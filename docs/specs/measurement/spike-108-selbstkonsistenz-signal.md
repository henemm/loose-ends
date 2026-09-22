---
entity_id: spike-108-selbstkonsistenz-signal
type: feature
created: 2026-09-22
updated: 2026-09-22
status: draft
workflow: spike-108-selbstkonsistenz-signal
---

# Spec: Spike #108 — Selbstkonsistenz-Signal am FocusBlox-Korpus (#65, Schnitt 2)

**Status:** draft · **Workflow:** spike-108-selbstkonsistenz-signal · **Erstellt:** 2026-09-22 · **Aktualisiert:** 2026-09-22

## Freigabe

- [ ] Freigegeben

## Problem

Spike #65 prüft die tragende Annahme A1 („Das Modell weiß, wann es nicht weiß",
`docs/project/06-annahmen-und-experimente.md`, Zeile 104): trennt ein Unsicherheits-Signal richtige
von falschen Modellausgaben zuverlässig genug, um es produktiv zu nutzen? Schnitt 1 (#107, gemergt)
liefert dafür nur das Fundament — mehrere Läufe je Satz zählen statt nur Satz-Mitgliedschaft zu
prüfen, ein Korpus lässt sich per Namen laden. Es existiert noch kein Signal und keine Auswertung.

`FoundationModelsEnricher` liefert für `importance`, `urgency`, `duration`, `energy`, `contexts`,
`people`, `project` je eine `EnrichmentDraft.Guess<T>` mit eigener `confidence`
(`Shared/Enrichment/EnrichmentDraft.swift:6-27`) — diese Konfidenz ist aber eine reine
Selbstauskunft des Modells, keine gemessene Trefferquote. Ob sie mit der tatsächlichen Richtigkeit
zusammenhängt, prüft die bestehende `FocusBloxCalibrationTests` bereits für einen Lauf je Satz
(#23). A1 fragt nach einem *anderen* Signal: Einstimmigkeit über mehrere unabhängige Läufe desselben
Satzes — liefert das Modell fünfmal denselben Wert, ist das ein Hinweis auf Sicherheit, unabhängig
von der selbstberichteten Konfidenz. Weder `MeasurementResult` noch eine Auswertungsfunktion kennen
heute mehr als `title`/`dueDate`/`dueHasTime`/`people` (`Measurement/MeasurementRun.swift:21-24`),
und der FocusBlox-Export (`scripts/export-focusblox-corpus.swift`) schreibt ein eigenes Schema statt
`Corpus.Entry` — die Schnitt-1-Lade-Infrastruktur (`Corpus.load(fileName:)`,
`remaining(from:runsPerEntry:)`, `MeasurementProgress`, `--corpus`) kann den FocusBlox-Korpus damit
noch nicht fahren.

**Zentraler Befund aus der Analyse, der den Zuschnitt korrigiert:** Der FocusBlox-Export liefert
keine Wahrheit für `people` und `project` — beide Spalten existieren in der `ZLOCALTASK`-Tabelle
nicht (SQL-Query in `scripts/export-focusblox-corpus.swift:152-157` hat keine entsprechende Spalte;
`docs/project/02-datenmodell-und-ansichten.md` Zeile 202ff. nennt sie auch nicht in der
Mapping-Tabelle). Ohne Wahrheit lässt sich für diese beiden Felder keine Trefferquote bilden; A1s
Abbruchkriterium (≥ 85 % Trefferquote bei ≥ 30 % Abdeckung) ist für sie grundsätzlich nicht prüfbar,
egal wie hoch ihre Selbstkonsistenz ausfällt. Für `people` kommt hinzu, dass die Qualitätsfrage
bereits am 2026-09-21 zurückgestellt wurde (#105, „kein bekannter Use Case, deshalb nicht
gemessen"); `project` gilt in derselben Analyse als Stufe C, geringste Priorität.

## Zweck

Dieser Schnitt misst die Selbstkonsistenz (Einstimmigkeit über 5 Modell-Läufe je Satz) und daraus
eine Trefferquote-über-Abdeckung-Kurve, für genau die fünf Felder mit echter Wahrheit im
FocusBlox-Export: `importance`, `urgency`, `duration`, `energy`, `contexts`. Er liefert den
Mechanismus (Schema-Erweiterung, Auswertungsfunktionen, Report-Generator) — nicht das
Messergebnis selbst: Der eigentliche mehrtägige Lauf auf Hennings Gerät ist bewusst nicht Teil
dieser Spec, ebenso wenig die daraus folgende Design-Entscheidung zu
`EnrichmentWriter.confidenceThreshold`.

## Quelle

- **Datei:** `Measurement/Corpus.swift`
  **Bezeichner:** `struct Entry` (neue Felder `lang`, `text`, `importanceTruth`, `urgencyTruth`,
  `durationTruth`, `energyTruth`, `contextsTruth: [String]?`)
- **Datei:** `Measurement/MeasurementRun.swift`
  **Bezeichner:** `struct MeasurementResult` (neue Felder `importance`, `urgency`, `duration`,
  `energy: String?`, `contexts: [String]`)
- **Datei:** `LooseEndsLab/MeasurementRunner.swift`
  **Bezeichner:** `func measure(_ entry: Corpus.Entry, runIndex: Int) async -> MeasurementResult`
  (befüllt die neuen `MeasurementResult`-Felder aus `draft`)
- **Datei:** `LooseEndsLab/LabApp.swift`
  **Bezeichner:** `struct LabApp` (`init()` liest zusätzlich `--runs <n>`, Default 1)
- **Datei:** `scripts/export-focusblox-corpus.swift`
  **Bezeichner:** `struct CorpusTask` (schreibt zusätzlich `lang`, `text`, die fünf
  Wahrheitsfelder)
- **Datei:** `Measurement/SelfConsistency.swift` (neu)
  **Bezeichner:** `enum SelfConsistency` — `static func majority(...)`,
  `static func agreement(...)`, `static func table(field:...)`
- **Datei:** `LooseEndsTests/SelfConsistencyReportTests.swift` (neu, Name vorläufig)
  **Bezeichner:** `struct SelfConsistencyReportTests` (`.enabled(if:)`-Suite, kein Modellaufruf)

**Nachtrag aus der RED-Phase (2026-09-22):** `MeasurementRunner.measure(_:runIndex:)` ist `private`
und liegt in `LooseEndsLab/MeasurementRunner.swift`, das `UIKit` unbedingt importiert und nur für
`platform: iOS` kompiliert (wie schon in Schnitt 1 festgestellt) — am Mac nicht direkt testbar. Für
AC-3 kommt hinzu: die Werte kommen aus `EnrichmentDraft.Guess<T>`, einem Typ aus dem `LooseEnds`-App-
Modul, aber `Measurement/MeasurementRun.swift` wird sowohl in `LooseEndsLab` (dort ist
`EnrichmentDraft.swift` eine Geschwisterdatei im selben Modul, kein Import nötig oder möglich) als
auch in `LooseEndsTests` (dort ist `EnrichmentDraft` nur über `@testable import LooseEnds` sichtbar)
kompiliert — ein einzelnes `import`-Statement in dieser Datei kann nicht beide Kontexte gleichzeitig
erfüllen. Die Durchreich-Logik zieht darum als reine Berechnung in `Shared/Enrichment/EnrichmentDraft.swift`
selbst ein (dort bereits für alle drei Ziele — `LooseEnds`, `LooseEndsLab`, `LooseEndsTests` — sichtbar,
keine neue Datei, kein Eintrag in `project.yml` nötig): `EnrichmentDraft.selfConsistencyValues: (importance:
String?, urgency: String?, duration: String?, energy: String?, contexts: [String])`. AC-3 prüft diese
Eigenschaft direkt; `measure(_:runIndex:)` liest sie nur noch aus, ohne die Guess-Entpackung zu
wiederholen. Damit kommt `Shared/Enrichment/EnrichmentDraft.swift` als achte MODIFY-Datei zum Umfang
hinzu (Ergänzung der „Betroffene Dateien"-Tabelle unten); die Umsetzung bleibt reines Durchreichen,
keine neue Abhängigkeit, keine Verhaltensänderung — nur der Ort, an dem eine bereits geplante Zeile
Code steht.

Ebenfalls aus der RED-Phase konkretisiert, weil die Tests eine feste Signatur brauchen —
`Measurement/SelfConsistency.swift` liefert: `static func majority(_ values: [String?]) -> String?`,
`static func agreement(_ values: [String?]) -> Double` (Einzelwert-Felder); `static func majoritySet(_
values: [[String]]) -> Set<String>?`, `static func agreementSet(_ values: [[String]]) -> Double`
(`contexts`, Mengengleichheit); `struct Outcome { var agreement: Double; var correct: Bool }` und
`static func table(field: String, outcomes: [Outcome]) -> String` (Tabelle „Einstimmigkeit /
Abdeckung / Trefferquote" über `static let thresholds: [Double] = [0.6, 0.8, 1.0]`, Vorbild
`FocusBloxCalibrationTests.table(field:outcomes:)`).

## Acceptance Criteria

- **AC-1 `Corpus.Entry` lädt die FocusBlox-Wahrheitsfelder additiv:** Given eine Korpus-Datei mit
  den bestehenden `Corpus.Entry`-Schlüsseln (`id`, `lang`, `text`, `date`, …) plus zusätzlich
  `importanceTruth: "high"`, `urgencyTruth: "low"`, `durationTruth: "minutes15"`,
  `energyTruth: "high"`, `contextsTruth: ["zuhause", "telefon"]` / When `Corpus.load(fileName:)`
  diese Datei dekodiert / Then trägt der geladene `Entry` alle fünf Werte unverändert, und ein
  bestehender Eintrag der `date-title-corpus`-Datei ohne diese Schlüssel dekodiert weiterhin
  erfolgreich mit allen fünf Feldern `nil` (rein additiv, kein bestehender Test bricht).
- **AC-2 `MeasurementResult` trägt die fünf neuen Rohwerte, rückwärtskompatibel:** Given JSON einer
  vor diesem Schnitt geschriebenen Ergebnisdatei ohne die Schlüssel `importance`, `urgency`,
  `duration`, `energy`, `contexts` / When sie dekodiert wird / Then sind `importance`, `urgency`,
  `duration`, `energy` `nil` und `contexts` `[]` (kein Absturz, keine fehlende Datei); Given ein
  neues `MeasurementResult` mit diesen fünf Werten gesetzt / When es kodiert und wieder dekodiert
  wird / Then sind alle fünf Werte identisch zum Original.
- **AC-3 `MeasurementRunner.measure(_:runIndex:)` reicht `draft` durch, ohne neuen Modellaufruf:**
  Given ein `EnrichmentDraft` mit gesetzten `importance`/`urgency`/`duration`/`energy`/`contexts`
  / When `measure(_:runIndex:)` mit diesem Draft aufgerufen wird (Enricher-Stub/Fake) / Then trägt
  das zurückgegebene `MeasurementResult` exakt `draft.importance?.value.rawValue`,
  `draft.urgency?.value.rawValue`, `draft.duration?.value.rawValue`,
  `draft.energy?.value.rawValue`, `draft.contexts?.value ?? []` — kein zweiter Aufruf an
  `FoundationModelsEnricher.enrich(_:)` gegenüber dem heutigen Verhalten.
- **AC-4 `--runs <n>` steuert `runsPerEntry`, Default bleibt 1:** Given Startargumente inklusive
  `--runs 5` / When `LabApp` initialisiert wird / Then wird `MeasurementRunner` mit
  `runsPerEntry: 5` erzeugt; ohne das Argument bleibt `runsPerEntry: 1` (Hennings eigene Kopie der
  Labor-App verhält sich unverändert).
- **AC-5 Mehrheitswert und Einstimmigkeit für Einzelwert-Felder:** Given fünf `MeasurementResult`
  derselben `entryID` mit `importance` = `["high", "high", "high", "medium", "high"]` / When
  `SelfConsistency.majority(...)`/`agreement(...)` für das Feld `importance` aufgerufen wird / Then
  ist der Mehrheitswert `"high"` und die Einstimmigkeit `0.8` (4 von 5).
- **AC-6 Mehrheit und Einstimmigkeit für `contexts` (Mengenfeld, exakte Gleichheit):** Given fünf
  `MeasurementResult` derselben `entryID` mit `contexts` = `[["a","b"], ["b","a"], ["a","b"],
  ["a"], ["a","b"]]` / When `SelfConsistency.majority`/`agreement` für `contexts` aufgerufen wird
  / Then zählt `["a","b"]` und `["b","a"]` als derselbe Mehrheitsantwort (Mengengleichheit, nicht
  Reihenfolge), der Mehrheitswert ist `{"a","b"}`, die Einstimmigkeit ist `0.8` (4 von 5); Given
  zusätzlich eine FocusBlox-Wahrheit `contextsTruth = ["a"]` für denselben Satz / Then gilt die
  Mehrheitsantwort `{"a","b"}` als *falsch* gegenüber der Wahrheit (exakte Mengengleichheit, kein
  Teiltreffer).
- **AC-7 Trefferquote-über-Abdeckung-Tabelle je Feld:** Given eine Menge von
  `(Mehrheitswert, Einstimmigkeit, Wahrheit)`-Tripeln über mehrere Sätze eines Feldes (Vorbild:
  `FocusBloxCalibrationTests.table(field:outcomes:)`) / When
  `SelfConsistency.table(field:outcomes:)` aufgerufen wird / Then enthält die Ausgabe eine Zeile je
  Einstimmigkeits-Schwelle mit Spalten „Einstimmigkeit / Abdeckung / Trefferquote", wobei Abdeckung
  der Anteil der Sätze mit Einstimmigkeit ≥ Schwelle ist und Trefferquote der Anteil davon, dessen
  Mehrheitswert der Wahrheit entspricht (analog `precision`/`written` im Vorbild, aber ohne
  Recall-Spalte, weil es ohne Konfidenzschwelle keinen zweiten unabhängigen Nenner gibt).
- **AC-8 Export schreibt die neuen Schlüssel additiv:** Given `scripts/export-focusblox-corpus.swift`
  läuft gegen den bestehenden Beispiel-Datensatz / When die JSON-Ausgabe geprüft wird / Then
  enthält jeder Eintrag zusätzlich zu allen bisherigen Schlüsseln `lang: "de"`, `text` (identisch zu
  `rawText`) sowie `importanceTruth`/`urgencyTruth`/`durationTruth`/`energyTruth`/`contextsTruth`
  (aus den bestehenden Feldern `importance`/`urgency`/`durationBucket`/`energy`/`contexts`
  übernommen), und kein bisheriger Schlüssel fehlt oder ändert seinen Wert.
- **AC-9 Report-Test liest nur vorhandene Dateien, ruft kein Modell:** Given zwei lokal vorhandene
  JSON-Dateien (FocusBlox-Wahrheit und eine `MeasurementRun`-Ergebnisdatei mit mehreren Läufen je
  Satz) / When `SelfConsistencyReportTests` läuft / Then schreibt sie
  `docs/reference/uncertainty-signal-selfconsistency-report.md` mit einer Tabelle je der fünf
  Felder, ohne `FoundationModelsEnricher.enrich(_:)` aufzurufen; fehlt eine der beiden Dateien, ist
  die Suite per `.enabled(if:)` deaktiviert (läuft insbesondere nie in CI).

## Nicht in diesem Schnitt

- Der eigentliche mehrtägige Messlauf auf Hennings Gerät (5 Läufe × 287 FocusBlox-Sätze). Dieser
  Schnitt liefert Code (Skript + reine Auswertung + Report-Generator), keine fertigen
  Messergebnisse.
- Die Design-Entscheidung zu `EnrichmentWriter.confidenceThreshold` (0,6) — hängt vom
  Messergebnis dieses Signals ab, nicht Teil dieser Spec.
- Eine weichere Mengenmetrik für `contexts` (Jaccard, F1 statt exakter Mengengleichheit). Die
  Analyse empfiehlt exakte Gleichheit, weil sie ohne neue Metrik auskommt und mit derselben
  Einstimmigkeits-Definition wie die Einzelwert-Felder rechnet; eine weichere Metrik ist bei Bedarf
  ein späterer Nachschlag.
- Selbstkonsistenz-Messung für `people` und `project` — beide haben keine Wahrheit im
  FocusBlox-Export, siehe „Zentraler Befund" oben. Weder `Corpus.Entry` noch `MeasurementResult`
  bekommen in diesem Schnitt ein `projectTruth`/`projectConfidence`-Feld; `people` existiert bereits
  in `MeasurementResult` und wird nicht erweitert.

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `FoundationModelsEnricher.enrich(_:)` | Funktion | Unverändert, reiner Datenlieferant — `measure(_:runIndex:)` liest zusätzliche Felder aus dem bereits vorhandenen `draft`. |
| `EnrichmentDraft.Guess<T>` | Typ | Unverändert; Quelle der neuen `MeasurementResult`-Felder (`.value`, ggf. `.rawValue` bei den Enum-Typen). |
| `Corpus.Entry` / `MeasurementResult` / `MeasurementRun.remaining` / `MeasurementProgress` (Schnitt 1) | Typen | Werden additiv erweitert, nicht ersetzt — die komplette Lade-/Zähl-/Fortsetz-Infrastruktur aus #107 bleibt unverändert nutzbar. |
| `scripts/export-focusblox-corpus.swift` | Skript | Liefert die Rohdaten; läuft nur lokal bei Henning, Ausgabe bleibt gitignored. |
| `FocusBloxCalibrationTests.swift` | Test-Vorbild | Tabellen- und `.enabled(if:)`-Muster für den neuen Report-Test; bleibt selbst unverändert, weil alle Änderungen additiv sind. |

## Umfang

### Betroffene Dateien

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/Corpus.swift` | MODIFY | `Corpus.Entry` um `lang`/`text`-Duplikat (bereits im Decoder vorhanden, siehe unten) und fünf optionale Wahrheitsfelder (`importanceTruth`, `urgencyTruth`, `durationTruth`, `energyTruth`, `contextsTruth: [String]?`) erweitern. |
| `Measurement/MeasurementRun.swift` | MODIFY | `MeasurementResult` um `importance`, `urgency`, `duration`, `energy: String?` sowie `contexts: [String]` erweitern, mit eigenem Decoder (`decodeIfPresent`, analog `runIndex`), rückwärtskompatibel. |
| `LooseEndsLab/MeasurementRunner.swift` | MODIFY | `measure(_:runIndex:)` befüllt die fünf neuen `MeasurementResult`-Felder aus `draft` (reines Durchreichen). |
| `LooseEndsLab/LabApp.swift` | MODIFY | `init()` liest zusätzlich `--runs <n>` (analog `--corpus`), reicht den Wert als `runsPerEntry` an `MeasurementRunner` durch, Default 1. |
| `scripts/export-focusblox-corpus.swift` | MODIFY | `CorpusTask` bzw. die JSON-Ausgabe schreibt zusätzlich `lang`, `text`, die fünf Wahrheitsfelder; bestehende Schlüssel unverändert. |
| `Shared/Enrichment/EnrichmentDraft.swift` | MODIFY | Nachtrag aus der RED-Phase: `EnrichmentDraft.selfConsistencyValues` (reine Berechnung, kein neuer Typ) — Grund und genaue Signatur siehe Nachtrag oben. |
| `Measurement/SelfConsistency.swift` | CREATE | Reine Funktionen: Gruppierung nach `entryID`, Mehrheitswert + Einstimmigkeit je Feld (Einzelwert und Mengenfeld), Trefferquote-über-Abdeckung-Tabelle. |
| `LooseEndsTests/SelfConsistencyReportTests.swift` (Name vorläufig) | CREATE | Gated Report-Test (`.enabled(if:)`), liest zwei lokale JSON-Dateien, kein Modellaufruf, schreibt `docs/reference/uncertainty-signal-selfconsistency-report.md`. |

**Hinweis zu `Corpus.Entry.lang`/`.text`:** Beide Schlüssel existieren im bestehenden Decoder
bereits (`Measurement/Corpus.swift:29-30,48`) für den `date-title-corpus`; sie werden hier nicht neu
eingeführt, sondern der FocusBlox-Export lernt, sie zusätzlich zu schreiben, damit
`Corpus.load(fileName:)` ihn unverändert laden kann.

### Geschätzter Umfang

- Dateien im Scope: 8 (Nachtrag aus der RED-Phase: `Shared/Enrichment/EnrichmentDraft.swift` kommt als
  achte MODIFY-Datei hinzu, siehe Nachtrag oben) — bewusst über dem Standard-Richtwert von 4-5. Nicht gesplittet, weil die
  Teile einseitig abhängig sind (Schema-Erweiterung → Export-Änderung → Auswertung → Report); ein
  Split ließe eine Zwischen-PR mit totem Code zurück (Export schreibt Felder, die niemand liest,
  oder Auswertung ohne Datenquelle). Die Fundament-Spec (Schnitt 1) hat diesen Schnitt bereits als
  eine zusammenhängende Folge-Spec vorgesehen.
- LoC gesamt: geschätzt rund +260/-15 — leicht über der ±250-LoC-Grenze, größtenteils neuer,
  isolierter Auswertungscode (`Corpus.swift` +25/-2, `MeasurementRun.swift` +25/-5,
  `MeasurementRunner.swift` +10/-2, `LabApp.swift` +8/-1, Export-Skript +10/-2,
  `SelfConsistency.swift` +90 neu, Report-Test +90 neu).
- Risiko: NIEDRIG für das Produkt — alle Änderungen bleiben in `Measurement/`, `LooseEndsLab/`,
  `LooseEndsTests/`, `scripts/` (kompilieren laut `CLAUDE.md` nie in den Produktpfad); jede
  Erweiterung ist additiv/rückwärtskompatibel, `FoundationModelsEnricher` und `EnrichmentWriter`
  bleiben unangetastet. MITTEL für den Umfang — sieben Dateien statt vier, weil ein neuer Signaltyp
  (Selbstkonsistenz statt Konfidenz) einen eigenen Auswertungs- und Report-Pfad braucht, der nicht
  aus Schnitt 1 wiederverwendbar ist.

## Technische Umsetzung

1. **`Corpus.Entry` bekommt fünf neue optionale Wahrheitsfelder**, dekodiert wie die bestehenden
   optionalen Felder (`entityList`, `peopleList`, `formName`) über `decodeIfPresent` im
   synthetisierten oder einem leicht erweiterten `CodingKeys`-Enum — kein eigener `init(from:)`
   nötig, weil alle fünf neuen Felder optional sind und Swifts synthetisiertes `Decodable` bei
   fehlendem Schlüssel für `Optional`-Felder bereits `nil` liefert (anders als bei `runIndex` in
   Schnitt 1, das ein nicht-optionales `Int` mit Default war).
2. **`MeasurementResult` bekommt die fünf neuen Felder mit eigenem Decoder**, nach demselben Muster
   wie `runIndex` (#65, `Measurement/MeasurementRun.swift:57-71`): `importance`/`urgency`/
   `duration`/`energy` als `String?` über `decodeIfPresent(String.self, forKey:)`, `contexts` als
   `[String]` über `decodeIfPresent([String].self, forKey:) ?? []`. Das ist die Voraussetzung für
   AC-2 — alte Ergebnisdateien ohne diese Schlüssel bleiben lesbar, ein laufender Mehrtage-Messlauf
   bricht beim nächsten App-Start nicht ab.
3. **`MeasurementRunner.measure(_:runIndex:)` schreibt die fünf Werte aus `draft`** — genau dort,
   wo heute schon `result.people = draft.people?.value ?? []` steht
   (`LooseEndsLab/MeasurementRunner.swift:145`): `result.importance = draft.importance?.value.rawValue`,
   entsprechend für `urgency`/`duration`/`energy`, `result.contexts = draft.contexts?.value ?? []`.
   Kein zweiter Aufruf an `enricher.enrich(input)`, keine Änderung an `FoundationModelsEnricher`.
4. **`LabApp.init()` liest `--runs <n>`** nach demselben Muster wie das bestehende `--corpus`-Flag
   (`Corpus.corpusFileName(from:flag:)`, `Measurement/Corpus.swift:125-130`): eine neue,
   freistehende Hilfsfunktion (z. B. `Corpus.runsPerEntry(from:flag:)` oder direkt in `LabApp`), die
   `CommandLine.arguments` nach `--runs` scannt und den folgenden Wert als `Int` parst; fehlt das
   Flag oder ist der Wert nicht parsbar, bleibt der Default `1`.
5. **`Measurement/SelfConsistency.swift` (neue Datei) mit reinen Funktionen**, ohne Modellaufruf und
   ohne Plattform-Import über `Foundation` hinaus:
   - Gruppierung: `[MeasurementResult]` nach `entryID`, nur `succeeded`-Ergebnisse.
   - Mehrheit + Einstimmigkeit je Einzelwert-Feld: häufigster nicht-`nil`-Wert unter den Läufen
     einer `entryID`, Einstimmigkeit = Anteil der Läufe mit diesem Wert an allen Läufen dieser
     `entryID`.
   - Mehrheit + Einstimmigkeit für `contexts`: Werte werden vor dem Vergleich als `Set<String>`
     behandelt (Mengengleichheit, keine Reihenfolge), sonst identische Logik.
   - „Richtig" je Satz: Mehrheitswert entspricht der jeweiligen `*Truth`-Angabe aus `Corpus.Entry`
     (für `contexts`: exakte Mengengleichheit mit `contextsTruth`).
   - `table(field:outcomes:)`: Spaltenüberschriften „Einstimmigkeit / Abdeckung / Trefferquote"
     statt „Schwelle / Geschrieben / Precision / Recall" im Vorbild
     (`FocusBloxCalibrationTests.table(field:outcomes:)`), weil Einstimmigkeit die Achse ist statt
     einer Konfidenzschwelle, und es ohne Konfidenzschwelle keinen zweiten unabhängigen Nenner für
     eine Recall-Spalte gibt.
6. **Report-Generator als gated Test**, Muster wie `FocusBloxCalibrationTests`
   (`@Suite(.enabled(if: FileManager.default.fileExists(atPath: ...)))`), aber ohne Modellaufruf:
   liest die bereits vorhandene FocusBlox-Wahrheitsdatei und eine bereits vom Gerät geholte
   `MeasurementRun`-Ergebnisdatei (Muster `sim.sh lab-fetch`), gruppiert über `SelfConsistency`,
   schreibt `docs/reference/uncertainty-signal-selfconsistency-report.md`. Läuft nie in CI
   (Datei-Gate), auch ohne Gerät und ohne Modell auf dem Mac — reine Nachverarbeitung zweier
   JSON-Dateien.
7. **`scripts/export-focusblox-corpus.swift` schreibt die neuen Schlüssel additiv**: `lang: "de"`
   fest, `text` als Duplikat von `rawText`, sowie `importanceTruth = importance`,
   `urgencyTruth = urgency`, `durationTruth = durationBucket`, `energyTruth = energy`,
   `contextsTruth = contexts` — alles aus bereits im Skript vorhandenen Werten übernommen, kein
   neuer SQL-Zugriff. Bestehende Schlüssel und ihre Werte bleiben unverändert (AC-8).
8. **Reihenfolge der Umsetzung**: Schema (`Corpus.swift`, `MeasurementRun.swift`) vor Export-Skript
   vor Auswertung (`SelfConsistency.swift`) vor Report-Test — jeder Schritt baut auf dem vorigen
   auf, und ein zu früh geschriebener Report-Test hätte keine Datenquelle.

### Alternativen

- **Eigener `FocusBloxCorpus`-Lade-Pfad statt `Corpus.Entry`-Erweiterung**: ein separater Lade-Pfad
  neben `Corpus.load`, der die FocusBlox-JSON in ihrer heutigen Form liest und intern auf ein
  eigenes Format abbildet, ohne die Export-Datei oder `Corpus.Entry` zu ändern. Vermeidet die
  Erweiterung von `Corpus.Entry`, verdoppelt aber die komplette Lauf-Mechanik aus Schnitt 1 (eigene
  Zählung, eigenes Pacing oder eine zweite Kopie davon) und widerspricht damit der in Schnitt 1
  explizit verworfenen „Parallel-Code-Pfad"-Alternative. Verworfen. Kippt keine bestehende ADR.
- **Selbstkonsistenz ohne Trefferquote auch für `people`/`project` mitschreiben**, als
  beschreibende Zusatzzeile im Report, ausdrücklich ohne Trefferquote-Spalte und ohne
  A1-Tauglichkeit. Dagegen spricht: zusätzlicher Code (`project` müsste neu in `EnrichmentDraft`
  sichtbar in `MeasurementResult` landen, `people` ist zwar schon vorhanden, aber ohne Wahrheit
  sinnlos zu gruppieren) für eine Zahl, die weder das Abbruchkriterium A1 noch die Rückstellung
  #105 beeinflusst. Verworfen für diesen Schnitt, auf Nachfrage nachrüstbar, da
  `MeasurementResult.people` als Rohdaten weiterhin vorhanden ist. Kippt keine bestehende ADR.
- **Weichere Mengenmetrik für `contexts` (Jaccard, F1) statt exakter Mengengleichheit**: würde
  Teiltreffer (ein Kontext von zweien richtig) differenzierter abbilden, braucht aber eine zweite,
  von der Einzelwert-Einstimmigkeit abweichende Metrik-Definition und eine eigene Begründung, welche
  Schwelle „richtig genug" ist. Zurückgestellt als möglicher Nachschlag, falls die exakte
  Mengengleichheit in der Auswertung zu streng wirkt. Kippt keine bestehende ADR.

## Testplan

### Automatisierte Tests (TDD RED)

- [ ] `CorpusTests`, neuer Fall: GIVEN eine Testdatei mit den fünf neuen Wahrheitsfeldern gesetzt /
  WHEN `Corpus.load(fileName:)` sie dekodiert / THEN trägt der `Entry` alle fünf Werte unverändert
  (AC-1).
- [ ] `CorpusTests`, neuer Fall: GIVEN ein Eintrag der bestehenden `date-title-corpus`-Datei ohne
  die neuen Schlüssel / WHEN er dekodiert wird / THEN sind alle fünf Wahrheitsfelder `nil`, kein
  Decoder-Fehler (AC-1).
- [ ] `MeasurementRunTests`, neuer Fall: GIVEN JSON eines `MeasurementResult` ohne die fünf neuen
  Schlüssel (Vorlage: bestehender Test zu `runIndex`-Rückwärtskompatibilität) / WHEN es dekodiert
  wird / THEN sind `importance`/`urgency`/`duration`/`energy` `nil`, `contexts` `[]` (AC-2).
- [ ] `MeasurementRunTests`, neuer Fall: GIVEN ein `MeasurementResult` mit allen fünf neuen Feldern
  gesetzt / WHEN es kodiert und wieder dekodiert wird / THEN sind alle fünf Werte identisch zum
  Original (AC-2).
- [ ] Neuer Test für `measure(_:runIndex:)`-Durchreichen (Fake-Enricher oder direkter Aufruf mit
  vorbereitetem `EnrichmentDraft`, analog zum bestehenden `runIndex`-Test in Schnitt 1): GIVEN ein
  `EnrichmentDraft` mit gesetzten `importance`/`urgency`/`duration`/`energy`/`contexts` / WHEN
  `measure` es verarbeitet / THEN trägt das `MeasurementResult` exakt diese Werte (AC-3).
- [ ] Neuer Test für die `--runs`-Argumentauswertung: GIVEN
  `["LooseEndsLab", "--runs", "5"]` / WHEN die freistehende Auswertungsfunktion sie liest / THEN
  liefert sie `5`; ohne das Argument liefert sie `1` (AC-4).
- [ ] `SelfConsistencyTests` (neu), Fall Einzelwert-Feld: GIVEN fünf `MeasurementResult` derselben
  `entryID` mit `importance` = `["high","high","high","medium","high"]` / WHEN `majority`/`agreement`
  für `importance` aufgerufen werden / THEN ist der Mehrheitswert `"high"`, die Einstimmigkeit `0.8`
  (AC-5).
- [ ] `SelfConsistencyTests`, Fall Mengenfeld: GIVEN fünf `MeasurementResult` mit `contexts` =
  `[["a","b"],["b","a"],["a","b"],["a"],["a","b"]]` / WHEN `majority`/`agreement` für `contexts`
  aufgerufen werden / THEN ist der Mehrheitswert `{"a","b"}` (Reihenfolge irrelevant), die
  Einstimmigkeit `0.8` (AC-6).
- [ ] `SelfConsistencyTests`, Fall Mengenfeld gegen Wahrheit: GIVEN dieselben fünf Ergebnisse und
  `contextsTruth = ["a"]` / WHEN die Trefferermittlung aufgerufen wird / THEN gilt der Satz als
  falsch (keine exakte Mengengleichheit) (AC-6).
- [ ] `SelfConsistencyTests`, Fall Tabelle: GIVEN mehrere `(Mehrheitswert, Einstimmigkeit, Wahrheit)`-
  Tripel über verschiedene Sätze / WHEN `table(field:outcomes:)` aufgerufen wird / THEN enthält die
  Ausgabe eine Zeile je Einstimmigkeits-Schwelle mit korrekt berechneter Abdeckung und Trefferquote
  (AC-7).
- [ ] Export-Skript-Test (manuell verifizierbar über einen kleinen Beispiel-Datensatz im Test, kein
  echter SQLite-Zugriff nötig, da die Mapping-Funktionen bereits reine Funktionen sind): GIVEN ein
  `CorpusTask`-artiger Datensatz mit `importance`/`urgency`/`durationBucket`/`energy`/`contexts`
  gesetzt / WHEN die neuen Zuweisungen (`lang`, `text`, `*Truth`) angewendet werden / THEN
  entsprechen sie den erwarteten Werten, bestehende Schlüssel bleiben unverändert (AC-8). Da das
  Skript ein `#!/usr/bin/env swift`-Script ohne Testziel ist, wird die Mapping-Logik so geschrieben,
  dass sie mit einem lokalen Probe-Lauf des Skripts gegen Testdaten verifiziert werden kann; kein
  neues Test-Target nötig.
- [ ] `SelfConsistencyReportTests`, gated: GIVEN zwei lokal vorhandene JSON-Testdateien (FocusBlox-
  Wahrheit, `MeasurementRun` mit mehreren Läufen je Satz) / WHEN die Suite läuft / THEN schreibt sie
  den Report mit einer Tabelle je Feld, ohne `FoundationModelsEnricher.enrich(_:)` aufzurufen (AC-9).
  Fehlt eine der beiden Dateien, ist die Suite deaktiviert.
- [ ] Bestehende Suiten bleiben grün: GIVEN der geänderte Code / WHEN `./scripts/sim.sh unit` läuft /
  THEN bestehen `CorpusTests`, `MeasurementRunTests`, `DateParserCorpusTests`,
  `DateTitleReportTests`, `EnrichmentTests` und `FocusBloxCalibrationTests` (falls lokal aktiviert)
  unverändert, weil dieser Schnitt keinen Produktpfad berührt und alle Erweiterungen additiv sind.

Kein UI-Test: Dieser Schnitt ändert keine SwiftUI-View über reine Argument-Auswertung hinaus und
keinen Produktcode — die Erweiterung lebt in `Measurement/`, `LooseEndsLab/`, `LooseEndsTests/` und
`scripts/`. Kein Test ruft dabei das Modell auf ([[feedback-phone-is-not-a-test-bench]] bleibt
gewahrt): `SelfConsistency.swift` ist reine In-Memory-Logik über `[MeasurementResult]`, der
Report-Test ist gated, liest nur bereits vorhandene JSON-Dateien und ruft kein Modell auf. Der
Nachweis läuft über den Mac-Testlauf.

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt, belegt durch die im Testplan genannten Tests
- [ ] `./scripts/sim.sh unit` grün, inklusive aller bestehenden Suiten
- [ ] CI grün
- [ ] PR mit `Closes` auf das Sub-Issue von #65/#108 für Schnitt 2 gemergt
- [ ] Hennings Hauptordner nachgezogen und Projekt neu erzeugt
  (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] `docs/reference/uncertainty-signal-selfconsistency-report.md` existiert als Vorlage/Struktur
  (Inhalt erst nach dem tatsächlichen Messlauf auf Hennings Gerät gefüllt — der Lauf selbst ist
  nicht Teil dieses Schnitts)

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Der geänderte Code liegt größtenteils in `Measurement/`, `LooseEndsLab/`,
  `LooseEndsTests/` und `scripts/` — Messcode, kein Produktpfad, keine neue Abhängigkeit. Einzige
  Ausnahme (Nachtrag aus der RED-Phase): `Shared/Enrichment/EnrichmentDraft.swift`, dort **eine**
  zusätzliche, rein berechnende Eigenschaft (`selfConsistencyValues`, keine gespeicherten Felder,
  kein `Codable`-Einfluss, kein Eingriff in `FoundationModelsEnricher` oder `EnrichmentWriter`) — nur
  aus Testbarkeits-Gründen dort statt in `LooseEndsLab/MeasurementRunner.swift` platziert (Nachtrag
  oben). Der Produktpfad selbst (App, Enrichment-Pipeline, Schreib-Schwelle) ändert sich dadurch
  nicht: Die neue Eigenschaft wird von keinem Produktcode aufgerufen, nur vom Messcode. Es entsteht
  sonst kein neuer Architekturbaustein, nur additive Schema- und Zähl-Erweiterungen bestehender
  Typen. Die Projektregel „Regeln vor Modell" ist nicht einschlägig: Dieser Schnitt ersetzt oder
  ergänzt kein Modell, sondern misst nur, wie einstimmig ein bereits bestehender Modellaufruf über
  mehrere Läufe ist — reine Zähl- und Vergleichslogik ohne Sprachverstehens-Bezug.

## Changelog

- 2026-09-22: Spec aus dem Analyse-Kontext (`docs/context/spike-108-selbstkonsistenz-signal.md`)
  erstellt.
