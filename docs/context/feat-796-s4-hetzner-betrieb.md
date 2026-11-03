# Context: feat-796-s4-hetzner-betrieb

## Request Summary
Schnitt 4 von #796: Der Dienst aus `server/` (S1–S3 gemergt, PR #813/#814) läuft dauerhaft auf `rennwienix` unter
`https://loose-ends.henemm.com`, mit nächtlichem `pg_dump` im bestehenden Backup, einmal geprobtem Rückspielen in eine leere
Datenbank und Überwachung mit Meldung nur bei Ausfall. DoD aus dem Ticket: Adresse antwortet, Neustart und DB-Abbruch belegt
überstanden, Sicherung in leere DB zurückgespielt.

Vorgänger-Kontext (Analyse für alle vier Schnitte, Server-Befund 2026-11-02): `docs/context/feat-796-dienst-hetzner.md`.

## Related Files
| File | Relevance |
|------|-----------|
| `server/Dockerfile` | Image `node:26-slim`, `PORT=8080`, `HOST=0.0.0.0`, Nutzer `node`, `CMD node src/main.ts`, kein HEALTHCHECK (Compose/monitor prüfen `/health`) |
| `server/src/main.ts` | liest `DATABASE_URL`, `PORT`, `HOST`; Routentabelle `/health`, `/mcp`; migrate mit Wiederholung beim Start; SIGTERM → Exit 0 |
| `server/src/health.ts` | `/health` 200 nur nach migrate + `SELECT 1`; 503 bei DB down oder > 50 % 5xx in 5 min (≥ 20 Anfragen) |
| `.github/workflows/server.yml` | CI-Job `image` baut das Image und startet es gegen Postgres 18 — Muster für den Server-Start |
| `docs/artifacts/feat-796-dienst-hetzner/ac11-echter-lauf.txt` | Beleg S1: DB weg → 503, DB zurück → 200 ohne Neustart |
| Repo `henemm/henemm-infra` (Server `/home/hem/henemm-infra`, Instanz `infra`) | Ziel aller S4-Dateien |
| `henemm-infra/n8n/docker-compose.yml` | **Vorlage Compose**: feste Image-Version, `127.0.0.1:<port>`, watchtower-Labels `enable=true` + `monitor-only=true`, Secrets per Datei unter `./secrets/` |
| `henemm-infra/nginx/frieda.henemm.com.conf` | **Vorlage vhost** mit MCP-Konnektor: `security-headers`, `location = /mcp` mit eigener `limit_req`-Zone, Anthropics Adressen 160.79.104.0/21, `location / { return 404; }`, certbot-Blöcke |
| `henemm-infra/scripts/backup.sh` | 03:00 täglich; Archiv + Readiness-Prüfung (Mindestgröße), restic off-site, Heartbeat nur bei Erfolg; Gregor-Daten als eigener Abschnitt (#184) — dort kommt der `pg_dump` hinzu |
| `henemm-infra/scripts/restore-test-gregor.sh` | **Vorlage Rückspielprobe** (in Temp, ohne Live-Daten zu berühren) |
| `henemm-infra/scripts/monitor.sh` | alle 5 min, `HTTP_CHECKS`-Array (`url|code|name`) → `alert_on_change` → Telegram; geteilter Betterstack-Heartbeat |
| `henemm-infra/docs/deploy.md` | Skripte laufen direkt aus dem Checkout (auto-deploy 5 min); **nginx-Configs und systemd-Units sind versionierte Kopien und werden von Hand installiert** |
| `henemm-infra` Issue #336 | Plan der Instanz `infra` für „Backend + MCP für Restock und Loose Ends auf diesem Server“: Docker Compose, Postgres nur im internen Netz, Speicherlimits, eigener vhost mit Rate-Limit, Secrets außerhalb des Repos, tägliche DB-Sicherung, höchstens **ein** Betterstack-Monitor (7 von 10 belegt), sonst Teil-Check in `monitor.sh`; „DNS-Eintrag macht der PO, exakte Werte werden geliefert“; Aufstocken auf CPX42 vertagt |

## Existing Patterns
- **Container-Dienste** (n8n, watchtower): Compose-Datei im Repo, Ports nur an 127.0.0.1, feste Versionen, watchtower nur beobachtend.
- **Öffentliche Dienste**: nginx-vhost je Unterdomain, certbot schreibt die TLS-Blöcke, unbekannte Pfade → 404, `limit_req` je Ort.
- **Sicherung = Readiness**: Archiv prüfen (Größe/Zählung) vor Heartbeat; off-site über restic/WireGuard.
- **Überwachung**: eine Zeile in `HTTP_CHECKS` reicht für Erreichbarkeit; Meldung nur bei Zustandswechsel (`alert_on_change`).
- **Quellcode auf dem Server**: Frieda zieht ein Repo-Checkout per Timer unter `/srv/...`; `loose-ends` ist **öffentlich**, ein Checkout braucht keinen Schlüssel.

## Dependencies
- Upstream: DNS-Zone henemm.com bei **Namecheap ohne API** (`docs/mail.md` in henemm-infra) — der A-Eintrag `loose-ends` → 178.104.143.19 fehlt (2026-11-03: `dig loose-ends.henemm.com` leer, kein Wildcard). certbot braucht ihn vor dem Zertifikat.
- Upstream: Docker auf rennwienix, `postgres:18`-Image, restic-Ziel, Betterstack, Telegram.
- Downstream: #621 (Connector braucht HTTPS-Adresse und später `/mcp`), #615 S3 (Anmelderouten, laufen hinter demselben vhost), #795 (App sendet Abschrift).

## Existing Specs
- `docs/specs/feat-796-schnitt-1-prozess-einstieg.md` (main.ts, health.ts)
- `docs/specs/feat-796-schnitt-2-image-und-sperre.md` (Dockerfile, CI-Job, migrate-Sperre)

## Risks & Considerations
- **Geteilter Produktivserver** (Mail, n8n, Gregor, Frieda): ein nginx-Fehler beim `reload` trifft alle — `nginx -t` vor jedem reload. Speicher: Swap fast voll (2026-10-27: 1,6/2 GB) → harte `mem_limit` für Postgres und Dienst.
- **Schreibzugriff auf den Server** braucht Hennings ausdrückliche Freigabe; Lesen wird vom Berechtigungssystem teils als „Production Reads“ gesperrt (Memory `loose-ends-hetzner-speicher-eng`).
- **Zuständigkeit `infra`**: Dateien in `henemm-infra` mit der Instanz absprechen (SendMessage), ihr Plan #336 ist die Grundlage; Doppelarbeit vermeiden.
- **DNS**: Namecheap ohne API → Handarbeit. Henning tippt keine Technik selbst (CLAUDE.md global) — Weg: ich trage es im Browser ein, er meldet sich an; oder er bekommt genau die Werte (wie #336 vorsieht). Entscheidung in der Analyse.
- **`/mcp` öffentlich?** Ohne Anmeldung (#615) hat `/mcp` kein Konto; der Vorgänger-Plan sperrt am Rand und gibt nur `/health` frei, bis #615/#621 so weit sind.
- **Image-Herkunft**: Bau auf dem Server aus öffentlichem Checkout (fester Commit) vs. CI pusht nach GHCR; kein `latest`.
- **Belege der DoD** entstehen nur auf dem Server: HTTPS-Abruf, `docker compose restart`, DB-Container stoppen/starten (503 → 200), `pg_dump` → leere DB → `pg_restore` mit Zählvergleich.
- Geräteliste der Abnahme: kein Pfad berührt (`server/` und Infra-Repo stehen nicht darauf).
- Im Loose-Ends-Repo selbst ändert sich voraussichtlich nur Doku (CLAUDE.md-Zeile zum Betrieb, Belege unter `docs/artifacts/`).

## Analysis

### Type
Feature (Betrieb, Schnitt 4 von #796)

### Recherche (2026-11-03)
- Offizielles Image `postgres:18`: ab Version 18 wird `/var/lib/postgresql` gemountet, nicht mehr `/var/lib/postgresql/data` (sonst Exit 1); `POSTGRES_PASSWORD_FILE` liest das Passwort aus einer Datei; `latest`/`18` wandern mit, daher feste Kleinversion (aktuell 18.4 laut Drittquelle, vor dem Bau auf hub.docker.com/_/postgres prüfen) → https://www.dbpro.app/blog/postgres-docker, https://www.cybrosys.com/research-and-development/postgres/step-by-step-guide-on-how-to-run-postgresql-18-in-docker
- Compose ohne Swarm: `mem_limit`/`memswap_limit` auf Dienstebene wirken bei `docker compose up`; Wirkung per `docker inspect` belegen → https://jacar.es/en/docker-resource-limits-and-logging/, https://github.com/docker/compose/issues/5803
- DNS: `dig +short loose-ends.henemm.com` leer (2026-11-03), `frieda.henemm.com` → 178.104.143.19.

### Affected Files (with changes)
Alles im Repo `henemm/henemm-infra` (privat; Skripte per auto-deploy, nginx von Hand installiert):

| File | Change Type | Schnitt | Description |
|------|-------------|---------|-------------|
| `loose-ends/docker-compose.yml` | CREATE | S4a | `db` (`postgres:18.x` fest, nur internes Netz, Volume `/var/lib/postgresql`, `POSTGRES_PASSWORD_FILE`, `shared_buffers=128MB`, `max_connections=20`, `mem_limit=memswap_limit=512m`, watchtower aus) und `server` (Image `loose-ends-server:<sha7>` aus dem Checkout gebaut, `127.0.0.1:<freier Port>:8080`, `env_file: ./secrets/server.env` mit `DATABASE_URL`, `mem_limit=memswap_limit=384m`, `NODE_OPTIONS=--max-old-space-size=256`, `restart: unless-stopped`, Log-Rotation json-file) ~70 LoC |
| `scripts/deploy-loose-ends.sh` | CREATE | S4a | holt den öffentlichen Repo-Stand an festem Commit nach `/srv/loose-ends-src`, baut mit `nice` das Image, `docker compose up -d`, wartet auf `/health` 200 ~40 LoC |
| `nginx/loose-ends.henemm.com.conf` | CREATE | S4a | nur `location = /health` (limit_req), `/mcp` und alles andere 404 bis Anmeldung (#615/#621), security-headers, certbot-Blöcke ~35 LoC |
| `scripts/monitor.sh` | MODIFY | S4a | eine Zeile `HTTP_CHECKS`: `https://loose-ends.henemm.com/health|200|Loose-Ends` (Meldung nur bei Zustandswechsel), erst nach laufendem Dienst |
| `scripts/backup.sh` | MODIFY | S4b | Abschnitt vor restic: `docker exec … pg_dump -Fc`, Readiness per `pg_restore --list` (Tabellenzahl), 30 Tage Aufbewahrung, Fehler → kein Heartbeat (Muster Frieda-Block) ~25 LoC |
| `scripts/restore-test-loose-ends.sh` | CREATE | S4b | Wegwerf-Container `postgres:18.x`, `pg_restore` des jüngsten Dumps, Zeilenzahl je Tabelle gegen Live, danach entfernen ~60 LoC |
| Loose Ends: `docs/artifacts/feat-796-s4-hetzner-betrieb/`, `CLAUDE.md` (eine Zeile Betrieb) | CREATE/MODIFY | beide | Belege, Verweis auf Betrieb |

Secrets (`loose-ends/secrets/`, chmod 600, `.gitignore`) entstehen nur auf dem Server.

### Scope Assessment
- S4a: 4 Dateien Infra, ~150 LoC; S4b: 2 Dateien Infra, ~90 LoC. Zusammen 6 Dateien → über dem Limit von 4–5, daher **zwei Teil-Specs**.
- Risk Level: MEDIUM — geteilter Produktivserver (Mail, n8n, Gregor, Frieda): nginx-Reload trifft alle vhosts, Speicher knapp, Backup-Abschnitt kann den gemeinsamen Heartbeat kippen.

### Technical Approach (Empfehlung)
- **Image auf dem Server bauen** aus dem öffentlichen Checkout an festem Commit (kein Schlüssel, kein Registry-Token, kein `latest`); der Commit steht versioniert in `henemm-infra`. Bau außerhalb 03:00, mit `nice`, vorher `free -m`/`df -h`.
- **Compose nach n8n-Muster**, harte Speichergrenzen inkl. Swap-Deckel (zusammen ≤ 900 MB), Postgres ohne Host-Port.
- **nginx:** erst Port-80-Block, `nginx -t`, `reload`, dann certbot, erneut `nginx -t`/`reload`. Nie `restart`.
- **Belege der DoD ohne Nebenwirkung auf andere Dienste:** HTTPS-Abruf `/health` 200 und `/mcp` 404; `docker compose restart server` und `docker kill` des Dienstes (Restart-Policy) → 200; `docker compose stop db` → 503, `start db` → 200 ohne Dienst-Neustart. **Kein Reboot, kein Neustart des Docker-Daemons** (träfe Mail/n8n).
- **S4b:** einmal `backup.sh` von Hand, Heartbeat beobachten; Rückspielprobe mit Zählvergleich.
- **Abstimmung `infra`:** Plan henemm-infra#336 ist Grundlage; die Instanz ist von hier nicht per SendMessage erreichbar → Kommentar an #336 mit dem Schnitt, Änderungen als PR im Infra-Repo.

### Alternativen
- **CI pusht Image nach GHCR (Digest-Pin):** reproduzierbar, kein Bau auf dem engen Server; braucht Workflow-Änderung im Loose-Ends-Repo und ein öffentliches Paket oder ein Pull-Token auf dem Server. Sinnvoll mit #625 (eigener Server, automatische Deploys).
- **systemd + eigener Node 26 unter Dienstnutzer:** verworfen (zwei Betriebsarten, Node 18 systemweit).
- **Betterstack-URL-Monitor statt `monitor.sh`-Zeile:** belegt einen der 3 freien Plätze; `monitor.sh` meldet über Telegram ebenso, nur bei Komplettausfall des Servers greift ohnehin der geteilte Heartbeat.
- **Passwort als Datei statt `env_file`:** bräuchte `DATABASE_URL_FILE` in `main.ts`; Risiko wie n8n, daher `env_file` mit chmod 600.

### Dependencies
1. Hennings Freigabe für Schreibzugriffe auf rennwienix.
2. A-Eintrag `loose-ends` → `178.104.143.19` bei Namecheap (keine API) — vor certbot, längste Wartezeit, daher zuerst.
3. S4a vor S4b (Rückspielprobe braucht echte Tabellen).
- Downstream: #621 (öffnet `/mcp` im vhost), #615 S3 (Anmelderouten im selben vhost).

### Open Questions
- [x] Adresseintrag: **Henning trägt selbst bei Namecheap ein** (2026-11-03): Typ `A Record`, Host `loose-ends`, Wert `178.104.143.19`, TTL Automatic; kein AAAA (Nachbaradressen haben keinen). Vor certbot mit `dig +short loose-ends.henemm.com` prüfen.
- [x] Schreibzugriff auf rennwienix: **freigegeben für S4a und S4b** (Henning, 2026-11-03); kein Reboot, kein Neustart anderer Dienste oder des Docker-Daemons.
