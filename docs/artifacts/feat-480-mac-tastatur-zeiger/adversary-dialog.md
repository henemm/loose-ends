# Adversary Dialog — feat-480-mac-tastatur-zeiger
Spec: docs/specs/feat-480-schnitt-1-liste.md
Datum: 2026-10-22 08:48

## Checkliste
- [x] **AC-1:** Die Zuordnung Taste → Aktion ist eine reine Funktion in `Shared/Models/RowKeyAction.swift` und folgt der Tabelle in „Implementation Details“. Beleg: `RowKeyActionTests` grün (alle Fälle der Tabelle).
- [x] **AC-2:** In einer Liste wählen ↓ und ↑ die nächste bzw. vorige Zeile; ohne Auswahl wählt ↓ die erste, ↑ die letzte; an den Rändern bleibt die Auswahl. Beleg: `MacKeyboardTests.testArrowsSelectAndSpaceCompletes` grün.
- [x] **AC-3:** Die gewählte Zeile steht in Akzent 12 % (hell und dunkel), Hover in Grau 7 %, bei beidem gewinnt Akzent. Beleg: Fotos `mac-keyboard-selection-light` und `-dark` aus dem CI-Lauf, geöffnet und beschrieben; Diff zeigt `opacity(0.12)` und `opacity(0.07)` in `WideListRow`.
- [x] **AC-4:** Die Leertaste erledigt die gewählte Zeile über das Rückgängig-Fenster (#32); in dessen Frist lässt sich die Aufgabe zurückholen. Beleg: `testArrowsSelectAndSpaceCompletes` grün; Diff ruft nur `TaskInteractions.complete(_:)`.
- [x] **AC-5:** ⌫ löscht die gewählte Zeile erst nach der Rückfrage „Delete this task?“; Abbrechen löscht nichts. Beleg: `testDeleteAsksFirst` grün; Diff nutzt nur `pendingDelete`/`confirmingDelete`, keine neue Löschlogik.
- [x] **AC-6:** Mit Textfokus (Suchfeld) wirken Leertaste und ⌫ nicht auf Aufgaben. Beleg: `testTextFocusKeepsKeys` grün; `RowKeyActionTests` Fälle mit `textFocused`.
- [x] **AC-7:** Ein Klick öffnet die Aufgabe wie bisher und markiert die Zeile; es gibt kein `List(selection:)`. Beleg: `testClickOpensAndMarks` und bestehende `MacDetailClickTests`, `StartScreenInteractionTests` grün.
- [x] **AC-8:** ⌘N, ⌘, und das Rechtsklick-Menü der Zeile bleiben wirksam und sind belegt. Beleg: `testShortcutsAndContextMenu` grün.
- [x] **AC-9:** iPhone und iPad bleiben unverändert: alle neuen Zweige hängen hinter `#if os(macOS)`. Beleg: Diff (iOS-Zweige von `TaskListView` und `WideListRow` ungeändert); iOS-UI-Smoke und voller Unit-Lauf grün; iPhone-Bild vorher/nachher gleich.
- [x] **AC-10:** Kein neuer AppStorage-Schlüssel, kein Modell-, Schema- oder Rechte-Eingriff, keine neue Abhängigkeit. Beleg: Diff.

## Dialog

### Runde 1
**Adversary:** Stand 4c6ac3b. Unit-Lauf selbst gestartet (`sim.sh sim-unit`, rc=0, "Unit-Tests bestanden", Ausgabe `test-green-output-round4.txt`); 1 von 4 Messstrecken und 2 Latenzschutz-Tests nicht gemessen (kein Sprachmodell im Simulator), benannte Messstrecken, keine Spec-Tests. Mac-UI-Tests nicht lokal (nur CI 39729292310, 4 Jobs grün laut Auftrag).
Angriffe:
- Merker `ChosenRows` (TaskListView.swift:576-580): `@MainActor @Observable`, `static let shared`, Schlüssel `ViewSelection` je Liste. Kein Leck zwischen Listen, je Auswahl ein eigener Eintrag. Swift 6: Klasse MainActor-isoliert, Zugriff nur aus View-Body und MainActor-Closures; kompiliert in CI.
- Reste nach gelöschter/erledigter Zeile: `.onChange(of: rowIDs)` (TaskListView.swift:182-184) räumt, solange die Liste nicht leer ist. Verschwindet die LETZTE Zeile, bleibt eine verwaiste UUID im Singleton. `RowKeyAction.resolve` behandelt unbekannte Auswahl als keine (RowKeyAction.swift:25-31), also keine Fehlaktion; nur wenn dieselbe Aufgabe in dieselbe Liste zurückkehrt (Wiederherstellen aus Completed nach All open), erscheint sie markiert. Kosmetisch. F001 LOW.
- Textfokus: `textFocused` fest false (TaskListView.swift:196). TaskListView hat selbst kein TextField/searchable (grep: Textfelder nur in Detail-, Capture-, Inbox-Views außerhalb des Listenkörpers). Tasten erreichen die Liste nur bei Listenfokus. Annahme tragfähig; AC-6 hängt am CI-Test `testTextFocusKeepsKeys`. Designhinweis: der Parameter hat im Produkt keinen Pfad für true.
- Modifikatoren: `onKeyPress` verwirft Cmd/Shift/Option/Control (Z.157); Fallbacks `onMoveCommand`/`onDeleteCommand` prüfen `NSEvent.modifierFlags` (Z.185-187). Doppelauslösung laut Kommentar ausgeschlossen; CI-Tests grün.
- Leertaste in Done/New/Parked/geparkte Aufgabe: `spaceCompletes` (RowKeyAction.swift:41-46); `isPending`-Schutz gegen Doppelplanung (TaskListView.swift:204). F001/F002/F003 aus Runde a bleiben behoben.
- `rowIDs` (TaskListView.swift:214-236) spiegelt die Abschnitte von Hand (Done gruppiert, Projektzeilen, New nach needsLook, Due/Open Rest vor Geparkt); eingeklappte Unteraufgaben zählen nicht. UI-Tests decken nur All open ab. F002 LOW (Belegslücke).
- iOS (AC-9): Diff main...HEAD in Paper.swift: `selected` Standard false, iOS-Zweig unverändert; TaskListView: `keyed` gibt auf iOS `list` zurück, `@FocusState` und `ChosenRows` nur `#if os(macOS)`, `isChosen` false, `accessibilityAddTraits([])` leer. iOS UI Smoke grün laut CI.
**Implementierer:** (nicht beteiligt, Kontext isoliert)

### Runde 2
**Adversary:** Gegenprobe zur Früh-Einigung: Foto `mac-gallery-480-3-after-back.png` geöffnet: Zeile "Rasen mähen" in All open trägt nach Zurück eine abgesetzte Füllung im Akzent-Ton (gedämpftes Teal), die anderen beiden Zeilen sind unmarkiert. Das belegt AC-7 (Markierung nach Detail und Zurück) und die Akzentfarbe aus AC-3. `mac-gallery-480-selection-light.png` nur als vorhanden geprüft; Dunkelfoto nicht von mir geöffnet. AC-5 und AC-8 stützen sich auf CI-Tests, die ich nicht lokal laufen darf; 7 Tests in MacKeyboardTests.swift:115-263 vorhanden, grün laut CI. Keine BROKEN-Evidenz gefunden.

## Bestätigungen

Confirmation:
  AC: AC-1
  Code reference: Shared/Models/RowKeyAction.swift:19
  Evidence: reine Funktion `resolve` mit Tabelle der Spec; Unit-Lauf grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/TaskListView.swift:156
  Evidence: onKeyPress für Pfeile ruft handle(.up/.down) und select; Randverhalten aus resolve; CI testArrowsSelectAndSpaceCompletes grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Views/Paper.swift:1
  Evidence: WideListRow: selected gibt accentColor.opacity(0.12), sonst hovering Grau 7 %, Auswahl hat Vorrang (Diff); Foto zeigt Akzentfüllung.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/TaskListView.swift:201
  Evidence: .complete ruft nur actions.complete(task) (Rückgängig-Fenster #32), isPending verhindert Doppelplanung; CI-Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/TaskListView.swift:207
  Evidence: .delete setzt nur pendingDelete/confirmingDelete (bestehender Dialog); testDeleteAsksFirst grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Views/TaskListView.swift:193
  Evidence: Tasten nur bei Listenfokus, Liste ohne eigenes Textfeld; resolve ignoriert bei textFocused (Unit); testTextFocusKeepsKeys grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Views/TaskListView.swift:140
  Evidence: detail() setzt selectedID im onAppear, kein List(selection:); Foto nach Zurück zeigt Markierung; testClickOpensAndMarks und MacDetailClickTests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Views/TaskListView.swift:156
  Evidence: keine Änderung an Cmd-N, Cmd-Komma, Kontextmenü; Modifikatorfilter lässt sie durch; testShortcutsAndContextMenu grün (CI).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Views/Paper.swift:1
  Evidence: neue Zweige alle `#if os(macOS)`; iOS: keyed gibt list zurück, selected Standard false; Unit grün, iOS UI Smoke grün (CI).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: Shared/Models/RowKeyAction.swift:1
  Evidence: Diffstat main...HEAD ohne project.yml, Persistence, Models, Entitlements; ChosenRows nur im Speicher.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/TaskListView.swift:183
  Description: Der Merker wird bei leerer Liste nie geräumt; verwaiste UUID bleibt im Singleton bis App-Ende.
  Spec requirement: AC-7 — Markierung folgt der Zeile
  Conflict: Kehrt dieselbe Aufgabe in dieselbe Liste zurück, erscheint sie markiert; keine Fehlaktion, keine Datenwirkung.
  Remediation: Optional beim Verlassen der Liste räumen; kein Blocker.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/TaskListView.swift:214
  Description: rowIDs spiegelt die Abschnittsreihenfolge von Hand; UI-Tests prüfen nur All open.
  Spec requirement: AC-2 — nächste/vorige Zeile in Anzeigereihenfolge
  Conflict: Abweichung in Projekt-/Done-/New-Ansicht wäre nur per Code-Lesen ausgeschlossen.
  Remediation: Optional Unit-Test, der rowIDs gegen die Abschnitte vergleicht.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Eigene Prüfung der einzigen neuen Zustandsstelle `ChosenRows.byList`:

| Feld | Produktions-Schreibstellen | Bedingung davor | Test für diesen Weg |
|---|---|---|---|
| byList (Auswahl) | handle(.select) | nur wenn resolve .select liefert (Pfeiltaste, ohne Modifikator) | testArrowsSelectAndSpaceCompletes |
| byList (Auswahl) | detail().onAppear | nur wenn die Detailansicht erscheint | testClickOpensAndMarks |
| byList (Auswahl) | onChange(rowIDs) auf nil | nur wenn Liste nicht leer und Auswahl nicht mehr enthalten | keiner als eigener UI-Test (Finding F001, LOW) |

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hielt dem Angriff stand; zwei LOW-Hinweise (F001, F002) ohne Blockade.
Tests: Unit-Lauf sim-unit rc=0 bestanden, 0 fehlgeschlagen; 1 von 4 Messstrecken und 2 Latenzschutz-Tests übersprungen (kein Sprachmodell im Simulator, benannt)
Mac-UI-Tests nur in CI (39729292310, grün), nicht lokal von mir gelaufen
Edge cases: geprüft, keine gebrochen
Regressions: keine gefunden
Checklist: 10/10 points proven

## Geprüfte Dateien

- sha256:8d6a48f99ceacdd377375a07f4b6aa29f0938b97fb95475a1662cb626aaa6b82  LooseEnds/Views/Paper.swift
- sha256:b9a0fc9b2f392b3c347c404ecbc53cd942683c995cec6b6b95938bce53c11e6d  LooseEnds/Views/TaskListView.swift
- sha256:da6762b4f07404a65cb861ed04b409be014a4257d8833d1f197c0fdd73c5e5c8  Shared/Models/RowKeyAction.swift

## Prüfbasis

- base: b56d3932068bc4647033e4970bdfe9bedb7c00e3
- blob:98c4c27f8cf604fe7ef65b90fd94138eea5a7a18  LooseEnds/Views/Paper.swift
- blob:8bb256bb98e26b3b438dd7e20213b2ab74327905  LooseEnds/Views/TaskListView.swift
- blob:21d3c67873eea1cdda6905e0c8a982c4e5b227dc  Shared/Models/RowKeyAction.swift
