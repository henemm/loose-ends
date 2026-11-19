# Adversary Dialog — feat-795-s5c2a-weckruf-delegates
Spec: docs/specs/feat-795-schnitt-5c2a-weckruf-delegates.md
Datum: 2026-11-19 13:13

## Checkliste
- [x] **AC-1:** GIVEN `userInfo` WHEN `PushWakeUp.isWake` prüft THEN ist es wahr nur bei vorhandenem Schlüssel `looseends` und läuft synchron im Rückruf (Test `isWakeOnlyWithLooseendsKey`).
- [x] **AC-2:** GIVEN ein Weckruf WHEN `wake()` innerhalb der Frist zurückkehrt THEN meldet `handle` geweckt, der iOS-Delegate `.newData` (Test `wakeWinsMapsToNewData`).
- [x] **AC-3:** GIVEN ein Weckruf WHEN `wake()` die 20-s-Frist überschreitet THEN meldet `handle` Frist, der iOS-Delegate `.noData`, nie `.failed` (Test `deadlineWinsMapsToNoData`).
- [x] **AC-4:** GIVEN die Frist hat gewonnen WHEN `wake()` später endet THEN wird der Abschluss nicht ein zweites Mal ausgelöst (Mutex-Einmalkasten; Test `lateWakeDoesNotCompleteTwice`).
- [x] **AC-5:** GIVEN eine Mitteilung ohne Schlüssel `looseends` WHEN sie eintrifft THEN antwortet der Knoten sofort `.noData` und ruft `wake()` nicht auf (Test `foreignNotificationReturnsImmediately`).
- [x] **AC-6:** GIVEN ein Gerätetoken WHEN der Token-Rückruf kommt THEN geht es über `DeviceRegistration.register` an den Dienst, nur mit Sitzung, und nichts ohne (Test `tokenForwardedOnlyWithSession`).
- [x] **AC-7:** GIVEN `account.status` WHEN er `signedIn` wird (beim Start oder später) THEN wird `registerForRemoteNotifications` genau einmal ausgelöst, ohne Konto nie (Test `signInTriggersOneRegistration`).
- [x] **AC-8:** GIVEN `--ui-testing` oder Unit-Tests WHEN die App startet THEN ist der Knoten nicht installiert und es wird nichts registriert (Test `silentUnderTests`).
- [x] **AC-9:** GIVEN der Mac WHEN `MacAppDelegate` Token oder Mitteilung erhält THEN reicht er an denselben Knoten durch, ohne Completion-Handler (Beleg: Mac-Bau `./scripts/sim.sh mac-build` grün und Diff).
- [x] **AC-10:** GIVEN der Diff WHEN gelesen THEN bleiben `project.yml`, Entitlements, `Info.plist` und `server/` unverändert, und es entsteht keine zweite Stelle für `registerForRemoteNotifications` außerhalb des Knotens.
- [x] **AC-11:** GIVEN die ganze Suite WHEN sie läuft THEN sind `./scripts/sim.sh unit` und die CI grün, und der Simulator-Bau gelingt (`./scripts/sim.sh build`).
- [?] **AC-12:** GIVEN der Simulator-Bau mit `LOOSEENDS_SIM_SIGN=1` und Debug-Weg (`local-service.sh`) WHEN `xcrun simctl push` einen Weckruf mit Schlüssel `looseends` sendet THEN wird der Auftrag geholt (Ergebnis in der Datenbank belegt), und ein Inhalt ohne den Schlüssel löst kein Holen aus (Beleg unter `docs/artifacts/feat-795-s5c2a-weckruf-delegates/`; der Simulator-Rückruf gilt laut Forum 725200 als unzuverlässig, Abweichung wird im Beleg benannt).

## Dialog

### Runde 1
**Adversary:** Alle Belege selbst nachgeprüft. `sim-unit PushWakeUpTests` (adversary-test-output.txt): Executed 8 tests, 0 failures. `git diff bb225fe -- project.yml server/ '*.entitlements' '*Info.plist'` leer. `grep registerForRemoteNotifications LooseEnds Shared`: nur PushWakeUp.swift (Zeilen 64 und 66). Ganze Suite laut test-green-output.txt: 1414, 1401 bestanden, 0 Fehlschläge, 13 Skips; mac-build grün.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Claude/PushWakeUp.swift:71
  Evidence: `isWake` ist `nonisolated static`, prüft synchron nur `userInfo["looseends"] != nil`; Test deckt Gross-/Kleinschreibung, CloudKit-`ck`, leer ab.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Claude/PushWakeUp.swift:77
  Evidence: `handle(isWake:)` gibt nach `wake()` `.woken` zurück, `fetchResult` (Zeile 21) bildet auf `.newData` ab; `IOSAppDelegate` reicht das durch (IOSAppDelegate.swift:24).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/PushWakeUp.swift:81
  Evidence: Zeitgeber-Task meldet `.deadline` nach `deadline` (20 s Standard); `fetchResult` nie `.failed` (Zeile 22, Test prüft alle drei Fälle).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/PushWakeUp.swift:129
  Evidence: `FinishOnce.finish` nimmt die Continuation unter Mutex-Lock und setzt sie auf nil; jede zweite Meldung ist ein No-op, kein doppeltes `resume` möglich, auch unter Wettlauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Notifications/IOSAppDelegate.swift:22
  Evidence: `isWake` wird synchron ausgewertet, nur das `Bool` geht in `handle`; fremde Mitteilung gibt sofort `.notOurs` (PushWakeUp.swift:78) und damit `.noData`; ohne Knoten ebenfalls `.noData` (IOSAppDelegate.swift:23). `userInfo` gelangt in keine Task.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Claude/PushWakeUp.swift:102
  Evidence: `didReceive(token:)` geht nur über `DeviceRegistration.register`; Test belegt Request mit Hex-Token mit Sitzung und keinen Request ohne.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Claude/PushWakeUp.swift:107
  Evidence: `observeSignIn` löst nur bei Übergang auf `signedIn` aus (`wasSignedIn`), idempotent durch `observing`-Wächter; Test: Start angemeldet = 1, spätere Anmeldung = 1, `signingIn` und ohne Konto = 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/App/LooseEndsApp.swift:70
  Evidence: `forApp(..., silent: isRunningTests || isUITesting)` gibt nil; `PushWakeUp.current = push` bleibt nil, `push?.observeSignIn()` ist No-op. Der Delegate selbst ist unter Tests installiert (Zeile 11), tut aber mit `current == nil` nichts (`?.`, `.noData`).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:180
  Evidence: Signatur `didReceiveRemoteNotification userInfo: [String: Any]` entspricht `NSApplicationDelegate`, kein Completion-Handler, Task nur mit `Bool`; Token-Rückruf Zeile 170 gleich; Fehler-Rückruf loggt nur den Typnamen. mac-build grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/App/LooseEndsApp.swift:11
  Evidence: Diff gegen bb225fe für project.yml, server/, entitlements, Info.plist leer; einzige Aufrufstelle `registerForRemoteNotifications` in PushWakeUp.swift:64/66.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: LooseEndsTests/PushWakeUpTests.swift:1
  Evidence: Gesamtsuite 1414 / 0 Fehlschläge / 13 Skips (benannt, bekannte Mess-/Gerätetests), build und mac-build grün. CI-Teil nicht lokal prüfbar.
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt, Kontextisolierung)

### Runde 2
**Adversary:** Gezielte Angriffe.

1. Einmal-Abschluss unter Wettlauf: `wake()` und Zeitgeber treffen gleichzeitig ein. Der Mutex entnimmt die Continuation atomar, genau ein Aufrufer ruft `resume`. Nicht angreifbar. Schwäche nur im Test 4: `completions` wird in `handle` gezählt, nicht in `finish`; der Test belegt also "handle kehrt einmal zurück", nicht direkt "kein zweites resume". Ein doppeltes resume würde eine CheckedContinuation ohnehin als Absturz melden, daher gering.
2. Frist-Task-Abbruch: Gewinnt `wake()`, wird der Zeitgeber abgebrochen (Zeile 91), `Task.sleep` wirft, `return` ohne finish. Gewinnt die Frist, läuft `wake()` weiter (nicht abbrechbar, dokumentiert), `timer.cancel()` und `finish` sind danach wirkungslos. Kein Leck.
3. `userInfo` in keiner Task: bestätigt in IOSAppDelegate.swift:22-24 und MenuBarCapture.swift:181-183.
4. CloudKit-Mitteilungen: ohne Schlüssel sofort `.noData`. Restrisiko: Ob die frühe `.noData`-Antwort den CloudKit-Abgleich im Hintergrund beeinträchtigt, ist nur am Gerät belegbar; die Spec legt das in die DoD (Stufe 3). Kein Befund im Code.
5. Unit-Test-Host: `PushWakeUp.current` nil, Test `silentUnderTests` prüft es.
6. Kein `.failed`: nur zwei Werte in `fetchResult`.
7. Logging: nur Fallname (`String(describing: type(of: error))` bzw. `Result`); Token und Fehlertext nie geloggt.
8. Mac: bei Frist liefert `handle` kein Ergebnis zurück, das ist laut Spec gewollt.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Notifications/IOSAppDelegate.swift:21
  Description: Der Pfad Delegate-Rückruf -> `handle` -> `wake()` -> Auftrag geholt wurde in keiner Umgebung ausgeführt. `simctl push` wird im iOS-27.2-Simulator mit UNErrorDomain 1401 abgewiesen, der Rückruf wird nie aufgerufen (simulator-push.md).
  Spec requirement: AC-12 — Weckruf mit `looseends` holt den Auftrag (Ergebnis in der Datenbank belegt), Inhalt ohne Schlüssel holt nichts.
  Conflict: Belegt ist nur die Token-Registrierung (device_tokens=1). Beide Läufe (mit und ohne Schlüssel) enden vor der App; die Gegenprobe hat damit keine Aussagekraft. Die Spec lässt eine benannte Abweichung zu ("Abweichung wird im Beleg benannt"), aber nur für die Unzuverlässigkeit des Rückrufs, nicht für den Ausfall des Kernnachweises.
  Remediation: Nachweis bleibt Stufe 3 (TestFlight, Konto-Bau) in der DoD; AC-12 im PR ausdrücklich als "Registrierung belegt, Empfang nicht belegbar" führen. Optional: Rückruf-Kette im Simulator über einen Debug-Launch-Argument-Aufruf der Delegate-Methode belegen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/PushWakeUpTests.swift:113
  Description: Test 4 zählt `completions` in `handle`, das nur einmal zurückkehrt; er kann ein doppeltes `finish` nicht von einem einfachen unterscheiden.
  Spec requirement: AC-4 — kein zweiter Abschluss.
  Conflict: Beweiskraft schwächer als der Name; der Code selbst ist korrekt (Mutex).
  Remediation: Optional Zähler in `FinishOnce` für Tests.

**AC-12 ehrlich bewertet:** Die Spec nahm das Risiko vorweg, aber das Gate-Wort lautet "Ergebnis in der Datenbank belegt". Das fehlt. Die Abweichung ist sauber benannt, die Ursache plausibel (Forum 663276/826180 laut Auftraggeber, 1401-Text im Beleg). Das macht AC-12 nicht erfüllt, sondern nur "mit benannter Abweichung teilbelegt". Ob das als Abnahme genügt, ist eine Entscheidung des Auftraggebers/Tech Leads, nicht des Prüfers. Der Code selbst hat keinen Fehler gezeigt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Weitere Code references (Abdeckung): 
Code reference: LooseEnds/Mac/MenuBarCapture.swift:170
Code reference: LooseEnds/App/LooseEndsApp.swift:72
Code reference: LooseEndsTests/PushWakeUpTests.swift:150

## Verdict

**AMBIGUOUS**: AC-1 bis AC-11 PROVEN; AC-12 nur teilweise (Registrierung belegt, Empfang im Simulator technisch nicht belegbar). Keine Code-Fehler gefunden.

## Geprüfte Dateien

- sha256:5227f429fab534875935cfedb584783cade70a4dc8e0d3d87e5bd99bc62e177f  LooseEnds/App/LooseEndsApp.swift
- sha256:b30c6f8f9066fd2c00ca07a28ebc23748301dc7ee9a6eabdc70a165bb5c94a86  LooseEnds/Claude/PushWakeUp.swift
- sha256:ca7a6cbc787a20056ac31aacd0a2af5be6cbc81bfb5c6ba92cb8188239f7a9e1  LooseEnds/Mac/MenuBarCapture.swift
- sha256:453e0313c72256e2c57152e9db0b25d5b500df1ffe705e26ae747fe2235e60f0  LooseEnds/Notifications/IOSAppDelegate.swift
- sha256:a6ccacfbdd2d0d362715d34e28aa51d3482a6c003ac26a72da5234e954c8b2fe  LooseEndsTests/PushWakeUpTests.swift

## Prüfbasis

- base: bb225fea6bf45f9492d6646b931cd7b7583aabfc
- blob:f593cc5726a966f392d9b9545d91a368dcc997a6  LooseEnds/App/LooseEndsApp.swift
- blob:961781e2f7ed5c11c6d45104876e2c367d08e31e  LooseEnds/Claude/PushWakeUp.swift
- blob:5b6a144984e17235dd000e67e9c68663b30faf5c  LooseEnds/Mac/MenuBarCapture.swift
- blob:7917f64dfe35183498132d1e37bd70e9ecc35987  LooseEnds/Notifications/IOSAppDelegate.swift
- blob:9b6091830b800e58ff1ac1a2f39fef21903ba5f0  LooseEndsTests/PushWakeUpTests.swift
