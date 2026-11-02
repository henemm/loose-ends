---
entity_id: feat-796-schnitt-1-prozess-einstieg
type: feature
created: 2026-11-02
updated: 2026-11-02
status: draft
workflow: feat-796-dienst-hetzner
---

# Spec: Prozess-Einstieg, /health und Fehlerrate, Schnitt S1 (#796, Dienst auf Hetzner)

## Approval

- [ ] Approved

## GitHub Issue

#796 (Epic #612). Schnitt S1; das Issue bleibt offen (`Refs #796`, nie `Closes #796`), es schließt erst nach S4.
Analyse: `docs/context/feat-796-dienst-hetzner.md`. Vorgänger: #613 (Dienstgerüst, MCP-Handler ohne Port, ADR-21).
Nicht Teil dieser Spec: Container-Image und CI-Bau (S2), Sperre in `migrate` (S3, #613 C1a F004), Bereitstellung auf `rennwienix` (S4), Anmeldung und Konten (#615).

## Purpose

Der Dienst aus `server/` hat bisher keinen Prozess-Einstieg: keinen Port, kein `listen`, keinen Pool-Aufbau, kein `migrate` beim Start, keine Gesundheitsabfrage. Ohne ihn kann er nirgends laufen. Dieser Schnitt liefert den Einstieg `server/src/main.ts` und die Gesundheitslogik `server/src/health.ts`:

- Ein `pg.Pool` aus `DATABASE_URL` **mit** `error`-Listener. Ohne ihn beendet ein Fehler eines ruhenden Clients (Datenbank-Neustart, Netzabbruch) den ganzen Prozess (node-postgres, https://node-postgres.com/apis/pool; #613 C1a F006).
- `migrate` beim Start, mit Wiederholung, solange die Datenbank noch nicht erreichbar ist (beim gemeinsamen Hochfahren von Dienst und Postgres ist sie es zunächst nicht).
- Ein `node:http`-Server mit **Routentabelle Pfad → Handler** (`/health`, `/mcp`), damit #615 S3 Anmelden, Abmelden und Löschen nur noch einträgt.
- `/health`: 200 erst nach gelungenem `migrate` und gelungenem `SELECT 1`, sonst 503; zusätzlich 503, wenn mehr als die Hälfte der Antworten der letzten fünf Minuten 5xx waren (mindestens 20 Anfragen).
- Sauberes Beenden bei SIGTERM und SIGINT.

`/mcp` wird an `mcpHandler` durchgereicht. Eine Anmeldung gibt es noch nicht (#615): `authInfo` bleibt leer, der Handler lehnt Werkzeugaufrufe mit „kein Konto“ ab. Dass `/mcp` am Netzrand (nginx) gesperrt bleibt, bis die Anmeldung da ist, gehört zu S4; hier nur zur Kenntnis.

**Regeln vor Modell:** Routing, Wiederholung, Fensterzählung, Schwelle: Code und Arithmetik. Ein Sprachmodell ist nicht beteiligt; der Satz „Ohne Modell geht es nicht, weil …“ entfällt, es gibt keine Sprachaufgabe.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Weg B ist durch ADR-21 entschieden; dieser Schnitt baut nur den Prozess-Einstieg, es fällt keine neue Grundsatzentscheidung an.

## Source

**Files:** `server/src/main.ts`, `server/src/health.ts`, `server/test/main.test.ts`, `server/package.json`, `CLAUDE.md`
**Identifier:** `start`, `createPool`, `routes`, `ErrorWindow`, `healthHandler`

### `server/src/health.ts`

- **`ErrorWindow`** (reine Logik, Uhr eingespeist: `new ErrorWindow(now: () => number, windowMs = 300_000)`):
  - `record(status: number)` merkt Zeitpunkt und ob `status >= 500`.
  - `stats()` verwirft zuerst Einträge, die älter als `windowMs` sind, und liefert `{ requests, errors, errorRate }` (`errorRate` = `errors / requests`, bei 0 Anfragen 0, auf drei Nachkommastellen gerundet).
  - `tripped()` ist wahr, wenn `requests >= 20` **und** `errorRate > 0.5`. Die Mindestanzahl sorgt dafür, dass eine einzelne 500 nie reicht.
- **`healthHandler({ pool, isMigrated, window, timeoutMs = 2000 })`** gibt einen Handler `() => Promise<Response>` zurück:
  - `db`: `SELECT 1` auf dem Pool, begrenzt durch `timeoutMs` (Zeitgrenze per `Promise.race`; die Verbindung wird nicht abgebrochen, der Ausgang zählt als „down“). Fehler und Zeitüberschreitung sind `"down"`, nie eine Ausnahme.
  - Status 200 nur, wenn `isMigrated()` **und** `db` `"up"` **und** nicht `tripped()`; sonst 503.
  - Body JSON, `content-type: application/json`: `{ "status": "ok" | "unavailable", "db": "up" | "down", "migrated": boolean, "errorRate": number, "requests": number }`. Nur Zahlen und Schlagworte, nie Aufgabeninhalte, Kennungen, Titel oder Fehlertexte der Datenbank.

### `server/src/main.ts`

- **`createPool(databaseUrl, applicationName = "loose-ends")`**: `new pg.Pool({ connectionString, application_name })` (der Name macht die Verbindungen des Dienstes in `pg_stat_activity` erkennbar; der Test vergibt einen eigenen je Lauf) mit `pool.on("error", …)`, der nur eine Zeile ohne Fehlertext loggt (`error`-Ereignis eines ruhenden Clients; der Client wird vom Pool verworfen, der Prozess lebt weiter).
- **`start(options)`** mit `options = { databaseUrl, port, host?, migrationsDir, retryMs?, maxAttempts?, now?, applicationName?, extraRoutes? }` (`host` Standard `127.0.0.1`, `retryMs` Standard 2000, `maxAttempts` Standard 60, `now` Standard `Date.now`, `applicationName` wird an `createPool` gereicht, `extraRoutes` Standard leer: zusätzliche Einträge der Routentabelle, nur für Tests, der Prozessstart setzt sie nie). Ablauf:
  1. Pool bauen, `ErrorWindow` und `mcpHandler(pool)` anlegen.
  2. Server **zuerst** auf `host:port` lauschen lassen, damit `/health` schon während des Hochfahrens 503 mit `migrated: false` antworten kann.
  3. Im Hintergrund `migrate(pool, migrationsDir)` aufrufen; scheitert er (Datenbank nicht erreichbar), nach `retryMs` erneut, höchstens `maxAttempts` Versuche. Gelingt er, ist der Dienst „migriert“. Sind alle Versuche verbraucht, loggt der Prozess es und beendet sich mit Exit-Code 1 (Compose oder systemd starten ihn neu); im Test ist stattdessen `ready` abgelehnt.
  4. Rückgabe `{ url, ready, close }`: `url` = `http://<host>:<tatsächlicher Port>` (Port 0 erlaubt), `ready` = Promise, das nach gelungenem `migrate` erfüllt wird, `close()` beendet den Server (`server.close`, offene Verbindungen mit `closeAllConnections`) und danach `pool.end()`, ruft `handler.close()` auf und ist wiederholbar, ohne zu werfen.
- **Routentabelle** `routes: Record<string, (request: Request) => Promise<Response>>`, ein Eintrag je Pfad; `/health` → `healthHandler`, `/mcp` → `mcpHandler.fetch`, bis zum Ende von `migrate` mit 503 (der Dienst nimmt keine Aufträge vor dem Schema an). Unbekannter Pfad → 404 (leerer Body, wird gezählt, kein Pfad im Log). Ausnahme in einem Handler → 500 ohne Fehlertext im Body. Jede Antwort außer der von `/health` geht an `window.record(status)`; `/health` selbst zählt nicht.
- **Brücke `node:http` ↔ `Request`/`Response`**: Das Anfrage-Objekt wird aus Methode, URL (`http://<Host-Kopfzeile>` + Pfad), Kopfzeilen und Rumpf gebaut, die `Response` zurückgeschrieben. Die Brücke ist eine eigene Funktion (≤ 50 Zeilen).
- **Prozessstart nur bei direktem Aufruf** (`import.meta.main`): liest `DATABASE_URL` (fehlt sie: eine Zeile Fehler, Exit 1), `PORT` (Standard 8080), `HOST` (Standard `127.0.0.1`), Migrationsordner `../migrations` relativ zur Datei. `SIGTERM` und `SIGINT` rufen einmalig `close()` und beenden mit Exit-Code 0. Der Prozessstart fängt die Ablehnung von `ready` ab (`ready.catch`): eine Logzeile `migrate gave up`, dann `close()` und Exit-Code 1 — nie eine unbehandelte Ablehnung.
- **Logs**: eine Zeile je Ereignis, `new Date().toISOString()` vorn (`listening`, `migrated`, `migrate failed, retrying (n/max)`, `pool error`, `shutting down`, `stopped`), über `console.log`/`console.error`. Nie Aufgabentext, Kennungen, Titel, Datenbank-Fehlertexte oder Verbindungsdaten.

### `server/package.json`

Skript `"start": "node src/main.ts"`. Keine neue Abhängigkeit (nur `node:http`, `pg`, das vorhandene MCP-SDK). `server/src/migrate.ts`, `orders.ts`, `transcripts.ts`, `mcp.ts`, `accounts.ts` und alle Migrationen bleiben unberührt.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/src/migrate.ts` (`migrate(pool, dir)`) | bestehend, **unverändert**; Sperre dagegen ist S3 |
| `server/src/mcp.ts` (`mcpHandler(pool)`, `.fetch`, `.close`) | bestehend, **unverändert** |
| `server/test/db.ts`, `server/scripts/test-local.sh`, `.github/workflows/server.yml` | bestehend, unverändert; Testaufbau gegen echtes Postgres |
| `node:http`, `pg`, `@modelcontextprotocol/server` | bestehend, **keine neuen Pakete** |
| #615 S1/S3 (Sitzung a7) | Absprache: `main.ts` gehört #796, #615 S3 trägt Routen in die Tabelle ein, `accounts.ts` bleibt unberührt |

## Acceptance Criteria

Tests in `server/test/main.test.ts` (echter Port 0 auf `127.0.0.1`, Wegwerf-Postgres der bestehenden Testkette; die Fehlerraten-Logik zusätzlich als reiner Test mit eingespeister Uhr). Testnamen tragen das Suffix „(S1)“.

- **AC-1:** `start` mit gültiger `databaseUrl`, Port 0 und dem Migrationsordner: nach `await ready` antwortet `GET /health` mit 200 und einem JSON-Body mit `status` „ok“, `db` „up“, `migrated` true, `errorRate` 0 und `requests` (Zahl); der Body enthält außer diesen fünf Schlüsseln nichts.
- **AC-2:** Vor dem Ende von `migrate` antwortet `/health` mit 503, `migrated` false (Aufbau: `databaseUrl` zeigt auf einen Port ohne Postgres, `retryMs` 50). Der Prozess bleibt dabei erreichbar, `/mcp` antwortet in diesem Zustand ebenfalls mit 503. Nach `maxAttempts` erschöpften Versuchen ist `ready` abgelehnt, und `close()` wirft nicht.
- **AC-3:** `POST /mcp` mit JSON-RPC `initialize` (Protokoll wie in `mcp.test.ts`) antwortet mit 200 und einem `serverInfo` im Ergebnis; ein `tools/call` für `get_now` antwortet mit `isError` und „kein Konto“ (kein Anmeldeweg in diesem Schnitt, `authInfo` leer).
- **AC-4:** `GET /gibt-es-nicht` antwortet mit 404; die Anfrage zählt in `requests` des nächsten `/health`.
- **AC-5:** Werden alle Verbindungen des Pools mit `pg_terminate_backend` beendet (Verbindungen über `application_name` erkannt), lebt der Prozess weiter (der Testlauf selbst bricht nicht ab), und das nächste `GET /health` antwortet innerhalb von 5 Sekunden wieder mit 200 und `db` „up“. Eine Verbindung, die nur wegen des Abbruchs den `error`-Listener auslöst, schreibt keinen Fehlertext in die Ausgabe.
- **AC-6:** `close()` beendet den Server (ein weiterer `fetch` auf `url` schlägt mit Verbindungsfehler fehl) und den Pool (`pool.ended`); ein zweiter Aufruf von `close()` wirft nicht. Eine noch offene keep-alive-Verbindung hält `close()` nicht auf.
- **AC-7:** `ErrorWindow` mit eingespeister Uhr: 19 Antworten mit 500 sind nicht `tripped` (unter der Mindestanzahl); 20 Antworten, davon 11 mit 500, sind `tripped` (`errorRate` 0,55); 20 Antworten, davon 10 mit 500, sind nicht `tripped` (Schwelle ist „größer als“ 0,5); nach `now() + 300_001` ms sind alle Einträge verfallen (`requests` 0, `errorRate` 0, nicht `tripped`); `record` mit 404 oder 200 zählt als Anfrage, aber nicht als Fehler.
- **AC-8:** `/health` kippt auf 503 und erholt sich: mit eingespeister Uhr (`now`-Option von `start`) und einer Route, die 500 liefert (Aufbau: Handler wirft; im Test über einen eigens eingetragenen Pfad der Routentabelle, den `start` für Tests als Option `extraRoutes` entgegennimmt), kippt `/health` nach 20 Anfragen mit mindestens 11 Fehlern auf 503 mit `status` „unavailable“ und `errorRate` über 0,5, obwohl `db` „up“ und `migrated` true sind; nach Vorstellen der Uhr um mehr als 5 Minuten antwortet `/health` wieder mit 200. Die `/health`-Abrufe selbst haben die Zahl `requests` nicht erhöht.
- **AC-9:** `healthHandler` mit einer Datenbank, deren Abfrage länger als `timeoutMs` braucht (Test: Pool-Attrappe mit nie endendem `query`, `timeoutMs` 50): antwortet 503 mit `db` „down“ nach höchstens einer Sekunde, ohne zu werfen.
- **AC-10:** Datenschutz: Weder der Rumpf irgendeiner Antwort (`/health`, 404, 500, 503) noch eine Logzeile enthält Aufgabentitel, Auftragskennungen, Datenbank-Fehlertexte oder die `databaseUrl`; jede Logzeile beginnt mit einem ISO-Zeitpunkt. Der Test spiegelt `console.log` und `console.error` mit, speist eine Abschrift mit Titeln und einen Auftrag über das Schema ein und prüft die aufgefangenen Zeilen auf diese Zeichenketten.
- **AC-11:** Echter Lauf als Nutzer des Dienstes (kein Test, ein Beleg im Abschlussbericht): `./server/scripts/test-local.sh`-Postgres bzw. ein Wegwerf-Postgres wie dort, `DATABASE_URL=… PORT=<frei> npm start` in `server/`; `curl -i http://127.0.0.1:<Port>/health` liefert 200; Postgres wird gestoppt (`pg_ctl stop`), `curl /health` liefert 503 mit `db` „down“ und der Prozess läuft weiter; Postgres wird wieder gestartet, `curl /health` liefert wieder 200 ohne Neustart des Prozesses; `kill -TERM` beendet den Prozess mit Exit-Code 0 und den Zeilen `shutting down`, `stopped`. Ausgabe der Befehle wird im Abschlussbericht gezeigt.
- **AC-12:** `npm run typecheck` und `./server/scripts/test-local.sh` sind grün (bestehende Tests unverändert) und räumen auf; `server.yml` ist auf dem PR grün.
- **AC-13:** Die Dateiliste des PR enthält genau `server/src/main.ts`, `server/src/health.ts`, `server/test/main.test.ts`, `server/package.json` und `CLAUDE.md` (Abschnitt „Where things live“, Eintrag `server/`: `src/main.ts` mit Routentabelle, `/health`, `npm start`), ausgenommen `docs/specs/`, `docs/context/`, `docs/briefings/`. `server/src/migrate.ts`, `mcp.ts`, `orders.ts`, `transcripts.ts`, `accounts.ts`, `server/migrations/`, `project.yml` und jede Swift-Datei bleiben unberührt; `package-lock.json` ändert sich nicht (keine neue Abhängigkeit).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/main.ts` | CREATE | `createPool`, `start`, Routentabelle, Brücke `node:http` ↔ `Request`/`Response`, Prozessstart und Signale, ~+120 |
| `server/src/health.ts` | CREATE | `ErrorWindow`, `healthHandler`, ~+50 |
| `server/test/main.test.ts` | CREATE | Tests zu AC-1 bis AC-10 (Port 0, Wegwerf-Postgres, Fehlerraten-Logik), ~+190 |
| `server/package.json` | MODIFY | Skript `start`, ~+1 |
| `CLAUDE.md` | MODIFY | `server/`-Eintrag um Prozess-Einstieg, Routentabelle und `/health` ergänzt, ~+3 |

### Estimated Changes

- Files: 5 (vier Dateien in `server/` und eine Zeile in `CLAUDE.md`)
- LoC: Code ≈ +175 (Grenze `max_loc_delta` 250), Tests ≈ +190 (eigene Grenze `max_test_loc_delta` 500, `openspec.yaml`). Beide Grenzen halten, der Schnitt bleibt ungeteilt. Jede Funktion ≤ 50 Zeilen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Migration, keine neuen Pakete, kein `generate`. Seiteneffekt außerhalb des Tickets: keiner; die App ruft den Dienst nicht auf, und der Dienst läuft nirgends, bis S4 ihn bereitstellt.

## Test Plan

### Automated Tests (TDD RED)

RED: Die Tests zuerst; `main.ts` und `health.ts` fehlen, der Import schlägt fehl.

- [ ] Test 1 (AC-1): GIVEN gültige Datenbank WHEN `start` und `GET /health` THEN 200, fünf Schlüssel, `migrated` true.
- [ ] Test 2 (AC-2): GIVEN Port ohne Postgres, `retryMs` 50, `maxAttempts` 3 WHEN `GET /health` und `POST /mcp` THEN 503, `migrated` false; danach `ready` abgelehnt, `close()` wirft nicht.
- [ ] Test 3 (AC-3): GIVEN laufender Dienst WHEN `initialize` und `tools/call get_now` über `POST /mcp` THEN `serverInfo`, bzw. `isError` „kein Konto“.
- [ ] Test 4 (AC-4): GIVEN laufender Dienst WHEN unbekannter Pfad THEN 404, `requests` im nächsten `/health` erhöht.
- [ ] Test 5 (AC-5): GIVEN laufender Dienst WHEN `pg_terminate_backend` auf alle Verbindungen des Pools THEN Prozess lebt, `/health` binnen 5 s wieder 200.
- [ ] Test 6 (AC-6): GIVEN laufender Dienst mit offener keep-alive-Verbindung WHEN `close()` zweimal THEN Server und Pool beendet, kein Fehler.
- [ ] Test 7 (AC-7): GIVEN `ErrorWindow` mit eingespeister Uhr WHEN 19, 20 (11 Fehler), 20 (10 Fehler) Antworten und Fensterablauf THEN `tripped` wie beschrieben.
- [ ] Test 8 (AC-8): GIVEN laufender Dienst mit fehlerhafter Testroute und eingespeister Uhr WHEN 20 Anfragen und Uhr vorstellen THEN 503, danach wieder 200.
- [ ] Test 9 (AC-9): GIVEN Pool-Attrappe ohne Antwort WHEN `healthHandler` THEN 503, `db` „down“.
- [ ] Test 10 (AC-10): GIVEN eingespeiste Abschrift mit Titeln, gespiegelte Ausgabe WHEN verschiedene Antworten und Ereignisse THEN keine Titel, Kennungen, Fehlertexte oder URL; Logzeilen beginnen mit ISO-Zeitpunkt.
- [ ] Prüfung AC-11: echter lokaler Lauf wie beschrieben, Ausgabe im Abschlussbericht.
- [ ] Prüfung AC-12/AC-13: `./server/scripts/test-local.sh` grün; Dateiliste des PR; `server.yml` grün.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A: Express oder Fastify statt `node:http`:** weniger Brückencode und fertige Routenverwaltung, aber eine neue Abhängigkeit für zwei, später fünf Pfade; die Projektregel verlangt Freigabe neuer Abhängigkeiten, und das MCP-SDK liefert bereits einen Fetch-Handler (`Request` → `Response`). Nicht gewählt. Kippt nichts, wäre später nachrüstbar.
- **B: `/health` ohne Fehlerrate, Fehlerrate als Folgeticket:** kleiner, das Ticket nennt sie aber ausdrücklich, und sie erkennt, was `SELECT 1` nicht sieht (Handler, die dauernd werfen, bei lebender Datenbank). Nicht gewählt, bleibt in S1.
- **C: `migrate` als eigener Schritt vor dem Start** (`npm run migrate`, danach `npm start`; in Compose als Init-Container): trennt Schema-Änderung vom Lauf und kommt ohne Wiederholung im Prozess aus. Verworfen, weil es zwei Betriebsarten für den Dienst schafft, das Warten auf die Datenbank dann im Init-Schritt steckt und `/health` „migriert“ nicht mehr aus dem Prozess selbst beantworten kann. Mit der Sperre aus S3 ist `migrate` im Prozess auch bei zwei Instanzen sicher. Wäre die Alternative, falls später mehrere Instanzen laufen.
- **D: Fehlerrate nach absoluten Fehlern statt Anteil:** einfacher, aber bei viel Verkehr dauernd rot, bei wenig nie. Nicht gewählt.
- **E: Schwelle sofort zum Neustart statt 503:** Der Prozess beendet sich selbst bei hoher Fehlerrate. Verworfen: `/health` soll melden, nicht handeln; Neustart bleibt Sache von Compose und Überwachung.

## Nicht in diesem Schnitt / Folgeschnitte

- **S2** Container-Image und CI-Bau (`Dockerfile`, `.dockerignore`, `server.yml`).
- **S3** `pg_advisory_lock` um den ganzen `migrate`-Lauf samt Test mit zwei parallelen Läufen (#613 C1a F004), nach dem Merge von #615 S1.
- **S4** Bereitstellung auf `rennwienix` (`henemm-infra`: Compose, nginx-Host `loose-ends.henemm.com`, certbot, `pg_dump` im restic-Backup, Wiederherstellungsprobe, Betterstack-Monitor auf `/health`). `/mcp` bleibt dort am Netzrand gesperrt, bis die Anmeldung (#615, #621) da ist.
- Anmelden, Abmelden, Löschen als Routen: #615 S3 (trägt in die Routentabelle ein).
- Begrenzung der Rumpfgröße, Zeitgrenzen für langsame Clients (`headersTimeout`, `requestTimeout` bleiben auf den Node-Standards): gehören zur Härtung am Netzrand (S4, nginx), nicht in den Prozess.

## Abnahme

- Stufe 1: `./server/scripts/test-local.sh` grün; `server.yml` grün auf dem PR.
- Stufe 2: Pflicht für den Abschluss. Echter Lauf als Nutzer des Dienstes (AC-11): Prozess mit `npm start` gegen Wegwerf-Postgres, `curl /health`, Datenbank-Stopp und -Start, erneut `curl /health`, `SIGTERM`. Dazu der Beleg von `./scripts/sim.sh test-proof CaptureSmokeTests` für `phase8_complete`; er zeigt nur, dass die App auf dem Stand startet, ein Bedienablauf für den Dienst existiert in der App nicht.
- Stufe 3: entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] Echter lokaler Lauf (AC-11) mit Ausgabe im Abschlussbericht
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #796 kommentiert (Stand S1), Board-Karte aktuell

## Changelog

- 2026-11-02: Initial spec created (Schnitt S1)
