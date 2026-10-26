# Adversary Dialog — feat-88-textform-spalte
Spec: docs/specs/measurement/feat-88-textform-spalte.md
Datum: 2026-10-26 07:16

## Checkliste
- [x] **AC-1:** Adapter erkennt das Objektformat. Given `Corpus.load(fileName: "textform-corpus")` / When die Datei gelesen wird / Then liefert es `Corpus.Entry` je Inhalt × Form `typed`, `dictated`, `english`, also 120 Notizen für 40 Inhalte. Erkannt wird am Dateiinhalt (oberster Wert ist ein Objekt mit `entries`), nicht am Dateinamen.
- [x] **AC-2:** Kennung und Sprache. Given die 120 Notizen / When Kennung und Sprache gelesen werden / Then lautet die Kennung `<inhalt>.<form>` (z. B. `tf-01.typed`, `tf-01.dictated`, `tf-01.english`), `lang` ist `en` für `english` und `de` für `typed` und `dictated`, `text` ist der Wortlaut der Form unverändert.
- [x] **AC-3:** Mail bleibt draußen. Given der Adapter / When die Notizen gezählt werden / Then kommt keine Notiz der Form `mail` vor (das Produkt reicht nur den Betreff weiter, der Körper ist kein Modell-Eingang).
- [x] **AC-4:** Bestehende Korpusse unverändert. Given `date-title-corpus`, `latency-corpus` und der FocusBlox-Korpus / When sie über `Corpus.load` gelesen werden / Then sind Anzahl, Kennungen und Texte genauso wie vor der Änderung; ein Test hält das fest. `date-title`- und `latency`-Läufe ändern sich nicht.
- [x] **AC-5:** Titel-Spalte je Form. Given `[MeasurementResult]` aus einem Lauf mit diesem Korpus / When ausgewertet wird / Then steht je Form (`typed`, `dictated`, `english`) der Anteil der Notizen, deren Modelltitel alle `truth.titleWords` des Inhalts enthält (Vergleich über `RawTextWords`), und daneben in derselben Zeile derselbe Anteil für den Titel, den `TitleRule` aus dem Rohtext bildet. Fehlgeschlagene Aufrufe (`error` gesetzt) zählen als nicht getroffen und werden mit ihrer Zahl ausgewiesen.
- [x] **AC-6:** Dauer-Spalte ohne Wahrheit, laut. Given dieselben Ergebnisse / When die Dauer ausgewertet wird / Then steht je Form `dictated` und `english` der Anteil der Inhalte, deren Dauer (Mehrheit über die Läufe via `SelfConsistency.majority`) der Dauer der Form `typed` desselben Inhalts gleicht. Der Bericht sagt in einer Zeile, dass der Korpus keine Dauer-Wahrheit hat und die Zahl eine Übereinstimmung zwischen den Formen ist, keine Trefferquote. Inhalte ohne Dauer in `typed` oder ohne Ergebnis zählen nicht mit und werden gezählt ausgewiesen.
- [x] **AC-7:** Leere Gruppe, keine erfundene Zahl. Given eine Form ohne Ergebnisse / When ausgewertet wird / Then zeigt ihre Zeile „–“ statt 0 %.
- [x] **AC-8:** Bericht gesperrt, laut übersprungen. Given `TextFormModelReportTests` / When die lokale Ergebnisdatei fehlt / Then wird die Suite übersprungen und das laut benannt (#149, Muster `SelfConsistencyReportTests`, Pfad über `MeasurementData`); liegt sie vor, gibt der Test den Bericht nach stdout aus. Es läuft in keinem Test ein Modellaufruf.
- [x] **AC-9:** Aufruf dokumentiert. Given `docs/reference/textform-rules.md` / When gelesen / Then ersetzt der Satz zum Aufruf (`--corpus textform-corpus --runs <n> --result <name>`, Auswertung) den Hinweis „Modellspalte fehlt noch“, und der Text sagt, dass der Lauf nur nach Hennings Wort läuft.

## Dialog

### Runde 1
**Adversary:** Tests und Code gelesen, Angriffe je AC.

Test-Beleg: docs/artifacts/feat-88-textform-spalte/adversary-test-output.txt — `sim-unit TextFormColumnTests`: 7 Tests bestanden, 0 fehlgeschlagen; `test_measurement_status.py`: 19 OK. Suite TextFormModelReportTests wird laut als "fehlt: textform-run.json" uebersprungen (nicht als bestanden gezaehlt).

Confirmation: AC-1, AC-2, AC-3
  Code reference: Measurement/Corpus.swift:147 (load prueft am Dateiinhalt `object["entries"] != nil`), Measurement/Corpus.swift:168 (textFormEntries: je Inhalt x TextFormColumn.forms, lang `en` nur bei english)
  Evidence: Korpus hat 40 eindeutige Ids, jede mit typed/dictated/mail/english; forms = [typed,dictated,english] ergibt 120, mail ausgeschlossen (Measurement/TextFormColumn.swift:9). Test adapterYields120Notes/idsAndLanguage gruen.
  Status: CONFIRMED

Confirmation: AC-4
  Code reference: Measurement/Corpus.swift:147
  Evidence: (a) Array-JSON: `as? [String: Any]` ist nil, Fallthrough zum unveraenderten `JSONDecoder().decode([Entry].self)`. Alle Korpusse in Measurement/ (date-title, latency, guardrail, convention) sind Listen. Der FocusBlox-Korpus laeuft gar nicht ueber `Corpus.load` (eigener Lader, Datei nur lokal) – die Nennung in AC-4 ist leer, kein Bruch. Fehlerfaelle: fehlende Datei wirft weiter `.fileNoSuchFile` (url(fileName:) identisch); kaputtes/leeres JSON wirft weiterhin, aber jetzt NSError (Cocoa 3840, JSONSerialization) statt DecodingError – Aufrufer sind `try?`/`try` ohne Typpruefung. Ein Objekt mit `entries` in fremder Datei wuerde als Textform-Korpus gelesen: gibt es nicht.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Measurement/Corpus.swift:148
  Description: load parst jede Korpusdatei zweimal (JSONSerialization, dann Decoder); kaputtes JSON wirft nun einen anderen Fehlertyp als vorher (NSError 3840 statt DecodingError).
  Spec requirement: AC-4 — bestehende Korpusse unveraendert
  Conflict: Nur Fehlertyp/Leistung, kein Aufrufer wertet den Typ aus; Test fuer den Fehlerfall fehlt, FocusBlox nicht getestet.
  Remediation: Optional; kein Block.

Confirmation: AC-5
  Code reference: Measurement/TextFormColumn.swift:52
  Evidence: Fehler zaehlen in `notes` (ofForm.count), nicht in `modelHits` (error == nil verlangt), `errors` ausgewiesen. Vergleich ueber RawTextWords.normalized (case/diacritic-insensitiv; "Müller" trifft "MÜLLER" und "muller", aber nicht "Mueller" – wie in der RawTextWords-Doku gewollt). Teilstring statt Wortgleichheit: "rechnung" trifft "Rechnungen" (mild; Regelspalte gleich behandelt, also vergleichbar). Leere titleWords oder nil-Titel ergeben Miss (TextFormColumn.swift:44). Regelspalte nur ueber Notizen mit Ergebnis und Text (Zeile 59). Closure statt TitleRule: TitleRule liegt nicht im Lab-Ziel; der Bericht reicht `TitleRule.title` ein.
  Status: CONFIRMED

Confirmation: AC-6
  Code reference: Measurement/TextFormColumn.swift:72
  Evidence: Mehrheit via SelfConsistency.majority (Gleichstand deterministisch ueber den kleineren Wert, SelfConsistency.swift:45); Fehlerlaeufe herausgefiltert; fehlende typed- oder Formmehrheit -> skipped. Hinweiszeile "keine Wahrheit ... keine Trefferquote" in render (Zeile 112). Test durationAgreement prueft compared/same/skipped.
  Status: CONFIRMED

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/TextFormModelReportTests.swift:23
  Description: Der Bericht uebergibt `run.succeeded` an durationRows; Inhalte, deren Laeufe in allen Formen scheitern, verschwinden aus der "nicht vergleichbar"-Zaehlung (durationRows kennt `contents` nur aus den uebergebenen Ergebnissen).
  Spec requirement: AC-6 — Inhalte ohne Ergebnis werden gezaehlt ausgewiesen
  Conflict: Vollstaendig gescheiterte Inhalte werden nicht mitgezaehlt; sie erscheinen aber in der Titelspalte als Fehler. Keine falsche Zahl, nur Unschaerfe.
  Remediation: `run.results` uebergeben (durationRows filtert Fehler selbst).

Confirmation: AC-7
  Code reference: Measurement/TextFormColumn.swift:121
  Evidence: `cell` liefert "–" bei rate == nil (notes == 0 bzw. compared == 0), auch bei Dauerzeile mit nur skipped und Regelspalte ohne Ergebnisnotizen. Test emptyFormShowsDash gruen.
  Status: CONFIRMED

Confirmation: AC-8
  Code reference: LooseEndsTests/TextFormModelReportTests.swift:12
  Evidence: `@Suite(.enabled(if: MeasurementData.exists(...)))` mit Begruendung; Lauf zeigt "TextFormModelReportTests – fehlt: textform-run.json" als uebersprungen (Messstrecken: 2 von 5). measurement_status.py GATES und Registry-Test gleichen die Swift-Quelle ab (19 OK). Suche nach FoundationModels/Enricher in TextForm* und Measurement/TextFormColumn.swift: kein Treffer – kein Modellaufruf.
  Status: CONFIRMED

Confirmation: AC-9
  Code reference: docs/reference/textform-rules.md:7
  Evidence: Absatz nennt `--corpus textform-corpus --runs <n> --result textform-run`, Auswertung, "Modellspalte fehlt noch" entfernt, Hennings Wort genannt. Test referenceDocNamesCall gruen.
  Status: CONFIRMED

Scope/Lab-Ziel: project.yml:275-286 – LooseEndsLab kompiliert `Measurement/` komplett plus RawTextWords.swift; TextFormColumn.swift nutzt nur Foundation, RawTextWords, SelfConsistency, MeasurementResult, Corpus.url (alle im Ziel; CorpusAnchor liegt in Corpus.swift). Kein TitleRule/LooseEnds-Import. MeasurementRunner und project.yml im Arbeitsbaum unveraendert. Mail nicht in den Notizen. Zusaetzlich zu den 5 Spec-Dateien geaendert: MeasurementData.swift, measurement_status.py, test_measurement_status.py (je 2-10 Zeilen), noetig fuer den Registry-Test der Messstrecken; Gesamtumfang unter 250 LoC, Dateizahl ueber der Spec-Angabe (LOW, Scope-Hinweis).
**Implementierer:** (nicht anwesend)

### Runde 2
**Adversary:** Gegenprobe der Frueh-Zustimmung: Korpusform per Python geprueft (40 Inhalte, alle mit allen vier Formen, 40 eindeutige Ids; `split` nutzt lastIndex und ist auch bei Punkten im Inhaltsteil robust). Fremde Korpusse: alle Listen. Kein Befund, der ein AC bricht. Offene Schwaeche: der AC-4-Test deckt nur date-title und latency; guardrail/convention/FocusBlox sind ungetestet, aber strukturell durch den Array-Fallthrough abgedeckt (Corpus.swift:149-151).
**Implementierer:** (nicht anwesend)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED** — alle 9 ACs bewiesen, 7 Tests + 19 Python-Tests gruen; zwei LOW-Hinweise (F001, F002) ohne Spec-Bruch.

## Geprüfte Dateien

- sha256:9edf832d2c6b2d7f0d70a3e78cfb52a028df840f4801ae85d3808fc53b32b912  LooseEndsTests/TextFormModelReportTests.swift
- sha256:e8948e5190f1db08c4254573c7ac1eaf0cdc473531a60776976b53d4fa1bb796  Measurement/Corpus.swift
- sha256:3a2a2f5a4a67564dfa6d826c9fbd41925f530dbfbac3967d5616f9de09cc9fb2  Measurement/TextFormColumn.swift
- sha256:5e0da887785aa3e6f37b53a22a31d84df3324f75293f2b7303cc12037a28f91f  docs/reference/textform-rules.md

## Prüfbasis

- base: eb61b1b24504a220d08480ef3a09c706fd164e79
- blob:97c214663b33a6cb5b235c7d092cf9e082c3efb4  LooseEndsTests/TextFormModelReportTests.swift
- blob:e7d9f3bba95c491b879e21d6e453d5fc87b69201  Measurement/Corpus.swift
- blob:e4410fbfff1d9ed9737ea37124ba7adaf9b44243  Measurement/TextFormColumn.swift
- blob:48543364300ca73c75a70fc121b42d9d50e8939c  docs/reference/textform-rules.md
