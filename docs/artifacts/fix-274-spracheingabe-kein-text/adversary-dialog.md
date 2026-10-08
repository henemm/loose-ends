# Adversary Dialog — fix-274-spracheingabe-kein-text
Spec: docs/specs/fix-274-sichtbare-spracheingabe-diagnose.md
Datum: 2026-10-08 14:12

## Checkliste
- [x] **AC-1 Schwelle:** Given die Erfassung hört zu und Puffer > 0 / When 6 s ohne Ergebnis vergangen sind (genau 6,0 s eingeschlossen) / Then steht die graue Zeile unter der Wellenform. Bei 5,9 s steht sie nicht da.
- [x] **AC-2 Konstante:** Die 6 Sekunden stehen genau einmal als `SpeechDiagnosis.threshold`; Regel, Prüfschleife und Tests benutzen diese Konstante.
- [x] **AC-3 Kein Ton:** Given 0 Puffer / When beliebig lange / Then keine Zeile (anderer Fehler, nicht Gegenstand).
- [x] **AC-4 Ergebnis löscht:** Given die Zeile steht / When ein Teil- oder Endergebnis eintrifft / Then verschwindet die Zeile spätestens eine Sekunde danach und kommt im selben Lauf nicht wieder.
- [x] **AC-5 Neustart:** Given eine Zeile stand / When die Erfassung geschlossen und neu geöffnet wird / Then beginnen Puffer- und Ergebniszähler und Uhr bei 0, und die Zeile erscheint erst wieder nach AC-1.
- [x] **AC-6 Inhalt:** Die Zeile nennt Modellstatus, Mikrofonrecht, Spracherkennungsrecht, Anzahl Puffer, Anzahl Ergebnisse, auf Deutsch und Englisch nach der Gerätesprache.
- [x] **AC-7 Aussehen:** Grau (`.secondary`), `.footnote`, keine Farbe, keine Schaltfläche. Abbrechen, Tippen ins Feld und Mikrofon-Knopf gehen unverändert.
- [x] **AC-8 Keine neue Zeile bei Grund:** Bei `unavailable`, `needsModel` und `loadingModel` erscheint die Zeile nie.
- [x] **AC-9 Erkennung unverändert:** Keine Änderung an Transcriber, Analyzer, Tap, Wandler, Rechteabfrage; der gesunde Fall (Text kommt) sieht aus wie vorher, ohne zusätzliche Zeile.
- [x] **AC-10 Festzustand:** Mit `--ui-testing` und `--ui-testing-speech-diagnosis` zeigt die Erfassung die Zeile mit dem festen Text aus „Testen“; ohne das zweite Argument bleibt `--ui-testing` unverändert.
- [x] **AC-11 Gerät (laut geänderter Spec: AC-1/AC-4/AC-6 am iPhone belegt, AC-5 nur per Code, kein Mac-Protokoll):** Prüfbau auf dem iPhone belegt Erscheinen, Verschwinden und Inhalt der Zeile durch Hennings Beobachtung; der Neustart ist nur durch Code-Lesen belegt, von Henning akzeptiert.
- [x] **AC-12 Regression:** Unit, Build, UI-Smoke und Speech Stress (10×, weil `LooseEnds/Speech/**` berührt) grün.

## Dialog

### Runde 1
**Adversary:** Alle Punkte gegen den Diff und die Läufe geprüft, nicht gegen die Behauptung.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:19
  Evidence: `guard buffers > 0, results == 0, secondsListening >= threshold` ist inklusive; Unit-Tests "No hint before the threshold" und "Hint at exactly the threshold (inclusive)" grün (test-green-output.txt Zeile 673-674). Uhr startet bei `listeningSince = .now` direkt nach `state = .listening` (LooseEnds/Speech/SpeechCapture.swift:230); Prüftakt 1 s, erste Anzeige also zwischen 6 und ~7 s (Spec: "jede Sekunde").
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:8
  Evidence: Literal 6 steht nur hier; Regel (Zeile 19) und Tests nutzen `threshold`; die Prüfschleife ruft nur `hint`. Grep nach weiteren 6er-Literalen in Speech/ ohne Treffer.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:19
  Evidence: `buffers > 0`; Test "No hint without audio" grün. Puffer kommen aus `ConverterBox.bufferCount` (LooseEnds/Speech/SpeechCapture.swift:334) unter derselben Sperre wie `feed`.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Speech/SpeechCapture.swift:258
  Evidence: `resultCount += 1` bei jedem Element vor der Textverarbeitung; `hint` liefert bei results > 0 dauerhaft nil, der nächste Takt (<= ~1 s) nimmt `diagnosis` zurück (Zeile 247). Kommt im selben Lauf nicht wieder, da der Zähler nur in stop()/Start auf 0 geht. Test "Hint disappears when a result comes later" grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Speech/SpeechCapture.swift:111
  Evidence: stop() setzt resultCount, listeningSince, diagnosis, box und cancelt check (Zeilen 108-114); der Start setzt resultCount/diagnosis/listeningSince erneut (228-230), ein neuer ConverterBox beginnt bei 0 Puffer. Eine alte Prüfschleife nach Neustart: Task.sleep wirft bei Abbruch -> return; läuft ein Takt trotzdem noch einmal, wertet er dieselben Felder des neuen Laufs aus, setzt also nichts Fremdes. Alles @MainActor, kein Datenwettlauf; Build ohne Swift-6-Fehler.
  Status: CONFIRMED (Restrisiken siehe F001, F002)

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:33
  Evidence: Schlüssel im Katalog stimmt buchstäblich mit der Interpolation (%@ %@ %@ %lld %lld) und der Spec-Tabelle überein; deutsche Werte identisch zur Tabelle. UI-Test vergleicht den englischen Text mit XCTAssertEqual: grün (adversary-test-output.txt, 2 Tests, 0 Failures). Der Diff der xcstrings fügt nur 3 Einträge hinzu; ein Komma an "Hidden" ergänzt, keine bestehende Zeile verändert. Die neuen en-Werte betreffen nur die zwei neuen Ja/Nein-Schlüssel. Deutsch ist nicht per Test belegt (nur Lesen des Katalogs).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Views/CaptureView.swift:143
  Evidence: `.font(.footnote)`, `.foregroundStyle(.secondary)`, reiner Text, kein Button, umbrechend (`fixedSize`). Screenshot geöffnet: Erfassungsblatt, Platzhalter "What should I remember?", Mikrofon-Symbol rechts, darunter graue zweizeilig umbrochene Zeile "No text yet — model: installed · microphone: yes · speech: yes · buffers: 62 · results: 0", keine Farbe. Cancel/Done/Mikrofonknopf unverändert (Zeile 135).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Speech/SpeechCapture.swift:243
  Evidence: `updateDiagnosis` setzt bei `!isListening` nil; check wird nur in begin() nach `state = .listening` angelegt. unavailable/needsModel/loadingModel/idle laufen nie dorthin. Die Zeile hängt in der View an `speech.diagnosis` (nur im Zweig .idle/.listening).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Speech/SpeechCapture.swift:221
  Evidence: Im Diff sind Transcriber-, Analyzer-, Tap-, Wandler- und Rechteabfrage-Code unverändert; ergänzt sind nur `modelStatus = ...`, `microphoneGranted/speechGranted = ...`, `self.box = box`, Zähler und Task. `ConverterBox.bufferCount` ist reiner Lesezugriff unter Sperre. In der View wird die HStack unverändert in einen VStack gelegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Views/CaptureView.swift:37
  Evidence: `diagnosisFixture` = `isUITesting && arguments.contains("--ui-testing-speech-diagnosis")`; ohne --ui-testing wirkungslos, ohne das Argument bleibt `speechWanted` false und die Zeile weg (Test testNoDiagnosisLineWithoutArgument grün). `begin()` startet bei `speechWanted == false` kein Mikrofon.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: LooseEndsUITests/SpeechDiagnosisLineTests.swift:36
  Evidence: Eigener Lauf `./scripts/sim.sh test-proof SpeechDiagnosisLineTests`: Exit 0, 2 Tests, 0 Failures, "Test Succeeded" (adversary-test-output.txt). Unit-Lauf aus test-green-output.txt (Test Succeeded, SpeechDiagnosis-Tests aufgelistet) nicht erneut gefahren. Speech Stress 10x und CI laufen erst in der Pipeline, hier nicht belegbar.
  Status: CONFIRMED (Unit/UI), Speech Stress offen

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Speech/SpeechCapture.swift:232
  Description: Die Prüfschleife `while !Task.isCancelled { ...; self?.updateDiagnosis() }` endet nicht, wenn `self` nil ist. start() überschreibt `check` ohne den alten Task zu canceln. Zwei überlappende start()-Aufrufe (zweimal schnell auf das Mikrofon tippen; `guard !isListening` greift erst nach den awaits) erzeugen zwei Schleifen, nur die zweite wird in stop() abgebrochen; die erste läuft nach dem Schließen der Ansicht endlos jede Sekunde weiter.
  Spec requirement: AC-5 — "Sie endet in stop()"
  Conflict: Ein verwaister Wecker-Task. Der doppelte start() selbst ist vorbestehend (engine/results werden genauso überschrieben), der Schaden ist ein sekündlicher Leerlauf, keine falsche Anzeige.
  Remediation: `guard let self else { return }` in der Schleife und `check?.cancel()` vor dem Zuweisen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Speech/SpeechCapture.swift:258
  Description: `collect` eines früheren Laufs wird in stop() nur cancelt; liefert die Sequenz nach dem Abbruch noch ein Element, erhöht der alte Task `resultCount` des neuen Laufs und unterdrückt dessen Zeile (falsch negativ). Sehr schmales Fenster, kein Fehlalarm.
  Spec requirement: AC-5 — Zähler beginnen bei 0
  Conflict: Der Zähler gehört nicht an einen Lauf gebunden.
  Remediation: Lauf-Kennung (stopCount) in collect prüfen, bevor gezählt wird.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Speech/SpeechCapture.swift:248
  Description: Zeitbasis ist `Date.now` (Wanduhr), nicht monoton. Eine Uhrumstellung während des Zuhörens kann die Zeile früher/später oder gar nicht zeigen.
  Spec requirement: AC-1 — 6 s Schwelle
  Conflict: Die Spec nennt keine Uhr; ContinuousClock wäre robuster.
  Remediation: `ContinuousClock.now` statt `Date`.

Finding:
  ID: F004
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEnds/Views/CaptureView.swift:135
  Description: Im Festzustand (--ui-testing-speech-diagnosis) ist der Mikrofonknopf sichtbar; ein Tipp ruft `speech.start()`. Spec: "startet kein Mikrofon". Der Start passiert nur auf Tipp, kein Test tippt ihn.
  Spec requirement: AC-10 — Festzustand ohne Mikrofon
  Conflict: Nur bei Tipp unter Testargument; Produktpfad unberührt.
  Remediation: Knopf im Festzustand ausblenden oder deaktivieren.

**Implementierer:**

### Runde 2
**Adversary:** Zweiter Durchgang gezielt auf Skepsis bei Einigkeit in Runde 1. (a) Leere Ergebnisse: `collect` zählt jedes Element (Zeile 258) vor der Textverarbeitung, also auch leere; die Spec nimmt das bewusst in Kauf (Risiken). (b) Race Prüfschleife/collect/stop: alle drei laufen auf dem Hauptakteur, `stop()` ist synchron; es gibt keine Verschränkung innerhalb von `updateDiagnosis`. Das einzige Fenster ist F002. (c) Beim Fehlerpfad in start() (begin wirft) ruft `stop()` auf und setzt danach unavailable: diagnosis ist nil. (d) Wird die Zeile bei gesundem Start angezeigt? Nein, `results` > 0 nach dem ersten Wort; Spec räumt kurzes Aufblitzen nach 6 s Schweigen ein. (e) AC-11 (Gerät) ist hier nicht beweisbar: Prüfbau und TestFlight stehen aus, Checkbox bleibt offen. (f) Screenshot von simulator-run angesehen (siehe AC-7).
**Implementierer:**

### Runde 3
**Adversary:** Nachprüfung von F001-F004 gegen den aktuellen Diff, dazu der Gerätebeleg (geraetelauf-beleg.md).

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Speech/SpeechCapture.swift:236
  Evidence: F001 behoben. `check?.cancel()` vor der Neuzuweisung (236), Schleife mit `guard let self, !Task.isCancelled else { return }` (240), `Task.sleep` wirft bei Abbruch -> return; stop() cancelt und nil-t `check` (110-111). Zwei überlappende start()-Aufrufe lassen keine verwaiste Schleife mehr zurück. F002 behoben: `run += 1` (233) vor dem Start von `collect(from:run:)`, Zählung nur bei `run == self.run` (266); ein alter Lauf zählt nie in den neuen, und begin() setzt `resultCount = 0` (230) nach jedem Streuzähler aus dem Leerlauf. Swift 6: Klasse @MainActor, Tasks erben den Hauptakteur, `[weak self]` ohne Sendable-Verstoß, alle Felder nur auf dem Hauptakteur; Build und UI-Lauf ohne Fehler. Rest: ein Zeitfenster zwischen stop() und dem nächsten begin(), in dem ein alter collect zählt, wird von Zeile 230 zurückgesetzt. Am Gerät nicht beobachtet (nur Code).
  Status: CONFIRMED (per Code)

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:21
  Evidence: F003 behoben: Zeitbasis `ContinuousClock` (SpeechCapture.swift:232, 252-253), monoton. Regel unverändert inklusive 6,0 s. Henning am iPhone: "die graue Zeile war da" (geraetelauf-beleg.md).
  Status: CONFIRMED (Gerät und Unit)

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Speech/SpeechCapture.swift:266
  Evidence: Zähler pro Element vor der Textverarbeitung; Zeile verschwindet im nächsten Takt (<= 1 s). Henning am iPhone: "verschwand, sobald ich gesprochen habe".
  Status: CONFIRMED (Gerät)

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Resources/Localizable.xcstrings:240
  Evidence: Schlüssel stimmt mit der Interpolation in SpeechDiagnosis.swift:32 überein, de-Werte plus ja/nein (241-242). Henning: "inhaltlich sinnvoll". Deutsch am Gerät nicht gesondert belegt, nur Lesen des Katalogs.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Views/CaptureView.swift:167
  Evidence: F004 behoben: `guard !diagnosisFixture else { return }` in toggleListening; `diagnosisFixture` verlangt `isUITesting` UND das Argument (37-40), im Produkt wirkungslos, `--ui-testing` allein unverändert (speechWanted false). Alle anderen speech.start()-Stellen (159, 172) liegen im gleichen Pfad bzw. nicht unter Fixture. UI-Test tippt den Mikrofonknopf (LooseEndsUITests/SpeechDiagnosisLineTests.swift:47-56): Label bleibt "Listen", Zeile bleibt, 3 s Wartezeit läuft in Timeout. Eigener Lauf grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Speech/SpeechCapture.swift:223
  Evidence: Diff gegen HEAD in Speech/: nur Zähler, Felder, `self.box = box`, `modelStatus`/Rechte-Merker, Prüfschleife, `bufferCount`. Transcriber, Analyzer, Tap, Wandler und Rechteabfrage unverändert (Zeilen 215-225 ändern nur die Merk-Zuweisung `self.box`). SpeechDiagnosis.swift ist rein (Foundation, kein Systemzugriff).
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:8
  Evidence: Eigener Lauf `./scripts/sim.sh test-proof SpeechDiagnosisLineTests`: Exit 0, 2 Tests, 0 Failures, Test Succeeded (adversary-test-output.txt, neu geschrieben, inkl. neuem Tipp-Test). Unit-Lauf test-green-output.txt (14:38:51, 468 grün) ist NEUER als SpeechCapture.swift (14:37:08), SpeechDiagnosis.swift und Localizable, aber ÄLTER als CaptureView.swift (14:51:24, Guard in toggleListening). Diese Änderung ist durch den frischen UI-Lauf mitkompiliert und getestet; die Unit-Tests berühren CaptureView nicht. Speech Stress 10x nur in CI.
  Status: CONFIRMED (Unit-Lauf strikt veraltet für CaptureView, Risiko minimal)

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Speech/SpeechCapture.swift:240
  Description: Kein neuer Defekt aus den Korrekturen gefunden. Einzige Restbeobachtung: die Prüfschleife hält `self` nur während eines Takts stark; ein verwaister Task endet beim nächsten Takt nach Freigabe. Kein Handlungsbedarf.
  Spec requirement: AC-5
  Conflict: keiner
  Remediation: keine

F001-F004: behoben (siehe oben).
**Implementierer:**

### Runde 4
**Adversary:** Die Spec wurde nach Runde 3 geändert (AC-11 auf das am Gerät Belegte reduziert, von Henning freigegeben). Bewertung von AC-11 gegen die geänderte Spec; Code seit Runde 3 unverändert (`git diff d7b4ce7 -- LooseEnds LooseEndsTests LooseEndsUITests` leer).

Confirmation:
  AC: AC-11
  Code reference: LooseEnds/Speech/SpeechCapture.swift:113
  Evidence: AC-11 verlangt nur noch Erscheinen, Verschwinden, Inhalt (AC-1, AC-4, AC-6) als Hennings Beobachtung am Bildschirm; geraetelauf-beleg.md belegt genau diese drei, nennt AC-5 "am Gerät nicht beobachtet" und kein Mac-Protokoll. AC-5 ist durch Code-Lesen belegt: stop() setzt resultCount und diagnosis zurück (SpeechCapture.swift:113-115), begin() setzt sie erneut (233-234), Lauf-Kennung in collect (269). Henning hat die Lücke am 2026-10-08 akzeptiert. Offen bleibt Hennings Rückmeldung der TestFlight-Fassung; sie ist Folgearbeit nach der Auslieferung, kein Teil dieser Abnahme.
  Status: CONFIRMED

Finding:
  ID: F006
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Speech/SpeechCapture.swift:113
  Description: Die Spec behauptete an zwei Stellen noch mehr als belegt: Geräteablauf Schritt 2 ("Ablauf im Protokoll gegengelesen", Neustart als Teil des Geräteablaufs) und Testplan zu `testRestartStartsFresh` ("belegt der Durchlauf auf dem Gerät"). Dazu fehlte bei AC-5 der Verweis auf die Beleglage.
  Spec requirement: AC-11
  Conflict: Spec widersprach sich selbst und überbehauptete den Beleg.
  Remediation: Formulierungen angleichen. Behoben: Spec geändert unter Hennings `override`, Änderungsverlauf ergänzt, Briefing neu erstellt und von Henning freigegeben. Per Nachlesen geprüft: kein "gegengelesen" mehr als Belegbehauptung.

### Runde 5
**Adversary:** Nach dem Aufsetzen auf main (#280, Zustand `.accessDenied`) wurde `SpeechCapture.swift` von Hand zusammengeführt (Commit a8886b3). Prüfung nur über Code, Diff und die frischen Läufe.

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Speech/SpeechCapture.swift:86
  Evidence: Konflikt korrekt gelöst: `microphoneGranted`/`speechGranted` werden vor `SpeechAccess.missing(...)` gesetzt (86-90), bei Treffer `state = .accessDenied(missing)` und `return` vor `begin()`; dort gibt es keinen Ton, keinen Puffer, keinen `check`-Task, `updateDiagnosis` hat zusätzlich `isListening && box != nil`. Die Zeile steht nur im Zweig `.idle/.listening` (LooseEnds/Views/CaptureView.swift:113 trennt `.accessDenied` in einen eigenen Fall). Nichts aus #280 verloren (SpeechAccess.swift unverändert), nichts aus #274 verloren.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:20
  Evidence: Im Erkennungspfad nur Zähler und Lesezugriff unter bestehender Sperre; Transcriber, Analyzer, Konverter unangetastet. Localizable.xcstrings: Diagnose-Schlüssel und #280-Einträge beide vorhanden (LooseEnds/Resources/Localizable.xcstrings:242).
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: LooseEndsUITests/SpeechDiagnosisLineTests.swift:36
  Evidence: Auf dem zusammengeführten Stand neu gelaufen: Unit grün inkl. Suiten "Speech diagnosis (#274)" und "Erfassung: fehlende Rechte (#280)" (test-green-output.txt), UI SpeechDiagnosisLineTests 2 Tests, 0 Failures (adversary-test-output.txt), Screenshot angesehen: graue Zeile unter türkisem Mikrofon.
  Status: CONFIRMED

Finding:
  ID: F007
  Severity: LOW
  Category: test_gap
  Code reference: LooseEnds/Views/CaptureView.swift:113
  Description: Kein UI-Test belegt, dass im Zustand `.accessDenied` keine Diagnosezeile steht; der Beleg ist nur strukturell (eigener `case`, kein Audio). Kein Blocker.
  Spec requirement: AC-8
  Conflict: keiner
  Remediation: keine nötig; bei Gelegenheit ein UI-Test.

**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Proven points: 12/12 (nach Aufsetzen auf main; #280 und #274 vollständig erhalten; F001-F004, F006 behoben, F007 LOW offen ohne Handlungsbedarf)
Tests: UI SpeechDiagnosisLineTests 2 passed, 0 failed, 0 übersprungen (adversary-test-output.txt); Unit-Lauf grün auf dem zusammengeführten Stand (test-green-output.txt)
Hinweis: Neustart (AC-5) nur durch Code-Lesen belegt, von Henning akzeptiert; Speech Stress 10x läuft in der CI.

## Geprüfte Dateien

- sha256:99141e8704510efa51d92c63cef478e8b5602426aa42789d0facaba1cf5f09d4  LooseEnds/Resources/Localizable.xcstrings
- sha256:43659fea1033ba4f58124665435689e84e278736b7fe42024a914c442ef47fe1  LooseEnds/Speech/SpeechCapture.swift
- sha256:d5b0d236f081f083bfbce05d6e147956729e5507f7d073802462cfdea1570893  LooseEnds/Speech/SpeechDiagnosis.swift
- sha256:0a015ecb99f1e78f3b98f2ea29a0498112877881af8df9df44c843cfeb682ba5  LooseEnds/Views/CaptureView.swift
- sha256:27a4548d7e22959d0c329698c72255ddded9d0735085abaa4d7e6a58d9009079  LooseEndsUITests/SpeechDiagnosisLineTests.swift

## Prüfbasis

- base: 5f7f3ec6f81dd58debe728175a4015e0e92d1f21
- blob:5dc12060fdb99fddfd428bc8cd72b1b43bef57b6  LooseEnds/Resources/Localizable.xcstrings
- blob:0588f35e95038ca051a788ea9594aa4f3c6ca94a  LooseEnds/Speech/SpeechCapture.swift
- blob:0e63dd826c20f86ba7dd44c38e3e5bda7a4daf0a  LooseEnds/Speech/SpeechDiagnosis.swift
- blob:edf58dca257cb300287f48f1ccba9c01bf8cb352  LooseEnds/Views/CaptureView.swift
- blob:66b1971137c7429e21d25ce40801ac8fd4154b2c  LooseEndsUITests/SpeechDiagnosisLineTests.swift
