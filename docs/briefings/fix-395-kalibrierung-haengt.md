---
spec_file: docs/specs/tooling/fix-395-kalibrierung-haengt.md
spec_sha256: a517ce3e995875be2922abd75f82ce60c4812db207ff9238fb97d8a1aa4fdc57
spec_frozen_sha256: ccaf7cb76a487dfcf237c9f31e3f6732d04aefd45d61de38b93c1947bc43b273
---

# PO-Briefing: fix-395-kalibrierung-haengt

- **Spec:** docs/specs/tooling/fix-395-kalibrierung-haengt.md
- **Issue:** #395
- **Erstellt:** 2026-10-18

## Änderung gegenüber der vorigen Fassung

Neu: Modellaufrufe sind nur in der separaten Modellreihe erlaubt, die nur auf ausdrücklichen Befehl läuft.

## Was gebaut wird

Die langsame Modell-Kalibrierungsprüfung verschwindet aus den automatischen Tests, damit lokale Testläufe immer enden.

## Definition of Done

Voller lokaler Testlauf endet grün ohne Kalibrierungsprüfung, und der eingecheckte Kalibrierungsbericht bleibt unverändert.

## Wie geprüft wird

Skripttests und ein voller Simulator-Lauf belegen Ende, unveränderten Bericht und fehlende Modellaufrufe; der alte Hänger bleibt unbeweisbar.

## Kritische Anmerkungen

- Hänger vom 13.10. nicht nachstellbar; behoben wird stattdessen das Überschreiben des Berichts.
- Ticket verlangte Schalter oder Zeitlimit; stattdessen wird gelöscht, Kalibrierung später nur noch neu aufzubauen.
- Acht Dateien statt Limit fünf; deine Freigabe liegt vor.

## Freigabe-Frage

Soll die Kalibrierungsprüfung endgültig entfernt werden, obwohl der ursprüngliche Hänger nie nachgestellt werden konnte?
