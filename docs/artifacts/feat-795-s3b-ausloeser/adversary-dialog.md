# Adversary Dialog — feat-795-s3b-ausloeser
Spec: docs/specs/feat-795-schnitt-3b1-ausloeser.md
Datum: 2026-11-12 21:56

## Checkliste
- [x] **AC-1:** Start: GIVEN ein Trigger mit gezählten Closures WHEN `start()` gerufen wird THEN lief genau einmal `send` und danach genau einmal `pull`, in dieser Reihenfolge, und es folgt nichts weiter (Test `startSendsThenPullsOnce`).
- [x] **AC-2:** Reihenfolge: GIVEN ein `send`, das erst nach einer Verzögerung endet WHEN `start()` gerufen wird THEN beginnt `pull` erst nach dem Ende von `send` (Test `pullWaitsForSendToFinish`).
- [x] **AC-3:** `start()` einmal: GIVEN ein gestarteter Trigger WHEN `start()` ein zweites Mal gerufen wird und danach eine Aktivierung gepostet wird THEN ist die Zahl der Aufrufe die eines einfachen Starts plus genau einer Aktivierung, nicht doppelt (Test `secondStartChangesNothing`).
- [x] **AC-4:** Vordergrund: GIVEN ein gestarteter Trigger WHEN die Benachrichtigung `didBecomeActive` der Plattform gepostet wird THEN lief nach dem Start-Durchgang einmal zusätzlich `send`, dann `pull` (Test `becomingActiveSendsThenPulls`).
- [x] **AC-5:** Speichern entprellt: GIVEN ein gestarteter Trigger und seine Aufrufe des Starts abgewartet WHEN `ModelContext.didSave` fünfmal in schneller Folge gepostet wird THEN lief nach der Entprellung genau einmal `send` und nie `pull` (Test `savesAreDebouncedToOneSendAndNeverPull`).
- [x] **AC-6:** Speichern wartet: GIVEN dieselbe Lage WHEN `didSave` gepostet wird THEN lief `send` nicht sofort, sondern erst nach `debounce`, und ein weiteres `didSave` innerhalb der Frist verschiebt es (Test `saveSendsOnlyAfterTheDebounce`).
- [x] **AC-7:** Import: GIVEN ein gestarteter Trigger WHEN `handle(_:)` ein fertiges, fehlerfreies Importereignis erhält THEN lief nach der Entprellung genau einmal `send` und nie `pull`; bei einem unfertigen (`endDate == nil`), einem fehlgeschlagenen (`errorMessage != nil`) und einem Export-Ereignis lief nichts (Test `onlyAFinishedImportSends`, Argumente je Ereignis).
- [x] **AC-8:** Ohne Start stumm: GIVEN ein Trigger, dessen `start()` nie gerufen wurde WHEN `didBecomeActive` und `didSave` gepostet werden THEN lief weder `send` noch `pull` (Test `withoutStartNothingReacts`).
- [x] **AC-9:** Holen nie an Speichern und Import: GIVEN ein gestarteter Trigger WHEN `didSave` und ein fertiger Import in beliebiger Folge eintreffen THEN ist die Zahl der `pull`-Aufrufe nach dem Start-Durchgang unverändert (Test `pullNeverFollowsSaveOrImport`).
- [x] **AC-10:** Stumm unter Tests: GIVEN ein Trigger ohne eingereichte Closures unter Unit-Test WHEN `start()` gerufen wird und Benachrichtigungen gepostet werden THEN geschieht nichts und nichts stürzt (Test `withoutClosuresItIsSilentUnderTests`).
- [x] **AC-11:** Verdrahtungsregel: GIVEN `ClaudeSyncTrigger.forApp(account: nil, container:)` THEN ist das Ergebnis `nil`; GIVEN ein `AccountState` im Status `signedOut` mit einem gezählten Transport und `silent: false` (die echten Closures über `ClaudeSync`) THEN ist das Ergebnis ein Trigger, und nach `start()`, einer Aktivierung und einem `didSave` samt Entprellung hat der Transport keine einzige Anfrage erhalten (ohne Sitzung gibt `withSession` `nil`); mit `silent: true` ebenso (Test `wiringRuleNeedsAnAccount`).
- [x] **AC-12:** Nichts auf dem Netz ohne Konto und ohne Sitzung: GIVEN die Verdrahtung in `LooseEndsApp.init` WHEN der Quelltext durchsucht wird THEN steht `ClaudeSyncTrigger.forApp(` genau einmal in `LooseEnds/App/LooseEndsApp.swift`, `ClaudeSync(` kommt außerhalb von `ClaudeSyncTrigger.swift` und den Tests nicht vor, und `ClaudeSyncTrigger.swift` enthält weder `try?` noch `print(` (Quellsuche als Beleg im Abschlussbericht; kein Swift-Test).
- [x] **AC-13:** Ganze Suite grün: GIVEN die ganze Unit-Suite WHEN sie läuft THEN ist sie grün, und die App startet unter `--ui-testing` im Simulator ohne Absturz, mit Trigger gebaut und gestartet und ohne Netzverkehr (maschineller Beleg `./scripts/sim.sh test-proof <Klasse>` einer bestehenden Smoke-Klasse; Beleg im Abschlussbericht).
- [x] **AC-14:** Sendung während einer Sendung: GIVEN ein gestarteter Trigger, dessen `send` erst nach einer Verzögerung endet WHEN während dieses `send` dreimal `didSave` gepostet wird und die Entprellung abläuft THEN laufen nie zwei `send` gleichzeitig, und nach dem Ende des laufenden folgt genau ein weiteres `send`; wird statt `didSave` die Aktivierung gepostet, folgt ebenso genau ein weiteres `send` und erst danach `pull` (Test `saveDuringASendSendsOnceMoreAfterIt`).

## Dialog

### Runde 1
**Adversary:** Ich behaupte, die Reihung sei kaputt. Szenarien: (a) Speichern waehrend laufendem send, (b) Start/Vordergrund waehrend send, (c) Rueckkopplung pull -> didSave, (d) start() doppelt, (e) Beobachter ohne start, (f) Import-Uebersetzung (Fehler, Export, setup), (g) Fabrik ohne Konto/silent, (h) Actor-Isolation.
**Implementierer:** Belege aus dem Code, selbst gelesen:
Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:93
  Evidence: start() ruft sendThenPull(): pullAfterSend=true, requestSend; drain() sendet, dann pull genau einmal (Zeilen 131-140). Test testStartSendsThenPullsOnce, eigener Lauf 12/12 gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:131
  Evidence: pull steht in drain() nach der repeat-while-Schleife, also nach Ende von send; kein paralleler Task fuers Holen.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:68
  Evidence: guard !started verhindert zweite Beobachter und zweiten Start-Durchgang.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:71
  Evidence: didBecomeActive der Plattform (#if canImport(UIKit)/AppKit, Zeilen 23-29) -> sendThenPull().
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:109
  Evidence: sendSoon() bricht pending ab und startet neuen sleep(debounce); nur requestSend, nie pull. Fuenf Saves -> ein send.
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:113
  Evidence: Task.sleep(for: debounce) vor requestSend; ein neues didSave verschiebt es (cancel -> return im catch).
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:97
  Evidence: handle() prueft started und WidgetReload.isFinishedImport (WidgetReload.swift:74: imported, endDate != nil, errorMessage == nil); Regel nicht kopiert. Uebersetzung Zeilen 83-89: Export -> .exported, anderes -> .setup, succeeded==false -> errorMessage gesetzt; alle ergeben false.
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:70
  Evidence: Beobachter werden erst in start() registriert; handle() hat zusaetzlich guard started.
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:109
  Evidence: sendSoon/handle setzen pullAfterSend nie; nur sendThenPull (Start, Aktivierung) tut das. Rueckkopplung pull -> save -> didSave -> send (kein pull) schliesst sich nicht. ClaudeSync.sendTranscript speichert nicht (grep save() in ClaudeSync.swift ohne Treffer).
  Status: CONFIRMED
Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:44
  Evidence: init macht fehlende Closures zu leeren Aktionen; kein Standard auf echtes ClaudeSync.
  Status: CONFIRMED
Confirmation:
  AC: AC-11
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:56
  Evidence: guard let account else nil; silent -> Trigger ohne Closures (Zeile 59), sonst echte Closures. Test wiringRuleNeedsAnAccount (signedOut, gezaehlter Transport, silent false und true, 2,4 s Wartezeit) gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-14
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:122
  Evidence: requestSend: laeuft sending, nur sendAgain=true; drain wiederholt send solange sendAgain (sendAgain wird vor jedem send zurueckgesetzt, Aenderungen waehrend send loesen genau eine Wiederholung aus); sending=false ohne Suspension zwischen Schleifenende und Flag; pull erst danach. Test mit overlapped-Flag gruen.
  Status: CONFIRMED

### Runde 2
**Adversary:** Tiefer: (1) Rennen zwischen sending=false und pull: waehrend pull laeuft kann ein neuer drain senden -> send ueberlappt nie mit send, mit pull aber (erlaubt, busy faengt pull ab). (2) sendThenPull waehrend pull: zweites pull trifft busy, laut Spec ok. (3) Entprellungs-Task, der nach dem sleep schon in requestSend ist, wird von cancel nicht gestoert (kein Suspensionspunkt) - ein laufendes send wird nie abgebrochen. (4) weak self: drain haelt self stark waehrend des Laufs, danach frei; Beobachter [weak self]; kein Zyklus. Observer werden nie entfernt (kein deinit): harmlos, da weak, aber Leichen bleiben im Center (nur Tests, in der App lebt der Trigger so lang wie der Prozess). (5) Isolation: Closures mit queue .main und MainActor.assumeIsolated wie WidgetReload; der CloudKit-Zweig liest userInfo ausserhalb von assumeIsolated, nutzt dort nur Sendable-freie Werte (kein self), kompiliert unter Swift 6. (6) Log: nur Fallnamen, privacy public fuer Name und Art, kein Token/Gerät/Text.
**Implementierer:** Bestaetigt. Konto-Regel und Verdrahtung:
Confirmation:
  AC: AC-12
  Code reference: LooseEnds/App/LooseEndsApp.swift:63
  Evidence: Quellsuche: ClaudeSyncTrigger.forApp( steht in LooseEnds genau einmal (LooseEndsApp.swift:63; sonst nur Tests). ClaudeSync( ausserhalb der Trigger-Datei und der Tests: nur ClaudeSyncTrigger.swift:57. try? und print( in ClaudeSyncTrigger.swift: keine Treffer. Properties let claudeSync: ClaudeSyncTrigger? haelt den Trigger mit dem Prozess am Leben; start() nach forApp.
  Status: CONFIRMED
Confirmation:
  AC: AC-13
  Code reference: LooseEnds/App/LooseEndsApp.swift:17
  Evidence: Ganze Suite: docs/artifacts/feat-795-s3b-ausloeser/test-green-full-output.txt (0 failures). Eigener Lauf ClaudeSyncTriggerTests: 12 Tests, 0 Failures, EXIT=0 (adversary-test-output.txt). Smoke-Beleg InboxDrawerSmokeTests: Executed 1 test, 0 failures, "UI-Test bestanden, Beleg: ...simulator-run.txt" (smoke-test-proof-output.txt). Unter --ui-testing ist der Trigger gebaut, gestartet, stumm.
  Status: CONFIRMED
Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/Claude/ClaudeSyncTrigger.swift:35
  Description: Beobachter werden gespeichert, aber nie entfernt (kein deinit); in Tests bleiben tote Beobachter im NotificationCenter.
  Spec requirement: keine; Muster wie WidgetReload
  Conflict: kein Verstoss, weak self macht sie wirkungslos
  Remediation: optional deinit/stop() zum Entfernen

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: ClaudeSyncTriggerTests 12 passed, 0 failed; ganze Suite 0 failures; Smoke 1 passed
Edge cases: Reihung, Entprellung, Idempotenz, Rueckkopplung, Isolation geprueft, nichts gebrochen (nur F001 LOW)
Regressions: None found
Checklist: 14/14 points proven

## Geprüfte Dateien

- sha256:8ec78a61dd44ef80beba072749013ca9547cc6e03132344b2ff76983cef9e3d5  LooseEnds/App/LooseEndsApp.swift
- sha256:41ecb14884dd2daac1812b36707be86c2e533e78664c488df89bd6d194281927  LooseEnds/Claude/ClaudeSyncTrigger.swift

## Prüfbasis

- base: 36aac30375b718bdcdb22b90638b3b71744d1d18
- blob:6b680eee218f7a0e5b0212a5539b1f20d350be7a  LooseEnds/App/LooseEndsApp.swift
- blob:86256fa7f7a996616ce975de734a1bb3ca258a48  LooseEnds/Claude/ClaudeSyncTrigger.swift
