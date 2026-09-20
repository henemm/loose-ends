---
entity_id: feat-92-date-parser
type: feature
created: 2026-09-20
updated: 2026-09-20
status: validated
workflow: feat-92-date-parser
---

# Spec: #92 — Datum regelbasiert: Zeitausdruck-Parser DE/EN (Schnitt 1: Parser messen)

**Status:** validated · **Workflow:** feat-92-date-parser · **Erstellt:** 2026-09-20 · **Aktualisiert:** 2026-09-20

## Freigabe

- [x] Freigegeben

## Problem
Das Datum kommt heute vom On-Device-Modell. Gemessen am 2026-09-20 (#67, #92): 50 % exakt, 96,5 %
erfunden. `NSDataDetector` als Regel-Baseline liegt bei 65 % exakt, 0 % erfunden, erkennt aber keine
deutschen relativen Ausdrücke („nächste Woche", „Monatsende", „nächsten Monat") — 89 der 139
Datumssätze im Korpus sind Deutsch. Nach der PO-Entscheidung „Regeln vor Modell" (2026-09-20, zum
zweiten Mal) wird alles, was sich mit Regeln lösen lässt, mit Regeln gelöst; das Modell bekommt nur,
was Sprachverstehen braucht (den Titel). Ohne eigenen Parser bleibt Datum entweder beim Modell
(50 %/96,5 % erfunden) oder bei `NSDataDetector` (65 %, aber blind für Deutsch).

## Zweck
Ein reiner, deterministischer Zeitausdruck-Parser (Datum und Uhrzeit, Deutsch und Englisch im selben
Text) ersetzt in der Messung das Modell und `NSDataDetector`. Der Bericht bekommt eine dritte Spalte
„Regelparser", damit die Trefferquote des eigenen Parsers neben Modell und `NSDataDetector` sichtbar
wird — als Nachweis, bevor die App umgebaut wird (Schnitt 2).

## Quelle
- **Datei:** `Measurement/DateExpressionParser.swift` (neu)
- **Bezeichner:** `enum DateExpression`, `struct DateExpressionParser`
- **Datei:** `Measurement/TimeExpressionParser.swift` (neu)
- **Bezeichner:** `struct TimeExpressionParser`
- **Referenz (unverändert, bleibt unabhängig):** `Measurement/Corpus.swift`, `enum Corpus.DateExpectation`, `func acceptedDays(reference:calendar:)`

## Acceptance Criteria

- **AC-1 Datum ≥ 95 % exakt:** Given die 139 Datumssätze des Korpus und ein fester Referenztag
  Do 12.3.2026 / When `DateExpressionParser` jeden Satz parst und das Ergebnis gegen
  `Corpus.DateExpectation.acceptedDays(reference:calendar:)` prüft / Then liegt die Trefferquote bei
  mindestens 95 % (höchstens 7 Fehlversuche), aufgeschlüsselt je Ausdrucksart (`offsetDays`,
  `weekday`, `endOfMonth`, `weekdayEitherNext`, `dayOfMonth`, `weekend`, `weekdayNextWeek`,
  `monthRange`, `dayAndMonth`).
- **AC-2 0 % erfunden auf den Kontrollsätzen:** Given die 178 Sätze ohne Datumserwartung (170 echte
  Kontrollsätze plus 8 `repeat`-Sätze) inklusive der Zahlenfallen „Rechnung 4711", „250 Euro",
  „Zimmer 12", „3 Kisten", „Gleis 9", „Police 30021988", „A-2291", „1,5 Liter", „Belege von 2025",
  „Svens Geburtstag" und der Wiederholungen „jeden Montag", „every day at 8pm", „Jeden ersten Montag
  im Monat" / When der Parser sie verarbeitet / Then liefert er für keinen dieser Sätze ein Datum
  (0 % erfunden).
- **AC-3 Uhrzeit ≥ 95 %:** Given alle 24 Uhrzeit-Sätze des Korpus (inklusive der 3 `repeat`-Sätze
  „Jeden Tag um 7 Uhr", „Werktags um 6:30", „Every day at 8pm") und derselbe feste Referenztag / When
  `TimeExpressionParser` sie parst / Then trifft er mindestens 95 % (höchstens 1 Fehlversuch) exakt
  auf Stunde und Minute. Uhrzeit wird unabhängig davon gewertet, ob der Satz für die Datumsmessung
  zählt — die Uhrzeit einer Wiederholung („jeden Tag um 7 Uhr") wird später gebraucht (Schnitt 2),
  darum zählen alle 24 Sätze, nicht nur die 21 mit eigener Datumserwartung.
- **AC-4 Je Ausdrucksart ein Unit-Test mit Falle:** Given jede der neun Datums-Ausdrucksarten und die
  Uhrzeit-Sonderfälle / When `DateExpressionParserTests` bzw. `TimeExpressionParserTests` laufen /
  Then existiert für jede Art mindestens ein Test in Deutsch und einer in Englisch (wo im Korpus
  vorhanden) sowie eine Falle, die keinen Treffer erzeugen darf (z. B. „Jeden Montag" bei `weekday`,
  „Rechnung 4711" bei Uhrzeit).
- **AC-5 Bericht zeigt den Regelparser:** Given ein Berichtslauf über den Korpus / When
  `DateTitleReportTests` den Bericht baut / Then enthält die Datumstabelle eine dritte Spalte
  „Regelparser" neben „Modell" und „NSDataDetector", mit Aufschlüsselung nach Ausdrucksart, und ein
  eigener Block „Regelparser danebenging" listet jeden verfehlten Satz mit erwarteter Ausdrucksart
  und dem tatsächlichen Parser-Ergebnis (Treffer, Fehltreffer oder leer).
- **AC-6 Abnahmetest ungated und in CI:** Given der volle Korpus und ein fester Referenztag / When
  `DateParserCorpusTests` läuft / Then wertet er AC-1, AC-2 und AC-3 als `#expect`-Aussagen, ohne an
  `MeasurementFiles.runs` (vorhandene Messläufe) gebunden zu sein, und läuft damit auch in CI ohne
  vorherigen Messlauf auf einem Gerät.
- **AC-7 Bestehende Tests bleiben grün:** Given der neue Parser-Code / When `./scripts/sim.sh unit`
  läuft / Then bestehen alle bisherigen Suiten (`CorpusTests`, `DateTitleReportTests`,
  `EnrichmentTests`) unverändert, weil Schnitt 1 keinen Produktpfad berührt.

## Nicht in diesem Schnitt
Schnitt 2 (App-Umbau) folgt erst, wenn Schnitt 1 die 95-%-Grenze zeigt („Erst wenn Schnitt 1 die
95 % zeigt, wird die App umgebaut", #92). Bis dahin bleibt der Parser reiner Messcode ohne
Produktwirkung:
- Umzug von `DateExpressionParser`/`TimeExpressionParser` nach `Shared/Services`, damit
  `FoundationModelsEnricher` sie aufrufen kann.
- Entfernen der Datumsfelder aus `ModelEnrichment` (`dueDate`, `dueTime`, `dueConfidence`,
  `dueReason`) und der zugehörigen Instruktionen.
- Aufruf des Parsers in `FoundationModelsEnricher.enrich(_:)` und Wegfall von
  `EnrichmentParsing.dueDate(day:time:)`.
- Simulator-Nachweis und Eintrag des Ergebnisses in #67 / `docs/project/04-stand.md`.
- Verbindliche PO-Entscheidung zu den fünf offenen Fragen unten (Auflösung auf genau ein Datum,
  Kennzeichnung als `ai` oder neuer `FieldSource`-Wert).

Jeder dieser Punkte gehört in eine eigene Spec nach Abschluss von Schnitt 1, nicht in diese.

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `Corpus.DateExpectation.acceptedDays(reference:calendar:)` | Funktion | Unabhängige Referenz-Kalenderrechnung; der Parser prüft `accepted.contains(parserDate)` dagegen, teilt sich aber keinen Code mit ihr (siehe Technische Umsetzung, Punkt 1). |
| `Corpus.weekdayNames` | Konstante | Wochentagsnamen für die Referenzberechnung; der Parser bildet eigene Wochentags-Erkennung DE/EN darauf ab. |
| `Corpus.Entry.time` | Feld | Wahrheit „HH:mm" je Uhrzeit-Satz, Vergleichsbasis für `TimeExpressionParserTests` und den Bericht. |
| `date-title-corpus.json` | Daten | 317 Sätze (242 DE, 75 EN), 139 mit Datumserwartung, 178 ohne, 24 mit Uhrzeit — Grundlage aller ACs. |
| `TitleCheck.normalized` | Funktion | Vorbild für die Sprachfaltung (Klein-/Großschreibung, Diakritika, `de_DE`) auf dem der Parser Diktate erkennt. |
| `Calendar` (Gregorian, `firstWeekday = 2`) | System-API | Referenzberechnung für „nächste Woche" analog `Corpus.inFollowingWeek`. |
| `Swift Regex` (Literal/Builder) | Sprach-Feature | Erkennung, verfügbar ab Deployment Target 27 ohne `NSRegularExpression`. |
| `DateTitleReportTests.scoreParser`, `Tally`, `ruleName` | Bestehender Code | Muster für die neue Regelparser-Spalte: eigene `Tally` + `byRule`-Aufschlüsselung nach demselben Schema wie die bestehende `NSDataDetector`-Messung. |

## Umfang

Schnitt 1 ist in drei Teillieferungen geschnitten, weil der Gesamtumfang über der 250-LoC-Grenze
liegt: 1a Datum-Parser, 1b Uhrzeit-Parser, 1c Bericht-Spalte + Abnahmetest + Doku. Jede Teillieferung
bleibt für sich unter 250 LoC und liefert eigenständig lauffähigen, getesteten Code.

### Betroffene Dateien

**1a — Datum-Parser (2 Dateien, ~200–250 LoC)**

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/DateExpressionParser.swift` | CREATE | Erkennung DE/EN je Ausdrucksart per `Regex` → `enum DateExpression` (dieselben neun Fälle wie `Corpus.DateExpectation`) plus eigene Auflösung auf genau ein Datum. Nur `Foundation`, kein SwiftUI. Wiederholungs-Sperre (jeden/jede/every/werktags/täglich/wöchentlich/monatlich) als Vorstufe vor der Erkennung. |
| `LooseEndsTests/DateExpressionParserTests.swift` | CREATE | Je Ausdrucksart mindestens ein DE- und ein EN-Test (wo im Korpus vorhanden), fester Referenztag wie `CorpusTests.reference` (Do 12.3.2026), je Fall mindestens eine Falle. |

**1b — Uhrzeit-Parser (2 Dateien, ~120–150 LoC)**

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/TimeExpressionParser.swift` | CREATE | Uhrzeit-Erkennung: `HH:MM(am/pm)`, „um/auf H Uhr", „H Uhr" (ohne „um"), „at H(am/pm)", „halb X" (DE, vor der vollen Stunde), „half past X" (EN, nach der vollen Stunde), nackte Zahl nur mit Zeitkontextwort (z. B. „Mittag"); Zahlwort-Tabelle DE/EN eins…zwölf / one…twelve. |
| `LooseEndsTests/TimeExpressionParserTests.swift` | CREATE | Uhrzeit-Fälle inklusive „halb zwölf" = 11:30, „half past seven" = 07:30, „um 12" nur nach „Mittag", „Rechnung 4711" liefert keine Uhrzeit. |

**1c — Bericht-Spalte, Abnahmetest, Doku (3 Dateien, ~100–150 LoC)**

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `LooseEndsTests/DateTitleReportTests.swift` | MODIFY | `scoreParser` misst zusätzlich den eigenen Parser (eigene `Tally` + `byRule`-Aufschlüsselung + Uhrzeit-Tally); `dateSection` bekommt dritte Spalte „Regelparser"; `missesSection` bekommt Block „Regelparser danebenging" mit Ausdrucksart und Parser-Ergebnis. |
| `LooseEndsTests/DateParserCorpusTests.swift` | CREATE | Ungated Abnahmetest (nicht an `MeasurementFiles.runs` gebunden): ganzer Korpus, fester Referenztag, `#expect` für Datum ≥ 95 % exakt, 0 % erfunden, Uhrzeit ≥ 95 %. |
| `docs/project/06-annahmen-und-experimente.md` | MODIFY | A3-Tabelle um Spalte „Regelparser" ergänzt, mit den gemessenen Werten aus 1c. |

`docs/reference/date-title-fidelity.md` ist generiert (Berichtslauf), kein Autoren-Code — keine
eigene Zeile in der Dateitabelle, aber Wirkung von 1c.

### Geschätzter Umfang
- Dateien im Scope: 7 (in drei Teillieferungen à 2–3 Dateien)
- LoC gesamt: ca. +420 bis +550 (1a ~200–250, 1b ~120–150, 1c ~100–150), je Teillieferung unter der
  250-LoC-Grenze
- Risiko: NIEDRIG — nur Messcode in `Measurement/` und `LooseEndsTests/`, kein Produktpfad

## Technische Umsetzung
1. **Erkennung und Rechnung getrennt, bewusste Doppelung der Kalenderrechnung.** `DateExpression`
   liefert Ausdrucksart + Wert, eine eigene Funktion löst sie gegen `capturedAt`/den Referenztag auf
   genau ein Datum auf. Der Bericht prüft `accepted.contains(parserDate)` gegen
   `Corpus.DateExpectation.acceptedDays`. `Corpus.DateExpectation` bleibt dabei die unabhängige
   Referenz — sie wird nicht mit dem Parser geteilt, weil ein gemeinsamer Rechenfehler sonst beide
   gleich verfälschen und die Messung sich selbst bestätigen würde. Die Doppelung ist die
   Absicherung, kein Makel.
2. **Ort in Schnitt 1: `Measurement/`**, kompiliert in `LooseEndsTests`, `LooseEndsUITests` und
   `LooseEndsLab` — für die Mac-Messung genügt das. Nur `Foundation`, kein SwiftUI. Der Umzug nach
   `Shared/Services` ist Schnitt 2 vorbehalten.
3. **Beide Sprachen gleichzeitig auf gefaltetem Text.** Kein `lang`-Feld im Produkt und Denglisch-
   Bauformen im Korpus verlangen, dass DE- und EN-Regeln immer parallel geprüft werden, auf klein
   geschriebenem, diakritik-gefaltetem Text (analog `TitleCheck.normalized`), damit Diktate wie „ähm
   nächste woche freitag" treffen.
4. **Mehrfachtreffer:** Der früheste Fundort im Text gewinnt; bei gleicher Position die spezifischere
   Regel in der Reihenfolge `dayAndMonth` > `dayOfMonth` > `weekdayNextWeek` > `weekdayEitherNext` >
   `weekday`.
5. **Wiederholungs-Sperre vor der Erkennung:** Steht „jeden/jede/every/werktags/täglich/wöchentlich/
   monatlich" unmittelbar vor dem Ausdruck, entsteht kein Datumstreffer — Wiederholung ist heute kein
   Datum (#92).
6. **Zahlen brauchen Kontext.** Eine Tagesnummer zündet nur mit Ordnungspunkt und Präposition („bis
   zum 15.", „am 20.", „by the 5th", „on the 12th"); eine Uhrzeit nur mit „Uhr", Doppelpunkt, am/pm
   oder einer Präposition „um/auf/at". Damit bleiben 4711, 250 Euro, Zimmer 12, Gleis 9, A-2291,
   1,5 Liter und 2025 Nicht-Treffer.
7. **Uhrzeit-Parser getrennt vom Datum**, mit zwei gegensätzlichen Halb-Regeln: Deutsch „halb zwölf"
   = 11:30 (halb VOR der vollen Stunde), Englisch „half past seven" = 07:30 (halb NACH), plus
   Zahlwort-Tabelle eins…zwölf / one…twelve.
8. **Abnahme mit festem Referenztag** (Do 12.3.2026, wie `CorpusTests.reference`), damit die 95 %/
   0 % in CI reproduzierbar sind. Die Berichtsspalte (1c, `DateTitleReportTests`) rechnet weiter
   gegen den tatsächlichen Messtag (`Date()`), wie die bestehende `NSDataDetector`-Spalte.
9. **Auflösung auf genau ein Datum für die Messung** (Arbeitsstand Schnitt 1, endgültige
   PO-Entscheidung erst in Schnitt 2): Wochenende = Samstag, „nächsten Freitag" = nächstes
   Vorkommen, „nächsten Monat" = 1. des Folgemonats. Für die Messung selbst zählt jeder Tag aus der
   von `acceptedDays` gelieferten Menge als Treffer — die Auflösungsregel legt nur fest, welchen der
   zulässigen Tage der Parser für seine eigene Ausgabe wählt, damit die Uhrzeit-Kombination und der
   Bericht ein einzelnes Datum anzeigen können.

### Alternativen
- **Ein gemeinsamer Ein-Pass-Parser für Datum und Uhrzeit** (Grammatik-Ansatz wie chrono.js/
  SwiftyChrono): ein Regelwerk statt zwei getrennter. Verworfen, weil die Sonderfälle (halb-vor vs.
  half-past, Wochentag ohne Präposition, Diktat-Bauformen) je Ausdrucksart einzeln besser testbar
  sind — bei nur 7 erlaubten Fehlern auf 139 Sätzen zählt Testbarkeit mehr als Kompaktheit. Kippt
  keine bestehende ADR.
- **`NSDataDetector` zuerst, eigener Parser nur für die Lücken:** spart wenig, weil der Detector die
  deutschen Ausdrücke (89 der 139 Datumssätze sind Deutsch) ohnehin nicht erkennt und bei Uhrzeiten
  eigene Regeln nötig bleiben; zusätzlich zwei Rechenwege im Bericht. Bleibt Plan B, falls der
  eigene Parser unter 95 % bleibt. Kippt keine bestehende ADR.
- **SoulverCore DateParsing** (kommerzielles Binärpaket, deutsch lokalisiert): neue Abhängigkeit
  (laut Projektregel nur mit expliziter Freigabe), System-Locale statt Textsprache, keine Tagesmenge
  wie `acceptedDays`. Plan C, falls der eigene Parser scheitert. Würde, wenn gewählt, eine neue
  Abhängigkeits-Freigabe nötig machen — bisher gibt es keine ADR gegen Fremdbibliotheken, aber die
  Projektregel „keine neuen Dependencies ohne explizite Freigabe" (CLAUDE.md) wäre der Prüfpunkt.
- **Neuer `FieldSource.rule` statt `ai`:** würde der Oberfläche erlauben, „Regel exakt" von „Modell
  geraten" zu unterscheiden. Verworfen für diesen Schnitt, weil es kein Ziel dieses Tickets ist und
  ~4 Dateien/~20 LoC zusätzlich kostet, die nichts an der 95-%-Messung ändern. Als Folge-Issue
  vormerken, nicht in Schnitt 2. Kippt keine bestehende ADR.

### Offene PO-Fragen (nur Schnitt 2)
Schnitt 1 läuft mit den unten genannten Empfehlungen und braucht keine Antwort. Die Fragen werden
erst relevant, wenn Schnitt 1 die 95 % zeigt und die App umgebaut wird:
- **„am Wochenende" → welcher Tag?** Empfehlung: Samstag (erster freier Tag). Alternative: Sonntag.
- **„nächsten Freitag" → nächstes Vorkommen oder übernächste Woche?** Empfehlung: nächstes Vorkommen
  (zu früh erinnert ist harmloser als eine Woche zu spät). Beide Lesarten gelten im Korpus.
- **„nächsten Monat" → 1. des Folgemonats oder kein Datum?** Empfehlung: 1. des Folgemonats (der
  Nutzer hat einen Zeitraum genannt, ein leeres Feld wirft ihn weg; per Revision korrigierbar).
  Alternative: kein Datum, weil kein Tag genannt wurde.
- **Kennzeichnung des Feldursprungs:** `dueSourceRaw = ai` beibehalten oder neuer Wert „Regel"?
  Empfehlung: `ai` beibehalten, „Regel" als eigenes Folge-Issue (siehe Alternative oben).
- **Uhrzeit-Wertung im Bericht:** unabhängig vom Datum werten (alle 24 Sätze) oder nur bei Sätzen mit
  eigener Datumserwartung (21 von 24)? Diese Spec entscheidet für Schnitt 1 bereits: unabhängig
  werten (AC-3), weil die Uhrzeit einer Wiederholung später gebraucht wird. Für Schnitt 2 bestätigt
  oder revidiert der PO das nur, falls sich am Produktverhalten für Wiederholungen etwas ändert.

## Testplan

### Automatisierte Tests (TDD RED)
- [x] `DateExpressionParserTests`, je Ausdrucksart mindestens ein DE- und ein EN-Fall: GIVEN ein Satz
  mit einer der neun Ausdrucksarten und ein fester Referenztag (Do 12.3.2026) / WHEN
  `DateExpressionParser` ihn parst / THEN liefert er dieselbe Ausdrucksart und einen Tag aus
  `Corpus.DateExpectation.acceptedDays` (AC-1, AC-4).
- [x] `DateExpressionParserTests`, je Ausdrucksart eine Falle: GIVEN ein Kontrollsatz ohne Datum
  (Zahlenfalle oder Wiederholung wie „Jeden Montag") / WHEN der Parser ihn verarbeitet / THEN liefert
  er kein Datum (AC-2, AC-4).
- [x] `TimeExpressionParserTests`, Kernfälle: GIVEN „um 20 Uhr", „18:45", „halb zwölf", „half past
  seven", „at 5pm" / WHEN `TimeExpressionParser` sie parst / THEN stimmt Stunde und Minute exakt mit
  der Korpus-Wahrheit überein (AC-3, AC-4).
- [x] `TimeExpressionParserTests`, Kontext-Fälle: GIVEN „um 12" nach „Mittag" vs. „Rechnung 4711" /
  WHEN der Parser beide verarbeitet / THEN liefert nur der erste eine Uhrzeit (AC-3, AC-4).
- [x] `DateParserCorpusTests` (ungated): GIVEN der volle Korpus (317 Sätze) und derselbe feste
  Referenztag / WHEN der Test über alle Sätze läuft / THEN hält er per `#expect` fest: Datum ≥ 95 %
  exakt auf den 139 Datumssätzen, 0 % erfunden auf den 178 Kontrollsätzen, Uhrzeit ≥ 95 % auf allen
  24 Uhrzeit-Sätzen — unabhängig von `MeasurementFiles.runs` (AC-1, AC-2, AC-3, AC-6).
- [x] `DateTitleReportTests`, neue Spalte: GIVEN vorhandene Messläufe / WHEN der Bericht gebaut wird
  / THEN enthält `dateSection` die Spalte „Regelparser" mit Aufschlüsselung nach Ausdrucksart, und
  `missesSection` einen Block „Regelparser danebenging" mit Satz, erwarteter Ausdrucksart und
  Parser-Ergebnis (AC-5).
- [x] Bestehende Suiten (`CorpusTests`, `DateTitleReportTests`-Bestand, `EnrichmentTests`): GIVEN der
  neue Parser-Code / WHEN `./scripts/sim.sh unit` läuft / THEN bleiben alle unverändert grün, keine
  Regression (AC-7).

Kein UI-Test: Schnitt 1 ändert keinen Produktcode und keine View — der Parser lebt ausschließlich in
`Measurement/` und `LooseEndsTests/`. Nachweis läuft über den Mac-Testlauf und den generierten
Bericht, nicht über die App oder den Simulator.

## Definition of Done

- [x] AC-1 bis AC-7 erfüllt, belegt durch die im Testplan genannten Tests
- [x] `./scripts/sim.sh unit` grün
- [ ] CI grün
- [x] `docs/reference/date-title-fidelity.md` neu erzeugt, zeigt die Spalte „Regelparser" mit
  gemessenen Werten
- [ ] PR mit `Closes` auf ein neu anzulegendes Sub-Issue von #92 für Schnitt 1 gemergt
- [ ] Hennings Hauptordner nachgezogen und Projekt neu erzeugt
  (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] Sub-Issue für Schnitt 2 (App-Umbau) angelegt und in #92 verlinkt
- [x] A3-Tabelle in `docs/project/06-annahmen-und-experimente.md` um die Regelparser-Spalte ergänzt

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Der neue Code liegt vollständig in `Measurement/` und `LooseEndsTests/` — Messcode,
  kein Produktpfad, keine neue Abhängigkeit, kein Eingriff in `Shared/`. Die zugrunde liegende
  Produktentscheidung „Regeln vor Modell" ist bereits als Grundsatz in `CLAUDE.md` und
  `docs/project/00-entscheidungen.md` (Abschnitt „Rules before the model") festgehalten; ein Blick in
  die ADR-Kurzform (ADR-1 bis ADR-17) zeigt keinen eigenen ADR-Eintrag dazu, weil sie als
  projektweite Arbeitsregel geführt wird, nicht als Einzelentscheidung zu einem Baustein. Diese Spec
  setzt die Regel für das Datumsfeld um, führt aber keinen neuen Architekturbaustein ein, der einen
  eigenen ADR-Eintrag rechtfertigt.

## Changelog

- 2026-09-20: Spec aus dem Analyse-Kontext (`docs/context/feat-92-date-parser.md`) erstellt.
- 2026-09-20: Validiert — 138/139 Datum, 0/170 erfunden, 24/24 Uhrzeit; 119 Tests grün.
