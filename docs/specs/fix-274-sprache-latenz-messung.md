---
entity_id: fix-274-sprache-latenz-messung
type: bugfix
created: 2026-10-09
updated: 2026-10-09
status: draft
workflow: fix-274-sprache-latenz
---

# Spec: #274 / #279 Teil A — Spracheingabe verzögert: Zeiten sichtbar messen (Schnitt 1)

## Approval

- [ ] Approved (Henning)

## Purpose

Hennings TestFlight-Build 21 (iPhone) zeigt die Diagnosezeile aus dem ersten Schnitt: „Noch kein Text – Modell: installed ·
Mikrofon: ja · Sprache: ja · Puffer: 71 · Ergebnisse: 0“. Dazu seine Worte: „es dauert sehr lange bis die Erfassung startet und
dann kommt sie sehr verzögert“. Damit ist „kein Text“ eine **Verzögerung**, kein Ausfall (Modell da, Rechte da, Ton kommt an,
Text später doch). Beschwerde und #279 Teil A (stoßweise, späte Ergebnisse) sind ein Symptom.

**Die Ursache der Verzögerung ist nicht bewiesen und nicht reproduziert.** Es gibt zwei getrennte Zeiten, und für keine liegt
ein Messwert aus Hennings Fassung vor:

1. **Start:** Öffnen der Erfassung (`CaptureView.begin()`) bis `state == .listening` („Erfassung startet lange“). Im Prüfbau
   558 ms (#22), in Hennings TestFlight-Fassung unbekannt.
2. **Erstes Ergebnis:** Zuhören beginnt bis das erste Ergebnis eintrifft („Text kommt verzögert“). Dafür gibt es im Code
   keinen Messpunkt; `collect(from:)` zählt nur.

Dieser Schnitt **ändert kein Verhalten der Erkennung**. Er macht beide Zeiten in der vorhandenen grauen Zeile sichtbar, die
Henning in TestFlight ohnehin sieht (umgeht #160: `Logger`-Zeilen sind von dort nicht lesbar). Aus den Zahlen folgt, welcher
Hebel (Schnitt 2) überhaupt in Frage kommt. Ein Fix auf Verdacht (`.fastResults`, `prepareToAnalyze`, Modus `.default`) ist
ausdrücklich nicht Teil dieses Schnitts: Lauf 5 zeigte für `prepareToAnalyze` im Prüfbau keinen Unterschied, und alle
anderen Hebel sind ungeprüft.

Regelweg: Uhr und Zähler, kein Modell, keine neue Abhängigkeit. „Ohne das Modell geht es nicht“ gilt nicht, weil das
Sprachmodell des Geräts (Apple Intelligence) nicht vorkommt.

## Source

- **Geändert:** `LooseEnds/Speech/SpeechDiagnosis.swift` (Zeiten, Berichtsfall, Text)
- **Geändert:** `LooseEnds/Speech/SpeechCapture.swift` (Zeitmarken im Start, Zeit des ersten Ergebnisses)
- **Geändert:** `LooseEnds/Views/CaptureView.swift` (eine Zeile: Öffnen melden)
- **Geändert:** `LooseEnds/Resources/Localizable.xcstrings` (DE/EN-Texte)
- **Geändert:** `LooseEndsTests/SpeechDiagnosisTests.swift` (Tests der Regel)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Speech/SpeechDiagnosis.swift` | MODIFY | Neu `struct SpeechTimings: Equatable` (`open`, `modelCheck`, `rights`, `analyzer`, `microphone`: `TimeInterval`; `var start: TimeInterval` = Summe der fünf; `firstResult: TimeInterval?`). Neu `static let slowStart: TimeInterval = 3`. `SpeechDiagnosis` bekommt `timings: SpeechTimings?`; `hint(...)` bekommt denselben Parameter mit Vorgabe `nil`. Regel und Text siehe unten. |
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | Neu `func noteOpened()` (merkt den Zeitpunkt). Misst mit `ContinuousClock` fünf zusammenhängende Strecken in `start()`/`begin()` und die Zeit bis zum ersten Ergebnis in `collect`. Reicht sie an `updateDiagnosis()` weiter. `stop()` und jeder Start setzen sie zurück. |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | Eine Zeile in `begin()`: `speech.noteOpened()` direkt neben `LaunchTimings.mark(.captureAppeared)`. Keine Änderung an Aussehen oder Ablauf. |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Drei Texte (siehe Texte), Deutsch und Englisch. Reine Textdatei. |
| `LooseEndsTests/SpeechDiagnosisTests.swift` | MODIFY | Tests für Berichtsfall, Schwellen, Text (siehe Test Plan). Bestehende Tests bleiben unverändert und grün. |

Geschätzt **+100 / −10 LoC** (Produktcode rund 60, Tests rund 50). **5 Dateien**, innerhalb der Grenzen.

Der UI-Test bleibt **unverändert**: Die Oberfläche zeigt schon `speech.diagnosis.text` als graue
Zeile, sobald `diagnosis != nil`; `CaptureView` ändert nur den einen Meldeaufruf. Der feste UI-Zustand (`--ui-testing-speech-diagnosis`) trägt `timings: nil` und zeigt den
Text von heute; der bestehende UI-Smoke bleibt gültig.

**Geräteliste berührt:** `LooseEnds/Speech/`. Stufe 3 (Hennings Geräte) ist Pflicht und läuft nur nach Hennings wörtlichem
„jetzt ist ein Test möglich“. `project.yml`, `Info.plist`, Entitlements bleiben unverändert. Keine neuen Berechtigungen, keine
AppStorage-Schlüssel, keine Audio-Dateien, keine Änderung an Persistenz oder Modell.

### Nicht in diesem Ticket

- Ein Fix der Verzögerung (Schnitt 2, erst nach Hennings Zahlen).
- Größter Abstand zwischen Ergebnissen („stoßweise“): Pausen des Sprechenden sind Abstände ohne Fehler, die Zahl wäre nicht
  zu deuten. Falls nach den Zahlen nötig, mit besserem Maß in Schnitt 2 (z. B. `audioTimeRange`).
- Pegel/Mikrofon-Zustand (#279 B/C), `.measurement`-Modus, `prepareToAnalyze`, `.fastResults`, `AVAudioSession`-Umbau.
- UI-Test für den Berichtsfall (siehe Risiken).

## Implementation Details

### Messstrecken in `SpeechCapture` (fünf, zusammenhängend)

Eine Uhr `ContinuousClock`. `CaptureView.begin()` ruft `noteOpened()` auf; das ist `tOpen`. `t0` ist der Eintritt in
`start()` hinter dem `isListening`-Guard. Die Strecken schließen aneinander an, damit ihre Summe die Startdauer ist:

| Strecke | von | bis |
|---|---|---|
| `open` | `tOpen` | `t0` (der zusätzliche Arbeitsschritt in `begin()` und alles, was den Hauptstrang davor belegt). Ohne `noteOpened()` (Start nach Modellladen) 0. |
| `modelCheck` | `t0` | nach `AssetInventory.status(forModules:)` (enthält die Sprachsuche in `transcriber()`) |
| `rights` | Ende `modelCheck` | nach `requestRecordPermission` und `requestSpeechAuthorization` |
| `analyzer` | Ende `rights` | nach `analyzer.start(inputSequence:)` in `begin` (enthält `AnalyzerInputConverter.converter`) |
| `microphone` | Ende `analyzer` | nach `engine.start()` (Audio-Session, Tap, Engine) |

`firstResult`: Sekunden von `listeningSince` bis zum ersten Element aus `transcriber.results` (flüchtig oder fest, auch leer,
wie der Ergebniszähler), nur wenn `run == self.run`. Es wird einmal gesetzt und bleibt bis `stop()`.

Wird `start()` mehrfach durchlaufen (`needsModel` → Modell laden → `start()`), beginnen die Strecken bei jedem Durchlauf neu.
Die erste Rechteabfrage nach Installation enthält die Zeit, die der Nutzer für die Systemfrage braucht; das steht in den
Risiken. `stop()` setzt Strecken und `firstResult` zurück.

### Regel `SpeechDiagnosis.hint`

Liefert genau dann einen Wert, wenn eine der beiden Bedingungen gilt (Fall W oder Fall B); sonst `nil`.

- **Fall W (Warten, unverändert):** `buffers > 0`, `results == 0`, `secondsListening >= threshold` (6 s, inklusive).
- **Fall B (Bericht, neu):** `results > 0` und (`timings.start >= slowStart` (3 s, inklusive) **oder**
  `timings.firstResult >= threshold` (6 s, inklusive)). Ohne `timings` (`nil`) gibt es keinen Fall B.

Die Schwellen stehen genau einmal als Konstanten (`threshold`, `slowStart`); Regel, Prüfschleife und Tests benutzen diese.
Begründung `slowStart = 3`: Im Prüfbau dauert der Start 0,6 s (#22), Apple nennt warm 0,3–0,5 s bis zum ersten Teilergebnis;
3 s liegen weit über allem Gesunden und weit unter Hennings „sehr lange“. Der Bericht bleibt stehen, bis die Erfassung endet,
damit Henning ihn in Ruhe ablesen kann; im gesunden Fall (Start < 3 s und erstes Ergebnis < 6 s) erscheint nie eine Zeile.

### Text

Fall W (wie heute, bei `timings != nil` um den Startteil ergänzt):
`Noch kein Text — Modell: installed · Mikrofon: ja · Sprache: ja · Puffer: 71 · Ergebnisse: 0 · Start: 12,4 s (Öffnen 0,1 · Modell 0,2 · Rechte 9,8 · Analyzer 1,5 · Mikrofon 0,8)`.
Ohne `timings` exakt der Text von heute.

Fall B: `Erster Text nach 11,4 s · Start: 12,4 s (Öffnen 0,1 · Modell 0,2 · Rechte 9,8 · Analyzer 1,5 · Mikrofon 0,8)`.

Alle Sekundenwerte mit einer Nachkommastelle in der Gerätesprache (Komma auf Deutsch, Punkt auf Englisch).

| Schlüssel (Englisch, Quelle) | Deutsch |
|---|---|
| `Speech diagnosis start: %@ s (opening %@ · model %@ · rights %@ · analyzer %@ · microphone %@)` | `Start: %@ s (Öffnen %@ · Modell %@ · Rechte %@ · Analyzer %@ · Mikrofon %@)` |
| `Speech diagnosis first text after %@ s` | `Erster Text nach %@ s` |
| `Speech diagnosis join` (Trenner ` · `) | ` · ` |

Der Katalogeintrag des Fall-W-Satzes aus Schnitt 1 bleibt unverändert; der Startteil wird mit dem Trenner angehängt. Die neuen
Schlüssel tragen das Präfix „Speech diagnosis“, damit sie keinen bestehenden Eintrag überschreiben.

### Prüfschleife und Oberfläche

Die Schleife (jede Sekunde, `updateDiagnosis()`) reicht `timings` an `hint` und setzt `diagnosis` oder `nil`. Im Fall B ist die
Bedingung nach dem ersten Ergebnis dauerhaft wahr; die Zeile wechselt von W nach B und bleibt, bis `stop()` sie
zurücknimmt. `CaptureView` rendert unverändert (`.footnote`, `.secondary`, keine Farbe, keine Schaltfläche, darf umbrechen).

## Test Plan

### Automated Tests (TDD RED zuerst)

Neue Fälle in `SpeechDiagnosisTests` (Unit, kein Framework):

- `testReportWhenStartIsSlow`: Ergebnisse 1, `timings.start == 3.0` (genau, Summe der fünf), `firstResult == 1.0` → Hinweis (Fall B).
- `testNoReportJustBelowSlowStart`: Ergebnisse 1, `start == 2.9`, `firstResult == 5.9` → `nil`.
- `testReportWhenFirstResultIsLate`: Ergebnisse 1, `start == 0.6`, `firstResult == 6.0` → Hinweis.
- `testNoReportWithoutTimings`: Ergebnisse 1, `timings == nil` → `nil` (altes Verhalten).
- `testReportWithoutFirstResultTime`: Ergebnisse 1, `start == 3.0`, `firstResult == nil` → Hinweis (kein Absturz, kein „nil s“ im Text).
- `testWaitingTextCarriesStartParts`: Fall W mit `timings` → Text enthält die Fall-W-Angaben und alle fünf Strecken sowie die Summe, in der Reihenfolge Öffnen, Modell, Rechte, Analyzer, Mikrofon.
- `testReportTextCarriesFirstResultAndParts`: Fall B → Text enthält „11,4“-Entsprechung (Wert des Testfalls), die Summe und die fünf Strecken.
- `testWaitingTextWithoutTimingsIsUnchanged`: Fall W ohne `timings` → Text gleich dem von heute.
- `testStartIsSumOfParts`: `SpeechTimings(open 0.1, 0.2, 9.8, 1.5, 0.8).start == 12.4` (mit Toleranz).
- `testSlowStartThresholdIsThreeSeconds`: `SpeechDiagnosis.slowStart == 3`.

Alle bestehenden Tests (`testNoHintBeforeThreshold` bis `testRestartStartsFresh`, UI-Smoke `SpeechDiagnosisLineTests`)
laufen unverändert grün; das belegt AC-8. Die Tests setzen die Texte in Englisch (wie Schnitt 1), die Zahlen werden mit
demselben Formatierer erzeugt, den die Regel benutzt, damit der Test nicht von der Gerätesprache abhängt.

### Simulator (Stufe 2)

Build und `./scripts/sim.sh unit`; UI-Smoke `SpeechDiagnosisLineTests` mit Screenshot (die Zeile von Schnitt 1 steht
unverändert da). Der Simulator hat keine Sprachmodelle: die Messstrecken laufen dort nicht durch. Das wird im Abschlussbericht
so gesagt, nicht als Beleg ausgegeben.

### Gerät (Stufe 3, Pflicht, nur nach Hennings „jetzt ist ein Test möglich“)

1. Neue TestFlight-Fassung (der Kanal, über den Henning die Zeile ohnehin sieht). Henning öffnet die Erfassung auf iPhone
   und iPad wie im Alltag (Plus und Aktionstaste), spricht, und sendet, was die graue Zeile zeigt.
2. Ein Prüfbau auf seinem iPhone ist nur nötig, wenn die TestFlight-Zahlen nicht deutbar sind; er läuft ebenfalls erst nach
   seinem Wort und gesondert angefragt.

## Acceptance Criteria

- **AC-1 Startdauer sichtbar:** Given Start ≥ 3,0 s (Summe der fünf Strecken) / When das erste Ergebnis eintrifft / Then steht
  eine graue Zeile mit Startdauer und den fünf Strecken bis zum Ende der Erfassung. Bei 2,9 s und erstem Ergebnis < 6 s steht
  keine Zeile.
- **AC-2 Zeit bis zum ersten Text sichtbar:** Given das erste Ergebnis kommt ≥ 6,0 s nach Zuhörbeginn / When es eintrifft /
  Then wechselt die Wartezeile in den Bericht „Erster Text nach X s · Start: …“ und bleibt bis zum Ende der Erfassung.
- **AC-3 Wartezeile trägt den Start:** Given Fall W (6 s Ton ohne Ergebnis) / Then enthält die Zeile zusätzlich Startdauer und
  fünf Strecken. Ohne `timings` ist der Text identisch mit dem von heute.
- **AC-4 Gesunder Fall unverändert:** Start < 3 s und erstes Ergebnis < 6 s → nie eine Zeile.
- **AC-5 Schwellen:** `threshold` (6 s) und `slowStart` (3 s) stehen je genau einmal als Konstante; Regel, Prüfschleife
  und Tests benutzen sie.
- **AC-6 Strecken zusammenhängend:** Die fünf Strecken schließen aneinander an; `start` ist ihre Summe; die Messpunkte liegen
  wie in der Tabelle beschrieben (Code-Lesen im Review).
- **AC-7 Neustart:** Nach `stop()` und neuem Start beginnen Strecken und `firstResult` neu; ein früherer Bericht bleibt nie
  stehen (Beleg: Code-Lesen wie AC-5 in Schnitt 1, nicht am Gerät beobachtet).
- **AC-8 Erkennung unverändert:** Keine Änderung an Transcriber, Optionen, Analyzer, Tap, Wandler, Audio-Session, Rechteabfrage;
  die bestehenden Tests und der UI-Smoke bleiben unverändert grün.
- **AC-9 Aussehen:** Grau (`.secondary`), `.footnote`, keine Farbe, keine Schaltfläche; `CaptureView` unverändert.
- **AC-10 Gerät:** Henning sendet aus der neuen TestFlight-Fassung (iPhone, wenn möglich auch iPad) die Zeile mit den Zahlen.
  Daraus wird im Ticket festgehalten, **welche** Strecke (Start: welche der fünf; oder erstes Ergebnis) die Zeit trägt. Das
  Ticket bleibt offen; der Fix ist Schnitt 2.
- **AC-11 Regression:** Unit, Build, UI-Smoke grün; Speech Stress (10×, weil `LooseEnds/Speech/**` berührt) grün.

## Dependencies

| Komponente | Version | Beschreibung |
|---|---|---|
| keine neue | – | Nur `ContinuousClock` und bestehende `Speech`-/`AVFoundation`-Aufrufe |

## Risiken

- **Rechteabfrage enthält Nutzerzeit:** Beim allerersten Start nach Installation wartet `rights` auf die Antwort des Nutzers
  auf die Systemfrage. Bei Henning, der alle Fragen beantwortet hat, bleibt der Wert klein; ist `rights` groß, ist das ein
  Befund (die Abfrage läuft bei jedem Start durch dasselbe Nadelöhr), kein Messfehler.
- **Zeit vor `begin()` fehlt weiterhin:** Alles vor dem Erscheinen der Erfassung (Tippen auf Plus/Aktionstaste, Szene aufbauen) misst `open` nicht. Zeigen die fünf Strecken deutlich weniger, als Henning erlebt, ist der nächste Messpunkt dort (Schnitt 2).
- **Hauptstrang:** `collect` und die Prüfschleife laufen auf dem Hauptakteur. Ist er belegt, verzögert sich auch die Messung
  des ersten Ergebnisses (`firstResult` misst dann „bis der Hauptstrang es verarbeitet“). Das ist kein Fehler der Messung,
  denn genau das sieht der Nutzer; der Hauptstrang als Ursache bleibt Hypothese (Apple-Forum 795924) und ist aus den Zahlen
  allein nicht vom Analyzer zu trennen. `project.yml` und die erzeugte Projektdatei setzen keine
  Standard-Isolation/Approachable-Concurrency-Schlüssel; was Xcode 27 ohne diese Schlüssel vorgibt, ist nicht belegt.
- **Kein UI-Test für Fall B:** Der feste UI-Zustand zeigt weiter nur Fall W ohne `timings`. Fall B und der Startteil sind
  durch Unit-Tests der Regel und des Textes sowie am Gerät belegt, nicht per Smoke im Simulator (dort fehlen die Modelle).
  Eine eigene Variante des Startarguments würde `CaptureView` und eine fünfte/sechste Datei berühren; bewusst nicht gewählt.
- **Die Zeile kann bei gesundem Gerät kurz erscheinen**, wenn der erste Satz nach über 6 s fällt (langes Schweigen am Anfang):
  Fall W wird zu Fall B und bleibt stehen. Ein Fehlalarm kostet nichts, ist aber an „Erster Text nach X s“ erkennbar.

## Alternativen (verworfen)

- **Gleich Hebel ziehen** (`.fastResults` + `prepareToAnalyze` + Modus `.default`): Verstößt gegen Analysis-First; `prepareToAnalyze`
  brachte im Prüfbau nichts, die übrigen Hebel sind unbelegt. Würde ein Ergebnis liefern, ohne zu sagen, welcher Hebel half.
- **Anzeige statt Beschleunigung** („Zuhören beginnt …“): Behebt nichts. Nur sinnvoll, falls die Zahlen zeigen, dass die
  Zeit nicht zu senken ist.
- **Rückbau auf `SFSpeechRecognizer`:** kippt die Entscheidung „nur auf dem Gerät“ aus #64; nur bei Beleg, dass
  `SpeechAnalyzer` selbst zu langsam ist. Die Zahlen aus diesem Schnitt sind der Beleg, ob dieser Weg überhaupt offen ist.
- **Prüfbau und `xctrace --launch` statt Zeile:** erreichte das Gerät zuletzt nicht (#160, #279), zeigt zudem nie Hennings
  Fassung und Datenbestand, und braucht sein Gerät; die Zeile kommt über den Weg, den er ohnehin nutzt.
- **Messdatei im App-Ordner:** in TestFlight nicht lesbar (Schnitt 1).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — kein neues Konzept: Es kommen nur Uhr, fünf Messstrecken und ein Berichtsfall in eine vorhandene reine Regel
  und eine vorhandene Zeile. Rohtext, Anreicherung, Revisions und Persistenz bleiben unberührt; „Regeln vor Modell“ wird
  eingehalten, es kommt kein Modell vor. Kippt keine bestehende ADR.

## Definition of Done

- AC-1 bis AC-11 erfüllt; die neuen Fälle in `SpeechDiagnosisTests` grün (zuerst rot), alle bestehenden Tests grün.
- Build und UI-Smoke mit Screenshot (angesehen); im Abschlussbericht steht, dass der Simulator die Messstrecken nicht belegt.
- Neue TestFlight-Fassung ausgeliefert; Henning hat (nach seinem Wort) die Zeile von iPhone, wenn möglich iPad gesendet.
- #274 und #279: Kommentar mit den Zahlen und der Strecke, die die Zeit trägt; Schnitt 2 als eigenes Ticket mit dem Hebel,
  den die Zahlen nahelegen (Alternativen oben). #274 bleibt bis dahin offen.
- `docs/project/04-stand.md` nennt Schnitt 1 und dass der Fix aussteht.
- Abschlussbericht ohne Git-Vokabular: was sich im Produkt ändert (die graue Zeile zeigt künftig Zeiten) und was Henning tun
  soll (Erfassung öffnen, sprechen, Zeile senden).

## Changelog

- 2026-10-09: Initiale Spec für den Verzögerungs-Schnitt 1 von #274/#279 A (Messen vor Ändern).
