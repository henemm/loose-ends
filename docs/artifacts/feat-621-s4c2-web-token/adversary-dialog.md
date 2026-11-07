# Adversary Dialog — feat-621-s4c2-web-token
Spec: docs/specs/feat-621-schnitt-4c2-web-token-ablegen.md
Datum: 2026-11-07 22:12

## Checkliste
- [x] **AC-1:** Erfolg legt das Web-Token verschlüsselt ab: GIVEN ein gültiger Hinweg und ein gültiger Rückweg WHEN `POST /oauth/apple/return` läuft THEN antwortet er 303 mit Ticket `{ uid, accountId }`, es gibt genau eine Zeile in `apple_tokens`, ihre `account_id` ist die des Tickets und des angelegten Kontos, ihre `client_id` ist `webClientId`, ihr Blob entschlüsselt sich mit `decryptToken(withWeb.tokenKey, accountId, blob)` zum Token aus Apples Antwort, und der Klartext steht in keinem Byte der Zeile (Blob ohne die Zeichenfolge), in keiner Zeile von `oauth_records`, in keiner Antwort (Körper und Kopfzeilen) und in keiner Protokollzeile (`assertQuiet`); Apple sah keinen Widerruf (`revokes` ist 0). Dies **kehrt AC-14 aus 4b-2a um**. Test: server/test/oauth-return.test.ts „rueckweg: web-token wird verschluesselt mit webClientId abgelegt“ (ersetzt „rueckweg: web-token wird nicht gespeichert und nicht widerrufen“).
- [x] **AC-2:** Abgelehnte Wege legen nichts ab: GIVEN ein Rückweg mit (a) Apples `error`, (b) abgelehnter Einlösung (`invalid_grant`, `invalid_client`, 500, Antwort ohne `refresh_token`), (c) abgelehnter `id_token`-Prüfung (falsche Nonce, fremde Zielgruppe, fremder Schlüssel, abgelaufen, anderer Algorithmus, ohne `sub`, anderer Aussteller), (d) Apple nicht erreichbar (Netzfehler, Zeitüberschreitung, Schlüsselsatz nicht abrufbar) WHEN der Rückweg läuft THEN gilt für jeden Fall wie bisher Ticket mit `access_denied` bzw. `temporarily_unavailable` ohne Konto, und zusätzlich gibt es in `apple_tokens` keine Zeile. Test: server/test/oauth-return.test.ts „rueckweg: apple-fehler ergibt ticket access_denied“, „rueckweg: abgelehnte einloesung ergibt access_denied“, „rueckweg: ungueltiges identity-token ergibt access_denied“, „rueckweg: apple nicht erreichbar ergibt temporarily_unavailable“ (bestehend, je um die Prüfung `apple_tokens` ist leer ergänzt; der Test zum ungültigen Token prüft das bereits).
- [x] **AC-3:** Die App-Zeile desselben Kontos bleibt unverändert: GIVEN ein Konto zum `sub` des Fakes mit einer App-Zeile (`storeRefreshToken` mit der App-ID und eigenem Blob, `created_at` eine Stunde zurückgesetzt) WHEN der Rückweg für dasselbe Konto läuft THEN gibt es zwei Zeilen in `apple_tokens`, die App-Zeile ist byte-gleich unberührt (Blob, `created_at`, `client_id`), die Web-Zeile trägt `webClientId` und das Web-Token, das Ticket nennt dasselbe Konto, und es wurde kein zweites Konto angelegt. Test: server/test/oauth-return.test.ts „rueckweg: app-zeile desselben kontos bleibt neben der web-zeile“.
- [x] **AC-4:** Eine zweite Browser-Anmeldung ersetzt die Web-Zeile: GIVEN zwei Rückwege nacheinander für denselben `sub`, der zweite mit einem anderen Refresh-Token von Apple, und die Zeit der ersten Zeile eine Stunde zurückgesetzt WHEN beide durchlaufen sind THEN gibt es weiter genau eine Zeile mit `client_id = webClientId`, ihr Blob entschlüsselt sich zum zweiten Token, `created_at` ist vorgerückt, und es gibt genau ein Konto. Test: server/test/oauth-return.test.ts „rueckweg: zweite anmeldung ersetzt die web-zeile“.
- [x] **AC-5:** Konto zwischendurch gelöscht ergibt `access_denied` ohne Konto-ID: GIVEN ein Rückweg, bei dem das Konto unmittelbar vor dem Ablegen des Tokens gelöscht wird (ein vorgeschalteter Pool löscht das Konto per `deleteAccount`, sobald der `INSERT INTO apple_tokens` kommt, Muster des bestehenden Tests zum gelöschten Konto) WHEN der Rückweg läuft THEN antwortet er 303 auf `finish` mit Ticket, die Ablage des Tickets ist `{ uid, error: "access_denied" }` mit `account_id` NULL, die Ablage enthält die Konto-ID nirgends, es gibt keine Zeile in `apple_tokens` und kein Konto, das Protokoll ist leer, und kein Wert aus Token oder Konto steht in der Antwort. Test: server/test/oauth-return.test.ts „rueckweg: konto beim ablegen geloescht ergibt access_denied ohne konto-id“.
- [x] **AC-6:** Datenbankfehler beim Ablegen ergibt die feste 400: GIVEN ein Rückweg, bei dem der `INSERT INTO apple_tokens` mit einem Datenbankfehler scheitert (vorgeschalteter Pool wirft nur für diese Anweisung; der Fehlertext enthält Konto-ID und ein erkennbares Wort) WHEN der Rückweg läuft THEN antwortet er 400 `bad request` (`assertFixed`: `no-store`, keine Weiterleitung), es gibt kein Ticket in `oauth_records`, keine Zeile in `apple_tokens`, das Protokoll ist genau `["oauth return store failed"]`, weder Fehlertext, Konto-ID noch Token stehen in Antwort oder Protokoll, und der `state` ist verbraucht (ein Wiederholen desselben `state` ergibt die feste 400 `oauth return refused`). Test: server/test/oauth-return.test.ts „rueckweg: datenbankfehler beim ablegen ergibt feste 400 ohne ticket“.
- [x] **AC-7:** Ende-zu-Ende, das Löschen widerruft das Web-Token mit der Web-ID: GIVEN ein Rückweg, der die Web-Zeile abgelegt hat, und eine Sitzung für das Konto (`createSession`), Apple antwortet auf den Widerruf mit 200 WHEN `POST /auth/delete` mit dieser Sitzung läuft THEN antwortet es 204 mit leerem Körper, das Konto und alle seine Zeilen (`apple_tokens`, `oauth_records` des Kontos) sind weg, es gibt genau einen Widerruf am Fake, dessen Formular `token` = das Token aus der Einlösung und `client_id` = `webClientId` trägt (nicht die App-ID), und das Protokoll des Dienstes enthält weder Token noch Web-ID. Test: server/test/oauth-return.test.ts „rueckweg: loeschen widerruft das abgelegte web-token mit der web-id“. **Entscheidung zum optionalen Test:** aufgenommen, weil der Aufbau beide Routen schon trägt; er braucht den Fake-Zusatz `revokeForms` (drei Zeilen) und rund 25 Zeilen Test, bleibt also im Rahmen.
- [x] **AC-8:** Gesamtlauf und Rest unverändert: GIVEN der fertige Schnitt WHEN `./server/scripts/test-local.sh` (typecheck + alle Tests) läuft THEN ist er grün und räumt auf; alle übrigen Tests in `oauth-return.test.ts` (Ticket gehasht, Replay, `state`, Übergröße, Methode und Typ, Felder, `user`, geschlossenes Konto, Protokoll, Fehlerfenster, JWKS-Instanz) sowie `oauth-interaction.test.ts`, `oauth-provider.test.ts`, `main.test.ts`, `auth.test.ts`, `apple-vault.test.ts`, `accounts.test.ts` laufen unverändert grün; es gibt keinen neuen Eintrag in `server/package.json` und keine neue Migration. Dateiliste (drei Dateien) und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Test: Gesamtlauf `./server/scripts/test-local.sh` und CI `server.yml`; Dateiliste in `/60-validate`.

## Dialog

### Runde 1
**Adversary:** Ich gehe pro AC von Bruch aus. Fragen: (1) Steht das Token irgendwo im Klartext? (2) Landet bei `false` die Konto-ID im Ticket? (3) Endet ein Wurf in der festen 400? (4) Wird die App-Zeile angefasst? (5) Wird nur nach allen Pruefungen abgelegt? (6) Neue Log-Ereignisse? (7) `outcome` <= 50 Zeilen?
**Implementierer (Belege):**
Code reference: server/src/oauth-return.ts:85
`outcome` hat 15 Zeilen (awk-Zaehlung). Reihenfolge: redeemCode (ok?) -> verifyIdentityToken (ok?) -> findOrCreate -> encryptToken -> storeRefreshToken; jeder abgelehnte Weg kehrt vor findOrCreate zurueck, also kein Konto und keine Zeile (AC-2).
Code reference: server/src/oauth-return.ts:94
`if (!(await storeRefreshToken(...))) return { uid, error: "access_denied" }` ohne accountId im Ergebnis (AC-5). Ein Wurf (DB-Fehler) laeuft in den bestehenden try in finishReturn (Zeile ~116), Log nur STORE_FAILED, feste 400 (AC-6); kein neues Log-Ereignis (der Diff zeigt nur Import, Kommentar, 4 Code-Zeilen).
Klartext: nur `encryptToken(config.tokenKey, accountId, refreshToken)` schreibt; Test prueft Blob, Zeile, oauth_records, Antwort, Header, Log.
App-Zeile: storeRefreshToken-Schluessel (account_id, client_id) mit client_id = webClientId, ON CONFLICT ersetzt nur diese Zeile (apple-vault.ts:43-45).
Code reference: server/test/oauth-return.test.ts:473
Tests AC-1..AC-7 vorhanden und im Lauf gruen (adversary-test-output.txt: 358 pass, 0 fail, 0 skipped).
Alles gruen in Runde 1, daher bewusst keine Konvergenz: Runde 2.

### Runde 2
**Adversary:** Schwaechste Stellen: (a) Greifen die Tests AC-5/6 wirklich den Ablagepfad (Zaehler `inserts`)? (b) Bleibt eine Web-Zeile, wenn danach das Ticket-Upsert scheitert? (c) Mutation "Ablage vor Pruefung"? (d) Migrate-Test im Gesamtlauf?
**Implementierer:**
(a) Code reference: server/test/oauth-return.test.ts:543 - `assert.equal(inserts, 1)`; Zeilen 531-552: Konto wird im INSERT geloescht, Ticket-Zeile account_id NULL, Konto-ID nicht in der Ablage, Log leer. Zeilen ~554-575 analog fuer den Wurf (Marker `ablage-kaputt-4711`). Fehlende Ablage scheitert am Zaehler.
(b) Wirft das Ticket-Upsert nach der Ablage, bleibt eine Web-Zeile fuer ein Konto ohne Ticket (400). Folgenlos: naechste Anmeldung ersetzt sie, Loeschen widerruft sie. LOW, keine Spec-Verletzung.
(c) Die Pruefungen laufen strikt vor findOrCreate; die AC-2-Tests (je `apple_tokens` leer, Zeilen 366/395/417/434) decken die Faelle (a)-(d) der Spec ab.
(d) Gesamtlauf `./server/scripts/test-local.sh`: Exit 0, 358 pass / 0 fail / 0 skipped; auch `migrate.test.ts` AC-3 war diesmal gruen. Die in Issue #869 beschriebene Lastschwaeche (Advisory-Sperre, parallele Testdateien) ist vom Code dieses Schnitts unabhaengig (migrate wird nicht angefasst), trat im Lauf nicht auf und bricht AC-8 nicht.
Dateien: server/package.json und migrations unveraendert (Diffstat leer).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

**VERIFIED**

Finding F001 (LOW, edge_case, Code reference: server/src/oauth-return.ts:116, Remediation: keine noetig): scheitert das Ticket-Upsert nach erfolgreicher Ablage, bleibt eine Web-Zeile ohne Ticket; folgenlos.

Confirmation: AC-1 bis AC-7 CONFIRMED (Code reference: server/src/oauth-return.ts:94; Code reference: server/test/oauth-return.test.ts:473).
AC-8 CONFIRMED: Gesamtlauf 358 pass, 0 fail, 0 skipped; Typecheck gruen; outcome 15 Zeilen.

## Geprüfte Dateien

- sha256:c3ec70b03d747a239fdb4a72f0c3bb7bc0328a265f82669cd2148a0030a52486  server/src/oauth-return.ts
- sha256:7b044b6518009e6d5e00b6481566886470cc601eba64e39553b046965a657825  server/test/oauth-return.test.ts

## Prüfbasis

- base: 239d7aad7e776387553e82ab72520e1629dd6912
- blob:ea2e549b4c82b053af03735f014f010dbadfb159  server/src/oauth-return.ts
- blob:ce19390b3c3fc0b36cded88269f49b097374252c  server/test/oauth-return.test.ts
