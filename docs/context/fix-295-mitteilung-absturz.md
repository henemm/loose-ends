# Context: fix-295-mitteilung-absturz

## Request Summary
Henning (Issue #295, 2026-10-09, iPhone, TestFlight): Mitteilung „fällig“ antippen → beim Wechsel in die App stürzt sie
ab; normal geöffnet startet sie. Ziel: Tippen auf die Mitteilung (Körper und die drei Knöpfe) öffnet bzw. bedient die App
ohne Absturz.

## Reproduktion (2026-10-10, Simulator iPhone 18 Pro, iOS 27.0, Debug, main 5037f0e)
Wegwerf-UI-Test `LooseEndsUITests/Repro295Tests.swift` (nicht im Repo): App ohne `--ui-testing` (echter Startpfad,
Delegate aktiv), Onboarding erzwungen (`--ui-testing-onboarding`), Mitteilungen erlaubt, Home, Shell spielt per
`simctl push` eine Mitteilung mit `category: DUE` und `taskID` ein, Test tippt das Banner.
Ergebnis: „com.henning.looseends crashed“, App danach `notRunning`. Bericht:
`docs/artifacts/fix-295-mitteilung-absturz/repro-simulator-crash.ips`.

## Root Cause (belegt)
`LooseEnds/Notifications/DueNotificationCenter.swift:101` — `nonisolated func userNotificationCenter(_:didReceive:) async`.
Die async-Variante läuft auf dem kooperativen Pool; der vom Compiler erzeugte `@objc`-Thunk ruft den Abschluss des
Systems danach aus diesem Strang. UIKit prüft den Hauptthread und wirft:
```
Thread 2 com.apple.root.user-initiated-qos.cooperative — SIGABRT
-[NSAssertionHandler handleFailureInMethod:…]
-[UIApplication _performBlockAfterCATransactionCommitSynchronizes:]
-[UIApplication _updateStateRestorationArchiveForBackgroundEvent:…]
-[UIApplication _updateSnapshotAndStateRestorationWithAction:windowScene:]
@objc closure #1 in DueNotificationCenter.userNotificationCenter(_:didReceive:)
```
Recherche: DTS bestätigt, dass die async-Varianten nicht `@MainActor` sind und vom Hauptthread springen; die
Rückruf-Variante ruft das System auf dem Hauptthread
(https://developer.apple.com/forums/thread/735651, https://developer.apple.com/forums/thread/796407).
Beim normalen Öffnen läuft `didReceive` nicht → kein Absturz (passt zum Symptom).
`willPresent` (Zeile 110) ist gleich gebaut (async, nonisolated); ob es abstürzt, ist nicht nachgestellt — im RED-Test
mitprüfen (Mitteilung bei geöffneter App).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Notifications/DueNotificationCenter.swift` (132 Z.) | Delegate; Fix hier. `@MainActor`-Klasse, `suppressed` unter Tests/UI-Tests, `apply` (MainActor) wertet Aktion aus. |
| `LooseEnds/App/LooseEndsApp.swift:30-31` | erzeugt und aktiviert den Delegate beim Start (vor der ersten Antwort). |
| `Shared/Notifications/DueReminders.swift` | reine Regeln: Kategorie `DUE`, Aktionen `DUE_DONE`/`DUE_NEXT`/`DUE_TOMORROW`, `handle(...)`. Unverändert. |
| `LooseEnds/Calendar/CalendarBridge.swift:33-35` | Muster `--ui-testing-calendar`: echter Weg unter UI-Tests mit In-Memory-Store. Vorbild für `--ui-testing-notifications`. |
| `LooseEnds/Views/OnboardingFlow.swift` | `--ui-testing-onboarding` erzwingt Onboarding; unter `--ui-testing` sonst übersprungen. |
| `LooseEndsUITests/CalendarTargetTests.swift` | Muster für UI-Test mit echtem Systemdienst. |

## Existing Patterns
- Systemdienste unter UI-Tests still (`suppressed`), gezielt einschaltbar per `--ui-testing-<dienst>`.
- Swift 6 strict concurrency; `Logger` statt `print`; kein `try?`.

## Lösungswege
1. **Empfehlung: Rückruf-Variante** `userNotificationCenter(_:didReceive:withCompletionHandler:)` (und `willPresent` mit
   Rückruf). Das System ruft sie auf dem Hauptthread; Werte als `String` herausziehen, `Task { @MainActor in await apply(…); completionHandler() }`
   oder Abschluss nach der Arbeit — Abschluss auf dem Hauptthread. Von DTS als zuverlässigster Weg genannt.
2. Alternative: async-Variante behalten, aber `@MainActor`-isoliert (isolierte Konformität `@MainActor UNUserNotificationCenterDelegate`,
   Swift 6.2). Kürzer, aber abhängig vom Compiler-Verhalten der Konformität; DTS-Hinweis im Forum, nicht dokumentiert.
3. Verworfen: `Task { @MainActor in … }` in der nonisolated async-Methode ohne Warten — Abschluss käme sofort, Speichern
   liefe ungeschützt nach dem Abschluss (App kann im Hintergrund suspendiert werden, bevor `save()` läuft).

## Test (RED vor dem Fix)
UI-Test mit echtem Delegate: `--ui-testing --ui-testing-notifications` (In-Memory-Store); unter dem Schalter fragt die App
die Erlaubnis an und plant eine Test-Mitteilung (Kategorie `DUE`, kurze Verzögerung). Test erlaubt, geht auf Home, tippt
das Banner, erwartet App im Vordergrund und bedienbar. Muss vor dem Fix rot (Absturz) sein. Ohne `simctl push`, damit es in
der CI läuft.

## Dependencies
- Upstream: `UserNotifications`, `DueReminders`, `ModelContainer.mainContext`.
- Downstream: Start der App aus der Mitteilung; drei Aktionsknöpfe (laufen ohne `.foreground` im Hintergrund).

## Risks & Considerations
- Gerätestufe 3: `LooseEnds/Notifications/` steht auf der Pfadliste → Gerätelauf nur nach „jetzt ist ein Test möglich“.
- Test-Mitteilung im Produktcode nur hinter UI-Test-Schalter; darf in Release nie feuern.
- Aktionsknöpfe (Erledigt/Als nächstes/Morgen) gehen durch dieselbe Methode → gleicher Absturz möglich; RED-Test oder
  Begründung, warum der Körper-Tipp stellvertretend reicht.

## Analysis

### Type
Bug (Absturz). Verschlechterung? Nein: `DueNotificationCenter.swift` ist seit seiner Einführung (#9, f56d46a) unverändert;
der Fehler steckt seit damals drin und zeigt sich, sobald jemand den Mitteilungskörper antippt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Notifications/DueNotificationCenter.swift` | MODIFY | `didReceive`/`willPresent` auf Rückruf-Varianten umstellen; `suppressed` unter `--ui-testing-notifications` aufheben; Test-Mitteilung (nur unter dem Schalter) |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | unter `--ui-testing-notifications` Erlaubnis anfragen und Test-Mitteilung planen (ggf. in DueNotificationCenter gekapselt) |
| `LooseEndsUITests/DueNotificationTapTests.swift` | CREATE | RED-Test: Banner antippen → App im Vordergrund und bedienbar |
| `LooseEndsUITests/Repro295Tests.swift` | DELETE | Wegwerf-Reproduktion, nie committet |

### Scope Assessment
- Files: 3 (+1 Wegwerfdatei weg)
- Estimated LoC: ~+100/-15
- Risk Level: LOW–MEDIUM (eine isolierte Klasse; Risiko liegt im UI-Test-Timing, nicht im Fix)

### Technical Approach (Empfehlung, bestätigt durch Plan-Bewertung)
- `nonisolated func userNotificationCenter(_:didReceive:withCompletionHandler:)`: `actionIdentifier` und `taskID` als
  `String` synchron herausziehen (`UNNotificationResponse` ist nicht Sendable), dann
  `Task { @MainActor in await apply(...); completionHandler() }` — Abschluss auf dem Hauptthread und erst nach `save()`,
  damit ein Hintergrundstart über die Aktionsknöpfe nicht vor dem Speichern suspendiert wird. Abschluss auch bei jedem
  frühen Rücksprung aus `apply` (steht nach dem `await`, also immer).
- `willPresent:withCompletionHandler:` synchron `completionHandler([.banner, .list, .sound])`. Absturz dort mechanisch
  unwahrscheinlich (Assert hängt am Vordergrund-Übergang), Umstellung aber billig und konsistent.
- Keine async-Variante daneben stehen lassen.
- Sendable-Annotation des Rückrufs im iOS-27-SDK beim ersten Build prüfen.

### Alternativen
- Isolierte Konformität `@MainActor UNUserNotificationCenterDelegate` mit async-Methoden: kürzer, aber nicht belegt, dass
  der Compiler-Thunk den Systemabschluss dann auf dem Hauptthread ruft; verworfen (kein ADR betroffen).
- Mitteilungskörper ohne Delegate-Behandlung (nur Knöpfe auswerten): löst den Absturz nicht, weil das System `didReceive`
  für jeden Tipp ruft, sobald ein Delegate gesetzt ist.

### Test
UI-Test unter `--ui-testing --ui-testing-notifications` (In-Memory-Store), App plant selbst eine Mitteilung (Kategorie
`DUE`, ~5 s), Test erlaubt per Interruption-Monitor, Home, tippt Banner, erwartet `runningForeground` + `captureButton`.
Ohne `simctl push` → CI-tauglich. Flakiness mittel (Banner-Timing): großzügige Timeouts. Aktionsknöpfe: im UI-Test
schwer bedienbar (Langdruck am Banner); gleicher Codeweg, durch den Körper-Tipp mitbelegt; Speichern-Logik ist
`DueReminders.handle` (bestehende Unit-Tests).

### Dependencies
`UserNotifications`, `DueReminders`, `ModelContainer.mainContext`. Keine neuen Abhängigkeiten, keine Info.plist-Änderung.

### Abnahme
Stufe 3 greift (`LooseEnds/Notifications/` auf der Geräteliste) → Gerätelauf nur nach Hennings „jetzt ist ein Test möglich“.

### Open Questions
- keine PO-Fragen offen.
