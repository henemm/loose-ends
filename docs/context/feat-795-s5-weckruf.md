# Context: feat-795-s5-weckruf

## Request Summary
#795 Schnitt S5 „Weckruf“: Legt Claude einen Auftrag an, weckt der Dienst die Geräte des Kontos per stiller Mitteilung (APNs, `content-available`), damit die App ihren `ClaudeSync`-Durchgang fährt, ohne dass Henning sie öffnet. Letztes Baustück von #795 (S1–S3b-2 gemergt).

## Related Files
| File | Relevance |
|------|-----------|
| server/src/orders.ts:69 | `putOrder` — einzige Stelle, an der ein Auftrag entsteht; Weckruf nur bei `"stored"` |
| server/src/mcp.ts:86, :111–117 | Aufrufer von `putOrder` (capture, `storing` für alle Änderungswerkzeuge) — Sender muss hierher gereicht werden |
| server/src/app-routes.ts:8–106 | Muster für einen neuen Weg `POST /app/device` (`admitted` mit `device`, `jsonBody`, 204) |
| server/src/apple-client.ts:27–36, server/src/apple.ts:21 | ES256-JWT mit `node:crypto` (`ieee-p1363`), `createPrivateKey` — Vorlage für den APNs-Anbieter-Token |
| server/src/main.ts:45–47, :144, :273 | `APPLE_VARS`/`appleConfigFromEnv` (alles-oder-nichts) — Vorlage für `APNS_*`; `mountApp` hängt `appRoutes` ein |
| server/migrations/ | nächste Nummer 008; kein Gerätetabelle bisher, Gerät nur als `reported_by` |
| LooseEnds/App/LooseEndsApp.swift:8, :63 | nur `NSApplicationDelegateAdaptor` (Mac); iOS hat keinen App-Delegate — nötig für Token und `didReceiveRemoteNotification` |
| LooseEnds/Mac/MenuBarCapture.swift | `MacAppDelegate` — Mac-Gegenstück |
| LooseEnds/Claude/ClaudeSyncTrigger.swift:43–131 | Auslöser; kein öffentlicher Eingang „einmal holen und Bescheid geben“ (für `fetchCompletionHandler`) |
| LooseEnds/Claude/ServiceClient.swift:98–142 | Muster für `registerDevice` |
| LooseEnds/Notifications/DueNotificationCenter.swift:19 | einziger `UNUserNotificationCenterDelegate`, nur lokale Mitteilungen |
| project.yml:70, :92–96 | `aps-environment` und `remote-notification` schon vorhanden (CloudKit) |
| docs/reference/claude-abschrift-vertrag.md:162–195 | „Wege der App“; neuer Weg muss hinein; nginx lässt nur drei `/app/`-Pfade durch (henemm-infra) |
| docs/specs/feat-795-schnitt-1-dienst-wege.md:148, :169 | S5 nur als Stichwort geplant |

## Existing Patterns
- Dienst: optionale Fähigkeit per Umgebungsvariablen alles-oder-nichts, Fehler nennt nur den Variablennamen, Start bricht bei halber Konfiguration ab.
- Dienst: App-Wege mit Sitzung + `X-Device`, Körper beim Lesen gezählt, nur Statuscodes, keine Geheimnisse im Log.
- App: Abhängigkeiten werden hineingereicht (`ClaudeSync`, `HTTPTransport`), unter `--ui-testing` kein Netz.
- App: ohne Konto kein einziger Aufruf an den Dienst (DoD #795).

## Dependencies
- Upstream: Apple APNs (HTTP/2, `api.push.apple.com` / `api.sandbox.push.apple.com`), ein .p8-Schlüssel mit APNs-Recht (ob der vorhandene `SF83PT3Q22` es hat, ist offen), `AccountState.withSession`, `DeviceIdentity`.
- Downstream: `ClaudeSync`-Durchgang, nginx-Erlaubnisliste in henemm-infra, Vertrag „Wege der App“, Konto löschen (`deleteAccount` muss Gerätetokens mitnehmen).

## Existing Specs
- docs/specs/feat-795-schnitt-1-dienst-wege.md, -1b-nginx, -2a-app-client, -2b-device-identity, -3a-claude-sync, -3b1-ausloeser, -3b2-debug-weg

## Risks & Considerations
- **Zustellung nicht garantiert:** Apple drosselt stille Mitteilungen (Faustregel 2–3 pro Stunde, Gerät entscheidet nach Akku und Nutzung); eine weggewischte App bekommt keine. Der Weckruf beschleunigt nur, ersetzt Start/Vordergrund nicht. Quellen: developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app, developer.apple.com/forums/thread/827460, developer.apple.com/forums/thread/757094.
- **Zusammenleben mit CloudKit:** CloudKits Mitteilungen landen ebenfalls in `didReceiveRemoteNotification`; der Handler muss eigene Weckrufe am Inhalt erkennen und den Rest unangetastet lassen (TN3163).
- **Umgebung:** TestFlight/Store = APNs Produktion, Xcode-Läufe = Sandbox; `aps-environment` steht im Projekt auf `development` und wird beim Archivieren umgestellt — der Dienst muss je Token wissen, welche Umgebung gilt.
- **Gerätepfad:** `LooseEnds/Notifications/`, `project.yml` → Stufe 3 über TestFlight; im Simulator lässt sich eine stille Mitteilung per `simctl push` einspielen.
- **Umfang:** Dienst (Migration, Weg, Sender, Konfiguration) und App (Delegate, Registrierung, Eingang) übersteigen zusammen 250 LoC → mindestens zwei Teilschnitte (Dienst / App).
- **Alternative ohne Push:** Hintergrund-Auffrischung (`BGAppRefreshTask`) holt periodisch — kein Dienstteil, aber noch unzuverlässiger im Takt; oder gar kein Weckruf (Abholen beim Öffnen genügt fürs Epic-DoD).

## Analysis

### Type
Feature (Schnitt S5 von #795; der Weckruf steht im Entwurf des Tickets, nicht in seiner Definition of Done)

### Befund
- Der vorhandene Apple-Schlüssel `SF83PT3Q22` kann nur Sign in with Apple (`docs/artifacts/feat-621-s6b-betrieb/apple-portal.md`); APNs braucht einen neuen Schlüssel, also eine Portal-Anmeldung Hennings.
- `capture_task`/`putOrder` antworten `state: "waiting"`, `get_order_result` nennt das „wartet auf ein Gerät“ (`server/src/mcp.ts:87, :118, :254`) — Claude sagt das Warten also schon.
- `ClaudeSyncTrigger` holt nur bei Start und `didBecomeActive`; die Mac-Menüleisten-App läuft dauernd, wird aber selten aktiv → ein Auftrag aus Claude auf dem Mac wartet, bis das Fenster nach vorn kommt.
- `pullOrders` liefert bei laufendem Durchgang `.busy`; ein neuer Auslöser hängt sich über `pullAfterSend`/`drain()` ein (`ClaudeSyncTrigger.swift:102–139`), nicht direkt an `pull()`.

### Varianten
| | A Stille Mitteilung (APNs) | B Mac holt im Takt (+ iOS Hintergrund) | C Nichts, Holen beim Öffnen |
|---|---|---|---|
| Umfang | 2–3 Schnitte, Dienst ≈ 230 LoC + App ≈ 200 LoC, nginx in henemm-infra | 1 Schnitt, 2–3 Dateien, ≈ 40–80 LoC | 0 |
| Was Henning sieht | Auftrag oft nach Minuten, manchmal Stunden, bei weggewischter App gar nicht | Mac: binnen ≈ 2 min; iPhone: beim Öffnen (Hintergrund ≈ 1×/Tag, vom System bestimmt) | beim nächsten Öffnen |
| Fremdabhängigkeit | neuer APNs-Schlüssel (Henning im Portal), Server-Geheimnisse, TestFlight | keine | keine |
| Risiko | hoch: Drosselung (≈ 2–3/h), Sandbox/Produktion je Token, gemeinsamer Eingang mit CloudKit kann iCloud-Abgleich stören, Löschpfad und Vertrag erweitern | niedrig | keines |

### Affected Files (Variante B, Mac-Takt)
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEnds/Claude/ClaudeSyncTrigger.swift | MODIFY | Takt-Auslöser (nur macOS, nur mit Konto, nicht unter Tests), hängt über `pullAfterSend` ein |
| LooseEndsTests/Claude/ClaudeSyncTriggerTests.swift | MODIFY | Takt löst Holen aus, kollidiert nicht mit laufendem Senden |
| (optional) LooseEnds/Notifications/BackgroundRefresh.swift | MODIFY | iOS-Hintergrund holt zusätzlich — berührt Gerätepfad → Stufe 3 |

### Scope Assessment
- A: ≥ 9 Dateien, ≈ 430 LoC, 2–3 Schnitte, Risiko HOCH
- B (nur Mac): 2 Dateien, ≈ 40–60 LoC, Risiko NIEDRIG, kein Gerätepfad
- C: 0

### Technical Approach (Entscheidung PO: A)
Gebaut wird A in drei Schnitten, je ≤ 5 Dateien / ±250 LoC:
- **S5a Dienst:** Migration 008 `device_tokens` (Konto, Gerät, Token, Umgebung, Zeit; Löschen mit dem Konto per Cascade), `POST /app/device` in `app-routes.ts` (204, Muster der drei Wege), `server/src/apns.ts` (ES256-Anbieter-Token mit `node:crypto`, `node:http2`, Token ≈ 50 min wiederverwendet, 410/`BadDeviceToken`/`Unregistered` löschen den Token), `APNS_*` alles-oder-nichts in `main.ts`, Aufruf aus `putOrder` bei `stored`, ohne zu warten und ohne Fehler weiterzugeben; Vertrag „Wege der App“ um den vierten Weg. Tests mit gefälschtem http2-Server.
- **S5b nginx + Schlüssel:** Erlaubnisliste in henemm-infra um `/app/device`, neuer APNs-Schlüssel im Portal (Henning nur Anmeldung), Geheimnisse auf `rennwienix`, Ausrollen.
- **S5c App:** iOS-`UIApplicationDelegateAdaptor` (Mac: `MacAppDelegate`), `registerForRemoteNotifications` nur mit Konto, Token über `AccountState.withSession` an `/app/device` samt Umgebung, `didReceiveRemoteNotification` erkennt eigenen Schlüssel (`looseends`) und lässt CloudKits Mitteilungen unberührt, Trigger-Eingang „einmal holen, dann Bescheid geben“ über `pullAfterSend`. Simulator: `xcrun simctl push`; Stufe 3 über TestFlight (Gerätepfad `project.yml`/`LooseEnds/Notifications/`).

Ursprüngliche Empfehlung (verworfen vom PO): B, nur der Mac-Takt: Die Menüleisten-App holt alle 2 Minuten, solange ein Konto verbunden ist. Kein Dienstteil, kein neuer Apple-Schlüssel, kein Gerätepfad. A erst, wenn das Warten am iPhone im Alltag stört; dann bekäme der Vertrag „Wege der App“ einen vierten Weg (Gerät anmelden), und der Dienst speicherte erstmals Gerätekennungen für Apple.

### Open Questions
- [x] PO: Weckruf per Mitteilung (A), Mac holt im Takt (B) oder nichts (C)? → **A, echter Weckruf per Push** (Henning, 2026-11-13, AskUserQuestion; Empfehlung war B, Drosselung und Portal-Anmeldung waren ihm erklärt)
- [ ] Neuer APNs-Schlüssel: Henning meldet sich einmal im Apple-Portal an (Passkey), Claude legt den Schlüssel an und bringt ihn auf den Server — erst wenn Schnitt S5a gemergt ist und der Dienst ihn braucht, alles vorher fertig
- [ ] Umgebung je Token: App meldet `sandbox`/`production` mit (aus dem Bau, nicht geraten)
