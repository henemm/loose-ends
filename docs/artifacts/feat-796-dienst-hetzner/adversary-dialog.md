# Adversary Dialog — feat-796-dienst-hetzner
Spec: docs/specs/feat-796-schnitt-1-prozess-einstieg.md
Datum: 2026-11-02 22:03

## Checkliste
- [x] **AC-1:** `start` mit gültiger `databaseUrl`, Port 0 und dem Migrationsordner: nach `await ready` antwortet `GET /health` mit 200 und einem JSON-Body mit `status` „ok“, `db` „up“, `migrated` true, `errorRate` 0 und `requests` (Zahl); der Body enthält außer diesen fünf Schlüsseln nichts.
- [x] **AC-2:** Vor dem Ende von `migrate` antwortet `/health` mit 503, `migrated` false (Aufbau: `databaseUrl` zeigt auf einen Port ohne Postgres, `retryMs` 50). Der Prozess bleibt dabei erreichbar, `/mcp` antwortet in diesem Zustand ebenfalls mit 503. Nach `maxAttempts` erschöpften Versuchen ist `ready` abgelehnt, und `close()` wirft nicht.
- [x] **AC-3:** `POST /mcp` mit JSON-RPC `initialize` (Protokoll wie in `mcp.test.ts`) antwortet mit 200 und einem `serverInfo` im Ergebnis; ein `tools/call` für `get_now` antwortet mit `isError` und „kein Konto“ (kein Anmeldeweg in diesem Schnitt, `authInfo` leer).
- [x] **AC-4:** `GET /gibt-es-nicht` antwortet mit 404; die Anfrage zählt in `requests` des nächsten `/health`.
- [x] **AC-5:** Werden alle Verbindungen des Pools mit `pg_terminate_backend` beendet (Verbindungen über `application_name` erkannt), lebt der Prozess weiter (der Testlauf selbst bricht nicht ab), und das nächste `GET /health` antwortet innerhalb von 5 Sekunden wieder mit 200 und `db` „up“. Eine Verbindung, die nur wegen des Abbruchs den `error`-Listener auslöst, schreibt keinen Fehlertext in die Ausgabe.
- [x] **AC-6:** `close()` beendet den Server (ein weiterer `fetch` auf `url` schlägt mit Verbindungsfehler fehl) und den Pool (`pool.ended`); ein zweiter Aufruf von `close()` wirft nicht. Eine noch offene keep-alive-Verbindung hält `close()` nicht auf.
- [x] **AC-7:** `ErrorWindow` mit eingespeister Uhr: 19 Antworten mit 500 sind nicht `tripped` (unter der Mindestanzahl); 20 Antworten, davon 11 mit 500, sind `tripped` (`errorRate` 0,55); 20 Antworten, davon 10 mit 500, sind nicht `tripped` (Schwelle ist „größer als“ 0,5); nach `now() + 300_001` ms sind alle Einträge verfallen (`requests` 0, `errorRate` 0, nicht `tripped`); `record` mit 404 oder 200 zählt als Anfrage, aber nicht als Fehler.
- [x] **AC-8:** `/health` kippt auf 503 und erholt sich: mit eingespeister Uhr (`now`-Option von `start`) und einer Route, die 500 liefert (Aufbau: Handler wirft; im Test über einen eigens eingetragenen Pfad der Routentabelle, den `start` für Tests als Option `extraRoutes` entgegennimmt), kippt `/health` nach 20 Anfragen mit mindestens 11 Fehlern auf 503 mit `status` „unavailable“ und `errorRate` über 0,5, obwohl `db` „up“ und `migrated` true sind; nach Vorstellen der Uhr um mehr als 5 Minuten antwortet `/health` wieder mit 200. Die `/health`-Abrufe selbst haben die Zahl `requests` nicht erhöht.
- [x] **AC-9:** `healthHandler` mit einer Datenbank, deren Abfrage länger als `timeoutMs` braucht (Test: Pool-Attrappe mit nie endendem `query`, `timeoutMs` 50): antwortet 503 mit `db` „down“ nach höchstens einer Sekunde, ohne zu werfen.
- [x] **AC-10:** Datenschutz: Weder der Rumpf irgendeiner Antwort (`/health`, 404, 500, 503) noch eine Logzeile enthält Aufgabentitel, Auftragskennungen, Datenbank-Fehlertexte oder die `databaseUrl`; jede Logzeile beginnt mit einem ISO-Zeitpunkt. Der Test spiegelt `console.log` und `console.error` mit, speist eine Abschrift mit Titeln und einen Auftrag über das Schema ein und prüft die aufgefangenen Zeilen auf diese Zeichenketten.
- [x] **AC-11:** Echter Lauf als Nutzer des Dienstes (kein Test, ein Beleg im Abschlussbericht): `./server/scripts/test-local.sh`-Postgres bzw. ein Wegwerf-Postgres wie dort, `DATABASE_URL=… PORT=<frei> npm start` in `server/`; `curl -i http://127.0.0.1:<Port>/health` liefert 200; Postgres wird gestoppt (`pg_ctl stop`), `curl /health` liefert 503 mit `db` „down“ und der Prozess läuft weiter; Postgres wird wieder gestartet, `curl /health` liefert wieder 200 ohne Neustart des Prozesses; `kill -TERM` beendet den Prozess mit Exit-Code 0 und den Zeilen `shutting down`, `stopped`. Ausgabe der Befehle wird im Abschlussbericht gezeigt.
- [x] **AC-12:** `npm run typecheck` und `./server/scripts/test-local.sh` sind grün (bestehende Tests unverändert) und räumen auf; `server.yml` ist auf dem PR grün.
- [x] **AC-13:** Die Dateiliste des PR enthält genau `server/src/main.ts`, `server/src/health.ts`, `server/test/main.test.ts`, `server/package.json` und `CLAUDE.md` (Abschnitt „Where things live“, Eintrag `server/`: `src/main.ts` mit Routentabelle, `/health`, `npm start`), ausgenommen `docs/specs/`, `docs/context/`, `docs/briefings/`. `server/src/migrate.ts`, `mcp.ts`, `orders.ts`, `transcripts.ts`, `accounts.ts`, `server/migrations/`, `project.yml` und jede Swift-Datei bleiben unberührt; `package-lock.json` ändert sich nicht (keine neue Abhängigkeit).

## Dialog

### Runde 1
**Adversary:** Ich gehe von "kaputt" aus und prüfe jeden Punkt am Code und im Lauf.
- Testlauf `./server/scripts/test-local.sh` (Ausgabe: docs/artifacts/feat-796-dienst-hetzner/adversary-test-output.txt): Exit 0, 112 pass, 0 fail, 0 skipped; typecheck grün; alle zehn Tests mit Suffix (S1) laufen und bestehen (AC-1 bis AC-10). `main.test.ts` ist seit dem RED-Commit unverändert (Verlauf: nur die eine Hinzufügung, 228 Zeilen).
- AC-11 wörtlich, mit `npm start` in `server/`, Wegwerf-Postgres (eigener Datenordner, freie Ports 54980/54981), Beweis unten.
- Code: `start` lauscht vor `migrate` (main.ts:96-103), `/mcp` gibt bis `migrated` 503 (main.ts:92), `dispatch` zählt alles außer `/health` und fängt Ausnahmen als 500 ohne Body (main.ts:46-57), `Object.hasOwn` verhindert `/__proto__`, `/constructor`, `/toString` als Route (Probe: alle 404).
- Datenschutz: Logzeilen sind feste Texte ohne Fehlerobjekt (main.ts:21-22, 27, 39, 117-118). Probe mit einer URL voller Zugangsdaten (Nutzer, Passwort, Datenbankname, toter Port): Ausgabe enthält nichts davon; Zeilen `listening`, `migrate failed, retrying (n/60)` mit ISO-Zeit.
**Implementierer (Beweise):**
AC-11 Ausgabe (Lauf 1, DATABASE_URL auf Wegwerf-Postgres Port 54980, PORT=54981, npm start):
```
--- 1 up
HTTP/1.1 200 OK  content-type: application/json
{"status":"ok","db":"up","migrated":true,"errorRate":0,"requests":0}
--- 2 pg_ctl stop
HTTP/1.1 503 Service Unavailable
{"status":"unavailable","db":"down","migrated":true,"errorRate":0,"requests":0}
Prozesse: 24093 npm start / 24118 node src/main.ts   (lebt)
--- 3 pg_ctl start
HTTP/1.1 200 OK
{"status":"ok","db":"up","migrated":true,"errorRate":0,"requests":0}
Prozesse: 24093 / 24118  (gleiche PIDs, kein Neustart)
--- SIGTERM an die npm-PID 24093
> start
> node src/main.ts
2026-11-02T21:05:23.244Z listening
2026-11-02T21:05:23.266Z migrated
2026-11-02T21:05:29.868Z pool error
2026-11-02T21:05:41.864Z shutting down
2026-11-02T21:05:41.865Z stopped
danach: kein Prozess übrig, Port geschlossen.
```
Lauf 2 (Exit-Code): npm start im Hintergrund, SIGTERM an dessen PID, dann wait: `EXIT(npm)=0`, Ausgabe `listening`, `migrated`, `shutting down`, `stopped`. Ergebnis: SIGTERM erreicht über npm den node-Prozess, Exit-Code 0, beide Zeilen sichtbar. Postgres und Prozesse danach aufgeräumt (Datenordner gelöscht, keine Reste).

### Runde 2
**Adversary:** Edge Cases, die Runde 1 nicht abdeckte.
- close() während der Wiederholung: Probe mit totem Port, SIGTERM zweimal hintereinander während `retrying (3/60)`: Exit 0, keine unbehandelte Ablehnung (`ready.catch(() => {})` main.ts:105, `ready.catch` main.ts:143, Wächter `stopping` main.ts:134). Der Abbruch von `sleep` beendet die Schleife (main.ts:40). Doppel-Signal ist idempotent. Auffällig: dabei erscheint `migrate gave up`, obwohl nur beendet wurde (F003, LOW).
- Brücke: HEAD /health 200 ohne Rumpf; POST /health 200; HTTP/1.0 ohne Host 200 (Fallback `localhost`, main.ts:72); `GET /mcp` 405 JSON-RPC-Fehler wird durchgereicht; `POST /mcp initialize` kommt als `text/event-stream` (SSE) vollständig an, `serverInfo` vorhanden (Streaming main.ts:75); Query-String `/health?x=1` 200; `//mcp`, `/mcp/` 404. Danach `/health` `requests: 7` = genau die gezählten Nicht-Health-Antworten.
- Host `a b` (ungültig): `new Request` wirft, der catch der Brücke antwortet 500 (main.ts:76-79), diese Antwort wird nicht in `window.record` gezählt (F001, LOW). Host `x/y?z` wird 404, kein Absturz.
- Start-Fehler: belegter Port und `PORT=abc` ergeben einen rohen Node-Stack (EADDRINUSE bzw. ERR_SOCKET_BAD_PORT), Exit 1, ohne ISO-Zeitpunkt, aber ohne URL oder Zugangsdaten (F002, LOW). `DATABASE_URL` fehlt: eine ISO-Zeile, Exit 1.
- `package-lock.json` unverändert (taucht in der Änderungsliste nicht auf), keine neue Abhängigkeit; alle Funktionen <= 50 Zeilen (längste `start`, main.ts:83-109, 27 Zeilen); Code main.ts 146 + health.ts 64 = 210 Zeilen einschließlich Leer- und Kommentarzeilen (< 250). AC-13: geändert sind CLAUDE.md, server/package.json, main.ts, health.ts, main.test.ts; migrate/mcp/orders/transcripts/accounts/migrations unberührt.
**Implementierer:** Alle Proben belegen die Kriterien; die drei Befunde sind kosmetisch und widersprechen keiner AC wörtlich (AC-10 betrifft Inhalte der Logzeilen; der Node-Stack enthält Adresse und Port, keine Zugangsdaten). Offen bleibt in AC-12 nur der CI-Lauf `server.yml` auf dem PR: erst nach dem Push prüfbar, lokal ist alles grün.

## Findings und Bestätigungen

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/main.ts:76
  Description: Fällt `new Request` (ungültige Host-Kopfzeile) oder die Brücke selbst aus, antwortet der catch-Zweig 500, ohne `window.record` aufzurufen.
  Spec requirement: Routentabelle — jede Antwort außer /health geht an window.record
  Conflict: Ein solcher 500 fließt nicht in die Fehlerrate ein. Praktisch irrelevant, der Verkehr kommt über nginx mit gültigem Host.
  Remediation: Optional: Host prüfen oder die Brücke den Status melden lassen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/main.ts:128
  Description: Belegter Port oder ungültiges PORT (Number("abc") ist NaN) lässt `start` mit einem rohen Node-Stack abbrechen (Exit 1), ohne Logzeile mit ISO-Zeitpunkt.
  Spec requirement: Logs: eine Zeile je Ereignis, ISO-Zeitpunkt vorn
  Conflict: Start-Fehler sind nicht als Logzeile formatiert; keine Geheimnisse im Stack.
  Remediation: Optional: `start` in try/catch, logError("listen failed"), Exit 1.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: server/src/main.ts:143
  Description: Wird beendet, während `migrate` noch wiederholt, lehnt der Abbruch `ready` ab und die Zeile `migrate gave up` erscheint, obwohl nur SIGTERM kam.
  Spec requirement: Logs mit Ereignisnamen; `migrate gave up` bei erschöpften Versuchen
  Conflict: Irreführende Logzeile, Exit-Code bleibt korrekt 0.
  Remediation: Optional: Abbruch von Erschöpfung unterscheiden.

Confirmation:
  AC: AC-1
  Code reference: server/src/health.ts:53
  Evidence: Handler liefert genau fünf Schlüssel; Test AC-1 (S1) grün; Lauf 200 mit status ok, db up, migrated true, errorRate 0, requests 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/main.ts:103
  Evidence: Wiederholung mit retryMs/maxAttempts, /health 503 migrated false und /mcp 503 (main.ts:92); Probe mit totem Port bestätigt; Test AC-2 (S1) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/main.ts:92
  Evidence: POST /mcp initialize liefert 200 mit serverInfo (Probe, SSE-Antwort); Test AC-3 (S1) prüft "kein Konto".
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/main.ts:51
  Evidence: Unbekannter Pfad 404, zählt im Fenster (Probe: requests 7 nach 7 Nicht-Health-Antworten).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/src/main.ts:27
  Evidence: error-Listener loggt nur "pool error"; im echten Lauf beim DB-Stopp eine solche Zeile, Prozess lebt, danach wieder 200; Test AC-5 (S1) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/main.ts:107
  Evidence: close() memoisiert (closing ??=), closeAllConnections vor dem Warten, pool.end; zweiter Aufruf wirft nicht; Test AC-6 (S1) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/health.ts:31
  Evidence: requests >= 20 und errorRate > 0.5; Verfall über entry.at >= oldest (health.ts:23); Test AC-7 (S1) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/main.ts:55
  Evidence: /health zählt nicht selbst, andere Pfade schon; extraRoutes (main.ts:90); Test AC-8 (S1) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/health.ts:40
  Evidence: Promise.race mit Timer, Fehler und Zeitüberschreitung ergeben "down", Timer wird gelöscht; Test AC-9 (S1) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/test/main.test.ts:205
  Evidence: Test spiegelt console.log/error (Zeile 49) und prüft Titel, Auftragskennung, Fehlertext, URL; eigene Probe mit Zugangsdaten in der URL: kein Leck, alle Zeilen ISO.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: server/package.json:10
  Evidence: Skript start = node src/main.ts; echter Lauf mit npm start (Runde 1): 200, 503 db down bei lebendem Prozess (gleiche PIDs), 200 nach DB-Neustart, SIGTERM an npm erreicht node, Exit 0, shutting down und stopped.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: server/test/main.test.ts:115
  Evidence: test-local.sh Exit 0, typecheck grün, 112 pass 0 fail 0 skipped; Postgres aufgeräumt. CI-Lauf auf dem PR noch nicht prüfbar (kein PR); lokal vollständig grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: server/src/health.ts:1
  Evidence: Dateiliste = main.ts, health.ts, main.test.ts, package.json, CLAUDE.md (Eintrag server/ ergänzt); migrate/mcp/orders/transcripts/accounts/migrations/project.yml, Swift und package-lock.json unberührt; keine neue Abhängigkeit.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:32ff4c4996714f77e297b4587d58a7e4b0199a85235a5745ef729ee0d3d19185  server/package.json
- sha256:81ba94db90d00c705316c7847df3f45e4b6d6dc9025fb066141ca3bc2c9c4ddc  server/src/health.ts
- sha256:7b3974818b4112be9b1af31fa032d37bd5a011692f55eb1e3d8e816ffa712188  server/src/main.ts
- sha256:0092b6dd7e43520dec8eb5a83d6d34dcf513088203b9fa441cba3da77729b00a  server/test/main.test.ts

## Prüfbasis

- base: 49d576f22144df439b2e780a4a54526fdd09e647
- blob:0792adb2ec8eb50ce84bb6d2a48444d875254fb0  server/package.json
- blob:d0f48a0765ffc0c662464d152e3fd0569e0be3b9  server/src/health.ts
- blob:1c01c9d7871802e34a8a9561c2151da300db4749  server/src/main.ts
- blob:021cc634b05218a7d9105c84638fffdbb83f796f  server/test/main.test.ts
