---
entity_id: feat-796-schnitt-4a-betrieb
type: feature
created: 2026-11-03
updated: 2026-11-03
status: draft
workflow: feat-796-s4-hetzner-betrieb
---

# Spec: Dienst auf rennwienix betreiben und überwachen, Schnitt S4a (#796, Dienst auf Hetzner)

## Approval

- [ ] Approved

## GitHub Issue

#796 (Epic #612). Schnitt S4a; das Issue bleibt offen (`Refs #796`, nie `Closes #796`), es schließt erst nach S4b.
Analyse: `docs/context/feat-796-s4-hetzner-betrieb.md` (Abschnitt „Analysis“), Vorgängerkontext `docs/context/feat-796-dienst-hetzner.md`.
Vorgänger: S1 (PR #813, Spec `docs/specs/feat-796-schnitt-1-prozess-einstieg.md`), S2+S3 (PR #814, Spec `docs/specs/feat-796-schnitt-2-image-und-sperre.md`).
Grundlage der Zuständigkeit: Plan der Instanz `infra` in `henemm/henemm-infra` Issue #336 („Backend + MCP für Restock und Loose Ends auf diesem Server“).
Nicht Teil dieser Spec: nächtlicher `pg_dump` im restic-Backup und Rückspielprobe in eine leere Datenbank (S4b, eigener Workflow, eigene Teil-Spec), Öffnen von `/mcp` und Anmelderouten (#615, #621), GHCR und Automatik (#625).

## Purpose

Der Dienst aus `server/` hat seit S1 bis S3 einen Prozess-Einstieg, ein Container-Image und eine gesicherte Migration, läuft aber nirgends. Dieser Schnitt stellt ihn auf `rennwienix` bereit, unter `https://loose-ends.henemm.com/health`, und sorgt dafür, dass ein Ausfall gemeldet wird:

1. **Betrieb:** Compose-Stapel mit Dienst und `postgres:18.x` (harte Speichergrenzen, Postgres ohne Host-Port, Dienst nur auf `127.0.0.1`), ein Deploy-Skript, das aus einem festen Commit des öffentlichen Repos baut, und ein nginx-Host, der nur `/health` nach außen gibt.
2. **Überwachung:** eine Zeile in `monitor.sh`; Telegram-Meldung nur bei Zustandswechsel.
3. **Belege** der Definition of Done aus dem Ticket, soweit sie nicht die Sicherung betreffen: Adresse antwortet, Neustart und DB-Abbruch überstanden.

Der Server ist geteilt (Mail, n8n, Gregor, Frieda), der Speicher knapp (Swap fast voll, 2026-10-27: 1,6 von 2 GB). Deshalb gelten harte Grenzen für die Container, kein Reboot, kein Neustart fremder Dienste oder des Docker-Daemons, `nginx` nur mit `reload` nach `nginx -t`.

**Regeln vor Modell:** Compose, Skript, nginx, Überwachung: Konfiguration und Shell. Ein Sprachmodell ist nicht beteiligt; der Satz „Ohne Modell geht es nicht, weil …“ entfällt, es gibt keine Sprachaufgabe.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Weg B ist durch ADR-21 entschieden; dieser Schnitt rollt den Dienst nach dem Muster der bestehenden Dienste auf `rennwienix` aus (Compose wie n8n, vhost wie Frieda). Code-Transport und Überwachungsweg stehen unter „Alternativen“ und lassen sich später ändern.

## Source

**Files (Repo `henemm/henemm-infra`, privat):** `loose-ends/docker-compose.yml`, `scripts/deploy-loose-ends.sh`, `nginx/loose-ends.henemm.com.conf`, `scripts/monitor.sh`
**Files (Repo Loose Ends):** `CLAUDE.md`, `docs/artifacts/feat-796-s4-hetzner-betrieb/`
**Identifier:** Stapel `loose-ends` (Container `loose-ends-db`, `loose-ends-server`), Host `loose-ends.henemm.com`, Check `Loose-Ends`

Werte, die erst am Server feststehen, haben eine feste Bestimmungsregel (keine Platzhalter im Ergebnis):

- **Postgres-Kleinversion:** neueste `18.x` auf hub.docker.com/_/postgres am Tag des Baus (Analyse nennt 18.4 laut Drittquelle, nicht belegt). Die Version steht fest im Compose, kein `18`/`latest`; der Beleg nennt Datum und Quelle.
- **Host-Port des Dienstes:** zuerst lesend `ss -ltn` auf `rennwienix`; der kleinste freie Port im Bereich 8780–8799, der weder in `ss -ltn` noch in `docker ps`, nginx-Configs oder `/etc/systemd/system` vorkommt. Er steht dann im Compose und im nginx-Host und wird im Beleg genannt.
- **Commit des Dienstes:** der Stand von `main` im Repo `henemm/loose-ends` zum Zeitpunkt des Baus, als vollständiger SHA fest im Deploy-Skript (Variable `LE_COMMIT`); das Image heißt `loose-ends-server:<erste 7 Zeichen>`.

### `loose-ends/docker-compose.yml` (CREATE)

Nach dem Muster `n8n/docker-compose.yml` (feste Versionen, `127.0.0.1`, watchtower-Labels, Secrets als Datei unter `./secrets/`). Zwei Dienste, ein internes Netz `internal` (`internal: true`, kein Zugang nach außen und von außen):

- **`db`** (Container `loose-ends-db`): `image: postgres:18.<x>`; `restart: unless-stopped`; **keine** `ports:`; Volume `loose-ends-db:/var/lib/postgresql` (Pfad ab Postgres 18; `/var/lib/postgresql/data` ließe den Container mit Exit 1 enden); `POSTGRES_PASSWORD_FILE=/run/secrets/db_password` mit Secret aus `./secrets/db-password`; `POSTGRES_DB=looseends`, `POSTGRES_USER=looseends`; `command: ["postgres", "-c", "shared_buffers=128MB", "-c", "max_connections=20"]`; `mem_limit: 512m` und `memswap_limit: 512m` (kein Swap für die DB); Label `com.centurylinklabs.watchtower.enable=false` (Datenbank wird nie automatisch aktualisiert); `healthcheck` mit `pg_isready -U looseends -d looseends` (Takt 10 s, 5 Wiederholungen); json-file-Logrotation (`max-size: 10m`, `max-file: "3"`).
- **`server`** (Container `loose-ends-server`): `image: loose-ends-server:${LE_TAG}` (der Tag kommt vom Deploy-Skript, ohne Voreinstellung: fehlt er, bricht Compose ab); `restart: unless-stopped`; `ports: ["127.0.0.1:<Port>:8080"]`; `env_file: ./secrets/server.env` (enthält `DATABASE_URL=postgres://looseends:<Passwort>@db:5432/looseends`); `environment: NODE_OPTIONS=--max-old-space-size=256`; `mem_limit: 384m`, `memswap_limit: 384m`; `depends_on: db: condition: service_healthy`; Netze `internal` und `default` (nur dieses bekommt den veröffentlichten Port); watchtower-Labels wie n8n (`enable=true`, `monitor-only=true`); dieselbe Logrotation. Kein Compose-Healthcheck im `server` (das Image hat kein `curl`, Begründung wie S2); `/health` prüfen Deploy-Skript und `monitor.sh` von außen.
- Volumes: `loose-ends-db`. Secrets: `db_password` (Datei).
- Zusammen höchstens 896 MB hart begrenzt (512 + 384).

`loose-ends/secrets/` (`db-password`, `server.env`) entsteht nur auf dem Server, `chmod 700` für das Verzeichnis und `chmod 600` für die Dateien, Passwort zufällig erzeugt (`openssl rand -hex 24`), nie im Repo, nie in einem Log. Die Wurzel-`.gitignore` des Infra-Repos deckt `secrets/` nicht ab (geprüft 2026-11-03); nach dem Muster `n8n/.gitignore` bekommt `loose-ends/` eine eigene `.gitignore` mit der Zeile `secrets/` (fünfte Datei des PR).

### `scripts/deploy-loose-ends.sh` (CREATE)

Läuft von Hand auf `rennwienix` nach Freigabe (Konvention von `henemm-infra`), nie um 03:00 (Backup-Zeit; das Skript bricht zwischen 02:45 und 03:30 Ortszeit mit Meldung ab). `set -euo pipefail`. Ablauf:

1. Festes `LE_COMMIT` (vollständiger SHA) und Port im Kopf des Skripts; ein Skript, das nur auf einen anderen SHA zeigt, ist der Weg zu jedem späteren Stand (Änderung per PR im Infra-Repo).
2. Vorab `free -m` und `df -h /` ausgeben; weniger als 600 MB verfügbarer Speicher (`available`) oder weniger als 2 GB freie Platte: Abbruch mit Meldung, nichts gebaut.
3. Öffentlichen Checkout `https://github.com/henemm/loose-ends.git` nach `/srv/loose-ends-src` holen (`git fetch`, `git checkout --detach "$LE_COMMIT"`), danach prüfen, dass `git rev-parse HEAD` der Wert ist.
4. `nice -n 19 docker build -t loose-ends-server:${LE_COMMIT:0:7} /srv/loose-ends-src/server`.
5. `LE_TAG=${LE_COMMIT:0:7} docker compose -f /home/hem/henemm-infra/loose-ends/docker-compose.yml up -d` (der Pfad des Checkouts auf dem Server steht im Skript als Variable, abgeleitet vom Skriptort).
6. Bis zu 60 s im Sekundentakt `curl --silent --output /dev/null --write-out '%{http_code}' http://127.0.0.1:<Port>/health`; bei 200 Erfolg, Ausgabe des Bodys. Sonst die letzten 50 Logzeilen des Dienstes ausgeben und Exit ≠ 0 (der Stapel bleibt, wie er ist; Zurückrollen ist ein neuer Aufruf mit dem vorherigen SHA).
7. Alte `loose-ends-server`-Images außer den zwei jüngsten entfernen (Platte), nie andere Images.

Das Skript startet oder stoppt nichts außerhalb des Stapels `loose-ends`.

### `nginx/loose-ends.henemm.com.conf` (CREATE)

Versionierte Kopie, von Hand installiert (nach `docs/deploy.md`), Vorlage `nginx/frieda.henemm.com.conf`:

- `server_name loose-ends.henemm.com;` `include snippets/security-headers.conf;` `gzip off;`
- `location = /health { limit_req zone=loose_ends_health burst=10 nodelay; limit_req_status 429; proxy_pass http://127.0.0.1:<Port>; …Standard-Proxy-Header… }`. Die Zone `loose_ends_health` (z. B. `limit_req_zone $binary_remote_addr zone=loose_ends_health:1m rate=30r/m;`, `monitor.sh` fragt alle 5 min) steht in einer eigenen `conf.d`-Datei oder am Kopf dieser Datei, je nachdem, wo die bestehenden Zonen liegen; der Ort wird vor dem Anlegen gelesen und der Beleg nennt ihn.
- `location = /mcp { return 404; }` und `location / { return 404; }`: nichts anderes geht nach außen, bis Anmeldung (#615) und Konnektor (#621) da sind. Die Datei trägt einen Kommentar mit dieser Bedingung.
- Reihenfolge der Inbetriebnahme: (1) Kopie nach `sites-available`, Link nach `sites-enabled`, zunächst **nur der Port-80-Block** (`listen 80; server_name …; location / { return 404; }`, `location /.well-known/acme-challenge/` bedient certbot); `nginx -t`; `systemctl reload nginx` (nie `restart`). (2) Vor `certbot` `dig +short loose-ends.henemm.com` muss `178.104.143.19` ergeben (Henning trägt den A-Eintrag selbst bei Namecheap ein: Host `loose-ends`, TTL Automatic, kein AAAA); fehlt er, wartet der Ablauf, der Port-80-Block darf schon stehen. (3) `certbot --nginx -d loose-ends.henemm.com`; (4) erneut `nginx -t` und `reload`. Die vollständige Datei im Repo enthält die von certbot verwalteten 443-Blöcke wie die Frieda-Vorlage.

### `scripts/monitor.sh` (MODIFY)

Eine Zeile in `HTTP_CHECKS` (nach `Kotoba`): `"https://loose-ends.henemm.com/health|200|Loose-Ends"`. Die vorhandene Schleife nutzt `alert_on_change "http-Loose-Ends" …`: Telegram nur bei Wechsel `ok` → `fail` und zurück, keine Dauermeldung. Die Zeile wird erst gemergt und damit aktiv (Auto-Deploy, 5 min), wenn der Dienst nach AC-1 läuft; sonst meldet `monitor.sh` einen Ausfall, den es nicht gibt.

### Loose-Ends-Repo

- `CLAUDE.md`: eine Zeile „Betrieb“ im Abschnitt zu `server/`: Adresse `https://loose-ends.henemm.com` (nur `/health` öffentlich), Stapel und nginx-Host in `henemm-infra` (`loose-ends/`, `nginx/loose-ends.henemm.com.conf`), Ausrollen per `scripts/deploy-loose-ends.sh` auf `rennwienix` von Hand mit festem Commit.
- Belege unter `docs/artifacts/feat-796-s4-hetzner-betrieb/` (Textdateien mit Befehl und Ausgabe, je AC eine Datei, Zeitstempel).

### Abstimmung mit `infra`

Die Instanz `infra` ist von hier nicht per SendMessage erreichbar. Weg: ein Kommentar an `henemm/henemm-infra` Issue #336 mit Schnitt, vier Dateien, Port, Speichergrenzen und der Zeile in `monitor.sh`, danach die Änderungen als Pull Request im Infra-Repo. Gemergt wird nach den üblichen Prüfungen dort; der Kommentar steht vor dem PR.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/Dockerfile`, `server/src/main.ts`, `server/src/health.ts` (S1, S2) | bestehend, **unverändert**; das Image startet `main.ts`, `/health` 200 nur nach migrate + `SELECT 1`, 503 bei DB-Ausfall |
| `henemm/loose-ends` öffentlich (Checkout ohne Zugangsdaten) | extern, bestehend |
| A-Eintrag `loose-ends` → `178.104.143.19` bei Namecheap (keine API) | extern, **Henning**; 2026-11-03 leer; ohne ihn kein Zertifikat, damit AC-1 bis AC-3 nicht von außen belegbar |
| Docker, `docker compose`, `postgres:18.x`, `certbot`, `nginx`, Telegram/`monitor.sh` auf `rennwienix` | bestehend |
| Hennings Freigabe für Schreibzugriff (2026-11-03, S4a und S4b) | erteilt; Grenzen: kein Reboot, kein Neustart anderer Dienste, kein Neustart des Docker-Daemons, nginx nur `reload` nach `nginx -t` |
| Instanz `infra`, henemm-infra#336 | Abstimmung per Kommentar und PR |

## Acceptance Criteria

Alle Belege entstehen aus echten Läufen auf `rennwienix` bzw. von außen und liegen als Textdatei (Befehl, Ausgabe, Uhrzeit) unter `docs/artifacts/feat-796-s4-hetzner-betrieb/`. Zuerst der Nachweis „vorher“ (RED): `dig +short loose-ends.henemm.com` leer und `curl https://loose-ends.henemm.com/health` scheitert; erst danach wird angelegt.

- **AC-1:** `curl --silent --show-error --fail https://loose-ends.henemm.com/health` (ohne `-k`, von außerhalb des Servers) liefert 200; der Body hat `status` „ok“, `db` „up“, `migrated` true; das Zertifikat ist gültig (`curl -v` zeigt `SSL certificate verify ok`, Aussteller und Ablaufdatum werden festgehalten). Beleg: `ac1-health.txt`. Vorher-Beleg (RED): `ac1-vorher.txt` mit leerem `dig` und fehlgeschlagenem `curl`.
- **AC-2:** Von außen: `GET /mcp` und `GET /irgendein-pfad` liefern 404. Auf dem Server: Postgres hat keinen Host-Port (`docker port loose-ends-db` leer; `ss -ltn` zeigt gegenüber der Ausgabe vor dem Schnitt keinen neuen Listener außer dem Dienst-Port auf `127.0.0.1`); der Dienst lauscht nur auf `127.0.0.1:<Port>` (`ss -ltn`, keine Zeile `0.0.0.0:<Port>` oder `*:<Port>`). Beleg: `ac2-zugang.txt`.
- **AC-3:** Die Speichergrenzen wirken: `docker inspect --format '{{.HostConfig.Memory}} {{.HostConfig.MemorySwap}}'` zeigt für `loose-ends-db` zweimal `536870912` und für `loose-ends-server` zweimal `402653184`; `NODE_OPTIONS` im Dienst enthält `--max-old-space-size=256` (`docker exec … printenv`); die Postgres-Einstellungen stimmen (`SHOW shared_buffers` = `128MB`, `SHOW max_connections` = `20`). Beleg: `ac3-grenzen.txt`.
- **AC-4:** Neustart überstanden: `docker compose restart server` und danach `/health` binnen 60 s wieder 200; `docker kill loose-ends-server` und die Restart-Policy bringt den Container zurück (neues `StartedAt`, Status `running`), `/health` binnen 60 s 200. Beleg: `ac4-neustart.txt` mit Zeitstempeln und `StartedAt` vorher/nachher.
- **AC-5:** DB-Abbruch überstanden: `docker compose stop db` und `/health` liefert 503 (Body `db` „down“), während `StartedAt` des Dienst-Containers gleich bleibt (kein Dienst-Neustart); `docker compose start db` und `/health` binnen 60 s wieder 200, `StartedAt` des Dienstes unverändert. Beleg: `ac5-db-abbruch.txt`.
- **AC-6:** Überwachung: Die Zeile `https://loose-ends.henemm.com/health|200|Loose-Ends` steht in `HTTP_CHECKS`; ein von Hand gestarteter Lauf von `monitor.sh` bei laufendem Dienst meldet nichts (kein Telegram, Zeile „Loose-Ends (200)“ im Lauf). **Belegbar und belegt wird:** das Verhalten der Zustandsmaschine `alert_on_change` mit `http-Loose-Ends`, indem derselbe Lauf während der DB-Abbruch-Probe aus AC-5 von Hand angestoßen wird (Status 503, Zustand wechselt auf `fail`, Meldungstext und Zustandsdatei im Beleg; zweiter Lauf im selben Zustand meldet nicht erneut) und nach `start db` erneut (Zustand `ok`, Erholungsmeldung). Ob die Telegram-Nachricht beim Empfänger ankommt, belegt die Zustandsdatei und der Telegram-Sendeaufruf im Log nur auf Senderseite; die Ankunft bestätigt Henning, falls er die Meldung sieht, und das steht im Beleg als solches (kein Haken ohne Sicht). Beleg: `ac6-ueberwachung.txt`.
- **AC-7:** Andere Dienste unberührt: Vor und nach jedem `nginx`-Reload ist `nginx -t` ok und der HTTPS-Abruf von `https://frieda.henemm.com/gesund` und `https://n8n.henemm.com` (beide in `monitor.sh` bzw. im Betrieb) liefert denselben Statuscode wie vorher; `StartedAt` aller anderen laufenden Container (`docker ps` gesamt) ist vor und nach dem Schnitt gleich; kein `restart` von nginx, Docker oder einem fremden Dienst im Verlauf (Auszug `systemctl show nginx -p ActiveEnterTimestamp` bleibt unverändert, `reload` ändert es nicht). Beleg: `ac7-unberuehrt.txt`.
- **AC-8:** Secrets: `loose-ends/secrets/` hat Modus 700, `db-password` und `server.env` Modus 600 (`stat -c '%a %n'`); im Checkout des Infra-Repos ist der Pfad ignoriert (`git check-ignore -v loose-ends/secrets/server.env` liefert eine Treffer-Zeile) und erscheint nicht in `git ls-files`; die Logs beider Container (`docker logs`) enthalten weder `postgres://` noch das Passwort (`grep -c` ergibt 0 für beide). Beleg: `ac8-secrets.txt` (ohne den Wert des Passworts).
- **AC-9:** Dateiliste: Der Pull Request im Infra-Repo enthält genau `loose-ends/docker-compose.yml`, `scripts/deploy-loose-ends.sh`, `nginx/loose-ends.henemm.com.conf` und `scripts/monitor.sh` und `loose-ends/.gitignore` (eine Zeile `secrets/`); der Diff von `monitor.sh` ist genau eine Zeile; der Diff im Loose-Ends-Repo enthält nur `CLAUDE.md` und Dateien unter `docs/` (Specs, Context, Artifacts, Briefings); `server/`, `project.yml`, `.github/` und jede Swift-Datei bleiben unberührt. Beleg: `ac9-dateiliste.txt` (beide Diffstat-Ausgaben).
- **AC-10:** Das Deploy-Skript ist wiederholbar und sicher: ein zweiter Lauf mit demselben Commit baut aus dem Cache, verändert die laufenden Container nicht unnötig (Dienst-`StartedAt` bleibt, wenn das Image gleich ist) und endet mit Exit 0 und `/health` 200; ein Lauf mit zu wenig Speicher (simuliert über die Schwellvariable, nicht über echten Speichermangel) bricht ab, ohne etwas zu bauen oder zu starten. `bash -n scripts/deploy-loose-ends.sh` und `shellcheck`, falls auf dem Server vorhanden, sind ohne Befund. Beleg: `ac10-deploy-skript.txt`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `loose-ends/docker-compose.yml` (Infra) | CREATE | `db` und `server`, internes Netz, Grenzen, Logrotation, watchtower; ≈ +70 |
| `scripts/deploy-loose-ends.sh` (Infra) | CREATE | fester Commit, Vorprüfung, `nice` Bau, `compose up`, Wartezeit auf `/health`; ≈ +45 |
| `nginx/loose-ends.henemm.com.conf` (Infra) | CREATE | `/health` mit `limit_req`, sonst 404, security-headers, certbot-Blöcke; ≈ +35 |
| `scripts/monitor.sh` (Infra) | MODIFY | eine Zeile in `HTTP_CHECKS`; ≈ +1 |
| `loose-ends/.gitignore` (Infra) | CREATE | `secrets/` nach Muster `n8n/.gitignore`; +1 |
| `CLAUDE.md` (Loose Ends) | MODIFY | eine Zeile „Betrieb“; ≈ +1 |
| `docs/artifacts/feat-796-s4-hetzner-betrieb/` (Loose Ends) | CREATE | Belege AC-1 bis AC-10 |

### Estimated Changes

- Dateien im Infra-Repo: 5 (Limit 4–5, davon `loose-ends/.gitignore` mit einer Zeile); im Loose-Ends-Repo nur `CLAUDE.md` und `docs/`.
- LoC: ≈ +150 Konfiguration und Shell, keine Unit-Tests (siehe Test Plan). Unter 250. Jede Shell-Funktion ≤ 50 Zeilen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neue Migration, keine neuen Pakete, kein `generate`. Seiteneffekte außerhalb des Tickets: ein neuer nginx-Host und ein Reload auf dem geteilten Server (abgesichert durch AC-7), zwei neue Container (abgesichert durch AC-3), eine Zeile Überwachung. Sicherung und Rückspielprobe: nicht in diesem Schnitt.

## Test Plan

Dieser Schnitt ändert Konfiguration und Betrieb. **Keine Unit- und keine UI-Tests in diesem Repo:** es gibt keinen Code mit Logik, den ein Test vor dem Bau prüfen könnte; Swift und `server/` bleiben unberührt, ihre Suiten (S1 bis S3) laufen unverändert. Die „RED“-Phase ist der Nachweis vorher.

- [ ] RED (AC-1): vor dem Anlegen `dig +short loose-ends.henemm.com` (leer, 2026-11-03 geprüft) und `curl --fail https://loose-ends.henemm.com/health` (scheitert) als `ac1-vorher.txt` ablegen; ebenso Ausgabe `docker ps`, `ss -ltn` und `StartedAt` aller Container als Ausgangsstand für AC-2 und AC-7.
- [ ] GREEN: Reihenfolge der Inbetriebnahme: `free -m`/`df -h`; Port bestimmen; Secrets anlegen; Compose und Skript über den Infra-PR (Auto-Deploy) oder per Checkout auf den Server; `deploy-loose-ends.sh` einmal von Hand (nicht um 03:00); nginx Port-80-Block, `nginx -t`, `reload`; DNS-Prüfung; certbot; `nginx -t`, `reload`; vollständige Datei; `monitor.sh`-Zeile erst nach AC-1.
- [ ] Prüfung AC-1 bis AC-5, AC-7, AC-8, AC-10: Befehle laut ACs, Ausgabe unter `docs/artifacts/feat-796-s4-hetzner-betrieb/`.
- [ ] Prüfung AC-6: `monitor.sh` von Hand bei laufendem Dienst (still), dann während der DB-Abbruch-Probe (Zustandswechsel), dann nach `start db` (Erholung). Reihenfolge zusammen mit AC-5, damit der Dienst nur einmal gestört wird.
- [ ] Prüfung AC-9: Diffstat beider Repos.
- [ ] Grenze: Der Schnitt kann auf der Maschine dieses Workflows nur über SSH-Zugriff auf `rennwienix` belegt werden. Ist der Zugriff nicht möglich, ist AC-1 bis AC-8 und AC-10 nicht belegt und das wird im Abschlussbericht so benannt, ohne Haken. Für die Ankunft einer Telegram-Meldung gilt die Einschränkung in AC-6.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Frage | Gewählt | Alternative | Warum nicht |
|---|---|---|---|
| Image-Herkunft | Bau auf dem Server aus öffentlichem Checkout an festem Commit | CI baut nach GHCR, Server zieht per Digest | erstes Paket ist privat, nur in der Web-Oberfläche öffentlich zu stellen; zusätzlicher `packages: write`-Pfad; Vorteil (kein Bau auf dem knappen Server) kommt mit #625 (eigener Server, Automatik) |
| Betriebsart | Docker Compose wie n8n | systemd mit eigenem Node 26 unter Dienstnutzer | zwei Betriebsarten, systemweit liegt Node 18; Container isoliert den Speicher hart |
| Überwachung | Zeile in `monitor.sh` | eigener Betterstack-URL-Monitor | 7 von 10 Plätzen belegt, `infra` will höchstens einen; `monitor.sh` meldet über Telegram ebenso, bei Totalausfall des Servers greift der geteilte Heartbeat ohnehin |
| Zugangsdaten | `env_file: ./secrets/server.env`, `chmod 600` | Passwortdatei (`DATABASE_URL_FILE`) | bräuchte Änderung an `main.ts`; Risiko wie bei n8n, daher `env_file` |
| Außenzugang | nginx-Host, nur `/health` | Port des Dienstes direkt öffnen oder `/mcp` schon durchreichen | Port 80/443 gehören nginx; `/mcp` hat ohne Anmeldung kein Konto (#615/#621) |
| Datenbank-Updates | feste `postgres:18.x`, watchtower aus | `postgres:18` mit Beobachtung | wandernder Tag ändert die Kleinversion unbemerkt; Major-Sprünge brauchen Dump und Rückspielen |
| Speicher | harte Grenzen mit Swap-Deckel (zusammen ≤ 896 MB) | keine Grenzen / Server aufstocken (CPX42, in #336 vertagt) | ohne Grenzen kann ein Ausreißer Mail und n8n verdrängen |
| Schnittgrenze | S4a Betrieb und Überwachung, S4b Sicherung | alles in einem | sechs Dateien über dem Limit; die Rückspielprobe braucht echte Tabellen aus S4a |

## Nicht in diesem Schnitt / Folgeschnitte

- **S4b** (eigener Workflow, eigene Teil-Spec): `scripts/backup.sh` bekommt den `pg_dump -Fc` vor restic mit Readiness-Prüfung (`pg_restore --list`) und 30 Tagen Aufbewahrung; `scripts/restore-test-loose-ends.sh` spielt den jüngsten Dump in einen Wegwerf-Container zurück und vergleicht Zeilenzahlen je Tabelle. Das Ticket #796 schließt erst danach.
- `/mcp` bleibt am Netzrand gesperrt bis #615 und #621.
- GHCR-Bau und automatisches Ausrollen: #625.
- Aufstocken des Servers (CPX42): vertagt in henemm-infra#336.

## Abnahme

- Stufe 1: entfällt für Code (keiner geändert); `bash -n` für das Skript, `nginx -t` für den Host, `docker compose config` für die Compose-Datei laufen vor dem Anlegen und stehen im Beleg.
- Stufe 2: echter Lauf als Nutzer des Dienstes auf `rennwienix` und von außen: AC-1 bis AC-8 und AC-10 mit den Belegen oben. Dazu der Beleg von `./scripts/sim.sh test-proof CaptureSmokeTests` für `phase8_complete`; er zeigt nur, dass die App auf dem Stand startet, ein Bedienablauf für den Dienst existiert in der App nicht.
- Stufe 3: entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt, Belege unter `docs/artifacts/feat-796-s4-hetzner-betrieb/`
- [ ] Vorher-Nachweis (RED) abgelegt
- [ ] Kommentar an henemm-infra#336 vor dem Infra-PR, Infra-PR mit genau den Dateien aus AC-9 gemergt
- [ ] `https://loose-ends.henemm.com/health` antwortet 200 mit gültigem Zertifikat; `monitor.sh` aktiv
- [ ] Andere Dienste unberührt belegt (AC-7)
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #796 kommentiert (Stand S4a, S4b offen), Board-Karte aktuell; Issue bleibt offen

## Known Limitations

- **AC-4, Auslöser des Absturzes:** `docker kill loose-ends-server` taugt nicht, um die Restart-Policy zu belegen. Docker wertet es als manuelles Anhalten, `unless-stopped` startet den Container danach nicht neu (Befund 2026-11-03, Docker Engine 29.9.1: Exit 137, `RestartCount` 0, Status `exited`; Doku: https://docs.docker.com/engine/containers/start-containers-automatically/). Der Absturz wird deshalb mit `kill -9` der Prozess-ID des Containers auf dem Host nachgestellt (`docker inspect -f '{{.State.Pid}}'`); Beleg in `ac4-neustart.txt`, der `docker kill`-Versuch steht dort als Befund.

## Changelog

- 2026-11-03: Initial spec created (Schnitt S4a)
- 2026-11-03: Known Limitations: Auslöser für AC-4 Teil 2 (`kill -9` der Prozess-ID statt `docker kill`)
