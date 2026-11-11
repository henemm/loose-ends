# Adversary Dialog — feat-795-app-auftraege
Spec: docs/specs/feat-795-schnitt-1-dienst-wege.md
Datum: 2026-11-11 17:37

## Checkliste
- [x] **AC-1:** Abschrift ablegen: GIVEN eine gültige App-Sitzung und eine gültige Abschrift WHEN `POST /app/transcript` mit `content-type: application/json` THEN **204** ohne Körper, `cache-control: no-store`, und `getTranscript` liefert für dieses Konto genau diese Abschrift. Ein zweiter Aufruf mit größerem `generatedAt` ersetzt sie (204, neue Abschrift gespeichert). Test: „app: abschrift ablegen und ersetzen“.
- [x] **AC-2:** Ältere Abschrift ist kein Fehler: GIVEN abgelegte Abschrift mit `generatedAt` T WHEN `POST /app/transcript` mit `generatedAt` T (gleich) und mit T minus 1 Minute (älter) THEN beide **204**, und die abgelegte Abschrift ist unverändert (`received_at` und Inhalt gleich). Test: „app: aeltere abschrift 204 ohne wirkung“.
- [x] **AC-3:** Ungültige Abschrift: WHEN `POST /app/transcript` mit (a) einem Feld zu wenig, (b) unbekannter Version 2, (c) einem Schlüssel `rawText` in einer Aufgabe, (d) einem Schlüssel `note`, (e) JSON, das kein Objekt ist (`[]`, `"x"`, `null`), (f) nicht lesbarem JSON (`{`) THEN jeweils **400** ohne Körper (die Antwort enthält weder Pfad noch Grund, `await response.text()` ist leer), und für das Konto liegt keine Abschrift. Tabellengetrieben, ein Fall je Zeile. Test: „app: ungueltige abschrift 400 ohne details“.
- [x] **AC-4:** Auftrag abholen: GIVEN ein freier Auftrag des Kontos (per `putOrder`) und gültige Sitzung, Kopf `X-Device` = UUID WHEN `POST /app/orders/claim` THEN **200**, `content-type: application/json`, `cache-control: no-store`, Körper ist der Auftrag, gleichwertig (`deepEqual`) zum abgelegten Dokument, und `orders.claimed_by` ist die UUID in Kleinschreibung (auch bei großgeschriebener UUID im Kopf). Ein zweiter `claim` desselben oder eines anderen Geräts sofort danach: **204** (kein freier Auftrag mehr). Test: „app: auftrag abholen genau einmal“.
- [x] **AC-4a:** Reihenfolge und Konto: GIVEN drei freie Aufträge, eingereiht in der Reihenfolge A, B, C, und ein vierter, freier eines anderen Kontos WHEN dreimal `claim` THEN A, B, C in dieser Reihenfolge, beim vierten Mal 204; der Auftrag des anderen Kontos wird nie ausgeliefert. Test: „app: abholen in reihenfolge und nur eigenes konto“.
- [x] **AC-5:** Nichts offen: GIVEN keine Aufträge WHEN `POST /app/orders/claim` THEN **204** ohne Körper, `cache-control: no-store`. Test: „app: abholen ohne auftrag 204“.
- [x] **AC-6:** Ergebnis melden: GIVEN ein an Gerät G vergebener Auftrag WHEN `POST /app/orders/result` mit `X-Device` = G und dem Ergebnis (`outcome: done`, danach im Test ein zweiter Auftrag mit `rejected` und `reason: stale`) THEN **204**; `getResult` meldet `result` mit genau diesem Dokument. Dasselbe Ergebnis ein zweites Mal von G: **204**, die Zeile in `order_results` ist unverändert (`duplicate`). Test: „app: ergebnis melden und wiederholen“.
- [x] **AC-7:** Ergebnis abgelehnt: WHEN `POST /app/orders/result` für (a) einen unbekannten Auftrag, (b) einen nie vergebenen Auftrag, (c) einen an ein anderes Gerät vergebenen, (d) den Auftrag eines anderen Kontos THEN jeweils **409** ohne Körper, und `order_results` bleibt leer. Tabellengetrieben. Test: „app: ergebnis abgelehnt 409“.
- [x] **AC-8:** Ungültiges Ergebnis: WHEN `POST /app/orders/result` mit (a) fehlendem `orderID`, (b) `outcome: rejected` ohne `reason`, (c) unbekanntem `outcome`, (d) `reason` bei `done`, (e) nicht lesbarem JSON THEN jeweils **400** ohne Körper, `order_results` bleibt leer. Test: „app: ungueltiges ergebnis 400“.
- [x] **AC-9:** Anmeldung, tabellengetrieben über alle drei Wege: (a) kein `authorization`-Kopf, (b) Schema `Basic`, (c) `Bearer` ohne Token, (d) `Bearer a b`, (e) unbekanntes Token, (f) abgelaufene Sitzung (`last_used_at` vor 91 Tagen gesetzt), (g) beendete Sitzung (`endSession`), (h) das Token eines gelöschten Kontos, (i) gültige Sitzung mit **fehlendem** `X-Device` bzw. (j) **falschem** `X-Device` (`"gerät"`, UUID ohne Bindestriche, UUID mit 35 Zeichen; nur `claim` und `result`) → (a) bis (h) jeweils **401** ohne Körper und mit `cache-control: no-store`, (i) und (j) jeweils **400**; ein 401 geht der Geräteprüfung voraus (Fall: unbekanntes Token **und** fehlendes `X-Device` → 401). In keinem Fall ändern sich `transcripts`, `orders` oder `order_results` (Zeilenzahlen und Inhalt gleich). Test: „app: sitzung und geraet, jede ablehnung“.
- [x] **AC-10:** Methode, Inhaltstyp, Größe: (a) `GET`, `PUT`, `DELETE` auf jeden der drei Pfade mit gültiger Sitzung → **405** mit `allow: POST`; (b) `POST /app/transcript` und `/app/orders/result` mit `content-type: text/plain` oder ohne → **415**; (c) `application/json; charset=utf-8` → angenommen; (d) ein Körper von genau 256 KiB (262 144 Bytes, gültiges JSON mit Füllfeld) wird gelesen (die Antwort ist dann ein **400** aus der Formprüfung, nicht 413); 256 KiB + 1 Byte und 900 KiB → **413** ohne Körper und die Datenbank ist unberührt; (e) ein Körper über 256 KiB **ohne** `Content-Length` (chunked) und einer, dessen `Content-Length` weniger behauptet, als gesendet wird, ergeben ebenfalls 413 bzw. eine abgebrochene Verbindung, ohne dass Daten abgelegt werden; (f) ein unauthentifizierter Aufruf (kein Token) mit falschem Inhaltstyp oder zu großem Körper antwortet **401**, nicht 415 oder 413 (die Anmeldung geht den Körperprüfungen voraus). Tabellengetrieben, ein Fall je Zeile. Test: „app: methode inhaltstyp und groesse“.
- [x] **AC-11:** Rückholregel, Kern: GIVEN ein an Gerät G1 vergebener Auftrag, dessen `claimed_at` per SQL auf `now() - interval '11 minutes'` gesetzt ist, ohne Ergebnis WHEN Gerät G2 `claim` ruft THEN **200** mit demselben Auftrag, `orders.claimed_by` = G2 und `claimed_at` frisch (nach der Zeit vor dem Aufruf). Danach meldet G1 sein Ergebnis → **409** (`order_results` leer); G2 meldet → **204**. Test: „app: rueckholen nach zehn minuten“.
- [x] **AC-12:** Rückholregel, Grenzen: Die Frist rechnet die Datenbank, sie gilt strikt „älter als“. (a) `claimed_at` = `now() - interval '9 minutes'` → ein `claim` eines anderen Geräts liefert **204** (Auftrag bleibt bei G1, `claimed_by` unverändert); (b) `claimed_at` = `now() - interval '11 minutes'`, **aber** mit schon abgelegtem Ergebnis → **204**, nie zurückgeholt, `order_results` und `claimed_by` unverändert; (c) ein zweiter, freier Auftrag neben einem zurückholbaren: der **ältere** (`created_at`) wird zuerst ausgeliefert, bei zwei `claim`-Aufrufen kommen beide, jeder genau einmal; (d) ein zurückholbarer Auftrag eines **anderen Kontos** wird nicht ausgeliefert. Tabellengetrieben. Test: „app: rueckholen grenzen“.
- [x] **AC-13:** Rückholregel ist atomar: GIVEN ein zurückholbarer Auftrag WHEN zwei Geräte gleichzeitig `claim` rufen (`Promise.all` über zwei Verbindungen des Pools, 20 Wiederholungen mit je frischem Auftrag) THEN genau einer bekommt 200, der andere 204, und `claimed_by` entspricht dem Gewinner; nie zwei 200. Test: „app: rueckholen gleichzeitig genau einer“.
- [x] **AC-14:** Einhängen und Betrieb: (a) Vor `migrate` (Datenbank nicht erreichbar, wie in den bestehenden Tests von `main.test.ts`) antworten alle drei Pfade **503** ohne Körper und rufen die Datenbank nicht; nach `ready` laufen sie. (b) Die Routen laufen in `start()` **ohne** Option `auth` (kein Apple-Setup nötig). (c) `extraRoutes` mit den Schlüsseln `/health` und `/mcp` ändert weiterhin nichts an diesen beiden Pfaden; ein `extraRoutes`-Eintrag `/app/transcript` überschreibt die App-Route (Reihenfolge wie bei `auth`, Test-Naht) — nur belegt, nicht gewünscht in Produktion. (d) Eine Anfrage über dem globalen 1-MiB-Limit des `bridge` an `/app/transcript` antwortet 413 mit `connection: close`, ohne dass die Route läuft. (e) Ein 401 und ein 400 zählen ins Fehlerfenster wie jede Antwort ≥ 400 bleibt unverändert: `/health` kippt weiterhin nur nach Regel aus `main.test.ts`; hier nur belegt, dass 204 und 200 nicht kippen. Test: „app: einhaengen vor migrate und ohne auth“.
- [x] **AC-15:** Keine Preisgabe: Bei jeder Antwort mit Status ≥ 400 aus AC-3, AC-7 bis AC-10 ist `await response.text()` leer (`""`); kein Header außer `cache-control: no-store` (und `allow` bei 405, `connection` bei 413) trägt Inhalt. Der Test sammelt beim Durchlauf der Tabellen aus AC-3, AC-7, AC-8, AC-9, AC-10 jeweils Status, Körper und Kopfnamen und prüft sie gegen diese Regel; ein Logger-Spion in `console.error` (Muster aus `main.test.ts`) bleibt über den ganzen Lauf leer. Test: „app: ablehnungen ohne koerper und ohne log“.
- [x] **AC-16:** Vertragsdokument und Doku: `docs/reference/claude-abschrift-vertrag.md` hat einen neuen Abschnitt (Überschrift enthält „Wege der App“) mit den drei Pfaden (Methode, Kopf `Authorization: Bearer <App-Sitzung>`, `X-Device`, Statuscodes und Körper) und einem Absatz „Rückholen“ mit der Frist 10 Minuten, den Folgen (a) bis (d) aus „Rückholregel“ und dem Hinweis „mindestens einmal“. Der Abschnitt enthält **keinen** weiteren ```json-Block (die Tests von `orders.test.ts` lesen genau drei Blöcke und schlagen sonst fehl; Beispiele im Abschnitt stehen als ```http oder ```text). `CLAUDE.md`, Abschnitt `server/`, nennt `src/app-routes.ts` (drei Wege, Sitzung, `X-Device`, 256 KiB, `gated`, Rückholregel in `claimOrder`, nginx und App noch offen, S1b/S2). Test: „app: vertrag und doku“ (Prüfung per `readFileSync` und Regex: die drei Pfade, `X-Device`, `10 Minuten`, genau drei ```json-Blöcke im Vertrag, `app-routes.ts` in `CLAUDE.md`).
- [x] **AC-17:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/app-routes.ts`, `server/src/orders.ts`, `server/src/main.ts`, `server/test/app-routes.test.ts` und `CLAUDE.md`; `transcripts.ts`, `auth.ts`, `accounts.ts`, `mcp.ts`, `server/migrations/` und alle weiteren Dateien sind unverändert; jede Funktion in den drei Quelldateien hat höchstens 50 Zeilen; in `orders.ts` ändern sich nur `claimOrder` und die Konstante `CLAIM_TIMEOUT_MINUTES`. **Kein dauerhafter Test** (ein Test gegen `origin/main` scheitert im flachen CI-Checkout und ist nach dem Merge leer): Beleg einmalig in `/60-validate`, Befehl, Ausgabe und Funktionslängen im Validierungsprotokoll.

## Dialog

Testlauf: ./server/scripts/test-local.sh, Exit 0, typecheck sauber, 408 bestanden, 0 fehlgeschlagen, 0 übersprungen (docs/artifacts/feat-795-app-auftraege/adversary-test-output.txt). Alle 17 Tests "app: ..." laufen und sind grün.

### Runde 1
**Adversary:** Beweis je AC verlangt, Code gelesen, Tests auf Aussagekraft geprüft.

Confirmation:
  AC: AC-1, AC-2, AC-3
  Code reference: server/src/app-routes.ts:77
  Evidence: transcript() prüft Methode/Sitzung (admitted), dann jsonBody (415, 413, 400 bei JSON/FormError), putTranscript; stored und older enden beide in 204, jede Antwort über status() mit no-store, Körper null.
  Status: CONFIRMED

Confirmation:
  AC: AC-4, AC-4a, AC-5
  Code reference: server/src/app-routes.ts:87
  Evidence: claim() ruft claimOrder mit device() in Kleinschreibung (Zeile 44); 200 mit Response.json und no-store, sonst 204. Reihenfolge ORDER BY created_at, id und Konto-Filter im SQL (server/src/orders.ts:86).
  Status: CONFIRMED

Confirmation:
  AC: AC-6, AC-7, AC-8
  Code reference: server/src/app-routes.ts:96
  Evidence: refused -> 409, stored/duplicate -> 204, FormError aus checkResult -> 400 ohne Körper (jsonBody fängt alles und antwortet nur 400).
  Status: CONFIRMED

Confirmation:
  AC: AC-9, AC-10
  Code reference: server/src/app-routes.ts:51
  Evidence: Reihenfolge 405 -> 401 (bearerToken/resolveSession) -> 400 Gerät; erst danach 415 -> 413 (readLimited zählt beim Lesen, cancel bei Überschreiten, strikt > 262144) -> 400. 401 geht Körperprüfungen voraus, weil admitted vor jsonBody läuft. Test server/test/app-routes.test.ts:288 deckt 405, 415, genau 256 KiB, +1, 900 KiB, chunked, lügende Content-Length, unauthentifiziert.
  Status: CONFIRMED

Confirmation:
  AC: AC-11, AC-12, AC-13
  Code reference: server/src/orders.ts:78
  Evidence: Eine UPDATE-Anweisung; Bedingung `claimed_at < now() - make_interval(mins => $3)` (strikt, DB-Zeit, Konstante 10 als Parameter, nicht Prozesszeit) plus NOT EXISTS order_results; Unterabfrage mit FOR UPDATE SKIP LOCKED, äußeres WHERE wiederholt die Bedingung (Atomarität unter Read Committed). Tests server/test/app-routes.test.ts:322/341/383 grün, inkl. 9 Minuten, vorhandenes Ergebnis, anderes Konto, 20 Wiederholungen parallel.
  Status: CONFIRMED

Confirmation:
  AC: AC-14, AC-15
  Code reference: server/src/main.ts:144
  Evidence: mountApp verpackt jede Route in gated (503 ohne Körper vor migrate), eingehängt vor extraRoutes, /health und /mcp bleiben danach unüberschreibbar (server/src/main.ts:214). Test server/test/app-routes.test.ts:406 belegt 503, Überschreibbarkeit, 1-MiB-Bridge-Grenze mit connection close, kein Fehlerfenster-Kippen; server/test/app-routes.test.ts:439 prüft Körper leer, Kopfnamen, console.error leer. Keine Logausgabe in app-routes.ts gefunden (kein console/Logger).
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: docs/reference/claude-abschrift-vertrag.md:162
  Evidence: Abschnitt "Wege der App (#795 S1)" mit Rückholen (Zeile 186: 10 Minuten, mindestens einmal); genau drei json-Blöcke (Test server/test/app-routes.test.ts:459 grün). CLAUDE.md:527 nennt src/app-routes.ts mit X-Device, 256 KiB, gated, claimOrder, S1b/S2 offen.
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: CLAUDE.md:527
  Evidence: Der Dateinamen-Diff gegen origin/main (ohne docs und .claude) nennt CLAUDE.md, server/src/main.ts, server/src/orders.ts, server/test/app-routes.test.ts; app-routes.ts ist laut Statusliste untracked (neu), damit genau die fünf Dateien. transcripts.ts, auth.ts, accounts.ts, mcp.ts, migrations: kein Diff. In orders.ts ändern sich nur Konstante und claimOrder. Alle Funktionen in app-routes.ts höchstens 22 Zeilen, claimOrder 14, mountApp 3.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: server/src/app-routes.ts:82
  Description: Bekannte Abweichung (1): jsonBody ruft check (checkTranscript/checkResult) auf, putTranscript/putResult prüfen die Form danach erneut. Die FormError-Zweige in putTranscript/putResult sind von der Route aus unerreichbar. Doppelte Arbeit, kein Fehlverhalten.
  Spec requirement: AC-3/AC-8 — ungültig -> 400 ohne Körper
  Conflict: Keiner im Verhalten; Preis ist Doppelprüfung, weil transcripts.ts nicht geändert werden darf. Bewertung: akzeptabel.
  Remediation: Optional später FormError sauber aus put* durchreichen.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: server/src/app-routes.ts:14
  Description: Bekannte Abweichung (2): status/notAllowed/isJson/readLimited sind aus auth.ts kopiert statt exportiert. Dublette, Divergenzrisiko.
  Spec requirement: Unberührt: auth.ts
  Conflict: Spec verbietet Änderung an auth.ts, Kopie ist die spec-konforme Folge. Akzeptabel.
  Remediation: Später gemeinsames Modul.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: server/src/main.ts:123
  Description: Bekannte Abweichung (4): das bestehende gated() liefert 503 ohne cache-control, während die Spec-Schnittstelle "jede Antwort trägt no-store" sagt. AC-14 fordert nur 503 ohne Körper (erfüllt); AC-15 sammelt 503 nicht.
  Spec requirement: Schnittstelle — jede Antwort no-store; AC-14a — 503 ohne Körper
  Conflict: Geringfügige Textabweichung ohne Sicherheitsfolge (503 enthält nichts).
  Remediation: Keine nötig; ggf. Spec-Satz präzisieren.

Bewertung (3): Bedingung in Unterabfrage und äußerem WHERE (server/src/orders.ts:82) ist gewollt, sie schließt das Zurückholen eines gerade von einem anderen Prozess vergebenen Auftrags aus und ist durch AC-13 (20 Läufe) gestützt. Bekanntes Restfenster der Spec (Ergebnis gleichzeitig mit Rückholung) ist in den Risiken akzeptiert.

**Implementierer:** keine Gegenrede nötig.

### Runde 2
**Adversary:** Skepsis gegen das frühe Einverständnis, gezielte Gegenproben:
- 401 vor 400/415/413: admitted() steht in allen drei Routen vor jsonBody; Test server/test/app-routes.test.ts:314 belegt unauthentifiziert mit text/plain und 300 KiB -> 401.
- Leerer Körper bei Ablehnungen: alle Ablehnungen nur über status()/notAllowed() mit null-Body; AC-15-Test iteriert 5 Tabellen und fordert Körper leer und nur allow als Zusatzkopf.
- Strikt "älter als 10 Minuten": `<` (nicht `<=`); Test 9 Minuten bleibt, 11 wird geholt; genau 10 nicht testbar (now() läuft), Strenge aus dem Code ersichtlich.
- Kein Rückholen bei Ergebnis: NOT EXISTS an beiden Stellen; Test "mit ergebnis: nie zurueck".
- X-Device groß: Regex /i, Ablage lowercased (server/src/app-routes.ts:44); Gerät fehlt -> null -> 400.
- 256 KiB bei chunked: readLimited zählt Bytes, Abbruch per reader.cancel; Tests chunked und lügende Länge akzeptieren 413 oder Abbruch, nie 2xx.
- claim ignoriert Körper: claim() liest request.body nie; 1-MiB-Bridge-Test mit claim -> 413 close belegt die globale Grenze.
- Keine Logs: kein console/Logger in app-routes.ts; Test beobachtet console.error.
- Ausnahmen nicht gefangen: nur jsonBody fängt, und dort nur Parse/Formprüfung; DB-Fehler gehen als 500 durch dispatch.
Ergebnis: kein Gegenbeweis gefunden, keine Lücke zwischen Spec und Tests.
**Implementierer:** keine Gegenrede nötig.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: 408 passed, 0 failed, 0 übersprungen
Edge cases: All checked, none broken (3 LOW-Anmerkungen zu bekannten Abweichungen, kein Blocker)
Regressions: None found
Checklist: 18/18 points proven (AC-1 bis AC-17 inkl. AC-4a)

## Geprüfte Dateien

- sha256:1649a3ad4c30dc869ed56c830418c86aad8400e0575391608b7c2d3ec3aa6bc6  CLAUDE.md
- sha256:3a249d2405fa423da580233363d1871532c115ffcc0e2d9f88142e359c13fa68  docs/reference/claude-abschrift-vertrag.md
- sha256:218e6e4719a023855d5a079018bf7fa3ac5c4b51218d3546764e2e4ad870a350  server/src/app-routes.ts
- sha256:211dd1cb1edf79c95d46b8d2dfc542bed128dc7ecee9c5c821a7c08dfaad1999  server/src/main.ts
- sha256:2fafae40a315c0295b710c1a2e2a401756d31c5cc2771b1896e8bd2d934a2306  server/src/orders.ts

## Prüfbasis

- base: d225bd0447691744d11c27ffb9592fc6127f6cdb
- blob:15cf9631dbbf17ac88e51b0daba922c60e08509e  CLAUDE.md
- blob:2ad50694432a359951fcae76338c18fd7b53fcdd  docs/reference/claude-abschrift-vertrag.md
- blob:0f6823c93d691735ea4bdf3623a3d6d67fd55b17  server/src/app-routes.ts
- blob:db64ee9c137d78eca2602670485976bf0c239d92  server/src/main.ts
- blob:ef92ff156e583f8c07bd35706f24e314130f59d1  server/src/orders.ts
