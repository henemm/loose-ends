# Context: feat-966-eigener-server

## Request Summary
Der Dienst für Claude (`server/`, Postgres, nginx-Eingang `loose-ends.henemm.com`) läuft heute auf dem geteilten
Hetzner-Server `rennwienix` (178.104.143.19; dort auch gregor20, n8n, Stalwart, claude-mq, mcp-obsidian, Frieda).
Vor der ersten Öffnung für externe Nutzer (#625) zieht er auf einen eigenen Server im selben Hetzner-Projekt um
(vereinbart in #796, Abschluss S4b-2, 2026-11-20: „Nicht vorziehen, nicht streichen“). #625 wartet auf #966.

## Related Files

Fast alles liegt im Repo `henemm/henemm-infra` (nicht lokal ausgecheckt; Haupt-Checkout auf rennwienix
`/home/hem/henemm-infra`, Auto-Deploy alle 5 min auf `origin/main`, nginx und systemd ausgenommen).

| Datei | Bedeutung |
|------|-----------|
| `loose-ends/docker-compose.yml` | Stapel: `loose-ends-db` (postgres:18.7, 512 MB, Volume `loose-ends-db`, Secret `db_password`), `loose-ends-server` (Image aus Quelle, `127.0.0.1:8780:8080`, `secrets/server.env`, 384 MB) |
| `scripts/deploy-loose-ends.sh` | baut das Image an `LE_COMMIT` aus dem öffentlichen Repo, `docker compose up -d`; manuell, nie 02:45–03:30 |
| `nginx/loose-ends.henemm.com.conf` | Allowlist (`/health`, `/mcp`, `/.well-known/…`, `/oauth/`, `/auth/*`, `/app/*`), Zonen `loose_ends_*` in `nginx/conf.d/limit-req.conf`, TLS Let's Encrypt |
| `fail2ban/nginx.local` | `nginx-limit-req` bannt 1 h nach 10 Treffern (henemm-infra#397) |
| `scripts/backup.sh` | ruft `backup-loose-ends-snapshot.sh` (pg_dump), eigener restic-Snapshot `--tag offsite --tag loose-ends --host henemm-hetzner`, sonntags Rückspielprobe |
| `scripts/backup-loose-ends-snapshot.sh` | Plain-SQL-Dump nach `/home/hem/backups/loose-ends/` |
| `scripts/monitor.sh` | prüft `https://loose-ends.henemm.com/health` und Image `loose-ends-db` (kritisch, Henning 2026-11-03) |
| `docs/backup-offsite.md` | restic → Heimserver über WireGuard (REST-Server nur an `10.10.0.2`), Prune 30 Tage für Loose Ends (#421/#423), Wiederherstellungsweg |
| `docs/vpn-wireguard.md` | Tunnel rennwienix ↔ Heimserver |
| `docs/security.md` | ufw, SSH-Härtung, tägliche Audit-Instanz (`claude-security`), DNS-Zone bei **Namecheap ohne API** |

In `henemm/loose-ends`: `CLAUDE.md` Abschnitt „Betrieb“ (Adresse, Zonen, Deploy, Sicherung), `server/` (unverändert,
läuft als Image), Belegordner `docs/artifacts/feat-796-*`, `feat-621-s6b-betrieb/`, `feat-795-s5b-weckruf-betrieb/`.

## Existing Patterns
- Ein Stapel je Dienst unter `henemm-infra/<dienst>/docker-compose.yml`, Port nur auf `127.0.0.1`, nginx davor.
- Deploy per Hand an festem Commit; Geheimnisse nur auf dem Server (`secrets/server.env`, `.p8` für APNs).
- Sicherung: nächtlicher pg_dump → restic off-site, wöchentliche Rückspielprobe in Wegwerf-Container.
- Überwachung zentral in `monitor.sh` auf rennwienix (Telegram-Meldung, Incidents).

## Dependencies
- Upstream: Hetzner Cloud (Server, Firewall, Backup), Namecheap-DNS (A/AAAA für `loose-ends.henemm.com`, Handarbeit),
  Let's Encrypt, Heimserver (restic-REST über WireGuard), Apple (Sign in with Apple Services-ID mit Return-URL auf der
  Domain, APNs-Schlüssel), GitHub (Quelle für den Bau).
- Downstream: App (alle Geräte, `LEServiceURL` = Domain, kein IP-Bezug), claude.ai-Konnektor (OAuth-Issuer = Domain,
  Tokens in der DB), Monitoring, Sicherung.

## Existing Specs
- `docs/specs/` zu #796 S4a/S4b (Betrieb, Sicherung), #621 S6b (Öffnen), #795 S5b (Weckruf-Betrieb).

## Risks & Considerations
- **Umfang:** Neuer Server = Bereitstellen, Härten (SSH, ufw, fail2ban, Audit), Docker, nginx + TLS, Stapel, Geheimnisse,
  WireGuard-Peer zum Heimserver, Sicherung + Rückspielprobe, Überwachung, Datenumzug, DNS-Umschaltung. Weit über einen
  Schnitt; Aufteilung in Schnitte nötig.
- **DNS bei Namecheap ohne API:** Umschalten braucht Hennings Anmeldung im Browser (Muster wie CloudKit-Console).
- **Hetzner-Zugang:** Anlegen eines Servers braucht ein hcloud-Token; Lage des Tokens klären (Doku nennt „per hcloud-API
  verifiziert“). Lesender SSH-Zugriff wird teils als „Production Reads“ gesperrt.
- **Kosten:** eigener Server + Hetzner-Backup kosten monatlich; Entscheidung „eigener Server“ steht seit #796.
- **Datenumzug ohne Verlust:** Konten, Sitzungen, OAuth-Grants, Apple-Tokens, Gerätetoken, Abschrift, offene Aufträge.
  Kurze Schreibpause beim Umschalten; DNS-TTL vorher senken. Die Abschrift schickt die App neu (ADR-21), Aufträge sind
  kurzlebig — ein kurzer Ausfall ist verkraftbar, Verlust von Konten/Grants nicht (claude.ai müsste neu verbinden).
- **Zertifikat:** Let's Encrypt auf dem neuen Server erst nach DNS-Umschaltung per HTTP-01, oder vorher per DNS-01 (Handarbeit)
  bzw. Zertifikat kopieren.
- **Ausgehende IP:** APNs und Apple-Endpunkte haben keine IP-Allowlist; Mail nicht betroffen.
- **Alternative (für die Analyse):** auf rennwienix bleiben, aber härter isolieren (eigener Docker-Netz-/Benutzer-, Ressourcen-
  grenzen) — würde die Vereinbarung aus #796 kippen; oder ein dedizierter Server nur für Postgres. Gehört in `/20-analyse`.
