---
spec_file: docs/specs/intents/fix-409-watch-reset.md
spec_sha256: 55e2ebd8a70b90452849a9c65fb9560081874b0a6f56a9cb7182d45df9a1acb8
---

# PO-Briefing: fix-409-watch-reset

- **Spec:** docs/specs/intents/fix-409-watch-reset.md
- **Issue:** #409
- **Erstellt:** 2026-10-15

## Was gebaut wird

Nach dem Diktieren und „Fertig“ zeigt die Watch kurz „Gespeichert“ und ist dann wieder bereit für die nächste Aufgabe.

## Definition of Done

Auf der Watch erscheint nach Fertig etwa 1,5 Sekunden Gespeichert, dann das leere Feld; eine zweite Aufgabe lässt sich sofort erfassen.

## Wie geprüft wird

Ein Simulator-Test erfasst zwei Aufgaben hintereinander und beweist Bestätigung und leeres Feld; Speicherfehler und App-Hintergrund bleiben ungetestet.

## Kritische Anmerkungen

- Speicherfehler und Hintergrund-Wechsel haben keinen automatischen Test, nur Code-Prüfung.
- Anzeige heißt weiterhin „Gespeichert“, nicht „Gesichert“ wie von dir genannt.
- Echter Nachweis auf der Uhr erst über TestFlight; Ticket bleibt bis dahin offen.

## Freigabe-Frage

Soll die Watch nach „Fertig“ 1,5 Sekunden „Gespeichert“ zeigen und danach von selbst zurückspringen?
