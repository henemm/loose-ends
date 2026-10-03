---
spec_file: docs/specs/tooling/fix-174-testflight-ios27.md
spec_sha256: 9dc848b6dddc465c57b5108ceed7663666af0e8dafb74d2032721a6dc1144574
---

# PO-Briefing: fix-174-testflight-ios27

- **Spec:** docs/specs/tooling/fix-174-testflight-ios27.md
- **Issue:** #174
- **Erstellt:** 2026-10-03

## Was gebaut wird

Der TestFlight-Build entsteht wieder aus dem iOS-27-Stand und wird vor dem Upload automatisch auf Version, Symbole und Datenschutztexte geprüft.

## Definition of Done

Ein Build mit Version 0.1.0 erscheint in TestFlight, und eine Prüftabelle zeigt für alle vier Ziele iOS-27-Stand statt 26.0.

## Wie geprüft wird

Absichtlich falsche Testarchive und ein echtes lokales Archiv beweisen die Prüfung; ob TestFlight den Build annimmt, zeigt erst der Lauf nach Freigabe.

## Kritische Anmerkungen

- Im Code gibt es keine iOS-27-abhängigen Pfade; der Beleg zeigt nur den Baustand, nicht geändertes Verhalten.
- Build läuft auf einem Vorschau-Rechner von GitHub; fällt dieser weg, schlägt der Lauf fehl.
- Datenschutz-Manifest bewusst ausgeklammert (eigenes Ticket); für spätere App-Store-Einreichung nötig.

## Freigabe-Frage

Soll der Build nach dem Merge wirklich in TestFlight bei der Gruppe Familie landen?
