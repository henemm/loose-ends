# Adversary Dialog — feat-982-s3-aufraeumen
Spec: docs/specs/enrichment/feat-982-schnitt-3a-modell-rest.md
Datum: 2026-11-27 12:25

## Checkliste
- [x] **AC-1:** Die Dateien `Shared/Enrichment/ModelDeadline.swift` und `Shared/Enrichment/ModelFailure.swift` gibt es nicht mehr, und in `LooseEnds`, `Shared`, `LooseEndsTests`, `LooseEndsLab`, `Measurement` steht weder `ModelDeadline` noch `ModelFailure` noch `StubEnricher` (Test 1).
- [x] **AC-2:** In denselben Verzeichnissen gibt es keinen Aufruf `EnrichmentWriter.apply(`, kein `examples(in:`, kein `confidenceThreshold` und kein `exampleLimit`; `TitleRule` hat kein `isFromNote`, `addsDate`, `borrows` im App-Code (nur die private Hilfsfunktion in `RealModelTests`). `Mode`, `mayWrite`, `userHasTouched` und `encode` stehen weiter in `EnrichmentWriter` (Test 1).
- [x] **AC-3:** `Localizable.xcstrings` enthält „That happens by itself once Apple Intelligence is ready.“ und „Apple Intelligence did not run, only the rules.“ nicht mehr, aber weiter „Estimated by Apple Intelligence“ und „The project was a guess of the model, not from your words.“; der Katalogwächter ist grün (Tests 1, 3).
- [x] **AC-4:** `./scripts/sim.sh build` und `./scripts/sim.sh unit` sind grün; `RuleGoldenTests` laufen ohne Änderung an `rule-golden.json` (Test 2).
- [x] **AC-5:** Messcode und Labor-App bleiben: `FoundationModelsEnricher`, `EnrichmentDraft`, `Measurement/`, `LooseEndsLab/` und die genannten Messtests bestehen weiter und kompilieren (Tests 2, 3).
- [x] **AC-6:** Im Simulator wird „Vor Konzert“ erfasst und steht mit Titel „Vor Konzert“ und ohne Dauer in der Liste (`./scripts/sim.sh test-proof NoModelCaptureTests`, Test 4).
- [x] **AC-7:** `CLAUDE.md` beschreibt unter „Rules before the model“ den Stand nach ADR-22 (kein Modell im Produkt, Felder nur aus Regeln und nur aus dem Gesagten, Messcode lebt in `Measurement/`, der Labor-App und den Messtests); der Satz „Until #1001 lands, the paragraph below describes the rest as it still is.“ steht nicht mehr; der Eintrag `Shared/Enrichment` unter „Where things live“ nennt kein `ModelDeadline` mehr und sagt, dass die Modelldateien nur für Labor-App und Messtests da sind (Durchsicht des Diffs).

## Dialog

### Runde 1
**Adversary:** Ich behaupte, der Schnitt ist kaputt, und suche an drei Stellen: (a) geloeschte Tests, die Regelverhalten belegten, (b) Reste toten App-Codes, (c) Beleg AC-6.
(a) Geloescht laut Diff der gestagten Aenderung: EnrichmentTests `appliesFieldsAboveThreshold`, `titleBelowThresholdIsUnverified`, `modelProjectIsIgnored`, `examplesComeFromDoneTasks`, `modelDoesNotOverwriteAnExistingValue`, `testModelTitleKeepsAUserTitleAndWritesWhereNoneHangs`; TitleRuleTests `modelTitleIsStruckToo`, `foreignModelTitleIsDropped`, `fromNote`, `dateInModelTitleIsDropped`, `addsDate`, `borrowedModelTitleIsDropped`, `borrows`; ReanalysisTests `firstRunStillGuardsDuration`. Alle riefen ausschliesslich `EnrichmentWriter.apply`, `TitleRule.isFromNote|addsDate|borrows` oder `examples(in:)` mit einem Modell-Draft auf. Regelanteil bleibt gedeckt: `DurationRuleCoordinatorTests.userValueStaysInFirstRun` (Z. 35), `ReanalysisTests.keepsWhatTheUserSet`/`ruleReplacesAISetField`, `KeyboardTitleTests`, `TitleRuleTests.coordinatorKeepsRuleTitle`/`userEmptiedTitleStaysEmpty`/`captureSetsTitle`. Tests, die apply nur zum Vorbereiten nutzten (RevisionServiceTests, ReanalysisTests, EnrichmentTests-Reset), setzen den Vorzustand per Hand (Revision plus Felder) und laufen gruen.
(b) Rest: `LanguagePacks.titleDateWords` hat keinen Leser mehr; die Spec nimmt das ausdruecklich aus (#1001). Keine verwaisten `pastNotes`/`ruleFields` (grep leer). `Mode`/`mayWrite`/`userHasTouched`/`encode` werden vom Coordinator benutzt (EnrichmentCoordinator.swift:137, :195, :241).
(c) Der Listen-Screenshot zeigt drei Zeilen "Vor Konzert", der Test erfasst eine. `sim.sh` deinstalliert fuer iOS nicht (nur Watch, sim.sh:684); Altbestand aus frueheren Laeufen. Die Detailpruefung nimmt `firstMatch`, kann also eine aeltere Zeile treffen.
**Implementierer:** keine eigene Antwort; Befunde in Runde 2 ausgewertet.

### Runde 2
**Adversary:** Nachbohren mit eigenen Laeufen. (1) AC-1/2: grep ueber LooseEnds, Shared, LooseEndsTests, LooseEndsLab, Measurement nach ModelDeadline|ModelFailure|StubEnricher|EnrichmentWriter.apply(|examples(in:|confidenceThreshold|exampleLimit|addsDate|borrows( : 0 Treffer; `isFromNote` nur privat in RealModelTests.swift:103. `scripts/test_modell_rest_entfernt.py` selbst gelaufen: 6 OK. (2) AC-3: Katalog-Diff entfernt genau zwei Zeilen; Bleibe-Schluessel da; `test_catalog_languages.py` selbst gelaufen: 9 OK. (3) AC-4: xcresult-Zusammenfassung 1385 gesamt / 1372 bestanden / 0 fehlgeschlagen / 13 uebersprungen (Zahl aus dem Beleg, nicht neu gefahren); rule-golden.json nicht im Diff. (4) AC-5: project.yml LooseEndsLab kompiliert Measurement, EnrichmentDraft.swift, FoundationModelsEnricher.swift, Enums.swift, RawTextWords.swift, keine davon im Diff; RealModelTests kompiliert im gruenen Unit-Lauf. Ein Lab-Build wurde nicht gefahren (Geraetebau verboten); Beleg ist die unveraenderte Quellmenge. (5) AC-6: test-proof 1/1 bestanden, 0 uebersprungen; Detail-Screenshot geoeffnet: Titel "Vor Konzert", "Nothing new found.", "+ Duration" leer, kein KI-Merkmal; Assertions im Test. (6) AC-7: CLAUDE.md-Diff beruehrt nur Satz "Until #1001", Absatz "Rules before the model", Subtask-/Schema-Satzreste, Eintrag Shared/Enrichment. Scope: 5 App-Swift-Dateien (2 Loeschungen) plus Katalog.
Restbefund zu (c): die Altzeilen entwerten den Beleg nicht (Regelpfad unveraendert, gepruefte Zeile korrekt), sind aber nicht hermetisch: LOW.
**Implementierer:** kein Widerspruch.

### Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/NoModelCaptureTests.swift:62
  Description: Die Zeilenabfrage nutzt firstMatch auf taskRow_* mit "Vor Konzert"; bei Altbestand im Simulator-Store (Screenshot: drei Zeilen) kann das Detail eine aeltere Aufgabe zeigen.
  Spec requirement: AC-6 — "Vor Konzert" wird erfasst und steht mit Titel und ohne Dauer in der Liste
  Conflict: Beleg nicht hermetisch; Abweichung unwahrscheinlich, da Regelpfad unveraendert.
  Remediation: Eindeutigen Text (Zeitstempel) oder Deinstallation vor dem Lauf; nicht in diesem Schnitt noetig.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: Shared/Services/TitleRule.swift:28
  Description: LanguagePacks.titleDateWords hat nach dem Entfernen von addsDate keinen Leser mehr, bleibt in Packs und Pack-Tests.
  Spec requirement: AC-2 — keine Reste von addsDate; Spec Dependencies nimmt die Wortliste ausdruecklich aus
  Conflict: Toter Datenbestand, laut Spec bis #1001 gewollt; kein Verstoss.
  Remediation: In #1001 entfernen.

### Confirmations

Confirmation:
  AC: AC-1
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:137
  Evidence: Dateien geloescht; grep ueber alle fuenf Verzeichnisse 0 Treffer; Abwesenheitstest 6 OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:17
  Evidence: nur Mode, mayWrite (Z. 17), userHasTouched, encode (Z. 34) bleiben; apply und confidenceThreshold weg; TitleRule hat nur title(from:); examples/exampleLimit weg.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:195
  Evidence: Katalog-Diff -2 Zeilen, Bleibe-Schluessel vorhanden, Waechter 9 OK; Coordinator nutzt Mode weiter (Z. 195, 241).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Services/TitleRule.swift:28
  Evidence: Unit-Lauf 1385/1372/0 fehlgeschlagen/13 uebersprungen; rule-golden.json nicht im Diff.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:7
  Evidence: Lab-Quellmenge in project.yml nicht im Diff; RealModelTests kompiliert im gruenen Unit-Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Enrichment/EnrichmentCoordinator.swift:90
  Evidence: test-proof 1/1 bestanden; Detail-Screenshot: Titel "Vor Konzert", keine Dauer, kein KI-Merkmal; drei Listenzeilen = Altbestand (F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:3
  Evidence: CLAUDE.md-Diff geprueft: nur die genannten Stellen.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Alle 7 ACs bewiesen; 0 fehlgeschlagen. Kein Regeltest ersatzlos verloren. Zwei LOW-Hinweise (F001, F002).

## Geprüfte Dateien

- sha256:ef79c58b387c5d94c02169bef92016baec8547944e0331912076a75238bb76dc  LooseEndsUITests/NoModelCaptureTests.swift
- sha256:8e1bd0a65ee0c18cbfe7931734281f0b4fb0c07ff215a4256395ed68c818027b  Shared/Enrichment/EnrichmentCoordinator.swift
- sha256:4e1423eb67b7bb40666aaedd9ade33f4e42e4ff057711932f23fc44633c98292  Shared/Enrichment/EnrichmentWriter.swift
- sha256:571a3976c865902c51558e4af4ee6868a641c21a895b6aed9c165e8af9857663  Shared/Services/TitleRule.swift

## Prüfbasis

- base: 4aa4632e9d2bb4926b459131a4eeda9c37bbe7b0
- blob:769867558e508c4c857521ccaa2395240181a07d  LooseEndsUITests/NoModelCaptureTests.swift
- blob:515c033a3b05edead06ba53dd94992c821da678a  Shared/Enrichment/EnrichmentCoordinator.swift
- blob:53edc8bb9d2e7145491317c2e3ee1833a1bbbb5b  Shared/Enrichment/EnrichmentWriter.swift
- blob:67ef451a701758c1200ae996edd5ad0788767dc2  Shared/Services/TitleRule.swift

## Geprüfte Dateien

- sha256:ef79c58b387c5d94c02169bef92016baec8547944e0331912076a75238bb76dc  LooseEndsUITests/NoModelCaptureTests.swift
- sha256:8e1bd0a65ee0c18cbfe7931734281f0b4fb0c07ff215a4256395ed68c818027b  Shared/Enrichment/EnrichmentCoordinator.swift
- sha256:4e1423eb67b7bb40666aaedd9ade33f4e42e4ff057711932f23fc44633c98292  Shared/Enrichment/EnrichmentWriter.swift
- sha256:571a3976c865902c51558e4af4ee6868a641c21a895b6aed9c165e8af9857663  Shared/Services/TitleRule.swift

## Prüfbasis

- base: 4aa4632e9d2bb4926b459131a4eeda9c37bbe7b0
- blob:769867558e508c4c857521ccaa2395240181a07d  LooseEndsUITests/NoModelCaptureTests.swift
- blob:515c033a3b05edead06ba53dd94992c821da678a  Shared/Enrichment/EnrichmentCoordinator.swift
- blob:53edc8bb9d2e7145491317c2e3ee1833a1bbbb5b  Shared/Enrichment/EnrichmentWriter.swift
- blob:67ef451a701758c1200ae996edd5ad0788767dc2  Shared/Services/TitleRule.swift
