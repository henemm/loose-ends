# Context: feat-368-startseite-drei-zonen

## Request Summary
Epic #372 Startseite: Der iPhone-Startbildschirm bekommt drei Zonen statt einer gleich gewichteten Liste (#368,
Konzept 1, von Henning am 2026-10-12 freigegeben): Eingangsleiste für Neu, Block „Jetzt“ (überfällig, heute fällig,
vorgemerkt, jede Aufgabe einmal), „Passt gerade“-Chips (Schnell + Kontexte), kompakte „Alle Ansichten“. #339
(Fällig vs. Als nächstes, PR #340, CI grün, nicht gemergt) geht in Schnitt 1 auf.

## Schnitte (Intake 2026-10-12, Henning „go“)
1. Regel „Jetzt“ rein in `ViewRules` + Unit-Tests; nimmt die Regel aus PR #340 mit (schließt #339).
2. Eingangsleiste und Block „Jetzt“ in `SidebarView` (ersetzen Satz, Vorschau „Als nächstes“, Vorschau „Heute fällig“).
3. „Passt gerade“-Chips und kompakte „Alle Ansichten“.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/SidebarView.swift` (418 Z.) | Startseite. iPhone (`isCompact`): `header` (Datum + Satz `lead`, Tipp → Neu), `nextUpPreview` (erste 3), `dueTodayPreview` (#299, erste 3); darunter für alle Größen: `startViews`-Zeilen, Projekte/Kontexte einklappbar (`@AppStorage startShowsProjects/Contexts`), Alle offenen + Erledigt. Anlegen/Umbenennen/Löschen von Projekten und Kontexten lebt hier. |
| `Shared/Models/ViewRules.swift` (186 Z.) | `dueToday` (heute + überfällig, ohne blockiert), `badgeCount` (Next ∪ dueToday), `startViews` (`dailyViews` immer, `occasionalViews` nur mit Inhalt), `tasks(for:)`, `tasks(inContext:)`. Hier kommt die reine Regel „Jetzt“ hin. |
| `LooseEnds/Views/TaskInteractions.swift` | Wisch-/Halten-Aktionen je `ViewKind` (#303). Vorschauzeilen nutzen `.next` bzw. `.due`; im Block „Jetzt“ muss jede Zeile die Aktionen ihrer Herkunft tragen. |
| `LooseEnds/Notifications/DueNotificationCenter.swift:134` | einziger Produktnutzer von `badgeCount` — bleibt unverändert (Ticket). |
| `LooseEndsTests/DueTodayTests.swift`, `LooseEndsTests/StartViewsTests.swift` | Unit-Tests der bisherigen Startseiten-Regeln; PR #340 ändert `DueTodayTests`. |
| `LooseEndsUITests/StartScreenInteractionTests.swift` (353 Z.) | `testDueTodayShowsOnTheStartScreen` (`dueTodayPreview_`), `testPreviewRowSwipesToDoneAndBack`, `testPreviewRowHasLongPressMenu` (`nextUpPreview_`). |
| weitere UI-Tests | navigieren über `viewRow_new` (22×), `viewRow_open/done`, `projectRow_`, `projectsToggle`, `newProjectButton`, `contextsToggle`, `newContextButton` — Kennungen müssen erhalten bleiben oder die Tests mitziehen (ContextUniqueness, RecognitionWalkthrough, CalendarTarget, CaptureSmoke, ProjectSubtasks, DesignGallery, PlaceSmoke). |
| `LooseEnds/Resources/Localizable.xcstrings` | neue Strings DE/EN (Eingangsleiste, „Jetzt“, „Passt gerade“, „Alle Ansichten“). |
| `docs/project/03-design-briefing.md` (Z. 55–72) | Startseiten-Beschreibung inkl. #299-Satz „erscheint in beiden“ — wird ersetzt. |
| `docs/project/02-datenmodell-und-ansichten.md` | Berechnungsregeln der Ansichten; neue Regel „Jetzt“ ergänzen. |

## Existing Patterns
- Reine Regeln in `ViewRules` (statische Funktionen über `[TaskItem]`, `now`/`calendar` injizierbar), Unit-Tests mit `TestStore`.
- Farbbudget ADR-14: Akzent = tippbar, Rot = Zeitdruck (immer mit Text), Grau = Hierarchie. Symbole grau in `countRow`.
- Nur SF Symbols (#350). `.paperRow()`/`.paperList()` für den Papiergrund (#180). `@ScaledMetric` für Glyphen.
- Eine einzige `Section` oben auf dem iPhone, weil eine plain List über jedem Section-Header eine hohe Lücke setzt.
- iPad/Mac (`!isCompact`) behalten die Seitenleiste — der Umbau betrifft nur den kompakten Zweig.
- Abhaken mit Rücknahme-Fenster über `PendingCompletions` (#32), `actions.pendingRow`.

## Dependencies
- Upstream: `TaskItem` (`nextRank`, `dueDate`, `isBlocked`, `isOpen`, `duration.isQuick`, `contexts`), `ViewKind` (Titel, Symbol), `TaskContext`, `TaskInteractions`, `TaskRow`, `ThreadGlyph`.
- Downstream: `badgeCount` → App-Symbol; Navigation über `ViewSelection`; viele UI-Tests über Startseiten-Kennungen.

## Existing Specs
- `docs/specs/feat-319-alle-offenen.md` — „Alle offenen“ direkt über Erledigt.
- Keine Spec zu #180/#299/#303 im Ordner; Entscheidungen stehen im Design-Briefing.

## Risks & Considerations
- **Mockups nicht erreichbar:** Das Artefakt aus #368 (claude.ai/artifact/XB2dVUZDwip1e1RX3uz9fT) ist von dieser Sitzung aus nicht lesbar, und es gibt keine lokale Kopie. Grundlage ist der Ticket-Text. Die Analyse muss den Entwurf nach `docs/artifacts/feat-368-startseite-drei-zonen/` neu aufbauen und Henning zeigen (Regel „Entwurf vor Spec“).
- **Offene Regelfrage „Jetzt“:** Wo steht eine vorgemerkte Aufgabe, die zugleich überfällig ist — nach Zeitdruck (oben) oder bei „vorgemerkt“? PR #340 sagte „die manuelle Wahl gewinnt“ (für die Listen), #368 sagt „sortiert nach Zeitdruck“. Und: Reihenfolge innerhalb „vorgemerkt“ = `nextRank`?
- **Aktionen je Zeile:** Eine Zeile aus „Fällig“ wischt nach „Als nächstes“, eine aus „Als nächstes“ heraus — im Block „Jetzt“ ändert ein Wisch dann nur die Position, nicht die Sichtbarkeit. Muss in der Analyse geklärt werden.
- **Kontext-Chips:** Anzahl bei mehr als 4 Kontexten (Umbruch oder horizontal scrollen); nur Kontexte mit Aufgaben oder alle? Projekte/Kontexte anlegen/umbenennen/löschen braucht weiter einen Ort.
- **UI-Test-Kennungen:** `viewRow_new` (22 Nutzungen) — die Eingangsleiste ist nur bei Neu > 0 sichtbar; „Neu“ muss in „Alle Ansichten“ erreichbar bleiben, sonst brechen Tests bei leerem Eingang.
- **Scoping:** `SidebarView` ist schon 418 Zeilen; neue Zonen gehören in eigene Views, damit Funktionen ≤ 50 Zeilen bleiben.
- **Geräteliste:** keine Datei aus der Liste betroffen, solange `Shared/Persistence` unberührt bleibt → Abnahme endet nach dem Simulator.
- **#299-Entscheidung** („in beiden“) wird im Startbereich ersetzt; der App-Symbol-Zähler bleibt gleich (Vereinigung zählt jede Aufgabe einmal, egal ob die Listen disjunkt sind).

## Analysis

### Type
Feature (UI-Umbau iPhone-Startseite, Epic #372). Kein Bug: keine Reproduktion nötig.

### Befunde (2026-10-12)
- Mockup-Artefakt aus #368 nicht lesbar („artifact not found“, nicht in der eigenen Liste). Entwurf neu aufgebaut:
  `docs/artifacts/feat-368-startseite-drei-zonen/entwurf.html`, veröffentlicht als https://claude.ai/artifact/8BKFetJHMDv53DB6k9EBaP (Heute-Screenshots aus `DesignGalleryTests`, Entwurf A
  Empfehlung, Alternative B, hell und dunkel, echte Farben: Akzent #0F6E73/#5FC4C9, Papier #F4F3EE/#171816).
- `TaskInteractions` für `.next` und `.due` sind identisch (Default-Zweige: links Erledigt, rechts Vormerken/Lösen;
  Menü hängt nur an `task.nextRank`). → Ein Satz Aktionen (`interactions(.next)`) für alle Jetzt-Zeilen.
  Folge: „Aus Als nächstes entfernen“ auf einer fälligen Zeile lässt sie in „Jetzt“ stehen (wandert in die Zeitdruck-Gruppe). In die Spec.
- `TaskRow` färbt Fälligkeit heute/überfällig schon rot (mit Text) — Farbbudget erfüllt ohne neue Farbe.
- PR #340 (dueToday ohne nextRank) wird NICHT gemergt; `dueToday` und `badgeCount` bleiben unverändert, die neue
  Regel „Jetzt“ ersetzt sie nur im Startbereich. #339 und PR #340 werden mit Schnitt 1 geschlossen.
- Kein Chip-/FlowLayout im Code → eigenes `Layout` nötig (Schnitt 3).
- Chip-Zahl muss aus derselben Funktion kommen wie die Liste dahinter (`tasks(for: .quick)`, `tasks(inContext:)`;
  Letztere zählt blockierte mit).
- `viewRow_*`-Kennungen (~32 Nutzungen, 8 UI-Testdateien) bleiben, wenn „Alle Ansichten“ dieselben `countRow`s nutzt
  und nicht eingeklappt wird. Nur `nextUpPreview_` (2×) und `dueTodayPreview_` (1×) in `StartScreenInteractionTests` werden zu `nowRow_`.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Models/ViewRules.swift` | MODIFY | S1: `now(in:now:calendar:)` gruppiert (überfällig, heute, vorgemerkt), jede Aufgabe einmal; S3: Reihenfolge „Alle Ansichten“ |
| `LooseEndsTests/NowRuleTests.swift` | CREATE | S1: Reihenfolge, Einmaligkeit, blockiert/Unteraufgaben/erledigt draußen, badgeCount unverändert |
| `LooseEnds/Views/SidebarView.swift` | MODIFY | S2: `lead`, `nextUpPreview`, `dueTodayPreview` raus, Zonen rein; S3: „Alle Ansichten“ kompakt |
| `LooseEnds/Views/StartZones.swift` | CREATE | S2: `InboxBar`, `NowBlock` (max 5 + aufklappen); S3: `FitChips` |
| `LooseEnds/Views/FlowLayout.swift` | CREATE | S3: umbrechendes `Layout` für Chips |
| `LooseEndsUITests/StartScreenInteractionTests.swift` | MODIFY | S2/S3: Kennungen `nowRow_`, Eingangsleiste, Chip öffnet Ansicht |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Strings DE/EN |
| `docs/project/03-design-briefing.md`, `02-datenmodell-und-ansichten.md` | MODIFY | #299-Satz ersetzen, Regel „Jetzt“ |

### Scope Assessment
- S1: ~4 Dateien, ±180 LoC · S2: 5 Dateien, ~±250 LoC (Grenze; Doku ggf. nach S3) · S3: 5 Dateien, ~±280 LoC (knapp; FlowLayout ggf. vorziehen)
- Risk Level: MEDIUM — zentrale Seite, viele UI-Tests navigieren über sie; Regel und Navigation selbst klein.
- Geräteliste: kein Pfad berührt → Abnahme endet nach Stufe 2 (Simulator).

### Technical Approach (Empfehlung)
Drei Schnitte wie im Intake. S1 reine Regel mit gruppiertem Ergebnis (UI braucht die Herkunft nicht für Rot, aber für
„N weitere“ und Tests). S2 Eingangsleiste als eine Zeile mit `.tag(.system(.new))`, Jetzt-Block mit `previewRow(prefix: "nowRow_")`.
S3 Chips als `Button` mit `.buttonStyle(.plain)` + `selection = …` (mehrere Tippziele in einer List-Zeile), Kennungen `chip_quick`/`chip_<uuid>`.
Alle bisherigen `viewRow_*`, `projectsToggle`, `contextsToggle`, `newProjectButton`, `newContextButton` bleiben.

### Alternativen
- B (im Entwurf): Jetzt mit Unterzeilen ohne Obergrenze, Chips einzeilig scrollend, „Alle Ansichten“ einklappbar.
  Nachteil: verdeckte Kontexte rechts, schlecht bei großer Schrift; Einklappen versteckt `viewRow_*` vor UI-Tests.
- Ohne neue Regel: zwei Vorschauen behalten und nur #340 mergen (kleinster Schritt). Löst die Gewichtung nicht, gegen die PO-Entscheidung vom 12.10.

### Dependencies
Upstream: `TaskItem`, `ViewKind`, `TaskInteractions`, `TaskRow`, `ThreadGlyph`, `PendingCompletions`, `ViewSelection`.
Downstream: `badgeCount` → `DueNotificationCenter:134` (unverändert); `tasks(for:)` auch in `TaskDetailView` (unverändert).

### PO-Entscheidungen (Henning, 2026-10-12, Entwurf A freigegeben)
- [x] „Jetzt“: höchstens 5 Zeilen, darunter „N weitere“, klappt an Ort und Stelle auf.
- [x] Vorgemerkt + fällig: nach Zeitdruck oben (überfällig → heute fällig → übrige vorgemerkte nach `nextRank`); ersetzt #339-Regel, PR #340 wird geschlossen.
- [x] Chips: „Schnell“ zuerst, dann nur Kontexte mit ≥1 Aufgabe (Zahl aus derselben Funktion wie die Liste), umbrechend.
- [x] „Alle Ansichten“: graues Zwei-Spalten-Raster wie Entwurf A — Als nächstes, Fällig, Neu, Alt, Wartet, Wiederkehrend,
  Geparkt (nur bei Inhalt), Projekte, Kontexte, Alle offenen, Erledigt; Projekte/Kontexte weiter mit Anlegen/Umbenennen/Löschen.
  Technisch: mehrere Tippziele in einer List-Zeile → Buttons mit `selection = …`, Kennungen `viewRow_*` bleiben an den Zellen;
  Projekte/Kontexte-Zelle klappt die bisherigen Gruppen (`projectsToggle`/`contextsToggle`) auf.

### Open Questions
- keine

## Lieferplan nach Freigabe (2026-10-12)
- Spec `docs/specs/feat-368-startseite-drei-zonen.md` freigegeben (vier Schnitte: 1 Regel, 2 Eingangsleiste + Jetzt,
  3 Chips, 4 Raster).
- Das LoC-Gate (`scope_guard.max_loc_delta` 250) zählt je Workflow. **Dieser Workflow liefert nur Schnitt 1** (Regel
  `ViewRules.now`, `NowRuleTests`, Doku 02, `Closes #339`, PR #340 schließen). Kein `loc_limit_override`.
- Schnitte 2, 3, 4: je ein eigener Workflow über `/00-intake #368`, Grundlage dieselbe freigegebene Spec (Schnitt-Abschnitt
  zitieren); #368 bleibt offen bis Schnitt 4.
