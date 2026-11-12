# Context: feat-795-s3-claude-sync

## Request Summary
#795 Schnitt S3: der Auslöser `ClaudeSync`, der die fertigen Bausteine aus S2a/S2b zum ersten Mal aufruft — Abschrift senden,
Aufträge holen, mit `OrderExecutor` als Nutzeränderung „Claude“ ausführen, Ergebnis melden. Nur mit angemeldetem Konto, sonst
kein einziger Aufruf. Liefert den A/B-Nachweis der DoD von #795 (Abschrift von Simulator A, Auftrag auf Simulator B ausgeführt).

Plan aus `docs/context/feat-795-app-auftraege.md` Z. 74: nach Muster `WidgetReload`; senden bei `didSave`/fertigem Import
(entprellt 2 s) und im Hintergrund-Auffrischen; holen beim Start und beim Wechsel in den Vordergrund: claim → `execute`
(Main Actor) → result, bis keiner mehr da ist; still unter Tests außer mit Ersatz-Transport.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/App/WidgetReload.swift` (90) | Vorbild: prozessweite Klasse, `ModelContext.didSave` + CloudKit-Import (`isFinishedImport`), Entprellung per `Task.sleep`, `start()` idempotent, unter Tests stumm außer mit eingereichter Closure |
| `LooseEnds/App/LooseEndsApp.swift` (214) | `init()` baut `account` (`AccountWiring.forApp`, nil bei Schalter aus) und startet `widgetReload`; hier wird `ClaudeSync` gebaut und gestartet (MODIFY) |
| `LooseEnds/Claude/AccountState.swift` | `withSession` (Z. 117): einziger Zugang, nil ohne `signedIn`/Token, 401 räumt Sitzung und wirft `unauthorized` weiter |
| `LooseEnds/Claude/ServiceClient.swift` | `putTranscript`, `claimOrder` → `Claim` (`.none`/`.order`/`.unreadable(id)`), `putResult`; Fehler `tooManyRequests` (429), `refused` (409), `unavailable` (503), `unauthorized` |
| `LooseEnds/Claude/DeviceIdentity.swift` | `current()` wirft bei Schlüsselbund-Fehler (vor erstem Entsperren) oder kaputtem Eintrag → Durchgang beenden |
| `LooseEnds/Claude/AccountWiring.swift` | `isEnabled` (nur `--ui-testing` oder `LEAccountEnabled` true), `serviceURL` (http://localhost nur im Debug-Bau), `UITestTransport` (kennt bisher nur `/auth/*`) |
| `Shared/Services/OrderExecutor.swift` | `execute(_:in:now:calendar:) throws -> OrderResult`, speichert selbst, Rollback bei Fehler; `refuse` liefert `rejected` + Grund |
| `Shared/Services/TranscriptCodec.swift` | `transcript(of:now:calendar:)` rein, aus allen `TaskItem` |
| `LooseEnds/Notifications/BackgroundRefresh.swift` | Hintergrund-Auffrischen (iOS); Einhängen dort = Pfad der Geräteliste → Stufe 3 |
| `LooseEnds/App/ContentView.swift:139` | einzige `scenePhase`-Reaktion, an ein Fenster gebunden (Mac im Menüband ohne Fenster!) |
| `docs/reference/claude-abschrift-vertrag.md` Z. 162–200 | Wege der App: 204 bei älterer Abschrift, Rückholen nach 10 min, 429 → Durchgang sofort abbrechen, kein Wiederholen |
| `server/scripts/test-local.sh` | Wegwerf-Postgres; Grundlage für einen lokalen Dienst beim A/B-Nachweis |
| Tests: `LooseEndsTests/ServiceClientTests.swift`, `OrderExecutorTests.swift`, `TranscriptCodecTests.swift`, `AccountState…Tests` | Stellvertreter-Transport und In-Memory-Store als Muster für `ClaudeSyncTests` |

## Existing Patterns
- Prozessweite Beobachter auf App-Ebene (`WidgetReload`, #883), nicht an Fenster gebunden — gilt hier auch: der Mac läuft ohne Fenster.
- Reine Regel + dünne Verdrahtung; Systemzugriffe hinter Protokollen (`HTTPTransport`, `KeychainOperations`, `RefreshTask`).
- Unter `isRunningTests`/`isUITesting` still, außer eine Test-Naht wird eingereicht.
- Fehler nie verschlucken (`Logger`, kein `try?`), kein Token/Körper im Log.

## Dependencies
- Upstream: `AccountState.withSession`, `ServiceClient` (S2a), `DeviceIdentity` (S2b), `OrderExecutor`, `TranscriptCodec`, `ModelContainer.mainContext`.
- Downstream: S5 Weckruf (ruft denselben Abholdurchgang auf), S4 Datenschutz/#625 (Schalter `LEAccountEnabled`).

## Existing Specs
- `docs/specs/feat-795-schnitt-2a-app-client.md` (Reaktionen: 429 Abbruch, `.unreadable` → `rejected/invalid`, `refused` verwerfen)
- `docs/specs/feat-795-schnitt-2b-device-identity.md` (`unauthorized` → Durchgang beenden; Kennungsfehler → beim nächsten Anlass)
- `docs/specs/feat-795-schnitt-1-dienst-wege.md`, `docs/reference/claude-abschrift-vertrag.md`

## Risks & Considerations
- **Gerätepfad:** Einhängen ins Hintergrund-Auffrischen berührt `LooseEnds/Notifications/` → Stufe 3 (TestFlight). Alternative:
  S3 ohne Hintergrund (senden bei Speichern/Import/Vordergrund, holen bei Start/Vordergrund), Hintergrund mit S5 zusammen —
  dann bleibt S3 bei Stufe 2.
- **Vordergrund auf dem Mac:** `scenePhase` hängt am Fenster; prozessweit `UIApplication`/`NSApplication.didBecomeActiveNotification`.
- **Rückkopplung:** `execute` speichert → `didSave` → Abschrift senden. Gewollt (Claude sieht das Ergebnis), aber entprellt;
  ein Durchgang darf nicht sich selbst neu auslösen (Holen nur an Start/Vordergrund, nicht an `didSave`).
- **Mengengrenze:** Abholschleife braucht eine Obergrenze je Durchgang; 429 bricht sofort ab; keine parallelen Durchgänge (Wiedereintrittssperre).
- **Mindestens einmal:** `capture` kann nach Rückholen doppelt erfasst werden (Vertrag (c)); bekannte Grenze, kein Fix in S3.
- **`refused` (409) beim Melden:** Ergebnis verwerfen; die lokale Änderung bleibt (der Dienst hat den Auftrag an ein anderes Gerät gegeben, das `stale` erhält).
- **Fehler beim Ausführen** (`execute` wirft, z. B. Speichern scheitert): kein Ergebnis melden → Dienst holt nach 10 min zurück; nicht als `invalid` melden.
- **A/B-Nachweis:** braucht lokalen Dienst mit gültiger Sitzung ohne Apple-Anmeldung (Sitzung direkt in der Wegwerf-DB anlegen) und
  einen Weg, das Konto im Debug-Bau außerhalb `--ui-testing` einzuschalten (`LEAccountEnabled` per Startargument/Umgebung nur im Debug,
  `LEServiceURL` auf `http://localhost`); `UITestTransport` kennt die App-Wege noch nicht.
- **Umfang:** `ClaudeSync.swift` + App-Verdrahtung + Tests + ggf. Debug-Schalter liegt nahe an 250 LoC; ggf. S3a (Durchgang, rein testbar) / S3b (Auslöser + A/B) teilen.
- **Ohne Konto kein Aufruf:** `account == nil` (Schalter aus) → `ClaudeSync` wird gar nicht gebaut; `signedOut` → `withSession` gibt nil ohne Netz.

## Analysis

### Type
Feature (App-Seite von Weg B, ADR-21), Schnitt S3 von #795.

### Recherche (2026-11-12)
- `scenePhase` im `App`-Körper ist ein Gesamtwert über alle Szenen („active, wenn eine Szene aktiv ist“), im View nur der eigenen Szene
  ([Apple: ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase.md), [Forum 747848](https://developer.apple.com/forums/thread/747848),
  [Forum 764132](https://developer.apple.com/forums/thread/764132): seit iOS 18 feuert `onChange` öfter).
- Eine Mac-App nur im Menüband hat keine Fenster-Szene; `scenePhase` kommt dort nicht zuverlässig an, ein Öffnen des `MenuBarExtra` ist nicht
  beobachtbar ([Forum 721627](https://developer.apple.com/forums/thread/721627), [Jesse Squires](https://www.jessesquires.com/blog/2024/06/29/swiftui-scene-phase/)).
  Folge für S3b: Vordergrund prozessweit über `NSApplication.didBecomeActiveNotification` / `UIApplication.didBecomeActiveNotification`
  im Muster von `WidgetReload`, nicht über `ContentView.scenePhase`; auf dem Mac ohne Fenster holt die App erst beim nächsten Aktivieren (bekannte Grenze, S5).

### Befunde aus dem Code
- **Endlosschleife bei Ausführungsfehler:** Wirft `OrderExecutor.execute` (Speichern scheitert), meldet die App kein Ergebnis. Der Dienst gibt
  denselben Auftrag demselben Gerät beim nächsten `claim` sofort zurück (Vertrag (d)). Eine Schleife „holen, bis keiner mehr da ist“ liefe
  dann im selben Durchgang endlos → **Ausführungsfehler beendet den Durchgang** (kein Ergebnis, Rückholung nach 10 min).
- **Obergrenze je Durchgang:** nginx-Stoß 40 Anfragen; je Auftrag 2 Anfragen (claim + result), dazu Abschrift und letztes `claim` →
  höchstens **15 Aufträge je Durchgang** (≤ 32 Anfragen), Rest beim nächsten Anlass.
- **Wiedereintritt:** ein Durchgang zur Zeit (Main Actor, Flag); ein Anlass während eines Durchgangs verfällt (holen) bzw. setzt „noch einmal
  senden“ (Abschrift).
- **Rückkopplung:** `execute` speichert → `didSave` → entprellte Abschrift. Gewollt; Holen hängt nie an `didSave`.
- `UITestTransport` antwortet auf jeden Nicht-`auth/apple`-Pfad 204 → unter UI-Tests wäre ein Durchgang harmlos (`claim` → `.none`); trotzdem
  bleibt `ClaudeSync` unter Tests stumm, außer ein Transport/eine Naht wird eingereicht (wie `WidgetReload`).
- `UITestTransport` hat keine App-Wege mit Aufträgen; der A/B-Nachweis braucht einen lokalen Dienst (`server/scripts/test-local.sh`) und im
  Debug-Bau einen Weg, Konto + `http://localhost` + Sitzung ohne Apple einzuschalten.

### Reaktionstabelle des Durchgangs (aus S2a/S2b und Vertrag)
| Fall | Reaktion |
|---|---|
| `withSession` → nil (nicht angemeldet) | nichts, kein Aufruf |
| `unauthorized` | Durchgang beenden (Sitzung räumt `AccountState`) |
| `tooManyRequests` (429) | Durchgang sofort beenden, auch keine Abschrift mehr, keine Wiederholung |
| `unavailable`, `invalidResponse`, `rejected(_)`, `CancellationError` | Durchgang beenden, nächster Anlass |
| `DeviceIdentity.current()` wirft | Durchgang beenden |
| `.none` | Durchgang fertig |
| `.order` | `execute` (Main Actor) → `putResult` |
| `.unreadable(id)` | `putResult(rejected, invalid)` |
| `execute` wirft | kein Ergebnis, Durchgang beenden |
| `putResult` → `refused` (409) | Ergebnis verwerfen, weiter holen |
| 15 Aufträge erreicht | Durchgang beenden |

### Schnittvorschlag (Empfehlung)
| Schnitt | Inhalt | Dateien | Gerätestufe |
|---|---|---|---|
| **S3a Durchgang** | `ClaudeSync` mit `sendTranscript()` (alle `TaskItem` → `TranscriptCodec` → `putTranscript`) und `pullOrders()` (Schleife nach Tabelle oben, Obergrenze 15, Wiedereintrittssperre); Abhängigkeiten eingereicht (`AccountState`, `DeviceIdentity`-Naht, `ModelContainer`, Uhr); nichts ruft ihn auf | `LooseEnds/Claude/ClaudeSync.swift` CREATE (~120), `LooseEndsTests/ClaudeSyncTests.swift` CREATE (~200) | nein, Stufe 2 entfällt mangels Bedienweg (reine Logik, wie S2a/S2b) |
| **S3b Auslöser + A/B** | Beobachter nach `WidgetReload`: senden bei `didSave`/fertigem Import (2 s entprellt) und beim Start; holen beim Start und bei `didBecomeActive` (prozessweit, iOS und Mac); Verdrahtung in `LooseEndsApp`; Debug-Schalter für lokalen Dienst und Sitzung ohne Apple; Nachweis A/B mit zwei Simulatoren gegen `test-local.sh` | `ClaudeSync.swift` MODIFY, `LooseEndsApp.swift` MODIFY, `AccountWiring.swift` MODIFY, Tests | nein (kein Pfad der Geräteliste) |
| S5 (bestehend) | Hintergrund-Auffrischen **und** Weckruf zusammen | `LooseEnds/Notifications/` | ja |

Hintergrund-Auffrischen wandert aus S3 nach S5: beides liegt in `LooseEnds/Notifications/` und braucht ohnehin TestFlight; S3 bleibt so ohne Gerätestufe.

### Affected Files (S3a)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/ClaudeSync.swift` | CREATE | `@MainActor final class ClaudeSync`: `sendTranscript()`, `pullOrders()`, `maxOrdersPerPass = 15`, Sperre, `Logger` nur mit Fallnamen |
| `LooseEndsTests/ClaudeSyncTests.swift` | CREATE | `FakeTransport` mit Antwortfolge, In-Memory-Container und -Store; je Zeile der Reaktionstabelle ein Test, „ohne Konto keine Anfrage“, Revision „Claude“ nach Ausführung |
| `LooseEnds/Claude/DeviceIdentity.swift` | evtl. MODIFY | nur falls für die Testnaht ein Protokoll nötig ist (sonst Closure `() throws -> UUID` in `ClaudeSync`) |

### Scope Assessment
- S3a: 2–3 Dateien, ≈ +320 LoC (Code ≈ 120, Tests ≈ 200) — über 250 nur durch Tests, wie S2a/S2b; Meldeschwelle wie dort.
- Risk Level: LOW für S3a (nichts ruft ihn auf, kein Netz ohne Sitzung); MEDIUM für S3b (erste echte Aufrufe an den Live-Dienst, aber nur mit
  Schalter `LEAccountEnabled`, der in jedem Store-Bau aus ist).

### Technical Approach
S3a als reiner, vollständig getesteter Durchgang; Auslöser und Nachweis in S3b. `ClaudeSync` hält `AccountState`, `ModelContainer`, eine
Gerätekennungs-Closure und eine Uhr; jeder Netzaufruf geht über `account.withSession`. Ausführen auf `container.mainContext` (Main Actor),
`now`/`calendar` eingereicht. Fehlerfälle als Fallname loggen (Muster `AccountState.caseName`), nie Text, Token oder Körper.

### Alternativen
- **Ein Schnitt S3 (Durchgang + Auslöser + A/B):** ≈ 450 LoC, 4–5 Dateien; Nachweis früher, aber Testdatei und Verdrahtung in einem Review. Verworfen wegen Umfang.
- **Abschrift im Takt statt bei jedem Speichern** (z. B. höchstens einmal je Minute): weniger Anfragen, aber Claude sieht Änderungen bis zu einer Minute
  später; bei 2 s Entprellung und 10 r/s am nginx unnötig. Keine ADR betroffen.
- **Mac als ständiger Ausführer** (Menüband-App holt jede Minute): ersetzt den Weckruf S5 für Nutzer mit laufendem Mac; fiele: Entwurf „stille Mitteilung“
  in #795. Produktfrage, kommt mit S5, nicht jetzt.

### Dependencies
`AccountState.withSession`, `ServiceClient` (S2a), `DeviceIdentity` (S2b), `OrderExecutor`, `TranscriptCodec`; Downstream S3b, S5.

### Open Questions
- keine für S3a (rein technisch, keine Produktentscheidung).

## PO-Entscheidung Umfang (2026-11-12)

Henning hat in /30-write-spec per AskUserQuestion „Annehmen“ gewählt: S3a mit ≈ 570 LoC (Code ≈ 130, Tests ≈ 440) in einem Schritt. Meldeschwelle 650 LoC: liegt der Stand nach RED oder GREEN darüber, erneut fragen; darunter in /60-validate nicht erneut fragen.
