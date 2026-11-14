# Protokoll A (#615 S4f, Abnahme Abmelden und Löschen gegen den lokalen Dienst)

Lauf 2026-11-14, 07:06–07:14 UTC, Simulator „iPhone 17“ (iOS 27.2, D553352F-…). Ablauf nach Spec Teil 4, Bash mit `set -m`
(Skripte im Scratch-Ordner der Sitzung), Ausgaben unverändert bis auf entfernte Farbcodes und Maskierung: Sitzungstoken stehen
nur als `<S1>`/`<S2>`, der Gerätetoken als `<geräte-token-hex64>`, der Temp-Ordner als `<tmp>`, der Postgres-Port der
Datenbank-Adresse als `<pgport>`. Die Wegwerf-Datenbank hat kein Passwort (`postgres://postgres@127.0.0.1:<port>/postgres`,
Vertrauensauthentifizierung). Kein echtes Gerät berührt, kein Token des Live-Dienstes benutzt.

## Ergebnis

| AC | Stand | Kernzahl / Beleg |
|---|---|---|
| AC-1 | erfüllt | frisch migriert (8 Migrationen): zweimal `rows`, je acht Zeilen `=0` in der Spec-Reihenfolge, kein Konto entstanden |
| AC-2 | erfüllt | ohne `DATABASE_URL` und mit `db.example`: je Ausgang 1 für `rows` und `apple-token`, stderr ohne Token und Platzhaltertext (grep -F); unbekannter Unterbefehl Ausgang 1, Usage nennt `apple-token` und `rows` |
| AC-3 | erfüllt | `apple-token` zweimal → je `apple_tokens=1`; `rows` danach `accounts=1`, `apple_tokens=1`; kein Klartext in einer Ausgabe |
| AC-4 | erfüllt (mit Anmerkung) | ohne Variablen: `testDeleteRemovesTheAccount` übersprungen, `testSignOutEndsOnlyThisSession` übersprungen, 0 Fehler, `** TEST SUCCEEDED **`, Grund je Test „kein lokaler Dienst: LOOSEENDS_DEBUG_SERVICE und LOOSEENDS_DEBUG_SESSION fehlen“. Anmerkung: `sim_proof.py` wertet einen Lauf nur aus übersprungenen Tests als `ergebnis: Unbekannt` und `sim.sh` endet deshalb mit 1 („Beleg ungültig“); xcodebuild selbst endete mit 0. Kein Test ist rot. |
| AC-5 | erfüllt | Test grün (67,7 s); `sessions` 1 → 0, `accounts=1`, übrige Zahlen unverändert (transcripts 1, orders 1, order_results 1, apple_tokens 1, oauth_records 0, device_tokens 1) |
| AC-6 | erfüllt | Test grün (31,3 s); vorher (Schritt 2) accounts, sessions, transcripts, orders, order_results, apple_tokens, device_tokens je 1; nach dem Löschen **alle acht 0** |
| AC-7 | erfüllt | Dienstlog im Löschschritt genau `2026-11-14T07:13:57.704Z apple revoke skipped`, 0× `apple revoke failed` (ganzes Log: 1 / 0) |
| AC-8 | erfüllt | `POST /auth/delete` mit `<S2>` → `http=401`, `rows` bleibt bei acht Nullen |
| AC-9 | erfüllt | `bash -n` sauber; Variablen nur im `test`-Zweig, Export nur bei beiden gesetzt; `test-proof AccountSettingsTests` 8/8 grün, Beleg `ergebnis: Passed` |
| AC-10 | erfüllt | `git diff --stat origin/main...HEAD -- server/src LooseEnds LooseEndsTests project.yml` leer; `test-local.sh` 422/422; `sim.sh unit` grün |
| AC-11 | erfüllt | nach SIGINT kein Prozess (Dienst, Node, Postgres dieses Laufs), Temp-Ordner weg, Ports 63260/63259 nicht offen; `grep -F` nach dem `<S2>`- und Gerätetoken-Wert und Mustersuche nach jedem Token ≥ 40 Zeichen (fängt `<S1>`) ohne Treffer (unten) |
| AC-12 | erfüllt | fünf Testbilder und ein Startbild geöffnet und beschrieben (unten) |

**Widerruf ehrlich benannt (AC-7):** Lokal ist kein Apple erreichbar: `local-service.sh` startet den Dienst ohne jede
`APPLE_*`-Variable. Der Widerruf wird beim Löschen versucht und übersprungen (`apple revoke skipped`, die Zeile aus
`apple-token` ist zudem absichtlich nicht entschlüsselbar). Der Aufruf an Apple selbst ist nur durch die Server-Tests mit
Attrappe belegt (`server/test/auth.test.ts`, Prüfungen `revokes(…)` gegen `https://appleid.apple.com/auth/revoke`, und
`server/test/apple-client.test.ts`, „revoke: …“); `./server/scripts/test-local.sh` ist grün (AC-10).

**`oauth_records`:** bleibt in diesem Lauf vorher und nachher 0 (lokal kein OAuth-Aussteller, keine claude.ai-Verbindung).
Die Null ist darum kein Beleg für das Löschen dieser Zeilen; das belegen die Server-Tests (Known Limitations der Spec).

**Belegdateien und Stand (Nachtrag aus der Validierung):** `test-proof` schreibt jeden Beleg nach `simulator-run.txt`; nach
jedem Lauf wurde er umbenannt. Die Rohausgaben unten nennen darum `simulator-run.txt`, gemeint sind: AC-4 →
`simulator-run-skip.txt`, AC-5 → `simulator-run-signout.txt`, AC-6 → `simulator-run-delete.txt`; das heutige
`simulator-run.txt` ist der Lauf `AccountSettingsTests` (AC-9, Kopie `simulator-run-accountsettings.txt`). Das Startbild aus
Schritt 2 heißt `schritt2-app.png` (in der Rohausgabe `step2-app.png`). Die Belege nennen `head: 2b3d192`, weil
`local-fixture.ts` und `sim.sh` erst nach den Läufen im Commit `76e2c90` festgeschrieben wurden; beide Dateien wurden zuletzt
um 07:04 UTC geändert, vor dem ersten Lauf (07:06 UTC), und danach nicht mehr: die Läufe liefen auf genau dem Inhalt dieses
Commits.

## AC-1 und AC-2: Fixture auf einer frisch migrierten Wegwerf-Datenbank

Eigene Wegwerf-Datenbank (wie `local-service.sh`, aber ohne die Startsitzung, damit es wirklich kein Konto gibt), danach
aufgeräumt.

```
$ (frische Wegwerf-Datenbank wie in local-service.sh, Migrationen über server/src/migrate.ts angewandt, kein Konto)
migriert: 8
$ DATABASE_URL=postgres://postgres@127.0.0.1:<port>/postgres node server/scripts/local-fixture.ts rows   # Aufruf 1
accounts=0
sessions=0
transcripts=0
orders=0
order_results=0
apple_tokens=0
oauth_records=0
device_tokens=0
exit=0
$ DATABASE_URL=postgres://postgres@127.0.0.1:<port>/postgres node server/scripts/local-fixture.ts rows   # Aufruf 2
accounts=0
sessions=0
transcripts=0
orders=0
order_results=0
apple_tokens=0
oauth_records=0
device_tokens=0
exit=0
--- AC-2
$ (DATABASE_URL ungesetzt) node server/scripts/local-fixture.ts rows
exit=1
local-fixture: DATABASE_URL fehlt
grep -F Platzhaltertext in stderr: kein Treffer
$ DATABASE_URL=postgres://u@db.example:5432/x node server/scripts/local-fixture.ts rows
exit=1
local-fixture: nur eine lokale Datenbank (127.0.0.1, localhost)
grep -F Platzhaltertext in stderr: kein Treffer
$ (DATABASE_URL ungesetzt) node server/scripts/local-fixture.ts apple-token
exit=1
local-fixture: DATABASE_URL fehlt
grep -F Platzhaltertext in stderr: kein Treffer
$ DATABASE_URL=postgres://u@db.example:5432/x node server/scripts/local-fixture.ts apple-token
exit=1
local-fixture: nur eine lokale Datenbank (127.0.0.1, localhost)
grep -F Platzhaltertext in stderr: kein Treffer
$ node server/scripts/local-fixture.ts unbekannt
local-fixture: Unterbefehl: session | transcript | order <text> | result <id> | due <taskID> <datum> | apple-token | rows
exit=1
$ (Gegenprobe nach den abgewiesenen Aufrufen: rows auf der Wegwerf-Datenbank)
accounts=0
sessions=0
transcripts=0
orders=0
order_results=0
apple_tokens=0
oauth_records=0
device_tokens=0
aufgeräumt: Temp-Ordner weg
```


## AC-4: ohne Umgebung übersprungen

Übersprungene Tests einzeln: `AccountLocalServiceTests/testDeleteRemovesTheAccount` (übersprungen),
`AccountLocalServiceTests/testSignOutEndsOnlyThisSession` (übersprungen). Grund im Ergebnisbündel je Test: „Test skipped -
kein lokaler Dienst: LOOSEENDS_DEBUG_SERVICE und LOOSEENDS_DEBUG_SESSION fehlen“. Beleg: `simulator-run-skip.txt`
(`xcodebuild: ** TEST SUCCEEDED **`, `tests: 2 gesamt, 0 bestanden, 0 fehlgeschlagen, 2 übersprungen`).

```
[sim] UI-Test mit Beleg: AccountLocalServiceTests → docs/artifacts/feat-615-s4f-abnahme/simulator-run.txt
    ⊘ testDeleteRemovesTheAccount (2.415 seconds)
    ⊘ testSignOutEndsOnlyThisSession (0.230 seconds)
Executed 2 tests, with 2 tests skipped and 0 failures (0 unexpected) in 2.644 (2.652) seconds
Executed 2 tests, with 2 tests skipped and 0 failures (0 unexpected) in 2.644 (2.653) seconds
Executed 2 tests, with 2 tests skipped and 0 failures (0 unexpected) in 2.644 (2.655) seconds
Test Succeeded
[sim_proof] ergebnis: Unbekannt
[sim] Beleg ungültig (sim_proof 1): docs/artifacts/feat-615-s4f-abnahme/simulator-run.txt
```


## Schritt 1: Dienst starten

```
$ bash start.sh   # set -m; nohup server/scripts/local-service.sh >svc.log 2>&1 &
pid 62117
Postgres on 127.0.0.1:63259, data in <tmp>
Dienst auf http://localhost:63260 (pid 62173)
STATE=<tmp>/state.env
```

`state.env` gelesen (`SERVICE_URL=http://localhost:63260`, `DATABASE_URL`, `SESSION_TOKEN` = `<S1>`).

## Schritt 2: Zeilen füllen (enthält AC-3)

```
# Schritt 2a, 2026-11-14T07:08:59Z
$ node server/scripts/local-fixture.ts rows
accounts=1
sessions=1
transcripts=0
orders=0
order_results=0
apple_tokens=0
oauth_records=0
device_tokens=0
exit=0
$ node server/scripts/local-fixture.ts apple-token
apple_tokens=1
exit=0
$ node server/scripts/local-fixture.ts apple-token
apple_tokens=1
exit=0
$ node server/scripts/local-fixture.ts rows
accounts=1
sessions=1
transcripts=0
orders=0
order_results=0
apple_tokens=1
oauth_records=0
device_tokens=0
exit=0
$ node server/scripts/local-fixture.ts order Aufgabe aus Protokoll A
58703d78-5705-42a3-9013-dbb6e2a81681
exit=0
$ curl -s -X POST $SERVICE_URL/app/device -H 'authorization: Bearer <S1>' -H 'x-device: 1161c32f-bd54-4262-beb7-3dc502dc9c60' -H 'content-type: application/json' -d '{"token":"<geräte-token-hex64>","environment":"sandbox"}'
http=204 body=
$ node server/scripts/local-fixture.ts rows
accounts=1
sessions=1
transcripts=0
orders=1
order_results=0
apple_tokens=1
oauth_records=0
device_tokens=1
exit=0
```


```
# Schritt 2b, 2026-11-14T07:10:02Z
$ LOOSEENDS_SIM_SIGN=1 ./scripts/sim.sh build   -> Build Succeeded (exit 0)
$ LOOSEENDS_SIM_SIGN=1 ./scripts/sim.sh launch -LEDebugService $SERVICE_URL -LEDebugSession <S1> -onboardingDone YES -AppleLanguages (en) -AppleLocale en_US
com.henning.looseends: 66070
[sim] App gestartet (com.henning.looseends).
$ node server/scripts/local-fixture.ts result 58703d78-5705-42a3-9013-dbb6e2a81681   # nach 22 s
result
outcome=done
taskID=ED9D41AB-8561-43AC-9349-7E7DD3D47B78
$ node server/scripts/local-fixture.ts transcript
tasks=1
Aufgabe aus Protokoll A
(Bildschirmfoto des Simulators: step2-app.png)
$ xcrun simctl terminate <udid> com.henning.looseends
exit=0
$ node server/scripts/local-fixture.ts rows
accounts=1
sessions=1
transcripts=1
orders=1
order_results=1
apple_tokens=1
oauth_records=0
device_tokens=1
exit=0
```


## Schritt 3: Abmelden (AC-5)

```
# Schritt signout, 2026-11-14T07:11:13Z
$ LOOSEENDS_DEBUG_SERVICE=$SERVICE_URL LOOSEENDS_DEBUG_SESSION=<S1> ./scripts/sim.sh test-proof AccountLocalServiceTests/testSignOutEndsOnlyThisSession
exit=0
    ✔ testSignOutEndsOnlyThisSession (67.714 seconds)
[sim] UI-Test bestanden, Beleg: docs/artifacts/feat-615-s4f-abnahme/simulator-run.txt
[sim] UI-Test mit Beleg: AccountLocalServiceTests/testSignOutEndsOnlyThisSession → docs/artifacts/feat-615-s4f-abnahme/simulator-run.txt
Executed 1 test, with 0 failures (0 unexpected) in 67.714 (67.731) seconds
Executed 1 test, with 0 failures (0 unexpected) in 67.714 (67.739) seconds
Executed 1 test, with 0 failures (0 unexpected) in 67.714 (67.744) seconds
Test Succeeded
# Ende test-proof 2026-11-14T07:13:08Z
$ node server/scripts/local-fixture.ts rows
accounts=1
sessions=0
transcripts=1
orders=1
order_results=1
apple_tokens=1
oauth_records=0
device_tokens=1
exit=0
$ (Dienstlog seit Beginn dieses Schritts, Zeilen 3 bis Ende)
(Ende Dienstlog-Auszug)
```


Beleg: `simulator-run-signout.txt` (`ergebnis: Passed`), Bilder `local-signed-in.png`, `local-signed-out.png`.

## Schritt 4: neue Sitzung und Löschen (AC-6, AC-7)

```
# Schritt 4a, 2026-11-14T07:13:19Z
$ node server/scripts/local-fixture.ts session
<S2>
exit=0
$ node server/scripts/local-fixture.ts rows
accounts=1
sessions=1
transcripts=1
orders=1
order_results=1
apple_tokens=1
oauth_records=0
device_tokens=1
exit=0
```


```
# Schritt delete, 2026-11-14T07:13:19Z
$ LOOSEENDS_DEBUG_SERVICE=$SERVICE_URL LOOSEENDS_DEBUG_SESSION=<S2> ./scripts/sim.sh test-proof AccountLocalServiceTests/testDeleteRemovesTheAccount
exit=0
    ✔ testDeleteRemovesTheAccount (31.295 seconds)
[sim] UI-Test bestanden, Beleg: docs/artifacts/feat-615-s4f-abnahme/simulator-run.txt
[sim] UI-Test mit Beleg: AccountLocalServiceTests/testDeleteRemovesTheAccount → docs/artifacts/feat-615-s4f-abnahme/simulator-run.txt
Executed 1 test, with 0 failures (0 unexpected) in 31.295 (31.303) seconds
Executed 1 test, with 0 failures (0 unexpected) in 31.295 (31.309) seconds
Executed 1 test, with 0 failures (0 unexpected) in 31.295 (31.310) seconds
Test Succeeded
# Ende test-proof 2026-11-14T07:14:04Z
$ node server/scripts/local-fixture.ts rows
accounts=0
sessions=0
transcripts=0
orders=0
order_results=0
apple_tokens=0
oauth_records=0
device_tokens=0
exit=0
$ (Dienstlog seit Beginn dieses Schritts, Zeilen 3 bis Ende)
2026-11-14T07:13:57.704Z apple revoke skipped
(Ende Dienstlog-Auszug)
```


Beleg: `simulator-run-delete.txt` (`ergebnis: Passed`), Bilder `local-before-delete.png`, `local-delete-dialog.png`,
`local-after-delete.png`.

## Schritt 5 und 6: Gegenprobe (AC-8) und Aufräumen (AC-11)

```
# Schritt 5, 2026-11-14T07:14:20Z
$ curl -s -o /dev/null -w '%{http_code}' -X POST $SERVICE_URL/auth/delete -H 'authorization: Bearer <S2>'
http=401
$ node server/scripts/local-fixture.ts rows
accounts=0
sessions=0
transcripts=0
orders=0
order_results=0
apple_tokens=0
oauth_records=0
device_tokens=0
exit=0
$ grep -c 'apple revoke skipped' <tmp>/service.log ; grep -c 'apple revoke failed' <tmp>/service.log
1
0
$ cat <tmp>/service.log   # gesamtes Dienstlog des Laufs
2026-11-14T07:08:39.544Z listening
2026-11-14T07:08:39.592Z migrated
2026-11-14T07:13:57.704Z apple revoke skipped
# Schritt 6, 2026-11-14T07:14:20Z
$ kill -INT 62117   # local-service.sh (Prozessgruppe eigen, set -m)
$ ps -p 62117 ; pgrep -f 'node src/main.ts' ; pgrep -f '<tmp>/pg'
local-service: kein Prozess
node src/main.ts: kein Prozess
postgres dieses Laufs: kein Prozess
$ test -d <tmp>
Temp-Ordner weg
$ lsof -nP -iTCP:63260 -iTCP:63259 -sTCP:LISTEN
kein offener Port (63260 Dienst, 63259 Postgres)
Dienstlog der Startausgabe (svc.log):
Postgres on 127.0.0.1:63259, data in <tmp>
Dienst auf http://localhost:63260 (pid 62173)
```


## AC-9: Durchreiche

```
$ bash -n scripts/sim.sh
bash -n scripts/sim.sh: sauber
$ grep -n 'LOOSEENDS_DEBUG_' scripts/sim.sh
21:#     LOOSEENDS_DEBUG_SERVICE=<url> LOOSEENDS_DEBUG_SESSION=<token> davor: gehen als TEST_RUNNER_… an den Test (#615 S4f);
323:    if [ "${1:-}" = test ] && [ -n "${LOOSEENDS_DEBUG_SERVICE:-}" ] && [ -n "${LOOSEENDS_DEBUG_SESSION:-}" ]; then
324:        export TEST_RUNNER_LOOSEENDS_DEBUG_SERVICE="$LOOSEENDS_DEBUG_SERVICE" TEST_RUNNER_LOOSEENDS_DEBUG_SESSION="$LOOSEENDS_DEBUG_SESSION"
654:    [ -z "${1:-}" ] && { error "Usage: [LOOSEENDS_DEBUG_SERVICE=<url> LOOSEENDS_DEBUG_SESSION=<token>] ./scripts/sim.sh test-proof <Testklasse>[/<test>] (Variablen nur gegen local-service.sh, nie Live-Token)"; return 1; }
```

Zeile 21 ist der Kommentar im Kopf, 654 die Usage-Meldung; die einzige wirksame Stelle (323–324) liegt in `run_xcodebuild`
und greift nur, wenn das erste Argument `test` ist und beide Variablen nicht leer sind. Ohne sie bleibt der Aufruf gleich.

```
$ ./scripts/sim.sh test-proof AccountSettingsTests   # ohne LOOSEENDS_DEBUG_*
    ✔ testDeleteCancelKeepsSignedIn (25.471 seconds)
    ✔ testDeleteConfirmSignsOut (29.050 seconds)
    ✔ testNotAllowedShowsItsSentence (23.768 seconds)
    ✔ testRetryLaterShowsItsSentence (33.787 seconds)
    ✔ testSignedOutShowsGroupBelowICloud (21.173 seconds)
    ✔ testSigningInKeepsDisabledAppleButton (32.124 seconds)
    ✔ testSignInShowsSignedInRows (24.804 seconds)
    ✔ testSignOutNeedsNoConfirmation (27.619 seconds)
[sim] UI-Test bestanden, Beleg: docs/artifacts/feat-615-s4f-abnahme/simulator-run.txt
Executed 8 tests, with 0 failures (0 unexpected) in 217.797 (217.810) seconds
Executed 8 tests, with 0 failures (0 unexpected) in 217.797 (217.821) seconds
Executed 8 tests, with 0 failures (0 unexpected) in 217.797 (217.826) seconds
Test Succeeded
(Beleg simulator-run-accountsettings.txt:)
ergebnis: Passed
xcodebuild: ** TEST SUCCEEDED **
tests: 8 gesamt, 8 bestanden, 0 fehlgeschlagen, 0 übersprungen
```


## AC-10: kein Produktcode, Server und App grün

```
$ git diff --stat origin/main...HEAD -- server/src LooseEnds LooseEndsTests project.yml
(leer)
$ git diff --stat -- server/src LooseEnds LooseEndsTests project.yml   # zusätzlich der nicht committete Arbeitsbaum
(leer)
$ ./server/scripts/test-local.sh   # exit=0
ℹ tests 422
ℹ pass 422
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
✔ revoke: anfrage (0.786375ms)
✔ revoke: erfolg (0.331583ms)
✔ revoke: apple-fehler und status (Fallliste) (1.618333ms)
✔ revoke: unavailable und zeitlimit (Fallliste) (0.936709ms)
✔ revoke fehlbedienung: wirft ohne netz (0.217292ms)
✔ revoke: silence (3.356541ms)
$ ./scripts/sim.sh unit   # exit=0
✔-Zeilen: 1257, ✖-Zeilen: 0
Executed 24 tests, with 0 failures (0 unexpected) in 11.913 (11.978) seconds
[sim] Unit-Tests bestanden.
Test Succeeded
[sim] Messstrecken: 3 von 6 übersprungen (nicht gemessen, nicht bestanden):
[sim]   RawSentenceReportTests – fehlt: loose-ends-rawtexts.json
[sim]   SelfConsistencyReportTests – fehlt: selfconsistency-run.json
[sim]   TextFormModelReportTests – fehlt: textform-run.json
[sim] Latenzschutz (#274):
[sim]   The first word arrives within 3 s of speech start – NICHT gemessen: Sprache de_DE wird hier nicht unterstützt (isAvailable false, supportedLocales.count 0, installedLocales.count 0)
[sim]   The final text keeps the key words – NICHT gemessen: Sprache de_DE wird hier nicht unterstützt (isAvailable false, supportedLocales.count 0, installedLocales.count 0)
```


## AC-11: kein Token im Protokoll

```
$ grep -cF "$S2" … ; grep -cF "$DEVTOK" … ; grep -cF <Platzhaltertext> … ; grep -cE '[A-Za-z0-9_-]{40,}' …   # S1 lag nur in <tmp>/state.env, beim Aufräumen gelöscht: Mustersuche
S2-Wert:           0 Treffer
Gerätetoken-Wert:  0 Treffer
Platzhaltertext:   0 Treffer
Muster [A-Za-z0-9_-]{40,} (S1, jeder lange Token): 0 Treffer
S2-Wert in allen Belegen des Ordners (*.md *.txt *.json): 0 Dateien
```

Gegenprobe der Mustersuche: auf die Datei mit dem echten `<S2>` (43 Zeichen) angewandt ergibt sie 1 Treffer; sie fängt also
auch `<S1>` (gleiches Format aus `createSession`). Die Datenbank-Adresse hat keinen Passwortteil; es gibt keinen weiteren
geheimen Wert. Auch die Belege `simulator-run-*.txt` und `summary*.json` enthalten den `<S2>`-Wert nicht.

## AC-12: Bilder, geöffnet und beschrieben

- `local-signed-in.png` (08:12 Ortszeit, Abmeldetest vor dem Tippen): Einstellungen, Gruppe „iCloud“ („This device only“),
  darunter Gruppe „Claude“ mit der Zeile „Signed in with Apple — This device“ (verbunden), „Sign out“ und „Delete account …“,
  Fußzeile „Claude sees your open tasks. Signing out disconnects only this device. …“. Kein Anmeldedialog, kein Mitteilungsdialog.
- `local-signed-out.png` (08:12, nach „Sign out“): Gruppe „Claude“ zeigt nur noch den schwarzen Knopf „Sign in with Apple“ und
  den Einleitungssatz „Sign in with Apple so Claude can read your open tasks and add new ones. Without signing in, nothing
  leaves this device.“; keine Rückfrage zu sehen; unten „Version 1.0.1 (1)“.
- `local-before-delete.png` (08:13, Löschtest vor dem Tippen): wie oben verbunden, „Signed in with Apple — This device“,
  „Sign out“, „Delete account …“.
- `local-delete-dialog.png` (08:13): Rückfrage als Popover über „Delete account …“: Titel „Delete account?“, Text „Claude will
  no longer see your tasks. Your tasks in the app stay as they are.“, roter Knopf „Delete account“.
- `local-after-delete.png` (08:14, nach der Bestätigung): Gruppe „Claude“ mit dem Knopf „Sign in with Apple“ und dem
  Einleitungssatz, die Zeile „verbunden“ und die beiden Aktionszeilen sind weg.
- `schritt2-app.png` (08:10, Schritt 2 vor dem Beenden): Startseite (keine Einführung) „Nothing presses today.“, Samstag 14. Nov.,
  „New — 1 to look over“, „Now 0“, Inhaltsliste mit „New 1“ und „All open 1“: die per Auftrag angelegte „Aufgabe aus Protokoll A“.
  Kein Mitteilungsdialog über dem Bild.
