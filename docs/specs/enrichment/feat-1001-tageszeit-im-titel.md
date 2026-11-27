---
entity_id: feat-1001-tageszeit-im-titel
type: feature
created: 2026-11-27
updated: 2026-11-27
status: draft
workflow: feat-1001-regeln-schaerfen
---

# Spec: Tageszeitwörter am Datum fallen aus dem Titel (Feature #1001, Epic #999)

## Approval

- [ ] Approved

## GitHub Issue

#1001 (Epic #999, ADR-22). Seit #982 setzen nur noch Regeln Titel und Felder. Lücke: „Pakete wegbringen heute Morgen“
ergibt den Titel „Pakete wegbringen Morgen“. Kontext und Auswertung: `docs/context/feat-1001-regeln-schaerfen.md`.

## Purpose

`TitleRule` streicht heute nur die Spans des Fälligkeitsdatums. Tageszeitwörter direkt am Datum („heute Abend“, „morgen früh“,
„tomorrow morning“) bleiben als Rest im Titel stehen („Abend Oma anrufen“). Der Schnitt streicht sie mit, wenn sie unmittelbar
an einem Datumsausdruck hängen, und lässt „tonight“ das Datum heute setzen. Es wird nichts erfunden: keine Uhrzeit aus einer Tageszeit.

## Messung an Hennings eigenen Erfassungen (2026-11-27, einmaliger lesender Export nach seinem Wort)

41 Sätze mit Titelkorrektur; die heutige Regel trifft seinen Titel bei 14 von 41. Regelseitig behebbar sind 2 davon (Klasse
Tageszeit am Datum); erwartet nach dem Schnitt 16 von 41. Die übrigen Abweichungen sind Hörfehler, inhaltliche Umformulierungen
und Einzelfälle, die keine Regel lösen (Einzelheiten im Kontext-Dokument, ohne Sätze).

## Alternativen

1. **Nur mit gesetzter Uhrzeit streichen.** Verworfen: erfüllt das Issue-Beispiel „Pakete wegbringen heute Morgen“ nicht (keine Zahl, keine Uhrzeit).
2. **Tageszeit setzt eine Uhrzeit** („heute Abend“ → 18:00). Verworfen: erfunden; widerspricht „nichts dazuerfunden“ (ADR-22) und #217 (Titel streicht nur, was ein Feld setzt, hier das Datum).
3. **Parser lernt die Tageszeiten** (Variante B). Verworfen: mehr Code, gleiches Ergebnis im Titel.
4. **Titel = Rohtext, Datum nur im Feld.** Würde #217 kippen; verworfen.

Gewählt: Variante A, Wortliste im `LanguagePack`, Erweiterung in `TitleRule`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR (Bezug ADR-22 und #217)
- **Rationale:** Regelweg statt Modell ist durch ADR-22 gesetzt; die Streichung folgt #217 (nur Wörter, die ein Feld setzen, gehen aus dem Titel). Eine Wortliste je Sprache ist das bestehende Muster; keine Entscheidung, die eine ADR bräuchte.

## Source

- **File:** `Shared/Services/TitleRule.swift`
- **Identifier:** `TitleRule.strippingRuleWords` (neu: Erweiterung des Datums-Spans um Tageszeitwörter)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `DueDateRule.match` (`Shared/Enrichment/DueDateRule.swift`) | function | liefert die Datums-Spans; bleibt unverändert |
| `LanguagePack` / `LanguagePacks` | module | neues Feld `dayParts` je Sprache |
| `EnglishPack.relativeDays` | table | bekommt `"tonight": 0` |
| `CaptureService` (Zeile 33), `RevisionService` (Zeile 55), `SiriCapture` (Zeile 182) | caller | rufen `TitleRule.title`; Signatur unverändert |
| `RuleGoldenTests`, `LanguagePackConformanceTests`, `Language/TestPack.swift` | tests | Golden-Fixture und Test-Pack müssen das neue Feld kennen |

Teilaufgaben nutzen `TitleRule` nicht; Claude- und Tastatur-Titel bleiben unberührt (#953, #950).

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Language/LanguagePack.swift` | MODIFY | Feld `dayParts` und Zugriff `LanguagePacks.dayParts` |
| `Shared/Language/GermanPack.swift` | MODIFY | de: abend, früh, mittag, vormittag, nachmittag, nacht; „morgen“ nur direkt nach einem Tag-Span |
| `Shared/Language/EnglishPack.swift` | MODIFY | en: morning, afternoon, evening, night, noon; `relativeDays["tonight"] = 0` |
| `Shared/Services/TitleRule.swift` | MODIFY | Datums-Span um angrenzende Tageszeitwörter erweitern, samt „am“/„in the“ davor |
| `LooseEndsTests/TitleRuleTests.swift` | MODIFY | RED-Fälle und Gegenproben |
| `LooseEndsTests/Language/TestPack.swift` | MODIFY | neues Feld befüllen |
| `LooseEndsTests/Fixtures/rule-golden.json` | MODIFY | neu schreiben mit `LOOSEENDS_UPDATE_GOLDEN=1` |
| `docs/reference/neue-sprache.md` | MODIFY | Punkt „Tageszeiten“ für neue Sprachen |

Ein UI-Test für die Abnahme Stufe 2 kommt als Testcode dazu (zählt nicht ins LoC-Limit).

### Estimated Changes
- Files: 4 App-Dateien (Limit 4–5), dazu Tests und Doku
- LoC: App-Code ca. +70/-0 (Limit 250)

## Implementation Details

- **Wortliste:** `dayParts` je Sprache, kleingeschrieben und ohne Akzentfalten wie die anderen Felder des Packs. „morgen“ steht im deutschen Feld, gilt aber nur als Tageszeit, wenn unmittelbar davor ein Tag-Span steht (heute, Wochentag): „heute Morgen“, „Montag Morgen“. Am Satzanfang bleibt „Morgen“ das Datum (Parser, unverändert).
- **Streichung:** Für jeden Span aus `DueDateRule.match.spans` prüft `TitleRule` das Wort direkt davor und direkt dahinter. Ist es ein Tageszeitwort (ganzes Wort, nach `ExpressionText.words`), wird es in den Span aufgenommen. Steht vor dem Tageszeitwort das Lead-in „am“ bzw. „in the“, geht es mit. Danach läuft die vorhandene Lead-in- und Satzzeichen-Logik.
- **Grenzen:** Ohne angrenzendes Datum bleibt alles stehen („Am Abend Tabletten nehmen“). Zusammensetzungen sind andere Wörter und bleiben („Abendessen“, „Morgenrunde“, „Montagabend“, „Samstagmorgen“). Genitiv und Inhaltswort vor dem Tageszeitwort (`Parents' evening`) bleiben, weil das Wort nicht am Span hängt.
- **Felder:** Der Parser bleibt unverändert. Datum, Uhrzeit und alle anderen Felder bleiben, nur „tonight“ setzt das Datum heute. Keine Uhrzeit aus einer Tageszeit.
- **Golden-Fixture:** Der Diff darf genau sechs Zeilen im Feld `title` zeigen (de-heute-2, de-morgen-2, de-zeit-5, de-zeit-hinten-2, de-lang-1, en-long-1) und sonst nichts.

## Test Plan

### Automated Tests (TDD RED)
- [ ] Test 1: GIVEN „Pakete wegbringen heute Morgen“ WHEN `TitleRule.title` THEN „Pakete wegbringen“; Datum heute, keine Uhrzeit.
- [ ] Test 2: GIVEN „Heute Abend um 20 Uhr Oma anrufen“ WHEN Titel THEN „Oma anrufen“.
- [ ] Test 3: GIVEN „Müll rausstellen heute Abend“ WHEN Titel THEN „Müll rausstellen“.
- [ ] Test 4: GIVEN „Morgen früh um 7:30 den Hund zum Tierarzt“ WHEN Titel THEN „Den Hund zum Tierarzt“.
- [ ] Test 5: GIVEN „Morgen Mittag um 12 …“ WHEN Titel THEN „Mittag“ steht nicht mehr im Titel.
- [ ] Test 6: GIVEN „tomorrow morning hand in …“ WHEN Titel THEN „morning“ steht nicht mehr im Titel.
- [ ] Test 7: GIVEN „Montag Abend …“ und „am Montag am Abend …“ WHEN Titel THEN Abend und „am“ sind gestrichen.
- [ ] Test 8: GIVEN „Call mom tonight“ WHEN die Regel läuft THEN Datum heute, Titel „Call mom“.
- [ ] Test 9 (Gegenproben): GIVEN „Heute Abendessen kochen“ → „Abendessen kochen“; „Am Abend Tabletten nehmen“ unverändert; „Morgen Morgenrunde laufen“ → „Morgenrunde laufen“; „Parents' evening at primary school Friday at 7 pm“ behält „Parents' evening“.
- [ ] Test 10: GIVEN jeder Tageszeitfall ohne Zahl WHEN die Regel läuft THEN keine Uhrzeit gesetzt.
- [ ] Test 11: GIVEN `rule-golden.json` neu geschrieben WHEN Diff gegen den Stand vor dem Schnitt THEN genau die sechs genannten Zeilen im Feld `title`.
- [ ] Test 12: GIVEN `LanguagePackConformanceTests` WHEN Deutsch und Englisch geprüft THEN `dayParts` ist sauber (klein, ohne Dubletten, kein Wort aus anderen Feldern widersprüchlich).

### Abnahme Stufe 2 (Simulator)
UI-Test mit `./scripts/sim.sh test-proof`: eine Aufgabe „Pakete wegbringen heute Morgen“ erfassen und den Titel ansehen („Pakete wegbringen“). Belege werden geöffnet und beschrieben.

## Acceptance Criteria

- **AC-1:** „Pakete wegbringen heute Morgen“ ergibt den Titel „Pakete wegbringen“, Datum heute, keine Uhrzeit gesetzt.
- **AC-2:** „Heute Abend um 20 Uhr Oma anrufen“ ergibt „Oma anrufen“; „Müll rausstellen heute Abend“ ergibt „Müll rausstellen“; „Morgen früh um 7:30 den Hund zum Tierarzt“ ergibt „Den Hund zum Tierarzt“.
- **AC-3:** „Morgen Mittag um 12 …“, „tomorrow morning hand in …“ und „Montag Abend …“ verlieren das Tageszeitwort im Titel; „am Montag am Abend“ verliert auch das „am“ vor dem Tageszeitwort.
- **AC-4:** „Call mom tonight“ setzt das Datum auf heute und ergibt den Titel „Call mom“.
- **AC-5:** Gegenproben bleiben: „Heute Abendessen kochen“ → „Abendessen kochen“; „Am Abend Tabletten nehmen“ (kein Datum) unverändert; „Morgen Morgenrunde laufen“ → „Morgenrunde laufen“; „Parents' evening at primary school Friday at 7 pm“ behält „Parents' evening“; „Montagabend“ und „Samstagmorgen“ bleiben ganze Wörter.
- **AC-6:** In allen Tageszeitfällen ohne Zahl wird keine Uhrzeit gesetzt; der Parser (`DateExpressionParser`, `TimeExpressionParser`) ist unverändert.
- **AC-7:** `rule-golden.json` ändert sich nur in den sechs Zeilen de-heute-2, de-morgen-2, de-zeit-5, de-zeit-hinten-2, de-lang-1, en-long-1, nur im Feld `title`.
- **AC-8:** Alle Unit-Tests (`./scripts/sim.sh unit`) einschließlich `LanguagePackConformanceTests` und `RuleGoldenTests` sind grün; der UI-Test der Abnahme Stufe 2 ist grün.
- **AC-9:** Der App-Code-Umfang bleibt innerhalb von 4 Dateien und ±250 LoC; `docs/reference/neue-sprache.md` nennt Tageszeiten als Punkt für neue Sprachen.

## Definition of Done (kein AC)

- [x] **Stufe 3 Gerät:** Kein Pfad der Geräteliste berührt (weder `Shared/Persistence/`, `LooseEnds/Speech/`, `Shared/Intents/` noch `project.yml`, Entitlements oder Info.plist; `Shared/Language` und `Shared/Services` stehen nicht in der Tabelle). Die Abnahme endet nach Stufe 2.
- [x] **Zahl im Issue (2026-11-27: 15 von 41, vorher 14; Abweichung von der Erwartung 16 im Issue begründet):** Wenn `docs/reference/loose-ends-rawtexts.json` vorhanden ist (Hennings Export, nicht eingecheckt), läuft der lokale Auswertelauf nach dem Schnitt erneut; Ziel: mindestens 16 von 41 Titeln gleich seiner Korrektur (vorher 14). Die Zahl steht im Issue, ohne Sätze. Fehlt die Datei, steht das so im Issue; kein Zugriff auf seine Geräte ohne sein Wort.

## Changelog

- 2026-11-27: Initial spec created
