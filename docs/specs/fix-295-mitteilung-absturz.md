---
entity_id: fix-295-mitteilung-absturz
type: bugfix
created: 2026-10-10
updated: 2026-10-10
status: draft
workflow: fix-295-mitteilung-absturz
---

# Spec: #295 — Mitteilung antippen stürzt die App ab

## Approval

- [ ] Approved (Henning)

## Purpose

Henning (Issue #295, iPhone, TestFlight): „App stürzt ab bei Click auf Notification. Ich bekomme auf dem iPhone eine
Notification, dass eine Aufgabe fällig ist. Ich klicke auf die Notifikation. Beim Wechsel in die App stürzt die App ab. Die App
startet aber normal, wenn ich sie aufrufe.“

**Hat es bisher funktioniert?** Nein. `DueNotificationCenter.swift` ist seit seiner Einführung (#9, f56d46a) unverändert; der
Fehler steckt seit damals drin und zeigt sich, sobald jemand den Mitteilungskörper (oder einen Knopf) antippt. Es ist keine
Verschlechterung, sondern ein Fehler von Anfang an.

### Root Cause (belegt, am Simulator nachgestellt)

`LooseEnds/Notifications/DueNotificationCenter.swift:101` ist `nonisolated func userNotificationCenter(_:didReceive:) async`.
Die async-Variante läuft auf dem kooperativen Pool; der vom Compiler erzeugte `@objc`-Thunk ruft den Abschluss des Systems
danach aus diesem Strang auf. UIKit prüft den Hauptthread und bricht ab.

Nachstellung (2026-10-10, Simulator iPhone 18 Pro, iOS 27.0, Debug, main 5037f0e): App ohne `--ui-testing` (echter Startpfad
mit aktivem Delegate), Mitteilungen erlaubt, Home, Mitteilung mit `category: DUE` und `taskID` per `simctl push` eingespielt,
Banner getippt. Ergebnis: „com.henning.looseends crashed“, App danach `notRunning`. Bericht:
`docs/artifacts/fix-295-mitteilung-absturz/repro-simulator-crash.ips`. Auszug des Absturzes:

```
Thread 2 com.apple.root.user-initiated-qos.cooperative — SIGABRT
-[NSAssertionHandler handleFailureInMethod:…]
-[UIApplication _performBlockAfterCATransactionCommitSynchronizes:]
-[UIApplication _updateStateRestorationArchiveForBackgroundEvent:…]
-[UIApplication _updateSnapshotAndStateRestorationWithAction:windowScene:]
@objc closure #1 in DueNotificationCenter.userNotificationCenter(_:didReceive:)
```

Beim normalen Öffnen der App läuft `didReceive` nicht, daher kein Absturz — das passt zu Hennings Satz „Die App startet aber
normal“. `willPresent` (Zeile 110) ist gleich gebaut (async, nonisolated); ob es abstürzt, ist nicht nachgestellt und wird im
neuen Test mitgeprüft.

Quellen (Recherche zuerst, Apple-Developer-Forum, DTS): die async-Varianten der Delegate-Methoden sind nicht `@MainActor` und
springen vom Hauptthread auf den Pool; die Rückruf-Variante ruft das System auf dem Hauptthread:
- https://developer.apple.com/forums/thread/735651
- https://developer.apple.com/forums/thread/796407

### Lösung

Beide Delegate-Methoden werden auf die Rückruf-Varianten umgestellt; die async-Varianten verschwinden (keine daneben):

- `userNotificationCenter(_:didReceive:withCompletionHandler:)`, `nonisolated`: `actionIdentifier` und `taskID` werden
  **synchron** als `String` aus der `UNNotificationResponse` gezogen (die Antwort ist nicht `Sendable`). Danach
  `Task { @MainActor in await apply(...); completionHandler() }`. Der Abschluss läuft damit auf dem Hauptthread und **erst nach
  `save()`**, auch wenn `apply` früh zurückkehrt (der Abschluss steht nach dem `await` und läuft immer). So wird eine
  Aktion aus dem Hintergrund nicht vor dem Speichern suspendiert.
- `userNotificationCenter(_:willPresent:withCompletionHandler:)`: ruft synchron `completionHandler([.banner, .list, .sound])`.
  Ein Absturz dort ist mechanisch unwahrscheinlich, die Umstellung ist billig und hält beide Methoden gleich.
- Schalter `--ui-testing-notifications` (Muster `--ui-testing-calendar`, `LooseEnds/Calendar/CalendarBridge.swift`): hebt
  `suppressed` für Mitteilungen auf, damit der echte Delegate gesetzt ist und die Erlaubnis angefragt wird. Er plant **keine**
  Mitteilung. Der Store bleibt In-Memory (`--ui-testing`). In Release ist der Schalter nie wirksam: er greift nur zusammen mit
  `--ui-testing` (`ModelContainerFactory.isUITesting`), siehe Implementation Details.
- Die Mitteilung im Test kommt **von außen** per `simctl push` (wie in der Nachstellung). Grund (Änderung 2026-10-10, nach
  `override`): Im iOS-27-Simulator scheitert jedes `UNUserNotificationCenter.add` aus der App mit `UNErrorDomain 2003
  "Repository could not save notification. Source is not authorized." UNAuthorizationStatus=Denied`, obwohl die App
  `authorizationStatus == .authorized` sieht und SpringBoard „notDetermined -> authorized“ protokolliert; Intervall- und
  Kalender-Auslöser, mit und ohne Ton, alle gleich. `simctl push` wird angenommen. Fremdbericht derselben Eigenheit:
  https://github.com/Nihilus913/Journalinsight-ios/pull/90.

Regelweg-Vermerk (Regeln vor Modell): Kein Modell beteiligt. Es geht um die Thread-Zuordnung eines Systemrückrufs; die Frage
„ohne Modell geht es nicht, weil …“ stellt sich nicht.

## Source

- **Geändert:** `LooseEnds/Notifications/DueNotificationCenter.swift` (Rückruf-Varianten, Schalter)
- **Geändert:** `scripts/sim.sh` (`test-proof` spielt mit `LOOSEENDS_PUSH=<datei>` während des Laufs Mitteilungen ein)
- **Neu:** `scripts/fixtures/due-reminder.apns` (Inhalt der eingespielten Mitteilung)
- **Neu:** `LooseEndsUITests/DueNotificationTapTests.swift`
- **Gelöscht:** `LooseEndsUITests/Repro295Tests.swift` (Wegwerf-Reproduktion, nie committet)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Notifications/DueNotificationCenter.swift` | MODIFY | `didReceive`/`willPresent` auf Rückruf-Varianten; Strings synchron ziehen; Abschluss nach `apply` auf dem Hauptthread; `suppressed` unter `--ui-testing-notifications` aufgehoben (keine Test-Mitteilung im App-Code) |
| `scripts/sim.sh` | MODIFY | `test-proof` mit `LOOSEENDS_PUSH=<datei>`: setzt `TEST_RUNNER_LOOSEENDS_PUSH_FEED=1` und spielt die Datei während des Laufs alle 5 s per `simctl push` ein; ohne die Variable unverändert |
| `scripts/fixtures/due-reminder.apns` | CREATE | Mitteilung „UI test reminder“, Kategorie `DUE`, `taskID` |
| `LooseEndsUITests/DueNotificationTapTests.swift` | CREATE | UI-Test, siehe Test Plan |
| `LooseEndsUITests/Repro295Tests.swift` | DELETE | Wegwerf-Reproduktion; wird nie committet |

Geschätzt **+110 / −15 LoC**, 4 Dateien (plus Wegwerfdatei weg), innerhalb der Scoping-Limits (4–5 Dateien, ±250 LoC).

**Geräteliste berührt:** `LooseEnds/Notifications/`. Stufe 3 (Hennings iPhone) ist Pflicht, aber **nur nach seinem wörtlichen
„jetzt ist ein Test möglich“**.

**Side-Effects:** Keine Änderung an Info.plist, Entitlements, AppStorage-Schlüsseln, Datenmodell, `DueReminders`
(`Shared/Notifications/`, unverändert), Texten oder Audio-Dateien. Neu ist nur ein Startargument, das ausschließlich Tests
setzen.

### Nicht in diesem Ticket

- Änderungen an `DueReminders` (Regeln, Kategorien, Aktionen).
- Ortserinnerungen (`PlaceReminders`/`PlaceDelivery`, #226).
- Das Verhalten nach dem Tippen (z. B. zur Aufgabe springen): heute öffnet der Körper-Tipp nur die App; das bleibt so.

## Implementation Details

### `didReceive` (Rückruf)

```swift
nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                        didReceive response: UNNotificationResponse,
                                        withCompletionHandler completionHandler: @escaping () -> Void) {
    let action = response.actionIdentifier
    let taskID = response.notification.request.content.userInfo["taskID"] as? String
    Task { @MainActor in
        await apply(actionRaw: action, taskID: taskID)
        completionHandler()
    }
}
```

`apply(actionRaw:taskID:)` (Zeile 117) bleibt unverändert; Ziel ist: nichts Nicht-`Sendable`es
überquert die Isolationsgrenze, und `completionHandler()` steht genau einmal, nach `apply`, auf dem Hauptthread. Ob der
Rückruf im iOS-27-SDK als `@Sendable` annotiert ist, wird beim ersten Build geprüft und die Signatur angepasst.

### `willPresent` (Rückruf)

```swift
nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                        willPresent notification: UNNotification,
                                        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .list, .sound])
}
```

### Schalter `--ui-testing-notifications`

- Hebt unter `--ui-testing` die Stille (`suppressed`) für den Mitteilungsdienst auf, wie `--ui-testing-calendar` es für den
  Kalender tut.
- Fragt die Erlaubnis an (der UI-Test beantwortet den Systemdialog); geplant wird nichts.
- Wirkt nur, wenn `--ui-testing` ebenfalls gesetzt ist; der Store bleibt dadurch In-Memory. In einem Release-Bau liest der
  Produktpfad das Argument nicht aus.

### Mitteilung von außen (`sim.sh test-proof`)

- `LOOSEENDS_PUSH=scripts/fixtures/due-reminder.apns ./scripts/sim.sh test-proof DueNotificationTapTests`: vor `xcodebuild`
  wird `TEST_RUNNER_LOOSEENDS_PUSH_FEED=1` gesetzt (xcodebuild reicht es ohne Präfix an den Testlauf weiter) und eine
  Hintergrundschleife gestartet, die die Datei alle 5 s per `simctl push <sim> com.henning.looseends` einspielt. Nach dem Lauf
  wird die Schleife beendet.
- Ohne `LOOSEENDS_PUSH` ändert sich an `test-proof` nichts. Der UI-Test überspringt sich ohne `LOOSEENDS_PUSH_FEED`
  (`XCTSkip`), also auch in der CI.

## Test Plan

### Automated Tests (TDD RED zuerst)

`LooseEndsUITests/DueNotificationTapTests.swift`, Start mit `--ui-testing --ui-testing-notifications`, Muster
`CalendarTargetTests` (echter Systemdienst im UI-Test):

- `testTapBannerFromHomeOpensApp`: Der Test beantwortet den Erlaubnisdialog in SpringBoard, geht auf Home
  (`XCUIDevice.shared.press(.home)`), wartet auf das eingespielte Banner und tippt es, erwartet `.runningForeground`,
  `captureButton` und dass die App 5 s später noch läuft. **RED vor dem Fix:** die App stürzt ab. **GRÜN nach dem Fix.**
- `testBannerWhileAppIsOpenKeepsAppAlive`: Die App bleibt im Vordergrund, das eingespielte Banner trifft bei geöffneter App
  ein (`willPresent`); erwartet, dass die App danach `runningForeground` ist und `captureButton` bedienbar bleibt.

Die Mitteilung kommt per `simctl push` von außen (siehe Lösung: `add` aus der App scheitert im Simulator). Deshalb laufen die
Tests nur über `LOOSEENDS_PUSH=… sim.sh test-proof` und überspringen sich in der CI; der Beleg ist der lokale Simulatorlauf,
rot vor und grün nach dem Fix. Banner-Timing ist die Hauptquelle möglicher Unruhe; deshalb großzügige Timeouts, Einspielen
alle 5 s und kein harter Sleep.

Bestehende Unit-Tests zu `DueReminders` (Speichern-Logik der Aktionen) bleiben unverändert und grün.

### Abnahme (Stufen)

1. **Tests:** `LOOSEENDS_PUSH=scripts/fixtures/due-reminder.apns ./scripts/sim.sh test-proof DueNotificationTapTests` (RED-Lauf auf main-Stand mit dem Absturz, GRÜN-Lauf
   nach dem Fix) und voller Unit-Lauf `./scripts/sim.sh unit` grün.
2. **Simulator:** `./scripts/sim.sh build`, `launch`; Mitteilung einspielen und antippen (UI-Test belegt den Ablauf), Screenshot
   angesehen.
3. **Gerät (Pflicht, `LooseEnds/Notifications/` steht auf der Geräteliste):** Erst wenn Henning wörtlich „jetzt ist ein Test
   möglich“ geschrieben hat; vorher wird nichts auf einem seiner Geräte gestartet, auch nichts Lesendes. Dann Prüfbau
   (`generate`, `device-build` auf genau dem Stand) und Hennings Beobachtung: fällige Mitteilung antippen, App öffnet ohne
   Absturz.

## Acceptance Criteria

- **AC-1 Körper-Tipp:** Given die App ist geschlossen oder im Hintergrund und eine Fälligkeits-Mitteilung (Kategorie `DUE`)
  liegt vor / When der Nutzer den Mitteilungskörper antippt / Then öffnet sich die App ohne Absturz (`runningForeground`) und der
  Erfassungsknopf ist bedienbar.
- **AC-2 Vordergrund:** Given die App ist geöffnet / When eine Fälligkeits-Mitteilung eintrifft / Then erscheint sie als Banner
  ohne Absturz und die App bleibt bedienbar.
- **AC-3 Aktionsknöpfe:** Given eine Fälligkeits-Mitteilung / When der Nutzer „Erledigt“, „Als nächstes“ oder „Morgen“ wählt /
  Then läuft die Aktion durch dieselbe Rückruf-Methode wie AC-1; die Speichern-Logik ist durch die bestehenden
  `DueReminders`-Unit-Tests belegt, und der Systemabschluss wird erst **nach** `save()` auf dem Hauptthread aufgerufen (auch bei
  frühem Rücksprung in `apply`). Die Knöpfe selbst sind im UI-Test nicht bedienbar (Langdruck am Banner); der Körper-Tipp belegt
  den gemeinsamen Codeweg.
- **AC-4 Schalter:** Given ein Start ohne `--ui-testing-notifications` (insbesondere Release/TestFlight) / When die App läuft /
  Then bleibt `suppressed` unter UI-Tests wirksam; nur `--ui-testing --ui-testing-notifications` setzt den Delegate im UI-Test.
  Der App-Code plant in keinem Fall eine Test-Mitteilung.
- **AC-5 RED vor dem Fix:** Given der neue UI-Test `DueNotificationTapTests` mit eingespielter Mitteilung (`LOOSEENDS_PUSH`) /
  When er ohne den Fix läuft / Then stürzt die App ab und der Test schlägt fehl (Protokoll mit dem Absturz); nach dem Fix
  besteht er. Ohne `LOOSEENDS_PUSH_FEED` (CI) überspringt er sich.
- **AC-6 Nichts sonst:** Diff berührt nur die genannten Dateien; `test-proof` ohne `LOOSEENDS_PUSH` verhält sich wie vorher; keine Änderung an Info.plist, Entitlements, AppStorage,
  Modell, `DueReminders`; alle bestehenden Unit- und UI-Tests grün.
- **AC-7 Gerät:** Nach Hennings ausdrücklicher Freigabe bestätigt der Prüfbau auf dem iPhone, dass das Antippen einer fälligen
  Mitteilung die App ohne Absturz öffnet; Henning bestätigt es nach Auslieferung im Alltag. #295 wird erst danach
  geschlossen.

## Dependencies

| Komponente | Beschreibung |
|---|---|
| `UserNotifications` | Delegate-Protokoll, Rückruf-Varianten |
| `DueReminders` (`Shared/Notifications/`) | reine Regeln, unverändert |
| `ModelContainer.mainContext` | Speicherziel von `apply` |

Keine neue Abhängigkeit.

## Risiken

- **UI-Test-Timing (mittel):** Das eingespielte Banner kommt erst, wenn die Erlaubnis erteilt ist. Gegenmittel: Einspielen alle
  5 s, großzügige Timeouts, Warten auf Bedingungen statt fester Pausen.
- **Kein CI-Schutz (mittel):** Die CI überspringt den Test; ein späterer Rückfall auf die async-Varianten fiele dort nicht auf.
  Der Beleg ist der lokale Lauf. Ein Mitteilungstest in der CI ist nicht möglich, solange der Simulator `add` ablehnt.
- **Sendable-Signatur im iOS-27-SDK:** Ob der Abschluss `@Sendable` ist, zeigt erst der Build; Anpassung ist lokal.
- **Schalter im Produktcode:** Hebt nur die Stille auf, plant nichts; greift nur zusammen mit `--ui-testing` (AC-4).
- **Der Simulator ersetzt das iPhone nicht:** Ob das Gerät genauso abstürzt, ist durch den gleichen Absturzstapel und Hennings
  Beschreibung sehr wahrscheinlich, bewiesen wird es erst in Stufe 3.

## Alternativen

- **Isolierte Konformität `@MainActor UNUserNotificationCenterDelegate` mit async-Methoden (Swift 6.2):** kürzer, aber nicht
  belegt, dass der vom Compiler erzeugte Thunk den Systemabschluss dann auf dem Hauptthread ruft; DTS nennt die
  Rückruf-Variante als zuverlässigen Weg. Verworfen, bleibt Rückfallweg, falls die Rückruf-Variante in iOS 27 gestrichen würde.
  Kippt keine ADR.
- **Nur die Aktionsknöpfe auswerten, Körper-Tipp nicht behandeln:** löst den Absturz nicht, weil das System `didReceive` für jeden
  Tipp ruft, sobald ein Delegate gesetzt ist.
- **`Task { @MainActor in … }` in der nonisolated async-Methode ohne Warten:** verworfen. Der Abschluss käme sofort, noch vor
  `save()`; die App kann im Hintergrund suspendiert werden, bevor das Speichern läuft.
- **Delegate ganz entfernen:** würde die drei Aktionsknöpfe und die Anzeige im Vordergrund abschaffen; widerspricht dem
  bestehenden Funktionsumfang aus #9.

- **Test-Mitteilung aus der App planen (ursprünglicher Testplan):** CI-tauglich gedacht, scheitert aber im iOS-27-Simulator an
  `UNErrorDomain 2003` (siehe Lösung). Verworfen am 2026-10-10.
- **Unit-Test, der prüft, dass der Abschluss auf dem Hauptthread kommt:** liefe in der CI, belegt aber nicht den Absturz auf dem
  Weg des Nutzers. Nicht Teil dieses Tickets.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: reine Fehlerbehebung in einer Klasse, keine Architekturentscheidung

## Definition of Done

- AC-1 bis AC-7 erfüllt; `DueNotificationTapTests` zuerst rot (Absturz im Protokoll), dann grün; alle bestehenden Tests grün.
- `Repro295Tests.swift` gelöscht, nie committet.
- Simulator-Durchlauf (Mitteilung antippen, App offen) als Screenshot belegt und angesehen.
- Geräteabnahme nur nach Hennings wörtlichem „jetzt ist ein Test möglich“; danach Auslieferung und Bestätigung im Alltag.
- `docs/project/04-stand.md` nennt den Fix; der PR verweist mit `Refs #295` (nicht `Closes`), #295 wird erst nach Hennings Bestätigung von Hand geschlossen.
- Abschlussbericht ohne Git-Vokabular: Das Antippen einer „fällig“-Mitteilung öffnet die App jetzt ohne Absturz; Henning soll
  eine fällige Mitteilung antippen und melden, ob die App sauber aufgeht.

## Changelog

- 2026-10-10 (nach `override`): Test-Mitteilung aus dem App-Code gestrichen, weil `add` im iOS-27-Simulator mit
  `UNErrorDomain 2003` scheitert; Mitteilung kommt per `simctl push` aus `sim.sh test-proof` (`LOOSEENDS_PUSH`), UI-Test
  überspringt sich in der CI.
- 2026-10-10: Initiale Spec für #295: Rückruf-Varianten der Delegate-Methoden statt async, Test-Mitteilung unter
  `--ui-testing-notifications`, UI-Test `DueNotificationTapTests`.
