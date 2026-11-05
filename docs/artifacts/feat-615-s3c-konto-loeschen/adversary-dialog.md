# Adversary Dialog — feat-615-s3c-konto-loeschen
Spec: docs/specs/feat-615-schnitt-3c1-konto-loeschen.md
Datum: 2026-11-05 08:03

## Checkliste
- [x] **AC-1:** Rundweg Löschen: Nach einer Anmeldung (AC-1 aus S3b) antwortet `POST /auth/delete` mit gültigem Bearer-Token mit 204 und ohne Body. Danach sind alle Tabellen des Kontos leer (`accounts`, `sessions`, `apple_tokens` sowie Abschrift und Aufträge des Kontos), und `resolveSession` mit dem alten Sitzungstoken ergibt `null`. Test: „auth: rundweg loeschen“.
- [x] **AC-2:** Widerruf im Rundweg: Apple bekommt genau einen Aufruf auf `/auth/revoke`, mit dem entschlüsselten Refresh-Token der Anmeldung und der beim Anmelden gespeicherten `client_id` (bei zwei konfigurierten Client-IDs die, für die der Token ausgestellt war). Der Aufruf geschieht synchron: Er ist beim Eintreffen der 204 bereits erfolgt, und zu diesem Zeitpunkt ist das Konto schon gelöscht. Es erscheint keine Logzeile. Test: „auth: loeschen widerruft einmal“.
- [x] **AC-3:** Anderes Konto unberührt: Ein zweites angemeldetes Konto behält Konto-Zeile, `apple_tokens`-Zeile, Sitzung und Daten, und seine Sitzung gilt weiter; eine zweite Sitzung desselben, gelöschten Kontos gilt nach dem Löschen nicht mehr. Test: „auth: loeschen beruehrt kein anderes konto“.
- [x] **AC-4:** Eingabe-Ablehnungen tabellengetrieben: falsche Methode (GET, PUT, DELETE) → 405 mit `Allow: POST`; fehlender Header, anderes Schema (`Basic`), leerer Wert, zwei Token → 401; unbekannter, schon beendeter und fremd erfundener Sitzungstoken → 401. Bei **jedem** dieser Fälle gilt: nichts gelöscht (alle Tabellen unverändert), kein Aufruf des gefälschten Apple-`fetch`, keine Logzeile, Antwort ohne Body. Test: „auth: loeschen abgelehnt, nichts angefasst“.
- [x] **AC-5:** Rennen: Verliert die Sitzung zwischen `resolveSession` und `deleteAccount` ihr Konto (Test reicht als `deps.pool` einen `Proxy` um den echten Pool herein, dessen `query` bei der ersten Anweisung der Löschung zuerst das Konto löscht; `AuthDeps` bekommt dafür keinen Hook), liefert `deleteAccount` `deleted: false`: Antwort 401, kein Aufruf von `/auth/revoke`, keine Logzeile. Test: „auth: loeschen rennen“.
- [x] **AC-6:** Zwei gleichzeitige Löschungen derselben Sitzung (`Promise.all`) ergeben genau eine 204 und genau eine 401, das Konto ist weg und es gibt genau einen Aufruf auf `/auth/revoke`. Test: „auth: zwei loeschungen gleichzeitig“.
- [x] **AC-7:** Widerruf scheitert nie das Löschen: Netz weg (`fetch` wirft), Apple antwortet 400 `invalid_grant`, Zeitüberschreitung (`fetch` bricht auf das Signal ab bzw. bleibt hängen, bis `revokeToken` das Limit meldet) → jeweils 204, Konto und Sitzung weg, **genau eine** Logzeile `apple revoke failed`, keine `apple revoke skipped`. Test: „auth: widerruf scheitert, konto weg“.
- [x] **AC-8:** Widerruf entfällt: Fall (a) `deps.config` fehlt, Fall (b) `client_id` des Kontos ist `null` (Zeile aus der Zeit vor Migration 003, Test setzt die Spalte vor dem Löschen auf `NULL`), Fall (c) der abgelegte Blob ist mit einem anderen `tokenKey` verschlüsselt und damit unlesbar, Fall (d) das Konto hat keine `apple_tokens`-Zeile (Test löscht sie vor dem Löschen), Fall (e) die gespeicherte `client_id` steht nicht (mehr) in `config.clientIds` (Kennung rotiert oder entfernt; Test löscht mit einer `config`, deren `clientIds` sie nicht enthält). Jeweils: 204, Konto weg, **kein** Aufruf von `/auth/revoke`, genau eine Logzeile `apple revoke skipped`. Fall (a) läuft zusätzlich mit `keys` undefiniert und belegt, dass Löschen weder `config` noch `keys` braucht. Test: „auth: widerruf entfaellt, konto weg“.
- [x] **AC-9:** Log-Schnittstelle: `AuthDeps.log` ist optional und hat den Typ `(event: string) => void`; ohne `log` laufen alle Löschfälle aus AC-7 und AC-8 ohne Fehler und ohne Ausgabe. Die gesammelten Logzeilen sind ausschließlich `apple revoke skipped` oder `apple revoke failed`, und keine enthält Refresh-Token, Sitzungstoken, Konto-ID, `sub`, `client_id` oder den Text einer Apple-Antwort (Test prüft gegen alle diese Werte der Läufe). Test: „auth: log ohne geheimnisse“.
- [x] **AC-10:** Stille bleibt: Während der Tests aus AC-1 bis AC-9 schreibt `auth.ts` weder auf `console` noch `process.stdout`/`stderr` (Test fängt beide ab, wie S3b-AC-11), und alle 401-Antworten der Löschroute sind in Status, Headern und Body gleich. `grep -nE "console|process\.(stdout|stderr)" server/src/auth.ts` hat keinen Treffer. Test: „auth: stille und einheitliche ablehnung loeschen“.
- [x] **AC-11:** Ausnahmen werden nicht gefangen: Wirft die Datenbank in `deleteAccount` (Pool-`Proxy` wie AC-5), ist die Antwort über `dispatch` 500 ohne Body, und es erscheint keine Logzeile `apple revoke failed`/`skipped`. Test: „auth: loeschen datenbankfehler“.
- [x] **AC-12:** Regression, Länge, Grenze: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, kein bestehender Testfall wird geändert oder gelöscht (alle S3b-Tests bleiben grün), `accounts.ts`, `apple-vault.ts` und `apple-client.ts` sind unverändert, jede Funktion in `auth.ts` hat höchstens 50 Zeilen, und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/auth.ts`, `server/test/auth.test.ts` und `CLAUDE.md`. Die Zeile zu `src/auth.ts` im Abschnitt `server/` von `CLAUDE.md` nennt zusätzlich `POST /auth/delete`, die Reihenfolge (Sitzung, Löschen, danach Widerruf), dass Löschen ohne Apple-Konfiguration läuft, das optionale `log` und dass nichts die Route aufruft.

## Dialog

### Runde 1
**Adversary:** Suite selbst gelaufen (adversary-test-output.txt): 214 tests, 214 pass, 0 fail, 0 skipped, Exit 0. Pruefreihenfolge in deleteAccountRoute (Code reference: server/src/auth.ts:114-125) = Spec: Methode 405 (:115), bearer 401 (:117), resolveSession 401 (:119), deleteAccount deleted=false 401 (:122), revokeAfterDelete (:123), 204 (:124). AC-1/2/3: Tests server/test/auth.test.ts:360,370,389. AC-4 :399, AC-5 :423, AC-6 :434 (deleteAccount sperrt Zeile; zweiter Aufruf deleted=false, kein Widerruf). AC-7 :444 drei Fehlerarten, je genau eine Zeile failed, revokes==1. AC-8 :466 fuenf Faelle (a)-(e), calls==0, genau eine Zeile skipped. AC-9 :487, AC-10 :509, AC-11 :536. Angriff F001-Fix: auth.ts:103 `known` verlangt config.clientIds.includes(clientId), damit wirft clientSecret (apple-client.ts:27) nie fuer eine unkonfigurierte Kennung; Token leer/null (:105) -> skipped, damit auch revokeToken-Misuse "refresh token must not be empty" (apple-client.ts:100) ausgeschlossen; decryptToken faengt alles und gibt null (apple-vault.ts:24-35). Restwege fuer eine Ausnahme nach dem Commit: (1) sign() mit ungueltigem config.privateKey oder nicht-finitem now() - loadAppleConfig validiert den Schluessel (apple.ts:36), Fehlkonfiguration, kein Laufzeitpfad; (2) deps.log wirft - Aufrufer-Vertrag, in 3c-2 logError; (3) Apple/Netz/Timeout/Body-Lesefehler: postForm/readBody liefern Grund statt zu werfen. Alle liegen ausserhalb dessen, was die Spec zusichert ("Throws only on own misuse"). Bewertung: von der Spec gedeckt, kein Finding; Hinweis fuer 3c-2: log darf nicht werfen.
**Implementierer:** Fix revokeAfterDelete wie in Spec Schnittstelle und AC-8e.

### Runde 2
**Adversary:** Regression: Diff der Testdatei gegen b66c4d9 zeigt genau eine hinzugefuegte Zeile (Fall "client_id nicht mehr konfiguriert", auth.test.ts:473); kein bestehender Testfall geaendert oder geloescht. AC-12: Diff gegen origin/main fuer accounts.ts, apple-vault.ts, apple-client.ts, main.ts leer; Dateiliste ausserhalb docs/.claude = CLAUDE.md, server/src/auth.ts, server/test/auth.test.ts (uncommittet inklusive, Status zeigt nur diese drei). Funktionslaengen in auth.ts alle <= 17 Zeilen. grep console|process.stdout|stderr in auth.ts: kein Treffer. CLAUDE.md-Zeile zu src/auth.ts nennt POST /auth/delete, Reihenfolge session/delete/revoke, laeuft ohne Apple-Config, optionales log mit den zwei Ereigniswoertern, nothing calls the route yet. Early-Agreement-Skepsis: nicht nur Tests gruen, Code je AC gelesen; einzige Beobachtung sind die Restwege (kein Finding).
**Implementierer:** keine Aenderung.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Code reference: server/src/auth.ts:114
Code reference: server/test/auth.test.ts:466

Confirmation: AC-1 Code reference: server/src/auth.ts:124 (204 ohne Body), Test auth.test.ts:360 - CONFIRMED
Confirmation: AC-2 Code reference: server/src/auth.ts:109 (ein Widerruf nach deleteAccount :120, vor 204) - CONFIRMED
Confirmation: AC-3 Code reference: server/test/auth.test.ts:389 - CONFIRMED
Confirmation: AC-4 Code reference: server/src/auth.ts:115 (405/401-Reihenfolge bis :119) - CONFIRMED
Confirmation: AC-5 Code reference: server/src/auth.ts:122 - CONFIRMED
Confirmation: AC-6 Code reference: server/test/auth.test.ts:434 - CONFIRMED
Confirmation: AC-7 Code reference: server/src/auth.ts:110 - CONFIRMED
Confirmation: AC-8 Code reference: server/src/auth.ts:103 (Faelle a-e) - CONFIRMED
Confirmation: AC-9 Code reference: server/src/auth.ts:106 (nur feste Woerter) - CONFIRMED
Confirmation: AC-10 Code reference: server/src/auth.ts:8 (kein console/stdout) - CONFIRMED
Confirmation: AC-11 Code reference: server/src/auth.ts:120 (kein try/catch) - CONFIRMED
Confirmation: AC-12 Code reference: server/test/auth.test.ts:473 (214 pass / 0 fail / 0 skipped) - CONFIRMED

## Geprüfte Dateien

- sha256:4c339694c87163de56950b57035af9d5fb6c5a3a7e9585735faff378176fba2d  server/src/auth.ts
- sha256:fb792e7cbcd84bd07b2d3cd6af019c76a83818f271676462215793576b767fff  server/test/auth.test.ts

## Prüfbasis

- base: 940f830dace12b106ac78c9648705002776ffa9a
- blob:067178707d95ca4b2de2768a1c674ba2a2c36db5  server/src/auth.ts
- blob:d3a9f7e3b0622e3bde9a229adcb0137304c28172  server/test/auth.test.ts
