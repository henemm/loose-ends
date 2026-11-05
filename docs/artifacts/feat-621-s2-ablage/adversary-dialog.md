# Adversary Dialog — feat-621-s2-ablage
Spec: docs/specs/feat-621-schnitt-2-ablage.md
Datum: 2026-11-05 20:47

## Checkliste
- [x] **AC-1:** Migration 004 additiv auf Bestandsdaten: Nach Migration von 001–003 mit einem Konto, einer Sitzung, einem Apple-Token, einer Abschrift und einem Auftrag legt 004 die Tabelle `oauth_records` an; alle vorhandenen Zeilen sind danach unverändert (`deepEqual` auf Werte und `created_at`), `migrate` meldet genau `["004_oauth.sql"]`, ein zweiter Lauf `[]`; Spaltentypen und Nullbarkeit laut Schnittstelle stimmen (abgefragt über `information_schema.columns`), `account_id` hat einen Fremdschlüssel mit `ON DELETE CASCADE`. Test: „migration 004: additiv auf bestandsdaten“ in `server/test/schema.test.ts`.
- [x] **AC-2:** `upsert` und `find` rund: Ein Datensatz je Modell aus einer Tabelle (AccessToken, AuthorizationCode, RefreshToken, Grant, Session, Interaction) wird mit `upsert(id, payload, 60)` abgelegt und von `find(id)` als `{ ...payload, jti: id }` zurückgegeben (`deepEqual`); ein zweites `upsert` mit gleicher `id` ersetzt Payload und Ablauf (Zeilenzahl bleibt 1). Test: „oauth-adapter: upsert und find“.
- [x] **AC-3:** Unbekanntes und Trennung der Modelle: `find` einer unbekannten `id` liefert `undefined`; dieselbe `id` unter zwei Modellnamen (zwei `PgAdapter`-Instanzen) liefert je den eigenen Payload und `destroy` im einen lässt den anderen stehen. Test: „oauth-adapter: unbekannt und modelle getrennt“.
- [x] **AC-4:** `findByUid`: Eine Session mit `uid` im Payload wird über `findByUid(uid)` gefunden und stimmt mit dem Payload überein; eine unbekannte `uid` und eine `uid` einer abgelaufenen Session liefern `undefined`; die `uid` einer Session eines anderen Modells wird nicht gefunden. Test: „oauth-adapter: find by uid“.
- [x] **AC-5:** `destroy`: Nach `destroy(id)` liefert `find(id)` `undefined` und die Zeile ist aus der Tabelle verschwunden; `destroy` einer unbekannten `id` wirft nicht. Test: „oauth-adapter: destroy“.
- [x] **AC-6:** `revokeByGrantId`: Zu einem Grant gehören ein AccessToken, ein RefreshToken, ein AuthorizationCode und die Interaction mit demselben `grantId`; nach `revokeByGrantId(grantId)` sind alle vier weg (`find` je `undefined`), Zeilen eines **anderen** Grants und ohne Grant bleiben unverändert. Test: „oauth-adapter: revoke by grant id“.
- [x] **AC-7:** Klartextfreiheit, per direkter SQL-Abfrage: Nach `upsert` eines AccessTokens mit `id = "geheim-token-123"` und `payload.jti = "geheim-token-123"` enthält `SELECT * FROM oauth_records` (jede Spalte als Text, einschließlich `payload::text`) die Zeichenfolge `geheim-token-123` nirgends; `id_hash` ist `sha256("geheim-token-123")` (32 Byte); der gespeicherte Payload hat keinen Schlüssel `jti` und keinen Schlüssel `consumed`; `find` setzt `jti` wieder ein. Dieselbe Prüfung gilt für die `id` eines RefreshTokens und eines AuthorizationCodes. Test: „oauth-adapter: ids nur als hash“.
- [x] **AC-8:** `find` verbirgt Abgelaufenes: Mit eingereichter Uhr: `upsert(id, payload, 60)`, `find` bei t+59 s liefert den Datensatz, bei t+60 s und danach `undefined` (Zeitsprung der Uhr, kein `sleep`); die Zeile bleibt bis zum Aufräumen in der Tabelle. Test: „oauth-adapter: abgelaufenes verborgen“.
- [x] **AC-9:** Ohne `expiresIn` kein Ablauf: Ein Datensatz des Modells `Client`, abgelegt ohne `expiresIn`, hat `expires_at IS NULL` und wird auch nach einem Zeitsprung von einem Jahr gefunden. Test: „oauth-adapter: ohne ablauf bleibt“.
- [x] **AC-10:** `consume` atomar, nacheinander: Das erste `consume(id)` gelingt; `find(id)` liefert danach `consumed` truthy und `consumed_at` in der Zeile ist gesetzt; das zweite `consume(id)` **wirft**; `consume` einer unbekannten und einer abgelaufenen `id` wirft ebenfalls; ein `upsert` auf einen verbrauchten Datensatz lässt `consumed` truthy (kein Wiederaufleben). Test: „oauth-adapter: consume einmal“.
- [x] **AC-11:** `consume` bei Gleichzeitigkeit: 20 gleichzeitige `consume(id)` (`Promise.allSettled`, jedes auf eigener Verbindung des Pools) auf denselben AuthorizationCode ergeben **genau einen** Erfolg und 19 Ablehnungen; die Zeile hat genau einen `consumed_at`. Test: „oauth-adapter: zwei gleichzeitige consume“.
- [x] **AC-12:** ReplayDetection atomar: Ein `upsert` auf das Modell `ReplayDetection` mit neuer `id` gelingt; ein zweites mit gleicher `id` solange der erste nicht abgelaufen ist **wirft** (Payload der ersten Zeile bleibt unverändert); nach Zeitsprung hinter den Ablauf gelingt das `upsert` wieder und ersetzt Payload und Ablauf; 20 gleichzeitige `upsert` mit gleicher `id` ergeben genau einen Erfolg. Test: „oauth-adapter: replay detection atomar“.
- [x] **AC-13:** `findByUserCode` nicht unterstützt: Der Aufruf wirft einen `Error` mit der Meldung `findByUserCode not supported` (definiertes Verhalten für den ungenutzten Device-Flow) und berührt die Datenbank nicht. Test: „oauth-adapter: find by user code nicht unterstuetzt“.
- [x] **AC-14:** Opportunistisches Aufräumen: Mit eingereichter Uhr und drei abgelaufenen Zeilen: Ein `upsert` löscht sie, wenn seit dem letzten Aufräumen dieses Prozesses (oder dem ersten `upsert`) mindestens 10 Minuten vergangen sind; ein `upsert` bei weniger als 10 Minuten Abstand löscht nichts; unabgelaufene Zeilen und Zeilen ohne Ablauf bleiben in beiden Fällen; ein Fehler beim Aufräumen (Tabelle während des Tests umbenannt) lässt das `upsert` nicht scheitern. Test: „oauth-adapter: aufraeumen hoechstens alle 10 minuten“.
- [x] **AC-15:** `deleteAccount` nimmt OAuth-Zeilen des Kontos mit: Für Konto A liegen ein Grant und ein AccessToken (mit `accountId`), eine Interaction **ohne** `accountId`, aber mit `grantId` von A, und eine Zeile mit `accountId` von A in einem anderen Modell; für Konto B ebenso; dazu eine Client-Zeile. Nach `deleteAccount(pool, A)` sind alle Zeilen von A weg (über `account_id` und über die Grants), alle von B unverändert (`deepEqual`), die Client-Zeile bleibt; die übrigen Zusagen von `deleteAccount` (Rückgabe, Zeilen von Aufträgen und Abschrift) sind unverändert. Test: „accounts: delete nimmt oauth zeilen mit“ in `server/test/accounts.test.ts`.
- [x] **AC-16:** Fremdschlüssel schützt vor Waisen: `upsert` mit `accountId` eines nicht existierenden Kontos wirft (Postgres-Code `23503`, geprüft über `error.code` am geworfenen Fehler oder seiner `cause`) und hinterlässt keine Zeile; die Fehlermeldung enthält weder `id`, `jti` noch die Konto-ID. Test: „oauth-adapter: unbekanntes konto wirft“.
- [x] **AC-17:** Nichts im Log: Während der Fälle aus AC-2 bis AC-16 wird `console.*` und `process.stdout`/`process.stderr` mitgeschnitten (Mitschnitt im Test selbst); der Mitschnitt enthält keine `id`, kein `jti`, keinen Payload-Wert und keine Konto-ID. Test: „oauth-adapter: nichts im log“.
- [x] **AC-18:** Grenze, Länge, Gesamtlauf: Dieser Schnitt ändert genau die sechs Dateien aus „Source“ (`git diff --name-only origin/main -- server` in `/60-validate` belegt, **nicht** als Test, weil ein Diff-Test gegen `main` in der CI und nach dem Merge bricht); `package.json` und Lockfile sind unverändert; jede Funktion hat höchstens 50 Zeilen; `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf. Nachweis: Lauf von `./server/scripts/test-local.sh` und `/60-validate`.

## Dialog

### Runde 1
**Adversary:** Lauf `./server/scripts/test-local.sh` selbst ausgeführt (Ausgabe `docs/artifacts/feat-621-s2-ablage/adversary-test-output.txt`): typecheck grün, 259 pass, 0 fail, 0 skipped. Alle 17 neuen Testnamen aus der Spec stehen als ✔ in der Ausgabe (u. a. „migration 004: additiv auf bestandsdaten", „accounts: delete nimmt oauth zeilen mit", „oauth-adapter: nichts im log"). Dateigrenze (AC-18): der Dateidiff gegen die Basis 53b4df6 im Verzeichnis server plus untracked ergibt genau die sechs Dateien (accounts.ts, oauth-adapter.ts, 004_oauth.sql, drei Tests); der Diff auf package.json und package-lock.json ist leer.

Confirmation: AC-1
Code reference: server/migrations/004_oauth.sql:5
Evidence: Tabelle mit PK (model, id_hash), `account_id ... REFERENCES accounts (id) ON DELETE CASCADE` (Z. 11).
Status: CONFIRMED

Confirmation: AC-1 (Test)
Code reference: server/test/schema.test.ts:61
Evidence: erwartet genau `["004_oauth.sql"]` aus dem Lauf auf Bestandsdaten, Test ✔.
Status: CONFIRMED

Confirmation: AC-2, AC-3, AC-4, AC-5, AC-6
Code reference: server/src/oauth-adapter.ts:31
Evidence: upsert mit ON CONFLICT (model, id_hash) DO UPDATE; find (Z. 49) setzt jti wieder ein, Modell im WHERE (Trennung); findByUid (Z. 59) filtert Modell und Ablauf; destroy (Z. 82) nur eigenes Modell; revokeByGrantId (Z. 87) löscht modellübergreifend. Tests ✔.
Status: CONFIRMED

Confirmation: AC-7
Code reference: server/src/oauth-adapter.ts:34
Evidence: `jti` und `consumed` werden vor dem Speichern abgestreift, id nur als `hash()` (Z. 10); Test „ids nur als hash" fragt jede Spalte als Text ab.
Status: CONFIRMED

Confirmation: AC-8, AC-9
Code reference: server/src/oauth-adapter.ts:11
Evidence: NOT_EXPIRED = `expires_at IS NULL OR expires_at > $3` mit eingereichter Uhr; Ablauf bei t+60 s ist exklusiv (>), Zeile bleibt bis Aufräumen.
Status: CONFIRMED

Confirmation: AC-10, AC-11
Code reference: server/src/oauth-adapter.ts:73
Evidence: ein einziges UPDATE ... WHERE consumed_at IS NULL AND NOT_EXPIRED RETURNING; rowCount != 1 wirft. Atomar unter READ COMMITTED (zweite Verbindung wartet auf die Zeilensperre und sieht dann consumed_at gesetzt). Upsert fasst consumed_at nicht an (Z. 40-41), also kein Wiederaufleben. 20-fach-Test ✔.
Status: CONFIRMED

Confirmation: AC-12
Code reference: server/src/oauth-adapter.ts:36
Evidence: ON CONFLICT DO UPDATE ... WHERE expires_at <= now; sonst rowCount 0 und Wurf (Z. 46). Gleichzeitigkeit durch Zeilensperre sicher. Edge expires_at NULL: `NULL <= now` ist NULL, also nie ersetzbar, Wurf; sichere Richtung.
Status: CONFIRMED

Confirmation: AC-13
Code reference: server/src/oauth-adapter.ts:68
Evidence: wirft sofort `findByUserCode not supported`, kein DB-Zugriff.
Status: CONFIRMED

Confirmation: AC-14
Code reference: server/src/oauth-adapter.ts:93
Evidence: erstes upsert setzt nur die Startzeit, danach Löschen frühestens nach 10 min, `.catch(() => undefined)` schluckt Fehler. Der Test (server/test/oauth-adapter.test.ts:252-259) nutzt einen BEFORE-DELETE-Trigger, der jedes DELETE verweigert, also einen echten Fehler genau der Aufräum-Anweisung. Die Begründung stimmt: Umbenennen der Tabelle ließe auch das Insert des upsert scheitern und könnte die Zusage „upsert scheitert nicht" gar nicht prüfen. Die Zusage ist damit belegt (Zeile neu-1 bleibt stehen, upsert gelingt).
Status: CONFIRMED

Confirmation: AC-15
Code reference: server/src/accounts.ts:59
Evidence: zusätzliches DELETE über `grant_id IN (SELECT grant_id ... WHERE account_id = $1)` vor DELETE accounts, Rest per CASCADE, in der bestehenden Transaktion; deleteAccount bleibt unter 50 Zeilen.
Status: CONFIRMED

Confirmation: AC-15 (Test)
Code reference: server/test/accounts.test.ts:175
Evidence: Test „accounts: delete nimmt oauth zeilen mit" ✔ (B und Client unverändert, Interaction nur mit grantId weg).
Status: CONFIRMED

Confirmation: AC-16
Code reference: server/test/oauth-adapter.test.ts:262
Evidence: FK-Verletzung 23503, `message` ohne id/jti/Konto-ID, keine Zeile zurück. Siehe F001 zu `detail`.
Status: CONFIRMED

Confirmation: AC-17
Code reference: server/test/oauth-adapter.test.ts:275
Evidence: Der Adapter enthält keinen console/stdout-Aufruf (komplett gelesen); Mitschnitt im Test ✔.
Status: CONFIRMED

Confirmation: AC-18
Code reference: server/src/oauth-adapter.ts:1
Evidence: Dateiliste siehe oben; package.json/Lockfile unverändert; keine Funktion über 50 Zeilen (Tests per awk ≤ 45, upsert 17); test-local.sh Exit 0.
Status: CONFIRMED
**Implementierer:** Keine Gegenrede, alle Belege am Code geprüft.

### Runde 2
**Adversary (Edge Cases):**
Finding:
  ID: F001
  Severity: LOW
  Category: security
  Code reference: server/src/oauth-adapter.ts:37
  Description: Der FK-Fehler von pg wird unverändert durchgereicht. `message` ist sauber, das Feld `detail` enthält aber `Key (account_id)=(<Konto-ID>)`.
  Spec requirement: AC-16 — „Fehlermeldung enthält weder id, jti noch die Konto-ID".
  Conflict: Wortlaut „Fehlermeldung" = `message`, dort erfüllt. Wer in S3 das ganze Error-Objekt loggt, schreibt die Konto-ID ins Log; der Test prüft nur `message`. Kein Verstoß, Hinweis für S3.
  Remediation: In S3 nie das Fehlerobjekt loggen, nur `code`; optional den Fehler im Adapter ohne `detail` neu verpacken.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/oauth-adapter.ts:40
  Description: Ein upsert auf eine abgelaufene, noch nicht aufgeräumte, verbrauchte Zeile gleicher id lässt `consumed_at` stehen.
  Spec requirement: AC-10 — kein Wiederaufleben eines verbrauchten Datensatzes.
  Conflict: Entspricht der Spec; nur bei Wiederverwendung einer id nach Ablauf relevant. oidc-provider vergibt zufällige ids, praktisch irrelevant.
  Remediation: Keine.

Geprüft ohne Befund: ReplayDetection mit NULL-Ablauf (sicher blockiert); consume auf abgelaufene Zeile (wirft); id_hash-Kollision zwischen Modellen (PK enthält model, AC-3 ✔); Interaction nur mit grantId (über Unterabfrage gelöscht, solange eine Zeile des Grants `account_id` trägt; ein Grant ganz ohne Kontozeile ist von der Spec nicht abgedeckt); Aufräumzeit je Pool im WeakMap, kein Timer; jti/consumed nie gespeichert (Z. 34).
**Implementierer:** Keine Änderung nötig; F001/F002 sind LOW und spezkonform, Hinweis für S3.


## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 259 passed, 0 failed, 0 übersprungen. Checkliste: 18/18 belegt. Findings: F001 LOW, F002 LOW (beide spezkonform).

## Geprüfte Dateien

- sha256:83178eb2014b3730c1073c75dadc4bf73ef4c680c8f9d3fcb4bc08d9ac3c1dc0  server/migrations/004_oauth.sql
- sha256:9e42c8bfb5e6809ca272b8b06b68fc5c6c1c15e316cf2fa320fdd794a5869f85  server/src/accounts.ts
- sha256:72cac8b70a151fa0ac70cf03f02d505bd288b97b2b5f979e530337b5ac481403  server/src/oauth-adapter.ts
- sha256:383a1b709bd4d6c47b2884ccf0b8f26bbdbce8041664a2183fe8af9189f6f198  server/test/accounts.test.ts
- sha256:e6572df6f4d59ddd7693d6facc801ebcd5054b315fd46ffa222c260aaf844e12  server/test/oauth-adapter.test.ts
- sha256:cfc24416219840bd810ef725dae264801125f77925f72228881bb66371c69c76  server/test/schema.test.ts

## Prüfbasis

- base: 53b4df657fa9725ad158333d28214358f8b84257
- blob:e52aba31e4056d14c92da4d759cf829ffe670f6c  server/migrations/004_oauth.sql
- blob:bd72fe2d242e3ccc139192b4be4e122b3df6217f  server/src/accounts.ts
- blob:1a93487d7f00b64030d4981c5b565d6e8e233cb5  server/src/oauth-adapter.ts
- blob:1dcc2cf3bd587dcaa940aa2413894dfd0c4d20f8  server/test/accounts.test.ts
- blob:41f5113dcf6aca5a985bdb57cd8f60d46ae3e3db  server/test/oauth-adapter.test.ts
- blob:1532f98fe44879053be6b09c94249ff608f8855a  server/test/schema.test.ts
