# Adversary-Dialog — feat-92-date-parser (#92, Schnitt 1: Regelparser messen)

Datum: 2026-09-20 · Spec: `docs/specs/measurement/feat-92-date-parser.md` · Prüfer: implementation-validator (liest nur Spec, Tests und Test-Outputs, nicht den Parser-Code) · Rollen: Orchestrator relayiert zwischen Prüfer und Developer Agent.

## Checkliste (aus der Spec geparst, 7 Punkte — Stand nach Runde 2)

- [x] AC-1 Datum ≥ 95 % exakt auf 139 Datumssätzen, Referenztag Do 12.3.2026, je Ausdrucksart aufgeschlüsselt — bewiesen: 138/139 (99,3 %), Prüfer-Lauf grün
- [x] AC-2 0 % erfunden auf 178 Sätzen ohne Datumserwartung (170 Kontrolle + 8 `repeat`) — bewiesen nach Fix F001: 178/178 geprüft, 0 erfunden
- [x] AC-3 Uhrzeit ≥ 95 % auf allen 24 Uhrzeit-Sätzen inkl. 3 `repeat` — bewiesen: 24/24 (100 %)
- [x] AC-4 Je Ausdrucksart ein Unit-Test DE + EN (wo im Korpus) + Falle — bewiesen: 14 + 7 Tests gelesen und ausgeführt
- [x] AC-5 Bericht: dritte Spalte „Regelparser", Aufschlüsselung, Block „Regelparser danebenging" — bewiesen im generierten Bericht
- [x] AC-6 `DateParserCorpusTests` ungated, wertet AC-1/2/3 als `#expect`, läuft in CI — bewiesen nach Fix F002 mit exakten Zählungen 139/178
- [x] AC-7 Bestehende Suiten grün, kein Produktpfad berührt — bewiesen: 119/119 grün, nur `Measurement/`, `LooseEndsTests/`, `docs/` geändert

### Runde 1 — Beweisangebot und Prüfung

Beweisangebot des Developer Agent: voller Lauf `./scripts/sim.sh unit` grün (`test-green-output.txt`), Datum 138/139 (99,3 %), erfunden 0/170 (+8 `repeat` ohne Datum), Uhrzeit 24/24, Bericht `docs/reference/date-title-fidelity.md` mit Spalte „Regelparser" und Block „Regelparser danebenging (1)".

| AC | Prüfung durch den Prüfer | Ergebnis |
|---|---|---|
| AC-1 | `DateParserCorpusTests.dates()` selbst ausgeführt (grün); 139 Einträge mit `date` per Skript gegen `date-title-corpus.json` verifiziert; 9 Zeilen je Ausdrucksart im Bericht | Akzeptiert (Vorbehalt F002) |
| AC-2 | Schleife in `dates()` lief mit `where entry.countsForDateMeasurement` (= `repeatRule == nil`): die 8 `repeat`-Sätze fielen vollständig aus der Zählung, `invented.total` = 170 statt 178 | **NICHT akzeptiert → F001** |
| AC-3 | `times()` filtert nur `entry.time != nil`, 24 Sätze per Skript verifiziert, Test grün, 100 % | Akzeptiert |
| AC-4 | Beide Testdateien gelesen und ausgeführt; 9 Ausdrucksarten DE, EN wo im Korpus (`weekdayNextWeek` hat nur DE-Einträge); Fallen `numberTraps`, `repeatTraps`, Uhrzeit-Fallen | Akzeptiert |
| AC-5 | Diff von `DateTitleReportTests.swift` und Bericht: dritte Spalte, Aufschlüsselung, Block „Regelparser danebenging (1)" | Akzeptiert |
| AC-6 | Kein `.enabled(if:)` an `DateParserCorpusTests`, läuft ohne Messlauf; aber AC-2 nur über 170 Sätze | Teilweise → F001 |
| AC-7 | `git status`/`git diff --stat`: nur `Measurement/`, `LooseEndsTests/`, `docs/`; alle Suiten im Artefakt grün | Akzeptiert |

Vorläufiges Verdict Runde 1: BROKEN (F001 HIGH, F002 MEDIUM).

Nachfragen an den Developer Agent: (1) F001 bewusst oder Versehen, Fix mit `entry.date == nil` für die invented-Zählung; (2) exakte Zählungen 139/178 statt `>= 130`/`>= 160`; (3) Beweis, dass die 8 `repeat`-Sätze real durch `parser.date(in:reference:)` laufen und kein Datum liefern; (4) ändern sich die Berichtszahlen?

## Fix-Loop 1 — Antwort des Developer Agent

Nur `LooseEndsTests/DateParserCorpusTests.swift` geändert: Schleife ohne Gate über `Corpus.load()`, Verzweigung über `entry.date != nil`; `#expect(exact.total == 139)`, `#expect(invented.total == 178)`. Lauf `./scripts/sim.sh unit DateParserCorpusTests`: 3/3 grün, Exit 0 (`test-green-corpus-fix.txt`).

Die 8 `repeat`-Sätze real durch den Parser (Referenztag 12.3.2026), alle ohne Datum: „Jeden Montag den Müll rausstellen", „Jeden Tag um 7 Uhr die Tabletten nehmen" (Uhrzeit 07:00), „Jeden ersten Montag im Monat den Rauchmelder prüfen", „Jedes Jahr im April die Reifen wechseln", „Werktags um 6:30 den Wecker für die Schule stellen" (06:30), „Every Monday water the plants", „Every day at 8pm take the medication" (20:00), „Every month check the smoke detector".

Bericht unverändert (99,3 % / 0,0 % von 170 / 100 % von 24). `scoreRuleParser` behält das Gate bewusst: der in RED vorgegebene Test „Wiederholungen nur bei der Uhrzeit" verlangt `ruleParserInvented.total == 1` für den Drei-Satz-Korpus, und die Spalten Modell/NSDataDetector zählen ebenfalls über 170, sodass die Zeile „Erfundene Daten" spaltenweise vergleichbar bleibt. Die 178 verlangt die Spec in AC-2/AC-6 (Abnahmetest), nicht in AC-5 (Bericht).

### Runde 2 — Verifikation durch den Prüfer

- F001: Diff selbst geprüft, Suite selbst ausgeführt (3/3 grün, Exit 0). Alle 178 Kontrollsätze laufen real durch `parser.date(in:reference:)`, `invented.misses.isEmpty` grün. **Behoben.**
- F002: `== 139` / `== 178` im Diff bestätigt, Test grün mit scharfen Werten. **Behoben.**
- Punkt 4 (Bericht behält Gate): Begründung geprüft und akzeptiert; AC-5 nennt keine 178er-Zahl, Spaltenvergleichbarkeit ist ein sachlicher Grund. Restpunkt als F003 (LOW) dokumentiert.
- Regressionscheck: voller Lauf `./scripts/sim.sh unit` selbst durchgeführt, aus `xcodebuild.log`: „Test run with 119 tests in 32 suites passed", 0 × ✘. Kein Produktpfad geändert.

## Finale Findings

```json
[
  {"id": "F001", "severity": "HIGH", "category": "spec_violation", "status": "RESOLVED",
   "description": "DateParserCorpusTests.dates() filterte 8 repeat-Sätze aus der invented-Zählung (170 statt 178).",
   "evidence": "LooseEndsTests/DateParserCorpusTests.swift:31 iteriert jetzt ungefiltert; eigener Lauf 3/3 grün.",
   "remediation": "Behoben."},
  {"id": "F002", "severity": "MEDIUM", "category": "spec_violation", "status": "RESOLVED",
   "description": "Sanity-Schwellen >= 130 / >= 160 statt exakter Korpuszahlen 139 / 178.",
   "evidence": "LooseEndsTests/DateParserCorpusTests.swift:41-42 jetzt == 139 / == 178, Test grün.",
   "remediation": "Behoben."},
  {"id": "F003", "severity": "LOW", "category": "edge_case",
   "description": "scoreRuleParser im Bericht zählt die Regelparser-Spalte auf 170 statt 178 Kontrollsätzen; eine Regression bei Wiederholungen wäre im Bericht nicht sichtbar, wird aber vom CI-Test (AC-6) gefangen.",
   "evidence": "LooseEndsTests/DateTitleReportTests.swift, scoreRuleParser; Spec AC-5 nennt keine 178.",
   "remediation": "Kein Handlungsbedarf für diesen Schnitt; optional eigene Berichtszeile für die 8 Wiederholungen."}
]
```

## Verdict
**VERIFIED**

Begründung des Prüfers im Wortlaut:

```
VERDICT: VERIFIED
Tests: 119 passed, 0 failed (voller Lauf, vom Prüfer eigenständig ausgeführt)
Edge cases: F001/F002 in Runde 2 verifiziert behoben; F003 (LOW) dokumentiert, nicht blockierend
Regressionen: keine — Shared/ und LooseEnds/ unberührt, alle bisherigen Suiten grün
Checklist:
  AC-1 CONFIRMED — 139 Datumssätze, 99,3 % exakt, Aufschlüsselung im Bericht
  AC-2 CONFIRMED — 178/178 geprüft, 0 erfunden, real durch den Parser gelaufen
  AC-3 CONFIRMED — 24/24 Uhrzeit-Sätze, 100 %
  AC-4 CONFIRMED — 9 Ausdrucksarten DE/EN (wo im Korpus) + Fallen
  AC-5 CONFIRMED — dritte Spalte, Aufschlüsselung, Misses-Block
  AC-6 CONFIRMED — ungated, 139/178/24 in einem #expect-Test, läuft in CI
  AC-7 CONFIRMED — 119/119 grün, kein Produktpfad berührt
```

Test-Outputs: `docs/artifacts/feat-92-date-parser/test-green-output.txt` (voller Lauf vor dem Fix), `docs/artifacts/feat-92-date-parser/test-green-corpus-fix.txt` (Abnahmetest nach dem Fix), Prüfer-Läufe im Scratchpad der Sitzung.
