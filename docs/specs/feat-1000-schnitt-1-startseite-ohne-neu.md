---
entity_id: feat-1000-schnitt-1-startseite-ohne-neu
type: feature
created: 2026-11-26
updated: 2026-11-26
status: draft
workflow: feat-1000-neu-entfaellt
---

# Spec: Startseite und Inhalt ohne „Neu“, Schnitt 1 (Feature #1000, Epic #999)

## Approval

- [ ] Approved

## GitHub Issue

#1000 (Epic #999). Henning, 2026-11-26: „Die AI hat in der Summe keinen Mehrwert, sondern stört eher.“ Entscheidung: ADR-22 (`docs/project/00-entscheidungen.md:350`). Analyse und PO-Entscheidungen: `docs/context/feat-1000-neu-entfaellt.md`. Entwurf (freigegeben, „Entwurf A: Zeilen wie heute“): Vorschau https://claude.ai/artifact/3oGvFJxJ7Mob4WcfZDiam3, Quelle `docs/artifacts/feat-1000-neu-entfaellt/`. Dieser Schnitt ist der erste von drei; das Issue bleibt danach offen.

## Purpose

Eine erfasste Aufgabe steht sofort in ihrer Liste, und die Startseite führt nirgends mehr nach „Neu“. In der Schreibzeile verschwindet der Kopf „Neu · N zum Durchsehen“; die Zeilen dieser Sitzung und die Zeile selbst bleiben genau wie heute. Der Index („Inhalt“ auf dem iPhone, Seitenleiste auf iPad und Mac) listet „Neu“ nicht mehr. Die VoiceOver-Ansage nach Return nennt „Neu“ nicht mehr.

**Kernbefund (Analyse):** „Neu“ ist nur eine berechnete Ansicht. `TaskItem.isOpen` (`Shared/Models/TaskItem.swift:157-159`) umfasst `.unprocessed` und `.unverified`; jede Aufgabe in „Neu“ steht heute schon in „Lose Enden“ (`.open`) und, wenn sie für heute fällig ist, in „Jetzt“. Es braucht keine Migration und kein CloudKit-Schema; weg muss nur der Weg dorthin.

**Regeln vor Modell:** Kein Modell im Spiel; es wird Oberfläche entfernt.

## Nicht in diesem Schnitt (Folgeschnitte)

Folgeschnitte, ohne eigene Abnahmekriterien hier:

- Schnitt 2: die Liste „Neu“ selbst (nach diesem Schnitt nur noch über gespeicherte Ansichten und das Detail erreichbar), Wisch „Passt“, Menüeintrag „Passt“, Detail-Knopf „Passt“, `ReviewNote`, Abschnitt „Bitte ansehen“.
- Schnitt 3: Regeln (`ViewRules.isInNew`, `needsLook`, `canConfirm`, `reviewReason`, `case .new`), `ViewKind.new`, `TaskActions.confirmReview`, `RowKeyAction`, Tönung „noch nicht angesehen“ in `TaskRow` (PO: weg), übrige Katalogschlüssel („New“, „%lld to look over“, „Looks right“, „Needs a look“ …), Doku (`02-datenmodell-und-ansichten.md`, `03-design-briefing.md`, `funktionsuebersicht.md`, CLAUDE.md).
- Danach: TestFlight-Bau, der die offenen Gerätepunkte von #982 trägt (Session hält Epic #999).

Unverändert in diesem Schnitt: Status `unprocessed`/`unverified`, `hasUnseenAutomaticRevisions`, die Akzentfärbung in `TaskRow`, `InboxDrawer` (reine Logik), alle Regeln in `ViewRules` außer den zwei Listen unten, Server, Abschrift, Watch, Widgets, Mac-Menüleiste.

## Was darf sich nicht ändern

- **Schreibzeile und Schublade:** Zeilen dieser Sitzung (`drawerRow_…`), die Zeile `startCaptureField` mit Frage in Kursiv, Cursor bleibt nach Return, Einklappen beim Ende der Eingabe (Fokus weg, Auswahl wechselt, App nicht aktiv, Escape auf dem Mac) und die weiche Bewegung (0,4 s, keine Feder).
- **Schreibweg:** `CaptureService.save(…, via: .keyboard, …)` und der Fangpass der Regeln.
- **„Jetzt“-Zahl, Symbolzahl:** eine Quelle (`ViewRules.now`); „Neu“ hat sie nie verändert.
- **Daten:** keine Änderung an Aufgaben, Status, Revisionen.

## Alternativen

1. **Entwurf B: Quittung statt Zeilen unter der Schreibzeile.** Vom PO verworfen (2026-11-26); kippt die ruhige Startseite von #677 und den Entwurf der Schublade (#601).
2. **„Neu“ als reine Anzeige „Zuletzt erfasst“ behalten.** In ADR-22 verworfen: dieselbe Zusatzliste ohne Aufgabe.
3. **Status `unprocessed`/`unverified` per Startpass auf `active` heben.** Unnötig, da die Listen sie schon zeigen; kostet Revisionen und CloudKit-Schreiblast. Kippt keine ADR, bleibt als Rückfall für Schnitt 3, falls dort ein Fall auftaucht.

Gewählt: Entwurf A. Gekippt wird mit Schnitt 3 der Sichtungsteil von ADR-17 („Neu (Eingang)“).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-22
- **Rationale:** Bestehende Entscheidung (`docs/project/00-entscheidungen.md:350`, Epic #999): Das Modell verlässt den Produktweg, damit gibt es nichts Erfundenes zu sichten, und „Neu“ entfällt. Dieser Schnitt setzt das auf der Startseite und im Index um und braucht keine neue ADR.

## Source

- **File:** `LooseEnds/Views/InboxDrawerView.swift`
- **Identifier:** `InboxDrawerView.head`, `InboxDrawerView.count`, `InboxDrawerView.save`, `InboxDrawerView.glowHead`; `ViewRules.indexViews`, `ViewRules.dailyViews`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `InboxDrawer` (`Shared/Models/InboxDrawer.swift`) | module | `rows(in:)`, `didCapture`, `close`; unverändert |
| `ViewRules.tasks(for:in:)` | module | `case .new` bleibt bis Schnitt 3, wird von der Startseite nicht mehr gerufen |
| `SidebarView` (`LooseEnds/Views/SidebarView.swift:79`) | app | Liest `ViewRules.indexViews`; ändert sich dadurch, ohne eigene Änderung |
| `ViewRules.startViews` | module | Nutzt `dailyViews`; verliert dadurch `.new` (nur Tests rufen ihn, `StartViewsTests`) |
| `Localizable.xcstrings` | resource | Neuer Schlüssel „Captured: %@“; Quellsprache Englisch, Übersetzung de (`LanguagePacks.shipped` = en, de) |
| `scripts/test_catalog_languages.py` | test | Katalogwächter für Sprachen und Vollständigkeit |
| `LaunchLanguage` (`LooseEndsUITests/LaunchLanguage.swift`) | test | Phrase `lookOver` entfällt (:32) |
| CI-Job `ui-smoke-lang` | ci | Führt `InboxDrawerSmokeTests` und `StartNumberTests` je Sprache aus |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/InboxDrawerView.swift` | MODIFY | `head` (:72-113, Kennung `inboxBar`), `count` (:41), `headGlow` (:35), `glowHead` (:211-225) und dessen Aufruf in `endEntry` (:205) entfernt; `body` ohne `head(metrics)`; Ansage (:179) auf „Captured: %@“; Doc-Kommentar (:5-13) ohne „Neu“ neu geschrieben |
| `Shared/Models/ViewRules.swift` | MODIFY | `dailyViews` (:52) = `[.next, .due]`, `indexViews` (:64-67) beginnt mit `[.next, .due]`; Doc-Kommentare (:51, :62) angepasst; alles andere bleibt |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Schlüssel „Filed in New: %@“ (:14, nur hier benutzt) ersetzt durch „Captured: %@“ mit de „Aufgenommen: %@“; übrige „Neu“-Schlüssel bleiben bis Schnitt 3 |
| `LooseEndsTests/StartViewsTests.swift` | MODIFY | :9, :27, :135, :144, :156 ohne `.new`; :35 nimmt `.new` aus der Menge `lists` (Test 3) |
| `LooseEndsTests/InboxDrawerTests.swift` | MODIFY | :22, :37 prüfen nicht mehr die Zahl in „Neu“, sondern `drawer.rows(in:)` und `ViewRules.tasks(for: .open, in:)` |
| `scripts/test_catalog_languages.py` | MODIFY | Prüfung: „Captured: %@“ hat de; „Filed in New: %@“ ist weg |
| `LooseEndsUITests/InboxDrawerSmokeTests.swift` | MODIFY | Tests 6 bis 8 neu; bisherige Kopf-Prüfungen (:42, :52-54, :60, :68, :72-76) umgeschrieben |
| `LooseEndsUITests/LaunchLanguage.swift` | MODIFY | Phrase `lookOver` (:32) entfernt |
| `LooseEndsUITests/MacDetailClickTests.swift` | MODIFY | :325-355 prüft Abwesenheit des Kopfes, Zeile steht in „Lose Enden“ |
| `LooseEndsUITests/StartScreenInteractionTests.swift` | MODIFY | :189-204 (`testInboxBarAppearsOnlyWithNewAndOpensNew`) wird `testNoInboxBarAndCapturedTaskStandsInOpen`; :281 und :610-624 ohne Kopf bzw. ohne `viewRow_new`; :44, :75, :106, :397 auf `viewRow_open` |
| `LooseEndsUITests/CaptureSmokeTests.swift` | MODIFY | Helfer `captureIntoNew` (:943-962) öffnet „Lose Enden“ (`viewRow_open`); die 17 weiteren Stellen mit `viewRow_new` (:178 bis :907) ebenso |
| `LooseEndsUITests/MacUITestSupport.swift` | MODIFY | :78 Fensterfinder und :138 Standardwert `list: "viewRow_open"` |
| 13 weitere UI-Testdateien | MODIFY | Je ein bis drei Aufrufe von `viewRow_new` auf `viewRow_open`: `PlaceSmokeTests`, `DriveSmokeTests`, `ProjectSubtasksTests`, `MacGalleryTests`, `NoModelCaptureTests`, `MacStoreScreenshotsTests`, `CalendarTargetTests`, `FieldsSmokeTests`, `PaperGroundTests`, `StoreScreenshotsTests`, `DesignGalleryTests`, `ContextUniquenessTests`, `RecognitionWalkthroughTests` |

### Estimated Changes

- Dateien App: 3 (`InboxDrawerView.swift`, `ViewRules.swift`, `Localizable.xcstrings`), dazu Testdateien und ein Python-Wächter.
- LoC App-Code: +~6/−~65 (Kopf ca. 42 Zeilen, Glühen und Zustand ca. 20, Zahl 1, Ansage 1 geändert). Klar unter 250; Testcode zählt nicht mit.

## Implementation Details

**`InboxDrawerView`:** Der `VStack` in `body` zeigt die Zeilen und die Schreibzeile, nicht mehr `head(metrics)`. Mit dem Kopf entfallen `count`, `head`, `headGlow`, `glowHead` und der Aufruf `if hadRows && !reduceMotion { glowHead() }` in `endEntry`; die Zeilen klappen weiter nach oben weg (`rowTransition`, weiche 0,4 s), nur das Aufleuchten des Kopfsatzes entfällt, weil es keinen Kopf mehr gibt. Der Parameter `open` bleibt, die Zeilen brauchen ihn (`open(.task(task.id))`). Die Ansage nach Return: `String(localized: "Captured: \(item.displayTitle)")`; Katalogschlüssel exakt `Captured: %@`, en „Captured: %@“, de „Aufgenommen: %@“.

**`ViewRules`:** `dailyViews` ist `[.next, .due]`, `indexViews` liefert `[.next, .due]` plus die belegten gelegentlichen Ansichten. `startViews` erbt `dailyViews`. `isInNew`, `case .new` und `ViewKind.new` bleiben stehen (Schnitt 3); „Neu“ ist dadurch nur noch über eine gespeicherte Ansicht (`SavedView.kind`) und das Detail erreichbar, beides räumen Schnitt 2 und 3 auf.

**Index:** `SidebarView` ändert sich nicht; es zeigt „Lose Enden“ (`viewRow_open`) und „Fertig“ (`viewRow_done`) immer (:80), `viewRow_new` verschwindet.

**UI-Tests:** Jede Stelle, die eine frisch erfasste Aufgabe über `viewRow_new` öffnet, geht über `viewRow_open`; wer eine Aufgabe mit „heute“ erfasst, findet sie auch in „Jetzt“ (`nowRow_…`). Nach diesem Schnitt kommen `viewRow_new` und `inboxBar` in keinem UI-Test mehr vor, außer in einer Abwesenheitsprüfung.

## Test Plan

### Automated Tests (TDD RED)

Unit (Swift Testing, Lauf `./scripts/sim.sh sim-unit StartViewsTests` und `InboxDrawerTests`; Katalog: `python3 scripts/test_catalog_languages.py`). RED: `ViewRules.indexViews`/`dailyViews` enthalten heute `.new`, der Katalog hat den neuen Schlüssel nicht.

- [ ] Test 1: GIVEN keine Aufgabe WHEN `ViewRules.startViews(in: [])` und `ViewRules.indexViews(in: [])` THEN beide `[.next, .due]` und `!ViewRules.dailyViews.contains(.new)`.
- [ ] Test 2: GIVEN eine geparkte und eine wiederkehrende Aufgabe WHEN `startViews` und `indexViews` THEN `[.next, .due, .repeating, .parked]`, in beiden nirgends `.new`; mit einer kurzen Aufgabe zusätzlich `.quick` an seinem Platz.
- [ ] Test 3: GIVEN `ViewRules.dailyViews + occasionalViews` WHEN verglichen mit allen Ansichten außer `.done, .open, .context, .project, .new` THEN gleich (`.new` bis Schnitt 3 ausgenommen).
- [ ] Test 4: GIVEN zwei über `CaptureService.save` gespeicherte Aufgaben und ein `InboxDrawer` WHEN `didCapture` für beide THEN liefert `drawer.rows(in:)` beide, und `ViewRules.tasks(for: .open, in:)` enthält beide.
- [ ] Test 5: GIVEN der Katalog `Localizable.xcstrings` WHEN `scripts/test_catalog_languages.py` läuft THEN hat „Captured: %@“ die Übersetzung „Aufgenommen: %@“ (de), und „Filed in New: %@“ ist nicht mehr da.

UI-Tests (XCTest). Lauf `./scripts/sim.sh test-proof InboxDrawerSmokeTests` (iPhone); Mac: `MacDetailClickTests` im CI-Job „Mac Gallery (macOS)“.

- [ ] Test 6: GIVEN die Startseite im Simulator (`--ui-testing`) WHEN „Reifen wechseln am Freitag“ in `startCaptureField` getippt und Return gedrückt wird THEN steht `drawerRow_…` mit diesem Titel oberhalb von `startCaptureField` (Frame `minY` kleiner), es gibt kein Element `inboxBar` und keinen Text „zum Durchsehen“/„to look over“; die Zeile bleibt.
- [ ] Test 7: GIVEN derselbe Ablauf WHEN ein zweiter Satz folgt und danach auf `startHeader` getippt wird THEN falten die Zeilen weg, die Schreibzeile bleibt, und `inboxBar` existiert weiter nicht.
- [ ] Test 8: GIVEN die zwei erfassten Aufgaben WHEN `viewRow_open` getippt wird THEN steht „Reifen wechseln“ als `taskRow_…` in „Lose Enden“; GIVEN eine mit „heute“ erfasste Aufgabe THEN steht sie zusätzlich unter „Jetzt“ (`nowRow_…`).
- [ ] Test 9: GIVEN die Startseite WHEN der Index („Inhalt“) geöffnet wird THEN gibt es kein `viewRow_new`, aber `viewRow_open` und `viewRow_done`; auf iPad (Seitenleiste) und Mac ebenso (`StartScreenInteractionTests`, `MacGalleryTests`).
- [ ] Test 10: GIVEN die Mac-Startseite WHEN Return in der Zeile gedrückt wird THEN gibt es kein `inboxBar`, die Zeile steht im Drawer, der Cursor bleibt, Escape faltet (`MacDetailClickTests.testWritingLineOpensTheDrawerAndEscapeFoldsIt`, neu geschrieben).
- [ ] Test 11: GIVEN `ui-smoke-lang` in en und de WHEN `InboxDrawerSmokeTests` läuft THEN besteht er ohne die Phrase `lookOver`.
- [ ] Test 12: GIVEN alle bisherigen UI-Tests mit `viewRow_new` WHEN sie über `viewRow_open` laufen THEN bestehen sie in ihrer bisherigen Aussage.

## Acceptance Criteria

- **AC-1:** Nach Return in der Schreibzeile gibt es auf der Startseite kein Element `inboxBar` und keinen Text „zum Durchsehen“/„to look over“; die Zeile dieser Sitzung steht oberhalb der Schreibzeile (Tests 6, 7, 10; iPhone und Mac).
- **AC-2:** `ViewRules.dailyViews` und `ViewRules.indexViews(in:)` enthalten `.new` nicht; der Index („Inhalt“) und die Seitenleiste auf iPad und Mac führen „Neu“ nicht (Tests 1, 2, 3, 9).
- **AC-3:** Eine über die Schreibzeile erfasste Aufgabe steht sofort in „Lose Enden“ und, wenn sie „heute“ sagt, auch in „Jetzt“; der UI-Test öffnet sie von dort (Tests 4, 8).
- **AC-4:** Die Ansage nach Return lautet in en „Captured: %@“ und in de „Aufgenommen: %@“; der Katalog enthält „Filed in New: %@“ nicht mehr (Test 5).
- **AC-5:** Alle UI-Tests, die bisher über `viewRow_new` gingen, bestehen über den neuen Weg; kein UI-Test nennt `viewRow_new` oder `inboxBar` außer in einer Abwesenheitsprüfung (Tests 11, 12).
- **AC-6:** Simulatordurchlauf auf dem iPhone: ein Satz getippt, Return, die Aufgabe steht in ihrer Liste; Beleg über `./scripts/sim.sh test-proof InboxDrawerSmokeTests`, Screenshots der Startseite geöffnet und beschrieben (Tests 6 bis 8).

## Risiken

- **Breite der UI-Suite:** 16 UI-Testdateien mit rund 45 Stellen hängen an `viewRow_new` (`CaptureSmokeTests` allein 18). Mechanischer Umbau, aber ein verfehlter Rückweg (zurück in den Index, dann Liste öffnen) kippt einen Test erst in der CI. Gegenmaßnahme: erst die Helfer (`captureIntoNew`, `macOpenDetail`), dann die Einzelstellen; lokale Läufe der geänderten Klassen vor dem PR.
- **`ui-smoke-lang`:** `InboxDrawerSmokeTests` läuft je Sprache; die Phrase `lookOver` wird entfernt, damit kein Satz in einer Sprache stehen bleibt. Die Ansage wird nicht gelesen, nur der Katalog geprüft.
- **Tote Verweise bis Schnitt 3:** `ViewKind.new`, `isInNew` und die Liste „Neu“ bleiben über gespeicherte Ansichten erreichbar; kein Weg der Oberfläche führt mehr hin. Schnitt 2 und 3 räumen sie ab.
- **Mac-Fenstergröße und Zeilenhöhe:** Ohne Kopf rückt die Schreibzeile eine Zeile nach oben; `macAssertWindowFitsScreen` und die Galerie belegen es.

## Definition of Done

- [ ] Build grün (`./scripts/sim.sh generate`, dann `./scripts/sim.sh build`)
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh unit`), darunter `StartViewsTests`, `InboxDrawerTests`, Katalogwächter
- [ ] Alle UI-Tests grün (CI, auch `ui-smoke-lang` und „Mac Gallery (macOS)“); Simulatorbeleg über `./scripts/sim.sh test-proof InboxDrawerSmokeTests`
- [ ] Gerätestufe: Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2.
- [ ] Ausgeliefert: PR mit `Refs #1000` (Issue bleibt für Schnitt 2 und 3 offen), CI grün, gemergt
- [ ] Abschlussbericht nennt die Abgrenzung: Liste „Neu“, Gesten, Detail-Knopf „Passt“ Schnitt 2; Regeln, Tönung, Katalog, Doku Schnitt 3; danach TestFlight-Bau mit den Gerätepunkten von #982

## Changelog

- 2026-11-26: Initial spec created
