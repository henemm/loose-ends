# Context: feat-621-s6-betrieb

## Request Summary
#621 Schnitt 6, der letzte vor S7: den fertigen Dienst (Ressourcenseite S1, Ablage S2, Aussteller S3, Apple-Web S4a–S4c, Zustimmung S5)
auf `rennwienix` öffentlich erreichbar machen und Claude (claude.ai) einmal echt mit Hennings Apple-Konto verbinden lassen.
DoD des Tickets: „In claude.ai als eigener Connector verbunden“ (die vier Ansichten = App erst mit S7 + #795).

## Related Files
| File | Relevance |
|------|-----------|
| `henemm-infra: nginx/loose-ends.henemm.com.conf` | Heute nur `location = /health` (Limit 30 r/m, `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`, **kein** `X-Forwarded-Host`); `= /mcp` und `/` → 404. Muss `/mcp`, `/.well-known/oauth-protected-resource/mcp`, `/.well-known/oauth-authorization-server`, `/.well-known/openid-configuration`, `/oauth/*` öffnen. Kein `client_max_body_size` (Default 1 m), kein SSE-/Buffering-Eintrag. |
| `henemm-infra: loose-ends/docker-compose.yml` | `server` mit `env_file: ./secrets/server.env` (nur auf dem Server, 600); Port `127.0.0.1:8780:8080`, `mem_limit 384m`. Keine Änderung nötig, wenn alle neuen Variablen in `server.env` landen. |
| `henemm-infra: scripts/deploy-loose-ends.sh` | `LE_COMMIT` fest im Skript (heute `e62f0d5…`, Stand #796 S4a) → für S6 auf den aktuellen `main` heben (PR im Infra-Repo). Baut auf dem Server, Health-Probe 60 s, Backup-Fenster 02:45–03:30 gesperrt. |
| `henemm-infra: security/expected-exposure.json`, `tests/test_external_scan.py` | `loose-ends.henemm.com` fehlt in `tls_hosts`/`urls`; Öffnung braucht einen Eintrag, sonst sieht der externe Scan den Host nicht. |
| `server/src/main.ts` | `DATABASE_URL` Pflicht (:248); `appleConfigFromEnv` (:255, alle `APPLE_*` oder keine); `oauthKeysFromEnv` (:262); `publicUrlFromEnv` (:269); `isIssuerPath` (:146: `/oauth/*` + zwei Discovery-Pfade). |
| `server/src/apple.ts` | `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_IDS`, `APPLE_PRIVATE_KEY`, `APPLE_TOKEN_KEY` (Pflicht im Satz), `APPLE_WEB_CLIENT_ID` (optional, nicht in `APPLE_CLIENT_IDS`). |
| `server/src/oauth-provider.ts` | `OAUTH_COOKIE_KEYS` (≥ 32 Zeichen je Schlüssel), `OAUTH_SIGNING_JWK` (ES256 privat); `proxy` an → Issuer/Redirects aus `X-Forwarded-*`; CIMD nur `https://claude.ai`. |
| `server/src/oauth-resource.ts` | `PUBLIC_URL` Default `https://loose-ends.henemm.com`; Metadaten `/.well-known/oauth-protected-resource/mcp`. |
| `server/src/accounts.ts` | `findOrCreate` legt für **jede** gültige Apple-`sub` ein Konto an — es gibt keine Erlaubnisliste (siehe Risiken). |
| `server/src/oauth-consent.ts` | Zustimmungsseite (S5, gemergt #866/#868 ohne Spec im Repo, aus einer Cloud-Sitzung). |

## Existing Patterns
- Infra-Änderungen: PR in `henemm/henemm-infra`, Merge, dann auf `rennwienix` `git pull` in `/home/hem/henemm-infra` und Handlauf `scripts/deploy-loose-ends.sh` (#796 S4a, infra#380). Geheimnisse nur in `secrets/` auf dem Server (700/600), nie im Repo.
- Belege für Serverarbeit als eigener Belege-PR im loose-ends-Repo (#819) unter `docs/artifacts/<workflow>/`.
- Infra-Tests: pytest mit Attrappen (`tests/test_backup_loose_ends.py`); für nginx-Confs gibt es keine Tests; Prüfung live mit `curl` von außen und `nginx -t`.
- `monitor.sh --status` für Belege (schreibt nichts); schnelle Handläufe lösen das nginx-Limit der Frieda-Prüfungen aus.

## Dependencies
- Upstream: Dienst S1–S5 und S4c (alles auf `main`), Apple-Konto (Services ID fehlt noch), Postgres auf rennwienix, nginx/certbot (Zertifikat für `loose-ends.henemm.com` besteht seit #796 S4a).
- Downstream: S7 (Abschrift v2, braucht #625), #795, #625 (Veröffentlichung: Datenschutz, Erlaubnisliste weg, Verzeichnis), #615 S4 (App-Anmeldung über `/auth/*`).

## Existing Specs
- `docs/specs/feat-621-schnitt-1-ressourcenseite.md` … `feat-621-schnitt-4c2-web-token-ablegen.md` (S5 ohne Spec im Repo)
- `docs/context/feat-621-mcp-anmeldung.md` (Schnittplan: S5 „Zustimmung + Erlaubnisliste `apple_sub` = nur Henning bis #625“; S6 „nginx, Compose-Variablen, Verbinden in claude.ai mit Hennings Konto“)
- `docs/context/feat-621-s4a-apple-web.md` (:95, :107: Return-URL `https://loose-ends.henemm.com/oauth/apple/return`, Services ID anlegen, mit `com.henning.looseends` verbinden, Domain eintragen; kein API-Weg, Henning meldet sich im Portal an, Klicks im Chrome-Tab)
- `docs/context/feat-621-s3-aussteller.md` (:44, :143: URL des claude.ai-Web-CIMD unbekannt, beim echten Verbinden ablesen; Claude-Code-CIMD mit Loopback-Port würde scheitern)
- `docs/context/feat-621-s4b-2b-finish.md` (:95: Echtbrowser-Nachweis Safari + Chrome mit echter Apple-Anmeldung gehört in S6)

## Risks & Considerations
- **Erlaubnisliste fehlt (Lücke aus S5).** Geplant war „nur Hennings `apple_sub` bis #625“; gebaut wurde sie nicht (`findOrCreate` ohne Prüfung, Beleg `accounts.ts:7-13`). Öffnet S6 nginx, kann jede Person mit Apple-ID über claude.ai ein Konto anlegen, bevor Datenschutz und Veröffentlichung (#625) stehen. Muss vor der Öffnung geschlossen werden (Dienstcode + Test, eigener Teilschnitt) oder ausdrücklich vom PO anders entschieden werden.
- **Neue Schreibfreigabe für den Server nötig.** Die Freigabe vom 2026-11-03 galt nur für #796 S4a/S4b („spätere Serverarbeit, z. B. #621 `/mcp` öffnen, braucht eine neue“). Grenzen damals: kein Reboot, kein Neustart anderer Dienste oder des Docker-Daemons.
- **Services ID im Apple-Konto.** Ohne sie kein `APPLE_WEB_CLIENT_ID`, also 501 an der Anmeldung. Nur im Portal; Henning meldet sich an.
- **Geheimnisse erzeugen und ablegen:** `OAUTH_COOKIE_KEYS`, `OAUTH_SIGNING_JWK`, `APPLE_TOKEN_KEY` (32 Byte), Apple-Schlüssel (`APPLE_KEY_ID`/`APPLE_PRIVATE_KEY`, Sign-in-with-Apple-Schlüssel; vorhandene `.p8` in `~/Developer` prüfen, welche SIWA hat) direkt auf dem Server, nie im Repo, nie im Log. Eine unvollständige `APPLE_*`-Menge stoppt den Dienst (Exit 1) — Health-Probe im Deploy fängt das, der Stapel bleibt aber unten.
- **Proxy-Header:** `proxy` an im Aussteller; nginx setzt heute kein `X-Forwarded-Host`. Issuer muss exakt `https://loose-ends.henemm.com` sein (Discovery, `iss`, Redirects) — `Host $host` fest oder `X-Forwarded-Host` fest auf den Servernamen.
- **Rate-Limits und Body-Größen** für `/oauth/*` und `/mcp` fehlen in nginx (nur `/health` begrenzt). Dienstseitig: Bridge 1 MiB, Aussteller 56 KiB, Rückweg 16 KiB.
- **MCP-Transport:** `/mcp` zustandslos (Streamable HTTP); prüfen, ob Antworten als SSE kommen → `proxy_buffering off` für `/mcp`.
- **claude.ai-CIMD-URL unbekannt** (`allowFetch` nur Host `https://claude.ai`); beim ersten echten Verbinden ablesen. Claude Code (Loopback mit Port) scheitert vermutlich — nicht Ziel dieses Schnitts.
- **Externer Scan:** `security/expected-exposure.json` um den Host ergänzen.
- **Echtbrowser:** Safari/WebKit nie belegt (Cookies beim `form_post`-Rückweg); Nachweis mit echter Anmeldung in Safari und Chrome.
- **Speicher auf rennwienix knapp** bei vielen Claude-Sitzungen; Deploy prüft ≥ 600 MB frei.
- **`/auth/*` (App-Anmeldung #615)** bleibt außerhalb dieses Schnitts geschlossen, außer die Analyse findet einen Grund.
- **Gerätestufe:** kein Pfad der Geräteliste berührt (nur `server/`-Betrieb und Infra-Repo). Der echte Connect braucht Hennings claude.ai-Konto, nicht sein Gerät.

## Analysis

### Type
Feature (Betrieb + eine Lücke im Dienst)

### Recherche (2026-11-08)
- claude.com/docs/connectors/building/authentication: Redirect-URI der gehosteten Oberflächen (Web, Desktop, Handy)
  `https://claude.ai/api/mcp/auth_callback`; CIMD nur, wenn die Discovery `client_id_metadata_document_supported: true`
  und `none` bewirbt (bei uns ja, `server/test/oauth-provider.test.ts:274`), sonst DCR (haben wir nicht). Die CIMD-URL der
  gehosteten Oberflächen nennt die Seite nicht, nur Claude Codes `https://claude.ai/oauth/claude-code-client-metadata`
  → beim echten Verbinden ablesen. `resource` der Protected-Resource-Metadaten muss exakt der eingegebenen URL entsprechen
  (`https://loose-ends.henemm.com/mcp`). Refresh-Token rotieren, `invalid_grant` bei ungültigem. Ausgangsverkehr
  Anthropic `160.79.104.0/21`. Zustimmungsseite soll den Redirect-Host zeigen (S5 tut das).
- nginx vor Streamable HTTP/SSE: `proxy_buffering off`, `proxy_http_version 1.1`, `proxy_set_header Connection ""`,
  lange `proxy_read_timeout` (blog.thalheim.io, aisauce.pages.dev, glama.ai Cisco-Beispiel).

### Kernbefund
Die im Schnittplan (`feat-621-mcp-anmeldung.md:101`) für S5 geplante Erlaubnisliste ist nie gebaut worden:
`findOrCreate` (`server/src/accounts.ts:7`) legt für jede gültige Apple-`sub` ein Konto an; Aufrufer `auth.ts:68`
(App, `/auth/apple`) und `oauth-return.ts:94` (Web-Rückweg, legt danach das Web-Refresh-Token ab). Öffnet nginx ohne
Tür, kann jede Person mit Apple-ID über claude.ai ein Konto anlegen und ein Apple-Token bei uns hinterlegen, bevor
Datenschutz und Veröffentlichung (#625) stehen. Hennings `sub` ist vor seiner ersten Anmeldung unbekannt (nie loggen).

### Varianten Zugangsbeschränkung
| Variante | Braucht Hennings sub vorab | Schützt Konto-Anlage | Restrisiko |
|---|---|---|---|
| (a) feste sub-Liste per Umgebungsvariable | ja (Henne-Ei) | ja | keins nach Bootstrap |
| (b) erstes Konto schließt die Tür | nein | ja | Fenster zwischen Öffnen und Hennings Anmeldung; Kontrolle `accounts = 1` danach |
| (c) keine Beschränkung | nein | nein | widerspricht Plan „kein Externer vor #625“ |
| (d) nginx-IP auf Anthropic-Bereich | nein | nein (Konto entsteht im Browser-/Apple-Rückweg) | nur Ergänzung für `/mcp`, `/oauth/token` |

**Empfehlung:** (a)+(b) in einer Regel in `findOrCreate`, eine SQL-Anweisung: vorhandene `sub` → ihr Konto; neue `sub`
nur, wenn sie in `ALLOWED_APPLE_SUBS` steht, oder — wenn die Variable fehlt — solange `accounts` leer ist (mit
`pg_advisory_xact_lock` gegen zwei gleichzeitige Erstanmeldungen). Rückgabe `string | null`. Fail closed: Standard ist (b),
nie offen. `oauth-return.ts` gibt bei `null` den Ticket-Fehler `access_denied` und legt kein Token ab; `auth.ts` antwortet
401 wie jede Ablehnung. Nach Hennings erstem Verbinden wird seine `sub` aus der Datenbank in `ALLOWED_APPLE_SUBS`
eingetragen (nur auf dem Server, nie Repo/Log). #625 nimmt die Regel weg. (d) entfällt in S6.
Keine ADR gekippt; ADR-21 („nur Henning bis #625“) wird mit (a)+(b) erst eingelöst.

### Schnitte
- **S6a Tür (dieser Workflow, loose-ends-Repo):** Regel in `findOrCreate`, beide Aufrufer, Variable in `main.ts`, Tests
  (Erstkonto, zweites Konto abgelehnt, Liste, Gleichzeitigkeit, Rückweg ohne Token bei Ablehnung).
- **S6b Betrieb (eigener Workflow danach, henemm-infra + Server):** nginx öffnet `/mcp` (Streaming-Einstellungen,
  Limit-Zone), `/.well-known/oauth-protected-resource/mcp`, die zwei Discovery-Pfade, `/oauth/*` (eigene Limit-Zone);
  `/auth/*` und `/` bleiben 404. `LE_COMMIT` heben, `security/expected-exposure.json` um den Host ergänzen. Services ID im
  Apple-Portal (Henning meldet sich an), Geheimnisdatei des Dienstes vor dem Deploy auf Vollständigkeit prüfen,
  `nginx -t` vor reload, Prüfung von außen, Verbinden in claude.ai, CIMD-URL ablesen, `accounts = 1`, sub eintragen.
  Braucht eine neue Server-Schreibfreigabe von Henning (die vom 2026-11-03 galt nur #796).

### Affected Files (S6a)
| File | Change Type | Description |
|------|-------------|-------------|
| server/src/accounts.ts | MODIFY | `findOrCreate` mit Tür, `string \| null` |
| server/src/oauth-return.ts | MODIFY | `null` → `access_denied`, kein Token |
| server/src/auth.ts | MODIFY | `null` → 401 |
| server/src/main.ts | MODIFY | `ALLOWED_APPLE_SUBS` lesen und durchreichen |
| server/test/accounts.test.ts (+ Rückweg-Test) | MODIFY | Tür-Tests inkl. Gleichzeitigkeit |

### Scope Assessment
- S6a: 5–6 Dateien, ca. +150/−10 LoC (Tests ≈ 2/3) — Risiko MITTEL (Anmeldepfad, aber eine Stelle)
- S6b: 3 Infra-Dateien, ca. +60 LoC, plus Handarbeit auf dem Server — Risiko MITTEL (geteiltes nginx)

### Risiken S6b (für dessen Spec)
Issuer exakt `https://loose-ends.henemm.com` (nginx `Host $host`, `X-Forwarded-Proto`; `proxy` an); unvollständige
`APPLE_*` → Exit 1, Stapel unten; Safari-`form_post`-Rückweg nie belegt; claude.ai könnte eine CIMD-URL außerhalb von
`https://claude.ai` nutzen (dann `allowFetch` anpassen); Claude Code mit Loopback nicht Ziel; Speicher auf rennwienix.
Gerätestufe: kein Pfad der Geräteliste berührt.

### Open Questions
- keine für S6a (Tür ist Plan, Umsetzung technisch). Für S6b: Server-Schreibfreigabe und Hennings Anmeldung im
  Apple-Portal — wird zu Beginn von S6b gefragt.
