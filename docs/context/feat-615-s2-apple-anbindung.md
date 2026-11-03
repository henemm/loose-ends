# Context: feat-615-s2-apple-anbindung

## Request Summary
#615 Schnitt 2 (Epic #612, Weg B / ADR-21): Der Dienst spricht mit Apple. Er prüft das Identity-Token aus „Mit Apple anmelden“,
löst den Authorization-Code bei Apple ein, speichert den Refresh-Token verschlüsselt und widerruft ihn beim Konto-Löschen.
Ohne HTTP-Rand (S3) und ohne App (S4); offline testbar, nichts ruft es auf.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/accounts.ts` | S1: `findOrCreate(appleSub)`, `createSession`, `deleteAccount` → gibt `appleToken: Buffer | null` (die verschlüsselten Bytes) für den Widerruf zurück. S2 liefert den `sub` und füllt `apple_tokens`. |
| `server/migrations/002_accounts.sql` | `apple_tokens(account_id PK FK CASCADE, refresh_token_enc bytea NOT NULL, created_at)`; Kommentar „encrypting and redeeming come in S2“. Kein Schema-Umbau nötig, ggf. Upsert-Funktion zum Schreiben. |
| `server/src/main.ts` | Einstellungen aus der Umgebung (`DATABASE_URL`, `PORT`, `HOST`); Logzeilen ohne Inhalte/Fehlertexte. S2 hängt nichts ein (S3 tut das), aber Konfiguration (Team-ID, Key-ID, Client-ID, .p8, Verschlüsselungsschlüssel) folgt diesem Muster. |
| `server/test/accounts.test.ts`, `server/test/db.ts` | Testmuster: `node --test`, Wegwerf-Postgres über `server/scripts/test-local.sh`; AC-12-Muster „nichts nach console/stdout, Fehlertext ohne Geheimnis“. |
| `server/package.json` | Abhängigkeiten `pg`, `zod`, MCP-SDK; keine JWT-Bibliothek. Neue Abhängigkeit (`jose`) bräuchte Hennings Freigabe. |
| `docs/specs/feat-615-schnitt-1-konten-sitzungen.md` | Schnittplan: S2 = `server/src/apple.ts`, AES-256-GCM für den Refresh-Token; Merkposten aus dem Ticketkommentar: AC-3-Klartextprüfung gegen `token_hash` schärfen. |
| `docs/context/feat-615-konto-anmeldung.md` | Recherche vom 2026-11-02 (TN3194, JWKS, client_secret ES256, `sub` je primärer App-ID). |
| `docs/project/00-entscheidungen.md` ADR-21 | Make or Buy: kein eigener OAuth-Server; App-Sitzung ist kein OAuth. |
| `.github/workflows/server.yml` | CI für den Dienst (Linux, postgres:18). |

## Existing Patterns
- Reine Funktionen über `pg.Pool`, ein Statement je Vorgang; Abhängigkeiten werden als Parameter hereingereicht (z. B. `now` in `start`), damit Tests sie ersetzen.
- Keine Ausgabe von Geheimnissen: Logs nur Ereignisnamen; Fehlertexte ohne Token, `sub` oder Datenbanktext.
- Node 26 führt TypeScript direkt aus (Type Stripping) — keine `enum`/`namespace`/Parameter-Properties.
- Tests ohne Netz: alles, was nach außen spricht, bekommt ein injiziertes `fetch`.

## Dependencies
- Upstream: Apple `https://appleid.apple.com/auth/keys` (JWKS, RS256), `/auth/token` (Code einlösen, `client_secret` = ES256-JWT aus .p8, Team-ID, Key-ID, Client-ID), `/auth/revoke`. Node `crypto` (`createPublicKey({format:'jwk'})`, `verify` RS256, `sign` ES256 mit `dsaEncoding:'ieee-p1363'`, AES-256-GCM).
- Downstream: S3 (HTTP-Rand: `POST /auth/apple` ruft Prüfen + Einlösen + `findOrCreate` + Token speichern + `createSession`; `DELETE /account` ruft `deleteAccount` + Widerruf), #621 (Connector, gleiches `sub` über Services-ID).

## Existing Specs
- `docs/specs/feat-615-schnitt-1-konten-sitzungen.md` — Konten, Sitzungen, Löschen.

## Risks & Considerations
- **Sicherheitskritisch:** falsche `aud`/`iss`/`exp`/Signatur-Prüfung oder `alg`-Verwechslung („none“, HS256 mit öffentlichem Schlüssel) öffnet fremde Konten. Nur RS256 akzeptieren, `kid` muss im JWKS stehen.
- `nonce`: Apple setzt den Nonce-Wert ins Token, den die App mitgeschickt hat (App sendet SHA-256 des Rohwerts); Prüfung gegen Wiederverwendung — Form klären in der Analyse.
- JWKS-Rotation: Schlüssel cachen, bei unbekanntem `kid` einmal neu laden.
- Zeitabhängigkeit (`exp`, `iat`, `client_secret`-Laufzeit ≤ 6 Monate) → `now` injizieren.
- Verschlüsselungsschlüssel und .p8 aus der Umgebung; Fehlen darf erst beim Gebrauch scheitern? Oder beim Start? — Analyse.
- Widerruf darf das Löschen nie verhindern (TN3194): Fehler beim Widerruf wird gemeldet, nicht geworfen.
- Echter Apple-Aufruf ist offline nicht belegbar; Belege über Testschlüssel und nachgebaute Apple-Antworten, echter Lauf erst mit S3/S4.
- Scoping: `apple.ts` + Tests + evtl. Speicherfunktion in `accounts.ts` → Limits 250 LoC prüfen; Tests ≈1,5× Code (Memory #613).

## Analysis

### Type
Feature (Dienst-Bausteine, kein sichtbarer App-Teil)

### Recherche (2026-11-03)
- Apple „Verifying a user“ (developer.apple.com/documentation/signinwithapple/verifying-a-user): Signatur, `nonce`,
  `iss` = `https://appleid.apple.com`, `aud` = client_id, jetzt < `exp`. Die Doku schreibt „JWS E256“.
- Live-JWKS `https://appleid.apple.com/auth/keys` (abgerufen 2026-11-03): drei Schlüssel, alle `kty` RSA, `alg` RS256
  (kids GNCf4J83Oh, nP41CGTvOz, 8nTlO3M2Bk) → Doku ungenau; geprüft wird strikt RS256, jedes andere `alg` in Token oder
  JWK wird abgelehnt (fail-closed: ein künftiger Wechsel fällt auf, statt still durchzulaufen).
- TN3194 (Revision 2025-10-03): Token prüfen, Code über `/auth/token` einlösen, Antwort sicher speichern; `/auth/revoke`
  ist der einzige Weg zum Widerruf und braucht Refresh- oder Access-Token; ohne Token muss das Löschen trotzdem erfolgen.
- Authorization-Code: einmalig, ~5 min gültig → der Refresh-Token MUSS gespeichert werden; Neu-Einlösen beim Löschen
  ist unmöglich, ein Access-Token lebt nur ~1 h.

### Schnitt-Entscheidung
Geschätzt ~280 LoC Code + ~420 LoC Tests → reißt das 250-LoC-Limit. Aufteilung:
- **S2a (dieser Workflow): Prüfen und Verschlüsseln.** Konfiguration laden, JWKS-Cache, `verifyIdentityToken`,
  AES-256-GCM-Tresor mit Upsert in `apple_tokens`. Netz nur für den JWKS-Abruf (injiziertes `fetch`).
- **S2b (eigener Workflow danach): Einlösen und Widerruf.** `clientSecret` (ES256 aus .p8), `redeemCode`, `revokeToken`.
  Nutzt Konfiguration und `decryptToken` aus S2a.

**Nachschnitt in Phase 3 (2026-11-03):** Das 250-LoC-Limit zählt Code + Tests + Doku (S1: ≈ +240 gesamt). S2a mit
Tresor und JWKS-Cache kam auf ≈ 431. Neue Aufteilung:
- **S2a (dieser Workflow):** `loadAppleConfig` + `verifyIdentityToken` mit hereingereichter Schlüsselsuche
  (`kid → JWK | unknown_kid | keys_unavailable`). Spec: `docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md`.
- **S2b:** `createJwks` (Cache, Neuladegrenze, Timeout, stale-if-error) + Tresor (`apple-vault.ts`, AES-256-GCM, AAD, Upsert).
- **S2c:** `clientSecret`, `redeemCode`, `revokeToken`.
Die Tabelle unten ist der Stand vor dem Nachschnitt; für S2a gelten nur `apple.ts`, `apple.test.ts`, `CLAUDE.md`.

### Affected Files (S2a, vor dem Nachschnitt)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple.ts` | CREATE | `loadAppleConfig`, `createJwks`, `verifyIdentityToken` (aufgeteilt in Parsen / Schlüssel / Claims, je ≤ 50 LoC) |
| `server/src/apple-vault.ts` | CREATE | `encryptToken`, `decryptToken`, `storeRefreshToken` (Upsert) |
| `server/test/apple.test.ts` | CREATE | eigenes RSA-Testpaar, nachgebautes JWKS, injiziertes `fetch`/`now`, Angriffsfälle |
| `server/test/apple-vault.test.ts` | CREATE | Rundlauf, Manipulation, falsches Konto (AAD), Upsert gegen Wegwerf-Postgres |
| `CLAUDE.md` | MODIFY | eine Zeile im Abschnitt `server/` |

`accounts.ts`, Migrationen, `main.ts`, `package.json` und CI bleiben unverändert (`apple_tokens` passt, keine Migration).

### Scope Assessment
- Files: 4 (+ eine CLAUDE.md-Zeile)
- Estimated LoC: Code ~170, Tests ~260
- Risk Level: MEDIUM — sicherheitskritische Prüfung, aber nirgends eingehängt (S3 hängt ein)

### Technical Approach
- **Nur `node:crypto`**, keine neue Abhängigkeit (`jose` = Alternative, s. u.).
- **Konfiguration:** `loadAppleConfig(env = process.env)` wirft bei fehlendem oder ungültigem Wert, geprüft beim Aufruf
  (S3 ruft beim Start). Umgebungsnamen: Team-ID, Key-ID, Client-IDs (kommagetrennte Liste; heute nur die Bundle-ID,
  #621 bringt die Services-ID), die .p8 als PEM (`\n`-Escapes toleriert, muss EC P-256 sein) und der 32-Byte-Tresorschlüssel
  (base64). Genaue Namen legt die Spec fest. Fehlertext nennt nur den Variablennamen, nie den Wert.
- **Prüfen:** genau drei base64url-Segmente, Header/Payload JSON-Objekte; `header.alg === "RS256"` sonst `alg` (vor jeder
  Schlüsselsuche; `none`/`HS256`/`ES256` abgelehnt); JWK muss `kty` RSA und (falls gesetzt) `alg` RS256 haben;
  `createPublicKey({format:"jwk"})` + `crypto.verify("sha256")`; dann `iss` exakt, `aud` exakt in der Client-ID-Liste (kein
  Teilstring), `exp > now − 60 s`, `iat ≤ now + 60 s`, `sub` nicht leer; `nonce`: Dienst bekommt den Rohnonce, vergleicht
  SHA-256-hex per `timingSafeEqual`, fehlender Claim = Ablehnung.
- **Rückgabe:** Union `{ok:true, sub} | {ok:false, reason}` mit festen Gründen (`malformed|alg|unknown_kid|signature|iss|
  aud|expired|iat|nonce|keys_unavailable`); nie Token-, `sub`- oder Apple-Text im Grund. Nur `loadAppleConfig` wirft.
- **JWKS-Cache:** TTL 1 h; unbekannter `kid` → einmal neu laden, höchstens alle 60 s (sonst lösen Zufalls-kids je Anfrage
  einen Apple-Abruf aus); `AbortSignal.timeout(5000)`; misslungener Abruf behält den alten Cache; `keys_unavailable`
  (→ später 503) getrennt von `unknown_kid` (→ später 401).
- **Tresor:** Blob `[0x01 Version | iv 12 | tag 16 | ciphertext]`, AES-256-GCM, `iv = randomBytes(12)`, `account_id` als
  AAD (ein Blob lässt sich nicht auf ein anderes Konto umkopieren); das Versionsbyte bereitet eine Schlüsselrotation vor.
  `decryptToken` gibt bei Manipulation, falschem Schlüssel oder falschem Konto `null` zurück statt zu werfen.
  `storeRefreshToken(pool, accountId, blob)`: `INSERT … ON CONFLICT (account_id) DO UPDATE`.
- **Stille:** kein `console.*`, stdout oder stderr; der Test greift alle ab (Muster AC-12 aus S1).

### Alternativen (geprüft, nicht gewählt)
- **`jose`** statt `node:crypto`: ~60 LoC weniger, JWKS-Cache und alg-Bindung eingebaut. Dagegen: neue Abhängigkeit
  (Freigabe nötig) auf dem sicherheitskritischen Pfad; gebraucht werden nur RS256-Prüfung und (S2b) ES256-Signatur
  (~40 Zeilen). Kippt keine ADR.
- **`pgcrypto`** (Verschlüsselung in Postgres): Schlüssel läge als SQL-Parameter vor (Logs, `pg_stat_statements`),
  verschlüsselt würde in der Instanz, die geschützt werden soll. Abgelehnt.
- **Refresh-Token nicht speichern:** unmöglich (Code einmalig, ~5 min), siehe Recherche.
- **Für S3 festzuhalten:** `/auth/token` liefert selbst ein `id_token`; S3 kann `sub` aus der Einlösung nehmen und mit
  derselben `verifyIdentityToken` prüfen; dann ist der einmalige Code der eigentliche Replay-Schutz. Ein Rohnonce ohne
  vom Dienst ausgegebenen Nonce bindet nur Token und Anfrage, er verhindert keinen Replay.

### Dependencies
- Upstream: Apple JWKS (S2a), `/auth/token` + `/auth/revoke` (S2b). `node:crypto`, `pg`.
- Downstream: S2b (Konfiguration, `decryptToken`), S3 (HTTP-Rand), #621 (zweite Client-ID in der Liste).

### Risiken
- alg-Verwechslung, `aud` als Teilstring, kid-Treffer auf Schlüssel mit anderem alg → je ein Angriffstest.
- Uhrabweichung → `now` injiziert, 60 s Spielraum.
- Echtes Apple-Verhalten offline nicht belegbar; S2a belegt mit eigenem RSA-Paar und nachgebautem JWKS.
- Betriebsrisiko (für S2b/S3): `deleteAccount` löscht die Zeile vor dem Widerruf; fällt der Widerruf aus, ist der Token
  weg — nach TN3194 als Best Effort zulässig, in der S2b-Spec nennen.
- Merkposten S1 (AC-3-Klartextprüfung schärfen) gehört nicht in S2.

### Open Questions
- Keine PO-Fragen: alles Technische ist entschieden, keine neue Abhängigkeit, kein sichtbarer App-Teil.
