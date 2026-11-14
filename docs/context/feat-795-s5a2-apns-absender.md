# Context: feat-795-s5a2-apns-absender

## Request Summary
#795 Schnitt S5a-2: Der Dienst sendet den Weckruf. Legt Claude einen Auftrag an (`putOrder` → `stored`), schickt der Dienst an jedes gemeldete Gerät des Kontos eine stille APNs-Mitteilung; ungültige Tokens löscht er. Ohne `APNS_*`-Konfiguration passiert nichts. Vorher: S5a-1 (PR #920, Speicher `device_tokens` und `POST /app/device`); Gesamtplan und PO-Entscheidung (Variante A) in `docs/context/feat-795-s5-weckruf.md`.

## Related Files
| File | Relevance |
|------|-----------|
| server/src/orders.ts:69 | `putOrder` — einzige Stelle, an der ein Auftrag entsteht; Weckruf nur bei `"stored"`, nie bei `"duplicate"` |
| server/src/mcp.ts:87, :118, :192 | Aufrufer `capturing` und `storing`; `mcpHandler(pool)` muss den Sender hineingereicht bekommen (oder `putOrder` bekommt ihn) |
| server/src/devices.ts | `device_tokens` (Konto, Gerät, Token klein, `environment` sandbox/production); Lesen je Konto und Löschen eines Tokens kommen dazu |
| server/migrations/008_device_tokens.sql | Tabelle; `UNIQUE (token)`, Cascade mit dem Konto |
| server/src/apple-client.ts:27–36 | ES256-JWT mit `node:crypto` `sign(..., dsaEncoding: "ieee-p1363")` — Vorlage für den APNs-Anbieter-Token |
| server/src/apple.ts | `loadAppleConfig`: Variablen lesen, Fehler nennt nur den Variablennamen, `createPrivateKey` |
| server/src/main.ts:27–50, :201, :266–300 | `StartOptions`, `APPLE_VARS`/`appleConfigFromEnv` (alles-oder-nichts, halbe Konfiguration → Exit 1 vor Pool und Port), `start()` baut `mcpHandler(pool)` |
| server/test/apple-client.test.ts:63–74 | Muster: Netz als hineingereichte Funktion mit Zähler, fester Uhr — Vorlage für einen Stub-Sender statt echtem http2 |
| server/test/devices.test.ts, test/mcp-write.test.ts, test/db.ts | Testaufbau gegen Wegwerf-Postgres |
| docs/reference/claude-abschrift-vertrag.md:162–195 | „Wege der App“; Weckruf-Absatz (Inhalt der stillen Mitteilung, Schlüssel `looseends`) gehört hierher, ohne neuen ```json-Block (Tests zählen genau drei) |
| docs/specs/feat-795-schnitt-5a1-geraet-anmelden.md:155 | Zuschnitt S5a-2: `apns.ts` (ES256, `node:http2`), `APNS_*` alles-oder-nichts, Weckruf aus `putOrder` bei `stored`, 410/`BadDeviceToken`/`Unregistered` löschen |
| CLAUDE.md, Abschnitt `server/` | eine Zeile zu `src/apns.ts` |

## Existing Patterns
- Optionale Fähigkeit per Umgebungsvariablen alles-oder-nichts; Fehler nennt nur den Variablennamen; Start bricht bei halber Konfiguration ab (`apple config invalid: <var>`, `oauth config invalid: <var>`).
- Netz und Uhr werden hineingereicht (`fetch`, `now`), Tests ohne echtes Netz.
- Log nur feste Ereignisnamen (`apple revoke failed`), nie Token, Konto-ID, Text oder Fehlertext; `logError` wirft nie.
- Fehler des Nebenwegs (Apple-Revoke) blockieren den Hauptweg nie (best effort, 204 trotzdem).

## Dependencies
- Upstream: APNs HTTP/2 (`api.push.apple.com`, `api.sandbox.push.apple.com`, Port 443), Pfad `/3/device/<token>`, Header `authorization: bearer <JWT>`, `apns-topic` (Bundle-ID), `apns-push-type: background`, `apns-priority: 5`; Körper `{"aps":{"content-available":1}, …}`. Ein .p8-Schlüssel mit APNs-Recht (neu, S5b; `SF83PT3Q22` kann nur Sign in with Apple).
- Downstream: S5b (nginx, Schlüssel, Geheimnisse auf `rennwienix`), S5c (App erkennt den Weckruf am eigenen Schlüssel, CloudKit-Mitteilungen bleiben unberührt).

## Existing Specs
- docs/specs/feat-795-schnitt-5a1-geraet-anmelden.md (Vorgänger, Downstream-Plan)
- docs/context/feat-795-s5-weckruf.md (Varianten A/B/C, PO-Entscheidung A)

## Recherche (2026-11-14)
- Anbieter-Token: einen pro Schlüssel wiederverwenden, frühestens nach 20, spätestens nach 60 Minuten erneuern; zu häufiges Erneuern → 429 `TooManyProviderTokenUpdates`, älter als 1 h → 403 `ExpiredProviderToken`. Üblich ≈ 50 min. Quellen: developer.apple.com/forums/thread/86288, /thread/687789, /thread/854496.
- Hintergrund-Mitteilungen: `apns-push-type: background` und `apns-priority: 5` Pflicht (seit iOS 13); Quelle: learn.microsoft.com/en-ca/azure/notification-hubs/push-notification-updates-ios-13; Apple „Pushing background updates to your app“.
- Ungültige Tokens: 410 `Unregistered`, 400 `BadDeviceToken` (auch bei falscher Umgebung!), 400 `DeviceTokenNotForTopic`.

## Risks & Considerations
- **`BadDeviceToken` heißt oft nur „falsche Umgebung“** (Sandbox-Token an Produktion). Löschen ist dann trotzdem richtig, weil die App ihr Token mit Umgebung bei jedem Start neu meldet (S5c) — muss in der Analyse bestätigt werden.
- **Bundle-ID je Token:** Der Prüfbau hat `com.henning.looseends.probe`; `device_tokens` kennt die Bundle-ID nicht. `apns-topic` fest auf `com.henning.looseends` (Konfiguration) → Prüfbau-Tokens bekämen `DeviceTokenNotForTopic`. Analyse: Topic aus Konfiguration, Prüfbau außen vor, oder Spalte nachrüsten (Migration nur additiv).
- **Nie den Auftrag gefährden:** Weckruf ohne Warten (`void`), Fehler nur geloggt; Claude bekommt weiter sofort `state: waiting`.
- **Token-Erneuerung bei mehreren Prozessen:** Es läuft genau ein Dienst-Prozess auf `rennwienix`; Cache im Prozess reicht.
- **http2-Verbindung:** je Umgebung eine wiederverwendete Sitzung oder je Weckruf eine neue; mit wenigen Weckrufen pro Stunde ist „neu pro Weckruf, Token gecacht“ einfach und robust. Zeitlimit wie `apple-client.ts` (5 s).
- **Umfang:** `apns.ts` neu (~90), `main.ts` Konfiguration (~25), `orders.ts`/`mcp.ts` Einhängen (~15), `devices.ts` Lesen/Löschen (~15), Tests (~150), Vertrag/CLAUDE.md → nahe an 250; Tests notfalls getrennt zählen wie in S5a-1.
- **Kein Gerätepfad** der Stufe-3-Liste berührt (nur `server/`).
- **Alternative:** Weckruf statt aus `putOrder` aus einem Abfrager, der `orders` periodisch auf neue Zeilen prüft (entkoppelt, aber Verzögerung und Zustand „schon geweckt“); oder Postgres `LISTEN/NOTIFY` per Trigger.

## Analysis

### Type
Feature (Dienst-Seite des Weckrufs, Variante A aus `docs/context/feat-795-s5-weckruf.md`)

### Affected Files (with changes)
| File | Change Type | Schnitt | Description |
|------|-------------|---------|-------------|
| server/src/apns.ts | CREATE | 2a | `apnsConfigFromEnv` (vier `APNS_*`-Variablen: Team, Schlüssel-ID, Schlüssel, Topic; alles oder nichts, `createPrivateKey` schon beim Laden, Fehler nennt nur die Variable), Anbieter-JWT ES256 (`ieee-p1363`, 50 min Cache, Erneuerung frühestens nach 20 min), Transport `node:http2` (eine Sitzung je Senden, 5 s, `session.on("error")`, `close` im `finally`, Ursprung je Umgebung überschreibbar), `createWaker({config, pool, send?, now?, log?})` → `wake(account)` |
| server/src/devices.ts | MODIFY | 2a | `listTokens(pool, account)` (token, environment), `dropToken(pool, token, environment)` |
| server/test/apns.test.ts | CREATE | 2a | Stub-Sender: Kopfzeilen/Körper, Host je Umgebung, 410/BadDeviceToken/DeviceTokenNotForTopic löschen, 5xx/Netz nicht, JWT-Cache und 403 ExpiredProviderToken (ein Wiederholversuch), Untergrenze 20 min, wake wirft nie; h2c-Server für den echten Transport (nur Rahmung, TLS nicht) |
| server/src/mcp.ts | MODIFY | 2b | `mcpHandler(pool, { wake? })`; ein Helfer `place(pool, owner, doc, wake)` statt der zwei `putOrder`-Aufrufe; `void wake(owner)` nur bei `stored` |
| server/src/main.ts | MODIFY | 2b | `apnsConfigFromEnv` in `main()` (Exit 1 mit `apns config invalid: <var>` vor Pool und Port), `StartOptions.apns`, Waker in `start()` |
| server/test/mcp-write.test.ts, Start-Tests | MODIFY | 2b | stored weckt, duplicate nicht, Weckruf-Fehler stört den Auftrag nicht, halbe Konfiguration bricht ab |
| docs/reference/claude-abschrift-vertrag.md | MODIFY | 2b | Absatz Weckruf (stille Mitteilung, fester Inhalt `{"looseends":{"v":1}}`, kein Auftrag, keine ID), ohne neuen json-Codeblock |
| CLAUDE.md | MODIFY | 2b | eine Zeile zu `src/apns.ts` |

### Scope Assessment
- 2a: 3 Dateien, ~+120 Code, ~+170 Tests (Tests getrennt gezählt wie S5a-1)
- 2b: 4–5 Dateien, ~+40 Code, ~+40 Tests, ~+10 Doku
- Risk Level: LOW–MEDIUM (nur `server/`; 2a wird von nichts aufgerufen; 2b hängt sich ohne Warten an, Fehler nur geloggt). Kein Pfad der Geräteliste berührt.

### Technical Approach
- Transport `node:http2` ohne neue Abhängigkeit: Nodes eingebautes `fetch` (gebündeltes undici) handelt HTTP/2 nicht zuverlässig aus, APNs verlangt HTTP/2 (undici#2750, Beispiel `api.sandbox.push.apple.com`).
- Host je Zeile aus `environment` (sandbox → api.sandbox.push.apple.com, production → api.push.apple.com), Pfad `/3/device/<token>`, `apns-push-type: background`, `apns-priority: 5`, `apns-topic` aus der Konfiguration, Körper `{"aps":{"content-available":1},"looseends":{"v":1}}`.
- Löschen bei 410 `Unregistered`, 400 `BadDeviceToken`, 400 `DeviceTokenNotForTopic`; alles andere nur loggen.
- Log nur feste Ereignisse: `apns send failed`, `apns token dropped`, `apns jwt failed`; nie Token, Konto, Grundtext.
- `wake` ganz in try/catch, `Promise.allSettled` über die Geräte: ein `void wake()` darf nie eine unbehandelte Ablehnung erzeugen (beendet Node).
- Reihenfolge: 2a (von nichts aufgerufen), dann 2b (Einhängen, Konfiguration, Doku); jeder Schnitt einzeln rücknehmbar.

### Alternatives
- Abfrager über `orders` (Spalte „geweckt“, Migration, Zeitgeber) oder Postgres `LISTEN/NOTIFY` (eigene Dauerverbindung, Wiederverbinden, Trigger-Migration): entkoppelter, aber mehr Teile und Verzögerung; bei einem Prozess und wenigen Weckrufen je Stunde ohne Gewinn. Verpasste Weckrufe nach einem Absturz fängt der Abruf der App beim nächsten Vordergrund ab. Fiele: keine ADR, nur der Zuschnitt aus der S5a-1-Spec.
- Ganz ohne Weckruf (nur Abruf beim Öffnen der App) = Variante B/C, vom PO zugunsten A verworfen.

### Dependencies
- Upstream: APNs HTTP/2, ein .p8-Schlüssel mit APNs-Recht (kommt in S5b; `SF83PT3Q22` kann nur Sign in with Apple).
- Downstream: S5b (Schlüssel und Geheimnisse auf rennwienix), S5c (App meldet Token samt Umgebung bei jedem Start, erkennt den Weckruf an `looseends`).

### Risks
- `BadDeviceToken` heißt oft „falsche Umgebung“; Löschen ist richtig, solange die App bei jedem Start neu meldet (S5c). Verzögert sich S5c, fehlt der Weckruf bis zum nächsten Start.
- Prüfbau (`com.henning.looseends.probe`) bekäme `DeviceTokenNotForTopic` und würde gelöscht; meldet er sich unter demselben Konto, entsteht ein Kreislauf aus Melden und Löschen. Akzeptiert (Prüfbau ist kein Ziel des Kontos), in S5c prüfen.
- h2c-Test prüft nur die Rahmung, nicht TLS; der echte Weg wird erst in S5b gegen Apple belegt.
- Zwei Aufträge kurz hintereinander = zwei Weckrufe; harmlos, kein Bündeln.

### Open Questions
- keine (PO-Entscheidung Variante A liegt vor; der Rest ist technisch)
