# Adversary Dialog — feat-795-s5a2b-weckruf-verdrahten
Spec: docs/specs/feat-795-schnitt-5a2b-weckruf-verdrahten.md
Datum: 2026-11-14 10:46

## Checkliste
- [x] **AC-1:** Jedes Auftragswerkzeug weckt genau einmal: GIVEN `mcpHandler(pool, { wake })` mit einem zählenden `wake` und ein Konto mit Abschrift WHEN `capture_task`, `complete_task`, `set_due`, `set_next`, `park_task` und `add_subtask` je einmal erfolgreich aufgerufen werden THEN antwortet jedes mit `state: "waiting"`, und `wake` wurde je Aufruf genau einmal mit der Konto-ID des Aufrufers aufgerufen (insgesamt sechsmal, nie mit einem anderen Konto). Test: „mcp-wake: jedes auftragswerkzeug weckt genau einmal“.
- [x] **AC-2:** `duplicate` weckt nicht: GIVEN ein bereits abgelegter Auftrag WHEN `storeOrder` mit derselben ID und demselben Konto erneut aufgerufen wird THEN `putOrder` meldet `duplicate`, die Antwort entspricht der bisherigen für diesen Fall, und `wake` wird nicht aufgerufen; der erste Aufruf mit neuer ID hat genau einmal geweckt. Test: „mcp-wake: duplicate weckt nicht“.
- [x] **AC-3:** Weckfehler stören den Auftrag nicht: GIVEN ein `wake`, das (a) synchron wirft, (b) ablehnt, (c) erst nach 200 ms auflöst WHEN `capture_task` aufgerufen wird THEN antwortet das Werkzeug in allen drei Fällen ohne `isError` mit `state: "waiting"` (bei (c) ohne auf `wake` zu warten, die Antwort trifft vor dem Auflösen ein), der Auftrag liegt in `orders`, und der Handler `process.on("unhandledRejection")` bleibt leer. Test: „mcp-wake: weckfehler stoert nicht“.
- [x] **AC-4:** Abgelehnte Aufrufe wecken nicht: GIVEN `capture_task` mit leerem Text, `set_due` mit geänderter Abschrift (`generatedAt` stimmt nicht), `complete_task` mit unbekannter Aufgabe, ein Aufruf ohne Konto und ein Auftrag, den `checkOrder` ablehnt (über `storeOrder`) WHEN sie laufen THEN antwortet jeder mit seiner bisherigen Fehlermeldung und `isError`, nichts liegt in `orders`, und `wake` wird nie aufgerufen. Test: „mcp-wake: abgelehnte werkzeuge wecken nicht“.
- [x] **AC-5:** Ohne `wake` wie bisher: GIVEN `mcpHandler(pool)` ohne zweites Argument WHEN die sechs Auftragswerkzeuge laufen THEN antworten sie wie vor diesem Schnitt, die Aufträge liegen in `orders`, es gibt keinen Fehler und keine unbehandelte Ablehnung; die bestehenden Tests in `mcp-write.test.ts` laufen unverändert grün. Test: „mcp-wake: ohne wake wie bisher“.
- [x] **AC-6:** Halbe Konfiguration bricht den Start ab: GIVEN der echte Prozess (`spawn`) mit je genau drei der vier `APNS_*`-Variablen (je eine fehlt) und mit einem unlesbaren `APNS_PRIVATE_KEY` WHEN er startet THEN endet er mit Exit 1, schreibt auf stderr `apns config invalid: ` mit dem Namen der betroffenen Variable, bindet den Port nie, und weder der Wert des Schlüssels noch von Team, Schlüssel-ID oder Topic steht in der Ausgabe. Test: „main: halbe apns-konfiguration bricht ab“.
- [x] **AC-7:** Ohne `APNS_*` startet der Dienst wie bisher: GIVEN der echte Prozess ohne `APNS_*` und mit sonst gültiger Umgebung WHEN er startet THEN beantwortet `/health` nach dem Migrieren 200, es gibt keine Zeile `apns config invalid`, und `capture_task` legt einen Auftrag ab, ohne dass ein Weckruf versucht wird (keine Zeile `apns …` auf stderr). Test: „main: keine apns-variablen startet wie bisher“.
- [x] **AC-8:** Kette Werkzeug → Waker → Tabelle → Senden: GIVEN `start({ apns: { config, send } })` mit gültiger Config, Stellvertreter-`send` und einem Konto mit einem per `putDevice` gemeldeten Gerät WHEN `capture_task` über `/mcp` aufgerufen wird THEN erhält der Stellvertreter genau einen Aufruf mit dem Token des Geräts und dem Topic der Config; ein zweites Konto mit Gerät bekommt keinen Aufruf; mit einem `send`, das 410 `Unregistered` meldet, ist die Zeile danach aus `device_tokens` weg. Kein echter Apple-Aufruf. Test: „main: capture_task sendet ueber den waker“.
- [x] **AC-9:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/mcp.ts`, `server/src/main.ts`, `server/test/mcp-wake.test.ts`, `server/test/main.test.ts` und höchstens `CLAUDE.md`; `apns.ts`, `devices.ts`, `orders.ts`, `app-routes.ts`, `.github/`, `project.yml`, `server/package.json` und jede Swift-Datei sind unverändert (keine neue Abhängigkeit); jede Funktion hat höchstens 50 Zeilen. **Kein dauerhafter Test** (ein Test gegen `origin/main` scheitert im flachen CI-Checkout): Beleg einmalig in `/60-validate`, Befehl, Ausgabe und Funktionslängen im Validierungsprotokoll.
- [x] **AC-10:** Doku: `docs/reference/claude-abschrift-vertrag.md` enthält einen Absatz „Weckruf“ (nach jedem neu abgelegten Auftrag stille Mitteilung `content-available`, Schlüssel `looseends`, an alle Geräte des Kontos; kein Weckruf bei bekannter ID; ohne Schlüssel im Dienst keiner; die App holt wie bisher selbst) und **keinen neuen** ```json-Block (`grep -c '```json'` gleich dem Stand auf `origin/main`); `CLAUDE.md` nennt `src/apns.ts` nicht mehr als „not wired yet“, sondern als in `mcp.ts`/`main.ts` eingehängt mit `APNS_*` alles oder nichts. **Kein dauerhafter Test**: Beleg einmalig in `/60-validate`.

## Dialog

### Runde 1
**Adversary:** Testlauf `./server/scripts/test-local.sh` (Ausgabe in adversary-test-output.txt): 441 pass, 0 fail, 0 skipped, Typecheck ohne Fehler; die neuen Tests (mcp-wake x5, main x3) laufen grün, die Flake migrate AC-3 trat nicht auf. Angriffe: (1) Weckruf bei `duplicate`? Die Bedingung steht in `storeOrder` als `stored === "stored"`, `putOrder` liefert `duplicate` nur bei `ON CONFLICT DO NOTHING` ohne Zeile. (2) Synchroner Wurf von `wake`: `Promise.resolve().then(() => wake(owner))` verschiebt den Aufruf in einen Mikrotask, der Wurf wird zur Ablehnung und vom `.catch` geschluckt; kein `await`, also keine Wartezeit. (3) `wake`-Vorrang: `wakeFor` gibt ein übergebenes `wake` zurück, bevor `config` geprüft wird. (4) `main()` ruft `apnsConfigOrExit` nach den OAuth-Schlüsseln und vor `publicUrl`, Pool und Port; die Meldung enthält nur `error.message` des Absenders. Der AC-6-Test beweist: Exit 1, kein Datenbankzugriff (Fake-DB-Socket), kein "listening", keine Werte (Team, Key-ID, Topic, PEM-Zeile) in der Ausgabe. (5) Alle sechs Werkzeugfabriken reichen `wake` durch (Diff geprüft: capturing, completing, lining, parking, subtasking, setting). (6) Ablehnungen (`Text fehlt`, `kein Konto`, `expected`-Fehler, `checkOrder`) kehren vor `putOrder` zurück. (7) AC-9: der Diff-Befehl aus AC-9 nennt genau CLAUDE.md, main.ts, mcp.ts, main.test.ts, mcp-wake.test.ts; apns.ts, devices.ts, orders.ts, app-routes.ts, package.json, Workflow-Ordner, project.yml, Swift unverändert. Funktionslängen: nur `mcpHandler` mit 103 Zeilen über 50, auf origin/main ebenfalls 103 (nur Signatur geändert); `storeOrder`, `wakeFor`, `apnsConfigOrExit` kurz. (8) AC-10: Anzahl der json-Blöcke 3 auf origin/main und im Arbeitsbaum; Absatz "Weckruf (#795 S5a-2b)" vorhanden mit content-available, `looseends`, alle Geräte, kein Weckruf bei bekannter ID, ohne APNS_* keiner, App holt selbst; CLAUDE.md enthält "not wired" nicht mehr. Erste Runde ohne Treffer: Gegenprobe in Runde 2.
**Implementierer:** Bedingung und Fehlerfestigkeit wie belegt; die mcpHandler-Länge ist Altbestand, nur die Signatur wurde geändert.

### Runde 2
**Adversary:** Tiefere Prüfung. (a) Test-Schärfe: Der Duplicate-Test nutzt dieselbe ID in Kleinschreibung und prüft Antwort, Zählung und genau einen Eintrag in orders; der Test mit `wake`, das nach 200 ms auflöst, prüft `state.resolved === false` zum Antwortzeitpunkt, also echte Entkopplung; unhandledRejection wird für alle drei Fälle gesammelt. (b) `createWaker` mit `send: undefined`: die Destrukturierung mit Default `send = sendHttp2` greift bei undefined, Typecheck grün. (c) Herunterfahren: Festlegung 6 verlangt kein Warten; `close()` unverändert; der Waker fängt DB-Fehler selbst. (d) AC-7-Abweichung: Die Spec formuliert "echter Prozess ... capture_task legt einen Auftrag ab"; der Test startet den echten Prozess nur für `/health` und Log-Freiheit, den Auftrag legt er in einem In-Process-Dienst ohne apns ab. Die Kernaussage (ohne `apns` kein Weckruf, keine apns-Zeile) ist abgedeckt; schwach, aber nicht falsch. (e) Weckruf nach geschlossenem Pool erzeugt keine Ausgabe, der Waker fängt. (f) Zwei Aufträge = zwei Weckrufe, wie in der Spec bewusst.
**Implementierer:** Abweichung (d) ist bekannt: Capture im echten Prozess bräuchte ein gültiges Bearer-Token ohne OAuth-Schlüssel, daher In-Process; die Aussage hängt an derselben Verdrahtung.

### Structured Findings

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: server/test/main.test.ts:785
  Description: Der Test "main: keine apns-variablen startet wie bisher" legt den Auftrag in einem In-Process-Dienst ab, nicht im gespawnten Prozess; der Prozess wird nur auf /health 200 und fehlende apns-Zeile geprüft.
  Spec requirement: AC-7 — echter Prozess ohne APNS_*, capture_task legt einen Auftrag ab, keine apns-Zeile auf stderr
  Conflict: Wortlaut der Spec strenger als der Test; das Verhalten selbst ist über wakeFor (main.ts:151) eindeutig.
  Remediation: Optional; im Prozess ist ein Capture ohne OAuth-Schlüssel nicht ohne Weiteres möglich. Kein Blocker.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: server/src/mcp.ts:192
  Description: mcpHandler ist 103 Zeilen lang (Festlegung 7: höchstens 50 je Funktion), unverändert gegenüber origin/main, nur die Signatur wurde geändert (zweites Argument).
  Spec requirement: AC-9 — jede Funktion höchstens 50 Zeilen
  Conflict: Wörtlich verletzt, aber Altbestand, vom Schnitt nicht verschlechtert; ein Umbau läge außerhalb des Umfangs.
  Remediation: In /60-validate als Altbestand vermerken; ggf. eigenes Refactoring-Ticket.

### Confirmations

Confirmation:
  AC: AC-1
  Code reference: server/test/mcp-wake.test.ts:74
  Evidence: Sechs Werkzeuge, je ein Aufruf, genau ein Weckruf je Aufruf, immer Konto "henning"; Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/mcp.ts:117
  Evidence: Weckruf nur bei `stored === "stored"`; Test mcp-wake.test.ts:87 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/mcp.ts:117
  Evidence: `void Promise.resolve().then(() => wake(owner)).catch(() => {})` ohne await; drei Fälle im Test, keine unhandledRejection.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/test/mcp-wake.test.ts:129
  Evidence: Fünf Ablehnungswege, `wake` nie, orders leer.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/test/mcp-wake.test.ts:156
  Evidence: Ohne wake sechs Aufträge, plus direktes storeOrder; Gesamtlauf 441 grün inkl. mcp-write.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/main.ts:306
  Evidence: apnsConfigOrExit vor publicUrl, Pool und Port; Test main.test.ts:737 prüft Exit 1, Variablenname, keine Werte, kein Pool.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/main.ts:151
  Evidence: Ohne config und wake gibt wakeFor undefined zurück; Test main.test.ts:785 grün (siehe F001, LOW).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/main.ts:215
  Evidence: start() baut den Waker einmal und reicht ihn an mcpHandler; Test main.test.ts:820 prüft Token, Topic, fremdes Konto, 410 löscht die Zeile.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/mcp.ts:108
  Evidence: Dateiliste exakt wie gefordert (inkl. CLAUDE.md); keine verbotene Datei geändert; einzige Funktion über 50 Zeilen ist der unveränderte Altbestand mcpHandler (F002).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/src/main.ts:275
  Evidence: Vertrag enthält den Absatz Weckruf, json-Blöcke 3 = 3 wie auf origin/main; CLAUDE.md "not wired" entfernt.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:34d588c4b17a787ab8dca9cb564af6ef0592fbba16c84c01505736006fb52f55  server/src/main.ts
- sha256:0397d604c8adb3ea1904368c58f36aac385ca323df4502a0efb36ec91daaaa34  server/src/mcp.ts
- sha256:efb46c20b7cc3636ded090be4f64009bda3126f3ed5a7c9342d86992c446c06a  server/test/main.test.ts
- sha256:8d404a95b662dc19d3d8f4cddd5eb20409de4be3b85833f4873ea3cb78e7054b  server/test/mcp-wake.test.ts

## Prüfbasis

- base: ab79cb30c1a73a902dca9b6e9d12a7db5081f594
- blob:596278ee9086d894b24fbd902b98380edf2ac7c1  server/src/main.ts
- blob:50d17db6df52759355ee852b99d3510e1481b1cc  server/src/mcp.ts
- blob:50a10aebaa886cf5657735cf776e21c0beec03b5  server/test/main.test.ts
- blob:89623cfd64ba02062571d581b901e7716883a161  server/test/mcp-wake.test.ts
