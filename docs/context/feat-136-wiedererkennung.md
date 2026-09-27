# Context: feat-136-wiedererkennung

## Request Summary

Ein Rohtext, der schon einmal erfasst wurde, soll die **Kontexte und die Dauer** des früheren
Eintrags wieder setzen — still, mit Konfidenz 1.0, KI-Marker und `Revision` wie jede Anreicherung
(Issue #136, Folge der B1-Entscheidung vom 2026-09-27). Ähnlichkeit ist Jaccard-Wortüberlappung über
Wörter ab vier Zeichen, ab Schwelle 0,34 gilt der beste Nachbar als Treffer. **Energie ausdrücklich
nicht** — Nachbarn schlagen dort die Konstante auf keiner Lesart, das Feld bleibt manuell (#112).
Ersetzt den Embedding-Teil des bereits geschlossenen #26.

## Related Files

| File | Relevance |
|------|-----------|
| `Shared/Enrichment/ImportanceUrgencyRule.swift` (102 LoC) | Jüngstes Vorbild (#117): reines `enum`, `Guess`-Rückgabe, Konfidenz-Konstante an einer Stelle, `nil` bei Nichttreffer, ausdrücklich `Foundation`-only wegen Watch/Widgets/Share |
| `Shared/Enrichment/DueDateRule.swift` (57 LoC) | Erstes Vorbild (#95): Regel schlägt Modell, Modell-Schema verlor danach die Felder |
| `Shared/Enrichment/EnrichmentCoordinator.swift` (166 LoC) | Andockstelle: `applyRules(to:)` läuft vor dem Modell, schreibt Revision + Feld + Source + Confidence je Feld nur bei `nil`, lässt `processedAt` unberührt. Hier liegt auch der Fetch-Kontext (`container.mainContext`), den die neue Regel als Vergleichsmenge braucht |
| `Shared/Enrichment/EnrichmentWriter.swift` (95 LoC) | Schreibt heute `draft.duration` und `draft.contexts` mit 0,6-Schwelle; `contexts` per Namensabgleich gegen `available: [TaskContext]`. Betroffen, sobald die Regel diese Felder belegt |
| `Shared/Enrichment/FoundationModelsEnricher.swift` (131 LoC) | `ModelEnrichment`-Schema führt `duration*` und `contexts*`; `instructions` nennt Dauer-Buckets und erlaubte Kontexte; `prompt(for:)` beschriftet Beispiele mit `duration`/`contexts` |
| `Shared/Enrichment/EnrichmentDraft.swift` (74 LoC) | `Guess<T>`, `EnrichmentInput.examples`, `EnrichmentExample`; `selfConsistencyValues` (#108) liest `duration`/`contexts` mit — rein lesend betroffen |
| `Measurement/LeaveOneOut.swift` (180 LoC) | Der gemessene Mechanismus: `similarityWords`, `jaccard`, `neighbors(of:in:k:)`. Kompiliert **nur** in Tests und Labor-App — nicht im Produktpfad verfügbar |
| `Measurement/Corpus.swift:235+` (`enum TitleCheck`) | `normalized(_:)` und `words(in:)`, auf denen `similarityWords` beruht. Ebenfalls messungs-only |
| `Shared/Services/DateExpressionParser.swift:27-50` (`enum ExpressionText`) | Der bereits **geteilte** Tokenizer: `folded(_:)` identisch zu `TitleCheck.normalized`, `words(in:)` aber ohne Bindestrich-Erhalt — kandidiert als Produkt-Tokenizer, weicht dann aber messbar von #131 ab |
| `Shared/Models/TaskItem.swift` | `rawText` (unveränderlich), `contexts: [TaskContext]?` + `contextsSourceRaw`/`contextsConfidence`, `durationRaw` + Source/Confidence, `processedAt` |
| `Shared/Models/Revision.swift`, `Shared/Models/Enums.swift` | `RevisedField.contexts`/`.duration` existieren, `FieldSource.ai`, `DurationBucket` — kein neuer Enum-Fall nötig |
| `LooseEnds/App/LooseEndsApp.swift:17` | Einziger Produktions-Aufrufer des Coordinators |
| `LooseEndsTests/ImportanceUrgencyRuleTests.swift` (128 LoC), `DueDateRuleTests.swift` (153 LoC) | Teststil für die reine Regel: Beispiel-Tests, kein Korpus-Score |
| `LooseEndsTests/EnrichmentTests.swift` (378 LoC) | Coordinator-Tests mit Stub-Enricher und In-Memory-Container — hier kommen Pool-/Reihenfolge-/Revisions-Tests hinzu |
| `LooseEndsTests/RuleLeaveOneOutTests.swift` (421 LoC) | Muster für die Korpus-Messung: zwei Suites, Logik immer in CI, Bericht per `.enabled(if: FileManager…fileExists)` auf die gitignorierte Korpusdatei gegattert |
| `docs/reference/focusblox-corpus.json` | 287 echte Aufgaben, gitignoriert, liegt **nur im Hauptordner**, nicht in diesem Worktree |
| `docs/project/02-datenmodell-und-ansichten.md:170-185` | Veredelungs-Pipeline, Schritt 2 „Wiedererkennung" beschreibt das Soll bereits — inklusive Schwelle 0,34 |
| `docs/project/00-entscheidungen.md:94-103` | ADR-5 in der neuen Fassung |
| `docs/project/06-annahmen-und-experimente.md:146-190` | B1-Entscheidung mit der nach Nachbar-Ähnlichkeit aufgeschlüsselten Tabelle |
| `docs/reference/retrieval-leave-one-out-rules.md` | Messbericht #131 mit beiden Lesarten und den Grenzen |

## Existing Patterns

- **Regel vor Modell, Feld-Guard im Coordinator.** `applyRules(to:)` prüft je Feld `== nil`, schreibt
  dann Revision (`author: .ai`), Wert, `*SourceRaw = ai`, `*Confidence` — und rührt `processedAt`
  nicht an, weil dieser Marker „das Modell hat die Aufgabe gesehen" bedeutet (ADR-4). Dadurch fügt
  der Nachzügler-Lauf keine zweite Revision hinzu.
- **Reine Regel, Aufrufer speichert.** Regeln sind `enum` ohne Zustand, ohne SwiftData, ohne
  Kalender-Abhängigkeit, wo es geht; `Shared/` kompiliert auch in Watch, Widgets und Share-Extension.
- **Konfidenz 1.0 bei deterministischen Regeln** (#95, #117): ein Zwischenwert wäre eine erfundene
  Zahl. Kein Treffer heißt `nil`, niemals ein Standardwert (Lehre aus #111).
- **Schwelle und Merkmalsliste an einer Stelle** — im Vorbild als `static let confidence` bzw.
  `CaseIterable`-Enum mit Schlüsselwortlisten.
- **Begründungssätze sind lokalisiert** (`String(localized:)`, `Localizable.xcstrings`, DE+EN von
  Anfang an, Lehre aus #98).
- **Messung in zwei Suites:** Logiktests laufen immer, der Bericht nur, wenn die persönliche
  Korpusdatei existiert.
- **Spec-Gliederung** liegt unter `docs/specs/enrichment/` (Vorbilder `rule-117-…`, `feat-95-…`).

## Dependencies

- **Upstream (was die neue Regel braucht):** `TaskItem.rawText` bestehender Aufgaben als
  Vergleichsmenge, deren `contexts`-Beziehungen und `durationRaw`; eine Tokenisierung + Jaccard; die
  Schwelle. Neu gegenüber allen bisherigen Regeln: sie braucht **andere Aufgaben**, also einen
  SwiftData-Fetch — der gehört in den Coordinator, damit die Regel rein bleibt.
- **Downstream (was von den gesetzten Feldern lebt):** `ViewRules` (Ansichten/Sortierung),
  `FieldCodec`/`RevisionService` (Reset per Nutzer-Revision), `TaskDetailView`/`FieldEditorView`
  (zeigen `revision.reason` und den KI-Marker), Spotlight-Index, `EnrichmentWriter` (darf dieselben
  Felder danach nicht überschreiben), `selfConsistencyValues` (#108) und
  `FocusBloxCalibrationTests`/`SelfConsistencyReportTests`, falls das Modell-Schema Felder verliert
  (Präzedenzfall: #118 als Folge-Aufräumticket zu #117).

## Existing Specs

- `docs/specs/enrichment/rule-117-importance-urgency.md` — direkte Gliederungsvorlage
- `docs/specs/enrichment/feat-95-parser-in-app.md` — derselbe Umbau für das Fälligkeitsdatum
- `docs/specs/measurement/spike-69-regel-auslasstest.md` — Spec der Messung, auf der #136 beruht
- `docs/context/spike-69-auslasstest-retrieval.md` — Kontext der Messung

## Risks & Considerations

1. **Die Schwelle 0,34 ist im Code nirgends belegt.** Sie steht nur in zwei Dokumenten
   (`02-datenmodell…:178`, `06-annahmen…:151`); `Measurement/LeaveOneOut.swift` kennt keine
   Aufschlüsselung nach Nachbar-Ähnlichkeit. Die Tabelle der B1-Entscheidung ist mit dem
   eingecheckten Code also nicht reproduzierbar — und ihre beiden Spalten sind gegenläufig definiert
   (`≥ 0,34` gegen `0 < Jaccard < 0,99`, überlappt), die Fallzahlen summieren sich nicht auf die
   Pools (Kontexte 63 + 2 gegen Pool 104 bei 19 ohne Nachbarn). **Vor der Spec nachrechnen**, sonst
   wird eine Zahl ins Produkt geschrieben, deren Herkunft niemand mehr prüfen kann.
2. **Zwei Tokenizer.** Der gemessene liegt in `Measurement/` (Tests + Labor-App), der geteilte
   (`ExpressionText`) trennt Bindestrich-Wörter anders. Produkt und Messung müssen denselben
   benutzen, sonst misst der Test etwas anderes als die App tut. Entweder umziehen oder bewusst
   abweichen **und neu messen**.
3. **Die Regel frisst ihre eigene Ausgabe.** Wird gegen *alle* Aufgaben verglichen, ist ein
   KI-gesetzter Kontext von Aufgabe A die Quelle für Aufgabe B — ein Fehler vervielfältigt sich
   still. Der Gegenvorschlag aus ADR-5/#26 (nur erledigte oder vom Nutzer korrigierte Aufgaben)
   begrenzt das, senkt aber die Abdeckung. Offene Frage 1 des Tickets.
4. **Laufzeit.** Heute O(n) je Erfassung, im Nachzügler-Lauf O(n²) über alle unverarbeiteten
   Aufgaben, plus Tokenisierung je Vergleich. Bei 287 Aufgaben irrelevant, bei einigen Tausend nicht.
   Offene Frage 2 des Tickets.
5. **Reihenfolge Regel/Modell.** Der Präzedenzfall #95 hat die Felder aus dem Modell-Schema
   entfernt. Hier greift die Regel aber nur bei ~60 % Abdeckung (wortgleiche Wiedererfassung) — ein
   vollständiger Schema-Entzug nähme neu formulierten Aufgaben Dauer und Kontexte ganz. Offene
   Frage 3 des Tickets; der bestehende `guard feld == nil` löst es ohne Schema-Änderung.
   **Korrigiert in der Analyse (Punkt 5 unter „Technischer Ansatz"):** Der letzte Halbsatz ist
   falsch. Dieser Guard sitzt in `EnrichmentCoordinator` und schützt nur die Regel gegen sich
   selbst; `EnrichmentWriter.apply` überschreibt `duration`/`contexts` ungeschützt im selben Lauf.
6. **Ein falscher Kontext ist unsichtbar** (`06-annahmen…`, Anmerkung zu A3): Die Aufgabe erscheint
   unter Garten, gesucht wird sie unter Computer, der KI-Marker steht dort, wo niemand hinsieht.
   Stilles Setzen ist von Henning entschieden — das Risiko gehört trotzdem in die Spec.
7. **Die Abdeckungszahlen stammen aus Textdubletten.** Der Korpus enthält große textgleiche Gruppen
   (43× „LinkedIn Nachrichten beantworten"); 58,7 % der Kontext- und 61,2 % der Dauer-Sätze haben
   einen Nachbarn mit Jaccard 1,0. Die entduplizierte Gegenprobe fällt unter die Konstante. Jede
   Messung in dieser Umsetzung braucht beide Lesarten, sonst liest sie halb.
8. **Alle Zahlen gelten für gepflegte Titel, nicht für Diktat** (`scripts/export-focusblox-corpus.swift`
   setzt `rawText: title`; #82/#88). Auf diktiertem Rohtext kann die Wortüberlappung schlechter
   treffen — Grenze gehört in jede Messung und in die Spec.
9. **Der Korpus fehlt in diesem Worktree.** Er liegt gitignoriert im Hauptordner. Ohne Kopie läuft
   die gegatterte Bericht-Suite nicht — und „grün ohne Korpus" heißt „Messung übersprungen", nicht
   „Messung bestanden". Vor Löschaktionen im Worktree ignorierte Dateien sichten (#135).
10. **Kontexte sind Entitäten, keine Namen.** `EnrichmentWriter` gleicht Modell-Strings gegen
    `[TaskContext]` ab; die Regel kann die `TaskContext`-Objekte des Nachbarn direkt übernehmen
    (gleicher Store) — einfacher, aber ein anderer Pfad als der bestehende, und der Revisionswert
    muss trotzdem als JSON-Namensliste kodiert werden (`EnrichmentWriter.encode`).
11. **Scope.** Neue Regel + Coordinator + evtl. Tokenizer-Umzug + Tests + zwei Dokumente + neue
    Begründungssätze DE/EN. Die 250-LoC-Grenze ist erreichbar, aber nur ohne Aufräumarbeiten am
    Modell-Schema — das wäre ein Folge-Issue nach dem Muster #118.
12. **Kleinigkeit mit Wirkung:** Der Kommentar an `EnrichmentCoordinator.examples` verspricht noch
    „Similarity-based retrieval (ADR-5, on-device embeddings) replaces recency in a later slice" —
    das ist seit dem 2026-09-27 gestrichen. Die Beispiele nach *Aktualität* sind davon nicht
    betroffen und bleiben; nur der Kommentar lügt.
13. **DoD-Punkt „#26 geschlossen" ist bereits erfüllt** — #26 ist seit der B1-Entscheidung zu.

## Analysis

### Type

Feature (Regel-Umsetzung einer bereits getroffenen Produktentscheidung, B1 vom 2026-09-27).

### Nachgerechnet: die Zahlen, auf denen das Ticket steht

Der Mechanismus aus `Measurement/LeaveOneOut.swift` (`similarityWords` + `jaccard` + `neighbors(k: 1)`)
wurde gegen `docs/reference/focusblox-corpus.json` (287 Einträge) nachgerechnet, aufgeschlüsselt nach
der Ähnlichkeit des besten Nachbarn. Ergebnis:

| Band | Kontexte (Pool 104) | Dauer (Pool 276) | Energie (Pool 211) |
|---|---|---|---|
| Jaccard = 1,0 (identische Wortmenge) | **61 von 61 = 100 %** | **169 von 169 = 100 %** | 73 von 101 = 72,3 % |
| 0,34 ≤ Jaccard < 0,99 | 2 Fälle, 2 richtig | 9 Fälle, **4 richtig = 44 %** | 10 Fälle, 6 richtig |
| 0 < Jaccard < 0,34 | 22 Fälle, 54,5 % | 70 Fälle, 44,3 % | 72 Fälle, 66,7 % |
| Konstante (häufigster Wert im Pool) | 56,7 % | 51,1 % | 77,3 % |

Die Skripte dieser Nachrechnung liegen unter `docs/artifacts/feat-136-wiedererkennung/` samt README,
damit jede Zahl oben nachprüfbar bleibt.

Die Reproduktion deckt sich mit dem eingecheckten Messbericht: Die dort genannten Abdeckungen bei
Jaccard 1,0 (58,7 % / 61,2 % / 47,9 %, `docs/reference/retrieval-leave-one-out-rules.md:83-90`)
kommen exakt heraus. Abweichung von der Tabelle in `06-annahmen-und-experimente.md:151-155`: genau
zwei Einträge bei Dauer und Energie, Ursache ist die `ß`-Behandlung — Foundations
`folding(.diacriticInsensitive, locale: de_DE)` faltet `ß` zu `ss`, die Python-Reproduktion nicht,
und der Korpus enthält genau zwei Einträge mit `ß`. Der Befund ist davon unberührt.

**Was die Tabelle in `06-annahmen-und-experimente.md:151-155` verdeckt:**

1. Ihre Spaltenbeschriftung ist irreführend. „63 von 104, 100 %" liest sich wie eine Quote von
   60,6 %; tatsächlich sind 63 die *Fälle im Band* (von Pool 104) und 100 % die Trefferquote in
   diesen 63. Die rechte Spalte ist mit „0 < Jaccard < 0,99" beschriftet, enthält aber nur das Band
   **0,34 ≤ Jaccard < 0,99** — das echte „nur teilweise ähnlich" (unter 0,34) fehlt in der Tabelle
   ganz. Es ist mit 22 bzw. 70 Fällen das weitaus größte Band und liegt bei 54,5 % bzw. 44,3 %, bei
   der Dauer also **unter** der Konstante.
2. Der gesamte gemessene Nutzen sitzt bei **identischer Wortmenge**. 173 der 287 Einträge liegen in
   nur **zehn Gruppen wörtlich identischen Rohtexts** (59× „Klavier spielen", 43× „LinkedIn
   Nachrichten beantworten", 23× „Fehlerbehebung FocusBlox", 18× „1 Blink lesen", 15× „Zehnagel
   behandel", …). Entdupliziert bleiben 124 verschiedene Texte.
3. Innerhalb dieser Gruppen sind Kontexte und Dauer **nie** widersprüchlich (daher 100 %). Bei
   Energie sind sie es in zwei Gruppen mit 49 Einträgen — das ist der Grund, warum Energie unter der
   Konstante landet, und bestätigt die Entscheidung, Energie nicht zu übernehmen.
4. **Die Schwelle 0,34 ist an Rauschen angepasst.** Sie liegt genau einen Hauch über dem höchsten
   Jaccard mit Fehlvorhersage bei den *Kontexten* (0,333); bei der Dauer liegen Fehlvorhersagen bei
   0,5 und 0,667, also darüber. Zwischen 0,34 und 0,60 liegt bei den Kontexten überhaupt kein
   Datenpunkt. Konkret kauft die Schwelle gegenüber reiner Gleichheit neun zusätzliche Dauer-Fälle,
   von denen fünf falsch sind, und senkt die Dauer-Treffsicherheit von 100 % auf 97,2 %. Gewinn:
   3,3 Prozentpunkte Abdeckung.

**Vier Vergleichsvarianten sind auf diesem Korpus nicht unterscheidbar** (je 124 Schlüssel,
Kontexte 61/61, Dauer 169/169): Wortmenge ab vier Zeichen, Wortmenge ab vier Zeichen plus alle
Zahlengruppen, Wortmenge über *alle* Wörter, ganzer normalisierter Text. Der Korpus enthält keine
Gruppe mit gleicher Wortmenge aber verschiedenem Text. Die Wahl zwischen ihnen ist also **nicht
gemessen**, sondern nur über Fehlermodi begründbar — das gehört so in die Spec.

### Technischer Ansatz

**1. Gleichheit statt Schwelle.** Die Regel verlangt **Gleichheit der normalisierten Wortmenge über
alle Wörter** statt Jaccard ≥ 0,34. Begründung:

- Auf beiden übernommenen Feldern 100 % exakt gemessen, gegen 100 %/97,2 % bei 0,34.
- Kein Schwellenwert im Code, nichts zu kalibrieren — „Regeln vor Modell" in Reinform, und wörtlich
  das, was die B1-Entscheidung „kein Lernen, sondern ein Textabgleich" verlangt.
- **Kein Vier-Zeichen-Filter.** Der existiert in `LeaveOneOut.similarityWords` nur, weil deutsche
  Funktionswörter eine *Ähnlichkeitssuche* verrauschen würden. Bei einem Gleichheitsvergleich ist er
  reiner Nachteil: er würde „Tee holen" und „Bad holen" zu derselben Menge `{holen}` machen (der
  Messbericht nennt genau diese Wörter als Grenze, `retrieval-leave-one-out-rules.md:78-79`) und
  „30 Minuten Sport" mit „60 Minuten Sport" verschmelzen. Ein falsch gesetzter Kontext ist unsichtbar
  (Risiko 6), also wird hier zugunsten der Strenge entschieden.
- Wortmenge statt ganzem String, weil das Produkt diktierten Rohtext verarbeitet (#82/#88):
  Satzzeichen, Groß/Klein und Wortstellung dürfen eine Wiedererkennung nicht verhindern.
- Der Vergleich wird ein Dictionary-Lookup (O(1) nach einmaligem Aufbau) statt eines O(n)-Scans mit
  Tokenisierung je Paar — damit ist Risiko 4 (Laufzeit) erledigt, auch bei einigen Tausend Aufgaben.

**2. Ein Tokenizer für Messung und Produkt.** Der gemessene Tokenizer (`TitleCheck.normalized`,
`TitleCheck.words(in:)`, `Measurement/Corpus.swift:238-240,278-280`) hängt nur von `Foundation` ab
und wird heute **nirgends** im Produktpfad aufgerufen (nur `Measurement/` und `LooseEndsTests/`).
Diese zwei Funktionen ziehen nach `Shared/`; `LeaveOneOut.similarityWords` und die Regel rufen
beide dieselbe Stelle auf. Damit misst der Test beweisbar, was die App tut (Risiko 2 aufgelöst).
`ExpressionText` aus `DateExpressionParser.swift:27-67` wird **nicht** genommen: identische Faltung,
aber Bindestriche trennen dort (`Mutter-Kind-Kur` → drei Wörter) und der Rückgabetyp trägt
Trennzeichen mit — das würde von der Messung abweichen. `project.yml` braucht die neue Datei in den
`LooseEndsLab`-Quellen, weil dieses Target aus `Shared/` nur einzeln benannte Dateien einbindet
(`project.yml:174-179`).

**3. Vergleichsmenge.** Der Pool wird **einmal vor der Schleife** in
`EnrichmentCoordinator.processPending()` geholt (wie `contexts`/`projects`/`examples` heute,
Zeile 43-45), und zwar aus **bereits verarbeiteten** Aufgaben (`processedAt != nil`). Damit kann eine
Aufgabe aus demselben Nachzügler-Lauf strukturell nie Quelle für eine andere sein — Risiko 3 ist
durch Konstruktion gelöst, nicht durch einen Laufzeitfilter. Kein Status-Filter auf `done`: eine
Wiedererfassung soll auch die Werte einer noch offenen Aufgabe übernehmen.
Bei mehreren Treffern gewinnt ein Nachbar, dessen Feld **nutzergesetzt** ist
(`*SourceRaw == FieldSource.user.rawValue`), vor einem KI-gesetzten; danach entscheidet die `id`,
damit die Reihenfolge nie von der Fetch-Reihenfolge abhängt. So pflanzt sich eine Nutzerkorrektur auf
alle künftigen Wiedererfassungen fort (ADR-5: „Korrekturen des Nutzers bleiben Beispiele erster
Klasse") statt ein KI-Fehler.

**4. Reine Regel, Aufrufer speichert** — wie `DueDateRule`/`ImportanceUrgencyRule`: `enum`, kein
`ModelContext`, kein Fetch. Die Regel bekommt eine Werteliste (`rawText` + Dauer + Kontextnamen +
Quelle je Feld), nicht `[TaskItem]`. Der Coordinator löst den Treffer über eine `[UUID: TaskItem]`-Map
auf und übernimmt die `TaskContext`-Objekte des Nachbarn direkt (gleicher Store) — robuster als der
Namensabgleich in `EnrichmentWriter`, weil kein Name driften kann. Konfidenz 1.0, still, KI-Marker,
`Revision` je Feld. Revisionswerte exakt wie bisher: Dauer als `DurationBucket.rawValue`, Kontexte
als JSON-Namensliste über `EnrichmentWriter.encode` (`EnrichmentWriter.swift:48,66,91-94`).

**5. Gefundene Lücke im heutigen Code, die vorher zu schließen ist.**
`EnrichmentWriter.apply` schreibt `duration` (Zeile 47-52) und `contexts` (Zeile 61-71) **ohne
`== nil`-Guard** und läuft im Coordinator **nach** `applyRules` im selben Durchlauf
(`EnrichmentCoordinator.swift:48` vor `57-59`). Sobald die neue Regel diese Felder belegt, überschreibt
das Modell sie still und hängt eine zweite Revision an dasselbe Feld. Bei Fälligkeitsdatum,
Wichtigkeit und Dringlichkeit passiert das nicht, weil diese Felder gar keinen Code mehr im
Modell-Pfad haben (#95/#117) — es ist also kein Guard, der schützt, sondern Feld-Entzug.
Die Annahme in Risiko 5 dieses Dokuments („der bestehende `guard feld == nil` löst es ohne
Schema-Änderung") ist damit **widerlegt**: dieser Guard sitzt in `EnrichmentCoordinator`
(Zeile 91/110/128) und verhindert nur die doppelte Anwendung der Regel selbst.
Kein bestehender Test deckt den Kollisionsfall ab (`EnrichmentTests.swift:262-290` prüft ihn nicht,
dort setzt der Stub-Draft das Feld gar nicht), ein Guard bricht also nichts.

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Enrichment/RecognitionRule.swift` | CREATE | Reine Regel: normalisierte Wortmenge, Gleichheitstreffer, Vorrang für nutzergesetzte Werte, Konfidenz 1.0, DE/EN-Begründungssatz (~70–90 LoC) |
| `Shared/Services/RawTextWords.swift` | CREATE | Geteilter Tokenizer (`normalized`, `words(in:)`), aus `Measurement/Corpus.swift` gezogen (~20 LoC) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | Pool-Fetch einmalig vor der Schleife, `[UUID: TaskItem]`-Map, `applyRecognitionRule`, Kommentar an `examples` korrigieren (~+35 LoC) |
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | `== nil`-Guard für `duration` und `contexts` (~+6 LoC) |
| `Measurement/Corpus.swift` + `Measurement/LeaveOneOut.swift` | MODIFY | Tokenizer-Aufrufe auf die geteilte Stelle umbiegen (~±10 LoC) |
| `project.yml` | MODIFY | Neue `Shared`-Datei in die `LooseEndsLab`-Quellen (~+1 LoC) |
| `LooseEndsTests/RecognitionRuleTests.swift` | CREATE | Regel-Tests im Stil von `ImportanceUrgencyRuleTests` + gegatterte Korpus-Suite (~100–130 LoC) |
| `LooseEndsTests/EnrichmentTests.swift` | MODIFY | Pool-Herkunft, Reihenfolge, kein Überschreiben durch das Modell, keine zweite Revision im Nachzügler-Lauf (~+50 LoC) |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | Schritt 2 der Pipeline: Mechanismus und Schwelle korrigieren (Zeile 176-183) |
| `docs/project/06-annahmen-und-experimente.md` | MODIFY | Tabelle 151-155 richtig beschriften, Band unter 0,34 ergänzen |

### Scope Assessment

- Dateien: 10 (davon 3 Dokumentation/Projektdatei) — über der Richtgröße von 4–5
- Geschätzte LoC: ~+300 / −20, davon ~180 Produktcode und ~120 Tests — über der 250-LoC-Grenze
- Risiko: **Mittel** — zwei zentrale Stellen der Veredelung (`EnrichmentCoordinator`,
  `EnrichmentWriter`), aber jede Änderung ist feld-lokal und durch einen `nil`-Guard begrenzt;
  kein Eingriff in Modell-Schema, Datenmodell oder Ansichten

### Dependencies

- **Upstream:** `TaskItem.rawText`/`contexts`/`durationRaw` + `*SourceRaw` bestehender Aufgaben,
  `processedAt` als Pool-Filter, geteilter Tokenizer
- **Downstream:** `ViewRules` (Ansichten/Sortierung), `RevisionService`/`FieldCodec` (Reset als
  Nutzer-Revision), `TaskDetailView`/`FieldEditorView` (KI-Marker und Begründung), Spotlight-Index,
  `selfConsistencyValues` (#108, nur lesend)

### Verworfene Alternativen

- **Jaccard ≥ 0,34 wie im Ticket** — gemessen schlechter bei der Dauer (97,2 % statt 100 %), Schwelle
  an einer Nachkommastelle auf 104 Fälle überangepasst, teurer zur Laufzeit.
- **Ganzer normalisierter Text als Schlüssel** — noch einfacher, auf dem Korpus gleichwertig, aber
  empfindlich gegen Satzzeichen und Wortstellung und damit schlechter auf diktiertem Rohtext.
- **Wortmenge ab vier Zeichen (wie gemessen)** — öffnet zwei Falschverschmelzungen
  („Tee holen"/„Bad holen", „30 Minuten Sport"/„60 Minuten Sport"), ohne auf dem Korpus etwas zu
  gewinnen.
- **`ExpressionText` als geteilter Tokenizer** — weicht bei Bindestrichen von der Messung ab.
- **Pool nur aus erledigten Aufgaben** (wie `examples` heute) — halbiert die Abdeckung ohne
  messbaren Gewinn; „vom Nutzer korrigiert" ist im Korpus gar nicht abgebildet, also nicht messbar.

### Open Questions

Beide vom PO entschieden (Henning, 2026-09-27) — keine offene Frage mehr:

- [x] **Neu formulierte Aufgaben: das Modell schätzt Dauer und Kontexte weiter.** Die Felder bleiben
  im Modell-Schema, die Wiedererkennung gewinnt per `nil`-Guard. Folge: `EnrichmentWriter` braucht den
  Guard aus Punkt 5, und `docs/project/02-datenmodell-und-ansichten.md:178-179` („das Modell wird für
  diese beiden Felder nicht mehr gefragt") wird korrigiert statt umgesetzt. Der vollständige
  Schema-Entzug bleibt als mögliches Folge-Issue offen — Begründung dafür wäre die gemessene
  Wertlosigkeit des Modells bei der Dauer (51 % gegen Konstante 51,1 %), nicht dieses Ticket.
- [x] **Umfang: ein Stück.** Rund 300 LoC über zehn Dateien, bewusst über der 250-LoC-Richtgröße,
  weil die Überschreitung aus Tests und zwei Dokumenten kommt. Die Korpus-Messung bleibt Teil der
  Definition of Done und wird nicht abgetrennt.

Vollständige Fassung der beiden Fragen, wie sie dem PO vorlagen:

- [x] **Bekommen neu formulierte Aufgaben weiterhin Dauer und Kontexte vom Modell?**
  `docs/project/02-datenmodell-und-ansichten.md:178-179` sagt heute „das Modell wird für diese beiden
  Felder nicht mehr gefragt" — das wäre der volle Schema-Entzug wie bei #95. Die Wiedererkennung hat
  auf neu formuliertem Text aber per Konstruktion 0 % Abdeckung: entdupliziert bleiben 124 von 287
  Texten ohne jeden Treffer. Voller Entzug heißt also, dass bei rund 40 % der Erfassungen zwei Felder
  leer bleiben. Gegenargument: Für die Dauer ist das Modell messbar wertlos — 51 % Precision
  (`docs/reference/focusblox-calibration-report.md:29-39`) gegen eine Konstante von 51,1 %; für
  Kontexte liegt keine Modellmessung vor. Empfehlung für dieses Ticket: Felder bleiben im Schema,
  die Regel gewinnt per `nil`-Guard; der Entzug wird ein Folge-Issue nach dem Muster #118.
- [x] **Bleibt das Ticket über der 250-LoC-Grenze in einem Stück?** Empfehlung: ja, weil die
  Überschreitung ausschließlich aus Tests und Dokumentation kommt und ein Aufteilen der Tests die
  Definition of Done verletzen würde.

### Erledigt, nicht mehr offen

- Offene Frage „Vergleich gegen alle oder nur erledigte/korrigierte" — entschieden, siehe Ansatz 3.
- Offene Frage „Laufzeit bei wachsendem Bestand" — entschieden, siehe Ansatz 1 (Dictionary-Lookup).
- DoD-Punkt „#26 geschlossen" — war bei der Kontextaufnahme schon erfüllt.
