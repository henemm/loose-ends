# Context: feat-621-s2-ablage

## Request Summary
#621 Schnitt 2 (Plan in `docs/context/feat-621-mcp-anmeldung.md`, Schnittplan): die Ablage für den Anmeldeserver, den S3 mit
`oidc-provider` einbettet — Migration `004_oauth.sql`, ein Postgres-Adapter nach der Adapter-Schnittstelle von `oidc-provider`,
`deleteAccount` löscht die OAuth-Daten des Kontos mit, dazu der Merkposten „Sitzungsablauf“ aus #615. Geplant ~130 LoC Code.
Sichtbar ändert sich nichts; `/mcp` bleibt hinter `rejectAll` (S1) und öffentlich hinter nginx zu.

## Related Files
| File | Relevance |
|------|-----------|
| `server/migrations/001–003` | Muster: kein BEGIN/COMMIT (Runner wickelt), nur hinzufügen, Kommentar oben; `accounts.id` ist `text` (UUID als Text) |
| `server/src/accounts.ts` | `deleteAccount` (:43-68): eine Transaktion, `FOR UPDATE` auf das Konto, löscht `order_results`, `orders`, `transcripts`, `accounts`; `sessions`/`apple_tokens` per FK-Kaskade. Neue OAuth-Zeilen müssen hier mit weg. `resolveSession` (:24-31) ohne Ablauf |
| `server/src/oauth-resource.ts` | S1: `bearerGate`, `rejectAll` (:16) — in S3 wird der Verifizierer an `AccessToken` der Ablage gebunden; S2 fasst ihn nicht an |
| `server/src/main.ts` | `start()` mit `options.oauth` (:136); S2 hängt nichts ein (Einhängen ist S3) |
| `server/test/db.ts` | `freshPool(t)`: eigenes Schema je Test gegen echtes Postgres, kein Überspringen |
| `server/test/accounts.test.ts` | AC-7..10 zu `deleteAccount` (:129-189): Muster für „alle Zeilen weg, anderes Konto unberührt“ |
| `server/test/schema.test.ts` | Migrationstests (`migration 003: additiv auf bestandsdaten` :183) — Muster für 004 |
| `server/package.json` | `oidc-provider` ist noch **nicht** Abhängigkeit (kommt in S3); der Adapter ist eine Klasse ohne Import aus der Bibliothek |

## Adapter-Schnittstelle (Recherche 2026-11-05)
Quelle: `example/my_adapter.js` in panva/node-oidc-provider (https://github.com/panva/node-oidc-provider/blob/main/example/my_adapter.js),
`oidc-provider` 9.13.3 (npm, geändert 2026-10-29).
- `constructor(name)` — ein Adapter je Modell: Grant, Session, AccessToken, AuthorizationCode, RefreshToken, ClientCredentials, Client,
  InitialAccessToken, RegistrationAccessToken, DeviceCode, Interaction, ReplayDetection, BackchannelAuthenticationRequest,
  PreAuthorizedCode, PushedAuthorizationRequest.
- `upsert(id, payload, expiresIn)` — anlegen/ersetzen, `expiresIn` in Sekunden (Speicherlebensdauer).
- `find(id)` — Datensatz oder falsy, auch wenn abgelaufen.
- `findByUid(uid)` — Session über `uid`. `findByUserCode` nur für den Device-Flow (nicht genutzt).
- `consume(id)` — **atomar** nur, wenn noch nicht verbraucht, sonst **werfen** (Rückgabewert wird ignoriert); `find` liefert danach
  `consumed` truthy. Das ist der Schutz gegen doppeltes Einlösen eines Codes / Refresh-Tokens.
- `destroy(id)`, `revokeByGrantId(grantId)` — alle Datensätze eines Grants weg.
- ReplayDetection: `upsert` muss atomar nur einfügen, wenn kein unabgelaufener Eintrag existiert, sonst **werfen**.
- Payload-Felder: Tokens/Codes `accountId`, `clientId`, `grantId`, `sessionUid`, `exp`, `iat`, `aud`, `scope`…; Grant `accountId`, `resources`;
  Session `uid`, `accountId`; Interaction `returnTo`, `params`, `result`, `grantId`, `session.*`.

## Existing Patterns
- Dienst ohne Framework, Bausteine rein mit eingereichten Abhängigkeiten (Pool, Uhr), Tests ≈ 2,5× Code gegen Wegwerf-Postgres
  (`./server/scripts/test-local.sh`).
- Geheimnisse nie im Klartext (Sitzungen nur SHA-256, Apple-Token AES-GCM); keine Werte im Log.
- Schema nur über nummerierte Migrationen, nur hinzufügen.

## Dependencies
- Upstream: Postgres 18, `pg`; `accounts` (FK-Ziel für `account_id`).
- Downstream: S3 (`oidc-provider` mit `adapter: (name) => new PgAdapter(pool, name)`, `verifyToken` liest `AccessToken`),
  S4b (Interaction mit Apple-Zustand), `deleteAccount` / `POST /auth/delete`.

## Existing Specs
- `docs/specs/feat-621-schnitt-1-ressourcenseite.md` (S1), `docs/context/feat-621-mcp-anmeldung.md` (Schnittplan, Make-or-Buy A)
- `docs/specs/feat-615-schnitt-3a-datenschicht.md`, `…-3c1-konto-loeschen.md` (Merkposten Sitzungsablauf, `deleteAccount`)

## Risks & Considerations
- **Eine Tabelle oder je Modell eine?** Üblich ist eine Tabelle `(model, id)` mit `payload jsonb`, `grant_id`, `uid`, `account_id`,
  `expires_at`, `consumed_at`. Konto-Bezug: `payload.accountId` fehlt bei Interaction/ReplayDetection/Client; `deleteAccount` muss
  über `account_id`-Spalte (aus dem Payload gezogen) **und** über die Grants des Kontos löschen.
- **Geheimnisse in der Ablage:** `id` von AccessToken/RefreshToken/AuthorizationCode ist bei opaken Token das Geheimnis selbst
  (bzw. der Token-Wert). Projektregel „nie im Klartext“ → `id` gehasht ablegen (SHA-256) — prüfen, ob `find`/`destroy` dann noch passt
  (ja: Adapter hasht jede eingehende `id` gleich).
- **Ablauf:** `find` muss abgelaufene Zeilen verbergen; Aufräumen abgelaufener Zeilen (wann, wer) offen.
- **`consume` und ReplayDetection atomar mit Werfen** — Nebenläufigkeit mit Test belegen (zwei gleichzeitige `consume`).
- **Merkposten Sitzungsablauf:** Seit S1 nimmt `/mcp` keine App-Sitzung mehr an (`rejectAll`, später nur OAuth-Token). Der
  Merkposten betrifft damit nur noch die App-Sitzung aus #615 (`resolveSession` für `/auth/logout`, `/auth/delete`) und gehört
  eher zu #615 S4 (App) als zu #621 — Entscheidung in der Analyse; OAuth-Token laufen über `expiresIn` ohnehin ab.
- **Ohne Bibliothek gebaut:** Der Adapter wird gegen die dokumentierte Schnittstelle getestet, nicht gegen `oidc-provider` selbst;
  Abweichungen zeigt erst das Spike-Gate in S3.
- **Datenschutz (#625):** Payloads enthalten `accountId`, `clientId`, Scopes, keine Aufgabeninhalte; Apple-Token liegen weiter nur in
  `apple_tokens`.

## Analysis

### Type
Feature (Baustein ohne sichtbare Änderung; `/mcp` bleibt hinter `rejectAll`).

### Recherche-Befund (Quelle: panva/node-oidc-provider `lib/models/base_model.js`, `replay_detection.js`, `example/my_adapter.js`, 2026-11-05)
- `BaseModel.save` ruft `adapter.upsert(this.jti, payload, ttl)`; `IN_PAYLOAD` enthält `jti`, und bei opaken Token ist der Wert, den der
  Client bekommt, genau `jti`. **Der Payload trägt also das Token im Klartext.** Folge: `jti` wird vor dem Speichern entfernt und bei `find`
  als `{...payload, jti: id}` wieder eingesetzt (`instantiate` liest `jti` aus dem Rückgabeobjekt).
- `consume`: SHOULD atomar nur markieren, wenn noch nicht verbraucht, sonst werfen (Rückgabewert wird ignoriert).
- ReplayDetection: `unique()` macht `find` dann `save`; die Doku verlangt, dass `upsert` atomar nur einfügt, wenn kein unabgelaufener
  Eintrag existiert, sonst wirft.
- `find` darf Abgelaufenes verbergen; die Bibliothek prüft `exp` zusätzlich selbst.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| server/migrations/004_oauth.sql | CREATE | Tabelle `oauth_records` (PK `model, id_hash bytea`), `payload jsonb`, `grant_id`, `uid`, `account_id` (FK `accounts ON DELETE CASCADE`, nullable), `expires_at`, `consumed_at`; Indizes `grant_id`, `uid`, `account_id`, `expires_at` |
| server/src/oauth-adapter.ts | CREATE | `PgAdapter(pool, name, now)`: `upsert`, `find`, `findByUid`, `consume`, `destroy`, `revokeByGrantId`, `findByUserCode` (nicht unterstützt), Aufräumen abgelaufener Zeilen |
| server/src/accounts.ts | MODIFY | `deleteAccount` löscht vor dem Konto alle Zeilen der Grants des Kontos (ein Statement in der bestehenden Transaktion); Rest per Kaskade |
| server/test/oauth-adapter.test.ts | CREATE | Schnittstelle, Hash statt Klartext (auch kein `jti` im jsonb), Ablauf, zwei gleichzeitige `consume`, Replay atomar, Grant-Widerruf |
| server/test/accounts.test.ts, server/test/schema.test.ts | MODIFY | `deleteAccount` nimmt OAuth-Zeilen mit, fremdes Konto unberührt; Migration 004 additiv auf Bestandsdaten |

### Scope Assessment
- Files: 3 Code + 3 Tests
- Estimated LoC: ~+130 Code, ~+350–400 Tests
- Risk Level: MEDIUM — Sicherheitsbaustein (Einmal-Einlösen, Klartextfreiheit); sichtbar ändert sich nichts, kein Pfad der Geräteliste.

### Technical Approach
Eine Tabelle für alle Modelle (sie unterscheiden sich nur im Payload). Jede eingehende `id` wird mit SHA-256 gehasht; `jti` wird aus dem
gespeicherten Payload herausgelöst und bei `find` wieder eingesetzt. `account_id` aus `payload.accountId`, `grant_id` aus `payload.grantId`,
`uid` aus `payload.uid` (Session-`uid` bleibt Klartext, `findByUid` braucht sie; sie ist kein Zugangsnachweis).
`consume` = ein `UPDATE … WHERE consumed_at IS NULL AND expires_at > $now RETURNING`, 0 Zeilen → werfen. ReplayDetection-`upsert` =
`INSERT … ON CONFLICT DO UPDATE … WHERE expires_at <= $now RETURNING`, 0 Zeilen → werfen. `find` blendet Abgelaufenes aus und setzt
`consumed` aus `consumed_at`. Die Uhr wird eingereicht (Projektmuster, Zeitsprung im Test). Aufräumen: `DELETE … WHERE expires_at < $now`
opportunistisch bei `upsert`, höchstens alle 10 min je Prozess; kein Timer. `deleteAccount`: Zeilen der Grants des Kontos per Statement,
alles mit `account_id` per Kaskade; Interaction/ReplayDetection ohne Konto laufen ab; Client-Zeilen sind kontoübergreifend und bleiben.
Folge der FK: ein `upsert` mit `accountId` eines gelöschten Kontos wirft (23503) — gewollt, das Konto existiert nicht mehr.

**Sitzungsablauf (Merkposten #615):** nicht in S2. Er hing nur an #621, weil `/mcp` damals `resolveSession` nutzte; seit S1 nimmt `/mcp`
keine App-Sitzung mehr an. Er betrifft nur noch die App-Sitzung (`/auth/logout`, `/auth/delete`) und braucht eine Migration an `sessions`
samt Laufzeit-Festlegung → zurück an #615 S4 (Kommentar dort). OAuth-Token laufen über `expiresIn` ab.

### Alternativen
- **Ids im Klartext** wie in den Beispielen der Bibliothek: ~20 LoC weniger, einfacher zu untersuchen, aber ein Datenbank-Leck macht
  Refresh-Tokens direkt nutzbar; verstößt gegen „Geheimnisse nie im Klartext“ (ADR-Lage #615). Verworfen.
- **Je Modell eine Tabelle:** echte FKs je Art, aber 15 fast gleiche Tabellen und Adapterzweige. Verworfen.
- **Sitzungsablauf mitnehmen** (+~25 LoC, Migration 005): nur sinnvoll, wenn er vor der App (#615 S4) gebraucht würde; die App gibt
  bis S4 keine Sitzung aus. Verworfen.

### Dependencies
- Upstream: Postgres 18, `pg`, `accounts`.
- Downstream: S3 (`adapter: (name) => new PgAdapter(pool, name, now)`, Spike-Gate prüft den Adapter gegen die echte Bibliothek),
  S4b (Interaction), `deleteAccount` / `POST /auth/delete`.
- Risiko: getestet nur gegen die dokumentierte Schnittstelle; Abweichungen (z. B. `consumed`-Format) zeigt S3. `payload jsonb` hält
  Nacharbeit migrationsfrei.

### Open Questions
- keine (alles Technische; keine Produktfrage)
