# Context: feat-621-s4c-web-token

## Request Summary
#621, Schnitt 4c (vor S6): das Apple-Refresh-Token, das der Rückweg der Browser-Anmeldung (`/oauth/apple/return`, Services ID
`APPLE_WEB_CLIENT_ID`) beim Einlösen bekommt, wird heute verworfen (`server/src/oauth-return.ts:90`). Ziel: Es ist so verwaltet,
dass beim Löschen des Kontos keine Berechtigung bei Apple liegen bleibt. Offen ist, ob speichern + beim Löschen widerrufen oder
sofort widerrufen (Entscheidung aus 4b-2a vertagt, Spec `feat-621-schnitt-4b2a-rueckweg.md` Alternative F, Risiko Z. 159).

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/oauth-return.ts` | `outcome()` löst den Code ein (`redeemCode` mit `webClientId`), verwirft `redeemed.refreshToken` (Z. 90), legt dann das Konto per `findOrCreate` an. Hier entsteht das Web-Token. |
| `server/src/apple-vault.ts` | `encryptToken`/`decryptToken` (AES-256-GCM, Konto als AAD), `storeRefreshToken(pool, accountId, blob, clientId)`: Upsert **je Konto** (`ON CONFLICT (account_id)`) — ein Web-Token würde das App-Token überschreiben. |
| `server/migrations/002_accounts.sql`, `003_apple_client_id.sql` | `apple_tokens`: PK `account_id`, `client_id` nullable (Zeile vor 003 = kein Widerruf möglich). Neue Migration wäre `005_*.sql`. |
| `server/src/accounts.ts` | `deleteAccount` liest **eine** Zeile `apple_tokens` (LEFT JOIN, `Deletion = { appleToken, clientId }`) und löscht per Kaskade. Bei mehreren Zeilen je Konto: JOIN liefert mehrere Zeilen, `rowCount !== 1` → heute „unbekanntes Konto“ (Fehlerquelle!). |
| `server/src/auth.ts` | `revokeAfterDelete`: widerruft nur, wenn `config.clientIds.includes(clientId)` — die Web-ID steht nie in `clientIds`, ein Web-Token würde also immer „skipped“. `revokeToken` selbst akzeptiert seit S4a die Web-ID. |
| `server/src/apple-client.ts` | `redeemCode` (gibt `refreshToken`, `sub`, `idToken`), `revokeToken(token, clientId, …)` (App-IDs und `webClientId`, sonst Wurf vor dem Netz). |
| `server/src/apple.ts` | `AppleConfig` mit `tokenKey`, `clientIds`, `webClientId`. |
| Tests: `apple-vault.test.ts`, `accounts.test.ts`, `auth.test.ts` (Löschen + Widerruf), `schema.test.ts` (Z. 190–219: Form von `apple_tokens`), `oauth-return.test.ts` (AC-14 aus 2a: „web-token wird nicht gespeichert und nicht widerrufen“ — wird gekippt) | |

## Existing Patterns
- Token nur verschlüsselt (`encryptToken`, Konto als AAD), Widerruf best effort nach dem Commit (`revokeAfterDelete`), feste Protokollereignisse `apple revoke skipped`/`apple revoke failed`.
- Migrationen nur additiv, nummeriert, je eine Transaktion; Schema-Tests in `schema.test.ts` belegen jede Migration.
- Feste Antworten ohne Werte, Log-Mitschnitt gegen feste Ereignisliste (`oauth-return.test.ts`, `oauth-interaction.test.ts`).

## Dependencies
- Upstream: `redeemCode`, `revokeToken`, `encryptToken`, `PgAdapter`, `findOrCreate`, `AppleConfig.tokenKey`.
- Downstream: `/auth/delete` (einziger Löschweg; Konto ist über `apple_sub` dasselbe für App und Browser), S5 Zustimmung, S6 Betrieb (Services ID im Apple-Konto).

## Existing Specs
- `docs/specs/feat-621-schnitt-4b2a-rueckweg.md` (Verzicht, Alternative F, Out of Scope „Web-Token-Ablage“)
- Specs von #615 S2b-2 (Vault), S3a (client_id, Migration 003), S3c-1 (Löschen + Widerruf)

## Recherche (2026-11-06)
- Apple „Revoke tokens“ (REST API, JSON der Doku-Seite): „The user session associated with the token provided is revoked if the request is successful.“ Antwort 200 auch für „previously invalid“. `client_id` = „The identifier (App ID or Services ID) for your app.“
- TN3107: `invalid_grant` u. a. wenn „the client_id does not match the client for which the refresh_token was issued“ → ein Web-Token muss mit der Services ID widerrufen werden, ein App-Token mit der Bundle-ID.
- Wirkung über Client-Grenzen (Services ID gruppiert unter der App-ID): **nicht dokumentiert**, Forum 844628 (genau diese Frage) ohne Antwort. Fremde Umsetzungen (z. B. aveer-dev/boxies PR #134) speichern je Client eine Zeile und widerrufen jede mit ihrer eigenen ID.
- Quellen: https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens, https://developer.apple.com/documentation/technotes/tn3107-resolving-sign-in-with-apple-response-errors, https://developer.apple.com/forums/thread/844628, https://github.com/aveer-dev/boxies/pull/134

## Wege (für /20-analyse)
1. **Sofort widerrufen, nichts speichern:** nach erfolgreicher Prüfung des id_token `revokeToken(refreshToken, webClientId)`, best effort. Keine Migration, kein Schlüssel, kein Löschpfad. Risiko: Wirkung auf die App-Berechtigung desselben Nutzers unbelegt (könnte die App bei Apple abmelden, falls Apple die Gruppe widerruft).
2. **Je Konto und client_id speichern, beim Löschen alle widerrufen:** Migration 005 (PK `(account_id, client_id)`, Zeilen ohne client_id behandeln), `storeRefreshToken` Upsert je Paar, `deleteAccount` liefert eine Liste, `revokeAfterDelete` widerruft jede mit ihrer ID (Web-ID zulassen). Größer (≈ 5 Dateien + Tests), aber ohne unbelegte Wirkung.
3. Status quo (weder speichern noch widerrufen): Berechtigung bleibt bei Apple liegen, auch nach Kontolöschung.

## Risks & Considerations
- `deleteAccount` mit mehreren Token-Zeilen: JOIN-Ergebnis ≠ 1 Zeile → heute fälschlich „nicht gelöscht“ (401). Muss mit Weg 2 umgebaut werden.
- Produktion: `APPLE_*` noch nicht im Compose-Stack → `apple_tokens` dort leer; Migration 005 trotzdem für Zeilen ohne `client_id` (vor 003) definiert halten.
- Fehler beim Speichern im Rückweg: darf nie zu einem Redirect ohne Ticket führen (feste 400 „store failed“) und nie das App-Token überschreiben.
- Konto gelöscht zwischen `findOrCreate` und Speichern (23503) → `storeRefreshToken` gibt `false`; Rückweg muss dann `access_denied` ergeben (wie `/auth/apple` 401).
- Werte nie im Protokoll (Token, Konto-ID; 23503-`detail` nennt die Konto-ID).
- Umfang: Weg 2 berührt Migration, `apple-vault.ts`, `accounts.ts`, `auth.ts`, `oauth-return.ts` + 4–5 Testdateien → über ±250 LoC wahrscheinlich; nach RED zählen und sofort fragen ([[feedback-loc-ueberhang-sicherheitstests]]).

## Analysis

### Type
Feature (Sicherheits-/Datenschutzlücke schließen, kein Fehlerbericht: der Verzicht war in 4b-2a bewusst vertagt).

### Befunde am Code (2026-11-06, gelesen)
- `oauth-return.ts:90` verwirft `redeemed.refreshToken`; `outcome()` hat nach `findOrCreate` die Konto-ID, also ist Speichern dort ohne Umbau möglich. Ein Wurf in `outcome()` endet schon heute in `finishReturn` als feste 400 `oauth return store failed`, nie als Redirect ohne Ticket.
- `apple-vault.ts:39–52` `storeRefreshToken`: `ON CONFLICT (account_id)` — würde das App-Token desselben Kontos überschreiben (App-Anmeldung und Browser-Anmeldung sind über `apple_sub` dasselbe Konto).
- `accounts.ts:47–66` `deleteAccount`: `LEFT JOIN apple_tokens … FOR UPDATE OF a`, dann `rowCount !== 1` → „nicht gelöscht“. Mit zwei Token-Zeilen liefert der JOIN 2 Zeilen → Löschen schlägt fehl (401) und das Konto bleibt bestehen. Muss getrennt werden: erst Konto sperren, dann Tokens als Liste lesen.
- `auth.ts:99–112` `revokeAfterDelete`: nur `config.clientIds.includes(clientId)` gilt als bekannt; die Web-ID muss zusätzlich zugelassen werden (`revokeToken` akzeptiert sie seit S4a).
- `auth.ts:69–71`: `/auth/apple` speichert mit `verdict.aud` — das Muster, dem der Rückweg mit `webClientId` folgt.
- Produktion: `apple_tokens` dort leer (`APPLE_*` nicht im Compose-Stack) — die Migration trifft keine echten Zeilen.

### Wege im Vergleich
| | Weg 1 sofort widerrufen | Weg 2 je Client speichern, beim Löschen alle widerrufen | Weg 3 Status quo |
|---|---|---|---|
| Berechtigung nach Kontolöschung bei Apple | weg (sofern 200 wirkt) | weg | bleibt liegen |
| Unbelegte Wirkung | ja: ob Widerruf des Web-Tokens auch die App-Anmeldung bei Apple trifft, ist nicht dokumentiert (Forum 844628 offen) | keine: jedes Token mit seiner eigenen ID, wie Apple TN3107 verlangt | — |
| Vorab prüfbar? | erst mit echter Services ID (S6) und echtem Konto | ja, vollständig mit Testdatenbank und Fake-Apple | — |
| Migration | keine | 005 | keine |
| Dateien (Quelle + Test) | 1 + 1 | 5 + 5 | 0 |
| LoC (Code / mit Tests ≈ 2,5×) | ≈ 10 / ≈ 40 | ≈ 60 / ≈ 210 | 0 |
| Gekippt würde | Spec 4b-2a Alternative F (Verzicht) | Spec 4b-2a Alternative F, #615 S2b-2 „ein Token je Konto“ | — |

Befunde gegen Weg 2: mehr Dateien als das Limit von 4–5, wenn Tests mitzählen; Lösung: Schnitt teilen (unten). Gegen Weg 1: eine unbelegte Wirkung, die im schlimmsten Fall Nutzer in der App bei Apple abmeldet — und das wäre erst nach S6 mit echtem Konto messbar. Weg 3 verstößt gegen das Ziel des Schnitts.

### Empfehlung
**Weg 2**, in zwei Teilschnitten, damit jeder in die Limits passt:
- **4c-1 Ablage je Client (ohne Produktwirkung):** Migration `005_apple_tokens_per_client.sql` — Zeilen ohne `client_id` löschen (nicht widerrufbar, Prod leer), `client_id` NOT NULL, PK von `(account_id)` auf `(account_id, client_id)`. `storeRefreshToken` Upsert `ON CONFLICT (account_id, client_id)`. `deleteAccount` sperrt das Konto, liest dann alle Tokens als Liste (`Deletion.tokens: { blob, clientId }[]`). `revokeAfterDelete` widerruft jede Zeile mit ihrer ID; bekannt = `clientIds` oder `webClientId`; Protokoll je Zeile weiter nur `apple revoke skipped`/`apple revoke failed`.
- **4c-2 Rückweg speichert:** `outcome()` verschlüsselt das Web-Token mit `tokenKey` und speichert es mit `webClientId` nach `findOrCreate`; `false` (23503, Konto zwischendurch gelöscht) → `access_denied`; Datenbankfehler → wie heute feste 400. AC-14 aus 2a („nicht gespeichert, nicht widerrufen“) wird umgedreht.

Alternative zu Weg 2: Weg 1 nach S6 als Messung nachholen, falls sich zeigt, dass Apple den Widerruf je Client sauber trennt — dann könnte die Web-Ablage wieder entfallen (Datensparsamkeit). Kein Ticket nötig, solange Weg 2 trägt.

### Affected Files (with changes)
| File | Change Type | Teil | Description |
|------|-------------|------|-------------|
| `server/migrations/005_apple_tokens_per_client.sql` | CREATE | 4c-1 | PK `(account_id, client_id)`, `client_id` NOT NULL, Zeilen ohne ID weg |
| `server/src/apple-vault.ts` | MODIFY | 4c-1 | Upsert je Paar |
| `server/src/accounts.ts` | MODIFY | 4c-1 | `deleteAccount` Konto sperren, Tokens als Liste |
| `server/src/auth.ts` | MODIFY | 4c-1 | Widerruf je Zeile, Web-ID zugelassen |
| `server/src/oauth-return.ts` | MODIFY | 4c-2 | Web-Token speichern |
| `server/test/schema.test.ts`, `apple-vault.test.ts`, `accounts.test.ts`, `auth.test.ts` | MODIFY | 4c-1 | Form 005, App + Web nebeneinander, Löschen mit 2 Zeilen, zwei Widerrufe |
| `server/test/oauth-return.test.ts` | MODIFY | 4c-2 | gespeichert mit Web-ID, App-Token unberührt, 23503 → access_denied |
| `CLAUDE.md` | MODIFY | beide | Zeilen zu `apple-vault.ts`, `oauth-return.ts` |

### Scope Assessment
- 4c-1: 4 Quelldateien + 4 Tests, ≈ +45/−15 Code, mit Tests ≈ 150 LoC
- 4c-2: 1 Quelldatei + 1 Test, ≈ +15/−3 Code, mit Tests ≈ 60 LoC
- Risk Level: MEDIUM — ändert den Löschpfad (einziger Weg, ein Konto zu entfernen) und einen Primärschlüssel; Prod-Tabelle leer, also kein Datenrisiko.

### Dependencies
Reihenfolge 4c-1 vor 4c-2. Kein Gerät, keine App, kein `project.yml`: Stufe 3 greift nicht. Danach S5 (Zustimmung), S6 (Betrieb).

### Open Questions
- keine PO-Frage: rein technische Wahl, Henning merkt davon nichts. Kontrolle des Teilschnitts in `/30-write-spec` (Spec für 4c-1 zuerst).
