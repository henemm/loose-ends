# Context: fix-978-s5-kurzer-klick (#978 Schnitt v5)

## Request Summary
Die Wiederöffnungstests des Mac-Menüleistenpanels sollen kurz klicken wie ein Mensch, die Haltedauer (Maus runter → hoch)
aus dem Panel-Protokoll messen und nur dann, wenn das Prüfwerkzeug zu lange gehalten hat, genau einmal wiederholen;
sonst hart rot. DoD von #978: Test baut den Nutzerweg nach, drei aufeinanderfolgende Läufe des Mac-Galerie-Jobs grün.

## Vorgeschichte (belegt)
- S2 (PR #992): Panel-Protokoll `MenuBarPanel` (key/resign/hide/close, Stapel, CGEvent-Felder, für 3 s nach `key` lokaler
  und globaler Maus-Monitor), Wiederholungs-Workflow `mac-panel-repeat.yml`, Auswerter `scripts/mac_panel_repeat_summary.py`.
- S3 v1–v3 widerlegt: Warten auf Ruhe der vordersten App, Klick über vorderste App, Klick über deren Menüleiste — der Fall
  trat trotzdem auf (Befunde `docs/artifacts/fix-978-s3-wiederoeffnen-warten/befund-*.md`).
- S3 v4 (PR #994, 33a102b): Halteprobe `testHoldDurationProbe`, Lauf 45602877961: `click(forDuration: 1.0)` 20/20 zu,
  `click(forDuration: 0.1)` 0/20 zu. Ursache: langes Halten auf dem Statusobjekt schließt das Panel (Systemverhalten wie
  bei Menüs, StableBar #904: ≥ 700 ms). Fälle bei `click()`: key→Maus hoch 0,71/0,90/0,93 s; Erfolge ≤ 0,36 s.
- Testläufer-Monitor (`HoldMonitor`, globaler NSEvent-Monitor) sah 0/40 XCTest-Klicks → Haltedauer nicht im Läufer messbar.
- Beim kurzen Klick steht im Panel-Protokoll **kein** Maus-hoch (das Ereignis bleibt beim Statusobjekt); der Auswerter paarte
  dann fälschlich mit späterem Maus-hoch (11–13 s).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsUITests/MacGalleryTests.swift` | `openPanel` (Z. ~313, `statusItem.click()`), `testMenuBarReopensAfterReturnWithOneClick`, `testMenuBarReopensAfterOpenAppWithOneClick` (Z. ~470), Kontrollarm, `testHoldDurationProbe`/`holdClick`/`HoldMonitor` (Z. ~505–585), `coordinateClick`, `waitForFrontmostSettled`, `frontmostRootClick` (v3, Z. ~643), `assertSymbolOpensPanelWithOneClick` (Z. ~670) — Hauptort des Umbaus |
| `LooseEnds/Mac/MenuBarCapture.swift` | Panel-Protokoll (`panelLogger`, Kategorie `MenuBarPanel`), `startMonitors` (Z. ~201: lokal+global, 3 s ab `key`), `logMonitored` (Typ, Fenster, Zeitstempel). Einzige Quelle der Haltedauer, die XCTest-Klicks sieht |
| `scripts/mac_panel_repeat_summary.py` | Auswerter: `parse_panel_log`, `key_to_mouse_up` (Paarung im 15-s-Fenster → Fehlpaarung beim kurzen Klick), `how_of`/`_HOW` (menubar-root/fallback-*), Arme |
| `scripts/test_mac_panel_repeat_summary.py`, `scripts/test_mac_reopen_settle.py`, `scripts/test_menubar_panel_log.py` | Skripttests, die Quelltext von MacGalleryTests/MenuBarCapture prüfen (v2/v3-Erwartungen, müssen mitwandern) |
| `.github/workflows/ci.yml` | Job „Mac Gallery (macOS)“ (Z. ~576, 60 min, `-only-testing:LooseEndsUITests/MacGalleryTests`), Protokoll-Schritt `log show … MenuBarPanel` → Artefakt `MacGalleryPanelLog` (Z. ~733) |
| `.github/workflows/mac-panel-repeat.yml` | Wiederholungsläufe je Arm, Eingaben `iterationen`, `sandbox`, `kontrollarm`, `halteprobe`; `log show` nach dem Lauf |
| `LooseEndsUITests/MacUITestSupport.swift` | `macLaunch`, `macElement`, `macMainWindow`, `macShot` |
| `docs/specs/fix-978-s3-wiederoeffnen-warten.md` | Spec v4 (Halteprobe), Regeln, Abweichungen |

## Existing Patterns
- Klickwege mit `how`-Text im Anhang `mac-gallery-<label>-click` (Zeitpunkt, vorderste App, Klickdauer, Ergebnis) — der
  Auswerter zählt daraus je Arm.
- Diagnosearme nur mit Umgebungsvariable (`LE_PANEL_CONTROL_ARM`, `LE_PANEL_HOLD_PROBE`), sonst `XCTSkip`; im Pflichtjob nie.
- Zustand an den Test: bisher nur über Accessibility (Elemente, Kennungen) und Startargumente (`--ui-testing…`); die App
  schreibt unter Tests nichts, was der Läufer liest.

## Dependencies
- Upstream: XCUITest-Klicksynthese (`click()`, `click(forDuration:thenDragTo:)`, `XCUICoordinate`), Statusobjekt-Host des
  Systems, `NSEvent`-Monitore der App, `log show` im CI-Job.
- Downstream: geschützter Check „Mac Gallery (macOS)“, `mac-panel-repeat.yml`-Auswertung, Skripttests.

## Existing Specs
- `docs/specs/fix-978-s3-wiederoeffnen-warten.md` (v4), `docs/specs/fix-978-s2-panel-ernte.md`, `docs/specs/fix-978-panel-schliesst.md`

## Risks & Considerations
- Kernfrage für die Analyse: Wie erfährt der Test die Haltedauer **während des Laufs**, um über der Schwelle zu wiederholen?
  Der Läufer sieht die Klicks nicht; `log show`/`OSLogStore` aus dem Läufer ist fraglich (Sandbox/Rechte des UI-Test-Läufers
  auf macOS, recherchieren). Möglich: die App legt den gemessenen Wert unter `--ui-testing` per Accessibility offen
  (App-Code, Kategorie Diagnose) — oder gar keine Wiederholung nötig, wenn `click(forDuration: 0.1)` die Haltedauer
  zuverlässig kurz hält (Probe: 0/20 zu, 0,036–0,137 s).
- Beim kurzen Klick fehlt Maus-hoch im Protokoll → „kein Maus-hoch in 3 s“ muss als „kurz“ gelten, nicht als „unbekannt“.
- Der v3-Klickweg (`frontmostRootClick`, harte Rückfall-Regel) liegt auf main; ein Umbau muss ihn sauber ablösen samt Skripttests.
- Galerie-Job dauert 33–41 min bei 60-min-Grenze; drei grüne Läufe = drei Reruns.
- Haltedauer-Schwelle: StableBar ≥ 700 ms, eigene Fälle ≥ 0,71 s, Erfolge ≤ 0,36 s → Schwelle irgendwo 0,4–0,7 s, begründen.
- Scoping: App-Code höchstens die Offenlegung der Haltedauer; Test-/Skriptcode zählt nicht zum LoC-Limit.

## Analysis

### Type
Bug im Prüfwerkzeug, nicht in der App: `click()` von XCTest hält das Menüleistensymbol unter Last 0,7–0,9 s; Loslassen
nach so langem Halten schließt das Panel wie ein Systemmenü (Standardverhalten macOS). Beleg: Halteprobe v4, Lauf 45602877961.

### Recherche (Quellen)
- Apple-Forum 714649: Popup-Menüs schließen nach Klicken-und-Halten beim Loslassen (XCUITest, Xcode 14).
- Mozilla Bug 101472: Menü nach Klick-und-Halten verschwindet beim Loslassen (Plattformverhalten).
- SDL-Issue 13134: Öffnet ein Menü auf Maus-runter, bekommt die App kein Maus-hoch → erklärt das fehlende Maus-hoch beim
  kurzen Klick im Panel-Protokoll.
- Apple-Forum 836113: NSStatusItem-Probleme unter macOS 27 (Hervorhebung), kein Bezug zur Haltedauer.
- Keine Quelle für eine einstellbare Haltedauer von `click()`; `click(forDuration:thenDragTo:)` ist der dokumentierte Weg.

### Gemessene Varianten
| Variante | Zustand | Haltedauer (Panel-Protokoll) | Panel zu |
|---|---|---|---|
| `click()` Fehlfälle | Nutzerarme | 0,71 / 0,90 / 0,93 s | ja |
| `click()` Erfolge | Nutzerarme | ≤ 0,36 s | nein |
| `click(forDuration: 1.0, thenDragTo: same)` | Return-Zustand | 0,89–1,44 s | 20/20 |
| `click(forDuration: 0.1, thenDragTo: same)` | Return-Zustand | 0,036–0,137 s | 0/20 |
| v1–v3 (Ruhe abwarten, Klickwurzel vorderste App) | Open-App | – | widerlegt |
| 0,1 s im Open-App-Zustand | Open-App | – | **nicht gemessen** → Nachweislauf |

0/20 schließt eine wahre Ausfallrate von 10 % nur mit ~88 % aus → Nachweislauf mit 40 Iterationen je Nutzerarm.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | ein Helfer für den kurzen Klick (Mitte des Symbols, `click(forDuration: 0.1, thenDragTo:)` auf dieselbe Koordinate) für `openPanel` und beide Nutzerarme; `frontmostRootClick` (v3) und `waitForFrontmostSettled` (v1) samt Rückfall-Regel entfernt; Anhang `how` = `user: short click 0.1 s`; Kontrollarm und Halteprobe bleiben |
| `scripts/mac_panel_repeat_summary.py` | MODIFY | `key_to_mouse_up`: Maus-hoch nur im 3-s-Monitorfenster nach `key`; keins → „kurz (kein Maus-hoch)“ statt Fehlpaarung (11–13 s); `how_of`/`_HOW` um die neue Kategorie; Haltedauer je Klick im Bericht |
| `scripts/test_mac_reopen_settle.py` | MODIFY | v2/v3-Erwartungen ersetzen: genau ein kurzer Klick, kein `frontmostRootClick`/`waitForFrontmostSettled`, keine Wiederholung, hart rot |
| `scripts/test_mac_panel_repeat_summary.py` | MODIFY | kurze Klicks ohne Maus-hoch, neue `how`-Kategorie |
| `.github/workflows/mac-panel-repeat.yml` | MODIFY (klein, nur falls nötig) | Kommentare; Nachweislauf mit `iterationen=40` |

### Scope Assessment
- Files: 4–5, nur Test-, Skript- und CI-Code; App-Code 0 LoC
- Estimated LoC: ca. +40 / −150 (Testcode, zählt nicht zum Limit)
- Risk Level: LOW (Produkt unberührt); Restrisiko: Open-App-Arm mit kurzem Klick noch unbelegt

### Technical Approach (Empfehlung B, bestätigt durch Plan-Bewertung)
Kurzer Klick wie ein Mensch (0,1 s) an allen Stellen, an denen der Test das Symbol klickt; keine Wiederholung, hart rot.
Reihenfolge: (1) Auswerter-Fix mit Test, (2) Helfer in `openPanel` und Nutzerarmen, alte Helfer raus, (3) Skripttests
nachziehen, (4) `mac-panel-repeat.yml` mit 40 Iterationen beider Nutzerarme, 0 Fehler, Haltedauern im Bericht,
(5) drei aufeinanderfolgende grüne Läufe „Mac Gallery (macOS)“ (DoD #978). Zeigt (4) Fehler im Open-App-Arm bei kurzer
Haltedauer, ist die Ursache dort eine andere → Stopp, neue Analyse (dann Alternative A prüfen).

### Alternativen
- **A (Vorschlag aus Befund v4):** `statusItem.click()` behalten, Haltedauer per Accessibility aus der App lesen
  (App-Code unter `--ui-testing`), über Schwelle 0,4–0,7 s genau einmal wiederholen. Nicht empfohlen: duldet die Streuung
  statt sie abzustellen und braucht App-Code für einen Test; Rückfall, falls B im Open-App-Arm scheitert.
- **C (Produkt):** Panel bei Maus-hoch öffnen bzw. langes Halten nicht schließen lassen. Abweichung vom Systemverhalten der
  Menüleiste, berührt die #862-Lösung (`dismiss()`), kein Nutzerbefund → nicht empfohlen.

### Open Questions
- Keine PO-Frage: reine Prüfwerkzeug-Arbeit; die DoD von #978 sieht den Fall „Prüfwerkzeug“ ausdrücklich vor.

## Analysis v6 (2026-11-25, nach Befund v5)

### Type
Weiter Bug im Prüfwerkzeug. Befund v5 (Lauf 45642831767): kurzer Klick 0/40 zu im Return-Arm, **1/40 zu im Open-App-Arm**,
Haltedauer ab `key` 0,616 s, Panel 17 ms nach Maus-hoch zu. Ursache bestätigt (langes Halten schließt), aber die
angeforderte Haltedauer von 0,1 s ist unter Last keine Garantie. Die Abbruchregel der Spec v5 greift → Alternative A.

### Recherche (Quellen)
- Apple-Forum 714649, Mozilla 101472: Klicken-und-Halten schließt Menüs beim Loslassen (Plattformverhalten).
- Apple-Doku `click(forDuration:thenDragTo:)`: keine Zusage zur tatsächlichen Haltedauer; keine Quelle zu gedehnter Synthese.
- Apple-Doku `OSLogStore.local()`: verlangt Admin-Konto (Forum 666679: ohne Entitlement genug), im Sandbox nur eigener
  Prozess (Forum 744806, mjtsai „OSLogStore on Monterey“). Ob der macOS-UI-Testläufer gesandboxt ist: nicht belegt → Probe.
- Test-only-Accessibility-Werte sind ein gängiges Muster; für `MenuBarExtra`/Statusobjekt keine Quelle → Probe.

### Messgrundlage für die Schwelle
Haltedauer ab `key` (App-Monitor, `key` liegt ~0,2 s nach Maus-runter): Fälle 0,616 / 0,71 / 0,90 / 0,93 s;
Erfolge kurzer Klick 0,033–0,147 s oder „kein Maus-hoch“, Erfolge `click()` ≤ 0,36 s. Schwelle **0,4 s** liegt in der Lücke;
0,616 + 0,2 ≈ 0,82 s Gesamthalten passt zum Systemwert ≥ 0,7 s (StableBar #904).

### Varianten
| Variante | Haltedauer-Quelle im Lauf | App-Code | Belegt? | Bewertung |
|---|---|---|---|---|
| B (v5, kurzer Klick, hart rot) | keine | 0 | 1/40 zu (2,5 %) | widerlegt als alleiniger Weg |
| **A-log**: kurzer Klick bleibt; bei Fehlschlag liest der Läufer per `OSLogStore.local()` die `MenuBarPanel`-Zeilen ab dem Klick, Haltedauer ab `key` ≥ 0,4 s → genau eine Wiederholung, sonst/unbekannt hart rot | vorhandenes Panel-Protokoll | 0 | Zugriff des Läufers unbelegt | **Empfehlung** |
| A-ax: App legt unter `--ui-testing` die letzte Haltedauer als Accessibility-Wert offen (Statusobjekt-Label) | App-Monitor | ~15 LoC in `MenuBarCapture.swift`/`LooseEndsApp.swift` | `MenuBarExtra`-Label-Weitergabe unbelegt | Rückfall, falls A-log keinen Zugriff hat |
| D: Klick per CGEvent vom Läufer (wie Kontrollarm) | Halten im Läufer selbst gesteuert | 0 | Kontrollarm 120/0, aber nur Return-Zustand | weicht vom XCUITest-Nutzerweg ab, den die DoD verlangt; nicht empfohlen |
| C: Produkt hält Panel trotz langem Halten offen | – | ja | – | ändert Systemverhalten, kippt #862-Lösung; nicht empfohlen |

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | `assertSymbolOpensPanelWithOneClick`/`openPanel`: nach Fehlschlag Haltedauer lesen (neuer Helfer), ≥ 0,4 s → genau ein zweiter kurzer Klick mit Anhang `retry: hold X s`, sonst hart rot mit Haltedauer in der Meldung |
| `LooseEndsUITests/MacPanelHold.swift` | CREATE | Helfer: `OSLogStore.local()`, Prädikat Subsystem+Kategorie `MenuBarPanel`, ab Klickzeit; `key` → erstes Maus-hoch im 3-s-Fenster (gleiche Regel wie der Auswerter) |
| `scripts/mac_panel_repeat_summary.py` | MODIFY | Wiederholungen zählen (Arm, Haltedauer, Ergebnis des zweiten Klicks) |
| `scripts/test_mac_reopen_settle.py`, `scripts/test_mac_panel_repeat_summary.py` | MODIFY | Erwartung „keine Wiederholung“ → „genau eine, nur über Schwelle“ |

### Scope Assessment
- Files: 4–5; App-Code 0 LoC (A-log), bei Rückfall A-ax ~15 LoC
- Estimated LoC: ca. +90 / −10 Test-/Skriptcode
- Risk Level: LOW (Produkt unberührt); Hauptrisiko: Läufer darf das Protokoll nicht lesen → dann A-ax

### Technical Approach
1. Probe zuerst (im selben Schnitt, kein Warten): Halteprobe-Arm (`halteprobe=true`, 1,0-s-Klick) ruft den neuen Helfer
   und schreibt die gelesene Haltedauer in den Anhang. Liefert er Werte ≥ 0,4 s → A-log trägt; liefert er nichts/Fehler →
   Rückfall A-ax, Spec-Nachtrag.
2. Wiederholungsregel in den Nutzerarmen und `openPanel`, Anhang je Klick mit Haltedauer und `retry`.
3. Auswerter + Skripttests.
4. `mac-panel-repeat.yml` 40 Iterationen beider Nutzerarme: 0 rote Iterationen; jede Wiederholung mit Haltedauer ≥ 0,4 s belegt.
5. Drei aufeinanderfolgende grüne Läufe „Mac Gallery (macOS)“ (DoD #978; Lauf 45642824480 zählt nicht, anderer Stand).

### Open Questions
- Keine PO-Frage: reine Prüfwerkzeug-Arbeit, die DoD von #978 sieht „Prüfwerkzeug hält zu lange → einmal wiederholen“ vor.

## Analysis v7 (2026-11-25, nach Befund v6)

Befund v6 (Lauf 45658361541, Commit c800f7b): alle 40 Klickanhänge `read hold: unknown (log not readable: Connection to logd failed)`.
Der Läufer darf `OSLogStore.local()` nicht lesen (mjtsai „OSLogStore on Monterey“, Apple-Forum 666679). Abbruchregel (a) → Rückfall A-ax.

- **A-ax (Empfehlung):** Die App misst unter `--ui-testing` in `MenuBarPanelLog` dieselbe Strecke `key` → erstes Maus-hoch (3 s) und legt sie
  als Accessibility-Wert `round=<n> <s>|short|pending` am `NSStatusBarButton` ab (per `NSApp.windows`/`NSStatusBarWindow`, Muster
  orchetect/MenuBarExtraAccess). Der Test liest `statusItems.firstMatch.value`, das er ohnehin hält. ~25 LoC App-Code, nur unter Tests wirksam.
- **TCP-Port unter `--ui-testing`** (Apple-DTS, Forum 130767: App Groups gehen für den Runner nicht): mehr Code, im Sandbox-Arm Netzwerk-Entitlement; nicht gewählt.
- **SwiftUI `.accessibilityValue` am `MenuBarExtra`-Label:** Durchreichung unbelegt; nicht gewählt.
- **D CGEvent-Klick, C Produkt:** wie v6, nicht gewählt.

Unbelegt bleibt, ob XCUITest den gesetzten Wert am Statusobjekt liest → Halteprobe zuerst; liefert sie keine Werte, Stopp und neue Analyse (TCP).
CI-Läufe (Probe, 40er-Lauf, drei Galerie-Läufe) stehen in der DoD, nicht als AC: Ein Abbruch soll keine Sperre am Gate auslösen.
