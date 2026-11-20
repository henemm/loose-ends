# Adversary Dialog — feat-960-sparsam-wecken
Spec: docs/specs/feat-960-sparsam-wecken.md
Datum: 2026-11-20 08:25

## Checkliste
- [x] **AC-1:** GIVEN ein Gerät ohne früheren Weckruf WHEN `wake` läuft THEN wird sofort genau einmal gesendet und kein Nachzügler geplant (Test 1).
- [x] **AC-2:** GIVEN ein Weckruf liegt weniger als `minGapMs` zurück WHEN ein weiterer `wake` läuft THEN wird nicht gesendet, genau ein Nachzügler für das Fensterende geplant und `apns wake later ENV` geloggt (Test 2).
- [x] **AC-3:** GIVEN ein Nachzügler ist geplant WHEN weitere `wake` binnen des Fensters laufen THEN wird kein zweiter geplant und nichts gesendet; jeder dieser Aufrufe loggt `apns wake throttled ENV` (Test 3).
- [x] **AC-4:** GIVEN der letzte Weckruf liegt mindestens `minGapMs` zurück und kein Nachzügler ist geplant WHEN `wake` läuft THEN wird wieder sofort gesendet (Test 4).
- [x] **AC-5:** GIVEN der Nachzügler löst aus WHEN das Gerät noch existiert THEN sendet er einmal und eröffnet ein neues Fenster, sodass höchstens ein Weckruf je Gerät je 15 min entsteht (Test 5).
- [x] **AC-6:** GIVEN der Nachzügler löst aus WHEN das Token inzwischen gelöscht ist THEN wird nicht gesendet (Test 6).
- [x] **AC-7:** GIVEN mehrere Geräte oder dasselbe Token in `sandbox` und `production` WHEN `wake` läuft THEN wird je Schlüssel `Umgebung:Token` unabhängig gedrosselt (Tests 7, 8).
- [x] **AC-8:** GIVEN beliebige Drossel- und Nachzüglerausgänge WHEN die Logzeilen gesammelt werden THEN passt jede auf den erweiterten Regex und enthält weder Token noch Konto-Kennung noch Fehlertext (Test 9).
- [x] **AC-9:** GIVEN ein Fehler beim Neulesen oder Senden im Nachzügler WHEN er auslöst THEN wirft nichts nach außen; `wake` wirft weiterhin nie (Test 10).
- [x] **AC-10:** GIVEN die Änderung WHEN `./server/scripts/test-local.sh` läuft THEN sind `npm run typecheck` und `npm test` grün, einschließlich der bestehenden Tests zu Anfrage, JWT, Wiederholversuch und Löschregel; Sendeweg, Payload und Priorität sind unverändert (Test 11, Diff-Durchsicht).

## Dialog

### Runde 1
**Adversary:** Erste Pruefung (Protokoll docs/artifacts/feat-960-sparsam-wecken/adversary-dialog-runde1.md): AC-1 bis AC-10 im Rahmen der Spec belegt, 501/501 gruen. Befunde: F001 MEDIUM (ueberholter Nachzuegler sendet nach erneuertem Fenster ein zweites Mal), F002 LOW (paced waechst, Token-Wanderung). Verdict damals AMBIGUOUS.
**Implementierer:** F001 behoben, F002 bewusst nicht.

### Runde 2
**Adversary:** Neupruefung. Eigener Lauf ./server/scripts/test-local.sh (adversary-test-output.txt ueberschrieben): tsc sauber, 502 bestanden, 0 fehlgeschlagen, 0 uebersprungen; neuer Test 'apns drossel: abgelaufener nachzuegler sendet nicht nach einem neueren weckruf' gruen.
Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: server/src/apns.ts:152
  Description: Fix: wakeLater bricht ab, wenn paced.get(key)?.later nicht true ist. Ueberholter Plan (neuer wake nach Fensterende setzt later=false) sendet nicht mehr.
  Spec requirement: AC-5 — hoechstens ein Weckruf je Geraet je 15 min
  Conflict: keiner mehr; Status RESOLVED, durch Code und Test belegt.
  Remediation: umgesetzt.
Randfaelle des Guards geprueft: (a) regulaerer Nachzuegler: later bleibt true bis zum Timer, Guard laesst durch, sendet einmal (Test 'nachzuegler weckt einmal'). (b) Neulesefehler danach: Guard liest vor dem try nur die Map (wirft nie); catch setzt later=false und loggt 'apns send failed list'; naechster wake plant oder sendet wieder. (c) geloeschtes Geraet: Guard passiert, Neulesen findet es nicht, paced.delete, nichts gesendet. (d) schedule-Standard unref (apns.ts:106) unveraendert; Unhandled Promise ausgeschlossen. Restrisiko (LOW, akzeptiert): wakes bei T+16 und T+17 beide vor dem Callback des alten Timers wuerden den alten Plan wiederbeleben (later=true des neuen Plans); Zeitfenster im Millisekundenbereich, Folge nur ein frueherer Weckruf.
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apns.ts:114
  Description: paced wird nur bei fehlendem Geraet im Nachzuegler bereinigt; Token-Wanderung zwischen Konten loescht den Eintrag des neuen Besitzers.
  Spec requirement: AC-7
  Conflict: kein Funktionsfehler. AKZEPTIERT: hoechstens ein Eintrag je gesehenem Geraet, Token wandern selten, Folge nur ein frueherer Weckruf.
  Remediation: keine.
**Implementierer:** Fix und Test wie beschrieben.

Confirmation:
  AC: AC-1
  Code reference: server/src/apns.ts:164
  Evidence: pace() sendet ohne Zustand sofort (wakeNow Z.145); Test 'erster weckruf sofort' 1 Senden, 0 Plaene.
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: server/src/apns.ts:164
  Evidence: im Fenster later=true, Log 'apns wake later ENV', schedule mit Delay last+gap-now.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: server/src/apns.ts:164
  Evidence: state.later -> 'apns wake throttled ENV', kein Senden, kein zweiter Plan.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: server/src/apns.ts:164
  Evidence: now()-last >= minGapMs -> wakeNow; Test 'nach fensterende sofort wieder'.
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: server/src/apns.ts:151
  Evidence: wakeLater -> wakeNow oeffnet neues Fenster; Guard Z.152 macht ueberholte Plaene wirkungslos; Tests 'nachzuegler weckt einmal...' und 'abgelaufener nachzuegler sendet nicht...' (apns.test.ts:357).
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: server/src/apns.ts:151
  Evidence: Neulesen, fehlendes Geraet -> paced.delete, kein Senden; Test 'weckt kein geloeschtes geraet'.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: server/test/apns.test.ts:375
  Evidence: Schluessel environment:token; Test 'je geraet und umgebung getrennt'.
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: server/test/apns.test.ts:434
  Evidence: nur feste Logstrings; Regextest 'logzeilen nur feste namen' gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: server/src/apns.ts:151
  Evidence: wakeLater: Guard vor try ist reiner Map-Zugriff (wirft nie), Rest in try/catch; Test 'fehler im nachzuegler...'.
  Status: CONFIRMED
Confirmation:
  AC: AC-10
  Code reference: server/test/main.test.ts:819
  Evidence: Diff gegen de0f43e: Sendeweg, Payload, Prioritaet unveraendert; main.test nutzt zweites Geraet nTok(3); 502/502 gruen, tsc sauber.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
F001 behoben und getestet, F002 (LOW) akzeptiert.
Tests: 502 passed, 0 failed, 0 uebersprungen; typecheck gruen
Edge cases: All checked, none broken
Regressions: None found
Checklist: 10/10 points proven

## Geprüfte Dateien

- sha256:d5e966bcffcfe2b9c2b11313d8ccd4bc4bae05bca03cf16f766af900ee6a76ef  server/src/apns.ts
- sha256:27deeb0c7b51e63c6f21aeccaf926f88d030f8f9769bc94c2a26c1eba948d4b0  server/test/apns.test.ts
- sha256:820fb8eede791d01a2fb2d52f0622c479e59ce64ef038edfa6282c668f2812f4  server/test/main.test.ts

## Prüfbasis

- base: de0f43e3eb9aeccadc068947ccc898894668e33e
- blob:f1ec1e3a31c06011374593b145a8c1f98af351cc  server/src/apns.ts
- blob:0e6d87fb03ef3dc319c6ccf3d2c7be3da945735a  server/test/apns.test.ts
- blob:a49e41d18d496096e1a10d73be2419acd698a740  server/test/main.test.ts
