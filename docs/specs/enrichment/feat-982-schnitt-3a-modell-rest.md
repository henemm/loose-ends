---
entity_id: feat-982-schnitt-3a-modell-rest
type: refactor
created: 2026-11-27
updated: 2026-11-27
status: draft
workflow: feat-982-s3-aufraeumen
---

# Spec: Modell-Rest aufräumen, Schnitt 3a (Feature #982, Epic #999)

## Approval

- [ ] Approved

## GitHub Issue

#982 (Epic #999). Henning, 2026-11-26: „Die AI hat in der Summe keinen Mehrwert, sondern stört eher.“ Entscheidung:
ADR-22 (`docs/project/00-entscheidungen.md`): das On-Device-Modell verlässt den Produktweg. Schnitt 1 (Modell aus dem
Produktweg) und Schnitt 2 (Onboarding ohne Modellhinweis) sind ausgeliefert, #1000 ist komplett. Dieser Schnitt ist der
erste Teil von „Schnitt 3 – Aufräumen“ und räumt den toten Modellcode ab, der noch in die App kompiliert wird.

## Purpose

Seit Schnitt 1 ruft kein Produktcode mehr das Modell auf. Übrig sind Helfer, die nur noch Tests benutzen
(`ModelDeadline`, `ModelFailure`, `EnrichmentWriter.apply`, `EnrichmentCoordinator.examples`, drei Titelprüfungen in
`TitleRule`) und zwei Katalogtexte, die nichts mehr anzeigt. Der Schnitt löscht sie samt der Tests, die nur sie prüften,
und schreibt den CLAUDE.md-Absatz „Rules before the model“ auf den Stand nach ADR-22. Kein sichtbares Verhalten ändert sich.

## Nicht in diesem Schnitt

- Datenschutztext, der das Modell noch nennt: nur nach Hennings Freigabe.
- Schärfen der Regeln an Hennings Aufnahmen: #1001.
- Der Enricher selbst (siehe Alternativen b und c).
- Die Gerätepunkte von #982 S1 und #1000: laufen über den TestFlight-Bau, der am 2026-11-27 aus `main` (`4aa4632`) gestartet
  wurde (Lauf 45987635148). Sie stehen in der Definition of Done, nie als AC.

## Was bleibt (Definition of Done von #982: Messcode und Labor-App bleiben)

- `Shared/Enrichment/FoundationModelsEnricher.swift`, `EnrichmentDraft.swift` samt `EnrichmentInput`, `EnrichmentExample`,
  `TaskEnricher`, `EnrichmentParsing`; `EnrichmentDraft.Guess` benutzen alle Regeln.
- `Measurement/`, `LooseEndsLab/`, `RealModel*Tests`, `TitleFidelityPromptTests`, `EnergyTests`,
  `ImportanceUrgencyRuleTests`, `Language/ModelPromptLanguagesTests`, `ModelAnswerMappingTests`.
- Alte Daten: `FieldSource.ai`, Revisions-Autor `.ai`; die Katalogschlüssel „Estimated by Apple Intelligence“
  (`FieldEditorView.swift`) und „The project was a guess of the model, not from your words.“ (`GuessedProjects.swift`).
- Von `EnrichmentWriter`: `Mode`, `mayWrite`, `userHasTouched`, `encode` (der Coordinator benutzt sie).
- `RuleGoldenTests` und `Fixtures/rule-golden.json` unverändert, kein Auffrischen.

## Alternativen

1. **(b) Enricher und Modelltypen aus dem App-Ziel herausziehen** (in ein Lab-/Test-Verzeichnis, `project.yml`). Etwa −370
   LoC App-Code, über dem Limit, und `project.yml` verlangt die Geräteliste. Das Binary hätte dann keinen Modellcode mehr.
   Mittleres Risiko (Lab-Bau und `real-model*` müssten weiter bauen). Bleibt ein möglicher späterer Schnitt S3b, nur wenn
   ein Compile-Beweis für App, Lab, Tests und UI-Tests gelingt; Watch, Widget und Share schließen den Enricher heute schon
   per `#if canImport(FoundationModels)` aus. Kippt keine ADR.
2. **(c) Modelltests und Labor-Modellpfad löschen.** Gleicher App-Umfang wie (b), dazu acht Testdateien und die Labor-App.
   Widerspricht der DoD von #982 („Messcode bleibt“); bräuchte Hennings Entscheidung. Verworfen für diesen Schnitt.
3. **Nichts löschen, nur Kommentare ergänzen.** Verworfen: toter Pfad, den jede neue Sitzung wieder für Produktcode hält
   (`EnrichmentWriter.apply` schreibt noch Modellwerte mit Autor `.ai`).

Gewählt: Variante (a), nur Löschungen im App-Code.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-22 (keine neue ADR)
- **Rationale:** Bestehende Entscheidung (Epic #999): kein Modell im Produkt. Der Schnitt entfernt Code, den nur noch Tests
  aufrufen; keine neue Entscheidung. Die Wahl der Variante (a) kippt keine ADR.

## Source

- **File:** `Shared/Enrichment/EnrichmentWriter.swift`
- **Identifier:** `EnrichmentWriter.apply(_:to:…)`, `EnrichmentWriter.confidenceThreshold`; außerdem `ModelDeadline`,
  `ModelFailure`, `EnrichmentCoordinator.examples(in:)`, `EnrichmentCoordinator.exampleLimit`, `TitleRule.isFromNote`,
  `TitleRule.borrows`, `TitleRule.addsDate`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `EnrichmentCoordinator` | module | Benutzt `Mode`, `mayWrite`, `userHasTouched`, `encode` weiter; verliert `examples(in:)` |
| `LooseEndsTests/RealModelTests.swift` | test | Nutzt `TitleRule.isFromNote` (Messtest); bekommt eine private Hilfsfunktion, bleibt kompilierbar |
| `FoundationModelsEnricher` | module | Bleibt; benutzt weder `ModelDeadline` noch `ModelFailure` (grep 2026-11-27: 0 Treffer in Enricher, `LooseEndsLab/`, `Measurement/`) |
| `scripts/test_catalog_languages.py` | script | Katalogwächter; bleibt grün nach dem Löschen der zwei Schlüssel |
| `scripts/test_onboarding_ohne_modell.py` | script | Vorlage für den neuen Abwesenheitstest |
| `LanguagePacks.titleDateWords` | module | Einziger Leser im Code ist `TitleRule.dateWords` (für `addsDate`, grep 2026-11-27). Die Wortliste ist Teil der Sprachpakete (`LanguagePack`, `TestPack`) und bleibt in diesem Schnitt samt Pack-Tests unberührt; danach unbenutzt, Aufräumen mit #1001 |

## Scope

### Affected Files

| Datei | Change | Was |
|---|---|---|
| `Shared/Enrichment/ModelDeadline.swift` | DELETE | nur `ModelSeamTests` benutzt sie (28 LoC) |
| `Shared/Enrichment/ModelFailure.swift` | DELETE | nur `ModelSeamTests` benutzt sie (21 LoC) |
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | `apply(_:…)` und `confidenceThreshold` weg; Typkommentar auf die verbleibenden Helfer (`Mode`, `mayWrite`, `userHasTouched`, `encode`) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | `examples(in:)` und `exampleLimit` weg |
| `Shared/Services/TitleRule.swift` | MODIFY | `isFromNote`, `borrows`, `addsDate` samt privatem `contentWords` und `dateWords` weg; einziger Nicht-Test-Aufrufer war `EnrichmentWriter.apply` (grep) |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | zwei Schlüssel weg: „That happens by itself once Apple Intelligence is ready.“ und „Apple Intelligence did not run, only the rules.“ (im Code nicht referenziert, grep) |
| `CLAUDE.md` | MODIFY | Absatz „Rules before the model“ und Eintrag `Shared/Enrichment` auf den Stand nach ADR-22; Satz „Until #1001 lands, …“ fällt weg |
| `LooseEndsTests/ModelSeamTests.swift` | MODIFY (Test) | `ModelSeamTests` (Klassifikation über `ModelFailure`) und `ModelDeadlineTests` weg; `ModelAnswerMappingTests` bleiben |
| `LooseEndsTests/EnrichmentTests.swift` | MODIFY (Test) | Tests von `EnrichmentWriter.apply` und von `examples(in:)` weg; `StubEnricher` weg, wenn danach unbenutzt |
| `LooseEndsTests/TitleRuleTests.swift` | MODIFY (Test) | Tests von `isFromNote`, `addsDate`, `borrows` und die zwei `apply`-Tests weg |
| `LooseEndsTests/ReanalysisTests.swift` | MODIFY (Test) | die eine `apply`-Stelle (Z. 171) ersetzen oder entfernen |
| `LooseEndsTests/RevisionServiceTests.swift` | MODIFY (Test) | die eine `apply`-Stelle (Z. 20) ersetzen |
| `LooseEndsTests/RealModelTests.swift` | MODIFY (Test) | private lokale Kopie von `isFromNote` für die Messung |
| `scripts/test_modell_rest_entfernt.py` | CREATE (Test) | Abwesenheitsbeleg (AC-1 bis AC-3) |

### Entscheidung je Testdatei (vor der Umsetzung festgelegt, in der Umsetzung nur bei Befund anpassen)

- `ModelSeamTests`: reiner Beleg für gelöschten Code (Klassifikation der Fehler, Zeitlimit); wird gelöscht, nichts ersetzt.
- `EnrichmentTests`: Tests, die nur prüfen, was `apply` schreibt (Schwelle, Titelwahl, Dauer, Autor `.ai`), werden gelöscht.
  Tests, die über den Coordinator laufen und `apply` nur zum Vorbereiten benutzten, bekommen den Vorzustand direkt
  (Felder und `Revision` von Hand gesetzt). Jede gelöschte Stelle wird im Abschlussbericht einzeln benannt.
- `TitleRuleTests`: die drei Prüfungen entfallen mit ihrem Code; die Tests von `TitleRule.title(from:)` bleiben.
- `ReanalysisTests`, `RevisionServiceTests`: je Test entscheiden; was eine Regel- oder Revisionswirkung beweist, bleibt und
  setzt den Vorzustand direkt (etwa über `RevisionService` oder Feldzuweisung mit Revision), was nur den Modellschreiber
  bewies, entfällt.

### Estimated Changes

- App-Code (zählt ins Limit): 5 Swift-Dateien (`ModelDeadline`, `ModelFailure`, `EnrichmentWriter`, `EnrichmentCoordinator`,
  `TitleRule`), etwa −216 LoC (28 + 21 + ca. 100 + ca. 22 + ca. 45), dazu der Katalog (zwei Schlüssel, etwa −20 Zeilen
  JSON) und CLAUDE.md (Dokumentation, nicht App-Code). Innerhalb von 4–5 Dateien und ±250 LoC.
- Tests (zählen nicht): 6 Testdateien und 1 neues Skript, etwa −450 / +70 LoC.

## Implementation Details

Reihenfolge: zuerst `scripts/test_modell_rest_entfernt.py` schreiben und rot laufen lassen (TDD RED). Dann vor jedem
Löschen per grep belegen, dass kein Aufrufer außerhalb der genannten Tests bleibt (`ModelDeadline`, `ModelFailure`,
`EnrichmentWriter.apply(`, `StubEnricher`, `examples(in:`, `isFromNote`, `addsDate`, `borrows`, `titleDateWords`,
`confidenceThreshold`, `exampleLimit`). Dann löschen, Tests anpassen, `./scripts/sim.sh generate` (Dateien fallen weg),
bauen. `RealModelTests` bekommt `isFromNote` als private Hilfsfunktion im Test, damit der Messtest weiter kompiliert; der
Messcode bleibt Messcode. Beim Katalog werden nur die zwei Schlüssel samt Übersetzung entfernt (JSON-Formatierung wie
Xcode: zwei Leerzeichen, `" : "`); nach dem Bau wird `git diff` des Katalogs geprüft, damit Xcode nichts zurückschreibt.

Abwesenheitstest (Muster `scripts/test_onboarding_ohne_modell.py`), Suchbereiche bewusst eng gefasst, weil andere Tests den
alten Namen absichtlich nennen dürfen: Die Namen `ModelDeadline`, `ModelFailure`, `StubEnricher` und `examples(in:` werden
in `LooseEnds`, `Shared`, `LooseEndsTests`, `LooseEndsLab` und `Measurement` gesucht; `EnrichmentWriter.apply(` nur als
Aufruf (Regex mit `EnrichmentWriter\.apply\(`), nicht der Name `EnrichmentWriter` insgesamt, weil `Mode` und `mayWrite`
dort bleiben. Die Katalogprüfung liest `Localizable.xcstrings` als JSON und prüft Schlüssel, nicht Textsuche.
Kommentare, die den alten Namen als Geschichte nennen, gelten als Treffer und werden mit entfernt.

## Test Plan

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN den Repo-Stand vor der Umsetzung WHEN `python3 scripts/test_modell_rest_entfernt.py` läuft THEN schlägt
  er fehl (Dateien vorhanden, Aufrufe vorhanden, zwei Schlüssel im Katalog); nach der Umsetzung besteht er.
- [ ] Test 2: GIVEN den Stand nach der Umsetzung WHEN `./scripts/sim.sh unit` läuft THEN sind alle Unit-Tests grün,
  einschließlich `RuleGoldenTests` ohne Auffrischen und `RealModelTests` übersetzt (Messtests laufen nicht gegen das Modell).
- [ ] Test 3: GIVEN den Stand nach der Umsetzung WHEN `./scripts/sim.sh build` und `python3 scripts/test_catalog_languages.py`
  laufen THEN bauen App und Labor-Ziel und der Katalogwächter ist grün.
- [ ] Test 4: GIVEN den Simulator WHEN `./scripts/sim.sh test-proof NoModelCaptureTests` läuft THEN wird „Vor Konzert“
  erfasst, steht sofort in der Liste mit Titel „Vor Konzert“ und ohne Dauer; Belegdatei des Werkzeugs und Screenshot
  werden geöffnet und beschrieben.
- [ ] Test 5: GIVEN `EnrichmentTests`, `TitleRuleTests`, `ReanalysisTests`, `RevisionServiceTests` nach der Anpassung WHEN sie
  laufen THEN bleiben die Tests der Regeln (Titel aus Rohtext, Re-Analyse der Regeln, Revisionen und Zurücksetzen) grün.

## Acceptance Criteria

- **AC-1:** Die Dateien `Shared/Enrichment/ModelDeadline.swift` und `Shared/Enrichment/ModelFailure.swift` gibt es nicht
  mehr, und in `LooseEnds`, `Shared`, `LooseEndsTests`, `LooseEndsLab`, `Measurement` steht weder `ModelDeadline` noch
  `ModelFailure` noch `StubEnricher` (Test 1).
- **AC-2:** In denselben Verzeichnissen gibt es keinen Aufruf `EnrichmentWriter.apply(`, kein `examples(in:`, kein
  `confidenceThreshold` und kein `exampleLimit`; `TitleRule` hat kein `isFromNote`, `addsDate`, `borrows` im App-Code
  (nur die private Hilfsfunktion in `RealModelTests`). `Mode`, `mayWrite`, `userHasTouched` und `encode` stehen weiter
  in `EnrichmentWriter` (Test 1).
- **AC-3:** `Localizable.xcstrings` enthält „That happens by itself once Apple Intelligence is ready.“ und „Apple
  Intelligence did not run, only the rules.“ nicht mehr, aber weiter „Estimated by Apple Intelligence“ und „The project
  was a guess of the model, not from your words.“; der Katalogwächter ist grün (Tests 1, 3).
- **AC-4:** `./scripts/sim.sh build` und `./scripts/sim.sh unit` sind grün; `RuleGoldenTests` laufen ohne Änderung an
  `rule-golden.json` (Test 2).
- **AC-5:** Messcode und Labor-App bleiben: `FoundationModelsEnricher`, `EnrichmentDraft`, `Measurement/`, `LooseEndsLab/`
  und die genannten Messtests bestehen weiter und kompilieren (Tests 2, 3).
- **AC-6:** Im Simulator wird „Vor Konzert“ erfasst und steht mit Titel „Vor Konzert“ und ohne Dauer in der Liste
  (`./scripts/sim.sh test-proof NoModelCaptureTests`, Test 4).
- **AC-7:** `CLAUDE.md` beschreibt unter „Rules before the model“ den Stand nach ADR-22 (kein Modell im Produkt, Felder
  nur aus Regeln und nur aus dem Gesagten, Messcode lebt in `Measurement/`, der Labor-App und den Messtests); der Satz
  „Until #1001 lands, the paragraph below describes the rest as it still is.“ steht nicht mehr; der Eintrag
  `Shared/Enrichment` unter „Where things live“ nennt kein `ModelDeadline` mehr und sagt, dass die Modelldateien nur für
  Labor-App und Messtests da sind (Durchsicht des Diffs).

## Risiken

- **Tests, die `apply` nur zum Vorbereiten nutzten:** ein ersatzloses Löschen würde Regelverhalten ungeprüft lassen. Je
  Stelle wird entschieden (siehe oben) und im Bericht benannt.
- **Xcode schreibt den Katalog beim Bauen zurück:** nach dem Bau `git diff` des Katalogs prüfen.
- **Generiertes Projekt:** nach Löschen von Dateien `./scripts/sim.sh generate`, sonst baut Xcode mit toten Verweisen.
- **Hotspot `CLAUDE.md`:** offener PR #968 ändert dieselbe Datei; vor dem PR `main` einarbeiten und Konflikt prüfen.
- **Abwesenheits-AC gegen Tests, die den Namen absichtlich nennen** (Erfahrung aus S2): der Suchbereich ist oben
  festgelegt; `RealModelTests` nennt `isFromNote` nur als private Hilfsfunktion, und kein AC verbietet das.

## Definition of Done

- [ ] Build grün (`./scripts/sim.sh generate`, dann `./scripts/sim.sh build`)
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh unit`), `RuleGoldenTests` unverändert
- [ ] `python3 scripts/test_modell_rest_entfernt.py` und `python3 scripts/test_catalog_languages.py` grün
- [ ] UI-Tests grün (CI); Simulatorbeleg über `./scripts/sim.sh test-proof NoModelCaptureTests`
- [ ] Gerätestufe: Dieser Schnitt berührt von der Geräteliste nur `Shared/Enrichment/EnrichmentCoordinator.swift`, und nur
  durch Löschen von `examples(in:)`, das im Coordinator selbst keinen Aufrufer hat (grep 2026-11-27: nur die Definition, Z. 517) – kein Modellaufruf-Pfad, den gibt es seit S1 nicht mehr. Nach Ausnahme #680 endet die Abnahme nach Stufe 2; der Bericht sagt „Regelzweig, kein
  Modellaufruf, im Simulator belegt“.
- [ ] Gerätepunkte von #982 S1 und #1000: über den TestFlight-Bau vom 2026-11-27 (Lauf 45987635148); Hennings Rückmeldung
  schließt sie; bis dahin bleibt #982 offen (PR mit `Refs #982`)
- [ ] Ausgeliefert: PR, CI grün, gemergt; GitHub-Board aktuell

## Changelog

- 2026-11-27: Initial spec created
