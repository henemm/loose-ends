# Adversary Dialog — feat-615-s3c2-einhaengen
Spec: docs/specs/feat-615-schnitt-3c2-einhaengen.md
Datum: 2026-11-05 12:46

## Checkliste
- [x] **AC-1:** Auth-Routen vor `migrate`: Solange `migrate` noch wartet (Datenbank nicht erreichbar, wie S1-AC-2), antworten `POST /auth/apple`, `POST /auth/logout`, `POST /auth/delete` jeweils 503 ohne Körper, ebenso `/mcp`; keine der Routen ruft die Datenbank oder das gefälschte Apple-`fetch` auf (Zähler 0). Nach `ready` laufen sie. Test: „einhaengen: auth vor migrate 503“.
- [x] **AC-2:** Ohne Apple-Einrichtung: `start({ …, auth: {} })` (keine `config`) startet, `ready` erfüllt sich; `POST /auth/apple` antwortet 503 ohne Körper (Zähler des gefälschten `fetch` 0, kein JWKS-Abruf); `POST /auth/logout` mit einer echten Sitzung antwortet 204 und beendet sie; `POST /auth/delete` mit einer echten Sitzung antwortet 204 und das Konto ist weg. Test: „einhaengen: ohne config logout und delete laufen“.
- [x] **AC-3:** Mit Apple-Einrichtung: `start({ …, auth: { config, fetch } })` mit dem selbst erzeugten Schlüsselpaar und gefälschtem Apple-`fetch` durchläuft `POST /auth/apple` (gültiges Identitätstoken, Code, Nonce) mit 200 und `{sessionToken}`; danach beendet `POST /auth/logout` diese Sitzung mit 204. Das ist der Rundweg durch die echte Routentabelle von `start()`. Test: „einhaengen: anmelden und abmelden mit config“.
- [x] **AC-4:** JWKS: Es entsteht genau eine `createJwks`-Instanz je `start()`, nur mit `config`, und sie ist lazy. Belegt am gefälschten `fetch`: nach `ready` ohne Anmeldung gibt es 0 Aufrufe auf die JWKS-Adresse (kein Vorladen); zwei Anmeldungen hintereinander ergeben insgesamt genau 1 Aufruf auf die JWKS-Adresse (eine Instanz, Cache); ohne `config` gibt es nie einen. Test: „einhaengen: jwks lazy und einmal“.
- [x] **AC-5:** Weiche in `appleConfigFromEnv(env)`, tabellengetrieben, ein Fall je Zeile: (a) keine der fünf Variablen gesetzt (auch nur Leerzeichen) → `undefined`; (b) alle fünf gültig → `AppleConfig`; (c) eine Variable fehlt (je Fall eine der fünf) → wirft mit Meldung, die genau diesen Variablennamen nennt; (d) alle fünf gesetzt, aber `APPLE_PRIVATE_KEY` unlesbar bzw. `APPLE_TOKEN_KEY` nicht 32 Byte → wirft mit dem Variablennamen. In keiner Meldung steht der Wert (Test prüft gegen die gesetzten Werte). Test: „einhaengen: weiche apple env“.
- [x] **AC-6:** Abbruch im Prozess: Ein Kindprozess (`spawnSync(process.execPath, [main.ts])`, Muster aus `server/test/migrate.test.ts`, `DATABASE_URL` gesetzt, `NODE_TEST_CONTEXT` entfernt) mit teilweise gesetzten bzw. ungültigen `APPLE_*` (Fälle aus AC-5c/d) endet mit Exit-Code 1, **ohne** zu lauschen (der gewählte Port bleibt frei, es gibt keine Zeile `listening`) und ohne den Pool zu öffnen (keine Verbindung mit dem `application_name` des Kindes in `pg_stat_activity`); die Ausgabe enthält die Zeile `apple config invalid:` mit dem Variablennamen und **keinen** der gesetzten Werte (weder den Schlüsseltext noch den Token-Schlüssel noch Team-, Key- oder Client-ID). Ein Kindprozess ohne jede `APPLE_*` startet dagegen, lauscht und antwortet `/health` (nach `SIGTERM` Exit 0). Test: „einhaengen: prozess bricht bei falscher config ab“.
- [x] **AC-7:** Körpergrenze: Ein Body von genau 1 MiB (1 048 576 Bytes) wird angenommen (die Route läuft); 1 MiB + 1 Byte und größere (z. B. 2 MiB) antworten 413 ohne Körper mit Header `connection: close`, und die Route wird nicht aufgerufen (Zähler 0). Gilt für `POST /auth/apple`, `/auth/logout`, `/auth/delete` und `/mcp` (tabellengetrieben, ein Fall je Zeile). Test: „einhaengen: body ueber 1 mib 413“.
- [x] **AC-8:** Lügende Länge: Gezählt wird beim Lesen. Ein Body ohne `Content-Length` (chunked) über 1 MiB und ein Body über 1 MiB, dessen `Content-Length` weniger als 1 MiB behauptet (roher Socket), ergeben je 413 bzw. eine abgebrochene Verbindung ohne dass die Route läuft und ohne dass der Dienst mehr als das Limit plus einen Chunk puffert; der Dienst läuft danach weiter (`/health` 200). Test: „einhaengen: luegende content-length“.
- [x] **AC-9:** 413 zählt nicht ins Fehlerfenster: Nach 25 Anfragen mit zu großem Body (über dem Mindestmaß von 20 Antworten des Fensters) bleibt `/health` 200; zählte 413, kippte es auf 503. Gegenprobe im selben Test: 25 unbekannte Pfade (404) kippen `/health` wie in S1-AC-8. Test: „einhaengen: 413 kippt health nicht“.
- [x] **AC-10:** `/health` und `/mcp` bleiben unüberschreibbar: Eine `extraRoutes`-Tabelle mit den Schlüsseln `/health` und `/mcp` und ein `auth`, dessen Routen auf denselben Pfaden lägen, ändern nichts: `/health` liefert weiter die Gesundheitsantwort mit fünf Schlüsseln (S1-AC-1), `/mcp` weiter die MCP-Antwort (S1-AC-3). Test: „einhaengen: health und mcp nicht ueberschreibbar“.
- [x] **AC-11:** `logError` wirft nie: Wirft `console.error` (Test ersetzt es durch eine Funktion, die wirft), dann bricht weder das Anwendungsereignis `pool error` (Pool-Listener, ausgelöst durch einen beendeten Verbindungs-Backend wie S1-AC-5) noch eine Logzeile von `auth.ts` (`apple revoke failed`, ausgelöst durch ein werfendes Apple-`fetch` beim Löschen) den Prozess oder die Antwort: die Löschung antwortet 204, der Testprozess meldet keine unbehandelte Ausnahme. Test: „einhaengen: log wirft nie“.
- [x] **AC-12:** Das Log der Auth-Routen bleibt wertfrei: In den gesammelten Logzeilen aller Auth-Tests dieses Schnitts (Rundweg, Löschen mit scheiterndem Widerruf, ungültige Einrichtung) steht kein Token, keine Sitzung, keine Konto-ID, kein `sub`, keine `client_id`, kein Schlüsseltext und kein Apple-Antworttext; jede Zeile beginnt mit der ISO-Zeit (wie S1-AC-10). Test: „einhaengen: log ohne geheimnisse“.
- [x] **AC-13:** `extraRoutes` und Regression: `extraRoutes` funktioniert weiter wie bisher (ohne `auth` ist die Routentabelle die alte); alle bestehenden Tests in `main.test.ts`, `auth.test.ts` und allen anderen Dateien bleiben unverändert grün, kein bestehender Testfall wird geändert oder gelöscht (`git diff` auf `server/test/` zeigt in `main.test.ts` nur hinzugefügte Zeilen und keine weitere Testdatei). `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf. Test: „einhaengen: bestehende tests unveraendert“ (Prüfung per `git diff --numstat`, keine gelöschten Zeilen in Testdateien).
- [x] **AC-14:** Grenze, Länge, Doku: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/main.ts`, `server/test/main.test.ts` und `CLAUDE.md`; `auth.ts`, `apple.ts`, `apple-jwks.ts` und alle weiteren `src/`-Dateien sind unverändert; jede Funktion in `main.ts` hat höchstens 50 Zeilen. Der Abschnitt `server/` in `CLAUDE.md` ist aktualisiert: die Zeilen zu `src/auth.ts` (S3b und `/auth/delete`) enden nicht mehr mit „nothing calls … yet“, sondern nennen, dass `start()` die Routen über die Option `auth` einhängt (vor `migrate` 503), und die `main.ts`-Zeile nennt die Weiche (keine `APPLE_*` → `/auth/apple` 503, logout und delete laufen; teilweise oder ungültig → Start bricht mit Variablennamen und Exit 1 ab), die lazy JWKS-Instanz, die 1-MiB-Grenze (413) und das nie werfende `logError`; der öffentliche Zugang (nginx, `APPLE_*` im Betrieb) steht als noch offen dort. Test: „einhaengen: grenze und doku“ (Prüfung per `git diff --name-only` und `grep` auf `CLAUDE.md`).

## Dialog

### Runde 1
**Adversary:** Suite selbst gelaufen (docs/artifacts/feat-615-s3c2-einhaengen/adversary-test-output.txt, ./server/scripts/test-local.sh): Exit 0, 227 tests, 227 pass, 0 fail, 0 skipped. Code gelesen: Spreizung server/src/main.ts:135-138 (mountAuth, extraRoutes, dann /health und /mcp zuletzt) = Spec, AC-10; gated (:110) fuer alle Auth-Routen und /mcp, 503 ohne Koerper fuer jede Methode (AC-1); mountAuth (:115-123) erzeugt createJwks nur wenn config gesetzt (:120), lazy, eine Instanz je start() (AC-4), ohne auth leere Tabelle (AC-13); appleConfigFromEnv (:34-37) zaehlt trim() (nur Leerzeichen = ungesetzt), sonst loadAppleConfig (wertfrei, apple.ts unberuehrt); main() (:175-180) loggt `apple config invalid: <Meldung>` vor start() und beendet mit 1, also vor Pool und Listen (AC-5/6); logError (:27) try/catch (AC-11). Funktionslaengen in main.ts alle < 50 (start ca. 30, main ca. 30). AC-13: numstat gegen Basis 253e908 fuer server/test/ = `380 0 server/test/main.test.ts`, keine Loeschung, keine weitere Testdatei. AC-14: Dateiliste gegen Basis 253e908 ausserhalb docs und .claude = CLAUDE.md, server/src/main.ts, server/test/main.test.ts; gegen origin/main erscheinen zusaetzlich drei fremde Dateien (asc-app-info.yml, scripts/asc_app_info.py, scripts/test_asc_app_info.py), weil origin/main seit der Basis weitergelaufen ist, nicht durch diesen Schnitt; der Arbeitsbaum zeigt uncommittet nur main.ts und CLAUDE.md. CLAUDE.md:476-478 nennt Weiche, lazy JWKS, 1 MiB/413, logError, offen nginx/APPLE_*; die auth.ts-Zeilen enden nicht mehr mit `nothing calls`. Angriff Body-Grenze: buffered (:76-88) zaehlt beim Lesen, nie Content-Length; `size > BODY_LIMIT` erst bei 1 MiB + 1, genau 1 MiB geht durch; 413 in bridge (:97) vor handle, also an dispatch/ErrorWindow vorbei (AC-9). Speicher: ueber dem Limit wird chunks=null gesetzt, es liegen nie mehr als 1 MiB + ein Chunk im Puffer (AC-8). Bekannte Auffaelligkeit: Weiterlesen ueber dem Limit (Drain) bis `end` statt sofortigem Kappen. Das widerspricht dem Wort "bricht ab" nur teilweise: das Puffern bricht ab (Speichergrenze der Spec gehalten), die Verbindung nicht. Risiko: ein endlos sendender Client haelt eine Verbindung bis requestTimeout (Node 300 s); Speicher bleibt flach, kein Einfluss auf /health oder andere Verbindungen; nginx davor (client_max_body_size 1m, client_body_timeout) kappt das ohnehin, sobald /auth/* durchgelassen ist. Die Alternative (sofort zerstoeren) verlore die 413 per RST, das hat der Implementierer begruendet. Bewertung F001: LOW, kein Blocker. Weitere Randfaelle: Client-Abbruch mitten im Body: req emittiert 'error' (fail), der bridge-catch antwortet 500 bzw. zerstoert, kein haengendes Promise; GET/HEAD mit Body werden nicht gelesen (wie vorher).
**Implementierer:** F001 bewusst so gebaut (Drain, damit die 413 nicht per RST verloren geht); keine Aenderung.

### Runde 2
**Adversary:** Early-Agreement-Skepsis: nicht nur gruen, jede AC an Code UND Test geprueft. Tests: AC-1 main.test.ts:327, AC-2 :350, AC-3 :367, AC-4 :381, AC-5 :396, AC-6 :440 (eigener TCP-Lauscher als Pool-Beleg, festgelegte Abweichung), AC-7 :481, AC-8 :520 (Route bekommt <= 1 MiB, /health 200, festgelegte Abweichung), AC-9 :535 (Gegenprobe 25x500 statt 404, festgelegte Abweichung), AC-10 :551, AC-11 :565, AC-12 :580, AC-13/14 :600. Versuche zu brechen: (1) Leerzeichen-Variablen: `!env[name]?.trim()` behandelt "   " als ungesetzt, bei Teilmenge prueft loadAppleConfig mit gleichem trim (required in apple.ts), Meldung nennt den Variablennamen, nie den Wert; (2) Wert in Fehlermeldung: main.ts:178 haengt nur error.message an, apple.ts unveraendert; (3) 503 vor migrate auch fuer GET/PUT/DELETE: gated prueft die Methode nicht, also ja; 405 kommt erst nach ready aus auth.ts; (4) JWKS nur mit config: :120; ohne config ist keys undefined und /auth/apple antwortet 503 aus auth.ts; (5) 413 an dispatch vorbei: :97 liegt in bridge, dispatch sieht die Anfrage nie; (6) logError-try/catch faengt synchrone Fehler, ausreichend fuer console.error; (7) Spreizungsreihenfolge: extraRoutes mit /health und /mcp sowie Auth-Pfade werden von :137-138 ueberschrieben, Test :551 belegt es. Keine reale Luecke gefunden ausser F001 (LOW). Verdict VERIFIED.
**Implementierer:** keine Aenderung.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Findings

```json
[
  {
    "id": "F001",
    "severity": "LOW",
    "category": "edge_case",
    "code_reference": "server/src/main.ts:76",
    "description": "buffered liest ueber dem Limit die Anfrage zu Ende und verwirft die Bytes (chunks = null), statt die Verbindung sofort zu kappen. Ein endlos sendender Client haelt die Verbindung bis requestTimeout (Node 300 s).",
    "spec_requirement": "AC-8 - ueber dem Limit bricht ab, hoechstens Limit plus einen Chunk puffern",
    "conflict": "Puffern ist begrenzt (Spec erfuellt), die Verbindung bricht aber nicht sofort ab; Verbrauch nur Socket und Zeit, kein Speicher.",
    "remediation": "Optional: nach z. B. 4 MiB verworfenen Bytes die Verbindung zerstoeren; nginx (client_max_body_size 1m, client_body_timeout) entschaerft das im Betrieb. Kein Blocker."
  }
]
```

## Verdict

VERDICT: VERIFIED

Tests: 227 passed, 0 failed, 0 uebersprungen (test-local.sh Exit 0)

Code reference: server/src/main.ts:76
Code reference: server/test/main.test.ts:327
Code reference: CLAUDE.md:478

Confirmation: AC-1 Code reference: server/src/main.ts:110 (gated, 503 ohne Koerper vor migrate) Test main.test.ts:327 - CONFIRMED
Confirmation: AC-2 Code reference: server/src/main.ts:115 (auth ohne config, keys undefined) Test main.test.ts:350 - CONFIRMED
Confirmation: AC-3 Code reference: server/src/main.ts:121 (authRoutes in echter Tabelle) Test main.test.ts:367 - CONFIRMED
Confirmation: AC-4 Code reference: server/src/main.ts:120 (createJwks nur mit config, lazy) Test main.test.ts:381 - CONFIRMED
Confirmation: AC-5 Code reference: server/src/main.ts:34 (appleConfigFromEnv) Test main.test.ts:396 - CONFIRMED
Confirmation: AC-6 Code reference: server/src/main.ts:178 (Abbruch vor start, Exit 1) Test main.test.ts:440 - CONFIRMED
Confirmation: AC-7 Code reference: server/src/main.ts:97 (413 mit connection close) Test main.test.ts:481 - CONFIRMED
Confirmation: AC-8 Code reference: server/src/main.ts:76 (Zaehlen beim Lesen) Test main.test.ts:520 - CONFIRMED
Confirmation: AC-9 Code reference: server/src/main.ts:97 (vor dispatch) Test main.test.ts:535 - CONFIRMED
Confirmation: AC-10 Code reference: server/src/main.ts:136 (extraRoutes vor /health und /mcp) Test main.test.ts:551 - CONFIRMED
Confirmation: AC-11 Code reference: server/src/main.ts:27 (logError try/catch) Test main.test.ts:565 - CONFIRMED
Confirmation: AC-12 Code reference: server/src/main.ts:178 (nur Variablenname im Log) Test main.test.ts:580 - CONFIRMED
Confirmation: AC-13 Code reference: server/test/main.test.ts:600 (numstat 380/0, nur main.test.ts) - CONFIRMED
Confirmation: AC-14 Code reference: CLAUDE.md:478 (drei Dateien gegen Basis 253e908, Doku aktualisiert) - CONFIRMED

## Geprüfte Dateien

- sha256:33edb177638e82ede7e35f558bcf3fec70b2ce9360057fed3e3b380c85f75757  CLAUDE.md
- sha256:87799cf75b2c1a89bec5cb9279742f2dadbe4dcdbac6bfa65772fd865b4b941d  server/src/main.ts
- sha256:cf01043432a23a22240464090dd9176f42853834e457c51299bde6f61d1601e9  server/test/main.test.ts

## Prüfbasis

- base: 253e90847bde572875e7dc004086d380e01a1c55
- blob:94070d7035deccc79a36c767121878d218e70d60  CLAUDE.md
- blob:65103f692e18dbbccba52d23fe015a910ea17d87  server/src/main.ts
- blob:4537b33e9e1be8491ae56eb6810f761ff4d88d10  server/test/main.test.ts
