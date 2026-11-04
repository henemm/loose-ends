# Context: feat-615-s3-http-rand

## Request Summary
#615 Schnitt 3: der HTTP-Rand des Dienstes für Konten — Anmelden (Apple-Identity-Token + Code → Konto + Sitzung),
Abmelden (Sitzung beenden), Konto löschen (Daten leeren, Apple-Token widerrufen). Nur Dienstcode in `server/`; die App ruft
den Dienst bis S4 (nach #625) nirgends auf.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/main.ts` | Routentabelle (`routes`, `extraRoutes`), `dispatch` (404/500 ohne Body), `bridge` (puffert den ganzen Body ohne Größengrenze); `main()` übergibt keine Apple-Konfiguration |
| `server/src/accounts.ts` | `findOrCreate`, `createSession`, `resolveSession`, `endSession`, `deleteAccount` (gibt den verschlüsselten Blob zurück) — alles vorhanden, nichts verdrahtet |
| `server/src/apple.ts` | `loadAppleConfig` (5 `APPLE_*`), `verifyIdentityToken` → `{ok, sub}`; **gibt `aud` nicht zurück** |
| `server/src/apple-jwks.ts` | `createJwks(opts)` → `{ keys }`, Cache 1 h; „einmal beim Start“ ist S3 vorbehalten |
| `server/src/apple-client.ts` | `redeemCode(code, clientId, opts)` → `{refreshToken, sub}`; `revokeToken(token, clientId, opts)` → `{ok}`, wirft nie bei Apples Antwort |
| `server/src/apple-vault.ts` | `encryptToken`, `decryptToken` (null bei jedem Fehler), `storeRefreshToken` (Upsert, false bei unbekanntem Konto) |
| `server/migrations/002_accounts.sql` | `accounts`, `sessions` (ohne Ablauf, nur `last_used_at`), `apple_tokens` (ohne `client_id`) |
| `server/src/mcp.ts` | liest das Konto nur aus `authInfo.extra.account`; Token-Prüfung am `/mcp` ist #621 |
| `server/test/db.ts`, `server/test/main.test.ts` | Testgerüst (Wegwerf-Postgres), Muster für Routen-Tests mit `extraRoutes` |
| `docs/specs/feat-615-schnitt-2c1/2c2-*.md` | Abschnitte „Für S3 festgehalten“: `sub`-Vergleich, `client_id`-Ablage, Widerruf blockiert Löschen nie |

## Existing Patterns
- Reine Bausteine mit hereingereichtem `fetch`/`now`/Schlüsselsuche; Fehler als Werte (`{ok:false, reason}`), Fehlertexte ohne Token, ID, Schlüssel.
- Routen sind `(Request) => Promise<Response>`, Antworten ohne Body bei 404/500; Log-Zeilen ohne Aufgabentext, IDs oder Datenbanktext.
- Spezifikationen mit nummerierten ACs, tabellengetriebene Angriffsfälle, Adversary-Dialog; Tests ≈ 2,5× Code (Memory).

## Dependencies
- Upstream: alle Bausteine aus S1–S2c-2; Postgres; `APPLE_*`-Umgebung (Team, Key-ID, Client-IDs, `.p8`, Token-Schlüssel).
- Downstream: #621 (Token am `/mcp`, nutzt `resolveSession`), S4 (App-Anmeldung), Betrieb auf `rennwienix` (Stack in `henemm-infra`).

## Offene Entscheidungen für die Analyse (aus den Vorgänger-Specs)
1. **`client_id`:** `verifyIdentityToken` liefert nur `sub`. Für Einlösen und Widerruf wird die `aud` gebraucht → `Verdict` um `aud` erweitern; Ablage für den Widerruf als Spalte `client_id` in `apple_tokens` (Migration 003, additiv) oder `clientIds[0]` bis #621.
2. **`sub`-Vergleich:** `redeemCode`-`sub` muss dem `sub` des Identity-Tokens gleichen, sonst wird nichts abgelegt und keine Sitzung erteilt.
3. **Reihenfolge Anmelden:** Token prüfen → Code einlösen → Konto → Token verschlüsseln und ablegen → Sitzung. Ein Fehlschlag in der Mitte darf keine verwaiste Sitzung hinterlassen (ein leeres Konto ist ohne Belang, `findOrCreate` ist idempotent).
4. **Löschen:** `deleteAccount` zuerst (Konto weg), dann `decryptToken` → `revokeToken`; `ok:false` blockiert nie, Protokoll ohne Token/ID; neuer `APPLE_TOKEN_KEY` → Widerruf entfällt.
5. **Sitzungen haben keinen Ablauf** (S1). Ob S3 eine Höchstdauer/Leerlaufgrenze einführt, ist in der Analyse zu entscheiden (Blast Radius Auth).
6. **Rand-Härtung:** `bridge` puffert Bodies unbegrenzt; die neuen Routen sind öffentlich und lösen Apple-Aufrufe aus → Größengrenze, Methode/Content-Type, einheitliche Fehlerantwort ohne Details, Begrenzung der Anmeldeversuche.
7. **Bearer-Auslesen** für Abmelden/Löschen: gemeinsame kleine Funktion; `/mcp` bleibt #621.

## Risks & Considerations
- LoC: Code + Tests + Doku liegt voraussichtlich deutlich über 250 → Schnitt in S3a (Anmelden/Abmelden, Migration 003, `aud`) und S3b (Löschen, Verdrahtung in `main()`, Rand-Härtung) vorschlagen, wie bei S2.
- `APPLE_*` fehlen auf `rennwienix` (Infra, nur Claude): ohne sie bleibt die Anmeldung aus (503/404), der Dienst muss trotzdem starten.
- Öffentliche Routen auf `loose-ends.henemm.com` erst nach Rollout von Hand (`deploy-loose-ends.sh`); der nginx-Host muss die Pfade durchlassen (`henemm-infra`).
- Datenschutztext (#625) muss vor externen Nutzern geändert sein; bis S4 ruft niemand die Routen.
- Keine Geräteliste-Pfade, kein Schema (`cloudkit/schema.ckdb`), keine `project.yml`.

## Analysis

### Type
Feature (Dienstcode, kein UI → kein Entwurf nötig; die App ruft nichts auf, bis S4).

### Recherche (2026-11-04)
- Apple TN3194: `/auth/revoke` ist der einzige Weg, Tokens ohne Nutzerinteraktion ungültig zu machen; das `client_id` beim Widerruf muss dem bei der Anmeldung entsprechen; fehlt der Token, muss die Löschung trotzdem erfolgen. → Löschen blockiert nie am Widerruf. Quelle: https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple.md ; Forum zur offenen Frage „Reichweite über Client-IDs“: https://developer.apple.com/forums/thread/844628
- Sitzungen: Idle- und Absolutgrenze serverseitig empfohlen (OWASP, Sekundärquellen, Zahlen für Büro-Apps; nicht übertragbar auf Dauer-Anmeldung in einer App) → eigene Entscheidung unten.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple.ts` | MODIFY | `Verdict` um `aud` erweitern (additiv; 6 `deepEqual`-Stellen in `apple.test.ts` anpassen) |
| `server/migrations/003_apple_client_id.sql` | CREATE | `apple_tokens.client_id text` (nullable, additiv) |
| `server/src/apple-vault.ts` | MODIFY | `storeRefreshToken(pool, id, blob, clientId)` |
| `server/src/accounts.ts` | MODIFY | `deleteAccount` liefert zusätzlich `clientId` |
| `server/src/auth.ts` | CREATE | `authRoutes(deps)`: `POST /auth/apple`, `/auth/logout`, `/auth/delete`; Bearer-Auslesen; einheitliche Antworten |
| `server/src/main.ts` | MODIFY | Body-Grenze in `bridge` (413), Apple-Konfiguration + JWKS beim Start, Routen einhängen |
| `server/test/auth.test.ts` u. a. | CREATE/MODIFY | Angriffsfälle tabellengetrieben, Rundwege gegen echtes Postgres |

### Entscheidungen (zu den 7 offenen Punkten)
1. **`client_id`:** `Verdict.aud` + Spalte `apple_tokens.client_id`. `clientIds` kann mehrere Einträge haben (Tests prüfen `IDS[1]`), Apple verlangt Übereinstimmung beim Widerruf; `clientIds[0]` zu raten wäre bei einem zweiten Client still falsch. Zeilen ohne Wert → Widerruf entfällt mit Logzeile.
2. **`sub`-Vergleich:** `redeemCode.sub !== verdict.sub` → 401, nichts abgelegt, keine Sitzung. Der Code wird immer eingelöst (bei Apple einmalig): das ist zugleich der Replay-Schutz für einen abgefangenen Identity-Token.
3. **Reihenfolge Anmelden:** verify → redeem → `sub`-Vergleich → `findOrCreate` → verschlüsseln + ablegen → `createSession` zuletzt (kein Fehler in der Mitte hinterlässt eine Sitzung). Erneutes Anmelden ersetzt den abgelegten Token; der alte bleibt bei Apple gültig (bewusst nicht widerrufen).
4. **Löschen:** Sitzung auflösen → `deleteAccount` (Transaktion) → danach `decryptToken` → `revokeToken` (nur nach Commit; `ok:false`/Fehler blockiert nie; Log ohne Token/ID) → 204. Zweiter Aufruf mit derselben Sitzung → 401.
5. **Sitzungsablauf: nicht in S3.** `resolveSession` ist gemeinsamer Kern mit #621 (`/mcp`); eine Idle-/Absolutgrenze ändert dort das Verhalten → Merkposten an #621. Bis S4 gibt es keinen ausgegebenen Token, die Lücke ist bis dahin theoretisch.
6. **Rand:** Body-Grenze 1 MiB global in `bridge` (413), 16 KiB in den Auth-Routen; nur POST (405), nur `application/json` (415), Form geprüft (400); Antworten ohne Body und ohne Grund (401 für jede Ablehnung von Token/Code/`sub`, 503 wenn Apple nicht konfiguriert/nicht erreichbar); Logzeile nur mit Grundwort aus fester Liste. **Kein eigener Versuchszähler im Prozess:** Apple-Aufrufe entstehen erst nach gültiger Apple-Signatur, JWKS-Nachladen ist auf 1/60 s begrenzt. Drosselung als `limit_req` im nginx-Host (Infra).
7. **Bearer:** eine Funktion in `auth.ts` (`Authorization: Bearer <token>`, sonst null); `/mcp` bleibt #621.
8. **Konfiguration:** keine `APPLE_*` gesetzt → Auth-Routen 503, Dienst startet; teilweise/ungültig → Start bricht mit Variablennamen ab.

### Scope Assessment
- Code ≈ 140 LoC, Tests ≈ 2,5× → ≈ 480 LoC, ≈ 9 Dateien → über dem Limit.
- Schnitt-Vorschlag (wie S2):
  - S3a Datenschicht (`aud`, Migration 003, `storeRefreshToken`, `deleteAccount`+`clientId`): ≈ 35 Code, Tests ≈ 100.
  - S3b Anmelden/Abmelden (`auth.ts`, `/auth/apple`, `/auth/logout`, Bearer; Test über `extraRoutes`): ≈ 80 Code, Tests ≈ 200.
  - S3c Löschen + Verdrahtung + Rand (`/auth/delete`, Start-Konfiguration, Body-Grenze): ≈ 60 Code, Tests ≈ 150.
- Risk Level: MEDIUM (Authentifizierung, aber nichts ruft sie auf; kein Pfad der Geräteliste, kein `cloudkit/`-Schema).

### Technical Approach
Reine Bausteine bleiben; `authRoutes({pool, config, keys, fetch, now})` setzt sie zusammen (alles hereingereicht, Tests ohne Netz). Fehler als Werte, eine Antwortfunktion für alle Ablehnungen.

### Alternativen
- A. Identity-Token von Apple bei jedem Aufruf statt eigener Sitzung: läuft nach Minuten ab, Nonce nicht wiederholbar → verworfen (kippt S1).
- B. Kein `client_id`-Feld, `clientIds[0]`: −15 LoC, bei einem zweiten Client still falsch. Kippt nichts; Spalte empfohlen, weil billig.
- C. Ohne Code einlösen (nur Identity-Token): kein Refresh-Token → kein Widerruf, kein Replay-Schutz → verworfen.
- D. Drosselung im Prozess statt nginx: mehr Code, hinter Proxy ohne verlässliche Client-IP wenig wert → verworfen.

### Dependencies
Upstream S1–S2c-2 (vorhanden). Downstream #621 (Sitzungsablauf-Merkposten), S4 (App, nach #625), Betrieb: `APPLE_*` auf `rennwienix`, nginx-Pfad `/auth/` (Infra).

### Open Questions
- [ ] Schnitt in S3a/S3b/S3c mit LoC-Überhang wie bei S2 (PO-Entscheidung beim Spec-Schritt).
- [ ] Merkposten „Sitzungsablauf“ an #621 hängen.
