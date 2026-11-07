# Adversary Dialog — feat-621-s4c-web-token
Spec: docs/specs/feat-621-schnitt-4c1-ablage-je-client.md
Datum: 2026-11-07 06:52

## Checkliste
- [x] **AC-1:** Migration, Datenwirkung: GIVEN ein Schema mit Migration 001 bis 004 und einem Konto A mit einer Token-Zeile ohne `client_id` (vor 003 gespeichert) sowie einem Konto B mit einer Token-Zeile mit `client_id` und eigenem Blob WHEN Migration 005 angewendet wird THEN meldet der Runner genau `["005_apple_tokens_per_client.sql"]`, die Zeile von A ist verschwunden, die von B ist byte-gleich (Blob, `created_at`, `client_id`) erhalten, beide Konten, Sitzungen und andere Tabellen sind unberührt; ein zweiter Lauf meldet `[]`. Test: server/test/schema.test.ts „migration 005: zeile ohne client_id faellt weg, rest bleibt“.
- [x] **AC-2:** Migration, Form: GIVEN ein Schema nach Migration 005 WHEN die Struktur von `apple_tokens` gelesen wird THEN ist `client_id` `NOT NULL` (`information_schema.columns`), der Primärschlüssel heißt `apple_tokens_pkey` und lautet `PRIMARY KEY (account_id, client_id)` (`pg_get_constraintdef`), der Fremdschlüssel `account_id` auf `accounts(id)` mit `ON DELETE CASCADE` besteht weiter (`confdeltype = 'c'`), und der alte Primärschlüssel nur auf `account_id` besteht nicht mehr (genau ein Primärschlüssel). Vor dem Test bei Migration 002 steht fest, dass der alte Name `apple_tokens_pkey` war (derselbe Test liest ihn im Stand nach 004 und prüft `PRIMARY KEY (account_id)`). Test: server/test/schema.test.ts „migration 005: form von apple_tokens“.
- [x] **AC-3:** Migration, Verhalten der Schlüssel: GIVEN ein Schema nach 005 und ein Konto WHEN (a) eine Zeile ohne `client_id` eingefügt wird, (b) zwei Zeilen mit verschiedener `client_id` für dasselbe Konto eingefügt werden, (c) eine zweite Zeile mit demselben Paar eingefügt wird, (d) das Konto gelöscht wird THEN (a) wird mit `23502` abgelehnt, (b) gelingt (zwei Zeilen), (c) wird mit `23505` abgelehnt, (d) entfernt beide Zeilen durch die Kaskade. Test: server/test/schema.test.ts „migration 005: zwei clients je konto, null und doppelt abgelehnt, kaskade“.
- [x] **AC-4:** Upsert je Paar, gleiches Paar ersetzt: GIVEN ein Konto mit einer Zeile (Client X, Blob 1) und `created_at` auf eine Stunde zuvor gesetzt WHEN `storeRefreshToken` mit Client X und Blob 2 aufgerufen wird THEN antwortet es `true`, es gibt weiter genau eine Zeile, ihr Blob ist Blob 2, `client_id` ist X, `created_at` ist vorgerückt. Test: server/test/apple-vault.test.ts „store: gleiches paar ersetzt blob und created_at“.
- [x] **AC-5:** Upsert je Paar, anderer Client steht daneben: GIVEN ein Konto mit einer Zeile (Client X, Blob 1, `created_at` zuvor gesetzt) WHEN `storeRefreshToken` mit Client Y und Blob 2 aufgerufen wird THEN antwortet es `true`, es gibt zwei Zeilen, die Zeile von X ist byte-gleich unberührt (Blob 1, `created_at`), die von Y trägt Blob 2; ein weiteres Konto bleibt unberührt. Test: server/test/apple-vault.test.ts „store: anderer client steht daneben und beruehrt die erste zeile nicht“.
- [x] **AC-6:** Fehlerverhalten der Ablage bleibt: GIVEN `storeRefreshToken` WHEN die `clientId` leer oder keine Zeichenkette ist, das Konto unbekannt ist (23503) oder die Verbindung geschlossen ist THEN wirft es bei leerer `clientId` vor der Datenbank (keine Zeile geschrieben), antwortet bei unbekanntem Konto `false` ohne Zeile, und wirft bei geschlossener Verbindung weiter. Test: server/test/apple-vault.test.ts „vault fehlbedienung: client_id“ und „store: unbekanntes konto“ (bestehende Tests, unverändert grün); „store: überschreibt“ und „store: blob gehört zum konto“ bleiben ebenfalls unverändert grün.
- [x] **AC-7:** `deleteAccount` mit zwei Zeilen: GIVEN ein Konto mit Token-Zeilen für die Clients `com.henning.looseends.web` und `com.henning.looseends` (in dieser Einfügereihenfolge), dazu Sitzung, Transkript und Auftrag, und ein zweites Konto WHEN `deleteAccount` läuft THEN ist das Ergebnis `{ deleted: true, tokens: [ { blob: <Blob von com.henning.looseends>, clientId: "com.henning.looseends" }, { blob: <Blob von …web>, clientId: "com.henning.looseends.web" } ] }` (sortiert nach `client_id`, nicht nach Einfügereihenfolge), alle Zeilen des Kontos sind weg, das zweite Konto ist unberührt. Test: server/test/accounts.test.ts „deleteAccount: zwei token-zeilen kommen als sortierte liste, konto ganz weg“.
- [x] **AC-8:** `deleteAccount` ohne Zeile und mit unbekanntem Konto: GIVEN ein Konto ohne Token-Zeile und ein anderes Konto mit Daten WHEN `deleteAccount` für das erste und für `"kein-konto"` läuft THEN ist das Ergebnis für das erste `{ deleted: true, tokens: [] }` (alle Zeilen weg), für das unbekannte `{ deleted: false, tokens: [] }`, und das andere Konto ist unverändert (Zeilenzahlen je Tabelle). Test: server/test/accounts.test.ts „deleteAccount: ohne token-zeile und unbekanntes konto“.
- [x] **AC-9:** Löschen im Rundweg mit Tokens: GIVEN ein Konto, dessen Token über `storeRefreshToken` (App-ID und Web-ID) abgelegt wurden WHEN `deleteAccount` läuft THEN lassen sich beide Blobs der Liste mit `decryptToken` und dem Konto als AAD zum jeweils abgelegten Klartext entschlüsseln und gehören zur jeweiligen `clientId`. Test: server/test/apple-vault.test.ts „store: rundweg ueber deleteAccount mit zwei clients“.
- [x] **AC-10:** Route `/auth/delete` mit App- und Web-Token: GIVEN ein Konto mit einem App-Token (Client = `config.clientIds[0]`) und einem Web-Token (Client = `config.webClientId`), beide mit eigenem Klartext abgelegt, `config.webClientId` gesetzt, Apple antwortet 200 WHEN `POST /auth/delete` mit der Sitzung läuft THEN antwortet die Route 204 mit leerem Körper, das Konto und alle Zeilen sind weg, es gibt genau zwei Widerrufe, in der Reihenfolge der Liste (nach `client_id`), jeder mit seinem eigenen Klartext im Formularfeld `token` und seiner eigenen `client_id` im Feld `client_id` (App-Token mit der App-ID, Web-Token mit der Web-ID, nie vertauscht), und das Protokoll ist leer. Beim Widerruf ist das Konto schon gelöscht. Test: server/test/auth.test.ts „auth: loeschen widerruft app und web token je mit eigener client_id“.
- [x] **AC-11:** Ein Widerruf scheitert, der andere läuft trotzdem: GIVEN dasselbe Konto wie AC-10 und Apple antwortet auf den Widerruf der ersten Zeile in Fall (a) mit `invalid_grant`, in Fall (b) mit einem Netzfehler (der Fake wirft), auf den der zweiten jeweils mit 200 WHEN `POST /auth/delete` läuft THEN antwortet die Route 204, beide Widerrufe wurden versucht (zwei Aufrufe am Fake), das Konto ist weg und das Protokoll ist genau `["apple revoke failed"]`; gilt gespiegelt (zweite Zeile scheitert, erste gelingt) mit demselben Ergebnis. Test: server/test/auth.test.ts „auth: ein widerruf scheitert, der andere laeuft, 204 und genau ein failed“.
- [x] **AC-12:** Web-Token ohne konfigurierte Web-ID: GIVEN dasselbe Konto wie AC-10, aber `config.webClientId` ist nicht gesetzt WHEN `POST /auth/delete` läuft THEN antwortet die Route 204, es gibt genau einen Widerruf (das App-Token, mit der App-ID), für die Web-Zeile geht kein Netzaufruf hinaus, und das Protokoll ist genau `["apple revoke skipped"]`; das Konto ist weg. Test: server/test/auth.test.ts „auth: web token ohne webClientId wird uebersprungen ohne netz“.
- [x] **AC-13:** Je Zeile überspringen, keine Zeile einmal: GIVEN je ein Konto mit (a) einer Zeile, deren `client_id` nicht mehr konfiguriert ist, (b) einer Zeile mit anderem `tokenKey` (nicht entschlüsselbar), (c) einer App-Zeile und einer unbekannten Zeile, (d) einer leeren Klartext-Zeile, (e) gar keiner Zeile, (f) einer App-Zeile, aber ohne `config` und `keys` WHEN `POST /auth/delete` läuft THEN antwortet die Route jeweils 204 und das Konto ist weg; die Zahl der Widerrufe ist (a) 0, (b) 0, (c) 1, (d) 0, (e) 0, (f) 0, das Protokoll ist in jedem der sechs Fälle genau `["apple revoke skipped"]` (je übersprungener Zeile ein Eintrag, bei (c) also einer für die unbekannte Zeile, bei (e) ohne Zeile genau einer, bei (f) einer für die nicht widerrufbare Zeile). Der bisherige Fall „client_id NULL“ entfällt (nach 005 unmöglich, siehe AC-16). Test: server/test/auth.test.ts „auth: widerruf entfaellt je zeile, keine zeile genau ein skipped“.
- [x] **AC-14:** Nebenläufigkeit beim Löschen: GIVEN ein Konto mit zwei Token-Zeilen WHEN zwei `POST /auth/delete` mit zwei Sitzungen desselben Kontos gleichzeitig laufen THEN antworten sie genau mit 204 und 401 (sortiert), das Konto ist weg, und es gibt genau zwei Widerrufe (einer je Zeile, nicht vier). Test: server/test/auth.test.ts „auth: zwei loeschungen gleichzeitig mit zwei tokens, widerrufe nur einmal“.
- [x] **AC-15:** Protokoll ohne Geheimnisse: GIVEN der bestehende Lauf „log ohne geheimnisse“, erweitert um ein Konto mit App- und Web-Token WHEN gelöscht wird (mit und ohne `log`-Funktion, mit Apple-Fehler, mit Netzfehler, ohne `config`) THEN besteht jede Zeile aus genau einem der Wörter `apple revoke skipped`, `apple revoke failed`, und keine Zeile enthält Refresh-Token (App und Web), Code, die Web-ID, die App-IDs, Konto-ID, Sitzungstoken, `sub` oder Fehlertext; stdout und stderr bleiben still (bestehender Test „stille und einheitliche ablehnung loeschen“ unverändert grün). Test: server/test/auth.test.ts „auth: log ohne geheimnisse“ (erweitert).
- [x] **AC-16:** `/auth/apple` bleibt unverändert, bestehende Tests angepasst: GIVEN die Anmeldungen über `/auth/apple` WHEN zweimal mit derselben App-ID angemeldet wird THEN ersetzt die zweite den Blob (eine Zeile); GIVEN ein Konto, das sich mit zwei verschiedenen App-IDs anmeldet THEN stehen zwei Zeilen (je `aud`), die erste unberührt. Alle übrigen Anmeldetests (Rundweg je `aud`, Ablehnungen, 23503, Fehlerfenster) bleiben unverändert grün. Die an die neue Form angepassten Tests sind im Changelog einzeln genannt. Test: server/test/auth.test.ts „auth: zweite anmeldung ersetzt schluessel nur je client“ (ersetzt „auth: zweite anmeldung ersetzt schluessel“).
- [x] **AC-17:** Gesamtlauf: GIVEN der fertige Schnitt WHEN `./server/scripts/test-local.sh` (typecheck + alle Tests) läuft THEN ist er grün und räumt auf; `oauth-return.test.ts`, `oauth-interaction.test.ts`, `oauth-provider.test.ts`, `main.test.ts`, `apple-client.test.ts` laufen unverändert grün; es gibt keinen neuen Eintrag in `server/package.json`. Dateiliste (neun Dateien) und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Test: Gesamtlauf `./server/scripts/test-local.sh` und CI `server.yml`; Dateiliste in `/60-validate`.

## Dialog

### Runde 1
**Adversary:** Fordere Beweis fuer jedes AC, dass die Tests wirklich das AC pruefen und nicht nur gruen sind (Reihenfolge nach client_id, Netzfehler, kein Netz bei fehlender Web-ID, genau zwei Widerrufe).
**Implementierer:** Gesamtlauf selbst ausgefuehrt: `./server/scripts/test-local.sh` (tsc --noEmit gruen, 345 tests, 345 pass, 0 fail, 0 skipped), gespeichert in docs/artifacts/feat-621-s4c-web-token/adversary-test-output.txt. Zuordnung:
- AC-1/2/3 Migration: Code reference: server/migrations/005_apple_tokens_per_client.sql:4 (DELETE NULL, SET NOT NULL, DROP alter PK, ADD PRIMARY KEY (account_id, client_id)); Runner wickelt BEGIN/COMMIT selbst (server/src/migrate.ts:57), die Datei hat keines, also eine Transaktion. Tests: Code reference: server/test/schema.test.ts:273, :296, :317. Evidence: Zeile ohne client_id faellt weg, B byte-gleich, Form, 23502/23505/Kaskade.
- AC-4/5/6/9 Ablage: Code reference: server/src/apple-vault.ts:39 (ON CONFLICT (account_id, client_id), client_id nicht mehr im SET, leere clientId wirft vor der DB, 23503 gibt false). Tests: Code reference: server/test/apple-vault.test.ts:132, :148, :202.
- AC-7/8 Loeschen: Code reference: server/src/accounts.ts:44 (erst Sperre FOR UPDATE auf accounts, unbekannt gibt deleted false und tokens leer, dann Tokens ORDER BY client_id). Test: Code reference: server/test/accounts.test.ts:150 fuegt Web zuerst ein und erwartet App zuerst, prueft also die Sortierung nach client_id wirklich; ohne Token-Zeile tokens leer.
- AC-10 bis AC-16: Code reference: server/src/auth.ts:98 (revokeOne: je Zeile bekannt-Pruefung gegen clientIds und webClientId, Entschluesselung mit Konto als AAD, skipped bei unbekannt, nicht entschluesselbar oder leer, failed nur wenn ok false) und server/src/auth.ts:115 (revokeAfterDelete: leere Liste ein skipped, sonst sequentiell). Tests: Code reference: server/test/auth.test.ts:471 (client_id und token je Formular, Reihenfolge App vor Web, Konto beim Widerruf schon weg), :492 (invalid_grant UND werfender Fake, je Zeile 1 und 2 scheiternd, 2 Aufrufe, genau ein failed), :513 (ohne webClientId ein Widerruf, ein skipped), :527 (zwei Sitzungen gleichzeitig, 204/401, genau 2 Widerrufe), :563, :590, :94.
**Bewertung Runde 1:** Alle Punkte belegt, kein Fund bisher. Runde 2 greift gezielt Randfaelle an.

### Runde 2
**Adversary:** Kann ein Widerruf nach aussen werfen? Race storeRefreshToken gegen deleteAccount? Sperrreihenfolge? Protokoll mit Werten? Funktionslaenge?
**Implementierer:**
- Werfen: revokeOne ruft revokeToken nur bei bekannter, konfigurierter Client-ID und nichtleerem Klartext; unbekannte ID und leerer Token sind vorher abgefangen (auth.ts:98-107), Netzfehler kommen als ok false zurueck (Test :492 mit werfendem Fake).
- Race: deleteAccount sperrt zuerst die accounts-Zeile (accounts.ts:48) und liest die Tokens erst danach. Ein paralleles INSERT von storeRefreshToken wartet (FOR KEY SHARE) und bekommt dann 23503 und false, oder es ist vorher committed und wird mitgelesen. Zweites gleichzeitiges Loeschen findet nach der Sperre kein Konto (401), Test auth.test.ts:527.
- Protokoll: nur die Literale apple revoke skipped und apple revoke failed; kein console.* in den drei Quelldateien (grep leer); Test auth.test.ts:590.
- Funktionslaenge: deleteAccount etwa 30 Zeilen, revokeOne etwa 12, storeRefreshToken etwa 15.
- Regression: tsc gruen, 345 Tests gruen inklusive oauth-return, oauth-interaction, oauth-provider, main, apple-client (AC-17).
**Bewertung Runde 2:** keine Bruchstelle. Hinweis LOW: Widerrufe laufen sequentiell, bis zu zwei Timeouts Wartezeit.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/auth.ts:115
  Description: revokeAfterDelete widerruft sequentiell, bei zwei haengenden Apple-Aufrufen wartet die Antwort bis zu zwei Timeouts.
  Spec requirement: AC-10 — Widerrufe in der Reihenfolge der Liste
  Conflict: kein Verstoss, nur Latenz; Spec fordert die Reihenfolge.
  Remediation: keine noetig.

Confirmation:
  AC: AC-1 bis AC-17
  Code reference: server/src/accounts.ts:44
  Evidence: siehe Runde 1 und 2, 345 von 345 Tests gruen, tsc gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/migrations/005_apple_tokens_per_client.sql:4
  Evidence: siehe Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/apple-vault.ts:39
  Evidence: siehe Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/test/schema.test.ts:273
  Evidence: siehe Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/test/apple-vault.test.ts:132
  Evidence: siehe Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/test/accounts.test.ts:150
  Evidence: siehe Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/test/auth.test.ts:471
  Evidence: siehe Runde 1.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED — alle 17 ACs belegt, 345 Tests gruen (0 fail, 0 skipped), nur LOW-Hinweis F001.

## Geprüfte Dateien

- sha256:0b265b404a8d60ce007a6c67dc87800175ad664def5cd5dac5a6742e3f4b9f48  server/migrations/005_apple_tokens_per_client.sql
- sha256:184124d7cf21ece4ad3e3b681185b2a9af1caf0402337b4d3a1ff8f7aad5bd48  server/src/accounts.ts
- sha256:86de5b2767cdbc70a99e63cb0ff2a9bab96385efd24552c066acf2c254ed97ac  server/src/apple-vault.ts
- sha256:867b2c2f01c9a7dec0b1204ccfe6b58016f3ca5efec0269ba2af62c748b5d0a1  server/src/auth.ts
- sha256:84ad58e59d5252b23d653def8689250ceb995a32340d1150cd2397d5a7b85db4  server/test/accounts.test.ts
- sha256:e655822f6bba6e3d1ad39b83a041f89deec4ff8451c368f5bd9f80bfcc516adc  server/test/apple-vault.test.ts
- sha256:fd4e351c5a4ad257bef83b17d850e31ae9531757dc880abab96898f923a786cc  server/test/auth.test.ts
- sha256:493e993c66376ba0190ac2a09c875e137b11aca1a7d3d741a4e36c38a1f2b434  server/test/schema.test.ts

## Prüfbasis

- base: 3306f546b3e849f4f0b6b7978486661b9fcd15e6
- blob:60c647957370faa6b8b342625aca3c32127fe0bd  server/migrations/005_apple_tokens_per_client.sql
- blob:cd5c9326788d4e88f2c7f576c5bbfbb0e31bed52  server/src/accounts.ts
- blob:c031acf94b5c2d995e34a73b13cef3be77525265  server/src/apple-vault.ts
- blob:c7bc16071e330638584a43b5213f18b868a15d7c  server/src/auth.ts
- blob:97d63f9177bc0e585bca77f0508c390dc8b202c9  server/test/accounts.test.ts
- blob:4c71e2362cdf798fcf4d6ead9775a715aa498398  server/test/apple-vault.test.ts
- blob:c28b67ed71e45ee0de42bbd8ff8d87f0347337b8  server/test/auth.test.ts
- blob:57ded1536566d541199ffc594946eae188ff2893  server/test/schema.test.ts
