# Adversary Dialog — fix-799-settle-grep
Spec: docs/specs/tooling/fix-799-settle-grep.md
Datum: 2026-11-02 07:41

## Checkliste
- [x] **AC-1:** Given kein Poster-Prozess läuft, When der Schritt „Let the simulator settle“ der Action unter `bash -e -o pipefail` läuft, Then endet die Messung mit `busy=0` und Exit 0 und die Schleife läuft weiter.
- [x] **AC-2:** Given kein Poster-Prozess läuft, When der Schritt im Job `ui-smoke` läuft, Then ist `grep` ebenfalls geschützt und das Warten bricht nicht ab.
- [x] **AC-3:** Given beide Kopien, When `scripts/test_ci_settle_sync.py` läuft, Then sind die `busy=`-Zeilen gleich, und der Kopf der Action nennt den Fall.
- [x] **AC-4:** Given der Stand vor dem Fix, When der Test läuft, Then ist er rot; nach dem Fix grün, ebenso alle übrigen Skripttests in `scripts/`.

## Dialog

### Runde 1
**Adversary:** `git diff` und `python3 -m unittest scripts/test_ci_settle_sync.py -v` ausgeführt, dann den Fix zu brechen versucht. Alle vier Tests grün. Mutationsprobe in einer Kopie im Scratchpad (Repo unverändert):
- Ohne Mutation: Exit 0, OK.
- `{ grep -i poster || true; }` zu `grep -i poster` zurückgesetzt, einzeln in `ci.yml`: 3 Failures (`test_busy_lines_identical`, `test_grep_is_guarded`, `test_no_match_exits_zero_under_pipefail`). Dieselbe Mutation einzeln in `action.yml`: dieselben 3 Failures. Der Test ist nicht trivial grün und prüft beide Kopien.
- Unter `bash --noprofile --norc -e -o pipefail`: ohne Treffer, geschützt: `busy=0`, Exit 0; ohne Treffer, ungeschützt: Exit 1 (Originalfehler); Treffer-Fall mit `9.0 posterd`: `busy=1`, der Schutz maskiert Treffer nicht.
- YAML beider Dateien lädt mit `yaml.safe_load`.
- Weitere `grep`: in `ci.yml` schon geschützt; `action.yml` Zeile 22 (`simctl list … | grep "$udid"`) gehört zum Pick-Schritt, dort soll ein fehlender Treffer scheitern, außerhalb des Scopes.
- Rot-Beleg `test-red-output.txt` (Commit fa08309): 3 Failures; `test_busy_lines_identical` damals ok, weil beide Kopien gleich ungeschützt waren. Grün-Beleg `test-green-output.txt`: 473 Tests, OK.
Bewertung: AC-1 bis AC-4 AKZEPTIERT.

Code reference: .github/actions/prepare-ui-simulator/action.yml:43
Code reference: .github/workflows/ci.yml:175
Code reference: scripts/test_ci_settle_sync.py:1

**Implementierer:** Die `busy=`-Zeile ist in beiden Dateien byte-gleich. Die Schleife `while [ "$waited" -lt 180 ]` läuft nach `busy=0` weiter, `quiet` zählt hoch. Der Kopfhinweis in `action.yml` Zeile 5–6 nennt `|| true`, `-e -o pipefail` und den Fall ohne Treffer.

Code reference: .github/actions/prepare-ui-simulator/action.yml:5
Code reference: .github/workflows/ci.yml:175
Code reference: scripts/test_ci_settle_sync.py:1

### Runde 2
**Adversary:** Randfälle gegengeprüft: Der Wächter hängt an den Mutationen aus Runde 1 (Schutz entfernt → rot, je Datei belegt). `|| true` steht in einer Gruppe nur um `grep`, ein Fehler von `ps`, `awk` oder `wc` bleibt unter `pipefail` sichtbar. In der Variante ohne `pipefail` (Job `ui-smoke`) ist der Schutz harmlos. Rest: Der Wächter prüft Text und Verhalten, keine echte CI-Ausführung; der CI-Beleg steht in der Definition of Done (AC-5), nicht in den ACs. Bewertung: AC-1 bis AC-4 AKZEPTIERT, keine NACHFRAGE.

Code reference: .github/actions/prepare-ui-simulator/action.yml:43
Code reference: .github/workflows/ci.yml:175
Code reference: scripts/test_ci_settle_sync.py:1

**Implementierer:** Bestätigt. Eine Zeile je Kopie plus Kopfhinweis und Wächtertest; der Diff berührt keine weiteren Zeilen.

Code reference: .github/actions/prepare-ui-simulator/action.yml:5
Code reference: .github/workflows/ci.yml:175
Code reference: scripts/test_ci_settle_sync.py:1

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`).

## Verdict
VERDICT: VERIFIED — alle vier ACs belegt, Test rot ohne Fix und grün mit Fix, Mutationsprobe in beiden Dateien rot, Verhalten unter `-e -o pipefail` stimmt, YAML gültig.

## Geprüfte Dateien

- sha256:fd714eb5779e2adf16c60d859ba0e7493eb52a6b1071f1e7ea435e4c5ae0357a  .github/actions/prepare-ui-simulator/action.yml
- sha256:c8a4edec0e5b2d1218789dd3a8cd1b451814cc264735ab26a510a687f9dce7dd  .github/workflows/ci.yml
- sha256:a034c4b6aa725067bc1c2b0f4c2d9b63f6ca9ee3c563220adc7ade157d70df7a  scripts/test_ci_settle_sync.py

## Prüfbasis

- base: 3ac92e4030284d3dd01af7d468262cb237050193
- blob:f00a5f207a50c251d6de64b9f2d78b96bfcea604  .github/actions/prepare-ui-simulator/action.yml
- blob:71b241f35fdfd4ad2baf825d4625559375a38d8c  .github/workflows/ci.yml
- blob:03022d4f6800ae3603e89ac94718260a1a1ef082  scripts/test_ci_settle_sync.py
