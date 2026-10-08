# Adversary Dialog — spike-22-kaltstart
Spec: docs/specs/measurement/spike-22-kaltstart.md
Datum: 2026-10-08 13:06

## Checkliste
- [x] **Input:** Start des Prüfbaus (Release) per `devicectl` mit `-measureLaunch` oder per Druck auf das Control. — Runde 2 belegt (Gerät: reihe1-launch-timings.json nachgerechnet)
- [x] **Output:** eine neue Eintragszeile in `Documents/launch-timings.json` im Container des Prüfbaus; Signposts im — Runde 2 belegt (Gerät: reihe1-launch-timings.json nachgerechnet)
- [x] **Side effects:** keine Verhaltensänderung der App ohne Startargument; ein Dateischreibvorgang pro Prüfbau-Prozess, nicht im — Runde 1: Code- und Testseite belegt
- [x] **AC-1 Signposts im Produkt:** Given ein beliebiger Build / When die Erfassung gestartet wird / Then liegen die Messpunkte aus Abschnitt 2 als Signposts im Unified Log, und nichts am Verhalten ist anders (`CaptureSmokeTests`, `SpeechListeningTests`, Speech Stress grün). — Runde 2: Speech Stress lokal 10/10, UI Smoke 17/17, Unit 459/0, project.yml unverändert; CI fährt Speech Stress zusätzlich
- [x] **AC-2 Datei nur im Prüfbau:** Given ein Build mit Kennung ohne `.probe` / When die Erfassung `.listening` und den ersten Puffer erreicht / Then entsteht keine `launch-timings.json` (Unit-Test belegt es auf dem Schreibpfad); Given der Prüfbau / When der erste Puffer nach `.listening` eintrifft (oder 3 s ohne Puffer vergehen) / Then steht ein neuer Lauf mit `listening` und `firstBuffer` (bzw. `null`) in der Datei. — Runde 1 belegt
- [x] **AC-3 Genau einmal pro Prozess:** Given ein Prüfbau-Prozess / When `.listening` mehrfach erreicht wird (Erfassung erneut geöffnet) / Then entsteht nur ein Eintrag für diesen Prozess (Unit-Test `WriteOnce`; auf dem Gerät: Zahl der Einträge = Zahl der Starts). — Runde 1 belegt
- [x] **AC-4 Läufe sammeln sich:** Given eine Datei mit n Läufen / When ein weiterer Prozess schreibt / Then hat sie n+1, die alten unverändert (Unit-Test). — Runde 1 belegt
- [x] **AC-5 Nullpunkt:** Given ein Lauf auf dem Gerät / When er ausgewertet wird / Then ist die Gesamtzeit von Prozessstart (`kp_proc.p_starttime`) bis `.listening` angegeben und `zeroPoint` lautet `processStart`. — Runde 2 belegt (Gerät: reihe1-launch-timings.json nachgerechnet)
- [x] **AC-6 Startargument:** Given der Start mit `-measureLaunch` / When die App öffnet / Then ist das Erfassungs-Sheet ohne Tippen sichtbar; Given der Start ohne Argument / Then ist es nicht sichtbar (UI-Test, Simulator). — Runde 1 belegt
- [x] **AC-7 Reihe 1:** Given der Release-Prüfbau auf dem iPhone 16 Pro / When `launch-measure 10` läuft / Then liegen 10 gültige Kaltlauf-Einträge der Laufart `automated` vor (erster Lauf verworfen, getrennt gekennzeichnet). — Runde 2 belegt (Gerät: reihe1-launch-timings.json nachgerechnet)
- [x] **AC-8 Reihe 2:** Given das Control des Prüfbaus / When Henning es zehnmal drückt (App jeweils im App-Umschalter beendet) / Then liegen 10 Einträge der Laufart `press` vor; Reihe 3 hat 1–2 Einträge nach Neustart. — entfallen per PO-Entscheidung 2026-10-08, Zitat: „schließe das ab, das brauche ich nicht“ (docs/context/spike-22-kaltstart.md, Abschnitt „Reihe 2 und 3 entfallen“; Bericht nennt den ungemessenen Systemanteil)
- [x] **AC-9 Hennings Installation unberührt:** Given Hennings Alltags-App / When die Messungen laufen / Then ist sie danach unverändert (gleiche Kennung, gleiche Version in `devicectl device info apps`, nur lesend geprüft). — Runde 2: lesende Abfrage (Implementierer) zeigt Loose Ends 0.1.0 Bundle Version 19 getrennt von LE Prüfbau .probe 0.1.0 (1); Werkzeug berührt nur .probe (sim.sh:405-408)
- [x] **AC-10 Bericht:** `docs/reference/kaltstart-messung.md` enthält Rohwerte je Lauf, Mittelwert, Median, Maximum, Abschnitte, Gerät, OS, Build, die Nulllinie (Reihe 1) und beide Befunde (Sheet statt Szene, Textfeld ohne Fokus). — Runde 2 belegt (Gerät: reihe1-launch-timings.json nachgerechnet)
- [x] **AC-11 Ergebnis eingetragen:** Offener Punkt 3 in `02-datenmodell-und-ansichten.md` nennt Mittelwert, Zahl der Läufe und Gerät; `04-stand.md` verweist auf den Bericht. — Runde 2 belegt (Gerät: reihe1-launch-timings.json nachgerechnet)
- [x] **AC-12 Verfehlung → Folge-Issue:** Given der Mittelwert von Reihe 2 liegt bei ≥ 1 s / Then existiert ein GitHub-Issue mit konkretem Optimierungsvorschlag aus dem größten Abschnitt; liegt er darunter, wird das im Bericht ausdrücklich festgehalten (kein Issue nötig). — Runde 2 belegt (Gerät: reihe1-launch-timings.json nachgerechnet)
- [x] **AC-13 Regression:** Unit, Build, UI Smoke und Speech Stress grün; `./scripts/sim.sh generate` ändert `project.yml` nicht. — Runde 2: Speech Stress lokal 10/10, UI Smoke 17/17, Unit 459/0, project.yml unverändert; CI fährt Speech Stress zusätzlich

## Dialog

### Runde 1
**Adversary:**

Eigene Läufe (Ausgabe: docs/artifacts/spike-22-kaltstart/adversary-test-output.txt):
- `./scripts/sim.sh unit LaunchTimingsTests`: 10/10 Swift-Testing-Tests grün ("Test Succeeded", "Unit-Tests bestanden"). Der Einzellauf zeigt im XCTest-Teil "Executed 0 tests" (bekanntes Swift-Testing-Muster); die 10 Tests stehen einzeln mit Häkchen im Log. Der volle Lauf (459 grün, 0 rot) liegt in test-green-output.txt.
- `./scripts/sim.sh test LaunchArgumentTests`: "Executed 2 tests, with 0 failures", "UI-Test bestanden".
- Arbeitsbaum nach den Läufen: project.yml unverändert; docs/reference/date-title-fidelity.md nicht verändert (nichts zurückzusetzen).
- Speech Stress: `.github/workflows/speech-stress.yml` läuft auf Runner-Label `xcode-27`, iPhone 17 / iOS 27.0, Schleife mit simctl-Rechte-Reset; nur in CI definiert, lokal nicht als Workflow ausführbar (CaptureCancelCrashTests einzeln wäre lokal möglich, ersetzt die 10 Läufe aber nicht). AC-1/AC-13 bleiben dafür offen.

Edge-Case-Prüfung (Code gelesen):
1. firstBuffer aus dem Audio-Thread: ConverterBox.feed ruft `LaunchTimings.mark` unter dem NSLock der Box; mark = Uhr lesen, Signpost, Dictionary-Eintrag unter OSAllocatedUnfairLock, `write` läuft ausserhalb der Sperre und nur via `queue.async` (utility-Queue). Kein MainActor-Hop, keine Datei-I/O im Audio-Thread. In Ordnung.
2. Zweite Erfassung im selben Prozess: `guard state.points[point] == nil` (erster Wert gewinnt) und `written` verhindern einen zweiten Eintrag; Test writeOnFirstBuffer deckt doppeltes firstBuffer/listening/Timeout ab. Jedes `.listening` plant einen weiteren Timeout-Block (LaunchTimings.swift:170), der folgenlos bleibt (take prüft `written`). Harmlos.
3. Timeout bei mehrfachem listening: siehe 2; Test writeOnTimeout belegt die Grenze (bufferTimeout-1 schreibt nicht, bufferTimeout schreibt, späteres firstBuffer schreibt nicht erneut).
4. `-measureLaunch` mit `--ui-testing`: der UI-Test startet genau so und ist grün; pending wird vor dem Container gesetzt, ContentView unverändert.
5. sysctl-Fehlerpfad: LaunchTimings.swift:210-213 loggt per Logger.error und setzt zeroPoint .firstPoint. Kein Unit-Test (nur per Injektion erreichbar), LOW, nicht spec-verlangt.
6. Beschädigte Datei: append() erkennt Decode-Fehler, persist() legt sie als launch-timings.corrupt-<Sekunden>.json beiseite und schreibt neu (atomic). Test `corrupt` prüft nur append; das Beiseitelegen (moveItem) in persist() hat keinen Test. LOW.
7. Kennung ohne .probe: persist() kehrt vor jeder Datei-I/O zurück (LaunchTimings.swift:142); Test `persist` belegt "keine Datei". Die Queue/Timeout-Maschinerie läuft auch im Produktbau, nur ohne Datei. Spec-konform.
8. Datei-I/O nicht auf MainActor/Audio-Thread: persistInDocuments läuft nur in `queue.async` (LaunchTimings.swift:161). In Ordnung.
9. Messpunkte vs. initializeCloudKitSchemaIfAsked: initStart (LooseEndsApp.swift:13) liegt davor, containerStart (:21) danach, der Aufruf ist `#if DEBUG`. Im Release-Prüfbau ohne Einfluss; in Debug ginge das Schema-Init in `initialization`, nicht in `container`.
10. Statische Initialisierung im ersten mark(): `clock` wird vor `ms` ausgewertet (sysctl einmalig), `recorder`/`template()` (Bundle-Info, uname) danach; deren Kosten landen in den Abschnitten nach initStart. Sie gehören zum realen Startpfad, klein; Runde 2 sieht es am Gerät (initialization).
11. sim.sh: Absicherung gegen Prüfkennung vorhanden (Info.plist des lokalen Release-Bundles, `*.probe`, sim.sh:403-405); das `PIPESTATUS`-Idiom mit `set -eo pipefail` ist korrekt (wie Zeile 212/360), Abbruch bei devicectl-Fehler laut. Schwächen siehe F001, F002.

**Implementierer:** (Runde 1: keine Antwort, folgt)

### Runde 2
**Adversary:**

Nachrechnung reihe1-launch-timings.json (python3): 11 Einträge = 11 Starts (Protokoll "Kaltstart 1/11 ... 11/11", "bisher n Läufe" zählt 0..10 lückenlos), alle `kind: automated`, `zeroPoint: processStart`, build "0.1.0 (1)", device iPhone17,1, OS 27.0 (24A437). Gewertet 10: total Mittel 558,05 / Median 555,74 / Max 589,84; firstBuffer Mittel 649,5 / Max 681,9; Abschnittsmittel (processToInit 10,6; initialization 32,1; container 23,9; initToCapture 223,6; captureToSpeechStart 57,8; modelCheck 71,4; analyzer 13,5; engine 148,6) und alle 11 Rohzeilen stimmen mit der Berichtstabelle überein. Summe der Abschnitte (ohne container) weicht vom total um 0,1 bis 2,7 ms ab; "addieren sich" im Bericht ist im Rahmen der Zwischenzeiten richtig, kein Defekt. Release: Protokoll zeigt "Release-Prüfbau installiert.", "Konfiguration: Release (.../Release-iphoneos/LooseEnds.app)" und Schlusszeile "11 Läufe (Release)". Plausibilität: processToInit ~10 ms ab Lauf 2, Lauf 1 107 ms (kalte Caches), total 713 ms.
sim.sh: F001 behoben (cmd_launch_measure ruft cmd_device_build_release selbst, Ausgabe nennt Release). F002 behoben (launch_runs_on_device: Auflistungsfehler und Kopierfehler brechen ab, 0 nur bei fehlender Datei; beide Aufrufer `|| return 1`). F005: Ausgabe markiert den ersten Lauf nicht, der Bericht tut es; `-measureLaunch` kam am Gerät an (kind automated in allen 11). F003/F004 nicht aufgetreten (alle firstBuffer gesetzt, keine Ausreißer).
Bericht gegen Spec: Rohwerte je Lauf, Mittel/Median/Max, Abschnitte, Gerät, OS, Build, Nulllinie, beide Befunde vorhanden; ehrlich über Lücken (Systemanteil ungemessen, 558 ms als Untergrenze ohne Intent-Weg; Mindestgerät iPhone 15 Pro nur Näherung; Warmstart). 02 (offener Punkt 3) nennt 558 ms, 10 Läufe, Gerät; 04 (Zeilen 53-55) verweist auf den Bericht. AC-12: Mittel < 1 s, im Bericht ("Folge") ausdrücklich: kein Issue.
AC-8/Reihe 3: Entfall per PO-Entscheidung mit Zitat im Kontextdokument und im Bericht belegt, Verlust benannt. Als PO-Waiver akzeptiert.
Restvorbehalt AC-9: "danach unverändert" stützt sich auf die berichtete lesende Abfrage; Gerät durfte nicht erneut abgefragt werden. Der Code verhindert Berührung der Hauptkennung (.probe-Prüfung vor Start, Installation nur des .probe-Bundles). Akzeptiert.
**Implementierer:** F001/F002 behoben (Beleg 1); Reihe 2/3 per PO-Entscheidung entfallen.

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/sim.sh:398
  Description: `launch-measure` prüft nur, dass lokal `Release-iphoneos/LooseEnds.app` existiert und dessen Bundle-ID auf `.probe` endet. Gestartet wird aber die auf dem Gerät INSTALLIERTE App gleicher Kennung.
  Spec requirement: Risiken "Debug statt Release" — launch-measure bricht ab, statt falsche Zahlen zu liefern.
  Conflict: Wurde nach `device-build-release` zwischenzeitlich `device`/`device-build` (Debug, gleiche .probe-Kennung) installiert, misst das Werkzeug stillschweigend den Debug-Build; ein altes lokales Release-Verzeichnis genügt der Prüfung. Ein veralteter Release-Stand wird ebenfalls nicht erkannt.
  Remediation: Vor der Reihe Konfiguration/Version der installierten App prüfen (`devicectl device info apps` gegen lokales Bundle) oder die Konfiguration ins Feld `build` der Messdatei aufnehmen und im Bericht gegenprüfen; mindestens `device-build-release` unmittelbar vor `launch-measure` ausführen und die Konfiguration im Bericht nennen.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/sim.sh:388
  Description: `launch_runs_on_device` verwirft jeden Fehler von `devicectl device copy from` (`>/dev/null 2>&1 || true`) und meldet dann "0 Läufe".
  Spec requirement: Risiken "Gerät gesperrt" — launch-measure meldet das und bricht ab, nicht still; Abschnitt 4: Fehler laut.
  Conflict: Schlägt der Abruf des Ausgangsstands fehl (Gerät gesperrt, Verbindung), steht count=0 obwohl die Datei n>0 Läufe hat; die Warteschleife sieht beim nächsten gelungenen Abruf n>0 und wertet den Lauf als fertig, bevor der neue Eintrag geschrieben wurde (Zählung verschoben). Abruffehler in der Schleife erscheinen nur als Timeout nach 30 s ohne Ursache.
  Remediation: Unterscheiden zwischen "Datei existiert noch nicht" (0) und "Abruf fehlgeschlagen" (Fehler melden und abbrechen).

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/App/LaunchTimings.swift:53
  Description: Trifft der erste Puffer (`buffers == 1` im Tap, SpeechCapture.swift:322) vor dem `.listening`-Messpunkt ein, wird `firstBuffer` verworfen und nie nachgeholt; der Lauf wird nach 3 s mit `firstBuffer: null` geschrieben.
  Spec requirement: Abschnitt 1 — Schreiben beim ersten Puffer NACH listening, sonst Zeitlimit.
  Conflict: Praktisch kaum erreichbar (Pufferlänge 100 ms, zwischen engine.start und mark(.listening) liegt kein await), aber ein stiller Verlust des Zweitwerts ohne Test.
  Remediation: Kein Eingriff nötig; im Bericht vermerken, falls ein Lauf `firstBuffer: null` hat.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/App/LaunchTimings.swift:165
  Description: Jeder Prüfbau-Prozess erzeugt beim ersten `.listening` einen Eintrag, auch wenn die Erfassung manuell Minuten nach dem Start geöffnet wird; er trägt `kind: press` und ein `total` im Minutenbereich und ist von einem echten Control-Druck nicht zu unterscheiden.
  Spec requirement: AC-3/AC-8 — Zahl der Einträge = Zahl der Starts; 10 Einträge Laufart press.
  Conflict: Spec-konform (kein Defekt), aber Reihe 2 kann durch versehentliches manuelles Öffnen verunreinigt werden.
  Remediation: Im Bericht Ausreißer benennen und mit Hennings Ansage je Lauf abgleichen.

Finding:
  ID: F005
  Severity: LOW
  Category: spec_violation
  Code reference: scripts/sim.sh:419
  Description: Die Ausgabe von `launch-measure` listet alle Einträge der Datei (auch frühere press-Läufe und den ersten, zu verwerfenden Lauf) ohne Markierung.
  Spec requirement: AC-7 — erster Lauf verworfen, getrennt gekennzeichnet.
  Conflict: Das Werkzeug kennzeichnet nichts; die Trennung muss im Bericht von Hand erfolgen. Außerdem ist die Übergabe von `-measureLaunch` nach der Bundle-ID (sim.sh:411) ohne Gerät nicht verifizierbar (laut --help ist Passthrough von Kommandozeilenargumenten vorgesehen); der erste Gerätelauf in Runde 2 muss `kind: automated` zeigen.
  Remediation: Ersten Lauf im Bericht als verworfen kennzeichnen; beim ersten Gerätelauf `kind` prüfen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/App/LooseEndsApp.swift:13
  Evidence: Messpunkte initStart (13), containerStart (21), containerEnd (27), initEnd (34) über LaunchTimings.mark; jeder Aufruf emittiert ein OSSignposter-Event (LaunchTimings.swift:167) in jedem Build. Ohne Argument keine Verhaltensänderung (Zeile 15 nur bei -measureLaunch). Speech Stress offen (CI).
  Status: CONFIRMED (Code-Seite)

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/CaptureView.swift:135
  Evidence: captureAppeared (135) und speechStartCalled (138, im Task unmittelbar vor speech.start()); verhaltensgleich zum früheren `Task { await speech.start() }`. CaptureSmokeTests 17/17 und SpeechListeningTests 1/1 grün (regression-*.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Speech/SpeechCapture.swift:65
  Evidence: modelReady (65, nur im .ready-Zweig), analyzerStarted (177), engineStarted (206), listening (211), firstBuffer (322, Audio-Thread, ohne MainActor-Hop). Reihenfolge entspricht der Spec-Tabelle.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/App/LaunchTimings.swift:142
  Evidence: persist() prüft isProbeBuild vor jeder I/O; Test `persist` belegt Produktkennung = keine Datei, .probe = Datei. Auslöser firstBuffer/Timeout belegen writeOnFirstBuffer und writeOnTimeout (Zeit injiziert).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/App/LaunchTimings.swift:69
  Evidence: `written`-Schalter in take(); Test writeOnFirstBuffer (zweites firstBuffer, zweites listening, Timeout danach) ergibt genau 1 Lauf.
  Status: CONFIRMED (Unit; Gerät: Runde 2)

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/App/LaunchTimings.swift:117
  Evidence: append() dekodiert den Bestand und hängt an; Tests `append` (3 Läufe, alte unverändert) und `persist` (zwei Schreibvorgänge = 2 Läufe) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/App/LooseEndsApp.swift:15
  Evidence: -measureLaunch setzt CaptureRequest.shared.pending; LaunchArgumentTests 2/2 im eigenen Lauf (adversary-test-output.txt): Sheet ohne Tippen sichtbar, ohne Argument kein captureTextField.
  Status: CONFIRMED

Confirmation:
  AC: AC-5 (Code-Seite)
  Code reference: LooseEnds/App/LaunchTimings.swift:205
  Evidence: sysctl KERN_PROC_PID, p_starttime, zeroPoint .processStart; Fehler laut geloggt mit Rückfall .firstPoint; `total` = (nil, .listening). Wanduhr-Differenz einmalig (Date() vs. Uptime); Plausibilität von processToInit am Gerät in Runde 2 prüfen.
  Status: CONFIRMED (Code), Gerät offen

Confirmation:
  AC: Side effects
  Code reference: LooseEnds/App/LaunchTimings.swift:159
  Evidence: Ein Schreibvorgang pro Prozess auf eigener utility-Queue, nach erstem Puffer bzw. 3,05 s; keine Datei-I/O in Produktbauten; Verhalten ohne Argument unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-7/AC-9 (Werkzeug-Seite)
  Code reference: scripts/sim.sh:403
  Evidence: Bundle-ID-Prüfung `*.probe` vor jedem Start, nur die Prüfkennung, lesendes copy-from; devicectl-Fehler über PIPESTATUS mit pipefail laut (411-412). Einschränkungen siehe F001, F002.
  Status: CONFIRMED (mit F001/F002)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Runde 1: F001/F002 (MEDIUM) am Messwerkzeug gefunden; Runde 2 bestätigt sie am Code als behoben. F003-F005 LOW, nicht aufgetreten bzw. im Bericht abgedeckt. Zahlen im Bericht stimmen mit der JSON überein, Release belegt, AC-8 per PO-Entscheidung sauber abgebildet. Tests: 459 Unit + 2 LaunchArgument + 17 Smoke + 1 SpeechListening + Speech Stress 10/10 bestanden, 0 fehlgeschlagen, 0 übersprungen.

## Runde 2 Bestätigungen

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/App/LaunchTimings.swift:205
  Evidence: Gerät: zeroPoint processStart in allen 11 Läufen, processToInit ~10 ms (Lauf 1: 107 ms).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/sim.sh:407
  Evidence: launch-measure baut/installiert den Release-Prüfbau selbst; 11 Läufe kind automated, erster verworfen, 10 gewertet.
  Status: CONFIRMED

Confirmation:
  AC: AC-3 (Gerät)
  Code reference: LooseEnds/App/LooseEndsApp.swift:13
  Evidence: 11 Starts = 11 Einträge; Messpunkte LooseEnds/Speech/SpeechCapture.swift:211, LooseEnds/Views/CaptureView.swift:135, LooseEnds/App/LaunchTimings.swift:165.
  Status: CONFIRMED

Confirmation:
  AC: AC-10/AC-11/AC-12
  Code reference: scripts/sim.sh:389
  Evidence: Bericht, 02 Punkt 3 und 04 stimmen mit nachgerechneten Werten überein; kein Folge-Issue ausdrücklich festgehalten.
  Status: CONFIRMED

## Geprüfte Dateien

- sha256:879b6b750a041ac747b6dce587898199c2c28c06bc5b57522a5cc7f10f665836  LooseEnds/App/LaunchTimings.swift
- sha256:eee45063964da4f63ee950646c904f077e27f963e8606fff6c565f5a0d8bee46  LooseEnds/App/LooseEndsApp.swift
- sha256:e9c04644754408c91d151e0524e3181f47152907d55e9bddec575784d85e9dc9  LooseEnds/Speech/SpeechCapture.swift
- sha256:c82d67eb49b3a302e32ff09679e91eb9f81db6e0f627441364ec768c20787695  LooseEnds/Views/CaptureView.swift
- sha256:b4e149a7dc28ccf3dedadac387492917f25aa55bf1539c905381abce6abb4822  scripts/sim.sh

## Prüfbasis

- base: c0a95db8f7e190ca867db62773228bab92a54064
- blob:502b6de86e8566972f47a569f5808e59ca01f038  LooseEnds/App/LaunchTimings.swift
- blob:76ab4ca47f7d99295289de122a6db37d3173dbd0  LooseEnds/App/LooseEndsApp.swift
- blob:20dfb7ba0531135ac1f2c81560227636088d0b1f  LooseEnds/Speech/SpeechCapture.swift
- blob:493f8e4d1e8d697064a2c3b4c4853e0c78443a03  LooseEnds/Views/CaptureView.swift
- blob:da916b985efaa86a1a54b13cdefbc52367238186  scripts/sim.sh

## Geprüfte Dateien

- sha256:879b6b750a041ac747b6dce587898199c2c28c06bc5b57522a5cc7f10f665836  LooseEnds/App/LaunchTimings.swift
- sha256:eee45063964da4f63ee950646c904f077e27f963e8606fff6c565f5a0d8bee46  LooseEnds/App/LooseEndsApp.swift
- sha256:e9c04644754408c91d151e0524e3181f47152907d55e9bddec575784d85e9dc9  LooseEnds/Speech/SpeechCapture.swift
- sha256:c82d67eb49b3a302e32ff09679e91eb9f81db6e0f627441364ec768c20787695  LooseEnds/Views/CaptureView.swift
- sha256:13c51916e112f9aa3ffc5020e96785ee20704abb35c7067b341744e3b49bff68  scripts/sim.sh

## Prüfbasis

- base: c03dcf40dff737447cd6de3a2379312a0539f197
- blob:502b6de86e8566972f47a569f5808e59ca01f038  LooseEnds/App/LaunchTimings.swift
- blob:76ab4ca47f7d99295289de122a6db37d3173dbd0  LooseEnds/App/LooseEndsApp.swift
- blob:20dfb7ba0531135ac1f2c81560227636088d0b1f  LooseEnds/Speech/SpeechCapture.swift
- blob:493f8e4d1e8d697064a2c3b4c4853e0c78443a03  LooseEnds/Views/CaptureView.swift
- blob:66a3bcaf9a685115345b9fa62f56efab7a75f6b2  scripts/sim.sh
