---
entity_id: feat-796-schnitt-2-image-und-sperre
type: feature
created: 2026-11-03
updated: 2026-11-03
status: draft
workflow: feat-796-s2-betrieb
---

# Spec: Betriebsfähiges Container-Image und Sperre in migrate, Schnitte S2+S3 (#796, Dienst auf Hetzner)

## Approval

- [ ] Approved

## GitHub Issue

#796 (Epic #612). Schnitte S2 und S3; das Issue bleibt offen (`Refs #796`, nie `Closes #796`), es schließt erst nach S4.
Analyse: `docs/context/feat-796-s2-betrieb.md` (Abschnitt „Analysis“), Vorgängerkontext `docs/context/feat-796-dienst-hetzner.md`.
Vorgänger: S1 (PR #813, Prozess-Einstieg und `/health`, Spec `docs/specs/feat-796-schnitt-1-prozess-einstieg.md`).
Nicht Teil dieser Spec: Ausrollen auf `rennwienix`, Compose-Stapel, nginx-Host, DNS, certbot, Sicherung (`pg_dump` im restic-Backup), Rückspielprobe, Überwachung (`monitor.sh`): alles S4, eigener Workflow, mit Abstimmung der Instanz `infra` und Hennings Freigabe für Schreibzugriffe auf dem Produktivserver.

## Purpose

Zwei Lücken verhindern, dass der Dienst aus `server/` dauerhaft laufen kann:

1. **Kein Container-Image (S2).** Der Dienst hat seit S1 einen Prozess-Einstieg, aber keine Form, in der ein Server ihn starten kann. Dieser Schnitt liefert `server/Dockerfile` und `server/.dockerignore` und beweist in der CI mit einem laufenden Container, dass das Image gegen Postgres 18 startet, migriert, auf `/health` mit 200 antwortet und bei SIGTERM sauber endet. Gebaut wird später auf dem Server aus einem Checkout des öffentlichen Repos (S4); die CI baut dasselbe Dockerfile vorher.
2. **`migrate` ist nicht gegen gleichzeitige Läufe gesichert (S3, #613 C1a F004).** Heute nutzt `migrate` `pool.query` für `CREATE TABLE` und `SELECT` und je Migration einen eigenen Client. Starten zwei Prozesse zugleich (Neustart, während der alte Prozess noch läuft; später mehrere Instanzen), lesen beide auf leerer Datenbank „nichts erledigt“ und spielen dieselbe Migration doppelt; einer scheitert am Primärschlüssel von `schema_migrations` oder an „already exists“. Der Fix: ein Client für den ganzen Lauf, davor ein Session-Advisory-Lock.

Die Sperre ist zuerst ein nachgestellter Fehler (RED-Test mit parallelen Läufen), dann der Fix; sie bleibt in diesem Schnitt ohne Änderung von Signatur und Rückgabewert von `migrate`.

**Regeln vor Modell:** Sperre, Dockerfile, CI-Schritte: Code und Konfiguration. Ein Sprachmodell ist nicht beteiligt; der Satz „Ohne Modell geht es nicht, weil …“ entfällt, es gibt keine Sprachaufgabe.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Weg B ist durch ADR-21 entschieden; dieser Schnitt sichert den Startpfad und baut das Image, es fällt keine neue Grundsatzentscheidung an (Lock-Art, Code-Transport und Ausrollweg stehen unter „Alternativen“ und lassen sich später ändern).

## Source

**Files:** `server/src/migrate.ts`, `server/test/migrate.test.ts`, `server/Dockerfile`, `server/.dockerignore`, `.github/workflows/server.yml`
**Identifier:** `migrate`, `MIGRATE_LOCK_ID`, Job `image`

### `server/src/migrate.ts`

- **`MIGRATE_LOCK_ID`** (exportiert): benannte, feste `bigint`-Konstante `7_960_613_001` als Zahl (liegt unter 2^53, Postgres nimmt sie als `bigint`). Ein einziger Wert für den ganzen Dienst; der Name im Code nennt den Zweck („migrate run lock“).
- **`migrate(pool, dir)`** bleibt mit gleicher Signatur und gleichem Rückgabewert (Namen der in diesem Lauf angewandten Migrationen, in Reihenfolge). Ablauf:
  1. `loadMigrations(dir)` **vor** jedem Datenbankzugriff (Fehler in Namen, Lücke, Doppelte werden weiter vor der Datenbank abgelehnt).
  2. `const client = await pool.connect()`; **ein** Client für den ganzen Lauf.
  3. `SELECT pg_advisory_lock($1)` mit `MIGRATE_LOCK_ID`: ein zweiter Lauf wartet hier, bis der erste fertig ist (Session-Lock, gilt auf dieser Verbindung).
  4. `CREATE TABLE IF NOT EXISTS schema_migrations …` und `SELECT name FROM schema_migrations` **erst nach** der Sperre, auf demselben Client; ein wartender Lauf liest damit den vollen Stand und hat nichts zu tun.
  5. Je Migration `BEGIN` … `INSERT INTO schema_migrations` … `COMMIT` auf demselben Client; bei Fehler `ROLLBACK`. `applyOne` nimmt dafür den Client statt des Pools.
  6. `finally`: `SELECT pg_advisory_unlock($1)`; die Freigabe darf einen ursprünglichen Fehler nie überdecken. Scheitert `ROLLBACK` oder `pg_advisory_unlock`, ist die Verbindung unbrauchbar: `client.release(error)` verwirft sie, und mit der Verbindung endet auch die Session-Sperre in Postgres. Andernfalls `client.release()`.
- Eine Migration steuert weiter nie ihre eigene Transaktion (kein `BEGIN`/`COMMIT` in der Datei).
- Der Lock gilt nur auf einer direkten Verbindung (kein Transaktions-Pooler wie PgBouncer davor): das ist hier gegeben (Recherche: GitLab-Ticket 608173, Netdata-Anleitung zu PgBouncer-Advisory-Locks, siehe Analyse).

### `server/Dockerfile`

```
FROM node:26-slim
ENV NODE_ENV=production HOST=0.0.0.0 PORT=8080
WORKDIR /app
COPY --chown=node:node package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --chown=node:node src ./src
COPY --chown=node:node migrations ./migrations
USER node
EXPOSE 8080
CMD ["node", "src/main.ts"]
```

- Inhalt als Zielform; Reihenfolge der Schichten: erst die Paketdateien, dann `npm ci`, dann der Code (Cache-Schicht für Abhängigkeiten). `npm ci --omit=dev` genügt: Laufzeit braucht nur `pg`, `@modelcontextprotocol/server`, `zod`. Typen werden von Node 26 beim Start entfernt (Type-Stripping, wie bei `npm start`), eine Build-Stufe gibt es nicht.
- `HOST=0.0.0.0`, weil `main.ts` sonst auf `127.0.0.1` bindet und im Container niemand herankäme; veröffentlicht wird später auf dem Host nur `127.0.0.1:<Port>` (S4).
- `USER node` (nicht root) gilt ab dem Start: `npm ci` läuft beim Bau noch als root, `node_modules` gehört root und ist für alle lesbar; `src/` und `migrations/` gehören über `--chown` dem Nutzer `node`. Der Dienst schreibt nichts auf die Platte.
- **Kein `HEALTHCHECK`** im Dockerfile. Begründung: `node:26-slim` enthält weder `curl` noch `wget`; ein node-basierter Check würde bei jedem Takt einen Node-Prozess starten (Speicher ist auf `rennwienix` knapp, Memory `loose-ends-hetzner-speicher-eng`) und doppelt, was Compose (`healthcheck:` im Stapel) und die Überwachung (`monitor.sh`, S4) ohnehin gegen `/health` leisten. Die CI prüft `/health` von außen mit `curl` auf dem Runner.
- Signal: `CMD` im Exec-Form-Array startet `node` als Prozess 1; SIGTERM erreicht `main.ts` direkt, das mit `close()` und Exit-Code 0 endet (S1).

### `server/.dockerignore`

`node_modules`, `test`, `scripts`, `*.log`, `.env*` (je eine Zeile). Der Bau-Kontext enthält damit weder lokale Pakete noch Tests, Skripte noch Zugangsdaten.

### `.github/workflows/server.yml`

Neuer Job `image` („Image (Docker, Postgres 18)“), unabhängig vom Job `test`, auf `ubuntu-latest`, mit demselben `postgres:18`-Dienst und denselben Pfadfiltern. Schritte:

1. `actions/checkout@v7`.
2. `docker build -t loose-ends-server:ci server`.
3. Container im Host-Netz starten: `docker run -d --name le-server --network host -e DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/postgres -e PORT=18080 -e HOST=127.0.0.1 loose-ends-server:ci` (Dienst-Port des Postgres-Dienstes ist auf dem Runner `127.0.0.1:5432`).
4. `/health` abfragen, bis 200 oder bis 60 Sekunden um sind (`curl --silent --output body.json --write-out '%{http_code}'`, Wiederholung im Sekundentakt); bei Zeitüberschreitung Log des Containers ausgeben und scheitern.
5. Body prüfen: JSON mit `status` „ok“, `db` „up“, `migrated` true (`jq -e`).
6. Log prüfen (`docker logs le-server`): jede nichtleere Zeile beginnt mit einem ISO-Zeitpunkt; die Zeichenketten `postgres://` und das Passwort kommen nicht vor; es steht `migrated` darin.
7. `docker stop --time 20 le-server` (sendet SIGTERM); der Exit-Code (`docker inspect --format '{{.State.ExitCode}}' le-server`) muss 0 sein, das Log enthält `shutting down` und `stopped`.
8. Immer: `docker logs` bei Fehlschlag anzeigen, Container entfernen (`if: always()`).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/src/main.ts` (`start`, SIGTERM, `HOST`/`PORT`/`DATABASE_URL`) | bestehend (S1), **unverändert**; das Image startet es |
| `server/src/migrate.ts` (`migrate`) | wird geändert; Aufrufer (`main.ts`, Tests) sehen Signatur und Rückgabe unverändert |
| `server/test/db.ts` (`freshPool`), `server/scripts/test-local.sh` | bestehend, **unverändert** |
| `server/package.json`, `package-lock.json` | bestehend, **unverändert** (keine neue Abhängigkeit) |
| `node:26-slim`, `postgres:18` (Docker Hub), `docker`, `curl`, `jq` auf dem Runner | extern, `ubuntu-latest` bringt `docker`, `curl`, `jq` mit |
| #615 S1 (PR #812) | gemergt; fasst `migrate.ts` nicht mehr an, die Sperre der Absprache mit Sitzung a7 ist aufgehoben. #615 S3 trägt nur Routen in `main.ts` ein |

## Acceptance Criteria

Tests in `server/test/migrate.test.ts` (Wegwerf-Schema über `freshPool` gegen echtes Postgres; die Sperre wirkt datenbankweit, deshalb mit je Test eigener Migrationsordner im Temp-Verzeichnis, dessen Dateien Wartezeit simulieren, wo nötig). Testnamen tragen das Suffix „(S3)“. Die Image-ACs belegt der CI-Job `image`.

- **AC-1 (Fehler nachgestellt):** Der Paralleltest aus AC-2 wird zuerst gegen den unveränderten `migrate.ts` ausgeführt und schlägt dort fehl (mindestens ein Lauf wirft einen Fehler zu `schema_migrations` oder „already exists“, oder eine Migration steht doppelt). Beleg: RED-Lauf im Workflow-Artefakt (`docs/artifacts/feat-796-s2-betrieb/`) vor der Änderung, danach derselbe Test grün.
- **AC-2:** Zwei bzw. drei `migrate`-Läufe gleichzeitig (`Promise.all`) gegen dasselbe leere Schema und einen Migrationsordner mit mindestens drei Migrationen: alle Läufe sind erfolgreich (keine Ablehnung); `schema_migrations` hat jede Migration genau einmal; die Vereinigung der Rückgabelisten ist genau die Menge aller Namen, und kein Name steht in zwei Rückgabelisten (keine Migration wird doppelt angewandt).
- **AC-3:** Nach einem fehlschlagenden Lauf (eine Migration mit kaputtem SQL) ist die Sperre frei: ein weiterer Lauf mit repariertem Ordner kommt innerhalb von 5 Sekunden zum Ende (Zeitgrenze im Test), und `pg_try_advisory_lock(MIGRATE_LOCK_ID)` auf einer fremden Verbindung liefert danach `true` (Gegenprobe: freigeben mit `pg_advisory_unlock`). Ein vor dem Fehler schon angewandter Migrationsschritt bleibt eingetragen, der kaputte nicht.
- **AC-4:** Fehler in Dateinamen, Lücke oder doppelte Nummer werden weiterhin abgelehnt, **bevor** die Datenbank berührt wird: Test mit einem Pool, dessen `connect` bei Aufruf wirft oder zählt, und einem Ordner mit Lücke; `connect` wurde nicht aufgerufen, die Ablehnung trägt die bisherige Meldung. Die bisherigen Tests in `migrate.test.ts` bleiben unverändert grün (Signatur, Rückgabewert, Reihenfolge, „erledigte werden nicht wiederholt“).
- **AC-5:** `docker build server` baut das Image. In der CI (Job `image`) startet der Container gegen den `postgres:18`-Dienst, `GET /health` liefert innerhalb von 60 Sekunden 200, der Body hat `status` „ok“, `db` „up“, `migrated` true. Beleg: CI-Lauf des PR.
- **AC-6:** Das Log des laufenden Containers enthält in jeder nichtleeren Zeile einen ISO-Zeitpunkt vorn und weder `postgres://` noch das Passwort; keine Aufgabentitel (es werden keine Aufgaben angelegt, das Log zeigt nur Ereigniszeilen wie `listening`, `migrated`). Beleg: CI-Lauf, Schritt „Log prüfen“.
- **AC-7:** `docker stop` (SIGTERM) beendet den Container mit Exit-Code 0 innerhalb von 20 Sekunden; das Log enthält `shutting down` und `stopped`. Beleg: CI-Lauf, Schritt „Beenden“.
- **AC-8:** Das Image läuft nicht als root (`docker run --entrypoint id loose-ends-server:ci -u` liefert nicht `0`) und enthält weder `test/` noch `scripts/` noch eine `.env*`-Datei. Beleg: CI-Lauf, Schritt „Image prüfen“.
- **AC-9:** `npm run typecheck` und `./server/scripts/test-local.sh` sind grün (alle bestehenden Tests plus die neuen); beide Jobs von `server.yml` (`test` und `image`) sind auf dem PR grün.
- **AC-10:** Die Dateiliste des PR enthält genau `server/src/migrate.ts`, `server/test/migrate.test.ts`, `server/Dockerfile`, `server/.dockerignore` und `.github/workflows/server.yml`, ausgenommen `docs/specs/`, `docs/context/`, `docs/artifacts/`, `docs/briefings/`. `server/src/main.ts`, `server/package.json`, `package-lock.json`, alle Migrationen, `project.yml` und jede Swift-Datei bleiben unberührt.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/migrate.ts` | MODIFY | `MIGRATE_LOCK_ID`, ein Client für den Lauf, `pg_advisory_lock` vor `CREATE TABLE`, `applyOne` auf dem Client, `unlock` im `finally`, `release(error)`; ≈ +25/−12 |
| `server/test/migrate.test.ts` | MODIFY | Paralleltest (2 und 3 Läufe), Sperre frei nach Fehler, Vorprüfung ohne `connect`; ≈ +60 |
| `server/Dockerfile` | CREATE | `node:26-slim`, Nutzer `node`, `npm ci --omit=dev`, `CMD ["node","src/main.ts"]`; ≈ +13 |
| `server/.dockerignore` | CREATE | `node_modules`, `test`, `scripts`, `*.log`, `.env*`; ≈ +5 |
| `.github/workflows/server.yml` | MODIFY | Job `image`: bauen, starten, `/health`, Log, SIGTERM, Aufräumen; ≈ +45 |

### Estimated Changes

- Files: 5 (Limit 4–5)
- LoC: Code und Konfiguration ≈ +88/−12 (Lock 25, Dockerfile 13, `.dockerignore` 5, CI 45), Tests ≈ +60 (≈ 1,5× des Lock-Codes eingerechnet: der Lock-Code ist klein, die Prüfung der Randfälle nicht). Summe ≈ +148/−12, unter der Grenze von 250. Jede Funktion ≤ 50 Zeilen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neue Migration, keine neuen Pakete, kein `generate`. Seiteneffekt außerhalb des Tickets: keiner; auf dem Server läuft nichts, bis S4 es bereitstellt.

## Test Plan

### Automated Tests (TDD RED)

RED: Der Paralleltest zuerst, gegen den unveränderten `migrate.ts`; er muss scheitern (AC-1).

- [ ] Test 1 (AC-1, AC-2): GIVEN leeres Schema und Ordner mit drei Migrationen WHEN zwei, dann drei `migrate` gleichzeitig THEN alle erfolgreich, jede Migration einmal in `schema_migrations`, Rückgaben disjunkt und zusammen vollständig.
- [ ] Test 2 (AC-3): GIVEN Ordner mit kaputter zweiter Migration WHEN `migrate` scheitert, danach Lauf mit repariertem Ordner THEN der zweite Lauf endet binnen 5 s; `pg_try_advisory_lock` auf fremder Verbindung ist `true`; die erste Migration bleibt eingetragen, die kaputte nicht.
- [ ] Test 3 (AC-4): GIVEN Ordner mit Lücke WHEN `migrate` mit Zähl-Pool THEN Ablehnung mit bisheriger Meldung, `connect` nie aufgerufen.
- [ ] Bestehende Tests (AC-4, AC-9): unverändert grün.
- [ ] Prüfung AC-5 bis AC-8: CI-Job `image` auf dem PR, Ausgabe der Schritte im Abschlussbericht.
- [ ] Prüfung AC-9/AC-10: `npm run typecheck`, `./server/scripts/test-local.sh` grün; Dateiliste des PR; `server.yml` grün.
- [ ] Zusätzlich lokal, soweit Docker verfügbar ist: `docker build server`, Start gegen das Postgres von `server/scripts/test-local.sh` (Host-Netz oder veröffentlichter Port), `curl /health`, `docker stop`, Exit-Code. **Grenze:** Auf der Maschine dieses Workflows gibt es kein Docker (`docker version` meldet „command not found“, geprüft 2026-11-03 nur lesend). Der Image-Nachweis läuft dort allein über den CI-Job `image`; wo Docker lokal fehlt, wird das im Abschlussbericht so benannt, und der lokale Teil entfällt, ohne dass etwas als belegt gilt, was nicht lief.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Frage | Gewählt | Alternative | Warum nicht |
|---|---|---|---|
| Lock-Art | Session-Lock (`pg_advisory_lock`) auf einem Client für den ganzen Lauf | `pg_advisory_xact_lock` je Migration plus Neulesen des Standes | mehr Code, nur nötig hinter einem Transaktions-Pooler, den es nicht gibt. Wäre die Wahl, sobald ein Pooler davorsteht |
| Code-Transport | Bau auf dem Server aus öffentlichem Checkout (`henemm/loose-ends` ist öffentlich, keine Zugangsdaten) | CI baut das Image nach GHCR, der Server zieht es per Digest | das erste Paket ist privat und lässt sich nur in der Web-Oberfläche öffentlich stellen; zusätzlicher `packages: write`-Pfad. Vorteil (kein Bau auf dem knappen Server) bleibt nachrüstbar |
| Überwachung | Einträge in `monitor.sh` (S4) | eigener Betterstack-URL-Monitor | Free-Plan mit 10 Monitoren und Heartbeats zusammen ist ausgereizt; Bezahlplan oder Umbau der Sammelbecken nötig |
| Ausrollen | von Hand nach Hennings Freigabe (Konvention von `henemm-infra`, S4) | eigener gebundener CI-Schlüssel wie `ci-ssh-dispatch.sh` | lohnt erst bei häufigen Releases; eigenes Ticket |
| Schnittgrenze | S2+S3 hier (nur Repo), S4 eigener Workflow | alles in einem | sprengt 4–5 Dateien und mischt zwei Repos |
| `HEALTHCHECK` | keiner im Dockerfile | node-basierter Check im Image (`node -e fetch(...)`) oder `curl` nachinstallieren | `slim` hat kein `curl`; Nachinstallieren vergrößert das Image und braucht einen Paketaufruf im Bau, ein Node-Prozess je Takt belastet den knappen Speicher; Compose-Healthcheck und `monitor.sh` leisten es in S4 |
| Migration getrennt vom Start | `migrate` im Prozess mit Sperre | eigener Schritt/Init-Container vor `npm start` | schafft zwei Betriebsarten (siehe Alternative C in der S1-Spec); mit der Sperre ist der Lauf im Prozess bei zwei Instanzen sicher |

## Nicht in diesem Schnitt / Folgeschnitte

- **S4** Bereitstellung auf `rennwienix` (Repo `henemm-infra`): Compose-Stapel `loose-ends/` mit Dienst und festem `postgres:18.x` (`mem_limit`, von watchtower ausgenommen, nur `127.0.0.1`), nginx-Host `loose-ends.henemm.com` mit nur `/health` durchgereicht, certbot, `pg_dump` im restic-Backup, Rückspielprobe in einen Wegwerf-Container, `monitor.sh`-Einträge. Voraussetzungen: dieser Schnitt gemergt, DNS-Eintrag, Abstimmung mit der Instanz `infra`, Hennings ausdrückliche Freigabe für Schreibzugriff auf den Produktivserver.
- `/mcp` bleibt am Netzrand gesperrt, bis Anmeldung und Konten da sind (#615, #621).
- Anmelden, Abmelden, Löschen als Routen: #615 S3 (trägt in die Routentabelle in `main.ts` ein).

## Abnahme

- Stufe 1: `npm run typecheck` und `./server/scripts/test-local.sh` grün (alle Tests gegen echtes Postgres); `server.yml` grün auf dem PR, beide Jobs.
- Stufe 2: Echter Lauf als Nutzer des Dienstes im CI-Job `image`: das gebaute Image läuft als Container gegen Postgres 18, `/health` antwortet 200 mit `migrated` true, SIGTERM beendet ihn mit Exit-Code 0 (AC-5 bis AC-8). Lokal zusätzlich `docker build` und Start gegen das Postgres von `test-local.sh`, wenn Docker verfügbar ist; auf dieser Maschine ist es das nicht (siehe Test Plan), dann zählt allein der CI-Lauf. Dazu der Beleg von `./scripts/sim.sh test-proof CaptureSmokeTests` für `phase8_complete`; er zeigt nur, dass die App auf dem Stand startet, ein Bedienablauf für den Dienst existiert in der App nicht.
- Stufe 3: entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt
- [ ] RED-Lauf des Paralleltests gegen den alten `migrate.ts` als Artefakt abgelegt, danach grün
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` (`test` und `image`) grün
- [ ] CI-Ausgabe des Jobs `image` (Health-Antwort, Log-Prüfung, Exit-Code) im Abschlussbericht
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #796 kommentiert (Stand S2+S3, S4 offen), Board-Karte aktuell; Issue bleibt offen

## Changelog

- 2026-11-03: Initial spec created (Schnitte S2+S3)
