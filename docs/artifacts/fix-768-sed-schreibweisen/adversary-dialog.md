# Adversary Dialog — fix-768-sed-schreibweisen
Spec: docs/specs/fast/fix-768-sed-schreibweisen.md
Datum: 2026-11-02 13:46

## Checkliste

- [x] P1 Schreibendes sed in allen 6 Schreibweisen erzeugt Treffer in Temp-Kopie von .github/
- [x] P2 Lesendes sed erzeugt keinen Treffer; READS_PROJECT_YML bleibt erlaubt; .github/ ohne Treffer
- [x] P3 Keine Änderung an .github/, keine neue Abhängigkeit; nur scripts/test_ci_xcode27.py
- [x] P4 Vorher-rot-Beleg (test-red-output.txt) und 475 Tests OK (test-green-output.txt)

## Dialog

### Runde 1
**Adversary:** Beweis zu P1: gilt das Muster wirklich für alle sechs Schreibweisen, oder prüft der Test nur Zeichenketten statt der echten Suche? Und fängt es auch Randformen?
**Implementierer:** Der Test ruft das echte `lowering_hits` (grep -rnE) auf einer Kopie von .github/ auf, je Schreibweise ein eigener subTest. Code reference: scripts/test_ci_xcode27.py:104-112. Muster: Code reference: scripts/test_ci_xcode27.py:59. Lauf `python3 -m unittest scripts.test_ci_xcode27 -v`: 29 Tests, OK, darunter `test_sed_pattern_catches_every_writing_spelling ... ok`. Randformen von mir geprüft: gefangen werden `sed -i f`, nach Pipe `x | sed -i ...`, `sed -Ei`, `sed -s -i`, `sed -i''`, `sed -E -i`, `sed --in-place=.bak`, `sed -ie`, `gsed -i`, `sed -n -E -i`.
**Adversary:** P2: lesendes sed und .github/ selbst?
**Implementierer:** `test_sed_pattern_ignores_reading_sed` legt `sed -n 1p f` und `sed -n 's/a/b/p' f` ab, erwartet []. Code reference: scripts/test_ci_xcode27.py:114-119. Das echte .github/ enthält u. a. `sed -n 's/…/p' project.yml` (testflight.yml:148, 424), die Zeilen bleiben über READS_PROJECT_YML erlaubt; `test_no_lowering_anywhere_in_github` ist grün. Code reference: scripts/test_ci_xcode27.py:101-102 und Filter in :64.

### Runde 2
**Adversary:** Lücken im Muster? Gefunden mit eigener Probe (grep -E, Muster aus Zeile 59):
- NICHT gefangen: `sed -e 's/a/b/' -i f` (Skript-Argument zwischen den Flags), `sed -n -e p -i f` (-e mit Argument davor), `sed --expression=x -i f` (Langoption).
- Fehlalarm-Freiheit: `sed -n 1p`, `sed -n s/a/b/p`, `sed -E 's/i/j/'` erzeugen keinen Treffer (gut).
Relevanz für die Spec: Die Spec nennt nur die sechs Schreibweisen (-i, -ni, -i.bak, zwei Leerzeichen, -n -i, --in-place); alle sind gefangen. Die Lücken liegen außerhalb des Ticketumfangs (Befund F002 aus #767), sind aber real: ein Muster mit Argumenten zwischen den Flags bräuchte ein Token-Parsing, nicht grep. Als Folgeaufgabe vermerkt, kein Blocker.
**Implementierer:** P3: `git status` zeigt geändert nur scripts/test_ci_xcode27.py (+10/-4), `git status --short .github` leer; keine Imports/Abhängigkeiten außer shutil/tempfile/Path, die schon in der Datei genutzt werden. Code reference: scripts/test_ci_xcode27.py:58-64. P4: test-red-output.txt zeigt für `test_sed_pattern_catches_every_writing_spelling` und `test_sed_pattern_ignores_reading_sed` ERROR/rot (vor der Implementierung fehlte `lowering_hits`); test-green-output.txt endet mit `Ran 475 tests ... OK`. Code reference: scripts/test_ci_xcode27.py:101-119.

## Confirmations

Confirmation:
  AC: P1
  Code reference: scripts/test_ci_xcode27.py:104
  Evidence: sechs Schreibweisen, je ein subTest gegen echtes grep auf Temp-Kopie; Lauf OK
  Status: CONFIRMED

Confirmation:
  AC: P2
  Code reference: scripts/test_ci_xcode27.py:114
  Evidence: sed -n 1p / sed -n 's/a/b/p' ohne Treffer; .github/ ohne Treffer (Zeile 101)
  Status: CONFIRMED

Confirmation:
  AC: P3
  Code reference: scripts/test_ci_xcode27.py:59
  Evidence: Diff nur diese Datei (+10/-4), .github/ unverändert
  Status: CONFIRMED

Confirmation:
  AC: P4
  Code reference: scripts/test_ci_xcode27.py:62
  Evidence: red-Artefakt zeigt ERROR, green-Artefakt 475 Tests OK
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Geltung: P1-P4 bewiesen. Offene Lücken außerhalb der Spec: `sed -e '…' -i`, `sed -n -e p -i`, `sed --expression=… -i` werden nicht gefangen (nur Hinweis, kein Blocker).
Tests: 29 passed (diese Datei), 0 failed, 0 übersprungen; Gesamtlauf laut Artefakt 475 OK.

## Geprüfte Dateien

- sha256:4ebf931cfbc94b4172394d1799bb0dd746f02df97101a1a1da360c031cc94f1b  scripts/test_ci_xcode27.py

## Prüfbasis

- base: 66b3616df0a9ffa9fb5e58a9eb034b9797b2a20e
- blob:98257f80292ac6944d627f649787e17445db4933  scripts/test_ci_xcode27.py
