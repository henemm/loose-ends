---
spec_file: docs/specs/fix-978-s2-panel-ernte.md
spec_sha256: 059c54ddd0ad8efb317c7d51161b15f311dc9aa74470e920f27d5391b2eb3fd7
spec_frozen_sha256: 0c90af415e126583a6ee8ae719a731799733b2fb2450004e9272efe0954f1693
---

# PO-Briefing: fix-978-s2-panel-ernte

- **Spec:** docs/specs/fix-978-s2-panel-ernte.md
- **Issue:** #978
- **Erstellt:** 2026-11-23

## Was gebaut wird

Das Menüleisten-Panel der Mac-App bekommt genauere Diagnose, und ein Wiederholungslauf zählt das seltene Selbstschließen nach.

## Definition of Done

Ein Wiederholungslauf liefert je Klickart Zahl der Versuche und Fehlschläge samt Zeitverlauf; die Ergebnisse stehen im Issue, das Verhalten der App bleibt unverändert.

## Wie geprüft wird

Ein Skript-Test prüft die Zählung mit festen Beispielen, der Pflicht-Job bleibt grün; ob die Ursache gefunden wird, beweisen die Tests nicht.

## Kritische Anmerkungen

- Issue verlangt Ursache und Fix; dieser Schnitt liefert nur Diagnose, Fix folgt in Schnitt 3, Issue bleibt offen.
- Ursache kann offen bleiben; null Fälle gelten als gültiges Ergebnis, dann startet Claude weitere Läufe.
- Neue Diagnosezeilen und Kontrollklick werden nur per Sichtung der Artefakte belegt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
