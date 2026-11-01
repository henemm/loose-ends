---
entity_id: spike-613-schnitt-c1b-schema
type: feature
created: 2026-10-31
updated: 2026-11-01
status: draft
workflow: spike-613-c1b-schema
---

# Spec: Erste Server-Migration für Abschrift, Aufträge und Ergebnisse, Schnitt C1b (#613, Weg B „Fenster für Claude“)

## Approval

- [ ] Approved

## GitHub Issue

#613 (Spike, Epic #612). Schnitt C1b; das Issue bleibt offen (`Refs #613`, nie `Closes #613`).
Vorgänger: C1a (`docs/specs/spike-613-schnitt-c1a-server-geruest.md`, PR #785), Vertrag v1 (`docs/reference/claude-abschrift-vertrag.md`, App-Seite PR #779).

## Purpose

Der Dienst für Claude braucht ein Schema, bevor Dienstlogik hineinkommt. Dieser Schnitt legt die erste Migration `server/migrations/001_claude_schema.sql` an:
drei Tabellen für die Abschrift (`transcripts`), die Aufträge (`orders`) und die Ergebnisse (`order_results`), genau nach Vertrag v1.
Das Dokument (`jsonb`) ist die einzige Quelle; Kennung, Art und Ergebnisfelder werden daraus erzeugt, so dass es keine doppelte Wahrheit zwischen Spalte und Dokument gibt.
Die Datenschutzgrenze des Vertrags (keine Rohtexte, keine Notizen, keine Anhänge, keine Revisionen in der Abschrift, #625) hält die Datenbank selbst per CHECK ein.
Tests lesen die drei ```json-Beispiele zur Laufzeit aus dem Vertragstext und prüfen sie gegen das Schema in echtem Postgres; weicht der Vertrag ab, schlägt der Servertest fehl.
Keine Dienstlogik, kein HTTP, keine Anmeldung, kein MCP. In der App ändert sich nichts.

**Regeln vor Modell:** Alles ist deterministisch (SQL, CHECK, jsonpath); kein Sprachmodell beteiligt. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Keine neue Produktentscheidung: Weg B (iCloud bleibt der Abgleich, eigener Dienst nur für Abschrift und Auftragsweg) ist in #612 entschieden und wird mit ADR-21 in C8 festgehalten;
  die Datenschutzgrenze der Abschrift (neue Felder nur mit Freigabe) ist in #625 entschieden. Dieser Schnitt setzt beide nur im Schema um.

## Source

**File:** `server/migrations/001_claude_schema.sql` (Hauptdatei; übrige Dateien in der Tabelle unter Scope)
**Identifier:** Tabellen `transcripts`, `orders`, `order_results`

Schema (Variante A der Analyse in allen Zeilen; PG-13-tauglich, nichts aus PG 18 nötig):

- `transcripts`: `account_id text PRIMARY KEY` (eine Zeile je Konto, keine Historie); `doc jsonb NOT NULL`;
  `generated_at timestamptz NOT NULL` mit CHECK `generated_at = (doc->>'generatedAt')::timestamptz`
  (`timestamptz` aus Text ist nicht `immutable`, deshalb keine erzeugte Spalte); dazu CHECK, dass `doc.generatedAt` vorhanden ist und mit einer Zeitzone endet
  (`Z` oder `±hh:mm`, per `jsonb_path_exists` und `like_regex`), damit der Vergleich nicht von der Zeitzone der Sitzung abhängt (Adversary-Runde 1, F003); `received_at timestamptz NOT NULL DEFAULT now()`.
  CHECKs auf `doc`: `doc @> '{"version":1}'`; Schlüssel oben nur `version`, `generatedAt`, `nowCount`, `now`, `tasks`; Schlüssel je Aufgabe nur
  `id`, `title`, `status`, `dueDate`, `dueHasTime`, `contexts`, `project`, `nextRank`, `isKnaeuel` (beide per `jsonb_path_exists` mit `keyvalue()` und `like_regex`;
  ein Unterabfrage-CHECK ist in Postgres nicht erlaubt, ein Nicht-Objekt in `tasks` bricht `keyvalue()` mit einem Fehler der Klasse 2203x ab, wird also ebenfalls abgewiesen).
- `orders`: `doc jsonb NOT NULL`; `id uuid GENERATED ALWAYS AS ((doc->>'id')::uuid) STORED PRIMARY KEY`;
  `kind text GENERATED ALWAYS AS (doc->>'kind') STORED NOT NULL` (ein Auftrag ohne Art wäre nie ausführbar, F001) mit CHECK `kind IN ('capture','complete','setDue')`; `account_id text NOT NULL` (ohne Fremdschlüssel bis C6);
  CHECK `doc @> '{"version":1}'`; `created_at timestamptz NOT NULL DEFAULT now()`; `claimed_by text`, `claimed_at timestamptz` mit CHECK „beide gesetzt oder beide leer“
  (die Vergabe selbst, `FOR UPDATE SKIP LOCKED`, ist C3).
- `order_results`: `doc jsonb NOT NULL`; `order_id uuid GENERATED ALWAYS AS ((doc->>'orderID')::uuid) STORED PRIMARY KEY REFERENCES orders(id)` (höchstens ein Ergebnis je Auftrag, nur zu einem bestehenden);
  `outcome text GENERATED ALWAYS AS (doc->>'outcome') STORED NOT NULL` (ein Ergebnis ohne Ausgang belegte den Auftrag, F002) mit CHECK `outcome IN ('done','rejected')`;
  `reason text GENERATED ALWAYS AS (doc->>'reason') STORED` mit CHECK `reason IN ('invalid','missing','stale')` und `(outcome = 'rejected') = (reason IS NOT NULL)`;
  `task_id uuid GENERATED ALWAYS AS ((doc->>'taskID')::uuid) STORED` (optional); `reported_by text NOT NULL`; `reported_at timestamptz NOT NULL DEFAULT now()`.
  Das Konto steht über den Auftrag, keine eigene `account_id`-Spalte.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `migrate` / `loadMigrations` aus `server/src/migrate.ts` (C1a) | Läufer, wendet `001` genau einmal an |
| Vertrag v1 `docs/reference/claude-abschrift-vertrag.md` | Quelle der Beispiele und der erlaubten Schlüssel; wird vom Test zur Laufzeit gelesen |
| Postgres 18 (lokal Wegwerf-Instanz, CI Dienstcontainer `postgres:18`) | Schema selbst PG-13-tauglich |
| `pg` 8.23.1, `node:test` | bestehend aus C1a; **keine neuen Abhängigkeiten** |

## Acceptance Criteria

- **AC-1:** `migrate(pool, "server/migrations")` auf einem frischen Schema wendet genau `001_claude_schema.sql` an und legt die Tabellen `transcripts`, `orders` und `order_results` an;
  `schema_migrations` hat danach eine Zeile; ein zweiter Lauf liefert eine leere Liste und ändert nichts. Belegt durch `server/test/schema.test.ts` (`to_regclass` je Tabelle, zweiter Lauf `[]`).
- **AC-2:** Die drei Vertragsbeispiele (Abschrift, Auftrag `complete`, Ergebnis `rejected/stale`) werden zur Laufzeit aus den ```json-Blöcken von `docs/reference/claude-abschrift-vertrag.md` gelesen, nicht abgeschrieben,
  in der Vertragsreihenfolge Abschrift, Auftrag, Ergebnis, und vom Schema angenommen (Abschrift mit `generated_at` = `generatedAt`, Auftrag mit `account_id`, Ergebnis nach dem Auftrag mit `reported_by`).
  Der Test schlägt fehl, wenn der Vertrag nicht genau drei ```json-Blöcke enthält. Belegt durch `schema.test.ts`.
- **AC-3:** `transcripts` weist Abweichungen mit dem erwarteten SQLSTATE ab (eine Abweichungstabelle in `schema.test.ts`, je Zeile eine Änderung am Vertragsbeispiel):
  `rawText` oder `note` an einer Aufgabe → 23514; fremder Schlüssel oben (z. B. `revisions`) → 23514; `version` fehlt → 23514; `version` als `"1"` → 23514;
  `generated_at` ≠ `doc.generatedAt` → 23514; `generatedAt` fehlt → 23514; `generatedAt` ohne Zeitzone (`2026-03-12T09:00:00`, `generated_at` mit demselben Text) → 23514; `tasks` enthält ein Nicht-Objekt (`"tasks":["Text"]`) → Fehler der Klasse 2203x (abgewiesen, ohne 23514 zu behaupten); `account_id` NULL → 23502;
  eine zweite Zeile desselben Kontos → 23505 (das Überschreiben bei neuerem `generatedAt` ist C3).
- **AC-4:** `orders` weist Abweichungen mit dem erwarteten SQLSTATE ab: `version` fehlt → 23514; `version` als `"1"` → 23514; `kind` unbekannt (`"delete"`) → 23514; `kind` fehlt → 23502;
  doppelte `id` → 23505; fehlende `id` → 23502; ungültige UUID als `id` → 22P02; `account_id` NULL → 23502;
  `claimed_by` ohne `claimed_at` → 23514 und `claimed_at` ohne `claimed_by` → 23514; beide gesetzt wird angenommen. Alle drei Arten (`capture`, `complete`, `setDue`) werden angenommen. Belegt durch `schema.test.ts`.
- **AC-5:** `order_results` weist Abweichungen mit dem erwarteten SQLSTATE ab: Ergebnis zu unbekanntem Auftrag → 23503; zweites Ergebnis zum selben Auftrag → 23505; fehlende `orderID` → 23502;
  `rejected` ohne `reason` → 23514; `done` mit `reason` → 23514; unbekannter `reason` → 23514; unbekannter `outcome` → 23514; fehlender `outcome` → 23502; `reported_by` NULL → 23502.
  Ein `done` ohne `taskID` (z. B. nach `capture`) wird angenommen. Belegt durch `schema.test.ts`.
- **AC-6:** Kennungen behalten im Dokument die Großschreibung des Vertrags; die erzeugten `uuid`-Spalten liefern Kleinbuchstaben; ein Abgleich per `id = '…'::uuid` findet den Auftrag unabhängig von der Schreibweise.
  Als bekannte Grenze wird festgehalten (eigener Test mit Kommentar): `"version": 1.0` wird angenommen, weil `jsonb`-Zahlen numerisch vergleichen; das ist harmlos (die App dekodiert `1.0` als 1) und kein Fehler des Schemas.
  Belegt durch `schema.test.ts`.
- **AC-7:** `freshPool` samt `DATABASE_URL`-Pflicht (fehlt die Variable, schlägt der Lauf fehl, kein `skip`) liegt in `server/test/db.ts` und wird von `migrate.test.ts` und `schema.test.ts` benutzt, nicht kopiert.
  `migrate.test.ts` ändert nur den Import: alle bisherigen Tests (AC-1 bis AC-5 aus C1a, einschließlich des Kindprozess-Tests ohne `DATABASE_URL`) bleiben ohne Änderung des Verhaltens grün.
  Belegt durch `npm test` und Diff-Durchsicht von `migrate.test.ts`.
- **AC-8:** `node --test` wertet `server/test/db.ts` nicht als Testdatei: Die Testauswahl in `server/package.json` ist `test/*.test.ts`, und `npm test` meldet genau die Tests aus `migrate.test.ts` und `schema.test.ts`, keinen leeren Lauf für `db.ts`.
  Belegt durch die Ausgabe von `npm test` (Dateiliste bzw. Testzahl).
- **AC-9:** `.github/workflows/server.yml` löst bei `pull_request` und `push` auch bei Änderungen an `docs/reference/claude-abschrift-vertrag.md` aus (Pfadfilter beider Auslöser ergänzt), weil der Servertest den Vertragstext liest.
  Der Vertrag nennt im Satz zu den wörtlichen Beispielen auch `server/test/schema.test.ts`. Belegt durch Diff-Durchsicht und den CI-Lauf auf dem PR; `python3 -m unittest discover -s scripts` bleibt grün.
- **AC-10:** `./server/scripts/test-local.sh` ist grün (Typprüfung `npm run typecheck` ohne Fehler, alle Tests gegen das Wegwerf-Postgres) und räumt auf; der Workflow `server.yml` ist auf dem PR grün.
  Die Dateiliste des PR enthält außer den unter Scope genannten nichts: keine App-Datei, kein `project.yml`, kein CloudKit-Schema, keine `CLAUDE.md`-Änderung. Belegt durch beide Läufe und Diff-Durchsicht.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/migrations/001_claude_schema.sql` | CREATE | drei Tabellen wie unter Source, ~60 Zeilen |
| `server/test/schema.test.ts` | CREATE | `migrate` auf den echten Ordner; Vertragsbeispiele aus dem Markdown; Abweichungstabelle je Tabelle mit SQLSTATE, ~110 Zeilen |
| `server/test/db.ts` | CREATE | `freshPool` und `DATABASE_URL`-Pflicht aus `migrate.test.ts` herausgezogen, ~25 Zeilen |
| `server/test/migrate.test.ts` | MODIFY | importiert `freshPool` statt es selbst zu definieren, −20 |
| `.github/workflows/server.yml` | MODIFY | Pfadfilter + `docs/reference/claude-abschrift-vertrag.md` (beide Auslöser), +2 |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Satz zu den wörtlichen Beispielen nennt auch den Servertest, +1 |
| `server/package.json` | MODIFY | Testmuster `test/*.test.ts` statt `test/`, ±1 (7. Datei, nur falls in RED bestätigt, dass `node --test test/` `db.ts` mitnimmt) |

### Estimated Changes

- Files: 6, mit `package.json` 7 (zwei Einzeiler)
- LoC: +~200/−~20, unter 250; jede Funktion ≤ 50 Zeilen, Testfälle als Tabelle gebündelt
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Änderung an `project.yml`; `./scripts/sim.sh generate` ist nicht nötig.

Bei Überschreitung von 250 Zeilen: stoppen und nachfragen.

## Test Plan

### Automated Tests (TDD RED)

RED: `server/test/db.ts` und `server/test/schema.test.ts` werden zuerst geschrieben; ohne `server/migrations/001_claude_schema.sql` schlägt `migrate` auf den echten Ordner bzw. jede Einfügung fehl.
In RED wird außerdem geprüft, ob `node --test test/` die Hilfsdatei `db.ts` mitzählt (AC-8). GREEN nach der Umsetzung.

- [ ] Test 1 (AC-1): GIVEN ein frisches Schema WHEN `migrate` auf `server/migrations` läuft THEN stehen drei Tabellen da; zweiter Lauf wendet nichts an.
- [ ] Test 2 (AC-2): GIVEN der Vertragstext WHEN die drei ```json-Blöcke gelesen werden THEN werden Abschrift, Auftrag und Ergebnis angenommen; ungleich drei Blöcke schlägt fehl.
- [ ] Test 3 (AC-3): GIVEN das Abschrift-Beispiel WHEN je Tabellenzeile eine Abweichung eingefügt wird THEN kommt der erwartete SQLSTATE.
- [ ] Test 4 (AC-4): GIVEN das Auftrag-Beispiel WHEN je Tabellenzeile eine Abweichung eingefügt wird THEN kommt der erwartete SQLSTATE; alle drei Arten werden angenommen.
- [ ] Test 5 (AC-5): GIVEN ein bestehender Auftrag WHEN Ergebnisse mit Abweichungen eingefügt werden THEN kommt der erwartete SQLSTATE.
- [ ] Test 6 (AC-6): GIVEN Kennungen in Großbuchstaben WHEN gespeichert und abgefragt THEN Dokument unverändert, Spalte klein; `1.0` als bekannte Grenze angenommen.
- [ ] Test 7 (AC-7, AC-8): `npm test` zeigt die bisherigen Tests von `migrate.test.ts` unverändert grün und keinen Lauf für `db.ts`.

Läufe: `./server/scripts/test-local.sh` (lokal, Gesamtkette), danach der Workflow `server.yml` auf dem PR; zusätzlich `python3 -m unittest discover -s scripts`.

**Keine UI-Tests und kein Swift-Test:** Der Schnitt ändert keine Oberfläche und keinen Ablauf in der App.

## Alternativen

- **Keine Ergebnistabelle** (Gesamtalternative): Claude liest Ergebnisse nur aus der nächsten Abschrift (die Aufgabe ist erledigt oder nicht). Spart eine Tabelle, verliert aber `stale`, `missing` und `invalid` als Antwort an Claude;
  Vertrag v1 legt das Ergebnis fest. Gekippt würde der Vertrag selbst, nicht eine ADR.
- **Abschrift je (Konto, Gerät)** statt je Konto: Die Abschrift trägt keine Gerätekennung, die Quelle gäbe es erst mit der Anmeldung (C6); alle Geräte rechnen aus demselben iCloud-Stand. Eine Spalte ohne Quelle, verworfen.
- **Abschrift mit Historie** (jede Lieferung eine Zeile): hilft beim Nachvollziehen von `stale`, kostet aber Speicher und widerspricht „so wenig wie möglich“ (Datenschutz); `stale` erklärt die App selbst. Verworfen.
- **Aufträge und Ergebnisse in einer Tabelle** (Ergebnisspalten am Auftrag): weniger Tabellen, aber „höchstens ein Ergebnis“ und „nur zu bestehendem Auftrag“ werden zu bedingten CHECKs. Eigene Tabelle mit PK = FK erzwingt beides ohne Bedingung.
- **Spalten vom Dienst gesetzt, per CHECK ans Dokument gebunden** statt erzeugter Spalten: braucht je Feld einen Bindungs-CHECK und lässt eine doppelte Wahrheit zu. Nur `generated_at` geht diesen Weg, weil `timestamptz` aus Text nicht `immutable` ist.
- **Keine Datenschutzprüfung im Schema** (der App vertrauen): Version 2 bräuchte dann keine Migration, aber ein Fehler in der App könnte Rohtext hochladen. Verworfen; neue Felder nur mit Freigabe (#625) ist gewollt, die Migration der Preis.
- **Volle JSON-Schema-Prüfung in Postgres** (`pg_jsonschema`): neue Abhängigkeit, kein eingebautes JSON-Schema in PG 18. Verworfen; die Formprüfung des Auftrags gehört in C3 (Annehmen), hier nur `version`, `kind`, `id`.

## Nicht in diesem Schnitt / Folgeschnitte

- C3 Dienstkern: Annehmen mit Formprüfung, Vergabe (`FOR UPDATE SKIP LOCKED`), Abschrift nur bei neuerem `generatedAt` überschreiben, `setDue`-Status prüfen.
- C4 MCP-Werkzeuge (lesen `transcripts`), C5 A/B-Nachweis, C6 Anmeldung und Konto-Tabelle (Fremdschlüssel auf `account_id` additiv), C7 Betrieb auf Hetzner (`migrate` beim Start, Postgres-Version dort prüfen), C8 ADR-21.
- Ab C7 wird Schema nur noch ergänzt; bis dahin darf `001` noch geändert werden, weil keine Datenbank außer den Testläufen sie hat.

## Abnahme

Kein Pfad der Geräteliste berührt. Stufe 1: `./server/scripts/test-local.sh` grün und der Workflow `server.yml` grün auf dem PR, dazu die Skript-Tests (`unittest discover -s scripts`).
Stufe 2: Kein Simulator-Ablauf ändert sich; die App wird weder geändert noch berührt. `phase8_complete` verlangt trotzdem einen `./scripts/sim.sh test-proof CaptureSmokeTests`-Beleg
(wie in C1a), der vor dem Abschluss aus einem echten Lauf auf dem aktuellen Stand erzeugt wird und nie von Hand gesetzt wird.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, Workflow `server.yml` grün, Skript-Tests grün
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #613 kommentiert (Stand C1b, Folgeschnitt C3), Board-Karte aktuell

## Changelog

- 2026-10-31: Initial spec created (Schnitt C1b)
- 2026-11-01: Nach Adversary-Runde 1 (AMBIGUOUS, F001–F003) ergänzt: `kind` und `outcome` NOT NULL, `generatedAt` Pflicht mit Zeitzone; AC-3, AC-4, AC-5 um je die Abweisung erweitert (Override Henning)
