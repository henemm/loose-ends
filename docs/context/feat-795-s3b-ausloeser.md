# Context: feat-795-s3b-ausloeser (#795 Schnitt S3b)

## Request Summary

Der Durchgang `ClaudeSync` aus S3a (Abschrift senden, Aufträge holen/ausführen/melden) wird zum ersten Mal aufgerufen: von
selbst beim Start, beim Wechsel in den Vordergrund und nach Änderungen, prozessweit verdrahtet in `LooseEndsApp`. Dazu ein
Debug-Weg gegen einen lokalen Dienst ohne Apple-Anmeldung und der Nachweis A/B mit zwei Simulatoren.
Planung aus `docs/context/feat-795-s3-claude-sync.md` (Abschnitt „Schnittvorschlag“, Zeile S3b) ist verbindlicher Ausgangspunkt.

## Related Files

| File | Relevance |
|------|-----------|
| `LooseEnds/Claude/ClaudeSync.swift` (160) | S3a: `sendTranscript()`, `pullOrders()`, `Ending`, `busy`-Sperre je Art; `init(account:container:device:execute:now:calendar:)`; noch kein Aufrufer |
| `LooseEnds/App/WidgetReload.swift` (90) | Vorbild: `@MainActor` prozessweit, `ModelContext.didSave` + CloudKit-Import (`isFinishedImport`), Entprellung `Task.sleep`, `start()` idempotent, unter Tests stumm außer mit eingereichter Closure |
| `LooseEnds/App/LooseEndsApp.swift` (214) | `init()` baut `widgetReload` (Z. 49) und `account = AccountWiring.forApp(...)` (Z. 59); hier wird der Auslöser gebaut und gestartet, nur wenn `account != nil` |
| `LooseEnds/Claude/AccountWiring.swift` (105) | `isEnabled` (`--ui-testing` immer an, sonst `LEAccountEnabled`), `serviceURL` (http nur localhost/127.0.0.1 im Debug), `forApp`; unter `--ui-testing` `UITestTransport`, der auf alles außer `auth/apple` 204 antwortet (also `claim` → 204, `transcript` → 204) |
| `LooseEnds/Claude/AccountState.swift` | `withSession` = einzige Tür; Status `signedIn` nur mit Token im Store |
| `LooseEnds/Claude/DeviceIdentity.swift` | `DeviceIdentity().current` = `device`-Closure für ClaudeSync |
| `LooseEnds/App/ContentView.swift:139` | einzige `scenePhase`-Reaktion, fensterbezogen; nicht als Auslöser geeignet (Mac im Menüband ohne Fenster) |
| `project.yml` (Z. 72–84) | `LEAccountEnabled: false`, `LEServiceURL` ungesetzt — **Pfad der Geräteliste**, nicht anfassen |
| `server/src/accounts.ts` | `findOrCreate`, `createSession` (Test-Helfer) — Weg zu einer Sitzung ohne Apple für den lokalen Nachweis |
| `server/src/orders.ts` | `putOrder` — Auftrag direkt einstellen (statt über MCP/OAuth) für den lokalen Nachweis |
| `server/scripts/test-local.sh` | Wegwerf-Postgres 18 auf freiem Port; Muster für ein lokales Start-Skript des Dienstes |
| `server/src/main.ts` | `npm start`; ohne `APPLE_*` läuft der Dienst, `/auth/apple` 503, App-Wege laufen |

## Existing Patterns

- Prozessweite Beobachter nach `WidgetReload` (#883): leben mit dem Prozess, nicht mit einem Fenster; `start()` einmal in `LooseEndsApp.init`.
- Test-Stummschaltung: `ModelContainerFactory.isRunningTests || isUITesting` → Standard-Aktion leer, Tests reichen eine Closure ein.
- Debug-only Startargumente: `-LEInitializeCloudKitSchema` (`#if DEBUG`, `CloudKitSchemaInitializer.shouldRun`).
- Unter `--ui-testing`: Konto immer an, `InMemorySessionStore`, `UITestTransport` ohne Netz.

## Dependencies

- Upstream: `ClaudeSync` (S3a), `AccountState.withSession`, `DeviceIdentity`, `ServiceClient`, `OrderExecutor`, `TranscriptCodec`.
- Downstream: S5 (Hintergrund-Auffrischen + Weckruf ruft denselben `pullOrders()`), #625 (Store-Schalter `LEAccountEnabled`).

## Existing Specs

- `docs/specs/feat-795-schnitt-3a-claude-sync.md` — der Durchgang, Ausgänge, Sperre.
- `docs/specs/feat-795-schnitt-2b-device-identity.md` — `DeviceIdentity`, `withSession`.
- `docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md` — Adressregel (http nur localhost im Debug).
- `docs/reference/claude-abschrift-vertrag.md` — Vertrag „Wege der App“, Mengengrenze (429 → Durchgang beenden).

## Recherche (2026-11-12)

- Vordergrund prozessweit: `scenePhase` ist im App-Körper ein Gesamtwert über Szenen, auf dem Mac für Lebenszyklus unzuverlässig;
  `NSApplication.didBecomeActiveNotification` bzw. `UIApplication.didBecomeActiveNotification` sind das robuste Signal
  ([Apple ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase.md),
  [Jesse Squires 2024](https://www.jessesquires.com/blog/2024/06/29/swiftui-scene-phase/),
  [Swift Forums](https://forums.swift.org/t/best-practice-on-handling-application-did-become-active/45766)). Zum reinen Menüband-Fall keine Quelle → im Simulator/Mac-Bau prüfen, bekannte Grenze bis S5.
- ATS und `http://127.0.0.1`/`localhost` im Simulator: Quellen alt und widersprüchlich
  ([Apple Forum 6205](https://developer.apple.com/forums/thread/6205), [NSAppTransportSecurity](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity.md)).
  Muss in der Analyse im Simulator nachgestellt werden; eine ATS-Ausnahme in `Info.plist` wäre ein Pfad der Geräteliste (Stufe 3) — vermeiden.

## Risks & Considerations

- **Erste echte Netzaufrufe:** Bisher sendet die App nichts. Mit S3b sendet jede App mit Sitzung beim Start, Vordergrund und Speichern.
  Im Store bleibt `LEAccountEnabled` aus → `account == nil` → kein Auslöser. Unter `--ui-testing` antwortet `UITestTransport` mit 204.
- **Rückkopplung:** `execute` speichert → `didSave` → Abschrift (gewollt, entprellt 2 s). Holen hängt nie an `didSave`.
- **Mengengrenze nginx** 10 r/s, Stoß 40: Entprellung 2 s, Holen max. 15 Aufträge, 429 beendet; Start + Vordergrund kurz hintereinander → `busy`.
- **Mac ohne Fenster:** Vordergrund nur bei Aktivierung der App; Aufträge kommen sonst erst mit S5.
- **Debug-Weg** (lokaler Dienst, Sitzung ohne Apple) nur `#if DEBUG`, nie im Release; kein `project.yml`/Info.plist-Eingriff.
- **Umfang:** Auslöser + Verdrahtung + Tests + Debug-Weg + lokales Dienst-Skript liegt bei ≈ 5 Dateien/≈ 300 LoC → in der Analyse
  ggf. teilen: S3b-1 Auslöser + Verdrahtung (unit-getestet), S3b-2 Debug-Weg + lokaler Dienst + A/B-Nachweis.

## Analysis

### Type
Feature (Schnitt S3b von #795: der Durchgang aus S3a bekommt seine Auslöser und den Nachweis A/B).

### Recherche-Ergebnis ATS (2026-11-12, entscheidet die Adresse des lokalen Dienstes)
Apple, [NSAllowsLocalNetworking](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking.md):
„In iOS 17, iPadOS 17, and macOS 14, ATS no longer allows connections to IP addresses by default.“ Unqualifizierte Namen
(`localhost`) und `.local` bleiben ohne Ausnahme erlaubt. Folge: der lokale Nachweis spricht `http://localhost:<port>`, **nie**
`http://127.0.0.1` — so braucht es keinen ATS-Schlüssel in der `Info.plist` (Pfad der Geräteliste). Die Annahme wird als erster
Schritt von S3b-2 im Simulator belegt (eine Anfrage an den lokalen Dienst kommt an); scheitert sie, wird vor dem Weiterbauen neu
entschieden. Simulatoren teilen das Netz des Macs, `localhost` im Simulator ist der Mac.

### Schnitt (Empfehlung: S3b in zwei Teile)
| Teil | Inhalt | Dateien | LoC (≈) |
|---|---|---|---|
| **S3b-1 Auslöser** | `ClaudeSyncTrigger` (`@MainActor`, prozessweit nach `WidgetReload`): beim Start und bei `didBecomeActive` (UIKit/AppKit, prozessweit) senden **und** holen; bei `ModelContext.didSave` und fertigem CloudKit-Import (Regel `WidgetReload.isFinishedImport`) nur senden, 2 s entprellt; Holen hängt nie an `didSave`. Aktionen als eingereichte Closures, unter Unit-/UI-Tests stumm außer mit eigener Closure. Verdrahtung in `LooseEndsApp.init` nur bei `account != nil` | `LooseEnds/Claude/ClaudeSyncTrigger.swift` CREATE (~90), `LooseEnds/App/LooseEndsApp.swift` MODIFY (~10), `LooseEndsTests/ClaudeSyncTriggerTests.swift` CREATE (~130) | ~230 |
| **S3b-2 Debug-Weg + A/B** | Nur `#if DEBUG`: Startargumente `-LEDebugService http://localhost:<port>` und `-LEDebugSession <token>` schalten das Konto ein (Adresse nach der bestehenden Regel `serviceURL`, Sitzung im `InMemorySessionStore`), ohne `project.yml`/`Info.plist`. Lokales Skript startet den Dienst gegen Wegwerf-Postgres (Muster `test-local.sh`), legt Konto + Sitzung an und stellt einen Auftrag ein. Nachweis: Simulator A sendet Abschrift → im Dienst lesbar; Auftrag → Simulator B führt ihn als Revision „Claude“ aus → Ergebnis im Dienst | `LooseEnds/Claude/AccountWiring.swift` MODIFY (~40), `LooseEndsTests/AccountWiringTests.swift` MODIFY (~60), `server/scripts/local-service.sh` CREATE (~60), `server/scripts/local-fixture.ts` CREATE (~60) | ~220 |

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/ClaudeSyncTrigger.swift` | CREATE | Beobachter: Start, `didBecomeActive`, `didSave`, Import; Entprellung; `start()` idempotent |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | `ClaudeSync` + Trigger bauen und starten, nur mit Konto |
| `LooseEndsTests/ClaudeSyncTriggerTests.swift` | CREATE | Benachrichtigungen posten → gezählte Closures; Entprellung; Holen nie bei `didSave`; doppeltes `start()` |
| `LooseEnds/Claude/AccountWiring.swift` | MODIFY (S3b-2) | Debug-Argumente für Dienst und Sitzung |
| `LooseEndsTests/AccountWiringTests.swift` | MODIFY (S3b-2) | Debug-Argumente; Release-Fall unverändert aus |
| `server/scripts/local-service.sh`, `server/scripts/local-fixture.ts` | CREATE (S3b-2) | lokaler Dienst, Konto/Sitzung/Auftrag ohne Apple |

### Scope Assessment
- S3b-1: 3 Dateien, ≈ +230 LoC; S3b-2: 4 Dateien, ≈ +220 LoC. Zusammen über der Grenze → zwei Schnitte.
- Risk Level: MEDIUM — erste echte Aufrufe der App an den Dienst. Begrenzt dadurch, dass `LEAccountEnabled` in jedem Store-Bau aus
  ist (`account == nil` → kein Auslöser) und ohne Sitzung `withSession` nichts sendet.
- Gerätestufe: kein Pfad der Geräteliste (`LooseEnds/Claude/`, `LooseEnds/App/`, `server/scripts/`).

### Technical Approach
`ClaudeSyncTrigger` hält zwei Closures `send`/`pull` (in der App `{ _ = await sync.sendTranscript() }` usw.), damit die Tests ohne
Netz und Konto zählen können. Vordergrund über `UIApplication.didBecomeActiveNotification` / `NSApplication.didBecomeActiveNotification`
(prozessweit, auch Mac ohne Fenster), nicht über `scenePhase` (fensterbezogen in `ContentView`, auf dem Mac unzuverlässig, Recherche im
Abschnitt oben). Beim Start und Vordergrund erst senden, dann holen; ausgeführte Aufträge speichern → `didSave` → Abschrift (entprellt),
so sieht Claude das Ergebnis. Die `busy`-Sperre in `ClaudeSync` fängt Start + Vordergrund kurz hintereinander ab. 2 s Entprellung, max.
15 Aufträge und 429 = Ende halten die nginx-Grenze (10 r/s, Stoß 40).

### Alternativen (verworfen)
- **`scenePhase` im App-Körper** statt Systembenachrichtigung: weniger Code, aber auf dem Mac im Menüband ohne Fenster unzuverlässig.
- **Nachweis über TestFlight mit echtem Apple-Konto** statt Debug-Weg: belegt den Live-Pfad, braucht aber Hennings Geräte und Anmeldung
  für jeden Lauf; bleibt für die Gerätestufe von S5.
- **Nur `UITestTransport`-Attrappe** statt lokalem Dienst: belegt die Kette nicht (Lehre aus #136).
- **ATS-Ausnahme `NSAllowsLocalNetworking`** für `127.0.0.1`: Pfad der Geräteliste, unnötig mit `localhost`.
- Keine ADR fällt; ADR-21 (Weg B) bleibt.

### Dependencies
`ClaudeSync` (S3a, PR #911 — muss vor S3b-1 auf main sein), `AccountState.withSession`, `DeviceIdentity`, `WidgetReload.isFinishedImport`.

### Open Questions
- keine PO-Frage (rein technischer Schnitt, keine sichtbare Änderung).
