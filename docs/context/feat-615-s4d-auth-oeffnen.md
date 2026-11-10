# Context: feat-615-s4d-auth-oeffnen (#615 Schnitt 4d)

## Request Summary
Die Anmeldung aus der App („Mit Apple anmelden“, Abmelden, Konto löschen) soll echt gegen den Live-Dienst
`https://loose-ends.henemm.com` laufen: nginx öffnet die drei `/auth/`-Pfade, der Dienst läuft mit dem Stand inkl. 4a
(Sitzungsablauf), dann ein TestFlight-Bau mit `konto=true` und Stufe 3 bei Henning (Beleg App-`sub` = Web-`sub`).
Datenschutztext (Konto-Teil) auf der Website und `LEAccountEnabled` im Store-Bau folgen in einem eigenen Schnitt (4e),
weil Henning den Wortlaut freigibt.

## Related Files
| File | Relevance |
|------|-----------|
| `henemm-infra: nginx/loose-ends.henemm.com.conf` | `location ^~ /auth/ { return 404; }` „bleibt zu bis #615 S4“; Muster je Pfad: eigene `limit_req_zone`, `proxy_pass 127.0.0.1:8780`, Header |
| `henemm-infra: scripts/deploy-loose-ends.sh` | `LE_COMMIT=ae957ba…` (PR #873). Danach kamen in `server/` nur `6e48532`/`fb6689a` (#615 S4a, Sitzungen 90 Tage gleitend) → Anheben nötig |
| `henemm-infra: security/expected-exposure.json` | erwartet heute `https://loose-ends.henemm.com/auth/apple` → 404; wird zu 405 (GET auf POST-Route) |
| `henemm-infra: loose-ends/docker-compose.yml` | `env_file: ./secrets/server.env`; keine Änderung erwartet |
| `server/src/auth.ts` | `POST /auth/apple` (Reihenfolge 503/405/415/413 16 KiB/400/401), `/auth/logout`, `/auth/delete`; `admit` mit `ALLOWED_APPLE_SUBS`; Audience = `config.clientIds` |
| `server/src/main.ts` | Body > 1 MiB → 413; `auth` immer eingehängt |
| `LooseEnds/Claude/ServiceClient.swift`, `AccountWiring.swift` | App ruft `/auth/apple`, `/auth/logout`, `/auth/delete` unter `serviceURL` (Fallback `https://loose-ends.henemm.com`) |
| `.github/workflows/testflight.yml` | Eingabe `konto` (Standard aus) setzt `LEAccountEnabled` true, Marke in „Was testen“ |
| `docs/artifacts/feat-621-s6b-betrieb/check-outside.sh` | Außenprüfung (curl, OK/FEHLT) — Vorlage für die `/auth/`-Prüfung |
| `docs/reference/datenschutz-entwurf.md` | sagt heute „kein Konto bei uns“ → Konto-Teil für 4e |

## Existing Patterns
- Infra-Schnitt #621 S6b: Infra-PR (drei Dateien), Tests im infra-Repo `python3 -m pytest tests -q` auf rennwienix,
  Deploy nur über `scripts/deploy-loose-ends.sh`, Belege unter `docs/artifacts/<workflow>/`, Außenprüfung per Skript.
- Geheimnisse nur über Skripte, die Namen bzw. ja/nein ausgeben (`secrets-namen.txt`).
- Stufe 3 über TestFlight: Lauf mit Eingabe, „Was testen“ für Henning, PR mit `Refs #615`.

## Dependencies
- Upstream: Apple (Identity Token, Code einlösen, Widerruf), `APPLE_CLIENT_IDS` muss `com.henning.looseends` enthalten,
  `ALLOWED_APPLE_SUBS` (ein Eintrag, Hennings Web-`sub`).
- Downstream: #795 (App lädt Abschrift hoch) hängt an 4d; 4e (Text + Store-Schalter).

## Research (2026-11-10)
- Apples `sub` ist team-bezogen: alle Apps und Services IDs desselben Teams bekommen denselben Nutzerbezeichner
  (DTS-Antwort, https://developer.apple.com/forums/thread/834970; Gegenstück verschiedene Teams:
  https://developer.apple.com/forums/thread/688044). App `com.henning.looseends` und Services ID
  `com.henning.looseends.web` liegen im Team `XK87E2B3VR` mit derselben primären App-ID → App-`sub` sollte gleich Web-`sub`
  sein und die Tür (`ALLOWED_APPLE_SUBS`) die App durchlassen. Beleg nur durch echten Lauf (Stufe 3).

## Existing Specs
- `docs/specs/feat-615-schnitt-4c2a-freischalten.md`, `docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md`,
  `docs/specs/feat-615-schnitt-4a-sitzungsablauf.md`

## Risks & Considerations
- **Wert von `APPLE_CLIENT_IDS` ungeprüft:** Lesender Blick auf den Server wurde in Phase 1 von der Rechtesperre
  abgelehnt; Prüfung (nur ja/nein) gehört in die Umsetzung, Skript liegt bereit.
- **Konto löschen auf Stufe 3 trifft Hennings einziges Konto:** dasselbe Konto trägt den claude.ai-Konnektor. Löschen
  entfernt Abschrift/Aufträge und widerruft auch den Web-Token → Konnektor muss neu verbunden werden. Produktfrage: auf
  dem Gerät löschen oder nur Anmelden/Abmelden und Löschen lokal/Simulator belegen.
- **fail2ban:** 10 Limit-Treffer sperren die Heim-IP 1 h für alle Hosts → keine Lastproben gegen die neue Zone.
- **Commit-Gate im infra-Klon** verlangt vor dem Adversary Hennings `override` (S6b-Falle) — einplanen.
- Nur die drei Pfade öffnen (exakte `location =`), Rest unter `/auth/` bleibt 404; Body-Grenze 16 KiB im Dienst, in
  nginx klein halten.
- Store-Bau bleibt aus, bis der Konto-Text live ist (Memory `loose-ends-615-s4-datenschutz-vorgezogen`).

## Analysis

### Type
Feature (Betrieb/Infrastruktur; keine sichtbare UI-Änderung, die Kontogruppe steht seit 4c → kein Entwurf nötig)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `henemm-infra: scripts/deploy-loose-ends.sh` | MODIFY | `LE_COMMIT` von `ae957ba` auf aktuellen `main` (enthält #615 S4a, Sitzungen 90 Tage gleitend); nur diese Zeile |
| `henemm-infra: nginx/loose-ends.henemm.com.conf` | MODIFY | Zone `loose_ends_auth` (5r/s, burst 10, Status 429); drei `location =` für `/auth/apple`, `/auth/logout`, `/auth/delete` mit `client_max_body_size 16k`, Proxy-Header wie die anderen; `^~ /auth/` → 404 bleibt für den Rest; Kopfkommentar anpassen |
| `henemm-infra: security/expected-exposure.json` | MODIFY | `/auth/apple` GET 404 → 405; dazu `/auth/logout`, `/auth/delete` GET → 405; `/auth/x` → 404 |
| `docs/artifacts/feat-615-s4d-auth-oeffnen/` | CREATE | Belege: Server-Variablen (nur ja/nein), Deploy, `nginx -t`, Außenprüfung, Gerätelauf |
| `docs/artifacts/feat-615-s4d-auth-oeffnen/check-auth.sh` | CREATE | Außenprüfung (Vorlage `check-outside.sh` aus S6b): GET → 405, POST ohne Body → 4xx, `/auth/delete` ohne/mit falschem Bearer → 401, `/auth/x` → 404, 17 KiB-Body → 413; insgesamt < 10 Anfragen, keine Schleifen |
| `CLAUDE.md` | MODIFY | Betriebsabsatz: `/auth/*` offen seit S4d (drei Pfade, Zone `loose_ends_auth`) statt „bleiben 404“ |

### Scope Assessment
- Files: 3 im infra-Repo, 2–3 hier (Belege zählen nicht als Code)
- Estimated LoC: infra ≈ +45/−3; hier ≈ +60 (Prüfskript) / ±5 CLAUDE.md
- Risk Level: MEDIUM — öffentlicher Endpunkt am Live-Dienst; Code dahinter seit S3 getestet

### Technical Approach
Reihenfolge (Rollbacks getrennt):
1. Server-Variablen lesend prüfen, Ausgabe nur ja/nein: `APPLE_CLIENT_IDS` enthält `com.henning.looseends`;
   `ALLOWED_APPLE_SUBS` gesetzt, ein Eintrag. Fehlt die App-ID → zuerst ergänzen (Skript, kein Wert im Log).
2. Infra-PR A: nur `LE_COMMIT`; Deploy über `scripts/deploy-loose-ends.sh`, `/health` 200, `get_now` des Konnektors geht weiter.
3. Infra-PR B: nginx + exposure; `nginx -t`, Reload, Außenprüfung, `check-external-exposure.sh` ohne Abweichung.
4. TestFlight-Lauf mit `konto=true`, „Was testen“ für Henning: Einstellungen › Claude › Mit Apple anmelden, dann Abmelden.
   Beleg danach auf dem Server: `accounts` = 1 (App-`sub` = Web-`sub`, Recherche oben), eine Sitzungszeile entstand und
   ist nach Abmelden beendet, keine Zeile `account refused`, Konnektor `get_now` geht weiterhin.

Befunde aus der Gegenprüfung (Plan-Agent, Code gelesen `server/src/accounts.ts:101-133`):
- `/auth/delete` löscht Abschrift, Aufträge, alle `oauth_records` der Grants, Sitzungen, Apple-Tokens und widerruft bei
  Apple auch den Web-Token → claude.ai-Konnektor gibt danach 401 und muss neu verbunden werden; Neuanmelden geht, weil
  Hennings `sub` in `ALLOWED_APPLE_SUBS` steht. Daten kommen nicht zurück (heute: noch keine Abschrift aus der App, #795).
- fail2ban (`nginx-limit-req`, 10 Treffer → 1 h alle Hosts): Außenprüfung bleibt unter 10 Anfragen, kein 429 provozieren.

### Alternatives
- **A1 (verworfen):** `^~ /auth/` als Präfix durchreichen statt drei exakter Pfade — weniger Zeilen, öffnet aber jeden
  künftigen Unterpfad ungeprüft; widerspricht der Allowlist aus #621 S6b.
- **A2:** Nur `/auth/apple` und `/auth/logout` öffnen, `/auth/delete` bleibt 404 bis zu einem Wegwerfkonto. Nachteil:
  App bietet „Konto löschen“, das dann live scheitert; Apples Pflicht zur Kontolöschung wäre im Store-Bau verletzt.
  Kippt keine ADR, aber die 4c-Entscheidung „Löschen in der App“.
- **A3:** Konto-Teil gar nicht live, App nur gegen lokalen Dienst (Simulator) belegen und 4d mit #795 bündeln — verschiebt
  den einzigen echten Beleg (App-`sub` = Web-`sub`), auf dem #795 aufbaut.

### Dependencies
- Upstream: Apple (Team `XK87E2B3VR`, App-ID mit SIWA primär, Schlüssel `SF83PT3Q22`), Server-Variablen.
- Downstream: #795, Schnitt 4e (Datenschutztext + Store-Schalter).

### Open Questions
- [x] PO (Henning, 2026-11-10): **Nur Anmelden/Abmelden auf dem iPhone.** Frage war: Auf dem iPhone auch „Konto löschen“ ausprobieren (Konnektor danach neu verbinden) oder nur Anmelden/Abmelden,
      Löschen live nur als Abweisung ohne Sitzung (401) und echt im Simulator gegen den lokalen Dienst? Empfehlung: Letzteres.

  Entscheidung: Löschen echt nur im Simulator gegen den lokalen Dienst; live nur Abweisung (401 ohne/mit falschem Token). Konnektor bleibt unberührt.
