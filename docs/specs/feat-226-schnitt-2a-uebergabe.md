---
entity_id: feat-226-schnitt-2a-uebergabe
type: feature
created: 2026-10-07
updated: 2026-10-07
status: draft
workflow: feat-226-zustellung
---

# Spec: #226 Schnitt 2a — Planung der Übergabe an das System (rein, ohne Systemanschluss)

## Approval

- [ ] Approved (Henning)

## Purpose

Schnitt 1 hat entschieden, **welche** höchstens 20 Orte das iPhone überwacht (`PlaceReminders.plan`).
Schnitt 2a entscheidet, **was dem System davon übergeben, ersetzt oder zurückgenommen wird**, damit
dieselbe Aufgabe nicht ein zweites Mal erinnert, nur weil sie nach einer Änderung neu geplant wird.

Der Kern: Das System meldet **nicht** zurück, ob eine Ortsmitteilung zugestellt wurde.
`getDeliveredNotifications()` liefert sie absichtlich nicht (Apple DTS: Datenschutz, Forum 777251). Eine
Zustellmarke an der Aufgabe lässt sich deshalb nicht herstellen. Die App weiß nur, **was sie dem System
übergeben hat**. Schnitt 2a führt dafür eine **Übergabe-Merkliste je Gerät** ein (Aufgabe plus
Fingerabdruck) und eine reine Funktion `PlaceDelivery.diff`, die aus Plan, Merkliste, offenen Anfragen
und Freigabe nur den **Unterschied** berechnet.

Ohne Modell: Es ist keines im Spiel, der Regelweg ist der einzige Weg (Regeln vor dem Modell).

**Ehrlich zum Nutzen:** Schnitt 2a ändert **nichts Sichtbares**. Es gibt keine Oberfläche, keine
Mitteilung, keine Berechtigung. Der Nutzen („keine doppelte Erinnerung“) entsteht erst, wenn
Schnitt 2b die Funktion ans System anschließt. Ein echtes Durchspielen (App starten, Ablauf benutzen)
gibt es für 2a nur als Unit-Nachweis, weil nichts an das System angeschlossen ist.

**Zuschnitt:** Die Analyse (`docs/context/feat-226-zustellung.md`) schätzt die Zustellung auf 5–6 Dateien
und +330 Zeilen, das sprengt die Grenzen (4–5 Dateien, ±250 Zeilen). Sie wird innerhalb von #226 in zwei
Schnitte geteilt, ein Ziel, eine DoD, zwei PRs, kein neues Ticket:

- **2a (diese Spec):** reine Planung der Übergabe, 2 Dateien.
- **2b (eigene Spec, ausdrücklich NICHT Teil):** Systemanschluss (`PlaceNotificationCenter` mit
  `UNLocationNotificationTrigger`, Kategorien, `project.yml`/`NSLocationWhenInUseUsageDescription`,
  Freigabe, Gerätenachweis, Debug-Starthilfe). Siehe „Weiter mit 2b“.

## Source

- **Neu:** `Shared/Notifications/PlaceDelivery.swift` — `enum PlaceDelivery` mit `Handover`, `Entry`,
  `Changes` und `diff`
- **Neu:** `LooseEndsTests/PlaceDeliveryTests.swift`
- **Unverändert, nur gelesen:** `Shared/Notifications/PlaceReminders.swift`
  (`Plan`, `Reminder`, `identifier = place_<uuid>`), `Shared/Models/TaskPlace.swift`,
  `Shared/Models/TaskItem.swift` (`repeatRule`, `dueDate`), `Shared/Services/TaskActions.swift`
  (`complete` rückt `dueDate` bei Wiederholung weiter)

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `PlaceReminders.plan` / `Plan.watched` | Eingabe | Was überwacht werden soll, in Rangfolge, höchstens 20. `Plan.unwatched` nimmt `diff` nicht an (Protokollierung per `Logger` ist 2b). |
| `PlaceReminders.Reminder.identifier` | Wiederverwendung, unverändert | Der Bezeichner `place_<uuid>` verbindet Plan, Merkliste und offene Anfrage. |
| `TaskItem.repeatRule`, `dueDate` | Eingabe (über die Aufgaben) | Bei wiederkehrenden Aufgaben ist das Fälligkeitsdatum der Zyklus im Fingerabdruck. `PlaceReminders.Reminder` trägt es nicht; `diff` liest es über die Aufgaben-ID aus den Aufgaben, damit `PlaceReminders.swift` unangetastet bleibt. |
| `TaskActions.complete` | Vorbild, unangetastet | Rückt `dueDate` einer wiederkehrenden Aufgabe weiter. Daraus ergibt sich der neue Fingerabdruck von selbst (F3). |
| `DueReminders.plan` | Vorbild | Gleiche Form: rein, sortiert, ohne Systemzugriff. |

## Verhalten / Regeln

### Eingabe und Ausgabe

```swift
enum PlaceDelivery {
    /// Was die App diesem Gerät übergeben hat. Wertetyp; gespeichert wird er erst in 2b.
    struct Handover: Codable, Equatable, Sendable {
        var entries: [Entry]            // sortiert nach taskID.uuidString, je Aufgabe höchstens einer
    }

    struct Entry: Codable, Equatable, Hashable, Sendable {
        let taskID: UUID
        let fingerprint: String
        let title: String               // der übergebene Titel, um eine Titeländerung zu erkennen
    }

    struct Changes: Equatable, Sendable {
        let add: [PlaceReminders.Reminder]       // neu anlegen, sortiert nach identifier
        let remove: [String]                     // Bezeichner entfernen, sortiert, ohne Doppelte
        let updateContent: [PlaceReminders.Reminder] // nur Titel ersetzen, sortiert nach identifier
        let handover: Handover                   // die neue Merkliste
    }

    static func fingerprint(of reminder: PlaceReminders.Reminder, in task: TaskItem?) -> String

    static func diff(
        plan: PlaceReminders.Plan,
        tasks: [TaskItem],
        handover: Handover,
        pending: Set<String>,           // Bezeichner der noch offenen place_-Anfragen im System
        authorized: Bool                // Freigabe „Beim Verwenden der App“ liegt vor
    ) -> Changes
}
```

`Handover` ist `Codable` mit festem, deterministischem Ergebnis (sortierte Einträge, Kodierung mit
sortierten Schlüsseln), damit 2b ihn in `UserDefaults` ablegen kann und ein unveränderter Stand
byte-gleich bleibt.

### Fingerabdruck

Eine Zeichenkette aus festen Feldern, der Name steht **zuletzt**, damit kein Trennzeichen im Namen zu
Kollisionen führt:

`<ereignis>|<breite>|<länge>|<zyklus>|<name>`

- `ereignis`: `arrive` oder `depart`.
- `breite`, `länge`: auf **5 Nachkommastellen** gerundet (rund 1 m), formatiert mit `String(format:
  "%.5f", …)` in der Gebietsschema-unabhängigen Form (Punkt als Trenner). Ein Ort, der sich nur jenseits
  der fünften Stelle unterscheidet, ist derselbe Ort. Der Radius ist fest (F6) und gehört nicht hinein.
- `zyklus`: bei `repeatRule != nil` und gesetztem `dueDate` die ganze Sekunde des Fälligkeitsdatums
  (`Int(timeIntervalSince1970.rounded())`), sonst `-`. Bei nicht wiederkehrenden Aufgaben ändert eine
  Änderung des Fälligkeitsdatums den Fingerabdruck **nicht**.
- `name`: der Name des Orts, wie ihn `TaskPlace` hält (schon getrimmt).

### Regeln von `diff`

Für jeden Eintrag `r` in `plan.watched` mit Merklisten-Eintrag `e` (gleiche Aufgabe) und
`offen = pending.contains(r.identifier)`:

1. **Neu:** Kein `e`, nicht offen → `add`, neuer Eintrag.
2. **Schon ausgelöst:** `e` mit gleichem Fingerabdruck, nicht offen → **nichts**. Der Eintrag bleibt.
   Die Anfrage ist ausgelöst oder zugestellt (das System sagt es nicht), also wird sie nicht erneut
   angelegt. Das ist der Schutz gegen die doppelte Erinnerung.
3. **Unverändert und aktiv:** `e` mit gleichem Fingerabdruck und gleichem Titel, offen → nichts.
   Nur Unterschiede werden nachgezogen, nie alles neu.
4. **Ort oder Ereignis geändert:** `e` mit anderem Fingerabdruck → war sie offen, kommt ihr Bezeichner in
   `remove`; in jedem Fall `add` und der Eintrag wird ersetzt. Die Aufgabe ist wieder scharf. Weil der
   Bezeichner derselbe bleibt, muss 2b erst entfernen, dann anlegen.
5. **Wiederkehrend:** Rückt `dueDate` nach `TaskActions.complete` weiter, ändert sich der Zyklus, also der
   Fingerabdruck, also Regel 4: wieder scharf für den nächsten Zyklus (F3). Änderungen an `TaskActions`
   sind nicht nötig.
6. **Aus dem Plan gefallen:** Ein Eintrag der Merkliste, dessen Aufgabe nicht in `plan.watched` steht
   (erledigt, geparkt, Ort entfernt, über Rang 20 hinaus) → der Eintrag wird gelöscht, und ein offener
   Bezeichner kommt in `remove`. Kommt die Aufgabe zurück, gilt Regel 1 (Master-Spec Punkt 2:
   „wiederhergestellt: beginnt wieder“). **Festlegung für den Randfall:** Fällt eine Aufgabe über Rang 20
   hinaus und kommt zurück, erinnert sie erneut, weil der Rangverlust den Eintrag gelöscht hat. Das ist
   bewusst so: eine Aufgabe, die das System zwischenzeitlich nicht überwachte, soll nicht still für immer
   stumm bleiben.
7. **Titeländerung:** `e` mit gleichem Fingerabdruck, offen, anderer Titel → `updateContent`, Eintrag mit
   neuem Titel. Nicht offen → nichts, der Eintrag bleibt unverändert (ein Titelwechsel löst nie neu aus).
8. **Fehlende Freigabe (`authorized == false`):** Es wird **nichts angelegt und nichts vermerkt**: `add`
   und `updateContent` sind leer, kein Eintrag wird hinzugefügt oder verändert. Das ist nötig, damit die
   Aufgabe nach der Freigabe ankommt; ein Vermerk ohne Übergabe würde sie für immer stumm machen.
   Rücknahmen laufen weiter (Regel 6 und 10, samt Löschen der Einträge ausgefallener Aufgaben), weil
   das Entfernen einer Anfrage keine Freigabe braucht und eine erledigte Aufgabe nicht erinnern darf.
   Die Merkliste der übrigen Aufgaben und offene Anfragen bleiben unangetastet.
9. **Bezeichner:** `PlaceReminders.Reminder.identifier` (`place_<uuid>`) bleibt, `PlaceReminders.swift`
   wird nicht geändert.
10. **Verwaist:** Jede offene Anfrage mit Präfix `place_` ohne Eintrag in `plan.watched` → `remove`, auch
    ohne Merklisten-Eintrag (Neuinstallation, Merkliste leer). Bezeichner ohne dieses Präfix (z. B. `due_`)
    fasst `diff` nie an.
11. **Neuinstallation, Merkliste leer:** Offene Anfrage, aber kein Eintrag, Aufgabe im Plan → der Eintrag
    wird aufgenommen (Fingerabdruck und Titel aus dem Plan), **kein** `add`, sonst entstünde eine
    Doppelanlage. Fehlt beides → Regel 1. Gilt nur bei `authorized == true` (sonst Regel 8).
12. **Determinismus:** Gleiche Eingabe, gleiche Ausgabe. Alle Listen sind sortiert (`add` und
    `updateContent` nach Bezeichner, `remove` aufsteigend ohne Doppelte, Einträge nach `taskID`); die
    Reihenfolge der Eingabe-Arrays beeinflusst das Ergebnis nicht.
13. **`Plan.unwatched`:** nimmt `diff` nicht an. Aufgaben über der Grenze sind aus Sicht der Übergabe
    „nicht im Plan“ (Regel 6). Das Benennen per `Logger` ist 2b.

### Alternativen (bewusst benannt)

| | Weg | Dafür | Dagegen |
|---|---|---|---|
| **A (diese Spec)** | Merkliste je Gerät plus Unterschied (`diff`) | Kein Schema, keine neue Berechtigung, rein testbar. Passt zu „jedes Gerät plant selbst“ (Master-Spec 6) | Neuinstallation: Merkliste leer, wird über Regel 10/11 aufgefangen |
| B | Zustellmarke als Feld am `TaskItem` (CloudKit) | Reist zwischen Geräten | **Nicht herstellbar:** kein Auslösesignal ([Forum 777251](https://developer.apple.com/forums/thread/777251)); Ignorieren der Mitteilung bliebe unsichtbar. Dazu Schemaänderung |
| C | `CLMonitor` mit „Immer“-Berechtigung, die App stellt selbst Mitteilungen zu (Apples Rat im [Forum 790110](https://developer.apple.com/forums/thread/790110)) | Die App kennt jeden Auslöser, eine Marke wäre möglich | **Kippt F1 / ADR-Antwort 14** („Beim Verwenden der App“), braucht „Immer“ und Hintergrundmodus Standort, schwerere Store-Prüfung, mehr Code. Nur sinnvoll, wenn A im Gerätelauf (2b) versagt |
| D | Keine Merkliste, nur bei Plan-Änderung neu anlegen | Kein Speicher | Jede Rangänderung ist eine Plan-Änderung; ohne Gedächtnis kein sicheres „schon erinnert“, Befund 1 bleibt offen |

Quellen: [Forum 777251](https://developer.apple.com/forums/thread/777251),
[UNLocationNotificationTrigger](https://developer.apple.com/documentation/usernotifications/unlocationnotificationtrigger),
[Forum 790110](https://developer.apple.com/forums/thread/790110).

**Offen aus der Recherche:** Ob ein Anlegen *innerhalb* des Bereichs sofort auslöst, ist nicht belegt. Es
wird in 2b gemessen. Es beeinflusst nur 2b, nicht diese Spec: 2a legt fest, **wann** angelegt wird, nicht
was das System danach tut.

### Festlegungen aus der Analyse

- **iPad und iPhone erinnern beide**, jedes Gerät plant selbst (Master-Spec 6). Die Merkliste gehört dem
  Gerät, nicht dem Konto. Der Mac übergibt nichts (2b). Vorschlag der Analyse, hier festgehalten.
- **Ort wird beim Neuanlegen mit anderem Namen als anderer Ort gewertet** (Name ist Teil des
  Fingerabdrucks): Wer nur den Anzeigenamen ändert, bekommt die Erinnerung erneut. Das ist harmlos und
  einfacher als zwei Fingerabdrücke.

## Akzeptanzkriterien

Jedes Kriterium ist ein Unit-Test mit echten `TaskItem` und `PlaceReminders.plan` als Eingabe.

1. **Neue Ortsaufgabe wird übergeben:** Given eine aktive Aufgabe mit Ort, leere Merkliste, keine offene
   Anfrage, Freigabe da / When `diff` läuft / Then enthält `add` genau diese Aufgabe, und die neue Merkliste
   hat einen Eintrag mit Fingerabdruck und Titel.
2. **Zweite Änderung erzeugt keine zweite Erinnerung:** Given derselbe Stand wie in 1, die Anfrage ist
   inzwischen nicht mehr offen (ausgelöst), der Eintrag steht in der Merkliste / When die Aufgabe geändert
   wurde (z. B. eine Notiz) und `diff` läuft / Then ist `add` leer, und der Eintrag bleibt.
3. **Offene Anfrage bleibt in Ruhe:** Given Eintrag mit gleichem Fingerabdruck und gleichem Titel, Anfrage
   offen / When `diff` läuft / Then sind `add`, `remove` und `updateContent` leer und die Merkliste
   unverändert.
4. **Anderer Ort ersetzt die Anfrage:** Given offene Anfrage und Eintrag / When Koordinate oder Ereignis
   geändert werden (und einmal nur der Name) / Then steht der Bezeichner in `remove` **und** die Aufgabe
   in `add`, und der Eintrag trägt den neuen Fingerabdruck. War die Anfrage nicht mehr offen, entsteht
   nur `add`.
5. **Wiederkehrende Aufgabe ist nach dem Abhaken wieder scharf:** Given wiederkehrende Aufgabe (wöchentlich)
   mit Ort, ausgelöste Anfrage, Eintrag / When `TaskActions.complete` das `dueDate` weitergerückt hat /
   Then enthält `add` die Aufgabe. Given eine **nicht** wiederkehrende Aufgabe, deren `dueDate` sich ändert
   / Then bleibt der Fingerabdruck gleich und `add` ist leer.
6. **Ausgefallene Aufgabe wird zurückgenommen, zurückgekehrte erinnert wieder:** Given Eintrag und offene
   Anfrage / When die Aufgabe erledigt, geparkt oder ihr Ort entfernt wird, oder sie bei 21 offenen
   Aufgaben auf Rang 21 fällt / Then steht ihr Bezeichner in `remove` (nur wenn offen) und der Eintrag
   fehlt in der neuen Merkliste. When sie wiederhergestellt wird / Then steht sie wieder in `add`.
7. **Titeländerung ersetzt nur den Inhalt:** Given Eintrag, Anfrage offen / When der Titel sich ändert /
   Then steht die Aufgabe in `updateContent`, `add` und `remove` sind leer, der Eintrag trägt den neuen
   Titel. Given die Anfrage ist nicht mehr offen / Then sind alle drei Listen leer und der Eintrag bleibt
   unverändert.
8. **Ohne Freigabe kommt nichts an, geht nichts verloren:** Given `authorized == false`, Aufgabe mit Ort,
   keine Anfrage / When `diff` läuft / Then sind `add` und `updateContent` leer und kein Eintrag wurde
   hinzugefügt. When danach `authorized == true` / Then steht die Aufgabe in `add`. Given `authorized ==
   false` und eine erledigte Aufgabe mit offener Anfrage / Then steht ihr Bezeichner trotzdem in `remove`.
9. **Bezeichner bleibt `place_<uuid>`:** Given eine Aufgabe im Plan / When `diff` läuft / Then entspricht
   jeder Bezeichner in `add` und `remove` `"place_" + id.uuidString`, und `git diff` zeigt keine Änderung
   an `Shared/Notifications/PlaceReminders.swift`.
10. **Verwaiste Anfragen verschwinden:** Given eine offene Anfrage `place_<uuid>` ohne Aufgabe im Plan und
    ohne Eintrag, und eine offene Anfrage `due_<uuid>` / When `diff` läuft / Then steht nur die
    `place_`-Anfrage in `remove`.
11. **Neuinstallation erzeugt keine Doppelanlage:** Given Merkliste leer, Aufgabe im Plan, ihre Anfrage ist
    offen / When `diff` läuft / Then ist `add` leer und die neue Merkliste hat den Eintrag. Given dieselbe
    Aufgabe ohne offene Anfrage / Then steht sie in `add`.
12. **Stabil:** Given dieselbe Eingabe / When `diff` zweimal läuft, und einmal mit umgekehrter
    Reihenfolge der Aufgaben / Then sind alle Ergebnisse gleich (alle Listen sortiert), und der
    `Handover` kodiert zu byte-gleichem JSON.
13. **Fingerabdruck ohne Kollision:** Given zwei Orte, die sich in der sechsten Nachkommastelle
    unterscheiden / Then gleicher Fingerabdruck; Given ein Name mit `|` darin / Then bleibt der
    Fingerabdruck von einem Ort mit anderen Feldern verschieden.
14. **Regression:** Given `./scripts/sim.sh unit` / Then bleiben alle bestehenden Tests grün
    (`PlaceReminders`, `DueReminders` unverändert).

## Tests

`LooseEndsTests/PlaceDeliveryTests.swift`, Swift Testing wie `PlaceRemindersTests`, TDD RED zuerst. Die
Eingabe sind echte `TaskItem` (mit `TestStore`; der `ModelContainer` bleibt im Test am Leben, siehe
CLAUDE.md) und `PlaceReminders.plan(for:)`; die offenen Anfragen sind `Set<String>` aus
`reminder.identifier`.

- Je Kriterium 1–13 mindestens ein Test, die Namen nennen die Wirkung („zweite Änderung erzeugt keine
  zweite Erinnerung“), nicht „Funktion existiert“.
- Ein Test, der zwei Aufrufe mit gleicher Eingabe vergleicht (Kriterium 12), samt umgekehrter
  Aufgabenreihenfolge.
- Kriterium 5 benutzt `TaskActions.complete` (wiederkehrend, `RepeatRule(frequency: .weekly)`), nicht ein
  von Hand verschobenes Datum, damit der echte Weg geprüft wird.
- Kriterium 6 mit 21 Aufgaben: die 21. fällt aus `watched`, ihr Eintrag und die offene Anfrage fallen mit.
- Kriterium 14 braucht keinen eigenen Test: Der volle Lauf `./scripts/sim.sh unit` ist der Beleg, dass
  `PlaceRemindersTests` und `DueRemindersTests` unverändert grün bleiben.
- Der Test für Kriterium 9 vergleicht die Bezeichner im Ergebnis mit dem Präfix; die Unverändertheit von
  `PlaceReminders.swift` belegt der Diff im PR.

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Notifications/PlaceDelivery.swift` | NEU | `Handover`, `Entry`, `Changes`, `fingerprint`, `diff`. Rein, nur `import Foundation`. |
| `LooseEndsTests/PlaceDeliveryTests.swift` | NEU | Unit-Tests zu Kriterium 1–13. |

Erwartet: rund 150 Zeilen insgesamt (rund 80 Produktcode, rund 70 Tests je nach Zählung), 2 Dateien, keine
Funktion über 50 Zeilen (`diff` wird dafür in kleine private Schritte zerlegt: Auswahl der Neuen, der
Ersetzten, der Verwaisten).

**Keine Änderung** an `project.yml`, `Info.plist`, `TaskItem`, `TaskActions`, `PlaceReminders`,
`DueNotificationCenter`, `ModelContainerFactory`. Kein neues CloudKit-Feld, kein neues Schema. Das Projekt
ist generiert: nach den neuen Dateien muss `./scripts/sim.sh generate` laufen.

**Kein Pfad der Geräteliste berührt:** `Shared/Notifications/` steht nicht auf der Liste. Der
Abschlussbericht darf sagen: „Kein Pfad der Geräteliste berührt.“

**Nicht in Schnitt 2a (Schnitt 2b und später):**
- Systemanschluss, Anfragen, Kategorien, Freigabe, Speicherung der Merkliste in `UserDefaults`.
- Oberfläche, Hinweise (Schnitt 3), Siri-Abbildung (#25).
- Das Protokollieren von `Plan.unwatched`.

## Weiter mit 2b

Nur als Verweis, nicht als Scope dieser Spec. 2b braucht:

- `PlaceNotificationCenter` in `LooseEnds/Notifications/`, nur unter `#if os(iOS)`; der Mac ist ein
  sauberer Nicht-Pfad.
- Anfragen mit `UNLocationNotificationTrigger` (150 m, Ereignis aus dem Ort), Kategorie `PLACE` mit
  `DUE_DONE` und `DUE_NEXT`; beide Kategorien **zusammen** setzen, weil `setNotificationCategories`
  alles ersetzt.
- Ablage des `Handover` in `UserDefaults`; Abgleich nach jedem Speichern und beim Start mit
  `getPendingNotificationRequests`; bei Änderung des Bezeichners erst entfernen, dann anlegen.
- `requestWhenInUseAuthorization()` beim ersten nicht leeren Plan; der Status ist abfragbar (für den
  grauen Hinweis in Schnitt 3); `NSLocationWhenInUseUsageDescription` in `project.yml`.
- Unter Tests und `--ui-testing` still.
- Messung: löst ein Anlegen innerhalb des Bereichs sofort aus?
- `Plan.unwatched` per `Logger` benennen.
- Debug-Starthilfe (Startargument, nur Debug- und Prüfbauten), die der ersten offenen Aufgabe einen Ort
  setzt, weil es bis Schnitt 3 keine Bedienung dafür gibt.
- Gerätestufe (`project.yml`, `LooseEnds/Notifications/` stehen auf der Liste).

## Erwartetes Verhalten

Für Henning ändert sich nach 2a nichts. Die App sieht gleich aus und verhält sich gleich. Für das
Projekt: Sobald 2b die Funktion anschließt, erinnert eine Aufgabe mit Ort einmal je Zyklus, nicht nach
jedem Speichern erneut, und eine abgehakte wiederkehrende Aufgabe erinnert für den nächsten Zyklus
wieder. Bis dahin ist 2a nur durch Unit-Tests belegt, und das wird im Abschlussbericht so gesagt.

## Known Limitations

- **Nicht zwischen Geräten:** Die Merkliste gehört dem Gerät. Ein zweites Gerät weiß nichts davon, jedes
  plant selbst (iPad und iPhone erinnern beide).
- **Ausgelöst oder ignoriert ist nicht unterscheidbar:** Das System sagt es nicht. Die Funktion nimmt
  an, dass eine nicht mehr offene Anfrage mit gleichem Fingerabdruck ausgelöst hat. Hat das System sie
  aus anderem Grund verloren (z. B. Systembereinigung), wird sie erst bei Ort-, Ereignis- oder
  Zykluswechsel wieder angelegt. Ob das in der Praxis vorkommt, zeigt 2b.
- **Randfall Rang 20:** Verlässt eine Aufgabe die 20 überwachten Orte und kommt zurück, erinnert sie
  erneut (Regel 6, bewusste Festlegung).
- **Namensänderung:** Ein geänderter Ortsname gilt als anderer Ort und macht die Aufgabe wieder scharf.
- **Anlegen innerhalb des Bereichs:** Das Systemverhalten ist nicht belegt (Messung in 2b).
- **Kein Nachweis am System:** 2a wird nur per Unit-Test belegt, es gibt keinen Durchlauf in App oder
  Simulator.

## Risiken

- **Falsche Annahme „nicht offen heißt ausgelöst“:** Siehe Known Limitations. Die Alternative C
  (`CLMonitor`, „Immer“) ist die Rückfallebene, falls der Gerätelauf in 2b zeigt, dass A nicht trägt. Sie
  kippt F1 / ADR-Antwort 14 und braucht dann eine eigene Entscheidung.
- **Kodierung des Handover:** Wird `Handover` später erweitert, nur optionale Felder ergänzen, damit eine
  gespeicherte Merkliste lesbar bleibt (wie bei `TaskPlace`).

**ADR-Nr.:** keine — Schnitt 2a ist eine reine Planungsfunktion ohne Systemanschluss und ohne neue
Entscheidung gegen eine bestehende ADR. Sie setzt die freigegebenen Festlegungen F1–F7 und die Master-Spec
um. Eine ADR entstünde erst, wenn Alternative C (ADR-Antwort 14) gekippt würde.

## Definition of Done

- Alle Unit-Tests oben grün (`./scripts/sim.sh unit`) und die Tests der Nachbardateien unverändert grün;
  Build und UI-Smoke der CI grün.
- `docs/project/04-stand.md` nennt Schnitt 2a als gebaut und 2b als nächsten Schritt von #226.
- Der Abschlussbericht benennt, dass 2a nichts Sichtbares ändert und nur per Unit-Test belegt ist, und
  schließt mit: „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-07: Entwurf. Schnitt 2a der Zustellung aus `docs/context/feat-226-zustellung.md`
  (Alternative A: Merkliste je Gerät); Systemanschluss als Schnitt 2b ausgegliedert.
