---
entity_id: feat-621-schnitt-2-ablage
type: feature
created: 2026-11-05
updated: 2026-11-05
status: draft
workflow: feat-621-s2-ablage
---

# Spec: Ablage für den OAuth-Anmeldeserver, Schnitt 2 (#621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 2; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte).
Analyse: `docs/context/feat-621-s2-ablage.md` (Abschnitte „Analysis“, „Recherche-Befund“, „Alternativen“); Schnittplan: `docs/context/feat-621-mcp-anmeldung.md`. Vorgänger: #621 S1 (`server/src/oauth-resource.ts`, `/mcp` hinter `rejectAll`), #615 (Konten, `deleteAccount`).

## Für den PO

Damit Claude sich später bei Loose Ends anmelden kann, braucht der Dienst ein Gedächtnis dafür: wer gerade welche Erlaubnis erteilt hat und welche Einmal-Codes schon benutzt wurden. Dieser Schnitt baut nur dieses Gedächtnis (eine Tabelle und ein Baustein, der sie bedient). Die Schlüssel, die Claude später erhält, liegen dort nicht im Klartext, sondern nur als unumkehrbarer Fingerabdruck; ein Datenbank-Leck gäbe also keine nutzbaren Schlüssel her. Löschst du dein Konto, verschwinden auch diese Einträge mit. Von außen ändert sich nichts: Die Tür für Claude bleibt zu, die App ruft nichts davon auf, deine Daten sind nicht berührt.

## Purpose

Der Anmeldeserver, den S3 mit `oidc-provider` einbettet, braucht eine Ablage nach dessen Adapter-Schnittstelle (Quelle: `example/my_adapter.js`, `lib/models/base_model.js`, `replay_detection.js` in panva/node-oidc-provider, `oidc-provider` 9.13.3, Recherche 2026-11-05). Dieser Schnitt liefert Migration `004_oauth.sql` mit einer Tabelle `oauth_records` für alle Modelle, die Klasse `PgAdapter` (`upsert`, `find`, `findByUid`, `consume`, `destroy`, `revokeByGrantId`, `findByUserCode` nicht unterstützt) und erweitert `deleteAccount`, damit die OAuth-Zeilen eines Kontos mitgehen. Die Bibliothek ist **noch keine Abhängigkeit** (kommt in S3); der Adapter ist eine Klasse ohne Import aus ihr und wird gegen die dokumentierte Schnittstelle getestet. Abweichungen zeigt erst das Spike-Gate in S3.

**Regeln vor Modell:** Persistenz und Protokollablage ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Festlegungen aus der Recherche, die den Entwurf bestimmen:

- `BaseModel.save` ruft `adapter.upsert(jti, payload, ttl)`, und `jti` ist in `IN_PAYLOAD`; bei opaken Token ist der Wert, den der Client erhält, genau `jti`. Der Payload trägt das Token also im Klartext. Daher: jede eingehende `id` wird mit SHA-256 gehasht (`id_hash bytea`), `jti` wird vor dem Speichern aus dem Payload entfernt und von `find` als `{ ...payload, jti: id }` wieder eingesetzt.
- `consume` muss atomar nur markieren, wenn noch nicht verbraucht, sonst werfen (der Rückgabewert wird ignoriert); `find` liefert danach `consumed` truthy. Das schützt gegen doppeltes Einlösen eines Codes oder Refresh-Tokens.
- ReplayDetection: `upsert` muss atomar nur einfügen, wenn kein unabgelaufener Eintrag existiert, sonst werfen.
- `find` darf Abgelaufenes verbergen; die Bibliothek prüft `exp` zusätzlich selbst.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — reiner Baustein innerhalb von ADR-21 (Weg B, eigener Dienst) und der Hausregel „Geheimnisse nie im Klartext“ (#615: Sitzungen nur SHA-256, Apple-Token AES-GCM). Der ADR-21-Nachtrag zur Wahl des Ausstellers (`oidc-provider`) folgt mit S3.

**Rationale:** (1) Eine Tabelle für alle Modelle, weil sich die 15 Modelle nur im Payload unterscheiden; `payload jsonb` hält Nacharbeit migrationsfrei. (2) Ids nur als SHA-256: Der Adapter hasht jede eingehende `id` gleich, daher bleiben `find`/`destroy`/`consume` unverändert nutzbar. (3) Zeit kommt als eingereichte Uhr (Projektmuster), damit Zeitsprünge im Test möglich sind und kein Test auf `sleep` wartet. (4) `consume` und Replay-`upsert` sind je ein einziges SQL-Statement, damit Atomarität die Datenbank liefert und nicht Anwendungslogik.

## Source

**Files:** `server/migrations/004_oauth.sql` (neu), `server/src/oauth-adapter.ts` (neu), `server/src/accounts.ts` (ändern), `server/test/oauth-adapter.test.ts` (neu), `server/test/accounts.test.ts` (ändern), `server/test/schema.test.ts` (ändern)
**Identifier:** `oauth_records`, `PgAdapter`, `deleteAccount`

### Schnittstelle

- **`server/migrations/004_oauth.sql`** (Kommentar oben, kein BEGIN/COMMIT, nur Hinzufügen, wie 001–003): Tabelle `oauth_records` mit
  - `model text NOT NULL`, `id_hash bytea NOT NULL`, `PRIMARY KEY (model, id_hash)`;
  - `payload jsonb NOT NULL`;
  - `grant_id text`, `uid text` (beide nullable, Klartext: Grant-Kennung und Session-`uid` sind kein Zugangsnachweis);
  - `account_id text REFERENCES accounts (id) ON DELETE CASCADE` (nullable: Interaction, ReplayDetection und Client haben kein Konto);
  - `expires_at timestamptz` (nullable: kein Ablauf, z. B. Client), `consumed_at timestamptz`, `created_at timestamptz NOT NULL DEFAULT now()`;
  - Indizes auf `grant_id`, `uid`, `account_id`, `expires_at`.
- **`server/src/oauth-adapter.ts`**: `class PgAdapter` mit `constructor(pool: pg.Pool, name: string, now: () => Date = () => new Date())`.
  - `upsert(id, payload, expiresIn?)`: legt an oder ersetzt (Schlüssel `(name, sha256(id))`); `expires_at = now() + expiresIn` Sekunden, ohne `expiresIn` `NULL`; `jti` und `consumed` werden aus dem gespeicherten Payload entfernt; `account_id` aus `payload.accountId`, `grant_id` aus `payload.grantId`, `uid` aus `payload.uid` (jeweils `NULL`, wenn nicht vorhanden); ein Ersetzen lässt `consumed_at` unverändert (ein verbrauchter Datensatz lebt durch `upsert` nicht wieder auf). Für das Modell `ReplayDetection` ist `upsert` **ein** Statement `INSERT … ON CONFLICT DO UPDATE … WHERE oauth_records.expires_at <= $now RETURNING`: 0 Zeilen → wirft. Öffnet beim Schreiben das Aufräumen (siehe unten).
  - `find(id)`: Datensatz `{ ...payload, jti: id }` und, wenn `consumed_at` gesetzt ist, `consumed` mit dem Verbrauchszeitpunkt in Sekunden (truthy); Abgelaufenes (`expires_at <= now`) und Unbekanntes → `undefined`.
  - `findByUid(uid)`: wie `find`, gesucht über die Spalte `uid` im eigenen Modell, liefert den Payload **ohne** `jti`, weil die Zeile nur den Hash der Id trägt (die Session-Id ist der Cookie-Wert und steht deshalb nicht im Klartext). Die Bibliothek braucht dort kein `jti` (Quelltext `oidc-provider` 9.13.3, 2026-11-05): `Session.findByUid` hat genau zwei Aufrufer, `checkSessionBinding` (`lib/models/token_helpers.js`) und `interactionDetails` (`lib/provider.js`), beide lesen nur `accountId` und `grantIdFor` und speichern die Session nie; fehlt `jti`, vergibt der Konstruktor eine neue Zufalls-Id, die nie geschrieben wird. Das Spike-Gate in S3 prüft es gegen die echte Bibliothek nach.
  - `consume(id)`: **ein** Statement `UPDATE … SET consumed_at = $now WHERE model = $1 AND id_hash = $2 AND consumed_at IS NULL AND (expires_at IS NULL OR expires_at > $now) RETURNING`; 0 Zeilen → wirft.
  - `destroy(id)`: löscht genau diese Zeile; unbekannt ist kein Fehler.
  - `revokeByGrantId(grantId)`: löscht alle Zeilen aller Modelle mit diesem `grant_id`.
  - `findByUserCode(userCode)`: wirft `Error("findByUserCode not supported")` (Device-Flow wird nicht genutzt).
  - Aufräumen: bei `upsert` höchstens alle 10 Minuten je Prozess (gemessen an der eingereichten Uhr, Zeitpunkt im Modul-Zustand je Pool) ein `DELETE … WHERE expires_at < $now`; kein Timer, kein Hintergrundprozess; ein Fehler dabei bricht das `upsert` nicht ab und wird nicht mit Werten geloggt.
- **`server/src/accounts.ts`**: `deleteAccount` löscht in der bestehenden Transaktion vor dem Konto ein Statement `DELETE FROM oauth_records WHERE grant_id IN (SELECT grant_id FROM oauth_records WHERE account_id = $1 AND grant_id IS NOT NULL)`; alle Zeilen mit `account_id` gehen durch `ON DELETE CASCADE` mit dem Konto. Client-Zeilen (ohne Konto, ohne Grant des Kontos) bleiben. Rückgabe und Fehlerverhalten von `deleteAccount` unverändert.

### Festlegungen

- **Klartextfreiheit:** Weder `id` noch `jti` stehen im Klartext in der Datenbank (nur `id_hash` und ein Payload ohne `jti`). Ausnahmen mit Begründung: `grant_id`, `uid`, `account_id`, `clientId`, Scopes im Payload sind Kennungen und keine Zugangsnachweise.
- **Atomarität kommt aus SQL:** `consume` und Replay-`upsert` sind je ein Statement ohne vorheriges `SELECT`.
- **Keine Werte im Log:** Der Adapter schreibt nichts auf `console.*`; Fehler tragen weder `id`, `jti`, Payload noch Konto-ID in ihrer Meldung.
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; keine neuen Pakete; keine Änderung an `package.json` und Lockfile.
- **Unberührt:** `oauth-resource.ts`, `main.ts`, `mcp.ts`, `auth.ts`, alle `apple*.ts`, Migrationen 001–003, jede Swift-Datei, `.github/`, nginx in `henemm-infra`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| Postgres 18, `pg`, `node:crypto` (`createHash`) | bestehend, **keine neuen Pakete** |
| `accounts` (FK-Ziel von `account_id`), `deleteAccount` | bestehend, `deleteAccount` erweitert |
| `freshPool` (`server/test/db.ts`), `migrate` | bestehend, nur in Tests |
| `oidc-provider` 9.13.3 | **nicht** Abhängigkeit in diesem Schnitt (S3) |
| Downstream | S3 (`adapter: (name) => new PgAdapter(pool, name)`, `verifyToken` liest `AccessToken`, Spike-Gate gegen die echte Bibliothek), S4b (Interaction), `POST /auth/delete` |

## Acceptance Criteria

Neue Tests in `server/test/oauth-adapter.test.ts` mit `node:test` und `node:assert/strict` gegen ein Wegwerf-Postgres über `freshPool(t)` und `migrate` (kein Überspringen); die Uhr wird als `now`-Funktion eingereicht und im Test verstellt. Fälle tabellengetrieben, ein Fall je Zeile.

- **AC-1:** Migration 004 additiv auf Bestandsdaten: Nach Migration von 001–003 mit einem Konto, einer Sitzung, einem Apple-Token, einer Abschrift und einem Auftrag legt 004 die Tabelle `oauth_records` an; alle vorhandenen Zeilen sind danach unverändert (`deepEqual` auf Werte und `created_at`), `migrate` meldet genau `["004_oauth.sql"]`, ein zweiter Lauf `[]`; Spaltentypen und Nullbarkeit laut Schnittstelle stimmen (abgefragt über `information_schema.columns`), `account_id` hat einen Fremdschlüssel mit `ON DELETE CASCADE`. Test: „migration 004: additiv auf bestandsdaten“ in `server/test/schema.test.ts`.
- **AC-2:** `upsert` und `find` rund: Ein Datensatz je Modell aus einer Tabelle (AccessToken, AuthorizationCode, RefreshToken, Grant, Session, Interaction) wird mit `upsert(id, payload, 60)` abgelegt und von `find(id)` als `{ ...payload, jti: id }` zurückgegeben (`deepEqual`); ein zweites `upsert` mit gleicher `id` ersetzt Payload und Ablauf (Zeilenzahl bleibt 1). Test: „oauth-adapter: upsert und find“.
- **AC-3:** Unbekanntes und Trennung der Modelle: `find` einer unbekannten `id` liefert `undefined`; dieselbe `id` unter zwei Modellnamen (zwei `PgAdapter`-Instanzen) liefert je den eigenen Payload und `destroy` im einen lässt den anderen stehen. Test: „oauth-adapter: unbekannt und modelle getrennt“.
- **AC-4:** `findByUid`: Eine Session mit `uid` im Payload wird über `findByUid(uid)` gefunden und stimmt mit dem Payload überein; eine unbekannte `uid` und eine `uid` einer abgelaufenen Session liefern `undefined`; die `uid` einer Session eines anderen Modells wird nicht gefunden. Test: „oauth-adapter: find by uid“.
- **AC-5:** `destroy`: Nach `destroy(id)` liefert `find(id)` `undefined` und die Zeile ist aus der Tabelle verschwunden; `destroy` einer unbekannten `id` wirft nicht. Test: „oauth-adapter: destroy“.
- **AC-6:** `revokeByGrantId`: Zu einem Grant gehören ein AccessToken, ein RefreshToken, ein AuthorizationCode und die Interaction mit demselben `grantId`; nach `revokeByGrantId(grantId)` sind alle vier weg (`find` je `undefined`), Zeilen eines **anderen** Grants und ohne Grant bleiben unverändert. Test: „oauth-adapter: revoke by grant id“.
- **AC-7:** Klartextfreiheit, per direkter SQL-Abfrage: Nach `upsert` eines AccessTokens mit `id = "geheim-token-123"` und `payload.jti = "geheim-token-123"` enthält `SELECT * FROM oauth_records` (jede Spalte als Text, einschließlich `payload::text`) die Zeichenfolge `geheim-token-123` nirgends; `id_hash` ist `sha256("geheim-token-123")` (32 Byte); der gespeicherte Payload hat keinen Schlüssel `jti` und keinen Schlüssel `consumed`; `find` setzt `jti` wieder ein. Dieselbe Prüfung gilt für die `id` eines RefreshTokens und eines AuthorizationCodes. Test: „oauth-adapter: ids nur als hash“.
- **AC-8:** `find` verbirgt Abgelaufenes: Mit eingereichter Uhr: `upsert(id, payload, 60)`, `find` bei t+59 s liefert den Datensatz, bei t+60 s und danach `undefined` (Zeitsprung der Uhr, kein `sleep`); die Zeile bleibt bis zum Aufräumen in der Tabelle. Test: „oauth-adapter: abgelaufenes verborgen“.
- **AC-9:** Ohne `expiresIn` kein Ablauf: Ein Datensatz des Modells `Client`, abgelegt ohne `expiresIn`, hat `expires_at IS NULL` und wird auch nach einem Zeitsprung von einem Jahr gefunden. Test: „oauth-adapter: ohne ablauf bleibt“.
- **AC-10:** `consume` atomar, nacheinander: Das erste `consume(id)` gelingt; `find(id)` liefert danach `consumed` truthy und `consumed_at` in der Zeile ist gesetzt; das zweite `consume(id)` **wirft**; `consume` einer unbekannten und einer abgelaufenen `id` wirft ebenfalls; ein `upsert` auf einen verbrauchten Datensatz lässt `consumed` truthy (kein Wiederaufleben). Test: „oauth-adapter: consume einmal“.
- **AC-11:** `consume` bei Gleichzeitigkeit: 20 gleichzeitige `consume(id)` (`Promise.allSettled`, jedes auf eigener Verbindung des Pools) auf denselben AuthorizationCode ergeben **genau einen** Erfolg und 19 Ablehnungen; die Zeile hat genau einen `consumed_at`. Test: „oauth-adapter: zwei gleichzeitige consume“.
- **AC-12:** ReplayDetection atomar: Ein `upsert` auf das Modell `ReplayDetection` mit neuer `id` gelingt; ein zweites mit gleicher `id` solange der erste nicht abgelaufen ist **wirft** (Payload der ersten Zeile bleibt unverändert); nach Zeitsprung hinter den Ablauf gelingt das `upsert` wieder und ersetzt Payload und Ablauf; 20 gleichzeitige `upsert` mit gleicher `id` ergeben genau einen Erfolg. Test: „oauth-adapter: replay detection atomar“.
- **AC-13:** `findByUserCode` nicht unterstützt: Der Aufruf wirft einen `Error` mit der Meldung `findByUserCode not supported` (definiertes Verhalten für den ungenutzten Device-Flow) und berührt die Datenbank nicht. Test: „oauth-adapter: find by user code nicht unterstuetzt“.
- **AC-14:** Opportunistisches Aufräumen: Mit eingereichter Uhr und drei abgelaufenen Zeilen: Ein `upsert` löscht sie, wenn seit dem letzten Aufräumen dieses Prozesses (oder dem ersten `upsert`) mindestens 10 Minuten vergangen sind; ein `upsert` bei weniger als 10 Minuten Abstand löscht nichts; unabgelaufene Zeilen und Zeilen ohne Ablauf bleiben in beiden Fällen; ein Fehler beim Aufräumen (Tabelle während des Tests umbenannt) lässt das `upsert` nicht scheitern. Test: „oauth-adapter: aufraeumen hoechstens alle 10 minuten“.
- **AC-15:** `deleteAccount` nimmt OAuth-Zeilen des Kontos mit: Für Konto A liegen ein Grant und ein AccessToken (mit `accountId`), eine Interaction **ohne** `accountId`, aber mit `grantId` von A, und eine Zeile mit `accountId` von A in einem anderen Modell; für Konto B ebenso; dazu eine Client-Zeile. Nach `deleteAccount(pool, A)` sind alle Zeilen von A weg (über `account_id` und über die Grants), alle von B unverändert (`deepEqual`), die Client-Zeile bleibt; die übrigen Zusagen von `deleteAccount` (Rückgabe, Zeilen von Aufträgen und Abschrift) sind unverändert. Test: „accounts: delete nimmt oauth zeilen mit“ in `server/test/accounts.test.ts`.
- **AC-16:** Fremdschlüssel schützt vor Waisen: `upsert` mit `accountId` eines nicht existierenden Kontos wirft (Postgres-Code `23503`, geprüft über `error.code` am geworfenen Fehler oder seiner `cause`) und hinterlässt keine Zeile; die Fehlermeldung enthält weder `id`, `jti` noch die Konto-ID. Test: „oauth-adapter: unbekanntes konto wirft“.
- **AC-17:** Nichts im Log: Während der Fälle aus AC-2 bis AC-16 wird `console.*` und `process.stdout`/`process.stderr` mitgeschnitten (Mitschnitt im Test selbst); der Mitschnitt enthält keine `id`, kein `jti`, keinen Payload-Wert und keine Konto-ID. Test: „oauth-adapter: nichts im log“.
- **AC-18:** Grenze, Länge, Gesamtlauf: Dieser Schnitt ändert genau die sechs Dateien aus „Source“ (`git diff --name-only origin/main -- server` in `/60-validate` belegt, **nicht** als Test, weil ein Diff-Test gegen `main` in der CI und nach dem Merge bricht); `package.json` und Lockfile sind unverändert; jede Funktion hat höchstens 50 Zeilen; `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf. Nachweis: Lauf von `./server/scripts/test-local.sh` und `/60-validate`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/migrations/004_oauth.sql` | CREATE | Tabelle `oauth_records`, Fremdschlüssel, vier Indizes, ≈ 20 |
| `server/src/oauth-adapter.ts` | CREATE | `PgAdapter` mit Schnittstelle, Hashing, Aufräumen, ≈ 100 |
| `server/src/accounts.ts` | MODIFY | ein Statement in `deleteAccount`, ≈ +8 |
| `server/test/oauth-adapter.test.ts` | CREATE | AC-2 bis AC-17, ≈ 280–320 |
| `server/test/accounts.test.ts` | MODIFY | `deleteAccount` mit OAuth-Zeilen (AC-15), ≈ +40 |
| `server/test/schema.test.ts` | MODIFY | Migrationstest 004 (AC-1), ≈ +30 |

### Estimated Changes

- **Files: 6** (3 Code, 3 Tests; Spec und Kontext zählen nicht).
- **Code ≈ +130 LoC** (Migration, Adapter, `deleteAccount`), **Tests ≈ +350–400 LoC** (≈ 2,5× Code), insgesamt ≈ 480–530 LoC.
- **Das 250-LoC-Limit wird insgesamt überschritten.** Die Überschreitung stammt aus Sicherheitstests (Klartextfreiheit per SQL, Einmal-Einlösen unter Gleichzeitigkeit, Replay, Ablauf per Zeitsprung, Konto-Löschung, Log); der Code-Anteil allein bleibt innerhalb des Limits. Das folgt der Projekt-Präzedenz #615 S2a (Sicherheitsbaustein, Tests ≈ 2,5× Code geschätzt, Freigabe vor dem Bauen) und der Notiz „Tests ≈ 2,5× Code schätzen“. Mit der Freigabe dieser Spec wird die Überschreitung ausdrücklich angenommen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, kein `generate`. Seiteneffekt außerhalb des Tickets: keiner nach außen, solange nichts den Adapter einhängt (S3) und nginx `/mcp` nicht durchlässt.

## Risiken

- **Getestet nur gegen die dokumentierte Schnittstelle:** Abweichungen der echten Bibliothek (z. B. Format von `consumed`, Umgang mit `jti` bei `findByUid`) zeigt erst das Spike-Gate in S3. Gegenmaßnahme: `payload jsonb` hält Nacharbeit migrationsfrei; die Annahmen stehen als Tests (AC-2, AC-7, AC-10).
- **`findByUid` ohne `jti`:** Die Session-Id lässt sich aus dem Hash nicht zurückgewinnen. Nach Quelltext 9.13.3 braucht keiner der beiden Aufrufer sie (siehe `findByUid` oben); ändert eine spätere Version das, zeigt es das Spike-Gate in S3, und die Antwort wäre die Id verschlüsselt abzulegen.
- **Hash statt Klartext:** Eine Untersuchung der Tabelle von Hand zeigt keine Token mehr; gewollt (AC-7). `findByUid` liest über die Klartext-`uid`; die `uid` einer Session ist kein Zugangsnachweis.
- **Nur additiv ab dem ersten Deploy:** `oauth_records` wird in Produktion von nun an nicht mehr umbenannt oder gelöscht; Änderungen kommen als weitere Migration.
- **Aufräumen ohne Timer:** Läuft der Prozess lange ohne `upsert`, bleiben abgelaufene Zeilen liegen. Sie sind für `find` unsichtbar (AC-8), kosten nur Platz.
- **Fremdschlüssel wirft bei gelöschtem Konto:** Ein `upsert` mit `accountId` eines gelöschten Kontos scheitert (AC-16); gewollt, denn das Konto existiert nicht mehr. S3 muss das als Fehler der Anmeldung behandeln.
- **Gleichzeitigkeit nur im Test mit einem Pool:** Zwei Prozesse gegen dieselbe Datenbank verhalten sich gleich, weil die Atomarität im SQL-Statement liegt, nicht im Prozess.

## Test Plan

### Automated Tests (TDD RED)

RED: `server/src/oauth-adapter.ts` und `004_oauth.sql` existieren nicht; die Tests schlagen fehl (fehlender Import `PgAdapter`, Tabelle `oauth_records` unbekannt, `deleteAccount` lässt Zeilen stehen, `migrate` meldet nur drei Migrationen).

| Testname | AC |
|---|---|
| „migration 004: additiv auf bestandsdaten“ | AC-1 |
| „oauth-adapter: upsert und find“ | AC-2 |
| „oauth-adapter: unbekannt und modelle getrennt“ | AC-3 |
| „oauth-adapter: find by uid“ | AC-4 |
| „oauth-adapter: destroy“ | AC-5 |
| „oauth-adapter: revoke by grant id“ | AC-6 |
| „oauth-adapter: ids nur als hash“ | AC-7 |
| „oauth-adapter: abgelaufenes verborgen“ | AC-8 |
| „oauth-adapter: ohne ablauf bleibt“ | AC-9 |
| „oauth-adapter: consume einmal“ | AC-10 |
| „oauth-adapter: zwei gleichzeitige consume“ | AC-11 |
| „oauth-adapter: replay detection atomar“ | AC-12 |
| „oauth-adapter: find by user code nicht unterstuetzt“ | AC-13 |
| „oauth-adapter: aufraeumen hoechstens alle 10 minuten“ | AC-14 |
| „accounts: delete nimmt oauth zeilen mit“ | AC-15 |
| „oauth-adapter: unbekanntes konto wirft“ | AC-16 |
| „oauth-adapter: nichts im log“ | AC-17 |
| `./server/scripts/test-local.sh` und `/60-validate` (Dateiliste per `git diff`) | AC-18 |

- [ ] Test 1 (AC-1): GIVEN Datenbank mit 001–003 und Bestandsdaten WHEN 004 läuft THEN Tabelle da, Bestand unverändert, zweiter Lauf leer.
- [ ] Test 2 (AC-2 bis AC-6): GIVEN Datensätze mehrerer Modelle WHEN `upsert`, `find`, `findByUid`, `destroy`, `revokeByGrantId` THEN Schnittstelle der Bibliothek erfüllt, Modelle und Grants getrennt.
- [ ] Test 3 (AC-7): GIVEN ein Token mit `jti` WHEN direkt per SQL gelesen THEN kein Klartext, nur Hash, kein `jti` im jsonb.
- [ ] Test 4 (AC-8, AC-9, AC-14): GIVEN eingereichte Uhr WHEN Zeitsprünge THEN Abgelaufenes verborgen, ohne Ablauf bleibt, Aufräumen höchstens alle 10 Minuten.
- [ ] Test 5 (AC-10, AC-11, AC-12): GIVEN gleichzeitige Aufrufe WHEN `consume` bzw. Replay-`upsert` THEN genau einer gelingt, die übrigen werfen.
- [ ] Test 6 (AC-13, AC-16, AC-17): GIVEN ungewöhnliche Eingaben WHEN Aufruf THEN definierter Fehler ohne Werte im Fehlertext und im Log.
- [ ] Test 7 (AC-15): GIVEN zwei Konten mit OAuth-Zeilen WHEN `deleteAccount(A)` THEN A weg, B und Client unberührt.
- [ ] Test 8 (AC-18): GIVEN fertiger Stand WHEN `./server/scripts/test-local.sh` THEN typecheck und alle Tests grün.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): Eine Tabelle `oauth_records` für alle Modelle, Ids als SHA-256, `jti` nicht im Payload, Uhr eingereicht, Aufräumen opportunistisch.** Kleinste Fläche, folgt der Hausregel „Geheimnisse nie im Klartext“, Atomarität liefert SQL.
- **B: Ids im Klartext** wie in den Beispielen der Bibliothek: etwa 20 LoC weniger und einfacher von Hand zu untersuchen, aber ein Datenbank-Leck macht Refresh-Tokens direkt nutzbar; verstößt gegen „Geheimnisse nie im Klartext“ (#615). Verworfen.
- **C: Je Modell eine Tabelle:** echte Fremdschlüssel je Art, aber 15 fast gleiche Tabellen und Adapterzweige. Verworfen.
- **D: Sitzungsablauf (Merkposten aus #615) mitnehmen** (+≈ 25 LoC, Migration 005): nur sinnvoll, wenn er vor der App (#615 S4) gebraucht würde; die App gibt bis S4 keine Sitzung aus, und seit S1 nimmt `/mcp` keine App-Sitzung mehr an. Verworfen.
- Befunde gegen den Plan: keine blockierenden. Die Wahl des Ausstellers (ADR-21: `oidc-provider` statt Eigenbau) fällt erst mit S3.

## Out of Scope / Folgeschnitte

- **Sitzungsablauf (Merkposten aus #615):** nicht in diesem Schnitt, **zurück an #615 S4**. Er hing nur an #621, solange `/mcp` `resolveSession` benutzte; seit S1 nimmt `/mcp` keine App-Sitzung mehr an. Er betrifft nur noch die App-Sitzung (`/auth/logout`, `/auth/delete`) und braucht eine Migration an `sessions` samt Festlegung der Laufzeit. OAuth-Token laufen über `expiresIn` ab. Ein Kommentar an #615 hält das fest.
- **S3 Aussteller:** `oidc-provider` als Abhängigkeit, Einhängen, `adapter: (name) => new PgAdapter(pool, name)`, Spike-Gate gegen die echte Bibliothek, `verifier` an AccessToken, AS-Metadaten, ADR-21-Nachtrag.
- **S4a/S4b Apple-Web, S5 Zustimmung und Erlaubnisliste, S6 Betrieb und echter Connect, S7 Abschrift v2:** wie im Schnittplan.
- Kein Einhängen von `/mcp` oder des Adapters in `main.ts`; `/mcp` bleibt hinter `rejectAll`.

## Abnahme

Kein Pfad der Geräteliste berührt (nur `server/`). Die Abnahme endet nach den Tests: `./server/scripts/test-local.sh` (typecheck + `npm test` gegen ein Wegwerf-Postgres) grün und die CI `server.yml` auf dem PR grün. Sichtbar ändert sich nichts; `/mcp` bleibt hinter `rejectAll` und öffentlich hinter nginx zu. Stufe 3 entfällt.

## Definition of Done

- [ ] AC-1 bis AC-18 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt in einer Zeile `migrations/004_oauth.sql`, `src/oauth-adapter.ts` und die Erweiterung von `deleteAccount` (Dokumentation, zählt nicht gegen die Dateigrenze, wie Spec und Kontext)
- [ ] #621 kommentiert (Stand Schnitt 2, Folge: S3 Aussteller), #615 kommentiert (Sitzungsablauf zurück an S4), Board-Karte aktuell

## Changelog

- 2026-11-05: Initial spec created (Schnitt 2)
