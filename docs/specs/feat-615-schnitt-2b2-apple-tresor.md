---
entity_id: feat-615-schnitt-2b2-apple-tresor
type: feature
created: 2026-11-03
updated: 2026-11-03
status: draft
workflow: feat-615-s2b2-apple-vault
---

# Spec: Apples Refresh-Token verschlüsselt ablegen, Schnitt 2b-2 (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 2b-2; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s2b2-apple-vault.md`, Abschnitt „Analysis“. Vorgänger: Schnitt 2b-1 (JWKS-Cache) und Schnitt 2a (`docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md`), dessen Abschnitt „Festgelegt für S2b und S2c“ dieser Schnitt umsetzt. Einlösen des Codes und Widerruf bei Apple sind S2c, ein eigener Workflow.

## Für den PO

Wenn jemand sein Konto löscht, verlangt Apple, dass wir die Anmeldung mit Apple dabei zurückziehen. Dafür muss der Dienst einen Schlüssel von Apple aufheben, den er bei der Anmeldung bekommt. Dieser Schnitt baut den Tresor dafür: Der Schlüssel liegt nur verschlüsselt in der Datenbank. Wer sich einen Abzug der Datenbank beschafft, kann damit nichts anfangen, solange er den separat verwahrten Tresorschlüssel nicht hat. In der App ändert sich nichts Sichtbares, und nichts davon wird aufgerufen: Die App ruft den Dienst weiterhin nirgends auf (ADR-21). Es ist ein Baustein, den der nächste Schnitt benutzt.

## Purpose

Der Dienst muss beim Löschen eines Kontos Apples Refresh-Token widerrufen (App-Store-Richtlinie 5.1.1, Apple TN3194). Dafür muss er den Token bis dahin aufbewahren, im Ruhezustand aber nicht im Klartext. Dieser Schnitt baut `server/src/apple-vault.ts`: `encryptToken` und `decryptToken` (AES-256-GCM, das Konto als zusätzlich authentifizierte Angabe) und `storeRefreshToken` (Upsert in die bestehende Tabelle `apple_tokens`). `decryptToken` gibt bei jedem Fehler `null` zurück und wirft nie; ein von `deleteAccount` zurückgegebener Blob muss sich entschlüsseln lassen.

Es entsteht nur Dienstcode ohne Port und ohne Netz; nichts ruft ihn auf (ADR-21). S2c ruft `encryptToken` und `storeRefreshToken` beim Einlösen des Codes und `decryptToken` beim Löschen. Der Schlüssel kommt aus `AppleConfig.tokenKey` (32 Byte aus `APPLE_TOKEN_KEY`, Form seit S2a geprüft) und wird hereingereicht.

**Regeln vor Modell:** Verschlüsselung und Datenbankzugriff, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 und die Festlegung „Tresor“ der S2a-Spec um, keine neue Architekturentscheidung, keine neue Abhängigkeit (nur `node:crypto`).
- **Rationale:** Blobformat, Algorithmus, IV, AAD und `null`-Verhalten stehen in der S2a-Spec. Neu festgeschrieben wird nur, was dort offen blieb: feste Tag-Länge beim Entschlüsseln (DEP0182), Verhalten von `storeRefreshToken` bei unbekanntem Konto und `created_at` beim Überschreiben.

## Source

**Files:** `server/src/apple-vault.ts`, `server/test/apple-vault.test.ts`, `CLAUDE.md`
**Identifier:** `encryptToken`, `decryptToken`, `storeRefreshToken`

Eigene Datei: `apple.ts`, `accounts.ts` und `002_accounts.sql` bleiben wie gemergt; die Tabelle `apple_tokens` existiert seit S1.

### Schnittstelle

- `encryptToken(key: Buffer, accountId: string, token: string): Buffer` — Blob `[0x01 | iv 12 | tag 16 | ciphertext]`, AES-256-GCM, `iv = randomBytes(12)`, zusätzlich authentifizierte Angabe (AAD) = `Buffer.from(accountId)`. **Wirft** bei eigener Fehleingabe (Schlüssel ≠ 32 Byte, leerer Token, leere `accountId`); der Fehlertext enthält weder Schlüssel noch Token noch `accountId`. Ein `null` würde S2c ohne gespeicherten Token weitermachen lassen.
- `decryptToken(key: Buffer, accountId: string, blob: unknown): string | null` — **wirft nie.** Ergibt `null` bei: Blob kein `Buffer` (String, `Uint8Array`, `null`, `undefined`), Schlüssel ≠ 32 Byte, Blob kürzer als 29 Byte, Version ≠ `0x01`, Manipulation, falschem Schlüssel, falschem Konto. Sonst den Klartext.
- `storeRefreshToken(pool: pg.Pool, accountId: string, blob: Buffer): Promise<boolean>` — ein Statement: `INSERT INTO apple_tokens … ON CONFLICT (account_id) DO UPDATE SET refresh_token_enc = EXCLUDED.refresh_token_enc, created_at = now()`. Ergibt `true` bei Erfolg, `false` bei unbekanntem Konto (Fremdschlüsselverletzung `23503`); andere Datenbankfehler werden weitergeworfen.

### Festlegungen

- **Feste Tag-Länge:** Beim Entschlüsseln `createDecipheriv("aes-256-gcm", key, iv, { authTagLength: 16 })`. Ohne diese Angabe akzeptiert Node gekürzte Tags (bis 4 Byte, als DEP0182 veraltet), und eine Fälschung würde möglich. Die Bloblänge wird vorher geprüft, `setAuthAAD`, `setAuthTag` und `final` laufen in `try/catch` und ergeben `null`.
- **Kleinste gültige Länge:** 29 Byte (Version + IV + Tag, leerer Ciphertext) ist formal zulässig; das Tag authentifiziert auch diesen Fall.
- **Kontobindung:** Die AAD ist die `accountId`; ein in die Zeile eines anderen Kontos kopierter Blob ergibt dort `null`.
- **Upsert-Semantik:** Eine neue Anmeldung überschreibt den alten Blob (ein Token je Konto). `created_at` ist das Alter des gespeicherten Tokens und rückt darum beim Überschreiben auf `now()`.
- **Unbekanntes Konto:** FK-Fehler `23503` abfangen statt Vorabfrage, damit es kein Rennen gibt.
- **Schlüsselwechsel:** Ein neuer `APPLE_TOKEN_KEY` macht alte Blobs unlesbar (`null`, der Widerruf entfällt, Best Effort nach TN3194). Rotation ist nicht Teil dieses Schnitts; das Versionsbyte `0x01` hält den Platz dafür frei. In der S2c-Spec benennen.
- **Stille und Länge:** kein `console`, kein `process.stdout`/`stderr`; Geheimnisse (Token, Schlüssel, Klartext) nie in Fehlertexten; jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `node:crypto` (`createCipheriv`, `createDecipheriv`, `randomBytes`) | Standardbibliothek, **keine neuen Pakete** |
| `AppleConfig.tokenKey` aus `server/src/apple.ts` | bestehend, `apple.ts` **unverändert**; die Funktionen nehmen den Schlüssel als `Buffer`-Parameter |
| `pg.Pool`, Tabelle `apple_tokens` (`002_accounts.sql`) | bestehend, **keine Migration** |
| `deleteAccount`, `findOrCreate` aus `server/src/accounts.ts` | bestehend, unverändert; nur im Test benutzt |
| `server/test/db.ts` (`freshPool`), `migrate` | bestehend, unverändert |
| Downstream | S2c (`redeemCode` → `encryptToken` + `storeRefreshToken`; Löschen → `deleteAccount().appleToken` → `decryptToken` → `revokeToken`), S3 |

## Acceptance Criteria

Die reinen Verschlüsselungstests laufen im Prozess ohne Netz und ohne Datenbank, die Speichertests (AC-9 bis AC-12) gegen das Wegwerf-Postgres von `./server/scripts/test-local.sh` (`freshPool` + `migrate`, ein eigenes Schema je Test). Alle mit `node:test` und `node:assert/strict`. Angriffsfälle stehen tabellengetrieben in einer Fallliste, ein Fall je Zeile.

- **AC-1:** Rundweg und Blobform: `decryptToken(key, id, encryptToken(key, id, token))` ergibt den Token zurück, für einen kurzen, einen langen (4 KiB) und einen Token mit Umlauten und Emoji; das erste Byte des Blobs ist `0x01`, die Länge ist `29 +` Klartextlänge in Bytes. Test: `server/test/apple-vault.test.ts`, „roundtrip: blobform“.
- **AC-2:** Angriffsfälle ergeben `null`: für jede Zeile der Fallliste — Version `0x00`, `0x02` und `0xFF`; je ein gekipptes Byte in IV, Tag und Ciphertext; Tag auf 15 Byte gekürzt (Blob 1 Byte kürzer, auch mit angepasstem Rest); Blob mit 28 Byte; leerer Buffer; falscher Schlüssel; falsches Konto — ergibt `decryptToken` `null` und wirft nie. Test: `apple-vault.test.ts`, „attack: manipuliert, falsch, zu kurz“ (Fallliste).
- **AC-3:** Fremde Eingabetypen: Als `blob` ergeben `null`, ein Text (auch der Hex- und Base64-Text eines gültigen Blobs), `Uint8Array` mit gültigem Inhalt, `undefined`, `null`, eine Zahl und ein Objekt jeweils `null`, ohne zu werfen. Test: `apple-vault.test.ts`, „attack: kein Buffer“ (Fallliste).
- **AC-4:** Schlüssellänge beim Entschlüsseln: Ein Schlüssel mit 31 oder 33 Byte und ein leerer Schlüssel ergeben bei einem sonst gültigen Blob `null`, ohne zu werfen. Test: `apple-vault.test.ts`, „decrypt: schlüssellänge“.
- **AC-5:** Kleinster Blob: Ein mit leerem Ciphertext authentisch gebildeter Blob von genau 29 Byte (Tag über einen leeren Klartext, zum Beispiel per `createCipheriv` im Test erzeugt) wird nicht wegen der Länge abgelehnt und ergibt `""`; dagegen ergibt derselbe Blob mit gekipptem Tag-Byte `null`. Test: `apple-vault.test.ts`, „decrypt: 29 Byte“.
- **AC-6:** `encryptToken` wirft bei eigener Fehleingabe: Schlüssel mit 31 oder 33 Byte, leerer Token, leere `accountId`; der Fehlertext enthält weder den Schlüssel (hex und base64) noch den Token noch die `accountId` (Testwerte `GEHEIM-123` für den Token, eine erkennbare UUID für das Konto). Test: `apple-vault.test.ts`, „encrypt: wirft bei Fehleingabe“.
- **AC-7:** IV-Eindeutigkeit: 1000 Verschlüsselungen desselben Klartexts mit demselben Schlüssel und Konto ergeben 1000 verschiedene IV (Bytes 1 bis 12) und 1000 verschiedene Blobs. Test: `apple-vault.test.ts`, „encrypt: iv je blob verschieden“.
- **AC-8:** Kein Klartext im Blob: Der Blob enthält den Klartext-Token nicht als Byte-Folge (`blob.includes(Buffer.from(token))` ist `false`, Token von mindestens 16 Byte). Test: `apple-vault.test.ts`, „encrypt: kein klartext im blob“.
- **AC-9:** Upsert überschreibt: Nach `storeRefreshToken` mit Blob A und danach mit Blob B für dasselbe Konto steht genau eine Zeile in `apple_tokens`, `refresh_token_enc` ist B, `created_at` ist nicht kleiner als zuvor und hat sich durch das Überschreiben vorwärts bewegt (Prüfung mit `pg_sleep` oder gesetztem Altwert); beide Aufrufe ergeben `true`. Test: `apple-vault.test.ts`, „store: überschreibt“.
- **AC-10:** Unbekanntes Konto: `storeRefreshToken` mit einer nicht vorhandenen `accountId` ergibt `false`, wirft nicht und legt keine Zeile an; ein anderer Datenbankfehler (Aufruf auf einem Pool nach `end()`) wird weitergeworfen und nicht als `false` verschluckt. Test: `apple-vault.test.ts`, „store: unbekanntes konto“.
- **AC-11:** Rundweg über `deleteAccount`: Konto per `findOrCreate`, `storeRefreshToken(pool, id, encryptToken(key, id, token))`, danach `deleteAccount`; der zurückgegebene `appleToken` ist ein Blob, den `decryptToken(key, id, appleToken)` zum Original-Token entschlüsselt; die Zeile in `apple_tokens` ist danach weg (Kaskade). Test: `apple-vault.test.ts`, „store: rundweg über deleteAccount“.
- **AC-12:** Konto gebunden in der Datenbank: Der aus der Zeile von Konto 1 gelesene Blob ergibt für Konto 2 `null`, auch wenn er dort in die Tabelle geschrieben wurde. Test: `apple-vault.test.ts`, „store: blob gehört zum konto“.
- **AC-13:** Stille: Während aller Aufrufe der Tests AC-1 bis AC-12 (Erfolg, `null`, Wurf) wird nichts nach `console` oder `process.stdout`/`process.stderr` geschrieben (der Test ersetzt sie vorübergehend), und `decryptToken` ergibt immer `string` oder `null`. Test: `apple-vault.test.ts`, „silence“.
- **AC-14:** Regression, CI und Funktionslänge: Test: `./server/scripts/test-local.sh` (typecheck + alle Tests, einschließlich der DB-Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, die bestehenden Testdateien bleiben unverändert; jede Funktion in `server/src/apple-vault.ts` hat höchstens 50 Zeilen (Prüfung in der Validierung: `grep -nE "function" server/src/apple-vault.ts`, Abstand zweier Funktionsanfänge und Dateiende ≤ 50).
- **AC-15:** Dateigrenze: Test: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple-vault.ts`, `server/test/apple-vault.test.ts` und `CLAUDE.md`; `server/src/apple.ts`, `server/src/accounts.ts`, `server/migrations/`, `server/test/db.ts`, `server/test/accounts.test.ts`, `server/package.json`, `server/package-lock.json`, `server/src/main.ts`, `.github/workflows/`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple-vault.ts` | CREATE | `encryptToken`, `decryptToken`, `storeRefreshToken`, ~+55 |
| `server/test/apple-vault.test.ts` | CREATE | AC-1 bis AC-13, tabellengetrieben, ~+130 bis 150 |
| `CLAUDE.md` | MODIFY | eine Zeile im Abschnitt `server/`: `src/apple-vault.ts`, ~+1 |

### Estimated Changes

- Files: 3 (2 neu, 1 geändert).
- LoC: ≈ 190 bis 210 gesamt, gezählt wie in S1, S2a und S2b-1 (Code, Tests und Doku zusammen): Code ≈ 55, Tests ≈ 130 bis 150, Doku ≈ 1. Limit ±250. Wird es knapp, wird vor dem Bauen gefragt; die Tests werden nicht gekürzt. Funktionen ≤ 50 Zeilen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, kein `generate`, keine Migration, kein Eingriff in `apple.ts` oder `accounts.ts`. Seiteneffekt außerhalb des Tickets: keiner; nichts ruft den Code auf.

## Risiken

- **Gekürzter Tag:** Ohne feste `authTagLength` wäre eine Fälschung möglich; darum Längenprüfung plus `authTagLength: 16` (AC-2, AC-5).
- **Blob-Vertauschung:** Ohne AAD ließe sich ein Blob in die Zeile eines anderen Kontos kopieren; die AAD schließt das aus (AC-2, AC-12).
- **Schlüsselwechsel:** Alte Blobs werden unlesbar, der Widerruf entfällt (Best Effort nach TN3194). Rotation ist ein eigener Schnitt, das Versionsbyte reserviert den Platz.
- **Klartext in Speicher und Logs:** Token, Schlüssel und Klartext erscheinen nie in Fehlertexten oder Ausgaben (AC-6, AC-13).
- **GCM-Grenze:** Zufälliger 96-Bit-IV ist bis etwa 2³² Verschlüsselungen je Schlüssel sicher (NIST SP 800-38D), weit über dem Bedarf (ein Token je Konto und Anmeldung).
- **LoC:** Tests ≈ 2,5-faches des Codes; Grenze 250 knapp, darum die Schätzung vor dem Bauen und die Regel „fragen statt kürzen“.

## Test Plan

### Automated Tests (TDD RED)

RED: Zuerst `apple-vault.test.ts`; `apple-vault.ts` fehlt, die Tests schlagen fehl.

- [ ] Test 1 (AC-1, AC-7, AC-8): GIVEN Schlüssel, Konto und Tokens (kurz, lang, Umlaute) WHEN verschlüsselt und entschlüsselt wird THEN Rundweg, Blobform, 1000 verschiedene IV, kein Klartext im Blob.
- [ ] Test 2 (AC-2, AC-3, AC-4, AC-5): GIVEN die Fallliste der Angriffe WHEN `decryptToken` aufgerufen wird THEN immer `null` und nie ein Wurf; der 29-Byte-Blob wird nur mit gültigem Tag angenommen.
- [ ] Test 3 (AC-6): GIVEN falsche Eingaben für `encryptToken` WHEN aufgerufen THEN Wurf, Fehlertext ohne Schlüssel, Token und Konto.
- [ ] Test 4 (AC-9, AC-10): GIVEN `freshPool` + `migrate` und ein Konto WHEN `storeRefreshToken` zweimal und mit unbekanntem Konto aufgerufen wird THEN eine Zeile mit Blob B und neuerem `created_at`, `false` ohne Zeile.
- [ ] Test 5 (AC-11, AC-12): GIVEN gespeicherter Blob WHEN `deleteAccount` läuft bzw. ein anderes Konto entschlüsselt THEN Original-Token bzw. `null`.
- [ ] Test 6 (AC-13): GIVEN `console.*` und `process.stdout/stderr` vorübergehend ersetzt WHEN alle Aufrufe laufen THEN keine Ausgabe.
- [ ] Test 7 (AC-14, AC-15): GIVEN der fertige Zweig WHEN `./server/scripts/test-local.sh`, `server.yml` und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` THEN grün, grün, genau die drei Dateien.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): `node:crypto` mit AES-256-GCM, Versionsbyte, Konto als AAD, `null` statt Ausnahme beim Entschlüsseln.** Klein (≈ 55 Zeilen), jede Zeile testbar, keine neue Abhängigkeit, setzt die S2a-Festlegung um.
- **B: Schlüsselkennung im Blob (Version `0x02` + `keyId`) für Rotation.** Würde das in S2a festgelegte Blobformat und den einen `tokenKey` überholen; erst sinnvoll, wenn wirklich rotiert wird. Das Versionsbyte erlaubt den Wechsel später ohne Migration.
- **C: HKDF-abgeleiteter Schlüssel je Zweck.** Heute gibt es nur einen Zweck; Aufwand ohne Nutzen.
- **D: Nicht verschlüsseln.** Kippt die S2a-Festlegung; ein Datenbankabzug gäbe widerrufsfähige Apple-Token preis.
- **E: `pgcrypto` in der Datenbank.** Schon in S2a abgelehnt: Der Schlüssel würde als SQL-Parameter in Logs landen.
- **F: Token nicht speichern.** Dann wäre der Widerruf beim Löschen nicht möglich, was Richtlinie 5.1.1 und TN3194 verlangen.
- Befunde gegen den Plan: keine. Bekannte Schwäche: Schlüsselwechsel macht alte Blobs unlesbar; wird in der S2c-Spec genannt.

## Nicht in diesem Schnitt / Folgeschnitte

- S2c: `clientSecret` (ES256 aus der `.p8`), `redeemCode`, `revokeToken` (Fehler melden, nie das Löschen verhindern).
- S3 HTTP-Rand: Routen, `createJwks` einmal beim Start, Konfiguration. S4 App (nach #625).
- Schlüsselrotation des Tresors.

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: `./server/scripts/test-local.sh` (typecheck + `node --test` gegen das Wegwerf-Postgres) grün und der CI-Job `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-15 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `src/apple-vault.ts`
- [ ] #615 kommentiert (Stand Schnitt 2b-2, Folge S2c), Board-Karte aktuell

## Changelog

- 2026-11-03: Initial spec created (Schnitt 2b-2)
