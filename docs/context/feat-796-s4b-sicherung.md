# Context: feat-796-s4b-sicherung (#796 Schnitt S4b)

## Request Summary
Die Postgres-Datenbank des Loose-Ends-Dienstes (`loose-ends-db` auf `rennwienix`, seit S4a in Betrieb) wird jede Nacht im
bestehenden Backup mitgesichert (lokal und off-site über restic), und eine Sicherung wird nachweislich in eine leere
Datenbank zurückgespielt. Danach ist die Definition of Done von #796 erfüllt und das Ticket kann schließen.

Entscheidungen, die schon stehen: nächtlicher `pg_dump` statt Wiederherstellung auf einen Zeitpunkt (PITR) — Henning,
2026-11-02 (`docs/context/feat-796-dienst-hetzner.md`, Zeile 113); Schreibzugriff auf `rennwienix` für S4a und S4b frei —
Henning, 2026-11-03 (kein Reboot, kein Neustart fremder Dienste oder des Docker-Daemons). Schnittplan aus der S4a-Analyse:
`docs/context/feat-796-s4-hetzner-betrieb.md` Zeilen 74–75, 89.

## Related Files (Repo `henemm/henemm-infra`, Stand main `69c7a62`)

| File | Relevance |
|------|-----------|
| `scripts/backup.sh` (242 Zeilen) | Cron `0 3 * * *` als `hem` (crontab, Log `/home/hem/backups/backup.log`). Abschnitte: Server-Config-tar → Gregor-Daten-tar (Zählvergleich) → Frieda-Daten-tar (Zählvergleich) → restic.env → Secret-Dateien sammeln → n8n-Snapshot (`backup-n8n-snapshot.sh`) → `restic backup` mit allen Pfaden → sonntags `restore-test-gregor.sh` → **ein** Betterstack-Heartbeat nur, wenn alles ok. Jeder Abschnitt bricht bei Fehler mit „Heartbeat NICHT gepingt“ ab. Aufbewahrung lokal 30 Tage per `find -mtime +30 -delete`. **Hier kommt der `pg_dump` hinzu.** |
| `scripts/backup-n8n-snapshot.sh` | **Nächstes Muster** für eine Datenbank: eigenes Skript, `set -euo pipefail`, legt einen konsistenten Schnappschuss in einem Ordner ab, Readiness (integrity_check + Mindestinhalt), Modus 700/600, **unkomprimiert** wegen restic-Deduplizierung (#228), über Umgebungsvariablen testbar (`SUDO=""`, `OUT_DIR`). `backup.sh` ruft es auf und gibt den Ordner an `restic backup`. |
| `scripts/restore-test-gregor.sh` | **Vorlage Rückspielprobe**: als root, holt den jüngsten Off-Site-Snapshot (`restic snapshots --tag offsite --latest 1`), RPO-Wache (> 48 h = Befund), `restic restore` in `mktemp -d` mit `umask 077` und `trap cleanup`, inhaltlicher Vergleich gegen live, überschreibt nichts. Sonntags aus `backup.sh` aufgerufen, hängt am selben Heartbeat. |
| `tests/test_backup_n8n_snapshot.py` | **Testmuster**: pytest, ruft das Skript mit Umgebungsvariablen und Wegwerf-Daten auf; prüft Erfolg, Fehlerfälle und per Textprüfung, dass `backup.sh` den Snapshot vor dem Heartbeat in `restic backup` aufnimmt. |
| `tests/test_backup_frieda.py` | Textprüfungen an `backup.sh` für den Frieda-Abschnitt (Muster für einen neuen Abschnitt). |
| `loose-ends/docker-compose.yml` (S4a) | Container `loose-ends-db` (`postgres:18.6`, kein Host-Port, Nutzer und DB `looseends`, Volume `loose-ends-db`, internes Netz). Zugriff für den Dump nur per `docker exec`. |
| `docs/backup-offsite.md` | restic-Ziel (Heimserver, append-only, über WireGuard), Wachstum, Rückspielen. Bekommt eine Zeile zu Loose Ends. |
| `README.md` Zeile 86/102 | nennt `backup.sh` „sonntags“ — veraltet (Cron läuft täglich); nicht Teil dieses Schnitts. |

Loose-Ends-Repo: `CLAUDE.md` (Zeile „Betrieb“ um die Sicherung ergänzen), Belege unter `docs/artifacts/feat-796-s4b-sicherung/`.

## Existing Patterns
- Ein Abschnitt je Datenquelle in `backup.sh`, mit eigenem Kommentarblock (Anlass, Ticket), Readiness-Prüfung und Abbruch ohne Heartbeat.
- Datenbanken als konsistenter Schnappschuss über das Werkzeug der Datenbank (SQLite `.backup`), nicht als Dateikopie.
- Unkomprimierte Ablage, damit restic dedupliziert (Messung #228: gzip-Archive dedupen nicht).
- Rückspielprobe vom Off-Site-Snapshot aus, in Temp, nichts überschreiben, sonntags, am selben Heartbeat (Betterstack-Kontingent voll).
- Infra-Tests: pytest mit Wegwerf-Daten über Umgebungsvariablen; Textprüfungen an `backup.sh`.

## Dependencies
- Upstream: `docker exec loose-ends-db pg_dump` (18.6, gleiche Version wie der Server, kein Versionskonflikt), `restic` + `/etc/henemm/restic.env`,
  WireGuard zum Heimserver, `postgres:18.6`-Image lokal vorhanden (für einen Wegwerf-Container der Probe).
- Downstream: Betterstack-Heartbeat des Backups (Ausbleiben = Alarm); Speicher und Platte des geteilten Servers.

## Ist-Stand am Server (lesend, 2026-11-04)
- Loose-Ends-DB: Tabellen `accounts`, `apple_tokens`, `order_results`, `orders`, `sessions`, `transcripts` je **0 Zeilen**,
  `schema_migrations` 2 Zeilen. Kein Nutzer ist angemeldet (`/mcp` geschlossen bis #615/#621).
- Platte `/`: 150 G, 126 G belegt, 19 G frei (88 %). Ein leerer Dump ist wenige KB groß.
- `pg_dump (PostgreSQL) 18.6` im Container.

## Existing Specs
- `docs/specs/feat-796-schnitt-4a-betrieb.md` — Betrieb, Abschnitt „Nicht in diesem Schnitt“ beschreibt S4b.
- `docs/specs/feat-796-schnitt-1-prozess-einstieg.md`, `…-schnitt-2-image-und-sperre.md` — Dienst und Migrationen.

## Risks & Considerations
- **Gemeinsamer Heartbeat:** Ein Fehler im neuen Abschnitt hält den Heartbeat für **alle** Sicherungen an (Gregor, Frieda, n8n).
  Das ist gewollt (Readiness), heißt aber: ein Fehlalarm aus Loose Ends sieht aus wie ein Ausfall des ganzen Backups.
- **Leere Datenbank:** Mit 0 Nutzerzeilen beweist ein Zählvergleich wenig. Die Readiness kann nur Struktur prüfen (Tabellen
  im Dump, `schema_migrations` ≥ 2). Für die Rückspielprobe braucht es entweder eine Probezeile oder einen Vergleich von
  Struktur und `schema_migrations`.
- **Wegwerf-Container für die Probe** verbraucht Speicher (knapp, Swap fast voll): harte Grenze, sofort entfernen, nie das
  Volume oder Netz des Live-Stapels anfassen.
- **Secrets:** Der Dump enthält künftig verschlüsselte Apple-Token und Sitzungs-Hashes; Ablage 600, restic verschlüsselt.
  `secrets/server.env` liegt unter `/home/hem/henemm-infra/loose-ends/secrets/` — wird es von der Secret-Sammlung
  (`-maxdepth 3 -name '*.env'`) schon erfasst? Zu prüfen in der Analyse (Tiefe 3 ab `/home/hem/henemm-infra` reicht für
  `loose-ends/secrets/server.env`).
- **Zeitfenster 03:00:** Das Deploy-Skript sperrt 02:45–03:30; ein manueller Probelauf von `backup.sh` erzeugt einen
  zusätzlichen restic-Snapshot und ein zusätzliches Archiv je Quelle (Platz, append-only), sonst keine Wirkung.
- **Dateigrenze:** `backup.sh` (MODIFY), neues Dump-Skript oder Abschnitt, neues Rückspielskript, Test(s), `docs/backup-offsite.md`
  — die Zahl der Dateien ist in der Analyse gegen das Limit (4–5) zu halten.
- Abstimmung mit der Instanz `infra` per Kommentar an henemm-infra#336 vor dem PR, wie in S4a.

## Analysis

### Type
Feature (Betrieb, Repo `henemm/henemm-infra`; im Loose-Ends-Repo nur `CLAUDE.md` und Belege)

### Recherche (2026-11-04)
- Komprimierte Dumps verhindern restics Deduplizierung; der Custom-Format-Dump von `pg_dump` ist standardmäßig komprimiert
  (`--compress=0` schaltet ab). Plain-SQL wird mit `psql` zurückgespielt. Quellen: https://forum.restic.net/t/backing-up-database-large-snapshot-size/4352,
  https://simplebackups.com/blog/postgresql-backup-formats, pgsql-admin-Liste (postgrespro.com). Deckt sich mit der Messung #228.
- `pg_dump` arbeitet in einer Snapshot-Transaktion (konsistent), der Container läuft weiter — Gegenstück zu SQLite `.backup`.

### Gelesener Stand (gh api, main von henemm-infra, 2026-11-04)
- `scripts/backup.sh`: Abschnitte gehen an `restic backup … "$BACKUP_FILE" "$DATA_FILE" "$FR_DATA_FILE" "$N8N_SNAPSHOT_DIR" "${SECRET_FILES[@]}"`;
  der n8n-Snapshot läuft per `OUT_DIR=… bash …/backup-n8n-snapshot.sh` vor dem restic-Schritt; sonntags `sudo -n bash restore-test-gregor.sh`.
- Secrets: `loose-ends/secrets/server.env` liegt in Tiefe 3 unter `/home/hem/henemm-infra` und wird von `SECRET_FILES` bereits erfasst
  (trägt `DATABASE_URL`, später den Schlüssel für `apple-vault`). `secrets/db-password` passt nicht aufs Namensmuster und wird **nicht**
  erfasst — unkritisch: das Passwort steht auch in `DATABASE_URL`, und eine neue DB bekommt ohnehin ein gesetztes Passwort. Kein Handlungsbedarf.
- `pg_dump` sichert keine Rollenpasswörter (nur Datenbankinhalt) — gewollt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| henemm-infra `scripts/backup-loose-ends-snapshot.sh` | CREATE | `docker exec loose-ends-db pg_dump -U looseends -d looseends` als **Plain-SQL, unkomprimiert** nach `OUT_DIR/looseends.sql` (tmp → mv), Ordner 700, Datei 600. Readiness: Endmarke „PostgreSQL database dump complete“, Zahl `CREATE TABLE` im Dump = Zahl der Live-Tabellen (`information_schema`), `schema_migrations` mit ≥ 1 Zeile im Dump. Über `DOCKER`, `CONTAINER`, `OUT_DIR` testbar (Muster n8n). |
| henemm-infra `scripts/backup.sh` | MODIFY | Abschnitt mit Kommentarblock (#796), Aufruf vor restic, Ordner im `restic backup`. |
| henemm-infra `tests/test_backup_loose_ends.py` | CREATE | pytest mit Attrappe für `docker` (liefert einen Wegwerf-Dump): Erfolg, abgeschnittener Dump, fehlende Tabelle, `docker exec` scheitert → Exit ≠ 0 und keine Datei; Textprüfung an `backup.sh` (Aufruf vor restic, Ordner im restic-Aufruf, vor dem Heartbeat). |
| henemm-infra `docs/backup-offsite.md` | MODIFY | Zeile Loose Ends: was, wo, wie zurückspielen (`psql -v ON_ERROR_STOP=1 < looseends.sql`). |
| loose-ends `CLAUDE.md` | MODIFY | Betriebszeile um die Sicherung ergänzen. |

Folge-Workflow S4b-2: `scripts/restore-test-loose-ends.sh` (CREATE), `backup.sh` (MODIFY, Sonntagsaufruf), Test.

### Scope Assessment
- Gesamt S4b (Dump + automatische Rückspielprobe): ~150 LoC Code + ~150 LoC Tests ≈ 300 → über ±250 (Lehre #615 S2a: Tests ≈ 2–2,5× Code bei Sicherheitsprüfungen).
- **S4b-1 (dieser Workflow):** 4 Dateien Infra + `CLAUDE.md`, ≈ +170 LoC (Skript ~55, backup.sh ~20, Tests ~90, Doku ~5).
- **S4b-2 (Folge-Workflow):** wöchentliche Rückspielprobe ≈ +180 LoC.
- Risk Level: MEDIUM — geteilter Heartbeat aller Sicherungen; ein Fehler im neuen Abschnitt alarmiert für das ganze Backup.

### Technical Approach (Empfehlung)
1. **S4b-1: nächtlicher Dump + einmaliger Rückspielbeweis.** Neues Skript nach dem n8n-Muster, eingehängt in `backup.sh` vor restic.
   Plain-SQL unkomprimiert (Deduplizierung, `psql` zum Zurückspielen, DB winzig). Nach dem Merge (auto-deploy) ein Probelauf außerhalb
   02:45–03:30: Dump schreiben, `restic backup` (zusätzlicher Snapshot), dann **einmal** den Dump aus dem Off-Site-Snapshot holen und in
   einen Wegwerf-Container `postgres:18.6` (`--network none`, `--memory 256m`, `--rm`, ohne Volume) zurückspielen; Vergleich Tabellenliste
   und `schema_migrations` gegen live. Beleg unter `docs/artifacts/feat-796-s4b-sicherung/`. Keine Probezeile in die Live-DB.
2. **S4b-2: Rückspielprobe automatisch, sonntags**, Muster `restore-test-gregor.sh`, am selben Heartbeat. Danach schließt #796.

### Alternativen
- **Custom-Format `-Fc --compress=0`** statt Plain-SQL: erlaubt `pg_restore` einzelner Tabellen und parallel. Bei 7 Tabellen im KB-Bereich
  kein Nutzen; Plain-SQL ist lesbar und braucht zum Zurückspielen nur `psql`. Verworfen, ohne ADR kippbar.
- **PITR (WAL-Archivierung)** statt Dump: von Henning am 2026-11-02 verworfen (RPO 24 h reicht, keine Nutzer).
- **Dump direkt als Abschnitt in `backup.sh`** ohne eigenes Skript: spart eine Datei, ist aber nicht testbar (sudo, restic, Heartbeat fest
  verdrahtet). Verworfen.
- **Alles in einem Workflow** (Dump + automatische Probe): ~300 LoC, über dem Limit. Der einmalige Beweis in S4b-1 erfüllt „nachweislich
  zurückgespielt“ schon, S4b-2 macht ihn dauerhaft.

### Dependencies
- `docker exec` als `hem`: Gruppenmitgliedschaft `docker` im Probelauf prüfen, sonst `sudo -n docker` (wie `SUDO` im n8n-Skript).
- restic + `/etc/henemm/restic.env`, WireGuard zum Heimserver; `postgres:18.6` lokal vorhanden.
- Abstimmung: Kommentar an henemm-infra#336 vor dem PR (wie S4a).

### Open Questions
- keine an den PO (Format, Schnitt und Probe sind technische Entscheidungen; PITR ist entschieden).
