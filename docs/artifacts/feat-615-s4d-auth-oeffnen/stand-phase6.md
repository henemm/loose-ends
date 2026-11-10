> Veraltet: Arbeitsnotiz vom Stand Phase 6, 15:50Z. Maßgeblich sind die Belege im Ordner und der Abschluss in der Validierung.

# Arbeitsstand Phase 6 (#615 S4d) — 2026-11-10 15:50Z

## Erledigt (Belege im Ordner)
- AC-1 `variablen.txt`: App-ID enthalten ja, ALLOWED_APPLE_SUBS genau ein Eintrag ja, 0 Treffer bei Geheimnissen.
- AC-2 `red.txt` (aus Phase 5).
- AC-3 Infra-PR A henemm-infra#419 gemergt (e0443b8), `infra-pr-a.txt`; Deploy c62fbae Exit 0, `deploy.txt`.
- AC-4 `konnektor.md` (Konnektor in der Sitzung nicht verfügbar, Ersatz check-outside.sh Exit 0).
- AC-5 `nginx-T.txt` (Auszug Server-Block, Zone `loose_ends_auth`, drei `location =`, `^~ /auth/` 404).
- AC-6 nginx eingespielt 15:43:01Z: Sicherung `/home/hem/backups/nginx-loose-ends.henemm.com.20261110T154301Z.conf`
  (= `nginx-alt.conf`), `nginx -t` ok, reload Exit 0. **`nginx-t.txt` noch schreiben** aus dieser Ausgabe:
  Sicherung …154301Z.conf / nginx -t: 2026-11-10T15:43:01Z / syntax is ok / test is successful / reload: 15:43:01Z / reload Exit: 0.
  Skript: scratchpad nginx-apply.sh (sichern, cp, `nginx -t`, nur bei Erfolg reload, sonst Rückkopie).
- AC-7 Infra-PR B henemm-infra#420 gemergt (12e857e), Dateien nginx +38 −2, expected-exposure +4 −1; keine CI-Checks im Repo;
  pytest im Wegwerfklon auf rennwienix (f800df7, 15:41:22Z) `502 passed, 6 skipped`, Exit 0. **`infra-pr-b.txt` noch schreiben.**
- AC-8 `green.txt`: 8× OK, Exit 0, 8 Anfragen, kein 429.
- AC-10 `monitor-vorher.txt`/`monitor-nachher.txt`: diff nur Zeit-/Messwerte, keine Zustandsänderung eines anderen Dienstes,
  kein anderer Container neu (nur loose-ends-server), uptime durchgehend 24 Tage. Loose-Ends (200) ✓.

- AC-9 `scan.txt`: Außenscan OK, Exit 0, Stempel 16:00:16. `nginx-t.txt` und `infra-pr-b.txt` geschrieben.
- Hinweis: Commit sperrt das Gate bis zum Adversary-Verdict; alle Belege liegen uncommittet im Worktree.

## Offen
- AC-11: lokaler Löschlauf. Aufbau wie `server/scripts/test-local.sh` (Postgres 18 Wegwerf), Dienst mit `npm start` in `server/`
  (DATABASE_URL, PORT, ohne APPLE_*/OAUTH_* → /auth/delete läuft ohne Apple-Konfig), Konto+Sitzung per Node-Skript mit
  `findOrCreate` + `createSession` aus `server/src/accounts.ts`, dann `POST /auth/delete` mit Bearer → 204, Zählungen 0,
  zweiter Aufruf 401. Dazu `./scripts/sim.sh test-proof AccountSettingsTests`. Belege `loeschen-lokal.md`, `loeschen-live.txt`.
- AC-12: CLAUDE.md Betrieb-Absatz (`/auth/*` … stay 404 → drei Pfade offen seit S4d, Zone `loose_ends_auth`, 16k), Scan auf Wertmuster.
- Danach GREEN-Artefakt registrieren, auto-green, Adversary (6b).
