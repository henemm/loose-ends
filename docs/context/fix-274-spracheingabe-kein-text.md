# Context: fix-274-spracheingabe-kein-text

## Request Summary
Die eingebaute Spracheingabe zeigt die Wellenform, liefert aber keinen Text. Betroffen: iPhone 16 Pro und iPad,
TestFlight Build 19. Die System-Diktierfunktion geht. Ziel: Text auf iPhone und iPad wieder, auf dem Gerät belegt (#274).

## Hat es bisher funktioniert?
Ja, laut Ticket in Hennings Xcode-Fassung auf dem iPhone. Build 19 (`35b2863`, 2026-10-08) ist die erste
ausgelieferte Fassung mit #64 (`a87ca81`, 2026-10-07, SpeechAnalyzer statt `SFSpeechRecognizer`). Build 18
(`723f3cd`, 2026-10-04) hatte #64 nicht. Offen: Ob Hennings funktionierende Xcode-Fassung #64 schon enthielt.
Das klärt die Reproduktion, nicht der Verlauf.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Speech/SpeechCapture.swift` (323 Z.) | Gesamte Kette: Modellstatus, Rechte, Analyzer, Tap, Ergebnisschleife `collect(from:)` |
| `LooseEnds/Speech/SpeechReadiness.swift` | Abbildung `AssetInventory.Status` auf Bereitschaft |
| `LooseEnds/Views/CaptureView.swift` | einziger Nutzer von `SpeechCapture` |
| `LooseEnds/Info.plist`, `project.yml` | Mikrofon- und Spracherkennungs-Texte (Geräteliste Stufe 3) |
| `docs/context/spracherfassung-teststufen.md` | Stufen 0–7, Simulator hat keine Modelle (Stufen 0–4 nur Gerät) |
| `scripts/sim.sh` (`device-build`, `device-console`, `device-status`) | Prüfbau „LE Prüfbau" und Live-Protokoll |

## Existing Patterns
- Die Kette protokolliert Stufe 0 (Modellstatus), Rechte, „Audio-Eingang", „Ton kommt an: N Puffer", „Erkannt: …"
  (Logger `com.henning.looseends`, Kategorie `Speech`). Wo die Kette abreißt, steht damit im Protokoll.
- Der Transcriber wird mit `reportingOptions: [.volatileResults]`, ohne `audioTimeRange`, ohne Attribute erzeugt.
- `collect` unterscheidet `isFinal` und Zwischenergebnis; kein Ergebnis führt nicht zu einer Meldung (stilles Nichts).
- Stufe 3 der Geräteliste ist Pflicht, weil `LooseEnds/Speech/` darauf steht. Prüfbau läuft unter eigener Kennung.

## Dependencies
- Upstream: `Speech` (SpeechAnalyzer, SpeechTranscriber, AssetInventory, AnalyzerInputConverter, iOS 27),
  `AVFoundation` (AVAudioEngine, `installAudioTap`), `AVAudioApplication`, `SFSpeechRecognizer.requestAuthorization`.
- Downstream: `CaptureView` liest `transcript`, `state`, `waveform`.

## Research (2026-10-08, Quellen)
- WWDC25 Session 277 (SpeechAnalyzer): https://developer.apple.com/videos/play/wwdc2025/277/
- Apple Doku SpeechAnalyzer: https://developer.apple.com/documentation/speech/speechanalyzer
- Live-Audio-Beispiel: https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio
- Praxisbericht „5 things the docs don't tell you": https://dev.to/simple_memo/ios-26s-speechanalyzer-on-a-live-mic-the-5-things-the-docs-dont-tell-you-2ng5

Die Suchen nannten nur Muster (Modell installiert, Format zu `bestAvailableAudioFormat`, `volatileResults`). Eine
konkrete Fehlerzeile für unseren Fall gibt es nicht; sie kommt erst aus dem Protokoll vom Gerät. Der Praxisbericht
ist in der Analyse wörtlich zu lesen, bevor eine Ursache benannt wird.

## Existing Specs
- Spec zu #64 (Spracherfassung auf SpeechAnalyzer) im Verlauf von `a87ca81`.

## Risks & Considerations
- Keine Ursache vor der Reproduktion (Henning-Regel). Verdacht auf #64 ist Eingrenzung, kein Befund.
- Reproduktion auf dem Gerät: iPhone ist per Kabel verbunden und entsperrt (`device-status`: connected, iOS 27.0).
  Das iPad ist von hier aus nicht erreichbar; Nachweis dort nur über TestFlight und Hennings Bestätigung.
- Alternative zur Reparatur: Rückbau auf `SFSpeechRecognizer` (kippt die Entscheidung „nur auf dem Gerät“ aus #64).
  Nur sinnvoll, wenn das Protokoll ein Systemproblem von `SpeechAnalyzer` belegt.
- Prüfbau darf Hennings Alltags-App (TestFlight) nicht überschreiben; er läuft unter `com.henning.looseends.probe`.
- Simulator hat keine Sprachmodelle: dort kein Nachweis für Text, nur für Ton und Absturzfreiheit.

## Analysis (Stand 2026-10-08, Phase 2, Ursache NICHT gefunden)

### Type
Bug. Nicht reproduziert.

### Recherche (Quellen)
- Praxisbericht (Format, Modell, volatile Ergebnisse): https://dev.to/simple_memo/ios-26s-speechanalyzer-on-a-live-mic-the-5-things-the-docs-dont-tell-you-2ng5
  Alle drei Fallen sind im Code behandelt (`AnalyzerInputConverter`, `AssetInventory`, `.volatileResults`).
- Forum: erstes Ergebnis bei warmem Start in 0,3–0,5 s; `prepareToAnalyze(in:)` und `.fastResults` sind die dokumentierten Hebel
  (https://developer.apple.com/forums/thread/794720).

### Messkanal (neu, für `/30-write-spec` wichtig)
- `./scripts/sim.sh device-console` zeigt **keine** `Logger`-Zeilen (liest nur stdout); `log collect` braucht root. Das ist #160.
- Funktioniert: `xcrun xctrace record --device <udid> --template Logging --launch -- <bundle-id> [Argumente]`, danach
  `xctrace export --xpath '/trace-toc/run[@number="1"]/data/table[@schema="os-log"]'`. Nur mit `--launch` kommen die
  Zeilen der App an; `--all-processes` lieferte 160 000 Systemzeilen und **null** von Speech (nichts davon aus der App).
- Der Start der Erfassung ohne Antippen braucht eine Änderung am Code (Startargument). Die Edit-Sperre erlaubt das in
  Phase 2 nicht; die Messungen liefen aus einer Wegwerf-Kopie unter dem Scratchpad (`diagcopy/`), das Repo ist unverändert.

### Messungen auf Hennings iPhone 16 Pro (iOS 27.0), Prüfbau `com.henning.looseends.probe`, Ton: laufende Konferenz im Raum
| Lauf | Konfiguration | Stufe 0 | Rechte | Text kommt? | Erster Text |
|---|---|---|---|---|---|
| 2 | Debug, Code von `main` | installed (de_DE) | Mikrofon 1, Sprache 1 | **ja** (>100 Zeilen) | 14,2 s nach Start |
| 3 | **Release** (wie Archiv), Code von `main` | installed | 1 / 1 | **ja** (97 Zeilen) | 13,6 s |
| 4 | Release + Pegelmarke | installed | 1 / 1 | **ja** (66 Zeilen) | 13,4 s |
| 5 | Release + `prepareToAnalyze` | installed | 1 / 1 | **ja** (103 Zeilen) | 13,7 s |
Lauf 5: erste Sprache am Mikrofon bei 13,08 s, erster Text 0,6 s später. Die „11,5 s von erstem Tonpaket bis erstem
Teilergebnis“ (Apple-Metrik) ist damit nur die Zeit bis zum ersten Wort im Raum, **keine** Verzögerung des Analyzers.
Eine frühere Deutung in dieser Sitzung („11 s Latenz“) war falsch und ist zurückgenommen.

### Befund
Der Code von Build 19 liefert auf dem iPhone Text, auch als Release-Bau, mit Prüfkennung. Die ganze Kette (Modell,
Rechte, Audio-Eingang, Ton, Analyzer, Ergebnisse) schließt. „Kein Text“ ist so **nicht** nachgestellt.

### Was nur Hennings TestFlight-App hat und der Prüfbau nicht (offen, keine Ursache)
1. Kennung `com.henning.looseends` statt `.probe`; Distributions-Signierung und Profil statt Entwicklungsprofil.
2. Hennings eigener Zustand (Rechte-Historie der alten `SFSpeechRecognizer`-Fassung, Sprache/Region, installierte Sprachen).
3. Der Weg ins Erfassungsfenster (Plus, Aktionstaste) statt Start mit offener Erfassung.
4. Auf dem iPad nicht messbar (nicht erreichbar).
Eine Fassung mit Hennings Kennung darf nicht über seine TestFlight-App gelegt werden (Memory „Alltags-App = TestFlight“).

### Alternativen (nicht gewählt, aber offen)
- **Sichtbar machen statt raten:** Kette in eine kleine Datei im App-Container schreiben und in der Erfassung eine Zeile
  zeigen, wenn nach N Sekunden Ton kein Text kommt. Löst auch #160 für die Spracherfassung. Gilt für jede Ursache.
- **Rückbau auf `SFSpeechRecognizer`:** kippt „nur auf dem Gerät“ aus #64; nur sinnvoll, wenn ein Systemproblem von
  `SpeechAnalyzer` in der Produktionskennung belegt wäre.
- **`prepareToAnalyze` + `.fastResults`:** in Lauf 5 ohne messbaren Unterschied; kein Fix, nur Latenzhebel.

### Offene Fragen
- [ ] Was zeigt Hennings TestFlight-App genau (Textfeld leer? Meldung? Wellenform wie lange)? Und: ob er nach Build 19 überhaupt
      einmal Text gesehen hat.
- [ ] Gleicher Fehler mit Hennings Hauptkennung aus Xcode (Entwicklungsprofil)? Würde Signierung/Profil von Zustand trennen.

### Entscheidung (Henning, 2026-10-08)
- „Fehler sichtbar machen“ statt Rückbau oder Hauptkennung. Entwurf A freigegeben (graue Zeile unter der Wellenform nach 6 s Ton ohne Text, keine Farbe, keine Schaltfläche).
- Vorschau: https://claude.ai/artifact/PvnUFZMnEuJUDwtznRDzQm, Datei `docs/artifacts/fix-274-spracheingabe-kein-text/entwurf.html` (+ `heute-simulator.png`).
- Korrektur zur Vorschau: Eine Datei im App-Ordner ist in TestFlight nicht lesbar (kein Zugriff ohne Entwicklungssignatur). Die Zeile selbst trägt deshalb die
  Befunde in Kurzform (Modellstatus, Rechte, Anzahl Puffer, Anzahl Ergebnisse), damit Henning sie abfotografieren oder vorlesen kann. Die Datei entfällt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | zählt Puffer und Ergebnisse, merkt sich Modellstatus/Rechte, meldet „Ton ohne Text seit 6 s“ als Zustand `silentRecognition(diagnosis)` oder getrenntes Feld |
| `LooseEnds/Speech/SpeechDiagnosis.swift` | CREATE | reine Regel: aus Zählern + Zeit wird Hinweis ja/nein und Kurztext (unit-testbar, kein Framework) |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | graue Zeile unter `listeningRow`, verschwindet bei Text |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | DE/EN-Text der Zeile |
| `LooseEndsTests/SpeechDiagnosisTests.swift` | CREATE | Regel: kein Hinweis vor 6 s, Hinweis bei Ton ohne Ergebnis, weg bei Text, Kurztext enthält Zähler |
| `LooseEndsUITests/…` | CREATE | Smoke: Zeile ist im Simulator unter `--ui-testing` zeigbar (Startargument für festen Zustand) |

### Scope Assessment
- Files: 6 (Grenze 4–5: Test-Datei oder Strings-Datei in der Spec zusammenlegen oder UI-Test weglassen und Regel nur per Unit-Test belegen — in `/30-write-spec` entscheiden)
- Estimated LoC: +140 / −5
- Risk Level: MEDIUM — berührt `LooseEnds/Speech/` (Gerätestufe 3 ist Pflicht), ändert aber nur Anzeige und Zähler, nicht die Erkennung.

### Technical Approach (Regelweg zuerst)
Ohne Modell, ohne neue Abhängigkeit: Zähler und Uhr. „Ohne das Modell geht es nicht“ gilt hier nicht, das Modell kommt nicht vor.
Die Regel `SpeechDiagnosis.hint(buffers:results:secondsListening:status:permissions:)` liefert nil, solange Ergebnisse > 0 oder Zeit < 6 s.
Danach erscheint die Zeile mit der Kurzdiagnose. Ablauf zum Beleg: Prüfbau auf dem iPhone (wie in den Messungen), danach neue TestFlight-Fassung; Henning spricht in die echte App und sendet, was die Zeile zeigt.

### Dependencies
`CaptureView` ist der einzige Nutzer von `SpeechCapture`; keine Änderung an Persistenz, Modell oder Intents.

### Open Questions
- [ ] Muss die Zeile auch bei `unavailable`/`needsModel` etwas Neues zeigen? Nein: dort steht heute schon ein Grund.
- [ ] Wartezeit 6 s: in der Spec festschreiben (Konferenzmessung: erstes Wort kam nach 0,6 s, also genügt 6 s mit Reserve).

## Nachtrag 2026-10-09 (Phase 1, Schnitt 2: Verzögerung, zusammen mit #279 Teil A)

### Neue Lage
Die Diagnosezeile (PR #290, TestFlight Build 21) hat geliefert. Henning, iPhone, wörtlich: „es dauert sehr lange bis die
Erfassung startet und dann kommt sie sehr verzögert. Vorher steht da ein grauer Text: ‚Noch kein Text – Modell: installed ·
Mikrofon: ja · Sprache: ja · Puffer: 71 · Ergebnisse: 0‘“. Damit gilt: Modell da, Rechte da, Ton kommt an (71 Puffer ≈ 7 s),
Ergebnisse kommen später doch. „Kein Text“ ist also **Verzögerung**, kein Ausfall. #274 und #279 Teil A sind ein Symptom.

### Hat es bisher funktioniert?
Ja, in Xcode-Fassung auf dem iPhone (Ticket). Die Verzögerung wurde im Prüfbau bisher nicht als solche gemessen:
Läufe 2–5 oben meldeten 13–14 s „bis zum ersten Text“, der Erklärversuch (erstes Wort im Raum bei 13,08 s) hing an einer
Konferenz als Tonquelle und ist **kein Beleg** gegen eine Verzögerung auf Hennings Weg.

### Zwei getrennte Zeiten (so gemessen werden sie nie vermischt)
1. **Tippen/Öffnen → `state == .listening`** („Erfassung startet lange“). Messpunkte existieren: `LaunchTimings`
   (`captureAppeared`, `speechStartCalled`, `modelReady`, `analyzerStarted`, `engineStarted`, `listening`, `firstBuffer`),
   Abschnitte `modelCheck`, `analyzer`, `engine`. Kaltstart-Messung #22: 558 ms per `devicectl` im Prüfbau, also **nicht**
   das, was Henning in TestFlight erlebt. Unterschiede: Distributionsbau, Hennings Datenbestand (`startUp` auf dem MainActor),
   Weg über Plus/Aktionstaste, Rechte-Abfragen (`requestRecordPermission`, `requestAuthorization`) vor jedem Start.
2. **`.listening` → erstes Ergebnis** („Text kommt verzögert, stoßweise“). Kein Messpunkt im Code: `collect(from:)` zählt nur
   `resultCount`, loggt aber keinen Zeitpunkt des ersten Ergebnisses; `LaunchTimings` endet bei `firstBuffer`.

### Code-Befund (SpeechCapture.swift, gelesen, keine Ursache)
- `transcriber()` (Z. 182–188): nur `.volatileResults`, kein `.fastResults`.
- Kein `prepareToAnalyze`; `AnalyzerInputConverter.converter(...)` und `analyzer.start` laufen erst nach den Rechte-Abfragen
  (Z. 81–96, 194–199) und damit auf dem Weg zwischen Tippen und Zuhören.
- Ergebnisse werden erst nach `engine.start()` gelesen (Z. 240), der Eingabestrom puffert bis dahin.
- `AVAudioSession` `.record`/`.measurement` (Z. 211): Modus `.measurement` schaltet Eingangsverarbeitung ab; ob das die
  Erkennung beeinflusst, ist nicht belegt.
- Bereits widerlegt als Hebel (Lauf 5): `prepareToAnalyze` allein ohne messbaren Unterschied — im Prüfbau mit Konferenzton.

### Alternativen zum bisherigen Weg
- `.fastResults` + `prepareToAnalyze` beim Öffnen der Erfassung (Analyzer vorwärmen, Rechte vorher abfragen).
- Rückbau auf `SFSpeechRecognizer` mit On-Device-Erkennung (kippt ADR zu #64); nur, wenn die Messung zeigt, dass
  SpeechAnalyzer selbst zu langsam ist.
- Anzeige statt Beschleunigung: „Zuhören beginnt …“-Zustand mit Fortschritt, bis `.listening` wirklich steht.

### Risiken
- Reproduktion der Verzögerung braucht das Gerät (Simulator hat keine Sprachmodelle). Gerätezugriff **nur** nach Hennings
  wörtlichem „jetzt ist ein Test möglich“; bis dahin nur Simulator und Code.
- Der Messkanal `xctrace --launch` erreichte das iPhone zuletzt nicht (#279, #160). Eine Zeitzeile in der Diagnose selbst
  (sichtbar in TestFlight) umgeht das.
- Scoping: Messpunkte + Diagnoseerweiterung + Fix müssen in 4–5 Dateien / ±250 LoC passen, sonst Schnitt teilen.

## Analysis (Stand 2026-10-09, Phase 2, Schnitt 2: Verzögerung; Ursache NICHT bewiesen)

### Type
Bug (Verschlechterung/Verzögerung, nicht reproduziert). Gilt zusammen für #274 und #279 Teil A.

### Recherche (zuerst, Quellen)
- Apple-Forum, „SpeechTranscriber extremely slow (14+ seconds)“ (iOS 26 Beta, iPhone 16 Pro): Apple nennt als Ursache „approachable
  concurrency“, bei der Verarbeitung und Anzeige auf dem Hauptstrang laufen; Abhilfe: abschalten oder Methoden `@concurrent`.
  https://developer.apple.com/forums/thread/795924
  Prüfung gegen unser Projekt: `project.yml` setzt nur `SWIFT_VERSION 6.0` und `SWIFT_STRICT_CONCURRENCY complete`, keine Standard-Hauptstrang-
  Isolation. Der Fall passt **nicht ohne Weiteres**; die effektiven Build-Einstellungen unter Xcode 27 sind aber nicht geprüft (offen).
- Apple-Forum, „SpeechAnalyzer latency“: `prepareToAnalyze()` ca. 0,75 s gewonnen, `.fastResults`, 16-kHz-Format am Tap vermeidet ca. 200 ms
  Umwandlung; warm 0,3–0,5 s bis zum ersten Teilergebnis. https://developer.apple.com/forums/thread/794720
- `AVAudioSession`-Modus `.measurement` „minimiert Signalverarbeitung, schaltet Dynamikverarbeitung ab“ (Apple-Doku, über Suche). Unser Code
  setzt `.record/.measurement` (SpeechCapture.swift:211). **Hypothese, nicht belegt:** passt zu Hennings zweiter Beobachtung (Pegel sehr gering,
  #279 B) und könnte die Erkennung bremsen. Eine Quelle, die das für SpeechAnalyzer belegt, wurde nicht gefunden.

### Was feststeht
- Henning (Build 21, iPhone): Modell installed, beide Rechte ja, 71 Puffer, 0 Ergebnisse nach 6 s; Text kommt später. Also Verzögerung, kein Ausfall.
- Zwei getrennte Zeiten, bisher beide ohne Messwert aus der Produktionsfassung: (1) Öffnen → `.listening` („Start dauert lange“),
  (2) `.listening` → erstes Ergebnis und Abstand der Ergebnisse („stoßweise“). Für (2) fehlt jeder Messpunkt im Code.
- Prüfbau-Läufe 2–5 (Konferenzton) zeigen die Verzögerung nicht eindeutig; Kaltstart-Messung #22: 558 ms bis Zuhören im Prüfbau.
  Damit unterscheidet sich Hennings Erlebnis vom Prüfbau (Distributionsbau, Datenbestand, Weg über Plus/Aktionstaste).

### Mögliche Ursachen (alle ungeprüft, nach Aufwand zum Prüfen)
1. `.measurement`-Modus (leises Signal → Erkennung wartet) — ein Schalter, im Prüfbau mit festem Satz vergleichbar.
2. Kein `prepareToAnalyze`/`.fastResults` (Lauf 5: ohne Wirkung im Prüfbau).
3. Hauptstrang-Belastung in Hennings Fassung (`startUp`, Datenbestand) verzögert Start und Ergebnisverarbeitung; `collect` läuft auf dem MainActor.
4. Format-Umwandlung 48 kHz → Modellformat.
5. Distributionssignierung/Profil (nur über TestFlight prüfbar).

### Ohne-Modell-Hinweis
Die Spracherkennung selbst braucht das System-Framework; alle Hebel hier sind Regeln/Konfiguration/Messung. Kein Sprachmodell-Weg im Spiel.

### Alternativen zum bisherigen Weg
- **Messen statt ändern (empfohlen, Schnitt 1):** Zeiten Öffnen→Zuhören und Zuhören→erstes Ergebnis sowie größter Abstand zwischen
  Ergebnissen in die Diagnosezeile aufnehmen (sichtbar in TestFlight, umgeht #160). Kein Verhalten ändert sich.
- **Gleich Hebel ziehen:** `.fastResults` + `prepareToAnalyze` + Modus `.default` auf Verdacht. Verstößt gegen Analysis-First.
- **Anzeige statt Beschleunigung:** „Zuhören beginnt …“ bis `.listening` steht. Kippt nichts, behebt nichts; nur falls Messung zeigt, dass die Zeit nicht zu senken ist.
- **Rückbau auf `SFSpeechRecognizer`:** kippt ADR aus #64; nur bei Beleg, dass SpeechAnalyzer selbst zu langsam ist.

### Technical Approach
Schnitt 1 (Messung, Spec in `/30-write-spec`): reine Regel/Zählung, keine neue Abhängigkeit.
- `SpeechCapture`: Zeitpunkte `listening`, erstes Ergebnis, größter Ergebnisabstand; Start-Dauer Öffnen→Zuhören.
- `SpeechDiagnosis`: Kurztext um diese Zeiten erweitern (rein, unit-testbar).
- Tests: Unit für die Regel (RED zuerst). UI-Smoke vorhanden (#274), Text prüfen.
Schnitt 2 (Fix) erst nach Messwerten von Hennings Gerät; Hebel 1–4 einzeln im Prüfbau mit festem Satz, dann Beleg in TestFlight.

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | Zeitmarken erstes Ergebnis/Abstand, Startdauer |
| `LooseEnds/Speech/SpeechDiagnosis.swift` | MODIFY | Zeiten im Kurztext |
| `LooseEndsTests/SpeechDiagnosisTests.swift` | MODIFY | Regel mit Zeiten |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | ggf. Textbausteine |

### Scope Assessment
- Files: 4, ca. +80/−10 LoC, Risiko NIEDRIG–MITTEL (berührt `LooseEnds/Speech/` → Gerätestufe 3 Pflicht, aber nur Zählung/Anzeige).

### Gerät
Reproduktion/Messung der Verzögerung braucht das iPhone (Simulator hat keine Sprachmodelle). Nichts darauf, auch nichts Lesendes,
bevor Henning wörtlich „jetzt ist ein Test möglich“ schreibt. Zuerst vorgesehen: TestFlight-Build mit Schnitt 1, den Henning ohnehin nutzt.

### Open Questions
- [ ] Effektive Build-Einstellungen (approachable concurrency / Standard-Isolation) unter Xcode 27 ablesen: reine Dateilesung, ohne Gerät.
- [ ] Beobachtet Henning die Verzögerung auch auf dem iPad? (Nachweis nur über seine Rückmeldung.)
