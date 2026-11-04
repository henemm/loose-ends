---
entity_id: feat-796-schnitt-4b1-sicherung
type: feature
created: 2026-11-04
updated: 2026-11-04
status: draft
workflow: feat-796-s4b-sicherung
---

# Spec: Nächtliche Sicherung der Datenbank und einmaliger Rückspielbeweis, Schnitt S4b-1 (#796, Dienst auf Hetzner)

## Approval

- [ ] Approved

## GitHub Issue

#796 (Epic #612). Schnitt S4b-1; das Issue bleibt offen (`Refs #796`, nie `Closes #796`), es schließt erst nach S4b-2.
Analyse: `docs/context/feat-796-s4b-sicherung.md` (Abschnitt „Analysis“), Vorgänger: S4a (PR #819, Spec `docs/specs/feat-796-schnitt-4a-betrieb.md`).
Grundlage der Zuständigkeit: Plan der Instanz `infra` in `henemm/henemm-infra` Issue #336. Entscheidung „nächtlicher `pg_dump` statt Wiederherstellung auf einen Zeitpunkt“: Henning, 2026-11-02 (`docs/context/feat-796-dienst-hetzner.md`).
Nicht Teil dieser Spec: die wöchentliche automatische Rückspielprobe (S4b-2, eigener Workflow, eigene Teil-Spec), Öffnen von `/mcp` und Anmelderouten (#615, #621), GHCR und Automatik (#625).

## Purpose

Seit S4a läuft die Datenbank des Dienstes (`loose-ends-db`, `postgres:18.6`) auf `rennwienix`, wird aber von keiner Sicherung erfasst. Die Definition of Done von #796 verlangt, dass sie jede Nacht mitgesichert wird (lokal und off-site) und dass eine Sicherung nachweislich in eine leere Datenbank zurückgespielt wurde. Dieser Schnitt liefert beides in einer Form, die in die Limits passt:

1. **Nächtlicher Dump:** ein eigenes Skript im Muster von `backup-n8n-snapshot.sh` schreibt per `docker exec … pg_dump` einen Plain-SQL-Dump, prüft ihn (Readiness) und legt ihn unkomprimiert in `/home/hem/backups/loose-ends/looseends.sql` ab; `backup.sh` ruft es vor `restic backup` auf und nimmt den Ordner in den restic-Aufruf auf. Lokal liegt wie beim n8n-Schnappschuss nur der jüngste Stand (jede Nacht ersetzt); der Verlauf liegt in den restic-Snapshots.
2. **Einmaliger Rückspielbeweis:** nach dem Merge wird der Dump aus dem jüngsten Off-Site-Snapshot geholt und in einem Wegwerf-Container in eine leere Datenbank zurückgespielt; Tabellenliste und Inhalt von `schema_migrations` werden gegen live verglichen. Die dauerhafte, automatische Probe ist S4b-2.

Der Server ist geteilt (Mail, n8n, Gregor, Frieda), der Speicher knapp. Es gelten die Grenzen aus Hennings Freigabe vom 2026-11-03: kein Reboot, kein Neustart fremder Dienste oder des Docker-Daemons.

**Regeln vor Modell:** Shell, `pg_dump`, `restic` und pytest; ein Sprachmodell ist nicht beteiligt, es gibt keine Sprachaufgabe. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Weg B ist durch ADR-21 entschieden, die Wahl „nächtlicher Dump statt Wiederherstellung auf einen Zeitpunkt“ hat Henning am 2026-11-02 getroffen. Dieser Schnitt setzt sie nach dem Muster der bestehenden Sicherungen um; Dump-Format und Probeweg stehen unter „Alternativen“ und lassen sich später ändern.

## Source

**Files (Repo `henemm/henemm-infra`, privat):** `scripts/backup-loose-ends-snapshot.sh`, `scripts/backup.sh`, `tests/test_backup_loose_ends.py`, `docs/backup-offsite.md`
**Files (Repo Loose Ends):** `CLAUDE.md`, `docs/artifacts/feat-796-s4b-sicherung/`
**Identifier:** Container `loose-ends-db`, Datenbank und Nutzer `looseends`, Dump-Datei `looseends.sql`

### Abweichung von der S4a-Spec (offen benannt)

Die S4a-Spec (Abschnitt „Nicht in diesem Schnitt“) nannte `pg_dump -Fc`, `pg_restore --list` als Readiness und einen Zeilenzahlvergleich je Tabelle. Nach der Analyse vom 2026-11-04 gilt stattdessen:

- **Plain-SQL, unkomprimiert** statt Custom-Format. Grund: `pg_dump -Fc` komprimiert standardmäßig, komprimierte Dumps verhindern restics Deduplizierung (Messung #228 im Infra-Repo; Quellen: https://forum.restic.net/t/backing-up-database-large-snapshot-size/4352, https://simplebackups.com/blog/postgresql-backup-formats). Plain-SQL wird mit `psql` zurückgespielt.
- **Struktur und `schema_migrations`** statt Zeilenzahlvergleich. Grund: Die Datenbank hat am 2026-11-04 in allen sechs Tabellen 0 Zeilen (`accounts`, `apple_tokens`, `order_results`, `orders`, `sessions`, `transcripts`), nur `schema_migrations` hat 2 Zeilen, und kein Nutzer ist angemeldet. Ein Zählvergleich von Nullen beweist nichts. Der Vergleich der Tabellenliste und des Inhalts von `schema_migrations` beweist, dass Struktur und Migrationsstand zurückkommen. Sobald Nutzerzeilen existieren, ergänzt S4b-2 den Zeilenvergleich.

### `scripts/backup-loose-ends-snapshot.sh` (CREATE)

Nach dem Muster `scripts/backup-n8n-snapshot.sh`: `set -euo pipefail`, über Umgebungsvariablen testbar, Schreibweise wie `SUDO`/`OUT_DIR` im n8n-Skript: `DOCKER="${DOCKER-sudo -n docker}"` (Voreinstellung über `sudo -n`, weil `hem` NOPASSWD-sudo hat und so keine Mitgliedschaft in der Gruppe `docker` nötig ist; die Tests setzen `DOCKER` auf die Attrappe), `CONTAINER="${CONTAINER:-loose-ends-db}"`, `OUT_DIR="${OUT_DIR:-/home/hem/backups/loose-ends}"`. Ablauf:

1. `umask 077`, `mkdir -p "$OUT_DIR"`, danach `chmod 700 "$OUT_DIR"` (auch ein schon vorhandener Ordner bekommt 700, wie im n8n-Skript).
2. `$DOCKER exec "$CONTAINER" pg_dump -U looseends -d looseends` (ohne `-F`, also Plain-SQL) ohne Komprimierung in `OUT_DIR/looseends.sql.tmp` schreiben.
3. Readiness, alles muss stimmen: (a) die Zeile `-- PostgreSQL database dump complete` steht unter den letzten fünf Zeilen des Dumps (nicht in der letzten: `pg_dump` 18.6 schreibt danach `--`, eine Leerzeile und `\unrestrict <Schlüssel>`; nachgestellt vom Validator am 2026-11-04 mit einer lokalen Instanz PostgreSQL 18.6; `\restrict`/`\unrestrict` sind seit 17.6/18 Teil jedes Plain-Dumps und brauchen zum Zurückspielen `psql` ≥ 17.6, das `postgres:18.6` mitbringt); (b) die Zahl der `CREATE TABLE`-Anweisungen im Dump ist gleich der Zahl der Tabellen im Schema `public` der laufenden Datenbank (`$DOCKER exec "$CONTAINER" psql -U looseends -d looseends -tA -c "select count(*) from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE'"`); (c) der Dump enthält die Tabelle `schema_migrations` mit mindestens einer Datenzeile (Block `COPY public.schema_migrations … FROM stdin;` mit mindestens einer Zeile vor `\.`).
4. Erst bei bestandener Prüfung: `chmod 600`, `mv` über die fertige Datei `OUT_DIR/looseends.sql`. Bei jedem Fehler (auch wenn `docker exec` scheitert): Meldung auf stderr, die `.tmp`-Datei entfernen, Exit ≠ 0. Eine halbe Datei bleibt nie liegen und ersetzt nie eine ältere gute.

Jede Funktion ≤ 50 Zeilen.

### `scripts/backup.sh` (MODIFY)

Neuer Abschnitt mit Kommentarblock (Anlass, Ticket #796), direkt nach den Zeilen 192–193 (n8n) und vor `restic backup`: `LE_SNAPSHOT_DIR="${BACKUP_DIR}/loose-ends"` (also `/home/hem/backups/loose-ends`) und `OUT_DIR="$LE_SNAPSHOT_DIR" bash /home/hem/henemm-infra/scripts/backup-loose-ends-snapshot.sh` (`DOCKER` bleibt auf der Voreinstellung `sudo -n docker`); schlägt er fehl, bricht `backup.sh` mit derselben Meldung „Heartbeat NICHT gepingt“ ab wie die übrigen Abschnitte. `"$LE_SNAPSHOT_DIR"` steht im bestehenden Aufruf `restic backup --tag offsite --tag daily --host henemm-hetzner …` direkt nach `"$N8N_SNAPSHOT_DIR"`; Tags und Host bleiben. Die bestehende Aufbewahrung der tar-Archive (`find -mtime +30 -delete`) bleibt unverändert; für den Dump braucht es keine, er wird jede Nacht ersetzt. Das Secret `loose-ends/secrets/server.env` wird von der bestehenden Secret-Sammlung bereits erfasst (Tiefe 3 unter `/home/hem/henemm-infra`, geprüft in der Analyse) und braucht keine Änderung.

### `tests/test_backup_loose_ends.py` (CREATE)

pytest nach dem Muster `tests/test_backup_n8n_snapshot.py`, mit einer Attrappe für `docker` (kleines Shell-Skript im Temp-Ordner, über `DOCKER` übergeben), die je nach Testfall einen Wegwerf-Dump oder einen Fehler liefert. Der Wegwerf-Dump hat den echten Schluss eines 18.6-Dumps (Endmarke, `--`, Leerzeile, `\unrestrict <Schlüssel>`), damit die Readiness gegen die echte Form geprüft wird. Fälle: Erfolg (mit `\unrestrict`-Schluss); abgeschnittener Dump (Endmarke fehlt); fehlende Tabelle (Zahl `CREATE TABLE` kleiner als Live-Zahl); `schema_migrations` ohne Datenzeile; `docker exec` scheitert. Jeweils geprüft: Exit-Code, Existenz und Modus der Datei, kein `.tmp`-Rest, eine vorhandene ältere Datei bleibt bei Fehler unverändert. Textprüfungen an `backup.sh`: der Aufruf steht vor `restic backup`, der Ordner steht im restic-Aufruf, der Abschnitt steht vor dem Heartbeat und bricht bei Fehler ab.

### `docs/backup-offsite.md` (MODIFY)

Eine Zeile (mit kurzem Satz zum Zurückspielen) zu Loose Ends: was gesichert wird (`looseends.sql`, Plain-SQL, nächtlich, 600), wo (lokal `/home/hem/backups/loose-ends/looseends.sql`, nur der jüngste Stand; off-site in jedem restic-Snapshot mit Tag `offsite`), Zurückspielen in eine leere Datenbank, in der die Rolle `looseends` existiert (der Dump enthält `ALTER TABLE … OWNER TO looseends`; ein neuer Container `postgres:18.6` mit `POSTGRES_USER=looseends` und `POSTGRES_DB=looseends` legt beides an), mit `psql -v ON_ERROR_STOP=1 -U looseends -d looseends < looseends.sql`. Hinweis, dass der Dump verschlüsselte Apple-Token und Sitzungs-Hashes enthalten wird und deshalb nur 600 liegt.

### Loose-Ends-Repo

- `CLAUDE.md`: die Betriebszeile („Betrieb (#796 S4a)“) um die Sicherung ergänzen: nächtlicher Plain-SQL-Dump von `loose-ends-db` im Backup von `rennwienix` (lokal `/home/hem/backups/loose-ends/`, nur der jüngste Stand; Verlauf off-site über restic), Skript und Tests in `henemm-infra`, Rückspielbeweis vom Stand 2026-11-04; automatische Probe folgt mit S4b-2.
- Belege unter `docs/artifacts/feat-796-s4b-sicherung/` (Textdateien mit Befehl, Ausgabe und Uhrzeit, je AC eine Datei).

### Einmaliger Rückspielbeweis (nach dem Merge)

Nach dem Merge im Infra-Repo rollt der Auto-Deploy das Skript auf `rennwienix` aus. Der Probelauf läuft **außerhalb von 02:45 bis 03:30** (Deploy-Sperre und Backup-Zeit). Ablauf, jeder Schritt mit Ausgabe im Beleg:

1. Vorab `free -m` und `df -h /`; weniger als 600 MB verfügbarer Speicher oder weniger als 2 GB freie Platte: Abbruch, nichts gestartet.
2. Dump schreiben (das neue Skript mit `OUT_DIR=/home/hem/backups/loose-ends`), dann `restic backup --tag offsite --tag manual --host henemm-hetzner /home/hem/backups/loose-ends` mit `/etc/henemm/restic.env` gegen dasselbe Off-Site-Repository wie der Nachtlauf (ein zusätzlicher Snapshot, append-only; Tag `manual` statt `daily`, damit er vom Nachtlauf unterscheidbar bleibt; sonst keine Wirkung).
3. Dump aus dem jüngsten Off-Site-Snapshot holen: `restic snapshots --tag offsite --latest 1`, `restic restore` in einen Ordner aus `mktemp -d` (`umask 077`, `trap` räumt auf), Muster `scripts/restore-test-gregor.sh`.
4. Wegwerf-Container (alle Docker-Befehle des Probelaufs als `sudo -n docker`, wie die Voreinstellung im Skript): `sudo -n docker run -d --rm --name le-restore-probe --network none --memory 256m --memory-swap 256m -e POSTGRES_USER=looseends -e POSTGRES_DB=looseends -e POSTGRES_PASSWORD="$(openssl rand -hex 16)" postgres:18.6`, ohne Volume, ohne das Netz des Live-Stapels (das Image legt Rolle und Datenbank `looseends` an; ohne die Rolle bricht `psql` an `ALTER TABLE … OWNER TO looseends` ab, nachgestellt vom Validator). Bereitschaft: bis zu 60 s im Sekundentakt `sudo -n docker exec le-restore-probe pg_isready -U looseends -d looseends` und anschließend `sudo -n docker exec le-restore-probe psql -U looseends -d looseends -tAc 'select 1'` (das Image startet während der Initialisierung kurz einen Zwischenserver, der `pg_isready` schon grün meldet; erst wenn beide Befehle zweimal hintereinander im Abstand von 2 s gelingen, gilt der Container als bereit), sonst nach 60 s Abbruch mit Aufräumen. Zurückspielen: `sudo -n docker exec -i le-restore-probe psql -v ON_ERROR_STOP=1 -U looseends -d looseends < "$TMP/home/hem/backups/loose-ends/looseends.sql"`.
5. Vergleich gegen live, je Seite derselbe Befehl über `sudo -n docker exec <Container> psql -U looseends -d looseends -tA -c …`: sortierte Liste der Tabellen im Schema `public` (`select table_name from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE' order by 1`) und alle Zeilen von `schema_migrations` (`select * from schema_migrations order by 1`); `diff` beider Ausgaben ist leer.
6. `sudo -n docker stop le-restore-probe` (`--rm` entfernt ihn) und Temp-Ordner sofort entfernen, auch bei Fehler (`trap`).

Keine Probezeile in die Live-Datenbank; sie bleibt unverändert (0 Nutzerzeilen, `schema_migrations` 2 Zeilen vor und nach dem Lauf).

### Abstimmung mit `infra`

Die Instanz `infra` ist von hier nicht per SendMessage erreichbar. Weg wie in S4a: ein Kommentar an `henemm/henemm-infra` Issue #336 mit Schnitt, den vier Dateien, dem Eingriff in den gemeinsamen Heartbeat und dem Zeitpunkt des Probelaufs; **der Kommentar steht vor dem Infra-PR**.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| Container `loose-ends-db` (`postgres:18.6`, S4a) | bestehend; `pg_dump` 18.6 im Container, gleiche Version wie der Server |
| `scripts/backup.sh`, `scripts/backup-n8n-snapshot.sh`, `scripts/restore-test-gregor.sh` (Infra) | bestehend; Muster und Einhängepunkt |
| `restic`, `/etc/henemm/restic.env`, WireGuard zum Heimserver | bestehend; Off-Site-Ziel append-only |
| `sudo -n docker` als Nutzer `hem` | bestehend (NOPASSWD-sudo, wie `sudo -n` im n8n-Skript); Voreinstellung von `DOCKER` im Skript |
| Image `postgres:18.6` lokal vorhanden | bestehend; für den Wegwerf-Container |
| Betterstack-Heartbeat des Backups | bestehend, **gemeinsam** für alle Sicherungen |
| Auto-Deploy des Infra-Repos | bestehend; rollt das Skript aus |
| Hennings Freigabe für Schreibzugriff (2026-11-03, S4a und S4b) | erteilt; Grenzen: kein Reboot, kein Neustart fremder Dienste oder des Docker-Daemons |
| Instanz `infra`, henemm-infra#336 | Abstimmung per Kommentar und PR |

## Acceptance Criteria

Alle Belege entstehen aus echten Läufen (pytest lokal, Skript und Rückspielbeweis auf `rennwienix`) und liegen als Textdatei (Befehl, Ausgabe, Uhrzeit) unter `docs/artifacts/feat-796-s4b-sicherung/`. Zuerst der Nachweis „vorher“ (RED); erst danach wird gebaut.

- **AC-1:** Vorher (RED): `pytest tests/test_backup_loose_ends.py` im Infra-Repo ist rot, weil `scripts/backup-loose-ends-snapshot.sh` fehlt; und `restic ls latest --tag offsite` (oder gleichwertig über `restic snapshots` und `restic ls`) zeigt im jüngsten Off-Site-Snapshot keine Datei `looseends.sql`. Beleg: `ac1-vorher.txt`.
- **AC-2:** Erfolgsfall: Das Skript schreibt mit der `docker`-Attrappe und im echten Lauf `OUT_DIR/looseends.sql` als Plain-SQL (unkomprimiert, Textdatei, Endmarke `-- PostgreSQL database dump complete` unter den letzten fünf Zeilen, im echten Lauf gefolgt von `\unrestrict …`); `OUT_DIR` hat Modus 700, die Datei Modus 600 (`stat -c '%a %n'`); Exit 0; kein `.tmp`-Rest. Beleg: `ac2-erfolg.txt` (pytest-Ausgabe und `stat`/`file`-Ausgabe des echten Laufs).
- **AC-3:** Fehlerfälle: Bei abgeschnittenem Dump (Endmarke fehlt), fehlender Tabelle (`CREATE TABLE` im Dump weniger als Tabellen im Schema `public`), `schema_migrations` ohne Datenzeile und gescheitertem `docker exec` endet das Skript mit Exit ≠ 0 und einer Meldung auf stderr, hinterlässt keine `looseends.sql` (keine halbe, kein `.tmp`-Rest) und lässt eine bereits vorhandene ältere `looseends.sql` unverändert (gleiche Prüfsumme). Beleg: `ac3-fehlerfaelle.txt` (pytest-Ausgabe, je Fall ein Test).
- **AC-4:** Einbindung: In `scripts/backup.sh` steht der Aufruf des Skripts vor `restic backup`, der Dump-Ordner steht im `restic backup`-Aufruf, der Abschnitt liegt vor dem Betterstack-Heartbeat, und ein Fehler bricht mit „Heartbeat NICHT gepingt“ ab wie die anderen Abschnitte; die Aufbewahrung (30 Tage) und alle übrigen Abschnitte sind im Diff unverändert. Belegt durch die Textprüfungen in pytest und den Diff von `backup.sh` (Zusatz nur ≈ 15 Zeilen). Beleg: `ac4-einbindung.txt`.
- **AC-5:** Statik: `bash -n` für beide Skripte ohne Befund, `shellcheck` ohne Befund (falls auf dem Server oder lokal vorhanden, sonst im Beleg benannt), die gesamte Suite `pytest tests/` des Infra-Repos grün (alte Tests unberührt), jede Funktion ≤ 50 Zeilen. Beleg: `ac5-statik.txt`.
- **AC-6:** Echter Lauf auf `rennwienix`, außerhalb von 02:45 bis 03:30: Skript schreibt den Dump aus dem laufenden Container `loose-ends-db`, `restic backup` mit dem Ordner läuft durch, und der jüngste Snapshot mit Tag `offsite` (der eben mit `--tag offsite --tag manual` geschriebene) enthält `/home/hem/backups/loose-ends/looseends.sql` (`restic ls`); vor dem Lauf `free -m` und `df -h /` im Beleg. Beleg: `ac6-lauf.txt`.
- **AC-7:** Rückspielbeweis: Der Dump aus dem Off-Site-Snapshot aus AC-6 (nicht die lokale Datei) wird in einem Wegwerf-Container `postgres:18.6` (`--network none`, `--memory 256m`, `--rm`, ohne Volume, `POSTGRES_USER`/`POSTGRES_DB` = `looseends`, Befehle wie im Abschnitt „Einmaliger Rückspielbeweis“ Schritt 4) mit `sudo -n docker exec -i … psql -v ON_ERROR_STOP=1 -U looseends -d looseends` in eine leere Datenbank zurückgespielt, Exit 0 ohne Fehlermeldung; die sortierte Tabellenliste des Schemas `public` und alle Zeilen von `schema_migrations` sind gleich denen der Live-Datenbank (`diff` leer). Beleg: `ac7-rueckspiel.txt` (Befehle, Ausgaben beider Seiten, `diff`).
- **AC-8:** Aufgeräumt und unberührt: Nach dem Beweis ist der Wegwerf-Container weg (`sudo -n docker ps -a` zeigt `le-restore-probe` nicht), der Temp-Ordner mit dem geholten Dump ist weg, `StartedAt` aller Container (`sudo -n docker ps -a --format '{{.Names}}'`, je Name `sudo -n docker inspect -f '{{.State.StartedAt}}'`) ist vor und nach dem Lauf gleich, die Live-Datenbank hat unverändert 0 Zeilen in den sechs Nutzertabellen und 2 in `schema_migrations`, kein Neustart von Docker, nginx oder einem fremden Dienst, kein Reboot. Beleg: `ac8-aufgeraeumt.txt`.
- **AC-9:** Nachtlauf (Heartbeat): Der reguläre Lauf von 03:00 nach dem Merge läuft mit dem neuen Abschnitt durch und pingt den Betterstack-Heartbeat weiterhin; belegt durch den Ausschnitt aus `/home/hem/backups/backup.log` mit den Zeilen des Abschnitts für Loose Ends und der Heartbeat-Zeile dieses Laufs (Datum des Folgetags). Bleibt der Heartbeat aus oder fehlt der Abschnitt, ist das ein Befund, der vor dem Abschluss behoben wird, und der Beleg nennt ihn. Beleg: `ac9-nachtlauf.txt`.
- **AC-10:** Doku: `docs/backup-offsite.md` enthält die Zeile zu Loose Ends mit dem Rückspielbefehl `psql -v ON_ERROR_STOP=1 -U looseends -d looseends < looseends.sql` und dem Hinweis, dass die Rolle `looseends` vorher existieren muss; `CLAUDE.md` im Loose-Ends-Repo nennt in der Betriebszeile die Sicherung; kein Platzhalter im Text. Beleg: `ac10-doku.txt` (beide Diffs).
- **AC-11:** Dateiliste: Der Pull Request im Infra-Repo enthält genau `scripts/backup-loose-ends-snapshot.sh`, `scripts/backup.sh`, `tests/test_backup_loose_ends.py` und `docs/backup-offsite.md`; der Diff im Loose-Ends-Repo enthält nur `CLAUDE.md` und Dateien unter `docs/` (Specs, Context, Artifacts, Briefings); `server/`, `project.yml`, `.github/` und jede Swift-Datei bleiben unberührt. Beleg: `ac11-dateiliste.txt` (beide Diffstat-Ausgaben).
- **AC-12:** Abstimmung: Der Kommentar an `henemm/henemm-infra` Issue #336 wurde vor dem Öffnen des Infra-PR geschrieben (Zeitstempel des Kommentars liegt vor dem des PR). Der Kommentar ist eine Benachrichtigung; auf eine Antwort wird nicht gewartet (wie in S4a). Beleg: `ac12-abstimmung.txt` (Links und Zeitstempel).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/backup-loose-ends-snapshot.sh` (Infra) | CREATE | `docker exec … pg_dump`, Readiness, tmp → mv, Modus 700/600; ≈ +55 |
| `scripts/backup.sh` (Infra) | MODIFY | Abschnitt mit Kommentarblock, Aufruf vor restic, Ordner im restic-Aufruf, Abbruch ohne Heartbeat; ≈ +15 |
| `tests/test_backup_loose_ends.py` (Infra) | CREATE | pytest mit `docker`-Attrappe (Erfolg, vier Fehlerfälle, ältere Datei bleibt) und Textprüfungen an `backup.sh`; ≈ +130 |
| `docs/backup-offsite.md` (Infra) | MODIFY | Zeile Loose Ends, Zurückspielen; ≈ +6 |
| `CLAUDE.md` (Loose Ends) | MODIFY | Betriebszeile um die Sicherung ergänzen; ≈ +1 |
| `docs/artifacts/feat-796-s4b-sicherung/` (Loose Ends) | CREATE | Belege AC-1 bis AC-12 |

### Estimated Changes

- Dateien im Infra-Repo: 4 (Limit 4–5); im Loose-Ends-Repo eine geänderte Datei (`CLAUDE.md`). Spec, Context, Briefing und die Belegdateien unter `docs/artifacts/feat-796-s4b-sicherung/` (hier zwölf, je AC eine) sind Workflow-Nachweise, keine Code-Änderung, und zählen nicht gegen das Datei- und LoC-Limit (vergleiche S4a: „im Loose-Ends-Repo nur `CLAUDE.md` und `docs/`“).
- LoC: ≈ +207 (Skript ≈ 55, `backup.sh` ≈ 15, Tests ≈ 130, Doku ≈ 6, `CLAUDE.md` ≈ 1), unter 250. Grundlage der Testschätzung: `tests/test_backup_n8n_snapshot.py` hat für ein gleich gebautes Skript 87 Zeilen; hier kommen ein Readiness-Fall mehr und der Fall „ältere Datei bleibt“ dazu, also Tests ≈ 2,4× Skript, im Rahmen der Lehre aus #615 S2a (2–2,5×). Liegt der Stand nach RED über 250, wird vor GREEN gefragt. Jede Funktion ≤ 50 Zeilen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neue Migration, keine neuen Pakete, kein `generate`. Seiteneffekte außerhalb des Tickets: ein weiterer Abschnitt im gemeinsamen Backup (siehe Known Limitations), ein zusätzlicher restic-Snapshot und ein zusätzliches Archiv je Quelle durch den Probelauf (Platz, append-only), ein kurzzeitig laufender Wegwerf-Container (256 MB hart begrenzt).

## Test Plan

Der Dump-Pfad hat Logik (Readiness, Fehlerbehandlung, atomare Ablage), deshalb gibt es Tests; sie liegen im Infra-Repo, nicht im Loose-Ends-Repo. Swift und `server/` bleiben unberührt, ihre Suiten laufen unverändert.

- [ ] RED (AC-1): `tests/test_backup_loose_ends.py` zuerst schreiben und rot sehen (Skript fehlt); jüngsten Off-Site-Snapshot auf `looseends.sql` prüfen (keine Datei).
- [ ] GREEN (AC-2 bis AC-5): Skript und `backup.sh`-Abschnitt schreiben, bis die neuen Tests grün sind und die ganze Suite des Infra-Repos grün bleibt; `bash -n` und `shellcheck`.
- [ ] Abstimmung (AC-12): Kommentar an henemm-infra#336, danach Infra-PR mit den vier Dateien (AC-11).
- [ ] Nach dem Merge und Auto-Deploy: Probelauf außerhalb 02:45 bis 03:30 (AC-6), Rückspielbeweis (AC-7), Aufräumen und Unberührtheit (AC-8).
- [ ] Nächster Nachtlauf (AC-9): `backup.log` mit Abschnitt und Heartbeat.
- [ ] Doku und Dateiliste (AC-10, AC-11).
- [ ] Grenze: AC-6 bis AC-9 sind nur über SSH-Zugriff auf `rennwienix` belegbar. Ist er nicht möglich, sind diese ACs nicht belegt und das wird im Abschlussbericht so benannt, ohne Haken.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Frage | Gewählt | Alternative | Warum nicht |
|---|---|---|---|
| Dump-Format (Abweichung zur S4a-Spec) | Plain-SQL, unkomprimiert, Zurückspielen mit `psql` | `pg_dump -Fc` (komprimiert) bzw. `-Fc --compress=0`, `pg_restore --list` als Readiness | komprimierte Dumps verhindern die restic-Deduplizierung (Messung #228); `-Fc --compress=0` erlaubt zwar `pg_restore` einzelner Tabellen, bringt bei sieben Tabellen im KB-Bereich aber nichts, Plain-SQL ist lesbar und braucht nur `psql` |
| Rückspiel-Vergleich (Abweichung zur S4a-Spec) | Tabellenliste und Inhalt `schema_migrations` | Zeilenzahl je Tabelle | alle sechs Nutzertabellen haben 0 Zeilen, ein Vergleich von Nullen beweist nichts; kommt mit S4b-2, sobald es Nutzerzeilen gibt |
| Probedaten | keine Probezeile, Live-DB unberührt | Probezeile in die Live-Datenbank, dann Rückspielen und Vergleich | schreibt in die produktive Datenbank für einen Beweis; Struktur und Migrationsstand belegen den Weg ebenso |
| Sicherungsweg | Dump nächtlich | Wiederherstellung auf einen Zeitpunkt (WAL-Archivierung) | von Henning am 2026-11-02 verworfen: Wiederherstellungspunkt von 24 h reicht, keine Nutzer |
| Einbindung | eigenes Skript, von `backup.sh` aufgerufen | Dump direkt als Abschnitt in `backup.sh` | nicht testbar (sudo, restic und Heartbeat fest verdrahtet) |
| Schnitt | S4b-1 Dump und einmaliger Beweis, S4b-2 wöchentliche Probe | alles in einem Workflow | ≈ 300 LoC, über dem Limit (Lehre #615 S2a: Tests ≈ 2–2,5× Code); der einmalige Beweis erfüllt „nachweislich zurückgespielt“ schon |
| Fehler im Dump-Abschnitt | Abbruch ohne Heartbeat, wie alle Abschnitte | Fehler nur melden, Heartbeat trotzdem pingen | ein stiller Ausfall der Sicherung wäre schlimmer als ein Fehlalarm; Folge siehe Known Limitations |

## Nicht in diesem Schnitt / Folgeschnitte

- **S4b-2** (eigener Workflow, eigene Teil-Spec): `scripts/restore-test-loose-ends.sh` spielt wöchentlich (sonntags, am selben Heartbeat, Muster `restore-test-gregor.sh`) den jüngsten Off-Site-Dump in einen Wegwerf-Container zurück und vergleicht; `backup.sh` ruft es auf; ≈ +180 LoC. **#796 schließt erst danach**, deshalb in diesem Schnitt nur `Refs #796`, nie `Closes`.
- `README.md` des Infra-Repos nennt `backup.sh` noch „sonntags“ (der Cron läuft täglich): veraltet, aber nicht Teil dieses Schnitts.
- `/mcp` bleibt am Netzrand gesperrt bis #615 und #621; GHCR-Bau und Automatik: #625.

## Abnahme

- Stufe 1: `pytest tests/` im Infra-Repo grün (neue und alte Tests), `bash -n` und `shellcheck` für die Skripte.
- Stufe 2: echter Lauf auf `rennwienix`: AC-6 bis AC-9 mit den Belegen oben. Dazu der Beleg von `./scripts/sim.sh test-proof CaptureSmokeTests` für `phase8_complete`; er zeigt nur, dass die App auf dem Stand startet, ein Bedienablauf für die Sicherung existiert in der App nicht.
- Stufe 3: entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt, Belege unter `docs/artifacts/feat-796-s4b-sicherung/`
- [ ] Vorher-Nachweis (RED) abgelegt
- [ ] Kommentar an henemm-infra#336 vor dem Infra-PR, Infra-PR mit genau den vier Dateien aus AC-11 gemergt
- [ ] Rückspielbeweis aus dem Off-Site-Snapshot erbracht und aufgeräumt (AC-7, AC-8)
- [ ] Nachtlauf nach dem Merge pingt den Heartbeat weiterhin (AC-9)
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #796 kommentiert (Stand S4b-1, S4b-2 offen), Board-Karte aktuell; Issue bleibt offen

## Known Limitations

- **Gemeinsamer Heartbeat:** Der Betterstack-Heartbeat des Backups ist einer für alle Sicherungen (Gregor, Frieda, n8n, nun Loose Ends). Ein Fehler im neuen Abschnitt hält ihn für **alle** an; ein Fehlalarm aus Loose Ends sieht aus wie ein Ausfall des ganzen Backups. Das ist gewollt (ein stiller Ausfall wäre schlimmer), und die Readiness ist deshalb streng, aber nicht überempfindlich (nur Endmarke, Tabellenzahl, `schema_migrations`). Abgesichert durch AC-3 (Fehlerfälle getestet) und AC-9 (Nachtlauf pingt weiter).
- **Struktur statt Inhalt:** Solange keine Nutzerzeilen existieren, belegt der Rückspielbeweis Struktur und Migrationsstand, nicht Nutzerdaten. Der Zeilenvergleich folgt mit S4b-2.
- **Einmaliger Beweis:** Nach diesem Schnitt ist die Rückspielbarkeit nur zum Zeitpunkt des Beweises belegt; bis S4b-2 prüft nichts automatisch, ob spätere Dumps zurückspielbar bleiben (die Readiness im Skript fängt abgeschnittene und unvollständige Dumps).
- **Geheimnisse im Dump:** Künftig enthält der Dump verschlüsselte Apple-Token und Sitzungs-Hashes; Ablage 600, restic verschlüsselt. Rollenpasswörter sichert `pg_dump` nicht (gewollt); das Datenbankpasswort steht auch in `loose-ends/secrets/server.env`, das die Secret-Sammlung erfasst.
- **Platz und Speicher:** Der Probelauf erzeugt einen zusätzlichen restic-Snapshot und ein zusätzliches Archiv je Quelle; der Wegwerf-Container ist auf 256 MB hart begrenzt, weil der Speicher des geteilten Servers knapp ist.

## Changelog

- 2026-11-04: Initial spec created (Schnitt S4b-1)
- 2026-11-04: Nach Validierung: Ablageordner `/home/hem/backups/loose-ends` und restic-Aufruf (Tags, Host) aus `backup.sh` festgelegt, `DOCKER` mit Voreinstellung `sudo -n docker`, LoC-Schätzung auf ≈ 207 korrigiert (Tests ≈ 130), `StartedAt` über `docker ps -a`, lokale Aufbewahrung richtiggestellt (nur jüngster Stand)
- 2026-11-04: Nach Validierung Runde 2: Endmarke unter den letzten fünf Zeilen statt in der letzten (`pg_dump` 18.6 schreibt `\unrestrict` danach, nachgestellt), Test-Dump mit echtem Schluss; Wegwerf-Container mit `POSTGRES_USER`/`POSTGRES_DB` = `looseends` (ohne Rolle bricht `psql` ab, nachgestellt), `pg_isready`-Schleife und `docker exec -i` als vollständige Befehle; alle Docker-Befehle des Probelaufs über `sudo -n docker`; `chmod 700` auch für einen vorhandenen Ordner
- 2026-11-04: Nach Validierung Runde 3: Bereitschaft zusätzlich über `select 1` (Zwischenserver beim Initialisieren), Kommentar an #336 ohne Warten auf Antwort, Belegdateien ausdrücklich außerhalb des Dateilimits (wie S4a)
