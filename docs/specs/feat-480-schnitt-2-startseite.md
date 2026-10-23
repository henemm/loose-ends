---
entity_id: feat-480-schnitt-2-startseite
type: feature
created: 2026-10-22
updated: 2026-10-22
status: draft
workflow: feat-480-s2-startseite-tasten
---

# Spec: #480 Schnitt 2 — Tastatur und Zeiger in den „Jetzt“-Zeilen der Mac-Startseite, Mindestgröße des Fensters

## Approval

- [ ] Approved (Henning)

Teil von Epic #467, Entwurf #408 (Tafel `docs/artifacts/feat-408-mac-entwurf/Grundlagen.dc.html`, Abschnitt „Zeiger und Tastatur“,
`docs/project/03-design-briefing.md:258-267`, freigegeben; kein neuer Entwurf nötig). Analyse: `docs/context/feat-480-s2-startseite-tasten.md`.
Vorbild für Aufbau, Technik und Belege: Schnitt 1, `docs/specs/feat-480-schnitt-1-liste.md` (PR #600).

**Schnitt.** Schnitt 1 hat Taste → Aktion (`RowKeyAction`), die Zeilenauswahl und die Akzentmarkierung in die Listen
(`TaskListView`) gebracht. Dieser Schnitt 2 überträgt das auf die „Jetzt“-Zeilen der Startseite und setzt die Mindestgröße
760 × 520 pt für das Hauptfenster. Er schließt das Ticket: der PR trägt `Closes #480`.

## Purpose

Auf der Mac-Startseite lässt sich eine „Jetzt“-Zeile mit den Pfeiltasten wählen. Die gewählte Zeile steht in Akzent 12 %, Hover in
Grau 7 %. Die Leertaste erledigt sie (mit Rückgängig-Fenster, #32), ⌫ löscht sie nach Rückfrage. Beides wirkt nur, solange die
Schreibzeile „Neu“ nicht den Fokus hat. ⌘N setzt den Cursor weiter in die Schreibzeile (#472). Das Hauptfenster lässt sich nicht
kleiner als 760 × 520 pt ziehen.

**Rein regelbasiert.** Tastaturlogik ist deterministisch; kein Modell, kein Prompt, kein Schema. „Without the model this fails
because …“ entfällt, weil kein Feld abgeleitet wird. Die Zuordnung Taste → Aktion bleibt `RowKeyAction.resolve` aus Schnitt 1
(unverändert, unit-getestet in `RowKeyActionTests`).

**Entscheidungen aus Schnitt 1 gelten:** Pfeiltasten wählen, ein Klick öffnet die Aufgabe wie bisher und markiert die Zeile; kein
`List(selection:)`.

## Source

- **Geändert:** `LooseEnds/Views/StartPage.swift` (Tasten, Auswahl, Optik der „Jetzt“-Zeilen)
- **Geändert:** `LooseEnds/Views/TaskListView.swift` (`ChosenRows` nicht mehr `private`, neue Eigenschaft `start`)
- **Geändert:** `LooseEnds/Views/StartZones.swift` (`NowBlock`: Aufklappzustand von außen steuerbar)
- **Geändert:** `LooseEnds/Views/InboxDrawerView.swift` (meldet den Fokus der Schreibzeile nach außen)
- **Geändert:** `LooseEnds/App/LooseEndsApp.swift` (Mindestgröße, nur macOS)
- **Geändert:** `LooseEndsUITests/MacKeyboardTests.swift` (neue Mac-UI-Tests für die Startseite)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Views/StartPage.swift` | MODIFY | Nur `#if os(macOS)`: Listenkörper `.focusable` mit `onKeyPress` (nackte Tasten ↑ ↓ Leertaste ⌫) wie `TaskListView.keyed/handle`, `onMoveCommand`/`onDeleteCommand` als Rückfall, `scrollTo` der gewählten Zeile, Auswahl verwerfen, wenn die Zeile geht. `rowIDs` = sichtbare „Jetzt“-Zeilen in Anzeigereihenfolge. `spaceCompletes(in: .next, …)`. `nowRow` und der Rückgängig-Zustand (`pendingRow`) nutzen `wideListRow(selected:)` statt eigenem padding/startMetrics/startRow. Der Klick im Button setzt zusätzlich die Auswahl. **Kein** Listenfokus beim Erscheinen |
| `LooseEnds/Views/TaskListView.swift` | MODIFY | `ChosenRows` wird intern statt `private` und bekommt `start: UUID?` (der Schlüssel `ViewSelection` ist nicht optional; die Startseite wird beim Zurück aus dem Detail neu gebaut). 2 bis 5 Zeilen, Verhalten der Listen unverändert |
| `LooseEnds/Views/StartZones.swift` | MODIFY | `NowBlock`: `expanded` als `Binding` mit Standardwert für den bestehenden Aufruf in `SidebarView`; sichtbare Zeilen = `expanded ? all : prefix(5)` |
| `LooseEnds/Views/InboxDrawerView.swift` | MODIFY | Callback `onWritingFocus(Bool)` aus `onChange(of: writing)` (ein `@FocusState` lässt sich nicht als Binding reichen); Verhalten der Schreibzeile und ⌘N (#472) unverändert |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | macOS: `.frame(minWidth: 760, minHeight: 520)` am `ContentView`, `.windowResizability(.contentMinSize)` an der Szene (ausdrücklich, nicht vom Standard abhängig) |
| `LooseEndsUITests/MacKeyboardTests.swift` | MODIFY | Neue Tests für die Startseite und die Mindestgröße (siehe Test Plan) |

### Estimated Changes

- Dateien: 6 (5 Produkt, 1 Test); zwei davon (`TaskListView`, `LooseEndsApp`) nur 2 bis 5 Zeilen. Kein neues File, keine
  neue Unit-Test-Datei (die reine Zuordnung bleibt unverändert und ist in Schnitt 1 abgedeckt).
- Dateigrenze: 6 statt 4–5, bewusst. Die Mindestgröße (`LooseEndsApp`, 2 Zeilen) gehört laut Ticket in denselben Schnitt, und
  `ChosenRows` (`TaskListView`, 2 bis 5 Zeilen) zu öffnen ist kleiner als ein eigener zweiter Speicher. Ein eigener Schnitt nur für
  die Mindestgröße bräuchte einen eigenen Workflow und PR für 2 Zeilen Produktcode; die LoC-Grenze bleibt eingehalten.
- LoC: Produkt ca. +100/−10, Tests ca. +100, zusammen ca. 210, unter 250. Überschreitet die Umsetzung 250, wird gestoppt und mit
  Schätzung nachgefragt.

Geräteliste: **Kein Pfad der Geräteliste berührt.** `LooseEnds/Views`, `LooseEnds/App/LooseEndsApp.swift` und Tests; weder
`Shared/Persistence` noch `project.yml`, Entitlements oder Info.plist (`project.yml` bleibt unverändert). Keine Berechtigung, kein
AppStorage-Schlüssel, kein Modellfeld, kein CloudKit-Schema.

## Implementation Details

**Wählbare Zeilen.** `rowIDs` sind die sichtbaren „Jetzt“-Zeilen in Anzeigereihenfolge: `ViewRules.now(in: tasks).all`, bei
zugeklapptem Block nur die ersten 5 (`NowBlock.limit`), nach „Mehr“ alle. Der Aufklappzustand liegt dafür in `StartPage`
(Binding an `NowBlock`), damit Auswahl und Anzeige dieselbe Liste sehen. Die Schublade „Neu“ und die rechte Spalte gehören nicht
dazu.

**Fokus.** Die Startseite setzt den Listenfokus **nicht** beim Erscheinen (anders als `TaskListView`), sonst streitet sie mit der
Schreibzeile und ⌘N (#472). Der Listenfokus entsteht durch Klick auf eine Zeile oder wenn die Schreibzeile ihn abgibt.
`textFocused` ist der gemeldete Fokus der Schreibzeile (`onWritingFocus`). Ob `onKeyPress` an einer `List` Tasten erhält, solange
ein `TextField` in derselben Liste fokussiert ist, ist auf macOS nicht dokumentiert (Apple-Forum 779117, ohne Antwort). Deshalb
verlässt sich die Spec nicht auf einen Vorrang, sondern übergibt `textFocused` ausdrücklich an `RowKeyAction.resolve`
(`.ignore` bei Textfokus); Leertaste und Rücktaste bleiben im Feld.

**Auswahl.** Eigener Zustand in `ChosenRows.shared.start`, damit er das Neubauen der Startseite beim Zurück aus dem Detail
übersteht (wie in Schnitt 1, #544). Ein Klick auf eine Zeile öffnet das Detail wie bisher und setzt die Auswahl im Button selbst
(das Detail der Startseite hat kein `onAppear` wie in `TaskListView`). Verschwindet die gewählte Zeile aus `rowIDs` (erledigt,
verschoben, gelöscht), gilt die Auswahl als leer; es springt nichts weiter.

**Ausführung.** Keine neue Erledigen- oder Löschlogik: Leertaste ruft `actions.complete(task)` (Rückgängig-Fenster
`PendingCompletions`, #32), eine Zeile mit `actions.isPending` ignoriert sie (nie doppelt). ⌫ setzt `pendingDelete` und
`confirmingDelete` und löst den vorhandenen `confirmationDialog("Delete this task?")` aus (`taskInteractionDialogs`, in
`StartPage` schon verdrahtet); gelöscht wird erst nach „Delete“.

**Optik.** `wideListRow(selected:)` (Schnitt 1) an `nowRow` und am Rückgängig-Zustand: Auswahl `Color.accentColor.opacity(0.12)`,
Hover `Color.primary.opacity(0.07)`, Akzent gewinnt. iPad breit sieht unverändert aus: dieselben 11 pt vertikal und dieselben
Zeilenränder wie bisher; Hover und Auswahl nur auf dem Mac. Die Zeilen-IDs `startNowRow_<id>` bleiben, damit `MacGalleryTests`
und `MacDetailClickTests` unverändert laufen.

**Mindestgröße.** Der Fensterinhalt bekommt auf macOS `minWidth: 760, minHeight: 520`; die Szene setzt
`.windowResizability(.contentMinSize)`. Mit Seitenleiste (220 pt) bleiben 540 pt Inhalt; das Detail hat `minWidth 480`. Unter
900 pt Breite fällt die rechte Spalte der Startseite schon heute weg (`ViewThatFits`), das bleibt so.

**Plattform.** Alle neuen Zweige hinter `#if os(macOS)`; iPhone und iPad bleiben unverändert.

### Alternativen

- **Gewählt: begrenzte Übernahme.** Die Tastenlogik aus `TaskListView.keyed/handle` wird in `StartPage` nachgebaut (ca. 40 Zeilen
  Doppelung), die Schnitt-1-Logik bleibt unangetastet. Begründung: Schnitt 1 ist eben abgenommen, ein Umbau würde alle Mac-Listen
  einem Regressionsrisiko aussetzen, und das Ticket bleibt in den Limits.
- **Verworfen: gemeinsamer macOS-`ViewModifier`** (`RowKeyboard` mit Auswahl-Binding, `rowIDs`, `textFocused`, `completes`,
  `onComplete`, `onDelete`), von beiden Listen benutzt. Vorteil: keine Doppelung. Nachteil: baut die abgenommene Schnitt-1-Logik
  um (Regression in allen Mac-Listen) und sprengt mit neuer Datei plus Umbau die 250-LoC-Grenze. Lohnt sich, sobald eine dritte
  Liste Tasten bekommt; kippt keine ADR.
- **Verworfen: Listenfokus beim Erscheinen wie in `TaskListView`.** Würde der Schreibzeile und ⌘N (#472) den Fokus nehmen; auf der
  Startseite hat das Schreiben Vorrang.
- **Verworfen: `List(selection:)`.** Siehe Schnitt 1; würde das Klickverhalten (#544) kippen.

## Test Plan

### Automated Tests (TDD RED)

Alle neuen UI-Tests liegen in `LooseEndsUITests/MacKeyboardTests.swift`, mit den Hilfen aus `MacUITestSupport.swift` (Präfix `mac`),
und laufen im CI-Job „Mac Gallery (macOS)“ in der Sandbox der echten App. Sie sind vor der Umsetzung rot, weil die Startseite weder
Auswahl noch Tastenbehandlung noch Mindestgröße hat.

- [ ] `testStartArrowsSelectAndSpaceCompletes`: GIVEN die Startseite mit vier „Jetzt“-Aufgaben WHEN ein Klick auf die erste Zeile
  öffnet und markiert, zurück zur Startseite, ↓ ↓ ↑ THEN ist die zweite Zeile gewählt; Leertaste: sie erscheint im
  Rückgängig-Fenster („Undo“), eine zweite Leertaste plant nichts doppelt ein, nach Ablauf ist genau diese erledigt, die anderen
  bleiben offen.
- [ ] `testStartMoreExtendsRows`: GIVEN sieben „Jetzt“-Aufgaben, Block zugeklappt WHEN ↓ siebenmal THEN bleibt die Auswahl auf Zeile 5
  stehen; nach „Mehr“ erreicht ↓ Zeile 6 und 7.
- [ ] `testStartDeleteAsksFirst`: GIVEN eine gewählte „Jetzt“-Zeile WHEN ⌫ THEN erscheint „Delete this task?“; Abbrechen lässt die
  Aufgabe stehen; ⌫ und „Delete“ löscht genau diese.
- [ ] `testStartWritingLineKeepsKeys`: GIVEN eine gewählte Zeile und Fokus in der Schreibzeile WHEN Leertaste und ⌫ THEN steht ein
  Leerzeichen im Feld bzw. wird ein Zeichen gelöscht, alle Aufgaben bleiben offen und vorhanden; Pfeile bewegen keine Auswahl.
- [ ] `testStartNewTaskShortcutFocusesWritingLine`: GIVEN eine gewählte „Jetzt“-Zeile und Listenfokus WHEN ⌘N THEN steht der Cursor in
  der Schreibzeile und die nächste Eingabe landet dort (#472); `StartScreenInteractionTests` bleiben grün.
- [ ] `testStartHasNoListFocusOnAppear`: GIVEN frischer Start der Startseite WHEN direkt getippt wird THEN landet die Eingabe nicht in
  einer Listenaktion: Leertaste erledigt nichts, keine Zeile ist gewählt.
- [ ] `testStartSelectionSurvivesDetail`: GIVEN eine gewählte Zeile WHEN ein Klick das Detail einer Aufgabe öffnet und der Weg zurück führt THEN ist dieselbe
  Zeile weiter gewählt.
- [ ] `testStartSelectionClearsWhenRowGoes`: GIVEN eine gewählte Zeile WHEN sie erledigt wird (Frist abgelaufen) THEN ist keine Zeile
  gewählt, und Leertaste wirkt nicht auf eine andere Zeile.
- [ ] `testWindowMinimumSize`: GIVEN das Hauptfenster WHEN die Fensterecke weit nach innen gezogen wird THEN misst das Fenster danach
  mindestens 760 × 520 pt (im Test aus dem Frame des Fensters gelesen).
- [ ] `testStartSelectionPhotoLight` / `testStartSelectionPhotoDark`: Fotos `mac-keyboard-start-selection-light/-dark` mit gewählter
  „Jetzt“-Zeile und einer Zeile unter dem Zeiger, als Anhang des Testlaufs.

Bestehend, grün zu halten: die sieben Tests aus Schnitt 1 in `MacKeyboardTests`, `RowKeyActionTests`, `MacDetailClickTests`,
`MacGalleryTests`, `StartScreenInteractionTests` (⌘N, #472), alle iOS-UI-Tests, die über `startNowRow_` laufen; iOS-UI-Smoke als
Gegenprobe für die geteilte `StartPage`; voller Unit-Lauf `./scripts/sim.sh sim-unit` (nie `unit` auf dem Mac).

Simulator (Stufe 2): iPhone und iPad breit, Startseite bzw. „Jetzt“-Liste, Wischen, Erledigen, Löschen, vorher (`main`) und nachher,
Bilder geöffnet und beschrieben (unverändert). Mac: nur Bilder und Läufe aus der CI, nie von Hennings Mac.

## Acceptance Criteria

- **AC-1:** Auf der Mac-Startseite wählen ↓ und ↑ die nächste bzw. vorige sichtbare „Jetzt“-Zeile; an den Rändern bleibt die Auswahl.
  Beleg: `MacKeyboardTests.testStartArrowsSelectAndSpaceCompletes` grün.
- **AC-2:** Bei zugeklapptem „Jetzt“-Block sind nur die ersten 5 Zeilen wählbar; nach „Mehr“ alle. Schublade „Neu“ und rechte Spalte
  sind nicht wählbar. Beleg: `testStartMoreExtendsRows` grün.
- **AC-3:** Die Leertaste erledigt die gewählte Zeile über das Rückgängig-Fenster (#32); eine Zeile im Rückgängig-Fenster wird nie ein
  zweites Mal eingeplant. Beleg: `testStartArrowsSelectAndSpaceCompletes` grün; Diff ruft nur `TaskInteractions.complete(_:)` und
  prüft `isPending`.
- **AC-4:** ⌫ löscht die gewählte Zeile erst nach der Rückfrage „Delete this task?“; Abbrechen löscht nichts. Beleg:
  `testStartDeleteAsksFirst` grün; Diff nutzt nur `pendingDelete`/`confirmingDelete`, keine neue Löschlogik.
- **AC-5:** Solange die Schreibzeile Fokus hat, wirken Pfeile, Leertaste und ⌫ nicht auf Aufgaben; Leertaste und ⌫ bleiben im Feld.
  Beleg: `testStartWritingLineKeepsKeys` grün; Diff übergibt `textFocused` aus dem gemeldeten Fokus der Schreibzeile.
- **AC-6:** ⌘N setzt den Cursor weiter in die Schreibzeile, auch bei gewählter Zeile und Listenfokus (#472 bleibt grün). Beleg:
  `testStartNewTaskShortcutFocusesWritingLine` und `StartScreenInteractionTests` grün.
- **AC-7:** Beim Erscheinen der Startseite hat die Liste keinen Fokus und keine Zeile ist gewählt. Beleg:
  `testStartHasNoListFocusOnAppear` grün; Diff setzt auf der Startseite kein `listFocused = true` beim Erscheinen.
- **AC-8:** Ein Klick öffnet die Aufgabe wie bisher und markiert die Zeile; die Auswahl überlebt Detail und Zurück (Speicher in
  `ChosenRows.shared.start`). Beleg: `testStartSelectionSurvivesDetail` sowie `MacDetailClickTests` und
  `StartScreenInteractionTests` grün; kein `List(selection:)`.
- **AC-9:** Verschwindet die gewählte Zeile (erledigt, verschoben, gelöscht), ist keine Zeile gewählt; nichts springt weiter. Beleg:
  `testStartSelectionClearsWhenRowGoes` grün.
- **AC-10:** Die gewählte „Jetzt“-Zeile steht in Akzent 12 %, Hover in Grau 7 %, bei beidem gewinnt Akzent, dargestellt über
  `wideListRow(selected:)` (auch im Rückgängig-Zustand). Beleg: Fotos `mac-keyboard-start-selection-light` und `-dark` aus dem
  CI-Lauf, geöffnet und beschrieben; Diff nutzt `wideListRow(selected:)` und keine eigenen Farben.
- **AC-11:** iPad breit und iPhone sehen unverändert aus (gleiche 11 pt vertikal, gleiche Zeilenränder, kein Hover, keine Auswahl);
  alle neuen Zweige hängen hinter `#if os(macOS)`. Beleg: Diff; iOS-UI-Smoke und voller Unit-Lauf grün; iPad-Bild vorher/nachher gleich.
- **AC-12:** Die bestehenden Zeilen-IDs `startNowRow_<id>` bleiben unverändert. Beleg: `MacGalleryTests` und `MacDetailClickTests`
  grün ohne Änderung; Diff berührt die IDs nicht.
- **AC-13:** Das Hauptfenster der Mac-App lässt sich nicht kleiner als 760 × 520 pt ziehen. Beleg: `testWindowMinimumSize` grün; Diff
  zeigt `.frame(minWidth: 760, minHeight: 520)` und `.windowResizability(.contentMinSize)` hinter `#if os(macOS)`.
- **AC-14:** Kein neuer AppStorage-Schlüssel, kein Modell-, Schema- oder Rechte-Eingriff, keine neue Abhängigkeit; `project.yml`
  unverändert. Beleg: Diff.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `RowKeyAction` | module | Zuordnung Taste → Aktion; unverändert aus Schnitt 1 |
| `TaskInteractions` (`complete`, `isPending`, `pendingRow`, `pendingDelete`, `confirmingDelete`) | module | Erledigen und Löschen; unverändert |
| `ViewRules.now(in:)`, `NowBlock` | module | Quelle und Anzeige der „Jetzt“-Zeilen |
| `Paper.wideListRow(selected:)` | module | Hover und Auswahlfarbe aus Schnitt 1 |
| `ChosenRows` (`TaskListView.swift`) | module | Auswahl über Neubau hinweg, neue Eigenschaft `start` |
| `InboxDrawerView` | module | Schreibzeile in derselben `List`, ⌘N (#472) |
| `MacUITestSupport`, `MacDetailClickTests`, `MacGalleryTests`, CI-Job „Mac Gallery (macOS)“ | test | Anordnung und Lauf der Mac-UI-Tests |
| Neue externe Abhängigkeit | – | keine |

## Nicht in diesem Schnitt

- Die Listen (`TaskListView`): fertig in Schnitt 1, hier nur `ChosenRows` geöffnet.
- Gemeinsamer `ViewModifier` für beide Listen (Alternative oben, erst bei einer dritten Liste).
- Tasten in der Schublade „Neu“, in der rechten Spalte und in der Seitenleiste; Return öffnet, Mehrfachauswahl, Tab-Reihenfolge,
  weitere Kurzbefehle.
- Detailansicht, Unteraufgaben per Taste aufklappen.
- Eine Mindestgröße für Nebenfenster (Menüleisten-Panel, Einstellungen); nur das Hauptfenster.
- iPhone, iPad, Watch, Widgets; Modell, Schema, Rechte, AppStorage.

## Auslieferung

Abnahme: Stufe 1 Tests (Unit, iOS-UI-Smoke als Gegenprobe, `MacKeyboardTests` und bestehende Mac-Tests in der CI), Stufe 2
Simulator (iPhone/iPad vorher/nachher) und Mac-Bilder aus dem CI-Artefakt. Satz im Abschlussbericht: „Kein Pfad der Geräteliste
berührt.“ Laut Ticket-DoD schaut Henning über TestFlight auf dem Mac auf das Ganze: er bekommt die Buildnummer und die
Prüfschritte (Startseite öffnen, ↓ drücken, Leertaste, ⌫, Fenster klein ziehen), keine Befehlszeile. Kein Modell, deshalb kein
`mac-schema-init`. Der PR trägt `Closes #480`.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — reine Mac-Bedienung auf vorhandenen Aktionen und der Logik aus Schnitt 1, kippt keine ADR; ADR-14 (Akzent =
antippbar/gewählt) wird eingehalten.

## Definition of Done

- [ ] AC-1 bis AC-14 erfüllt; `sim-unit` und iOS-UI-Smoke grün; `MacKeyboardTests` und die bestehenden Mac-Tests grün in der CI.
- [ ] Stufe 2: iPhone und iPad breit im Simulator vorher/nachher; Mac-Fotos aus dem CI-Artefakt geöffnet und beschrieben.
- [ ] Satz im Abschlussbericht: „Kein Pfad der Geräteliste berührt.“
- [ ] PR mit `Closes #480`; Board gepflegt; Belege unter `docs/artifacts/feat-480-s2-startseite-tasten/`; Mac-Abnahme über TestFlight
  nach dem Merge laut Ticket-DoD, Rückmeldung von Henning schließt den Punkt.

## Changelog

- 2026-10-22: Spec aus der Analyse `docs/context/feat-480-s2-startseite-tasten.md` geschrieben. Entscheidungen: begrenzte Übernahme
  der Tastenlogik statt gemeinsamem ViewModifier; kein Listenfokus beim Erscheinen (⌘N, #472); `textFocused` aus dem gemeldeten
  Fokus der Schreibzeile, nicht auf Handler-Vorrang verlassen; Mindestgröße 760 × 520 pt am Fensterinhalt.
