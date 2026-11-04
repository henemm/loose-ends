---
entity_id: feat-615-schnitt-3b-anmelden-abmelden
type: feature
created: 2026-11-04
updated: 2026-11-04
status: draft
workflow: feat-615-s3b-anmelden-abmelden
---

# Spec: Anmelden und Abmelden als HTTP-Routen, Schnitt 3b (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 3b; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s3b-anmelden-abmelden.md` und `docs/context/feat-615-s3-http-rand.md`. Vorgänger: Schnitt 3a (`docs/specs/feat-615-schnitt-3a-datenschicht.md`, PR #826), der `aud`, Migration 003 und `storeRefreshToken(…, clientId)` geliefert hat.

## Für den PO

Dieser Schnitt baut im Dienst die zwei Türen, durch die sich die App später anmeldet und wieder abmeldet. Meldet sich jemand mit Apple an, prüft der Dienst den Nachweis von Apple, löst den mitgeschickten Einmalcode bei Apple ein, legt den dabei erhaltenen Schlüssel verschlüsselt ab und gibt der App erst ganz zum Schluss ein Sitzungs-Token. Geht unterwegs etwas schief, bleibt nichts zurück. Nach außen sagt der Dienst bei jeder Ablehnung nur „nicht angemeldet“, nie warum. Beim Abmelden endet genau diese eine Sitzung. In der App ändert sich nichts Sichtbares, und nichts ruft die Türen auf, bis die App-Seite (S4) kommt. Konto löschen und das Einhängen in den laufenden Dienst folgen in S3c.

## Purpose

`server/src/auth.ts` mit `authRoutes(deps)`, das eine Routentabelle `{ "/auth/apple", "/auth/logout" }` (Typ `Route` aus `main.ts`) liefert, und der Hilfsfunktion `bearerToken(request)`. Reine Zusammensetzung vorhandener Bausteine (`verifyIdentityToken`, `redeemCode`, `findOrCreate`, `encryptToken`, `storeRefreshToken`, `createSession`, `endSession`); `main.ts` bleibt unberührt, Tests hängen die Tabelle über `extraRoutes` ein. **Regeln vor Modell:** Protokoll- und Datenarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Quellen (Recherche 2026-11-04, aus der Analyse): Apple-Forum Threads 132214 und 118135 sowie die Apple-REST-Doku „Request an authorization to the Sign in with Apple server“ (Code einmalig, 5 Minuten gültig, ein zweites Einlösen gibt `invalid_grant`).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 und die Reihenfolge aus S2a bis 3a um; keine neue Abhängigkeit.
- **Rationale:** (1) Der Code wird immer eingelöst, sobald der Identity-Token gültig ist, auch wenn danach etwas scheitert (ein abgefangener Token verbrennt so den Code). (2) `createSession` kommt zuletzt, damit kein Fehler eine Sitzung ohne abgelegten Schlüssel hinterlässt. (3) Gründe nach außen einheitlich 401, nur Apple nicht erreichbar gibt 503; so verrät die Antwort nicht, welche Prüfung scheiterte. (4) Abmelden ist idempotent (204 auch bei unbekannter Sitzung), damit kein Rückschluss darauf möglich ist, ob ein Token je gültig war.

## Source

**Files:** `server/src/auth.ts` (neu), `server/test/auth.test.ts` (neu), `CLAUDE.md`
**Identifier:** `authRoutes`, `bearerToken`, `AuthDeps`

### Schnittstelle

- `AuthDeps = { pool: pg.Pool; config?: AppleConfig; keys?: KeyLookup; fetch: typeof fetch; now: () => number }`.
- `authRoutes(deps): Record<string, Route>` mit den Schlüsseln `/auth/apple` und `/auth/logout`.
- `bearerToken(request): string | null`: Wert hinter `Bearer ` (Schema ohne Rücksicht auf Groß-/Kleinschreibung) aus `Authorization`, sonst `null` (fehlend, anderes Schema, leer, mehr als ein Token).
- **`POST /auth/apple`**, Prüfreihenfolge, die erste Verletzung antwortet (alle Antworten ohne Body außer 200):
  1. fehlt `config` oder `keys` → 503
  2. Methode ≠ POST → 405 (mit `Allow: POST`)
  3. `Content-Type` nicht `application/json` (Parameter wie `charset` erlaubt) → 415
  4. Body über 16 KiB (beim Lesen gezählt, nicht nur `Content-Length`) → 413
  5. kein JSON-Objekt oder eines der Felder `identityToken`, `nonce`, `code` kein nicht-leerer Text → 400
  6. `verifyIdentityToken(identityToken, nonce, { config, keys, now: now() })`: `keys_unavailable` → 503, jeder andere Fehlgrund → 401
  7. `redeemCode(code, aud, { config, fetch, now })` (immer, sobald 6 ok): `unavailable` → 503, jeder andere Fehlgrund → 401
  8. `redeemed.sub !== verdict.sub` → 401, nichts abgelegt
  9. `findOrCreate(pool, sub)`, `encryptToken(config.tokenKey, accountId, refreshToken)`, `storeRefreshToken(pool, accountId, blob, aud)`; `false` (Konto zwischenzeitlich gelöscht) → 401
  10. `createSession` zuletzt → 200, `Content-Type: application/json`, Body `{"sessionToken": "<token>"}`, `Cache-Control: no-store`
- **`POST /auth/logout`**: Methode ≠ POST → 405; kein Bearer-Token → 401; sonst `endSession(pool, token)` → 204, **auch wenn es die Sitzung nicht gab**. Beendet genau diese eine Sitzung, nie andere des Kontos. Braucht weder `config` noch `keys`.
- Eine Ausnahme in einer Route (z. B. Datenbankfehler, `redeemCode` wirft bei Fehlbedienung) wird nicht gefangen: `dispatch` in `main.ts` macht daraus 500 ohne Body.

### Festlegungen

- **Stille:** kein `console` in `auth.ts`; weder Identity-Token, Nonce, Code, Refresh-Token, Sitzungs-Token, `sub` noch `aud` stehen in Logzeilen oder Fehlertexten. Es gibt keine Log-Ausgabe in diesem Schnitt (Gründe bleiben intern).
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; keine neuen Pakete.
- **Unberührt:** `main.ts`, `mcp.ts`, alle bestehenden `src/`-Dateien, `.github/`, `project.yml`, jede Swift-Datei, Migrationen.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `verifyIdentityToken`, `AppleConfig`, `KeyLookup` (`apple.ts`) | bestehend, unverändert |
| `redeemCode` (`apple-client.ts`) | bestehend, unverändert |
| `encryptToken`, `storeRefreshToken` (`apple-vault.ts`) | bestehend, unverändert |
| `findOrCreate`, `createSession`, `endSession` (`accounts.ts`) | bestehend, unverändert |
| `Route` (`main.ts`), `extraRoutes` | bestehend, nur genutzt |
| `pg`, `node:test`, `node:crypto` | bestehend, **keine neuen Pakete** |
| Downstream | S3c (`/auth/delete`, Verdrahtung, Body-Grenze, Start-Konfiguration), #621 (`bearerToken`), S4 (App) |

## Acceptance Criteria

Alle Tests mit `node:test` und `node:assert/strict`; Datenbank gegen das Wegwerf-Postgres aus `server/test/db.ts`; Apple wird durch ein selbst erzeugtes Schlüsselpaar und ein injiziertes `fetch` ersetzt (kein Netz). Ablehnungsfälle tabellengetrieben, ein Fall je Zeile.

- **AC-1:** Rundweg Anmelden: Mit gültigem, selbst signiertem Identity-Token (Nonce passt), von der gefälschten Apple-Antwort eingelöstem Code und gleichem `sub` antwortet `POST /auth/apple` mit 200 und `{ sessionToken }` (Text, nicht leer, `Cache-Control: no-store`). Danach gilt: `resolveSession(sessionToken)` ergibt das Konto zum `sub`; `deleteAccount` auf dieses Konto liefert den entschlüsselbaren Refresh-Token der Apple-Antwort und als `clientId` die geprüfte `aud` (bei zwei konfigurierten Client-IDs die zweite, wenn der Token für die zweite ausgestellt war). Test: „auth: rundweg anmelden“.
- **AC-2:** Zweite Anmeldung desselben `sub`: gleiches Konto, neue Sitzung, abgelegter Schlüssel und `client_id` ersetzt; es bleibt eine Zeile in `apple_tokens` und eine Zeile in `accounts`. Test: „auth: zweite anmeldung ersetzt schluessel“.
- **AC-3:** Eingabe-Ablehnungen tabellengetrieben: falsche Methode (GET, PUT, DELETE) 405; `text/plain`, fehlender Content-Type 415; Body 16 KiB + 1 Byte (mit und ohne passenden `Content-Length`) 413; Body kein JSON, JSON-Array, `null`, Feld fehlt, leer, Zahl, Objekt je Feld 400. Bei **jedem** dieser Fälle gilt: kein Aufruf des gefälschten Apple-`fetch`, keine Zeile in `accounts`, `sessions`, `apple_tokens`. Test: „auth: eingabe abgelehnt, nichts angefasst“.
- **AC-4:** Identity-Token-Ablehnungen: abgelaufener, falsch signierter, falsches `aud`, falsche Nonce, `alg: none`, kaputt aufgebauter Token ergeben 401 **ohne Body und ohne Text, der den Grund verrät**; es wird **kein** Code eingelöst (`fetch` nicht aufgerufen) und nichts abgelegt. `keys` meldet `keys_unavailable` → 503, ebenfalls ohne Einlösen. Test: „auth: identity-token abgelehnt“.
- **AC-5:** Code-Ablehnungen: Apple antwortet `invalid_grant`, `invalid_client`, anderer Fehler, kaputter Body → 401; Netz- oder Zeitfehler (`unavailable`) → 503; in allen Fällen wurde der Code **genau einmal** eingelöst, keine Zeile in `accounts`, `sessions`, `apple_tokens`. Test: „auth: einloesen scheitert, nichts abgelegt“.
- **AC-6:** `sub`-Abweichung: liefert die Einlösung ein anderes `sub` als der Identity-Token, ist die Antwort 401, der Code wurde eingelöst, nichts abgelegt, keine Sitzung. Test: „auth: sub weicht ab“.
- **AC-7:** Keine verwaiste Sitzung: Wird das Konto zwischen `findOrCreate` und `storeRefreshToken` gelöscht (Test reicht als `deps.pool` einen `Proxy` um den echten Pool herein, dessen `query` bei der ersten Anweisung auf `apple_tokens` zuerst das Konto löscht bzw. in der zweiten Variante einen Fehler wirft; `AuthDeps` bekommt dafür keinen Hook) und liefert `storeRefreshToken` damit `false`, ist die Antwort 401 und es existiert keine Sitzung; wirft das Ablegen (Datenbankfehler), ist die Antwort 500 über `dispatch` und es existiert ebenfalls keine Sitzung. Test: „auth: createSession zuletzt“.
- **AC-8:** Fehlt `config` oder `keys` in `AuthDeps`, antwortet `/auth/apple` 503 vor jeder Eingabeprüfung außer der Routenwahl, `/auth/logout` funktioniert weiter (204 mit gültigem Bearer-Token). Test: „auth: ohne apple-konfiguration“.
- **AC-9:** Abmelden: gültiger Bearer-Token → 204 und genau diese Sitzung ist beendet (`resolveSession` danach `null`), eine zweite Sitzung desselben Kontos und die eines anderen Kontos gelten weiter; unbekannter, schon beendeter und fremder Token → 204 ohne Wirkung auf andere; fehlender Header, anderes Schema (`Basic`), leerer Wert, zwei Token → 401; falsche Methode → 405. Test: „auth: abmelden“ (Fallliste).
- **AC-10:** `bearerToken`: tabellengetrieben für `Bearer abc`, `bearer abc`, `BEARER abc` (→ `abc`), fehlend, `Basic abc`, `Bearer`, `Bearer ` , `Bearer a b`, `Bearer  abc` mit zwei Leerzeichen (→ `null`). Test: „auth: bearerToken“.
- **AC-11:** Stille und Einheitlichkeit: Während der Tests aus AC-1 bis AC-9 schreibt `auth.ts` weder auf `console` noch `process.stdout`/`stderr` (Test fängt beide ab), und alle 401-Antworten sind in Status, Headern und Body gleich. `grep -nE "console|process\.(stdout|stderr)" server/src/auth.ts` hat keinen Treffer. Test: „auth: stille und einheitliche ablehnung“.
- **AC-12:** Regression, Länge, Grenze: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` auf dem PR ist grün, kein bestehender Testfall wird geändert oder gelöscht, jede Funktion in `auth.ts` hat höchstens 50 Zeilen, und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/auth.ts`, `server/test/auth.test.ts` und `CLAUDE.md`. Die Zeile zu `src/auth.ts` im Abschnitt `server/` von `CLAUDE.md` nennt beide Routen, die Reihenfolge, „createSession zuletzt“ und dass nichts sie aufruft.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/auth.ts` | CREATE | `authRoutes`, `bearerToken`, Body-Lesen mit 16-KiB-Grenze, ≈ 85 |
| `server/test/auth.test.ts` | CREATE | Schlüsselpaar, gefälschtes Apple-`fetch`, Rundwege und Fallisten, ≈ 230 |
| `CLAUDE.md` | MODIFY | eine Zeile im Abschnitt `server/`, ≈ +2 |

### Estimated Changes

- **Files: 3** (Spec und Kontext zählen nicht). **LoC ≈ 320** (Code ≈ 85, Tests ≈ 230, Doku ≈ 2) und damit **über dem Limit von ±250**. Der Überhang kommt allein aus Sicherheitstests (Tests ≈ 2,5× Code, wie bei S2). Zerlegung wäre möglich (Anmelden ≈ 60 + 150 Test, Abmelden ≈ 25 + 60 Test), doppelt aber Testaufbau und Antwortformen. Die Entscheidung über den Überhang trifft der PO mit der Freigabe.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, keine Migration, kein `generate`. Seiteneffekt außerhalb des Tickets: keiner, nichts ruft die Routen auf.

## Risiken

- **Verbrannter Code bei späterem Fehler:** Der Code wird eingelöst, bevor `sub` und Ablage geprüft sind; scheitert danach etwas, muss die App einen neuen Anmeldeversuch (neuer Code) machen. Gewollt (Replay-Schutz), in AC-5/AC-6 belegt.
- **Verwaiste Sitzung oder Konto:** Reihenfolge mit `createSession` zuletzt (AC-7). Ein neu angelegtes Konto ohne Sitzung nach einem Fehler bleibt als leeres Konto zurück; harmlos, die nächste Anmeldung nutzt es wieder (AC-2).
- **Information durch Fehlerbilder:** einheitlich 401 (AC-4/5/6/11); 503 verrät nur „Apple nicht erreichbar“.
- **Große oder gestreute Bodys:** 16 KiB beim Lesen gezählt (AC-3); die allgemeine 1-MiB-Grenze am Rand folgt in S3c.
- **Mehrfachanmeldungen und Drosselung:** keine Zählung im Prozess; Drosselung ist `limit_req` im nginx-Host (Infra), nicht Teil dieses Schnitts.
- **Tests fälschen Apple zu gut:** Sie prüfen die Verkettung, nicht Apples echtes Verhalten; echtes Verhalten bleibt S4/Geräteabnahme.

## Test Plan

### Automated Tests (TDD RED)

RED: `auth.ts` existiert nicht, alle Tests schlagen beim Import fehl.

- [ ] Test 1 (AC-1, AC-2): GIVEN signierter Token, gefälschtes Apple, echtes Postgres WHEN zweimal `POST /auth/apple` THEN 200 mit Sitzung, Konto, abgelegter Schlüssel und `aud` stimmen.
- [ ] Test 2 (AC-3 bis AC-6): GIVEN die Ablehnungstabellen WHEN Anfrage THEN erwarteter Status, `fetch`-Zähler und leere Tabellen wie beschrieben.
- [ ] Test 3 (AC-7, AC-8): GIVEN Pool-Hülle bzw. fehlende Konfiguration WHEN Anmelden THEN keine Sitzung, 401/500/503.
- [ ] Test 4 (AC-9, AC-10): GIVEN mehrere Sitzungen WHEN Abmelden bzw. `bearerToken` THEN nur die eine Sitzung endet, Fallliste stimmt.
- [ ] Test 5 (AC-11, AC-12): GIVEN die Gesamtläufe WHEN `./server/scripts/test-local.sh`, `grep`, `git diff` THEN grün, kein Treffer, genau drei Dateien.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): ein Schnitt mit beiden Routen.** Gemeinsame Bearer-Funktion und Antwortformen, ein Testaufbau.
- **B: Anmelden und Abmelden getrennt** (≈ 60 + 40 Code): hält jeden Schnitt unter 250 LoC, doppelt aber den Testaufbau; kippt keine ADR. Verworfen, solange der PO den Überhang freigibt.
- **C: Abmelden mit 401 bei unbekannter Sitzung:** verrät, ob ein Token je gültig war; verworfen zugunsten von 204.
- **D: Anmelden ohne sofortiges Einlösen, Code später einlösen:** der Code läuft nach 5 Minuten ab und der Replay-Schutz entfällt; verworfen.
- Befunde gegen den Plan: keine blockierenden.

## Nicht in diesem Schnitt / Folgeschnitte

- S3c: `POST /auth/delete` (Sitzung auflösen, `deleteAccount`, danach Widerruf, der das Löschen nie blockiert), `authRoutes` in `main()` einhängen, `APPLE_*`-Konfiguration und JWKS beim Start, 1-MiB-Grenze im `bridge`.
- #621: `/mcp` nutzt `bearerToken` und `resolveSession`; Sitzungsablauf ist Merkposten dorthin.
- S4 App (nach #625).

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: `./server/scripts/test-local.sh` grün und `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `src/auth.ts`
- [ ] #615 kommentiert (Stand Schnitt 3b, Folge S3c), Board-Karte aktuell

## Changelog

- 2026-11-04: Initial spec created (Schnitt 3b)
