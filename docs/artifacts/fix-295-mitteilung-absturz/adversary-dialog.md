# Adversary Dialog — fix-295-mitteilung-absturz
Spec: docs/specs/fix-295-mitteilung-absturz.md
Datum: 2026-10-10 14:16

## Checkliste
- [x] **AC-1 Körper-Tipp:** Given die App ist geschlossen oder im Hintergrund und eine Fälligkeits-Mitteilung (Kategorie `DUE`) liegt vor / When der Nutzer den Mitteilungskörper antippt / Then öffnet sich die App ohne Absturz (`runningForeground`) und der Erfassungsknopf ist bedienbar.
- [x] **AC-2 Vordergrund:** Given die App ist geöffnet / When eine Fälligkeits-Mitteilung eintrifft / Then erscheint sie als Banner ohne Absturz und die App bleibt bedienbar.
- [x] **AC-3 Aktionsknöpfe:** Given eine Fälligkeits-Mitteilung / When der Nutzer „Erledigt“, „Als nächstes“ oder „Morgen“ wählt / Then läuft die Aktion durch dieselbe Rückruf-Methode wie AC-1; die Speichern-Logik ist durch die bestehenden `DueReminders`-Unit-Tests belegt, und der Systemabschluss wird erst **nach** `save()` auf dem Hauptthread aufgerufen (auch bei frühem Rücksprung in `apply`). Die Knöpfe selbst sind im UI-Test nicht bedienbar (Langdruck am Banner); der Körper-Tipp belegt den gemeinsamen Codeweg.
- [x] **AC-4 Schalter:** Given ein Start ohne `--ui-testing-notifications` (insbesondere Release/TestFlight) / When die App läuft / Then bleibt `suppressed` unter UI-Tests wirksam; nur `--ui-testing --ui-testing-notifications` setzt den Delegate im UI-Test. Der App-Code plant in keinem Fall eine Test-Mitteilung.
- [x] **AC-5 RED vor dem Fix:** Given der neue UI-Test `DueNotificationTapTests` mit eingespielter Mitteilung (`LOOSEENDS_PUSH`) / When er ohne den Fix läuft / Then stürzt die App ab und der Test schlägt fehl (Protokoll mit dem Absturz); nach dem Fix besteht er. Ohne `LOOSEENDS_PUSH_FEED` (CI) überspringt er sich.
- [x] **AC-6 Nichts sonst:** Diff berührt nur die genannten Dateien; `test-proof` ohne `LOOSEENDS_PUSH` verhält sich wie vorher; keine Änderung an Info.plist, Entitlements, AppStorage, Modell, `DueReminders`; alle bestehenden Unit- und UI-Tests grün.
- [ ] **AC-7 Gerät (steht aus, Gerätelauf nach PO-Freigabe „jetzt ist ein Test möglich“):** Nach Hennings ausdrücklicher Freigabe bestätigt der Prüfbau auf dem iPhone, dass das Antippen einer fälligen Mitteilung die App ohne Absturz öffnet; Henning bestätigt es nach Auslieferung im Alltag. #295 wird erst danach geschlossen.

## Dialog

### Runde 1
**Adversary:** Diff gelesen (nur LooseEnds/Notifications/DueNotificationCenter.swift: beide Delegate-Methoden auf Rückruf-Variante, async entfernt, keine Altvariante daneben).
Confirmation: AC: AC-1 | Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:112 | Evidence: didReceive ist nonisolated, zieht actionIdentifier/taskID synchron als String, Abschluss kommt aus `Task { @MainActor }` nach apply (Zeile 119-122). RED (red-crash.ips, SIGABRT in `@objc closure #1 in ...didReceive`) -> GREEN (2 von 2 bestanden, 0 übersprungen, simulator-run.txt). Screenshot opened-from-reminder (E42586E6): App im Vordergrund, Startscreen "All tied up." bedienbar; das Banner oben ist der nächste 5-s-Push, kein Absturz. Status: CONFIRMED
Confirmation: AC: AC-2 | Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:125 | Evidence: willPresent ruft completionHandler([.banner,.list,.sound]) synchron auf dem aufrufenden Strang. testBannerWhileAppIsOpenKeepsAppAlive grün; Screenshot reminder-in-front (448EF7A7): Banner über bedienbarem Startscreen. Status: CONFIRMED
Confirmation: AC: AC-3 | Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:120 | Evidence: Gleiche Methode für alle Aktionen. Früher Rücksprung: der guard in apply (Zeile 130) ist ein `return` innerhalb von apply, der Abschluss steht danach in der Task, also genau einmal auch bei unbekannter Aktion/fehlender taskID (der Testfall selbst: Default-Aktion + nicht vorhandene Aufgaben-ID läuft genau diesen Weg). apply ist nicht-werfend (do/catch intern), kein Pfad ohne Abschluss, kein Doppelaufruf. Status: CONFIRMED (Knopfpfad selbst nicht UI-getestet, laut Spec akzeptiert)
Confirmation: AC: AC-4 | Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:16 | Evidence: suppressed = isRunningTests || (isUITesting && !isNotificationUITest); Test-Flag nur zusammen mit --ui-testing. Im App-Code kein add einer Test-Mitteilung (request(for:) nur aus reschedule). Status: CONFIRMED
Confirmation: AC: AC-5 | Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:112 | Evidence: test-red-output.txt: 2 Tests, 1 Failure (Tipp-Test), Absturzbericht auf didReceive; Skip ohne LOOSEENDS_PUSH_FEED in DueNotificationTapTests.setUpWithError. Status: CONFIRMED
Confirmation: AC: AC-6 | Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:105 | Evidence: Diff gegen Basis: nur DueNotificationCenter, UI-Test, sim.sh (+12, nur unter if LOOSEENDS_PUSH), Fixture, Doku/Artefakte; keine Info.plist/Entitlements/Modell/DueReminders. Eigener sim-unit-Lauf: rc=0, 7 XCTest + Swift Testing, 0 Fehler (adversary-test-output.txt); Messberichte danach zurückgesetzt. UI-Gesamtsuite nicht von mir neu gefahren.
Angriff auf die Selektor-Erkennung: Build-Log xcodebuild.log hat 0 Warnungen (kein "nearly matches"); `strings` im LooseEnds.debug.dylib zeigt beide Selektoren `userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:` und `…willPresentNotification:withCompletionHandler:`.
Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:112
  Description: Der grüne Lauf belegt nicht direkt, dass didReceive aufgerufen wurde. Der Test prüft nur "App lebt nach Tipp"; ohne Delegate-Aufruf wäre er auch grün. Indirekter Beleg: derselbe Test war im RED-Lauf rot durch Absturz in genau dieser Methode, Selektor im Binary, keine Warnung.
  Spec requirement: AC-1, AC-5 — Antippen öffnet ohne Absturz; Test belegt den Weg
  Conflict: Kein positiver Beleg des Aufrufs (kein Log, kein Test-Hook); Lücke, kein nachgewiesener Fehler.
  Remediation: Optional Logger-Eintrag in didReceive und im Simulator-Log zitieren, oder Lücke im Abschlussbericht nennen; AC-7 schließt sie.
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:119
  Description: completionHandler wird erst nach `await reschedule()` aufgerufen (bei Knöpfen: save + mehrere add). Theoretisch könnte ein langsamer Abschluss das Zeitfenster des Systems reißen; beim Körper-Tipp endet apply sofort. Nicht als Problem belegt.
  Spec requirement: AC-3 — Abschluss erst nach save()
  Conflict: Spec fordert diese Reihenfolge; Risiko nur theoretisch.
  Remediation: Keine nötig; im Gerätelauf mit Knopf beobachten.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Zweiter Angriff gegen Frühkonvergenz. (a) Doppelaufruf: ein Task je Delegate-Aufruf, ein completionHandler am Ende. (b) taskID fehlt oder kein UUID: `as? String` ergibt nil, apply kehrt über guard zurück, Abschluss trotzdem. (c) Swift 6: `@Sendable` nötig; ObjC-Selektoren unverändert, Build ohne Warnungen. (d) willPresent: Handler synchron aufgerufen, kein Threadwechsel. (e) Regression: apply private, Aufrufer unverändert. (f) Mehrere schnelle Tipps: Tasks laufen seriell auf dem Hauptakteur, mainContext, kein Datenrennen. (g) Screenshots angesehen und beschrieben. (h) Beide UI-Tests ohne Überspringen. Kein weiterer Bruch gefunden.
Code reference: LooseEnds/Notifications/DueNotificationCenter.swift:104
**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS

Begründung: AC-1 bis AC-6 belegt (UI 2/2 grün, 0 übersprungen; Unit-Lauf grün; kein Bruch). AC-7 (Gerät) steht aus, Gerätelauf nach PO-Freigabe. AMBIGUOUS statt VERIFIED wegen F001 (didReceive-Aufruf im grünen Lauf nur indirekt belegt) und offenem AC-7. Keine Spec-Verletzung gefunden.

## Geprüfte Dateien

- sha256:67d8e39e47f87c906bdd0e7a9bba310b1dcc579edb7fa1ce3cf27eaf1283f2bc  LooseEnds/Notifications/DueNotificationCenter.swift
