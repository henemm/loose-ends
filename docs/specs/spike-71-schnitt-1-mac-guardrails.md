---
entity_id: spike-71-schnitt-1-mac-guardrails
type: feature
created: 2026-10-27
updated: 2026-10-27
status: draft
workflow: spike-71-guardrail-rate
---

# Spec: Guardrail-Rate messen, Schnitt 1 — Mac (#71)

## Approval

- [ ] Approved

## GitHub Issue

#71 (Spike, Epic #370, Annahme B3). Schnitt 1 von 2; das Issue bleibt offen (`Refs #71`, nie `Closes #71`).

## Purpose

Annahme B3 (`docs/project/06-annahmen-und-experimente.md`): Lassen die Guardrails des On-Device-Modells Alltagstext durch? Abbruchkriterium: über 1 %
Verweigerung auf Alltagstext. Dieser Schnitt misst die Verweigerungsrate auf dem **Mac** mit dem echten Modell und schreibt den Bericht (Mac-Spalte).
Die iPhone-Messung ist **Schnitt 2** (nur nach Hennings wörtlichem „jetzt ist ein Test möglich“, gebündelt mit #88 Teil 2).

Messkorpus: die 100 heiklen Alltagstexte aus `Measurement/guardrail-corpus.json` (10 Themengruppen à 10, 90 DE, 10 EN; Feld `form` = Themengruppe) plus die
287 echten Sätze des FocusBlox-Korpus (Feld `rawText`, die gesprochene Produkteingabe, nicht der Titel). Der FocusBlox-Korpus ist gitignored und liegt nur im
Hauptordner; er wird per `LOOSEENDS_FOCUSBLOX_CORPUS` (Pfad) geladen und nie eingecheckt. Ohne die Variable läuft nur die 100er-Menge, und der Bericht sagt das.

Recherche (Stand 2026-10-27, Quellen im Bericht): Forum 793876, 787736, 835777; WWDC26 Sitzung 241 und 339. Befund: Fehlalarme sind **nicht deterministisch**
(dieselbe Anfrage geht mal, mal nicht), deshalb **zwei Durchläufe je Text**. `.permissiveContentTransformations` greift laut Forum 835777 nicht bei `Generable`;
`FoundationModelsEnricher` nutzt `respond(generating:)`, der Schalter ist also kein Ausweg. `refusal` kann auch ohne Guardrail-Verstoß kommen und wird getrennt gezählt.
`rateLimited` kann Last oder Gerätezustand meinen und gehört nicht in die Verweigerungsrate.

**Ohne Modell geht es nicht, weil** die Titelverfeinerung Sprachverstehen braucht (Beleg: #202, `TitleRule` setzt den Titel beim Erfassen nur aus dem bereinigten
Rohtext; die Verfeinerung ist das, was bleibt). Dieses Ticket führt kein Modell ein, es vermisst den bestehenden Aufruf. **Nulllinie:** Die Regel-Spalte ist
0 % Verweigerung per Konstruktion (Regeln verweigern nie: `DueDateRule` 99,3 % in #92/#95, `ContextWordRule`, `TitleRule`). Der Bericht führt sie so. Im Produkt kostet eine
Verweigerung nur die Modellverfeinerung (Titel, Dauer, Wichtigkeit/Dringlichkeit): `ModelFailure.isPermanent` (#535) lässt die Regelwerte stehen. Das senkt das Gewicht
der Schwelle, nicht den Wert der Messung (Tor für externe Tester, Epic #370).

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Messung und Bericht, kein Produktpfad. Der Bericht entscheidet B3 nicht endgültig; das geschieht erst mit der iPhone-Spalte (Schnitt 2).
ADR-4 (Anreicherung läuft einmal) bleibt unberührt.

## Source

**File:** `Measurement/GuardrailReport.swift` (Hauptdatei; übrige Dateien in der Tabelle)
**Identifier:** `GuardrailReport`, `RealModelGuardrailTests`, `cmd_real_model_guardrail`

| Datei | Änderung |
|---|---|
| `Measurement/GuardrailReport.swift` | NEU: reine Auswertung (Raten je Fehlerart, Menge, Sprache, Themengruppe; Treffer immer/manchmal; Wilson-Grenze; Schwelle) |
| `LooseEndsTests/GuardrailReportTests.swift` | NEU: Unit-Tests mit gestellten Ergebnissen (Simulator) |
| `LooseEndsTests/RealModelGuardrailTests.swift` | NEU: Mac-Lauf mit echtem Modell, Rohdaten als JSON |
| `LooseEndsTests/RealModelGateTests.swift` | MODIFY: Quelltext-Gate auch für die neue Suite |
| `scripts/sim.sh` | MODIFY: `real-model-guardrail` nach Muster `real-model-latency` |
| `docs/reference/modell-guardrails.md` | NEU: Bericht (Mac-Spalte); Rohdaten unter `docs/artifacts/71-guardrails/` (Beleg, kein Code) |

Nicht in diesem Schnitt: `Measurement/Corpus.swift` und `LooseEndsLab/MeasurementRunner.swift` bleiben unverändert (Schnitt 2), ebenso `Measurement/MeasurementRun.swift`
(`MeasurementErrorKind.classify` wird nur aufgerufen). Kein Python-Skript: die Auswertung ist Swift (`GuardrailReport`), der Bericht entsteht aus ihrer Ausgabe.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `MeasurementErrorKind.classify` (`guardrail`, `refusal`, `rateLimited`, `timeout`, `andere` …) | wiederverwendet, unverändert |
| `RealModel` (Gates) in `RealModelTests.swift`, Muster `RealModelLatencyTests.swift` | wiederverwendet, unverändert |
| `Measurement/guardrail-corpus.json`, `GuardrailCorpusTests` | wiederverwendet, unverändert |
| `FoundationModelsEnricher` | gemessen, unberührt |
| `scripts/sim.sh` Testsperre (`acquire_testlock`) | wiederverwendet |
| #276 (Korpus), #535, #536, #68 | gemergt |
| Schnitt 2 (iPhone, `--count-failures` im Läufer, #88 Teil 2) | folgt, Stufe 3 |

## Acceptance Criteria

- **AC-1:** `Measurement/GuardrailReport.swift` wertet eine Liste von Proben `{id, menge ("heikel"|"alltag"), sprache, gruppe, durchlauf, fehlerart?}` rein (ohne Modell, ohne
  Dateizugriff) aus. Die Verweigerungsrate zählt **nur** `guardrail` und `refusal`, je Art getrennt ausgewiesen (und als Summe). `rateLimited`, `timeout`,
  `contextWindow` und übrige Arten zählen **nicht** in die Verweigerungsrate und werden separat je Art gezählt; sie stehen nicht im Nenner der Rate (Nenner = Proben ohne
  diese Fehlerarten) und der Bericht nennt ihre Zahl.
- **AC-2:** Die Auswertung weist Raten je Menge (heikel, Alltag) einzeln, je Sprache, je Themengruppe und über alle Texte gemeinsam aus. Ein Text ist ein **Treffer „immer“**,
  wenn er in allen seinen Durchläufen verweigert wurde, **„manchmal“**, wenn nur in einem Teil; jeder Treffer wird mit Wortlaut, Menge, Gruppe, Sprache und
  der Fehlerart je Durchlauf aufgelistet.
- **AC-3:** Je Rate gibt es die obere 95-%-Grenze nach Wilson; bei 0 Treffern zusätzlich den Hinweis der Dreierregel (3/n). Die **Schwelle 1 %** wird am Gesamtwert über
  **alle Texte gemeinsam** (heikel + FocusBlox = „Alltagstext“, Entscheidung dieser Spec) geprüft: „unter“, wenn die Rate ≤ 1 % ist; der Bericht nennt zusätzlich, ob die obere Grenze
  über 1 % liegt (dann nur „nicht widerlegt“). Beide Mengen stehen einzeln daneben, tragen die Schwelle aber nicht allein. Gezählt wird je Text (ein Text, der in mindestens einem Durchlauf
  verweigert wurde, ist ein Treffer); die Rate je Durchlauf wird zusätzlich ausgewiesen.
- **AC-4:** `GuardrailReportTests` (Simulator, `sim.sh sim-unit`) prüfen mit gestellten Ergebnissen: jede Fehlerart landet in der richtigen Spalte; `rateLimited` und `timeout` erhöhen die
  Verweigerungsrate nicht; 0 Treffer (Rate 0, Wilson-Grenze und Dreierregel-Hinweis stimmen für n = 387); 1 Treffer (≈ 0,26 %, Grenze ≈ 1,4 %); „immer“ gegen „manchmal“ bei zwei Durchläufen;
  Rate je Menge, Sprache und Gruppe; Schwellenurteil am Gesamtwert (z. B. 4 von 387 > 1 %).
- **AC-5:** Die neue Suite `RealModelGuardrailTests` trägt dieselben Gates wie `RealModelLatencyTests` (`.enabled(if: RealModel.isRequested)`, `.enabled(if: RealModel.isAvailable)`,
  `.serialized`); ohne `LOOSEENDS_REAL_MODEL=1` wird sie übersprungen, nie rot, und läuft nie in der CI. `RealModelGateTests` prüft das im Quelltext auch für die neue Suite, einschließlich der
  Namen `LOOSEENDS_GUARDRAIL_OUT` und `LOOSEENDS_FOCUSBLOX_CORPUS`.
- **AC-6:** Die Suite läuft je Text **2 Durchläufe** (jeder Text einmal je Durchlauf, auch nach einem Fehlschlag; kein Wiederholen, kein Abbruch nach Fehlern in Folge) über die 100 Texte aus
  `guardrail-corpus.json` und, wenn `LOOSEENDS_FOCUSBLOX_CORPUS` auf die Datei zeigt, über die 287 `rawText`-Sätze. Fehler werden mit `MeasurementErrorKind.classify` eingeordnet. Die Rohproben gehen als JSON
  nach `LOOSEENDS_GUARDRAIL_OUT`; ohne diese Variable schreibt die Suite nichts und bleibt grün. Die Rohdaten tragen die FocusBlox-Sätze nicht im Klartext: nur `id` (Index) und Menge,
  den Wortlaut nur für die heiklen 100 und für Treffer in der **lokalen** Auswertung, nicht in den eingecheckten Rohdaten (persönliche Daten). Ohne die Variable stehen im Lauf-Kopf
  der Rohdaten „nur 100er-Menge“, und der Bericht sagt das.
- **AC-7:** `./scripts/sim.sh real-model-guardrail` holt die Testsperre wie `real-model-latency`, prüft macOS ≥ Target und Apple Silicon, baut (`build-for-testing`), startet nur
  `RealModelGuardrailTests` (`test-without-building`), schreibt die Rohdaten nach `docs/artifacts/71-guardrails/` und bricht bei fehlender Datei mit Meldung ab. Es fasst kein iPhone, iPad oder keine Watch an.
- **AC-8:** Der Mess-Durchlauf ist gelaufen (Nachweis: der Lauf selbst, kein automatischer Test; die Suite steht hinter dem Gate) und der Bericht `docs/reference/modell-guardrails.md` enthält:
  Gerät und System (`sw_vers`, Chip), Weg, Läufe und ob der FocusBlox-Korpus dabei war; die Raten je Fehlerart getrennt (guardrail, refusal, rateLimited, timeout, übrige) je Menge, Sprache und Gruppe;
  jeden Treffer mit Wortlaut und „immer/manchmal“; die **Nulllinie** (Regel-Spalte 0 % per Konstruktion) mit dem Satz „Ohne Modell geht es nicht, weil …“; den Statistikabschnitt (387 Texte, 1 % ≈ 3,9 Treffer, obere
  Grenze bei 0 Treffern ≈ 0,8 % und bei 1 Treffer ≈ 1,4 %, die 100 heiklen allein tragen die Schwelle nicht: ein Treffer = 1 %, 0 Treffer → obere Grenze ≈ 3 %); den Hinweis „Mac = ältere Modellgeneration, ersetzt das iPhone nicht“; die Recherche-Quellen
  mit den Befunden aus „Purpose“; die **Entscheidung gemäß Abbruchkriterium** für die Mac-Spalte (≤ 1 %: B3 trägt auf dem Mac; > 1 %: Folgeticket „Modell hat abgelehnt“ als sichtbarer Zustand statt stummem „ungeprüft“, mit den Alternativen
  A/B/C und dem Regelweg); den offenen Punkt „iPhone → Schnitt 2, nur nach Hennings wörtlichem ‚jetzt ist ein Test möglich‘, gebündelt mit #88 Teil 2“. Der Bericht entscheidet B3 **nicht** endgültig vor Schnitt 2.
- **AC-9:** `EnrichmentCoordinator.swift`, `FoundationModelsEnricher.swift`, `Measurement/Corpus.swift`, `LooseEndsLab/MeasurementRunner.swift` und alles unter `Shared/` bleiben unverändert
  (die Dateiliste des PR enthält dort nichts). `docs/reference/focusblox-corpus.json` wird nicht eingecheckt.

## Scope

**Affected Files:** fünf Code- und Skriptdateien (`Measurement/GuardrailReport.swift`, `GuardrailReportTests.swift`, `RealModelGuardrailTests.swift`, `RealModelGateTests.swift`, `scripts/sim.sh`)
plus Bericht und Rohdaten (Beleg, kein Code). Geschätzt ≈ +230 LoC ohne Bericht und Rohdaten. Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Änderung am Produktpfad.
**Kein Pfad der Geräteliste berührt.**

**Mac als Messort:** Der Lauf geschieht auf dem Entwicklungsrechner dieser Sitzung über den Mac-Weg des echten Modells (wie `real-model`, #531, und `real-model-latency`, #534), nicht auf einem Gerät, das Henning
als Testziel führt; eigene Rechner-Ressourcen sind laut globaler Regel nicht betroffen. Unit-Tests laufen weiter nur im Simulator (`sim.sh sim-unit`).

**Schnitt 2 (eigener Workflow, #71 bleibt bis dahin offen):** Läufer-Schalter `--count-failures` und `Corpus` mit `rawText`, Labor-App-Aufruf, iPhone-Spalte im Bericht; ein einziger Gerätedurchgang, gebündelt mit
#88 Teil 2, erst nach Hennings wörtlichem „jetzt ist ein Test möglich“ (Stufe 3).

## Test Plan

**Zuordnung AC → Test:** AC-1 bis AC-4: `GuardrailReportTests` (Simulator, Funktionsnamen entstehen in TDD RED und werden dort eingetragen). AC-5: `RealModelGateTests` (Quelltext-Gate).
AC-6, AC-7, AC-8: Nachweis ist der Mess-Lauf `sim.sh real-model-guardrail` samt Rohdaten und Bericht, kein automatischer Test (Begründung unten). AC-9: Dateiliste des PR.
Die DoD „durch Test belegt“ gilt daher für AC-1 bis AC-5 und AC-9; AC-6 bis AC-8 durch den Lauf.

RED: `GuardrailReportTests` schlagen fehl (Typ fehlt), solange `GuardrailReport.swift` fehlt; der Quelltext-Test in `RealModelGateTests` schlägt fehl, solange `RealModelGuardrailTests.swift` oder eines der Gates fehlt.
GREEN: beide grün. Der Mess-Durchlauf `sim.sh real-model-guardrail` ist der Nachweis für AC-6/7/8: dafür gibt es keinen automatischen Test, nur den Lauf selbst, denn die Suite steht hinter `LOOSEENDS_REAL_MODEL` und läuft nie in der CI;
ein Test der Suite wäre selbst ein Modelllauf. Die Auswertelogik deckt `GuardrailReportTests` mit gestellten Daten ab. Simulator-Durchlauf: kein sichtbarer Ablauf geändert; `sim.sh sim-unit` bleibt grün, `sim.sh build` baut.

## Alternativen

- **A. Nicht messen, nur absichern:** Im Produkt bleibt eine Verweigerung stumm, die Regelwerte stehen (`ModelFailure.isPermanent`). Dann würde B3 vom Tor zur Beobachtung. Verworfen: B3 ist Teil des Tors für
  externe Tester (Epic #370), und Henning will die tragenden Annahmen vor dem Bauen geprüft. Betroffen wäre die Annahmentabelle in `06-annahmen-und-experimente.md`, keine ADR.
- **B. Sichtbarer Zustand „Modell hat abgelehnt“ erst bei Überschreitung (gewählt als Folge):** nur bei > 1 % bauen, als Folgeticket. Kippt ADR-4 nicht (Anreicherung läuft weiter einmal).
- **C. Nur Mac messen, iPhone weglassen:** spart den Gerätedurchgang, aber der Mac hat die ältere Modellgeneration und das iPhone ist das Gerät der Tester. Nicht empfohlen; deshalb Schnitt 2.
- **Regelweg als Rückfall bei Überschreitung:** „Parser ohne Modell für diese Aufgabe“ — die Regeln verweigern nie. Das ersetzte nur die Verfeinerung (Titel, Dauer, Wichtigkeit/Dringlichkeit) durch Regelwerte; berührte die Modellrolle
  aus ADR-5 („das Modell setzt keine Kontexte“) nicht, bei Überschreitung wäre die Abgrenzung des Modells neu zu fassen.
- **Python-Auswertung statt Swift:** verworfen; die Fehlerart-Einordnung liegt schon in Swift (`MeasurementErrorKind`), und `GuardrailReport` wird in Schnitt 2 für die Labor-App wiederverwendet.

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt
- [ ] `GuardrailReportTests` und `RealModelGateTests` grün; `sim.sh sim-unit` grün; `sim.sh build` baut
- [ ] `sim.sh real-model-guardrail` gelaufen, Rohdaten unter `docs/artifacts/71-guardrails/` und Bericht im Repo
- [ ] #71 kommentiert (Stand Schnitt 1, Rest = Schnitt 2, bei > 1 % Folgeticket „Modell hat abgelehnt“ angelegt)

## Changelog

- 2026-10-27: Initial (Schnitt 1 von 2)
