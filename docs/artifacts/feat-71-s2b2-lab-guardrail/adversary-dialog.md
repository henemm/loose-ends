# Adversary Dialog — feat-71-s2b2-lab-guardrail
Spec: docs/specs/spike-71-schnitt-2b2-lab-guardrail.md
Datum: 2026-10-29

## Checkliste
- [x] **AC-1:** build erzeugt 103 Einträge, alltag-0..2, Format id/lang/text/form, stdout ohne Satz.
- [x] **AC-2:** build bricht ab ohne Zieldatei (Ziel im Repo, ≠100 heikel, doppelte Id, falsches Präfix).
- [x] **AC-3:** count zählt je Eintrag×Durchlauf einmal, nur Erfolg/guardrail/refusal.
- [x] **AC-4:** lab-guardrail --dry-run baut außerhalb des Repos, meldet Zahl, Dauer, „entsperrt“, Status 0, kein Gerät.
- [x] **AC-5:** statische Prüfung von cmd_lab_guardrail vorhanden und deckt alle Zusicherungen.
- [x] **AC-6:** Simulator-Kette belegt (simulator-kette.md); count/Berichttest durchlaufen, Rohdaten ohne Alltagswort.
- [x] **AC-7:** genau drei Code-Dateien, kein devicectl im Test (Attrappe), Commit nennt Refs #71.

## Dialog

### Runde 1
**Adversary:** Suite `python3 -I scripts/test_guardrail_corpus.py`: 16 Tests OK, 0 Fehler, 0 übersprungen (adversary-test-output.txt). Eigene Randfälle:
- build mit Ziel im Worktree (absolut), mit `scripts/../docs/...` und per Symlink: jeweils Status 1, „Zielpfad liegt im Repo“, keine Datei. (AC-2 belegt, Auflösung per resolve() greift.)
- Leere FocusBlox-Datei (0 Byte): Traceback JSONDecodeError, Status 1, keine Zieldatei; Eintrag ohne rawText: KeyError, Status 1, kein Zielordner angelegt. Kein Satz im Traceback. `[]`: Status 0, „heikel 100, Alltag 0, gesamt 100“ (F002).
- Ziel in nicht existierendem Ordner: wird angelegt (Dry-Run mit TMPDIR mit Schrägstrich: Korpus unter .../t1/loose-ends-71-guardrails/guardrail-geraet.json, kein doppelter Schrägstrich).
- count: error="" zählt, guardrail/refusal zählen, rateLimited/timeout/unbekannt nicht, Doppel einmal (Ergebnis 2 bei erwartetem 2); Datei ohne results: 0.
- Trockenlauf mit Attrappen-xcrun im PATH: 206 Aufrufe (103×2), 17 Minuten (206×4,83 s = 995 s), „entsperrt“ enthalten, Status 0; Attrappe nicht aufgerufen. Quellprüfung `[ -f "$focusblox" ]` steht vor build und vor require_device (Code sim.sh:1070), also Fehler statt Gerät.
- Sätze in stdout/stderr: build druckt nur Zahlen; count nur Zahl.
**Implementierer:** (nicht beteiligt, Kontext isoliert)

### Runde 2
**Adversary:** Tiefer in cmd_lab_guardrail / lab_guardrail_slices (Code gelesen, nicht ausgeführt, da Gerät verboten):
- require_device (sim.sh:1076) steht nach Meldung und dry-run-Rückkehr (1074). OK. Kein `device uninstall`.
- Scheibenschleife: Status 0 und 124 akzeptiert, anderer Status bricht ab, gesperrt bricht ab, Zählung gegen `calls` (>=), maximal 6 Scheiben, Wiederaufnahme per Gerätestand. OK.
- Schwäche: sim.sh:1047 `copy from ... || true` und `[ -s "$dest" ]`: bleibt eine Ergebnisdatei eines früheren Laufs in $TMPDIR liegen und scheitert das Holen, wird der alte Stand gezählt (F003).
- Schwäche: repo_root() (guardrail_corpus.py:22) liefert im Worktree den Worktree, nicht den Haupt-Checkout; ein Ziel unter /Users/hem/Developer/loose-ends/docs/... wird nicht abgewiesen (F001; per `git rev-parse --show-toplevel` aus scripts/ bestätigt, Schreibversuch nicht gemacht, Hook blockiert zudem).
- sim.sh:1093 `rm -f "$raw"` löscht vorhandene Rohdaten vor dem Berichttest; schlägt der Test fehl, sind frühere Rohdaten weg (F004, gering).
**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** Behebungen gegen den Code geprüft. Suite neu: 19 Tests OK, 0 übersprungen (adversary-test-output.txt).
- F002 behoben: `[]` bricht mit Status 1 ab ("keine persönlichen Sätze"), keine Zieldatei und kein Zielordner (Eigenlauf). Prüfung steht vor write_text.
  Code reference: scripts/guardrail_corpus.py:38
- F003 behoben: `rm -f "$result"` steht nach Bau, Installation und Korpuskopie, unmittelbar vor `lab_guardrail_slices`; ein gescheiterter Abruf endet an `[ -s "$dest" ]` als "Ergebnisdatei fehlt". Vor dem Trockenlauf-Return nicht erreichbar, kein Geräteaufruf neu.
  Code reference: scripts/sim.sh:1088
- F004 behoben: Berichttest schreibt nach `$scratch/iphone-rohdaten.json`, `mv` nach `docs/artifacts/71-guardrails/iphone-rohdaten.json` erst nach Testerfolg und nicht leerer Ausgabe; ein Fehlschlag lässt vorhandene Rohdaten unberührt. Rohdaten landen weiterhin nur dort.
  Code reference: scripts/sim.sh:1097
- Tests für die Behebungen vorhanden und grün.
  Code reference: scripts/test_guardrail_corpus.py:134
Offen bleibt F001 (bewusst, nur bei Handaufruf). Keine neuen Funde.
**Implementierer:** (nicht beteiligt)

## Findings
Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/guardrail_corpus.py:31
  Description: Repo-Prüfung vergleicht nur mit dem Toplevel des aktuellen Worktrees. Ein Ziel im Haupt-Checkout (enthält den Worktree, liegt aber nicht darin) wird angenommen.
  Spec requirement: AC-2 — Ziel im Repo wird abgewiesen
  Conflict: persönliche Sätze könnten im Repo (Haupt-Checkout) landen. Der Befehl selbst nutzt nur $TMPDIR, daher nur bei Handaufruf.
  Remediation: zusätzlich `git rev-parse --git-common-dir` bzw. den Haupt-Checkout als gesperrt prüfen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/guardrail_corpus.py:36
  Description: Eine leere Alltagsliste (`[]`) baut einen Korpus ohne Alltagseintrag, Status 0.
  Spec requirement: AC-1 — persönliche Sätze im Korpus
  Conflict: Rate auf Alltagstext wäre ohne Nenner; Lauf würde 200 Aufrufe verbrauchen.
  Remediation: bei 0 Alltagseinträgen abbrechen.

Finding:
  ID: F003
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/sim.sh:1047
  Description: `|| true` beim Holen plus `-s "$dest"` erkennt eine veraltete Ergebnisdatei im Scratch nicht; Zählung und Berichttest laufen dann auf altem oder fremdem Korpusstand.
  Spec requirement: AC-4/AC-6 — Ergebnisdatei gehört zum gebauten Korpus
  Conflict: falsches „Alle Aufrufe gemessen“ möglich, wenn der erste Abruf scheitert.
  Remediation: vor Scheibe 1 `$result` entfernen (Wiederaufnahme liegt auf dem Gerät) oder Abrufstatus prüfen.

Finding:
  ID: F004
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/sim.sh:1093
  Description: `rm -f "$raw"` vor dem Berichttest.
  Spec requirement: AC-5 — Rohdaten nur nach docs/artifacts/71-guardrails/
  Conflict: bei Testfehler gehen vorhandene Rohdaten verloren.
  Remediation: in Temp schreiben, nach Erfolg verschieben.

## Confirmations
Confirmation:
  AC: AC-1
  Code reference: scripts/guardrail_corpus.py:36
  Evidence: Dry-Run mit 3 Sätzen: „heikel 100, Alltag 3, gesamt 103“; stdout nur Zahlen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/guardrail_corpus.py:34
  Evidence: Prüfungen vor write_text (Zeile 46); Repo-Ziel abgelehnt (absolut, `..`, Symlink), keine Datei; Tests für ≠100, doppelte Id, Präfix grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/guardrail_corpus.py:52
  Evidence: Menge aus (entryID, runIndex); Eigenlauf lieferte 2 für 5 gemischte Ergebnisse.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/sim.sh:1074
  Evidence: Rückkehr vor require_device (1076); Attrappe nicht gerufen; bash -n der Suite grün (Test ruft es), Status 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/test_guardrail_corpus.py:186
  Evidence: Teststellen für TMPDIR, Reihenfolge dry-run vor require_device (194); Suite 16/16 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/sim.sh:1094
  Evidence: simulator-kette.md: 774 Aufrufe gezählt, Berichttest bestanden, Wort 0× in Rohdaten, 1× lokal. Nicht neu ausgeführt (Simulator-Lauf), Beleg gelesen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_guardrail_corpus.py:134
  Evidence: `git diff HEAD --name-only` und HEAD: genau guardrail_corpus.py, sim.sh, test_guardrail_corpus.py (Rest Artefakte/Spec); Attrappe in Test 134-150. „Refs #71“: Commit 76abeb1 nennt es, PR-Text noch offen.
  Status: CONFIRMED

## Herkunft der Vorbedingungen
Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`).

## Verdict
VERDICT: VERIFIED
Tests: 19 passed, 0 failed, 0 übersprungen
F002, F003, F004 behoben und geprüft; F001 (MEDIUM) bewusst offen, nur bei Handaufruf.

## Geprüfte Dateien

- sha256:66ed53cc08e42e2c5e28de58eaeb0f21b01673a6ae20927ddbb3ec756ef3612e  scripts/guardrail_corpus.py
- sha256:3046f2a5fa724d33756c7346f0a5b69a84d63a35f7919d937629c30e3e92ae33  scripts/sim.sh
- sha256:54a42319794b30a9afb8e053d8d5935d7709b8109ad146c00cdf75565fad8878  scripts/test_guardrail_corpus.py

## Prüfbasis

- base: 14f8c91619aebc17828768b1482376814011d875
- blob:9a64e0d455c5448e220bac41fbb5beddaf22cf8d  scripts/guardrail_corpus.py
- blob:43221906f3b01614730e12e6e5d17effc703b074  scripts/sim.sh
- blob:d7c370f252dc02dafcc58d7c5fc112bf2e350206  scripts/test_guardrail_corpus.py

## Geprüfte Dateien

- sha256:66ed53cc08e42e2c5e28de58eaeb0f21b01673a6ae20927ddbb3ec756ef3612e  scripts/guardrail_corpus.py
- sha256:3046f2a5fa724d33756c7346f0a5b69a84d63a35f7919d937629c30e3e92ae33  scripts/sim.sh
- sha256:54a42319794b30a9afb8e053d8d5935d7709b8109ad146c00cdf75565fad8878  scripts/test_guardrail_corpus.py

## Prüfbasis

- base: 14f8c91619aebc17828768b1482376814011d875
- blob:9a64e0d455c5448e220bac41fbb5beddaf22cf8d  scripts/guardrail_corpus.py
- blob:43221906f3b01614730e12e6e5d17effc703b074  scripts/sim.sh
- blob:d7c370f252dc02dafcc58d7c5fc112bf2e350206  scripts/test_guardrail_corpus.py
