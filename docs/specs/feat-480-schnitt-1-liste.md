---
entity_id: feat-480-schnitt-1-liste
type: feature
created: 2026-10-20
updated: 2026-10-20
status: draft
workflow: feat-480-mac-tastatur-zeiger
---

# Spec: #480 Schnitt 1 — Tastatur und Zeiger in den Listen der Mac-App

## Approval

- [ ] Approved (Henning)

Teil von Epic #467, Entwurf #408 (Tafel `docs/artifacts/feat-408-mac-entwurf/Grundlagen.dc.html`, Abschnitt „Zeiger und Tastatur“,
`docs/project/03-design-briefing.md:258-267`, freigegeben). Analyse: `docs/context/feat-480-mac-tastatur-zeiger.md`.
Vorbild für Technik und Belege: #477 (Liste), #544 (Mac-Klick-Tests), #479 (Galerie-Bilder).

**Schnitt.** Das Ticket verlangt Liste **und** Startseite sowie die Mindestgröße. Das sprengt die Grenze von 4 bis 5 Dateien.
Dieser Schnitt 1 liefert die Zuordnung Taste → Aktion, die Zeilenauswahl und die Akzentmarkierung **in den Listen**
(`TaskListView`: Ansichten, Kontexte, Projekte). Schnitt 2 (eigene Spec) bringt Startseite („Jetzt“-Zeilen, Hover dort) und die
Mindestgröße 760 × 520 pt. Dieses Ticket schließt erst Schnitt 2 (`Closes #480` dort, hier `Refs #480`).

## Purpose

In den Listen der Mac-App lässt sich eine Zeile mit den Pfeiltasten wählen. Die gewählte Zeile steht in Akzent 12 %. Die
Leertaste erledigt sie (mit dem Rückgängig-Fenster, #32), ⌫ löscht sie nach Rückfrage. Beides wirkt nur ohne Textfokus. Hover
in Grau 7 %, ⌘N, ⌘, und das Rechtsklick-Menü sind schon da und werden hier nur belegt.

**Rein regelbasiert.** Tastaturlogik ist deterministisch; kein Modell, kein Prompt, kein Schema. „Without the model this fails
because …“ entfällt, weil kein Feld abgeleitet wird.

**Entscheidung des PO (2026-10-20):** Pfeiltasten wählen, ein Klick öffnet die Aufgabe wie bisher und markiert die Zeile.

## Source

- **Neu:** `Shared/Models/RowKeyAction.swift` (reine Zuordnung, ohne SwiftUI)
- **Geändert:** `LooseEnds/Views/TaskListView.swift` (Auswahlzustand, Fokus, `onKeyPress`, nur `#if os(macOS)`)
- **Geändert:** `LooseEnds/Views/Paper.swift` (`WideListRow` bekommt den Zustand „gewählt“ in Akzent 12 %)
- **Neu:** `LooseEndsTests/RowKeyActionTests.swift`
- **Neu:** `LooseEndsUITests/MacKeyboardTests.swift`

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Models/RowKeyAction.swift` | CREATE | `RowKey` (up, down, space, delete) und `RowKeyAction.resolve(_:textFocused:selection:ids:)` → `.select(id)`, `.complete(id)`, `.delete(id)`, `.ignore`. Nur Foundation, kompiliert auch für Watch und Widgets |
| `LooseEnds/Views/TaskListView.swift` | MODIFY | `@State selectedID: UUID?`; Listenkörper fokussierbar; `onKeyPress` für ↑ ↓ Leertaste ⌫ ruft `resolve` und führt über **bestehende** `TaskInteractions.complete(_:)` bzw. `pendingDelete`/`confirmingDelete` aus; Klick auf die Zeile setzt `selectedID` zusätzlich zum Öffnen. Alles hinter `#if os(macOS)` |
| `LooseEnds/Views/Paper.swift` | MODIFY | `wideListRow(selected:)`: Hintergrund Akzent 12 % bei Auswahl, Grau 7 % bei Hover (Auswahl hat Vorrang). iOS-Zweig unverändert |
| `LooseEndsTests/RowKeyActionTests.swift` | CREATE | Tabelle der Zuordnung (siehe Test Plan) |
| `LooseEndsUITests/MacKeyboardTests.swift` | CREATE | Mac-UI-Test in der Sandbox-Anordnung von `MacDetailClickTests` (Hilfen aus `MacUITestSupport`, Präfix `mac`) |

### Estimated Changes

- Dateien: 5, innerhalb der Grenze von 4 bis 5.
- LoC: ca. +190/−10, unter 250. Überschreitet die Umsetzung 250, wird gestoppt und mit Schätzung nachgefragt.

Geräteliste: **Kein Pfad der Geräteliste berührt** (`Shared/Models`, `LooseEnds/Views`, Tests; weder `Shared/Persistence` noch
`project.yml`, Entitlements oder Info.plist). Keine Berechtigung, kein AppStorage-Schlüssel, kein Modellfeld, kein CloudKit-Schema.

## Implementation Details

**Zuordnung (rein).** `RowKeyAction.resolve(key, textFocused:, selection:, ids:)`; `ids` sind die gerade sichtbaren Zeilen in
Anzeigereihenfolge (eingeklappte Unteraufgaben zählen nicht). Verbindliche Tabelle:

| Zustand | ↓ | ↑ | Leertaste | ⌫ |
|---|---|---|---|---|
| `textFocused` | ignore | ignore | ignore | ignore |
| `ids` leer | ignore | ignore | ignore | ignore |
| keine oder unbekannte Auswahl | select(erste) | select(letzte) | ignore | ignore |
| Auswahl in der Mitte | select(nächste) | select(vorige) | complete(Auswahl) | delete(Auswahl) |
| Auswahl an der letzten Zeile | select(letzte) | select(vorige) | complete | delete |
| Auswahl an der ersten Zeile | select(nächste) | select(erste) | complete | delete |

An den Rändern bleibt die Auswahl stehen (kein Umlauf).

**Ausführung.** Keine neue Erledigen- oder Löschlogik: `complete` ruft `TaskInteractions.complete(_:)` (Rückgängig-Fenster
`PendingCompletions`, #32), `delete` setzt `pendingDelete` und `confirmingDelete` und löst damit den vorhandenen
`confirmationDialog("Delete this task?")` aus; gelöscht wird erst nach „Delete“ im Dialog. Eine Zeile im Rückgängig-Fenster
(`actions.isPending`) ignoriert die Leertaste (kein zweites Einplanen). Nach `didDelete` und wenn die gewählte Zeile aus der
Liste verschwindet (erledigt, verschoben), gilt die Auswahl als leer; es springt nichts automatisch weiter.

**Textfokus.** `onKeyPress` hängt am fokussierbaren Listenkörper und feuert nur bei Listenfokus. Zusätzlich übergibt die Ansicht
`textFocused` aus ihren eigenen Fokuszuständen (Suchfeld), damit die reine Regel auch dann `.ignore` liefert, falls der Fokus
einmal doppelt belegt ist. Leertaste tippt im Suchfeld ein Leerzeichen, ⌫ löscht dort ein Zeichen; es wird keine Aufgabe berührt.

**Klick.** Ein Klick öffnet wie bisher (`NavigationLink`, `MacDetailClickTests` unverändert) und setzt zusätzlich `selectedID`,
ohne das Öffnen zu verändern. Es gibt **kein** `List(selection:)`, damit das Klickverhalten aus #544 nicht kippt.

**Markierung.** `Color.accentColor.opacity(0.12)` als Zeilenhintergrund der gewählten Zeile, abgerundet 10 (wie der Hover);
Hover bleibt `Color.primary.opacity(0.07)`. Ist die Zeile gewählt, gewinnt Akzent. Akzent = antippbar/gewählt (Farbbudget, ADR-14).

**Plattform.** Alles hinter `#if os(macOS)`; die iOS-Zweige von `TaskListView` und `WideListRow` bleiben unverändert.

**Offene technische Punkte (im RED-Test zu entscheiden, nicht anzunehmen):**
- Wirken `onKeyPress` für Leertaste und ⌫ sowie die Pfeile an einer `List` mit `NavigationLink`-Zeilen verlässlich? Quellen
  (Apple-Foren 667366, 772806): auf macOS nur an fokussierbaren Views; `onDeleteCommand` an `List` ist unzuverlässig.
  Rückfall bei Misserfolg, im selben Dateisatz: `onDeleteCommand` bzw. Menübefehle mit `keyboardShortcut`.
- Greift die Liste die Pfeiltasten ohne `selection:` selbst ab (System-Fokusbewegung)? Wenn ja, wird der Fokusring der Zeile
  nicht als zweite Markierung sichtbar gemacht; bleibt es beim Akzent-Hintergrund.

### Alternativen

- **`List(selection:)` mit Systemauswahl** (mac-nativ, Finder-Verhalten: Klick wählt, Doppelklick öffnet): weniger eigener Code,
  aber ändert das Öffnen per Klick, braucht Umbau der Zeilen und gefährdet `MacDetailClickTests`/`StartScreenInteractionTests`.
  Verworfen auf Entscheidung des PO; kippt nichts in einer ADR.
- **Menübefehle statt `onKeyPress`** („Erledigen“ ⎵, „Löschen“ ⌫ im Menü Bearbeiten mit `keyboardShortcut`): sichtbar und
  auffindbar, aber Tasten ohne Modifikator im Menü kollidieren mit Texteingabe. Nur als Rückfall.
- **Vorschlag statt Aktion** (Leertaste markiert nur, ein zweiter Druck erledigt): unnötig, weil das Rückgängig-Fenster das
  Versehen auffängt.

## Test Plan

### Automated Tests (TDD RED)

- [ ] `RowKeyActionTests` (Unit): jede Zeile der Tabelle oben als eigener Fall, mindestens: Textfokus × vier Tasten → ignore;
  leere Liste × vier Tasten → ignore; ↓ ohne Auswahl → erste; ↑ ohne Auswahl → letzte; ↓ an letzter bleibt; ↑ an erster bleibt;
  Leertaste/⌫ ohne Auswahl → ignore; Leertaste/⌫ mit Auswahl → complete/delete der Auswahl; unbekannte Auswahl wie keine.
- [ ] `MacKeyboardTests.testArrowsSelectAndSpaceCompletes`: GIVEN drei offene Aufgaben in einer Liste WHEN ↓ ↓ Leertaste THEN
  die zweite Zeile ist gewählt, erscheint im Rückgängig-Fenster („Undo“), und nach Ablauf ist sie erledigt; die anderen bleiben.
- [ ] `MacKeyboardTests.testDeleteAsksFirst`: GIVEN eine gewählte Zeile WHEN ⌫ THEN erscheint „Delete this task?“; Abbrechen
  lässt die Aufgabe stehen; ⌫ und „Delete“ löscht genau diese.
- [ ] `MacKeyboardTests.testTextFocusKeepsKeys`: GIVEN eine gewählte Zeile und Fokus im Suchfeld WHEN Leertaste und ⌫ THEN
  bleibt jede Aufgabe offen und vorhanden, das Feld nimmt die Tasten.
- [ ] `MacKeyboardTests.testClickOpensAndMarks`: Klick auf eine Zeile öffnet sie wie bisher; zurück, die Zeile ist gewählt.
- [ ] `MacKeyboardTests.testShortcutsAndContextMenu`: ⌘, öffnet die Einstellungen; Rechtsklick zeigt das Zeilenmenü
  (`menuDelete` vorhanden); ⌘N öffnet die Neuaufnahme.
- [ ] `MacKeyboardTests.testSelectionPhotoLight` / `testSelectionPhotoDark`: Foto `mac-keyboard-selection-light/-dark`
  mit gewählter Zeile (Akzent 12 %), als Anhang des Testlaufs.

Die UI-Tests laufen im CI-Job „Mac Gallery (macOS)“ in der Sandbox der echten App (wie `MacDetailClickTests`); alle sind vor der
Umsetzung rot, weil weder Auswahl noch Tastenbehandlung existieren.

Bestehend, grün zu halten: `MacDetailClickTests`, `StartScreenInteractionTests`, alle UI-Tests mit Swipe-Aktionen und
`menuDelete`; iOS-UI-Smoke als Gegenprobe für die geteilte Ansicht; voller Unit-Lauf `./scripts/sim.sh sim-unit` (nie `unit`
auf dem Mac).

Simulator (Stufe 2): iPhone, eine Liste, Wischen/Löschen/Erledigen, vorher (`main`) und nachher, Bilder geöffnet und
beschrieben (unverändert). Mac: nur Bilder und Läufe aus der CI, nie von Hennings Mac.

## Acceptance Criteria

- **AC-1:** Die Zuordnung Taste → Aktion ist eine reine Funktion in `Shared/Models/RowKeyAction.swift` und folgt der Tabelle in
  „Implementation Details“. Beleg: `RowKeyActionTests` grün (alle Fälle der Tabelle).
- **AC-2:** In einer Liste wählen ↓ und ↑ die nächste bzw. vorige Zeile; ohne Auswahl wählt ↓ die erste, ↑ die letzte; an den
  Rändern bleibt die Auswahl. Beleg: `MacKeyboardTests.testArrowsSelectAndSpaceCompletes` grün.
- **AC-3:** Die gewählte Zeile steht in Akzent 12 % (hell und dunkel), Hover in Grau 7 %, bei beidem gewinnt Akzent. Beleg:
  Fotos `mac-keyboard-selection-light` und `-dark` aus dem CI-Lauf, geöffnet und beschrieben; Diff zeigt `opacity(0.12)` und
  `opacity(0.07)` in `WideListRow`.
- **AC-4:** Die Leertaste erledigt die gewählte Zeile über das Rückgängig-Fenster (#32); in dessen Frist lässt sich die Aufgabe
  zurückholen. Beleg: `testArrowsSelectAndSpaceCompletes` grün; Diff ruft nur `TaskInteractions.complete(_:)`.
- **AC-5:** ⌫ löscht die gewählte Zeile erst nach der Rückfrage „Delete this task?“; Abbrechen löscht nichts. Beleg:
  `testDeleteAsksFirst` grün; Diff nutzt nur `pendingDelete`/`confirmingDelete`, keine neue Löschlogik.
- **AC-6:** Mit Textfokus (Suchfeld) wirken Leertaste und ⌫ nicht auf Aufgaben. Beleg: `testTextFocusKeepsKeys` grün;
  `RowKeyActionTests` Fälle mit `textFocused`.
- **AC-7:** Ein Klick öffnet die Aufgabe wie bisher und markiert die Zeile; es gibt kein `List(selection:)`. Beleg:
  `testClickOpensAndMarks` und bestehende `MacDetailClickTests`, `StartScreenInteractionTests` grün.
- **AC-8:** ⌘N, ⌘, und das Rechtsklick-Menü der Zeile bleiben wirksam und sind belegt. Beleg: `testShortcutsAndContextMenu` grün.
- **AC-9:** iPhone und iPad bleiben unverändert: alle neuen Zweige hängen hinter `#if os(macOS)`. Beleg: Diff (iOS-Zweige von
  `TaskListView` und `WideListRow` ungeändert); iOS-UI-Smoke und voller Unit-Lauf grün; iPhone-Bild vorher/nachher gleich.
- **AC-10:** Kein neuer AppStorage-Schlüssel, kein Modell-, Schema- oder Rechte-Eingriff, keine neue Abhängigkeit. Beleg: Diff.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `TaskInteractions` (`complete`, `pendingDelete`, `confirmingDelete`, `isPending`) | module | Erledigen und Löschen; unverändert |
| `PendingCompletions`, `CompletionPulse` | module | Rückgängig-Fenster (#32); unverändert |
| `Paper` (`WideListRow`, `paperRow`) | module | Hover und neue Auswahlfarbe |
| `MacUITestSupport`, `MacDetailClickTests`, CI-Job „Mac Gallery (macOS)“ | test | Anordnung und Lauf der Mac-UI-Tests |
| Neue externe Abhängigkeit | – | keine |

## Außerhalb des Umfangs (Nicht-Ziele)

- Startseite („Jetzt“-Zeilen: Auswahl, Tasten, Hover Grau 7 %) und Mindestgröße 760 × 520 pt: **Schnitt 2**.
- Detailansicht, Seitenleiste, Aufgaben mit Unteraufgaben aufklappen per Taste.
- Mehrfachauswahl, Return öffnet, Tab-Reihenfolge, weitere Kurzbefehle.
- Klick wählt / Doppelklick öffnet (Finder-Verhalten): verworfen, siehe Alternativen.
- iPhone, iPad, Watch, Widgets; Modell, Schema, Rechte, AppStorage.

## Auslieferung

Abnahme: Stufe 1 Tests (Unit, iOS-UI-Smoke als Gegenprobe, `MacKeyboardTests` in der CI), Stufe 2 Simulator iPhone vorher/nachher
und Mac-Bilder aus dem CI-Artefakt. Satz im Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ Nach Schnitt 2 schaut Henning
über TestFlight (Mac) auf das Ganze; er bekommt die Buildnummer und die Prüfschritte (Liste öffnen, ↓ drücken, Leertaste, ⌫),
keine Befehlszeile. Kein Modell, deshalb kein `mac-schema-init`.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — reine Mac-Bedienung auf vorhandenen Aktionen, kippt keine ADR; ADR-14 (Akzent = antippbar/gewählt) wird
eingehalten.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt; `sim-unit` und iOS-UI-Smoke grün; `MacKeyboardTests` und die bestehenden Mac-Klick-Tests grün in der CI.
- [ ] Stufe 2: iPhone-Liste im Simulator vorher/nachher; Mac-Fotos aus dem CI-Artefakt geöffnet und beschrieben.
- [ ] Satz im Abschlussbericht: „Kein Pfad der Geräteliste berührt.“
- [ ] PR mit `Refs #480` (Schnitt 1); Board gepflegt; Belege unter `docs/artifacts/feat-480-mac-tastatur-zeiger/`; Schnitt 2 als
  eigener Workflow angelegt, bevor dieser Schnitt endet.

## Changelog

- 2026-10-20: Spec aus der Analyse `docs/context/feat-480-mac-tastatur-zeiger.md` geschrieben. Entscheidungen: Pfeiltasten wählen,
  Klick öffnet und markiert (PO); eigener Auswahlzustand statt `List(selection:)`; Schnitt 1 = Listen, Schnitt 2 = Startseite
  und Mindestgröße.
