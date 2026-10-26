# Context: feat-88-textform-spalte

## Request Summary
#88 Teil 2, vorab ohne Gerät: Der Laborlauf bekommt die Spalte „Titel und Dauer je Textform“ (Kommentar von
#70, Entscheidung Henning 2026-10-25, Variante A). Gebaut werden Adapter und Auswertung; der Lauf auf dem
iPhone selbst bleibt aus, bis Henning „jetzt ist ein Test möglich“ schreibt.

## Related Files
| File | Relevance |
|------|-----------|
| `Measurement/textform-corpus.json` | 40 Inhalte × Formen `typed`, `dictated`, `mail`, `english`; `truth.titleWords`, `dictatedNumbers`; **kein** Format `Corpus.Entry`, keine Dauer-Wahrheit |
| `Measurement/Corpus.swift` | `Corpus.load(fileName:)` dekodiert fest `[Entry]`; `--corpus <name>`, `--runs <n>`, `--result <name>` kommen schon aus den Startargumenten |
| `LooseEndsLab/MeasurementRunner.swift` | Lädt über `Corpus.load`, ruft je `Entry` den Veredeler, schreibt `MeasurementResult` (Titel, Dauer, Kontexte …) in die Ergebnisdatei; `--runs` wiederholt jeden Satz |
| `Measurement/MeasurementRun.swift` | `MeasurementResult` (`entryID`, `title`, `duration`, `runIndex`), `MeasurementStore.coder` |
| `Measurement/SelfConsistency.swift` | reine Zählung: `majority`, `agreement` (Einstimmigkeit über Läufe), keine Abhängigkeit zu `Corpus.Entry` |
| `LooseEndsTests/TextFormRuleReportTests.swift` | Regelspalte (#70): privater `TextFormCorpus`-Decoder, `Measurer`, `cutMail`, Titel-Abdeckung je Form; Bericht nach stdout |
| `LooseEndsTests/SelfConsistencyReportTests.swift` | Muster für einen Bericht aus einer Geräte-Ergebnisdatei, gesperrt über `MeasurementData` (Datei fehlt → Suite übersprungen, #149) |
| `LooseEndsTests/MeasurementData.swift` | Pfade zu lokalen, nicht eingecheckten Messdateien |
| `docs/reference/textform-rules.md` | Regelspalte und Entscheidung je Kanal; Hinweis „Modellspalte fehlt noch“ |
| `project.yml` (LooseEndsLab, LooseEndsTests) | `Measurement/` ist Quelle beider Ziele; die JSON wird als Ressource mitgenommen |
| `scripts/sim.sh` (`lab`, `lab-run`, `lab-fetch`) | Gerätewege, laufen nur auf Hennings Wort |

## Existing Patterns
- Reine Zählung in `Measurement/`, Berichte als Tests, die aus lokalen Dateien lesen und bei fehlender Datei **laut übersprungen** werden (#149).
- Korpusauswahl im Lab per Startargument; kein Produktpfad, keine App-Gruppe, kein CloudKit.
- Regel-Spalte steht in jedem Bericht neben dem Modell (CLAUDE.md „Die Nulllinie zählt“): `TitleRule` 100 % Schlüsselwörter in allen Formen.

## Dependencies
- Upstream: `Corpus.Entry` (id, lang, text), `RawTextWords`, `TitleRule`, `SelfConsistency`.
- Downstream: Lab-App (liest den Korpus nur über `Corpus.load`); `date-title`-Lauf und `latency`-Lauf dürfen sich nicht ändern.

## Existing Specs
- Keine Spec zu #88 Teil 2. Ticket #88 (Teil 1 gemergt, PR #665), Kommentar der #70-Analyse vom 2026-10-25.

## Analyse (Summe 2, in diesem Durchgang)
**Befund:** Der Läufer ist schon so gebaut, dass jede Korpusdatei im Format `[Corpus.Entry]` mit `--runs n` mehrfach gemessen wird. Es fehlt nur ein Adapter, der aus `textform-corpus.json` eine Liste von Notizen macht (Kennung `tf-01.typed`, `tf-01.dictated`, `tf-01.english`, Sprache aus der Form), und eine Auswertung, die die Ergebnisdatei nach Inhalt und Form aufschlüsselt.

**Auswertung je Form (kein Modellaufruf im Test):**
- Dauer: keine Wahrheit im Korpus → Selbstkonsistenz zwischen den Formen desselben Inhalts (Mehrheit der Formen = Referenz, Anteil der Inhalte mit gleicher Dauer wie `typed`).
- Titel: Schlüsselwörter des Modelltitels gegen `truth.titleWords`, daneben die Regelspalte (`TitleRule`) als Nulllinie.
- Mail-Körper bleibt draußen (das Produkt reicht nur den Betreff weiter); die Formen sind `typed`, `dictated`, `english`.

**Alternative:** Nichts vorab bauen, bis der Laborlauf freigegeben ist (der Adapter würde dann in einem eigenen Durchgang entstehen). Gekippt würde keine ADR. Gewählt ist das Vorabbauen, damit der Geräte-Durchgang später alles auf einmal misst.

## Risks & Considerations
- `Corpus.load` darf für bestehende Korpusse (`date-title-corpus`, `latency-corpus`, FocusBlox) nichts ändern: Formaterkennung nur für den Textform-Korpus, und das mit einem Test.
- Der Mess-Code ist in `LooseEndsLab` mit eigenen Quellen verdrahtet: neue Datei in `Measurement/` kommt automatisch in Lab, Tests und UI-Tests; sie darf kein `import LooseEnds` brauchen.
- Datumsfelder sind für diese Spalte unerheblich (die Datumsregel läuft ohne Modell); der Läufer misst „heute 9 Uhr“, der Textform-Korpus hat den Referenztag 2026-10-07.
- Die Dauer-Auswertung hat keine Wahrheit; der Bericht sagt das laut statt eine Trefferquote zu zeigen.
- Stufe 3: `Measurement/` und `LooseEndsLab/` stehen nicht auf der Geräteliste; der Lauf selbst braucht Hennings Wort.

## Analysis

### Type
Feature (Messwerkzeug, kein Produktpfad)

### Befund (am Code geprüft, 2026-10-26)
- `Corpus.load` (`Measurement/Corpus.swift`) dekodiert fest `[Entry]`; `textform-corpus.json` ist ein Objekt (`reference`, `timeZone`, `entries[]` mit `forms{typed,dictated,mail,english}`, `truth`). Mit `--corpus textform-corpus` würde der Läufer heute leer starten (`try?` → `[]`, „Korpus: 0 Sätze“).
- Der Läufer (`MeasurementRunner`) braucht nur `id`, `lang`, `text` je Satz; `--runs n` und `--result` sind schon da.
- Ohne Modell geht es hier nicht, weil die Spalte genau das Modell messen soll (Selbstkonsistenz des Modells über Textformen); die Regel-Spalte (`TitleRule`, 100 %) steht als Nulllinie daneben.

### Affected Files
| File | Change | Description |
|------|--------|-------------|
| `Measurement/Corpus.swift` | MODIFY | `load` erkennt das Objektformat (Schlüssel `entries`/`forms`) und liefert `Entry` je Inhalt × Form (`typed`, `dictated`, `english`; Kennung `tf-01.typed`, Sprache de/en aus der Form); bisherige Korpusse unverändert |
| `Measurement/TextFormColumn.swift` | CREATE | reine Auswertung: je Form Titel-Schlüsselwörter (Modell vs. `TitleRule`) und Dauer-Übereinstimmung mit `typed` (Mehrheit über Läufe via `SelfConsistency`) |
| `LooseEndsTests/TextFormColumnTests.swift` | CREATE | Unit-Tests: Adapter (Anzahl 120, Kennungen, Sprache, Mail draußen, alte Korpusse gleich), Auswertung mit synthetischen Ergebnissen |
| `LooseEndsTests/TextFormModelReportTests.swift` | CREATE | Bericht aus lokaler Ergebnisdatei, laut übersprungen wenn sie fehlt (#149), Muster `SelfConsistencyReportTests` |
| `docs/reference/textform-rules.md` | MODIFY | Hinweis „Modellspalte fehlt noch“ → Aufruf und Lesart |

### Scope Assessment
- Files: 5, LoC: ca. +200/−5, Risk: LOW (nur Messcode, kein Produktpfad, Lab/Tests)

### Technical Approach
Adapter in `Corpus.load` (Formaterkennung am Dateiinhalt, nicht am Namen), Auswertung als reine Funktion auf `[MeasurementResult]`, Bericht als gesperrter Test. Dauer-Spalte sagt laut, dass es keine Wahrheit gibt (nur Übereinstimmung zwischen Formen). Mail-Körper bleibt draußen.

### Alternativen
- A: Nichts vorab bauen, Adapter erst im Geräte-Durchgang (gekippt: keine ADR; Nachteil: Henning wartet danach nochmal).
- B: Eigene Lab-Eingabe statt `Corpus.load`-Erweiterung (mehr Code im Läufer, der bisher unverändert bleibt) — verworfen.
- C: JSON in das `Entry`-Format umschreiben (dann zwei Quellen für `TextFormRuleReportTests`) — verworfen.

### Dependencies
`Corpus.Entry`, `RawTextWords`, `TitleRule`, `SelfConsistency`, `MeasurementResult`; `date-title`- und `latency`-Läufe dürfen sich nicht ändern.

### Open Questions
- keine für Henning; der Geräte-Lauf selbst bleibt aus, bis er „jetzt ist ein Test möglich“ schreibt.
