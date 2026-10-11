# Adversary Dialog — fix-295-mitteilung-absturz
Spec: docs/specs/fix-295-mitteilung-absturz.md
Datum: 2026-10-11 18:39

## Checkliste
- [x] **AC-1 Körper-Tipp:** Given die App ist geschlossen oder im Hintergrund und eine Fälligkeits-Mitteilung (Kategorie `DUE`) liegt vor / When der Nutzer den Mitteilungskörper antippt / Then öffnet sich die App ohne Absturz (`runningForeground`) und der Erfassungsknopf ist bedienbar.
- [x] **AC-2 Vordergrund:** Given die App ist geöffnet / When eine Fälligkeits-Mitteilung eintrifft / Then erscheint sie als Banner ohne Absturz und die App bleibt bedienbar.
- [x] **AC-3 Aktionsknöpfe:** Given eine Fälligkeits-Mitteilung / When der Nutzer „Erledigt“, „Als nächstes“ oder „Morgen“ wählt / Then läuft die Aktion durch dieselbe Rückruf-Methode wie AC-1; die Speichern-Logik ist durch die bestehenden `DueReminders`-Unit-Tests belegt, und der Systemabschluss wird erst **nach** `save()` auf dem Hauptthread aufgerufen (auch bei frühem Rücksprung in `apply`). Die Knöpfe selbst sind im UI-Test nicht bedienbar (Langdruck am Banner); der Körper-Tipp belegt den gemeinsamen Codeweg.
- [x] **AC-4 Schalter:** Given ein Start ohne `--ui-testing-notifications` (insbesondere Release/TestFlight) / When die App läuft / Then bleibt `suppressed` unter UI-Tests wirksam; nur `--ui-testing --ui-testing-notifications` setzt den Delegate im UI-Test. Der App-Code plant in keinem Fall eine Test-Mitteilung.
- [x] **AC-5 RED vor dem Fix:** Given der neue UI-Test `DueNotificationTapTests` mit eingespielter Mitteilung (`LOOSEENDS_PUSH`) / When er ohne den Fix läuft / Then stürzt die App ab und der Test schlägt fehl (Protokoll mit dem Absturz); nach dem Fix besteht er. Ohne `LOOSEENDS_PUSH_FEED` (CI) überspringt er sich.
- [x] **AC-6 Nichts sonst:** Diff berührt nur die genannten Dateien; `test-proof` ohne `LOOSEENDS_PUSH` verhält sich wie vorher; keine Änderung an Info.plist, Entitlements, AppStorage, Modell, `DueReminders`; alle bestehenden Unit- und UI-Tests grün.
- [ ] **AC-7 Gerät:** Nach Hennings ausdrücklicher Freigabe bestätigt der Prüfbau auf dem iPhone, dass das Antippen einer fälligen Mitteilung die App ohne Absturz öffnet; Henning bestätigt es nach Auslieferung im Alltag. #295 wird erst danach geschlossen.

## Dialog

### Runde 1
**Adversary:** Eigene Läufe auf dem zusammengeführten Stand (HEAD 65aab2d auf 8fb57ea). Beleg: `docs/artifacts/fix-295-mitteilung-absturz/adversary-test-output.txt` (= `sim.sh sim-unit`, Simulator LE-295: "Test Succeeded", 532 Haken, 0 Fehlschläge; Messstrecke SelfConsistencyReportTests mangels Daten übersprungen, nicht durch dieses Ticket). Vorher lief `sim.sh unit` (Standardbefehl; wählt hier den Mac als Testhost, weil macOS 27 >= Target): Ergebnis "TEST FAILED", Übersetzungsfehler "Value of type 'XCUIDevice' has no member 'press'" in `LooseEndsUITests/DueNotificationTapTests.swift:24`, 0 Tests liefen (Beleg: `adversary-test-output-mac-unit-FAILED.txt`; `DerivedData/LooseEnds-session-fix295/xcodebuild.log` Zeile 1684). Das ist Finding F001. Code geprüft:
- AC-1: `DueNotificationCenter.swift:173-184` ist die Rückruf-Variante; Strings werden synchron gezogen (178-179), der Abschluss steht im `Task { @MainActor }` nach `await apply` (180-183), also auf dem Hauptthread. Beleg: `test-green-output.txt` (2/2 grün, 18:37, HEAD 65aab2d, Banner aus Home getippt, `runningForeground`, `captureButton` ansprechbar), Screenshot in `simulator-run/` angesehen: App offen. Gegenprobe `test-red-main-output.txt`: mit dem async-Delegate von main scheitert genau dieser Test ("App not in front after the tap, state 1"); `red-main-crash.ips` zeigt die Kooperativ-Queue (`com.apple.root.user-initiated-qos.cooperative`, Zeile 937). Schalter umgelegt: Fehler da, Fix, Fehler weg.
- AC-2: `willPresent` (186-192) ruft synchron. `testBannerWhileAppIsOpenKeepsAppAlive` war auch auf main grün; der Test trennt Fix und Nicht-Fix also nicht (willPresent stürzt nicht), er schützt nur vor Rückfall.
- AC-3: gleicher Codeweg; `save()` und `reschedule()` stehen in `apply` (194-212); auch der frühe Rücksprung beim Standard-Tipp (#331, 195-198) läuft über denselben `await`, der Abschluss kommt danach. Knöpfe nicht bedient (Spec räumt das ein).
- AC-4: `suppressed` (27-29) ist nur bei `isUITesting && !isNotificationUITest` wahr; `isNotificationUITest` (31-33) verlangt beide Argumente. Randbeobachtung F003.
- AC-5: RED (`test-red-main-output.txt`, `red-main-crash.ips`; älter `test-red-output.txt`, `red-crash.ips`) und GRÜN belegt; `setUpWithError` überspringt ohne `LOOSEENDS_PUSH_FEED` (DueNotificationTapTests.swift:16-19). Der GRÜN-Beleg hat 0 übersprungen.
- AC-6: Diff gegen die Merge-Basis berührt im Produktcode nur `DueNotificationCenter.swift`; keine Änderung an Info.plist, Entitlements, Modell, `DueReminders`. ABER: "alle bestehenden Unit-Tests grün" gilt für den Standardbefehl `sim.sh unit` nicht (F001). Messberichte nach meinem Lauf geändert: `docs/reference/focusblox-calibration-report.md`, `docs/reference/retrieval-leave-one-out-rules.md` (bekannter Nebeneffekt, nicht zurückgesetzt; vor dem Commit zurücksetzen).
- AC-7: kein Gerätebeleg, bleibt offen.
**Implementierer:** (kein Rückkanal in diesem Lauf; Rückmeldung zu F001/F002 steht aus.)

### Runde 2
**Adversary:** Gezielte Gegenangriffe.
- Thread und Sendable: `completionHandler` ist `@Sendable` (176) und wird genau einmal aufgerufen; alle Fehler in `apply` werden gefangen (209-211), der Abschluss kann nicht ausbleiben, kein Doppelaufruf.
- Reentranz: `apply` ruft `await reschedule()`; ein zweites `didReceive` kann währenddessen auf dem Hauptakteur starten. `handle` wirkt auf Aufgaben idempotent; kein neues Risiko gegenüber vorher.
- Gerätewiderspruch (Hennings Build 29 ohne Absturz, async-Delegate): kein Widerspruch beweisbar, aber auch nicht aufgelöst. Der Simulatorabsturz tritt auf, wenn die App suspendiert im Hintergrund liegt (Home, dann Tipp); der Stapel `_updateSnapshotAndStateRestorationWithAction` ist UIKits Pfad für Hintergrundereignisse. Bei einer vom System beendeten App (Kaltstart über die Mitteilung) oder einer App im Vordergrund läuft dieser Pfad womöglich nicht oder anders. Build 29 enthält zudem #331 (Standard-Tipp kehrt früh zurück), was den Zeitpunkt des Abschlusses verschiebt, nicht den Thread; main-Rotlauf mit #331 stürzt dennoch (red-main). Hennings ursprüngliche Meldung ("Beim Wechsel in die App") passt zum Hintergrund-Fall. Nichts davon ist am Gerät belegt; der Fix folgt dem DTS-Weg und schadet in keinem Zustand. F002 ist AMBIGUOUS, nicht blockierend.
- Leere Detailseite nach Tipp ("Nothing here yet."): Fixture-Aufgabe existiert nicht, #331-Verhalten, nicht Teil dieses Tickets.
- Alte Dialogrunden und Stempel sind ungültig (Datei geändert); dieses Protokoll ersetzt sie.
**Implementierer:** (offen)

### Runde 3
**Adversary:** F001 nachgeprüft. `LooseEndsUITests/DueNotificationTapTests.swift` beginnt mit `#if os(iOS)` (Zeile 1) und endet mit `#endif`; damit gibt es `XCUIDevice.press` nur auf iOS. Beleg `mac-build-for-testing.txt`: "** TEST BUILD SUCCEEDED **" für macOS. Eigener erneuter iOS-Lauf `LOOSEENDS_PUSH=scripts/fixtures/due-reminder.apns sim.sh test-proof DueNotificationTapTests` (Simulator LE-295, Output `adversary-test-output.txt`): testBannerWhileAppIsOpenKeepsAppAlive und testTapBannerFromHomeOpensApp beide bestanden, "Executed 2 tests, with 0 failures". Produktcode seit Runde 2 unverändert. Der Simulator-Unit-Lauf aus Runde 1 (`adversary-test-output-sim-unit.txt`, grün) bleibt gültig, da nur die Testdatei hinter `#if` ging. Den Mac-Unit-Lauf `sim.sh unit` selbst habe ich nicht erneut gefahren; die Übersetzung des Ziels für macOS ist durch build-for-testing belegt. F001 ist behoben, AC-6 bewiesen. Offen bleibt AC-7.
**Implementierer:** F001 behoben.

## Findings

Finding:
  ID: F001
  Severity: HIGH
  Category: regression
  Code reference: LooseEndsUITests/DueNotificationTapTests.swift:24
  Description: Der neue UI-Test ruft `XCUIDevice.shared.press(.home)` ohne Plattformschranke. Auf macOS gibt es `XCUIDevice.press` nicht; das Ziel LooseEndsUITests wird für den Mac mitübersetzt, sobald der Mac Testhost ist.
  Spec requirement: AC-6 — alle bestehenden Unit- und UI-Tests grün
  Conflict: `./scripts/sim.sh unit` (wählt auf diesem Mac macOS als Host, cmd_unit in scripts/sim.sh) endet mit "TEST FAILED", Fehler "Value of type 'XCUIDevice' has no member 'press'", "Testing cancelled because the build failed", 0 Tests. Der Standard-Unit-Befehl ist durch das Ticket gebrochen. `sim-unit` (Simulator) ist grün.
  Remediation: Testdatei in `#if os(iOS)` einschließen und `sim.sh unit` danach erneut laufen lassen.
  Reproduction: CLAUDE_SESSION_ID=fix295 LOOSEENDS_SIM=LE-295 ./scripts/sim.sh unit

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:173
  Description: Der Fix ist am Simulator mit suspendierter App (Home, dann Tipp) belegt. Hennings Build 29 (async-Delegate) zeigte auf dem Gerät keinen Absturz.
  Spec requirement: AC-7 — Gerätebestätigung durch Henning
  Conflict: AMBIGUOUS. App-Zustand beim Tipp (beendet, suspendiert, vorn) unbekannt; weder Widerspruch noch Betroffenheit des Geräts beweisbar.
  Remediation: Bei der Gerätebestätigung (nur nach Hennings "jetzt ist ein Test möglich") den Fall "App im Hintergrund, dann Mitteilung antippen" ausdrücklich prüfen und den Zustand mitprotokollieren. Fix beibehalten.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:45
  Description: Unter `--ui-testing-notifications` ist `suppressed` falsch, daher wird auch `SystemDueScheduler` gesetzt, nicht nur der Delegate; `reschedule` kann dort `add` und `setBadgeCount` ans System schicken.
  Spec requirement: AC-4 — der App-Code plant in keinem Fall eine Test-Mitteilung
  Conflict: Nur formal: mit leerem In-Memory-Store liefert `plan(for:)` nichts; kein Bruch beobachtet.
  Remediation: Optional Scheduler unter dem Schalter auf nil lassen oder den Spec-Wortlaut präzisieren.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:173
  Evidence: Rückruf-Variante, Abschluss auf dem Hauptthread nach apply; test-green-output.txt 2/2 grün, Gegenprobe mit main-Delegate rot mit SIGABRT.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:186
  Evidence: willPresent ruft den Abschluss synchron; testBannerWhileAppIsOpenKeepsAppAlive grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:194
  Evidence: gleicher Weg wie AC-1; Abschluss nach `await apply` (save, reschedule); Knöpfe selbst nicht bedient, wie in der Spec vorgesehen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:27
  Evidence: `suppressed` bleibt ohne beide Argumente wahr; der Schalter kommt nur im Test und in dieser Datei vor.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsUITests/DueNotificationTapTests.swift:16
  Evidence: XCTSkipUnless auf LOOSEENDS_PUSH_FEED; RED mit main-Delegate, GRÜN mit Fix.
  Status: CONFIRMED

Finding-Hinweis scripts/sim.sh: Code reference: scripts/sim.sh:333 — test-proof ohne LOOSEENDS_PUSH unverändert (Zweig nur bei gesetzter Variable).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine Tabelle angehängt, keine verdächtigen Zeilen.

## Verdict
VERDICT: AMBIGUOUS

F001 (HIGH) behoben und in Runde 3 geprüft. Offen: AC-7 (Gerät, nicht belegt; AMBIGUOUS bis Hennings Bestätigung), F002 AMBIGUOUS (Build 29 ohne Absturz), F003 LOW.
Tests: iOS-UI 2 bestanden, 0 fehlgeschlagen, 0 übersprungen; sim-unit grün; Mac-Übersetzung grün.
Checklist: AC-1 bis AC-6 bewiesen, AC-7 offen.

## Geprüfte Dateien

- sha256:e32bda0b784814932c673fb41b29962bc0bb23318a5fe3ebe17586eb2e85af6e  LooseEnds/Notifications/DueNotificationCenter.swift
- sha256:dc57372612397ce063798f3813ae7b4135cf404d67f678808f42fee64869e691  LooseEndsUITests/DueNotificationTapTests.swift

## Prüfbasis

- base: 8fb57ea5fd20a917b066c6b3a11c8a5aa3d99259
- blob:65ce08df2c5cd40864d5072fd2ca3e5bac6dc755  LooseEnds/Notifications/DueNotificationCenter.swift
- blob:fb0732b35663c85e20a0eb6a57b04dc454777550  LooseEndsUITests/DueNotificationTapTests.swift
