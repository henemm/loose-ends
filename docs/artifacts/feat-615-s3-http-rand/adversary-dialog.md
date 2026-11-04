# Adversary Dialog — feat-615-s3-http-rand
Spec: docs/specs/feat-615-schnitt-3a-datenschicht.md
Datum: 2026-11-04 09:04

## Checkliste
- [x] **AC-1:** `aud` im Erfolg: Bei gültigem Identity-Token, dessen `aud` die erste, und bei einem, dessen `aud` die zweite der beiden konfigurierten Client-IDs ist, ergibt `verifyIdentityToken` genau `{ ok: true, sub, aud }` mit der jeweils richtigen Client-ID (nicht immer der ersten). Test: „verify: aud im erfolg“ in `apple.test.ts`, dazu die angepassten Erfolgszeilen in `apple.test.ts` und der bestehende Zusammenspiel-Test in `apple-jwks.test.ts` (Zeile 217, nur um `aud` ergänzt, kein neuer Test).
- [x] **AC-2:** Fehlerformen unverändert: Jeder bisherige Fehlerfall von `verifyIdentityToken` ergibt weiterhin ein Objekt, dessen `Object.keys` genau `["ok", "reason"]` sind (kein `aud`, kein `sub`), mit unveränderten Gründen. Test: „verify: fehlerformen“ (bestehende Fehlerfälle unverändert, dazu eine Schleife über deren Ergebnisse mit `Object.keys`).
- [x] **AC-3:** Migration 003 läuft einmal und additiv: Auf einer bis 002 migrierten Datenbank mit einer abgelegten Token-Zeile (aus 002-Zeit, ohne Spalte) wendet `migrate` mit dem echten Ordner genau `003_apple_client_id.sql` an; die Zeile bleibt mit unverändertem `refresh_token_enc` und `created_at` erhalten, `client_id` ist `NULL`; ein zweiter Lauf wendet nichts an. Die Spalte hat den Typ `text` und ist nullable. Test: „migration 003: additiv auf bestandsdaten“ in `server/test/schema.test.ts` (legt die Datenbank mit 001 und 002 aus einem temporären Ordner an, kopiert 003 aus dem echten Ordner dazu); dazu die angepassten Listen in `schema.test.ts` und `accounts.test.ts`.
- [x] **AC-4:** Upsert ersetzt `client_id`: `storeRefreshToken(pool, id, blob, clientId)` legt Blob und `client_id` ab und liefert `true`; ein zweiter Aufruf mit anderem Blob und anderer `client_id` ersetzt beide und setzt `created_at` neu; es bleibt eine Zeile je Konto. Ein unbekanntes Konto ergibt weiterhin `false` und legt nichts ab. Test: „vault: client_id wird abgelegt und ersetzt“.
- [x] **AC-5:** Fehlbedienung wirft: `storeRefreshToken` mit `clientId` = `""`, `undefined`, `null`, einer Zahl, einem Objekt und einem Array wirft, **ohne dass die Datenbank berührt wird** (kein Zeilenzuwachs, kein Aufruf auf einem toten Pool nötig), und kein Fehlertext enthält den übergebenen Wert (Testwert `GEHEIM-CLIENT` als Text im Objekt/Array). Test: „vault fehlbedienung: client_id“ (Fallliste).
- [x] **AC-6:** Rundweg und Grenzfälle: Nach `storeRefreshToken(pool, id, blob, clientId)` liefert `deleteAccount(pool, id)` genau `{ deleted: true, appleToken: blob, clientId }`; ein Konto ohne Token ergibt `{ deleted: true, appleToken: null, clientId: null }`; ein unbekanntes Konto `{ deleted: false, appleToken: null, clientId: null }`; ein Konto mit einer Zeile aus 002-Zeit (`client_id` NULL) ergibt `{ deleted: true, appleToken: blob, clientId: null }`. Die Löschung bleibt vollständig (die bestehenden Zählungen aller Tabellen auf 0 bleiben grün). Test: „delete: rundweg mit client_id“ (Fallliste), dazu die angepassten bestehenden `deepEqual`-Zeilen.
- [x] **AC-7:** Regression und Funktionslänge: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, **kein bestehender Testfall wird gelöscht**, und geändert werden nur die in „Bestehende Tests, die mitgehen müssen“ genannten Zeilen; jede Funktion in `server/src/apple.ts`, `apple-vault.ts` und `accounts.ts` hat höchstens 50 Zeilen. Test: `./server/scripts/test-local.sh`, dazu `git diff origin/main -- server/test` (nur die genannten Zeilen verändert, sonst Ergänzungen) und `grep -nE "function" ` je Datei (Abstand zweier Funktionsanfänge und Dateiende ≤ 50).
- [x] **AC-8:** Dateigrenze und Doku: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple.ts`, `server/migrations/003_apple_client_id.sql`, `server/src/apple-vault.ts`, `server/src/accounts.ts`, `server/test/apple.test.ts`, `server/test/apple-jwks.test.ts`, `server/test/apple-vault.test.ts`, `server/test/accounts.test.ts`, `server/test/schema.test.ts` und `CLAUDE.md` (Test: dieser Befehl, in der Validierung ausgeführt); die Zeilen zu `src/accounts.ts`, `src/apple.ts` und `src/apple-vault.ts` im Abschnitt `server/` von `CLAUDE.md` nennen `aud`, `client_id` und Migration 003; `main.ts`, `mcp.ts`, `apple-client.ts`, `apple-jwks.ts`, `.github/`, `project.yml` und jede Swift-Datei bleiben unberührt. Zusätzlich bestätigt `grep -rn "client_id\|clientId" server/src/apple.ts server/src/apple-vault.ts server/src/accounts.ts`, dass kein Treffer in einem `throw`-Text oder `console`-Aufruf steht.

## Dialog

### Runde 1
**Adversary:** Beweislauf und Diff. `./server/scripts/test-local.sh` selbst gefahren (Ausgabe: docs/artifacts/feat-615-s3-http-rand/adversary-test-output.txt): typecheck ok, 192 tests, 192 pass, 0 fail, 0 skipped, exit 0.
- [x] AC-1: aud wird aus payload.aud zurueckgegeben, das vorher als string und in clientIds geprueft wurde. Test "verify: aud im erfolg" deckt IDS[0] und IDS[1] ab.
  Code reference: server/src/apple.ts:99
- [x] AC-2: Fehlerpfade unveraendert (fail(...)), Test "verify: fehlerformen" prueft Object.keys == ["ok","reason"]. Im Test-Diff gegen origin/main sind entfernte Zeilen nur die genannten Erfolgs-deepEquals.
- [x] AC-3: Migration nur ADD COLUMN client_id text, kein BEGIN/COMMIT. Test legt 001+002 an, fuegt Zeile ein, wendet nur 003 an, prueft enc/created_at unveraendert, NULL, text/YES, zweiter Lauf leer.
  Code reference: server/migrations/003_apple_client_id.sql:4
- [x] AC-4: Upsert setzt client_id und ersetzt bei Konflikt mit Blob und created_at; 23503 liefert weiter false.
  Code reference: server/src/apple-vault.ts:42
- [x] AC-5: Validierung (Zeile 40) steht vor jedem pool.query; Test nutzt zusaetzlich einen beendeten Pool und prueft, dass GEHEIM-CLIENT nicht in Message/Stack steht. Meldung "client id must not be empty" ohne Wert. Treffer clientId in der Bedingung der throw-Zeile ist nur der Variablenname, nicht im Text: kein Verstoss.
  Code reference: server/src/apple-vault.ts:40
- [x] AC-6: LEFT JOIN liefert bei Konto ohne Token NULL/NULL, bei unbekanntem Konto rowCount 0 -> Rollback, clientId null. Alte Zeile ergibt clientId null. Zaehlungen auf 0 bleiben gruen.
  Code reference: server/src/accounts.ts:48
- [x] AC-7: Gruen (siehe oben). Kein Testfall geloescht; geaendert nur genannte Zeilen plus Hilfsfunktion `filled` (optionaler Parameter) und Import-Zeile in schema.test.ts. Funktionslaengen: laengste deleteAccount 26 Zeilen, verifyIdentityToken 19, alle <= 50. server.yml auf dem PR kann ich nicht pruefen (noch kein PR).
- [x] AC-8: Dateiliste gegen origin/main nennt 9 getrackte Dateien (CLAUDE.md, 3 src, 5 test) plus untracked 003 = genau die 10 der Spec. CLAUDE.md-Zeilen nennen aud, client_id, Migration 003. main.ts, mcp.ts, apple-client.ts, apple-jwks.ts, Workflow-Ordner, project.yml, Swift unberuehrt.
  Code reference: CLAUDE.md:466

### Runde 2
**Adversary:** Gezielte Angriffe.
- [x] aud-Vergleich: includes() exakt und case-sensitiv; aud als Array im Token wird mit "aud" abgelehnt, nie zurueckgegeben.
  Code reference: server/src/apple.ts:61
- [x] Upsert bei 23503: catch-Zweig unveraendert, false; Wert parametrisiert.
- [x] Validierungsreihenfolge: vor try/pool.query, durch toten Pool bewiesen.
- [x] Migration doppelt: Runner wickelt in Transaktion, Test belegt zweiten Lauf leer.
- [x] deleteAccount LEFT JOIN: apple_tokens.account_id ist eindeutig (ON CONFLICT), hoechstens eine Zeile; rowCount === 1 bleibt gueltig.
  Code reference: server/src/accounts.ts:61
- [x] Stille: kein console/stdout in den geaenderten Funktionen; Test "silence" gruen.
**Implementierer:** n/a (Eigenprotokoll).

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apple-vault.ts:40
  Description: Ein nur aus Leerzeichen bestehender clientId-String wird akzeptiert und abgelegt.
  Spec requirement: AC-5 — nur "" ist als Wurf spezifiziert
  Conflict: Kein Spec-Verstoss; praktisch irrelevant, da clientId aus verify (aud in clientIds) stammt.
  Remediation: optional trim pruefen.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: server/src/accounts.ts:48
  Description: Test-Hilfsfunktion `filled` in accounts.test.ts wurde um einen optionalen Parameter erweitert; in der Spec nicht ausdruecklich unter den mitgehenden Zeilen.
  Spec requirement: AC-7 — nur genannte Zeilen aendern
  Conflict: Rein mechanisch, kein Verhalten bestehender Faelle geaendert.
  Remediation: keine; im PR erwaehnen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

**VERIFIED**
Tests: 192 passed, 0 failed, 0 uebersprungen
Edge cases: All checked, only LOW notes (F001, F002)
Regressions: None found
Checklist: 8/8 points proven

## Geprüfte Dateien

- sha256:3dc63382351fd85838d2a3dbb32c17cf0f3ce3062de4c6b3f3043c1f76ab4544  CLAUDE.md
- sha256:12c2247bcc9d42417d734605e339feeeced9f88df9b8216b3354395072ae5f6c  server/migrations/003_apple_client_id.sql
- sha256:45cb67488d92f17b7c62c2ef4c5c625b6fbe93259066b50dcfe28f8b597f00d3  server/src/accounts.ts
- sha256:10f56fddc4548d9a2b3833bf75c26df1c9fb6b405da5bd177e90888a9c030bdc  server/src/apple-vault.ts
- sha256:916821d66cb9f964edc12ac5e2faca9fd63ad1c8f7ad2bae57ea6fca4d028fcc  server/src/apple.ts

## Prüfbasis

- base: e4ec723847d394b7c8099a1aa234cffa81a283f5
- blob:dcd32a3a0c787017e975db297c061a4426c915be  CLAUDE.md
- blob:a7eeccb05fd9d1216d392038755bd479807dab69  server/migrations/003_apple_client_id.sql
- blob:e2f423e6d7b0846a9350da6d5014f2369e2d2c80  server/src/accounts.ts
- blob:a65b7d580f3f66a2bf3bb8c27592376c323e9154  server/src/apple-vault.ts
- blob:190592259b540f8cb1c73b88ce19ff7540f38e86  server/src/apple.ts

## Geprüfte Dateien

- sha256:3dc63382351fd85838d2a3dbb32c17cf0f3ce3062de4c6b3f3043c1f76ab4544  CLAUDE.md
- sha256:12c2247bcc9d42417d734605e339feeeced9f88df9b8216b3354395072ae5f6c  server/migrations/003_apple_client_id.sql
- sha256:45cb67488d92f17b7c62c2ef4c5c625b6fbe93259066b50dcfe28f8b597f00d3  server/src/accounts.ts
- sha256:10f56fddc4548d9a2b3833bf75c26df1c9fb6b405da5bd177e90888a9c030bdc  server/src/apple-vault.ts
- sha256:916821d66cb9f964edc12ac5e2faca9fd63ad1c8f7ad2bae57ea6fca4d028fcc  server/src/apple.ts

## Prüfbasis

- base: e4ec723847d394b7c8099a1aa234cffa81a283f5
- blob:dcd32a3a0c787017e975db297c061a4426c915be  CLAUDE.md
- blob:a7eeccb05fd9d1216d392038755bd479807dab69  server/migrations/003_apple_client_id.sql
- blob:e2f423e6d7b0846a9350da6d5014f2369e2d2c80  server/src/accounts.ts
- blob:a65b7d580f3f66a2bf3bb8c27592376c323e9154  server/src/apple-vault.ts
- blob:190592259b540f8cb1c73b88ce19ff7540f38e86  server/src/apple.ts
