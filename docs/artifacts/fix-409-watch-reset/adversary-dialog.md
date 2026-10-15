# Adversary Dialog — fix-409-watch-reset
Spec: docs/specs/intents/fix-409-watch-reset.md
Datum: 2026-10-15

## Checkliste
- [x] **AC-1:** Bestätigung ~1,5 s, dann leeres Feld, ohne Tipp — Beweis: Runde 3: drei Läufe nacheinander (je kalter Erststart), je 2/2 grün per xcresulttool (Passed, 0 fehlgeschlagen, 0 übersprungen), Beleg `simulator-run.txt` (Apple Watch Series 12, watchOS 27.0); Zusicherungen in Test 1 (Zeilen 25–31) gegen HEAD unverändert; RED davor belegt (`test-red-output.txt:458` „Feld kommt nach „Milch kaufen“ nicht zurück“); Screenshots in Runde 3 geöffnet: „Gespeichert“ mit Häkchen (Uhr 13:24), danach leeres Feld „Ich höre zu“ + „Fertig“ + „0.1.0 (1)“.
  Code reference: LooseEndsWatch/WatchCaptureView.swift:32
- [x] **AC-2:** Bestätigung sichtbar, Feld noch nicht — Beweis: Runde 4: `testConfirmationIsVisibleBeforeFieldReturns` liest mit einem `app.snapshot()` je Schleifendurchlauf beide Tatsachen im selben Abbild (`contents(of:)`, Testdatei Zeilen 41–67): Bestätigung (Identifier `watch.capture.saved` oder Label Saved/Gespeichert, Typ staticText) UND kein `textField`; Schleife bis Bestätigung gesehen oder 5 s. Das Abbild entsteht nach dem Fertig-Tipp (Aufruf folgt `capture()`); ein Abbild ohne Bestätigung führt nur zum nächsten Durchlauf bzw. nach 5 s zu Rot. 3/3 Läufe grün (2/2 je Lauf); Abbild in run-r3 innerhalb 0,41 s nach dem Tipp. Strenger als vorher (atomar statt zwei Abfragen). F002 behoben.
  Code reference: LooseEndsUITests/Watch/WatchCaptureUITests.swift:32
- [x] **AC-3:** Zweite Aufgabe direkt erfassbar — Beweis: derselbe Test erfasst „Milch kaufen“ und „Brot holen“ hintereinander, „Gespeichert“ erscheint je Erfassung (nur nach erfolgreichem `CaptureService.save`, Zeile 49 vor 51).
  Code reference: LooseEndsWatch/WatchCaptureView.swift:49
- [x] **AC-4:** Fehlerfall unverändert — Beweis: Code-Review: `text = ""` und `saved = true` stehen nach `try CaptureService.save` im do-Zweig (50–51); catch (52–55) setzt nur `saveFailed`; `text` bleibt, kein `saved`, kein Task-Start. Nicht per Test auslösbar (laut Spec).
  Code reference: LooseEndsWatch/WatchCaptureView.swift:52
- [x] **AC-5:** Hintergrund während 1,5 s — Beweis: Code-Review: `.task(id: saved)` hängt am VStack, das bei Hintergrund nicht abgebaut wird; `Task.sleep(for:)` nutzt `ContinuousClock` (zählt Anhalten mit, Frist verstreicht); Abbruch → `catch { return }` ohne Zuweisung (37–39); nur ein vollendeter Schlaf setzt `saved = false` (40); bei `saved == false` kehrt die Task per `guard` sofort zurück (34), also genau ein Reset je `true`-Wert. Doppeltipp auf „Fertig“ unmöglich (Knopf verschwindet mit `saved`, vorher leer = disabled).
  Code reference: LooseEndsWatch/WatchCaptureView.swift:36
- [x] **AC-6:** Kein Auto-Fokus — Beweis: Test prüft nach jedem Reset `sheetDone.exists == false` (grün); Code hat kein `@FocusState`/Fokussetzung. Prüfung schwach (F003), nicht abgeschwächt; Screenshot „leeres Feld“ (Runde 3 geöffnet) zeigt kein Eingabeblatt; in den xcresults gibt es nach dem Reset keinen Tipp auf das Feld, bevor der Test ihn selbst auslöst.
  Code reference: LooseEndsUITests/Watch/WatchCaptureUITests.swift:26
- [x] **AC-7:** Testaufbau — Beweis: project.yml:326 Ziel `LooseEndsWatchUITests` (platform watchOS, `TEST_TARGET_NAME: LooseEndsWatch`), Schema `LooseEndsWatch` (project.yml:349–355); sim.sh:104–117 `sim_id` mit Plattform-Parametern (iOS-Aufruf unverändert über `SIM_OS=iOS`, `SIM_FAMILY=iPhone`), sim.sh:349 Deinstallation nur wenn `WATCH_APP_ID` gesetzt (nur in `cmd_watch_test_proof` gesetzt, 365–368, kein Leck in den iOS-Weg), sim_proof.py:55 watchOS-Gerätebeschriftung. Eigener grüner `watch-test-proof`-Lauf mit Beleg „geraet: Apple Watch Series 12, watchOS 27.0“, 2/2. Skripttests `test_sim_proof test_ci_xcode27 test_entitlements_sync`: 35 OK.
  Code reference: project.yml:326
  Code reference: scripts/sim.sh:365
  Code reference: scripts/sim_proof.py:55
- [x] **AC-8:** Gerätepunkt (Stufe 3) — Beweis: Henning hat TestFlight-Build 64 (PR #451, b9bd752) auf seiner Watch geprüft und am 2026-10-15 auf die Frage „Wie verhält sich die Watch-Erfassung mit Build 64?“ mit „Funktioniert“ geantwortet (Option: kurz „Gespeichert“, dann leeres Feld, zweite Aufgabe ging direkt, beide auf dem iPhone). Kein Gerätezugriff durch mich.
  Code reference: LooseEndsWatch/WatchCaptureView.swift:32
- [x] **AC-9:** Bestehendes grün — Runde 3 unabhängig nachgeprüft: `sim.sh test CaptureSmokeTests` 17/17 grün (smoke.log: „Executed 17 tests, with 0 failures“, „UI-Test bestanden“); `sim-unit` per xcresulttool aus Test-LooseEnds-2026.10.15_11-47-05: 644 gesamt, 641 bestanden, 0 fehlgeschlagen, 3 übersprungen, Ergebnis Passed. Die 3 einzeln: `SelfConsistencyReportTests` (Messdatei fehlt), `Speech latency (#274)/The first word arrives within 3 s of speech start`, `…/The final text keeps the key words` (Ticket #419, unabhängig von #409). Skripttests `test_sim_proof` 14 OK. Hinweis: Lauf lag vor der Testdatei-Änderung 13:05; die Watch-Testdatei ist im iOS-Ziel per Exclude `Watch/**` ausgeschlossen, `WatchCaptureView.swift` (Watch-Ziel) unverändert seit dem Lauf.
  Code reference: project.yml:315

## Dialog

### Runde 1
**Adversary:** Beweise selbst angesehen, nicht geglaubt: Diff gelesen, Spec gelesen, Skripttests (35 OK), Watch-Lauf selbst wiederholt (2/2 grün, Beleg neu erzeugt, Hash von WatchCaptureView/Test unverändert), Screenshots geöffnet (Häkchen + „Gespeichert“; danach leeres Feld „Ich höre zu“, Fertig). RED-Beleg gegengelesen (1 von 2 rot am richtigen Grund). Weil alles auf Anhieb passt, gezielt gebohrt: (a) Text nur aus Leerzeichen → Knopf `.disabled` (WatchCaptureView.swift:25), kein Save. (b) Doppeltipp „Fertig“ → nach erstem Tipp `saved = true`, Knopf aus dem Baum. (c) `saved`-Wechsel während laufender Task → nicht möglich, Feld fehlt im Zustand `saved`; `task(id:)` bricht bei Wechsel ab, der catch-Zweig setzt nichts. (d) sim.sh iOS-Weg: `SIM_OS`/`SIM_FAMILY` Standard iOS/iPhone, `WATCH_APP_ID` nur in der Watch-Funktion gesetzt (Leck nur, wenn der Nutzer die Variable exportiert: harmlos). (e) project.yml-Exclude: iOS-Ziel baut und linkt weiterhin.
**Implementierer:** (Kontext isoliert, keine Antwort erhalten; Befunde unten)

### Runde 2
**Adversary:** Nachbohren an Testgüte und Randfällen. (1) `sheetDone = navigationBars.buttons.element(boundBy: 1)` hat im Hauptbild keine Navigationsleiste, `exists` ist dort immer false; der AC-6-Test belegt „kein Eingabeblatt“ nur schwach (F003). (2) AC-2 ist zeitabhängig: Feld-Fehlen wird nach `waitForExistence` abgefragt, die 1,5-s-Frist ist knapp gegenüber der Abfragelatenz von XCUITest; unter Last kann der Test flackern (F002). (3) Test ohne `@MainActor`: ~20 Swift-6-Isolationswarnungen im Watch-Bau (F001). (4) Spec nennt `LooseEndsWatchUITests/WatchCaptureUITests.swift`, tatsächlich liegt der Test in `LooseEndsUITests/Watch/` (mit Exclude, in project.yml begründet) (F005). (5) `Task.sleep(for:)` → ContinuousClock: Anhalten zählt mit, AC-5 hält. (6) Beleg `simulator-run.txt` verlor beim Neulauf den Block „Geprüfte Dateien“ (nur Hinweis, wird beim Registrieren neu angehängt). (7) AC-9: Lauf des iOS-UI-Ziels und sim-unit konnten wegen Systemlast nicht beendet werden (F004).
**Implementierer:** (keine Antwort; Befunde zur Bewertung durch den Auftraggeber)

### Runde 3
**Adversary:** Neue Beweise selbst geprüft, nichts geglaubt.
(1) F001: Diff gelesen; jede Testmethode und jeder Helfer trägt `@MainActor`, die Klasse selbst nicht, `setUp()` setzt nur `continueAfterFailure`. In `watch-1.log` und `watch-3.log` keine Warnung zu `WatchCaptureUITests.swift` (0 Treffer). F001 behoben.
(2) Keine Zusicherung abgeschwächt: Die Aussagen von AC-1 (Bestätigung, Feld zurück, Bestätigung weg, Feldwert enthält den Text nicht), AC-2 (Bestätigung da, Feld nicht da) und AC-6 (`sheetDone.exists == false`) stehen wörtlich unverändert, nur mit `in: app` parametrisiert. Neu und strenger: `waitForNonExistence` des Eingabeblatts, Fokus per `hasKeyboardFocus`, Knopf „Fertig“ muss enabled+hittable sein, bevor getippt wird (belegt zusätzlich, dass der Text angekommen ist). Die Wartezeiten der Prüfungen blieben bei 5 s.
(3) Drei Läufe aus den xcresults (xcresulttool summary): run-1, run-2, run-3 je Passed, 2 bestanden, 0 fehlgeschlagen, 0 übersprungen. Aktivitäten ausgewertet (`get test-results activities`): in allen sechs Testdurchläufen gibt es je Erfassung genau einen „Tap watch.capture.field“; der zweite Tipp in `openInputSheet` wurde nie ausgelöst, also kein Hinweis auf einen verschluckten Tipp. Lauf 1 war unter Last langsam (zweiter Test: 114 s Wartezeit beim Start, Gesamtdauer 165 s), blieb aber grün.
(4) Screenshots geöffnet: „gespeichert Milch kaufen“ zeigt grauen Kreis mit Häkchen und fettem „Gespeichert“ auf Schwarz (Uhr 13:24); „leeres Feld nach Brot holen“ zeigt das leere Feld mit Platzhalter „Ich höre zu“, Knopf „Fertig“ und „0.1.0 (1)“, kein Eingabeblatt. Zeitstempel im Manifest: 1,1 s zwischen beiden Aufnahmen (Milch), 1,2 s (Brot), passt zur 1,5-s-Frist inklusive Screenshot-Aufwand.
(5) F002 nachgemessen: Im Test `testConfirmationIsVisibleBeforeFieldReturns` lagen zwischen dem Synthetisieren des Fertig-Tipps und der Existenzprüfung der Bestätigung 2,6 s (Lauf 2: Tipp 18,05 s, Prüfung 20,62 s), 1,5 s (Lauf 3) und 2,0 s (Lauf 1); danach kam die Feldprüfung 0,07 s später und meldete trotzdem „Feld fehlt“. Das ist nur durch Schnappschuss-Zeitpunkt der XCUITest-Abfrage erklärbar (Abfrage vor dem Reset), nicht durch Abstand zur Frist: die Zusicherung hat keine harte Marge. Die Härtung hat F002 nicht entschärft; dass 3/3 grün sind, beweist keine Robustheit. Bleibt offen, MEDIUM, laut Spec Known Risk 3 bekannt.
(6) AC-9: smoke.log und xcresult des sim-unit-Laufs selbst gelesen (Zahlen siehe Checkliste), die drei Übersprungenen per xcresulttool einzeln benannt: wie erwartet. F004 behoben.
(7) AC-8 bleibt offen: Spec verlangt Hennings Rückmeldung zum TestFlight-Bau nach seinem „jetzt ist ein Test möglich“. Kein Gerätezugriff, nichts erfunden. Ein offenes AC hält laut Gate das Urteil auf AMBIGUOUS, bis Henning den Override setzt (Geräte-ACs nachgelagert).
**Implementierer:** (keine Antwort; Bewertung durch den Auftraggeber)

### Runde 4
**Adversary:** Nur die Teständerung geprüft, Belege selbst gelesen, keine Läufe gestartet.
(1) Diff gelesen: `contents(of:)` durchläuft den Baum des Abbilds iterativ; Bestätigung = staticText mit Identifier `watch.capture.saved` oder Label Saved/Gespeichert (App-Code setzt den Identifier, WatchCaptureView.swift:18), Feld = beliebiger `textField`. Die Schleife nimmt Abbilder, bis die Bestätigung da ist oder 5 s um sind; erst danach zwei Zusicherungen auf demselben Abbild.
(2) Mindestens so streng wie vorher? Ja: gleiche zwei Aussagen (Bestätigung da, Feld nicht da), nun atomar. Fälschlich grün: (a) Abbild vor dem Tipp unmöglich, der Aufruf folgt `capture()`, das mit dem Tipp auf Fertig endet, und vor dem Tipp gibt es keine Bestätigung; (b) Bestätigung nur über Label: Identifier oder Label, beides aus der App; ein Fremdtext „Gespeichert“ im Eingabeblatt wäre nur solange denkbar, wie das Blatt offen ist, `capture()` wartet aber auf `waitForNonExistence` des Blatts; (c) Textfeld im Eingabeblatt: würde als Feld gezählt, also rot, nicht grün; (d) Abbild ohne Bestätigung und ohne Feld (Übergang) führt nicht zu grün, sondern zum nächsten Durchlauf bzw. nach 5 s zu Rot. Einzige Lücke: ein Feld, das der Baum nicht als `textField` liefert, bliebe unbemerkt; die übrigen Tests fragen dasselbe Element über `app.textFields` ab, und der RED-Beleg (Feld zurück) lief über denselben Typ, daher akzeptiert.
(3) Belege: run-r1..r3 je 2 Tests, 0 Fehler (watch-r*.log „Executed 2 tests, with 0 failures“). Aktivitäten von run-r3: Tipp auf Fertig 70976.509, Test-Ende 70976.916, also Abbild innerhalb 0,41 s, passt zu den genannten 0,31 s. Normale Last, große Marge zur 1,5-s-Frist.
(4) Lastserie: Fehler liegen in `openInputSheet` (Fokus, testmanagerd) und beim Warten auf den Fertig-Knopf in `capture()`, beide vor der neuen Prüfung; die Änderung betrifft sie nicht. Als F006 (LOW) festgehalten.
(5) AC-6/AC-1: Test 1 und `capture()` unverändert (Zusicherungen wörtlich wie in Runde 3); AC-6-Schwäche F003 bleibt. Produktcode WatchCaptureView.swift unverändert (sha256 ee69e583…). Das RED-Log des Rotlaufs vor der Änderung liegt nicht mehr vor; ich stütze mich dafür nur auf die Zeitstempel im Auftrag.
(6) Swift 6: `contents(of:)` und der Test sind `@MainActor`; 0 Treffer für `WatchCaptureUITests.swift` in watch-r1..3.log. `try app.snapshot()` wirft in den Test (kein `try?`), kein `try?` in der Datei.
(7) AC-8 bleibt offen: laut Spec erst nach Hennings TestFlight-Rückmeldung. Nichts erfunden.
**Implementierer:** (keine Antwort; Bewertung durch den Auftraggeber)

## Befunde

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Status: BEHOBEN in Runde 3 (`@MainActor` an allen Methoden, keine Warnung im Watch-Bau)
  Code reference: LooseEndsUITests/Watch/WatchCaptureUITests.swift:11
  Description: Klasse und Testmethoden haben kein `@MainActor`; der Watch-Bau meldet ~20 Isolationswarnungen (Zeilen 11–43), iOS-UI-Tests nutzen `@MainActor`.
  Spec requirement: AC-7 — Testaufbau nach bestehendem Muster
  Conflict: Warnungen unter Swift-6-Strict-Concurrency, bricht aber nichts.
  Remediation: `@MainActor` an die Klasse.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Status: BEHOBEN in Runde 4 (atomares Abbild; Restrisiko Systemlast siehe F006)
  Code reference: LooseEndsUITests/Watch/WatchCaptureUITests.swift:41
  Description: Vorher zwei getrennte Abfragen (`waitForExistence` der Bestätigung, dann `field.exists`); unter Last lag die zweite 2,06 s nach dem Tipp, nach Ablauf der 1,5 s. Jetzt liefert ein einziges `app.snapshot()` je Durchlauf Bestätigung und Feldzustand zugleich.
  Spec requirement: AC-2 — Feld noch nicht da; Risiko 3 (zeitabhängiger Test)
  Conflict: Der falsche Rotbefund (Feld zurück, weil spät abgefragt) ist beseitigt; die Zusicherung bleibt zeitabhängig (Bestätigung steht 1,5 s), kann aber nicht mehr durch zwei verschiedene Zeitpunkte widersprüchlich werden.
  Remediation: keine nötig.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Status: OFFEN (unverändert, nicht abgeschwächt)
  Code reference: LooseEndsUITests/Watch/WatchCaptureUITests.swift:31
  Description: `sheetDone` (`navigationBars.buttons.element(boundBy: 1)`) existiert im Hauptbild nie; die Prüfung „Eingabeblatt öffnet sich nicht von selbst“ ist nahezu tautologisch.
  Spec requirement: AC-6 — kein Eingabeblatt nach dem Reset
  Conflict: Beweisstärke gering; die Code-Prüfung (kein Fokus gesetzt) trägt AC-6.
  Remediation: zusätzlich auf Elemente des Eingabeblatts prüfen oder Hinweis im Test.

Finding:
  ID: F004
  Severity: MEDIUM
  Category: regression
  Status: BEHOBEN in Runde 3 (CaptureSmokeTests 17/17, sim-unit 641/0/3, Skips benannt)
  Code reference: project.yml:315
  Description: Der Exclude `Watch/**` im iOS-UI-Ziel baut und linkt (belegt); ein vollständiger Lauf bestehender iOS-UI-Tests und ein eigener `sim-unit` wurden von mir nicht abgeschlossen (Last 350–430, Lauf blieb beim App-Start hängen und wurde beendet).
  Spec requirement: AC-9 — Bestehendes bleibt grün
  Conflict: Nachweis nur über Implementierer-Ausgabe (641/0/3 übersprungen), nicht unabhängig reproduziert; die 3 Übersprungenen sind laut Auftrag unabhängig von #409 (#419).
  Remediation: Lauf bei normaler Last wiederholen (CaptureSmokeTests + sim-unit) oder CI-Ergebnis des PR heranziehen.

Finding:
  ID: F005
  Severity: LOW
  Category: spec_violation
  Status: OFFEN (Hinweis für die Validierung: Spec anpassen)
  Code reference: project.yml:329
  Description: Testdatei liegt in `LooseEndsUITests/Watch/`, die Spec (Source, Affected Files) nennt `LooseEndsWatchUITests/WatchCaptureUITests.swift`.
  Spec requirement: Scope/Affected Files
  Conflict: Pfadabweichung, in project.yml begründet, funktional folgenlos.
  Remediation: Spec anpassen.

Finding:
  ID: F006
  Severity: LOW
  Category: edge_case
  Status: OFFEN (Hinweis, kein Blocker)
  Code reference: LooseEndsUITests/Watch/WatchCaptureUITests.swift:100
  Description: Die Lastserie (System-Load 200–357, Neustart des Simulators) schlug 2 von 3 Läufen fehl: testmanagerd-Zeitüberschreitung im Fokus-Schritt (`openInputSheet`) und „App-Knopf Fertig bleibt gesperrt“ in `capture()` im unveränderten Test 1. Beides liegt vor der geänderten Prüfung und im unveränderten Hilfscode; die Änderung berührt es nicht. Der Test kann bei starker Last weiter rot werden (falsch rot, nicht falsch grün).
  Spec requirement: AC-7 — belastbarer Testaufbau
  Conflict: Umgebungsflackern ohne Bezug zur Änderung; nicht in diesem Ticket lösbar.
  Remediation: bei normaler Last laufen lassen; bei Wiederholung eigenes Ticket.

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Betroffene Felder im Änderungsumfang: `saved` und `text` in `WatchCaptureView`. Bedingung davor: `text = ""`/`saved = true` nur nach erfolgreichem `CaptureService.save` (WatchCaptureView.swift:49–51); `saved = false` nur nach vollendetem 1,5-s-Schlaf (Zeile 40). Test für diesen Weg: `testTwoCapturesInARowReturnToEmptyField` löst genau diesen Weg aus (Erfolgsweg); für den Fehlerweg keiner (laut Spec nur Code-Review, AC-4).

## Verdict

AC-1 bis AC-7 und AC-9 bestätigt (Runde 4: AC-2-Test atomar und mindestens so streng, 3/3 grüne Läufe nach der Änderung; Rest wie Runde 3). AC-8 (Gerät, Stufe 3, TestFlight nach dem Merge) ist laut Spec bewusst offen und von mir nicht erfindbar; ein offenes AC blockiert das Gate, bis Henning den Override setzt. Offene Befunde: F003 (LOW), F005 (LOW, Spec-Pfad), F006 (LOW, Lastflackern). Keine CRITICAL/HIGH/MEDIUM offen. Behoben: F001, F002, F004.

Nachtrag Auftraggeber (2026-10-15, nach dem Merge): AC-8 von Henning mit TestFlight-Build 64 auf der Watch bestätigt („Funktioniert“), siehe Checkliste. Das Urteil des Adversary bleibt unverändert; der Override für AC-8 steht im Workflow.

### Verdict: AMBIGUOUS

## Geprüfte Dateien

- sha256:eabfb40e24ecab44a092d2763ebee029e18efe715faad5c1de934e425fa49be0  LooseEndsUITests/Watch/WatchCaptureUITests.swift
- sha256:ee69e583d817c13bf218dd7a22b42215ad0a164ac62eb7941d9b8b7e18cd772f  LooseEndsWatch/WatchCaptureView.swift
- sha256:3dfbccf8acd1696e5e4fa2e922dfa329e381cb67762dadb06329afaa8adee232  project.yml
- sha256:178d34d2b06d1024e91ada10097722196471e5bea83e5d8cd245094e9b7d3d4c  scripts/sim.sh
- sha256:1e51ecc8c081329a65de0cf27940164fb0a57542f7e32b711ea61d1de5a7568b  scripts/sim_proof.py

## Prüfbasis

- base: a371718bc3a71a4dafeee2ebb7a9a47a175aff1d
- blob:84d55143685aad95ed53cb20235111523843dbb4  LooseEndsUITests/Watch/WatchCaptureUITests.swift
- blob:b4d98876a3e98866742e85acb8a6bf76ca49fdd6  LooseEndsWatch/WatchCaptureView.swift
- blob:72ce43c7cab0b8deaef14111fe644b8d26aafb61  project.yml
- blob:a38005e3a1acb4c018f504f1825f22c8f25dff83  scripts/sim.sh
- blob:3a4f573d04840276a012c025efb207e0f148f33a  scripts/sim_proof.py
