---
entity_id: feat-319-alle-offenen
type: feature
created: 2026-10-11
updated: 2026-10-11
status: draft
workflow: feat-319-alle-offenen
---

# Spec: #319 — Ansicht „Alle offenen“

## Approval

- [ ] Approved (Henning)

Produktentscheidungen (Henning, 2026-10-11, Analyse `docs/context/feat-319-alle-offenen.md`, Entwurf
`docs/artifacts/feat-319-alle-offenen/index.html`): Zeile unten direkt über „Erledigt“; Geparktes gehört dazu; flache Liste,
dringend zuerst.

## Purpose

Genauso wie es eine Ansicht „Erledigt“ gibt, gibt es eine Ansicht „Alle offenen“ (Issue #319): eine Systemansicht, die jede
noch nicht erledigte Aufgabe in einer Liste zeigt und auf dem Startbildschirm als eigene Zeile erreichbar ist. Heute liegt
offenes Material verteilt auf Neu, Als nächstes, Wartet, Geparkt und die gelegentlichen Ansichten; es gibt keinen Ort, der
„alles, was noch zu tun ist“ zeigt.

Umfang:

1. **Neuer `ViewKind`-Fall `.open`**, englischer Schlüssel „All open“, deutsch „Alle offenen“, Symbol `circle` (grau wie alle
   Ansichtsglyphen, ADR-14).
2. **Regel:** alle Oberaufgaben (`parent == nil`) mit `status != .done`. Es gibt fünf Status (`TaskStatus`: `unprocessed`,
   `unverified`, `active`, `parked`, `done`); `.open` enthält vier davon: **Neu** (`unprocessed`, `unverified`), **Aktiv**
   (`active`) und **Geparkt** (`parked`), und schließt nur `done` aus. „Wartend“ ist kein Status, sondern `isBlocked`
   (eine offene Aufgabe in `blockedBy`); wartende Aufgaben tragen einen der vier Status und sind damit **eingeschlossen**.
   Die Regel ist bewusst **nicht** `TaskItem.isOpen` (= `unprocessed || unverified || active`, ohne Geparktes).
   Flache Liste, Sortierung `ViewRules.byUrgencyThenImportance` (dringend zuerst, dann wichtig, dann `capturedAt`), wie
   Kontext- und Projektansichten.
3. **Startbildschirm/Sidebar:** eigene Zeile `viewRow_open` in der letzten Section **direkt über „Erledigt“**, mit Zähler,
   **immer sichtbar** (auch bei 0 Aufgaben; die Zahl 0 selbst wird wie bei allen Zeilen nicht angezeigt, `.badge` lässt
   sie weg, #180). Dieselbe `SidebarView` für iPhone, iPad und Mac; es gibt keine zweite Oberfläche.
4. **Leersatz** für die leere Liste: „Nothing left open.“ → „Nichts mehr offen.“ (Stil der anderen Leersätze in
   `TaskListView.emptySentence`).
5. **Geparkte Aufgaben erkennbar:** In „Alle offenen“ trägt eine geparkte Zeile die Glyphe `moon.zzz` (grau,
   `.secondary`, kleine Größe) direkt hinter dem Titel, an der Stelle, an der `TaskRow` auch das AI-Zeichen (`sparkle`)
   zeigt. Farbbudget: grau = Hierarchie, kein Akzent, kein Rot. Die Glyphe erscheint nur in dieser Ansicht (Parameter an
   `TaskRow`); in „Geparkt“ wäre sie Rauschen, in allen anderen Ansichten kommen geparkte Aufgaben nicht vor.
6. **Wischaktionen in `.open`:** nach rechts (leading) **„Complete“** wie bei allen Ansichten (Standardzweig), auch für
   geparkte Aufgaben. Nach links (trailing): bei **geparkter** Aufgabe **„Activate“** (`TaskActions.activate`) statt
   „Next up“, weil eine geparkte Aufgabe nicht in „Als nächstes“ erscheint (Regel dort: `isOpen`); bei allen anderen wie
   Standard „Next up“ / „Remove from Next up“. Das Langdruckmenü bleibt unverändert (es unterscheidet bereits nach Status:
   geparkt → Activate + Delete).
7. **Doku:** neue Zeile in der Regeltabelle von `docs/project/02-datenmodell-und-ansichten.md`, Einleitungssatz und
   `kind`-Aufzählung angepasst.

**Rein regelbasiert.** Eine Filterregel über vorhandene Felder; kein Modell beteiligt, kein Prompt, kein Schema. Kein
Modellfeld, kein CloudKit-Schema (`SavedView.kindRaw` ist ein String und fällt bei unbekanntem Wert auf `.next` zurück;
ein neuer Fall ist additiv). Widgets (nutzen nur `.next`), Watch und Intents sind unberührt.

### Abweichungen und Bündelung (ausdrücklich)

- Die Analyse empfahl, Geparktes **auszuschließen** (Anlehnung an `isOpen`). Der PO hat entschieden, es einzuschließen. Folge:
  eigene Wischregel (Punkt 6) und Kennzeichnung (Punkt 5), beide aus dieser Entscheidung abgeleitet, keine Zusatzwünsche.
- Wartende Aufgaben sind eingeschlossen, obwohl die meisten Tagesansichten `!isBlocked` ausschließen; „Alle“ heißt hier alle.
- Nicht im Umfang: Gruppierung der Liste, Filter innerhalb der Ansicht, Ausblenden der Zeile, eigene Reihenfolge.

## Source

- **Geändert:** `Shared/Models/Enums.swift` (`ViewKind.open`, Titel, Symbol)
- **Geändert:** `Shared/Models/ViewRules.swift` (`case .open` in `tasks(for:)`)
- **Geändert:** `LooseEnds/Views/SidebarView.swift` (Zeile `viewRow_open`)
- **Geändert:** `LooseEnds/Views/TaskListView.swift` (Leersatz, Parameter an `TaskRow`)
- **Geändert:** `LooseEnds/Views/TaskRow.swift` (Mond-Glyphe für geparkt, nur auf Anforderung)
- **Geändert:** `LooseEnds/Views/TaskInteractions.swift` (trailing: `.open` + geparkt → Activate)
- **Geändert:** `LooseEnds/Resources/Localizable.xcstrings` (zwei Texte, DE)
- **Tests:** `LooseEndsTests/StartViewsTests.swift`, `LooseEndsTests/SubtaskTests.swift`, `LooseEndsUITests/StartScreenInteractionTests.swift`
- **Doku:** `docs/project/02-datenmodell-und-ansichten.md`

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Models/Enums.swift` | MODIFY | `ViewKind` bekommt `case open`. `titleKey`: `"All open"`. `symbol`: `"circle"`. `isSystem` gilt automatisch. Reihenfolge der Fälle: nach `parked`, vor `done`. |
| `Shared/Models/ViewRules.swift` | MODIFY | `tasks(for:)`: `case .open: return topLevel.filter { $0.status != .done }.sorted(by: byUrgencyThenImportance)`. `dailyViews`/`occasionalViews` bleiben unverändert (`.open` ist keine Zeile der oberen Section und wird nicht aus Inhalt abgeleitet). |
| `LooseEnds/Views/SidebarView.swift` | MODIFY | Letzte Section: vor der Erledigt-Zeile `countRow(String(localized: ViewKind.open.titleKey), symbol: ViewKind.open.symbol, count: ViewRules.tasks(for: .open, in: tasks).count, id: "viewRow_open").tag(ViewSelection.system(.open))`. Kein `if`: immer da, auch bei 0 (`.badge` lässt die Null weg, #180). |
| `LooseEnds/Views/TaskListView.swift` | MODIFY | `emptySentence`: `case .open: "Nothing left open."`. Beim Erzeugen der `TaskRow` in `row(_:)`: `marksParked: kind == .open`. Liste selbst läuft über `openRows` (flach, kein `onMove`), keine neue Zeilenlogik. |
| `LooseEnds/Views/TaskRow.swift` | MODIFY | Neuer Parameter `var marksParked = false`. Im Titel-`HStack`, hinter dem AI-Zeichen: `if marksParked, task.status == .parked { Image(systemName: "moon.zzz").imageScale(.small).foregroundStyle(.secondary).accessibilityLabel("Parked").accessibilityIdentifier("parkedMarker_<uuid>") }`. Der Text „Parked“ besteht schon (→ „Geparkt“). Zeilenhöhe unverändert (die Glyphe sitzt in der Titelzeile). |
| `LooseEnds/Views/TaskInteractions.swift` | MODIFY | `trailingActions`: neuer Zweig `case .open?` vor `default`: ist `task.status == .parked`, `Button("Activate", systemImage: "play") { activate(task) }.tint(.accentColor).accessibilityIdentifier("swipeActivate_\(task.id.uuidString)")`, sonst dieselben Next-up-Schaltflächen wie `default` (Wiederverwendung über eine kleine private Funktion `nextUpAction(_:)`, damit der Code nicht dupliziert wird). `leadingActions` bleibt unverändert (Standardzweig: Complete). Kopfkommentar um „All open: Activate for a parked task“ ergänzt. |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | `All open` → `Alle offenen`; `Nothing left open.` → `Nichts mehr offen.` Reine Textdatei. |
| `LooseEndsTests/StartViewsTests.swift` | MODIFY | `everyViewHasAPlace` nimmt `.open` aus; neue Regeltests (siehe Test Plan). |
| `LooseEndsTests/SubtaskTests.swift` | MODIFY | Die Liste der Ansichten ohne Unteraufgaben (Zeile ~78) um `.open` ergänzt. |
| `LooseEndsUITests/StartScreenInteractionTests.swift` | MODIFY | Zwei neue UI-Tests (siehe Test Plan); bestehende Datei, keine neue. |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | Zeile „Alle offenen“ in der Regeltabelle; `kind`-Aufzählung um `open` ergänzt; Einleitungssatz um die Ausnahme „Alle offenen“ ergänzt. |

**Schätzung:** Produktcode rund **+55 / −3 LoC**, Tests rund **+110 LoC**, Doku +4 Zeilen; insgesamt etwa **+170 / −5**,
unter der Grenze von ±250 LoC.

**Ausnahme von der Dateigrenze (4–5 Code-Dateien): 6 Code-Dateien plus der Textkatalog, ausdrücklich.** Begründung: Die
Änderung ist ein Stück (Ansicht, Zeile, Kennzeichnung geparkter Zeilen und ihre Wischaktion bilden zusammen die Entscheidung
„Geparktes gehört dazu“); ohne `TaskRow` und `TaskInteractions` zeigte die Liste Geparktes ununterscheidbar und böte ihm
die falsche Wischaktion („Next up“ für etwas, das dort nie erscheint). `Localizable.xcstrings` ist eine reine Textdatei ohne
Logik. Jede einzelne Änderung ist klein (zwei bis zwölf Zeilen). Kein Drive-by-Refactoring; die kleine Funktion
`nextUpAction(_:)` in `TaskInteractions` ist die einzige Umstellung bestehenden Codes und dient nur, die Next-up-Schaltflächen
nicht zu verdoppeln.

**Geräteliste (CLAUDE.md, Stufe 3) berührt: nein.** Die Dateiliste enthält weder `Shared/Enrichment/FoundationModelsEnricher.swift`,
`Shared/Enrichment/EnrichmentCoordinator.swift`, `Shared/Persistence/`, `LooseEndsWatch/`, `LooseEndsWidgets/`, `LooseEndsShare/`,
`Shared/Intents/`, `LooseEnds/Speech/`, `LooseEnds/Notifications/` noch `project.yml`, eine `*.entitlements` oder eine `Info.plist`
(`Shared/Models/*`, `LooseEnds/Views/*`, Resources, Tests, Doku). Die Abnahme endet nach Stufe 2; der Abschlussbericht
begründet das mit dem Satz „Kein Pfad der Geräteliste berührt.“ (Hinweis: Im Arbeitsbaum liegt eine unbeteiligte Änderung an
`LooseEnds/LooseEnds.entitlements`; sie gehört nicht zu diesem Ticket und wird nicht mit eingecheckt.)

Keine neuen Berechtigungen, keine neuen AppStorage-Schlüssel, keine Audio-Dateien, keine Änderung an Persistenz oder Modell.
Lokalisierung läuft über den String Catalog (`Localizable.xcstrings`, englischer Schlüssel, deutsche Übersetzung).
`LooseEndsShare` hat einen eigenen Katalog und braucht die Texte nicht.

## Implementation Details

### Regel

```swift
case .open:
    return topLevel.filter { $0.status != .done }
        .sorted(by: byUrgencyThenImportance)
```

`topLevel` filtert `parent == nil` bereits; Unteraufgaben erscheinen nur in ihrer Elternaufgabe. Reihenfolge innerhalb
gleicher Dringlichkeit/Wichtigkeit: `capturedAt` aufsteigend (ältere zuerst), wie in Kontext und Projekt. Geparkte Aufgaben
ohne Dringlichkeit/Wichtigkeit sortieren damit ans Ende (Rang 3), geparkte mit Wert stehen dort, wo ihr Wert sie einordnet.
Der Exhaustiv-`switch` in `ViewRules.tasks(for:)` und die zwei in `Enums.swift` melden jede vergessene Stelle zur Übersetzungszeit.

### Zeile

`SidebarView` zeigt `.open` nicht über `startViews` (dort stehen die oberen Zeilen aus Tages- und gelegentlichen Ansichten),
sondern fest in der letzten Section, im Muster der Erledigt-Zeile, darüber. Reihenfolge von oben nach unten dort: „Alle
offenen“, „Erledigt“. Die Auswahl läuft über `.tag(ViewSelection.system(.open))`; `ContentView` und `TaskListView` lesen
`ViewSelection` generisch und brauchen keine Anpassung außer den genannten.

### Titel

`TaskListView.title` nutzt `kind.titleKey` → „All open“ / „Alle offenen“; der Navigationstitel zeigt ihn.

### Geparkte Zeile und Wisch

`TaskRow(task:, marksParked:)`: nur wenn `marksParked` **und** `status == .parked`. In `TaskInteractions.trailingActions`
entscheidet `kind == .open` **und** `task.status == .parked`. Die Wischaktion „Activate“ setzt über `TaskActions.activate`
den Status zurück (ohne `parkedAt`); die Aufgabe bleibt in „Alle offenen“ und verliert die Glyphe. Complete nach rechts auf
einer geparkten Aufgabe läuft über dieselbe Done-Frist (#32) und `TaskActions.complete` wie überall; es gibt keine Sonderlogik.

## Test Plan

### Automated Tests (TDD RED zuerst)

`StartViewsTests` (Swift Testing, Unit; Muster `TestStore`, `@MainActor`):

- `testOpenViewContainsNewActiveWaitingAndParked`: GIVEN je eine Oberaufgabe mit `unprocessed`, `unverified`, `active`,
  eine aktive, die von einer offenen blockiert wird (`blockedBy`), und eine geparkte (`TaskActions.park`) WHEN
  `ViewRules.tasks(for: .open, in: all)` THEN alle fünf Aufgaben stehen darin.
- `testOpenViewExcludesDoneAndSubtasks`: GIVEN eine erledigte Oberaufgabe (`TaskActions.complete`) und eine offene
  Unteraufgabe (`Subtasks.add`) WHEN `.open` THEN weder die erledigte noch die Unteraufgabe; die Elternaufgabe steht darin.
- `testOpenViewSortsUrgentFirst`: GIVEN Aufgaben mit Dringlichkeit niedrig, hoch, ohne Wert, mittel (und eine geparkte mit
  hoch) WHEN `.open` THEN Reihenfolge hoch, hoch (nach Wichtigkeit, dann `capturedAt`), mittel, niedrig, ohne Wert.
- `testOpenViewIsEmptyWithoutTasks`: `ViewRules.tasks(for: .open, in: [])` ist leer.
- `everyViewHasAPlace` (angepasst): `Set(ViewKind.allCases).subtracting([.done, .open, .context, .project])`.
- `testOpenIsNotAStartViewRow`: `ViewRules.startViews(in: all)` enthält `.open` nie (die Zeile steht fest unten).

`SubtaskTests` (angepasst): Die Schleife über `[.next, .new, .due, .quick, .old, .waiting, .repeating, .parked, .done]`
bekommt `.open`; keine Ansicht listet eine offene oder erledigte Unteraufgabe.

`LooseEndsUITests/StartScreenInteractionTests.swift` (UI-Smoke, Simulator, Startargumente `--ui-testing`,
`-AppleLanguages (en)`, `-AppleLocale en_US`; die bestehende Hilfsfunktion `launch()` hat zusätzlich
`--ui-testing-long-done-window`, der Test mit Erledigen startet **ohne** dieses Argument, damit die Drei-Sekunden-Frist
abläuft; Texte werden englisch geprüft, wie in den bestehenden Tests):

- `testOpenRowShowsOpenAndParkedButNotDone`: GIVEN drei erfasste Aufgaben (A, B, C), A über das Langdruckmenü (`menuDone`)
  erledigt (`waitForNonExistence` der Zeile in „Neu“, Zeitlimit 10 s), B über das Langdruckmenü „Park“ geparkt.
  WHEN zurück zum Startbildschirm: `viewRow_open` existiert, **und sein Rahmen liegt über** dem von `viewRow_done`
  (`viewRow_open.frame.minY < viewRow_done.frame.minY`, beide nach Wischen sichtbar). Antippen. THEN Navigationstitel
  `app.navigationBars["All open"]` existiert; genau **zwei** Elemente mit Kennung `taskRow_…` (B und C), genau ein
  `parkedMarker_…`; A fehlt (Anzahl, keine CONTAINS-Prüfung auf Text). Der Zähler an `viewRow_open` lautet „2“
  (gleich der Zeilenzahl der Liste). Danach zurück und `viewRow_parked` antippen: dort existiert **kein**
  `parkedMarker_…`, obwohl B darin steht. Screenshot hell, angehängt.
- `testSwipeLeftOnParkedRowOffersActivate`: GIVEN eine geparkte Aufgabe (wie oben) und eine nicht geparkte WHEN in
  „All open“ auf der geparkten Zeile nach links gewischt wird THEN existiert `swipeActivate_<uuid>` (Label gleich „Activate“)
  und „Next up“ existiert **nicht**; auf der nicht geparkten Zeile bietet der Wisch nach links „Next up“. Antippen von
  „Activate“ entfernt `parkedMarker_…` und lässt die Zeile in der Liste. Nach rechts wischen auf der geparkten Zeile bietet
  `swipeDone_<uuid>` („Complete“).
- Leere Liste: `testOpenViewEmptySentence`: GIVEN ohne Aufgaben, `viewRow_open` ist sichtbar (auch ohne Zähler) WHEN
  angetippt THEN `emptyViewLabel` existiert mit Label **gleich** „Nothing left open.“.

(Die Wischregeln für Next up/Activate sind in `TaskInteractions` eine reine Fallunterscheidung; die UI-Tests belegen,
dass sie in der echten Liste ankommt. Der Simulator hat ein Modell, das Titel überschreiben kann (#208): Die Tests prüfen
Kennungen und Anzahl, nicht Titeltexte.)

### Simulator (Stufe 2)

`./scripts/sim.sh generate`, `build`, `launch`, `screenshot`: Startbildschirm ansehen (Zeile „Alle offenen“ mit Kreis-Glyphe
und Zähler direkt über „Erledigt“), Liste öffnen (offene und geparkte Aufgabe, Mond-Glyphe nur an der geparkten), Wisch nach
links an der geparkten Zeile („Aktivieren“). Screenshots hell und dunkel; sie werden geöffnet und beschrieben, bevor ein Haken
fällt. Zusätzlich iPad-Größe (Sidebar), weil dort dieselbe Zeile in der Seitenleiste steht.

### Gerät (Stufe 3)

Entfällt. Kein Pfad der Geräteliste berührt (siehe Scope).

## Acceptance Criteria

- **AC-1 Regel:** `ViewRules.tasks(for: .open, in:)` liefert jede Oberaufgabe mit `status != .done`: Neu (`unprocessed`,
  `unverified`), Aktiv, Wartende (blockiert) und Geparkte; erledigte Aufgaben und Unteraufgaben fehlen (Unit-Test).
- **AC-2 Sortierung:** Die Liste steht nach Dringlichkeit, dann Wichtigkeit, dann `capturedAt` (dringend zuerst); geparkte
  Aufgaben sortieren nach denselben Werten mit (Unit-Test).
- **AC-3 Fall und Texte:** `ViewKind.open` hat Titel „All open“ (DE „Alle offenen“) und Symbol `circle`; kein anderer Fall
  ändert sich; `everyViewHasAPlace` und die Unteraufgaben-Liste kennen `.open` (Unit-Tests grün).
- **AC-4 Zeile:** Auf dem Startbildschirm steht in der letzten Section die Zeile `viewRow_open` direkt über `viewRow_done`,
  immer sichtbar (auch bei 0 Aufgaben, dann ohne Zahl wie alle Zeilen), mit Zähler = Anzahl der Liste (UI-Test prüft „2“
  bei zwei offenen Aufgaben), Glyphe grau (UI-Test und Screenshot).
- **AC-5 Öffnen:** Antippen der Zeile zeigt die Liste mit Navigationstitel „All open“, die offene und die geparkte, aber
  nicht die erledigte Aufgabe enthält (UI-Test).
- **AC-6 Leersatz:** Ohne Aufgaben zeigt die Liste „Nothing left open.“ / „Nichts mehr offen.“ mit `emptyViewLabel` (UI-Test).
- **AC-7 Geparkt erkennbar:** In „All open“ trägt nur die geparkte Zeile die graue Glyphe `moon.zzz` (`parkedMarker_<uuid>`,
  Accessibility-Label „Parked“); in „Geparkt“ erscheint sie nicht (UI-Test zählt dort null `parkedMarker_…`), in den übrigen
  Ansichten kommen geparkte Aufgaben nicht vor; Farbbudget eingehalten, kein Rot/Akzent (UI-Test, Screenshot).
- **AC-8 Wisch nach rechts:** Auf jeder Zeile (auch der geparkten) bietet der Wisch nach rechts „Complete“ (`swipeDone_<uuid>`,
  grün wie überall) (UI-Test).
- **AC-9 Wisch nach links:** Auf einer geparkten Zeile bietet der Wisch nach links „Activate“ (`swipeActivate_<uuid>`) und nicht
  „Next up“; auf allen anderen Zeilen „Next up“ bzw. „Remove from Next up“; „Activate“ nimmt die Mond-Glyphe, die Aufgabe bleibt
  in der Liste (UI-Test).
- **AC-10 Langdruckmenü unverändert:** Geparkte Aufgabe: „Activate“ und „Delete“; alle anderen: das bisherige Menü (kein
  Codeeingriff in `menu(_:)`, durch den Diff belegt).
- **AC-11 Alle Geräte, eine Oberfläche:** iPhone, iPad und Mac zeigen die Zeile aus derselben `SidebarView`; kein
  plattformspezifischer Code (Diff) und Simulator-Screenshot auf iPhone und iPad.
- **AC-12 Keine Nebenwirkungen:** Kein Modellfeld, kein CloudKit-Schema (`mac-schema-init` entfällt), Widgets, Watch, Intents,
  Persistenz, `project.yml`, Entitlements und `Info.plist` unverändert (Diff); „Als nächstes“ und alle anderen Ansichten
  liefern unverändert dieselben Listen (bestehende Unit-Tests grün).
- **AC-13 Doku:** `docs/project/02-datenmodell-und-ansichten.md` enthält die Zeile „Alle offenen“ mit Regel und Sortierung
  und nennt die Ausnahme in der Einleitung.
- **AC-14 Regression und Abnahme:** Unit, Build und UI-Smoke grün; Stufe 2 (Simulator-Durchlauf mit Screenshots hell und
  dunkel, angesehen); Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“

## Dependencies

| Komponente | Version | Beschreibung |
|---|---|---|
| `TaskStatus` | bestehend | fünf Fälle: `unprocessed`, `unverified`, `active`, `parked`, `done`; `.open` = alle außer `done` |
| `ViewRules.byUrgencyThenImportance` | bestehend | Sortierung, wie Kontext und Projekt |
| `TaskActions.activate` / `complete` / `toggleNext` | bestehend | Aktionen hinter den Wischaktionen |
| `ViewSelection.system(_:)`, `SidebarView.countRow` | bestehend | tragen den neuen Fall ohne Änderung |
| `Localizable.xcstrings` | bestehend | zwei neue Einträge; „Parked“ und „Activate“ bestehen |
| Neue Abhängigkeit | – | keine |

## Risiken

- **`isOpen` und `.open` verwechselt.** `TaskItem.isOpen` schließt Geparktes aus, die neue Regel nicht. Wer später die Liste
  mit einer „offen“-Prüfung weiterfiltert, verliert Geparktes. Der Regeltest fixiert das (AC-1), und die Regel steht ohne
  Umweg über `isOpen` im Code.
- **Zählerabweichung zu „Als nächstes“ und „Neu“.** Die Zahl in „Alle offenen“ ist größer als die Summe von Neu und Als
  nächstes, weil sie auch Geparktes und Wartendes zählt. Das ist gewollt und im Entwurf so gezeigt.
- **Exhaustive `switch`es.** `Enums.swift` (zwei), `ViewRules.tasks(for:)`, `TaskListView.emptySentence`: der Compiler meldet
  jede vergessene Stelle; die Tests laufen erst nach grünem Bau.
- **Simulator-Modell (#208):** überschreibt Titel während UI-Tests; die Tests zählen Kennungen statt Titel zu vergleichen.
- **Alter `SavedView.kindRaw`:** Ein unbekannter Wert (etwa auf einem älteren Gerät, das `.open` nicht kennt) fällt dort auf
  `.next` zurück; da `ViewSelection` nicht gespeichert wird, entsteht kein Datenproblem.

## Alternativen (verworfen)

- **Zeile oben bei den Tagesansichten (vor „Als nächstes“):** würde die drei Tageseinstiege auf vier erweitern und eine
  Sammelliste neben die handlungsleitenden Ansichten stellen. „Erledigt“ und „Alle offenen“ sind beide Sammlungen, keine
  Tagesaufgaben; sie stehen zusammen unten. Vom PO verworfen zugunsten der Position über „Erledigt“.
- **Gruppierung nach Fälligkeit (Heute / Diese Woche / Später / Ohne Datum):** verspricht Orientierung, ist aber die Rolle von
  „Fällig“ und führt Abschnittslogik und neue Texte ein. Eine flache Liste „dringend zuerst“ entspricht Kontext und Projekt
  und bleibt klein. Verworfen.
- **Geparktes ausschließen (Anlehnung an `isOpen`):** wäre die kleinste Änderung (kein Mond-Zeichen, keine eigene Wischregel),
  ließe aber „alle offenen“ nicht alle zeigen; geparkte Aufgaben wären nirgends mit dem übrigen Offenen vereint. Vom PO
  verworfen; die Folgearbeit (Punkt 5 und 6) ist der Preis dieser Entscheidung.
- **Eigener Filter „Geparkte mit einblenden“ in der Ansicht:** zusätzlicher Schalter, zusätzlicher Zustand pro Gerät. Nicht
  nötig, solange die Zeile die Geparkten kenntlich macht.
- **Kein Modell:** Die Aufgabe ist ein Filter über ein vorhandenes Feld (`status`); ein Modell kommt nicht vor, deshalb entfällt
  die Zeile „Without the model this fails because …“. Rein regelbasiert.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — kein neues Konzept: eine weitere Systemansicht nach dem bestehenden Muster (`ViewKind` plus Regel in `ViewRules`), ohne Modell-, Schema- oder Persistenzänderung; das Farbbudget (ADR-14) und „Regeln vor Modell“ werden eingehalten, keine bestehende ADR wird gekippt.

## Definition of Done

- AC-1 bis AC-14 erfüllt; die neuen und angepassten Unit-Tests sowie die UI-Tests in `StartScreenInteractionTests` grün, alle
  bestehenden Tests grün.
- Stufe 2 im Simulator belegt: Startbildschirm (iPhone und iPad) mit Zeile über „Erledigt“, Liste mit offener und geparkter
  Aufgabe, Wisch nach links auf der geparkten Zeile; Screenshots hell und dunkel, geöffnet und beschrieben.
- `docs/project/02-datenmodell-und-ansichten.md` aktualisiert; `docs/project/04-stand.md` nennt die Änderung, falls dort die
  Ansichten aufgeführt sind.
- PR mit `Closes #319`; Abschlussbericht ohne Git-Vokabular: was Henning auf dem Startbildschirm sieht, was in der Liste
  steht und was die Wischgesten tun; Satz „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-11: Nach PO-Briefing: Zählerprüfung und Fehlen der Mond-Glyphe in „Geparkt“ in den UI-Test aufgenommen; Null ohne Zahl klargestellt.
- 2026-10-11: Initiale Spec für #319; Produktentscheidungen des PO (Zeile über „Erledigt“, Geparktes eingeschlossen, flache
  Liste dringend zuerst) und die daraus abgeleitete Kennzeichnung und Wischregel für geparkte Zeilen.
