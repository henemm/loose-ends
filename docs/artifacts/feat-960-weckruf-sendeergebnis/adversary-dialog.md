# Adversary Dialog — feat-960-weckruf-sendeergebnis
Spec: docs/specs/feat-960-weckruf-sendeergebnis.md
Datum: 2026-11-19 21:31

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
**Adversary:** Ich gehe von kaputt aus. Vollstaendiger Lauf `./server/scripts/test-local.sh` (Beleg `adversary-test-output.txt`): Exit 0, typecheck und npm test gruen, 485 Tests, 485 bestanden, 0 fehlgeschlagen, 0 uebersprungen. AC-7 damit bewiesen (Vorgaenger-Befund #963 behoben).
Probe (a): Hat der migrate-Test an Aussagekraft verloren? Der Test ruft weiterhin `migrate` gegen eine kaputte Migration (rejects /no_such_table/), prueft `lockIsFree(url)` ueber eine neue Verbindung (bis 50 Wiederholungen, nur solange der Lock belegt ist) und verlangt danach den reparierten Lauf in 5 s mit demselben Pool. Haelt `migrate` den Lock nach Fehlschlag (migrate.ts:95 lock, :100 unlock im finally, :106 release(broken)), bliebe er gehalten und `lockIsFree` auf neuer Verbindung derselben, jetzt exklusiven Datenbank liefert false: Test rot. Die eigene Datenbank schliesst nur fremde Halter aus. Nicht abgeschwaecht.
Probe (b): Aufraeumen: `t.after` fuehrt pool.end, DROP DATABASE ... WITH (FORCE), admin.end auch bei Fehlschlag aus. Kleiner Rest: schlaegt CREATE DATABASE selbst fehl, bleibt der admin-Client offen (nur Testprozess, folgenlos, kein Befund).
Probe (c): test-local.sh nutzt initdb -U postgres (Superuser), CI server.yml DATABASE_URL postgres://postgres:postgres@.../postgres mit postgres:18: CREATE DATABASE moeglich. Lokal belegt durch den gruenen Lauf.
Probe (e): AC-1..AC-6 gegen Code: `apnsIds` (apns.ts:76, verankerte UUID-Regex), `describe` prueft erneut, `deliver` (apns.ts:117) schreibt je Ausgang eine feste Zeile, Catch-Zweig `apns send failed error ENV` (:131), wake loggt `devices=N` vor dem Senden (:139), Listenfehler `apns send failed list`. Tests: apns.test.ts:108-116 (Retry genau eine Ergebniszeile), :133 (Drop), :142-153 (Ausgaenge), :163 (ids nur kanonisch), :195 (leer/Listenfehler), :229 (Regex ueber alle Zeilen). log wirft und dropToken wirft landen in try/catch bzw. allSettled, wake wirft nie. Keine Geheimnisse in den Zeilen (nur Status, env, UUIDs).
**Implementierer:** Keine Einwaende; Nachweise stimmen.

### Runde 2
**Adversary:** Fruehe Einigung ist verdaechtig, zweiter Angriff: (1) Header-Array oder Gross-/Anhangtext in apns-id: typeof-Pruefung plus verankerte Regex lehnen ab. (2) Antwort ohne Status: `end` loest nur bei status, sonst close -> Reject -> `error ENV`. (3) Reason-Freitext erscheint nie in describe. (4) Diff: DROP-Set, Retry-Bedingung, Prioritaet, Payload unveraendert; bestehende Tests gruen. (5) migrate-Test: Datenbankname aus randomUUID hex, kollisionsfrei, keine Injektion; parallele Testdateien beruehren die Wegwerf-DB nicht. Kein Gegenbeispiel.
**Implementierer:** Bestaetigt.

Confirmation:
  AC: AC-1
  Code reference: server/src/apns.ts:126
  Evidence: `apns sent` plus Status/ENV/ids; server/test/apns.test.ts:108 und :163
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: server/src/apns.ts:76
  Evidence: apnsIds filtert per verankerter UUID-Regex, nochmals in describe; server/test/apns.test.ts:163
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: server/src/apns.ts:131
  Evidence: failed/dropped/error-Zeilen fester Form; server/test/apns.test.ts:133
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: server/src/apns.ts:139
  Evidence: `apns wake devices=N`, 0 Geraete sendet nichts; server/test/apns.test.ts:195
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: server/test/apns.test.ts:229
  Evidence: Regex ueber alle gesammelten Zeilen, keine Geheimnisse
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: server/src/apns.ts:117
  Evidence: Sendeweg/Retry/DROP unveraendert, bestehende Tests gruen (485/485)
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: server/test/migrate.test.ts:226
  Evidence: Test mit eigener Wegwerf-DB (freshDatabase :189, lockIsFree :208); Gesamtlauf Exit 0, 485 pass, 0 fail
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)


## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 485 passed, 0 failed, 0 uebersprungen (test-local.sh Exit 0)
Edge cases: All checked, none broken
Regressions: None found
Checklist: 7/7 points proven

## Geprüfte Dateien

- sha256:344cf0bea7c1b96bec48c3b5143a4c596b30590a00cad5363d3a37eacaf71026  server/src/apns.ts
- sha256:397d68af65db5acda2bc5b298dc6d835a94d84659a12dda10e46c83a99aa2bf3  server/test/apns.test.ts
- sha256:0c1faedad3963e2bb6af5cae31d75ad8f3481b36d0d9e0773c74974021407348  server/test/migrate.test.ts

## Prüfbasis

- base: 820199ad60aa3617de7ae566f5aa4d1cf23981fb
- blob:0f317adafbab1e8b4c233647906c578b6b03d3c7  server/src/apns.ts
- blob:fc351edb8152e55cadf03af5c2b776901fa3142a  server/test/apns.test.ts
- blob:847679efa782e38d71d2811baf4d7180472655b9  server/test/migrate.test.ts
