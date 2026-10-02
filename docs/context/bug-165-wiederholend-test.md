# Kontext: #165 UI-Test „wiederholende Aufgabe löschen“ rot bzw. nur per Wiederholung grün

## Befund aus dem Issue

`CaptureSmokeTests/testDeletingRecurringTaskAfterCompletionDoesNotCrash` (Regressionstest für #121)
ist lokal rot (Zeile 336, „Should be back at the list with the task visible“) und in der CI nur über
`-retry-tests-on-failure` grün (erster Versuch: „Long press should open the menu with Complete“).

## Reproduktion (2026-10-01)

- `./scripts/sim.sh test CaptureSmokeTests/testDeletingRecurringTaskAfterCompletionDoesNotCrash` →
  `** TEST FAILED **`, Zeile 336. UI-Hierarchie im Fehlermoment: Ansicht „New“, `emptyViewLabel`
  „Nothing here“.
- Bildschirmaufnahme lokal: nach dem Setzen von „Daily“ zeigt das Detail Titel mit KI-Marker,
  Duration 15 min ✦, Energy Medium ✦; danach ist „New“ leer.
- Bildschirmaufnahme CI (Artefakt `UITestResults` von Lauf 36860656065): das lange Drücken öffnet
  das Detail statt des Menüs; `openMenu` drückt danach ins Leere.

## Recherche

- Der iOS-Simulator nutzt die Apple Intelligence des Macs (Kodeco, „Getting Started with Apple's
  Foundation Models“; Apple Developer Forums, Thread 787445). Lokal läuft das Modell also auch im
  UI-Test; die CI-VM hat keins.
- Long-Press auf Zeilen in SwiftUI-Listen ist als Geste empfindlich (Apple Developer Forums,
  Thread 765104); im Projekt bekannt aus #76 und #114.

## Ursachenkette

1. Lokal: `EnrichmentWriter.apply` setzt bei gesetztem Titel `status = .active`
   (`Shared/Enrichment/EnrichmentWriter.swift:34`). Beim Rücksprung aus dem Wiederholungs-Editor
   feuert `TaskDetailView.onAppear` erneut und `markSeen()` quittiert die KI-Revisionen
   (`LooseEnds/Views/TaskDetailView.swift:96-98, 165-168`). Damit greift keine Bedingung von „New“
   (`Shared/Models/ViewRules.swift:16`). Gewolltes Produktverhalten; der Test setzt stillschweigend
   „kein Modell“ voraus.
2. CI: `press(forDuration:)` kommt auf dem langsamen Runner als Tippen an, die Zeile ist ein
   NavigationLink und öffnet das Detail. `openMenu` (`LooseEndsUITests/CaptureSmokeTests.swift:32-42`)
   erkennt das nicht.

Kein App-Fehler. Beide Ursachen liegen im Testaufbau.

## Request Summary
Henning will #165 behoben: der Regressionstest für #121 soll lokal und in der CI beim ersten Versuch
grün sein, damit `sim.sh test-proof CaptureSmokeTests` (#145) als Klasse belegbar ist.

## Related Files
| File | Relevance |
|------|-----------|
| LooseEndsUITests/CaptureSmokeTests.swift | Der betroffene Test (Z. ~300) und `openMenu` (Z. 32-42); einziger zu ändernder Code |
| LooseEnds/Views/SidebarView.swift | Ansichtszeilen mit Kennung `viewRow_<kind>` (Z. 29), Weg zu „Repeating“ |
| LooseEnds/Views/TaskListView.swift | Zeile = NavigationLink + `.contextMenu` auf demselben Element (Z. 100-108) |
| LooseEnds/Views/TaskDetailView.swift | `.onAppear` → `markSeen()` (Z. 96-98) |
| Shared/Models/ViewRules.swift | Bedingungen von „New“ (Z. 16) und „Repeating“ (Z. 32) |
| Shared/Enrichment/EnrichmentWriter.swift | Status `.active`/`.unverified` nach der Veredelung (Z. 34-36) |
| Shared/Services/TaskActions.swift | `complete` rollt Wiederholungen vor, Status bleibt offen |
| .github/workflows/ci.yml | `-retry-tests-on-failure` (Z. 130) verdeckt rote Erstversuche |

## Existing Patterns
- Rückweg zur Sidebar über `app.navigationBars.buttons.firstMatch`, wie in
  `testCompletedTaskShowsUnderCompleted` (Z. ~392-397).
- `openMenu` mit gestaffelten Druckdauern (1,2/1,5/2,0 s) aus #114.

## Dependencies
- Upstream: XCUITest, Kennungen `viewRow_*`, `taskRow_*`, `menuDone`, `menuDelete`, `confirmDeleteButton`.
- Downstream: `openMenu` wird zusätzlich von `testDoneFromMenuEmptiesNew` (Z. 185) und
  `testCompletedTaskShowsUnderCompleted` (Z. 387) benutzt.

## Existing Specs
- `docs/specs/tooling/feat-145-simulator-beleg.md` — Beleg nimmt die Testklasse als Ganzes.
- Keine Spec zu #121 selbst.

## Risks & Considerations
- Das Modell kann auch den Titel umschreiben; eine Suche über `label == "Tabletten nehmen"` ist lokal
  nicht stabil.
- Lokal (mit Modell) und CI (ohne) fahren verschiedene Pfade; der Fix muss in beiden halten.
- Eine Änderung an `openMenu` darf die beiden anderen Aufrufer nicht verändern, solange das Menü beim
  ersten Drücken aufgeht.

## Analysis

### Type
Bug (Testaufbau, kein App-Fehler)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsUITests/CaptureSmokeTests.swift | MODIFY | Test findet die Aufgabe nach dem Setzen der Wiederholung über „Repeating“ und ohne Titelbezug; `openMenu` springt zurück, wenn das Drücken ins Detail navigiert hat |
| docs/project/04-stand.md | MODIFY | Veraltete Prioritätsliste (geschlossene #20, #21, #74) bereinigen |

### Scope Assessment
- Files: 2
- Estimated LoC: +30/-10
- Risk Level: LOW — nur Testcode und Doku, kein Produktpfad

### Technical Approach
1. Nach „Daily“ dreimal zurück (Editor → Detail → Liste → Sidebar, wie in
   `testCompletedTaskShowsUnderCompleted`), dann `viewRow_repeating`. „Repeating“ ist
   `isOpen && repeatRule != nil`; `TaskActions.complete` rollt eine Wiederholung vor, ohne Status oder
   Regel zu ändern — die Aufgabe bleibt durchgehend in der Ansicht.
2. Zeile dort über die Kennung `taskRow_*` suchen, nicht über den Titel: das Modell darf den Titel
   umschreiben (Hinweis Plan-Agent).
3. `openMenu`: nach jedem erfolglosen Drücken prüfen, ob die Zeile verschwunden ist (Detail ist
   offen); dann zurücktippen, auf die Zeile warten, erneut drücken. Greift nur im Fehlerpfad, die
   übrigen Aufrufer (Z. 185, 387) verhalten sich unverändert.

### Alternative (nicht gewählt)
Launch-Argument, das die Veredelung unter `--ui-testing` abschaltet: macht alle UI-Tests
deterministisch, ändert aber den Produktcode und verdeckt den Ablauf, den Henning tatsächlich
bekommt (Aufgabe mit KI-Feldern verlässt „New“). Kippt keine ADR, wäre aber ein eigenes Ticket.

### Nachweis
`./scripts/sim.sh test-proof CaptureSmokeTests` dreimal hintereinander grün, lokal mit aktivem
Modell; erster CI-Versuch grün ohne Wiederholung.

### Open Questions
- keine
