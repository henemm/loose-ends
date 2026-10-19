---
spec_file: docs/specs/feat-478-mac-einstellungen-papier.md
spec_sha256: 6ef0362b0a4930867b5a6fea1be522847a48f78725a265d29b9966cc8341ee3f
spec_frozen_sha256: 775467ca6bb3ecc7a86d33b73ba7c4ca6509f08aa2c1495ba645cfd33c294d43
---

# PO-Briefing: feat-478-mac-einstellungen-papier

- **Spec:** docs/specs/feat-478-mac-einstellungen-papier.md
- **Issue:** #478
- **Erstellt:** 2026-10-18

## Was gebaut wird

Das Mac-Einstellungsfenster erscheint im Papierstil mit Haarlinien statt grauer Karten; alle Einträge und Funktionen bleiben.

## Definition of Done

Beim Öffnen mit ⌘, zeigt das Mac-Fenster Papier, Haarlinien und graue Hinweise; iPhone und iPad sehen unverändert aus.

## Wie geprüft wird

Ein Galerietest prüft nur, dass alle Einträge vorhanden sind; das Aussehen wird per Bildbetrachtung beurteilt, nicht automatisch.

## Kritische Anmerkungen

- Fenstertitel bleibt Systemschrift statt verlangter 15 pt halbfett; bewusste Abweichung vom Ticket.
- Tafel zeigt eine Tagesende-Auswahl, die App zwei Schalter; das Fenster folgt der App, nicht der Tafel.
- Papier, Linien und Schalter haben keinen automatischen Test, nur Bildurteil.

## Freigabe-Frage

Gibst du das Papier-Design der Mac-Einstellungen frei, mit Systemtitel statt Wunschschrift im Fenstertitel?
