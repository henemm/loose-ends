---
entity_id: fix-978-s5-kurzer-klick
type: bugfix
created: 2026-11-25
updated: 2026-11-25
status: draft
workflow: fix-978-s5-kurzer-klick
---

# Spec: #978 Schnitt v7 (Nachtrag A-ax) — kurzer Klick, Haltedauer als Accessibility-Wert der App, ab 0,4 s genau eine Wiederholung

Vorgänger: `docs/specs/fix-978-s3-wiederoeffnen-warten.md` (v4, Halteprobe, belegt); diese Spec in Fassung v5 (kurzer Klick, hart rot, widerlegt) und v6 (Haltedauer per `OSLogStore`, gebaut, Commit c800f7b, widerlegt).
Analyse: `docs/context/fix-978-s5-kurzer-klick.md` (Abschnitte „Analysis v6“ und „Analysis v7“). Befunde: `docs/artifacts/fix-978-s5-kurzer-klick/befund-v5-nachweislauf.md`, `docs/artifacts/fix-978-s5-kurzer-klick/befund-v6-halteprobe.md`.

## Approval

- [ ] Approved (Henning)

## Purpose

Das Menüleisten-Panel klappt im Pflicht-Check „Mac Gallery (macOS)“ gelegentlich direkt nach dem Öffnen wieder zu (#978). Ursache (Halteprobe v4,
Lauf 45602877961): Hält die Klicksynthese des Tests das Symbol lange, schließt das Loslassen das Panel wie ein Systemmenü. Der kurze Klick von
0,1 s (v5) senkte die Rate, stellte sie aber nicht ab (Lauf 45642831767: Open-App-Arm 1 von 40 zu, Haltedauer ab `key` 0,616 s). v6 sollte die
Haltedauer im Test aus dem Panel-Protokoll lesen (`OSLogStore.local()`); der Befund v6 (Lauf 45658361541, Commit c800f7b) zeigt: alle 40
Klickanhänge tragen `read hold: unknown (log not readable: Connection to logd failed)`, der macOS-UI-Testläufer darf `logd` nicht lesen.
Die Abbruchregel (a) der v6-Spec hat gegriffen. Schnitt v7 behält Klick, Retry-Pfad (genau eine Wiederholung, Schwelle 0,4 s, kein Retry ohne
gelesene Sekunden) und Auswerter und tauscht nur die Quelle der Haltedauer: Die App misst unter `--ui-testing` dieselbe Strecke `key` → erstes
Maus-hoch selbst und legt sie als Accessibility-Wert des Menüleisten-Statusobjekts ab, das der Test ohnehin als `app.statusItems.firstMatch` hält.
Ohne `--ui-testing` ändert sich an der App nichts.

**Hat es bisher funktioniert?** Überwiegend ja; das Produktverhalten ist unberührt, der Fehler liegt in der gedehnten Klicksynthese des Prüfwerkzeugs.

**Recherche (Quellen):**
- Klicken-und-Halten schließt Menüs beim Loslassen: Apple-Forum 714649, Mozilla-Bug 101472. `click(forDuration:thenDragTo:)`: Apples Doku macht keine Zusage zur tatsächlichen Haltedauer.
- Befund v6: `OSLogStore.local()` scheitert im Läufer mit „Connection to logd failed“; die Meldung kennt man aus der Sandbox, `local()` verlangt Admin-Konto bzw. das nicht vergebene Entitlement `com.apple.logging.local-store` (mjtsai.com „OSLogStore on Monterey“, Apple-Forum 666679, Apple-Doku `OSLogStore.local()`).
- Das Statusobjekt eines `MenuBarExtra` ist über `NSApp.windows` erreichbar (Fensterklasse `NSStatusBarWindow`, darin der `NSStatusBarButton`): orchetect/MenuBarExtraAccess (https://github.com/orchetect/MenuBarExtraAccess). Dass ein dort gesetztes `accessibilityValue` per XCUITest als `statusItems.firstMatch.value` lesbar ist, dazu fand sich keine Quelle: Die Probe kommt zuerst (Abbruchregel a').
- Datenaustausch Läufer und App: Apple-DTS (Forum 130767): App Groups gehen nicht, weil der Runner fremde Entitlements hat, TCP wäre die IPC-Wahl; Pasteboard aus dem Runner ist eingeschränkt (Forum 684548, iOS). Deshalb der Weg über Accessibility, den der Läufer ohnehin liest.
- macOS 27: `MenuBarExtra(.window)` ignoriert AXPress (github jizhi0v0/macos27-beta-issues #34). Das betrifft den Test nicht, er klickt per Koordinate; es ist der Grund, nicht `statusItem.press` zu verwenden.

## Source

- **File:** `LooseEnds/Mac/MenuBarCapture.swift`, `LooseEndsUITests/MacPanelHold.swift`, `LooseEndsUITests/MacGalleryTests.swift`
- **Identifier:** `MenuBarPanelLog` (`record`, `startMonitors`, `logMonitored`, neu der Wert am Statusobjekt), `MacPanelHold`, `openPanel`, `retryAfterLongHold`, `assertSymbolOpensPanelWithOneClick`, `holdClick`/`testHoldDurationProbe`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| XCUIAutomation (`XCUIElement.value`, `XCUICoordinate.click(forDuration:thenDragTo:)`) | API | Wert des Statusobjekts lesen; kurzer Klick (0,1 s) auf dieselbe Koordinate |
| AppKit (`NSApp.windows`, `NSStatusBarWindow`, `NSStatusBarButton`, `setAccessibilityValue`, `NSEvent`-Monitore) | API | App setzt den Wert am Statusobjekt (nur unter `--ui-testing`) |
| `ModelContainerFactory.isUITesting` | App | Schalter: ohne `--ui-testing` kein Wert, kein Verhalten |
| `LooseEnds/Mac/MenuBarCapture.swift` (`MenuBarPanelLog`, Monitorrunde 3 s ab `key`) | App | Quelle der Messung; Protokollzeilen bleiben unverändert |
| `LooseEnds/App/LooseEndsApp.swift` (`MenuBarExtra`) | App | nur gelesen; kein Eingriff (SwiftUI-Label-Weg nicht gewählt) |
| `LooseEndsUITests/MacUITestSupport.swift` | Test-Werkzeug | nur gelesen |
| `project.yml` | Konfiguration | unverändert: `LooseEndsUITests` ist Ordnerquelle, `MacPanelHold.swift` liegt schon im Bundle |
| `scripts/mac_panel_repeat_summary.py` und `scripts/test_mac_panel_repeat_summary.py` | Skript | unverändert wie in v6 gebaut (Auswerter zählt Wiederholungen, Spalte „key → Maus hoch“ aus dem Protokoll) |
| `.github/workflows/mac-panel-repeat.yml` | CI | Halteprobe `halteprobe=true`, Nachweislauf `iterationen=40`; unverändert |
| CI-Job „Mac Gallery (macOS)“ in `.github/workflows/ci.yml` | CI | Pflicht-Check, Träger der drei grünen Läufe; unverändert |

Keine neue externe Abhängigkeit.

## Scope

Ausgangsstand für den Diff dieses Nachtrags ist der Commit c800f7b (v6 gebaut).

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | `MenuBarPanelLog`: nur unter `ModelContainerFactory.isUITesting`; bei `key` (dort startet `startMonitors`) Zeit merken (`ProcessInfo.processInfo.systemUptime`) und Wert `round=<n> pending` setzen; beim ersten Maus-hoch (`leftMouseUp`, NSEvent-Typ 2, lokal oder global) innerhalb der 3-s-Monitorrunde `round=<n> <Sekunden, 3 Nachkommastellen>`; endet die Runde ohne Maus-hoch `round=<n> short` (gleiche Regel wie `key_to_mouse_up` im Auswerter). Gesetzt per `setAccessibilityValue` am `NSStatusBarButton`, gefunden über `NSApp.windows` (Fensterklasse `NSStatusBarWindow`, deren `contentView` oder Unteransicht ist der Button). Protokollzeilen unverändert |
| `LooseEndsUITests/MacPanelHold.swift` | MODIFY | Umbau: kein `OSLogStore`. `round(of:)` liest die aktuelle Runde aus `statusItem.value` (`round=<n> …`, fehlt oder unlesbar: 0). `read(_:after:)` wartet nach einem Fehlschlag höchstens 4 s, bis der Wert eine Runde größer als `after` trägt und nicht `pending` ist; Ergebnis `.seconds(x)`, `.short` oder `.unknown(Grund)` (Wert fehlt, nicht lesbar, keine neue Runde). Typ `Reading` und `text` bleiben |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | `openPanel`, `assertSymbolOpensPanelWithOneClick` und `holdClick` lesen die Runde vor dem Klick und übergeben sie an den Helfer statt `since: Date`. Retry-Pfad (`retryAfterLongHold`) bleibt genau einer: Schwelle 0,4 s, höchstens eine Wiederholung, kein Retry ohne gelesene Sekunden; Halteprobe schreibt die gelesene Haltedauer je Klick in den Anhang |
| `scripts/test_mac_reopen_settle.py` | MODIFY | Quelltextprüfung des Helfers: statt `OSLogStore` das Lesen von `value` am Statusobjekt, das Rundenformat `round=`, `pending` und `short`, das 4-s-Warten; für die App: Setzen nur unter `isUITesting`, `setAccessibilityValue`, `NSStatusBarWindow`, Paarung `key` → erstes Maus-hoch innerhalb 3 s; kein `OSLogStore` mehr im Helfer. Die Retry-Pfad-Tests folgen der neuen Aufrufform `MacPanelHold.read(` |

### Estimated Changes

- Files: 4 (Limit 4 bis 5 eingehalten)
- LoC: App-Code (`LooseEnds/Mac/MenuBarCapture.swift`) ca. +25 (Limit 250); Testcode und Skripte ca. +60/−40 (zählt nicht zum Limit)

Keine Änderung an `project.yml`, `Info.plist`, Entitlements, AppStorage-Schlüsseln, `ci.yml`, `mac-panel-repeat.yml` oder Gate-Konfiguration.
`LooseEnds/Mac/` steht nicht in der Geräteliste: Kein Pfad der Geräteliste berührt. Es sind keine Schritte vorgesehen, die eine menschliche Sperre (override) brauchen.

Side-Effects, ausdrücklich: Die App setzt den Accessibility-Wert nur, wenn `--ui-testing` übergeben ist; die Produktstarts von Henning und der Store-Bau tragen das Argument nie. Es entstehen keine neuen Berechtigungen, keine Dateien, keine Schlüssel.

## Implementation Details

Schwelle **0,4 s** unverändert (Begründung aus der Haltedauer ab `key`): Panel-zu-Fälle 0,616 / 0,71 / 0,90 / 0,93 s; Erfolge des kurzen Klicks 0,033 bis
0,147 s oder „kein Maus-hoch“, Erfolge von `click()` höchstens 0,36 s. 0,4 s liegt in der Lücke.

Wertformat am Statusobjekt (eine Zeile, Leerzeichen getrennt): `round=<n> pending` ab `key`, danach `round=<n> 0.934` (Sekunden ab `key` bis zum ersten
Maus-hoch in den 3 s der Monitorrunde) oder `round=<n> short`, wenn die Runde ohne Maus-hoch endet. `n` zählt die Monitorrunden (`monitorRound`) der Sitzung;
eine neue `key`-Zeile beginnt eine neue Runde.

Ablauf im Test: Vor dem Klick `let before = MacPanelHold.round(of: statusItem)`. Nach einem Fehlschlag ruft `retryAfterLongHold` `MacPanelHold.read(statusItem, after: before)`;
nur `.seconds(x)` mit `x >= 0.4` löst den einen zweiten Klick aus. Die Halteprobe liest dieselbe Runde je Klick und schreibt `read hold: …` in den Anhang.

Warum AppKit statt SwiftUI: Ob SwiftUI `.accessibilityValue` am `MenuBarExtra`-Label bis zum Statusobjekt durchreicht, ist unbelegt; AppKit am
`NSStatusBarButton` (Muster MenuBarExtraAccess) ist der direkte Weg. Ein Rückfall innerhalb der Probe auf SwiftUI ist nicht vorgesehen.

Reihenfolge der Umsetzung (Probe zuerst):

1. Skripttests anpassen (RED): Helfer ohne `OSLogStore`, mit `value`, `round=`, `pending`, `short`, 4-s-Warten; App-Quelltext mit den fünf Merkmalen.
2. App-Code in `MenuBarPanelLog`, Helfer umbauen, `MacGalleryTests.swift` anpassen (GREEN lokal).
3. Übersetzung von App und UI-Test-Bundle für macOS lokal prüfen (`./scripts/sim.sh mac-build` bzw. die Build-Prüfung).
4. Danach die CI-Läufe der Definition of Done: Halteprobe, Nachweislauf, drei Galerie-Läufe.

**Abbruchregeln (vorab festgelegt, ersetzen v6 (a), keine Nachverhandlung im Schnitt):**
(a') Die Halteprobe (`mac-panel-repeat.yml`, `halteprobe=true`) liefert für die 1,0-s-Klicks keine gelesene Haltedauer ≥ 0,4 s (Wert fehlt oder durchgängig „unknown“): Stopp, neue Analyse (Kandidaten: TCP-Port der App unter `--ui-testing`, D CGEvent-Klick); Nachweislauf und Galerie-Läufe werden nicht angegangen.
(b) Der Nachweislauf zeigt Panel-zu-Fälle mit Haltedauer unter 0,4 s oder einen zweiten Fehlschlag nach der Wiederholung: Stopp, neue Analyse, keine Schwellenverschiebung in diesem Schnitt.

## Test Plan

Mac-UI-Tests laufen nur in der CI (macOS 27), nie auf Hennings Mac. Lokal laufen die Skripttests und die Übersetzungsprüfung; die CI-Läufe stehen in der Definition of Done.

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN der Quelltext von `MacPanelHold.swift` WHEN `test_mac_reopen_settle.py` ihn prüft THEN liest er `value` am Statusobjekt, kennt das Format `round=` mit `pending` und `short`, wartet höchstens 4 s und enthält kein `OSLogStore` und kein `import OSLog`.
- [ ] Test 2: GIVEN der Quelltext von `MenuBarCapture.swift` WHEN `test_mac_reopen_settle.py` ihn prüft THEN setzt `MenuBarPanelLog` den Wert nur unter `isUITesting`, mit `setAccessibilityValue`, über `NSStatusBarWindow`, und paart `key` mit dem ersten Maus-hoch (Typ 2) innerhalb der 3-s-Monitorrunde.
- [ ] Test 3: GIVEN der Quelltext von `MacGalleryTests.swift` WHEN `test_mac_reopen_settle.py` ihn prüft THEN gibt es genau einen Retry-Pfad mit der Schwelle `0.4`, der nur nach `.seconds(x)` mit `x >= 0.4` klickt, genau einen Lesevorgang und genau einen zweiten Klick, ohne Schleife; die Runde wird vor dem Klick gelesen.
- [ ] Test 4: GIVEN der Quelltext von `MacGalleryTests.swift` WHEN der Test ihn prüft THEN schreibt die Halteprobe die gelesene Haltedauer als Zeile `read hold:` in den Anhang, und die Nutzerklick-Anhänge tragen eine Zeile `hold:`.
- [ ] Test 5: GIVEN die Skripttests von v6 für den Auswerter (`test_mac_panel_repeat_summary.py`) WHEN sie unverändert laufen THEN sind sie grün (Zählen der Wiederholungen bleibt wie gebaut).
- [ ] Test 6: GIVEN App und UI-Test-Bundle WHEN sie für macOS übersetzt werden THEN gibt es keine Fehler.

Die v6-Testplanpunkte 6 und 7 (Halteprobe, Nachweislauf) sind in die Definition of Done verschoben.

### Abnahme (Stufen)

1. **Tests:** Skripttests grün, App und UI-Test-Bundle für macOS übersetzt.
2. **Simulator / Benutzung:** Die Mac-Klassen laufen nur in der CI; dort öffnet die echte Mac-App, das ist die Stufe. Sie liegt in der Definition of Done (Halteprobe, Nachweislauf, drei Galerie-Läufe), mit geöffneten und beschriebenen Anhängen.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given `scripts/test_mac_reopen_settle.py` und `scripts/test_mac_panel_repeat_summary.py` / When `python3 -m unittest` beide lokal fährt / Then sind alle Tests grün, darunter die neuen Quelltextprüfungen für Helfer, App und Retry-Pfad, und die v6-Tests des Auswerters bestehen unverändert. Belegt durch den Testlauf.
- **AC-2:** Given `LooseEndsUITests/MacPanelHold.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then liest der Helfer `value` am Statusobjekt, kennt das Format `round=<n>` mit `pending` und `short`, wartet höchstens 4 s auf eine neue, nicht ausstehende Runde, liefert `.seconds`, `.short` oder `.unknown` mit Grund und enthält weder `OSLogStore` noch `import OSLog`. Belegt durch den Testlauf und den Diff.
- **AC-3:** Given `LooseEnds/Mac/MenuBarCapture.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then setzt `MenuBarPanelLog` den Wert nur unter `ModelContainerFactory.isUITesting`, per `setAccessibilityValue` am Button des Fensters der Klasse `NSStatusBarWindow`, setzt bei `key` `round=<n> pending`, danach die Sekunden beim ersten Maus-hoch (Typ 2, lokal oder global) innerhalb der 3-s-Monitorrunde und `short` bei Rundenende ohne Maus-hoch; die Protokollzeilen sind unverändert. Belegt durch den Testlauf und den Diff.
- **AC-4:** Given `LooseEndsUITests/MacGalleryTests.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then liest jeder Klickweg (`openPanel`, `assertSymbolOpensPanelWithOneClick`, `holdClick`) die Runde vor dem Klick, es gibt genau einen Retry-Pfad mit Schwelle `0.4`, höchstens eine Wiederholung, keinen Retry ohne gelesene Sekunden (unter 0,4 s, „short“ und „unknown“ sind hart rot mit Haltedauer oder Grund in der Meldung), der Klick bleibt `shortClick` mit `click(forDuration: 0.1`, Kontrollarm und Halteprobe bleiben hinter Umgebungsvariable und `XCTSkip`. Belegt durch den Testlauf.
- **AC-5:** Given der Stand dieses Nachtrags / When App und UI-Test-Bundle für macOS übersetzt werden (`./scripts/sim.sh mac-build` bzw. die Build-Prüfung) / Then übersetzen beide ohne Fehler. Belegt durch die Prüfausgabe.
- **AC-6:** Given der Diff gegen den Commit c800f7b / When `git diff --stat` geprüft wird / Then sind es genau die vier Dateien `LooseEnds/Mac/MenuBarCapture.swift`, `LooseEndsUITests/MacPanelHold.swift`, `LooseEndsUITests/MacGalleryTests.swift` und `scripts/test_mac_reopen_settle.py` plus Dokumentation (`docs/`), der App-Code liegt nur in `LooseEnds/Mac/MenuBarCapture.swift` bei höchstens 250 LoC und ist nur unter `isUITesting` wirksam; `project.yml`, `Info.plist`, Entitlements, `ci.yml`, `mac-panel-repeat.yml` und Gate-Konfiguration sind unverändert. Belegt durch `git diff --stat` und den Quelltext.

## Definition of Done

CI-Läufe stehen hier und nicht als AC, damit ein Abbruch keine menschliche Sperre am Gate auslöst; jede Zeile mit Lauf-Kennung, Beleg-Datei unter `docs/artifacts/fix-978-s5-kurzer-klick/` und Kommentar im Issue #978.

- [ ] AC-1 bis AC-6 belegt (Skripttests, Quelltextprüfungen, Übersetzung, Diff)
- [ ] Halteprobe (`mac-panel-repeat.yml`, `halteprobe=true`): je 1,0-s-Klick eine gelesene Haltedauer ≥ 0,4 s im Anhang (ersetzt v6 Testplanpunkt 6); fehlt sie oder ist sie durchgängig „unknown“, gilt Abbruchregel (a')
- [ ] Nachweislauf `iterationen=40` mit beiden Nutzerarmen: je Arm 40 Iterationen, 0 rot, jede Wiederholung mit gelesener Haltedauer ≥ 0,4 s; Lauf-Kennung, Zähler, Wiederholungen mit Haltedauer und Rate in der Beleg-Datei (ersetzt v6 Testplanpunkt 7); Panel-zu-Fall unter 0,4 s oder zweiter Fehlschlag: Abbruchregel (b)
- [ ] Der Job „Mac Gallery (macOS)“ läuft dreimal hintereinander auf demselben Commit grün (Lauf 45642824480 zählt nicht, anderer Stand); die drei Lauf-Kennungen stehen in der Beleg-Datei und im Issue #978
- [ ] Anhänge geöffnet und beschrieben (ein Klickanhang je Arm, mit Wiederholung, falls vorhanden)
- [ ] Issue #978 erst nach den drei grünen Läufen schließen, bis dahin `Refs #978`
- [ ] Kein Pfad der Geräteliste berührt.

## Alternativen

- **A-ax Haltedauer als Accessibility-Wert aus der App unter `--ui-testing`, am `NSStatusBarButton` per AppKit (gewählt):** nutzt den Kanal, den der Läufer ohnehin liest (`statusItems.firstMatch`), keine neue Berechtigung, ca. 25 LoC App-Code, nur unter Tests wirksam. Risiko: Lesbarkeit des Werts per XCUITest unbelegt; deshalb die Probe zuerst und Abbruchregel (a').
- **A-log Haltedauer per `OSLogStore.local()` im Läufer (v6, widerlegt):** Befund v6, `Connection to logd failed` in 40 von 40 Klicks; der Läufer darf das Protokoll nicht lesen.
- **TCP-Port der App unter `--ui-testing` (Apple-DTS-Empfehlung, Forum 130767):** tragfähig, aber mehr Code und im Sandbox-Arm ein Netzwerk-Entitlement; nicht gewählt, Kandidat der neuen Analyse bei Abbruchregel (a').
- **SwiftUI `.accessibilityValue` am `MenuBarExtra`-Label:** Durchreichung bis zum Statusobjekt unbelegt, ein Rückfall innerhalb der Probe ist nicht vorgesehen; nicht gewählt.
- **D Klick per CGEvent vom Läufer (wie der Kontrollarm):** steuert das Halten selbst, weicht aber vom XCUITest-Nutzerweg ab, den die DoD verlangt; nicht gewählt, Kandidat bei (a').
- **C Produkt ändern (Panel trotz langem Halten offen lassen):** weicht vom Systemverhalten der Menüleiste ab, kippt die #862-Lösung (`dismiss()`), kein Nutzerbefund; nicht gewählt.
- **B v5 kurzer Klick ohne Wiederholung, hart rot (widerlegt):** Open-App-Arm 1 von 40 zu (Haltedauer 0,616 s), Befund v5.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Eine Testhilfe in der App, nur unter `--ui-testing` wirksam, ohne Wirkung auf Produktverhalten, Datenmodell, Berechtigungen oder Plattformzuschnitt; keine bestehende ADR wird berührt oder gekippt.

## Changelog

- 2026-11-25: Initial spec created (v5, Empfehlung B aus der Analyse; löst die Wiederholungs-Idee aus Befund v4 durch den kurzen Klick ab).
- 2026-11-25: v6: nach Befund v5 Wiederholung bei gemessener Haltedauer ≥ 0,4 s, Quelle OSLogStore (Empfehlung A-log, Rückfall A-ax; v5-ACs ersetzt).
- 2026-11-25: v7: Nachtrag A-ax nach Befund v6 (logd im Läufer nicht lesbar); CI-Läufe in die DoD
