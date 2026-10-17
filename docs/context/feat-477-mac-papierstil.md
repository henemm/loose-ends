# Context: feat-477-mac-papierstil

## Request Summary
#477 (Epic #467): Auf dem Mac sollen Liste und Detail aussehen wie die freigegebenen Tafeln „Liste“ und „Detail“
(`docs/artifacts/feat-408-mac-entwurf/`, Freigabe Henning 2026-10-16). Gemeint ist Papier mit Haarlinien statt grauer Karten,
dieselben Zeilen wie auf dem iPhone und ein Detail als Register. Alle bisherigen Funktionen des Details bleiben.

## Soll laut Tafeln (`Liste.dc.html`, `Detail.dc.html`, `mac.css`)
**Liste**
- Werkzeugleiste: Titel in SF 15 pt halbfett (Tinte), daneben grau 12 pt „2 offen · 20 Min.“, rechts ein Rundknopf (+), 34 pt mit Haarlinie.
- Inhalt mit 44 pt Rand, Abschnittsköpfe in Großbuchstaben (`.cap`: 11 pt halbfett, Laufweite 0,12 em, grau).
- Zeilen wie auf der iPhone-Startseite: Rand 76 pt mit Zeit oder Dauer (12 pt medium, grau, rot bei Zeitdruck), Titel in New York 18 pt,
  Merkmale 13 pt mit Symbolen 15 pt, Haarlinie unten, rechts ein blasser Pfeil (13 pt).
- Auswahl: Akzent 12 % mit Radius 10, Hover Grau 7 % (Hover steht im Ticket, nicht auf der Tafel).

**Detail**
- Werkzeugleiste: Zurück-Pfeil als Rundknopf ohne Rand, daneben der Name der Liste grau 13 pt; rechts Rundknöpfe „Erledigen“ (Kreis mit Haken) und „…“.
- Spalte höchstens 760 pt, Rand 56 pt. Kopf in Großbuchstaben mit Knoten (rot „Heute“ bei Zeitdruck), Titel in New York 30 pt medium,
  darunter der Rohtext 12,5 pt grau.
- Gesetzte Felder als Zeilen: Beschriftung in Großbuchstaben 12 pt in einer Spalte von 130 pt, Wert 14 pt, Herkunft klein grau
  („aus deinen Worten“), Haarlinie, mindestens 40 pt hoch.
- Leere Felder als Chips mit Rand („+ Projekt“, „+ Ort“, „+ Wartet auf“, „+ Wiederholen“, „+ Anhang“), Akzentschrift.
- „NOTIZ“ als Kopf, Notiz in New York 17 pt.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/TaskListView.swift` (313 Z.) | Liste aller Ansichten; `List` + `.paperList()`, `NavigationLink` zur Detailansicht, Wischgesten, Kontextmenü, Leerzustand |
| `LooseEnds/Views/TaskRow.swift` (173 Z.) | Die Zeile; liest `\.startMetrics` (gesetzt nur auf der Startseite), sonst Textstile `.body`/`.caption`, Randbreite 54 |
| `LooseEnds/Views/Paper.swift` | `paperList`/`paperRow`: nur iPhone kompakt ist `.plain` mit Papierzeilen; iPad breit und Mac behalten den Plattformstil (graue Karten / Seitenleistenstil) |
| `LooseEnds/Views/StartMetrics.swift` | Maße der Startseite (Titel 18, Rand 12, Merkmale 12,5, Randbreite 52); `startRow()` setzt die Einzüge |
| `LooseEnds/Views/TaskDetailView.swift` (669 Z.) | Detail als `Form` `.grouped` + `.paperGround()`; Abschnitte Titel/Rohtext, Feldzeilen (`fieldRow`, Beschriftung `.footnote` in 92-pt-Spalte), Wortleiste leerer Felder (`FlowLayout`, „+ Wort“), Notiz, Anhänge, Kalender, Ort, Unteraufgaben, Wartet auf, Herkunft, Quelle, Ergänzen; Werkzeugleiste „Passt“ + Menü „…“ (Erledigen im Menü, #435) |
| `LooseEnds/Views/DetailLayout.swift` | Reine Regel: gesetzt/leer, Rohtext zeigen; unit-getestet |
| `LooseEnds/Views/NoteSection.swift`, `AttachmentsSection.swift`, `SupplementSection.swift`, `PlaceSection.swift`, `SubtasksSection.swift`, `WaitingOnSection.swift` | Abschnitte des Details, jeweils `Section` in der `Form`; Funktionen müssen bleiben (#439, #442, #441) |
| `LooseEnds/App/ContentView.swift` | `NavigationSplitView`: Detailspalte = `NavigationStack` mit `TaskListView`, Plus-Knopf (⌘N) per `.toolbar`; Aufgabe aus Widget öffnet `TaskDetailView` direkt |
| `LooseEnds/Views/StartPage.swift`, `StartZones.swift`, `SideColumnView.swift`, `SidebarView.swift` | Vorbilder: Mac-Startseite (#471–#473) und Seitenleiste (#476) setzen `StartMetrics` und `startRow` schon um, Auswahl `Color.accentColor.opacity(0.12)` |
| `LooseEndsUITests/DesignGalleryTests.swift` | Fotografiert Hauptbildschirme hell/dunkel; läuft in der CI nur für iOS (Artefakt `DesignGallery`) |
| `docs/project/03-design-briefing.md` Abschnitt „Mac-App“ | Beschluss im Wortlaut (Schrift Serif/SF, Farbbudget, Fenster ≥ 760 × 520) |

## Existing Patterns
- **Eine Codebasis (ADR-1):** Mac-Abweichungen nur per `#if os(macOS)` (z. B. `editorPopover` #482, Seitenleistenbreite #476) oder per Größenklasse.
- **Startseiten-Maße per Umgebung:** `.environment(\.startMetrics, metrics)` + `.startRow(metrics)` macht aus `TaskRow` die Zeile der Tafel; außerhalb der Startseite bleiben Systemstile.
- **Großbuchstaben-Köpfe:** `captionHead()` in `Paper.swift` (#438).
- **Papier:** Farbe `Paper` aus dem Asset-Katalog, `paperGround()` blendet den Formular-Hintergrund aus.
- **Feldeditor am Mac als Popover an der Zeile** (#482): bleibt, egal wie die Zeile aussieht.

## Dependencies
- Upstream: `ViewRules` (Zeilen je Ansicht, `marginMark`, Fälligkeit), `FieldFormatting`, `RevisionService` (Herkunft), `TaskInteractions` (Gesten, Menü, Löschen), `FlowLayout`.
- Downstream: UI-Tests nutzen die Kennungen `taskRow_*`, `field_*`, `detailTitleField`, `detailMoreMenu`, `menuCompleteButton`, `detailConfirmButton`, `emptyViewLabel`, `disclosure_*`, `projectSubtask_*` — sie müssen bleiben.

## Existing Specs
- `docs/specs/feat-438-detail-schrift.md` — Detail im Stil der Startseite auf dem iPhone (#438): Titel 23 pt, Beschriftungsspalte 92 pt, keine Pfeile.
- `docs/specs/feat-368-startseite-drei-zonen.md` — Startseiten-Zeilen.
- Für #471–#476 gibt es keine Specs; sie liefen ohne Workflow.

## Risks & Considerations
- **iPhone und iPad dürfen sich nicht ändern**, sofern Henning es nicht will. `paperList`/`paperRow` und `TaskRow` sind geteilt. Offen ist, ob das iPad im breiten Fenster mitzieht: Henning wollte die iPad-Seitenleiste wie auf dem iPhone (#368 S2), und für das iPad gilt hier dasselbe Muster. Das ist eine Produktfrage für die Analyse.
- **Widerspruch zu #435:** Die Detail-Tafel zeigt einen Erledigen-Knopf (Kreis mit Haken) in der Werkzeugleiste. Henning hat am 2026-10-15 entschieden, dass kein Haken in der Leiste steht, weil man ihn versehentlich als „Schließen“ antippt. Die Tafel stammt vom 2026-10-16, das Ticket nennt den Knopf nicht. Das muss in der Analyse geklärt werden.
- **Leere Felder:** Die Tafel zeigt Chips mit Rand, das iPhone die Wortleiste „+ Wort“ ohne Rand (#440). Auf der Tafel fehlen Energie, Wichtig/Dringend und Notiz als Chips. Die Feldliste kommt aus `fieldEntries`, nicht aus der Tafel.
- **Umfang:** Liste und Detail zusammen sprengen 250 LoC und 4–5 Dateien. Deshalb zwei Teil-Specs mit je eigenem Workflow (Memory „Mehrere Schnitte = Teil-Specs“): Schnitt 1 Liste (+ Zeile), Schnitt 2 Detail.
- **Detail ohne `Form`:** Ein Register mit Haarlinien und 760 pt Breite verlangt am Mac vermutlich `ScrollView` + eigene Zeilen statt `Form .grouped`. Jede `Section` der Unterabschnitte (Notiz, Anhänge, Ort …) ist heute ein `Section` und rendert außerhalb einer `Form`/`List` anders. Das ist das größte technische Risiko, die Analyse muss es prüfen (Alternative: `Form` mit `.formStyle(.columns)` oder `List(.plain)` mit ausgeblendeten Trennern).
- **Beleg am Mac:** Der Mac ist Hennings Gerät. Die globale Regel „nur auf sein Wort“ nennt „Mac als Zielgerät“ ausdrücklich, Unit-Tests laufen nie auf dem Mac (Memory „Tests nie auf dem Mac“). `sim.sh` hat keinen Mac-UI-Testbefehl, die Galerie läuft in der CI nur für iOS. Ein Bild von „Heute“ und der Nachweis brauchen also entweder seine Freigabe oder einen Mac-Galerielauf in der CI (CI-Runner, nicht sein Gerät). Das muss die Analyse entscheiden. Die Abnahme laut Ticket läuft über TestFlight auf dem Mac.
- **Stufe 3:** Keine Datei der Geräteliste ist berührt (nur `LooseEnds/Views/`). Das Ticket verlangt aber selbst die Abnahme über TestFlight auf dem Mac.
- **Hover und Auswahl in `List`:** Die Auswahl einer `NavigationLink`-Zeile färbt macOS selbst mit der Systemfarbe. Akzent 12 % und Hover 7 % brauchen eigene Hintergründe (`listRowBackground`, `onHover`).

## Analysis

### Type
Feature (Gestaltung), Teil von Epic #467.

### Entscheidungen des PO (Henning, 2026-10-17, Kommentar in #477)
1. Kein Erledigen-Haken in der Detail-Leiste, auch auf dem Mac (#435 gilt, Tafel veraltet).
2. iPad im breiten Fenster zieht mit: dieselbe Liste und dasselbe Detail wie der Mac. iPhone (kompakt) bleibt unverändert.
3. Mac-Bilder nur aus der CI (neues Ticket #511 „Mac-Galerie“), nie auf Hennings Mac. #511 kommt vor die Vorschau „Heute neben Entwurf“.

### Recherche (Quellen)
- Auswahlfarbe einer macOS-Liste ist in SwiftUI kaum steuerbar, sie folgt der AccentColor (https://developer.apple.com/forums/thread/732856, https://www.hackingwithswift.com/forums/swiftui/how-to-change-highlight-color-of-selected-navigationlink/1515).
- `Section` in Stack/ScrollView hat keine eigene Optik (https://developer.apple.com/documentation/swiftui/grouping-data-with-lazy-stack-views.md).
- GitHub-macOS-Runner sind interaktive Sitzungen, macOS-XCUITest läuft ohne Zusatzeinrichtung (https://tessl.io/registry/testland/xcuitest-suite/files/references/macos.md).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEnds/Views/Paper.swift | MODIFY | Schnitt 1: Umgebungswert `paperPlain`, `plainPaperList()`, `HoverRow` (Mac). Schnitt 2: `DetailContainer` (kompakt `Form .grouped`, breit `List .plain`, ≤ 760 pt) |
| LooseEnds/Views/TaskListView.swift | MODIFY | Schnitt 1: breit = Startseiten-Maße je Zeile, Köpfe in Großbuchstaben, Untertitel „N offen · M Min.“, Hover; kein Pfeil am Zeilenende (#509 schlägt die Tafel) |
| LooseEnds/Views/TaskInteractions.swift | MODIFY | Schnitt 1: durchgestrichene Zeile (`pendingRow`) mit denselben Maßen |
| Shared/Models/ViewRules.swift (oder neues `ListSummary`) | MODIFY/CREATE | Schnitt 1: reine Regel für den Untertitel (Anzahl, Summe der Dauern) + Unit-Test |
| LooseEnds/Resources/Localizable.xcstrings | MODIFY | Schnitt 1: Untertitel-Texte |
| LooseEnds/Views/TaskDetailView.swift | MODIFY | Schnitt 2: `Form` → `DetailContainer`; breit: Titel 30 pt, Rohtext 12,5 pt, Beschriftung in Großbuchstaben in 130-pt-Spalte, Zeilen ≥ 40 pt, leere Felder als Chips mit Rand |

Die sechs Abschnittsdateien (Notiz, Anhänge, Ergänzen, Ort, Unteraufgaben, Wartet auf) bleiben unverändert, weil das Detail in einer `List` bleibt.

### Scope Assessment
- Schnitt 1 (Liste): 4–5 Dateien, ~120–150 LoC.
- Schnitt 2 (Detail): 2–3 Dateien, ~130–170 LoC; Rückfall bei > 250 LoC: 2a (Behälter, Titel, Felder, Chips), 2b (Köpfe, Feinschliff).
- Risk Level: MEDIUM. Geteilte Ansichten, iPad bekommt neue Darstellung, Mac nur über #511/TestFlight prüfbar.

### Technical Approach
Alle Änderungen hängen an `sizeClass != .compact` (Mac: Größenklasse nil, zählt als breit). Der kompakte Zweig bleibt textgleich, damit das iPhone unverändert bleibt.
- **Liste:** `List .plain` auf Papier mit 720-pt-Spalte wie `StartPage.listColumn`; Zeilen bekommen `StartMetrics` + `startRow` (Titel 18 New York, Rand, Merkmale 12,5); Trennlinien der Plain-Liste sind die Haarlinien. Untertitel per `navigationSubtitle` (Mac nativ; iPad erst im Bau prüfen). Hover 7 % per `onHover` nur Mac. **Auswahl in Akzent 12 % ist mit Push-Zeilen nicht erreichbar** (kein Auswahlzustand). Sie braucht `List(selection:)` und gehört zur Tastaturauswahl in #480.
- **Detail (Weg B):** gleiche `List`-Mechanik, auf breit nur Stil `.plain` statt `.grouped`. So bleiben Wischgesten, Löschen, Sheets, `fileImporter`, `NavigationLink` und Popover erhalten.

### Alternativen (Detail)
| Weg | Dateien | LoC | Risiko |
|---|---|---|---|
| **B: `Form`→`List .plain` auf breit (`DetailContainer`)** | 2–3 | ~150 | gering–mittel: iPhone unberührt; Mac-Popover, iPad-Zeilengrund prüfen |
| A: `ScrollView`+`VStack`, ≤ 760 pt | 6+ | ~250–300 | hoch: Wischen/Löschen fallen weg, Sheets an Abschnitten verteilen sich, Haarlinien von Hand |
| C: `Form .columns` in `ScrollView` | 3–4 | ~150 | mittel–hoch: Spalten kollidieren mit eigenen Zeilen, List-Funktionen weg |
| D: `.grouped` behalten, nur umfärben | 1–2 | ~40 | gering, verfehlt aber die Tafel (graue Karten bleiben) |
Gekippt würde mit B nichts; ADR-1 (ein Codepfad) bleibt, die Weiche ist die Größenklasse wie bei #471/#476.

### Abweichungen von der Tafel (in die Spec)
- Kein Haken in der Detail-Leiste (Entscheidung 1).
- Auswahl 12 % erst mit #480; #477 liefert Hover.
- Werkzeugleisten-Titel am Mac in Systemgröße (13 pt) statt 15 pt halbfett; exakte 15 pt nur über `ToolbarItem(.principal)`, nicht lohnend.
- Grauer Listenname neben dem Zurück-Pfeil im Detail entfällt (Systemknopf).
- „GESAGT“-Vorsatz vor dem Rohtext: steht nicht auf der Tafel. Er bleibt, weil er seit #438 auf dem iPhone steht.

### Dependencies
Upstream: `ViewRules`, `StartMetrics`, `FieldFormatting`, `RevisionService`, `TaskInteractions`. Downstream: UI-Tests laufen nur auf dem iPhone (kompakt), sind also vom breiten Zweig nicht berührt; keiner deckt iPad oder Mac ab. Nachweis breit: iPad-Simulator (Stufe 2) und Mac-Galerie #511.

### Open Questions
- [x] Haken in der Leiste? → nein (Henning)
- [x] iPad mit? → ja (Henning)
- [x] Mac-Bilder? → CI (#511, Henning)
- [ ] Vorschau „Heute“ (aus #511) neben „Entwurf“ zeigen und freigeben lassen. Erst dann `/30-write-spec` (Hennings Regel „Entwurf vor Spec“).
  Vorschau (2026-10-17): `docs/artifacts/feat-477-mac-papierstil/vorschau.html`, https://claude.ai/artifact/TcQ39RrQdJA1U72n2chb44.
  „Heute“ aus Lauf 39028852918 (main): Liste hat schon Papierzeilen mit Textstilen, Kopf in normaler Schrift, kein Untertitel; Detail = graue Karten.
- [x] Detail → **iPhone-Register, breiter** (Henning 2026-10-17): Register aus #438 auch auf breit, Titel 30 pt, Spalte ≤ 760 pt; Beschriftung in normaler Schrift, Wortleiste ohne Rahmen, keine Chips, keine Großbuchstaben-Beschriftung. Tafel ist darin überholt.
- [x] Liste → **wie die Tafel** (Henning 2026-10-17): zweizeilig wie die iPhone-Startseite, Hover Grau 7 %, Untertitel „N offen · M Min.“, Köpfe in Großbuchstaben; Auswahl 12 % mit #480.
- [ ] iPad in Split View/Slide Over ist kompakt und bekommt die iPhone-Darstellung (in der Spec so festhalten, technisch zwingend über die Größenklasse).
