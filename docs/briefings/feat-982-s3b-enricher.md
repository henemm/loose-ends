---
spec_file: docs/specs/enrichment/feat-982-schnitt-3b-enricher-aus-release.md
spec_sha256: 1ffc01bd969e1515b240d0c55a1ddc880b84b6b0fe89dcce614a38ea04e338a5
spec_frozen_sha256: 297636db036872cd45a8f6957e5e4d42ed9b460f4c448599f62cd1f42b187975
---

# PO-Briefing: feat-982-s3b-enricher

- **Spec:** docs/specs/enrichment/feat-982-schnitt-3b-enricher-aus-release.md
- **Issue:** #982
- **Erstellt:** 2026-11-27

## Was gebaut wird

Die ausgelieferte App, Widgets und Teilen-Erweiterung enthalten den ungenutzten KI-Modellcode nicht mehr; sichtbar ändert sich nichts.

## Definition of Done

Ein Testbau der App enthält keine Spur des Modells mehr, Erfassung von „Vor Konzert“ funktioniert wie zuvor, und alle Tests laufen grün.

## Wie geprüft wird

Tests und Binärprüfung belegen die Abwesenheit des Modells im Release-Bau; Start, Widget und Teilen auf dem Gerät prüft nur TestFlight.

## Kritische Anmerkungen

- Ursprungsanfrage nur über Kontext-Dokument geprüft, Issue-Text war nicht lesbar; Gerätefeedback zu Build 145 liegt laut Kontext nicht vor.
- Die Archivprüfung läuft erst im nächsten TestFlight-Lauf; vorher gibt es nur den lokalen Release-Simulatorbau als Beleg.
- Datenschutztext nennt Apple Intelligence weiterhin; Änderung bewusst ausgeklammert und braucht später deine Freigabe.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
