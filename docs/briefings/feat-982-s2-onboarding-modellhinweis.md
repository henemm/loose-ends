---
spec_file: docs/specs/enrichment/feat-982-schnitt-2-onboarding-ohne-modellhinweis.md
spec_sha256: 9361be3851d3aae43c7f0fd2d301083e8e3a8edb80d0d97c678ce441304eea17
spec_frozen_sha256: 34167e83e68698d8121219050272de2e3200c360c2cead33e08fe66aede99d33
---

# PO-Briefing: feat-982-s2-onboarding-modellhinweis

- **Spec:** docs/specs/enrichment/feat-982-schnitt-2-onboarding-ohne-modellhinweis.md
- **Issue:** #982
- **Erstellt:** 2026-11-26

## Was gebaut wird

Der erste Einrichtungsschritt verliert endgültig seinen Apple-Intelligence-Hinweis samt Texten und Tests; sichtbar ändert sich nichts.

## Definition of Done

Einrichtung läuft wie bisher in drei Schritten, nirgends erscheint ein Hinweis zu Apple Intelligence, und alle Tests sind grün.

## Wie geprüft wird

Ein Oberflächentest belegt, dass auch mit altem Testschalter kein Hinweis erscheint; Durchlauf und Überspringen bleiben getestet, das Löschen der Texte nur per Suche.

## Kritische Anmerkungen

- Löschen der drei Texte und der Code-Reste wird nur per Textsuche geprüft; der Katalogwächter prüft Vollständigkeit, nicht Abwesenheit.
- Im Produkt war der Hinweis seit Schnitt 1 schon unsichtbar; dieser Schnitt räumt nur auf.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
