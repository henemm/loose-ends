---
entity_id: feat-759-schnitt-9-messung-je-sprache
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-759-schnitt-9-messung-je-sprache
---

# Spec: #759 Schnitt 9 — Messung je Sprache und die Schwelle für eine neue Sprache

Epic #750. Nach #752–#754. Modell: Sonnet oder Opus. Kein Produktcode.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750.

## Purpose

Der Datum-Titel-Bericht weist eine Regelspalte aus, nicht je Sprache. Für eine dritte Sprache braucht es die Marke,
ab der sie als ausgeliefert gilt, und den Beleg, dass Englisch sie heute erreicht.

Ohne Modell geht es nicht: nicht relevant; die Modellspalte bleibt, wie sie ist (Mac-Lauf #531, nicht Teil des Schnitts).

## Source

- `Measurement/date-title-corpus.json`: 319 Einträge, `lang` 244 de / 75 en; `Corpus.Entry.lang` (Corpus.swift Z. 55; Rückfall `"de"` Z. 163 für das dritte Format).
- `LooseEndsTests/DateTitleReportTests.swift`: schreibt `DATE-TITLE-REPORT BEGIN … END` (Z. 105); `DateParserCorpusTests` (139 Datumssätze, 180 Kontrollsätze, Z. 50–51 fest).
- `docs/reference/date-title-fidelity.md` Tabelle Z. 21–25 (Regel 99.3 % von 139, 0.0 % von 172).
- `Measurement/guardrail-corpus.json` (90/10), `latency-corpus.json` (5/1): unverändert.

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| Measurement/date-title-corpus.json | MODIFY | +25 englische Sätze (→ 100 en, 344 gesamt) |
| Measurement/MeasurementRun.swift oder DateTitleReportTests.swift | MODIFY | Regelspalte je `lang` |
| LooseEndsTests/DateParserCorpusTests.swift | MODIFY | Zählungen anpassen; je Sprache Datum ≥ 99 % exakt, 0 erfunden |
| LooseEndsTests/RuleGoldenTests.swift + Fixture | MODIFY | Fixture um die 25 neuen Zeilen erweitert (`LOOSEENDS_UPDATE_GOLDEN=1`, Diff zeigt nur neue IDs) |
| Measurement/Corpus.swift | MODIFY | Eintrag ohne `lang` im ersten Format → Fehler mit ID (heute stillschweigend) |
| docs/reference/date-title-fidelity.md | MODIFY | Tabelle je Sprache + Absatz „Schwelle“ |

LoC Swift ≈ +60 / −10 (Mess- und Testcode, kein Produktpfad).

## Implementation Details

- 25 neue englische Sätze nach den Mustern des deutschen Teils, mit Erwartungswert, keine Dopplung per
  `RawTextWords`-Wortmenge: Wochentag („by Thursday“), `next` + Wochentag, „end of the month“, „on May 4th“, „in 3 days“,
  „next week“, Uhrzeit („at 5pm“, „half past seven“), Dauer („takes an hour“), fünf Kontrollsätze ohne Datum
  („Call the plumber about the kitchen tap“), zwei Wiederholungen („every Monday“, Kontrolle). IDs fortlaufend.
- Bericht: je `lang` eine Zeile `Regel exakt | Regel erfunden | n`; Gesamtzeile bleibt.
- `DateParserCorpusTests`: Konstanten 139/180 auf die neuen Zahlen; zusätzlich je Sprache `#expect(exact.share >= 0.99)` und `invented.misses.isEmpty`.
- **Schwelle** (Text für `date-title-fidelity.md` und `neue-sprache.md` in #762): „Eine Sprache gilt als ausgeliefert,
  wenn ihre Regelspalte auf mindestens 50 Korpussätzen Datum ≥ 99 % exakt und 0 % erfunden erreicht und ihre
  Textform-Werte für Dringlichkeit und Etiketten nicht unter den englischen liegen (38/40, 37/40, `textform-rules.md`).
  Darunter bleibt das Pack im Code, aber nicht in `shipped`.“
- Erreicht Englisch die Schwelle nach dem Lauf nicht: die fehlenden Sätze mit ihrem Muster als neues Issue
  („Mehrsprachigkeit: englische Datumsregel, Muster X“), Spec-Changelog vermerkt es, **keine** Schwellenänderung.

## Test Plan

- [ ] `DateParserCorpusTests.dates`: GIVEN 344 Sätze THEN je Sprache ≥ 99 % exakt, 0 erfunden.
- [ ] `CorpusTests.entryWithoutLangFails`: GIVEN Eintrag ohne `lang` im Hauptformat THEN `Corpus.entries(from:)` wirft mit der ID.
- [ ] `RuleGoldenTests` grün nach Fixture-Erweiterung; Diff der Fixture enthält nur neue IDs (im PR gezeigt: `git diff -- LooseEndsTests/Fixtures | grep '^-' | grep -v '^---'` leer).

## Acceptance Criteria

- **AC-1:** `python3 -I -c "import json;d=json.load(open('Measurement/date-title-corpus.json'));..."` zählt ≥ 100 `en` (Befehl und Ausgabe im PR).
- **AC-2:** CI-Log `DATE-TITLE-REPORT` zeigt Zeilen `de` und `en` mit Regelwerten; `en` ≥ 99 % / 0 %.
- **AC-3:** Fixture-Diff nur Zusätze.

## Definition of Done

- [ ] AC-1 bis AC-3 belegt. PR `test: Datum-Titel-Messung je Sprache, englischer Korpus auf 100 (Refs #750, Closes #759)`; Merge; Board Done.
- [ ] „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-30: Spec erstellt.
