# Adversary-Dialog: #118 — importance/urgency aus den Measurement-Tests entfernen

Geprüft gegen `docs/specs/fast/fix-118-remove-importance-urgency-from-measurement-tests.md`
(AC-1 bis AC-3 plus den Abschnitt "Was sich nicht ändern darf").
Kontextisoliert: nur die Spec gelesen, alle Belege selbst über Versionsvergleiche, `grep`, `nm`
und einen eigenen Testlauf erbracht — keine Übernahme von Aussagen des Implementierers.

Stand: Änderungsstand `5129a65`, Arbeitsbaum sauber (nur unversioniertes `.claude/`).
Vergleichsbasis für alle Diffs: `d7ec2f5` (Stand vor dem Ticket) gegen `HEAD`.

## Eigener Testlauf (Beweisgrundlage)

```
./scripts/sim.sh generate   -> Created project at .../LooseEnds.xcodeproj
./scripts/sim.sh unit       -> Test Succeeded, exit code 0
```

Volle Ausgabe: `docs/artifacts/fix-118-remove-importance-urgency-from-measurement-tests/adversary-test-output.txt`
(122 Zeilen, 0 Fehlschläge, 0 `error:`; Abschluss `Test Succeeded` / `[sim] Unit-Tests bestanden.`).

Relevante Zeilen:
- `Suite MeasurementFieldScopeTests passed after 0.001 seconds` (die ungegatete Wächter-Suite aus #118)
- `Suite "ModelEnrichment ohne Wichtigkeit/Dringlichkeit (AC-7)" passed` (Produktseite #117 weiter grün)
- `Suite "Regelschritt: Wichtigkeit und Dringlichkeit" passed` (Regelweg #119 weiter grün)
- `FocusBloxCalibrationTests` und `SelfConsistencyReportTests` tauchen nicht auf -> korrekt übersprungen,
  weil `docs/reference/focusblox-corpus.json` und `docs/reference/selfconsistency-run.json` lokal fehlen
  (per `ls` verifiziert).

### Runde 1 — Erste Prüfung: erfüllt der Code die drei ACs buchstäblich?

- [x] **AC-1** `LooseEndsTests/FocusBloxCalibrationTests.swift` — vollständig gelesen (121 Zeilen).
  Keine `importanceOutcomes`/`urgencyOutcomes` (Zeilen 83-84 deklarieren nur `durationOutcomes`,
  `energyOutcomes`), keine Tabellenausgabe für die Felder (Zeilen 113/115: nur `duration`, `energy`),
  das harte `#expect(!importanceOutcomes.isEmpty, ...)` ist ersatzlos entfernt (Datei endet nach
  `report.write(...)`, Zeilen 117-118). Testname Zeile 59: "Precision/Recall je Schwelle für duration, energy".
  `grep -c "importance|urgency"` über die Datei -> **0**.
- [x] **AC-2** `LooseEndsTests/SelfConsistencyReportTests.swift:40-43` — `sections` enthält nur noch
  `duration` und `energy`, `contexts` wird Zeile 51 angehängt. Berichtstext Zeilen 56-57 auf
  "die drei Modellfelder" korrigiert (3 = duration, energy, contexts — stimmt rechnerisch).
  `grep -c "importance|urgency"` über die Datei -> **0**.
- [x] **AC-3** `Measurement/SelfConsistency.swift:12` — `// MARK: - Single-value fields (duration, energy)`.
  Der Diff d7ec2f5..HEAD über `Measurement/` meldet genau `1 file changed, 1 insertion(+), 1 deletion(-)`,
  also ausschließlich die Kommentarzeile; der Code ist unverändert.

Erster Eindruck: alle drei Punkte belegt. Das ist zu billig — ein reines Entfernen kann an drei
Stellen kippen: (a) es kompiliert nicht mehr, (b) es wurde mehr entfernt als bestellt,
(c) irgendwo blieb eine Rest-Referenz oder ein Seiteneffekt. Runde 2 sucht genau danach.

### Runde 2 — Gezielte Gegenprobe: Kompilat, Überschuss, Rest-Referenzen, Gating

1. **Wird die geänderte Datei überhaupt kompiliert, oder verschwindet sie hinter
   `#if canImport(FoundationModels)`?** Wäre `canImport` im Testziel falsch, bewiese der grüne Lauf
   für AC-1 gar nichts. Gegenprobe am Objektcode:
   `.../LooseEndsTests.build/Objects-normal/arm64/FocusBloxCalibrationTests.o` ist 208 808 Bytes groß,
   `nm | swift-demangle | grep -c calibrate` -> **57** Symbole. Die Datei wird also mit echtem Code
   übersetzt, nicht wegkompiliert. **Kein Defekt.**
2. **Kompiliert der `EnrichmentExample`-Aufruf ohne `importance:`/`urgency:` überhaupt?**
   `Shared/Enrichment/EnrichmentDraft.swift:51-59` deklariert beide weiterhin als optionale `var`,
   der memberwise-Init vergibt dafür den Default `nil`, und die Argumentreihenfolge am Aufrufort
   (`FocusBloxCalibrationTests.swift:73-79`) folgt der Deklarationsreihenfolge.
   Empirischer Beleg statt Theorie — das Objekt referenziert exakt:
   `U LooseEnds.EnrichmentExample.init(rawText:title:importance:urgency:duration:energy:contexts:)`.
   **Kein Defekt.**
3. **Wurde mehr entfernt als bestellt? Insbesondere Produktcode?**
   Der Diff d7ec2f5..HEAD (`--stat`) zeigt nur: die beiden Testdateien, die neue Wächter-Suite
   `MeasurementFieldScopeTests.swift`, die eine Kommentarzeile in `Measurement/SelfConsistency.swift`,
   zwei Artefakt-Textdateien und die Spec. **Kein `Shared/`-Pfad im Diff -> Produktcode unberührt.**
4. **Bleiben `Measurement/MeasurementRun.swift` und `Measurement/Corpus.swift` unverändert?**
   Der Diff d7ec2f5..HEAD über beide Dateien ist **leer**. `grep` bestätigt, dass `importance`
   und `urgency` dort weiterleben (`Corpus.swift:45,46,60`;
   `MeasurementRun.swift:35,36,44,58,59,68,88,89`) — genau wie die Spec es für den Rohdaten-Speicher
   verlangt. **Kein Defekt.**
5. **Rest-Referenzen außerhalb der genannten Zeilen?**
   Repo-weite Suche nach `CorpusTask|FocusBloxCalibration|SelfConsistencyReportTests|MeasurementFieldScope`
   in `*.swift`/`*.yml`/`*.sh`: nur ein Doc-Kommentar (`Measurement/SelfConsistency.swift:65`, nennt
   `FocusBloxCalibrationTests` als Kontrast — feldneutral, kein Handlungsbedarf) und der eigenständige
   `CorpusTask` im Export-Skript `scripts/export-focusblox-corpus.swift:38,196,210`. Letzteres ist
   der Rohdaten-Export, der die Felder laut Spec behalten darf. **Kein Defekt.**
6. **Bleibt das Gating unangetastet, läuft wirklich nichts in CI?**
   Gate-Zeilen `FocusBloxCalibrationTests.swift:23` und `SelfConsistencyReportTests.swift:21-22`
   sind im Diff nicht enthalten; der Dateistand aus d7ec2f5 zeigt denselben Wortlaut wie heute.
   `check-ignore` bestätigt `docs/reference/focusblox-corpus.json` als ignoriert (Ignorierdatei
   des Repos, Zeile 13), und die Dateiliste der Versionskontrolle für `docs/reference/` enthält
   keine Korpus-Datei. Beide Suiten hängen (auch) an dieser Datei, können in CI also nicht anlaufen.
   Die Ignorierdatei wurde vom Ticket nicht angefasst (Diff leer). **Kein Defekt.**
7. **Seiteneffekt des Testlaufs selbst?** Nach `./scripts/sim.sh unit` war
   `docs/reference/date-title-fidelity.md` verändert (Schreibnebenwirkung von `DateTitleReportTests`,
   vorbestehende Eigenheit, nicht aus #118). Zurückgesetzt, Arbeitsbaum wieder sauber.
   Kein Ticket-Defekt.

### Runde 3 — Wo könnte der Fix trotz grüner Lage schlechter sein als vorher?

8. **`calibrate()` hat jetzt keine einzige `#expect`-Zusicherung mehr** (nur noch das
   `try #require` auf Modellverfügbarkeit, Zeile 67). Vorher fing `#expect(!importanceOutcomes.isEmpty)`
   den Fall "Korpus liefert keine Wahrheitswerte" ab. Die Spec verlangt das Entfernen ausdrücklich und
   fordert keinen Ersatz — also keine Spec-Verletzung, aber ein echter Rückschritt der Aussagekraft
   -> **F001 (MEDIUM)**.
9. **Die Beispielauswahl für den Few-Shot-Prompt hat sich geändert**, nicht nur die Auswertung:
   Filter von `$0.importance != nil` auf `$0.durationBucket != nil` (Zeile 70), und die Beispiele
   tragen importance/urgency nun implizit als `nil`. Das verändert die Eingabe des Modells und damit
   die gemessenen duration/energy-Zahlen — über den Spec-Wortlaut hinaus -> **F002 (LOW)**.
10. **Der abgelegte Bericht `docs/reference/focusblox-calibration-report.md` zeigt weiterhin
    importance- und urgency-Tabellen** (Zeilen 5 und 17). AC-1 sagt "Bericht und Test decken nur noch
    duration/energy ab"; der Code erfüllt das, das abgelegte Artefakt widerspricht ihm aber noch.
    Neu erzeugen geht nur lokal mit dem personenbezogenen Korpus -> **F003 (LOW)**.
11. **Die Wächter-Suite ist eine reine Quelltext-Suche** (`MeasurementFieldScopeTests.swift:21-22,28-29`
    prüft die Literale `importanceOutcomes`, `urgencyOutcomes`, `field: "importance"`,
    `field: "urgency"`). Eine Rückkehr unter anderem Variablennamen bliebe unbemerkt, und AC-3
    (der MARK-Kommentar) ist gar nicht abgesichert -> **F004 (LOW)**.


## Strukturierte Befunde

Finding:
  ID: F001
  Severity: MEDIUM
  Category: anti_pattern
  Code reference: LooseEndsTests/FocusBloxCalibrationTests.swift:60
  Description: calibrate() (Zeilen 60-118) enthaelt nach der Aenderung keine einzige
    #expect-Zusicherung mehr; nur das try #require auf enricher.unavailableReason (Zeile 67) blieb.
    Der Test kann jetzt einen Bericht mit zwei leeren Tabellen schreiben und trotzdem gruen sein.
  Spec requirement: AC-1 — importance/urgency-Auswertung inkl. des harten
    #expect(!importanceOutcomes.isEmpty, ...) entfernen; Bericht und Test decken nur noch
    duration/energy ab.
  Conflict: Keine Verletzung des Buchstabens (die Spec verlangt das Entfernen und keinen Ersatz),
    aber der Sanity-Check fuer "der Korpus enthaelt ueberhaupt Wahrheitswerte" ist ersatzlos weg.
  Remediation: #expect(!durationOutcomes.isEmpty, "corpus must have at least one task with known
    durationBucket") ergaenzen — gleiche Schutzwirkung auf dem verbliebenen Leitfeld.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/FocusBloxCalibrationTests.swift:70
  Description: Der Few-Shot-Beispielfilter wechselte in Zeile 70 von $0.importance != nil auf
    $0.durationBucket != nil, und die in den Zeilen 73-79 gebauten EnrichmentExample tragen
    importance/urgency nun implizit als nil. Damit waehlt der Test andere fuenf Beispiele aus und
    schickt einen anderen Prompt an das Modell als vorher.
  Spec requirement: AC-1 — entfernt werden sollen Sammlung, Tabellenausgabe und das harte #expect.
  Conflict: Die Aenderung geht ueber den Spec-Wortlaut hinaus und veraendert die Messmethodik; neue
    duration/energy-Zahlen sind mit dem alten abgelegten Bericht nicht vergleichbar.
  Remediation: Bewusst so lassen (Folge des Wegfalls der Felder aus CorpusTask), aber im Bericht-Kopf
    vermerken, dass die Beispielbasis ab #118 eine andere ist.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: docs/reference/focusblox-calibration-report.md:5
  Description: Der abgelegte Kalibrierungsbericht enthaelt weiterhin die Abschnitte
    "importance (59 Aufgaben mit bekanntem Wert)" (Zeile 5) und "urgency ..." (Zeile 17).
  Spec requirement: AC-1 — "Bericht und Test decken nur noch duration/energy ab."
  Conflict: Der Code erzeugt nur noch duration/energy, das abgelegte Artefakt dokumentiert aber
    weiter zwei Felder, die das Produkt seit #117 nicht mehr vom Modell holt.
  Remediation: Beim naechsten lokalen Lauf mit vorhandenem Korpus neu erzeugen; bis dahin eine
    Kopfzeile "Stand vor #118, importance/urgency historisch" ergaenzen.

Finding:
  ID: F004
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsTests/MeasurementFieldScopeTests.swift:21
  Description: Die Waechter-Suite prueft nur vier Zeichenketten im Quelltext (Zeilen 21-22 und
    28-29: importanceOutcomes, urgencyOutcomes, field "importance", field "urgency"). Eine
    Rueckkehr der Auswertung unter anderem Variablennamen bliebe unentdeckt; der MARK-Kommentar aus
    AC-3 ist gar nicht abgesichert.
  Spec requirement: AC-1/AC-2/AC-3 — Schutz gegen das stille Zurueckkehren der Felder.
  Conflict: Der Schutz ist schmaler als die ACs breit sind; AC-3 hat keinen Test.
  Remediation: Zusaetzlich auf die Woerter "importance"/"urgency" in beiden Dateien pruefen
    (beide stehen aktuell bei 0 Treffern) statt nur auf einzelne Bezeichner.

## Bestaetigungen

Confirmation:
  AC: AC-1
  Code reference: LooseEndsTests/FocusBloxCalibrationTests.swift:59
  Evidence: Testname Zeile 59 nur noch "duration, energy"; nur durationOutcomes/energyOutcomes
    deklariert (83-84) und befuellt (102-103); Report-String (113, 115) enthaelt nur die zwei
    Tabellen; das harte #expect(!importanceOutcomes.isEmpty, ...) ist weg (Datei endet 117-118).
    grep nach importance/urgency ueber die Datei: 0 Treffer. Datei wird nachweislich uebersetzt
    (FocusBloxCalibrationTests.o, 208 808 Bytes, 57 demangelte calibrate-Symbole).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsTests/SelfConsistencyReportTests.swift:40
  Evidence: sections (40-43) enthaelt nur duration und energy, contexts wird Zeile 51 angehaengt;
    keine Zeile mit field "importance" oder field "urgency"; Berichtstext (56-57) von "fuenf
    Felder" auf "drei Modellfelder" korrigiert, was zu den drei Abschnitten passt. grep ueber die
    Datei: 0 Treffer.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Measurement/SelfConsistency.swift:12
  Evidence: Zeile 12 lautet "// MARK: - Single-value fields (duration, energy)". Der Diff
    d7ec2f5..HEAD ueber Measurement/ meldet exakt 1 file changed, 1 insertion(+), 1 deletion(-) —
    es wurde nur der Kommentar geaendert, kein Code.
  Status: CONFIRMED

Confirmation:
  AC: NC-1 (Was sich nicht aendern darf) — MeasurementRun.swift und Corpus.swift unveraendert
  Code reference: Measurement/MeasurementRun.swift:35
  Evidence: Der Diff d7ec2f5..HEAD ueber beide Dateien ist leer; die Felder importance/urgency
    existieren dort unveraendert weiter (MeasurementRun.swift 35-36, 68, 88-89; Corpus.swift 45-46,
    60) — Rohdaten-Speicher, analog dueDate nach #95.
  Status: CONFIRMED

Confirmation:
  AC: NC-1b (Was sich nicht aendern darf) — Corpus.swift unveraendert
  Code reference: Measurement/Corpus.swift:45
  Evidence: Zeilen 45-46 und 60 tragen importanceTruth/urgencyTruth unveraendert; der Diff
    d7ec2f5..HEAD ueber diese Datei ist leer.
  Status: CONFIRMED

Confirmation:
  AC: NC-2 (Was sich nicht aendern darf) — kein Eingriff in Shared/Enrichment
  Code reference: Shared/Enrichment/EnrichmentDraft.swift:51
  Evidence: Der Diff d7ec2f5..HEAD (--stat) listet keinen Pfad unter Shared/; EnrichmentExample
    (51-59) traegt importance/urgency unveraendert, und das Objektsymbol des Tests referenziert
    weiterhin den vollstaendigen memberwise-Init. Produktsuiten "ModelEnrichment ohne
    Wichtigkeit/Dringlichkeit (AC-7)" und "Regelschritt: Wichtigkeit und Dringlichkeit" sind gruen.
  Status: CONFIRMED

Confirmation:
  AC: NC-3 (Was sich nicht aendern darf) — Suiten bleiben gegated und laufen nie in CI
  Code reference: LooseEndsTests/SelfConsistencyReportTests.swift:21
  Evidence: Gate-Zeilen 21-22 sind identisch zum Stand vor dem Ticket, ebenso
    FocusBloxCalibrationTests.swift:23; die Ignorierdatei des Repos wurde vom Ticket nicht
    angefasst; check-ignore bestaetigt docs/reference/focusblox-corpus.json als ignoriert
    (Zeile 13); die Dateiliste der Versionskontrolle fuer docs/reference/ enthaelt keine
    Korpus-Datei. Im eigenen Lauf erscheinen beide Suiten nicht in der Ausgabe — korrekt
    uebersprungen.
  Status: CONFIRMED

## Verdict

VERDICT: VERIFIED

- AC-1: PROVEN — Code, grep und Objektcode belegen es; F001/F002 sind Qualitaetsanmerkungen, keine
  Verletzung des Spec-Wortlauts.
- AC-2: PROVEN — sections und Berichtstext stimmen, 0 Treffer im grep.
- AC-3: PROVEN — genau eine geaenderte Kommentarzeile, Code unveraendert.
- Nicht-aendern-Liste: alle drei Punkte bestaetigt (Measurement-Rohdaten unveraendert, kein
  Produktcode, Gating unangetastet).
- Tests: eigener Lauf ./scripts/sim.sh unit -> Test Succeeded, exit 0, 0 Fehlschlaege; die
  Waechter-Suite MeasurementFieldScopeTests laeuft und ist gruen; beide gegateten Suiten
  uebersprungen.
- Offene, nicht blockierende Befunde: F001 (MEDIUM, fehlende Zusicherung), F002/F003/F004 (LOW).

## Geprüfte Dateien

- sha256:05a94f69aa123e16add92386c4d3b1e246d3c74920c2c8136733890762ce6266  LooseEndsTests/FocusBloxCalibrationTests.swift
- sha256:281367ba8016dd50d73d9891f6325d21b93d48d51e78a2febee4192570f07509  LooseEndsTests/MeasurementFieldScopeTests.swift
- sha256:fcc2374acde1da4f43492250dc7964d6a5e918b493af2b55b03d0fade8b84224  LooseEndsTests/SelfConsistencyReportTests.swift
- sha256:a15049b32ecdde31e5aa1385f13651ca3a91499294c8f9dd91189311c640eb61  Measurement/Corpus.swift
- sha256:1b510371a8dfa55ebcaa4f3dbaa930c6dbfdca1183deb3700d50a7e69932887a  Measurement/MeasurementRun.swift
- sha256:f59502ce488c968fa5182acf9dff8e4e59e0b412770e15e0897b2a386222c16a  Measurement/SelfConsistency.swift
- sha256:9128c974e1b1951eb981d21afe8d2c2bd29e0161638c9f0b08ce23f54424e5d9  Shared/Enrichment/EnrichmentDraft.swift
- sha256:a9bf0f28624de000889184a7c13b843aea72b0ff7ce4cf279eff2ee445429ccd  docs/reference/focusblox-calibration-report.md
