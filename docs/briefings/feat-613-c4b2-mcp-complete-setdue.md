---
spec_file: docs/specs/feat-613-c4b2-mcp-complete-setdue.md
spec_sha256: 08e47209a91be17596f73eba0569502c4b13adf279d24a48dd9d09793cfa8137
spec_frozen_sha256: 46cd9c649fe1c4b2a315e6b8132ad685b625b1bc20da59c75a3eb50b1dda2f7d
---

# PO-Briefing: feat-613-c4b2-mcp-complete-setdue

- **Spec:** docs/specs/feat-613-c4b2-mcp-complete-setdue.md
- **Issue:** #613
- **Erstellt:** 2026-11-02

## Was gebaut wird

Claude kann über den Dienst vorbereiten, dass eine Aufgabe abgehakt oder ihre Fälligkeit gesetzt oder entfernt wird.

## Definition of Done

Beide neuen Werkzeuge legen einen wartenden Auftrag mit erwartetem Stand an; fehlerhafte, veraltete oder fremde Anfragen werden mit Meldung abgelehnt.

## Wie geprüft wird

Automatische Tests gegen eine echte Datenbank belegen Aufträge und Ablehnungen; ob ein Gerät den Auftrag später richtig ausführt, prüft dieser Schnitt nicht.

## Kritische Anmerkungen

- Zusätzlich verlangt die Spec: Claude muss den Zeitstempel der gelesenen Liste mitgeben, sonst entsteht kein Auftrag (nicht im Ticket, technische Absicherung).
- Noch ruft nichts den Dienst auf; Aufträge bleiben unausgeführt, bis ein Gerätekanal existiert.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
