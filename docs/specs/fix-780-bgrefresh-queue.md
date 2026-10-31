---
entity_id: fix-780-bgrefresh-queue
type: bugfix
created: 2026-10-31
updated: 2026-10-31
status: draft
workflow: fix-780-bgrefresh-queue
---

# Spec: #780 — Hintergrund-Auffrischung stürzt beim Start durch iOS ab

## Approval

- [ ] Approved (Henning)

## Purpose

Die tägliche Hintergrund-Auffrischung (#553) soll den Mitteilungsplan ohne App-Start erneuern. Sobald iOS sie startet, stürzt
die App ab; der Plan wird dadurch ohne App-Start nie erneuert. Der Absturz-Abruf (#773, Lauf 41216707696) fand zwei Berichte:
Build 98 (2026-10-21) und Build 126 = 1.0 (2026-10-31), beide `EXC_BREAKPOINT` in `_dispatch_assert_queue_fail + 120` unter
`closure #1 in static BackgroundRefresh.register(_:)`.

**Hat es bisher funktioniert?** Nein. Die Datei `LooseEnds/Notifications/BackgroundRefresh.swift` stammt aus #553 und ist seither
unverändert in der Frage der Queue; der Absturz steckt in jedem Bau seit #553. Es ist keine Verschlechterung, sondern ein
Fehler von Anfang an.

### Root Cause (belegt im Nachbau)

`BackgroundRefresh` ist `@MainActor` (`BackgroundRefresh.swift:11`). Der Block, den `register(forTaskWithIdentifier:using: nil)`
(Zeile 20) bekommt, ist im SDK nicht `@Sendable` markiert; die Closure erbt damit die Bindung an den Main Actor. Das System ruft
sie laut Header auf „a default background queue“ (`using: nil`). Die Swift-6-Laufzeitprüfung bricht ab, bevor der innere
`Task { @MainActor in … }` (Zeile 23) überhaupt läuft.

Dasselbe Muster steckt in zwei weiteren Closures derselben Datei, ohne dass dazu schon ein Bericht vorliegt:

- `task.expirationHandler = { … }` (Zeile 22): Queue vom System nicht dokumentiert.
- Der Handler von `submitTaskRequest` (Zeile 42): laut Header „called on an arbitrary queue“. #580 hat dafür schon den Logger als
  lokale Konstante herausgezogen (Zeile 41), die Closure selbst aber nicht `@Sendable` gemacht.

### Nachbau (2026-10-31)

Der Simulator scheidet aus: `BGTaskScheduler is not available on this platform.` (BGTaskSchedulerErrorDomain Code=1);
`_simulateLaunchForTaskWithIdentifier:` startet dort nichts. Ein reiner Swift-Nachbau stürzt ebenfalls nicht ab, weil Swift die
Laufzeitprüfung nur bei Blöcken aus importierten Objective-C-Schnittstellen einsetzt. Deshalb:
`docs/artifacts/fix-780-bgrefresh-queue/repro/` (`main.swift`, `FakeScheduler.h/.m`, `run.sh`) bildet die Schnittstelle
`registerForTaskWithIdentifier:usingQueue:launchHandler:` in Objective-C nach, Swift 6, `@MainActor enum` registriert den Handler.
`bash run.sh` baut und fährt drei Fälle:

| Fall | Ergebnis |
|---|---|
| `using: nil`, Closure erbt `@MainActor` (heutiger Code) | `Trace/BPT trap: 5`, exit 133; im Debugger `EXC_BREAKPOINT` in `_dispatch_assert_queue_fail + 120` (identisch mit dem Gerätebericht) |
| A: `using: .main` | läuft durch, exit 0 |
| B: `using: nil`, Closure ausdrücklich `@Sendable` | läuft durch, exit 0 |

Variante B steht im Nachbau bereits drin (`registerSendable()` in `main.swift`, dritter Fall in `run.sh`); sie wird mit dem Fix
committet und gilt als Beleg.

### Recherche (zuerst, 2026-10-31)

- Dasselbe Bild bei anderen Entwicklern: `EXC_BREAKPOINT` auf `com.apple.BGTaskScheduler` über `_dispatch_assert_queue_fail` →
  `_swift_task_checkIsolatedSwift`, Auslöser `using: nil` mit einem Handler, der Main-Actor-Bindung erbt; Abhilfe: Queue und
  Isolation in Einklang bringen.
  - https://hackernoon.com/swift-6-gave-me-zero-warnings-but-two-objective-c-callbacks-still-crashed-at-runtime
  - https://developer.apple.com/forums/thread/774517
- Apple-Doku: `nil` bedeutet „default background queue“; jede Kennung nur einmal registrieren.
  https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/register(fortaskwithidentifier:using:launchhandler:)
- SDK-Header: `BackgroundTasks.framework/Headers/BGTaskScheduler.h:87–93` und `:136–143`, `BGTask.h:42` (keine Sendable-Markierung).

### Lösung (Weg B)

Alle drei System-Closures werden ausdrücklich `@Sendable`; die Queue bleibt `nil`. Eine `@Sendable`-Closure erbt keine
Actor-Bindung und läuft damit auf jeder Queue, die das System wählt. Der Sprung auf den Main Actor geschieht erst im inneren
`Task { @MainActor in … }`, wie bisher.

Damit der Handler testbar wird, wird sein Rumpf aus `register` herausgezogen (Naht `RefreshTask`, siehe Implementation Details).
Produktverhalten bleibt gleich: erst `reschedule()`, dann neue Anfrage, dann `setTaskCompleted(success: true)`; Ablauf des
Zeitfensters beendet die Aufgabe mit `success: false`.

Regelweg-Vermerk (Regeln vor Modell): Kein Modell beteiligt. Es geht um die Queue-Zuordnung eines Systemrückrufs; die Frage
„ohne Modell geht es nicht, weil …“ stellt sich nicht.

## Source

- **Geändert:** `LooseEnds/Notifications/BackgroundRefresh.swift` (`BackgroundRefresh.register(_:)`, `BackgroundRefresh.schedule()`, neu `BackgroundRefresh.launchHandler(reschedule:)`, `RefreshTask`)
- **Neu:** `LooseEndsTests/BackgroundRefreshTests.swift`
- **Geändert:** `CLAUDE.md` (ein Halbsatz bei `BackgroundRefresh`)
- **Ergänzt (Beleg):** `docs/artifacts/fix-780-bgrefresh-queue/repro/` (Variante B, schon vorhanden, wird mit eingecheckt)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Notifications/BackgroundRefresh.swift` | MODIFY | `launchHandler`, `expirationHandler` und `submitTaskRequest`-Handler ausdrücklich `@Sendable`; Handler-Rumpf als `nonisolated static func launchHandler(reschedule:)` herausgezogen; Protokoll `RefreshTask`, `BGTask` erfüllt es; `RefreshHandle` hält `any RefreshTask` |
| `LooseEndsTests/BackgroundRefreshTests.swift` | CREATE | zwei Tests mit Fake-Task von einer Hintergrund-Queue, siehe Test Plan |
| `CLAUDE.md` | MODIFY | Halbsatz bei `BackgroundRefresh` unter „Where things live“ |
| `docs/artifacts/fix-780-bgrefresh-queue/repro/` | ADD | Nachbau inklusive Variante B (Beleg, kein Produktcode): nur die vier Quelldateien `main.swift`, `FakeScheduler.h`, `FakeScheduler.m`, `run.sh` (zusammen ca. 60 Zeilen); die Bauprodukte `FakeScheduler.o` und `repro` werden nicht eingecheckt |

Geschätzt **+~120 / −~12 LoC** im Produkt- und Testbaum (Produktcode ca. +40/−12, Test ca. +75, CLAUDE.md +1), 3 Dateien;
dazu der Nachbau als Beleg (4 Dateien, ca. +60, kein Produktcode, schon geschrieben). Innerhalb der Scoping-Limits (4–5
Dateien, ±250 LoC) für Produkt und Tests; mit dem Beleg ca. +180 LoC. Jede Funktion ≤ 50 LoC.

**Aufrufer bleiben unverändert** (Zeilen geprüft): `LooseEnds/App/LooseEndsApp.swift:47` ruft `BackgroundRefresh.register(notifications)`,
`LooseEnds/App/ContentView.swift:130` ruft `BackgroundRefresh.schedule()`. Die öffentlichen Signaturen von `register` und
`schedule` ändern sich nicht.

**Geräteliste berührt:** `LooseEnds/Notifications/`. Stufe 3 ist Pflicht, läuft über TestFlight (siehe Abnahme).

**Side-Effects:** Keine Änderung an Info.plist, Entitlements, `project.yml`, AppStorage-Schlüsseln, Datenmodell, Texten oder
Audio-Dateien. Die Kennung `com.henning.looseends.refresh` und der Zeitabstand (`earliest`) bleiben. Die neue Testdatei ist
iOS-only; `project.yml` nimmt Testdateien über das Verzeichnis auf, nach der Änderung läuft `./scripts/sim.sh generate`.

### Nicht in diesem Ticket

- Zeitplan, Kennung oder Verhalten der Auffrischung (`earliest`, `reschedule()`).
- Andere Aufrufer oder weitere Hintergrundaufgaben.
- Die Mitteilungs-Delegate (#295 ist erledigt, andere Datei).
- Ein Wegwerf-Test, der den Systemscheduler anspricht (im Simulator nicht vorhanden).

## Implementation Details

### Naht `RefreshTask`

`BGTask` hat keinen öffentlichen Initialisierer; der Simulator hat keinen Scheduler. Der Handler arbeitet deshalb gegen ein
Protokoll, das `BGTask` bereits erfüllt:

```swift
protocol RefreshTask: AnyObject {
    var expirationHandler: (() -> Void)? { get set }
    func setTaskCompleted(success: Bool)
}
extension BGTask: RefreshTask {}
```

`RefreshHandle` (Zeile 51–54) hält statt `BGTask` ein `any RefreshTask`; es bleibt `@unchecked Sendable` und trägt den Task
über die Grenze auf den Main Actor. Ob `RefreshTask` `@Sendable`-Sprünge ohne weitere Annotation übersteht, zeigt der erste
Bau mit Swift 6 (strikte Nebenläufigkeit); die Signatur wird dann lokal angepasst.

### Handler als `@Sendable`

```swift
nonisolated static func launchHandler(
    reschedule: @escaping @MainActor @Sendable () async -> Void
) -> @Sendable (any RefreshTask) -> Void {
    { task in
        let handle = RefreshHandle(task)
        task.expirationHandler = { @Sendable in handle.task.setTaskCompleted(success: false) }
        Task { @MainActor in
            await reschedule()
            handle.task.setTaskCompleted(success: true)
        }
    }
}
```

`register` ruft ihn auf; `using` bleibt `nil`:

```swift
let handler = launchHandler(reschedule: { await notifications.reschedule(); schedule() })
let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { @Sendable task in
    handler(task)
}
```

Die Reihenfolge im Produktpfad bleibt wie heute: erst `await notifications.reschedule()`, dann `schedule()` (neue Anfrage für den
nächsten Lauf), dann `setTaskCompleted(success: true)`. `schedule()` hat die vorhandene Test-Sperre (`isRunningTests`,
`isUITesting`, Zeile 36) und tut unter Tests nichts; im Test wird `schedule()` ohnehin nicht über die Produkt-Closure
aufgerufen, sondern die Neuplanung über die injizierte `reschedule`-Closure beobachtet.

### `submitTaskRequest`-Handler

```swift
BGTaskScheduler.shared.submitTaskRequest(request) { @Sendable error in … }
```

Der Rumpf bleibt, einschließlich des lokalen `log` (Zeile 41).

### Warum `nonisolated static`

Das umgebende `enum` ist `@MainActor`. Eine `@MainActor`-statische Funktion dürfte das System nicht von einer Hintergrund-Queue
aus rufen; `nonisolated` macht die Funktion von jeder Queue aufrufbar, genau wie der Test es verlangt. Der zurückgegebene
Handler ist `@Sendable`, erbt nichts und springt erst im inneren `Task { @MainActor in … }` auf den Main Actor.

## Expected Behavior

- **Input:** iOS startet die Hintergrund-Auffrischung auf einer Hintergrund-Queue.
- **Output:** Kein Absturz. Der Mitteilungsplan wird erneuert (`reschedule()`), die nächste Auffrischung wird angefragt
  (`schedule()`), die Aufgabe endet mit `success: true`.
- **Ablauf des Zeitfensters:** Ruft das System den Ablauf-Handler, endet die Aufgabe mit `success: false`, ebenfalls ohne Absturz,
  von jeder Queue.
- **Planung:** Die Anfrage aus `schedule()` meldet einen Fehler des Systems weiter nur ins Log, jetzt ohne Absturz, wenn der
  Handler nicht auf dem Main Thread läuft.
- **Side effects:** keine neuen.

## Test Plan

### Automated Tests (TDD RED zuerst)

`LooseEndsTests/BackgroundRefreshTests.swift`, `#if os(iOS)`. **XCTest** (nicht Swift Testing): 131 der 132 Testdateien nutzen
Swift Testing, aber das QA-Gate des Workflows zählt nur XCTest-Zeilen („Executed N tests“) und wertet einen Einzellauf einer
Swift-Testing-Suite als „0 tests“. Das Projekt hat beides (`DetailLayoutTests.swift` ist XCTest). Zum Einzellauf für
`BackgroundRefreshTests` ist deshalb XCTest nötig, damit der Beleg des Gates stimmt.

Gemeinsamer Aufbau: ein `FakeRefreshTask: RefreshTask` (Klasse, `@unchecked Sendable`, zählt `setTaskCompleted`-Aufrufe und merkt
sich `success`, hält den `expirationHandler`); eine `reschedule`-Closure, die Aufrufe zählt. Der Handler wird von
`DispatchQueue.global()` aus gerufen, nicht vom Main Thread; der Test wartet mit `XCTestExpectation` (Zeitgrenze 5 s).

- `testLaunchHandlerCalledFromBackgroundQueueReschedulesOnceAndCompletesWithSuccess`: Handler von `DispatchQueue.global()` rufen;
  erwartet: `reschedule` genau einmal, Fake-Task `success: true` genau einmal, kein Absturz.
- `testExpirationHandlerCalledFromBackgroundQueueCompletesWithoutSuccess`: Handler rufen (Fake-Task trägt danach den
  `expirationHandler`), diesen von `DispatchQueue.global()` aus rufen; erwartet: Fake-Task `success: false`, kein Absturz.

**RED vor dem Fix:** Die Tests kompilieren nicht (`RefreshTask` und `launchHandler(reschedule:)` fehlen). Das ist der rote
Zustand des Tests; die Wirkung des heutigen Codes zeigt der Nachbau (`bash run.sh`, Fall 1: exit 133).

**Ehrlich zur Reichweite:** Der Unit-Test belegt Verhalten und Aufrufbarkeit von einer Hintergrund-Queue; dass der Typ
`@Sendable` ist, erzwingt der Compiler. Die Swift-6-Laufzeitprüfung selbst löst ein reiner Swift-Aufruf nicht aus (siehe
Nachbau), der Unit-Test hätte den heutigen Code daher auch nicht rot gemacht. Den Absturz und seine Behebung belegt der
Objective-C-Nachbau.

### Nachbau

`bash docs/artifacts/fix-780-bgrefresh-queue/repro/run.sh`: Fall 1 (heutiger Code) exit 133, Fall A (`.main`) und Fall B
(`@Sendable`) exit 0. Das Skript wird nach dem Fix erneut gefahren und der Lauf im Abschlussbericht genannt.

### Abnahme (Stufen)

1. **Tests:** `./scripts/sim.sh sim-unit BackgroundRefreshTests` (beide Tests grün, „Executed 2 tests“), danach voller Lauf
   `./scripts/sim.sh sim-unit` grün. Nachbau `bash run.sh` mit Ergebnis wie oben.
2. **Simulator:** `./scripts/sim.sh build`, `launch`, App startet, Wechsel in den Hintergrund (`schedule()` läuft), kein Absturz,
   Log angesehen. Der Scheduler fehlt im Simulator, die Zeile `BGTaskScheduler is not available on this platform` ist dort
   erwartet und kein Fehler.
3. **Gerät (Pflicht, `LooseEnds/Notifications/` steht auf der Geräteliste):** über TestFlight, nicht über einen Prüfbau. Nach dem
   Merge und TestFlight-Bau nutzt Henning die App wie sonst; nichts auf seinen Geräten ohne sein wörtliches „jetzt ist ein Test
   möglich“. Der Beleg ist der Absturz-Abruf (#773, Workflow aus PR #778): für Bauten ab dem Fix zeigt er keine
   `BackgroundRefresh`-Meldung mehr. Das System startet die Auffrischung selten; der Beleg braucht einige Tage Nutzung.

## Acceptance Criteria

- **AC-1:** Handler von der Hintergrund-Queue, Erfolg: Given ein Fake-Task und eine zählende `reschedule`-Closure / When der Handler
  aus `BackgroundRefresh.launchHandler(reschedule:)` auf `DispatchQueue.global()` mit dem Fake-Task gerufen wird / Then läuft
  `reschedule` genau einmal, der Fake-Task meldet `setTaskCompleted(success: true)` genau einmal, ohne Absturz.
  Nachweis: Unit-Test `testLaunchHandlerCalledFromBackgroundQueueReschedulesOnceAndCompletesWithSuccess`.
- **AC-2:** Ablauf von der Hintergrund-Queue: Given derselbe Aufbau / When der vom Handler gesetzte `expirationHandler` auf
  `DispatchQueue.global()` gerufen wird / Then meldet der Fake-Task `setTaskCompleted(success: false)` und es gibt keinen Absturz.
  Nachweis: Unit-Test `testExpirationHandlerCalledFromBackgroundQueueCompletesWithoutSuccess`.
- **AC-3:** Alle drei System-Closures `@Sendable`: Given `BackgroundRefresh.swift` nach dem Fix / When der Quelltext geprüft wird /
  Then tragen der `launchHandler`-Block an `register(forTaskWithIdentifier:using:)`, der `expirationHandler` und der Handler von
  `submitTaskRequest` ausdrücklich `@Sendable`; `using:` bleibt `nil`. Nachweis: Compiler (Swift 6, strikte Nebenläufigkeit,
  Bau ohne neue Warnung dazu) und Durchsicht des Diffs.
- **AC-4:** Der Absturz ist behoben: Given der Objective-C-Nachbau / When `bash run.sh` läuft / Then endet Fall 1 (heutiger Code,
  Closure erbt `@MainActor`) mit exit 133 und Fall B (`@Sendable`, `using: nil`) mit exit 0; Fall A (`.main`) endet mit exit 0.
  Nachweis: Ausgabe von `run.sh`, vor und nach dem Fix.
- **AC-5:** Verhalten gleich: Given `register` und `schedule` / When die App startet und in den Hintergrund wechselt / Then ändern
  sich Signaturen, Aufrufer (`LooseEndsApp.swift:47`, `ContentView.swift:130`), Kennung und Zeitabstand nicht; unter Tests und
  `--ui-testing` kehren beide wie bisher sofort zurück. Nachweis: Diff, Simulator-Lauf ohne Absturz im Log, voller
  `sim-unit`-Lauf grün.
- **AC-6:** Nichts sonst: Given der Diff / When er geprüft wird / Then berührt er nur `BackgroundRefresh.swift`,
  `BackgroundRefreshTests.swift`, den Halbsatz in `CLAUDE.md` und das Nachbau-Verzeichnis; keine Änderung an `project.yml`,
  Info.plist, Entitlements, Datenmodell, `DueNotificationCenter`; alle bestehenden Unit- und UI-Tests grün. Nachweis: `git diff
  --stat`, voller Unit-Lauf.
- **AC-7:** Gerät über TestFlight: Given ein TestFlight-Bau mit dem Fix und Hennings Nutzung über einige Tage (nur nach seinem
  wörtlichen „jetzt ist ein Test möglich“, falls dafür etwas auf dem Gerät gestartet werden muss) / When der Absturz-Abruf
  (#773) läuft / Then enthält er für Bauten ab dem Fix keine `BackgroundRefresh`-Meldung mehr. #780 wird erst danach
  geschlossen.

## Dependencies

| Komponente | Beschreibung |
|---|---|
| `BackgroundTasks` | `BGTaskScheduler`, `BGAppRefreshTaskRequest`, `BGTask` |
| `DueNotificationCenter.reschedule()` | die eigentliche Arbeit im Handler, `@MainActor`, als `@MainActor`-Closure übergeben |
| Absturz-Abruf (#773, PR #778) | Beleg für Stufe 3 |

Keine neue Abhängigkeit.

## Risiken

- **Compiler-Strenge (niedrig):** `RefreshTask` als Protokoll mit `any` und die `@Sendable`-Hülle können Swift-6-Fehler in
  Sendable-Prüfungen auslösen (z. B. `notifications` in der Closure). Anpassung lokal; `DueNotificationCenter` ist Main-Actor-
  isoliert und damit `Sendable`, falls nicht, bleibt der Zugriff innerhalb der `@MainActor`-Closure.
- **Test beweist die Laufzeitprüfung nicht (mittel, benannt):** siehe Known Limitations. Der Beleg des Absturzes ist der Nachbau.
- **Beleg braucht Zeit (niedrig):** Das System startet die Auffrischung selten; der Abruf zeigt die Wirkung erst nach einigen
  Tagen.
- **Registrierung nur einmal:** `register` muss vor Ende des App-Starts laufen und darf nur einmal registrieren (Header
  Zeile 80–90). Daran ändert der Fix nichts.

## Alternativen

- **A: `using: .main`.** Ein Wort, behebt den gemeldeten Absturz (Nachbau: exit 0). Verworfen, weil er nur eine von drei Stellen
  trifft: `expirationHandler` (Queue undokumentiert) und `submitTaskRequest`-Handler („arbitrary queue“ laut Header) erben
  weiter `@MainActor` und stürzen ab, sobald das System sie einmal nicht auf dem Main Thread ruft. Zudem zwingt `.main` die
  Arbeit des Systems auf den Main Thread. Gekippt würde dadurch keine ADR.
- **Das ganze `enum` nicht mehr `@MainActor`:** Die Isolation hängt an `register`/`schedule` und an `notifications.reschedule()`
  (`@MainActor`, Zeile 24); `schedule()` greift auf `logger` zu. Ohne `@MainActor` müssten diese einzeln wieder isoliert
  werden, mit größerem Diff und neuen Sendable-Fragen; der Fehler sitzt in den Closures, nicht in der Isolation des Typs.
  Verworfen.
- **Nur `launchHandler` `@Sendable`, den Rest lassen:** behebt den bekannten Absturz, lässt aber dasselbe Muster zweimal
  stehen. Verworfen.
- **Test über den echten Scheduler:** im Simulator nicht möglich (`BGTaskScheduler is not available on this platform`), `BGTask`
  ohne öffentlichen Initialisierer. Daher die Naht `RefreshTask`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: reine Fehlerbehebung in einer Datei (Queue-/Isolationszuordnung von drei Systemrückrufen), keine
  Architekturentscheidung

## Known Limitations

- Der Unit-Test belegt Verhalten und Aufrufbarkeit von einer Hintergrund-Queue. Die Swift-6-Laufzeitprüfung setzt Swift nur bei
  Blöcken aus importierten Objective-C-Schnittstellen ein; ein reiner Swift-Aufruf löst sie nicht aus. Der Test hätte den
  heutigen Code also nicht rot gemacht. Dass die Closure `@Sendable` ist, erzwingt der Compiler; den Absturz und seine
  Behebung belegt allein der Objective-C-Nachbau (`bash run.sh`).
- Der Simulator hat keinen `BGTaskScheduler`; der echte Ablauf (System startet die Aufgabe) ist erst auf dem Gerät sichtbar.
- Ob iOS die Auffrischung in einem bestimmten Zeitraum startet, entscheidet das System; der Beleg in Stufe 3 braucht Geduld.
- Der Nachbau bildet die Objective-C-Schnittstelle nach, nicht das echte Framework.

## Definition of Done

- [ ] AC-1 bis AC-7 erfüllt (AC-7 nach Auslieferung); `BackgroundRefreshTests` grün, voller Unit-Lauf grün, Nachbau-Lauf dokumentiert.
- [ ] Simulator-Durchlauf (Start, Hintergrundwechsel, Log) angesehen.
- [ ] Geräteabnahme nur über TestFlight und nur nach Hennings wörtlichem „jetzt ist ein Test möglich“, wo etwas auf dem Gerät laufen
  müsste; Beleg ist der Absturz-Abruf.
- [ ] `CLAUDE.md`: Halbsatz bei `BackgroundRefresh`: System-Closures `@Sendable`, erben nie eine Main-Actor-Bindung (#780).
- [ ] Der PR verweist mit `Refs #780` (nicht `Closes`); #780 wird erst nach dem sauberen Absturz-Abruf geschlossen.
- [ ] Abschlussbericht ohne Git-Vokabular: Die tägliche Hintergrund-Auffrischung stürzt nicht mehr ab, wenn iOS sie startet; Henning
  muss nichts tun, außer die TestFlight-Version einige Tage zu benutzen; der nächste Absturz-Abruf zeigt, ob die Meldung
  verschwunden ist.

## Changelog

- 2026-10-31: Initiale Spec für #780: Weg B (alle drei System-Closures `@Sendable`, `using: nil`), Naht `RefreshTask`,
  Unit-Tests mit Fake-Task von der Hintergrund-Queue, Nachbau als Beleg des Absturzes.
