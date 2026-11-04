---
entity_id: feat-818-s2-perlen-ohne-budget
type: feature
created: 2026-11-04
updated: 2026-11-04
status: approved
workflow: feat-818-s2-perlen-ohne-budget
---

# Spec: #818 Schnitt 2 — Perlen ohne Obergrenze

Issue #818 Punkt 1. Henning, 2026-11-04: Die Perle hebt eine Aufgabe hervor; die Schnur braucht nur die Zahl der Perlen, bis sie voll ist.
Eine Obergrenze offener Perlen ist nicht nötig und bräuchte einen Hinweis „aufgebraucht“ — „nimm das Budget komplett raus“.
Ein Zeitraum entfällt ebenfalls. Weitere Schnitte (eigene Spec): Schnurlänge einstellbar, volle Schnur bestätigen.

## Approval

- [x] Approved — Henning am 2026-11-04.

## Purpose

Bisher durften höchstens fünf offene Aufgaben eine Perle tragen (`TaskActions.countsBudget`, #645). Das entfällt ersatzlos:
jede Aufgabe kann eine Perle bekommen. Das Knäuel zählt weiter immer.

Ohne Modell geht es nicht: nicht relevant (reine Nutzeraktion).

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| Shared/Services/TaskActions.swift | MODIFY | `countsBudget`, `canCount` entfallen; `toggleCounts` ohne `among` |
| Shared/Models/ViewRules.swift | MODIFY | `counting(in:)` entfällt (nur das Budget las es) |
| LooseEnds/Views/TaskInteractions.swift | MODIFY | Menü: immer „Attach a bead“, kein grauer Eintrag |
| LooseEnds/Views/FieldSettingsView.swift, Localizable.xcstrings | MODIFY | Erklärsatz ohne „höchstens fünf offene zugleich“; Schlüssel „Attach a bead (%lld of %lld)“ entfällt |
| LooseEndsTests/KnaeuelTests.swift, LooseEndsUITests/DriveSmokeTests.swift | MODIFY | Budgettest wird „ohne Grenze“ |
| CLAUDE.md, docs/project/00-entscheidungen.md | MODIFY | Stand nachgezogen |

## Test Plan

- [ ] `BeadsTests.marksHaveNoLimit`: acht Aufgaben bekommen je eine Perle als Nutzer-Revision; Abnehmen ist eine zweite Revision; das Knäuel zählt von selbst.
- [ ] `DriveSmokeTests.testCountsShowsTheBeadAndTheWeekString`: sechs Perlen in der Liste, kein grauer Eintrag, die Schnur zeigt nach dem Erledigen „1 of 5“.
- [ ] `scripts/test_catalog_languages.py` grün (lokal gelaufen).

Kein Pfad der Geräteliste berührt.
