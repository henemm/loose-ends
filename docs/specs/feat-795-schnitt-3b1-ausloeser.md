---
entity_id: feat-795-schnitt-3b1-ausloeser
type: feature
created: 2026-11-12
updated: 2026-11-12
status: draft
workflow: feat-795-s3b-ausloeser
---

# Spec: Auslöser für den ClaudeSync-Durchgang, Schnitt S3b-1 (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S3b-1 (erster Teil von S3b; die acht Schnitte des Issues sind S1, S1b, S2a, S2b, S3a, S3b, S4, S5); das Issue bleibt offen (`Refs #795`, nie `Closes #795`): S3b-2 (Debug-Weg, lokaler Dienst, Nachweis A/B mit zwei Simulatoren) und S5 (Weckruf, Hintergrund-Auffrischen) folgen.
Analyse: `docs/context/feat-795-s3b-ausloeser.md` (Abschnitte „Analysis“, „Schnitt“, „Technical Approach“, „Alternativen“, „Recherche“; verbindlich).
Vorgänger: S3a (`docs/specs/feat-795-schnitt-3a-claude-sync.md`, der Durchgang `ClaudeSync`, PR #911), S2b (`docs/specs/feat-795-schnitt-2b-device-identity.md`, `DeviceIdentity`, `AccountState.withSession`).
Es sind **drei Codedateien**: der Auslöser, seine Verdrahtung in `LooseEndsApp` und die Tests; dazu eine Zeile Doku in `CLAUDE.md`, die nicht zum Dateilimit zählt.

## Für den PO

Die App meldet sich jetzt von selbst beim Dienst für Claude: beim Start, beim Zurückkehren in die App und kurz nach Änderungen an deinen Aufgaben. Dabei zeigt sie dem Dienst ihre Aufgabenliste und holt offene Aufträge von Claude ab. Das geschieht nur, wenn ein Konto verbunden ist.

In der App aus dem Store ist das Konto weiterhin ausgeschaltet; du merkst nichts davon, und es geht nichts ins Netz. Du musst nichts entscheiden und nichts tun.

## Purpose

S3a hat den Durchgang `ClaudeSync` gebaut (`sendTranscript()`, `pullOrders()`), aber nichts ruft ihn auf. Dieser Schnitt liefert die Anlässe: `ClaudeSyncTrigger` (neu, `LooseEnds/Claude/ClaudeSyncTrigger.swift`), `@MainActor final class ClaudeSyncTrigger`, nach dem Muster von `WidgetReload` (#883): prozessweit, nicht an ein Fenster gebunden, `start()` einmal in `LooseEndsApp.init`.

**Eingereichte Aktionen.** `init(send:pull:debounce:)` mit `send: (@MainActor () async -> Void)?`, `pull: (@MainActor () async -> Void)?` und `debounce: Duration = .seconds(2)`. Unter Unit- und UI-Tests (`ModelContainerFactory.isRunningTests || ModelContainerFactory.isUITesting`) sind fehlende Closures leere Aktionen (wie `WidgetReload.suppressed`): ein Test erreicht nie ein echtes `ClaudeSync`, es sei denn, er reicht eine eigene Closure ein. Außerhalb von Tests ohne Closure gibt es keinen Standard: der Trigger wird in der App nur über die Fabrik unten gebaut, die beide Closures einreicht.

**Anlässe und Reaktion.**

| Anlass | Reaktion |
|---|---|
| `start()` (einmal, beim Start des Prozesses) | sofort einmal „senden, dann holen“ |
| Die App wird aktiv: `UIApplication.didBecomeActiveNotification` (iOS, iPadOS) bzw. `NSApplication.didBecomeActiveNotification` (macOS), prozessweit | „senden, dann holen“ |
| `ModelContext.didSave` | nur senden, entprellt (2 s nach der letzten Änderung) |
| Fertiger CloudKit-Import (`NSPersistentCloudKitContainer.eventChangedNotification`, Regel `WidgetReload.isFinishedImport`, nicht kopiert) | nur senden, entprellt wie oben |
| Unfertiger oder fehlgeschlagener Import, jedes andere Ereignis | nichts |

**Holen hängt nie an `didSave` und nie am Import.** `ClaudeSync.pullOrders()` führt Aufträge aus und speichert; hinge das Holen am Speichern, entstünde eine Rückkopplung (Ausführen → `didSave` → Holen → …). So ist der Ablauf gewollt: ausgeführte Aufträge speichern → `didSave` → entprellte Abschrift → Claude sieht das Ergebnis.

**Reihenfolge „senden, dann holen“.** Beide Aktionen laufen nacheinander in einer `Task` des Main Actors (`await send()`, dann `await pull()`); das Holen beginnt erst, wenn das Senden beendet ist, gleich mit welchem Ausgang. Die Rückgabewerte (`Ending`) dienen nur dem Log der Fabrik (nur Fallnamen); der Trigger entscheidet nichts danach.

**Entprellung.** Wie `WidgetReload.reloadSoon`: ein neuer Anlass bricht das noch wartende Senden ab und startet es neu (`cancel` + neue `Task` mit `Task.sleep(for: debounce)`), so löst eine Folge von Speichervorgängen genau eine Sendung aus, `debounce` nach dem letzten. Ein bereits laufendes Senden wird nicht abgebrochen (Abbruch mitten in der Anfrage würde `stopped(.cancelled)` und eine halbe Abschrift bedeuten); der Abbruch betrifft nur das Warten.

**Keine Sendung geht verloren.** `ClaudeSync` hat je Art eine Wiedereintrittssperre (`busy`, S3a AC-16); eine Sendung, die dort aufliefe, wäre verloren, und eine Änderung während eines laufenden Sendens käme erst mit der nächsten Änderung beim Dienst an. Der Trigger reiht seine Sendungen deshalb selbst: läuft sein `send` noch, merkt ein weiterer Anlass (entprellte Sendung, Start, Vordergrund) nur „noch einmal senden“ vor (ein Merker, kein Stapel); endet das laufende `send`, folgt genau eine weitere Sendung, wenn vorgemerkt war. So ruft der Trigger `sendTranscript()` nie überlappend auf, und die letzte Änderung erreicht den Dienst immer. Kommt Start oder Vordergrund während eines laufenden Sendens, merkt der Anlass ebenso nur vor; sein Holen beginnt erst, wenn das Senden samt vorgemerkter Wiederholung beendet ist („senden, dann holen“ gilt also auch dann). Beim Holen genügt `busy`: ein zweites Holen während eines laufenden findet nichts, was das erste nicht auch holt. `ClaudeSync` bleibt unverändert.

**Kein `scenePhase`.** `scenePhase` im App-Körper ist ein Gesamtwert über alle Szenen und fensterbezogen; auf dem Mac läuft die App mit geschlossenem Fenster im Menüband, dort ist es für den Lebenszyklus unzuverlässig. Die Systembenachrichtigung der Anwendung ist prozessweit und das robuste Signal. Quellen: [Apple, ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase.md), [Jesse Squires 2024, SwiftUI scene phase](https://www.jessesquires.com/blog/2024/06/29/swiftui-scene-phase/), [Swift Forums, handling application did become active](https://forums.swift.org/t/best-practice-on-handling-application-did-become-active/45766). Zum reinen Menüband-Fall (Mac ohne Fenster) gibt es keine Quelle: er wird mit S3b-2 im Mac-Bau geprüft und bleibt bis S5 eine bekannte Grenze.

**Verdrahtung.** Eine statische Fabrik `ClaudeSyncTrigger.forApp(account: AccountState?, container: ModelContainer) -> ClaudeSyncTrigger?` ist die einzige Stelle der Regel „nur mit Konto“: ohne `account` gibt sie `nil` zurück und baut nichts (kein `ClaudeSync`, kein Schlüsselbund-Zugriff, kein Beobachter); mit Konto baut sie `ClaudeSync(account:container:device: { try DeviceIdentity().current() }, now: { Date() }, calendar: .current)` und einen Trigger, dessen `send` `{ _ = await sync.sendTranscript() }` und dessen `pull` `{ _ = await sync.pullOrders() }` (mit Log der `Ending`-Fallnamen) sind. Die Fabrik hat einen Parameter `silent: Bool` mit dem Standard `ModelContainerFactory.isRunningTests || ModelContainerFactory.isUITesting`. **Unter Unit- und UI-Tests** (Standard) reicht die Fabrik keine Closures ein (`send: nil`, `pull: nil`), der Trigger ist damit stumm (leere Aktionen) und ruft das gebaute `ClaudeSync` nie auf; so bleibt der Satz oben („ein Test erreicht nie ein echtes `ClaudeSync`“) auch für die Fabrik wahr. Die Fabrik liegt als reine Funktion in der Trigger-Datei, damit die Regel getestet werden kann, ohne `LooseEndsApp` zu starten. In `LooseEndsApp.init` steht nach `account = AccountWiring.forApp(...)` die Zeile `claudeSync = ClaudeSyncTrigger.forApp(account: account, container: container)` und `claudeSync?.start()`; der Trigger ist eine Eigenschaft der App (`let claudeSync: ClaudeSyncTrigger?`), damit er mit dem Prozess lebt.

**Wer ein Konto hat.** Jeder Store-Bau hat `LEAccountEnabled` aus (`project.yml`), also `account == nil`, kein Trigger, keine Netzaufrufe. Unter `--ui-testing` ist das Konto an (`UITestTransport`, `InMemorySessionStore`): der Trigger wird gebaut und gestartet, ist aber stumm (leere Aktionen). Ohne Sitzung gibt `account.withSession` `nil`, und `ClaudeSync` sendet nichts (S3a AC-1).

**Log.** `Logger(subsystem: "com.henning.looseends", category: "claude-sync")`; nur Fallnamen (`Ending`), nie Token, Gerätekennung, Auftrags- oder Aufgabentext. Kein `try?`, kein `print`.

**Regeln vor Modell:** reine Ablauflogik ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR; ADR-21 (Dienst für Claude, Weg B) bleibt unverändert und wird umgesetzt, ebenso der Vertrag „Wege der App“ (`docs/reference/claude-abschrift-vertrag.md`: 429 beendet den Durchgang, Mengengrenze am nginx). Keine neue Abhängigkeit, kein Schema, keine Berechtigung.

- **Rationale:** Die Anlässe sind eine eigene Klasse mit eingereichten Aktionen, damit jede Zeile der Anlasstabelle ohne Netz, Konto und Schlüsselbund gezählt werden kann (Muster `WidgetReload`, #883). Prozessweite Systembenachrichtigungen statt `scenePhase`, weil die App auf dem Mac ohne Fenster läuft. Die Entprellung von 2 s und die Obergrenzen aus S3a (15 Aufträge, 429 beendet) halten die nginx-Grenze (10 r/s, Stoß 40).

## Source

- **File:** `LooseEnds/Claude/ClaudeSyncTrigger.swift` (neu)
- **Identifier:** `ClaudeSyncTrigger`, `init(send:pull:debounce:)`, `start()`, `handle(_ event: SyncStatus.Event)`, `ClaudeSyncTrigger.forApp(account:container:)`; benutzt `WidgetReload.isFinishedImport`, `ClaudeSync`, `DeviceIdentity`, `AccountState`

**Dateien:** `LooseEnds/Claude/ClaudeSyncTrigger.swift` (neu), `LooseEnds/App/LooseEndsApp.swift` (geändert), `LooseEndsTests/ClaudeSyncTriggerTests.swift` (neu).
**Unberührt:** `ClaudeSync.swift`, `DeviceIdentity.swift`, `AccountState.swift`, `AccountWiring.swift`, `WidgetReload.swift`, `LooseEnds/Notifications/`, `Shared/`, `server/`, `project.yml`, jede `Info.plist`, Entitlements, alle Views.

### Schnittstelle und Festlegungen

- **`start()` ist idempotent:** ein zweiter Aufruf registriert keine Beobachter neu und löst keinen zweiten Start-Durchgang aus.
- **Beobachter prozessweit** über `NotificationCenter.default.addObserver(forName:object:nil, queue: .main)`, mit `MainActor.assumeIsolated` wie in `WidgetReload`; `[weak self]`.
- **Plattformname:** eine private Konstante wählt per `#if canImport(UIKit)` bzw. `#if canImport(AppKit)` den Namen der Benachrichtigung; es gibt keine Abhängigkeit von `scenePhase`.
- **Import-Regel wiederverwendet:** die Übersetzung `NSPersistentCloudKitContainer.Event` → `SyncStatus.Event` und die Prüfung `WidgetReload.isFinishedImport` werden aufgerufen, nicht dupliziert; reicht eine Übersetzungsfunktion nicht ohne Umbau von `WidgetReload`, bleibt `WidgetReload.swift` unberührt und der Trigger übersetzt in wenigen Zeilen selbst, ruft aber `WidgetReload.isFinishedImport` auf (die Regel steht nur dort).
- **Beobachter einmal:** Start und `didBecomeActive` fallen beim Kaltstart oft zusammen; beim Senden reiht der Trigger (AC-14), beim Holen fängt `ClaudeSync.busy` das Zusammentreffen ab (siehe oben).
- **Kein Warten, kein Timer, kein Polling** außer der Entprellung; weitere Anlässe kommen von außen (S5).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `ClaudeSync` (`LooseEnds/Claude/ClaudeSync.swift`, S3a, PR #911; muss vor S3b-1 auf main sein) | bestehend, unverändert |
| `DeviceIdentity().current()` (S2b) | bestehend, unverändert; in der Fabrik als Closure eingereicht |
| `AccountState`, `AccountWiring.forApp` (S2b, #615 S4c-1) | bestehend, unverändert |
| `WidgetReload.isFinishedImport`, `SyncStatus.Event` | bestehend, unverändert |
| `ModelContainerFactory.isRunningTests`, `.isUITesting` | bestehend |
| Downstream | S3b-2 (Debug-Weg, lokaler Dienst, A/B-Nachweis), S5 (Hintergrund-Auffrischen und Weckruf rufen denselben `pullOrders`), #625 (Store-Schalter `LEAccountEnabled`) |

## Acceptance Criteria

Jedes AC wird über einen benannten Test in `LooseEndsTests/ClaudeSyncTriggerTests.swift` belegt (XCTest, `@MainActor`; das QA-Gate zählt nur XCTest). Die Tests reichen gezählte Closures ein (sie protokollieren Aufrufe in einer Liste mit den Einträgen `send` und `pull`), posten Benachrichtigungen über `NotificationCenter.default` und warten mit einer kurzen Entprellung (50 ms) und einem begrenzten Warten auf die Bedingung (`XCTestExpectation` oder Abfrage mit Frist), nie mit festem langem Schlafen. Die vorhandenen Tests bleiben unverändert grün.

- **AC-1:** Start: GIVEN ein Trigger mit gezählten Closures WHEN `start()` gerufen wird THEN lief genau einmal `send` und danach genau einmal `pull`, in dieser Reihenfolge, und es folgt nichts weiter (Test `startSendsThenPullsOnce`).
- **AC-2:** Reihenfolge: GIVEN ein `send`, das erst nach einer Verzögerung endet WHEN `start()` gerufen wird THEN beginnt `pull` erst nach dem Ende von `send` (Test `pullWaitsForSendToFinish`).
- **AC-3:** `start()` einmal: GIVEN ein gestarteter Trigger WHEN `start()` ein zweites Mal gerufen wird und danach eine Aktivierung gepostet wird THEN ist die Zahl der Aufrufe die eines einfachen Starts plus genau einer Aktivierung, nicht doppelt (Test `secondStartChangesNothing`).
- **AC-4:** Vordergrund: GIVEN ein gestarteter Trigger WHEN die Benachrichtigung `didBecomeActive` der Plattform gepostet wird THEN lief nach dem Start-Durchgang einmal zusätzlich `send`, dann `pull` (Test `becomingActiveSendsThenPulls`).
- **AC-5:** Speichern entprellt: GIVEN ein gestarteter Trigger und seine Aufrufe des Starts abgewartet WHEN `ModelContext.didSave` fünfmal in schneller Folge gepostet wird THEN lief nach der Entprellung genau einmal `send` und nie `pull` (Test `savesAreDebouncedToOneSendAndNeverPull`).
- **AC-6:** Speichern wartet: GIVEN dieselbe Lage WHEN `didSave` gepostet wird THEN lief `send` nicht sofort, sondern erst nach `debounce`, und ein weiteres `didSave` innerhalb der Frist verschiebt es (Test `saveSendsOnlyAfterTheDebounce`).
- **AC-7:** Import: GIVEN ein gestarteter Trigger WHEN `handle(_:)` ein fertiges, fehlerfreies Importereignis erhält THEN lief nach der Entprellung genau einmal `send` und nie `pull`; bei einem unfertigen (`endDate == nil`), einem fehlgeschlagenen (`errorMessage != nil`) und einem Export-Ereignis lief nichts (Test `onlyAFinishedImportSends`, Argumente je Ereignis).
- **AC-8:** Ohne Start stumm: GIVEN ein Trigger, dessen `start()` nie gerufen wurde WHEN `didBecomeActive` und `didSave` gepostet werden THEN lief weder `send` noch `pull` (Test `withoutStartNothingReacts`).
- **AC-9:** Holen nie an Speichern und Import: GIVEN ein gestarteter Trigger WHEN `didSave` und ein fertiger Import in beliebiger Folge eintreffen THEN ist die Zahl der `pull`-Aufrufe nach dem Start-Durchgang unverändert (Test `pullNeverFollowsSaveOrImport`).
- **AC-10:** Stumm unter Tests: GIVEN ein Trigger ohne eingereichte Closures unter Unit-Test WHEN `start()` gerufen wird und Benachrichtigungen gepostet werden THEN geschieht nichts und nichts stürzt (Test `withoutClosuresItIsSilentUnderTests`).
- **AC-11:** Verdrahtungsregel: GIVEN `ClaudeSyncTrigger.forApp(account: nil, container:)` THEN ist das Ergebnis `nil`; GIVEN ein `AccountState` im Status `signedOut` mit einem gezählten Transport und `silent: false` (die echten Closures über `ClaudeSync`) THEN ist das Ergebnis ein Trigger, und nach `start()`, einer Aktivierung und einem `didSave` samt Entprellung hat der Transport keine einzige Anfrage erhalten (ohne Sitzung gibt `withSession` `nil`); mit `silent: true` ebenso (Test `wiringRuleNeedsAnAccount`).
- **AC-12:** Nichts auf dem Netz ohne Konto und ohne Sitzung: GIVEN die Verdrahtung in `LooseEndsApp.init` WHEN der Quelltext durchsucht wird THEN steht `ClaudeSyncTrigger.forApp(` genau einmal in `LooseEnds/App/LooseEndsApp.swift`, `ClaudeSync(` kommt außerhalb von `ClaudeSyncTrigger.swift` und den Tests nicht vor, und `ClaudeSyncTrigger.swift` enthält weder `try?` noch `print(` (Quellsuche als Beleg im Abschlussbericht; kein Swift-Test).
- **AC-13:** Ganze Suite grün: GIVEN die ganze Unit-Suite WHEN sie läuft THEN ist sie grün, und die App startet unter `--ui-testing` im Simulator ohne Absturz, mit Trigger gebaut und gestartet und ohne Netzverkehr (maschineller Beleg `./scripts/sim.sh test-proof <Klasse>` einer bestehenden Smoke-Klasse; Beleg im Abschlussbericht).
- **AC-14:** Sendung während einer Sendung: GIVEN ein gestarteter Trigger, dessen `send` erst nach einer Verzögerung endet WHEN während dieses `send` dreimal `didSave` gepostet wird und die Entprellung abläuft THEN laufen nie zwei `send` gleichzeitig, und nach dem Ende des laufenden folgt genau ein weiteres `send`; wird statt `didSave` die Aktivierung gepostet, folgt ebenso genau ein weiteres `send` und erst danach `pull` (Test `saveDuringASendSendsOnceMoreAfterIt`).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/ClaudeSyncTrigger.swift` | CREATE | `ClaudeSyncTrigger`, Beobachter, Entprellung, `start()`, `handle`, Fabrik `forApp`; ≈ +90 |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | Eigenschaft `claudeSync`, Bau über `forApp` und `start()` nach `account`; ≈ +10 |
| `LooseEndsTests/ClaudeSyncTriggerTests.swift` | CREATE | gezählte Closures, Benachrichtigungen, Tests zu AC-1 bis AC-11 und AC-14; ≈ +130 |
| `CLAUDE.md` | MODIFY | Doku, zählt nicht zum Dateilimit: eine Zeile zu `ClaudeSyncTrigger` im Absatz `LooseEnds/Claude` |

### Estimated Changes

- **Dateien: 3** (zwei neu, eine geändert), innerhalb des Limits von 4 bis 5.
- **LoC: ≈ +230** (Code ≈ 100, Tests ≈ 130), innerhalb von ±250; keine Funktion über 50 Zeilen. Kein Anlass zur Rückfrage.
- Keine Permissions, keine `Info.plist`-Einträge, keine AppStorage-Keys, kein CloudKit-Schema, keine Audio-Dateien, keine Oberfläche, keine neue Abhängigkeit. `generate` muss laufen, weil zwei Dateien neu sind (CLAUDE.md, Build).
- **Seiteneffekte nach außen:** erstmals senden Apps mit Konto und Sitzung von selbst. Jeder Store-Bau hat `LEAccountEnabled` aus (`account == nil`), sendet also nichts; unter `--ui-testing` bleibt der Trigger stumm.
- **Parallele Arbeit:** vor dem PR `origin/main` und offene PRs auf Berührung von `LooseEnds/Claude/` und `LooseEndsApp.swift` prüfen; `CLAUDE.md` ist Hotspot.

## Risiken

- **Erste echte Netzaufrufe.** Bisher sendet die App nichts. Begrenzt dadurch, dass `LEAccountEnabled` in jedem Store-Bau aus ist (AC-11) und ohne Sitzung `withSession` nichts sendet (S3a AC-1). Der Durchlauf gegen den echten Dienst folgt in S3b-2.
- **Rückkopplung.** `pullOrders` speichert und löst damit `didSave` aus; weil das Holen nie an `didSave` hängt (AC-9), schließt sich keine Schleife; es folgt höchstens eine entprellte Abschrift.
- **Mengengrenze am nginx** (10 r/s, Stoß 40). Entprellung 2 s (AC-5), höchstens 15 Aufträge je Durchgang und 429 beendet (S3a); Start und Vordergrund kurz hintereinander fängt `busy` ab.
- **Mac ohne Fenster.** Die Aktivierung der App ist der einzige Vordergrund-Anlass; im Menüband ohne Aktivierung kommen Aufträge erst mit S5. Nicht belegt, siehe Known Limitations.
- **Verlorene Sendung bei `busy`.** Ausgeschlossen durch die eigene Reihung der Sendungen im Trigger (AC-14).
- **Belegkraft.** Die Tests zählen Aufrufe gegen Stellvertreter-Closures und echte Systembenachrichtigungen; dass die Kette bis zum Dienst schließt, belegt erst S3b-2 (Lehre aus #136: eine Attrappe beweist die Kette nicht).

## Test Plan

Unit-Tests (XCTest) in `LooseEndsTests/ClaudeSyncTriggerTests.swift`. Lauf: `./scripts/sim.sh sim-unit ClaudeSyncTriggerTests`, danach die ganze Suite `./scripts/sim.sh unit`.
**Keine neuen UI-Tests:** der Schnitt hat keine Oberfläche und ändert nichts Sichtbares; es gibt keinen Ablauf, den ein UI-Test bedienen könnte. Als Stufe-2-Beleg läuft eine bestehende Smoke-Klasse (AC-13).

| Test | AC |
|---|---|
| `startSendsThenPullsOnce` | AC-1 |
| `pullWaitsForSendToFinish` | AC-2 |
| `secondStartChangesNothing` | AC-3 |
| `becomingActiveSendsThenPulls` | AC-4 |
| `savesAreDebouncedToOneSendAndNeverPull` | AC-5 |
| `saveSendsOnlyAfterTheDebounce` | AC-6 |
| `onlyAFinishedImportSends` | AC-7 |
| `withoutStartNothingReacts` | AC-8 |
| `pullNeverFollowsSaveOrImport` | AC-9 |
| `withoutClosuresItIsSilentUnderTests` | AC-10 |
| `saveDuringASendSendsOnceMoreAfterIt` | AC-14 |
| `wiringRuleNeedsAnAccount` | AC-11 |
| Quellsuche (Verdrahtung, `try?`, `print(`) | AC-12 |
| ganze Suite, Smoke-Beleg | AC-13 |

- [ ] Test 1 (AC-1 bis AC-3): GIVEN gezählte Closures WHEN `start()` einmal und zweimal gerufen wird THEN senden dann holen, genau einmal, in dieser Reihenfolge.
- [ ] Test 2 (AC-4): GIVEN ein gestarteter Trigger WHEN die Aktivierung gepostet wird THEN senden dann holen.
- [ ] Test 3 (AC-5, AC-6, AC-9): GIVEN eine Folge von `didSave` und Importen WHEN die Entprellung abläuft THEN genau ein Senden, nie Holen.
- [ ] Test 4 (AC-7, AC-8, AC-10, AC-11): GIVEN unfertige Importe, fehlender Start, fehlende Closures, fehlendes Konto WHEN Ereignisse eintreffen THEN nichts, und die Fabrik gibt ohne Konto `nil`.
- [ ] Test 5 (AC-14): GIVEN ein langsames Senden WHEN währenddessen gespeichert wird THEN nie zwei Sendungen gleichzeitig, danach genau eine weitere.

**Ehrlich zur Belegkraft:** TDD-Reihenfolge: die Tests werden vor dem Code geschrieben (RED: Kompilierfehler, weil `ClaudeSyncTrigger` fehlt), dann der Code (GREEN). Die Tests belegen Anlässe, Reihenfolge, Entprellung und die Regel „nur mit Konto“. Ob die App unter echter Systemaktivierung tatsächlich einen Durchgang gegen den Dienst anstößt, belegen sie nicht; die Test-Benachrichtigung ist dieselbe wie die des Systems, aber ein Aktivieren der App durch das Betriebssystem wird nicht nachgespielt.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): eigener `ClaudeSyncTrigger` mit Systembenachrichtigungen** | siehe Purpose | prozessweit, auch Mac im Menüband; ohne Netz zählbar; Muster `WidgetReload` | eine weitere Klasse, Plattform-Unterscheidung für den Namen der Benachrichtigung | nichts; keine ADR |
| **B `scenePhase` im App-Körper** | `.onChange(of: scenePhase)` löst aus | weniger Code, keine Plattform-Unterscheidung | fensterbezogen, auf dem Mac im Menüband ohne Fenster unzuverlässig (Quellen im Abschnitt Purpose); der Wechsel in den Vordergrund ginge mit dem Fenster verloren | nichts; keine ADR; verworfen |
| **C Nur Attrappe** (`UITestTransport` antwortet 204, keine Anlässe nachgewiesen) | Verdrahtung ohne eigene Zähltests | weniger Tests | beweist die Kette nicht (Lehre aus #136), Rückkopplung und Entprellung blieben ungeprüft | die Regel „Der Durchlauf wird benutzt, nicht nur gebaut“ (CLAUDE.md); verworfen |
| **D Timer oder Polling** (alle n Sekunden senden und holen) | feste Takte statt Ereignisse | unabhängig von Systemsignalen, einfach | mehr Anfragen gegen die nginx-Grenze (10 r/s), Akku, Claude sähe Änderungen nie sofort; ein Takt auf dem Mac ohne Fenster ist eine Produktfrage und liefe dem Weckruf-Entwurf (S5) zuwider | der Weckruf-Entwurf in #795 (S5); verworfen für jetzt |
| **E Holen auch bei `didSave`** | ein Ereignis für beides | Aufträge schneller ausgeführt | Rückkopplung (Ausführen speichert, löst Holen aus); mehr Anfragen | nichts; verworfen |

## Out of Scope / Folgeschnitte

- **S3b-2** (eigener Schnitt, eigene Spec): Debug-Weg nur in `#if DEBUG` (Startargumente für lokalen Dienst und Sitzung ohne Apple-Anmeldung, Adresse `http://localhost:<port>`, nie `127.0.0.1`, wegen ATS), lokales Skript für Dienst und Aufbau von Konto, Sitzung und Auftrag, Nachweis A/B mit zwei Simulatoren (Abschrift von A im Dienst lesbar, Auftrag auf B als Revision „Claude“ ausgeführt, Ergebnis im Dienst); Änderungen an `AccountWiring.swift`, `AccountWiringTests.swift` und `server/scripts/`.
- **S5:** Hintergrund-Auffrischen (`LooseEnds/Notifications/BackgroundRefresh.swift`, Pfad der Geräteliste, Stufe 3) und Weckruf; der Mac im Menüband ohne Fenster.
- **#625:** Store-Schalter `LEAccountEnabled`.
- Anzeige des Zustands in der Oberfläche; Änderungen an `ClaudeSync.swift`, `DeviceIdentity.swift`, `AccountState.swift`, `WidgetReload.swift`, `server/`, Widgets, Watch, `project.yml`: keine.

## Abnahme

**Kein Pfad der Geräteliste berührt.** (`LooseEnds/Claude/`, `LooseEnds/App/` und `LooseEndsTests/` stehen nicht darin; kein `project.yml`, keine Entitlements, keine `Info.plist`.) Die Abnahme endet nach Stufe 2: Stufe 1 sind die Unit-Tests (neue und bestehende, `./scripts/sim.sh unit`), Stufe 2 der Beleg „App startet unter `--ui-testing` im Simulator ohne Absturz“ (`./scripts/sim.sh build`, `launch`, `screenshot` und der maschinelle Beleg `./scripts/sim.sh test-proof <Klasse>` einer bestehenden Smoke-Klasse). Sichtbar ändert sich nichts, und das wird im Abschlussbericht gesagt. Der Durchlauf bis zum echten Dienst ist S3b-2 vorbehalten; die Abnahme dieses Schnitts behauptet ihn nicht. Gerätepunkte gibt es in diesem Schnitt nicht.

## Definition of Done

- [ ] AC-1 bis AC-14 erfüllt, jeder über seinen benannten Test beziehungsweise Beleg; Tests vor dem Code geschrieben (RED belegt)
- [ ] `./scripts/sim.sh unit` grün (gesamte Suite), Build erfolgreich
- [ ] Abnahme: „Kein Pfad der Geräteliste berührt.“
- [ ] Stufe 2: App startet unter `--ui-testing` im Simulator ohne Absturz, Beleg liegt vor
- [ ] Kein Token, keine Gerätekennung, kein Auftrags- oder Aufgabentext in einer Logzeile; kein `try?`, kein `print(` (AC-12)
- [ ] Doku (keine Codedatei, zählt nicht zum Dateilimit): `CLAUDE.md` im Absatz `LooseEnds/Claude` um `ClaudeSyncTrigger` ergänzt (eine Zeile, Hotspot, vor dem PR gegen `origin/main` abgleichen)
- [ ] PR mit `Refs #795`, CI grün, Merge durch Claude; #795 kommentiert (Stand S3b-1, Folge S3b-2), Board-Karte aktuell, Memory geschrieben

## Known Limitations

- Der Trigger ist nur unit-getestet; unter `--ui-testing` ist er stumm. Dass die Kette App → Dienst → Auftrag → Ergebnis schließt, belegt erst der A/B-Nachweis in S3b-2. Eine Attrappe beweist die Kette nicht (Lehre aus #136).
- Ein Holen, das auf ein laufendes Holen trifft, endet mit `busy`; das laufende holt dieselben Aufträge, nichts geht verloren. Der Dienst hält immer die letzte vollständige Abschrift, die App sendet immer alle Aufgaben.
- Auf dem Mac mit geschlossenem Fenster (nur Menüband) ist `didBecomeActive` der einzige Vordergrund-Anlass; ob er dort in allen Lagen feuert, ist nicht belegt (keine Quelle). Aufträge können dort bis S5 (Weckruf) auf den nächsten Anlass warten.
- Ein kaputter Eintrag der Gerätekennung beendet jeden Durchgang mit `deviceIdentity` (Known Limitation aus S3a); der Trigger ändert daran nichts.
- AC-12 (Quellsuche) und AC-13 (Smoke-Beleg) sind Belege im Abschlussbericht, keine Swift-Tests.

## Changelog

- 2026-11-12: Initial spec created (Schnitt S3b-1)
- 2026-11-12: Eigene Reihung der Sendungen statt Verlust bei `busy` (AC-14)
- 2026-11-12: Validator-Runde 2: Anlass während des Sendens, `silent`-Parameter der Fabrik (AC-11)
