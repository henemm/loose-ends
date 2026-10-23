# Adversary Dialog — feat-480-s2-startseite-tasten
Spec: docs/specs/feat-480-schnitt-2-startseite.md
Datum: 2026-10-23 08:20

## Checkliste
- [x] **AC-1:** Auf der Mac-Startseite wählen ↓ und ↑ die nächste bzw. vorige sichtbare „Jetzt“-Zeile; an den Rändern bleibt die Auswahl. Beleg: `MacKeyboardTests.testStartArrowsSelectAndSpaceCompletes` grün.
- [x] **AC-2:** Bei zugeklapptem „Jetzt“-Block sind nur die ersten 5 Zeilen wählbar; nach „Mehr“ alle. Schublade „Neu“ und rechte Spalte sind nicht wählbar. Beleg: `testStartMoreExtendsRows` grün.
- [x] **AC-3:** Die Leertaste erledigt die gewählte Zeile über das Rückgängig-Fenster (#32); eine Zeile im Rückgängig-Fenster wird nie ein zweites Mal eingeplant. Beleg: `testStartArrowsSelectAndSpaceCompletes` grün; Diff ruft nur `TaskInteractions.complete(_:)` und prüft `isPending`.
- [x] **AC-4:** ⌫ löscht die gewählte Zeile erst nach der Rückfrage „Delete this task?“; Abbrechen löscht nichts. Beleg: `testStartDeleteAsksFirst` grün; Diff nutzt nur `pendingDelete`/`confirmingDelete`, keine neue Löschlogik.
- [x] **AC-5:** Solange die Schreibzeile Fokus hat, wirken Pfeile, Leertaste und ⌫ nicht auf Aufgaben; Leertaste und ⌫ bleiben im Feld. Beleg: `testStartWritingLineKeepsKeys` grün; Diff übergibt `textFocused` aus dem gemeldeten Fokus der Schreibzeile.
- [x] **AC-6:** ⌘N setzt den Cursor weiter in die Schreibzeile, auch bei gewählter Zeile und Listenfokus (#472 bleibt grün). Beleg: `testStartNewTaskShortcutFocusesWritingLine` und `StartScreenInteractionTests` grün.
- [x] **AC-7:** Beim Erscheinen der Startseite hat die Liste keinen Fokus und keine Zeile ist gewählt. Beleg: `testStartHasNoListFocusOnAppear` grün; Diff setzt auf der Startseite kein `listFocused = true` beim Erscheinen.
- [x] **AC-8:** Ein Klick öffnet die Aufgabe wie bisher und markiert die Zeile; die Auswahl überlebt Detail und Zurück (Speicher in `ChosenRows.shared.start`). Beleg: `testStartSelectionSurvivesDetail` sowie `MacDetailClickTests` und `StartScreenInteractionTests` grün; kein `List(selection:)`.
- [x] **AC-9:** Verschwindet die gewählte Zeile (erledigt, verschoben, gelöscht), ist keine Zeile gewählt; nichts springt weiter. Beleg: `testStartSelectionClearsWhenRowGoes` grün.
- [x] **AC-10:** Die gewählte „Jetzt“-Zeile steht in Akzent 12 %, Hover in Grau 7 %, bei beidem gewinnt Akzent, dargestellt über `wideListRow(selected:)` (auch im Rückgängig-Zustand). Beleg: Fotos `mac-keyboard-start-selection-light` und `-dark` aus dem CI-Lauf, geöffnet und beschrieben; Diff nutzt `wideListRow(selected:)` und keine eigenen Farben.
- [x] **AC-11:** iPad breit und iPhone sehen unverändert aus (gleiche 11 pt vertikal, gleiche Zeilenränder, kein Hover, keine Auswahl); alle neuen Zweige hängen hinter `#if os(macOS)`. Beleg: Diff; iOS-UI-Smoke und voller Unit-Lauf grün; iPad-Bild vorher/nachher gleich.
- [x] **AC-12:** Die bestehenden Zeilen-IDs `startNowRow_<id>` bleiben unverändert. Beleg: `MacGalleryTests` und `MacDetailClickTests` grün ohne Änderung; Diff berührt die IDs nicht.
- [x] **AC-13:** Das Hauptfenster der Mac-App lässt sich nicht kleiner als 760 × 520 pt ziehen. Beleg: `testWindowMinimumSize` grün; Diff zeigt `.frame(minWidth: 760, minHeight: 520)` und `.windowResizability(.contentMinSize)` hinter `#if os(macOS)`.
- [x] **AC-14:** Kein neuer AppStorage-Schlüssel, kein Modell-, Schema- oder Rechte-Eingriff, keine neue Abhängigkeit; `project.yml` unverändert. Beleg: Diff.

## Dialog

### Runde 1
**Adversary:**
Tests: CI-Lauf 39825553494 (Commit c1991f1): MacKeyboardTests 18/18, MacGalleryTests 13/13, MacDetailClickTests 10/10, 0 Fehler, 0 übersprungen
(test-green-output.txt; ci-mac-gallery-green.log:783,1472,1518); sim-unit "Test Succeeded" (sim-unit-output.txt). Nicht belegt:
ein Lauf von `StartScreenInteractionTests` (im Mac-Log 0 Treffer für "Test Case.*StartScreenInteraction", dort nur kompiliert).

Fotos geöffnet. light: Fenster 1024x674, "Aufgabe 2" mit grünlich-teal getönter, abgerundeter Fläche (Akzent 12 %), "Aufgabe 4" (Hover)
mit neutral grauer Fläche; die Auswahl ist deutlich farbiger als der Hover; "Neu"-Schreibzeile und Kopf ungetönt, keine eigenen Farben.
dark: gleiches Bild, Auswahl dunkel-teal, Hover dunkelgrau. Das Foto heißt `mac-gallery-480-start-selection-*`, nicht wie in der Spec
`mac-keyboard-...` (nur Namensabweichung der Spec). Zugprotokoll: left edge 1024x674 -> 760x674, bottom edge -> 760x572.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/StartPage.swift:183
  Evidence: `keyed` bindet onKeyPress für up/down/space/delete (nur ohne ⌘⇧⌥⌃), `handle` (Zeile 223) löst über `RowKeyAction.resolve` auf `rowIDs` auf; Randverhalten aus Schnitt 1; testStartArrowsSelectAndSpaceCompletes prüft "Up am Rand bleibt Zeile 1" (Mac-Log grün).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/StartPage.swift:253
  Evidence: `rowIDs` nimmt `prefix(NowBlock.limit)` (5) bei zugeklappt; `nowExpanded` ist derselbe Zustand wie in NowBlock (StartZones.swift:51-65). Test: 7 Aufgaben, 7x Down stoppt auf Zeile 5, nach "Mehr" zwei Downs auf Zeile 7. Schublade und rechte Spalte sind nie in `rowIDs` (indirekt, siehe F005).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Views/StartPage.swift:232
  Evidence: `.complete` ruft nur `actions.complete(task)` und nur wenn `!actions.isPending(task)`; Test: zweites Leerzeichen -> weiter genau 1 Undo-Knopf, Undo-ID gehört zur gewählten Zeile, nur diese Aufgabe verschwindet.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/StartPage.swift:237
  Evidence: `.delete` setzt nur `pendingTaskDelete`/`confirmingTaskDelete` (vorhandene Rückfrage); Test: Abbrechen (Escape) löscht nichts, zweiter Anlauf mit confirmDeleteButton löscht genau die gewählte.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/InboxDrawerView.swift:73
  Evidence: `onChange(of: writing)` meldet den echten Fokus der Zeile an `writingFocusChanged` (StartPage.swift:174), `handle` übergibt ihn als `textFocused`; Test tippt "a b", Delete nimmt "b" im Feld, Down/Space wirken nicht auf Aufgaben. Schwäche der Assertion: F003 (LOW).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Views/StartPage.swift:70
  Evidence: `listFocused` wird nirgends auf true gesetzt, kein .onAppear im Diff (grep leer); Test geht weg und zurück, drückt Space und Down, erwartet keine Auswahl und kein Undo. Nicht trivial: wäre der Fokus gesetzt, würde Down wählen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Views/StartPage.swift:212
  Evidence: `onChange(of: rowIDs)` löscht `selectedID`, wenn die Zeile fehlt; Test: Space, nach 3 Zeilen keine Markierung, zweites Space plant nichts. Ein Weiterspringen würde die Markierungsabfrage fangen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Views/StartPage.swift:138
  Evidence: auch der Rückgängig-Zweig läuft durch `.wideListRow(selected: isChosen(task))`; Paper.swift:139-147 malt Akzent 12 % vor Grau 7 %, keine eigenen Farben; Fotos light/dark geöffnet (s. oben).
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: LooseEnds/Views/StartPage.swift:136
  Evidence: `TaskRow(task:, identifierPrefix: "startNowRow_")` unverändert; MacGalleryTests und MacDetailClickTests grün, beide Dateien vom Diff unberührt.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: LooseEnds/App/LooseEndsApp.swift:110
  Evidence: `.frame(minWidth: 760, minHeight: 520)` (Zeile 110) und `.windowResizability(.contentMinSize)` (Zeile 116), beide in `#if os(macOS)`; Zugprotokoll: Breite hält bei 760, Höhe bei 572. Siehe F004 (LOW).
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: LooseEnds/Views/StartZones.swift:51
  Evidence: Diff gegen b8e656a berührt weder project.yml noch Shared/ noch Modell; kein AppStorage, kein try?, kein print; neuer Zustand nur @State und `ChosenRows.start` (TaskListView.swift:580), nichts persistiert. Funktionen <= 50 Zeilen (keyed ~40, handle ~28).
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: HIGH
  Category: regression
  Code reference: LooseEnds/Views/StartPage.swift:150
  Description: Die Jetzt-Zeile verliert auf iOS ihren eigenen `.padding(.vertical, 11)`, `.environment(\.startMetrics, ...)` und `.startRow(metrics)` und bekommt sie nur noch über `wideListRow`. Paper.swift:128-131 gibt im kompakten iOS-Zweig den Inhalt unverändert zurück. StartPage steckt im Detail der NavigationSplitView (ContentView.swift:73) und kann auf dem iPad kompakt sein (Slide Over, Drittel-Split; ContentView.swift:160 rechnet ausdrücklich mit `selection == nil` und `sizeClass == .compact`).
  Spec requirement: AC-11 — iPad und iPhone sehen unverändert aus (gleiche 11 pt vertikal, gleiche Zeilenränder)
  Conflict: Im kompakten Fall fallen 11 pt oben/unten, die 20-pt-Seitenränder und die `startMetrics` (TaskRow-Schriften, TaskRow.swift:68-171) weg: Jetzt-Zeilen werden niedriger und tragen Systemschriften statt der Entwurfsschriften.
  Remediation: Für iOS die drei alten Modifier unverändert behalten (`#if os(iOS)` alter Zweig), nur macOS neu verdrahten.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Views/StartPage.swift:153
  Description: Neue Zweige ohne `#if os(macOS)`: `.contentShape(Rectangle()).onTapGesture { open(task) }` (Zeile 152-153), `.accessibilityAddTraits(...)` (Zeile 143, auf iOS wirkungslos, isChosen ist false) und der Rückgängig-Zustand bekommt `.wideListRow` (Zeile 138). Auf dem breiten iPad bekommt die Rückgängig-Zeile damit erstmals 11 pt Polster, startMetrics und Rand; die Tippfläche liegt jetzt außerhalb des Buttons, das contextMenu (Zeile 148) umschließt das Polster nicht mehr (vorher im Button-Label); der äußere Tap kann für VoiceOver eine zweite Aktion erzeugen.
  Spec requirement: AC-11 — alle neuen Zweige hängen hinter `#if os(macOS)`; iPad/iPhone unverändert
  Conflict: wörtlich verletzt; gleiches Verhalten auf iOS (Rückgängig-Zeile, Langdruck-Menü am Polster, Zugriffsaktionen) nicht belegt.
  Remediation: iOS-Zweig der Zeile unverändert lassen; Tap-Geste und wideListRow der Rückgängig-Zeile nur unter `#if os(macOS)`.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/TaskListView.swift:580
  Description: `ChosenRows` wurde von `private` auf internal geöffnet (Zeile 576) und bekam `start`; die Auswahl lebt app-weit. testStartWritingLineKeepsKeys prüft nach Down im Feld nur `selectedNowRows != [ids[2]]` (MacKeyboardTests.swift), nicht `== [ids[1]]` oder leer; ein Sprung auf Zeile 1 oder 4 bliebe unbemerkt.
  Spec requirement: AC-5 — Pfeile wirken nicht auf Aufgaben, solange die Schreibzeile Fokus hat
  Conflict: Der Test beweist nur "nicht eine Zeile weiter", nicht "gar nicht".
  Remediation: Auswahl vor und nach dem Tippen lesen und gleich erwarten (oder leer, falls der Klick ins Feld sie löscht, dann so festlegen).

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/App/LooseEndsApp.swift:110
  Description: `minHeight: 520` gilt am Inhalt; das Fenster hält bei 572 (52 pt Titel-/Werkzeugleiste, nur abgeleitet, nicht gemessen). Der Test zieht zwei Kanten nacheinander, nie Ecke oder rechte Kante, und prüft nur `>= 760` / `>= 520`, nicht die tatsächliche Untergrenze.
  Spec requirement: AC-13 — Hauptfenster nicht kleiner als 760 x 520 pt
  Conflict: erfüllt (760 x 572 >= 760 x 520), aber die Spec sagt nicht, ob 520 Inhalt oder Fenster meint; das Fenster ist höher als gefordert.
  Remediation: In der Spec festhalten ("520 pt am Inhalt, Fenster 572").

Finding:
  ID: F005
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsUITests/MacKeyboardTests.swift:279
  Description: Die Tests klappen die Schublade mit Escape zu und klemmen den Klick ins Fenster (Zeile 100-108): echte Nutzergesten, schwächen keinen AC ab. Aber kein Test fährt Tasten bei offener Schublade (AC-2 "Schublade nicht wählbar" nur indirekt über `selectedNowRows`). Außerdem liegt eine temporäre `LooseEndsUITests/TmpIPadStartShotTests.swift` im Baum (vom Bildlauf); sie darf nicht in den Commit.
  Spec requirement: AC-2 — Schublade "Neu" ist nicht wählbar
  Conflict: nur indirekt bewiesen.
  Remediation: Test mit offener Schublade (ohne Escape): Down/Space wählen nichts. TmpIPadStartShotTests vor dem Commit löschen.

Stand Runde 1: angenommen AC-1, 2, 3, 4, 5, 7, 9, 10, 12, 13, 14. Offen: AC-6 und AC-8 (kein Lauf von StartScreenInteractionTests belegt), AC-11 (vorerst DISPROVEN, F001/F002).

Verlangter Beleg für Runde 2:
1. AC-6/AC-8: Lauf der `StartScreenInteractionTests` für c1991f1 (Testfallnamen, Anzahl) aus dem iOS-UI-Smoke- oder Mac-Job.
2. AC-11: iPad regulär vorher/nachher und iPad kompakt (Slide Over/Drittel-Split) vorher/nachher, dazu die Rückgängig-Zeile auf dem iPad; oder die Korrektur von F001/F002 mit Diff.
3. AC-11: voller iOS-UI-Smoke-Lauf als Log für c1991f1 mit Testzahl (nur "success" genügt nicht).
4. F003: schärfere Assertion oder Begründung.
5. AC-2: Ergebnis mit offener Schublade oder Begründung, warum der Escape-Weg genügt.
6. AC-13: Spec-Satz zu 520 am Inhalt; TmpIPadStartShotTests gelöscht.

**Implementierer:**

### Runde 2
**Adversary:**
Stand b5a9fdd (auf origin/main aufgesetzt). Ich habe Diff, Logs und Bilder selbst gelesen.

Tests: CI-Lauf 39916257254. Mac: MacGalleryTests 13/13, MacDetailClickTests 10/10, MacKeyboardTests 18/18, 0 Fehler (ci-mac-gallery-green.log:786,1478,1524). iOS UI Smoke: "Executed 73 tests, with 6 tests skipped and 0 failures" (ci-ui-smoke-green.log:1520). Die 6 übersprungenen sind DueNotificationTapTests x3 und PlaceNotificationTapTests x3 (brauchen LOOSEENDS_PUSH, nicht Teil dieses Schnitts, einzeln benannt). Lokal auf dem iPhone-Simulator: StartScreenInteractionTests, 20 Tests, 0 Fehler (start-screen-interaction-ios.txt). 0 bestanden mit Übersprungen liegt nicht vor, es sind 67 bestanden.

F001/F002: `nowRow` verzweigt jetzt mit `#if os(macOS)` zu `macNowRow`; der iOS-Zweig (StartPage.swift Zeilen 146-165) ist Zeile für Zeile der Code der Basis b8e656a (Button, padding 11, startMetrics, startRow, swipeActions, contextMenu, paperRow; Rückgängig-Zweig ohne wideListRow). Tap-Geste, isSelected-Trait, wideListRow, Fokus, `nowExpanded`, `open`, `isChosen`, Tastenlogik liegen alle hinter `#if os(macOS)`. Damit entfällt auch der kompakte Fall: es gibt auf iOS keinen geänderten Pfad mehr. Bilder: ipad-start-undo-before/after geöffnet und verglichen: Jetzt-Zeilen, Rückgängig-Zeile, Kopf und Seitenleiste sind identisch, einziger Unterschied die Uhr (08:30 gegen 08:38). Bleibender Rest: `InboxDrawerView.onWritingFocus` (Standardwert leere Closure) und `NowBlock(expanded:)` (Standard nil) sind plattformneutral, ändern aber auf iOS nichts (nil -> eigener Zustand). Die #398-Änderungen in StartZones.swift stammen von main.
F003: `chosenBefore == [ids[1]]` vorher und nachher (MacKeyboardTests.swift:462-471), schärfer, angenommen. F004: Spec Zeile 242 nennt "am Fensterinhalt", gemessen 760 x 572 = 520 + 52: angenommen. AC-2 Escape-Weg: Schublade ist nie in `rowIDs`, Escape ist echtes Produktverhalten, Klick wird ins Fenster geklemmt: als Begründung angenommen.

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Views/InboxDrawerView.swift:73
  Evidence: ⌘N läuft weiter über `focusRequest` in die Schreibzeile; testStartNewTaskShortcutFocusesWritingLine bei gewählter Zeile grün (Mac 18/18); StartScreenInteractionTests 20/20 lokal und im UI-Smoke-Lauf (73 Tests, 0 Fehler).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Views/TaskListView.swift:580
  Evidence: `ChosenRows.start` hält die Auswahl über Detail und Zurück; Klick öffnet und markiert (`open` in macNowRow, StartPage.swift:171-204); testStartSelectionSurvivesDetail, MacDetailClickTests 10/10 und StartScreenInteractionTests (testNowRowOpensItsTask) grün; kein `List(selection:)`.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: LooseEnds/Views/StartPage.swift:143
  Evidence: iOS-Zweig wörtlich gleich der Basis, alle neuen Zweige hinter `#if os(macOS)` (StartPage.swift:66,135,144,168,207,253; LooseEndsApp.swift:108-116; StartZones.swift neuer Parameter nur mit nil-Standard); iPad-Bilder vorher/nachher gleich bis auf die Uhr; iOS-UI-Smoke 73/0 Fehler.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: LooseEnds/App/LooseEndsApp.swift:110
  Evidence: `.frame(minWidth: 760, minHeight: 520)` und `.windowResizability(.contentMinSize)` hinter `#if os(macOS)`; Zugprotokoll 760 x 572; Spec Zeile 242 legt 520 auf den Inhalt fest.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/StartZones.swift:51
  Evidence: gemeinsamer Fold-Zustand und `limit` 5; rowIDs nur Jetzt-Zeilen (StartPage.swift:253); testStartMoreExtendsRows grün; Escape-Weg begründet.
  Status: CONFIRMED

Runde 1 weiter gültig: AC-1, 3, 4, 5, 7, 9, 10, 12, 14 (Code unverändert, CI erneut grün auf b5a9fdd). F001, F002, F003, F004 behoben. F005: Der Escape-Teil ist begründet; `LooseEndsUITests/TmpIPadStartShotTests.swift` liegt noch untracked im Baum und muss vor dem Commit gelöscht werden (Bedingung, kein Befund am Produktcode).

**Implementierer:** Fix und Belege laut Koordinator (b5a9fdd, CI 39916257254).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: 67 passed (iOS UI Smoke 73 Läufe, davon 6 übersprungen: DueNotificationTapTests x3, PlaceNotificationTapTests x3, brauchen LOOSEENDS_PUSH), Mac 41/41, StartScreenInteractionTests 20/20, 0 failed
Edge cases: All checked, none broken
Regressions: None found (iOS-Zweig wörtlich wie Basis, iPad-Bilder gleich)
Checklist: 14/14 points proven
Bedingung: LooseEndsUITests/TmpIPadStartShotTests.swift vor dem Commit löschen.

## Geprüfte Dateien

- sha256:25c7b8bce4eadaee07d9b707396015d7a7d4252bb0bafed7facfb8f355d66364  LooseEnds/App/LooseEndsApp.swift
- sha256:17e00b3f23c3508d0f75597b2b067ac7457c7be8dbd362891436a0d11c272d7d  LooseEnds/Views/InboxDrawerView.swift
- sha256:0c603d70fc3ce615bbb4bb090c1daec83f33ee78a982983bbae9bf66877b84ce  LooseEnds/Views/StartPage.swift
- sha256:97540c4117032d49da0a7e67affd967fcbf384f3e5b5e873ac450b32d8bb24de  LooseEnds/Views/StartZones.swift
- sha256:12b2cea395f06813088145b27f5d29c961db2720c0aebddbdb7f494ed97ef4ee  LooseEnds/Views/TaskListView.swift
- sha256:2c2f3af15f8eda3008c6131dc43d03b3ba8b9f6fbcfecaa9d4643b5a93769dd1  LooseEndsUITests/MacKeyboardTests.swift

## Prüfbasis

- base: 21548a386eb11c973e204957d3d336ddd8d279d0
- blob:8045b35596d8c7670a574096d024030b086dcae4  LooseEnds/App/LooseEndsApp.swift
- blob:885ac796100e5168455dc49892d9bccf1eb1e1fc  LooseEnds/Views/InboxDrawerView.swift
- blob:8773c16e8f507f4617fd795e4dab94e47e240be2  LooseEnds/Views/StartPage.swift
- blob:3b401fdaab585c4cdfd583ffec490ee1d395c69a  LooseEnds/Views/StartZones.swift
- blob:9ccb0e583ed68e080d58c5d08b48f735d9871ee9  LooseEnds/Views/TaskListView.swift
- blob:1794813d3319289c54315cdc2cc28419e012bace  LooseEndsUITests/MacKeyboardTests.swift
