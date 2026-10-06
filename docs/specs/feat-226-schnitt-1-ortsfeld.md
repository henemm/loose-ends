---
entity_id: feat-226-schnitt-1-ortsfeld
type: feature
created: 2026-10-06
updated: 2026-10-06
status: draft
workflow: feat-226-ortserinnerungen
---

# Spec: #226 Schnitt 1 — Ort an der Aufgabe und die Auswahl der überwachten Orte

## Approval

- [x] Approved (Henning, 2026-10-06)

## Purpose

Eine Aufgabe kann einen Ort tragen: Name, Koordinate und Ereignis (ankommen oder verlassen). Eine
reine Funktion wählt aus allen offenen Aufgaben die höchstens 20 Orte aus, die das iPhone überwachen
soll. Schnitt 1 hat **keine Oberfläche und keine Zustellung**. Er legt das Fundament, auf dem
Schnitt 2 (Siri), Schnitt 3 (Detail) und Schnitt 4 (Mitteilung) aufsetzen. Produktentscheidungen:
`docs/specs/feat-226-ortserinnerungen.md`, Antworten F1–F7.

Ein Modell kommt nicht vor. Den Ort setzt nur Henning (Schnitt 3) oder Siri (Schnitt 2). Er wird nie
geraten (Regeln vor dem Modell, F5 → #237).

## Source

- **Neu:** `Shared/Models/TaskPlace.swift` — `struct TaskPlace`
- **Neu:** `Shared/Notifications/PlaceReminders.swift` — `enum PlaceReminders`, `plan(for:)`
- **Geändert:** `Shared/Models/TaskItem.swift` (`place`, `placeSourceRaw`),
  `Shared/Models/Enums.swift` (`RevisedField.place`), `Shared/Services/FieldCodec.swift`,
  `Shared/Services/RevisionService.swift`

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `RepeatRule` als `Codable`-Wert am `TaskItem` | Vorbild | `place` wird genauso gespeichert: ein Wert, über CloudKit abgeglichen, kein eigenes Modell. |
| `FieldCodec.encode(_ rule:)` / `decodeRepeat` | Vorbild | JSON mit sortierten Schlüsseln, damit gleiche Werte gleich codiert sind und eine unveränderte Eingabe keine Revision schreibt. |
| `RevisionService.set`, `.origin(of:on:)`, `revertAll` | Wiederverwendung | Jede Änderung am Ort ist eine Revision. Das Zurücksetzen läuft über die bestehende Schleife über `RevisedField.allCases`. |
| `DueReminders.plan` | Vorbild, unangetastet | Gleiche Form: rein, sortiert, ohne Systemzugriff. Die Fällig-Mitteilung bleibt unverändert. |
| `TaskItem.isOpen` | Wiederverwendung | Legt fest, welche Aufgabe erinnern darf: unverarbeitet, ungeprüft oder aktiv. Geparkt und erledigt erinnern nicht. |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Models/TaskPlace.swift` | NEU | `struct TaskPlace: Codable, Hashable, Sendable` mit `name`, `latitude`, `longitude`, `event` (`enum Event: String { case arrive, depart }`), dazu `static let radius: Double = 150` (F6). Ein `init?(name:latitude:longitude:event:)` lehnt einen leeren Namen (nach dem Trimmen) und Koordinaten außerhalb von ±90 / ±180 ab. |
| `Shared/Models/TaskItem.swift` | MODIFY | `var place: TaskPlace?` und `var placeSourceRaw: String?`, beide optional mit dem Vorgabewert `nil` (CloudKit). |
| `Shared/Models/Enums.swift` | MODIFY | `RevisedField.place`, als letzter Fall angehängt. Die Rohwerte der bestehenden Fälle bleiben unverändert. |
| `Shared/Services/FieldCodec.swift` | MODIFY | `encode(.place)` als JSON mit sortierten Schlüsseln. `apply(.place)` decodiert und setzt `place` und `placeSourceRaw`; ein leerer oder kaputter Wert leert beides. Dazu `encode(_ place:)` und `decodePlace(_:)`. |
| `Shared/Services/RevisionService.swift` | MODIFY | `origin(of: .place)` liest `placeSourceRaw`. |
| `Shared/Notifications/PlaceReminders.swift` | NEU | Reine Planung, siehe unten. |
| `LooseEnds/Views/FieldFormatting.swift` | MODIFY | `label(.place)` = „Place“ / „Ort“. `value(.place)` = Name des Orts. Nötig, weil die `switch`-Anweisungen über `RevisedField` vollständig sein müssen; sonst bleibt die Oberfläche unberührt. |
| `LooseEnds/Views/FieldEditorView.swift` | MODIFY | `case .place` kommt zu `EmptyView()`. Den Editor baut erst Schnitt 3. |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | „Place“ → „Ort“. |
| `LooseEndsTests/TaskPlaceTests.swift` | NEU | Unit-Tests zu `TaskPlace` und Codec |
| `LooseEndsTests/PlaceRemindersTests.swift` | NEU | Unit-Tests zur Planung |

Erwartet: rund 120 Zeilen Produktcode und 150 Zeilen Tests.

**Kein Pfad der Geräteliste berührt:** `Shared/Persistence/`, `LooseEnds/Notifications/`,
`project.yml`, `Info.plist` und die Entitlements bleiben unverändert. Die neuen Felder sind optional
und am bestehenden Modell `TaskItem`. Das Schema in `ModelContainerFactory` ändert sich nicht.

**Nicht in Schnitt 1:**
- `SavedPlace` (Zuhause, Arbeit): Es ist ein neues Modell und muss in
  `Shared/Persistence/ModelContainerFactory` eingetragen werden, also gilt die Gerätestufe. Es kommt
  mit Schnitt 3, der sie ohnehin braucht.
- Oberfläche, Berechtigung, Zustellung, Siri.

## Implementation Details

### `PlaceReminders.plan`

```swift
enum PlaceReminders {
    static let limit = 20
    static let identifierPrefix = "place_"

    struct Reminder: Equatable, Sendable {
        let taskID: UUID
        let title: String
        let place: TaskPlace
        var identifier: String { identifierPrefix + taskID.uuidString }
    }

    struct Plan: Equatable, Sendable {
        let watched: [Reminder]      // höchstens `limit`, in Rangfolge
        let unwatched: [UUID]        // offen, mit Ort, aber über der Grenze
    }

    static func plan(for tasks: [TaskItem]) -> Plan
}
```

**Auswahl:** jede Aufgabe mit `isOpen` und `place != nil`. Geparkte und erledigte Aufgaben fallen
heraus. Endet die Überwachung (Abhaken, Parken), plant Schnitt 4 neu, und die Aufgabe fehlt in der
neuen Liste.

**Rangfolge** (Verhalten 4 der Vorbereitung):
1. Aufgaben in „Als nächstes“ (`nextRank != nil`), nach `nextRank` aufsteigend
2. dann Aufgaben mit Fälligkeit, nach `dueDate` aufsteigend
3. dann alle übrigen, die neuesten zuerst (`capturedAt` absteigend)
4. Bei Gleichstand entscheidet die `id`, damit jeder Lauf dieselbe Liste liefert.

Die ersten 20 kommen in `watched`, die übrigen in `unwatched`. Schnitt 3 zeigt für diese den Hinweis
„Wird gerade nicht überwacht“. Nichts fällt still weg.

**Wiederholung (F3):** keine eigene Logik. Eine wiederkehrende Aufgabe ist nach dem Abhaken wieder
offen und taucht deshalb im nächsten Plan wieder auf. `repeats: false` setzt Schnitt 4 bei der
Zustellung.

### Codec

`{"event":"arrive","latitude":53.55,"longitude":9.93,"name":"Bauhaus, Hamburg-Altona"}`. Die Schlüssel
sind sortiert, damit derselbe Ort immer gleich codiert ist und `RevisionService.set` bei einer
unveränderten Eingabe nichts schreibt.

## Test Plan

### Automated Tests (TDD RED zuerst)

`TaskPlaceTests`:
- Ein gültiger Ort wird angelegt. Ein leerer oder nur aus Leerzeichen bestehender Name und Koordinaten
  außerhalb von ±90 / ±180 ergeben `nil`.
- Codec hin und zurück liefert denselben Ort; derselbe Ort ergibt zweimal denselben Text.
- `apply` mit kaputtem oder leerem Text leert `place` und `placeSourceRaw`.
- `RevisionService.set(.place)` schreibt eine Revision mit Autor `.user`; derselbe Ort ein zweites Mal
  schreibt nichts; `origin(of: .place)` ist `.user`.
- `revertAll` stellt einen Ort wieder her, den eine Regel gesetzt hat (Revision mit Autor `.rule`).

`PlaceRemindersTests`:
- Ohne Ort, geparkt oder erledigt: kein Eintrag. Unverarbeitet, ungeprüft oder aktiv mit Ort: ein
  Eintrag mit Titel und Ort.
- Rangfolge: „Als nächstes“ vor Fälligkeit vor Rest; innerhalb jeder Gruppe wie oben; Gleichstand nach
  `id`.
- 25 offene Aufgaben mit Ort: genau 20 in `watched`, die 5 mit dem niedrigsten Rang in `unwatched`.
- Eine wiederkehrende Aufgabe ist nach `TaskActions.complete` wieder im Plan.

## Acceptance Criteria

- **AC-1 Ort gültig oder gar nicht:** Given ein leerer Name oder eine ungültige Koordinate / When ein
  `TaskPlace` angelegt wird / Then entsteht keiner.
- **AC-2 Ort als Revision:** Given eine Aufgabe ohne Ort / When `RevisionService.set(.place, …)` mit
  einem codierten Ort aufgerufen wird / Then trägt die Aufgabe den Ort, `placeSourceRaw` ist `user`,
  und es gibt genau eine Revision mit `field == .place`. Die gleiche Eingabe noch einmal schreibt
  nichts.
- **AC-3 Nur offene Aufgaben erinnern:** Given Aufgaben mit Ort in jedem Status / When `plan` läuft /
  Then sind nur unverarbeitete, ungeprüfte und aktive enthalten.
- **AC-4 Höchstens 20, keine verschwindet still:** Given 25 offene Aufgaben mit Ort / When `plan` läuft
  / Then sind 20 in `watched` nach der Rangfolge oben und die anderen 5 in `unwatched`.
- **AC-5 Stabil:** Given dieselben Aufgaben / When `plan` zweimal läuft / Then sind beide Ergebnisse
  gleich.
- **AC-6 Regression:** Given `./scripts/sim.sh unit` / Then bleiben alle bestehenden Tests grün,
  `DueReminders` verhält sich unverändert, und der UI-Smoke-Lauf der CI bleibt grün.

## Risiken

- **CloudKit-Schema:** Zwei optionale Felder am `TaskItem`. Das ist additiv, ältere Stände ignorieren
  sie. Die Produktion ist noch nicht ausgerollt (#175).
- **Codable am Modell:** `place` folgt dem erprobten Muster von `repeatRule`. Ändert sich später die
  Form, gilt dieselbe Vorsicht wie dort: nur optionale Felder ergänzen.

## Alternativen (verworfen)

- **Fünf einzelne Felder** (`placeName`, `placeLatitude`, …), wie in der Vorbereitung vorgeschlagen:
  Sie lassen halbe Orte zu (Name ohne Koordinate) und brauchen fünf Spalten im Codec. Ein `TaskPlace`
  ist entweder ganz da oder gar nicht.
- **Radius speichern:** Er ist fest (F6), und Siri liefert keinen. Er wäre eine Spalte ohne Nutzen.
  Kommt später ein einstellbarer Radius, wird er als optionales Feld ergänzt.
- **Planung erst mit der Zustellung (Schnitt 4):** Dann wäre die Rangfolge nur auf dem Gerät
  prüfbar. Rein und in der Cloud getestet ist sie billiger und sicherer.

## Definition of Done

- Alle Tests oben grün in der CI (Unit, Build, UI-Smoke).
- `docs/project/04-stand.md` nennt Schnitt 1 als gebaut.
- Abschlussbericht: „Kein Pfad der Geräteliste berührt.“
