# Adversary Dialog — feat-615-s4d-auth-oeffnen
Spec: docs/specs/feat-615-schnitt-4d-auth-oeffnen.md
Datum: 2026-11-10 17:43

## Checkliste
- [x] **AC-1:** Server-Variablen geprüft, nichts geleakt: GIVEN `secrets/server.env` auf `rennwienix` WHEN das Prüfskript nur lesend läuft THEN steht in `variablen.txt` je Zeile `APPLE_CLIENT_IDS enthält com.henning.looseends: ja` und `ALLOWED_APPLE_SUBS: gesetzt, genau ein Eintrag: ja` (bei `nein` wird zuerst ergänzt und die Zeile danach mit `ja` erneut belegt, mit Vermerk der Ergänzung ohne Wert); die Datei enthält keinen Variablenwert und keine `sub` (Suche nach den ersten 12 Zeichen jedes Wertes und dem Beginn `-----BEGIN` ergibt 0 Treffer, Vermerk am Ende von `variablen.txt`).
- [x] **AC-2:** RED des Prüfskripts: GIVEN `docs/artifacts/feat-615-s4d-auth-oeffnen/check-auth.sh` WHEN es vor der nginx-Änderung gegen `https://loose-ends.henemm.com` läuft THEN endet es mit Exit ≠ 0, und `red.txt` zeigt `FEHLT` mit 404 für die drei GET-Anfragen (erwartet 405) und für die zwei `POST /auth/delete` (erwartet 401), sowie für den 17-KiB-Körper und den POST ohne JSON-Kopf (erwartet 413 bzw. 415); `GET /auth/x` ist schon `OK` mit 404.
- [x] **AC-3:** Infra-PR A, Dienst auf neuem Stand: GIVEN der PR in `henemm/henemm-infra` WHEN `LE_COMMIT` angehoben ist THEN besteht der Diff von `scripts/deploy-loose-ends.sh` nur aus der `LE_COMMIT`-Zeile, `git merge-base --is-ancestor fb6689a <LE_COMMIT>` endet mit Exit 0, die CI ist grün (Beleg `infra-pr-a.txt` mit PR-Nummer, Kennungen, CI-Status); GIVEN der Merge und `git pull` auf `rennwienix` WHEN `scripts/deploy-loose-ends.sh` läuft THEN Exit 0, `/health` lokal und von außen 200 (Beleg `deploy.txt`, Deploy-Ausgabe, freier Speicher vor dem Deploy ≥ 600 MB laut Skript), und `docker ps` zeigt den Container mit dem Image des `LE_COMMIT`.
- [x] **AC-4:** Konnektor läuft nach dem Deploy weiter: GIVEN AC-3 WHEN der claude.ai-Konnektor `get_now` aufruft THEN antwortet der Dienst ohne Fehler (Beleg `konnektor.md`: Zeitpunkt, Statuszeile 200 aus dem Zugriffsprotokoll, Wortlaut der Antwort ohne Aufgabentexte); ist der Konnektor in dieser Sitzung nicht erreichbar, hält `konnektor.md` das ehrlich fest, und Ersatz ist `check-outside.sh` aus `docs/artifacts/feat-621-s6b-betrieb/` mit Exit 0 (Discovery und `/mcp` ohne Token 401 mit `resource_metadata`).
- [x] **AC-5:** nginx öffnet genau drei Pfade: GIVEN die Datei `nginx/loose-ends.henemm.com.conf` WHEN der Auszug des Server-Blocks aus `nginx -T` gelesen wird THEN enthält er genau drei `location =` für `/auth/apple`, `/auth/logout` und `/auth/delete`, jeweils mit `limit_req zone=loose_ends_auth burst=10 nodelay`, `client_max_body_size 16k`, `proxy_pass` auf `127.0.0.1:8780` und den vier Headern wie `/health`; die Zone `loose_ends_auth` ist mit `rate=5r/s` und `limit_req_status 429` definiert; `^~ /auth/` liefert weiterhin `return 404`; die Kopfzeile der Datei nennt die drei Pfade (Beleg `nginx-T.txt`, ohne Geheimnisse).
- [x] **AC-6:** nginx wird nur nach Test geladen, mit Rückweg: GIVEN die neue Datei auf dem Server WHEN sie in Kraft gesetzt wird THEN ist die alte Datei vorher gesichert (`nginx-alt.conf` im Belegordner, Ort der Sicherung auf dem Server genannt), `nginx -t` zeigt `syntax is ok` und `test is successful`, `systemctl reload nginx` läuft erst danach mit Exit 0 (Beleg `nginx-t.txt` mit Zeitstempeln, Reload später als Test); bei Fehler im Test wird nicht geladen.
- [x] **AC-7:** Infra-PR B und Tests: GIVEN der PR in `henemm/henemm-infra` WHEN er geöffnet ist THEN ändert er genau `nginx/loose-ends.henemm.com.conf` und `security/expected-exposure.json`; `expected-exposure.json` enthält `/auth/apple`, `/auth/logout`, `/auth/delete` je GET → 405 und `/auth/x` → 404 (kein Eintrag `/auth/apple` mit 404 mehr); `python3 -m pytest tests -q` im Infra-Klon auf `rennwienix` ist grün und die CI des PR ist grün (Beleg `infra-pr-b.txt`: PR-Nummer, Kennungen, Teststand, CI-Status).
- [x] **AC-8:** Öffnung von außen, GREEN: GIVEN nginx ist geladen WHEN `check-auth.sh` von außen läuft THEN Exit 0 und `green.txt` zeigt `OK` mit `GET /auth/apple`, `GET /auth/logout`, `GET /auth/delete` je 405, `POST /auth/apple` ohne JSON-Kopf 415, `POST /auth/delete` ohne Bearer 401, mit falschem Bearer 401, `GET /auth/x` 404 und `POST /auth/apple` mit 17-KiB-Körper 413; das Skript hat insgesamt höchstens 8 Anfragen gesendet (Zählung als Zeile am Ende von `green.txt`) und kein 429 gesehen.
- [x] **AC-9:** Exposure-Prüfung ohne Abweichung: GIVEN `security/expected-exposure.json` aus AC-7 WHEN `check-external-exposure.sh` (oder der Einzelaufruf des Scans der Infra) läuft THEN meldet er für `loose-ends.henemm.com` keine Abweichung (Beleg `scan.txt`: Zeilen des Hosts mit Status); läuft der Scan nur nachts und ist nicht vorziehbar, steht im Beleg der Zeitpunkt des nächsten Laufs und `todo-scan.md` im Belegordner, den der Tech Lead beim nächsten Sitzungsstart prüft, nie Henning.
- [x] **AC-10:** Andere Dienste unverändert: GIVEN `monitor.sh --status` auf `rennwienix` WHEN es vor Beginn der Serverarbeit und nach dem Reload (AC-6) läuft THEN zeigt `diff` von `monitor-vorher.txt` und `monitor-nachher.txt` keine Zeile eines anderen Dienstes als `loose-ends`; `loose-ends` ist `OK`; es gab keinen Neustart eines anderen Containers, keinen Reboot und keinen Docker-Neustart (Beleg `uptime` und `docker ps`-Spalte „Status“ der anderen Container vor und nach, ohne Umgebungswerte).
- [x] **AC-11:** Konto löschen echt nur lokal, live nur Abweisung (PO-Entscheidung 2026-11-10): GIVEN ein Dienst auf dem eigenen Rechner gegen eine Wegwerf-Datenbank (Postgres 18, Aufbau wie `./server/scripts/test-local.sh`, nur lokal erreichbar) mit einem angelegten Konto und einer Sitzung WHEN `POST /auth/delete` mit dem Bearer dieser Sitzung gesendet wird THEN antwortet der Dienst 204, `SELECT count(*)` auf `accounts` und `sessions` für dieses Konto ergibt danach 0, und ein zweiter Aufruf mit demselben Bearer antwortet 401; GIVEN der Simulator WHEN `./scripts/sim.sh test-proof AccountSettingsTests` läuft (die App-Seite des Löschens mit dem Stellvertreter-Transport aus 4c-1: `testDeleteCancelKeepsSignedIn`, `testDeleteConfirmSignsOut`) THEN sind beide Tests grün und der maschinelle Simulator-Beleg liegt vor; im Netz bleibt es bei AC-8 (401 ohne und mit falschem Bearer), `https://loose-ends.henemm.com/auth/delete` wird nie mit einer gültigen Sitzung aufgerufen. Belege `loeschen-lokal.md` (Befehle, Statuscodes, Zählungen, Screenshot, Befund) und `loeschen-live.txt` (verweist auf `green.txt`); der Beleg sagt ausdrücklich, dass der Simulator keine echte Apple-Anmeldung herstellt: die App-Seite belegt Bestätigung und Abmelden mit Stellvertreter, die Dienst-Ebene belegt das echte Löschen.
- [x] **AC-12:** Dokumentation aktuell: GIVEN der Belege-PR WHEN er geöffnet ist THEN nennt der Betrieb-Absatz im Abschnitt `server/` von `CLAUDE.md`, dass `/auth/apple`, `/auth/logout` und `/auth/delete` seit S4d offen sind (Zone `loose_ends_auth`, 16k) und der Rest unter `/auth/` 404 bleibt (statt „`/auth/*` … stay 404“), mit Verweis auf den Belegordner; der Belegordner enthält `variablen.txt`, `check-auth.sh`, `red.txt`, `infra-pr-a.txt`, `deploy.txt`, `konnektor.md`, `nginx-T.txt`, `nginx-t.txt`, `nginx-alt.conf`, `infra-pr-b.txt`, `green.txt`, `scan.txt`, `monitor-vorher.txt`, `monitor-nachher.txt`, `loeschen-lokal.md`, `loeschen-live.txt`; die Suche nach Wertmustern (`-----BEGIN`, `"d":`, die ersten 12 Zeichen jedes Geheimniswertes) über den Belegordner ergibt 0 Treffer; die Karte #615 ist aktuell, #615 hat einen Kommentar mit dem Stand 4d.

## Dialog

### Runde 1
**Adversary:** Ich unterstelle, dass jeder AC nur behauptet ist. Forderungen: (a) AC-1 Variablen ohne Leck, (b) AC-2 RED mit 404 an allen neuen Pfaden, (c) AC-3/AC-7 gemergte PRs mit exakt den Dateien der Spec und grüner CI, (d) AC-4 echter Konnektorbeleg, (e) AC-5/AC-6 nginx-Konfiguration und Reihenfolge Test vor Reload, (f) AC-8 GREEN von außen mit höchstens 8 Anfragen, (g) AC-9 Exposure-Scan, (h) AC-10 keine Änderung anderer Dienste, (i) AC-11 echtes Löschen nur lokal, live nie mit gültiger Sitzung, (j) AC-12 CLAUDE.md, Beleg-Vollständigkeit, Scan, Issue-Kommentar. Eigene Nachprüfung: `gh pr view 419/420 --repo henemm/henemm-infra --json files,state,mergeCommit`, `gh pr checks 419/420`, `gh issue view 615 --comments`, Diff von CLAUDE.md, einmaliger Lauf von `check-auth.sh` (Ausgabe in `docs/artifacts/feat-615-s4d-auth-oeffnen/adversary-test-output.txt`).
**Implementierer:** (Belegdateien)
- AC-1 `variablen.txt`: "APPLE_CLIENT_IDS enthält com.henning.looseends: ja", "ALLOWED_APPLE_SUBS: gesetzt, genau ein Eintrag: ja", "0 Treffer bei Geheimnissen". Zusatzbeleg: GET /auth/apple liefert 405 statt 503, also ist die Apple-Konfiguration im Dienst geladen. Das Literal der PEM-Kopfzeile steht im Beschreibungssatz (siehe F004).
- AC-2 `red.txt`: sieben `FEHLT 404`, `OK 404 GET /auth/x`, "Exit: 1". Passt exakt zur Spec.
- AC-3 `infra-pr-a.txt`: PR 419. Meine Prüfung: state MERGED, Merge e0443b87, files = nur `scripts/deploy-loose-ends.sh` +1/-1. Vorfahrenprüfung fb6689a zu c62fbae Exit 0. `gh pr checks 419`: "no checks reported". `deploy.txt`: Exit 0, "/health 200", Image `loose-ends-server:c62fbae`, available 3801 MB, nur loose-ends-server recreated.
- AC-4 `konnektor.md`: "nicht erreichbar" ehrlich vermerkt, Ersatz `check-outside.sh` 12x OK, Exit 0, inkl. `/mcp` 401. Die Spec erlaubt das ausdrücklich.
- AC-5 `nginx-dump.txt`: drei `location =` mit `limit_req zone=loose_ends_auth burst=10 nodelay`, `limit_req_status 429`, `client_max_body_size 16k`, `proxy_pass http://127.0.0.1:8780`, vier Header; Zone `rate=5r/s`; `location ^~ /auth/` mit `return 404`; Kopfzeile nennt die drei Pfade. Auszug (Zeilen 13-87 fehlen, siehe F001).
- AC-6 `nginx-test.txt`: Sicherung `/home/hem/backups/nginx-loose-ends.henemm.com.20261110T154301Z.conf` = `nginx-alt.conf`, "syntax is ok / test is successful", danach "reload Exit: 0"; Rückweg beschrieben. Das Skript lädt nur im Erfolgszweig.
- AC-7 `infra-pr-b.txt`: PR 420. Meine Prüfung: MERGED, Merge 12e857e3, files genau `nginx/loose-ends.henemm.com.conf` (+38/-2) und `security/expected-exposure.json` (+4/-1). Exposure-Datei auf main (gh api): /auth/apple, /auth/logout, /auth/delete je [405], /auth/x [404], kein 404 für /auth/apple. `gh pr checks 420`: "no checks reported"; Ersatz pytest "502 passed, 6 skipped" auf rennwienix (siehe F002).
- AC-8 `green.txt` (15:43:08Z), `green-wiederholung.txt` (16:43Z) und mein eigener Lauf `adversary-test-output.txt` (16:44:42Z): 8x OK, "Anfragen gesendet: 8 (höchstens 8), 429 gesehen: nein", Exit 0. Die Wiederholung misst denselben Zustand ein zweites Mal, kein Widerspruch; 429-frei, also kein fail2ban-Risiko eingegangen.
- AC-9 `scan.txt`: "OK: Außensicht entspricht der Soll-Liste", Exit 0, Soll-Liste nennt die loose-ends-URLs inkl. der drei neuen (von mir gegengelesen).
- AC-10 `monitor-vorher/nachher.txt`: `diff` zeigt nur Zeit- und Messwerte (Uhrzeit, Load, CPU-/RAM-Prozente, "letzter Lauf"), den Container `loose-ends-server` (Up 2 days, dann Up 5 minutes) und die auto-deploy-infra-Zeile (Hash 0adca37e, dann e0443b87, Folge von PR 419). Andere Container unverändert (n8n Up 9 days, stalwart-mail Up 13 hours usw. in beiden Dateien identisch), uptime 24 Tage durchgehend, Loose-Ends (200) grün. Wörtlich "keine Zeile" ist nicht erfüllbar (siehe F003).
- AC-11 `loeschen-lokal.md`/`loeschen-lokal.sh`: Wegwerf-Postgres 18.6 auf 127.0.0.1, "Vorher 1 1, 204, Nachher 0 0, zweiter Aufruf 401". Simulator `simulator-run.txt`: "8 gesamt, 8 bestanden, 0 fehlgeschlagen, 0 übersprungen", Screenshot `loeschen-dialog.png` vorhanden. `loeschen-live.txt`: "nie mit einer gültigen Sitzung aufgerufen"; live nur die 401-Zeilen aus green.txt. Befund nennt ausdrücklich: Simulator stellt keine echte Apple-Anmeldung her.
- AC-12 Diff von CLAUDE.md: Betrieb-Absatz nennt "since #615 S4d also `/auth/apple`, `/auth/logout` and `/auth/delete` (zone `loose_ends_auth`, 16k; evidence `docs/artifacts/feat-615-s4d-auth-oeffnen/`); the rest of `/auth/` and everything else stay 404". Alle 16 geforderten Belege vorhanden, zwei unter neuen Namen: `nginx-dump.txt`/`nginx-test.txt`. Die Umbenennung steht offen im Kopf von `nginx-dump.txt`, in `stand-phase6.md` und im Issue-Kommentar zu #615 ("nginx-T.txt/nginx-t.txt heißen nginx-dump.txt/nginx-test.txt, weil macOS die Namen nicht unterscheidet"). Dort steht auch der Stand 4d. Der Inhalt trägt AC-5 und AC-6 vollständig.

### Runde 2
**Adversary:** Nachbohren an Edge Cases aus der nginx-Konfiguration (keine zusätzlichen Live-Anfragen): (1) `^~ /auth/` schließt alles: `^~` verhindert die Regex-Prüfung; `= /auth/apple` gewinnt nur bei exakter Übereinstimmung, `/auth/apple/` (Schrägstrich), `/auth/apple/x`, `/auth/applex` fallen in `^~ /auth/` und geben 404. (2) Groß-/Kleinschreibung: nginx-Locations sind case-sensitiv, `/AUTH/apple` trifft keine der Locations und fällt in den Rest des Server-Blocks; ob das 404 ist, hängt vom Catch-all in den nicht gezeigten Zeilen 13-87 ab. (3) HEAD: wird wie GET an den Dienst gereicht (kein `limit_except`); der Dienst weist Nicht-POST mit 405 ab, öffnet also nichts. (4) `//auth/apple`, `%61uth/apple`: nginx normalisiert vor dem Location-Abgleich (merge_slashes, Dekodierung), gleiches Ergebnis wie der Normalpfad, keine Umgehung. (5) 413 kommt bei 17 KiB aus nginx (`client_max_body_size 16k`), nicht aus dem Dienst: Beleg für die vordere Grenze, die Dienstgrenze gleicher Höhe ist in `server/test` belegt. (6) Zone `loose_ends_auth` gilt für die drei Pfade gemeinsam: 5 r/s, burst 10; ein Angreifer erzeugt höchstens 429 für die eigene Adresse; fail2ban-Wirkung wie bei den anderen Zonen (Spec-Risiko benannt). (7) Fehlerfall beim Reload: das Skript kopiert bei fehlgeschlagenem `nginx -t` die Sicherung zurück und lädt nicht. (8) 405-Beweiskraft: ohne Apple-Konfiguration würde GET /auth/apple 503 liefern; 405 beweist die Konfiguration. Alles sauber, aber (2) ist aus dem Auszug allein nicht beweisbar.
**Implementierer:** `nginx-dump.txt` (Block `location ^~ /auth/` mit `return 404`), Auszugsvermerk "Zeilen 1–12 und 88–128 der Ausgabe"; `konnektor.md` zeigt "OK 404 GET / (soll 404)" und die Exposure-Datei erwartet `https://loose-ends.henemm.com/` [404], vom Scan mit Exit 0 bestätigt: der Catch-all antwortet 404, `/AUTH/apple` landet damit im selben Zweig wie `/`. Die Spec fordert genau drei `location =` im Auszug; die sichtbaren Zeilen zeigen drei, die unsichtbaren Zeilen 13-87 sind die bestehenden Blöcke (`/health`, `/mcp`, `.well-known`, `/oauth/`) und wurden von der Außenprüfung bestätigt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Befunde

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-dump.txt:1
  Description: Der Beleg für AC-5 ist ein Auszug (Zeilen 1-12 und 88-128); die Zeilen 13-87 des Server-Blocks sind durch [...] ersetzt.
  Spec requirement: AC-5 — Auszug des Server-Blocks aus nginx -T mit genau drei location = für /auth/*.
  Conflict: "Genau drei" und das Verhalten für Pfade außerhalb der Locations (z. B. /AUTH/apple) sind aus dem Auszug allein nicht beweisbar; indirekt gedeckt durch scan.txt (/ 404, /auth/x 404) und green.txt.
  Remediation: Bei nächster Gelegenheit den vollständigen Server-Block ablegen.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-b.txt:9
  Description: AC-3 und AC-7 verlangen "CI grün"; gh pr checks 419 und 420 melden "no checks reported". Ersatz: pytest 502 passed, 6 skipped im Wegwerfklon auf rennwienix, in beiden Belegen offen genannt.
  Spec requirement: AC-3/AC-7 — CI des PR grün.
  Conflict: Wortlaut nicht erfüllbar, weil das Repo keine CI hat; der Ersatz belegt die Repo-eigene Testsuite.
  Remediation: Spec-Wortlaut künftig "Tests des Infra-Repos grün"; kein Nacharbeiten nötig.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/monitor-nachher.txt:34
  Description: Der diff der Monitor-Belege enthält Zeilen anderer Dienste (Zeit-/Lastwerte, auto-deploy-infra mit neuem Hash als Folge von PR 419; CPU-Zeile war schon vorher rot).
  Spec requirement: AC-10 — keine Zeile eines anderen Dienstes im diff.
  Conflict: Wörtlich unerfüllbar (Zeitstempel); semantisch erfüllt: kein Zustandswechsel, kein Neustart anderer Container, uptime durchgehend.
  Remediation: Spec-Formulierung auf "keine Zustandsänderung" präzisieren.

Finding:
  ID: F004
  Severity: LOW
  Category: anti_pattern
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/variablen.txt:5
  Description: Die Leckprüfzeile enthält das Literal der PEM-Kopfzeile; die Suche danach hat laut wertscan.txt einen Treffer (Beschreibungssatz, kein Schlüssel).
  Spec requirement: AC-1/AC-12 — Suche nach dem PEM-Kopf ergibt 0 Treffer.
  Conflict: Wörtlich 1 Treffer; als Fehlalarm erklärt und geprüft (kein Schlüsselmaterial).
  Remediation: Satz umformulieren, damit der Scan 0 Treffer liefert.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/check-auth.sh:36
  Description: Der 413-Fall prüft nur die vordere Grenze (nginx 16k bei 17 KiB), nicht den Randwert 16384 Byte und nicht die Dienstgrenze. konnektor.md belegt keinen echten get_now. CLAUDE.md sagt "APPLE_* are in the Compose stack since #615 S4d", obwohl sie laut variablen.txt schon vorher dort standen (ungenau, harmlos).
  Spec requirement: AC-8, AC-4, AC-12
  Conflict: Keine Verletzung; Belegkraft begrenzt, wie die Spec im Abschnitt "Ehrlich zur Belegkraft" selbst festhält.
  Remediation: Keine; CLAUDE.md-Satz bei nächster Änderung präzisieren.

Confirmation:
  AC: AC-1
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/variablen.txt:3
  Evidence: ja/ja-Zeilen ohne Wert; GET /auth/apple 405 statt 503 beweist geladene Apple-Konfiguration.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/red.txt:1
  Evidence: Sieben FEHLT 404, GET /auth/x OK, Exit 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-a.txt:3
  Evidence: PR 419 MERGED, nur deploy-loose-ends.sh +1/-1, fb6689a Vorfahr, Deploy Exit 0, Container c62fbae, /health 200 (deploy.txt); CI-Ersatz siehe F002.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/konnektor.md:1
  Evidence: Konnektor ehrlich als nicht erreichbar vermerkt, Ersatz check-outside.sh Exit 0 inkl. /mcp 401.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-dump.txt:15
  Evidence: drei location =, Zone 5r/s, limit_req_status 429, 16k, proxy_pass 127.0.0.1:8780, vier Header, ^~ /auth/ return 404, Kopfzeile nennt die Pfade (Auszug, F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-test.txt:6
  Evidence: Sicherung mit Ort, nginx -t ok vor reload, reload Exit 0, nginx-alt.conf vorhanden; Namensabweichung offen genannt.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-b.txt:3
  Evidence: PR 420 MERGED, genau zwei Dateien, Exposure 405/405/405/404, pytest 502 passed; CI-Ersatz siehe F002.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/adversary-test-output.txt:1
  Evidence: Eigener Lauf 16:44:42Z, acht OK, 8 Anfragen, kein 429, Exit 0; deckt green.txt und green-wiederholung.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/scan.txt:9
  Evidence: Außenscan Exit 0 "Außensicht entspricht der Soll-Liste"; Soll-Liste auf main 12e857e gegengelesen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/monitor-nachher.txt:5
  Evidence: Nur loose-ends-server neu, andere Container, uptime und Loose-Ends (200) unverändert; F003 zur Wortlautabweichung.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/loeschen-lokal.md:19
  Evidence: Lokal 1 1, 204, 0 0, 401; Simulator 8/8 grün; live nie mit gültiger Sitzung (loeschen-live.txt); Simulatorgrenze benannt.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: docs/artifacts/feat-615-s4d-auth-oeffnen/wertscan.txt:3
  Evidence: CLAUDE.md-Diff nennt drei Pfade, Zone, 16k, Rest 404, Belegordner; Beleglisten vollständig (zwei umbenannt, offen genannt); Issue-Kommentar "Stand Schnitt 4d" vorhanden; Wertscan 0 Geheimnistreffer (Fehlalarm F004). Die Board-Karte konnte ich nicht prüfen.
  Status: CONFIRMED

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hat die Gegenprüfung überstanden. Fünf LOW-Befunde (Belegform und Spec-Wortlaut), keiner blockiert.
Tests: Infra-pytest laut Beleg 502 passed, 0 failed, 6 übersprungen (Infra-Repo, nicht dieser Schnitt); Simulator AccountSettingsTests 8 passed, 0 failed, 0 übersprungen; check-auth.sh 8/8 OK (eigener Lauf, Exit 0)
Edge cases: Schrägstrich, Groß-/Kleinschreibung, HEAD, Pfadnormalisierung aus der Konfiguration beurteilt; keine Umgehung
Regressions: keine (andere Container unverändert, nur loose-ends-server neu)
Checklist: 12/12 points proven

## Geprüfte Dateien

- sha256:a51c44daa96952b4d3a035e573cd46d6f005489aed262bd8070ecd16f5717d9a  docs/artifacts/feat-615-s4d-auth-oeffnen/adversary-test-output.txt
- sha256:ef16b40fecd1367a2eb01040fac4211cc8933535fc907a35342f0afd5ad82215  docs/artifacts/feat-615-s4d-auth-oeffnen/check-auth.sh
- sha256:3cb5678692d9945a9197ddd79034938ff91d7eaf11f1dfe5e2e2991f3e59d113  docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-a.txt
- sha256:4f25a35e68a52d4da7a71ea491246ffffff3de7aed47b64f90f8fed49198d952  docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-b.txt
- sha256:6790480c18af99740f98ee684321cb6a31ddc0b93ec5827a0cebb9226d2d43c8  docs/artifacts/feat-615-s4d-auth-oeffnen/konnektor.md
- sha256:ebba10a8c3f9aadd52dcce4fa33c2cfd5d11c7362d374ab085f502a1fc2617d1  docs/artifacts/feat-615-s4d-auth-oeffnen/loeschen-lokal.md
- sha256:c58f676e6ede032af2803e360567e157eddf436fb6021412e8086f513b18406a  docs/artifacts/feat-615-s4d-auth-oeffnen/monitor-nachher.txt
- sha256:5cbdda86b28a53cab77a4dd05b71746e4a353be1f3d2b4bf9bec3b75d7631ed1  docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-dump.txt
- sha256:113d15862eb238c90e97b24258c07878dd97809767c4550df0179cde366c9273  docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-test.txt
- sha256:a49cb402b71070b7cef520d56bb34cb93ff3a2a4d59e2c687515403b45d83619  docs/artifacts/feat-615-s4d-auth-oeffnen/red.txt
- sha256:8eb5ef41b8c5854c1c5c5e1899de70179e1315d8c282217c1d2bc0ac5f7a1518  docs/artifacts/feat-615-s4d-auth-oeffnen/scan.txt
- sha256:35aff26945e7e4dc6a7081e7a2b1cfee37db755315d666d62532ef7fccaf250b  docs/artifacts/feat-615-s4d-auth-oeffnen/variablen.txt
- sha256:10853e072d469365c979389b14fd3e2ae410f00ea7542b8d350068719786d350  docs/artifacts/feat-615-s4d-auth-oeffnen/wertscan.txt

## Prüfbasis

- base: c62fbae4550368d97cf3132fcd9667fa5e8c75d8
- blob:92f1877b9acc2a108bac77e8080782f89f89b286  docs/artifacts/feat-615-s4d-auth-oeffnen/adversary-test-output.txt
- blob:b5c28cd32fc298574cbda2c778a563b7b6523eb7  docs/artifacts/feat-615-s4d-auth-oeffnen/check-auth.sh
- blob:3db4429ca74adf93b7c71bd3d9d041dea8767cc8  docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-a.txt
- blob:0ac01374acfe934d60fde0559e8962bdbef40254  docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-b.txt
- blob:77ad02d4b22502eb5fe6fe3555a438d29cec5840  docs/artifacts/feat-615-s4d-auth-oeffnen/konnektor.md
- blob:909d34bdcc3ba184a90c6a02dd465ea406494ff8  docs/artifacts/feat-615-s4d-auth-oeffnen/loeschen-lokal.md
- blob:04d5c3a3837ae7371387dffed96e1ecbb4860bdc  docs/artifacts/feat-615-s4d-auth-oeffnen/monitor-nachher.txt
- blob:1fc5ac31591dcc087c0b5f34f869379db8522f8d  docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-dump.txt
- blob:0b207b7b8c0fbc0abae33df70d3869674b16cebb  docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-test.txt
- blob:89d04cc86cf8853d2447a0d2dfba79b2c41a2257  docs/artifacts/feat-615-s4d-auth-oeffnen/red.txt
- blob:aa3ed50bc42beddc4bc797a9acd30329c24413f8  docs/artifacts/feat-615-s4d-auth-oeffnen/scan.txt
- blob:d8d9fdde15fabb71176618a6a6cfc3cedb7eaf41  docs/artifacts/feat-615-s4d-auth-oeffnen/variablen.txt
- blob:0cc225a24179bf383ea43cd10be7b5b9b0fa822b  docs/artifacts/feat-615-s4d-auth-oeffnen/wertscan.txt

## Geprüfte Dateien

- sha256:a51c44daa96952b4d3a035e573cd46d6f005489aed262bd8070ecd16f5717d9a  docs/artifacts/feat-615-s4d-auth-oeffnen/adversary-test-output.txt
- sha256:ef16b40fecd1367a2eb01040fac4211cc8933535fc907a35342f0afd5ad82215  docs/artifacts/feat-615-s4d-auth-oeffnen/check-auth.sh
- sha256:3cb5678692d9945a9197ddd79034938ff91d7eaf11f1dfe5e2e2991f3e59d113  docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-a.txt
- sha256:4f25a35e68a52d4da7a71ea491246ffffff3de7aed47b64f90f8fed49198d952  docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-b.txt
- sha256:6790480c18af99740f98ee684321cb6a31ddc0b93ec5827a0cebb9226d2d43c8  docs/artifacts/feat-615-s4d-auth-oeffnen/konnektor.md
- sha256:ebba10a8c3f9aadd52dcce4fa33c2cfd5d11c7362d374ab085f502a1fc2617d1  docs/artifacts/feat-615-s4d-auth-oeffnen/loeschen-lokal.md
- sha256:c58f676e6ede032af2803e360567e157eddf436fb6021412e8086f513b18406a  docs/artifacts/feat-615-s4d-auth-oeffnen/monitor-nachher.txt
- sha256:5cbdda86b28a53cab77a4dd05b71746e4a353be1f3d2b4bf9bec3b75d7631ed1  docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-dump.txt
- sha256:113d15862eb238c90e97b24258c07878dd97809767c4550df0179cde366c9273  docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-test.txt
- sha256:a49cb402b71070b7cef520d56bb34cb93ff3a2a4d59e2c687515403b45d83619  docs/artifacts/feat-615-s4d-auth-oeffnen/red.txt
- sha256:8eb5ef41b8c5854c1c5c5e1899de70179e1315d8c282217c1d2bc0ac5f7a1518  docs/artifacts/feat-615-s4d-auth-oeffnen/scan.txt
- sha256:35aff26945e7e4dc6a7081e7a2b1cfee37db755315d666d62532ef7fccaf250b  docs/artifacts/feat-615-s4d-auth-oeffnen/variablen.txt
- sha256:10853e072d469365c979389b14fd3e2ae410f00ea7542b8d350068719786d350  docs/artifacts/feat-615-s4d-auth-oeffnen/wertscan.txt

## Prüfbasis

- base: c62fbae4550368d97cf3132fcd9667fa5e8c75d8
- blob:92f1877b9acc2a108bac77e8080782f89f89b286  docs/artifacts/feat-615-s4d-auth-oeffnen/adversary-test-output.txt
- blob:b5c28cd32fc298574cbda2c778a563b7b6523eb7  docs/artifacts/feat-615-s4d-auth-oeffnen/check-auth.sh
- blob:3db4429ca74adf93b7c71bd3d9d041dea8767cc8  docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-a.txt
- blob:0ac01374acfe934d60fde0559e8962bdbef40254  docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-b.txt
- blob:77ad02d4b22502eb5fe6fe3555a438d29cec5840  docs/artifacts/feat-615-s4d-auth-oeffnen/konnektor.md
- blob:909d34bdcc3ba184a90c6a02dd465ea406494ff8  docs/artifacts/feat-615-s4d-auth-oeffnen/loeschen-lokal.md
- blob:04d5c3a3837ae7371387dffed96e1ecbb4860bdc  docs/artifacts/feat-615-s4d-auth-oeffnen/monitor-nachher.txt
- blob:1fc5ac31591dcc087c0b5f34f869379db8522f8d  docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-dump.txt
- blob:0b207b7b8c0fbc0abae33df70d3869674b16cebb  docs/artifacts/feat-615-s4d-auth-oeffnen/nginx-test.txt
- blob:89d04cc86cf8853d2447a0d2dfba79b2c41a2257  docs/artifacts/feat-615-s4d-auth-oeffnen/red.txt
- blob:aa3ed50bc42beddc4bc797a9acd30329c24413f8  docs/artifacts/feat-615-s4d-auth-oeffnen/scan.txt
- blob:d8d9fdde15fabb71176618a6a6cfc3cedb7eaf41  docs/artifacts/feat-615-s4d-auth-oeffnen/variablen.txt
- blob:0cc225a24179bf383ea43cd10be7b5b9b0fa822b  docs/artifacts/feat-615-s4d-auth-oeffnen/wertscan.txt
