---
spec_file: docs/specs/feat-226-schnitt-2a-uebergabe.md
spec_sha256: d96e83f9890e1e668eb5a4161faf6feee26d44018bfeb1b4662684edf3b02d04
---

# PO-Briefing: feat-226-zustellung

- **Spec:** docs/specs/feat-226-schnitt-2a-uebergabe.md
- **Issue:** #226
- **Erstellt:** 2026-10-07

## Was gebaut wird

Intern wird geplant, welche Ortserinnerungen dem System übergeben werden, damit keine doppelt erinnert; nichts Sichtbares.

## Definition of Done

Neue Planungsfunktion samt Tests läuft grün, bestehende Tests bleiben grün; in der App ändert sich nichts.

## Wie geprüft wird

Unit-Tests belegen die Rechenregeln, nicht dass das iPhone wirklich erinnert; Systemanschluss und Gerätenachweis folgen erst in 2b.

## Kritische Anmerkungen

- Ticket-DoD (Erinnerung auf dem Gerät nachgewiesen) erst mit 2b erfüllbar; 2a allein bringt Nutzern nichts.
- Annahme „nicht mehr offen heißt ausgelöst“ ist unbelegt; verliert das System eine Anfrage, bleibt die Aufgabe stumm.
- Aufgabe über Rang 20 hinaus erinnert nach Rückkehr erneut; zwei Kriterien haben keinen eigenen Test.

## Freigabe-Frage

Gibst du den unsichtbaren Zwischenschritt 2a frei, obwohl Ortserinnerungen erst nach Schnitt 2b wirklich funktionieren?
