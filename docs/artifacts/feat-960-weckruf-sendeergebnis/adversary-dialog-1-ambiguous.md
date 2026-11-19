# Adversary Dialog — feat-960-weckruf-sendeergebnis
Spec: docs/specs/feat-960-weckruf-sendeergebnis.md
Datum: 2026-11-19 21:24

## Checkliste
- [x] **AC-1:** GIVEN Apple antwortet 2xx WHEN `wake` für ein Konto mit Geräten läuft THEN schreibt der Waker genau eine Zeile `apns wake devices=N` und je Gerät genau eine Zeile `apns sent STATUS ENV` mit `id=`/`unique=` nur für vorhandene, kanonische UUIDs (Tests 1, 2).
- [x] **AC-2:** GIVEN `apns-id` oder `apns-unique-id` ist keine einzelne kanonische UUID WHEN `sendHttp2` die Header liest THEN fehlt der Schlüssel in `ApnsResponse`, und der Wert erscheint nie im Log (Tests 3, 9).
- [x] **AC-3:** GIVEN Apple antwortet mit Fehlerstatus, Löschstatus oder gar nicht WHEN `wake` läuft THEN lautet die Zeile `apns send failed STATUS ENV`, `apns token dropped STATUS ENV` bzw. `apns send failed error ENV`, ohne Freitext (Tests 4, 5, 7).
- [x] **AC-4:** GIVEN ein Konto ohne Gerät WHEN `wake` läuft THEN steht genau `apns wake devices=0` im Log und es wird nichts gesendet (Test 6).
- [x] **AC-5:** GIVEN beliebige Sendeausgänge WHEN alle Logzeilen gesammelt werden THEN passt jede auf den Regex des Abschnitts „Logformat“ und enthält weder Token, Konto-Kennung, JWT, Body, `reason`-Freitext noch Fehlertext (Test 8).
- [x] **AC-6:** GIVEN die Änderung WHEN die bestehenden Tests zu Anfrage (Kopfzeilen, Priorität 5, Payload), JWT-Cache, Wiederholversuch, Löschregel und „wake wirft nie“ laufen THEN sind sie grün; Sendeweg, Payload, Priorität, Wiederholversuch und Löschregel sind in `apns.ts` unverändert (Test 10, Diff-Durchsicht).
- [x] **AC-7:** GIVEN der Stand WHEN `./server/scripts/test-local.sh` läuft THEN sind `npm run typecheck` und `npm test` grün.

## Dialog

### Runde 1
**Adversary:** Beweise je AC eingefordert und selbst geprueft. Testlauf `./server/scripts/test-local.sh` (adversary-test-output.txt): typecheck gruen, 485 Tests, 484 bestanden, 1 rot, 0 uebersprungen. Alle 13 apns-Tests gruen.
- AC-1: Code reference: server/src/apns.ts:139 (`apns wake devices=N` genau einmal nach listTokens) und server/src/apns.ts:126 (`apns sent` + describe). Test: server/test/apns.test.ts:157 (5 Geraete, 6 Zeilen, id/unique je nach Vorhandensein). CONFIRMED.
- AC-2: Code reference: server/src/apns.ts:76 (`apnsIds`: nur string + UUID-Regex mit ^...$, Schluessel fehlen sonst) und server/src/apns.ts:60 (sendHttp2 setzt ids). Test: server/test/apns.test.ts:168 (Array, Leerzeichen, Klammern, 42, leer). describe (apns.ts:84) prueft die IDs vor dem Schreiben erneut. CONFIRMED.
- AC-3: Code reference: server/src/apns.ts:127-131. Status/ENV aus Antwort, kein reason im Text. Tests server/test/apns.test.ts:128, :146, :200. CONFIRMED.
- AC-4: server/src/apns.ts:139 loggt devices=0, Schleife leer, nichts gesendet; Test apns.test.ts:178 (leeres Konto: Log ["apns wake devices=0"], keine Sendeaufrufe). CONFIRMED.
- AC-5: Test server/test/apns.test.ts:200 prueft jede Zeile gegen LINE, sucht Konto/Token/GEHEIM/reason-Woerter, console leer. Der Code bildet Zeilen nur aus Konstanten, Status, Umgebungs-Enum, UUIDs, Zaehler. CONFIRMED.
- AC-6: Diff von apns.ts gegen HEAD: Anfrage, Header, Prioritaet, Payload, JWT, Retry-Bedingung und DROP unveraendert; nur Header-Lesen, Variable `outcome`, Logaufrufe geaendert. Tests 93/119/128/146 gruen. CONFIRMED.
- AC-7: siehe Runde 2.
**Implementierer:** Vorbefund laut Auftrag: ein roter migrate-Test, auch auf origin/main rot, Issue #963.

### Runde 2
**Adversary:** Nachgebohrt.
- log-Callback wirft: apns.ts:105 faengt im Wrapper; Test apns.test.ts:178 Fall "log". OK.
- dropToken wirft nach Antwort: Code reference server/src/apns.ts:128-131 landet im catch und loggt `apns send failed error ENV` statt `token dropped`; formatkonform, aber ungenau. Nur LOW, kein Spec-Verstoss.
- Wiederholung nach ExpiredProviderToken: apns.ts:123-125 ueberschreibt `response`, outcome kommt nach dem Retry, genau eine Zeile; Test apns.test.ts:200 (403 dann 200 mit apnsId) erwartet `apns sent 200 sandbox id=A`. OK.
- Gross-/Kleinschreibung UUID: Regex akzeptiert beide, Wert unveraendert (apns.ts:76). Header-Array: abgelehnt (Test :168). OK.
- Keine Geheimnisse im Log: siehe AC-5.
- AC-7: Voller Lauf: 1 Test rot (migrate AC-3 "after a failed run the lock is free"). Isoliert (nur test/migrate.test.ts, frische Wegwerf-DB, adversary-migrate-isolated.txt): 14 von 14 bestanden. Der Test beruehrt apns.ts nicht; Baseline auf origin/main ebenfalls rot (main-baseline-output.txt, green-note.md); Ursache geteilte DB + datenbankweites Advisory-Lock (#963). Der Wortlaut "npm test gruen" ist lokal dennoch nicht erfuellt; die Server-CI muss den Beleg liefern. Daher AMBIGUOUS.
**Implementierer:** keine weiteren Einwaende.

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: server/test/apns.test.ts:157
  Description: Die apns-Tests sind gruen, aber `npm test` insgesamt ist lokal rot (migrate.test.ts AC-3, 484/485). Isoliert gruen (14/14), auf origin/main ebenfalls rot; Ursache nicht #960 (Issue #963).
  Spec requirement: AC-7 - typecheck und npm test gruen
  Conflict: Wortlaut verlangt vollen gruenen Lauf; lokal nicht erreicht, durch Vorbestand verursacht, nicht durch die Aenderung.
  Remediation: Server-CI des PR als Beleg abwarten oder #963 beheben.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apns.ts:128
  Description: Wirft dropToken nach einer Loeschstatus-Antwort, steht `apns send failed error ENV` statt `token dropped`.
  Spec requirement: AC-3 - Zeilen je Ausgang
  Conflict: Formatkonform, leakt nichts, nennt aber den Apple-Status nicht.
  Remediation: Optional; kein Blocker.

Confirmation:
  AC: AC-1
  Code reference: server/src/apns.ts:126
  Evidence: sent-Zeile mit describe; Test server/test/apns.test.ts:157 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/apns.ts:76
  Evidence: apnsIds nur kanonische UUID als Einzelstring; Test apns.test.ts:168.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/apns.ts:127
  Evidence: failed/dropped/error-Zeilen ohne Freitext; Tests apns.test.ts:128,146,200.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/apns.ts:139
  Evidence: devices=0, nichts gesendet; Test apns.test.ts:178.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/test/apns.test.ts:200
  Evidence: LINE-Regex je Zeile, keine Geheimnisse, console leer.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/apns.ts:122
  Evidence: Diff gegen HEAD zeigt nur Logging und Header-Lesen; bestehende Tests gruen.
  Status: CONFIRMED

### Runde 2
**Adversary:**
**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review):
  F001: AC-7 wortgetreu lokal nicht erfuellt (1 roter Vorbestands-Test migrate AC-3, isoliert 14/14 gruen, auf main ebenfalls rot, #963), Ursache nicht #960.

Proven points: 6/7 (AC-7 haengt an Server-CI)
Tests: 484 passed, 1 failed, 0 übersprungen
Recommendation: Server-CI des PR muss gruen sein, dann ist AC-7 belegt; sonst #963 zuerst.

## Geprüfte Dateien

- sha256:344cf0bea7c1b96bec48c3b5143a4c596b30590a00cad5363d3a37eacaf71026  server/src/apns.ts
- sha256:397d68af65db5acda2bc5b298dc6d835a94d84659a12dda10e46c83a99aa2bf3  server/test/apns.test.ts

## Prüfbasis

- base: 820199ad60aa3617de7ae566f5aa4d1cf23981fb
- blob:0f317adafbab1e8b4c233647906c578b6b03d3c7  server/src/apns.ts
- blob:fc351edb8152e55cadf03af5c2b776901fa3142a  server/test/apns.test.ts
