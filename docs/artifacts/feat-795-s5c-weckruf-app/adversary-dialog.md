# Adversary Dialog — feat-795-s5c-weckruf-app
Spec: docs/specs/feat-795-schnitt-5c1-weckruf-kern.md
Datum: 2026-11-15 22:26

## Checkliste
- [x] **AC-1:** Wire: GIVEN ein Client mit Attrappe-Transport und Antwort 204 WHEN `putDevice(token: "ab12…", environment: .production, sessionToken: S, device: D)` läuft THEN ging genau eine Anfrage `POST` an `/app/device` (auch unter Basis mit Pfad) mit `Authorization: Bearer S`, `X-Device` gleich `D` in Kleinschreibung, `Content-Type: application/json` und einem Körper, dessen Schlüssel genau `token` und `environment` sind (Werte `ab12…` und `production`); für `.sandbox` steht `sandbox` (Test `putDeviceWire`).
- [x] **AC-2:** Statusabbildung: GIVEN dieselbe Lage WHEN der Dienst 401, 409, 429, 503, 400, 413, 500 oder 200 antwortet THEN wirft `putDevice` der Reihe nach `unauthorized`, `refused`, `tooManyRequests`, `unavailable`, `rejected(400)`, `rejected(413)`, `rejected(500)`, `rejected(200)`; nur 204 ist Erfolg (Test `putDeviceStatusMapping`).
- [x] **AC-3:** Fehler ohne Geheimnis: GIVEN Antworten 401, 500 und 200 mit einem Körper, der „SECRET-BODY“ enthält, und ein `URLError(.timedOut)` WHEN `putDevice` mit Sitzungstoken „SECRET-SESSION“ und Gerätetoken „SECRET-DEVICE“ läuft THEN enthält die Beschreibung keines geworfenen Fehlers eines dieser Wörter; `URLError(.cancelled)` ergibt `CancellationError`, ein anderer `URLError` ergibt `unavailable` (Test `putDeviceErrorsCarryNoSecrets`).
- [x] **AC-4:** Umgebung: GIVEN die Werte `"production"`, `"sandbox"`, `"Production"`, `""`, `nil`, `42` und `"prod"` WHEN `PushEnvironment(infoValue:)` sie liest THEN ergibt nur der String `"production"` `.production`, alle anderen `.sandbox`; die Rohwerte der Fälle sind `sandbox` und `production` (Test `environmentFromInfoValue`).
- [x] **AC-5:** Hex: GIVEN `Data` aus den Bytes `00 0f a0 ff` und 32 Bytes von `0x00` bis `0x1f` WHEN `DeviceRegistration.hex` sie umsetzt THEN entstehen `000fa0ff` und ein kleingeschriebener String von 64 Zeichen (Test `hexIsLowercaseTwoDigitsPerByte`).
- [x] **AC-6:** Melden: GIVEN ein angemeldetes Konto, ein Gerät `D`, Umgebung `.sandbox` und Antwort 204 WHEN `register(token:)` läuft THEN ist das Ergebnis `registered`, und genau eine Anfrage ging mit dem Hex des Tokens, `sandbox`, dem Sitzungstoken des Stores und `X-Device` gleich `D` hinaus (Test `registersTokenThroughTheSession`).
- [x] **AC-7:** Ohne Sitzung kein Netz: GIVEN ein Konto im Status `signedOut` WHEN `register(token:)` läuft THEN ist das Ergebnis `notSignedIn` und der Transport hat keine Anfrage erhalten; ebenso wird `device` nicht gelesen (Test `withoutSessionNothingIsSent`).
- [x] **AC-8:** Gleiches Paar nicht erneut: GIVEN ein erfolgreich gemeldetes Paar WHEN `register` mit demselben Token und derselben Umgebung noch einmal läuft THEN ist das Ergebnis `unchanged` und es ging keine zweite Anfrage hinaus; mit einem anderen Token geht eine zweite Anfrage hinaus, und eine zweite `DeviceRegistration` mit `.production` für denselben Token sendet ebenfalls (Test `samePairIsSentOnlyOnce`).
- [x] **AC-9:** Fehler wird wiederholt: GIVEN Antworten 503 und danach 204 WHEN `register` zweimal mit demselben Token läuft THEN ist das erste Ergebnis `failed(.unavailable)`, das zweite `registered` (zwei Anfragen); für 429 `failed(.tooManyRequests)`, für 500 `failed(.serviceError)`, für 401 `failed(.unauthorized)` und das Konto ist danach `signedOut`; wirft `device` einen Fehler, ist das Ergebnis `failed(.deviceIdentity)` und es ging nichts hinaus (Test `failureIsRetriedAndNothingIsRemembered`).
- [x] **AC-10:** Nie parallel: GIVEN eine Antwort, die erst nach einer Verzögerung kommt WHEN `register` während der laufenden Meldung ein zweites Mal gerufen wird THEN ist das zweite Ergebnis `busy` und es ging nur eine Anfrage hinaus (Test `noSecondRegistrationWhileOneRuns`).
- [x] **AC-11:** `wake` im Leerlauf: GIVEN ein Trigger mit gezählten Aktionen, `start()` nicht gerufen WHEN `wake()` aufgerufen wird THEN laufen `send`, dann `pull` je einmal in dieser Reihenfolge, und `wake()` kehrt erst nach dem Ende von `pull` zurück (`pull` mit Verzögerung; der Rückkehrzeitpunkt liegt nach dem Eintrag „pulled“) (Test `wakeReturnsAfterSendAndPull`).
- [x] **AC-12:** `wake` während eines Sendens: GIVEN ein `send`, das erst nach einer Verzögerung endet WHEN währenddessen `wake()` aufgerufen wird THEN laufen nie zwei `send` gleichzeitig, `pull` beginnt erst nach dem Ende des laufenden Sendens (und einer vorgemerkten Wiederholung), und `wake()` kehrt erst nach diesem Holen zurück; ein Kaltstart `start()` gefolgt von sofortigem `wake()` verhält sich ebenso und der Weckrufer wartet auf das Holen, nicht nur auf den Start-Durchgang (Test `wakeDuringASendWaitsForTheFollowingPull`).
- [x] **AC-13:** `wake` während eines Holens: GIVEN ein `pull`, das noch läuft, weil es vor dem Aufruf begann WHEN `wake()` aufgerufen wird THEN läuft ein zweites Holen erst nach dem Ende des ersten (nie zwei gleichzeitig) und `wake()` kehrt erst nach dem Ende dieses zweiten Holens zurück (Test `wakeDuringAPullWaitsForAnotherPull`).
- [x] **AC-14:** Mehrere Wartende: GIVEN drei `wake()`-Aufrufe in schneller Folge WHEN der Durchgang läuft THEN kehren alle drei genau einmal zurück, jeder erst nach einem Holen, das nach seinem Aufruf begann, und es laufen nie zwei `send` oder zwei `pull` gleichzeitig; ein weiterer Aufruf, der erst mitten im Holen kommt, wird von einem zusätzlichen Holen bedient (Test `severalWakesAreAllWokenOnce`).
- [x] **AC-15:** Regeln aus S3b-1 bleiben: GIVEN `wake()` läuft WHEN `didSave` gepostet wird THEN folgt weiter nur ein entprelltes `send` und kein `pull` aus dem Speichern; `wake()` registriert keine Beobachter (ohne `start()` löst `didBecomeActive` nichts aus); unter Unit-Test ohne eingereichte Aktionen kehrt `wake()` sofort und ohne Absturz zurück (Test `wakeKeepsTheTriggerRules`). Alle vorhandenen Tests von `ClaudeSyncTriggerTests` und `ServiceClientTests` laufen unverändert grün.
- [x] **AC-16:** Nichts ruft den Kern auf, ohne Geheimnis im Log: GIVEN der Quelltext WHEN er durchsucht wird THEN stehen `putDevice(`, `DeviceRegistration` und `.wake(` außerhalb der eigenen Dateien und der Tests nirgends in `LooseEnds/`; `DeviceRegistration.swift` und die geänderten Zeilen enthalten weder `try?` noch `print(`, und keine Logzeile enthält Token, Hex oder Gerätekennung (Quellsuche als Beleg im Abschlussbericht; kein Swift-Test).
- [x] **AC-17:** Ganze Suite grün: GIVEN die ganze Unit-Suite WHEN sie im Simulator läuft THEN ist sie grün und das Projekt baut für iOS-Simulator ohne Fehler (`./scripts/sim.sh unit`, `./scripts/sim.sh build`; Beleg im Abschlussbericht).

## Dialog

### Runde 1
**Adversary:** Ich unterstelle: wake() verliert oder verdoppelt Wartende, Holen laufen parallel, wake() kehrt zu früh zurück, register() lässt `running` bei Fehlern hängen. Ich lese den Code und gehe die Abläufe durch (alles MainActor, zwischen den awaits keine Unterbrechung). Eigene Testläufe: adversary-test-output.txt.

Confirmation:
  AC: AC-11
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:107
  Evidence: wake() hängt den Wartenden an und ruft sendThenPull(); pullIfAsked nimmt die Wartenden zu Beginn des Holens (Zeile 159) und weckt sie erst nach `await pull()`. Test wakeReturnsAfterSendAndPull grün (3 Läufe).
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:134
  Evidence: requestSend setzt bei laufendem Senden nur sendAgain; drain wiederholt, setzt sending=false und ruft ohne Suspension pullIfAsked; `while pullAfterSend, !sending` verhindert Holen während Senden. Kaltstart start()+wake(): selber pullAfterSend/Wartende-Pfad, geweckt erst von einem Holen nach dem Aufruf.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:155
  Evidence: `guard !pulling` verhindert paralleles Holen; wake() im laufenden Holen setzt pullAfterSend, der Wartende ist nicht in `group` des laufenden Holens, die Schleife oder der drain danach holt erneut und weckt ihn. Endet das laufende Holen während eines Sendens, verlässt die Schleife `!sending`, das Ende von drain ruft pullIfAsked: kein verlorener Wartender, kein Deadlock.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:159
  Evidence: `group = waiters; waiters = []` vor `await pull()`: jeder Wartende genau einmal geweckt; wer mitten im Holen kommt, bleibt in waiters und löst per pullAfterSend ein weiteres Holen aus.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:70
  Evidence: start/didBecomeActive/didSave/Import-Pfade unverändert (Diff nur Felder, wake(), Holen-Schleife); wake() registriert keine Beobachter; unter silent leere Aktionen, wake() kehrt sofort zurück. 17 ClaudeSyncTriggerTests grün, dreimal.
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Claude/ServiceClient.swift:107
  Evidence: bearer(path: "app/device"), X-Device in Kleinschreibung, Content-Type JSON, Körper genau {token, environment}, Erfolg nur 204 über send(_:success:).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Claude/ServiceClient.swift:112
  Evidence: gleiche send(success:[204])-Abbildung wie putResult; Test putDeviceStatusMapping grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/ServiceClient.swift:111
  Evidence: Der Körper wird nur in die Anfrage geschrieben, kein Fehlerpfad enthält Token, URL oder Körper (vorhandenes send); Test putDeviceErrorsCarryNoSecrets grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/DeviceRegistration.swift:9
  Evidence: `(infoValue as? String) == "production"`: nur genau der String ergibt production; 42, nil, Production, prod ergeben sandbox.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Claude/DeviceRegistration.swift:55
  Evidence: String(format: "%02x") je Byte, klein; leeres Data ergibt "" ohne Absturz.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Claude/DeviceRegistration.swift:67
  Evidence: genau ein putDevice innerhalb account.withSession mit dem Sitzungstoken aus dem Store; registered bei Nicht-nil.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Claude/DeviceRegistration.swift:84
  Evidence: device() wird nur im Closure von withSession gelesen (readDevice); ohne Sitzung gibt withSession nil: notSignedIn, nichts gesendet, nichts gemerkt.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Claude/DeviceRegistration.swift:72
  Evidence: lastSent wird nur nach nicht-nil-Rückgabe (204) gesetzt; Pair enthält Hex und Umgebung, daher sendet .production für denselben Token erneut.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Claude/DeviceRegistration.swift:76
  Evidence: Fehler: nichts gemerkt; `defer { running = false }` gibt den busy-Merker bei jedem Austritt frei (auch CancellationError); 401 wirft aus withSession nach dropSession (AccountState.swift:121-124); DeviceUnreadable trägt nichts vom Ursprungsfehler.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Claude/DeviceRegistration.swift:64
  Evidence: `running` wird vor dem ersten await gesetzt (MainActor, keine Lücke); zweiter Aufruf mit anderem Token während des Laufs ergibt busy. Beobachtung, kein Defekt: dasselbe Paar während des Laufs ergibt auch busy (noch nichts gemerkt), passt zur Spec.
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: LooseEnds/Claude/DeviceRegistration.swift:76
  Evidence: Quellsuche über LooseEnds, Shared, Watch-, Widget- und Share-Ziele: putDevice/DeviceRegistration/PushEnvironment/.wake( nur in den eigenen Dateien (ServiceClient.swift:107 Definition); kein `try?`, kein `print(` in den drei Dateien und im Diff; die Logzeile enthält nur Fallname und Typname des Fehlers.
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: LooseEnds/Claude/ServiceClient.swift:106
  Evidence: test-green-output.txt (Executed 65 tests, 0 failures) und eigene Läufe: DeviceRegistrationTests 10/0, ClaudeSyncTriggerTests 17/0, je dreimal, kein Wackler.
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt, Kontextisolierung)

### Runde 2
**Adversary:** Zweiter Angriff auf Randfälle; frühe Einigkeit nicht geglaubt.
- Hängendes pull lässt wake() hängen: laut Spec Sache des Aufrufers (Frist in S5c-2a), kein Defekt dieses Schnitts.
- Abbruch des Aufrufers: Wartender bleibt stehen, wird beim nächsten Holen geweckt, nie verloren.
- didSave während eines Holens startet drain parallel zum pull wie vor dem Schnitt; wake() in dieser Lage setzt sendAgain/pullAfterSend, die Holen-Schleife endet an `!sending`, das drain-Ende holt: kein Deadlock, kein doppeltes Wecken (Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:154).
- Wiedereintritt: `pulling` wird erst nach der Schleife ohne Suspension zurückgesetzt: kein Fenster, in dem ein Wartender ohne Holen stehen bleibt.
- register: Abbruch ergibt failed(.cancelled), `running` wird frei; Logzeile ohne Token, Hex, UUID.
- Leeres Token-Data: Hex "" geht raus, der Dienst lehnt ab (serviceError); kein Absturz, Aufrufer fehlt noch.
Keine Findings. 17 von 17 Punkten belegt.
**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
Tests: DeviceRegistrationTests 10 und ClaudeSyncTriggerTests 17, je 3 Läufe, 0 Fehler, 0 übersprungen (adversary-test-output.txt); volle Suite 65 Tests, 0 Fehler laut test-green-output.txt.
Edge cases: alle geprüft, keine gebrochen. Regressions: keine. Checklist: 17/17 belegt.

## Geprüfte Dateien

- sha256:b28321a29d422c38be6f8e48155787693a63902a58f67eb0343d844fcee1cafd  LooseEnds/Claude/ClaudeSyncTrigger.swift
- sha256:37af4660ff91e645c71a474d3501577d12e7eb3eb206bad30321bd38d1cd5f6c  LooseEnds/Claude/DeviceRegistration.swift
- sha256:2e1921d069d8ab5d7b79a78bfe036fccdce3ba56297dda0e344a2dd22e0a0148  LooseEnds/Claude/ServiceClient.swift

## Prüfbasis

- base: 44e3a261ae583b9f462a78e870b9f891678605ed
- blob:9054696fb656858d206fbc67a5573b82624e0153  LooseEnds/Claude/ClaudeSyncTrigger.swift
- blob:e4f3e618f10849b5f2f4b38a9998189fa3966526  LooseEnds/Claude/DeviceRegistration.swift
- blob:3494bf5d6cd350055d33dc4207efd3cbe0218eb4  LooseEnds/Claude/ServiceClient.swift

## Geprüfte Dateien

- sha256:b28321a29d422c38be6f8e48155787693a63902a58f67eb0343d844fcee1cafd  LooseEnds/Claude/ClaudeSyncTrigger.swift
- sha256:37af4660ff91e645c71a474d3501577d12e7eb3eb206bad30321bd38d1cd5f6c  LooseEnds/Claude/DeviceRegistration.swift
- sha256:2e1921d069d8ab5d7b79a78bfe036fccdce3ba56297dda0e344a2dd22e0a0148  LooseEnds/Claude/ServiceClient.swift

## Prüfbasis

- base: 44e3a261ae583b9f462a78e870b9f891678605ed
- blob:9054696fb656858d206fbc67a5573b82624e0153  LooseEnds/Claude/ClaudeSyncTrigger.swift
- blob:e4f3e618f10849b5f2f4b38a9998189fa3966526  LooseEnds/Claude/DeviceRegistration.swift
- blob:3494bf5d6cd350055d33dc4207efd3cbe0218eb4  LooseEnds/Claude/ServiceClient.swift
