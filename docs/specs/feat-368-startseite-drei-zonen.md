---
entity_id: feat-368-startseite-drei-zonen
type: feature
created: 2026-10-12
updated: 2026-10-12
status: draft
workflow: feat-368-startseite-drei-zonen
---

# Spec: #368 — Startbildschirm iPhone: drei Zonen statt gleich gewichteter Liste (Epic #372)

## Approval

- [ ] Approved (Henning)

Produktentscheidungen (Henning, 2026-10-12, Analyse `docs/context/feat-368-startseite-drei-zonen.md`, Entwurf
`docs/artifacts/feat-368-startseite-drei-zonen/entwurf.html`, Entwurf A freigegeben, B verworfen): „Jetzt“ höchstens fünf
Zeilen mit „N weitere“; Zeitdruck oben, dann vorgemerkt; Chips „Schnell“ zuerst, dann nur Kontexte mit Aufgaben, umbrechend;
„Alle Ansichten“ als graues Zwei-Spalten-Raster; Lieferung in Schnitten (Intake, „go“: drei Schnitte). Der dritte Schnitt lag
schon in der Schätzung über ±250 LoC und ist deshalb vorab in Schnitt 3 (Chips) und Schnitt 4 (Raster) geteilt; Inhalt unverändert.

## Purpose

Der iPhone-Startbildschirm zeigt heute alles gleich gewichtet: einen Satz („2 zum Durchsehen, 2 vorgemerkt“), die Vorschau
„Als nächstes“, die Vorschau „Heute fällig“ (in der dieselbe Aufgabe doppelt stehen kann, #299), danach elf Zeilen Ansichten.
Wer die App öffnet, sieht nicht, was jetzt dran ist. Die Seite bekommt drei Zonen:

1. **Eingangsleiste** (nur bei Neu > 0): eine Akzentfläche mit Zahl, ein Tippziel, öffnet „Neu“. Ersetzt den Satz `lead`.
2. **Block „Jetzt“**: alle überfälligen, heute fälligen und vorgemerkten Aufgaben, **jede einmal**, überfällig zuerst, dann
   heute fällig, dann die übrigen vorgemerkten nach `nextRank`. Höchstens fünf Zeilen, darunter „N weitere“, das an Ort und
   Stelle aufklappt. Ersetzt `nextUpPreview` und `dueTodayPreview`.
3. **„Passt gerade“-Chips** (Schnell, Kontexte mit Aufgaben) und **„Alle Ansichten“** als graues Zwei-Spalten-Raster.

**Rein regelbasiert.** Alles sind Filter und Sortierungen über vorhandene Felder (`dueDate`, `nextRank`, `status`, `isBlocked`,
`duration`, `contexts`); kein Modell beteiligt, kein Prompt, kein Schema, deshalb entfällt die Zeile „Without the model this
fails because …“.

**Ersetzte Entscheidung.** Die #299-Entscheidung „eine Aufgabe in ‚Als nächstes‘ und fällig steht in beiden Listen“ (Henning,
2026-10-11) gilt im Startbereich nicht mehr: „Jetzt“ zeigt jede Aufgabe einmal. Sie gilt unverändert für die Ansichten „Als
nächstes“ und „Fällig“ selbst, für `ViewRules.dueToday` und für den App-Symbol-Zähler `badgeCount` (zählt weiter die
Vereinigung, jede Aufgabe einmal). Der Satz im Design-Briefing wird ersetzt.

**#339 / PR #340.** #339 („Fällig vs. Als nächstes“) geht in Schnitt 1 auf: die dort gesuchte Regel „was gehört zu heute, was
ist vorgemerkt, jede Aufgabe einmal“ ist `ViewRules.now`. PR #340 (`dueToday` ohne `nextRank`) wird nicht gemergt, sondern
geschlossen; `dueToday` bleibt unverändert.

## Source

- **Geändert:** `Shared/Models/ViewRules.swift` (neue reine Regel `now`, Schnitt 1)
- **Neu:** `LooseEndsTests/NowRuleTests.swift` (Schnitt 1)
- **Neu:** `LooseEnds/Views/StartZones.swift` (`InboxBar`, `NowBlock` in Schnitt 2; `FitChips` in Schnitt 3; `AllViewsGrid` in Schnitt 4)
- **Neu:** `LooseEnds/Views/FlowLayout.swift` (umbrechendes `Layout`, Schnitt 3)
- **Geändert:** `LooseEnds/Views/SidebarView.swift` (Schnitt 2 und 3, nur der kompakte Zweig)
- **Geändert:** `LooseEnds/Resources/Localizable.xcstrings`, `LooseEndsUITests/StartScreenInteractionTests.swift`
- **Doku:** `docs/project/02-datenmodell-und-ansichten.md`, `docs/project/03-design-briefing.md`

## Scope

### Geprüfte Ausgangslage (Code)

- `ViewRules.dueToday`: `parent == nil && isOpen && !isBlocked && dueDate < Beginn von morgen`, älteste zuerst.
- `ViewRules.tasks(for: .next)`: `parent == nil && isOpen && nextRank != nil && !isBlocked`, nach `nextRank`.
- Beide schließen Unteraufgaben, erledigte und geparkte (`isOpen` ist `unprocessed || unverified || active`, ohne `parked`
  und `done`) sowie blockierte Aufgaben aus. **„Jetzt“ übernimmt genau diese beiden Mengen als Vereinigung** und sortiert sie um.
- `TaskInteractions` kennt für `.next` und `.due` keine eigenen Zweige (beide laufen in `default`: rechts Complete, links
  Vormerken/Lösen; Menü hängt nur an `nextRank` und Status). Ein Satz Aktionen (`interactions(.next)`) trägt alle Jetzt-Zeilen.
- `previewRow(_:actions:prefix:)` erzeugt `TaskRow(identifierPrefix:)`, Wisch, Menü und `pendingRow` (Rücknahme-Fenster, #32).
  Bisherige Präfixe: `nextUpPreview_`, `dueTodayPreview_`; neu: `nowRow_`.
- `viewRow_<raw>` hängt an `countRow`; `startViews` liefert `.next, .new, .due` immer, `.quick, .old, .waiting, .repeating,
  .parked` nur mit Inhalt. Projekte/Kontexte: `projectsToggle`, `contextsToggle`, `newProjectButton`, `newContextButton`,
  `projectRow_<uuid>`, `contextRow_<uuid>`; `@AppStorage startShowsProjects/startShowsContexts`.
- `TaskRow` färbt Fälligkeit heute/überfällig bereits rot und mit Text. Ein neuer Rotfall entsteht nicht.

### Die vier Lieferungen (je ein PR, je ≤ 5 Dateien, ±250 LoC, Funktionen ≤ 50 Zeilen)

| Datei | Schnitt | Änderung | Beschreibung |
|---|---|---|---|
| `Shared/Models/ViewRules.swift` | 1 | MODIFY | `struct NowTasks` (`overdue`, `today`, `lined`, `all`) und `static func now(in:now:calendar:) -> NowTasks` |
| `LooseEndsTests/NowRuleTests.swift` | 1 | CREATE | Unit-Tests der Regel (Swift Testing, `TestStore`) |
| `docs/project/02-datenmodell-und-ansichten.md` | 1 | MODIFY | Regel „Jetzt“ in die Berechnungsregeln |
| `LooseEnds/Views/StartZones.swift` | 2, 3, 4 | CREATE / MODIFY | S2: `InboxBar`, `NowBlock`; S3: `FitChips`; S4: `AllViewsGrid` |
| `LooseEnds/Views/SidebarView.swift` | 2, 3, 4 | MODIFY | S2: `lead`, `nextUpPreview`, `dueTodayPreview`, `dueActions`, Tag am Header raus; Zonen rein. S3: Chips einhängen. S4: Raster, Projekte/Kontexte-Gruppen im kompakten Zweig |
| `LooseEnds/Resources/Localizable.xcstrings` | 2, 3, 4 | MODIFY | Strings DE/EN (siehe unten) |
| `LooseEndsUITests/StartScreenInteractionTests.swift` | 2, 3, 4 | MODIFY | Kennungen umstellen, neue UI-Tests |
| `docs/project/03-design-briefing.md` | 2 | MODIFY | #299-Satz ersetzen, Startseite beschreiben (Z. 55–72) |
| `LooseEnds/Views/FlowLayout.swift` | 3 | CREATE | `FlowLayout: Layout`, umbrechend |

### Estimated Changes (Schätzung je Schnitt)

| Schnitt | Dateien | LoC |
|---|---|---|
| 1 Regel | 3 (ViewRules, NowRuleTests, Doku 02) | ca. +35 ViewRules, +115 Tests, +8 Doku = **+158 / −0** |
| 2 Eingangsleiste und „Jetzt“ | 5 (StartZones, SidebarView, Localizable, StartScreenInteractionTests, Doku 03) | ca. +125 StartZones, +30/−75 SidebarView, +12/−8 Strings, +70/−12 UI-Tests, +6/−4 Doku = **ca. +243 / −99, gezählt ±245** (Grenze) |
| 3 Chips „Passt gerade“ | 5 (StartZones, FlowLayout, SidebarView, Localizable, StartScreenInteractionTests) | ca. +50 StartZones, +35 FlowLayout, +10 SidebarView, +4 Strings, +30 UI-Tests = **ca. +130** |
| 4 Raster „Alle Ansichten“ | 4 (StartZones, SidebarView, Localizable, StartScreenInteractionTests) | ca. +65 StartZones, +35/−35 SidebarView, +6 Strings, +35 UI-Tests = **ca. +140 / −35** |

Gesamt: 9 verschiedene Dateien, ca. +670 / −135 über vier PRs.

Grenzfall (ausdrücklich): Schnitt 2 liegt an der Grenze; wird sie beim Bau überschritten (Zählung am Diff), wandert die Doku 03
nach Schnitt 4. Kein stilles Überschreiten.

**Geräteliste (CLAUDE.md, Stufe 3) berührt: nein.** Keine Datei aus `Shared/Enrichment/FoundationModelsEnricher.swift`,
`EnrichmentCoordinator.swift`, `Shared/Persistence/`, `LooseEndsWatch/`, `LooseEndsWidgets/`, `LooseEndsShare/`,
`Shared/Intents/`, `LooseEnds/Speech/`, `LooseEnds/Notifications/`, `project.yml`, `*.entitlements`, `Info.plist`. Die Abnahme
endet nach Stufe 2; der Abschlussbericht jedes Schnitts enthält den Satz „Kein Pfad der Geräteliste berührt.“

Side-Effects (explizit): keine neuen Berechtigungen, **keine neuen AppStorage-Schlüssel** (`startShowsProjects/Contexts`
bleiben, ihr Wert behält die Bedeutung), kein Modellfeld, kein CloudKit-Schema (`mac-schema-init` entfällt), keine Audio-Dateien,
keine Änderung an Widgets, Watch, Intents, Benachrichtigungen. `DueNotificationCenter` und `badgeCount` unverändert.
iPad und Mac (`!isCompact`) behalten die Seitenleiste unverändert.

## Implementation Details

### Schnitt 1: Regel „Jetzt“

`ViewRules.now(in:now:calendar:)` liefert eine `NowTasks`-Struktur:

- Grundmenge: Vereinigung aus `dueToday(in:now:calendar:)` und `tasks(for: .next, in:now:calendar:)`, nach `id` dedupliziert.
  Damit gelten Unteraufgaben, Erledigtes, Geparktes und Blockiertes als draußen, ohne die Bedingungen zu duplizieren.
- `overdue`: `dueDate` vor Beginn des heutigen Tages (Kalendertag, nicht Uhrzeit), älteste zuerst. Eine Aufgabe von heute 09:00
  bei jetzt 10:00 ist „heute fällig“, nicht „überfällig“.
- `today`: `dueDate` an diesem Tag, früheste Uhrzeit zuerst.
- `lined`: der Rest (hat `nextRank`, ist weder überfällig noch heute fällig), nach `nextRank`. Eine vorgemerkte Aufgabe, die
  zugleich überfällig oder heute fällig ist, steht in `overdue`/`today` (Zeitdruck gewinnt, PO-Entscheidung).
- `all` = `overdue + today + lined`. Gleiche Fälligkeit: Reihenfolge nach `nextRank` (ohne Rang zuletzt), dann `capturedAt`.

`dueToday`, `badgeCount`, `tasks(for:)` bleiben **unverändert**. Doku 02: eine Zeile „Jetzt (nur Startbildschirm iPhone)“.

### Schnitt 2: Eingangsleiste und „Jetzt“

`StartZones.swift`:

- `InboxBar(count:)`: eine Zeile, Symbol `tray` (SF Symbol, outline), Text „N zum Durchsehen“ / „N to look over“, Chevron
  `chevron.right`, Akzent als Schrift und als flache Tönung (`Color.accentColor.opacity(0.12)`), da tippbar (ADR-14). In
  `SidebarView` als einzelne List-Zeile mit `.tag(ViewSelection.system(.new))`, `.accessibilityIdentifier("inboxBar")`,
  `.paperRow()`. Nur bei `ViewRules.tasks(for: .new, in:).count > 0`. Der Kopf (Datum mit Knoten, `startHeader`) bleibt, ist
  aber nicht mehr tippbar und trägt keinen Satz mehr.
- `NowBlock(now:actions:…)`: Überschrift „Jetzt“ (kleine graue Überschrift wie `caption`), darunter `now.all.prefix(5)`; ist
  `all.count > 5`, eine Zeile „N weitere“ (`nowMore`, Button, `.buttonStyle(.plain)`, grau mit Chevron), die `@State expanded`
  umschaltet: danach alle Zeilen und die Zeile „Weniger anzeigen“ (gleiche Kennung `nowMore`). Der Zustand ist nur lokal und
  wird nicht gespeichert. Sinkt `all.count` auf ≤ 5, verschwindet die Zeile.
- Zeilen über die bestehende `previewRow` mit `prefix: "nowRow_"` und `interactions(.next)`; `dueActions` entfällt.
- Leerer Block (`all.isEmpty`): Überschrift „Jetzt“ bleibt, darunter die bisherige graue Zeile „Swipe left on any task to line it
  up here.“ (bestehender Text, hält den Einstieg ins Vormerken). Der Satz „All tied up.“ entfällt mit `lead`.
- Folge der einen Aktionsmenge, bewusst: „Aus Als nächstes entfernen“ auf einer fälligen Zeile lässt sie in „Jetzt“; sie wandert
  nur von `lined` in `today` bzw. `overdue`. Auf einer rein vorgemerkten Zeile verlässt sie den Block.

### Schnitt 3: Chips „Passt gerade“ · Schnitt 4: Raster „Alle Ansichten“

Schnitt 3 liefert `FlowLayout` und `FitChips`, Schnitt 4 `AllViewsGrid` und den Umbau der Gruppen.

- `FlowLayout: Layout` (`FlowLayout.swift`): setzt Unterviews zeilenweise, bricht um, kleine Abstände (`@ScaledMetric`), bis ca.
  40 Zeilen Code; keine Abhängigkeit.
- `FitChips`: Überschrift „Passt gerade“, darunter `FlowLayout` aus Chips. Zuerst „Schnell“ (`chip_quick`, Symbol der Ansicht
  `.quick`, Zahl = `ViewRules.tasks(for: .quick, in:).count`, nur bei ≥ 1), dann je Kontext mit
  `ViewRules.tasks(inContext:in:).count ≥ 1` einen Chip `chip_<uuid>` in `sortOrder`. Die Zahl kommt aus derselben Funktion wie
  die Liste dahinter (`tasks(inContext:)`). Jeder Chip ist ein `Button` mit `.buttonStyle(.plain)`, der `selection = …` setzt
  (mehrere Tippziele in einer List-Zeile). Chip: Kapsel, Akzentschrift (tippbar), Zahl grau. Gibt es keinen Chip, entfällt der
  ganze Block samt Überschrift.
- `AllViewsGrid`: Überschrift „Alle Ansichten“ (grau), Raster aus zwei Spalten (`LazyVGrid`, bei Accessibility-Textgrößen eine
  Spalte). Zellen in dieser Reihenfolge: Als nächstes, Fällig, Neu, Alt, Wartet, Wiederkehrend, Geparkt (nur bei Inhalt),
  Projekte, Kontexte, Alle offenen, Erledigt. Jede Zelle ist ein `Button` mit Symbol (grau), Titel und Zähler; Kennungen
  `viewRow_<raw>` (`next`, `due`, `new`, `old`, `waiting`, `repeating`, `parked`, `open`, `done`), `projectsToggle`,
  `contextsToggle`. Zellen für Ansichten setzen `selection = .system(kind)`. Die Zellen „Projekte“ und „Kontexte“ klappen die
  bisherigen Gruppen (Zeilen `projectRow_`/`contextRow_`, `newProjectButton`, `newContextButton`, Umbenennen/Löschen über
  Kontextmenü und Wisch) darunter auf, gesteuert von `showsProjects`/`showsContexts`. „Schnell“ steht nicht im Raster; seine
  Ansicht erreicht man über den Chip.
- Im kompakten Zweig entfallen die `foldHeader` und die Sektion der letzten zwei Zeilen; die Gruppen Projekte/Kontexte
  erscheinen unter dem Raster. Der nicht kompakte Zweig bleibt wie heute.

### Strings (Localizable.xcstrings, englischer Schlüssel → Deutsch)

Vorhandene Texte geprüft: „Next up“, „Quick“ (Schnell), „Due today“, „Views“, „Swipe left on any task to line it up here.“
bestehen. Neu: `%lld to look over` → „%lld zum Durchsehen“; `Now` → „Jetzt“; `%lld more` → „%lld weitere“; `Show less` →
„Weniger anzeigen“; `Fits now` → „Passt gerade“; `All views` → „Alle Ansichten“. Entfallen (ungenutzt nach Schnitt 2): „All tied
up.“, „Nothing to look over, %lld lined up.“, „%@ to look over, nothing lined up.“, „%@ to look over, %lld lined up.“; „Due today“
entfällt, sofern nichts anderes den Schlüssel nutzt (vor dem Löschen per Suche prüfen).

### Farbe, Schrift, Papier

Rot nur über `TaskRow` (Zeitdruck, mit Text). Akzent nur an Tippbarem: Eingangsleiste, Chips, „N weitere“ nicht (grau,
Hierarchie). Grau: Überschriften, Raster, Zähler. Nur SF Symbols (#350), kein Zeichen als Symbolersatz. `.paperRow()` für jede
Zeile, `.paperList()` bleibt; eine einzige `Section` oben (keine hohen Lücken über Section-Headern). Glyphengrößen und Abstände
über `@ScaledMetric`. Funktionen ≤ 50 Zeilen, deshalb die Zonen als eigene Views in `StartZones.swift`.

## Test Plan

### Automated Tests (TDD RED zuerst)

Unit (Schnitt 1), `LooseEndsTests/NowRuleTests.swift` (Swift Testing, `@Suite`, `@MainActor`, `TestStore`; der Container bleibt in
einer lokalen `let store` am Leben, `now` fix auf Donnerstag 12.03.2026 10:00 Berlin wie in `DueTodayTests`):

- `overdueBeforeTodayBeforeLined`: GIVEN eine überfällige, eine heute fällige und eine nur vorgemerkte Aufgabe WHEN `now(...).all`
  THEN Reihenfolge überfällig, heute, vorgemerkt.
- `lineEachTaskOnce`: GIVEN eine Aufgabe mit `nextRank` und heutigem `dueDate` WHEN `now` THEN sie steht genau einmal in `all`
  (in `today`, nicht in `lined`).
- `overdueAndLinedStaysInTimePressureGroup`: GIVEN vorgemerkt und überfällig WHEN `now` THEN in `overdue`, nicht in `lined`.
- `todayAtEarlierHourIsToday`: GIVEN `dueDate` heute 09:00 bei jetzt 10:00 THEN `today`, nicht `overdue`.
- `linedSortedByRank`: GIVEN drei Vorgemerkte mit Rängen 3, 1, 2 THEN Reihenfolge 1, 2, 3.
- `overdueOldestFirst`: GIVEN zwei Überfällige vor 5 und vor 2 Tagen THEN die ältere zuerst.
- `blockedSubtasksDoneParkedStayOut`: GIVEN je eine blockierte, eine Unter-, eine erledigte und eine geparkte Aufgabe, jede
  fällig heute oder vorgemerkt WHEN `now` THEN keine davon in `all`.
- `futureDueWithoutRankStaysOut`: GIVEN fällig morgen ohne `nextRank` THEN nicht in `all`.
- `emptyInputIsEmpty`: GIVEN `[]` THEN `all` leer.
- `unionMatchesTheTwoSources`: GIVEN eine gemischte Menge THEN `Set(all.map(\.id)) == Set(dueToday ∪ tasks(for: .next))`.
- `badgeCountAndDueTodayUnchanged`: GIVEN dieselbe Menge THEN `badgeCount` zählt die Vereinigung einmal, `dueToday` enthält weiter
  auch Vorgemerkte (Regression, #299).

UI (Schnitte 2 bis 4), `LooseEndsUITests/StartScreenInteractionTests.swift`. Es gibt keinen Seed-Weg: die Tests legen Aufgaben
über die Erfassung an (`captureButton`, `captureTextField`, `captureDoneButton`; „Heute …“ als Rohtext setzt die Fälligkeit
regelbasiert) und starten mit `--ui-testing --ui-testing-long-done-window -AppleLanguages (en) -AppleLocale en_US`; Kennungen
und Anzahl werden geprüft, nicht Titeltexte (der Simulator hat ein Modell, #208). Die Hilfsfunktion `captureAndLineUp` bleibt.

- Umstellung (S2): `testDueTodayShowsOnTheStartScreen`, `testPreviewRowSwipesToDoneAndBack`, `testPreviewRowHasLongPressMenu`
  suchen `nowRow_` statt `dueTodayPreview_`/`nextUpPreview_`.
- `testInboxBarAppearsOnlyWithNewAndOpensNew` (S2): GIVEN App ohne Aufgaben THEN `inboxBar` fehlt, `viewRow_new` existiert;
  WHEN eine Aufgabe erfasst THEN `inboxBar` existiert; Antippen öffnet die Liste mit Navigationstitel „New“.
- `testNowOrdersOverdueBeforeTodayBeforeLined` (S2): GIVEN eine Aufgabe „Heute …“ und eine vorgemerkte (`captureAndLineUp`)
  THEN die Reihenfolge der `nowRow_`-Kennungen nach `frame.minY` zeigt heute vor vorgemerkt, jede Kennung genau einmal.
- `testNowMoreExpandsInPlace` (S2): GIVEN sieben Jetzt-Aufgaben (sieben „Heute …“-Erfassungen) THEN fünf `nowRow_`-Elemente
  und `nowMore` mit Label „2 more“; Antippen zeigt sieben und „Show less“; erneut Antippen wieder fünf.
- `testNowRowSwipeCompletesWithUndo` (S2): Wisch nach rechts auf einer `nowRow_` startet Erledigt mit `undoComplete_`, Tippen
  nimmt zurück, die Zeile bleibt.
- `testRemovingNextUpFromDueRowKeepsItInNow` (S2): GIVEN eine „Heute …“-Aufgabe, vorgemerkt; Menü „Remove from Next up“ THEN die
  Zeile bleibt in `nowRow_`.
- `testChipOpensItsView` (S3): GIVEN eine Aufgabe mit Kontext (über Aufgaben-Detail zugeordnet oder per Regel erkannt) THEN
  `chip_<uuid>` existiert, das Label trägt dieselbe Zahl wie die Zeilenzahl der Liste dahinter; Antippen öffnet die Ansicht mit
  Kontextnamen als Titel.
- `testGridCellOpensView` (S4): Antippen von `viewRow_done` und `viewRow_open` im Raster öffnet die Listen (Navigationstitel);
  `testProjectsCellUnfoldsGroup` (S4): `projectsToggle` antippen zeigt `newProjectButton`.
- Bestehende Tests, die über `viewRow_new`, `viewRow_open/done`, `projectRow_`, `projectsToggle`, `newProjectButton`,
  `contextsToggle`, `newContextButton` navigieren (ContextUniqueness, RecognitionWalkthrough, CalendarTarget, CaptureSmoke,
  ProjectSubtasks, DesignGallery, PlaceSmoke), laufen **ohne Änderung** weiter; das belegt der volle UI-Smoke-Lauf. Nach Schnitt 4
  prüft ein Blick in `DesignGalleryTests`, dass `-startShowsProjects NO` weiter greift.

### Simulator (Stufe 2, jeder UI-Schnitt 2 bis 4, ohne Ausnahme)

`./scripts/sim.sh generate`, `build`, `launch`, `screenshot`: App starten und als Nutzer benutzen. Erfassen, Jetzt-Zeilen
wischen, „N weitere“ aufklappen, Chip antippen, Raster-Zelle antippen, Projekt anlegen, Kontext umbenennen. Screenshots hell und
dunkel, Dynamic Type groß und größte Accessibility-Stufe (Chips umbrechen, Raster einspaltig, nichts abgeschnitten), dazu ein
Graustufenbild (Hierarchie ohne Farbe lesbar; Rot nur an Zeitdruck mit Text). Jedes Bild wird geöffnet und beschrieben, bevor ein
Haken fällt. Zusätzlich iPad-Größe: Seitenleiste unverändert.

### Gerät (Stufe 3)

Entfällt. „Kein Pfad der Geräteliste berührt.“ Nichts auf Hennings Geräten.

## Acceptance Criteria

Schnitt 1 (Regel):

- **AC-1:** `ViewRules.now(in:now:calendar:).all` enthält genau die Vereinigung aus `dueToday` und `tasks(for: .next)`, jede Aufgabe
  einmal; blockierte, Unter-, erledigte und geparkte Aufgaben fehlen (Unit-Tests `unionMatchesTheTwoSources`,
  `blockedSubtasksDoneParkedStayOut`).
- **AC-2:** Reihenfolge: zuerst überfällig (älteste zuerst), dann heute fällig (früheste Uhrzeit zuerst), dann übrige
  vorgemerkte nach `nextRank`; eine vorgemerkte und fällige Aufgabe steht in der Zeitdruck-Gruppe (Unit-Tests).
- **AC-3:** `ViewRules.dueToday`, `ViewRules.badgeCount` und `ViewRules.tasks(for:)` liefern für dieselbe Eingabe dieselben
  Ergebnisse wie vor der Änderung (Regressionstest `badgeCountAndDueTodayUnchanged`, bestehende `DueTodayTests` und
  `StartViewsTests` grün, Diff berührt die drei Funktionen nicht).
- **AC-4:** #339 ist mit dem PR von Schnitt 1 geschlossen (`Closes #339`), PR #340 geschlossen und nicht gemergt; die Regel steht
  in `docs/project/02-datenmodell-und-ansichten.md`.

Schnitt 2 (Eingangsleiste und „Jetzt“):

- **AC-5:** Auf dem iPhone-Startbildschirm existiert `inboxBar` genau dann, wenn „Neu“ mindestens eine Aufgabe enthält; ein Tipp
  darauf öffnet „Neu“. Der Satz „… to look over, … lined up.“ erscheint nirgends mehr (UI-Test, Screenshot).
- **AC-6:** Bei sieben Jetzt-Aufgaben zeigt der Block fünf `nowRow_`-Zeilen und darunter „2 more“ (`nowMore`); Antippen zeigt
  sieben Zeilen und „Show less“, erneut Antippen wieder fünf; die Seite wird dabei nicht verlassen (UI-Test).
- **AC-7:** Jede Aufgabe steht im Startbereich höchstens einmal: eine vorgemerkte, heute fällige Aufgabe erscheint genau einmal
  als `nowRow_`, die Blöcke `nextUpPreview_` und `dueTodayPreview_` gibt es nicht mehr (UI-Test zählt Kennungen).
- **AC-8:** Eine `nowRow_`-Zeile verhält sich wie die bisherige Vorschauzeile (#303): Wisch nach rechts startet Erledigt mit
  „Undo“ (`undoComplete_`), Tippen nimmt zurück; Langdruck zeigt das Menü; Tippen auf die Zeile öffnet die Aufgabe (UI-Tests).
- **AC-9:** „Remove from Next up“ auf einer heute fälligen Zeile lässt sie in „Jetzt“ stehen, auf einer nur vorgemerkten Zeile
  entfernt es sie aus dem Block (UI-Test `testRemovingNextUpFromDueRowKeepsItInNow` und `testPreviewRowHasLongPressMenu`).
- **AC-10:** Ist „Jetzt“ leer, steht unter der Überschrift „Jetzt“ die graue Zeile „Wisch eine Aufgabe nach links, um sie hier
  vorzumerken.“, keine Zeile `nowRow_`, kein `nowMore` (UI-Test mit leerem Speicher, Screenshot).
- **AC-11:** Farbbudget: Rot erscheint im Block nur als Fälligkeitstext von `TaskRow`; die Eingangsleiste ist die einzige
  Akzentfläche der Zone; „N weitere“, Überschriften und Symbole sind grau (Screenshots hell, dunkel, Graustufen). Alle Zeichen
  sind SF Symbols (Diff: kein Emoji, kein Ersatzzeichen).
- **AC-12:** iPad und Mac zeigen die Seitenleiste unverändert; im Diff steht die Änderung ausschließlich im `isCompact`-Zweig
  (Simulator-Screenshot iPad).

Schnitt 3 (Chips „Passt gerade“: AC-13, AC-14) und Schnitt 4 (Raster „Alle Ansichten“: AC-15 bis AC-17); AC-18 mit Schnitt 2 (Doku 03):

- **AC-13:** „Passt gerade“ zeigt zuerst `chip_quick` (nur bei mindestens einer schnellen Aufgabe), dann je einen
  `chip_<uuid>` für jeden Kontext mit mindestens einer offenen Aufgabe; Kontexte ohne Aufgabe haben keinen Chip; ohne Chip fehlt
  der ganze Block. Die Zahl im Chip ist gleich der Zeilenzahl der Liste, die der Tipp öffnet (UI-Test vergleicht beide).
- **AC-14:** Chips brechen in weitere Zeilen um statt zu scrollen oder abzuschneiden; bei größter Accessibility-Schrift sind alle
  Chips sichtbar (Screenshot).
- **AC-15:** „Alle Ansichten“ zeigt die Zellen in der Reihenfolge Als nächstes, Fällig, Neu, Alt, Wartet, Wiederkehrend, Geparkt
  (nur bei Inhalt), Projekte, Kontexte, Alle offenen, Erledigt als graues Zwei-Spalten-Raster, bei Accessibility-Textgrößen
  einspaltig; jede Ansichtszelle behält ihre Kennung `viewRow_<raw>`, Tipp öffnet die Ansicht (UI-Tests, Screenshot).
- **AC-16:** „Neu“ ist bei Neu = 0 über `viewRow_new` weiter erreichbar (UI-Test); alle bestehenden UI-Tests, die über `viewRow_*`,
  `projectsToggle`, `contextsToggle`, `newProjectButton`, `newContextButton`, `projectRow_` navigieren, laufen unverändert grün.
- **AC-17:** Die Zelle „Projekte“ (`projectsToggle`) und „Kontexte“ (`contextsToggle`) klappen die bisherigen Gruppen auf, mit
  Anlegen, Umbenennen und Löschen wie bisher; der gespeicherte Zustand (`startShowsProjects/Contexts`) bleibt gültig (UI-Test).
- **AC-18:** Das Design-Briefing nennt statt des #299-Satzes die drei Zonen und „jede Aufgabe einmal“; keine Stelle der Doku
  behauptet mehr „erscheint in beiden“ für den Startbereich.

Übergreifend:

- **AC-19:** Je Schnitt: Build, alle Unit-Tests und der UI-Smoke grün; Stufe 2 im Simulator mit Screenshots hell, dunkel,
  Dynamic Type groß und Graustufen, geöffnet und beschrieben; jeder PR hält ≤ 5 Dateien, ±250 LoC, Funktionen ≤ 50 Zeilen.
- **AC-20:** Keine Nebenwirkungen: kein neues Modellfeld, kein CloudKit-Schema, keine neuen AppStorage-Schlüssel, `project.yml`,
  Entitlements, `Info.plist`, Widgets, Watch, Intents unverändert (Diff); Satz „Kein Pfad der Geräteliste berührt.“

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ViewRules.dueToday`, `ViewRules.tasks(for:)` | module | Quellmengen von „Jetzt“; bleiben unverändert |
| `ViewRules.tasks(inContext:)`, `.quick` | module | Zahl und Liste hinter den Chips (dieselbe Funktion) |
| `TaskInteractions`, `TaskRow`, `PendingCompletions` | module | Wisch, Menü, Rücknahme-Fenster der Jetzt-Zeilen |
| `ViewSelection`, `ViewKind`, `CatalogService`, `NameEdit` | module | Navigation, Titel, Symbole, Anlegen/Umbenennen/Löschen |
| `DueNotificationCenter` (Zeile 134, `badgeCount`) | module | einziger Produktnutzer von `badgeCount`; unverändert |
| `Localizable.xcstrings` | resource | neue Texte DE/EN |
| SwiftUI `Layout`, `LazyVGrid` | framework | umbrechende Chips, Raster; keine neue Bibliothek |
| Neue Abhängigkeit | – | keine |

## Risiken

- **Viele UI-Tests navigieren über die Startseite** (`viewRow_new` allein 22 Nutzungen in 8 Dateien). Gegenmaßnahme: Kennungen
  bleiben an den Rasterzellen, das Raster wird nicht eingeklappt; voller UI-Smoke je Schnitt (AC-16).
- **Mehrere Tippziele in einer List-Zeile** (Chips, Raster): ohne `.buttonStyle(.plain)` und eigenes `selection = …` triggert
  die ganze Zeile jedes Ziel. Gegenmaßnahme: Buttons, ein UI-Test je Zelle/Chip.
- **Umbau von `SidebarView` (418 Zeilen):** neue Zonen als eigene Views, damit Funktionen ≤ 50 Zeilen bleiben.
- **Uhrzeit und Kalendertag:** „überfällig“ ist tagesgenau; eine Aufgabe von heute früh bleibt „heute“. Unit-Test fixiert das.
- **Simulator-Modell (#208):** kann Titel überschreiben; UI-Tests zählen Kennungen.
- **Schnitt 2 an der Schätzgrenze:** Doku 03 wandert bei Überschreitung nach Schnitt 4 (siehe Scope); Chips und Raster sind vorab getrennt.
- **Zähler-Abweichung:** Die Zahl am App-Symbol (Vereinigung heute + Als nächstes) und die Zahl der Jetzt-Zeilen sind gleich, weil
  dieselben beiden Mengen verwendet werden; ein Unit-Test belegt das.

## Alternativen (verworfen)

- **Entwurf B:** „Jetzt“ mit zwei Unterzeilen (Zeitdruck, Vorgemerkt) und ohne Obergrenze, Chips in einer seitlich scrollenden
  Zeile, „Alle Ansichten“ einklappbar. Verworfen: viele Überfällige schieben „Passt gerade“ aus dem Bild; Chips rechts außerhalb
  des Bildschirms bleiben verdeckt und sind bei großer Schrift schlecht; Einklappen versteckt die `viewRow_*`-Ziele vor den
  UI-Tests und für die Hand (ein Tipp mehr).
- **Nur PR #340 mergen, Vorschauen behalten:** kleinster Schritt (`dueToday` ohne `nextRank`, zwei Vorschauen). Verworfen: löst
  die gleiche Gewichtung aller Zonen nicht, bleibt bei zwei Blöcken für dieselbe Frage „was ist jetzt dran“ und widerspricht der
  PO-Entscheidung vom 12.10. Die Regel „jede Aufgabe einmal“ verlangt ohnehin die neue Funktion.
- **Alle Jetzt-Zeilen zeigen, ohne Obergrenze:** verworfen (Entwurf-Frage 1), drängt Chips und Raster aus dem sichtbaren Bereich.
- **Kein Modell:** Alles ist Filter und Sortierung über vorhandene Felder; ein Modell hätte hier nichts zu verstehen. Der
  Regelweg ist die Lösung, nicht die Alternative.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — kein neues Konzept: eine weitere reine Regel in `ViewRules` und ein Umbau der kompakten Startseite aus
  vorhandenen Bausteinen (`TaskRow`, `TaskInteractions`, `countRow`); keine Modell-, Schema- oder Persistenzänderung, das
  Farbbudget (ADR-14) und „Regeln vor Modell“ sind eingehalten. Die #299-Produktentscheidung „erscheint in beiden“ wird im
  Startbereich ersetzt (siehe Purpose); sie war keine ADR und steht im Design-Briefing, das mit Schnitt 2 angepasst wird.

## Definition of Done

- AC-1 bis AC-20 erfüllt, je Schnitt für seine ACs; neue Unit-Tests und UI-Tests grün, alle bestehenden Tests grün.
- Stufe 2 je UI-Schnitt im Simulator belegt (Screenshots hell, dunkel, Dynamic Type groß, Graustufen, angesehen und beschrieben).
- Doku: `02-datenmodell-und-ansichten.md` (Regel „Jetzt“, Schnitt 1) und `03-design-briefing.md` (Schnitt 2) aktualisiert.
- PRs: Schnitt 1 mit `Closes #339` (PR #340 geschlossen, nicht gemergt), Schnitte 2 bis 4 mit Verweis auf #368; #368 schließt
  mit Schnitt 4. Board-Status gepflegt. Abschlussbericht ohne Git-Vokabular: was Henning auf der Startseite sieht und
  was die Gesten tun; Satz „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-12: Initiale Spec für #368 (drei Schnitte); Produktentscheidungen des PO (Entwurf A, höchstens fünf Zeilen, Zeitdruck
  vor vorgemerkt, Chips, Raster) und Ersatz der #299-Entscheidung im Startbereich.
