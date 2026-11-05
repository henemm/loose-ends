# Adversary Dialog — feat-621-mcp-anmeldung
Spec: docs/specs/feat-621-schnitt-1-ressourcenseite.md
Datum: 2026-11-05 16:11

## Checkliste
- [x] **AC-1:** Metadaten-Dokument: `GET /.well-known/oauth-protected-resource/mcp` antwortet 200 mit `content-type: application/json` und einem Körper, der als JSON genau gleich `{ "resource": "<RESOURCE>", "authorization_servers": ["https://loose-ends.henemm.com"], "bearer_methods_supported": ["header"] }` ist (`deepEqual`, keine weiteren Schlüssel); kein `access-control-allow-origin`-Header. Test: „oauth-resource: metadaten dokument“.
- [x] **AC-2:** Metadaten nur lesend: `POST`, `PUT`, `DELETE` und `HEAD` auf dieselbe URL antworten je 405 mit Header `Allow: GET` und leerem Körper (tabellengetrieben, eine Methode je Zeile). Test: „oauth-resource: metadaten nur get“.
- [x] **AC-3:** Metadaten vor `migrate`: Ist die Datenbank nicht erreichbar (wie S1-AC-2 in `main.test.ts`), antwortet `GET <META>` trotzdem 200 mit dem Dokument aus AC-1, während `/mcp` 503 ohne Körper antwortet (nicht 401). Nach `ready` antwortet `/mcp` ohne Token 401. Test: „oauth-resource: metadaten vor migrate“.
- [x] **AC-4:** `/mcp` ohne Token: `POST /mcp` ohne `Authorization`-Header antwortet 401; der Header `WWW-Authenticate` beginnt mit `Bearer`, enthält `error="invalid_token"` und genau `resource_metadata="<META>"`; der Körper ist JSON mit `error: "invalid_token"`. Der Aufruf erreicht `mcp.fetch` nicht (kein MCP-Antwortkörper). Test: „oauth-resource: mcp ohne token 401“.
- [x] **AC-5:** Ablehnungstabelle am Prüftor, je Zeile eine Anfrage an `/mcp` mit dem Test-Verifizierer: (a) `Authorization: Basic eDp4` → 401 mit `WWW-Authenticate`-Typ `Bearer`; (b) `Bearer unbekannt` (Verifizierer wirft `OAuthError InvalidToken`) → 401; (c) gültiges Token, aber `resource` = `https://anderer.example/mcp` → 401, Beschreibung nennt „not issued for this resource“; (d) gültiges Token, aber `resource` fehlt → 401; (e) gültiges Token ohne `expiresAt` → 401, Beschreibung nennt „no expiration time“; (f) abgelaufenes Token (`expiresAt` in der Vergangenheit) → 401. Jede 401 trägt `resource_metadata="<META>"`. Test: „oauth-resource: ablehnungstabelle“.
- [x] **AC-6:** Verifizierer wirft Nicht-`OAuthError`: Antwort 500 (OAuth-Fehler `server_error`), im Fehlerfenster gezählt; die gesammelten Logzeilen enthalten weder das Token noch den Text der Ausnahme. Test: „oauth-resource: verifizierer wirft 500“.
- [x] **AC-7:** App-Sitzungstoken wird nie angenommen: Mit dem **Standard-Verifizierer** (`oauth` ohne `verifier`) antwortet `/mcp` für ein echtes Token aus `createSession(pool, accountId)` (Konto über `findOrCreate`) 401 mit `resource_metadata="<META>"`; ebenso für beliebige andere Token-Zeichenfolgen. Test: „oauth-resource: app-sitzung abgelehnt“.
- [x] **AC-8:** Gültiges Token reicht das Konto durch: Mit eingereichtem Test-Verifizierer (`extra.account` = Konto A, `resource` = `<RESOURCE>`, `expiresAt` in der Zukunft) verbindet ein MCP-Client (`StreamableHTTPClientTransport` mit `requestInit.headers.Authorization = "Bearer …"`); ist über `putTranscript` die Abschrift für A vorbereitet, liefert `get_now` genau deren Jetzt-Zeilen; ohne vorbereitete Abschrift liefert es „noch keine Abschrift“ ohne `isError`. Test: „oauth-resource: konto durchgereicht“.
- [x] **AC-9:** Kein Mitlesen über Konten: Zwei Tokens (Konto A und Konto B, je mit eigener Abschrift über `putTranscript`) lesen über `get_now` jeweils nur die eigene Abschrift; die Antwort für A enthält keine Kennung aus B und umgekehrt. Test: „oauth-resource: konten getrennt“.
- [x] **AC-10:** Reihenfolge vor `migrate`: Vor `migrate` antwortet `/mcp` auch mit einem gültigen Test-Token und auch ohne Token 503 ohne Körper (der Verifizierer wird nicht aufgerufen, Zähler 0); danach greift die Prüfung. Test: „oauth-resource: mcp vor migrate 503“.
- [x] **AC-11:** Ressource aus der Konfiguration, nicht aus der Anfrage: Mit `oauth: { publicUrl: "http://127.0.0.1" }` (Testfall) stehen `resource` im Dokument und `resource_metadata` im Header auf dieser URL (`http://127.0.0.1/mcp` bzw. `http://127.0.0.1/.well-known/oauth-protected-resource/mcp`); ein abweichender `Host`-Header (`evil.example`) ändert weder das Dokument noch den Header noch die geprüfte Audience (ein Token mit `resource = http://evil.example/mcp` wird abgelehnt). Test: „oauth-resource: ressource folgt public url“.
- [x] **AC-12:** `publicUrlFromEnv`, tabellengetrieben, ein Fall je Zeile: leer, fehlend und nur Leerzeichen → `https://loose-ends.henemm.com`; `https://loose-ends.henemm.com` → derselbe Wert; `https://example.org/` → `https://example.org`; `http://localhost:8080` und `http://127.0.0.1` → erlaubt (Origin zurück); `http://example.org`, `https://example.org/pfad`, `https://example.org/?a=1`, `https://example.org/#x`, `https://nutzer:pw@example.org`, `kein-url` → wirft `Error` mit der Meldung `PUBLIC_URL invalid`, in der der gesetzte Wert nicht vorkommt. Test: „oauth-resource: public url aus env“.
- [x] **AC-13:** Abbruch im Prozess: Ein Kindprozess (`main.ts`, `DATABASE_URL` gesetzt, Muster aus `main.test.ts` „einhaengen: prozess bricht bei falscher config ab“) mit `PUBLIC_URL=http://example.org` endet mit Exit-Code 1, ohne zu lauschen und ohne den Pool zu öffnen; die Ausgabe enthält die Zeile `public url invalid` und nicht den Wert `example.org`. Ein Kindprozess ohne `PUBLIC_URL` startet, lauscht und antwortet `GET <META>` mit dem Standard-Dokument (nach `SIGTERM` Exit 0). Test: „oauth-resource: prozess bricht bei falscher public url ab“.
- [x] **AC-14:** Nicht überschreibbar: `extraRoutes` mit den Schlüsseln `/.well-known/oauth-protected-resource/mcp` und `/mcp` (Funktionen, die 418 liefern) ändern nichts: `GET <META>` liefert das Dokument aus AC-1, `/mcp` ohne Token 401. `GET /.well-known/oauth-authorization-server` antwortet 404 (kein Aussteller in S1). Test: „oauth-resource: nicht ueberschreibbar“.
- [x] **AC-15:** Umgestellte bestehende Tests in `server/test/main.test.ts`, ohne eine Prüfung zu schwächen: (a) „AC-3 (S1)“ (Zeile ~98): `/mcp` ohne Token → 401 mit `WWW-Authenticate`; mit eingereichtem Test-Verifizierer ohne `extra.account` verbindet der Client, `serverInfo.name === "loose-ends"`, und `get_now` liefert weiter `isError` mit „kein Konto“; (b) „einhaengen: health und mcp nicht ueberschreibbar“ (Zeile ~551): der Client verbindet nur mit Test-Verifizierer und Bearer-Header, `/mcp` ohne Token bleibt 401 statt 418; (c) „einhaengen: body ueber 1 mib 413“ (Zeilen ~486, ~503): die Prüfung `status !== 413` bei genau 1 MiB bleibt unverändert und trifft nun 401, die 413-Fälle bleiben unberührt; die Tests bei Zeile ~92 und ~337 (503 vor `migrate`) bleiben unverändert. `server/test/mcp.test.ts` bleibt unberührt. Test: die genannten Testfälle in `main.test.ts`.
- [x] **AC-16:** Grenze, Länge, Doku: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/oauth-resource.ts`, `server/src/main.ts`, `server/test/oauth-resource.test.ts`, `server/test/main.test.ts` und `CLAUDE.md`; `mcp.ts`, `auth.ts`, `accounts.ts`, alle `apple*.ts`, `server/migrations/`, `server/package.json` und das Lockfile sind unverändert; jede Funktion hat höchstens 50 Zeilen; `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf. `CLAUDE.md` nennt im Abschnitt `server/` in einer Zeile `src/oauth-resource.ts` (Metadaten-Route, Prüftor, Standard-Verifizierer lehnt alles ab, `publicUrlFromEnv`, `/mcp` ohne Token 401, noch kein Aussteller). Test: „oauth-resource: grenze und doku“ (Prüfung per `git diff --name-only` und `grep` auf `CLAUDE.md`).

## Dialog

### Runde 1
**Adversary:** Forderung: Beweis je AC, nicht nur gruene Tests. Selbst beschafft: voller Lauf `./server/scripts/test-local.sh` (docs/artifacts/feat-621-mcp-anmeldung/adversary-test-output.txt): 242 Tests, 242 bestanden, 0 fehlgeschlagen, 0 uebersprungen, typecheck gruen; alle 15 Tests `oauth-resource: ...` einzeln im Log gruen. Eigene Proben gegen `publicUrlFromEnv`: `https://example.org?` wirft, `https://example.org//` wirft, `http://localhost.` wirft, `HTTPS://Example.ORG` wird `https://example.org`, Port 443 entfaellt, `:8443` bleibt, `http://LOCALHOST:9` wird `http://localhost:9`, Leerraum wird getrimmt, `http://[::1]` wirft (strenger als Spec, F001). Probe `bearerGate` mit eigenem Verifizierer: kein Header, `Bearer`, `Bearer ` (leer), `Bearer  ok` (zwei Leerzeichen), `Basic` je 401 mit `WWW-Authenticate: Bearer error=invalid_token`; `bearer ok` und `BEARER ok` (Schema laut RFC 7235 case-insensitive) werden angenommen, `Bearer ok x` reicht Token `ok` durch (SDK-Verhalten, F002). Metadaten-Route: GET 200, HEAD/OPTIONS/POST 405 mit `allow: GET`. Lebender Dienst (start() mit unerreichbarer DB, Port 0): Metadaten 200 vor migrate, auch mit `?x=1`; `/.well-known/oauth-protected-resource` (ohne /mcp), `.../mcp/` und `/mcp/` 404; `POST/HEAD/OPTIONS /mcp` vor migrate 503. Host-Spoofing: Konfiguration bestimmt Ressource (oauth-resource.ts:11-13; Test ab Zeile 316 mit node:http und Host evil.example). Ueberschreibbarkeit: main.ts:140-147 setzt Metadaten, /health, /mcp nach `...extraRoutes`. Dateigrenze: Diff gegen origin/main plus die untracked Datei ergibt exakt die fuenf Dateien; keine Funktion ueber 50 Zeilen (awk-Pruefung).
**Implementierer:** Belege liegen vor (Tests, Code-Pfade, Proben). Bewertung: AKZEPTIERT fuer AC-1 bis AC-16. Nachfragen ohne Schaden: Schema `bearer` und Mehrfachtoken (SDK, nicht Teil der Spec), `[::1]` (Spec nennt nur localhost und 127.0.0.1).

### Runde 2
**Adversary:** Zweiter Angriff auf Luecken. (1) Token-Passthrough: Standard-Verifizierer `rejectAll` (oauth-resource.ts:16-18) wirft immer InvalidToken; Test `app-sitzung abgelehnt` nutzt ein echtes `createSession`-Token, Ergebnis 401 mit resource_metadata. (2) Log-Leck: dispatch (main.ts:64-75) faengt Ausnahmen ohne Logzeile; Test `verifizierer wirft 500` prueft 500 und dass Log weder Token noch Ausnahmetext enthaelt, gruen (nur ueber den Test belegt, keine eigene Probe). (3) Reihenfolge: gated (main.ts:113-115) steht vor der Pruefung; Verifizierer-Zaehler 0 vor migrate (Test mcp vor migrate 503, gruen); eigene Probe: POST/HEAD/OPTIONS /mcp vor migrate 503. (4) PUBLIC_URL im Prozess: Kindprozess-Test bricht mit Exit 1 und Zeile `public url invalid` ohne Wert ab; main() prueft vor start(), also vor Pool und listen (main.ts:190-196). (5) Query-String an der Metadaten-URL wird ignoriert (dispatch nutzt pathname), harmlos. (6) Doku: CLAUDE.md:479 nennt src/oauth-resource.ts mit Metadaten-Route, Pruefor, rejectAll, publicUrlFromEnv, 401 ohne Token, noch kein Aussteller. (7) Umgestellte Altfaelle (main.test.ts:111, 497-520, 567): 413-Pruefungen unveraendert, /mcp ohne Token 401 statt 418. Keine Spec-Abweichung gefunden.
**Implementierer:** Alle Punkte belegt; AKZEPTIERT. F001 und F002 sind Strengeres bzw. SDK-Verhalten und brechen nichts.

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/oauth-resource.ts:38-45
  Description: LOCAL_HOSTS enthaelt nur localhost und 127.0.0.1; `http://[::1]` wird mit PUBLIC_URL invalid abgelehnt.
  Spec requirement: AC-12 - nennt nur localhost und 127.0.0.1 als erlaubte http-Hosts
  Conflict: kein Konflikt, strenger als noetig.
  Remediation: keine noetig; bei Bedarf `[::1]` ergaenzen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/main.ts:145-148
  Description: Das SDK-Tor (requireBearerAuth) akzeptiert das Schema `bearer`/`BEARER` und reicht bei `Bearer ok x` das erste Token durch; publicUrlFromEnv normalisiert `https://example.org/%2e` auf den Origin.
  Spec requirement: AC-4, AC-5 - Ablehnung ohne Token und bei Schema Basic
  Conflict: kein Konflikt (RFC 7235: Schema case-insensitive; der Verifizierer prueft das Token weiter); nur Hinweis.
  Remediation: keine.

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-14
  Code reference: server/src/oauth-resource.ts:21-30
  Evidence: metadataRoute liefert nur bei GET 200 mit genau drei Schluesseln, sonst 405 mit allow GET ohne Koerper; vor migrate lebender Dienst 200; Route steht nach extraRoutes.
  Status: CONFIRMED

Confirmation:
  AC: AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10, AC-11
  Code reference: server/src/main.ts:133-148
  Evidence: bearerGate vor mcp.fetch mit authInfo, gated davor, rejectAll als Standard, Ressource aus publicUrl; Tests gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-12, AC-13
  Code reference: server/src/oauth-resource.ts:41-50
  Evidence: publicUrlFromEnv Tabelle und Probe; main() bricht mit public url invalid ab (main.ts:190-196).
  Status: CONFIRMED

Confirmation:
  AC: AC-1 bis AC-14 (Testabdeckung)
  Code reference: server/test/oauth-resource.test.ts:138
  Evidence: 15 Tests oauth-resource gruen im Gesamtlauf (242/242).
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: server/test/main.test.ts:111
  Evidence: umgestellte Faelle AC-3 (S1), 413 (Zeile 497-520), nicht ueberschreibbar (Zeile 567) gruen, 413-Pruefungen unveraendert.
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: CLAUDE.md:479
  Evidence: server-Abschnitt nennt src/oauth-resource.ts in einer Zeile; genau die fuenf Dateien geaendert; keine Funktion ueber 50 Zeilen; test-local.sh gruen.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:5aee2bcfe4213f5c8f150c6fa653ca04fa041a45d0df39c18e969f216d6b1d00  CLAUDE.md
- sha256:f6c70eaabcde9343ffb82894014d622fa6a90025b5a708154790aa76dce93384  server/src/main.ts
- sha256:558c8313e48d87ed701bfabf1d1d440ea8d4438f88e773e5280aa46b236a819d  server/src/oauth-resource.ts
- sha256:19733a08afa1e3b008726a041d3f056a040b48fa90a8ab4539eee67aa75c38ed  server/test/main.test.ts
- sha256:4c5434cd10d5a6a2e40b9a444008b327ef13ba1634deb4c29bb8aaea0b3de592  server/test/oauth-resource.test.ts

## Prüfbasis

- base: 185099961651feeed2bda73e65eb552c416e15ee
- blob:58f431f17ce2347b689e3018b66bfb552514f3a2  CLAUDE.md
- blob:f5b48d59803ab275d28665c6073e18037e7c2532  server/src/main.ts
- blob:bff3d0f7fa3a89ac77902814755a932d92b8ee5f  server/src/oauth-resource.ts
- blob:475d6c5eaf134026374bd8e00005841c62fc6327  server/test/main.test.ts
- blob:3e17d1bf9b68b8104df46e388cb02dd648ddabf2  server/test/oauth-resource.test.ts
