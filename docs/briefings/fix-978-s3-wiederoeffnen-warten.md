---
spec_file: docs/specs/fix-978-s3-wiederoeffnen-warten.md
spec_sha256: 7c98068c38b61773426d423b312f6676414631ac62e2388b12e5675710206504
spec_frozen_sha256: 61db59df2c38dc8232dd27a1ef664d8e13a93f2d2f381fd31d3d4e987c9914b8
---

# PO-Briefing: fix-978-s3-wiederoeffnen-warten

- **Spec:** docs/specs/fix-978-s3-wiederoeffnen-warten.md
- **Issue:** #978
- **Erstellt:** 2026-11-25

## Was gebaut wird

Eine reine Messprobe im automatischen Mac-Test, die klärt, ob langes Gedrückthalten das Menüleisten-Fenster zuklappen lässt.

## Definition of Done

Ein Probelauf mit mindestens 20 Klicks je Variante liegt ausgewertet vor, und die vorab festgelegte Regel nennt den Folgeschritt.

## Wie geprüft wird

Skripttests prüfen die Auswertung, der Probelauf liefert die Messung; ob Nutzer das Zuklappen je sehen, wird nicht geprüft.

## Kritische Anmerkungen

- Dieser Schnitt behebt den Fehler nicht; #978 bleibt offen, die eigentliche Korrektur folgt frühestens im nächsten Schnitt.
- Die Ursache ist nur eine Vermutung; frühere Versuche wurden bereits widerlegt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
