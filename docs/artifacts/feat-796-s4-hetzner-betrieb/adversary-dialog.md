# Adversary Dialog — feat-796-s4-hetzner-betrieb
Spec: docs/specs/feat-796-schnitt-4a-betrieb.md
Datum: 2026-11-03 17:30

## Checkliste
- [x] **AC-1:** `curl --silent --show-error --fail https://loose-ends.henemm.com/health` (ohne `-k`, von außerhalb des Servers) liefert 200; der Body hat `status` „ok“, `db` „up“, `migrated` true; das Zertifikat ist gültig (`curl -v` zeigt `SSL certificate verify ok`, Aussteller und Ablaufdatum werden festgehalten). Beleg: `ac1-health.txt`. Vorher-Beleg (RED): `ac1-vorher.txt` mit leerem `dig` und fehlgeschlagenem `curl`.
- [x] **AC-2:** Von außen: `GET /mcp` und `GET /irgendein-pfad` liefern 404. Auf dem Server: Postgres hat keinen Host-Port (`docker port loose-ends-db` leer; `ss -ltn` zeigt gegenüber der Ausgabe vor dem Schnitt keinen neuen Listener außer dem Dienst-Port auf `127.0.0.1`); der Dienst lauscht nur auf `127.0.0.1:<Port>` (`ss -ltn`, keine Zeile `0.0.0.0:<Port>` oder `*:<Port>`). Beleg: `ac2-zugang.txt`.
- [x] **AC-3:** Die Speichergrenzen wirken: `docker inspect --format '{{.HostConfig.Memory}} {{.HostConfig.MemorySwap}}'` zeigt für `loose-ends-db` zweimal `536870912` und für `loose-ends-server` zweimal `402653184`; `NODE_OPTIONS` im Dienst enthält `--max-old-space-size=256` (`docker exec … printenv`); die Postgres-Einstellungen stimmen (`SHOW shared_buffers` = `128MB`, `SHOW max_connections` = `20`). Beleg: `ac3-grenzen.txt`.
- [x] **AC-4:** Neustart überstanden: `docker compose restart server` und danach `/health` binnen 60 s wieder 200; `docker kill loose-ends-server` und die Restart-Policy bringt den Container zurück (neues `StartedAt`, Status `running`), `/health` binnen 60 s 200. Beleg: `ac4-neustart.txt` mit Zeitstempeln und `StartedAt` vorher/nachher.
- [x] **AC-5:** DB-Abbruch überstanden: `docker compose stop db` und `/health` liefert 503 (Body `db` „down“), während `StartedAt` des Dienst-Containers gleich bleibt (kein Dienst-Neustart); `docker compose start db` und `/health` binnen 60 s wieder 200, `StartedAt` des Dienstes unverändert. Beleg: `ac5-db-abbruch.txt`.
- [x] **AC-6:** Überwachung: Die Zeile `https://loose-ends.henemm.com/health|200|Loose-Ends` steht in `HTTP_CHECKS`; ein von Hand gestarteter Lauf von `monitor.sh` bei laufendem Dienst meldet nichts (kein Telegram, Zeile „Loose-Ends (200)“ im Lauf). **Belegbar und belegt wird:** das Verhalten der Zustandsmaschine `alert_on_change` mit `http-Loose-Ends`, indem derselbe Lauf während der DB-Abbruch-Probe aus AC-5 von Hand angestoßen wird (Status 503, Zustand wechselt auf `fail`, Meldungstext und Zustandsdatei im Beleg; zweiter Lauf im selben Zustand meldet nicht erneut) und nach `start db` erneut (Zustand `ok`, Erholungsmeldung). Ob die Telegram-Nachricht beim Empfänger ankommt, belegt die Zustandsdatei und der Telegram-Sendeaufruf im Log nur auf Senderseite; die Ankunft bestätigt Henning, falls er die Meldung sieht, und das steht im Beleg als solches (kein Haken ohne Sicht). Beleg: `ac6-ueberwachung.txt`.
- [x] **AC-7:** Andere Dienste unberührt: Vor und nach jedem `nginx`-Reload ist `nginx -t` ok und der HTTPS-Abruf von `https://frieda.henemm.com/gesund` und `https://n8n.henemm.com` (beide in `monitor.sh` bzw. im Betrieb) liefert denselben Statuscode wie vorher; `StartedAt` aller anderen laufenden Container (`docker ps` gesamt) ist vor und nach dem Schnitt gleich; kein `restart` von nginx, Docker oder einem fremden Dienst im Verlauf (Auszug `systemctl show nginx -p ActiveEnterTimestamp` bleibt unverändert, `reload` ändert es nicht). Beleg: `ac7-unberuehrt.txt`.
- [x] **AC-8:** Secrets: `loose-ends/secrets/` hat Modus 700, `db-password` und `server.env` Modus 600 (`stat -c '%a %n'`); im Checkout des Infra-Repos ist der Pfad ignoriert (`git check-ignore -v loose-ends/secrets/server.env` liefert eine Treffer-Zeile) und erscheint nicht in `git ls-files`; die Logs beider Container (`docker logs`) enthalten weder `postgres://` noch das Passwort (`grep -c` ergibt 0 für beide). Beleg: `ac8-secrets.txt` (ohne den Wert des Passworts).
- [x] **AC-9:** Dateiliste: Der Pull Request im Infra-Repo enthält genau `loose-ends/docker-compose.yml`, `scripts/deploy-loose-ends.sh`, `nginx/loose-ends.henemm.com.conf` und `scripts/monitor.sh` und `loose-ends/.gitignore` (eine Zeile `secrets/`); der Diff von `monitor.sh` ist genau eine Zeile; der Diff im Loose-Ends-Repo enthält nur `CLAUDE.md` und Dateien unter `docs/` (Specs, Context, Artifacts, Briefings); `server/`, `project.yml`, `.github/` und jede Swift-Datei bleiben unberührt. Beleg: `ac9-dateiliste.txt` (beide Diffstat-Ausgaben).
- [x] **AC-10:** Das Deploy-Skript ist wiederholbar und sicher: ein zweiter Lauf mit demselben Commit baut aus dem Cache, verändert die laufenden Container nicht unnötig (Dienst-`StartedAt` bleibt, wenn das Image gleich ist) und endet mit Exit 0 und `/health` 200; ein Lauf mit zu wenig Speicher (simuliert über die Schwellvariable, nicht über echten Speichermangel) bricht ab, ohne etwas zu bauen oder zu starten. `bash -n scripts/deploy-loose-ends.sh` und `shellcheck`, falls auf dem Server vorhanden, sind ohne Befund. Beleg: `ac10-deploy-skript.txt`.

## Dialog

### Runde 1
**Adversary:** Eigene, lesende Nachpruefung von aussen und per ssh (2026-11-03, Rohausgabe in adversary-test-output.txt). Kein Unit-Testlauf: Infra-Schnitt, Swift und server/ unberuehrt (Diff nur CLAUDE.md und docs/).
- AC-1: curl ohne -k: HTTP 200, Body status ok, db up, migrated true; "SSL certificate verify ok", Aussteller Let's Encrypt YE1, Ablauf 2027-02-01.
  Confirmation: AC-1
  Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/nginx/loose-ends.henemm.com.conf:37 (443-Block mit certbot-Zertifikat), Status CONFIRMED.
- AC-2: /mcp 404, /irgendwas 404, /health/ 404, /secrets 404; http:80 -> 301 auf https. Server: `docker port loose-ends-db` leer (nur 5432/tcp intern), ss zeigt nur 127.0.0.1:8780, keine 5432-Zeile, Netz loose-ends_internal Internal=true.
  Confirmation: AC-2
  Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/loose-ends/docker-compose.yml:44 (ports 127.0.0.1:8780:8080, db ohne ports), Status CONFIRMED.
- AC-3: mem/swap db 536870912/536870912, server 402653184/402653184; NODE_OPTIONS=--max-old-space-size=256; shared_buffers 128MB, max_connections 20, Version 18.6; Volume-Mount auf /var/lib/postgresql; Logrotation 10m/3; watchtower db=false, server=true; unless-stopped.
  Confirmation: AC-3
  Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/loose-ends/docker-compose.yml:23 (mem_limit/memswap_limit), Status CONFIRMED.
- AC-8: Modi 700/600/600; check-ignore trifft loose-ends/.gitignore:1 `secrets/`; git ls-files loose-ends zeigt nichts unter secrets; grep -c "postgres://" in beiden Container-Logs = 0 (Passwort-Grep nicht ausfuehrbar, ohne den Wert zu lesen; Secrets-Sperre respektiert, hier nur Beleg-basiert).
  Confirmation: AC-8
  Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/loose-ends/.gitignore:1, Status CONFIRMED.
- Dateitreue: sha256 aller 5 Dateien lokal == Server-Worktree; installierter nginx-Host == Repo-Datei (3cd64dca...); Link in sites-enabled vorhanden. `bash -n` ok. monitor.sh-Diff genau 1 Zeile.
  Confirmation: AC-9
  Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/scripts/monitor.sh:62 (genau eine neue Zeile in HTTP_CHECKS), Status CONFIRMED. Loose-Ends-Diff nur CLAUDE.md + docs/; server/, project.yml, .github unberuehrt.

Finding F001: Severity MEDIUM, Category edge_case
Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/loose-ends/docker-compose.yml:67 (secrets-Datei und env_file relativ ./secrets/). Beschreibung: Die Secrets liegen nur unter /home/hem/henemm-infra-le796/loose-ends/secrets; das db-Bind-Mount zeigt dorthin. /home/hem/henemm-infra/loose-ends existiert nicht. Spec-Bezug AC-10 (wiederholbar) und Pfad vom Skriptort abgeleitet. Konflikt: Nach Merge/Auto-Deploy in /home/hem/henemm-infra bricht der naechste Deploy-Lauf dort fail-closed im Preflight ab (Env-Datei fehlt, deploy-loose-ends.sh:41), bis die Secrets dort liegen; beim Umziehen wird der db-Container neu angelegt (Volume bleibt). Kein Defekt im Ist-Stand. Remediation: nach Merge Secrets in den endgueltigen Checkout verlegen und Deploy dort wiederholen, im Beleg vermerken.

Finding F002: Severity LOW, Category security
Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/nginx/loose-ends.henemm.com.conf:20 (location = /health ohne limit_except). Beschreibung: POST /health und /health?x=1 liefern 200. Spec verlangt nur /health nach aussen, kein Schaden (read-only, limit_req greift). Remediation: optional `limit_except GET { deny all; }`.
**Implementierer:** (nicht beteiligt, Isolation)

### Runde 2
**Adversary:** Gezielte Angriffe auf Grenzfaelle der Skriptlogik und Belege.
- Zeitfenster: Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/scripts/deploy-loose-ends.sh:29. `10#$now` >= 245 und < 330, TZ=Europe/Berlin; fuehrende Null korrekt, 0000-0244 und 0330 ausserhalb; wie Spec.
- Schwellen: available (free -m Spalte 7) < 600 MB oder < 2 GB Platte bricht vor fetch/build ab; per LE_MIN_MEM_MB/LE_MIN_DISK_GB simulierbar. Aktuell 4122 MB available, 19 GB frei.
- Image-Aufraeumen: deploy-loose-ends.sh:70-80 filtert `docker images loose-ends-server`, behaelt zwei juengste, `image rm` ohne -f; fremde Images unberuehrt.
- Das Skript wirkt nur per `docker compose -f` auf den Stapel (`name: loose-ends`); LE_TAG ohne Default bricht ab.
- Belege ac4 bis ac7, ac10 gelesen/abgeglichen mit Serverzustand: Server StartedAt 15:37:08Z, db 15:51:22Z (zu AC-5 passend), nginx ActiveEnterTimestamp 2026-10-28 unveraendert, kein nginx-Restart. AC-4 Known Limitation (kill -9 statt docker kill) in der Spec dokumentiert, akzeptiert.
  Confirmation: AC-4
  Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/loose-ends/docker-compose.yml:12 (restart: unless-stopped), Status CONFIRMED (Beleg-basiert, Ausloesen verboten).
  Confirmation: AC-5
  Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/loose-ends/docker-compose.yml:50 (depends_on service_healthy; kein Dienst-Healthcheck, kein Dienst-Neustart), Status CONFIRMED (Beleg-basiert).
  Confirmation: AC-6
  Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/scripts/monitor.sh:62 (Zeile aktiv; Zustandsmaschine per Beleg, Telegram-Ankunft nur senderseitig wie Spec erlaubt; Entscheidung "kritisch" dokumentiert), Status CONFIRMED.
  Confirmation: AC-7
  Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/nginx/loose-ends.henemm.com.conf:1 (eigener Host, nur reload), Status CONFIRMED.
  Confirmation: AC-10
  Code reference: /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/scripts/deploy-loose-ends.sh:26 (preflight vor Bau; bash -n ok; shellcheck nicht erneut gelaufen), Status CONFIRMED.
- Rate-Limit loose_ends_health 30r/m burst 10 nodelay, 429; monitor alle 5 min unkritisch; Zone in eigener Datei (Spec erlaubt, Kommentar nennt Ort); keine Namenskollision in conf.d.
- AC-9: PR fehlt, Dateimenge (5 Infra + CLAUDE.md/docs) und 1-Zeilen-Diff stimmen; vom Auftrag als entschieden vorgegeben.
**Implementierer:** (nicht beteiligt)


## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:71c1a23e67706c2468b62fd8935e96b5c0b6b3e5eca3cccbc48e7191c7677ccd  /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/loose-ends/.gitignore
- sha256:33b585f4040bc6c2801defccf1c85db93c6b278418df8c6637395a417e7812d6  /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/loose-ends/docker-compose.yml
- sha256:3cd64dca75cb2fabf08abb63b6440d7a88b3b3454bff4eb76fa3ba4c64872529  /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/nginx/loose-ends.henemm.com.conf
- sha256:4455db7de384cf61ea30235bdc9b8b60d79297a5c7356804b833a3d8c75bb15d  /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/scripts/deploy-loose-ends.sh
- sha256:09b8bee36b9256c95330c049a3deb251c7ac382a4e15a346682dcbc8845ccf5a  /private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-rosy-pondering-engelbart/58de4aae-75a4-40ff-9123-677b0011b2fb/scratchpad/henemm-infra/scripts/monitor.sh
