# Adversary Dialog — feat-615-s3b-anmelden-abmelden
Spec: docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md
Datum: 2026-11-04 12:47

## Checkliste
- [x] **AC-1:** Rundweg Anmelden: Mit gültigem, selbst signiertem Identity-Token (Nonce passt), von der gefälschten Apple-Antwort eingelöstem Code und gleichem `sub` antwortet `POST /auth/apple` mit 200 und `{ sessionToken }` (Text, nicht leer, `Cache-Control: no-store`). Danach gilt: `resolveSession(sessionToken)` ergibt das Konto zum `sub`; `deleteAccount` auf dieses Konto liefert den entschlüsselbaren Refresh-Token der Apple-Antwort und als `clientId` die geprüfte `aud` (bei zwei konfigurierten Client-IDs die zweite, wenn der Token für die zweite ausgestellt war). Test: „auth: rundweg anmelden“.
- [x] **AC-2:** Zweite Anmeldung desselben `sub`: gleiches Konto, neue Sitzung, abgelegter Schlüssel und `client_id` ersetzt; es bleibt eine Zeile in `apple_tokens` und eine Zeile in `accounts`. Test: „auth: zweite anmeldung ersetzt schluessel“.
- [x] **AC-3:** Eingabe-Ablehnungen tabellengetrieben: falsche Methode (GET, PUT, DELETE) 405; `text/plain`, fehlender Content-Type 415; Body 16 KiB + 1 Byte (mit und ohne passenden `Content-Length`) 413; Body kein JSON, JSON-Array, `null`, Feld fehlt, leer, Zahl, Objekt je Feld 400. Bei **jedem** dieser Fälle gilt: kein Aufruf des gefälschten Apple-`fetch`, keine Zeile in `accounts`, `sessions`, `apple_tokens`. Test: „auth: eingabe abgelehnt, nichts angefasst“.
- [x] **AC-4:** Identity-Token-Ablehnungen: abgelaufener, falsch signierter, falsches `aud`, falsche Nonce, `alg: none`, kaputt aufgebauter Token ergeben 401 **ohne Body und ohne Text, der den Grund verrät**; es wird **kein** Code eingelöst (`fetch` nicht aufgerufen) und nichts abgelegt. `keys` meldet `keys_unavailable` → 503, ebenfalls ohne Einlösen. Test: „auth: identity-token abgelehnt“.
- [x] **AC-5:** Code-Ablehnungen: Apple antwortet `invalid_grant`, `invalid_client`, anderer Fehler, kaputter Body → 401; Netz- oder Zeitfehler (`unavailable`) → 503; in allen Fällen wurde der Code **genau einmal** eingelöst, keine Zeile in `accounts`, `sessions`, `apple_tokens`. Test: „auth: einloesen scheitert, nichts abgelegt“.
- [x] **AC-6:** `sub`-Abweichung: liefert die Einlösung ein anderes `sub` als der Identity-Token, ist die Antwort 401, der Code wurde eingelöst, nichts abgelegt, keine Sitzung. Test: „auth: sub weicht ab“.
- [x] **AC-7:** Keine verwaiste Sitzung: Wird das Konto zwischen `findOrCreate` und `storeRefreshToken` gelöscht (Test reicht als `deps.pool` einen `Proxy` um den echten Pool herein, dessen `query` bei der ersten Anweisung auf `apple_tokens` zuerst das Konto löscht bzw. in der zweiten Variante einen Fehler wirft; `AuthDeps` bekommt dafür keinen Hook) und liefert `storeRefreshToken` damit `false`, ist die Antwort 401 und es existiert keine Sitzung; wirft das Ablegen (Datenbankfehler), ist die Antwort 500 über `dispatch` und es existiert ebenfalls keine Sitzung. Test: „auth: createSession zuletzt“.
- [x] **AC-8:** Fehlt `config` oder `keys` in `AuthDeps`, antwortet `/auth/apple` 503 vor jeder Eingabeprüfung außer der Routenwahl, `/auth/logout` funktioniert weiter (204 mit gültigem Bearer-Token). Test: „auth: ohne apple-konfiguration“.
- [x] **AC-9:** Abmelden: gültiger Bearer-Token → 204 und genau diese Sitzung ist beendet (`resolveSession` danach `null`), eine zweite Sitzung desselben Kontos und die eines anderen Kontos gelten weiter; unbekannter, schon beendeter und fremder Token → 204 ohne Wirkung auf andere; fehlender Header, anderes Schema (`Basic`), leerer Wert, zwei Token → 401; falsche Methode → 405. Test: „auth: abmelden“ (Fallliste).
- [x] **AC-10:** `bearerToken`: tabellengetrieben für `Bearer abc`, `bearer abc`, `BEARER abc` (→ `abc`), fehlend, `Basic abc`, `Bearer`, `Bearer ` , `Bearer a b`, `Bearer  abc` mit zwei Leerzeichen (→ `null`). Test: „auth: bearerToken“.
- [x] **AC-11:** Stille und Einheitlichkeit: Während der Tests aus AC-1 bis AC-9 schreibt `auth.ts` weder auf `console` noch `process.stdout`/`stderr` (Test fängt beide ab), und alle 401-Antworten sind in Status, Headern und Body gleich. `grep -nE "console|process\.(stdout|stderr)" server/src/auth.ts` hat keinen Treffer. Test: „auth: stille und einheitliche ablehnung“.
- [x] **AC-12:** Regression, Länge, Grenze: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` auf dem PR ist grün, kein bestehender Testfall wird geändert oder gelöscht, jede Funktion in `auth.ts` hat höchstens 50 Zeilen, und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/auth.ts`, `server/test/auth.test.ts` und `CLAUDE.md`. Die Zeile zu `src/auth.ts` im Abschnitt `server/` von `CLAUDE.md` nennt beide Routen, die Reihenfolge, „createSession zuletzt“ und dass nichts sie aufruft.

## Dialog

### Runde 1
**Adversary:** Suite selbst gefahren: `./server/scripts/test-local.sh` Exit 0, 203 Tests, 0 fail, 0 skipped (Output: adversary-test-output.txt). Quellcode gelesen (server/src/auth.ts:1-101) und gegen die Prüfreihenfolge der Spec gelegt: 503 (Z.76) vor 405 (77) vor 415 (78) vor 413 (79-80) vor 400 (81-82) vor verify (60) vor redeemCode (62) vor sub (64) vor findOrCreate/encrypt/store (65-68) vor createSession (69). Reihenfolge stimmt exakt. Bearer-Regex Z.19 lehnt leer, zwei Token, doppeltes Leerzeichen ab. Alle Ablehnungen gehen über `status()` (Z.14), also ohne Body, ohne Grundheader; kein console in auth.ts (Suche ohne Treffer). Funktionslängen (awk): 4, 4, 17, 9, 13, 11, 7, 6 Zeilen, alle unter 50.
**Implementierer:** (Code unverändert; Befunde siehe Runde 2)

### Runde 2
**Adversary:** Wegwerf-Tests (wieder gelöscht) gegen den echten Code: Content-Type `application/json; charset=utf-8`, `Application/JSON`, ` application/json ;charset=UTF-8` ergeben 200; `application/jsonx`, `-seq`, `text/json`, `jsonp` ergeben 415. Gestückelter Stream (1000-Byte-Chunks, ohne Content-Length): 16 KiB+1 ergibt 413, genau 16 KiB ergibt 400 (nicht 413), 10 MB ergibt 413 ohne Einlösen. Mehrbyte-Zeichen (8200 mal ä = 16400 Byte) ergibt 413: Zählung in Bytes. Mutationen an auth.ts (jeweils zurückgesetzt, Vergleich mit Sicherung identisch): M1 createSession vor Ablage ergibt rot; M2 sub-Vergleich entfernt ergibt rot; M3 Logout ohne Token gibt 204 ergibt rot; M5 keys_unavailable als 401 ergibt rot; M6 Content-Type-Prüfung entfernt ergibt rot. M4 Grenze `size >= BODY_LIMIT` (genau 16 KiB abgelehnt) bleibt GRÜN: kein Test belegt, dass genau 16 KiB noch durchgehen.
**Implementierer:** n/a

Befund F001 (LOW, Testlücke, keine Spec-Verletzung): server/test/auth.test.ts:111-112 testet nur 16 KiB + 1, nicht die Grenze 16 KiB selbst; Mutation M4 überlebt. Der Code (auth.ts:38) ist korrekt. Ein positiver Test für Content-Type mit Parameter fehlt ebenfalls; Code verhält sich korrekt (Wegwerf-Test).

AC-12 Teilprüfung: Diff gegen origin/main nennt CLAUDE.md, server/test/auth.test.ts plus docs-Dateien; auth.ts ist noch ungetrackt, die erwarteten drei Dateien sind vorhanden. Kein bestehender Testfall geändert (Diff zum Vorgänger nur Hinzufügungen). CLAUDE.md-Zeile nennt beide Routen, Reihenfolge, "createSession last", "nothing calls them yet". NACHGELAGERT, NICHT ERFÜLLT: `server.yml` grün auf dem PR (erst nach PR prüfbar).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Bestätigungen

Confirmation:
  AC: AC-1
  Code reference: server/src/auth.ts:60
  Evidence: 200 mit sessionToken, no-store, aud an storeRefreshToken; Test rundweg grün
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/auth.ts:65
  Evidence: findOrCreate plus Upsert; Test grün
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/auth.ts:76
  Evidence: Reihenfolge und Bytezählung (Z.37-38), Wegwerf-Tests gestückelt und Mehrbyte
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/auth.ts:61
  Evidence: bare 401/503 vor redeemCode
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/src/auth.ts:63
  Evidence: genau ein Einlösen, 401/503
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/auth.ts:64
  Evidence: Mutation M2 wird vom Test gefangen
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/auth.ts:68
  Evidence: Mutation M1 wird vom Test gefangen
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/auth.ts:76
  Evidence: 503 vor allem, logout ohne config
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/auth.ts:91
  Evidence: endSession nur mit diesem Token; M3 wird gefangen
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/src/auth.ts:19
  Evidence: Tabellentest grün
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: server/src/auth.ts:14
  Evidence: Suche leer, Stille-Test grün, 401 identisch
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: server/src/auth.ts:96
  Evidence: Suite grün, Funktionen kurz, Dateiliste ok; server.yml nachgelagert
  Status: CONFIRMED

Confirmation:
  AC: Dateiabdeckung
  Code reference: server/test/auth.test.ts:111
  Evidence: Testdatei geprüft, Lücke F001
  Status: CONFIRMED

## Verdict

VERDICT: VERIFIED
Tests: 203 passed, 0 failed, 0 übersprungen
Edge cases: geprüft, keine Spec-Verletzung; F001 (LOW) Testlücke Grenze 16 KiB
Regressions: keine
Checklist: 12/12 (AC-12 ohne server.yml, nachgelagert)

## Geprüfte Dateien

- sha256:93db693f9197df76f52c6d2f270c15fbc9570e6f38bfb2723f2d1287cb18e2d2  server/src/auth.ts
- sha256:f50b934f41325cd5bf9745903e469e1fa64208c72cfde3b4a2892228594fef5d  server/test/auth.test.ts

## Prüfbasis

- base: 0ab9c80c61969de4fa72b4766181d880d4ffc76a
- blob:bfe8745b6624ac05c8bbc38664362b43006c0cb4  server/src/auth.ts
- blob:b8014dad565b9c8321ef70fec27c8b8bc8789ee9  server/test/auth.test.ts

## Geprüfte Dateien

- sha256:93db693f9197df76f52c6d2f270c15fbc9570e6f38bfb2723f2d1287cb18e2d2  server/src/auth.ts
- sha256:f50b934f41325cd5bf9745903e469e1fa64208c72cfde3b4a2892228594fef5d  server/test/auth.test.ts

## Prüfbasis

- base: 0ab9c80c61969de4fa72b4766181d880d4ffc76a
- blob:bfe8745b6624ac05c8bbc38664362b43006c0cb4  server/src/auth.ts
- blob:b8014dad565b9c8321ef70fec27c8b8bc8789ee9  server/test/auth.test.ts
