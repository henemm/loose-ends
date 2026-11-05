# Adversary Dialog — feat-621-mcp-anmeldung
Spec: docs/specs/feat-621-schnitt-1-ressourcenseite.md
Datum: 2026-11-05 (Fassung 2, nach Aenderung am Test grenze und doku)

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
**Adversary:** Beweise selbst beschafft. Voller Lauf `./server/scripts/test-local.sh` (docs/artifacts/feat-621-mcp-anmeldung/adversary-test-output.txt): Exit 0, typecheck (tsc --noEmit) gruen, tests 242, pass 242, fail 0, cancelled 0, skipped 0, todo 0. Alle 15 Tests `oauth-resource: ...` einzeln gruen (Log-Zeilen 282-358). Je AC: AC-1/2/3/14 Tests metadaten dokument/nur get/vor migrate/nicht ueberschreibbar gruen, Code oauth-resource.ts:21-30 (nur GET 200 mit drei Schluesseln, sonst 405 allow GET ohne Koerper, kein CORS), main.ts Routentabelle setzt METADATA_PATH nach `...extraRoutes`. AC-4..7 Tests mcp ohne token 401, ablehnungstabelle, verifizierer wirft 500, app-sitzung abgelehnt gruen; Code bearerGate oauth-resource.ts:33-36 (SDK requireBearerAuth, expectedResource aus Konfiguration), Standard `rejectAll` :16-18. AC-8/9 Tests konto durchgereicht/konten getrennt gruen, main.ts reicht `authInfo: checked` an mcp.fetch. AC-10 gated steht aussen (main.ts `gated(isReady, ...)`), Test mcp vor migrate 503 gruen. AC-11 Ressource aus publicUrl, Test ressource folgt public url gruen. AC-12 oauth-resource.ts:41-50, Tabellentest gruen; AC-13 main() prueft publicUrlFromEnv vor start() (also vor Pool/listen), Kindprozess-Test gruen. AC-15: Der Diff gegen origin/main zeigt in main.test.ts nur Zusaetze/Umstellungen (Import, Test-Verifizierer, Bearer-Transport, 401-Pruefungen); die 413-Pruefungen und die 503-vor-migrate-Tests erscheinen nicht im Diff, sind also unveraendert; mcp.test.ts nicht im Diff. Lebender Dienst: probe-run.txt zeigt POST /mcp ohne Token 401 mit `www-authenticate: Bearer error="invalid_token", ... resource_metadata="https://loose-ends.henemm.com/.well-known/oauth-protected-resource/mcp"`, Metadaten-GET 200 mit exakt dem AC-1-Dokument, AS-Metadaten 404, Log ohne Inhalte.
**Implementierer:** Belege akzeptiert fuer AC-1 bis AC-15.

### Runde 2
**Adversary:** Schwerpunkt Aenderung seit Fassung 1 (AC-16). (1) Die Dateimengen-Abfrage der Spec (Namensliste des Diffs gegen origin/main ohne docs und .claude) selbst ausgefuehrt, Ausgabe genau: CLAUDE.md, server/src/main.ts, server/src/oauth-resource.ts, server/test/main.test.ts, server/test/oauth-resource.test.ts. Damit sind mcp.ts, auth.ts, accounts.ts, apple*.ts, server/migrations/, package.json und Lockfile unveraendert (nicht im Diff). Diffstat: 528 Zeilen hinzu, 7 weg ueber diese fuenf Dateien. (2) Der Test `oauth-resource: grenze und doku` (oauth-resource.test.ts:420-436) prueft jetzt nur noch Laenge pro Top-Level-Block <= 50, kein `console.` und die CLAUDE.md-Zeile mit publicUrlFromEnv, 401 und dem Metadatenpfad; er ruft keinen Diff mehr auf. Der Kommentar Zeile 426 begruendet das: ein Diff gegen origin/main bricht im flachen CI-Klon und waere nach dem Merge leer. Die Begruendung ist stichhaltig (server.yml checkt ohne fetch-depth aus). (3) Bewertung AC-16: Inhalt erfuellt (fuenf Dateien, Unveraendert-Liste, Laenge, Gesamtlauf gruen, Doku-Zeile CLAUDE.md:479). Wortlaut weicht ab: Die Spec nennt als Nachweis einen Test mit Dateidiff; dieser Teil ist nun eine einmalige Pruefung (hier), kein dauerhafter Test. Der Test prueft die Laenge ausserdem nur grob (Split an Top-Level-Deklarationen, nicht je Funktion). Ich werte das nicht als stilles Ok: Die Abweichung ist begruendet, der Wortlaut der Spec sollte angepasst werden. (4) CLAUDE.md-Zeile mit Pflichtwoertern vorhanden (Zeile 479). Keine Funktion in main.ts ueber 50 Zeilen (start 129-165, main ab 177).
**Implementierer:** Aenderung am Test ist notwendig (flacher CI-Klon, Dauerrot nach Merge). Dateigrenze einmalig belegt. Spec-Wortlaut von AC-16 wird nachgezogen.

### Findings
Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: server/test/oauth-resource.test.ts:426-436
  Description: Der Test `oauth-resource: grenze und doku` enthaelt keine Diff-Pruefung mehr; die Dateigrenze von AC-16 ist nur einmalig (durch den Adversary, Ergebnis genau die fuenf Dateien) belegt. Die Laengenpruefung ist grob (Top-Level-Split).
  Spec requirement: AC-16 - Test: `oauth-resource: grenze und doku` (Pruefung per Dateidiff und `grep` auf `CLAUDE.md`)
  Conflict: Der Spec-Wortlaut verlangt einen Test mit Dateidiff; die Umsetzung weicht begruendet ab (flacher CI-Klon ohne origin/main, nach Merge leere Menge). Inhaltlich ist AC-16 erfuellt, wortlich nicht.
  Remediation: Spec AC-16 und Test-Plan-Zeile anpassen (Dateigrenze einmalig bei Validierung, Test nur Laenge, console, Doku) oder PO die Abweichung bestaetigen lassen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/oauth-resource.ts:38-45
  Description: LOCAL_HOSTS enthaelt nur localhost und 127.0.0.1; `http://[::1]` wird abgelehnt. Strenger als die Spec, kein Konflikt.
  Spec requirement: AC-12
  Conflict: keiner.
  Remediation: keine.

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-14
  Code reference: server/src/oauth-resource.ts:21-30
  Evidence: metadataRoute nur GET 200 mit genau drei Schluesseln, sonst 405 allow GET ohne Koerper; Tests gruen (Log 282-308, 357); probe-run.txt 200 und AS-Metadaten 404.
  Status: CONFIRMED

Confirmation:
  AC: AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10, AC-11
  Code reference: server/src/main.ts:133-148
  Evidence: gated aussen, bearerGate dann mcp.fetch mit authInfo, rejectAll als Standard, Ressource aus publicUrl; Tests gruen, probe-run.txt 401 mit resource_metadata.
  Status: CONFIRMED

Confirmation:
  AC: AC-12, AC-13
  Code reference: server/src/oauth-resource.ts:41-50
  Evidence: publicUrlFromEnv wirft PUBLIC_URL invalid ohne Wert; main() bricht vor start() mit public url invalid und Exit 1 ab; Kindprozess-Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-1 bis AC-14 (Testabdeckung)
  Code reference: server/test/oauth-resource.test.ts:138
  Evidence: 15 Tests oauth-resource gruen im Gesamtlauf, 242 von 242, 0 uebersprungen.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: server/test/main.test.ts:111
  Evidence: AC-3 (S1) mit 401 ohne Token und Bearer-Client (get_now weiter ohne Konto), health-und-mcp-Test mit 401 statt 418; 413- und 503-Tests nicht im Diff, mcp.test.ts nicht im Diff.
  Status: CONFIRMED

Confirmation:
  AC: AC-16 (Doku, Dateimenge, Gesamtlauf)
  Code reference: CLAUDE.md:479
  Evidence: eine Zeile unter server/ nennt src/oauth-resource.ts mit allen geforderten Merkmalen; Dateimenge genau fuenf; test-local.sh gruen. Offen nur der Wortlaut (F001).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS

PO-Freigabe (Henning, 2026-11-05, getippt „override“): F001 betrifft nur den Wortlaut von AC-16. Inhalt belegt: Dateigrenze per `git diff --name-only origin/main` genau fünf Dateien (Lauf des Adversary), Länge, `console` und CLAUDE.md-Zeile im Test. AC-16 deshalb abgehakt.

## Geprüfte Dateien

- sha256:5aee2bcfe4213f5c8f150c6fa653ca04fa041a45d0df39c18e969f216d6b1d00  CLAUDE.md
- sha256:f6c70eaabcde9343ffb82894014d622fa6a90025b5a708154790aa76dce93384  server/src/main.ts
- sha256:558c8313e48d87ed701bfabf1d1d440ea8d4438f88e773e5280aa46b236a819d  server/src/oauth-resource.ts
- sha256:19733a08afa1e3b008726a041d3f056a040b48fa90a8ab4539eee67aa75c38ed  server/test/main.test.ts
- sha256:074bd8dc65f9ab5ccf8148a2dfe8219df0063e8a79138dfbeac0259ee396f4fc  server/test/oauth-resource.test.ts

## Prüfbasis

- base: 185099961651feeed2bda73e65eb552c416e15ee
- blob:58f431f17ce2347b689e3018b66bfb552514f3a2  CLAUDE.md
- blob:f5b48d59803ab275d28665c6073e18037e7c2532  server/src/main.ts
- blob:bff3d0f7fa3a89ac77902814755a932d92b8ee5f  server/src/oauth-resource.ts
- blob:475d6c5eaf134026374bd8e00005841c62fc6327  server/test/main.test.ts
- blob:74bd4298e054b83cd063fea7bb9417dce066ff0a  server/test/oauth-resource.test.ts
