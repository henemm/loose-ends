# Context: spike-613-c1-server-geruest

## Request Summary
Schnitt C1 von Spike #613 (Weg B, „Fenster für Claude“): das Gerüst des eigenen Dienstes unter `server/` (TypeScript auf Node,
Postgres) samt Datenbank-Schema für Abschrift und Aufträge, mit eigener Testkette lokal und in der CI. Noch kein HTTP-Endpunkt,
keine Anmeldung, kein MCP (C3, C4, C6).

## Stand vor diesem Schnitt
- C2 (App-Seite) gemergt, PR #779: `TranscriptCodec`, `OrderExecutor`, Vertrag v1 `docs/reference/claude-abschrift-vertrag.md`.
- C0 erledigt (2026-10-31, ohne Workflow): Homebrew-`node` 26.5.1 startete nicht (fehlende `libsimdjson.33`), `brew upgrade node`
  → `node` v26.13.0, `npm` 11.20.0. Kein `psql`, kein Postgres, kein Docker auf dem Mac.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/reference/claude-abschrift-vertrag.md` | Vertrag v1: Felder der Abschrift, drei Auftragsarten, Ergebnisse (`done`/`rejected` + `invalid`/`missing`/`stale`). Das Schema bildet ihn ab |
| `docs/specs/spike-613-schnitt-1-abschrift-auftraege.md` | Liste der Folgeschnitte C0–C8, Haltepunkte bei Henning |
| `docs/context/spike-613-backend-weg-b.md` | Recherche des Spikes (MCP-SDK v2.4, node-oidc-provider, Claude-Connector-Auth), Schnittplan „C1 Vertrag + `server/`-Gerüst + Postgres-Schema (~150 LoC)“ |
| `LooseEndsTests/TranscriptCodecTests.swift`, `LooseEndsTests/OrderExecutorTests.swift` | wörtliche JSON-Beispiele des Vertrags; der Dienst soll dieselben Beispiele annehmen (Fixtures teilen statt kopieren) |
| `.github/workflows/ci.yml` | alle Jobs auf `xcode-27` (macOS); Skript-Tests laufen als erster Schritt im Job `unit-tests` (`unittest discover -s scripts`). Ein Server-Job braucht Postgres → eigener Job auf `ubuntu-latest` mit Postgres-Dienstcontainer |
| `scripts/test_ci_xcode27.py` | prüft die Workflows; verlangt vermutlich `xcode-27` für jeden Job → ein Linux-Job muss dort als Ausnahme bekannt sein (in der Analyse prüfen) |
| `.gitignore` | `node_modules/` fehlt noch; `.env`/`.env.*` schon ausgeschlossen |
| `CLAUDE.md` („Where things live“) | `server/` muss dort eingetragen werden |

## Existing Patterns
- Reine Logik mit Tests zuerst, Aufrufer später (C2: Codec und Ausführer ohne Aufrufer im Produkt).
- Werkzeuge der Pipeline sind Python mit `unittest`, Workflows werden von Python-Tests geprüft (`test_ci_xcode27.py`,
  `test_entitlements_sync.py`). TypeScript gibt es im Repo bisher nicht.
- Schemas als Datei im Repo, von CI geprüft: `cloudkit/schema.ckdb` + `scripts/test_cloudkit_schema.py`. Gleiches Muster für
  `server/schema.sql`.
- Henning-Projekte mit TypeScript: `helix-mvp` (Next.js, Jest). Kein bestehendes Muster für einen schlanken Node-Dienst.

## Recherche (2026-10-31)
- Node 26: TypeScript-Ausführung per Typ-Entfernung ist **stabil** (Stability 2), ohne Build-Schritt; nur löschbare Syntax
  (keine `enum`, `namespace`, Parameter-Properties, Dekoratoren), Importe mit Dateiendung, `import type` Pflicht, `tsconfig` wird
  ignoriert → Typprüfung separat mit `tsc --noEmit`. https://nodejs.org/download/release/v26.5.1/docs/api/typescript.html
- Testläufer: `node:test` ist eingebaut, damit braucht es keine Test-Abhängigkeit.
- Treiber `pg` (node-postgres), laut depscope 8.21.0; offiziell getestet bis Node 24, Version beim Anlegen per `npm view pg version`
  festhalten. https://node-postgres.com/ , https://depscope.dev/api/check/npm/pg
- CI: Postgres als Dienstcontainer mit `pg_isready`-Healthcheck, auf einem Runner ohne Container über `127.0.0.1:5432`.
  https://docs.github.com/fr/actions/tutorials/use-containerized-services/create-postgresql-service-containers ,
  https://qaskills.sh/blog/github-actions-service-container-health-check-postgres
- Lokal: Homebrew `postgresql@18` (18.6) oder `@17` (17.11) installierbar; Server-Version auf rennwienix unbekannt (C7).

## Dependencies
- Upstream: Vertrag v1 (Felder, Fehlerarten), Node 26, Postgres.
- Downstream: C3 Dienstkern (liest und schreibt die Tabellen; muss `version` beim Annehmen prüfen und einen Auftrag genau einem
  Gerät geben), C4 MCP, C5 A/B-Nachweis, C6a (OAuth-Tabellen kommen dazu), C7 Betrieb auf Hetzner.

## Risks & Considerations
- **Neue Sprache im Repo:** Lint, Typprüfung und Tests müssen in der CI laufen, sonst verrottet `server/` unbemerkt.
- **CI-Kosten/Runner:** Linux-Job mit Postgres-Dienst; `test_ci_xcode27.py` darf ihn nicht als Fehler werten.
- **Schema-Entwicklung:** Ab dem ersten Betrieb (C7) nur noch Zusatzmigrationen → schon jetzt nummerierte Migrationsdateien
  statt einer einzigen `schema.sql`, die man später nicht mehr ändern darf.
- **Datensparsamkeit:** Die Abschrift wird als JSON-Dokument je Gerät/Konto gespeichert (Dienst rechnet nichts nach) oder in Spalten
  zerlegt; der Vertrag spricht für „Dokument speichern, nur prüfen“. Entscheidung in der Analyse.
- **Konto ohne Anmeldung:** Bis C6 gibt es keine Nutzer; das Schema braucht trotzdem eine Konto-Spalte, damit C6 nur ergänzt.
- **Fixtures:** Die JSON-Beispiele des Vertrags sollten an einer Stelle liegen, die Swift-Tests und Server-Tests lesen, sonst
  laufen die zwei Seiten auseinander.
- **Abhängigkeiten:** keine neuen ohne Freigabe (globale Regel). `pg` und `typescript` (nur Entwicklung) sind das Minimum.
- Kein Pfad der Geräteliste (Stufe 3) berührt; kein Simulator-Ablauf ändert sich. Für `phase8_complete` braucht es trotzdem einen
  `test-proof`-Beleg (Memory `loose-ends-613-s1-gemergt`).
- Alternative zur lokalen Postgres-Installation: PGlite (Postgres als WASM in Node, keine Installation) für Tests; in der Analyse
  gegen echtes Postgres abwägen (Unterschiede zum Betrieb).

## Analysis

### Type
Feature (Spike-Schnitt, Unterbau ohne sichtbare Änderung in der App)

### Befunde
- **CI-Prüfung steht nicht im Weg:** `scripts/test_ci_xcode27.py` prüft `runs-on: xcode-27` nur für die Jobs in `ci.yml` und
  `speech-stress.yml`. Ein eigener Workflow `.github/workflows/server.yml` auf `ubuntu-latest` mit Postgres-Dienstcontainer
  braucht dort keine Ausnahme. `main` hat keinen Branchschutz (gh: „Branch not protected“) → ein Pfadfilter (`server/**`,
  Vertrag, Workflow selbst) blockiert keinen PR.
- **Fixtures teilen ist schon gelöst:** Die Swift-Tests prüfen, dass der Vertrag `docs/reference/claude-abschrift-vertrag.md`
  ihre Beispiele wörtlich enthält (`documentCarriesFixture`). Die Server-Tests lesen die ```json-Blöcke aus derselben Datei.
  Eine Quelle, keine Kopie, keine Änderung an `project.yml`.
- **Abhängigkeiten:** Henning hat am 2026-10-31 „Postgres + ein TypeScript-Dienst“ gewählt (Memory
  `loose-ends-612-weg-b-fenster-fuer-claude`). Daraus folgt das Minimum: `pg` 8.23.1 (Laufzeit), `typescript` 7.0.2,
  `@types/pg` 8.23.1, `@types/node` 26.6.6 (nur Entwicklung). Kein Testframework (`node:test`), kein Lint-Werkzeug
  (`tsc --strict --noEmit` ist die Prüfung), kein Formatierer. Versionen per `npm view` am 2026-10-31; Lockfile wird eingecheckt.
- **Lokal:** `node` v26.13.0 läuft (C0). Postgres fehlt → Homebrew `postgresql@18` (18.6) als Werkzeug auf dem Mac,
  gestartet nur für den Testlauf mit Wegwerf-Datenordner (`initdb` + `pg_ctl` auf eigenem Port), kein Dauerdienst.
- **Scope-Grenze:** Gerüst + Testkette + CI + Migrationsläufer + Schema + Vertragstests ergäben ~8 Dateien und ~280–310 LoC
  (über 4–5 Dateien / ±250). Deshalb geteilt:
  - **C1a (dieser Workflow):** Gerüst, Migrationsläufer, Testkette lokal und CI.
  - **C1b (eigener Workflow danach):** `migrations/001_*.sql` (Abschrift, Aufträge, Ergebnisse) + Tests gegen die Vertragsbeispiele.

### Affected Files (C1a)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/package.json` (+ `package-lock.json`, generiert) | CREATE | `type: module`, `engines.node >=26`, Skripte `typecheck` (`tsc --noEmit`), `test` (`node --test`), `test:local` |
| `server/tsconfig.json` | CREATE | `strict`, `noEmit`, `erasableSyntaxOnly`, `verbatimModuleSyntax`, `allowImportingTsExtensions` — passend zur Typ-Entfernung von Node |
| `server/src/migrate.ts` | CREATE | liest `migrations/NNN_*.sql` in Nummernfolge, wendet jede fehlende in einer Transaktion an, merkt sie in `schema_migrations`; Fehler → Rückrollen, nichts gemerkt, Fehler weitergereicht (kein Verschlucken) |
| `server/test/migrate.test.ts` (+ kleine Test-Migrationsordner) | CREATE | gegen echtes Postgres (`DATABASE_URL`, fehlt = Test schlägt fehl, nie übersprungen): Reihenfolge, zweiter Lauf wendet nichts an, kaputte Migration rollt zurück und wird nicht gemerkt, Lücke/Doppelnummer wird abgelehnt |
| `server/scripts/test-local.sh` | CREATE | Wegwerf-Postgres starten, Tests, aufräumen |
| `.github/workflows/server.yml` | CREATE | `ubuntu-latest`, Dienst `postgres:18` mit `pg_isready`, `setup-node` 26, `npm ci`, `typecheck`, `test` |
| `.gitignore` | MODIFY | `node_modules/` |
| `CLAUDE.md` | MODIFY | `server/` unter „Where things live“, Befehle unter „Build“ |

### Scope Assessment
- Files: 8 (davon 2 Einzeiler/Doku, Lockfile generiert)
- Estimated LoC: ~+170/-0
- Risk Level: LOW — neuer, abgeschlossener Ordner; App, Xcode-Projekt und bestehende CI-Jobs bleiben unberührt.

### Technical Approach
Eigener Ordner `server/` mit TypeScript, das Node 26 direkt ausführt (Typ-Entfernung stabil, kein Build-Schritt); Typprüfung
getrennt mit `tsc`. Datenbankänderungen nur als nummerierte Migrationsdateien, die ein eigener kleiner Läufer genau einmal
anwendet — ab dem Betrieb (C7) darf nur noch ergänzt werden. Tests laufen immer gegen echtes Postgres: lokal ein Wegwerf-Server,
in der CI ein Dienstcontainer, in einem eigenen Workflow, damit die macOS-Jobs und ihre Prüfung unberührt bleiben.

### Alternativen (verworfen, mit Grund)
- **PGlite statt echtem Postgres** (Postgres als WASM, keine Installation): eine Verbindung, andere Sperrsemantik; C3 braucht
  „ein Auftrag geht an genau ein Gerät“ (`FOR UPDATE SKIP LOCKED` über mehrere Verbindungen) — das prüft nur echtes Postgres.
- **Fertiges Migrationswerkzeug** (node-pg-migrate, Kysely, Prisma): mehr Abhängigkeiten für ~40 Zeilen Läufer; Prisma bringt ein
  eigenes Schema-Format. Kippbar, falls Migrationen später komplex werden.
- **Server-Job in `ci.yml`:** müsste `test_ci_xcode27.py` aufweichen (jeder Job dort = `xcode-27`); eigener Workflow ist sauberer.
- **Ein Schnitt C1 statt C1a/C1b:** sprengt die Scoping-Grenze.

### Für C1b vorgemerkt (Schema-Entscheidungen)
- Abschrift als `jsonb`-Dokument je Konto und Gerät (Dienst rechnet nichts nach, Vertrag), dazu `generated_at`, `received_at`;
  Claude liest die jüngste.
- Aufträge mit `id` (UUID aus dem Auftrag), `kind` per CHECK auf die drei Arten, Dokument `jsonb`, CHECK `version = 1`,
  Spalten für die Vergabe an genau ein Gerät (`claimed_by`, `claimed_at`) — die Vergabe selbst ist C3.
- Ergebnisse je Auftrag (`outcome`/`reason` per CHECK, `reason` nur bei `rejected`).
- `account_id` überall Pflicht, ohne Fremdschlüssel bis C6 (dort additiv ergänzt).

### Dependencies
- Upstream: Vertrag v1, Node 26, Postgres 18 (Version auf rennwienix in C7 prüfen; das Schema nutzt nichts nach PG 13).
- Downstream: C1b Schema, C3 Dienstkern, C7 Betrieb (führt `migrate` beim Start aus).

### Abnahme
Kein Pfad der Geräteliste berührt, kein Simulator-Ablauf ändert sich. `phase8_complete` verlangt trotzdem einen
`sim.sh test-proof`-Beleg (wie in C2: `CaptureSmokeTests`).

### Open Questions
- keine an Henning (Abhängigkeiten folgen aus seiner Wahl „Postgres + TypeScript-Dienst“; Teilung ist eine Scoping-Entscheidung)

## Erkenntnisse aus TDD RED (2026-10-31)

- `postgresql@18` ist per Homebrew installiert (`/opt/homebrew/opt/postgresql@18/bin`), kein Dienst gestartet.
- `test-local.sh`: Liegt der Datenordner unter einem langen Pfad (Scratchpad, `mktemp` unter `/private/tmp/claude-…`), scheitert der Start mit
  „Unix-Domain-Socket-Pfad … ist zu lang (maximal 103 Bytes)“. Lösung: `pg_ctl … -o "-p <port> -c unix_socket_directories= -c listen_addresses=127.0.0.1"`, nur TCP.
  `initdb -U postgres -A trust`; `DATABASE_URL=postgres://postgres@127.0.0.1:<port>/postgres`.
- Die Tests legen ihre Migrationsordner selbst in `mkdtemp` an (Anlage-Reihenfolge steuerbar); ein statischer Ordner `server/test/fixtures/` entfällt.
- Fehlermeldungen, die die Tests erwarten: Lücke → Meldung passt auf `/Lücke.*002/`, doppelte Nummer → `/doppelt.*002/`; beides vor `CREATE TABLE schema_migrations`.
- Jeder Test hat ein eigenes Schema per `search_path`; `migrate` legt `schema_migrations` ohne Schema-Präfix an (Spalte `name`).
- AC-5 hängt an der Prüfung oben in `migrate.test.ts`; sie greift erst, wenn `src/migrate.ts` existiert (ESM-Importe laufen vor dem Modulcode).
