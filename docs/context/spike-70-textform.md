# Context: spike-70-textform (#70)

## Request Summary
Spike #70 (Epic #370, M3): Ist die Textform egal? Derselbe Inhalt getippt, diktiert, als Mail und auf Englisch soll
dieselbe Struktur ergeben. Die Regelspalte ist gemessen (PR #270). Offen laut Ticket: die Modellspalte (iPhone-Laborlauf)
und die Entscheidung je Kanal „roh ins Modell / vorverarbeiten“.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/reference/textform-rules.md` | Regelspalte: getippt 40/40, Diktat 39/40 (Uhrzeit 39), Mail roh 0 brauchbar, Mail zugeschnitten 0 erfunden, Englisch ≈ getippt. Entscheidung je Kanal steht dort schon, aber ohne Modellspalte. |
| `Measurement/textform-corpus.json` | 40 Inhalte × Formen typed/dictated/mail/english (mailCut wird im Test berechnet), Wahrheit je Feld |
| `LooseEndsTests/TextFormRuleReportTests.swift` | Regelbericht (Referenztag 2026-10-07), Markdown nach stdout |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | Schema `ModelEnrichment`: title, duration, contexts, project (+ Konfidenz, Grund). Der Writer übernimmt nur Titel und Dauer. |
| `LooseEndsLab/MeasurementRunner.swift` | Laborläufer: ein Satz je Aufruf, liest `Corpus.load(fileName:)`; Ergebnis je Satz mit Titel, Dauer, Kontexte, Bedingungen |
| `Measurement/Corpus.swift` | Korpusformat des Läufers (`Corpus.Entry` mit `text`), anderes Format als `textform-corpus.json` |
| `Shared/Services/SharedContent.swift:26-53` | Mail aus der Share-Erweiterung: nur der Betreff wird vorbelegt (`subject(ofMail:)`), nie der Körper |
| `docs/reference/modell-verfuegbarkeit.md` | #68: Das Modell läuft nur in der App; „kein Modell“ ist ein Normalzustand |
| `docs/project/06-annahmen-und-experimente.md` (B2) | Annahme „Textform ist egal“ mit Abbruchkriterium und Alternativen |

## Existing Patterns
- Regelbericht als Swift-Testing-Test, der nur den Korpus prüft und den Bericht auf stdout schreibt.
- Modellmessungen laufen in der Labor-App (`com.henning.looseends.lab`) in Scheiben, Rückkanal per `sim.sh lab-run` / `lab-fetch`; nie als Xcode-Testlauf (Memory „Handy ist kein Prüfstand“).
- Auswertung nach Vorbild #534 und `modell-latenz.md`: Rohdaten unter `docs/artifacts/`, Bericht unter `docs/reference/`.

## Dependencies
- Upstream: #95 (Datum per Regel), #215 (Modell setzt nie Kontexte), #469 (nie Projekt), #202 (Titel per `TitleRule` beim Erfassen), #68 (Matrix).
- Downstream: #342 Teil 5, Entscheidung je Kanal für Mail-Teilen (Epic #371).

## Befund für die Analyse
1. Das Modell schreibt im Produkt nur **Titelverfeinerung und Dauer**. Datum, Uhrzeit, Wichtigkeit, Dringlichkeit, Kontexte, Projekt kommen aus Regeln oder gar nicht. Die Modellspalte kann also nur Titel-Treue und Dauer-Übereinstimmung zwischen Formen messen, nicht die fünf Felder der Regelspalte.
2. Die Mail-Frage ist im Produkt schon entschieden: Der Körper erreicht das Modell nie, nur der Betreff.
3. Der Korpus hat keine Wahrheit für Dauer. `truth` kennt due, time, importance, urgency, contexts, titleWords. Eine Dauer-Übereinstimmung wäre nur Form gegen Form (Selbstkonsistenz), nicht gegen Wahrheit.
4. Gerät: Der Laborlauf braucht Hennings wörtliches „jetzt ist ein Test möglich“, gebündelt mit #71.

## Risks & Considerations
- Alternative zur Modellspalte: B2 ohne Modell beantworten (Regelspalte plus Produktpfad „nur Betreff“) und Titel/Dauer-Modellmessung auf #88 verschieben. Dafür muss die Analyse die Zeile „Ohne Modell geht es nicht, weil …“ belegen oder streichen. Kippt: Annahme B2 im Wortlaut „das Modell muss aus allen Formen dieselbe Struktur machen“.
- Zwei Korpusformate (`textform-corpus.json` gegen `date-title-corpus.json`): Ein Laborlauf braucht einen Adapter oder ein zweites Korpusformat im Läufer.
- Das Diktat des Korpus ist geschrieben, nicht gesprochen (kleingeschrieben, ausgeschriebene Zahlen); die Spracherkennung selbst ist nicht Teil der Messung.

## Analysis

### Type
Spike (Messung und Entscheidung, kein Produktcode). Kein Bug, kein UI.

### Recherche
Keine externe Schnittstelle, kein Fehlertext: Die Frage ist eine Messfrage über das eigene Produkt. Belege sind die
eigenen Berichte (`textform-rules.md`, `date-title-fidelity.md`, `modell-verfuegbarkeit.md`) und der Produktcode.

### Hat es bisher funktioniert?
Nicht anwendbar (kein Fehler). Stand: Regelspalte gemessen und gemergt (PR #270), Uhrzeit-Fix im Parser enthalten.

### Befund
1. **Was die Modellspalte überhaupt messen kann.** `ModelEnrichment` liefert Titel, Dauer, Kontexte, Projekt. Der Writer
   übernimmt davon nur Titel und Dauer (#215 Kontexte nie, #469 Projekt nie). Datum, Uhrzeit, Wichtigkeit, Dringlichkeit
   kommen aus Regeln. Die fünf Felder der Regelspalte sind also im Produkt gar nicht Sache des Modells. Das Abbruchkriterium
   des Tickets („Felder zwischen getippt und diktiert") ist für das Modell auf zwei Felder zusammengeschrumpft.
2. **Mail.** Das Produkt reicht nie den Körper weiter, nur den Betreff (`SharedContent.subject(ofMail:)`). „Mail setzt
   Felder aus der Signatur" kann im Produkt nicht passieren. Die Regelspalte zeigt zusätzlich: roher Körper erzeugt
   bei Regeln Erfundenes (Tag 20, Uhrzeit 30, Wichtigkeit 35, Dringlichkeit 29, Kontexte 25 von 40); zugeschnitten 0.
3. **Titel.** Regeln: Schlüsselwörter in allen Formen 100 % im Titel (`TitleRule`, ≤ 12 Wörter, setzt den Titel beim Erfassen).
   Das Modell darf ihn nur verfeinern. Ein Mehrwert der Verfeinerung gegenüber der Regel ist nirgends belegt.
4. **Dauer.** Es gibt keine Wahrheit für Dauer im Textform-Korpus. Eine Modellmessung wäre nur Selbstkonsistenz
   (Form gegen Form), nicht Treue. `DurationRule` deckt zudem ausdrücklich genannte Längen ab (#441/#673).
5. **Aufwand der Modellspalte.** Zweites Korpusformat (`textform-corpus.json` gegen `Corpus.Entry`), Adapter im Läufer,
   Gerätelauf des iPhone (8,8 s je Satz laut #67, 40 × 4 Formen ≈ 160 Aufrufe ≈ 25 min, dazu Drosselung), Hennings Wort
   „jetzt ist ein Test möglich", Bündelung mit #71.

### Ohne Modell geht es nicht, weil …
Für kein Feld belegt. Titel: Regel 100 % Schlüsselwörter in allen Formen. Dauer: nur dort offen, wo der Text keine Länge
nennt; das ist die Frage von #88/#72, nicht der Textform. Deshalb ist der Regelweg der Vorschlag.

### Varianten (Zahlen, bevor die Empfehlung kommt)
| Variante | Antwortet auf B2 | Gerät nötig | Aufwand | Kippt |
|---|---|---|---|---|
| A. B2 ohne Modell beantworten: Regelspalte + Produktpfad „nur Betreff“; Titel/Dauer-Formtreue des Modells als Spalte in den ohnehin nötigen Laborlauf von #88 | Ja, für alle Felder, die das Produkt setzt | Nein, nicht für #70 | gering: Bericht abschließen, B2 in `06` eintragen, Notiz an #88 | Wortlaut der Annahme B2 („das Modell muss aus allen Formen dieselbe Struktur machen“) wird zu „die Struktur entsteht aus allen Formen“ |
| B. Eigene Modellspalte jetzt (Adapter, ≈160 Aufrufe auf dem iPhone) | Zusätzlich Titel/Dauer-Selbstkonsistenz | Ja | mittel: Adapter ≈ 80 LoC, Gerätelauf, Auswertung | nichts |
| C. Alles nur Regeln, Modellspalte endgültig streichen | Ja | Nein | am geringsten | zusätzlich: Titelverfeinerung durch das Modell bleibt ungeprüft (Risiko, nicht neu) |

### Entscheidung je Kanal (Vorschlag für den Bericht)
- Getippt, Diktat, Englisch: roh an die Regeln, Modell nur Titelverfeinerung/Dauer.
- Mail: Körper weder ans Modell noch an die Regeln, nur der Betreff. Kommt je ein Körper-Feature (#342 Teil 5, Epic #371),
  dann zuerst auf den eigenen Text zuschneiden (Regelspalte mailCut: 0 erfundene Felder), nie roh.
- Diktat: Satzzeichen-/Zahlen-Normalisierung nicht nötig (Regeln 39–40/40 nach Fix).

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/reference/textform-rules.md` | MODIFY | Kopf „Modellspalte fehlt“ ersetzen durch Befund und Entscheidung je Kanal, Mail-Zeile mit Produktpfad |
| `docs/project/06-annahmen-und-experimente.md` | MODIFY | B2: Ergebnis, berichtigter Wortlaut, Verweis auf #88 für Titel/Dauer-Formtreue |

### Scope Assessment
- Files: 2 (+ Kommentar an #88)
- Estimated LoC: +40/-5, nur Doku
- Risk Level: LOW (kein Code, kein Gerät)

### Open Questions
- [ ] PO: Variante A (Empfehlung), B oder C?
