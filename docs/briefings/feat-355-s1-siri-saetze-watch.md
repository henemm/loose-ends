---
spec_file: docs/specs/intents/feat-355-s1-siri-saetze-watch.md
spec_sha256: e19813a97de9d6b49d2f1f1948f7db3f37e63350494e0f76bc4a668e73b2176e
---

# PO-Briefing: feat-355-s1-siri-saetze-watch

- **Spec:** docs/specs/intents/feat-355-s1-siri-saetze-watch.md
- **Issue:** #355
- **Erstellt:** 2026-10-13

## Was gebaut wird

Die Apple Watch versteht deutsche Siri-Sätze, darunter neu „Erfasse in Loose Ends“, und fragt auf Deutsch nach dem Text.

## Definition of Done

Du sagst auf der Watch „Erfasse in Loose Ends“, Siri fragt nach dem Text, speichert ohne App-Start, und die Aufgabe erscheint auf dem iPhone.

## Wie geprüft wird

Tests und Paketinspektion belegen nur, dass die deutschen Texte im Watch-Paket liegen; ob Siri sie versteht, zeigt allein dein Test über TestFlight.

## Kritische Anmerkungen

- Siri fragt auf der Watch womöglich gar nicht nach dem Text (bekannter Apple-Fehler); dann ist das Ziel verfehlt, Ersatzticket nötig.
- Dialog bleibt „Was soll ich aufnehmen?“ statt der im Ticket genannten Formulierung „Was soll ich mir merken?“.
- Alternative App-Namen („Loose End“) wirken auf der Watch ohne Siri-Berechtigung eventuell nicht; Tickettext selbst wurde nicht im Original gelesen.

## Freigabe-Frage

Soll Schnitt 1 mit dem Dialogtext „Was soll ich aufnehmen?“ und dem Risiko, dass die Siri-Rückfrage auf der Watch scheitert, starten?
