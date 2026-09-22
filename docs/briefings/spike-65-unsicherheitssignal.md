---
spec_file: docs/specs/measurement/spike-65-mehrfachlauf-infrastruktur.md
spec_sha256: 0393ce6662b2108b9619873596443bf4c3c79217ae7ab7c115afb8f2215d9962
---

# PO-Briefing: spike-65-unsicherheitssignal

- **Spec:** docs/specs/measurement/spike-65-mehrfachlauf-infrastruktur.md
- **Issue:** #65
- **Erstellt:** 2026-09-22

## Was gebaut wird

Die Mess-Werkzeuge lernen, mehrere Testdurchläufe pro Satz zu zählen und ein zweites Test-Set zu laden.

## Definition of Done

Alle sechs Prüfpunkte sind durch automatisierte Tests belegt, bestehende Tests bleiben unverändert grün.

## Wie geprüft wird

Automatisierte Tests am Mac zeigen korrektes Zählen und Laden; kein Test ruft dabei Modell oder Gerät auf.

## Kritische Anmerkungen

- Beantwortet die Ausgangsfrage aus #65 noch nicht: kein Signal gemessen, kein Report, keine Empfehlung — nur Vorbereitung.
- Sub-Issues für diesen und den nächsten Schritt fehlen noch, werden erst nach Freigabe angelegt.
- Das Issue verlangt Gerätetests; diese Lieferung testet nur am Mac, Gerätemessung folgt in Schritt 2.

## Freigabe-Frage

Ist es in Ordnung, dass diese Freigabe nur Vorbereitung liefert und die eigentliche Signal-Frage aus #65 offen bleibt?
