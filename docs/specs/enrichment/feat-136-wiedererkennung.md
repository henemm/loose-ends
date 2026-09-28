---
entity_id: feat-136-wiedererkennung
type: feature
created: 2026-09-27
updated: 2026-09-27
status: approved
workflow: feat-136-wiedererkennung
---

# Spec: #136 — Wiedererkennung bekannter Rohtexte (Folge von B1, ADR-5 neu gefasst)

## Approval

- [x] Approved (Henning, 2026-09-27)

## Purpose

Henning hat am 2026-09-27 entschieden (B1, `docs/project/06-annahmen-und-experimente.md`): Lernen ist
Wiedererkennung, nicht Training. ADR-5 ist entsprechend neu gefasst
(`docs/project/00-entscheidungen.md:94-103`) — das ursprünglich geplante Embedding-Retrieval für
Prompt-Beispiele ist gestrichen. Ein Rohtext, der schon einmal erfasst wurde, setzt stattdessen die
**Kontexte und die Dauer** des früheren Eintrags wieder: still, Konfidenz 1.0, KI-Marker, `Revision`
wie jede Anreicherung. **Energie ausdrücklich nicht** — auf keiner Lesart schlagen Nachbarn dort die
Konstante (77,3 % gegen höchstens 72,3 %), das Feld bleibt manuell (#112).

Grundlage ist Issue #131 (`docs/reference/retrieval-leave-one-out-rules.md`): auf 287 echten FocusBlox-
Aufgaben trägt reine Wortüberlappung als Nachbarsuche nur dort, wo der Rohtext fast wortgleich
wiederkehrt (Kontexte 100 %, Dauer 97,2 % bei rund 60 % Abdeckung); bei nur teilweiser Ähnlichkeit
fällt sie auf Rateniveau (55 %). Die Kontextaufnahme zu diesem Ticket
(`docs/context/feat-136-wiedererkennung.md`) hat die Zahlen, auf denen Issue #136 aufsetzt, mit zwei
Wegwerf-Skripten nachgerechnet (`docs/artifacts/feat-136-wiedererkennung/`, samt README) und dabei zwei
Fehler in der bestehenden Dokumentation gefunden (siehe „Implementation Details", Punkt 1, und die
Abschnitte, die in dieser Spec zur Korrektur von `docs/project/02-datenmodell-und-ansichten.md` und
`docs/project/06-annahmen-und-experimente.md` führen).

Diese Spec setzt „Regeln vor Modell" (CLAUDE.md, Henning 2026-09-20) wörtlich um: kein Modellaufruf,
kein zu kalibrierender Schwellenwert, ein reiner Textabgleich nach demselben Baustein-Muster wie
`DueDateRule` (#95) und `ImportanceUrgencyRule` (#117).

## Source

- **Datei:** `Shared/Enrichment/RecognitionRule.swift` (neu)
- **Bezeichner:** `enum RecognitionRule`, `static func match(rawText:in:)`
- **Datei:** `Shared/Services/RawTextWords.swift` (neu)
- **Bezeichner:** `enum RawTextWords`, `static func normalized(_:)`, `static func words(in:)`
- **Datei:** `Shared/Enrichment/EnrichmentCoordinator.swift`
- **Bezeichner:** `private func applyRules(to:recognitionPool:tasksByID:)`,
  `private func applyRecognitionRule(to:pool:tasksByID:)`,
  `private static func recognitionCandidates(in:)`

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `Shared/Enrichment/DueDateRule.swift` (#95), `ImportanceUrgencyRule.swift` (#117) | Vorbild | Dasselbe Muster: reiner Baustein ohne SwiftData, `Guess`-Rückgabe, Konfidenz 1.0, `nil` bei Nichttreffer, der Coordinator schreibt und legt die Revision an |
| `EnrichmentDraft.Guess<T>` (`Shared/Enrichment/EnrichmentDraft.swift:6-16`) | Typ | Rückgabetyp der Regel, unverändert |
| `Measurement/Corpus.swift:238-240,278-280` (`TitleCheck.normalized`, `TitleCheck.words(in:)`) | Quelle | Wandert nach `Shared/Services/RawTextWords.swift`, damit Messung und Produkt denselben Tokenizer aufrufen |
| `Measurement/LeaveOneOut.swift:20-22` (`similarityWords`) | Messcode | Ruft künftig `RawTextWords.words(in:)`/`.normalized(_:)` statt der bisherigen, jetzt entfernten Kopie in `Corpus.swift` |
| `Shared/Models/TaskItem.swift` (`rawText`, `id`, `processedAt`, `duration`/`durationSourceRaw`, `contexts`/`contextsSourceRaw`) | Modell | Datenquelle für Vergleichsmenge und Zielfelder |
| `Shared/Models/Revision.swift`, `RevisedField.duration`/`.contexts` (`Shared/Models/Enums.swift:32-34`) | Typ | Bestehen bereits, kein neuer Enum-Fall nötig |
| `FieldSource.ai`/`.user` (`Shared/Models/Enums.swift:17-19`) | Enum | Feldursprung bleibt `ai`; `.user` entscheidet den Vorrang bei mehreren Treffern |
| `EnrichmentWriter.encode(_:)` (`Shared/Enrichment/EnrichmentWriter.swift:91-94`) | Funktion | Kodiert die Kontext-Namensliste für die Revision, wie heute |
| `EnrichmentWriter.apply` (`Shared/Enrichment/EnrichmentWriter.swift:47-52,61-71`) | Downstream | Braucht einen `== nil`-Guard für `duration`/`contexts`, sonst überschreibt das Modell die Regel im selben Lauf (siehe „Implementation Details", Punkt 5) |
| `docs/reference/focusblox-corpus.json` | Messdaten | Gitignoriert, liegt nur im Hauptordner (#135) — Voraussetzung für die gegatterte Korpus-Suite |
| `#26` | Issue | War beim Start dieses Tickets bereits geschlossen (B1-Entscheidung), kein DoD-Schritt mehr nötig |

**Downstream (lesend, unverändert):** `ViewRules` (Ansichten/Sortierung nach `duration`/`contexts`),
`RevisionService`/`FieldCodec` (Reset per Nutzer-Revision), `TaskDetailView`/`FieldEditorView`
(`revision.reason`, KI-Marker), Spotlight-Index, `EnrichmentDraft.selfConsistencyValues` (#108).

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `Shared/Enrichment/RecognitionRule.swift` | CREATE | Reine Regel: Gleichheit der normalisierten Wortmenge, Vorrang für nutzergesetzte Werte, Konfidenz 1.0, ein lokalisierter Begründungssatz DE/EN (~70–90 LoC) |
| `Shared/Services/RawTextWords.swift` | CREATE | Geteilter Tokenizer (`normalized`, `words(in:)`), aus `Measurement/Corpus.swift` gezogen (~20 LoC) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | Vergleichsmenge einmalig vor der Schleife holen (analog `contexts`/`projects`/`examples`, Zeile 43-45), `applyRules(to:)` um die Regel erweitern, Kommentar an `examples` (Zeile 145-146) korrigieren (~+35 LoC) |
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | `== nil`-Guard für `duration` (Zeile 47) und `contexts` (Zeile 61) (~+6 LoC) |
| `Measurement/Corpus.swift` + `Measurement/LeaveOneOut.swift` | MODIFY | Tokenizer-Aufrufe auf `RawTextWords` umbiegen, `TitleCheck.normalized`/`.words(in:)` entfallen aus `Corpus.swift` (~±10 LoC) |
| `project.yml` | MODIFY | Neue `Shared`-Datei in die Quellen von **drei** Zielen, nicht nur `LooseEndsLab` (siehe unten) (~+3 LoC) |
| `LooseEndsTests/RecognitionRuleTests.swift` | CREATE | Regel-Tests im Stil von `ImportanceUrgencyRuleTests.swift` + gegatterte Korpus-Suite im Stil von `RuleLeaveOneOutTests.swift` (~110–140 LoC) |
| `LooseEndsTests/EnrichmentTests.swift` | MODIFY | Pool-Herkunft, Nutzervorrang, kein Überschreiben durch das Modell, keine zweite Revision im Nachzügler-Lauf (~+55 LoC) |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Ein neuer Begründungssatz DE+EN von Anfang an (wie #117, anders als #98) |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | Schritt 2 der Veredelungs-Pipeline (Zeile 173-180): Mechanismus (Gleichheit statt Schwelle 0,34) und der falsche Satz „das Modell wird für diese beiden Felder nicht mehr gefragt" korrigieren |
| `docs/project/06-annahmen-und-experimente.md` | MODIFY | Tabelle (Zeile 149-155) richtig beschriften (Fälle im Band vs. Trefferquote, fehlendes Band unter 0,34 ergänzen) |
| `docs/project/04-stand.md` | MODIFY | Ticket-DoD von #136: #136 aus der Prioritätenliste der offenen Features nehmen (Zeile 115) und den Satz „Dauer wird über Wiedererkennung geschärft" (Zeile 84-86) auf den umgesetzten Mechanismus bringen — Gleichheit des Rohtexts, nicht Ähnlichkeitsschwelle. Nur Prioritätsordnung und Verweise, kein erneutes Auflisten von Scope oder DoD (CLAUDE.md) |

**Dreizehn Dateien in zwölf Tabellenzeilen** (`Measurement/Corpus.swift` und
`Measurement/LeaveOneOut.swift` teilen sich eine Zeile, weil beide dieselbe Umstellung erfahren),
**davon fünf Dokumentation/Konfiguration ohne eigene Fachlogik** (`project.yml`,
`Localizable.xcstrings`, die drei Projektdokumente). Das liegt über der Richtgröße von 4–5 Dateien aus
CLAUDE.md. Henning hat das am 2026-09-27 ausdrücklich als „ein Stück" freigegeben
(`docs/context/feat-136-wiedererkennung.md`, „Open Questions", Punkt 2): die Überschreitung kommt aus
Tests und Dokumentation, nicht aus zusätzlicher Fachlogik, und ein Abtrennen der Korpus-Messung würde
die Definition of Done verletzen — sie bleibt Teil dieses Tickets, nicht eines Folge-Issues.

**Korrektur an der Analyse beim Lesen von `project.yml`:** Die Kontextaufnahme nennt nur
`LooseEndsLab` als Ziel, das die neue `Shared`-Datei einzeln braucht (project.yml:174-179). Beim
tatsächlichen Lesen der Datei (Pflicht-Lektüre dieser Spec) zeigt sich: `Measurement/Corpus.swift` und
`Measurement/LeaveOneOut.swift` haben heute **keinen** `import LooseEnds` — sie sind bewusst
modellfrei und werden als rohe Quelldateien in drei Ziele kompiliert, die den Ordner `Measurement`
wortwörtlich auflisten: `LooseEndsLab` (project.yml:174-176), `LooseEndsTests`
(project.yml:198-200) und `LooseEndsUITests` (project.yml:221-223). Keines der drei importiert
`Shared/Services` automatisch — `LooseEndsLab` bindet einzelne `Shared`-Dateien namentlich ein
(project.yml:177-179), `LooseEndsTests`/`LooseEndsUITests` bekommen `Shared`-Typen nur über
`@testable import LooseEnds` in einzelnen Testdateien, nicht in `Measurement/*.swift` selbst. Sobald
`LeaveOneOut.swift` `RawTextWords` aufruft, muss `Shared/Services/RawTextWords.swift` deshalb als
`path:`-Eintrag in **allen drei** Ziel-Quelllisten stehen, nicht nur in `LooseEndsLab` — sonst
kompiliert `LooseEndsTests` oder `LooseEndsUITests` nicht mehr. Kein neuer `import LooseEnds` in
`Corpus.swift`/`LeaveOneOut.swift`: das würde die Modellfreiheit dieser Dateien aufgeben und
`LooseEndsLab` bräche, weil dieses Ziel `LooseEnds` nicht als Abhängigkeit führt.

**Geschätzter Umfang:** ca. +290/−20 LoC, davon rund 180 Produktivcode (Regel, Tokenizer, Coordinator,
Writer-Guard) und rund 120 Testcode — deckungsgleich mit der Schätzung der Analyse.

## Implementation Details

### 1. Gleichheit statt Schwelle

Die Regel verlangt **Gleichheit der normalisierten Wortmenge über alle Wörter** des Rohtexts, nicht
Jaccard ≥ 0,34 wie im Ticket vorgeschlagen. Nachgerechnet in
`docs/artifacts/feat-136-wiedererkennung/` (README dort): Gleichheit trifft auf beiden übernommenen
Feldern 100 % exakt, gegen 100 %/97,2 % bei der Schwelle 0,34. Vier Gründe, warum Gleichheit gewinnt:

- Kein Schwellenwert im Code, nichts zu kalibrieren — „Regeln vor Modell" in Reinform, und wörtlich
  das, was B1 „kein Lernen, sondern ein Textabgleich" nennt.
- **Kein Vier-Zeichen-Filter**, anders als `LeaveOneOut.similarityWords`. Der Filter existiert dort nur,
  weil deutsche Funktionswörter eine *Ähnlichkeitssuche* verrauschen würden. Bei einem
  Gleichheitsvergleich ist er reiner Nachteil: er würde „Tee holen" und „Bad holen" zu derselben Menge
  `{holen}` machen (die Grenze steht so schon im Messbericht,
  `docs/reference/retrieval-leave-one-out-rules.md:78-79`) und „30 Minuten Sport" mit
  „60 Minuten Sport" verschmelzen. Ein falsch gesetzter Kontext ist unsichtbar (Risiko 1 unten), also
  wird hier zugunsten der Strenge entschieden.
- Wortmenge statt ganzem normalisierten Text, weil das Produkt diktierten Rohtext verarbeitet
  (#82/#88): Satzzeichen, Groß-/Kleinschreibung und Wortstellung dürfen eine Wiedererkennung nicht
  verhindern.
- Der Vergleich wird ein Dictionary-Lookup (O(1) nach einmaligem Aufbau der Wortmengen) statt eines
  O(n)-Scans mit Tokenisierung je Paar.

Signaturskizze:

```swift
enum RecognitionRule {
    /// Ein Gleichheitstreffer ist deterministisch da oder nicht — wie bei DueDateRule/
    /// ImportanceUrgencyRule wäre ein Zwischenwert eine erfundene Zahl.
    static let confidence = 1.0

    /// Was die Regel von einer bereits verarbeiteten Aufgabe braucht — kein `TaskItem`, damit die
    /// Regel ohne SwiftData bleibt.
    struct Candidate: Sendable {
        var id: UUID
        var rawText: String
        var duration: DurationBucket?
        var durationSourceRaw: String?
        var contextNames: [String]?
        var contextsSourceRaw: String?
    }

    /// Welcher Kandidat gewonnen hat (für die Kontext-Übernahme im Coordinator) und der Guess dazu.
    struct FieldMatch<Value: Equatable & Sendable>: Sendable {
        var sourceID: UUID
        var guess: EnrichmentDraft.Guess<Value>
    }

    struct Match: Sendable {
        var duration: FieldMatch<DurationBucket>?
        var contexts: FieldMatch<[String]>?
    }

    /// `nil`, wenn kein Kandidat dieselbe Wortmenge trägt oder keiner der beiden Werte vorhanden ist.
    static func match(rawText: String, in pool: [Candidate]) -> Match?
}
```

Ein gemeinsamer, lokalisierter Begründungssatz für beide Felder (anders als #117 mit fünf Kategorien:
hier gibt es nur einen Mechanismus, „derselbe Text wurde schon einmal erfasst"):
`String(localized: "From a raw text captured before, word for word.")`.

### 2. Ein Tokenizer für Messung und Produkt

`TitleCheck.normalized(_:)` und `TitleCheck.words(in:)` (`Measurement/Corpus.swift:238-240,278-280`)
hängen nur von `Foundation` ab und werden heute **nirgends** im Produktpfad aufgerufen. Beide Funktionen
ziehen nach `Shared/Services/RawTextWords.swift`; `LeaveOneOut.similarityWords`
(`Measurement/LeaveOneOut.swift:20-22`) und `RecognitionRule.match` rufen künftig dieselbe Stelle auf —
`similarityWords` filtert danach weiterhin auf Wörter ab vier Zeichen (dort bleibt der Filter, siehe
Punkt 1), `RecognitionRule` tut das nicht. Damit misst der Test beweisbar, was die App tut.

`ExpressionText` aus `Shared/Services/DateExpressionParser.swift:27-67` wird **nicht** als Tokenizer
genommen: `folded(_:)` faltet identisch, aber `words(in:)` trennt an Bindestrichen
(`Mutter-Kind-Kur` → drei Wörter) und der Rückgabetyp (`ExpressionWord`) trägt das Trennzeichen mit —
das würde von der nachgerechneten Messung abweichen, ohne neu gemessen zu sein.

`project.yml` braucht den neuen Pfad `Shared/Services/RawTextWords.swift` in den Quellen von
`LooseEndsLab` (Zeile 174-179, neben `EnrichmentDraft.swift`/`FoundationModelsEnricher.swift`/
`Enums.swift`), `LooseEndsTests` (Zeile 198-200) und `LooseEndsUITests` (Zeile 221-223) — Begründung
siehe „Scope", Korrektur-Absatz oben.

### 3. Vergleichsmenge

Der Pool wird **einmal vor der Schleife** in `EnrichmentCoordinator.processPending()` geholt, an
derselben Stelle wie `contexts`/`projects`/`examples` heute (`EnrichmentCoordinator.swift:43-45), und
zwar aus **bereits verarbeiteten** Aufgaben (`processedAt != nil`). Dadurch kann eine Aufgabe aus
demselben Nachzügler-Lauf strukturell nie Quelle für eine andere sein — kein Laufzeitfilter nötig, es
folgt aus der Fetch-Reihenfolge selbst. Kein Status-Filter auf `done`: eine Wiedererfassung soll auch
die Werte einer noch offenen Aufgabe übernehmen (anders als `examples`, das nur erledigte Aufgaben
liefert, `EnrichmentCoordinator.swift:147-165`).

**Nachgezogen mit #144:** `processedAt` allein war das falsche Lesekriterium — der Vermerk wird nur
in `EnrichmentWriter.apply` gesetzt, also ausschließlich nach einem geglückten Modelllauf. Ohne
Apple Intelligence (Simulator, nicht berechtigtes Gerät, abgeschaltete Funktion) und bei einem
fehlgeschlagenen Modellaufruf blieb die Vergleichsmenge dauerhaft leer, und ein Regelmechanismus,
der ausdrücklich kein Modell braucht, griff faktisch nie. Seit #144 trägt der Regelschritt seinen
eigenen Vermerk `rulesAppliedAt` (gesetzt in `processPending()` direkt nach `applyRules`, außerhalb
des Modellblocks und außerhalb von dessen `try`/`catch`), und `recognitionInputs(in:)` liest die
Vergleichsmenge über **zwei** `FetchDescriptor` — `processedAt != nil` und `rulesAppliedAt != nil` —
zusammengeführt per `id` mit `uniquingKeysWith: { first, _ in first }`. Kein `#Predicate` mit `||`:
ein solches existiert nirgends im Projekt, und ob SwiftData es gegen den CloudKit-Store korrekt
übersetzt, ist unbelegt. Die Zusammenführung hält Aufgaben erreichbar, die vor #144 veredelt wurden
(`processedAt != nil`, `rulesAppliedAt == nil`), und entdoppelt Aufgaben mit beiden Vermerken.

```swift
private static func recognitionCandidates(from tasks: [TaskItem]) -> [RecognitionRule.Candidate] {
    tasks.map { task in
        RecognitionRule.Candidate(
            id: task.id,
            rawText: task.rawText,
            duration: task.duration,
            durationSourceRaw: task.durationSourceRaw,
            contextNames: task.contexts.map { $0.map(\.name) },
            contextsSourceRaw: task.contextsSourceRaw
        )
    }
}
```

Bei mehreren gleichwertigen Kandidaten (identische Wortmenge) gewinnt je Feld getrennt ein Kandidat,
dessen Feld **nutzergesetzt** ist (`durationSourceRaw`/`contextsSourceRaw ==
FieldSource.user.rawValue`), vor einem KI-gesetzten; danach entscheidet aufsteigend `id.uuidString`,
damit die Reihenfolge nie von der Fetch-Reihenfolge abhängt. So pflanzt sich eine Nutzerkorrektur auf
alle künftigen Wiedererfassungen fort (ADR-5: „Korrekturen des Nutzers bleiben Beispiele erster
Klasse") statt eines KI-Fehlers.

### 4. Reine Regel, Aufrufer speichert

Wie `DueDateRule`/`ImportanceUrgencyRule`: `enum`, kein `ModelContext`, kein Fetch. Die Regel bekommt
eine Werteliste (`Candidate`), nicht `[TaskItem]`. Der Coordinator löst den Treffer über eine
`[UUID: TaskItem]`-Map auf und übernimmt bei Kontexten die `TaskContext`-Objekte des Nachbarn direkt
(gleicher Store) — robuster als der Namensabgleich in `EnrichmentWriter`, weil kein Name driften kann.

```swift
private func applyRecognitionRule(
    to task: TaskItem, pool: [RecognitionRule.Candidate], tasksByID: [UUID: TaskItem]
) {
    guard let match = RecognitionRule.match(rawText: task.rawText, in: pool) else { return }

    if task.duration == nil, let hit = match.duration {
        task.revisions = (task.revisions ?? []) + [Revision(
            task: task, field: .duration, oldValue: nil, newValue: hit.guess.value.rawValue,
            author: .ai, reason: hit.guess.reason)]
        task.duration = hit.guess.value
        task.durationSourceRaw = FieldSource.ai.rawValue
        task.durationConfidence = hit.guess.confidence
    }

    if task.contexts == nil, let hit = match.contexts, let source = tasksByID[hit.sourceID] {
        task.revisions = (task.revisions ?? []) + [Revision(
            task: task, field: .contexts, oldValue: nil,
            newValue: EnrichmentWriter.encode(hit.guess.value), author: .ai, reason: hit.guess.reason)]
        task.contexts = source.contexts
        task.contextsSourceRaw = FieldSource.ai.rawValue
        task.contextsConfidence = hit.guess.confidence
    }
}
```

Konfidenz 1.0, still, KI-Marker, eine `Revision` je getroffenem Feld — Revisionswerte exakt wie
bisher: Dauer als `DurationBucket.rawValue`, Kontexte als JSON-Namensliste über
`EnrichmentWriter.encode` (`EnrichmentWriter.swift:91-94`). `applyRules(to:)`
(`EnrichmentCoordinator.swift:84-88`) ruft `applyRecognitionRule` als vierten, unabhängigen Schritt
neben `applyDueDateRule`/`applyImportanceRule`/`applyUrgencyRule` auf und bekommt dafür die zusätzlichen
Parameter `recognitionPool`/`tasksByID` durchgereicht. `processedAt` bleibt unberührt, aus demselben
Grund wie bei den anderen Regeln (ADR-4: der Marker bedeutet „das Modell hat die Aufgabe gesehen").

Der Docstring an `EnrichmentCoordinator.examples` (Zeile 145-146: „Similarity-based retrieval (ADR-5,
on-device embeddings) replaces recency in a later slice") wird korrigiert — dieses Versprechen ist seit
der B1-Entscheidung vom 2026-09-27 gestrichen. Die Beispiele nach *Aktualität* selbst bleiben
unverändert, nur der Kommentar lügt.

### 5. Gefundene Lücke im heutigen Code, die vorher zu schließen ist

`EnrichmentWriter.apply` schreibt `duration` (`EnrichmentWriter.swift:47-52`) und `contexts`
(`EnrichmentWriter.swift:61-71`) **ohne `== nil`-Guard** und läuft im Coordinator **nach**
`applyRules` im selben Durchlauf (`EnrichmentCoordinator.swift:48` vor `57-59`). Sobald
`RecognitionRule` diese Felder belegt, würde das Modell sie still überschreiben und eine zweite
Revision an dasselbe Feld hängen. Bei Fälligkeitsdatum, Wichtigkeit und Dringlichkeit passiert das
nicht, weil diese Felder im Modell-Pfad seit #95/#117 gar keinen Code mehr haben — dort schützt
Feld-Entzug, kein Guard. Für `duration`/`contexts` bleiben die Felder im Modell-Schema (siehe PO-
Entscheidung unten), also braucht es hier tatsächlich einen Guard:

```swift
if let duration = draft.duration, duration.confidence >= threshold, task.duration == nil {
    …
}
…
if let contexts = draft.contexts, contexts.confidence >= threshold, task.contexts == nil {
    …
}
```

Kein bestehender Test deckt den Kollisionsfall ab (`EnrichmentTests.swift:40-133` prüft `apply`
gegen leere Task-Felder, nie gegen bereits gesetzte); der Guard bricht also keinen bestehenden Test.

**PO-Entscheidung (Henning, 2026-09-27):** Neu formulierte Aufgaben bekommen Dauer und Kontexte
weiterhin vom Modell geschätzt. Die Felder bleiben im `ModelEnrichment`-Schema, die Wiedererkennung
gewinnt per `nil`-Guard in `EnrichmentCoordinator` (Regel läuft vor dem Modellaufruf) und jetzt auch in
`EnrichmentWriter` (Modell überschreibt die Regel nicht mehr). Der vollständige Schema-Entzug
(nach dem Muster #95/#117) bleibt ein mögliches Folge-Issue — Begründung dafür wäre die gemessene
Wertlosigkeit des Modells bei der Dauer (51 % Precision gegen eine Konstante von 51,1 %,
`docs/reference/focusblox-calibration-report.md:29-39`), nicht dieses Ticket. Der Satz „das Modell
wird für diese beiden Felder nicht mehr gefragt" in
`docs/project/02-datenmodell-und-ansichten.md:178-179` ist damit falsch und wird korrigiert statt
umgesetzt.

## Test Plan

### Automated Tests (TDD RED)

**Neu — `LooseEndsTests/RecognitionRuleTests.swift`**

- GIVEN zwei Kandidaten mit demselben Rohtext bis auf Groß-/Kleinschreibung, Satzzeichen und
  Wortstellung („LinkedIn Nachrichten beantworten." vs. „nachrichten linkedin beantworten") und
  Dauer/Kontexte am zweiten Kandidaten / WHEN `RecognitionRule.match(rawText:in:)` mit dem ersten Text
  läuft / THEN liefert er `duration` und `contexts` je mit Konfidenz 1.0 und nicht-leerem Grundsatz
  (AC-1, AC-3).
- GIVEN ein Kandidat mit anderem Rohtext ohne gemeinsame Wortmenge / WHEN `match` läuft / THEN liefert
  er `nil` (AC-2).
- GIVEN „Tee holen" als Ziel und „Bad holen" als einziger Kandidat mit gesetzter Dauer / WHEN `match`
  läuft / THEN liefert er `nil` — kein Vier-Zeichen-Filter verschmilzt beide zu `{holen}` (AC-4).
- GIVEN „30 Minuten Sport" als Ziel und „60 Minuten Sport" als einziger Kandidat mit gesetzter Dauer /
  WHEN `match` läuft / THEN liefert er `nil`, aus demselben Grund (AC-4).
- GIVEN ein Kandidat mit gesetzter Energie, aber `Match`/`RecognitionRule.Candidate` ohne
  Energie-Eigenschaft überhaupt / WHEN der Typ gelesen wird / THEN structural: `RecognitionRule.Match`
  besitzt kein Energiefeld — die Regel kann Energie gar nicht setzen (AC-5).
- GIVEN zwei Kandidaten mit identischer Wortmenge, einer mit `durationSourceRaw == "user"`, der andere
  mit `"ai"` und einer anderen Dauer / WHEN `match` läuft / THEN gewinnt der nutzergesetzte Wert,
  unabhängig von der Reihenfolge im Pool (AC-6).
- GIVEN zwei Kandidaten mit identischer Wortmenge, beide `durationSourceRaw == "ai"`, unterschiedliche
  `id` / WHEN `match` zweimal mit vertauschter Pool-Reihenfolge läuft / THEN gewinnt beide Male
  derselbe Kandidat (aufsteigend nach `id.uuidString`) (AC-6).
- GIVEN ein leerer Pool / WHEN `match` läuft / THEN liefert er `nil`, kein Absturz.
- GIVEN ein Rohtext ohne ein einziges Wort (z. B. nur Satzzeichen) / WHEN `match` läuft / THEN liefert
  er `nil`, statt jeden anderen leeren Rohtext zu treffen.
- GIVEN derselbe Text (z. B. „Mutter-Kind-Kur beantragen, 30 Minuten") / WHEN einmal
  `RawTextWords.words(in:)` direkt und einmal über den Pfad aufgerufen wird, den
  `Measurement/LeaveOneOut.similarityWords` benutzt (vor dessen Vier-Zeichen-Filter) / THEN sind beide
  Basiswortmengen identisch — Messung und Produkt zerlegen denselben Text gleich, es gibt keinen
  zweiten Tokenizer (AC-10).
- GIVEN `Measurement/Corpus.swift` nach dem Umzug / WHEN der Quelltext geprüft wird / THEN existieren
  `TitleCheck.normalized(_:)` und `TitleCheck.words(in:)` dort nicht mehr als eigene Fassungen —
  strukturelle Garantie gegen ein Auseinanderdriften der beiden Zerlegungen (AC-10).
- Test analog `DueDateRuleTests.reasonsAreTranslatedToGerman()`/
  `ImportanceUrgencyRuleTests.reasonsAreTranslatedToGerman()`: GIVEN der neue Begründungssatz / WHEN im
  gebauten `de.lproj`-Bundle nachgeschlagen / THEN hat er eine deutsche Übersetzung, fällt nicht auf den
  englischen Schlüsseltext zurück (AC-11).

**Neu — gegatterte Korpus-Suite in `LooseEndsTests/RecognitionRuleTests.swift`, Muster
`RuleLeaveOneOutTests.swift`/`RuleLeaveOneOutReportTests`:**

- `@Suite(.enabled(if: FileManager.default.fileExists(atPath: focusBloxTruthURL.path)))`: läuft nur mit
  der gitignorierten `docs/reference/focusblox-corpus.json` im Worktree, nicht in CI.
- GIVEN der volle Korpus (287 Aufgaben) als Pool, `RecognitionRule.Candidate` daraus gebaut / WHEN jede
  Aufgabe gegen den Pool ohne sich selbst geprüft wird / THEN trifft die Regel bei Kontexten 61 von 104
  Aufgaben mit Kontext-Wahrheit (100 % der Treffer), bei Dauer 169 von 276 (100 % der Treffer) — dieselben
  Zahlen wie in der Nachrechnung (`docs/artifacts/feat-136-wiedererkennung/`) (AC-12, erste Lesart).
- GIVEN dieselbe Rechnung auf dem **entduplizierten** Pool (ein Vertreter je textgleicher Gruppe, wie in
  `RuleLeaveOneOutReportTests.deduplicated(_:)`) / WHEN geprüft wird / THEN liefert die Regel für
  praktisch keine Aufgabe einen Treffer (0 oder nahe 0, weil Deduplizierung per Definition keine zwei
  Einträge mit identischer Wortmenge mehr übrig lässt) — der Beleg dafür, dass der Mechanismus
  Wiedererkennung ist, keine Ähnlichkeitsaussage für neu formulierten Text (AC-12, zweite Lesart).
- Die Suite trägt am Testfall den Vermerk, dass alle Zahlen für gepflegte Titel aus dem
  FocusBlox-Export gelten, nicht für diktierten Rohtext (#82/#88) — die Grenze, die das Ticket in
  jede Messung verlangt (AC-12).
- Beide Zahlen werden über `#expect` geprüft, nicht in eine neue Markdown-Datei geschrieben — anders als
  `RuleLeaveOneOutReportTests`, das einen Bericht erzeugt: hier ergänzen die Zahlen den bestehenden
  Bericht (siehe „Definition of Done"), es entsteht keine zweite Berichtsdatei.

**Geändert — `LooseEndsTests/EnrichmentTests.swift`**

- Neuer Fall in `EnrichmentCoordinatorTests`: GIVEN eine bereits verarbeitete Aufgabe
  (`processedAt != nil`) mit Dauer und Kontexten sowie eine neu erfasste Aufgabe mit demselben Rohtext /
  WHEN `processPending()` läuft / THEN übernimmt die neue Aufgabe Dauer und Kontexte der alten, mit
  `durationSourceRaw == "ai"`, `contextsSourceRaw == "ai"`, Konfidenz 1.0, je einer `Revision`
  (`author == .ai`) (AC-1).
- Neuer Fall: GIVEN zwei unverarbeitete Aufgaben mit identischem Rohtext im selben Nachzügler-Lauf,
  keine dritte, bereits verarbeitete Aufgabe im Store / WHEN `processPending()` läuft / THEN setzt
  keine der beiden Dauer oder Kontexte bei der anderen — der Pool enthält nur `processedAt != nil`
  (AC-7).
- Neuer Fall: GIVEN eine bereits verarbeitete Aufgabe mit vom Nutzer korrigierter Dauer
  (`durationSourceRaw == "user"`) und eine zweite, ebenfalls verarbeitete Aufgabe mit gleichem Rohtext
  und KI-gesetzter, abweichender Dauer / WHEN eine dritte, neue Aufgabe mit demselben Rohtext verarbeitet
  wird / THEN übernimmt sie die vom Nutzer gesetzte Dauer, nicht die KI-gesetzte (AC-6).
- Neuer Fall: GIVEN eine Aufgabe, deren Dauer/Kontexte bereits durch die Regel gesetzt sind
  (`processedAt == nil`, Regel bereits gelaufen) / WHEN `processPending()` erneut läuft (z. B. weil das
  Modell jetzt verfügbar wird) / THEN entsteht keine zweite `.duration`-/`.contexts`-Revision und die
  Werte bleiben unverändert (AC-8).
- Neuer Fall: GIVEN ein `StubEnricher`, dessen `EnrichmentDraft` sowohl `duration` als auch `contexts`
  mit ausreichender Konfidenz liefert, UND eine Aufgabe, deren `duration`/`contexts` bereits durch die
  Regel gesetzt wurden / WHEN `EnrichmentWriter.apply` mit diesem Draft läuft / THEN überschreibt der
  Modellwert die Regelwerte nicht, und es entsteht keine zweite Revision auf dasselbe Feld (AC-9) — das
  ist der Test, der die in „Implementation Details", Punkt 5 gefundene Lücke schließt.
- Neuer Fall in `EnrichmentWriterTests`: GIVEN ein Draft mit `duration`/`contexts` über der Schwelle UND
  ein `TaskItem`, dessen `duration`/`contexts` bereits gesetzt sind (unabhängig von der Regel, z. B. vom
  Nutzer) / WHEN `EnrichmentWriter.apply` läuft / THEN bleiben beide Felder unverändert, `written`
  zählt sie nicht mit (AC-9, isolierter Test ohne Coordinator).

Kein neuer UI-Test: Es entsteht keine neue View und kein neues UI-Element.
`TaskDetailView.swift`/`FieldEditorView.swift` zeigen `revision.reason` bereits heute an — der
Regelsatz durchläuft denselben, ungeänderten Anzeigepfad. Das Projekt schreibt UI-Tests erst nach dem
Design-Freeze und nur als Smoke-Tests (CLAUDE.md).

## Acceptance Criteria

- **AC-1 Gleichheitstreffer setzt beide Felder:** Given eine bereits verarbeitete Aufgabe mit Dauer und
  Kontexten und eine neue Aufgabe mit derselben normalisierten Wortmenge im Rohtext / When
  `EnrichmentCoordinator.processPending()` läuft / Then trägt die neue Aufgabe dieselbe Dauer und
  dieselben Kontext-Objekte, `durationSourceRaw == "ai"`, `contextsSourceRaw == "ai"`, Konfidenz 1.0 und
  je eine `Revision` mit `author == .ai`.
- **AC-2 Unterschiedlicher Text setzt nichts:** Given zwei Aufgaben ohne gemeinsame normalisierte
  Wortmenge / When `RecognitionRule.match(rawText:in:)` läuft / Then liefert er `nil`, kein Feld wird
  gesetzt.
- **AC-3 Normalisierung ist unempfindlich gegen Schreibweise:** Given zwei Rohtexte, die sich nur in
  Groß-/Kleinschreibung, Satzzeichen und Wortstellung unterscheiden / When `match` läuft / Then gilt das
  als Gleichheitstreffer.
- **AC-4 Kein Vier-Zeichen-Verschmelzen:** Given die Rohtext-Paare „Tee holen"/„Bad holen" und
  „30 Minuten Sport"/„60 Minuten Sport" / When `match` je Paar läuft / Then liefert er `nil` — die
  beiden Sätze bleiben trotz Teilüberlappung getrennt.
- **AC-5 Energie bleibt unberührt:** Given `RecognitionRule.Match` als Typ / When er auf seine
  Eigenschaften geprüft wird / Then besitzt er kein Energiefeld — die Regel kann Energie strukturell
  nicht setzen, unabhängig von den Testdaten.
- **AC-6 Vorrang nutzergesetzter Werte:** Given zwei gleichwertige Kandidaten mit widersprüchlichem Wert
  für dasselbe Feld, einer nutzergesetzt / When `match` läuft / Then gewinnt der nutzergesetzte Wert,
  unabhängig von der Pool-Reihenfolge; bei zwei KI-gesetzten Werten gewinnt deterministisch derselbe
  Kandidat (aufsteigend nach `id`).
- **AC-7 Pool enthält nur Aufgaben, deren Regelschritt bereits lief** (umformuliert mit #144, vorher
  „nur bereits verarbeitete Aufgaben"): Given zwei Aufgaben mit identischem Rohtext, deren
  Regelschritt noch nicht lief (`rulesAppliedAt == nil`, `processedAt == nil`), im selben
  Nachzügler-Lauf und ohne eine dritte bereits verarbeitete Aufgabe / When `processPending()` läuft /
  Then setzt keine der beiden Aufgaben Dauer oder Kontexte bei der anderen. Die Garantie folgt
  unverändert aus dem **Zeitpunkt des Fetches** (Pool einmal vor der Schleife), nicht aus dem
  Feldnamen: Im selben Durchgang trägt keine der beiden einen der beiden Vermerke. Ab dem zweiten
  Durchgang kann eine Aufgabe mit `rulesAppliedAt != nil` Quelle sein — das ist kein aufgeweichter
  Schutz, denn ohne Modell können Dauer und Kontexte nur aus einer Nutzereingabe oder aus der
  Wiedererkennung selbst stammen (das Saatkorn ist immer ein Nutzerwert, und `RecognitionRule.winner`
  bevorzugt nutzergesetzte Werte), und ein Selbsttreffer ist durch die Guards `Feld == nil` und
  `!EnrichmentWriter.userHasTouched(…)` wirkungslos.
- **AC-8 Keine doppelte Revision im Nachzügler-Lauf:** Given eine Aufgabe, deren Dauer/Kontexte bereits
  durch die Regel gesetzt sind / When `processPending()` erneut läuft / Then entstehen keine zweiten
  `.duration`-/`.contexts`-Revisionen, die Werte bleiben unverändert.
- **AC-9 `EnrichmentWriter` überschreibt die Regelwerte nicht mehr:** Given ein Modell-Draft mit
  `duration`/`contexts` über der Konfidenzschwelle UND eine Aufgabe, deren `duration`/`contexts` bereits
  gesetzt sind / When `EnrichmentWriter.apply` läuft / Then bleiben beide Felder unverändert, keine
  zweite Revision entsteht.
- **AC-10 Tokenizer ist geteilt:** Given `RawTextWords.normalized(_:)`/`.words(in:)` in
  `Shared/Services/` / When `Measurement/LeaveOneOut.similarityWords` und
  `RecognitionRule.match` beide aufgerufen werden / Then rufen beide dieselbe Funktion auf — geprüft
  über einen Test, der beide Aufrufe mit demselben Text vergleicht und identische Basiswortmengen
  erwartet (vor dem Vier-Zeichen-Filter von `similarityWords`).
- **AC-11 Lokalisierung von Anfang an:** Given der neue Begründungssatz in `Localizable.xcstrings` /
  When im gebauten `de.lproj`-Bundle nachgeschlagen wird / Then hat er eine deutsche Übersetzung, fällt
  nicht auf den englischen Schlüsseltext zurück.
- **AC-12 Korpus-Messung mit beiden Lesarten:** Given `docs/reference/focusblox-corpus.json` im
  Worktree / When die gegatterte Korpus-Suite läuft / Then bestätigt sie auf dem vollen Pool 61/104
  Kontext- und 169/276 Dauer-Treffer bei 100 % Trefferquote, und auf dem entduplizierten Pool nahe null
  Treffer — beide Zahlen im Testergebnis sichtbar, nicht nur die günstigere. Ohne die Datei ist die
  Suite deaktiviert; „grün ohne Korpus" bedeutet „Messung übersprungen", nicht „bestanden". Und: die
  Suite trägt am Testfall den Vermerk, dass alle Zahlen für gepflegte Titel aus dem FocusBlox-Export
  gelten, nicht für diktierten Rohtext (#82/#88) — die Grenze, die das Ticket ausdrücklich in jede
  Messung verlangt.

## Risiken

1. **Ein falscher Kontext ist unsichtbar.** Die Aufgabe erscheint unter Garten, gesucht wird sie unter
   Computer, der KI-Marker steht dort, wo niemand hinsieht (`docs/project/06-annahmen-und-experimente.md`,
   Anmerkung zu A3). Gegenmaßnahme: stilles Setzen ist von Henning ausdrücklich entschieden (B1);
   Gleichheit statt Schwelle senkt die Falsch-Treffer-Rate messbar auf 0 % auf diesem Korpus, aber das
   Risiko bleibt strukturell — kein automatisierter Test kann eine inhaltlich falsche Wiedererkennung
   auf neuem, unbekanntem Text ausschließen.
2. **Die Zahlen gelten für gepflegte Titel, nicht für diktierten Rohtext** (#82/#88, weil
   `scripts/export-focusblox-corpus.swift` `rawText: title` setzt). Gegenmaßnahme: AC-12 verlangt
   ausdrücklich, dass die Korpus-Suite diese Grenze als Kommentar am Testfall trägt, damit die Zahlen
   nie als Aussage über die Güte auf Diktat gelesen werden. Wie gut die Wiedererkennung auf
   diktiertem Rohtext trifft, ist mit dem heutigen Korpus **nicht messbar** — die Regel ist dort
   strenger, nicht schwächer (Gleichheit statt Ähnlichkeit), sie trifft also im Zweifel gar nicht,
   statt falsch zu treffen.
3. **Der Korpus fehlt in diesem Worktree** — er liegt gitignoriert nur im Hauptordner. Gegenmaßnahme:
   Kopie vor dem Testlauf, die Suite ist per `.enabled(if:)` gegattert, „grün ohne Korpus" ≠ „Messung
   bestanden" (AC-12); vor Löschaktionen im Worktree ignorierte Dateien sichten (#135).
4. **Scope über der Richtgröße** (11 Dateien statt 4–5, ~290 LoC statt ±250). Gegenmaßnahme: PO-
   Entscheidung vom 2026-09-27, „ein Stück" — die Überschreitung kommt aus Tests und Dokumentation, ein
   Abtrennen würde die Definition of Done verletzen.
5. **Die Regel könnte ihre eigene Ausgabe wiederkäuen** (ein KI-gesetzter Wert einer Aufgabe wird zur
   Quelle für die nächste, ein Fehler vervielfältigt sich). Gegenmaßnahme: durch Konstruktion
   ausgeschlossen — der Pool besteht nur aus `processedAt != nil`-Aufgaben, eine Aufgabe im selben
   Nachzügler-Lauf kann strukturell nie sich selbst oder eine andere Aufgabe desselben Laufs speisen.
6. **Laufzeit bei wachsendem Bestand.** Gegenmaßnahme: Wortmengen-Gleichheit ist ein Dictionary-Lookup
   nach einmaligem Aufbau (O(1) je Vergleich), kein O(n)-Scan mit Tokenisierung je Paar.
7. **Der Kommentar an `EnrichmentCoordinator.examples` verspricht noch das gestrichene
   Embedding-Retrieval.** Gegenmaßnahme: als Teil dieses Tickets korrigiert (siehe „Implementation
   Details", Punkt 4).
8. **`project.yml` bricht, wenn die neue Datei nur in einem statt drei Zielen eingetragen wird**
   (`LooseEndsTests`/`LooseEndsUITests` kompilieren `Measurement/` ebenfalls als rohe Quelle).
   Gegenmaßnahme: alle drei Ziele in derselben Änderung eingetragen (siehe „Scope",
   Korrektur-Absatz), `./scripts/sim.sh build` für alle betroffenen Ziele vor dem Zusammenführen.

## Alternativen

- **Jaccard ≥ 0,34 wie im Ticket:** verworfen. Gemessen schlechter bei der Dauer (97,2 % statt 100 %),
  die Schwelle ist an einer Nachkommastelle auf 104 Fälle überangepasst (genau über dem höchsten
  Jaccard mit Fehlvorhersage bei Kontexten, 0,333) und teurer zur Laufzeit (Jaccard über alle Paare
  statt Dictionary-Lookup). Kippt keine bestehende Entscheidung — das Ticket selbst ist kein ADR,
  sondern der Ausgangsvorschlag, den diese Spec verfeinert.
- **Ganzer normalisierter Text als Schlüssel** (statt Wortmenge): noch einfacher, auf dem Korpus
  gleichwertig (124 Schlüssel, dieselben Trefferquoten), aber empfindlich gegen Satzzeichen und
  Wortstellung und damit schlechter auf diktiertem Rohtext (#82/#88). Kippt keine bestehende
  Entscheidung.
- **Wortmenge ab vier Zeichen** (wie in `LeaveOneOut.similarityWords` gemessen): öffnet zwei
  Falschverschmelzungen („Tee holen"/„Bad holen", „30 Minuten Sport"/„60 Minuten Sport"), ohne auf dem
  Korpus etwas zu gewinnen (dieselben 124 Schlüssel wie bei Gleichheit über alle Wörter). Kippt keine
  bestehende Entscheidung.
- **`ExpressionText` als geteilter Tokenizer** (statt eines neuen `RawTextWords`): würde eine zweite
  Datei sparen, weicht aber bei Bindestrich-Wörtern von der nachgerechneten Messung ab und wäre damit
  ungemessen. Kippt keine bestehende Entscheidung.
- **Pool nur aus erledigten oder vom Nutzer korrigierten Aufgaben** (wie `examples` heute, oder der
  Gegenvorschlag aus dem ursprünglichen #26): halbiert die Abdeckung ohne messbaren Gewinn — „vom
  Nutzer korrigiert" ist im Korpus gar nicht abgebildet, also auf dieser Datenbasis nicht mess- oder
  widerlegbar. Würde die in dieser Spec getroffene Entscheidung „Pool = alle bereits verarbeiteten
  Aufgaben" ersetzen; nur infrage, falls Henning das ausdrücklich revidiert.

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt, belegt durch die im Test Plan genannten Tests
- [ ] `./scripts/sim.sh unit` grün nach Regel, Tokenizer-Umzug, Coordinator-Umbau und Writer-Guard
- [ ] Build erfolgreich (`./scripts/sim.sh build` ohne Errors) für `LooseEnds`, `LooseEndsWatch`,
      `LooseEndsWidgets`, `LooseEndsShare`, `LooseEndsLab`, `LooseEndsTests`, `LooseEndsUITests` —
      alle sieben Ziele, weil `project.yml` in drei von ihnen geändert wird (siehe „Scope")
- [ ] Drei Abnahmestufen durchlaufen: Tests → Simulator → Hennings iPhone 16 Pro
      (`./scripts/sim.sh device`) — kein Schritt entfällt, TestFlight ist kein Ersatz dafür
- [ ] Korpus-Messung durchgeführt (nicht nur gegattert übersprungen): beide Lesarten (voller Pool,
      entduplizierter Pool) im Testlauf sichtbar bestätigt, mit der lokalen Kopie von
      `docs/reference/focusblox-corpus.json`
- [ ] `docs/project/02-datenmodell-und-ansichten.md` (Schritt 2 der Pipeline, Zeile 173-180):
      Mechanismus auf Gleichheit statt Schwelle 0,34 korrigiert, der Satz „das Modell wird für diese
      beiden Felder nicht mehr gefragt" entfernt
- [ ] `docs/project/06-annahmen-und-experimente.md` (Tabelle, Zeile 149-155): Spaltenbeschriftung
      korrigiert (Fälle im Band vs. Trefferquote), das fehlende Band unter 0,34 ergänzt
- [ ] `docs/project/04-stand.md` aktualisiert (ausdrücklicher DoD-Punkt aus Issue #136): #136 aus der
      Prioritätenliste der offenen Features entfernt (Zeile 115), der Satz „Dauer wird über
      Wiedererkennung geschärft" (Zeile 84-86) auf den umgesetzten Mechanismus gebracht — Gleichheit
      des Rohtexts statt Ähnlichkeitsschwelle
- [ ] Kommentar an `EnrichmentCoordinator.examples` korrigiert (kein Verweis mehr auf das gestrichene
      Embedding-Retrieval)
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
      (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] PR schließt #136 (`Closes #136`) — #26 ist bereits geschlossen (B1-Entscheidung), kein
      zusätzlicher Schritt nötig
- [ ] Nutzerkorrekturen sind gegen Wiederbefüllung geschützt (Befund F002 der Adversary-Prüfung,
      Changelog 2026-09-27): ein per `RevisionService`-Reset geleertes Feld wird im nächsten
      Nachzügler-Lauf nicht wieder gesetzt — belegt durch die Regressionstests „Eine vom Nutzer
      zurückgesetzte Dauer wird nicht wieder gesetzt" und „Vom Nutzer entfernte Kontexte werden nicht
      wieder gesetzt", je für `duration` und `contexts`. Dieser Schutz ist keine der zwölf Acceptance
      Criteria und wäre über „AC-1 bis AC-12 erfüllt" allein nicht mitgeprüft (Befund des zweiten
      unabhängigen PO-Briefings) — deshalb steht er hier als eigener Punkt.
- [ ] Kein manueller Testhinweis an Henning — jede Acceptance Criterion ist automatisiert bewiesen
- [ ] CI grün

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Die Änderung setzt das bereits am 2026-09-27 neu gefasste ADR-5
  (`docs/project/00-entscheidungen.md:94-103`, „Lernen ist Wiedererkennung, kein Training") in Code um,
  führt aber keinen neuen Architekturbaustein ein, der eine eigene Nummer rechtfertigt.
  `RecognitionRule` ist ein weiterer reiner Baustein neben `DueDateRule` (#95) und
  `ImportanceUrgencyRule` (#117) — gleiches Muster: `enum`, `Guess`-Rückgabe, Konfidenz 1.0, der
  Coordinator schreibt und legt die Revision an. Die zugrunde liegende Produktentscheidung „Regeln vor
  Modell" ist bereits als projektweite Arbeitsregel in `CLAUDE.md` geführt, nicht als Einzel-ADR
  (dieselbe Begründung wie in `docs/specs/enrichment/feat-95-parser-in-app.md` und
  `docs/specs/enrichment/rule-117-importance-urgency.md`). Diese Spec setzt die Regel für Dauer und
  Kontexte um, wie #95 sie für das Fälligkeitsdatum und #117 sie für Wichtigkeit/Dringlichkeit umgesetzt
  haben.

## Changelog

- 2026-09-27: Spec aus der Analyse (Phase 2, #136, Folge der B1-Entscheidung) erstellt.
- 2026-09-27: `docs/project/04-stand.md` als betroffene Datei und als Punkt der Definition of Done
  ergänzt — der Ticket-DoD von #136 verlangt ihn ausdrücklich, die erste Fassung der Spec hat ihn
  übergangen (Befund des unabhängigen PO-Briefings).
- 2026-09-27: Dateizählung im Scope-Absatz korrigiert — die Tabelle listet dreizehn Dateien in zwölf
  Zeilen, nicht zwölf Dateien (Befund des unabhängigen PO-Briefings).
- 2026-09-27: Test Plan um zwei Fälle für AC-10 ergänzt (geteilter Tokenizer war als AC formuliert,
  aber nirgends getestet) und die Grenze „gepflegte Titel, nicht Diktat" von einer bloßen Behauptung
  in Risiko 2 zu einer prüfbaren Forderung in AC-12 und in der Korpus-Suite gemacht (Befunde des
  unabhängigen PO-Briefings).
- 2026-09-27: Von Henning freigegeben. Vorher nachgefragt, warum Gleichheit statt Toleranz — am
  Korpus belegt: die Toleranz kauft über alle 287 Aufgaben elf Fälle dazu, davon fünf falsche
  Dauern („Termin für Reifenwechsel machen" gegen „Termin für Hautkrebs-Früherkennungsuntersuchung
  machen"), und die Schwelle 0,34 schneidet sie nicht weg, weil die Dauer-Fehltreffer bei 0,5 und
  0,667 liegen.
- 2026-09-27: Guard in Implementation Details 4 und 5 verschärft (Befund F002 der Adversary-Prüfung,
  vom Orchestrator auf beide Felder erweitert). Die skizzierten Bedingungen `task.duration == nil`
  und `task.contexts == nil` allein reichen nicht: `FieldCodec` kollabiert beim Leeren eines Feldes
  auch dessen `*SourceRaw` (Zeile 56 für `duration`, Zeile 65 für `contexts`), sodass ein per
  `RevisionService`-Reset vom Nutzer zurückgenommener Wert nicht mehr von „nie gesetzt" zu
  unterscheiden ist — der nächste Nachzügler-Lauf hätte ihn stumm wieder gesetzt und damit AC-6 und
  ADR-5 verletzt. Beide Guards prüfen zusätzlich, dass für das Feld **keine `Revision` mit
  `author == .user`** existiert; Revisionen werden nie gelöscht und sind damit der einzige tragfähige
  Marker. Die zwölf Acceptance Criteria bleiben unberührt. Belege: der Befund war in beiden Feldern
  reproduzierbar (`docs/artifacts/feat-136-wiedererkennung/test-red-f002-nutzerkorrektur.txt`, vier
  Fehlschläge, je zwei pro Feld) und ist durch zwei Regressionstests geschlossen. Die Einschätzung
  des Prüfers, der Defekt betreffe nur `contexts`, war falsch; sein angenommener Auslöser
  (Kontext-Bearbeitung in einer View) existiert in der App nicht — der reale Auslöser ist der
  Revisions-Reset.
- 2026-09-27: Definition of Done um einen eigenen Punkt für den F002-Schutz ergänzt (Befund des
  zweiten unabhängigen PO-Briefings). Der Schutz gegen Wiederbefüllung einer Nutzerkorrektur war
  automatisiert getestet, stand aber nur in den Implementation Details und im Changelog — über die
  formale Abnahme „AC-1 bis AC-12 erfüllt" wäre er nicht sichtbar mitgeprüft worden. Bewusst kein
  AC-13: die zwölf Acceptance Criteria sind freigegeben und die Adversary-Prüfung hat gegen genau
  diese zwölf geprüft; ein nachgeschobenes AC hätte den Prüfstand verschoben, ohne etwas zu belegen,
  was die beiden Regressionstests nicht schon belegen.
