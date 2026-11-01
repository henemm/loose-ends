# Adversary Dialog — spike-613-c1b-schema
Spec: docs/specs/spike-613-schnitt-c1b-schema.md
Datum: 2026-11-01 08:18

## Checkliste
- [x] **AC-1:** `migrate(pool, "server/migrations")` auf einem frischen Schema wendet genau `001_claude_schema.sql` an und legt die Tabellen `transcripts`, `orders` und `order_results` an; `schema_migrations` hat danach eine Zeile; ein zweiter Lauf liefert eine leere Liste und ändert nichts. Belegt durch `server/test/schema.test.ts` (`to_regclass` je Tabelle, zweiter Lauf `[]`).
- [x] **AC-2:** Die drei Vertragsbeispiele (Abschrift, Auftrag `complete`, Ergebnis `rejected/stale`) werden zur Laufzeit aus den ```json-Blöcken von `docs/reference/claude-abschrift-vertrag.md` gelesen, nicht abgeschrieben, in der Vertragsreihenfolge Abschrift, Auftrag, Ergebnis, und vom Schema angenommen (Abschrift mit `generated_at` = `generatedAt`, Auftrag mit `account_id`, Ergebnis nach dem Auftrag mit `reported_by`). Der Test schlägt fehl, wenn der Vertrag nicht genau drei ```json-Blöcke enthält. Belegt durch `schema.test.ts`.
- [x] **AC-3:** `transcripts` weist Abweichungen mit dem erwarteten SQLSTATE ab (eine Abweichungstabelle in `schema.test.ts`, je Zeile eine Änderung am Vertragsbeispiel): `rawText` oder `note` an einer Aufgabe → 23514; fremder Schlüssel oben (z. B. `revisions`) → 23514; `version` fehlt → 23514; `version` als `"1"` → 23514; `generated_at` ≠ `doc.generatedAt` → 23514; `generatedAt` fehlt → 23514; `generatedAt` ohne Zeitzone (`2026-03-12T09:00:00`, `generated_at` mit demselben Text) → 23514; `tasks` enthält ein Nicht-Objekt (`"tasks":["Text"]`) → Fehler der Klasse 2203x (abgewiesen, ohne 23514 zu behaupten); `account_id` NULL → 23502; eine zweite Zeile desselben Kontos → 23505 (das Überschreiben bei neuerem `generatedAt` ist C3).
- [x] **AC-4:** `orders` weist Abweichungen mit dem erwarteten SQLSTATE ab: `version` fehlt → 23514; `version` als `"1"` → 23514; `kind` unbekannt (`"delete"`) → 23514; `kind` fehlt → 23502; doppelte `id` → 23505; fehlende `id` → 23502; ungültige UUID als `id` → 22P02; `account_id` NULL → 23502; `claimed_by` ohne `claimed_at` → 23514 und `claimed_at` ohne `claimed_by` → 23514; beide gesetzt wird angenommen. Alle drei Arten (`capture`, `complete`, `setDue`) werden angenommen. Belegt durch `schema.test.ts`.
- [x] **AC-5:** `order_results` weist Abweichungen mit dem erwarteten SQLSTATE ab: Ergebnis zu unbekanntem Auftrag → 23503; zweites Ergebnis zum selben Auftrag → 23505; fehlende `orderID` → 23502; `rejected` ohne `reason` → 23514; `done` mit `reason` → 23514; unbekannter `reason` → 23514; unbekannter `outcome` → 23514; fehlender `outcome` → 23502; `reported_by` NULL → 23502. Ein `done` ohne `taskID` (z. B. nach `capture`) wird angenommen. Belegt durch `schema.test.ts`.
- [x] **AC-6:** Kennungen behalten im Dokument die Großschreibung des Vertrags; die erzeugten `uuid`-Spalten liefern Kleinbuchstaben; ein Abgleich per `id = '…'::uuid` findet den Auftrag unabhängig von der Schreibweise. Als bekannte Grenze wird festgehalten (eigener Test mit Kommentar): `"version": 1.0` wird angenommen, weil `jsonb`-Zahlen numerisch vergleichen; das ist harmlos (die App dekodiert `1.0` als 1) und kein Fehler des Schemas. Belegt durch `schema.test.ts`.
- [x] **AC-7:** `freshPool` samt `DATABASE_URL`-Pflicht (fehlt die Variable, schlägt der Lauf fehl, kein `skip`) liegt in `server/test/db.ts` und wird von `migrate.test.ts` und `schema.test.ts` benutzt, nicht kopiert. `migrate.test.ts` ändert nur den Import: alle bisherigen Tests (AC-1 bis AC-5 aus C1a, einschließlich des Kindprozess-Tests ohne `DATABASE_URL`) bleiben ohne Änderung des Verhaltens grün. Belegt durch `npm test` und Diff-Durchsicht von `migrate.test.ts`.
- [x] **AC-8:** `node --test` wertet `server/test/db.ts` nicht als Testdatei: Die Testauswahl in `server/package.json` ist `test/*.test.ts`, und `npm test` meldet genau die Tests aus `migrate.test.ts` und `schema.test.ts`, keinen leeren Lauf für `db.ts`. Belegt durch die Ausgabe von `npm test` (Dateiliste bzw. Testzahl).
- [x] **AC-9:** `.github/workflows/server.yml` löst bei `pull_request` und `push` auch bei Änderungen an `docs/reference/claude-abschrift-vertrag.md` aus (Pfadfilter beider Auslöser ergänzt), weil der Servertest den Vertragstext liest. Der Vertrag nennt im Satz zu den wörtlichen Beispielen auch `server/test/schema.test.ts`. Belegt durch Diff-Durchsicht und den CI-Lauf auf dem PR; `python3 -m unittest discover -s scripts` bleibt grün.
- [x] **AC-10:** `./server/scripts/test-local.sh` ist grün (Typprüfung `npm run typecheck` ohne Fehler, alle Tests gegen das Wegwerf-Postgres) und räumt auf; der Workflow `server.yml` ist auf dem PR grün. Die Dateiliste des PR enthält außer den unter Scope genannten nichts: keine App-Datei, kein `project.yml`, kein CloudKit-Schema, keine `CLAUDE.md`-Änderung. Belegt durch beide Läufe und Diff-Durchsicht.

## Dialog

### Runde 1
**Adversary:** Frische Läufe. `./server/scripts/test-local.sh`: typecheck ohne Fehler, 16 von 16 Tests grün, 0 übersprungen (docs/artifacts/spike-613-c1b-schema/adversary-test-output.txt). `python3 -m unittest discover -s scripts`: 453 Tests, OK (docs/artifacts/spike-613-c1b-schema/adversary-unittest-output.txt). Angriff auf F004 in eigener Wegwerf-Postgres (Port 54399, danach gestoppt und gelöscht), 19 Fälle direkt gegen die `transcripts`-Constraints:
- angenommen: `Z`, `+01:00`, `-05:00`, Bruchteile `.123456Z` (alle mit passendem `generated_at`).
- 23514: `generatedAt` als Array, verschachteltes Array, `null`, fehlend, ohne Zeitzone, `rawText` an einer Aufgabe, `revisions` oben.
- abgewiesen mit 22007 (Cast scheitert in der ersten CHECK, also ebenfalls nicht angenommen): Objekt, Zahl, Array mit zwei Elementen, leeres Array, `"...Z junk"`.
- 2203C: `tasks:["Text"]` und `tasks:null` (Klasse 2203x, wie AC-3 verlangt).
Der F004-Fix wirkt: `jsonb_typeof(doc->'generatedAt') = 'string'` (server/migrations/001_claude_schema.sql:15) schließt das einelementige Array. Die RED/GREEN-Belege passen dazu (test-red-f004: "Missing expected rejection: generatedAt als Array"; test-green-f004: 16/16). F001 bis F003 aus Runde 1 des Vorgängerlaufs bleiben geschlossen (Großschreibung/uuid AC-6, Zeitzone AC-3, 2203x bei Nicht-Objekt in tasks, alle durch die Tests und die Direktfälle bestätigt). Die drei Vertragsbeispiele werden angenommen (Test AC-2).
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Zweiter Angriff auf Lücken außerhalb von `generatedAt`. Fund: Ein Objekt `now` mit fremdem Inhalt oder eine `now`-Eintragsliste mit `rawText` wird angenommen (Fall `nowRaw`: `"now":[{"rawText":"x"}]` ACCEPTED). Der Vertrag (docs/reference/claude-abschrift-vertrag.md:23) definiert `now` als Kennungen, die Spec (AC-3) verlangt die Schlüsselprüfung aber ausdrücklich nur oben und je Aufgabe in `tasks`. Das ist also keine Spec-Verletzung, sondern eine dokumentierte Grenze des Datenschutz-Zauns; als LOW vermerkt (F005). Weiter geprüft: Test-Infrastruktur. `freshPool` samt `DATABASE_URL`-Pflicht liegt in server/test/db.ts:11 und wird von server/test/migrate.test.ts:10 importiert (keine Kopie); der Kindprozess-Test ohne `DATABASE_URL` ist grün (AC-5 C1a). `server/package.json:10` wählt `test/*.test.ts`, die Ausgabe zeigt 16 Tests aus zwei Dateien, kein Lauf für db.ts. `.github/workflows/server.yml:9` und `:15` ergänzen den Vertragspfad für `pull_request` und `push`; der Vertrag nennt `server/test/schema.test.ts` (docs/reference/claude-abschrift-vertrag.md:8). Regression: TranscriptCodec (Shared/Services/TranscriptCodec.swift:13) ist unverändert, die Schlüssel `version`, `generatedAt`, `nowCount`, `now`, `tasks` stimmen mit dem Zaun überein. Die Testtabelle enthält die neue Zeile (server/test/schema.test.ts:93). Dateiliste der Änderung: nur server/, docs/, .github/workflows/server.yml, keine App-Datei, kein project.yml, kein CloudKit-Schema, keine CLAUDE.md. Offen und bekannt, kein Defekt: AC-9/AC-10 Teil „CI-Lauf auf dem PR“, solange es keinen PR gibt.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Findings
Finding:
  ID: F004
  Severity: HIGH
  Category: edge_case
  Code reference: server/migrations/001_claude_schema.sql:15
  Description: generatedAt als einelementiges Array wurde angenommen; jetzt mit jsonb_typeof = 'string' ausgeschlossen. Neu geprüft: Array, verschachtelt, Objekt, Zahl, null, fehlend alle abgewiesen.
  Spec requirement: AC-3 — generatedAt ohne Zeitzone/ungültig abweisen
  Conflict: keiner mehr, Status GESCHLOSSEN
  Remediation: keine

Finding:
  ID: F005
  Severity: LOW
  Category: anti_pattern
  Code reference: server/migrations/001_claude_schema.sql:20
  Description: Der Schlüsselzaun prüft nur oben und je Aufgabe in tasks; Inhalt von now bleibt ungeprüft ("now":[{"rawText":"x"}] wird angenommen).
  Spec requirement: AC-3 — Schlüssel oben und je Aufgabe (nicht in now)
  Conflict: kein Spec-Konflikt; Datenschutz-Zaun hat eine dokumentierbare Lücke, die in C3 (Aufnahme-Endpunkt) zu schließen ist
  Remediation: C3 validiert now als Objekt mit Kennungen, oder CHECK auf Typ der Werte

## Bestätigungen
Confirmation:
  AC: AC-1
  Code reference: server/test/schema.test.ts:93
  Evidence: Test "AC-1: the real migrations folder applies 001 once and creates the three tables" grün
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: docs/reference/claude-abschrift-vertrag.md:8
  Evidence: Drei Vertragsbeispiele zur Laufzeit gelesen und angenommen, Test AC-2 grün
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/migrations/001_claude_schema.sql:15
  Evidence: 19 Direktfälle und Tabellentest grün, SQLSTATEs wie in der Spec
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/migrations/001_claude_schema.sql:36
  Evidence: Test AC-4 orders grün, alle drei Arten angenommen
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/migrations/001_claude_schema.sql:50
  Evidence: Test AC-5 order_results grün, Primary Key = Foreign Key
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/migrations/001_claude_schema.sql:37
  Evidence: beide AC-6-Tests grün (Großschreibung, uuid klein, 1.0 als bekannte Grenze)
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/test/db.ts:11
  Evidence: freshPool zentral, migrate.test.ts:10 importiert nur; 9 migrate-Tests grün
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/package.json:10
  Evidence: Auswahl test/*.test.ts, 16 Tests, kein db.ts-Lauf
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: .github/workflows/server.yml:9
  Evidence: Vertragspfad in beiden Auslösern; unittest 453 OK; CI-Lauf auf dem PR offen (kein PR, bekannt)
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/test/migrate.test.ts:10
  Evidence: test-local.sh grün, Aufräumen ok, Dateiliste ohne App-Dateien; CI auf PR offen (bekannt)
  Status: CONFIRMED

Confirmation:
  AC: Privacy/Regression
  Code reference: Shared/Services/TranscriptCodec.swift:13
  Evidence: Codec-Schlüssel unverändert und deckungsgleich mit Zaun
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 16 passed, 0 failed, 0 übersprungen (server); 453 passed (scripts)

## Geprüfte Dateien

- sha256:3bfab5d3e214e45cc29164595d9d3610e9695b3055f8f961d8779a85931ba73b  .github/workflows/server.yml
- sha256:8e6898f6f9193dbcda9bb13b3b37e6d46a4b8ed6d2af3ef36f43fc2decdc80b8  Shared/Services/TranscriptCodec.swift
- sha256:0d38398683ad7f0b122a0863cad90306d9f6530285f26a0c90cc63cc3f0e9ed5  docs/reference/claude-abschrift-vertrag.md
- sha256:4bec8caef895e9e0e5979bdbe31177237574d1084ccd81da097e979e7c085e6a  server/migrations/001_claude_schema.sql
- sha256:ef2bc1acb7cb27d3dbdd5ff3c5caf8143a742710c2f05f29be96b8ced86f1f1f  server/package.json
- sha256:40281a1aed6430c433b7ebcec2561f29459dba1914d2132d1cc010c2b18b5d5a  server/test/db.ts
- sha256:29bc4c47a9e1317c8cdb81ec4c1ebb0de39b862629b63dc12f8ca06744bd9f8f  server/test/migrate.test.ts
- sha256:7fafebf17c993e352491f665c6f0aee09f9a86d8301faf2aac54c2286e53c11b  server/test/schema.test.ts

## Prüfbasis

- base: fe1097a1514ab02599f485582004973f9779c097
- blob:7af0e18c36dc0da7ebdc77db1915bca4e1adb584  .github/workflows/server.yml
- blob:9ee5ccfc0057a00dbaa52b8c71527e5d36aaa4eb  Shared/Services/TranscriptCodec.swift
- blob:29d170353f3c6982341825f69034fe6911a63945  docs/reference/claude-abschrift-vertrag.md
- blob:acb202e7e7ec7d4a90a7288b5214cd7897c6bfba  server/migrations/001_claude_schema.sql
- blob:39fa6d49b407ceb440026f84d0fdef384d27c511  server/package.json
- blob:d745feabf6ec0724ad7ebdb89673a74ae86e65e1  server/test/db.ts
- blob:4e75f13b1102eb4b84ea444deba20ef6a31b23d2  server/test/migrate.test.ts
- blob:816bdd57cadebb01fd0e61bb2d9f5d9fd48f25c9  server/test/schema.test.ts
