# Context: feat-145-s2-gate (#145, Schnitt 2 — Beleg erzwingen)

## Request Summary
Kein `phase8_complete` ohne gültigen, maschinell erzeugten Simulator-Beleg (`simulator-run.txt`), der zum
aktuellen Stand der Produktionsdateien passt und nicht von Hand entstanden sein kann. Das Gate sitzt im Plugin
`henemm/agent-os-openspec`, ist für mehrere Belegtypen ausgelegt (Kommentar 2026-09-28) und härtet nach der
Tech-Lead-Entscheidung vom 2026-10-01: Ergebnis aus `run.xcresult` neu ableiten, Schreibsperre, Prüfsummen.

## Stand
- Schnitt 1 erledigt (PR #167): `scripts/sim.sh test-proof <Klasse>` → `scripts/sim_proof.py` schreibt
  `docs/artifacts/<wf>/simulator-run.txt` + `simulator-run/{summary.json,*.png,run.xcresult}` (Bündel gitignored).
- Im Plugin 3.41.0 kennt kein Hook `simulator_run`, `simulator-run` oder `xcresult`. Kein Plugin-Ticket dafür
  (henemm/agent-os-openspec#313 im Issue-Kommentar ist ein anderes Thema: qa_gate/unittest, geschlossen).
- Schnitt 3 (Doku) folgt danach; `docs/project/04-stand.md` ist aufgelöst (2026-10-12) → Ziel ist
  `docs/reference/abnahme-und-arbeitsweise.md` + Projekt-`CLAUDE.md`.

## Related Files
| File | Relevance |
|------|-----------|
| `agent-os-openspec/core/hooks/workflow.py:271` | `VALID_ARTIFACT_TYPES` — neuer Typ `simulator_run` |
| `agent-os-openspec/core/hooks/workflow.py:1068-1093` | Phase-8-Gate in `_validate_transition`: heute nur Adversary-Verdict + `check_dialog_evidence` — zweite Bedingung kommt daneben |
| `agent-os-openspec/core/hooks/workflow.py:1537-1558` | `cmd_add_artifact`: prüft nur den Typ; Pfad/Inhalt ungeprüft (Lücke aus Kommentar 2026-09-28) |
| `agent-os-openspec/core/hooks/workflow.py:1415-1452` | `cmd_set_field` mit `_SET_FIELD_PROTECTED` (#379) — Vorbild „per set-field gesperrt“ |
| `agent-os-openspec/core/hooks/workflow.py:1667-1690` | `cmd_complete` → derselbe `_validate_transition(data, "phase8_complete")` (#337: auch bei schon gesetzter Phase 8) |
| `agent-os-openspec/core/hooks/adversary_dialog.py:955-1167` | Vorbild für Beleg-Prüfung: `stamp_dialog_artifact` (sha256-Block „## Geprüfte Dateien“), `find_dialog_artifact`, `_outside_roots`, `check_dialog_evidence` (fail-closed, nie werfen) |
| `agent-os-openspec/core/hooks/adversary_dialog.py:1185,1324` | `coverage_gate_enabled` (Kill-Switch per Config), `phase8_code_files` (Änderungsmenge seit Basis) |
| `agent-os-openspec/core/hooks/hook_utils.py:1309` | `is_gated_code_path` — Definition „Produktionsdatei“ (config `strict_code_gate`) |
| `agent-os-openspec/core/hooks/bash_gate.py` | Commit-Gate 5c nutzt dieselbe Dialog-Regel; Ort für eine Bash-Schreibsperre |
| `agent-os-openspec/core/hooks/edit_gate.py` | Ort für eine Edit/Write-Sperre auf `simulator-run.txt` / `simulator-run/` |
| `agent-os-openspec/config.yaml` | Vorgaben; neuer Abschnitt für geforderte Belegtypen (opt-in je Projekt) |
| `loose-ends/openspec.yaml` | Projekt-Config: hier würde Loose Ends den Belegtyp für Phase 8 einschalten |
| `loose-ends/scripts/sim_proof.py` | Erzeuger; Format: Kopfzeilen `schlüssel: wert`, `ergebnis: Passed`, `head:`, `basis:`, `summary: <pfad>  sha256:<hex>`, Block `## Geprüfte Dateien` mit `- sha256:<hex>  <pfad>` |
| `loose-ends/scripts/sim.sh:581-628` | `cmd_test_proof`: löscht alten Beleg vor dem Lauf, schreibt neuen auch bei rotem Lauf (`ergebnis: Failed`) |

## Existing Patterns
- **Beleg mit Hash-Block:** Dialog-Artefakt bekommt per Werkzeug einen `## Geprüfte Dateien`-Block; das Gate
  vergleicht die Hashes mit dem Arbeitsbaum. `sim_proof.py` schreibt bereits genau dasselbe Format — das Gate kann
  die Parser-Funktion (`_EXAMINED_FILES_LINE_RE`, adversary_dialog.py:586) wiederverwenden.
- **Abdeckung der Änderungsmenge:** `phase8_code_files` liefert die seit Basis geänderten Code-Dateien; der
  Beleg muss jede davon mit aktuellem Hash binden (gleiche Logik wie #259 für den Dialog).
- **Fail-closed:** jede Prüfung liefert `str | None`, interne Fehler werden zum Ablehnungsgrund.
- **Kill-Switch nur durch explizites `enabled: false`** (Muster `coverage_gate_enabled`); hier umgekehrt nötig:
  opt-in, weil Projekte ohne Simulator (Python, Web) sonst nie abschließen könnten.
- **Gesperrte Felder:** `_SET_FIELD_PROTECTED` verhindert, dass Gate-Felder per `set-field` gesetzt werden.

## Dependencies
- Upstream: `xcrun xcresulttool get test-results summary --path <bündel> --compact` (Neuableitung); `git`.
- Downstream: jedes Projekt mit dem Plugin (nur wenn eingeschaltet); `/60-validate`, `/70-deploy`, `complete`,
  `finish`; Commit-Gate (bash_gate 5c) falls die Regel auch dort greifen soll.

## Existing Specs
- `docs/specs/tooling/feat-145-simulator-beleg.md` — Schnitt 1 (Erzeuger)

## Risks & Considerations
- **Zwei Repos:** Code landet im Plugin-Repo `/Users/hem/Developer/agent-os-openspec` (eigene Tests, 143
  Testdateien, CHANGELOG, Version in `setup.py`, `skills/*` generiert). Der Workflow hier trackt; Edit-/LoC-Gates
  messen den Loose-Ends-Worktree, nicht das Plugin-Repo — die Analyse muss klären, wo der Workflow für den
  Plugin-Code geführt wird (Ein Workflow im Plugin-Repo, dieser hier für die Loose-Ends-Seite: openspec.yaml).
- **Gilt für alle Projekte:** Nur opt-in je Projekt; ohne Config darf sich nichts ändern.
- **Drift:** `sim_proof.py` spiegelt `is_gated_code_path` aus Plugin 3.34.0; das Plugin hat inzwischen
  `is_colocated_test_file` dazu. Gate und Erzeuger müssen dieselbe Dateimenge meinen — sonst lehnt das Gate
  ehrliche Belege ab oder übersieht Dateien.
- **xcresulttool nur auf macOS mit Xcode:** Neuableitung im Gate läuft lokal; auf Linux-CI nicht verfügbar.
- **Fälschungsschutz ist relativ** (Entscheidung 2026-10-01): Ziel „Fälschen ist aufwendiger als der ehrliche
  Lauf und fällt auf“. Signatur verworfen, Gate-fährt-selbst-Lauf als späteres Zielbild.
- **Schreibsperre vs. Erzeuger:** Die Sperre muss Write/Edit/Bash-Umleitungen blocken, aber `sim.sh test-proof`
  (Bash) durchlassen — Erkennung über den Befehl, nicht über den Pfad allein.
- **Fast-Track/Spikes/Doku-Tickets ohne UI:** Brauchen eine Regel, wann kein Simulator-Beleg nötig ist
  (z. B. keine gated Code-Datei geändert → kein Beleg gefordert).

## Analysis

### Type
Feature (Werkzeug: Prüfregel im Plugin, Einschalten in Loose Ends)

### Befunde (2026-10-22)
- Plugin (Stand Repo 3.40.0, installiert 3.41.0): kein Hook kennt `simulator_run`/`xcresult`. Phase-8-Zweig
  `workflow.py:1068-1096`; `cmd_add_artifact:1537` prüft nur den Typ; `docs/` und `*.txt` sind in edit_gate frei
  beschreibbar (config.yaml `always_allowed_dirs`/`_patterns`); bash_gate `PROTECTED_FILE_PATTERNS:57` kennt
  `docs/artifacts/` nicht. Bash-Sperre greift nur, wenn der Befehlstext den Pfad nennt — `sim.sh` schreibt intern
  und wird nicht gesehen (gewollt).
- Erzeuger `scripts/sim_proof.py`: Format siehe Related Files; `ergebnis` = Passed nur bei `result==Passed`,
  xcodebuild-Exit 0 und ≥ 1 Test. Dateimenge = diff gegen `merge-base origin/main HEAD` + untracked, gefiltert mit
  fester Kopie von `is_gated_code_path` (v3.34). Sie zählt `LooseEndsTests/*.swift` mit, das Plugin mit Loose-Ends-
  Config nicht → Erzeuger-Menge ⊇ Gate-Menge, solange beide `.swift` außerhalb `scripts/`/`docs/` zählen.
- `summary.json` ist versioniert (nur `*.xcresult` gitignored), `run.xcresult` bleibt lokal im Worktree.
- Recherche: `xcrun xcresulttool get test-results summary --path … --compact` (Xcode 27.1 lokal, Schema 0.4.0,
  versioniert; Apple veröffentlicht das Format nicht separat, Schema per `--schema`). Quellen:
  developer.apple.com/forums/thread/763050, /thread/763888. Folge: **semantisch** vergleichen (result, Zähler),
  nicht byteweise — ein Xcode-Update zwischen Lauf und Abschluss darf keinen ehrlichen Beleg brechen.
- Verbreitung: 22 von 81 Artefakt-Ordnern haben einen `simulator-run.txt`. Ohne saubere Ausnahmen blockiert das
  Gate die Mehrheit (Doku, Werkzeug, Mac-only).

### Affected Files (with changes) — Plugin-Repo `henemm/agent-os-openspec`
| File | Change Type | Description |
|------|-------------|-------------|
| `core/hooks/evidence_gate.py` | CREATE | `check_evidence(target_phase, wf) -> str|None`, fail-closed; Verifier-Registry, erstes Mitglied `xcresult_proof` |
| `core/hooks/workflow.py` | MODIFY | eine Aufrufstelle im Phase-8-Zweig nach dem Dialog-Check (gilt damit auch für `complete`/`finish`) |
| `core/hooks/config_loader.py` + `config.yaml` | MODIFY | Abschnitt `evidence_checks` (Default leer = keine Änderung für andere Projekte), Key in `PLUGIN_CONFIG_KEYS` |
| `core/hooks/edit_gate.py`, `core/hooks/bash_gate.py` | MODIFY | Schnitt 2b: Schreibsperre auf `docs/artifacts/*/simulator-run.txt` und `simulator-run/` |
| `tests/test_evidence_gate_145.py` (+ 2b: `tests/test_evidence_write_lock_145.py`) | CREATE | Gate- und Sperrtests |

Loose-Ends-Seite (dieser Workflow): `openspec.yaml` (Einschalten + Ausnahmepfade), danach Schnitt 3 Doku
(`docs/reference/abnahme-und-arbeitsweise.md`, `CLAUDE.md`).

### Was das Gate prüft (Schnitt 2a)
1. Konfiguriert für `phase8_complete`? Sonst nichts tun.
2. Gate-Dateimenge = `phase8_code_files(wf)`, abzüglich `exempt_paths` aus der Config. Leer → kein Beleg nötig.
3. `docs/artifacts/<wf>/simulator-run.txt` existiert, liegt im Projekt (`_outside_roots`), Kopf lesbar.
4. Jede Datei der Gate-Menge steht im Block `## Geprüfte Dateien` mit dem Hash des Arbeitsbaums (Obermenge
   erlaubt). **Keine Bindung an `head:`** — Rebase/Amend ohne Code-Änderung darf den Beleg nicht entwerten.
5. `summary.json` passt zur `summary:`-Prüfsumme; `run.xcresult` liegt daneben.
6. Neuableitung per `xcresulttool` (mit Timeout): `result`, `totalTestCount`, `passedTests`, `failedTests`,
   `skippedTests` gleich `summary.json` und den Zeilen `ergebnis:`/`tests:`; verlangt `Passed` und ≥ 1 bestanden.
   `xcresulttool` fehlt → abgewiesen mit klarer Meldung.
Kein neuer Artefakt-Typ nötig: das Gate liest den festen Pfad; ein Registereintrag wäre nur ein weiteres
fälschbares Feld.

### Ausnahmen
- Keine Gate-Datei geändert → kein Beleg (Doku, Skripte, Tests).
- `exempt_paths` in `openspec.yaml` für Bereiche ohne Simulator-UI-Test (Mac-only `LooseEnds/Mac/`). Dateien
  außerhalb davon verlangen weiter den Beleg.
- Sonst nur Hennings getipptes `override` (bestehender Mechanismus). **Kein selbst registrierbares
  Verzicht-Artefakt** — „ein Gate, das man selbst öffnen kann, ist kein Gate" (CLAUDE.md, 2026-09-27).

### Scope Assessment
- Schnitt 2a (Plugin, Gate): 4 Dateien, ca. +170 Prod-LoC, ca. +250 Test-LoC
- Schnitt 2b (Plugin, Schreibsperre): 2–3 Dateien, ca. +40 Prod-LoC, ca. +120 Test-LoC
- Loose-Ends-Seite: `openspec.yaml` +6 Zeilen; Erzeuger unverändert (Menge ist schon Obermenge)
- Risk Level: MEDIUM — Gate wirkt auf jeden Abschluss in Loose Ends; für andere Projekte nur per Opt-in

### Technical Approach
Lokales Gate wie am 2026-10-01 entschieden, in zwei Plugin-Schnitten (2a Gate, 2b Schreibsperre), **als eigenes
Issue und eigener Workflow im Plugin-Repo** — die Scope-/Edit-Gates messen das Repo, in dem der Workflow lebt;
ein Loose-Ends-Workflow sähe den Plugin-Code nicht. Dieser Workflow trägt danach das Einschalten in
`openspec.yaml` und den Pilot am nächsten UI-Ticket. Nur Phase 8, nicht das Commit-Gate: der Beleg sperrt
„fertig", nicht Zwischenstände.

### Alternative (Pflicht)
**CI spielt die im Beleg genannte Testklasse auf dem PR selbst durch**, das Gate prüft nur den grünen Check
(`gh pr checks`). Nicht lokal fälschbar, ca. 60 Plugin-LoC, kein `xcresulttool` lokal nötig. Kippt die
Entscheidung vom 2026-10-01 („Gate leitet lokal aus run.xcresult ab", „Gate fährt selbst = später") und dreht
den Ablauf um (PR muss vor Phase 8 stehen), kostet CI-Minuten je Ticket (UI-Lauf heute ca. 4–8 min).
Nicht jetzt: das lokale Gate schließt die Lücke sofort und bleibt als erste Stufe sinnvoll; CI-Nachlauf als
Zielbild in #145 festgehalten.

### Dependencies
- Plugin-Release mit 2a vor dem Einschalten in Loose Ends; 2b danach.
- Restlücke (bewusst akzeptiert): ein selbst gebautes `run.xcresult` beweist das Gate nicht als unecht.
- Erzeuger/Gate-Drift: Gate verlangt Obermenge; wächst die Plugin-Menge (neue Endung in `code_extensions`),
  muss `sim_proof.py` mitziehen — Test in Schnitt 2a-Spec als AC.

### Plugin-Ticket
henemm/agent-os-openspec#447 (Teil von Epic #430) trägt Schnitt 2a/2b. Die Spec dieses Workflows beschreibt
das Gate-Verhalten (ACs) und das Einschalten in Loose Ends; gebaut wird der Plugin-Code im Plugin-Workflow zu #447.

### Open Questions
- keine PO-Fragen; Technik entschieden (s. oben).
