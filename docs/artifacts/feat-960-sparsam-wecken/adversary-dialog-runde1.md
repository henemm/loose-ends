# Adversary Dialog — feat-960-sparsam-wecken
Spec: docs/specs/feat-960-sparsam-wecken.md
Datum: 2026-11-20 08:22

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
**Adversary:** Alle zehn ACs gegen Code und Testausgabe gefordert. Eigener Lauf von ./server/scripts/test-local.sh (Ausgabe: docs/artifacts/feat-960-sparsam-wecken/adversary-test-output.txt): typecheck (tsc --noEmit) sauber, 501 Tests bestanden, 0 fehlgeschlagen, 0 uebersprungen.
Confirmation: AC-1 / Code reference: server/src/apns.ts:164 / Evidence: pace() ruft ohne Zustand wakeNow (Zeile 145); Test "apns drossel: erster weckruf sofort..." prueft 1 Senden, 0 Plaene, Log nur devices=1 + sent. Status: CONFIRMED
Confirmation: AC-2 / Code reference: server/src/apns.ts:164 / Evidence: im Fenster setzt pace later=true, loggt "apns wake later ENV", schedule mit Delay last+gap-now (Test: Delay 10 min bei Minute 5). Status: CONFIRMED
Confirmation: AC-3 / Code reference: server/src/apns.ts:164 / Evidence: state.later -> "apns wake throttled ENV", kein Senden, kein zweiter Plan (Test Minute 7 und 9: 1 Senden, 1 Plan). Status: CONFIRMED
Confirmation: AC-4 / Code reference: server/src/apns.ts:164 / Evidence: now()-last >= minGapMs (Grenze inklusive) -> wakeNow; Test "nach fensterende sofort wieder" (GAP-1 plant, GAP sendet). Status: CONFIRMED
Confirmation: AC-5 / Code reference: server/src/apns.ts:151 / Evidence: wakeLater -> wakeNow setzt last neu, later=false; Test "nachzuegler weckt einmal und eroeffnet ein neues Fenster". Status: CONFIRMED (Einschraenkung F001)
Confirmation: AC-6 / Code reference: server/src/apns.ts:151 / Evidence: listTokens neu gelesen, fehlt das Geraet -> paced.delete, kein Senden; Test "nachzuegler weckt kein geloeschtes geraet". Status: CONFIRMED
Confirmation: AC-7 / Code reference: server/src/apns.ts:114 / Evidence: Map-Schluessel keyOf = environment:token; Test "je geraet und umgebung getrennt". Status: CONFIRMED
Confirmation: AC-8 / Code reference: server/test/apns.test.ts:434 / Evidence: nur feste Logstrings in apns.ts (later/throttled/list mit device.environment); Regextest "logzeilen nur feste namen" gruen. Status: CONFIRMED
Confirmation: AC-9 / Code reference: server/src/apns.ts:151 / Evidence: wakeLater komplett in try/catch, catch loggt nur "apns send failed list" und setzt later=false; log selbst gekapselt; Timer-Callback liefert nie eine rejected Promise; Test "fehler im nachzuegler werfen nicht". Status: CONFIRMED
Confirmation: AC-10 / Code reference: server/test/main.test.ts:819 / Evidence: Diff gegen de0f43e in apns.ts nur Drossel (deliver, Anfrage, Payload BODY, Prioritaet unveraendert); main.test nutzt zweites Geraet nTok(3), weil nTok(1) gedrosselt ist, und prueft, dass nTok(1) nicht geloescht wird. Status: CONFIRMED
Randfaelle aktiv: unref im Standard-Timer (apns.ts:106) ok; Fehler im Neulesen -> later=false, naechster wake plant/sendet wieder ok; Clock exakt am Fensterende = senden (>=) ok.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Zweite Runde, gezielt Zustandsmaschine angreifen.
Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: server/src/apns.ts:164
  Description: pace() sendet bei abgelaufenem Fenster sofort (wakeNow setzt later=false), auch wenn ein Nachzuegler noch geplant ist; der geplante Timer ruft danach in wakeLater (Zeile 151) ohne Pruefung von state.later oder des Fensters erneut wakeNow auf.
  Spec requirement: AC-5 — hoechstens ein Weckruf je Geraet je 15 min
  Conflict: Ablauf wake@0 (sendet), wake@5 (plant), wake@16 (sendet, Fenster neu), dann Timer feuert: zweiter Weckruf zur selben Zeit. Real moeglich, wenn ein wake nach dem Fristablauf, aber vor dem Timer-Callback eintrifft (beide warten auf listTokens). Kein Test deckt es ab; AC-4 setzt "kein Nachzuegler geplant" voraus, der Fall ist daher unspezifiziert.
  Remediation: In wakeLater am Anfang pruefen: state fehlt oder !state.later oder now()-last < minGapMs -> nichts tun; oder in wakeNow den geplanten Nachzuegler entwerten (Generationszaehler).
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apns.ts:114
  Description: Die Map paced wird nur in wakeLater bei fehlendem Geraet geleert; Eintraege fuer entfernte oder gedroppte Tokens bleiben bis Prozessende. Ausserdem loescht wakeLater bei einem zu einem anderen Konto gewanderten Token den Eintrag des neuen Besitzers.
  Spec requirement: AC-7 — Drosselung je Schluessel
  Conflict: Kein Funktionsfehler, nur langsamer Speicherzuwachs und eine zusaetzliche Sendung im seltenen Wanderfall.
  Remediation: Eintraege bei Drop oder Alter > minGapMs bereinigen.
Weitere Randfaelle ohne Befund: schedule wirft synchron -> aeusserer try faengt, later bleibt true, nach Fensterende sendet der naechste wake wieder (Selbstheilung); Unhandled Promise im Timer ausgeschlossen (try/catch um alles). Sendeweg/Payload/Prioritaet im Diff unveraendert.
Code reference: server/test/apns.test.ts:310 (Drossel-Tests 1-7 vorhanden, alle gruen; kein Test fuer F001).
**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review):
  F001: Nachzuegler feuert nach bereits erneuertem Fenster ein zweites Mal (AC-5 "hoechstens ein Weckruf je 15 min" im Randfall verletzt, von AC-4 nicht abgedeckt) — Einzeiler-Fix in wakeLater empfohlen.
  F002 (LOW): paced waechst ohne Bereinigung.
Proven points: 10/10 im spezifizierten Rahmen
Tests: 501 passed, 0 failed, 0 uebersprungen; typecheck gruen
Regressions: None found

## Geprüfte Dateien

- sha256:1f784e6b7e233a742e40af29ea39d5c73e6a0492461cb1cf468ac7efd92b7f03  server/src/apns.ts
- sha256:00870ffcd50b5db9a96a2ddd5ce10e67f377833ab844945e8601479c52f15f78  server/test/apns.test.ts

## Prüfbasis

- base: de0f43e3eb9aeccadc068947ccc898894668e33e
- blob:72cb09fdd2c29fdf2fbc89655bbc1ec156911a89  server/src/apns.ts
- blob:755b516b3ea636fb6a039eff04e9a8663bc83d24  server/test/apns.test.ts
