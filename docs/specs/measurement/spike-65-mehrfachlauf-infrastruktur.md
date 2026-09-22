---
entity_id: spike-65-mehrfachlauf-infrastruktur
type: feature
created: 2026-09-22
updated: 2026-09-22
status: draft
workflow: spike-65-unsicherheitssignal
---

# Spec: Spike #65 Schritt 1 — Mess-Infrastruktur für Mehrfachläufe

**Status:** draft · **Workflow:** spike-65-unsicherheitssignal · **Erstellt:** 2026-09-22 · **Aktualisiert:** 2026-09-22

## Freigabe

- [ ] Freigegeben

## Problem

Die bestehende Mess-Infrastruktur aus #67 kennt nur genau einen Lauf pro Satz und genau ein fest
verdrahtetes Korpus. `MeasurementRun.doneIDs`/`remaining(from:)` (`Measurement/MeasurementRun.swift:93-102`)
arbeiten über Mengen-Mitgliedschaft: ein Satz gilt als erledigt, sobald irgendein Erfolgsergebnis mit
seiner `entryID` existiert — ein zweites Ergebnis zur selben `entryID` ist im heutigen Modell nicht
vorgesehen. `Corpus.load(calendar:)` (`Measurement/Corpus.swift:113-120`) lädt immer `Corpus.fileName =
"date-title-corpus"`; `MeasurementRunner.init` (`LooseEndsLab/MeasurementRunner.swift:52-59`) ruft es
ohne Parameter auf, `LabApp` (`LooseEndsLab/LabApp.swift`) kennt keine Korpuswahl.

Spike #65 Schritt 2 (eigene, spätere Spec) braucht beides anders: fünf Läufe je Satz für das
Selbstkonsistenz-Signal, gemessen gegen den FocusBlox-Korpus statt das Datums-/Titelkorpus. Ohne diese
Erweiterung entstünde für Schritt 2 nur ein neuer Parallel-Code-Pfad neben der bestehenden
Infrastruktur — genau das schließt die Analyse explizit aus
(`docs/context/spike-65-unsicherheitssignal.md`, Technical Approach Punkt 1–2: „keine neue
Architektur", „kein Parallel-Code-Pfad"). Die härteste Nebenbedingung dabei: die bestehende
Fortsetzbarkeit bei Unterbrechung (Speichern nach jedem Satz, Fortsetzen von dort) darf nicht brechen,
weil Messläufe mehrtägig auf Hennings Alltags-iPhone laufen
([[feedback-phone-is-not-a-test-bench]]).

## Zweck

Schritt 1 erweitert die vier bestehenden Bausteine der Mess-Infrastruktur minimalinvasiv, ohne neue
Konzepte einzuführen: `Corpus.load` bekommt einen parametrisierbaren Dateinamen mit unverändertem
Default, `MeasurementResult` bekommt einen `runIndex` (Default 0, alte Dateien bleiben lesbar),
`remaining(from:)` zählt ab jetzt Läufe je Satz statt reiner Satz-Mitgliedschaft, und
`MeasurementRunner`/`LabApp` reichen Korpusname und Laufzahl durch. Das ist reines Fundament: kein
neues Signal, kein Modellaufruf geändert, keine Produktwirkung. Schritt 2 (Selbstkonsistenz-Signal,
FocusBlox-Korpus, 5 Läufe je Satz) baut darauf auf und ist **nicht** Teil dieser Spec.

## Quelle

- **Datei:** `Measurement/Corpus.swift`
  **Bezeichner:** `static func load(fileName: String = Corpus.fileName, calendar: Calendar = .current) throws -> [Entry]`
- **Datei:** `Measurement/MeasurementRun.swift`
  **Bezeichner:** `struct MeasurementResult` (neues Feld `runIndex: Int`), `func remaining(from entries: [Corpus.Entry], runsPerEntry: Int = 1) -> [(entry: Corpus.Entry, runIndex: Int)]`
- **Datei:** `LooseEndsLab/MeasurementRunner.swift`
  **Bezeichner:** `final class MeasurementRunner` (neue Init-Parameter `corpusFileName`, `runsPerEntry`; `func measure(_ entry: Corpus.Entry, runIndex: Int) async -> MeasurementResult`)
- **Datei:** `LooseEndsLab/LabApp.swift`
  **Bezeichner:** `struct LabApp` (`init()` liest `--corpus <name>` aus `CommandLine.arguments`)
- **Datei:** `Measurement/MeasurementRun.swift`
  **Bezeichner:** `enum MeasurementProgress` (neu) — `static func total(entries: Int, runsPerEntry: Int) -> Int`,
  `static func done(in run: MeasurementRun) -> Int`, `static func progress(done: Int, total: Int) -> Double`
- **Datei:** `Measurement/Corpus.swift`
  **Bezeichner:** `static func corpusFileName(from arguments: [String], flag: String = "--corpus") -> String` (neu)

**Nachtrag aus der RED-Phase (2026-09-22):** `MeasurementRunner` (`LooseEndsLab/MeasurementRunner.swift`)
importiert `UIKit` unbedingt und `LabApp`/`LabView` `SwiftUI`; `LooseEndsLab` ist `platform: iOS`
und wird von `LooseEndsTests` (`supportedDestinations: [iOS, macOS]`) nicht kompiliert. AC-4, AC-5
und AC-6 lassen sich deshalb nicht durch Instanziieren von `MeasurementRunner`/`LabApp` selbst am Mac
testen — der Testplan unten prüft stattdessen die beiden oben genannten neuen, plattformunabhängigen
Bausteine (`MeasurementProgress`, `Corpus.corpusFileName(from:)`), auf die `MeasurementRunner`/`LabApp`
in der Implementierung dünn delegieren. Die Acceptance Criteria selbst (Verhalten) bleiben unverändert
erfüllt; nur der Ort der Prüfung verschiebt sich von der Klasse auf die extrahierte, reine Logik.

## Acceptance Criteria

- **AC-1 Korpus lädt per Namen, Default unverändert:** Given ein Dateiname wie `"date-title-corpus"`
  oder `"focusblox-corpus"` / When `Corpus.load(fileName:calendar:)` aufgerufen wird / Then lädt es
  genau diese Datei (Bundle-Ressource bevorzugt, sonst die Datei neben `Corpus.swift`, wie bisher) —
  und alle bestehenden Aufrufe `Corpus.load()` ohne Argument (`CorpusTests`, `DateParserCorpusTests`,
  `DateTitleReportTests`) laden weiterhin unverändert `date-title-corpus`, weil der Parameter den
  Default `Corpus.fileName` trägt.
- **AC-2 Mehrere Läufe je Satz werden zutreffend gezählt:** Given ein `MeasurementRun` mit zwei
  erfolgreichen Ergebnissen zur `entryID` „x" (`runIndex` 0 und 1) und `runsPerEntry = 3` / When
  `remaining(from:runsPerEntry:)` aufgerufen wird / Then enthält das Ergebnis für Satz „x" noch genau
  ein Paar `(entry, runIndex: 2)`; sobald ein drittes erfolgreiches Ergebnis vorliegt, taucht Satz „x"
  nicht mehr auf.
- **AC-3 Rückwärtskompatibilität mit `runsPerEntry = 1`:** Given der Default `runsPerEntry = 1` und
  eine vor diesem Schnitt geschriebene Ergebnisdatei ohne `runIndex`-Feld im JSON / When die Datei
  dekodiert und `remaining(from:)` ohne den neuen Parameter aufgerufen wird / Then dekodiert
  `runIndex` als 0, und ein Satz mit einem Erfolgsergebnis gilt wie bisher als vollständig erledigt
  (kein Verhaltensunterschied zum Stand vor diesem Schnitt für einlaufige Messungen).
- **AC-4 `MeasurementRunner` zählt Läufe statt Sätze:** Given ein Korpus mit N Sätzen und
  `runsPerEntry = R` (R > 1) / When `MeasurementRunner` initialisiert wird / Then ist `total == N * R`,
  `done` entspricht der Anzahl erfolgreicher Ergebnisse insgesamt (nicht der Anzahl unterschiedlicher
  Sätze), und `progress == Double(done) / Double(total)`.
- **AC-5 Runner reicht Korpusname und Laufzahl durch:** Given eine `MeasurementRunner`-Instanz mit
  einem vom Default abweichenden `corpusFileName` und `runsPerEntry > 1` / When `measureRemaining()`
  einen Satz mehrfach hintereinander misst / Then wird `Corpus.load(fileName:)` mit dem übergebenen
  Namen aufgerufen (nicht mit `Corpus.fileName`), und jedes gespeicherte `MeasurementResult` trägt den
  passenden, bei diesem Satz aufsteigenden `runIndex`.
- **AC-6 `LabApp` liest Korpuswahl aus dem Startargument:** Given Startargumente inklusive
  `--corpus focusblox-corpus` (analog zum bestehenden `--measure`-Flag) / When `LabApp` initialisiert
  wird / Then wird `MeasurementRunner` mit `corpusFileName: "focusblox-corpus"` erzeugt; ohne dieses
  Argument bleibt der bisherige Default (`Corpus.fileName`) unverändert.

## Nicht in diesem Schnitt

Schritt 1 liefert ausschließlich die vier oben genannten Bausteine. Alles, was Schritt 2
(Selbstkonsistenz-Signal, eigene Spec, erst nach Abschluss von Schritt 1) betrifft, bleibt hier außen
vor:

- FocusBlox-Export (`scripts/export-focusblox-corpus.swift`) auf `Corpus.Entry`-Schema angleichen.
- Die eigentliche Selbstkonsistenz-Auswertung (Einstimmigkeit über 5 Läufe, Trefferquote-über-
  Abdeckung-Kurve je Feld) als reine, testbare Funktionen.
- Das Report-Skript für `docs/reference/uncertainty-signal-selfconsistency-report.md`.
- Eine feste `runsPerEntry`-Konstante von 5 oder ein eigenes Kommandozeilen-Flag dafür in `LabApp` —
  Schritt 1 liefert nur den Mechanismus (Init-Parameter mit Default 1); wer den Wert auf 5 setzt und
  wie er ausgewählt wird, entscheidet Schritt 2.
- Der eigentliche mehrtägige Messlauf auf Hennings Gerät.
- Jede Design-Entscheidung zu `EnrichmentWriter.confidenceThreshold` (0,6) — abhängig vom
  Messergebnis aus Schritt 2, nicht Teil dieser Spec.

Jeder dieser Punkte gehört in eine eigene Spec nach Abschluss von Schritt 1, nicht in diese.

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `Corpus.fileName` | Konstante | Bleibt der Default-Wert für `load(fileName:)` — bestehende Aufrufe `Corpus.load()` bleiben unverändert. |
| `Corpus.Entry` | Typ | Unverändert in diesem Schnitt; das FocusBlox-Format daran anzugleichen ist Aufgabe von Schritt 2. |
| `MeasurementStore` | Typ | Liest/schreibt `MeasurementRun` unverändert; liest ab diesem Schnitt zusätzlich Dateien mit `runIndex`-Feld sowie ältere ohne, verlustfrei. |
| `MeasurementPacing` | Typ | Drosselungslogik unverändert — arbeitet weiter je einzelnem Messversuch, unabhängig davon, ob der Versuch der erste oder ein späterer Lauf desselben Satzes ist. |
| `FoundationModelsEnricher` | Typ | Modellaufruf in `measure(_:runIndex:)` inhaltlich unverändert; der Aufruf bekommt lediglich den zusätzlichen `runIndex`-Parameter zum Durchreichen ins Ergebnis. |
| `MeasurementResult.succeeded` | Berechnete Eigenschaft | Grundlage für die neue Zählung in `remaining(from:runsPerEntry:)` und `MeasurementRunner.done`. |
| `sim.sh` (Ziele `lab`, `lab-fetch`) | Skript | Startet/holt die Labor-App; unverändert in diesem Schnitt, da `--corpus` optional ist und ohne Argument das bisherige Verhalten bleibt. |

## Umfang

### Betroffene Dateien

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/Corpus.swift` | MODIFY | `load(fileName:calendar:)` mit Default `Corpus.fileName` statt der bisherigen festen Konstante im Funktionskörper. |
| `Measurement/MeasurementRun.swift` | MODIFY | `MeasurementResult` bekommt `runIndex: Int = 0` plus eigenen `init(from:)`/`CodingKeys` (analog zum bestehenden Muster bei `MeasurementRun.events`), damit alte Dateien ohne dieses Feld lesbar bleiben. `remaining(from:runsPerEntry:)` ersetzt die reine Mengen-Prüfung durch einen Lauf-Zähler je `entryID`; `doneIDs` entfällt, weil `MeasurementRunner` künftig direkt `run.succeeded.count` verwendet. |
| `LooseEndsLab/MeasurementRunner.swift` | MODIFY | Neue Init-Parameter `corpusFileName: String = Corpus.fileName`, `runsPerEntry: Int = 1`; `entries = Corpus.load(fileName: corpusFileName)`; `done`/`total`/`progress` auf Läufe statt Sätze umgestellt; die Schleife iteriert über `(entry, runIndex)`-Paare und ruft `measure(_:runIndex:)`, das den Wert ins gespeicherte `MeasurementResult` schreibt. |
| `LooseEndsLab/LabApp.swift` | MODIFY | `init()` liest ein optionales `--corpus <name>`-Argument aus `CommandLine.arguments` (analog zum bestehenden `--measure`-Flag in `LabView.task`) und reicht den Namen an `MeasurementRunner(corpusFileName:)` durch; ohne Argument bleibt der bisherige Default. |

### Geschätzter Umfang

- Dateien im Scope: 4
- LoC gesamt: geschätzt ca. +80/-25 (Parametrisierung bestehender Funktionen, eine neue
  Zählvariante über bereits vorhandene Typen, kein neues Konzept) — deutlich unter der
  250-LoC-Grenze
- Risiko: NIEDRIG — `Measurement/` und `LooseEndsLab/` kompilieren nicht in die Haupt-App, keine
  Nutzerdaten betroffen, kein Modellverhalten geändert

## Technische Umsetzung

1. **`Corpus.load` bekommt einen Namensparameter mit unverändertem Default.** Die Bundle-/Datei-Suche
   bleibt exakt wie heute (`Bundle(for: CorpusAnchor.self)` zuerst, dann die Datei neben der
   Quelldatei), nur der gesuchte Dateiname wird zum Parameter. `Corpus.fileName` bleibt als
   Standardwert bestehen, damit kein bestehender Aufruf (`Corpus.load()` in `CorpusTests`,
   `DateParserCorpusTests`, `DateTitleReportTests`) angepasst werden muss.
2. **`MeasurementResult.runIndex` mit eigenem Decoder, nicht mit synthetisiertem `Codable`.** Ein
   neues, nicht-optionales `Int`-Feld mit Default würde bei Swifts synthetisiertem `Decodable` für
   ältere JSON-Dateien ohne dieses Feld fehlschlagen (anders als bei optionalen Feldern wie
   `errorKind`). `MeasurementResult` bekommt darum — nach demselben Muster, das `MeasurementRun`
   bereits für `events` verwendet (`Measurement/MeasurementRun.swift:79-86`) — einen eigenen
   `init(from decoder:)`, der `runIndex` per `decodeIfPresent(Int.self, forKey:) ?? 0` liest. Das ist
   die Voraussetzung für AC-3 und für die harte Nebenbedingung, dass laufende Mehrtage-Messungen beim
   nächsten App-Start weiterlaufen.
3. **`remaining(from:runsPerEntry:)` zählt Erfolge je `entryID`, statt nur Mitgliedschaft zu prüfen.**
   Für jeden Korpus-Eintrag wird die Anzahl bereits erfolgreicher Ergebnisse mit passender `entryID`
   ermittelt (`succeeded.filter { $0.entryID == entry.id }.count`); ist sie kleiner als `runsPerEntry`,
   werden die fehlenden `runIndex`-Werte fortlaufend ab der bisherigen Erfolgsanzahl erzeugt. Für den
   Default `runsPerEntry = 1` ist das Ergebnis identisch zum bisherigen Verhalten (ein Satz mit einem
   Erfolg liefert keinen offenen Eintrag mehr) — AC-3. Die Rückgabe wechselt von `[Corpus.Entry]` zu
   `[(entry: Corpus.Entry, runIndex: Int)]`, weil der Aufrufer wissen muss, welcher Lauf als Nächstes
   fällig ist.
4. **Kein exaktes Set erledigter Indizes, sondern ein einfacher Zähler.** Die Lab-App misst
   grundsätzlich sequenziell (ein Satz, ein Lauf nach dem anderen, ein fehlgeschlagener Versuch
   erzeugt kein Erfolgsergebnis und blockiert daher keinen späteren Index) — ein reiner Zähler je
   `entryID` reicht für dieses Ablaufmuster und bleibt einfacher als ein `Set<Int>` je Satz (siehe
   Alternative 3 unten).
5. **`MeasurementRunner` bekommt zwei neue, mit sicherem Default versehene Init-Parameter**
   (`corpusFileName`, `runsPerEntry`) statt eines neuen Typs — bestehende Aufrufer
   (`MeasurementRunner()` in `LabApp`, etwaige Tests) bleiben unverändert lauffähig. `done` wird zu
   `run.succeeded.count` (Gesamtzahl erfolgreicher Läufe, nicht mehr unterschiedlicher Sätze), `total`
   zu `entries.count * runsPerEntry`.
6. **`measure(_:runIndex:)` schreibt den übergebenen Index unverändert ins `MeasurementResult`** — der
   Modellaufruf selbst (`enricher.enrich(input)`) bleibt unverändert; `runIndex` beeinflusst nur, was
   gespeichert wird, nicht, was gemessen wird.
7. **`LabApp.init()` liest `--corpus <name>` nach demselben Muster wie das bestehende
   `--measure`-Flag** (`LabView.task`, `CommandLine.arguments.contains("--measure")`): ein einfacher
   Scan von `CommandLine.arguments` nach `--corpus`, gefolgt vom nächsten Argument als Dateiname. Ohne
   das Flag bleibt der bisherige Default `Corpus.fileName` unverändert — Hennings eigene Kopie der
   Labor-App wird nie mit diesem Argument gestartet, genau wie bei `--measure` heute schon.
8. **Kein Eingriff in `MeasurementPacing`, `FoundationModelsEnricher` oder `EnrichmentWriter`.** Die
   Drosselungslogik, der Modellaufruf und die Schreib-Schwelle bleiben unverändert — dieser Schnitt
   ändert ausschließlich, *wie oft* und *gegen welches Korpus* gemessen wird, nicht *was* gemessen
   wird.

### Alternativen

- **Eigener `MultiRunMeasurementRunner` neben `MeasurementRunner`, statt der bestehenden Klasse neue
  Parameter zu geben:** vermeidet Anpassungen am bestehenden Code, verdoppelt aber
  Drosselungs-/Fortsetzungslogik, Szenenverwaltung und Idle-Timer-Handling — genau der
  Parallel-Code-Pfad, den die Analyse ausdrücklich ausschließt. Verworfen. Kippt keine bestehende ADR.
- **N getrennte Ergebnisdateien statt eines `runIndex`-Felds** (eine `MeasurementStore`-Datei je
  Lauf-Nummer): löst Mehrfachzählung ohne Schema-Änderung an `MeasurementResult`, verteilt aber einen
  zusammengehörigen Messlauf über mehrere Dateien und erschwert `lab-fetch`/Report-Aggregation in
  Schritt 2 (dort wird „5 Läufe desselben Satzes" als Einheit gebraucht, um Einstimmigkeit zu prüfen).
  Verworfen — würde in Schritt 2 mehr Aufwand erzeugen, als es hier spart. Kippt keine bestehende ADR.
- **Exaktes `Set<Int>` erledigter `runIndex`-Werte je Satz statt eines reinen Zählers:** robuster
  gegenüber Lücken (z. B. Lauf 1 schlägt fehl, Läufe 0 und 2 sind bereits erfolgreich). Kommt im
  sequenziellen Ablauf der Lab-App aber nicht vor, weil ein fehlgeschlagener Versuch nie als
  Erfolgsergebnis gespeichert wird und daher keinen Index „belegt". Zurückgestellt als mögliche
  spätere Härtung, falls Schritt 2 zeigt, dass Lücken doch auftreten (z. B. durch parallele
  Messläufe). Kippt keine bestehende ADR.

## Testplan

### Automatisierte Tests (TDD RED)

- [ ] `CorpusTests`, neuer Fall: GIVEN der Dateiname `"date-title-corpus"` explizit übergeben / WHEN
  `Corpus.load(fileName: "date-title-corpus")` aufgerufen wird / THEN liefert es dieselben 317
  Einträge wie `Corpus.load()` ohne Argument (AC-1).
- [ ] `CorpusTests`, neuer Fall: GIVEN ein nicht existierender Dateiname / WHEN `Corpus.load(fileName:)`
  aufgerufen wird / THEN wirft es denselben `CocoaError(.fileNoSuchFile)` wie heute bei fehlender
  Standarddatei (AC-1).
- [ ] `MeasurementRunTests`, neuer Fall: GIVEN ein `MeasurementRun` mit zwei erfolgreichen Ergebnissen
  zur selben `entryID` (`runIndex` 0 und 1) und `runsPerEntry = 3` / WHEN `remaining(from:runsPerEntry:)`
  aufgerufen wird / THEN enthält das Ergebnis genau ein Paar mit `runIndex == 2` für diesen Satz
  (AC-2).
- [ ] `MeasurementRunTests`, neuer Fall: GIVEN drei erfolgreiche Ergebnisse zur selben `entryID` und
  `runsPerEntry = 3` / WHEN `remaining(from:runsPerEntry:)` aufgerufen wird / THEN taucht dieser Satz
  nicht mehr in der Rückgabe auf (AC-2).
- [ ] `MeasurementRunTests`, neuer Fall: GIVEN JSON einer alten Ergebnisdatei ohne `runIndex`-Schlüssel
  (Vorlage: bestehender Test „Alte Ergebnisdatei ohne Ereignisse bleibt lesbar") / WHEN sie dekodiert
  wird / THEN ist `runIndex == 0`, und `remaining(from:)` ohne `runsPerEntry`-Argument behandelt den
  Satz als erledigt, sobald ein Erfolgsergebnis vorliegt — wie vor diesem Schnitt (AC-3).
- [ ] Neuer `MeasurementRunnerTests`-Fall (oder Erweiterung von `MeasurementRunTests`, je nach
  vorhandener Test-Infrastruktur für `MeasurementRunner` auf dem Mac): GIVEN ein In-Memory-Korpus mit
  2 Sätzen und `runsPerEntry = 3` / WHEN `total`/`done`/`progress` direkt nach der Initialisierung
  gelesen werden (vor jedem Messversuch) / THEN ist `total == 6`, `done == 0`,
  `progress == 0` (AC-4).
- [ ] Wie oben, nach Einspielen von vier erfolgreichen `MeasurementResult`-Einträgen ins `MeasurementRun`
  / THEN ist `done == 4`, `progress == 4.0/6.0` (AC-4).
- [ ] Test für `remaining(from:runsPerEntry:)` mit einem zweiten, abweichenden Korpusnamen: GIVEN ein
  `MeasurementRunner`, der mit `corpusFileName: "focusblox-corpus"` (Test-Fixture statt echtem
  FocusBlox-Export) initialisiert wird / WHEN die Instanz ihre Einträge lädt / THEN stammen sie aus
  dieser Datei, nicht aus `date-title-corpus` (AC-5).
- [ ] Test für aufsteigende `runIndex`-Werte: GIVEN ein `MeasurementRunner` mit `runsPerEntry = 2` und
  einem einzelnen Korpus-Eintrag / WHEN zwei aufeinanderfolgende Messversuche für denselben Satz
  simuliert werden (`measure(_:runIndex:)` direkt aufgerufen, kein echter Modellaufruf nötig) / THEN
  trägt das erste gespeicherte Ergebnis `runIndex == 0`, das zweite `runIndex == 1` (AC-5).
- [ ] Neuer Test für `LabApp`/Argument-Parsing: GIVEN eine Argumentliste
  `["LooseEndsLab", "--corpus", "focusblox-corpus"]` / WHEN die Auswahlfunktion (freistehende, aus
  `LabApp.init()` herausgezogene Hilfsfunktion, damit sie ohne SwiftUI-Lebenszyklus testbar ist) sie
  auswertet / THEN liefert sie `"focusblox-corpus"`; ohne das Argument liefert sie `Corpus.fileName`
  (AC-6).
- [ ] Bestehende Suiten bleiben grün: GIVEN der geänderte Code / WHEN `./scripts/sim.sh unit` läuft /
  THEN bestehen `CorpusTests`, `MeasurementRunTests`, `DateParserCorpusTests`, `DateTitleReportTests`
  und `EnrichmentTests` unverändert, weil dieser Schnitt keinen Produktpfad berührt und alle
  Default-Parameter das bisherige Verhalten erhalten.

Kein UI-Test: Dieser Schnitt ändert keine SwiftUI-View über reine Argument-Auswertung hinaus und
keinen Produktcode — die Erweiterung lebt in `Measurement/` und `LooseEndsLab/`. Kein Test ruft dabei
das Modell auf ([[feedback-phone-is-not-a-test-bench]] bleibt gewahrt: die neuen Tests prüfen reine
Zähl-/Lade-Logik mit In-Memory-Daten, keine echte Messung). Der Nachweis läuft über den Mac-Testlauf.

## Definition of Done

- [ ] AC-1 bis AC-6 erfüllt, belegt durch die im Testplan genannten Tests
- [ ] `./scripts/sim.sh unit` grün, inklusive aller bestehenden Suiten
- [ ] CI grün
- [ ] PR mit `Closes` auf ein neu anzulegendes Sub-Issue von #65 für Schritt 1 gemergt
- [ ] Hennings Hauptordner nachgezogen und Projekt neu erzeugt
  (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] Sub-Issue für Schritt 2 (Selbstkonsistenz-Signal) angelegt und in #65 verlinkt, mit Verweis auf
  diese Spec als Fundament

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Der geänderte Code liegt vollständig in `Measurement/` und `LooseEndsLab/` —
  Messcode, kein Produktpfad, keine neue Abhängigkeit, kein Eingriff in `Shared/`. Es entsteht kein
  neuer Architekturbaustein, nur eine Parametrisierung bestehender Typen und Funktionen; die
  Projektregel „Regeln vor Modell" ist hier nicht einschlägig, weil keine der Änderungen ein Modell
  ersetzt oder ergänzt — es handelt sich um reine Zähl- und Lade-Logik ohne jeden Sprachverstehens-
  Bezug.

## Changelog

- 2026-09-22: Spec aus dem Analyse-Kontext (`docs/context/spike-65-unsicherheitssignal.md`) erstellt.
