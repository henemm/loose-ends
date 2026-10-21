# Context: fix-578-ui-test-kaltstart

## Request Summary
#578 (Teil von Epic #465): `CalendarTargetTests.testDefaultCalendarIsStampedOnSwitchOn` fällt als erster UI-Test
nach kaltem Simulatorstart in der CI. Ziel: beim ersten Versuch grün, auch als erster Test; Ursache belegt, kein
bloßes Timeout hochsetzen; 5 Läufe grün, einer davon als erster Test nach frischem Simulator.

## Befund (belegt, Quelle: roter CI-Lauf 39457247533, Job 118747226749, Artefakt `UITestResults`)
Zwei Vorfälle am 2026-10-20: PR #577 (Lauf 39378870415, Versuch 1, Log nicht mehr abrufbar) und main 696322c
(Lauf 39457247533). Der zweite ist vollständig ausgewertet. Bildfolge der Aufzeichnung:
`docs/artifacts/fix-578-ui-test-kaltstart/red-run-39457247533-bildfolge.png` (ein Bild je 8 s).

1. **Tastatur-Hinweis „Speed up your typing by sliding your finger … Continue“** liegt beim ersten Öffnen des
   Erfassen-Blatts über der Tastatur, im Bild von etwa 4:37 bis 4:38 (rund 50 s). Die CI schaltet ihn nicht ab;
   `scripts/sim.sh` tut es seit #341 (`defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true`,
   `cmd_boot`, Zeile 520/521, abgesichert durch `scripts/test_sim_lock.py`). Folge: `captureTextField` finden 23 s,
   tippen und Folgeschritte je 7–10 s, der Lauf hinkt um etwa eine Minute hinterher.
2. **Kalender-Dialog „Allow „Loose Ends“ to access your calendar?“** erscheint erst bei t≈122 s (4:39), nachdem
   der Test ihn schon gesucht hat: `allowCalendarAccessIfAsked()` wartet nur 3 s auf einen SpringBoard-Alert
   (`CalendarTargetTests.swift:261`). Der Test wartet danach auf `calendarTargetRow`, findet ihn nie, scrollt 5 Mal
   und scheitert mit „nach 5 Wischversuchen nicht erzeugt“ (Zeile 211).
3. **Der Dialog bleibt stehen.** `addUIInterruptionMonitor` greift nicht: Das Log meldet bei jeder Geste
   „Failed to construct element query matching interruption. Interrupting element Alert, foreground application
   'com.apple.springboard', element application: (null)“ (ab t=135,65 s, danach in jedem Folgetest). Der Alert
   überlebt den Neustart der App und blockiert alle weiteren Tests: 25 Folgefehler („Erfassungs-Blatt ging nicht
   auf“ usw.), verteilt auf 5 Suiten. Die Annahme im Test-Kommentar („A prompt that comes later … is caught by
   the interruption monitor on the next gesture“, `CalendarTargetTests.swift`, über `allowCalendarAccessIfAsked`)
   trifft unter iOS 27 nicht zu.
4. Der App-Hauptthread war währenddessen 22,5 s, 8 s, 7 s blockiert (`watchdog.log`), der Läufer ist unter Last
   (Übersetzen und Simulatorstart überlappen, `host-load.log`).

Recherche (2026-10-20): [Alerts von SpringBoard werden vom Interruption-Handler seit iOS 17 nicht automatisch
behandelt, Apple bestätigt den Fehler, Umgehung: SpringBoard direkt abfragen und den Knopf tippen, außerhalb des Handlers](https://developer.apple.com/forums/thread/737880);
[Handler laufen nur bei einer Geste und nicht für jeden Alert](https://developer.apple.com/documentation/xctest/handling-ui-interruptions.md);
`simctl privacy <udid> grant|reset calendar <bundle-id>` setzt die Berechtigung vorab (in `speech-stress.yml:77` schon
für `reset all` im Einsatz).

Nicht belegt: Der erste Vorfall (PR #577) zeigt laut Ticket dieselbe Signatur (29 s bis `captureTextField`, 10 s
Wartezeit danach), sein Log ist überschrieben. Konsistent mit dem Befund, aber kein Beweis.

## Related Files
| File | Relevance |
|------|-----------|
| `.github/workflows/ci.yml` (Job `ui-smoke`, Zeilen 104–195) | bootet den Simulator, schaltet weder Tastatur-Hinweis ab noch setzt er Kalender-Rechte |
| `scripts/sim.sh` (`cmd_boot`, Z. 520) | schaltet den Tastatur-Hinweis lokal ab; Vorbild |
| `scripts/test_sim_lock.py` (Z. 197 ff.) | prüft, dass `cmd_boot` den Hinweis abschaltet; Muster für einen Test der CI-Datei |
| `LooseEndsUITests/CalendarTargetTests.swift` | drei Tests; `allowCalendarAccessIfAsked` (3 s, Z. 261), Monitor (Z. 16, 118), `scrollUntilVisible` (Z. 275) |
| `LooseEnds/Calendar/CalendarBridge.swift` (Z. 259 ff.) | `ensureAccess()` fragt `requestFullAccessToEvents()`; mit vorab erteilter Berechtigung kommt kein Dialog |
| `.github/workflows/speech-stress.yml` (Z. 77) | setzt Rechte per `simctl privacy` zurück |

## Existing Patterns
- Simulator-Vorbereitung in der CI steht als Schritte vor dem Testlauf (Warten auf Boot, Poster-Dienste aus, #228).
- `sim.sh boot` bereitet den lokalen Simulator vor (#341); die CI hat ihre eigene, nicht gleiche Vorbereitung.
- Änderungen an der Testumgebung werden durch ein Python-Skript in `scripts/test_*.py` abgesichert.

## Dependencies
- Upstream: `simctl` (privacy, spawn defaults), Xcode 27.0 auf dem Läufer `xcode-27`, iOS-27.0-Simulator.
- Downstream: alle UI-Tests im Job `UI Smoke` (der Hinweis betrifft jede erste Texteingabe, der Kalender-Dialog
  jeden Test, der den Kalender einschaltet), `docs/reference/abnahme-und-arbeitsweise.md` (falls dort die
  Simulatorvorbereitung steht).

## Existing Specs
- Keine Spec zu den Kalender-UI-Tests; Hintergrund #203 (Kalender), #341 (Testläufe), #228 (Simulator beruhigen).

## Risks & Considerations
- Nachstellen im Simulator ist nötig (Reproduktion zuerst). Er ist bis etwa 22:30 von einer anderen Sitzung gesperrt
  (`/tmp/loose-ends-testlauf.lock`, restock-08); vorher nur Lesen und Planen.
- Der Kalender-Dialog selbst gehört zum Nutzerablauf. Vorab erteilte Rechte (`simctl privacy grant`) machen die Tests
  deterministisch, prüfen aber den Dialog nicht mehr. Alternative: Dialog behalten und den Alert über
  `XCUIApplication(bundleIdentifier: "com.apple.springboard")` mit langer Frist suchen. Entscheidung gehört in die Spec.
- Ein einmal stehender Alert zieht die ganze Suite mit. Auch mit Fix braucht der Test eine Absicherung, die den
  Alert beseitigt oder laut meldet, statt 25 Folgetests rot zu färben.
- Änderung bleibt klein (CI-Datei, 1 Testdatei, 1 Skripttest), unter den Scoping-Limits.

## Analysis

### Type
Bug in der Testumgebung (nicht in der App). Aus Nutzersicht: der Kalender-Dialog selbst ist richtig, nur der
Testlauf stellt den Zustand, in dem er gefragt wird, nicht sicher her.

### Ursachen (alle am roten Lauf belegt, siehe Befund oben)
| # | Ursache | Beleg | Behebbar |
|---|---------|-------|----------|
| 1 | Tastatur-Hinweis in der CI nicht abgeschaltet | Bildfolge, ~50 s auf dem Erfassen-Blatt; `sim.sh boot` schaltet ihn seit #341 ab, `ci.yml` nicht | ja |
| 2 | Test wartet nur 3 s auf den Kalender-Dialog | `CalendarTargetTests.swift:261`; Dialog kam bei t≈122 s, Frist lief bei t≈121 s ab | ja |
| 3 | Stehender SpringBoard-Alert wird vom Interruption-Handler nicht entfernt | Log „Failed to construct element query matching interruption“ in jedem Folgetest; Apple-Forum 737880 | nur umgehen |
| 4 | Läufer unter Last (Hauptthread der App 22,5 s blockiert) | `watchdog.log`, `host-load.log` | nein, nur Frist-Abhängigkeit mindern |

Ursache 1 verlängert alles, 2 macht den Test rot, 3 macht aus einem roten Test eine rote Suite.

### Lösungswege
| Weg | Was | Dafür | Dagegen |
|-----|-----|-------|---------|
| A (Empfehlung) | Eine gemeinsame Simulator-Vorbereitung für CI und `sim.sh boot`: Tastatur-Hinweis aus und Kalender-Zugriff vorab per `simctl privacy grant calendar` | Beseitigt 1, 2 und 3 an der Wurzel, kein Dialog kann mehr stehen bleiben; ein Ort statt zweier, die auseinanderlaufen | Der Systemdialog wird nicht mehr durchgespielt; das ist Apples Dialog, die App ruft nur `requestFullAccessToEvents` |
| B | Hinweis aus wie in A, Dialog bleibt, Test sucht ihn mit langer Frist direkt in SpringBoard und tippt „Allow Full Access“ | Dialogpfad bleibt getestet | Bleibt fristabhängig (Ursache 4), ein verpasster Dialog zieht wieder die Suite mit; Apple nennt genau diese Umgehung selbst anfällig |
| C | Nur das Timeout von 3 s auf 30 s erhöhen | eine Zeile | Das Ticket verbietet es ohne Begründung; Ursache 1 und 3 bleiben, die Suite kann weiter kippen |

Bisherige Entscheidung, die A kippt: Im Test-Kommentar steht, ein später Dialog werde vom Handler bei der nächsten
Geste gefangen (#203). Das ist unter iOS 27 widerlegt. Keine ADR betroffen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/sim_prepare.sh` | CREATE | Hinweis aus + Kalender-Zugriff erteilen, ein Aufruf mit der Simulator-UDID |
| `.github/workflows/ci.yml` | MODIFY | Schritt „Simulator vorbereiten“ im Job `ui-smoke` nach dem Boot-Warten |
| `scripts/sim.sh` | MODIFY | `cmd_boot` ruft die gemeinsame Vorbereitung statt der Einzelzeile |
| `scripts/test_sim_lock.py` | MODIFY | Test: `sim_prepare.sh` setzt beides, `cmd_boot` und `ci.yml` rufen es auf |
| `LooseEndsUITests/CalendarTargetTests.swift` | MODIFY | Falschen Kommentar zum Handler berichtigen, Frist-Rückfall behalten |

### Scope Assessment
- Files: 5
- Estimated LoC: +60/-5
- Risk Level: MEDIUM (CI-Konfiguration wirkt auf alle UI-Tests)

### Beweisplan (Reproduktion zuerst)
1. Frischer Wegwerf-Simulator `LE-578-repro` ohne Vorbereitung, der Test als erster Lauf, so wie in der CI.
   Erwartet: Hinweis im Bild, Kalender-Dialog kommt nach der Frist oder bleibt stehen.
2. Mit Vorbereitung auf einem zweiten frischen Simulator: derselbe Ablauf, Hinweis und Dialog erscheinen nicht.
3. DoD des Tickets: 5 Läufe grün, davon einer als erster Test nach frischem Simulator, in der CI.
Stand: siehe „Nachstellen am 2026-10-21“ unten.

### Open Questions
- [ ] Reicht ein ruhiger Mac, um die Verzögerung nachzustellen, oder braucht es künstliche Last (wie bei der anderen Sitzung)?
- [ ] Weg A oder B: A ist die Empfehlung, weil Weg B dieselbe Fristabhängigkeit behält.

### Nachstellen am 2026-10-21 (lokal, `sim.sh test`, frischer Wegwerf-Simulator, danach gelöscht)
Der Fehler ließ sich lokal NICHT auslösen. Der Test lief jedes Mal grün.

| Lauf | Aufbau | Ergebnis |
|------|--------|----------|
| 1 | frischer Simulator, Hinweis nicht abgeschaltet, Test als erster | grün, 107 s; Texteingabe sofort, Kalender-Dialog kam innerhalb der 3 s |
| 2 | wie 1, Software-Tastatur erzwungen (Simulator-Voreinstellung) | grün, 105 s; Berechtigung stammte aus Lauf 1, daher kein Dialog (kein gültiger Lauf für den Dialog) |
| 3 | Berechtigung zurückgesetzt, Dialogfrist im Test künstlich auf 0,1 s | grün, 3 Tests in 158 s; der späte Dialog wurde vom Handler bei der nächsten Geste (dem Wischen in `scrollUntilVisible`) gefangen |

Folgerungen:
- Lauf 3 belegt, dass die Annahme im Test-Kommentar lokal gilt. In der CI galt sie nicht: dort meldet XCTest
  „Failed to construct element query matching interruption … element application: (null)“. Das Verhalten hängt also von
  Last und Zeitablauf ab und lässt sich auf einem ruhigen Mac nicht erzwingen.
- Auf diesem Mac erschien der Tastatur-Hinweis nicht (kein Zeitverlust bei der Texteingabe), in der CI schon. Der Beleg
  dafür bleibt das Video des CI-Laufs.
- Die Ursachenkette 1 bis 3 ist damit am CI-Lauf belegt, lokal aber nicht ausgelöst. Der Beweis „Fehler weg“ kann nur
  aus der CI kommen (5 Läufe grün, einer als erster Test nach frischem Simulator), plus ein Schritt-Log der CI, das
  zeigt, dass Hinweis und Berechtigung gesetzt waren.
- Das stützt Weg A: Er entfernt den Dialog, also genau die Klasse, die unter Last kippt. Weg B würde sie behalten.
- Offen, falls doch lokal nachgestellt werden soll: Prozessorlast auf dem Mac (belastet andere Sitzungen).

Aufräumen: Die temporären Änderungen an `scripts/sim.sh` und `CalendarTargetTests.swift` sind zurückgenommen, die
Simulator-Voreinstellung ist wiederhergestellt, `LE-578-repro` ist gelöscht.
