---
entity_id: feat-477-schnitt-1-liste
type: feature
created: 2026-10-17
updated: 2026-10-17
status: draft
workflow: feat-477-mac-papierstil
---

# Spec: #477 Schnitt 1 — Liste im Papierstil auf breit (Mac und iPad)

## Approval

- [ ] Approved (Henning)

Teil-Spec von #477 (Epic #467). Analyse und Entscheidungen: `docs/context/feat-477-mac-papierstil.md`. Entscheidungen von Henning
am 2026-10-17 (Kommentar in #477): iPad im breiten Fenster zieht mit; Mac-Bilder nur aus der CI (#511), nie von seinem Mac;
die Liste sieht aus wie die Tafel `docs/artifacts/feat-408-mac-entwurf/Liste.dc.html`. Das Detail (Schnitt 2) bekommt eine
eigene Teil-Spec und ist hier nicht enthalten.

## Purpose

Auf dem Mac und im breiten iPad-Fenster zeigt jede Liste (Ansichten, Etiketten, Projekte) dieselben zweizeiligen Zeilen wie die
iPhone-Startseite, auf Papier mit Haarlinien statt der grauen Plattform-Karten, mit Abschnittsköpfen in Großbuchstaben, einem
Untertitel „N offen · M Min.“ und einem Grauton unter dem Zeiger. Das iPhone und das iPad im kompakten Fenster bleiben
unverändert.

**Rein regelbasiert.** Der Untertitel ist Zählen und Addieren über vorhandene Felder (`status`, `duration`); kein Modell,
kein Prompt, kein Schema.

## Source

- **Neu:** `LooseEnds/Views/ListSummary.swift` (reine Regel `ListSummary` plus Text des Untertitels)
- **Geändert:** `LooseEnds/Views/TaskListView.swift`, `LooseEnds/Views/Paper.swift`, `LooseEnds/Resources/Localizable.xcstrings`
- **Neu:** `LooseEndsTests/ListSummaryTests.swift`

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Views/ListSummary.swift` | CREATE | `struct ListSummary` (offene Aufgaben, Minuten, Untergrenze) mit `static func of(_:)`; `text` für den Untertitel |
| `LooseEnds/Views/TaskListView.swift` | MODIFY | Breit-Weiche über die Größenklasse; Zeilen und Köpfe breit, Untertitel, Spaltenbreite |
| `LooseEnds/Views/Paper.swift` | MODIFY | `wideListRow(_:)` (Maße, Hintergrund, Hover; auf kompakt wirkungslos), `captionHead` unverändert |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Texte des Untertitels, DE und EN |
| `LooseEndsTests/ListSummaryTests.swift` | CREATE | Unit-Tests der Regel und des Textes |

`TaskInteractions.swift` bleibt unverändert: `pendingRow` bekommt die Maße von außen (Umgebung `startMetrics`, Einzüge und
Zeilenabstand am äußeren Modifier in `TaskListView`), sein Innenleben mit „Undo“ bleibt.

### Estimated Changes

- Dateien: 5 (4 geändert oder neu im Produkt, 1 Testdatei), innerhalb der Grenze von 4 bis 5.
- LoC: ca. +230/-15 (ListSummary ~55, TaskListView ~55, Paper ~40, Strings ~8, Tests ~80). Überschreitet die Umsetzung 250, wird
  gestoppt und mit Schätzung nachgefragt.

Geräteliste: **Kein Pfad der Geräteliste berührt** (nur `LooseEnds/Views`, `LooseEnds/Resources`, Tests). Keine Berechtigung,
kein AppStorage-Schlüssel, kein Modellfeld, kein CloudKit-Schema.

## Implementation Details

**Weiche.** `isWide` in `TaskListView`: auf iOS `horizontalSizeClass != .compact`, auf dem Mac immer `true` (Größenklasse nil
zählt als breit, wie in #471/#476). Ein iPad in Split View oder Slide Over ist kompakt und bekommt die iPhone-Darstellung; das ist
über die Größenklasse zwingend und gewollt. Die Reihen-Inhalte (`openRows`, `reviewSections`, `doneSections`, `projectRows`)
bleiben dieselben Funktionen. Auf kompakt ändert sich weder Stil noch Modifier-Kette: `wideListRow` und die breite Listenhülle
sind dort die Identität (kein zusätzlicher `.navigationSubtitle`, nicht einmal ein leerer).

**Breite Hülle.** `List` mit `.listStyle(.plain)` und `paperGround()`, Spalte `frame(maxWidth: 720)` zentriert wie
`StartPage.listColumn`, das Papier läuft darunter randlos (`Paper.ground.ignoresSafeArea()`), damit außerhalb der Spalte keine
weißen Streifen stehen (Build 71). `paperList()` und `paperRow()` selbst bleiben unverändert, weil Seitenleiste, Katalog und
Startseite sie mitbenutzen.

**Zeile.** `wideListRow(metrics)` setzt `StartMetrics(typeSize)` in die Umgebung (`TaskRow` liest sie: Rand mit Zeit oder Dauer,
rot bei Zeitdruck, Titel New York 18 pt, Merkmale mit Symbolen), `startRow` für die Einzüge, 11 pt oben und unten wie
`StartPage.nowRow`, Zeilengrund Papier. Die Haarlinien sind die Trenner der Plain-Liste. Kein Pfeil am Zeilenende (#509 gilt, die
Tafel ist darin überholt). Die durchgestrichene Zeile (`pendingRow`) trägt dieselben Maße, weil `wideListRow` auf ihr äußeres
Ergebnis wirkt; Projektzeilen (`projectTaskRow`, `subtaskLine`) bekommen dieselbe Behandlung, der Pfeil für Unteraufgaben bleibt.

**Hover (nur Mac).** `#if os(macOS)`: `onHover` setzt einen Zustand je Zeile, der Zeilengrund wird Papier mit einem Rechteck
Radius 10 in `Color.primary.opacity(0.07)` darüber („Grau 7 %“, hell und dunkel aus derselben Tinte). Auf dem iPad gibt es
keinen Hover-Zustand in dieser Spec.

**Köpfe.** In den breiten Abschnitten (Erledigt: Tag; Neu: „Needs a look“) steht der Kopf als `captionHead()`, Großbuchstaben,
grau, mit dem linken Einzug der Zeilen.

**Untertitel „N offen · M Min.“.** `navigationSubtitle` an `TaskListView`, nur breit. Auf dem Mac nativ unter dem Titel; auf dem
iPad (iOS 27) zeigt die Navigationsleiste ihn laut Plattform ebenfalls, das wird im Simulatorbild geprüft; zeigt sie ihn nicht,
bleibt er auf dem iPad aus und die Abweichung kommt in den Abschlussbericht. Die Regel `ListSummary.of(_ tasks: [TaskItem])`:

- **offen:** Anzahl der übergebenen Aufgaben mit `status != .done`. Die Liste übergibt `shown`, also die obersten Zeilen der
  Ansicht, keine Unteraufgaben.
- **Minuten:** Summe der Dauer-Stufen aller offenen Aufgaben mit gesetzter Dauer: 5, 15, 30, 60 und für `hours2plus` 120.
  `hours2plus` heißt „2 Std. und mehr“, also ist die Summe dann eine Untergrenze (`isAtLeast`); der Text sagt „mind.“, statt eine
  Genauigkeit zu behaupten, die es nicht gibt. Die Stufen und ihre Beschriftung kommen aus `DurationBucket` und
  `FieldFormatting.duration`.
- **Randfälle:** Keine Dauer gesetzt: nur „N offen“. 0 offen: kein Untertitel (die Liste zeigt den Leerzustand
  `emptyViewLabel`). Ansicht „Erledigt“: kein Untertitel, „offen“ wäre dort falsch.
- **Format:** unter 60 Minuten „20 Min.“, ab 60 in Stunden mit Rest: „1 Std.“, „1 Std. 30 Min.“, „2 Std. 30 Min.“ (die Wörter
  „Std.“ und „Min.“ wie die vorhandenen Dauer-Beschriftungen). Mit Untergrenze „mind. 2 Std. 30 Min.“. Die Tafel
  zeigt „2 offen · 20 Min.“ (5 + 15), das ist der Fall unter 60. Englisch: „2 open · 20 min“, „1 h 30 min“, „at least 2 h“.
- **Warum hier und nicht in `Shared/Models`:** `Shared/` wird in Watch und Widgets mitübersetzt; der Text braucht die Strings der
  App. Die Regel liegt mit dem Text in einer Datei in `LooseEnds/Views`, bleibt aber frei von SwiftUI und ist ohne Oberfläche
  testbar (der Test übersetzt `LooseEnds/Views` schon, vgl. `DueWordsTests`).

**Alle Funktionen bleiben:** `NavigationLink` zum Detail, Wischgesten, Kontextmenü, Ziehen in „Als nächstes“, Leerzustand,
Plus und ⌘N (Werkzeugleiste in `ContentView`, unverändert). Kennungen `taskRow_*`, `emptyViewLabel`, `disclosure_*`,
`projectSubtask_*`, `undoComplete_*` bleiben.

### Abweichungen von der Tafel (ausdrücklich)

1. **Auswahl in Akzent 12 %** fehlt: Push-Zeilen haben keinen Auswahlzustand; sie braucht `List(selection:)` und kommt mit #480
   (Tastaturauswahl). Dieser Schnitt liefert den Hover.
2. **Titel der Werkzeugleiste** in Systemgröße statt 15 pt halbfett (exakte 15 pt nur über `ToolbarItem(.principal)`, nicht
   lohnend). Der Rundknopf (+) bleibt der vorhandene Knopf `captureToolbarItem`.
3. **Kein Pfeil am Zeilenende** (#509 schlägt die Tafel; der Platz gehört dem Stern mit Rang und dem Mond).
4. **Seitenrand** der Spalte wie `StartPage` (20 pt Einzug in 720 pt Spalte) statt 44 pt der Tafel, damit Startseite und Listen
   dieselbe Spalte haben.
5. **Abschnittskopf** als `captionHead()` (Laufweite 1 pt) statt 0,12 em; derselbe Kopf wie im Detail seit #438.

### Alternativen

- **Eigene `ScrollView` mit `LazyVStack` statt `List .plain`:** exakte Maße der Tafel ohne Listenzwang, aber Wischgesten,
  Ziehen, `onMove` und das Ausblenden gelöschter Zeilen (#194) müssten von Hand nachgebaut werden. Verworfen; `List .plain` trägt
  dieselben Maße und behält alle Funktionen.
- **Nur Mac statt Mac und iPad:** kleiner, aber das iPad im breiten Fenster bliebe bei grauen Karten. Von Henning entschieden:
  das iPad zieht mit.
- **Auswahl 12 % jetzt:** brauchte den Umbau auf `List(selection:)` und kollidiert mit #480. Verschoben.

## Test Plan

### Automated Tests (TDD RED)

Unit, `LooseEndsTests/ListSummaryTests.swift` (Swift Testing, `TestStore`; zuerst schreiben, rot, weil `ListSummary` fehlt):

- [ ] `countsOpenTasksOnly`: GIVEN drei Aufgaben, eine erledigt, WHEN `of` THEN `openCount == 2`.
- [ ] `sumsDurationBuckets`: GIVEN offene Aufgaben mit 5 und 15 Minuten THEN `minutes == 20`, `isAtLeast == false`.
- [ ] `taskWithoutDurationAddsNothing`: GIVEN eine Aufgabe ohne Dauer neben einer mit 30 THEN `minutes == 30`, `openCount == 2`.
- [ ] `twoHoursPlusIsALowerBound`: GIVEN eine Aufgabe `hours2plus` und eine mit 30 THEN `minutes == 150`, `isAtLeast == true`.
- [ ] `doneTaskDurationDoesNotCount`: GIVEN eine erledigte Aufgabe mit 60 THEN `minutes == 0`.
- [ ] `emptyListHasNoText`: GIVEN keine offene Aufgabe THEN `text == nil`.
- [ ] `textWithoutDurationIsOnlyTheCount`: GIVEN zwei Aufgaben ohne Dauer THEN Text ist „2 open“ (Englisch erzwungen).
- [ ] `textUnderAnHourInMinutes`: GIVEN 5 und 15 THEN „2 open · 20 min“.
- [ ] `textFromAnHourInHoursAndMinutes`: GIVEN 60, 15, 15 THEN „… · 1 h 30 min“; GIVEN genau 60 THEN „1 h“.
- [ ] `textWithLowerBoundSaysAtLeast`: GIVEN `hours2plus` und 30 THEN „… · at least 2 h 30 min“.
- [ ] `germanTextUsesStdAndMin`: GIVEN 5, 15 und Deutsch THEN „2 offen · 20 Min.“; GIVEN 90 THEN „1 Std. 30 Min.“.

Bestehend, grün zu halten: `StartViewsTests`, `MarginMarkTests`, `DueTodayTests`, voller Unit-Lauf; UI Smoke (alle laufen auf dem
iPhone, also kompakt).

Simulator (Stufe 2): iPad im breiten Fenster und iPhone, je `./scripts/sim.sh build`, `launch`, `screenshot`; die Bilder werden
geöffnet und beschrieben.

Mac: Bilder `mac-gallery-light-2-list-new` und `mac-gallery-dark-2-list-new` aus dem CI-Job „Mac Gallery (macOS)“ (Artefakt
`MacGallery`) des PR-Laufs; `MacGalleryTests` fotografiert die Liste „New“ mit drei erfassten Aufgaben schon heute.

## Acceptance Criteria

- **AC-1:** `ListSummary.of` zählt offene Aufgaben (`status != .done`) und summiert die Dauer-Stufen offener Aufgaben (5, 15, 30,
  60, `hours2plus` = 120 als Untergrenze); fehlende Dauer und erledigte Aufgaben tragen nichts bei (Unit-Tests
  `countsOpenTasksOnly`, `sumsDurationBuckets`, `taskWithoutDurationAddsNothing`, `twoHoursPlusIsALowerBound`,
  `doneTaskDurationDoesNotCount`).
- **AC-2:** Der Untertitel lautet „N open · M min“ beziehungsweise „N offen · M Min.“; ohne Dauer nur „N open“/„N offen“; ab 60
  Minuten in Stunden und Minuten; mit Untergrenze „at least“/„mind.“; bei 0 offenen Aufgaben fehlt er (Unit-Tests
  `emptyListHasNoText`, `textWithoutDurationIsOnlyTheCount`, `textUnderAnHourInMinutes`, `textFromAnHourInHoursAndMinutes`,
  `textWithLowerBoundSaysAtLeast`, `germanTextUsesStdAndMin`). Die Texte stehen mit DE und EN in `Localizable.xcstrings`.
- **AC-3:** Auf dem Mac zeigt eine Liste Papier mit Haarlinien ohne graue Karten, Zeilen zweizeilig mit Rand (Zeit oder Dauer),
  Titel in New York und Merkmalen mit Symbolen, in hell und dunkel, ohne Pfeil am Zeilenende (Galeriebilder
  `mac-gallery-light-2-list-new`, `mac-gallery-dark-2-list-new` aus dem CI-Lauf, geöffnet und beschrieben: Papierfarbe, Haarlinien
  zwischen Zeilen, Titelschrift, Rand links).
- **AC-4:** Der Untertitel „3 open“ steht in den beiden Mac-Galeriebildern der Liste „New“ unter dem Titel in der Werkzeugleiste
  (Sichtbefund im Bild); im breiten iPad-Simulator steht er unter dem Titel der Navigationsleiste, oder die Abweichung ist im
  Abschlussbericht festgehalten (Simulatorbild).
- **AC-5:** Das iPad im breiten Fenster zeigt dieselbe Papierliste wie der Mac (Simulatorbild iPad Querformat, Liste „New“ oder
  „Next up“, beschrieben: keine grauen Karten, Zeilen der Startseite, Haarlinien, Köpfe in Großbuchstaben bei „Needs a look“).
- **AC-6:** Das iPhone und das iPad im kompakten Fenster bleiben unverändert: der Diff zeigt für die kompakte Darstellung keine
  geänderte Modifier-Kette (nur Extraktion und die auf kompakt wirkungslosen Zusätze `wideListRow` und die breite Hülle), alle
  bestehenden UI-Tests und der volle Unit-Lauf sind grün, und das iPhone-Simulatorbild der Liste „New“ zeigt Papier, Textstile und
  Stern oder Mond am Zeilenende wie vor der Änderung (Vergleich mit `main`).
- **AC-7:** Die durchgestrichene Zeile nach dem Erledigen (Fenster von drei Sekunden mit „Undo“) hat auf breit dieselben Maße
  (Rand, Einzug, Zeilenabstand) wie eine offene Zeile; „Undo“ stellt die Aufgabe wieder her. Belegt im iPad-Simulator: Aufgabe
  wischen und erledigen, Bild während des Fensters beschrieben, danach „Undo“ getippt (`undoComplete_*`).
- **AC-8:** Alle Funktionen der Liste bleiben auf breit erhalten: Tippen öffnet das Detail, Wischen nach rechts und links,
  Kontextmenü, Leerzustand (`emptyViewLabel`), Plus und ⌘N. Beleg: im iPad-Simulator wird das Detail geöffnet, ein Wischen ausgeführt
  und eine leere Ansicht gezeigt (Bilder beschrieben); die Kennungen `taskRow_*` und `emptyViewLabel` sind im Diff unverändert.
- **AC-9:** Hover auf dem Mac: unter dem Zeiger liegt ein Grau von 7 % mit Radius 10 auf der Zeile (`#if os(macOS)`); auf
  iOS ist der Code nicht übersetzt (Diff und iOS-Build). Der Zustand wird nicht fotografiert, weil die CI keinen Zeiger
  bewegt; der Beleg ist der Quelltext und der grüne Mac-Bau im Galerielauf.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `StartMetrics`, `startRow` | module | Maße der Zeile (Titel 18, Rand, Merkmale), Einzüge; unverändert |
| `TaskRow` | module | liest `\.startMetrics`; unverändert |
| `TaskInteractions` | module | Wischen, Menü, `pendingRow`; unverändert |
| `Paper`, `paperList`, `paperRow`, `captionHead` | module | geteilte Modifier; unverändert, `wideListRow` kommt hinzu |
| `DurationBucket`, `FieldFormatting.duration` | module | Stufen und Beschriftung der Dauer |
| `MacGalleryTests`, CI-Job „Mac Gallery (macOS)“ (#511) | test | liefert die Mac-Bilder; unverändert |
| Neue externe Abhängigkeit | – | keine |

## Außerhalb des Umfangs

- **Schnitt 2 (Detail):** eigene Teil-Spec mit eigenem Workflow (`TaskDetailView`, Register breit, Titel 30 pt, Spalte ≤ 760 pt).
  Hier keine Änderung am Detail.
- Auswahl in Akzent 12 % und Tastaturauswahl: #480.
- Startseite, Seitenleiste, Katalog: unverändert.

## Auslieferung

Nach dem Merge läuft der TestFlight-Bau; Henning bekommt die Buildnummer und die Prüfschritte für den Mac (Liste „New“ öffnen:
Papier, Haarlinien, Untertitel, Grau unter dem Zeiger), keine Befehlszeile. Das ist die Definition of Done des Tickets und
ein Schritt nach dem Merge, kein Abnahmekriterium dieser Spec. Es ändert sich kein Modell, deshalb kein
`mac-schema-init`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — keine neue Entscheidung. ADR-1 (eine Codebasis, Abweichungen über Größenklasse oder `#if os(macOS)`)
  bleibt und trägt die Weiche wie bei #471 und #476; kein Modell-, Schema- oder Persistenzeingriff.

## Definition of Done

- AC-1 bis AC-9 erfüllt; neue und alle bestehenden Unit-Tests grün (`./scripts/sim.sh sim-unit`, nie auf dem Mac), UI Smoke grün.
- Stufe 2: iPad breit und iPhone im Simulator gebaut, gestartet, fotografiert, Bilder beschrieben. Mac-Bilder aus dem CI-Artefakt
  `MacGallery`, nie von Hennings Mac.
- Satz im Abschlussbericht: „Kein Pfad der Geräteliste berührt.“
- PR mit `Closes`-Verweis nur, wenn Schnitt 2 abgeschlossen ist, sonst Verweis auf #477; Board gepflegt.

## Changelog

- 2026-10-17: Teil-Spec Schnitt 1 (Liste) aus der Analyse `docs/context/feat-477-mac-papierstil.md` geschrieben.
