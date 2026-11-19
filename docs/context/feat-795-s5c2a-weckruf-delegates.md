# Context: feat-795-s5c2a-weckruf-delegates

## Request Summary
#795 Schnitt 5c-2a: Die App hört auf den stillen Weckruf des Dienstes. Sie meldet ihr Gerätetoken über den fertigen
`DeviceRegistration` (S5c-1) und ruft beim Eingang einer Mitteilung mit dem Schlüssel `looseends` `ClaudeSyncTrigger.wake()`
(senden, dann holen). Plan und Recherche: `docs/context/feat-795-s5c-weckruf-app.md` (Abschnitt „S5c-2a“).

## Related Files
| File | Relevance |
|------|-----------|
| LooseEnds/App/LooseEndsApp.swift:7–9, :62–65 | nur `@NSApplicationDelegateAdaptor(MacAppDelegate)`; iOS hat keinen App-Delegate. `account` und `claudeSync` entstehen in `init`, der Delegate braucht beide |
| LooseEnds/Mac/MenuBarCapture.swift:130–168 | `MacAppDelegate` (Login-Item, Dock): Mac-Gegenstück für Token-Rückruf und `application(_:didReceiveRemoteNotification:)` (AppKit, ohne Completion-Handler) |
| LooseEnds/Claude/DeviceRegistration.swift | `PushEnvironment.current` (Info `LEApsEnvironment`, S5c-2b gemergt), `register(token:)` → `registered/unchanged/notSignedIn/busy/failed`; nur über `AccountState.withSession` |
| LooseEnds/Claude/ClaudeSyncTrigger.swift:54–70, :107 | `forApp` (still unter Tests), `wake()` kehrt erst nach einem Holen zurück, das nach dem Aufruf begann; braucht kein `start()` |
| LooseEnds/Claude/AccountState.swift:12–16 | `@Observable`, `status` (`signedIn` nach späterer Anmeldung) → Anlass, sich dann zu registrieren |
| LooseEnds/Notifications/BackgroundRefresh.swift:36–98 | Muster „Abschluss genau einmal“: `RefreshHandle` mit `Mutex`, `nonisolated` Handler hüpft auf den MainActor (#780/#782) |
| LooseEnds/Notifications/DueNotificationCenter.swift | einziger `UNUserNotificationCenterDelegate`; stille Mitteilungen laufen nicht über ihn, sondern über den App-Delegate |
| server/src/apns.ts:13 | Inhalt des Weckrufs: `{ aps: { "content-available": 1 }, looseends: { v: 1 } }` |
| project.yml:70–100 | `aps-environment: development`, `LEApsEnvironment: sandbox`, `UIBackgroundModes: [remote-notification, fetch]` — schon vorhanden, dieser Schnitt ändert `project.yml` nicht |
| LooseEndsTests/BackgroundRefreshTests.swift, ClaudeSyncTriggerTests.swift, DeviceRegistrationTests.swift | Testmuster für Einmal-Abschluss, Weckruf und Registrierung |

## Existing Patterns
- Systemrückruf von beliebiger Queue → Einmal-Handle (`Mutex`) + `Task { @MainActor in … }`, Abschluss genau einmal, auch bei Fristablauf (BackgroundRefresh).
- Prozessweite Dienste werden in `LooseEndsApp.init` gebaut und gestartet (`WidgetReload`, `ClaudeSyncTrigger`, `BackgroundRefresh.register`); unter Tests still.
- Reine, testbare Regel neben der Systemverdrahtung (z. B. `WidgetReload.isFinishedImport`, `PlaceNotifications`).

## Dependencies
- Upstream: `DeviceRegistration.register(token:)`, `PushEnvironment.current`, `ClaudeSyncTrigger.wake()`, `AccountState.status`, `DeviceIdentity`.
- Downstream: Dienst `POST /app/device` (live seit S5b), APNs-Sender `apns.ts` (live, weckt nach jedem neuen Auftrag).

## Existing Specs
- `docs/specs/feat-795-schnitt-5c1-weckruf-kern.md` (Registrierer, `wake()`)
- `docs/specs/feat-795-schnitt-3b1-ausloeser.md` (Trigger-Regeln)
- `docs/specs/feat-795-schnitt-5a1-geraet-anmelden.md`, `feat-795-schnitt-5b-weckruf-betrieb.md`
- S5c-2b (`LEApsEnvironment`) gemergt; S5c-2b2 (Mac-Push-Schlüssel) läuft parallel in einer anderen Sitzung (PR offen: `project.yml`, `testflight.yml`, Entitlements) — keine gemeinsame Datei außer `CLAUDE.md`.

## Risks & Considerations
- **Gerätepfad:** neue Datei unter `LooseEnds/Notifications/` → Stufe 3 über TestFlight (Konto-Bau); der Mac empfängt erst nach S5c-2b2.
- **Delegate-Übergabe:** `@UIApplicationDelegateAdaptor` baut den Delegate vor/neben `init`; `account`/`claudeSync` erreichen ihn über einen statischen Haken, den `init` füllt.
- **CloudKit nicht stören:** fremde Mitteilungen (ohne `looseends`) sofort `.noData`; `NSPersistentCloudKitContainer` bearbeitet seine eigenen selbst. Koexistenz nur am Gerät belegbar.
- **Abschluss genau einmal und rechtzeitig** (~30 s Budget): Frist ~25 s gegen `wake()`, wer verliert, schließt nicht ab.
- **Registrierung nur mit Konto**, auch nach späterer Anmeldung (`status` beobachten); ohne Konto kein `registerForRemoteNotifications`-Bericht an den Dienst. CloudKit braucht `registerForRemoteNotifications` ohnehin (macht der Container selbst).
- **Tests:** unter `--ui-testing` und Unit-Tests still; Simulator: `xcrun simctl push` als frühe Einschätzung (Forum 725200 nennt den Rückruf im Simulator unzuverlässig).
- **Watch:** kein Konto, nicht betroffen.

## Recherche (2026-11-19)
- Swift 6: `[AnyHashable: Any]` ist nicht `Sendable`; Abhilfe ist ein `@MainActor`-Delegate und die async-Variante
  `application(_:didReceiveRemoteNotification:) async -> UIBackgroundFetchResult` ([Forum 757042](https://developer.apple.com/forums/thread/757042),
  [Firebase](https://firebase.google.com/docs/cloud-messaging/ios/receive)). `userInfo` nur synchron prüfen, nie in eine Task tragen.
- Budget ≈ 30 s, Abschluss Pflicht, Hintergrund-Mitteilungen werden gedrosselt und nicht garantiert zugestellt
  ([Apple: Pushing background updates](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app)).
- AppKit: `application(_:didReceiveRemoteNotification:)` ohne Completion; eine kurz vor dem Start eingetroffene Mitteilung
  ruft ihn nicht auf, wenn `applicationDidFinishLaunching` implementiert ist ([AppKit-Doku](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application(_:didreceiveremotenotification:).md));
  unkritisch, weil der Start ohnehin sendet und holt. Mac-Zustellung laut Foren unzuverlässig ([Forum 743679](https://developer.apple.com/forums/thread/743679)).
- Simulator-Rückruf unzuverlässig ([Forum 725200](https://developer.apple.com/forums/thread/725200)) → `xcrun simctl push` nur als frühe Einschätzung.

## Analysis

### Type
Feature (#795 S5c-2a, App-Seite des Weckrufs; PO-Entscheidung A vom 2026-11-13)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEnds/Claude/PushWakeUp.swift | CREATE | `@MainActor`-Knoten, einmal aus `LooseEndsApp.init` gesetzt (statisch; nil ohne Konto und unter Tests). Reine Regel `isWake(userInfo)` (Schlüssel `looseends`), synchron im Rückruf ausgewertet. `handle(isWake:) async -> Result`: Fremdes → `.notOurs` sofort; sonst `trigger.wake()` gegen 20-s-Frist, Fortsetzung mit `Mutex`-Einmalkasten (wake ist nicht abbrechbar, ModelDeadline daher unbrauchbar), Zeitgeber wird bei Sieg abgebrochen. `didReceive(token:)` → `DeviceRegistration.register`. Anmeldebeobachtung `Observations { account.status }` (erstes Element deckt den Start ab, kein eigener Startcheck): bei `signedIn` → `registerForRemoteNotifications` (Closure, testbar) |
| LooseEnds/Notifications/IOSAppDelegate.swift | CREATE | `#if os(iOS)`, `@MainActor final class`: Token-Rückruf, Fehler-Rückruf (nur Log), async `didReceiveRemoteNotification` → Knoten; ohne Knoten `.noData`. Ergebnis: geweckt → `.newData`, Frist → `.noData` (`.failed` drosselt künftige Weckrufe), fremd → `.noData` |
| LooseEnds/Mac/MenuBarCapture.swift | MODIFY | `MacAppDelegate`: dieselben Token-Rückrufe und `didReceiveRemoteNotification` (ohne Completion, Task) |
| LooseEnds/App/LooseEndsApp.swift | MODIFY | `@UIApplicationDelegateAdaptor` (iOS), Knoten nach `claudeSync` installieren |
| LooseEndsTests/PushWakeUpTests.swift | CREATE | isWake, Weckruf gewinnt, Frist gewinnt (wake hängt), später wake schließt nicht doppelt, Token-Weitergabe, Anmeldung löst genau eine Registrierung aus, ohne Konto nichts |

### Scope Assessment
- Files: 5 (+ CLAUDE.md-Zeile)
- Estimated LoC: ≈ +150 Code / +150 Tests (Bewertung Plan-Agent); Meldeschwelle beachten, ggf. nach RED fragen
- Risk Level: MEDIUM — Gerätepfad (`LooseEnds/Notifications/`), neuer App-Delegate auf iOS neben CloudKit-Abgleich

### Technical Approach
Hintergrund-Mitteilung über App-Delegate (iOS async-Variante, Mac AppKit), Knoten im App-Kern, alle Regeln dort testbar; der
Delegate ist nur Durchreiche. Bisher ruft niemand `registerForRemoteNotifications` und kein Token-Rückruf erreichte die App;
der CloudKit-Container registriert sich selbst. `DeviceRegistration` dedupliziert je Paar und Prozess, doppelte Rückrufe sind harmlos.
`DueNotificationCenter` ist `UNUserNotificationCenterDelegate`, getrennter Kanal, keine Kollision.

Alternativen:
- Kein App-Teil, nur Holen bei Start/Vordergrund (heute): fällt hinter PO-Entscheidung A zurück, ADR-21-Addendum (Weckruf) ohne Empfänger.
- Nur `BGAppRefreshTask` (#553-Muster) statt Weckruf: kein zeitnahes Holen, System wählt Zeitpunkt (Stunden).
- Sichtbare Mitteilung mit Notification Service Extension: Extension läuft nur für sichtbare Mitteilungen, und der Nutzer sähe Banner — verworfen.

### Dependencies
Upstream: `DeviceRegistration`, `PushEnvironment.current`, `ClaudeSyncTrigger.wake()`, `AccountState.status`, `DeviceIdentity`.
Downstream: Dienst `POST /app/device` und `apns.ts` (live). Mac-Empfang erst mit S5c-2b2 (PR #957, andere Sitzung; keine gemeinsame Datei).

### Nachweis
- Stufe 1: Unit-Tests oben. Stufe 2: Simulator mit `LOOSEENDS_SIM_SIGN=1`, Debug-Weg (`local-service.sh`), `xcrun simctl push`
  mit `looseends`-Inhalt → Auftrag wird geholt (Ergebnis in der Datenbank), CloudKit-Inhalt → `.noData`.
- Stufe 3 (Gerätepfad): TestFlight-Konto-Bau; Gerätepunkte in der DoD, nicht als AC: Weckruf holt Auftrag bei App im Hintergrund;
  iCloud-Abgleich im Hintergrund unverändert. PR mit `Refs #795`.

### Open Questions
- [x] Frist 20 s, Frist → `.noData` (technisch, Claude)
- [ ] CloudKit-Koexistenz nur am Gerät belegbar (Stufe 3)
- [ ] Datenschutz-Absatz Push-Token (#795 S5c-2 laut CLAUDE.md) folgt als eigener Schnitt; Rechtstext nur nach Hennings Freigabe live. Konto-Schalter ist im Store aus, also meldet kein Store-Bau ein Token.
Keine offene PO-Frage.
