---
entity_id: feat-615-schnitt-4d-auth-oeffnen
type: feature
created: 2026-11-10
updated: 2026-11-10
status: draft
workflow: feat-615-s4d-auth-oeffnen
---

# Spec: Die App-Anmeldung am Live-Dienst öffnen, Schnitt 4d (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 4d; das Issue bleibt offen (`Refs #615`, nie `Closes #615`): Schnitt 4e (Datenschutztext und Store-Schalter) folgt, und die Gerätepunkte stehen in der Definition of Done (Stufe 3).
Analyse: `docs/context/feat-615-s4d-auth-oeffnen.md` (Ist-Stand, Recherche zur team-bezogenen Apple-`sub`, Reihenfolge, Alternativen, Risiken, PO-Entscheidung 2026-11-10; verbindlich).
Vorgänger: 4a (`docs/specs/feat-615-schnitt-4a-sitzungsablauf.md`), 4c-2a (`docs/specs/feat-615-schnitt-4c2a-freischalten.md`), 4c-2b (`docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md`); Betriebsvorbild `docs/specs/feat-621-schnitt-6b-betrieb.md`.
Es ist ein Betriebsschnitt: **kein Dienstcode in `server/src`**, keine App-Änderung.

## Für den PO

Die Gruppe „Claude“ in den Einstellungen kann sich bisher nur gegen einen Dienst im eigenen Rechner anmelden, weil der echte Dienst im Netz die drei Wege dafür (Anmelden, Abmelden, Konto löschen) noch verschlossen hält. Dieser Schnitt macht genau diese drei Wege auf. Danach bauen wir eine TestFlight-Version, in der die Gruppe eingeschaltet ist, und du probierst Anmelden und Abmelden auf dem iPhone aus. Dabei zeigt sich, ob Apple dich in der App und im Browser als dieselbe Person kennt; danach rechne ich auf dem Server nach, dass es bei einem einzigen Konto bleibt und deine Verbindung zu claude.ai unberührt ist.

Dein Konto löschst du auf dem iPhone nicht: Löschen würde dein einziges Konto samt der claude.ai-Verbindung entfernen. Das Löschen prüfe ich echt gegen einen Dienst auf meinem Rechner, und im Netz nur, dass es ohne gültige Anmeldung abgewiesen wird. Die Gerätepunkte (dein Anmelden und Abmelden) sind keine Bedingung dieser Spezifikation, sondern stehen in der Definition of Done; das Ticket bleibt bis zu deiner Rückmeldung offen. Der Datenschutztext und der Store-Schalter folgen in einem eigenen Schnitt, weil du den Wortlaut freigibst. In den Stores ändert sich nichts.

## Purpose

`https://loose-ends.henemm.com` reicht seit #621 S6b nach einer Erlaubnisliste nur `/health`, `/mcp`, die drei `/.well-known/`-Dokumente und `/oauth/` an den Dienst; `^~ /auth/` antwortet ausdrücklich 404 („bleibt zu bis #615 S4“). Der Dienst selbst kann `POST /auth/apple`, `POST /auth/logout` und `POST /auth/delete` seit S3 (geprüft in `server/test`, nie öffentlich gelaufen). Die App spricht diese Pfade unter `serviceURL` (Fallback `https://loose-ends.henemm.com`).

Dieser Schnitt (a) prüft lesend, dass die Server-Variablen die App zulassen, (b) hebt den Dienst auf einen Stand mit 4a (Sitzungen laufen nach 90 Tagen Nichtbenutzung ab), (c) öffnet in nginx genau diese drei Pfade, (d) belegt die Öffnung von außen mit einem kleinen Skript und (e) legt den Gerätelauf als Definition of Done fest.

| Pfad | Zweck | nginx |
|---|---|---|
| `= /auth/apple` | Anmelden (Identity Token plus Code) | neue Zone `loose_ends_auth`, `client_max_body_size 16k` |
| `= /auth/logout` | Abmelden dieser Sitzung | wie oben |
| `= /auth/delete` | Konto löschen | wie oben |
| `^~ /auth/` (Rest) | nichts | bleibt 404 |

Alle drei reichen dieselben Header weiter wie `/health` (`Host $host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) an `127.0.0.1:8780`. Die Zone `loose_ends_auth` hat `rate=5r/s`, `burst=10 nodelay`, `limit_req_status 429`. Der Dienst begrenzt den Körper selbst auf 16 KiB (413); nginx hält dieselbe Grenze vorn.

**Ablauf (feste Reihenfolge, Rollbacks getrennt):**

1. **Server-Variablen lesend prüfen**, Ausgabe nur ja/nein: `APPLE_CLIENT_IDS` enthält `com.henning.looseends`; `ALLOWED_APPLE_SUBS` ist gesetzt mit genau einem Eintrag. Fehlt die App-ID, wird sie zuerst ergänzt (Skript, kein Wert im Protokoll) und der Dienst über das Deploy-Skript neu gestartet.
2. **Infra-PR A**: nur `LE_COMMIT` in `scripts/deploy-loose-ends.sh`, auf den `main`-Stand des Dienstes zum Deploy-Zeitpunkt (enthält 4a: `6e48532` und `fb6689a`). Deploy nur über das Skript; `/health` 200; der claude.ai-Konnektor läuft weiter.
3. **Prüfskript und RED**: `check-auth.sh` läuft vor der nginx-Änderung und zeigt `FEHLT` (heute 404 statt 405/401/413).
4. **Infra-PR B**: nginx-Datei und `expected-exposure.json`; CI und Tests im Infra-Repo grün, Merge, `git pull` auf `rennwienix`; alte Datei sichern, neue kopieren, `nginx -t`, erst bei Erfolg `systemctl reload nginx`.
5. **GREEN von außen**: `check-auth.sh` Exit 0; Exposure-Prüfung ohne Abweichung; `monitor.sh --status` für andere Dienste unverändert.
6. **Konto löschen echt nur lokal** (PO-Entscheidung 2026-11-10): gegen einen Dienst auf dem eigenen Rechner mit Wegwerf-Datenbank (`./server/scripts/test-local.sh`-Aufbau); im Netz nur die Abweisung ohne gültige Sitzung (401).
7. **Belege-PR und `CLAUDE.md`**; danach TestFlight-Lauf mit `konto=true` (Eingabe `what_to_test` für Henning), Gerätelauf nach „Definition of Done (Gerätepunkte, Stufe 3)“.

**Regeln vor Modell:** Betrieb, Netz und Sicherheit ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 (Dienst für Claude, Anmeldung nur über Apple, „nur Henning bis #625“) und die Entscheidung #615 (nur Apple, Konto-Gruppe in der App, Löschen in der App) um, ohne sie zu ändern oder zu kippen; kein neues Verfahren, keine neue Abhängigkeit, keine Migration. Die Allowlist-Haltung aus #621 S6b (nur freigegebene Pfade) bleibt Grundlage.

- **Rationale:** Der Code dahinter ist seit S3 getestet, offen war nur das Öffnen. Drei exakte Pfade statt eines Präfixes halten die Haltung der Datei ein; die Reihenfolge Deploy vor nginx folgt S6b, damit nie ein halb offener Zustand nach außen steht.

## Source

**Dateien (Infra-Repo `henemm/henemm-infra`):** `scripts/deploy-loose-ends.sh` (nur `LE_COMMIT`), `nginx/loose-ends.henemm.com.conf`, `security/expected-exposure.json`.
**Dateien (loose-ends):** `docs/artifacts/feat-615-s4d-auth-oeffnen/` (neu: `check-auth.sh` und Belege), `CLAUDE.md` (Betrieb-Absatz im Abschnitt `server/`).
**Kein Dienstcode, keine App:** `server/src`, `server/test`, Migrationen, `project.yml`, `LooseEnds/` bleiben unberührt. Wird beim Betrieb ein Dienstfehler sichtbar, wird der Schnitt angehalten; der Fix ist ein eigener Schnitt.

### Schnittstelle und Festlegungen

- **Statuscodes des Dienstes** (`server/src/auth.ts`, gegengelesen): `/auth/apple`: 503 ohne Apple-Konfiguration, dann 405 für Nicht-POST (Header `allow: POST`), 415 ohne JSON, 413 über 16 KiB, 400 bei ungültigem Körper, 401 bei jeder anderen Ablehnung, 503 nur wenn Apple nicht erreichbar. `/auth/logout` und `/auth/delete`: 405 für Nicht-POST, 401 ohne Bearer oder bei unbekannter Sitzung, 204 bei Erfolg. Alle Ablehnungen sind nackte Statuscodes mit `cache-control: no-store`.
- **`check-auth.sh`** (Vorlage `check-outside.sh` aus S6b): `curl`, nur lesend, ohne Geheimnisse, Ausgabe zeilenweise `OK`/`FEHLT` mit Statuscode, Exit 0 nur, wenn alles `OK`; **höchstens 8 Anfragen, keine Schleifen**, kein 429 provozieren (fail2ban sperrt nach 10 Limit-Treffern die Heim-IP eine Stunde für alle Hosts). Anfragen: `GET /auth/apple`, `GET /auth/logout`, `GET /auth/delete` (je 405), `POST /auth/apple` ohne JSON-Kopf (415), `POST /auth/delete` ohne Bearer (401), `POST /auth/delete` mit falschem Bearer (401), `GET /auth/x` (404), `POST /auth/apple` mit 17 KiB JSON-Körper (413).
- **`expected-exposure.json`:** `/auth/apple` GET von 404 auf 405; neu `/auth/logout` und `/auth/delete` GET 405; `/auth/x` 404.
- **Geheimnisse:** nie im Repo, Protokoll, Beleg oder Nachricht; Belege nennen nur Namen, ja/nein und Zählungen. Die Prüfung der Variablen läuft über ein Skript, das nur `ja`/`nein` ausgibt.
- **Nur über das Deploy-Skript neu starten**, nie `docker compose` von Hand, kein Reboot, kein Eingriff in andere Dienste.
- **Commit-Gate im Infra-Klon:** verlangt vor dem Adversary Hennings `override` (Erfahrung aus S6b); wird eingeplant, nicht umgangen.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| Dienst auf `main` inkl. 4a (`6e48532`, `fb6689a`), Deploy-Skript mit Image-Build | bestehend |
| `APPLE_CLIENT_IDS` mit `com.henning.looseends`, `ALLOWED_APPLE_SUBS` mit Hennings `sub` (Team `XK87E2B3VR`, Services ID `com.henning.looseends.web`, Schlüssel `SF83PT3Q22`) | bestehend; Prüfung in Schritt 1 |
| App mit Konto-Gruppe (4c-1), Schalter `konto` im TestFlight-Lauf (4c-2a), https-Adresse (4c-2b) | bestehend |
| Apples team-bezogene `sub` (App und Services ID im selben Team liefern denselben Nutzerbezeichner; Belege Apple-Foren 834970 und 688044) | Annahme; der echte Beleg ist der Gerätelauf |
| Downstream | Schnitt 4e (Datenschutztext, Store-Schalter), #795 (App lädt Abschrift hoch) |

## Acceptance Criteria

Belege liegen unter `docs/artifacts/feat-615-s4d-auth-oeffnen/` (im Folgenden „Belegordner“). Kein Beleg enthält einen Geheimniswert; Ausgaben mit Variablen zeigen nur Namen, ja/nein, Zählungen und Statuscodes.

- **AC-1:** Server-Variablen geprüft, nichts geleakt: GIVEN `secrets/server.env` auf `rennwienix` WHEN das Prüfskript nur lesend läuft THEN steht in `variablen.txt` je Zeile `APPLE_CLIENT_IDS enthält com.henning.looseends: ja` und `ALLOWED_APPLE_SUBS: gesetzt, genau ein Eintrag: ja` (bei `nein` wird zuerst ergänzt und die Zeile danach mit `ja` erneut belegt, mit Vermerk der Ergänzung ohne Wert); die Datei enthält keinen Variablenwert und keine `sub` (Suche nach den ersten 12 Zeichen jedes Wertes und dem Beginn `-----BEGIN` ergibt 0 Treffer, Vermerk am Ende von `variablen.txt`).
- **AC-2:** RED des Prüfskripts: GIVEN `docs/artifacts/feat-615-s4d-auth-oeffnen/check-auth.sh` WHEN es vor der nginx-Änderung gegen `https://loose-ends.henemm.com` läuft THEN endet es mit Exit ≠ 0, und `red.txt` zeigt `FEHLT` mit 404 für die drei GET-Anfragen (erwartet 405) und für die zwei `POST /auth/delete` (erwartet 401), sowie für den 17-KiB-Körper und den POST ohne JSON-Kopf (erwartet 413 bzw. 415); `GET /auth/x` ist schon `OK` mit 404.
- **AC-3:** Infra-PR A, Dienst auf neuem Stand: GIVEN der PR in `henemm/henemm-infra` WHEN `LE_COMMIT` angehoben ist THEN besteht der Diff von `scripts/deploy-loose-ends.sh` nur aus der `LE_COMMIT`-Zeile, `git merge-base --is-ancestor fb6689a <LE_COMMIT>` endet mit Exit 0, die CI ist grün (Beleg `infra-pr-a.txt` mit PR-Nummer, Kennungen, CI-Status); GIVEN der Merge und `git pull` auf `rennwienix` WHEN `scripts/deploy-loose-ends.sh` läuft THEN Exit 0, `/health` lokal und von außen 200 (Beleg `deploy.txt`, Deploy-Ausgabe, freier Speicher vor dem Deploy ≥ 600 MB laut Skript), und `docker ps` zeigt den Container mit dem Image des `LE_COMMIT`.
- **AC-4:** Konnektor läuft nach dem Deploy weiter: GIVEN AC-3 WHEN der claude.ai-Konnektor `get_now` aufruft THEN antwortet der Dienst ohne Fehler (Beleg `konnektor.md`: Zeitpunkt, Statuszeile 200 aus dem Zugriffsprotokoll, Wortlaut der Antwort ohne Aufgabentexte); ist der Konnektor in dieser Sitzung nicht erreichbar, hält `konnektor.md` das ehrlich fest, und Ersatz ist `check-outside.sh` aus `docs/artifacts/feat-621-s6b-betrieb/` mit Exit 0 (Discovery und `/mcp` ohne Token 401 mit `resource_metadata`).
- **AC-5:** nginx öffnet genau drei Pfade: GIVEN die Datei `nginx/loose-ends.henemm.com.conf` WHEN der Auszug des Server-Blocks aus `nginx -T` gelesen wird THEN enthält er genau drei `location =` für `/auth/apple`, `/auth/logout` und `/auth/delete`, jeweils mit `limit_req zone=loose_ends_auth burst=10 nodelay`, `client_max_body_size 16k`, `proxy_pass` auf `127.0.0.1:8780` und den vier Headern wie `/health`; die Zone `loose_ends_auth` ist mit `rate=5r/s` und `limit_req_status 429` definiert; `^~ /auth/` liefert weiterhin `return 404`; die Kopfzeile der Datei nennt die drei Pfade (Beleg `nginx-T.txt`, ohne Geheimnisse).
- **AC-6:** nginx wird nur nach Test geladen, mit Rückweg: GIVEN die neue Datei auf dem Server WHEN sie in Kraft gesetzt wird THEN ist die alte Datei vorher gesichert (`nginx-alt.conf` im Belegordner, Ort der Sicherung auf dem Server genannt), `nginx -t` zeigt `syntax is ok` und `test is successful`, `systemctl reload nginx` läuft erst danach mit Exit 0 (Beleg `nginx-t.txt` mit Zeitstempeln, Reload später als Test); bei Fehler im Test wird nicht geladen.
- **AC-7:** Infra-PR B und Tests: GIVEN der PR in `henemm/henemm-infra` WHEN er geöffnet ist THEN ändert er genau `nginx/loose-ends.henemm.com.conf` und `security/expected-exposure.json`; `expected-exposure.json` enthält `/auth/apple`, `/auth/logout`, `/auth/delete` je GET → 405 und `/auth/x` → 404 (kein Eintrag `/auth/apple` mit 404 mehr); `python3 -m pytest tests -q` im Infra-Klon auf `rennwienix` ist grün und die CI des PR ist grün (Beleg `infra-pr-b.txt`: PR-Nummer, Kennungen, Teststand, CI-Status).
- **AC-8:** Öffnung von außen, GREEN: GIVEN nginx ist geladen WHEN `check-auth.sh` von außen läuft THEN Exit 0 und `green.txt` zeigt `OK` mit `GET /auth/apple`, `GET /auth/logout`, `GET /auth/delete` je 405, `POST /auth/apple` ohne JSON-Kopf 415, `POST /auth/delete` ohne Bearer 401, mit falschem Bearer 401, `GET /auth/x` 404 und `POST /auth/apple` mit 17-KiB-Körper 413; das Skript hat insgesamt höchstens 8 Anfragen gesendet (Zählung als Zeile am Ende von `green.txt`) und kein 429 gesehen.
- **AC-9:** Exposure-Prüfung ohne Abweichung: GIVEN `security/expected-exposure.json` aus AC-7 WHEN `check-external-exposure.sh` (oder der Einzelaufruf des Scans der Infra) läuft THEN meldet er für `loose-ends.henemm.com` keine Abweichung (Beleg `scan.txt`: Zeilen des Hosts mit Status); läuft der Scan nur nachts und ist nicht vorziehbar, steht im Beleg der Zeitpunkt des nächsten Laufs und `todo-scan.md` im Belegordner, den der Tech Lead beim nächsten Sitzungsstart prüft, nie Henning.
- **AC-10:** Andere Dienste unverändert: GIVEN `monitor.sh --status` auf `rennwienix` WHEN es vor Beginn der Serverarbeit und nach dem Reload (AC-6) läuft THEN zeigt `diff` von `monitor-vorher.txt` und `monitor-nachher.txt` keine Zeile eines anderen Dienstes als `loose-ends`; `loose-ends` ist `OK`; es gab keinen Neustart eines anderen Containers, keinen Reboot und keinen Docker-Neustart (Beleg `uptime` und `docker ps`-Spalte „Status“ der anderen Container vor und nach, ohne Umgebungswerte).
- **AC-11:** Konto löschen echt nur lokal, live nur Abweisung (PO-Entscheidung 2026-11-10): GIVEN ein Dienst auf dem eigenen Rechner gegen eine Wegwerf-Datenbank (Postgres 18, Aufbau wie `./server/scripts/test-local.sh`, nur lokal erreichbar) mit einem angelegten Konto und einer Sitzung WHEN `POST /auth/delete` mit dem Bearer dieser Sitzung gesendet wird THEN antwortet der Dienst 204, `SELECT count(*)` auf `accounts` und `sessions` für dieses Konto ergibt danach 0, und ein zweiter Aufruf mit demselben Bearer antwortet 401; GIVEN der Simulator WHEN `./scripts/sim.sh test-proof AccountSettingsTests` läuft (die App-Seite des Löschens mit dem Stellvertreter-Transport aus 4c-1: `testDeleteCancelKeepsSignedIn`, `testDeleteConfirmSignsOut`) THEN sind beide Tests grün und der maschinelle Simulator-Beleg liegt vor; im Netz bleibt es bei AC-8 (401 ohne und mit falschem Bearer), `https://loose-ends.henemm.com/auth/delete` wird nie mit einer gültigen Sitzung aufgerufen. Belege `loeschen-lokal.md` (Befehle, Statuscodes, Zählungen, Screenshot, Befund) und `loeschen-live.txt` (verweist auf `green.txt`); der Beleg sagt ausdrücklich, dass der Simulator keine echte Apple-Anmeldung herstellt: die App-Seite belegt Bestätigung und Abmelden mit Stellvertreter, die Dienst-Ebene belegt das echte Löschen.
- **AC-12:** Dokumentation aktuell: GIVEN der Belege-PR WHEN er geöffnet ist THEN nennt der Betrieb-Absatz im Abschnitt `server/` von `CLAUDE.md`, dass `/auth/apple`, `/auth/logout` und `/auth/delete` seit S4d offen sind (Zone `loose_ends_auth`, 16k) und der Rest unter `/auth/` 404 bleibt (statt „`/auth/*` … stay 404“), mit Verweis auf den Belegordner; der Belegordner enthält `variablen.txt`, `check-auth.sh`, `red.txt`, `infra-pr-a.txt`, `deploy.txt`, `konnektor.md`, `nginx-T.txt`, `nginx-t.txt`, `nginx-alt.conf`, `infra-pr-b.txt`, `green.txt`, `scan.txt`, `monitor-vorher.txt`, `monitor-nachher.txt`, `loeschen-lokal.md`, `loeschen-live.txt`; die Suche nach Wertmustern (`-----BEGIN`, `"d":`, die ersten 12 Zeichen jedes Geheimniswertes) über den Belegordner ergibt 0 Treffer; die Karte #615 ist aktuell, #615 hat einen Kommentar mit dem Stand 4d.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `henemm-infra: scripts/deploy-loose-ends.sh` | MODIFY | `LE_COMMIT` auf den aktuellen Dienststand mit 4a; ≈ +1/−1 |
| `henemm-infra: nginx/loose-ends.henemm.com.conf` | MODIFY | Zone `loose_ends_auth`, drei `location =`, Kopfkommentar; `^~ /auth/` bleibt 404; ≈ +40/−2 |
| `henemm-infra: security/expected-exposure.json` | MODIFY | `/auth/apple` 404 → 405, `/auth/logout`, `/auth/delete` 405, `/auth/x` 404; ≈ +6/−1 |
| `docs/artifacts/feat-615-s4d-auth-oeffnen/` (loose-ends) | CREATE | `check-auth.sh` (≈ 45 Zeilen) und Belege (Text) |
| `CLAUDE.md` (loose-ends) | MODIFY | Betrieb-Absatz im `server/`-Abschnitt; ≈ +3/−2 |

Außerhalb des Repos (Handarbeit, nicht versioniert, mit Belegen): Server `rennwienix` (Prüfung der Variablen, Deploy, nginx-Datei, `reload`), TestFlight-Lauf.

### Estimated Changes

- **Dateien: 5 Pfade** (3 Infra, 2 loose-ends; der Belegordner zählt als ein Pfad). Innerhalb des Limits von 4 bis 5 Dateien; Belege sind Text und zählen nicht als Code.
- **LoC: ≈ 100 insgesamt** (Infra ≈ 55, `check-auth.sh` ≈ 45, `CLAUDE.md` ≈ 5), innerhalb von ±250 LoC. Kein Dienstcode.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, kein `generate`, keine Migration, keine neue Abhängigkeit.
- **Seiteneffekte nach außen (explizit):** Drei Pfade am Live-Dienst werden öffentlich erreichbar; geteiltes nginx lädt neu (`reload`, kein Neustart, `nginx -t` vorher); der Dienst wird neu gestartet (Deploy-Skript, 4a-Stand); bei der Anmeldung im Gerätelauf entsteht eine Sitzung für Hennings bestehendes Konto (kein zweites Konto, `ALLOWED_APPLE_SUBS` hält die Tür).
- **Parallele Arbeit:** vor jedem PR `origin/main` und offene PRs in beiden Repos erneut prüfen; `CLAUDE.md` ist Hotspot.

## Risiken

- **Öffentlicher Endpunkt am Live-Dienst.** Gegenmittel: exakte Pfade, Zone mit Limit, 16-KiB-Grenze in nginx und im Dienst, nackte Statuscodes im Dienst, Code seit S3 getestet; Rückweg über die gesicherte nginx-Datei.
- **fail2ban.** Zehn Limit-Treffer sperren die Heim-IP eine Stunde für alle Hosts. Gegenmittel: `check-auth.sh` mit höchstens 8 Anfragen, keine Lastproben gegen die neue Zone.
- **Wert von `APPLE_CLIENT_IDS` ungeprüft.** Fehlt die App-ID, weist der Dienst jede App-Anmeldung mit 401 ab (Audience = `config.clientIds`). Gegenmittel: AC-1 vor dem Deploy.
- **App-`sub` ungleich Web-`sub`.** Nach Apples Dokumentation und den Forenbelegen sollte sie im selben Team gleich sein; belegt wird es nur durch den echten Lauf. Wäre sie ungleich, antwortet der Dienst mit 401 und `account refused`, `accounts` bleibt 1; der Befund ist dann ein eigener Schnitt (Zulassung beider `sub`-Werte), nicht Teil dieser Spec.
- **Konto löschen trifft Hennings einziges Konto.** Es trägt auch den claude.ai-Konnektor; Löschen entfernt Abschrift, Aufträge und alle Grants und widerruft den Web-Token bei Apple. Gegenmittel (PO-Entscheidung): kein Löschen auf dem Gerät, live nur Abweisung.
- **Geteiltes nginx.** Ein Fehler könnte andere Hosts treffen. Gegenmittel: `nginx -t` vor `reload`, alte Datei gesichert, `monitor.sh --status` vorher und nachher (AC-6, AC-10).
- **Commit-Gate im Infra-Klon** verlangt vor dem Adversary Hennings `override`; wird eingeplant, nicht umgangen.
- **Store-Bau bleibt aus.** `LEAccountEnabled` bleibt in jedem Store-Bau `false`, bis der Datenschutztext mit Konto-Teil live ist (Schnitt 4e); nur der TestFlight-Lauf mit `konto=true` schaltet die Gruppe ein.

## Test Plan

Es gibt keinen Dienstcode und keine App-Änderung, also keine neuen Unit- oder UI-Tests. Die Prüfungen sind Außenprüfung, Infra-Tests und ein lokaler Lauf:

| Prüfung | Beleg | AC |
|---|---|---|
| Lesende Prüfung der Server-Variablen (nur ja/nein) | `variablen.txt` | AC-1 |
| `check-auth.sh` RED vor der nginx-Änderung | `red.txt` | AC-2 |
| Infra-PR A, `LE_COMMIT` mit 4a als Vorfahr, Deploy, `/health` | `infra-pr-a.txt`, `deploy.txt` | AC-3 |
| Konnektor `get_now` nach dem Deploy (oder `check-outside.sh` als Ersatz) | `konnektor.md` | AC-4 |
| `nginx -T`-Auszug: drei `location =`, Zone, 16k, Rest 404 | `nginx-T.txt` | AC-5 |
| `nginx -t` vor `reload`, alte Datei gesichert | `nginx-t.txt`, `nginx-alt.conf` | AC-6 |
| Infra-Repo `python3 -m pytest tests -q` auf `rennwienix`, CI des PR | `infra-pr-b.txt` | AC-7 |
| `check-auth.sh` GREEN von außen, höchstens 8 Anfragen | `green.txt` | AC-8 |
| Exposure-Prüfung ohne Abweichung | `scan.txt` | AC-9 |
| `monitor.sh --status` vorher/nachher, kein Neustart anderer Dienste | `monitor-vorher.txt`, `monitor-nachher.txt` | AC-10 |
| Löschen echt lokal (Dienst-Ebene echt, App-Seite per `AccountSettingsTests`), live nur 401 | `loeschen-lokal.md`, `loeschen-live.txt` | AC-11 |
| `CLAUDE.md`, Vollständigkeit der Belege, Scan auf Wertmuster, Board | Belege-PR | AC-12 |

- [ ] Test 1 (AC-2): GIVEN unveränderter Stand WHEN `check-auth.sh` THEN Exit ≠ 0, `FEHLT` mit 404 an den neuen Pfaden.
- [ ] Test 2 (AC-5, AC-6): GIVEN die neue Datei WHEN `nginx -t` THEN `syntax is ok`, `test is successful`, danach `reload`.
- [ ] Test 3 (AC-7): GIVEN der Infra-Klon WHEN `python3 -m pytest tests -q` THEN grün (Konfigurations- und Exposure-Tests des Infra-Repos).
- [ ] Test 4 (AC-8): GIVEN geladene Datei WHEN `check-auth.sh` THEN Exit 0, acht Anfragen, kein 429.
- [ ] Test 5 (AC-10): GIVEN `monitor.sh --status` vorher/nachher WHEN `diff` THEN keine Zeile eines anderen Dienstes.
- [ ] Test 6 (AC-11): GIVEN lokaler Dienst mit Wegwerf-Datenbank WHEN `POST /auth/delete` mit gültiger Sitzung THEN 204, Zeilen weg, zweiter Aufruf 401; live ohne Sitzung 401.

**Ehrlich zur Belegkraft:** Die ACs 2, 5 bis 10 belegen nur, dass die Pfade offen sind und der Dienst nach außen richtig abweist. Dass sich ein echter Nutzer anmelden kann und dass die App-`sub` zur zugelassenen passt, belegt keine automatische Prüfung; dafür gibt es allein den Gerätelauf (unten). Das echte Löschen wird nie am Live-Dienst geprüft; AC-11 belegt es auf Dienst-Ebene echt und die App-Seite (Bestätigung, Abmelden danach) im Simulator mit dem Stellvertreter-Transport.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): drei exakte Pfade, Deploy vor nginx, Gerätelauf als Definition of Done** | siehe Purpose | Allowlist-Haltung bleibt; nie halb offen; früher echter Beleg App-`sub` = Web-`sub` | öffentlicher Endpunkt mit Abhängigkeit von Apples `sub`-Verhalten | — |
| **A1 `^~ /auth/` als Präfix durchreichen** | ein Block statt drei | weniger Zeilen | öffnet jeden künftigen Unterpfad ungeprüft; widerspricht der Allowlist aus #621 S6b | die Allowlist-Haltung der nginx-Datei (#621 S6b); verworfen |
| **A2 nur `/auth/apple` und `/auth/logout` öffnen, `/auth/delete` bleibt 404** | kein Löschen im Netz | keine Gefahr für das einzige Konto | die App bietet „Konto löschen“, das dann live scheitert; Apples Pflicht zur Kontolöschung wäre im Store-Bau verletzt | die 4c-Entscheidung „Löschen in der App“ (keine ADR); verworfen |
| **A3 Konto-Teil gar nicht live, nur gegen lokalen Dienst belegen, 4d mit #795 bündeln** | kein Netz-Schritt jetzt | weniger Betrieb | verschiebt den einzigen echten Beleg (App-`sub` = Web-`sub`), auf dem #795 aufbaut; kippt keine ADR, nur die Reihenfolge | die Reihenfolge der Schnitte von #615 (4d vor #795); verworfen |

Alternative zu A bleibt Hennings Entscheidung vom 2026-11-10 für das Löschen: Löschen auf dem Gerät mit anschließendem Neuverbinden des Konnektors statt nur lokal (verworfen, weil es sein einziges Konto trifft und nichts Neues belegt, was der lokale Lauf nicht auch belegt).

## Out of Scope / Folgeschnitte

- **Schnitt 4e:** Datenschutztext mit Konto-Teil (`docs/reference/datenschutz-entwurf.md`, Website-Repo), Freigabe durch Henning, danach `LEAccountEnabled` im Store-Bau.
- **#795:** App lädt die Abschrift hoch.
- **Dienstfixes, die der Betrieb offenlegt** (zum Beispiel abweichende App-`sub`, Zulassung beider Werte): eigene Schnitte.
- Änderungen an `server/src`, Migrationen, App, Widgets, Watch, Mac: keine.

## Abnahme

Der Schnitt selbst berührt keinen Pfad der Geräteliste (nur `henemm-infra`, `docs/artifacts/` und `CLAUDE.md`; kein `project.yml`, keine Entitlements, keine `Info.plist`). Kein App-Code wird geändert; Stufe 1 ist die Infra-Testsuite und der lokale Löschlauf am Dienst, Stufe 2 der Simulator-Beleg `test-proof AccountSettingsTests` (AC-11) für die App-Seite des Kontos; dazu die Abnahme von außen (`check-auth.sh` GREEN, Exposure-Prüfung). Weil der Dienst damit erstmals für die App erreichbar wird, folgt der Gerätelauf als Definition of Done über TestFlight (Henning, 2026-10-10, #279).

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt, Belege im Belegordner
- [ ] `check-auth.sh` Exit 0 von außen, `monitor.sh --status` für andere Dienste unverändert
- [ ] Infra-PR A und B gemergt (CI grün), Belege-PR gemergt (mit `Refs #615`), `CLAUDE.md` aktualisiert
- [ ] Kein Geheimniswert in Repo, Belegen, Protokoll oder Nachricht (Scan, 0 Treffer)
- [ ] #615 kommentiert (Stand 4d, Folge 4e), Board-Karte aktuell, Memory geschrieben

### Definition of Done (Gerätepunkte, Stufe 3)

Diese Punkte sind keine Akzeptanzkriterien (das QA-Gate kennt keinen Aufschub); sie schließen das Ticket, bis dahin bleibt #615 offen. Alles ist fertig gebaut, bevor Henning gerufen wird; er wartet nie auf Claude.

- [ ] TestFlight-Lauf mit `konto=true` ist gebaut, „Was testen“ nennt für Henning in einfachen Worten: Einstellungen › Claude › „Mit Apple anmelden“, danach „Abmelden“; was er sehen muss (Anmeldung ohne Fehlermeldung, nach dem Abmelden wieder der Apple-Knopf). Kein Löschen auf dem Gerät.
- [ ] Hennings Rückmeldung zum Anmelden und Abmelden liegt vor.
- [ ] Serverbeleg danach (nur Zählungen, nie eine `sub`): `accounts` = 1 (App-`sub` = Web-`sub`), eine Sitzungszeile ist entstanden und nach dem Abmelden beendet, das Protokoll enthält keine Zeile `account refused`, der Konnektor `get_now` geht weiterhin.
- [ ] Beleg `geraetelauf.md` im Belegordner (Zeitpunkt, Hennings Rückmeldung, Serverzählungen); der PR trägt `Refs #615`.

## Changelog

- 2026-11-10: Initial spec created (Schnitt 4d)
