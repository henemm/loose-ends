# Context: fix-780-bgrefresh-queue

## Request Summary
Die tägliche Hintergrund-Auffrischung (#553) stürzt ab, sobald iOS sie startet (#780). Zwei Berichte aus dem Absturz-Abruf
(#773, Lauf 41216707696): Build 98 (2026-10-21) und Build 126 = 1.0 (2026-10-31), beide `EXC_BREAKPOINT` in
`_dispatch_assert_queue_fail + 120` unter `closure #1 in static BackgroundRefresh.register(_:)`. Folge: Der Mitteilungsplan wird
ohne App-Start nie erneuert. „Hat es bisher funktioniert?“: nein, seit #553 in jedem Bau.

## Reproduktion (2026-10-31)
- Simulator scheidet aus: `BGTaskScheduler is not available on this platform.` (BGTaskSchedulerErrorDomain Code=1, Log der App
  im iPhone-17-Simulator); `_simulateLaunchForTaskWithIdentifier:` startet dort nichts.
- Nachbau mit Objective-C-Schnittstelle gleicher Form (`registerForTaskWithIdentifier:usingQueue:launchHandler:`, Block ohne
  Sendable-Markierung), Swift 6, `@MainActor enum` registriert den Handler:
  `using: nil` → `Trace/BPT trap: 5`, im Debugger `EXC_BREAKPOINT` in `libdispatch _dispatch_assert_queue_fail + 120` auf der
  Hintergrund-Queue (identisch mit dem Gerätebericht); `using: .main` → läuft durch. Nachbau unter
  `docs/artifacts/fix-780-bgrefresh-queue/repro/` (`bash run.sh` baut und fährt beide Fälle), wird in der Spec als Beleg zitiert.
- Ein reiner Swift-Nachbau stürzt NICHT ab: Swift setzt die Laufzeitprüfung nur bei Blöcken aus importierten
  Objective-C-Schnittstellen ein (statische Prüfung reicht in reinem Swift).

## Ursache
`BackgroundRefresh` ist `@MainActor` (`LooseEnds/Notifications/BackgroundRefresh.swift:11`). Der Block an
`BGTaskScheduler.shared.register(forTaskWithIdentifier:using: nil)` (Zeile 20) ist im SDK nicht `@Sendable` markiert, also erbt
die Closure die Bindung an den Main Actor. Das System ruft sie laut Header auf „a default background queue“ (`using: nil`); die
Swift-6-Laufzeitprüfung bricht ab, bevor der innere `Task { @MainActor in … }` läuft.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Notifications/BackgroundRefresh.swift` | Einzige Absturzstelle; `register` (Zeile 18–32), `schedule` (Zeile 35–46), `RefreshHandle` |
| `LooseEnds/App/LooseEndsApp.swift:47` | Ruft `BackgroundRefresh.register(notifications)` beim Start |
| `LooseEnds/App/ContentView.swift:130` | Ruft `BackgroundRefresh.schedule()` beim Wechsel in den Hintergrund |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | `reschedule()`, die eigentliche Arbeit im Handler (`@MainActor`) |
| SDK `BackgroundTasks.framework/Headers/BGTaskScheduler.h:87–93`, `:136–143`; `BGTask.h:42` | Queue-Regeln, keine Sendable-Markierung |

## Existing Patterns
- #580: `schedule()` nimmt den Logger als lokale Konstante, weil der `submitTaskRequest`-Handler „off the main actor“ laufen
  kann. Die Closure selbst ist aber ebenfalls nicht `@Sendable` markiert und erbt damit `@MainActor`.
- `RefreshHandle: @unchecked Sendable` trägt den `BGTask` über die Grenze auf den Main Actor.
- Unter Tests (`isRunningTests`, `isUITesting`) kehren `register` und `schedule` sofort zurück; es gibt keinen Test für die Datei.

## Dependencies
- Upstream: `BGTaskScheduler`, `BGAppRefreshTask`, `DueNotificationCenter.reschedule()`, `Logger`.
- Downstream: App-Start (`LooseEndsApp`), Szenenwechsel (`ContentView`). iOS only (`#if os(iOS)`), nicht Mac/Watch.

## Existing Specs
- #553 (Hintergrund-Auffrischung), #580 (Fehler beim Einplanen); keine Spec für die Queue-Frage.

## Risks & Considerations
- **Gleiches Muster zweimal mehr in derselben Datei:** der `submitTaskRequest`-Handler (Header: „called on an arbitrary queue“)
  und der `expirationHandler` (Queue nicht dokumentiert) erben ebenfalls `@MainActor`. Kein Bericht bisher, aber dieselbe Falle;
  in der Analyse entscheiden, ob alle drei Closures in einem Schnitt fest gemacht werden.
- Nicht testbar über den echten Scheduler (Simulator ohne BGTaskScheduler, `BGTask` ohne öffentlichen Initialisierer). Test
  braucht eine Naht (z. B. die Closure als `nonisolated`/`@Sendable` herausziehen und von einer Hintergrund-Queue rufen).
- Geräteliste: `LooseEnds/Notifications/` → Stufe 3 über TestFlight; Beleg ist der nächste Absturz-Abruf ohne diese Meldung.
- `register` muss vor Ende des App-Starts laufen und darf nur einmal registrieren (Header Zeile 80–90); daran ändert der Fix nichts.

## Analysis

### Type
Bug (Absturz, seit #553 in jedem Bau, nie funktioniert)

### Recherche (2026-10-31)
- Dasselbe Bild bei anderen Entwicklern: `EXC_BREAKPOINT` auf `com.apple.BGTaskScheduler` über `_dispatch_assert_queue_fail` →
  `_swift_task_checkIsolatedSwift`, Auslöser `using: nil` mit einem Handler, der Main-Actor-Bindung erbt; Abhilfe: Queue und
  Isolation in Einklang bringen. https://hackernoon.com/swift-6-gave-me-zero-warnings-but-two-objective-c-callbacks-still-crashed-at-runtime,
  https://developer.apple.com/forums/thread/774517
- Apple-Doku: `nil` = „default background queue“, jede Kennung nur einmal registrieren.
  https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler/register(fortaskwithidentifier:using:launchhandler:)

### Nachbau, beide Wege gemessen (`repro/run.sh`)
| Fall | Ergebnis |
|---|---|
| `using: nil`, Closure erbt `@MainActor` (heutiger Code) | `Trace/BPT trap: 5`, exit 133 |
| A: `using: .main` | läuft durch, exit 0 |
| B: `using: nil`, Closure ausdrücklich `@Sendable` | läuft durch, exit 0 |

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Notifications/BackgroundRefresh.swift` | MODIFY | Alle drei System-Closures (`launchHandler`, `expirationHandler`, `submitTaskRequest`-Handler) ausdrücklich `@Sendable`; Handler-Rumpf als `nonisolated static func launchHandler(…) -> @Sendable (any RefreshTask) -> Void` herausgezogen, Protokoll `RefreshTask` (Ablauf-Handler, `setTaskCompleted`), `BGTask` erfüllt es |
| `LooseEndsTests/BackgroundRefreshTests.swift` | CREATE | Handler von einer Hintergrund-Queue mit Fake-Task aufrufen: Plan wird erneuert, Task `success: true`; Ablauf von einer Hintergrund-Queue → `success: false`, kein Absturz |
| `docs/artifacts/fix-780-bgrefresh-queue/repro/` | MODIFY | Variante B ergänzt (Beleg für die Spec) |
| `CLAUDE.md` | MODIFY | Ein Halbsatz bei `BackgroundRefresh`: System-Closures `@Sendable`, nie Main-Actor-Bindung erben (#780) |

### Scope Assessment
- Files: 3 (+ Repro-Artefakt)
- Estimated LoC: +~90 / -~15
- Risk Level: LOW — eine Datei im Produktcode, Aufrufer unverändert, nur iOS

### Technical Approach
**Empfehlung: Weg B** — alle drei Closures `@Sendable`, Queue bleibt `nil`. Die Closure läuft dann unabhängig davon, auf
welcher Queue das System sie ruft, und springt erst im inneren `Task { @MainActor in … }` auf den Main Actor. Das deckt auch
`submitTaskRequest` („arbitrary queue“ laut Header) und `expirationHandler` (Queue undokumentiert), die dieselbe Falle tragen.

**Alternative A:** `using: .main`. Ein Wort, behebt den gemeldeten Absturz, lässt aber die anderen beiden Closures mit
geerbter Main-Actor-Bindung stehen — sie stürzen ab, sobald das System sie einmal nicht auf dem Main Thread ruft. Gekippt
würde dafür nichts; verworfen, weil er nur das Symptom an einer von drei Stellen trifft.

**Test:** `BGTask` hat keinen öffentlichen Initialisierer und der Simulator keinen Scheduler; daher die Naht `RefreshTask`.
Der Unit-Test prüft das Verhalten von einer Hintergrund-Queue aus; dass der Typ `@Sendable` ist, erzwingt der Compiler. Den
Laufzeitabsturz selbst belegt der Objective-C-Nachbau (einziger Weg, die Laufzeitprüfung außerhalb des Geräts auszulösen).

### Dependencies
`BGTaskScheduler`, `DueNotificationCenter.reschedule()` (`@MainActor`, als `@MainActor`-Closure übergeben). Aufrufer
`LooseEndsApp.swift:47` und `ContentView.swift:130` bleiben unverändert.

### Abnahme
Stufe 1 Unit-Tests, Stufe 2 Simulator (App startet, Hintergrundwechsel ohne Fehler im Log; der Scheduler selbst fehlt dort).
Stufe 3: `LooseEnds/Notifications/` steht auf der Geräteliste → TestFlight-Bau; Beleg ist der Absturz-Abruf (#773), der für
Bauten ab dem Fix keine `BackgroundRefresh`-Meldung mehr zeigt. Das System startet die Auffrischung selten, der Beleg braucht
also einige Tage Nutzung.

### Open Questions
- keine (technische Wahl, Produktverhalten bleibt gleich)
