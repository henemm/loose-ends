# Context: feat-480-s2-startseite-tasten

## Request Summary
#480 Schnitt 2: Die Tasten und Zeigerzustände aus Schnitt 1 (PR #600) kommen in die „Jetzt“-Zeilen der Mac-Startseite
(Pfeile wählen, Leertaste erledigt mit Rückgängig-Fenster, Rücktaste löscht nach Rückfrage, Auswahl Akzent 12 %, Hover Grau 7 %),
und das Hauptfenster bekommt eine Mindestgröße von 760 × 520 pt. Dieser Schnitt schließt das Ticket (`Closes #480`).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/StartPage.swift` (136 Z.) | `nowRow` baut die „Jetzt“-Zeilen (Button → Detail, Wischen, Kontextmenü, `actions.pendingRow`); hier kommt die Tastenverdrahtung und `wideListRow(selected:)` dazu |
| `LooseEnds/Views/TaskListView.swift` (596 Z.) | Vorbild: `keyed(_:)` (`.focused`, `onKeyPress`, `onMoveCommand`/`onDeleteCommand` als Rückfall, `scrollTo`, Auswahl verwerfen, wenn die Zeile geht), `handle(_:)`, `ChosenRows` (privat, `[ViewSelection: UUID]`) |
| `Shared/Models/RowKeyAction.swift` | Reine Zuordnung Taste → Aktion, unit-getestet; wird unverändert wiederverwendet. `spaceCompletes` kennt `ViewKind?`; die Startseite hat keine Art, „Jetzt“ = `.next` (so nutzt StartPage schon `TaskInteractions(kind: .next)`) |
| `LooseEnds/Views/Paper.swift` | `wideListRow(selected:)` malt Auswahl Akzent 12 % und Hover Grau 7 % |
| `LooseEnds/Views/StartZones.swift` | `NowBlock`: zeigt höchstens 5, „Mehr“ klappt auf (`@State expanded` im Block) → die wählbaren Zeilen hängen vom Aufklappzustand ab |
| `LooseEnds/Views/InboxDrawerView.swift` | Schreibzeile über „Jetzt“ in **derselben** `List` (`@FocusState writing`, ⌘N setzt den Fokus, #472) |
| `LooseEnds/Views/StartMetrics.swift` | `startRow(_:)` Zeilenränder der Startseite |
| `LooseEnds/App/LooseEndsApp.swift` | `WindowGroup(id: "main")` mit `.defaultSize(1200, 780)` (#514); die Mindestgröße gehört hierher bzw. an `ContentView` |
| `LooseEndsUITests/MacKeyboardTests.swift`, `MacUITestSupport.swift` | 7 Mac-Tastaturtests aus Schnitt 1, Helfer `macLaunch`, `macCapture`, `macElement`; laufen im CI-Job „Mac Gallery (macOS)“ in der Sandbox |

## Existing Patterns
- Eigener Auswahlzustand statt `List(selection:)`, damit ein Klick weiter öffnet (#544); Zustand außerhalb der View, weil der Mac die Liste beim Zurück neu baut.
- Tasten nur ohne Modifier; Rückfall-Befehle, falls die Liste die Tasten vor `onKeyPress` nimmt.
- Löschen läuft über `pendingDelete` + `confirmingDelete` und `taskInteractionDialogs` (StartPage hat beides schon).
- Erledigen über `actions.complete(task)` mit Rückgängig-Fenster, nie doppelt bei `isPending`.
- Öffnen eines Tasks markiert seine Zeile (`detail(...).onAppear`).

## Dependencies
- Upstream: `RowKeyAction`, `TaskInteractions`, `ViewRules.now(in:)`, `Paper.wideListRow`, `PendingCompletions`.
- Downstream: Mac-Startseite (Hauptweg), iPad breit nutzt dieselbe `StartPage` (Tasten nur `#if os(macOS)`), `MacGalleryTests`/`MacDetailClickTests` fahren über die Startseite.

## Existing Specs
- `docs/specs/feat-480-schnitt-1-liste.md` — Schnitt 1, Abschnitt „Nicht in diesem Schnitt“ benennt genau diesen Umfang.
- `docs/context/feat-480-mac-tastatur-zeiger.md` — Kontext von Schnitt 1.
- Entwurf: `docs/artifacts/feat-408-mac-entwurf/` (Tafel Grundlagen, „Zeiger und Tastatur“) — bereits freigegeben, kein neuer Entwurf.

## Risks & Considerations
- **Textfokus in derselben Liste:** Die Schreibzeile liegt in der `List` der Startseite. Leertaste/Rücktaste/Pfeile müssen dort beim Feld bleiben. In Schnitt 1 war `textFocused` immer `false`, weil die Liste kein Feld hatte; hier muss der Fokus des Felds (`writing`) oder der Fokus-Ort entscheiden. Zu prüfen: kommen die Tasten bei fokussiertem Feld überhaupt am `onKeyPress` der Liste an?
- **Startfokus:** Schnitt 1 setzt `listFocused = true` beim Erscheinen. Auf der Startseite darf das ⌘N/Schreibzeile (#472) nicht stören.
- **Wählbare Zeilen = sichtbare Zeilen:** `NowBlock` zeigt nur 5, bis „Mehr“ gedrückt ist; die Reihenfolge muss mit `ViewRules.now(in:).all` und dem Aufklappzustand übereinstimmen. Zeilen in der Schublade „Neu“ und die rechte Spalte gehören nicht dazu (Ticket: „Jetzt“-Zeilen).
- **`ChosenRows` ist privat** in `TaskListView`; die Startseite (`selection == nil`) braucht einen eigenen Schlüssel oder einen geteilten Speicher.
- **Mindestgröße vs. Inhalte:** Startseite mit rechter Spalte braucht ~1120 pt (ViewThatFits fällt darunter auf die Liste allein zurück); Detail hat `minWidth 480`. 760 × 520 muss mit Seitenleiste (220) + Inhalt passen; `.windowResizability(.contentMinSize)` oder `frame(minWidth:minHeight:)` am Fensterinhalt.
- Nur Mac; kein Pfad der Geräteliste berührt (`project.yml` bleibt unverändert).

## Analysis

### Type
Feature (Rest von #480; Schnitt 2 schließt das Ticket)

### Recherche
- Ob `onKeyPress` an einer `List` Tasten bekommt, solange ein `TextField` **in derselben Liste** den Fokus hat, ist auf macOS
  nicht dokumentiert (Apple-Forum 779117 fragt genau das, ohne Antwort; `.ignored` reicht eine Taste an den Elternteil weiter).
  Daraus: nicht auf den Vorrang verlassen, `textFocused` ausdrücklich übergeben — `RowKeyAction.resolve` hat den Parameter schon.
- Mindestgröße: `WindowResizability.automatic` = `contentMinSize` für normale Fenster; die Mindestgröße kommt aus
  `.frame(minWidth:minHeight:)` am Fensterinhalt (Apple-Doku `windowResizability(_:)`). Ausdrücklich `.windowResizability(.contentMinSize)`
  setzen, damit es nicht vom Standard abhängt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/StartPage.swift` | MODIFY | Tasten wie `TaskListView.keyed/handle` (nur macOS): `focused`, `onKeyPress` (nackte Tasten), `onMoveCommand`/`onDeleteCommand` als Rückfall, `scrollTo`, Auswahl verwerfen, wenn die Zeile geht; `spaceCompletes(in: .next, …)`; `nowRow` und `pendingRow` bekommen `wideListRow(selected:)` statt eigenem padding/startMetrics/startRow (macht dasselbe plus Hover/Auswahl); Klick setzt die Auswahl im Button selbst (das Detail der Startseite hat kein `onAppear` wie in `TaskListView`) |
| `LooseEnds/Views/TaskListView.swift` | MODIFY | `ChosenRows` nicht mehr `private`, neue Eigenschaft `start: UUID?` (der Schlüssel `ViewSelection` ist nicht optional; die Startseite wird beim Zurück aus dem Detail neu gebaut) |
| `LooseEnds/Views/StartZones.swift` | MODIFY | `NowBlock`: `expanded` von außen steuerbar (Binding mit Standard für den Aufruf in `SidebarView`), damit wählbare Zeilen = sichtbare Zeilen (`expanded ? all : prefix(5)`) |
| `LooseEnds/Views/InboxDrawerView.swift` | MODIFY | meldet den Fokus der Schreibzeile nach außen (Callback aus `onChange(of: writing)`; `@FocusState` lässt sich nicht als Binding reichen) |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | macOS: `.frame(minWidth: 760, minHeight: 520)` am `ContentView`, `.windowResizability(.contentMinSize)` an der Szene |
| `LooseEndsUITests/MacKeyboardTests.swift` | MODIFY | Startseite: Pfeile wählen + Leertaste erledigt mit Rückgängig; Rücktaste fragt; Schreibzeile behält Leertaste/Rücktaste; ⌘N setzt weiter den Cursor in die Schreibzeile; Fenster lässt sich nicht unter 760 × 520 ziehen |

### Scope Assessment
- Files: 5 Produkt + 1 Test (zwei davon nur 2–5 Zeilen: `TaskListView`, `LooseEndsApp`)
- Estimated LoC: Produkt ca. +100/−10, Tests ca. +100 → ~210, unter 250
- Risk Level: MEDIUM — Fokus zwischen Liste und Schreibzeile (⌘N, #472) ist der heikle Teil; alles andere ist erprobtes Muster aus Schnitt 1

### Technical Approach
1. **Fokus:** Die Startseite setzt den Listenfokus **nicht** beim Erscheinen (anders als `TaskListView`), sonst streitet sie mit
   der Schreibzeile und ⌘N (#472). Der Fokus kommt auf die Liste durch Klick auf eine Zeile oder wenn die Schreibzeile ihn
   abgibt. `textFocused` = Fokus der Schreibzeile (Callback), damit Leertaste/Rücktaste/Pfeile dort beim Feld bleiben, egal
   welchen Vorrang macOS den Handlern gibt.
2. **Auswahl:** in `ChosenRows.shared.start`, überlebt das Neubauen der Startseite; Klick auf eine Zeile setzt sie.
3. **Zeilen:** `rowIDs` = sichtbare „Jetzt“-Zeilen in Anzeigereihenfolge (`ViewRules.now(in:).all`, bei zugeklapptem Block nur die ersten 5). Schublade „Neu“ und rechte Spalte gehören nicht dazu.
4. **Optik:** `wideListRow(selected:)` an `nowRow` und am Rückgängig-Zustand; iPad breit bleibt gleich (dieselben 11 pt und Ränder), Hover/Auswahl nur Mac.
5. **Mindestgröße** 760 × 520 wie oben; darunter greift `ViewThatFits` schon heute ab 900 pt (rechte Spalte fällt weg, gewollt).
- Kein neuer Entwurf nötig: Aussehen ist im freigegebenen Entwurf #408 (Tafel Grundlagen, „Zeiger und Tastatur“) festgelegt und in Schnitt 1 umgesetzt.

### Alternative (nicht gewählt)
Die Tastenlogik aus `TaskListView.keyed/handle` als gemeinsamen macOS-`ViewModifier` (`RowKeyboard`: Auswahl-Binding, `rowIDs`,
`textFocused`, `completes`, `onComplete`, `onDelete`) herausziehen und von beiden Listen benutzen. Vorteil: keine Doppelung (~40
Zeilen). Nachteil: baut die eben abgenommene Schnitt-1-Logik um (Regressionsrisiko in allen Mac-Listen) und sprengt mit neuer
Datei + Umbau die 250-LoC-Grenze. Gewählt ist die begrenzte Übernahme; lohnt sich der Modifier, wenn eine dritte Liste Tasten bekommt.

### Dependencies
- Upstream: `RowKeyAction` (unverändert), `TaskInteractions` (`complete`, `isPending`, `pendingRow`, Lösch-Rückfrage), `ViewRules.now(in:)`, `Paper.wideListRow`.
- Downstream: Mac-Startseite, iPad breit (gleiche `StartPage`, Tasten nur `#if os(macOS)`), `SidebarView` (`NowBlock`), `StartScreenInteractionTests` (⌘N, #472), `MacGalleryTests`/`MacDetailClickTests` (Zeilen-IDs `startNowRow_` bleiben).

### Open Questions
- keine PO-Fragen; Aussehen und Verhalten stehen im Ticket und im freigegebenen Entwurf.
- Abnahme: kein Pfad der Geräteliste berührt (`project.yml` unverändert); Mac-Abnahme über TestFlight laut DoD des Tickets.
