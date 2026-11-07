---
entity_id: feat-621-schnitt-4c1-ablage-je-client
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: feat-621-s4c-web-token
---

# Spec: Apple-Token je Konto und Client ablegen und beim Löschen alle widerrufen (Schnitt 4c-1, #621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 4c-1; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte).
Analyse: `docs/context/feat-621-s4c-web-token.md` (Abschnitte „Recherche“, „Analysis“, „Wege im Vergleich“, „Empfehlung“); Vorgänger: `docs/specs/feat-621-schnitt-4b2a-rueckweg.md` (Verzicht auf das Web-Token, Alternative F), `docs/specs/feat-621-schnitt-4b2b-finish.md`, #615 S2b-2 (Vault), S3a (`client_id`, Migration 003), S3c-1 (Löschen und Widerruf). Folge: Schnitt 4c-2 (der Rückweg `oauth-return.ts` speichert das Web-Token), danach S5 (Zustimmung) und S6 (Betrieb).

## Für den PO

Wenn Claude sich im Browser mit Loose Ends verbindet, meldet sich der Nutzer über Apple an, und Apple gibt dem Dienst dafür eine Berechtigung. Die App bekommt bei ihrer eigenen Anmeldung ebenfalls eine. Löscht jemand sein Konto, muss der Dienst **beide** bei Apple zurückgeben, sonst bleibt eine Berechtigung bei Apple liegen. Heute kann der Dienst pro Konto nur **eine** merken. Dieser Schnitt baut die Grundlage: Der Dienst merkt sich je Konto eine Berechtigung **je Zugang** (App und Browser getrennt) und gibt beim Löschen jede mit ihrer eigenen Kennung zurück.

Für dich ändert sich **nichts Sichtbares**: Der Dienst ist von außen noch nicht erreichbar, die App und deine Daten sind nicht berührt, und in Produktion ist die betroffene Tabelle leer. Der Browser-Zugang selbst legt noch nichts ab; das ist der nächste Schnitt (4c-2). **Zu entscheiden hast du nur eines:** Der Schnitt ist größer als üblich (neun statt vier bis fünf Dateien, rund 300 statt 250 Zeilen), weil die Teile nur zusammen lauffähig sind und das Löschen gründlich getestet wird; mit der Freigabe dieser Spec nimmst du das an.

## Purpose

Heute hält `apple_tokens` genau eine Zeile je Konto (Primärschlüssel `account_id`). Der Rückweg der Browser-Anmeldung bekommt ein zweites Refresh-Token (Services ID) für dasselbe Konto (App und Browser sind über `apple_sub` dasselbe Konto); eine Ablage würde das App-Token überschreiben, und `deleteAccount` bräche bei zwei Zeilen: sein `LEFT JOIN` liefert dann zwei Zeilen, `rowCount !== 1` gilt als „unbekanntes Konto“, und das Löschen scheitert fälschlich mit 401. Dieser Schnitt behebt beides, **ohne dass etwas Neues abgelegt wird** (Produktwirkung: keine):

1. **Migration `server/migrations/005_apple_tokens_per_client.sql`** (kein `BEGIN`/`COMMIT`, der Runner wickelt die Transaktion): Zeilen mit `client_id IS NULL` löschen (vor 003 gespeichert, nie widerrufbar; Produktion hat keine Zeilen, weil `APPLE_*` dort nicht gesetzt ist), `client_id` auf `NOT NULL`, den alten Primärschlüssel `apple_tokens_pkey` (`PRIMARY KEY (account_id)`) entfernen und durch `PRIMARY KEY (account_id, client_id)` ersetzen.
2. **`storeRefreshToken`** (`apple-vault.ts`): Upsert `ON CONFLICT (account_id, client_id)`. Gleiches Paar: ersetzt den Blob, `created_at = now()`. Anderer Client desselben Kontos: zweite Zeile, die erste bleibt unberührt. Signatur und Fehlerverhalten bleiben (leere `clientId` wirft vor der Datenbank, 23503 ergibt `false`).
3. **`deleteAccount`** (`accounts.ts`): erst das Konto sperren (`SELECT id FROM accounts WHERE id = $1 FOR UPDATE`; keine Zeile: `ROLLBACK`, `{ deleted: false, tokens: [] }`), dann alle Tokens lesen (`SELECT refresh_token_enc, client_id FROM apple_tokens WHERE account_id = $1 ORDER BY client_id`), der Rest wie heute. Neuer Typ `Deletion = { deleted: boolean; tokens: { blob: Buffer; clientId: string }[] }` (ersetzt `appleToken` und `clientId`).
4. **`revokeAfterDelete`** (`auth.ts`): je Token-Zeile, nacheinander, best effort, nach dem Commit. Bekannt ist eine Zeile, wenn `config` gesetzt ist und `config.clientIds.includes(clientId)` oder (`config.webClientId` gesetzt und `clientId === config.webClientId`). Unbekannt, nicht entschlüsselbar oder leer: Protokoll `apple revoke skipped` für diese Zeile, kein Netz. Sonst Widerruf mit der **eigenen** `clientId` der Zeile (Apple TN3107: ein Token muss mit der Kennung widerrufen werden, für die es ausgestellt wurde); nicht ok: `apple revoke failed` für diese Zeile. Keine Zeile: genau einmal `apple revoke skipped` (heutiges Verhalten). Ein Fehlschlag einer Zeile hält die nächste nicht auf. Die Antwort bleibt 204, Apple ändert sie nie. Protokoll nie mit Werten.
5. **Unverändert:** `/auth/apple` (`signIn`) speichert weiter mit `verdict.aud`; `revokeToken`, `encryptToken`, `decryptToken`, `oauth-return.ts`.

**Regeln vor Modell:** Datenbank-, Protokoll- und Sicherheitsablauf ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Festlegungen aus der Analyse (Recherche 2026-11-06):

- **Je Client eine Zeile, jede mit ihrer eigenen ID widerrufen.** Apple dokumentiert den Widerruf als „The user session associated with the token provided is revoked“, `client_id` als „The identifier (App ID or Services ID) for your app“; TN3107 nennt `invalid_grant`, wenn „the client_id does not match the client for which the refresh_token was issued“. Die Wirkung eines Widerrufs über die Client-Grenze hinweg ist **nicht dokumentiert** (Forum 844628 ohne Antwort). Je Client eine Zeile und je Zeile der eigene Widerruf braucht diese Wirkung nicht zu kennen. Quellen: https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens, https://developer.apple.com/documentation/technotes/tn3107-resolving-sign-in-with-apple-response-errors, https://developer.apple.com/forums/thread/844628, https://github.com/aveer-dev/boxies/pull/134.
- **Konto zuerst sperren, dann Tokens lesen.** Die Sperre (`FOR UPDATE` auf `accounts`) steht vor dem Lesen, damit zwei gleichzeitige Löschungen nicht beide die Liste bekommen: die zweite wartet, findet nach dem Commit keine Zeile und ergibt `deleted: false`. Widerrufe laufen damit genau einmal je Zeile.
- **Zeilen ohne `client_id` fallen weg.** Sie sind nie widerrufbar (der Widerruf verlangt die Kennung); Produktion hat sie nicht. Damit ist `NOT NULL` möglich und der Primärschlüssel eindeutig.
- **Protokoll:** weiter nur die festen Ereignisse `apple revoke skipped` und `apple revoke failed`, nie Token, Konto-ID, `client_id`, `sub` oder Fehlertext; das `detail` des 23503-Fehlers nennt die Konto-ID und wird nie protokolliert.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt den Plan aus dem ADR-21-Nachtrag (Schnitt 4, Apple in der Interaction des Ausstellers) und die in 4b-2a vertagte Entscheidung zur Token-Ablage um; kein neues Verfahren, keine neue Abhängigkeit, ADR-21 bleibt unberührt.

**Rationale:** Die Ablage je Client ist die einzige Wahl, die nach der Kontolöschung keine Berechtigung bei Apple liegen lässt, ohne eine undokumentierte Wirkung vorauszusetzen. Sie ist von der Speicherung im Rückweg trennbar (4c-2) und allein belegbar (Testdatenbank, Fake-Apple).

## Source

**Files:** `server/migrations/005_apple_tokens_per_client.sql` (neu), `server/src/apple-vault.ts` (ändern), `server/src/accounts.ts` (ändern), `server/src/auth.ts` (ändern), `server/test/schema.test.ts` (ändern), `server/test/apple-vault.test.ts` (ändern), `server/test/accounts.test.ts` (ändern), `server/test/auth.test.ts` (ändern), `CLAUDE.md` (ändern).
**Identifier:** `storeRefreshToken`, `deleteAccount`, `Deletion`, `revokeAfterDelete`, `deleteAccountRoute`, `signIn`, `AppleConfig` (`clientIds`, `webClientId`, `tokenKey`), `revokeToken`, `decryptToken`, `apple_tokens`, `apple_tokens_pkey`

### Schnittstelle

- **`005_apple_tokens_per_client.sql`** (neu), in dieser Reihenfolge:
  1. `DELETE FROM apple_tokens WHERE client_id IS NULL;`
  2. `ALTER TABLE apple_tokens ALTER COLUMN client_id SET NOT NULL;`
  3. `ALTER TABLE apple_tokens DROP CONSTRAINT apple_tokens_pkey;` (Name aus der Postgres-Konvention `<Tabelle>_pkey` für den Primärschlüssel aus 002; AC-2 belegt ihn an der Datenbank)
  4. `ALTER TABLE apple_tokens ADD PRIMARY KEY (account_id, client_id);`
  - Der Fremdschlüssel `account_id → accounts(id) ON DELETE CASCADE` und die Spalten `refresh_token_enc`, `created_at` bleiben. Kopfkommentar englisch, nennt, warum Zeilen ohne `client_id` fallen (nie widerrufbar, Produktion leer). Die Migration ist nach der ersten Anwendung nur noch additiv zu ergänzen (Regel des Runners).
- **`apple-vault.ts`**: `storeRefreshToken(pool, accountId, blob, clientId): Promise<boolean>` mit `ON CONFLICT (account_id, client_id) DO UPDATE SET refresh_token_enc = EXCLUDED.refresh_token_enc, created_at = now()`. Kommentar darüber: ein Token je Konto und Client. Alles andere unverändert.
- **`accounts.ts`**: `export type Deletion = { deleted: boolean; tokens: { blob: Buffer; clientId: string }[] }`. `deleteAccount(pool, accountId)`: `BEGIN`; `SELECT id FROM accounts WHERE id = $1 FOR UPDATE`; `rowCount !== 1` → `ROLLBACK`, `{ deleted: false, tokens: [] }`; `SELECT refresh_token_enc, client_id FROM apple_tokens WHERE account_id = $1 ORDER BY client_id`; Löschung von `order_results`, `orders`, `transcripts`, `oauth_records` (Grant-Zeilen) und `accounts` wie heute; `COMMIT`; Rückgabe `{ deleted: true, tokens: rows.map(r => ({ blob: r.refresh_token_enc, clientId: r.client_id })) }`. Fehler: `ROLLBACK` und weiterwerfen (wie heute). Kommentar aktualisieren.
- **`auth.ts`**: `revokeAfterDelete(deps, accountId, deletion)`: bei `deletion.tokens.length === 0` genau einmal `deps.log?.("apple revoke skipped")` und Ende; sonst für jede Zeile in Reihenfolge der Liste (`for … of`, nacheinander) eine Hilfsfunktion `revokeOne(deps, accountId, token)` (Vorschlag), die `known` wie unter Purpose 4 bestimmt, entschlüsselt (`decryptToken(config.tokenKey, accountId, blob)`), bei Unbekannt/`null`/leer `skipped` meldet und sonst `revokeToken(plain, token.clientId, { config, fetch, now })` aufruft und bei `!ok` `failed` meldet. Eine Zeile wirft nie nach außen (`revokeToken` wirft nur bei unbekannter ID, und die ist durch `known` ausgeschlossen). `deleteAccountRoute` bleibt: Sitzung, `deleteAccount`, `!deleted` → 401, `revokeAfterDelete`, 204. Jede Funktion ≤ 50 Zeilen, Kommentare englisch.
- **Unverändert:** `signIn` und `/auth/apple`, `apple-client.ts`, `apple.ts`, `oauth-return.ts`, `oauth-*.ts`, `main.ts`, alle anderen Migrationen.

### Festlegungen

- **Nie 5xx aus dem Widerruf:** Apples Antwort ändert die Antwort der Route nie (204); der Löschpfad ist der einzige Weg, ein Konto zu entfernen, und wartet nie auf Apple-Einrichtung.
- **Kein Wert in Protokoll, Antwort oder Fehler:** weder Token noch Konto-ID, `client_id`, `sub` oder Fehlertext.
- **Alles Bestehende bleibt grün,** außer den unten ausdrücklich geänderten oder gestrichenen Tests (AC-16 und Changelog).
- **Stil:** Kommentare knapp auf Englisch; Tests `node:test` + `node:assert/strict`, eingereichtes `fetch`, kein Netz, Wegwerf-Schema je Test.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `revokeToken` (`apple-client.ts`): akzeptiert App-IDs und `webClientId`, wirft bei anderer ID vor dem Netz | bestehend, ungeändert |
| `AppleConfig` (`apple.ts`): `clientIds`, `webClientId?`, `tokenKey` | bestehend, ungeändert |
| Migrations-Runner (`migrate`, Transaktion je Datei, lückenlose Nummern) | bestehend, ungeändert |
| Tests: `migrated`, `freshPool`, `filled` (`accounts.test.ts`), `member`, `deleter`, `rig`, `onConnect`, `appleError`, `ok200` (`auth.test.ts`) | bestehend, einzelne Helfer angepasst |
| Downstream | Schnitt 4c-2 (Rückweg speichert das Web-Token mit `webClientId`), S5, S6 |

## Acceptance Criteria

Wenn nicht anders genannt, läuft jeder Test gegen ein Wegwerf-Schema mit allen Migrationen (`migrated`); Apple ist `fakeApple` (`rig`/`deleter`), das Formular jedes Widerrufs wird im Fake gelesen.

- **AC-1:** Migration, Datenwirkung: GIVEN ein Schema mit Migration 001 bis 004 und einem Konto A mit einer Token-Zeile ohne `client_id` (vor 003 gespeichert) sowie einem Konto B mit einer Token-Zeile mit `client_id` und eigenem Blob WHEN Migration 005 angewendet wird THEN meldet der Runner genau `["005_apple_tokens_per_client.sql"]`, die Zeile von A ist verschwunden, die von B ist byte-gleich (Blob, `created_at`, `client_id`) erhalten, beide Konten, Sitzungen und andere Tabellen sind unberührt; ein zweiter Lauf meldet `[]`. Test: server/test/schema.test.ts „migration 005: zeile ohne client_id faellt weg, rest bleibt“.
- **AC-2:** Migration, Form: GIVEN ein Schema nach Migration 005 WHEN die Struktur von `apple_tokens` gelesen wird THEN ist `client_id` `NOT NULL` (`information_schema.columns`), der Primärschlüssel heißt `apple_tokens_pkey` und lautet `PRIMARY KEY (account_id, client_id)` (`pg_get_constraintdef`), der Fremdschlüssel `account_id` auf `accounts(id)` mit `ON DELETE CASCADE` besteht weiter (`confdeltype = 'c'`), und der alte Primärschlüssel nur auf `account_id` besteht nicht mehr (genau ein Primärschlüssel). Vor dem Test bei Migration 002 steht fest, dass der alte Name `apple_tokens_pkey` war (derselbe Test liest ihn im Stand nach 004 und prüft `PRIMARY KEY (account_id)`). Test: server/test/schema.test.ts „migration 005: form von apple_tokens“.
- **AC-3:** Migration, Verhalten der Schlüssel: GIVEN ein Schema nach 005 und ein Konto WHEN (a) eine Zeile ohne `client_id` eingefügt wird, (b) zwei Zeilen mit verschiedener `client_id` für dasselbe Konto eingefügt werden, (c) eine zweite Zeile mit demselben Paar eingefügt wird, (d) das Konto gelöscht wird THEN (a) wird mit `23502` abgelehnt, (b) gelingt (zwei Zeilen), (c) wird mit `23505` abgelehnt, (d) entfernt beide Zeilen durch die Kaskade. Test: server/test/schema.test.ts „migration 005: zwei clients je konto, null und doppelt abgelehnt, kaskade“.
- **AC-4:** Upsert je Paar, gleiches Paar ersetzt: GIVEN ein Konto mit einer Zeile (Client X, Blob 1) und `created_at` auf eine Stunde zuvor gesetzt WHEN `storeRefreshToken` mit Client X und Blob 2 aufgerufen wird THEN antwortet es `true`, es gibt weiter genau eine Zeile, ihr Blob ist Blob 2, `client_id` ist X, `created_at` ist vorgerückt. Test: server/test/apple-vault.test.ts „store: gleiches paar ersetzt blob und created_at“.
- **AC-5:** Upsert je Paar, anderer Client steht daneben: GIVEN ein Konto mit einer Zeile (Client X, Blob 1, `created_at` zuvor gesetzt) WHEN `storeRefreshToken` mit Client Y und Blob 2 aufgerufen wird THEN antwortet es `true`, es gibt zwei Zeilen, die Zeile von X ist byte-gleich unberührt (Blob 1, `created_at`), die von Y trägt Blob 2; ein weiteres Konto bleibt unberührt. Test: server/test/apple-vault.test.ts „store: anderer client steht daneben und beruehrt die erste zeile nicht“.
- **AC-6:** Fehlerverhalten der Ablage bleibt: GIVEN `storeRefreshToken` WHEN die `clientId` leer oder keine Zeichenkette ist, das Konto unbekannt ist (23503) oder die Verbindung geschlossen ist THEN wirft es bei leerer `clientId` vor der Datenbank (keine Zeile geschrieben), antwortet bei unbekanntem Konto `false` ohne Zeile, und wirft bei geschlossener Verbindung weiter. Test: server/test/apple-vault.test.ts „vault fehlbedienung: client_id“ und „store: unbekanntes konto“ (bestehende Tests, unverändert grün); „store: überschreibt“ und „store: blob gehört zum konto“ bleiben ebenfalls unverändert grün.
- **AC-7:** `deleteAccount` mit zwei Zeilen: GIVEN ein Konto mit Token-Zeilen für die Clients `com.henning.looseends.web` und `com.henning.looseends` (in dieser Einfügereihenfolge), dazu Sitzung, Transkript und Auftrag, und ein zweites Konto WHEN `deleteAccount` läuft THEN ist das Ergebnis `{ deleted: true, tokens: [ { blob: <Blob von com.henning.looseends>, clientId: "com.henning.looseends" }, { blob: <Blob von …web>, clientId: "com.henning.looseends.web" } ] }` (sortiert nach `client_id`, nicht nach Einfügereihenfolge), alle Zeilen des Kontos sind weg, das zweite Konto ist unberührt. Test: server/test/accounts.test.ts „deleteAccount: zwei token-zeilen kommen als sortierte liste, konto ganz weg“.
- **AC-8:** `deleteAccount` ohne Zeile und mit unbekanntem Konto: GIVEN ein Konto ohne Token-Zeile und ein anderes Konto mit Daten WHEN `deleteAccount` für das erste und für `"kein-konto"` läuft THEN ist das Ergebnis für das erste `{ deleted: true, tokens: [] }` (alle Zeilen weg), für das unbekannte `{ deleted: false, tokens: [] }`, und das andere Konto ist unverändert (Zeilenzahlen je Tabelle). Test: server/test/accounts.test.ts „deleteAccount: ohne token-zeile und unbekanntes konto“.
- **AC-9:** Löschen im Rundweg mit Tokens: GIVEN ein Konto, dessen Token über `storeRefreshToken` (App-ID und Web-ID) abgelegt wurden WHEN `deleteAccount` läuft THEN lassen sich beide Blobs der Liste mit `decryptToken` und dem Konto als AAD zum jeweils abgelegten Klartext entschlüsseln und gehören zur jeweiligen `clientId`. Test: server/test/apple-vault.test.ts „store: rundweg ueber deleteAccount mit zwei clients“.
- **AC-10:** Route `/auth/delete` mit App- und Web-Token: GIVEN ein Konto mit einem App-Token (Client = `config.clientIds[0]`) und einem Web-Token (Client = `config.webClientId`), beide mit eigenem Klartext abgelegt, `config.webClientId` gesetzt, Apple antwortet 200 WHEN `POST /auth/delete` mit der Sitzung läuft THEN antwortet die Route 204 mit leerem Körper, das Konto und alle Zeilen sind weg, es gibt genau zwei Widerrufe, in der Reihenfolge der Liste (nach `client_id`), jeder mit seinem eigenen Klartext im Formularfeld `token` und seiner eigenen `client_id` im Feld `client_id` (App-Token mit der App-ID, Web-Token mit der Web-ID, nie vertauscht), und das Protokoll ist leer. Beim Widerruf ist das Konto schon gelöscht. Test: server/test/auth.test.ts „auth: loeschen widerruft app und web token je mit eigener client_id“.
- **AC-11:** Ein Widerruf scheitert, der andere läuft trotzdem: GIVEN dasselbe Konto wie AC-10 und Apple antwortet auf den Widerruf der ersten Zeile in Fall (a) mit `invalid_grant`, in Fall (b) mit einem Netzfehler (der Fake wirft), auf den der zweiten jeweils mit 200 WHEN `POST /auth/delete` läuft THEN antwortet die Route 204, beide Widerrufe wurden versucht (zwei Aufrufe am Fake), das Konto ist weg und das Protokoll ist genau `["apple revoke failed"]`; gilt gespiegelt (zweite Zeile scheitert, erste gelingt) mit demselben Ergebnis. Test: server/test/auth.test.ts „auth: ein widerruf scheitert, der andere laeuft, 204 und genau ein failed“.
- **AC-12:** Web-Token ohne konfigurierte Web-ID: GIVEN dasselbe Konto wie AC-10, aber `config.webClientId` ist nicht gesetzt WHEN `POST /auth/delete` läuft THEN antwortet die Route 204, es gibt genau einen Widerruf (das App-Token, mit der App-ID), für die Web-Zeile geht kein Netzaufruf hinaus, und das Protokoll ist genau `["apple revoke skipped"]`; das Konto ist weg. Test: server/test/auth.test.ts „auth: web token ohne webClientId wird uebersprungen ohne netz“.
- **AC-13:** Je Zeile überspringen, keine Zeile einmal: GIVEN je ein Konto mit (a) einer Zeile, deren `client_id` nicht mehr konfiguriert ist, (b) einer Zeile mit anderem `tokenKey` (nicht entschlüsselbar), (c) einer App-Zeile und einer unbekannten Zeile, (d) einer leeren Klartext-Zeile, (e) gar keiner Zeile, (f) einer App-Zeile, aber ohne `config` und `keys` WHEN `POST /auth/delete` läuft THEN antwortet die Route jeweils 204 und das Konto ist weg; die Zahl der Widerrufe ist (a) 0, (b) 0, (c) 1, (d) 0, (e) 0, (f) 0, das Protokoll ist in jedem der sechs Fälle genau `["apple revoke skipped"]` (je übersprungener Zeile ein Eintrag, bei (c) also einer für die unbekannte Zeile, bei (e) ohne Zeile genau einer, bei (f) einer für die nicht widerrufbare Zeile). Der bisherige Fall „client_id NULL“ entfällt (nach 005 unmöglich, siehe AC-16). Test: server/test/auth.test.ts „auth: widerruf entfaellt je zeile, keine zeile genau ein skipped“.
- **AC-14:** Nebenläufigkeit beim Löschen: GIVEN ein Konto mit zwei Token-Zeilen WHEN zwei `POST /auth/delete` mit zwei Sitzungen desselben Kontos gleichzeitig laufen THEN antworten sie genau mit 204 und 401 (sortiert), das Konto ist weg, und es gibt genau zwei Widerrufe (einer je Zeile, nicht vier). Test: server/test/auth.test.ts „auth: zwei loeschungen gleichzeitig mit zwei tokens, widerrufe nur einmal“.
- **AC-15:** Protokoll ohne Geheimnisse: GIVEN der bestehende Lauf „log ohne geheimnisse“, erweitert um ein Konto mit App- und Web-Token WHEN gelöscht wird (mit und ohne `log`-Funktion, mit Apple-Fehler, mit Netzfehler, ohne `config`) THEN besteht jede Zeile aus genau einem der Wörter `apple revoke skipped`, `apple revoke failed`, und keine Zeile enthält Refresh-Token (App und Web), Code, die Web-ID, die App-IDs, Konto-ID, Sitzungstoken, `sub` oder Fehlertext; stdout und stderr bleiben still (bestehender Test „stille und einheitliche ablehnung loeschen“ unverändert grün). Test: server/test/auth.test.ts „auth: log ohne geheimnisse“ (erweitert).
- **AC-16:** `/auth/apple` bleibt unverändert, bestehende Tests angepasst: GIVEN die Anmeldungen über `/auth/apple` WHEN zweimal mit derselben App-ID angemeldet wird THEN ersetzt die zweite den Blob (eine Zeile); GIVEN ein Konto, das sich mit zwei verschiedenen App-IDs anmeldet THEN stehen zwei Zeilen (je `aud`), die erste unberührt. Alle übrigen Anmeldetests (Rundweg je `aud`, Ablehnungen, 23503, Fehlerfenster) bleiben unverändert grün. Die an die neue Form angepassten Tests sind im Changelog einzeln genannt. Test: server/test/auth.test.ts „auth: zweite anmeldung ersetzt schluessel nur je client“ (ersetzt „auth: zweite anmeldung ersetzt schluessel“).
- **AC-17:** Gesamtlauf: GIVEN der fertige Schnitt WHEN `./server/scripts/test-local.sh` (typecheck + alle Tests) läuft THEN ist er grün und räumt auf; `oauth-return.test.ts`, `oauth-interaction.test.ts`, `oauth-provider.test.ts`, `main.test.ts`, `apple-client.test.ts` laufen unverändert grün; es gibt keinen neuen Eintrag in `server/package.json`. Dateiliste (neun Dateien) und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Test: Gesamtlauf `./server/scripts/test-local.sh` und CI `server.yml`; Dateiliste in `/60-validate`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/migrations/005_apple_tokens_per_client.sql` | CREATE | Zeilen ohne `client_id` löschen, `NOT NULL`, Primärschlüssel `(account_id, client_id)`, ≈ +10 |
| `server/src/apple-vault.ts` | MODIFY | Upsert `ON CONFLICT (account_id, client_id)`, Kommentar, ≈ +3/−3 |
| `server/src/accounts.ts` | MODIFY | `Deletion` mit Liste, Konto sperren, Tokens lesen, ≈ +14/−8 |
| `server/src/auth.ts` | MODIFY | Widerruf je Zeile mit eigener ID, Web-ID zugelassen, ≈ +22/−12 |
| `server/test/schema.test.ts` | MODIFY | neue Tests zu 005 (AC-1 bis AC-3), ≈ +45 |
| `server/test/apple-vault.test.ts` | MODIFY | AC-4, AC-5, AC-9; zwei Tests geändert, ≈ +30/−12 |
| `server/test/accounts.test.ts` | MODIFY | AC-7, AC-8; AC-7..AC-10-Tests auf neue Form, `filled` ohne NULL, ≈ +30/−14 |
| `server/test/auth.test.ts` | MODIFY | AC-10 bis AC-16; Fall „client_id NULL“ gestrichen, ≈ +70/−20 |
| `CLAUDE.md` | MODIFY | `server/`-Abschnitt: Zeile zu `apple-vault.ts`/`accounts.ts`, ≈ +2/−2 |

### Estimated Changes

- **Files: 9** (Code: `005_…sql`, `apple-vault.ts`, `accounts.ts`, `auth.ts`; Tests: `schema.test.ts`, `apple-vault.test.ts`, `accounts.test.ts`, `auth.test.ts`; Doku: `CLAUDE.md`). Das liegt **über dem Limit von 4 bis 5 Dateien**. Warum angenommen: Migration, Upsert und Löschpfad sind gekoppelt. Nach dem Primärschlüssel-Wechsel scheitert `ON CONFLICT (account_id)` (es gibt keinen passenden Constraint mehr), und ohne die Listen-Löschung bricht `/auth/delete` bei zwei Zeilen. Ein kleinerer Teil wäre allein nicht lauffähig oder nicht belegbar: Mit dem alten Primärschlüssel sind zwei Zeilen je Konto gar nicht herzustellen, also ließe sich weder der Upsert je Paar noch das Löschen mit Liste testen. Die vier Testdateien stehen jeweils für genau eine der drei Quelldateien plus die Migration. Die Überschreitung wird mit der Freigabe dieser Spec durch Henning angenommen.
- **Code ≈ 72 LoC, Tests ≈ 221 LoC, Doku ≈ 4 LoC, insgesamt ≈ 297 LoC** (Summe der Tabelle oben, Zeilen hinzugefügt, geändert und gelöscht). Das liegt **über dem Limit von ±250 LoC**. Warum angenommen: Die Last liegt in den Tests des Löschpfads (zwei Tokens, einer scheitert, Web-ID fehlt, je Zeile übersprungen, Nebenläufigkeit, Protokoll) und im Umbau der Alttests auf die neue Form; sie sind der Beleg, dass beim Löschen eines Kontos keine Berechtigung bei Apple liegen bleibt und das Löschen selbst nie scheitert, und lassen sich aus den oben genannten Kopplungsgründen nicht in einen späteren Schnitt verschieben. Präzedenz: 4b-2b (≈ 325 LoC, freigegeben 2026-11-06). Die Überschreitung von Dateizahl **und** LoC wird mit der Freigabe dieser Spec durch Henning angenommen. **Meldeschwelle beim Bauen:** wächst die Summe über 400 LoC, wird das vor dem Weiterbauen gemeldet (Erfahrung: Tests ≈ 2,5× Code, eher darüber).
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine neue Abhängigkeit. Eine Migration (005).
- Doku als Teil des Schnitts: `CLAUDE.md` (`server/`-Abschnitt) bei `apple-vault.ts` und `accounts.ts`: ein Token je Konto **und Client** (`ON CONFLICT (account_id, client_id)`, Migration 005), `deleteAccount` sperrt zuerst das Konto und gibt `tokens` als Liste, der Widerruf läuft je Zeile mit der eigenen `client_id` (App-IDs und Web-ID zugelassen).
- Seiteneffekte nach außen: keine. Der Dienst ist nicht erreichbar (nginx bis S6); in Produktion ist `apple_tokens` leer (`APPLE_*` dort nicht gesetzt), die Migration löscht und ändert dort nichts.

## Risiken

- **Der Löschpfad ist der einzige Weg, ein Konto zu entfernen.** Ein Fehler darin lässt Konten stehen (401) oder Berechtigungen bei Apple liegen. Gegenmittel: AC-7, AC-8, AC-10 bis AC-14, bestehende Tests zu Rennen und Datenbankfehler bleiben.
- **Primärschlüssel-Wechsel.** `DROP CONSTRAINT apple_tokens_pkey` setzt den Namen der Postgres-Konvention voraus; AC-2 liest ihn im Stand nach 004 aus der Datenbank. Der Runner wickelt die vier Anweisungen in eine Transaktion: scheitert eine, bleibt die Tabelle im alten Stand. Zwischen `DROP` und `ADD` ist nie ein Zustand ohne Schlüssel sichtbar.
- **Datenrisiko:** keines in Produktion (Tabelle leer). Auf anderen Umgebungen verschwinden Zeilen ohne `client_id`; sie waren nicht widerrufbar.
- **Zusätzliche Apple-Aufrufe beim Löschen:** je Konto bis zu zwei, nacheinander, je mit 5 s Zeitgrenze von `revokeToken`; die Antwort der Route ist erst danach fertig (wie bisher mit einem). Hängt Apple, verlängert sich das Löschen auf bis zu rund 10 s, ändert aber nie den Status.
- **Widerruf über Client-Grenzen undokumentiert.** Ob Apple das Widerrufen des einen Tokens das andere ungültig macht, ist offen (Forum 844628). Folge für diesen Schnitt: keine; ein bereits ungültiges zweites Token ergibt bei Apple 200 oder `invalid_grant` und höchstens ein `apple revoke failed`, nie ein anderes Ergebnis.
- **Werte im Protokoll:** das `detail` eines 23503-Fehlers nennt die Konto-ID. Gegenmittel: AC-15, `storeRefreshToken` fängt nur 23503 und gibt `false`, alle anderen Fehler werfen ohne Protokoll in dieser Datei.
- **Sperrreihenfolge.** Das Konto wird vor dem Lesen der Tokens gesperrt; `storeRefreshToken` schreibt gegen den Fremdschlüssel auf `accounts` und wartet daher auf die Löschung oder gibt nach ihr `false`. Ein Token, das zwischen Sperre und Löschung eingefügt würde, ist nicht möglich: der Fremdschlüssel nimmt ein Schlüsselteilen-Lock auf die Kontozeile, die `FOR UPDATE` hält.

## Test Plan

### Automated Tests (TDD RED)

RED: Migration 005 existiert nicht (AC-1 bis AC-3 scheitern an der Form), `storeRefreshToken` ersetzt statt zu ergänzen und scheitert nach der Migration an `ON CONFLICT (account_id)`, `Deletion.tokens` ist undefiniert (AC-7 bis AC-9, AC-10 bis AC-15 scheitern), der Test „zweite anmeldung ersetzt schluessel nur je client“ schlägt gegen den Altstand mit einer Zeile statt zweien fehl.

| Testname | AC |
|---|---|
| schema: „migration 005: zeile ohne client_id faellt weg, rest bleibt“ | AC-1 |
| schema: „migration 005: form von apple_tokens“ | AC-2 |
| schema: „migration 005: zwei clients je konto, null und doppelt abgelehnt, kaskade“ | AC-3 |
| apple-vault: „store: gleiches paar ersetzt blob und created_at“ | AC-4 |
| apple-vault: „store: anderer client steht daneben und beruehrt die erste zeile nicht“ | AC-5 |
| apple-vault: „vault fehlbedienung: client_id“, „store: unbekanntes konto“ (bestehend) | AC-6 |
| accounts: „deleteAccount: zwei token-zeilen kommen als sortierte liste, konto ganz weg“ | AC-7 |
| accounts: „deleteAccount: ohne token-zeile und unbekanntes konto“ | AC-8 |
| apple-vault: „store: rundweg ueber deleteAccount mit zwei clients“ | AC-9 |
| auth: „auth: loeschen widerruft app und web token je mit eigener client_id“ | AC-10 |
| auth: „auth: ein widerruf scheitert, der andere laeuft, 204 und genau ein failed“ | AC-11 |
| auth: „auth: web token ohne webClientId wird uebersprungen ohne netz“ | AC-12 |
| auth: „auth: widerruf entfaellt je zeile, keine zeile genau ein skipped“ | AC-13 |
| auth: „auth: zwei loeschungen gleichzeitig mit zwei tokens, widerrufe nur einmal“ | AC-14 |
| auth: „auth: log ohne geheimnisse“ (erweitert) | AC-15 |
| auth: „auth: zweite anmeldung ersetzt schluessel nur je client“ | AC-16 |
| `./server/scripts/test-local.sh`, `/60-validate` (Dateiliste per `git diff`) | AC-17 |

- [ ] Test 1 (AC-1 bis AC-3): GIVEN Altstand mit und ohne `client_id` WHEN Migration 005 THEN Altzeile weg, Rest erhalten, Schlüssel `(account_id, client_id)`, `NOT NULL`, Kaskade.
- [ ] Test 2 (AC-4 bis AC-6, AC-9): GIVEN ein Konto WHEN gleiches Paar, anderer Client, Fehlbedienung, Rundweg THEN ersetzt, daneben, unverändert, entschlüsselbar.
- [ ] Test 3 (AC-7, AC-8): GIVEN zwei, null Zeilen und ein unbekanntes Konto WHEN `deleteAccount` THEN sortierte Liste, leere Liste, `deleted: false`.
- [ ] Test 4 (AC-10 bis AC-13): GIVEN App- und Web-Token WHEN `/auth/delete` THEN zwei Widerrufe mit eigener ID, einer scheitert und der andere läuft, Web ohne ID übersprungen, je Zeile übersprungen.
- [ ] Test 5 (AC-14, AC-15, AC-16): GIVEN gleichzeitige Löschungen, Protokoll, Anmeldung THEN Widerrufe einmal je Zeile, keine Geheimnisse, `/auth/apple` ersetzt nur je Client.
- [ ] Test 6 (AC-17): GIVEN Altbestand und Gesamtlauf WHEN `./server/scripts/test-local.sh` THEN grün, keine neue Abhängigkeit.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): eine Zeile je Konto und Client, beim Löschen jede mit eigener ID widerrufen** | Migration 005, Upsert je Paar, `deleteAccount` mit Liste, Widerruf je Zeile | keine undokumentierte Wirkung vorausgesetzt (TN3107 verlangt die eigene Kennung); vollständig mit Testdatenbank und Fake-Apple belegbar; Berechtigung bleibt nach Kontolöschung nicht liegen | neun Dateien statt vier bis fünf, ein Primärschlüssel-Wechsel | — |
| **B Weg 1 der Analyse: Web-Token sofort widerrufen, nichts speichern** | im Rückweg nach der Prüfung `revokeToken(refreshToken, webClientId)`, keine Migration | ≈ 10 LoC, kein Löschpfad-Umbau | die Wirkung auf die App-Berechtigung desselben Nutzers ist unbelegt (Forum 844628 offen); könnte die App bei Apple abmelden; erst mit echtem Konto in S6 messbar | der Plan „Ablage je Client“; würde Spec 4b-2a Alternative F (Verzicht) und #615 S2b-2 „ein Token je Konto“ nachträglich bestätigen statt ändern; nur als Nachmessung nach S6 sinnvoll |
| **C Zeilen ohne `client_id` behalten:** eindeutiger Index `(account_id, client_id) NULLS NOT DISTINCT` (Postgres ≥ 15), Spalte nullable lassen | Altzeilen bleiben erhalten | kein Löschen in der Migration | die Zeilen sind nie widerrufbar, es blieben Daten ohne Zweck; `NULL` bliebe ein zulässiger Wert im Schlüssel und müsste überall gesondert behandelt werden | die Wahl „löschen und `NOT NULL`“; Produktion hat keine Zeilen, der Vorteil ist rein theoretisch |
| **D Zweite Tabelle `apple_web_tokens`** statt Primärschlüssel-Wechsel | App-Token bleibt wie heute, Web-Token in eigener Tabelle | keine Änderung am bestehenden Schlüssel | doppelte Logik in Upsert, Löschen und Widerruf; jeder weitere Client bräuchte eine weitere Tabelle | die Wahl einer Tabelle mit Client im Schlüssel |
| **E Status quo (nichts speichern, nichts widerrufen)** | Web-Berechtigung bleibt bei Apple liegen | kein Aufwand | verletzt das Ziel des Schnitts (Löschung ohne Rückgabe) | — |

A und B bis E sind in der Analyse behandelt (B als Weg 1, E als Weg 3). Die Alternative zu A bleibt offen: zeigt eine Messung nach S6, dass Apple den Widerruf je Client sauber trennt, könnte das Web-Token entfallen; kein Ticket nötig, solange A trägt.

## Out of Scope / Folgeschnitte

- **Schnitt 4c-2 „Rückweg speichert“:** `outcome()` in `oauth-return.ts` verschlüsselt das Web-Token mit `tokenKey` und speichert es mit `webClientId` nach `findOrCreate`; `false` (23503) ergibt `access_denied`, Datenbankfehler die feste 400; AC-14 aus 2a („web-token wird nicht gespeichert und nicht widerrufen“) wird dort umgedreht. Folgt direkt nach diesem Schnitt.
- **Zustimmungsseite und Erlaubnisliste (S5)**, **Betrieb (S6)** mit Services ID, nginx, Schlüsseln in Compose und Echtbrowser-Nachweis.
- **F001 und F002 aus 4b-2a** (LOW, Rückweg): nicht in diesem Schnitt.

## Abnahme

Kein Pfad der Geräteliste berührt. (Nur `server/` und `CLAUDE.md`, keine App, kein `project.yml`.) Die Abnahme endet nach den Tests: `./server/scripts/test-local.sh` (typecheck + `node --test` gegen ein Wegwerf-Postgres) grün und die CI `server.yml` auf dem PR grün. Ein Simulator-Durchlauf entfällt, weil es reiner Dienstcode ohne Oberfläche ist und der Dienst von außen nicht erreichbar ist; der Löschpfad wird in den Tests Ende-zu-Ende mit echter Datenbank, echtem Vault und `fakeApple` durchgespielt. Stufe 3 entfällt.

## Definition of Done

- [ ] AC-1 bis AC-17 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] Die in AC-16 und im Changelog genannten Tests sind umgestellt, umgedreht oder gestrichen, keine alten Namen mit falscher Aussage bleiben
- [ ] `CLAUDE.md` (`server/`-Abschnitt) aktualisiert: `apple-vault.ts` und `accounts.ts` (ein Token je Konto und Client, `deleteAccount` mit Liste, Widerruf je Zeile mit eigener ID, Web-ID zugelassen, Migration 005)
- [ ] #621 kommentiert (Stand Schnitt 4c-1; Folge: 4c-2 Rückweg speichert, S5, S6), Board-Karte aktuell

## Changelog

- 2026-11-06: Initial spec created (Schnitt 4c-1)
- 2026-11-06: Validierung: LoC-Schätzung an die Tabelle angeglichen (≈ 297 statt ≈ 215, über ±250, zur Freigabe gestellt), Migration 002 als Ort des alten Schlüssels, vollständige Testnamen in AC-6.
- 2026-11-06: **Gekippte oder angepasste bestehende Tests** (müssen im Bau ausdrücklich so behandelt werden):
  - `server/test/apple-vault.test.ts` „vault: client_id wird abgelegt und ersetzt“ (zeigt, dass ein anderer Client das Token ersetzt, Zeile 136 bis 140: `${CLIENT}.web` ersetzt, eine Zeile): **umgedreht**, ein anderer Client steht als zweite Zeile daneben (AC-5); der Teil „client_id wird abgelegt“ und „unbekanntes Konto ergibt false“ bleibt.
  - `server/test/apple-vault.test.ts` „store: rundweg über deleteAccount“ (`gone.appleToken`): **umbenannt und umgestellt** zu „store: rundweg ueber deleteAccount mit zwei clients“ auf `gone.tokens` (AC-9); der alte Name bleibt nicht als zweiter Test stehen.
  - `server/test/accounts.test.ts` „AC-7/AC-8/AC-10“, „AC-9“, „delete: rundweg mit client_id“ und der Test zu `oauth zeilen` (Zeile 195, `{ appleToken, clientId }`): **umgestellt** auf `{ deleted, tokens }`; die Hilfsfunktion `filled` legt Zeilen nur noch mit gesetzter `client_id` an, der Fall „Zeile aus 002-Zeit“ (`client_id` NULL) entfällt, weil nach 005 unmöglich.
  - `server/test/auth.test.ts` Rundweg der Anmeldung (Zeile 88 bis 89, `deletion.appleToken`/`deletion.clientId`): **umgestellt** auf `deletion.tokens`.
  - `server/test/auth.test.ts` „auth: zweite anmeldung ersetzt schluessel“ (zwei Anmeldungen mit `IDS[0]` und `IDS[1]` erwarten eine Zeile): **ersetzt** durch „auth: zweite anmeldung ersetzt schluessel nur je client“ (AC-16); verschiedene IDs ergeben jetzt zwei Zeilen.
  - `server/test/auth.test.ts` „auth: widerruf entfaellt, konto weg“, Fall „client_id NULL“ (`UPDATE apple_tokens SET client_id = NULL`): **gestrichen**, nach 005 unmöglich (`NOT NULL`); ersetzt durch den Schema-Test in AC-3 (a), der `NULL` mit `23502` ablehnt. Die übrigen Fälle gehen in „auth: widerruf entfaellt je zeile, keine zeile genau ein skipped“ (AC-13) über.
  - `server/test/auth.test.ts` „auth: log ohne geheimnisse“: **erweitert** um Konto mit App- und Web-Token (AC-15).
  - `server/test/schema.test.ts` Tests zu Migration 003 und 004: **unverändert gültig** (sie prüfen den Stand nach 003 bzw. 004 mit eigenem Migrationsordner).
