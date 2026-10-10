# Context: 279a-sprachstart-latenz

## Request Summary
#279 Teil A (Henning, 2026-10-10, Intake): Zwei Dinge stören in Build 25 noch. Erstens dauert es vom Antippen bis zum ersten
erkannten Wort 2–3 s. Zweitens kommen die Wörter in Schüben (zwei Wörter, dann nach einer Pause ein Block). Gewählter Weg:
**erst messen und die Wartezeit zerlegen, dann beschleunigen.** „Ich höre …“ und der Ring (#279 B/C, #297) bleiben unverändert.

**Hat es bisher funktioniert?** Nein. Im Alltag waren es immer 2–3 s (Henning, 2026-10-10). Build 22 (`.fastResults`, #274)
hat daran nichts geändert. Die 12–14 s aus #274 waren ein Sonderfall (Mac, Prüfbau). Es gibt also keinen Rückschritt,
den man über die Git-Historie eingrenzen könnte.

## Recherche (Quellen)
- **Apple, SpeechAnalyzer-Doku** (developer.apple.com/documentation/speech/speechanalyzer): „By default, the analyzer and
  modules load the system resources that they require lazily, and unload those resources when they're deallocated. To
  proactively load system resources and 'preheat' the analyzer, call `prepareToAnalyze(in:)` … This may improve how quickly
  the modules return their first results. To delay or prevent unloading … select a `ModelRetention` option“
  (`.whileInUse` / `.lingering` / `.processLifetime`, über `SpeechAnalyzer.Options`). Und: „Modules deliver results
  periodically, but you can manually synchronize … call `finalize(through:)`.“
- **Apple-Forum 794720** (SpeechTranscriber langsam): ohne Vorwärmen 2,2 s, mit `prepareToAnalyze` 1,45 s im Mittel
  (0,05–3 s). Apple empfiehlt `prepareToAnalyze` und `[.volatileResults, .fastResults]`. Die große Streuung hängt mit einer
  kalten Neural Engine zusammen.
- **DEV Community / simplememofast** („5 things the docs don't tell you“): warm, iOS 26.5, iPhone 16e: erstes Teilergebnis
  nach 0,3–0,5 s. Das Mikrofon liefert 48 kHz, das Umrechnen auf 16 kHz kostet etwa 200 ms. Ein Tap gleich in 16 kHz mono
  spart das.
- **SDK iOS 27 (swiftinterface)**: `SpeechAnalyzer.Options(priority:modelRetention:ignoresResourceLimits:)`,
  `AssetInventory.reserve(locale:)`. Alternativ-Modul `DictationTranscriber` mit den Presets `progressiveShortDictation` und
  `ReportingOption.frequentFinalization` (gegen Schübe?).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Speech/SpeechCapture.swift` | Der ganze Start: `start()` (Modellstatus → Rechte → `begin`), `begin()` (Konverter, **neuer** `SpeechAnalyzer` je Öffnen, ohne `prepareToAnalyze` und ohne `Options`; Audio-Session **nach** dem Analyzer; Engine/Tap mit 100 ms Puffer), `collect()` (flüchtig ersetzt flüchtig, fest wird angehängt), `stop()` (Analyzer `cancelAndFinishNow`, alles verworfen) |
| `LooseEnds/Views/CaptureView.swift:193` | `begin()` → `speech.noteOpened()` + `speech.start()` beim Erscheinen der Erfassung. Jede Erfassung hat eine neue `SpeechCapture` (`@State`) |
| `LooseEnds/Speech/SpeechDiagnosis.swift` | `SpeechTimings` (fünf Strecken: Öffnen, Modell, Rechte, Analyzer, Mikrofon, dazu `firstResult`). Die Zeile erscheint nur bei Start ≥ 3 s oder erstem Ergebnis ≥ 6 s, Hennings 2–3 s bleiben also darunter: **keine Gerätezahlen vorhanden** |
| `LooseEnds/App/LaunchTimings.swift` | Signposts `captureAppeared … firstBuffer`. Die JSON-Datei gibt es nur im Prüfbau |
| `docs/artifacts/fix-274-spracheingabe-latenz/probe.swift`, `run.sh` | Mac-Versuchsaufbau: Ton per `say` in 100-ms-Paketen in Echtzeit, Zeit bis zum ersten Ergebnis je Variante. Grundlage für die Zerlegung ohne Gerät |
| `LooseEndsTests/…SpeechLatency…` (aus #274) | Prüft `transcriberReportingOptions` |
| `docs/specs/fix-274-*.md`, `docs/specs/feat-64-speechanalyzer.md` | Vorgeschichte, Strecken-Definition |

## Existing Patterns
- Ein Ort baut den Transcriber (`makeTranscriber`), Test und Probe gehen auch darüber.
- Messung über `ContinuousClock` und Logger mit `privacy: .public`. Unter `--ui-testing` startet keine Erkennung.
- `stopCount`-Ticket schützt vor dem Öffnen des Mikrofons nach einem Abbruch (#184). Jede Vorwärm-Lösung muss das erhalten.
- Tap-Rückruf `nonisolated` (Absturzklasse `dispatch_assert_queue`, #60/#184).

## Dependencies
- Upstream: Speech (`SpeechAnalyzer`, `SpeechTranscriber`, `AssetInventory`, `AnalyzerInputConverter`), AVFAudio (`AVAudioEngine`, `AVAudioSession` `.record`/`.measurement`)
- Downstream: `CaptureView` (Transkript, Waveform, `ListeningHint`, Diagnosezeile), UI-Smoke- und Speech-Stress-Tests (CI)

## Hypothesen für die Zerlegung (noch nicht gemessen)
1. **Kaltstart des Modells je Öffnen**: Der Analyzer wird bei jedem Öffnen neu gebaut, ohne Vorwärmen und ohne Retention.
   Bei `stop()` gibt er seine Ressourcen frei (`whileInUse`).
2. **Reihenfolge**: Analyzer-Start, Audio-Session und Engine laufen nacheinander statt parallel.
3. **48 → 16 kHz** im Wandler (laut Bericht ~200 ms).
4. **Schübe**: Der Transcriber liefert Ergebnisse „periodisch“. Ob trotz `.fastResults` Blöcke entstehen, ist offen; Mac-Probe
   mit natürlichem Satz und Pausen fahren. Gegenmittel laut Doku: `finalize(through:)` bzw. `DictationTranscriber` mit
   `frequentFinalization`.

## Alternativen (Henning: in Alternativen denken)
- Vorwärmen beim Öffnen der Erfassung (`prepareToAnalyze`) — klein, im bestehenden Ablauf.
- Vorwärmen schon beim App-Start bzw. Analyzer mit `.lingering`/`.processLifetime` halten. Schneller, kostet aber Speicher
  und Strom, Mikrofon bleibt trotzdem zu.
- Anderes Modul (`DictationTranscriber`), kippt die Modulwahl aus #64.
- Nichts bauen, nur messen: Liegt der Rest in Teilen, die die App nicht beeinflusst (Mikrofon-Hardware), bleibt es beim
  Überbrücken (#297).

## Risks & Considerations
- **Messort**: Der Simulator hat das Modell nur eingeschränkt ([[Simulator hat ein Modell]], CI „modelNotReady“), die Mac-Probe
  ist der verlässliche Zerlegungsort (Erkenntnis #274). Gerät nur über TestFlight und nur nach „jetzt ist ein Test möglich“.
  Ein Messkanal vom Gerät fehlt (#160). Die Diagnosezeile zeigt die Strecken erst ab 3 s.
- Vorwärmen darf das Mikrofon nicht früher öffnen (Datenschutz-Anzeige, #184-Ticket).
- Stufe 3 ist Pflicht (`LooseEnds/Speech/` berührt).
- Eine Retention über den Prozess hält das Modell im Speicher, auch für Widgets/Share ist das irrelevant (eigene Prozesse).

## Analysis

### Type
Feature (Verbesserung, kein Rückschritt: im Alltag waren es immer 2–3 s)

### Zerlegung der Wartezeit (gemessen)
Messaufbau: `docs/artifacts/279a-sprachstart-latenz/` (`zerlegung.swift`, `run.sh`, `qualitaet.sh`, Ergebnisse
`messung-mac.txt`, `qualitaet-mac.txt`). Nachbau des App-Wegs aus `SpeechCapture.begin` auf dem Mac (macOS 27.0.1):
Transcriber → `AnalyzerInputConverter` → `SpeechAnalyzer.start`, Ton in 48 kHz mono, 100-ms-Pakete in Echtzeit mit
`AVAudioTime`, 1 s Stille vor dem Satz. Kein Ton abgespielt (`say -o`).

| Strecke | Wert | Quelle |
|---|---|---|
| App-Start bis „Mikrofon hört“ | 0,56 s | Gerät, Prüfbau, #22 |
| davon Modellstatus, Konverter, Analyzer-Start | < 0,01 s | Mac, diese Messung |
| Nutzer beginnt zu sprechen | unbekannt, Annahme 0,5–1 s | — |
| Sprechbeginn bis erstes Wort | 0,6 s (Gerät, #274 Lauf 5); 0,63–1,32 s (Mac) | |
| Takt der Ergebnisse | **fest ~1 s**, je Takt bis 4 Wörter | Mac |

Summe 0,56 + 0,5–1 + 0,6–1,3 ≈ 1,7–2,9 s: deckt Hennings 2–3 s. **Der Takt ist der Hebel, den die App beeinflussen
kann; der Start (0,56 s) ist klein und durch Vorwärmen nicht zu drücken.**

**Schübe, Ursache belegt:** `SpeechTranscriber` liefert unabhängig von den Optionen etwa einmal pro Sekunde
(Mac: `0.91:+2  1.92:+4  2.92:+1  4.82:+4  5.71:+3 …`). Genau Hennings Bild „zwei Wörter, dann nach einer Pause ein
Block“. Das erste Wort hängt davon ab, wo der Sprechbeginn im Takt liegt (Vorlauf 1,0 / 1,3 / 1,6 s → 0,91 / 0,63 /
1,32 s).

### Varianten (Mac, Satz „Morgen um zehn Uhr den Zahnarzt anrufen … nicht vergessen“, je 2 Öffnungen)
| Variante | erstes Wort | größter Schub | längste Pause | Bemerkung |
|---|---|---|---|---|
| App heute (`SpeechTranscriber`, volatile + fast) | 0,90–0,92 s | 4 Wörter | 1,9 s | |
| + `prepareToAnalyze` | 0,91–0,92 s | 4 | 1,9 s | kein Effekt (auch Gerät #274 Lauf 5) |
| + `modelRetention .processLifetime` | 0,91–0,92 s | 4 | 1,9 s | kein Effekt |
| direkt 16 kHz statt Konverter | 0,92–0,93 s | 4 | 1,9 s | kein Effekt (die „200 ms“ aus dem Blog nicht bestätigt) |
| Preset `.progressiveTranscription` | 0,90–0,91 s | 4 | 1,9 s | kein Effekt |
| `finalize(through:)` alle 300 ms | 1,11 s | — | — | zerstört die Erkennung (1 Wort) |
| **`DictationTranscriber` `.progressiveShortDictation`** | **0,73–0,74 s** | **1 Wort** | 1,2 s (echte Sprechpause) | Wort für Wort alle 0,2–0,5 s |
| `DictationTranscriber` + `.frequentFinalization` | 0,70–0,71 s | 1 | 1,2 s | wie oben, Satzzeichen fehlen eher |

Erkennungsgüte, 10 typische Aufgabensätze (synthetische Stimme, kleine Stichprobe): `SpeechTranscriber` 7,2 %
Wortfehler (5/69, „LinkedIn“ → „Lynn geht in“), `DictationTranscriber` 5,8 % (4/69, „Quartals Meeting“ getrennt).
Gegenstimme: Apple (WWDC25 277) nennt `DictationTranscriber` den Rückfall für nicht unterstützte Sprachen/Geräte,
gleiches Modell wie das On-Device-`SFSpeechRecognizer` seit iOS 10; ein Blog spricht von mehrfacher Fehlerrate.

### Quellen
- WWDC25 Session 277, „Bring advanced speech-to-text to your app with SpeechAnalyzer“ (developer.apple.com/videos/play/wwdc2025/277)
- Apple-Doku SpeechAnalyzer (`prepareToAnalyze`, `ModelRetention`, `finalize(through:)`)
- Apple-Forum 794720 / 795924 (Latenz, Vorwärmen)
- DEV Community, simple_memo: warm 0,3–0,5 s bis zum ersten Teilergebnis (iPhone 16e, iOS 26.5)

### Strategische Bewertung (Plan-Agent) und Einordnung
- Gegenbefund: Auf dem Gerät kam das erste Wort in #274 Lauf 5 schon 0,6 s nach Sprechbeginn (ein Lauf, Konferenzton,
  Prüfbau). Ob das Gerät denselben 1-s-Takt hat, ist **nicht gemessen**; Hennings Beschreibung („zwei Wörter, dann ein
  Block“) passt aber genau auf das Mac-Bild. Die Diagnosezeile zeigt Zeiten erst ab 3 s Start / 6 s erstes Wort, darum
  gibt es keine Gerätezahlen für 2–3 s.
- Korrektur zum Agenten: `DictationTranscriber` setzt Kommas („Milch, Brot“, „fragen, ob“), nur den Schlusspunkt nicht.
  #297 („Ich höre …“) ist schon ausgeliefert, also keine offene Brücke mehr.
- Wer `DictationTranscriber` nimmt, kippt die Modulwahl aus #64 (`docs/specs/feat-64-speechanalyzer.md`), nicht das
  Framework: es bleibt `SpeechAnalyzer` + `AssetInventory`.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | Modul wählbar (`SpeechTranscriber` / `DictationTranscriber .progressiveShortDictation`) an der einen Stelle `makeTranscriber`; `collect` für beide Ergebnistypen; Takt messen (Abstand der Ergebnisse) |
| `LooseEnds/Speech/SpeechDiagnosis.swift` | MODIFY | Zeitzeile für den Gerätetest ohne Schwelle: Antippen→erstes Wort, Start, längste Pause zwischen Ergebnissen |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | Zeitzeile im Testbau anzeigen |
| `LooseEndsTests/SpeechLatencyTests.swift` | MODIFY | Takt-Test im Simulator mit Fixture: größter Schub ≤ 2 Wörter, keine Ergebnislücke > 0,6 s beim Sprechen |
| (ggf.) Einstellungs-View | MODIFY | nur bei Weg „Umschalter“: temporärer Testschalter |

### Scope Assessment
- Files: 4–5
- Estimated LoC: +150–250 / −20 (Umschalter an der Obergrenze)
- Risk Level: MEDIUM — Spracherfassung ist zentral, Absturzklasse #184/#60 (Tap `nonisolated`, `stopCount`) muss erhalten
  bleiben, Modell-Assets für `DictationTranscriber` auf dem iPhone ungeprüft (Mac meldet für das Kommandozeilenprogramm
  `supported`, die App verlangt `installed` → evtl. „Modell laden“-Zeile). Stufe 3 Pflicht (`LooseEnds/Speech/`).

### Technical Approach
Empfehlung: **ein TestFlight-Bau mit Zeitzeile und temporärem Umschalter** zwischen heutigem Erkenner und
wortweisem Erkenner (`DictationTranscriber`). Henning spricht dieselben Sätze mit beiden, liest die Zeitzeile ab und
entscheidet nach Gefühl und Zahl; ein Folgeschnitt entfernt Schalter und Zeile und behält den Gewinner. Begründung:
Nur ein anderes Modul ändert den Takt (alle anderen Hebel gemessen ohne Wirkung); die Qualität des älteren Modells auf
echter Stimme lässt sich nur auf dem Gerät beurteilen; ein Bau statt zwei Runden.

Alternativen:
- (b) Erst nur Messbau (Zeitzeile ohne Schwelle), Erkenner danach entscheiden (Plan-Agent). Sauberer, aber zwei
  TestFlight-Runden.
- (c) Direkt auf `DictationTranscriber` umstellen, mit Zeitzeile. Schnellster Weg, kein Rückweg ohne neuen Bau.
- (d) Hybrid: beide Module in einem Analyzer, wortweise live, Endtext vom heutigen Modell. Doppelte Last, Text springt
  beim Beenden, sprengt eher das Limit.
- (e) Nichts bauen: Start (0,56 s) und Reaktionszeit sind ohnehin nicht zu holen; Schübe bleiben.

### Dependencies
Speech (`SpeechAnalyzer`, `SpeechTranscriber`, `DictationTranscriber`, `AssetInventory`, `AnalyzerInputConverter`),
AVFAudio. Downstream: `CaptureView`, `SpeechLatencyTests`, UI-Smoke (Diagnose-Fixture `--ui-testing-speech-diagnosis`).

### Entscheidung (Henning, 2026-10-10)
**„Nichts ändern“ (Weg e).** Die Schübe bleiben, der Erkenner bleibt `SpeechTranscriber`. Keine Spec, kein Bau.
#279 Teil A ist damit mit Messbefund beantwortet. Wer das Thema neu aufgreift, startet bei der Variantentabelle oben
und dem Messaufbau `docs/artifacts/279a-sprachstart-latenz/` (offen wäre dann: `AssetInventory.status` für
`DictationTranscriber` auf dem iPhone und die Qualität auf echter Stimme).
