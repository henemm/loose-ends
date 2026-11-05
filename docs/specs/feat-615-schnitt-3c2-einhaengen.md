---
entity_id: feat-615-schnitt-3c2-einhaengen
type: feature
created: 2026-11-05
updated: 2026-11-05
status: draft
workflow: feat-615-s3c2-einhaengen
---

# Spec: Anmelde-Routen in den laufenden Dienst einhängen, Schnitt 3c-2 (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 3c-2; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s3c2-einhaengen.md`. Vorgänger: Schnitt 3c-1 (`docs/specs/feat-615-schnitt-3c1-konto-loeschen.md`, Abschnitt „Nicht in diesem Schnitt / Folgeschnitte“ mit dem Folgeplan 3c-2) und Schnitt 3b (`docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md`) mit `authRoutes`; Schnitt 2b-1 (`docs/specs/feat-615-schnitt-2b1-jwks-cache.md`) mit `createJwks`.

## Für den PO

Dieser Schnitt hängt die drei fertigen Türen „Anmelden“, „Abmelden“ und „Konto löschen“ in den laufenden Dienst ein. Von außen ändert sich noch nichts: Der Server vor dem Dienst lässt `/auth/*` erst später durch, und die App ruft nichts auf. Drei Dinge werden dabei sicherer: Fehlt die Apple-Einrichtung ganz, läuft der Dienst wie heute weiter (Anmelden meldet „nicht verfügbar“, Abmelden und Löschen laufen). Ist sie nur halb oder falsch eingetragen, startet der Dienst gar nicht und sagt im Log, welche Angabe fehlt, nie den Wert, damit nie unbemerkt ein Dienst ohne Anmeldung läuft. Und der Dienst nimmt keine Anfrage über 1 MiB mehr an, weder bei der Anmeldung noch bei Claude.

## Purpose

`server/src/main.ts` erhält die Option `auth` in `StartOptions`, die Weiche für die Apple-Einrichtung in `main()`, eine Körpergrenze von 1 MiB im `bridge` und ein `logError`, das nie wirft. Reine Verdrahtung fertiger Bausteine (`authRoutes`, `loadAppleConfig`, `createJwks`); `auth.ts`, `apple.ts`, `apple-jwks.ts` und alle anderen `src/`-Dateien bleiben unberührt. **Regeln vor Modell:** Protokoll- und Betriebsarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Quelle (Recherche 2026-11-05, aus der Analyse): Apple rotiert die JWKS-Schlüssel ohne Ankündigung und hält mehrere gleichzeitig gültig; üblich ist Cache plus gebremstes Nachladen bei unbekanntem `kid`, genau `createJwks` (https://developer.apple.com/forums/thread/133699). Ein `node:http`-Server hat keine Körpergrenze; üblich sind 100 KB (Express) bis 1 MB (nginx-Standard `client_max_body_size`), 1 MiB im Dienst deckt sich mit dem, was davor schon gilt (https://betterstack.com/community/questions/default-nginx-client-max-body-size-value/).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Verdrahtung fertiger Bausteine nach ADR-21 und dem Folgeplan aus Spec 3c-1; keine neue Abhängigkeit, kein neues Muster.
- **Rationale:** (1) Die Umgebung wird nur in `main()` gelesen (wie `DATABASE_URL`), `start()` bleibt frei davon: Der Abbruch bei falscher Einrichtung geschieht damit vor dem Listen und vor dem Pool, und es ist kein Pool zu schließen. (2) Alle Auth-Routen antworten vor `migrate` 503 ohne Körper wie `/mcp`, denn sie brauchen die Datenbank. (3) Die 413-Antwort entsteht im `bridge`, läuft an `dispatch` vorbei und zählt deshalb nicht ins Fehlerfenster: ein Client-Fehler darf `/health` nicht kippen. (4) `logError` fängt eigene Fehler, weil `console.error` auf geschlossenem stderr (EPIPE) werfen kann und `log` in `auth.ts` und im Pool-Listener nie den Prozess beenden darf.

## Source

**Files:** `server/src/main.ts` (ändern), `server/test/main.test.ts` (nur neue Tests), `CLAUDE.md`
**Identifier:** `StartOptions.auth`, `gated`, `mountAuth`, `appleConfigFromEnv`, `bridge`, `buffered`, `logError`

### Schnittstelle

- `StartOptions` erhält `auth?: { config?: AppleConfig; fetch?: typeof fetch }`. `extraRoutes` bleibt unverändert.
- **Ohne `auth`** (alle bisherigen Tests) hängt `start()` keine Auth-Routen ein; die Routentabelle ist wie bisher. **Mit `auth`** (immer in `main()`) hängt `mountAuth` `authRoutes({ pool, config, keys, fetch, now, log })` ein; `fetch` ist `auth.fetch ?? globalThis.fetch`, `now` ist `options.now ?? Date.now`, `log` ist `logError`.
- **`keys`:** genau eine `createJwks({ fetch, now })`-Instanz je `start()`, und nur wenn `auth.config` gesetzt ist; ohne `config` ist `keys` undefiniert. Kein Vorladen: die Instanz holt Apples Schlüssel erst bei der ersten Anmeldung (lazy).
- **Routentabelle:** `{ ...authRoutes, ...options.extraRoutes, "/health": …, "/mcp": … }`; `/health` und `/mcp` stehen zuletzt und sind weder durch `auth` noch durch `extraRoutes` zu überschreiben.
- **`gated(isReady, route)`:** liefert eine Route, die vor `migrate` 503 ohne Körper antwortet und danach die Route aufruft. Alle drei Auth-Routen und `/mcp` laufen darüber.
- **`appleConfigFromEnv(env)`** (aus `main.ts` exportiert): zählt die fünf Variablen `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_IDS`, `APPLE_PRIVATE_KEY`, `APPLE_TOKEN_KEY`; nur Leerzeichen zählt als nicht gesetzt (wie `required` in `apple.ts`). Keine gesetzt → `undefined`; sonst `loadAppleConfig(env)` (wirft mit Variablennamen, wertfrei).
- **`main()`:** nach `DATABASE_URL` und vor `start()` ruft sie `appleConfigFromEnv(process.env)`; wirft es, schreibt sie genau eine Logzeile `apple config invalid: <Meldung>` (die wertfreie Meldung von `loadAppleConfig`, der Name der Variablen) über `logError` und beendet mit Exit 1, ohne zu listen und ohne Pool. Sonst `start({ …, auth: { config } })`.
- **Körpergrenze im `bridge`:** `BODY_LIMIT = 1024 * 1024` Bytes. `buffered` zählt die gelesenen Bytes beim Lesen (nicht die `Content-Length`); über dem Limit bricht es ab und der `bridge` antwortet 413 ohne Körper mit `connection: close`, ohne `handle` aufzurufen. Gilt für jede Route, auch `/mcp`, und für lügende oder fehlende `Content-Length` (chunked). Genau 1 MiB geht noch durch.
- **`logError`:** `console.error` in `try { … } catch {}`; wirft nie, schreibt weiter eine Zeile mit ISO-Zeit vorn.

### Festlegungen

- **Stille:** Die Logzeile bei ungültiger Einrichtung nennt nur den Variablennamen aus der Meldung von `loadAppleConfig`, nie einen Wert, keinen Schlüssel, keine Token-Bytes; sonst keine neuen Logzeilen. Die 413-Antwort schreibt nichts ins Log.
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen (`start()` bleibt darunter, Zusatzlogik in `gated`, `mountAuth`, `appleConfigFromEnv`); Kommentare knapp auf Englisch; keine neuen Pakete.
- **Unberührt:** `auth.ts`, `apple.ts`, `apple-jwks.ts`, `apple-client.ts`, `apple-vault.ts`, `accounts.ts`, `mcp.ts`, alle anderen `src/`-Dateien, bestehende Tests, `.github/`, `project.yml`, jede Swift-Datei, Migrationen.

## Abweichung vom Folgeplan 3c-1

Der Folgeplan in Spec 3c-1 nannte „neue Option statt `extraRoutes`“ und „JWKS einmal beim Start“. Dieser Schnitt weicht in zwei Punkten bewusst ab:

1. **`extraRoutes` bleibt.** `server/test/main.test.ts` (die Routen `/boom` und `/leak`) und `server/test/auth.test.ts` (`/auth/delete` per `extraRoutes`) nutzen es als Test-Naht; es zu ersetzen hieße, bestehende Tests zu ändern, ohne dass der Schnitt es braucht. Die neue Option `auth` steht daneben. Ohne `auth` ändert sich für diese Tests nichts.
2. **JWKS lazy statt vorladen.** Eine Instanz je Prozess, aber ohne Abruf beim Start: Ein Vorab-Abruf bringt nichts (Apples Schlüssel ändern sich ohnehin, der Cache läuft nach einer Stunde ab), und ein beim Start fehlgeschlagener Abruf belegte die 60-s-Sperre des Nachladens, sodass die erste echte Anmeldung `keys_unavailable` bekäme. „Einmal beim Start“ ist damit präzisiert zu „eine Instanz je Prozess“.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `authRoutes`, `AuthDeps` (`auth.ts`) | bestehend aus 3b/3c-1, unverändert |
| `loadAppleConfig`, `AppleConfig` (`apple.ts`) | bestehend, unverändert |
| `createJwks` (`apple-jwks.ts`) | bestehend, unverändert |
| `ErrorWindow`, `healthHandler`, `mcpHandler`, `migrate` | bestehend, unverändert |
| `node:http`, `node:child_process`, `pg`, `node:test` | bestehend, **keine neuen Pakete** |
| Downstream | nginx-Freigabe von `/auth/*` und `APPLE_*` in der Compose-Umgebung (`henemm-infra`, mit S4/#621), #621 (`/mcp` mit `bearerToken`/`resolveSession`), S4 App (nach #625) |

## Acceptance Criteria

Alle neuen Tests mit `node:test` und `node:assert/strict` in `server/test/main.test.ts`, mit dem Testaufbau `service(t, options)` aus S1; Datenbank gegen das Wegwerf-Postgres aus `server/test/db.ts`; Apple wird durch ein selbst erzeugtes Schlüsselpaar und ein injiziertes `auth.fetch` ersetzt (kein Netz). Ablehnungsfälle tabellengetrieben, ein Fall je Zeile. Kein bestehender Testfall wird geändert.

- **AC-1:** Auth-Routen vor `migrate`: Solange `migrate` noch wartet (Datenbank nicht erreichbar, wie S1-AC-2), antworten `POST /auth/apple`, `POST /auth/logout`, `POST /auth/delete` jeweils 503 ohne Körper, ebenso `/mcp`; keine der Routen ruft die Datenbank oder das gefälschte Apple-`fetch` auf (Zähler 0). Nach `ready` laufen sie. Test: „einhaengen: auth vor migrate 503“.
- **AC-2:** Ohne Apple-Einrichtung: `start({ …, auth: {} })` (keine `config`) startet, `ready` erfüllt sich; `POST /auth/apple` antwortet 503 ohne Körper (Zähler des gefälschten `fetch` 0, kein JWKS-Abruf); `POST /auth/logout` mit einer echten Sitzung antwortet 204 und beendet sie; `POST /auth/delete` mit einer echten Sitzung antwortet 204 und das Konto ist weg. Test: „einhaengen: ohne config logout und delete laufen“.
- **AC-3:** Mit Apple-Einrichtung: `start({ …, auth: { config, fetch } })` mit dem selbst erzeugten Schlüsselpaar und gefälschtem Apple-`fetch` durchläuft `POST /auth/apple` (gültiges Identitätstoken, Code, Nonce) mit 200 und `{sessionToken}`; danach beendet `POST /auth/logout` diese Sitzung mit 204. Das ist der Rundweg durch die echte Routentabelle von `start()`. Test: „einhaengen: anmelden und abmelden mit config“.
- **AC-4:** JWKS: Es entsteht genau eine `createJwks`-Instanz je `start()`, nur mit `config`, und sie ist lazy. Belegt am gefälschten `fetch`: nach `ready` ohne Anmeldung gibt es 0 Aufrufe auf die JWKS-Adresse (kein Vorladen); zwei Anmeldungen hintereinander ergeben insgesamt genau 1 Aufruf auf die JWKS-Adresse (eine Instanz, Cache); ohne `config` gibt es nie einen. Test: „einhaengen: jwks lazy und einmal“.
- **AC-5:** Weiche in `appleConfigFromEnv(env)`, tabellengetrieben, ein Fall je Zeile: (a) keine der fünf Variablen gesetzt (auch nur Leerzeichen) → `undefined`; (b) alle fünf gültig → `AppleConfig`; (c) eine Variable fehlt (je Fall eine der fünf) → wirft mit Meldung, die genau diesen Variablennamen nennt; (d) alle fünf gesetzt, aber `APPLE_PRIVATE_KEY` unlesbar bzw. `APPLE_TOKEN_KEY` nicht 32 Byte → wirft mit dem Variablennamen. In keiner Meldung steht der Wert (Test prüft gegen die gesetzten Werte). Test: „einhaengen: weiche apple env“.
- **AC-6:** Abbruch im Prozess: Ein Kindprozess (`spawnSync(process.execPath, [main.ts])`, Muster aus `server/test/migrate.test.ts`, `DATABASE_URL` gesetzt, `NODE_TEST_CONTEXT` entfernt) mit teilweise gesetzten bzw. ungültigen `APPLE_*` (Fälle aus AC-5c/d) endet mit Exit-Code 1, **ohne** zu lauschen (der gewählte Port bleibt frei, es gibt keine Zeile `listening`) und ohne den Pool zu öffnen (keine Verbindung mit dem `application_name` des Kindes in `pg_stat_activity`); die Ausgabe enthält die Zeile `apple config invalid:` mit dem Variablennamen und **keinen** der gesetzten Werte (weder den Schlüsseltext noch den Token-Schlüssel noch Team-, Key- oder Client-ID). Ein Kindprozess ohne jede `APPLE_*` startet dagegen, lauscht und antwortet `/health` (nach `SIGTERM` Exit 0). Test: „einhaengen: prozess bricht bei falscher config ab“.
- **AC-7:** Körpergrenze: Ein Body von genau 1 MiB (1 048 576 Bytes) wird angenommen (die Route läuft); 1 MiB + 1 Byte und größere (z. B. 2 MiB) antworten 413 ohne Körper mit Header `connection: close`, und die Route wird nicht aufgerufen (Zähler 0). Gilt für `POST /auth/apple`, `/auth/logout`, `/auth/delete` und `/mcp` (tabellengetrieben, ein Fall je Zeile). Test: „einhaengen: body ueber 1 mib 413“.
- **AC-8:** Lügende Länge: Gezählt wird beim Lesen. Ein Body ohne `Content-Length` (chunked) über 1 MiB und ein Body über 1 MiB, dessen `Content-Length` weniger als 1 MiB behauptet (roher Socket), ergeben je 413 bzw. eine abgebrochene Verbindung ohne dass die Route läuft und ohne dass der Dienst mehr als das Limit plus einen Chunk puffert; der Dienst läuft danach weiter (`/health` 200). Test: „einhaengen: luegende content-length“.
- **AC-9:** 413 zählt nicht ins Fehlerfenster: Nach 25 Anfragen mit zu großem Body (über dem Mindestmaß von 20 Antworten des Fensters) bleibt `/health` 200; zählte 413, kippte es auf 503. Gegenprobe im selben Test: 25 unbekannte Pfade (404) kippen `/health` wie in S1-AC-8. Test: „einhaengen: 413 kippt health nicht“.
- **AC-10:** `/health` und `/mcp` bleiben unüberschreibbar: Eine `extraRoutes`-Tabelle mit den Schlüsseln `/health` und `/mcp` und ein `auth`, dessen Routen auf denselben Pfaden lägen, ändern nichts: `/health` liefert weiter die Gesundheitsantwort mit fünf Schlüsseln (S1-AC-1), `/mcp` weiter die MCP-Antwort (S1-AC-3). Test: „einhaengen: health und mcp nicht ueberschreibbar“.
- **AC-11:** `logError` wirft nie: Wirft `console.error` (Test ersetzt es durch eine Funktion, die wirft), dann bricht weder das Anwendungsereignis `pool error` (Pool-Listener, ausgelöst durch einen beendeten Verbindungs-Backend wie S1-AC-5) noch eine Logzeile von `auth.ts` (`apple revoke failed`, ausgelöst durch ein werfendes Apple-`fetch` beim Löschen) den Prozess oder die Antwort: die Löschung antwortet 204, der Testprozess meldet keine unbehandelte Ausnahme. Test: „einhaengen: log wirft nie“.
- **AC-12:** Das Log der Auth-Routen bleibt wertfrei: In den gesammelten Logzeilen aller Auth-Tests dieses Schnitts (Rundweg, Löschen mit scheiterndem Widerruf, ungültige Einrichtung) steht kein Token, keine Sitzung, keine Konto-ID, kein `sub`, keine `client_id`, kein Schlüsseltext und kein Apple-Antworttext; jede Zeile beginnt mit der ISO-Zeit (wie S1-AC-10). Test: „einhaengen: log ohne geheimnisse“.
- **AC-13:** `extraRoutes` und Regression: `extraRoutes` funktioniert weiter wie bisher (ohne `auth` ist die Routentabelle die alte); alle bestehenden Tests in `main.test.ts`, `auth.test.ts` und allen anderen Dateien bleiben unverändert grün, kein bestehender Testfall wird geändert oder gelöscht (`git diff` auf `server/test/` zeigt in `main.test.ts` nur hinzugefügte Zeilen und keine weitere Testdatei). `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf. Test: „einhaengen: bestehende tests unveraendert“ (Prüfung per `git diff --numstat`, keine gelöschten Zeilen in Testdateien).
- **AC-14:** Grenze, Länge, Doku: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/main.ts`, `server/test/main.test.ts` und `CLAUDE.md`; `auth.ts`, `apple.ts`, `apple-jwks.ts` und alle weiteren `src/`-Dateien sind unverändert; jede Funktion in `main.ts` hat höchstens 50 Zeilen. Der Abschnitt `server/` in `CLAUDE.md` ist aktualisiert: die Zeilen zu `src/auth.ts` (S3b und `/auth/delete`) enden nicht mehr mit „nothing calls … yet“, sondern nennen, dass `start()` die Routen über die Option `auth` einhängt (vor `migrate` 503), und die `main.ts`-Zeile nennt die Weiche (keine `APPLE_*` → `/auth/apple` 503, logout und delete laufen; teilweise oder ungültig → Start bricht mit Variablennamen und Exit 1 ab), die lazy JWKS-Instanz, die 1-MiB-Grenze (413) und das nie werfende `logError`; der öffentliche Zugang (nginx, `APPLE_*` im Betrieb) steht als noch offen dort. Test: „einhaengen: grenze und doku“ (Prüfung per `git diff --name-only` und `grep` auf `CLAUDE.md`).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/main.ts` | MODIFY | `StartOptions.auth`, `gated`, `mountAuth`, `appleConfigFromEnv`, Körpergrenze in `buffered`/`bridge`, `logError` mit `try/catch`, Weiche in `main()`, ≈ +70 |
| `server/test/main.test.ts` | MODIFY (nur neue Tests) | Fälle AC-1 bis AC-12, Kindprozess für AC-6, ≈ +120–140 |
| `CLAUDE.md` | MODIFY | Zeilen zu `src/auth.ts` und `src/main.ts` im Abschnitt `server/`, ≈ ±10 |

### Estimated Changes

- **Files: 3** (Spec und Kontext zählen nicht). **LoC ≈ +200–220** (Code ≈ 70, Tests ≈ 120–140, Doku ≈ 10) und damit innerhalb des Limits von ±250.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, keine Migration, kein `generate`. Seiteneffekt außerhalb des Tickets: keiner nach außen, solange nginx `/auth/*` nicht durchlässt; im Betrieb ist heute keine `APPLE_*` gesetzt, der Dienst startet also wie bisher (Fall AC-2). Neu für `/mcp`: die 1-MiB-Grenze (MCP-Anfragen sind klein).

## Risiken

- **Dienst startet nicht mehr:** Eine teilweise gesetzte Einrichtung stoppt den Start (gewollt, AC-6). Im Betrieb ist heute keine gesetzt (Fall „keine“ startet wie bisher, AC-2); beim späteren Eintragen der `APPLE_*` im Compose-Stack gilt: alle fünf oder keine.
- **Geheimnis im Log beim Abbruch:** Die Meldung von `loadAppleConfig` ist wertfrei (S2a), die Zeile hängt nur sie an; AC-5 und AC-6 prüfen gegen alle gesetzten Werte.
- **Falsche 413-Grenze für `/mcp`:** MCP-Anfragen sind klein (Abschrift wird über Werkzeuge geholt, nicht gesendet); die Grenze vorher prüfen: die längste Anfrage der bestehenden Tests liegt weit darunter, und S1-AC-3 bleibt grün.
- **Speicher bei lügender Länge:** Gezählt wird beim Lesen, nicht nach der Kopfzeile (AC-8); der Dienst puffert höchstens Limit plus einen Chunk.
- **`/health` kippt durch Angreifer:** 413 läuft an `dispatch` vorbei und zählt nicht ins Fehlerfenster (AC-9).
- **Überschreiben von `/health` oder `/mcp`:** Reihenfolge der Spreizung, `/health` und `/mcp` zuletzt (AC-10).
- **`console.error` wirft (EPIPE):** `logError` fängt (AC-11).
- **Tests fälschen Apple zu gut:** sie prüfen die Verkettung in der echten Routentabelle, nicht Apples echtes Verhalten; das bleibt S4/Geräteabnahme.

## Test Plan

### Automated Tests (TDD RED)

RED: Die Option `auth`, `appleConfigFromEnv` und die Körpergrenze existieren nicht; die neuen Tests schlagen fehl (404 auf `/auth/*`, Typfehler bzw. fehlender Export, keine 413).

| Testname | AC |
|---|---|
| „einhaengen: auth vor migrate 503“ | AC-1 |
| „einhaengen: ohne config logout und delete laufen“ | AC-2 |
| „einhaengen: anmelden und abmelden mit config“ | AC-3 |
| „einhaengen: jwks lazy und einmal“ | AC-4 |
| „einhaengen: weiche apple env“ | AC-5 |
| „einhaengen: prozess bricht bei falscher config ab“ | AC-6 |
| „einhaengen: body ueber 1 mib 413“ | AC-7 |
| „einhaengen: luegende content-length“ | AC-8 |
| „einhaengen: 413 kippt health nicht“ | AC-9 |
| „einhaengen: health und mcp nicht ueberschreibbar“ | AC-10 |
| „einhaengen: log wirft nie“ | AC-11 |
| „einhaengen: log ohne geheimnisse“ | AC-12 |
| „einhaengen: bestehende tests unveraendert“ (`test-local.sh`, `git diff --numstat`) | AC-13 |
| „einhaengen: grenze und doku“ (`git diff --name-only`, `grep` auf `CLAUDE.md`) | AC-14 |

- [ ] Test 1 (AC-1, AC-2, AC-3, AC-4): GIVEN Dienst mit und ohne `auth.config`, gefälschtes Apple WHEN Auth-Routen vor und nach `ready` THEN 503 vor `migrate`, ohne Config 503 nur bei `/auth/apple`, Rundweg mit Config, eine JWKS-Instanz lazy.
- [ ] Test 2 (AC-5, AC-6): GIVEN Umgebungstabelle und Kindprozess WHEN `appleConfigFromEnv` bzw. `main.ts` THEN `undefined`/Konfiguration/Wurf mit Variablennamen, Exit 1 vor Listen und Pool, kein Wert in der Ausgabe.
- [ ] Test 3 (AC-7, AC-8, AC-9): GIVEN Bodies um 1 MiB, chunked und lügende Länge WHEN Anfrage an alle vier Routen THEN 413 ohne Körper und `connection: close`, Route nicht aufgerufen, `/health` bleibt 200.
- [ ] Test 4 (AC-10, AC-11, AC-12): GIVEN `extraRoutes` mit `/health`/`/mcp`, werfendes `console.error`, gesammelte Logzeilen WHEN Betrieb THEN nichts überschrieben, nichts bricht, keine Geheimnisse.
- [ ] Test 5 (AC-13, AC-14): GIVEN die Gesamtläufe WHEN `./server/scripts/test-local.sh`, `git diff`, `grep` THEN grün, genau drei Dateien, keine gelöschten Testzeilen, `CLAUDE.md` aktualisiert.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): `auth` als neue Option neben `extraRoutes`, Umgebung nur in `main()`, JWKS lazy, Grenze im `bridge`.** Bestehende Tests bleiben unberührt, Abbruch vor Listen und Pool, `/health` bleibt unbeeinflusst.
- **B: `start()` liest die Umgebung selbst:** Der Abbruch wäre per `start()` testbar, aber der Pool wäre dann schon offen und müsste geschlossen werden, und `start()` hinge an `process.env`; verworfen.
- **C: Körpergrenze nur in den Routen:** Das ungebremste Puffern in `buffered` bliebe (Speicher), und `/mcp` hätte sie nicht; verworfen.
- **D: JWKS beim Start vorladen:** ohne Nutzen, und ein fehlgeschlagener Vorab-Abruf belegte die 60-s-Sperre, sodass die erste echte Anmeldung `keys_unavailable` bekäme; verworfen.
- **E: `extraRoutes` durch die neue Option ersetzen (Folgeplan 3c-1):** änderte bestehende Tests in `main.test.ts` und `auth.test.ts`; verworfen, siehe Abschnitt „Abweichung vom Folgeplan 3c-1“.
- **F: Teilweise Einrichtung still als „keine“ behandeln:** Der Dienst liefe unbemerkt ohne Anmeldung; verworfen, Abbruch mit Variablennamen.
- Befunde gegen den Plan: keine blockierenden.

## Nicht in diesem Schnitt / Folgeschnitte

- nginx-Freigabe von `/auth/*` und die `APPLE_*`-Variablen in der Compose-Umgebung (`henemm-infra`), später mit S4/#621; bis dahin ist die Anmeldung von außen nicht erreichbar.
- App-Seite (S4, nach #625): Anmelden, Abmelden, „Konto löschen“ in den Einstellungen.
- #621: `/mcp` nutzt `bearerToken` und `resolveSession`; Sitzungsablauf ist Merkposten dorthin.

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: Server-Kette `./server/scripts/test-local.sh` (typecheck + `npm test` gegen ein Wegwerf-Postgres) grün und `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-14 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt die Einhängung, die Weiche, die lazy JWKS-Instanz und die 1-MiB-Grenze
- [ ] #615 kommentiert (Stand Schnitt 3c-2, Folge: nginx und `APPLE_*` im Betrieb, S4), Board-Karte aktuell

## Changelog

- 2026-11-05: Initial spec created (Schnitt 3c-2)
- 2026-11-05 (Validierung): Drei Abweichungen im Beleg, keine im Verhalten. AC-9: Das Fehlerfenster zählt nur Antworten ≥ 500 (`health.ts`), 404 kippt `/health` nicht; die Gegenprobe läuft deshalb mit 25 × 500. AC-8: Bei einer zu kleinen `Content-Length` übergibt der HTTP-Parser der Route nur die behaupteten Bytes, der Rest wird nie als Körper gepuffert; belegt ist, dass die Route nie mehr als 1 MiB bekommt und `/health` danach 200 bleibt. AC-7: `/auth/apple` hat seine eigene Grenze von 16 KiB, deshalb ist „genau 1 MiB geht durch“ an den anderen Routen belegt; die Brücke prüft unabhängig vom Pfad. Zeilengrenze: ≈ 456 statt ≈ 210, von Henning nach RED angenommen (Kontext-Dokument).
