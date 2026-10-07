---
spec_file: docs/specs/fix-203-kalender-quelle.md
spec_sha256: 0c421f434cb7b141621605bdabe57f48b07dc5d06ad44db166ab98ae6b03d511
---

# PO-Briefing: bug-203-kalender-termin

- **Spec:** docs/specs/fix-203-kalender-quelle.md
- **Issue:** #203
- **Erstellt:** 2026-10-06

## Was gebaut wird

Der Schalter „Im Kalender anzeigen“ legt „Loose Ends“ künftig in iCloud statt Google an und zeigt den Zielkalender.

## Definition of Done

In der Kalender-App erscheint „Loose Ends“ mit dem Termin, die Aufgabe zeigt „Kalender · Loose Ends“; ohne erlaubtes Konto erscheint ein Hinweis.

## Wie geprüft wird

Tests belegen die Konto-Reihenfolge und den Erfolgsweg im Simulator; Googles Ablehnung und der Hinweis sind nicht automatisch getestet.

## Kritische Anmerkungen

- Nur Teil A: Rückfrage zu Uhrzeit und Dauer, Zeile „Termin“ und wählbarer Kalender fehlen; #203 bleibt offen.
- Der Hinweis bei fehlendem Konto hat keinen automatischen Test, nur eine Nachstellung von Hand.
- Startzeit, Dauer und ganztägig gelten als „stimmt schon“, ohne neuen Test.

## Freigabe-Frage

Soll Teil A allein, ohne Rückfrage-Sheet und Kalenderwahl, freigegeben werden?
