---
entity_id: feat-615-schnitt-1-konten-sitzungen
type: feature
created: 2026-11-02
updated: 2026-11-02
status: draft
workflow: feat-615-konto-anmeldung
---

# Spec: Kontotabelle und Sitzungen im Dienst, Schnitt 1 (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 1 von 4; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-konto-anmeldung.md`, Abschnitt „Analysis“. Vorgänger im Dienst: C4b-2 (`docs/specs/feat-613-c4b2-mcp-complete-setdue.md`), Schema C1b (`docs/specs/spike-613-schnitt-c1b-schema.md`).
Nicht Teil dieser Spec: S2 Apple-Anbindung (Identity-Token prüfen, Code einlösen, widerrufen, Verschlüsselung des Refresh-Tokens), S3 HTTP-Rand (Port, `POST /auth/apple`, Bearer-Prüfung), S4 App, Datenschutztext (#625), Betrieb (#796).

## Purpose

Der Dienst kennt bisher kein Konto: `transcripts.account_id` und `orders.account_id` sind freie Texte ohne Fremdschlüssel (Kommentar in `001_claude_schema.sql`: „until the account table arrives“). Dieser Schnitt legt das Konto an, auf dem alles Weitere aufbaut: eine Kontotabelle mit `apple_sub` als einzigem Schlüssel, undurchsichtige Sitzungs-Token, die nur als Hash gespeichert werden, und Löschen eines Kontos samt aller seiner Daten in einer Transaktion (Pflicht aus App-Store-Regel 5.1.1(v), Apple TN3194).

Es entsteht nur Dienstcode ohne Port und ohne Apple-Anbindung: nichts ruft ihn auf, die App ruft den Dienst weiter nirgends auf (ADR-21). Er ist komplett offline gegen echtes Postgres testbar.

**Regeln vor Modell:** Konto, Zufall, Hash, SQL. Es gibt keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Weg B und das Konto nur für Claude-Nutzer sind mit ADR-21 entschieden; dieser Schnitt setzt die Tabelle um. ADR-21 bekommt später den Zusatz „App-Sitzung ≠ OAuth“ (mit S3 oder #621), nicht in diesem Schnitt.

## Source

**Files:** `server/migrations/002_accounts.sql`, `server/src/accounts.ts`, `server/test/accounts.test.ts`, `server/test/schema.test.ts`, `CLAUDE.md`
**Identifier:** `findOrCreate`, `createSession`, `resolveSession`, `endSession`, `deleteAccount`

### Schema (`002_accounts.sql`)

Kein `BEGIN`/`COMMIT` (der Läufer umschließt die Datei). Neue Tabellen:

- `accounts(id text PRIMARY KEY DEFAULT gen_random_uuid()::text, apple_sub text NOT NULL UNIQUE, created_at timestamptz NOT NULL DEFAULT now())`. **`id` ist `text`**, weil `transcripts.account_id` und `orders.account_id` schon `text` sind und `mcp.ts` das Konto als Text aus `authInfo` liest; ein Typwechsel dort wäre Folgearbeit ohne Nutzen. Die Kennung bleibt eine UUID in Textform. `apple_sub` ist der einzige Kontoschlüssel, nie E-Mail (privates Relay).
- `sessions(token_hash bytea PRIMARY KEY, account_id text NOT NULL REFERENCES accounts (id) ON DELETE CASCADE, created_at timestamptz NOT NULL DEFAULT now(), last_used_at timestamptz NOT NULL DEFAULT now())`, dazu ein Index auf `account_id`.
- `apple_tokens(account_id text PRIMARY KEY REFERENCES accounts (id) ON DELETE CASCADE, refresh_token_enc bytea NOT NULL, created_at timestamptz NOT NULL DEFAULT now())`. Hier nur die Spalte für den verschlüsselten Refresh-Token; Verschlüsseln und Einlösen kommt in S2, `accounts.ts` liest die Bytes nur durch.

Bestehende Tabellen bleiben **unverändert** (kein `ALTER TABLE`, siehe Risiken): `transcripts.account_id` und `orders.account_id` bekommen in diesem Schnitt keinen Fremdschlüssel, `order_results` behält seine Regel. `deleteAccount` räumt sie ausdrücklich ab.

### Funktionen (`accounts.ts`)

Reine Funktionen über `pg.Pool` wie `transcripts.ts`/`orders.ts`, jede ≤ 50 Zeilen, keine neue npm-Abhängigkeit, nichts nach `console`/`stdout`:

- **`findOrCreate(pool, appleSub)`** → Kontokennung. Idempotent und nebenläufigkeitsfest durch ein Statement (`INSERT … ON CONFLICT (apple_sub) DO UPDATE SET apple_sub = EXCLUDED.apple_sub RETURNING id`); zwei gleichzeitige Aufrufe ergeben ein Konto.
- **`createSession(pool, accountId)`** → Klartext-Token: 32 Byte aus `randomBytes`, `base64url`. Gespeichert wird nur `sha256(token)` als `bytea`. Der Klartext verlässt die Funktion nur als Rückgabewert.
- **`resolveSession(pool, token)`** → Kontokennung oder `null`; setzt dabei `last_used_at = now()` (ein Statement `UPDATE … RETURNING`). Unbekannt, beendet, leer oder nicht-Text → `null`, nie eine Ausnahme.
- **`endSession(pool, token)`** → `boolean` (gab es die Sitzung), löscht nur diese eine Zeile.
- **`deleteAccount(pool, accountId)`** → `{ deleted: boolean, appleToken: Buffer | null }`: ob es das Konto gab (S3 braucht das für seine Antwort) und das verschlüsselte Apple-Token (oder `null`) für den späteren Widerruf. Eine Transaktion: Kontozeile sperren (`SELECT … FOR UPDATE`), Token lesen, dann `order_results` der Aufträge des Kontos, `orders`, `transcripts` (je `WHERE account_id = $1`) und zuletzt `accounts` löschen; Sitzungen und Apple-Token gehen über ihre Fremdschlüssel mit. Unbekanntes Konto → `{ deleted: false, appleToken: null }`, nichts passiert. Löschen gelingt ohne Apple-Token (TN3194: der Nutzer widerruft dann selbst).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/src/migrate.ts` (Läufer, je Datei eine Transaktion) | bestehend, **unverändert**; wendet `002` an |
| `server/migrations/001_claude_schema.sql` | bestehend, **unverändert**; `002` fasst seine Tabellen nicht an |
| `server/src/transcripts.ts`, `orders.ts`, `mcp.ts` | bestehend, **unverändert** (SQL läuft weiter mit Konto als Text) |
| `server/test/db.ts` (`freshPool`) | Testaufbau, **unverändert** |
| `node:crypto`, `pg` | bestehend, **keine neuen Pakete** |
| Downstream | S2 (Apple-Token), S3 (HTTP-Rand, Bearer), #795, #621 (übernimmt `accounts` über `apple_sub`) |

## Acceptance Criteria

Alle Tests laufen gegen echtes Postgres (`freshPool`), im Prozess, ohne Port.

- **AC-1:** Der Migrationsläufer wendet auf einer leeren Datenbank genau `["001_claude_schema.sql", "002_accounts.sql"]` an, ein zweiter Lauf wendet nichts an; die Tabellen `accounts`, `sessions`, `apple_tokens` existieren.
- **AC-2:** `findOrCreate` mit demselben `apple_sub` liefert dieselbe Kennung (auch bei zwei gleichzeitigen Aufrufen, genau eine Zeile in `accounts`); ein anderer `apple_sub` liefert eine andere Kennung.
- **AC-3:** `createSession` liefert einen `base64url`-Token aus 32 Byte (43 Zeichen); die Tokens zweier Aufrufe unterscheiden sich; in `sessions` steht `sha256(token)`, und der Klartext kommt in keiner Spalte jeder Zeile von `sessions` (als Text gelesen) vor.
- **AC-4:** `resolveSession` liefert für einen gültigen Token die Kontokennung und setzt `last_used_at` neu (der Test setzt es vorher per `UPDATE` auf einen festen Zeitpunkt in der Vergangenheit und erwartet danach einen späteren); für einen unbekannten, leeren, veränderten oder nicht-Text-Token (`undefined`, Zahl) liefert es `null`.
- **AC-5:** Nach `endSession` liefert `resolveSession` für diesen Token `null`; weitere Sitzungen desselben Kontos bleiben gültig; `endSession` für einen unbekannten Token gibt `false` zurück, ohne Ausnahme.
- **AC-6:** `createSession` für eine nicht vorhandene Kontokennung wird vom Fremdschlüssel abgelehnt.
- **AC-7:** `deleteAccount` entfernt für ein Konto mit Sitzung, Apple-Token, Abschrift, Auftrag und Ergebnis jede Zeile dieses Kontos aus `accounts`, `sessions`, `apple_tokens`, `transcripts`, `orders` und `order_results` und gibt `deleted: true` mit den gespeicherten Bytes des Apple-Tokens zurück.
- **AC-8:** Ein zweites Konto mit denselben Arten von Zeilen bleibt nach `deleteAccount` des ersten vollständig unberührt (Zeilenzahl je Tabelle, seine Sitzung löst weiter auf).
- **AC-9:** `deleteAccount` ohne Apple-Token gibt `{ deleted: true, appleToken: null }` zurück und löscht trotzdem alles; für ein unbekanntes Konto gibt es `{ deleted: false, appleToken: null }` und ändert nichts.
- **AC-10:** `deleteAccount` entfernt auch Ergebnisse zu Aufträgen des Kontos, die schon abgeholt und beantwortet sind (Auftrag mit `claimed_by`, `claimed_at` und Zeile in `order_results`), ohne Fremdschlüsselfehler.
- **AC-11:** Die bestehenden Tests zu Abschrift, Aufträgen und MCP laufen unverändert weiter (ihre Dateien bleiben unberührt); im Schema-Test ändern sich nur die erwartete Migrationsliste und die erwartete Zeilenzahl von `schema_migrations` (1 → 2) im dortigen AC-1-Test. `npm run typecheck` und `./server/scripts/test-local.sh` sind grün und räumen auf; `server.yml` ist auf dem PR grün.
- **AC-12:** Während aller `accounts`-Aufrufe eines Tests (inklusive des scheiternden `createSession` aus AC-6) wird nichts nach `console` oder `process.stdout` geschrieben (Test ersetzt beide vorübergehend), und der Fehlertext des scheiternden Aufrufs enthält weder Token noch `apple_sub`.
- **AC-13:** `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau die fünf Dateien aus „Affected Files“ (Workflow-Unterlagen unter `docs/` und `.claude/` zählen nicht); insbesondere bleiben `server/package.json`, `server/src/mcp.ts`, `transcripts.ts`, `orders.ts`, `migrate.ts`, `001_claude_schema.sql`, `server/test/db.ts`, `transcripts.test.ts`, `orders.test.ts`, `mcp.test.ts`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/migrations/002_accounts.sql` | CREATE | drei neue Tabellen, ~+25 |
| `server/src/accounts.ts` | CREATE | fünf Funktionen, ~+80 |
| `server/test/accounts.test.ts` | CREATE | AC-1 (Tabellen) bis AC-10, ~+130 |
| `server/test/schema.test.ts` | MODIFY | AC-1-Test: erwartete Migrationsliste `001`+`002` und `rowCount` 2, ~+2/−2 |
| `CLAUDE.md` | MODIFY | `server/`-Zeile: `002_accounts`, `src/accounts.ts`, ~+2 |

### Estimated Changes

- Files: 5 (3 neu, 2 geändert).
- LoC: ≈ +240/−2. Code ≈ 105, Tests ≈ 132, Doku ≈ 2. Zeichnet sich eine Überschreitung ab, wird gestoppt und nachgefragt.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, kein `generate`. Eine neue Migration (`002`), nur im Dienst. Seiteneffekt außerhalb des Tickets: keiner; nichts in der App ruft den Dienst auf.

## Risiken

- **Abschrift und Aufträge ohne Fremdschlüssel:** Ein Fremdschlüssel auf `accounts` hätte vier bestehende Testdateien zum Umbau gezwungen (sie benutzen viele frei gebildete Kontotexte, z. B. `konto-${name}`) und die Dateigrenze auf 8 gehoben. Stattdessen löscht `deleteAccount` diese Zeilen ausdrücklich in derselben Transaktion. Rest-Risiko: Schreibt jemand genau während des Löschens noch eine Abschrift mit der alten Kennung, bliebe eine verwaiste Zeile. Das kann erst ab S3 passieren; dort prüft jeder Schreibweg vorher die Sitzung, die mit dem Konto verschwindet. Ob der Fremdschlüssel nachgezogen wird, entscheidet S3.
- **Ohne Constraint-Austausch** bleibt die Regel „Migrationen nur hinzufügend“ wörtlich erfüllt: `002` legt nur neue Tabellen an.
- **Sitzung ohne Ablauf:** Es gibt kein `expires_at`; Ablauf, Ratenlimit und Rotation gehören an den HTTP-Rand (S3) und sind mit `created_at`/`last_used_at` ohne Schemaänderung möglich.

## Test Plan

### Automated Tests (TDD RED)

RED: Zuerst `accounts.test.ts` und die geänderte Erwartung in `schema.test.ts`; `accounts.ts` und `002` fehlen, die Tests schlagen fehl.

- [ ] Test 1 (AC-1): GIVEN eine leere Datenbank WHEN `migrate` zweimal läuft THEN erst beide Namen, dann `[]`, die drei Tabellen existieren.
- [ ] Test 2 (AC-2): GIVEN ein `apple_sub` WHEN `findOrCreate` zweimal und parallel läuft THEN dieselbe Kennung, eine Zeile; ein anderer `apple_sub` gibt eine andere.
- [ ] Test 3 (AC-3): GIVEN ein Konto WHEN `createSession` zweimal THEN zwei verschiedene 43-Zeichen-Tokens, gespeichert nur als SHA-256, Klartext in keiner Zeile.
- [ ] Test 4 (AC-4, AC-5): GIVEN eine Sitzung mit `last_used_at` per `UPDATE` auf einen festen früheren Zeitpunkt WHEN `resolveSession` mit gültigem, unbekanntem, leerem, verändertem, nicht-Text- (`undefined`, Zahl) und beendetem Token THEN Kennung bzw. `null`, `last_used_at` liegt danach später, andere Sitzung bleibt gültig, `endSession` unbekannt gibt `false`.
- [ ] Test 5 (AC-6, AC-10): GIVEN keine Kontozeile WHEN eine Sitzung angelegt wird THEN Fremdschlüsselfehler 23503; GIVEN ein Konto mit abgeholtem, beantwortetem Auftrag WHEN `deleteAccount` THEN Auftrag und Ergebnis weg, kein Fehler.
- [ ] Test 6 (AC-7, AC-8): GIVEN zwei Konten mit je Sitzung, Apple-Token, Abschrift, Auftrag, Ergebnis WHEN `deleteAccount` für das erste THEN seine Zeilen in allen sechs Tabellen weg, Bytes des Apple-Tokens zurück, das zweite unberührt.
- [ ] Test 7 (AC-9): GIVEN ein Konto ohne Apple-Token bzw. eine unbekannte Kennung WHEN `deleteAccount` THEN `null`, Löschen gelingt bzw. nichts ändert sich.
- [ ] Test 8 (AC-12): GIVEN `console.log/error/warn` und `process.stdout.write` vorübergehend ersetzt WHEN `findOrCreate`, `createSession` (auch für ein unbekanntes Konto), `resolveSession`, `endSession`, `deleteAccount` laufen THEN keine Ausgabe, Fehlertext ohne Token und ohne `apple_sub`.
- [ ] Test 9 (AC-11): GIVEN alle Tests WHEN `./server/scripts/test-local.sh` THEN grün; `server.yml` auf dem PR grün.
- [ ] Test 10 (AC-13): GIVEN der fertige Zweig WHEN `git diff --name-only origin/main -- . ':!docs' ':!.claude'` THEN genau die fünf Dateien.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): nativ „Mit Apple anmelden“ und ein eigenes, undurchsichtiges Sitzungs-Token.** Klein, offline testbar, unabhängig von #796 und #621; `apple_sub` als Schlüssel, #621 übernimmt die Tabelle. Preis: ein zweiter Token-Weg neben dem OAuth-Server von #621 (Hash, Ablauf, Widerruf selbst gebaut). ADR-21 bleibt gültig (kein OAuth-Server, nur ein Bearer für die eigene App), bekommt später den Zusatz „App-Sitzung ≠ OAuth“.
- **B: die App als OAuth-Client des Servers aus #621.** Ein Token-Weg, aber blockiert auf #621 und #796, Browserblatt statt des Face-ID-Blatts, größter Umfang. Nicht gewählt.
- **C: kein App-Konto.** Nichts zu bauen, aber die App hat keine Berechtigung für #795, und „Konto löschen in der App“ (Regel 5.1.1(v)) wäre unmöglich. Nicht gewählt.
- **Innerhalb dieses Schnitts, Sitzungs-Token:** ein signiertes Token (JWT) statt Zufall plus Hash ginge ohne Datenbankzugriff, ließe sich aber nicht einzeln beenden und bräuchte eine Bibliothek oder eigene Signaturlogik; nicht gewählt.
- **Innerhalb dieses Schnitts, Löschen:** Fremdschlüssel mit `ON DELETE CASCADE` von `transcripts`/`orders` auf `accounts` (Datenbank erzwingt Konsistenz) statt ausdrücklichem Löschen. Nicht gewählt, weil es acht Dateien und einen Constraint-Austausch an `order_results` braucht; in S3 neu zu prüfen.

## Nicht in diesem Schnitt / Folgeschnitte

- S2 Apple-Anbindung (`server/src/apple.ts`): Identity-Token prüfen, Code einlösen, widerrufen, Verschlüsselung (AES-256-GCM) des Refresh-Tokens.
- S3 HTTP-Rand (`server/src/http.ts`): `POST /auth/apple`, `POST /auth/logout`, `DELETE /account`, Bearer-Prüfung, Limits; Widerruf nach dem Löschen.
- S4 App (nach #625): Entitlement, Keychain, Einstellungen; dort greift Stufe 3.
- Datenschutztext (#625), Betrieb (#796), Claude-Connector (#621).

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulatorablauf sinnvoll. Nachweis: `./server/scripts/test-local.sh` (typecheck + test) grün und der CI-Job `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Zeile) nennt `002_accounts` und `src/accounts.ts`
- [ ] #615 kommentiert (Stand Schnitt 1), Board-Karte aktuell

## Changelog

- 2026-11-02: Initial spec created (Schnitt 1)
- 2026-11-02: Ausdrückliches Löschen statt Fremdschlüssel auf Abschrift/Aufträge; 5 statt 8 Dateien, `CLAUDE.md` im Scope
