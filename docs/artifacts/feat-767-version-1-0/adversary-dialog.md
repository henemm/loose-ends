# Adversary Dialog — feat-767-version-1-0
Spec: docs/specs/tooling/feat-767-version-1-0.md
Datum: 2026-10-30 19:45

## Checkliste
- [x] **AC-1:** `project.yml` setzt `MARKETING_VERSION` auf `"1.0"`; es gibt genau eine solche Zeile. Geprüft durch `test_marketing_version_is_1_0`.
- [x] **AC-2:** `testflight.yml` trägt kein Versions-Literal (`MARKETING="<Ziffern>"`) mehr; beide Archivprüfungen (iOS, macOS) lesen `MARKETING` aus `project.yml`. Geprüft durch `test_no_version_literal_in_workflow` und `test_workflow_reads_version_from_project_yml`.
- [x] **AC-3:** Der in `testflight.yml` stehende Auslese-Befehl liefert, in bash ausgeführt, genau den Wert aus `project.yml` (echte Datei: `1.0`; Temp-Kopie mit anderem Wert: dieser Wert). Geprüft durch `test_workflow_reads_version_from_project_yml`.
- [x] **AC-4:** Fehlt der Wert oder ist er leer, bricht der Prüfblock mit Exit ≠ 0 und `::error::MARKETING_VERSION not found in project.yml` ab, der Upload findet nicht statt. Geprüft durch `test_empty_version_aborts`.
- [x] **AC-5:** `scripts/test_ci_xcode27.py` lässt unter `.github/` genau die zwei lesenden Zeilen zu und schlägt bei jeder anderen Erwähnung von `project.yml` oder einem `sed -i` weiter an; `scripts/test_asc_wait_build.py` bleibt grün (jeder Block von `testflight.yml` besteht `bash -n`), und `python3 -m unittest discover -s scripts` ist grün. Geprüft durch diesen Lauf.
- [x] **AC-6:** `docs/reference/testflight.md` nennt die erwartete Version `1.0 (<Lauf-Nummer>)` und dass die Archivprüfung sie aus `project.yml` liest; `0.1.0` steht dort nicht mehr als erwartete Version. Geprüft durch Lesen der Datei im Diff und `grep -n "0\.1\.0" docs/reference/testflight.md` (kein Treffer als erwartete Version).
- [x] **AC-7:** Simulator-Stufe: Die frisch generierte App baut, und die Einstellungen zeigen Version 1.0. Nachweis: Screenshot per `./scripts/sim.sh screenshot`, geöffnet und beschrieben.

## Dialog

### Runde 1
**Adversary:** Beweis je AC verlangt und selbst erhoben.

Confirmation:
  AC: AC-1
  Code reference: project.yml:24
  Evidence: genau eine Zeile `MARKETING_VERSION: "1.0"`; Z. 76 ff. sind `CFBundleShortVersionString: $(MARKETING_VERSION)` und passen weder auf das sed-Muster noch auf die Testregex. test_marketing_version_is_1_0 OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: .github/workflows/testflight.yml:148
  Evidence: kein `MARKETING="<Ziffer>"` mehr; Auslese Z. 148 (iOS) und Z. 424 (macOS), Abbruch Z. 149/425. Kommentar Z. 6 `v1.0`. Beide Zeilen stehen nach `BUILD="${BUILD:?}"` und vor der ersten Nutzung von $MARKETING (Z. 174 / 445), per Skript geprueft.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/test_marketing_version.py:46
  Evidence: Test fuehrt die Zeile aus testflight.yml in bash aus: echte Datei `1.0`, Temp-Kopie `2.3.4`. Lauf OK (4 Tests).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/test_marketing_version.py:61
  Evidence: ohne MARKETING_VERSION-Zeile Exit != 0, `::error::MARKETING_VERSION not found in project.yml`, "weiter" wird nicht ausgegeben. Robustheit des sed: Kommentar am Zeilenende, Tab-Einrueckung, ungequoteter Wert ergeben leere Auslese und damit Abbruch (fail closed); eine zweite Zeile ergibt einen mehrzeiligen Wert, der den Versionsvergleich (Z. 174) fehlschlagen laesst (ebenfalls fail closed).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/test_ci_xcode27.py:25
  Evidence: test_ci_xcode27 27 Tests OK, test_asc_wait_build 21 OK, Gesamtlauf `unittest discover -s scripts`: 395 Tests, OK, EXIT 0 (docs/artifacts/feat-767-version-1-0/adversary-test-output.txt). `bash -n` je Pruefblock Exit 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: docs/reference/testflight.md:288
  Evidence: grep auf `0.1.0` in der Datei ohne Treffer; Z. 288 nennt Lesen aus project.yml, Z. 292 `1.0 (<Lauf-Nummer>)`.
  Status: CONFIRMED

AC-7: kein Beweis vorhanden, bleibt offen.

**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Gegenproben zu AC-5 (Schutztest) mit Temp-Anhaengen an testflight.yml und sofortiger Wiederherstellung (Datei danach identisch, diff --stat unveraendert):
- zusaetzliches `sed -i "..." project.yml`: Test FAILED (gut)
- `cat project.yml`, Kommentar `# see project.yml`: FAILED (gut)
- `sed -i s/a/b/ foo.txt`, `echo 26.0`: FAILED (gut)
- erlaubte Zeile plus Anhang: FAILED (gut)
- Duplikat einer der beiden erlaubten Zeilen: OK (nicht gefangen)
- `sed -ni ...` und `sed  -i` (zwei Leerzeichen): OK (nicht gefangen)

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_ci_xcode27.py:92
  Description: Der Schutztest laesst jede Zeile durch, die einer der beiden erlaubten Zeilen gleicht, auch ein drittes Vorkommen; "genau zwei" wird dort nicht erzwungen (fuer die Auslesezeile erzwingt es test_marketing_version.py:48).
  Spec requirement: AC-5 — "genau die zwei lesenden Zeilen"
  Conflict: Ein Duplikat bleibt unentdeckt; harmlos, da die Zeile nur liest.
  Remediation: optional Trefferzahl auf 2 pruefen.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/test_ci_xcode27.py:92
  Description: Das grep-Muster `sed -i` erkennt `sed -ni` oder `sed  -i` nicht. Muster unveraendert seit vorher, keine Regression.
  Spec requirement: AC-5 — "jedes sed -i bleibt verboten"
  Conflict: Nur im Sinne der bisherigen Muster erfuellt.
  Remediation: Muster erweitern (eigenes Ticket).

Weitere Dateien: Code reference: scripts/test_marketing_version.py:20 (Auslesezeilen kommen aus dem Workflow, geprueft wird, was laeuft); Code reference: docs/reference/testflight.md:292.

Regressionen: keine; Nutzer von MARKETING in testflight.yml (Z. 174, 445) unveraendert, Gesamtlauf gruen, nichts uebersprungen.

**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Confirmation:
  AC: AC-7
  Code reference: project.yml:24
  Evidence: sim-build.log endet mit "Build Succeeded", rc=0; plutil auf der gebauten LooseEnds.app liefert CFBundleShortVersionString = 1.0. Screenshot docs/artifacts/feat-767-version-1-0/adversary-screenshot.png geoeffnet: Einstellungen, Abschnitt "About", Zeile "Version" mit Wert "1.0 (1)" (1 = Simulator-Buildnummer). Der Weg war ein Wegwerf-UI-Test mit XCTAttachment statt `sim.sh screenshot` (Zeile erst nach Scrollen sichtbar; Log sim-version-proof.log: 1 Test bestanden); die Testdatei ist geloescht (LooseEndsUITests ohne Aenderung). Die Abweichung vom Werkzeug ist akzeptabel, weil der Screenshot echte App-Zustand im Simulator zeigt und der Beleg der Spec (Version 1.0 in den Einstellungen) damit erbracht ist. Maschineller Beleg simulator-run.txt: test-proof SettingsSmokeTests Passed, 1/1.
  Status: CONFIRMED

Alle ACs belegt; F001/F002 sind LOW und blockieren nicht.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:fef0686965e497815ba37381cabe0c07927aaf867ac63ffa8f79fe52883c27d2  .github/workflows/testflight.yml
- sha256:418a8a7162ea302b9a86c55bba6c65937f3e94ed0080c39890bdc26c907bff77  docs/reference/testflight.md
- sha256:bcf99de78c1784e3c3092a22a595517bd3be69048a50a55aa9c4d771fbdf871b  project.yml
- sha256:8c846fbfa6de6a7dbfe6e774c55658b6ac997339bd502d6c6e0ed139f599b882  scripts/test_ci_xcode27.py
- sha256:706a13c3abce83c2a1231650e971836a0ee9fc9359a0ab23a9451b6a6318f5c4  scripts/test_marketing_version.py

## Prüfbasis

- base: 991c2e62abc40f2122c9a9da0afb67f14b6a9d47
- blob:b32c89f7bdb2dc5e4f011bc4cc40efad72c16e87  .github/workflows/testflight.yml
- blob:c3c44ac7a437b88a16ddec9418e5a37438c09864  docs/reference/testflight.md
- blob:c220cfcf398b15d26502b083a61968a8a68406cd  project.yml
- blob:7286159366fe6439f83cfbcb41b1939fc26d3fd5  scripts/test_ci_xcode27.py
- blob:881e63c7568fd07d96f2525a7be07407e31e87f9  scripts/test_marketing_version.py
