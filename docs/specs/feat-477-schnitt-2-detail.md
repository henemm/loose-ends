---
entity_id: feat-477-schnitt-2-detail
type: feature
created: 2026-10-18
updated: 2026-10-18
status: draft
workflow: feat-477-schnitt-2-detail
---

# Spec: #477 Schnitt 2 — Detail im iPhone-Register, breiter (Mac und iPad)

## Approval

- [ ] Approved (Henning)

Teil-Spec von #477 (Epic #467). Analyse und Entscheidungen: `docs/context/feat-477-schnitt-2-detail.md` und
`docs/context/feat-477-mac-papierstil.md`. Entscheidungen von Henning am 2026-10-17 (Kommentare in #477): kein Erledigen-Haken in
der Leiste (#435 gilt, die Tafel `docs/artifacts/feat-408-mac-entwurf/Detail.dc.html` ist darin veraltet); das breite iPad zieht
mit; Mac-Bilder nur aus der CI (Artefakt `MacGallery`, #511), nie von seinem Mac; Beschriftung in normaler Schrift, leere Felder
als Wortleiste ohne Rahmen, keine Großbuchstaben-Spalte, keine umrandeten Chips. Die Liste (Schnitt 1) ist gemergt (PR #520).

## Purpose

Auf dem Mac und im breiten iPad-Fenster zeigt das Detail dasselbe Register wie das iPhone seit #438, nur breiter: Papier mit
Haarlinien statt grauer oder weißer Karten, Titel in New York 30 pt, Feldzeilen ohne Beschriftung „Title“ in einer Spalte neben
dem Titel, eine zentrierte Spalte von höchstens 760 pt. Das iPhone und das iPad im kompakten Fenster bleiben unverändert.

**Rein regelbasiert.** Reine Layout-Änderung über Größenklasse und Plattform; kein Modell, kein Prompt, kein Schema. Eine
Begründung „Without the model this fails because …“ entfällt, weil kein Feld abgeleitet wird.

## Source

- **Geändert:** `LooseEnds/Views/Paper.swift` (`detailRow()`, Breit-Weiche fürs Detail)
- **Geändert:** `LooseEnds/Views/TaskDetailView.swift` (Titel 30 pt breit, `labelsHidden`, Spalte, `paperRow` → `detailRow`)
- **Geändert:** `LooseEnds/Views/DetailLayout.swift` (reine Maße: Titelgröße, Spaltenbreite)
- **Geändert:** `LooseEndsTests/DetailLayoutTests.swift` (Tests der Maße)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Views/Paper.swift` | MODIFY | `detailRow()`: Papier hinter jeder Detailzeile auf allen Größen; auf kompakt dieselbe Wirkung wie `paperRow()` |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | Weiche `isWide`, Titel 30 pt nur breit, `.labelsHidden()` am Titelfeld, Spalte `frame(maxWidth:)` zentriert, 13 Aufrufe `paperRow()` → `detailRow()` |
| `LooseEnds/Views/DetailLayout.swift` | MODIFY | `titleSize(wide:)` (23 / 30) und `columnWidth` (760) als reine Regel |
| `LooseEndsTests/DetailLayoutTests.swift` | MODIFY | Tests der Maße |

`MacGalleryTests` bleiben unverändert: sie fotografieren das Detail schon (`mac-gallery-light-3-detail`,
`mac-gallery-dark-3-detail`) und warten auf `detailRawTextMarker`. Greift der bedingte Schritt 2 (siehe unten), wächst der Umfang
in `Paper.swift` und `TaskDetailView.swift`, aber es kommt keine weitere Datei hinzu.

### Estimated Changes

- Dateien: 4, innerhalb der Grenze von 5.
- LoC: ca. +80/-25 (Paper ~25, TaskDetailView ~35 einschließlich der 13 umbenannten Aufrufe, DetailLayout ~12, Tests ~25). Mit
  Schritt 2 (Weg 2) etwa +60 mehr. Überschreitet die Umsetzung 250, wird gestoppt und mit Schätzung nachgefragt.

Geräteliste: **Kein Pfad der Geräteliste berührt** (nur `LooseEnds/Views`, Tests). Keine Berechtigung, kein AppStorage-Schlüssel,
kein Modellfeld, kein CloudKit-Schema.

## Implementation Details

**Ausgangsbefund.** Die iPhone-Optik des Details kommt aus `Form` mit `.formStyle(.grouped)` und `paperRow()`. `PaperRow` wirkt
nur bei `horizontalSizeClass == .compact` (damit Seitenleisten ihre Auswahl behalten); auf breit und auf dem Mac fällt es weg, und
die Abschnitte werden zu Karten. Auf dem Mac zeigt das Titelfeld zusätzlich die Beschriftung „Title“ links als Spalte, und macOS
begrenzt `GroupedFormStyle` selbst auf etwa 600 pt Inhaltsbreite (Recherche in der Analyse; ob das unter macOS 27 noch gilt, zeigt
erst das CI-Bild).

**Weiche.** `isWide` in `TaskDetailView`: auf iOS `horizontalSizeClass != .compact`, auf dem Mac immer `true` (Größenklasse nil
zählt als breit, wie in Schnitt 1). Ein iPad in Split View oder Slide Over ist kompakt und bekommt die iPhone-Darstellung.

**Schritt 1 (Weg 1: Form behalten, Stil umschalten).** Der Behälter bleibt dieselbe `Form`; Wischgesten, Sheets, `fileImporter`,
`navigationDestination` und der Mac-Popover (#482) bleiben, weil sich nichts am Behälter ändert.

- `detailRow()` in `Paper.swift` setzt `listRowBackground(Paper.ground)` auf **allen** Größen (auf kompakt ist das heute
  `paperRow()`, also identisch); alle Abschnitte des Details nehmen `detailRow()` statt `paperRow()`. `paperRow()` selbst bleibt
  für Seitenleiste und Katalog unverändert.
- Titel: `DetailLayout.titleSize(wide:)` liefert 30 breit, 23 kompakt; `titleSize` bleibt `@ScaledMetric` (Basis 23 bzw. 30), New York
  medium, `tracking(-0.2)` wie heute.
- Titelfeld bekommt `.labelsHidden()`, damit auf dem Mac keine Beschriftung „Title“ vor dem Titel steht; die
  Barrierefreiheits-Beschriftung bleibt erhalten. Kennung `detailTitleField` bleibt.
- Spalte: auf breit `frame(maxWidth: DetailLayout.columnWidth)` (760) zentriert, das Papier läuft darunter randlos
  (`Paper.ground.ignoresSafeArea()`), damit außerhalb der Spalte keine Streifen stehen (Build 71). Auf kompakt kein `frame`.
- Auf kompakt ändert sich die Modifier-Kette nicht (nur die Umbenennung auf `detailRow()` mit gleicher Wirkung und Zusätze, die
  dort die Identität sind).

**Schritt 2 (bedingt, Weg 2 bzw. 600 statt 760).** Nach Schritt 1 werden zuerst der Simulator (iPad Querformat) und dann die
Mac-Galeriebilder `mac-gallery-light-3-detail` und `mac-gallery-dark-3-detail` aus dem CI-Lauf des PR geöffnet und beschrieben.
Schritt 2 wird umgesetzt, wenn **mindestens einer** der folgenden Punkte auf einem der Mac-Bilder zutrifft; jeder Punkt ist ein
Sichtbefund:

1. Die Abschnitte stehen noch als Karten (abgerundete, vom Papier abgesetzte Flächen) statt als Zeilen auf Papier mit Haarlinien.
2. Vor dem Titel steht noch die Beschriftung „Title“ als Spalte.
3. Die Form ist trotz `maxWidth: 760` sichtbar auf etwa 600 pt gekappt (Inhalt endet deutlich vor der gesetzten Spaltenbreite,
   Fläche beiderseits breiter als die Spalte).

Dann gilt: Punkt 1 oder 2 → Weg 2, das heißt auf breit `List` mit `.listStyle(.plain)` statt `Form`, gleiche Abschnitte, gleiche
Mechanik wie die Listen aus Schnitt 1 (`Toggle`, `Picker`, `TextField` in den Abschnitten werden einzeln im Bild und im
bestehenden UI-Test geprüft); Punkt 3 allein → Spalte auf 600 pt festlegen (`columnWidth` 600; „höchstens 760“ bleibt erfüllt).
Trifft keiner der drei Punkte zu, bleibt Schritt 1 und Schritt 2 entfällt. Nach Schritt 2 läuft die CI-Galerie erneut, und die
Bilder werden erneut beschrieben. Weg 2 trägt dieselbe Mechanik wie die gemergten Listen und ist deshalb der letzte Schritt in
dieser Spec.

**Kein Erledigen-Haken in der Leiste** (#435). Die Leiste (`actions`) bleibt unverändert; Erledigen bleibt im Menü
(`menuCompleteButton` unter `detailMoreMenu`) und mit `detailConfirmButton` im Bestätigungsweg.

**Beschriftung und leere Felder** bleiben, wie #438 sie festgelegt hat: Feldname grau in normaler Schrift in fester Spalte
(`labelWidth`), Wert in New York, leere Felder als Wortleiste „+ Due, + Importance …“ ohne Rahmen, keine Großbuchstaben-Spalte,
keine umrandeten Chips. Abschnittsköpfe bleiben `captionHead()`.

**Alle Funktionen bleiben**, Kennungen `field_*`, `detailTitleField`, `detailRawText`, `detailRawTextMarker`, `detailMoreMenu`,
`menuCompleteButton`, `detailConfirmButton`, `resetTitleButton` bleiben.

### Alternativen

- **Weg 2 gleich zu Beginn (`List .plain`):** trägt die Haarlinien sicher, kostet aber das Prüfen jedes Steuerelements in den
  Abschnitten und mehr Umfang. Nur als Rückfall, weil Weg 1 die kleinere Änderung ist und der Behälter gleich bleibt.
- **Weg 3, `.formStyle(.columns)` auf dem Mac:** keine Karten, aber Beschriftungsspalte und keine Abschnitte; widerspricht dem
  iPhone-Register. Verworfen.
- **Nur Mac statt Mac und iPad:** das breite iPad bliebe bei Karten. Von Henning entschieden: das iPad zieht mit.

## Test Plan

### Automated Tests (TDD RED)

Unit, `LooseEndsTests/DetailLayoutTests.swift` (Swift Testing; zuerst schreiben, rot, weil `titleSize(wide:)` und `columnWidth`
fehlen):

- [ ] `titleIsLargerOnWide`: GIVEN `wide: true` WHEN `DetailLayout.titleSize(wide:)` THEN 30; GIVEN `wide: false` THEN 23.
- [ ] `columnIsAtMost760`: GIVEN `DetailLayout.columnWidth` THEN 760 (bei Schritt 2 mit Punkt 3: 600, Test wird angepasst).
- [ ] `compactTitleSizeIsUnchanged`: GIVEN kompakt THEN dieselbe Größe wie vor der Änderung (23), damit das iPhone nicht wandert.

Bestehend, grün zu halten: `DetailLayoutTests` (alle bisherigen Fälle), `RecognitionWalkthroughTests` und die weiteren UI-Tests mit
`field_*`, `detailTitleField`, `detailMoreMenu`, `menuCompleteButton`, `detailConfirmButton`; voller Unit-Lauf; UI Smoke (alle
laufen auf dem iPhone, also kompakt). `./scripts/sim.sh sim-unit`, nie auf dem Mac.

Simulator (Stufe 2): iPad Querformat und iPhone, je `./scripts/sim.sh build`, `launch`, `screenshot` des Details einer Aufgabe mit
gesagtem Satz, gesetzten und leeren Feldern; Bilder werden geöffnet und beschrieben. iPhone zusätzlich vorher (Stand `main`) und
nachher.

Mac: Bilder `mac-gallery-light-3-detail` und `mac-gallery-dark-3-detail` aus dem CI-Job „Mac Gallery (macOS)“ (Artefakt
`MacGallery`) des PR-Laufs.

## Acceptance Criteria

- **AC-1:** `DetailLayout.titleSize(wide:)` liefert 30 für breit und 23 für kompakt, `DetailLayout.columnWidth` höchstens 760
  (Unit-Tests `titleIsLargerOnWide`, `columnIsAtMost760`, `compactTitleSizeIsUnchanged`).
- **AC-2:** Auf dem Mac zeigt das Detail Papier mit Haarlinien ohne Karten: die Abschnitte stehen als Zeilen auf der Papierfarbe,
  keine abgerundeten, abgesetzten Flächen. Beleg: Galeriebilder `mac-gallery-light-3-detail` und `mac-gallery-dark-3-detail` aus
  dem CI-Lauf, geöffnet und beschrieben (Papierfarbe hell und dunkel, Haarlinien zwischen den Feldzeilen, keine Kartenränder).
- **AC-3:** In denselben beiden Mac-Galeriebildern steht der Titel in New York, sichtbar größer als die Feldwerte (30 pt), ohne
  die Beschriftung „Title“ davor; der gesagte Satz steht unter dem Titel mit kleinem Kopf „GESAGT“ beziehungsweise „SAID“ wie auf
  dem iPhone, die Köpfe der Abschnitte in kleinen Großbuchstaben (Sichtbefund im Bild).
- **AC-4:** Die Spalte des Details ist auf dem Mac in den Galeriebildern mittig und höchstens 760 pt breit (Fenstergröße aus
  `mac-gallery-*-window-size`), das Papier läuft beidseits der Spalte ohne weiße oder graue Streifen bis zum Fensterrand.
- **AC-5:** Das iPad im breiten Fenster zeigt dasselbe Detail wie der Mac (Simulatorbild iPad Querformat: Papier mit Haarlinien,
  keine Karten, Titel 30 pt New York ohne Beschriftung „Title“, Spalte mittig und begrenzt), beschrieben.
- **AC-6:** Bedingter Schritt 2: Die Prüfung der drei Punkte (Karten, „Title“-Spalte, 600-pt-Kappung) ist an den Mac-Bildern
  durchgeführt und im Abschlussbericht je Punkt mit „trifft zu“ oder „trifft nicht zu“ festgehalten; trifft einer zu, ist die
  genannte Maßnahme umgesetzt und die Galerie danach erneut beschrieben, sodass kein Punkt mehr zutrifft.
- **AC-7:** Das iPhone und das iPad im kompakten Fenster bleiben unverändert: der Diff zeigt für kompakt keine geänderte
  Modifier-Kette (nur die Umbenennung `paperRow` → `detailRow` mit gleicher Wirkung und auf kompakt wirkungslose Zusätze), alle
  bestehenden UI-Tests und der volle Unit-Lauf sind grün, und das iPhone-Simulatorbild des Details zeigt vorher (`main`) und nachher
  denselben Titel (23 pt), dieselben Feldzeilen und Köpfe (Bildvergleich, beide beschrieben).
- **AC-8:** Alle Funktionen des Details bleiben auf breit erhalten: Titel bearbeiten und mit Return beenden, Feldzeile tippen öffnet
  den Editor (iPad Sheet-Seite, Mac Popover), Menü „Mehr“ mit Erledigen, Bestätigen. Beleg: im iPad-Simulator wird ein Feld
  geöffnet, der Titel geändert und das Menü gezeigt (Bilder beschrieben); die Kennungen `field_*`, `detailTitleField`,
  `detailMoreMenu`, `menuCompleteButton`, `detailConfirmButton` sind im Diff unverändert; in der Leiste ist kein Erledigen-Haken
  hinzugekommen (#435).

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `DetailLayout` | module | gesetzt/leer, Rohtext zeigen; bekommt die Maße als reine Regel |
| `Paper`, `paperRow`, `paperGround`, `captionHead`, `wideListRow` | module | geteilte Modifier; `detailRow` kommt hinzu, die übrigen unverändert |
| `FlowLayout`, `AddWordLabelStyle`, `FieldFormatting`, `editorPopover` | module | Wortleiste, Feldwerte, Mac-Popover; unverändert |
| Abschnitte `NoteSection`, `AttachmentsSection`, `SupplementSection`, `PlaceSection`, `SubtasksSection`, `WaitingOnSection` | module | `Section` in der Form; unverändert, nehmen `detailRow()` am Aufrufer |
| `MacGalleryTests`, CI-Job „Mac Gallery (macOS)“ (#511) | test | liefert die Mac-Bilder; unverändert |
| Neue externe Abhängigkeit | – | keine |

## Außerhalb des Umfangs

- **F002/F003 (Haarlinien der Listen):** die Haarlinie bei Zeilen ohne Randtext beginnt an anderer Stelle als bei Zeilen mit
  Randtext, und die Linie unter dem Abschnittskopf ist auf dem Mac dunkler als die Haarlinien. Beides betrifft `StartRow` und die
  Listen, nicht das Detail; mögliche Schnitt 3 von #477, wenn Henning es sehen will.
- Auswahl in Akzent 12 % und Tastaturauswahl: #480.
- Erledigen-Haken in der Leiste: entschieden dagegen (#435).
- Startseite, Seitenleiste, Katalog, Listen: unverändert.

## Auslieferung

Nach dem Merge läuft der TestFlight-Bau; Henning bekommt die Buildnummer und die Prüfschritte für den Mac (eine Aufgabe öffnen:
Papier, Haarlinien, großer Titel, mittige Spalte), keine Befehlszeile. Das ist die Definition of Done des Tickets und ein Schritt
nach dem Merge, kein Abnahmekriterium dieser Spec. Es ändert sich kein Modell, deshalb kein `mac-schema-init`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — keine neue Entscheidung. ADR-1 (eine Codebasis, Abweichungen über Größenklasse oder `#if os(macOS)`) bleibt
  und trägt die Weiche wie in Schnitt 1; kein Modell-, Schema- oder Persistenzeingriff.

## Definition of Done

- AC-1 bis AC-8 erfüllt; neue und alle bestehenden Unit-Tests grün (`./scripts/sim.sh sim-unit`, nie auf dem Mac), UI Smoke grün.
- Stufe 2: iPad breit und iPhone im Simulator gebaut, gestartet, fotografiert, Bilder beschrieben. Mac-Bilder aus dem CI-Artefakt
  `MacGallery`, nie von Hennings Mac.
- Satz im Abschlussbericht: „Kein Pfad der Geräteliste berührt.“
- PR mit `Closes #477`, weil das Detail der letzte Schnitt ist (Schnitt 3 nur auf Hennings Wunsch, dann als eigenes Ticket); Board
  gepflegt.

## Changelog

- 2026-10-18: Teil-Spec Schnitt 2 (Detail) aus der Analyse `docs/context/feat-477-schnitt-2-detail.md` geschrieben.
- 2026-10-18: Beleg-Entscheidung von Henning (Auswahl „iPad-Bild als Beleg“) nach den Mac-Galeriebildern des PR-Laufs: Das
  Galeriefenster ist 900 pt breit (Detailbereich etwa 650 pt) und die Galerie-Aufgabe hat keinen gesagten Satz. Deshalb
  werden die Spalte von höchstens 760 pt mittig (Teil von AC-4) und der Kopf „SAID“ mit dem gesagten Satz (Teil von AC-3) am
  iPad-Querformat-Bild `ipad-landscape-detail.png` belegt, nicht am Mac-Bild; Mac und breites iPad nehmen denselben Code. Am
  Mac-Bild bleiben belegt: Papier mit Haarlinien ohne Karten (AC-2), Titel New York groß ohne „Title“, Köpfe in
  Großbuchstaben (AC-3), Papier bis zum Rand ohne Streifen (AC-4). Wortlaut der Abnahmekriterien unverändert.
