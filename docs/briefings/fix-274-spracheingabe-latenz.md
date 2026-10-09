---
spec_file: docs/specs/fix-274-spracheingabe-latenz.md
spec_sha256: 64a8ff1c3883bd8920bdc16327af577586d71133c0ef05639388b2eed3427a35
---

# PO-Briefing: fix-274-spracheingabe-latenz

- **Spec:** docs/specs/fix-274-spracheingabe-latenz.md
- **Issue:** #274
- **Erstellt:** 2026-10-09

## Was gebaut wird

Gesprochener Text erscheint etwa eine Sekunde nach dem Sprechen statt erst nach zwölf Sekunden.

## Definition of Done

Henning sieht in der TestFlight-Fassung auf iPhone und iPad das erste Wort kurz nach Sprechbeginn.

## Wie geprüft wird

Ein Mac-Test misst die Zeit bis zum ersten Wort und den Textinhalt, nicht das Verhalten auf iPhone oder iPad.

## Kritische Anmerkungen

- Ursache nur am Mac nachgestellt; der im Ticket verlangte Gerätebeleg auf iPhone und iPad folgt erst später.
- Der lange Start bis zum Zuhören wurde nicht gemessen und könnte bleiben.
- Der Zeittest wird in CI und Simulator übersprungen.

## Freigabe-Frage

Soll die Spracherkennung schneller gestellt werden, mit Geräteprüfung erst nach Hennings ausdrücklicher Freigabe?
