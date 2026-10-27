---
spec_file: docs/specs/tooling/feat-715-s2-voraussetzungen-hook.md
spec_sha256: 2624650701cacef9a4c63e70ad766afcbffc8d536d4f988ad08fe140dc3d632c
spec_frozen_sha256: 4304ce08f4a7f576f06571d502b5485b6956833fdb22f651e4d66015f046b53b
---

# PO-Briefing: feat-715-s2-voraussetzungen-hook

- **Spec:** docs/specs/tooling/feat-715-s2-voraussetzungen-hook.md
- **Issue:** #715
- **Erstellt:** 2026-10-27

## Was gebaut wird

Nach /clear nennt jede Epic-Sitzung automatisch das nächste freie Ticket; die Reihenfolge steht dafür auf GitHub.

## Definition of Done

Ticket 176 wird nicht mehr vorgeschlagen, und der Hinweis erscheint nach /clear in unter 30 Sekunden.

## Wie geprüft wird

13 Skripttests, ein echter Durchlauf (14–17 s) und GitHub-Abfragen belegen es; nicht geprüft: Erscheinen in einer echten neuen Sitzung.

## Kritische Anmerkungen

- Abweichung: 176 erscheint nicht mehr als blockiert in der Ausgabe; Folge-Ticket 723.
- Epic 612 erhält nur Abhängigkeiten der Stufen 1→2 und 2→3, spätere Stufen bleiben ungeordnet.
- Hook-Eintrag liegt außerhalb des Projekts, unversioniert; jedes /clear wartet bis 17 Sekunden.

## Freigabe-Frage

Ist es für dich in Ordnung, dass nach /clear bis zu 17 Sekunden gewartet wird?
