# Adversary Dialog — feat-621-s4b-anmeldung
Spec: docs/specs/feat-621-schnitt-4b1-hinweg.md
Datum: 2026-11-06 13:30

## Checkliste
- [x] **AC-1:** Login leitet zu Apple: GIVEN der Dienst mit Apple-Konfiguration samt Web-ID und OAuth-Schlüsseln WHEN GET `/oauth/interaction/<uid>` mit dem Interaktions-Cookie THEN Status 303, `location` beginnt mit `https://appleid.apple.com/auth/authorize?`, die geparsten Parameter sind genau `client_id=com.henning.looseends.web`, `redirect_uri=https://loose-ends.test/oauth/apple/return`, `response_type=code`, `response_mode=form_post`, `state` (≥ 43 Zeichen base64url), `nonce` (64 Hexzeichen), ohne `scope`; Header `cache-control: no-store` und `referrer-policy: no-referrer`; leerer Körper. Test: „hinweg: login leitet mit allen parametern zu apple“.
- [x] **AC-2:** Ablage gehasht, mit Ablauf, einmal einlösbar: GIVEN die Weiterleitung aus AC-1 WHEN die Zeile in `oauth_records` (Modell `AppleLogin`) gelesen wird THEN steht dort `id_hash` = SHA-256 von `state` (das `state` selbst und die rohe `nonce` kommen in keiner Spalte als Klartext vor), `payload` enthält genau `uid` (die der Interaktion) und die rohe `nonce`, deren SHA-256-Hex gleich dem `nonce`-Parameter der Apple-Adresse ist, `expires_at` liegt ≤ 600 s hinter der (injizierten) Jetztzeit und nie hinter dem Ablauf der Interaktion; `new PgAdapter(pool, "AppleLogin", now).find(state)` liefert den Payload, das erste `consume(state)` gelingt, das zweite wirft, ein `find` nach Ablauf (Uhr vorgestellt) liefert nichts. Test: „hinweg: zustand gehasht, mit ablauf, einmal einlösbar“.
- [x] **AC-3:** TTL folgt der Restlaufzeit: GIVEN eine Interaktion, deren Restlaufzeit unter 600 s liegt (Uhr nach dem Anlegen um 540 s vorgestellt) WHEN der Hinweg läuft THEN ist `expires_at` gleich dem Ablauf der Interaktion (nicht 600 s ab jetzt); ist die Interaktion abgelaufen (Uhr um 601 s vorgestellt, falls die Bibliothek sie noch liefert) oder die Restlaufzeit nicht positiv, ist die Antwort die feste 400 und es steht keine `AppleLogin`-Zeile in der Datenbank. Test: „hinweg: ttl folgt der restlaufzeit“.
- [x] **AC-4:** Jeder Versuch hat eigene Werte: GIVEN zwei getrennte Interaktionen WHEN beide den Hinweg durchlaufen THEN unterscheiden sich `state` und `nonce`, und zwei Zeilen liegen vor. Test: „hinweg: state und nonce je versuch verschieden“.
- [x] **AC-5:** Prompt `consent` bleibt 501: GIVEN eine Interaktion, deren erster Schritt `login` die Test-Hilfe `interactionFinished({ login })` abschließt (eine nur in diesem Test eingehängte Hilfsinteraktion bildet den Anmeldeschritt nach; der Dienst selbst legt kein Konto an) und die dadurch den Prompt `consent` erzeugt WHEN GET der neuen Interaktion mit `appleInteraction` als Interaktion THEN 501, Körper `sign-in not available`, `cache-control: no-store`, keine `AppleLogin`-Zeile. (Aufbau: ein Konto per `findOrCreate`, Anmeldung über die Bibliothek mit `interactionFinished`, dann der Gegenstand der Prüfung.) Test: „hinweg: consent bleibt feste 501“.
- [x] **AC-6:** Ohne Apple-Konfiguration 501: GIVEN `start()` mit OAuth-Schlüsseln, aber ohne `auth` (und ein zweites Mal mit `auth: { config }` ohne `webClientId`) WHEN GET `/oauth/interaction/<uid>` mit Cookie THEN 501 mit demselben festen Körper wie in AC-5, keine `AppleLogin`-Zeile, keine Weiterleitung. Test: „hinweg: ohne apple-konfiguration oder web-id feste 501“.
- [x] **AC-7:** Fehlendes oder fremdes Cookie → feste 400: GIVEN eine echte Interaktion WHEN GET `/oauth/interaction/<uid>` ohne Cookie, mit dem Cookie einer anderen Interaktion und mit unbekannter `uid` THEN jeweils Status 400, Körper genau `bad request`, `cache-control: no-store`; keine `AppleLogin`-Zeile; weder die `uid` noch ein Cookiewert noch ein Fehlertext stehen im Körper. Test: „hinweg: ohne passendes cookie feste 400“.
- [x] **AC-8:** Ablagefehler führt nicht zu einer Weiterleitung: GIVEN `appleInteraction` mit einem Pool, dessen `AppleLogin`-Schreibzugriff scheitert (Aufbau im Test: `appleInteraction` bekommt statt des echten Pools einen Ersatz, dessen `query` beim Schreiben verwirft; die Interaktion selbst läuft über den echten Aussteller) WHEN der Hinweg läuft THEN feste 400 ohne `location`-Header, Protokoll enthält `oauth interaction store failed`. Test: „hinweg: ablagefehler ergibt 400 ohne weiterleitung“.
- [x] **AC-9:** Keine Werte im Protokoll: GIVEN alle Fälle aus AC-1 bis AC-8 WHEN `console.log`/`console.error`/`process.stdout`/`process.stderr` im Test abgefangen werden THEN enthält keine Zeile `state`, `nonce`, `uid`, Web-ID, Cookiewert, Apple-Adresse oder Fehlertext; erlaubt sind nur die festen Ereignisnamen `oauth interaction refused` und `oauth interaction store failed`. Test: „hinweg: protokoll ohne werte“.
- [x] **AC-10:** Fehlerfenster unberührt: GIVEN ein Dienst mit injizierter Uhr, ≥ 20 Hinweg-Anfragen in 5 min, davon die Hälfte 303 und der Rest feste 501 (consent / ohne Konfiguration) WHEN `/health` abgefragt wird THEN 200 (die 501 zählt nicht, die 303 ist kein 5xx); die feste 400 zählt als 4xx, nicht als Fehler. Test: „hinweg: fehlerfenster unberuehrt“.
- [x] **AC-11:** Eigene Test-Interaktionen bleiben möglich: GIVEN `start()` mit `oauth.interaction` gesetzt (wie in `oauth-provider.test.ts`) und Apple-Konfiguration mit Web-ID WHEN eine Anmeldung läuft THEN greift die eingehängte Interaktion, `appleInteraction` wird nicht gebaut (keine `AppleLogin`-Zeile). Zusätzlich laufen alle Fälle von `oauth-provider.test.ts`, `main.test.ts`, `auth.test.ts` unverändert grün. Test: „einhaengen: gesetzte interaktion hat vorrang“ und `./server/scripts/test-local.sh`.
- [x] **AC-12:** `/oauth/apple/return` bleibt unbehandelt: GIVEN der Dienst wie in AC-1 WHEN POST `/oauth/apple/return` (leer, mit Form-Körper) THEN antwortet der Aussteller mit seiner üblichen 404 ohne Wert; es entsteht nichts in der Datenbank. Test: „hinweg: rueckweg noch nicht behandelt“.
- [x] **AC-13:** Eine JWKS-Instanz je `start()`: GIVEN `start()` mit Apple-Konfiguration samt Web-ID und OAuth-Schlüsseln, `fetch` eingereicht (zählt Aufrufe) WHEN ein Hinweg läuft und `/auth/apple` mit einem Test-Identity-Token befragt wird THEN lädt Apples Schlüsselsatz höchstens einmal (gemeinsame Instanz; der Hinweg selbst ruft Apple nie), und `appleInteraction` erhält dieselbe Instanz (belegt durch den Abruf-Zähler, nicht durch Einblick in interne Felder). Test: „einhaengen: eine jwks-instanz je start“.
- [x] **AC-14:** Gesamtlauf: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf; es gibt keinen neuen Eintrag in `server/package.json` und keine neue Migration. Dateigrenze und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main -- server`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Nachweis: `./server/scripts/test-local.sh`, CI `server.yml`, `/60-validate`.

## Dialog

### Runde 1
**Adversary:** Beweis je AC? Lauf `./server/scripts/test-local.sh` (Ausgabe adversary-test-output.txt): typecheck `tsc --noEmit` ohne Fehler, 306 pass, 0 fail, 0 skipped; die 12 Hinweg-Tests (Zeilen 316-358) laufen alle gruen, einschliesslich der Namen aus AC-1 bis AC-13. Kann ein fremdes Cookie trotzdem zu 303 fuehren (AC-7)? Die Bibliothek vergleicht Cookie-uid nie mit dem Pfad.
**Implementierer:** Code reference: server/src/oauth-interaction.ts:46 vergleicht `details.uid` (aus dem signierten Cookie) mit `pathUid(req.url)` und antwortet sonst mit fester 400 (Z. 47). Cookie A + Pfad B ergibt 400; Cookie A + Pfad A ist der rechtmaessige Fall. Pfad mit Anhang, Prozent-Kodierung, Trailing Slash: uid stimmt nicht, 400 (fail-closed). Test server/test/oauth-interaction.test.ts:278-285 deckt ohne Cookie, fremdes Cookie, unbekannte uid ab. Die Pruefung liegt vor der Prompt-Pruefung (Z. 50), gilt also auch fuer consent. 303 wird nur in Z. 65 erreicht, nach `upsert` (Z. 59), dessen Fehler in Z. 60-62 zu 400 fuehrt: keine Weiterleitung ohne Ablage (c), Test Z. 295. Ohne webClientId geht Z. 38 vor jeder Cookie-Lesung zur festen 501 (AC-6).

### Runde 2
**Adversary:** Raender: TTL genau 0, Bruchteile, NaN; Protokoll; Vorrang; JWKS; Fehlerfenster; package.json/Migration?
**Implementierer:** TTL (Code reference: server/src/oauth-interaction.ts:51-55): `floor(exp - now/1000)` begrenzt auf 600; Rest genau 0, 0.5 s (floor 0), negativ und NaN ergeben `!(ttl > 0)` und damit feste 400 ohne Ablage; Abrunden garantiert expires_at <= Ablauf der Interaktion (AC-3, Test Z. 231-246). Protokoll (b): in oauth-interaction.ts nur `log("oauth interaction refused")` und `log("oauth interaction store failed")` mit festem Text, die catch-Bloecke binden kein Fehlerobjekt; `logError` in server/src/main.ts:35 schreibt nur ISO-Zeit plus Ereignisname; keine console-Aufrufe in der neuen Datei; 400-Antworten tragen nur `bad request` (Z. 24). Test Z. 307-320 prueft Zeilen auf uid und Cookiewerte. Vorrang (e): server/src/main.ts:148-154 gibt `interaction` zurueck, bevor Apple gebaut wird (Test Z. 342-347, Status 418); ohne Config oder keys faellt es auf productInteraction. Eine JWKS-Instanz: server/src/main.ts:122-126 `appleKeys` wird einmal in `start()` erzeugt und an mountAuth und mountIssuer gereicht (Test Z. 367). Fehlerfenster: main.ts:173 laesst nur 501 aus; 303 und 400 sind keine 5xx (Test Z. 323-340). server/src/oauth-provider.ts:30 aendert nur den Kommentar, productInteraction bleibt. (f): Diff von server/package.json und server/migrations ist leer, letzte Migration 004; typecheck gruen. Beobachtung, kein Befund: ein Ablagefehler (DB-Ausfall) liefert 400 und erreicht das Fehlerfenster nicht (spec-konform, AC-8), Ausfaelle erscheinen nur im Protokoll `oauth interaction store failed`.

Findings: keine (nur Beobachtung, LOW, nicht gefuehrt).
Confirmations: AC-1..AC-13 CONFIRMED durch die benannten Tests gruen plus Code-Pfade oben; AC-14 CONFIRMED durch test-local.sh exit 0 und leeren Diff fuer package.json/migrations (Dateigrenze und Funktionslaenge: /60-validate).
Code reference: server/src/oauth-interaction.ts:65
Code reference: server/src/main.ts:148
Code reference: server/src/oauth-provider.ts:30
Code reference: server/test/oauth-interaction.test.ts:278

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 306 bestanden, 0 fehlgeschlagen, 0 uebersprungen; typecheck gruen. Alle 14 ACs belegt, keine Findings.

## Geprüfte Dateien

- sha256:9d3cc1d515aefad85451bff14b0c8052aff37c0581f02d2cd26f80c56c2b7ff0  server/src/main.ts
- sha256:18122bfce6686ae1810b9a812201bdd79f5949a6628d96ae8845575157c70b94  server/src/oauth-interaction.ts
- sha256:d542ada5f6f74b3ebc38a2083caf01e11c012da8d190be39a500b25f8df34030  server/src/oauth-provider.ts
- sha256:282a99f17067c7b3583788379a6683bfb7e3c40695bfe989c122ccd60c09db4e  server/test/oauth-interaction.test.ts

## Prüfbasis

- base: 0690402eaa5531b95ce1ba224958483e685191ea
- blob:c37b082160b1e0782cf9aef0534f0568888666d5  server/src/main.ts
- blob:3bafa02d49694c38afe7680661afce189ebf4559  server/src/oauth-interaction.ts
- blob:cebb4b49f7e48a6aa86e11619a97ba6013812fb1  server/src/oauth-provider.ts
- blob:6c91047cfd8c7b3f62d74a78bea0b255a22e8411  server/test/oauth-interaction.test.ts
