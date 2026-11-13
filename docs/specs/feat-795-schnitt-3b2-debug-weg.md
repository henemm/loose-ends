---
entity_id: feat-795-schnitt-3b2-debug-weg
type: feature
created: 2026-11-13
updated: 2026-11-13
status: draft
workflow: feat-795-s3b2-debug-weg
---

# Spec: Debug-Weg zum lokalen Dienst und Nachweis A/B, Schnitt S3b-2 (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S3b-2; das Issue bleibt offen (`Refs #795`, nie `Closes #795`): S5 (Weckruf, Hintergrund-Auffrischen, Gerätenachweis über TestFlight) folgt.
Analyse: `docs/context/feat-795-s3b2-debug-weg.md` (Abschnitt „Analysis“, verbindlich).
Vorgänger: S3a (`ClaudeSync`, PR #911), S3b-1 (`ClaudeSyncTrigger`, PR #913; dessen Spec nennt S3b-2 unter „Out of Scope / Folgeschnitte“).
Es sind **vier Code-/Testdateien**: `AccountWiring.swift` (geändert), `AccountSectionTests.swift` (geändert), `server/scripts/local-service.sh` (neu), `server/scripts/local-fixture.ts` (neu). Beleg und `CLAUDE.md`-Zeilen zählen nicht zum Dateilimit.

## Für den PO

Für dich ändert sich nichts. Dieser Schnitt ist ein Entwicklerweg: er lässt mich die Verbindung zwischen App und Dienst für Claude einmal vollständig im Simulator durchspielen, gegen einen echten, nur auf diesem Mac laufenden Dienst, ohne Anmeldung bei Apple. Die App aus dem Store und deine TestFlight-App kennen diesen Weg nicht und können ihn nicht einschalten. Du musst nichts entscheiden und nichts tun.

## Purpose

S3a/S3b-1 haben Durchgang und Auslöser nur gegen Stellvertreter belegt (Lehre aus #136: eine Attrappe beweist die Kette nicht). S3b-2 schließt die Kette gegen den echten Dienstcode und liefert den Nachweis A/B der Definition of Done von #795: Abschrift von A im Dienst lesbar, Auftrag von B geholt und als Revision „Claude“ ausgeführt, Ergebnis im Dienst.

### Teil 1: Debug-Weg in der App (`AccountWiring.swift`)

Neue reine Funktion `AccountWiring.debugService(arguments: [String], debugBuild: Bool = AccountWiring.debugBuild) -> (url: URL, token: String)?`.

Sie liefert Adresse und Sitzung nur, wenn **alle** Bedingungen gelten, sonst `nil`:
- `debugBuild` ist wahr (`#if DEBUG`-Konstante `AccountWiring.debugBuild`; im Release-Bau immer `nil`);
- beide Startargumente sind da: `-LEDebugService <url>` und `-LEDebugSession <token>` (der Wert ist jeweils das nächste Argument);
- der Token ist nicht leer (nach Entfernen von Leerraum);
- die Adresse ist genau `http://localhost:<port>`: Schema `http`, Host `localhost` (Groß-/Kleinschreibung egal), **Port vorhanden**, kein Benutzer, kein Passwort, Pfad leer oder `/`, keine Anfrage, kein Fragment. Nie `https`, nie `127.0.0.1`, nie ein fremder Host.

`isEnabled` und `forApp` bekommen denselben Parameter `debugBuild: Bool = AccountWiring.debugBuild` und reichen ihn an `debugService` durch, damit der Release-Fall im Debug-Testbau prüfbar ist.

**Port ist Pflicht (Entscheidung):** Ohne Port würde Port 80 gelten; dort läuft auf einem Entwicklungsrechner kein Wegwerf-Dienst, wohl aber womöglich etwas anderes. Ein fehlender Port ist daher fast sicher ein Tippfehler und wird abgelehnt (`nil`), statt still gegen einen unbeabsichtigten Dienst zu senden. Der Test-Skript-Weg gibt den Port immer an.

**Nur `localhost`, nicht `127.0.0.1`:** Apple (`NSAllowsLocalNetworking`, seit iOS 17 keine IP-Adressen ohne Ausnahme) und die Regel `serviceURL` aus #615 S4c-2b; im Simulator wurde am 2026-11-13 nachgestellt, dass `http://localhost:<port>` ohne ATS-Eintrag ankommt (Beleg in der Analyse). Keine `Info.plist`-Änderung nötig.

**`isEnabled`** wird wahr, wenn zusätzlich `debugService(arguments:)` nicht `nil` ist (Parameter `debugBuild` wird durchgereicht, Standard wie oben). Bestehende Fälle (`--ui-testing`, `LEAccountEnabled`) bleiben unverändert; ohne beide Argumente und im Release-Bau bleibt der Schalter aus.

**`forApp`:** Gilt der Debug-Weg (und nicht `--ui-testing`), baut `forApp` `AccountState(client: ServiceClient(baseURL: url), store: InMemorySessionStore(token: token))`. Das ist der echte `ServiceClient` über `URLSessionTransport`, der Status ist sofort `signedIn`. **Kein Schlüsselbund-Eintrag** (der Token liegt nur im Speicher), **kein `--ui-testing`**: unter `--ui-testing` ist `ClaudeSyncTrigger` stumm (S3b-1, `silent`), der Nachweis liefe leer. Trägt der Start beides (`--ui-testing` und die Debug-Argumente), gewinnt `--ui-testing` (Stellvertreter, kein Netz), damit ein UI-Test nie versehentlich gegen einen lokalen Dienst spricht. `LooseEndsApp.swift` bleibt unberührt: `forApp(info:arguments:)` kennt den Weg, der Trigger wird wie bisher nur mit Konto gebaut.

Der Token steht im Prozessaufruf des Simulators (Startargument). Das ist hier unkritisch, weil er nur gegen eine Wegwerf-Datenbank gilt und die Adresse auf `localhost` beschränkt ist; ein Token des Live-Dienstes darf nie so übergeben werden. Dieser Satz steht als Kopfkommentar in `local-service.sh` und in der `CLAUDE.md`-Zeile zum Debug-Weg (beides Lieferpunkte, siehe Teil 2 und Definition of Done).

### Teil 2: Lokaler Dienst und Hilfsbefehle (`server/scripts/`)

**`local-service.sh`** (Bash, `set -euo pipefail`, Muster `test-local.sh`; Kopfkommentar: nur für den Simulator gegen diese Wegwerf-Datenbank, nie einen Token des Live-Dienstes als Startargument übergeben): startet einen Wegwerf-Postgres 18 (eigener Datenordner im Temp-Ordner, freier Port, nur TCP, kein Unix-Socket), dann den Dienst `node src/main.ts` im Ordner `server/` mit `DATABASE_URL`, `HOST=127.0.0.1` und `PORT` (der Wert von `LOCAL_SERVICE_PORT`, falls gesetzt, sonst ein freier Port). Vor dem Start entfernt es ausdrücklich jede geerbte Variable, die den Dienst anders konfigurieren würde: alle `APPLE_*`, `OAUTH_COOKIE_KEYS`, `OAUTH_SIGNING_JWK`, `ALLOWED_APPLE_SUBS`, `PUBLIC_URL` (`unset`); der Dienst läuft also ohne Apple und ohne OAuth (`/auth/apple` 503, App-Wege laufen, `/mcp` auf `rejectAll`). Es führt `[ -d node_modules ] || npm ci` aus, wartet höchstens 30 s auf `/health` 200 (sonst Fehlschlag mit den letzten 20 Logzeilen), schreibt eine Zustandsdatei `<tmp>/state.env` mit genau den Schlüsseln `DATABASE_URL`, `PORT`, `SERVICE_URL=http://localhost:<port>` und `SESSION_TOKEN` (erzeugt über `local-fixture.ts session`), gibt deren Pfad als letzte Zeile `STATE=<pfad>` aus und läuft bis Strg-C oder Signal. Auf EXIT, INT und TERM stoppt es den Dienst und Postgres und löscht den Temp-Ordner, auch bei Fehlern in der Mitte. Es bindet nie an eine andere Adresse als `127.0.0.1`.

**`local-fixture.ts`** (TypeScript, läuft direkt mit Node 26 wie `main.ts`): Unterbefehle gegen dieselbe Datenbank (`DATABASE_URL` aus der Umgebung), ausschließlich über vorhandene Funktionen, **keine Änderung am Server-Code**. **Schutz vor echter Datenbank:** das Fixture akzeptiert `DATABASE_URL` nur mit dem Host `127.0.0.1` oder `localhost`; jede andere Adresse endet vor dem ersten Datenbankzugriff mit Ausgang 1 (so kann es nie ein Konto an `admit` vorbei in einer echten Datenbank anlegen). **Jeder** Unterbefehl bestimmt das Fixture-Konto zuerst mit `findOrCreate(pool, "local-fixture")` (`accounts.ts`); es gibt genau ein Konto in der Wegwerf-Datenbank, die ID wird nie übergeben oder gespeichert.
- `session`: Konto wie oben, dann `createSession` (`accounts.ts`), gibt den Rohtoken aus (eine Zeile) und braucht die Migrationen (`migrate`) schon angewandt (der Dienst hat sie beim Start);
- `transcript`: `getTranscript` (`transcripts.ts`) des Fixture-Kontos, gibt `tasks=<Anzahl>` und je Aufgabe eine Zeile mit dem Titel aus; ohne Abschrift `none`;
- `order <text>`: `putOrder` (`orders.ts`) mit `{ version: 1, id: <neue UUID>, kind: "capture", text }`, gibt die Auftrags-ID aus; `putOrder` prüft das Dokument selbst mit `checkOrder`, ein ungültiger Auftrag endet als Fehler mit Ausgang 1;
- `result <id>`: `getResult` (`orders.ts`), gibt den Zustand (`unknown`, `waiting`, `claimed`, `result`) und bei `result` die Felder `outcome`, `reason` (falls da) und `taskID` als eine Zeile je Feld aus.

Unbekannter Unterbefehl, fehlendes Argument oder fehlende `DATABASE_URL` enden mit Meldung auf stderr und Ausgang 1; ein Token oder Auftragstext erscheint nie in einer Fehlermeldung. Der Pool wird immer geschlossen.

**Bewusste Abweichung `findOrCreate` statt `admit`:** `findOrCreate` ist laut `accounts.ts` ein Test-Helfer; Produktaufrufer legen Konten nur über `admit` an (Zulassungsregel `ALLOWED_APPLE_SUBS`, #621 S6a). Das Fixture ist kein Produktaufrufer: es läuft nur gegen die Wegwerf-Datenbank von `local-service.sh`, die mit dem Skript verschwindet, und braucht genau das eine Konto ohne Apple-Kennung. Die Zulassungsregel ist dort ohne Gegenstand; der Produktweg `/auth/apple` bleibt unverändert bei `admit`.

**Selbsttest (Beleg AC-9 bis AC-11, keine eigene Datei):** eine feste Befehlsfolge, die die Umsetzung wörtlich ins Protokoll `docs/artifacts/feat-795-s3b2-debug-weg/selbsttest.md` schreibt (Befehl und Ausgabe je Schritt):
0. Die Befehlsfolge läuft in einer Bash mit `set -m` (Job-Steuerung): sonst startet ein Hintergrundjob mit ignoriertem SIGINT, und Bash erlaubt keinen Trap auf ein beim Start ignoriertes Signal. Mit `set -m` bekommt das Skript SIGINT normal; Schritt 4 belegt das. Vorab nachgestellt am 2026-11-13 (Wegwerfskript mit `trap … INT TERM`, Protokoll `docs/artifacts/feat-795-s3b2-debug-weg/vorab-sigint.md`): ohne `set -m` läuft es nach `kill -INT` weiter, mit `set -m` läuft der Trap und es endet mit 0. Weil ein Signal vor dem Setzen des Traps ihn umgeht, setzt `local-service.sh` die Traps als erste Anweisung nach `set -euo pipefail`, und der Selbsttest signalisiert erst nach der Zeile `STATE=`.
1. Vorher `(cd server && npm ci)` außerhalb jeder Frist. Dann `APPLE_TEAM_ID=x server/scripts/local-service.sh > <log> 2>&1 &` starten (die geerbte Variable belegt das `unset`), höchstens 90 s (Postgres-Start plus 30 s Health-Frist) auf die Zeile `STATE=<pfad>` im Log warten, `state.env` lesen: genau die vier Schlüssel `DATABASE_URL`, `PORT`, `SERVICE_URL`, `SESSION_TOKEN`, alle nicht leer.
2. `curl -s -o /dev/null -w '%{http_code}' $SERVICE_URL/health` → `200`; `curl -s -o /dev/null -w '%{http_code}' -X POST $SERVICE_URL/auth/apple` → `503`; `lsof -nP -iTCP:$PORT -sTCP:LISTEN` zeigt nur `127.0.0.1`.
3. `POST $SERVICE_URL/app/transcript` mit `Authorization: Bearer $SESSION_TOKEN`, `Content-Type: application/json` und dem Dokument `{"version":1,"generatedAt":"<jetzt, ISO 8601 mit Z>","nowCount":0,"now":{"today":[],"lined":[],"waiting":[]},"tasks":[]}` → 2xx. Fixture mit `DATABASE_URL` aus `state.env`: `transcript` → `tasks=0`; `order "Selbsttest"` → UUID; `result <uuid>` → `waiting`; `result <neue UUID>` → `unknown`; `foo`, `order` ohne Text, ein Aufruf ohne `DATABASE_URL` und einer mit `DATABASE_URL=postgres://u@db.example:5432/x` → je Ausgang 1, und `grep -F` mit dem Wert von `SESSION_TOKEN` aus `state.env` sowie mit „Selbsttest“ findet in stderr nichts.
4. `kill -TERM <pid>`, höchstens 15 s warten; danach `pgrep -f` ohne Treffer für Dienst und Postgres dieses Laufs, Temp-Ordner fehlt, `lsof` auf beiden Ports leer. Neu starten (Schritt 1) und dasselbe mit `kill -INT`.
5. Erzwungener Startfehler: `python3 -m http.server <p> --bind 127.0.0.1 &` belegt einen Port, dann `LOCAL_SERVICE_PORT=<p> server/scripts/local-service.sh` → Ausgang ≠ 0 innerhalb von 60 s, kein Postgres dieses Laufs mehr, Temp-Ordner fehlt; danach den Python-Server beenden.
6. `git diff --stat origin/main...HEAD -- server/src/` und `git diff --stat -- server/src/` sind leer.

### Teil 3: Nachweis A/B (Definition of Done von #795)

Ablauf, deterministisch, weil ein Auftrag keinem Gerät vorab zugeordnet ist und `claimOrder(pool, account, device)` ihn dem ersten Gerät gibt, das ihn holt, und weil zwei Simulatoren ohne iCloud keinen Bestand teilen (darum `capture`, nicht `complete`). Erfasst wird ohne Bedienung im Simulator: Tippen ist dort nur über einen UI-Test möglich, und der verlangt `--ui-testing`, unter dem der Auslöser stumm ist. A bekommt seine Aufgabe darum selbst über einen ersten Auftrag; das belegt zugleich, dass A nach dem Ausführen die Abschrift sendet.

1. `server/scripts/local-service.sh` in einer Bash mit `set -m` im Hintergrund starten, `state.env` lesen (`SERVICE_URL`, `SESSION_TOKEN`).
2. `local-fixture.ts order "Aufgabe von A"` (ID A merken). `./scripts/sim.sh build`, dann Simulator A (`LOOSEENDS_SIM="iPhone 17"`, ohne `--ui-testing`): `./scripts/sim.sh launch -LEDebugService $SERVICE_URL -LEDebugSession $SESSION_TOKEN`. Beim Start sendet A, holt den Auftrag, führt ihn aus und sendet nach dem Speichern (2 s entprellt) erneut. `local-fixture.ts result <ID A>` und danach `transcript` werden alle 2 s abgefragt, je höchstens 60 s lang, bis `outcome=done` und eine Abschrift mit dem Titel „Aufgabe von A“ vorliegen. A beenden (`xcrun simctl terminate <udid A> com.henning.looseends`).
3. Erst danach `local-fixture.ts order "Aufgabe von B"` (ID B merken).
4. Simulator B (`LOOSEENDS_SIM="iPhone Air"`, eigene Gerätekennung) mit denselben Argumenten starten (`LOOSEENDS_SIM="iPhone Air" ./scripts/sim.sh launch …`): B holt, führt aus, meldet. `local-fixture.ts result <ID B>` wird alle 2 s abgefragt, höchstens 60 s lang, bis es `result` mit `outcome=done` und `taskID` zeigt; danach wird `transcript` ebenso alle 2 s, höchstens 60 s lang abgefragt, bis es die neue Aufgabe von B enthält (die Sendung nach dem Speichern ist um 2 s entprellt, S3b-1). Läuft eine Frist ab, gilt der Lauf als gescheitert.
5. B's Store `LooseEnds.store` finden: `ModelContainerFactory` legt ihn in den App-Group-Container, fällt aber ohne nutzbare App-Gruppe (`containerURL(forSecurityApplicationGroupIdentifier:)` nil, beim unsignierten Simulatorbau möglich) auf den Datencontainer der App zurück. Darum fest: zuerst `find "$(xcrun simctl get_app_container <udid B> com.henning.looseends group.com.henning.looseends)" -name LooseEnds.store`, ohne Treffer `find "$(xcrun simctl get_app_container <udid B> com.henning.looseends data)" -name LooseEnds.store`; genau ein Treffer muss es sein, und das Protokoll nennt, welcher Container es war. Diese Datei nur lesend prüfen (`sqlite3 -readonly`, Tabellen `ZREVISION` und `ZTASKITEM`): eine Revision mit Grund „Claude“ an der neuen Aufgabe. Die UDIDs von A und B liest das Protokoll nach dem jeweiligen Start aus `xcrun simctl list devices booted` (Zeile mit „iPhone 17“ bzw. „iPhone Air“; gebootet ist je Name genau einer). Screenshot von B: `LOOSEENDS_SIM="iPhone Air" ./scripts/sim.sh screenshot docs/artifacts/feat-795-s3b2-debug-weg/b-aufgabe.png`, geöffnet und beschrieben.
6. Aufräumen: Apps beenden, `local-service.sh` per Signal beenden, Temp-Ordner weg.

Das Protokoll (Befehle, Ausgaben, Auszug `sqlite3`, Screenshot) liegt unter `docs/artifacts/feat-795-s3b2-debug-weg/`.

**Regeln vor Modell:** reine Verdrahtung ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR; ADR-21 (Dienst für Claude, Weg B) bleibt unverändert und wird belegt. Keine neue Abhängigkeit, kein Schema, keine Berechtigung, keine `Info.plist`-Änderung.

- **Rationale:** Der Debug-Weg ist eine reine Funktion mit eingereichtem `debugBuild` (Muster `serviceURL(info:allowsLocalHTTP:)`), damit der Release-Fall ohne Release-Bau getestet wird. Startargumente statt Einstellungsseite, weil es ein Entwicklerweg ist und sichtbare Oberfläche Entwurf und UI-Test verlangte.

## Source

- **File:** `LooseEnds/Claude/AccountWiring.swift`
- **Identifier:** `AccountWiring.debugService(arguments:debugBuild:)`, `AccountWiring.isEnabled(info:arguments:debugBuild:)`, `AccountWiring.forApp(info:arguments:debugBuild:)`; benutzt `ServiceClient(baseURL:)`, `InMemorySessionStore(token:)`, `AccountState(client:store:)`
- **Dateien Server:** `server/scripts/local-service.sh`, `server/scripts/local-fixture.ts`; benutzt `findOrCreate`, `createSession` (`accounts.ts`), `putOrder`, `getResult` (`orders.ts`), `getTranscript` (`transcripts.ts`)
- **Unberührt:** `LooseEndsApp.swift`, `ClaudeSync.swift`, `ClaudeSyncTrigger.swift`, `AccountState.swift`, `SessionStore.swift`, `server/src/`, `project.yml`, jede `Info.plist`, Entitlements, alle Views.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `ClaudeSync`, `ClaudeSyncTrigger`, `OrderExecutor`, `DeviceIdentity` (S3a/S3b-1, auf main) | bestehend, unverändert |
| `AccountState(client:store:)`, `InMemorySessionStore(token:)`, `ServiceClient(baseURL:)` | bestehend, unverändert |
| Server `accounts.ts`, `orders.ts`, `transcripts.ts`, `migrate.ts`, `main.ts` | bestehend, unverändert; Skripte rufen sie nur auf (`findOrCreate` bewusst als Test-Helfer, Begründung in Teil 2) |
| `scripts/sim.sh` (`launch` reicht Startargumente durch, `LOOSEENDS_SIM` wählt den Simulator) | bestehend, unverändert |
| Postgres 18 (Homebrew `postgresql@18`) und Node 26 auf dem Mac | wie `test-local.sh` |
| Downstream | S5 (nutzt denselben lokalen Weg für seine Nachweise), #625 (Store-Schalter) |

## Acceptance Criteria

Die ACs 1 bis 8 belegen benannte Tests in `LooseEndsTests/AccountSectionTests.swift` (diese Datei nutzt Swift Testing, `@Test`; die Namen unten sind die Funktionsnamen). AC-9 bis AC-11 belegt der Selbsttest des Skripts, AC-12 bis AC-15 der Simulatorlauf. Die vorhandenen Tests bleiben unverändert grün.

- **AC-1:** Beide Argumente da: GIVEN `-LEDebugService http://localhost:8780` und `-LEDebugSession TOKEN` und `debugBuild: true` WHEN `debugService` gerufen wird THEN ist das Ergebnis die Adresse `http://localhost:8780` und der Token `TOKEN`; die Reihenfolge der Argumente und weitere Argumente dazwischen ändern nichts (Test `debugServiceReadsAddressAndSession`).
- **AC-2:** Nur im Debug-Bau: GIVEN dieselben Argumente und `debugBuild: false` THEN ist `debugService` `nil`, `isEnabled(info: nil, arguments:, debugBuild: false)` ist `false` und `forApp(info: nil, arguments:, debugBuild: false)` ist `nil` (Test `debugServiceNeverInRelease`).
- **AC-3:** Beide Argumente nötig: GIVEN nur `-LEDebugService …` oder nur `-LEDebugSession …`, ein Argument ohne folgenden Wert (letztes Argument) oder ein leerer oder nur aus Leerraum bestehender Token THEN ist `debugService` `nil` (Test `debugServiceNeedsBothArguments`).
- **AC-4:** Nur `http://localhost:<port>`: GIVEN die Adressen `https://localhost:8780`, `http://127.0.0.1:8780`, `http://fremd.example:8780`, `http://localhost.evil.example:8780`, `http://user@localhost:8780`, `http://user:pw@localhost:8780`, `http://localhost:8780#x`, `http://localhost:8780/pfad`, `http://localhost:8780/?x=1`, `ftp://localhost:8780`, `kein url` und leer THEN ist `debugService` jeweils `nil`; `http://LOCALHOST:8780` und `http://localhost:8780/` gelten (Test `debugServiceAcceptsOnlyLocalhostHTTP`).
- **AC-5:** Port ist Pflicht: GIVEN `http://localhost` (ohne Port) THEN ist `debugService` `nil` (Test `debugServiceNeedsAPort`).
- **AC-6:** Schalter: GIVEN `info: nil` und die Debug-Argumente mit `debugBuild: true` THEN ist `isEnabled` wahr; ohne die Argumente, nur mit einem davon oder mit ungültiger Adresse bleibt es `false` (kein `LEAccountEnabled`, kein `--ui-testing`); `--ui-testing` und `LEAccountEnabled` wirken wie bisher (Test `debugArgumentsSwitchTheAccountOn`).
- **AC-7:** Verdrahtung: GIVEN `forApp(info: nil, arguments: [-LEDebugService http://localhost:<port>, -LEDebugSession TOKEN])` im Debug-Bau THEN ist das Ergebnis ein `AccountState` im Status `signedIn`, und `forApp(info: nil, arguments:)` mit denselben Argumenten, aber ungültiger Adresse, liefert `nil` (Test `forAppWithDebugArgumentsIsSignedIn`). Dass der Token über den echten Transport ankommt, belegt AC-12, nicht dieser Test.
- **AC-8:** `--ui-testing` gewinnt: GIVEN die Debug-Argumente **und** `--ui-testing` THEN baut `forApp` den Stellvertreter (`UITestTransport`, Status `signedOut`), nicht den lokalen Weg (Test `uiTestingBeatsDebugArguments`).
- **AC-9:** Skript, Aufbau: GIVEN `server/scripts/local-service.sh`, gestartet mit geerbtem `APPLE_TEAM_ID` WHEN es läuft THEN antwortet `$SERVICE_URL/health` mit 200, der Dienst bindet nur an `127.0.0.1`, `state.env` enthält genau `DATABASE_URL`, `PORT`, `SERVICE_URL`, `SESSION_TOKEN`, und `POST /auth/apple` antwortet 503 (die geerbte Apple-Variable ist entfernt) (Beleg: Selbsttest Schritte 1–2, Protokoll `selbsttest.md`).
- **AC-10:** Skript, Aufräumen: GIVEN der laufende Dienst WHEN SIGTERM, SIGINT oder ein Fehler beim Start (belegter `LOCAL_SERVICE_PORT`) kommt THEN sind Dienst, Postgres und der Temp-Ordner danach weg und die Ports frei (Beleg: Selbsttest Schritte 4–5).
- **AC-11:** Fixture: GIVEN der laufende lokale Dienst THEN nimmt `POST /app/transcript` mit `SESSION_TOKEN` das leere Dokument mit 2xx an; `transcript` gibt `tasks=0`, `order <text>` eine UUID, `result` dazu `waiting`, `result` mit unbekannter ID `unknown`; ein unbekannter Unterbefehl, ein fehlendes Argument, eine fehlende `DATABASE_URL` und eine `DATABASE_URL` mit fremdem Host enden mit Ausgang 1, und stderr enthält weder den Wert des Tokens noch den Text (`grep -F`); `server/src/` ist unverändert (Beleg: Selbsttest Schritte 3 und 6).
- **AC-12:** Abschrift von A: GIVEN Simulator A ohne `--ui-testing` mit den Debug-Argumenten und der vor dem Start gestellte Auftrag „Aufgabe von A“ WHEN A startet THEN zeigt `local-fixture.ts result <ID A>` innerhalb von 60 s `outcome=done`, und `transcript` zeigt innerhalb weiterer 60 s eine Abschrift mit dem Titel „Aufgabe von A“ (Beleg: Protokoll `ab-lauf.md` mit den Ausgaben).
- **AC-13:** Auftrag an B: GIVEN die Abschrift von A im Dienst und A beendet WHEN `local-fixture.ts order "Aufgabe von B"` gelaufen ist und Simulator B (anderer Simulator, andere Gerätekennung) mit denselben Argumenten startet THEN zeigt `local-fixture.ts result <ID B>` innerhalb von 60 s den Zustand `result` mit `outcome=done` und einer `taskID`, und `transcript` enthält innerhalb weiterer 60 s „Aufgabe von B“ (Beleg: Protokoll `ab-lauf.md`).
- **AC-14:** Revision „Claude“ auf B: GIVEN der Lauf aus AC-13 WHEN B's `LooseEnds.store` (gefunden wie in Teil 3, Schritt 5) nur lesend geöffnet wird (`sqlite3 -readonly`, `ZREVISION` samt `ZTASKITEM`) THEN gibt es an der neuen Aufgabe eine Revision mit Grund „Claude“ (Beleg: Auszug der Abfrage im Protokoll).
- **AC-15:** Screenshot B: GIVEN der Lauf aus AC-13 THEN zeigt `docs/artifacts/feat-795-s3b2-debug-weg/b-aufgabe.png` (Befehl in Teil 3, Schritt 5) die Aufgabe „Aufgabe von B“ auf der Startseite oder in der Liste; der Screenshot wird geöffnet und beschrieben, bevor das AC abgehakt wird (Beleg: Bild im Artefaktordner).
- **AC-16:** Quellsuche: GIVEN die Änderung WHEN diese Befehle laufen THEN gilt je Befehl: `grep -n -- '-LEDebug' LooseEnds/Claude/AccountWiring.swift` trifft nur Zeilen in `debugService`; `grep -n 'static let debugBuild = true' -B2 LooseEnds/Claude/AccountWiring.swift` zeigt `#if DEBUG` darüber; `grep -n 'KeychainSessionStore' LooseEnds/Claude/AccountWiring.swift` trifft nur den bestehenden Nicht-Debug-Zweig; `grep -nE 'try\?|print\(|logger\.' LooseEnds/Claude/AccountWiring.swift` trifft keine neue Zeile (Beleg: die vier Befehle mit Ausgabe im Abschlussbericht). Die Wirkung im Release-Fall belegt AC-2.
- **AC-17:** Ganze Suite grün: GIVEN die ganze Unit-Suite WHEN `./scripts/sim.sh unit` läuft THEN ist sie grün (Beleg: Lauf im Abschlussbericht).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/AccountWiring.swift` | MODIFY | `debugService`, `isEnabled` und `forApp` kennen den Debug-Weg; ≈ +40 |
| `LooseEndsTests/AccountSectionTests.swift` | MODIFY | Tests zu AC-1 bis AC-8; ≈ +80 |
| `server/scripts/local-service.sh` | CREATE | Wegwerf-Postgres, Dienst, Zustandsdatei, Aufräumen; ≈ +70 |
| `server/scripts/local-fixture.ts` | CREATE | Unterbefehle `session`, `transcript`, `order`, `result`; ≈ +60 |
| `docs/artifacts/feat-795-s3b2-debug-weg/` | CREATE | Protokoll und Bilder des A/B-Laufs, Selbsttest-Ausgabe; Doku, zählt nicht zum Limit |
| `CLAUDE.md` | MODIFY | Doku, zählt nicht zum Limit: Zeile zum Debug-Weg im Absatz `LooseEnds/Claude`, `local-service.sh` in der Server-Zeile |

### Estimated Changes

- **Dateien: 4 Code-/Testdateien** (zwei neu, zwei geändert), innerhalb des Limits von 4 bis 5.
- **LoC: ≈ +250** (Code ≈ 170, Tests ≈ 80), an der Grenze von ±250; keine Funktion über 50 Zeilen. Der Selbsttest ist eine Befehlsfolge im Protokoll, keine Datei. 250 Zeilen (Additions + Modifications + Deletions der vier Dateien) sind die harte Obergrenze; zeichnet sich mehr ab, wird vor dem Weiterbauen gefragt, nicht still erweitert.
- Keine Permissions, keine `Info.plist`-Einträge (ATS nicht berührt), keine AppStorage-Keys, kein CloudKit-Schema, keine Audio-Dateien, keine Oberfläche, keine neue Abhängigkeit. Neue Swift-Dateien gibt es nicht, `generate` ist trotzdem nach dem Stand zu fahren (Regel des Repos).
- **Seiteneffekte nach außen:** keine für Nutzer. Der Debug-Lauf spricht nur mit `localhost` und mit einer Wegwerf-Datenbank; Store-Bau und TestFlight bleiben unverändert.
- **Parallele Arbeit:** vor dem PR `origin/main` und offene PRs auf Berührung von `LooseEnds/Claude/` und `CLAUDE.md` (Hotspot) prüfen.

## Risiken

- **ATS:** `localhost` ohne Ausnahme im Simulator belegt (Analyse). Scheitert es in einem späteren Simulator, neu entscheiden; eine ATS-Ausnahme in der `Info.plist` wäre ein Pfad der Geräteliste und ein eigener Schnitt.
- **Nie im Release:** `#if DEBUG`-Konstante und Parameter `debugBuild`; AC-2 und AC-16 sichern es ab.
- **Trigger stumm unter `--ui-testing`:** darum läuft der Nachweis ohne dieses Argument, mit dem echten Simulator-Store; `--ui-testing` gewinnt gegen die Debug-Argumente (AC-8), damit UI-Tests nie ins Netz greifen.
- **Zwei Simulatoren, getrennte Daten:** darum `capture` statt `complete` (AC-13).
- **Token im Prozessaufruf:** nur gegen Wegwerf-Datenbank; die Adressregel schließt den Live-Dienst aus.
- **Testsperre:** `launch` holt `/tmp/loose-ends-testlauf.lock`; A und B werden nacheinander gestartet.
- **Postgres/Node fehlen auf dem Mac:** das Skript bricht mit klarer Meldung ab (wie `test-local.sh`).
- **Gerätestufe:** nicht berührt (`LooseEnds/Claude/`, `LooseEndsTests/`, `server/scripts/` stehen nicht in der Liste).

## Test Plan

Unit-Tests (Swift Testing) in `LooseEndsTests/AccountSectionTests.swift`, Lauf `LOOSEENDS_SIM=… ./scripts/sim.sh sim-unit AccountSectionTests`, danach die ganze Suite `./scripts/sim.sh unit`. Hinweis: das QA-Gate zählt nur XCTest-Zeilen; für diese Datei ist der Beleg der Lauf der ganzen Suite (AC-17) und die Ausgabe der benannten Tests.
**Keine neuen UI-Tests:** keine Oberfläche, nichts Sichtbares. Ersatz und eigentlicher Beleg ist der echte Durchlauf A/B (AC-12 bis AC-15), der die Kette bis zum Dienst schließt.

| Test / Beleg | AC |
|---|---|
| `debugServiceReadsAddressAndSession` | AC-1 |
| `debugServiceNeverInRelease` | AC-2 |
| `debugServiceNeedsBothArguments` | AC-3 |
| `debugServiceAcceptsOnlyLocalhostHTTP` | AC-4 |
| `debugServiceNeedsAPort` | AC-5 |
| `debugArgumentsSwitchTheAccountOn` | AC-6 |
| `forAppWithDebugArgumentsIsSignedIn` | AC-7 |
| `uiTestingBeatsDebugArguments` | AC-8 |
| Skript-Selbsttest (Befehlsfolge in Teil 2, Protokoll `selbsttest.md`) | AC-9 bis AC-11 |
| A/B-Lauf im Simulator mit Protokoll | AC-12 bis AC-15 |
| Quellsuche (`grep`) | AC-16 |
| ganze Suite | AC-17 |

TDD-Reihenfolge: Swift-Tests zuerst (RED: Kompilierfehler, `debugService` fehlt), dann Code (GREEN); der Skript-Selbsttest wird vor dem A/B-Lauf geschrieben und gefahren.

**Ehrlich zur Belegkraft:** die Unit-Tests belegen die Regeln der Adresse und des Schalters. Dass die Kette App, Dienst, Auftrag, Ergebnis wirklich schließt, belegt nur der Lauf A/B gegen den echten Dienstcode (AC-12 bis AC-15). Dass das auch mit Apple-Anmeldung, nginx und Hennings Konto geht, belegt er nicht; das bleibt Stufe 3 in S5.

## Alternativen

| Weg | Was | Dagegen | Gekippt würde |
|---|---|---|---|
| **A (gewählt): Startargumente im Debug-Bau, Skript für lokalen Dienst** | siehe Purpose | — | nichts; keine ADR |
| **B Debug-Einstellungsseite** | Adresse und Sitzung in der App eintippen | sichtbare UI, braucht Entwurf und UI-Test, für einen Entwicklerweg zu viel; verworfen | nichts |
| **C Nachweis gegen den Live-Dienst mit echter Apple-Anmeldung über TestFlight** | echter Pfad inklusive nginx | braucht Hennings Gerät und Konto pro Lauf; bleibt Stufe 3 von S5 (DoD #795); verworfen für diesen Schnitt | nichts |
| **D `127.0.0.1` statt `localhost`** | Loopback per IP | funktioniert im Simulator, widerspricht aber Apples Doku seit iOS 17; verworfen | nichts |
| **E Sitzung über Umgebungsvariable (`SIMCTL_CHILD_…`)** | hält den Token aus der Prozessliste | `sim.sh launch` reicht nur Argumente durch; gegen Wegwerf-Datenbank unkritisch; verworfen für jetzt | nichts |
| **F Debug-Weg auch mit https und fremdem Host** | Test gegen einen Staging-Dienst | öffnet einen Weg, einen echten Token im Argument gegen einen echten Dienst zu senden; verworfen | nichts |

ADR-21 (Weg B) bleibt; keine frühere Entscheidung fällt.

## Out of Scope / Folgeschnitte

- **S5:** Weckruf und Hintergrund-Auffrischen (`LooseEnds/Notifications/BackgroundRefresh.swift`, Pfad der Geräteliste, Stufe 3), Mac im Menüband ohne Fenster, Gerätenachweis über TestFlight.
- **#625:** Store-Schalter `LEAccountEnabled`.
- Änderungen an `LooseEndsApp.swift`, `ClaudeSync*.swift`, `AccountState.swift`, `server/src/`, `project.yml`, jeder `Info.plist`: keine. Anzeige des Zustands in der Oberfläche: keine.

## Abnahme

**Kein Pfad der Geräteliste berührt.** Die Abnahme endet nach Stufe 2: Stufe 1 sind die Unit-Tests und der Skript-Selbsttest, Stufe 2 der benutzte Durchlauf A/B im Simulator mit Protokoll und Bildern (AC-12 bis AC-15). Sichtbar ändert sich für den PO nichts, und das wird im Abschlussbericht gesagt. Nichts läuft auf Hennings Geräten.

## Definition of Done

- [ ] AC-1 bis AC-17 erfüllt, jeder über seinen benannten Test beziehungsweise Beleg; Tests vor dem Code geschrieben (RED belegt)
- [ ] `./scripts/sim.sh unit` grün (gesamte Suite), Build erfolgreich; die Ausgabe der acht benannten Swift-Testing-Tests (AC-1 bis AC-8) steht im Abschlussbericht, weil das QA-Gate sie nicht zählt
- [ ] Nachweis A/B vollständig: Protokoll, `sqlite3`-Auszug und geöffnete, beschriebene Screenshots unter `docs/artifacts/feat-795-s3b2-debug-weg/`
- [ ] Skript-Selbsttest grün und im Artefaktordner abgelegt; nach dem Lauf kein Prozess, kein Temp-Ordner, kein belegter Port
- [ ] Abnahme: „Kein Pfad der Geräteliste berührt.“
- [ ] Doku: `CLAUDE.md` (Debug-Weg im Absatz `LooseEnds/Claude` samt dem Satz, dass nie ein Token des Live-Dienstes als Startargument übergeben wird; `local-service.sh` in der Server-Zeile; Hotspot, vor dem PR gegen `origin/main` abgleichen)
- [ ] PR mit `Refs #795`, CI grün, Merge durch Claude; #795 kommentiert (Stand S3b-2, Folge S5), Board-Karte aktuell, Memory geschrieben

## Known Limitations

- Der Debug-Weg belegt die Kette gegen den echten Dienstcode, aber ohne Apple-Anmeldung, nginx und Konto-Zulassung (`ALLOWED_APPLE_SUBS`); diese bleiben bei den Schnitten S4 und S5.
- Zwei Simulatoren teilen keinen Bestand; darum belegt der Lauf `capture`, nicht `complete` oder `setDue` auf einer Aufgabe von A. Diese Arten sind in S3a/`OrderExecutor` unit-getestet.
- Der Mac im Menüband ohne Fenster ist hier nicht belegt (S5).
- AC-9 bis AC-16 sind Belege im Protokoll und im Abschlussbericht, keine Swift-Tests; AC-1 bis AC-8 laufen in Swift Testing, das das QA-Gate nicht als XCTest zählt (AC-17 als Beleg der ganzen Suite).

## Changelog

- 2026-11-13: Initial spec created (Schnitt S3b-2)
- 2026-11-13: Vierte Validierung: Simulator B fest „iPhone Air“, UDID aus `simctl list devices booted`, stderr-Prüfung auf den Token-Wert, Live-Token-Hinweis als Lieferpunkt
- 2026-11-13: Dritte Validierung: Store-Ort fest über beide Container (Gruppe, sonst Daten), Screenshot-Pfad und Simulator für B, Screenshot von A gestrichen, AC-16 mit vier benannten Befehlen, `origin/main...HEAD`, SIGINT-Probe abgelegt, `npm ci` vor der Frist
- 2026-11-13: Zweite Validierung: `debugBuild` auch an `isEnabled`/`forApp`, Store im App-Group-Container, Release-Bau-AC gestrichen (Wirkung über AC-2), AC-8 nur `--ui-testing`, Passwort/Fragment in AC-4, Selbsttest vollständig festgelegt (`set -m`, `LOCAL_SERVICE_PORT`, Dokument, Fristen), Fixture nur gegen lokale Datenbank, geerbte Apple-/OAuth-Variablen entfernt, A über ersten Auftrag statt Bedienung, `outcome` statt Status
- 2026-11-13: Nach Validierung: Selbsttest als feste Befehlsfolge, Fixture-Konto je Unterbefehl, `findOrCreate` begründet, AC-7/AC-8 auf einen Beleg, Fristen im A/B-Lauf, LoC-Schwelle genau
