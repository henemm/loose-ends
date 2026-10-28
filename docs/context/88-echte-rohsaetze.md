# Context: 88-echte-rohsaetze

## Request Summary
#88 Teil 2: Hennings echte Loose-Ends-Rohsätze werden als zweite Messquelle ausgewiesen, getrennt vom
FocusBlox-Korpus. Der Teil ohne Gerät wird vorbereitet (Einlesen einer lokalen Datei, regelbasierte
Wahrheit, Ergänzungsformat, getrennter Berichtsabschnitt). Holen der Erfassungen und Laborlauf erst nach
Hennings wörtlichem „jetzt ist ein Test möglich“.

## Stand vor dieser Arbeit
- Teil 1 fertig (Gewichtung nach Hennings Verteilung, Regel-Spalte neben dem Modell): `LooseEndsTests/DateTitleReportTests.swift`, Bericht `docs/reference/date-title-fidelity.md`.
- Textform-Spalte samt Adapter fertig (PR #694, Commit 3103dc9): `Measurement/TextFormColumn.swift`, `Corpus.textFormEntries`, Auswertung `TextFormModelReportTests`, Gate `textform-run.json` in `scripts/measurement_status.py`.
- Offene Kästchen im Ticket: Erfassungen lokal holen (nie einchecken), Wahrheit je Satz, getrennter Berichtsteil, derselbe Gerätedurchgang wie #71.

## Related Files
| File | Relevance |
|------|-----------|
| `Measurement/Corpus.swift` | `Corpus.Entry`, `load(fileName:)` (JSON-Liste oder Textform-Objekt), `url(fileName:)` (Bundle oder Datei neben der Quelle), `Weights` mit Quelle „Angabe Henning aus 108 FocusBlox-Rohsätzen“ |
| `Measurement/TextFormColumn.swift` | Muster für eine rein zählende Auswertung ohne `import LooseEnds`; `carriesAll` (Schlüsselwörter im Titel) wiederverwendbar |
| `Measurement/MeasurementRun.swift` | `MeasurementResult` (Titel, Dauer, Fehler je Note), Läufer der Labor-App; `--corpus <name>`, `--runs <n>` |
| `LooseEndsTests/DateTitleReportTests.swift` | Berichtsaufbau nach Bauform und gewichtet; Vorbild für den getrennten Abschnitt |
| `LooseEndsTests/MeasurementData.swift` | Suche der gitignorierten Dateien (Arbeitsstand, dann Hauptordner) |
| `scripts/measurement_status.py` + `test_measurement_status.py` | `GATES`: Suite → Datei; Liste muss mit den Gattern im Swift-Code übereinstimmen |
| `scripts/export-focusblox-corpus.swift` | Vorbild für einen lokalen, schreibgeschützten Export aus einem SwiftData-Store; Ausgabe gitignoriert |
| `.gitignore` | Zeile 13 `docs/reference/focusblox-corpus.json` — eine neue Datei mit echten Rohsätzen muss hier ebenfalls stehen |
| `docs/project/00-entscheidungen.md` | R4-4: Rohtexte als Messkorpus ja, lokal auf dem Mac, nie im Repository |
| `docs/reference/textform-rules.md` | Aufruf und Lesart der Textform-Spalte |

## Existing Patterns
- Echte persönliche Daten: gitignorierte JSON-Datei in `docs/reference/`; fehlt sie, wird die Messsuite laut übersprungen und `measurement_status.py` meldet es.
- Auswertungen sind reine Zählung über bereits gemessene Ergebnisse, die Regel (`TitleRule`) wird als Closure hereingereicht, weil sie nicht in der Labor-App liegt.
- Leere Gruppe zeigt „–“, nie eine Zahl; Gewichte tragen immer ihre Quelle.
- Regelspalte steht in jeder Zeile neben dem Modell (Regeln vor Modell).

## Dependencies
- Upstream: `RawTextWords`, `TitleRule`, `SelfConsistency.majority`, `Corpus`.
- Downstream: Laborlauf #88/#71 (ein gemeinsames „jetzt ist ein Test möglich“), Bericht `docs/reference/date-title-fidelity.md`.

## Offene Fragen für die Analyse
1. **Woher kommen die Rohsätze?** Die Labor-App läuft unter eigener Kennung mit eigener App-Gruppe (#156) und sieht Hennings Store nicht. Ein Export aus seinem Mac-Store (Datei lesen) oder von seinem iPhone ist ein Zugriff auf sein Gerät und braucht sein Wort. Vorbereitbar ist nur das Einlesen einer fertigen lokalen Datei.
2. **Wie kommen sie in den Läufer?** Wie der Textform-Korpus über `Corpus.load`/`--corpus`; die Datei müsste ins Lab-Bundle, ohne im Repo zu liegen (gitignoriert, beim Bau eingebunden).
3. **Wahrheit je Satz:** regelbasiert, soweit möglich (Schlüsselwörter aus Substantiven? Titel-Regel als Maßstab ist zirkulär — `TitleRule` kann nicht zugleich Wahrheit und Prüfling sein). Hier liegt der eigentliche Entwurf.
4. **Zählfehler vermeiden:** Dubletten (43× „LinkedIn Nachrichten beantworten“ im FocusBlox-Korpus, Memory „Korpus-Textdubletten“) auch in den Loose-Ends-Erfassungen erwartbar.

## Alternativen (Henning: in Alternativen denken)
- **Ohne neue Datei:** Nur den Bericht um einen Abschnitt „echte Rohsätze: nicht gemessen, weil …“ erweitern. Billig, belegt aber nichts.
- **Gerätelos über den Simulator:** eigene Beispielsätze im Stil seiner Verteilung. Verworfen: das wäre wieder ein erfundener Korpus, nicht seine Sätze.

## Risks & Considerations
- Echte persönliche Texte dürfen nie in Repo, Artefakte, Issue-Kommentare oder Berichte im Klartext (nur Zählungen).
- Scoping: 4–5 Dateien, ±250 LoC; Messcode berührt keinen Pfad der Geräteliste.
- Kein Zugriff auf Hennings Geräte oder deren Daten vor seinem Wort.

## Analysis

### Type
Feature (Messwerkzeug, kein Produktpfad).

### Befund
- **Wahrheit liegt schon im Store, ohne Regel:** Jede Nutzerkorrektur an Titel oder Dauer ist eine `Revision` mit `author == .user` (`oldValue`/`newValue`). Wo Henning korrigiert hat, ist `newValue` die Wahrheit, der `oldValue` das, was Regel/Modell geliefert hat. Nicht zirkulär, weil `TitleRule` nicht Maßstab ist.
- **Drei Wahrheitsstufen je Satz:** (1) vom Nutzer korrigiert = Wahrheit; (2) nicht korrigiert = *kein* Beleg („nicht beanstandet“ ist keine Wahrheit, wird als eigene Gruppe ausgewiesen, nie als richtig gezählt); (3) Titel ohne Revision, aber Schlüsselwörter prüfbar (`carriesAll`) = Rückfall für Titel-Treue wie im Textform-Korpus. Dauer: nur Stufe 1.
- **Das Laufzeit-Format existiert:** `Corpus.load`/`--corpus` liest JSON-Listen und das Textform-Objekt; ein dritter Adapter ist der kleinste Schnitt. Datei gitignoriert wie `focusblox-corpus.json`; Gate in `measurement_status.py`.
- **Holen der Sätze ist Gerätezugriff:** Die Labor-App sieht Hennings Store nicht (eigene Kennung, eigener Container, #156). Der Mac-Store von Loose Ends (App-Gruppe) enthält dieselben Daten per CloudKit; ihn zu lesen ist Zugriff auf sein Gerät → nur nach „jetzt ist ein Test möglich“.
- **Dubletten:** vor dem Zählen nach `RawTextWords`-Gleichheit entduplizieren (Memory „Korpus-Textdubletten“), sonst zählt ein Satz 40-fach.
- **Datenschutz:** Berichte, Artefakte, Issue-Kommentare tragen nur Zählungen, nie Sätze.

### Ohne Modell geht es nicht, weil …
Die Messung gilt dem Modell selbst (Titel-Verfeinerung, Dauer); die Regel-Spalte (`TitleRule`) steht in jeder Zeile daneben. Für die Wahrheit selbst wird kein Modell gebraucht (Revisionen, Schlüsselwörter).

### Alternativen
- **A (empfohlen): Export aus dem Mac-Store, lokal, gitignoriert** — ein schreibgeschütztes Swift-Skript nach Vorbild `export-focusblox-corpus.swift`. Kippt keine ADR.
- **B: Export-Knopf in der App** (Datei teilen). Produktfunktion nur für die Messung, Datenschutztext (#705) müsste mit; verworfen.
- **C: nur Bericht „nicht gemessen, weil …“**. Billig, belegt nichts.
- **D: CloudKit direkt lesen** (cktool). Privates DB-Schema, nicht mit Management-Token zugänglich; verworfen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/RawSentenceColumn.swift` | CREATE | Adapter für `loose-ends-rawtexts.json`, Wahrheitsstufen, reine Zählung |
| `Measurement/Corpus.swift` | MODIFY | `load` erkennt das dritte Format |
| `LooseEndsTests/RawSentenceReportTests.swift` | CREATE | Auswertung als eigener Berichtsabschnitt + Tests mit Kunstdaten |
| `scripts/measurement_status.py` (+ Test) | MODIFY | Gate `loose-ends-rawtexts.json` |
| `.gitignore` | MODIFY | neue Datei ausschließen |
| `scripts/export-loose-ends-rawtexts.swift` | CREATE | Schnitt B: Export (erst nach Hennings Wort) |

### Scope Assessment
- **Schnitt A (ohne Gerät):** Adapter, Wahrheitsstufen, Bericht, Gate, gitignore, Tests mit Kunstdaten — 5 Dateien, ca. +230 LoC. Abnahme: Unit-Tests + Simulator-Beleg.
- **Schnitt B (Export + Lauf):** Skript (ca. +90 LoC), 1 Datei; braucht Hennings Wort, derselbe Durchgang wie #71.
- Risk Level: LOW (nur `Measurement/`, Tests, Skripte; kein Pfad der Geräteliste).

### Technical Approach
Schnitt A zuerst als eigene Spec; Schnitt B danach als zweiter Workflow. Format der Datei: je Satz `rawText`, `titleBefore`, `titleUser?`, `durationUser?`, `capturedAt`; keine Ids der App.

### Dependencies
`RawTextWords`, `TitleRule` (als Closure), `TextFormColumn.carriesAll`, `Corpus.load`, `MeasurementData` (Dateisuche).

### Open Questions
- [ ] Datei-/Feldnamen sind Entwurf, in der Spec festzulegen.
- [ ] Mindestmenge: unter welcher Zahl korrigierter Sätze der Bericht „zu wenig“ sagt statt eine Rate (Vorschlag: 30), in der Spec.
