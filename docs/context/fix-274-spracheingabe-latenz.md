# Context: fix-274-spracheingabe-latenz

## Request Summary
#274, zweiter Schnitt. Die Diagnosezeile aus Build 21 (PR #290) zeigt auf Hennings iPhone 16 Pro (TestFlight,
Hauptkennung): „Noch kein Text – Modell: installed · Mikrofon: ja · Sprache: ja · Puffer: 71 · Ergebnisse: 0“. Text kommt
später doch, und „es dauert sehr lange, bis die Erfassung startet“. Ziel: Die Erfassung hört schnell zu und Text kommt
in seiner echten App so schnell wie im Prüfbau, belegt mit gemessenen Zeiten. Gehört zu #279 Teil A (Verzögerung,
stoßweise Ergebnisse).

## Hat es bisher funktioniert?
Ja, laut Ticket vor Build 19 (alte `SFSpeechRecognizer`-Fassung; Build 19 ist die erste mit #64, `a87ca81`). Wichtiger:
**Derselbe Code ist im Prüfbau schnell.** Erster Schnitt (`docs/context/fix-274-spracheingabe-kein-text.md`): Prüfbau,
Release, iPhone, Läufe 2–5: erstes Wort 0,6 s nach dem Sprechen. Spike #22 (`docs/artifacts/spike-22-kaltstart/reihe1-launch-timings.json`):
Prozessstart bis Zuhören 713 ms, Analyzer-Start 6,7 ms. Langsam ist es nur in Hennings TestFlight-App.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Speech/SpeechCapture.swift` | Kette Modell → Rechte → Analyzer → Tap → `collect(from:)`; `@MainActor`, Ergebnis-Schleife läuft als `Task` auf dem Hauptstrang; Transcriber mit `reportingOptions: [.volatileResults]`, `SpeechAnalyzer(modules:)` ohne `Options` |
| `LooseEnds/Speech/SpeechDiagnosis.swift` | Diagnosezeile (Schwelle 6 s), Zähler Puffer/Ergebnisse — bestehender Messkanal in der echten App |
| `LooseEnds/Views/CaptureView.swift` | einziger Nutzer; `speech.start()` beim Erscheinen |
| `LooseEnds/App/ContentView.swift:63,70,112–122` | `startUp()`: `mergeDuplicateContexts`, `mergeEnglishDefaults`, Speichern, `enrichment.processPending()`; dazu `onChange(of: tasks.count)` → `processPending()` (jeder CloudKit-Import) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | `@MainActor`, ruft das On-Device-Modell (Apple Intelligence) je unbearbeiteter Aufgabe |
| `LooseEnds/App/LaunchTimings.swift` | Messpunkte bis `firstBuffer` (#22), **kein** Punkt „erstes Ergebnis“; Datei nur im Prüfbau |

## Existing Patterns
- Messpunkte über `LaunchTimings.mark(...)` (Signposts immer, JSON nur im Prüfbau).
- Diagnose in der echten App als graue Zeile statt Datei (TestFlight gibt keinen Dateizugriff, Entscheidung erster Schnitt).
- Reine Regeln in eigenen Typen (`SpeechDiagnosis`, `SpeechReadiness`), unit-getestet; `SpeechCapture` nur Verdrahtung.

## Dependencies
- Upstream: `Speech` (iOS 27: `SpeechAnalyzer`, `SpeechTranscriber`, `AssetInventory`, `AnalyzerInputConverter`),
  `AVAudioEngine`. Konkurrenz um denselben Hauptstrang und dieselbe Neural Engine: `EnrichmentCoordinator`
  (Foundation Models), SwiftData-Hauptkontext, CloudKit-Import.
- Downstream: `CaptureView` liest `transcript`, `state`, `waveform`, Diagnose.

## Recherche (2026-10-09, Quellen)
- SDK iOS 27 (`Speech.swiftinterface`): `SpeechAnalyzer.Options(priority:modelRetention:ignoresResourceLimits:)` —
  `ignoresResourceLimits` ist **neu in iOS 27**; `modelRetention` `.whileInUse | .lingering | .processLifetime`;
  `prepareToAnalyze(in:)`; `ReportingOption.fastResults`; `SpeechTranscriber.Preset.progressiveTranscription`.
- Apple-Forum, 14 s bis zum ersten Ergebnis: Apple nennt als mögliche Ursache, dass Ergebnis-Verarbeitung und Anzeige
  beide auf dem Main Actor laufen und sich gegenseitig blockieren; Abhilfe `@concurrent` bzw. Arbeit vom Main Actor
  nehmen. https://developer.apple.com/forums/thread/795924
- Apple-Forum, Latenz: `prepareToAnalyze` und `[.volatileResults, .fastResults]` als dokumentierte Hebel.
  https://developer.apple.com/forums/thread/794720
- Apple-Forum, schnellere Ergebnisse: Preset `.progressiveTranscription` für Echtzeit.
  https://developer.apple.com/forums/thread/829790
- Praxisbericht: 0,3–0,5 s bis zum ersten Teilergebnis bei warmem Start (iOS 26.5).
  https://dev.to/simple_memo/ios-26s-speechanalyzer-on-a-live-mic-the-5-things-the-docs-dont-tell-you-2ng5

## Existing Specs
- `docs/specs/*/fix-274-sichtbare-spracheingabe-diagnose.md` (erster Schnitt, Diagnosezeile)
- `docs/specs/*/spike-22-kaltstart.md` (Messpunkte bis Zuhören)

## Spuren für die Analyse (keine Ursache, nicht reproduziert)
1. **Prüfbau ≠ echte App: Daten und Arbeit beim Start.** Der Prüfbau ist leer. Hennings App führt beim Start
   Kontext-Dubletten zusammen, speichert, reichert unbearbeitete Aufgaben mit Apple Intelligence an (`@MainActor`), und
   jeder CloudKit-Import (`tasks.count` ändert sich) stößt das erneut an. Die Ergebnis-Schleife `collect` läuft ebenfalls
   auf dem Hauptstrang. Passt zu „Start dauert lange“ und „Ergebnisse 0 nach 6 s, später doch“.
2. **Neural Engine teilen:** Sprachmodell und Apple-Intelligence-Modell gleichzeitig; `ignoresResourceLimits` (neu in
   iOS 27) deutet auf Drosselung unter Last. Unbelegt.
3. **Optionen:** `.fastResults`, Preset `.progressiveTranscription`, `modelRetention`, `priority`. Im ersten Schnitt
   zeigte `prepareToAnalyze` im leeren Prüfbau keinen Unterschied; unter Last ungeprüft.

## Reproduktion ohne Hennings Gerät (Plan für /20-analyse)
- Simulator mit **großem Datenbestand und unbearbeiteten Aufgaben** (wie Hennings App), dann Erfassung öffnen; messen:
  Öffnen → Zuhören, Zuhören → erstes Ergebnis, Hauptstrang-Blockaden. Klären, ob der iOS-27-Simulator Sprachmodelle hat
  (erster Schnitt: nein; Memory: der Simulator hat ein Apple-Intelligence-Modell) — sonst Mac-Host-Test mit Audiodatei
  über `analyzeSequence`, einmal mit, einmal ohne Last auf dem Main Actor.
- Fehlender Messpunkt „erstes Ergebnis“ in `LaunchTimings` → für vorher/nachher nötig.

## Risks & Considerations
- Keine Ursache vor der Reproduktion. Spur 1 ist plausibel, aber nur gelesen.
- Gerätestufe 3 Pflicht (`LooseEnds/Speech/`); Gerät nur auf Hennings „jetzt ist ein Test möglich“. Erst Recherche und
  Simulator ausschöpfen (Memory `feedback-erst-recherche-und-simulator-dann-geraet`).
- Hennings Alltags-App ist TestFlight; Beleg in seiner echten Umgebung nur über eine neue TestFlight-Fassung.
- Alternativen: (a) Arbeit beim Start verschieben, solange die Erfassung offen ist; (b) Ergebnis-Schleife vom Main Actor
  nehmen; (c) Transcriber-Optionen; (d) Rückbau auf `SFSpeechRecognizer` (kippt „nur auf dem Gerät“ aus #64).
- #279 B/C (Pegel, Mikrofon-Symbol) bleiben draußen: brauchen einen Entwurf.

## Analysis

### Type
Bug (Verschlechterung seit Build 19, #64 `a87ca81`; die alte `SFSpeechRecognizer`-Fassung lieferte Teilergebnisse sofort).

### Reproduktion (2026-10-09, Mac M4, macOS 27.0.1, deutsches Sprachmodell `installed` wie auf Hennings iPhone)
Wegwerf-Versuch `docs/artifacts/fix-274-spracheingabe-latenz/probe.swift` (+ `run.sh`, `install.swift`): `SpeechAnalyzer`
mit **derselben Transcriber-Einstellung wie die App** (`reportingOptions: [.volatileResults]`), Ton aus `say -v Anna`
in Echtzeit-Paketen zu 100 ms wie vom Mikrofon. Zeiten ab Fütterungsbeginn:

| Aufnahme | App heute `[.volatileResults]` | `+ .fastResults` | Preset `.progressiveTranscription` |
|---|---|---|---|
| 22 s, Sprache ab 4 s | erstes Wort **12,2 s**, dann nichts bis 23,4 s (Schübe) | **5,0 s**, danach jede Sekunde | **5,0 s**, danach jede Sekunde |
| Sprache ab 0 s | **12,2 s**, nächster Schub 19,3 s | – | – |
| Sprache ab 8 s | **13,2 s** | – | – |
| 7 s kurz | erst am Ende (7,7 s) | 1,08 s | 1,09 s |
| 22 s unter Apple-Intelligence-Dauerlast | 12,3 s | 5,0 s | – |

- Ohne `.fastResults` sammelt der Analyzer rund **12 s Ton**, bevor er das erste Ergebnis meldet, egal wann gesprochen wird,
  und meldet danach in Schüben. Genau Hennings Zeile (Puffer 71 = 7 s, Ergebnisse 0, Text kommt später) und #279 A (stoßweise).
- Endtext bei allen drei Einstellungen Wort für Wort gleich (nur Großschreibung des ersten Worts).
- `prepareToAnalyze`, Zeitstempel an `AnalyzerInput`, Foundation-Models-Last: **kein** Einfluss.
- Erst mit nicht installiertem Modell (`supported`) wirkte es anders (Schub erst bei Satzende) — irrelevant, Henning hat `installed`.

### Neubewertung der Spuren aus dem Kontext
- **Spur 1 (Hauptstrang belegt): widerlegt als Ursache des späten Texts.** Die Diagnosezeile wird jede Sekunde vom selben
  Hauptakteur gesetzt, der auch `collect` ausführt; dass sie mit „Ergebnisse: 0“ erschien, heißt, der Hauptstrang lief und
  es gab nichts abzuholen. Am Mac zudem ohne jede App-Last reproduziert.
- **Spur 2 (Neural Engine geteilt):** am Mac kein Effekt. Auf dem iPhone nicht gemessen, für die Erklärung nicht nötig.
- **Spur 3 (Optionen): Ursache.** `.fastResults` fehlt.
- **Erster Schnitt neu gelesen:** Die Prüfbau-Läufe 2–5 lieferten den ersten Text **immer** nach 13,4–14,2 s. Das ist das
  12–13-s-Fenster, nicht „Sprache begann bei 13,08 s, Text 0,6 s später“. Prüfbau und TestFlight verhalten sich also
  vermutlich gleich; der Unterschied „Prüfbau schnell“ war eine Fehldeutung.
- **„Start dauert lange“:** nicht getrennt gemessen. Mit 12 s ohne jedes Wort ist die Erfassung für den Nutzer „nicht
  gestartet“; die Startstrecke im Prüfbau (713 ms, #22) ist klein. Ob danach ein Rest bleibt, zeigt der Gerätelauf.

### Recherche (Quellen)
- Apple-Forum 794720: `[.volatileResults, .fastResults]` als dokumentierter Latenzhebel. https://developer.apple.com/forums/thread/794720
- Apple-Forum 829790: Preset `.progressiveTranscription` für Echtzeit. https://developer.apple.com/forums/thread/829790
- SDK iOS/macOS 27 `Speech.swiftinterface`: `ReportingOption.fastResults`, `Preset.progressiveTranscription`; zu
  `ignoresResourceLimits` keine Doku auffindbar (Suche 2026-10-09 ohne Treffer), nicht nötig.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | `transcriber()`: `reportingOptions: [.volatileResults, .fastResults]`; Erzeugung des Transcribers als testbare statische Fabrik (ohne Locale-Suche) |
| `LooseEndsTests/SpeechLatencyTests.swift` | CREATE | Mac-Host-Test: Ton aus Datei in Echtzeit durch den Transcriber der App; erstes Ergebnis < 3 s nach Sprechbeginn, Endtext enthält die Kernwörter. Überspringt sichtbar, wenn das Modell nicht `installed` ist (CI, Simulator) |
| `LooseEndsTests/Fixtures/speech-de.m4a` (o. ä.) | CREATE | ~10 s deutscher Testsatz (aus `say`, AAC, klein) |
| `project.yml` | evtl. MODIFY | nur falls die Testressource nicht automatisch im Test-Bundle landet (dann Geräteliste-Treffer, ohnehin Stufe 3) |

### Scope Assessment
- Files: 2–4
- Estimated LoC: +80 / −3 (Produkt 3–5, Test ~70)
- Risk Level: LOW — eine Option an einer Stelle; Text, Ablauf, UI, Daten unverändert. Restrisiko: `.fastResults` heißt laut
  Apple „schneller, evtl. etwas weniger genau“ in Zwischenständen; der Endtext war im Versuch identisch.

### Technical Approach (Empfehlung)
`.fastResults` zu den bestehenden `reportingOptions` hinzufügen (kleinster Eingriff, alle übrigen Optionen bleiben). Belegt
wird es mit einem automatischen Mac-Host-Test, der genau die Zeit misst, über die Henning klagt (erstes Wort), und vorher rot
ist (12 s), nachher grün (~1 s). Danach Stufe 3 auf dem Gerät nur nach Hennings Wort, dann TestFlight.

**Alternativen:**
- Preset `.progressiveTranscription` (gleiche Zeiten im Versuch; Apples Voreinstellung für Live-Diktat, setzt aber eigene
  Transkriptions-/Attribut-Optionen fest, also mehr Änderung als nötig).
- Erst messen, dann ändern (Spec `fix-274-sprache-latenz-messung.md` der parallelen Sitzung): durch die Reproduktion
  überholt — Ursache steht fest, der Messschnitt würde nur eine TestFlight-Runde und Hennings Zeit kosten. Die Diagnosezeile
  aus Schnitt 1 bleibt als Rückmeldekanal bestehen; zeigt das Gerät danach noch eine lange Startstrecke, ist die
  Zeitmessung der nächste Schritt.
- Rückbau auf `SFSpeechRecognizer`: unnötig, kippt #64.
- Keine ADR betroffen.

### Dependencies
`Speech` (`SpeechTranscriber`, `SpeechAnalyzer`, `AssetInventory`), keine neue Abhängigkeit. Downstream `CaptureView`
unverändert. Diagnosezeile (Schwelle 6 s) bleibt; mit ~1 s bis zum ersten Wort erscheint sie im gesunden Fall nicht mehr.

### Open Questions
- [ ] Parallele Sitzung `fix-274-sprache-latenz` (Worktree `linear-yawning-wigderson`, Mess-Spec wartet auf Freigabe):
      verwerfen, damit nicht beides gebaut wird. Henning sollte die dortige Spec nicht freigeben.
- [ ] Gerätestufe: `LooseEnds/Speech/` liegt auf der Geräteliste — Lauf nur nach Hennings „jetzt ist ein Test möglich“.
