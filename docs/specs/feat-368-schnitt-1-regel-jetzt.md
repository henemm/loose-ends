---
entity_id: feat-368-schnitt-1-regel-jetzt
type: feature
created: 2026-10-12
updated: 2026-10-12
status: draft
workflow: feat-368-startseite-drei-zonen
---

# Spec: #368 Schnitt 1 — Regel „Jetzt“

## Approval

- [ ] Approved (Henning)

Teil-Spec der freigegebenen Gesamt-Spec `docs/specs/feat-368-startseite-drei-zonen.md` (Henning, 2026-10-12, „approved“).
Sie übernimmt deren Abschnitt „Schnitt 1: Regel ‚Jetzt‘“ und die Acceptance Criteria AC-1 bis AC-4 **wörtlich**; inhaltlich
ändert sich nichts. Grund der Teilung: Die Gegenprüfung (Adversary) arbeitet jedes AC der verknüpften Spec ab, und die
Gesamt-Spec beschreibt vier getrennte Lieferungen. Jede Lieferung bekommt deshalb eine eigene Teil-Spec, wie bei #226
(`feat-226-schnitt-*`). Die Gesamt-Spec bleibt der verbindliche Plan für #368; Schnitte 2 bis 4 folgen als eigene Teil-Specs.

## Purpose

Die reine Regel für den Block „Jetzt“ der iPhone-Startseite: alle überfälligen, heute fälligen und vorgemerkten Aufgaben,
**jede einmal**, überfällig zuerst, dann heute fällig, dann die übrigen vorgemerkten nach `nextRank`. Die Startseite selbst
ändert sich in diesem Schnitt nicht; Schnitt 2 baut die Zone auf dieser Regel.

**Rein regelbasiert.** Filter und Sortierung über vorhandene Felder (`dueDate`, `nextRank`, `status`, `isBlocked`); kein
Modell beteiligt, kein Prompt, kein Schema.

**#339 / PR #340.** #339 („Fällig vs. Als nächstes“) geht in diesem Schnitt auf: die dort gesuchte Regel ist `ViewRules.now`.
PR #340 (`dueToday` ohne `nextRank`) wird nicht gemergt, sondern geschlossen; `dueToday` bleibt unverändert.

## Source

- **Geändert:** `Shared/Models/ViewRules.swift` (neue reine Regel `now`, `struct NowTasks`)
- **Neu:** `LooseEndsTests/NowRuleTests.swift`
- **Doku:** `docs/project/02-datenmodell-und-ansichten.md`

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Models/ViewRules.swift` | MODIFY | `struct NowTasks` (`overdue`, `today`, `lined`, `all`) und `static func now(in:now:calendar:) -> NowTasks` |
| `LooseEndsTests/NowRuleTests.swift` | CREATE | Unit-Tests der Regel (Swift Testing, `TestStore`) |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | Regel „Jetzt“ in die Berechnungsregeln |

Geschätzt 3 Dateien, ca. +160 LoC. **Kein Pfad der Geräteliste berührt.** Keine neuen Berechtigungen, keine
AppStorage-Schlüssel, kein Modellfeld, kein CloudKit-Schema. `DueNotificationCenter` und `badgeCount` unverändert.

## Implementation Details

`ViewRules.now(in:now:calendar:)` liefert eine `NowTasks`-Struktur:

- Grundmenge: Vereinigung aus `dueToday(in:now:calendar:)` und `tasks(for: .next, in:now:calendar:)`, nach `id` dedupliziert.
  Damit gelten Unteraufgaben, Erledigtes, Geparktes und Blockiertes als draußen, ohne die Bedingungen zu duplizieren.
- `overdue`: `dueDate` vor Beginn des heutigen Tages (Kalendertag, nicht Uhrzeit), älteste zuerst. Eine Aufgabe von heute 09:00
  bei jetzt 10:00 ist „heute fällig“, nicht „überfällig“.
- `today`: `dueDate` an diesem Tag, früheste Uhrzeit zuerst.
- `lined`: der Rest (hat `nextRank`, ist weder überfällig noch heute fällig), nach `nextRank`. Eine vorgemerkte Aufgabe, die
  zugleich überfällig oder heute fällig ist, steht in `overdue`/`today` (Zeitdruck gewinnt, PO-Entscheidung).
- `all` = `overdue + today + lined`. Gleiche Fälligkeit: Reihenfolge nach `nextRank` (ohne Rang zuletzt), dann `capturedAt`.

`dueToday`, `badgeCount`, `tasks(for:)` bleiben **unverändert**. Doku 02: eine Zeile „Jetzt (nur Startbildschirm iPhone)“.

## Test Plan

Unit, `LooseEndsTests/NowRuleTests.swift` (Swift Testing, `TestStore`, `now` fix auf Donnerstag 12.03.2026 10:00 Berlin):
`overdueBeforeTodayBeforeLined`, `lineEachTaskOnce`, `overdueAndLinedStaysInTimePressureGroup`, `todayAtEarlierHourIsToday`,
`todaySortedByHour`, `linedSortedByRank`, `overdueOldestFirst`, `blockedSubtasksDoneParkedStayOut`,
`futureDueWithoutRankStaysOut`, `futureDueWithRankIsLined`, `emptyInputIsEmpty`, `unionMatchesTheTwoSources`,
`badgeCountAndDueTodayUnchanged`. Dazu bestehende `DueTodayTests` und `StartViewsTests` grün, voller Unit-Lauf im Simulator.

Simulator-Abnahme (Stufe 2): Die Regel hat in diesem Schnitt keine Oberfläche. Belegt wird, dass die App unverändert baut
und startet und die Startseite wie vorher aussieht (Screenshot); der sichtbare Ablauf folgt mit Schnitt 2.
Gerät (Stufe 3): entfällt, „Kein Pfad der Geräteliste berührt.“

## Acceptance Criteria

- **AC-1:** `ViewRules.now(in:now:calendar:).all` enthält genau die Vereinigung aus `dueToday` und `tasks(for: .next)`, jede Aufgabe
  einmal; blockierte, Unter-, erledigte und geparkte Aufgaben fehlen (Unit-Tests `unionMatchesTheTwoSources`,
  `blockedSubtasksDoneParkedStayOut`).
- **AC-2:** Reihenfolge: zuerst überfällig (älteste zuerst), dann heute fällig (früheste Uhrzeit zuerst), dann übrige
  vorgemerkte nach `nextRank`; eine vorgemerkte und fällige Aufgabe steht in der Zeitdruck-Gruppe (Unit-Tests).
- **AC-3:** `ViewRules.dueToday`, `ViewRules.badgeCount` und `ViewRules.tasks(for:)` liefern für dieselbe Eingabe dieselben
  Ergebnisse wie vor der Änderung (Regressionstest `badgeCountAndDueTodayUnchanged`, bestehende `DueTodayTests` und
  `StartViewsTests` grün, Diff berührt die drei Funktionen nicht).
- **AC-4:** #339 ist mit dem PR von Schnitt 1 geschlossen (`Closes #339`), PR #340 geschlossen und nicht gemergt; die Regel steht
  in `docs/project/02-datenmodell-und-ansichten.md`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ViewRules.dueToday`, `ViewRules.tasks(for:)` | module | Quellmengen von „Jetzt“; bleiben unverändert |
| `ViewRules.badgeCount` → `DueNotificationCenter` | module | zählt dieselben Mengen; unverändert |
| Neue Abhängigkeit | – | keine |

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — eine weitere reine Regel in `ViewRules` nach bestehendem Muster; keine Modell-, Schema- oder
  Persistenzänderung. Der Ersatz der #299-Entscheidung im Startbereich ist in der Gesamt-Spec begründet und wird erst mit
  Schnitt 2 sichtbar.

## Definition of Done

- AC-1 bis AC-4 erfüllt; neue Unit-Tests und alle bestehenden Unit-Tests grün (Simulator).
- App baut und startet im Simulator unverändert (Screenshot angesehen).
- PR mit `Closes #339`, Verweis auf #368; PR #340 geschlossen. Board gepflegt. Satz „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-12: Teil-Spec aus der freigegebenen Gesamt-Spec gezogen (Abschnitt Schnitt 1, AC-1 bis AC-4 wörtlich).
