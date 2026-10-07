---
entity_id: feat-226-schnitt-4-zustellung
type: feature
created: 2026-10-07
updated: 2026-10-07
status: draft
workflow: feat-226-ortserinnerungen
---

# Spec: #226 Schnitt 4 — Ortserinnerung zustellen

## Approval

- [ ] Approved (Henning)

## Purpose

Eine Aufgabe mit Ort erinnert beim Ankommen oder Verlassen, auch wenn die App nicht läuft.
Produktentscheidungen: `docs/specs/feat-226-ortserinnerungen.md` (F1–F7). Schnitt 1 hat Ort und
Auswahl der höchstens 20 überwachten Orte gebaut (`PlaceReminders.plan`); hier kommen Vermerk und
Zustellung dazu. Zwei Teile, getrennt gebaut, weil nur der zweite die Geräteliste berührt.

## Befund aus Schnitt 1: ohne Vermerk erinnert dieselbe Aufgabe zweimal

`UNLocationNotificationTrigger` mit `repeats: false` löst einmal aus und ist danach aus dem System
verschwunden. `DueNotificationCenter.reschedule()` ersetzt aber nach **jedem Speichern** alle
offenen Anfragen durch den aktuellen Plan. Läse man den Ort wie heute (`plan` nimmt jede offene
Aufgabe mit Ort), meldete der nächste Speichervorgang die schon zugestellte Erinnerung neu an, und
sie käme beim nächsten Mal Ankommen wieder. Verlangt ist „einmal, dann nicht mehr“ (F3). Der Plan
muss also wissen, welche Orte schon erinnert haben.

## Teil A — Vermerk „erinnert“ (rein, in der Cloud baubar)

Kein Pfad der Geräteliste berührt (`Shared/Models`, `Shared/Notifications`, `Shared/Services`).

| Datei | Änderung |
|---|---|
| `Shared/Models/TaskItem.swift` | `var placeRemindedAt: Date?` (optional, Vorgabe `nil`; additiv für CloudKit, wie `place`) |
| `Shared/Notifications/PlaceReminders.swift` | `plan` lässt Aufgaben mit `placeRemindedAt != nil` aus `watched` **und** `unwatched` heraus (sie warten nicht auf einen Platz, sie sind erledigt). Neu: `markDelivered(taskID:in:now:) -> Bool`, setzt den Vermerk; `false`, wenn die Aufgabe fehlt. |
| `Shared/Services/TaskActions.swift` | `complete` einer Wiederholung setzt `placeRemindedAt = nil` (der Ort wird für den nächsten Durchgang wieder scharf, F3). `park` und endgültiges Erledigen ändern ihn nicht. |
| `Shared/Services/FieldCodec.swift` | Wird ein Ort gesetzt oder geändert (`apply(.place)`, auch beim Zurücksetzen), wird `placeRemindedAt` geleert: ein neuer Ort ist eine neue Erinnerung. |
| `LooseEndsTests/PlaceRemindersTests.swift` | Neue Fälle, siehe Testplan |

Der Vermerk ist ein Zustand, keine Ableitung: kein `*SourceRaw`, keine Revision (wie `completedAt`).

### Testplan Teil A (TDD, rot zuerst)

- Aufgabe mit Ort und `placeRemindedAt` fehlt in `watched` und in `unwatched`.
- `markDelivered` setzt den Vermerk; zweimal aufgerufen ändert nichts; unbekannte `taskID` → `false`.
- Wiederholende Aufgabe: `markDelivered`, dann `TaskActions.complete` → Vermerk `nil`, wieder in `watched`.
- Nicht wiederholende Aufgabe: `complete` → erledigt, nicht im Plan (wie bisher).
- Neuer Ort per `FieldCodec.apply(.place)` an einer schon erinnerten Aufgabe → Vermerk `nil`.
- Alle bestehenden `PlaceReminders`-Tests (Rangfolge, 20er-Grenze, Stabilität) bleiben unverändert grün.

### Acceptance Criteria Teil A

- **AC-A1:** Eine zugestellte Ortserinnerung taucht in keinem weiteren Plan auf.
- **AC-A2:** Eine abgehakte Wiederholung ist für den nächsten Durchgang wieder im Plan.
- **AC-A3:** Ein geänderter Ort erinnert wieder.
- **AC-A4:** `DueReminders` und alle bestehenden Tests bleiben unverändert grün.

## Teil B — Zustellung (System, Gerätestufe Pflicht)

Berührt `LooseEnds/Notifications/` und `Info.plist` → Stufe 3 ist Pflicht (`CLAUDE.md`).
Gebaut wird auf dem Mac, nachgewiesen wird auf dem iPhone mit „LE Prüfbau“.

- `Info.plist`: `NSLocationWhenInUseUsageDescription` mit dem Text aus der Vorbereitung.
- `LooseEnds/Notifications/PlaceNotificationCenter.swift` (neu), parallel zu `DueNotificationCenter`:
  - Kategorie `PLACE` mit zwei Aktionen: **Erledigt** und **Als nächstes** (F4). Kein „Morgen“.
  - `reschedule()`: ersetzt alle offenen Anfragen mit Präfix `place_` durch `PlaceReminders.plan`
    (`watched`), je ein `UNLocationNotificationTrigger` mit `CLCircularRegion(radius: TaskPlace.radius)`,
    `notifyOnEntry`/`notifyOnExit` je nach `event`, `repeats: false`.
  - Zugestellt wird nach Teil A: Kommt die Mitteilung an (`willPresent` oder Aktion), ruft der Code
    `PlaceReminders.markDelivered` und speichert.
  - Aktionen laufen über dieselbe `handle`-Logik wie bei `DueReminders` (Erledigt, Als nächstes).
  - Standort-Freigabe wird erst beim ersten gesetzten Ort abgefragt (F1), nicht im Onboarding.
    Lehnt Henning ab, bleibt der Ort gespeichert; es wird nichts angemeldet.
  - Unter Tests stumm, wie `DueNotificationCenter` (`ModelContainerFactory.isRunningTests`).
  - Nur iOS, iPadOS, watchOS; auf dem Mac nichts anmelden (`#if !os(macOS)`).
- `LooseEndsApp`/`ContentView`: `rescheduleSoon()` ruft zusätzlich die Ortsplanung auf.
- Die Anfragen der Fällig-Mitteilung bleiben unberührt (Präfix `due_`).

### Nachweis (Stufe 3)

1. `./scripts/sim.sh device-status`, dann „LE Prüfbau“ per `sim.sh device`.
2. Aufgabe mit Ort anlegen (bis Schnitt 3 steht, per Siri oder Debug-Zugang festgelegt), Freigabe
   „Beim Verwenden der App“ erteilen.
3. Den Ort wirklich erreichen oder verlassen: Mitteilung mit Titel, Aktionen Erledigt / Als nächstes.
4. Danach noch einmal speichern und den Ort noch einmal erreichen: keine zweite Mitteilung.

## Nicht in Schnitt 4

Oberfläche (Schnitt 3), Siri-Abbildung (#25), Ort aus dem Rohtext (#237), `SavedPlace`.

## Risiken

- **iOS prüft nicht auf den Meter:** Das System meldet Ankommen/Verlassen mit Verzögerung (Quelle:
  Apple, „Monitoring the user’s proximity“). Das ist Systemverhalten, kein Fehler.
- **Freigabe verweigert:** Der Ort bleibt gespeichert und erinnert nicht. Der Hinweis dazu kommt
  mit Schnitt 3.

## Definition of Done

- Teil A: Tests grün in der CI; `docs/project/04-stand.md` nennt Teil A als gebaut.
- Teil B: Nachweis auf dem iPhone nach obigem Ablauf, mit Beleg im Abschlussbericht.
