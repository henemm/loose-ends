# Adversary Dialog — spike-613-c1b-schema
Spec: docs/specs/spike-613-schnitt-c1b-schema.md
Datum: 2026-11-01 00:06

## Checkliste
- [x] **AC-1:** `migrate(pool, "server/migrations")` auf einem frischen Schema wendet genau `001_claude_schema.sql` an und legt die Tabellen `transcripts`, `orders` und `order_results` an; `schema_migrations` hat danach eine Zeile; ein zweiter Lauf liefert eine leere Liste und ändert nichts. Belegt durch `server/test/schema.test.ts` (`to_regclass` je Tabelle, zweiter Lauf `[]`).
- [x] **AC-2:** Die drei Vertragsbeispiele (Abschrift, Auftrag `complete`, Ergebnis `rejected/stale`) werden zur Laufzeit aus den ```json-Blöcken von `docs/reference/claude-abschrift-vertrag.md` gelesen, nicht abgeschrieben, in der Vertragsreihenfolge Abschrift, Auftrag, Ergebnis, und vom Schema angenommen (Abschrift mit `generated_at` = `generatedAt`, Auftrag mit `account_id`, Ergebnis nach dem Auftrag mit `reported_by`). Der Test schlägt fehl, wenn der Vertrag nicht genau drei ```json-Blöcke enthält. Belegt durch `schema.test.ts`.
- [x] **AC-3:** `transcripts` weist Abweichungen mit dem erwarteten SQLSTATE ab (eine Abweichungstabelle in `schema.test.ts`, je Zeile eine Änderung am Vertragsbeispiel): `rawText` oder `note` an einer Aufgabe → 23514; fremder Schlüssel oben (z. B. `revisions`) → 23514; `version` fehlt → 23514; `version` als `"1"` → 23514; `generated_at` ≠ `doc.generatedAt` → 23514; `tasks` enthält ein Nicht-Objekt (`"tasks":["Text"]`) → Fehler der Klasse 2203x (abgewiesen, ohne 23514 zu behaupten); `account_id` NULL → 23502; eine zweite Zeile desselben Kontos → 23505 (das Überschreiben bei neuerem `generatedAt` ist C3).
- [x] **AC-4:** `orders` weist Abweichungen mit dem erwarteten SQLSTATE ab: `version` fehlt → 23514; `version` als `"1"` → 23514; `kind` unbekannt (`"delete"`) → 23514; doppelte `id` → 23505; fehlende `id` → 23502; ungültige UUID als `id` → 22P02; `account_id` NULL → 23502; `claimed_by` ohne `claimed_at` → 23514 und `claimed_at` ohne `claimed_by` → 23514; beide gesetzt wird angenommen. Alle drei Arten (`capture`, `complete`, `setDue`) werden angenommen. Belegt durch `schema.test.ts`.
- [x] **AC-5:** `order_results` weist Abweichungen mit dem erwarteten SQLSTATE ab: Ergebnis zu unbekanntem Auftrag → 23503; zweites Ergebnis zum selben Auftrag → 23505; fehlende `orderID` → 23502; `rejected` ohne `reason` → 23514; `done` mit `reason` → 23514; unbekannter `reason` → 23514; unbekannter `outcome` → 23514; `reported_by` NULL → 23502. Ein `done` ohne `taskID` (z. B. nach `capture`) wird angenommen. Belegt durch `schema.test.ts`.
- [x] **AC-6:** Kennungen behalten im Dokument die Großschreibung des Vertrags; die erzeugten `uuid`-Spalten liefern Kleinbuchstaben; ein Abgleich per `id = '…'::uuid` findet den Auftrag unabhängig von der Schreibweise. Als bekannte Grenze wird festgehalten (eigener Test mit Kommentar): `"version": 1.0` wird angenommen, weil `jsonb`-Zahlen numerisch vergleichen; das ist harmlos (die App dekodiert `1.0` als 1) und kein Fehler des Schemas. Belegt durch `schema.test.ts`.
- [x] **AC-7:** `freshPool` samt `DATABASE_URL`-Pflicht (fehlt die Variable, schlägt der Lauf fehl, kein `skip`) liegt in `server/test/db.ts` und wird von `migrate.test.ts` und `schema.test.ts` benutzt, nicht kopiert. `migrate.test.ts` ändert nur den Import: alle bisherigen Tests (AC-1 bis AC-5 aus C1a, einschließlich des Kindprozess-Tests ohne `DATABASE_URL`) bleiben ohne Änderung des Verhaltens grün. Belegt durch `npm test` und Diff-Durchsicht von `migrate.test.ts`.
- [x] **AC-8:** `node --test` wertet `server/test/db.ts` nicht als Testdatei: Die Testauswahl in `server/package.json` ist `test/*.test.ts`, und `npm test` meldet genau die Tests aus `migrate.test.ts` und `schema.test.ts`, keinen leeren Lauf für `db.ts`. Belegt durch die Ausgabe von `npm test` (Dateiliste bzw. Testzahl).
- [x] **AC-9:** `.github/workflows/server.yml` löst bei `pull_request` und `push` auch bei Änderungen an `docs/reference/claude-abschrift-vertrag.md` aus (Pfadfilter beider Auslöser ergänzt), weil der Servertest den Vertragstext liest. Der Vertrag nennt im Satz zu den wörtlichen Beispielen auch `server/test/schema.test.ts`. Belegt durch Diff-Durchsicht und den CI-Lauf auf dem PR; `python3 -m unittest discover -s scripts` bleibt grün.
- [x] **AC-10:** `./server/scripts/test-local.sh` ist grün (Typprüfung `npm run typecheck` ohne Fehler, alle Tests gegen das Wegwerf-Postgres) und räumt auf; der Workflow `server.yml` ist auf dem PR grün. Die Dateiliste des PR enthält außer den unter Scope genannten nichts: keine App-Datei, kein `project.yml`, kein CloudKit-Schema, keine `CLAUDE.md`-Änderung. Belegt durch beide Läufe und Diff-Durchsicht.

## Dialog

### Runde 1
**Adversary:** Testlauf frisch: `./server/scripts/test-local.sh` rc=0, Typpruefung ohne Fehler, 16 Tests, 0 fail, 0 skipped; `python3 -m unittest discover -s scripts` OK. Ausgabe: docs/artifacts/spike-613-c1b-schema/adversary-test-output.txt. Jeder Punkt wurde zusaetzlich am Code gegengelesen.
Confirmation:
  AC: AC-1
  Code reference: server/migrations/001_claude_schema.sql:8
  Evidence: drei Tabellen (Zeilen 8, 26, 41), Test server/test/schema.test.ts:67 prueft to_regclass, schema_migrations-Zeile und zweiten Lauf []
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: server/test/schema.test.ts:15
  Evidence: Beispiele per Regex aus dem Vertrag gelesen, assert genau 3 Bloecke, Reihenfolge Abschrift/Auftrag/Ergebnis
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: server/migrations/001_claude_schema.sql:13
  Evidence: eigener Probelauf bestaetigt Verankerung von like_regex: Aufgabenschluessel "titleX" und "xtitle" abgewiesen (23514), oberer Schluessel "tasksX" abgewiesen, tasks als Objekt oder Array-in-Array abgewiesen, tasks "x" und [null] liefern 2203x, doc als Array/null abgewiesen, Schluessel mit Zeilenumbruch abgewiesen
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: server/migrations/001_claude_schema.sql:27
  Evidence: kind "delete" und kind 5 abgewiesen (23514), id=5 und "kein-uuid" 22P02, Gross/Klein-Duplikat der id 23505, direkter Schreibversuch auf kind abgelehnt, claimed-Paar-CHECK Zeile 33
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: server/migrations/001_claude_schema.sql:41
  Evidence: PK=FK (Zeile 43), outcome/reason-CHECKs, Wechselbeziehung Zeile 51; getestet in server/test/schema.test.ts:115
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: server/test/schema.test.ts:136
  Evidence: Dokument behaelt Grossschreibung, Spalte klein, 1.0 als bekannte Grenze mit Kommentar
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: server/test/db.ts:5
  Evidence: DATABASE_URL-Pflicht per throw, freshPool exportiert; server/test/migrate.test.ts:8 importiert nur; Diff entfernt nur die Definition, Kindprozess-Test laeuft gruen
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: server/package.json:10
  Evidence: Muster 'test/*.test.ts'; Lauf meldet 16 Tests, kein db.ts-Eintrag
  Status: CONFIRMED
Confirmation:
  AC: AC-9 (lokal)
  Code reference: .github/workflows/server.yml:9
  Evidence: Pfad in pull_request (Zeile 9) und push (Zeile 15); docs/reference/claude-abschrift-vertrag.md:8 nennt server/test/schema.test.ts; unittest discover OK
  Status: CONFIRMED
Confirmation:
  AC: AC-10 (lokal)
  Code reference: server/scripts/test-local.sh:23
  Evidence: Lauf gruen, Wegwerf-Postgres per trap aufgeraeumt; Dateiliste laut Diff: nur Scope-Dateien plus Artefakte unter docs/, keine App-Datei, kein project.yml, kein CloudKit, keine CLAUDE.md
  Status: CONFIRMED
**Implementierer:** Keine Rueckmeldung noetig, keine Abweichung zur Spec in Runde 1.

### Runde 2
**Adversary:** Eigene Abweichungen gegen das Schema (Wegwerf-Postgres im Scratchpad, nichts im Baum).
Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: server/migrations/001_claude_schema.sql:27
  Description: kind ist generiert aus doc->>'kind'; CHECK (kind IN (...)) ist bei NULL nicht verletzt. Ein Auftrag ohne kind wird angenommen (Probe), die Zeile ist nie vergebbar.
  Spec requirement: AC-4 nennt nur kind unbekannt; Spec sagt Formpruefung hier "nur version, kind, id"
  Conflict: fehlendes kind wird nicht abgewiesen; AC-4 benennt den Fall nicht (Spec-Luecke, Umsetzung folgt dem SQL der Spec woertlich)
  Remediation: kind NOT NULL (oder CHECK kind IS NOT NULL) plus Tabellenzeile "kind fehlt"
Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: server/migrations/001_claude_schema.sql:51
  Description: outcome fehlt im Ergebnis: (NULL = 'rejected') = (reason IS NOT NULL) ergibt NULL, CHECK besteht; auch der outcome-CHECK besteht bei NULL. Ergebnis ohne outcome wird angenommen und belegt per PK den Auftrag (das richtige Ergebnis danach: 23505, Probe).
  Spec requirement: AC-5 — unbekannter outcome -> 23514 (fehlender nicht genannt)
  Conflict: gleiche NULL-Luecke; ein Ergebnis ohne outcome sperrt den Auftrag
  Remediation: outcome NOT NULL
Finding:
  ID: F003
  Severity: MEDIUM
  Category: edge_case
  Code reference: server/migrations/001_claude_schema.sql:12
  Description: CHECK (generated_at = (doc->>'generatedAt')::timestamptz) ist bei fehlendem generatedAt NULL und besteht (Probe). generatedAt ohne Zeitzone wird je nach Session-TimeZone angenommen oder abgewiesen: mit SET timezone UTC bzw. Asia/Tokyo und passendem generated_at angenommen, mit Europe/Berlin und Z-Wert abgewiesen. Der Text-Cast ist stable, nicht immutable.
  Spec requirement: AC-3 — generated_at != doc.generatedAt -> 23514
  Conflict: fehlendes oder zonenloses generatedAt wird nicht sicher abgewiesen; Ergebnis haengt von der Server-TimeZone ab (CI = UTC, Hetzner evtl. anders)
  Remediation: CHECK (doc ? 'generatedAt') und Zeitzonen-Format per like_regex; Tabellenzeilen im Test
Hinweis (Grenzen, die die Spec nach C3 schiebt oder nicht verlangt, keine Findings): verschachteltes rawText unter now, in contexts oder in einem title-Objekt wird angenommen (nur oberste und Aufgaben-Schluessel werden geprueft, so die Spec); tasks, now, nowCount duerfen fehlen; zusaetzliche Auftragsschluessel, complete ohne taskID, leerer account_id und id in Klammern (uuid normalisiert) werden angenommen (Formpruefung C3); leeres tasks wird angenommen (gewollt).
Code reference: server/test/schema.test.ts:67
Code reference: server/test/db.ts:5
Code reference: server/test/migrate.test.ts:8
Code reference: server/package.json:10
Code reference: .github/workflows/server.yml:9
Code reference: docs/reference/claude-abschrift-vertrag.md:8
**Implementierer:** Umsetzung entspricht dem SQL der Spec woertlich; F001-F003 sind Luecken der Spec, jeweils ein Einzeiler.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS

## Geprüfte Dateien

- sha256:3bfab5d3e214e45cc29164595d9d3610e9695b3055f8f961d8779a85931ba73b  .github/workflows/server.yml
- sha256:0d38398683ad7f0b122a0863cad90306d9f6530285f26a0c90cc63cc3f0e9ed5  docs/reference/claude-abschrift-vertrag.md
- sha256:1806fc1f8a2a860e1158d12bd7b2bbef0e07af0af6e063c22b2d6af8e23a5a62  server/migrations/001_claude_schema.sql
- sha256:ef2bc1acb7cb27d3dbdd5ff3c5caf8143a742710c2f05f29be96b8ced86f1f1f  server/package.json
- sha256:f8fcd4e694bb038c2df4a67b81b25ecc2638555c1f35d9e38a4566980089cea7  server/scripts/test-local.sh
- sha256:40281a1aed6430c433b7ebcec2561f29459dba1914d2132d1cc010c2b18b5d5a  server/test/db.ts
- sha256:29bc4c47a9e1317c8cdb81ec4c1ebb0de39b862629b63dc12f8ca06744bd9f8f  server/test/migrate.test.ts
- sha256:24c3d634ee3cd2fb06ad54e9bcce792e4fec4245e8d69958e0d08b2bb6985961  server/test/schema.test.ts

## Prüfbasis

- base: 20e250a4a5faf9dab675465a7d43c0816662931b
- blob:7af0e18c36dc0da7ebdc77db1915bca4e1adb584  .github/workflows/server.yml
- blob:29d170353f3c6982341825f69034fe6911a63945  docs/reference/claude-abschrift-vertrag.md
- blob:8762ed48315610cc8c87a2bbeea9185aa0e272bb  server/migrations/001_claude_schema.sql
- blob:39fa6d49b407ceb440026f84d0fdef384d27c511  server/package.json
- blob:801b9e49ce7d6cf3387f7386c8cd062015f529b5  server/scripts/test-local.sh
- blob:d745feabf6ec0724ad7ebdb89673a74ae86e65e1  server/test/db.ts
- blob:4e75f13b1102eb4b84ea444deba20ef6a31b23d2  server/test/migrate.test.ts
- blob:2a04e1aa71baf3809af87b84b513bafdf17ed472  server/test/schema.test.ts
