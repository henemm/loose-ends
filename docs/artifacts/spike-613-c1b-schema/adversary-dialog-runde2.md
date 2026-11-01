# Adversary Dialog — spike-613-c1b-schema
Spec: docs/specs/spike-613-schnitt-c1b-schema.md
Datum: 2026-11-01 07:23

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
**Adversary:** Tests frisch gelaufen (test-local.sh, Ausgabe in docs/artifacts/spike-613-c1b-schema/adversary-test-output.txt; 16 pass, 0 fail, 0 skipped; unittest 453 OK). F001 bis F003 gezielt angegriffen in einer Wegwerf-Postgres-Instanz (Port 54999, danach gestoppt und gelöscht), Sitzungszeitzone je Fall gesetzt, Spalte `generated_at` mit passendem Text:
- generatedAt als JSON-Zahl 1700000000 → abgewiesen (22008, Cast scheitert).
- `"...Z "` mit Leerzeichen am Ende → 23514. `"...+0100"` ohne Doppelpunkt → 23514. kleines `z` → 23514. Zeilenumbruch am Ende → 23514. Zonenname `" UTC"` → 23514. JSON null → 23514.
- Gültige Form, aber ungültiges Datum `2026-13-45T09:00:00Z` → 22008 abgewiesen. `hello Z`, `xx+01:00`, `...+01:00Z` → 22007 abgewiesen (Cast).
- Zeitzonenunabhängigkeit: `...Z` unter Europe/Berlin und Asia/Tokyo angenommen, `+01:00` unter Asia/Tokyo angenommen, `-05:00` angenommen; Gleichheit gilt als Zeitpunkt (andere Schreibweise desselben Moments angenommen, korrekt).
- App-Formen: JSONEncoder `.iso8601` (Code reference: Shared/Services/TranscriptCodec.swift:74) erzeugt `yyyy-MM-dd'T'HH:mm:ssZZZZZ`, also `Z` oder `+01:00`; beides wird angenommen, auch mit Bruchteilen `.123Z`. Der Regex weist keine App-Form ab.
**Implementierer:** Spec-Änderung und Migration decken F001 bis F003 ab (Code reference: server/migrations/001_claude_schema.sql:15, :30, :47).

### Runde 2
**Adversary:** Eigene Gegenbeispiele, die die Spec nicht nennt, fanden eine Lücke:
- Code reference: server/migrations/001_claude_schema.sql:15. `generatedAt` als Array `["2026-03-12T09:00:00Z"]` wird ANGENOMMEN: `jsonb_path_exists` läuft im lax-Modus und entpackt das Array, der Regex trifft den Eintrag; `doc->>'generatedAt'` liefert den Text `["2026-03-12T09:00:00Z"]`, und Postgres liest den Cast samt Klammern (Zeile gespeichert, `jsonb_typeof` = array). Die App dekodiert so ein Dokument nicht als Date. Mit `@.type() == "string" &&` im Filter wird das Array abgewiesen (geprüft, die Zeichenkette bleibt angenommen).
- Weitere lockere Formen, angenommen, aber harmlos: Leerzeichen statt `T` (`2026-03-12 09:00:00Z`), reines Datum mit Zone (`2026-03-12Z`). Die App erzeugt sie nicht. Nur Hinweis.
- Bestand gebrochen? Die drei Vertragsbeispiele werden angenommen (AC-2 grün), kein weiterer Test rot, migrate.test.ts unverändert grün.
- RED-Nachweis der Zeile `generatedAt ohne Zeitzone` (Frage 3): Im RED-Lauf (test-red2-output.txt:39) bricht die Schleife bei `generatedAt fehlt` ab, die Zeitzonenzeile wurde dort nicht erreicht. Der getrennte Nachweis gegen die alte Migration genügt als Beleg, weil die Zeilen unabhängig sind; er ist aber schwächer als ein Lauf je Zeile. Zusätzlich zeigt meine Probe, dass die Zeile gegen die neue Migration wirklich 23514 liefert (Zonenname, Zeilenumbruch, Leerzeichen scheitern am selben CHECK). Ausreichend; Empfehlung: ein Test je Tabellenzeile, dann bricht kein Fehlschlag die übrigen ab.
- Scope: keine App-Datei in der Dateiliste. Die Spec schiebt verschachtelten rawText und die Formprüfung des Auftrags nach C3, kein Finding.
**Implementierer:** Offen, für den Menschen.

**Findings (strukturiert):**

Finding:
  ID: F004
  Severity: MEDIUM
  Category: edge_case
  Code reference: server/migrations/001_claude_schema.sql:15
  Description: Der CHECK auf generatedAt nutzt `jsonb_path_exists(doc, '$.generatedAt ? (@ like_regex ...)')` ohne Typprüfung im lax-Modus; ein einelementiges Array mit gültiger Zeichenkette passiert Regex und Cast.
  Spec requirement: AC-3 — generatedAt muss vorhanden sein und mit einer Zeitzone enden, der Vergleich darf nicht von der Sitzung abhängen.
  Conflict: Das Dokument mit `"generatedAt":["2026-03-12T09:00:00Z"]` wird gespeichert, obwohl der Vertrag eine Zeichenkette verlangt und die App kein Array dekodiert. Nicht durch die Spec-Tabelle abgedeckt, daher AMBIGUOUS statt BROKEN.
  Remediation: Filter auf `@.type() == "string" && @ like_regex ...` (geprüft), dazu eine Tabellenzeile `generatedAt als Array` mit 23514.

Geschlossen: F001 (kind NOT NULL, Zeile 30, Test 111), F002 (outcome NOT NULL, Zeile 47, Test 146), F003 (Zeile 15, Test 91 und 92), mit der Einschränkung F004.

Offen, ausdrücklich: AC-9 und AC-10 brauchen den CI-Lauf auf dem PR (es gibt noch keinen PR).


**Bestätigungen (Confirmation, Status CONFIRMED):**

- AC-1: Code reference: server/migrations/001_claude_schema.sql:6 — drei CREATE TABLE (transcripts, orders, order_results); Code reference: server/test/schema.test.ts:56 prüft to_regclass und zweiten Lauf `[]`. Evidence: Testlauf grün (16 von 16).
- AC-2: Code reference: server/test/schema.test.ts:68 — Beispiele zur Laufzeit aus dem Vertrag. Evidence: grün; die neuen Zeilen haben die drei Vertragsbeispiele nicht gebrochen (NOT NULL und Zeitzonen-CHECK akzeptieren `...Z`).
- AC-3: Code reference: server/test/schema.test.ts:81 (Zeilen 91 und 92 neu) und server/migrations/001_claude_schema.sql:15. Evidence: grün; eigene Gegenbeispiele in Runde 1 und 2, mit Einschränkung F004.
- AC-4: Code reference: server/migrations/001_claude_schema.sql:30 (`kind ... NOT NULL`), server/test/schema.test.ts:111 (`kind fehlt` → 23502). Evidence: grün.
- AC-5: Code reference: server/migrations/001_claude_schema.sql:47 (`outcome ... NOT NULL`), server/test/schema.test.ts:146 (`outcome fehlt` → 23502). Evidence: grün.
- AC-6: Code reference: server/test/schema.test.ts:160 und server/test/schema.test.ts:171. Evidence: grün.
- AC-7: Code reference: server/test/db.ts:5 (DATABASE_URL-Pflicht, `throw`), server/test/migrate.test.ts:10 (`import { freshPool } from "./db.ts"`). Evidence: migrate.test.ts ist gegenüber HEAD unverändert, 9 migrate-Tests grün inkl. Kindprozess-Test ohne DATABASE_URL.
- AC-8: Code reference: server/package.json:10 (`node --test 'test/*.test.ts'`). Evidence: Lauf meldet `tests 16`, nur migrate- und schema-Tests, kein Lauf für db.ts.
- AC-9: Code reference: .github/workflows/server.yml:9 (pull_request-Filter) und .github/workflows/server.yml:15 (push-Filter); Code reference: docs/reference/claude-abschrift-vertrag.md:8 (Satz nennt schema.test.ts). Evidence: Diff-Durchsicht, `python3 -m unittest discover -s scripts`: 453 Tests OK. OFFEN: der CI-Lauf auf dem PR, es gibt den PR noch nicht.
- AC-10: Evidence: `./server/scripts/test-local.sh` Exit 0 (Typprüfung ohne Fehler, 16 von 16 grün, 0 übersprungen), Aufräumen per trap. Dateiliste gegen HEAD: nur server.yml, Vertrag, Spec, Briefing, server/package.json, schema.test.ts plus neu server/migrations/; keine App-Datei, kein project.yml, kein CloudKit-Schema, keine CLAUDE.md. OFFEN: server.yml grün auf dem PR (kein PR).


**Belegstellen je Datei (Confirmation, Status CONFIRMED):**

Code reference: server/migrations/001_claude_schema.sql:15
Evidence: AC-3/F003 und F004: CHECK auf generatedAt

Code reference: server/test/schema.test.ts:81
Evidence: AC-3 bis AC-5: Abweichungstabellen

Code reference: server/test/db.ts:5
Evidence: AC-7: DATABASE_URL-Pflicht

Code reference: server/test/migrate.test.ts:10
Evidence: AC-7: Import von freshPool

Code reference: server/package.json:10
Evidence: AC-8: Testauswahl test/*.test.ts

Code reference: .github/workflows/server.yml:9
Evidence: AC-9: Pfadfilter

Code reference: docs/reference/claude-abschrift-vertrag.md:8
Evidence: AC-9: Satz zu den Beispielen

Code reference: Shared/Services/TranscriptCodec.swift:74
Evidence: App-Datumsformat iso8601

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**AMBIGUOUS**

## Geprüfte Dateien

- sha256:3bfab5d3e214e45cc29164595d9d3610e9695b3055f8f961d8779a85931ba73b  .github/workflows/server.yml
- sha256:8e6898f6f9193dbcda9bb13b3b37e6d46a4b8ed6d2af3ef36f43fc2decdc80b8  Shared/Services/TranscriptCodec.swift
- sha256:0d38398683ad7f0b122a0863cad90306d9f6530285f26a0c90cc63cc3f0e9ed5  docs/reference/claude-abschrift-vertrag.md
- sha256:3ca8f2da5ff4b1dfed71fe81ac2062b9111df4d009063ea0adf7bec548b36926  server/migrations/001_claude_schema.sql
- sha256:ef2bc1acb7cb27d3dbdd5ff3c5caf8143a742710c2f05f29be96b8ced86f1f1f  server/package.json
- sha256:40281a1aed6430c433b7ebcec2561f29459dba1914d2132d1cc010c2b18b5d5a  server/test/db.ts
- sha256:29bc4c47a9e1317c8cdb81ec4c1ebb0de39b862629b63dc12f8ca06744bd9f8f  server/test/migrate.test.ts
- sha256:f2780193bb53c6b796832e23571978a2e1aaf2e79cef4ecd4bc01cd4b84c6c1e  server/test/schema.test.ts

## Prüfbasis

- base: 20e250a4a5faf9dab675465a7d43c0816662931b
- blob:7af0e18c36dc0da7ebdc77db1915bca4e1adb584  .github/workflows/server.yml
- blob:9ee5ccfc0057a00dbaa52b8c71527e5d36aaa4eb  Shared/Services/TranscriptCodec.swift
- blob:29d170353f3c6982341825f69034fe6911a63945  docs/reference/claude-abschrift-vertrag.md
- blob:ce7361296490f2d748a3b299bdbcaa8f5d20b8a1  server/migrations/001_claude_schema.sql
- blob:39fa6d49b407ceb440026f84d0fdef384d27c511  server/package.json
- blob:d745feabf6ec0724ad7ebdb89673a74ae86e65e1  server/test/db.ts
- blob:4e75f13b1102eb4b84ea444deba20ef6a31b23d2  server/test/migrate.test.ts
- blob:9c1afbb0cd222d82986c8dda8fa311f79f271b47  server/test/schema.test.ts
