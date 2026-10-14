---
entity_id: feat-414-offen-am-tagesende
type: feature
created: 2026-10-14
updated: 2026-10-14
status: approved
workflow: feat-414-offen-am-tagesende
---

# Spec: #414 Offen am Tagesende

## Approval

- [x] Approved (Henning, 2026-10-14): „Alle drei als Einstellung, C als Vorgabe“ und „grau, rot nur mit Uhrzeit“.
  Konzept mit Recherche und Skizzen: https://claude.ai/artifact/QtiUt4gdfDLRwDdwhbSdPT, Entscheidung im Issue.

## Purpose

Was mit einer Aufgabe passiert, deren Fälligkeitstag vorbei ist und die offen blieb. Zwei Entscheidungen:

1. **Grau statt Rot.** Nach ihrem Tag bleibt nur eine Fälligkeit mit Uhrzeit rot. Ohne Uhrzeit steht sie grau als
   „Seit gestern“ bzw. „Seit N Tagen“ (ADR-14: Rot heißt Zeitdruck; ein gesprochener Vorsatz ist keiner).
2. **Einstellung „Noch offen am Tagesende“** unter Mitteilungen: Still weitertragen · Morgens erinnern (Vorgabe) ·
   Abends durchsehen.

**Rein regelbasiert.** Datum, Uhrzeit, Kalendertage; kein Modell.

## Schnitte

| Schnitt | Inhalt | Geräteliste |
|---|---|---|
| 1 | `ViewRules.dueState`, Zeile grau „Seit gestern“ / „Seit N Tagen“ | nicht berührt |
| 2 | Einstellung (iCloud-Schlüsselwertspeicher wie die Erinnerungszeit), „Morgens erinnern“: eine gebündelte Mitteilung „Von gestern noch offen: N“ zur Erinnerungszeit, Aktionen „Heute nochmal“ und „Ansehen“, höchstens 3 Morgen je Aufgabe; „Still weitertragen“: nach 7 Tagen aus „Jetzt“ und Zahl am App-Symbol | `LooseEnds/Notifications/` → Stufe 3 über TestFlight |
| 3 | „Abends durchsehen“: Mitteilung zur eigenen Abendzeit (Vorgabe 20:00) „N lose Enden von heute“, Aktionen „Alle auf morgen“ und „Ansehen“, Durchsicht: Morgen, Später, Parken, Erledigt | `LooseEnds/Notifications/` → Stufe 3 über TestFlight |

Schnitt 2 und 3 bekommen je eine Teil-Spec, bevor sie gebaut werden. ADR-16 wird mit Schnitt 2 ergänzt.

## Schnitt 1: Grau statt Rot

### Source

| Datei | Änderung |
|---|---|
| `Shared/Models/ViewRules.swift` | `enum DueState` (`later`, `today`, `missed`, `carried(days:)`), `static func dueState(of:now:calendar:)` |
| `LooseEnds/Views/TaskRow.swift` | Fälligkeitsmerkmal aus `dueState`: rot bei `today`/`missed`, bei `carried` grauer Text statt Datum |
| `LooseEnds/Resources/Localizable.xcstrings` | „Since yesterday“ / „Seit gestern“, „Since %lld days“ / „Seit %lld Tagen“ |
| `LooseEndsTests/DueStateTests.swift` | Unit-Tests |
| `docs/project/00`, `02`, `03` | ADR-14 nachgeschärft, Regel, Zustandstabelle |

### Acceptance Criteria

- **AC-1:** Offene Aufgabe, heute fällig (mit oder ohne Uhrzeit, auch Uhrzeit vorbei) → `today`, Merkmal rot mit Datum.
- **AC-2:** Offene Aufgabe ohne Uhrzeit, Tag vorbei → `carried(days:)` in Kalendertagen (gestern = 1), Merkmal grau
  „Seit gestern“ bzw. „Seit N Tagen“.
- **AC-3:** Offene Aufgabe mit Uhrzeit, Tag vorbei → `missed`, Merkmal rot mit Datum und Uhrzeit.
- **AC-4:** Zukunft, kein Datum, erledigt, geparkt → `later`, nicht rot.
- **AC-5:** „Jetzt“, „Fällig“ und die Zahl am App-Symbol bleiben unverändert (eine weitergetragene Aufgabe zählt weiter
  als überfällig).

### Abnahme

Stufe 1: `DueStateTests` und der volle Unit-Lauf in CI. Stufe 2: Simulator, Zeile einer Aufgabe mit Fälligkeit gestern
ohne Uhrzeit zeigt grau „Seit gestern“. Stufe 3: Kein Pfad der Geräteliste berührt.
