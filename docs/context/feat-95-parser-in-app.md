# Context: feat-95-parser-in-app

Issue: [#95](https://github.com/henemm/loose-ends/issues/95) — Regelparser in die App (Teil von #92, Schnitt 2)
Phase 1 erstellt am 2026-09-21.

## Request Summary

Der in Schnitt 1 gemessene Regelparser (99,3 % exakte Daten, 0 % erfunden) soll das Modell als
Datumsquelle in der App ablösen: Parser wandert aus `Measurement/` in den Produktpfad, die
Datumsfelder verschwinden aus dem Modellschema, und `EnrichmentDraft.dueDate` kommt aus der Regel.

## PO-Entscheidungen (Henning, 2026-09-21, via Intake)

| Ausdruck | Entscheidung | Parser heute |
|---|---|---|
| „am Wochenende" | Samstag | Samstag ✅ |
| „nächsten Freitag" | **Freitag der Folgewoche** | kommendes Vorkommen ❌ → ändern |
| „nächsten Monat" | 1. des Folgemonats | 1. des Folgemonats ✅ |
| „jeden Tag um 7 Uhr" | Uhrzeit wird übernommen | Uhrzeit wird übernommen ✅ |
| Feldursprung | bleibt `ai` (Tech-Lead-Entscheidung, „Regel" als Folge-Issue) | — |

**Wichtiger Befund zur Abweichung:** Die Messung bleibt gültig. `Corpus.DateExpectation.weekdayEitherNext`
akzeptiert beide Lesarten (`Measurement/Corpus.swift:149-151`), die Erkennung (`.weekdayEitherNext`)
bleibt unverändert. Zu ändern ist nur die Auflösung in `DateExpressionParser.resolve`
(`Measurement/DateExpressionParser.swift:109`) von `next(includingToday: false)` auf
`inFollowingWeek` — eine Zeile plus Kommentar und Unit-Test. Kein neuer Korpus-Erwartungswert,
kein neuer Messlauf nötig.

## Related Files

| Datei | Relevanz |
|---|---|
| `Measurement/DateExpressionParser.swift` (297 LoC) | zieht nach `Shared/Services`; Zeile 109 + Kommentar Zeile 99 ändern |
| `Measurement/TimeExpressionParser.swift` (79 LoC) | zieht mit; `ExpressionText`/`ExpressionWord` stecken im Date-File |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | `ModelEnrichment` verliert vier Datumsfelder, Instruktion Zeile 27 entfällt, `draft(from:)` Zeile 68-71 |
| `Shared/Enrichment/EnrichmentDraft.swift` | `EnrichmentParsing.dueDate(day:time:)` (Zeile 60-73) fällt weg; `clamp` bleibt |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | baut `EnrichmentInput`; steigt bei fehlendem Modell früh aus (siehe Risiko 1) |
| `Shared/Enrichment/EnrichmentWriter.swift` | schreibt `dueDate`, `dueHasTime`, `dueSourceRaw = ai`, `dueConfidence`; Schwelle 0.6 |
| `project.yml` | `Measurement` kompiliert in Lab/Tests/UITests; `Shared` in App, Watch, Widgets, Share. Lab listet Shared-Dateien einzeln (Zeile 177-179) und braucht die zwei neuen Pfade |
| `LooseEndsTests/DateExpressionParserTests.swift` | Auflösungs-Tests zu `weekdayEitherNext` (Zeile 80-87) |
| `LooseEndsTests/EnrichmentTests.swift` | Zeile 230-241 testen `EnrichmentParsing.dueDate` → entfallen; Zeile 56-83 Draft→Task bleibt |
| `LooseEndsTests/DateTitleReportTests.swift` | erzeugt den Messbericht zu #67; nutzt beide Parser |
| `LooseEnds/Views/TaskDetailView.swift:183`, `FieldEditorView.swift:32` | zeigen den Revisions-Grund an → der Parser muss einen lesbaren Grund liefern |

## Existing Patterns

- **Enricher-Naht:** `TaskEnricher` (Protokoll) → `EnrichmentDraft` → `EnrichmentWriter.apply` → `TaskItem` + `Revision`.
  Tests setzen einen Stub-Enricher ein; alles Reine ist ohne Modell testbar.
- **Guess-Tripel:** jedes Feld trägt Wert, Konfidenz und einen Satz Begründung. Der Writer schreibt nur
  ab 0.6 und legt je Feld eine Revision an (ADR-3, ADR-6).
- **Getrennte Arithmetik:** Parser und Korpus rechnen bewusst nicht mit demselben Code, damit ein Fehler
  sich nicht selbst bestätigt (`DateExpressionParser.swift:69-71`). Das muss der Umzug erhalten.
- **Plattform-Guard:** `FoundationModelsEnricher` ist mit `#if canImport(FoundationModels) && !os(watchOS)`
  geklammert. Der Parser darf keinen solchen Guard brauchen — reines Foundation, kompiliert in Watch und Widgets mit.

## Dependencies

- Upstream: `Foundation`, `Calendar`. Der Parser braucht `reference: Date` (= `capturedAt`) und einen Kalender.
- Downstream: `EnrichmentWriter` → `TaskItem.dueDate`/`dueHasTime`; daran hängen Fälligkeits-Erinnerungen
  (`Shared/Notifications/DueReminders`), die Listenregeln (`ViewRules`) und die Wiederholungslogik.

## Existing Specs

- `docs/specs/measurement/feat-92-date-parser.md` — Schnitt 1, enthält unter „Offene PO-Fragen (nur Schnitt 2)"
  genau die jetzt entschiedenen Punkte und unter „Alternativen" den Stand der Abwägung.

## Risks & Considerations

1. **Ohne Apple Intelligence kein Datum — obwohl die Regel eins hätte.** Die Issue schlägt vor, den Parser
   *in* `FoundationModelsEnricher.enrich(_:)` aufzurufen. Der Koordinator bricht aber vorher ab, wenn
   `unavailableReason` gesetzt ist (`EnrichmentCoordinator.swift:29-32`) — auf einem Gerät ohne Modell,
   bei gesperrtem Gerät oder am Limit gäbe es dann kein Datum, obwohl der Regelweg keinerlei Modell braucht.
   **Alternative für Phase 2:** Parser als eigener Schritt vor dem Enricher (im Koordinator) oder als
   Dekorator um jeden `TaskEnricher`. Das ist zugleich die Lesart von „Regeln vor Modell": die Regel ist
   der Hauptweg, das Modell der Zusatz — nicht umgekehrt.
2. **Konfidenz eines Regel-Treffers ist noch nicht festgelegt.** Der Writer schreibt erst ab 0.6. Ein
   Regel-Treffer ist entweder da oder nicht; ein Wert wie 1.0 ist ehrlicher als eine geschätzte Zahl.
   Gehört in die Spec.
3. **Der Begründungstext wird dem Nutzer angezeigt** (Aufgaben-Detail und Feld-Editor). Bisher schrieb ihn
   das Modell in der Sprache der Notiz. Die Regel muss einen eigenen, lesbaren Satz liefern — und die
   Sprachfrage (DE/EN) ist zu entscheiden.
4. **Umzug berührt vier Build-Ziele.** `Shared` kompiliert in App, Watch, Widgets und Share-Erweiterung;
   das Labor-Ziel listet Shared-Dateien einzeln auf und bricht sonst. Nach jedem Stand muss das
   Xcode-Projekt neu erzeugt werden.
5. **Modellschema schrumpft um vier Felder.** Guided Generation ist damit schneller und kann kein Datum
   mehr erfinden (gemessen 96,5 % erfunden) — aber alle Tests, die `ModelEnrichment` mit Datumsfeldern
   aufbauen, müssen mit.
6. **Doppelte Quelle vermeiden.** Nach dem Umzug darf der Parser nicht gleichzeitig in `Measurement/`
   und `Shared/Services` liegen, sonst kollidieren die Typen im Test-Ziel (beide Ordner kompilieren dort).

---

# Analysis

Phase 2 am 2026-09-21. Befunde am Code geprüft, strategische Bewertung unabhängig gegengelesen.

## Type

Feature (Umbau) — kein Bug. Der Regelweg ersetzt den Modellweg für ein Feld.

## Der tragende Befund: wo der Parser läuft, entscheidet alles

Die Issue schlägt vor, den Parser **in** `FoundationModelsEnricher.enrich()` aufzurufen. Das ist am
Code widerlegt. Drei Stellen, jede einzeln nachgeprüft:

1. `EnrichmentCoordinator.swift:28-31` kehrt für den **ganzen Durchgang** zurück, sobald
   `enricher.unavailableReason != nil` — bevor auch nur eine Aufgabe geholt wird. Sitzt der Parser
   in `enrich()`, läuft er bei gesperrtem Gerät, fehlender Apple Intelligence oder am Ratenlimit
   **nie**. „Regeln vor Modell" würde faktisch zu „Regeln nur, wenn das Modell kann".
2. `LooseEndsLab/MeasurementRunner.swift:48,138` ruft `FoundationModelsEnricher` **direkt** auf, ohne
   Koordinator. Ein Parser in `enrich()` würde bedeuten: Das Messlabor misst ab sofort eine Mischung
   aus Regel und Modell. Die Trennung, auf der der #67-Bericht beruht (Modell 50 % / Regel 99,3 %,
   getrennt gemessen), wäre dahin — spätere Messläufe nach einem Apple-Modell-Update wären mit den
   bisherigen nicht mehr vergleichbar.
3. `FoundationModelsEnricher` ist mit `#if canImport(FoundationModels) && !os(watchOS)` geklammert.
   Der Parser wäre an einen Typ gekettet, den es auf der Watch nicht gibt.

**Entschieden (Tech Lead): Der Parser läuft als eigener Schritt im `EnrichmentCoordinator`,
unabhängig vom Modell-Gate.** Die eigentliche Rechenarbeit (Tag + Uhrzeit → ein `Date`, Guess mit
Konfidenz) liegt in einem neuen reinen Baustein in `Shared/Enrichment`, damit der Koordinator
schlank bleibt und der Schritt ohne Modell testbar ist (Stub-Enricher wie bisher).

**Verworfene Alternative:** Dekorator um jeden `TaskEnricher` (`RuleFirstEnricher(wrapping:)`).
Architektonisch sauberer für eine Zukunft mit mehreren Enrichern, kostet heute aber einen neuen
Produktionstyp, eine neue Testdatei und einen Eingriff in die Komposition — ohne zweiten Enricher,
der das rechtfertigt. Wird nachgeholt, sobald ein zweiter dazukommt.

## Die Folge, die niemand bestellt hat: `processedAt`

`EnrichmentWriter.swift:100` setzt `processedAt` **immer**, auch wenn kein Feld die Schwelle nahm —
Veredelung läuft genau einmal pro Aufgabe (ADR-4). Heute bleibt eine Aufgabe ohne Modell schlicht
liegen und wird beim nächsten Durchgang nachgeholt.

Läuft die Regel künftig unabhängig vom Modell, würde sie eine Aufgabe als „verarbeitet" abhaken,
die das Modell nie gesehen hat: Datum ja, Titel und Wichtigkeit für immer nein.

**Entschieden (Tech Lead):** `processedAt` bleibt der Marker für „das Modell hat es gesehen". Bei
fehlendem Modell schreibt die Regel das Datum und die Aufgabe bleibt offen für den Nachhol-Durchgang.
Damit die Regel beim zweiten Durchgang keine zweite Revision anlegt, wird der Regel-Guess nur
erzeugt, solange die Aufgabe noch kein Fälligkeitsdatum trägt.
**Alternative:** `processedAt` sofort setzen — billiger, verliert aber Titel und Wichtigkeit dauerhaft,
sobald eine Aufgabe einmal ohne Apple Intelligence erfasst wurde. Verworfen.

## Uhrzeit ohne Datum

`DateExpressionParser.isRepetition` (Zeile 152-154) verhindert bewusst, dass „jeden Tag um 7 Uhr"
ein Datum liefert — eine Wiederholung ist kein Tag. Die Uhrzeit erkennt der Zeitparser trotzdem, aber
das Produktschema hat keinen Platz dafür: `TaskItem.dueHasTime` ist ein Flag neben `dueDate`, kein
eigener Zeit-Slot.

**Entschieden:** Ohne erkanntes Datum wird weder `dueDate` noch `dueHasTime` geschrieben, auch wenn
eine Uhrzeit dasteht. Die freistehende Uhrzeit gehört zur Wiederholungsregel und damit in ein
Folge-Issue. Gemessen wird sie weiterhin unabhängig (`TimeExpressionParserTests`), es geht nichts verloren.

## Konfidenz eines Regel-Treffers: 1.0

`DateExpressionParser.expression(in:)` liefert deterministisch genau einen Kandidaten oder nichts —
es gibt keinen „vielleicht"-Zustand, aus dem sich eine Zwischenzahl ableiten ließe. Eine geschätzte
0.9 wäre eine erfundene Zahl. 1.0 ist die einzig ehrliche Aussage auf Satzebene: die Grammatik hat
gefeuert. Das ist keine Behauptung über die 99,3 % des Gesamtsystems. Schwelle im Writer ist 0.6.

## Begründungstext

Der Grund erscheint dem Nutzer (`TaskDetailView.swift:183`, `FieldEditorView.swift:32`) und darf
laut beiden Views leer sein — ein leeres „Von der KI gesetzt" wäre aber unschön. Die Regel liefert
einen eigenen Satz aus der erkannten Ausdrucksart (z. B. „Aus ‚nächsten Freitag' im Text."), über
`String(localized:)` lokalisiert. Feldursprung bleibt `ai` (PO-Entscheidung); ein eigener Wert
„Regel" ist ein Folge-Issue, weil `FieldSource` als Rohstring in SwiftData liegt.

## Affected Files

| Datei | Change | Was |
|---|---|---|
| `Measurement/DateExpressionParser.swift` | MOVE → `Shared/Services/` | plus Zeile 109 `next(includingToday:false)` → `inFollowingWeek` und Kommentar Zeile 99 (PO: „nächsten Freitag" = Folgewoche) |
| `Measurement/TimeExpressionParser.swift` | MOVE → `Shared/Services/` | unverändert; `ExpressionText`/`ExpressionWord` ziehen im Date-File mit |
| `Shared/Enrichment/DueDateRule.swift` | CREATE | Tag + Uhrzeit → ein `Date`, Guess mit Konfidenz 1.0 und lesbarem Grund. Rein, ohne Modell testbar |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | Modell-Gate von „ganzer Durchgang aus" zu „nur die KI-Felder aus"; Regelschritt davor; `processedAt`-Semantik |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | MODIFY | vier `@Guide`-Datumsfelder, Instruktionszeile 28 und Mapping 68-71 raus |
| `Shared/Enrichment/EnrichmentDraft.swift` | MODIFY | `EnrichmentParsing.dueDate(day:time:)` raus, `clamp` bleibt |
| `project.yml` | MODIFY | prüfen, ob die Lab-Einzelpfade (Zeile 177-179) noch reichen; `generate` nach jedem Stand |
| `LooseEndsTests/DateExpressionParserTests.swift` | MODIFY | Auflösung `weekdayEitherNext` (Zeile 80-87) |
| `LooseEndsTests/EnrichmentTests.swift` | MODIFY | `EnrichmentParsingTests` (Zeile 224-244) entfallen; neuer Test „ohne Modell schreibt die Regel trotzdem das Datum" |
| `LooseEndsTests/DueDateRuleTests.swift` | CREATE | Kombination Datum+Uhrzeit, Uhrzeit-ohne-Datum, Grund-Text |

## Scope

Über dem Limit von 4–5 Dateien in einem Stück. **Vorschlag: zwei Schnitte**, jeder für sich grün und
auslieferbar:

- **Schnitt 2a — Umzug.** Beide Parser nach `Shared/Services`, PO-Fix „nächsten Freitag", Tests
  nachziehen. 3 Dateien + 1 Testdatei, ca. ±20 LoC echte Änderung (der Move selbst ist netto 0).
  Muss **ein** Stand sein: liegt derselbe Typ gleichzeitig in `Measurement/` und `Shared/Services/`,
  kollidiert er im Testziel, das beide Ordner kompiliert.
- **Schnitt 2b — Naht.** Neuer Regelbaustein, Koordinator, Schemaschrumpf, Tests.
  4 Produktionsdateien + 2 Testdateien, ca. ±200 LoC.

Risiko: **mittel.** Der Eingriff in `processPending()` ist ein echter struktureller Umbau, kein
Hinzufügen — daran hängen Fälligkeits-Erinnerungen, Listenregeln und die Wiederholungslogik. Der
Umzug selbst und der Schemaschrumpf sind risikoarm.

## Reihenfolge

1. Umzug + PO-Fix in einem Stand, volle Suite grün (Schnitt 2a).
2. Regelbaustein mit eigenen Tests, noch ohne Berührung von Koordinator oder Enricher.
3. Naht verdrahten; Modellschema **noch unverändert** lassen — die Regel überschreibt, nichts bricht.
4. Erst jetzt die vier Schemafelder und `EnrichmentParsing.dueDate` entfernen.
5. `generate`, volle Suite, Lab-Build, dann Simulator und iPhone 16 Pro.

## Open Questions

Keine für den PO. Die vier Punkte aus der Issue („am Wochenende", „nächsten Freitag", „nächsten
Monat", Feldursprung) hat Henning am 2026-09-21 entschieden; die übrigen Fragen sind technisch und
oben als Tech-Lead-Entscheidung festgehalten.
