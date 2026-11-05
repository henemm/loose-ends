# Adversary Dialog — feat-615-s3c-konto-loeschen
Spec: docs/specs/feat-615-schnitt-3c1-konto-loeschen.md
Datum: 2026-11-05 07:09

## Checkliste
- [x] **AC-1:** Rundweg Löschen: Nach einer Anmeldung (AC-1 aus S3b) antwortet `POST /auth/delete` mit gültigem Bearer-Token mit 204 und ohne Body. Danach sind alle Tabellen des Kontos leer (`accounts`, `sessions`, `apple_tokens` sowie Abschrift und Aufträge des Kontos), und `resolveSession` mit dem alten Sitzungstoken ergibt `null`. Test: „auth: rundweg loeschen“.
- [x] **AC-2:** Widerruf im Rundweg: Apple bekommt genau einen Aufruf auf `/auth/revoke`, mit dem entschlüsselten Refresh-Token der Anmeldung und der beim Anmelden gespeicherten `client_id` (bei zwei konfigurierten Client-IDs die, für die der Token ausgestellt war). Der Aufruf geschieht synchron: Er ist beim Eintreffen der 204 bereits erfolgt, und zu diesem Zeitpunkt ist das Konto schon gelöscht. Es erscheint keine Logzeile. Test: „auth: loeschen widerruft einmal“.
- [x] **AC-3:** Anderes Konto unberührt: Ein zweites angemeldetes Konto behält Konto-Zeile, `apple_tokens`-Zeile, Sitzung und Daten, und seine Sitzung gilt weiter; eine zweite Sitzung desselben, gelöschten Kontos gilt nach dem Löschen nicht mehr. Test: „auth: loeschen beruehrt kein anderes konto“.
- [x] **AC-4:** Eingabe-Ablehnungen tabellengetrieben: falsche Methode (GET, PUT, DELETE) → 405 mit `Allow: POST`; fehlender Header, anderes Schema (`Basic`), leerer Wert, zwei Token → 401; unbekannter, schon beendeter und fremd erfundener Sitzungstoken → 401. Bei **jedem** dieser Fälle gilt: nichts gelöscht (alle Tabellen unverändert), kein Aufruf des gefälschten Apple-`fetch`, keine Logzeile, Antwort ohne Body. Test: „auth: loeschen abgelehnt, nichts angefasst“.
- [x] **AC-5:** Rennen: Verliert die Sitzung zwischen `resolveSession` und `deleteAccount` ihr Konto (Test reicht als `deps.pool` einen `Proxy` um den echten Pool herein, dessen `query` bei der ersten Anweisung der Löschung zuerst das Konto löscht; `AuthDeps` bekommt dafür keinen Hook), liefert `deleteAccount` `deleted: false`: Antwort 401, kein Aufruf von `/auth/revoke`, keine Logzeile. Test: „auth: loeschen rennen“.
- [x] **AC-6:** Zwei gleichzeitige Löschungen derselben Sitzung (`Promise.all`) ergeben genau eine 204 und genau eine 401, das Konto ist weg und es gibt genau einen Aufruf auf `/auth/revoke`. Test: „auth: zwei loeschungen gleichzeitig“.
- [x] **AC-7:** Widerruf scheitert nie das Löschen: Netz weg (`fetch` wirft), Apple antwortet 400 `invalid_grant`, Zeitüberschreitung (`fetch` bricht auf das Signal ab bzw. bleibt hängen, bis `revokeToken` das Limit meldet) → jeweils 204, Konto und Sitzung weg, **genau eine** Logzeile `apple revoke failed`, keine `apple revoke skipped`. Test: „auth: widerruf scheitert, konto weg“.
- [x] **AC-8:** Widerruf entfällt: Fall (a) `deps.config` fehlt, Fall (b) `client_id` des Kontos ist `null` (Zeile aus der Zeit vor Migration 003, Test setzt die Spalte vor dem Löschen auf `NULL`), Fall (c) der abgelegte Blob ist mit einem anderen `tokenKey` verschlüsselt und damit unlesbar, Fall (d) das Konto hat keine `apple_tokens`-Zeile (Test löscht sie vor dem Löschen). Jeweils: 204, Konto weg, **kein** Aufruf von `/auth/revoke`, genau eine Logzeile `apple revoke skipped`. Fall (a) läuft zusätzlich mit `keys` undefiniert und belegt, dass Löschen weder `config` noch `keys` braucht. Test: „auth: widerruf entfaellt, konto weg“.
- [x] **AC-9:** Log-Schnittstelle: `AuthDeps.log` ist optional und hat den Typ `(event: string) => void`; ohne `log` laufen alle Löschfälle aus AC-7 und AC-8 ohne Fehler und ohne Ausgabe. Die gesammelten Logzeilen sind ausschließlich `apple revoke skipped` oder `apple revoke failed`, und keine enthält Refresh-Token, Sitzungstoken, Konto-ID, `sub`, `client_id` oder den Text einer Apple-Antwort (Test prüft gegen alle diese Werte der Läufe). Test: „auth: log ohne geheimnisse“.
- [x] **AC-10:** Stille bleibt: Während der Tests aus AC-1 bis AC-9 schreibt `auth.ts` weder auf `console` noch `process.stdout`/`stderr` (Test fängt beide ab, wie S3b-AC-11), und alle 401-Antworten der Löschroute sind in Status, Headern und Body gleich. `grep -nE "console|process\.(stdout|stderr)" server/src/auth.ts` hat keinen Treffer. Test: „auth: stille und einheitliche ablehnung loeschen“.
- [x] **AC-11:** Ausnahmen werden nicht gefangen: Wirft die Datenbank in `deleteAccount` (Pool-`Proxy` wie AC-5), ist die Antwort über `dispatch` 500 ohne Body, und es erscheint keine Logzeile `apple revoke failed`/`skipped`. Test: „auth: loeschen datenbankfehler“.
- [ ] **AC-12:** Regression, Länge, Grenze: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` auf dem PR ist grün, kein bestehender Testfall wird geändert oder gelöscht (alle S3b-Tests bleiben grün), `accounts.ts`, `apple-vault.ts` und `apple-client.ts` sind unverändert, jede Funktion in `auth.ts` hat höchstens 50 Zeilen, und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/auth.ts`, `server/test/auth.test.ts` und `CLAUDE.md`. Die Zeile zu `src/auth.ts` im Abschnitt `server/` von `CLAUDE.md` nennt zusätzlich `POST /auth/delete`, die Reihenfolge (Sitzung, Löschen, danach Widerruf), dass Löschen ohne Apple-Konfiguration läuft, das optionale `log` und dass nichts die Route aufruft.

## Dialog

### Runde 1
**Adversary:** Testlauf `./server/scripts/test-local.sh` (Ausgabe: adversary-test-output.txt): typecheck ok, 214 pass, 0 fail, 0 skipped; zweiter Lauf identisch (kein Flackern bei AC-6). Alle elf Löschtests grün.
Code reference: server/src/auth.ts:98 (revokeAfterDelete), server/src/auth.ts:111 (deleteAccountRoute), server/src/auth.ts:128 (Route /auth/delete)
Code reference: server/test/auth.test.ts:360 (Rundweg), server/test/auth.test.ts:423 (Rennen), server/test/auth.test.ts:535 (DB-Fehler)
Prüfreihenfolge der Spec (405, Bearer, Session, Löschen, 401 bei deleted=false, Widerruf, 204) stimmt mit auth.ts:111-122 überein. Widerruf nach COMMIT (accounts.ts:60), der Test belegt "Konto beim Widerruf schon weg" über Zählung im fetch-Fake. Logzeilen nur die zwei festen Wörter; grep console/process.stdout|stderr in auth.ts: kein Treffer; Funktionen höchstens 17 Zeilen. accounts.ts, apple-vault.ts, apple-client.ts, main.ts: Diff gegen origin/main leer. Dateiliste außerhalb docs/.claude: genau auth.ts, auth.test.ts, CLAUDE.md. CLAUDE.md-Zeile nennt /auth/delete, Reihenfolge, ohne Apple-Konfiguration, optionales log, "nothing calls the route yet".
Test-Prüfung statt Behauptung: AC-4 prüft je Zeile Status, leeren Body, Allow, 0 fetch-Aufrufe, keine Logzeile, unveränderte Tabellen; AC-8 deckt vier Fälle ab, (a) mit keys undefined; AC-9 prüft gegen Token, Code, Konto-ID, Sitzungstoken, sub, client_id; AC-11 läuft über echtes start()/dispatch. Abweichung ohne Folge: der Proxy hakt `connect` statt `query` ein (deleteAccount nutzt pool.connect, accounts.ts:44), semantisch gleichwertig. Der Test-Helfer `rig` wurde erweitert (urls/forms/signals); kein Testfall geändert oder gelöscht.
Angriff: Was, wenn `revokeToken` wirft? Es ruft `clientSecret` (apple-client.ts:26), das bei einer gespeicherten `client_id`, die nicht (mehr) in `config.clientIds` steht, wirft ("client id is not configured"), ebenso bei leerem Token (apple-client.ts:100). revokeAfterDelete (auth.ts:98-108) fängt das nicht; das Konto ist da schon committet, die Antwort wird über dispatch zu 500. Das bricht die Spec-Zusage, der Widerruf könne nie die Antwort ändern. Kein Test deckt es ab (AC-8 kennt nur client_id NULL).
**Implementierer:** (nicht anwesend)

### Runde 2
**Adversary:** Befund nachgeprüft: auth.ts:98-122 hat kein try/catch; die Spec lässt Ausnahmen nur für die Datenbank (AC-11) durchschlagen. Antwort wäre 500, obwohl das Konto weg ist; Wiederholen ergibt 401. Praxisfall: Client-ID wird in APPLE_* rotiert/entfernt, danach löscht ein alter Nutzer sein Konto. Übrige Punkte gegengeprüft: AC-5 401 ohne Widerruf, AC-6 genau 204+401 und ein Widerruf, zweimal grün. Timeout-Fall dauert ~5 s (echte Frist).
AC-12, Teil "server.yml auf dem PR ist grün": kein PR vorhanden, nicht belegbar; erst nach dem Push zu prüfen. Alles andere aus AC-12 ist belegt.
Code reference: server/src/apple-client.ts:27
**Implementierer:** (nicht anwesend)

### Findings
Finding:
  ID: F001
  Severity: HIGH
  Category: edge_case
  Code reference: server/src/auth.ts:105
  Description: revokeAfterDelete ruft revokeToken ohne Schutz auf; revokeToken wirft über clientSecret (apple-client.ts:27), wenn die gespeicherte client_id nicht in config.clientIds steht, und bei leerem entschlüsselten Token (apple-client.ts:100).
  Spec requirement: Schnittstelle Schritt 5 / AC-7 / Risiken — der Widerruf kann nie die Antwort ändern, Löschen scheitert nie an Apple.
  Conflict: Nach dem COMMIT der Löschung führt die Ausnahme zu 500 ohne Body statt 204 und ohne Logzeile "apple revoke failed"; Konto ist weg, der Nutzer sieht einen Fehler. Kein Test deckt es ab.
  Remediation: Vor dem Widerruf `config.clientIds.includes(clientId)` prüfen und sonst wie "skipped" behandeln, oder den Aufruf in try/catch fassen und `apple revoke failed` loggen; Testfall (client_id nicht konfiguriert) ergänzen. Spec-Nachbesserung nötig.

Confirmation:
  AC: AC-1
  Code reference: server/src/auth.ts:111
  Evidence: "auth: rundweg loeschen" grün, 204, leerer Body, sechs Tabellen leer, resolveSession null.
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: server/test/auth.test.ts:370
  Evidence: Ein Aufruf auf REVOKE mit REFRESH und IDS[1], Konto beim Widerruf schon 0, keine Logzeile.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: server/test/auth.test.ts:389
  Evidence: zweites Konto unberührt, zweite Sitzung des gelöschten ungültig.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: server/test/auth.test.ts:399
  Evidence: Ablehnungstabelle, jeweils 0 fetch, keine Logzeile, Tabellen gleich.
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: server/test/auth.test.ts:423
  Evidence: 401, kein Widerruf, keine Logzeile.
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: server/src/accounts.ts:48
  Evidence: FOR UPDATE; Test liefert [204,401], ein Widerruf.
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: server/test/auth.test.ts:486
  Evidence: nur feste Wörter, keine Geheimnisse, auch ohne log fehlerfrei.
  Status: CONFIRMED
Confirmation:
  AC: AC-10
  Code reference: server/test/auth.test.ts:508
  Evidence: nichts auf console/stdout/stderr, 401er identisch, grep leer.
  Status: CONFIRMED
Confirmation:
  AC: AC-11
  Code reference: server/test/auth.test.ts:535
  Evidence: 500 ohne Body über echtes start(), keine Logzeile.
  Status: CONFIRMED

AC-7 und AC-8 sind für die getesteten Fälle bewiesen (auth.test.ts:444, :466), durch F001 aber in ihrer Aussage unterlaufen. AC-12 offen (server.yml ohne PR nicht belegbar).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: BROKEN

F001 (HIGH): Ausnahme aus revokeToken nach dem Commit führt zu 500 statt 204.

## Geprüfte Dateien

- sha256:45cb67488d92f17b7c62c2ef4c5c625b6fbe93259066b50dcfe28f8b597f00d3  server/src/accounts.ts
- sha256:13bd279c1de9d24bd6a623f8ebae1a77e5f71034b95a4eaa616df52025869d95  server/src/apple-client.ts
- sha256:7a984132d43ebf16581fd40e4723d7605dbd18a0df96ec0d57be1cbad9f2ead6  server/src/auth.ts
- sha256:1fc7bfadc3a9699946340dd7941edce452477f1b1c3ffd2ef8e92fd5a2859597  server/test/auth.test.ts

## Prüfbasis

- base: 940f830dace12b106ac78c9648705002776ffa9a
- blob:e2f423e6d7b0846a9350da6d5014f2369e2d2c80  server/src/accounts.ts
- blob:527ce0c6bdcd067c60f30b703d4db2ce8d855ffe  server/src/apple-client.ts
- blob:103e6515e595eeebc99f0107f1925c321bab6849  server/src/auth.ts
- blob:3474e5cfe3330e26a671af37b60ca4b03c1c05cf  server/test/auth.test.ts
