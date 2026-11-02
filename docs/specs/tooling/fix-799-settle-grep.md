---
entity_id: fix-799-settle-grep
type: bugfix
created: 2026-11-02
updated: 2026-11-02
status: draft
workflow: fix-799-settle-grep
---

# Spec: #799 — CI-Schritt „Let the simulator settle“ bricht nicht mehr ab, wenn kein Poster-Prozess läuft

## Approval

- [ ] Approved (Henning)

## Purpose

`ui-smoke-lang (de)` brach in PR #797 (Lauf 41347564840, Job 124970667576) im Schritt „Let the simulator settle (#228)“ mit Exit 1
ab, bevor ein Test lief. Der Schritt soll warten, bis der Simulator ruhig ist; er darf nie am Fehlen eines Prozesses scheitern.

**Hat es bisher funktioniert?** Ja, zeitabhängig. Der Fehler tritt nur auf, wenn der Poster-Prozess beim ersten Messen schon weg ist
(`ui-smoke-lang (en)` lief im selben Lauf grün). Seit #761 (Matrix nutzt die Action) trifft er einen Pflichtjob.

### Root Cause (nachgestellt 2026-11-02, lokal)

`busy=$(ps -A -o pcpu=,comm= | grep -i poster | awk '$1 > 5' | wc -l | tr -d ' ')`: `grep` liefert ohne Treffer Exit 1. Composite-Schritte
mit `shell: bash` laufen als `bash --noprofile --norc -e -o pipefail`; `pipefail` plus `-e` beenden die Zuweisung und damit den Schritt.
Der gute Fall „kein Prozess“ (`busy=0`, ruhig) wird so nie erreicht.

Nachstellung mit denselben Shell-Optionen, Muster ohne Treffer:
- alt `ps … | grep -i X | awk … | wc -l`: Exit 1, nächste Zeile nie erreicht
- neu `ps … | { grep -i X || true; } | awk … | wc -l`: Exit 0, `busy=0`

Die Kopie im Job `ui-smoke` (`ci.yml`) hat dasselbe Muster, läuft aber ohne `pipefail` und mit `continue-on-error: true`; dort bricht der Fehler
nur still das Warten ab.

**Alternative (verworfen):** `grep` ganz weglassen, `awk 'tolower($0) ~ /poster/ && $1 > 5'`. Ein Prozess weniger und kein Exit-Code-Problem,
ändert aber den Filter (ganze Zeile statt `comm`) und wurde nicht nachgestellt. Gewählt ist die kleinste Änderung nach dem Muster, das
`ci.yml:158,171` schon benutzen. Kein ADR berührt. Kein Modell beteiligt (Regeln vor Modell trifft nicht zu).

## Source

- **File:** `.github/actions/prepare-ui-simulator/action.yml` (Schritt „Let the simulator settle (#228)“)
- **Identifier:** Zeile `busy=$(…)`, Kopie in `.github/workflows/ci.yml` (Job `ui-smoke`, Zeile 175)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ps`, `grep`, `awk` des macOS-Runners | werkzeug | die Messung selbst, Verhalten unverändert |
| Job `ui-smoke-lang` (Matrix je Sprache) | ci | nutzt die Action, ist der Pflichtjob, den der Fehler traf |
| Job `ui-smoke` | ci | trägt die Kopie des Schritts |
| `scripts/test_info_plist_sync.py` | muster | Vorbild für Stil und Aufruf des neuen Tests |

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `.github/actions/prepare-ui-simulator/action.yml` | MODIFY | `grep -i poster` → `{ grep -i poster \|\| true; }`; Kopfhinweis um diesen Fall ergänzen |
| `.github/workflows/ci.yml` | MODIFY | dieselbe Zeile im Job `ui-smoke`, gleich geändert |
| `scripts/test_ci_settle_sync.py` | CREATE | Zeilengleichheit beider Kopien, kein ungeschütztes `grep` in der Pipeline, Verhaltensprobe unter `bash -e -o pipefail` |

Geschätzt +45/−3 LoC, 3 Dateien. Keine Produktänderung, kein Swift-Code, keine Berechtigungen, keine AppStorage-Schlüssel, keine Info.plist.
**Geräteliste:** Kein Pfad der Geräteliste berührt. Nichts läuft auf Hennings Geräten. Keine sichtbare UI-Änderung, kein Entwurf nötig.

## Definition of Done

- [ ] `grep` in beiden Kopien kann den Schritt nicht mehr beenden (AC-1, AC-2)
- [ ] Beide Kopien gleich, Hinweis im Kopf der Action (AC-3)
- [ ] Skripttest zuerst rot, dann grün; alle Skripttests in `scripts/` grün (AC-4)
- [ ] Ein CI-Lauf, in dem `ui-smoke-lang` für alle Sprachen den Schritt passiert (AC-5)

## Implementation Details

1. In beiden Dateien die Zeile `busy=$(ps -A -o pcpu=,comm= | { grep -i poster || true; } | awk '$1 > 5' | wc -l | tr -d ' ')`; sonst nichts an der Schleife.
2. Kopfhinweis der Action (Zeilen 3–4): ein Satz, dass die `busy=`-Zeile in beiden Kopien gleich bleibt und `grep` dort mit `|| true` geschützt sein muss (`pipefail`).
3. `scripts/test_ci_settle_sync.py` (unittest, Stil von `test_info_plist_sync.py`): liest beide Dateien, zieht die `busy=`-Zeile heraus, vergleicht sie
   Zeichen für Zeichen, prüft, dass jedes `grep` in ihr in `{ …; }` mit `|| true` steht, und führt die Pipeline mit einem Muster ohne Treffer unter
   `bash -e -o pipefail -c` aus (erwartet Exit 0 und `busy=0`).

## Test Plan

| Test | Datei | Prüft |
|---|---|---|
| `test_busy_lines_identical` | `test_ci_settle_sync.py` | beide `busy=`-Zeilen gleich (AC-3) |
| `test_grep_is_guarded` | `test_ci_settle_sync.py` | kein ungeschütztes `grep` in der Zeile (AC-1, AC-2) |
| `test_no_match_exits_zero_under_pipefail` | `test_ci_settle_sync.py` | Verhaltensprobe mit der echten Zeile, Muster ohne Treffer: Exit 0, `busy=0` (AC-1) |
| CI-Beleg | CI | `ui-smoke-lang` für alle Sprachen und `ui-smoke` grün (AC-5) |

Der Test wird zuerst rot geschrieben (beide Zeilen heute ungeschützt).

## Acceptance Criteria

- **AC-1:** Given kein Poster-Prozess läuft, When der Schritt „Let the simulator settle“ der Action unter `bash -e -o pipefail` läuft, Then endet die Messung mit `busy=0` und Exit 0 und die Schleife läuft weiter.
- **AC-2:** Given kein Poster-Prozess läuft, When der Schritt im Job `ui-smoke` läuft, Then ist `grep` ebenfalls geschützt und das Warten bricht nicht ab.
- **AC-3:** Given beide Kopien, When `scripts/test_ci_settle_sync.py` läuft, Then sind die `busy=`-Zeilen gleich, und der Kopf der Action nennt den Fall.
- **AC-4:** Given der Stand vor dem Fix, When der Test läuft, Then ist er rot; nach dem Fix grün, ebenso alle übrigen Skripttests in `scripts/`.
- **AC-5:** Given der PR, When die CI läuft, Then passiert `ui-smoke-lang` für alle Sprachen den Schritt grün (Beleg im Schritt-Log, „settled after about … s“).
