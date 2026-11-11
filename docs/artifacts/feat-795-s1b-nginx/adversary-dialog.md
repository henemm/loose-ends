# Adversary Dialog — feat-795-s1b-nginx
Spec: docs/specs/feat-795-schnitt-1b-nginx.md
Datum: 2026-11-11 23:25

## Checkliste
- [x] **AC-1:** RED des Prüfskripts: GIVEN `docs/artifacts/feat-795-s1b-nginx/check-app.sh` WHEN es vor der nginx-Änderung gegen `https://loose-ends.henemm.com` läuft THEN endet es mit Exit ≠ 0, und `red.txt` zeigt `FEHLT` mit 404 für die drei `POST` ohne Sitzung (erwartet 401), die drei `GET` (erwartet 405) und den 300-KiB-Körper (erwartet 413); `GET /app/x` ist schon `OK` mit 404; die Datei nennt genau acht gesendete Anfragen.
- [x] **AC-2:** nginx öffnet genau drei Pfade: GIVEN die Datei `nginx/loose-ends.henemm.com.conf` WHEN der Auszug des Server-Blocks aus `nginx -T` gelesen wird THEN enthält er genau drei `location =` für `/app/transcript`, `/app/orders/claim` und `/app/orders/result`, jeweils mit `limit_req zone=loose_ends_app burst=40 nodelay`, `client_max_body_size 256k`, `proxy_pass http://127.0.0.1:8780` und den vier Headern `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto` wie bei `/health`; es gibt unter `/app/` keine Streaming-Einstellung (`proxy_buffering off`, `proxy_read_timeout`) (Beleg `nginx-T.txt`, ohne Geheimnisse).
- [x] **AC-3:** Eigene Zone, Anmeldung unberührt: GIVEN dieselbe Datei WHEN die `limit_req_zone`-Zeilen gelesen werden THEN gibt es `loose_ends_app` mit `rate=10r/s` und `limit_req_status 429` für die drei App-Pfade, die Zone `loose_ends_auth` hat unverändert `rate=5r/s`, und keiner der drei App-Pfade verwendet `loose_ends_auth` (`grep` auf `zone=loose_ends_auth` im Block der App-Pfade ergibt 0 Treffer, die Auth-Pfade verwenden sie wie vorher; Beleg `nginx-T.txt` mit dem Vergleich zu `nginx-alt.conf`).
- [x] **AC-4:** Der Rest bleibt zu: GIVEN dieselbe Datei WHEN sie gelesen wird THEN enthält sie `location ^~ /app/ { return 404; }`, `^~ /auth/` und `location / { return 404; }` weiterhin mit 404, und die Kopfzeile der Datei nennt die drei App-Pfade samt Zone (Beleg `nginx-T.txt`).
- [x] **AC-5:** `expected-exposure.json` und Infra-PR: GIVEN der PR in `henemm/henemm-infra` WHEN er geöffnet ist THEN ändert er genau `nginx/loose-ends.henemm.com.conf` und `security/expected-exposure.json`; die JSON-Datei enthält `/app/transcript`, `/app/orders/claim`, `/app/orders/result` je GET → 405 und `/app/x` → 404; `python3 -m pytest tests -q` im Wegwerfklon auf `rennwienix` ist grün und die CI des PR ist grün (Beleg `infra-pr.txt`: PR-Nummer, Kennungen, Teststand, CI-Status).
- [x] **AC-6:** nginx wird nur nach Test geladen, mit Rückweg: GIVEN die neue Datei auf dem Server WHEN sie in Kraft gesetzt wird THEN ist die alte Datei vorher gesichert (`nginx-alt.conf` im Belegordner, Ort der Sicherung auf dem Server genannt), `nginx -t` zeigt `syntax is ok` und `test is successful`, `systemctl reload nginx` läuft erst danach mit Exit 0 (Beleg `nginx-t.txt` mit Zeitstempeln, Reload später als Test); bei Fehler im Test wird nicht geladen.
- [x] **AC-7:** Öffnung von außen, GREEN: GIVEN nginx ist geladen WHEN `check-app.sh` von außen läuft THEN Exit 0 und `green.txt` zeigt `OK` mit den drei `POST` ohne Sitzung je 401, den drei `GET` je 405, `GET /app/x` 404 und `POST /app/transcript` mit 300-KiB-Körper 413; die Schlusszeilen nennen genau acht gesendete Anfragen und `429 gesehen: nein`.
- [x] **AC-8:** 413 kommt von nginx, nicht vom Dienst: GIVEN der 300-KiB-Körper aus AC-7 WHEN die Antwort geprüft wird THEN ist der Status 413 ohne Anmeldung (ohne `Authorization`-Kopf; der Dienst würde 401 geben), und die Zeile im Zugriffsprotokoll von nginx für diese Anfrage zeigt 413 (Beleg `green.txt` mit dem Zusatz „ohne Bearer, daher von nginx“ und `nginx-413.txt` mit der Protokollzeile, ohne Adressen und Geheimnisse).
- [x] **AC-9:** Exposure-Prüfung ohne Abweichung und andere Hosts unverändert: GIVEN `security/expected-exposure.json` aus AC-5 WHEN `check-external-exposure.sh` (oder der Einzelaufruf des Scans der Infra) läuft THEN meldet er für `loose-ends.henemm.com` keine Abweichung (Beleg `scan.txt`: Zeilen des Hosts mit Status); GIVEN `monitor.sh --status` auf `rennwienix` WHEN es vor Beginn der Serverarbeit und nach dem Reload läuft THEN zeigt `diff` von `monitor-vorher.txt` und `monitor-nachher.txt` keine Zeile eines anderen Dienstes als `loose-ends`, und `loose-ends` ist `OK`; läuft der Scan nur nachts und ist nicht vorziehbar, steht im Beleg der Zeitpunkt des nächsten Laufs und `todo-scan.md` im Belegordner, den der Tech Lead beim nächsten Sitzungsstart prüft, nie Henning.
- [x] **AC-10:** Vertrag mit 429-Regel: GIVEN `docs/reference/claude-abschrift-vertrag.md` WHEN der Abschnitt „Wege der App“ gelesen wird THEN nennt er, dass nginx die drei Wege auf 10 Anfragen je Sekunde (Stoß bis 40) begrenzt und bei Überschreitung 429 antwortet, und legt als Pflicht der App fest: bei 429 den Abholdurchgang abbrechen und erst beim nächsten Anlass fortsetzen, ohne Schleife; der Vertrag enthält weiterhin genau drei ```json-Blöcke (die Tests von `server/test/orders.test.ts` lesen genau drei; der neue Text steht als Fließtext oder ```text, Prüfung per `grep -c '^```json'` ergibt 3).
- [x] **AC-11:** `CLAUDE.md` aktuell: GIVEN der Doku-PR WHEN er geöffnet ist THEN steht im Absatz `src/app-routes.ts` im Abschnitt `server/` nicht mehr „nginx (`/app/`, S1b) … still open“, sondern dass `/app/transcript`, `/app/orders/claim` und `/app/orders/result` seit S1b offen sind (Zone `loose_ends_app`, 256k, Rest unter `/app/` 404), der App-Client (S2) noch offen ist und `refused` 409 ein Ergebnis zu einem Auftrag meint, den dieses Gerät nicht (mehr) hält; der Betrieb-Absatz nennt `/app/…` in der Liste der offenen Pfade mit Verweis auf den Belegordner.
- [x] **AC-12:** Belege vollständig und ohne Geheimnisse: GIVEN der Belegordner WHEN er geprüft wird THEN enthält er `check-app.sh`, `red.txt`, `infra-pr.txt`, `nginx-T.txt`, `nginx-t.txt`, `nginx-alt.conf`, `nginx-413.txt`, `green.txt`, `scan.txt`, `monitor-vorher.txt`, `monitor-nachher.txt`; die Suche nach Wertmustern (`-----BEGIN`, `Bearer ` mit folgendem Wert, `"d":`) ergibt 0 Treffer; die Karte #795 ist aktuell und #795 hat einen Kommentar mit dem Stand S1b (Folge S2).

## Dialog

### Runde 1
**Adversary:** Eigene Nachpruefung gegen die Quellen, nicht gegen die Belegtexte. Infra-PR 431 via gh: state MERGED, mergeCommit bd6c405, files genau nginx/loose-ends.henemm.com.conf (+43/-1) und security/expected-exposure.json (+4/-0). Datei auf main per gh api gelesen: 3x `location = /app/`, 4x `zone=loose_ends_app` (1 Zonendefinition, 3 Nutzungen), im App-Block kein loose_ends_auth, kein proxy_buffering, kein proxy_read_timeout. Live-Konfiguration per `sudo nginx -T` (nur lesend) gegen main verglichen: 0 Abweichungen (whitespace-normalisiert). Diff main gegen nginx-alt.conf: nur Kommentarkopf, neue Zone, drei Bloecke, `^~ /app/` 404; loose_ends_auth unveraendert (rate=5r/s, 3 Nutzungen vorher und nachher). expected-exposure.json auf main enthaelt die vier /app/-Eintraege (405,405,405,404). Ein eigener Lauf check-app.sh von aussen (genau 8 Anfragen): Exit 0, alle OK, 429 nein (adversary-test-output.txt). Vertrag: 3 json-Bloecke, Absatz "Mengengrenze" mit 10 r/s, Stoss 40, 429, Abbruchpflicht ohne Schleife. Wertscan: 0 Treffer ausserhalb des Dialog-Geruests (das Geruest zitiert die Muster selbst). #795-Kommentar mit "Stand S1b" vorhanden.
**Implementierer:** Belege vorhanden, Abweichungen (Dateinamen, keine CI, Doppel-Scan) offengelegt.

### Runde 2
**Adversary:** Gegenpruefung der bekannten Abweichungen und Schwachstellen. (1) Dateinamen nginx-dump.txt/nginx-test.txt: Inhalt deckt AC-2..4 und AC-6 vollstaendig, Erklaerung steht im Kopf beider Dateien; case-insensitive Kollision ist real, Abweichung akzeptiert. (2) Keine CI im Infra-Repo: `gh pr view 431` zeigt statusCheckRollup leer; Ersatz pytest 524 passed/6 skipped im Wegwerfklon des PR-Zweigs; 0 Failures, die 6 skipped stammen aus Infra-Tests ohne Bezug zu nginx (Hinweis, nicht belegt pro Test). (3) Reihenfolge AC-6: Sicherung, nginx -t, reload alle 21:29:50Z, reload nur im Erfolgszweig; Zeitstempel gleiche Sekunde, Reihenfolge nur durch Textreihenfolge und Beschreibung belegt (LOW). (4) AC-8: Zugriffsprotokollzeile zeigt 413 fuer POST /app/transcript, Zeit gleich dem GREEN-Lauf, ohne Bearer, daher nginx. (5) AC-9: scan.txt zeigt nur die Gesamtzeile "OK: Aussensicht entspricht der Soll-Liste", nicht Zeilen je Host; die Spec verlangt "Zeilen des Hosts mit Status". Die Einzelcodes werden indirekt ueber green.txt und die Soll-Liste belegt (LOW). Monitor-Diff: nur Zeit, Uptime, Last, RAM/CPU, "letzter Lauf", Infra-Stand, kein Dienstzustand wechselt; loose-ends OK. (6) Einwand: erster Scanlauf hing, zweiter 16 Minuten; Erfolgsstempel 22:08:24Z passt. Kein Widerspruch gefunden. (7) 429-Pfad: nicht von aussen belegt (bewusst, fail2ban-Risiko); Spec bestaetigt das ausdruecklich als Out of Scope der Belegkraft.
**Implementierer:** Abweichungen akzeptiert, keine Nacharbeit noetig.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: docs/artifacts/feat-795-s1b-nginx/scan.txt:20
  Description: scan.txt belegt "keine Abweichung" nur ueber die Gesamtzeile des Skripts; Zeilen je Host mit Status fehlen, weil das Skript bei Erfolg nichts Einzelnes ausgibt.
  Spec requirement: AC-9 — Beleg scan.txt: Zeilen des Hosts mit Status
  Conflict: Pro-Host-Zeilen fehlen; Ersatz ist die Soll-Liste plus green.txt. Inhaltlich ausreichend, formal schwaecher.
  Remediation: Optional beim naechsten Betriebsschnitt eine Ausgabe je URL aus dem Skript ermoeglichen.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: docs/artifacts/feat-795-s1b-nginx/nginx-test.txt:16
  Description: Reihenfolge nginx -t vor reload ist nur durch gleiche Sekunde und Beschreibung des Ein-Aufruf-Ablaufs belegt, nicht durch feinere Zeitstempel.
  Spec requirement: AC-6 — Beleg mit Zeitstempeln, Reload spaeter als Test
  Conflict: Zeitstempel identisch statt strikt spaeter.
  Remediation: Keine, Ablauf mit Erfolgszweig ist beschrieben; kuenftig Sekundenbruchteile loggen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: docs/artifacts/feat-795-s1b-nginx/red.txt:1
  Evidence: 7x FEHLT 404 (3 POST, 3 GET, 413-Fall), GET /app/x OK 404, "Anfragen gesendet: 8", Exit 1; check-app.sh:36-47 sendet genau acht Anfragen ohne Schleife und ohne Authorization.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: docs/artifacts/feat-795-s1b-nginx/nginx-dump.txt:34
  Evidence: Drei location = je mit limit_req burst=40 nodelay, client_max_body_size 256k, proxy_pass 8780, vier Header; kein buffering/timeout; selbst gegen main und Live-nginx -T verglichen, 0 Abweichung.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/artifacts/feat-795-s1b-nginx/nginx-dump.txt:15
  Evidence: Zone loose_ends_app rate=10r/s, limit_req_status 429 in allen drei Bloecken, loose_ends_auth unveraendert 5r/s, 0 Nutzungen in App-Bloecken; Diff gegen docs/artifacts/feat-795-s1b-nginx/nginx-alt.conf bestaetigt.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/artifacts/feat-795-s1b-nginx/nginx-dump.txt:72
  Evidence: location ^~ /app/ 404, ^~ /auth/ 404, location / 404 vorhanden; Kopfkommentar nennt die drei Pfade und die Zone.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: docs/artifacts/feat-795-s1b-nginx/infra-pr.txt:3
  Evidence: PR 431 MERGED bd6c405, genau zwei Dateien (selbst per gh geprueft), expected-exposure.json mit vier /app/-Eintraegen auf main gelesen, pytest 524 passed/6 skipped, CI-Ersatz offengelegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: docs/artifacts/feat-795-s1b-nginx/nginx-test.txt:11
  Evidence: Sicherung mit Serverpfad, nginx -t syntax ok und test successful, reload Exit 0 im Erfolgszweig, alte Datei als nginx-alt.conf im Ordner.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/artifacts/feat-795-s1b-nginx/green.txt:1
  Evidence: Acht OK-Zeilen (401x3, 405x3, 404, 413), "429 gesehen: nein", Exit 0; eigener Wiederholungslauf in docs/artifacts/feat-795-s1b-nginx/adversary-test-output.txt:1 identisch (22:28:21Z).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/artifacts/feat-795-s1b-nginx/nginx-413.txt:8
  Evidence: nginx-Protokollzeile 413 176 Bytes fuer POST /app/transcript, Anfrage ohne Authorization, Dienst haette 401 gegeben.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: docs/artifacts/feat-795-s1b-nginx/scan.txt:11
  Evidence: Skript Exit 0 "OK: Aussensicht entspricht der Soll-Liste" gegen Soll-Liste bd6c405; monitor-Diff (docs/artifacts/feat-795-s1b-nginx/monitor-nachher.txt:1) ohne Dienstwechsel, loose-ends OK. Siehe F001.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: docs/reference/claude-abschrift-vertrag.md:192
  Evidence: Absatz "Mengengrenze (#795 S1b)" nennt 10 r/s, Stoss 40, 429, Pflicht: Abbruch des Durchgangs, naechster Anlass, keine Schleife; grep -c json-Bloecke = 3.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: CLAUDE.md:527
  Evidence: "still open" fuer nginx entfernt, refused 409 erklaert, seit S1b offen (Zone, 10r/s burst 40, 256k, Rest 404), S2 offen; Betrieb-Absatz CLAUDE.md:536 nennt die drei Pfade mit Belegordner.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: docs/artifacts/feat-795-s1b-nginx/check-app.sh:1
  Evidence: Alle elf Belege vorhanden (zwei Namen abweichend, begruendet), Wertscan 0 Treffer ausserhalb des Geruests, #795-Kommentar "Stand S1b" per gh gesehen; Board-Stand In progress, In review folgt mit PR (laut Auftrag, nicht selbst geprueft).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: 524 passed (Infra-pytest laut Beleg), 0 failed, 6 uebersprungen (Infra, nginx-fremd); check-app.sh eigener Lauf Exit 0, 8/8 OK
Edge cases: All checked, none broken (zwei LOW-Hinweise F001, F002)
Regressions: None found (Live-nginx == main, loose_ends_auth unveraendert, monitor-Diff ohne Dienstwechsel)
Checklist: 12/12 points proven

## Geprüfte Dateien

- sha256:5509eed89d169b5607d88364f8f1cbbf81a24a94b241545228d4619eaa3ba675  CLAUDE.md
- sha256:802af9db555c4cb9088851617fdf397a2a34bd0b60bc64dfbef9c3c5d5250090  docs/artifacts/feat-795-s1b-nginx/check-app.sh
- sha256:f4630e8d38b899f6e0bba6b0f8b48f4726edc5c6f4da6731e6be2edd8bc0110e  docs/artifacts/feat-795-s1b-nginx/green.txt
- sha256:08ece123182bf0e6809e28fad9002c53c09926ca28ea97f6313bdc9f073c8e38  docs/artifacts/feat-795-s1b-nginx/infra-pr.txt
- sha256:eb71b25ab2f93b7547c31f1ea05303f8057de2ee90e370216df9d303e68f947d  docs/artifacts/feat-795-s1b-nginx/nginx-413.txt
- sha256:5f462f724ec24b79ffbd5965ad0d6c3206ac3f5fb620e6a4896fafd38dcd4c8f  docs/artifacts/feat-795-s1b-nginx/nginx-dump.txt
- sha256:64c0ddf177d4239a7ed8c152aaa554c706ca8e83c59a20c1cd3f7e073c7d4f78  docs/artifacts/feat-795-s1b-nginx/nginx-test.txt
- sha256:ba8133bc92632118010c98d43a7a68030fdd540c427622b27391a5c51192fe3c  docs/artifacts/feat-795-s1b-nginx/red.txt
- sha256:e08524ac22e790090e431336f88a95d60262173d65cf8fd55938e0b97f30a478  docs/artifacts/feat-795-s1b-nginx/scan.txt
- sha256:edf3810f31761ba80405719f226c406e7483089f92e1cdf697d1f0ad9391f10d  docs/reference/claude-abschrift-vertrag.md

## Prüfbasis

- base: 63de3cc2b65b7f7ca8416f2ce45196ab897ee9c6
- blob:3dadb5b376896b70562c351a9119bb81d2890860  CLAUDE.md
- blob:9975dfb39b6fca511b49f2093ea5e223045cab28  docs/artifacts/feat-795-s1b-nginx/check-app.sh
- blob:984b721697a9d4bbd7064d6095c70995fcf5df1b  docs/artifacts/feat-795-s1b-nginx/green.txt
- blob:8fe3b1a7cebc5a65ac2704dda8c4d569f806fef9  docs/artifacts/feat-795-s1b-nginx/infra-pr.txt
- blob:cc5e1327f07fb0728874b451f20e980efc26aa31  docs/artifacts/feat-795-s1b-nginx/nginx-413.txt
- blob:e22c09d73cd0da1a5037a5353b02fd2721961150  docs/artifacts/feat-795-s1b-nginx/nginx-dump.txt
- blob:68502a5256ab73b40ee7d88530781fd96aef946c  docs/artifacts/feat-795-s1b-nginx/nginx-test.txt
- blob:f86cef4111b5174b5fbe9efa198b302eb13b8f64  docs/artifacts/feat-795-s1b-nginx/red.txt
- blob:fe005852d0bda57264c230c8df4cedb76ff2bf8e  docs/artifacts/feat-795-s1b-nginx/scan.txt
- blob:2d273b054d3343be8cf94dcf229dfd0a77b5a5f8  docs/reference/claude-abschrift-vertrag.md
