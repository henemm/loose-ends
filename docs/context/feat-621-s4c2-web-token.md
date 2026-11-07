# Context: feat-621-s4c2-web-token

## Request Summary
#621, Schnitt 4c-2: Der Rückweg der Browser-Anmeldung (`POST /oauth/apple/return`) verwirft heute das Apple-Refresh-Token
der Services ID (`server/src/oauth-return.ts:90`). Er soll es verschlüsselt mit `webClientId` ablegen, damit `/auth/delete`
es seit 4c-1 (PR #863) beim Löschen des Kontos mit der eigenen ID bei Apple widerruft.

Recherche, Wegevergleich und Empfehlung (Weg 2, Teilschnitte 4c-1/4c-2) stehen in `docs/context/feat-621-s4c-web-token.md`
(Abschnitte „Recherche (2026-11-06)“, „Wege im Vergleich“, „Empfehlung“); 4c-1 ist gemergt, dieses Dokument ergänzt nur,
was für 4c-2 gilt.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/oauth-return.ts` | `outcome()` Z. 83–94: `redeemCode` → `verifyIdentityToken` → `findOrCreate`; Z. 90 verwirft das Token. Hier wird gespeichert. Ein Wurf in `outcome()` endet in `finishReturn` (Z. 110–116) als feste 400 `oauth return store failed`, nie als Redirect ohne Ticket. |
| `server/src/apple-vault.ts` | `encryptToken(key, accountId, token)` (Konto als AAD); `storeRefreshToken(pool, accountId, blob, clientId)` Upsert je `(account_id, client_id)`, `false` bei 23503, leere ID wirft. |
| `server/src/auth.ts` | Muster Z. 61–74 (`signIn`): `findOrCreate` → `encryptToken` → `storeRefreshToken(…, verdict.aud)`, `false` → 401. `revokeAfterDelete` widerruft seit 4c-1 jede Zeile mit eigener `client_id`, Web-ID zugelassen. |
| `server/src/apple.ts` | `AppleConfig.tokenKey` (32 Byte), `webClientId` (optional; der Rückweg existiert nur mit ihr). |
| `server/src/main.ts` Z. 160–168 | `returnFor` baut `appleReturn` nur mit `webClientId` und JWKS; `deps.config` ist dieselbe Config wie `/auth/*`. |
| `server/test/oauth-return.test.ts` | Z. 459–468 „web-token wird nicht gespeichert und nicht widerrufen“ (AC-14 aus 4b-2a) wird umgedreht; Z. 395–415 belegt schon „ungültiges identity-token → nichts in `apple_tokens`“; Z. 433–457 zeigt das Muster „Konto zwischendurch gelöscht“ über einen vorgeschalteten Pool. Fake-Apple zählt `revokes` (Z. 66–90). |
| `server/test/auth.test.ts` Z. 340–360, 600–660 | Rig für `/auth/delete` mit Widerruf; Vorlage, falls ein Ende-zu-Ende-Beleg „Browser-Anmeldung → Löschen → Widerruf mit Web-ID“ gewünscht ist. |

## Existing Patterns
- Token nur verschlüsselt, nie im Klartext in Tabelle, Antwort oder Protokoll; Protokoll nur feste Ereignisse (`oauth return refused`/`oauth return store failed`).
- Reihenfolge wie `/auth/apple`: erst Prüfungen, dann Konto, dann Token ablegen, dann das Ergebnis (dort Sitzung, hier Ticket).
- `false` von `storeRefreshToken` = Konto gelöscht während der Anmeldung → Anmeldung scheitert (dort 401, hier Ticket `access_denied`).

## Dependencies
- Upstream: `redeemCode` (liefert `refreshToken`), `verifyIdentityToken`, `findOrCreate`, `encryptToken`, `storeRefreshToken`.
- Downstream: `/auth/delete` → `deleteAccount` (Liste je Client) → `revokeAfterDelete`; finish (S4b-2b) liest nur das Ticket, unberührt.

## Existing Specs
- `docs/specs/feat-621-schnitt-4c1-ablage-je-client.md` (Z. 192: Beschreibung von 4c-2)
- `docs/specs/feat-621-schnitt-4b2a-rueckweg.md` (AC-14 Verzicht, Alternative F)

## Parallele Arbeit
- PR #865 (Cloud-Sitzung, eigene Tabelle `apple_web_tokens`, Migration 005) wurde am 2026-11-07 ungemergt geschlossen; sein Aufbau kollidiert mit dem gemergten 4c-1. Die gestapelten PRs #866–#868 (S5 Lesen/Schreiben/Zustimmung) stehen auf dieser Basis; #868 ändert ebenfalls `server/test/oauth-return.test.ts` (neue Zustimmungs-Tests am Dateiende) — Konflikt nur textuell, nicht inhaltlich.

## Risks & Considerations
- Konto zwischen `findOrCreate` und Ablage gelöscht (23503) → `access_denied`, kein Ticket mit Konto-ID.
- Datenbankfehler beim Ablegen → wie heute feste 400 `store failed` (über den Wurf in `outcome`).
- App-Token desselben Kontos darf nicht überschrieben werden (Upsert je Paar seit 4c-1; Test mit beiden Zeilen).
- Zweite Browser-Anmeldung ersetzt die Web-Zeile (genau eine Zeile je Konto und Web-ID).
- Reihenfolge: erst nach bestandener id_token-Prüfung ablegen; abgelehnte Einlösung oder Prüfung legen nichts ab (Z. 395–415 belegt das schon für ein ungültiges Token).
- Kein Gerät, keine App, keine Migration: Stufe 3 greift nicht.

## Analysis

### Type
Feature (Schnitt 4c-2 von #621; 4c-1 gemergt mit PR #863)

### Befund am Code (2026-11-07, Stand origin/main 8df564a)
- `redeemCode` liefert im Web-Fluss schon `refreshToken` (Pflichtfeld, sonst `malformed_response`); `outcome()` wirft es weg (`server/src/oauth-return.ts:90`).
- Der `sub` des Kontos kommt aus `verifyIdentityToken` auf genau dem `idToken`, den `redeemCode` zurückgab; ein eigener Abgleich `redeemed.sub === verdict.sub` wie in `signIn` ist hier durch dasselbe Token schon erfüllt.
- `storeRefreshToken` (4c-1) ist Upsert je `(account_id, client_id)`, `false` bei 23503, wirft bei leerer ID; `encryptToken` bindet das Konto als AAD. Beides bleibt unverändert.
- `/auth/delete` → `revokeAfterDelete` widerruft seit 4c-1 jede Zeile mit eigener `client_id`, Web-ID zugelassen: die Gegenseite ist fertig.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/oauth-return.ts` | MODIFY | `outcome()`: nach `findOrCreate` `encryptToken(config.tokenKey, accountId, redeemed.refreshToken)` → `storeRefreshToken(pool, accountId, blob, webClientId)`; `false` → Ticket `access_denied`; Kommentar Z. 90 entfällt; Import aus `apple-vault.ts` |
| `server/test/oauth-return.test.ts` | MODIFY | Test „web-token wird nicht gespeichert“ umdrehen: genau eine Zeile mit `client_id = webClientId`, entschlüsselt = Apples Token, Klartext nirgends; neu: App-Zeile desselben Kontos bleibt, zweite Anmeldung ersetzt die Web-Zeile, Konto zwischendurch gelöscht → `access_denied` ohne Zeile, DB-Fehler beim Ablegen → 400 `store failed`, abgelehnte Einlösung/Prüfung → keine Zeile |
| `server/test/auth.test.ts` | MODIFY (optional) | Ende-zu-Ende: Web-Zeile aus dem Rückweg → `/auth/delete` → Widerruf mit `client_id = webClientId` (4c-1 belegt den Widerruf schon mit einer von Hand gesetzten Zeile; Entscheidung in der Spec) |
| `CLAUDE.md` | MODIFY | Satz „The web refresh token is neither stored nor revoked (own cut before S6)“ ersetzen |

### Scope Assessment
- Files: 3–4
- Estimated LoC: Code ≈ +8/−2, Tests ≈ +70–90, Doku ≈ ±2 → gesamt ≈ 90–100, klar unter 250
- Risk Level: LOW — eine Stelle im Rückweg, Bausteine unverändert, keine Migration, kein Gerät

### Technical Approach (Empfehlung)
Weg A: In `outcome()` nach `findOrCreate` verschlüsseln und mit `webClientId` ablegen, genau wie `signIn` in `auth.ts`
(Prüfungen → Konto → Token → Ergebnis). `false` (Konto während der Anmeldung gelöscht) → Ticket `{ uid, error: "access_denied" }`,
nie ein Ticket mit Konto-ID. Ein Wurf (DB-Fehler) läuft wie heute in `finishReturn` auf die feste 400 `oauth return store failed`.
Keine neuen Protokollereignisse.

### Alternativen
- **B — Token sofort bei Apple widerrufen statt ablegen** (Alternative F aus 4b-2a): keine Ablage, aber Apple löst die Verbindung
  mit der Services ID sofort wieder, beim Löschen gäbe es nichts zu widerrufen, und jede Browser-Anmeldung kostet einen zweiten
  Apple-Aufruf. Kippt „Weg 2“ aus `feat-621-s4c-web-token.md`. Verworfen.
- **C — eigene Tabelle `apple_web_tokens`** (PR #865, geschlossen): doppelt zu 4c-1, Löschen und Widerruf müssten zwei Tabellen lesen. Verworfen.
- **D — Ablegen erst in `finish`**: das Token müsste dafür im Ticket mitreisen (verschlüsselt in `oauth_records`), mehr Fläche ohne Gewinn. Verworfen.

### Befunde gegen den Plan
Keine sachlichen. Nur textuell: PRs #866–#868 ändern `CLAUDE.md`, #868 hängt Tests ans Ende von `oauth-return.test.ts` —
Konflikt beim Zusammenführen, nicht im Verhalten.

### Dependencies
Upstream unverändert: `redeemCode`, `verifyIdentityToken`, `findOrCreate`, `encryptToken`, `storeRefreshToken`.
Downstream: `/auth/delete` (4c-1) nutzt die neue Zeile; `finish` (S4b-2b) liest nur das Ticket, unberührt.

### Abnahme
Reiner Serverschnitt: Tests über `./server/scripts/test-local.sh`. Kein Pfad der Geräteliste berührt.

### Open Questions
- keine
