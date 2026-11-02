# Context: fix-799-settle-grep

## Request Summary
Der CI-Schritt „Let the simulator settle (#228)“ bricht mit Exit 1 ab, sobald kein Poster-Prozess mehr läuft
(`grep` findet nichts, `pipefail` + `-e` beenden den Schritt). Betroffen: `ui-smoke-lang (de)` in PR #797
(Lauf 41347564840). Issue #799, M1, P0, XS.

## Related Files
| File | Relevance |
|------|-----------|
| `.github/actions/prepare-ui-simulator/action.yml:41` | `busy=$(ps … \| grep -i poster \| awk …)`; Schritt hat `shell: bash` = `bash --noprofile --norc -e -o pipefail` → bricht ab |
| `.github/workflows/ci.yml:175` | dieselbe Zeile im Job `ui-smoke`; Schritt ohne `shell:` (macOS-Standard `bash -e {0}`, kein pipefail) und `continue-on-error: true` → bricht nur das Warten ab |
| `.github/workflows/ci.yml:158,171` | weitere `grep … poster`, beide schon mit `\|\| echo` bzw. `\|\| true` abgesichert, nichts zu tun |
| `.github/actions/prepare-ui-simulator/action.yml:3-4` | Kopfhinweis „Kopie in ci.yml gleich ändern“ (#761), soll um diesen Fall ergänzt werden |

## Existing Patterns
- `|| true` / `|| echo` hinter `grep` in denselben Schritten (ci.yml:158, :171).
- Die Action ist die Kopie des `ui-smoke`-Schritts; beide werden gemeinsam geändert (Kopfhinweis).

## Nachgestellt (2026-11-02, lokal)
Dieselben Shell-Optionen wie in der CI (`set -e -o pipefail`), Muster ohne Treffer:
- alt: `ps … | grep -i X | awk … | wc -l` → Exit 1, nächste Zeile nie erreicht
- neu: `ps … | { grep -i X || true; } | awk … | wc -l` → Exit 0, `busy=0`
Hinweis: Die Schleife unterscheidet „kein Prozess“ (busy=0 → ruhig) richtig; nur der Exit-Code war das Problem.

## Dependencies
- Upstream: `ps`, `grep`, `awk` des macOS-Runners.
- Downstream: Job `ui-smoke-lang` (Matrix je Sprache, nutzt die Action), Job `ui-smoke`.

## Existing Specs
Keine. Kein Swift-Code, kein Gerätepfad: „Kein Pfad der Geräteliste berührt.“

## Risks & Considerations
- Nur Zeitpunkt-abhängig → ein grüner Lauf beweist wenig; Beleg ist der lokale Nachstellversuch plus CI-Lauf, in dem `ui-smoke-lang` den Schritt für alle Sprachen passiert.
- Beide Kopien müssen gleich bleiben, sonst driftet das Muster wieder auseinander.
- Test-Weg: kleines Skript-/Python-Test im Stil von `scripts/test_*_sync.py` könnte die Zeilengleichheit prüfen (in der Analyse entscheiden).

## Analysis

### Type
Bug (CI-Konfiguration, kein Swift-Code). Hat es bisher funktioniert? Ja, zeitabhängig: Der Fehler tritt nur auf, wenn der Poster-Prozess beim ersten Messen schon weg ist; `ui-smoke-lang (en)` lief im selben Lauf grün. Seit #761 (Matrix nutzt die Action) trifft er einen Pflichtjob.

### Root Cause (reproduziert, siehe „Nachgestellt“)
`grep` ohne Treffer → Exit 1; mit `-e -o pipefail` (Composite `shell: bash`) beendet das die Pipeline und den Schritt. Der Wert `busy=0` („ruhig“) wird nie erreicht, obwohl genau das der gute Fall ist.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `.github/actions/prepare-ui-simulator/action.yml` | MODIFY | `grep -i poster` → `{ grep -i poster \|\| true; }`; Kopfhinweis um diesen Fall ergänzen |
| `.github/workflows/ci.yml` | MODIFY | dieselbe Zeile im Job `ui-smoke` (Zeile 175), gleich geändert |
| `scripts/test_ci_settle_sync.py` | CREATE | Test im Stil der `test_*_sync.py`: beide `busy=`-Zeilen identisch und ohne ungeschütztes `grep`; zusätzlich Verhaltensprobe mit `bash -e -o pipefail` auf Muster ohne Treffer |

### Scope Assessment
- Files: 3
- Estimated LoC: +45/-3
- Risk Level: LOW (ändert nur den Exit-Code im Fall „kein Treffer“; Schleifenlogik unverändert)

### Technical Approach
`{ grep -i poster || true; }` in beiden Kopien (wie vom Ticket und den Mustern ci.yml:158/171 vorgegeben). Der Test wird zuerst rot geschrieben (beide Zeilen heute ungeschützt) und hält die Kopien künftig gleich.

Alternative: `grep` ganz weglassen, `ps … | awk 'tolower($0) ~ /poster/ && $1 > 5'` — ein Prozess weniger, kein Exit-Code-Problem, weil `awk` ohne Treffer 0 liefert. Spräche für sich, wenn man das Muster ohnehin neu schreibt; es ändert aber den Filter (Treffer auf die ganze Zeile statt `comm`-Spalte) und wurde nicht reproduziert. Kein ADR berührt. Rein deterministisch, kein Modell („Rules before the model“ trifft nicht zu).

### Dependencies
`ps`, `grep`, `awk` des macOS-Runners. Downstream: Jobs `ui-smoke-lang` (Matrix) und `ui-smoke`.

### Open Questions
- [ ] Keine. Beleg für „Kein Pfad der Geräteliste berührt“: nur `.github/` und `scripts/`. CI-Lauf mit `ui-smoke-lang` für alle Sprachen nach dem PR (DoD des Tickets).
