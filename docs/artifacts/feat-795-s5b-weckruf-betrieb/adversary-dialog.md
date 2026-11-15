# Adversary Dialog — feat-795-s5b-weckruf-betrieb
Spec: docs/specs/feat-795-schnitt-5b-weckruf-betrieb.md
Datum: 2026-11-15 18:58

## Checkliste
- [x] **AC-1:** RED des Prüfskripts: GIVEN `check-device.sh` WHEN es vor der nginx-Änderung gegen `https://loose-ends.henemm.com` läuft THEN endet es mit Exit ≠ 0, und `red.txt` zeigt `FEHLT` mit 404 für `POST /app/device` ohne Sitzung (erwartet 401), `GET /app/device` (erwartet 405) und den 20-KiB-Körper (erwartet 413); `GET /app/x` (404) und die zwei Nachbarzeilen sind `OK`; die Datei nennt genau sechs gesendete Anfragen. Zusätzlich `monitor-vorher.txt` (Ausgabe von `monitor.sh --status` vor Beginn der Serverarbeit).
- [x] **AC-2:** nginx öffnet genau einen weiteren Pfad: GIVEN die Datei `nginx/loose-ends.henemm.com.conf` WHEN der Auszug des Server-Blocks aus `nginx -T` gelesen wird THEN enthält er `location = /app/device` mit `limit_req zone=loose_ends_app burst=40 nodelay`, `limit_req_status 429`, `client_max_body_size 16k`, `proxy_pass http://127.0.0.1:8780` und den vier Headern `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`; die drei Nachbarblöcke (`/app/transcript`, `/app/orders/claim`, `/app/orders/result`) und die Zone `loose_ends_app` (`rate=10r/s`) sind unverändert, es gibt unter `/app/` keine Streaming-Einstellung, und `location ^~ /app/ { return 404; }` besteht weiter (Beleg `nginx-dump.txt` mit Vergleich zu `nginx-alt.conf`).
- [?] **AC-3:** Infra-PR: GIVEN der PR in `henemm/henemm-infra` WHEN er geöffnet ist THEN ändert er nur `nginx/loose-ends.henemm.com.conf` und `security/expected-exposure.json` (und einen vorhandenen Test, falls die Liste dort geprüft wird); die JSON-Datei enthält `/app/device` mit GET → 405; `python3 -m pytest tests -q` im Wegwerfklon auf `rennwienix` ist grün (Beleg `infra-pr.txt`: PR-Nummer, Kennungen, Teststand; hat das Repo keine CI, steht das dort ausdrücklich).
- [x] **AC-4:** nginx wird nur nach Test geladen, mit Rückweg: GIVEN die neue Datei auf dem Server WHEN sie in Kraft gesetzt wird THEN ist die alte Datei vorher gesichert (`nginx-alt.conf` im Belegordner, Ort auf dem Server genannt), `nginx -t` zeigt `syntax is ok` und `test is successful`, und `systemctl reload nginx` (kein Neustart) läuft erst danach mit Exit 0 (Beleg `nginx-test.txt` mit Textfolge; bei Fehler wird nicht geladen).
- [x] **AC-5:** Öffnung von außen, GREEN: GIVEN nginx ist geladen WHEN `check-device.sh` von außen läuft THEN Exit 0 und `green.txt` zeigt `OK` mit `POST /app/device` ohne Sitzung 401, `GET` 405, 20-KiB-Körper 413 (ohne `Authorization`-Kopf, also von nginx und nicht vom Dienst), `GET /app/x` 404 und die zwei Nachbarzeilen unverändert; die Schlusszeilen nennen genau sechs gesendete Anfragen und `429 gesehen: nein`.
- [x] **AC-6:** Exposure-Prüfung ohne Abweichung: GIVEN `security/expected-exposure.json` aus AC-3 WHEN `check-external-exposure.sh` läuft THEN meldet es keine Abweichung (Beleg `scan.txt`); läuft der Scan nur nachts und ist nicht vorziehbar, nennt der Beleg den Zeitpunkt des nächsten Laufs und `todo-scan.md` im Belegordner, den der Tech Lead beim nächsten Sitzungsstart prüft, nie Henning.
- [x] **AC-7:** Schlüssel angelegt, Umgebung belegt: GIVEN das Apple-Portal, in dem Henning sich angemeldet hat WHEN der APNs-Schlüssel angelegt ist THEN nennt `portal.md` im Belegordner die Zahl der vorher vorhandenen APNs-Schlüssel, die Schlüsselkennung (`APNS_KEY_ID`, keine Geheimnisse), das Team `XK87E2B3VR`, das Topic `com.henning.looseends` und die Umgebung des Schlüssels (a: „Sandbox & Production“ oder, falls das Portal nur eine anbot, c: „Production“ mit dem Wortlaut der Portal-Auswahl); außerdem steht dort, dass die .p8 auf `rennwienix` übertragen und die lokale Kopie danach gelöscht wurde (Prüfung: die Datei existiert lokal nicht mehr, `ls`-Ausgabe im Beleg).
- [x] **AC-8:** Probe vor dem Neustart: GIVEN die Kandidatengeheimnisdatei auf `rennwienix` und der laufende Dienst unberührt WHEN `apns-probe.mjs` per stdin in einem Einmal-Container (`docker compose run --rm --no-deps -T`) läuft THEN meldet `probe-vorher.txt` für beide Hosts je 400 `BadDeviceToken` (Fall a); im Fall c steht dort production 400 `BadDeviceToken` und sandbox 403 `InvalidProviderToken`, ausdrücklich als erwartet bezeichnet; die Ausgabe enthält nur Variablennamen mit Länge und „vorhanden“, Hostnamen, Statuscodes und `reason`; der Beleg zeigt außerdem, dass `/health` des laufenden Dienstes währenddessen 200 blieb und dass die Probe weder `createWaker` noch die Datenbank berührt (Skript enthält beides nicht, `grep` im Beleg).
- [x] **AC-9:** Dienst mit Schlüssel, ohne Startschleife: GIVEN AC-8 bestanden WHEN `secrets/server.env` (vorher gesichert als `server.env.bak-<UTC>`, Rechte 0600, Datei unverändert bis auf die vier `APNS_*`) ersetzt und `deploy-loose-ends.sh` mit demselben Image ausgeführt ist THEN zeigt `betrieb.txt` die Namen der gesicherten Datei und die Rechte (`0600`), `/health` 200 innerhalb von 60 s nach dem Start, im Log des Dienstes kein `apns config invalid`, und die vier Variablen als „vorhanden“ mit Länge (nie Werte); bei Fehler steht der Rückweg im Beleg (gesicherte Datei zurück, Deploy erneut), und der Schnitt hält an.
- [?] **AC-10:** Erster echter Aufruf an Apple mit dem laufenden Stand: GIVEN der Dienst läuft mit den `APNS_*` WHEN die Probe aus AC-8 mit der Konfiguration des laufenden Containers wiederholt wird THEN zeigt `probe-nachher.txt` dasselbe Ergebnis wie `probe-vorher.txt`; `monitor-nachher.txt` zeigt `loose-ends` als `OK`, und `diff` von `monitor-vorher.txt` und `monitor-nachher.txt` enthält keine Zeile eines anderen Dienstes mit Zustandswechsel (Zeit- und Laufzeitangaben ausgenommen).
- [x] **AC-11:** Vertrag aktuell: GIVEN `docs/reference/claude-abschrift-vertrag.md` WHEN der Abschnitt „Wege der App“ gelesen wird THEN steht dort nicht mehr „von außen erst ab S5b“ für `/app/device`, sondern dass der Pfad seit S5b offen ist und die Zone `loose_ends_app` (10 Anfragen je Sekunde, Stoß 40, bei Überschreitung 429) auch für `/app/device` gilt, mit der bestehenden Abbruchregel bei 429; der Vertrag enthält weiterhin genau drei ```json-Blöcke (`grep -c '^```json'` ergibt 3; die Tests von `server/test/orders.test.ts` lesen genau drei).
- [x] **AC-12:** `CLAUDE.md` und Belege vollständig: GIVEN der Doku-PR WHEN er geöffnet ist THEN nennt `CLAUDE.md` im Abschnitt `server/` (Betrieb und Absatz `src/apns.ts`/`src/devices.ts`) `/app/device` seit S5b in der Liste der offenen Pfade (Zone `loose_ends_app`, 16k), den Weckruf als aktiv mit gesetzten `APNS_*` und die Umgebung des Schlüssels (a oder c) samt Hinweis, dass S5c die App liefert; der Belegordner enthält `check-device.sh`, `apns-probe.mjs`, `red.txt`, `green.txt`, `nginx-alt.conf`, `nginx-dump.txt`, `nginx-test.txt`, `infra-pr.txt`, `scan.txt`, `portal.md`, `probe-vorher.txt`, `betrieb.txt`, `probe-nachher.txt`, `monitor-vorher.txt`, `monitor-nachher.txt`; die Suche nach Wertmustern (`-----BEGIN` mit folgendem Schlüsselkörper, `Bearer ` mit Wert, `"d":`, `APNS_PRIVATE_KEY=` mit Wert) ergibt 0 Treffer; die Karte #795 ist aktuell und #795 hat einen Kommentar mit dem Stand S5b (Folge S5c).

## Dialog

### Runde 1
**Adversary:** Alle Belege gelesen, nicht nur zitiert. Eigene Gegenproben: /health extern 200; PR 460 MERGED (de4216b), genau zwei Dateien; `nginx -T` auf rennwienix zeigt `location = /app/device` mit allen geforderten Direktiven, `^~ /app/` danach unveraendert; Container `loose-ends-server:9bbb4cd`, Start 16:46:11Z, RestartCount 0 (keine Startschleife, kein neues Image); Vertrag hat 3 json-Bloecke. `check-device.sh` lief ich NICHT selbst (der Auto-Mode-Klassifikator lehnte den Aufruf ab, kein Umgehungsversuch); Ersatz ist der frische Lauf test-green-output.txt (16:50:38Z, exit=0, 6 Anfragen, 429 nein), deckungsgleich mit green.txt.
Finding F001 (MEDIUM, spec_violation): AC-3 verlangt `pytest tests -q` gruen, infra-pr.txt zeigt 25 failed. Gegenprobe auf main identisch (Frieda-RED-Commit 17f91e5, nicht im PR). Wortlaut verfehlt.
Finding F002 (LOW, spec_violation): AC-10 verlangt keinen Zustandswechsel anderer Dienste im diff; n8n/loose-ends-db Update->aktuell und CPU wechselten (fremder PR #459, Last). Wortlaut verfehlt, inhaltlich keine Verschlechterung.
**Implementierer:** F001: Tech-Lead-Freigabe, Fehler vorbestehend. F002: fremde Ursache, in probe-nachher.txt bewertet.

### Runde 2
**Adversary:** Gegen Early Agreement: Probe-Skript geprueft. Es importiert nur apnsConfigFromEnv/sendHttp2, nutzt erfundene randomBytes-Token, gibt keine Werte aus (nur Namen, Laengen, Host, Status, reason), Exit 1 bei jeder Abweichung. Wertscan: 3 Roh-Treffer (Regex-Literal im Skript, Beschreibungstext in portal.md/stand.md), als Nicht-Werte begruendet, plausibel. Betrieb: Sicherung 0600, nur vier APNS_*-Zeilen Differenz, Probe vor Neustart, Rueckweg dokumentiert. Abweichung (2), Neustart durch andere Sitzung: Beleg vollstaendig, Pruefung danach hier, unkritisch. Nicht von mir pruefbar: Karte/Kommentar #795 (AC-12 letzter Halbsatz) und Portal-Schritte (nur Belegtext).
**Implementierer:** Keine weiteren Einwaende.

## Bestaetigungen
Confirmation: AC: AC-1
  Code reference: docs/artifacts/feat-795-s5b-weckruf-betrieb/check-device.sh:37
  Evidence: Evidence: red.txt 3x FEHLT 404, 3x OK, 6 Anfragen, exit=1 | Status: CONFIRMED
Confirmation: AC: AC-2
  Code reference: docs/artifacts/feat-795-s5b-weckruf-betrieb/nginx-dump.txt:1
  Evidence: Evidence: eigener nginx -T Auszug deckt sich | Status: CONFIRMED
Confirmation: AC: AC-4
  Code reference: docs/artifacts/feat-795-s5b-weckruf-betrieb/nginx-test.txt:1
  Evidence: Evidence: nginx -t vor reload, Sicherung, reload Exit 0 | Status: CONFIRMED
Confirmation: AC: AC-5
  Code reference: docs/artifacts/feat-795-s5b-weckruf-betrieb/green.txt:1
  Evidence: Evidence: 401/405/413/404/401/405, exit=0, 429 nein | Status: CONFIRMED
Confirmation: AC: AC-6
  Code reference: docs/artifacts/feat-795-s5b-weckruf-betrieb/scan.txt:1
  Evidence: Evidence: Scan vorgezogen, OK ohne Abweichung | Status: CONFIRMED
Confirmation: AC: AC-7
  Code reference: docs/artifacts/feat-795-s5b-weckruf-betrieb/portal.md:1
  Evidence: Evidence: 0 vorher, KeyID, Team, Topic, Fall a, .p8 lokal geloescht | Status: CONFIRMED
Confirmation: AC: AC-8
  Code reference: docs/artifacts/feat-795-s5b-weckruf-betrieb/apns-probe.mjs:28
  Evidence: Evidence: nur apnsConfigFromEnv/sendHttp2, keine DB; probe-vorher.txt beide Hosts 400 BadDeviceToken | Status: CONFIRMED
Confirmation: AC: AC-9
  Code reference: docs/artifacts/feat-795-s5b-weckruf-betrieb/betrieb.txt:1
  Evidence: Evidence: bak 0600, Health 200, kein apns config invalid, RestartCount 0 | Status: CONFIRMED
Confirmation: AC: AC-11
  Code reference: docs/reference/claude-abschrift-vertrag.md:203
  Evidence: Evidence: offen seit S5b; Zeile 212 Zone auch fuer /app/device, 16 KiB; 3 json-Bloecke | Status: CONFIRMED
Confirmation: AC: AC-12
  Code reference: CLAUDE.md:573
  Evidence: Evidence: /app/device Zone loose_ends_app 16k in der Liste; Zeile 565 Weckruf aktiv, Fall a, S5c; Belegliste vollstaendig (wertscan.txt) | Status: CONFIRMED (Karte/Kommentar ungeprueft)
Finding F001
  Code reference: docs/artifacts/feat-795-s5b-weckruf-betrieb/infra-pr.txt:14
Finding F002
  Code reference: docs/artifacts/feat-795-s5b-weckruf-betrieb/probe-nachher.txt:22
Test output: docs/artifacts/feat-795-s5b-weckruf-betrieb/adversary-test-output.txt:1

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review):
  F001: AC-3 verlangt gruene Infra-Tests; 25 vorbestehende Fehler (fremder RED-Commit, identisch auf main, nicht durch den PR); Merge per Tech-Lead-Freigabe. Wortlaut verfehlt, Substanz unkritisch.
  F002: AC-10 diff zeigt Zustandswechsel anderer Dienste (fremder PR #459, CPU), Verbesserung, nicht von diesem Schnitt.

Proven points: 10/12 (AC-3, AC-10 nur dem Sinn nach)
Tests: 0 eigene Laeufe von check-device.sh (vom Klassifikator blockiert; Ersatz Lauf 16:50Z exit=0, 6/6 OK), 0 failed, 0 uebersprungen
Edge cases: Probe-Skript, Wertscan, Neustart durch andere Sitzung geprueft, nichts broken
Regressions: None found
Recommendation: Tech Lead nimmt F001/F002 per override-ambiguous mit Begruendung an.

## Geprüfte Dateien

- sha256:25b4d1a2757c3b9b9cd10d78fda4726604ee38195550cb3a509bcc4e919d232e  CLAUDE.md
- sha256:1acf7f38dad082208e602c7faffc2c7f69303aa5d148d3af2c3734b1c3a3c905  docs/artifacts/feat-795-s5b-weckruf-betrieb/apns-probe.mjs
- sha256:4768045954ca76c96b057402eb534f7398b93a58f6e0ec57f94dc570c298db4a  docs/artifacts/feat-795-s5b-weckruf-betrieb/betrieb.txt
- sha256:59b200dc0ef876d4c223331a04effd4e0e92ca69ba64ebb3a4c80188d3eb0525  docs/artifacts/feat-795-s5b-weckruf-betrieb/check-device.sh
- sha256:50c814993b16067e213c77c1cf0f44f51d1a64824dd99755aa0dcc2d2686fe6e  docs/artifacts/feat-795-s5b-weckruf-betrieb/green.txt
- sha256:9a944eee471f20f069153f2f2f942e8a900fa5393a642558db12739d692ceb27  docs/artifacts/feat-795-s5b-weckruf-betrieb/infra-pr.txt
- sha256:9abc3889fea23895b628813405c9b414251c588e052dcbf9177acb9317ce43fa  docs/artifacts/feat-795-s5b-weckruf-betrieb/nginx-dump.txt
- sha256:c4b735a26b408264fb8899ec3a2acdbeabab79ed510390a7d0cb7786a127318d  docs/artifacts/feat-795-s5b-weckruf-betrieb/nginx-test.txt
- sha256:e64ca1898ecd0c3c6b0e9fa4ceb270a6562b1905048c2a3c0209e9cb569ece5c  docs/artifacts/feat-795-s5b-weckruf-betrieb/portal.md
- sha256:cb523847fafd0772f26d107ca0583b5f37799c65a66dbe1b2a97b04dbdf767e9  docs/artifacts/feat-795-s5b-weckruf-betrieb/probe-nachher.txt
- sha256:dd9361c1e11e39e5a784f296dfa94f111f15247def4c08eab0a87ea7bb0191a6  docs/artifacts/feat-795-s5b-weckruf-betrieb/scan.txt
- sha256:06da7a5809212419c5db83ae77286027ae3138fc664d6b1bb5bdd8834e259af3  docs/reference/claude-abschrift-vertrag.md

## Prüfbasis

- base: 2429bf61b681c85970578351ac0cff73c548b102
- blob:119bb79083344307b0a4eebb771d5dc3e23e98d1  CLAUDE.md
- blob:5b9755822f7115a1b00932a49f4f2f7782cfa516  docs/artifacts/feat-795-s5b-weckruf-betrieb/apns-probe.mjs
- blob:78ece0069b1e0bfd3cec7981f7bdddcfcd4c6aa0  docs/artifacts/feat-795-s5b-weckruf-betrieb/betrieb.txt
- blob:2e30d8ab482bfc9fa2cf26830b5c53b6d1ad8b8c  docs/artifacts/feat-795-s5b-weckruf-betrieb/check-device.sh
- blob:c3905f0e5856913e09b6b9b6b5ee6e26a7f3fd6e  docs/artifacts/feat-795-s5b-weckruf-betrieb/green.txt
- blob:7f446c6dc9700271b90404baebd0ef22f2331394  docs/artifacts/feat-795-s5b-weckruf-betrieb/infra-pr.txt
- blob:44968b9861ed3a311787b4a9d63634eece6bde1c  docs/artifacts/feat-795-s5b-weckruf-betrieb/nginx-dump.txt
- blob:94a4c3dc5ce084eb0a627bfd094e311c2abb1437  docs/artifacts/feat-795-s5b-weckruf-betrieb/nginx-test.txt
- blob:1ea206cde64c8931d4f5e09b0f9a6b502ee5d5db  docs/artifacts/feat-795-s5b-weckruf-betrieb/portal.md
- blob:c12ee8066aa2ef3aaffee99ff14a8fd070acad0b  docs/artifacts/feat-795-s5b-weckruf-betrieb/probe-nachher.txt
- blob:216c2446ade066a3a8a02bd9a92bf603e4aa766d  docs/artifacts/feat-795-s5b-weckruf-betrieb/scan.txt
- blob:025ccfd7390cbfbf34683f3c0bb3991404b42fc3  docs/reference/claude-abschrift-vertrag.md
