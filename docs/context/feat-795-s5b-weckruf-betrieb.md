# Context: feat-795-s5b-weckruf-betrieb

## Request Summary
Schnitt S5b von #795 (Epic #612): den in S5a-1/S5a-2 gebauten Weckruf in Betrieb nehmen. nginx öffnet `POST /app/device`,
ein APNs-Schlüssel entsteht im Apple-Portal (Henning meldet sich nur an), die `APNS_*`-Geheimnisse liegen auf `rennwienix`,
der Dienst läuft damit, und ein erster echter Aufruf an Apple ist belegt. Die App (Token melden, Weckruf erkennen) ist S5c.

## Stand vor dem Schnitt (2026-11-15, gemessen)
- Live-Dienst `loose-ends-server` läuft mit Image `loose-ends-server:9bbb4cd` (= origin/main-Spitze, enthält S5a-1 Migration 008,
  `/app/device`, S5a-2a Absender, S5a-2b Weckruf in `storeOrder`). `/health` innen 200. **Ausrollen des Codes ist also schon
  geschehen**; ohne `APNS_*` bleibt der Weckruf aus.
- `secrets/server.env` auf `rennwienix` enthält `DATABASE_URL`, `APPLE_*` (Sign in with Apple, Schlüssel `SF83PT3Q22`),
  `OAUTH_*`, `PUBLIC_URL`, `ALLOWED_APPLE_SUBS` — **keine** `APNS_*`. Zwei datierte Sicherungen derselben Datei liegen daneben
  (Muster für die Sicherung vor dem Ändern).
- nginx (`henemm-infra/nginx/loose-ends.henemm.com.conf`): Zone `loose_ends_app` (10m, 10 r/s) mit drei `location =`-Blöcken
  (`/app/transcript`, `/app/orders/claim`, `/app/orders/result`, je `burst=40 nodelay`, `limit_req_status 429`,
  `client_max_body_size 256k`, vier Header), danach `location ^~ /app/ { return 404; }`. `/app/device` fällt heute auf 404.
- Compose: `loose-ends/docker-compose.yml`, Dienst mit `env_file: ./secrets/server.env`, Image-Tag `LE_TAG` nur über
  `scripts/deploy-loose-ends.sh`.

## Related Files
| Datei | Bedeutung |
|------|-----------|
| `server/src/apns.ts` | `apnsConfigFromEnv` (vier Variablen `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC`, alles oder nichts), `sendHttp2`, `createWaker`; Host je Gerät nach `environment` (`sandbox` → `api.sandbox.push.apple.com`, `production` → `api.push.apple.com`), **ein** Schlüssel für beide |
| `server/src/main.ts` | `apnsConfigOrExit`: halbe/ungültige Konfiguration → `apns config invalid: <Variable>`, Exit 1 |
| `server/src/devices.ts` | `/app/device`, `device_tokens`, `listTokens`, `dropToken` |
| `docs/reference/claude-abschrift-vertrag.md` | Abschnitt „Wege der App“: `/app/device` „von außen erst ab S5b“, Mengengrenze „Zone legt S5b fest“ — beides nachzuziehen |
| `docs/specs/feat-795-schnitt-1b-nginx.md` + `docs/artifacts/feat-795-s1b-nginx/` | Vorbild: Prüfskript `check-app.sh`, RED/GREEN von außen, Infra-PR über gh-API, `nginx -t` vor `reload`, `expected-exposure.json`, Monitor vorher/nachher |
| `docs/specs/feat-795-schnitt-5a1-geraet-anmelden.md`, `…-5a2a-…`, `…-5a2b-…` | Festlegungen für S5b (Downstream-Zeilen), Datenschutz-Vorbedingung erst für S5c |
| `project.yml` Z. 70/150 | `aps-environment: development` (App/Watch); das Archiv für TestFlight wird beim Export auf `production` umgestellt → Hennings Geräte melden später `production` (S5c prüft das) |
| `CLAUDE.md` Abschnitt `server/` (Betrieb) | Liste der offenen Pfade; bekommt `/app/device` |

## Existing Patterns
- Betriebsschnitte ohne Dienstcode: #615 S4d, #795 S1b — Prüfskript zuerst rot, Infra-PR, `nginx -t` → `reload`, Skript grün,
  `check-external-exposure.sh`, `monitor.sh --status` vorher/nachher, Doku-PR hier.
- Geheimnisse: Sicherung `server.env.bak-<UTC>`, Datei 0600, Werte nie in Ausgaben oder Belegen; Fehlermeldungen nennen nur den
  Variablennamen.
- Apple-Portal mit Henning: Claude öffnet die Seite in seinem Chrome, Henning meldet sich nur an (Passkey), Claude klickt den
  Rest (Vorbild CloudKit-Console, Services ID `com.henning.looseends.web` in #621).

## Recherche (2026-11-15)
- Apple, „Establishing a token-based connection to APNs“
  (https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns): **team-scoped Schlüssel
  gelten je für Sandbox oder Production** (höchstens zwei je Umgebung); bestehende Schlüssel für beide bleiben unterstützt, Apple
  empfiehlt getrennte. **Topic-spezifische** Schlüssel: je eine Umgebung, ausgewählte App-IDs. Auf einer Verbindung nach dem ersten
  Push keinen Schlüssel anderer Umgebung oder Art mischen.
- Anbieter-Anleitungen 2025/26 (OneSignal https://documentation.onesignal.com/docs/ios-p8-token-based-connection-to-apns, Pushy
  https://cdn.pushy.me/docs/ios/setup-apns-auth, Rover https://developer.rover.io/docs/ios/apns) beschreiben im Portal weiterhin die
  Auswahl „Sandbox & Production“ bei team-scoped Schlüsseln. Ob das Portal sie heute für neue Schlüssel anbietet, zeigt erst die
  Seite selbst.
- Fehlercodes: 403 `InvalidProviderToken` = Schlüssel/Team/kid passt nicht; 400 `BadDeviceToken` = Token falsch oder andere
  Umgebung, Anmeldung also bestanden (Apple-Foren https://developer.apple.com/forums/thread/689857). Damit lässt sich ein
  „erster echter Aufruf“ ohne Gerät belegen: frei erfundenes, wohlgeformtes Token → 400 `BadDeviceToken` beweist gültige
  Anmeldung, 403 beweist das Gegenteil.

## Dependencies
- Upstream: Apple-Portal (Schlüssel mit APNs-Recht, Team `XK87E2B3VR`, Topic `com.henning.looseends`), APNs HTTP/2, nginx auf
  `rennwienix`, `henemm-infra` (nginx-Datei, `expected-exposure.json`, Tests).
- Downstream: S5c (App meldet Token samt Umgebung, erkennt `looseends`), Vorbedingung Datenschutztext für S5c bleibt unberührt.

## Risks & Considerations
- **Umgebungsfrage (wichtigste Entscheidung):** Der Code nimmt einen Schlüssel für beide Hosts. Bietet das Portal nur
  Ein-Umgebungs-Schlüssel, bekommt die andere Umgebung 403. Hennings Alltag (TestFlight) ist `production`; Simulator- und
  Xcode-Läufe (A/B-Nachweis) sind `sandbox`. Wege: (a) ein Schlüssel „Sandbox & Production“, kein Code; (b) zwei Schlüssel, je
  Umgebung, kleine Codeänderung in `apns.ts`/`main.ts` (zweiter Variablensatz); (c) nur Production, Sandbox-Geräte werden nicht
  geweckt (holen weiter bei Start/Vordergrund). Entscheidung in `/20-analyse`.
- **Prüfaufruf darf kein Token löschen:** `createWaker` löscht bei 400 `BadDeviceToken`; der Beleg muss `sendHttp2` direkt
  nutzen (oder eine gezielte Probe), nie gegen echte Zeilen.
- Die JWT-Erzeugung ist in `apns.ts` nicht exportiert; ein Probeaufruf im Container braucht entweder eine kleine Ausfuhr oder
  eigenen Code im Skript.
- `server.env` ändern + Dienst neu starten = kurzer Ausfall des kritischen Dienstes (Monitor „kritisch“); vorher sichern, nach dem
  Start `/health` 200 und `APNS` ohne `apns config invalid` im Log.
- fail2ban/Mengengrenze: `/app/device` ruft die App selten (Start, Tokenwechsel) — gemeinsame Zone `loose_ends_app` reicht, Körper
  klein (`client_max_body_size` 16k genügt, 256k wie die Nachbarn ist unschädlich).
- Henning-Anmeldung im Portal: alles vorher fertig, damit er nicht wartet; Schlüsseldatei `.p8` lädt Apple nur **einmal** herunter
  — sofort auf `rennwienix` in `server.env` übertragen, lokale Kopie danach löschen.
- Nichts auf Hennings Geräten; kein Gerätelauf in diesem Schnitt.

## Analysis

### Type
Feature (Betriebsschnitt, kein Dienstcode)

### Recherche-Nachtrag (2026-11-15)
Anbieter-Anleitungen (Rover https://developer.rover.io/docs/ios/apns, OneSignal
https://documentation.onesignal.com/docs/en/ios-p8-token-based-connection-to-apns, Adobe
https://experienceleague.adobe.com/en/docs/platform-learn/implement-mobile-sdk/experience-cloud/journey-optimizer/journey-optimizer-push)
zeigen im Portal unter „Configure Key“ die Umgebung „Sandbox & Production“ für team-scoped Schlüssel; Apples Seite selbst
bestätigt das erst beim Anlegen. Für APNs-Schlüssel gibt es keine API (Anlegen nur im Portal), die `.p8` ist nur einmal ladbar.

### Entscheidung Umgebung (Tech Lead)
(a) **ein team-scoped Schlüssel „Sandbox & Production“**, kein Code. Fallback, falls das Portal nur eine Umgebung anbietet:
(c) **nur Production** (Hennings Alltag ist TestFlight = production; Xcode-/Simulator-Läufe holen weiter bei Start und
Vordergrund), ebenfalls ohne Code. (b) zwei Schlüssel mit zweitem Variablensatz (~30 LoC in `apns.ts`/`main.ts`, Apples
Empfehlung) bleibt Alternative, falls Sandbox-Weckrufe später gebraucht werden. Gekippt würde dafür keine ADR, nur die
Festlegung „ein Schlüssel für beide Hosts“ aus S5a-2a.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/artifacts/feat-795-s5b-weckruf-betrieb/check-device.sh` | CREATE | Prüfskript von außen: `POST /app/device` ohne Sitzung → 401 (heute 404), übriges `/app/` weiter 404, Nachbarn unverändert |
| `docs/artifacts/feat-795-s5b-weckruf-betrieb/apns-probe.mjs` | CREATE | Probe per stdin in einen Einmal-Container: `apnsConfigFromEnv` + `sendHttp2` aus `/app/src/apns.ts`, JWT im Skript selbst (node:crypto, ES256, ieee-p1363), an beide Hosts je ein erfundenes 64-hex-Token; Erwartung 400 `BadDeviceToken` (Anmeldung bestanden), 403 = Fehler; keine DB, kein `createWaker` (würde `dropToken` rufen), keine Werte in der Ausgabe |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | „von außen erst ab S5b“ → offen; Mengengrenze: Zone `loose_ends_app` gilt auch für `/app/device` |
| `CLAUDE.md` | MODIFY | Betrieb: `/app/device` in der Liste der offenen Pfade; Weckruf aktiv |
| `docs/specs/feat-795-schnitt-5b-weckruf-betrieb.md` | CREATE | Spec |
| henemm-infra: `nginx/loose-ends.henemm.com.conf`, `expected-exposure.json` (+ Test) | MODIFY | `location = /app/device` wie die drei Nachbarn (Zone `loose_ends_app`, burst 40, 429, Körper 16k) |
| rennwienix: Geheimnisdatei des Dienstes | MODIFY | vier `APNS_*` (Schlüssel einzeilig mit `\n`), vorher datierte Sicherung, 0600 |

`server/src/apns.ts` bleibt unberührt (kein Export nur fürs Betriebsskript).

### Scope Assessment
- Files: 5 in diesem Repo (+ 2–3 im Infra-Repo, + Geheimnisdatei)
- Estimated LoC: ca. +130 / −5 (Skripte ~90, Doku ~25)
- Risk Level: MEDIUM — Neustart des kritischen Dienstes; ein ungültiger Schlüssel schickte ihn mit `apns config invalid`
  in eine Startschleife. Dagegen: Probe **vor** dem Neustart.

### Technical Approach (Reihenfolge)
1. `check-device.sh` rot (404), Monitor `--status` vorher.
2. Infra-PR (nginx + Exposure), `nginx -t` → `reload`, Skript grün (401), `check-external-exposure.sh`.
3. Portal (Henning meldet sich nur an, alles vorher bereit): vorhandene APNs-Schlüssel zählen (Limit zwei je Umgebung),
   team-scoped „Sandbox & Production“ (Fallback Production) anlegen, `.p8` einmal laden.
4. `.p8` sofort auf rennwienix: Sicherungskopie `secrets/apns-<keyid>.p8` (0600), lokale Datei löschen.
5. **Probe vor dem Neustart:** Kandidat-Geheimnisdatei mit APNS_*, Einmal-Container `docker compose run --rm --no-deps -T`,
   laufender Dienst unberührt → beide Hosts 400 `BadDeviceToken` (Fallback c: production 400, sandbox 403, so belegt).
   Zeilenumbrüche im Wert vorher prüfen, nur Länge/Vorhandensein ausgeben, nie Werte.
6. Erst dann Geheimnisdatei sichern und ersetzen, `deploy-loose-ends.sh` (gleiches Image), `/health` 200, Log ohne
   `apns config invalid`, Probe wiederholen, Monitor nachher.
7. Doku (Vertrag, CLAUDE.md), PR hier.

### Dependencies
Apple-Portal (Hennings Anmeldung), APNs HTTP/2, nginx/`henemm-infra`, `deploy-loose-ends.sh`. Downstream S5c.

### Open Questions
- [x] Umgebung: technisch entschieden, (a) mit Fallback (c).
- Keine PO-Frage. Henning wird nur zur Portal-Anmeldung gerufen, wenn alles bereitsteht.
