# Context: feat-615-s3c-konto-loeschen (#615, Schnitt 3c)

## Request Summary
Letzter Dienst-Schnitt von S3 (HTTP-Rand): `POST /auth/delete` löscht das Konto der Sitzung samt allem und gibt danach Apples Refresh-Token zurück (Widerruf, blockiert das Löschen nie). Dazu die Verdrahtung in den laufenden Dienst: `authRoutes` in `main()`/`start()`, `APPLE_*`-Konfiguration und JWKS einmal beim Start, 1-MiB-Body-Grenze in `bridge`.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/auth.ts` | `authRoutes(deps)` mit `/auth/apple`, `/auth/logout`, `bearerToken`, `notAllowed`, `status`; hier kommt `/auth/delete` dazu |
| `server/src/accounts.ts` | `resolveSession` (Konto zur Sitzung), `deleteAccount` (eine Transaktion, liefert `{deleted, appleToken, clientId}`; Sitzungen und `apple_tokens` fallen per FK) |
| `server/src/apple-vault.ts` | `decryptToken(key, accountId, blob)` → Text oder `null`, wirft nie |
| `server/src/apple-client.ts` | `revokeToken(token, clientId, {config, fetch, now})` → `{ok}` oder `{ok:false, reason}`; wirft nur bei leerem Token (Fehlbedienung) |
| `server/src/apple.ts` | `loadAppleConfig(env)` wirft mit Variablennamen bei fehlender/ungültiger Variable |
| `server/src/apple-jwks.ts` | `createJwks({fetch, now, url?})` → `{keys}`; Cache 1 h, Nachladen ≤ 1/60 s |
| `server/src/main.ts` | `start(options)` mit `extraRoutes`, `dispatch` (404/500 ohne Body), `bridge` puffert den Body **ohne Grenze**, `main()` liest nur `DATABASE_URL`, `PORT`, `HOST` |
| `server/test/auth.test.ts` | Testaufbau S3b: Schlüsselpaar, gefälschtes Apple-`fetch`, Wegwerf-Postgres; wird um Löschfälle erweitert |
| `server/test/main.test.ts` | `service(t, options)`-Helfer startet `start()` gegen Wegwerf-Postgres; Ort für Body-Grenze und Verdrahtung |
| `server/test/accounts.test.ts` | Zählungen aller Tabellen auf 0 nach `deleteAccount` (bestehend, bleibt) |
| `CLAUDE.md` (`server/`-Abschnitt) | Zeilen zu `src/auth.ts` und `src/main.ts` („nothing calls them yet“ fällt weg) |

## Existing Patterns
- Routen geben nackte Status ohne Body zurück; Ausnahmen werden nicht gefangen, `dispatch` macht 500.
- Ablehnung einheitlich (401), Apple nicht erreichbar/nicht konfiguriert 503.
- Abhängigkeiten werden hereingereicht (`AuthDeps`: `pool`, `config?`, `keys?`, `fetch`, `now`); Tests injizieren `fetch` und Pool-`Proxy`.
- Logs: eine Zeile, ISO-Zeit, nur festes Ereigniswort (`log`/`logError` in `main.ts`); `auth.ts` loggt bisher gar nicht (S3b-AC-11).
- Tests tabellengetrieben, `node:test` + `node:assert/strict`, Wegwerf-Postgres aus `server/test/db.ts`.

## Dependencies
- Upstream: `resolveSession`, `deleteAccount`, `decryptToken`, `revokeToken`, `loadAppleConfig`, `createJwks` — alle vorhanden und getestet, unverändert.
- Downstream: S4 App (Einstellungen „Konto löschen“, nach #625), #621 (`/mcp` mit `bearerToken` + `resolveSession`), Infra (nginx gibt heute nur `/health` frei; `/auth/*` und die `APPLE_*`-Secrets im Compose-Stack kommen mit dem Ausrollen, nicht in diesem Repo).

## Existing Specs
- `docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md` — Abschnitt „Nicht in diesem Schnitt“ listet genau den S3c-Umfang.
- `docs/specs/feat-615-schnitt-3a-datenschicht.md` — „Für S3b/S3c festgehalten“: Sitzung auflösen → `deleteAccount` → danach `decryptToken` und `revokeToken(token, clientId)`; Widerruf blockiert nie (`ok:false`, `null`, `clientId: null` → Logzeile ohne Token/Kennung, Antwort 204).
- `docs/specs/feat-615-schnitt-2c2-apple-widerruf.md` — `revokeToken` „ok heißt nur nicht abgelehnt“; Apple TN3194 (Widerruf bei Kontolöschung Pflicht, Best Effort).
- `docs/context/feat-615-s3-http-rand.md` — Entscheidungen 6 (Rand: 1 MiB global, 16 KiB Auth) und 8 (keine `APPLE_*` → Auth 503, Dienst startet; teilweise/ungültig → Start bricht mit Variablennamen ab). Schätzung S3c ≈ 60 Code, ≈ 150 Tests.

## Offene Punkte für /20-analyse
1. Löschen-Reihenfolge: Bearer → `resolveSession` → `deleteAccount` → Antwort; Widerruf vor oder nach der Antwort? (synchron 5-s-Limit vs. nachgelagert; Tests brauchen Determinismus).
2. Braucht `/auth/delete` `config`? Ohne `config` kann nicht entschlüsselt/widerrufen werden — löschen trotzdem (204 + Logzeile) oder 503?
3. Logzeile beim gescheiterten Widerruf: `auth.ts` bekommt ein `log`-Deps-Feld oder nutzt eine feste Ereigniszeile; S3b-AC-11 („auth.ts schreibt nie auf console“) muss dann angepasst oder der Log über Deps geführt werden.
4. Konfigurationsweiche in `main()`: „keine `APPLE_*` gesetzt“ vs. „teilweise gesetzt“ — `loadAppleConfig` wirft in beiden Fällen; Unterscheidung nötig.
5. 1-MiB-Grenze in `bridge`: gezählt beim Lesen, 413 ohne Body, Verbindung danach schließen.
6. Wiederholung des Widerrufs (Tabelle für offene Widerrufe?) — Analyse S2c-2 ließ es S3 offen; Best Effort mit Logzeile ist die Vorgabe aus 3a.
7. Umfang: Code ≈ 60, Tests ≈ 150 → voraussichtlich wieder über 250 LoC; ggf. Teilung (3c-1 Löschen, 3c-2 Verdrahtung + Rand).

## Risks & Considerations
- **Löschen darf nie an Apple hängen** (TN3194, Spec 3a): jede Widerrufspanne endet in 204.
- **Rennen Anmelden/Löschen:** S3b-AC-7 deckt das Konto-gelöscht-vor-Ablage ab; `deleteAccount` sperrt die Kontozeile.
- **Geheimnisse:** Token, Kennung, `client_id`, `sub` nie in Logs (Grundwort aus fester Liste).
- **Ein falscher `APPLE_TOKEN_KEY`** macht alte Blobs unlesbar → Widerruf entfällt still (Logzeile), Löschen läuft.
- **Produktwirkung:** sobald verdrahtet, sind `/auth/*` im Prozess erreichbar; öffentlich erst, wenn nginx sie freigibt (Infra, eigener Schritt beim Ausrollen).
- Kein Pfad der Geräteliste berührt (nur `server/`, `CLAUDE.md`).

## Analysis

### Type
Feature (Dienst, nur `server/`)

### Recherche (2026-11-05)
- Apple TN3194: Kontolöschung muss in der App anstoßbar sein; `/auth/revoke` ist der einzige Weg, die Tokens ohne Nutzer zu entwerten; `client_id` muss der beim Anmelden entsprechen; fehlt ein Token, wird trotzdem gelöscht (Nutzer widerruft dann selbst in den Apple-Einstellungen). https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple
- `node:http` hat keine Body-Grenze; üblich: beim Lesen zählen, 413 senden, `Connection: close`, Socket erst nach dem Senden schließen (ein `destroy()` direkt nach `end()` kann die 413 abschneiden). nginx-Standard `client_max_body_size` = 1 MiB, passt zur 1-MiB-Grenze.

### Entscheidungen zu den offenen Punkten
1. **Widerruf synchron nach dem Commit, vor der Antwort.** Reihenfolge: 405 → Bearer (fehlt → 401) → `resolveSession` (unbekannt → 401) → `deleteAccount` (`deleted:false` = Rennen → 401) → Widerruf → 204. Apple begrenzt `postForm` auf 5 s; das Konto ist zu dem Zeitpunkt schon weg, eine Zeitüberschreitung verlängert nur die Antwort. Deterministisch testbar. Alternative: Widerruf nach der Antwort im Hintergrund — schneller, aber bei SIGTERM verloren und in Tests nur über einen eigenen Haken zu fassen; verworfen.
2. **Löschen braucht keine Apple-Konfiguration.** Ohne `config` wird gelöscht, Widerruf entfällt mit Logzeile, Antwort 204. Löschen ist ein Recht des Nutzers und darf an nichts hängen (TN3194). Abweichung von `/auth/apple` (503 ohne config) ist gewollt.
3. **Logzeile über Deps:** `AuthDeps.log?: (event: string) => void`, Vorgabe stumm; `main` reicht später `logError` herein. S3b-AC-11 („auth.ts schreibt nie auf console") bleibt wahr. Feste Wörter, nie Token, Konto-ID, `sub`, `client_id`, Apple-Text: `apple revoke skipped` (keine config, kein Token, `client_id` null, Blob unlesbar) und `apple revoke failed` (`ok:false`).
4. **Konfigurationsweiche** (`APPLE_*` keine gesetzt → undefined; mindestens eine → `loadAppleConfig`, Fehler bricht Start mit Variablennamen ab) → **Schnitt 3c-2**.
5. **1-MiB-Grenze in `bridge`** (gezählt beim Lesen, 413, `connection: close`) → **Schnitt 3c-2**.
6. **Keine Wiederholungstabelle.** Ein offener Widerruf müsste das Apple-Token nach der Löschung weiter aufbewahren — widerspricht der Löschung selbst. Best Effort + Logzeile (Vorgabe Spec 3a).
7. **Teilung** (Tests ≈ 2,5× Code, Lehre aus S2a):
   - **3c-1 (dieser Workflow):** `POST /auth/delete` + `log`-Deps. ≈ +30 Code, ≈ +110 Tests, ≈ 145 LoC, 3 Dateien.
   - **3c-2 (nächster Workflow):** Verdrahtung in `start()`/`main()` (Auth-Routen brauchen den Pool aus `start` → neue Option statt `extraRoutes`, vor `migrate` 503 wie `/mcp`), JWKS einmal beim Start, Konfigurationsweiche, 1-MiB-Grenze. ≈ +45 Code, ≈ +110 Tests.

### Affected Files (3c-1)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/auth.ts` | MODIFY | `deleteAccountRoute`: Reihenfolge oben, `revokeAfterDelete` (config/Blob/client_id prüfen, `decryptToken`, `revokeToken`, Logzeile); `AuthDeps.log?`; Route `/auth/delete` |
| `server/test/auth.test.ts` | MODIFY | Löschfälle (Liste unten) |
| `CLAUDE.md` | MODIFY | `src/auth.ts`-Zeile um `/auth/delete` ergänzen |

### Testfälle 3c-1
- Rundweg: anmelden → löschen → 204; alle Tabellen des Kontos leer, Sitzung ungültig; Apple bekam genau einen `/auth/revoke` mit dem entschlüsselten Token und der gespeicherten `client_id`.
- Anderes Konto bleibt unberührt.
- Kein/fremdes Schema/unbekanntes Bearer → 401, nichts gelöscht, kein Apple-Aufruf; GET → 405 mit `allow: POST`.
- Widerruf scheitert (Netz weg, Apple 400 `invalid_grant`, Zeitüberschreitung simuliert) → 204, Konto weg, eine Logzeile `apple revoke failed`.
- Ohne config / `client_id` null (Zeile vor 003) / falscher `tokenKey` → 204, Konto weg, kein Apple-Aufruf, Logzeile `apple revoke skipped`.
- Zwei gleichzeitige Löschungen derselben Sitzung → genau eine 204, eine 401, ein Widerruf.
- Keine Logzeile enthält Token, Sitzungstoken, Konto-ID, `sub` oder `client_id`; Antworten ohne Body.

### Scope Assessment
- Files: 3
- Estimated LoC: ≈ +145 / −2
- Risk Level: LOW — neue Route, noch nicht verdrahtet (öffentlich erst mit 3c-2 und nginx-Freigabe); bestehende Funktionen unverändert.

### Alternativen
- Löschen als MCP-Werkzeug statt HTTP-Route: verworfen, Löschen gehört in die App-Einstellungen (Apple-Pflicht), nicht zu Claude; würde ADR-21 (Anmeldung nur über `/auth/*`) berühren.
- Ungeteilt (3c in einem Schnitt, ≈ 250–290 LoC): verworfen wegen Scoping-Limit.

### Dependencies
`resolveSession`, `deleteAccount`, `decryptToken`, `revokeToken` — vorhanden, unverändert. Downstream: 3c-2, S4 App, #621.

### Open Questions
- keine (alles technisch; kein Pfad der Geräteliste berührt)

## Freigabe Zeilengrenze (2026-11-05, nach RED)

Tests 265 Zeilen statt geschätzt 110, Schnitt gesamt ≈ 300 statt ≈ 145 (Grenze 250). Henning per Auswahl: „Annehmen, so bauen“.
