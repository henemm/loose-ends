# Adversary Dialog — feat-621-s4b-2-rueckweg
Spec: docs/specs/feat-621-schnitt-4b2a-rueckweg.md
Datum: 2026-11-06 16:50

## Checkliste
- [x] **AC-1:** Erfolg bis zur 303: GIVEN ein Hinweg mit gespeichertem `state` und ein `fakeApple`, das den Code gegen ein gültiges `id_token` (Web-ID als `aud`, Aussteller Apple, rohe Nonce als SHA-256-Hex, `sub` „apple-sub-1“) einlöst WHEN POST mit `state` und `code` THEN Status 303, `location` ist genau `https://loose-ends.test/oauth/interaction/<uid>/finish?ticket=<ticket>` (die `uid` der Interaktion, Ticket ≥ 43 Zeichen base64url), `cache-control: no-store`, `referrer-policy: no-referrer`, leerer Körper; genau ein Konto mit `apple_sub = apple-sub-1` existiert; der Aufruf an den Token-Endpunkt trägt `client_id = com.henning.looseends.web`, `redirect_uri = https://loose-ends.test/oauth/apple/return`, `grant_type = authorization_code` und den Code. Test: „rueckweg: erfolg ergibt 303 auf finish mit ticket und legt konto an“.
- [x] **AC-2:** Ticket gehasht, gebunden, kurzlebig, einmalig: GIVEN das Ticket aus AC-1 WHEN die Zeile in `oauth_records` (Modell `AppleTicket`) gelesen wird THEN steht dort `id_hash` = SHA-256 des Tickets (das Ticket selbst in keiner Spalte als Klartext), `uid` = die der Interaktion, `account_id` = das Konto aus AC-1, `payload` enthält genau `uid` und `accountId` (nichts sonst, kein Token, kein `sub`), `expires_at` liegt ≤ 60 s hinter der (injizierten) Jetztzeit; `new PgAdapter(pool, "AppleTicket", now).find(ticket)` liefert den Payload, das erste `consume` gelingt, das zweite wirft, ein `find` nach Ablauf (Uhr um 61 s vorgestellt) liefert nichts. Zwei vollständige Durchläufe ergeben verschiedene Tickets. Test: „rueckweg: ticket gehasht, gebunden, 60 sekunden, einmalig“.
- [x] **AC-3:** Zweites Einlösen desselben `state` scheitert: GIVEN der erfolgreiche POST aus AC-1 WHEN derselbe Körper erneut gesendet wird THEN 400, Körper genau `bad request`, kein zweites Ticket, kein weiterer Aufruf an Apple (Zähler am `fakeApple`), kein weiteres Konto. Test: „rueckweg: replay desselben state wird abgelehnt“.
- [x] **AC-4:** Unbekanntes, fremdes oder abgelaufenes `state` scheitert: GIVEN (a) ein nie ausgegebenes `state`, (b) ein `state` als Ticket-Kennung bzw. aus einem anderen Modell (z. B. eine echte Ticket-Kennung als `state`), (c) ein `state`, dessen Zeile abgelaufen ist (Uhr hinter den Ablauf vorgestellt) WHEN POST mit gültigem Code THEN jeweils 400 `bad request`, kein Ticket, kein Konto, kein Aufruf an Apple. Test: „rueckweg: unbekanntes fremdes oder abgelaufenes state wird abgelehnt“.
- [x] **AC-5:** Übergröße scheitert zählend: GIVEN ein Körper mit 16 KiB + 1 Byte, einmal mit `Content-Length` und einmal ohne (chunked, ohne Längenangabe) WHEN POST THEN 413, leerer Körper, `connection: close`, `cache-control: no-store`; ein Körper von genau 16 KiB wird gelesen (und dann wegen fehlender Felder mit 400 abgelehnt); der `state` einer gültigen Zeile bleibt in beiden Fällen unverbraucht (ein folgender gültiger POST gelingt). Test: „rueckweg: uebergroesse wird beim lesen gezaehlt abgelehnt“.
- [x] **AC-6:** Methode und Inhaltstyp: GIVEN GET, PUT und DELETE auf `/oauth/apple/return` WHEN gesendet THEN jeweils 405 mit `allow: POST`, leerer Körper; GIVEN POST mit `application/json`, mit `text/plain` und ohne `content-type` THEN jeweils 415, leer; `application/x-www-form-urlencoded; charset=utf-8` wird angenommen. In keinem Fall wird `state` verbraucht oder Apple aufgerufen. Test: „rueckweg: falsche methode und falscher inhaltstyp“.
- [x] **AC-7:** Fehlende und doppelte Felder: GIVEN Körper (a) ohne `state`, (b) mit zwei `state`, (c) mit leerem `state`, (d) mit zwei `code`, (e) mit zwei `error`, (f) mit `code` und `error` zugleich, (g) weder `code` noch `error`, (h) leerer Körper WHEN POST THEN jeweils 400 `bad request`, `cache-control: no-store`, kein Ticket, kein Aufruf an Apple, der gültige `state` bleibt unverbraucht. Test: „rueckweg: fehlende und doppelte felder ergeben 400“.
- [x] **AC-8:** Das Feld `user` wird ignoriert: GIVEN ein gültiger POST aus AC-1 mit zusätzlichem Feld `user` (einmal gültiges JSON mit Namen und E-Mail, einmal Müll, einmal doppelt) WHEN gesendet THEN dasselbe Ergebnis wie AC-1 (303, ein Konto); weder Name noch E-Mail noch der `user`-Inhalt stehen in einer Zeile von `oauth_records`, in `accounts` oder im Protokoll. Test: „rueckweg: feld user wird ignoriert“.
- [x] **AC-9:** Apple-Fehler ergibt `access_denied`: GIVEN ein POST mit `state` und `error=user_cancelled_authorize` (und einmal `error=beliebiger_text`) ohne `code` WHEN gesendet THEN 303 wie in AC-1, das Ticket trägt `{ uid, error: "access_denied" }` (kein `accountId`, `account_id` leer), es gab keinen Aufruf an Apple und es entstand kein Konto; der Fehlertext von Apple steht nirgends in der Datenbank. Test: „rueckweg: apple-fehler ergibt ticket access_denied“.
- [x] **AC-10:** Abgelehnte Einlösung ergibt `access_denied`: GIVEN `fakeApple` antwortet auf die Einlösung mit (a) 400 `invalid_grant`, (b) 400 `invalid_client`, (c) 500, (d) 200 ohne `refresh_token`, (e) 200 mit `id_token` für die App-ID als `aud` statt der Web-ID WHEN POST THEN jeweils 303, Ticket `{ uid, error: "access_denied" }`, kein Konto; von außen sind die Fälle nicht zu unterscheiden (gleiche Statusangabe, gleiche Header, gleicher Ticket-Inhalt). Test: „rueckweg: abgelehnte einloesung ergibt access_denied“.
- [x] **AC-11:** Ungültiges Identity-Token ergibt `access_denied`: GIVEN eine erfolgreiche Einlösung, deren `id_token` (a) eine falsche Nonce trägt (Nonce eines anderen Versuchs), (b) für eine fremde `aud` ausgestellt ist, (c) mit fremdem Schlüssel signiert ist, (d) abgelaufen ist, (e) einen anderen Algorithmus als RS256 nutzt, (f) keine `sub` trägt, (g) einen anderen Aussteller trägt WHEN POST THEN jeweils 303 mit Ticket `{ uid, error: "access_denied" }`, kein Konto, kein `apple_tokens`-Eintrag; (a) und (b) sind getrennte Fälle und beide belegt, weil `redeemCode` nur `aud` und Aussteller liest, die Nonce aber nur `verifyIdentityToken` prüft. Test: „rueckweg: ungueltiges identity-token ergibt access_denied“.
- [x] **AC-12:** Apple nicht erreichbar ergibt `temporarily_unavailable` ohne 5xx: GIVEN (a) der Token-Endpunkt wirft (Netzfehler), (b) antwortet nicht in der Zeit (Zeitüberschreitung über den Abbruch des eingereichten `fetch`), (c) Apples Schlüsselsatz ist nicht erreichbar (`keys_unavailable`), während die Einlösung gelingt WHEN POST THEN jeweils 303 (kein 5xx), Ticket `{ uid, error: "temporarily_unavailable" }`, kein Konto. Test: „rueckweg: apple nicht erreichbar ergibt temporarily_unavailable“.
- [x] **AC-13:** Konto zwischendurch gelöscht: GIVEN die Ablage des Tickets scheitert am Fremdschlüssel, weil das Konto nach `findOrCreate` und vor dem Schreiben gelöscht wird (Aufbau im Test: Pool-Ersatz, dessen `query` beim Schreiben des Modells `AppleTicket` zuvor `deleteAccount` ausführt, wie der Ersatz in AC-8 des Hinweg-Tests) WHEN POST THEN 400 `bad request` ohne `location`, kein Ticket in der Datenbank, Protokoll nur `oauth return store failed`, die Konto-ID und der Fehlertext des Fremdschlüssels stehen weder in Antwort noch Protokoll. Zusätzlich: GIVEN ein gültiges Ticket und danach `deleteAccount` WHEN die Zeile gelesen wird THEN ist das Ticket mit entfernt. Test: „rueckweg: geloeschtes konto ergibt 400 und raeumt tickets mit ab“.
- [x] **AC-14:** Web-Token wird weder gespeichert noch widerrufen: GIVEN AC-1 WHEN geprüft wird THEN gibt es keine Zeile in `apple_tokens`, `fakeApple` sah nie einen Aufruf an `/auth/revoke`, und das Refresh-Token aus der Einlösung steht in keiner Zeile von `oauth_records`, keiner Antwort und keiner Protokollzeile. Test: „rueckweg: web-token wird nicht gespeichert und nicht widerrufen“.
- [x] **AC-15:** Ohne Rückweg bleibt die 404 des Ausstellers: GIVEN (a) `start()` mit OAuth-Schlüsseln, aber ohne `auth`, (b) mit `auth: { config }` ohne `webClientId`, (c) mit gesetzter `oauth.interaction` und Web-ID WHEN POST `/oauth/apple/return` (leer und mit gültigem Körper) THEN jeweils die übliche 404 des Ausstellers ohne Wert, es entsteht nichts in der Datenbank, Apple wird nicht aufgerufen. Zusätzlich: Pfade `/oauth/apple/return/x`, `/oauth/apple/returnx` und `/oauth/apple` werden auch mit Rückweg nicht vom Handler beantwortet (404 des Ausstellers). Test: „rueckweg: ohne rueckweg und bei fremden pfaden 404 des ausstellers“.
- [x] **AC-16:** `finish` bleibt unbehandelt: GIVEN die 303 aus AC-1 WHEN GET der `location` (mit dem Interaktions-Cookie des Hinweg-Browsers und ohne) THEN antwortet der Dienst weiterhin mit der festen 400 des Hinweges (die uid im Pfad wäre `<uid>/finish`, ungleich der Cookie-uid), schließt die Interaktion nicht ab, legt keine Sitzung und keinen Code an und verbraucht das Ticket nicht. Test: „rueckweg: finish ist noch nicht behandelt und verbraucht nichts“.
- [x] **AC-17:** Keine Werte im Protokoll: GIVEN alle Fälle aus AC-1 bis AC-16 WHEN `console.log`, `console.error`, `process.stdout` und `process.stderr` im Test mitgeschnitten werden THEN besteht jede Zeile aus genau einem der festen Ereignisnamen `oauth return refused`, `oauth return store failed`, `oauth interaction refused`, `oauth interaction store failed` (Hinweg) oder einem bestehenden festen Ereignis aus `main.ts`; keine Zeile enthält `state`, `code`, `sub`, Ticket, `uid`, Token, Web-ID, Apple-Adresse, Konto-ID oder Fehlertext. Der Mitschnitt erlaubt keine Zeile außerhalb dieser Liste. Test: „rueckweg: protokoll nur feste ereignisse ohne werte“.
- [x] **AC-18:** Fehlerfenster: Apple-Ausfall füllt es nicht: GIVEN ein Dienst mit injizierter Uhr, die Anmeldungen und Hinwege laufen vor dem Test, danach wird die Uhr um mehr als 5 min vorgestellt (die Hinweg-Anfragen liegen nicht mehr im Fenster) WHEN ≥ 25 Rückweg-Anfragen in 5 min beantwortet werden, alle mit Apple nicht erreichbar (303 `temporarily_unavailable`) oder 4xx THEN antwortet `/health` mit 200; Gegenprobe: GIVEN ≥ 25 Rückweg-Anfragen in 5 min, die mit 500 enden (Ersatz-Handler über die Option `appleReturn`, der wirft; Koa antwortet 500) THEN antwortet `/health` mit 503 (5xx zählt). Test: „rueckweg: fehlerfenster zaehlt 5xx und nicht die 303“.
- [x] **AC-19:** Eine JWKS-Instanz je `start()`, benutzt vom Rückweg: GIVEN `start()` mit Apple-Konfiguration samt Web-ID und OAuth-Schlüsseln, `auth.fetch` zählt Abrufe von Apples Schlüsselsatz WHEN ein Rückweg mit gültigem Token läuft und danach `/auth/apple` mit einem Identity-Token derselben `kid` befragt wird THEN lädt der Schlüsselsatz insgesamt genau einmal (der Rückweg benutzt `keys`, der App-Weg trifft den Zwischenspeicher; ein zweiter Rückweg lädt nicht erneut). Belegt durch den Abruf-Zähler, nicht durch Einblick in interne Felder (Nachschärfung 3 aus `/60-validate` S4b-1). Test: „rueckweg: eine jwks-instanz je start fuer rueckweg und app-weg“.
- [x] **AC-20:** `redeemCode` gibt das Token weiter: GIVEN Apples Antwort mit `id_token` WHEN `redeemCode` einlöst THEN enthält das Ergebnis `idToken` gleich dem `id_token` der Antwort; in allen Fehlerfällen bleibt `{ ok: false, reason }` unverändert. Test: die angepassten Erwartungen in `apple-client.test.ts` (Fälle „erfolg …“ und „web aud web“) und AC-1/AC-11.
- [x] **AC-21:** Gesamtlauf: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf; `oauth-interaction.test.ts`, `oauth-provider.test.ts`, `main.test.ts`, `auth.test.ts` laufen unverändert grün; es gibt keinen neuen Eintrag in `server/package.json` und keine neue Migration. Dateiliste und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main -- server`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Nachweis: `./server/scripts/test-local.sh`, CI `server.yml`, `/60-validate`.

## Dialog

### Runde 1
**Adversary:** Testlauf ./server/scripts/test-local.sh (Ausgabe in docs/artifacts/feat-621-s4b-2-rueckweg/adversary-test-output.txt): typecheck sauber, 324 tests, 324 pass, 0 fail, 0 skipped, 0 todo. Die 19 Tests "rueckweg: ..." tragen exakt die Namen der Spec. Pro AC geprüft, dass der Test den Weg auslöst und nicht nur das Ergebnis setzt (Hinweg läuft real über CIMD-Client, /oauth/auth, begin; Apple ist nur fakeApple).
Confirmation: AC-1 CONFIRMED. Code reference: server/src/oauth-return.ts:115 (location aus publicUrl-Origin, encodeURIComponent(uid), Ticket 32 Byte base64url = 43 Zeichen), :116 (303, no-store, no-referrer, leerer Körper); Test server/test/oauth-return.test.ts:210.
Confirmation: AC-2 CONFIRMED. server/src/oauth-return.ts:110 (PgAdapter AppleTicket, upsert TTL 60 = Konstante :20); Hash, account_id, uid kommen aus der Spalten-Abbildung des Adapters (server/src/oauth-adapter.ts:38-46); Test :225.
Confirmation: AC-3 CONFIRMED. :68-78 find, dann atomares consume (UPDATE ... consumed_at IS NULL, oauth-adapter.ts:75); Test :250 zählt Apple-Aufrufe.
Confirmation: AC-4 CONFIRMED. Modellname AppleLogin im Schlüssel (model, id_hash), fremde Ticket-Kennung findet nichts; Test :261.
Confirmation: AC-5 CONFIRMED. :35-50 zählt Bytes beim Lesen, :132 413 mit connection close vor parseFields, also vor jedem state-Zugriff; Test :280.
Confirmation: AC-6 CONFIRMED. :122-124 Methode vor Typ vor Lesen; Typ wird am Semikolon geteilt und kleingeschrieben; Test :298.
Confirmation: AC-7 CONFIRMED. :53-65 parseFields (Mehrfach und leer ergeben null, genau eines von code/error); Test :318.
Confirmation: AC-8 CONFIRMED. user wird nirgends gelesen (:53-65 liest nur state, code, error); Test :333.
Confirmation: AC-9 CONFIRMED. :84 error ohne Apple-Aufruf; Test :347.
Confirmation: AC-10 CONFIRMED. :87 jede Ablehnung ausser unavailable ergibt access_denied, einheitlich; Test :370.
Confirmation: AC-11 CONFIRMED. :89-90 verifyIdentityToken mit roher Nonce und audiences [webClientId]; Nonce (a) und aud (b) getrennte Fälle; Test :390.
Confirmation: AC-12 CONFIRMED. :87 und :90 ergeben temporarily_unavailable, 303 statt 5xx; Test :412.
Confirmation: AC-13 CONFIRMED. :108-114 fängt FK-Fehler, loggt nur die feste Zeile, 400 ohne location; Test :428 (Pool-Ersatz löscht Konto vor dem INSERT AppleTicket).
Confirmation: AC-14 CONFIRMED. :88 Kommentar, refreshToken wird nirgends gelesen, kein storeRefreshToken, kein revokeToken im Import (:1-7); Test :454.
Confirmation: AC-15 CONFIRMED. server/src/oauth-provider.ts:104-107 (ctx.path exakt, nur mit Handler gesetzt); server/src/main.ts:160-168 returnFor (gleiche Bedingungen wie interactionFor, interaction gesetzt ergibt undefined); Test :465 mit drei Aufbauten und fremden Pfaden.
Confirmation: AC-16 CONFIRMED. Kein finish-Handler, Hinweg liefert feste 400; Test :493 prüft Zeilenzahl, Modelle Session/AuthorizationCode/Grant = 0, consumed_at des Tickets null.
Confirmation: AC-17 CONFIRMED. Nur deps.log(REFUSED|STORE_FAILED) in server/src/oauth-return.ts:100,104,112,129,135; Test :539. Der Mitschnitt-Regex wurde gegenüber dem RED-Stand um listening|migrated erweitert (server/test/oauth-return.test.ts:144); beides sind feste Ereignisse aus server/src/main.ts:226,229, die Spec erlaubt bestehende feste Ereignisse aus main.ts. Berechtigt.
Confirmation: AC-18 CONFIRMED. Test :508 hat Vorlauf mit vorgestellter Uhr (20 Hinwege, dann +301 s), 20 mal 303 und 5 mal 400 ergeben /health 200; 25 mal 500 ergibt 503.
Confirmation: AC-19 CONFIRMED. server/src/main.ts:176-180 gibt dieselbe jwks-Instanz an interactionFor und returnFor; Test :525 zählt keyCalls = 1 vor und nach dem App-Weg und nach dem zweiten Rückweg.
Confirmation: AC-20 CONFIRMED. server/src/apple-client.ts:82-84 (idToken wird zurückgegeben, fehlendes id_token ergibt malformed_response). server/test/apple-client.test.ts trägt die idToken-Erwartungen schon aus dem RED-Commit (daher keine Änderung im Arbeitsbaum), Zeile 42.
Confirmation: AC-21 CONFIRMED mit Vorbehalt F004. Gesamtlauf grün, keine Änderung in server/package.json oder server/migrations. Funktionslängen (awk-Zählung): empty 3, badRequest 3, readLimited 16, parseFields 13, redeemState 11, outcome 12, finishReturn 23, appleReturn 21, returnFor 9; alle unter 50. CLAUDE.md:477 trägt die Doku-Zeile.
**Implementierer:** (Adversary-Lauf, keine Antwort nötig; die Belege stehen oben.)

Bewertung des gestrichenen Tests "hinweg: rueckweg noch nicht behandelt" (server/test/oauth-interaction.test.ts:350, 14 Zeilen gestrichen): Er erwartete 404 für POST /oauth/apple/return mit auth.config withWeb und OAuth-Schlüsseln, also genau unter den Bedingungen, unter denen returnFor (server/src/main.ts:160) den Handler jetzt baut. Der Test ist mit AC-1 logisch unvereinbar und durfte nicht bleiben. Verlorene Abdeckung: (1) 404 ohne Wert im Körper, nichts in der DB, kein Konto gilt weiter für die Aufbauten ohne Rückweg und ist in server/test/oauth-return.test.ts:465 (AC-15 a/b/c) abgedeckt; (2) die Schlusszeile Hinweg liefert 303 ist durch die übrigen Hinweg-Tests und through/begin in oauth-return.test.ts abgedeckt. Kein Verlust. Der Wortlaut von AC-21 (unverändert grün) wird formal verletzt, ist aber nicht vermeidbar (F004).

### Runde 2
**Adversary:** Bohrungen, die kein Test deckt, durch Code-Lesen (Arbeitsbaum unverändert):
1. Bindung: uid und Nonce kommen allein aus der AppleLogin-Zeile des state (server/src/oauth-return.ts:77, :109); kein Eingabefeld beeinflusst sie. Ticket-Payload enthält uid; die Cookie-Bindung folgt in S4b-2b (Spec-Risiko). Kein Befund.
2. Replay-Wettlauf zweier paralleler POSTs mit gleichem state: beide find gelingen, consume ist ein einzelnes UPDATE ... WHERE consumed_at IS NULL (server/src/oauth-adapter.ts:75), nur eines liefert eine Zeile, das zweite wirft und führt über redeemState zu null, also 400 vor jedem Apple-Aufruf (Konto-Anlage erst in outcome). Kein Doppelkonto, kein zweites Ticket. Kein Befund (ein eigener Test dafür fehlt; Atomarität belegt der S2-Adaptertest).
3. Konto-Anlage bei ungültigem Token: findOrCreate steht erst nach verifyIdentityToken ok (server/src/oauth-return.ts:89-91). Ungültig ergibt kein Konto. Kein Befund.
4. Werte in Logs und Antworten: deps.log bekommt nur zwei Konstanten, alle catch-Blöcke verwerfen das Fehlerobjekt (:99, :111, :128). Antworten sind feste Texte, einzige Ausnahme die location der 303. Kein Befund.
5. Ablauf des Tickets: fest 60 s (TICKET_TTL, :20), nicht aus Eingabe; Uhr ist deps.now (injizierbar). Das Ticket kann länger leben als die Interaktion (bis 600 s), bewirkt aber ohne finish nichts. Kein Befund.
6. Body-Limit bei gestückeltem Lesen: Größe wird je Chunk kumuliert, ab Überschreitung wird nichts mehr gesammelt (:41-45). Der Rest wird per resume() verworfen, ohne Lese-Timeout (wie in auth.ts); die Spec sagt, der Rest werde nicht weitergelesen. F002 LOW.
7. Feldnamen und Content-Type: URLSearchParams ist groß-/kleinschreibungsabhängig, State ergibt 400; Content-Type wird kleingeschrieben verglichen. Kein Befund.
8. Weiche: ctx.path ist ohne Query-String, genau gleich RETURN_PATH, jede Methode, nur mit Handler (server/src/oauth-provider.ts:104). Trailing-Slash und Unterpfade fallen auf die 404 des Ausstellers durch (Test AC-15). Wirft der Handler, geht der Fehler an Koa (500, zählt im Fehlerfenster, AC-18). Kein Befund.
9. Fehlerklassifikation: redeemState fängt jeden Fehler von consume und gibt null zurück (:72-76); ein Datenbankfehler im consume wird als oauth return refused statt oauth return store failed protokolliert, die Spec (Schritt 5) verlangt für Datenbankfehler store failed. Sicherheitlich folgenlos (400 in beiden Fällen). F001 LOW.
10. JWKS-Teilung: returnFor und interactionFor erhalten dieselbe Instanz jwks (server/src/main.ts:176-180). Kein Befund.
11. Dateirahmen: Spec erlaubt 6 Dateien; Arbeitsbaum zeigt 6 Dateien plus CLAUDE.md (Doku, vorgesehen). oauth-return.ts hat 140 Zeilen (Spec schätzte 85), das Testfile 542 Zeilen (Schätzung 215). Die Spec verlangt Meldung, wenn die Schätzung über 380 LoC wächst; das Gesamtvolumen liegt bei ca. 720. F003 LOW (Prozess).
12. Mutationsproben in Wegwerfkopie nicht nötig: die Tests prüfen Verhalten (Zähler am fakeApple, DB-Zeilen), nicht nur Existenz.
**Implementierer:** (Adversary-Lauf, keine Antwort nötig.)

Befunde:
Finding: ID F001 Severity LOW Category: spec_violation Code reference: server/src/oauth-return.ts:72 Description: catch um consume verschluckt auch Datenbankfehler und gibt null zurück. Spec requirement: Ablauf Schritt 5 (Datenbankfehler ergibt oauth return store failed). Conflict: Protokollname falsch, Antwort identisch. Remediation: nur den Fall bereits verbraucht von Verbindungsfehlern trennen.
Finding: ID F002 Severity LOW Category: edge_case Code reference: server/src/oauth-return.ts:42 Description: Nach Überschreiten des Limits wird der Rest per resume() leer gelesen, ohne Zeitgrenze. Spec requirement: Schritt 3, Rest wird nicht weitergelesen. Conflict: Ein langsamer Client hält die Verbindung offen; auth.ts verhält sich ähnlich. Remediation: req.destroy() nach der 413-Antwort oder Socket-Timeout.
Finding: ID F003 Severity LOW Category: anti_pattern Code reference: server/test/oauth-return.test.ts:1 Description: Umfang weit über der Schätzung (Code 140 statt 85 Zeilen, Tests 542 statt 215). Spec requirement: Estimated Changes (Meldung ab 380 LoC). Conflict: Prozess, nicht Verhalten. Remediation: im /60-validate benennen.
Finding: ID F004 Severity LOW Category: spec_violation Code reference: server/test/oauth-interaction.test.ts:350 Description: Der Test hinweg: rueckweg noch nicht behandelt wurde gestrichen. Spec requirement: AC-21 (oauth-interaction.test.ts läuft unverändert grün). Conflict: Wortlaut verletzt, aber der Test widerspricht AC-1 logisch; Abdeckung durch AC-15 ersetzt. Remediation: Streichung im Spec-Changelog festhalten.
Weitere geprüfte Dateien: server/src/apple-client.ts:82, server/src/main.ts:160, server/src/oauth-provider.ts:104.

### Code-Belege je Datei
Code reference: server/src/oauth-return.ts:115
Code reference: server/src/oauth-provider.ts:104
Code reference: server/src/main.ts:160
Code reference: server/src/apple-client.ts:82
Code reference: server/test/oauth-return.test.ts:210
Code reference: server/test/oauth-interaction.test.ts:350
Code reference: server/test/apple-client.test.ts:42
Code reference: CLAUDE.md:477

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

324 von 324 Tests grün, 0 übersprungen; alle 21 ACs belegt; vier LOW-Befunde (F001-F004), keiner blockiert.

## Geprüfte Dateien

- sha256:7555bd0d0c60079fb662cdd69f212159b2502806e1480b317522104b44c3a711  CLAUDE.md
- sha256:dbda185a2f67ad22150e423c8892be9abe599927aeed9f2dc4ba96ad8987ccce  server/src/apple-client.ts
- sha256:eadcf8a3b0c94ed5e93f222dd291bf147eab81e70cb7ddc60f690614e6b5ec20  server/src/main.ts
- sha256:a44502bed21b35764f775987cba751f6a37f1df5022fd91c43e5eb65bd58ad2c  server/src/oauth-provider.ts
- sha256:2f81dda8489deb037930074af9494cc86f4af0efd95be01c3f9270f25eb3fe9e  server/src/oauth-return.ts
- sha256:d01c767c578e089d030466b91b2b93589fa6cf3048e38768a8d9b885e3f09320  server/test/apple-client.test.ts
- sha256:b869be4f7e455759061dc80555d7209bbe4746063ebc6b7445b426a1d75b050c  server/test/oauth-interaction.test.ts
- sha256:e53691816df16f838000c3669e28becd93a86d4b02ac49a6ac7f73210d24a184  server/test/oauth-return.test.ts

## Prüfbasis

- base: f867cfee909049fe29e203c2a5cfc9e4cbde95fa
- blob:398a100c16e82b8d2f140853ee16d1b6bd4dd6ae  CLAUDE.md
- blob:e50f9c5433bcceaa662059eaea9f7f02557ae5f6  server/src/apple-client.ts
- blob:6fb58f57b523a47db3da07a956367c1b8291b983  server/src/main.ts
- blob:65d989b2db7e008b80cc9d9d8720c153dd7b2fc1  server/src/oauth-provider.ts
- blob:a2dd3203cb947d42351e48e6b2a44e826fb7977d  server/src/oauth-return.ts
- blob:7f76d995ee79b3eef63b5f53a92a4652b991c0a2  server/test/apple-client.test.ts
- blob:f217312df921421025914fe8ed5c97cbf609390a  server/test/oauth-interaction.test.ts
- blob:f70b8e55fef3f2e9622ba2c8d6acfda6cd63aade  server/test/oauth-return.test.ts
