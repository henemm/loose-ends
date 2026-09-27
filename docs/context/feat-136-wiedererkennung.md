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
