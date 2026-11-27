# Kontext: feat-982-s3-aufraeumen (#982 Schnitt 3, Epic #999, ADR-22)

## Request Summary
#982 „Modell ausbauen“: Schnitt 1 (Modell aus dem Produktweg, 2026-11-26) und Schnitt 2 (Onboarding-Hinweis weg)
sind ausgeliefert, #1000 („Neu“ entfällt) ist seit 2026-11-27 komplett. Offen in #982:
1. **Schnitt 3 – Aufräumen:** toter Modellcode, der noch in die App kompiliert wird (`ModelDeadline`, `ModelFailure`,
   `EnrichmentWriter.apply`, `EnrichmentCoordinator.examples`, `StubEnricher`), Modelltests verorten, CLAUDE.md-Absatz
   „Rules before the model“, zwei tote Katalogschlüssel.
2. **Testbau für die Gerätepunkte:** Stufe 3 (Pfadliste: `EnrichmentCoordinator.swift`, berührt in S1) über TestFlight,
   bewusst gebündelt mit #1000. Letzter TestFlight-Lauf: 2026-11-24 (`c885f7a`) – also vor S1, S2 und ganz #1000.
   Diese Sitzung hält Epic #999 und darf damit den TestFlight-Bau starten (CLAUDE.md „One session, one scope“).
3. Datenschutztext nennt das Modell noch – nur nach Hennings Freigabe, nicht Teil dieses Schnitts.

## Related Files (Ist-Stand, gemessen im Worktree)
- `Shared/Enrichment/ModelDeadline.swift` (28 LoC) – nur noch von `LooseEndsTests/ModelSeamTests.swift` benutzt.
- `Shared/Enrichment/ModelFailure.swift` (21 LoC, `import FoundationModels`) – nur von `ModelSeamTests` benutzt.
- `Shared/Enrichment/FoundationModelsEnricher.swift` (113 LoC) – in App-Ziel (über `Shared/`) und Labor-App
  (`project.yml` LooseEndsLab listet die Datei einzeln); benutzt von `LooseEndsLab/MeasurementRunner.swift:52` und den
  Messtests `RealModel*Tests`, `TitleFidelityPromptTests`, `EnergyTests`, `ImportanceUrgencyRuleTests`, `ModelSeamTests`,
  `Language/ModelPromptLanguagesTests` (per `@testable import LooseEnds`).
- `Shared/Enrichment/EnrichmentDraft.swift` (76 LoC): `EnrichmentDraft.Guess` wird von allen Regeln benutzt (bleibt);
  `EnrichmentInput`, `EnrichmentExample`, `TaskEnricher`, `EnrichmentParsing` nur noch vom Enricher/Messcode.
- `Shared/Enrichment/EnrichmentWriter.swift` (133 LoC): `apply(_ draft:…)` schreibt Modellentwürfe – im Produkt tot;
  `Mode`, `mayWrite`, `userHasTouched`, `encode` benutzt der Coordinator (bleiben).
- `Shared/Enrichment/EnrichmentCoordinator.swift:513–534` `examples(in:)` + `exampleLimit` (Z. 12) – nur Testaufrufer
  (`EnrichmentTests.swift:212`).
- Tests mit `EnrichmentWriter.apply`/`StubEnricher`: `EnrichmentTests` (9 Stellen, 950 LoC), `TitleRuleTests` (2),
  `ReanalysisTests` (1), `RevisionServiceTests` (1).
- `LooseEnds/Resources/Localizable.xcstrings`: „That happens by itself once Apple Intelligence is ready.“ und
  „Apple Intelligence did not run, only the rules.“ – im Code nicht mehr referenziert.
  **Bleiben** (alte KI-Werte stehen weiter in Aufgaben): „Estimated by Apple Intelligence“ (`FieldEditorView.swift:131`),
  „The project was a guess of the model, not from your words.“ (`GuessedProjects.swift:10`).
- `CLAUDE.md`: Absatz „Rules before the model“ und Zeile „Until #1001 lands …“ unter „No model, no "New"“;
  `Shared/Enrichment`-Eintrag unter „Where things live“.
- `project.yml` LooseEndsLab-Quellen (Z. 288 ff.), LooseEndsTests-Quellen (Z. 334 ff.).
- `.github/workflows/testflight.yml` – manueller Lauf mit Pflicht-Input `what_to_test` (de:/en:-Abschnitte, #760).

## Existing Patterns
- Abwesenheitsbelege als Python-Test `scripts/test_*.py` (S2: `scripts/test_onboarding_ohne_modell.py`).
- `scripts/test_catalog_languages.py` prüft Vollständigkeit der Kataloge; tote Schlüssel ohne `extractionState: stale`
  bleiben sonst unbemerkt.
- Messcode lebt in `Measurement/` (kompiliert in Tests und Labor-App, nie ins Produkt).

## Dependencies / Dependents
- Labor-App braucht `FoundationModelsEnricher` + `EnrichmentDraft` (Messungen #534, #71, #88 laufen dort).
- `sim.sh real-model*` fährt die `RealModel*Tests` auf dem Mac gegen das echte Modell.
- `RuleGoldenTests` halten die Regelausgabe fest – dürfen sich durch Aufräumen nicht ändern.

## Existing Specs
- `docs/specs/` für #982 S1/S2 (feat-982-…), ADR-22 in `docs/project/00-entscheidungen.md`.

## Risks
- **Pfadliste Stufe 3:** `project.yml` und `EnrichmentCoordinator.swift` stehen auf der Geräteliste → Stufe 3 ohnehin
  über den gebündelten TestFlight-Bau.
- Umfang: Löschen von Testcode zählt nicht ins LoC-Limit, App-Code-Löschungen schon; ±250 LoC App-Code im Blick.
- Verschieben des Enrichers aus `Shared/` heraus ändert, was ins App-Binary kommt; Watch/Widget/Share kompilieren
  `Shared/` ebenfalls (heute mit `#if canImport(FoundationModels)` geschützt).
- Messtests dürfen nicht stillschweigend wegfallen (Labor-Messungen bleiben laut DoD von #982).
- Parallele Sitzung w4 arbeitet in einem anderen Repo (Meditationstimer); offener PR #968 ändert CLAUDE.md
  (Hotspot-Überschneidung beim CLAUDE.md-Edit).

## Analysis

**Type:** Feature (Aufräumen, kein sichtbares Verhalten ändert sich)

### TestFlight-Bau (Teil 2 des Auftrags) – erledigt in dieser Phase
Gestartet 2026-11-27 12:06 MEZ aus `main` (`4aa4632`), Lauf 45987635148 (ein erster Lauf 45987542087 wurde sofort
abgebrochen: „Was testen“ nannte 20 min, die Regel rundet auf den Eimer 30 min auf). Begründung „jetzt, nicht nach S3a“:
S3a ändert kein Verhalten, die Gerätepunkte betreffen #982 S1 und #1000; Warten verzögert nur Hennings Prüfung.
„Was testen“ (de/en): „Vor Konzert“ → sofort in der Liste, kein „Neu“, Titel genau „Vor Konzert“, keine Dauer, kein
KI-Stern, kein „Passt“; „Steuer 30 Minuten“ → 30 min. Gerätepunkte von #982 bleiben offen bis Hennings Rückmeldung.

### Varianten (App-Code, aus wc/grep)
| | App-Dateien | App-LoC | App-Binary ohne Modellcode | Risiko |
|---|---|---|---|---|
| (a) nur tote Helfer löschen | 5 (`ModelDeadline`, `ModelFailure`, `EnrichmentWriter`, `EnrichmentCoordinator`, `TitleRule`) + xcstrings, CLAUDE.md | ca. −220 | nein, `FoundationModelsEnricher` bleibt | gering |
| (b) Enricher + Modelltypen in ein Lab/Test-Verzeichnis | (a) + `FoundationModelsEnricher`, `EnrichmentDraft`, `project.yml` | ca. −370, über Limit | ja | mittel: `#if canImport(LooseEnds) @testable import`, Lab-Bau und `real-model*` nötig |
| (c) Modelltests + Labor-Modellpfad löschen | wie (b) + Lab + 8 Testdateien | ca. −370 | ja | widerspricht DoD („Messcode bleibt“), PO nötig |

**Empfehlung: (a) als dieser Schnitt (S3a).** (b) als eigener späterer Schnitt S3b nur, wenn ein Compile-Beweis
(Lab, Tests, UITests) gelingt; sonst bleibt der Enricher als bekannter Restposten (Watch/Widget/Share schließen ihn heute
schon per `#if` aus). Alternative (c) kippt die DoD-Zeile „Messcode in `Measurement/` und Labor-App bleibt“ (Henning).

### Affected Files (S3a)
- DELETE `Shared/Enrichment/ModelDeadline.swift`, `Shared/Enrichment/ModelFailure.swift`
- MODIFY `Shared/Enrichment/EnrichmentWriter.swift` – `apply(_:…)` und `confidenceThreshold` raus; `Mode`, `mayWrite`,
  `userHasTouched`, `encode` bleiben (Coordinator)
- MODIFY `Shared/Enrichment/EnrichmentCoordinator.swift` – `examples(in:)`, `exampleLimit` raus
- MODIFY `Shared/Services/TitleRule.swift` – `isFromNote`, `addsDate`, `borrows` raus, falls nach Prüfung keine weiteren
  Aufrufer (`RealModelTests` nutzt `isFromNote` → dort lokal ersetzen oder Test-Hilfe)
- MODIFY `LooseEnds/Resources/Localizable.xcstrings` – zwei tote Schlüssel
- MODIFY `CLAUDE.md` – „Rules before the model“ auf den Stand nach ADR-22 kürzen, `Shared/Enrichment`-Eintrag
- Tests: `ModelSeamTests` (Deadline/Failure-Teile), `EnrichmentTests` (`StubEnricher`, apply-Tests, `examples`-Test),
  `TitleRuleTests`, `ReanalysisTests`, `RevisionServiceTests`; NEU `scripts/test_modell_rest_entfernt.py` (Abwesenheit)
- Prüfen: `EnrichmentInput.examples`/`EnrichmentExample` bleiben (Enricher und Messcode brauchen sie).

### Scope / Risk
5 App-Swift-Dateien + Katalog + CLAUDE.md; App-Code nur Löschungen (~−220 LoC). Risiko gering: kein Produktaufrufer
(per grep belegt). `EnrichmentCoordinator.swift` steht auf der Geräteliste → Stufe 3 läuft ohnehin über den gestarteten
TestFlight-Bau bzw. den nächsten; Bericht nach Ausnahme #680 („Regelzweig, kein Modellaufruf, im Simulator belegt“).

### Technical Approach
Abwesenheitstest zuerst (RED), dann löschen, Tests anpassen, `RuleGoldenTests` + `sim.sh unit` grün, Simulator-Durchlauf
„Vor Konzert“ mit `NoModelCaptureTests` per `test-proof`.

### Open Questions
Keine an den PO. Datenschutztext bleibt außerhalb (nur nach Hennings Freigabe).
