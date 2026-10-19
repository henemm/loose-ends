---
spec_file: docs/specs/tooling/fix-516-schnitt-1-testlauf-waechter.md
spec_sha256: 145eaee7e604c52be107df0d3fcd0a0d26a9be492c3ca46a693bc46cd3071932
spec_frozen_sha256: 13f14838b4b8caf4e53d41ebcd3bb1f39241e307e4159aeef2cb92bdae4ee973
---

# PO-Briefing: fix-516-testlauf-waechter

- **Spec:** docs/specs/tooling/fix-516-schnitt-1-testlauf-waechter.md
- **Issue:** #516
- **Erstellt:** 2026-10-19

## Was gebaut wird

Ein Testlauf, der 15 Minuten nichts mehr meldet, wird automatisch abgebrochen, damit andere Sitzungen nicht stundenlang warten.

## Definition of Done

Ein künstlich stummer Testlauf endet nach der Frist mit sichtbarer Fehlermeldung, die gemeinsame Sperre ist frei, parallele Läufe bleiben unberührt.

## Wie geprüft wird

Skripttests mit Attrappen beweisen Abbruch, Meldung und Sperrfreigabe; ein echter Xcode-Hänger und die 15-Minuten-Frist selbst werden nicht geprüft.

## Kritische Anmerkungen

- Wartelisten-Fairness (zweiter Punkt des Tickets) fehlt bewusst, kommt als Schnitt 2; Ticket bleibt offen.
- 15 Minuten sind geschätzt; ein gesunder, lange stiller Lauf könnte fälschlich abgebrochen werden.
- Ticket nicht direkt lesbar; gegen Kontext-Dokument geprüft. Dokuänderung in der Anleitung hat keinen Test.

## Freigabe-Frage

Soll der Wächter mit 15 Minuten Stille als Abbruchgrenze gebaut werden, und die Warteliste später separat folgen?
