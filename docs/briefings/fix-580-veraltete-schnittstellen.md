---
spec_file: docs/specs/fix-580-veraltete-schnittstellen.md
spec_sha256: c7b203734ca883df543e1ddcb8128042e7dbd21137ecc9bbcc35539ad69ebdc6
spec_frozen_sha256: 5f03fd4b10f38648fdb390d823ca4527086aa73e7b9efa162ef1524efa03978d
---

# PO-Briefing: fix-580-veraltete-schnittstellen

- **Spec:** docs/specs/fix-580-veraltete-schnittstellen.md
- **Issue:** #580
- **Erstellt:** 2026-10-24

## Was gebaut wird

Sechs veraltete Systemaufrufe werden ersetzt, ohne dass sich für Nutzer beim Teilen, in der Detailansicht oder bei Mitteilungen etwas ändert.

## Definition of Done

Der Bau meldet keine der sechs Warnungen mehr, alle Tests sind grün, und die Detailansicht sieht vorher und nachher gleich aus.

## Wie geprüft wird

Automatisch nur die Textdekodierung und die Warnungsfreiheit; ob Teilen aus Safari, Notizen, Mail, Fotos und Dateien weiter klappt, zeigt nur dein iPhone.

## Kritische Anmerkungen

- Teilen ist ohne Gerätetest unbewiesen; Prüfung erst nach deinem „jetzt ist ein Test möglich“, Ticket bleibt bis dahin offen.
- Mail als Zeichenkette wird bewusst nicht mehr gelesen; bisher nie beobachtet, ein Verlust bliebe aber unbemerkt.
- Tägliche Mitteilungsplanung ist nur schwach belegbar: Fehler erscheinen im Protokoll, das TestFlight nicht liefert.

## Freigabe-Frage

Gibst du die Ablösung frei, mit Gerätetest später und Ticket offen bis zu deiner Rückmeldung?
