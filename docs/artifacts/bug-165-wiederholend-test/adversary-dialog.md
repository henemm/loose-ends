# Adversary-Dialog bug-165-wiederholend-test

### Runde 1

Beleg-Pruefung: shasum -a 256 LooseEndsUITests/CaptureSmokeTests.swift = 2e3f1280...aca99, identisch mit
"Geprueften Dateien" in simulator-run.txt. Beleg gehoert zum aktuellen Arbeitsstand (head b0b3945 + uncommittete Testdatei, Pruefsumme gleich).
test-green-output.txt: drei test-proof-Laeufe, je "Executed 12 tests, with 0 failures", Beleg "Passed, 12/12, TEST SUCCEEDED".
Funktionslaengen in CaptureSmokeTests alle <= 50 Zeilen (awk-Pruefung ohne Treffer). Kein Probe-Rest (0.05) in der Datei.

- [x] AC-1: openRepeatingFromEditor geht dreimal zurueck, tippt viewRow_repeating, sucht taskRow(in:) (BEGINSWITH 'taskRow_'). Kein Titel.
Code reference: LooseEndsUITests/CaptureSmokeTests.swift:79
- [x] AC-2: openMenu erkennt !row.exists || detailRawText.exists, tippt Zurueck, wartet auf Detail weg und Zeile hittable, Folge bleibt [1.2,1.5,2.0]. Probe ac2-probe.txt: ohne Rueckweg ROT, mit Rueckweg GRUEN.
Code reference: LooseEndsUITests/CaptureSmokeTests.swift:53
- [x] AC-3: openMenu-Aufrufe in testDoneFromMenuEmptiesNew und testCompletedTaskShowsUnderCompleted im Diff unveraendert (nur Zeilensuche per AC-8); Oeffnet das Menue beim ersten Druck, kehrt die Schleife vor dem neuen Zweig zurueck.
Code reference: LooseEndsUITests/CaptureSmokeTests.swift:259
- [x] AC-4: Ablauf menuDone, Zeile bleibt (repeating.waitForExistence), deleteFromMenu (menuDelete, confirmDeleteButton), waitForNonExistence, captureButton-Pruefung vorhanden.
Code reference: LooseEndsUITests/CaptureSmokeTests.swift:402
- [x] AC-5: Drei Laeufe gruen mit aktivem Modell (test-green-output.txt), Beleg aus sim.sh test-proof, Pruefsumme passt.
Code reference: LooseEndsUITests/CaptureSmokeTests.swift:30
AC-6 (nachgelagert, Phase 7): Vorbedingung erfuellt (ci.yml unveraendert, Test ueber den Rueckweg deterministisch). Der erste CI-Versuch ist vor dem Push grundsaetzlich nicht belegbar, Commit ist bis zum Verdict gesperrt. Nachweis (Ergebnisprotokoll ohne Wiederholung) erfolgt in Phase 7; hier nicht abgehakt.
- [x] AC-7: git diff main: 04-stand.md entfernt genau #20, #21, #74; #22/#24/#67 usw. bleiben, Reihenfolge gleich, Spike-Liste neu nummeriert 1-2; keine Restverweise auf die drei.
Code reference: docs/project/04-stand.md:36
- [x] AC-8: Alle label==Titel-Suchen entfernt (grep: nur noch High/Weekly/Daily-Optionen und Menuepunkte, keine Aufgabentitel); taskRow_* ueberall; Inhalt ueber assertDetailRawText.
Code reference: LooseEndsUITests/CaptureSmokeTests.swift:32

Runde-1-Fragen: Wird AC-8 schwaecher? Trifft taskRow die falsche Zeile?

### Runde 2

- [x] Zusicherungsstaerke: Wo vorher nur "Titel sichtbar" galt, gilt jetzt Zeile existiert UND (testCapturedTaskShowsUpInNew, PlusButtonProof, DetailShowsRawText, Importance, Repeat, Subtask, Calendar, Completed) Detail zeigt unveraenderlichen Rohtext mit XCTAssertEqual. Keine Zusicherung entfernt; testDoneFromMenuEmptiesNew prueft weiter Verschwinden der Zeile, jetzt auch bei umbenanntem Titel (vorher trivial gruen). Staerker, nicht schwaecher.
Code reference: LooseEndsUITests/CaptureSmokeTests.swift:40
- [x] Falsche Zeile: taskRow_* wird nur in TaskRow.swift:62 vergeben (Subtask-Zeilen heissen subtaskRow_), --ui-testing-Speicher ist leer, jeder Test erfasst genau eine Aufgabe; firstMatch trifft daher die eine. Restrisiko: ein kuenftiger Test mit zwei Aufgaben (Doku-Kommentar vermerkt es).
Code reference: LooseEnds/Views/TaskRow.swift:62
- [x] Rueckweg-Randfall: Nach dem letzten Fehlversuch (2,0 s) tippt openMenu zurueck, drueckt nicht mehr; der Aufrufer-Assert schlaegt dann klar fehl, kein Haenger.
Code reference: LooseEndsUITests/CaptureSmokeTests.swift:58
- [x] Eigener Lauf: test CaptureSmokeTests/testDeletingRecurringTaskAfterCompletionDoesNotCrash gestartet; Ergebnis lag bei Protokollabschluss noch nicht vor (xcodebuild baut/laeuft). Urteil stuetzt sich auf die drei Belegslaeufe mit passender Pruefsumme.

Findings:
- F001 LOW edge_case, LooseEndsUITests/CaptureSmokeTests.swift:32 -- taskRow(in:).firstMatch haengt an der Annahme einer Aufgabe pro Test. Remediation: Kommentar vorhanden; bei Mehr-Aufgaben-Tests Rohtext-Filter.
- F002 LOW anti_pattern, docs/artifacts/bug-165-wiederholend-test/simulator-run.txt -- Beleg-head b0b3945 ist nicht der Stand mit Aenderung (uncommittet); gebunden nur ueber Datei-Pruefsumme (stimmt). Remediation: nach Commit Beleg neu erzeugen, falls Gate Commit-Kennung prueft.
- F003 LOW edge_case, LooseEndsUITests/CaptureSmokeTests.swift:53 -- AC-2 nur per Wegwerf-Probe belegt (Verzoegerung 0,05 s), in den Gruenlaeufen greift der Rueckweg nicht natuerlich. Akzeptabel.

AC-6: Vorbedingung erfuellt, Nachweis in Phase 7.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:003691af5887904b7636fa3c6bcce8b4b532649e842e943ad1c21d1032c12b6a  LooseEnds/Views/TaskRow.swift
- sha256:2e3f12802826189246a9573192a2ae977c048b017ea517c41b53a015738aca99  LooseEndsUITests/CaptureSmokeTests.swift
- sha256:08492ee9fc72a276d9d98739e0589f50d1a377297dddf27a7501668f22848c08  docs/project/04-stand.md
