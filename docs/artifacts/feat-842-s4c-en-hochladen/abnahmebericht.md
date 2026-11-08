# Abnahmebericht #842 Schnitt 4c-1 — englische Store-Bilder in die Asset-Bibliothek

Stand 2026-11-08, Phase 7 (`/60-validate`).

## Stufe 1: Tests

- `python3 -m unittest scripts/test_asc_store_images.py`: 12 Tests, 12 grün, 0 übersprungen.
- Mit `test_asc_header_upload.py`, `test_asc_version_texts.py`, `test_asc_store_probe.py`: 61 Tests, alle grün.

## Stufe 2: Handläufe gegen Apple (Benutzen-Beleg)

| AC | Run | Zweig/Commit | Ergebnis (Protokoll in diesem Ordner) |
|---|---|---|---|
| Vorher | 42515431363 | main 472ac7e | Store-Probe-Ausgangsstand: en-US ohne Platzierung, de-DE mit 30 Platzierungen |
| AC-8 | 42518370162 | Zweig 503c73b | `version IOS 1.0.1 … PREPARE_FOR_SUBMISSION`, `lokalisierung en-US vorhanden`, drei Gruppen mit `maxCount=10`, 12-mal `plan en-… fehlt`, Mac-Warnung |
| AC-9 | 42518449813 | Zweig 503c73b | 12-mal `hochgeladen`, `zustand bereit` |
| AC-9 | 42518964937 | Zweig 503c73b | 12-mal `en-… PREPARE_FOR_SUBMISSION platzierungen=0`; die 22 Bestandsbilder zeilengleich mit dem ersten Lauf |
| AC-9 | 42519008880 | Zweig 503c73b | 12-mal `schon vorhanden, übersprungen` |
| AC-10 | 42519049719 | main 472ac7e | en-US `platzierung keine`, `bildsatz keine`; de-DE gegenüber dem Vorher-Lauf ohne Zeitstempel identisch |

Skript und Workflow sind seit 503c73b unverändert; die Läufe prüften den Endstand.

**Abweichung von der DoD („vom Zweig aus“):** Die beiden Store-Probe-Läufe liefen auf `main`. Das ändert nichts am Beleg:
`asc-store-probe.yml` und `scripts/asc_store_probe.py` sind auf dem Zweig unverändert (`git diff main...HEAD` leer), und
die Probe liest nur den Stand bei Apple, den die Läufe vom Zweig verändert haben.

## Stufe 3

Kein Pfad der Geräteliste berührt.

Der Diff ändert an Code und Konfiguration nur `scripts/asc_store_images.py`, `scripts/test_asc_store_images.py` und
`.github/workflows/asc-store-images.yml`; dazu kommen die Workflow-Dokumente unter `docs/`. Auf Hennings Geräten lief nichts.

## Offene LOW-Befunde aus dem Prüfdialog

F002 bis F004 (unter anderem: keine `concurrency`-Sperre im Workflow; ein Lauf mit `sprache=de` würde eigene `de-…`-Bilder
neben die bestehenden deutschen Bilder legen; er ist nicht gelaufen) blockieren nicht und gehören zu Schnitt 4c-2 oder zu einem Folgeticket.

## Umfang

611 LoC (Skript 171, Workflow 54, Tests 386); Henning hat den Überhang am 2026-11-08 angenommen („So übernehmen“).
