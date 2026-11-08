# Adversary Dialog — feat-621-s6-betrieb
Spec: docs/specs/feat-621-schnitt-6a-tuer.md
Datum: 2026-11-08 08:25

## Checkliste
- [x] **AC-1:** Erstes Konto schließt die Tür (Zweig 2): GIVEN `accounts` ist leer und keine Liste WHEN `admit(pool, "sub-a", undefined)` läuft THEN gibt es die ID des neuen Kontos, genau eine Zeile in `accounts`; WHEN danach `admit(pool, "sub-b", undefined)` THEN `null`, weiterhin genau eine Zeile; WHEN `admit(pool, "sub-a", undefined)` nochmals THEN dieselbe ID wie zuvor, weiterhin eine Zeile. Test: server/test/accounts.test.ts „tuer: erstes konto schliesst die tuer, vorhandenes bleibt nutzbar“.
- [x] **AC-2:** Gleichzeitige Erstanmeldungen ergeben genau ein Konto: GIVEN `accounts` ist leer und keine Liste WHEN acht `admit`-Aufrufe mit acht verschiedenen `sub`s gleichzeitig laufen (`Promise.all`, aus einem Pool mit mindestens acht Verbindungen) THEN ist genau ein Ergebnis eine ID, sieben sind `null`, und `accounts` hat genau eine Zeile; WHEN dieselbe `sub` achtmal gleichzeitig kommt THEN ergeben alle dieselbe ID, eine Zeile. Test: server/test/accounts.test.ts „tuer: gleichzeitige erstanmeldungen ergeben genau ein konto“.
- [x] **AC-3:** Die Liste ist die Wahrheit (Zweig 1): GIVEN die Liste `{"sub-a"}` WHEN `admit(pool, "sub-a", liste)` läuft THEN gibt es ein Konto (auch bei leerer Tabelle); WHEN `admit(pool, "sub-x", liste)` bei leerer Tabelle THEN `null` und keine Zeile (die Liste schlägt die Regel „erstes Konto“); WHEN ein Konto zu `sub-b` schon besteht (hergestellt mit `findOrCreate`) und `admit(pool, "sub-b", liste)` läuft THEN `null` (vorhandenes Konto zählt nicht, wenn es nicht auf der Liste steht), die Zeile bleibt unberührt; WHEN die Liste `{"sub-a", "sub-b"}` ist THEN ergibt `admit(pool, "sub-b", …)` die ID des vorhandenen Kontos, ohne zweites. Test: server/test/accounts.test.ts „tuer: liste entscheidet, auch ueber vorhandene konten“.
- [x] **AC-4:** Die Variable wird streng gelesen: GIVEN `allowedSubsFromEnv` WHEN die Variable fehlt, leer oder nur Leerraum ist THEN `undefined`; WHEN sie `"a, b ,c"` ist THEN die Menge `{a, b, c}` (getrimmt); WHEN sie `"a"` ist THEN `{a}`; WHEN sie `"a,,b"`, `"a,"`, `",a"`, `" , "` oder `","` ist THEN wirft jede mit der Meldung genau `ALLOWED_APPLE_SUBS` (der Wert, auch ein Teil davon, steht nicht in der Meldung). Test: server/test/accounts.test.ts „tuer: allowedSubsFromEnv liest streng und nennt nie den wert“.
- [x] **AC-5:** Ein ungültiger Wert stoppt den Prozess vor Pool und Port: GIVEN der gestartete Prozess (`main.ts`, Muster der bestehenden Start-Tests) mit `ALLOWED_APPLE_SUBS=sub-a,,sub-geheim-4711` WHEN er startet THEN endet er mit Exit 1, seine Ausgabe enthält `allowed subs invalid: ALLOWED_APPLE_SUBS`, aber weder `sub-geheim-4711` noch `sub-a`, und er hat keinen Port geöffnet (keine „listening“-Zeile; das Muster der bestehenden Tests zu `oauth config invalid` zeigt, wie das geprüft wird). Test: server/test/main.test.ts „start: ungueltige ALLOWED_APPLE_SUBS stoppt vor pool und port, ohne den wert zu nennen“.
- [x] **AC-6:** `POST /auth/apple` weist Fremde ab: GIVEN `authRoutes` mit Fake-Apple, ohne Liste, und ein Erstkonto, das sich anmeldet WHEN danach eine zweite, fremde `sub` mit gültigem Token und Code anmeldet THEN ist die Antwort ein bares 401 (leerer Körper, `no-store`), `accounts` hat weiter genau eine Zeile, `sessions` und `apple_tokens` haben keine Zeile für die zweite `sub`, das Protokoll ist genau `["account refused"]`, und die `sub` steht in keiner Antwort und keiner Protokollzeile; WHEN dieselbe fremde `sub` in der Liste steht (`allowedSubs` mit beiden) THEN antwortet derselbe Weg 200 mit Sitzungstoken, ein zweites Konto. Das Erstkonto selbst: 200 wie bisher. Test: server/test/auth.test.ts „auth: fremde sub wird abgewiesen, kein konto, keine sitzung, kein token“.
- [x] **AC-7:** Der Web-Rückweg weist Fremde ab: GIVEN der Rückweg (`service` über `start`, Fake-Apple, `through`) ohne Liste, ein Erstkonto hat sich über den Rückweg angemeldet WHEN eine zweite, fremde `sub` (`apple.sub = "apple-sub-2"`) denselben Weg durchläuft THEN antwortet er 303 auf `finish`, die Ablage des Tickets ist `{ uid, error: "access_denied" }` mit `account_id` NULL, es gibt kein zweites Konto, keine Zeile in `apple_tokens` für die zweite `sub` (das Web-Token wird nicht abgelegt) und keinen Widerruf an Apple, das Protokoll enthält genau `account refused` (und keine Zeile mit der `sub` oder der Konto-ID), der `state` ist verbraucht; WHEN `allowedSubs` die zweite `sub` enthält THEN läuft derselbe Weg bis zum Ticket mit Konto-ID und abgelegtem Web-Token. Test: server/test/oauth-return.test.ts „rueckweg: fremde sub ergibt access_denied ohne konto und ohne token“.
- [x] **AC-8:** Kein Produktweg umgeht die Tür: GIVEN die Quelldateien in `server/src` WHEN ein Test sie liest (Dateisystem, kein `git diff`) THEN kommt der Name `findOrCreate` außer in `accounts.ts` in keiner Datei vor; GIVEN `start()` ohne `allowedSubs` mit Apple-Konfiguration WHEN über `POST /auth/apple` zwei verschiedene `sub`s anmelden THEN wird nur die erste angenommen (200), die zweite bekommt 401 und es gibt ein Konto (belegt, dass `main.ts` die Tür auch ohne Option geschlossen verdrahtet); WHEN `start()` mit `allowedSubs` beider läuft THEN werden beide angenommen (belegt, dass die Option durch `mountAuth` und `returnFor` zu den Routen kommt). Test: server/test/main.test.ts „tuer: kein aufrufer in src umgeht admit, start verdrahtet die liste“ (Dateiliste-Teil mit `readdirSync`/`readFileSync` über `src`).
- [x] **AC-9:** Gesamtlauf und Rest unverändert: GIVEN der fertige Schnitt WHEN `./server/scripts/test-local.sh` (typecheck + alle Tests) läuft THEN ist er grün und räumt auf; die bestehenden Tests, die über `authRoutes`, `appleReturn` oder `start` mehrere verschiedene `sub`s anmelden (`auth.test.ts` „app-id“-Schleife und der Löschfall, `oauth-return.test.ts` Test mit `apple-sub-2`, `main.test.ts` Löschfälle mit `member(…, .a/.b)`), reichen dafür ausdrücklich `allowedSubs` ein und bleiben sonst in Aussage und Prüfungen unverändert; es gibt keinen neuen Eintrag in `server/package.json` und keine neue Migration. Funktionslänge (jede Funktion höchstens 50 Zeilen) und Dateiliste belegt `/60-validate`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Test: Gesamtlauf `./server/scripts/test-local.sh` und CI `server.yml`.

## Dialog

### Runde 1
**Adversary:** Suite: `./server/scripts/test-local.sh` (typecheck + Tests): 380 pass, 0 fail, 0 skipped (docs/artifacts/feat-621-s6-betrieb/adversary-test-output.txt). Nachbohren bei AC-6: In server/src/auth.ts:19-20 setzen `status()` und `notAllowed()` jetzt `cache-control: no-store`. Alle Abweisungen von /auth/apple laufen durch diese beiden (503 ohne Config/Keys :85, 405 :86, 415 :87, 413 :89, 400 :91, 401 :66-77). Header je Antwort also gleich, bis auf `allow: POST` bei 405, das ist HTTP-Pflicht und verrät keine Prüfung. Die Assertion in server/test/auth.test.ts:132 belegt es für die fremde sub (401, Körper leer). Logout/Delete: 204 und 401 laufen ebenfalls durch `status()` (auth.ts:101, 139); die Tests prüfen dort nur Status, nichts Spezifiziertes bricht, `no-store` auf 204 ist harmlos und korrekt. AC-1..4: server/src/accounts.ts:21-69 (admit, admitFirst mit pg_advisory_xact_lock, allowedSubsFromEnv wirft nur den Variablennamen); Tests accounts.test.ts:255-303 grün (server/test/accounts.test.ts:255).
**Implementierer:** Keine Änderung außer auth.ts:19-20 und der Assertion.

### Runde 2
**Adversary:** Versuch, die Tür zu umgehen: grep `findOrCreate` in src: nur accounts.ts:8 (Test server/test/main.test.ts:564-569 liest `src` per readdirSync). Beide Produktaufrufer nutzen `admit`: auth.ts:70, server/src/oauth-return.ts:94; Ablehnung ohne storeRefreshToken, Protokoll nur `account refused` (oauth-return.ts:96, auth.ts:72). main.ts: `allowedSubsOrExit` (main.ts:248-254) beendet vor Pool und Port, Meldung ohne Wert; Test main.test.ts:548. Verdrahtung `mountAuth` main.ts:138 und `returnFor` main.ts:168. AC-8 Beleg für `returnFor`: server/test/main.test.ts:564-586 belegt `mountAuth` über `start()`. Der Teil `returnFor` wird in server/test/oauth-return.test.ts:560 belegt: `service` (ca. Zeile 98-107) ruft `start()` mit `auth` aus den Optionen; `withList` (:534) gibt `allowedSubs: BOTH` ohne `ret`-Überschreibung hinein, also baut `start()` den Rückweg selbst über `returnFor`. Fremde sub auf der Liste ergibt Ticket mit Konto-ID und Web-Token (:560-571), ohne Liste access_denied (:536-558). Das ist Ende-zu-Ende und stärker als ein Test in main.test.ts; trägt als Beleg. Randfälle: Liste schlägt vorhandenes Konto (admit :23); leere Liste unmöglich (allowedSubsFromEnv wirft bei leerem Eintrag, :63). Restlücke: der 503 vor migrate (server/src/main.ts:123, `gated`) und 404/500 (main.ts:78-80) tragen kein `no-store`; das ist vor-spezifiziert, betrifft nicht die Entscheidung der Tür und ist von außen nur vor dem Start sichtbar (Finding F001, LOW). Tests: server/test/accounts.test.ts, server/test/auth.test.ts, server/test/main.test.ts, server/test/oauth-return.test.ts alle in der grünen Suite.
- AC-7/AC-8 Beleg Rückweg über start(): Code reference: server/test/oauth-return.test.ts:560
**Implementierer:** F001 nicht Teil von AC-6 (dort „Antwort der fremden sub“); kein Handlungsbedarf in diesem Schnitt.

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/main.ts:123
  Description: `gated` antwortet vor Abschluss von migrate mit 503 ohne `cache-control`, daher unterscheidbar von den 503/400/401 aus auth.ts, die `no-store` tragen.
  Spec requirement: AC-6 — Abweisung einer fremden sub ist ein bares 401 mit no-store (nur dafür gefordert)
  Conflict: Keine Verletzung von AC-6; nur Hinweis auf uneinheitliche Header vor dem Start.
  Remediation: Optional `no-store` in `gated` setzen (eigener Schnitt).

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: server/src/accounts.ts:32
  Evidence: admitFirst legt nur bei leerer Tabelle an, vorhandene sub liefert ihre ID; Test accounts.test.ts:255 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/test/accounts.test.ts:269
  Evidence: Advisory Lock serialisiert acht parallele Erstanmeldungen, ein Konto.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/test/accounts.test.ts:285
  Evidence: admit prüft allowed.has vor dem Insert (accounts.ts:23), auch für vorhandene Konten.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/test/accounts.test.ts:303
  Evidence: allowedSubsFromEnv wirft genau `ALLOWED_APPLE_SUBS` (accounts.ts:63).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/test/main.test.ts:548
  Evidence: main.ts:248-254 beendet mit Exit 1 vor Pool und Port, Meldung ohne Wert; Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/auth.ts:19
  Evidence: status() und notAllowed() mit no-store; auth.ts:70-73 admit null gibt 401 und `account refused`; Assertion server/test/auth.test.ts:132 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/oauth-return.ts:94
  Evidence: admit null gibt access_denied ohne Ablage und Widerruf, Log `account refused`; Test oauth-return.test.ts:536 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/main.ts:168
  Evidence: returnFor reicht allowedSubs durch (main.ts:168), mountAuth main.ts:138; Tests main.test.ts:564 und oauth-return.test.ts:560 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/test/oauth-return.test.ts:560
  Evidence: Rückweg über start() (service, withList ohne ret): fremde sub auf der Liste ergibt Ticket mit Konto-ID und Web-Token; belegt returnFor-Verdrahtung Ende zu Ende.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/test/auth.test.ts:121
  Evidence: Gesamtlauf 380 pass, 0 fail, 0 skipped, typecheck sauber.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:d31318a60caba7d0b816f457f59771f9fb0c09f9c93413c3f479bc12a4a87e7a  server/src/accounts.ts
- sha256:29d0acf90a66976fd87a253544c7efc0900ae832cb77c54497954447a4ad7a40  server/src/auth.ts
- sha256:17907c89869980b49ec3e8876992ee982b04feb56bc3214d9adcfcd1fcb06e7c  server/src/main.ts
- sha256:5ea1a25561c5cecd73fa310e9953ca6d5228682dc61bc776c54a2aa53277c104  server/src/oauth-return.ts
- sha256:f8f7ffc6cbc4733faf3a6f85f277df4dd4e3c728173fcda7c4d43d17f5516a23  server/test/accounts.test.ts
- sha256:33a1e1b3877f4852a8828523af9c9482ab7aef3793d4ef2fade7df11d69f7d9f  server/test/auth.test.ts
- sha256:8eb8a1719d5972ba65207ba2d7b6c9a6df927db9017284f1ab1662e842a93243  server/test/main.test.ts
- sha256:de5ec43be05c8ed2a6a4f5c2106910249630b82300dd0dd7cdbf2f44b4f9d173  server/test/oauth-return.test.ts

## Prüfbasis

- base: 1a7c228bff62755a0274cb37fa0522cbd17c7041
- blob:8247f21d4a7ee70975f0352a4d39f9ae0640d4b4  server/src/accounts.ts
- blob:1f386909240c3bd0a41489858f9390306f4cb6c7  server/src/auth.ts
- blob:326ec51bbd5bf86cd66b4fe27f59c492900064cd  server/src/main.ts
- blob:63cf86dc72b0fcbcbc94eec4cf7ab807423b06b5  server/src/oauth-return.ts
- blob:d7735a6c3061c3a783e5b7ac6c510894d9e3330b  server/test/accounts.test.ts
- blob:0348360adf667095a117e1e5960275dc62a6b21c  server/test/auth.test.ts
- blob:a3aa16ab81851914b21c24be137a1f64ad199188  server/test/main.test.ts
- blob:3205f9b10842982c6cc4787782b53cb9be96739e  server/test/oauth-return.test.ts
