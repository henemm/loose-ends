---
entity_id: feat-795-schnitt-1b-nginx
type: feature
created: 2026-11-11
updated: 2026-11-11
status: draft
workflow: feat-795-s1b-nginx
---

# Spec: Die App-Wege am Live-Dienst öffnen, Schnitt S1b (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S1b von sechs; das Issue bleibt offen (`Refs #795`, nie `Closes #795`): S2 (App-Client), S3 (`ClaudeSync`) und S5 (Weckruf) folgen.
Analyse: `docs/context/feat-795-s1b-nginx.md` (Abschnitt „Analysis“: Befund, Recherche, Lastprofil, Alternativen, Risiken; verbindlich).
Vorgänger: S1 (`docs/specs/feat-795-schnitt-1-dienst-wege.md`, PR #904, ausgerollt 2026-11-11 mit `LE_COMMIT` `63de3cc`); Betriebsvorbild `docs/specs/feat-615-schnitt-4d-auth-oeffnen.md`.
Es ist ein Betriebsschnitt: **kein Dienstcode in `server/src`**, keine App-Änderung, kein Deploy des Dienstes.

## Für den PO

Der Dienst im Netz hat seit gestern Abend die drei Türen, über die die App ihre Aufgabenliste ablegt, Aufträge von Claude abholt und Ergebnisse meldet. Von außen sind sie noch zu, weil der Vorschalt-Server nur freigegebene Adressen durchlässt. Dieser Schnitt öffnet genau diese drei Adressen und sonst nichts. Danach kann die App in den nächsten Schnitten gegen den echten Dienst arbeiten. Für dich ändert sich noch nichts Sichtbares.

Eine Sache habe ich anders entschieden als im Vorschnitt notiert: Die Anmeldung und der Abgleich bekommen getrennte Mengenbegrenzungen. Sonst hätte ein einziges „Aufwachen“ von iPhone, iPad und Mac mit zehn offenen Aufträgen genügt, um deine Heim-Adresse für eine Stunde bei allen meinen Seiten zu sperren. Die App bricht bei einer Ablehnung den Abholdurchgang ab und versucht es erst beim nächsten Anlass wieder; das halte ich im Vertrag fest. Du musst nichts entscheiden und nichts tun.

## Purpose

`https://loose-ends.henemm.com` reicht nach einer Erlaubnisliste nur `/health`, `/mcp`, die drei `/.well-known/`-Dokumente, `/oauth/` und seit #615 S4d `/auth/apple`, `/auth/logout`, `/auth/delete` an den Dienst. `/app/…` fällt in `location / { return 404; }`. Nachgestellt am 2026-11-11: von außen `POST /app/transcript` und `/app/orders/claim` → 404; direkt am Dienst (`127.0.0.1:8780`) `POST /app/orders/claim` ohne Sitzung → 401. Der Dienst ist bereit, nur nginx sperrt.

Dieser Schnitt öffnet in nginx genau drei Pfade, belegt sie von außen mit einem kleinen Skript und legt die Abbruchregel bei 429 für S2/S3 im Vertrag fest.

| Pfad | Zweck | nginx |
|---|---|---|
| `= /app/transcript` | Abschrift ablegen | neue Zone `loose_ends_app`, `client_max_body_size 256k` |
| `= /app/orders/claim` | einen offenen Auftrag abholen | wie oben |
| `= /app/orders/result` | Ergebnis melden | wie oben |
| `^~ /app/` (Rest) | nichts | `return 404` |

Alle drei reichen dieselben vier Header weiter wie `/health` (`Host $host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) an `127.0.0.1:8780`. Keine Streaming- oder Zeitgrenzen-Einstellungen: die Antworten sind kurz (S1, Alternative C verworfen), die Standardwerte von nginx reichen.

**Zone und Begründung.** `limit_req_zone $binary_remote_addr zone=loose_ends_app:10m rate=10r/s;`, je Pfad `limit_req zone=loose_ends_app burst=40 nodelay;`, `limit_req_status 429`. Lastprofil: je Gerät und Anlass 1× `transcript`, dann `claim` → `result` → `claim` … bis 204, also 2N + 2 Anfragen bei N Aufträgen, nacheinander. Ein Weckruf trifft iPhone, iPad und Mac gleichzeitig von einer Heim-Adresse: bei 10 Aufträgen und drei Geräten rund 2·10 + 3·2 = 26 Anfragen in 1 bis 3 s. Das liegt unter `burst 40` plus 10 r/s. Mit `loose_ends_auth` (5 r/s, burst 10) gäbe das rund 10 Ablehnungen, und fail2ban (`nginx-limit-req`: 10 Limit-Treffer in 10 Minuten, Sperre 1 h, alle Hosts auf `rennwienix`, `ignoreip` nur der Server selbst) sperrte Hennings Heim-Adresse. fail2ban zählt nur abgelehnte, nicht durchgelassene Anfragen (Quellen: https://nginx.org/r/limit_req, https://fail2ban-recipes.pages.dev/guides/fail2ban-nginx-limit-req/). Die Zone `loose_ends_auth` bleibt unverändert; Anmeldung und Abgleich zählen getrennt.

**Abbruchregel für die App (Vertrag, gilt für S2/S3).** Antwortet nginx 429, bricht das Gerät den Abholdurchgang ab und macht erst beim nächsten Anlass (Start, Vordergrund, Weckruf) weiter, ohne Wiederholung in einer Schleife. So entsteht höchstens eine Ablehnung je Gerät und Anlass; zehn Ablehnungen in zehn Minuten brauchen dann einen echten Fehler.

**Ablauf (feste Reihenfolge, Rückweg je Schritt):**

1. **Prüfskript und RED**: `check-app.sh` läuft vor der nginx-Änderung gegen den Live-Host und zeigt `FEHLT`.
2. **Infra-PR** (`henemm/henemm-infra`, Git über die gh-API wegen des Worktree-Guards): nginx-Datei und `expected-exposure.json`; `python3 -m pytest tests -q` im Wegwerfklon auf `rennwienix`, CI grün, Merge, dann auf `rennwienix` `git pull --ff-only`.
3. **Einsetzen**: alte Datei sichern, neue kopieren, `nginx -t`, erst bei Erfolg `systemctl reload nginx` (kein Neustart); bei Fehler im Test wird nicht geladen und die gesicherte Datei bleibt.
4. **GREEN von außen**: `check-app.sh` Exit 0; `check-external-exposure.sh` ohne Abweichung; `monitor.sh --status` für andere Dienste unverändert.
5. **Doku-PR** (dieses Repo): Prüfskript, Belege, `CLAUDE.md`, Vertrag.

Kein Dienst-Deploy: `LE_COMMIT` steht schon auf `63de3cc`. Ein echter Durchlauf mit gültiger Sitzung ist nicht Teil dieses Schnitts (die App ruft erst ab S2/S3); die 401 ohne Sitzung belegt die Öffnung.

**Regeln vor Modell:** Betrieb, Netz und Sicherheit ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 (Dienst für Claude, Weg B) und die Allowlist-Haltung der nginx-Datei (#621 S6b) um, ohne sie zu ändern; kein neues Verfahren, keine neue Abhängigkeit, keine Migration. Gekippt wird nur die Notiz in der S1-Spec („S1b nginx: Zone wie `loose_ends_auth`, 256k“), keine ADR.

- **Rationale:** Exakte Pfade statt eines Präfixes halten die Allowlist-Haltung ein. Die eigene Zone folgt aus dem Lastprofil (Rechnung oben); die Abbruchregel in der App macht aus „viele Ablehnungen“ höchstens eine je Anlass. Die Grenze 256k liegt in nginx und im Dienst gleich, nginx antwortet bei Überschreitung selbst 413 (vor der Anmeldung, deshalb ohne Sitzung belegbar).

## Source

- **File:** `henemm-infra: nginx/loose-ends.henemm.com.conf`
- **Identifier:** nginx-Blöcke `location = /app/transcript`, `location = /app/orders/claim`, `location = /app/orders/result`, `location ^~ /app/` und Zone `limit_req_zone … zone=loose_ends_app`; Verhalten des Dienstes dahinter: `appRoutes` in `server/src/app-routes.ts` (unverändert)

**Dateien (Infra-Repo `henemm/henemm-infra`):** `nginx/loose-ends.henemm.com.conf`, `security/expected-exposure.json`.
**Dateien (loose-ends):** `docs/artifacts/feat-795-s1b-nginx/` (neu: `check-app.sh` und Belege), `CLAUDE.md` (Abschnitt `server/`), `docs/reference/claude-abschrift-vertrag.md` (Abschnitt „Wege der App“).
**Kein Dienstcode, keine App:** `server/src`, `server/test`, Migrationen, `project.yml`, `LooseEnds/` bleiben unberührt. Wird beim Betrieb ein Dienstfehler sichtbar, wird der Schnitt angehalten; der Fix ist ein eigener Schnitt.

### Schnittstelle und Festlegungen

- **Statuscodes des Dienstes** (`server/src/app-routes.ts`, gegengelesen), Reihenfolge: 405 für Nicht-POST (Header `allow: POST`), 401 ohne Bearer oder bei unbekannter Sitzung, 400 bei fehlender oder ungültiger `X-Device` (nur `claim`, `result`), 415 ohne `application/json`, 413 über 256 KiB (beim Lesen gezählt), 400 bei ungültigem JSON oder Form. Alle Ablehnungen sind nackte Statuscodes mit `cache-control: no-store`.
- **nginx vor dem Dienst:** 413 aus `client_max_body_size 256k` schon anhand des Kopfes `Content-Length`, ohne dass der Dienst die Anfrage sieht; 429 aus `limit_req`; 404 für den Rest unter `/app/`.
- **`check-app.sh`** (Vorlage `docs/artifacts/feat-615-s4d-auth-oeffnen/check-auth.sh`): `curl`, ohne Geheimnisse, ohne gültige Sitzung, Ausgabe zeilenweise `OK`/`FEHLT` mit Statuscode, Exit 0 nur, wenn alles `OK` und kein 429 kam; **genau acht Anfragen, keine Schleifen**: `POST /app/transcript`, `POST /app/orders/claim`, `POST /app/orders/result` ohne Bearer (je 401); `GET` auf alle drei Pfade (je 405); `GET /app/x` (404); `POST /app/transcript` mit 300-KiB-JSON-Körper (413). Schlusszeilen: Zahl der Anfragen, „429 gesehen: ja/nein“, Zeitpunkt und Adresse.
- **`expected-exposure.json`:** neu `/app/transcript`, `/app/orders/claim`, `/app/orders/result` je GET → 405 und `/app/x` → 404.
- **Geheimnisse:** nie im Repo, Protokoll, Beleg oder Nachricht; das Skript sendet nie einen `Authorization`-Kopf, auch keinen erfundenen.
- **Nur `systemctl reload nginx`**, nie Neustart, kein Reboot, kein Eingriff in andere Dienste.
- **Commit-Gate im Infra-Klon:** verlangt vor dem Adversary Hennings `override` (Erfahrung aus S6b und S4d); wird eingeplant, nicht umgangen.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| Dienst mit den drei App-Wegen live (S1, `LE_COMMIT` `63de3cc`, 2026-11-11 21:11Z ausgerollt) | bestehend |
| nginx 1.24.0 auf `rennwienix`, Datei `nginx/loose-ends.henemm.com.conf` mit Allowlist | bestehend |
| fail2ban-Jail `nginx-limit-req` (`maxretry 10`, `findtime 10m`, `bantime 1h`, henemm-infra#397) | bestehend, unverändert |
| Infra-Repo: `python3 -m pytest tests -q`, `security/check-external-exposure.sh`, `monitor.sh --status` | bestehend |
| Downstream | S2 (App-Client: 429 als eigener Fehler, Abbruch des Durchgangs), S3 (`ClaudeSync`), S5 (Weckruf an alle Geräte gleichzeitig), #622-Beleg aus claude.ai |

## Acceptance Criteria

Belege liegen unter `docs/artifacts/feat-795-s1b-nginx/` (im Folgenden „Belegordner“). Kein Beleg enthält einen Geheimniswert; Ausgaben zeigen nur Namen, Statuscodes und Zählungen.

- **AC-1:** RED des Prüfskripts: GIVEN `docs/artifacts/feat-795-s1b-nginx/check-app.sh` WHEN es vor der nginx-Änderung gegen `https://loose-ends.henemm.com` läuft THEN endet es mit Exit ≠ 0, und `red.txt` zeigt `FEHLT` mit 404 für die drei `POST` ohne Sitzung (erwartet 401), die drei `GET` (erwartet 405) und den 300-KiB-Körper (erwartet 413); `GET /app/x` ist schon `OK` mit 404; die Datei nennt genau acht gesendete Anfragen.
- **AC-2:** nginx öffnet genau drei Pfade: GIVEN die Datei `nginx/loose-ends.henemm.com.conf` WHEN der Auszug des Server-Blocks aus `nginx -T` gelesen wird THEN enthält er genau drei `location =` für `/app/transcript`, `/app/orders/claim` und `/app/orders/result`, jeweils mit `limit_req zone=loose_ends_app burst=40 nodelay`, `client_max_body_size 256k`, `proxy_pass http://127.0.0.1:8780` und den vier Headern `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto` wie bei `/health`; es gibt unter `/app/` keine Streaming-Einstellung (`proxy_buffering off`, `proxy_read_timeout`) (Beleg `nginx-T.txt`, ohne Geheimnisse).
- **AC-3:** Eigene Zone, Anmeldung unberührt: GIVEN dieselbe Datei WHEN die `limit_req_zone`-Zeilen gelesen werden THEN gibt es `loose_ends_app` mit `rate=10r/s` und `limit_req_status 429` für die drei App-Pfade, die Zone `loose_ends_auth` hat unverändert `rate=5r/s`, und keiner der drei App-Pfade verwendet `loose_ends_auth` (`grep` auf `zone=loose_ends_auth` im Block der App-Pfade ergibt 0 Treffer, die Auth-Pfade verwenden sie wie vorher; Beleg `nginx-T.txt` mit dem Vergleich zu `nginx-alt.conf`).
- **AC-4:** Der Rest bleibt zu: GIVEN dieselbe Datei WHEN sie gelesen wird THEN enthält sie `location ^~ /app/ { return 404; }`, `^~ /auth/` und `location / { return 404; }` weiterhin mit 404, und die Kopfzeile der Datei nennt die drei App-Pfade samt Zone (Beleg `nginx-T.txt`).
- **AC-5:** `expected-exposure.json` und Infra-PR: GIVEN der PR in `henemm/henemm-infra` WHEN er geöffnet ist THEN ändert er genau `nginx/loose-ends.henemm.com.conf` und `security/expected-exposure.json`; die JSON-Datei enthält `/app/transcript`, `/app/orders/claim`, `/app/orders/result` je GET → 405 und `/app/x` → 404; `python3 -m pytest tests -q` im Wegwerfklon auf `rennwienix` ist grün und die CI des PR ist grün (Beleg `infra-pr.txt`: PR-Nummer, Kennungen, Teststand, CI-Status).
- **AC-6:** nginx wird nur nach Test geladen, mit Rückweg: GIVEN die neue Datei auf dem Server WHEN sie in Kraft gesetzt wird THEN ist die alte Datei vorher gesichert (`nginx-alt.conf` im Belegordner, Ort der Sicherung auf dem Server genannt), `nginx -t` zeigt `syntax is ok` und `test is successful`, `systemctl reload nginx` läuft erst danach mit Exit 0 (Beleg `nginx-t.txt` mit Zeitstempeln, Reload später als Test); bei Fehler im Test wird nicht geladen.
- **AC-7:** Öffnung von außen, GREEN: GIVEN nginx ist geladen WHEN `check-app.sh` von außen läuft THEN Exit 0 und `green.txt` zeigt `OK` mit den drei `POST` ohne Sitzung je 401, den drei `GET` je 405, `GET /app/x` 404 und `POST /app/transcript` mit 300-KiB-Körper 413; die Schlusszeilen nennen genau acht gesendete Anfragen und `429 gesehen: nein`.
- **AC-8:** 413 kommt von nginx, nicht vom Dienst: GIVEN der 300-KiB-Körper aus AC-7 WHEN die Antwort geprüft wird THEN ist der Status 413 ohne Anmeldung (ohne `Authorization`-Kopf; der Dienst würde 401 geben), und die Zeile im Zugriffsprotokoll von nginx für diese Anfrage zeigt 413 (Beleg `green.txt` mit dem Zusatz „ohne Bearer, daher von nginx“ und `nginx-413.txt` mit der Protokollzeile, ohne Adressen und Geheimnisse).
- **AC-9:** Exposure-Prüfung ohne Abweichung und andere Hosts unverändert: GIVEN `security/expected-exposure.json` aus AC-5 WHEN `check-external-exposure.sh` (oder der Einzelaufruf des Scans der Infra) läuft THEN meldet er für `loose-ends.henemm.com` keine Abweichung (Beleg `scan.txt`: Zeilen des Hosts mit Status); GIVEN `monitor.sh --status` auf `rennwienix` WHEN es vor Beginn der Serverarbeit und nach dem Reload läuft THEN zeigt `diff` von `monitor-vorher.txt` und `monitor-nachher.txt` keine Zeile eines anderen Dienstes als `loose-ends`, und `loose-ends` ist `OK`; läuft der Scan nur nachts und ist nicht vorziehbar, steht im Beleg der Zeitpunkt des nächsten Laufs und `todo-scan.md` im Belegordner, den der Tech Lead beim nächsten Sitzungsstart prüft, nie Henning.
- **AC-10:** Vertrag mit 429-Regel: GIVEN `docs/reference/claude-abschrift-vertrag.md` WHEN der Abschnitt „Wege der App“ gelesen wird THEN nennt er, dass nginx die drei Wege auf 10 Anfragen je Sekunde (Stoß bis 40) begrenzt und bei Überschreitung 429 antwortet, und legt als Pflicht der App fest: bei 429 den Abholdurchgang abbrechen und erst beim nächsten Anlass fortsetzen, ohne Schleife; der Vertrag enthält weiterhin genau drei ```json-Blöcke (die Tests von `server/test/orders.test.ts` lesen genau drei; der neue Text steht als Fließtext oder ```text, Prüfung per `grep -c '^```json'` ergibt 3).
- **AC-11:** `CLAUDE.md` aktuell: GIVEN der Doku-PR WHEN er geöffnet ist THEN steht im Absatz `src/app-routes.ts` im Abschnitt `server/` nicht mehr „nginx (`/app/`, S1b) … still open“, sondern dass `/app/transcript`, `/app/orders/claim` und `/app/orders/result` seit S1b offen sind (Zone `loose_ends_app`, 256k, Rest unter `/app/` 404), der App-Client (S2) noch offen ist und `refused` 409 ein Ergebnis zu einem Auftrag meint, den dieses Gerät nicht (mehr) hält; der Betrieb-Absatz nennt `/app/…` in der Liste der offenen Pfade mit Verweis auf den Belegordner.
- **AC-12:** Belege vollständig und ohne Geheimnisse: GIVEN der Belegordner WHEN er geprüft wird THEN enthält er `check-app.sh`, `red.txt`, `infra-pr.txt`, `nginx-T.txt`, `nginx-t.txt`, `nginx-alt.conf`, `nginx-413.txt`, `green.txt`, `scan.txt`, `monitor-vorher.txt`, `monitor-nachher.txt`; die Suche nach Wertmustern (`-----BEGIN`, `Bearer ` mit folgendem Wert, `"d":`) ergibt 0 Treffer; die Karte #795 ist aktuell und #795 hat einen Kommentar mit dem Stand S1b (Folge S2).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `henemm-infra: nginx/loose-ends.henemm.com.conf` | MODIFY | Zone `loose_ends_app`, drei `location =`, `^~ /app/` 404, Kopfkommentar; ≈ +45/−2 |
| `henemm-infra: security/expected-exposure.json` | MODIFY | vier Einträge; ≈ +4/−1 |
| `docs/artifacts/feat-795-s1b-nginx/` (loose-ends) | CREATE | `check-app.sh` (≈ 40 Zeilen) und Belege (Text) |
| `CLAUDE.md` (loose-ends) | MODIFY | Absatz `src/app-routes.ts` und Betrieb-Absatz; ≈ +3/−0 |
| `docs/reference/claude-abschrift-vertrag.md` (loose-ends) | MODIFY | 429-Regel im Abschnitt „Wege der App“; ≈ +8/−0 |

Außerhalb des Repos (Handarbeit, nicht versioniert, mit Belegen): Server `rennwienix` (Wegwerfklon und Tests, `git pull --ff-only`, nginx-Datei, `reload`).

### Estimated Changes

- **Dateien: 5 Pfade** (2 im Infra-Repo, 3 in loose-ends; der Belegordner zählt als ein Pfad). Innerhalb des Limits von 4 bis 5 Dateien; Belege sind Text und zählen nicht als Code.
- **LoC: ≈ +100 / −3** (nginx ≈ 45, JSON ≈ 4, Skript ≈ 40, Doku ≈ 11), innerhalb von ±250 LoC. Kein Dienstcode.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine Migration, keine neue Abhängigkeit.
- **Seiteneffekte nach außen (explizit):** Drei Pfade am Live-Dienst werden öffentlich erreichbar (ohne gültige Sitzung weisen sie mit nacktem Statuscode ab); geteiltes nginx lädt neu (`reload`, kein Neustart, `nginx -t` vorher); eine neue Mengenbegrenzung gilt für diese Pfade. Der Dienst wird nicht neu gestartet.
- **Parallele Arbeit:** vor jedem PR `origin/main` und offene PRs in beiden Repos erneut prüfen; `CLAUDE.md` ist Hotspot.

## Risiken

- **Öffentlicher Endpunkt am Live-Dienst.** Gegenmittel: exakte Pfade, Zone mit Limit, 256-KiB-Grenze in nginx und im Dienst, nackte Statuscodes, Sitzung vor jeder Verarbeitung; Rückweg über die gesicherte nginx-Datei.
- **fail2ban sperrt Hennings Heim-Adresse für alle Hosts eine Stunde** bei zehn Limit-Treffern. Gegenmittel: eigene Zone mit 10 r/s und Stoß 40 (trägt die gerechneten 26 Anfragen), Abbruchregel bei 429 im Vertrag (AC-10), `check-app.sh` mit genau acht Anfragen. Restrisiko: ein Gerät, das gegen die Regel verstößt (Fehler in S2/S3); die Regel steht im Vertrag, S2/S3 testen sie.
- **Zu knapp bemessene Grenze.** Eine Last mit sehr vielen Aufträgen je Weckruf überschritte den Stoß. Gegenmittel: Messen in S3; Abholen gebündelt (Alternative C) wäre dann ein eigener Dienstschnitt.
- **Geteiltes nginx.** Ein Fehler könnte andere Hosts treffen. Gegenmittel: `nginx -t` vor `reload`, alte Datei gesichert, `monitor.sh --status` vorher und nachher (AC-6, AC-9).
- **Belegkraft.** Die 401 ohne Sitzung belegt die Öffnung, nicht den echten Durchlauf mit Sitzung; der kommt mit S2/S3.
- **Commit-Gate im Infra-Klon** verlangt vor dem Adversary Hennings `override`; wird eingeplant, nicht umgangen.

## Test Plan

Es gibt keinen Dienstcode und keine App-Änderung, also keine neuen Unit- oder UI-Tests. Die Prüfungen sind Außenprüfung, Infra-Tests und Dateiinhalte:

| Prüfung | Beleg | AC |
|---|---|---|
| `check-app.sh` RED vor der nginx-Änderung | `red.txt` | AC-1 |
| `nginx -T`-Auszug: drei `location =`, Zone, 256k, Rest 404 | `nginx-T.txt` | AC-2, AC-3, AC-4 |
| Infra-PR, `python3 -m pytest tests -q` auf `rennwienix`, CI | `infra-pr.txt` | AC-5 |
| `nginx -t` vor `reload`, alte Datei gesichert | `nginx-t.txt`, `nginx-alt.conf` | AC-6 |
| `check-app.sh` GREEN von außen, genau acht Anfragen | `green.txt` | AC-7 |
| 413 ohne Sitzung, Protokollzeile von nginx | `green.txt`, `nginx-413.txt` | AC-8 |
| Exposure-Prüfung, `monitor.sh --status` vorher/nachher | `scan.txt`, `monitor-*.txt` | AC-9 |
| Vertrag: 429-Regel, drei ```json-Blöcke | Doku-PR (`grep`) | AC-10 |
| `CLAUDE.md`, Vollständigkeit der Belege, Wertscan, Board | Doku-PR | AC-11, AC-12 |

- [ ] Test 1 (AC-1): GIVEN unveränderter Stand WHEN `check-app.sh` THEN Exit ≠ 0, `FEHLT` mit 404 an den neuen Pfaden.
- [ ] Test 2 (AC-2 bis AC-4): GIVEN die neue Datei WHEN `nginx -T` gelesen THEN drei `location =`, Zone `loose_ends_app` getrennt, `^~ /app/` 404.
- [ ] Test 3 (AC-5): GIVEN der Infra-Klon WHEN `python3 -m pytest tests -q` THEN grün.
- [ ] Test 4 (AC-6): GIVEN die neue Datei WHEN `nginx -t` THEN `syntax is ok`, `test is successful`, danach `reload`.
- [ ] Test 5 (AC-7, AC-8): GIVEN geladene Datei WHEN `check-app.sh` THEN Exit 0, acht Anfragen, kein 429, 413 ohne Sitzung.
- [ ] Test 6 (AC-9): GIVEN Exposure-Prüfung und `monitor.sh --status` WHEN verglichen THEN keine Abweichung, keine Zeile eines anderen Dienstes.
- [ ] Test 7 (AC-10): GIVEN der Vertrag WHEN `grep -c '^```json'` THEN 3 und die 429-Regel steht im Abschnitt.

**Ehrlich zur Belegkraft:** Die ACs 1 bis 9 belegen nur, dass die Pfade offen sind und nach außen richtig abweisen. Ob die App mit gültiger Sitzung durchkommt und ob die Grenze im echten Betrieb reicht, belegen erst S2/S3.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): eigene Zone 10 r/s, burst 40, Abbruchregel bei 429** | siehe Purpose | trägt den Weckruf mit drei Geräten (26 Anfragen); Anmeldung und Abgleich zählen getrennt; höchstens eine Ablehnung je Gerät und Anlass | eine zusätzliche Zone und eine Vertragsregel, die S2/S3 einhalten müssen | die S1-Notiz „Zone wie `loose_ends_auth`“; keine ADR |
| **B Zone `loose_ends_auth` mitbenutzen** (S1-Vorgabe) | keine neue Zone | kleinste Datei | 5 r/s, burst 10: ein Weckruf mit rund 10 Aufträgen erzeugt rund 10 Ablehnungen und damit die Stundensperre der Heim-Adresse; Anmeldung und Abgleich verbrauchen einander | die S1-Notiz; verworfen |
| **C Abholen gebündelt** (`claim` liefert alle offenen Aufträge, ein `result` für alle) | 2 bis 3 Anfragen statt 2N + 2; Grenze könnte eng bleiben | wenig Last | kippt den Vertrag aus S1 (ein Auftrag je `claim`, AC-4/4a) und die Rückholregel je Auftrag; Dienstcode statt Betriebsschnitt | der Vertrag Version 1 (S1), keine ADR; lohnt erst, wenn S3 echte Mengen misst |
| **D `/app/` aus fail2ban nehmen** (`limit_req_log_level info`) | keine Sperre der Heim-Adresse möglich | kein Aussperren | auch keine Sperre eines Angreifers auf öffentlichen Pfaden; Anmeldeversuche unbegrenzt wiederholbar; ändert die Jail-Haltung aus henemm-infra#397 | die Haltung „jedes Limit zählt für die Sperre“ (henemm-infra#397); verworfen |

## Out of Scope / Folgeschnitte

- **S2:** App-Client (429 als eigener Fehler, Abbruch des Durchgangs, `X-Device`, Sitzung); **S3:** `ClaudeSync`; **S5:** Weckruf an alle Geräte; Gerätepunkte stehen bei diesen Schnitten.
- **Abholen gebündelt** (Alternative C) und ein Long-Poll: eigener Dienstschnitt, erst nach Messung in S3.
- **Dienstfixes, die der Betrieb offenlegt:** eigene Schnitte.
- Änderungen an `server/src`, Migrationen, App, Widgets, Watch, Mac, Deploy des Dienstes: keine.

## Abnahme

Der Schnitt berührt keinen Pfad der Geräteliste (nur `henemm-infra`, `docs/artifacts/`, `CLAUDE.md`, Vertrag; kein `project.yml`, keine Entitlements, keine `Info.plist`). Kein App-Code wird geändert; Stufe 1 ist die Infra-Testsuite plus Dateiprüfungen, Stufe 2 die Abnahme von außen (`check-app.sh` GREEN, Exposure-Prüfung). Der Abschlussbericht sagt: „Kein Pfad der Geräteliste berührt.“ Gerätepunkte gibt es in diesem Schnitt nicht; die App ruft die Wege erst ab S2/S3.

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt, Belege im Belegordner
- [ ] `check-app.sh` Exit 0 von außen, `monitor.sh --status` für andere Dienste unverändert
- [ ] Infra-PR gemergt (CI grün), Doku-PR gemergt (mit `Refs #795`), `CLAUDE.md` und Vertrag aktualisiert
- [ ] Kein Geheimniswert in Repo, Belegen, Protokoll oder Nachricht (Scan, 0 Treffer)
- [ ] #795 kommentiert (Stand S1b, Folge S2), Board-Karte aktuell, Memory geschrieben

## Changelog

- 2026-11-11: Initial spec created (Schnitt S1b)
