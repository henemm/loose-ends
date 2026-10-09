# Adversary Dialog — fix-298-testlauf-nachlauf
Spec: docs/specs/fast/fix-298-testlauf-nachlauf.md
Datum: 2026-10-09 22:40

## Checkliste
- [x] 1. `run_xcodebuild test …` hängt `-collect-test-diagnostics never` an, übrige Argumente erhalten (Beleg: Shell-Probe mit Platzhalter-xcodebuild: `[test][-project][P][-only-testing:A/B][-collect-test-diagnostics][never][-derivedDataPath]…`; alle vier Aufrufer sim.sh:186, 299, 309, 334 rufen mit `test` an erster Stelle; Option in Xcode 27 per `xcodebuild -help` vorhanden)
- [x] 2. Andere Aktionen bekommen die Option nicht (Beleg: Probe `build -p x` und `test-without-building -p x` ohne Option; Aufrufer build sim.sh:195, 202; Gerätebauten/lab rufen run_xcodebuild nicht mit `test`)
- [x] 3. Roter Test: kein simctl diagnose, Nachlauf 2 s statt 258 s (Beleg: nachlauf-vorher-rot.txt nachlauf_s 258 mit diagnose-Prozess; nachlauf-nachher-rot.txt nachlauf_s 2, kein diagnose, rc=65)
- [x] 4. Grüner UI-/Unit-Lauf: Nachlauf < 30 s, rc und `** TEST SUCCEEDED **` unverändert, Beleg-Eingaben intakt (Beleg: nachlauf-nachher-ui.txt 2 s rc=0; nachlauf-nachher-unit.txt Gesamtlauf 8 s rc=0; eigener Export der Screenshots aus dem Nachher-xcresult liefert PNG, Summary "Passed"; test_sim_proof grün)
- [x] 5. CI-Workflows unverändert (Beleg: Diff gegen origin/main für .github ist leer)

## Dialog

### Runde 1
**Adversary:** Wirkt die Option nur bei `test` an erster Stelle? Was bei `test-without-building`, leeren Argumenten (`set -u`), Argumenten mit Leerzeichen, und bricht die Zeile mit `&&` unter `set -e`/pipefail bei `build` ab oder verschluckt den Rückgabewert? Ist der Rückgabewert eines roten Laufs weiter 65?
**Implementierer:** Eigene Proben (Platzhalter-xcodebuild im PATH, Funktion wörtlich aus sim.sh, `set -euo pipefail`): `build` läuft durch (rc=0, keine Option); `test-without-building` bekommt die Option bewusst nicht (kein Aufrufer, siehe F002); leere Argumente ohne Fehler; `-only-testing:with space` bleibt ein Argument; `STUBRC=65` mit `test` liefert Exit 65. `bash -n scripts/sim.sh` ok. Unittest-Lauf scripts: 91 Tests, OK, 0 übersprungen (adversary-test-output.txt).

### Runde 2
**Adversary:** Sind die Messbelege tragfähig? Nachher-Unit hat keine Ergebniszeile, Vorher-UI zeigt einen simctl-Prozess unter Restock-DerivedData. Wurde test-proof nach der Änderung je gefahren? Fehlen mit `never` Anhänge/Screenshots im Ergebnisbündel?
**Implementierer:** Vorher-rot ist sauber (Session-Pfad LooseEnds-session-fix298, 258 s, diagnose-Prozess gesehen), Nachher-rot/ui zeigen 2 s ohne diagnose. Vorher-ui ist verunreinigt (fremder Prozess, kein Ergebniszeitpunkt), Nachher-unit hat keinen Ergebniszeitpunkt (Messmuster griff nicht), aber Gesamtdauer 8 s beweist unter 30 s. test-proof wurde nach der Änderung nicht gefahren; ersatzweise habe ich das Ergebnisbündel des Nachher-UI-Laufs selbst geprüft: Summary "Passed", Screenshot-Export liefert detail-target-calendar PNG. Damit sind die Eingaben von sim_proof.py erhalten. Rest: F001 (LOW).

## Findings
[
 {"id": "F001", "severity": "LOW", "category": "edge_case", "description": "Kein echter test-proof-Lauf nach der Aenderung; Vorher-UI-Messung verunreinigt, Nachher-Unit ohne Ergebniszeit.", "evidence": "nachlauf-vorher-ui.txt; scripts/sim.sh:334", "remediation": "Beim naechsten test-proof-Lauf Beleg pruefen."},
 {"id": "F002", "severity": "LOW", "category": "edge_case", "description": "Nur die Aktion test an erster Stelle wird erfasst; test-without-building bekaeme die Option nicht. Kein heutiger Aufrufer betroffen.", "evidence": "scripts/sim.sh:134", "remediation": "Bei neuem Aufrufer mit anderer Aktion Bedingung erweitern."}
]

## Confirmations
Code reference: scripts/sim.sh:134 — die Zeile mit der Option hängt sie nur bei test an, bleibt unter set -euo pipefail und leeren Argumenten fehlerfrei (AC 1, 2).
Code reference: scripts/sim.sh:299 — sim-unit/test/test-proof (Z. 186, 309, 334) rufen run_xcodebuild mit test an erster Stelle und nutzen die Rückgabe unverändert (AC 1, 4).
Code reference: scripts/test_sim_run_xcodebuild.py:55 — Test prüft Option bei test samt erhaltenen Argumenten und Abwesenheit bei build gegen die wörtlich aus sim.sh gelesene Funktion; 91/91 Tests grün (AC 1, 2).

## Herkunft der Vorbedingungen
kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:a28f2e1e81c443fbe6e64c68a9745a62351347349aa371006120b4593b6296df  scripts/sim.sh
- sha256:6354dd3386c2da51f38953c13134565852cb91d5877baf7f5ee881b4d3201196  scripts/test_sim_run_xcodebuild.py

## Prüfbasis

- base: 6a0853bacaebf9f52530d4fd3762cf640b13456e
- blob:4dd59b687f5f8ead246d1e3d5d9b3964294a60ab  scripts/sim.sh
- blob:2bae14966c7b7800dd9f253ceff497955b798a75  scripts/test_sim_run_xcodebuild.py

## Geprüfte Dateien

- sha256:a28f2e1e81c443fbe6e64c68a9745a62351347349aa371006120b4593b6296df  scripts/sim.sh
- sha256:6354dd3386c2da51f38953c13134565852cb91d5877baf7f5ee881b4d3201196  scripts/test_sim_run_xcodebuild.py

## Prüfbasis

- base: 6a0853bacaebf9f52530d4fd3762cf640b13456e
- blob:4dd59b687f5f8ead246d1e3d5d9b3964294a60ab  scripts/sim.sh
- blob:2bae14966c7b7800dd9f253ceff497955b798a75  scripts/test_sim_run_xcodebuild.py
