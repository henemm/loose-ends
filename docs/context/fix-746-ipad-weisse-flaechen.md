# Context: fix-746-ipad-weisse-flaechen

## Request Summary
#746: Auf dem iPad im Hochformat (iPad Pro 13-inch (M5), Seitenleiste ausgeblendet) steht die Startseite
auf einer weißen Fläche (bis etwa y=580 von 2000) auf beigem Grund; „Erledigt“ hat hinter dem Faden eine weiße
Fläche, die links bei etwa x=465 von 1500 abgeschnitten ist. iPhone ist nicht betroffen. Gewollt oder Darstellungsfehler,
zuerst im Simulator nachstellen, dann ändern. Blockiert #742 Schnitt 1 (App-Store-Bilder).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/App/ContentView.swift:52-87` | einzige `NavigationSplitView`; Detailspalte zeigt `StartPage` (keine Auswahl) oder `NavigationStack { TaskListView }` (Erledigt); kein eigener Hintergrund an der Spalte |
| `LooseEnds/Views/StartPage.swift:55-87,118` | `ViewThatFits`: ab 900 pt Breite Liste + `SideColumnView`, sonst nur `listColumn`; `listColumn` = `.frame(maxWidth: 720)`, `.frame(maxWidth: .infinity)`, `.background(Paper.ground.ignoresSafeArea())` |
| `LooseEnds/Views/TaskListView.swift:257-269` | `hull(_:)` für breite Fenster: gleiche 720-pt-Spalte, `Paper.ground.ignoresSafeArea()` dahinter; „Erledigt“ ist `kind == .done` |
| `LooseEnds/Views/Paper.swift:6-125` | `Paper.ground` (Asset „Paper“, beige), `paperGround()` = `scrollContentBackground(.hidden)` + Hintergrund, `DetailColumn`, `PaperList` |
| `LooseEnds/Views/Beads.swift`, `Thread.swift`, `KnaeuelThread.swift` | der „Faden“ auf der Erledigt-Seite; mögliche Quelle der Fläche dahinter, noch nicht geprüft |
| `LooseEndsUITests/DesignGalleryTests.swift` | vorhandene Galerie-Aufnahmen, mögliche Basis für den UI-Test |
| `scripts/sim.sh` (`build`, `launch`, `screenshot`, `store-screenshots` auf dem #742-Zweig) | Nachstellung; iPad per `LOOSEENDS_SIM="iPad Pro 13-inch (M5)"` |

## Existing Patterns
- Beiges Papier wird pro View gesetzt (`Paper.ground`), nicht an der Spalte der `NavigationSplitView`. Auf dem Mac gab es schon einmal weiße Balken außerhalb der 720-pt-Spalte (Build 71), gelöst mit `.background(Paper.ground.ignoresSafeArea())` an der Liste.
- Das Muster bedeckt nur den Bereich der View selbst. Der Hintergrund, den iPadOS hinter einer Detailspalte im Hochformat zeichnet (Systemfarbe, ggf. Glas-Effekt der Seitenleiste ab iPadOS 26), ist davon nicht erfasst.

## Dependencies
- Upstream: `NavigationSplitView` (iPadOS 27), `Paper`-Farbasset, `horizontalSizeClass`.
- Downstream: Startseite und alle Listenansichten im breiten Fenster (iPad, Mac), Detailseite (`detailColumn`), #742 Store-Bilder.

## Recherche
- Kein Fallbericht zu genau diesem Symptom gefunden. Verwandt: Apple-Forum 803191 (Seitenleiste wirkt auf iPadOS 26 transparent, Abhilfe Hintergrund hinter der Seitenleiste), 832916 (Hintergrund der `NavigationSplitView`, Hinweis auf `containerBackground(for: .navigationSplitView)`, dort auf iOS 27 funktionierend). Beides ungeprüft.

## Existing Specs
- Keine Spec zu diesem Bereich. Verwandt: #477 (Mac-Papierstil), #408 (Startseite breit), #593 (Fensterplatzierung).

## Risks & Considerations
- Nicht nachgestellt: Der Simulator-Bau wartet auf die rechnerweite Testsperre, die eine Restock-Sitzung hält. Ursache und Gewolltheit bleiben bis zur Nachstellung offen.
- Die Bilder aus #742 liegen auf einem noch nicht hochgeladenen Zweig; die Nachstellung muss die Flächen selbst erzeugen.
- Ein Eingriff an der Spalte trifft Mac und iPad-Querformat mit; dort gibt es Mac-Galerie- und Fenstertests (`MacGalleryTests`, #593).
- Alternative: Flächen sind plattformgewollt, dann Store-Bilder anders aufnehmen (Seitenleiste sichtbar) statt die App ändern.

## Analysis

### Type
Bug (Darstellungsfehler, kein Plattformverhalten): Das Papier-Beige ist die Vorgabe der App (`Paper.ground`, #180); weiß ist nirgends gewollt.

### Reproduktion (2026-10-30, Simulator iPad Pro 13-inch (M5), Hochformat, `--ui-testing`, Build aus diesem Stand)
- Startseite: die rechte Spalte (die Startseite) steht auf einer weißen Fläche von x=465 bis zum rechten Rand und von y=125 bis y=463 (von 2000), genau so hoch wie ihre Zeilen („Alles verknotet.“, Schreibzeile, „Jetzt“, Hinweis); darunter beiger Grund. Bild: `/private/tmp/claude-501/-Users-hem-Developer-loose-ends/cb18b848-41f7-43bb-8dc3-c35fb60f25f0/scratchpad/ipad-start-before.png`.
- „Erledigt“: noch nicht selbst aufgenommen (der Simulator lässt sich ohne UI-Test nicht antippen). Es entsteht im ersten Schritt von `/40-tdd-red` als roter UI-Test. Dieselbe Ursache ist im Code zu sehen (`TaskListView.swift:327-329`, die Fadenzeile `WeekString` trägt nur `.paperRow()`); die weiße Fläche beginnt wie im Bericht bei x=465.
- Hat es bisher funktioniert? Weder im Ticket noch im Verlauf belegt; der Bericht sagt, die Flächen seien schon in den ersten Bildern von #742 gewesen.

### Root Cause
`PaperRow` (`LooseEnds/Views/Paper.swift:85-96`) setzt den beigen Zeilenhintergrund nur bei `horizontalSizeClass == .compact`. Auf dem iPad im Hochformat ist die Breite regulär, also bleibt `.paperRow()` wirkungslos. Die Listen der Detailspalte (`StartPage.listColumn`, `TaskListView.hull`, `CatalogPage`) sind `.plain` und zeichnen für Zeilen ohne eigenen Hintergrund den Systemhintergrund: weiß. Der Listengrund dahinter ist beige (`paperGround()`), weiß ist nur der Bereich der Zeilen. Auf dem Mac sind Zeilen durchsichtig, deshalb fiel es dort nie auf. Nur Zeilen mit `.wideListRow()` (`Paper.swift:132`) setzen den Grund auch im breiten Fenster.
Betroffene Zeilen ohne `.wideListRow()`: `StartPage.swift:76,124,158,181`, `StartZones.swift:30,157,166,205,282`, `Knaeuel.swift:30`, `Beads.swift:176,182,188`, `TaskListView.swift:329`, `CatalogPage.swift:60-91`.
Die Seitenleiste ist kein Gegenbeispiel: Ihre Liste ist im Seitenleisten-Stil, dort sind Zeilen durchsichtig, und `SidebarView.swift:133,174,192,275` verlässt sich auf das „regulär = unverändert“ (Auswahlmarkierung bleibt).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/Paper.swift` | MODIFY | `PaperRow` setzt auf iOS den Grund auch im regulären Fenster; neue `sidebarRow()` für die Seitenleiste, die im regulären Fenster unverändert bleibt |
| `LooseEnds/Views/SidebarView.swift` | MODIFY | 4 Aufrufe `.paperRow()` → `.sidebarRow()` |
| `LooseEndsUITests/PaperGroundTests.swift` | CREATE | iPad-UI-Test: Pixelprobe in der Zeilenfläche der Startseite und unter ihr gleich beige; ebenso „Erledigt“ |

### Scope Assessment
- Files: 3
- Estimated LoC: +60/-6
- Risk Level: LOW-MEDIUM (Listen aller Detailansichten im breiten Fenster; macOS bleibt bewusst unverändert, damit Mac-Galerie und Fenstertests nicht berührt werden)

### Technical Approach
Eine Regel an einer Stelle statt jede Zeile einzeln: `paperRow()` meint „Zeile einer Papierliste“ und malt den Grund immer (iOS). Die Seitenleiste bekommt ihren eigenen Aufruf und behält das alte Verhalten. Kein Modell, keine Regel-Frage.
Alternative: den Zeilengrund der ganzen Liste setzen (`listRowBackground` am Container) — verworfen, weil SwiftUI das nicht an alle Zeilen weitergibt; oder jede Zeile mit `.wideListRow()` ausstatten — verworfen, weil es Abstände und Mac-Verhalten mitverändert. Alternative „Flächen gewollt, Bilder anders aufnehmen“ ist widerlegt: weiß kommt in der App-Farbwelt nicht vor.

### Dependencies
Upstream: SwiftUI-Listen (iPadOS 27), `Paper.ground`. Downstream: Start, Erledigt, Kataloge (Etiketten, Projekte), alle Listen im breiten iPad-Fenster; #742 Schnitt 1 (Store-Bilder neu aufnehmen).

### Open Questions
- [ ] Soll der iPad-UI-Test in der CI laufen? Dort läuft UI Smoke nur auf iPhone 17 (`CLAUDE.md`); ein iPad-Lauf wäre ein eigenes Ticket. Vorschlag: der Test läuft lokal über `LOOSEENDS_SIM="iPad Pro 13-inch (M5)" ./scripts/sim.sh test-proof PaperGroundTests`.
- [ ] Zeigt „Erledigt“ im Simulator dieselbe Fläche? Klärt der rote Test.
