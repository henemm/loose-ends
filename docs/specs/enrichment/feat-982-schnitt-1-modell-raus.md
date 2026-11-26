---
entity_id: feat-982-schnitt-1-modell-raus
type: feature
created: 2026-11-26
updated: 2026-11-26
status: draft
workflow: feat-982-modell-ausbauen
---

# Spec: Das Modell verlässt den Produktweg, Schnitt 1 (Feature #982, Epic #999)

## Approval

- [ ] Approved

## GitHub Issue

#982 (Epic #999). Henning, 2026-11-26: „Die AI hat in der Summe keinen Mehrwert, sondern stört eher.“ Entscheidung: ADR-22 (`docs/project/00-entscheidungen.md`). Analyse: `docs/context/feat-982-modell-ausbauen.md` (Abschnitt „Analysis“). Dieser Schnitt ist der erste von drei; das Issue bleibt danach offen.

## Purpose

Das On-Device-Modell (Apple Intelligence) wird im Produkt nicht mehr aufgerufen. Der Titel kommt allein aus `TitleRule` (setzt ihn bei der Erfassung), die Dauer nur, wenn der Text sie nennt (`DurationRule`) oder die Aufgabe wiedererkannt wird (`RecognitionRule`), sonst bleibt sie leer. „Neu analysieren“ läuft nur noch über die Regeln. Der `EnrichmentCoordinator` bekommt kein Modell mehr übergeben, damit der Compiler jeden Modellaufruf im Produkt ausschließt.

**Regeln vor Modell:** Hier wird dem Modell nichts hinzugefügt, es wird entfernt; alle Felder haben einen Regelweg, der heute schon auf Geräten ohne Apple Intelligence und in jedem UI-Test läuft. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt, weil kein Modell vorgeschlagen wird.

## Nicht in diesem Schnitt

- Status und Liste „Neu“ (#1000): neue Aufgaben bleiben in „Neu“, so wie heute schon auf Geräten ohne Apple Intelligence und in jedem UI-Test. Der Koordinator hob bisher `unprocessed` über das Modell; daran ändert dieser Schnitt nichts.
- Onboarding-Hinweis und seine Texte (`OnboardingFlow.ModelNote`, `OnboardingView`, Strings, `OnboardingTests`, Argument `--ui-testing-model-reason`): Schnitt 2. Hier wird nur die Quelle des Grundes abgeklemmt.
- Aufräumen (`ModelDeadline`, `ModelFailure`, `EnrichmentWriter.apply`, `examples`, Verortung der Modelltests, CLAUDE.md-Absatz „Rules before the model“, ADR-4-Hinweis): Schnitt 3.
- Datenschutztext (`docs/reference/datenschutz-entwurf.md`) und Website: getrennt, nur mit Hennings Freigabe.
- `FoundationModelsEnricher.swift` und `EnrichmentDraft.swift` bleiben unverändert und kompiliert; die Labor-App und `Measurement/` nutzen sie.
- Keine Migration, kein CloudKit-Schema, keine Änderung an `project.yml`.

## Was darf sich nicht ändern

- **Alte KI-Werte und ihre Revisionen** (Autor `.ai`, „Estimated by Apple Intelligence“) bleiben an den Aufgaben stehen; nichts wird gelöscht, umgeschrieben oder zurückgesetzt.
- **Regelfelder** (Fälligkeit, Wichtigkeit/Dringlichkeit, Kontexte, Projekt, Orte, Telefon, Dauer aus Text oder Wiedererkennung) werden wie bisher gesetzt; ihre Schreibregeln (`EnrichmentWriter.mayWrite`, `userHasTouched`) bleiben dieselben.
- **Teilschritte** (#565) laufen weiter nur über ihre zwei Regeln.
- **Labor-App und `Measurement/`** bauen und laufen unverändert.
- **Nutzerwerte** werden nie überschrieben.

## Alternativen

1. **Variante B: Naht behalten, einen „kein Modell“-Enricher verdrahten** (1–2 Dateien, ca. +10 LoC). Verworfen: die Modellzweige blieben im Koordinator, ADR-22 wäre nur durch Verdrahtung erfüllt, ein späteres Verdrahten brächte das Modell zurück, ohne dass der Compiler es meldet.
2. **Variante C: A plus Modelldateien aus dem App-Ziel nehmen** (6+ Dateien, `project.yml`, ca. −400 LoC). Verworfen für diesen Schnitt: sprengt die Limits, und `project.yml` ist eine Gerätepfad-Datei. Kommt, soweit nötig, in Schnitt 3.
3. **Modell nur auf Wunsch über „Neu analysieren“.** Von ADR-22 verworfen; bliebe der Modellteil von ADR-4 bestehen. Henning will das Modell ganz aus dem Produktweg.

Gewählt: Variante A. Die Alternative 3 würde den Modellteil von ADR-4 wieder aufrufen; ADR-22 hat ihn gekippt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-22
- **Rationale:** Bestehende Entscheidung (`docs/project/00-entscheidungen.md`, Epic #999): kein Modell im Produktweg, Felder nur aus Regeln. Sie kippt den Modellteil von ADR-4. Dieser Schnitt setzt sie im Koordinator um und braucht keine neue ADR.

## Source

- **File:** `Shared/Enrichment/EnrichmentCoordinator.swift`
- **Identifier:** `EnrichmentCoordinator.init`, `processPending`, `reanalyze`, `callModel`, `ReanalysisResult`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `EnrichmentCoordinator` | module | Verliert `enricher`/`modelTimeout`, `callModel` und die Modellzweige |
| `TaskItem.processedAt` / `rulesAppliedAt` | module | `processedAt` = „Modell lief“ (wird nicht mehr gesetzt), `rulesAppliedAt` = „Regelschritt lief“ (#144) |
| `EnrichmentWriter.mayWrite` / `userHasTouched` | module | Regeln für Erstlauf und Neuanalyse, unverändert |
| `TitleRule`, `DurationRule`, `RecognitionRule`, `DueDateRule`, `ContextWordRule` u. a. | module | Alle Felder kommen aus diesen Regeln, unverändert |
| `FoundationModelsEnricher`, `EnrichmentDraft` | module | Bleiben kompiliert für Labor-App und Messung, im Produkt ungenutzt |
| `ModelOffEnricher` (`LooseEndsApp.swift`) | app | Entfällt, es gibt keinen Enricher mehr |
| `OnboardingFlow` / `OnboardingView` | module | Bekommt keinen Modellgrund mehr; Argument `--ui-testing-model-reason=` bleibt bis Schnitt 2 |
| `TaskInteractions.listAnalysis` | module | Protokolliert nur das Ergebnis; Übersetzung prüfen, Änderung nicht erwartet |
| `StubEnricher` | test | Entfällt in den Koordinator-Tests |
| `LooseEndsUITests/CaptureCancelCrashTests` | test | Vorbild für den Start ohne `--ui-testing` mit `-onboardingDone YES` |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | `init(container:savedPlaces:)` ohne `enricher`/`modelTimeout`; `callModel`, Modellzweige in `processPending` und `reanalyze`, Logging „model unavailable“ raus; `ReanalysisResult.finished(changed:)`; Auswahl der Nachzügler `rulesAppliedAt == nil && processedAt == nil` in beiden Fetches |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | Kein `FoundationModelsEnricher`, `ModelOffEnricher` entfernt, neuer Init verdrahtet |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | Ergebnisfall ohne `modelRan`; Zeile „Apple Intelligence did not run, only the rules.“ entfällt |
| `LooseEnds/App/ContentView.swift` | MODIFY | Onboarding bekommt den Modellgrund nur noch aus dem UI-Test-Argument `--ui-testing-model-reason=`, sonst `nil` |
| `LooseEndsTests/*` (ca. 19 Dateien) | MODIFY/DELETE | Ca. 110 Konstruktionen `EnrichmentCoordinator(enricher:…)` mechanisch auf den neuen Init; `ModelUnavailableTests` und modellspezifische Stub-Fälle (`ModelSeamTests` Koordinatorteile, `EnrichmentTests`, `ReanalysisTests`) werden Regeltests oder entfallen |
| `LooseEndsTests/NoModelCoordinatorTests.swift` | CREATE | Neue XCTest-Klasse für AC-1 bis AC-7 und AC-10 |
| `LooseEndsUITests/NoModelCaptureTests.swift` | CREATE | Neue UI-Test-Klasse `NoModelCaptureTests` für AC-9 (echte Verdrahtung) |

`RealModel*Tests`, `TitleFidelityPromptTests` und `ModelPromptLanguagesTests` rufen `FoundationModelsEnricher` direkt auf (Messung) und kompilieren unverändert weiter.

### Estimated Changes

- Files: 4 App-Dateien (`EnrichmentCoordinator.swift`, `LooseEndsApp.swift`, `TaskDetailView.swift`, `ContentView.swift`), dazu Testdateien
- LoC App-Code: +~25/−~170 (die Zahl zählt Additions plus Deletions und liegt unter der 250-Grenze, wenn die entfernten Modellzweige knapp 200 Zeilen haben; zeigt sich beim Bauen mehr, vor dem Weitermachen per `AskUserQuestion` annehmen lassen oder teilen). Testcode zählt nicht mit.

## Implementation Details

**`EnrichmentCoordinator`:** Der Init heißt `init(container:savedPlaces:)`. `enricher`, `modelTimeout`, `callModel` und die Auswertung von `unavailableReason` entfallen, ebenso die Modellzweige in `processPending` und `reanalyze` samt der Protokollzeile „Model unavailable“. `ReanalysisResult` bekommt `finished(changed:)`; die Teilschritt-Zweige liefern dasselbe. `processPending` und `reanalyze` führen Regelschritt, `rulesAppliedAt` und Speichern wie bisher aus.

**Auswahl der Nachzügler:** Beide Fetches (unverarbeitete Aufgaben, aktive Aufgaben der obersten Ebene) wählen `rulesAppliedAt == nil && processedAt == nil`. Begründung: Ohne Modell bleibt `processedAt` für immer leer; mit der alten Auswahl `processedAt == nil` nähme jeder Lauf (Start, jede Erfassung) alle offenen Aufgaben erneut. `rulesAppliedAt` begrenzt auf einen Lauf je Aufgabe (ADR-4). Die Konjunktion mit `processedAt == nil` hält Aufgaben von vor #144 (Modell lief, Regelschritt nie markiert) heraus, damit sie keine nachträgliche Regel-Dauer bekommen. `processedAt` behält die Bedeutung „Modell lief“ und wird nur nicht mehr gesetzt.

**Neuanalyse (Regel, genau):** `reanalyze` schreibt über den Modus `.reanalysis`: ein Feld wird nur geschrieben, wenn die Regel einen anderen Wert findet (`changes`) und der Nutzer das Feld nie angefasst hat (`!userHasTouched`, d. h. keine Revision mit Autor `.user`). Ein alter KI-Wert steht also nur dann nicht mehr, wenn eine Regel für dasselbe Feld jetzt einen abweichenden Wert findet und der Nutzer es nie gesetzt hat; dann entsteht eine neue Revision, die alte bleibt. Für Felder, in denen keine Regel etwas findet, ändert sich nichts, und keine bestehende Revision wird verändert oder gelöscht.

**`TaskDetailView`:** Der Ergebnisfall `.finished(changed:)` zeigt die Zahl der Änderungen wie bisher; der Zweig „modelRan == false → Apple Intelligence did not run, only the rules.“ entfällt. Der Katalogschlüssel bleibt im Katalog stehen, bis Schnitt 3 oder 2 Strings aufräumt, soweit der Katalogwächter dies erlaubt; ist er nach dem Entfernen nirgends mehr benutzt und der Wächter meldet es, wird er hier mit entfernt.

**`ContentView`:** Der Modellgrund fürs Onboarding stammt nicht mehr aus `FoundationModelsEnricher`. Er ist `nil`, es sei denn, das Startargument `--ui-testing-model-reason=` ist gesetzt (nur unter UI-Tests). So laufen die vorhandenen `OnboardingTests` bis Schnitt 2 weiter; echte Nutzer sehen „Turn on Apple Intelligence …“ nie mehr.

**`LooseEndsApp`:** Der Koordinator wird mit dem neuen Init gebaut; `ModelOffEnricher` entfällt. Die Erfassung ruft `processPending` wie bisher (App-Fenster, Mac-Menüleiste, Teilschritte).

## Test Plan

### Automated Tests (TDD RED)

Unit-Tests in `LooseEndsTests/NoModelCoordinatorTests.swift` (XCTest), Lauf mit `./scripts/sim.sh sim-unit NoModelCoordinatorTests`. Die Kette läuft wie auf dem Gerät: `CaptureService.save` legt die Aufgabe an, `EnrichmentCoordinator(container:savedPlaces:)` reichert an. RED: die Klasse kompiliert vor der Umsetzung nicht (Init ohne `enricher` existiert nicht).

- [ ] Test 1: GIVEN eine mit „Vor Konzert“ gespeicherte Aufgabe WHEN `processPending` läuft THEN ist `title == "Vor Konzert"`, `duration` leer, es gibt keine Revision mit Autor `.ai`, `processedAt == nil` und `rulesAppliedAt != nil`.
- [ ] Test 2: GIVEN eine Aufgabe „Vor Konzert 20 Minuten“ WHEN `processPending` läuft THEN hat sie die Regeldauer (Eimer für 20 Minuten) mit Autor-Regel-Revision, keine `.ai`-Revision. GIVEN eine zweite Aufgabe mit demselben Rohtext wie eine frühere, vom Nutzer gesetzte WHEN `processPending` läuft THEN bekommt sie Dauer und Kontexte aus der Wiedererkennung.
- [ ] Test 3: GIVEN eine Aufgabe mit gesetztem `rulesAppliedAt` WHEN `processPending` erneut läuft THEN entstehen keine neue Revision und `rulesAppliedAt` bleibt unverändert.
- [ ] Test 4: GIVEN eine Aufgabe mit `processedAt` gesetzt, `rulesAppliedAt == nil` und „20 Minuten“ im Text (Stand von vor #144) WHEN `processPending` läuft THEN entsteht keine Dauer-Revision und `rulesAppliedAt` bleibt `nil`.
- [ ] Test 5: GIVEN eine Aufgabe mit einer alten KI-Dauer (Revision mit Autor `.ai`) und einem Rohtext ohne Dauerwort WHEN `reanalyze` läuft THEN ist das Ergebnis `.finished(changed:)`, die KI-Revision und der Wert stehen unverändert da. GIVEN dieselbe Aufgabe mit einem Dauerwort im Rohtext und ohne Nutzer-Revision für die Dauer THEN schreibt die Regel eine neue Revision mit abweichendem Wert, die alte KI-Revision bleibt erhalten. GIVEN eine Nutzer-Revision auf der Dauer THEN schreibt die Regel nichts.
- [ ] Test 6: GIVEN eine Aufgabe „Vor Konzert 20 Minuten“, deren Regelschritt schon lief, und deren Dauer vorher geleert wurde (ohne Nutzer-Revision) WHEN `reanalyze` läuft THEN ist das Ergebnis genau `.finished(changed: 1)` und die Aufgabe trägt eine neue Regel-Revision; ein zweites `reanalyze` liefert `.finished(changed: 0)`.
- [ ] Test 7: GIVEN `EnrichmentCoordinator(container:savedPlaces:)` THEN ist dies der einzige Init; der Test konstruiert ihn ohne `enricher` (Kompilierbeweis, dass kein Modell übergeben werden kann).
- [ ] Test 8: GIVEN der Wert für den Onboarding-Modellgrund wie in `ContentView` gebildet WHEN kein Argument `--ui-testing-model-reason=` gesetzt ist THEN ist er `nil`; WHEN das Argument gesetzt ist THEN trägt er dessen Wert. Die Bildung steht dafür in einer reinen Funktion, die der Test aufruft.
- [ ] Test 9: GIVEN eine Teilaufgabe (`parent != nil`) WHEN `processPending` und `reanalyze` laufen THEN bekommt sie nur die Teilschritt-Regeln (Fälligkeit, Kontextwort), `rulesAppliedAt` wird gesetzt, das Verhalten bleibt wie bisher.
- [ ] Test 10: GIVEN eine über den Erfassungsweg der Mac-Menüleiste gespeicherte Aufgabe (derselbe `CaptureService.save` plus `processPending` wie im Panel) THEN läuft der Regelschritt (`rulesAppliedAt != nil`).

Bestehende Tests: `ModelUnavailableTests` entfällt (der Fall gibt es nicht mehr); `ModelSeamTests`, `EnrichmentTests` und `ReanalysisTests` verlieren ihre Stub-Fälle oder werden zu Regeltests; alle anderen Konstruktionen werden mechanisch umgestellt.

UI-Test in `LooseEndsUITests/NoModelCaptureTests.swift`, Lauf mit `./scripts/sim.sh test-proof NoModelCaptureTests`. Er startet die App ohne `--ui-testing` (echte Verdrahtung, wie `CaptureCancelCrashTests`, mit `-onboardingDone YES`).

- [ ] Test 11: GIVEN die App ohne `--ui-testing` mit `-onboardingDone YES` WHEN in der Erfassung „Vor Konzert“ getippt und gesichert wird THEN steht die Aufgabe mit Titel „Vor Konzert“ in der Liste, zeigt in der Detailansicht keine Dauer und keine KI-Kennzeichnung („Estimated by Apple Intelligence“). WHEN dort „Analyze again“ angetippt wird THEN erscheint das Ergebnis („Nothing new found.“ o. ä.) und nirgends der Satz „Apple Intelligence did not run, only the rules.“.

## Acceptance Criteria

- **AC-1:** Nach Erfassung von „Vor Konzert“ und `processPending` hat die Aufgabe den Titel „Vor Konzert“, keine Dauer, keine Revision mit Autor `.ai`, `processedAt == nil` und `rulesAppliedAt != nil` (Test 1).
- **AC-2:** Eine genannte Dauer („Vor Konzert 20 Minuten“) setzt weiter die Regeldauer, und eine wiedererkannte Aufgabe bekommt weiter Dauer und Kontexte aus `RecognitionRule` (Test 2).
- **AC-3:** Eine Aufgabe mit gesetztem `rulesAppliedAt` wird von einem späteren `processPending` nicht angefasst: keine neue Revision, `rulesAppliedAt` unverändert (Test 3).
- **AC-4:** Eine Aufgabe mit `processedAt` gesetzt und `rulesAppliedAt == nil` (Stand von vor #144) bekommt mit „20 Minuten“ im Text von `processPending` keine Dauer-Revision (Test 4).
- **AC-5:** `reanalyze` läuft nur die Regeln und liefert `.finished(changed:)`; alte KI-Werte und KI-Revisionen bleiben unverändert, außer eine Regel findet für ein Feld, das der Nutzer nie gesetzt hat (keine Nutzer-Revision), einen abweichenden Wert; dann kommt eine neue Revision dazu, die alte bleibt (Tests 5 und 6).
- **AC-6:** Die Detailansicht zeigt nach „Neu analysieren“ nie „Apple Intelligence did not run, only the rules.“ (Test 11 tippt „Analyze again“ in der Detailansicht und prüft, dass der Satz nicht erscheint; Test 6 belegt das Ergebnis `.finished(changed:)`).
- **AC-7:** `EnrichmentCoordinator` hat keinen Weg mehr, ein Modell zu empfangen oder aufzurufen: nur `init(container:savedPlaces:)`, kein `enricher`, kein `callModel` (Test 7, Kompilierbeweis).
- **AC-8:** Das Onboarding der echten App (ohne UI-Test-Argument) zeigt keinen Apple-Intelligence-Hinweis; der Grund ist `nil`, außer `--ui-testing-model-reason=` ist gesetzt (Test 8).
- **AC-9:** Im Simulator, ohne `--ui-testing`, zeigt `NoModelCaptureTests` für die getippte Erfassung „Vor Konzert“: Titel „Vor Konzert“, keine Dauer, keine KI-Kennzeichnung (Test 11, Beleg über `./scripts/sim.sh test-proof NoModelCaptureTests`).
- **AC-10:** Teilaufgaben und die Mac-Menüleisten-Erfassung führen den Regelschritt weiter aus (`processPending` wird gerufen, Teilschritte unverändert) (Tests 9 und 10).

## Definition of Done

- [ ] Build grün (`./scripts/sim.sh generate`, dann `./scripts/sim.sh build`)
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh unit`), darunter `NoModelCoordinatorTests` und die umgestellten Bestandstests
- [ ] Alle UI-Tests grün, darunter `NoModelCaptureTests`; Simulatorbeleg registriert über `./scripts/sim.sh test-proof NoModelCaptureTests`, App ohne `--ui-testing` im Simulator durchgespielt
- [ ] Stufe 3 über TestFlight (`EnrichmentCoordinator.swift` steht auf der Geräte-Pfadliste; Ausnahme #680 greift nicht, weil der Modellaufruf selbst geändert wird): nach Merge und TestFlight-Bau bekommt Henning in einfachen Worten, was er probieren soll und was er sehen muss (Aufgabe erfassen, Titel bleibt wie gesprochen oder getippt, keine Dauer erfunden, „Neu analysieren“ ohne Hinweis zu Apple Intelligence); sein Wort schließt den Gerätepunkt. Nichts auf seinen Geräten vor seinem „jetzt ist ein Test möglich“
- [ ] Ausgeliefert: PR mit `Refs #982` (Issue bleibt für Schnitt 2 und 3 offen), CI grün, gemergt
- [ ] Abschlussbericht nennt die Abgrenzung: Status/„Neu“ bleibt #1000, Onboarding-Strings Schnitt 2, Aufräumen und CLAUDE.md Schnitt 3, Datenschutztext getrennt

## Changelog

- 2026-11-26: Initial spec created
