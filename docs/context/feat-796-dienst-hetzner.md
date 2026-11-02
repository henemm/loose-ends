# Context: feat-796-dienst-hetzner

## Request Summary
Der Dienst aus `server/` (Weg B, ADR-21) soll dauerhaft auf dem Hetzner-Server `rennwienix` laufen: erreichbar über HTTPS,
Postgres mit Sicherung und einmal geprobter Wiederherstellung, Überwachung mit Meldung nur bei Ausfall (Issue #796, Teil von
Epic #612, Schnitt C7 aus #613). Henning will die Claude-Anbindung forcieren (2026-11-02); #796 ist der Engpass für #621 und #795.

## Related Files
| File | Relevance |
|------|-----------|
| `server/package.json` | `engines.node >=26`, Type-Stripping ohne Build; Abhängigkeiten `pg`, `@modelcontextprotocol/server`, `zod` |
| `server/src/migrate.ts` | `migrate(pool, dir)`: eine Transaktion je Migration. Fehlt: `pg_advisory_lock` gegen zwei gleichzeitige Läufe (#613 C1a F004). **Gehört gerade #615 S1 (Sitzung a7) — nicht anfassen, bis deren Stand gemergt ist** |
| `server/src/mcp.ts` | `mcpHandler` (stateless MCP, Konto nur aus `authInfo`); bisher **kein Prozess-Einstieg, kein Port, kein `listen`** |
| `server/src/orders.ts`, `server/src/transcripts.ts` | Datenzugriff über `pg.Pool`; Fehler-Listener an Pool/Client fehlen (#613 C1a F006) |
| `server/migrations/001_claude_schema.sql` | einziges Schema; #615 S1 fügt gerade eine Migration hinzu |
| `server/scripts/test-local.sh` | Wegwerf-Postgres 18 lokal, Muster für Prüfungen ohne Server |
| `.github/workflows/server.yml` | CI: Node 26 + `postgres:18`, typecheck + test |
| `docs/context/spike-613-backend-weg-b.md` | Herkunft C7; „öffentliche Adresse (Unterdomain von henemm.com) wird vor C7 gefragt“ (Z. 165); Ressourcen: CPU reicht, Speicher knapp bei vielen Claude-Sitzungen, das steuert Henning (Z. 161) |
| `docs/project/00-entscheidungen.md` | ADR-21 (Claude-Fenster, Datenhaltung in iCloud) |
| Repo `henemm/henemm-infra` (auf dem Server `/home/hem/henemm-infra`) | **bestehende Server-Konventionen**: `nginx/*.conf`, `systemd/*.service`, `scripts/backup.sh` (täglich 03:00, restic off-site über WireGuard, ein Betterstack-Heartbeat nur bei Erfolg), `scripts/restore-test-gregor.sh` (Wiederherstellungsprobe in Temp-Ordner), `healthcheck.sh`, `betterstack-telegram.sh`, `docs/deploy.md`, `docs/monitoring.md`; eigene Claude-Instanz `infra` |

## Server-Befund (2026-11-02, nur gelesen)
- Ubuntu, Kernel 6.8, x86_64. RAM 7,7 GB, davon 2,3 GB verfügbar; **Swap 1,9/2,0 GB belegt**. Platte 150 GB, 83 % belegt (25 GB frei). Last ~3.
- **Node 18.19.1** systemweit (Dienst verlangt ≥ 26). Docker vorhanden, Image `node:22-slim` liegt da.
- **Kein Postgres** (weder Paket noch Container). Andere Produkte nutzen SQLite/Dateien (Gregor, Frieda).
- nginx + certbot. `mcp.henemm.com` ist **belegt** (proxy auf 127.0.0.1:8100, obsidian-mcp) → eigene Unterdomain nötig.
- Dienste laufen als systemd-Units mit eigenem Nutzer (z. B. `User=claude-gregor`, `EnvironmentFile=…`), einige als Docker-Container; watchtower aktualisiert Container.
- Überwachung: Betterstack (Free-Plan, Heartbeats) → Telegram; Sammelbecken-Prinzip, ein Backup-Heartbeat für alle.

## Existing Patterns
- Deploy-Konfiguration (nginx, systemd, Skripte) liegt versioniert in `henemm-infra`, nginx/systemd als manuelle Kopien, Skripte laufen direkt aus dem Checkout (auto-deploy alle 5 min).
- Sicherung = Readiness, nicht Liveness: Heartbeat nur, wenn Archiv vollständig UND off-site geschrieben. Wiederherstellung wird mit eigenem Skript in Temp-Ordner bewiesen, ohne Live-Daten zu überschreiben.
- Im Loose-Ends-Repo: Migrationen nur additiv, nummeriert; Tests gegen echtes Postgres (lokal Wegwerf, CI Container).

## Dependencies
- Upstream: Node ≥ 26, Postgres 18, nginx/certbot, restic-Ziel (Heimserver über WireGuard), Betterstack.
- Downstream: #621 (Connector braucht öffentliche HTTPS-Adresse; claude.ai ruft aus 160.79.104.0/21, 10 s Zeitlimit), #795 (App sendet Abschrift, holt Aufträge), #615 (Konten im selben Postgres), #625 (eigener Server vor externen Nutzern).

## Existing Specs
- `docs/specs/spike-613-schnitt-c1a-server-geruest.md` (Gerüst, F004/F006 als offene Punkte)
- `docs/specs/spike-613-schnitt-c4a-mcp-lesen.md` (MCP-Handler ohne Port)

## Risks & Considerations
- **Gemeinsam genutzter Produktivserver**: Mail, n8n, Gregor, Frieda laufen dort. Jede Änderung an nginx oder Speicherlast trifft sie mit. Postgres mit kleinem `shared_buffers`, Speichergrenze für Dienst und DB.
- **Speicher**: nur 2,3 GB frei, Swap fast voll. Alternative: eigener kleiner Server im selben Hetzner-Projekt schon jetzt (Ticket sieht ihn ohnehin vor #625 vor).
- **Node 26 vs. 18**: nicht systemweit aufrüsten (andere Dienste); eigener Node für den Dienst (Container `node:26` oder eigene Installation unter dem Dienstnutzer).
- **Kein Prozess-Einstieg**: `listen`, Pool-Aufbau, `migrate` beim Start und `/health` gibt es noch nicht. Überschneidung mit #615 S3 (HTTP-Rand, a7) möglich → Absprache.
- **Überschneidung mit a7**: `server/src/migrate.ts` und neue Migrationen gehören bis zum Merge #615 S1; F004 danach.
- **Zuständigkeit Server**: Die Instanz `infra` pflegt `henemm-infra`; Änderungen dort mit ihr absprechen (SendMessage), nicht an ihr vorbei.
- **PO-Fragen**: Unterdomain (z. B. `loose-ends.henemm.com` oder `api.loose-ends…`) und ob schon jetzt ein eigener Server.
- Geräteliste der Abnahme: `server/` steht nicht darauf; Nachweis über HTTPS-Aufruf, Neustart, DB-Abbruch, Wiederherstellung.

## Analysis

### Type
Feature (Betrieb, Schnitt C7 aus #613)

### Absprache mit a7 (#615, 2026-11-02)
- #615 S1 fasst `migrate.ts` **nicht** an (nur `002_accounts.sql`, `accounts.ts`, `accounts.test.ts`, eine Zeile `schema.test.ts`); Merge erwartet ~30–60 min nach 2026-11-02 Nachmittag. Der Lock (F004) kommt trotzdem erst auf den gemergten Stand.
- `server/src/main.ts` gehört #796. Routenvergabe als **Tabelle Pfad → Handler**, damit #615 S3 Anmelden/Abmelden/Löschen nur einträgt. `accounts.ts` bleibt unberührt.

### Recherche (2026-11-02)
- `node:26-slim` ist ein offizielles Image (Docker Hub, Stand 26.12.x) → https://hub.docker.com/_/node/tags?name=26
- node-postgres: ohne `pool.on('error')` beendet ein Fehler eines ruhenden Clients (DB-Neustart, Netzabbruch) den Prozess; der Client wird ohnehin verworfen → https://node-postgres.com/apis/pool
- PITR braucht `archive_mode`/`archive_command`, Basissicherung und eine lückenlose WAL-Kette → https://www.postgresql.org/docs/18/continuous-archiving.html
- Server trägt den Dienst (Henning 2026-10-31, Memory `loose-ends-hetzner-speicher-eng`): Speicher ist kein Gegenargument; eigener Server erst vor #625.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/main.ts` | CREATE | Prozess-Einstieg: Pool mit `error`-Listener (F006), `migrate` beim Start mit Wiederholung, `node:http` mit Routentabelle (`/health`, `/mcp`), SIGTERM → `server.close` + `pool.end` |
| `server/src/health.ts` | CREATE | `/health`: 200 erst nach erfolgreichem `migrate` und `SELECT 1`, sonst 503; Fehlerrate (5xx-Anteil der letzten 5 min) im Body, über Schwelle → 503 |
| `server/test/main.test.ts` | CREATE | echter Port gegen Wegwerf-Postgres: `/health`, `/mcp` antwortet, DB-Abbruch per `pg_terminate_backend` überlebt, Neustart |
| `server/package.json` | MODIFY | Skript `start` |
| `server/Dockerfile`, `server/.dockerignore` | CREATE | `node:26-slim`, `npm ci --omit=dev`, Start `node src/main.ts` |
| `.github/workflows/server.yml` | MODIFY | Image-Bau als Prüfung |
| `server/src/migrate.ts`, `server/test/migrate.test.ts` | MODIFY | `pg_advisory_lock` um den ganzen Lauf, Test mit zwei parallelen Läufen (F004) — nach a7-Merge |
| Repo `henemm-infra` | CREATE/MODIFY | `docker-compose` (Dienst + `postgres:18.x` fest, `mem_limit`, watchtower aus, nur 127.0.0.1), nginx-vhost + certbot, `backup.sh` um `pg_dump`, Wiederherstellungsprobe, Betterstack-URL-Monitor auf `/health` → Telegram — mit Instanz `infra` absprechen |

### Scope Assessment
Vier Schnitte, jeder in den Limits:
- **S1** Prozess-Einstieg + `/health` + Fehlerrate (main.ts, health.ts, main.test.ts, package.json) — ~+230 LoC
- **S2** Container-Image + CI-Bau (Dockerfile, .dockerignore, server.yml) — ~+40 LoC
- **S3** migrate-Lock F004 (migrate.ts, migrate.test.ts) — ~+55 LoC, nach a7-Merge
- **S4** Bereitstellung auf rennwienix (henemm-infra) + Abnahmebelege: HTTPS-Aufruf, Neustart, DB-Abbruch, Rückspielen in leere DB
- Risk Level: MEDIUM — geteilter Produktivserver (Mail, n8n, Gregor); Speichergrenzen und nginx-Änderung treffen ihn mit.

### Technical Approach
- **Docker Compose mit zwei Containern** statt systemd + eigenem Node: Node 18 bleibt systemweit unangetastet, Postgres 18 gibt es dort nur so, Speichergrenzen sind direkt setzbar (DB ~512 MB mit `shared_buffers=128MB`, Dienst ~384 MB). Postgres mit fester Version und watchtower-Ausschluss (ein Major-Sprung machte das Datenverzeichnis unlesbar); Dienst-Image aus dem Checkout gebaut, kein `latest`.
- **`/mcp` bleibt bis zur Anmeldung (#615/#621) am Rand gesperrt** (nginx liefert nur `/health` aus): `authInfo` hat ohne Anmeldung kein Konto, der Handler lehnt zwar ab, aber ein offener Endpunkt ohne Anmeldung gehört nicht ins Netz. Entscheidung Tech Lead.
- **Sicherung (Empfehlung, PO-Bestätigung offen):** nächtlicher `pg_dump` ins bestehende restic-Backup (03:00, Heartbeat nur bei Erfolg), Wiederherstellung per Skript in leere DB geprobt — statt PITR.

| Kriterium | PITR (WAL-Archiv) | nächtlicher `pg_dump` in restic |
|---|---|---|
| Aufwand | hoch: `archive_command`, Basissicherung, WAL-Aufbewahrung, Restore mit Zielzeit | niedrig: eine Zeile in `backup.sh`, Restore mit `pg_restore`, Muster `restore-test-gregor.sh` |
| Verlustfenster | Sekunden bis Minuten | bis 24 h |
| Passung ADR-21 | überdimensioniert: Aufgaben liegen in iCloud, die App sendet die Abschrift neu | passt: Abschrift heilt die App, Aufträge sind kurzlebig |
| Last auf geteiltem Server | WAL-Platte, mehr Fehlerquellen | minimal |
| Nicht rekonstruierbar | Konten (#615) | Konten (#615): ≤ 24 h neue Anmeldungen müssten sich neu anmelden |

### Alternativen
- **systemd + eigener Node unter Dienstnutzer, Postgres als Container** — näher an Gregor, aber zwei Betriebsarten für einen Dienst; verworfen.
- **Eigener kleiner Hetzner-Server sofort** — kippt die Absprache vom 2026-10-31 (Server trägt den Dienst, eigener erst vor #625); nicht empfohlen.
- **PITR wie im Ticket** — siehe Tabelle; nachrüstbar mit #625, wenn Konten in Zahl entstehen.
- **Fehlerrate erst als Folgeticket** — kleiner, aber das Ticket nennt sie; bleibt in S1.

### Dependencies
- S1, S2 sofort; S3 nach Merge #615 S1; S4 nach S1+S2 und der Unterdomain-Entscheidung, Infra-Dateien mit Instanz `infra`.
- Downstream: #621 braucht die Adresse und die Freigabe von `/mcp`; #615 S3 trägt Routen in die Tabelle ein.

### Open Questions
- [x] Unterdomain: **`loose-ends.henemm.com`** (Henning, 2026-11-02)
- [x] Sicherung: **nächtlicher `pg_dump` ins restic-Backup reicht**, PITR zurückgestellt bis viele Konten (Henning, 2026-11-02); Rückspielen in leere DB einmal geproben
