---
entity_id: feat-615-schnitt-3c1-konto-loeschen
type: feature
created: 2026-11-05
updated: 2026-11-05
status: draft
workflow: feat-615-s3c-konto-loeschen
---

# Spec: Konto löschen als HTTP-Route, Schnitt 3c-1 (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 3c-1; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s3c-konto-loeschen.md` (Entscheidungen 1–7). Vorgänger: Schnitt 3b (`docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md`) mit `authRoutes`, `bearerToken`, und Schnitt 3a (`docs/specs/feat-615-schnitt-3a-datenschicht.md`, Abschnitt „Für S3b/S3c festgehalten“), der `deleteAccount` mit `appleToken` und `clientId` geliefert hat.

## Für den PO

Dieser Schnitt baut im Dienst die dritte Tür: „Konto löschen“. Wer löscht, ist angemeldet; der Dienst löscht sein Konto samt Sitzungen, Aufträgen, Abschrift und dem bei Apple abgelegten Schlüssel, und teilt Apple danach mit, dass dieser Schlüssel nicht mehr gilt (Apple verlangt das bei jeder Kontolöschung). Apple nicht erreichbar oder nicht eingerichtet hält das Löschen nie auf: das Konto ist weg, die Antwort heißt „erledigt“, und der Dienst vermerkt intern nur, dass der Widerruf nicht gelang. In der App ändert sich nichts Sichtbares, und nichts ruft die Tür auf, bis die App-Seite (S4) kommt. Das Einhängen in den laufenden Dienst folgt in 3c-2.

## Purpose

`server/src/auth.ts` erhält die Route `/auth/delete` in `authRoutes(deps)` und das Feld `AuthDeps.log?: (event: string) => void` (Vorgabe stumm). Reine Zusammensetzung vorhandener Bausteine (`bearerToken`, `resolveSession`, `deleteAccount`, `decryptToken`, `revokeToken`); `accounts.ts`, `apple-vault.ts`, `apple-client.ts` und `main.ts` bleiben unberührt. **Regeln vor Modell:** Protokoll- und Datenarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Quelle (Recherche 2026-11-05, aus der Analyse): Apple TN3194 „Handling account deletions and revoking tokens for Sign in with Apple“ (Widerruf bei Kontolöschung Pflicht, `client_id` muss der beim Anmelden entsprechen; fehlt ein Token, wird trotzdem gelöscht).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 und die Reihenfolge aus Spec 3a um; keine neue Abhängigkeit.
- **Rationale:** (1) Der Widerruf läuft synchron nach dem Commit der Löschung und vor der Antwort: das Konto ist dann schon weg, Apples 5-s-Limit verlängert höchstens die Antwort, und der Ablauf ist deterministisch testbar (ein Widerruf im Hintergrund ginge bei SIGTERM verloren). (2) Löschen braucht keine Apple-Konfiguration: Löschen ist ein Recht des Nutzers und hängt an nichts (TN3194); das weicht gewollt von `/auth/apple` (503 ohne `config`) ab. (3) Die Logzeile kommt über `AuthDeps.log`, nicht über `console`, damit S3b-AC-11 („`auth.ts` schreibt nie auf `console`“) wahr bleibt. (4) Keine Wiederholungstabelle für offene Widerrufe: sie müsste das Apple-Token nach der Löschung weiter aufbewahren und widerspräche der Löschung selbst; Best Effort mit Logzeile ist die Vorgabe aus Spec 3a.

## Source

**Files:** `server/src/auth.ts` (ändern), `server/test/auth.test.ts` (ändern), `CLAUDE.md`
**Identifier:** `authRoutes`, `AuthDeps.log`, `deleteAccountRoute`, `revokeAfterDelete`

### Schnittstelle

- `AuthDeps = { pool: pg.Pool; config?: AppleConfig; keys?: KeyLookup; fetch: typeof fetch; now: () => number; log?: (event: string) => void }`; ohne `log` passiert nichts.
- `authRoutes(deps)` liefert zusätzlich den Schlüssel `/auth/delete`.
- **`POST /auth/delete`**, Prüfreihenfolge, die erste Verletzung antwortet (alle Antworten ohne Body):
  1. Methode ≠ POST → 405 (mit `Allow: POST`)
  2. `bearerToken(request)` ist `null` → 401
  3. `resolveSession(pool, token)` ist `null` → 401
  4. `deleteAccount(pool, accountId)`: `deleted === false` (Rennen mit einer zweiten Löschung) → 401, kein Widerruf
  5. `revokeAfterDelete(deps, accountId, deletion)` (kann nie die Antwort ändern)
  6. → 204
- **`revokeAfterDelete`**: Widerruf nur, wenn `config` gesetzt ist, `appleToken` nicht `null`, `clientId` nicht `null` und in `config.clientIds` enthalten ist (sonst würfe `clientSecret` nach dem Commit, F001) und `decryptToken(config.tokenKey, accountId, appleToken)` nicht leeren Text liefert; sonst `log("apple revoke skipped")`. Dann `revokeToken(token, clientId, { config, fetch, now })` genau einmal; `ok: false` → `log("apple revoke failed")`, `ok: true` → keine Logzeile.
- Der Body der Anfrage wird nicht gelesen. Braucht weder `keys` noch `config` (siehe ADR).
- Eine Ausnahme in der Route (z. B. Datenbankfehler) wird nicht gefangen: `dispatch` in `main.ts` macht daraus 500 ohne Body.

### Festlegungen

- **Stille:** kein `console` und kein `process.stdout`/`stderr` in `auth.ts`. Es gibt genau zwei feste Ereigniswörter, `apple revoke skipped` und `apple revoke failed`; weder Token, Sitzungstoken, Konto-ID, `sub`, `client_id` noch Apple-Text stehen in Logzeilen.
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; keine neuen Pakete.
- **Unberührt:** `main.ts`, `mcp.ts`, `accounts.ts`, `apple.ts`, `apple-vault.ts`, `apple-client.ts`, alle anderen `src/`-Dateien, `.github/`, `project.yml`, jede Swift-Datei, Migrationen.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `resolveSession`, `deleteAccount`, `Deletion` (`accounts.ts`) | bestehend, unverändert |
| `decryptToken` (`apple-vault.ts`) | bestehend, unverändert |
| `revokeToken` (`apple-client.ts`) | bestehend, unverändert |
| `bearerToken`, `status`, `notAllowed` (`auth.ts`) | bestehend aus 3b, genutzt |
| `pg`, `node:test`, `node:crypto` | bestehend, **keine neuen Pakete** |
| Downstream | 3c-2 (Verdrahtung in `start()`/`main()`, `log` hereinreichen), #621 (`/mcp`), S4 (App, Einstellungen „Konto löschen“, nach #625) |

## Acceptance Criteria

Alle Tests mit `node:test` und `node:assert/strict` in `server/test/auth.test.ts`, auf dem Testaufbau aus S3b; Datenbank gegen das Wegwerf-Postgres aus `server/test/db.ts`; Apple wird durch das selbst erzeugte Schlüsselpaar und ein injiziertes `fetch` ersetzt (kein Netz). Ablehnungsfälle tabellengetrieben, ein Fall je Zeile. Das gefälschte `fetch` zählt Aufrufe je Adresse.

- **AC-1:** Rundweg Löschen: Nach einer Anmeldung (AC-1 aus S3b) antwortet `POST /auth/delete` mit gültigem Bearer-Token mit 204 und ohne Body. Danach sind alle Tabellen des Kontos leer (`accounts`, `sessions`, `apple_tokens` sowie Abschrift und Aufträge des Kontos), und `resolveSession` mit dem alten Sitzungstoken ergibt `null`. Test: „auth: rundweg loeschen“.
- **AC-2:** Widerruf im Rundweg: Apple bekommt genau einen Aufruf auf `/auth/revoke`, mit dem entschlüsselten Refresh-Token der Anmeldung und der beim Anmelden gespeicherten `client_id` (bei zwei konfigurierten Client-IDs die, für die der Token ausgestellt war). Der Aufruf geschieht synchron: Er ist beim Eintreffen der 204 bereits erfolgt, und zu diesem Zeitpunkt ist das Konto schon gelöscht. Es erscheint keine Logzeile. Test: „auth: loeschen widerruft einmal“.
- **AC-3:** Anderes Konto unberührt: Ein zweites angemeldetes Konto behält Konto-Zeile, `apple_tokens`-Zeile, Sitzung und Daten, und seine Sitzung gilt weiter; eine zweite Sitzung desselben, gelöschten Kontos gilt nach dem Löschen nicht mehr. Test: „auth: loeschen beruehrt kein anderes konto“.
- **AC-4:** Eingabe-Ablehnungen tabellengetrieben: falsche Methode (GET, PUT, DELETE) → 405 mit `Allow: POST`; fehlender Header, anderes Schema (`Basic`), leerer Wert, zwei Token → 401; unbekannter, schon beendeter und fremd erfundener Sitzungstoken → 401. Bei **jedem** dieser Fälle gilt: nichts gelöscht (alle Tabellen unverändert), kein Aufruf des gefälschten Apple-`fetch`, keine Logzeile, Antwort ohne Body. Test: „auth: loeschen abgelehnt, nichts angefasst“.
- **AC-5:** Rennen: Verliert die Sitzung zwischen `resolveSession` und `deleteAccount` ihr Konto (Test reicht als `deps.pool` einen `Proxy` um den echten Pool herein, dessen `query` bei der ersten Anweisung der Löschung zuerst das Konto löscht; `AuthDeps` bekommt dafür keinen Hook), liefert `deleteAccount` `deleted: false`: Antwort 401, kein Aufruf von `/auth/revoke`, keine Logzeile. Test: „auth: loeschen rennen“.
- **AC-6:** Zwei gleichzeitige Löschungen derselben Sitzung (`Promise.all`) ergeben genau eine 204 und genau eine 401, das Konto ist weg und es gibt genau einen Aufruf auf `/auth/revoke`. Test: „auth: zwei loeschungen gleichzeitig“.
- **AC-7:** Widerruf scheitert nie das Löschen: Netz weg (`fetch` wirft), Apple antwortet 400 `invalid_grant`, Zeitüberschreitung (`fetch` bricht auf das Signal ab bzw. bleibt hängen, bis `revokeToken` das Limit meldet) → jeweils 204, Konto und Sitzung weg, **genau eine** Logzeile `apple revoke failed`, keine `apple revoke skipped`. Test: „auth: widerruf scheitert, konto weg“.
- **AC-8:** Widerruf entfällt: Fall (a) `deps.config` fehlt, Fall (b) `client_id` des Kontos ist `null` (Zeile aus der Zeit vor Migration 003, Test setzt die Spalte vor dem Löschen auf `NULL`), Fall (c) der abgelegte Blob ist mit einem anderen `tokenKey` verschlüsselt und damit unlesbar, Fall (d) das Konto hat keine `apple_tokens`-Zeile (Test löscht sie vor dem Löschen), Fall (e) die gespeicherte `client_id` steht nicht (mehr) in `config.clientIds` (Kennung rotiert oder entfernt; Test löscht mit einer `config`, deren `clientIds` sie nicht enthält). Jeweils: 204, Konto weg, **kein** Aufruf von `/auth/revoke`, genau eine Logzeile `apple revoke skipped`. Fall (a) läuft zusätzlich mit `keys` undefiniert und belegt, dass Löschen weder `config` noch `keys` braucht. Test: „auth: widerruf entfaellt, konto weg“.
- **AC-9:** Log-Schnittstelle: `AuthDeps.log` ist optional und hat den Typ `(event: string) => void`; ohne `log` laufen alle Löschfälle aus AC-7 und AC-8 ohne Fehler und ohne Ausgabe. Die gesammelten Logzeilen sind ausschließlich `apple revoke skipped` oder `apple revoke failed`, und keine enthält Refresh-Token, Sitzungstoken, Konto-ID, `sub`, `client_id` oder den Text einer Apple-Antwort (Test prüft gegen alle diese Werte der Läufe). Test: „auth: log ohne geheimnisse“.
- **AC-10:** Stille bleibt: Während der Tests aus AC-1 bis AC-9 schreibt `auth.ts` weder auf `console` noch `process.stdout`/`stderr` (Test fängt beide ab, wie S3b-AC-11), und alle 401-Antworten der Löschroute sind in Status, Headern und Body gleich. `grep -nE "console|process\.(stdout|stderr)" server/src/auth.ts` hat keinen Treffer. Test: „auth: stille und einheitliche ablehnung loeschen“.
- **AC-11:** Ausnahmen werden nicht gefangen: Wirft die Datenbank in `deleteAccount` (Pool-`Proxy` wie AC-5), ist die Antwort über `dispatch` 500 ohne Body, und es erscheint keine Logzeile `apple revoke failed`/`skipped`. Test: „auth: loeschen datenbankfehler“.
- **AC-12:** Regression, Länge, Grenze: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, kein bestehender Testfall wird geändert oder gelöscht (alle S3b-Tests bleiben grün), `accounts.ts`, `apple-vault.ts` und `apple-client.ts` sind unverändert, jede Funktion in `auth.ts` hat höchstens 50 Zeilen, und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/auth.ts`, `server/test/auth.test.ts` und `CLAUDE.md`. Die Zeile zu `src/auth.ts` im Abschnitt `server/` von `CLAUDE.md` nennt zusätzlich `POST /auth/delete`, die Reihenfolge (Sitzung, Löschen, danach Widerruf), dass Löschen ohne Apple-Konfiguration läuft, das optionale `log` und dass nichts die Route aufruft.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/auth.ts` | MODIFY | `deleteAccountRoute`, `revokeAfterDelete`, `AuthDeps.log?`, Route `/auth/delete`, ≈ +30 / −2 |
| `server/test/auth.test.ts` | MODIFY | Löschfälle (Rundweg, Widerruf, Rennen, Ablehnungen, Logzeilen), ≈ +110 |
| `CLAUDE.md` | MODIFY | die Zeile zu `src/auth.ts` im Abschnitt `server/` ergänzen, ≈ +5 |

### Estimated Changes

- **Files: 3** (Spec und Kontext zählen nicht). **LoC ≈ +145 / −2** (Code ≈ 30, Tests ≈ 110, Doku ≈ 5) und damit innerhalb des Limits von ±250.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, keine Migration, kein `generate`. Seiteneffekt außerhalb des Tickets: keiner, nichts ruft die Route auf, solange sie nicht eingehängt ist (3c-2); öffentlich erst mit 3c-2 und der nginx-Freigabe im Infra-Repo.

## Risiken

- **Löschen darf nie an Apple hängen:** jede Widerrufspanne (Netz, 400, Zeitüberschreitung, fehlende Konfiguration, unlesbarer Blob) endet in 204 (AC-7, AC-8). Die Antwort kann bis zu Apples 5-s-Limit länger dauern; das Konto ist da schon gelöscht.
- **Widerruf geht verloren:** bei Fehlschlag gibt es keine Wiederholung (ADR-Punkt 4); der Nutzer kann den Zugriff in den Apple-Einstellungen selbst widerrufen. Bewusst hingenommen, Vorgabe aus Spec 3a und TN3194 (Best Effort).
- **Rennen Anmelden/Löschen und Löschen/Löschen:** `deleteAccount` sperrt die Kontozeile; AC-5 und AC-6 belegen 401 statt Doppelwiderruf, S3b-AC-7 deckt die Gegenrichtung.
- **Falscher `APPLE_TOKEN_KEY`:** alte Blobs unlesbar, Widerruf entfällt mit Logzeile, Löschen läuft (AC-8c).
- **Rotierte oder entfernte Client-ID** (Adversary F001): `revokeToken` würfe über `clientSecret` erst nach dem Commit, die Antwort wäre 500 bei gelöschtem Konto; deshalb entfällt der Widerruf dann mit Logzeile, Löschen antwortet 204 (AC-8e).
- **Geheimnisse in Logs:** feste Ereigniswörter, geprüft gegen alle Werte der Läufe (AC-9).
- **Tests fälschen Apple zu gut:** sie prüfen die Verkettung, nicht Apples echtes Verhalten; das bleibt S4/Geräteabnahme.

## Test Plan

### Automated Tests (TDD RED)

RED: `/auth/delete` und `AuthDeps.log` existieren nicht; die Löschtests schlagen fehl (404 bzw. Typfehler).

- [ ] Test 1 (AC-1 bis AC-3): GIVEN zwei angemeldete Konten, gefälschtes Apple WHEN eines löscht THEN 204, Tabellen leer, ein Widerruf mit Token und `client_id`, anderes Konto unberührt.
- [ ] Test 2 (AC-4, AC-5, AC-6): GIVEN die Ablehnungstabelle, Pool-Hülle, zwei gleichzeitige Anfragen WHEN Löschen THEN 405/401, nichts angefasst, genau eine 204 bei Gleichzeitigkeit, ein Widerruf.
- [ ] Test 3 (AC-7, AC-8): GIVEN gescheiterter bzw. entfallender Widerruf WHEN Löschen THEN 204, Konto weg, Logzeile `failed` bzw. `skipped`, Aufrufzahl wie beschrieben.
- [ ] Test 4 (AC-9, AC-10, AC-11): GIVEN die gesammelten Logzeilen, abgefangene Ausgabe, Datenbankfehler WHEN Löschen THEN keine Geheimnisse, keine Ausgabe, 500 über `dispatch`.
- [ ] Test 5 (AC-12): GIVEN die Gesamtläufe WHEN `./server/scripts/test-local.sh`, `grep`, `git diff` THEN grün, kein Treffer, genau drei Dateien.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): synchroner Widerruf nach dem Commit, vor der Antwort.** Deterministisch, in Tests ohne eigenen Haken zu fassen.
- **B: Widerruf nach der Antwort im Hintergrund:** schneller für die App, aber bei SIGTERM verloren und nur über einen eigenen Haken testbar; verworfen.
- **C: Löschen als MCP-Werkzeug statt HTTP-Route:** verworfen; Löschen gehört in die App-Einstellungen (Apple-Pflicht), nicht zu Claude, und es berührte ADR-21 (Anmeldung und Konto nur über `/auth/*`).
- **D: ungeteilt (3c in einem Schnitt, ≈ 250–290 LoC):** verworfen wegen des Scoping-Limits; geteilt in 3c-1 (dieser Schnitt) und 3c-2.
- **E: 503 ohne Apple-Konfiguration:** würde Löschen an Betriebszustand knüpfen; verworfen (TN3194).
- Befunde gegen den Plan: keine blockierenden.

## Nicht in diesem Schnitt / Folgeschnitte

- **3c-2:** `authRoutes` in `start()`/`main()` einhängen (neue Option statt `extraRoutes`, vor `migrate` 503 wie `/mcp`), `APPLE_*`-Konfigurationsweiche (keine gesetzt → Auth 503, teilweise oder ungültig → Start bricht mit Variablennamen ab), JWKS einmal beim Start, 1-MiB-Grenze im `bridge`, `logError` als `log` hereinreichen.
- #621: `/mcp` nutzt `bearerToken` und `resolveSession`; Sitzungsablauf ist Merkposten dorthin.
- S4 App (nach #625); nginx-Freigabe von `/auth/*` und die `APPLE_*`-Secrets beim Ausrollen (Infra).

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: `./server/scripts/test-local.sh` grün und `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `/auth/delete` in der Zeile zu `src/auth.ts`
- [ ] #615 kommentiert (Stand Schnitt 3c-1, Folge 3c-2), Board-Karte aktuell

## Changelog

- 2026-11-05: Initial spec created (Schnitt 3c-1)
- 2026-11-05: Nachbesserung nach Adversary-Befund F001 (Override PO): Widerruf entfällt auch bei einer `client_id`, die nicht mehr in `config.clientIds` steht, oder leerem entschlüsseltem Token (AC-8 Fall e); „`server.yml` auf dem PR grün“ aus AC-12 in die Definition of Done verschoben (vor dem Commit nicht belegbar)
