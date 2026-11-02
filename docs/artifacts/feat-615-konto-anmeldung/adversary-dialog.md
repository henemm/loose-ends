# Adversary Dialog — feat-615-konto-anmeldung
Spec: docs/specs/feat-615-schnitt-1-konten-sitzungen.md
Datum: 2026-11-02 21:40

## Checkliste
- [x] **AC-1:** Der Migrationsläufer wendet auf einer leeren Datenbank genau `["001_claude_schema.sql", "002_accounts.sql"]` an, ein zweiter Lauf wendet nichts an; die Tabellen `accounts`, `sessions`, `apple_tokens` existieren.
- [x] **AC-2:** `findOrCreate` mit demselben `apple_sub` liefert dieselbe Kennung (auch bei zwei gleichzeitigen Aufrufen, genau eine Zeile in `accounts`); ein anderer `apple_sub` liefert eine andere Kennung.
- [x] **AC-3:** `createSession` liefert einen `base64url`-Token aus 32 Byte (43 Zeichen); die Tokens zweier Aufrufe unterscheiden sich; in `sessions` steht `sha256(token)`, und der Klartext kommt in keiner Spalte jeder Zeile von `sessions` (als Text gelesen) vor.
- [x] **AC-4:** `resolveSession` liefert für einen gültigen Token die Kontokennung und setzt `last_used_at` neu (der Test setzt es vorher per `UPDATE` auf einen festen Zeitpunkt in der Vergangenheit und erwartet danach einen späteren); für einen unbekannten, leeren, veränderten oder nicht-Text-Token (`undefined`, Zahl) liefert es `null`.
- [x] **AC-5:** Nach `endSession` liefert `resolveSession` für diesen Token `null`; weitere Sitzungen desselben Kontos bleiben gültig; `endSession` für einen unbekannten Token gibt `false` zurück, ohne Ausnahme.
- [x] **AC-6:** `createSession` für eine nicht vorhandene Kontokennung wird vom Fremdschlüssel abgelehnt.
- [x] **AC-7:** `deleteAccount` entfernt für ein Konto mit Sitzung, Apple-Token, Abschrift, Auftrag und Ergebnis jede Zeile dieses Kontos aus `accounts`, `sessions`, `apple_tokens`, `transcripts`, `orders` und `order_results` und gibt `deleted: true` mit den gespeicherten Bytes des Apple-Tokens zurück.
- [x] **AC-8:** Ein zweites Konto mit denselben Arten von Zeilen bleibt nach `deleteAccount` des ersten vollständig unberührt (Zeilenzahl je Tabelle, seine Sitzung löst weiter auf).
- [x] **AC-9:** `deleteAccount` ohne Apple-Token gibt `{ deleted: true, appleToken: null }` zurück und löscht trotzdem alles; für ein unbekanntes Konto gibt es `{ deleted: false, appleToken: null }` und ändert nichts.
- [x] **AC-10:** `deleteAccount` entfernt auch Ergebnisse zu Aufträgen des Kontos, die schon abgeholt und beantwortet sind (Auftrag mit `claimed_by`, `claimed_at` und Zeile in `order_results`), ohne Fremdschlüsselfehler.
- [x] **AC-11:** Die bestehenden Tests zu Abschrift, Aufträgen und MCP laufen unverändert weiter (ihre Dateien bleiben unberührt); im Schema-Test ändern sich nur die erwartete Migrationsliste und die erwartete Zeilenzahl von `schema_migrations` (1 → 2) im dortigen AC-1-Test. `npm run typecheck` und `./server/scripts/test-local.sh` sind grün und räumen auf; `server.yml` ist auf dem PR grün.
- [x] **AC-12:** Während aller `accounts`-Aufrufe eines Tests (inklusive des scheiternden `createSession` aus AC-6) wird nichts nach `console` oder `process.stdout` geschrieben (Test ersetzt beide vorübergehend), und der Fehlertext des scheiternden Aufrufs enthält weder Token noch `apple_sub`.
- [x] **AC-13:** `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau die fünf Dateien aus „Affected Files“ (Workflow-Unterlagen unter `docs/` und `.claude/` zählen nicht); insbesondere bleiben `server/package.json`, `server/src/mcp.ts`, `transcripts.ts`, `orders.ts`, `migrate.ts`, `001_claude_schema.sql`, `server/test/db.ts`, `transcripts.test.ts`, `orders.test.ts`, `mcp.test.ts`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Dialog

### Runde 1
**Adversary:** Test-Suite per test-local.sh gelaufen (adversary-test-output.txt): 110 pass, 0 fail, 0 skipped. Jedes AC einzeln gegen Code und Test geprueft (siehe Confirmations). Angriffe: Nebenlaeufigkeit findOrCreate (ein Statement, Unique-Index, Test mit Promise.all), Token 43 Zeichen, Klartext nie gespeichert (nur hash() in accounts.ts:4 an die DB), nicht-Text-Token (Guard Zeile 24 und 34, vor dem Hash), Klartext-Pruefung ueber s::text.
**Implementierer:** Alle Punkte durch Code und Tests belegt.

### Runde 2
**Adversary:** Zweite Runde auf Randfaelle ohne Test. (a) deleteAccount parallel doppelt: FOR UPDATE OF a (accounts.ts:49) serialisiert, der zweite sieht die Zeile nicht mehr, rowCount 0, ROLLBACK, deleted false; nur einer gewinnt. (b) Rollback bei Fehler: catch fuehrt ROLLBACK aus und wirft weiter, finally gibt die Verbindung frei; kein Test deckt diesen Pfad (Beobachtung, LOW, kein Spec-AC). (c) Ein Versuch, einen Wegwerf-Test mit Fehler-Trigger auszufuehren, scheiterte an der Shell-Sperre des Worktrees (Heredoc-Filter), daher nur durch Codelesen belegt. (d) findOrCreate nimmt leeren oder langen apple_sub an: Spec verlangt keine Pruefung, S2 liefert den sub nach Token-Pruefung (Beobachtung, LOW). (e) deleteAccount mit leerer/nicht-Text-Kennung: Parameter an Postgres, kein Treffer, deleted false. (f) Fehlertext: pg-Fehler 23503 nennt die Kontokennung kein-konto, aber weder Token (nur Hash gebunden) noch apple_sub. (g) Kein console/stdout in accounts.ts. (h) Schreiben einer Abschrift waehrend des Loeschens: in der Spec als Restrisiko fuer S3 benannt, in S1 nicht erreichbar. Keine Defekte gefunden.
**Implementierer:** Beobachtungen (b) und (d) liegen ausserhalb der AC; kein Befund, der das Verdict aendert.

Confirmation:
  AC: AC-1
  Code reference: server/migrations/002_accounts.sql:6
  Evidence: Test AC-1 in accounts.test.ts: migrate liefert genau 001+002, zweiter Lauf [], drei Tabellen via to_regclass; im Lauf gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/accounts.ts:9
  Evidence: Ein INSERT ON CONFLICT DO UPDATE RETURNING id; Test mit Promise.all, count=1; zweiter apple_sub andere Kennung
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/accounts.ts:17
  Evidence: randomBytes(32) base64url = 43 Zeichen (Regex-Test), nur sha256 als bytea gespeichert, s::text enthaelt keinen Klartext
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/accounts.ts:24
  Evidence: Guard typeof/leer, UPDATE ... RETURNING setzt last_used_at; Test von fester Vergangenheit aus; undefined/42/leer/veraendert/unbekannt gleich null
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/src/accounts.ts:35
  Evidence: DELETE nur token_hash, rowCount===1; zweite Sitzung bleibt gueltig, unbekannt false
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/migrations/002_accounts.sql:15
  Evidence: FK sessions.account_id; Test erwartet SQLSTATE 23503
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/accounts.ts:56
  Evidence: Reihenfolge order_results, orders, transcripts, accounts; Sessions/apple_tokens per CASCADE; Rueckgabe Bytes (deepEqual mit Buffer); Zaehlung ueber sechs Tabellen = 0
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/test/accounts.test.ts:140
  Evidence: counts() des zweiten Kontos vor/nach identisch, resolveSession des zweiten loest auf; alle DELETEs mit WHERE account_id=$1
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/accounts.ts:52
  Evidence: LEFT JOIN liefert null ohne Apple-Token, unbekanntes Konto: rowCount 0, ROLLBACK, {false,null}; Test prueft Unveraendertheit des anderen Kontos
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/test/accounts.test.ts:38
  Evidence: filled() legt Auftrag mit claimed_by/claimed_at plus order_results an; deleteAccount ohne FK-Fehler, totalResults 1 danach (keine Waisen)
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: server/test/schema.test.ts:59
  Evidence: Diff schema.test.ts nur Liste und rowCount 1 zu 2; Lauf 110 pass, 0 fail, 0 skipped; transcripts/orders/mcp-Tests unberuehrt. Nur lokal belegt: server.yml macht dasselbe (Postgres 18, typecheck, npm test) und laeuft erst auf dem PR; der lokale Lauf belegt den Inhalt, nicht den CI-Status, das bleibt nach PR-Erstellung zu pruefen
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: server/test/accounts.test.ts:158
  Evidence: console.log/error/warn und stdout.write ersetzt, written leer; Fehler 23503 ohne Token/apple_sub im message; accounts.ts enthaelt kein console
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: CLAUDE.md:460
  Evidence: git diff --name-only origin/main zeigt CLAUDE.md, accounts.test.ts, schema.test.ts; untracked 002_accounts.sql und accounts.ts; zusammen genau die fuenf Dateien, package.json/mcp.ts/db.ts etc. unberuehrt
  Status: CONFIRMED


## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 110 passed, 0 failed, 0 uebersprungen
Edge cases: geprueft, keine gebrochen (Rollback-Pfad nur durch Codelesen)
Regressions: keine
Checklist: 13/13 bewiesen
Hinweis AC-11: server.yml auf dem PR ist erst nach PR-Erstellung pruefbar; der lokale Lauf ist inhaltlich gleichwertig, aber kein CI-Beleg.

## Geprüfte Dateien

- sha256:ffab66c77463b219c9145bc787dc162e12bec8dcc0b916967b5d535bc9bbd2cf  CLAUDE.md
- sha256:dfcdebea9cd5e6dbc31a6675a73e552cadc3cd0239b12c5a386635a7043ffc48  server/migrations/002_accounts.sql
- sha256:87fce565482285f28762d9493b143ac86a755225e8e4226778f3aaf9a679939e  server/src/accounts.ts
- sha256:884aee5bec4bc04ca1726f0901fb4979d08aff6b670d97597ffedf61ae0a61a1  server/test/accounts.test.ts
- sha256:eea8bde2c67045c84324194941b9881d29266c321032c26161e9c502c44005f8  server/test/schema.test.ts

## Prüfbasis

- base: 49d576f22144df439b2e780a4a54526fdd09e647
- blob:c2a28370f3909a1df29895c60021676dfea92d06  CLAUDE.md
- blob:408d7b7e4fa2ab9f0cc91f91ab7e9865929bcebd  server/migrations/002_accounts.sql
- blob:16a82b1673ee90790dfc4c75f195fc9d143d9cb1  server/src/accounts.ts
- blob:a3846ada06e45f7ddb4c15996bf8be6def0b8d59  server/test/accounts.test.ts
- blob:a88e6e6abb1ba8f73c6c4d8bb44321c827b93e5e  server/test/schema.test.ts

## Geprüfte Dateien

- sha256:ffab66c77463b219c9145bc787dc162e12bec8dcc0b916967b5d535bc9bbd2cf  CLAUDE.md
- sha256:dfcdebea9cd5e6dbc31a6675a73e552cadc3cd0239b12c5a386635a7043ffc48  server/migrations/002_accounts.sql
- sha256:87fce565482285f28762d9493b143ac86a755225e8e4226778f3aaf9a679939e  server/src/accounts.ts
- sha256:884aee5bec4bc04ca1726f0901fb4979d08aff6b670d97597ffedf61ae0a61a1  server/test/accounts.test.ts
- sha256:eea8bde2c67045c84324194941b9881d29266c321032c26161e9c502c44005f8  server/test/schema.test.ts

## Prüfbasis

- base: 49d576f22144df439b2e780a4a54526fdd09e647
- blob:c2a28370f3909a1df29895c60021676dfea92d06  CLAUDE.md
- blob:408d7b7e4fa2ab9f0cc91f91ab7e9865929bcebd  server/migrations/002_accounts.sql
- blob:16a82b1673ee90790dfc4c75f195fc9d143d9cb1  server/src/accounts.ts
- blob:a3846ada06e45f7ddb4c15996bf8be6def0b8d59  server/test/accounts.test.ts
- blob:a88e6e6abb1ba8f73c6c4d8bb44321c827b93e5e  server/test/schema.test.ts
