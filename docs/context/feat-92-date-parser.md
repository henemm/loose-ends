# Context: feat-92-date-parser

## Request Summary
Das Datum kommt nicht mehr vom Modell, sondern aus einem deterministischen Zeitausdruck-Parser
DE/EN (#92, PO-Entscheidung „Regeln vor Modell", 2026-09-20). Ziel: ≥ 95 % exakt und 0 % erfunden
auf dem Messkorpus, Uhrzeit ≥ 95 %. Zwei Lieferungen: (1) Parser + Messspalte im Bericht + Liste
„Was danebenging"; (2) Modellschema ohne Datumsfelder, Enricher ruft den Parser, Simulator-Nachweis,
Eintrag in #67. Erst wenn Schnitt 1 die 95 % zeigt, wird die App umgebaut.

## Related Files
| File | Relevance |
|------|-----------|
| `Measurement/Corpus.swift` | `Corpus.DateExpectation` (9 Ausdrucksarten) mit fertiger Kalenderrechnung `acceptedDays(reference:calendar:)`; `Corpus.weekdayNames`; `Corpus.Entry.time` als „HH:mm". **Kompiliert nur in Tests, UI-Tests und Labor-App, nicht in `Shared/`** |
| `Measurement/date-title-corpus.json` | 317 Sätze (242 DE, 75 EN); 139 mit Datum, 178 ohne (8 davon `repeat`, zählen nicht); 24 mit Uhrzeit |
| `LooseEndsTests/DateTitleReportTests.swift` | Bericht; `scoreParser` misst heute `NSDataDetector` gegen `today` und füllt `report.parser`/`parserInvented`; `dateSection` hat Spalten Modell + NSDataDetector; `missesSection` listet nur Modell-Fehler; `ruleName` benennt Ausdrucksarten |
| `LooseEndsTests/CorpusTests.swift` | Prüft die Kalenderrechnung je Regel gegen festen Referenztag; Vorbild für Parser-Tests |
| `Shared/Enrichment/EnrichmentDraft.swift` | `EnrichmentDraft.dueDate: Guess<Date>?`, `dueHasTime`; `EnrichmentParsing.dueDate(day:time:)` (nur noch für das Modellformat „YYYY-MM-DD") |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | `ModelEnrichment` (@Generable) mit `dueDate`, `dueTime`, `dueConfidence`, `dueReason`; `draft(from:capturedAt:)` mappt sie; Instruktionen erwähnen „due date" (Schnitt 2) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | Baut `EnrichmentInput` (rawText, capturedAt) und ruft `enricher.enrich`; hier oder im Enricher setzt Schnitt 2 den Parser vor das Modell |
| `Shared/Enrichment/EnrichmentWriter.swift` | Schreibt `draft.dueDate` bei `confidence >= threshold`, setzt `dueSourceRaw = ai`, legt `Revision` an |
| `Shared/Models/Enums.swift` | `FieldSource { ai, user }` — kein Wert für „Regel/Parser" (Schnitt 2 muss entscheiden: `ai` beibehalten oder neuer Wert) |
| `LooseEndsLab/MeasurementRunner.swift` | Labor-App misst das Modell auf dem iPhone; `capturedAt` = 9 Uhr des Messtags. Für den Parser nicht nötig (Mac genügt), aber Schnitt 2 ändert das Schema, das die Labor-App mitkompiliert |
| `LooseEndsTests/EnrichmentTests.swift` | `EnrichmentParsingTests` (Zeilen 224–241) testen das Modellformat; `EnrichmentWriter`-Tests setzen `draft.dueDate` direkt (bleiben gültig) |
| `docs/reference/date-title-fidelity.md` | Generierter Bericht (`./scripts/sim.sh report` bzw. Testlauf); bekommt Parser-Spalte + „Was danebenging" für den Parser |
| `docs/project/06-annahmen-und-experimente.md` | A3 „gemessen" mit Modell/NSDataDetector-Tabelle; Parser-Ergebnis kommt dazu |
| `docs/project/04-stand.md` | Zeilen 48–52: #67 → #92 verlinkt; nach Abschluss Status nachziehen |
| `project.yml` | `Measurement/` gehört zu LooseEndsTests, LooseEndsUITests, LooseEndsLab; `Shared/` zu allen App-Targets inkl. Watch |

## Korpus: Was der Parser erkennen muss (aus den 139 Datumssätzen)

| Ausdrucksart | Sätze | Formulierungen DE | Formulierungen EN |
|---|---|---|---|
| offsetDays | 56 | heute (noch/Abend), morgen (früh/Mittag), übermorgen, in drei/zwei/10/14/21 Tagen, in einer/zwei/vier Woche(n) | today, tomorrow (morning), the day after tomorrow, in three/10 days, in one/two week(s) |
| weekday | 27 | am Montag, Dienstag (ohne „am"), kommenden Freitag, diesen Donnerstag, bis Freitag, Freitag (Stichwort), Freitga (Tippfehler) | on Monday, Saturday, on Wednesday |
| endOfMonth | 11 | Ende des Monats, zum/bis Monatsende, bis Ende des Monats | at the end of the month, end of the month |
| weekdayEitherNext | 9 | nächsten Montag/Mittwoch/Freitag/Donnerstag | next Tuesday/Friday/Monday, by next Friday |
| dayOfMonth | 9 | bis zum 3./15./8./20., am 20. | by the 5th, on the 12th |
| weekend | 8 | am Wochenende, dieses Wochenende | this weekend, over the weekend |
| weekdayNextWeek | 7 | nächste Woche Freitag/Dienstag/Montag/Mittwoch (auch klein, Diktat) | – (keine EN-Sätze) |
| monthRange | 6 | nächsten Monat, im nächsten Monat | next month |
| dayAndMonth | 6 | am 4. Mai, 24. Dezember, 1. März, 31. Juli | on May 4th, on November 11 |

Bauformen mit Datum jenseits „standard": stichwort („Steuerberater morgen"), frage („bis Freitag?"),
ich-satz, nebensatz, diktat (kleingeschrieben, „ähm"), zeit-hinten, zwei-aufgaben, denglisch,
tippfehler („Freitga" — wird der Parser nicht treffen; das ist ein legitimer Fehlfall), praefix,
diktat-name.

**Uhrzeit (24 Sätze):** „um 20 Uhr", „um 7:30", „18:45" (ohne „um"), „9 Uhr" (ohne „um"), „um 12"
(nackte Zahl nach „Mittag"), „um halb zwölf/acht", „auf 10 Uhr", „at 5pm", „at 9am", „at 2:30 pm",
„at half past seven". 2 der 24 sind `repeat`-Sätze („Jeden Tag um 7 Uhr", „Werktags um 6:30",
„Every day at 8pm" → 3), die zählen für die Datumsmessung nicht, wohl aber für die Uhrzeitprüfung,
falls der Bericht Uhrzeit unabhängig vom Datum wertet — klären in der Spec.

**Fallen (Sätze ohne Datum, mit Zahlen/Zeitwörtern):** „Rechnung 4711", „250 Euro", „Zimmer 12",
„3 Kisten", „Gleis 9", „Police 30021988", „A-2291", „1,5 Liter", „Belege von 2025", „Svens
Geburtstag", `repeat`-Sätze „Jeden Montag", „Every day at 8pm", „Jeden ersten Montag im Monat".
Der Parser darf aus keinem davon ein Datum machen (0 % erfunden). Wiederholungen („jeden", „every",
„werktags") sind heute kein Datum; der Parser muss sie explizit als Nicht-Treffer behandeln.

## Existing Patterns
- **Wahrheit als Regel, nicht als Datum**: `DateExpectation` liefert die Menge zulässiger Tage gegen
  einen Referenztag. Der Parser sollte dasselbe Zwischenergebnis erzeugen (Ausdrucksart + Wert), damit
  Erkennung (RegEx) und Rechnung (Kalender) getrennt testbar sind und der Bericht je Ausdrucksart
  auswerten kann.
- **Mehrdeutigkeit**: `weekend` und `weekdayEitherNext` erlauben zwei Tage, `monthRange` einen ganzen
  Monat. Für die Messung reicht „ein Tag aus der Menge"; das Produkt (Schnitt 2) braucht genau ein
  Datum → Auswahlregel nötig (z. B. Wochenende = Samstag, „nächsten Freitag" = nächstes Vorkommen,
  „nächsten Monat" = erster Tag oder kein Datum). Das ist eine PO-Frage für die Spec.
- **Bericht-Spalten**: `Tally` mit `record(hit:empty:miss:)`; `scoreParser` läuft heute ohne
  Messlauf-Daten über den ganzen Korpus gegen `today`. Der neue Parser folgt demselben Muster, mit
  eigenem `Tally` und `byRule`-Aufschlüsselung, damit „nach Art des Ausdrucks" auch für den Parser
  steht.
- **`Bundle(for: CorpusAnchor.self)`** lädt den Korpus im Test-Bundle; auf dem Mac genügt die Datei
  neben der Quelle. Parser-Tests brauchen kein Gerät.
- **Sprachfaltung**: `TitleCheck.normalized` faltet Groß-/Kleinschreibung und Diakritika mit
  `de_DE`; für die Erkennung von „nächste"/„naechste" in Diktaten übertragbar.
- Deployment Target 27 → Swift `Regex` (Literal und Builder) uneingeschränkt verfügbar; keine
  `NSRegularExpression` nötig.

## Dependencies
- Upstream (Parser braucht): `Calendar` mit `firstWeekday = 2` für „nächste Woche" (siehe
  `inFollowingWeek`), Referenzdatum = `capturedAt` (Produkt) bzw. Messtag (Bericht), Sprache aus dem
  Text selbst (kein `lang`-Feld im Produkt → der Parser muss beide Sprachen gleichzeitig prüfen).
- Downstream (nutzt den Parser): Schnitt 1 nur `DateTitleReportTests`. Schnitt 2:
  `FoundationModelsEnricher`/`EnrichmentCoordinator` → `EnrichmentDraft.dueDate` → `EnrichmentWriter`
  → `TaskItem.dueDate/dueHasTime/dueSourceRaw/dueConfidence` → Views, `DueReminders`, `CalendarSync`,
  Watch/Widgets (alles über `Shared/`).
- **Strukturfrage**: Die Kalenderrechnung liegt in `Measurement/`, das nicht in `Shared/` kompiliert.
  Für Schnitt 2 muss sie nach `Shared/Services` wandern (und `Corpus.DateExpectation` sie von dort
  nutzen) oder der Parser bekommt eine eigene Kopie. Empfehlung in der Analyse.

## Existing Specs
- `docs/specs/measurement/issue-82-satzformen.md` — Korpus-Bauformen, Bericht nach Bauform
- `docs/specs/lab-83-foreground-measurement.md` — Labor-App, Messlauf in Scheiben
- `docs/context/issue-82-satzformen.md` — Kontext des Korpus-Umbaus
- Kein Spec für Enrichment-Schema oder Datumsfeld; Regeln stehen in `docs/project/00-entscheidungen.md`
  (ADR-3 Threshold, ADR-11 Stub-Enricher) und als Doc-Kommentare.

## Recherche (2026-09-20)
- `NSDataDetector` erkennt englische relative Ausdrücke („next Monday at 7 pm", „tomorrow at noon"),
  deutsche relative Ausdrücke („nächste Woche", „Wochenende", „Monatsende", „nächsten Monat") nicht;
  im Korpus 65 % exakt, 41 leer gelassen. Quellen:
  [Apple: NSDataDetector](https://developer.apple.com/documentation/foundation/nsdatadetector),
  [Ole Begemann: Working with Date and Time in Cocoa](https://oleb.net/blog/2011/11/working-with-date-and-time-in-cocoa-part-2/),
  [#92](https://github.com/henemm/loose-ends/issues/92).
- Fertige Swift-Bibliotheken: [SoulverCore DateParsing](https://github.com/soulverteam/DateParsing)
  (kommerzielles Binärpaket, deutsch lokalisiert, System-Locale statt Textsprache),
  [SwiftyChrono](https://github.com/quire-io/SwiftyChrono) (Port von chrono.js, nur Englisch, seit
  Jahren ohne Pflege). Beide sind neue Abhängigkeiten (laut Regeln nur mit Freigabe) und lösen weder
  die Zwei-Sprachen-im-selben-Text-Frage noch die Korpusregeln (Mehrdeutigkeit als Menge). Eigener
  Parser über die vorhandene Kalenderrechnung bleibt die Empfehlung; SoulverCore ist die Alternative,
  falls der eigene Parser unter 95 % bleibt.

## Risks & Considerations
- **95 % ist eine harte Grenze auf 139 Sätzen**: 7 Fehlversuche sind das Maximum. Der Tippfehler
  „Freitga" ist schon einer. Diktate ohne Großschreibung und mit Füllwörtern müssen sitzen.
- **0 % erfunden auf 170 Kontrollsätzen** heißt: Zahlen (4711, 250, 12, 9, 2025), Namen („Svens
  Geburtstag") und Wiederholungen („jeden Montag") dürfen nie zünden. Die RegEx muss Kontext
  verlangen (Präposition oder Ordnungspunkt), nicht bloß eine Zahl.
- **„Freitag Andrea die 250 Euro"**: Wochentag ohne Präposition am Satzanfang; „Laternenumzug Freitag"
  Wochentag am Ende. Der Parser muss Wochentage frei im Satz finden, aber „Jeden Montag" ausschließen.
- **„bis Freitag" / „by next Friday" / „bis zum 15."**: „bis" ändert die Rechnung nicht (Korpus
  behandelt es wie „am"), muss aber als Präposition akzeptiert werden.
- **Uhrzeit-Sonderfälle**: „halb zwölf" = 11:30 (deutsch: halb VOR), „half past seven" = 07:30
  (englisch: halb NACH); „um 12" ohne „Uhr" nur zünden, wenn davor ein Zeitkontext steht („Mittag");
  „Heute Abend um 20 Uhr" nicht als 20 Tage/Jahr; „auf 10 Uhr" (verschieben) ist eine Uhrzeit.
- **Zwei Datumsangaben im Satz** („Deadline für das Rollout am Freitag checken"): erstes Vorkommen
  gewinnt oder Präferenz nach Ausdrucksart — Spec-Entscheidung.
- **Schnitt 2 berührt `Shared/`**, das in Watch und Widgets kompiliert: kein SwiftUI, nur Foundation.
- **Konfidenz/Revision**: Ein Regeltreffer hat keine Modell-Konfidenz. `EnrichmentWriter` verlangt
  `confidence >= threshold`; der Parser setzt 1.0 oder das Draft bekommt einen eigenen Pfad.
  `dueSourceRaw` bleibt `ai` oder erhält einen neuen `FieldSource`-Wert (`rule`) — der Wert steuert
  `RevisionService.reset` und die KI-Markierung in den Views. PO-Frage.
- **Messtag-Abhängigkeit**: `scoreParser` rechnet gegen `Date()` des Berichtslaufs; der Bericht
  ändert sich also täglich, nur in den Fehlerlisten (Datum), nicht in den Quoten — außer bei
  `weekday` am Tag selbst (heute erlaubt) und Monatsgrenzen. Tests des Parsers selbst brauchen einen
  festen Referenztag wie `CorpusTests`.
- **Labor-App kompiliert das Schema mit**: Schnitt 2 muss `sim.sh lab` weiter bauen lassen.
- **Bericht-Tests sind `.enabled(if: !MeasurementFiles.runs.isEmpty)`**: Der Parser-Anteil hängt
  heute an vorhandenen Messläufen. Für Schnitt 1 sinnvoll: eigener Test ohne diese Bedingung, der den
  Parser über den ganzen Korpus rechnet und die 95 %/0 % als `#expect` festhält.

## Analysis

### Type
Feature (PO-Entscheidung „Regeln vor Modell", 2026-09-20). Zwei Lieferungen, Schnitt 2 erst nach
bestandener Messung in Schnitt 1.

### Affected Files (with changes)

**Schnitt 1 — Parser messen (drei Änderungen, jede unter 250 LoC)**

| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/DateExpressionParser.swift` | CREATE | Erkennung DE/EN je Ausdrucksart (RegEx) → `DateExpression` (gleiche neun Fälle wie `Corpus.DateExpectation`) + eigene Auflösung auf genau ein Datum. Nur `Foundation`. Wiederholungs-Sperre („jeden/every/werktags/täglich") als Vorstufe |
| `LooseEndsTests/DateExpressionParserTests.swift` | CREATE | Je Ausdrucksart DE + EN, fester Referenztag wie `CorpusTests.reference` (Do 12.3.2026), je Fall mindestens eine Falle |
| `Measurement/TimeExpressionParser.swift` | CREATE | Uhrzeit: `HH:MM(am/pm)`, `um/auf H Uhr`, `H Uhr`, `at H(am/pm)`, „halb X" (DE, vor der vollen Stunde), „half past X" (EN, danach), nackte Zahl nur mit Kontextwort; Zahlwort-Tabelle DE/EN |
| `LooseEndsTests/TimeExpressionParserTests.swift` | CREATE | Uhrzeit-Fälle inkl. „halb zwölf" = 11:30, „half past seven" = 07:30, „um 12" nach „Mittag", „Rechnung 4711" ≠ Uhrzeit |
| `LooseEndsTests/DateTitleReportTests.swift` | MODIFY | `scoreParser` misst zusätzlich den eigenen Parser (eigene `Tally` + `byRule` + Uhrzeit); `dateSection` dritte Spalte „Regelparser"; `missesSection` Block „Regelparser danebenging" mit Ausdrucksart |
| `LooseEndsTests/DateParserCorpusTests.swift` | CREATE | **Ungated** Abnahmetest (nicht an `MeasurementFiles.runs` gebunden): ganzer Korpus, fester Referenztag, `#expect` Datum ≥ 95 %, erfunden = 0 %, Uhrzeit ≥ 95 % |
| `docs/project/06-annahmen-und-experimente.md` | MODIFY | A3-Tabelle um Parser-Spalte ergänzen |
| `docs/reference/date-title-fidelity.md` | generiert | Wird vom Berichtslauf geschrieben, kein Autoren-Code |

**Schnitt 2 — App umbauen (erst nach bestandenem Schnitt 1, eigene Spec)**

| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/*Parser.swift` → `Shared/Services/` | MOVE | Reiner Umzug, keine Logikänderung; `project.yml` Lab-Pfade ergänzen |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | MODIFY | `ModelEnrichment` verliert `dueDate/dueTime/dueConfidence/dueReason`; `enrich(_:)` ruft den Parser auf `input.rawText` mit `input.capturedAt` (im Enricher, nicht im Coordinator, weil `MeasurementRunner.swift:138` den Enricher direkt aufruft) |
| `Shared/Enrichment/EnrichmentDraft.swift` | MODIFY | `EnrichmentParsing.dueDate(day:time:)` entfernen (einziger Produktaufrufer war der Enricher) |
| `LooseEndsTests/EnrichmentTests.swift` | MODIFY | `EnrichmentParsingTests` (224–241) entfernen, Enricher-Test „Datum kommt vom Parser" ergänzen |
| `docs/project/04-stand.md`, Issue #67 | MODIFY | Ergebnis eintragen, Abbruchkriterium „Datum" neu bewerten |

### Scope Assessment
- Schnitt 1: 7 Dateien in drei Änderungen — 1a Datum (2 Dateien, ~200–250 LoC), 1b Uhrzeit
  (2 Dateien, ~120–150), 1c Bericht + Abnahmetest + Doku (3 Dateien, ~100–150)
- Schnitt 2: ~5 Dateien, ~150–200 LoC; Schätzung erst nach Schnitt 1 verbindlich
- Risk Level: **LOW** (Schnitt 1: nur Messcode, kein Produktpfad) / **MEDIUM** (Schnitt 2: ändert
  Enrichment-Schema, das App, Labor-App und Watch mitkompilieren)

### Technical Approach
1. **Erkennung und Rechnung getrennt**, wie die Wahrheit im Korpus: RegEx liefert Ausdrucksart + Wert
   (`DateExpression`, neun Fälle identisch zu `Corpus.DateExpectation`), eine eigene Funktion löst sie
   gegen `capturedAt` auf genau ein Datum auf. Der Bericht prüft `accepted.contains(parserDate)` gegen
   `acceptedDays` — damit bleibt `Corpus.DateExpectation` die **unabhängige Referenz**. Deshalb wird
   die Kalenderrechnung **nicht** aus `Measurement/` nach `Shared/` gezogen und geteilt: teilten sich
   Parser und Referenz eine Funktion, würde ein Rechenfehler beide gleich verfälschen und die Messung
   sich selbst bestätigen. Die Doppelung ist die Absicherung, kein Makel.
2. **Ort in Schnitt 1: `Measurement/`** (kompiliert in LooseEndsTests, das genügt für Mac-Messung),
   nur `Foundation`, kein SwiftUI. Umzug nach `Shared/Services` in Schnitt 2 ist dann ein reines
   Verschieben. Das entspricht wörtlich der Vorgabe „erst wenn Schnitt 1 die 95 % zeigt, wird die App
   umgebaut".
3. **Beide Sprachen immer gleichzeitig** über den Text (kein `lang` im Produkt; Denglisch-Bauform).
   Erkennung auf gefaltetem Text (Kleinschreibung, Diakritika wie `TitleCheck.normalized`), damit
   Diktate („ähm nächste woche freitag") treffen.
4. **Mehrfachtreffer:** frühester Fundort im Text gewinnt; bei gleicher Position die spezifischere
   Regel (dayAndMonth > dayOfMonth > weekdayNextWeek > weekdayEitherNext > weekday).
5. **Wiederholungs-Sperre vor der Erkennung:** steht „jeden/jede/every/werktags/täglich/wöchentlich/
   monatlich" unmittelbar vor dem Ausdruck, kein Datum (Wiederholung ist heute kein Datum, #92).
6. **Zahlen brauchen Kontext:** Tagesnummer nur mit Ordnungspunkt und Präposition („bis zum 15.",
   „am 20.", „by the 5th", „on the 12th"); Uhrzeit nur mit „Uhr", Doppelpunkt, am/pm oder „um/auf/at".
   So bleiben 4711, 250 Euro, Zimmer 12, Gleis 9, A-2291, 1,5 Liter, 2025 Nicht-Treffer.
7. **Uhrzeit-Parser getrennt vom Datum**, mit zwei gegensätzlichen Halb-Regeln (DE „halb zwölf" =
   11:30, EN „half past seven" = 07:30) und Zahlwort-Tabelle eins…zwölf / one…twelve.
8. **Abnahme ungated und mit festem Referenztag** (Do 12.3.2026 wie `CorpusTests`), damit die 95 %/0 %
   in CI reproduzierbar sind; die Berichtsspalte rechnet weiter gegen den Messtag (`Date()`).
9. **Schnitt 2:** Parser-Aufruf in `FoundationModelsEnricher.enrich(_:)` (nach der Modellantwort),
   nicht im Coordinator, weil die Labor-App den Enricher direkt aufruft (`MeasurementRunner.swift:138`).
   Konfidenz fix 1.0, `dueSourceRaw = ai` beibehalten (Verwender: `EnrichmentWriter.swift:21`,
   `RevisionService.aiSetFields`, `TaskRow.swift:20/82`, `Revision.swift:13`).

**Alternativen (Henning, „in Alternativen denken"):**
- *Ein gemeinsamer Ein-Pass-Parser für Datum und Uhrzeit* (Grammatik wie chrono.js/SwiftyChrono):
  ein Regelwerk statt zwei, aber die Sonderfälle (halb-vor vs. half-past, Wochentag ohne Präposition,
  Diktat) sind je Ausdrucksart getrennt besser testbar. Bei 7 erlaubten Fehlern auf 139 Sätzen zählt
  Testbarkeit mehr. Verworfen.
- *`NSDataDetector` zuerst, eigener Parser nur für die Lücken* (Issue-Alternative): spart wenig, weil
  der Detector die deutschen Ausdrücke (89 der 139 Sätze sind DE) ohnehin nicht kennt und bei
  Uhrzeiten eigene Regeln nötig bleiben; außerdem zwei Rechenwege im Bericht. Bleibt Plan B, falls der
  Parser unter 95 % bleibt.
- *SoulverCore DateParsing* (Recherche Phase 1): neue Binärabhängigkeit, System-Locale statt
  Textsprache, keine Tagesmenge. Plan C.
- *Neuer `FieldSource.rule`* statt `ai`: erlaubt der Oberfläche „Regel exakt" von „Modell geraten" zu
  unterscheiden; kostet ~4 Dateien/~20 LoC und ändert kein Ziel dieses Tickets. Als Folge-Issue
  vormerken, nicht in Schnitt 2.

### Dependencies
- Parser braucht: `Calendar` (Gregorian, `firstWeekday = 2` für „nächste Woche"), Referenzdatum
  (`capturedAt` im Produkt, Messtag im Bericht, fester Tag im Abnahmetest), nichts aus dem Modell.
- Schnitt 1 hängt nur an `Corpus.DateExpectation.acceptedDays` (Referenz) und `Corpus.Entry.time`.
- Schnitt 2 hängt an Schnitt 1 (≥ 95 %/0 % bewiesen) und an den PO-Antworten unten.
- Bericht-Suite `DateTitleReportTests` bleibt `.enabled(if: !MeasurementFiles.runs.isEmpty)`; nur die
  beschreibende Spalte hängt daran, die Abnahme nicht.

### Open Questions (PO — nur für Schnitt 2 nötig; Schnitt 1 läuft mit den Empfehlungen)
- [ ] **„am Wochenende" → welcher Tag?** Empfehlung: Samstag (erster freier Tag). Alternative: Sonntag.
- [ ] **„nächsten Freitag" → nächstes Vorkommen oder übernächste Woche?** Empfehlung: nächstes
      Vorkommen (zu früh erinnert ist harmloser als eine Woche zu spät). Beide gelten im Korpus.
- [ ] **„nächsten Monat" → 1. des Folgemonats oder kein Datum?** Empfehlung: 1. des Folgemonats
      (der Nutzer hat einen Zeitraum genannt, ein leeres Feld wirft ihn weg; per Revision korrigierbar).
      Alternative: kein Datum, weil kein Tag genannt. Für die Messung zählt beides als Treffer.
- [ ] **Kennzeichnung:** Datum aus dem Parser weiter als „KI" markiert (`ai`) oder neuer Wert „Regel"?
      Empfehlung: `ai` beibehalten, „Regel" als Folge-Issue.
- [ ] **Uhrzeit-Wertung im Bericht:** heute nur bei Sätzen, die für das Datum zählen (`repeat`-Sätze
      ausgenommen, also 21 von 24). Empfehlung: Parser-Uhrzeit auf allen 24 werten, weil die Uhrzeit
      einer Wiederholung („jeden Tag um 7 Uhr") später gebraucht wird. Kein Produktthema, Spec legt es fest.
