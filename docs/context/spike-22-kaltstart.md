# Context: spike-22-kaltstart (#22 Kaltstart in die Erfassung unter einer Sekunde)

## Request Summary
Messen, ob die Erfassung nach einem Kaltstart über das Kontrollzentrum bzw. die Aktionstaste auf einem
iPhone 15 Pro (oder neuer als Näherung, Hennings iPhone 16 Pro) in unter einer Sekunde eingabebereit ist
(Mikrofon hört, Textfeld als Alternative). Zehn Läufe, Mittelwert und Ausreißer. Wird das Ziel verfehlt:
Ursache eingrenzen und ein Folge-Ticket mit Optimierungsvorschlag anlegen. Ergebnis in
`docs/project/02-datenmodell-und-ansichten.md` (offener Punkt 3) und `04-stand.md`.

## Recherche (2026-10-08, Quellen)
| Frage | Befund | Quelle | Status |
|---|---|---|---|
| Offizielle Startmessung | Instruments „App Launch“ und `OSSignposter` sind der Standard; Apple DTS rät zu Instruments und Time Profiler | [Forum 761677](https://developer.apple.com/forums/thread/761677) | belegt |
| `XCTApplicationLaunchMetric` | aktuell, misst bis zum ersten Frame bzw. `waitUntilResponsive` | [Apple-Doku](https://developer.apple.com/documentation/xctest/xctapplicationlaunchmetric.md) | belegt |
| MetricKit extended launch | `extendLaunchMeasurement(forTaskID:)` existiert, liefert aber nur Histogramme mit Verzögerung bis 1 Tag. Für 10 Einzelläufe ungeeignet | [Zusammenfassung](https://skills.sh/dpearson2699/swift-ios-skills/metrickit) | API belegt, Eignung geschlossen |
| Apple-Ziel erster Frame | 400 ms (davon ~100 ms System) | [WWDC19 423](https://developer.apple.com/videos/play/wwdc2019/423/), [WWDC23 10196](https://developer.apple.com/videos/play/wwdc2023/10196) | belegt |
| Kaltstart automatisiert | `devicectl device process launch --terminate-existing` startet neu, aber über CoreDevice, nicht über die Intent-Pipeline. Liefert damit nur eine Untergrenze | [Forum 756393](https://developer.apple.com/forums/thread/756393) | Befehl belegt, Pfadunterschied Vermutung |
| Control/Aktionstaste automatisiert auslösen | Nichts gefunden. Bleibt vermutlich ein manueller Schritt (Henning drückt) | — | offen |
| Systemzeit vor erstem App-Code bei Control/Intent | Keine Zahlen; Forenbericht „mehrere Sekunden“ bei nicht laufender App (iOS 18). DTS: Minimal-App als Basis messen | [Forum 761677](https://developer.apple.com/forums/thread/761677) | offen |
| Signposts ohne GUI | `xcrun xctrace record --device <UDID> --template … --launch/--attach`, dann `xctrace export --toc`/`--xpath`; auf Geräten bekannte Hänger | [Forum 720361](https://developer.apple.com/forums/thread/720361), [Forum 687944](https://developer.apple.com/forums/thread/687944) | Form belegt, am Probelauf prüfen |
| SpeechAnalyzer-Vorlauf | `prepareToAnalyze(in:)` lädt vor; Blog: warm ~0,3–0,5 s bis zum ersten Ergebnis (iPhone 16e, iOS 26.5). Für iPhone 15 Pro, iOS 27, kalt keine Zahl | [Apple-Doku](https://developer.apple.com/documentation/speech/speechanalyzer.md), [WWDC25 277](https://developer.apple.com/videos/play/wwdc2025/277/), [Blog](https://dev.to/simple_memo/ios-26s-speechanalyzer-on-a-live-mic-the-5-things-the-docs-dont-tell-you-2ng5) | Blogzahl, nicht Apple |
| `ModelContainer` mit CloudKit | keine Zahlen, keine Apple-Empfehlung gefunden | — | offen, messen |

## Ist-Zustand des Startpfads (Code)
| Schritt | Ort | Befund |
|---|---|---|
| Auslöser | `LooseEndsWidgets/CaptureControl.swift:6-15` (`ControlWidgetButton(action: OpenCaptureIntent())`), `Shared/Intents/CaptureTextIntent.swift:23-32` (`openAppWhenRun = true`, `perform()` setzt nur `CaptureRequest.shared.pending`) | Aktionstaste ist abgedeckt, wenn dort das Control liegt |
| App-Init, synchron auf dem MainActor | `LooseEnds/App/LooseEndsApp.swift:11-23` | `ModelContainerFactory.make()` (App-Gruppe + CloudKit), Enricher, `DueNotificationCenter.activate()`, `CalendarBridge` |
| „Erfassungs-Szene“ | `LooseEnds/App/ContentView.swift:55-57, 73-74, 161-165` | **Keine eigene Szene**: ein `.sheet` über der vollen Hauptansicht (`NavigationSplitView`, `@Query`), geöffnet in `onAppear`/`onChange(pending)`. Widerspricht ADR-9 („schlanke Erfassungs-Szene, kein Tab, kein Laden“) |
| Parallel beim Start | `ContentView.swift:63, 107-129` `startUp`-Task | Seeder, `mergeDuplicateContexts`/`mergeEnglishDefaults` + `save()` (synchron auf dem MainActor), `processPending`, Mitteilungs-Freigabe, `reschedule`, `calendar.sync` |
| Onboarding | `ContentView.swift:15, 59` | `fullScreenCover` konkurriert beim allerersten Start mit dem Sheet |
| Erfassung | `LooseEnds/Views/CaptureView.swift:73, 134-140` | `onAppear` → `speech.start()`; **Textfeld wird nicht fokussiert**, solange Sprache gewollt ist (nur bei `.unavailable` bzw. unter UI-Tests) |
| Sprache bis „hört“ | `LooseEnds/Speech/SpeechCapture.swift:48-86, 172-210` | Locale → `AssetInventory.status` (nur `.ready` geht weiter) → Rechte → `SpeechAnalyzer` + `start(inputSequence:)` → AudioSession → `AVAudioEngine` + Tap → `engine.start()` → **`state = .listening`** (:208). Erster Ton: Log „Ton kommt an“ (:319-320) |

## Existing Patterns
- Logging nur über `Logger` (Subsystem `com.henning.looseends`, Kategorien App, Capture, Speech, Persistence …). Kein `os_signpost`, kein MetricKit, kein Messtest.
- `MainThreadWatchdog` (`LooseEnds/App/MainThreadWatchdog.swift`) nur unter UI-Tests: meldet blockierten Main-Thread > 1 s.
- Geräte-Rückkanal: `sim.sh device`, `device-launch` (`--terminate-existing`), `device-console [sek]` (startet mit `--console`); Daten nur lesend per `devicectl device copy from` (bewährt in #226 Schnitt 2b).
- UI-Tests: `CaptureSmokeTests` (mit `--ui-testing`, ohne Sprache), `SpeechListeningTests` (ohne `--ui-testing`, mit Sprache). Keiner startet über `OpenCaptureIntent`, keiner misst Zeit.

## Dependencies
- Upstream: `OpenCaptureIntent`/`CaptureRequest`, `ModelContainerFactory`, `ContentView` (Sheet), `CaptureView`, `SpeechCapture` (SpeechAnalyzer seit #64), `OnboardingFlow`.
- Downstream: ADR-9 und Entscheidung #19 (`docs/project/00-entscheidungen.md:127-133, :50`), offener Punkt 3 in `02-datenmodell-und-ansichten.md:286`, Ticket #24 (Mail-Share) unberührt.

## Existing Specs
- `docs/specs/feat-64-speechanalyzer.md:84-110` (Ablauf `start()`, keine Startzeitaussage; das Modell wird nie automatisch geladen)
- Keine Spec zur Erfassungs-Szene als eigener Szene.

## Risks & Considerations
- **Messpunkte berühren `LooseEnds/Speech/` und den App-Start** → Geräteliste greift (Stufe 3 Pflicht). Gemessen wird ohnehin auf dem Gerät.
- **Der echte Pfad (Control/Aktionstaste) ist nicht automatisierbar.** Henning muss pro Lauf drücken, das sind 10 Drücke. `devicectl` misst nur die Untergrenze ohne Intent-Pipeline. Zu klären, ob beides gemessen wird und wie sich der Systemanteil vor dem ersten App-Code fassen lässt (Signpost am Prozessstart über `ProcessInfo`/`kinfo_proc`-Startzeit oder `xctrace --attach`).
- **„Eingabebereit“ ist im Code nicht definiert**: Ohne geladenes Modell bleibt `.needsModel` (kein Fokus, kein Mikrofon). Definition fürs Messen nötig, z. B. „`state == .listening` oder Textfeld fokussiert“.
- **Kaltstart = Prozess beendet**, nicht nur Hintergrund. Ein warmer Start (App suspendiert) ist ein anderes Maß und muss getrennt genannt werden.
- Das Ergebnis kann eine Architekturfrage aufwerfen: eigene schlanke Szene statt Sheet über der Hauptansicht, `startUp` hinter die Eingabebereitschaft verschieben. **Nicht in diesem Spike umsetzen**, sondern als Folge-Ticket. Der Spike misst und grenzt ein.
- Scoping: Messpunkte (Signposts) sollen im Produkt bleiben dürfen (kostenarm, Release-tauglich), damit sich die Messung wiederholen lässt (#73 Dauerlauf).
- Alternativen für die Analyse: (A) Signposts + `devicectl`-Kaltstarts automatisiert + wenige manuelle Control-Drücke; (B) nur Logger-Zeitstempel über `device-console`; (C) `XCTApplicationLaunchMetric` in einem Geräte-UI-Test (scheidet laut #153 wegen Eingriff in Hennings Installation eher aus, prüfen mit Prüfkennung); (D) Hochgeschwindigkeitsvideo vom Druck bis Mikrofon-Anzeige (unabhängig von App-Code, misst auch Systemanteil).

## Analysis

### Type
Spike (Messung), featureartig: neue Messpunkte im Startpfad und ein Messbefehl. Keine Verhaltensänderung, keine Optimierung.

### Befunde aus der Analyse (2026-10-08)
- **Prüfbau ist Debug.** `cmd_device_build` (`scripts/sim.sh:332-338`) baut ohne `-configuration`, also Debug. Debug-Startzeiten taugen nicht für „unter 1 s“ (unoptimiert, Debug-Dylib). Gemessen wird im **Release-Prüfbau** (`BUNDLE_ID_SUFFIX=.probe`, gleiche Entwicklungssignierung). Debug nur für den Trockenlauf.
- **`device-launch`/`device-console` starten die gebaute App** (Bundle aus dem gebauten `Info.plist`, `sim.sh:357, 375`), also den Prüfbau. Hennings TestFlight-Installation bleibt unberührt (#153).
- **Der echte Druck trägt kein Startargument.** Messpunkte, die nur mit Startargument schreiben, sehen den Control-Druck nie. Deshalb: Signposts immer (kostenarm), Zeitstempel-Datei nur im Prüfbau (Kennung endet auf `.probe`), geschrieben **einmal** beim Erreichen von `.listening`, nicht pro Punkt (Datei-I/O im Startpfad verfälscht).
- **Startargument öffnet die Erfassung** (für die automatisierten `devicectl`-Läufe): in `LooseEndsApp.init` `CaptureRequest.shared.pending` setzen, dann ist `ContentView` nicht zu ändern.
- **Nullpunkt = Prozessstart** (`sysctl` `KERN_PROC_PID` → `kp_proc.p_starttime`), damit die Zeit vor `main` (dyld) mitzählt. Die Zeit vom Tastendruck bis zum Prozessstart sieht kein App-Code; sie wird nur als Differenz echter Druck ↔ `devicectl`-Lauf sichtbar.
- **„Eingabebereit“ = `SpeechCapture.state == .listening`** (`SpeechCapture.swift:208`), Zweitwert erster Audiopuffer (:320). Das Textfeld wird bei gewollter Sprache **nicht fokussiert** (`CaptureView.swift:134-140`), ADR-9 sagt „Textfeld fokussiert“. Wird als Befund berichtet, nicht in diesem Spike geändert.
- **Kalt = Prozess beendet** (Alltagsfall nach Speicherdruck). „Nach Neustart“ ist ein strengerer Fall (dyld-Caches kalt), wird mit 1–2 Läufen als Ausreißerprobe genannt. Warm (suspendiert) getrennt.
- Erster Lauf nach Installation wird verworfen (Onboarding, Rechtedialoge). Vorbedingung: Sprachmodell installiert (sonst `.needsModel`, gemessen würde die falsche Strecke).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/App/LaunchTimings.swift` | CREATE | `OSSignposter` + Zeitstempel ab Prozessstart, JSON `Documents/launch-timings.json` nur im Prüfbau, einmal geschrieben bei `.listening` (~70 LoC) |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | Messpunkte `init` Anfang/Ende, um `ModelContainerFactory.make()`; Startargument setzt `CaptureRequest.shared.pending` (~15 LoC) |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | Messpunkt Erfassung erscheint, `speech.start()` aufgerufen (~5 LoC) |
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | Messpunkte Modell bereit, Analyzer gestartet, `engine.start`, `.listening`, erster Puffer (~10 LoC) |
| `scripts/sim.sh` | MODIFY | Release-Variante des Prüfbaus, `launch-measure <n>` (n Kaltstarts per `--terminate-existing` + Startargument) und Abholen der Datei per `devicectl copy from` (~50 LoC) |
| `docs/project/02-datenmodell-und-ansichten.md`, `docs/project/04-stand.md` | MODIFY | Ergebnis (offener Punkt 3), Stand |
| Messbericht `docs/reference/kaltstart-messung.md` | CREATE | Rohwerte je Lauf, Mittelwert, Median, Maximum, Gerät, OS, Build |

### Scope Assessment
- Code-Dateien: 5 (eine neu), Docs: 3
- Estimated LoC: ~+150/-5 Code
- Risk Level: MEDIUM — berührt den Startpfad und `LooseEnds/Speech/` (Geräteliste, Stufe 3 Pflicht); Messpunkte selbst ändern kein Verhalten

### Technical Approach (Empfehlung)
Release-Prüfbau mit Messpunkten. Zwei Messreihen:
1. **Untergrenze, automatisiert:** 10 Kaltstarts per `devicectl --terminate-existing` mit Startargument, 10 Warmstarts. Ich fahre sie selbst, Henning hält das iPhone nur entsperrt im WLAN.
2. **Echter Weg:** 10 Drücke auf das Control des Prüfbaus (Kontrollzentrum oder Aktionstaste, vorübergehend umbelegt). Danach die App jeweils im App-Umschalter beenden. Die Datei sammelt alle Läufe, ich hole sie ab.
Auswertung: Abschnitte je Messpunkt (Prozessstart → `init` → Container → Erfassung sichtbar → Sprache hört). Bei Verfehlung zeigt der größte Abschnitt die Ursache, daraus ein Folge-Ticket.

Reihenfolge: Messpunkte + Debug-Trockenlauf → Release-Variante → Reihe 1 → Reihe 2 (Henning) → Auswertung, Docs, ggf. Folge-Ticket.

### Alternativen
- **Video statt Code (D):** zweites Gerät filmt Druck bis Mikrofon-Anzeige mit 240 fps. Misst die Nutzersicht inklusive Systemanteil, grenzt aber keine Ursache ein und ist Handauswertung. Kippt die Annahme, Messpunkte im Code reichen. Sinnvoll als Gegenprobe für 3–5 Läufe, falls die Systemzeit vor dem Prozessstart groß aussieht.
- **Minimal-App als Systembasis (Apple DTS):** leere App mit gleichem Control. Liegt sie schon über 1 s, ist das Ziel unabhängig vom eigenen Code unerreichbar, und das Ergebnis lautet „Budget in ADR-9 anpassen“ statt „optimieren“. Eigenes Target, nur wenn Reihe 2 knapp verfehlt.
- **Nur Instruments „App Launch“ (C):** am wenigsten Code, aber GUI-gebunden, nicht wiederholbar (#73 Dauerlauf).
- **Grundsätzlich:** ADR-9 verlangt eine schlanke Erfassungs-Szene; heute ist es ein Sheet über der vollen Hauptansicht. Statt zu messen, könnte man direkt umbauen. Abgelehnt: ohne Messung wissen wir nicht, ob der Umbau nötig ist oder die Zeit im Sprachteil steckt.

### Dependencies
`OpenCaptureIntent`/`CaptureRequest`, `ModelContainerFactory`, `CaptureView`, `SpeechCapture`, `sim.sh` Gerätebefehle, Prüfkennung (#156). Downstream: ADR-9, Entscheidung #19, offener Punkt 3.

### Open Questions
- [x] PO: Übernimmt Henning Reihe 2? **Ja (2026-10-08): 10 Drücke auf das Control des Prüfbaus, Aktionstaste vorübergehend umbelegt, danach zurück.** Claude stellt das Control bereit und sagt pro Lauf an, wann gedrückt wird; nach jedem Druck App im App-Umschalter schließen.

## Umfang (Henning, 2026-10-08)
Umsetzung ergab ~440 LoC (LaunchTimings ~220, sim.sh ~60, Tests ~150) statt ±250. Henning hat entschieden:
„So lassen" — ein Ticket, kein Abspalten des Messbefehls.

## Reihe 2 und 3 entfallen (Henning, 2026-10-08)
Auf die Bitte um zehn Drücke auf das Control des Prüfbaus antwortete Henning: „schließe das ab, das brauche ich
nicht“. Abgeschlossen mit Reihe 1 (558 ms, `docs/reference/kaltstart-messung.md`); AC-8 entfällt per PO-Entscheidung,
der Systemanteil vor dem Prozessstart bleibt ungemessen und steht so im Bericht.
