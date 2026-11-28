# Adversary Dialog — ci-995-pfadfilter
Spec: docs/specs/ci/ci-995-skripttests-parallel.md
Datum: 2026-11-28 08:04

## Checkliste
- [x] **AC-1:** Der Läufer findet genau die Module von `glob scripts/test_*.py` und keine anderen (Test 1).
- [x] **AC-2:** Ein rotes Modul führt zu Exit 1, seine volle Ausgabe wird gedruckt, und die Schlusszeile nennt es mit Namen (Test 2).
- [x] **AC-3:** Ein Verzeichnis ohne Testmodule führt zu Exit 1 (Test 3).
- [x] **AC-4:** Ein hängendes Modul, das das (für den Test konfigurierbare) Zeitlimit überschreitet, führt zu Exit 1 und steht in der Liste der roten Module (Test 4).
- [x] **AC-5:** `ci.yml` ruft im Schritt „Script tests“ (Name unverändert, ohne `if`, vor „Build and test“) den Läufer mit dem Python der venv auf und kein `unittest discover` mehr; die Jobs `ui-smoke` und `languages` laufen auf `ubuntu-latest` ohne `select-xcode-27`; die Jobnamen der sechs Pflicht-Checks sind unverändert; `test_ci_xcode27.py` und `test_ci_changes.py` bilden das ab und sind grün.
- [x] **AC-6:** Die ganze Skript-Suite läuft lokal über den Läufer grün in unter 4 Minuten (Messung 2026-11-28: 120 bis 144 s bei 4 bis 8 Workern).

## Dialog

### Runde 1
**Adversary:** Behauptung: Läufer ist sauber. Angriffe: Import-Absturz eines Moduls, Enkelprozess bei Zeitlimit, ungültige Umgebungswerte, nicht vorhandener Ordner, vermischte Ausgabe, Flakiness bei 8 Workern.
**Implementierer:** (Belege aus eigenen Läufen)
- AC-1: `modules()` ist `Path(folder).glob("test_*.py")`; Code reference: scripts/run_script_tests.py:22; Test test_finds_exactly_the_glob_modules grün; Lauf nennt 58 Module = `ls scripts/test_*.py | wc -l` (58).
- AC-2/AC-3: Import-Absturz (`raise` auf Modulebene) wird als `===== ROT test_crash =====` mit vollem Traceback gedruckt, Exit 1; leerer oder nicht vorhandener Ordner: Exit 1 (`return 0 if results and not red else 1`). Code reference: scripts/run_script_tests.py:73.
- AC-4: Modul mit Enkelprozess (`sleep 300`) bei SCRIPT_TESTS_TIMEOUT=2: Lauf nach 3 s beendet, Exit 1, Modul rot, `pgrep -f "sleep 300"` leer, also Prozessgruppe samt Enkel beendet (`start_new_session=True` + `os.killpg`). Code reference: scripts/run_script_tests.py:46.
- Ausgabe: Blöcke werden unter `LOCK` gedruckt, nicht vermischt (Läufe gelesen).
**Adversary:** Und ungültige Eingaben?
**Implementierer:** SCRIPT_TESTS_WORKERS=0 -> ValueError aus ThreadPoolExecutor, `=abc` -> ValueError in workers(), SCRIPT_TESTS_TIMEOUT=abc -> ValueError in main: jeweils Traceback und Exit 1, nie ein falsches Grün (Findings F001). `os.killpg` auf schon beendete Gruppe würde ProcessLookupError werfen (Race zwischen Timeout und Ende): dann bricht `pool.map` mit Traceback ab, Exit 1, ebenfalls kein falsches Grün (F002, nicht ausgelöst).

### Runde 2
**Adversary:** Flakiness durch geteilte Ressourcen (/tmp/loose-ends-testlauf.lock in test_sim_lock) und CI-Verdrahtung.
**Implementierer:** Zwei volle Läufe der Suite über den Läufer: Standard-Worker 193 s (parallel zu meinen Proben, test_asc_store_submit allein 192,9 s) Exit 0, 58 Module, 0 rot; SCRIPT_TESTS_WORKERS=8 112 s Exit 0, 58 Module, 0 rot. Beide unter 240 s (AC-6); der Standardlauf hat unter Last wenig Reserve (F003). Zusätzlich test_run_script_tests (6 Tests), test_ci_xcode27 (30), test_ci_changes (11) einzeln grün.
- AC-5: Schritt „Script tests“ ohne `if`, ruft `"$RUNNER_TEMP/script-tests/bin/python" scripts/run_script_tests.py`, kein `unittest discover` mehr (grep leer). Code reference: .github/workflows/ci.yml:51-55. Jobs `ui-smoke` (Zeile 391) und `languages` (413) `ubuntu-latest`, ohne select-xcode-27; `languages` nutzt nur `python3 scripts/shipped_languages.py` (nur re/pathlib, lokal Ausgabe `["en","de"]`), ubuntu hat python3; `ui-smoke` nur Shell; Abhängigkeiten: `ui-smoke-lang` needs languages (Ausgabe `list` unverändert), `ui-smoke` needs changes und ui-smoke-shard; Jobnamen unverändert. Code reference: scripts/test_ci_xcode27.py:1; CLAUDE.md:282.
- Hinweis: Das Kind läuft mit cwd=scripts/, `discover -s scripts` ließ cwd im Repo-Root; die ganze Suite ist so grün, also kein Befund, nur Abweichung von der Spezformulierung.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine verdächtigen Schreibstellen: das Werkzeug schreibt keine Felder aus Produktcode.


## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/run_script_tests.py:29
  Description: ungültiges SCRIPT_TESTS_WORKERS (abc, 0, negativ) bzw. SCRIPT_TESTS_TIMEOUT löst ValueError mit Traceback aus.
  Spec requirement: AC-2 — Exit 1 bei Fehler
  Conflict: Exit bleibt 1, nur die Meldung ist unschön; kein falsches Grün.
  Remediation: Werte prüfen, klare Fehlermeldung.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/run_script_tests.py:46
  Description: os.killpg ohne Schutz gegen ProcessLookupError, wenn das Kind genau zwischen Timeout und Kill endet.
  Spec requirement: AC-4
  Conflict: Lauf bricht mit Traceback ab (Exit 1), statt das Modul als rot zu melden; extrem selten.
  Remediation: try/except ProcessLookupError um killpg.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_run_script_tests.py:1
  Description: AC-6 hat unter Last wenig Reserve: test_asc_store_submit dauerte 192,9 s allein, Gesamtlauf 193 s; es gibt keine Teilung des längsten Moduls.
  Spec requirement: AC-6 — unter 4 min
  Conflict: bleibt knapp unter 240 s, aber auf langsamen Runnern kann die Grenze reißen.
  Remediation: schwerstes Modul beschleunigen (eigenes Ticket).

Confirmation:
  AC: AC-1
  Code reference: scripts/run_script_tests.py:22
  Evidence: glob test_*.py, 58 Module gefunden
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: .github/workflows/ci.yml:51
  Evidence: Läuferaufruf mit venv-Python, ubuntu-Jobs ohne Xcode-Auswahl, Tests grün
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: CLAUDE.md:282
  Evidence: CI-Absatz nennt Ausnahmen und Läufer
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_ci_xcode27.py:1
  Evidence: Suite 193 s bzw. 112 s, 0 rot; CLAUDE.md:282 dokumentiert die Änderung
  Status: CONFIRMED

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 58 Module passed, 0 failed, 0 übersprungen (zwei volle Läufe)
Edge cases: nur LOW-Funde (F001-F003), kein falsches Grün
Regressions: None found
Checklist: 6/6 points proven

## Geprüfte Dateien

- sha256:659adc6b89e1bd574fc1ed7975c83533e8b6c9f41431066631d0cdfc3e6d204d  .github/workflows/ci.yml
- sha256:c379822ed30abfa5b94d3785a91a9b6135c3c475faf9a7ad9dc153502d84ce91  CLAUDE.md
- sha256:0443b251f5716988f90ef2b46e10ad2734868381fbcfad8f4da73db30b3e4698  scripts/run_script_tests.py
- sha256:9a5cdb5950605d0e9df5227f67b9be9be844d52c6dcaf40fcf278ac74ada276f  scripts/test_ci_xcode27.py
- sha256:6ece43e92eff420c55dc1234c506045fb40f05201eb93dbd3653e51b242774b1  scripts/test_run_script_tests.py

## Prüfbasis

- base: 5290f5d4da4cbb2d59fa6c26b907fd13fad8b9fb
- blob:ff169dec678f6bb24c4c652ca11cbfc189af6873  .github/workflows/ci.yml
- blob:90bed4d05060562048c3980bebae4ce5da905106  CLAUDE.md
- blob:cb21f2cf4cf42a7ef9d7f322ba01a32247af3fe7  scripts/run_script_tests.py
- blob:f7935c9f36d844c04f09d0a321e0d34d40609e4e  scripts/test_ci_xcode27.py
- blob:e32fe77520586293c4fa6157e28f9f61af457588  scripts/test_run_script_tests.py
