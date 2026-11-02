---
spec_file: docs/specs/spike-613-schnitt-c4b1-mcp-erfassen-ergebnis.md
spec_sha256: 10f69aabe439bae1a504203f0e6ac5400eb9223cff655efe705782b62f6c65f9
spec_frozen_sha256: aca0b7095f552ab842cbe2f815606d258cdb755cbb53b7fce9f083d5b17800c8
---

# PO-Briefing: spike-613-c4b-mcp-schreiben

- **Spec:** docs/specs/spike-613-schnitt-c4b1-mcp-erfassen-ergebnis.md
- **Issue:** #613
- **Erstellt:** 2026-11-02

## Was gebaut wird

Claude kann über den Dienst eine Aufgabe zum Erfassen anlegen und abfragen, ob und wie der Auftrag erledigt wurde.

## Definition of Done

Ein angelegter Auftrag zeigt ehrlich "wartet auf ein Gerät", später "bei einem Gerät" oder das Ergebnis; fremde Konten sehen nichts davon.

## Wie geprüft wird

Automatische Tests gegen eine echte Datenbank prüfen alle Zustände und die Kontotrennung; ob die App Aufträge abholt, prüfen sie nicht.

## Kritische Anmerkungen

- Abweichung: Die Analyse plante vier Werkzeuge in einem Schnitt; die Spec liefert nur Erfassen und Ergebnis, Abhaken und Fälligkeit folgen separat.
- Bis ein Abholweg in der App existiert, bleibt jeder Auftrag unerledigt; der Dienst sagt das offen.
- Der geforderte Simulator-Nachweis berührt die Werkzeuge nicht, er zeigt nur, dass die App startet.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
