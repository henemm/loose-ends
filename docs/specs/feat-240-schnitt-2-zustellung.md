---
entity_id: feat-240-schnitt-2-zustellung
type: feature
created: 2026-10-14
updated: 2026-10-14
status: draft
workflow: feat-240-schnitt-2-zustellung
---

# Spec: #240 Schnitt 2 — Ortsmitteilung zustellen (Systemanschluss)

## Approval

- [ ] Approved (Henning)

## Purpose

Was der Nutzer erlebt: Eine Aufgabe mit Ort meldet sich auf dem iPhone und iPad beim Ankommen oder Verlassen mit
„Du bist bei <Ort>.“, auch wenn die App geschlossen ist. Die Mitteilung trägt die Knöpfe „Erledigt“ und „Als
nächstes“ (kein „Morgen“, ein Ort hat keinen Tag); Tippen öffnet die Aufgabe. Die Mitteilung kommt **einmal je
Zyklus für alle Geräte zusammen** (Festlegung „Einmal für alle“). Die App fragt nach dem Standortrecht „Beim
Verwenden“ erst, wenn zum ersten Mal ein Ort zu überwachen ist, nur einmal und nur im Vordergrund.

Schnitt 1 (PR #410) hat die reinen Bausteine geliefert (`NotificationCategories`, `PlaceNotifications`,
`ReconcileGate`); `PlaceReminders.plan` und `PlaceDelivery.diff` liegen seit #226 bereit. Schnitt 2 schließt sie
ans System an: `PlaceNotificationCenter` (iOS, `UNLocationNotificationTrigger`), Anschluss im bestehenden
`DueNotificationCenter` als einzigem Delegate, Berechtigungstext in `project.yml`. Diese Spec ersetzt zusammen mit
Schnitt 1 den Teil B von `docs/specs/feat-226-schnitt-4-zustellung.md`.

Ohne Modell: Es ist keines im Spiel; Regeln und Systemauslöser sind der einzige Weg (Regeln vor dem Modell).

**Umfang:** Henning hat am 2026-10-14 „alles in einem Durchgang“ gewählt. Das ist eine bewusste, ausdrückliche
Ausnahme vom 250-Zeilen-Limit (geschätzt rund +400 / −20 Zeilen samt Tests). Darüber hinaus wird nichts angefasst.

## Source

Details siehe `docs/context/feat-240-schnitt-2-zustellung.md` (Abschnitt „Analysis“), hier treu übernommen.

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Notifications/PlaceNotificationCenter.swift` | CREATE | Alles unter `#if os(iOS)`. Ortslogik aus der Vorarbeit (Worktree `jazzy-crunching-trinket`, nur gelesen), ohne den Wegwerf-`PlaceSeed`. Neue Prüfnähte: `PlaceScheduling` (pending, remove, add; `SystemDueScheduler` erfüllt es), eine Standort-Naht (Status, Genauigkeit, Vordergrund, Freigabe erbitten), ein Merklistenspeicher statt `UserDefaults.standard`. `reconcile` fängt eigene Fehler ab. Ca. 190 Zeilen. |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | MODIFY | `setNotificationCategories(NotificationCategories.all())` statt `[Self.category]`, private Kategorie entfällt. Optionales `PlaceReconciling` (auf dem Mac nil). `reschedule()` ruft danach `reconcile`. Im Delegate werden Kennung und `taskID` als Strings gelesen; bei `place_` läuft zuerst `PlaceNotifications.respond`, dann `taskToOpen`. `willPresent` setzt die Marke in einem eigenen Main-Actor-Task, die Completion folgt sofort. Callback-Fassungen bleiben (#295). Ca. +40 / −20. |
| `project.yml` | MODIFY | `NSLocationWhenInUseUsageDescription` im App-Target (Text der Vorarbeit, englisch). |
| `LooseEnds/Resources/de.lproj/InfoPlist.strings`, `LooseEnds/Resources/en.lproj/InfoPlist.strings` | MODIFY | Der Berechtigungstext deutsch und englisch (wie die übrigen `UsageDescription`). Je eine Zeile. |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | „You're at %@.“ → „Du bist bei %@.“ |
| `LooseEndsTests/PlaceNotificationCenterTests.swift` | CREATE | Recorder-Tests zum Ortszentrum. Ca. 130 Zeilen. |
| `LooseEndsTests/DueNotificationCenterTests.swift` | MODIFY | Routing- und Anschlusstests. Ca. +60 Zeilen. |
| `LooseEndsUITests/PlaceNotificationTapTests.swift`, `scripts/fixtures/place-reminder.apns` | CREATE | UI-Test wie `DueNotificationTapTests`. Ca. 100 Zeilen. |
| `LooseEnds/App/LooseEndsApp.swift` oder `ContentView.swift` | MODIFY (nur unter `--ui-testing-places`, ca. 15 Zeilen) | Prüfaufgabe mit fester UUID (`…0240`) und Ort, nur unter UI-Test. Falls schon eine Hilfe für Prüfdaten existiert, wird sie dort ergänzt. |

`LooseEndsApp.swift` und `ContentView.swift` bekommen **keine Anschlusslogik**: `ModelContext.didSave` und der
Wechsel in den Vordergrund lösen schon `rescheduleSoon()` aus, und `reschedule()` ruft den Ortsabgleich.

Erwartet: 9–10 Dateien, ca. +400 / −20 Zeilen (Produkt ca. 210, Tests ca. 210). Keine Funktion über 50 Zeilen.
Das Projekt ist generiert: Nach neuen Dateien und `project.yml` muss `./scripts/sim.sh generate` laufen.

Side-Effects: neue Berechtigung (Standort „Beim Verwenden“, Info.plist-Schlüssel); neue `UserDefaults`-Schlüssel
`placeHandover` (Merkliste) und `placeAuthorizationAsked` (Merker „schon gefragt“); keine neuen AppStorage-Schlüssel
der Oberfläche; keine Audio-Dateien; kein Modell- und kein CloudKit-Schema-Schritt (`placeRemindedAt` existiert
seit PR #248).

### Out of Scope

- **Kein Schnitt 3b:** kein Hinweis „Standort nicht freigegeben“ in der Oberfläche, kein „Aktueller Ort“ (#241).
- **Kein `CLMonitor`, kein „Immer“, kein Hintergrundmodus** (Alternative C, F1 „Beim Verwenden“ bleibt).
- **Kein Mac:** `UNLocationNotificationTrigger` gibt es auf macOS nicht; alles `#if os(iOS)`. **iPad gehört dazu**
  (läuft als iOS). Watch und Mac übergeben nichts.
- Keine Änderung am Modell, an Entitlements, am CloudKit-Schema.
- Siri (#25) und die Fälligkeits-Mitteilung selbst (nur die gemeinsame Kategorienmenge ändert sich).

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `NotificationCategories.all()`, `PlaceNotifications.respond`, `isAuthorized`, `shouldRequestAuthorization`, `isSilent`, `pendingPlaceIdentifiers`, `ReconcileGate` | Aufruf (Schnitt 1) | Kategorien, Antwort auf Tippen/Knopf, Freigabe-Entscheidung, Schutz gegen überlappende Läufe. |
| `PlaceReminders.plan` / `identifierPrefix` / `markDelivered` | Aufruf | ≤ 20 Orte, Präfix `place_`, Marke `placeRemindedAt`. |
| `PlaceDelivery.diff` / `Handover` | Aufruf | Hinzufügen, Zurücknehmen, Titel ersetzen, Merkliste je Gerät. |
| `DueReminders.handle`, `taskToOpen`, `SystemDueScheduler` (#328) | Wiederverwendung | Knöpfe Erledigt/Als nächstes, Öffnen der Aufgabe, Systemnaht für pending/remove/add. |
| `CoreLocation` (`CLLocationManager`, `CLCircularRegion`) | System, nur iOS | Freigabe „Beim Verwenden“, Genauigkeit, Region 150 m. |
| `UserNotifications` (`UNLocationNotificationTrigger`, `UNUserNotificationCenter`) | System, nur iOS | Anmelden und Zurücknehmen der Ortsmitteilung, einziger Delegate. |

## Recherche (2026-10-14)

| Frage | Befund | Quelle |
|---|---|---|
| Braucht die Ortsmitteilung „Immer“ oder einen Hintergrundmodus? | Nein. „Because the system actually monitors the regions, you don't need to request always permissions.“ Die App muss nicht laufen. Tutorials mit Hintergrundmodus meinen die eigene Bereichsüberwachung per `CLLocationManager`, nicht diesen Auslöser. | [Apple-Doku UNLocationNotificationTrigger](https://developer.apple.com/tutorials/data/documentation/usernotifications/unlocationnotificationtrigger.md), [Kodeco](https://www.kodeco.com/20690666-location-notifications-with-unlocationnotificationtrigger) |
| Auslöser verzögert? | Ja. Das System wendet Heuristiken an, damit nur eine absichtliche Grenzüberschreitung zählt; auf dem Gerät bis zu einige Minuten. | Apple-Doku (oben) |
| Zustellung sichtbar? | Ortsmitteilungen fehlen in `getDeliveredNotifications`; deshalb Merkliste je Gerät und Marke `placeRemindedAt`. | [Forum 777251](https://developer.apple.com/forums/thread/777251) |
| Simulator | Ortsmitteilungen kommen dort laut Fremdberichten nicht an. Zusätzlich lehnt der iOS-27-Simulator jedes `add` aus der App ab (UNErrorDomain 2003, eigene Messung 2026-10-10). Belegbar sind nur Antippen und Knöpfe einer von außen eingespielten Mitteilung (`simctl push`). | [MoEngage](https://moengage.com/docs/developer-guide/ios-sdk/push/optional/location-triggered), Memory `loose-ends-sim-mitteilung-add-2003` |
| `requestWhenInUseAuthorization`, reduzierte Genauigkeit | fragt nur bei `notDetermined` und im Vordergrund; reduzierte Genauigkeit schaltet Bereichsüberwachung ab. | siehe Spec Schnitt 1 |

## Implementation Details

1. **Eine Kategorienmenge, ein Aufruf.** `DueNotificationCenter.activate()` ruft
   `setNotificationCategories(NotificationCategories.all())` genau einmal; die private Kategorie entfällt. Das
   Ortszentrum ruft `setNotificationCategories` nie.
2. **Ein Delegate.** `DueNotificationCenter` bleibt `UNUserNotificationCenter.delegate`. Das Ortszentrum ist
   Delegate nur für `CLLocationManager` (Berechtigungswechsel).
3. **Callback-Fassungen (#295).** `didReceive` und `willPresent` bleiben Callback-Methoden; die Completion kommt vom
   Main-Thread. `didReceive` ruft die Completion nach der Arbeit, `willPresent` sofort.
4. **Routing am Präfix.** Entscheidend ist allein `place_`, nicht `PlaceNotifications.isSilent`. Sonst bliebe der
   UI-Test unter `--ui-testing-notifications` blind (zwei Schalter: `suppressed` und `isSilent`).
5. **`willPresent`** (App im Vordergrund) setzt die Marke über `PlaceNotifications.respond` in einem eigenen
   Main-Actor-Task und speichert; die Completion (`[.banner, .list, .sound]`) wird nicht darauf gewartet.
6. **Abgleich (`reconcile`)** nach jedem `reschedule()`: Plan holen (`PlaceReminders.plan`), Freigabe prüfen,
   gegebenenfalls einmal fragen, offene `place_`-Kennungen filtern, `PlaceDelivery.diff`, zuerst Zurücknehmen,
   dann `add` (neue und Titel-Ersetzungen), erst danach Merkliste schreiben. `ReconcileGate` verhindert
   überlappende Läufe. Fehler werden mit `Logger` protokolliert und gehen nicht nach außen.
7. **Anfrage:** Kategorie `PLACE`, `userInfo["taskID"]`, Inhalt Titel der Aufgabe und Text „Du bist bei <Ort>.“,
   Auslöser `UNLocationNotificationTrigger` mit `CLCircularRegion` (Radius `TaskPlace.radius` = 150 m),
   `notifyOnEntry` bei Ankommen, `notifyOnExit` bei Verlassen, `repeats: false`, Kennung `place_<uuid>`.
8. **Freigabe:** Gefragt wird mit `PlaceNotifications.shouldRequestAuthorization` und `requestWhenInUseAuthorization`;
   danach wird der Merker `placeAuthorizationAsked` gesetzt.

## Acceptance Criteria

Alles, was nicht ausdrücklich anders steht, sind Unit-Tests im Simulatorlauf (`./scripts/sim.sh unit`) mit
Recorder statt System. Geräte-ACs stehen am Ende und sind als solche gekennzeichnet.

### Kategorien und Delegate

- **AC-1:** **Genau ein `setNotificationCategories` mit beiden Kategorien:** Given ein `DueNotificationCenter` mit
  Recorder-Naht / When `activate()` läuft / Then wird `setNotificationCategories` genau einmal mit
  `NotificationCategories.all()` aufgerufen (Kategorien `DUE` mit `DUE_DONE`, `DUE_NEXT`, `DUE_TOMORROW` und
  `PLACE` mit `DUE_DONE`, `DUE_NEXT`), und `PlaceNotificationCenter` ruft es nie. Nachweis: Unit-Test
  (`DueNotificationCenterTests`), Gegenprobe im UI-Test: der Knopf „Tomorrow“ der Fällig-Mitteilung ist weiter da
  (AC-14).
- **AC-2:** **`DueNotificationCenter` bleibt einziger Delegate, Callback-Fassungen (#295):** Given der Quelltext
  beider Zentren / Then setzt nur `DueNotificationCenter` `UNUserNotificationCenter.delegate`; `didReceive` und
  `willPresent` sind Callback-Methoden (`withCompletionHandler`), keine `async`-Fassungen. Nachweis: Unit-Test, der
  die Delegate-Methoden mit Completion-Handlern aufruft und die Completion zählt; Review des Quelltexts; UI-Test
  AC-12 gegen den Absturz aus #295.
- **AC-3:** **Routing nur am Präfix `place_`:** Given eine Antwort mit Kennung `place_<uuid>` / When
  `didReceive` läuft, auch wenn das Ortszentrum still ist (`isSilent`) / Then läuft `PlaceNotifications.respond`
  (Marke und Knopf), danach `taskToOpen`. Given Kennung `due_<uuid>` / Then verhält sich der Pfad unverändert
  und setzt `placeRemindedAt` nie. Nachweis: Unit-Test (`DueNotificationCenterTests`).
- **AC-4:** **Tippen und Knöpfe an der Ortsmitteilung:** Given eine Aufgabe mit Ort und eine Antwort `place_<uuid>`
  ohne Knopf (Tippen) / Then ist `placeRemindedAt` gesetzt, gespeichert, und `OpenTaskRequest.shared.taskID` zeigt
  auf die Aufgabe. Given `DUE_DONE` / Then Aufgabe erledigt und Marke gesetzt. Given `DUE_NEXT` / Then Aufgabe als
  nächstes und Marke gesetzt. Given `DUE_TOMORROW` auf `place_<uuid>` / Then ändert sich an der Aufgabe nichts
  (Marke bleibt, wie `respond` es vorgibt). Nachweis: Unit-Test.
- **AC-5:** **`willPresent` setzt die Marke, die Completion kommt sofort:** Given eine Ortsmitteilung erscheint bei
  offener App / When `willPresent` läuft / Then wird die Completion mit `[.banner, .list, .sound]` aufgerufen,
  bevor die Marke gespeichert ist (kein Warten), und `placeRemindedAt` ist nach dem Main-Actor-Task gesetzt. Given
  eine `due_`-Mitteilung / Then bleibt die Marke leer. Nachweis: Unit-Test.

### Abgleich im Ortszentrum

- **AC-6:** **Die Anfrage trägt alles Nötige:** Given eine Aufgabe mit Ort „Büro“, Ereignis Ankommen / When
  `reconcile` läuft / Then bekommt der Recorder genau eine Anfrage mit Kennung `place_<uuid>`, Kategorie `PLACE`,
  `userInfo["taskID"]`, Titel der Aufgabe, Text „Du bist bei Büro.“ (lokalisiert), `UNLocationNotificationTrigger`
  mit `CLCircularRegion` (Radius 150 m, `repeats == false`), `notifyOnEntry == true`, `notifyOnExit == false`.
  Given Ereignis Verlassen / Then `notifyOnEntry == false`, `notifyOnExit == true`. Nachweis: Unit-Test
  (`PlaceNotificationCenterTests`).
- **AC-7:** **Fälligkeiten bleiben unberührt:** Given offene Anfragen `due_<uuid>` und `place_<uuid>` / When
  `reconcile` läuft / Then werden nur `place_`-Kennungen gelesen, ersetzt oder zurückgenommen; kein `due_`-Eintrag
  wird je an `remove` oder `add` gereicht. Umgekehrt fasst `reschedule()` für Fälligkeiten keine `place_`-Kennung
  an. Nachweis: Unit-Test.
- **AC-8:** **Zweiter Lauf ohne Änderung tut nichts:** Given ein Lauf hat Plan und Merkliste übergeben / When
  `reconcile` ein zweites Mal ohne Änderung an Aufgaben läuft / Then kommen weder `add` noch `remove`. Given
  der Ort einer Aufgabe ändert sich / Then wird nur diese Anfrage ersetzt; ändert sich nur der Titel, wird nur der
  Inhalt ersetzt. Nachweis: Unit-Test.
- **AC-9:** **Fehler bei `add` bricht nichts und schreibt die Merkliste nicht:** Given `add` wirft (wie
  UNErrorDomain 2003 im Simulator) / When `reconcile` läuft / Then wirft `reconcile` nicht, die Merkliste bleibt
  ungeschrieben, der nächste Lauf versucht es erneut, und der Fälligkeitslauf (`reschedule()`, Abzeichen)
  läuft vollständig durch, auch wenn der Ortsabgleich scheitert. Nachweis: Unit-Test.
- **AC-10:** **Ohne Freigabe nur Zurücknehmen:** Given keine Freigabe (`refused`, `notDetermined` oder reduzierte
  Genauigkeit) / When `reconcile` läuft / Then wird nichts hinzugefügt und keine Merkliste geschrieben, aber
  veraltete `place_`-Anfragen (Aufgabe erledigt, Ort entfernt, Marke gesetzt) werden zurückgenommen. Nachweis:
  Unit-Test.
- **AC-11:** **Freigabe wird nur einmal gefragt, nur mit Ort, nur im Vordergrund:** Given `notDetermined`, Ort
  überwacht, noch nie gefragt, App aktiv / When `reconcile` läuft / Then genau eine Anfrage nach „Beim
  Verwenden“, danach ist `placeAuthorizationAsked` gesetzt. Given jeweils eine der Bedingungen verletzt (kein Ort,
  schon gefragt, Hintergrund, Status erteilt oder abgelehnt) / Then keine Anfrage. Given der Wechsel in den
  Vordergrund nach einem Lauf im Hintergrund / Then wird dann gefragt (Merker nicht vorher gesetzt). Reduzierte
  Genauigkeit gilt als keine Freigabe und fragt nicht erneut. Nachweis: Unit-Test.

### UI-Test (Simulator, `simctl push`)

- **AC-12:** **Die App überlebt das Banner, Tippen öffnet die Aufgabe:** Given
  `LOOSEENDS_PUSH=scripts/fixtures/place-reminder.apns ./scripts/sim.sh test-proof PlaceNotificationTapTests` mit
  Kategorie `PLACE`, `taskID …0240` und der Prüfaufgabe unter `--ui-testing-places` / When das Banner bei offener
  App erscheint / Then bleibt die App im Vordergrund (`runningForeground`, kein Absturz nach 5 s, Erfassen-Knopf
  bedienbar); When die App im Home-Bildschirm ist und das Banner angetippt wird / Then kommt sie nach vorn und
  ist bedienbar. Nachweis: UI-Test `PlaceNotificationTapTests` mit maschinellem Simulator-Beleg
  (Screenshots werden geöffnet und beschrieben).
- **AC-13:** **Knöpfe der Ortsmitteilung:** Given dasselbe Banner / When langes Drücken / Then zeigt es „Complete“
  und „Next up“ und **kein** „Tomorrow“; When „Complete“ getippt wird / Then ist die Prüfaufgabe in der Liste
  erledigt. Nachweis: UI-Test.
- **AC-14:** **Regression Fällig-Mitteilung:** Given `LOOSEENDS_PUSH=scripts/fixtures/due-reminder.apns
  ./scripts/sim.sh test-proof DueNotificationTapTests` / Then bleibt der Test grün, und das lange Drücken der
  Fällig-Mitteilung zeigt weiter „Tomorrow“ (Gegenprobe zu AC-1). `PlaceSmokeTests` bleibt grün. Nachweis: UI-Tests.

### Übersetzung, Text, Mac

- **AC-15:** **Lokalisierung und Berechtigungstext:** Given `Localizable.xcstrings` / Then liefert „You're at %@.“ im
  Deutschen „Du bist bei %@.“ (Unit-Test mit Locale `de`). Given `project.yml` / Then enthält das App-Target
  `NSLocationWhenInUseUsageDescription` (englisch) und beide `InfoPlist.strings` den passenden Text; nach
  `./scripts/sim.sh generate` steht der Schlüssel in der erzeugten `Info.plist`. Nachweis: Unit-Test plus
  Prüfung der erzeugten `Info.plist` im Build-Lauf.
- **AC-16:** **Mac-Build kompiliert weiter:** Given der Stand nach Schnitt 2 / When die App für macOS (und die
  Watch- und Widget-Targets, in denen `Shared/` liegt) gebaut wird / Then ist der Bau fehlerfrei; auf dem Mac gibt
  es kein `PlaceNotificationCenter` (`#if os(iOS)`), und `DueNotificationCenter` läuft dort mit `nil`-Ortszentrum
  wie zuvor. Nachweis: macOS-Build als Gegenprobe der `#if`-Grenze (kein Test auf Hennings Mac, nur Bau).
- **AC-17:** **Regression:** Given `./scripts/sim.sh generate` und `./scripts/sim.sh unit` / Then bleiben alle
  bestehenden Tests grün (`DueReminders`, `PlaceReminders`, `PlaceDelivery`, `PlaceNotifications`,
  `DueNotificationCenter`). Nachweis: Unit-Lauf, CI grün.
- **AC-18:** **Simulatorlauf, ehrlich:** Given `./scripts/sim.sh build`, `launch`, `screenshot` / When die App mit
  einer Aufgabe mit Ort gestartet wird / Then startet sie wie zuvor, die Ortszeile im Detail ist da, die App stürzt
  beim Abgleich nicht ab, auch wenn `add` im Simulator mit 2003 scheitert (Protokollzeile statt Absturz). Berichtet
  wird ausdrücklich: **Der echte Ortsauslöser (Ankommen/Verlassen bis zum Banner) ist im Simulator nicht belegbar**;
  er wird in AC-19 bis AC-21 auf dem Gerät belegt. Nachweis: Simulatorlauf mit Screenshots (geöffnet und
  beschrieben).

### Gerät (Stufe 3, Pflicht)

Die Geräteliste greift (`LooseEnds/Notifications/`, `project.yml`). Läuft über TestFlight nach dem Merge und
**nur nach Hennings wörtlichem „jetzt ist ein Test möglich“**. Die Buildnummer und die Prüfschritte stehen in
„Was testen“ des TestFlight-Baus. Vorher läuft nichts auf Hennings Geräten, auch nichts Lesendes.

- **AC-19:** **Ankommen bei geschlossener App:** Given ein TestFlight-Bau, Standortfrage mit „Beim Verwenden“
  beantwortet, eine Aufgabe mit Ort und Ereignis Ankommen, App geschlossen / When Henning den Ort betritt (Prüfort
  Zuhause 51.99563, 7.71357, nach einem Verlassen des Bereichs) / Then erscheint „Du bist bei <Ort>.“ mit Titel
  der Aufgabe (mit Systemverzögerung von bis zu einigen Minuten). Nachweis: Gerät, TestFlight, nachgelagert.
- **AC-20:** **Verlassen bei geschlossener App und Einmal-Prinzip:** Given eine Aufgabe mit Ereignis Verlassen,
  App geschlossen / When Henning den Ort verlässt / Then erscheint die Mitteilung einmal; When er danach erneut
  den Bereich quert / Then bleibt eine zweite Mitteilung aus (Marke gesetzt, Anfrage zurückgenommen). Nachweis:
  Gerät, TestFlight, nachgelagert.
- **AC-21:** **Knopf „Erledigt“ am Gerät:** Given die Ortsmitteilung ist da / When Henning „Erledigt“ tippt /
  Then ist die Aufgabe erledigt, in der Liste wie am Simulator. Nachweis: Gerät, TestFlight, nachgelagert.

## Tests

- **Unit** (Swift Testing, TDD RED zuerst; `ModelContainer` bleibt im Test am Leben):
  `LooseEndsTests/PlaceNotificationCenterTests.swift` (AC-6 bis AC-11, AC-15) mit Recorder für `PlaceScheduling`,
  Standort-Naht und Merklistenspeicher; `LooseEndsTests/DueNotificationCenterTests.swift` (AC-1 bis AC-5, AC-9
  zweiter Teil: `reschedule()` ruft `reconcile`, Fehler dort bricht den Fälligkeitslauf nicht). Die Namen nennen die
  Wirkung („Fehler beim Anlegen lässt die Merkliste ungeschrieben“), nicht „Funktion existiert“. Zusicherungen über
  `==`, nie `CONTAINS`.
- **UI** (`./scripts/sim.sh test-proof PlaceNotificationTapTests`, Fixture `scripts/fixtures/place-reminder.apns`):
  AC-12, AC-13; Regression AC-14. Unter CI ohne `LOOSEENDS_PUSH_FEED` übersprungen wie `DueNotificationTapTests`.
- Reihenfolge: RED (Unit und UI) → `PlaceNotificationCenter` → `DueNotificationCenter` → `project.yml` und
  `generate` → iOS-Build, Unit, macOS-Bau → `test-proof PlaceNotificationTapTests` und Regression
  `DueNotificationTapTests`, `PlaceSmokeTests` → Simulatorlauf mit Beleg.

## Alternativen (bewusst benannt)

| | Weg | Dafür | Dagegen / welche Entscheidung kippt |
|---|---|---|---|
| **A (Empfehlung, diese Spec)** | `DueNotificationCenter` bleibt einziger Delegate und besitzt den Ortsabgleich hinter einem kleinen Protokoll; Ortslogik der Vorarbeit neu angeschlossen | ein Delegate, eine Auslösestelle, Recorder-Tests als Hauptbeweis | `DueNotificationCenter` wächst um das Routing |
| B | Ortszentrum gleichrangig in `LooseEndsApp`, Antworten per Closure aus dem Delegate, `ContentView` löst zusätzlich aus | `DueNotificationCenter` bleibt frei von Ortslogik | zwei Dateien mehr und eine zweite Auslösestelle, die man vergessen kann; für die Testbarkeit kein Gewinn |
| C | `CLMonitor` + „Immer“, die App stellt selbst zu | volle Kontrolle, Fehlauslösungen filterbar | kippt F1 (ADR-Antwort 14 „Beim Verwenden“), Hintergrundmodus, strengere Prüfung; bleibt der Rückfall, falls der Gerätelauf den Systemauslöser als unzuverlässig zeigt |
| D | UI-Test weglassen, nur Unit-Tests | rund 100 Zeilen weniger | verliert den Absturzschutz für den neuen Delegate-Pfad (#295); abgewählt, UI-Tests sind Pflicht |

## Risiken

- **Delegate ist der Weg aller Mitteilungen** (MITTEL): Ein Fehler im Routing träfe auch die Fällig-Mitteilung.
  Gegen: Routing nur am Präfix, Callback-Fassungen, AC-2, AC-3 und die Regression AC-14.
- **Kategorien überschreiben sich:** Ein zweiter `setNotificationCategories`-Aufruf nähme die Knöpfe der anderen
  Kategorie. Gegen: genau ein Aufruf (AC-1).
- **Async-Delegate der Vorarbeit:** Genau diese Fassung stürzte in #295 beim Antippen ab; sie wird nicht
  übernommen.
- **Simulator:** `add` scheitert dort immer (2003), und der Ortsauslöser ist nicht belegbar. Fehler werden
  protokolliert (AC-9), der echte Auslöser wird nur auf dem Gerät belegt (AC-19 bis AC-21).
- **Systemverzögerung und Mehrdeutigkeit:** Der Auslöser kann Minuten dauern; „ausgelöst oder ignoriert“ ist nicht
  unterscheidbar (Forum 777251). Zwei Geräte können beide auslösen, bevor die Marke angekommen ist. Anlegen
  innerhalb des Bereichs löst nicht aus (erst beim nächsten Betreten, Gerät 2026-10-08).
- **Umfang:** Rund +400 Zeilen sind über dem Limit; Henning hat das am 2026-10-14 ausdrücklich freigegeben. Wächst es
  darüber hinaus, wird gestoppt und gemeldet.

## Abnahme-Stufen

1. **Tests:** `./scripts/sim.sh unit` grün, Mac-Gegenprobe baut, CI grün.
2. **Simulator:** `test-proof PlaceNotificationTapTests` (Banner per `simctl push`, App überlebt, Tippen, Knöpfe)
   und Regression; `build`, `launch`, `screenshot` des geänderten Ablaufs. Ehrlich festgehalten: Der echte
   Ortsauslöser ist im Simulator nicht belegbar.
3. **Gerät (Pflicht, Pfade `LooseEnds/Notifications/` und `project.yml`):** nach dem Merge über TestFlight, nur
   nach Hennings wörtlichem „jetzt ist ein Test möglich“; Ankommen und Verlassen bei geschlossener App melden sich
   mit „Du bist bei <Ort>.“, eine zweite Mitteilung bleibt aus, „Erledigt“ wirkt (AC-19 bis AC-21). Bis seine
   Rückmeldung da ist, bleibt #240 offen.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Schnitt 2 setzt freigegebene Festlegungen um (F1 „Beim Verwenden“, „Einmal für alle“, Merkliste aus 2a) und kippt keine ADR; eine ADR entstünde erst, wenn Alternative C („Immer“, ADR-Antwort 14) gewählt würde.

## Definition of Done

- Alle Unit- und UI-Tests grün, Build und CI grün, Mac-Gegenprobe baut.
- Simulator: Änderungsablauf gespielt, Belege geöffnet und beschrieben (AC-18).
- Nach dem Merge: TestFlight-Bau mit „Was testen“ auf Deutsch; Gerätepunkte AC-19 bis AC-21 mit Hennings
  Rückmeldung abgeschlossen; #240 erst dann geschlossen.

## Changelog

- 2026-10-14: Entwurf. Schnitt 2 aus `docs/context/feat-240-schnitt-2-zustellung.md`; „alles in einem Durchgang“
  als Ausnahme vom 250-Zeilen-Limit von Henning freigegeben.
