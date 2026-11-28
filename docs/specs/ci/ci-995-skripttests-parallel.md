---
entity_id: ci-995-skripttests-parallel
type: feature
created: 2026-11-28
updated: 2026-11-28
status: draft
workflow: ci-995-pfadfilter
---

# Spec: Skripttests parallel, Sammeljobs auf ubuntu (#995)

## Approval

- [ ] Approved

## GitHub Issue

#995. Analyse: `docs/context/ci-995-pfadfilter.md` (Abschnitte „Stand“, „Messung Skripttests“ und „Analysis“, verbindlich). Reiner CI- und Werkzeugumbau: **kein App-Code, kein Pfad der Geräteliste.** Keine für den PO sichtbare Produktänderung.

## Purpose

Der Pfadfilter aus #993 ist ausgeliefert, ein reiner Skript- oder Doku-PR braucht aber noch gut 11 Minuten (Lauf 46116156915: 11 min 25 s), weil der Schritt „Script tests“ im Job „Unit Tests (macOS destination)“ allein rund 11 Minuten dauert. Diese Spec führt die Skripttests je Testmodul in einem eigenen Prozess parallel aus (lokal 539 s seriell gegen 120 bis 144 s parallel) und verlegt die Sammeljobs `ui-smoke` und `languages`, die kein Xcode brauchen, auf ubuntu. So belegt ein Skript-PR nur noch einen macOS-Rechner, und alle Pflicht-Checks sind in unter 10 Minuten erfüllt.

Ohne Parallelität geht es nicht, weil: die Skripttests seriell 539 s brauchen bei nur 30 % CPU-Auslastung (Warten auf Subprozesse, `sleep`, Timeouts), Beleg Messung 2026-11-28; der Gesamtlauf liegt damit über der 10-Minuten-Vorgabe, auch wenn alle anderen Jobs übersprungen sind.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Es entsteht keine neue Architekturentscheidung. Die Regel „jeder CI-Job läuft auf `xcode-27` mit `select-xcode-27`“ (CLAUDE.md, `scripts/test_ci_xcode27.py`) wird auf Jobs eingeengt, die Xcode brauchen; `changes` (#993) ist dafür schon Präzedenz. Die Namen der Pflicht-Checks bleiben unverändert.
- **Alternativen:**
  - (B) Die langsamsten Tests entschärfen (`test_store_version_script_untouched` 37 s, Sperrtests): rund 390 s seriell, ~8 bis 9 Minuten, knapp, und fasst wacklige Zeit- und Sperrtests an. Eigenes Vorhaben, hier nicht enthalten.
  - (C) Alles auf ubuntu: löst nur die Warteschlange; die Skripttests brauchen macOS (`sim.sh`, bash 3.2).
  - (D) Eigener Skripttest-Job: hilft einem Skript-PR nicht, weil der Job ebenso Pflicht-Check wäre und gleich lange läuft.
  - pytest-xdist: wäre eine neue Abhängigkeit ohne Freigabe; der stdlib-Läufer genügt.

## Source

| Datei | Änderung |
|---|---|
| `scripts/run_script_tests.py` | Neuer Läufer: je Testmodul `scripts/test_*.py` ein Prozess `python -m unittest <modul> -v` mit Arbeitsordner `scripts/` (wie `unittest discover -s scripts`), `ThreadPoolExecutor` (Threads nur zum Warten auf die Prozesse), Worker `max(4, min(8, cpu_count))`, überschreibbar mit der Umgebungsvariable `SCRIPT_TESTS_WORKERS`, längstes Modul zuerst, Zeitlimit je Modul 600 s (zählt als Fehler, Prozess wird beendet) |
| `scripts/test_run_script_tests.py` | Tests des Läufers (siehe Test Plan) |
| `.github/workflows/ci.yml` | Schritt „Script tests“ (Name und fehlendes `if` bleiben) ruft den Läufer mit dem Python der venv; Jobs `ui-smoke` und `languages` auf `ubuntu-latest` ohne `select-xcode-27` |
| `scripts/test_ci_xcode27.py` | Erwartung für den Läufer statt `unittest discover` (weiter „vor Build and test“); Ausnahmeliste der xcode-27-Regel: `changes`, `ui-smoke`, `languages` |
| `CLAUDE.md` | CI-Absatz um ein bis zwei Sätze |

**Ausgabe des Läufers:** Jedes Modul schreibt sofort nach seinem Ende einen Block: bei Fehler die vollständige Ausgabe (stdout und stderr), bei Erfolg eine Zeile mit Modulname, Dauer und Testzahl. Die letzte Zeile nennt die Zahl der Module, die Zahl der roten und deren Namen. Exit 0 nur, wenn mindestens ein Modul lief und alle bestanden haben; Exit 1 bei jedem roten Modul, bei null gefundenen Modulen und bei Zeitüberschreitung.

**Reihenfolge längste zuerst:** feste Liste der bekannten schweren Module (`test_asc_store_submit`, `test_sim_run_xcodebuild`, `test_sim_lock`, `test_asc_beta_invite`, `test_asc_store_version`) vorn, der Rest nach Dateigröße absteigend, dann Name. Das ist nur eine Planung der Wartezeit und beeinflusst kein Ergebnis.

**Isolation:** Je Modul ein eigener Prozess isoliert `os.chdir` und `os.environ`-Änderungen (heute leckt es über `discover` in Folgemodule). Threads im selben Prozess sind ausdrücklich verboten.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| Python 3 Standardbibliothek (`subprocess`, `concurrent.futures`, `glob`, `os`) | Bibliothek | einzige Abhängigkeit des Läufers, keine neue |
| `scripts/test_*.py` (57 Module) | Eingabe | werden einzeln aufgerufen, bleiben unverändert |
| `.github/workflows/ci.yml` Jobs `unit-tests`, `ui-smoke`, `languages`, `changes` | CI | Aufruf des Läufers, Wechsel des Runners |
| `scripts/test_ci_changes.py` | Test | `test_unit_tests_always_run_the_script_tests`, `test_smoke_summary_passes_when_spared` müssen grün bleiben |
| Branch-Schutz auf `main` | GitHub | verlangt Unit Tests (macOS destination), Build (iOS Simulator), UI Smoke (iOS Simulator), Shipped languages, UI iPad (iOS Simulator), Mac Gallery (macOS); Namen unverändert |
| `.github/workflows/asc-*.yml` | CI | rufen einzelne Testdateien auf, bleiben unberührt |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/run_script_tests.py` | CREATE | paralleler stdlib-Läufer, ~70 LoC |
| `scripts/test_run_script_tests.py` | CREATE | Tests des Läufers, ~60 LoC |
| `.github/workflows/ci.yml` | MODIFY | Läuferaufruf, zwei Jobs auf ubuntu-latest |
| `scripts/test_ci_xcode27.py` | MODIFY | neue Erwartung, Ausnahmeliste |
| `CLAUDE.md` | MODIFY | CI-Absatz |

### Estimated Changes

- Files: 5
- LoC: +150/−15, davon App-Code 0 (nur Werkzeug, Tests und CI)

## Out of Scope

- Kapazität der macOS-Warteschlange des Kontos.
- Einzelne langsame Tests beschleunigen (Variante B), Untergrenze des Läufers bleibt ≈ 100 s (`test_asc_store_submit` 98 s).
- Alle anderen Jobs (`ios-build`, `ui-smoke-plan`, `ui-smoke-shard`, `ui-smoke-lang`, `ui-ipad`, `mac-gallery`) bleiben auf `xcode-27`.
- Der Pfadfilter selbst (`scripts/ci_changes.py`) bleibt unverändert.

## Implementation Details

`scripts/run_script_tests.py` sucht Module mit `glob("scripts/test_*.py")` relativ zum eigenen Ordner, bildet daraus Modulnamen (ohne `.py`) und startet je Modul `sys.executable -m unittest <modul> -v` mit `cwd=scripts/`. Ein Worker-Thread wartet je Prozess mit `subprocess.run(..., timeout=...)`; bei `TimeoutExpired` gilt das Modul als rot mit einem Vermerk in der Ausgabe. Das Zeitlimit je Modul ist ein Parameter des Einstiegs (Standard 600 s) und über eine Umgebungsvariable (`SCRIPT_TESTS_TIMEOUT`) setzbar, damit der Test des Läufers es auf wenige Sekunden stellen kann. Das Verzeichnis mit den Modulen ist ebenfalls ein Parameter (Standard: Ordner des Skripts), damit der Test ein leeres und ein künstliches Verzeichnis prüfen kann. Ausgaben werden unter einer Sperre geschrieben, damit sich Blöcke nicht vermischen.

In `ci.yml` bleibt die venv-Einrichtung (`pyyaml`, `pillow`) wie heute; der Schritt ruft statt `unittest discover` den Läufer mit dem venv-Python auf. `ui-smoke` und `languages` brauchen nur Shell und Python und wechseln auf `runs-on: ubuntu-latest`; ihr `select-xcode-27`-Schritt entfällt. Die Jobnamen („UI Smoke (iOS Simulator)“, „Shipped languages“) bleiben.

## Test Plan

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN das echte Verzeichnis `scripts/` WHEN der Läufer die Module sammelt THEN entspricht die Menge genau den Dateien von `glob scripts/test_*.py` (ohne `.py`).
- [ ] Test 2: GIVEN ein temporäres Verzeichnis mit einem grünen und einem roten Testmodul WHEN der Läufer läuft THEN ist der Exit-Code 1, die Ausgabe des roten Moduls steht vollständig da, und die letzte Zeile nennt dessen Namen und keinen anderen.
- [ ] Test 3: GIVEN ein temporäres Verzeichnis ohne `test_*.py` WHEN der Läufer läuft THEN ist der Exit-Code 1.
- [ ] Test 4: GIVEN ein Modul, das länger schläft als das auf 2 s gestellte Zeitlimit WHEN der Läufer läuft THEN ist der Exit-Code 1, das Modul steht in der Liste der roten, und der Lauf endet deutlich vor dem Schlafende des Moduls.
- [ ] Test 5: GIVEN zwei grüne Testmodule WHEN der Läufer läuft THEN ist der Exit-Code 0 und die letzte Zeile nennt zwei Module und null rote.
- [ ] Test 6: GIVEN `SCRIPT_TESTS_WORKERS=2` und ohne diese Variable bei bekannter Kernzahl WHEN die Workerzahl bestimmt wird THEN ist sie 2 bzw. `max(4, min(8, cpu_count))`.
- [ ] Test 7: GIVEN `.github/workflows/ci.yml` WHEN `scripts/test_ci_xcode27.py` und `scripts/test_ci_changes.py` laufen THEN sind sie grün mit den neuen Erwartungen (Läuferaufruf, Ausnahmeliste).

## Acceptance Criteria

- **AC-1:** Der Läufer findet genau die Module von `glob scripts/test_*.py` und keine anderen (Test 1).
- **AC-2:** Ein rotes Modul führt zu Exit 1, seine volle Ausgabe wird gedruckt, und die Schlusszeile nennt es mit Namen (Test 2).
- **AC-3:** Ein Verzeichnis ohne Testmodule führt zu Exit 1 (Test 3).
- **AC-4:** Ein hängendes Modul, das das (für den Test konfigurierbare) Zeitlimit überschreitet, führt zu Exit 1 und steht in der Liste der roten Module (Test 4).
- **AC-5:** `ci.yml` ruft im Schritt „Script tests“ (Name unverändert, ohne `if`, vor „Build and test“) den Läufer mit dem Python der venv auf und kein `unittest discover` mehr; die Jobs `ui-smoke` und `languages` laufen auf `ubuntu-latest` ohne `select-xcode-27`; die Jobnamen der sechs Pflicht-Checks sind unverändert; `test_ci_xcode27.py` und `test_ci_changes.py` bilden das ab und sind grün.
- **AC-6:** Die ganze Skript-Suite läuft lokal über den Läufer grün in unter 4 Minuten (Messung 2026-11-28: 120 bis 144 s bei 4 bis 8 Workern).

## Definition of Done

- [ ] Skripttests grün (AC-1 bis AC-6).
- [ ] `CLAUDE.md`-CI-Absatz nennt den parallelen Läufer und die Ausnahmen der xcode-27-Regel.

Belege aus dem echten CI-Lauf (Phase 7, bewusst keine ACs, weil das QA-Gate keinen Aufschub kennt); die Zahlen stehen im PR und in #995:

- [ ] **Beleg A (App-Beleg):** Der PR berührt `.github/` und zählt daher als App-Änderung (voller Lauf): alle 16 Jobs sind `success`, nichts übersprungen.
- [ ] **Beleg B (Dauer):** Ein anschließender reiner Doku-PR erfüllt alle Pflicht-Checks in unter 10 Minuten ab Laufstart, gemessen an den Jobdauern.

Kein Pfad der Geräteliste berührt.

## Abnahme

Stufe 1 (Skripttests über den Läufer) und der echte CI-Lauf auf dem PR; Belege A und B oben. „Kein Pfad der Geräteliste berührt.“ Keine Testpunkte für Henning, keine sichtbare Änderung am Produkt.

## Risiken

- Parallele Module könnten gemeinsame Ressourcen teilen: Befund der Analyse zeigt keine festen Pfade oder Ports, lokal 4 und 8 Worker ohne Fehler. Auf dem CI-Rechner mit weniger Kernen wird es durch Beleg A geprüft.
- Vermischte Ausgabe: je Modul als Block, Fehler vollständig und am Ende benannt.
- Die Pflicht-Checks hängen am Workflow: AC-5 sichert die Namen; ein Wechsel von `ui-smoke` und `languages` auf ubuntu wird durch Beleg A bestätigt.
- Wartezeit auf macOS-Runner bleibt außerhalb der Testdauer; ein Skript-PR belegt künftig nur einen macOS-Rechner statt drei.

- Docstrings, die `unittest discover` als lokalen Aufruf nennen (test_catalog_languages, test_mac_reopen_settle, test_mac_panel_repeat_summary), bleiben: der serielle Aufruf funktioniert weiter, der Läufer ersetzt ihn nur in der CI.
- `scripts/test_run_script_tests.py` wird vom Läufer selbst mit eingesammelt; seine Testfälle starten den Läufer nur gegen eigene Temp-Verzeichnisse, nie gegen `scripts/` (keine Rekursion).

## Offene Fragen

Keine für den PO.

## Changelog

- 2026-11-28: Initial spec created
