---
spec_file: docs/specs/tooling/feat-715-s2-voraussetzungen-hook.md
spec_sha256: 5239efa0de7fe47bea97370a51e3bfa767796e3deeab6cf9b7362d8fab57b464
spec_frozen_sha256: 8c578b21e8b123be6ede193d3431337bdb5a219c76cfea2e9a3693f5ae08e39b
---

# PO-Briefing: feat-715-s2-voraussetzungen-hook

- **Spec:** docs/specs/tooling/feat-715-s2-voraussetzungen-hook.md
- **Issue:** #715
- **Erstellt:** 2026-10-27

## Was gebaut wird

Nach /clear erscheint automatisch das nächste freie Ticket des Epics; Reihenfolgen stehen als Voraussetzungen auf GitHub.

## Definition of Done

Nach /clear erscheint der Vorschlag, Ticket 176 kommt nicht mehr vor seinen Voraussetzungen, Wartezeit ist gemessen.

## Wie geprüft wird

Skripttests mit Attrappen prüfen Hinweis und Stille; Voraussetzungen und Wartezeit werden nur einmal von Hand geprüft.

## Kritische Anmerkungen

- Bis zu 14 Sekunden Wartezeit bei jedem /clear in Epic-Sitzungen; Beschleunigung nur als Folge-Ticket.
- Zusätzlich zu Ticket 176 trägt die Spec Epic 612 ein; eine falsche Voraussetzung sperrt Arbeit.
- Der Einstellungseintrag liegt außerhalb des Projekts, unversioniert, und wirkt erst nach dem nächsten Abgleich.

## Freigabe-Frage

Soll der Vorschlag nach /clear automatisch erscheinen, auch wenn dafür bis zu 14 Sekunden Wartezeit entstehen können?
