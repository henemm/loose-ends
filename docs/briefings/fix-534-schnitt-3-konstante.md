---
spec_file: docs/specs/fix-534-schnitt-3-konstante.md
spec_sha256: f35b8cbee8632000dcb27c1c5288da6f49af589ac0a1881daaa1a207db230790
spec_frozen_sha256: 7161649deead4839c6878b59c919f9d3a34a710c8a55b309f73def4998e6d5d1
---

# PO-Briefing: fix-534-schnitt-3-konstante

- **Spec:** docs/specs/fix-534-schnitt-3-konstante.md
- **Issue:** #534
- **Erstellt:** 2026-10-23

## Was gebaut wird

Die App wartet auf einen Aufruf des Sprachmodells künftig höchstens 25 statt bisher geschätzter 30 Sekunden.

## Definition of Done

Alle Tests sind grün, der Simulator erfasst und verarbeitet eine Aufgabe, und Hennings TestFlight-Rückmeldung bestätigt den Gerätepunkt.

## Wie geprüft wird

Tests belegen den Wert 25 Sekunden im erlaubten Bereich; sie belegen nicht, dass echte Modellaufrufe darunter bleiben.

## Kritische Anmerkungen

- Der einzige Test gegen das echte Modell läuft nie in Simulator oder CI; die Grenze bleibt dort ungeprüft.
- Gemessen wurde fast nur am heißen Gerät mit kurzen Notizen; lange Texte könnten über 25 Sekunden laufen.
- Ticket bleibt trotz „Closes“ bis zu Hennings TestFlight-Rückmeldung offen.

## Freigabe-Frage

Soll die Modell-Zeitgrenze auf 25 Sekunden sinken, obwohl lange Texte nicht gemessen wurden?
