---
entity_id: feat-795-schnitt-5b-weckruf-betrieb
type: feature
created: 2026-11-15
updated: 2026-11-15
status: draft
workflow: feat-795-s5b-weckruf-betrieb
---

# Spec: Den Weckruf in Betrieb nehmen, Schnitt S5b (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S5b; das Issue bleibt offen (`Refs #795`, nie `Closes #795`): S5c (die App meldet ihr Token und erkennt den Weckruf) folgt.
Analyse: `docs/context/feat-795-s5b-weckruf-betrieb.md` (Abschnitt „Analysis“: Entscheidung Umgebung, Affected Files, Technical Approach, Risiken, Recherche mit Quellen; verbindlich).
Vorgänger: S5a-1 (`docs/specs/feat-795-schnitt-5a1-geraet-anmelden.md`, `/app/device`, Migration 008), S5a-2a (`docs/specs/feat-795-schnitt-5a2a-apns-absender.md`, Absender), S5a-2b (`docs/specs/feat-795-schnitt-5a2b-weckruf-verdrahten.md`, Weckruf in `storeOrder`); Betriebsvorbild `docs/specs/feat-795-schnitt-1b-nginx.md`.
Es ist ein Betriebsschnitt: **kein Dienstcode in `server/src`**, keine App-Änderung, kein neues Image. Der laufende Dienst (Image `loose-ends-server:9bbb4cd`) enthält den Code bereits; es fehlen nur die Öffnung des Pfades und die Geheimnisse.

## Für den PO

Der Dienst kann ein Gerät kurz anstupsen, wenn Claude einen Auftrag hinterlegt hat, damit die App ihn gleich abholt statt erst beim nächsten Öffnen. Der Code dafür ist schon im Netz, aber ohne Schlüssel von Apple bleibt er stumm. Dieser Schnitt besorgt den Schlüssel, legt ihn sicher auf den Server und öffnet die eine Adresse, über die sich ein Gerät später anmelden wird. Ein erster Probeaufruf an Apple zeigt, dass die Anmeldung gültig ist, ganz ohne dein Gerät.

Von dir brauche ich genau einen Handgriff: Wenn alles bereitsteht, öffne ich das Apple-Entwicklerportal in deinem Browser, und du meldest dich einmal an (Passkey). Den Rest klicke ich. Auf deinen Geräten läuft nichts, und sichtbar ändert sich noch nichts; erst der nächste Schnitt (die App) nutzt es.

## Purpose

`POST /app/device` (S5a-1) fällt von außen heute in `location ^~ /app/ { return 404; }`, und `secrets/server.env` auf `rennwienix` enthält keine `APNS_*`, sodass der Weckruf (`apnsConfigFromEnv` liefert dann keinen Absender) nie sendet. Dieser Schnitt öffnet den Pfad, legt einen APNs-Schlüssel an, hinterlegt ihn und belegt mit einem Probeaufruf an Apple, dass die Anmeldung gilt.

| Teil | Was | Wo |
|---|---|---|
| nginx | `location = /app/device` wie die drei Nachbarn: Zone `loose_ends_app`, `burst=40 nodelay`, `limit_req_status 429`, `client_max_body_size 16k`, `proxy_pass http://127.0.0.1:8780`, dieselben vier Header; der Rest unter `/app/` bleibt 404 | `henemm-infra`: `nginx/loose-ends.henemm.com.conf`, `security/expected-exposure.json` |
| Schlüssel | APNs-Authentifizierungsschlüssel (.p8) im Apple-Portal, Team `XK87E2B3VR`, Topic `com.henning.looseends`; Anlegen nur im Portal (keine API), die Datei lädt Apple genau einmal | Portal, Henning meldet sich nur an |
| Geheimnisse | vier Variablen `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY` (einzeilig mit `\n`), `APNS_TOPIC` in `secrets/server.env`, vorher datierte Sicherung `server.env.bak-<UTC>`, Datei 0600; Kopie der .p8 als `secrets/apns-<keyid>.p8` (0600), lokale Datei nach der Übertragung gelöscht | `rennwienix`, nicht versioniert |
| Probe | `apns-probe.mjs` per stdin in einen Einmal-Container: `apnsConfigFromEnv` und `sendHttp2` aus dem Image, JWT im Skript selbst (`node:crypto`, ES256, `ieee-p1363`), je Host ein erfundenes wohlgeformtes 64-hex-Token; nie `createWaker`, nie Datenbank, nie ein echtes Token | Belegordner |
| Neustart | erst nach bestandener Probe: Geheimnisdatei ersetzen, `deploy-loose-ends.sh` mit demselben Image, `/health` 200, Log ohne `apns config invalid` | `rennwienix` |

**Probe-Erwartung.** Ein erfundenes, wohlgeformtes Token an `api.push.apple.com` und `api.sandbox.push.apple.com`: Apple prüft zuerst die Anmeldung. 400 `BadDeviceToken` heißt, Schlüssel, Team und Kennung sind gültig und nur das Token ist falsch oder aus der anderen Umgebung; 403 `InvalidProviderToken` heißt, die Anmeldung ist falsch (Fehler, Schnitt hält an). Beim Fallback (c, nur Production) gilt: production 400, sandbox 403, so belegt. Quellen: Apple, „Establishing a token-based connection to APNs“ (https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns); Apple-Forum https://developer.apple.com/forums/thread/689857.

**Warum die Probe vor dem Neustart.** `main.ts` beendet den Start bei halber oder ungültiger Konfiguration mit `apns config invalid: <Variable>` und Exit 1. Mit einer kaputten Datei geriete der kritische Dienst (Monitor „kritisch“) in eine Startschleife. Die Probe läuft deshalb gegen eine Kandidatendatei in einem Einmal-Container (`docker compose run --rm --no-deps -T`), der laufende Dienst bleibt unberührt.

**Warum die Probe `createWaker` nie ruft.** `createWaker` löscht bei 400 `BadDeviceToken` die Zeile über `dropToken`; die Probe würde mit einem erfundenen Token zwar nichts Echtes treffen, aber sie soll auch nie die Datenbank berühren.

**Regeln vor Modell:** Betrieb, Netz und Sicherheit ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR. Der Schnitt setzt ADR-21 (Dienst für Claude, Weg B) und die Festlegungen der Specs S5a-1 bis S5a-2b um und ändert sie nicht; kein neues Verfahren, keine neue Abhängigkeit, keine Migration, kein Dienstcode.
- **Rationale:** „Ein Schlüssel für beide Hosts“ folgt aus der einen Konfiguration in S5a-2a (genau ein Satz von vier `APNS_*`, Ursprung je Umgebung des Geräts, AC-6 dort). Fiele sie (Alternative b, zwei Schlüssel), wäre das eine Änderung dieser Festlegung in `apns.ts`/`main.ts` und ein eigener Dienstschnitt, aber keine ADR. Die Wahl der Umgebung des Schlüssels ist Betrieb, keine Architektur.

## Source

- **File:** `henemm-infra: nginx/loose-ends.henemm.com.conf`
- **Identifier:** nginx-Block `location = /app/device`; Verhalten dahinter: `/app/device` in `server/src/app-routes.ts` und `server/src/devices.ts`, Absender `apnsConfigFromEnv`, `sendHttp2`, `createWaker` in `server/src/apns.ts` (alle unverändert)

**Dateien (Infra-Repo `henemm/henemm-infra`):** `nginx/loose-ends.henemm.com.conf`, `security/expected-exposure.json` (nebst zugehörigem Test, falls er die Liste prüft).
**Dateien (loose-ends):** `docs/artifacts/feat-795-s5b-weckruf-betrieb/` (neu: `check-device.sh`, `apns-probe.mjs` und Belege), `docs/reference/claude-abschrift-vertrag.md` (Abschnitt „Wege der App“), `CLAUDE.md` (Abschnitt `server/`, Betrieb), diese Spec.
**Außerhalb der Repos (Handarbeit, nicht versioniert, mit Belegen):** Apple-Portal (Schlüssel), `rennwienix` (`secrets/server.env`, `secrets/apns-<keyid>.p8`, nginx-Datei, `reload`, Neustart per Deploy-Skript).
**Kein Dienstcode, keine App:** `server/src`, `server/test`, Migrationen, `project.yml`, `LooseEnds/` bleiben unberührt (`apns.ts` bekommt keinen Export nur fürs Betriebsskript). Wird beim Betrieb ein Dienstfehler sichtbar, wird der Schnitt angehalten; der Fix ist ein eigener Schnitt.

### Schnittstelle und Festlegungen

- **Umgebung des Schlüssels (Tech Lead, Analyse):** (a) ein team-scoped Schlüssel „Sandbox & Production“. Bietet das Portal beim Anlegen nur eine Umgebung an, gilt Fallback (c): nur Production (Hennings Alltag ist TestFlight, also `production`; Xcode- und Simulatorläufe holen weiter bei Start und Vordergrund). Vor dem Anlegen werden vorhandene APNs-Schlüssel gezählt (Apple erlaubt höchstens zwei je Umgebung); ist das Limit erreicht, wird nichts widerrufen, der Schnitt hält an und meldet es.
- **Statuscodes von `/app/device`** (Dienst, S5a-1): 405 für Nicht-POST, 401 ohne Bearer oder bei unbekannter Sitzung, 400 ohne `X-Device`, nackte Statuscodes mit `cache-control: no-store`. Ohne Sitzung ist die Öffnung deshalb mit 401 belegbar.
- **Körpergrenze:** `client_max_body_size 16k` genügt (Token höchstens 200 Hexzeichen plus Umgebung); die Nachbarn haben 256k, das Limit des Dienstes bleibt unverändert.
- **`check-device.sh`** (Vorlage `docs/artifacts/feat-795-s1b-nginx/check-app.sh`): `curl`, ohne Geheimnisse, ohne `Authorization`-Kopf, Ausgabe zeilenweise `OK`/`FEHLT` mit Statuscode, Exit 0 nur, wenn alles `OK` und kein 429 kam; **genau sechs Anfragen, keine Schleifen**: `POST /app/device` ohne Bearer (401), `GET /app/device` (405), `POST /app/device` mit 20-KiB-Körper (413, von nginx, ohne Sitzung), `GET /app/x` (404, der Rest bleibt zu), `POST /app/transcript` ohne Bearer (401, Nachbar unverändert), `GET /app/orders/claim` (405, Nachbar unverändert). Schlusszeilen: Zahl der Anfragen, „429 gesehen: ja/nein“, Zeitpunkt.
- **`apns-probe.mjs`:** liest die vier Variablen aus der Umgebung des Containers, prüft vor dem Senden Vorhandensein und Form (Schlüssel beginnt mit `-----BEGIN PRIVATE KEY-----` nach dem Ersetzen von `\n`, keine echten Zeilenumbrüche im Wert), gibt **nur** Variablennamen, Längen, Hostnamen, Statuscodes und den `reason` von Apple aus (nie einen Wert, nie das JWT, nie das Token); Exit 0 nur, wenn jeder erwartete Status eintrat.
- **Geheimnisse:** nie im Repo, Beleg, Protokoll oder in einer Nachricht; die .p8 wird sofort nach dem Laden auf `rennwienix` übertragen und lokal gelöscht; Sicherung der Geheimnisdatei als `server.env.bak-<UTC>` mit Rechten 0600; Werte nie auf der Befehlszeile (Übergabe per stdin oder Datei).
- **Nur `systemctl reload nginx`**, nie Neustart von nginx; der Dienst wird einmal über `scripts/deploy-loose-ends.sh` mit demselben `LE_COMMIT` neu gestartet (kurzer Ausfall des kritischen Dienstes, vorher und nachher `monitor.sh --status`).
- **Commit-Gate im Infra-Klon:** verlangt vor dem Adversary Hennings `override` (Erfahrung aus S6b, S4d, S1b); wird eingeplant, nicht umgangen. Git im Infra-Repo über die gh-API wegen des Worktree-Guards.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| Dienst mit `/app/device`, `device_tokens` und Absender live (S5a-1 bis S5a-2b, Image `loose-ends-server:9bbb4cd`) | bestehend |
| nginx 1.24.0 auf `rennwienix`, Datei `nginx/loose-ends.henemm.com.conf`, Zone `loose_ends_app` (S1b) | bestehend |
| fail2ban-Jail `nginx-limit-req` (`maxretry 10`, `findtime 10m`, `bantime 1h`, henemm-infra#397) | bestehend, unverändert; das Skript sendet sechs Anfragen |
| Apple-Entwicklerportal, Team `XK87E2B3VR`, Topic `com.henning.looseends`; APNs HTTP/2 (`api.push.apple.com`, `api.sandbox.push.apple.com`) | extern; Hennings Anmeldung (Passkey) |
| `scripts/deploy-loose-ends.sh`, `docker compose` auf `rennwienix`, Infra-Repo: `python3 -m pytest tests -q`, `security/check-external-exposure.sh`, `monitor.sh --status` | bestehend |
| Downstream | S5c (App meldet Token samt Umgebung, erkennt `looseends`; Hennings TestFlight-Geräte melden `production`, S5c prüft das gegen `aps-environment`); Datenschutztext als Vorbedingung für S5c bleibt unberührt |

## Acceptance Criteria

Belege liegen unter `docs/artifacts/feat-795-s5b-weckruf-betrieb/` (im Folgenden „Belegordner“). Kein Beleg enthält einen Geheimniswert; Ausgaben zeigen nur Namen, Längen, Statuscodes und Zählungen.

- **AC-1:** RED des Prüfskripts: GIVEN `check-device.sh` WHEN es vor der nginx-Änderung gegen `https://loose-ends.henemm.com` läuft THEN endet es mit Exit ≠ 0, und `red.txt` zeigt `FEHLT` mit 404 für `POST /app/device` ohne Sitzung (erwartet 401), `GET /app/device` (erwartet 405) und den 20-KiB-Körper (erwartet 413); `GET /app/x` (404) und die zwei Nachbarzeilen sind `OK`; die Datei nennt genau sechs gesendete Anfragen. Zusätzlich `monitor-vorher.txt` (Ausgabe von `monitor.sh --status` vor Beginn der Serverarbeit).
- **AC-2:** nginx öffnet genau einen weiteren Pfad: GIVEN die Datei `nginx/loose-ends.henemm.com.conf` WHEN der Auszug des Server-Blocks aus `nginx -T` gelesen wird THEN enthält er `location = /app/device` mit `limit_req zone=loose_ends_app burst=40 nodelay`, `limit_req_status 429`, `client_max_body_size 16k`, `proxy_pass http://127.0.0.1:8780` und den vier Headern `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`; die drei Nachbarblöcke (`/app/transcript`, `/app/orders/claim`, `/app/orders/result`) und die Zone `loose_ends_app` (`rate=10r/s`) sind unverändert, es gibt unter `/app/` keine Streaming-Einstellung, und `location ^~ /app/ { return 404; }` besteht weiter (Beleg `nginx-dump.txt` mit Vergleich zu `nginx-alt.conf`).
- **AC-3:** Infra-PR: GIVEN der PR in `henemm/henemm-infra` WHEN er geöffnet ist THEN ändert er nur `nginx/loose-ends.henemm.com.conf` und `security/expected-exposure.json` (und einen vorhandenen Test, falls die Liste dort geprüft wird); die JSON-Datei enthält `/app/device` mit GET → 405; `python3 -m pytest tests -q` im Wegwerfklon auf `rennwienix` ist grün (Beleg `infra-pr.txt`: PR-Nummer, Kennungen, Teststand; hat das Repo keine CI, steht das dort ausdrücklich).
- **AC-4:** nginx wird nur nach Test geladen, mit Rückweg: GIVEN die neue Datei auf dem Server WHEN sie in Kraft gesetzt wird THEN ist die alte Datei vorher gesichert (`nginx-alt.conf` im Belegordner, Ort auf dem Server genannt), `nginx -t` zeigt `syntax is ok` und `test is successful`, und `systemctl reload nginx` (kein Neustart) läuft erst danach mit Exit 0 (Beleg `nginx-test.txt` mit Textfolge; bei Fehler wird nicht geladen).
- **AC-5:** Öffnung von außen, GREEN: GIVEN nginx ist geladen WHEN `check-device.sh` von außen läuft THEN Exit 0 und `green.txt` zeigt `OK` mit `POST /app/device` ohne Sitzung 401, `GET` 405, 20-KiB-Körper 413 (ohne `Authorization`-Kopf, also von nginx und nicht vom Dienst), `GET /app/x` 404 und die zwei Nachbarzeilen unverändert; die Schlusszeilen nennen genau sechs gesendete Anfragen und `429 gesehen: nein`.
- **AC-6:** Exposure-Prüfung ohne Abweichung: GIVEN `security/expected-exposure.json` aus AC-3 WHEN `check-external-exposure.sh` läuft THEN meldet es keine Abweichung (Beleg `scan.txt`); läuft der Scan nur nachts und ist nicht vorziehbar, nennt der Beleg den Zeitpunkt des nächsten Laufs und `todo-scan.md` im Belegordner, den der Tech Lead beim nächsten Sitzungsstart prüft, nie Henning.
- **AC-7:** Schlüssel angelegt, Umgebung belegt: GIVEN das Apple-Portal, in dem Henning sich angemeldet hat WHEN der APNs-Schlüssel angelegt ist THEN nennt `portal.md` im Belegordner die Zahl der vorher vorhandenen APNs-Schlüssel, die Schlüsselkennung (`APNS_KEY_ID`, keine Geheimnisse), das Team `XK87E2B3VR`, das Topic `com.henning.looseends` und die Umgebung des Schlüssels (a: „Sandbox & Production“ oder, falls das Portal nur eine anbot, c: „Production“ mit dem Wortlaut der Portal-Auswahl); außerdem steht dort, dass die .p8 auf `rennwienix` übertragen und die lokale Kopie danach gelöscht wurde (Prüfung: die Datei existiert lokal nicht mehr, `ls`-Ausgabe im Beleg).
- **AC-8:** Probe vor dem Neustart: GIVEN die Kandidatengeheimnisdatei auf `rennwienix` und der laufende Dienst unberührt WHEN `apns-probe.mjs` per stdin in einem Einmal-Container (`docker compose run --rm --no-deps -T`) läuft THEN meldet `probe-vorher.txt` für beide Hosts je 400 `BadDeviceToken` (Fall a); im Fall c steht dort production 400 `BadDeviceToken` und sandbox 403 `InvalidProviderToken`, ausdrücklich als erwartet bezeichnet; die Ausgabe enthält nur Variablennamen mit Länge und „vorhanden“, Hostnamen, Statuscodes und `reason`; der Beleg zeigt außerdem, dass `/health` des laufenden Dienstes währenddessen 200 blieb und dass die Probe weder `createWaker` noch die Datenbank berührt (Skript enthält beides nicht, `grep` im Beleg).
- **AC-9:** Dienst mit Schlüssel, ohne Startschleife: GIVEN AC-8 bestanden WHEN `secrets/server.env` (vorher gesichert als `server.env.bak-<UTC>`, Rechte 0600, Datei unverändert bis auf die vier `APNS_*`) ersetzt und `deploy-loose-ends.sh` mit demselben Image ausgeführt ist THEN zeigt `betrieb.txt` die Namen der gesicherten Datei und die Rechte (`0600`), `/health` 200 innerhalb von 60 s nach dem Start, im Log des Dienstes kein `apns config invalid`, und die vier Variablen als „vorhanden“ mit Länge (nie Werte); bei Fehler steht der Rückweg im Beleg (gesicherte Datei zurück, Deploy erneut), und der Schnitt hält an.
- **AC-10:** Erster echter Aufruf an Apple mit dem laufenden Stand: GIVEN der Dienst läuft mit den `APNS_*` WHEN die Probe aus AC-8 mit der Konfiguration des laufenden Containers wiederholt wird THEN zeigt `probe-nachher.txt` dasselbe Ergebnis wie `probe-vorher.txt`; `monitor-nachher.txt` zeigt `loose-ends` als `OK`, und `diff` von `monitor-vorher.txt` und `monitor-nachher.txt` enthält keine Zeile eines anderen Dienstes mit Zustandswechsel (Zeit- und Laufzeitangaben ausgenommen).
- **AC-11:** Vertrag aktuell: GIVEN `docs/reference/claude-abschrift-vertrag.md` WHEN der Abschnitt „Wege der App“ gelesen wird THEN steht dort nicht mehr „von außen erst ab S5b“ für `/app/device`, sondern dass der Pfad seit S5b offen ist und die Zone `loose_ends_app` (10 Anfragen je Sekunde, Stoß 40, bei Überschreitung 429) auch für `/app/device` gilt, mit der bestehenden Abbruchregel bei 429; der Vertrag enthält weiterhin genau drei ```json-Blöcke (`grep -c '^```json'` ergibt 3; die Tests von `server/test/orders.test.ts` lesen genau drei).
- **AC-12:** `CLAUDE.md` und Belege vollständig: GIVEN der Doku-PR WHEN er geöffnet ist THEN nennt `CLAUDE.md` im Abschnitt `server/` (Betrieb und Absatz `src/apns.ts`/`src/devices.ts`) `/app/device` seit S5b in der Liste der offenen Pfade (Zone `loose_ends_app`, 16k), den Weckruf als aktiv mit gesetzten `APNS_*` und die Umgebung des Schlüssels (a oder c) samt Hinweis, dass S5c die App liefert; der Belegordner enthält `check-device.sh`, `apns-probe.mjs`, `red.txt`, `green.txt`, `nginx-alt.conf`, `nginx-dump.txt`, `nginx-test.txt`, `infra-pr.txt`, `scan.txt`, `portal.md`, `probe-vorher.txt`, `betrieb.txt`, `probe-nachher.txt`, `monitor-vorher.txt`, `monitor-nachher.txt`; die Suche nach Wertmustern (`-----BEGIN` mit folgendem Schlüsselkörper, `Bearer ` mit Wert, `"d":`, `APNS_PRIVATE_KEY=` mit Wert) ergibt 0 Treffer; die Karte #795 ist aktuell und #795 hat einen Kommentar mit dem Stand S5b (Folge S5c).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `henemm-infra: nginx/loose-ends.henemm.com.conf` | MODIFY | `location = /app/device` wie die Nachbarn, Kopfkommentar; ≈ +12/−1 |
| `henemm-infra: security/expected-exposure.json` | MODIFY | ein Eintrag (`/app/device` GET → 405); ≈ +1/−0 |
| `docs/artifacts/feat-795-s5b-weckruf-betrieb/` (loose-ends) | CREATE | `check-device.sh` (≈ 35 Zeilen), `apns-probe.mjs` (≈ 55 Zeilen) und Belege (Text) |
| `docs/reference/claude-abschrift-vertrag.md` (loose-ends) | MODIFY | `/app/device` offen, Zone gilt auch dafür; ≈ +5/−2 |
| `CLAUDE.md` (loose-ends) | MODIFY | Betrieb und Absatz `server/`; ≈ +4/−2 |
| `docs/specs/feat-795-schnitt-5b-weckruf-betrieb.md` (loose-ends) | CREATE | diese Spec |

Außerhalb der Repos: Apple-Portal, `secrets/server.env`, `secrets/apns-<keyid>.p8`, nginx-Datei und Neustart auf `rennwienix` (Handarbeit mit Belegen).

### Estimated Changes

- **Dateien: 5 in diesem Repo** (`check-device.sh`, `apns-probe.mjs`, Vertrag, `CLAUDE.md`, diese Spec; die übrigen Belege sind Ausgaben ohne Code). Dazu 2 im Infra-Repo, das einen eigenen PR mit eigener Prüfung bekommt (wie in S1b und #615 S4d). Je Repo innerhalb des Limits von 4 bis 5 Dateien; beide Teile hängen zusammen (Öffnung und Schlüssel sind ein Betriebsschritt), ein Teilen brächte nur einen zweiten Monitor- und Belegdurchlauf.
- **LoC: ≈ +130 / −5** (Skripte ≈ 90, Doku ≈ 25, nginx und JSON ≈ 15), innerhalb von ±250 LoC. Kein Dienstcode.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine Migration, keine neue Abhängigkeit.
- **Seiteneffekte nach außen (explizit):** ein weiterer Pfad am Live-Dienst wird öffentlich erreichbar (ohne gültige Sitzung nackte Statuscodes); geteiltes nginx lädt neu (`reload`, `nginx -t` vorher); der Live-Dienst wird einmal neu gestartet (kurzer Ausfall, Probe vorher); Apple erhält erfundene Test-Pushes mit nicht existierenden Tokens (kein Gerät betroffen); ein APNs-Schlüssel entsteht im Apple-Konto.
- **Parallele Arbeit:** vor jedem PR `origin/main` und offene PRs in beiden Repos erneut prüfen; `CLAUDE.md` ist Hotspot.

## Risiken

- **Neustart des kritischen Dienstes** (Monitor „kritisch“). Gegenmittel: Probe vorher im Einmal-Container (AC-8), gesicherte Geheimnisdatei mit Rückweg, `/health` und Log nach dem Start (AC-9), Monitor vorher und nachher.
- **Startschleife durch ungültigen Schlüssel** (`apns config invalid`, Exit 1). Gegenmittel: dieselbe Probe plus Formprüfung des Schlüsselwerts (einzeilig mit `\n`) vor dem Ersetzen.
- **.p8 nur einmal ladbar.** Gegenmittel: sofortige Übertragung auf `rennwienix` (`secrets/apns-<keyid>.p8`, 0600) vor jeder weiteren Handlung, lokale Kopie danach gelöscht (AC-7). Ein verlorener Schlüssel wäre durch einen neuen ersetzbar, solange das Limit von zwei je Umgebung es erlaubt.
- **Umgebung des Schlüssels.** Bietet das Portal nur eine Umgebung an, bekäme die andere 403. Fallback (c) deckt Hennings Alltag (TestFlight = `production`); Sandbox-Geräte werden dann nicht geweckt und holen weiter bei Start und Vordergrund. Alternative (b) bleibt offen.
- **Geheimnisse in Ausgaben.** Gegenmittel: Skripte geben nur Namen, Längen, Statuscodes aus; Wertscan über den Belegordner (AC-12).
- **fail2ban.** Gegenmittel: `check-device.sh` mit genau sechs Anfragen, gemeinsame Zone mit Stoß 40.
- **Henning-Anmeldung im Portal.** Alles andere ist vorher fertig (nginx, Kandidatendatei-Vorbereitung, Skripte), damit er nicht wartet; sein einziger Handgriff ist die Anmeldung per Passkey.
- **Belegkraft.** Die Probe belegt gültige Anmeldung bei Apple, nicht die Zustellung an ein echtes Gerät; die kommt mit S5c und der TestFlight-Rückmeldung.
- **Commit-Gate im Infra-Klon** verlangt vor dem Adversary Hennings `override`; wird eingeplant, nicht umgangen.

## Test Plan

Es gibt keinen Dienstcode und keine App-Änderung, also keine neuen Unit- oder UI-Tests. Die Prüfungen sind Außenprüfung, Probe gegen Apple, Infra-Tests und Dateiinhalte.

| Prüfung | Beleg | AC |
|---|---|---|
| `check-device.sh` RED vor der nginx-Änderung, Monitor vorher | `red.txt`, `monitor-vorher.txt` | AC-1 |
| `nginx -T`-Auszug, Infra-PR, Tests | `nginx-dump.txt`, `infra-pr.txt` | AC-2, AC-3 |
| `nginx -t` vor `reload`, alte Datei gesichert | `nginx-test.txt`, `nginx-alt.conf` | AC-4 |
| `check-device.sh` GREEN von außen | `green.txt` | AC-5 |
| Exposure-Prüfung | `scan.txt` | AC-6 |
| Schlüssel im Portal, Übertragung | `portal.md` | AC-7 |
| Probe vor dem Neustart | `probe-vorher.txt` | AC-8 |
| Neustart, `/health`, Log | `betrieb.txt` | AC-9 |
| Probe danach, Monitor nachher | `probe-nachher.txt`, `monitor-nachher.txt` | AC-10 |
| Vertrag, `CLAUDE.md`, Vollständigkeit, Wertscan, Board | Doku-PR (`grep`) | AC-11, AC-12 |

- [ ] Test 1 (AC-1): GIVEN unveränderter Stand WHEN `check-device.sh` THEN Exit ≠ 0, `FEHLT` mit 404 an `/app/device`.
- [ ] Test 2 (AC-2, AC-3): GIVEN die neue Datei WHEN `nginx -T` gelesen und `python3 -m pytest tests -q` im Infra-Klon läuft THEN `location = /app/device` mit Zone und 16k, Tests grün.
- [ ] Test 3 (AC-4, AC-5): GIVEN die neue Datei WHEN `nginx -t` und danach `reload`, dann `check-device.sh` THEN `test is successful`, Exit 0, sechs Anfragen, kein 429.
- [ ] Test 4 (AC-8): GIVEN die Kandidatengeheimnisdatei WHEN die Probe im Einmal-Container läuft THEN 400 `BadDeviceToken` an beiden Hosts (Fall c: production 400, sandbox 403), keine Werte in der Ausgabe.
- [ ] Test 5 (AC-9, AC-10): GIVEN der Neustart mit den `APNS_*` WHEN `/health`, Log und Probe wiederholt THEN 200, kein `apns config invalid`, gleiche Probe-Ergebnisse, Monitor `OK`.
- [ ] Test 6 (AC-11, AC-12): GIVEN der Doku-PR WHEN `grep -c '^```json'` und der Wertscan laufen THEN 3 und 0 Treffer.

**Ehrlich zur Belegkraft:** AC-1 bis AC-6 belegen nur die Öffnung des Pfades. AC-7 bis AC-10 belegen, dass Apple die Anmeldung des Dienstes akzeptiert und der Dienst mit ihr stabil läuft. Ob ein Weckruf ein echtes Gerät erreicht, belegen erst S5c und Hennings TestFlight-Rückmeldung.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **(a) gewählt: ein team-scoped Schlüssel „Sandbox & Production“, kein Code** | ein Schlüssel für beide Hosts | passt zum Code (S5a-2a: eine Konfiguration für beide Hosts); Production und Sandbox-Läufe werden geweckt; nur ein Geheimnissatz | Apple empfiehlt getrennte Schlüssel je Umgebung; ob das Portal ihn für neue Schlüssel noch anbietet, zeigt erst die Seite | nichts |
| **Fallback (c): nur Production, kein Code** | Schlüssel nur für Production; Sandbox-Geräte (Xcode, Simulator) holen weiter bei Start und Vordergrund | deckt Hennings Alltag (TestFlight = `production`); gilt, wenn das Portal nur eine Umgebung anbietet | Sandbox-Weckrufe entfallen, sandbox an Apple liefert 403 | nichts |
| **(b) zwei Schlüssel, je Umgebung** | zweiter Variablensatz, je Host ein Schlüssel (~30 LoC in `apns.ts`/`main.ts`, eigener Dienstschnitt) | Apples Empfehlung; Sandbox und Production sauber getrennt | Code, Tests und Neustart statt reinem Betrieb; ein zweiter Geheimnissatz | die eine Konfiguration für beide Hosts aus S5a-2a (`docs/specs/feat-795-schnitt-5a2a-apns-absender.md`), keine ADR |

## Out of Scope / Folgeschnitte

- **S5c:** die App meldet Token und Umgebung (`POST /app/device`), erkennt den Weckruf (`looseends`), Datenschutztext als Vorbedingung; Gerätepunkte stehen dort.
- **Alternative (b)** (zwei Schlüssel): eigener Dienstschnitt, nur wenn Sandbox-Weckrufe gebraucht werden.
- **Dienstfixes, die der Betrieb offenlegt:** eigene Schnitte.
- Änderungen an `server/src`, Migrationen, App, Widgets, Watch, Mac: keine. Nichts auf Hennings Geräten.

## Abnahme

Der Schnitt berührt keinen Pfad der Geräteliste (nur `henemm-infra`, `docs/artifacts/`, `docs/reference/`, `CLAUDE.md`, Spec; kein `project.yml`, keine Entitlements, keine `Info.plist`; `server/` ohne Codeänderung). Stufe 1 ist die Infra-Testsuite plus Dateiprüfungen, Stufe 2 die Abnahme von außen (`check-device.sh` GREEN, Exposure-Prüfung) und die Probe gegen Apple. Der Abschlussbericht sagt: „Kein Pfad der Geräteliste berührt.“ Gerätepunkte gibt es in diesem Schnitt nicht.

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt, Belege im Belegordner
- [ ] `check-device.sh` Exit 0 von außen, beide Probe-Läufe wie erwartet, `monitor.sh --status` für andere Dienste unverändert
- [ ] Infra-PR gemergt, Doku-PR gemergt (mit `Refs #795`), `CLAUDE.md` und Vertrag aktualisiert
- [ ] Kein Geheimniswert in Repo, Belegen, Protokoll oder Nachricht (Scan, 0 Treffer); lokale .p8 gelöscht
- [ ] #795 kommentiert (Stand S5b, Folge S5c), Board-Karte aktuell, Memory geschrieben

## Changelog

- 2026-11-15: Initial spec created (Schnitt S5b)
