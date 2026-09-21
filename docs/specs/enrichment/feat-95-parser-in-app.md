---
entity_id: feat-95-parser-in-app
type: feature
created: 2026-09-21
updated: 2026-09-21
status: draft
workflow: feat-95-parser-in-app
---

# Spec: #95 — Regelparser in die App (Teil von #92, Schnitt 2)

## Approval

- [ ] Approved

## Purpose

Der in Schnitt 1 gemessene Regelparser (99,3 % exakte Daten, 0 % erfunden, #92) löst das On-Device-
Modell als Datumsquelle im Produkt ab: `DateExpressionParser`/`TimeExpressionParser` ziehen aus
`Measurement/` in den Produktpfad, `EnrichmentDraft.dueDate` kommt künftig aus der Regel statt aus
`ModelEnrichment`, und das Modellschema verliert die vier Datumsfelder, die zu 96,5 % erfundene
Werte lieferten. Das setzt die Projektregel „Regeln vor Modell" (CLAUDE.md, Henning 2026-09-20) für
das Fälligkeitsdatum um.

## Source

- **Datei:** `Shared/Enrichment/EnrichmentCoordinator.swift`
- **Bezeichner:** `func processPending()`
- **Datei:** `Shared/Enrichment/DueDateRule.swift` (neu)
- **Bezeichner:** `enum DueDateRule`

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `DateExpressionParser` / `TimeExpressionParser` (#92, Schnitt 1) | Modul | Geprüfter Regelparser (99,3 % Datum exakt, 0 % erfunden; 100 % Uhrzeit auf dem Vollkorpus). Liefert Ausdrucksart + Wert, keine eigene Modellabhängigkeit. |
| `EnrichmentCoordinator` | Klasse | Orchestriert den Veredelungsdurchlauf; bekommt den Regelschritt zusätzlich zum Modellschritt. |
| `EnrichmentWriter` | Modul | Schwellenwert 0.6, schreibt Felder + Revisions; bleibt in diesem Ticket unverändert. |
| `EnrichmentDraft` / `TaskEnricher` | Typ/Protokoll | Naht zwischen Koordinator und Modell (Guess-Tripel: Wert, Konfidenz, Grund); `EnrichmentParsing.dueDate(day:time:)` fällt weg. |
| `FoundationModelsEnricher` / `ModelEnrichment` | Struct | On-Device-Modell; verliert vier `@Guide`-Datumsfelder und die zugehörige Instruktionszeile. |
| `TaskItem.dueDate` / `dueHasTime` / `dueSourceRaw` / `dueConfidence` | Modellfelder | Ziel des Schreibvorgangs, unverändertes Schema. |
| `project.yml` | Konfiguration | Build-Ziele App, Watch, Widgets, Share, Lab, Tests, UITests — der Umzug berührt alle sieben. |
| `Corpus` / `date-title-corpus.json` | Messdaten | Referenz für die Regressionsprüfung der geänderten Auflösung (`weekdayEitherNext`). |

## Scope

Über dem Limit von 4–5 Dateien / ±250 LoC in einem Stück. Zwei Schnitte, jeder für sich grün und
auslieferbar. Das Scoping-Limit gilt je Schnitt.

### Schnitt 2a — Umzug

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `Shared/Services/DateExpressionParser.swift` | CREATE (Move von `Measurement/DateExpressionParser.swift`) | Inhalt unverändert bis auf Zeile 109: `next(weekday, from: day, includingToday: false)` → `inFollowingWeek(weekday, from: day)` im Fall `.weekdayEitherNext`; Kommentar Zeile 99 entsprechend angepasst (PO: „nächsten Freitag" = Folgewoche). |
| `Shared/Services/TimeExpressionParser.swift` | CREATE (Move von `Measurement/TimeExpressionParser.swift`) | Unverändert. |
| `Measurement/DateExpressionParser.swift`, `Measurement/TimeExpressionParser.swift` | DELETE | Damit derselbe Typ nicht gleichzeitig in `Measurement/` und `Shared/Services/` liegt (Typkollision im Test-Ziel, das beide Ordner kompiliert). |
| `project.yml` | MODIFY | Prüfen, ob die Lab-Einzelpfade (Zeile 177–179) um die zwei neuen `Shared/Services`-Dateien ergänzt werden müssen, oder ob `Shared/Enrichment/*` bereits reicht; `xcodegen generate` danach. |
| `LooseEndsTests/DateExpressionParserTests.swift` | MODIFY | Test `weekdayEitherNext()` (Zeile 79–88) erwartet für „nächsten Freitag" die Folgewoche statt des nächsten Vorkommens. |

**Geschätzter Umfang:** 3 Produktionsdateien (2 neu + 1 project.yml) + 2 gelöschte + 1 Testdatei,
ca. ±20 LoC echte Änderung (der Move selbst ist netto 0).

Muss **ein** Stand sein: Move und Löschung der Quelle gehören in denselben Commit.

### Schnitt 2b — Naht

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `Shared/Enrichment/DueDateRule.swift` | CREATE | Reiner Baustein: kombiniert `DateExpressionParser.date(in:reference:)` und `TimeExpressionParser.time(in:)` zu einem `Date` (Tag + optionale Uhrzeit), liefert Konfidenz 1.0 und einen lesbaren, lokalisierten Grund je erkannter Ausdrucksart (`String(localized:)`). Ohne erkanntes Datum: kein Ergebnis, auch wenn eine Uhrzeit dasteht. Ohne Modell testbar (kein `#if canImport(FoundationModels)`, reines `Foundation`). |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | `processPending()`: das Modell-Gate (`enricher.unavailableReason != nil`) beendet nicht mehr den ganzen Durchgang, sondern nur den Modell-Teil je Aufgabe. Vor dem Modellaufruf läuft für jede Aufgabe ohne `dueDate` der Regelschritt (`DueDateRule`); ein Treffer wird mit eigener Revision geschrieben, ohne `processedAt` zu setzen. Danach läuft — nur wenn das Modell verfügbar ist — der bestehende Modellaufruf plus `EnrichmentWriter.apply` (setzt `processedAt` wie bisher). |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | MODIFY | `ModelEnrichment` verliert `dueDate`, `dueTime`, `dueConfidence`, `dueReason` samt `@Guide`-Beschreibung; `instructions` verliert die Datums-Zeile (Zeile 28); `draft(from:capturedAt:calendar:)` verliert das Mapping (Zeile 68–71). |
| `Shared/Enrichment/EnrichmentDraft.swift` | MODIFY | `EnrichmentParsing.dueDate(day:time:calendar:)` entfällt; `EnrichmentParsing.clamp` bleibt. `EnrichmentDraft.dueDate`/`dueHasTime` bleiben als Typ bestehen (weiterhin Teil des Guess-Vertrags, z. B. für Tests mit `StubEnricher`), werden aber von keinem Modell-Adapter mehr befüllt. |
| `LooseEndsTests/EnrichmentTests.swift` | MODIFY | `EnrichmentParsingTests` (Zeile 224–244) entfällt, weil die getestete Funktion wegfällt. Zwei neue Fälle in `EnrichmentCoordinatorTests`: „ohne verfügbares Modell schreibt die Regel trotzdem das Datum" (AC-7) und „zweiter Durchgang legt keine zweite Revision an" (AC-8). |
| `LooseEndsTests/DueDateRuleTests.swift` | CREATE | Datum+Uhrzeit kombiniert, Uhrzeit ohne Datum, Grundtext je Ausdrucksart, Konfidenz 1.0 (AC-5, AC-6). |

**Geschätzter Umfang:** 4 Produktionsdateien + 2 Testdateien, ca. ±200 LoC.

### Nicht-Scope (Folge-Issues)

- **Neuer `FieldSource`-Wert „Regel"** statt `dueSourceRaw = ai`: PO-Entscheidung ist `ai` beibehalten
  (2026-09-21). Ein eigener Wert ist ein Folge-Issue, weil `FieldSource` als Rohstring in SwiftData
  liegt und die Oberfläche „Regel exakt" von „Modell geraten" heute nirgends unterscheidet.
- **Freistehende Uhrzeit für Wiederholungsregeln** („jeden Tag um 7 Uhr"): `TimeExpressionParser`
  erkennt die Uhrzeit, aber `TaskItem.dueHasTime` ist ein Flag neben `dueDate`, kein eigener
  Zeit-Slot. Gehört in ein Folge-Issue zur Wiederholungsregel, sobald die dafür nötige Modellierung
  ansteht.
- **Zweiter Enricher / Dekorator-Architektur** (`RuleFirstEnricher(wrapping:)`): architektonisch
  sauberer für mehrere Enricher, aber ohne einen zweiten Enricher heute unbegründet. Siehe
  „Alternativen".

## Implementation Details

**Wo der Parser läuft.** Die Issue schlägt vor, `DueDateRule` innerhalb von
`FoundationModelsEnricher.enrich(_:)` aufzurufen. Das ist verworfen (siehe „Alternativen"): der
Koordinator kehrt heute bei `enricher.unavailableReason != nil` für den **ganzen** Durchgang zurück
(`EnrichmentCoordinator.swift:28-31`), bevor auch nur eine Aufgabe geholt wird — ein Parser in
`enrich()` liefe dann nie, wenn das Modell fehlt. Das Messlabor (`LooseEndsLab/MeasurementRunner.swift`)
ruft `FoundationModelsEnricher` zudem direkt auf, ohne Koordinator; ein Parser in `enrich()` würde
Regel und Modell in der Messung vermischen und die Trennung zunichtemachen, auf der der
#67-Bericht beruht. Der Regelschritt läuft deshalb als eigener Schritt **im Koordinator**, unabhängig
vom Modell-Gate.

**Die Rechenarbeit** liegt in `DueDateRule`, einem reinen Baustein ohne Modellabhängigkeit:
gegeben Rohtext, Erfassungszeitpunkt (`capturedAt`) und Kalender, liefert er entweder nichts oder
ein Datum, eine Konfidenz von 1.0 (ein Regel-Treffer ist deterministisch da oder nicht — eine
geschätzte Zwischenzahl wäre eine erfundene Zahl) und einen eigenen, lokalisierten Grundsatz aus der
erkannten Ausdrucksart (z. B. „Aus ‚nächsten Freitag' im Text."), unabhängig von der Sprache der
Notiz. Uhrzeit ohne erkanntes Datum liefert kein Ergebnis — `DateExpressionParser.isRepetition`
verhindert bereits, dass „jeden Tag um 7 Uhr" ein Datum liefert, und das Produktschema hat keinen
Platz für eine freistehende Uhrzeit.

**`processedAt`-Semantik bleibt der Marker für „das Modell hat es gesehen"** (ADR-4: Veredelung
genau einmal pro Aufgabe). Läuft der Regelschritt unabhängig vom Modell, darf er diesen Marker nicht
setzen, sonst bliebe Titel und Wichtigkeit auf einem Gerät ohne Apple Intelligence für immer offen.
Der Koordinator schreibt den Regel-Treffer deshalb **vor** dem Modellaufruf, mit eigener Revision,
ohne `processedAt` zu berühren; `EnrichmentWriter.apply` (unverändert) setzt `processedAt` weiterhin
nur nach einem tatsächlichen Modellaufruf. Damit die Regel beim nächsten Durchgang (Nachhol-Lauf,
sobald das Modell verfügbar ist) keine zweite Revision auf dasselbe Feld anlegt, erzeugt der
Koordinator den Regel-Guess nur, solange `task.dueDate == nil` ist.

**Feldursprung bleibt `ai`** (PO-Entscheidung 2026-09-21); die Regel schreibt über denselben Pfad
wie bisher der Modellwert (`task.dueSourceRaw = "ai"`, `task.dueConfidence`, eine `Revision` mit
`author: .ai`).

## Test Plan

### Automated Tests (TDD RED)

**Neu**
- `LooseEndsTests/DueDateRuleTests.swift`: GIVEN „Nächsten Freitag den Zuschuss beantragen, um 14 Uhr"
  und ein fester Referenztag / WHEN `DueDateRule` den Text verarbeitet / THEN liefert er ein Datum auf
  dem Freitag der Folgewoche mit Uhrzeit 14:00, Konfidenz 1.0 und einem nicht-leeren Grundsatz (AC-5).
- `LooseEndsTests/DueDateRuleTests.swift`: GIVEN „Jeden Tag um 7 Uhr die Tabletten nehmen" (Uhrzeit
  ohne Datum, Wiederholungs-Sperre greift) / WHEN `DueDateRule` den Text verarbeitet / THEN liefert er
  kein Ergebnis (AC-6).
- `LooseEndsTests/DueDateRuleTests.swift`: GIVEN je einen Satz pro Ausdrucksart (`offsetDays`,
  `weekday`, `weekdayNextWeek`, `weekdayEitherNext`, `endOfMonth`, `dayOfMonth`, `weekend`,
  `monthRange`, `dayAndMonth`) / WHEN `DueDateRule` sie verarbeitet / THEN ist der Grundsatz für jede
  Ausdrucksart unterschiedlich und nicht leer (AC-5).
- `LooseEndsTests/EnrichmentTests.swift`, neuer Fall in `EnrichmentCoordinatorTests`: GIVEN eine
  Aufgabe mit „Nächsten Freitag die Miete überweisen" und ein `StubEnricher` mit
  `unavailableReason` gesetzt / WHEN `EnrichmentCoordinator.processPending()` läuft / THEN trägt die
  Aufgabe ein `dueDate` auf dem Freitag der Folgewoche, `dueSourceRaw == "ai"`, eine `Revision` mit
  `author == .ai`, aber `processedAt == nil` und der Enricher wurde nicht aufgerufen (AC-7).
- `LooseEndsTests/EnrichmentTests.swift`, neuer Fall in `EnrichmentCoordinatorTests`: GIVEN dieselbe
  Aufgabe aus dem vorigen Test (Regel hat bereits geschrieben, `processedAt == nil`) und ein zweiter
  Durchlauf mit einem jetzt verfügbaren `StubEnricher` / WHEN `processPending()` erneut läuft / THEN
  ruft der Enricher genau einmal auf, schreibt Titel und übrige Felder, setzt `processedAt`, aber die
  Aufgabe trägt weiterhin genau eine `dueDate`-Revision (keine zweite) (AC-8).

**Geändert**
- `LooseEndsTests/DateExpressionParserTests.swift`, `weekdayEitherNext()`: Erwartung für „Nächsten
  Freitag …" von „nächstes Vorkommen" auf „Freitag der Folgewoche" umgestellt; bestehende Fälle für
  die übrigen acht Ausdrucksarten unverändert (AC-2, Regressionsschutz für AC-3).
- `LooseEndsTests/EnrichmentTests.swift`: `EnrichmentParsingTests` (bisher Zeile 224–244) entfernt,
  weil `EnrichmentParsing.dueDate(day:time:)` entfällt (AC-10). `appliesFieldsAboveThreshold` und die
  übrigen `EnrichmentWriterTests` bleiben unverändert, weil `EnrichmentWriter` in diesem Ticket nicht
  angefasst wird.

**Entfallend**
- `EnrichmentParsingTests.parsesDueDate()` (in `LooseEndsTests/EnrichmentTests.swift`): testete eine
  Funktion, die mit dem Schemaschrumpf keinen Aufrufer mehr hat.

**Unverändert, nur Bau-Abhängigkeit**
- `LooseEndsTests/DateTitleReportTests.swift` nutzt `@testable import LooseEnds` bereits heute; der
  Umzug ändert keine Zeile darin, nur den physischen Ort des referenzierten Typs.

Kein neuer UI-Test: Es entsteht keine neue View und kein neues UI-Element. `TaskDetailView.swift:183`
und `FieldEditorView.swift:32` zeigen `revision.reason` bereits heute an — der Regelsatz durchläuft
denselben, ungeänderten Anzeigepfad. Das Projekt schreibt UI-Tests erst nach dem Design-Freeze und
nur als Smoke-Tests (CLAUDE.md).

## Acceptance Criteria

- **AC-1 (2a) Ein Parser-Stand, keine Typkollision:** Given der Umzug nach `Shared/Services/` / When
  derselbe Commit `Measurement/DateExpressionParser.swift` und `Measurement/TimeExpressionParser.swift`
  löscht / Then existiert `DateExpression`/`DateExpressionParser`/`TimeExpressionParser` genau einmal
  im Repository und `./scripts/sim.sh unit` kompiliert ohne Typkollision im Test-Ziel.
- **AC-2 (2a) „Nächsten Freitag" = Folgewoche:** Given der Satz „Nächsten Freitag den Zuschuss
  beantragen" und ein fester Referenztag (Do 12.3.2026) / When `DateExpressionParser.date(in:reference:)`
  ihn auflöst / Then liefert er den Freitag der auf den Referenztag folgenden Woche (20.3.2026), nicht
  das nächste Vorkommen (13.3.2026).
- **AC-3 (2a) Regression der übrigen acht Ausdrucksarten:** Given die geänderte Auflösung in
  `.weekdayEitherNext` / When `./scripts/sim.sh unit` läuft / Then bleiben alle Fälle für
  `offsetDays`, `weekday`, `weekdayNextWeek`, `endOfMonth`, `dayOfMonth`, `weekend`, `monthRange`,
  `dayAndMonth` in `DateExpressionParserTests` und alle Fälle in `TimeExpressionParserTests`
  unverändert grün.
- **AC-4 (2a) Alle sieben Build-Ziele kompilieren:** Given der Umzug nach `Shared/Services/` und ein
  angepasstes `project.yml` / When `xcodegen generate` läuft und danach `./scripts/sim.sh build` für
  `LooseEnds` sowie ein Build von `LooseEndsWatch`, `LooseEndsWidgets`, `LooseEndsShare` und
  `LooseEndsLab` / Then kompilieren alle sieben Ziele (App, Watch, Widgets, Share, Lab, Tests,
  UITests) ohne fehlende Dateireferenz.
- **AC-5 (2b) `DueDateRule` kombiniert Datum und Uhrzeit:** Given der Satz „Nächsten Freitag den
  Zuschuss beantragen, um 14 Uhr" und ein fester Referenztag / When `DueDateRule` ihn verarbeitet /
  Then liefert er ein `Date` auf dem Freitag der Folgewoche um 14:00, Konfidenz 1.0 und einen
  nicht-leeren, lokalisierten Grundsatz.
- **AC-6 (2b) Uhrzeit ohne Datum bleibt leer:** Given der Satz „Jeden Tag um 7 Uhr die Tabletten
  nehmen" (Wiederholungs-Sperre greift, keine Ausdrucksart erkannt) / When `DueDateRule` ihn
  verarbeitet / Then liefert er kein Ergebnis, und `EnrichmentWriter` schreibt weder `dueDate` noch
  `dueHasTime`.
- **AC-7 (2b) Ohne verfügbares Modell schreibt die Regel trotzdem das Datum:** Given eine Aufgabe mit
  „Nächsten Freitag die Miete überweisen" und ein Enricher mit gesetztem `unavailableReason` / When
  `EnrichmentCoordinator.processPending()` läuft / Then trägt die Aufgabe das von der Regel erkannte
  `dueDate` mit `dueSourceRaw == "ai"` und einer `Revision` (`author == .ai`), aber `processedAt`
  bleibt `nil` und der Enricher wird nicht aufgerufen.
- **AC-8 (2b) Zweiter Durchgang holt Titel nach, ohne die Regel-Revision zu duplizieren:** Given eine
  Aufgabe, deren `dueDate` bereits durch die Regel gesetzt wurde (`processedAt == nil`) / When
  `processPending()` mit einem jetzt verfügbaren Modell erneut läuft / Then ruft der Enricher genau
  einmal auf, schreibt Titel und übrige Felder, setzt `processedAt`, und die Aufgabe trägt weiterhin
  genau eine `dueDate`-Revision.
- **AC-9 (2b) Feldursprung bleibt `ai`:** Given ein Regel-Treffer / When `EnrichmentCoordinator` ihn
  schreibt / Then steht `task.dueSourceRaw == "ai"` und `task.dueConfidence == 1.0`, kein neuer
  `FieldSource`-Wert.
- **AC-10 (2b) Modellschema schrumpft, `EnrichmentParsing.dueDate` entfällt:** Given der Schemaschrumpf
  in `ModelEnrichment` / When `./scripts/sim.sh unit` läuft / Then existiert
  `EnrichmentParsing.dueDate(day:time:)` nicht mehr im Code, `ModelEnrichment` hat keine
  `dueDate`/`dueTime`/`dueConfidence`/`dueReason`-Felder mehr, und alle verbleibenden Suiten
  (`EnrichmentWriterTests`, `EnrichmentCoordinatorTests`, `CorpusTests`, `DateTitleReportTests`)
  bleiben grün.

## Risiken

1. **Ohne Apple Intelligence kein Datum, obwohl die Regel eins hätte.** Gegenmaßnahme (Schnitt 2b,
   AC-7): Der Regelschritt läuft im Koordinator unabhängig vom Modell-Gate, nicht innerhalb von
   `FoundationModelsEnricher.enrich()`.
2. **Konfidenz eines Regel-Treffers war unfestgelegt.** Gegenmaßnahme (Schnitt 2b, AC-5/AC-9): fest
   auf 1.0, weil `DateExpressionParser.expression(in:)` deterministisch genau einen Kandidaten oder
   nichts liefert — kein „vielleicht"-Zustand, aus dem sich eine Zwischenzahl ableiten ließe.
3. **Der Begründungstext wird dem Nutzer angezeigt, Sprachfrage DE/EN war offen.** Gegenmaßnahme
   (Schnitt 2b, AC-5): `DueDateRule` liefert einen eigenen, über `String(localized:)` lokalisierten
   Satz je Ausdrucksart, unabhängig von der Sprache der Notiz — die Anzeigepfade
   (`TaskDetailView.swift:183`, `FieldEditorView.swift:32`) bleiben unverändert.
4. **Umzug berührt vier Build-Ziele.** Gegenmaßnahme (Schnitt 2a, AC-4): `project.yml` wird geprüft
   und `xcodegen generate` läuft vor jedem Testlauf; alle sieben Ziele werden gebaut, nicht nur
   getestet.
5. **Modellschema schrumpft um vier Felder, bestehende Tests bauen `ModelEnrichment` mit
   Datumsfeldern auf.** Gegenmaßnahme (Schnitt 2b, AC-10): `EnrichmentParsingTests` entfällt
   kontrolliert als Teil dieses Tickets, nicht als Kollateralschaden; keine andere Suite baut
   `ModelEnrichment` von Hand auf.
6. **Doppelte Quelle: derselbe Typ gleichzeitig in `Measurement/` und `Shared/Services/`.**
   Gegenmaßnahme (Schnitt 2a, AC-1): Move und Löschung der Quelle in einem Commit, keine
   Zwischenstände mit beiden Ordnern.

## Alternativen

- **Parser in `FoundationModelsEnricher.enrich(_:)` aufrufen** (Vorschlag der Issue): verworfen. Der
  Koordinator kehrt bei fehlendem Modell für den ganzen Durchgang zurück, das Messlabor ruft den
  Enricher direkt ohne Koordinator auf (Vermischung von Regel- und Modellmessung), und der Enricher
  ist mit `#if canImport(FoundationModels) && !os(watchOS)` geklammert. Keine Bedingung zum
  Wiederaufmachen — das ist kein Kostenabwägung, sondern am Code widerlegt.
- **Dekorator `RuleFirstEnricher(wrapping:)` um jeden `TaskEnricher`:** architektonisch sauberer für
  eine Zukunft mit mehreren Enrichern, kostet heute aber einen neuen Produktionstyp, eine neue
  Testdatei und einen Eingriff in die Komposition, ohne dass ein zweiter Enricher das rechtfertigt.
  Wird nachgeholt, sobald ein zweiter Enricher hinzukommt.
- **`processedAt` beim Regel-Only-Schreiben sofort setzen:** billiger umzusetzen, verliert aber Titel
  und Wichtigkeit dauerhaft, sobald eine Aufgabe einmal ohne Apple Intelligence erfasst wurde (gesperrtes
  Gerät, kein unterstütztes Modell, Ratenlimit). Verworfen. Würde nur infrage kommen, wenn ein Gerät
  dauerhaft (nicht nur vorübergehend) ohne Apple Intelligence bliebe und ein Nachhol-Lauf sich damit
  erübrigt — heute nicht der Fall.
- **Neuer `FieldSource`-Wert „Regel" statt `ai`:** in Schnitt 1 bereits verworfen (siehe
  `docs/specs/measurement/feat-92-date-parser.md`, Abschnitt „Alternativen"), von Henning am
  2026-09-21 bestätigt. Als Folge-Issue vorgemerkt (siehe „Nicht-Scope").
- **Freistehende Uhrzeit ohne Datum in ein eigenes Feld schreiben:** verworfen, weil das
  Produktschema keinen Slot dafür hat (`dueHasTime` ist ein Flag neben `dueDate`, kein eigener
  Zeit-Slot); gehört zur Wiederholungsregel und damit in ein eigenes Folge-Issue.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt, belegt durch die im Test Plan genannten Tests
- [ ] Schnitt 2a: `./scripts/sim.sh unit` grün nach dem Umzug, alle sieben Build-Ziele kompilieren
      (AC-4)
- [ ] Schnitt 2b: `./scripts/sim.sh unit` grün nach Regelschritt, Koordinator-Umbau und Schemaschrumpf
- [ ] Build erfolgreich (`xcodebuild` bzw. `./scripts/sim.sh build` ohne Errors), jeder Commit
      kompiliert
- [ ] Drei Abnahmestufen durchlaufen: Tests → Simulator → Hennings iPhone 16 Pro
      (`./scripts/sim.sh device`) — kein Schritt entfällt, TestFlight ist kein Ersatz dafür
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
      (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] PR für Schnitt 2a referenziert #95, ohne es zu schließen (Schnitt 2b folgt)
- [ ] PR für Schnitt 2b schließt #95 (`Closes #95`)
- [ ] Kein manueller Testhinweis an Henning — jede Acceptance Criterion ist automatisiert bewiesen
- [ ] CI grün auf beiden PRs

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Die Änderung bewegt sich innerhalb bestehender Architektur-Entscheidungen
  (ADR-3 Rohtext unveränderlich/abgeleitete Felder mit Herkunft und Konfidenz; ADR-4 Veredelung genau
  einmal pro Aufgabe; ADR-6 Revisionen statt Undo; ADR-11 Tests mit Fake-Modell über das
  `TaskEnricher`-Protokoll) und führt keinen neuen Architekturbaustein ein, der eine eigene Nummer
  rechtfertigt — `DueDateRule` ist ein weiterer reiner Baustein neben `EnrichmentWriter`, keine neue
  Schicht. Die zugrunde liegende Produktentscheidung „Regeln vor Modell" ist bereits als
  projektweite Arbeitsregel in `CLAUDE.md` geführt, nicht als Einzel-ADR (siehe dieselbe Begründung
  in `docs/specs/measurement/feat-92-date-parser.md`). Diese Spec setzt die Regel für den
  Produktpfad um.

## Changelog

- 2026-09-21: Spec aus dem Analyse-Kontext (`docs/context/feat-95-parser-in-app.md`, Phase 1+2)
  erstellt.
