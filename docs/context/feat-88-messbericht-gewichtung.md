# Context: feat-88-messbericht-gewichtung

## Request Summary
#88 Teil 1 (neu geschnitten 2026-10-23): Der Messbericht für #67 weist die Gesamtzahl zusätzlich nach Hennings
Verteilung der Satzformen gewichtet aus, mit Regel-Spalte daneben. Teil 2 (echte Rohsätze) wartet auf Hennings Wort.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsTests/DateTitleReportTests.swift` | Hier lebt der Berichtsbau (`formSection`, `titleSection`, `conditionSection`, `Report`, `FormTally`). Die Gewichtung kommt neben `formSection`. |
| `Measurement/Corpus.swift` | `Corpus.forms` (12 Formen, geschlossene Liste), `Entry.form`, `TitleCheck`. Hier hängt das Gewicht je Form. |
| `Measurement/date-title-corpus.json` | 203 Sätze `standard` + je ca. 11 in den 11 anderen Formen. |
| `docs/reference/date-title-fidelity.md` | Der eingecheckte Bericht („Nach Bauform“, Zeile 63 ff.); wird mit neuem Abschnitt neu erzeugt. |
| `docs/specs/measurement/issue-82-satzformen.md` | Spec von Schnitt 1; „Nicht in diesem Schnitt“ benennt genau diesen Rest. |
| `docs/project/06-annahmen-und-experimente.md` | Z. 280 ff.: Datenbasis, kein Rohtext-Korpus. |

## Existing Patterns
- Der Bericht ist reine Funktion über Messläufe + Korpus, im Test-Target, Markdown mit Tabellen. Ein Kriterium ohne Sätze zeigt „–“, nie 0 % oder 100 %.
- Jede bekannte Form bekommt eine Zeile, auch unbemessen („fehlende Zeile liest sich wie ‚in Ordnung‘“).
- Die Regel-Spalte gibt es beim Datum (`ruleParser`, `FrozenDetector`), **nicht** beim Titel: `TitleRule` fehlt im Bericht.

## Befunde zur Herkunft der Gewichte (wichtig für die Analyse)
- Quelle der Zahlen „12 % mit Zeitangabe“ und „ein Drittel Stichwörter ohne Verb“: Hennings 108 FocusBlox-Rohsätze (Spec Schnitt 1, Problem-Absatz). Sonst stehen **keine** Anteile für `ich-satz`, `frage`, `diktat`, `praefix` usw. irgendwo.
- Also gibt es nur zwei belegte Gewichte: `stichwort` ≈ 1/3, und „Zeitangabe“ ≈ 12 % (das ist ein Merkmal quer über die Formen, keine Form). Eine Gewichtung über alle 12 Formen kann daraus **nicht** ehrlich berechnet werden.
- Die 108 Sätze liegen in FocusBlox (Beschreibungsfeld, meist Titelkopie); `scripts/export-focusblox-corpus.swift` existiert. Ob daraus eine Verteilung je Form zählbar ist, ohne Rohtext aus Loose Ends, ist offen.
- Das Modell liefert seit #95 kein Datum mehr; die Datum-Spalten im Bericht beschreiben den Regelparser-Weg. Für das Modell zählen Titel-Treue und Dauer.

## Dependencies
- Upstream: `Corpus`, `RawTextWords`, `TitleRule`, `DateExpressionParser`.
- Downstream: `scripts/compare_reports.py` liest den Bericht (Test `scripts/test_compare_reports.py`); der eingecheckte Bericht darf sich nicht bei jedem Unit-Lauf neu schreiben (#543).

## Existing Specs
- `docs/specs/measurement/issue-82-satzformen.md` (Schnitt 1, freigegeben).

## Risks & Considerations
- **Erfundene Genauigkeit:** Aus zwei Anteilen eine Gewichtung über 12 Formen zu bauen, wäre geraten. Ansatz zur Prüfung in der Analyse: Gewichtung nur über die belegten Merkmale (Stichwort ja/nein, Zeitangabe ja/nein), der Rest laut „ohne Gewicht“.
- **Alternative zum Gewichten:** Statt zu gewichten die Zahl je Form beibehalten und die zwei belegten Anteile als Hinweis neben die Gesamtzahl stellen; wäre kleiner, aber gewichtet nichts.
- Berichtsdatei und CI: Änderungen am Bericht nur über einen Test, der keinen eingecheckten Bericht überschreibt (#543, #147).
- Kein Pfad der Geräteliste berührt; Lauf auf dem iPhone nicht nötig.

## Analysis

### Type
Feature (Messbericht, nur Test-Target; Teil 1 von #88. Teil 2 wartet auf Hennings Wort.)

### Recherche
Keine unbekannte Schnittstelle und kein Fehler: reine Berichtsrechnung über vorhandene Messläufe. Eine Websuche entfällt, begründet.

### Befunde (nachgezählt am 2026-10-24, regelbasiert, `docs/reference/focusblox-corpus.json` im Hauptordner)
- Alle 287 FocusBlox-Einträge haben `rawText == title`: gepflegte Titel, keine Rohsätze.
- Davon 211 (73,5 %) mit höchstens 3 Wörtern, 3 Fragen, 1 mit Zeitwort (0,3 %). Hennings Angaben („ein Drittel Stichwörter“, „12 % mit Zeitangabe“) stammen aus den 108 Beschreibungen; die liegen im Korpus nicht vor und sind nicht nachprüfbar.
- Zwei belegte Gewichte, beide Hennings Angabe: Stichwort ≈ 1/3, Zeitangabe ≈ 12 %. Für `ich-satz`, `frage`, `diktat`, `praefix` … gibt es keine Anteile. Eine Gewichtung über alle 12 Formen wäre geraten.
- `formSection` zeigt nur Modellzahlen; die Regel-Spalte fehlt dort und beim Titel ganz (`TitleRule` kommt im Bericht nicht vor, die Regelparser-Tallies für das Datum existieren schon im `Report`).

### Entscheidung Henning (AskUserQuestion, 2026-10-24)
Gewichte = seine Angaben, gekennzeichnet „Angabe Henning, nicht nachgezählt“; daneben eine zweite Zeile mit der Zählung an den 287 Titeln als Empfindlichkeit.

### Technical Approach (Regeln vor Modell: reine Rechnung, kein Modell)
Gewichtet wird über **zwei Gruppierungen je Kriterium**, nie über 12 Formen:
- Titel-Kriterien: Gruppe Stichwort (`form == stichwort`) mit Gewicht 1/3, alle anderen Formen zusammen 2/3. Gesamtzahl = Σ Gewicht × Anteil der Gruppe.
- Datum-Kriterien: Gruppe „Satz mit Zeitangabe“ (Wahrheit hat ein Datum) 12 %, ohne 88 %.
- Keine Kreuzzellen (Stichwort × Zeit): das setzte Unabhängigkeit voraus, die nirgends belegt ist.
- Ist eine Gruppe leer (kein Satz), steht „–“ und die Gesamtzahl entfällt laut („ohne Gewicht“), nie still umnormiert.
- Formen ohne Gewicht stehen im Bericht ausdrücklich als „kein Gewicht“.
- Regel-Spalte in jeder Zeile: `TitleRule` (Titel ohne erfundene Fakten über `TitleCheck`) und der schon gemessene Regelparser (Datum exakt/erfunden) neben dem Modell, auch in „Nach Bauform“.
- Neuer Abschnitt „Gewichtet nach Hennings Verteilung“ neben `formSection`, mit Gewichten, Quelle, Zählung als zweiter Zeile. Der eingecheckte Bericht wird nur über den bestehenden Weg neu erzeugt (#543, #147), nie bei jedem Unit-Lauf.

### Alternativen (zum bisherigen Weg)
1. **Spanne statt Gewicht:** schlechteste/beste Bauform und Differenz; nichts geschätzt, aber keine „Gesamtzahl nach seiner Verteilung“. Von Henning verworfen zugunsten von Gewichten mit Gegenzählung.
2. **Nur Zählung der 287 Titel:** nachprüfbar, aber es sind Titel statt Rohsätze (kippt die Annahme „Hennings Verteilung“ aus Schnitt 1).
3. **Teil 2 vorziehen** (Zählung an echten Erfassungen): würde die Gewichte belegen, braucht aber sein Gerät und „jetzt ist ein Test möglich“. Bleibt Teil 2.
Gekippt würde keine ADR; Schnitt 1 (`issue-82-satzformen`) bleibt unberührt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsTests/DateTitleReportTests.swift` | MODIFY | Gewichtsabschnitt, Regel-Spalten in `formSection`, Gruppenrechnung |
| `Measurement/Corpus.swift` | MODIFY | Gewichte als benannte Konstanten mit Quelle (falls dort besser als im Test) |
| `LooseEndsTests/` (neue Datei, z. B. `WeightedReportTests.swift`) | CREATE | Tests der Rechnung: leere Gruppe, Gewichtssumme 1, Umnormierung verboten |
| `docs/reference/date-title-fidelity.md` | MODIFY | neu erzeugter Bericht |

### Scope Assessment
- Files: 4
- Estimated LoC: +150/-10
- Risk Level: LOW (nur Messbericht im Test-Target; `compare_reports.py` liest Abschnittsüberschriften, ein neuer Abschnitt darf keine bestehende verschieben)

### Dependencies
`Corpus`, `TitleCheck`, `TitleRule`, `DateExpressionParser`; Leser `scripts/compare_reports.py`. Kein Gerät, kein Pfad der Geräteliste berührt.

### Open Questions
- [x] Welche Zahlen als Gewichte? → Hennings Angaben, Zählung daneben.
- [ ] Spec: Soll `compare_reports.py` den neuen Abschnitt kennen? (Standard: nein, nur nicht stören.)
