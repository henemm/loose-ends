# Adversary-Dialog feat-145-simulator-beleg

### Runde 1

Zwischenstand (kein Verdict): Code gelesen, Unit-Tests und Belege geprueft, keine Blocker.

- [x] AC-1: Gruener Lauf (CaptureSmokeTests/testPlusButtonProof): Exit 0, ergebnis Passed, TEST SUCCEEDED, head 087e829; run.xcresult per git check-ignore ignoriert (.gitignore:8); summary.json per cmp identisch mit frischer xcresulttool-Ausgabe; manifest.json und 4 PNG vorhanden; PNG geoeffnet: Startscreen "Views" mit Plus-Button oben rechts, Listen Next up/New/Due/Quick/Old/Waiting/Repeating/Parked je 0, Abschnitte Projects und Contexts, unten Completed 0. Abweichung: Methode statt ganzer Klasse (siehe F001).
Code reference: scripts/sim.sh:241
Code reference: scripts/sim_proof.py:120
- [x] AC-2: Roter Lauf: rot-lauf-1/2 zeigen Failed (11/12 bestanden, TEST FAILED); eigener Lauf mit nicht existierender Klasse: Exit 1, alter gruener Beleg war vorher geloescht, neuer Beleg ergebnis Unbekannt (0 Tests), nie Passed.
Code reference: scripts/sim.sh:231
Code reference: scripts/sim_proof.py:60
- [x] AC-3: shasum -a 256 summary.json stimmt mit Beleg-Zeile ueberein (a194edc3...); Dateimenge leer, daher keine weiteren Zeilen.
Code reference: scripts/sim_proof.py:98
- [x] AC-4: Plugin-Regex liefert null Treffer; Dateimenge (diff gegen merge-base plus untracked, Filter) enthaelt nur scripts/docs, also korrekt leer; Filter ist 1:1-Spiegel von hook_utils.py is_gated_code_path (Listen verglichen).
Code reference: scripts/sim_proof.py:84
- [x] AC-5: Ohne Argument bzw. ohne Workflow Abbruch vor cmd_generate/Werkzeug (Zeilen 229/232 vor Zeile 237); subprocess-Tests mit Stubs gruen.
Code reference: scripts/sim.sh:229
Code reference: scripts/test_sim_proof.py:117
- [x] AC-6: python3 -m unittest -v scripts/test_sim_proof.py: 11 Tests OK, Ausgabe in /tmp/adversary_test_output.txt.
Code reference: scripts/test_sim_proof.py:136
- [x] AC-7: Diff von sim.sh nur additiv (Kopfkommentar, cmd_test_proof, help-Zeilen 3,30, Dispatcher); run_xcodebuild, test, unit, report, build unveraendert; unit-run-ac7.txt zeigt Unit-Tests bestanden, unit-exit=0. Eigenen unit-Lauf nicht gestartet.
Code reference: scripts/sim.sh:477
- [x] AC-8: run_xcodebuild-Pipeline (xcodebuild | tee | xcbeautify) unter set -eo pipefail, Aufruf mit || rc=$?; Gegenprobe in bash: Teilkommando exit 65 in gleicher Pipeline liefert rc=65; Rueckgabe return "$rc" vor Hilfsskript-Code.
Code reference: scripts/sim.sh:244

### Runde 2

Zwischenstand (kein Verdict): Edge Cases versucht, nur Findings niedriger Schwere.

- [x] Edge Cases: Bundle fehlt: read_summary liefert leer, Unbekannt, Exit 1. Pfade mit Leerzeichen: alle Variablen gequotet, git mit -z. Geloeschte Dateien: --diff-filter=d. Uncommittete Aenderungen: Hash ueber Arbeitsverzeichnis. Testklasse ohne Screenshot: Beleg wird geschrieben, Exit 1 (Zeile 139). set -e: || rc=$? und || prc=$? halten den Lauf am Leben. cd PROJECT_DIR vor relativen Pfaden.
Code reference: scripts/sim_proof.py:139
Code reference: scripts/sim_proof.py:92

Finding F001: Severity MEDIUM, Category spec_violation. AC-1 nennt die ganze Klasse CaptureSmokeTests; der gruene Nachweis lief nur mit einer Methode, weil die Klasse wegen vorbestehendem flakigen Test (#165) rot ist. Das Werkzeug selbst funktioniert klassenweit (rote Laeufe zeigen Failed korrekt). Evidence: simulator-run.txt testklasse-Zeile, rot-lauf-1/2. Remediation: Abweichung im Abschlussbericht offen benennen, AC-1 nach #165 mit ganzer Klasse wiederholen oder AC anpassen. Als formale Abweichung bewertet, nicht als Werkzeugfehler.

Finding F002: Severity LOW, Category edge_case. Nicht existierende Klasse: xcodebuild liefert Exit 0 und "Test Succeeded" mit 0 Tests, Beleg ergebnis Unbekannt statt Failed. Spec AC-2 nennt dies als Beispiel mit Failed. Verhalten sicher (nie Passed, Exit 1), aber Wortlaut der Spec passt nicht. Evidence: eigener Lauf, Code reference scripts/sim_proof.py:60. Remediation: Spec-Beispiel streichen oder 0 Tests als Failed ausweisen.

Finding F003: Severity LOW, Category edge_case. Workflow-Name aus active_workflow wird nur von Whitespace befreit; "../x" oder "a/b" wuerden in rm -rf und mkdir als Pfad eingehen. Evidence: scripts/sim.sh:230-235. Remediation: Name gegen ^[A-Za-z0-9._-]+$ pruefen. Nur durch lokalen Agenten ausloesbar, daher niedrig.

Beobachtung: Der letzte gruene Lauf hing nach den 20 s Testzeit rund 10 Minuten nach (bekannte Eigenheit von sim.sh, auch bei unit); start/ende im Beleg umfassen daher 628 s. Kein Defekt von test-proof.

Tests: 11 passed, 0 failed. Regressionen: keine gefunden. Letzter Lauf: test-proof CaptureSmokeTests/testPlusButtonProof gruen, Beleg liegt.

VERDICT: AMBIGUOUS

## Geprüfte Dateien

- sha256:563d6d98c07c8755b027df24b63a33faac3fcbd3f6f5f25e5908290ae94f744b  scripts/sim.sh
- sha256:3941ecafbabc4a8627fb073c5cac6aed672637e6ba9587efba3ccd0ea130d839  scripts/sim_proof.py
- sha256:e0ccc238c4f6dddd208911491521d64b62a553acbe2ffd97994baeab3714ddbf  scripts/test_sim_proof.py
