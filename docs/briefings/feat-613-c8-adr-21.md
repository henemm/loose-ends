---
spec_file: docs/specs/fast/feat-613-c8-adr-21.md
spec_sha256: 1eb562237b1a9a5d4cc1cfbd3ca6f907ff3d80f229edc1540360f1157a4fcf72
spec_frozen_sha256: f5715d4510b88998dde600d73f6a1ddb7d020c7a353e47b6483572a943d564b0
---

# PO-Briefing: feat-613-c8-adr-21

- **Spec:** docs/specs/fast/feat-613-c8-adr-21.md
- **Issue:** #613
- **Erstellt:** 2026-11-02

## Was gebaut wird

Die Entscheidung "iCloud bleibt, Claude bekommt ein eigenes Fenster" wird als neuer Beschluss ADR-21 festgehalten.

## Definition of Done

ADR-21 steht in der Entscheidungsdatei, der alte iCloud-Beschluss verweist darauf, und Ticket #613 ist geschlossen.

## Wie geprüft wird

Nur Textsuche und Diff-Prüfung belegen, dass der Eintrag existiert; ob Inhalt und Begründung stimmen, prüft kein Test.

## Kritische Anmerkungen

- Ticket verlangte Messung aus dem Prototyp und Kostenrechnung im Beschluss; beides fehlt, #613 würde trotzdem geschlossen.
- Alter Beschluss wird nur ergänzt, nicht ersetzt, wie das Ticket forderte (folgt deiner Weg-B-Entscheidung).
- Datenschutztext ("kein eigener Server") bleibt vorerst unverändert; Änderung auf #625 verschoben, App ruft den Dienst bisher nicht auf.

## Freigabe-Frage

Darf #613 ohne Messung und Kostenrechnung im Beschluss geschlossen werden, oder sollen beide noch ergänzt werden?

## Ampel

Ampel: rot
