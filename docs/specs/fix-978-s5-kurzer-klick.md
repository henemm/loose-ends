---
entity_id: fix-978-s5-kurzer-klick
type: bugfix
created: 2026-11-25
updated: 2026-11-25
status: draft
workflow: fix-978-s5-kurzer-klick
---

# Spec: #978 Schnitt v6 — kurzer Klick, bei gemessener Haltedauer ab 0,4 s genau eine Wiederholung

Vorgänger: `docs/specs/fix-978-s3-wiederoeffnen-warten.md` (v4, Halteprobe, belegt); diese Spec in Fassung v5 (kurzer Klick, hart rot, widerlegt).
Analyse: `docs/context/fix-978-s5-kurzer-klick.md` (Abschnitt „Analysis v6“). Befund v5: `docs/artifacts/fix-978-s5-kurzer-klick/befund-v5-nachweislauf.md`.

## Approval

- [ ] Approved (Henning)

## Purpose

Das Menüleisten-Panel klappt im Pflicht-Check „Mac Gallery (macOS)“ gelegentlich direkt nach dem Öffnen wieder zu (#978). Ursache (Halteprobe v4,
Lauf 45602877961): Hält die Klicksynthese des Tests das Symbol lange, schließt das Loslassen das Panel wie ein Systemmenü. Der kurze Klick von
0,1 s (v5) senkte die Rate, stellte sie aber nicht ab: Lauf 45642831767 zeigte Return-Arm 0 von 40 zu, Open-App-Arm 1 von 40 zu, Haltedauer ab
`key` 0,616 s, Panel 17 ms nach Maus-hoch zu. Die Abbruchregel der v5-Spec hat damit gegriffen. Schnitt v6 behält den kurzen Klick und lässt den
Test bei einem Fehlschlag die tatsächliche Haltedauer aus dem Panel-Protokoll der App lesen (`OSLogStore.local()`, Subsystem
`com.henning.looseends`, Kategorie `MenuBarPanel`): ab 0,4 s liegt der Fehler im Prüfwerkzeug und es folgt genau eine Wiederholung, sonst
(unter 0,4 s, „kurz“, „unbekannt“) bleibt der Test hart rot.

**Hat es bisher funktioniert?** Überwiegend ja; die App ist unberührt, der Fehler liegt in der gedehnten Klicksynthese des Prüfwerkzeugs.

**Recherche (Quellen):** Klicken-und-Halten schließt Menüs beim Loslassen: Apple-Forum 714649, Mozilla-Bug 101472. `click(forDuration:thenDragTo:)`:
Apples Doku macht keine Zusage zur tatsächlichen Haltedauer. `OSLogStore.local()` verlangt laut Apple-Doku ein Admin-Konto (Forum 666679: ohne
Entitlement genug) und liest in einer Sandbox nur den eigenen Prozess (Forum 744806). Ob der macOS-UI-Testläufer das darf, ist nicht belegt;
deshalb kommt die Probe zuerst (AC-5).

## Source

- **File:** `LooseEndsUITests/MacGalleryTests.swift`, `LooseEndsUITests/MacPanelHold.swift`
- **Identifier:** `openPanel`, `assertSymbolOpensPanelWithOneClick`, `testMenuBarReopensAfterReturnWithOneClick`, `testMenuBarReopensAfterOpenAppWithOneClick`, `testHoldDurationProbe`/`holdClick`, `shortClick`; neu der Helfer in `MacPanelHold.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| XCUIAutomation (`XCUICoordinate.click(forDuration:thenDragTo:)`) | API | kurzer Klick (0,1 s) auf dieselbe Koordinate |
| `OSLogStore.local()` (OSLog) | API | liest im Läufer die Panel-Protokollzeilen ab dem Klickzeitpunkt |
| `LooseEnds/Mac/MenuBarCapture.swift` (Logger `com.henning.looseends` / `MenuBarPanel`) | App | unverändert; Zeilen `panel key …` und `monitor local|global type=N window=… time=…` (Monitor 3 s ab `key`) |
| `LooseEndsUITests/MacUITestSupport.swift` | Test-Werkzeug | nur gelesen |
| `project.yml` | Konfiguration | unverändert: `LooseEndsUITests` ist als Ordnerquelle (`path: LooseEndsUITests`) eingebunden, die neue Datei kommt mit `generate` automatisch ins Bundle |
| `scripts/mac_panel_repeat_summary.py` | Skript | Auswerter (`MONITOR_SECONDS`, `key_to_mouse_up`, `hold_of`, `SHORT`): Wiederholungen zählen |
| `.github/workflows/mac-panel-repeat.yml` | CI | Nachweislauf `iterationen=40`, Halteprobe `halteprobe=true`; unverändert |
| CI-Job „Mac Gallery (macOS)“ in `.github/workflows/ci.yml` | CI | Pflicht-Check, Träger der drei grünen Läufe; unverändert |

Keine neue externe Abhängigkeit.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacPanelHold.swift` | CREATE | Helfer: liest per `OSLogStore.local()` die Einträge Subsystem `com.henning.looseends` + Kategorie `MenuBarPanel` ab dem Klickzeitpunkt; Haltedauer = erste `panel key`-Zeile nach dem Klick bis zum ersten Maus-hoch (`type=2`) innerhalb 3 s; Ergebnis Sekunden, „kurz“ (kein Maus-hoch im Fenster) oder „unbekannt“ mit Grund |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | `assertSymbolOpensPanelWithOneClick` und `openPanel`: Klick bleibt `shortClick`; bei Fehlschlag Haltedauer lesen, ≥ 0,4 s genau ein zweiter kurzer Klick (Anhang je Klick mit Haltedauer, zweiter mit `retry: hold X s`), sonst hart rot mit Haltedauer/Grund; `testHoldDurationProbe` schreibt die gelesene Haltedauer in seinen Anhang; Kontrollarm und Halteprobe bleiben (Umgebungsvariable, sonst `XCTSkip`) |
| `scripts/mac_panel_repeat_summary.py` | MODIFY | erkennt `retry: hold X s` in den Anhängen und zählt je Arm Wiederholungen, deren Haltedauer und das Ergebnis des zweiten Klicks; Iteration mit Wiederholung und offenem zweiten Klick zählt nicht als rot, wird aber ausgewiesen |
| `scripts/test_mac_reopen_settle.py` | MODIFY | „keine Wiederholung“ → „höchstens eine, nur bei Haltedauer ≥ 0,4 s, Helfer aus `MacPanelHold`“ |
| `scripts/test_mac_panel_repeat_summary.py` | MODIFY | Tests für das Zählen der Wiederholungen |

### Estimated Changes

- Files: 5 (Limit 4 bis 5 eingehalten)
- LoC: App-Code (`LooseEnds/`) 0; Testcode und Skripte ca. +90/−10 (zählt nicht zum Limit)

Keine Änderung an `project.yml`, `Info.plist`, Entitlements, AppStorage-Schlüsseln, `ci.yml`, `mac-panel-repeat.yml` oder Gate-Konfiguration.
Kein Pfad der Geräteliste berührt. Es sind keine Schritte vorgesehen, die eine menschliche Sperre (override) brauchen.

## Implementation Details

Schwelle **0,4 s**, begründet aus der Haltedauer ab `key` (`key` liegt etwa 0,2 s nach Maus-runter): Panel-zu-Fälle 0,616 / 0,71 / 0,90 / 0,93 s;
Erfolge des kurzen Klicks 0,033 bis 0,147 s oder „kein Maus-hoch“, Erfolge von `click()` höchstens 0,36 s. 0,4 s liegt in der Lücke;
0,616 s + 0,2 s ≈ 0,82 s Gesamthalten passt zum Systemwert von etwa 0,7 s und mehr (StableBar #904).

Reihenfolge der Umsetzung (Probe zuerst, im selben Schnitt):

1. **Helfer `MacPanelHold.swift`** mit Skripttest-Erwartungen (RED): öffnet `OSLogStore.local()`, Prädikat auf Subsystem und Kategorie, Position ab
   Klickzeitpunkt; sucht die erste `panel key`-Zeile danach und das erste Maus-hoch (Monitorzeile `type=2`) höchstens 3 s später (dieselbe Regel
   wie `key_to_mouse_up` im Auswerter). Kein Zugriff oder kein `key` → „unbekannt“ mit Grund; kein Maus-hoch im Fenster → „kurz“.
2. **Probe:** `testHoldDurationProbe` (Klick 1,0 s und 0,1 s im Wechsel) ruft den Helfer und schreibt die gelesene Haltedauer je Klick in den
   Anhang. Lauf `mac-panel-repeat.yml` mit `halteprobe=true`. Liefert er für die 1,0-s-Klicks Werte ≥ 0,4 s, trägt A-log. Liefert er nichts
   oder nur „unbekannt“ (Läufer darf das Protokoll nicht lesen), gilt Abbruchregel (a).
3. **Wiederholungsregel:** in `assertSymbolOpensPanelWithOneClick` (gemeinsamer Weg beider Nutzerarme) und in `openPanel`. Es gibt genau einen
   Retry-Pfad, nie mehr als eine Wiederholung; der zweite Versuch entscheidet hart. Kein Retry ohne gelesene Haltedauer.
4. **Auswerter + Skripttests**, danach der Nachweislauf `iterationen=40` und die drei Galerie-Läufe.

**Abbruchregeln (vorab festgelegt, keine Nachverhandlung im Schnitt):**
(a) Die Probe liefert keine Haltedauer: Stopp, Rückfall **A-ax** als Spec-Nachtrag (App legt unter `--ui-testing` die letzte Haltedauer als
Accessibility-Wert des Statusobjekts offen, ca. 15 LoC App-Code); AC-6 und AC-7 werden dann nicht angegangen. A-ax ist hier nicht gebaut.
(b) Der Nachweislauf zeigt Panel-zu-Fälle mit Haltedauer unter 0,4 s oder einen zweiten Fehlschlag nach der Wiederholung: Stopp, neue Analyse,
keine Schwellenverschiebung in diesem Schnitt.

## Test Plan

Mac-UI-Tests laufen nur in der CI (macOS 27), nie auf Hennings Mac. Lokal laufen die Skripttests und eine Übersetzungsprüfung.

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN die Anhänge einer Iteration, deren erster Klick das Panel nicht offen hielt und deren zweiter Klick den Vermerk `retry: hold 0.616 s` trägt und das Panel offen hält, WHEN der Auswerter zählt THEN steht je Arm eine Wiederholung mit Haltedauer 0,616 s und Ergebnis „offen“, die Iteration zählt nicht als rot und wird ausgewiesen.
- [ ] Test 2: GIVEN eine Iteration, deren zweiter Klick nach `retry` ebenfalls zu ist WHEN der Auswerter zählt THEN zählt sie als rot und das Ergebnis des zweiten Klicks steht im Bericht.
- [ ] Test 3: GIVEN Läufe ohne `retry` in den Anhängen WHEN der Auswerter zählt THEN stehen 0 Wiederholungen und die bisherigen Zähler bleiben unverändert.
- [ ] Test 4: GIVEN der Quelltext von `MacGalleryTests.swift` WHEN `test_mac_reopen_settle.py` ihn prüft THEN gibt es genau einen Retry-Pfad mit der Schwelle `0.4`, der nur nach einer gelesenen Haltedauer greift, und kein zweiter Wiederholungsschleifenpfad (kein Retry ohne Haltedauer).
- [ ] Test 5: GIVEN der Quelltext von `MacPanelHold.swift` WHEN `test_mac_reopen_settle.py` ihn prüft THEN enthält er `OSLogStore`, die Kategorie `MenuBarPanel`, das Subsystem `com.henning.looseends` und das 3-s-Fenster.
- [ ] Test 6: GIVEN ein Halteprobe-Lauf mit `halteprobe=true` WHEN die Anhänge ausgewertet werden THEN steht für jeden 1,0-s-Klick eine gelesene Haltedauer ≥ 0,4 s.
- [ ] Test 7: GIVEN der Nachweislauf mit `iterationen=40` WHEN er endet THEN liegen je Nutzerarm 40 Iterationen vor, 0 davon rot, und jede Wiederholung trägt eine gelesene Haltedauer ≥ 0,4 s.

### Abnahme (Stufen)

1. **Tests:** Skripttests grün, UI-Test-Bundle übersetzt, Probe und Nachweislauf ausgewertet.
2. **Simulator / Benutzung:** Die Mac-Klassen laufen nur in der CI; dort öffnet die echte Mac-App, das ist die Stufe. Belege: Zusammenfassung,
   ein Klickanhang je Arm (mit Wiederholung, falls vorhanden), geöffnet und beschrieben.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given `scripts/test_mac_panel_repeat_summary.py` / When `python3 -m unittest` lokal läuft / Then sind alle Skripttests grün, darunter neue Tests, die `retry: hold X s` in Anhängen erkennen und je Arm Wiederholungen, deren Haltedauer und das Ergebnis des zweiten Klicks zählen; eine Iteration mit Wiederholung und offenem zweitem Klick zählt nicht als rot und wird ausgewiesen, eine mit zweitem Fehlschlag zählt als rot. Belegt durch den Testlauf.
- **AC-2:** Given `scripts/test_mac_reopen_settle.py` / When er lokal läuft / Then ist er grün und verlangt: genau ein Retry-Pfad in `MacGalleryTests.swift` mit Schwelle `0.4`, höchstens eine Wiederholung, kein Retry ohne gelesene Haltedauer (unter 0,4 s, „kurz“ und „unbekannt“ sind hart rot mit Haltedauer oder Grund in der Meldung), Klick weiter `shortClick` mit `click(forDuration: 0.1`. Belegt durch den Testlauf.
- **AC-3:** Given `LooseEndsUITests/MacPanelHold.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then enthält der Helfer `OSLogStore`, Subsystem `com.henning.looseends`, Kategorie `MenuBarPanel`, die Paarung erste `panel key`-Zeile nach dem Klick mit erstem Maus-hoch (`type=2`) im 3-s-Fenster, und die Ergebnisse „kurz“ und „unbekannt“ mit Grund. Belegt durch den Testlauf und den Diff.
- **AC-4:** Given der Diff dieses Schnitts / When `git diff --stat` gegen den Ausgangsstand geprüft wird und das UI-Test-Bundle per Build-Prüfung übersetzt wird / Then ist App-Code (`LooseEnds/`) unverändert (0 LoC), ebenso `project.yml`, `ci.yml`, `mac-panel-repeat.yml` und jede Gate-Konfiguration, der Schnitt liegt bei höchstens 5 Dateien, das Bundle übersetzt ohne Fehler (die neue Datei kommt über die Ordnerquelle `LooseEndsUITests` ins Bundle), Kontrollarm und Halteprobe bleiben mit Umgebungsvariable und `XCTSkip`. Belegt durch `git diff --stat` und Prüfausgabe.
- **AC-5:** Given der Halteprobe-Lauf `mac-panel-repeat.yml` mit `halteprobe=true` / When er endet und die Anhänge geöffnet werden / Then steht in den Anhängen je Klick die vom Helfer gelesene Haltedauer, und die 1,0-s-Klicks zeigen Werte ≥ 0,4 s. Fehlt jede gelesene Haltedauer oder ist sie durchgängig „unbekannt“, gilt Abbruchregel (a): Stopp, A-ax per Spec-Nachtrag, AC-6 und AC-7 werden nicht angegangen. Belegt durch Lauf-Kennung und geöffneten Anhang in der Beleg-Datei unter `docs/artifacts/fix-978-s5-kurzer-klick/`.
- **AC-6:** Given der Nachweislauf `mac-panel-repeat.yml` mit `iterationen=40` und beiden Nutzerarmen (`ReturnWithOneClick`, `OpenAppWithOneClick`) / When er endet und ausgewertet wird / Then liegen je Arm 40 Iterationen vor, 0 sind rot, jede Wiederholung trägt eine gelesene Haltedauer ≥ 0,4 s, und Lauf-Kennung, Zähler, Wiederholungen mit Haltedauer und Rate stehen in einer Beleg-Datei unter `docs/artifacts/fix-978-s5-kurzer-klick/`. Tritt ein Panel-zu-Fall mit Haltedauer unter 0,4 s oder ein zweiter Fehlschlag nach Wiederholung auf, gilt Abbruchregel (b): Stopp, neue Analyse, AC-7 wird nicht angegangen. Belegt durch die Artefakte, geöffnet und beschrieben.
- **AC-7:** Given der Stand dieses Schnitts im Pull Request, vor dem Merge / When der Job „Mac Gallery (macOS)“ dreimal hintereinander auf demselben Commit grün läuft (Lauf 45642824480 zählt nicht, anderer Stand) / Then stehen die drei Lauf-Kennungen in der Beleg-Datei unter `docs/artifacts/fix-978-s5-kurzer-klick/` und im Issue #978 (DoD von #978). Belegt durch die CI-Läufe.

## Definition of Done

- [ ] AC-1 bis AC-7 belegt (Skripttests, Übersetzungsprüfung, Probe, Nachweislauf, drei grüne Galerie-Läufe auf demselben Commit)
- [ ] Beleg-Dateien von Probe und Nachweislauf unter `docs/artifacts/fix-978-s5-kurzer-klick/`, Ergebnis im Issue #978 kommentiert
- [ ] Issue #978 erst nach den drei grünen Läufen schließen, bis dahin `Refs #978`
- [ ] Kein Pfad der Geräteliste berührt.

## Alternativen

- **A-log kurzer Klick, bei Fehlschlag Haltedauer aus dem Panel-Protokoll per `OSLogStore.local()` lesen, ab 0,4 s genau eine Wiederholung (gewählt):** behandelt den belegten Fehler des Prüfwerkzeugs (gedehnte Synthese) dort, wo er entsteht, ohne App-Code, nutzt das vorhandene Protokoll; unter 0,4 s oder ohne Messwert bleibt der Test hart rot, ein echter Produktfehler wird nicht verdeckt. Risiko: Der Läufer darf das Protokoll vielleicht nicht lesen; deshalb die Probe zuerst.
- **A-ax Haltedauer als Accessibility-Wert aus der App (Rückfall):** App legt unter `--ui-testing` die letzte Haltedauer am Statusobjekt offen (ca. 15 LoC App-Code); Label-Weitergabe bei `MenuBarExtra` unbelegt. Nur als Spec-Nachtrag, falls die Probe scheitert (Abbruchregel a).
- **B v5 kurzer Klick ohne Wiederholung, hart rot (widerlegt):** Open-App-Arm 1 von 40 zu (Haltedauer 0,616 s), Befund v5; die angeforderte Haltedauer ist unter Last keine Garantie.
- **D Klick per CGEvent vom Läufer (wie der Kontrollarm):** steuert das Halten selbst, weicht aber vom XCUITest-Nutzerweg ab, den die DoD verlangt; nicht gewählt.
- **C Produkt ändern (Panel trotz langem Halten offen lassen):** weicht vom Systemverhalten der Menüleiste ab, kippt die #862-Lösung (`dismiss()`), kein Nutzerbefund; nicht gewählt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Änderung am Testwerkzeug und an den Auswertungsskripten; App, Datenmodell und Plattformzuschnitt bleiben, keine bestehende ADR wird berührt oder gekippt.

## Changelog

- 2026-11-25: Initial spec created (v5, Empfehlung B aus der Analyse; löst die Wiederholungs-Idee aus Befund v4 durch den kurzen Klick ab).
- 2026-11-25: v6: nach Befund v5 Wiederholung bei gemessener Haltedauer ≥ 0,4 s, Quelle OSLogStore (Empfehlung A-log, Rückfall A-ax; v5-ACs ersetzt).
