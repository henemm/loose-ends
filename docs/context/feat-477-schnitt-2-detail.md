# Context: #477 Schnitt 2 — Detail im iPhone-Register, breiter

Epic #467, Teil von #477. Schnitt 1 (Listen) ist gemergt (PR #520, Build 81). Die Gesamtanalyse mit allen Entscheidungen steht in
`docs/context/feat-477-mac-papierstil.md`; hier nur, was für den Detail-Schnitt zählt.

## Request Summary

Auf dem Mac und im breiten iPad-Fenster zeigt das Detail dasselbe Register wie das iPhone (#438), nur breiter: Titel 30 pt, Spalte
höchstens 760 pt, Papier mit Haarlinien statt grauer Karten. Das iPhone und das iPad im kompakten Fenster bleiben unverändert.

## Entschieden (Henning, 2026-10-17, Kommentare in #477)

1. Kein Erledigen-Haken in der Leiste (#435 gilt, die Tafel `Detail.dc.html` ist darin veraltet).
2. Das breite iPad zieht mit, derselbe Stil wie der Mac.
3. Mac-Bilder nur aus der CI (Mac-Galerie, #511, Artefakt `MacGallery`), nie von seinem Mac.
4. Beschriftung in normaler Schrift, leere Felder als Wortleiste ohne Rahmen, keine Großbuchstaben-Spalte, keine umrandeten Chips.

## Heute (aus den Belegen von Schnitt 1)

- Mac-Galerie und iPad-Bild zeigen das Detail als `Form .grouped`: jeder Abschnitt ist eine weiße oder graue Karte mit großem
  Radius, Titel klein (23 pt), Feldzeilen mit 92-pt-Beschriftungsspalte, Wortleiste „+ Due, + Importance …“ in einer Karte.
- Abschnittsköpfe (`captionHead`) sind schon Großbuchstaben, klein, grau (#438). Sie bleiben.

## Related Files

| Datei | Relevanz |
|---|---|
| `LooseEnds/Views/TaskDetailView.swift` (669 Z.) | `Form` + `.formStyle(.grouped)` + `.paperGround()`; `titleSize` 23 (Z. 31), Titelfeld Z. 59; Abschnitte tragen `.paperRow()` |
| `LooseEnds/Views/Paper.swift` | `paperGround`, `paperRow` (nur auf kompakt wirksam), `wideListRow` aus Schnitt 1; hier käme der Breit-Zweig fürs Detail hin |
| `LooseEnds/Views/DetailLayout.swift` | reine Regel gesetzt/leer, Rohtext zeigen; bleibt |
| `NoteSection`, `AttachmentsSection`, `SupplementSection`, `PlaceSection`, `SubtasksSection`, `WaitingOnSection` | Abschnitte, jeweils `Section` in der Form; sollen unverändert bleiben |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift`, `MacGalleryTests` | nutzen `field_*`, `detailTitleField`, `detailMoreMenu`, `menuCompleteButton`, `detailConfirmButton` — Kennungen müssen bleiben |

## Existing Patterns

- Breit-Weiche: `horizontalSizeClass == .compact` auf iOS, auf dem Mac immer breit (`PaperList`, `PaperRow`, `WideListRow` in `Paper.swift`).
- Schnitt 1 hat den Stil über Modifier an derselben `List` umgeschaltet, nicht durch einen neuen Behälter.
- Skalierte Schriftmaße über `@ScaledMetric` (`titleSize`, `labelWidth`).

## Dependencies / Dependents

- Upstream: `FieldFormatting`, `RevisionService`, `CalendarSync`, `FlowLayout`, `AddWordLabelStyle`, `editorPopover` (Mac-Popover, #482).
- Downstream: `ContentView` (Detailspalte), `TaskListView` (NavigationLink), Widget-Einstieg öffnet `TaskDetailView` direkt.

## Existing Specs

`docs/specs/feat-438-detail-schrift.md` (Register iPhone), `docs/specs/feat-477-schnitt-1-liste.md` (Breit-Weiche, Haarlinien).

## Risks & Considerations

- **Form ohne `.grouped`:** Ein Register mit Haarlinien verlangt auf breit vermutlich `List(.plain)` oder `.formStyle(.columns)`. Wischgesten,
  Sheets, `fileImporter`, `NavigationLink` und Popover müssen erhalten bleiben (Weg B der Gesamtanalyse: gleiche `List`-Mechanik, nur Stil).
- **iPhone unberührt:** Jede Änderung braucht eine kompakt/breit-Weiche; Beleg per iPhone-Simulator-Bild vorher/nachher.
- **Mitnahme aus Schnitt 1 (Optik, LOW):** F002 — Haarlinie bei Zeilen ohne Randtext beginnt an anderer Stelle als bei Zeilen mit
  Randtext; F003 — Linie unter dem Abschnittskopf ist auf dem Mac dunkler als die Haarlinien. Beides betrifft die Listen, nicht das Detail;
  gehört in diesem Schnitt in dieselbe Haarlinien-Regel, sonst Folge-Ticket.
- **Umfang:** Ziel 2–3 Dateien, ca. 150 LoC. Über 250 LoC: Teilung 2a (Behälter, Titel, Felder) und 2b (Feinschliff).
- **Parallele Sitzungen:** loose-ends-73 und loose-ends-88 laufen; vor der Spec `git fetch` und Offene-PR-Suche (Memory „Vor Schnitt prüfen“).
- **Geräteliste:** keine betroffenen Pfade (nur `LooseEnds/Views`, Tests, Texte). Abnahme endet nach Stufe 2: iPad-Simulator breit, Mac aus der CI-Galerie.

## Analysis

### Type
Feature (Teil von #477, Epic #467). Entwurf: Henning hat Vorschau „Heute neben Entwurf“ am 2026-10-17 freigegeben (Entscheidung 4); keine neue Vorschau nötig.

### Befund (Ist-Zustand, aus den Belegen von Schnitt 1)
- Die iPhone-Optik des Details kommt aus `Form(.grouped)` + `paperRow()` = `listRowBackground(Paper.ground)`. `PaperRow` ist aber nur bei `horizontalSizeClass == .compact` wirksam (damit Seitenleisten ihre Auswahl behalten). Auf breit/Mac fällt es weg → graue/weiße Karten.
- Mac: Das Titelfeld zeigt die Feldbeschriftung „Title“ links als Spalte (Form-Layout), der Titel steht rechts. Auf dem iPad nicht.
- Titel 23 pt (`titleSize`), keine Breitenbegrenzung.
- Recherche: macOS 15+ begrenzt `GroupedFormStyle` selbst auf 600 pt Inhaltsbreite (Apple-Forum „SwiftUI Form (Grouped) with Table“/„Form under macOS looks like iOS“); `.formStyle(.columns)` ist der macOS-Standard ohne Abschnitte. `listRowBackground` wirkt am Zeileninhalt, nicht an der Form (createwithswift.com, Apple Docs `FormStyle.grouped`).

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEnds/Views/Paper.swift | MODIFY | `detailRow()` (Paper-Hintergrund immer, auch breit) und Breit-Weiche fürs Detail |
| LooseEnds/Views/TaskDetailView.swift | MODIFY | Titel 30 pt breit, `labelsHidden` am Titelfeld, Spalte ≤ 760 pt, `paperRow` → `detailRow` |
| LooseEndsUITests/…Gallery/Detail-Test | MODIFY | Bildbeleg iPad breit + Mac-Galerie (Kennungen bleiben) |

### Scope Assessment
- Files: 2–3, Estimated LoC: +60/-15, Risk Level: MEDIUM (Mac-Verhalten der Form nur aus der CI sichtbar; iPhone muss pixelgleich bleiben)

### Technical Approach
Rules/kein Modell: reine Layout-Änderung, „Without the model…“ entfällt.
Empfehlung (Weg 1): Form behalten, nur Stil umschalten, wie in Schnitt 1 — eigener `detailRow()`, der den Paper-Hintergrund auf allen Größen setzt; Titel 30 pt nur breit; `.frame(maxWidth: 760)` zentriert; Titelfeld `.labelsHidden()`. Wischgesten, Sheets, `fileImporter`, Popover bleiben, weil der Behälter derselbe ist.
Alternativen:
- Weg 2: `List(.plain)` statt `Form` auf breit (gleiche Mechanik wie Listen in Schnitt 1). Kippt nichts am ADR, aber `Toggle`/`Picker`/`TextField` in den Abschnitten müssten einzeln auf List-Verhalten geprüft werden. Fallback, falls Weg 1 auf dem Mac nicht trägt.
- Weg 3: `.formStyle(.columns)` auf dem Mac. Keine Karten, aber Beschriftungsspalte und keine Abschnitte — widerspricht dem iPhone-Register.
Entscheidungspunkt ist die 600-pt-Kappung der Mac-Form: gilt sie, gewinnt Weg 2 oder 600 statt 760 („höchstens 760“ bleibt erfüllt).
Reihenfolge: erst iPad-Simulator-Bild (breit), dann Mac-Galerie aus der CI; fällt das Mac-Bild durch, Weg 2 in derselben Spec als zweiter Schritt.
F002/F003 (Haarlinien der Listen) bleiben außerhalb; sie betreffen `StartRow`, nicht das Detail → Folge im selben Ticket #477 als Schnitt 3, falls Henning sie sehen will.

### Dependencies
`DetailLayout`, `FlowLayout`, `AddWordLabelStyle`, `FieldFormatting`; UI-Tests nutzen `detailTitleField`, `field_*`, `detailMoreMenu` (Kennungen bleiben).

### Open Questions
- [ ] Trägt `listRowBackground` in `Form(.grouped)` auf macOS 27 (Hintergrund + Haarlinien)? Nur per CI-Bild zu klären → Spec-Schritt 2.
- [ ] Gilt die 600-pt-Kappung der Mac-Form noch unter macOS 27?
