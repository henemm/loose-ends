---
spec_file: docs/specs/feat-842-schnitt-1-probe-texte.md
spec_sha256: 970b90b899147db87e1f88abf0620479fbac5df5c3747f33473228487c4a5e56
spec_frozen_sha256: 0bcb7471404610370c6d1a233e36b246e156482e11309f37f7ae54d92af56d69
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
