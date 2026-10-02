# Adversary-Dialog fix-172-ui-tests-first-try

Prüfer: implementation-validator (nur gelesen, Diff und Protokolle; keine Dateien geändert, keine Simulator-Läufe).

### Runde 1 (Beweise einfordern, Diff und Protokolle lesen)

- [x] AC-1 Reproduktion
  Code reference: docs/artifacts/fix-172-ui-tests-first-try/red-run-delay.txt:32
  - red-run-delay.txt zeigt "testCalendarSwitchStaysOn, XCTAssertTrue failed - Value was Optional(0)", Ergebnis Failed nach 26 s. red-run-1.txt (ohne Verzögerung) ist grün: der Fehler entsteht erst unter künstlicher Auflösezeit, was die Spec ausdrücklich zulässt.
- [x] AC-2 Fix belegt
  Code reference: docs/artifacts/fix-172-ui-tests-first-try/green-run-delay.txt:28
  - Derselbe Test besteht bei 53 s (jedes Lesen 6 s), "Test Succeeded". Die Wegwerf-Verzögerung steckt nicht im Endstand (kein Treffer für sleep/Thread./delay/Dispatch in den beiden geänderten Testdateien).
- [x] AC-3 waitForValue/valueAfterWaiting
  Code reference: LooseEndsUITests/CaptureSmokeTests.swift:117
  - Frist per Uhrzeit, nach Fristende genau ein letztes Lesen; Anfangswert "0" direkt gelesen; Ersatz-Tippen nur bei Wert "0" nach dem letzten Lesen. Randfälle (Wert schon "1", langsame Auflösung, Endlosschleife) geprüft.
- [x] AC-4 RecognitionWalkthroughTests
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:121
  - topRow + detailRawText ("Rasen mähen"), row(containing:in:) gelöscht, Zusicherung zur zweiten Aufgabe nicht im Diff. Kein Substring-Konflikt mit "mähen Rasen".
- [x] AC-6 Wiederholung entfernt
  Code reference: .github/workflows/ci.yml:127
  - Genau eine Zeile entfernt, kein Treffer mehr für retry-tests, YAML lädt, Fortsetzungszeilen intakt.
- [x] AC-8 Kein Produktcode
  Code reference: .github/workflows/ci.yml:127
  - Diff berührt genau ci.yml, CaptureSmokeTests.swift, RecognitionWalkthroughTests.swift (+25/-14 ohne Artefakte).
- [x] AC-9 Geräteliste
  Code reference: LooseEndsUITests/CaptureSmokeTests.swift:117
  - Kein Pfad der Geräteliste berührt.
- Offen bis nach dem Merge (bewusst NICHT abgehakt, kein Kästchen, damit das Gate sie nicht als bewiesen liest): AC-7 Drei CI-Läufe grün ohne ##[error]-Zeile (erst nach Push möglich); AC-10 Ausliefern per sync-main (erst nach Merge). Kein Defekt, beide in /60-validate und /70-deploy nachzuweisen.

### Runde 2 (AC-5 kritisch, Gegenprobe)

- [x] AC-5 test-proof grün
  Code reference: docs/artifacts/fix-172-ui-tests-first-try/test-green-capture-2.txt:64
  - CaptureSmokeTests 12/12 bei Load 2,98; RecognitionWalkthroughTests 1/1 (bei Load 95-117); Simulator-Beleg gültig.
  - Der erste volle Capture-Lauf (test-green-capture.txt, Load 12-17) hatte 2 Fehler: CaptureSmokeTests.swift:568 (unveränderte 5-s-Frist nach Zurück-Navigation) und testSubtaskCanBeAddedAndChecked (Zeile 505, unveränderte 5-s-Frist). Beide gehören nicht zum belegten Root Cause und nicht zum Fix, sind aber dieselbe Fehlerklasse "feste 5-s-Frist unter Runner-Last". Ein Vergleichslauf mit altem Code unter derselben Last fehlt.

Findings

- F-1 (LOW, edge_case)
  Code reference: LooseEndsUITests/CaptureSmokeTests.swift:552
  - Das Ersatz-Tippen entscheidet an einer Lesung nach 2 s; reagiert die App erst später, tippt der Ersatzweg doppelt. Enger als vorher, nicht null. Kein Merge-Blocker.
- F-2 (MEDIUM, edge_case)
  Code reference: LooseEndsUITests/CaptureSmokeTests.swift:568
  - Zwei weitere Tests mit unveränderten 5-s-Festfristen wurden unter Last rot. Ohne Wiederholung bleibt das Risiko für das Ticketziel offen. AC-7 (drei CI-Läufe) entscheidet; bei Rot greift der Rückfall "Wiederholung sichtbar machen"; sonst als Folgearbeit unter demselben Ziel bündeln.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:be80b5fb7be34880ef3f6d3439498bb85fb19fd32665e30040ae76bcc1125035  .github/workflows/ci.yml
- sha256:96be9c62f8f17e306c9454abcd5452d5d56e6c1a155144ebdc84546c1637244b  LooseEndsUITests/CaptureSmokeTests.swift
- sha256:e0c67332c26134bf3a61fdf4eac053442be9aa6bc554d8b591dddadd9e260785  LooseEndsUITests/RecognitionWalkthroughTests.swift
- sha256:517874de36d0fd8f3d04f1b69851875d4b6b973ca54a8dfee52f4d386b765ee0  docs/artifacts/fix-172-ui-tests-first-try/green-run-delay.txt
- sha256:060264620cbf985c8ac97f19f78a2eec44d9e2d750f2fabc32cf83e7ae25b037  docs/artifacts/fix-172-ui-tests-first-try/red-run-delay.txt
- sha256:2a2fab41ffdd6c11c7a7db3e07b9619d767ec45126bd4947f4354950fcc64ce6  docs/artifacts/fix-172-ui-tests-first-try/test-green-capture-2.txt

## Geprüfte Dateien

- sha256:be80b5fb7be34880ef3f6d3439498bb85fb19fd32665e30040ae76bcc1125035  .github/workflows/ci.yml
- sha256:96be9c62f8f17e306c9454abcd5452d5d56e6c1a155144ebdc84546c1637244b  LooseEndsUITests/CaptureSmokeTests.swift
- sha256:e0c67332c26134bf3a61fdf4eac053442be9aa6bc554d8b591dddadd9e260785  LooseEndsUITests/RecognitionWalkthroughTests.swift
- sha256:517874de36d0fd8f3d04f1b69851875d4b6b973ca54a8dfee52f4d386b765ee0  docs/artifacts/fix-172-ui-tests-first-try/green-run-delay.txt
- sha256:060264620cbf985c8ac97f19f78a2eec44d9e2d750f2fabc32cf83e7ae25b037  docs/artifacts/fix-172-ui-tests-first-try/red-run-delay.txt
- sha256:2a2fab41ffdd6c11c7a7db3e07b9619d767ec45126bd4947f4354950fcc64ce6  docs/artifacts/fix-172-ui-tests-first-try/test-green-capture-2.txt
