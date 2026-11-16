# Context: feat-795-s5c-weckruf-app

## Request Summary
#795 Schnitt S5c: Die App meldet ihr Gerätetoken samt APNs-Umgebung an `POST /app/device` und reagiert auf den stillen
Weckruf des Dienstes (`{"aps":{"content-available":1},"looseends":{"v":1}}`, `server/src/apns.ts:13`) mit einem
`ClaudeSync`-Durchgang (senden, dann holen). Dienstseite ist seit S5b live (`APNS_*` gesetzt, `/app/device` außen offen).
Plan aus der S5-Analyse: `docs/context/feat-795-s5-weckruf.md` (Abschnitt „Technical Approach“, S5c).

## Related Files
| File | Relevance |
|------|-----------|
| LooseEnds/App/LooseEndsApp.swift:8, :50–64 | nur `@NSApplicationDelegateAdaptor(MacAppDelegate)`; iOS hat keinen App-Delegate. Baut `account` (`AccountWiring.forApp`) und `claudeSync` (`ClaudeSyncTrigger.forApp`) — beide müssen den Delegate erreichen |
| LooseEnds/Mac/MenuBarCapture.swift:134–168 | `MacAppDelegate` (Login-Item, Dock); Mac-Gegenstück für `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` und `didReceiveRemoteNotification` (AppKit: ohne Completion-Handler) |
| LooseEnds/Claude/ClaudeSyncTrigger.swift:51–139 | `forApp`, `start()`, `sendThenPull()` (privat), `drain()`; kein öffentlicher Eingang „einmal senden+holen und Bescheid geben“ — der Weckruf braucht ihn für `fetchCompletionHandler` |
| LooseEnds/Claude/ServiceClient.swift:81–106, :125–160 | Muster `putTranscript`/`claimOrder`/`putResult` (Bearer, `X-Device` klein geschrieben, Erfolgsmenge) — Vorlage für `putDevice(token:environment:sessionToken:device:)` → 204 |
| LooseEnds/Claude/AccountState.swift:117–127 | `withSession` — einzige Tür zu den App-Wegen, nur aus `signedIn`; Registrierung muss auch nach späterer Anmeldung laufen, nicht nur beim Start |
| LooseEnds/Claude/DeviceIdentity.swift | `current()` liefert die `X-Device`-UUID |
| LooseEnds/Claude/AccountWiring.swift | `forApp`: Konto nur mit `LEAccountEnabled`, unter `--ui-testing` immer an mit `UITestTransport` (kein Netz) |
| LooseEnds/Notifications/DueNotificationCenter.swift:19 | einziger `UNUserNotificationCenterDelegate` (nur lokale Mitteilungen); stille Mitteilungen laufen NICHT über ihn, sondern über den App-Delegate |
| LooseEnds/Notifications/BackgroundRefresh.swift | Muster für Systemrückrufe: `@Sendable`, nie Main-Actor-Bindung erben (#780), Abschluss genau einmal (#782) |
| project.yml:70, :92–96 | `aps-environment: development`, `UIBackgroundModes: [remote-notification, fetch]` vorhanden (CloudKit); Mac-Target prüfen |
| .github/workflows/testflight.yml:118, :225–233, :425 | Muster: `plutil -replace` auf `LooseEnds/Info.plist` nach `generate` (LEAccountEnabled) samt Archivprüfung — möglicher Weg für eine Umgebungsmarke |
| server/src/devices.ts:4–19 | Vertrag: `{token: hex 64–200, gerade Länge; environment: "sandbox"|"production"}` |
| docs/reference/claude-abschrift-vertrag.md:185–195 | „Wege der App“, `POST /app/device` |
| LooseEndsTests/ServiceClientTests.swift, ClaudeSyncTriggerTests.swift, AccountStateTests.swift | bestehende Testmuster (Transport-Attrappe, Trigger mit eigenen Aktionen) |

## Existing Patterns
- Abhängigkeiten hineingereicht (`HTTPTransport`, Aktionen im Trigger); unter Tests (`silent`) keine echten Durchgänge, unter `--ui-testing` kein Netz.
- Ohne Konto kein Aufruf an den Dienst (DoD #795); `withSession` gibt `nil` ohne Sitzung.
- Systemrückrufe: Abschluss genau einmal, `@Sendable`, keine Main-Actor-Erbschaft (#780/#782).
- Logs nur Fallnamen, nie Token oder Körper (auch kein Gerätetoken).
- Archivschalter per `plutil` nach `generate` in `testflight.yml`, im Archiv geprüft.

## Dependencies
- Upstream: `UIApplication.registerForRemoteNotifications()` / `NSApplication.registerForRemoteNotifications()`,
  Delegate-Rückrufe für Token und Fehler, `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` (iOS) bzw.
  `application(_:didReceiveRemoteNotification:)` (macOS); `AccountState.withSession`, `DeviceIdentity`, `ServiceClient`.
- Downstream: `ClaudeSync`-Durchgang, Dienst `putDevice` (S5a-1), Weckrufsender `apns.ts` (wählt Host je Umgebung).

## Existing Specs
- docs/specs/feat-795-schnitt-5a1-*.md (Weg `/app/device`), feat-795-schnitt-5a2*-*.md (Sender), feat-795-schnitt-5b-weckruf-betrieb.md
- docs/specs/feat-795-schnitt-3b1-ausloeser.md (Trigger-Regeln: nie zwei Sendungen gleichzeitig, holen nur nach senden)

## Recherche (2026-11-15)
- **Umgebung zur Laufzeit:** Apple bietet keine API; üblich ist, `aps-environment` aus `embedded.mobileprovision` zu lesen
  (Format proprietär, Firebase macht es so). Entwicklungssigniert → sandbox, verteilungssigniert (Ad-Hoc, TestFlight, Store)
  → production. Ob TestFlight-Bauten die Datei überhaupt enthalten, ist nicht belegt; Fallback „DEBUG = sandbox“ gilt als grob.
  Quellen: [Apple-Forum 747663](https://developer.apple.com/forums/thread/747663),
  [aps-environment](https://developer.apple.com/tutorials/data/documentation/bundleresources/entitlements/aps-environment.md),
  [process-one: Provisioning Profile lesen](https://www.process-one.net/blog/reading-ios-provisioning-profile-in-swift/),
  [SO 10146911](https://kaweah.freedombox.rocks/kiwix/stackoverflow.com_en_all_2023-11/questions/10146911/determine-whether-app-is-communicating-with-apns-sandbox-or-production-environ),
  [Pushwoosh](https://help.pushwoosh.com/hc/en-us/articles/17218085469597-iOS-My-provisioning-profile-is-the-distribution-but-in-the-logs-I-still-see-the-sandbox-gateway).
  Repo-eigene Alternative ohne Raten: Marke im Info.plist, die nur `testflight.yml` beim Archivieren auf `production` setzt
  (Muster `LEAccountEnabled`), Vorgabe `sandbox`.
- **Zusammenleben mit CloudKit:** Stille CloudKit-Mitteilungen landen im selben App-Delegate-Rückruf
  ([CKNotification](https://developer.apple.com/documentation/cloudkit/cknotification.md)); `NSPersistentCloudKitContainer`
  verarbeitet sie selbst. Unser Handler erkennt nur `looseends` und meldet für Fremdes sofort `.noData`, ohne CloudKits
  Weg zu berühren. Keine Apple-Aussage zur Koexistenz gefunden → Gerätenachweis (Stufe 3) nötig.
  Quellen: [Forum 725200](https://developer.apple.com/forums/thread/725200), [Forum 820550](https://developer.apple.com/forums/thread/820550).
- **Simulator:** `xcrun simctl push` spielt eine Mitteilung ein; Forenberichte nennen den Rückruf im Simulator unzuverlässig
  ([Forum 725200](https://developer.apple.com/forums/thread/725200)) → im Simulator früh nachstellen.

## Risks & Considerations
- **Gerätepfad:** `LooseEnds/Notifications/` bzw. `project.yml`/`Info.plist` berührt → Stufe 3 über TestFlight (Konto-Bau).
- **Umgebung falsch gemeldet** → der Dienst schickt an den falschen Host, APNs antwortet `BadDeviceToken` und der Dienst
  löscht den Token (S5a-2a) → Weckruf still tot. Muss belegbar richtig sein.
- **CloudKit-Abgleich nicht stören:** ein Delegate, der fremde Mitteilungen schluckt oder zu spät abschließt, kann den
  iCloud-Abgleich bremsen.
- **Abschluss genau einmal und rechtzeitig** (~30 s Budget für `fetchCompletionHandler`); ein laufender Durchgang (`busy`)
  muss trotzdem abschließen.
- **Registrierung nur mit Konto**, auch nach späterer Anmeldung; Abmelden/Löschen braucht keine Abmeldung beim Dienst
  (Logout behält die Zeile, Löschen kaskadiert).
- **Watch:** kein Konto auf der Uhr → nicht betroffen.
- **Umfang:** Delegate iOS + Mac, Client-Weg, Registrierer, Trigger-Eingang, Umgebung, Tests → voraussichtlich > 250 LoC →
  Teilung in S5c-1 (Client-Weg + Umgebung + Registrierer, rein, testbar) und S5c-2 (Delegates + Weckruf-Eingang) prüfen.
- **Alternative:** gar keine App-Seite, nur Holen bei Start/Vordergrund (Status heute); dann ist der Dienst-Weckruf ohne
  Empfänger — fällt hinter die PO-Entscheidung A vom 2026-11-13 zurück.

## Analysis

### Type
Feature (#795, App-Seite des Weckrufs; PO-Entscheidung A vom 2026-11-13)

### Schnitte (je ≤ 4–5 Dateien, ±250 LoC)
Drei Schnitte in dieser Reihenfolge; dieser Workflow baut **S5c-1**, S5c-2b und S5c-2a folgen als eigene Workflows unter #795.

**S5c-1 — reiner App-Kern, kein Pfad der Geräteliste** (≈ 230 LoC mit Tests)
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEnds/Claude/ServiceClient.swift | MODIFY | `putDevice(token:environment:sessionToken:device:)` → `POST /app/device`, Körper `{token, environment}`, `X-Device` klein, Erfolg 204 (Muster `putResult`) |
| LooseEnds/Claude/DeviceRegistration.swift | CREATE | `PushEnvironment` (Info `LEApsEnvironment`: nur `production` → production, sonst sandbox) und `DeviceRegistration` (Token-`Data` → Hex klein; sendet nur über `AccountState.withSession`; merkt Token+Umgebung des letzten Erfolgs nur im Speicher, gleicher Wert wird nicht erneut gesendet; Log nur Fallnamen, nie Token) |
| LooseEnds/Claude/ClaudeSyncTrigger.swift | MODIFY | öffentliches `wake() async -> ClaudeSync.Ending?`: wie `sendThenPull`, kehrt erst nach dem darauf folgenden Holen zurück; Warteliste von Continuations, in `drain` nach `await pull()` geweckt, auch wenn ein Senden schon lief (`busy`); Ergebnis des Holens zurück, damit der Handler `.newData`/`.noData` ehrlich meldet |
| LooseEndsTests/ServiceClientTests.swift | MODIFY | Weg, Kopfzeilen, Körper, 204/401/409/429 |
| LooseEndsTests/ClaudeSyncTriggerTests.swift (+ Registrierungs-Tests darin oder eigene Datei) | MODIFY | `wake` während laufendem Senden, Kaltstart `start()`+`wake` fasst zusammen, mehrere Wartende, ohne Sitzung nichts gesendet |

**S5c-2b — Umgebungsmarke im Bau (Pfad der Geräteliste: project.yml)**
`project.yml` Info `LEApsEnvironment: sandbox`; `testflight.yml` setzt per `plutil` nach `generate` `production` (iOS und Mac, Muster `LEAccountEnabled` :118/:425); Archivprüfung **kreuzweise**: Marke gegen signiertes Entitlement (`production` ↔ `aps-environment=production`; Mac-Schlüssel aus `codesign` klären, `aps-environment` oder `com.apple.developer.aps-environment` — heute in der Mac-Prüfung :495 nicht geprüft). Abweichung = Upload stoppt.

**S5c-2a — Delegates und Weckruf-Eingang (Pfade der Geräteliste)**
iOS `UIApplicationDelegateAdaptor` (neu) und `MacAppDelegate` (LooseEnds/Mac/MenuBarCapture.swift): Token/Fehler-Rückrufe → `DeviceRegistration`; `didReceiveRemoteNotification` reagiert nur auf Schlüssel `looseends`, alles andere (CloudKit) sofort `.noData`; Abschluss genau einmal über Einmal-Handle (Lehre #780/#782, `BackgroundRefresh.swift`), Frist ~25 s gegen `wake()`, Verlierer schließt nicht ab. Übergabe von `account`/`claudeSync` an den Delegate (der Adapter entsteht vor `LooseEndsApp.init` fertig ist): statischer Haken, den `init` füllt. `registerForRemoteNotifications` beim Start mit Konto und bei späterer Anmeldung (Beobachtung von `AccountState.status`, `@Observable`). Simulator: `xcrun simctl push` als frühe Einschätzung; Stufe 3 über TestFlight (Konto-Bau).

### Scope Assessment (S5c-1)
- Files: 5
- Estimated LoC: ≈ +230/−5
- Risk Level: LOW (nichts ruft den neuen Code bis S5c-2a auf; kein Gerätepfad)
- Gesamtrisiko #795-S5c: MEDIUM (falsche Umgebung → Dienst löscht Token, Weckruf still tot; CloudKit-Pushes nicht stören)

### Technical Approach
Umgebung aus dem Bau statt geraten: Info-Marke, die nur der TestFlight-Lauf auf `production` setzt, im Archiv gegen das signierte Entitlement geprüft. Abgelehnte Alternativen: `embedded.mobileprovision` lesen (proprietär, in TestFlight-Bauten nicht belegt); beide Umgebungen melden (Dienst hält eine Zeile je Konto+Gerät, `server/migrations/008_device_tokens.sql:10`, die zweite überschriebe die erste); kein App-Teil, nur Holen bei Start/Vordergrund (fällt hinter PO-Entscheidung A zurück, ADR-21-Addendum Weckruf bliebe ohne Empfänger).

### Dependencies
Upstream: `AccountState.withSession`, `DeviceIdentity.current()`, `ServiceClient.send`, `ClaudeSync.pullOrders`/`sendTranscript`. Downstream: Dienst `/app/device` (S5a-1, live), Sender `apns.ts` (live seit S5b).

### Open Questions
- [x] Umgebung: Info-Marke + Archiv-Kreuzprüfung (technisch, Claude)
- [ ] Mac-Entitlement-Schlüssel im Archiv (in S5c-2b am CI-Lauf klären)
- [ ] CloudKit-Koexistenz nur auf dem Gerät belegbar (S5c-2a, Stufe 3)
Keine offene PO-Frage.

## Umfang nach RED (2026-11-15)

Nach RED: Tests 470 Zeilen (DeviceRegistrationTests 304, ClaudeSyncTriggerTests +166), mit Code ≈ 120 gesamt ≈ 590, über der Meldeschwelle 520 der Spec. Henning per AskUserQuestion: „So weiterbauen“. In /60-validate nicht erneut fragen, solange der Endstand nicht nennenswert über ≈ 620 liegt. (Commit dieser Notiz kommt mit der Umsetzung; in phase6 sperrt bash_gate Commits bis zum Adversary-Urteil.)
