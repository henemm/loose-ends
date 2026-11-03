# Adversary Dialog — feat-796-s2-betrieb
Spec: docs/specs/feat-796-schnitt-2-image-und-sperre.md
Datum: 2026-11-03 06:31

## Checkliste
- [x] **AC-1 (Fehler nachgestellt):** Der Paralleltest aus AC-2 wird zuerst gegen den unveränderten `migrate.ts` ausgeführt und schlägt dort fehl (mindestens ein Lauf wirft einen Fehler zu `schema_migrations` oder „already exists“, oder eine Migration steht doppelt). Beleg: RED-Lauf im Workflow-Artefakt (`docs/artifacts/feat-796-s2-betrieb/`) vor der Änderung, danach derselbe Test grün.
- [x] **AC-2:** Zwei bzw. drei `migrate`-Läufe gleichzeitig (`Promise.all`) gegen dasselbe leere Schema und einen Migrationsordner mit mindestens drei Migrationen: alle Läufe sind erfolgreich (keine Ablehnung); `schema_migrations` hat jede Migration genau einmal; die Vereinigung der Rückgabelisten ist genau die Menge aller Namen, und kein Name steht in zwei Rückgabelisten (keine Migration wird doppelt angewandt).
- [x] **AC-3:** Nach einem fehlschlagenden Lauf (eine Migration mit kaputtem SQL) ist die Sperre frei: ein weiterer Lauf mit repariertem Ordner kommt innerhalb von 5 Sekunden zum Ende (Zeitgrenze im Test), und `pg_try_advisory_lock(MIGRATE_LOCK_ID)` auf einer fremden Verbindung liefert danach `true` (Gegenprobe: freigeben mit `pg_advisory_unlock`). Ein vor dem Fehler schon angewandter Migrationsschritt bleibt eingetragen, der kaputte nicht.
- [x] **AC-4:** Fehler in Dateinamen, Lücke oder doppelte Nummer werden weiterhin abgelehnt, **bevor** die Datenbank berührt wird: Test mit einem Pool, dessen `connect` bei Aufruf wirft oder zählt, und einem Ordner mit Lücke; `connect` wurde nicht aufgerufen, die Ablehnung trägt die bisherige Meldung. Die bisherigen Tests in `migrate.test.ts` bleiben unverändert grün (Signatur, Rückgabewert, Reihenfolge, „erledigte werden nicht wiederholt“).
- [ ] **AC-5:** `docker build server` baut das Image. In der CI (Job `image`) startet der Container gegen den `postgres:18`-Dienst, `GET /health` liefert innerhalb von 60 Sekunden 200, der Body hat `status` „ok“, `db` „up“, `migrated` true. Beleg: CI-Lauf des PR.
- [ ] **AC-6:** Das Log des laufenden Containers enthält in jeder nichtleeren Zeile einen ISO-Zeitpunkt vorn und weder `postgres://` noch das Passwort; keine Aufgabentitel (es werden keine Aufgaben angelegt, das Log zeigt nur Ereigniszeilen wie `listening`, `migrated`). Beleg: CI-Lauf, Schritt „Log prüfen“.
- [ ] **AC-7:** `docker stop` (SIGTERM) beendet den Container mit Exit-Code 0 innerhalb von 20 Sekunden; das Log enthält `shutting down` und `stopped`. Beleg: CI-Lauf, Schritt „Beenden“.
- [ ] **AC-8:** Das Image läuft nicht als root (`docker run --entrypoint id loose-ends-server:ci -u` liefert nicht `0`) und enthält weder `test/` noch `scripts/` noch eine `.env*`-Datei. Beleg: CI-Lauf, Schritt „Image prüfen“.
- [ ] **AC-9:** `npm run typecheck` und `./server/scripts/test-local.sh` sind grün (alle bestehenden Tests plus die neuen); beide Jobs von `server.yml` (`test` und `image`) sind auf dem PR grün.
- [ ] **AC-10:** Die Dateiliste des PR enthält genau `server/src/migrate.ts`, `server/test/migrate.test.ts`, `server/Dockerfile`, `server/.dockerignore` und `.github/workflows/server.yml`, ausgenommen `docs/specs/`, `docs/context/`, `docs/artifacts/`, `docs/briefings/`. `server/src/main.ts`, `server/package.json`, `package-lock.json`, alle Migrationen, `project.yml` und jede Swift-Datei bleiben unberührt.


## Dialog

### Runde 1
**Adversary:**
Eigener Lauf `./server/scripts/test-local.sh`: typecheck + 124 Tests, 0 fail, 0 skipped (docs/artifacts/feat-796-s2-betrieb/adversary-test-output.txt). RED-Beleg test-red-output.txt: 3 fail vor der Änderung (die drei S3-Tests; AC-3 scheitert allerdings schon an der fehlenden Konstante MIGRATE_LOCK_ID, nicht am Verhalten; AC-2 scheitert am Verhalten).

Mutationsprobe (temporär, danach wiederhergestellt, migrate.ts identisch zum Stand vorher): `pg_advisory_unlock` im finally entfernt -> alle 124 Tests grün. Nur die Paralleltests wurden von 0,35 s auf 10 s / 20 s langsamer (Verbindung stirbt erst durch Idle-Timeout). Der AC-3-Test erkennt eine fehlende Freigabe also nicht.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: server/test/migrate.test.ts:187
  Description: `lockIsFree` holt den Probe-Client aus demselben Pool wie `migrate`. Advisory-Sperren sind je Session wiederholbar; kommt dieselbe (idle) Verbindung zurück, liefert pg_try_advisory_lock true, obwohl die Sperre noch gehalten wird. Mutationsprobe oben belegt das.
  Spec requirement: AC-3 — pg_try_advisory_lock auf einer fremden Verbindung liefert true (Beleg, dass die Freigabe wirkt).
  Conflict: Der Test beweist die Freigabe nicht; fehlende Freigabe würde unbemerkt bleiben.
  Remediation: Probe über einen eigenen pg.Client (neue Verbindung) oder zweite Pool-Verbindung, während die erste gehalten wird; oder pg_locks nach objid/classid abfragen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/migrate.ts:99
  Description: Die Zweige "ROLLBACK scheitert" (Zeile 65) und "pg_advisory_unlock scheitert" (Zeile 100-101) sowie "pg_advisory_lock wirft" (Zeile 95) haben keinen Test. Lesen des Codes: Originalfehler bleibt erhalten (catch schluckt Unlockfehler, throw error aus applyOne), release(Error) verwirft die Verbindung, Sperre endet mit der Session. Bei Wurf von pg_advisory_lock (z. B. Verbindungsabbruch) geht der Client mit release(false) zurück; pg entfernt eine tote Verbindung selbst. Kein Defekt gefunden, nur ungetestet. Kein Timeout auf der Wartezeit der Sperre (hängender Halter blockiert den Start unbegrenzt).
  Spec requirement: Source/migrate Schritt 6 — Freigabe darf Fehler nie überdecken, release(error).
  Conflict: Zugesichertes Verhalten ohne Testnachweis.
  Remediation: Fake-Client-Test (query wirft bei ROLLBACK/unlock; release-Argument prüfen).

Weitere Prüfung migrate.ts: loadMigrations vor connect (Zeile 91-92) erfüllt; CREATE TABLE und SELECT laufen auf client erst nach der Sperre (applyPending, aufgerufen nach Zeile 95) -> wartender Lauf liest erst nach der Sperre; Paralleltests grün. Funktionslängen: migrate 17, applyPending 14, applyOne 14 Zeilen, alle unter 50. MIGRATE_LOCK_ID 7_960_613_001 als Number, pg sendet Text, Postgres löst bigint auf; Test läuft grün.

Statische Prüfung Dockerfile/CI (kein Docker auf der Maschine, nichts ausgeführt): Dockerfile entspricht der Zielform der Spec Zeile für Zeile (server/Dockerfile:1-10). Laufzeit-Imports in src sind nur pg, @modelcontextprotocol/server, zod = dependencies. migrationsDir `../migrations` aus import.meta.dirname = /app/migrations, im Image vorhanden. main.ts-Logs: `${ISO} ${event}` (main.ts:21), "listening"/"migrated"/"shutting down"/"stopped" (101,104,136,138) passen zu den Regexen in server.yml:94-110. ISO-Regex erlaubt Millisekunden und Z, passt zu toISOString. Fehlerzeilen laufen über stderr, `2>&1` erfasst sie. grep 'postgres' ist strenger als `postgres://`, keine Log-Zeile von main.ts enthält das Wort. Env PORT=18080/HOST=127.0.0.1/DATABASE_URL passen zu main.ts:129. YAML parst. Pfadfilter unverändert. Exit-Code-Prüfung liest ExitCode nach `docker stop`, Aufräumen mit if: always().

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: .github/workflows/server.yml:80
  Description: Der Job `image` ist nur statisch geprüft. Ob Nutzer `node` uid 1000 hat, node:26-slim existiert und sh/ls/grep im Image sind, zeigt erst der CI-Lauf. Kein Defekt, nur nicht belegt.
  Spec requirement: AC-5..AC-8 — Beleg: CI-Lauf.
  Conflict: Beleg fehlt bis zum CI-Lauf.
  Remediation: CI-Lauf des PR abwarten, Ausgabe in den Abschlussbericht.

**Implementierer:**

### Runde 2
**Adversary:**
Zweiter Durchgang: (a) Fehler im ersten Lauf, danach Sperre frei: applyOne -> ROLLBACK ok -> broken bleibt false -> unlock (migrate.ts:99-100) -> release() ohne Fehler; Test grün, aber schwach (F001). (b) AC-4: loadMigrations vor pool.connect (migrate.ts:91-92), Zähl-Pool-Test grün (touched 0). (c) AC-2: drei Läufe gleichzeitig, vollständig, ohne Dopplung; 0,35 s im Normalfall. (d) AC-10 Vorprüfung: `git diff --stat origin/main` zeigt neben docs/ nur server/src/migrate.ts, server/test/migrate.test.ts und .github/workflows/server.yml; server/Dockerfile und server/.dockerignore sind noch untracked und kommen in den PR dazu. main.ts, package.json, package-lock.json, Migrationen, project.yml, Swift unberührt. Endgültig erst mit der PR-Dateiliste. (e) Das Verzeichnis .claude/ ist untracked und darf nicht in den PR. Weitere Codestellen: server/.dockerignore:1 (die fünf Zeilen der Spec), server/Dockerfile:8 (USER node vor CMD). Keine weiteren Defekte außer der Testlücke F001.
**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

AC-Status: AC-1..AC-4 belegt (Aussagekraft des AC-3-Tests eingeschränkt, F001). AC-5, AC-6, AC-7, AC-8, CI-Teil von AC-9 und AC-10 (PR-Dateiliste) sind statisch geprüft und bewusst offen, bis ein CI-Lauf auf dem PR vorliegt. Echte Defekte im Produktionscode: keine; ein Test ist zu schwach (F001, MEDIUM).

Confirmation:
  AC: AC-2
  Code reference: server/src/migrate.ts:95
  Evidence: Sperre vor CREATE TABLE/SELECT auf einem Client, Paralleltests mit 2 und 3 Läufen grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/migrate.ts:91
  Evidence: loadMigrations vor pool.connect; Zähl-Pool-Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: server/test/migrate.test.ts:150
  Evidence: test-red-output.txt zeigt 3 fail vor der Änderung, danach 124 pass.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/migrate.ts:99
  Evidence: unlock im finally, Originalfehler erhalten; Test grün, aber schwach (F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/.dockerignore:1
  Evidence: Vorprüfung der Dateiliste ok, offen bis PR (nicht abgehakt).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/Dockerfile:8
  Evidence: USER node vor CMD; Beleg erst durch CI (nicht abgehakt).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: .github/workflows/server.yml:69
  Evidence: Job image statisch konsistent mit main.ts; Beleg erst durch CI (nicht abgehakt).
  Status: CONFIRMED

VERDICT: AMBIGUOUS

## Geprüfte Dateien

- sha256:1541f856e0145ae07bc21c1d1a63237dcde42bfe21278176d53add60a34ea39d  .github/workflows/server.yml
- sha256:a4533b979ca332996c47bd64d247cc8cee37a67997ac9c7ea492ce81bb01bc32  server/.dockerignore
- sha256:1608c2ec70a0e6ebadd480743e8ef1948823ac4858d18251982300029449fc32  server/Dockerfile
- sha256:dbf8eccc88183ff503537e305befa204cb3edd492a297fa97fe9d2c52dc9f577  server/src/migrate.ts
- sha256:7458320af24610b3b4331637ea9167841ccc4d465e278c106b4b820c32c54d3e  server/test/migrate.test.ts

## Prüfbasis

- base: bc66568373eb78859d157a6b78ac9c39297b1aaa
- blob:fa3719b7f50742f9c5a619e9bcbad452bfc7401c  .github/workflows/server.yml
- blob:9c4429af8d4de850c5c771d13b973e750c65e76c  server/.dockerignore
- blob:ddd190b794e271e82269e000e473023093d2b259  server/Dockerfile
- blob:93a54f09301ebda0d08b2d579b44cc653f39ef61  server/src/migrate.ts
- blob:131b3285631412d69e9f027dda04187a239e4ca1  server/test/migrate.test.ts
