# Context: feat-796-s2-betrieb

## Request Summary
Zweiter Durchgang für #796 nach Schnitt 1 (PR #813, Prozess-Einstieg und `/health`): Der Dienst aus `server/` läuft dauerhaft
auf dem Hetzner-Server `rennwienix` unter `https://loose-ends.henemm.com`. Er hat eine nächtliche Sicherung, das Rückspielen
in eine leere Datenbank ist einmal geprobt, und eine Überwachung meldet sich nur bei Ausfall. Dazu kommt der `migrate`-Lock (F004).

Grundlage ist der erste Kontext `docs/context/feat-796-dienst-hetzner.md` mit Server-Befund, Mustern, Recherche und Schnittplan
S1–S4. Hier steht nur, was sich seitdem geändert hat und was dieser Durchgang braucht.

## Stand seit dem ersten Kontext
- **S1 gemergt** (PR #813, 2026-11-03). Vorhanden sind `server/src/main.ts` (Routentabelle, Pool mit `error`-Listener, also F006
  erledigt, `migrate` mit Wiederholung, SIGTERM), `server/src/health.ts` und `npm start`. Belegt mit einem echten Lauf, darunter
  ein DB-Abbruch ohne Neustart: `docs/artifacts/feat-796-dienst-hetzner/ac11-echter-lauf.txt`.
- **#615 S1 gemergt** (PR #812): `002_accounts.sql`, `accounts.ts`. Die Sperre auf `migrate.ts` aus der Absprache mit a7 ist
  damit aufgehoben. #615 S2/S3 (Dienst, offline) sind offen. S3 trägt Routen in die Tabelle in `main.ts` ein, fasst `migrate.ts`
  aber nicht an.
- Keine offenen PRs. Der Remote-Zweig `feat-796-dienst-hetzner` trägt S1 (bereits gemergt).
- Die Entscheidungen von Henning (2026-11-02) gelten weiter: Adresse `loose-ends.henemm.com`, nächtlicher `pg_dump` ins
  restic-Backup statt PITR, Rückspielen einmal proben.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/migrate.ts` | `migrate(pool, dir)`: Tabelle anlegen, Erledigte lesen, je Migration eine Transaktion. **Fehlt `pg_advisory_lock`** (F004): Zwei gleichzeitige Starts (z. B. Neustart während eines alten Prozesses) könnten dieselbe Migration doppelt versuchen |
| `server/test/migrate.test.ts`, `server/test/db.ts` | Bestehende Migrationstests gegen echtes Postgres; Ort für einen Paralleltest |
| `server/src/main.ts` | `start()`/`main()`: liest `DATABASE_URL`, `PORT` (8080), `HOST` (127.0.0.1); Logzeilen ohne Inhalte. Bekannte Grenze: Fehler vor `start()` ohne ISO-Präfix, wird unter dem Prozessverwalter sichtbar |
| `server/package.json` | Node ≥ 26, `npm start` = `node src/main.ts`, keine Build-Stufe |
| `.github/workflows/server.yml` | CI: typecheck + test gegen `postgres:18`; noch kein Image-Bau |
| (neu) `server/Dockerfile`, `server/.dockerignore` | geplant in S2 des ersten Kontexts: `node:26-slim`, `npm ci --omit=dev` |
| Repo `henemm/henemm-infra` | Server-Konventionen (gelesen über die GitHub-API, nicht über SSH): `mcp-obsidian/docker-compose.yml` + `Dockerfile` (**nächstes Vorbild**: eigener Dienst als Compose-Stapel), `nginx/mcp.henemm.com.conf` (Proxy auf 127.0.0.1, `limit_req`, Certbot-verwaltet), `scripts/backup.sh` (täglich, Readiness-Heartbeat nur wenn Archiv vollständig und restic off-site geschrieben; Gregor/Frieda als `tar`), `scripts/restore-test-gregor.sh`, `scripts/monitor.sh`, `docs/deploy.md`, `docs/monitoring.md`, `watchtower/docker-compose.yml` |

## Existing Patterns
- **henemm-infra-Deploy** (`docs/deploy.md`): Skripte laufen direkt aus `/home/hem/henemm-infra`, Cron zieht `main` alle 5 min
  nach (`auto-deploy-infra.sh`) und prüft die Syntax. **nginx-Configs, systemd-Units und Compose-Stapel werden nicht automatisch
  ausgerollt**, nur von Hand kopiert bzw. gestartet. Wer auf `main` von henemm-infra pusht, führt Code auf dem Server aus.
- **Sicherung als Readiness**: ein gemeinsamer Betterstack-Heartbeat für alle Sicherungen, nur bei vollständigem Archiv und
  erfolgreichem restic. Ein neuer Teil (pg_dump) muss sich in diese Kette einfügen, sonst kippt der Heartbeat für alle.
- **Rückspielprobe** in einen Temp-Ordner, ohne Live-Daten zu berühren (`restore-test-gregor.sh`).
- **Überwachung** über Betterstack (Free-Plan) → Telegram. `monitor.sh` sammelt Prüfungen in einen Heartbeat.
- Im Loose-Ends-Repo: Migrationen nur additiv; Tests gegen echtes Postgres (lokal `server/scripts/test-local.sh`, CI-Container).

## Dependencies
- Upstream: Docker auf `rennwienix`, `node:26-slim`, `postgres:18` (Version fest, von watchtower ausgenommen), nginx + certbot,
  DNS-Eintrag für `loose-ends.henemm.com`, restic-Ziel, Betterstack.
- Downstream: #621 (Connector braucht die öffentliche HTTPS-Adresse und später die Freigabe von `/mcp`), #615 S2/S3 (Anmeldung im
  selben Dienst), #795 (App sendet Abschrift), #625 (eigener Server vor externen Nutzern).

## Existing Specs
- `docs/specs/feat-796-schnitt-1-prozess-einstieg.md` (S1, gemergt)
- `docs/specs/spike-613-schnitt-c1a-server-geruest.md` (F004/F006 als Herkunft)

## Risks & Considerations
- **Zugriff auf den Produktivserver.** Bisher ist nur der lesende Befund vom 2026-11-02 belegt. Das Berechtigungssystem sperrt
  lesendes SSH zeitweise als „Production Reads“ (Memory `loose-ends-hetzner-speicher-eng`). Schreibendes Ausrollen
  (Compose-Stapel starten, nginx-vhost, certbot, Crontab) ist ein nach außen wirkender, schwer umkehrbarer Schritt auf einem
  Server, auf dem Mail, n8n, Gregor und Frieda laufen. In der Analyse klären: Wer rollt aus (diese Sitzung per SSH, die Instanz
  `infra` über henemm-infra oder ein eng gebundener CI-Weg wie `ci-ssh-dispatch.sh`), und wo liegt die Freigabe.
- **Zuständigkeit henemm-infra**: Die Instanz `infra` pflegt das Repo. Änderungen dort werden abgestimmt (SendMessage), nicht an
  ihr vorbei. Ein Push auf `main` dort wird binnen 5 min auf dem Server wirksam.
- **DNS** für `loose-ends.henemm.com`: Wo die Zone liegt und wer den A/AAAA-Eintrag setzt, ist noch offen. Ohne Eintrag kein
  Zertifikat.
- **Code-Transport auf den Server**: entweder ein Checkout von `loose-ends` auf dem Server mit `docker compose build`, oder ein
  CI-gebautes Image (GHCR) mit festem Tag. Bei einem privaten Repo braucht beides Zugangsdaten auf dem Server. Wahl in der Analyse.
- **Speicher**: Laut Henning trägt der Server den Dienst. Trotzdem braucht der Stapel feste Grenzen (`mem_limit`), weil der Swap
  am 2026-11-02 fast voll war.
- **`/mcp` bleibt am Rand gesperrt**, bis die Anmeldung steht (#615/#621). nginx reicht nur `/health` durch (Entscheidung aus dem
  ersten Kontext).
- **Scope-Grenzen**: Repo-Teil (Lock, Dockerfile, CI) und Server-Teil (henemm-infra) sind getrennte Dateigebiete. Die Analyse muss
  den Durchgang in Schnitte ≤ 250 LoC / 4–5 Dateien teilen. Die Abnahmebelege (HTTPS-Aufruf, Neustart, DB-Abbruch,
  Rückspielen) entstehen erst auf dem Server.
- Geräteliste der Abnahme: `server/` steht nicht darauf. Der Nachweis läuft über echte Aufrufe gegen den Dienst.

## Analysis

### Type
Feature (Betrieb, #796 Schnitte S2 + S3 aus dem ersten Kontext). S4 (Ausrollen auf `rennwienix`) folgt als eigener Workflow.

### Befunde (2026-11-03)
- **Repo `henemm/loose-ends` ist öffentlich.** Ein Checkout auf dem Server braucht keine Zugangsdaten; ein GHCR-Image ebenso wenig
  nötig. `henemm-infra` ist privat.
- **DNS:** `loose-ends.henemm.com` hat keinen Eintrag, es gibt keinen Wildcard (`zzz-test-123.henemm.com` leer). `henemm.com`,
  `www`, `mcp` zeigen auf `178.104.143.19`. Zone bei Namecheap (`dns1/2.registrar-servers.com`), keine Automatisierung in den
  henemm-Repos. Den A-Eintrag setzt Henning oder ich im Browser mit seiner Anmeldung (Muster CloudKit-Console) — Frage für S4.
- **Überwachung:** Betterstack Free = 10 Monitore + Heartbeats zusammen, laut `backup.sh` ausgereizt. Kein eigener URL-Monitor.
  Stattdessen Einträge in `monitor.sh`: `HTTP_CHECKS` (`https://loose-ends.henemm.com/health|200|Loose Ends`) und
  `DOCKER_CONTAINERS` (Dienst, Postgres). `alert_on_change` meldet nur beim Wechsel ok→fail und zurück = „nur bei Ausfall“.
- **Sicherung:** `backup.sh` hängt jeden Teil an den einen Heartbeat (nur bei Erfolg + restic). `pg_dump -Fc` aus dem Container
  in `BACKUP_DIR`, Größen-/Lesbarkeitsprüfung (`pg_restore --list`), dann restic. Rückspielprobe nach Muster
  `restore-test-gregor.sh` in einen Wegwerf-Container `postgres:18`.
- **Ausrollweg auf dem Server:** nginx-vhost, Compose-Stapel und Crontab werden in henemm-infra nur versioniert und von Hand
  ausgerollt (`docs/deploy.md`). `ci-ssh-dispatch.sh` ist an Gregor gebunden (drei feste Befehle). Ein CI-Ausrollen für Loose Ends
  bräuchte einen eigenen gebundenen Schlüssel — nicht in diesem Ticket.
- **`migrate` (F004):** `pool.query` für `CREATE TABLE`/`SELECT`, je Migration ein eigener Client. Zwei gleichzeitige Läufe auf
  leerer DB lesen beide „nichts erledigt“ und spielen 001 doppelt; einer scheitert an `schema_migrations`-PK oder „already exists“.
  Nachstellen im RED-Test (zwei `migrate` parallel gegen Wegwerf-Postgres).
- **Container-Start:** `main.ts` bindet standardmäßig `127.0.0.1`; im Container muss `HOST=0.0.0.0` gesetzt sein, der Host
  veröffentlicht nur `127.0.0.1:<port>`. Laufzeit braucht nur `pg`, `@modelcontextprotocol/server`, `zod` → `npm ci --omit=dev`.
  Type-Stripping greift nicht in `node_modules`, `src/` hat nur löschbare Typen (läuft heute schon per `npm start`).

### Recherche
- Session-Advisory-Locks gelten nur, solange Sperren, Arbeit und Entsperren auf **derselben Verbindung** laufen; hinter einem
  Transaktions-Pooler (PgBouncer) brechen sie → hier kein Pooler, direkte Verbindung. Quellen:
  https://gitlab.com/gitlab-org/gitlab/-/work_items/608173, https://www.netdata.cloud/guides/pgbouncer/pgbouncer-advisory-locks-transaction-mode/
- Betterstack Free: 10 Monitore & Heartbeats zusammen, 3-min-Takt: https://betterstack.com/pricing
- `node:26-slim` offizielles Image (erster Kontext): https://hub.docker.com/_/node/tags?name=26

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/migrate.ts` | MODIFY | Ein Client für den ganzen Lauf: `pg_advisory_lock(<feste Zahl>)`, dann Tabelle anlegen, Erledigte lesen, je Migration `BEGIN…COMMIT` auf demselben Client; `pg_advisory_unlock` im `finally`, kaputte Verbindung wird verworfen |
| `server/test/migrate.test.ts` | MODIFY | Zwei (bzw. drei) `migrate` gleichzeitig auf leerer DB: beide erfolgreich, jede Migration genau einmal in `schema_migrations`, Rückgabe der Läufe zusammen = alle Namen; Sperre nach Fehler wieder frei |
| `server/Dockerfile` | CREATE | `node:26-slim`, Nutzer `node`, `npm ci --omit=dev`, `ENV HOST=0.0.0.0 PORT=8080`, `CMD ["node","src/main.ts"]` |
| `server/.dockerignore` | CREATE | `node_modules`, `test`, `scripts`, Logs |
| `.github/workflows/server.yml` | MODIFY | Job „Image“: `docker build server/`, Container gegen den `postgres:18`-Dienst starten, `curl /health` bis 200, Container-Log ohne Inhalte prüfen |

### Scope Assessment
- Files: 5 (Limit 4–5)
- Estimated LoC: +~130/−~15 (Lock ~25, Test ~50, Dockerfile ~15, .dockerignore ~6, CI ~35)
- Risk Level: LOW — nur Repo, nichts auf dem Server; `migrate` ist der Startpfad, durch bestehende + neue Tests abgedeckt.
- Arbeitszweig: neu von `origin/main` (der Zweig `feat-796-dienst-hetzner` trägt den gemergten S1).

### Technical Approach
1. **Lock (S3):** Session-Advisory-Lock auf einem einzigen Client für den ganzen Lauf — einfachste korrekte Form, weil die
   Verbindung direkt ist. Der zweite Start wartet, liest danach den vollen Stand und hat nichts zu tun.
2. **Image (S2):** Gebaut auf dem Server aus einem Checkout des öffentlichen Repos, Tag = Commit (Muster `mcp-obsidian`: Compose
   mit `image:` aus Env). Die CI baut dasselbe Dockerfile und startet es einmal gegen Postgres 18 — damit ist belegt, dass das
   Image läuft, bevor der Server es baut.
3. **S4 (nächster Workflow, henemm-infra):** Compose-Stapel `loose-ends/` (Dienst + `postgres:18.x` fest, `mem_limit`,
   watchtower-Ausschluss, nur `127.0.0.1`), nginx-vhost mit nur `/health` durchgereicht + certbot, `backup.sh` um `pg_dump`,
   Rückspielprobe, `monitor.sh`-Einträge; mit der Instanz `infra` abgestimmt; Ausrollen erst nach Hennings ausdrücklicher Freigabe
   für Schreibzugriffe auf dem Produktivserver; DNS-Eintrag vorher.

### Alternativen
| Frage | Empfehlung | Alternative | Warum nicht |
|---|---|---|---|
| Lock-Art | Session-Lock auf einem Client | `pg_advisory_xact_lock` je Migration + Neulesen | mehr Code, nur nötig hinter einem Transaktions-Pooler, den es nicht gibt |
| Code-Transport | Bau auf dem Server aus öffentlichem Checkout | CI baut Image nach GHCR, Server zieht per Digest | erstes Paket ist privat, öffentlich stellen nur in der Web-Oberfläche; zusätzlicher `packages: write`-Pfad. Vorteil (kein Bau auf dem knappen Server) nachrüstbar |
| Überwachung | `monitor.sh`-Einträge | eigener Betterstack-URL-Monitor | Free-Plan ausgereizt; würde Bezahlplan oder Umbau der Sammelbecken verlangen |
| Ausrollen | von Hand nach Freigabe (henemm-infra-Konvention) | eigener gebundener CI-Schlüssel wie `ci-ssh-dispatch.sh` | lohnt erst bei häufigen Releases; eigenes Ticket |
| Schnittgrenze | S2+S3 hier, S4 eigener Workflow | alles in einem | sprengt 4–5 Dateien und mischt zwei Repos |

### Dependencies
- S2/S3 sofort, keine Sperre mehr (#615 S1 gemergt, fasst `migrate.ts` nicht an; #615 S3 nur `main.ts`-Routen).
- S4 braucht: diesen Schnitt gemergt, DNS-Eintrag, Abstimmung mit `infra`, Hennings Freigabe für Schreibzugriff auf `rennwienix`.

### Open Questions
- [ ] (S4, nicht für diese Spec) DNS-Eintrag `loose-ends.henemm.com` → `178.104.143.19`: setzt Henning, oder ich im Browser mit seiner Anmeldung?
- [ ] (S4) Freigabe für Schreibzugriff auf `rennwienix` (Compose starten, nginx, certbot, Crontab) — wird vor S4 erfragt.
