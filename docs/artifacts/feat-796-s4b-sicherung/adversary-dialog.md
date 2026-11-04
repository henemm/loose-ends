# Adversary Dialog — feat-796-s4b-sicherung
Spec: docs/specs/feat-796-schnitt-4b1-sicherung.md
Datum: 2026-11-04 09:56

## Checkliste
- [x] **AC-1:** Vorher (RED): `pytest tests/test_backup_loose_ends.py` im Infra-Repo ist rot, weil `scripts/backup-loose-ends-snapshot.sh` fehlt; und `restic ls latest --tag offsite` (oder gleichwertig über `restic snapshots` und `restic ls`) zeigt im jüngsten Off-Site-Snapshot keine Datei `looseends.sql`. Beleg: `ac1-vorher.txt`.
- [x] **AC-2:** Erfolgsfall: Das Skript schreibt mit der `docker`-Attrappe und im echten Lauf `OUT_DIR/looseends.sql` als Plain-SQL (unkomprimiert, Textdatei, Endmarke `-- PostgreSQL database dump complete` unter den letzten fünf Zeilen, im echten Lauf gefolgt von `\unrestrict …`); `OUT_DIR` hat Modus 700, die Datei Modus 600 (`stat -c '%a %n'`); Exit 0; kein `.tmp`-Rest. Beleg: `ac2-erfolg.txt` (pytest-Ausgabe und `stat`/`file`-Ausgabe des echten Laufs).
- [x] **AC-3:** Fehlerfälle: Bei abgeschnittenem Dump (Endmarke fehlt), fehlender Tabelle (`CREATE TABLE` im Dump weniger als Tabellen im Schema `public`), `schema_migrations` ohne Datenzeile und gescheitertem `docker exec` endet das Skript mit Exit ≠ 0 und einer Meldung auf stderr, hinterlässt keine `looseends.sql` (keine halbe, kein `.tmp`-Rest) und lässt eine bereits vorhandene ältere `looseends.sql` unverändert (gleiche Prüfsumme). Beleg: `ac3-fehlerfaelle.txt` (pytest-Ausgabe, je Fall ein Test).
- [x] **AC-4:** Einbindung: In `scripts/backup.sh` steht der Aufruf des Skripts vor `restic backup`, der Dump-Ordner steht im `restic backup`-Aufruf, der Abschnitt liegt vor dem Betterstack-Heartbeat, und ein Fehler bricht mit „Heartbeat NICHT gepingt“ ab wie die anderen Abschnitte; die Aufbewahrung (30 Tage) und alle übrigen Abschnitte sind im Diff unverändert. Belegt durch die Textprüfungen in pytest und den Diff von `backup.sh` (Zusatz nur ≈ 15 Zeilen). Beleg: `ac4-einbindung.txt`.
- [x] **AC-5:** Statik: `bash -n` für beide Skripte ohne Befund, `shellcheck` ohne Befund (falls auf dem Server oder lokal vorhanden, sonst im Beleg benannt), die gesamte Suite `pytest tests/` des Infra-Repos grün (alte Tests unberührt), jede Funktion ≤ 50 Zeilen. Beleg: `ac5-statik.txt`.
- [x] **AC-6:** Echter Lauf auf `rennwienix`, außerhalb von 02:45 bis 03:30: Skript schreibt den Dump aus dem laufenden Container `loose-ends-db`, `restic backup` mit dem Ordner läuft durch, und der jüngste Snapshot mit Tag `offsite` (der eben mit `--tag offsite --tag manual` geschriebene) enthält `/home/hem/backups/loose-ends/looseends.sql` (`restic ls`); vor dem Lauf `free -m` und `df -h /` im Beleg. Beleg: `ac6-lauf.txt`.
- [x] **AC-7:** Rückspielbeweis: Der Dump aus dem Off-Site-Snapshot aus AC-6 (nicht die lokale Datei) wird in einem Wegwerf-Container `postgres:18.6` (`--network none`, `--memory 256m`, `--rm`, ohne Volume, `POSTGRES_USER`/`POSTGRES_DB` = `looseends`, Befehle wie im Abschnitt „Einmaliger Rückspielbeweis“ Schritt 4) mit `sudo -n docker exec -i … psql -v ON_ERROR_STOP=1 -U looseends -d looseends` in eine leere Datenbank zurückgespielt, Exit 0 ohne Fehlermeldung; die sortierte Tabellenliste des Schemas `public` und alle Zeilen von `schema_migrations` sind gleich denen der Live-Datenbank (`diff` leer). Beleg: `ac7-rueckspiel.txt` (Befehle, Ausgaben beider Seiten, `diff`).
- [x] **AC-8:** Aufgeräumt und unberührt: Nach dem Beweis ist der Wegwerf-Container weg (`sudo -n docker ps -a` zeigt `le-restore-probe` nicht), der Temp-Ordner mit dem geholten Dump ist weg, `StartedAt` aller Container (`sudo -n docker ps -a --format '{{.Names}}'`, je Name `sudo -n docker inspect -f '{{.State.StartedAt}}'`) ist vor und nach dem Lauf gleich, die Live-Datenbank hat unverändert 0 Zeilen in den sechs Nutzertabellen und 2 in `schema_migrations`, kein Neustart von Docker, nginx oder einem fremden Dienst, kein Reboot. Beleg: `ac8-aufgeraeumt.txt`.
- [x] **AC-9:** Nachtlauf (Heartbeat): Der reguläre Lauf von 03:00 nach dem Merge läuft mit dem neuen Abschnitt durch und pingt den Betterstack-Heartbeat weiterhin; belegt durch den Ausschnitt aus `/home/hem/backups/backup.log` mit den Zeilen des Abschnitts für Loose Ends und der Heartbeat-Zeile dieses Laufs (Datum des Folgetags). Bleibt der Heartbeat aus oder fehlt der Abschnitt, ist das ein Befund, der vor dem Abschluss behoben wird, und der Beleg nennt ihn. Beleg: `ac9-nachtlauf.txt`.
- [x] **AC-10:** Doku: `docs/backup-offsite.md` enthält die Zeile zu Loose Ends mit dem Rückspielbefehl `psql -v ON_ERROR_STOP=1 -U looseends -d looseends < looseends.sql` und dem Hinweis, dass die Rolle `looseends` vorher existieren muss; `CLAUDE.md` im Loose-Ends-Repo nennt in der Betriebszeile die Sicherung; kein Platzhalter im Text. Beleg: `ac10-doku.txt` (beide Diffs).
- [x] **AC-11:** Dateiliste: Der Pull Request im Infra-Repo enthält genau `scripts/backup-loose-ends-snapshot.sh`, `scripts/backup.sh`, `tests/test_backup_loose_ends.py` und `docs/backup-offsite.md`; der Diff im Loose-Ends-Repo enthält nur `CLAUDE.md` und Dateien unter `docs/` (Specs, Context, Artifacts, Briefings); `server/`, `project.yml`, `.github/` und jede Swift-Datei bleiben unberührt. Beleg: `ac11-dateiliste.txt` (beide Diffstat-Ausgaben).
- [x] **AC-12:** Abstimmung: Der Kommentar an `henemm/henemm-infra` Issue #336 wurde vor dem Öffnen des Infra-PR geschrieben (Zeitstempel des Kommentars liegt vor dem des PR). Der Kommentar ist eine Benachrichtigung; auf eine Antwort wird nicht gewartet (wie in S4a). Beleg: `ac12-abstimmung.txt` (Links und Zeitstempel).

## Dialog

### Runde 1
**Adversary:**
Eigener Lauf auf rennwienix: `pytest tests/test_backup_loose_ends.py -v` = 13 passed, Gesamtsuite `pytest tests/` = 412 passed in 53.71s (Ausgabe: `adversary-test-output.txt`). Live-Skript (sha256 2aded080...) entspricht dem PR-Diff #383 (gemergt 08:22:05Z, vier Dateien). `bash -n` beider Skripte ok.
Angriffe auf die Beleglage, je Punkt:
- AC-1: ac1-vorher.txt zeigt 13 failed ("Skript fehlt"), `restic ls f458ab48 | grep -c looseends` = 0, Gegenprobe n8n = 3. Test `run()` prueft vorab `SNAPSHOT.is_file()`, die Fehlerfaelle sind also nicht grundlos gruen.
- AC-2/AC-3: eigene Randfall-Probe mit Docker-Attrappe (/tmp, danach geloescht): Baseline rc=0 nur `looseends.sql`; leerer Dump bei Exit 0 -> rc=1; Endmarke nur am Anfang (abgeschnitten) -> rc=1; Migrationen-Kopf fehlt -> rc=1; Migrationen leer, aber andere COPY-Zeilen -> rc=1; Tabellenzahl leer -> rc=1; Ausgabeordner ist eine Datei -> rc=1 mit mkdir-Meldung; vorhandenes `.tmp` -> wird ersetzt, rc=0, kein Rest; psql-Ausgabe mit CR -> bereinigt, rc=0. Nirgends bleibt eine halbe Datei oder ein `.tmp`-Rest.
- AC-4: Live `backup.sh`: Zeile 198-201 Aufruf mit `if !`/`exit 1` und "Heartbeat NICHT gepingt", Zeile 206-207 restic mit `$LE_SNAPSHOT_DIR`, Zeile 251 `curl` ist die letzte Zeile (`wc -l` = 251, `tail` bestaetigt), Zeile 2 `set -e`. Diff +10/-1, das -1 ist nur die restic-Zeile.
- AC-5: shellcheck lokal belegt (neues Skript clean, backup.sh dieselben Altbefunde wie vorher). Funktionen: nur `fail()` (4 Zeilen).
- AC-6/AC-7: Snapshot 67bcf30a, sha256 des restic-Restores gleich der lokalen Datei, Container `--network none`, Memory = MemorySwap = 268435456, AutoRemove=true, psql ON_ERROR_STOP Exit 0, stderr 0 Bytes, `diff` Tabellenliste und schema_migrations leer. Mounts=1 ist das anonyme Image-Volume, in ac8 als entfernt belegt.
- AC-8: StartedAt vorher=nachher fuer alle 9 Container, uptime gleich, 0/2 Zeilen unveraendert, Probe-Dateien entfernt.
- AC-9: eigene Pruefung: `restic snapshots e6eb86d0` zeigt `/home/hem/backups/loose-ends` unter den Pfaden, `restic ls e6eb86d0` enthaelt `/home/hem/backups/loose-ends/looseends.sql`; Log Zeile 253 "Loose-Ends-Dump ok (7 Tabellen, 2 Migrationen, 12K)" genau einmal; lokal 700/600. Die Vorziehung ist auf Hennings ausdruecklichen Wunsch erfolgt und in der Belegdatei benannt. Substanz getragen (Abschnitt im echten backup.sh-Lauf, rc=0, Heartbeat-Befehl als letzte Zeile erreicht). Schwaeche: der Heartbeat schreibt keine Logzeile, und `curl -s -o /dev/null` liefert Exit 0 auch bei HTTP-4xx/5xx; der Ping ist nur indirekt belegt (F002).
- AC-10/11/12: backup-offsite.md Zeile 52-66 mit Befehl und Rollenhinweis; CLAUDE.md Zeile 472 nennt Sicherung und Rueckspielbeweis; PR hat genau vier Dateien; Kommentar #336 08:14:45Z liegt 24 s vor PR 08:15:09Z.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: henemm-infra/scripts/backup-loose-ends-snapshot.sh:53
  Description: Readiness (b) zaehlt `grep -c '^CREATE TABLE '` gegen die Tabellen des Schemas public. `CREATE UNLOGGED TABLE`, Tabellen in anderen Schemas oder eine Datenzeile, die mit "CREATE TABLE " beginnt, verschieben die Zahl. Probe: UNLOGGED -> "1 CREATE TABLE im Dump, 2 live" rc=1; zusaetzliche Tabelle x.extra -> "3 vs 2" rc=1; Datenzeile -> "3 vs 2" rc=1. Alle drei Dumps sind gueltig.
  Spec requirement: AC-3 und Known Limitations — Readiness "streng, aber nicht ueberempfindlich"
  Conflict: Ein kuenftiges Migrationsskript mit UNLOGGED oder eigenem Schema laesst die Sicherung dauerhaft scheitern und haelt den gemeinsamen Heartbeat fuer Mail, n8n, Gregor und Frieda an (Fehlalarm, fail-closed, kein Datenverlust). Heute sind alle 7 Relationen `r`/persistent in public, 7 = 7.
  Remediation: `grep -cE '^CREATE (UNLOGGED )?TABLE public\.'` oder Live-Zaehlung ueber alle Nutzerschemas; Hinweis an kuenftige Migrationen. Nicht blockierend.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: henemm-infra/scripts/backup.sh:251
  Description: Der Heartbeat ist die letzte Zeile (`curl -s -o /dev/null ...`), schreibt keine Logzeile und liefert Exit 0 auch bei HTTP-Fehlern. AC-9 verlangt "die Heartbeat-Zeile dieses Laufs"; der Beleg schliesst aus rc=0.
  Spec requirement: AC-9 — Nachtlauf pingt den Heartbeat weiterhin, Ausschnitt mit Heartbeat-Zeile, Lauf von 03:00
  Conflict: Formal weicht der Beleg ab (vorgezogener Lauf statt 03:00, keine Heartbeat-Zeile). Die Abweichung ist offen benannt und vom PO verlangt; auch der Lauf von 03:00 vorher hat keine solche Zeile. Die Substanz (Abschnitt laeuft, Heartbeat-Befehl erreicht) ist belegt. Der Cron-Lauf 2026-11-05 03:00 (minimaler Cron-Pfad) bleibt die einzige echte Bestaetigung der Umgebung.
  Remediation: Am 2026-11-05 nach 03:00 `grep Loose-Ends-Dump /home/hem/backups/backup.log` und Betterstack-Status ansehen. Nicht blockierend.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: henemm-infra/scripts/backup-loose-ends-snapshot.sh:32
  Description: Der EXIT-Trap raeumt `looseends.sql.tmp` bei Fehlern auf, nicht bei SIGKILL oder Stromausfall. Ein Rest laege im gesicherten Ordner; Probe stale_tmp zeigt, dass der naechste Lauf ihn entfernt (Zeile 38 `rm -f`).
  Spec requirement: AC-3 — kein `.tmp`-Rest
  Conflict: Nur im Absturzfall, folgenlos und selbstheilend.
  Remediation: keine noetig.

Confirmation:
  AC: AC-1
  Code reference: henemm-infra/tests/test_backup_loose_ends.py:111
  Evidence: RED-Beleg 13 failed ohne Skript; restic ls des Vortags-Snapshots ohne looseends.sql, Gegenprobe n8n sichtbar.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: henemm-infra/scripts/backup-loose-ends-snapshot.sh:34
  Evidence: `umask 077`, `chmod 700`, `chmod 600 "$TMP"` (Zeile 63), `mv -f` (Zeile 64); echter Lauf stat 700/600, Endmarke mit `\unrestrict`, kein gzip-Magic.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: henemm-infra/scripts/backup-loose-ends-snapshot.sh:39
  Evidence: `pg_dump ... > "$TMP" || fail`, Endmarke Zeile 44, Tabellenzahl Zeile 53, Migrationen Zeile 57; 8 parametrisierte Tests und 13 eigene Randproben, keine Datei und keine Aenderung der aelteren bei Fehler.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: henemm-infra/scripts/backup.sh:199
  Evidence: Aufruf vor restic (206), Ordner im Aufruf (207), Abbruch mit "Heartbeat NICHT gepingt" (200), Heartbeat Zeile 251 letzter Befehl unter `set -e`.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: henemm-infra/tests/test_backup_loose_ends.py:98
  Evidence: 13 passed, Gesamtsuite 412 passed (adversary-test-output.txt); bash -n ok; shellcheck ohne neuen Befund.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: henemm-infra/scripts/backup.sh:206
  Evidence: Snapshot e6eb86d0 enthaelt looseends.sql (selbst per restic ls geprueft), Log Zeile "Loose-Ends-Dump ok", rc=0, Heartbeat Zeile 251 letzte Zeile; Abweichung (vorgezogen) vom PO verlangt.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: CLAUDE.md:472
  Evidence: Betriebszeile nennt nightly dump, local keeps latest, off-site history, restore proven 2026-11-04; docs/backup-offsite.md:65 hat den psql-Befehl, Rollenhinweis davor, keine Platzhalter.
  Status: CONFIRMED
**Implementierer:**
Nicht beteiligt (Kontextisolation); Belege ac1 bis ac12 unabhaengig nachgeprueft.

### Runde 2
**Adversary:**
Zweite Runde, gezielt gegen die genannten Schwachstellen:
- Partitionierte/unlogged Tabellen: siehe F001. Live-Abfrage `pg_class`: 7 Relationen, alle `relkind r`, persistent, nur Schema public. Zaehlung heute korrekt (7 = 7). Partitionen waeren BASE TABLE und im Dump eigene CREATE TABLE, passen.
- awk-Regex (c): echter Lauf lieferte "2 Migrationen" gegen die echte COPY-Kopfzeile; Probe mit drei Spalten rc=0; fehlender Kopf und leere Tabelle -> rc=1. Eine Datenzeile `\.` kann in COPY-Daten nicht vorkommen (maskiert).
- psql-stdout-Leerzeichen: `LIVE="${LIVE//[[:space:]]/}"`; Probe "2\r" rc=0, leere Antwort -> rc=1 mit Meldung.
- trap und `set -e`: Fehler in der Umleitung (Ordner ist Datei) endet per set -e, Exit 1, nichts liegt; Fehler in `pg_dump > "$TMP"` geht durch `|| fail`. Platte voll: docker exec liefert Exit != 0, zusaetzlich faengt die Endmarke ab.
- Modus 600 bei umask: umask 077 vor jeder Erzeugung, danach explizites chmod; vorhandener Ordner 755 wird 700 (test_vorhandener_ordner_bekommt_700).
- backup.sh-Abbruch vor restic und Heartbeat: Abschnitt Zeile 198-201 vor 206 und 251; `if !` plus `exit 1`, `set -e` aktiv. `DOCKER` und `CONTAINER` kommen in backup.sh nicht vor (grep leer), kein Ueberschreiben der Voreinstellung. `hem` hat `(ALL) NOPASSWD: ALL`, `sudo -n docker` geht unter cron.
- Probecontainer: Network=none, Memory=MemorySwap=268435456 (256 MB hart), AutoRemove=true; kein verwaistes Volume.
- StartedAt vollstaendig: alle 9 Container, `diff` leer; uptime, docker.service (2026-10-16) und nginx.service (2026-10-28) unveraendert; Live-DB 0/0/0/0/0/0/2 vorher=nachher.
- AC-12: Kommentar-Zeitstempel 08:14:45Z gegen PR 08:15:09Z, per `gh pr view` in ac12 belegt und mit PR-JSON (createdAt 08:15:09Z) uebereinstimmend.
- AC-11: PR-Dateiliste per `gh pr view 383 --json files` exakt vier Dateien.
Confirmation:
  AC: AC-6
  Code reference: henemm-infra/scripts/backup-loose-ends-snapshot.sh:39
  Evidence: Echter Lauf 08:28Z, free/df vorab im Beleg, Snapshot 67bcf30a (offsite,manual) enthaelt looseends.sql; lokale Datei 700/600.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: henemm-infra/scripts/backup-loose-ends-snapshot.sh:64
  Evidence: Restore aus dem Off-Site-Snapshot (sha256 gleich), Container none/256m/AutoRemove, psql ON_ERROR_STOP Exit 0 ohne stderr, beide diff leer.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: henemm-infra/scripts/backup.sh:206
  Evidence: StartedAt aller 9 Container, uptime, docker/nginx unveraendert; Probe-Container, Temp-Ordner, Volume weg; Live-DB 0/2 unveraendert.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: henemm-infra/docs/backup-offsite.md:52
  Evidence: PR #383 enthaelt genau die vier Dateien; Loose-Ends-Diff nur CLAUDE.md und docs/.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: henemm-infra/tests/test_backup_loose_ends.py:182
  Evidence: Kommentar 08:14:45Z, PR 08:15:09Z (gh pr view createdAt), 24 s davor.
  Status: CONFIRMED

Ergebnis Runde 2: kein weiterer Befund ueber F001 bis F003 hinaus; keiner blockiert.
**Implementierer:**
Nicht beteiligt (Kontextisolation); Belege ac1 bis ac12 unabhaengig nachgeprueft.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Tests: 13 passed (Feature), 412 passed (Gesamtsuite), 0 failed, 0 uebersprungen
Edge cases: F001 (MEDIUM, Fehlalarm bei UNLOGGED oder Fremdschema, fail-closed), F002 (LOW), F003 (LOW), keiner blockierend
Regressions: keine
Checklist: 12/12 proven

## Geprüfte Dateien

- sha256:f812b83b282edefeedf2e9d37fe89cd968ab12fc58c600146327c91dc73f8a49  CLAUDE.md

## Prüfbasis

- base: e4ec723847d394b7c8099a1aa234cffa81a283f5
- blob:948db21e87fe875bc83533761c3a0857c7e86642  CLAUDE.md
