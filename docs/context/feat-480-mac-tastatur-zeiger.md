# Context: feat-480-mac-tastatur-zeiger

## Request Summary
#480 (Epic #467): Die Mac-App bekommt Tastatur und Zeiger wie im freigegebenen Entwurf (Tafel „Grundlagen“,
Abschnitt „Zeiger und Tastatur“, `docs/project/03-design-briefing.md:267`). Soll laut Ticket:
⌘N, ⌘, Einstellungen, Leertaste erledigt die gewählte Zeile (mit Rückgängig-Fenster, #32), ⌫ löscht nach Rückfrage,
Rechtsklick-Menü, Hover Grau 7 %, Auswahl Akzent 12 %, Fenster mindestens 760 × 520 pt.

## Stand im Code (was schon da ist)
| Punkt | Stand | Stelle |
|---|---|---|
| ⌘N | da: Toolbar-Knopf mit `keyboardShortcut("n")`, auf der Startseite ins Feld (`startFocusRequest`), sonst Sheet | `LooseEnds/App/ContentView.swift:158-165` |
| ⌘, | da: `Settings`-Szene bringt ⌘, und App-Menü-Eintrag selbst; Zahnrad ist `SettingsLink` | `LooseEnds/App/LooseEndsApp.swift:116`, `ContentView.swift:171` |
| Rechtsklick | da: `.contextMenu { actions.menu(task) }` in Liste, Projektzeilen, Startseite „Jetzt“, Seitenleiste | `TaskListView.swift:284,379`, `StartPage.swift:134`, `TaskInteractions.swift:47` |
| Hover 7 % | da, aber nur in `WideListRow` (Listen); Startseite „Jetzt“ nutzt `.startRow`/`.paperRow`, nicht `wideListRow` | `Paper.swift:117-153` |
| Fenster-Startgröße | da: `defaultSize(1200 × 780)`; **keine Mindestgröße** | `LooseEndsApp.swift:113` |

## Was fehlt
- **Zeilenauswahl.** Die `List`en haben kein `selection:`. Zeilen sind `NavigationLink` (Projektansicht) oder `Button` (Startseite) mit
  Swipe-Aktionen. Ohne gewählte Zeile gibt es kein Ziel für Leertaste und ⌫, und keinen Akzent-12-%-Zustand.
- **Leertaste → erledigen**, über `TaskInteractions.complete(_:)` (`TaskInteractions.swift:150`), das das Rückgängig-Fenster (#32, `PendingCompletions`) schon bedient.
- **⌫ → löschen mit Rückfrage**, über `pendingDelete`/`confirmingDelete` (`TaskInteractions.swift:20,140,216`, `confirmationDialog("Delete this task?")`).
- **Auswahl in Akzent 12 %.**
- **Mindestgröße 760 × 520 pt** (Szene oder `.frame(minWidth:minHeight:)` am `ContentView`, nur macOS).
- Hover auf den „Jetzt“-Zeilen der Startseite (Ticket: „Hover in Grau 7 %“, DoD „in Liste und Startseite“).

## Existing Patterns
- Reine Logik als Wert-Typ mit Unit-Test (`ViewRules`, `DueReminders`, `ListeningHint`): Taste → Aktion passt dorthin (DoD-Punkt 3).
- Alles Mac-Spezifische mit `#if os(macOS)`; `Shared/` kompiliert auch für Watch/Widgets, SwiftUI-Tasten bleiben in `LooseEnds/Views`.
- Mac-UI-Tests: `MacUITestSupport.swift` (Präfix `mac`), `MacDetailClickTests` in der Sandbox der echten App; Galerie `MacGalleryTests`.
- Farbbudget: Akzent = antippbar/Auswahl, Grau = Hierarchie (CLAUDE.md).

## Dependencies / Dependents
- Upstream: `TaskInteractions`, `PendingCompletions`, `CompletionPulse`, `ViewRules`, `Paper` (`WideListRow`, `paperRow`, `startRow`).
- Downstream: dieselben Views laufen auf iPhone/iPad; jede Änderung an `List`/Zeilen muss dort unverändert bleiben (nur `#if os(macOS)`).

## Existing Specs / Entwurf
- Entwurf: `docs/artifacts/feat-408-mac-entwurf/Grundlagen.dc.html` (Zeilen 39-45), Briefing `docs/project/03-design-briefing.md:258-267`.
- Keine Entity-Spec; Spec entsteht in `/30-write-spec`.

## Risks & Considerations
- **Textfokus:** Leertaste und ⌫ dürfen nur ohne Textfokus wirken (Aufnahmefeld der Startseite, Notiz, Suche). `onKeyPress` an der Liste feuert nur bei Listenfokus; zu prüfen, ob das reicht.
- **`List(selection:)` mit `NavigationLink`/Button-Zeilen** ändert Klickverhalten (Auswahl statt Navigation?) — Gefahr für `MacDetailClickTests` und `StartScreenInteractionTests`. Alternative: eigener Fokus-Zustand statt Systemauswahl.
- **Kollision:** ⌫ im Detail oder in Textfeldern; ⌘N-Doppelbelegung (Toolbar + evtl. neuer Menüeintrag) vermeiden.
- **Geräteliste:** kein Pfad berührt (nur `LooseEnds/Views`, `LooseEnds/App`) → Abnahme endet nach Stufe 2 (Simulator reicht für iOS-Regression; Mac über CI-Galerie/UI-Tests).
- **#593** (Mac-UI-Tests: Fenster breiter als CI-Bildschirm): Eine Mindestgröße von 760 × 520 passt auf 1024 pt; die neue Tastatur-Test sollte Fenster zoomen wie `MacDetailClickTests` (seit #591), nicht #593 lösen.
- Umfang: voraussichtlich 5-6 Dateien (`TaskListView`, `StartPage`, `Paper`, `LooseEndsApp`/`ContentView`, neue reine Zuordnung + Test); Limit 250 LoC im Blick, sonst Schnitt.

## Analysis

### Type
Feature (Mac-Verhalten, Epic #467). Entwurf liegt freigegeben vor (Tafel „Grundlagen“); keine neue Gestaltung, nur der Auswahlzustand in Akzent 12 % — daher keine neue Vorschau nötig.

### Recherche (vor der Analyse)
- Apple-Foren: auf macOS wirkt `onKeyPress` nur an fokussierbaren Views; `onDeleteCommand` an `List` ist unzuverlässig (Menü aktiv, Taste ohne Wirkung, Thread 667366). Zu Leertaste und `NavigationLink`-Zeilen mit `List(selection:)` fand sich keine belastbare Quelle.
- Quellen: developer.apple.com/forums/thread/667366, /thread/772806, danielsaidi.com/blog/2023/12/20/quick-search-with-swiftui-searchable.
- Konsequenz: `onKeyPress` am fokussierbaren Listenkörper, im Simulator/Mac-UI-Test belegen, nicht annehmen.

### Entscheidung des PO (2026-10-20)
Pfeiltasten wählen, Klick öffnet wie bisher (und markiert die Zeile). Verworfene Alternative: Klick wählt, Doppelklick öffnet (Finder) — änderte das Öffnen und `MacDetailClickTests`.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| Shared/Models/RowKeyAction.swift (oder LooseEnds/Views) | CREATE | Reine Zuordnung Taste → Aktion (↑ ↓ Leertaste ⌫), nur wirksam ohne Textfokus; Unit-testbar |
| LooseEnds/Views/TaskListView.swift | MODIFY | `selectedID`, Listenkörper fokussierbar, `onKeyPress`, Zeilenmarkierung Akzent 12 % (nur macOS) |
| LooseEnds/Views/StartPage.swift | MODIFY | dasselbe für die „Jetzt“-Zeilen; Hover Grau 7 % dort |
| LooseEnds/Views/Paper.swift | MODIFY | Hover/Auswahl-Hintergrund als gemeinsamer Baustein (`WideListRow`, `startRow`) |
| LooseEnds/App/LooseEndsApp.swift | MODIFY | `.frame(minWidth: 760, minHeight: 520)` am Inhalt (nur macOS) |
| LooseEndsTests/RowKeyActionTests.swift | CREATE | Unit-Test der Zuordnung |
| LooseEndsUITests/MacKeyboardTests.swift | CREATE | Mac-UI-Test: ↓, Leertaste → Rückgängig-Fenster, ⌫ → Rückfrage |

### Scope Assessment
- Files: 7 (2 neu Test, 1 neu Logik) — an der Grenze der 4–5-Dateien-Regel; Schnitt: Schnitt 1 Logik + Liste + Mindestgröße, Schnitt 2 Startseite + Hover dort, falls das Limit reißt.
- Estimated LoC: ca. +230/-10 mit Tests
- Risk Level: MEDIUM (Fokus/Tastatur auf Mac, Kollision mit Texteingabe; Änderungen nur unter `#if os(macOS)`, iPhone/iPad unverändert)

### Technical Approach
Rules before model: kein Modell beteiligt (Tastaturlogik ist deterministisch).
1. Eigener Auswahlzustand `selectedID: UUID?` statt `List(selection:)`: so bleibt das `NavigationLink`-/Button-Klickverhalten unverändert.
2. Reine Funktion `RowKeyAction.resolve(key, textFocused:, selection:, ids:)` → `.moveUp/.moveDown/.complete(id)/.delete(id)/.ignore`. Leertaste und ⌫ ohne Textfokus; mit Textfokus `.ignore`.
3. Ausführung über die vorhandenen `TaskInteractions.complete(_:)` (Rückgängig-Fenster #32) und `pendingDelete`/`confirmingDelete` (Rückfrage); keine neue Löschlogik.
4. Markierung: `Color.accentColor.opacity(0.12)` für Auswahl, `Color.primary.opacity(0.07)` für Hover (schon in `WideListRow`), auf die „Jetzt“-Zeilen ausgedehnt.
5. Mindestgröße 760 × 520 am `ContentView` in `WindowGroup` (macOS).
6. ⌘N und ⌘, sind vorhanden (nur im UI-Test belegen); Rechtsklick-Menü ist vorhanden.

Alternative (nicht gewählt): `List(selection:)` mit Systemauswahl — mac-nativ, aber Klick wählt statt öffnet; kippt den Klickweg aus #544 und braucht Umbau der Zeilen.

### Dependencies
`TaskInteractions`, `PendingCompletions`, `Paper`, `StartMetrics`; `MacUITestSupport` für den Test. Keine ADR berührt; keine Gerätelisten-Pfade → Stufe 3 entfällt („Kein Pfad der Geräteliste berührt.“).

### Open Questions
- [x] Auswahlweise (entschieden: Pfeiltasten, Klick öffnet).
- [ ] Wirkt `onKeyPress` für Leertaste/⌫ in einer `List` mit `NavigationLink` verlässlich? Wird in `/40-tdd-red` als Mac-UI-Test zuerst rot gestellt; Rückfall: `onDeleteCommand` bzw. Menübefehle mit `keyboardShortcut`.
- [ ] Pfeiltasten in der Systemliste ohne `selection:` — ggf. Fokus von `List` abgreifen; sonst eigener `onKeyPress`.
