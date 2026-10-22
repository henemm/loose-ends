# Adversary Dialog — feat-480-mac-tastatur-zeiger
Spec: docs/specs/feat-480-schnitt-1-liste.md
Datum: 2026-10-21 08:33

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
Zweiter Durchgang nach BROKEN. Ich lese Diff und Dateien, nicht die Behauptung. Vorgaenger-Findings nachgeprueft:

- F001 (Space in Done/New/Parked): behoben. `RowKeyAction.spaceCompletes(in:status:)` (Shared/Models/RowKeyAction.swift:42) liefert false fuer .done/.new/.parked und fuer status parked/done; `handle` reicht das als `completes` in `resolve` (LooseEnds/Views/TaskListView.swift:187). Abgleich mit `TaskInteractions.leadingActions` (TaskInteractions.swift:56-81): Done=Restore, Parked=Activate, New=Looks right (kein Done), sonst Complete. Stimmt. Abweichung zugunsten der Vorsicht: im "Loose ends"-Parkblock bietet der Wisch (default-Zweig) noch "Complete", Space ignoriert (RowKeyAction.swift:42ff). Kein Defekt, Spec-Tabelle kennt die Ausnahme nicht (LOW, F005).
- F002 (Scroll): behoben. `ScrollViewReader` + `onChange(of: selectedID) { proxy.scrollTo(id) }` (TaskListView.swift:141,170). Die Zeilen-IDs sind UUID: `ForEach(shown)` ueber `TaskItem.id: UUID` (Shared/Models/TaskItem.swift:10), im Projekt `ProjectLine.id == task.id` (ViewRules.swift:279). scrollTo trifft also. Offen nur: Verhalten von scrollTo an macOS-`List` mit Sektionen, nur in der CI sichtbar.
- F003 (Modifikatoren): behoben im Code. onKeyPress prueft `press.modifiers.isDisjoint(with: [.command,.shift,.option,.control])` (TaskListView.swift:149). Pfeile tragen auf macOS .numericPad/.function, beide nicht in der Sperrmenge, werden also durchgelassen. Fallbacks nutzen `NSEvent.modifierFlags` (TaskListView.swift:209), Namen .command/.shift/.option/.control existieren, `import AppKit` unter `#if os(macOS)` (Zeile 2-4). Lesend kompilierbar: `onKeyPress(keys:)` mit Set-Literal, `KeyEquivalent.delete`, `KeyPress.Result` Rueckgabe, `@FocusState` im macOS-`#else`. Nicht uebersetzt, daher kein Beweis.
- F004 (Textfokus): kein Code-Fehler, aber Beleg schwach, siehe unten.

Weitere Suche nach Defekten:
- rowIDs (TaskListView.swift:214) gegen die Sektionsreihenfolge im Body geprueft: done (groupedByCompletionDay), Projekt (lines ohne Unterzeilen), New (confirm vor look), Due/Open (needsDate, rest, parked), sonst shown. Deckungsgleich, Reihenfolge stimmt.
- Klick: `detail(...).onAppear { selectedID = task.id }` (Zeile 134) setzt die Auswahl beim Oeffnen, kein `List(selection:)`; `onChange(of: selectedID)` scrollt dabei auf eine verdeckte Liste, harmlos. `onChange(of: rowIDs)` leert die Auswahl, wenn die Zeile verschwindet (erledigt/geloescht). Bei Rueckkehr kommt `onAppear { listFocused = true }` erneut.
- Pending-Zeilen: `isPending` verhindert doppeltes Einplanen (TaskListView.swift:195). Unteraufgabenzeile (Zeile 482) ohne selected, richtig, keine Zeile der Auswahl.
- Reihenfolge `hull(keyed(List))`: listStyle/paperGround wirken ueber die Umgebung durch den ScrollViewReader; `.overlay` haengt weiter am Ergebnis von hull. Kein Befund, aber nur die CI zeigt es.
- Ungeklaert, nur CI: ob `.focused($listFocused)` an einer macOS-`List` (NSTableView) ohne `.focusable()` den Fokus tatsaechlich nimmt und ob `onKeyPress` nach dem Klick aufs Papier unter der letzten Zeile feuert (`focusList`, MacKeyboardTests.swift). Ob `XCUIElement.isSelected` die Trait `.isSelected` (accessibilityAddTraits an TaskRow, TaskListView.swift ~409/503) als AXSelected sieht, ebenso.
- Umfang: numstat Produktion Paper 13 + TaskListView 144 + RowKeyAction 48 = 205 Zeilen; mit Tests (28 + 73) insgesamt 306 geaenderte Zeilen. Spec schaetzt +190/-10 und sagt "ueber 250: stoppen und nachfragen". Dateigrenze 5 eingehalten. Siehe F006.
- AC-10: kein AppStorage, Modell, Schema, Entitlement; nur @State/@FocusState (TaskListView.swift:37-38).

Finding F005:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Models/RowKeyAction.swift:42
  Description: Space ignoriert geparkte Aufgaben auch im Parkblock von "Loose ends"; dort bietet der Wisch (TaskInteractions.swift:76 default) "Complete".
  Spec requirement: AC-4 — Leertaste erledigt die gewaehlte Zeile
  Conflict: Spec-Tabelle nennt die Ausnahme nicht; Verhalten ist aber sicherer als der Wisch.
  Remediation: Ausnahme in der Spec nachtragen oder so lassen. Kein Blocker.

Finding F006:
  ID: F006
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Views/TaskListView.swift:141
  Description: Umfang 306 geaenderte Zeilen inkl. Tests (205 Produktion) gegen Spec-Schaetzung +190/-10 und Grenze 250.
  Spec requirement: Scope "Estimated Changes" — ueber 250 stoppen und mit Schaetzung nachfragen
  Conflict: Grenze je nach Zaehlweise (mit Tests) ueberschritten, nicht angefragt.
  Remediation: Henning/PO kurz bestaetigen lassen (Produktionscode 205 < 250, Rest ist Test) oder Zaehlweise festhalten.

Finding F007:
  ID: F007
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Views/TaskListView.swift:187
  Description: `textFocused: false` fest; die Liste hat kein Suchfeld. `testTextFocusKeepsKeys` nutzt das Capture-Feld aus Cmd-N; das prueft die Modalitaet des Systems, nicht die Liste. Der Test wuerde auch ohne jede Sperre im Listencode bestehen.
  Spec requirement: AC-6 — Mit Textfokus (Suchfeld) wirken Leertaste und Backspace nicht auf Aufgaben
  Conflict: Der Wortlaut "Suchfeld" existiert nicht; die Regel-Seite (`RowKeyActionTests` Faelle textFocused) ist bewiesen, die Ansicht reicht den Parameter nie durch (immer false).
  Remediation: AC-6 per Spec-Nachbesserung (override) auf "die Liste hat kein Textfeld; Tasten erreichen sie nur bei Listenfokus" umformulieren, der Test bleibt als Gegenprobe (Capture-Sheet bei gewaehlter Zeile). Ohne Nachbesserung bleibt AC-6 AMBIGUOUS.

Confirmation:
  AC: AC-1
  Code reference: Shared/Models/RowKeyAction.swift:19
  Evidence: resolve folgt der Tabelle; RowKeyActionTests 14/14, sim-unit 880 + 10 gruen (docs/artifacts/feat-480-mac-tastatur-zeiger/test-green-output.txt, nicht neu gestartet). Datei importiert nur Foundation.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Views/Paper.swift:141
  Evidence: selected nur im macOS-Zweig von WideListRow; TaskListView-Neuerungen hinter #if os(macOS), iOS liefert isChosen=false und list unveraendert (TaskListView.swift:121-127,141ff). iOS-Build und Unit-Lauf gruen. iOS-UI-Smoke und iPhone-Vorher/Nachher-Bild nicht von mir gesehen.
  Status: CONFIRMED (Code, Build, Unit)

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Views/TaskListView.swift:37
  Evidence: nur @State und @FocusState; kein AppStorage, Modell, Schema, Entitlement, keine Abhaengigkeit.
  Status: CONFIRMED

**Implementierer:**
(nicht beteiligt)

### Runde 2
**Adversary:**
Gegenprobe auf Fruehe Einigkeit: Ich habe versucht, die Regel-Teile zu brechen. AC-4 Regel: spaceCompletes deckt alle ViewKind-Zweige der Wischlogik (Done, Parked, New, default); Test `spaceFinishesOnlyWhereTheSwipeOffersDone` listet .next,.due,.quick,.old,.waiting,.repeating,.open als true, passend zu default. AC-5 Regel: `.delete` setzt nur `pendingDelete`/`confirmingDelete` (TaskListView.swift:200-201), keine neue Loeschlogik; Delete fragt auch bei nicht erledigbaren Zeilen (gewollt). AC-3 Regel: `selected` gewinnt vor `hovering` (Paper.swift:141-144), Werte 0.12 und 0.07 wie in der Spec. AC-6 Regel: resolve liefert bei textFocused .ignore in jedem Fall (RowKeyAction.swift:25). AC-7: kein `List(selection:)` im Diff (grep). Keinen echten Code-Defekt gefunden; die Fallbacks onMoveCommand/onDeleteCommand koennten auf macOS doppelt zur Taste feuern, falls die List Pfeile selbst bewegt und onKeyPress ebenfalls handled; die Dokumentation sagt, ein gehandeltes Ereignis wird nicht zum Command. Das kann nur die CI zeigen.
**Implementierer:**
(nicht beteiligt)

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Einziges neues Feld: der View-Zustand `selectedID` (LooseEnds/Views/TaskListView.swift:37). Bedingung davor: geschrieben von `handle` bei Pfeiltasten mit Listenfokus (TaskListView.swift:184), von `detail().onAppear` beim Oeffnen (Zeile 134), geleert durch `onChange(of: rowIDs)`. Test fuer diesen Weg: RowKeyActionTests fuer die Zuordnung; die Schreibwege selbst nur MacKeyboardTests.testArrowsSelectAndSpaceCompletes und testClickOpensAndMarks (CI-Mac, noch nie gruen gelaufen), sonst keiner.

## Verdict

VERDICT: AMBIGUOUS
Kein echter Code-Defekt gefunden; F001-F003 behoben. Offen nur Beweise und zwei Spec-Fragen:
- F007 (MEDIUM): AC-6-Beleg misst nicht die Liste; Spec-Wortlaut "Suchfeld" passt nicht. Spec-Nachbesserung noetig.
- F006 (MEDIUM): 306 Zeilen mit Tests (205 Produktion) gegen Spec-Grenze 250.
- F005 (LOW): Space im Parkblock enger als der Wisch.
Lokal bewiesen: AC-1, AC-9 (Code/Build/Unit), AC-10 und die Regelteile von AC-3..AC-6. Haengen am CI-Mac-Lauf: AC-2, AC-3 (Fotos), AC-7, AC-8 und die UI-Seite von AC-4..AC-6.

## Geprüfte Dateien

- sha256:8d6a48f99ceacdd377375a07f4b6aa29f0938b97fb95475a1662cb626aaa6b82  LooseEnds/Views/Paper.swift
- sha256:996ee8da66889194463451741376e0e2b4dca6c4393f0dfb3942b4c6effc0085  LooseEnds/Views/TaskListView.swift
- sha256:da6762b4f07404a65cb861ed04b409be014a4257d8833d1f197c0fdd73c5e5c8  Shared/Models/RowKeyAction.swift

## Prüfbasis

- base: 6ce15a05448b2ed277eb80a4a876621eda8d402c
- blob:98c4c27f8cf604fe7ef65b90fd94138eea5a7a18  LooseEnds/Views/Paper.swift
- blob:8dbf71b9e10a69227e192a7ac229392e04b67c63  LooseEnds/Views/TaskListView.swift
- blob:21d3c67873eea1cdda6905e0c8a982c4e5b227dc  Shared/Models/RowKeyAction.swift
