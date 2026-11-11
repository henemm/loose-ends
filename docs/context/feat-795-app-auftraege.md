# Context: feat-795-app-auftraege (#795)

## Request Summary
Die App ist das andere Ende von Weg B (ADR-21): Ein Gerät mit verbundenem Konto schreibt die Abschrift in den Dienst, holt offene Aufträge, führt sie mit `OrderExecutor` als Nutzeränderung „Claude“ aus und meldet das Ergebnis. Ohne Konto kein einziger Aufruf an den Dienst.

## Stand in einem Satz
App-Bausteine (Codec, Executor, Client-Gerüst, Token-Ablage) und Datenbankfunktionen im Dienst existieren; es fehlen die HTTP-Wege im Dienst, ihre Freigabe in nginx, die Aufrufe in der App, der Auslöser in der App und jeder APNs-Code (App und Dienst).

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Services/TranscriptCodec.swift` | `TranscriptCodec.transcript(of:now:calendar:)` (L49) rein, `encode` (L86) sortedKeys/iso8601, `version = 1`, füllt `views` immer |
| `Shared/Services/OrderExecutor.swift` | `Order`/`OrderResult` (L8–38), `execute(_:in:now:calendar:) throws -> OrderResult` (L46), speichert selbst, Rollback bei Fehler |
| `LooseEnds/Claude/ServiceClient.swift` | nur `signIn`, `logout`, `deleteAccount`; `request(path:)` nur POST, 15 s; `send` bildet 401/503/URLError ab (L85–101) |
| `LooseEnds/Claude/AccountState.swift` | `@MainActor @Observable`; `client`/`store` privat, Token nur über privates `storedToken(in:)` (L132) — #795 braucht einen Zugang; 401 → `dropSession` (L115) |
| `LooseEnds/Claude/AccountWiring.swift` | `forApp` gibt nil, wenn `LEAccountEnabled` aus → Grundlage für „ohne Konto kein Netz“; `UITestTransport` antwortet allen Nicht-Auth-Pfaden 204 leer |
| `LooseEnds/Claude/KeychainSessionStore.swift`, `SessionStore.swift` | Token-Ablage, `SessionStoring` |
| `LooseEnds/App/LooseEndsApp.swift` | baut `account` (L59), `notifications.activate()` (L47), `widgetReload.start()` (L49), `BackgroundRefresh.register` (L53); Mac hat `MacAppDelegate`, iOS keinen `UIApplicationDelegateAdaptor` |
| `LooseEnds/App/WidgetReload.swift` | Muster für „bei Änderung“: `ModelContext.didSave` + fertiger CloudKit-Import, 1 s entprellt, Aktion injizierbar, unter Tests still |
| `LooseEnds/Notifications/DueNotificationCenter.swift` | einziger Mitteilungs-Delegate; keine Remote-Mitteilungen bisher |
| `LooseEnds/Notifications/BackgroundRefresh.swift` | `BGAppRefreshTask` täglich; Naht-Muster für Systemrückrufe außerhalb des Main Actors (#780) |
| `project.yml` | `aps-environment: development` (L70), `UIBackgroundModes: [remote-notification, fetch]` (L96), `LEAccountEnabled: false` (L84) |
| `server/src/transcripts.ts` | `checkTranscript` (L116), `putTranscript` → `stored`/`older` (L124) |
| `server/src/orders.ts` | `claimOrder(pool, account, device)` (L79, SKIP LOCKED, genau ein Gerät), `putResult` → `stored`/`duplicate`/`refused` (L91); `device` freier Text; kein Rückholen bei totem Gerät |
| `server/src/main.ts` | Routentabelle L208–217, exakter Pfadvergleich (L75), 1 MiB, `gated(isReady)` |
| `server/src/auth.ts`, `server/src/accounts.ts` | Muster App-Sitzung: `bearerToken` → `resolveSession` → 401 (`/auth/logout`, `/auth/delete`) |
| `docs/reference/claude-abschrift-vertrag.md` | Vertrag v1: Abschrift, sechs Auftragsarten, Ergebnis, Vergabe an genau ein Gerät |
| `docs/reference/datenschutz-entwurf.md:171`, `PrivacyInfo.xcprivacy` | Absatz zur Übertragung der Abschrift und „Other User Content“ kommen laut S4e mit #795 |

## Existing Patterns
- Rand im Dienst: Route-Objekt in der Tabelle, Bearer → `resolveSession` → Konto; jede Ablehnung nackte 401; Körper beim Lesen gezählt.
- App-Netz: `ServiceClient` über austauschbaren `HTTPTransport`; Fehler als `ServiceError`, nie Token im Fehler.
- Beobachtung: `WidgetReload` (didSave + fertiger Import, entprellt, injizierbar, still unter Tests).
- Systemrückrufe: `@Sendable`-Nahtstellen ohne Main-Actor-Bindung (#780).
- Nichts geht ohne Tippen raus; Konto-Gruppe nur mit `LEAccountEnabled`.

## Dependencies
- Upstream: `ViewRules` (über Codec), `CaptureService`/`TaskActions` (über Executor), `KeychainSessionStore`, Postgres-Funktionen des Dienstes.
- Downstream: MCP-Werkzeuge (`get_now`, `get_view`, Auftrags-Werkzeuge #622) lesen die Abschrift und warten auf Ergebnisse; #622-DoD (Beleg aus claude.ai) hängt an #795; #625 (Datenschutz/Store) folgt.

## Existing Specs
- `docs/specs/spike-613-schnitt-1-abschrift-auftraege.md`, `-c3a-abschrift-annehmen` (HTTP in C3 bewusst verschoben), `-c3b-auftraege` (device als übergebener Text „bis C6“, Rückholen später „C7“)
- `docs/specs/feat-615-schnitt-*` (4b2…4d nennen #795: „Abschrift hochladen mit dem Sitzungstoken aus der Ablage“; 4e: Datenschutzabsatz + PrivacyInfo mit #795)
- `docs/specs/feat-621-schnitt-6b-*` (Türregel endet mit #625)
- ADR-21 in `docs/project/00-entscheidungen.md` L308–328: „bis dahin ruft die App den Dienst nirgends auf“

## Risks & Considerations
- **Umfang:** Dienst-Routen + nginx (henemm-infra) + App-Client + Auslöser + APNs (App-Registrierung und Versand im Dienst mit Apple-Schlüssel) + Datenschutz/PrivacyInfo — weit über 4–5 Dateien; muss in Schnitte.
- **Gerätekennung:** `device` ist freier Text; die App braucht eine stabile, nicht persönliche Kennung je Installation.
- **Hängender Auftrag:** Ein Gerät, das einen Auftrag holt und abstürzt, hält ihn ohne Rückholregel für immer.
- **Datenschutz:** Abschrift verlässt das Gerät erstmals; Text auf henemm.com und `PrivacyInfo.xcprivacy` müssen vor externem Nutzer stimmen; Schalter `LEAccountEnabled` bleibt bis #625 aus.
- **APNs:** neuer Apple-Schlüssel und Versandcode im Dienst; Simulator kann echte Remote-Mitteilungen nicht empfangen (nur `.apns`-Datei) → Weckruf als eigener Schnitt, Holen beim Start/Vordergrund reicht für den A/B-Nachweis.
- **Stufe 3:** `LooseEnds/Notifications/` und ggf. `project.yml` berühren die Geräteliste → TestFlight-Lauf nötig.
- **Konflikte:** `ModelContext` im Executor auf dem Main Actor; Abschrift-Senden nach eigener Auftragsausführung (Schleife vermeiden, nur entprellt).
- **Tür:** `ALLOWED_APPLE_SUBS` lässt nur Hennings Konto zu — für den Nachweis im Simulator lokaler Dienst.

## Analysis

### Type
Feature (App-Seite von Weg B, ADR-21). Zu groß für einen Schnitt: Dienst-Wege, App-Client, Auslöser, Datenschutz und Weckruf berühren je eigene Dateigruppen.

### Recherche (2026-11-11)
- Stille Mitteilungen: `aps` nur mit `content-available`, Kopf `apns-push-type: background`, `apns-priority: 5`; Zustellung wird gedrosselt und ist nie garantiert
  ([Apple: Pushing background updates](https://developer.apple.com/tutorials/data/documentation/usernotifications/pushing-background-updates-to-your-app.md),
  [Apple Forum 835645](https://origin-devforums.apple.com/forums/thread/835645), [Apple Forum 126540](https://developer.apple.com/forums/thread/126540)).
  Folge: Der Weckruf ist eine Beschleunigung, nie der einzige Weg; Holen beim Start/Vordergrund/Hintergrund-Auffrischen bleibt Pflicht.

### Schnitte (je eigener Workflow-Durchlauf bzw. Teil-Spec, je ≤ 4–5 Dateien, ±250 LoC)
| Schnitt | Inhalt | Dateien (Change) | Gerätestufe |
|---|---|---|---|
| **S1 Dienst-Wege für die App** | `POST /app/transcript` (→ `putTranscript`, 204/400), `POST /app/orders/claim` (→ `claimOrder`, 200 Auftrag / 204 keiner), `POST /app/orders/result` (→ `putResult`, 204 stored/duplicate, 409 refused); Bearer = App-Sitzung (`bearerToken` → `resolveSession`, jede Ablehnung nackte 401), Gerät im Kopf `X-Device` (UUID, sonst 400), Körper ≤ 256 KiB beim Lesen gezählt, `gated(isReady)`; Rückholregel: ein Auftrag, dessen Vergabe älter als 10 min ohne Ergebnis ist, wird beim nächsten `claim` wieder frei (`claimOrder` erweitert, `putResult` des alten Geräts dann `refused`) | `server/src/app-routes.ts` CREATE, `server/src/orders.ts` MODIFY, `server/src/main.ts` MODIFY, `server/test/app-routes.test.ts` CREATE, `docs/reference/claude-abschrift-vertrag.md` MODIFY | nein |
| S1b nginx (henemm-infra) | `/app/` freigeben (Zone wie `loose_ends_auth`, 256k) | Infra-Repo, 1 Datei | nein |
| **S2 App-Client** | `ServiceClient.putTranscript/claimOrder/putResult` (JSON über `TranscriptCodec.encode`/`Order`/`OrderResult`), Gerätekennung je Installation (zufällige UUID in `UserDefaults`, nicht in iCloud), `AccountState` gibt einen Aufruf mit Token her, ohne das Token herauszureichen (401 → `dropSession`) | `ServiceClient.swift`, `AccountState.swift` MODIFY, `DeviceID.swift` CREATE, Tests 1–2 | nein |
| **S3 Auslöser `ClaudeSync`** | nach Muster `WidgetReload`: Abschrift senden bei `didSave`/fertigem Import (entprellt 2 s) und im Hintergrund-Auffrischen; Aufträge holen beim Start und beim Wechsel in den Vordergrund: claim → `OrderExecutor.execute` (Main Actor) → result, bis keiner mehr da ist; nur wenn `AccountState` angemeldet, sonst kein Aufruf; still unter Tests außer mit Ersatz-Transport. Nachweis A/B: lokaler Dienst, zwei Simulatoren | `LooseEnds/Claude/ClaudeSync.swift` CREATE, `LooseEndsApp.swift` MODIFY, Tests, ggf. `BackgroundRefresh.swift` (Gerätepfad? nein, `LooseEnds/Notifications/` → ja, wenn berührt) | nur wenn `Notifications/` berührt |
| S4 Datenschutz | Absatz „Abschrift“ im Text + `PrivacyInfo.xcprivacy` „Other User Content“; Text braucht Hennings Freigabe und die Website-Seite | Doku, Website-Repo, `PrivacyInfo` | ja (Info/Plist-Klasse) |
| S5 Weckruf | App: `registerForRemoteNotifications`, Gerätetoken an `POST /app/push-token`; Dienst: APNs-Versand (Token-Auth mit `.p8`-Schlüssel, `background`, Priorität 5) nach `putOrder` | App-Delegate/`DueNotificationCenter`, Dienst `apns.ts`, Migration, Schlüssel in henemm-infra | ja (`LooseEnds/Notifications/`, TestFlight) |

S1 → S2 → S3 ist die Reihenfolge für den A/B-Nachweis der DoD; S4 vor dem Einschalten von `LEAccountEnabled` (#625); S5 zuletzt.

### Scope Assessment (gesamt)
- Dateien: ca. 18 über 5–6 Schnitte; erster Schnitt S1: 5 Dateien, geschätzt +230/−10 LoC (davon ~120 Tests)
- Risk Level: MEDIUM — Dienst ist live und öffentlich; neue Wege nur mit gültiger App-Sitzung, Tür (`ALLOWED_APPLE_SUBS`) lässt nur Hennings Konto zu.

### Technical Approach (S1)
Eigene Routendatei wie `auth.ts`; Sitzung genau wie `/auth/logout` geprüft; Antworten ohne Körper außer dem Auftrag; Fehlerform des Vertrags (`checkTranscript`/`checkResult` werfen → 400 ohne Details nach außen). Rückholregel als Teil der einen `UPDATE`-Anweisung (`claimed_by IS NULL OR (claimed_at < now() - interval '10 minutes' AND NOT EXISTS result)`), Zeit aus der Datenbank. Eine Abschrift je Konto (nicht je Gerät): das zuletzt berechnete gewinnt (`generatedAt`), wie in C3a.

### Alternativen
- **Kein Weckruf, Mac als ständiger Ausführer:** Die Mac-App läuft im Menüband ohnehin dauernd; sie könnte jede Minute Aufträge holen. Spart APNs (Schlüssel, Versandcode, Drosselung), aber ohne eingeschalteten Mac warten Aufträge bis zum nächsten App-Start. Fiele: Entwurf „stille Mitteilung“ in #795.
- **Abholen statt Abgeben (Long-Poll/WebSocket):** App hält im Vordergrund eine offene Verbindung; im Hintergrund wirkungslos, also nur Ergänzung.
- **Abschrift je Gerät statt je Konto:** würde widersprüchliche Stände zweier Geräte sichtbar machen; verworfen, weil iCloud die Geräte ohnehin angleicht und `generatedAt` den neueren nimmt (ADR-21 bleibt).

### Dependencies
`resolveSession`/`bearerToken` (auth), `putTranscript`/`claimOrder`/`putResult` (Dienst), `TranscriptCodec`/`OrderExecutor` (App), `KeychainSessionStore`; nginx in henemm-infra; #625 für Datenschutz/Store.

### Open Questions
- keine für S1 (rein technisch). Für S4 kommt der Datenschutz-Wortlaut zu Henning; für S5 die Wahl Weckruf vs. „Mac als Ausführer“ als Produktfrage, wenn S3 läuft.

## Umfangsfreigabe S1 (2026-11-11)
Henning per Auswahl vor der Spec-Freigabe: „Annehmen, so bauen“ — rund 460 zählende Zeilen (Code ≈125, Tests ≈330) statt 250. Meldeschwelle: Tests nach RED > 380 oder Endstand > 520 → erneut fragen. In /60-validate nicht erneut fragen, solange darunter.

Nach RED (2026-11-11): 464 Testzeilen, über der Meldeschwelle 380; erneut gefragt, Henning „So lassen“ (AC-13/AC-15 bleiben in S1, Issue-Kommentar #795). Neue Grenze für /60-validate: Endstand bis ≈590 zählende Zeilen ohne erneute Frage.
