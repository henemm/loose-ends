# Context: feat-795-s1b-nginx (#795 Schnitt S1b)

## Request Summary
Die drei App-Wege des Dienstes (`POST /app/transcript`, `/app/orders/claim`, `/app/orders/result`, gebaut in S1, PR #904,
ausgerollt 2026-11-11 21:11Z mit LE_COMMIT 63de3cc) sind auf `rennwienix` live, aber von außen 404, weil nginx nach einer
Erlaubnisliste nur freigegebene Pfade durchreicht. S1b öffnet genau diese drei Pfade in nginx, damit S2/S3 (App-Client,
Auslöser) gegen den echten Dienst laufen können. Betriebsschnitt: kein Dienstcode, keine App.

## Related Files
| File | Relevance |
|------|-----------|
| `henemm-infra: nginx/loose-ends.henemm.com.conf` | Erlaubnisliste; drei `location = /app/…` neu, `^~ /app/` sonst 404 (heute fällt `/app/` in `location /` → 404) |
| `henemm-infra: security/expected-exposure.json` | Soll-Statuscodes von außen; heute keine `/app/`-Einträge. Neu z. B. `GET /app/transcript` 405, `/app/x` 404 |
| `henemm-infra: scripts/deploy-loose-ends.sh` | `LE_COMMIT` steht schon auf 63de3cc (S1) — kein Deploy nötig |
| `server/src/app-routes.ts` | Reihenfolge der Antworten: 405 (allow: POST) → Sitzung 401 → `X-Device` 400 → 415 → 413 (256 KiB, gezählt) → 400; leere Antworten mit `cache-control: no-store` |
| `docs/artifacts/feat-615-s4d-auth-oeffnen/check-auth.sh` | Vorlage für ein Prüfskript von außen (≤ 8 Anfragen, kein 429, OK/FEHLT, Exit 0) |
| `docs/artifacts/feat-615-s4d-auth-oeffnen/infra-pr-b.txt`, `deploy.txt` | Vorlage für Infra-PR und Ausrollen (pytest im Wegwerfklon auf rennwienix, `nginx -t`, `systemctl reload nginx`) |
| `docs/specs/feat-615-schnitt-4d-auth-oeffnen.md` | Vorbild-Spec (Betriebsschnitt, Reihenfolge, Rollback) |
| `CLAUDE.md` (Abschnitt `server/`, Absätze `src/app-routes.ts` und „Betrieb“) | „nginx (`/app/`, S1b) … still open“ wird aktualisiert; Betrieb-Absatz bekommt `/app/…`; dabei die offene Kleinigkeit aus S1: „`refused` 409“ meint ein Ergebnis zu einem Auftrag, den dieses Gerät nicht geholt hat |

## Existing Patterns
- Jeder offene Pfad ist eine exakte `location =` mit `limit_req` (eigene Zone je Gruppe, `limit_req_status 429`),
  `client_max_body_size` gleich der Grenze des Dienstes, dieselben vier `proxy_set_header`, `proxy_pass http://127.0.0.1:8780`.
- Rest eines Präfixes ausdrücklich `return 404` (`^~ /auth/`).
- Prüfung von außen per kleinem curl-Skript ohne Geheimnisse; 413 lässt sich ohne Sitzung belegen, weil nginx die Größe vor dem Dienst prüft.
- Infra-PR per gh-API (Worktree-Git-Guard), pytest auf rennwienix im Wegwerfklon, `git pull --ff-only` auf dem Server, alte Datei sichern, `nginx -t`, reload.

## Dependencies
- Upstream: S1 live (63de3cc), nginx auf rennwienix, fail2ban `nginx-limit-req` (Sperre 1 h nach 10 Limit-Treffern, henemm-infra#397).
- Downstream: S2 App-Client und S3 `ClaudeSync` (rufen die Wege; Holen bis keiner mehr da ist → Anfragefolgen), #622-Beleg aus claude.ai.

## Existing Specs
- `docs/specs/feat-795-schnitt-1-dienst-wege.md` (S1, „Nicht in diesem Schnitt“: S1b nginx, Zone wie `loose_ends_auth`, 256k)
- `docs/specs/feat-615-schnitt-4d-auth-oeffnen.md`, `docs/specs/feat-621-schnitt-6b-betrieb.md`

## Risks & Considerations
- **fail2ban sperrt Hennings Heim-Adresse** für alle Hosts eine Stunde, wenn die App das Limit zehnmal trifft. iPhone, iPad und Mac
  teilen hinter dem Router eine Adresse; S3 holt Aufträge in einer Schleife (claim → result → claim …). Zonenwahl muss das tragen:
  eigene Zone `loose_ends_app` statt geteilter `loose_ends_auth` (sonst zählen Anmeldung und Abgleich zusammen), Rate/Burst begründen.
- Körpergrenze 256k in nginx = Dienstgrenze; nginx antwortet bei Überschreitung selbst 413 (vor Anmeldung).
- Keine Streaming-Antworten auf `/app/` (Spec S1, Alternative C verworfen): Standard-Puffer und -Timeouts reichen.
- Prüfskript darf kein 429 provozieren; höchstens ~8 Anfragen.
- Eine 401 von außen belegt die Öffnung ohne gültige Sitzung; ein echter Durchlauf mit Sitzung kommt erst mit S2/S3.
- Rollback: alte nginx-Datei sichern, bei `nginx -t`-Fehler nicht neu laden.

## Analysis

### Type
Feature (Betriebsschnitt, kein Dienst- und kein App-Code)

### Befund heute (2026-11-11, nachgestellt)
- Von außen: `POST /app/transcript` und `/app/orders/claim` → **404** (fallen in `location / { return 404; }`).
- Auf `rennwienix` direkt am Dienst (`127.0.0.1:8780`): `POST /app/orders/claim` ohne Sitzung → **401**. Dienst ist also bereit, nur nginx sperrt.
- nginx 1.24.0, `error_log /var/log/nginx/error.log` (Stufe `error`), kein `limit_req_log_level` gesetzt.
- fail2ban (`henemm-infra: fail2ban/nginx.local`): Jail `nginx-limit-req`, `maxretry = 10`, `findtime = 10m`, `bantime = 1h`, Ports http/https —
  eine Sperre trifft **alle** Hosts auf `rennwienix` (henemm.com, Frieda …) für Hennings Heim-Adresse; `ignoreip` nur Server selbst.

### Recherche (Quellen)
- nginx `limit_req`: mit `nodelay` gehen Anfragen innerhalb `burst` sofort durch, erst darüber wird abgelehnt (429); `limit_req_log_level`
  Standard `error`, Verzögerungen eine Stufe tiefer — https://nginx.org/r/limit_req
- fail2ban-Filter `nginx-limit-req` zählt nur die Zeilen „limiting requests, excess“, also nur **abgelehnte** Anfragen, nicht durchgelassene —
  https://fail2ban-recipes.pages.dev/guides/fail2ban-nginx-limit-req/ , https://www.netdata.cloud/guides/nginx/nginx-limiting-requests-excess/

### Lastprofil der App (aus S1-Spec und #795-Entwurf)
- Je Gerät und Anlass: 1× `transcript`, dann `claim` → `result` → `claim` … bis 204: **2N + 2** Anfragen bei N Aufträgen, nacheinander (RTT-gebunden, ~10–20/s).
- Anlässe: Start, Vordergrund, stiller Weckruf (S5) — ein Weckruf trifft iPhone, iPad, Mac **gleichzeitig** von **einer** Heim-Adresse.
- Beispiel 10 Aufträge aus Claude, drei Geräte geweckt: ≈ 2·10 + 3·2 = **26** Anfragen in 1–3 s. Mit der Zone `loose_ends_auth`
  (5 r/s, burst 10) gäbe das rund 10 Ablehnungen → **Sperre der Heim-Adresse für eine Stunde**. Die S1-Vorgabe „Zone wie `loose_ends_auth`“ trägt das nicht.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `henemm-infra: nginx/loose-ends.henemm.com.conf` | MODIFY | Zone `loose_ends_app` (10 r/s); drei `location = /app/…` (burst 40 nodelay, 429, `client_max_body_size 256k`, vier Kopfzeilen, `proxy_pass`); `location ^~ /app/ { return 404; }`; Kopfkommentar |
| `henemm-infra: security/expected-exposure.json` | MODIFY | `/app/transcript`, `/app/orders/claim`, `/app/orders/result` → [405] (GET), `/app/x` → [404] |
| `docs/artifacts/feat-795-s1b-nginx/check-app.sh` | CREATE | Prüfskript von außen nach Vorlage `check-auth.sh` (≤ 8 Anfragen, kein 429): 3× POST ohne Sitzung → 401, GET → 405, `/app/x` → 404, 300 KiB → 413 (nginx), Status OK/FEHLT |
| `CLAUDE.md` (Abschnitt `server/`) | MODIFY | `app-routes.ts`: „nginx (`/app/`, S1b) … still open“ → offen seit S1b; Betrieb-Absatz: `/app/…`, Zone `loose_ends_app`; Präzisierung „`refused` 409 = Ergebnis zu einem Auftrag, den dieses Gerät nicht (mehr) hält“ |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Abschnitt „Wege der App“: 429 von nginx und Pflicht der App, bei 429 den Lauf abzubrechen und erst beim nächsten Anlass weiterzumachen (Vorgabe für S2/S3) — ohne neuen ```json-Block (AC-16 von S1) |

### Scope Assessment
- Files: 5 (2 im Infra-Repo, 3 hier), davon 1 neues Prüfskript
- Estimated LoC: ≈ +45 nginx, +4/−0 JSON, ≈ +40 Skript, ≈ +10 Doku → **≈ +100 / −3**
- Risk Level: **MEDIUM** — kein Code, aber ein Fehler in nginx trifft alle Hosts auf `rennwienix`; abgesichert durch `nginx -t` vor dem Neuladen und gesicherte alte Datei. Zweites Risiko: falsch bemessene Grenze sperrt Hennings Heim-Adresse (fail2ban).

### Technical Approach (Empfehlung)
Eigene Zone `loose_ends_app` mit **10 r/s, burst 40, nodelay** (wie `loose_ends_mcp`), getrennt von der Anmeldung, damit Abgleich und
Anmeldung sich nicht gegenseitig aufbrauchen. 26 Anfragen in einem Stoß liegen weit unter 40 + 10/s. Zusätzlich als Vertragsregel für S2/S3:
Bei 429 bricht das Gerät den Abhol-Lauf ab und versucht es erst beim nächsten Anlass — so entsteht höchstens **eine** Ablehnung je Gerät und
Anlass, zehn Ablehnungen in zehn Minuten (Sperre) brauchen dann einen echten Fehler. Körpergrenze 256k = Dienstgrenze, nginx antwortet bei
Überschreitung selbst 413 (vor Anmeldung, belegbar ohne Sitzung). Keine Streaming-Einstellungen (S1, Alternative C verworfen). Exakte
`location =` je Pfad, Rest von `/app/` ausdrücklich 404. Ablauf wie #615 S4d: Infra-PR per gh-API, pytest im Wegwerfklon auf `rennwienix`,
Merge, `git pull --ff-only`, alte Datei sichern, `nginx -t`, `systemctl reload nginx`, Prüfskript von außen, `check-external-exposure.sh`.
Kein Dienst-Deploy (LE_COMMIT 63de3cc ist schon live).

### Alternativen
- **A (Empfehlung):** eigene Zone 10 r/s / burst 40 + 429-Abbruchregel in der App.
- **B: Zone `loose_ends_auth` mitbenutzen (S1-Vorgabe).** Kippt nur die Notiz in der S1-Spec. Verworfen: 5 r/s / burst 10 sperrt bei einem Weckruf mit ~10 Aufträgen die Heim-Adresse (Rechnung oben).
- **C: Abholen gebündelt** (`claim` liefert alle offenen Aufträge auf einmal, ein `result` mit allen Ergebnissen): 2–3 Anfragen statt 2N+2, Grenze könnte eng bleiben. Kippt den Vertrag aus S1 (ein Auftrag je `claim`, AC-4/4a) und die Rückholregel je Auftrag; Dienstcode statt Betriebsschnitt. Lohnt erst, wenn S3 echte Mengen misst.
- **D: `/app/` aus fail2ban nehmen** (`limit_req_log_level info` für diese Pfade, Ablehnungen erreichen das Log der Stufe `error` nicht): keine Sperre der Heim-Adresse möglich, aber auch keine Sperre eines Angreifers auf diesen Pfaden; nginx-Grenze allein bleibt. Verworfen, weil die Pfade öffentlich sind und Anmeldeversuche sonst unbegrenzt wiederholbar wären.

### Dependencies
- Upstream: S1 live (63de3cc); fail2ban-Jail `nginx-limit-req` unverändert.
- Downstream: S2 (App-Client: 429 als eigener Fehler, Abbruch des Laufs), S3 (`ClaudeSync`), S5 (Weckruf an alle Geräte gleichzeitig).

### Open Questions
- keine an den PO (reiner Betriebsschnitt, keine Produktentscheidung, keine sichtbare Änderung).
