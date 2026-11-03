# Context: feat-615-s2c-apple-einloesen

## Request Summary
#615 Schnitt 2c (Epic #612, Weg B, ADR-21): Der Dienst löst den einmaligen Autorisierungscode der App bei Apple ein
(`/auth/token`), erhält dafür den Refresh-Token (der in S2b-2 verschlüsselt abgelegt wird) und widerruft ihn beim Löschen des
Kontos (`/auth/revoke`). Beides braucht ein selbst signiertes `client_secret` (ES256 aus der `.p8`). Nichts ruft den Code auf
(ADR-21); den HTTP-Rand baut S3.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/apple-client.ts` (neu, Name in der Analyse festlegen) | `clientSecret`, `redeemCode`, `revokeToken` |
| `server/test/apple-client.test.ts` (neu) | Signatur-Prüfung des Secrets, Formulardaten, Antwortformen, Fehlerfälle, Zeitlimit |
| `server/src/apple.ts` | `AppleConfig` (`teamId`, `keyId`, `clientIds`, `privateKey` als EC-P-256-`KeyObject`, `tokenKey`); `verifyIdentityToken` liefert `sub`, aber nicht `aud` |
| `server/src/apple-jwks.ts` | Muster für Netz: `fetch` und `now` werden hereingereicht, `AbortSignal.timeout(5000)`, nie werfen bei fremder Antwort |
| `server/src/apple-vault.ts` | `encryptToken`/`storeRefreshToken` (nach dem Einlösen), `decryptToken` (vor dem Widerruf) |
| `server/src/accounts.ts` | `deleteAccount` gibt `appleToken` (Blob) zurück, nachdem die Zeile schon gelöscht ist |
| `server/migrations/002_accounts.sql` | `apple_tokens` hat keine Spalte für die `client_id` (siehe Risiken) |
| `server/test/apple-jwks.test.ts` | Muster für einen Stub-`fetch` mit Aufrufzähler und austauschbarer Antwort |
| `CLAUDE.md` | Abschnitt `server/`: Zeile für die neue Datei ergänzen |

## Existing Patterns
- **Nur `node:crypto`**, keine neuen Pakete (S2a, Entscheidung A: `jose` abgelehnt, ES256-Signatur ≈ 40 Zeilen selbst).
- **Netz hereinreichen:** `fetch` und Uhr als Optionen (`createJwks`), Zeitlimit per `AbortSignal.timeout`.
- **Werte statt Ausnahmen bei fremden Eingaben:** `Verdict`-artige Ergebnisse (`{ ok: true, … } | { ok: false, reason }`);
  werfen nur bei eigener Fehlbedienung. Fehlertexte nennen nie Geheimnisse (Secret, Code, Token).
- **Stille:** kein `console`.
- **Tests:** `node:test` + `node:assert/strict`, tabellengetrieben; die Signatur wird mit dem passenden öffentlichen Schlüssel geprüft.
- Funktionen ≤ 50 Zeilen, Kommentare knapp auf Englisch.

## Dependencies
- Upstream: `node:crypto.sign` (ES256 mit `dsaEncoding: "ieee-p1363"`), `AppleConfig`, globales `fetch` (Formular
  `application/x-www-form-urlencoded`), `apple-vault.ts`.
- Downstream: S3 (`POST /auth/apple`: Identity-Token prüfen → Code einlösen → Konto finden/anlegen → Token verschlüsseln und ablegen
  → Sitzung; `DELETE /account`: `deleteAccount` → `decryptToken` → `revokeToken`), #621 (zweite Client-ID für den Claude-Connector).

## Existing Specs
- `docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md`, „Festgelegt für S2b und S2c“: `clientSecret` (ES256 aus der .p8),
  `redeemCode`, `revokeToken` (Fehler melden, nie das Löschen verhindern). Betriebsrisiko: `deleteAccount` löscht vor dem Widerruf.
- `docs/specs/feat-615-schnitt-2b2-apple-tresor.md`: Schlüsselwechsel macht alte Blobs unlesbar → Widerruf entfällt; in dieser Spec zu nennen.
- `docs/specs/feat-615-schnitt-2b1-jwks-cache.md`, `docs/specs/feat-615-schnitt-1-konten-sitzungen.md`.

## Recherche (2026-11-03)
- **Einlösen:** `POST https://appleid.apple.com/auth/token`, Formular `client_id`, `client_secret`, `code`,
  `grant_type=authorization_code`, `redirect_uri` nur, wenn die Anmeldung einen hatte (die native App hat keinen). Code gilt einmal
  und fünf Minuten. Antwort 200: `access_token`, `token_type` (`bearer`), `expires_in`, `refresh_token`, `id_token`.
  Fehler 400 als `{ "error": … }` mit genau einem Wert aus `invalid_request`, `invalid_client`, `invalid_grant`,
  `unauthorized_client`, `unsupported_grant_type`, `invalid_scope`.
  Quelle: https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens,
  https://developer.apple.com/documentation/signinwithapplerestapi/errorresponse
- **Widerruf:** `POST https://appleid.apple.com/auth/revoke`, Formular `client_id`, `client_secret`, `token`,
  `token_type_hint=refresh_token`. 200 ohne Inhalt, auch wenn der Token schon ungültig war. Die `client_id` **muss dieselbe sein wie bei
  der Anmeldung**. Quelle: https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens
- **Client-Secret:** Kopf `alg: ES256`, `kid` (Key-ID); Nutzlast `iss` (Team-ID), `iat`, `exp` (höchstens 15 777 000 s = sechs Monate),
  `aud: https://appleid.apple.com`, `sub` = die `client_id` des Aufrufs (Groß-/Kleinschreibung zählt). ECDSA P-256 mit SHA-256.
  Quelle: https://developer.apple.com/documentation/accountorganizationaldatasharing/creating-a-client-secret
- **Node:** `crypto.sign` liefert ECDSA standardmäßig DER; JWS verlangt `r‖s` (64 Byte) → `dsaEncoding: "ieee-p1363"`.
  Quelle: https://dev.to/oskarmakarov/sign-in-with-apple-broke-with-invalidclient-after-6-months-heres-why-and-how-to-never-deal-2mhk
- **Fallberichte:** `invalid_grant` beim Einlösen eines Codes aus `ASAuthorizationAppleIDCredential`, wenn als `client_id` die
  Services-ID statt der Bundle-ID steht, oder wenn derselbe Code ein zweites Mal eingelöst wird; `invalid_client` nach sechs Monaten bei
  einem dauerhaft gespeicherten Secret. Quellen: https://developer.apple.com/forums/thread/118135,
  https://developer.apple.com/forums/thread/685250, https://developer.apple.com/forums/thread/690536

## Risks & Considerations
- **Welche `client_id`?** `AppleConfig.clientIds` ist eine Liste (App jetzt, Connector #621 später). Der Code der App gilt nur mit der
  Bundle-ID, und der Widerruf muss dieselbe `client_id` nehmen wie die Anmeldung. `apple_tokens` speichert sie nicht, und
  `verifyIdentityToken` gibt `aud` nicht zurück. In der Analyse entscheiden: `client_id` als Parameter hereinreichen und für den Widerruf
  mit ablegen (neue Spalte/Migration, oder im verschlüsselten Blob), oder bis #621 nur die erste Client-ID verwenden.
- **Code gehört zum selben Nutzer?** Das `id_token` aus der Einlöse-Antwort trägt `sub`. Ohne Vergleich mit dem `sub` des geprüften
  Identity-Tokens könnte ein fremder Code ein Konto mit einem fremden Refresh-Token belegen. Prüfen, ob `redeemCode` das `sub` aus dem
  `id_token` zurückgibt (die Antwort kommt per TLS direkt von Apple) und S3 vergleicht.
- **Secret-Lebensdauer:** je Aufruf neu signieren (kurz, z. B. 5 min) statt sechs Monate vorhalten; kein Ablaufproblem, keine Ablage.
- **Widerruf nach dem Löschen:** Fehler melden, nie werfen, nie das Löschen verhindern (Best Effort nach TN3194). Unlesbarer Blob
  (neuer `APPLE_TOKEN_KEY`) → kein Widerruf möglich; das meldet S3, nicht dieser Schnitt.
- **Zeitlimit:** Apple antwortet nicht → Abbruch nach festem Limit (wie JWKS 5 s), Ergebnis statt Ausnahme.
- **Geheimnisse in Fehlern:** Code, Secret, Refresh-Token nie in Rückgabegründen oder Fehlertexten; Apples `error`-Wert nur, wenn er einer
  der sechs bekannten ist.
- **LoC:** Code ≈ 80–100, Tests ≈ 2,5× (Memory „LoC-Überhang durch Sicherheitstests“) → über 250; Teilung in der Analyse prüfen
  (z. B. 2c-1 `clientSecret` + `redeemCode`, 2c-2 `revokeToken`).
- **Geräteliste:** nur `server/`, kein Pfad berührt.

## Analysis

### Type
Feature (Server-Baustein ohne Aufrufer, ADR-21; HTTP-Rand folgt in S3)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple-client.ts` | CREATE | `clientSecret(config, clientId, now)` (ES256, `ieee-p1363`, 5 min gültig), `redeemCode(code, clientId, opts)` → `{ ok: true, refreshToken, sub } \| { ok: false, reason }` |
| `server/test/apple-client.test.ts` | CREATE | Secret mit dem öffentlichen Schlüssel prüfen (Kopf, Nutzlast, 64-Byte-Signatur), Formularfelder, Antwortformen, Apple-Fehler, Zeitlimit, keine Geheimnisse in Gründen |
| `CLAUDE.md` | MODIFY | eine Zeile im Abschnitt `server/` |

Schnitt 2c-2 (eigener Workflow danach): `revokeToken(refreshToken, clientId, opts)` in derselben Datei + Tests.

### Scope Assessment
- Files: 3 (2c-1)
- Estimated LoC: Code ≈ +65, Tests ≈ +165, Doku +1 → ≈ 230 (2c-2: Code ≈ +20, Tests ≈ +60)
- Beide zusammen ≈ 310 → über 250, deshalb geteilt (Tests ≈ 2,5× Code, Memory „LoC-Überhang durch Sicherheitstests“)
- Risk Level: LOW — neue Datei, nichts ruft sie auf, kein Pfad der Geräteliste

### Technical Approach
1. **`client_id` als Parameter, kein Rückgriff auf `clientIds[0]`.** `redeemCode`/`revokeToken` nehmen die `client_id`
   entgegen und werfen bei einem Wert außerhalb von `config.clientIds` (eigene Fehlbedienung). Grund: Apple verlangt beim Einlösen die
   Bundle-ID (Fallbericht forums/thread/118135) und beim Widerruf dieselbe `client_id` wie bei der Anmeldung; mit #621 kommt eine zweite.
   Woher S3 sie nimmt und wo sie für den Widerruf liegt (`aud` aus `verifyIdentityToken` zurückgeben, Spalte `client_id` in
   `apple_tokens` per additiver Migration 003), entscheidet S3 — dort wird beides erst benutzt. Hier festgehalten, damit S3 es nicht vergisst.
2. **`sub` aus dem `id_token` der Antwort zurückgeben.** Die Antwort kommt per TLS direkt von Apple; nach OIDC Core 3.1.3.7 (6) darf
   TLS die Signaturprüfung ersetzen. Geprüft werden trotzdem billig `iss = https://appleid.apple.com` und `aud = clientId`; fehlt `sub`
   oder passt eins davon nicht → `malformed_response`. S3 vergleicht `sub` mit dem geprüften Identity-Token (sonst könnte ein fremder Code
   ein Konto mit fremdem Refresh-Token belegen).
3. **Secret je Aufruf neu**, `iat = now`, `exp = now + 300 s`; kein Vorhalten, kein Sechs-Monats-Ablauf (Fallbericht `invalid_client`).
4. **Netz wie `apple-jwks.ts`:** `fetch` und `now` hereingereicht, `AbortSignal.timeout(5000)`, Formular
   `application/x-www-form-urlencoded` (`client_id`, `client_secret`, `code`, `grant_type=authorization_code`, kein `redirect_uri`).
5. **Ergebnis statt Ausnahme:** Gründe `apple:<error>` nur für die sechs bekannten Apple-Werte, sonst `apple_status`; `unavailable` bei
   Netzfehler/Zeitlimit; `malformed_response` bei fehlendem `refresh_token`/`id_token` oder kaputtem JSON. Kein Grund enthält Code,
   Secret oder Token (Test mit Kennwörtern im Stub).

### Befunde gegen den Plan
- `apple_tokens` hat keine `client_id`-Spalte, `verifyIdentityToken` gibt `aud` nicht zurück → bewusst nach S3 verlegt (siehe 1), kein Blocker für 2c-1.
- `id_token` ohne Signaturprüfung: zulässig nach OIDC, aber nur, solange die URL fest auf `appleid.apple.com` (https) steht; ein
  überschreibbares `url` gibt es nur für Tests.

### Alternativen
| Weg | Was er bedeutet | Kippt |
|---|---|---|
| **A (Empfehlung):** Code einlösen, Refresh-Token verschlüsselt ablegen, beim Löschen widerrufen | wie in S2a festgelegt | nichts |
| B: Kein Refresh-Token speichern; beim Löschen schickt die App einen frischen Autorisierungscode, der Dienst löst ihn ein und widerruft sofort | kein Tresor, kein `APPLE_TOKEN_KEY`, kein Schlüsselwechsel-Problem | S2b-2 (Tresor) würde überflüssig; Löschen ginge nur aus der App mit frischer Apple-Anmeldung, nie vom Dienst allein (z. B. Löschung per Mail-Anfrage) |
| C: `client_id` im verschlüsselten Blob statt eigener Spalte | keine Migration | Blob-Format 0x01 aus S2b-2 (neue Version nötig) |
| D: nur `clientIds[0]` bis #621 | 2 Zeilen weniger | Widerruf für Connector-Konten wäre später falsch; Umbau in #621 |

### Dependencies
- Upstream: `node:crypto.sign` (`dsaEncoding: "ieee-p1363"`), `AppleConfig` aus `apple.ts` (unverändert), globales `fetch`.
- Downstream: 2c-2 `revokeToken`; S3 (`POST /auth/apple`, `DELETE /account`, `aud` + Spalte `client_id`); #621.

### Open Questions
- keine an den PO (rein technisch; Weg A war schon in S2a festgelegt)
