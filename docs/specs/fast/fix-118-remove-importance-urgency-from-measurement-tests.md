# Mini-Spec: FocusBloxCalibrationTests/SelfConsistencyReportTests fuer importance/urgency anpassen (#118)

## Was ändert sich
- `LooseEndsTests/FocusBloxCalibrationTests.swift`: importance/urgency-Auswertung entfernen
  (Sammlung, Tabellenausgabe, das harte `#expect(!importanceOutcomes.isEmpty, ...)`). Bericht und
  Test decken nur noch duration/energy ab.
- `LooseEndsTests/SelfConsistencyReportTests.swift`: die beiden Tabellen-Zeilen für "importance" und
  "urgency" aus `sections` entfernen. Bericht deckt nur noch duration/energy/contexts ab.
- `Measurement/SelfConsistency.swift`: Kommentar `// MARK: - Single-value fields (importance,
  urgency, duration, energy)` auf `(duration, energy)` verkürzen — der Code selbst ist feldneutral
  und bleibt unverändert.

## Acceptance Criteria
- **AC-1:** `LooseEndsTests/FocusBloxCalibrationTests.swift` wertet importance/urgency nicht mehr aus (keine Sammlung, keine Tabellenausgabe, kein hartes `#expect(!importanceOutcomes.isEmpty, ...)`); Bericht und Test decken nur noch duration/energy ab.
- **AC-2:** `LooseEndsTests/SelfConsistencyReportTests.swift` enthält in `sections` keine Tabellen-Zeilen mehr für "importance" und "urgency"; Bericht deckt nur noch duration/energy/contexts ab.
- **AC-3:** `Measurement/SelfConsistency.swift` — der Kommentar `// MARK: - Single-value fields (importance, urgency, duration, energy)` ist auf `(duration, energy)` verkürzt; der Code selbst bleibt unverändert.

## Was sich nicht ändern darf
- `Measurement/MeasurementRun.swift` und `Measurement/Corpus.swift` bleiben unverändert (Rohdaten-
  Speicher, analog zu `dueDate` nach #95 — die Felder existieren dort weiter, nur die Auswertung in
  den beiden Report-Tests entfällt).
- Kein Eingriff in Produktcode (`Shared/Enrichment/*`) — das war #117.
- Die Test-Suiten bleiben weiterhin auf lokale, gitignorete Corpus-Dateien gegated und laufen nie in CI.

## Manuelle Test-Schritte
Entfällt — beide Suiten sind auf lokale, personenbezogene Corpus-Dateien gegated und laufen nie in
CI. Verifikation erfolgt durch Kompilierbarkeit (`./scripts/sim.sh unit`, Suiten werden übersprungen)
und Code-Review der verbleibenden Feld-Referenzen.

## Inline-Test (wird während Implementierung geschrieben)
- [ ] Nach der Änderung: `grep -n "importance\|urgency" LooseEndsTests/FocusBloxCalibrationTests.swift LooseEndsTests/SelfConsistencyReportTests.swift` liefert keine Treffer mehr.
- [ ] `./scripts/sim.sh unit` compiliert und läuft grün durch (beide Suiten übersprungen, da Corpus-Dateien lokal fehlen).
