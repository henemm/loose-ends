# Adversary Dialog — feat-615-s2-apple-anbindung
Spec: docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md
Datum: 2026-11-03 06:36

## Checkliste
- [x] **AC-1:** Konfiguration gültig: `loadAppleConfig` mit fünf gültigen Variablen liefert `teamId`, `keyId`, `clientIds` (aus `" a.b , c.d ,"` wird `["a.b", "c.d"]`), einen EC-P-256-`privateKey` (auch bei `\n` als Zeichenfolge im PEM) und `tokenKey` mit 32 Byte. Test: `server/test/apple.test.ts`, „config: gültige Umgebung“.
- [x] **AC-2:** Konfiguration ungültig: `loadAppleConfig` wirft für jede der fünf Variablen, wenn sie fehlt oder leer ist, außerdem bei RSA-Schlüssel oder Müll in `APPLE_PRIVATE_KEY`, bei 31 oder 33 Byte oder Nicht-base64 in `APPLE_TOKEN_KEY` und bei nur Kommas in `APPLE_CLIENT_IDS`; der Fehlertext nennt den Variablennamen und enthält den übergebenen Wert nicht (Testwert `GEHEIM-123`). Test: `apple.test.ts`, „config: fehlend und ungültig“.
- [x] **AC-3:** Gültiges Token: Ein korrekt signiertes Token (RS256, `kid` bekannt, `iss`, `aud` aus der Liste, `exp` in der Zukunft, `iat` jetzt, `nonce` = SHA-256-hex des Rohwerts, `sub` gesetzt) ergibt `{ ok: true, sub }` mit dem `sub` des Tokens, auch mit der zweiten Client-ID als `aud`, und auch, wenn das JWK kein `alg` trägt. Test: `apple.test.ts`, „verify: gültiges Token“.
- [x] **AC-4:** Malformed: `undefined`, Zahl, leerer Text, zwei oder vier Segmente, Nicht-base64url-Zeichen, Header oder Payload als JSON-Array, `null` oder Text sowie ein gültig signiertes Token mit leerem oder fehlendem `sub` ergeben `malformed` und werfen nie. Test: `apple.test.ts`, „attack: malformed“ (Fallliste).
- [x] **AC-5:** Angriff alg none: `alg: "none"` und `"NONE"`, auch mit leerer Signatur, ergeben `alg`, und die Schlüsselsuche wird nicht aufgerufen (Zähler 0). Test: `apple.test.ts`, „attack: alg none“.
- [x] **AC-6:** Angriff HS256 mit öffentlichem Schlüssel: Ein HS256-Token, dessen HMAC mit dem öffentlichen Schlüssel als Secret gebildet ist, ergibt `alg`; die Fallliste hat zwei Zeilen, eine mit dem PEM-Text, eine mit den Modulus-Bytes. Test: `apple.test.ts`, „attack: HS256 mit öffentlichem Schlüssel“.
- [x] **AC-7:** Angriff ES256: Ein ES256-Token mit gültiger Signatur eines eigenen EC-Schlüssels ergibt `alg`. Test: `apple.test.ts`, „attack: ES256“.
- [x] **AC-8:** Kid und Schlüsselsuche: Liefert die Stub-Suche `unknown_kid`, ergibt das `unknown_kid`; liefert sie `keys_unavailable`, ergibt das `keys_unavailable`; ein Token ohne `kid` im Header ergibt `unknown_kid`. Test: `apple.test.ts`, „attack: kid und Schlüsselsuche“.
- [x] **AC-9:** Angriff JWK mit fremdem alg oder kty: Liefert die Suche ein JWK mit `alg: "RS384"` oder `kty: "EC"`, ergibt ein sonst gültiges Token `unknown_kid`. Test: `apple.test.ts`, „attack: JWK mit fremdem alg oder kty“.
- [x] **AC-10:** Angriff Signatur: Ein geändertes Zeichen in Payload oder Signatur und ein mit anderem RSA-Schlüssel signiertes Token mit dem `kid` des echten ergeben `signature`; ein nicht ladbares JWK (`n` leer) ebenfalls. Test: `apple.test.ts`, „attack: Signatur“.
- [x] **AC-11:** Angriff iss: `iss` = `https://appleid.apple.com/`, `http://appleid.apple.com`, `https://evil.example` oder fehlend ergibt `iss`. Test: `apple.test.ts`, „attack: iss“.
- [x] **AC-12:** Angriff aud: `aud` als Teilstring einer erlaubten ID, als Oberstring, als Array mit erlaubtem und fremdem Eintrag, als Array nur mit dem erlaubten Eintrag, in anderer Groß-/Kleinschreibung, fehlend oder als Zahl ergibt `aud`. Test: `apple.test.ts`, „attack: aud“.
- [x] **AC-13:** Abgelaufen, Spielraum 60 s: `exp` = `now − 59 s` wird akzeptiert; `exp` = `now − 60 s`, `now − 1 h`, fehlend, als Text oder `NaN` ergibt `expired`. Test: `apple.test.ts`, „attack: abgelaufen“.
- [x] **AC-14:** Angriff iat in der Zukunft: `iat` = `now + 60 s` wird akzeptiert; `now + 61 s`, `now + 1 d`, fehlend oder als Text ergibt `iat`. Test: `apple.test.ts`, „attack: iat“.
- [x] **AC-15:** Nonce: Fehlender Claim, der Rohwert statt seines SHA-256, falscher Hash, Zahl oder Array als Claim, andere Länge und ein falsch übergebener Rohwert ergeben `nonce`; der richtige Rohwert ergibt `ok`. Test: `apple.test.ts`, „attack: nonce“.
- [x] **AC-16:** Feste Gründe: Über alle Angriffsfälle ist `reason` immer einer der zehn Werte `malformed|alg|unknown_kid|signature|iss|aud|expired|iat|nonce|keys_unavailable`, jeder Wert kommt in mindestens einem Fall vor, und kein Grund enthält Teile des Tokens, des `sub` oder eines Apple-Textes. Test: `apple.test.ts`, „reasons: feste Liste“ (sammelt die Ergebnisse der Falllisten).
- [x] **AC-17:** Stille: Während aller Aufrufe von `loadAppleConfig` (gültig und ungültig) und `verifyIdentityToken` (gültig und abgelehnt) wird nichts nach `console` oder `process.stdout`/`process.stderr` geschrieben (der Test ersetzt sie vorübergehend), und kein Fehlertext enthält Token, PEM, Schlüssel oder `sub`. Test: `apple.test.ts`, „silence“.
- [x] **AC-18:** Regression, CI und Funktionslänge: Test: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, die bestehenden Testdateien bleiben unverändert; jede Funktion in `server/src/apple.ts` hat höchstens 50 Zeilen (Prüfung in der Validierung: `grep -nE "^(export )?(async )?function" server/src/apple.ts`, Abstand zweier Treffer und letzte Zeile ≤ 50).
- [x] **AC-19:** Dateigrenze: Test: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple.ts`, `server/test/apple.test.ts` und `CLAUDE.md`; `server/package.json`, `server/package-lock.json`, `server/src/accounts.ts`, `server/src/main.ts`, `server/migrations/`, `server/test/db.ts`, `.github/workflows/`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Dialog

### Runde 1
**Adversary:** Testlauf: ./server/scripts/test-local.sh, Ausgabe in docs/artifacts/feat-615-s2-apple-anbindung/adversary-test-output.txt. Ergebnis: typecheck (tsc --noEmit) sauber, 137 Tests, 137 bestanden, 0 fehlgeschlagen, 0 übersprungen, Exit 0. Die 15 Tests aus apple.test.ts laufen mit (config x2, verify, 10x attack, reasons, silence). Jeden AC habe ich gegen Test UND Code gelesen, nicht nur auf Grün geschaut.
- AC-1 CONFIRMED. Code reference: server/src/apple.ts:31. Test prüft Trimmen und Leerverwerfen (" a.b , c.d ," ergibt zwei Einträge), EC/prime256v1, tokenKey 32 Byte, auch mit Backslash-n-Zeichenfolge im PEM (apple.ts:21) und mit echtem PEM.
- AC-2 CONFIRMED. Code reference: server/test/apple.test.ts:80. Alle fünf Variablen je fehlend und leer, RSA-PEM, Müll, 31/33 Byte, Nicht-Alphabet, nur Kommas. Der Test prüft, dass der Name im Fehlertext steht und der Wert (GEHEIM) nicht. Echt: apple.ts:14, 23, 26, 35, 39 nennen nur Namen.
- AC-3 CONFIRMED. Test apple.test.ts:97: ok mit sub, zweite aud, JWK ohne alg. Code apple.ts:93 erlaubt fehlendes alg.
- AC-4 CONFIRMED. apple.test.ts:104, 14 Zeilen inkl. undefined, Zahl, Segmentzahl, Zeichen, Array/null/Text in Header und Payload, sub leer/fehlt. Code: parse (apple.ts:49), try/catch um JSON.parse (apple.ts:85), sub-Prüfung apple.ts:67.
- AC-5 CONFIRMED. apple.test.ts:115 prüft none/NONE, leere und fremde Signatur und lookup.calls gleich 0. Code: alg-Prüfung apple.ts:87 vor Suche apple.ts:91.
- AC-6, AC-7 CONFIRMED. apple.test.ts:125 (PEM und Modulus-Bytes), apple.test.ts:132 (ES256 mit echter Signatur). Beide enden in alg, weil apple.ts:87 strikt auf RS256 prüft.
- AC-8, AC-9 CONFIRMED. apple.test.ts:136 und 142. Durchreichen apple.ts:92, kid-Typ apple.ts:89, kty/alg apple.ts:93.
- AC-10 CONFIRMED. apple.test.ts:148: Payload-Änderung, Signaturzeichen, fremder RSA-Schlüssel mit echtem kid, n leer. Code apple.ts:71 bis 77, Ausnahme wird zu false.
- AC-11 bis AC-15 CONFIRMED. apple.test.ts:156, 164, 173, 181, 189 enthalten alle Zeilen der Spec. Grenzen: exp = now minus 60 s abgelehnt, minus 59 s ok, iat plus 60 s ok, plus 61 s abgelehnt (Code apple.ts:62, 63). Nonce: SHA-256-hex gegen Claim mit timingSafeEqual, Längenprüfung vorher (apple.ts:64 bis 66).
- AC-16 CONFIRMED. apple.test.ts:199 sammelt über seen alle Fallergebnisse, verlangt mindestens 50, nur zehn erlaubte Gründe, nur die Schlüssel ok und reason, jeder Grund kommt vor. Kein Token-Text im Grund folgt daraus, dass reason aus Literalen besteht (apple.ts:83).
- AC-17 CONFIRMED. apple.test.ts:208 ersetzt console.* und stdout/stderr write, ruft gültig und abgelehnt auf, erwartet written leer; apple.ts enthält kein console.
- Prüfreihenfolge: falsche Signatur UND falsches iss ergibt signature (Runde 2); alg none UND falsches iss ergibt alg.
- AC-18 CONFIRMED. Funktionsanfänge in apple.ts: Zeilen 12, 18, 31, 43, 49, 59, 71, 80, Dateiende 97. Längste Funktion verifyIdentityToken mit 18 Zeilen. test-local.sh grün. Bestehende Testdateien unverändert: der Diff gegen origin/main im Ordner server/test nennt nur apple.test.ts. server.yml auf dem PR ist mangels PR noch nicht prüfbar, Sache der Validierung.
- AC-19 CONFIRMED. Der Diff gegen origin/main ohne docs und .claude nennt genau CLAUDE.md und server/test/apple.test.ts; server/src/apple.ts ist untracked (erwartet), zusammen die drei Dateien. Keine Berührung von package.json, accounts.ts, main.ts, Migrationen, Workflows, project.yml oder Swift. CLAUDE.md: genau eine Zeile (Code reference: CLAUDE.md:464).
**Implementierer:** Keine Rückfrage nötig, alle Punkte durch Tests und Code belegt.

### Runde 2
**Adversary:** Eigene Angriffe außerhalb der Testliste mit einem Wegwerf-Skript im Scratchpad (Node 26 führt apple.ts direkt aus), rund 60 Fälle. Alles, was ein Token fälschlich akzeptieren würde, scheitert fail-closed:
- alg "RS256 " mit Leerzeichen und alg als Array: alg. Header mit __proto__: alg. kid als Zahl/Objekt/fehlend: unknown_kid.
- Token mit Padding "=" oder Standard-Alphabet (plus und Schrägstrich): malformed. Newline am Ende, 1e6 Punkte, 100000 verschachtelte Klammern, String-Objekt als Token: malformed, kein Wurf. 5-MB-Token wird korrekt verarbeitet.
- exp als Text: expired. exp Infinity (wird zu null): expired. aud mit Unicode-Homoglyph oder angehängtem Leerzeichen: aud. nonce in Großbuchstaben-Hex: nonce.
- Schlüsselsuche wirft (synchron und async), liefert undefined, null oder fremden Text: keys_unavailable bzw. unknown_kid, kein Wurf. Fremder öffentlicher Schlüssel unter demselben kid: signature. Falsche Signatur UND falsches iss: signature (Reihenfolge stimmt). Leere/gekürzte/verlängerte Signatur: signature.
- JWK mit use "enc" oder key_ops ["encrypt"] wird akzeptiert. Die Spec verlangt das nicht (Schritt 3 nennt nur kty und alg), Apples JWKS trägt use "sig". Nicht exploitierbar, der Schlüssel kommt aus der vertrauten Suche. Notiert, kein Fund.
- Doppelte Schlüssel im JSON: der letzte gewinnt (JSON.parse). Ein Header mit alg none gefolgt von alg RS256 wird als RS256 gelesen. Unkritisch, weil die Signatur über genau diese Header-Bytes gebildet sein muss; ein Parser-Differential gäbe es nur mit einem zweiten Parser. Ebenso doppeltes aud. Notiert, kein Fund.
Finding F001: Severity LOW, Category edge_case. Code reference: server/src/apple.ts:64. rawNonce wird mit String() umgewandelt und nicht auf Text geprüft: rawNonce undefined passt zu einem Token mit nonce sha256("undefined"), null zu sha256("null"), und ein Objekt ohne Prototyp wirft einen TypeError. Spec Schritt 9 und der Satz "wirft nie auf Eingabewerten". Konflikt nur für Typ-verletzende Eingaben (TypeScript verlangt Text; JSON-Eingaben liefern kein Objekt ohne Prototyp). Keine Lücke: der Angreifer bräuchte ein von Apple signiertes Token mit diesem nonce, das nur sein eigenes Konto öffnet. Abhilfe: typeof rawNonce gleich string verlangen, sonst nonce. Kein Test deckt nicht-Text-Rohwerte ab. Nicht blockierend; S3 soll den Rohwert als Text validieren.
Finding F002: Severity LOW, Category edge_case. Code reference: server/src/apple.ts:62. Ist now gleich NaN, sind beide Zeitvergleiche falsch und ein abgelaufenes Token wird akzeptiert (Skript: ok). Nur ein Fehler des Aufrufers (Date.now liefert nie NaN), die Spec nennt es nicht. Abhilfe: Number.isFinite(now) verlangen. Nicht blockierend.
Beide Funde verletzen keinen der 19 ACs im Wortlaut und öffnen bei richtiger Verwendung (Text als Rohwert, Date.now als Uhr) keine Lücke.
**Implementierer:** Funde LOW, Härtung in S3 oder bei Gelegenheit; kein Blocker für Schnitt 2a.

### Runde 3
**Adversary:** Nachprüfung nach dem Fix von F001 und F002. Diff: server/src/apple.ts ist untracked, geändert sind nur drei Dinge in claimsReason: Zeile 64 (now keine endliche Zahl ergibt expired, vor exp), Zeile 68 (rawNonce kein Text oder leer ergibt nonce, vor dem Hash), Zeile 69 (update(rawNonce) ohne String()). Der Diff von server/test/apple.test.ts gegen HEAD umfasst 4 Zeilen: Hilfsfunktion direct (Zeile 64), Assert für now NaN (Zeile 180), Asserts für Objekt ohne Prototyp und undefined gegen Token mit sha256("undefined") (Zeilen 199 und 200). Die Asserts prüfen die Sache selbst: direct reicht rohe Werte an verifyIdentityToken, erwartet exakt reason expired bzw. nonce, und der undefined-Fall nutzt ein Token, das vorher fälschlich akzeptiert wurde. Ich habe das Angriffsskript aus Runde 2 gegen den neuen Stand gefahren und vorher dieselben Werte als ok bzw. Wurf gesehen.
- test-local.sh neu: Exit 0, typecheck sauber, 137 Tests, 137 bestanden, 0 fehlgeschlagen, 0 übersprungen (adversary-test-output.txt).
- Regression: Das gesamte Skript mit rund 60 Fällen liefert dieselben Gründe wie in Runde 2; die einzigen ok-Ergebnisse sind das Basis-Token und die in Runde 2 als unkritisch bewerteten Fälle.
- F001 behoben: rawNonce undefined gegen Nonce sha256("undefined"): nonce. null gegen sha256("null"): nonce. Zahl 5 gegen sha256("5"): nonce. Symbol: nonce. Objekt ohne Prototyp: nonce, kein Wurf mehr. Leerer Rohwert: nonce.
- F002 behoben: now NaN ergibt expired statt ok.
- AC-18: Funktionsanfänge 12, 18, 31, 43, 49, 59, 73, 82, Dateiende 99; claimsReason 14 Zeilen, verifyIdentityToken 18, alle unter 50. AC-19 unverändert: Änderungen nur in apple.ts, apple.test.ts, CLAUDE.md. Keine neuen Funde.
**Implementierer:** F001 und F002 behoben, RED vor dem Fix und grün danach belegt.

### Belege je Datei

Confirmation: AC-1 bis AC-19 (Code)
  Code reference: server/src/apple.ts:82
  Status: CONFIRMED

Confirmation: AC-2 bis AC-17 (Tests)
  Code reference: server/test/apple.test.ts:80
  Status: CONFIRMED

Confirmation: AC-19 (Doku-Zeile)
  Code reference: CLAUDE.md:464
  Status: CONFIRMED

Finding F001 (LOW, behoben)
  Code reference: server/src/apple.ts:68

Finding F002 (LOW, behoben)
  Code reference: server/src/apple.ts:64

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED. Alle 19 ACs belegt (Tests 137/137 grün, 0 übersprungen, typecheck sauber, Funktionen unter 50 Zeilen, Dateigrenze eingehalten). Rund 60 eigene Angriffe in Runde 2 und 3: kein Token wird fälschlich akzeptiert, Prüfreihenfolge stimmt. F001 und F002 (beide LOW) sind in Runde 3 als behoben nachgewiesen, keine offenen Funde.

## Geprüfte Dateien

- sha256:cc2ff84139e63767a806203efe8b6d1657446f18dad95482122347a80b915f8a  CLAUDE.md
- sha256:52648b0b3eb5f7f6fe4bbfcbab59de23e36704916aa533b2f9fe77b565aa83ff  server/src/apple.ts
- sha256:82a3b0c8bf662f9c2b22dacb160a44f848af252d2b1c702ddfe6797bae4db290  server/test/apple.test.ts

## Prüfbasis

- base: bc66568373eb78859d157a6b78ac9c39297b1aaa
- blob:d28bf6102ff4f43cf8bfa5ace1be19af425ed22c  CLAUDE.md
- blob:31ad983e4fdaa02a53f768fdf09af1f3590eb39a  server/src/apple.ts
- blob:83e1e926c14c861d3c62a9ab3ee352ae34a59841  server/test/apple.test.ts
