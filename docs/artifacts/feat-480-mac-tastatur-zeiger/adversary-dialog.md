# Adversary Dialog — feat-480-mac-tastatur-zeiger
Spec: docs/specs/feat-480-schnitt-1-liste.md
Datum: 2026-10-21 09:58

## Checkliste
- [x] **AC-1:** Die Zuordnung Taste → Aktion ist eine reine Funktion in `Shared/Models/RowKeyAction.swift` und folgt der Tabelle in „Implementation Details“. Beleg: `RowKeyActionTests` grün (alle Fälle der Tabelle).
- [x] **AC-2:** In einer Liste wählen ↓ und ↑ die nächste bzw. vorige Zeile; ohne Auswahl wählt ↓ die erste, ↑ die letzte; an den Rändern bleibt die Auswahl. Beleg: `MacKeyboardTests.testArrowsSelectAndSpaceCompletes` grün.
- [x] **AC-3:** Die gewählte Zeile steht in Akzent 12 % (hell und dunkel), Hover in Grau 7 %, bei beidem gewinnt Akzent. Beleg: Fotos `mac-keyboard-selection-light` und `-dark` aus dem CI-Lauf, geöffnet und beschrieben; Diff zeigt `opacity(0.12)` und `opacity(0.07)` in `WideListRow`.
- [x] **AC-4:** Die Leertaste erledigt die gewählte Zeile über das Rückgängig-Fenster (#32); in dessen Frist lässt sich die Aufgabe zurückholen. Beleg: `testArrowsSelectAndSpaceCompletes` grün; Diff ruft nur `TaskInteractions.complete(_:)`.
- [x] **AC-5:** ⌫ löscht die gewählte Zeile erst nach der Rückfrage „Delete this task?“; Abbrechen löscht nichts. Beleg: `testDeleteAsksFirst` grün; Diff nutzt nur `pendingDelete`/`confirmingDelete`, keine neue Löschlogik.
- [x] **AC-6:** Mit Textfokus (Suchfeld) wirken Leertaste und ⌫ nicht auf Aufgaben. Beleg: `testTextFocusKeepsKeys` grün; `RowKeyActionTests` Fälle mit `textFocused`.
- [ ] **AC-7:** Ein Klick öffnet die Aufgabe wie bisher und markiert die Zeile; es gibt kein `List(selection:)`. Beleg: `testClickOpensAndMarks` und bestehende `MacDetailClickTests`, `StartScreenInteractionTests` grün.
- [x] **AC-8:** ⌘N, ⌘, und das Rechtsklick-Menü der Zeile bleiben wirksam und sind belegt. Beleg: `testShortcutsAndContextMenu` grün.
- [ ] **AC-9:** iPhone und iPad bleiben unverändert: alle neuen Zweige hängen hinter `#if os(macOS)`. Beleg: Diff (iOS-Zweige von `TaskListView` und `WideListRow` ungeändert); iOS-UI-Smoke und voller Unit-Lauf grün; iPhone-Bild vorher/nachher gleich.
- [x] **AC-10:** Kein neuer AppStorage-Schlüssel, kein Modell-, Schema- oder Rechte-Eingriff, keine neue Abhängigkeit. Beleg: Diff.

## Dialog

Dritter Durchgang. Vorgänger: Runde a BROKEN (F001 Leertaste in Done/New/Parked, F002 Scrollen, F003 Modifikatoren; behoben), Runde b AMBIGUOUS (CI-Belege fehlten).

### Runde 1
**Adversary:**
Beweislage aus dem CI-Lauf 39559352169 (Commit f4e4af2), im Log `ci-mac-gallery-run3.log` selbst nachgelesen:
- Job „Mac Gallery (macOS)": `MacGalleryTests` 13 Tests, 0 Fehler (Log-Zeile 775). `MacDetailClickTests` 9 Tests, 0 Fehler (Zeile 1456). `MacKeyboardTests` 7 Tests, 1 Fehler (Zeile 1465): grün sind `testArrowsSelectAndSpaceCompletes`, `testDeleteAsksFirst`, `testSelectionPhotoDark`, `testSelectionPhotoLight`, `testShortcutsAndContextMenu`, `testTextFocusKeepsKeys` (Zeilen 1458-1464); rot ist `testClickOpensAndMarks` (Zeile 1459: „The opened row should be marked on the way back: [] of 3 rows"). Der macOS-Zweig kompiliert also, jedoch nur im Stand f4e4af2, ohne den neuen Merker.
- Job „Unit Tests (macOS destination)": FAILURE im Schritt „Script tests", alle Schritte danach übersprungen. Die Ursache ist im Log nicht abrufbar (Lauf läuft noch); die Anmerkungen zeigen nur den board.py-Usage-Text. Gegenprobe lokal: alle Skript-Tests im Arbeitsordner (unittest discover in scripts): 209 Tests OK, also auch `scripts/test_ci_xcode27.py` mit der neuen ci.yml (ein `-only-testing` je Schritt). Das erklärt den roten Schritt plausibel (zwei `-only-testing` im Klick-Schritt), beweist es aber nicht; die CI muss es zeigen.
- Job „UI Smoke (iOS Simulator)": seit 07:16 UTC „in_progress" im Schritt „Run UI smoke tests"; bei meiner Abfrage ca. 08:05 UTC, also fast 50 Minuten; der Lauf insgesamt noch „in_progress". Kein Ergebnis, möglicherweise hängend. AC-9 hat damit keinen UI-Smoke-Beleg.

Fotos geöffnet und beschrieben (CI-Artefakt `MacGallery`, Ordner mg3):
- `mac-gallery-480-selection-light.png`: Fenster „All open, 3 open", helles Papier. Drei Zeilen. Die zweite („Rasen mähen", Tag Garden) liegt auf einem abgerundeten, gedämpft blaugrünen Feld über die ganze Listenbreite, deutlich sichtbar, Titel unverändert. Erste und dritte Zeile ohne Hintergrund. Das ist die Akzent-12-%-Markierung, kein Grau.
- `...-selection-dark.png`: dieselbe Anordnung auf dunklem Grund, die zweite Zeile mit abgerundetem, dunkel blaugrünem Feld, die anderen unmarkiert. Lesbar, Akzent erkennbar.
- `...-1-space-undo-window.png`: nach der Leertaste steht „Rasen mähen" durchgestrichen und grau, rechts „Undo"; die Markierung ist weg, die beiden anderen Zeilen unverändert. Das ist das Rückgängig-Fenster (#32).
- `...-2-before-back.png`: Detail „Rasen mähen" mit Zurück-Pfeil (neben dem Zahnrad), „Looks right" rechts oben.
- `...-3-after-back.png`: die Liste ist zurück, alle drei Zeilen ohne Markierung (kein Feld hinter „Rasen mähen"). Das ist der rote Test sichtbar; `...-hierarchy-after-back.txt` zeigt die drei Zeilen als `taskRow_*`-Buttons ohne „Selected" (die Seitenleistenzeile `viewRow_open` trägt es dagegen), die Auswahl ist also wirklich weg, nicht nur falsch gemalt.

Code-Sichtung des NEUEN Codes (alles unter `#if os(macOS)`, in der CI noch nie kompiliert):
- `ChosenRows` (TaskListView.swift:576-583): `@MainActor private final class` mit `static let shared`. Zugriffe in `detail(_:)` (Zeile 138), `onAppear` (155) und `onChange(of: selectedID)` (182) laufen in View-Closures, die MainActor erben, wie die schon kompilierten Zugriffe auf `@State` und `proxy.scrollTo` daneben. Ich finde keinen Swift-6-Verstoß, kann ihn ohne macOS-Übersetzung aber nicht ausschließen. Der iOS-Build (grün) enthält den Block nicht; der nächste Mac-Lauf kompiliert ihn zum ersten Mal. Ein lokaler Mac-Build war nicht möglich: die Testsperre `/tmp/loose-ends-testlauf.lock` hält eine fremde Sitzung.
- Reihenfolge `onAppear` (Zeilen 152-157): `isShown = true`, dann Wiederherstellen, dann Fokus. `onDisappear` setzt `isShown = false` (158). Erscheinen und Verschwinden sind paarweise, auch bei neu aufgebauter Liste (neue Instanz startet mit `isShown = false`, ihr `onAppear` setzt es). Kein Defekt gefunden.
- Gelöschte oder erledigte Aufgabe: `RowKeyAction.restored` (RowKeyAction.swift:40-42) gibt nur zurück, was in `ids` steht; Unit-Test `aRememberedRowComesBackOnlyWhileShown` (test-green-output.txt Zeile 1032 grün) deckt gesetzt, unbekannt, nil und leere Liste ab. Eine erledigte Aufgabe bleibt im Done-Fenster noch in `rowIDs`, danach nicht mehr: dann `nil`. Kein Defekt.
- Schlüssel `ViewSelection` (Hashable, ViewSelection.swift:6): je Liste ein Eintrag, Ansichten stören sich nicht. Nebenwirkung (LOW, F001): Wählt man eine Zeile, wechselt in der Seitenleiste und kommt zurück, ist die Zeile wieder gewählt, falls sie noch in der Liste steht; die Spec sagt dazu nichts.
- Speicher (LOW, F002): `byList` wächst höchstens um die Zahl der Kontexte, Projekte und Ansichten, Einträge gelöschter Kontexte bleiben bis zum Appende. Vernachlässigbar.
- `onChange(of: rowIDs)` räumt nur bei `isShown` (Zeile 188). Ein Defekt wäre nur denkbar, wenn `onAppear` nach einem Zurück nicht erneut feuerte: dann bliebe `isShown` falsch und eine erledigte Zeile bliebe als unsichtbare Auswahl stehen. Bei paarweisen Ereignissen nicht der Fall; Beobachtung für den CI-Lauf.
- Der Testname `aRememberedRowComesBackOnlyWhileShown` prüft nur die Mitgliedschaft in `ids`, nicht „while shown" (das ist View-Zustand); nur Benennung, LOW (F003).
- Grenzen: Produktion +222/-12 (Paper +9/-4, TaskListView +160/-8, RowKeyAction +53), 6 Dateien mit `.github/workflows/ci.yml` (Spec nennt 5; die Überschreitung von Dateizahl und 250 Zeilen inkl. Tests hat Henning laut Auftrag am 2026-10-21 per AskUserQuestion bestätigt). AC-10: keine `AppStorage`/`SceneStorage`-Treffer im Diff; `project.yml`, Entitlements, Plists, Modelle und cloudkit unverändert.
- ci.yml: der Tastaturtest hat jetzt einen eigenen Schritt mit `!cancelled()` und eigenem `MacKeyboard.xcresult`; Export und Upload kennen das Bündel (Zeilen 435, 473-474); gleiches `-derivedDataPath build/click`, die signierte App bleibt erhalten. Kein Mangel erkennbar, aber nicht in der CI gelaufen.
**Implementierer:** Merker `ChosenRows` plus `RowKeyAction.restored` plus Unterdrückung des Aufräumens hinter dem geöffneten Detail sind der Fix für den roten Test; sim-unit 881 + 10 grün, iOS-Build grün; der Beweis für AC-7 fehlt bis zum nächsten Mac-Lauf.

### Runde 2
**Adversary:**
Frühe Zustimmung nehme ich nicht an; ich habe die Schwachstellen gezielt gesucht:
- Trifft der Fix die Ursache? Die Hierarchie zeigt „keine Zeile gewählt" nach Zurück. Zwei Ursachen sind möglich: (a) die Liste wurde neu aufgebaut und `selectedID` ging verloren, (b) `onChange(of: rowIDs)` räumte hinter dem Detail ab. Der Fix deckt beide ab (Merker und `isShown`-Wache). Nicht abgedeckt ist eine dritte: `onAppear` der Liste feuert nach Zurück nicht (Liste bleibt als Instanz erhalten) UND `selectedID` wurde durch etwas anderes genullt; dann bliebe der Merker ungenutzt. Das schließt das Foto allein nicht aus; deshalb AMBIGUOUS für AC-7.
- Was `testClickOpensAndMarks` im neuen Stand voraussetzt: `selectedRows(in:)` (Zeilen mit `isSelected`, MacKeyboardTests.swift:111-113) ist nach Zurück genau `[ids[1]]`. Bei Misserfolg hängt der Test `mac-gallery-480-hierarchy-after-back` an (Zeilen 206-212), das hilft der Diagnose.
- AC-6-Wortlaut: Die Spec sagt „Suchfeld"; die Liste hat keins, der Test nimmt das Eingabefeld der Neuaufnahme (⌘N) und weist nach, dass ⌫ ein Zeichen im Feld löscht, kein Undo-Fenster und keine Rückfrage erscheinen und alle drei Aufgaben bleiben. Der Sinn des AC ist belegt; der Wortlaut ist in der Spec nachzuziehen (LOW, F004).
- AC-4 „zurückholen": Der Test klickt „Undo" nicht an. Belegt ist, dass die Leertaste nur `actions.complete(task)` ruft (TaskListView.swift:209-211), das Foto das Undo-Fenster mit Schaltfläche zeigt und die Zeile erst nach Ablauf verschwindet. Das Zurückholen selbst ist der bestehende Pfad (#32), nicht neu; ausreichend.
- Doppeltes Einplanen: Zeile 209 prüft `actions.isPending`. Leertaste in Done/New/Parked: `spaceCompletes` (RowKeyAction.swift:47-52), Unit-Tests grün.
- Modifikatoren: Wache in Zeile 161 und `bareKey` (223-225) für die Fallbacks `onMoveCommand` und `onDeleteCommand`; ⌘⌫ und ⌥↓ ziehen nichts.
- Teilbeleg AC-9: Unter iOS liefert `keyed` nur `list` (Zeilen 191-193), `isChosen` liefert `false` (124-129), `WideListRow` bekommt `selected`, die iOS-Variante verwendet es nicht (Paper.swift). Voller Unit-Lauf grün (test-green-output.txt „Unit-Tests bestanden"). Offen: iOS-UI-Smoke (CI läuft oder hängt) und iPhone-Bild vorher/nachher fehlt im Artefaktordner.
**Implementierer:** Die dritte Ursache ist die offene Frage; der nächste Mac-Lauf klärt sie.

## Bestätigungen und Befunde

Confirmation:
  AC: AC-1
  Code reference: Shared/Models/RowKeyAction.swift:19
  Evidence: `resolve` ist reine Funktion (nur Foundation) und folgt der Tabelle; `RowKeyActionTests` in sim-unit grün (docs/artifacts/feat-480-mac-tastatur-zeiger/test-green-output.txt, 881 + 10 Tests, 0 Fehler).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/TaskListView.swift:198
  Evidence: `handle(_:)` führt `.select` aus; CI-Lauf 39559352169 Log-Zeile 1458: `testArrowsSelectAndSpaceCompletes` grün (↓ erste, ↓ zweite, ↑ erste, ↓ zweite, jeweils über `isSelected` geprüft; Ränder per `RowKeyActionTests`).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Views/Paper.swift:138
  Evidence: `selected` ergibt `Color.accentColor.opacity(0.12)`, sonst Hover `Color.primary.opacity(0.07)`, Akzent gewinnt (if / else if); Fotos hell und dunkel geöffnet und oben beschrieben, `testSelectionPhotoLight` und `testSelectionPhotoDark` grün (Zeilen 1461-1462).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/TaskListView.swift:207
  Evidence: `.complete` ruft nur `actions.complete(task)` nach der `isPending`-Prüfung; `testArrowsSelectAndSpaceCompletes` grün inkl. Undo-Kennung der gewählten Zeile; Foto `-1-space-undo-window` zeigt „Undo".
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/TaskListView.swift:212
  Evidence: `.delete` setzt nur `pendingDelete` und `confirmingDelete`; `testDeleteAsksFirst` grün (Zeile 1460): Rückfrage, Escape löscht nichts, zweiter Versuch mit „Delete" löscht genau die gewählte Zeile.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Views/TaskListView.swift:160
  Evidence: `onKeyPress` am fokussierten Listenkörper; `testTextFocusKeepsKeys` grün (Zeile 1464) mit dem Eingabefeld der Neuaufnahme statt Suchfeld (die Liste hat keins, siehe F004); `RowKeyActionTests` Textfokus-Fälle grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEndsUITests/MacKeyboardTests.swift:220
  Evidence: `testShortcutsAndContextMenu` grün (Log-Zeile 1463): ⌘N öffnet die Neuaufnahme, ⌘, das Einstellungsfenster, Rechtsklick das Zeilenmenü mit Delete; kein Produktcode dafür geändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Views/Paper.swift:36
  Evidence: Diff gegen die Basis: nur Paper, TaskListView, RowKeyAction, Tests, ci.yml; keine AppStorage/SceneStorage-Treffer, project.yml, Entitlements, Plists, Modelle und cloudkit unverändert, keine neue Abhängigkeit.
  Status: CONFIRMED

Finding:
  ID: F005
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Views/TaskListView.swift:152
  Description: Nach „Zurück" aus dem Detail stellt die Liste die Auswahl über `ChosenRows` im `onAppear` wieder her; dieser Pfad ist neu und lief noch in keinem CI-Lauf (der letzte Lauf zeigte `testClickOpensAndMarks` rot, Log-Zeile 1459, Foto `-3-after-back` ohne Markierung).
  Spec requirement: AC-7 — Klick öffnet und markiert die Zeile; Beleg `testClickOpensAndMarks` grün.
  Conflict: Beleg fehlt, kein bewiesener Defekt im Code. Status AMBIGUOUS, nicht BROKEN.
  Remediation: Nächsten Mac-Lauf abwarten; Erwartung siehe Verdict.

Finding:
  ID: F006
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Views/TaskListView.swift:191
  Description: Der iOS-Zweig ist unverändert (nur `list`), `isChosen` ist unter iOS `false`, `WideListRow` nutzt `selected` unter iOS nicht; der iOS-UI-Smoke des Laufs 39559352169 ist nach fast 50 Minuten nicht fertig (Schritt „Run UI smoke tests" in_progress), und ein iPhone-Bild vorher/nachher liegt nicht im Artefaktordner.
  Spec requirement: AC-9 — iOS-UI-Smoke und voller Unit-Lauf grün; iPhone-Bild vorher/nachher gleich.
  Conflict: Unit grün und Diff sauber, aber zwei verlangte Belege (UI-Smoke, Bild) fehlen. AMBIGUOUS.
  Remediation: UI-Smoke im nächsten Lauf grün abwarten (hängt er, Lauf neu anstoßen); iPhone-Bild im Simulator vorher/nachher ablegen und beschreiben.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/TaskListView.swift:155
  Description: Der Merker gilt je `ViewSelection` auch nach Wechsel der Ansicht und zurück: die Zeile ist dann wieder gewählt, solange sie in der Liste steht.
  Spec requirement: AC-7 — die Spec schweigt zu diesem Fall.
  Conflict: Keiner; das Verhalten ist plausibel, nur nicht beschrieben.
  Remediation: In der Spec ergänzen oder bei Ansichtswechsel leeren.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/Views/TaskListView.swift:580
  Description: `byList` wird nie bereinigt; Einträge gelöschter Kontexte oder Projekte bleiben bis zum Appende. Das Wachstum ist durch die Zahl der Listen begrenzt.
  Spec requirement: AC-10 — keine neue Persistenz (erfüllt, nur im Speicher).
  Conflict: Keiner.
  Remediation: Keine nötig.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsTests/RowKeyActionTests.swift:104
  Description: Der Test `aRememberedRowComesBackOnlyWhileShown` prüft nur die Mitgliedschaft in `ids`, der Name verspricht „while shown".
  Spec requirement: AC-1 — Beleg der Zuordnung.
  Conflict: Nur Benennung.
  Remediation: Umbenennen in `aRememberedRowComesBackOnlyWhileItIsStillListed`.

Finding:
  ID: F004
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEndsUITests/MacKeyboardTests.swift:160
  Description: AC-6 nennt „Suchfeld", die Liste hat keins; der Test nutzt das Eingabefeld der Neuaufnahme.
  Spec requirement: AC-6 — Textfokus verschluckt Leertaste und ⌫.
  Conflict: Nur Wortlaut; der Sinn ist belegt.
  Remediation: Spec-Wortlaut anpassen („Textfeld").

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Die neuen Zustandsfelder des Schnitts, von Hand geprüft:

| Feld | Produktions-Schreibstellen | Bedingung davor | Test für diesen Weg |
|---|---|---|---|
| `selectedID` (TaskListView.swift:37) | `handle(.select)` Zeile 206, `detail().onAppear` 139, `onAppear` der Liste 155, `onChange(of: rowIDs)` 188 | Pfeiltaste bei Listenfokus ohne Modifikator; Detail erscheint; Liste erscheint (aus dem Merker); Zeile verlässt die Liste bei `isShown` | `testArrowsSelectAndSpaceCompletes` (Pfeile und Verschwinden der Zeile nach der Undo-Frist, in der CI grün); `testClickOpensAndMarks` (Detail und Zurück, in der CI rot im Stand f4e4af2, Fix noch ungelaufen) |
| `ChosenRows.byList` (TaskListView.swift:580) | `detail().onAppear` 138, `onChange(of: selectedID)` 182 | Detail geöffnet oder Auswahl geändert | `aRememberedRowComesBackOnlyWhileShown` (nur die reine Regel `restored`); der Weg Detail, Zurück, Merker ist nur durch `testClickOpensAndMarks` belegt, im neuen Stand ungelaufen (F005) |
| `isShown` (TaskListView.swift:40) | `onAppear` 154, `onDisappear` 158 | Liste erscheint oder verschwindet (auch hinter geöffnetem Detail) | keiner direkt; nur mittelbar über `testClickOpensAndMarks` (F005) |

## Verdict

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review / next CI run):
  F005: AC-7 Auswahl nach Zurück, Fix noch nicht in der CI gelaufen
  F006: AC-9 iOS-UI-Smoke ohne Ergebnis (Lauf 39559352169 hängt im Schritt „Run UI smoke tests"), iPhone-Bild fehlt

Proven points: 8/10 (AC-1, 2, 3, 4, 5, 6, 8, 10)
Tests: sim-unit 881 + 10 bestanden, 0 fehlgeschlagen; CI Mac: MacGallery 13/13, MacDetailClick 9/9, MacKeyboard 6/7 (testClickOpensAndMarks rot im Stand f4e4af2); Skript-Tests lokal 209 OK; 0 übersprungen bei den Mac-Läufen
Recommendation: Nächsten CI-Lauf abwarten. Erwartung: Schritt „Script tests" grün; „Run the click test in the sandbox (#544)" 9/9 grün; NEUER Schritt „Run the keyboard test in the sandbox (#480)" 7/7 grün, insbesondere `testClickOpensAndMarks` (nach Klick und Zurück genau die `taskRow_` der zweiten Zeile selected; Foto `mac-gallery-480-3-after-back` mit Akzentfeld hinter „Rasen mähen"); der macOS-Zweig kompiliert mit `ChosenRows` ohne Concurrency-Fehler; Artefakt `MacGalleryResults` enthält MacKeyboard.xcresult; „UI Smoke (iOS Simulator)" beendet und grün; „Unit Tests (macOS destination)" läuft über die Skript-Tests hinaus. Bleibt `testClickOpensAndMarks` rot, den Anhang `mac-gallery-480-hierarchy-after-back` prüfen; feuert `onAppear` nach Zurück nicht (dritte Ursache, Runde 2), den Merker beim Verschwinden des Details (`detail().onDisappear`) setzen und die Liste daraus wiederherstellen.

## Geprüfte Dateien

- sha256:8d6a48f99ceacdd377375a07f4b6aa29f0938b97fb95475a1662cb626aaa6b82  LooseEnds/Views/Paper.swift
- sha256:6ca1156a77b7a4c8815e9056cc1c4f5c1c3b15f0786fe61f106bb92a7964097d  LooseEnds/Views/TaskListView.swift
- sha256:75323168a8dbbea02421751894a854eb665d7450edf201be10722e31f9c204e7  LooseEndsTests/RowKeyActionTests.swift
- sha256:b4fb2c88f44f34fe0d027c7ba925e63f78d80714c33bb5677ea3399bb885b21a  LooseEndsUITests/MacKeyboardTests.swift
- sha256:dc4945bc91b4bf3e090aeffe06e9ace374d47114abe6f68b9119ae7ba88c8217  Shared/Models/RowKeyAction.swift

## Prüfbasis

- base: 3021c4f649d4fdf507c673676a1e27a64552e8ee
- blob:98c4c27f8cf604fe7ef65b90fd94138eea5a7a18  LooseEnds/Views/Paper.swift
- blob:fd79e7639e76850c2a451e3daf8f341ed0073538  LooseEnds/Views/TaskListView.swift
- blob:cfa27597922a175c1468ea3cb00d3eee12c79fa1  LooseEndsTests/RowKeyActionTests.swift
- blob:a58c6e7f63bee9851bcb1d30400d9d42f4df2fcc  LooseEndsUITests/MacKeyboardTests.swift
- blob:47c3ff1463af0a11914b3dd90e2315e1db3c7395  Shared/Models/RowKeyAction.swift
