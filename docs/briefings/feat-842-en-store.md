---
spec_file: docs/specs/feat-842-schnitt-1-probe-texte.md
spec_sha256: 9813e02d6a18aa2826d18df7b62fcd6bd37cfa167389b9649c259bf835af3141
spec_frozen_sha256: 7063784437df12436fdcce37d5f927f4c0ec56c808165f2ef62ea6d05d119aea
---

# PO-Briefing: feat-842-en-store

- **Spec:** docs/specs/feat-842-schnitt-1-probe-texte.md
- **Issue:** #842
- **Erstellt:** 2026-11-06

## Was gebaut wird

Ein reiner Lesetest zeigt, welche Store-Texte und Bildplatzierungen in App Store Connect stehen, bevor der englische Text geschrieben wird.

## Definition of Done

Der Handlauf nach dem Merge zeigt Beschreibung, Schlüsselwörter und Support-Adresse von Deutsch und Englisch sowie die Bildplatzierungen, oder nennt je Abfrage den Fehler.

## Wie geprüft wird

Automatische Tests gegen einen lokalen Nachbau belegen Ausgabe und Fehlertoleranz; ob Apples echte Schnittstelle antwortet, zeigt erst der Handlauf.

## Kritische Anmerkungen

- Nur Schnitt 1 von 4: Die englische Store-Seite entsteht erst mit Schnitt 2 bis 4, #842 bleibt offen.
- Der Abfragepfad für Bildplatzierungen ist aus der Recherche, unerprobt; ein Fehler im Lauf wäre ein Befund, kein Mangel.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
