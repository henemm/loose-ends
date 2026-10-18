---
spec_file: docs/specs/tooling/fix-395-kalibrierung-haengt.md
spec_sha256: f1ee0ec772f7633515441a07893a45a3cb6c5c9bdd6d7d0381d50c90a3b7e0e7
spec_frozen_sha256: 90f14895619e9c1b5940075b9026b824700561687a2e6f36ed9d384f8d3d48fd
---

# PO-Briefing: fix-395-kalibrierung-haengt

- **Spec:** docs/specs/tooling/fix-395-kalibrierung-haengt.md
- **Issue:** #395
- **Erstellt:** 2026-10-18

## Was gebaut wird

Die langsame Modell-Kalibrierungsprüfung wird aus den automatischen Tests entfernt, damit lokale Testläufe immer enden.

## Definition of Done

Ein voller lokaler Testlauf mit Korpus endet grün, enthält keine Kalibrierungsprüfung mehr, und der eingecheckte Kalibrierungsbericht bleibt unverändert.

## Wie geprüft wird

Skripttests und ein voller Simulator-Testlauf belegen Ende, unveränderten Bericht und fehlende Modellaufrufe; dass der damalige Hänger verschwunden ist, lässt sich nicht beweisen.

## Kritische Anmerkungen

- Der Hänger vom 13.10. ließ sich in drei Läufen nicht nachstellen; behoben wird das Überschreiben des Berichts.
- Das Ticket verlangte Schalter oder Zeitlimit; stattdessen wird die Prüfung gelöscht, Kalibrierung später nur über Verlauf wiederholbar.
- Der Schnitt berührt acht Dateien, über dem Limit; Freigabe liegt von dir vor.

## Freigabe-Frage

Soll die Kalibrierungsprüfung endgültig entfernt werden, obwohl der ursprüngliche Hänger nicht nachgestellt werden konnte?
