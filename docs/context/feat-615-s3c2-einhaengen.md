# Context: feat-615-s3c2-einhaengen

## Request Summary
#615 Schnitt 3c-2: Die fertigen Routen `/auth/apple`, `/auth/logout`, `/auth/delete` (`authRoutes`, S3b/S3c-1) in den
laufenden Dienst einhängen. Plan aus `docs/specs/feat-615-schnitt-3c1-konto-loeschen.md` (Abschnitt Folgeschnitte):
neue Option statt `extraRoutes`, vor `migrate` 503 wie `/mcp`, `APPLE_*`-Weiche (keine gesetzt → Auth 503, teilweise
oder ungültig → Start bricht mit Variablennamen ab), JWKS einmal beim Start, 1-MiB-Grenze im `bridge`, `logError` als
`log` hereinreichen (darf nicht werfen).

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/main.ts` | `start()` (Routentabelle, `/mcp` 503 vor migrate), `bridge` (liest den Körper ungebremst, `buffered`), `main()` (Umgebung lesen, Exit-Codes), `log`/`logError` |
| `server/src/auth.ts` | `authRoutes(deps)`, `AuthDeps { pool, config?, keys?, fetch, now, log? }`; `/auth/apple` 503 ohne `config`/`keys`, logout/delete brauchen keine Apple-Konfiguration |
| `server/src/apple.ts` | `loadAppleConfig(env)` wirft mit Variablennamen bei fehlender/ungültiger Angabe; fünf Variablen `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_IDS`, `APPLE_PRIVATE_KEY`, `APPLE_TOKEN_KEY` |
| `server/src/apple-jwks.ts` | `createJwks({ fetch, now })` – Cache lädt bei erster Abfrage (lazy), 1 h, Sperre 60 s |
| `server/test/main.test.ts` | Starttests S1 (AC-1…AC-10), Hilfsfunktion `service(t, options)`; AC-10 prüft Log ohne Geheimnisse |
| `server/test/auth.test.ts` | Routentests über `authRoutes` direkt; ein Test hängt `/auth/delete` per `extraRoutes` ein (Z. 543) |
| `CLAUDE.md` (Abschnitt `server/`) | Zeilen „nothing calls them yet“ für `auth.ts` werden mit diesem Schnitt falsch |

## Existing Patterns
- Abhängigkeiten werden hereingereicht (`fetch`, `now`, `log`), nie global gegriffen; Tests ersetzen sie.
- Vor `migrate` antwortet jede DB-Route 503 ohne Körper (`/mcp`).
- Fehlermeldungen nennen nur den Variablennamen, nie den Wert (`required` in `apple.ts`).
- Log: eine Zeile je Ereignis, ISO-Zeit vorn, keine Texte, IDs oder Fehlertexte (AC-10 S1).
- `dispatch` macht aus Ausnahmen 500 ohne Körper und zählt jede Antwort außer `/health` ins Fehlerfenster.

## Dependencies
- Upstream: `accounts.ts`, `apple*.ts`, `node:http`, `pg`.
- Downstream: Betrieb (`henemm-infra`: Compose-Umgebung, nginx-Freigabe `/auth/*`), #621 (`/mcp` mit `bearerToken`/`resolveSession`), S4 App.

## Existing Specs
- `docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md`, `docs/specs/feat-615-schnitt-3c1-konto-loeschen.md` (Folgeplan 3c-2)
- `docs/specs/feat-615-schnitt-2b1-jwks-cache.md` (Cache-Verhalten)

## Risks & Considerations
- Eine teilweise gesetzte Konfiguration darf den Dienst nicht still ohne Anmeldung laufen lassen → Start bricht ab (Plan).
- Abbruch beim Start darf den Wert eines Geheimnisses nicht ins Log schreiben (Meldung von `loadAppleConfig` ist wertfrei).
- Im Betrieb ist heute keine `APPLE_*` gesetzt → der Dienst muss weiter starten (Fall „keine gesetzt“).
- 1-MiB-Grenze im `bridge` gilt auch für `/mcp`; MCP-Anfragen sind klein, Grenze vorher prüfen.
- `log` darf nicht werfen: `console.error` auf geschlossenem stderr (EPIPE) kann werfen.
- Routennamen dürfen bestehende (`/health`, `/mcp`) nicht überschreiben; Reihenfolge der Spreizung beachten.
- „JWKS einmal beim Start“: eine Instanz je Prozess; Vorladen beim Start ist offen (Analyse).

## Analysis

### Type
Feature (Verdrahtung fertiger Bausteine, kein Bug)

### Research (2026-11-05)
- Apple rotiert die JWKS-Schlüssel ohne Ankündigung, mehrere sind gleichzeitig gültig; gängig ist Cache + Nachladen bei unbekanntem `kid` mit gebremstem Nachladen — genau `createJwks` (S2b-1). Keine offizielle TTL-Vorgabe von Apple gefunden.
  Quellen: https://developer.apple.com/forums/thread/133699, https://www.gravitee.io/jwks-rotation.html, https://docs.rs/crate/cheers-providers/latest/source/src/providers/apple/jwks_cache.rs
- Ein bloßer `node:http`-Server hat keine Körpergrenze (unser `buffered` liest ungebremst). Üblich: Express 100 KB, nginx `client_max_body_size` Standard 1 MB (unsere nginx-Datei setzt keinen Wert → 1 MB davor). 1 MiB im Dienst deckt sich damit.
  Quellen: https://betterstack.com/community/questions/default-nginx-client-max-body-size-value/, https://fast.io/resources/express-body-parser-limit/

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/main.ts` | MODIFY | neue Option `auth?: { config?: AppleConfig; fetch?: typeof fetch }`; `gated` (503 vor migrate, auch für `/mcp`); Spreizung `{ ...auth, ...extraRoutes, "/health", "/mcp" }`; eine `createJwks`-Instanz je `start()`, nur mit `config`; `logError` mit try/catch (wirft nie) als `log`; `buffered` zählt bis 1 MiB, darüber 413 ohne Körper + `connection: close`; `appleConfigFromEnv(env)` (0 gesetzt → undefined, sonst `loadAppleConfig`), in `main()` vor `start()`, Fehler nur mit der wertfreien Meldung, Exit 1 |
| `server/test/main.test.ts` | MODIFY (nur neue Tests) | 503 vor migrate, logout/delete ohne Config, apple 503 ohne Config, Weiche 0/teilweise/ungültig (Name im Log, Wert nicht), 413 bei > 1 MiB und bei lügender Content-Length, `/health`/`/mcp` nicht überschreibbar, werfendes `console.error` bricht nichts, Exit-Pfad per Kindprozess (Muster `spawnSync` aus `migrate.test.ts`) |
| `CLAUDE.md` | MODIFY | Zeilen „nothing calls … yet“ (471–477) und die `main.ts`-Zeile: eingehängt, Weiche, 1 MiB |

### Scope Assessment
- Files: 3 (+ docs)
- Estimated LoC: Code ≈ +70, Tests ≈ +120–140, CLAUDE.md ≈ ±10 → ≈ 200–220
- Risk Level: LOW–MEDIUM — zentrale Datei `main.ts`, aber nginx lässt `/auth/*` noch nicht durch; im Betrieb ohne `APPLE_*` startet der Dienst wie heute

### Technical Approach
Empfehlung (Plan-Agent, Befunde nachgeprüft):
- **`extraRoutes` bleibt** (Abweichung vom Folgeplan 3c-1): `main.test.ts` Z. 177 (`/boom`) und Z. 212 (`/leak`) sowie `auth.test.ts` Z. 543 nutzen es als Test-Naht; bestehende Tests werden nicht geändert. Ohne `auth`-Option hängt `start()` keine Auth-Routen ein → alle bisherigen Tests unverändert; `main()` übergibt `auth` immer.
- **Umgebung nur in `main()`** lesen (wie `DATABASE_URL`); `start()` bleibt frei davon. Abbruch vor dem Listen und vor dem Pool.
- **Weiche:** nur Leerzeichen = nicht gesetzt (wie `required`). Keine gesetzt → `/auth/apple` 503, `/auth/logout`/`/auth/delete` laufen (brauchen keine Config).
- **JWKS lazy, eine Instanz je Prozess** (Präzisierung von „einmal beim Start“): Vorladen bringt nichts; ein fehlgeschlagener Vorab-Abruf belegte die 60-s-Sperre, und der erste echte Login bekäme `keys_unavailable`.
- **413 im `bridge`** läuft an `dispatch` vorbei, zählt also nicht ins Fehlerfenster (Client-Fehler, kippt `/health` nicht).
- Funktionen ≤ 50 Zeilen: Zusatzlogik in Hilfsfunktionen (`gated`, `mountAuth`), `start()` wächst kaum.

### Alternatives (verworfen)
- `start()` liest die Umgebung selbst: Abbruch per `start()` testbar, aber der Pool ist dann schon offen und muss geschlossen werden.
- Körpergrenze nur in den Routen: das ungebremste Puffern in `buffered` bliebe (Speicher), widerspricht dem Plan.
- JWKS beim Start vorladen: Nachteil ohne Nutzen (siehe oben).
- `extraRoutes` ersetzen (Folgeplan): würde bestehende Tests ändern.

### Dependencies
- Upstream: `auth.ts`, `apple.ts`, `apple-jwks.ts` — alle unverändert.
- Downstream: nginx-Freigabe `/auth/*` in `henemm-infra` (nicht dieser Schnitt, mit S4/#621), `APPLE_*` in der Compose-Umgebung (später), #621.

### Open Questions
- keine PO-Fragen (rein technisch, nichts Sichtbares; die Abweichung bei `extraRoutes` ist eine Tech-Lead-Entscheidung)

## Freigabe Zeilengrenze (2026-11-05, nach RED)

Tests 380 Zeilen statt geschätzt 120–140, Schnitt gesamt ≈ 470 statt ≈ 210 (Grenze 250). Henning per Auswahl: „Annehmen, so bauen“.

## Abweichungen der Tests von den AC-Texten (Tech Lead, RED 2026-11-05)

- AC-6: „Pool nicht geöffnet“ wird mit einem eigenen TCP-Lauscher als Datenbankadresse belegt (0 Verbindungen), statt per `pg_stat_activity`; das ist auch nach dem Prozessende noch prüfbar.
- AC-8: Bei einer `Content-Length` unter der wahren Länge übergibt der HTTP-Parser der Route nur die angegebenen Bytes; der Rest wird nie als Body gepuffert. Der Test belegt „Route bekam ≤ 1 MiB“ und `/health` 200, nicht „Route läuft nicht“ (das ist dort nicht erreichbar).
- AC-9: Das Fehlerfenster zählt nur 5xx; 404 kippt `/health` nicht. Belegt wird: 413 erhöht `requests` nicht (läuft an `dispatch` vorbei); Gegenprobe mit 25 × 500 über `/boom`.
- AC-13/AC-14: `git diff`-Prüfungen laufen in /60-validate; der Doku-Teil von AC-14 ist der Test „einhaengen: grenze und doku“.
- Commit dieser Notiz kommt mit der Umsetzung (bash_gate blockt Commits in phase6).
