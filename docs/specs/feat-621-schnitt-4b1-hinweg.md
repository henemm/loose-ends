---
entity_id: feat-621-schnitt-4b1-hinweg
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: feat-621-s4b-anmeldung
---

# Spec: Anmeldung über Apple im Browser, Hinweg (Schnitt 4b-1, #621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 4b-1; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte).
Analyse: `docs/context/feat-621-s4b-anmeldung.md` (Abschnitte „Recherche“, „Alternativen“, „Analysis“); Gesamt-Schnittplan: `docs/context/feat-621-mcp-anmeldung.md`. Vorgänger: #621 S3 (Aussteller, Einhängepunkt `Interaction`, feste 501), #621 S4a (`authorizeUrl`, `appleReturnUrl`, `webClientId`), #621 S2 (`PgAdapter`). Folge: S4b-2 (Rückweg und Abschluss).

## Für den PO

Wenn du Claude im Browser mit Loose Ends verbindest, schickt dich der Dienst zur Anmeldung zu Apple. Dieser Schnitt baut den ersten Teil davon: den **Hinweg**. Sobald der Browser bei der Anmeldeseite des Dienstes ankommt, merkt sich der Dienst kurz (höchstens zehn Minuten, nur als Fingerabdruck, nie im Klartext) eine Zufallskennung dieses einen Versuchs und leitet dich zur Apple-Anmeldeseite weiter. Der Rückweg von Apple (der Dienst nimmt das Ergebnis an und legt dich als Konto an oder erkennt dich wieder) folgt im nächsten Schnitt, S4b-2.

Für dich ändert sich **nichts Sichtbares**: Der Dienst ist von außen noch nicht erreichbar (nginx lässt bis S6 nur `/health` durch), die App und deine Daten sind nicht berührt, es entstehen keine Konten. Auch die Zustimmungsseite („Claude darf auf deine Aufgaben zugreifen“) bleibt bis S5 eine feste Absage. **Zu entscheiden hast du nichts.** Technisch entschieden ist außerdem: Das Apple-Token aus dem Browser-Weg wird vorerst nicht gespeichert; das gehört in einen eigenen Schnitt vor S6.

## Purpose

Die Anmelde-Interaktion des Ausstellers (Prompt `login`) antwortet nicht mehr mit der festen 501, sondern leitet zu Apple weiter, wenn der Dienst dafür konfiguriert ist:

- GET `/oauth/interaction/<uid>` liest die Interaktion über das Bibliotheks-Cookie (`interactionDetails`).
- Prompt `login`: der Dienst erzeugt zufälliges `state` und eine rohe `nonce`, legt `state → { uid, nonce }` unter dem Modell `AppleLogin` ab (`new PgAdapter(pool, "AppleLogin", now)`, also nur als SHA-256 der Kennung, mit Ablauf und atomarem Einmal-Einlösen durch `consume`), und antwortet mit 303 auf `authorizeUrl(config, { redirectUri: appleReturnUrl(publicUrl), state, nonce })`.
- Jeder andere Prompt (`consent`) bleibt die feste 501 wie heute (S5).
- Ohne Apple-Konfiguration oder ohne `webClientId` bleibt es bei der festen 501 (zählt nicht im Fehlerfenster), unverändert.

**Regeln vor Modell:** Protokoll- und Sicherheitsablauf ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Festlegungen aus der Analyse (Quelltext oidc-provider 9.13.3 und Recherche 2026-11-06):

- **Browser-Bindung über das Bibliotheks-Cookie.** `interactionDetails`/`interactionFinished` lesen die Interaktion nur über das Cookie `_interaction` (Pfad `/oauth/interaction/<uid>`, `SameSite=Lax`). Der Hinweg ist ein top-level GET und trägt es; ohne Cookie wirft `interactionDetails` `SessionNotFound`.
- **Zustand serverseitig, keine Migration.** `state` ist der Schlüssel, die Zeile trägt `{ uid, nonce }`. `form_post` (Wahl aus S4a) ist ein seitenübergreifender POST ohne Lax-Cookies; der Rückweg findet seinen Zustand daher unter `state` in der Datenbank (S4b-2).
- **Nonce:** Abgelegt wird die **rohe** Nonce, die S4b-2 an `verifyIdentityToken` gibt; `authorizeUrl` schickt selbst nur deren SHA-256-Hex an Apple.
- **TTL = `min(600, Restlaufzeit der Interaktion)`** in Sekunden (`details.exp` ist Unix-Sekunden, die Uhr kommt aus `now`); ist die Restlaufzeit nicht positiv, wird nichts abgelegt und fest mit 400 geantwortet.
- **Protokoll:** nur feste Ereignisnamen, nie `state`, `nonce`, `uid`, Fehlerobjekte (Lehre S2/S3: Fehlerdetails nennen Kennungen).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt den Plan aus dem ADR-21-Nachtrag (Schnitt 4: Apple in der Interaction des Ausstellers) um; ADR-21 und die S4a-Wahl `response_mode=form_post` („Code nie in einer URL“) bleiben unberührt, keine neue Abhängigkeit, keine Migration.

**Rationale:** Der Hinweg ist allein prüfbar (Weiterleitung, Ablage, feste Ablehnungen), ohne dass Apple erreicht oder ein Konto angelegt wird. Der Rückweg braucht zusätzlich Körper-Lesen, Code-Einlösen, Konto und Abschluss und würde mit Tests weit über 250 LoC liegen; die Teilung hält beide Schnitte prüfbar.

## Source

**Files:** `server/src/oauth-interaction.ts` (neu), `server/src/oauth-provider.ts` (ändern), `server/src/main.ts` (ändern), `server/test/oauth-interaction.test.ts` (neu).
**Identifier:** `appleInteraction`, `productInteraction`, `Interaction`, `authorizeUrl`, `appleReturnUrl`, `PgAdapter` (Modell `AppleLogin`), `createJwks`, `mountIssuer`, `mountAuth`

### Schnittstelle

- **`server/src/oauth-interaction.ts`** (neu)
  - `appleInteraction(deps: { pool: pg.Pool; config: AppleConfig; publicUrl: string; now: () => Date; fallback: Interaction; keys: KeyLookup; log: (event: string) => void }): Interaction`. Rückgabe passt zum bestehenden Typ `Interaction = (provider, req, res) => Promise<void>` aus `oauth-provider.ts`. `keys` (die geteilte JWKS-Suche) wird in S4b-1 nur angenommen und nicht genutzt; S4b-2 prüft damit das Identity-Token.
  - Ablauf je Aufruf:
    1. Ohne `config.webClientId` → `deps.fallback` (die feste 501), sonst nichts. (`main()` baut `appleInteraction` ohnehin nur mit Web-ID; die Prüfung ist die zweite Sicherung.)
    2. `provider.interactionDetails(req, res)`; wirft es (`SessionNotFound` oder jeder andere Fehler) → feste Antwort 400, Körper `bad request`, Header `content-type: text/plain; charset=utf-8`, `cache-control: no-store`; Protokoll nur `oauth interaction refused`; kein Wert aus Fehler oder Anfrage.
    3. `details.prompt.name !== "login"` → `deps.fallback`.
    4. `state` = 32 Zufallsbytes als base64url, `nonce` = 32 Zufallsbytes als base64url (`node:crypto` `randomBytes`). Ablage `new PgAdapter(pool, "AppleLogin", now).upsert(state, { uid: details.uid, nonce }, ttl)` mit `ttl = min(600, floor(details.exp − now/1000))`. Schlägt die Ablage fehl oder ist `ttl ≤ 0` → feste 400 wie in 2 (bei Ablagefehler Protokoll `oauth interaction store failed`), nie eine Weiterleitung ohne gespeicherten Zustand.
    5. 303 mit `location: authorizeUrl(config, { redirectUri: appleReturnUrl(publicUrl), state, nonce })`, `cache-control: no-store`, `referrer-policy: no-referrer`, leerer Körper.
  - Keine Schreibzugriffe auf `res` nach der Antwort; keine anderen Prompts, kein `interactionFinished` (S4b-2).
- **`server/src/oauth-provider.ts`** (ändern): `productInteraction` bleibt unverändert und exportiert; Kommentar darüber nennt, dass sie ab S4b-1 der Rückfall für „keine Apple-Konfiguration“ und für Prompt `consent` ist. Sonst keine Verhaltensänderung; `createProvider` und `Interaction` bleiben.
- **`server/src/main.ts`** (ändern)
  - Die JWKS-Instanz wird je `start()` einmal erzeugt (nur mit Apple-Konfiguration) und sowohl `mountAuth` als auch `mountIssuer` gereicht, statt in `mountAuth` zu entstehen.
  - `mountIssuer` baut `appleInteraction`, wenn `options.auth?.config?.webClientId` gesetzt ist, `options.oauth.interaction` **nicht** gesetzt ist (Tests dürfen weiter eigene Interaktionen einhängen) und der Aussteller Schlüssel hat; Rückfall `productInteraction`. `main()` reicht dafür `auth: { config }` und `oauth: { publicUrl, keys }` wie bisher; die Interaktion entsteht aus der Konfiguration, `main()` selbst setzt `oauth.interaction` nicht.
  - Das Fehlerfenster bleibt: 501 zählt nicht, jede andere Antwort zählt; die feste 400 und die 303 laufen durch denselben `finish`-Haken. `/oauth/apple/return` bleibt unbehandelt (404 des Ausstellers).

### Festlegungen

- **Keine Werte in Antworten, Protokoll, Fehlern:** weder `state`, `nonce`, `uid`, Web-ID noch Apple-Adresse tauchen in Protokollzeilen oder festen Antworten auf; die einzige Stelle mit `state`/`nonce` außerhalb der Ablage ist die Weiterleitungsadresse an Apple.
- **Der App-Weg und alle bestehenden Tests bleiben unverändert grün;** `oauth-provider.test.ts` hängt eigene Interaktionen ein und sieht keinen Unterschied.
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; Test-Stil wie bisher (`node:test`, `node:assert/strict`, eingereichtes `fetch`, kein Netz, Wegwerf-Schema je Dienst).
- **Unberührt:** `apple.ts`, `apple-client.ts`, `apple-jwks.ts`, `apple-vault.ts`, `auth.ts`, `accounts.ts`, `oauth-adapter.ts`, `oauth-resource.ts`, `mcp.ts`, Migrationen, jede Swift-Datei, `.github/`, nginx und Compose in `henemm-infra`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `authorizeUrl`, `appleReturnUrl`, `AppleConfig.webClientId` (S4a) | bestehend, ungeändert |
| `PgAdapter` (S2, Modell `AppleLogin` ohne eigene Tabelle) | bestehend, ungeändert |
| `createProvider`, `Interaction`, `productInteraction` (S3) | bestehend |
| `createJwks` (`KeyLookup`) | bestehend, nur durchgereicht |
| `oidc-provider` 9.13.3 (`interactionDetails`) | bestehend, keine neue Abhängigkeit |
| `node:crypto` (`randomBytes`) | Node |
| Tests: CIMD-Client und Helfer aus `oauth-provider.test.ts` (`cimd`, `raw`, `pkce`, `authQuery`, `service`) | Vorbild; da nicht exportiert, im neuen Testfile knapp nachgebaut |
| Downstream | S4b-2 (`/oauth/apple/return`, Ticket, `finish`), S5 (Zustimmung), Web-Token-Schnitt vor S6, S6 (Services ID im Apple-Konto, nginx `/oauth/*`, `APPLE_WEB_CLIENT_ID`, OAuth-Schlüssel in Compose) |

## Acceptance Criteria

Tests in `server/test/oauth-interaction.test.ts` mit `node:test` und `node:assert/strict`, Ende-zu-Ende gegen ein Wegwerf-Postgres. Der Test startet `start()` mit `oauth: { publicUrl: "https://loose-ends.test", keys, fetch: <CIMD-Client> }` und `auth: { config }` (Web-ID `com.henning.looseends.web`, App-ID `com.henning.looseends`, Test-Schlüssel wie in `apple-client.test.ts`), ruft `/oauth/auth` mit dem CIMD-Client `https://claude.ai/oauth/test-client` (PKCE S256, Ressource `https://loose-ends.test/mcp`, Scope `tasks offline_access`) auf, folgt der 303 auf `/oauth/interaction/<uid>` mit den vom Aussteller gesetzten Cookies und fragt dann die Interaktion ab. Apple wird nie erreicht.

- **AC-1:** Login leitet zu Apple: GIVEN der Dienst mit Apple-Konfiguration samt Web-ID und OAuth-Schlüsseln WHEN GET `/oauth/interaction/<uid>` mit dem Interaktions-Cookie THEN Status 303, `location` beginnt mit `https://appleid.apple.com/auth/authorize?`, die geparsten Parameter sind genau `client_id=com.henning.looseends.web`, `redirect_uri=https://loose-ends.test/oauth/apple/return`, `response_type=code`, `response_mode=form_post`, `state` (≥ 43 Zeichen base64url), `nonce` (64 Hexzeichen), ohne `scope`; Header `cache-control: no-store` und `referrer-policy: no-referrer`; leerer Körper. Test: „hinweg: login leitet mit allen parametern zu apple“.
- **AC-2:** Ablage gehasht, mit Ablauf, einmal einlösbar: GIVEN die Weiterleitung aus AC-1 WHEN die Zeile in `oauth_records` (Modell `AppleLogin`) gelesen wird THEN steht dort `id_hash` = SHA-256 von `state` (das `state` selbst und die rohe `nonce` kommen in keiner Spalte als Klartext vor), `payload` enthält genau `uid` (die der Interaktion) und die rohe `nonce`, deren SHA-256-Hex gleich dem `nonce`-Parameter der Apple-Adresse ist, `expires_at` liegt ≤ 600 s hinter der (injizierten) Jetztzeit und nie hinter dem Ablauf der Interaktion; `new PgAdapter(pool, "AppleLogin", now).find(state)` liefert den Payload, das erste `consume(state)` gelingt, das zweite wirft, ein `find` nach Ablauf (Uhr vorgestellt) liefert nichts. Test: „hinweg: zustand gehasht, mit ablauf, einmal einlösbar“.
- **AC-3:** TTL folgt der Restlaufzeit: GIVEN eine Interaktion, deren Restlaufzeit unter 600 s liegt (Uhr nach dem Anlegen um 540 s vorgestellt) WHEN der Hinweg läuft THEN ist `expires_at` gleich dem Ablauf der Interaktion (nicht 600 s ab jetzt); ist die Interaktion abgelaufen (Uhr um 601 s vorgestellt, falls die Bibliothek sie noch liefert) oder die Restlaufzeit nicht positiv, ist die Antwort die feste 400 und es steht keine `AppleLogin`-Zeile in der Datenbank. Test: „hinweg: ttl folgt der restlaufzeit“.
- **AC-4:** Jeder Versuch hat eigene Werte: GIVEN zwei getrennte Interaktionen WHEN beide den Hinweg durchlaufen THEN unterscheiden sich `state` und `nonce`, und zwei Zeilen liegen vor. Test: „hinweg: state und nonce je versuch verschieden“.
- **AC-5:** Prompt `consent` bleibt 501: GIVEN eine Interaktion, deren erster Schritt `login` die Test-Hilfe `interactionFinished({ login })` abschließt (eine nur in diesem Test eingehängte Hilfsinteraktion bildet den Anmeldeschritt nach; der Dienst selbst legt kein Konto an) und die dadurch den Prompt `consent` erzeugt WHEN GET der neuen Interaktion mit `appleInteraction` als Interaktion THEN 501, Körper `sign-in not available`, `cache-control: no-store`, keine `AppleLogin`-Zeile. (Aufbau: ein Konto per `findOrCreate`, Anmeldung über die Bibliothek mit `interactionFinished`, dann der Gegenstand der Prüfung.) Test: „hinweg: consent bleibt feste 501“.
- **AC-6:** Ohne Apple-Konfiguration 501: GIVEN `start()` mit OAuth-Schlüsseln, aber ohne `auth` (und ein zweites Mal mit `auth: { config }` ohne `webClientId`) WHEN GET `/oauth/interaction/<uid>` mit Cookie THEN 501 mit demselben festen Körper wie in AC-5, keine `AppleLogin`-Zeile, keine Weiterleitung. Test: „hinweg: ohne apple-konfiguration oder web-id feste 501“.
- **AC-7:** Fehlendes oder fremdes Cookie → feste 400: GIVEN eine echte Interaktion WHEN GET `/oauth/interaction/<uid>` ohne Cookie, mit dem Cookie einer anderen Interaktion und mit unbekannter `uid` THEN jeweils Status 400, Körper genau `bad request`, `cache-control: no-store`; keine `AppleLogin`-Zeile; weder die `uid` noch ein Cookiewert noch ein Fehlertext stehen im Körper. Test: „hinweg: ohne passendes cookie feste 400“.
- **AC-8:** Ablagefehler führt nicht zu einer Weiterleitung: GIVEN `appleInteraction` mit einem Pool, dessen `AppleLogin`-Schreibzugriff scheitert (Aufbau im Test: `appleInteraction` bekommt statt des echten Pools einen Ersatz, dessen `query` beim Schreiben verwirft; die Interaktion selbst läuft über den echten Aussteller) WHEN der Hinweg läuft THEN feste 400 ohne `location`-Header, Protokoll enthält `oauth interaction store failed`. Test: „hinweg: ablagefehler ergibt 400 ohne weiterleitung“.
- **AC-9:** Keine Werte im Protokoll: GIVEN alle Fälle aus AC-1 bis AC-8 WHEN `console.log`/`console.error`/`process.stdout`/`process.stderr` im Test abgefangen werden THEN enthält keine Zeile `state`, `nonce`, `uid`, Web-ID, Cookiewert, Apple-Adresse oder Fehlertext; erlaubt sind nur die festen Ereignisnamen `oauth interaction refused` und `oauth interaction store failed`. Test: „hinweg: protokoll ohne werte“.
- **AC-10:** Fehlerfenster unberührt: GIVEN ein Dienst mit injizierter Uhr, ≥ 20 Hinweg-Anfragen in 5 min, davon die Hälfte 303 und der Rest feste 501 (consent / ohne Konfiguration) WHEN `/health` abgefragt wird THEN 200 (die 501 zählt nicht, die 303 ist kein 5xx); die feste 400 zählt als 4xx, nicht als Fehler. Test: „hinweg: fehlerfenster unberuehrt“.
- **AC-11:** Eigene Test-Interaktionen bleiben möglich: GIVEN `start()` mit `oauth.interaction` gesetzt (wie in `oauth-provider.test.ts`) und Apple-Konfiguration mit Web-ID WHEN eine Anmeldung läuft THEN greift die eingehängte Interaktion, `appleInteraction` wird nicht gebaut (keine `AppleLogin`-Zeile). Zusätzlich laufen alle Fälle von `oauth-provider.test.ts`, `main.test.ts`, `auth.test.ts` unverändert grün. Test: „einhaengen: gesetzte interaktion hat vorrang“ und `./server/scripts/test-local.sh`.
- **AC-12:** `/oauth/apple/return` bleibt unbehandelt: GIVEN der Dienst wie in AC-1 WHEN POST `/oauth/apple/return` (leer, mit Form-Körper) THEN antwortet der Aussteller mit seiner üblichen 404 ohne Wert; es entsteht nichts in der Datenbank. Test: „hinweg: rueckweg noch nicht behandelt“.
- **AC-13:** Eine JWKS-Instanz je `start()`: GIVEN `start()` mit Apple-Konfiguration samt Web-ID und OAuth-Schlüsseln, `fetch` eingereicht (zählt Aufrufe) WHEN ein Hinweg läuft und `/auth/apple` mit einem Test-Identity-Token befragt wird THEN lädt Apples Schlüsselsatz höchstens einmal (gemeinsame Instanz; der Hinweg selbst ruft Apple nie), und `appleInteraction` erhält dieselbe Instanz (belegt durch den Abruf-Zähler, nicht durch Einblick in interne Felder). Test: „einhaengen: eine jwks-instanz je start“.
- **AC-14:** Gesamtlauf: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf; es gibt keinen neuen Eintrag in `server/package.json` und keine neue Migration. Dateigrenze und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main -- server`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Nachweis: `./server/scripts/test-local.sh`, CI `server.yml`, `/60-validate`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/oauth-interaction.ts` | CREATE | `appleInteraction(deps)`: Prompt-Weiche, `state`/`nonce`, Ablage `AppleLogin`, 303 zu Apple, feste 400/501, ≈ +55 |
| `server/src/oauth-provider.ts` | MODIFY | Kommentar an `productInteraction` (Rückfall für „ohne Apple“ und `consent`), ≈ +2 |
| `server/src/main.ts` | MODIFY | eine JWKS-Instanz je `start()` für `mountAuth` und `mountIssuer`, `appleInteraction` aus der Konfiguration bauen, ≈ +20 |
| `server/test/oauth-interaction.test.ts` | CREATE | AC-1 bis AC-13, ≈ +190 |

### Estimated Changes

- **Files: 4** (Code: `oauth-interaction.ts`, `oauth-provider.ts`, `main.ts`; Test: `oauth-interaction.test.ts`). `CLAUDE.md`, Spec und Kontext zählen nicht.
- **Code ≈ +80 LoC**, **Tests ≈ +190 LoC** (≈ 2,4× Code, wie in den Vorgängerschnitten), insgesamt ≈ 270 LoC.
- **Offen: Die Summe kann das Limit von ±250 LoC überschreiten** (Schätzung 270, mit Streuung bis ≈ 300). Warum das hingenommen wird: Die Last liegt in den Sicherheitstests (Ende-zu-Ende über `/oauth/auth` mit CIMD-Client, Cookie-Handling, Ablage gehasht, TTL, Einmal-Einlösen, Log ohne Werte), nicht im Code; sie lassen sich ohne Verlust an Aussage nicht kürzen, und eine weitere Teilung (z. B. 4b-1a Ablage, 4b-1b Weiterleitung) bräuchte denselben Testaufbau zweimal. Knapp gehalten wird das Testfile durch gemeinsame Hilfsfunktion `begin()` (Anmeldung bis zur Interaktion), tabellengetriebene Fälle für AC-6 und AC-7 und eine einzige Abfangstelle für das Protokoll (AC-9, AC-10 laufen über dieselben Aufrufe wie AC-1 bis AC-8). Wächst die Schätzung beim Bauen über 300, wird das vor dem Weiterbauen gemeldet. Mit der Freigabe dieser Spec wird die mögliche Überschreitung ausdrücklich angenommen (Präzedenz #621 S3, S4a, #615 S2a).
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Migration, kein `generate`, keine neue Abhängigkeit.
- Doku als Teil des Schnitts: `CLAUDE.md` (`server/`-Abschnitt) bekommt eine Zeile zu `src/oauth-interaction.ts` (`appleInteraction`: Hinweg, Modell `AppleLogin`, Ablage, feste 400/501, Rückfall `productInteraction`; Rückweg S4b-2, Web-Token-Ablage vor S6) und ergänzt bei `main.ts` die geteilte JWKS-Instanz.
- Seiteneffekte nach außen: keine. Der Dienst ist nicht erreichbar (nginx bis S6), ohne `APPLE_WEB_CLIENT_ID` und OAuth-Schlüssel ändert sich kein Verhalten; es entstehen weder Konten noch Sitzungen noch Apple-Aufrufe.

## Risiken

- **Interaktion antwortet nicht mehr fest:** Bisher 501 für jeden Prompt; jetzt eine echte Weiterleitung für `login`. Gegenmaßnahme: nur mit Web-ID und Schlüsseln; AC-5, AC-6, AC-11 sichern 501 und Test-Einhängung.
- **Weiterleitung ohne gespeicherten Zustand** würde S4b-2 unbrauchbar machen und `state` ins Leere laufen lassen. Gegenmaßnahme: Weiterleitung erst nach erfolgreicher Ablage (AC-8).
- **Werte in Protokoll oder Antwort** (`state`, `nonce`, `uid`, Konto-ID im FK-Detail): AC-9; Antworten fest ohne Wert (AC-7).
- **Sitzungsfixierung / Login-CSRF:** Der Hinweg verlangt das Bibliotheks-Cookie (AC-7); die Bindung des Rückwegs an dieselbe `uid` samt Ticket folgt in S4b-2 und ist dort Kern der Prüfung.
- **`details.exp` und Uhr:** Die Bibliothek rechnet mit ihrer Uhr; der Test stellt `now` vor und prüft die TTL gegen den Ablauf der Interaktion (AC-3). Weicht das Verhalten der Bibliothek bei abgelaufener Interaktion ab (liefert sie keine Details mehr), greift ohnehin die feste 400 aus `SessionNotFound`.
- **Zustimmung nach der Anmeldung:** `consent` bleibt bis S5 die feste 501; Ende-zu-Ende endet bis dahin an der Zustimmung. Der Dienst ist bis S6 nicht öffentlich.
- **Datenschutz:** gespeichert werden nur Hash, Zufallswerte und die Interaktions-`uid`, kurzlebig (≤ 10 min); keine personenbezogenen Daten, Datenschutztext unberührt.

## Test Plan

### Automated Tests (TDD RED)

RED: `server/src/oauth-interaction.ts` existiert nicht, `main.ts` baut keine Apple-Interaktion; alle Hinweg-Tests schlagen fehl (501 statt 303, fehlender Import).

| Testname | AC |
|---|---|
| „hinweg: login leitet mit allen parametern zu apple“ | AC-1 |
| „hinweg: zustand gehasht, mit ablauf, einmal einlösbar“ | AC-2 |
| „hinweg: ttl folgt der restlaufzeit“ | AC-3 |
| „hinweg: state und nonce je versuch verschieden“ | AC-4 |
| „hinweg: consent bleibt feste 501“ | AC-5 |
| „hinweg: ohne apple-konfiguration oder web-id feste 501“ | AC-6 |
| „hinweg: ohne passendes cookie feste 400“ | AC-7 |
| „hinweg: ablagefehler ergibt 400 ohne weiterleitung“ | AC-8 |
| „hinweg: protokoll ohne werte“ | AC-9 |
| „hinweg: fehlerfenster unberuehrt“ | AC-10 |
| „einhaengen: gesetzte interaktion hat vorrang“ + alle Altfälle | AC-11 |
| „hinweg: rueckweg noch nicht behandelt“ | AC-12 |
| „einhaengen: eine jwks-instanz je start“ | AC-13 |
| `./server/scripts/test-local.sh`, `/60-validate` (Dateiliste per `git diff`) | AC-14 |

- [ ] Test 1 (AC-1, AC-4): GIVEN CIMD-Client, Apple-Konfiguration mit Web-ID, Schlüssel WHEN Anmeldung bis zur Interaktion und Hinweg THEN 303 mit allen Parametern, ohne `scope`, `no-store`, `no-referrer`, je Versuch eigene Werte.
- [ ] Test 2 (AC-2, AC-3): GIVEN die Weiterleitung WHEN `oauth_records` und `PgAdapter` befragt werden, Uhr vorgestellt THEN nur Hash und Payload `{ uid, nonce }`, TTL = Minimum, einmal `consume`, nach Ablauf unsichtbar.
- [ ] Test 3 (AC-5, AC-6, AC-12): GIVEN Prompt `consent` bzw. fehlende Konfiguration bzw. Rückweg-Adresse WHEN abgefragt THEN feste 501 bzw. 404, nichts in der Datenbank.
- [ ] Test 4 (AC-7, AC-8): GIVEN fehlendes, fremdes Cookie, unbekannte `uid`, Ablagefehler WHEN abgefragt THEN feste 400 ohne Wert, ohne `location`.
- [ ] Test 5 (AC-9, AC-10): GIVEN alle Fälle WHEN Protokoll und `/health` geprüft werden THEN keine Werte, Fehlerfenster unberührt.
- [ ] Test 6 (AC-11, AC-13, AC-14): GIVEN gesetzte Test-Interaktion bzw. geteilte JWKS bzw. Gesamtlauf WHEN gestartet THEN Vorrang der Test-Interaktion, ein Schlüsselabruf, alles grün.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): Zustand in der DB über `PgAdapter` (`AppleLogin`), Rückweg später per 303 zurück unter den Interaktionspfad** | `state → { uid, nonce }` gehasht, einmal einlösbar; der Abschluss läuft über einen GET mit dem Bibliotheks-Cookie | keine Migration, keine zweite Cookie-Sorte; Bindung an denselben Browser bleibt über das Bibliotheks-Cookie; der Code steht nie in einer URL (S4a) | zusätzlicher Schritt (Weiterleitung und Ticket) im Rückweg; Zeilen in `oauth_records` | — |
| B Eigenes `SameSite=None; Secure`-Cookie für `state`/`nonce` | Zustand im Browser statt in der DB | keine Zeilen in der DB, keine Ablage zu räumen | zweites Cookie mit eigener Signierung und schwächerer Cookie-Haltung; `interactionFinished` braucht trotzdem den Sprung zurück unter den Interaktionspfad (das Bibliotheks-Cookie reist beim seitenübergreifenden POST nicht) | die Wahl „Cookie-Haltung nur Bibliothek, Lax“ |
| C Interaktion im Rückweg ohne Cookie per `provider.Interaction.find(uid)` abschließen | keine Weiterleitung, kein Ticket | einfacher Rückweg | die Bindung an den Browser, der die Anmeldung begonnen hat, entfällt (Login-CSRF / Unterschieben einer fremden Anmeldung); wer `state` abfängt, schließt fremde Interaktionen ab | die Bindung an den Browser als Sicherheitsannahme von S4b |
| D `response_mode=query` | Rückweg als normale Weiterleitung, Lax-Cookies reisen | keine DB-Ablage nötig | Code steht in URL, Verlauf und nginx-Log; nur ohne Name und E-Mail möglich | die S4a-Wahl „Code nie in einer URL“ (`form_post`) |
| E Zwei getrennte Zufallswerte in `state` (kein Hash-Schlüssel, nonce im Cookie) | weniger Datenbank | — | verteilt den Zustand auf zwei Orte, Cookie-Probleme wie B | wie B |
| F Hinweg und Rückweg in einem Schnitt | ein Durchstich | ein PR, keine Zwischenstände | Code ≈ 220 + Tests ≈ 2,5× weit über 250 LoC; Sicherheitslogik zweier verschiedener Richtungen in einem Review | die Teilung S4b-1 / S4b-2 |

Befunde gegen den Plan: Der Schnittplan nannte S4b mit ≈ 220 LoC Code; die ehrliche Schätzung mit Tests liegt bei ≈ 500, deshalb geteilt. Keine blockierenden Befunde. Zur Frage „Apple-Web-Token speichern“: **nicht in S4b**, weil `apple_tokens` eine Zeile je Konto hat (das Web-Token würde das App-Token überschreiben) und `revokeAfterDelete` nur App-IDs kennt; eigener Schnitt vor S6 mit Migration 005.

## Out of Scope / Folgeschnitte

- **S4b-2, Rückweg und Abschluss:** POST `/oauth/apple/return` (Körper selbst lesen, Limit, urlencoded; `user` ignorieren), `consume(state)`, Apple-`error` → `access_denied`, `redeemCode` mit Web-ID und `redirectUri`, `verifyIdentityToken` (rohe Nonce, `audiences: [webClientId]`), gleicher `sub`, `findOrCreate`, einmaliges Ticket (60 s, an `uid` gebunden), 303 auf `GET /oauth/interaction/<uid>/finish?ticket=…`, dort `interactionFinished({ login: { accountId } })`. Eigener Workflow, Größe absehbar über 250 LoC mit Tests, wird vorher genannt.
- **Zustimmungsseite und Erlaubnisliste (S5):** `consent`-Prompt, nur Henning (`apple_sub`) bis #625.
- **Web-Token-Ablage (eigener Schnitt vor S6):** Ablage je Konto und `client_id` (Migration 005), Widerruf aller Tokens beim Löschen.
- **Betrieb (S6):** Services ID im Apple-Konto (Henning meldet sich im Portal an, die Klicks übernimmt Claude im Browser-Tab), nginx `/oauth/*` einschließlich `/oauth/apple/return`, `APPLE_WEB_CLIENT_ID` und OAuth-Schlüssel in Compose (Repo `henemm-infra`).

## Abnahme

Kein Pfad der Geräteliste berührt (nur `server/`, keine App, kein `project.yml`). Die Abnahme endet nach den Tests: `./server/scripts/test-local.sh` (typecheck + `node --test` gegen ein Wegwerf-Postgres) grün und die CI `server.yml` auf dem PR grün. Ein Simulator-Durchlauf entfällt, weil es reiner Dienstcode ohne Oberfläche ist und der Dienst von außen noch nicht erreichbar ist; der Hinweg wird in den Tests Ende-zu-Ende über `/oauth/auth` mit dem CIMD-Client durchgespielt (echter Aussteller, echte Datenbank, nur Apple entfällt). Stufe 3 entfällt.

## Definition of Done

- [ ] AC-1 bis AC-14 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) aktualisiert: neue Zeile zu `server/src/oauth-interaction.ts` (`appleInteraction`, Modell `AppleLogin`, feste 400/501, Rückfall `productInteraction`, Rückweg in S4b-2) und die geteilte JWKS-Instanz in `main.ts`
- [ ] #621 kommentiert (Stand Schnitt 4b-1, Folge: S4b-2 Rückweg, Web-Token-Ablage vor S6, S5, S6), Board-Karte aktuell

## Changelog

- 2026-11-06: Initial spec created (Schnitt 4b-1)
- 2026-11-06 (/60-validate): Endstand 496 LoC (112 Code, 381 Tests); Freigabe nach RED im Kontextdokument, in der Validierung erneut angenommen. Teststärke, nachzuschärfen in S4b-2: AC-10 verdünnt die Quote durch die Anfragen von `begin()` und belegt daher nicht, dass 501/400 ungezählt bleiben; der Mitschnitt in `after` lässt jedes kleingeschriebene Ereignis zu statt nur die zwei festen; AC-13 belegt die geteilte JWKS-Instanz nur für `/auth/apple`, weil der Hinweg `keys` noch nicht benutzt. Der Code ist an allen drei Stellen korrekt (`main.ts` zählt nur 5xx außer der festen 501). Über die Spec hinaus prüft der Hinweg die Pfad-uid gegen die Cookie-uid (fremde uid → 400, auch vor `consent`).
