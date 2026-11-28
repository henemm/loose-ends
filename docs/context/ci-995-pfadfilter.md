# Context: ci-995-pfadfilter (#995)

## Request Summary
#995: CI prüft nur, was geändert wurde. Ein reiner Skript-/Doku-PR soll alle Pflicht-Checks in **unter 10 min** erfüllen,
ein App-PR läuft weiter voll. PO 2026-11-24: „das ist doch nicht mehr Verhältnismäßig!!!!!!“

## Stand (2026-11-28)
Der Pfadfilter selbst ist **schon ausgeliefert** (mit #993, 2026-11-24): Job `changes` (ubuntu) + `scripts/ci_changes.py`,
Tests `scripts/test_ci_changes.py`; App-Jobs mit `if: needs.changes.outputs.app == 'true'`, Sammeljob `ui-smoke`
wertet „übersprungen + app=false“ als bestanden, Push auf `main` = immer `app=true`.

DoD-Punkte laut Issue-Kommentar 2026-11-24:
1. **Dauer < 10 min — offen.** Letzter reiner Doku-PR #1018 (Lauf 46116156915): 11 min 25 s gesamt, davon
   Schritt „Script tests“ im Job `Unit Tests (macOS destination)` ≈ 11 min. Lauf 45397060999 (#993): Script tests 11 min 35 s.
2. **Beleg App-PR — erfüllt.** #1017 (Lauf 46068343454): alle 16 Jobs `success`, nichts übersprungen.

## Messung Skripttests (lokal, MacBook Air, 10 Kerne)
- Seriell (`unittest discover`, wie CI): **539 s**, 936 Tests, CPU nur 30 % → Zeit ist Warten (Subprozesse, sleeps, Timeouts), nicht Rechnen.
- Teuerste Module: test_asc_store_submit 98 s, test_sim_run_xcodebuild 65 s, test_sim_lock 50 s, test_asc_beta_invite 41 s,
  test_asc_store_version 38 s. Einzeltest-Spitze: `test_store_version_script_untouched` 37 s, `test_parallel_takeover_of_orphan_lock` 20 s,
  sechs Wächtertests in test_sim_run_xcodebuild je ~8 s.
- Je Modul ein Prozess, parallel: **4 Worker 144 s, 8 Worker 120 s, keine Fehler** (57 Module). Die Tests isolieren sich
  schon selbst (z. B. Sperre in eigenem Temp-Ordner per `LOOSEENDS_LOCK_DIR`).

## Related Files
- `.github/workflows/ci.yml` (728 Z.): Job `unit-tests`, Schritt „Script tests“ (Z. 51–55): venv, pyyaml+pillow, `unittest discover -s scripts -p 'test_*.py' -v`.
- `scripts/test_ci_xcode27.py`: `test_unit_job_runs_every_script_test` (Z. 123) prüft den Aufruf; `test_every_job_runs_on_xcode_27_with_the_action` (Z. 95).
- `scripts/test_ci_changes.py`: `test_unit_tests_always_run_the_script_tests` (Z. 64), `test_smoke_summary_passes_when_spared` (Z. 73).
- `scripts/ci_changes.py`: Pfadregel.
- CLAUDE.md: Abschnitt CI (Zeile „CI runs on … every job uses the composite action“).

## Existing Patterns
- Nur Standardbibliothek in Skripten (keine neuen Abhängigkeiten ohne Freigabe; pytest-xdist wäre eine).
- Workflow-Struktur wird von Python-Tests gegen das YAML gehalten (test_ci_xcode27, test_ci_changes).

## Dependencies / Dependents
- Pflicht-Checks des Hauptzweigs: Unit Tests (macOS destination), Build (iOS Simulator), UI Smoke (iOS Simulator),
  Shipped languages, UI iPad (iOS Simulator), Mac Gallery (macOS). Namen dürfen sich nicht ändern.
- Jede parallele Sitzung, deren PR durch die CI muss.

## Risks
- Parallel laufende Testmodule könnten sich gemeinsame Ressourcen teilen (Temp-Dateien, Umgebungsvariablen, Ports) →
  lokal 2× parallel grün, aber auf dem CI-Rechner (weniger Kerne) prüfen.
- Ausgabe paralleler Läufe vermischt sich → je Modul gesammelt ausgeben, Fehler am Ende benennen.
- Wartezeit auf einen freien macOS-Rechner (Lauf 45397060999: Sammeljob `ui-smoke` startete erst 36 min nach den
  Skripttests) — liegt außerhalb der Testdauer, aber zählt für „Pflicht-Checks in < 10 min“. Kandidat: Sammeljob und
  `languages` auf ubuntu (Präzedenz: `changes`); widerspricht der Regel „jeder Job nutzt select-xcode-27“.

## Analysis

**Type:** Feature (Beschleunigung der CI für reine Skript-/Doku-PRs; Pfadfilter selbst seit #993 vorhanden)

### Affected Files
| Datei | Change | Grund |
|---|---|---|
| `scripts/run_script_tests.py` | CREATE | stdlib-Läufer: je Testmodul ein Prozess (`python -m unittest <mod> -v`), ThreadPool, längste zuerst, Ausgabe je Modul als Block (bei Fehler vollständig), Liste der roten Module am Ende, Exit 1 bei Fehler / 0 Modulen / Zeitlimit je Modul |
| `scripts/test_run_script_tests.py` | CREATE | Läufer findet dieselben Module wie `glob scripts/test_*.py`, roter Modul → Exit 1, leer → Exit 1 |
| `.github/workflows/ci.yml` | MODIFY | Schritt „Script tests“ ruft den Läufer statt `unittest discover`; Sammeljob `ui-smoke` und `languages` auf `ubuntu-latest` (brauchen nur Python/Shell) |
| `scripts/test_ci_xcode27.py` | MODIFY | Erwartung auf den Läufer umstellen; Ausnahme von „jeder Job auf xcode-27“ für `changes`, `ui-smoke`, `languages` |
| `CLAUDE.md` | MODIFY | CI-Zeile: Ausnahmen der xcode-27-Regel, parallele Skripttests |

App-Code: 0 (alles Werkzeug/CI); Läufer ~70 LoC, Tests ~60 LoC.

### Scope / Risk
- Risiko mittel: Pflicht-Checks hängen daran. Namen bleiben unverändert („Script tests“, „UI Smoke (iOS Simulator)“, „Shipped languages“).
- Parallelität: Explore-Befund — keine festen Pfade, keine festen Ports; `os.chdir`/`os.environ`-Änderungen nur innerhalb eines Moduls (test_asc_crashes, test_asc_what_to_test, test_asc_review_notes) → mit **Prozessen** je Modul sogar besser isoliert als heute (heute leckt es über `discover` in Folgemodule). Threads innerhalb eines Prozesses wären falsch.
- Untergrenze ≈ 100 s (test_asc_store_submit 98 s).

### Varianten (Plan-Agent, B–D geschätzt)
| Variante | Skripttests | Wirkung auf „< 10 min“ |
|---|---|---|
| heute | 539 s lokal, ~11 min CI | 11,5 min, verfehlt |
| **A** paralleler stdlib-Läufer | 120–144 s lokal, CI geschätzt 3–5 min | ~5–6 min, erfüllt |
| B langsamste Tests entschärfen | ~390 s seriell | ~8–9 min, knapp; fasst wacklige Zeit-/Sperrtests an |
| C alles auf ubuntu | unverändert | löst nur Warteschlange; Skripttests brauchen macOS (sim.sh, bash 3.2) |
| D eigener Skripttest-Job | unverändert | hilft Skript-PR nicht |

**Empfehlung:** A, dazu Sammeljob `ui-smoke` und `languages` auf ubuntu (aus C nur der gefahrlose Teil: sie brauchen kein Xcode).
Damit belegt ein Skript-PR nur noch **einen** macOS-Rechner statt drei → weniger Warten in der Warteschlange
(Lauf 45397060999: Sammeljob startete 36 min verspätet). Fallende Regel: „jeder Job läuft auf xcode-27 mit select-xcode-27“
(CLAUDE.md, test_ci_xcode27) — gilt künftig für Jobs, die Xcode brauchen.

### Technical Approach
1. RED: `test_run_script_tests.py`, angepasste Erwartungen in `test_ci_xcode27.py`.
2. Läufer schreiben; Worker `max(4, min(8, cpu_count))`, Umgebungsvariable `SCRIPT_TESTS_WORKERS`; Zeitlimit je Modul 600 s.
3. ci.yml umstellen; CLAUDE.md.
4. Lokal voll grün; Beleg am eigenen PR (berührt nur scripts/.github/CLAUDE.md → `.github/` zählt als App → voller Lauf = App-Beleg) und an einem reinen Doku-PR danach (Zeit < 10 min).

### Dependencies
- Einzelmodul-Aufrufe in asc-*.yml bleiben unberührt (laufen einzelne Dateien).

### Open Questions
- keine (technische Entscheidung; Warteschlangen-Kapazität des Kontos liegt außerhalb und wird nicht weiter verfolgt, solange ein Skript-PR nur einen macOS-Rechner belegt).
