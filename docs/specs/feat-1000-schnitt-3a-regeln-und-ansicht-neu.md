---
entity_id: feat-1000-schnitt-3a-regeln-und-ansicht-neu
type: feature
created: 2026-11-27
updated: 2026-11-27
status: draft
workflow: feat-1000-s3-neu-aufraeumen
---

# Spec: Sichtungsregeln und Ansicht „Neu“ entfallen, Schnitt 3a (Feature #1000, Epic #999)

## Approval

- [ ] Approved

## GitHub Issue

#1000 (Epic #999). Henning, 2026-11-26: „Neu“ entfällt ganz; Entscheidung ADR-22 (`docs/project/00-entscheidungen.md`).
Schnitt 1 (Startseite ohne „Neu“, PR #1004) und Schnitt 2 („Passt“ weg, PR #1005) sind gemergt. Der im Schnitt-1-Spec
(`docs/specs/feat-1000-schnitt-1-startseite-ohne-neu.md:33`) geplante Schnitt 3 wird geteilt, weil er sieben Swift-Dateien
berührt (Kontext und Analyse: `docs/context/feat-1000-s3-neu-aufraeumen.md`):

- **Schnitt 3a (diese Spec):** Regeln, die Ansicht `ViewKind.new`, `TaskActions.confirmReview`, Tastaturregel, Leersatz.
- **Schnitt 3b (nächster Workflow):** Tönung „noch nicht angesehen“ in `TaskRow` (Entwurf A, PO: weg), `Paper.wideNoteInsets`,
  die unbenutzten Katalogschlüssel, Design-Briefing und Funktionsübersicht. Das Issue bleibt bis 3b offen.

## Purpose

Nach Schnitt 1 und 2 führt kein Weg der Oberfläche mehr zu „Neu“, aber der Code kennt die Ansicht und ihre Sichtungsregeln
noch. Dieser Schnitt entfernt sie, damit „Neu“ auch technisch nicht mehr existiert: keine Ansicht „Neu“, keine Regel, die
eine Aufgabe als „zu sichten“ einordnet, keine Aktion „Passt“. Für den Nutzer ändert sich nichts Sichtbares; eine erfasste
Aufgabe steht wie seit Schnitt 1 sofort in ihrer Liste.

## Was darf sich nicht ändern

- Alle übrigen Ansichten (`next`, `due`, `quick`, `old`, `waiting`, `repeating`, `parked`, `open`, `done`, `context`, `project`),
  ihre Regeln, Reihenfolgen, Titel und Symbole; Startseite, Index, Seitenleiste, „Jetzt“ und die Zahl am Symbol.
- Status-Werte `unprocessed`/`unverified` im Modell (CloudKit additiv), `TaskItem.hasUnseenAutomaticRevisions`,
  `RevisionService.markSeen` und die Änderungsliste im Detail.
- Tastaturregel des Mac für alle anderen Listen; Tönung in den Zeilen (bleibt bis 3b).
- Abschrift für Claude und Dienst (kennen „Neu“ nicht).

## Alternativen

1. **Ganzer Schnitt 3 in einem (7 Swift-Dateien) mit PO-Annahme der Überschreitung.** Spart einen Durchlauf, bricht die
   Dateigrenze 4–5; verworfen, weil die Teilung ohne Nachteil geht (3a löscht Code, 3b Darstellung und Katalog).
2. **`ViewKind.new` als verborgenen Altfall behalten.** Sinnvoll nur, wenn gespeicherte Ansichten existierten; `SavedView`
   wird in der App nirgends angelegt oder gelesen, und `SavedView.kind` dekodiert Unbekanntes zu `.next`. Toter Code; verworfen.
3. **Status `unprocessed`/`unverified` beim Start auf `active` heben.** Nicht nötig, die Listen zeigen solche Aufgaben seit
   Schnitt 1; kostet Revisionen und CloudKit-Schreiblast. Verworfen, kippt keine ADR.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-22
- **Rationale:** Bestehende Entscheidung (Epic #999): ohne Modell nichts zu sichten, „Neu“ entfällt. Dieser Schnitt setzt sie
  in Regeln und Ansichtsliste um und braucht keine neue ADR. Mit ihm fällt der Sichtungsteil von ADR-17 („Neu (Eingang)“)
  endgültig, ebenso die Ticket-Entscheidungen #188 (Sichtungsfach) und #318 („Passt“).

## Source

- **File:** `Shared/Models/ViewRules.swift`
- **Identifier:** `ViewRules.ReviewReason`, `ViewRules.needsLook`, `ViewRules.isInNew`, `ViewRules.canConfirm`,
  `ViewRules.reviewReason(of:)`, `ViewRules.tasks(for:in:)` (`case .new`); `ViewKind.new` (`Shared/Models/Enums.swift`);
  `TaskActions.confirmReview` (`Shared/Services/TaskActions.swift`); `RowKeyAction` (`.new?`, `Shared/Models/RowKeyAction.swift`);
  `TaskListView` Leersatz (`LooseEnds/Views/TaskListView.swift`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Shared/Models/ViewRules.swift` | MODIFY | `ReviewReason`, `needsLook`, `isInNew`, `canConfirm`, `reviewReason` und `case .new` in `tasks(for:)` entfallen; Doku-Kommentare über „Neu“ an `dailyViews` bleiben als Geschichte |
| `Shared/Models/Enums.swift` | MODIFY | `case new` aus `ViewKind`, samt Titel „New“ und Symbol `tray` |
| `Shared/Services/TaskActions.swift` | MODIFY | `confirmReview` entfällt (kein Aufrufer seit Schnitt 2) |
| `Shared/Models/RowKeyAction.swift` | MODIFY | `.new?` aus der Liste der Ansichten ohne Erledigen per Leertaste |
| `LooseEnds/Views/TaskListView.swift` | MODIFY | Leersatz `case .new: "Nothing to look over."` entfällt |
| `SavedView.kind` | module | unverändert; dekodiert ein altes `"new"` zu `.next` (keine Migration) |
| `LooseEndsTests/ReviewTrayTests.swift` | DELETE (Test) | prüft nur die entfallenden Regeln |
| `LooseEndsTests/ViewKindWithoutNewTests.swift` | CREATE (Test) | Tests 1–3 (RED) |
| `CaptureServiceTests`, `DetailBackTests`, `EnrichmentTests`, `PeopleRetiredTests`, `ProjectNameRuleTests`, `RevisionServiceTests`, `RowKeyActionTests`, `StartViewsTests`, `SubtaskListsTests`, `SubtaskTests` | MODIFY (Test) | `.new`/`isInNew`/`confirmReview` durch die Erwartung ersetzen, die bleibt (Liste „Lose Enden“ bzw. Status) oder streichen |
| `CLAUDE.md`, `docs/project/02-datenmodell-und-ansichten.md` | MODIFY (Doku) | Vermerke „bleiben bis S3“ und Zeile „Neu“ nachziehen |

## Scope

- **Affected Files:** die Zeilen mit MODIFY/CREATE/DELETE in der Tabelle unter „Dependencies“ (5 App-Dateien, 12 Testdateien, 2 Doku-Dateien).
- **Estimated Changes:** App-Code 5 Dateien, etwa −75 / +2 LoC; Tests 1 neu, 1 gelöscht, 10 angepasst, etwa +40 / −200 LoC.
- **Nicht in diesem Schnitt (3b):** `LooseEnds/Views/TaskRow.swift` (Tönung), `LooseEnds/Views/Paper.swift` (`wideNoteInsets`), `LooseEnds/Resources/Localizable.xcstrings` (Schlüssel), `docs/project/03-design-briefing.md`, `docs/reference/funktionsuebersicht.md`.

## Implementation Details

**`ViewRules`:** Der Block `ReviewReason` bis `reviewReason(of:)` (oben in der Datei) entfällt ganz; `tasks(for:in:)` verliert
`case .new`. Der `switch` über `ViewKind` bleibt erschöpfend, der Compiler meldet jede vergessene Stelle.

**`ViewKind`:** `case next, due, quick, old, waiting, repeating, parked, open, done, context, project`; `titleKey` und `symbol`
verlieren `.new`. Rohwerte der übrigen Fälle bleiben gleich, `Codable` unverändert.

**`TaskActions.confirmReview`:** entfällt samt Doku-Kommentar. `EnrichmentCoordinator`-Kommentare, die „Looks right“ als
Geschichte nennen, bleiben (kein Drive-by).

**`RowKeyAction`:** `case .done?, .parked?: false`.

**`TaskListView`:** Fall `.new` im Leersatz-`switch` entfällt.

Danach `./scripts/sim.sh generate` (eine Testdatei neu, eine gelöscht).

## Test Plan

### Automated Tests (TDD RED)

Swift Testing, `LooseEndsTests/ViewKindWithoutNewTests.swift`, Lauf `./scripts/sim.sh sim-unit ViewKindWithoutNewTests`.
RED, weil heute `ViewKind.new` existiert.

- [ ] Test 1: GIVEN `ViewKind.allCases` WHEN die Rohwerte gelesen werden THEN enthält keiner `"new"`, und es sind genau die
  elf Fälle `next, due, quick, old, waiting, repeating, parked, open, done, context, project`.
- [ ] Test 2: GIVEN eine `SavedView` mit `kindRaw = "new"` (Altbestand) WHEN `kind` gelesen wird THEN ist es `.next`, ohne Absturz.
- [ ] Test 3: GIVEN eine über `CaptureService` frisch erfasste Aufgabe (Status `unprocessed`, ohne Regelstufe) und eine mit
  ungesehener Regel-Revision WHEN `ViewRules.tasks(for: .open, in:)` und `ViewRules.now(in:)` berechnet werden THEN stehen beide
  in „Lose Enden“, und die Zahl über „Jetzt“ ist dieselbe wie mit Status `active` (keine Sichtung hält sie zurück).
- [ ] Test 4: GIVEN alle übrigen Unit- und UI-Tests WHEN sie laufen (`./scripts/sim.sh unit`, CI inkl. `ui-smoke-lang` und
  „Mac Gallery (macOS)“) THEN bestehen sie.

## Acceptance Criteria

- **AC-1:** `ViewKind` hat keinen Fall `new`; eine gespeicherte Ansicht mit Rohwert `"new"` liest sich als „Als nächstes“ (Tests 1, 2).
- **AC-2:** Im Code gibt es kein `isInNew`, `needsLook`, `canConfirm`, `reviewReason`, `ReviewReason` und `confirmReview` mehr;
  `grep -rnE "isInNew|needsLook|canConfirm|reviewReason|ReviewReason|confirmReview" Shared LooseEnds LooseEndsWatch LooseEndsWidgets LooseEndsTests`
  findet nichts (Codeprüfung in der Validierung).
- **AC-3:** Eine frisch erfasste Aufgabe steht ohne Zutun in „Lose Enden“ und zählt in „Jetzt“ wie eine aktive (Test 3).
- **AC-4:** Alle übrigen Unit- und UI-Tests bestehen (Test 4).
- **AC-5:** Simulatordurchlauf auf dem iPhone: Satz über die Schreibzeile erfasst, die Aufgabe steht sofort in der Liste, der
  Index zeigt keinen Eintrag „Neu“; Beleg über `./scripts/sim.sh test-proof InboxDrawerSmokeTests`, Screenshot geöffnet und beschrieben.

## Risiken

- **Unbenutzte Katalogschlüssel** „New“ und „Nothing to look over.“ kommen zu den fünf aus Schnitt 2 hinzu; alle werden in 3b
  entfernt. Verlangt der CI-Schritt „Generate leaves the tree clean“ einen Katalog-Diff, wird er hier mitgeliefert.
- **Gespeicherte Ansicht „Neu“:** existiert in keinem Store, weil die App keine anlegt; fiele doch eine an, zeigt sie „Als nächstes“.

## Definition of Done

- [ ] Build grün (`./scripts/sim.sh generate`, dann `./scripts/sim.sh build`)
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh unit`)
- [ ] Alle UI-Tests grün (CI, auch `ui-smoke-lang` und „Mac Gallery (macOS)“); Simulatorbeleg über `./scripts/sim.sh test-proof InboxDrawerSmokeTests`
- [ ] Gerätestufe: Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2.
- [ ] CLAUDE.md und `docs/project/02-datenmodell-und-ansichten.md` nachgezogen
- [ ] Ausgeliefert: PR mit `Refs #1000` (Issue bleibt für 3b offen), CI grün, gemergt
- [ ] Abschlussbericht nennt Schnitt 3b (Tönung, `wideNoteInsets`, Katalog, Design-Briefing, Funktionsübersicht) als nächsten Schritt

## Changelog

- 2026-11-27: Erstfassung (Teilung von Schnitt 3 in 3a/3b).
