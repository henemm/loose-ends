# Context: feat-615-s2b2-apple-vault

## Request Summary
#615 Schnitt 2b-2 (Epic #612, Weg B, ADR-21): Der Dienst legt Apples Refresh-Token verschlüsselt in `apple_tokens` ab
(AES-256-GCM, Konto als AAD) und kann ihn wieder entschlüsseln, damit S2c beim Löschen des Kontos den Widerruf bei Apple
auslösen kann. Nichts ruft den Code auf (ADR-21); Einlösen des Codes und Widerruf sind S2c.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/apple-vault.ts` (neu) | `encryptToken`, `decryptToken`, `storeRefreshToken` |
| `server/test/apple-vault.test.ts` (neu) | Angriffsfälle (Manipulation, falscher Schlüssel, falsches Konto, Version, Länge) und Upsert gegen Wegwerf-Postgres |
| `server/src/apple.ts` | `AppleConfig.tokenKey` (32 Byte aus `APPLE_TOKEN_KEY`, Form schon in S2a geprüft) — Quelle des Schlüssels; unverändert |
| `server/src/accounts.ts` | `deleteAccount` liest `refresh_token_enc` in derselben Transaktion VOR dem Löschen und gibt ihn als `appleToken` zurück; unverändert |
| `server/migrations/002_accounts.sql` | `apple_tokens (account_id text PK → accounts ON DELETE CASCADE, refresh_token_enc bytea NOT NULL, created_at)`; keine neue Migration nötig |
| `server/test/db.ts` | `freshPool(t)`: eigenes Schema je Test |
| `server/test/accounts.test.ts` | Muster: `migrated(t)`, Konto per `findOrCreate`, `deleteAccount` |
| `docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md` | Abschnitt „Festgelegt für S2b und S2c“: verbindliche Tresor-Vorgaben |
| `CLAUDE.md` | Abschnitt `server/`: Zeile für `src/apple-vault.ts` ergänzen |

## Existing Patterns
- **Nur `node:crypto`**, keine neuen Pakete (S2a, Entscheidung A).
- **Nie werfen bei fremden Eingaben, Werte statt Ausnahmen:** `decryptToken` gibt bei jedem Fehler `null` (Vorgabe aus S2a).
- **Stille:** kein `console`, keine Ausgabe (AC-17 S2a); Geheimnisse nie in Fehlertexten.
- **Ein SQL-Statement wo möglich** (`findOrCreate` als `INSERT … ON CONFLICT … DO UPDATE`): Upsert analog.
- **Tests:** `node:test` + `node:assert/strict`, tabellengetrieben, DB-Tests über `freshPool` + `migrate`.
- **Funktionen ≤ 50 Zeilen**, Kommentare knapp auf Englisch.

## Dependencies
- Upstream: `createCipheriv`/`createDecipheriv` (`aes-256-gcm`), `randomBytes(12)`, `AppleConfig.tokenKey`, `pg.Pool`, Tabelle `apple_tokens`.
- Downstream: S2c (Code einlösen → `encryptToken` + `storeRefreshToken`; Konto löschen → `deleteAccount().appleToken` → `decryptToken` → Widerruf), S3 (HTTP-Rand).

## Existing Specs
- `docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md`, Festlegung S2b Tresor: Blob `[0x01 | iv 12 | tag 16 | ciphertext]`,
  AES-256-GCM, `iv = randomBytes(12)`, `account_id` als AAD; `decryptToken` → `null` bei Manipulation, falschem Schlüssel, falschem
  Konto, falscher Version oder zu kurzem Blob; `storeRefreshToken(pool, accountId, blob)` als Upsert; Test gegen Wegwerf-Postgres;
  der von `deleteAccount` zurückgegebene Blob muss entschlüsselbar sein.
- Abgelehnt dort: `pgcrypto` (Schlüssel als SQL-Parameter in Logs), Token nicht speichern (kein Widerruf möglich).
- `docs/specs/feat-615-schnitt-1-konten-sitzungen.md`: Konten, `deleteAccount`.

## Recherche (2026-11-03)
- Node: Ohne `authTagLength` in `createDecipheriv` akzeptiert `setAuthTag` auch gekürzte Tags (bis 4 Byte); seit DEP0182 als veraltet
  markiert. Also `authTagLength: 16` beim Entschlüsseln fest setzen und die Bloblänge vorher prüfen.
  Quellen: https://github.com/nodejs/node/commit/03e05b092c, https://github.com/simstudioai/sim/pull/3881, https://github.com/nodejs/node/issues/40272
- Apple TN3194 / Richtlinie 5.1.1: Beim Löschen des Kontos ist der Refresh-Token über `/auth/revoke` zu widerrufen; Apple sagt nichts zur
  Verschlüsselung im Ruhezustand — das ist unsere Entscheidung. Quellen: https://developer.apple.com/forums/thread/730914,
  https://actingweb.readthedocs.io/en/latest/docs/guides/apple-sign-in.html
- GCM mit zufälligem 96-Bit-IV: sicher bis etwa 2³² Verschlüsselungen je Schlüssel (NIST SP 800-38D) — weit über dem Bedarf (ein Token je Konto und Anmeldung).

## Risks & Considerations
- **Gekürzter Tag** (s. o.): ohne feste Länge Fälschung möglich → Längenprüfung + `authTagLength: 16`.
- **Kontobindung:** AAD = `account_id` verhindert, dass ein Blob in die Zeile eines anderen Kontos kopiert und dort entschlüsselt wird.
- **Schlüsselwechsel:** Das Versionsbyte `0x01` reserviert Platz; ein Wechsel von `APPLE_TOKEN_KEY` macht alte Blobs heute unlesbar
  (→ `null`, Widerruf entfällt, Best Effort nach TN3194). Rotation selbst ist nicht Teil dieses Schnitts (Alternative in der Analyse).
- **Klartext im Speicher/Logs:** Token nie loggen, nie in Fehlertexte.
- **Upsert-Semantik:** Neue Anmeldung überschreibt den alten Blob (ein Token je Konto); `created_at` beim Überschreiben aktualisieren oder nicht — in der Analyse festlegen.
- **Korrektur aus dem Intake:** `deleteAccount` liest den Blob bereits vor dem Löschen in derselben Transaktion; das Kaskadenlöschen ist kein Problem.
- **LoC:** Code ≈ 50–70, Tests ≈ 2,5× → Grenze 250 knapp; Schätzung in der Spec vor dem Bauen nennen.

## Analysis

### Type
Feature (Dienstcode ohne Aufrufer, ADR-21).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple-vault.ts` | CREATE | `encryptToken`, `decryptToken`, `storeRefreshToken` (≈ 55 LoC) |
| `server/test/apple-vault.test.ts` | CREATE | Tabellengetriebene Angriffsfälle, IV-Eindeutigkeit, Upsert, Rundweg über `deleteAccount` (≈ 130–150 LoC) |
| `CLAUDE.md` | MODIFY | Eine Zeile im Abschnitt `server/` für `src/apple-vault.ts` |

Unverändert: `apple.ts`, `accounts.ts`, `002_accounts.sql` (keine Migration).

### Scope Assessment
- Files: 3
- Estimated LoC: +190…210 / -0 (unter 250; Tests nicht kürzen — wird es knapp, vor dem Bauen fragen)
- Risk Level: LOW (isoliertes Modul, kein Aufrufer, keine Migration, kein Pfad der Geräteliste)

### Technical Approach (festgelegt)
- `encryptToken(key: Buffer, accountId: string, token: string): Buffer` — Blob `[0x01 | iv 12 | tag 16 | ciphertext]`,
  AES-256-GCM, `iv = randomBytes(12)`, AAD = `Buffer.from(accountId)`. **Wirft** bei eigener Fehleingabe (Schlüssel ≠ 32 Byte,
  leerer Token, leere `accountId`), Fehlertext ohne Werte — ein `null` würde S2c ohne Token weitermachen lassen.
- `decryptToken(key: Buffer, accountId: string, blob: unknown): string | null` — **nie werfen**: Nicht-Buffer (String,
  Uint8Array, `null`, `undefined`), Schlüssel ≠ 32 Byte, Blob < 29 Byte, Version ≠ 0x01 → `null` vor dem Entschlüsseln;
  `createDecipheriv(..., { authTagLength: 16 })` fest (DEP0182, gekürzter Tag); `setAuthAAD`, `setAuthTag`, `final` in
  `try/catch` → `null`. Genau 29 Byte (leerer Ciphertext) ist formal zulässig; das Tag authentifiziert auch das.
- `storeRefreshToken(pool, accountId, blob): Promise<boolean>` — ein Statement:
  `INSERT … ON CONFLICT (account_id) DO UPDATE SET refresh_token_enc = EXCLUDED.refresh_token_enc, created_at = now()`.
  `created_at` = Alter des gespeicherten Tokens, darum beim Überschreiben `now()`. Unbekanntes Konto: FK-Verletzung
  `23503` abfangen → `false` (keine Vorabfrage, kein Race); andere Fehler werfen weiter; Erfolg `true`.
- Stille: kein `console`, Geheimnisse nie in Fehlertexten.

### Test Plan (Kern)
- `null`-Tabelle: Version 0x00/0x02/0xFF; je ein Byte in IV, Tag, Ciphertext gekippt; Tag auf 15 Byte gekürzt; 28 Byte;
  leerer Buffer; falscher Schlüssel; falsches Konto; Nicht-Buffer; Schlüssel 31/33 Byte.
- Positiv: Rundweg mit Umlauten und langem Token; erstes Byte 0x01; Länge 29 + Klartextlänge (Bytes).
- `encryptToken` wirft bei Schlüssel ≠ 32, leerem Token, leerer `accountId`; Fehlertext enthält weder Schlüssel noch Token.
- 1000 Verschlüsselungen desselben Klartexts → 1000 verschiedene IVs.
- DB (`freshPool` + `migrate`): zweiter Aufruf überschreibt (eine Zeile, `created_at` rückt vor); unbekanntes Konto → `false`,
  keine Zeile; store → `deleteAccount` → `appleToken` entschlüsselt sich zum Original.

### Dependencies
- Upstream: `node:crypto`, `AppleConfig.tokenKey` (S2a), `pg.Pool`, `apple_tokens`, `deleteAccount` (S1).
- Downstream: S2c (`redeemCode` → `encryptToken` + `storeRefreshToken`; Löschen → `decryptToken` → `revokeToken`), S3.

### Alternativen (nicht gewählt)
- **A: Schlüsselkennung im Blob** (Version 0x02 + keyId) für Rotation — würde das S2a-Blobformat und den einen `tokenKey`
  überholen; erst sinnvoll, wenn wirklich rotiert wird. Das Versionsbyte erlaubt den Wechsel später ohne Migration.
- **B: HKDF-abgeleiteter Schlüssel je Zweck** — heute nur ein Zweck, Aufwand ohne Nutzen.
- **C: Nicht verschlüsseln** — kippt die S2a-Festlegung; ein DB-Abzug gäbe widerrufsfähige Apple-Token preis.
- **D: `pgcrypto`** — schon in S2a abgelehnt (Schlüssel als SQL-Parameter in Logs).
- Befunde gegen den Plan: keine (Spec eindeutig, AAD schließt Blob-Vertauschung aus). Bekannte Schwäche: Schlüsselwechsel
  macht alte Blobs unlesbar → Widerruf entfällt (Best Effort, TN3194); in der S2c-Spec nennen.

### Open Questions
- keine (keine Produktfrage; alles Technische oben entschieden)
