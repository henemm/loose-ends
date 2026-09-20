# Context: issue-82-satzformen

## Request Summary
Der Messkorpus für #67 (203 Sätze) ist im Satzbau einförmig: Zeitangabe, Objekt, Verb. Hennings
108 echte FocusBlox-Rohsätze sind anders gebaut (34 % Stichwörter ≤ 3 Wörter, Fragen an sich
selbst, Schlüsselwort-Präfixe, Diktatfehler in Namen, nur 12 % mit Zeitangabe). Der Korpus bekommt
je Satz eine Bauform, mindestens 100 neue Sätze in seinen Formen, und der Bericht trennt die
Trefferquote nach Bauform. Zweiter Schnitt (eigener PR): seine Rohsätze als lokaler Korpusteil mit
seiner Wahrheit.

## Related Files
| File | Relevance |
|------|-----------|
| `Measurement/date-title-corpus.json` | Der Korpus, eine Zeile je Satz, Wahrheit als Regel (`offsetDays`, `weekday`, …) |
| `Measurement/Corpus.swift` | `Corpus.Entry` (Decodable, optionale Felder über private `*List`), `DateExpectation`, `TitleCheck` |
| `LooseEndsTests/DateTitleReportTests.swift` | Auswertung auf dem Mac, `Report` mit `byRule`/`byCondition`, Markdown-Abschnitte, schreibt `docs/reference/date-title-fidelity.md` |
| `LooseEndsTests/CorpusTests.swift` | `corpusIsSound`: Entitäten müssen wörtlich im Rohtext stehen, Mindestzahlen |
| `LooseEndsLab/MeasurementRunner.swift` | Bündelt den Korpus, misst `remaining(from:)` — neue Sätze werden nach `sim.sh lab` automatisch nachgeholt |
| `scripts/export-focusblox-corpus.swift` | Export aus dem FocusBlox-Store; exportiert `ZTASKDESCRIPTION` (Rohsatz) noch nicht — zweiter Schnitt |

## Existing Patterns
- Optionale JSON-Schlüssel werden als `private var xList: String?` dekodiert und über eine
  berechnete Eigenschaft mit Default ausgegeben (`entities`, `people`). `form` folgt dem Muster.
- Der Bericht gruppiert schon nach Ausdruck (`byRule`) und Bedingung (`byCondition`) mit `Tally`;
  Bauform kommt als dritte Gruppierung, aber mit drei Kriterien je Form (Datum, erfundenes Datum,
  Titel-Fakten), weil eine Form beim Datum gut und beim Titel schlecht sein kann.
- Tests zuerst (RED): `corpusHasSentenceForms` und `DateTitleFormSectionTests` liegen bereits
  rot vor; die Bauform-Prüfungen je Form (Stichwort ≤ 3 Wörter, Frage endet mit „?", Ich-Satz
  beginnt mit „ich", Diktat klein und ohne Komma) halten die Formen ehrlich.

## Dependencies
- Upstream: `Corpus.load()` aus dem Test-Bundle bzw. neben der Quelldatei; `TitleCheck.words`.
- Downstream: Labor-App (Korpus ist gebündelt, neuer Stand braucht `sim.sh lab`), Reminders-
  Benchmark #78 (liest denselben Korpus, ignoriert unbekannte Schlüssel), `sim.sh report`.

## Existing Specs
- `docs/specs/lab-83-foreground-measurement.md` — Labor-App, Messlauf in Scheiben (#83)
- Kein Spec für den Korpus selbst; Regeln stehen als Doc-Kommentar in `Corpus.swift`.

## Risks & Considerations
- Entitäten bei Tippfehlern und Diktatfehlern in Namen werden **wie getippt** geführt („Dativ",
  „Öz Demir"): Korrigiert das Modell, zählt das als verlorene Entität — gewollt, das ist der
  Befund. Namens-Tippfehler mit `people` würden über `alteredNames` als erfundener Fakt zählen,
  darum kein Tippfehler in Personennamen mit `people`-Eintrag.
- Bestehende Sätze bleiben `standard`; nur `de-diktat-*`, `en-dictation-*` und `de-lang-2..4`
  werden nachträglich als `diktat`/`nebensatz` markiert.
- Hennings echte Verteilung (12 % mit Datum) wird hier nicht nachgebildet; die Gewichtung nach
  realer Verteilung gehört zum zweiten Schnitt mit seinen Rohsätzen.
- Alternativen zum Weg: (a) nur seine 108 Rohsätze messen, keine erfundenen Formen — scheitert
  daran, dass die Wahrheit je Satz von ihm kommen muss und Regeln gegen den Messtag dort nicht
  passen (die Sätze wurden an festen Tagen erfasst); (b) Bauform automatisch klassifizieren statt
  im JSON zu führen — spart Pflege, ist aber selbst eine Fehlerquelle im Messgerät.

## Analysis

### Type
Feature (Messgerät erweitern), Schnitt 1 von 2 für #82. Schnitt 2 (Hennings Rohsätze als
lokaler Korpusteil mit seiner Wahrheit, Gewichtung nach realer Verteilung) wird ein eigenes
Sub-Issue, weil er einen Export aus dem FocusBlox-Store, ein Wahrheits-Format für Henning und
einen Messlauf mit festem Erfassungsdatum braucht.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/date-title-corpus.json` | MODIFY | 114 neue Sätze in 11 Bauformen mit Regel-Wahrheit; 9 bestehende Sätze als `diktat`/`nebensatz` markiert |
| `Measurement/Corpus.swift` | MODIFY | `form` je Eintrag (Default `standard`), `Corpus.forms`, `Corpus.standardForm` |
| `LooseEndsTests/DateTitleReportTests.swift` | MODIFY | `FormTally`, `byForm`, Abschnitt „Nach Bauform" mit Datum, erfundenem Datum und Titel-Fakten je Form |
| `LooseEndsTests/CorpusTests.swift` | MODIFY | RED-Test `corpusHasSentenceForms` (liegt vor) |
| `docs/project/04-stand.md` | MODIFY | Korpuszahl in der Messstrecke-Zeile |

### Scope Assessment
- Files: 5
- Estimated LoC: Code +60 (Corpus.swift +12, Report +35, Tests +45 liegen vor); Daten +114 Zeilen JSON
- Risk Level: LOW — Messgerät und Tests, kein Produktcode; Labor-App holt neue Sätze über `remaining(from:)` von selbst nach

### Technical Approach
Bauform als optionaler JSON-Schlüssel `form` nach dem bestehenden Muster für optionale Felder;
fehlender Schlüssel heißt `standard`. Der Bericht führt je Bauform drei Zählwerke (Datum exakt,
Datum erfunden, Titel ohne erfundene Fakten), weil die Kriterien pro Form auseinanderlaufen
können. Die neuen Sätze werden per Skript angehängt (Wahrheit als Regel, Entitäten wörtlich aus
dem Text), das Skript bleibt außerhalb des Repos; der Korpus selbst ist die Quelle. Formprüfungen
im Test (Stichwort ≤ 3 Wörter, Frage endet mit „?", Ich-Satz beginnt mit „ich", Diktat klein und
ohne Komma) verhindern, dass eine Form nur dem Namen nach existiert.

### Dependencies
- `Corpus.load()` (Test-Bundle, Labor-App, #78-Benchmark) — unbekannte Schlüssel werden ignoriert, alte Leser bleiben intakt.
- `MeasurementRunner.remaining(from:)` — neue IDs zählen als offen, der laufende Messstand bleibt.

### Open Questions
- [ ] Keine für den PO. Technisch entschieden: Entitäten bei Tipp- und Diktatfehlern wie getippt.
