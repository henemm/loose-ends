# Context: Spike #108 — Selbstkonsistenz-Signal am FocusBlox-Korpus (#65, Schnitt 2)

## Request Summary

Teil von #65 (tragende Annahme A1: „Das Modell weiß, wann es nicht weiß"). Fünf Läufe je Satz über
den FocusBlox-Korpus, Einstimmigkeit als Konfidenz-Ersatz für die Felder mit `Guess<T>`
(`importance`, `urgency`, `duration`, `energy`, `contexts`, `people`, `project`). Ziel: eine
Trefferquote-über-Abdeckung-Kurve je Feld, die zeigt, ob Einstimmigkeit richtige von falschen
Feldern trennt — das misst A1 selbst nutzt es nicht als Wahrscheinlichkeit, sondern nur, ob
höhere Übereinstimmung mit höherer Trefferquote einhergeht. Abbruchkriterium (aus
`06-annahmen-und-experimente.md`, A1): kein Signal erreicht ≥ 85 % Trefferquote bei ≥ 30 %
Abdeckung.

Baut auf dem in #107 gemergten Fundament auf (`docs/specs/measurement/spike-65-mehrfachlauf-infrastruktur.md`):
`Corpus.load(fileName:)` wählt den Korpus per Namen, `MeasurementResult.runIndex` unterscheidet
Läufe desselben Satzes, `MeasurementRun.remaining(from:runsPerEntry:)` und `MeasurementProgress`
zählen Läufe statt Sätze, `LabApp`/`MeasurementRunner` akzeptieren `--corpus <name>`.

## Related Files

| File | Relevance |
|------|-----------|
| `Measurement/Corpus.swift` | `Corpus.Entry`-Schema (Wahrheit als Regel: `date: DateExpectation?`), `Corpus.load(fileName:)`. FocusBlox-Korpus ist bisher NICHT in diesem Schema — eigene `CorpusTask`-Form (siehe unten). |
| `Measurement/MeasurementRun.swift` | `MeasurementResult` (inkl. `runIndex`, aber ohne `importance`/`urgency`/`duration`/`energy`/`contexts`/`project` — nur `title`, `dueDate`, `dueHasTime`, `people`), `remaining(from:runsPerEntry:)`, `MeasurementProgress`. Für Selbstkonsistenz auf den weichen Feldern muss `MeasurementResult` um diese Felder erweitert werden. |
| `LooseEndsLab/MeasurementRunner.swift` | Ruft `FoundationModelsEnricher.enrich(_:)` auf und schreibt nur `title`/`dueDate`/`dueHasTime`/`people` in `MeasurementResult` — muss um die übrigen `Guess`-Felder erweitert werden, damit ihre Selbstkonsistenz überhaupt gemessen werden kann. |
| `LooseEndsLab/LabApp.swift` | Liest `--corpus` bereits aus (#107); `runsPerEntry` ist im Runner-Init ein Parameter mit Default 1, aber noch nicht aus den Kommandozeilenargumenten lesbar — DoD von #108 fordert dafür laut Fundament-Spec kein festes Flag mehr in diesem Schnitt, sondern erst hier. |
| `scripts/export-focusblox-corpus.swift` | Exportiert FocusBlox real in `CorpusTask` (id, rawText, title, contexts, importance, urgency, durationBucket, energy, dueDate als echtes Datum, capturedAt, completedAt, blockedBy, isCompleted, repeatRule) — ein anderes Schema als `Corpus.Entry`. Datei ist gitignored, real personenbezogen. |
| `LooseEndsTests/FocusBloxCalibrationTests.swift` | Bestehende Kalibrierung (#23): dekodiert den FocusBlox-Export direkt in ein eigenes lokales `CorpusTask` (Duplikat des Schemas aus dem Export-Skript, nicht `Corpus.Entry`), misst Precision/Recall der Modell-Konfidenz je Schwelle für `importance`/`urgency`/`duration`/`energy`. Läuft nur, wenn der Export lokal vorliegt (`.enabled(if:)`), nie in CI. Das Tabellenformat (Schwelle/Geschrieben/Precision/Recall) ist das Muster für die neue Trefferquote-über-Abdeckung-Tabelle. |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | Erzeugt `EnrichmentDraft.Guess<T>` mit `confidence` für `title`, `importance`, `urgency`, `duration`, `energy`, `contexts`, `people`, `project`. `dueDate` kommt seit #95 aus `DueDateRule`, nicht mehr vom Modell — für Selbstkonsistenz irrelevant. |
| `Shared/Enrichment/EnrichmentWriter.swift` | `confidenceThreshold = 0.6` — die Design-Entscheidung, die laut #108-Body von diesem Messergebnis abhängt (aber explizit **nicht** Teil dieses Schnitts). |
| `docs/reference/focusblox-calibration-report.md` | Bestehender Bericht im selben Themenfeld (Konfidenz-Kalibrierung, nicht Selbstkonsistenz) — Nachbar-Dokument für den neuen Bericht `docs/reference/uncertainty-signal-selfconsistency-report.md` (DoD). |
| `docs/project/06-annahmen-und-experimente.md` (Zeile 104) | Formale Definition von A1: Signal, Abbruchkriterium, Alternativen bei Abbruch. |
| `docs/specs/measurement/spike-65-mehrfachlauf-infrastruktur.md` | Fundament-Spec (Schnitt 1) mit explizitem Abschnitt „Nicht in diesem Schnitt", der die Scope-Liste für #108 vorgibt. |

## Existing Patterns

- **Wahrheit als Regel, nie als festes Datum** (`Corpus.DateExpectation`) — gilt nur für den
  synthetischen `date-title-corpus`. Der FocusBlox-Korpus hat echte, einmalige Werte
  (`importance`, `urgency` usw. aus tatsächlich abgeschlossenen Aufgaben), keine Regel — ein
  strukturell anderer Wahrheitsbegriff. Beide unter `Corpus.Entry` zu vereinheitlichen ist keine
  bloße Umbenennung, sondern eine Schema-Entscheidung für `/20-analyse`.
- **Precision/Recall-Tabelle je Schwelle** (`FocusBloxCalibrationTests.table(field:outcomes:)`) —
  bestehendes, funktionierendes Muster für „Kurve je Feld", nur mit Konfidenz-Schwelle statt
  Einstimmigkeits-Grad als Achse.
- **Reine, testbare Auswertungsfunktionen getrennt vom Messlauf** (`MeasurementProgress`,
  `MeasurementPacing`) — Selbstkonsistenz-Berechnung sollte denselben Zuschnitt bekommen: eine
  reine Funktion über `[MeasurementResult]` einer `entryID`, ohne Modellaufruf, damit sie ohne
  Gerät testbar ist ([[feedback-phone-is-not-a-test-bench]]).
- **Messcode kompiliert nur in `LooseEndsTests` und `LooseEndsLab`, nie in den Produktpfad**
  (`Measurement/`-Regel aus `CLAUDE.md`).

## Dependencies

- Upstream: `FoundationModelsEnricher.enrich(_:)`, `EnrichmentDraft.Guess<T>`, `Corpus.Entry`,
  `MeasurementResult`/`MeasurementRun` aus Schnitt 1, `scripts/export-focusblox-corpus.swift`
  (liefert die Rohdaten, läuft nur lokal bei Henning).
- Downstream: `docs/reference/uncertainty-signal-selfconsistency-report.md` (neu, DoD), die
  spätere Design-Entscheidung zu `EnrichmentWriter.confidenceThreshold` (ausdrücklich zurückgestellt),
  Folge-Issues für die Konsequenzen (DoD-Punkt aus #65).

## Existing Specs

- `docs/specs/measurement/spike-65-mehrfachlauf-infrastruktur.md` — Fundament, Schnitt 1.
- `docs/specs/measurement/issue-82-satzformen.md`, `docs/specs/measurement/feat-92-date-parser.md` —
  angrenzende Messstrecken-Specs, gleiche Verzeichniskonvention.

## Risks & Considerations

- **Schema-Bruch:** `Corpus.Entry.date` ist eine `DateExpectation`-Regel; der FocusBlox-Export hat
  ein echtes `dueDate`. Eine 1:1-Angleichung ist nicht möglich, ohne den Wahrheitsbegriff für einen
  der beiden Korpora zu verbiegen. Für Schnitt 2 zählt ohnehin nur `dueDate` nicht (das Feld kommt
  seit #95 aus `DueDateRule`, nicht mehr vom Modell) — die Analyse muss klären, ob `Corpus.Entry`
  nur die für Selbstkonsistenz relevanten Felder (Text + die bekannten Ist-Werte der weichen Felder)
  tragen muss, nicht das komplette FocusBlox-Schema.
- **`MeasurementResult` fehlen fünf Felder** (`importance`, `urgency`, `duration`, `energy`,
  `contexts`, `project` — nur `people` existiert schon), die für dieses Signal gebraucht werden.
  Das ist eine Erweiterung des Ergebnis-Typs, keine reine Auswertung obendrauf — zieht
  `MeasurementRunner.measure(_:runIndex:)` mit.
- **Reale, personenbezogene Daten:** Der FocusBlox-Export bleibt gitignored; jeder neue Test folgt
  dem `.enabled(if: FileManager...exists)`-Muster aus `FocusBloxCalibrationTests`, läuft nie in CI,
  und der Bericht selbst enthält nur aggregierte Zahlen (bestehende Konvention, unverändert
  fortzuführen).
- **Fünf Läufe je Satz bedeuten fünf Modellaufrufe** — Rate-Limit-Verhalten aus #83
  (`MeasurementPacing`) gilt unverändert; kein neuer Mechanismus nötig, aber die Laufzeit auf dem
  Gerät steigt in der Fläche (287 Sätze × 5 Läufe = 1435 Aufrufe statt 287).
- **Abgrenzung zum tatsächlichen Messlauf:** Laut #108-Body zählen weder der mehrtägige Lauf auf
  Hennings Gerät noch die `confidenceThreshold`-Entscheidung zu diesem Schnitt — dieser Schnitt
  liefert Code (Skript + reine Auswertung + Report-Generator), keine fertigen Messergebnisse.

## Analysis

### Type

Feature (Schnitt 2 eines mehrteiligen Spikes, #65/#108). Kein Bug.

### Zentraler Befund, der den Zuschnitt korrigiert

Der FocusBlox-Export (`scripts/export-focusblox-corpus.swift`, SQL-Query gegen `ZLOCALTASK`)
liefert **keine Wahrheit für `people` und `project`** — beide Spalten existieren in FocusBlox nicht
(SQL-Select hat keine entsprechende Spalte; `docs/project/02-datenmodell-und-ansichten.md` Zeile
202ff. nennt sie auch in der Mapping-Tabelle nicht). Der Kontext-Abschnitt oben listet beide Felder
noch unter den sieben zu messenden — das ist vor dem Lesen des Exports geschrieben und trifft nicht
mehr zu.

Ohne Wahrheit lässt sich keine Trefferquote bilden; A1s Abbruchkriterium (≥ 85 % Trefferquote bei
≥ 30 % Abdeckung) ist für `people`/`project` also grundsätzlich nicht prüfbar, egal wie hoch die
Selbstkonsistenz ausfällt. Für `people` kommt dazu, dass die Qualitätsfrage bereits am 2026-09-21
zurückgestellt wurde (#105, „kein bekannter Use Case, deshalb nicht gemessen"); `project` gilt in
derselben Analyse als „harmlos" (Stufe C, geringste Priorität).

**Empfehlung:** Schnitt 2 misst Selbstkonsistenz und Trefferquote-über-Abdeckung nur für die fünf
Felder mit echter Wahrheit im Export: `importance`, `urgency`, `duration`, `energy`, `contexts`.
`people` und `project` bleiben außen vor — nicht nur ungemessen, sondern bewusst nicht Teil von
`MeasurementResult` und `Corpus.Entry` in diesem Schnitt, weil ein Feld ohne Wahrheit im Korpus
keinen Wert für A1 liefert und nur Code trägt, den niemand auswerten kann.

**Alternative:** Selbstkonsistenz (reine Einstimmigkeit über die 5 Läufe, ohne Trefferquote) auch für
`people`/`project` mitschreiben, als beschreibende Zusatzzeile im Report, ausdrücklich ohne
Trefferquote-Spalte und ohne Anspruch auf A1-Tauglichkeit. Dagegen spricht: zusätzlicher Code
(`project` müsste neu in `EnrichmentDraft`/`MeasurementResult` sichtbar werden, `people` ist zwar
schon vorhanden aber ohne Wahrheit sinnlos zu gruppieren) für eine Zahl, die keine der beiden
Entscheidungen (Abbruchkriterium A1, Rückstellung #105) beeinflusst. Nur sinnvoll, falls Henning
unabhängig vom Abbruchkriterium wissen will, wie oft sich das Modell bei diesen beiden Feldern selbst
widerspricht — auf Nachfrage nachrüstbar, da `MeasurementResult.people` als Rohdaten weiterhin da ist.

### Technischer Ansatz

**1. FocusBlox-Export an `Corpus.Entry` angleichen (additiv, nicht umbenennend).**
`Corpus.Entry` bekommt fünf neue optionale Wahrheitsfelder (`importanceTruth`, `urgencyTruth`,
`durationTruth`, `energyTruth`, `contextsTruth: [String]?`) plus zwei neue Schlüssel, die der Export
zusätzlich schreibt: `lang` (fest `"de"`) und `text` (Duplikat von `rawText`) — beides fehlt in
`Corpus.Entry`s bestehendem Decoder sonst zum Laden. Der Export behält seine bisherigen Schlüssel
(`rawText`, `title`, `importance`, `urgency`, `durationBucket`, `energy`, `contexts`, …) unverändert
bei: rein additiv, keine vorhandene Datei bricht. Das erlaubt `Corpus.load(fileName:)` unverändert
auf der neu exportierten Datei zu laufen und **die komplette Schritt-1-Infrastruktur wiederzuverwenden**
(`remaining(from:runsPerEntry:)`, `MeasurementProgress`, `--corpus`-Flag, Pacing) — genau der Grund,
warum die Fundament-Spec „Export auf Corpus.Entry-Schema angleichen" als Schnitt-2-Aufgabe nennt.

*Alternative:* ein separater `FocusBloxCorpus`-Lade-Pfad neben `Corpus.load`, der die
FocusBlox-JSON in ihrer heutigen Form liest und intern auf `Corpus.Entry` abbildet, ohne die
Export-Datei zu ändern. Vermeidet die Erweiterung von `Corpus.Entry`, verdoppelt aber die
Lauf-Mechanik (eigene Zählung, eigenes Pacing oder eine zweite Kopie davon) und widerspricht damit
„baut auf dem Fundament auf". Verworfen.

Weil rein additiv, bleibt `FocusBloxCalibrationTests.swift` unverändert lauffähig — kein achtes File.

**2. `MeasurementResult` um die fünf Rohwerte erweitern**, analog zu `people` (bereits vorhanden):
`importance`, `urgency`, `duration`, `energy`: `String?`; `contexts: [String]`. Rückwärtskompatibel
über `decodeIfPresent` wie bei `runIndex` (#65) — alte Ergebnisdateien bleiben lesbar.
`MeasurementRunner.measure(_:runIndex:)` schreibt die Werte aus `draft` hinein (reines Durchreichen,
kein neuer Modellaufruf, keine Änderung an `FoundationModelsEnricher`).

**3. `runsPerEntry` aus der Kommandozeile lesbar machen**: neues Flag `--runs <n>` in `LabApp.swift`,
analog zu `--corpus`, Default bleibt `1` (Hennings eigene Kopie der Lab-App bleibt unverändert im
Verhalten). Wer beim eigentlichen Messlauf `--runs 5` setzt, entscheidet dieser Schnitt nur als
Mechanismus — der Lauf selbst ist explizit nicht Teil von #108.

**4. Neue reine Auswertungsfunktionen** (`Measurement/SelfConsistency.swift`, neue Datei): gruppiert
`[MeasurementResult]` nach `entryID`, bestimmt je Feld den Mehrheitswert und seinen Anteil an den
Läufen (die Einstimmigkeit, 0…1). Baut daraus die Trefferquote-über-Abdeckung-Tabelle im Format der
bestehenden `FocusBloxCalibrationTests.table(field:outcomes:)` — Spaltenüberschriften wechseln von
„Schwelle/Geschrieben/Precision/Recall" (Konfidenz-Schwelle) zu „Einstimmigkeit/Abdeckung/
Trefferquote" (kein Recall: ohne Konfidenzschwelle gibt es keine zwei unabhängigen Nenner, Abdeckung
allein macht die Kurve). Mengenfelder (`contexts`) zählen als eine Antwort: „Mehrheit" heißt hier
exakte Mengengleichheit über die 5 Läufe, „richtig" heißt exakte Mengengleichheit mit der
FocusBlox-Wahrheit. *Offene Frage an `/30-write-spec`:* ob exakte Mengengleichheit für `contexts` zu
streng ist (ein Kontext von zweien richtig zählt dann als falsch) — Empfehlung ist, bei der exakten
Gleichheit zu bleiben, weil sie ohne neue Metrik (Jaccard, F1) auskommt und mit derselben
Einstimmigkeits-Definition wie die Einzelwert-Felder rechnet; eine weichere Metrik ist bei Bedarf ein
Nachschlag, keine Blockade für diesen Schnitt.

**5. Report-Generator** als gated Test (`.enabled(if:)`, Muster wie `FocusBloxCalibrationTests`),
liest aber **keinen** Modellaufruf — anders als `FocusBloxCalibrationTests.calibrate()`. Er liest zwei
bereits vorhandene lokale Dateien (die FocusBlox-Wahrheit und eine bereits von Hennings Gerät
geholte `MeasurementRun`-Ergebnisdatei, Muster `sim.sh lab-fetch`), gruppiert, wertet aus, schreibt
`docs/reference/uncertainty-signal-selfconsistency-report.md`. Läuft nie in CI (Datei-Gate), aber
auch ohne Gerät und ohne Modell auf dem Mac — reine Nachverarbeitung zweier JSON-Dateien.

### Betroffene Dateien

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Measurement/Corpus.swift` | MODIFY | `Corpus.Entry` um `lang`/`text`-Duplikat und fünf optionale Wahrheitsfelder erweitern |
| `Measurement/MeasurementRun.swift` | MODIFY | `MeasurementResult` um `importance`/`urgency`/`duration`/`energy`/`contexts` erweitern, rückwärtskompatibel |
| `LooseEndsLab/MeasurementRunner.swift` | MODIFY | Neue Felder aus `draft` befüllen |
| `LooseEndsLab/LabApp.swift` | MODIFY | `--runs <n>`-Flag lesen, an `MeasurementRunner` durchreichen |
| `scripts/export-focusblox-corpus.swift` | MODIFY | `lang`/`text`/Wahrheitsfelder zusätzlich schreiben, additiv |
| `Measurement/SelfConsistency.swift` | CREATE | Reine Einstimmigkeits- und Tabellen-Funktionen |
| `LooseEndsTests/SelfConsistencyReportTests.swift` (Name vorläufig) | CREATE | Gated Report-Generator, kein Modellaufruf |

### Scope Assessment

- Dateien: 7 (über dem Standard-Richtwert von 4-5) — **bewusst nicht gesplittet**: die Teile sind
  einseitig abhängig (Schema-Erweiterung → Export-Änderung → Auswertung → Report), ein Split ließe
  eine Zwischen-PR mit totem Code zurück (Export schreibt Felder, die niemand liest, oder Auswertung
  ohne Datenquelle). Die Fundament-Spec (Schnitt 1) hat „Schritt 2" bereits als eine zusammenhängende
  Folge-Spec vorgesehen, kein Splitting-Kandidat.
- Geschätzte LoC: rund +260/-15 (`Corpus.swift` +25/-2, `MeasurementRun.swift` +25/-5,
  `MeasurementRunner.swift` +10/-2, `LabApp.swift` +8/-1, Export-Skript +10/-2,
  `SelfConsistency.swift` +90 neu, Report-Test +90 neu) — leicht über ±250 LoC, größtenteils neuer,
  isolierter Auswertungscode.
- Risiko: **Niedrig für das Produkt** — alle Änderungen bleiben in `Measurement/`, `LooseEndsLab/`,
  `LooseEndsTests/`, `scripts/` (kompiliert laut `CLAUDE.md` nie in den Produktpfad); jede Erweiterung
  ist additiv/rückwärtskompatibel (`decodeIfPresent`), `FoundationModelsEnricher` und
  `EnrichmentWriter` bleiben unangetastet. **Mittel für den Umfang** — sieben Dateien statt vier,
  weil ein neuer Signaltyp (Selbstkonsistenz statt Konfidenz) einen eigenen Auswertungs- und
  Report-Pfad braucht, der nicht aus Schritt 1 wiederverwendbar ist.

### Dependencies

Wie im Kontext-Abschnitt oben (`FoundationModelsEnricher.enrich(_:)` unverändert als reiner
Datenlieferant; `EnrichmentDraft.Guess<T>` unverändert; Schritt-1-Typen `Corpus.Entry`,
`MeasurementResult`, `MeasurementRun.remaining`, `MeasurementProgress` werden erweitert, nicht
ersetzt). Reihenfolge: Schema (`Corpus.swift`, `MeasurementRun.swift`) vor Export-Skript vor
Auswertung vor Report-Test — jeder Schritt baut auf dem vorigen auf.

### Open Questions

- [ ] Mengengleichheit für `contexts` als „richtig"/„einstimmig" — exakt (Empfehlung) oder mit
      Teilübereinstimmung? Für `/30-write-spec` zu entscheiden, falls Henning eine weichere Metrik
      will.
- [ ] Name des neuen Report-Test-Files — Vorschlag `SelfConsistencyReportTests.swift`, passend zum
      Zieldokument `uncertainty-signal-selfconsistency-report.md`.
