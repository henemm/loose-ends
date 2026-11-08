# Context: feat-621-s6b-betrieb

## Request Summary
#621 Schnitt 6b: den fertigen Dienst (S1–S5, Tür S6a PR #873) auf `rennwienix` für Claude öffnen und claude.ai einmal echt
mit Hennings Apple-Konto als eigenen Connector verbinden (DoD des Tickets: „In claude.ai als eigener Connector verbunden“).
Grundlage: `docs/context/feat-621-s6-betrieb.md` (Kontext + Analyse für S6 als Ganzes, Abschnitt „Schnitte“ → S6b);
dieses Dokument ergänzt den Ist-Stand vom 2026-11-08 nach dem Merge von S6a.

## Related Files
| File | Relevance |
|------|-----------|
| `henemm-infra: nginx/loose-ends.henemm.com.conf` | Ist: nur `location = /health` (Zone `loose_ends_health` 30 r/m, `Host $host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`, kein `X-Forwarded-Host`); `= /mcp` und `/` → 404; certbot-Blöcke 443/80. Soll: `/mcp` (Streaming), `/.well-known/oauth-protected-resource/mcp`, `/.well-known/oauth-authorization-server`, `/.well-known/openid-configuration`, `/oauth/*` mit eigenen Limit-Zonen; `/auth/*` und `/` bleiben 404. |
| `henemm-infra: scripts/deploy-loose-ends.sh` | `LE_COMMIT="e62f0d5…"` (:12, Stand #796 S4a) → auf `main` nach PR #873 (`ae957ba`) heben. Prüft `secrets/server.env` (:39), Backup-Sperre 02:45–03:30 (:30), Health 60 s (:53–65), bei Fehler bleibt der Stapel (:90). |
| `henemm-infra: loose-ends/docker-compose.yml` | `server`: `env_file: ./secrets/server.env`, Netze `internal` + `default` (Ausgang zu Apple und claude.ai für CIMD möglich), `127.0.0.1:8780:8080`, `mem_limit 384m`. Voraussichtlich keine Änderung: alle neuen Variablen landen in `server.env`. |
| `henemm-infra: security/expected-exposure.json` | `loose-ends.henemm.com` fehlt in `tls_hosts` und `urls` → Host, `/health` 200, `/mcp` ohne Token 401, `/auth/apple` 404, `/` 404 eintragen. |
| `server/src/main.ts` | liest `DATABASE_URL`, `APPLE_*` (alle oder keine, sonst Exit 1), `OAUTH_COOKIE_KEYS`/`OAUTH_SIGNING_JWK` (beide oder keine), `PUBLIC_URL`, `ALLOWED_APPLE_SUBS` (S6a). |
| `server/src/apple.ts` | `APPLE_TEAM_ID` (`XK87E2B3VR`), `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (Sign-in-with-Apple-Schlüssel, .p8), `APPLE_CLIENT_IDS` (`com.henning.looseends`), `APPLE_TOKEN_KEY` (32 Byte), `APPLE_WEB_CLIENT_ID` (Services ID, neu). |
| `server/src/oauth-provider.ts` | Issuer = Origin von `PUBLIC_URL`, `proxy` an; CIMD nur von `https://claude.ai`; PKCE S256; Ressource `<publicUrl>/mcp`. |
| `server/src/oauth-interaction.ts`, `oauth-return.ts`, `oauth-consent.ts` | Hinweg zu Apple, Rückweg `POST /oauth/apple/return` (`form_post`), Zustimmungsseite; aktiv nur mit `APPLE_WEB_CLIENT_ID` + OAuth-Schlüsseln. |
| `server/src/accounts.ts` | `admit`: ohne `ALLOWED_APPLE_SUBS` nur das erste Konto; nach dem ersten Verbinden Hennings sub eintragen. |
| `~/Developer/AuthKey_{K928C9Z9P2,T7D652RS7A,WF54BW29RL}.p8` | drei Apple-Schlüssel auf dem Mac; welcher Sign in with Apple trägt, ist offen (Portal → Keys). |

## Existing Patterns
- Infra-Änderung = PR in `henemm/henemm-infra` (offen dort nur #381, fremdes Thema), Merge, auf `rennwienix` `git pull` in
  `/home/hem/henemm-infra`, nginx-Datei nach `/etc/nginx/sites-available/`, `nginx -t`, `systemctl reload nginx`,
  danach `scripts/deploy-loose-ends.sh` (Vorbild #796 S4a, infra#380). Kein lokaler Klon des Infra-Repos auf dem Mac; lesen über `gh api`.
- Geheimnisse nur in `secrets/` auf dem Server (700/600), nie im Repo, nie im Log, nie in einer Nachricht.
- Belege der Serverarbeit als eigener Belege-PR im loose-ends-Repo unter `docs/artifacts/<workflow>/` (Vorbild #819).
- Apple-Portal hat keine API für Services IDs: Henning meldet sich in Chrome an, Klicks im Tab (Vorbild CloudKit-Console,
  Memory `loose-ends-cloudkit-deploy-ablauf`). Werte laut `docs/context/feat-621-s4a-apple-web.md:95–107`: Services ID mit
  Sign in with Apple, primäre App `com.henning.looseends`, Domain `loose-ends.henemm.com`, Return-URL
  `https://loose-ends.henemm.com/oauth/apple/return`.
- `monitor.sh --status` liest nur; der Dienst ist im Monitor kritisch (Memory `loose-ends-dienst-kritisch-im-monitor`).

## Dependencies
- Upstream: Dienst auf `main` inkl. S6a; Apple-Konto (Services ID, SIWA-Schlüssel); Postgres und nginx/certbot auf
  rennwienix (Zertifikat besteht seit #796 S4a); claude.ai (Connector-Einstellung, Hennings Konto).
- Downstream: S7 (Abschrift v2), #795, #625 (Veröffentlichung, Regel der Tür weg), #615 S4 (App über `/auth/*`, bleibt zu).

## Existing Specs
- `docs/specs/feat-621-schnitt-6a-tuer.md` (Out of Scope → S6b-Liste)
- `docs/context/feat-621-s6-betrieb.md` (Recherche claude.ai-Callback `https://claude.ai/api/mcp/auth_callback`,
  nginx-Streaming-Einstellungen, Risiken S6b)
- `docs/context/feat-621-s3-aussteller.md` (:44, :143 CIMD-URL beim Verbinden ablesen), `feat-621-s4b-2b-finish.md` (:95 Echtbrowser Safari + Chrome)

## Risks & Considerations
- **Freigaben von Henning nötig, bevor irgendetwas am Server passiert:** neue Server-Schreibfreigabe (die vom 2026-11-03 galt
  nur #796), Grenzen wie damals (kein Reboot, kein Neustart anderer Dienste/Docker-Daemon); seine Anmeldung im Apple-Portal;
  sein Verbinden in claude.ai (sein Konto, nicht sein Gerät → keine Gerätestufe).
- **Zeitfenster der Tür:** Ohne `ALLOWED_APPLE_SUBS` nimmt der Dienst das erste Konto. Öffnen und Hennings erstes Verbinden
  müssen direkt aufeinander folgen; danach `accounts = 1` prüfen und seine sub eintragen. Alternative: sub vorab aus einer
  App-Anmeldung, die es aber erst mit #615 S4 gibt.
- **Issuer exakt `https://loose-ends.henemm.com`:** `proxy` an, nginx `Host $host` + `X-Forwarded-Proto`; ein falscher Host
  bricht Discovery, `iss` und Redirects.
- **Unvollständige Variablen stoppen den Dienst** (Exit 1); das Deploy-Skript fängt es per Health, der Stapel bleibt dann aber
  unten → `server.env` vor dem Deploy auf Vollständigkeit prüfen (nur Namen, nie Werte ausgeben).
- **Streaming `/mcp`:** `proxy_buffering off`, `proxy_http_version 1.1`, `Connection ""`, langes `proxy_read_timeout`.
- **Limits:** eigene Zonen für `/oauth/*` und `/mcp`; Body-Größen dienstseitig (1 MiB, 56 KiB, 16 KiB), nginx-Default 1 m.
- **CIMD-URL von claude.ai unbekannt** (`allowFetch` nur `https://claude.ai`); weicht sie ab, ist ein Dienstfix nötig (neuer Schnitt).
- **Safari-`form_post`-Rückweg** nie belegt; Echtbrowser-Nachweis gehört hierher.
- **Speicher** auf rennwienix knapp; Deploy verlangt ≥ 600 MB frei.
- **Externer Scan** sieht den Host erst mit dem Eintrag in `expected-exposure.json`.
- **Gerätestufe:** Kein Pfad der Geräteliste berührt.

## Analysis

### Type
Feature (Betrieb: Dienst öffnen und einmal echt mit claude.ai verbinden; kein neuer Dienstcode geplant)

### Ist-Stand 2026-11-08 (gelesen über `gh api`, henemm-infra `main`)
- `nginx/loose-ends.henemm.com.conf`: nur `location = /health` (Zone `loose_ends_health` 30 r/m); `= /mcp` und `/` → 404.
- `scripts/deploy-loose-ends.sh:12`: `LE_COMMIT="e62f0d5…"` (#796 S4a) — Dienststand ohne OAuth, ohne Tür.
- `security/expected-exposure.json`: `loose-ends.henemm.com` fehlt in `tls_hosts` und `urls`.
- Offener Infra-PR nur #381 (fremd, Staging-Sweep) → keine Überschneidung.
- Dienstpfade (`server/src/main.ts:142–149`, `oauth-provider.ts:19–28`, `oauth-resource.ts:8`): Issuer-Präfix `/oauth/`,
  Discovery `/.well-known/oauth-authorization-server` und `/.well-known/openid-configuration`, Ressourcen-Metadaten
  `/.well-known/oauth-protected-resource/mcp`, `/mcp`. `/auth/*` (App-Anmeldung, #615 S4) bleibt geschlossen.

### Recherche (2026-11-08, ergänzt die S6-Recherche)
- claude.ai: Redirect `https://claude.ai/api/mcp/auth_callback`; CIMD nur bei `client_id_metadata_document_supported` +
  `none` (haben wir); die CIMD-URL der gehosteten Oberfläche ist nirgends dokumentiert, nur Claude Codes
  `https://claude.ai/oauth/claude-code-client-metadata` (claude.com/docs/connectors/building/authentication; Strata nennt
  ebenfalls eine claude.ai-Adresse) → `allowFetch` auf `https://claude.ai` passt voraussichtlich, beim Verbinden ablesen.
- Sign in with Apple, Services ID: Apples Hilfe verlangt laut Forum die Verifikation jeder Domain per
  `/.well-known/apple-developer-domain-association.txt` (ohne Umleitung, Datei 7 Tage gültig); neuere Berichte (2023)
  richten ohne Verifikation ein. Unsicher → im Portal ablesen. Bietet es „Verify“ an, braucht nginx für genau diese Datei
  eine statische `location`. Quellen: developer.apple.com/forums/thread/119616, …/128652, …/719985.

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| henemm-infra `nginx/loose-ends.henemm.com.conf` | MODIFY | `= /mcp` (Streaming: `proxy_http_version 1.1`, `Connection ""`, `proxy_buffering off`, `proxy_read_timeout 3600s`, Zone `loose_ends_mcp`), `= /.well-known/oauth-protected-resource/mcp`, `= /.well-known/oauth-authorization-server`, `= /.well-known/openid-configuration`, `^~ /oauth/` (Zone `loose_ends_oauth`, `client_max_body_size 64k`); Proxy-Header wie `/health`; `/auth/` und `/` bleiben 404; Kopfkommentar neu; bei Bedarf Apple-Verifikationsdatei |
| henemm-infra `scripts/deploy-loose-ends.sh` | MODIFY | `LE_COMMIT` → `main` nach PR #873 (`ae957ba…`) oder späterer main-Stand zum Deploy-Zeitpunkt |
| henemm-infra `security/expected-exposure.json` | MODIFY | Host in `tls_hosts`; `/health` 200, `/mcp` 401, `/.well-known/oauth-authorization-server` 200, `/auth/apple` 404, `/` 404 |
| Server: Geheimnisdatei des Stapels (`loose-ends/secrets/`, nicht versioniert) | MODIFY | `APPLE_*` (6), `OAUTH_COOKIE_KEYS`, `OAUTH_SIGNING_JWK`, `PUBLIC_URL`; danach `ALLOWED_APPLE_SUBS`; nur Namen prüfen, nie Werte ausgeben |
| loose-ends `docs/artifacts/feat-621-s6b-betrieb/` | CREATE | Belege (Prüfung von außen, Discovery, 401, Verbinden, `accounts = 1`, Tool-Aufruf aus claude.ai) |
| loose-ends `CLAUDE.md` (Betrieb-Zeile) | MODIFY | „only `/health` public“ → geöffnete Pfade, `/auth/*` zu |

### Scope Assessment
- Repo-Dateien: 3 (Infra) + 2 (loose-ends Belege/CLAUDE.md); ca. +70/−10 LoC, kein Dienstcode
- Handarbeit: Apple-Portal (Services ID, ggf. SIWA-Schlüssel), Server (Geheimnisse, nginx, Deploy), Verbinden in claude.ai
- Risk Level: MITTEL — geteiltes nginx (`nginx -t` vor `reload`), und das Öffnen macht die Anmeldung erstmals öffentlich
  (Tür S6a fail closed)

### Technical Approach (Empfehlung)
Reihenfolge so, dass nie ein halb offener Zustand nach außen steht:
1. **Apple-Portal** (Henning meldet sich in Chrome an, ich klicke): Services ID mit Sign in with Apple, primäre App
   `com.henning.looseends`, Domain `loose-ends.henemm.com`, Return-URL `https://loose-ends.henemm.com/oauth/apple/return`.
   Prüfen, welcher der drei `.p8` SIWA trägt (Portal → Keys); fehlt einer, neuen anlegen. Verifikation nur, falls angeboten.
2. **Geheimnisse** auf rennwienix erzeugen/eintragen (Cookie-Schlüssel, ES256-JWK, Token-Schlüssel auf dem Server erzeugt;
   übertragen wird nur der `.p8`), Vollständigkeit nur nach Namen prüfen.
3. **Infra-PR** (nginx, `LE_COMMIT`, Exposure) → CI → Merge; auf dem Server `git pull`, **erst Deploy** (Dienst neu, nginx
   noch zu: Health 200 lokal, Discovery lokal per `curl -H Host:` mit richtigem Issuer), **dann nginx** kopieren,
   `nginx -t`, `reload`.
4. **Prüfung von außen**: Discovery (`issuer` exakt `https://loose-ends.henemm.com`), Ressourcen-Metadaten, `/mcp` ohne
   Token 401 mit `WWW-Authenticate`, `/auth/apple` 404, `/` 404; andere Dienste unverändert (`monitor.sh --status`).
5. **Direkt danach** verbindet Henning in claude.ai den Connector (Apple-Anmeldung, Zustimmungsseite) — das Fenster der Tür
   bleibt Minuten. Danach `accounts` = 1, seine `sub` aus der Datenbank in `ALLOWED_APPLE_SUBS` (nur Server), Neustart über
   das Deploy-Skript, `accounts` weiter 1. Ein Tool-Aufruf (`get_now`) aus claude.ai als Beleg; die CIMD-`client_id` aus
   `oauth_records` ablesen (nur die URL).
6. Belege-PR im loose-ends-Repo, CLAUDE.md-Zeile, Memory.

### Alternativen
- **nginx „alles durch außer `/auth/`“** statt Pfad-Erlaubnisliste: weniger Pflege, aber jeder künftige Dienstpfad wäre
  sofort öffentlich. Verworfen: die Erlaubnisliste ist die bestehende Haltung der Datei.
- **Tür ohne Fenster:** erst #615 S4 (App-Anmeldung) bauen, Hennings `sub` dort gewinnen, dann mit fester Liste öffnen.
  Kippt keine ADR, verschiebt aber die DoD um einen ganzen Schnitt; das Fenster in (5) ist Minuten und wird mit
  `accounts = 1` kontrolliert → nicht empfohlen.
- **Verbinden ohne Öffnen** (Tunnel, `/etc/hosts`): geht nicht, Apple und claude.ai müssen die öffentliche Adresse erreichen.

### Dependencies
- Dienst auf `main` (S1–S6a), Zertifikat (#796 S4a), Postgres-Stapel; Hennings Apple-Portal-Anmeldung; sein claude.ai-Konto.
- Folge: S7, #795, #625 (nimmt die Tür weg), #615 S4.

### Open Questions (vor Phase 5 bei Henning, mit Kontext)
- [ ] Server-Schreibfreigabe für #621 S6b (Grenzen wie 2026-11-03: kein Reboot, kein Neustart anderer Dienste/Docker-Daemon).
- [ ] Zeitpunkt, zu dem er sich im Apple-Portal anmelden und direkt danach claude.ai verbinden kann (zusammen ca. 20 min).
- Gerätestufe: Kein Pfad der Geräteliste berührt.
