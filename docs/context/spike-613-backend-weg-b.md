# Context: spike-613-backend-weg-b

## Request Summary
Spike #613 (Epic #612): Backend für Claude wählen und beweisen. Seit 2026-10-31 gilt **Weg B „Fenster für Claude“**:
iCloud (ADR-2) bleibt der Abgleich; ein eigener schlanker Dienst auf Hetzner hält eine **Abschrift** (samt fertig
berechneter `ViewRules`-Ansichten) und einen **Auftragsweg**, den das nächste Gerät als Nutzer-Revision „Claude“ ausführt.
Ergebnis: neue ADR (ergänzt ADR-2, löst es nicht ab) mit Prototyp-Messung, Kostenrechnung, Freigabe Henning.

## Entscheidungsstand (Quellen)
- Issue #613 Kommentare 2026-10-22 (Hosting auf Hetzner CPX32, später eigener Server vor #625), 2026-10-31 (Weg B, Quellen
  PowerSync/Supabase-OAuth), 2026-10-31 Nachtrag (eigener Dienst statt Supabase; Supabase Pro nur Rückfall für OAuth).
- Memory `loose-ends-612-weg-b-fenster-fuer-claude.md`.
- Ticket-Text (ADR-2 ablösen, ADR-19, PowerSync, Simulator-A/B-TaskItem-Abgleich) ist **überholt** und wird in der Spec
  angepasst: ADR-2 bleibt; **ADR-19 und ADR-20 sind vergeben**, die neue Entscheidung wird **ADR-21**.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/project/00-entscheidungen.md` | ADR-2 (Z. 80), Ziel der neuen ADR-21 |
| `Shared/Models/ViewRules.swift` | `now(in:)`, `nowCount`, `nowRows` u. a. — Quelle der Ansichten, die die Abschrift fertig berechnet mitträgt („eine Zahl überall“, #637) |
| `Shared/Models/TaskItem.swift` | ~71 Felder; die Abschrift ist eine Auswahl davon, nicht das SwiftData-/`CD_`-Format |
| `Shared/Models/Revision.swift`, `Shared/Models/Enums.swift` (`FieldSource` ai/user/rule) | Auftrag aus Claude wird als Revision `author .user`, `reason "Claude"` geschrieben (Muster wie Siri, #225) |
| `Shared/Services/TaskActions.swift` | complete, park, move, setDue, toggleNext … — die Aktionen, die ein Auftrag auslöst |
| `Shared/Services/CaptureService.swift` | Anlegen einer Aufgabe — Auftrag „erfassen“ |
| `Shared/Services/SiriCapture.swift` | Vorbild: externe Eingabe in zwei Schritten prüfen/schreiben, Autor `.user` mit Grund |
| `Shared/Persistence/SyncStatus.swift`, `LooseEnds/Notifications/DueNotificationCenter.swift` | Beobachten von CloudKit-Importen (`eventChangedNotification`) — Einhängepunkt „nach Änderung Abschrift senden“ |
| `LooseEnds/Notifications/BackgroundRefresh.swift` | täglicher `BGAppRefreshTask` — möglicher zweiter Einhängepunkt fürs Abholen von Aufträgen |
| `project.yml` | `aps-environment`, `UIBackgroundModes: [remote-notification, fetch]` schon vorhanden (stille Mitteilung zum Wecken) ; „Mit Apple anmelden“ fehlt noch |

## Existing Patterns
- Externe Eingaben (Siri) werden als Nutzer-Revision mit Grund geschrieben; nichts bleibt halb liegen bei Fehler.
- Reine Regeln (`ViewRules`, `DueReminders`) getrennt von der System-Hülle; Hülle ist unter `--ui-testing` stumm.
- Kein `try?`, `Logger`, Swift 6 strict concurrency; neue App-Teile unter `LooseEnds/`, plattformneutral Reines in `Shared/`.
- Berechtigungen nur über `project.yml` (#311).

## Dependencies
- Upstream: SwiftData-Store mit CloudKit-Spiegelung (bleibt), `ViewRules`, `TaskActions`, APNs.
- Downstream: #614 (Datenmodell), #615 (Konto), #616–#620 (entfallen voraussichtlich → „Abschrift und Aufträge“),
  #621–#624 (MCP-Server, Skills, MCP App) bauen auf der Wahl auf.

## Existing Specs
- Keine Spec zu Backend/Sync. Verwandt: `docs/specs/feat-175-cloudkit-produktion.md` (CloudKit-Schema-Weg).

## Risks & Considerations
- **Kein dokumentierter Zugang zum Hetzner-Server** in Repo, CLAUDE.md oder Memory (`~/.ssh/config` kennt ihn nicht).
  Ressourcenmessung und Betrieb dort brauchen Zugangsdaten → Analyse muss klären, ob der Prototyp lokal läuft und Hetzner
  nur gemessen wird.
- **Lokale Werkzeuge**: kein Docker, kein `psql`; `node` (Homebrew 26.5.1) startet nicht (fehlende `libsimdjson.33`) →
  lokale Umgebung muss erst repariert werden (eigener Rechner, erlaubt).
- **claude.ai muss den Dienst erreichen** (öffentliche HTTPS-Adresse) — für das OAuth-Kriterium braucht der Spike eine
  erreichbare Instanz, lokal reicht nicht.
- **OAuth nie selbst schreiben**: nur MCP-SDK-Auth-Router oder node-oidc-provider; CIMD vor DCR (MCP-Spez. 2025-11-25).
- Stufe 3: Eine App-Änderung in `project.yml` (Sign in with Apple) oder `Shared/Persistence/` löst Gerätelauf aus —
  im Spike möglichst vermeiden (Prototyp über Simulatoren, Gerät nur nach „jetzt ist ein Test möglich“).
- Datenschutz: Abschrift verlässt iCloud → Datenschutztext (`docs/reference/datenschutz-entwurf.md`, Website) ändert sich
  erst mit #625; die ADR muss das Versprechen „privat in deiner iCloud, außer du verbindest Claude“ formulieren.
- Konflikte: Auftrag gegen eine inzwischen geänderte Aufgabe (veraltete Abschrift) — Regel nötig (z. B. Auftrag trägt
  erwarteten Stand, sonst abgelehnt und gemeldet). Keine eigene Konfliktlösung im Sinne eines Sync-Frameworks.
- Scoping-Limit 4–5 Dateien / ±250 LoC je Schnitt: Prototyp (Dienst + App-Anbindung) braucht voraussichtlich mehrere Schnitte.

## Analysis

### Type
Spike (Feature-Vorarbeit): Architektur beweisen, Ergebnis ADR-21. Kein Produktpfad wird in diesem Spike ausgeliefert.

### Recherche (2026-10-31, Quellen)
- **MCP TypeScript SDK v2.4** (2026-10-23) liefert nur die Ressourcen-Seite (`requireBearerAuth`, Metadaten-Router RFC 9728/8414);
  die Autorisierungsserver-Helfer (`mcpAuthRouter`, `ProxyOAuthServerProvider`) sind in `@modelcontextprotocol/server-legacy/auth`
  eingefroren: „Use a dedicated identity provider for new servers“. https://github.com/modelcontextprotocol/typescript-sdk (docs/serving/authorization.md)
- **node-oidc-provider v9.13.3** (2026-10-29): CIMD (`features.clientIdMetadataDocument`, draft-02, experimentell), DCR, PKCE Pflicht
  für öffentliche Clients, Refresh-Rotation, Widerruf, RFC 8707. Selbst zu bauen: Postgres-Adapter, Anmelde- und Zustimmungsseite.
  https://github.com/panva/node-oidc-provider/blob/main/docs/README.md ; Beispiel darauf: https://github.com/tigrisdata/mcp-oidc-provider
- **Claude.ai-Connectoren**: Auth-Spez. 2025-03-26/06-18/11-25; CIMD nur bei `client_id_metadata_document_supported: true` und
  `none` in `token_endpoint_auth_methods_supported`, sonst DCR; Rücksprung `https://claude.ai/api/mcp/auth_callback`; PKCE S256;
  401 mit `WWW-Authenticate: Bearer resource_metadata=…`; `resource` = Server-URL exakt; Refresh bei 401 und bis 5 min vor Ablauf,
  ungültiger Refresh → `invalid_grant`; 10 s Zeitlimit für Discovery/Token; öffentliches HTTPS, Absender 160.79.104.0/21; authlose
  Connectoren werden unterstützt. https://claude.com/docs/connectors/building/authentication.md , …/custom/remote-mcp.md
- **Mit Apple anmelden**: Prüfung des Identitätstokens (JWKS, `iss`, `aud`, `exp`, `nonce`) braucht keinen Schlüssel. Da die Anmeldung
  aber im Browser während Claudes OAuth-Ablauf passiert, ist es der **Web-Ablauf**: Services ID plus Client-Secret aus dem .p8-Schlüssel.
  Kontolöschung verlangt Widerruf über Apples REST-API (`/auth/revoke`), der Server muss das Refresh-Token halten.
  https://developer.apple.com/documentation/signinwithapple/verifying-a-user , https://developer.apple.com/support/offering-account-deletion-in-your-app/
- **Stille Mitteilung**: keine Zustellgarantie, „nicht mehr als zwei oder drei pro Stunde“, nach Zwangsbeenden verworfen, 30 s Laufzeit.
  Aufträge brauchen daher Abholen beim Öffnen und per `BGAppRefreshTask`; die Mitteilung ist nur Beschleuniger.
  https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app
- Better Auth (oauthProvider + mcp + cimd) ist eine zweite TS-Option, jünger und mit claude.ai unbelegt; Cloudflare
  `workers-oauth-provider` hängt an Workers-APIs und passt nicht auf Hetzner/Node.

### Befunde im Code
- `ViewRules` ist rein über `[TaskItem]` + `now` + `calendar`: `now(in:)`, `nowCount` (= Symbolzahl, #637), `tasks(for: .due/.next/.open)`.
  Die Abschrift kann die Ansichten damit auf dem Gerät berechnen; **Achtung:** `TaskListView.swift:371-409` ordnet „Fällig“ und
  „Lose Enden“ in der Oberfläche zusätzlich (Überfällige oben, Blöcke #657). Die Abschrift muss dieselbe Reihenfolge tragen, sonst
  zeigt Claude eine andere Liste als die App → diese Ordnung gehört nach `ViewRules` (eigener kleiner Schnitt, nicht im Spike).
- Schreibwege: `TaskActions.complete/park/toggleNext` schreiben keine Revision (Status ist kein abgeleitetes Feld); `move`/`setDue`
  gehen über `RevisionService.set` (Autor `.user`), verwerfen aber die zurückgegebene Revision. `SiriCapture.write` setzt den Grund,
  indem es die zurückgegebenen Revisionen einsammelt (:180–:198) → derselbe Weg für „Claude“. `CaptureChannel` hat kein `.claude`.
- `TaskItem` hat `id: UUID`, aber **kein `modifiedAt`** → der Auftrag trägt den erwarteten Stand der Felder, die er ändert
  (`statusRaw`, `dueDate`/`dueHasTime`); weicht er ab, wird der Auftrag abgelehnt und als abgelehnt zurückgemeldet.
- Einhängepunkte: `ContentView.swift:149` (`ModelContext.didSave`), `DueNotificationCenter.swift:79-91` (CloudKit-Import),
  `BackgroundRefresh.swift` (täglicher Hintergrundlauf). Kein `didReceiveRemoteNotification`, **kein URLSession, kein Schlüsselbund**
  in Produkt-Targets.

### Umgebung
- Hetzner-Server = SSH-Host `rennwienix` (178.104.143.19, dort läuft gregor20). Lesender Ressourcenblick wurde vom Berechtigungssystem
  abgelehnt („Production Reads“) → braucht Hennings Freigabe (offene Frage unten).
- Lokal: `node` startet nicht (fehlende `libsimdjson`), kein Docker, kein `psql` → vor dem Dienst reparieren (eigener Rechner).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/` (neu: `package.json`, `schema.sql`, `src/*.ts`, `deploy/*`) | CREATE | Dienst: Abschrift, Aufträge, MCP-Endpunkt, später OAuth; liegt im Repo, damit Vertrag und Swift zusammen wandern |
| `Shared/Services/TranscriptCodec.swift` | CREATE | rein: Aufgaben + Ansichten (`ViewRules`) → JSON-Abschrift (nur benötigte Felder, nicht alle ~71) |
| `Shared/Services/OrderExecutor.swift` | CREATE | rein: Auftrag (erfassen, abhaken, Datum setzen) prüfen (erwarteter Stand) und ausführen, Grund „Claude“ |
| `Shared/Models/Enums.swift` | MODIFY | `CaptureChannel.claude` (kein Schema-Feld, Rohwert-Enum) |
| `LooseEndsTests/…` | CREATE | Unit-Tests Codec/Ausführer; A/B-Nachweis mit zwei getrennten Stores gegen den laufenden Dienst |
| `docs/project/00-entscheidungen.md` | MODIFY | ADR-21 (ergänzt ADR-2) |

Kein Pfad der Geräteliste (Stufe 3) im Spike: kein `project.yml`, keine Berechtigung, nichts unter `Shared/Persistence/`,
`LooseEnds/Notifications/`. „Mit Apple anmelden“ in der App gehört zu #615.

### Scope Assessment
- Schnitte: C0 Umgebung (0 LoC) · C1 Vertrag + `server/`-Gerüst + Postgres-Schema (~150) · C2 Swift-Codec + Ausführer + Tests (~230) ·
  C3 Dienstkern ohne Anmeldung (~240) · C4 MCP-Schicht `get_now`, `list_tasks`, `create_order` (~150) · C5 A/B-Nachweis (~200) ·
  C7 Betrieb auf Hetzner + Messung (~150) · C6a OAuth mit node-oidc-provider, DCR + PKCE + Rotation + Widerruf (~250) ·
  C6b Mit Apple anmelden (Web-Ablauf) + Zustimmungsseite (~200) · C8 ADR-21.
- Risk Level: MEDIUM — App-Seite rein und testbar; Hauptrisiko ist der OAuth-Teil (öffentliche Adresse, Services ID, .p8, 10-s-Grenzen).

### Technical Approach
**Ein Spike, zwei Abschnitte mit je einem Halt bei Henning.**
1. **Datenweg (C0–C5, C7):** Dienst in `server/` (TypeScript, MCP-SDK v2 als Ressourcen-Server, Postgres auf Hetzner). App-Seite
   nur als reiner Codec/Ausführer in `Shared/Services/`, getrieben aus Tests; „Simulator A/B“ wird als **zwei getrennte Stores**
   nachgewiesen (zwei Simulatoren mit derselben iCloud gleichen nicht verlässlich ab, und den Abgleich beweist ADR-2 schon).
   Claude.ai verbindet sich in diesem Abschnitt **ohne Anmeldung über eine geheime Adresse, nur für Henning** — Zwischenschritt,
   nie die Entscheidung. Halt 1: Henning sieht in Claude dieselbe „Jetzt“-Zahl wie in der App, ein Auftrag aus Claude kommt an.
2. **Anmeldung (C6a, C6b):** node-oidc-provider als Autorisierungsserver (DCR zuerst, CIMD danach), Mit Apple anmelden im
   Web-Ablauf; Kriterium: Claude.ai verbindet sich, Token-Erneuerung und Widerruf funktionieren. Scheitert C6a in zwei Anläufen,
   übernimmt Supabase Pro genau diesen Teil (vereinbarte Rückfallebene).
3. **ADR-21** nach Abschnitt 2, mit Messung und Kosten; das Ergebnis von Abschnitt 1 wird sofort festgehalten.

Aufträge im Prototyp: erfassen, abhaken, Datum setzen (die drei häufigsten aus Claude). Parken, verschieben und „Als nächstes“ folgen
im Produkt-Ticket. Ausführung beim Öffnen der App und im Hintergrundlauf; stille Mitteilung nur als Beschleuniger (nicht im Spike).

**Alternative (nicht gewählt):** Claude spricht direkt mit CloudKit über die CloudKit-Web-API, ohne eigene Abschrift. Kippt ADR-21
vor seiner Entstehung, scheitert aber an: Webtoken höchstens zwei Wochen, Nachbau des `CD_`-Formats, keine fertig berechneten
Ansichten, Schreiben ohne Revision. **Zweite Alternative für die Anmeldung:** Better Auth (weniger Eigencode, aber jünger und mit
claude.ai unbelegt).

| Anmelde-Option | Für | Gegen |
|---|---|---|
| node-oidc-provider | zertifiziert, CIMD/DCR/PKCE/Rotation/Widerruf, läuft auf Hetzner, keine Bindung | Adapter, Anmelde- und Zustimmungsseite selbst; CIMD experimentell |
| Better Auth | Apple eingebaut, Postgres-Adapter dabei, weniger Code | jung, API ändert sich, mit claude.ai unbelegt |
| Supabase OAuth (Pro) | nichts selbst zu betreiben | Monatsgebühr, zweiter Anbieter, CIMD undokumentiert, Zustimmungsseite trotzdem selbst |
| ohne Anmeldung + geheime Adresse | sofort, null Code | kein Produkt, kein Widerruf je Nutzer → nur Zwischenschritt |

### Dependencies
- Upstream: `ViewRules`, `RevisionService`, `TaskActions`, `CaptureService`; Apple Developer (Services ID, .p8) erst ab C6b.
- Downstream: #614 (Datenmodell), #615 (Konto), #616–#620 (entfallen voraussichtlich → „Abschrift und Aufträge“), #621–#624.
- Folgearbeit (eigene Tickets nach dem Spike): UI-Ordnung aus `TaskListView` nach `ViewRules`; Kontolöschung mit Apple-Widerruf;
  Datenschutztext (#625).

### Open Questions
- [x] Hetzner-Ressourcen: schon in einer früheren Sitzung gemessen (Henning, 2026-10-31). Die CPU ist kein Problem. Der Speicher
  wird nur knapp, **wenn** viele Claude-Sitzungen parallel laufen, und das steuert Henning selbst. → Der Server trägt den Dienst,
  kein neuer Blick vor der Spec, kein eigener Server für den Spike (der eigene Server vor #625 bleibt wie vereinbart). C7 hält den
  Speicherbedarf des laufenden Dienstes (Postgres + Node) als Zahl für die ADR fest.
- [ ] Öffentliche Adresse für den Dienst (Vorschlag: Unterdomain von henemm.com) — erst vor C7, wird dann gefragt.

### TDD RED (Schnitt 1, 2026-10-31): Festlegungen für /50-implement
Die Tests `LooseEndsTests/TranscriptCodecTests.swift` und `OrderExecutorTests.swift` legen die Namen fest:
- `Transcript` (`version`, `generatedAt`, `nowCount`, `now: Transcript.Now`, `tasks: [Transcript.Entry]`), Memberwise-Init in dieser Reihenfolge;
  `Transcript.Entry(id:title:status:dueDate:dueHasTime:contexts:project:nextRank:isKnaeuel:)`, `title` = `displayTitle`, Kontexte nach Namen sortiert.
  `tasks` = alle außer `.done` und `.removed`. Optionale Felder fehlen im JSON, wenn nil (`knaeuel`, `dueDate`, `project`, `nextRank`).
- `TranscriptCodec.transcript(of:now:calendar:)`, `encode<T: Encodable>(_:) throws -> Data`, `decode<T: Decodable>(_:from:) throws -> T`
  (ISO 8601 in ganzen Sekunden, `sortedKeys`).
- `Order(version: Int = 1, id:, kind: Order.Kind, text:, taskID:, expectedStatus:, date:, hasTime:, expectedDueDate:)`, alles nach `kind` optional mit Vorgabe nil.
- `OrderResult(orderID:, outcome:, reason: = nil, taskID: = nil)`, `Outcome` `done|rejected`, `Reason` `invalid|stale|missing`.
- `OrderExecutor.execute(_:in:now:calendar:) throws -> OrderResult`, `@MainActor`.
- **Präzisierung des Vertrags:** `complete` prüft Status **und** Fälligkeit (`expectedDueDate`, nil = ohne Datum). Nur so ergibt das zweite
  Ausführen bei einer wiederkehrenden Aufgabe `stale` (AC-8): sie bleibt `active`, nur die Fälligkeit rückt weiter. Deckt die Spec („erwarteter
  Stand der Felder, die er ändert“); im Vertragsdokument so beschreiben.
- Fälligkeiten werden in ganzen Sekunden verglichen (ISO-8601-Text), sonst wäre ein Datum aus der Abschrift mit Sekundenbruchteilen im Store stets `stale`.
- Reihenfolge der Prüfung: Version und Pflichtfelder → `invalid`; Aufgabe fehlt → `missing` (mit `taskID` nil); Stand weicht ab → `stale` (mit `taskID`).
- `docs/reference/claude-abschrift-vertrag.md` muss die drei Fixtures (Abschrift, Auftrag, Ergebnis) wörtlich enthalten, ab Spalte 0
  (Swift entfernt den Einzug der Mehrzeilen-Literale); die Tests vergleichen per `contains`.
