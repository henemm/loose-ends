---
entity_id: feat-1000-schnitt-2-passt-entfaellt
type: feature
created: 2026-11-26
updated: 2026-11-26
status: draft
workflow: feat-1000-s2-passt-entfaellt
---

# Spec: Liste „Neu“, Wischen, Menü und Detail-Knopf „Passt“ entfallen, Schnitt 2 (Feature #1000, Epic #999)

## Approval

- [ ] Approved

## GitHub Issue

#1000 (Epic #999). Henning, 2026-11-26: „Die AI hat in der Summe keinen Mehrwert, sondern stört eher.“ Entscheidung: ADR-22 (`docs/project/00-entscheidungen.md:350`): kein „Neu“, kein „N zum Durchsehen“, kein „Passt“. Gesamtanalyse und PO-Entscheidungen (Entwurf A, Tönung weg): `docs/context/feat-1000-neu-entfaellt.md`; Kontext dieses Schnitts: `docs/context/feat-1000-s2-passt-entfaellt.md`. Schnitt 1 (Startseite, Index) ist gemergt (PR #1004). Dieser Schnitt ist der zweite von drei; das Issue bleibt danach offen.

## Purpose

Eine erfasste Aufgabe muss nirgends mehr „abgenickt“ werden. Nach Schnitt 1 zeigt das Detail einer frisch erfassten Aufgabe noch den Knopf „Passt“, weil sie bis zur Regelstufe als „noch nicht sortiert“ gilt. Dieser Schnitt entfernt die Sichtung aus Liste, Gesten und Detail: kein Knopf „Passt“ in der Leiste, kein Hinweis unter dem Titel, warum die Aufgabe wartet, kein Wisch und kein Menüeintrag „Passt“, kein Abschnitt „Bitte ansehen“ und keine Zeilennotizen „war: …“, „Titel nicht geprüft“, „Noch nicht sortiert“. Öffnen des Details markiert die Änderungen der Regeln als gesehen, wie heute schon außerhalb von „Neu“.

## Nicht in diesem Schnitt (Schnitt 3)

- Regeln `ViewRules.isInNew`, `needsLook`, `canConfirm`, `reviewReason`, `ReviewReason`, `case .new` in `ViewRules.tasks(for:in:)`, `ViewKind.new` (eine gespeicherte Ansicht fällt dann auf `.next` zurück).
- `TaskActions.confirmReview`, `RowKeyAction` (`.new` von der Leertaste ausgenommen), die Akzent-Tönung/Kursivschrift „ungesehen“ in `TaskRow` (PO: weg), Katalogschlüssel, die dadurch unbenutzt werden, Doku (02-datenmodell, 03-design-briefing, funktionsuebersicht, CLAUDE.md).
- Unit-Tests `ReviewTrayTests` und `EnrichmentTests` „confirmed with Looks right“ (prüfen Regeln und `TaskActions`, die bis S3 bleiben).

## Was darf sich nicht ändern

- Leiste des breiten Details (Erledigen, Als Nächstes, Verschieben, Parken, #831) und das „…“-Menü mit allen übrigen Einträgen in ihrer Reihenfolge (#667).
- Wische in „Erledigt“ (Wiederherstellen), „Geparkt“ (Aktivieren) und allen anderen Listen; Langdruck-Menü sonst unverändert.
- Listen „Lose Enden“, „Fällig“, „Jetzt“, „Erledigt“, Projekte, Kontexte: Abschnitte, Reihenfolge, Zeilennotizen (Unteraufgabe von …, Alter in „Alt“).
- Änderungsliste im Detail (`aiFields`, Titelzeile, „Zuletzt von Claude“), Felder und Editoren.
- Startseite und Schreibzeile aus Schnitt 1.

## Alternativen

1. **„Passt“ im Detail behalten, nur Liste und Gesten entfernen.** Widerspricht ADR-22 („kein ‚Passt‘“); verworfen.
2. **Statt Knopf den Status beim Öffnen auf `active` heben.** Schreibt Revisionen und CloudKit-Last, gehört zum Regel-Aufräumen in Schnitt 3; kippt keine ADR, bleibt dort als Rückfall.
3. **Schnitt 2 und 3 zusammen.** Sprengt 4–5 Dateien (Enums, ViewRules, RowKeyAction, TaskActions, Katalog, TaskRow dazu); verworfen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-22
- **Rationale:** Bestehende Entscheidung (`docs/project/00-entscheidungen.md:350`, Epic #999): ohne Modell gibt es nichts Erfundenes zu sichten, „Neu“ und „Passt“ entfallen. Dieser Schnitt setzt das in Liste, Gesten und Detail um und braucht keine neue ADR. Überholt werden die Ticket-Entscheidungen #188 (Sichtungsfach), #318 (Passt außerhalb „Neu“), #349 (Detail aus „Neu“) und #681 (Menü „Passt“).

## Source

- **File:** `LooseEnds/Views/TaskDetailView.swift`
- **Identifier:** `TaskDetailView.reviewing`, `TaskDetailView.inReview`, `TaskDetailView.toolbarActions`, `TaskDetailView.confirmReview()`; `TaskInteractions.leadingActions`, `TaskInteractions.menu`, `TaskInteractions.confirm`; `TaskListView.reviewSections`, `TaskListView.note(for:)`, `TaskListView.detail(_:reviewing:)`; `ReviewNote`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `RevisionService.markSeen` | module | Bleibt; das Detail ruft es beim Öffnen jetzt immer |
| `ViewRules.needsLook`, `isInNew`, `canConfirm`, `reviewReason` | module | Werden von den Views nicht mehr gerufen; bleiben bis Schnitt 3 (Unit-Tests) |
| `TaskActions.confirmReview` | module | Wird von den Views nicht mehr gerufen; bleibt bis Schnitt 3 |
| `ViewKind.new` | module | Bleibt bis Schnitt 3; eine gespeicherte Ansicht „Neu“ zeigt bis dahin eine schlichte Liste ohne Sichtungsabschnitte |
| `StoreScreenshotsTests` | test | Tippt heute „Passt“ bedingt an und prüft `reviewNote`; beide Zeilen entfallen |

## Scope

### Affected Files

| Datei | Change | Was |
|---|---|---|
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | `reviewing`, `inReview`, Abschnitt `ReviewNote`, beide Leistenknöpfe „Looks right“ (`detailConfirmButton`), `confirmReview()` weg; `onAppear` ruft `markSeen()` ohne Bedingung; Doc-Kommentar ohne „New“/„Looks right“ |
| `LooseEnds/Views/TaskInteractions.swift` | MODIFY | Wisch `case .new?` mit „Looks right“ (`swipeConfirm_…`), Menüeintrag „Looks right“ (`menuConfirm`), `confirm(_:)` weg; Doc-Kommentare angepasst |
| `LooseEnds/Views/TaskListView.swift` | MODIFY | Zweig `kind == .new` → `reviewSections` und `reviewSections` selbst, `.new`-Reihenfolge in der Tastaturwahl, `.new`-Zeilennotizen in `note(for:)`, Parameter `reviewing` in `detail` weg. Der Leersatz-Fall `.new` bleibt bis Schnitt 3 (der `switch` über `ViewKind` ist erschöpfend) |
| `LooseEnds/Views/ReviewNote.swift` | DELETE | ganze Datei |
| `LooseEndsUITests/StoreScreenshotsTests.swift` | MODIFY (Test) | bedingtes „Passt“ und `reviewNote`-Prüfung weg |
| `LooseEndsUITests/InboxDrawerSmokeTests.swift` | MODIFY (Test) | neuer Test (RED), siehe Test 1 |

### Estimated Changes

- App-Code: 4 Dateien, etwa −150 / +5 LoC.
- Tests: 2 Dateien, etwa +40 / −5 LoC.

## Implementation Details

**`TaskDetailView`:** Ohne `reviewing` gibt es kein `inReview`. Im `toolbarActions` entfällt der ganze erste `if !deleted, task.isOpen { … }`-Block mit beiden Zweigen; die Leiste des breiten Details (`showsBarActions`) und das „…“-Menü bleiben unverändert. `.onAppear` setzt `titleDraft` und ruft `markSeen()`. Der Abschnitt nach `driveSection` mit `ReviewNote` entfällt samt Tönung.

**`TaskInteractions`:** `leadingActions` verliert `case .new?`; ein Aufruf mit `kind == .new` fällt in `default` (Erledigen, wie in jeder anderen offenen Liste). `menu` verliert den Eintrag „Looks right“ vor „Erledigen“. `confirm(_:)` entfällt, es gibt keinen Aufrufer mehr.

**`TaskListView`:** Der `List`-Inhalt verliert den Zweig `kind == .new`; eine (nur noch gespeicherte) Ansicht „Neu“ fällt in den bestehenden Standardzweig. Die Reihenfolge der Tastaturwahl verliert den Sonderfall `.new`. `note(for:)` verliert den Block `if kind == .new`. `detail(_:)` ruft `TaskDetailView(task:)`.

Nach dem Löschen von `ReviewNote.swift`: `./scripts/sim.sh generate`, damit Xcode die Datei nicht mehr sucht.

## Test Plan

### Automated Tests (TDD RED)

UI-Test (XCTest), Lauf `./scripts/sim.sh test-proof InboxDrawerSmokeTests` (iPhone). RED: Eine frisch erfasste Aufgabe ist bis zur Regelstufe `unprocessed` mit Titel, das Detail zeigt deshalb heute `detailConfirmButton`.

- [ ] Test 1: GIVEN die Startseite im Simulator (`--ui-testing`) WHEN ein Satz in `startCaptureField` getippt, Return gedrückt und die Zeile `drawerRow_…` dieser Sitzung geöffnet wird THEN zeigt das Detail den Titel, es gibt kein Element `detailConfirmButton`, kein `reviewNote` und keinen Knopf mit der Aufschrift „Passt“/„Looks right“; nach „…“ (`detailMoreMenu`) ebenfalls kein `menuConfirm` und kein „Passt“/„Looks right“, aber „Erledigen“/„Complete“ (`menuDone`).
- [ ] Test 2: GIVEN `StoreScreenshotsTests` (lokal `./scripts/sim.sh test StoreScreenshotsTests`, CI) WHEN die Detailstrecke läuft THEN besteht sie ohne „Passt“-Schritt; Tag und Dauer stehen wie bisher.
- [ ] Test 3: GIVEN alle bisherigen Unit- und UI-Tests WHEN sie laufen (`./scripts/sim.sh unit`, CI inkl. `ui-smoke-lang` und „Mac Gallery (macOS)“) THEN bestehen sie unverändert.

## Acceptance Criteria

- **AC-1:** Das Detail einer frisch über die Schreibzeile erfassten Aufgabe zeigt keinen Knopf „Passt“ (`detailConfirmButton`) und keinen Hinweis `reviewNote`; das „…“-Menü hat keinen Eintrag „Passt“ und weiterhin „Erledigen“ (Test 1).
- **AC-2:** Im App-Code gibt es keinen Wisch und keinen Menüeintrag „Looks right“, keine Datei `ReviewNote.swift`, keinen Parameter `reviewing` und keinen Abschnitt „Needs a look“; `grep -rn "Looks right\|ReviewNote\|reviewing\|Needs a look" LooseEnds/` findet nichts außer im Katalog (Codeprüfung in der Validierung).
- **AC-3:** Öffnen des Details markiert die Änderungen der Regeln immer als gesehen (`markSeen()` ohne Bedingung in `onAppear`, Codeprüfung).
- **AC-4:** Alle übrigen Unit- und UI-Tests bestehen, `StoreScreenshotsTests` ohne „Passt“-Schritt (Tests 2, 3).
- **AC-5:** Simulatordurchlauf auf dem iPhone: Satz getippt, Return, Detail geöffnet, kein „Passt“; Beleg über `./scripts/sim.sh test-proof InboxDrawerSmokeTests`, Screenshot des Details geöffnet und beschrieben (Test 1).

## Risiken

- **Verhaltensänderung beim Öffnen:** Das Detail markiert jetzt immer gesehen (vorher nicht aus „Neu“). Ohne „Neu“ ist das der einzige Weg; die Tönung entfällt ohnehin in Schnitt 3.
- **Gespeicherte Ansicht „Neu“:** zeigt bis Schnitt 3 eine schlichte Liste; Erledigen per Wisch statt „Passt“. Bewusst, Schnitt 3 entfernt `ViewKind.new`.
- **Unbenutzte Katalogschlüssel** („Looks right“, „Needs a look“, „was: %@“, „Title not checked“, „Not sorted yet“): Xcode kann sie beim Bauen als veraltet markieren; der Katalogwächter prüft Vollständigkeit, nicht Verwendung. Aufräumen in Schnitt 3; ein Diff im Katalog nach dem Bauen wird in diesem Schnitt nicht mitgeliefert, außer der CI-Schritt „Generate leaves the tree clean“ verlangt es.

## Definition of Done

- [ ] Build grün (`./scripts/sim.sh generate`, dann `./scripts/sim.sh build`)
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh unit`)
- [ ] Alle UI-Tests grün (CI, auch `ui-smoke-lang` und „Mac Gallery (macOS)“); Simulatorbeleg über `./scripts/sim.sh test-proof InboxDrawerSmokeTests`
- [ ] Gerätestufe: Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2.
- [ ] Ausgeliefert: PR mit `Refs #1000` (Issue bleibt für Schnitt 3 offen), CI grün, gemergt
- [ ] Abschlussbericht nennt die Abgrenzung: Regeln, `ViewKind.new`, Tönung, Katalog, Doku in Schnitt 3; danach TestFlight-Bau mit den Gerätepunkten von #982

## Changelog

- 2026-11-26: Initial spec created
