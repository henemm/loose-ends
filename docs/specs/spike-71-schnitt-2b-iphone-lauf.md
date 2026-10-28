---
entity_id: spike-71-schnitt-2b-iphone-lauf
type: feature
created: 2026-10-28
updated: 2026-10-28
status: draft
workflow: feat-71-guardrail-iphone-lauf
---

# Spec: Guardrail-Rate messen, Schnitt 2b-1 — Übersetzung Läufer-Ergebnis → Probe und Berichttest (#71)

## Approval

- [ ] Approved

## GitHub Issue

#71 (Spike, Epic #370, Annahme B3). Schnitt 2b-1 von 2b-1, 2b-2 (geteilt wegen der Limits 5 Dateien / ±250 LoC); das Issue bleibt bis zur Datenübernahme offen (`Refs #71`, nie `Closes #71` im Code-PR). Der Datenschritt nach dem Gerätelauf (2b-2) schließt es.

## Purpose

Annahme B3 (`docs/project/06-annahmen-und-experimente.md`): Mehr als 1 % Ablehnung auf Alltagstext ist das Abbruchkriterium. Die Mac-Spalte steht (2/387 = 0,52 %, obere Wilson-Grenze 1,86 %, PR #727), die obere Grenze liegt über 1 %, und das iPhone hat die neuere Modellgeneration. 2a (PR #734) hat den Läufer fähig gemacht, eine Ablehnung als Ergebnis zu zählen (`--count-failures`, Korpus aus `Documents/`). 2b-1 baut die Auswertung, die der Gerätelauf braucht, und belegt sie im Simulator, damit eine geholte iPhone-Datei beim ersten Anlauf auswertbar ist. Das Werkzeug zum Lauf (Skript, Korpusbau, Scheiben) folgt als 2b-2. Dieser Schnitt enthält:

- die Übersetzung Läufer-Ergebnis → `GuardrailProbe` (mit Vollständigkeitsprüfung, damit ein unvollständiger Lauf nie als Bericht durchgeht),
- einen Berichttest, der aus der geholten Ergebnisdatei Rohdaten (ohne Alltagswortlaut) und eine lokale Zusammenfassung schreibt.

Der Gerätelauf selbst ist **kein Teil der Tests und kein AC dieses PR**. Henning hat am 2026-10-28 wörtlich „jetzt ist ein Test möglich“ geschrieben; das gilt für genau einen Durchgang, der erst nach 2b-2 als eigener dokumentierter Schritt läuft (Abschnitt „Gerätelauf“). Bis dahin läuft nichts auf einem Gerät, auch nichts Lesendes.

**Ohne Modell geht es nicht, weil** die Frage lautet, ob das Modell ablehnt; Regeln lehnen nie ab, die Regel-Spalte ist 0 % per Konstruktion (Beleg: Schnitt 1, `docs/reference/modell-guardrails.md`, Abschnitt „Nulllinie“). Dieser Schnitt führt kein Modell ein, er misst das bestehende. Alternative zum Weg: B3 allein auf der Mac-Zahl entscheiden (siehe Alternativen).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Messcode der Labor-App, kein Produktpfad
- **Rationale:** Reine Auswertung, ein Hilfsskript und ein Handlauf-Befehl; kein Produktverhalten, kein Schema, keine Berechtigung. Gekippte ADR: keine.

## Source

- **File:** `Measurement/GuardrailReport.swift`
- **Identifier:** `GuardrailProbe.probes(from:corpus:runsPerEntry:)` (neu) mit Rückgabe `GuardrailProbe.Translation` (`probes`, `missing`, `unknown`)

Zusätzlich: Berichttest in `LooseEndsTests/GuardrailReportTests.swift`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| 2a (PR #734): `--count-failures`, `Corpus.url` mit `Documents/` | module | Läufer zählt Ablehnung als Ergebnis; Gerätekorpus liegt in `Documents/` und nie im Bündel |
| `GuardrailProbe`, `GuardrailReport` (Schnitt 1, PR #727) | module | Zählung, Wilson-Grenze, Treffer |
| `MeasurementResult`, `MeasurementRun`, `MeasurementErrorKind` | module | Quelle der Übersetzung (`entryID`, `runIndex`, `errorKind`, `conditions`) |
| `Corpus.entries(from:)` | module | liest die Gerätekorpusdatei (Liste von Einträgen, erkannt am Inhalt) |
| `RealModelGuardrailTests` (`Head`, `RawFile`, `summary`, `line`) | test | Schreibweise von Rohdaten und lokaler Zusammenfassung, wiederverwendet statt kopiert |
| `Measurement/guardrail-corpus.json` | data | 100 heikle Texte (`gr-001` …) |
| `docs/reference/focusblox-corpus.json` (gitignored, nur im Hauptordner) | data | 287 persönliche Sätze (`lang`, `rawText`); nie ins Repo, nie ins Bündel |
| Hennings Wort „jetzt ist ein Test möglich“ | Freigabe | Voraussetzung für den Gerätelauf, nicht für den Code |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/GuardrailReport.swift` | MODIFY | `GuardrailProbe.probes(from:corpus:runsPerEntry:)` und `Translation`; `GuardrailProbe.withoutEverydayWording(_:)` (aus `writeRaw` herausgezogen) |
| `LooseEndsTests/GuardrailReportTests.swift` | MODIFY | Tests der Übersetzung, Kette-Test ohne Gerät, gesperrter Berichttest |
| `LooseEndsTests/RealModelGuardrailTests.swift` | MODIFY | nur `summary`, `line` von `private` auf `internal`; `writeRaw` nutzt `withoutEverydayWording` |
| `docs/reference/modell-guardrails.md` | MODIFY (Datenschritt, 2b-2) | iPhone-Spalte; zählt nicht gegen die Code-Limits |
| `docs/artifacts/71-guardrails/iphone-rohdaten.json` | CREATE (Datenschritt, 2b-2) | Rohdaten ohne Alltagswortlaut; zählt nicht gegen die Code-Limits |

Nicht angefasst: `Shared/`, `FoundationModelsEnricher.swift`, `EnrichmentCoordinator.swift`, `project.yml`, `LooseEndsLab/` (2a ist fertig), `Measurement/MeasurementRun.swift`, `Measurement/Corpus.swift`.

### Estimated Changes

- Files: 3 Code/Test-Dateien (Daten/Doku des Datenschritts gehören zu 2b-2)
- LoC: ca. +165/−5 (GuardrailReport +40, GuardrailReportTests +115, RealModelGuardrailTests ±8) — innerhalb der Limits; das Werkzeug (ca. +175 in `sim.sh`, `guardrail_corpus.py`, `test_guardrail_corpus.py`) ist Schnitt 2b-2.

## Implementation Details

### 1. Übersetzung Ergebnis → Probe (`GuardrailReport.swift`)

`GuardrailProbe.probes(from run: MeasurementRun, corpus: [Corpus.Entry], runsPerEntry: Int) -> Translation`. Rein, ohne Datei und Modell.

- Je Eintrag × Durchlauf `0..<runsPerEntry` höchstens eine Probe. Mehrfachergebnisse desselben Eintrags und Durchlaufs: das **letzte** in der Reihenfolge der Datei zählt (die Datei ist chronologisch; ein später wiederholter Aufruf nach `rateLimited` ersetzt den früheren).
- `menge` = `alltag`, wenn die Id mit `alltag-` beginnt, sonst `heikel`. `sprache` = `lang`, `gruppe` = `form`, `text` = Satz, `durchlauf` = `runIndex + 1`.
- `fehlerart` = `errorKind`; `nil` bei Erfolg; hat ein Ergebnis `error` aber keinen `errorKind` (Dateien vor #83), dann `MeasurementErrorKind.other`.
- Fehlt für Eintrag × Durchlauf jedes Ergebnis: **keine Probe**, aber `missing` zählt ihn (Anzahl fehlender Aufrufe, Soll = Einträge × `runsPerEntry`). Ein Ergebnis mit `entryID` außerhalb des Korpus oder `runIndex ≥ runsPerEntry` erzeugt keine Probe und steht in `unknown` (Zahl), damit nichts stillschweigend verschwindet.
- `rateLimited`, `timeout`, `assetsUnavailable` u. a. werden **nicht** zur Ablehnung: Sie bleiben Proben mit ihrer Fehlerart, die `GuardrailProbe.isExcluded` schon aus dem Nenner nimmt (Schnitt 1).
- `GuardrailProbe.withoutEverydayWording(_ probes:)` setzt `text = nil` für jede Probe mit `menge != "heikel"`. Das ist heute der Block in `writeRaw`; er wandert dorthin, damit Mac- und iPhone-Weg dieselbe Funktion nutzen und ein Test sie ohne Datei belegen kann.

### 2. Berichttest (`GuardrailReportTests.swift`)

Eine eigene Suite, nur aktiv, wenn `LOOSEENDS_GUARDRAIL_IPHONE_RESULT` (geholte Ergebnisdatei) und `LOOSEENDS_GUARDRAIL_CORPUS` (Gerätekorpusdatei) gesetzt sind und die Dateien existieren; sonst übersprungen (Memory: Messberichte zerstören sich im Simulator). Ablauf: beide Dateien lesen, übersetzen, `#expect(missing == 0)` und `#expect(unknown == 0)`, dann

- `LOOSEENDS_GUARDRAIL_OUT`: `RawFile` mit `Head(geraet: Conditions.device des ersten Ergebnisses, system: dessen systemVersion, datum: Datum des letzten Ergebnisses, nurHeikel: false, durchlaeufe: 2)`; Proben durch `withoutEverydayWording`. Der Kopf nimmt Gerät und System aus der **Ergebnisdatei**, nie vom Simulator, der den Test ausführt.
- `LOOSEENDS_GUARDRAIL_LOCAL`: `RealModelGuardrailTests.summary(head:report:)` mit Wortlaut der Treffer, Ziel außerhalb des Repos.
- Ohne die Ausgabe-Variablen wird nichts geschrieben (wie am Mac).

`summary` und `line` werden `internal static` und aufgerufen, nicht kopiert.

## Gerätelauf (nur auf Hennings Wort, nach 2b-2)

Nicht Teil der Tests, nicht Teil dieses PR; hier nur zur Einordnung. Entwurf von Korpusbau, Befehl und Scheiben: `docs/context/feat-71-guardrail-iphone-lauf.md`, Abschnitt „Vorlage für Schnitt 2b-2“. Reihenfolge, damit Henning nicht wartet („Bereit, bevor ich Henning rufe“):

1. 2b-1 und 2b-2 gemergt, Simulator-Durchlauf belegt, Trockenlauf `lab-guardrail --dry-run` ohne Fehler.
2. Mit der Nachricht, die Henning ruft, läuft der Befehl schon: Labor-App gebaut, Korpus gebaut, Meldung mit Zahl und Dauer ausgegeben. Seine einzige Aufgabe: iPhone entsperrt lassen.
3. Der Befehl läuft in Scheiben bis 774 gemessene Aufrufe, holt die Datei, schreibt Rohdaten und lokale Zusammenfassung.
4. Datenschritt (eigener Commit, Doku/Daten): iPhone-Spalte in `docs/reference/modell-guardrails.md`, `iphone-rohdaten.json`, Ticket #71 kommentieren und schließen, B3 in `06-annahmen-und-experimente.md` mit der Zahl entscheiden. Überschreitung der 1-%-Schwelle: Folgeticket „Modell hat abgelehnt“ als sichtbarer Zustand (Alternativen im Ticket).

Die Erlaubnis gilt für diesen einen Durchgang, nicht darüber hinaus. Scheiben innerhalb dieses Durchgangs gehören dazu; ein späterer zweiter Durchgang braucht ein neues Wort.

## Acceptance Criteria

- **AC-1:** `GuardrailProbe.probes(from:corpus:runsPerEntry:)` übersetzt je Eintrag × Durchlauf ein Ergebnis in eine Probe: `menge` `alltag` bei Id-Präfix `alltag-`, sonst `heikel`; `sprache` = `lang`; `gruppe` = `form`; `text` = Satz; `durchlauf` = `runIndex + 1`; `fehlerart` `nil` bei Erfolg, `guardrail` und `refusal` aus `errorKind` übernommen.
- **AC-2:** `rateLimited`, `timeout`, `assetsUnavailable` und `contextWindow` bleiben Proben mit ihrer Fehlerart und gelten über `isExcluded` nicht als Ablehnung (`isRefused == false`); ein Fehler ohne `errorKind` wird zu `andere`.
- **AC-3:** Fehlt für Eintrag × Durchlauf ein Ergebnis, entsteht keine Probe und `Translation.missing` zählt ihn (Soll = Einträge × `runsPerEntry` minus vorhandene). Ein Ergebnis zu unbekannter `entryID` oder mit `runIndex ≥ runsPerEntry` steht in `Translation.unknown`. Bei mehreren Ergebnissen desselben Eintrags und Durchlaufs zählt das letzte.
- **AC-4:** `GuardrailProbe.withoutEverydayWording(_:)` setzt `text = nil` für jede Probe mit `menge != "heikel"` und lässt die heiklen Proben unverändert; `RealModelGuardrailTests.writeRaw` benutzt sie, ohne Verhaltensänderung für die Mac-Rohdaten.
- **AC-5:** Kette ohne Gerät: Ein Test baut aus einem Korpus (100 heikle, 287 Alltag mit erfundenen Sätzen und einem Erkennungswort) und gestellten Ergebnissen (774 Aufrufe, eine Ablehnung in der Alltagsmenge) die Proben, den `RawFile`-JSON-Text und die lokale Zusammenfassung: Der Rohtext enthält weder ein Alltagswort noch das Erkennungswort, aber `alltag-<Index>` des Treffers; die Zusammenfassung enthält den Wortlaut des Treffers; `missing == 0`; Zahlen stimmen (1/387 Texte, 0 ausgenommen).
- **AC-6:** Der Berichttest läuft nur, wenn `LOOSEENDS_GUARDRAIL_IPHONE_RESULT` und `LOOSEENDS_GUARDRAIL_CORPUS` auf vorhandene Dateien zeigen, sonst wird er übersprungen; mit ihnen schlägt er fehl, wenn `missing > 0` oder `unknown > 0`; er schreibt die Rohdaten nur nach `LOOSEENDS_GUARDRAIL_OUT` und die lokale Zusammenfassung nur nach `LOOSEENDS_GUARDRAIL_LOCAL`, ohne die Variablen nichts. Gerät und System im Kopf stammen aus `Conditions` der Ergebnisdatei.
- **AC-7:** `summary` und `line` existieren genau einmal im Quelltext (in `RealModelGuardrailTests`, `internal`); `GuardrailReportTests` ruft sie auf (Prüfung: `grep -c "func summary"` über `LooseEndsTests/` ergibt 1).
- **AC-8:** Der Code-PR enthält genau die drei Dateien der Scope-Tabelle (Dateiliste des PR) und läuft auf keinem Gerät: kein `devicectl`, kein `lab-guardrail`.

## Test Plan

### Automated Tests (TDD RED)

Alle Swift-Tests laufen nur im Simulator (`./scripts/sim.sh sim-unit GuardrailReportTests`), nie auf dem Mac-Host, nie auf einem Gerät. Funktionsnamen entstehen in TDD RED; vor der Implementierung kompilieren sie nicht.

- Test: GIVEN ein Ergebnis ohne Fehler, eines mit `guardrail`, eines mit `refusal` WHEN übersetzt THEN `fehlerart` ist `nil`, `guardrail`, `refusal`; `isRefused` entsprechend (AC-1)
- Test: GIVEN Einträge `gr-001` (de, Form `kuendigung`) und `alltag-3` (en) WHEN übersetzt THEN `menge` `heikel` und `alltag`, `sprache`, `gruppe`, `text` stimmen, `durchlauf` = `runIndex + 1` (AC-1)
- Test: GIVEN Ergebnisse mit `rateLimited`, `timeout`, `assetsUnavailable`, `contextWindow` und ein Fehler ohne `errorKind` WHEN übersetzt THEN alle sind ausgenommen und keine Ablehnung, der Fehler ohne Typ heißt `andere` (AC-2)
- Test: GIVEN zwei Einträge à zwei Durchläufe, ein Ergebnis fehlt, ein weiteres gehört zu unbekannter Id, ein drittes hat `runIndex` 2 WHEN übersetzt THEN `missing == 1`, `unknown == 2`, keine Probe für den fehlenden Aufruf (AC-3)
- Test: GIVEN zwei Ergebnisse desselben Eintrags und Durchlaufs, zuerst `rateLimited`, dann Erfolg WHEN übersetzt THEN eine Probe, `fehlerart == nil` (AC-3)
- Test: GIVEN Proben der Mengen `heikel` und `alltag` WHEN `withoutEverydayWording` THEN Alltag ohne Text, heikel mit Text (AC-4)
- Test: GIVEN die gestellte Kette (100 + 287, 774 Ergebnisse, ein Treffer in `alltag`) WHEN übersetzt, als `RawFile` kodiert und zusammengefasst THEN Rohtext ohne Alltagswort, mit `alltag-<Index>`; Zusammenfassung mit Wortlaut; `missing == 0` (AC-5)
- Test: GIVEN die beiden Variablen nicht gesetzt WHEN der Berichttest läuft THEN er wird übersprungen, nicht rot, nicht grün mit Nullen (AC-6)
- Test: GIVEN Quelltext von `LooseEndsTests/` WHEN `func summary` gezählt THEN genau eine Stelle (AC-7, per `grep` im Prüfdialog)

### Simulator-Durchlauf (Pflicht vor der Übergabe)

Die Kette wird im Simulator durchgespielt, nicht nur Teile einzeln: Eine Wegwerf-Korpusdatei (100 heikle Texte aus `Measurement/guardrail-corpus.json`, 287 erfundene Alltagssätze `alltag-<Index>` mit einem Erkennungswort) und eine Wegwerf-Ergebnisdatei (774 Ergebnisse, eine Ablehnung in der Alltagsmenge) entstehen außerhalb des Repos; der Berichttest läuft damit im Simulator mit allen drei Ausgabe-Variablen; geprüft wird per `grep`, dass die Rohdaten kein Alltagswort und nicht das Erkennungswort enthalten und die lokale Zusammenfassung den Treffer mit Wortlaut. Das beweist, dass die Kette schließt (Memory: Testaufbau, der sich den Ausgangszustand selbst herstellt, prüft den halben Weg). Gerät: nichts.

## Alternativen

- **A. Auf der Mac-Zahl entscheiden:** verworfen. Obere Grenze 1,86 % liegt über der Schwelle 1 %, das iPhone hat die neuere Modellgeneration. Gekippt würde die Annahme, dass Mac und iPhone getrennt zählen.
- **B. Nur die 100 heiklen Texte aufs iPhone:** Notlösung, falls die persönlichen Sätze nicht aufs Gerät sollen; ein Treffer wäre schon 1 %, die Schwelle trüge nicht.
- **C. Auswertung als Skript statt als Test:** Python könnte Proben direkt aus der Ergebnisdatei bauen. Verworfen: Zählung, Wilson-Grenze und Zusammenfassung existieren in Swift, ein zweiter Zähler könnte abweichen (Memory: eine Quelle).
- **D. Alltagsmenge im Bündel der Labor-App:** verworfen, persönliche Sätze nie im Bündel; `Documents/` verschwindet mit der Deinstallation der Labor-App.
- Gekippte ADR: keine.

## Offene Punkte (für 2b-2, hier nicht zu entscheiden)

1. Zahl und Länge der Scheiben (Vorschlag 20 Minuten, höchstens 6), Umgang mit ausgenommenen Proben am Ende, Verbleib der lokalen Zusammenfassung, Exit-Verhalten der Labor-App beim Dreifehler-Stopp: siehe `docs/context/feat-71-guardrail-iphone-lauf.md`.

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt, jedes durch Test, `grep` oder Dateiliste belegt
- [ ] `GuardrailReportTests` und `RealModelGuardrailTests` kompilieren und sind im Simulator grün; `./scripts/sim.sh build` baut
- [ ] Simulator-Durchlauf der Kette belegt (Rohdaten ohne Alltagswortlaut, lokale Zusammenfassung mit Treffer)
- [ ] Nichts auf einem Gerät gelaufen; PR mit `Refs #71`
- [ ] Gerätelauf, Datenschritt und B3-Entscheidung gehören zu 2b-2

## Changelog

- 2026-10-28: Initial (Schnitt 2b), am selben Tag geteilt in 2b-1 (diese Spec) und 2b-2
