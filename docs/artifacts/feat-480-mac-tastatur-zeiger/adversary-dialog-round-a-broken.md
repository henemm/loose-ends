# Adversary Dialog — feat-480-mac-tastatur-zeiger
Spec: docs/specs/feat-480-schnitt-1-liste.md
Datum: 2026-10-21 08:01

## Checkliste
- [x] **AC-1:** Die Zuordnung Taste → Aktion ist eine reine Funktion in `Shared/Models/RowKeyAction.swift` und folgt der Tabelle in „Implementation Details“. Beleg: `RowKeyActionTests` grün (alle Fälle der Tabelle).
- [ ] **AC-2:** In einer Liste wählen ↓ und ↑ die nächste bzw. vorige Zeile; ohne Auswahl wählt ↓ die erste, ↑ die letzte; an den Rändern bleibt die Auswahl. Beleg: `MacKeyboardTests.testArrowsSelectAndSpaceCompletes` grün.
- [ ] **AC-3:** Die gewählte Zeile steht in Akzent 12 % (hell und dunkel), Hover in Grau 7 %, bei beidem gewinnt Akzent. Beleg: Fotos `mac-keyboard-selection-light` und `-dark` aus dem CI-Lauf, geöffnet und beschrieben; Diff zeigt `opacity(0.12)` und `opacity(0.07)` in `WideListRow`.
- [ ] **AC-4:** Die Leertaste erledigt die gewählte Zeile über das Rückgängig-Fenster (#32); in dessen Frist lässt sich die Aufgabe zurückholen. Beleg: `testArrowsSelectAndSpaceCompletes` grün; Diff ruft nur `TaskInteractions.complete(_:)`.
- [ ] **AC-5:** ⌫ löscht die gewählte Zeile erst nach der Rückfrage „Delete this task?“; Abbrechen löscht nichts. Beleg: `testDeleteAsksFirst` grün; Diff nutzt nur `pendingDelete`/`confirmingDelete`, keine neue Löschlogik.
- [ ] **AC-6:** Mit Textfokus (Suchfeld) wirken Leertaste und ⌫ nicht auf Aufgaben. Beleg: `testTextFocusKeepsKeys` grün; `RowKeyActionTests` Fälle mit `textFocused`.
- [ ] **AC-7:** Ein Klick öffnet die Aufgabe wie bisher und markiert die Zeile; es gibt kein `List(selection:)`. Beleg: `testClickOpensAndMarks` und bestehende `MacDetailClickTests`, `StartScreenInteractionTests` grün.
- [ ] **AC-8:** ⌘N, ⌘, und das Rechtsklick-Menü der Zeile bleiben wirksam und sind belegt. Beleg: `testShortcutsAndContextMenu` grün.
- [x] **AC-9:** iPhone und iPad bleiben unverändert: alle neuen Zweige hängen hinter `#if os(macOS)`. Beleg: Diff (iOS-Zweige von `TaskListView` und `WideListRow` ungeändert); iOS-UI-Smoke und voller Unit-Lauf grün; iPhone-Bild vorher/nachher gleich.
- [x] **AC-10:** Kein neuer AppStorage-Schlüssel, kein Modell-, Schema- oder Rechte-Eingriff, keine neue Abhängigkeit. Beleg: Diff.

## Dialog

### Runde 1
**Adversary:**
Ich lese den Diff, nicht die Behauptung. Befunde mit Code-Bezug:

Finding F001: Leertaste erledigt in der Ansicht "Done" erneut und umgeht die Swipe-Regeln in New und Parked
  Severity: HIGH
  Category: edge_case
  Code reference: LooseEnds/Views/TaskListView.swift:177
  Description: `handle(.space)` ruft `actions.complete(task)` fuer jede gewaehlte Zeile, ohne `kind` zu pruefen; nur `isPending` wird abgefangen. In der Ansicht Done ist die Zeile schon erledigt: `TaskActions.complete` (Shared/Services/TaskActions.swift:32-34) setzt `completedAt = now` neu, die Aufgabe springt in den Tagesabschnitt "heute". Die Swipe-Leiste bietet dort bewusst "Restore" (TaskInteractions.swift:57-59), in New bewusst kein Done (#318, TaskInteractions.swift:65-71), in Parked "Activate".
  Spec requirement: AC-4 (Leertaste erledigt ueber das Rueckgaengig-Fenster, nur bestehende Aktionen); Purpose (keine Seiteneffekte)
  Conflict: Datenaenderung an bereits erledigten Aufgaben (Erledigt-Zeitpunkt ueberschrieben, Reihenfolge der Done-Liste verschoben) und Umgehung der Regel aus #318 durch die Tastatur.
  Remediation: In `handle` bei `kind == .done` die Leertaste ignorieren (oder restore), bei .new/.parked analog zum Swipe; Test fuer die Zuordnung Ansicht -> Aktion.

Finding F002: Gewaehlte Zeile wird nicht in den sichtbaren Bereich gescrollt
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEnds/Views/TaskListView.swift:143
  Description: Die Pfeile setzen nur `selectedID`; es gibt kein `ScrollViewReader`/`scrollTo` (grep: keine Treffer). Bei mehr Zeilen als Fensterhoehe laeuft die Auswahl aus dem Bild; Leertaste erledigt dann eine unsichtbare Zeile ohne Rueckfrage.
  Spec requirement: AC-2 und AC-4 (Aktionen auf die gewaehlte Zeile)
  Conflict: Nutzer erledigt ungesehen.
  Remediation: `ScrollViewReader` mit `proxy.scrollTo(id)` bei `selectedID`-Wechsel.

Finding F003: Modifikatoren werden nicht geprueft
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/TaskListView.swift:143
  Description: `onKeyPress(keys:)` ignoriert `press.modifiers`; Shift+Leertaste, Option+Pfeil, Cmd+Backspace loesen dieselbe Aktion aus.
  Spec requirement: AC-4
  Remediation: `guard press.modifiers.isEmpty`.

Finding F004: Der AC-6-Test beweist die Textfokus-Sperre nicht, `textFocused` ist fest false
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Views/TaskListView.swift:174
  Description: `resolve(..., textFocused: false, ...)`. Die Spec verlangt, dass die Ansicht `textFocused` aus ihren Fokuszustaenden uebergibt (Tiefenverteidigung); die Liste hat kein Textfeld, also derzeit keine Luecke, aber keine zweite Sperre. `testTextFocusKeepsKeys` (LooseEndsUITests/MacKeyboardTests.swift:167) nutzt das Feld des Cmd+N-Sheets; ein Sheet bekommt die Tasten ohnehin, der Test wird auch ohne jede Sperre gruen und beweist AC-6 nur schwach. Die Spec nennt ein Suchfeld, das es in der Liste nicht gibt (Abweichung ehrlich zu benennen).
  Spec requirement: AC-6
  Conflict: Beleg schwach, Spec-Wortlaut nicht erfuellt.
  Remediation: Spec-Wortlaut angleichen; zusaetzlich Taste mit Fokus ausserhalb der Liste (Seitenleiste) pruefen.

Geprueft und ohne Defekt:
- Reihenfolge und Menge `rowIDs` (TaskListView.swift:193-217) gegen die Sektionen: Done = groupedByCompletionDay, Projekt = lines ohne Unteraufgaben-Zeilen, New = confirm dann look, Due/Open = needsDate + rest + parked mit gleicher Kurzschlussbedingung wie newDateSections, Rest = shown. Nach #599 laufen Unteraufgaben mit eigenem Datum ueber `ViewRules.leftovers` in beiden Pfaden gleich. Kontextansicht (kind nil, project nil) faellt wie body in `shown`. Gleiche Menge, gleiche Reihenfolge.
- Doppelausloesung: `onKeyPress` liefert `.handled`, dann entstehen keine Move-/Delete-Commands; Fallbacks greifen nur bei `.ignored`. Am Rand liefert resolve select(gleiche), also handled. Leertaste auf Zeile im Done-Fenster: handled ohne Aktion.
- Auswahl nach Erledigen/Loeschen/Verschieben: `onChange(of: rowIDs)` leert sie (TaskListView.swift:163-165).
- iOS: `selectedID`, `listFocused`, `keyed`, `handle`, `rowIDs` hinter `#if os(macOS)`; `isChosen` false auf iOS; `wideListRow(selected:)` Default false; iOS-Build und sim-unit gruen (test-green-output.txt).

**Implementierer:** (in dieser Pruefung nicht erreichbar; Antwort steht aus)

### Runde 2
**Adversary:**
Zweiter Angriff auf das, was nur die CI zeigen kann, und auf die Tests selbst.

- Trait (Angriffsflaeche 6): `.accessibilityAddTraits(.isSelected)` sitzt am `TaskRow`-Aufruf (TaskListView.swift:387, 483). `TaskRow` setzt `.accessibilityElement(children: .combine)` und die Kennung `taskRow_<id>` auf seiner Wurzel (TaskRow.swift:51-52); das Trait von aussen wirkt auf dasselbe Element. Im `NavigationLink` auf dem Mac kann XCUITest die Kennung aber am Link-Element sehen. Lokal nicht belegbar, haengt am CI-Lauf von `selectedRows` (`isSelected`).
- Listenfokus: `.focused($listFocused)` an `List` ohne `.focusable()` (TaskListView.swift:141). Ob die List den Fokus uebernimmt und `onKeyPress` vor dem NSTableView-Eigenverhalten bekommt, ist ohne Mac-Lauf offen. Die Fallbacks `onMoveCommand`/`onDeleteCommand` decken Pfeile und Delete, aber nicht die Leertaste: faellt `onKeyPress` fuer Space aus, bleibt AC-4 tot.
- Fokus nach der Rueckfrage: `testDeleteAsksFirst` drueckt nach Escape erneut Delete; ob die Liste den Fokus nach dem `confirmationDialog` behaelt, ist offen.
- Testqualitaet `focusList` (MacKeyboardTests.swift:96): Klick 80 pt unter die letzte Zeile; ob ein Klick auf leere Listenflaeche der List den Fokus gibt, zeigt nur die CI. Die Tests werden nicht trivial gruen (ohne Marke scheitert `selectedRows == [ids[0]]`), koennen aber falsch-rot sein.
- `goBack` (MacKeyboardTests.swift:86): Rueckfall `toolbars.buttons.firstMatch` kann die Seitenleistentaste treffen; scheitert laut, nie falsch-gruen.
- `testClickOpensAndMarks`: setzt voraus, dass `selectedID` die Navigation ueberlebt; bis CI offen.
- Umfang: Produktion TaskListView +123, Paper +13, RowKeyAction 34 (rund 170 LoC), Dateien genau die der Spec, unter 250. AC-10: kein AppStorage, Modell, Schema, Recht, keine Abhaengigkeit.
- AC-1: test-green-output.txt Zeilen 1190-1202, Suite RowKeyActionTests bestanden; RowKeyAction.swift:18-33 gegen die Tabelle gelesen, jede Zeile stimmt.

**Implementierer:** (nicht erreichbar)

## Konfirmationen

Confirmation:
  AC: AC-1
  Code reference: Shared/Models/RowKeyAction.swift:18
  Evidence: resolve folgt der Tabelle, 11 Unit-Faelle gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Views/Paper.swift:141
  Evidence: neuer Zweig `selected` nur im macOS-Zweig von WideListRow; TaskListView-Neuerungen hinter `#if os(macOS)` (LooseEnds/Views/TaskListView.swift:138); iOS-Build und Unit-Lauf gruen. iOS-UI-Smoke und iPhone-Bild nicht eingesehen.
  Status: CONFIRMED (Code und Unit-Lauf)

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Views/TaskListView.swift:31
  Evidence: nur @State/@FocusState; kein AppStorage, Modell, Schema, Entitlement.
  Status: CONFIRMED

Nicht belegt (AMBIGUOUS bis CI): AC-2 (TaskListView.swift:143), AC-3 (Paper.swift:141-144, Foto fehlt), AC-4 (TaskListView.swift:177, dazu F001), AC-5 (TaskListView.swift:181), AC-6 (TaskListView.swift:174, F004), AC-7 (TaskListView.swift:387), AC-8 (nur Test, MacKeyboardTests.swift). Alle haengen am MacKeyboardTests-Lauf in der CI, der nie gruen war.

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Neues Feld: nur der View-Zustand `selectedID` (LooseEnds/Views/TaskListView.swift:35). Bedingung davor: geschrieben von `handle` bei Pfeiltasten mit Listenfokus, von `detail().onAppear` beim Oeffnen, geleert durch `onChange(of: rowIDs)`. Test fuer diesen Weg: RowKeyActionTests (Zuordnung); die Schreibwege selbst nur durch MacKeyboardTests (CI, noch nie gruen), sonst keiner.

## Verdict

VERDICT: BROKEN
Finding F001 (HIGH): Leertaste erledigt in Done erneut (completedAt ueberschrieben) und umgeht Swipe-Regeln in New und Parked, LooseEnds/Views/TaskListView.swift:177.
Finding F002 (MEDIUM): kein scrollTo fuer die Auswahl, TaskListView.swift:143.
Finding F004 (MEDIUM): AC-6-Test beweist die Sperre nicht, textFocused fest false, TaskListView.swift:174.
Finding F003 (LOW): Modifikatoren ungeprueft.
Zusaetzlich AC-2..AC-8 ohne Beleg (CI-Mac-Lauf nie gruen).

## Geprüfte Dateien

- sha256:8d6a48f99ceacdd377375a07f4b6aa29f0938b97fb95475a1662cb626aaa6b82  LooseEnds/Views/Paper.swift
- sha256:4cf0b013670a1542daad7136edd96b9e3b786a66a171d705e446a5d510006d0d  LooseEnds/Views/TaskListView.swift
- sha256:3c1e8991bb59848db62a9d8b6293e8ec83b8b97064fa1afc9a0d3d52506a6d82  Shared/Models/RowKeyAction.swift

## Prüfbasis

- base: 6ce15a05448b2ed277eb80a4a876621eda8d402c
- blob:98c4c27f8cf604fe7ef65b90fd94138eea5a7a18  LooseEnds/Views/Paper.swift
- blob:af550ba5ab2cbf2829ddf2fde7378eb17b1b1314  LooseEnds/Views/TaskListView.swift
- blob:0dd8ca6d47df07d13caf0b2528ff6462fe3e005b  Shared/Models/RowKeyAction.swift
