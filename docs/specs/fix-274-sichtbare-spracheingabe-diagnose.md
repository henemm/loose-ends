---
entity_id: fix-274-sichtbare-spracheingabe-diagnose
type: bugfix
created: 2026-10-08
updated: 2026-10-08
status: draft
workflow: fix-274-spracheingabe-kein-text
---

# Spec: #274 — Spracheingabe ohne Text: Fehler sichtbar machen

## Approval

- [ ] Approved (Henning)

## Purpose

In Hennings TestFlight-App (Build 19, iPhone und iPad) zeigt die Erfassung die Wellenform, liefert aber keinen Text. Die
Ursache ist **nicht reproduziert**: Der Code von Build 19 liefert auf dem iPhone 16 Pro Text, auch als Release-Bau unter der
Prüfkennung `com.henning.looseends.probe` (Läufe 2–5, `docs/context/fix-274-spracheingabe-kein-text.md`). Was nur
Hennings Installation hat (Produktionskennung, Distributions-Signierung, eigener Rechte- und Sprachzustand, iPad), lässt
sich von hier aus nicht messen.

Produktentscheidung (Henning, 2026-10-08): **Fehler sichtbar machen statt raten, kein Rückbau.** Entwurf A ist freigegeben
(`docs/artifacts/fix-274-spracheingabe-kein-text/entwurf.html`).

Kommt in der Erfassung 6 Sekunden lang Ton an (Puffer > 0), ohne dass ein Ergebnis eintrifft, erscheint unter der
Wellenform eine **graue Zeile** (Hierarchie-Grau, keine Farbe, keine Schaltfläche) mit einer Kurzdiagnose: Modellstatus,
Rechte (Mikrofon, Sprache), Anzahl Puffer, Anzahl Ergebnisse. Sie verschwindet, sobald ein Ergebnis kommt. Henning
fotografiert oder liest sie vor; daraus folgt die Ursache.

Korrektur zur Vorschau: Eine Protokolldatei im App-Ordner entfällt, weil sie in TestFlight nicht lesbar ist. Die Zeile
trägt die Befunde selbst.

Regelweg: Zähler und Uhr, kein Modell, keine neue Abhängigkeit. „Ohne das Modell geht es nicht“ gilt hier nicht, weil
das Sprachmodell des Geräts (Apple Intelligence) nicht vorkommt. **Die Erkennung selbst bleibt unverändert.**

## Source

- **Neu:** `LooseEnds/Speech/SpeechDiagnosis.swift` — reine Regel, kein Framework
- **Geändert:** `LooseEnds/Speech/SpeechCapture.swift` (Zähler, Merker für Modellstatus und Rechte, Prüfschleife)
- **Geändert:** `LooseEnds/Views/CaptureView.swift` (graue Zeile unter `listeningRow`, Startargument)
- **Geändert:** `LooseEnds/Resources/Localizable.xcstrings` (DE/EN-Texte)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Speech/SpeechDiagnosis.swift` | NEU | `struct SpeechDiagnosis: Equatable` mit `modelStatus: String`, `microphone: Bool`, `speech: Bool`, `buffers: Int`, `results: Int`. `static let threshold: TimeInterval = 6`. `static func hint(buffers:results:secondsListening:modelStatus:microphone:speech:) -> SpeechDiagnosis?` (nil, solange Bedingung nicht erfüllt) und `var text: String` (lokalisierte Kurzzeile). Rein, ohne Systemzugriff. |
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | Merkt Modellstatus und Rechte aus `start()` (stehen dort schon im Protokoll). Zählt Puffer (`ConverterBox` reicht den Zählerstand thread-sicher heraus) und Ergebnisse (`collect`). Eine Prüfschleife wertet jede Sekunde die Regel aus und setzt `private(set) var diagnosis: SpeechDiagnosis?`. `stop()` und jeder neue Start setzen Zähler, Zeit und `diagnosis` zurück. |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | Unter der Wellenform (Zustand `.listening`) `Text(diagnosis.text)`, `.font(.footnote)`, `.foregroundStyle(.secondary)`, Kennung `speechDiagnosisLabel`. Startargument `--ui-testing-speech-diagnosis` (siehe unten). |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Zwei Texte (Zeile, Ja/Nein), Deutsch und Englisch. Reine Textdatei. |
| `LooseEndsTests/SpeechDiagnosisTests.swift` | NEU | Unit-Tests der Regel (siehe Test Plan). |
| `LooseEndsUITests/SpeechDiagnosisLineTests.swift` | NEU | UI-Smoke: Zeile ist mit festem Zustand sichtbar und ohne Argument nicht da. |

Geschätzt **+140 / −5 LoC** (Produktcode rund 80, Tests rund 60).

**Ausnahme von der Dateigrenze (4–5 Dateien): 6 Dateien, ausdrücklich.** Begründung: `Localizable.xcstrings` ist eine reine
Textdatei ohne Logik (zwei Einträge). Der UI-Test ist nach der globalen Regel Pflicht für jede sichtbare Änderung. Die
Änderung ist ein einziges Stück (Regel, Zähler, Anzeige); sie zu teilen ergäbe einen Zwischenstand, der Zähler ohne Anzeige
oder Anzeige ohne Regel enthielte. LoC-Grenze (±250) wird eingehalten. Kein Drive-by-Refactoring.

**Geräteliste berührt:** `LooseEnds/Speech/`. Stufe 3 (Hennings iPhone) ist Pflicht. `project.yml`, `Info.plist` und
Entitlements bleiben unverändert. Keine neuen Berechtigungen, keine neuen AppStorage-Schlüssel, keine Audio-Dateien, keine
Änderung an Persistenz oder Modell.

### Nicht in diesem Ticket

- Eine Ursache oder ein Fix für „kein Text“. Das Ticket #274 bleibt offen, bis Henning die Zeile gesendet und die Ursache
  behoben ist (eigener Schnitt).
- Eine Zeile bei `unavailable` und `needsModel`: Dort steht schon ein Grund.
- Eine Protokolldatei im App-Ordner und #160 (Geräteprotokoll). Die Zeile ersetzt sie nur für diesen Fall.
- iPad-Messung von hier aus; sie läuft über Hennings TestFlight-Fassung.

## Implementation Details

### Regel `SpeechDiagnosis.hint`

Liefert genau dann einen Wert, wenn **alle** gelten:

1. `buffers > 0` (es kommt Ton an)
2. `results == 0` (weder Teil- noch Endergebnis)
3. `secondsListening >= SpeechDiagnosis.threshold` (6 s, **inklusive**)

Sonst `nil`. Die Schwelle steht an genau einer Stelle als Konstante `threshold`; Tests und Prüfschleife benutzen sie, keine
zweite Zahl. Begründung für 6 s: Konferenzmessung (Lauf 5) lieferte das erste Wort 0,6 s nach dem Sprechen; 6 s lassen
reichlich Reserve, auch bei langsamem Sprechbeginn.

### Zähler und Prüfschleife in `SpeechCapture`

- Ergebniszähler: `collect(from:)` erhöht ihn bei **jedem** Element aus `transcriber.results` (flüchtig oder fest), vor der
  Textverarbeitung.
- Pufferzähler: `ConverterBox.feed` zählt schon (`buffers`); ein lesender Zugriff unter derselben Sperre gibt den Stand heraus.
- `secondsListening` läuft ab dem Moment, in dem `state = .listening` gesetzt wird (nach `engine.start()`).
- Die Prüfschleife ist eine `Task` auf dem Hauptakteur, die jede Sekunde `SpeechDiagnosis.hint(...)` auswertet und
  `diagnosis` setzt oder auf `nil` zurücknimmt. Sie endet in `stop()` (wie `results`).
- Kommt ein Ergebnis, ist `diagnosis` spätestens in der nächsten Sekunde `nil`.
- Neustart der Erfassung (`stop()`, dann `start()`): Pufferzähler, Ergebniszähler, Startzeit und `diagnosis` beginnen bei 0
  bzw. `nil`. Die Zeile eines früheren Laufs bleibt nie stehen.

### Oberfläche (CaptureView)

Im Zweig `.idle, .listening` bleibt die `HStack` aus Wellenform und Mikrofon-Knopf unverändert. Darunter, nur wenn
`speech.diagnosis != nil`, eine graue Zeile (`.footnote`, `.secondary`, keine Schaltfläche, keine Farbe). Sie ist reiner
Text, damit Henning sie abfotografieren oder vorlesen kann; sie darf umbrechen (mehrzeilig). Die Farbbudget-Regel bleibt:
Grau = Hierarchie.

### Texte

| Schlüssel (Englisch, Quelle) | Deutsch |
|---|---|
| `No text yet — model: %@ · microphone: %@ · speech: %@ · buffers: %lld · results: %lld` | `Noch kein Text — Modell: %@ · Mikrofon: %@ · Sprache: %@ · Puffer: %lld · Ergebnisse: %lld` |
| `Speech diagnosis yes` / `Speech diagnosis no` | `ja` / `nein` |

Der Modellstatus erscheint als Rohwert des Systems (`installed` usw.), weil er Diagnose ist und in beiden Sprachen
gleich vorgelesen werden soll. Die Ja/Nein-Schlüssel tragen das Präfix „Speech diagnosis“, damit sie keinen bestehenden
Eintrag des Katalogs überschreiben.

Beispiel Englisch: `No text yet — model: installed · microphone: yes · speech: yes · buffers: 62 · results: 0`.
Beispiel Deutsch: `Noch kein Text — Modell: installed · Mikrofon: ja · Sprache: ja · Puffer: 62 · Ergebnisse: 0`.

### Startargument für den UI-Test

`--ui-testing-speech-diagnosis` wirkt nur zusammen mit `--ui-testing`. Dann zeigt die Erfassung die Zeile `listeningRow`
trotz `--ui-testing` (heute abgeschaltet, `speechWanted == false`), startet **kein** Mikrofon und keine Erkennung und setzt
`diagnosis` fest auf `SpeechDiagnosis(modelStatus: "installed", microphone: true, speech: true, buffers: 62, results: 0)`.
Der Text läuft über denselben Formatierer `text` wie im Produktpfad. Das Argument wird von `CaptureView` (`ProcessInfo`
wie `--ui-testing-dark`) gelesen; ohne es ändert sich unter `--ui-testing` nichts. Es ändert den Produktpfad nicht.

## Test Plan

### Automated Tests (TDD RED zuerst)

`SpeechDiagnosisTests` (Unit, kein Framework nötig):

- `testNoHintBeforeThreshold`: 5,9 s, Puffer 50, Ergebnisse 0 → `nil`.
- `testHintAtExactlyThreshold`: genau `SpeechDiagnosis.threshold` (6,0 s), Puffer 60, Ergebnisse 0 → Hinweis.
- `testHintAfterThreshold`: 30 s, Puffer 300, Ergebnisse 0 → Hinweis.
- `testNoHintWithoutBuffers`: 10 s, Puffer 0, Ergebnisse 0 → `nil` (es kommt kein Ton an; das ist ein anderer Fehler).
- `testNoHintWhenResultsArrived`: 10 s, Puffer 100, Ergebnisse 1 → `nil`.
- `testHintDisappearsWhenResultComesLater`: erst 7 s/Puffer 70/Ergebnisse 0 → Hinweis, dann 8 s/Puffer 80/Ergebnisse 1 → `nil`.
- `testThresholdIsSixSeconds`: `SpeechDiagnosis.threshold == 6`.
- `testTextCarriesAllFacts`: Hinweis mit Status `installed`, Mikrofon ja, Sprache nein, Puffer 62, Ergebnisse 0 → Text
  enthält jede der fünf Angaben (Wert „62“, „0“, „installed“ und die beiden Ja/Nein-Wörter in der Reihenfolge Mikrofon, Sprache).
- `testRestartStartsFresh`: Der Aufrufer ruft die Regel mit zurückgesetzten Zählern (0 s, 0 Puffer, 0 Ergebnisse) → `nil`.
  (Das Zurücksetzen selbst in `SpeechCapture` belegt der Durchlauf auf dem Gerät, siehe unten.)

`SpeechDiagnosisLineTests` (UI-Smoke, Simulator, Englisch erzwungen):

- `testDiagnosisLineShowsFixedState`: Start mit `--ui-testing`, `--ui-testing-speech-diagnosis`, `-AppleLanguages (en)`,
  `-AppleLocale en_US`; (+) antippen; `speechDiagnosisLabel` erscheint innerhalb von 10 s, und sein `label` ist **gleich**
  (`XCTAssertEqual`, keine CONTAINS-Prüfung) `No text yet — model: installed · microphone: yes · speech: yes · buffers: 62 · results: 0`.
  Screenshot wird angehängt und geöffnet angesehen.
- `testNoDiagnosisLineWithoutArgument`: Start nur mit `--ui-testing`; Erfassung öffnen; `speechDiagnosisLabel` existiert
  nicht (die Erfassung bleibt wie heute ohne Spracherfassung).

Der Simulator hat keine Sprachmodelle: Die Erkennung selbst ist dort nicht prüfbar. Der UI-Test belegt Anzeige und Text,
nicht die Zähler.

### Gerät (Stufe 3, Pflicht)

1. **Prüfbau** (`./scripts/sim.sh device-build` auf dem Stand, vorher `generate`) auf Hennings iPhone: Erfassung öffnen,
   Sprache ins Mikrofon, Text erscheint, die Zeile erscheint **nicht** (gesunder Fall, wie Lauf 3–5).
2. Zeile hervorrufen: Mikrofon läuft, aber es wird nicht gesprochen und kein Ergebnis eintrifft → nach 6 s steht die Zeile
   mit Puffern > 0 und Ergebnissen 0 da; ein Ergebnis (Sprechen) lässt sie verschwinden; Abbrechen und erneutes Öffnen
   beginnt ohne Zeile. Ablauf mit dem Messkanal `xctrace --launch` im Protokoll gegengelesen (Zähler = „Ton kommt an“, „Erkannt“).
3. **Neue TestFlight-Fassung** mit der Änderung ausliefern. Henning öffnet die Erfassung in seiner Alltags-App auf iPhone
   und iPad, spricht, und **sendet, was die Zeile zeigt** (Foto oder vorgelesen). Erst daraus folgt die Ursache und der
   Fix in einem eigenen Schnitt. Eine Fassung mit Hennings Hauptkennung wird nicht über seine TestFlight-App gelegt.

## Acceptance Criteria

- **AC-1 Schwelle:** Given die Erfassung hört zu und Puffer > 0 / When 6 s ohne Ergebnis vergangen sind (genau 6,0 s
  eingeschlossen) / Then steht die graue Zeile unter der Wellenform. Bei 5,9 s steht sie nicht da.
- **AC-2 Konstante:** Die 6 Sekunden stehen genau einmal als `SpeechDiagnosis.threshold`; Regel, Prüfschleife und Tests
  benutzen diese Konstante.
- **AC-3 Kein Ton:** Given 0 Puffer / When beliebig lange / Then keine Zeile (anderer Fehler, nicht Gegenstand).
- **AC-4 Ergebnis löscht:** Given die Zeile steht / When ein Teil- oder Endergebnis eintrifft / Then verschwindet die Zeile
  spätestens eine Sekunde danach und kommt im selben Lauf nicht wieder.
- **AC-5 Neustart:** Given eine Zeile stand / When die Erfassung geschlossen und neu geöffnet wird / Then beginnen Puffer-
  und Ergebniszähler und Uhr bei 0, und die Zeile erscheint erst wieder nach AC-1.
- **AC-6 Inhalt:** Die Zeile nennt Modellstatus, Mikrofonrecht, Spracherkennungsrecht, Anzahl Puffer, Anzahl Ergebnisse, auf
  Deutsch und Englisch nach der Gerätesprache.
- **AC-7 Aussehen:** Grau (`.secondary`), `.footnote`, keine Farbe, keine Schaltfläche. Abbrechen, Tippen ins Feld und
  Mikrofon-Knopf gehen unverändert.
- **AC-8 Keine neue Zeile bei Grund:** Bei `unavailable`, `needsModel` und `loadingModel` erscheint die Zeile nie.
- **AC-9 Erkennung unverändert:** Keine Änderung an Transcriber, Analyzer, Tap, Wandler, Rechteabfrage; der gesunde Fall
  (Text kommt) sieht aus wie vorher, ohne zusätzliche Zeile.
- **AC-10 Festzustand:** Mit `--ui-testing` und `--ui-testing-speech-diagnosis` zeigt die Erfassung die Zeile mit dem festen
  Text aus „Testen“; ohne das zweite Argument bleibt `--ui-testing` unverändert.
- **AC-11 Gerät:** Prüfbau auf dem iPhone belegt AC-1, AC-4, AC-5 (Protokoll gegengelesen); in der neuen TestFlight-Fassung
  sendet Henning, was die Zeile zeigt.
- **AC-12 Regression:** Unit, Build, UI-Smoke und Speech Stress (10×, weil `LooseEnds/Speech/**` berührt) grün.

## Dependencies

| Komponente | Version | Beschreibung |
|---|---|---|
| keine neue | – | Nur Zähler und Uhr über bestehende `Speech`-/`AVFoundation`-Aufrufe; keine neue Abhängigkeit |

## Risiken

- **Zähler und Hauptakteur:** `ConverterBox` läuft auf dem Audio-Strang. Der Zählerstand wird nur unter der vorhandenen
  Sperre gelesen; kein neuer Abschluss mit Hauptstrang-Bindung auf dem Audio-Strang (Absturzklasse `dispatch_assert_queue`,
  siehe Kommentare in `SpeechCapture`).
- **„Ergebnis“ heißt jedes Element von `results`**, auch ein leeres. Liefert der Analyzer nur leere Ergebnisse, bleibt die
  Zeile weg, obwohl kein Text erscheint. Das wäre selbst ein Befund (Ergebniszähler > 0, Text leer) und in der Zeile als
  `results: n` nicht sichtbar. Nehmen wir hier bewusst in Kauf; wird Henning „kein Text, keine Zeile“ melden, ist das der
  nächste Schritt.
- **Die Zeile kann bei gesundem Start kurz auftauchen**, wenn das erste Wort erst nach 6 s fällt (langes Schweigen am
  Anfang). Sie verschwindet beim ersten Ergebnis wieder; ein Fehlalarm kostet nichts.
- **Simulator ohne Modelle:** Zähler und Prüfschleife sind dort nicht durchlaufbar; sie belegt nur das Gerät.

## Alternativen (verworfen)

- **Rückbau auf `SFSpeechRecognizer`:** kippt „nur auf dem Gerät“ (#64) und die Entscheidung gegen die Server-Frage, ohne
  dass ein Systemproblem von `SpeechAnalyzer` in Produktion belegt wäre. Nur sinnvoll, wenn Hennings Zeile genau das zeigt.
- **Immer eine Debug-Ansicht oder Protokolldatei:** Die Datei im App-Ordner ist in TestFlight nicht lesbar (kein Zugriff ohne
  Entwicklungssignatur); eine dauerhafte Debug-Ansicht wäre sichtbarer Lärm im gesunden Fall. Die Zeile erscheint nur im
  Fehlerfall und braucht keinen Zugriff auf Dateien.
- **Hauptkennung aus Xcode auf Hennings iPhone:** trennt Signierung von Zustand, würde aber seine Alltags-App
  überschreiben (Memory „Alltags-App = TestFlight“) und deckt das iPad nicht ab.
- **`prepareToAnalyze` / `.fastResults`:** in Lauf 5 ohne messbaren Unterschied; kein Fix, nur Latenzhebel.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — kein neues Konzept: Es kommen nur Zähler, eine reine Regel und eine Zeile Anzeige dazu.
  Rohtext, Anreicherung, Revisions und Persistenz bleiben unberührt; die Entscheidung „Regeln vor Modell“ (Henning,
  2026-09-20) wird eingehalten, es kommt kein Modell vor. Kippt keine bestehende ADR.

## Definition of Done

- AC-1 bis AC-12 erfüllt; `SpeechDiagnosisTests` und `SpeechDiagnosisLineTests` grün, alle bestehenden Tests grün.
- Der Durchlauf im Simulator mit `--ui-testing-speech-diagnosis` ist als Screenshot belegt und angesehen.
- Prüfbau-Durchlauf auf dem iPhone mit Protokoll belegt; neue TestFlight-Fassung ausgeliefert.
- `docs/project/04-stand.md` nennt die Zeile und dass #274 offen bleibt, bis Hennings Antwort vorliegt.
- Abschlussbericht ohne Git-Vokabular: was sich im Produkt ändert, und was Henning in der TestFlight-Fassung tun soll
  (Erfassung öffnen, sprechen, die graue Zeile senden).

## Changelog

- 2026-10-08: Initiale Spec für #274 (Entwurf A freigegeben): sichtbare Kurzdiagnose bei Ton ohne Text.
