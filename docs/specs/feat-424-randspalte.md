---
entity_id: feat-424-randspalte
type: feature
created: 2026-10-15
status: approved
---

# Spec: #424 Randspalte und Unteraufgaben ohne Kreis

## Approval

- [x] Approved (Henning, 2026-10-15): Z2 und U in https://claude.ai/artifact/AppBHrhym57SBMURaQck5P

## Source

| Datei | Änderung |
|---|---|
| `Shared/Models/ViewRules.swift` | `MarginMark`, `marginMark(of:now:calendar:)` |
| `LooseEnds/Views/TaskRow.swift` | Randspalte links, Datum aus der Merkmalzeile, Dauer nur noch mit Datum als Merkmal |
| `LooseEnds/Views/SubtasksSection.swift`, `TaskListView.swift` | Unteraufgaben ohne Kreis, erledigt mit grauem Haken |
| `LooseEndsTests/MarginMarkTests.swift` | Regeltests |

## Acceptance Criteria

- **AC-1:** Heute mit Uhrzeit → Uhrzeit, rot; heute ohne → „Heute“, rot.
- **AC-2:** Vorbei mit Uhrzeit → „Gestern“ / „Vor N Tagen“, rot; ohne Uhrzeit → „Seit gestern“ / „Seit N Tagen“, grau.
- **AC-3:** Morgen → „Morgen“; 2 bis 6 Tage → Wochentag kurz; später → Tag und Monat.
- **AC-4:** Ohne Fälligkeit, mit Dauer → Dauer am Rand und nicht in der Merkmalzeile; sonst leer.
- **AC-5:** Erledigt und geparkt → leer. Die Spalte hat immer dieselbe Breite.
- **AC-6:** Unteraufgaben: offen ohne Zeichen, erledigt mit grauem Haken und durchgestrichen; VoiceOver sagt „Erledigt“/„Offen“ wie bisher.

## Abnahme

Stufe 1: `MarginMarkTests`, voller Unit- und UI-Lauf in CI. Stufe 2: kein Simulator in der Cloud-Sitzung, Beleg UI Smoke.
Stufe 3: Kein Pfad der Geräteliste berührt.
