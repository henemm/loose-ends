---
entity_id: feat-621-schnitt-6b-betrieb
type: feature
created: 2026-11-08
updated: 2026-11-08
status: draft
workflow: feat-621-s6b-betrieb
---

# Spec: Den Dienst öffnen und claude.ai einmal echt verbinden (Schnitt 6b, #621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 6b; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte; S7 Abschrift v2, #795, #625 und #615 S4 folgen). Das Issue schließt erst, wenn die Definition of Done des Tickets („In claude.ai als eigener Connector verbunden“) belegt ist; dieser Schnitt liefert genau diesen Beleg für den Verbindungsteil.
Analyse: `docs/context/feat-621-s6b-betrieb.md` (Ist-Stand 2026-11-08, Reihenfolge, Alternativen, Risiken) und `docs/context/feat-621-s6-betrieb.md` (Gesamtanalyse S6, Recherche nginx-Streaming und claude.ai-Callback). Vorgänger: `docs/specs/feat-621-schnitt-6a-tuer.md` (die Tür: `admit`, `ALLOWED_APPLE_SUBS`, PR #873). Es ist ein Betriebsschnitt: **kein Dienstcode in `server/src`**.

## Für den PO

Der Dienst für Claude ist fertig gebaut, steht aber noch hinter einer zugemachten Tür im Netz: von außen antwortet nur die Gesundheitsprüfung. Dieser Schnitt macht ihn für claude.ai erreichbar und verbindet dich einmal echt: Du fügst in claude.ai einen eigenen Connector ein, meldest dich mit deiner Apple-ID an, bestätigst auf einer Zustimmungsseite, und Claude kann danach deine Loose-Ends-Abschrift abrufen. Das ist der Beleg, auf den das Ticket #621 wartet.

Was du dafür tust, zusammen etwa 20 Minuten an einem Stück: (1) Du meldest dich im Apple-Entwicklerportal in Chrome an; die Einrichtung dort klicke ich. (2) Wenn ich dir sage, dass alles bereitsteht, fügst du den Connector in claude.ai hinzu und meldest dich an. Alles andere (Server, Geheimnisse, Webserver, Prüfung von außen) mache ich selbst.

Zwei Dinge hole ich vorher bei dir ein: die Erlaubnis, auf dem Server zu schreiben (die vom 3. November galt nur für die Sicherung; die Grenzen bleiben: kein Neustart des Servers, kein Neustart anderer Dienste, kein Eingriff in Docker selbst) und den Zeitpunkt, an dem du die 20 Minuten hast. Der Grund für den Zeitpunkt: Solange noch niemand verbunden ist, nimmt der Dienst als erstes Konto das erste, das sich anmeldet. Das soll deines sein, deshalb folgen „Öffnen“ und „du verbindest“ direkt aufeinander. Danach prüfe ich, dass genau ein Konto besteht, trage deine Apple-Kennung als einzige zugelassene auf dem Server ein (nur dort, nie im Repo oder in einer Nachricht), und die Tür ist zu.

An der App, am iPhone, iPad, Mac oder an der Watch ändert sich nichts.

## Purpose

`https://loose-ends.henemm.com` ist heute ein Hostname mit Zertifikat (#796 S4a), über den nginx nur `/health` an den Dienst reicht; `/mcp` und alles andere antworten 404. Der Dienst selbst (S1–S5 plus Tür S6a, `main`-Stand `ae957ba`) kann OAuth-Aussteller, Anmeldung über Apple, Zustimmungsseite und MCP-Werkzeuge; er ist aber nie öffentlich gelaufen.

Dieser Schnitt (a) richtet bei Apple die Services ID für die Anmeldung im Browser ein, (b) legt die Geheimnisse des Dienstes auf dem Server ab, (c) öffnet in nginx genau die Pfade, die claude.ai braucht, (d) bringt den Dienst auf den Stand mit der Tür und (e) verbindet claude.ai einmal echt mit Hennings Apple-Konto und belegt dies.

**Geöffnet wird nach einer Erlaubnisliste von Pfaden** (die bestehende Haltung der Datei), nichts anderes:

| Pfad | Zweck | nginx |
|---|---|---|
| `= /health` | Gesundheit (besteht) | unverändert |
| `= /mcp` | MCP über Streamable HTTP | Streaming (`proxy_http_version 1.1`, `Connection ""`, `proxy_buffering off`, `proxy_read_timeout 3600s`), Zone `loose_ends_mcp` |
| `= /.well-known/oauth-protected-resource/mcp` | Metadaten der Ressource | Zone `loose_ends_oauth` |
| `= /.well-known/oauth-authorization-server` | Discovery | Zone `loose_ends_oauth` |
| `= /.well-known/openid-configuration` | Discovery | Zone `loose_ends_oauth` |
| `^~ /oauth/` | Aussteller, Anmeldung, Rückweg von Apple, Zustimmung | Zone `loose_ends_oauth`, `client_max_body_size 64k` |
| `/auth/*`, `/` und alles Übrige | App-Anmeldung (#615 S4), nichts | bleibt 404 |

Alle geöffneten Pfade reichen dieselben Header weiter wie `/health` (`Host $host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`), damit der Issuer exakt `https://loose-ends.henemm.com` bleibt (`proxy` ist im Aussteller an; ein falscher Host bricht Discovery, `iss` und Weiterleitungen).

**Ablauf (feste Reihenfolge, damit nie ein halb offener Zustand nach außen steht):**

0. **Freigaben**: Server-Schreibfreigabe und Zeitpunkt von Henning (per AskUserQuestion, mit Kontext). Vorher keine Serverarbeit, auch keine lesende am Server außer dem, was die Analyse schon über `gh api` gelesen hat.
1. **Prüfskript und RED-Beleg** (nur von außen, schreibt nichts).
2. **Apple-Portal** (Henning meldet sich in Chrome an, ich klicke): Services ID mit Sign in with Apple, primäre App `com.henning.looseends`, Domain `loose-ends.henemm.com`, Return-URL `https://loose-ends.henemm.com/oauth/apple/return`; prüfen, welcher der drei `.p8` unter `~/Developer/AuthKey_{K928C9Z9P2,T7D652RS7A,WF54BW29RL}.p8` Sign in with Apple trägt (Portal → Keys), fehlt ein passender, einen neuen anlegen; Domain-Verifikation nur, wenn das Portal sie verlangt (dann braucht nginx für genau `/.well-known/apple-developer-domain-association.txt` eine eigene statische `location`, ohne Umleitung; das ist ein Zusatzpunkt der Infra-Datei und wird im Beleg vermerkt).
3. **Geheimnisse** in der Geheimnisdatei des Stapels auf `rennwienix` (`loose-ends/secrets/server.env`, Rechte 700/600, nicht versioniert): `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_IDS`, `APPLE_TOKEN_KEY`, `APPLE_WEB_CLIENT_ID`, `OAUTH_COOKIE_KEYS`, `OAUTH_SIGNING_JWK`, `PUBLIC_URL`. Cookie-Schlüssel, ES256-JWK und Token-Schlüssel werden auf dem Server erzeugt; vom Mac wird nur der `.p8` übertragen. Vollständigkeit wird nur nach **Namen** geprüft (unvollständige `APPLE_*` oder halbe OAuth-Schlüssel stoppen den Dienst mit Exit 1 und ließen den Stapel unten), nie werden Werte ausgegeben.
4. **Infra-PR** in `henemm/henemm-infra` (nginx-Datei, `LE_COMMIT`, `expected-exposure.json`), CI, Merge. Auf dem Server `git pull` in `/home/hem/henemm-infra`.
5. **Erst Deploy, nginx noch zu**: `scripts/deploy-loose-ends.sh` bringt den Dienst auf den neuen Stand; lokal (`127.0.0.1:8780`, `curl -H "Host: loose-ends.henemm.com"` und `X-Forwarded-Proto: https`) kommen Health 200 und die Discovery mit dem richtigen Issuer. Von außen ist noch nichts offen.
6. **Dann nginx**: alte Datei sichern, neue nach `/etc/nginx/sites-available/` kopieren, `nginx -t`, erst bei Erfolg `systemctl reload nginx`.
7. **Prüfung von außen** (GREEN des Prüfskripts) und `monitor.sh --status`: andere Dienste unverändert.
8. **Sofort danach** verbindet Henning in claude.ai (Apple-Anmeldung, Zustimmungsseite). Das Fenster der Tür (Zweig 2 aus S6a) ist damit Minuten, nicht Stunden.
9. **Tür schließen**: `accounts` = 1; Hennings `sub` aus der Datenbank (nur Server) nach `ALLOWED_APPLE_SUBS` in `server.env`; Neustart über das Deploy-Skript (nie anders); `accounts` weiter 1; Dienst gesund.
10. **Beleg aus claude.ai**: ein Werkzeugaufruf (`get_now`); die CIMD-`client_id` (nur die URL) aus `oauth_records` ablesen.
11. **Belege-PR** im loose-ends-Repo (`docs/artifacts/feat-621-s6b-betrieb/`), `CLAUDE.md` (Betrieb-Zeile), Memory, Kommentar in #621.

**Regeln vor Modell:** Betrieb, Netz und Sicherheit ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 (Claude bekommt ein Fenster, eigener Dienst, OAuth-Aussteller, „nur Henning bis #625“, Addendum zum Aussteller) um, ohne sie zu ändern oder zu kippen; kein neues Verfahren, keine neue Abhängigkeit, keine Migration. Geprüft gegen `docs/project/00-entscheidungen.md`, ADR-21: die Pfade, die Ausschlüsse (`/auth/*` bleibt zu) und die Beschränkung auf Hennings Konto entsprechen dem Beschlossenen.

- **Rationale:** Die Entscheidung steht; offen war nur der Betrieb. Er folgt dem Vorbild #796 S4a (Infra-PR, Deploy-Skript mit festem Stand, Belege als eigener PR).

## Source

**Dateien (Infra-Repo `henemm/henemm-infra`):** `nginx/loose-ends.henemm.com.conf`, `scripts/deploy-loose-ends.sh`, `security/expected-exposure.json`.
**Dateien (loose-ends):** `docs/artifacts/feat-621-s6b-betrieb/` (neu: Prüfskript und Belege), `CLAUDE.md` (Betrieb-Zeile im Abschnitt `server/`).
**Kein Dienstcode:** `server/src`, `server/test`, Migrationen und `server/package.json` bleiben unberührt. Wird beim Betrieb ein Dienstfehler sichtbar (zum Beispiel eine abweichende CIMD-Adresse von claude.ai), wird der Schnitt angehalten und der Fix ist ein eigener Dienstschnitt.

### Schnittstelle und Festlegungen

- **nginx-Datei:** neue `limit_req_zone`-Zonen `loose_ends_oauth` und `loose_ends_mcp` neben der bestehenden `loose_ends_health` (30 r/m); Werte: `loose_ends_oauth` `rate=10r/s`, in den Blöcken `burst=20 nodelay` (gilt für `/.well-known/*` und `^~ /oauth/`); `loose_ends_mcp` `rate=10r/s`, `burst=40 nodelay`; `limit_req_status 429`. Ein einzelnes Verbinden (Discovery, Metadaten, Auth, Token, Rückweg, Zustimmung, `/mcp` mehrfach, zusammen unter 20 Anfragen) wird so nie begrenzt, ein Schnelllauf von 60 Anfragen innerhalb einer Sekunde aber schon. `client_max_body_size 64k` für `^~ /oauth/`. Die Kopfzeile der Datei nennt die geöffneten Pfade neu. `/auth/` und `/` bleiben ausdrücklich 404. Die certbot-Blöcke 443/80 bleiben unverändert.
- **`deploy-loose-ends.sh`:** nur `LE_COMMIT` ändert sich, auf den `main`-Stand des Dienstes zum Deploy-Zeitpunkt; er muss `ae957ba` (PR #873) enthalten. Backup-Sperre (02:45–03:30), Speicherprüfung (≥ 600 MB frei), Health-Warte 60 s und „bei Fehler bleibt der Stapel“ bleiben, wie sie sind. `docker-compose.yml` ändert sich nicht: der Dienst `server` liest laut Ist-Stand (henemm-infra `main`, gelesen 2026-11-08 über `gh api`) `env_file: ./secrets/server.env`, alle neuen Variablen landen dort; vor Schritt 3 wird diese Zeile erneut gelesen; wäre es doch nötig, kommt es als vierte Infra-Datei in denselben PR und der Beleg nennt den Grund.
- **`expected-exposure.json`:** `loose-ends.henemm.com` in `tls_hosts`; in `urls`: `/health` 200, `/mcp` ohne Token 401, `/.well-known/oauth-authorization-server` 200, `/auth/apple` 404, `/` 404.
- **Geheimnisse:** nur auf dem Server, nie im Repo, nie im Protokoll, nie in einer Nachricht an Henning, nie in einem Beleg; Belege nennen Variablennamen und Zählungen, nie Werte. Ausnahme ohne Wert: die CIMD-`client_id` ist eine öffentliche URL und darf im Beleg stehen.
- **Nur über das Deploy-Skript neu starten**, nie `docker compose` von Hand, nie andere Dienste, kein Reboot, kein Docker-Daemon.
- **Alte nginx-Datei vor dem Kopieren sichern** (Rückweg: zurückkopieren, `nginx -t`, `reload`).
- **Stil:** Skript `check-outside.sh` mit `curl`, nur lesend, ohne Geheimnisse, Ausgabe zeilenweise `OK`/`FEHLT` mit Statuscode; Exit 0 nur, wenn alle Zeilen `OK`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| Dienst auf `main` inkl. S6a (`ae957ba`), Image-Build im Deploy-Skript | bestehend |
| Zertifikat und Hostname `loose-ends.henemm.com` (#796 S4a, A-Eintrag `178.104.143.19`), Postgres 18 im Stapel `loose-ends` | bestehend |
| Apple-Entwicklerkonto (Team `XK87E2B3VR`), Sign-in-with-Apple-Schlüssel (`.p8`), neue Services ID | Henning meldet sich an, ich klicke; Portal hat keine API für Services IDs |
| claude.ai (Connector-Einstellung, Hennings Konto; Callback `https://claude.ai/api/mcp/auth_callback`) | Henning |
| Server-Schreibfreigabe für S6b | Henning, vor Beginn |
| `monitor.sh --status`, externer Scan der Infra (`expected-exposure.json`) | bestehend |
| Downstream | S7 (Abschrift v2), #795, #625 (Veröffentlichung, Regel der Tür entfällt), #615 S4 (App-Anmeldung über `/auth/*`, bleibt zu) |

## Acceptance Criteria

Belege liegen unter `docs/artifacts/feat-621-s6b-betrieb/` (im Folgenden „Belegordner“). Kein Beleg enthält einen Geheimniswert; Ausgaben mit Variablen zeigen nur Namen, Zählungen und Statuscodes.

- **AC-1:** Vorab-Freigaben belegt: GIVEN der Schnitt beginnt WHEN vor der ersten Schreibaktion am Server und vor dem Apple-Portal die Fragen an Henning gestellt sind THEN steht im Belegordner `freigaben.md` mit seiner wörtlichen Server-Schreibfreigabe für #621 S6b samt den Grenzen (kein Neustart des Servers, kein Neustart anderer Dienste, kein Docker-Daemon) und dem vereinbarten Zeitpunkt; ohne diese Datei ist keine Serverarbeit erfolgt (der erste Beleg mit Serverbezug trägt einen späteren Zeitstempel).
- **AC-2:** RED des Prüfskripts: GIVEN `docs/artifacts/feat-621-s6b-betrieb/check-outside.sh` (nur `curl`, nur lesend) WHEN es vor jeder Änderung gegen `https://loose-ends.henemm.com` läuft THEN gibt es Exit ≠ 0 aus, und `red.txt` zeigt: `/health` 200 (`OK`), Discovery (`/.well-known/oauth-authorization-server`) 404, `/.well-known/openid-configuration` 404, `/.well-known/oauth-protected-resource/mcp` 404, `/mcp` ohne Token 404 statt 401 (alle vier `FEHLT`), `/auth/apple` 404 und `/` 404 (`OK`).
- **AC-3:** Apple-Portal eingerichtet: GIVEN Hennings Anmeldung im Apple-Portal in Chrome WHEN die Services ID angelegt ist THEN dokumentiert `apple-portal.md` im Belegordner (ohne Schlüsselmaterial): Services-ID-Kennung (öffentlich, dieselbe wie `APPLE_WEB_CLIENT_ID`, ungleich `com.henning.looseends`), Sign in with Apple aktiv, primäre App `com.henning.looseends`, Domain `loose-ends.henemm.com`, Return-URL genau `https://loose-ends.henemm.com/oauth/apple/return`, die Schlüssel-ID (`APPLE_KEY_ID`, öffentlich) des für Sign in with Apple freigegebenen Schlüssels (Portal → Keys) und ob das Portal eine Domain-Verifikation verlangt hat (ja/nein); verlangt es sie, ist die statische `location` für `/.well-known/apple-developer-domain-association.txt` Teil des Infra-PR (AC-7) und `curl` auf diese Datei liefert 200 ohne Umleitung.
- **AC-4:** Geheimnisse vollständig und geschützt, nichts geleakt: GIVEN `secrets/server.env` auf `rennwienix` WHEN ein Namens-Check (ohne Werte) läuft THEN sind alle neun Namen `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CLIENT_IDS`, `APPLE_TOKEN_KEY`, `APPLE_WEB_CLIENT_ID`, `OAUTH_COOKIE_KEYS`, `OAUTH_SIGNING_JWK`, `PUBLIC_URL` gesetzt und nicht leer (Beleg `secrets-namen.txt`: je Name `gesetzt`, plus Dateirechte `600` der Datei und `700` des Ordners, ohne Werte); `PUBLIC_URL` ist genau `https://loose-ends.henemm.com`; GIVEN die Belege, der Infra-PR und die Nachrichten dieses Schnitts WHEN nach den Wertmustern gesucht wird (Beginn eines PEM-Blocks `-----BEGIN`, die Zeichenfolge `"d":` eines JWK, die ersten 12 Zeichen jedes Geheimniswerts, der Dateiinhalt des `.p8`) THEN gibt es keinen Treffer (Beleg `secrets-scan.txt`: Suchmuster, Dateiliste, „0 Treffer“; die Muster selbst enthalten keine Werte).
- **AC-5:** Infra-PR, drei Dateien und nichts darüber hinaus: GIVEN der PR in `henemm/henemm-infra` WHEN er geöffnet ist THEN ändert er `nginx/loose-ends.henemm.com.conf`, `scripts/deploy-loose-ends.sh` und `security/expected-exposure.json` (eine weitere Datei nur mit Begründung im Beleg, siehe Schnittstelle), die CI ist grün, `LE_COMMIT` ist ein Commit des Dienst-Repos, der `ae957ba` als Vorfahr hat (Beleg: `git merge-base --is-ancestor ae957ba` mit dem im PR gesetzten `LE_COMMIT` als zweitem Argument, Exit 0 in `infra-pr.txt` mit PR-Nummer, Commit-Kennungen und CI-Status), und der Diff von `deploy-loose-ends.sh` besteht nur aus der `LE_COMMIT`-Zeile.
- **AC-6:** Deploy vor nginx, der Dienst ist lokal richtig: GIVEN der Infra-PR ist gemergt und `git pull` auf `rennwienix` gelaufen WHEN `scripts/deploy-loose-ends.sh` läuft, bevor die nginx-Datei kopiert ist THEN endet es mit Exit 0 („Health 200“), der laufende Container trägt das neue Image des `LE_COMMIT`; lokal liefert `curl -H "Host: loose-ends.henemm.com" -H "X-Forwarded-Proto: https" http://127.0.0.1:8780/.well-known/oauth-authorization-server` Status 200 mit `"issuer":"https://loose-ends.henemm.com"` (exakt, ohne Pfad, ohne Port), und der `/health` lokal 200; zugleich zeigt `red.txt`-Wiederholung von außen weiterhin `/mcp` 404 (nichts war vorzeitig offen). Beleg `deploy-lokal.txt` (Deploy-Ausgabe, die beiden `curl`-Antworten gekürzt auf Statuscode und Issuer-Zeile, freier Speicher vor dem Deploy ≥ 600 MB laut Skript).
- **AC-7:** nginx wird nur nach Test geladen, mit Rückweg: GIVEN die neue Datei WHEN sie auf dem Server liegt THEN ist die alte Datei vorher gesichert (`nginx-alt.conf` im Belegordner, ohne Geheimnisse, der Ort der Sicherung auf dem Server genannt), `nginx -t` zeigt `syntax is ok` und `test is successful` (Beleg `nginx-t.txt` mit Zeitstempel), `systemctl reload nginx` läuft erst danach (Zeitstempel des Reloads später als der des Tests, Exit 0); bei Fehler im Test wird nicht geladen und die alte Datei bleibt in Kraft. Die Datei enthält die geöffneten Pfade aus der Tabelle im Purpose und nur diese, `/auth/` und `/` sind 404 (Beleg: `nginx -T`-Auszug des Server-Blocks `loose-ends.henemm.com`).
- **AC-8:** Öffnung von außen, GREEN: GIVEN nginx ist geladen WHEN `check-outside.sh` von außen läuft THEN Exit 0 und `green.txt` zeigt: `/health` 200; `/.well-known/oauth-authorization-server` 200 mit `issuer` exakt `https://loose-ends.henemm.com`; `/.well-known/openid-configuration` 200 mit demselben `issuer`; `/.well-known/oauth-protected-resource/mcp` 200 mit `resource` exakt `https://loose-ends.henemm.com/mcp`; `/mcp` ohne Token 401 mit Header `WWW-Authenticate`, der `resource_metadata` mit der Adresse `https://loose-ends.henemm.com/.well-known/oauth-protected-resource/mcp` nennt; `/auth/apple` 404 (GET und POST), `/auth/delete` 404, `/` 404, `/oauth/auth-gibt-es-nicht` oder ein anderer nicht vorhandener Pfad unter `/oauth/` kommt als Dienstantwort (kein nginx-Fehler 502/504). Die Discovery nennt `client_id_metadata_document_supported` mit `true` und `token_endpoint_auth_methods_supported` mit `none` (Voraussetzung für claude.ai, Beleg im selben Lauf).
- **AC-9:** Streaming, Body-Grenze und Limit-Zonen wirken: GIVEN die geladene Datei WHEN geprüft wird THEN enthält der Block für `= /mcp` `proxy_http_version 1.1`, `proxy_set_header Connection ""`, `proxy_buffering off` und `proxy_read_timeout 3600s` (Beleg `nginx -T`-Auszug); WHEN von außen ein POST mit 100 KiB Körper an `/oauth/token` geschickt wird THEN antwortet nginx mit 413 und der Dienst bekommt ihn nicht; WHEN 60 Anfragen an `/.well-known/oauth-authorization-server` innerhalb einer Sekunde kommen THEN ist mindestens eine Antwort 429 (Zone `loose_ends_oauth` greift, `limit_req_status 429`), und eine einzelne Anfrage danach (nach 10 s) liefert wieder 200. Beleg `grenzen.txt`.
- **AC-10:** Andere Dienste unverändert: GIVEN `monitor.sh --status` auf `rennwienix` WHEN es vor Beginn der Serverarbeit und nach dem Reload (AC-8) läuft THEN ist die Ausgabe für alle Dienste außer `loose-ends` zeilengleich (Beleg `monitor-vorher.txt`, `monitor-nachher.txt`, `diff` zeigt keine Zeile eines anderen Dienstes); `loose-ends` ist `OK`; die Hosts der anderen Dienste, die der Scan kennt, liefern weiterhin ihre Statuscodes aus `expected-exposure.json`; es hat keinen Neustart eines anderen Containers, keinen Reboot und keinen Docker-Neustart gegeben (Beleg: `uptime` des Hosts und `docker ps`-Spalte „Status/Created“ der anderen Container vor und nach, ohne Umgebungswerte).
- **AC-11:** Externer Scan kennt den Host: GIVEN `security/expected-exposure.json` mit den Einträgen aus der Schnittstelle WHEN der externe Scan der Infra (derselbe Weg, den der Scan sonst nimmt, oder, wenn er nur nachts läuft, sein Einzelaufruf mit der neuen Datei) läuft THEN meldet er für `loose-ends.henemm.com` keine Abweichung (Beleg `scan.txt`: Zeilen für den Host, Status; läuft er nur nachts und ist nicht vorziehbar, steht im Beleg der Zeitpunkt des nächsten Laufs und `todo-scan.md` im Belegordner, den der Tech Lead beim nächsten Sitzungsstart prüft, nie Henning).
- **AC-12:** claude.ai verbindet sich echt mit Hennings Apple-Konto: GIVEN AC-8 und AC-10 sind erfüllt und die Variablen für die Tür stehen noch nicht (Zweig 2) WHEN Henning in claude.ai `https://loose-ends.henemm.com/mcp` als eigenen Connector hinzufügt und die Verbindung startet THEN kommt er über die Apple-Anmeldung (Services ID aus AC-3) und die Zustimmungsseite des Dienstes („Zugriff erlauben“, Bereich `tasks`) ohne Fehlerseite zurück zu claude.ai, und der Connector steht dort als verbunden; belegt durch `verbinden.md` (Hennings Rückmeldung wörtlich, Zeitpunkt, Browser) und Nginx-Zugriffszeilen des Ablaufs ohne Query-Werte: Aufrufe von `/.well-known/oauth-protected-resource/mcp`, `/.well-known/oauth-authorization-server`, `/oauth/auth`, `/oauth/apple/return` (POST), `/oauth/token`, danach `/mcp` mit Statuscode 200, alle ohne 5xx. Der Rückweg von Apple (`form_post` über den Browser) ist damit in einem echten Browser belegt; läuft das Verbinden in Safari **und** Chrome, steht beides im Beleg, sonst steht ehrlich „nur Safari geprüft“ oder „nur Chrome geprüft“ (siehe Risiken).
- **AC-13:** CIMD-Adresse von claude.ai abgelesen und erlaubt: GIVEN das Verbinden aus AC-12 WHEN die `client_id` des Clients aus `oauth_records` (nur dieses Feld) oder aus dem Zugriffsprotokoll des Dienstes gelesen wird THEN steht sie im Beleg `cimd.md` als Adresse, beginnt mit `https://claude.ai/` und der Dienst hat sie ohne Fehler geladen (der Ablauf aus AC-12 wäre sonst abgebrochen); beginnt sie anders oder weist der Dienst sie ab, wird der Schnitt an dieser Stelle angehalten, nichts weiter geöffnet gelassen als nötig, und der Fix (Erlaubnis für eine weitere Herkunft im Aussteller) ist ein eigener Dienstschnitt mit eigener Spec.
- **AC-14:** Tür nach dem ersten Verbinden: GIVEN AC-12 WHEN direkt danach in der Datenbank gezählt wird THEN ist `SELECT count(*) FROM accounts` genau `1` (Beleg `tuer.md`: nur die Zahl, nie eine `apple_sub`, Zeitpunkt des nginx-Reloads, Zeitpunkt `created_at` des Kontos, Dauer des Fensters in Minuten); ist die Zahl größer als 1, wird die Tür sofort durch Rückgabe der alten nginx-Datei (AC-7) geschlossen, der Vorfall im Beleg festgehalten und Henning ohne Git-Vokabular informiert.
- **AC-15:** Liste gesetzt, Dienst neu, nichts ausgesperrt: GIVEN `accounts` = 1 WHEN Hennings `sub` (aus der Datenbank gelesen, nie ausgegeben, nie in ein Protokoll oder einen Beleg kopiert) als `ALLOWED_APPLE_SUBS` in `secrets/server.env` steht und das Deploy-Skript den Dienst neu startet THEN endet es mit Exit 0, `/health` ist 200, der Name `ALLOWED_APPLE_SUBS` ist gesetzt (Beleg `tuer.md`: „gesetzt, ein Eintrag“), der Startlauf des Dienstes enthält weder `allowed subs invalid` noch die `sub`, `accounts` ist weiter `1`, und `check-outside.sh` läuft wieder grün; WHEN Henning danach in claude.ai die Verbindung erneuert (trennen und wieder verbinden oder ein Werkzeug aufrufen, das die Anmeldung braucht) THEN wird er angenommen (belegt: seine Kennung steht in der Liste, er ist nicht ausgesperrt; Beleg in `verbinden.md`, Ergänzung).
- **AC-16:** Abweisung einer fremden Anmeldung, soweit prüfbar: GIVEN die Liste aus AC-15 WHEN geprüft werden soll, ob ein fremdes Apple-Konto abgewiesen würde THEN ist ein echter Live-Test ohne zweites Apple-Konto **nicht prüfbar**; der Beleg `tuer.md` hält das ehrlich fest und verweist auf die Tests von S6a (`server/test/oauth-return.test.ts`, „rueckweg: fremde sub ergibt access_denied ohne konto und ohne token“, und `auth.test.ts`, CI grün auf `main`), die die Regel mit echter Datenbank und Fake-Apple belegen; prüfbar bleibt live, dass das Zugriffsprotokoll nach dem Neustart keine Zeile `account refused` für Hennings eigene Anmeldung enthält und `accounts` nach allen Läufen `1` ist.
- **AC-17:** Werkzeugaufruf aus claude.ai: GIVEN AC-15 WHEN Henning in claude.ai den Connector nutzt und `get_now` aufgerufen wird THEN antwortet der Dienst auf `/mcp` mit Status 200 und einer Werkzeugantwort ohne Fehler (die Antwort darf „keine Abschrift vorhanden“ lauten, solange die App noch keine Abschrift hochlädt; der Inhalt der Ansichten ist S7); Beleg `get_now.md`: Zeitpunkt, Zugriffszeile mit Status 200, Wortlaut der Antwort (ohne Aufgabentexte), Hennings Rückmeldung.
- **AC-18:** Belege vollständig, nichts Geheimes im Repo, Dokumentation aktuell: GIVEN der Belege-PR im loose-ends-Repo WHEN er geöffnet ist THEN enthält der Belegordner `freigaben.md`, `check-outside.sh`, `red.txt`, `green.txt`, `apple-portal.md`, `secrets-namen.txt`, `secrets-scan.txt`, `infra-pr.txt`, `deploy-lokal.txt`, `nginx-t.txt`, `nginx-alt.conf`, `grenzen.txt`, `monitor-vorher.txt`, `monitor-nachher.txt`, `scan.txt`, `verbinden.md`, `cimd.md`, `tuer.md`, `get_now.md`; die Suche aus AC-4 über den Belegordner hat 0 Treffer; die Betrieb-Zeile im `server/`-Abschnitt von `CLAUDE.md` („only `/health` public“) nennt jetzt die geöffneten Pfade, dass `/auth/*` zu bleibt, die Tür (`ALLOWED_APPLE_SUBS` gesetzt) und dass claude.ai seit S6b als Connector verbunden ist, mit Verweis auf den Belegordner; das Board (Karte #621) ist aktuell und #621 hat einen Kommentar mit dem Stand S6b.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `henemm-infra: nginx/loose-ends.henemm.com.conf` | MODIFY | `= /mcp` (Streaming, Zone `loose_ends_mcp`), drei `= /.well-known/…`, `^~ /oauth/` (Zone `loose_ends_oauth`, 64 k), Header wie `/health`, Kopfkommentar; `/auth/` und `/` bleiben 404; bei Bedarf Apple-Verifikationsdatei; ≈ +50/−5 |
| `henemm-infra: scripts/deploy-loose-ends.sh` | MODIFY | `LE_COMMIT` auf den neuen Dienststand (eine Zeile); ≈ +1/−1 |
| `henemm-infra: security/expected-exposure.json` | MODIFY | Host in `tls_hosts`; fünf Einträge in `urls`; ≈ +14 |
| `docs/artifacts/feat-621-s6b-betrieb/` (loose-ends) | CREATE | `check-outside.sh` (≈ 40 Zeilen) und Belege (Text, kein Code) |
| `CLAUDE.md` (loose-ends) | MODIFY | Betrieb-Zeile im `server/`-Abschnitt; ≈ +2/−1 |

Außerhalb des Repos (Handarbeit, nicht versioniert, mit Belegen): Apple-Portal (Services ID, Schlüssel), Server `rennwienix` (`secrets/server.env`, Deploy, nginx-Datei, `reload`), claude.ai (Connector).

### Estimated Changes

- **Dateien: 5 Pfade** (3 Infra, 2 loose-ends; der Belegordner zählt als ein Pfad). Innerhalb des Limits von 4 bis 5 Dateien. Die Belege selbst sind Text und zählen nicht als Code.
- **LoC: ≈ 110 insgesamt** (Infra-Konfiguration ≈ 65, `check-outside.sh` im Belegordner ≈ 40, `CLAUDE.md` ≈ 3), damit innerhalb von ±250 LoC. Kein Dienstcode.
- Keine Permissions in der App, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine Migration, keine neue Abhängigkeit.
- **Seiteneffekte nach außen (explizit):** Der Dienst wird erstmals öffentlich erreichbar (`/mcp`, Discovery, `/oauth/*`); Apple bekommt eine Services ID mit Return-URL auf diesen Host; Hennings Apple-Konto bekommt eine Autorisierung dieser Services ID; es entsteht ein Konto in der Datenbank des Dienstes (Hennings, `accounts` = 1); geteiltes nginx lädt neu (`reload`, kein Neustart, andere Hosts unberührt, `nginx -t` vorher).
- **Parallele Arbeit:** In `henemm-infra` ist nur #381 offen (fremd, Staging-Sweep); vor dem PR `origin/main` und offene PRs erneut prüfen. Im loose-ends-Repo ist `CLAUDE.md` ein Hotspot; vor dem Belege-PR `origin/main` und offene PRs prüfen.

## Risiken

- **Zeitfenster der Tür.** Ohne `ALLOWED_APPLE_SUBS` nimmt der Dienst das erste Konto, das sich anmeldet. Gegenmittel: nginx wird erst geladen, wenn Henning bereitsteht; Verbinden direkt danach (AC-12); danach `accounts` = 1 (AC-14), Liste gesetzt (AC-15), bei mehr als einem Konto sofort Rückgabe der alten nginx-Datei. Alternative (gekippt, siehe unten): erst #615 S4 bauen und die `sub` vorab gewinnen.
- **Issuer falsch.** Ein falscher Host oder ein fehlendes `X-Forwarded-Proto` bricht Discovery, `iss` und Weiterleitungen. Gegenmittel: Header wie `/health`, lokale Probe mit `Host` vor dem Öffnen (AC-6), Prüfung `issuer` exakt (AC-8).
- **Unvollständige Variablen stoppen den Dienst** (`APPLE_*` alle oder keine, OAuth-Schlüssel beide oder keine, Exit 1), das Deploy-Skript lässt dann den Stapel unten. Gegenmittel: Namens-Check vor dem Deploy (AC-4); `PUBLIC_URL` genau gesetzt.
- **Geheimnisse.** Gegenmittel: nur auf dem Server, 700/600, Scan der Belege und Nachrichten nach Wertmustern (AC-4, AC-18); nur der `.p8` wird übertragen, die übrigen Schlüssel entstehen auf dem Server.
- **Geteiltes nginx.** Ein Fehler in der Datei könnte andere Hosts treffen. Gegenmittel: `nginx -t` vor `reload`, alte Datei gesichert, `monitor.sh --status` vorher und nachher (AC-7, AC-10).
- **CIMD-Adresse von claude.ai unbekannt.** `allowFetch` erlaubt nur `https://claude.ai`; die Adresse der gehosteten Oberfläche ist nirgends dokumentiert (nur Claude Codes `https://claude.ai/oauth/claude-code-client-metadata`). Weicht sie ab, ist ein Dienstfix nötig: dann **neuer Dienstschnitt**, nicht hier (AC-13).
- **Apple-Domain-Verifikation.** Foren berichten, dass Apple die Domain per `/.well-known/apple-developer-domain-association.txt` prüfen will, neuere Berichte (2023) richten ohne Verifikation ein; im Portal ablesen (AC-3). Verlangt Apple sie, kommt eine statische `location` für genau diese Datei hinzu (ohne Umleitung, Datei 7 Tage gültig), im selben Infra-PR.
- **Safari-`form_post`-Rückweg.** Apple antwortet per POST-Formular über den Browser; mit Safari (Intelligent Tracking Prevention, Cookie-Regeln für den Interaction-Cookie) nie belegt. Gegenmittel: Verbinden in einem echten Browser (AC-12), nach Möglichkeit in Safari und Chrome. Scheitert Safari, ist das ein Dienstbefund (eigenes Ticket, Cookie-Attribute), kein Grund, den Schnitt zu verwerfen, wenn Chrome läuft.
- **Speicher auf `rennwienix`.** Der Deploy verlangt ≥ 600 MB frei und baut ein Image. Läuft er nicht an, wartet der Schnitt (Henning steuert die parallelen Claude-Sitzungen); kein Eingriff in andere Dienste.
- **Nicht prüfbar live:** die Abweisung eines fremden Apple-Kontos (AC-16); belegt durch die Tests von S6a.
- **Rate-Limits zu eng oder zu weit.** Zu eng würde das Verbinden stören, zu weit nützt nichts. Gegenmittel: Werte nach dem Ablauf eines Verbindens bemessen, AC-9 und AC-12 prüfen beides.

## Test Plan

### Prüfungen von außen (TDD RED, dann GREEN)

Es gibt keinen Dienstcode, also keinen Unit-Test; die Tests sind Prüfungen von außen, die Arbeit beweisen oder widerlegen. Der Kern ist `docs/artifacts/feat-621-s6b-betrieb/check-outside.sh` (ein kleines `curl`-Skript, nur lesend, Zeilen `OK`/`FEHLT` mit Statuscode, Exit 0 nur wenn alles `OK`), dazu `security/expected-exposure.json`, die der Scan der Infra prüft.

**RED (heute, vor jeder Änderung):** Discovery 404, beide Discovery-Pfade 404, Ressourcen-Metadaten 404, `/mcp` 404 statt 401; `/health` 200, `/auth/apple` 404 und `/` 404 sind schon richtig. Das Skript endet mit Exit ≠ 0 (`red.txt`, AC-2).

**GREEN (nach Deploy und nginx):** Discovery 200 mit `issuer` exakt `https://loose-ends.henemm.com`, `openid-configuration` 200 mit demselben Issuer, Ressourcen-Metadaten 200 mit `resource` `https://loose-ends.henemm.com/mcp`, `/mcp` ohne Token 401 mit `WWW-Authenticate` und `resource_metadata`, `/auth/apple` 404, `/` 404, `/health` 200, Exit 0 (`green.txt`, AC-8).

| Prüfung | Beleg | AC |
|---|---|---|
| Freigaben vor der Serverarbeit | `freigaben.md` | AC-1 |
| RED von außen | `red.txt` | AC-2 |
| Apple-Portal (Services ID, Schlüssel, Verifikation) | `apple-portal.md` | AC-3 |
| Geheimnisse nach Namen, Rechte, Scan auf Wertmuster | `secrets-namen.txt`, `secrets-scan.txt` | AC-4 |
| Infra-PR, drei Dateien, CI, `LE_COMMIT` mit `ae957ba` als Vorfahr | `infra-pr.txt` | AC-5 |
| Deploy vor nginx, lokale Health und Discovery mit Host-Header | `deploy-lokal.txt` | AC-6 |
| `nginx -t` vor `reload`, alte Datei gesichert | `nginx-t.txt`, `nginx-alt.conf` | AC-7 |
| GREEN von außen | `green.txt` | AC-8 |
| Streaming-Einstellungen, 413, Limit-Zone | `grenzen.txt` | AC-9 |
| Andere Dienste unverändert | `monitor-vorher.txt`, `monitor-nachher.txt` | AC-10 |
| Externer Scan | `scan.txt` | AC-11 |
| Echtes Verbinden mit Henning, Rückweg im Browser | `verbinden.md` | AC-12 |
| CIMD-Adresse | `cimd.md` | AC-13 |
| `accounts` = 1 direkt nach dem Verbinden | `tuer.md` | AC-14 |
| Liste, Neustart, nicht ausgesperrt | `tuer.md`, `verbinden.md` | AC-15 |
| Fremde Anmeldung (nicht live prüfbar, ehrlich vermerkt) | `tuer.md` | AC-16 |
| `get_now` aus claude.ai | `get_now.md` | AC-17 |
| Vollständigkeit, kein Geheimnis, `CLAUDE.md`, Board | Belege-PR | AC-18 |

- [ ] Test 1 (AC-2): GIVEN unveränderter Stand WHEN `check-outside.sh` THEN Exit ≠ 0, vier Zeilen `FEHLT` mit 404.
- [ ] Test 2 (AC-4): GIVEN `server.env` WHEN Namens-Check und Scan THEN neun Namen gesetzt, Rechte 600/700, 0 Treffer.
- [ ] Test 3 (AC-6): GIVEN Deploy ohne nginx WHEN lokale Probe mit Host-Header THEN 200, `issuer` exakt; von außen weiter 404.
- [ ] Test 4 (AC-7, AC-8): GIVEN `nginx -t` grün und `reload` WHEN `check-outside.sh` THEN Exit 0, alle Zeilen `OK`.
- [ ] Test 5 (AC-9): GIVEN geladene Datei WHEN 100-KiB-POST und 60 Anfragen/s THEN 413 und mindestens ein 429, danach wieder 200.
- [ ] Test 6 (AC-10): GIVEN `monitor.sh --status` vorher und nachher WHEN `diff` THEN keine Zeile eines anderen Dienstes.
- [ ] Test 7 (AC-12, AC-13): GIVEN Henning verbindet WHEN Zugriffszeilen ausgewertet THEN Ablauf bis `/mcp` 200 ohne 5xx, CIMD-Adresse unter `https://claude.ai/`.
- [ ] Test 8 (AC-14, AC-15): GIVEN verbunden WHEN `accounts` gezählt, Liste gesetzt, Neustart THEN 1, 1, Health 200, kein Aussperren.
- [ ] Test 9 (AC-17): GIVEN `get_now` aus claude.ai WHEN Zugriffszeile THEN 200, Werkzeugantwort ohne Fehler.

**Keine UI-Tests:** keine Oberfläche der App. Das Verbinden in claude.ai ist ein Ablauf mit Henning in einer Fremdoberfläche (nicht automatisierbar, Anmeldung mit seiner Apple-ID) und wird deshalb als Beleg mit seiner Rückmeldung plus Zugriffsprotokoll geführt, nicht als manueller Testauftrag nach dem Muster „bitte prüfen“: die Prüfung liegt in den Zugriffszeilen und in der Zählung.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): Erlaubnisliste von Pfaden, Deploy vor nginx, Henning verbindet sofort, danach Liste** | siehe Purpose und Ablauf | nie ein halb offener Zustand; entspricht der bestehenden Haltung der Datei (nur Freigegebenes erreichbar); Fenster der Tür nur Minuten und mit `accounts` = 1 kontrolliert; erfüllt die DoD des Tickets in einem Schnitt | Fenster der Tür, das nicht null ist; zwei Handlungen von Henning in einem Zeitraum | — |
| **B nginx „alles durch außer `/auth/`“** | ein Block `location /` leitet weiter, `/auth/` ist 404 | weniger Pflege, neue Dienstpfade sofort erreichbar | jeder künftige Dienstpfad wäre sofort öffentlich, auch einer, der es nicht sein soll; widerspricht der bestehenden Haltung der Datei | die Haltung „nur Freigegebenes“ der bestehenden Datei; verworfen |
| **C Tür ohne Fenster: erst #615 S4 (App-Anmeldung) bauen, Hennings `sub` dort gewinnen, dann mit fester Liste öffnen** | `ALLOWED_APPLE_SUBS` schon vor dem Öffnen gefüllt, Zweig 2 nie genutzt | kein Zeitfenster | verschiebt die DoD des Tickets um einen ganzen Schnitt (App-Anmeldung, App-Änderung, Gerätestufe nach Geräteliste für `Shared/Intents`-nahe Pfade nicht auszuschließen); das Fenster hier ist Minuten und wird geprüft | keine ADR; verschiebt nur die Reihenfolge von #615 S4 und S6b; nicht empfohlen |
| **D Verbinden ohne Öffnen (Tunnel, Eintrag in `/etc/hosts`)** | keine öffentliche Erreichbarkeit | keine Angriffsfläche | geht nicht: Apple (Rückweg über den Browser, aber die Return-URL und die Domain müssen öffentlich auflösen) und claude.ai (holt Metadaten und Token aus dem Netz von Anthropic) müssen die öffentliche Adresse erreichen | die Erreichbarkeitsannahme; verworfen |
| **E Zusatzschranke: nginx beschränkt `/mcp` und `/oauth/token` auf den Adressbereich von Anthropic (`160.79.104.0/21`)** | Zusatz zu A | weniger Scans auf `/mcp` | schützt die Konto-Anlage nicht (das Konto entsteht im Browser-Rückweg und über `/auth/apple`); Adressbereich kann sich ändern und das Verbinden still brechen | Ergänzung für später (nach #625 prüfen); nicht in diesem Schnitt |

Alternative zu A bleibt offen: Hält Henning das Zeitfenster für zu riskant, wählt der Tech Lead C, ohne dass eine ADR gekippt würde; das Ticket bliebe dann einen Schnitt länger offen. Mit #625 (Veröffentlichung) entfällt die ganze Regel der Tür.

## Out of Scope / Folgeschnitte

- **S7:** Abschrift v2 (Ansichten wie `ViewRules`), damit die vier Ansichten in claude.ai dasselbe wie die App liefern; die DoD des Tickets in diesem Punkt gehört dorthin.
- **#795, #625:** Veröffentlichung, Verzeichnis, Datenschutztext, Ende der Regel der Tür (`ALLOWED_APPLE_SUBS` und Zweig 2 entfallen).
- **#615 S4:** App-Anmeldung über `/auth/*`; bleibt in nginx 404.
- **Aufräumen für Abgewiesene:** Widerruf bei Apple für Abgewiesene und Entfernen ausgegebener Tokens von der Liste genommener Konten (Out of Scope von S6a, unverändert).
- **Zusatzschranke nach Anthropic-Adressbereich:** Alternative E, nach #625 zu prüfen.
- **Dienstfixes, die der Betrieb offenlegt** (abweichende CIMD-Adresse, Safari-Cookie): eigene Dienstschnitte.
- Änderungen an `server/src`, Migrationen, App, Widgets, Watch, Mac: keine.

## Abnahme

Kein Pfad der Geräteliste berührt. (Nur `henemm-infra`, `docs/artifacts/` und `CLAUDE.md`; keine App, kein `project.yml`, keine Entitlements, keine `Info.plist`.) Das Verbinden in claude.ai betrifft Hennings Konto, nicht sein Gerät; es braucht sein „jetzt“ für die gemeinsame Zeit (Schritt 8 im Ablauf), ist aber kein Test auf seinen Geräten im Sinne der Regel. Dasselbe gilt für das Apple-Portal in Chrome auf seinem Mac (Schritt 2): eine Webseite in seinem Browser, kein Installieren, Starten oder Messen auf einem Zielgerät; die Freigabe aus Schritt 0 deckt es ab. Stufe 1 und 2 entfallen als App-Tests (kein App-Code); an ihre Stelle tritt die Abnahme von außen: `check-outside.sh` GREEN, die Zugriffszeilen des echten Verbindens und `accounts` = 1. Stufe 3 entfällt.

## Definition of Done

- [ ] AC-1 bis AC-18 erfüllt, Belege im Belegordner
- [ ] `check-outside.sh` Exit 0 von außen, `monitor.sh --status` für andere Dienste unverändert
- [ ] claude.ai ist als eigener Connector mit Hennings Apple-Konto verbunden, `get_now` antwortet
- [ ] `accounts` = 1, `ALLOWED_APPLE_SUBS` gesetzt, Dienst gesund
- [ ] Kein Geheimniswert in Repo, Belegen, Protokoll oder Nachricht (Scan, 0 Treffer)
- [ ] Infra-PR gemergt (CI grün), Belege-PR gemergt, `CLAUDE.md` (Betrieb-Zeile) aktualisiert
- [ ] #621 kommentiert (Stand S6b, Folge S7), Board-Karte aktuell, Memory geschrieben

## Changelog

- 2026-11-08: Initial spec created (Schnitt 6b)
