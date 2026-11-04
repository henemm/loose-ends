# Context: feat-615-s3b-anmelden-abmelden

## Request Summary
#615 Schnitt 3b (Epic #612, Weg B, ADR-21): die beiden HTTP-Routen `POST /auth/apple` (Anmelden) und `POST /auth/logout` (Abmelden) im Dienst. Löschen, Verdrahtung in `main()`, Body-Grenze 1 MiB und Start-Konfiguration sind S3c. Die Analyse für ganz Schnitt 3 steht in `docs/context/feat-615-s3-http-rand.md` (Abschnitt „Analysis“, Entscheidungen 2, 3, 6, 7); S3a (PR #826) hat `aud`, Migration 003, `storeRefreshToken(…, clientId)` und `Deletion.clientId` geliefert.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/auth.ts` | NEU: `authRoutes(deps)`, `bearerToken` |
| `server/src/apple.ts` | `verifyIdentityToken(token, rawNonce, {config, keys, now})` → `{ok, sub, aud}`; `AppleConfig`, `KeyLookup` |
| `server/src/apple-client.ts` | `redeemCode(code, clientId, {config, fetch, now})` → `{ok, refreshToken, sub}` oder `{ok:false, reason}` |
| `server/src/apple-vault.ts` | `encryptToken(key, accountId, token)`, `storeRefreshToken(pool, id, blob, clientId)` (false bei unbekanntem Konto) |
| `server/src/accounts.ts` | `findOrCreate`, `createSession`, `endSession`; `resolveSession` bleibt für #621 |
| `server/src/main.ts` | `Route = (Request) => Promise<Response>`; `dispatch` macht 404/500 ohne Body und zählt im Fehlerfenster; `extraRoutes` kommt vor dem Pool in `start()`, also reicht ein Test den Pool selbst herein (`service(...).databaseUrl`) |
| `server/test/main.test.ts` | Muster `service(t)` mit eigenem Schema je Test; Vorbild für Rundwegtests über `extraRoutes` |
| `server/test/apple*.test.ts` | Muster für gefälschte Apple-Antworten (Schlüsselpaar, injiziertes `fetch`, tabellengetrieben) |

## Existing Patterns
- Bausteine sind rein; alles Äußere (Pool, `fetch`, `now`, `keys`) wird hereingereicht, Tests laufen ohne Netz.
- Fehler als Werte `{ok:false, reason}`; Gründe aus fester Liste, nie Apples Text; Log nur Grundwort, nie Token, ID, Code.
- Antworten ohne Body (`new Response(null, {status})`); Ausnahme in der Route → 500 durch `dispatch`.
- Tests: `node:test`, `node:assert/strict`, echtes Postgres, tabellengetriebene Angriffsfälle, Tests ≈ 2,5× Code.

## Dependencies
- Upstream: alles aus S1–S3a (vorhanden), `APPLE_*`-Konfiguration als hereingereichtes `AppleConfig`.
- Downstream: S3c (`/auth/delete`, Verdrahtung, Body-Grenze, Start-Konfiguration), #621 (`/mcp` nutzt `resolveSession` und `bearerToken`), S4 (App).

## Existing Specs
- `docs/specs/feat-615-schnitt-3a-datenschicht.md`, `…-2c1-apple-einloesen.md`, `…-2c2-apple-widerruf.md` (Stil, Festlegungen zu Stille und Länge).

## Risks & Considerations
- Anmelde-Reihenfolge ohne verwaiste Sitzung: verify → redeem → `sub` gleich? → `findOrCreate` → verschlüsseln + ablegen → `createSession` zuletzt.
- `storeRefreshToken` = false (Konto zwischenzeitlich gelöscht) → keine Sitzung, Antwort wie jede Ablehnung.
- Der Code wird immer eingelöst (Replay-Schutz für einen abgefangenen Identity-Token). `redeemCode`/`clientSecret` können bei Fehlbedienung werfen → 500 durch `dispatch`, nie Details.
- Gründe nach außen einheitlich (401), nur 503 wenn Apple nicht erreichbar ist (`unavailable`/`keys_unavailable`).
- Eingabe: nur POST (405), nur `application/json` (415), Body höchstens 16 KiB (413), Felder `identityToken`, `nonce`, `code` als nicht-leere Texte (400). Die 1-MiB-Grenze im `bridge` ist S3c; die 16 KiB gelten hier beim Lesen in der Route.
- Aus der Geräteliste wird nichts berührt, kein Schema, keine `project.yml`; nichts ruft die Routen auf (bis S4).

## Analysis (kurz, Summe 3)
- Typ: Feature, Dienstcode ohne UI (kein Entwurf nötig).
- Dateien: `server/src/auth.ts` (neu, ≈ 80 Zeilen), `server/test/auth.test.ts` (neu, ≈ 200), `CLAUDE.md` (ein Absatz), Spec. Das sind 4 Dateien und ≈ 300 LoC. Das 250-LoC-Limit wird mit den Tests voraussichtlich überschritten (wie bei S2, vor dem Bauen mit dem PO abstimmen).
- Alternative: Anmelden und Abmelden in zwei Schnitten (≈ 60 + 40 Code). Dagegen spricht, dass Bearer-Funktion und Antwortformen gemeinsam sind. Empfehlung: ein Schnitt.
- Rückfall: Fehlt `config` oder `keys`, antworten die Routen 503, damit S3c den Dienst auch ohne `APPLE_*` starten kann.

## Analysis (S3b, 2026-11-04)

### Type
Feature (Dienstcode ohne UI, kein Entwurf nötig; nichts ruft die Routen auf, bis S4).

### Recherche (2026-11-04)
- Apple REST-Doku und Forum: der Authorization Code ist einmalig und 5 Minuten gültig; ein zweites Einlösen oder Ablauf gibt `invalid_grant`; Client-ID muss zur App passen (App-ID nativ). → Der Code wird in der Route sofort und genau einmal eingelöst; `invalid_grant` wird nach außen wie jede Ablehnung zu 401. Quellen: https://developer.apple.com/forums/thread/132214 , https://developer.apple.com/forums/thread/118135 , https://developer.apple.com/tutorials/data/documentation/signinwithapplerestapi/request-an-authorization-to-the-sign-in-with-apple-server..md
- Nonce-/Identity-Token-Prüfung: schon in S2a gebaut und dort recherchiert (`verifyIdentityToken`); hier nicht neu.
- Rest (Löschen, Widerruf, Sitzungsgrenzen): Recherche in `docs/context/feat-615-s3-http-rand.md`.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/auth.ts` | CREATE | `authRoutes({pool, config, keys, fetch, now})` mit `POST /auth/apple`, `POST /auth/logout`; `bearerToken`; fehlt `config`/`keys` → 503 |
| `server/test/auth.test.ts` | CREATE | tabellengetriebene Ablehnungsfälle, Rundweg gegen echtes Postgres über `extraRoutes`, gefälschte Apple-Antworten |
| `CLAUDE.md` | MODIFY | ein Absatz unter `server/` |
| `docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md` | CREATE | Spec |

### Scope Assessment
- Files: 4 (davon 2 Code/Test). Code ≈ 80 LoC, Tests ≈ 200 → ≈ 300 LoC, über dem 250er-Limit durch Sicherheitstests (wie S2); beim Spec-Schritt mit dem PO abstimmen. Keine Geräteliste, kein Schema, keine `project.yml`.
- Risk Level: MEDIUM (Authentifizierung, aber ohne Aufrufer).

### Technical Approach
Reine Bausteine zusammensetzen, alles Äußere hereinreichen. Reihenfolge Anmelden: Methode (405) → Content-Type (415) → Body ≤ 16 KiB (413) → Felder `identityToken`, `nonce`, `code` nicht-leere Texte (400) → `verifyIdentityToken` → `redeemCode(code, aud)` (immer, Replay-Schutz) → `sub` gleich? → `findOrCreate` → `encryptToken` + `storeRefreshToken(…, aud)` (false → 401) → `createSession` zuletzt → 200 `{sessionToken}`. Gründe einheitlich 401, nur `unavailable`/`keys_unavailable` → 503; Log nur Grundwort. Abmelden: Bearer lesen, `endSession`, 204 (auch bei unbekannter Sitzung, damit nichts verraten wird; ohne Bearer 401).

### Alternativen
- Anmelden und Abmelden getrennt (≈ 60 + 40 LoC): gemeinsame Bearer-/Antwortformen sprechen für einen Schnitt; kippt nichts.
- Abmelden mit 401 bei unbekannter Sitzung statt 204: verrät, ob ein Token je gültig war; 204 empfohlen.

### Dependencies
Upstream S1–S3a (vorhanden). Downstream S3c (Löschen, Verdrahtung, Body-Grenze), #621 (`bearerToken`, `resolveSession`).

### Open Questions
- [ ] LoC-Überhang ≈ 300 durch Tests: beim Spec-Schritt bestätigen lassen (wie S2).
