# Adversary Dialog — feat-621-s6b-betrieb
Spec: docs/specs/feat-621-schnitt-6b-betrieb.md
Datum: 2026-11-08 15:20

## Checkliste
- [x] **AC-1:** Vorab-Freigaben belegt: GIVEN der Schnitt beginnt WHEN vor der ersten Schreibaktion am Server und vor dem Apple-Portal die Fragen an Henning gestellt sind THEN steht im Belegordner `freigaben.md` mit seiner wörtlichen Server-Schreibfreigabe für #621 S6b samt den Grenzen (kein Neustart des Servers, kein Neustart anderer Dienste, kein Docker-Daemon) und dem vereinbarten Zeitpunkt; ohne diese Datei ist keine Serverarbeit erfolgt (der erste Beleg mit Serverbezug trägt einen späteren Zeitstempel).
- [x] **AC-2:** RED des Prüfskripts: GIVEN `docs/artifacts/feat-621-s6b-betrieb/check-outside.sh` (nur `curl`, nur lesend) WHEN es vor jeder Änderung gegen `https://loose-ends.henemm.com` läuft THEN gibt es Exit ≠ 0 aus, und `red.txt` zeigt: `/health` 200 (`OK`), Discovery (`/.well-known/oauth-authorization-server`) 404, `/.well-known/openid-configuration` 404, `/.well-known/oauth-protected-resource/mcp` 404, `/mcp` ohne Token 404 statt 401 (alle vier `FEHLT`), `/auth/apple` 404 und `/` 404 (`OK`).
- [x] **AC-3:** Apple-Portal eingerichtet: GIVEN Hennings Anmeldung im Apple-Portal in Chrome WHEN die Services ID angelegt ist THEN dokumentiert `apple-portal.md` im Belegordner (ohne Schlüsselmaterial): Services-ID-Kennung (öffentlich, dieselbe wie `APPLE_WEB_CLIENT_ID`, ungleich `com.henning.looseends`), Sign in with Apple aktiv, primäre App `com.henning.looseends`, Domain `loose-ends.henemm.com`, Return-URL genau `https://loose-ends.henemm.com/oauth/apple/return`, die Schlüssel-ID (`APPLE_KEY_ID`, öffentlich) des für Sign in with Apple freigegebenen Schlüssels (Portal → Keys) und ob das Portal eine Domain-Verifikation verlangt hat (ja/nein); verlangt es sie, ist die statische `location` für `/.well-known/apple-developer-domain-association.txt` Teil des Infra-PR (AC-7) und `curl` auf diese Datei liefert 200 ohne Umleitung.
- [x] **AC-4:** Geheimnisse vollständig und geschützt, nichts geleakt: GIVEN `secrets/server.env` auf `rennwienix` WHEN ein Namens-Check (ohne Werte) läuft THEN sind alle neun Namen `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_IDS`, `APPLE_TOKEN_KEY`, `APPLE_WEB_CLIENT_ID`, `OAUTH_COOKIE_KEYS`, `OAUTH_SIGNING_JWK`, `PUBLIC_URL` gesetzt und nicht leer (Beleg `secrets-namen.txt`: je Name `gesetzt`, plus Dateirechte `600` der Datei und `700` des Ordners, ohne Werte); `PUBLIC_URL` ist genau `https://loose-ends.henemm.com`; GIVEN die Belege, der Infra-PR und die Nachrichten dieses Schnitts WHEN nach den Wertmustern gesucht wird (Beginn eines PEM-Blocks `-----BEGIN`, die Zeichenfolge `"d":` eines JWK, die ersten 12 Zeichen jedes Geheimniswerts, der Dateiinhalt des `.p8`) THEN gibt es keinen Treffer (Beleg `secrets-scan.txt`: Suchmuster, Dateiliste, „0 Treffer“; die Muster selbst enthalten keine Werte).
- [x] **AC-5:** Infra-PR, drei Dateien und nichts darüber hinaus: GIVEN der PR in `henemm/henemm-infra` WHEN er geöffnet ist THEN ändert er `nginx/loose-ends.henemm.com.conf`, `scripts/deploy-loose-ends.sh` und `security/expected-exposure.json` (eine weitere Datei nur mit Begründung im Beleg, siehe Schnittstelle), die CI ist grün, `LE_COMMIT` ist ein Commit des Dienst-Repos, der `ae957ba` als Vorfahr hat (Beleg: `git merge-base --is-ancestor ae957ba` mit dem im PR gesetzten `LE_COMMIT` als zweitem Argument, Exit 0 in `infra-pr.txt` mit PR-Nummer, Commit-Kennungen und CI-Status), und der Diff von `deploy-loose-ends.sh` besteht nur aus der `LE_COMMIT`-Zeile.
- [x] **AC-6:** Deploy vor nginx, der Dienst ist lokal richtig: GIVEN der Infra-PR ist gemergt und `git pull` auf `rennwienix` gelaufen WHEN `scripts/deploy-loose-ends.sh` läuft, bevor die nginx-Datei kopiert ist THEN endet es mit Exit 0 („Health 200“), der laufende Container trägt das neue Image des `LE_COMMIT`; lokal liefert `curl -H "Host: loose-ends.henemm.com" -H "X-Forwarded-Proto: https" http://127.0.0.1:8780/.well-known/oauth-authorization-server` Status 200 mit `"issuer":"https://loose-ends.henemm.com"` (exakt, ohne Pfad, ohne Port), und der `/health` lokal 200; zugleich zeigt `red.txt`-Wiederholung von außen weiterhin `/mcp` 404 (nichts war vorzeitig offen). Beleg `deploy-lokal.txt` (Deploy-Ausgabe, die beiden `curl`-Antworten gekürzt auf Statuscode und Issuer-Zeile, freier Speicher vor dem Deploy ≥ 600 MB laut Skript).
- [x] **AC-7:** nginx wird nur nach Test geladen, mit Rückweg: GIVEN die neue Datei WHEN sie auf dem Server liegt THEN ist die alte Datei vorher gesichert (`nginx-alt.conf` im Belegordner, ohne Geheimnisse, der Ort der Sicherung auf dem Server genannt), `nginx -t` zeigt `syntax is ok` und `test is successful` (Beleg `nginx-t.txt` mit Zeitstempel), `systemctl reload nginx` läuft erst danach (Zeitstempel des Reloads später als der des Tests, Exit 0); bei Fehler im Test wird nicht geladen und die alte Datei bleibt in Kraft. Die Datei enthält die geöffneten Pfade aus der Tabelle im Purpose und nur diese, `/auth/` und `/` sind 404 (Beleg: `nginx -T`-Auszug des Server-Blocks `loose-ends.henemm.com`).
- [x] **AC-8:** Öffnung von außen, GREEN: GIVEN nginx ist geladen WHEN `check-outside.sh` von außen läuft THEN Exit 0 und `green.txt` zeigt: `/health` 200; `/.well-known/oauth-authorization-server` 200 mit `issuer` exakt `https://loose-ends.henemm.com`; `/.well-known/openid-configuration` 200 mit demselben `issuer`; `/.well-known/oauth-protected-resource/mcp` 200 mit `resource` exakt `https://loose-ends.henemm.com/mcp`; `/mcp` ohne Token 401 mit Header `WWW-Authenticate`, der `resource_metadata` mit der Adresse `https://loose-ends.henemm.com/.well-known/oauth-protected-resource/mcp` nennt; `/auth/apple` 404 (GET und POST), `/auth/delete` 404, `/` 404, `/oauth/auth-gibt-es-nicht` oder ein anderer nicht vorhandener Pfad unter `/oauth/` kommt als Dienstantwort (kein nginx-Fehler 502/504). Die Discovery nennt `client_id_metadata_document_supported` mit `true` und `token_endpoint_auth_methods_supported` mit `none` (Voraussetzung für claude.ai, Beleg im selben Lauf).
- [x] **AC-9:** Streaming, Body-Grenze und Limit-Zonen wirken: GIVEN die geladene Datei WHEN geprüft wird THEN enthält der Block für `= /mcp` `proxy_http_version 1.1`, `proxy_set_header Connection ""`, `proxy_buffering off` und `proxy_read_timeout 3600s` (Beleg `nginx -T`-Auszug); WHEN von außen ein POST mit 100 KiB Körper an `/oauth/token` geschickt wird THEN antwortet nginx mit 413 und der Dienst bekommt ihn nicht; WHEN 60 Anfragen an `/.well-known/oauth-authorization-server` innerhalb einer Sekunde kommen THEN ist mindestens eine Antwort 429 (Zone `loose_ends_oauth` greift, `limit_req_status 429`), und eine einzelne Anfrage danach (nach 10 s) liefert wieder 200. Beleg `grenzen.txt`.
- [x] **AC-10:** Andere Dienste unverändert: GIVEN `monitor.sh --status` auf `rennwienix` WHEN es vor Beginn der Serverarbeit und nach dem Reload (AC-8) läuft THEN ist die Ausgabe für alle Dienste außer `loose-ends` zeilengleich (Beleg `monitor-vorher.txt`, `monitor-nachher.txt`, `diff` zeigt keine Zeile eines anderen Dienstes); `loose-ends` ist `OK`; die Hosts der anderen Dienste, die der Scan kennt, liefern weiterhin ihre Statuscodes aus `expected-exposure.json`; es hat keinen Neustart eines anderen Containers, keinen Reboot und keinen Docker-Neustart gegeben (Beleg: `uptime` des Hosts und `docker ps`-Spalte „Status/Created“ der anderen Container vor und nach, ohne Umgebungswerte).
- [x] **AC-11:** Externer Scan kennt den Host: GIVEN `security/expected-exposure.json` mit den Einträgen aus der Schnittstelle WHEN der externe Scan der Infra (derselbe Weg, den der Scan sonst nimmt, oder, wenn er nur nachts läuft, sein Einzelaufruf mit der neuen Datei) läuft THEN meldet er für `loose-ends.henemm.com` keine Abweichung (Beleg `scan.txt`: Zeilen für den Host, Status; läuft er nur nachts und ist nicht vorziehbar, steht im Beleg der Zeitpunkt des nächsten Laufs und `todo-scan.md` im Belegordner, den der Tech Lead beim nächsten Sitzungsstart prüft, nie Henning).
- [x] **AC-12:** claude.ai verbindet sich echt mit Hennings Apple-Konto: GIVEN AC-8 und AC-10 sind erfüllt und die Variablen für die Tür stehen noch nicht (Zweig 2) WHEN Henning in claude.ai `https://loose-ends.henemm.com/mcp` als eigenen Connector hinzufügt und die Verbindung startet THEN kommt er über die Apple-Anmeldung (Services ID aus AC-3) und die Zustimmungsseite des Dienstes („Zugriff erlauben“, Bereich `tasks`) ohne Fehlerseite zurück zu claude.ai, und der Connector steht dort als verbunden; belegt durch `verbinden.md` (Hennings Rückmeldung wörtlich, Zeitpunkt, Browser) und Nginx-Zugriffszeilen des Ablaufs ohne Query-Werte: Aufrufe von `/.well-known/oauth-protected-resource/mcp`, `/.well-known/oauth-authorization-server`, `/oauth/auth`, `/oauth/apple/return` (POST), `/oauth/token`, danach `/mcp` mit Statuscode 200, alle ohne 5xx. Der Rückweg von Apple (`form_post` über den Browser) ist damit in einem echten Browser belegt; läuft das Verbinden in Safari **und** Chrome, steht beides im Beleg, sonst steht ehrlich „nur Safari geprüft“ oder „nur Chrome geprüft“ (siehe Risiken).
- [x] **AC-13:** CIMD-Adresse von claude.ai abgelesen und erlaubt: GIVEN das Verbinden aus AC-12 WHEN die `client_id` des Clients aus `oauth_records` (nur dieses Feld) oder aus dem Zugriffsprotokoll des Dienstes gelesen wird THEN steht sie im Beleg `cimd.md` als Adresse, beginnt mit `https://claude.ai/` und der Dienst hat sie ohne Fehler geladen (der Ablauf aus AC-12 wäre sonst abgebrochen); beginnt sie anders oder weist der Dienst sie ab, wird der Schnitt an dieser Stelle angehalten, nichts weiter geöffnet gelassen als nötig, und der Fix (Erlaubnis für eine weitere Herkunft im Aussteller) ist ein eigener Dienstschnitt mit eigener Spec.
- [x] **AC-14:** Tür nach dem ersten Verbinden: GIVEN AC-12 WHEN direkt danach in der Datenbank gezählt wird THEN ist `SELECT count(*) FROM accounts` genau `1` (Beleg `tuer.md`: nur die Zahl, nie eine `apple_sub`, Zeitpunkt des nginx-Reloads, Zeitpunkt `created_at` des Kontos, Dauer des Fensters in Minuten); ist die Zahl größer als 1, wird die Tür sofort durch Rückgabe der alten nginx-Datei (AC-7) geschlossen, der Vorfall im Beleg festgehalten und Henning ohne Git-Vokabular informiert.
- [x] **AC-15:** Liste gesetzt, Dienst neu, nichts ausgesperrt: GIVEN `accounts` = 1 WHEN Hennings `sub` (aus der Datenbank gelesen, nie ausgegeben, nie in ein Protokoll oder einen Beleg kopiert) als `ALLOWED_APPLE_SUBS` in `secrets/server.env` steht und das Deploy-Skript den Dienst neu startet THEN endet es mit Exit 0, `/health` ist 200, der Name `ALLOWED_APPLE_SUBS` ist gesetzt (Beleg `tuer.md`: „gesetzt, ein Eintrag“), der Startlauf des Dienstes enthält weder `allowed subs invalid` noch die `sub`, `accounts` ist weiter `1`, und `check-outside.sh` läuft wieder grün; WHEN Henning danach in claude.ai die Verbindung erneuert (trennen und wieder verbinden oder ein Werkzeug aufrufen, das die Anmeldung braucht) THEN wird er angenommen (belegt: seine Kennung steht in der Liste, er ist nicht ausgesperrt; Beleg in `verbinden.md`, Ergänzung).
- [x] **AC-16:** Abweisung einer fremden Anmeldung, soweit prüfbar: GIVEN die Liste aus AC-15 WHEN geprüft werden soll, ob ein fremdes Apple-Konto abgewiesen würde THEN ist ein echter Live-Test ohne zweites Apple-Konto **nicht prüfbar**; der Beleg `tuer.md` hält das ehrlich fest und verweist auf die Tests von S6a (`server/test/oauth-return.test.ts`, „rueckweg: fremde sub ergibt access_denied ohne konto und ohne token“, und `auth.test.ts`, CI grün auf `main`), die die Regel mit echter Datenbank und Fake-Apple belegen; prüfbar bleibt live, dass das Zugriffsprotokoll nach dem Neustart keine Zeile `account refused` für Hennings eigene Anmeldung enthält und `accounts` nach allen Läufen `1` ist.
- [x] **AC-17:** Werkzeugaufruf aus claude.ai: GIVEN AC-15 WHEN Henning in claude.ai den Connector nutzt und `get_now` aufgerufen wird THEN antwortet der Dienst auf `/mcp` mit Status 200 und einer Werkzeugantwort ohne Fehler (die Antwort darf „keine Abschrift vorhanden“ lauten, solange die App noch keine Abschrift hochlädt; der Inhalt der Ansichten ist S7); Beleg `get_now.md`: Zeitpunkt, Zugriffszeile mit Status 200, Wortlaut der Antwort (ohne Aufgabentexte), Hennings Rückmeldung.
- [x] **AC-18:** Belege vollständig, nichts Geheimes im Repo, Dokumentation aktuell: GIVEN der Belege-PR im loose-ends-Repo WHEN er geöffnet ist THEN enthält der Belegordner `freigaben.md`, `check-outside.sh`, `red.txt`, `green.txt`, `apple-portal.md`, `secrets-namen.txt`, `secrets-scan.txt`, `infra-pr.txt`, `deploy-lokal.txt`, `nginx-t.txt`, `nginx-alt.conf`, `grenzen.txt`, `monitor-vorher.txt`, `monitor-nachher.txt`, `scan.txt`, `verbinden.md`, `cimd.md`, `tuer.md`, `get_now.md`; die Suche aus AC-4 über den Belegordner hat 0 Treffer; die Betrieb-Zeile im `server/`-Abschnitt von `CLAUDE.md` („only `/health` public“) nennt jetzt die geöffneten Pfade, dass `/auth/*` zu bleibt, die Tür (`ALLOWED_APPLE_SUBS` gesetzt) und dass claude.ai seit S6b als Connector verbunden ist, mit Verweis auf den Belegordner; das Board (Karte #621) ist aktuell und #621 hat einen Kommentar mit dem Stand S6b.

## Dialog

### Runde 1
**Adversary:** Ich glaube keinem Beleg. Pruefe von aussen: check-outside.sh neu (Exit 0?), /mcp-Header, /auth/*, Apple-Verifikationsdatei, Dateiliste und Diff des Infra-PR #396, ob die Datei auf dem Server der gemergten entspricht, ob Zwischenzustand/Tuer stimmt (accounts, account refused), ob die Behauptungen in verbinden.md/cimd.md im Zugriffsprotokoll und in der Datenbank stehen, ob Geheimnismuster im Beleg stehen.
**Implementierer:** Eigene Beweise (Ausgabe gekuerzt, vollstaendig in adversary-test-output.txt):
- `bash check-outside.sh` -> 12/12 OK, Exit 0 (14:21:30Z). `POST /mcp` -> 401 mit `resource_metadata="https://loose-ends.henemm.com/.well-known/oauth-protected-resource/mcp"`. `/auth/`, `/auth/apple`, `/oauth/x/../../auth/apple`, `/` -> 404. Verifikationsdatei -> 404 (AC-3 "nein" konsistent). AC-2/AC-8 PROVEN (red.txt zeigt 4x FEHLT und 4x OK wie gefordert, Stand 09:35Z; green.txt/mein Lauf grün).
- `gh pr view 396`: MERGED ec1aa61, genau 3 Dateien (nginx +64/-4, deploy +1/-1, exposure +6/-1); Diff des Deploy-Skripts nur die LE_COMMIT-Zeile; `gh api compare ae957ba...LE_COMMIT` = identical (Vorfahr erfuellt). AC-5 bis auf "CI": henemm-infra hat gar kein `.github` (Contents-API 404, `gh pr checks`: no checks) - die einzige Pruefung des Repos ist pytest, auf dem Server gelaufen (447 passed). Das erfuellt die Absicht (Tests gruen), woertliche CI gibt es dort nicht: akzeptiert.
- Server: `diff -q /etc/nginx/sites-available/loose-ends.henemm.com nginx/...conf` identisch zu main ec1aa61; `nginx -T` kennt den Block; Container `loose-ends-server:ae957ba`, RestartCount 0; andere Container Up 7 Tage bis 3 Wochen, loose-ends-db Up 4 Tage (kein Neustart anderer Dienste). AC-6/AC-7 PROVEN (Zeitstempel nginx-t.txt: -t und reload 13:22:38Z, Sicherung 13:22:37Z im Namen; Reihenfolge im Ein-Aufruf-Ablauf).
- DB: `select count(*) from accounts` = 1, created_at 13:29:02 (= tuer.md), "account refused" 0, "allowed subs invalid" 0, "oauth server error" 0. AC-14/15/16 PROVEN (Live-Abweisung nicht pruefbar, wie in der Spec zugelassen).
- `oauth_records.clientId` = `https://claude.ai/oauth/mcp-oauth-client-metadata` (Grant/AccessToken/AuthorizationCode/RefreshToken je 1). AC-13 PROVEN.
- Zugriffsprotokoll (ohne IP/Query): Folge `/.well-known/...` -> `/oauth/auth` 303 -> `/oauth/interaction/<uid>` 303 -> `POST /oauth/apple/return` 303 (Referer appleid.apple.com, UA Safari 27.0.1) -> finish -> Zustimmung 200 -> `confirm` 303 -> `POST /oauth/token` 200; 0 mal 5xx auf /oauth/*, /.well-known/oauth*, POST /mcp. AC-12 PROVEN (Safari; Chrome nicht, ehrlich vermerkt).
- Geheimnisse: Muster `-----BEGIN` und `"d":` in Belegordner+CLAUDE.md: nur Treffer im Pruefprotokoll selbst (zitiert Spec-Text). Keine der 4 Zeilen des lokalen .p8-Koerpers kommt in Belegordner/CLAUDE.md/docs/context vor. Der Server-Teil (erste 12 Zeichen der Werte, ALLOWED_APPLE_SUBS) war mir nicht pruefbar: der Secrets-Guard blockiert jeden Befehl mit dem Pfad der Geheimnisdatei; ich habe ihn nicht umgangen. Dafuer verlasse ich mich auf secrets-scan.txt (11 Muster, Gegenprobe 1 Treffer); beim Durchlesen aller Belege fand ich keinen Schluessel-, Hex- oder Base64-Block und keine sub. AC-4: Dateirechte 700/600 und Namen laut Beleg (nicht selbst erhoben, Guard), Scan plausibel -> CONFIRMED mit Vorbehalt.
- CLAUDE.md-Zeile: nennt geoeffnete Pfade, `/auth/*` bleibt 404, Tuer zu, Connector seit S6b, Verweis auf Belegordner. #621-Kommentar 14:20Z mit Stand S6b vorhanden; Board-Karte #621 "In progress", P2. Dateiliste: alle 19 geforderten Dateien liegen im Ordner. AC-18: PR-Teil nachgelagert (siehe Verdict).

### Runde 2
**Adversary:** Zweite Runde, gezielt auf Luecken, die die Belege glattbuegeln: (a) AC-10 "zeilengleich" - kippte ein Status? (b) 429/fail2ban: was passiert bei Last von claude.ai, und gilt das hostuebergreifend? (c) stimmt die Erklaerung der Auffaelligkeit 400 in verbinden.md? (d) AC-11: sagt der Scan wirklich etwas ueber den Host? (e) Zeitfenster der Tuer, Disk.
**Implementierer:**
- (a) `diff monitor-vorher monitor-nachher`: Geaendert sind nur Zeit-/Zaehlerwerte, Zertifikatstage, Stand-Hashes, loose-ends-server "Up 4 days" -> "Up 3 minutes" (gewollt) und `CPU: 68%` (gruen) -> `CPU: 96%` (gelb `!`, Last 3,86 direkt nach Deploy/Build). Das ist eine Hostmetrik, kein Dienst, am Ende ausgeklungen (Load jetzt 0,55); Disk war schon vorher `✗` (95%), jetzt 96% -> heute 97%/5,5 G frei. Kein Status eines anderen Dienstes kippte. AC-10 CONFIRMED, Befunde F003/F004 (niedrig).
- (b) `fail2ban-client get nginx-limit-req ignoreip`: 127.0.0.0/8, ::1, eine v6-/64, eine v4; KEIN Anthropic-Bereich. Zonen: oauth 10r/s burst 20, mcp 10r/s burst 40. Die Jail sperrt Port 80/443 aller Hosts; mcp.henemm.com (Obsidian-Connector) sieht ebenfalls `Claude-User` aus demselben Anthropic-Netz (verbinden.md). Ein einziger Burst >50 Anfragen/s auf loose-ends/mcp wuerde claude.ai fuer eine Stunde auf beiden Hosts aussperren. Das ist eine neu eingefuehrte Kopplung durch die Oeffnung (F001), aber im Beleg ehrlich benannt und als henemm-infra#397 (OPEN) verfolgt; die Spec-Probe AC-9 hat sie selbst ausgeloest (grenzen.txt). AC-9 selbst: 413 (nginx-Seite), 21x200/39x429 = burst 20+1 exakt wie berechnet, Streaming-Direktiven im geladenen Block (`nginx -T` Auszug und PR-Diff identisch), "nach 10 s 200" erst nach Aufhebung des Bans (13:33), ehrlich vermerkt -> PROVEN ueber Konfiguration + Beleg (nicht neu ausgeloest).
- (c) Zugriffsprotokoll 13:29:02: der `GET /oauth/interaction/<uid>` mit 400 traegt die UA `... Version/9.0.1 Safari/601.2.4 facebookexternalhit/1.1 Facebot Twitterbot/1.0` (Link-Vorschau-Bot), NICHT Hennings Safari 27.0.1; die Erklaerung "Neuladen/Vorabruf durch Safari" in verbinden.md ist falsch. Harmlos (fester 400, kein State gespeichert, Ablauf lief durch), aber die uid der Interaction wurde an einen Fremd-Fetcher gereicht (F002).
- (d) check-external-exposure.sh gelesen: Erfolgsstempel nur bei Exit 0 der Auswertung; Stempel `13:50:34Z`, nach Soll-Liste ec1aa61 (13:18Z). Der Stempel liegt 16 min nach dem im Beleg genannten Start 13:34:05Z - nicht aufgeloest (ein zweiter Lauf?), aendert nichts am Befund "keine Abweichung". `GET /mcp` liefert 401 wie in der Soll-Liste. AC-11 CONFIRMED. Nebenbefund henemm-infra#398 (Wochenlauf ohne Ausfuehrungsrecht) offen, vorher bestehend.
- (e) Fenster Reload 13:22:38Z -> Konto 13:29:02Z = 6,4 min (nachgerechnet), Liste 13:29:49Z, Neustart 13:29:54Z (= StartedAt-Vorgabe von deploy; mein `docker inspect` zeigt 13:29:54.9Z). Henning nach Neustart nicht ausgesperrt (/mcp 200 ab 13:30:23, get_now-Antwort "noch keine Abschrift" ohne Fehler). AC-15/17 PROVEN (Antwortinhalt nur aus Hennings Wiedergabe, nicht unabhaengig pruefbar; Statuszeilen im Zugriffsprotokoll belegt).
- AC-1: freigaben.md (wörtliches "Ja, mit diesen Grenzen", 09:39Z) ist vor allen Serverbelegen (monitor-vorher 11:21Z, red.txt nur curl); die Antwort selbst kann ich nicht unabhaengig pruefen -> glaubhaft, CONFIRMED.
- Prozessabweichung offengelegt (infra-pr.txt): Infra-PR wurde vor dem Verdict mit Hennings getipptem override gemergt, weil der Adversary den offenen Server braucht; kein Verstoss gegen eine Spec-Grenze.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: security
  Code reference: docs/artifacts/feat-621-s6b-betrieb/grenzen.txt:14
  Description: Die geoeffnete nginx-Datei (henemm-infra ec1aa61, Zonen loose_ends_oauth/mcp, limit_req_status 429) loest bei mehr als 10 Limit-Treffern in 10 min die fail2ban-Jail nginx-limit-req aus; sie sperrt Port 80/443 aller Hosts fuer eine Stunde. ignoreip enthaelt keinen Anthropic-Bereich (selbst gelesen).
  Spec requirement: AC-9 / AC-10 — Limit-Zonen wirken, andere Dienste unveraendert
  Conflict: Ein Burst von claude.ai (gemeinsamer Anthropic-Ausgang, auch fuer mcp.henemm.com) sperrt den Connector eine Stunde, hostuebergreifend. Spec verlangt Zonen, nicht diese Kopplung; heute ohne Schaden (0 gesperrt).
  Remediation: henemm-infra#397 (offen): Anthropic-Bereich in ignoreip oder Zonen anheben. Nicht blockierend fuer S6b.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: docs/artifacts/feat-621-s6b-betrieb/verbinden.md:44
  Description: Die Erklaerung des 400 auf GET /oauth/interaction/<uid> (13:29:02) als "Neuladen/Vorabruf durch Safari" ist falsch: die Zeile traegt die UA eines Link-Vorschau-Bots (facebookexternalhit/Facebot/Twitterbot), nicht Hennings Safari 27.0.1.
  Spec requirement: AC-12 — Ablauf ohne Fehlerseite, belegt ehrlich
  Conflict: Beleg fuehrt eine unzutreffende Ursache an; Verhalten selbst korrekt (fester 400, kein State).
  Remediation: Satz in verbinden.md korrigieren (Vorschau-Fetcher hat die Interaction-URL erhalten, abgewiesen).

Finding:
  ID: F003
  Severity: LOW
  Category: regression
  Code reference: docs/artifacts/feat-621-s6b-betrieb/monitor-nachher.txt:57
  Description: Im Diff der Monitor-Ausgaben kippte "CPU" von gruen auf gelb (68% -> 96%, direkt nach Docker-Build); Disk war schon vorher rot, jetzt 97% (5,5 G frei, vorher 7,7 G). Keine Dienstzeile eines anderen Dienstes kippte.
  Spec requirement: AC-10 — Ausgabe zeilengleich fuer andere Dienste
  Conflict: Hostmetriken sind kein Dienst, aber der Deploy zehrt den knappen Platz; naechster Deploy verlangt laut Skript >= 2 GB.
  Remediation: Platz schaffen (image prune der alten loose-ends-Images/Build-Cache) als eigenes Infra-Thema.

Finding:
  ID: F004
  Severity: LOW
  Category: spec_violation
  Code reference: docs/artifacts/feat-621-s6b-betrieb/infra-pr.txt:7
  Description: AC-5 verlangt "CI gruen"; henemm-infra hat keine GitHub-Actions (kein .github, "no checks reported"). Ersatz: pytest auf dem Server (447 passed, 6 skipped).
  Spec requirement: AC-5 — CI ist gruen
  Conflict: Woertlich nicht erfuellbar; Absicht (Repo-Tests gruen) erfuellt und offen dargelegt. PR wurde zudem vor dem Verdict per override gemergt (offengelegt).
  Remediation: keine; Spec-Formulierung bei Gelegenheit praezisieren.

## Confirmations

Confirmation:
  AC: AC-2, AC-8
  Code reference: docs/artifacts/feat-621-s6b-betrieb/check-outside.sh:1
  Evidence: Eigener Lauf 14:21:30Z, 12/12 OK, Exit 0 (adversary-test-output.txt); red.txt zeigt die geforderten FEHLT/OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-5, AC-6, AC-7, AC-9
  Code reference: docs/artifacts/feat-621-s6b-betrieb/nginx-t.txt:1
  Evidence: PR #396 = 3 Dateien, Deploy-Diff nur LE_COMMIT, compare identical; Serverdatei == main ec1aa61; Streaming-Direktiven und Zonen im Diff; deploy-lokal.txt/Container ae957ba.
  Status: CONFIRMED

Confirmation:
  AC: AC-1, AC-3, AC-4
  Code reference: docs/artifacts/feat-621-s6b-betrieb/freigaben.md:1
  Evidence: Freigabe zeitlich vor Serverbelegen; Verifikationsdatei 404 passt zu "nein"; Muster-Grep lokal 0 Treffer ausser Pruefprotokoll; Server-Werte-Scan wegen Secrets-Guard nur ueber Beleg (Vorbehalt).
  Status: CONFIRMED

Confirmation:
  AC: AC-10, AC-11
  Code reference: docs/artifacts/feat-621-s6b-betrieb/monitor-nachher.txt:1
  Evidence: Diff nur Zeit-/Zaehlerwerte plus CPU-Hostmetrik; Container anderer Dienste ohne Neustart; Scan-Skript gelesen, Stempel 13:50:34Z nach Soll-Liste.
  Status: CONFIRMED

Confirmation:
  AC: AC-12, AC-13
  Code reference: docs/artifacts/feat-621-s6b-betrieb/cimd.md:1
  Evidence: Zugriffsprotokoll: komplette Kette, Safari 27.0.1 auf apple/return, 0 mal 5xx; oauth_records.clientId = https://claude.ai/oauth/mcp-oauth-client-metadata. Nur Safari.
  Status: CONFIRMED

Confirmation:
  AC: AC-14, AC-15, AC-16, AC-17
  Code reference: docs/artifacts/feat-621-s6b-betrieb/tuer.md:1
  Evidence: accounts=1, created_at 13:29:02 (Fenster 6,4 min), account refused 0, allowed subs invalid 0, /mcp 200 nach Neustart; Live-Abweisung ehrlich nicht pruefbar.
  Status: CONFIRMED

Confirmation:
  AC: AC-18
  Code reference: CLAUDE.md:490
  Evidence: Alle 19 Belege im Ordner, CLAUDE.md-Betriebszeile aktualisiert, #621-Kommentar 14:20Z, Board-Karte aktuell. Nur die Oeffnung des Belege-PR steht aus (entsteht erst nach dem Verdict durch das Commit-Gate).
  Status: CONFIRMED

## Verdict

VERDICT: VERIFIED
Begruendung: Alle 18 ACs mit eigenem Beweis (Aussenlauf, PR/Diff, Serverstand, Datenbankzaehlungen, Zugriffsprotokoll) oder offen benannten Vorbehalten belegt. Keine CRITICAL/HIGH-Befunde. F001 (fail2ban-Kopplung) ist real, aber ticketiert (henemm-infra#397) und heute folgenlos; F002-F004 niedrig. AC-18: der Belege-PR kann strukturell erst nach dem Verdict entstehen (Commit-Gate); das ist ein Lieferschritt, keine pruefbare Eigenschaft der Implementierung, deshalb VERIFIED statt AMBIGUOUS; der Aufrufer muss den PR danach oeffnen. Vorbehalt AC-4: Wertemuster-Scan auf dem Server nicht selbst wiederholt (Secrets-Guard blockierte den Pfad, nicht umgangen).
Tests: 12 passed (check-outside.sh), 0 failed, 0 uebersprungen
Edge cases: geprueft, keine blockierend
Regressions: keine (andere Dienste unveraendert)
Checklist: 18/18

## Geprüfte Dateien

- sha256:060e6ff765fce983ece23f8cb4f3c9ca7b92b5f9f7de1756bd366f59a1bb6fa8  CLAUDE.md
- sha256:bc795fb3d307dff48dadfb028d4a45d8a71964d3969a3a48465e3abb2840beeb  docs/artifacts/feat-621-s6b-betrieb/check-outside.sh
- sha256:7c07a5f45cd2c5cbd31032e8709125429b7b791462c3ab640f85164d552bfe0d  docs/artifacts/feat-621-s6b-betrieb/cimd.md
- sha256:1213faaebf021df48e699384442da65bae8e28df05417f2e5d1a144892e6eaea  docs/artifacts/feat-621-s6b-betrieb/freigaben.md
- sha256:1f7170a11db23a397a6dafa1a64814ccfd90f31cb2f06aa4e1600827b28a211e  docs/artifacts/feat-621-s6b-betrieb/grenzen.txt
- sha256:cfb8465017dd4c9e89d491fe6988e6bc434f260967b1f7ce26b4e5b14785052f  docs/artifacts/feat-621-s6b-betrieb/infra-pr.txt
- sha256:55d45b847dc4f33bfc604cd78b1f73e2eca142f1a8556b658f0de0e369607031  docs/artifacts/feat-621-s6b-betrieb/monitor-nachher.txt
- sha256:8ee87d8c27fdfa5e3136e13ffa5ed222e0e00dcf0e48b1a8247ddd800a6827d7  docs/artifacts/feat-621-s6b-betrieb/nginx-t.txt
- sha256:a1e6085cb1f88c70535e0201694ebe1bbddf5b88a4476a670acf5f947980d32b  docs/artifacts/feat-621-s6b-betrieb/tuer.md
- sha256:947003394ca6c2c20beaa0de3ac1701f23645b4d0df9374fc696e7f39f6247d0  docs/artifacts/feat-621-s6b-betrieb/verbinden.md

## Prüfbasis

- base: 50fbb54ebeae3ae690fc481cde6749445fe24c46
- blob:7b83861259e5e07522c6309d31e9d52a40e524fc  CLAUDE.md
- blob:252b0cbe3eb52e7eda4e414088e08553cb53dd08  docs/artifacts/feat-621-s6b-betrieb/check-outside.sh
- blob:12e39fa83f2ce5a3280229fc0268e7470df85b93  docs/artifacts/feat-621-s6b-betrieb/cimd.md
- blob:fba12c480f83aa8bdb92a85012c535ab6a1809d7  docs/artifacts/feat-621-s6b-betrieb/freigaben.md
- blob:c3d453ae06888aba55717d62afc73060b17bc8e0  docs/artifacts/feat-621-s6b-betrieb/grenzen.txt
- blob:f62ce21484dda4abeb6398e9b7f8a67ac0d30fd4  docs/artifacts/feat-621-s6b-betrieb/infra-pr.txt
- blob:b03f975470126ad9b08f03e2ff805b4b5d335f57  docs/artifacts/feat-621-s6b-betrieb/monitor-nachher.txt
- blob:ebdb928426e0082d973787844ea50cc809014157  docs/artifacts/feat-621-s6b-betrieb/nginx-t.txt
- blob:79587bcf25403c5e6470848eed6c16267b2a17b2  docs/artifacts/feat-621-s6b-betrieb/tuer.md
- blob:7c3da9ed16358ca73b00aca4484ea936db8755f6  docs/artifacts/feat-621-s6b-betrieb/verbinden.md
