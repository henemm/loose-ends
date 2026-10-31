---
entity_id: spike-613-schnitt-c1a-server-geruest
type: feature
created: 2026-10-31
updated: 2026-10-31
status: draft
workflow: spike-613-c1-server-geruest
---

# Spec: Server-Gerüst mit Migrationsläufer und Testkette, Schnitt C1a (#613, Weg B „Fenster für Claude“)

## Approval

- [ ] Approved

## GitHub Issue

#613 (Spike, Epic #612). Schnitt C1a; das Issue bleibt offen (`Refs #613`, nie `Closes #613`).
Der Ticket-Text ist überholt (siehe Vorgänger-Spec `docs/specs/spike-613-schnitt-1-abschrift-auftraege.md`): Weg B gilt, iCloud/CloudKit (ADR-2) bleibt der Abgleich,
der eigene Dienst hält nur Abschrift und Auftragsweg.

## Purpose

Der Dienst für Claude braucht einen Ort und eine Prüfkette, bevor Schema und Logik hineinkommen. Dieser Schnitt legt den Ordner `server/` an
(TypeScript, das Node 26 direkt ausführt; Postgres), einen kleinen Migrationsläufer, der nummerierte SQL-Dateien genau einmal anwendet, und die Testkette lokal und in der CI.
Es gibt noch kein Schema, keinen HTTP-Endpunkt, keine Anmeldung und kein MCP. In der App ändert sich nichts Sichtbares.

**Regeln vor Modell:** Alles ist deterministisch; kein Sprachmodell beteiligt. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Dieser Schnitt legt nur Werkzeug und Gerüst fest, keine Produktentscheidung. Die Wahl „Postgres + ein TypeScript-Dienst“ traf Henning am 2026-10-31
  (Weg B, Memory `loose-ends-612-weg-b-fenster-fuer-claude`); sie wird mit ADR-21 im letzten Schnitt des Spikes (C8) festgehalten, ergänzt ADR-2 und löst es nicht ab.

## Source

**File:** `server/src/migrate.ts` (Hauptdatei; übrige Dateien in der Tabelle unter Scope)
**Identifier:** `migrate` (Funktion), `loadMigrations` (Funktion, liest und prüft die Ordner-Dateien)

Verhalten von `migrate(pool, dir)`:

- liest `NNN_name.sql` aus `dir`, sortiert nach Nummer; legt bei Bedarf die Tabelle `schema_migrations` an;
- wendet jede noch nicht gemerkte Migration in einer eigenen Transaktion an und trägt sie in derselben Transaktion in `schema_migrations` ein;
- schlägt eine Migration fehl: `ROLLBACK`, kein Eintrag, der Fehler wird unverändert weitergeworfen (kein Verschlucken, kein `catch` ohne Wurf);
- Lücke in der Nummernfolge oder doppelte Nummer: Ablehnung vor der ersten Änderung an der Datenbank;
- Rückgabe: Liste der in diesem Lauf angewandten Dateinamen.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `pg` 8.23.1 | Laufzeit (Postgres-Treiber), nach `npm view` am 2026-10-31 |
| `typescript` 7.0.2 | nur Entwicklung (`tsc --noEmit`) |
| `@types/pg` 8.23.1, `@types/node` 26.6.6 | nur Entwicklung (Typen) |
| Node 26 (lokal v26.13.0 seit C0) | Typ-Entfernung stabil, `node:test` eingebaut, kein Testframework nötig |
| Postgres 18 | lokal Homebrew `postgresql@18` mit Wegwerf-Datenordner (`initdb` + `pg_ctl`, eigener Port, kein Dauerdienst); CI Dienstcontainer `postgres:18` |
| `actions/setup-node` (Version 26) | CI |
| `docs/reference/claude-abschrift-vertrag.md` (Vertrag v1) | nur Hintergrund; das Schema dazu ist C1b |

Keine weiteren Abhängigkeiten: kein Lint- oder Formatierwerkzeug (`tsc --strict --noEmit` ist die Prüfung), kein Migrationswerkzeug, kein ORM.

## Acceptance Criteria

- **AC-1:** `migrate` wendet die Migrationen eines Ordners in Nummernfolge an (nicht in Dateisystem- oder Einfügereihenfolge) und liefert die angewandten Namen in dieser Folge zurück.
  Belegt durch `server/test/migrate.test.ts` (Fixture-Ordner mit drei Dateien, Namen werden bewusst unsortiert angelegt; Ergebnis `001`, `002`, `003`; die von Migration 002 angelegte Tabelle sieht die Migration 003).
- **AC-2:** Ein zweiter Lauf auf derselben Datenbank wendet nichts an (leere Rückgabe) und ändert nichts; `schema_migrations` hat danach genau eine Zeile je Datei. Kommt eine neue Datei hinzu, wird nur sie angewandt.
  Belegt durch `migrate.test.ts` (zweiter Lauf, dann Ordner mit zusätzlicher vierter Datei).
- **AC-3:** Eine kaputte Migration (SQL-Fehler nach einer gültigen Anweisung in derselben Datei) rollt vollständig zurück: die gültige Anweisung hinterlässt keine Tabelle, die Migration steht nicht in `schema_migrations`,
  frühere gültige Migrationen bleiben angewandt, und `migrate` wirft den ursprünglichen Postgres-Fehler weiter (Test prüft Fehlercode bzw. Meldung, nicht nur „wirft“).
  Belegt durch `migrate.test.ts`.
- **AC-4:** Eine Lücke in der Nummernfolge (`001`, `003`) und eine doppelte Nummer (`002_a.sql`, `002_b.sql`) werden mit eindeutiger Fehlermeldung abgelehnt, bevor irgendeine Migration angewandt wird
  (Tabelle `schema_migrations` bleibt leer bzw. unverändert). Belegt durch `migrate.test.ts` (zwei Fälle).
- **AC-5:** Die Tests laufen gegen echtes Postgres über `DATABASE_URL`. Fehlt die Variable, **schlägt** der Test fehl (mit Meldung, die `DATABASE_URL` nennt); er wird nie übersprungen (`skip`/`todo` kommen im Test nicht vor).
  Jeder Test nutzt ein eigenes frisches Schema oder eine frische Datenbank, so dass Läufe sich nicht beeinflussen. Belegt durch `migrate.test.ts` (ein Test, der den Fall ohne Variable in einem Kindprozess ausführt, erwartet Exit-Code ≠ 0)
  und durch Durchsicht auf `skip`.
- **AC-6:** `npm run typecheck` (`tsc --noEmit` mit `strict`, `erasableSyntaxOnly`, `verbatimModuleSyntax`, `allowImportingTsExtensions`) läuft in `server/` ohne Fehler; der Code verwendet nur Syntax, die Node 26 per Typ-Entfernung ausführt
  (kein `enum`, kein `namespace`, keine Parameter-Properties), kein `any` ohne Begründung, kein `catch`, der den Fehler verschluckt. Belegt durch den Typprüflauf und `npm test` (Node führt die `.ts`-Dateien direkt aus, ohne Build-Schritt).
- **AC-7:** `./server/scripts/test-local.sh` startet ein Wegwerf-Postgres (temporärer Datenordner, freier Port, kein Eingriff in vorhandene Postgres-Dienste), setzt `DATABASE_URL`, führt Typprüfung und Tests aus, gibt deren Exit-Code zurück
  und räumt in jedem Fall auf (Server gestoppt, Datenordner gelöscht, auch bei roten Tests). Belegt durch einen Lauf grün und einen Lauf mit absichtlich rotem Test, jeweils danach `pg_ctl`-Prozess und Ordner weg.
- **AC-8:** `.github/workflows/server.yml` läuft auf `ubuntu-latest` mit Dienstcontainer `postgres:18` (`pg_isready`-Healthcheck, `DATABASE_URL` auf `127.0.0.1:5432`), `actions/setup-node` mit Node 26, `npm ci`, `npm run typecheck`, `npm test`.
  Pfadfilter `server/**` und der Workflow selbst; `main` hat keinen Branchschutz, ein nicht gestarteter Lauf blockiert also keinen PR. Belegt durch einen grünen Lauf des Workflows auf dem PR und
  `python3 -m unittest discover -s scripts` (insbesondere `test_ci_xcode27.py` bleibt grün, es prüft nur `ci.yml` und `speech-stress.yml`).
- **AC-9:** `server/package-lock.json` ist eingecheckt und passt zu `package.json` (`npm ci` läuft ohne Änderung); `package.json` hat `"type": "module"`, `engines.node` `>=26` und exakt die Abhängigkeiten aus der Tabelle oben.
  `.gitignore` enthält `node_modules/`; `git status` zeigt nach `npm ci` keine unversionierten Dateien in `server/`. Belegt durch `npm ci`, `git status` und Durchsicht der `package.json`.
- **AC-10:** `CLAUDE.md` nennt `server/` unter „Where things live“ (Zweck, Läufer, Regel „Schema nur als nummerierte Migrationen, ab dem Betrieb nur ergänzen“) und die Befehle (`./server/scripts/test-local.sh`, `npm run typecheck`, `npm test`) unter „Build“.
  Die App, das Xcode-Projekt (`project.yml`) und die bestehenden CI-Jobs sind unverändert. Belegt durch Diff-Durchsicht: Die Dateiliste des PR enthält außer den unter Scope genannten nichts.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/package.json` (+ `server/package-lock.json`, generiert) | CREATE | `type: module`, `engines.node >=26`, Skripte `typecheck`, `test` (`node --test`), `test:local` |
| `server/tsconfig.json` | CREATE | `strict`, `noEmit`, `erasableSyntaxOnly`, `verbatimModuleSyntax`, `allowImportingTsExtensions` |
| `server/src/migrate.ts` | CREATE | Migrationsläufer (siehe Source) |
| `server/test/migrate.test.ts` (+ Test-Migrationsordner unter `server/test/fixtures/`) | CREATE | Tests AC-1 bis AC-5 gegen echtes Postgres |
| `server/scripts/test-local.sh` | CREATE | Wegwerf-Postgres, Tests, Aufräumen |
| `.github/workflows/server.yml` | CREATE | eigener Workflow, Linux, Postgres-Dienst |
| `.gitignore` | MODIFY | `node_modules/` |
| `CLAUDE.md` | MODIFY | `server/` unter „Where things live“, Befehle unter „Build“ |

### Estimated Changes

- Files: 8 (Lockfile generiert, Fixtures klein)
- LoC: +170/-0 (Läufer ~50, Test ~70, Skript ~25, Workflow ~25, Rest Einzeiler/Doku); jede Funktion ≤ 50 Zeilen
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Änderung an `project.yml`; ein `./scripts/sim.sh generate` ist nicht nötig.

Bei Überschreitung von 250 Zeilen: stoppen und nachfragen.

## Test Plan

### Automated Tests (TDD RED)

RED: `server/test/migrate.test.ts` wird zuerst geschrieben; ohne `server/src/migrate.ts` schlägt der Import fehl. GREEN nach der Umsetzung.

- [ ] Test 1 (AC-1): GIVEN drei Migrationsdateien in unsortierter Anlage WHEN `migrate` läuft THEN werden sie in Nummernfolge angewandt und in dieser Folge zurückgegeben.
- [ ] Test 2 (AC-2): GIVEN ein bereits migrierter Stand WHEN `migrate` erneut läuft THEN wird nichts angewandt; mit einer neuen vierten Datei nur diese.
- [ ] Test 3 (AC-3): GIVEN eine Migration mit gültiger und dann fehlerhafter Anweisung WHEN `migrate` läuft THEN wird zurückgerollt, nichts gemerkt und der Postgres-Fehler weitergeworfen; frühere Migrationen bleiben.
- [ ] Test 4 (AC-4): GIVEN eine Lücke bzw. eine doppelte Nummer WHEN `migrate` läuft THEN Ablehnung mit klarer Meldung, bevor etwas angewandt wird.
- [ ] Test 5 (AC-5): GIVEN keine `DATABASE_URL` WHEN die Tests laufen THEN schlagen sie fehl, statt zu überspringen.

Läufe: `./server/scripts/test-local.sh` (lokal, Gesamtkette), `npm run typecheck`, danach der Workflow `server.yml` auf dem PR. Zusätzlich `python3 -m unittest discover -s scripts` für die Workflow-Prüfungen.

**Keine UI-Tests und kein Swift-Test:** Der Schnitt ändert keine Oberfläche und keinen Ablauf in der App.

## Alternativen

- **PGlite (Postgres als WASM in Node) statt echtem Postgres.** Verworfen: eine Verbindung, andere Sperrsemantik; C3 braucht „ein Auftrag geht an genau ein Gerät“ (`FOR UPDATE SKIP LOCKED` über mehrere Verbindungen),
  das prüft nur echtes Postgres. Gekippt würde nichts Bestehendes, nur die Testannahme für C3.
- **Fertiges Migrationswerkzeug** (node-pg-migrate, Kysely, Prisma). Verworfen: mehr Abhängigkeiten für ~50 Zeilen Läufer; Prisma bringt ein eigenes Schema-Format. Kippbar, falls Migrationen später komplex werden.
- **Server-Job in `ci.yml`.** Verworfen: alle Jobs dort laufen auf `xcode-27` (macOS), `test_ci_xcode27.py` müsste aufgeweicht werden; ein eigener Linux-Workflow lässt die macOS-Jobs und ihre Prüfung unberührt.
- **Ein Schnitt C1 statt C1a/C1b.** Verworfen: Gerüst plus Schema und Vertragstests ergäben ~10 Dateien und ~280–310 LoC und sprengen die Scoping-Grenze (±250 LoC).
  C1a bleibt bei ~+170 LoC; von seinen 8 Einträgen sind das Lockfile generiert und `.gitignore` sowie `CLAUDE.md` Einzeiler bzw. Doku, tragend sind 5 neue Dateien in einem neuen, abgeschlossenen Ordner.
  Weiter zu teilen (z. B. CI-Workflow eigens) hieße einen Zwischenstand, dessen Tests nirgends automatisch laufen.

## Nicht in diesem Schnitt / Folgeschnitte

- **C1b (eigener Workflow, direkt danach):** `server/migrations/001_*.sql` (Abschrift als `jsonb` je Konto und Gerät, Aufträge mit CHECK auf die drei Arten und `version = 1`, Vergabespalten `claimed_by`/`claimed_at`,
  Ergebnisse mit `outcome`/`reason` per CHECK, `account_id` Pflicht ohne Fremdschlüssel bis C6) und Vertragstests gegen die ```json-Beispiele aus `docs/reference/claude-abschrift-vertrag.md`.
- C3 Dienstkern, C4 MCP-Werkzeuge, C5 A/B-Nachweis, C6a/C6b Anmeldung, C7 Betrieb auf Hetzner (führt `migrate` beim Start aus, Postgres-Version dort prüfen), C8 ADR-21.
- Kein HTTP-Endpunkt, keine Anmeldung, kein MCP in diesem Schnitt.

## Abnahme

Kein Pfad der Geräteliste berührt. Stufe 1: `./server/scripts/test-local.sh` grün und der Workflow `server.yml` grün auf dem PR, dazu die Skript-Tests (`unittest discover -s scripts`).
Stufe 2: Kein Simulator-Ablauf ändert sich; die App wird weder geändert noch berührt. `phase8_complete` verlangt trotzdem einen `./scripts/sim.sh test-proof CaptureSmokeTests`-Beleg
(wie in Schnitt 1), der vor dem Abschluss aus einem echten Lauf auf dem aktuellen Stand erzeugt wird und nie von Hand gesetzt wird.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, Workflow `server.yml` grün, Skript-Tests grün
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #613 kommentiert (Stand C1a, Folgeschnitt C1b), Board-Karte aktuell

## Changelog

- 2026-10-31: Initial spec created (Schnitt C1a)
