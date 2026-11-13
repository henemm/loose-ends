---
spec_file: docs/specs/feat-623-skills-plugin.md
spec_sha256: be37bac3b8f2d43d553773957ec717a03a1a5a19eacd2a1ec703c0157268ba68
spec_frozen_sha256: 6a25fc79611b3a8b192a8e508bba5be6587946ae5e85fdad68e4b133a0aca71f
---

# PO-Briefing: feat-623-skills-plugin

- **Spec:** docs/specs/feat-623-skills-plugin.md
- **Issue:** #623
- **Erstellt:** 2026-11-13

## Was gebaut wird

Claude bekommt beim Verbinden mit Loose Ends eine kurze Anleitung für Tag planen und Texte zerlegen, ohne Plugin.

## Definition of Done

Die Anleitung kommt beim Verbinden an, ist höchstens 2 KB lang, nennt nur echte Werkzeuge, und die gesamte Serverprüfung läuft grün.

## Wie geprüft wird

Automatische Tests belegen Inhalt, Länge und Ankunft der Anleitung; ob claude.ai sie wirklich beachtet, belegt erst der spätere gemeinsame Durchlauf.

## Kritische Anmerkungen

- Ob claude.ai die Anleitung liest, ist unbelegt; bei negativem Ergebnis wird das Ticket mit Plugin neu geschnitten.
- Abweichung vom Ticket (Plugin, drei Skills, Wochenrückblick) ist von dir bereits entschieden.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
