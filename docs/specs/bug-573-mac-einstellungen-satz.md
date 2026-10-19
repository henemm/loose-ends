---
entity_id: bug-573-mac-einstellungen-satz
type: bug
created: 2026-10-19
updated: 2026-10-19
status: approved
workflow: bug-573-mac-einstellungen-satz
---

# Spec: #573 — Mac-Einstellungsfenster nach der Tafel; „Felder“ nimmt den Klick auf der ganzen Zeile

## Approval

- [x] Approved (Henning, 2026-10-19: „#573 jetzt beheben“)

Henning, Build 92 auf dem Mac: „Optisch eine Katastrophe und UX auch – man muss Glück haben, um »Felder« zu öffnen.“
Das Galeriebild von #549 zeigt genau den ausgelieferten Stand; die freigegebene Tafel
`docs/artifacts/feat-408-mac-entwurf/Einstellungen.dc.html` zeigt etwas anderes. Befund und DoD in #573.

## Purpose

Das Fenster liest sich wie die Tafel: Köpfe bündig mit dem Zeilentext und mit Luft darüber, Haarlinien nur zwischen
Zeilen und unter der letzten Zeile eines Blocks, der Hinweis darunter ohne eigene Linie, Zeiten als Wert ohne
Stepper-Rahmen. Zeilen mit Pfeil nehmen den Klick auf der ganzen Zeile, zeigen Grau unter dem Zeiger und die Hand.
Rein Darstellung und Treffer; iPhone und iPad bleiben unverändert (Form grouped).

## Source

- **Geändert:** `LooseEnds/Views/SettingsView.swift` (Mac-Zweig von `group`, `clickRow()`/`hoverRow()`, `.datePickerStyle(.field)`)
- **Geändert:** `LooseEndsUITests/MacDetailClickTests.swift` (Klick in die Zeilenmitte von „Felder“)
- **Neu:** diese Spec

## Implementation Details

**Satz (`group`, Mac).** Kein `Section` mehr: Kopf, Zeilen und Hinweis sind Zeilen derselben Plain-List. Der Kopf ist
`captionHead()` mit Einzug `Paper.wideRowInsets.leading`, 24 pt Luft darüber, 6 pt darunter, untere Trennlinie
versteckt. Die Zeilen behalten `Paper.wideRowInsets` und mindestens 40 pt. Der Hinweis (Grau 12 pt) versteckt nur
seine untere Trennlinie: so steht die Haarlinie zwischen letzter Zeile und Hinweis (wie auf der Tafel) und keine unter
dem Hinweis; zwischen Hinweis und nächstem Kopf und unter dem Kopf gibt es keine Linie, weil eine Linie nur steht,
wenn beide Nachbarn sie zeigen. Ein Block ohne Hinweis endet mit der Linie unter seiner letzten Zeile.

**Treffer (`clickRow()`).** Ein Plain-Button in einer Liste trifft nur, was sein Label malt; ein `Spacer` malt nichts.
Das Label bekommt `frame(maxWidth: .infinity)` und `contentShape(Rectangle())`. `hoverRow()` legt Grau 7 % aus der
Tinte (wie `wideListRow()`, #477) 8 pt über den Inhalt hinaus und setzt `pointerStyle(.link)`; bei der
Kalenderzeile nur, wenn sie bereit ist.

**Zeit.** `datePickerStyle(.field)` am Behälter: Wert ohne Stepper, Eingabe per Tastatur bleibt.

**Höhe.** Die Tafel zeigt ein Fenster von 720 pt mit sechs Blöcken; die App hat mit den Abend- und Morgenzeilen
(#518) und „Felder“ (#538) rund 860 pt Inhalt. In 720 lag „Felder“ unter dem Rand (der erste CI-Lauf klickte
ins Leere: „not hittable“). Das Fenster bekommt 880 pt (`LooseEndsApp.swift`), damit jede Zeile ohne Scrollen
steht, wo der Bildschirm es zulässt; ein kleinerer Bildschirm scrollt, nichts geht verloren.

## Acceptance Criteria

- **AC-1:** Köpfe bündig mit dem Zeilentext, Luft darüber, keine Linie darunter (Galeriebilder hell und dunkel).
- **AC-2:** Haarlinien nur zwischen Zeilen und unter der letzten Zeile eines Blocks; keine unter einem Hinweis.
- **AC-3:** `MacDetailClickTests.testFieldsOpensFromTheMiddleOfItsRow`: ein Klick in die Mitte der Zeile „Felder“ öffnet
  die Seite; „Fertig“ schließt sie.
- **AC-4:** Zeitfelder ohne Stepper; `reminderTimePicker` und die beiden anderen Kennungen bleiben.
- **AC-5:** iPhone und iPad unverändert (UI-Smoke, `FieldsSmokeTests`).

## Abnahme

Stufe 1 und 2 in CI (Mac-Galerie mit Klicktest, UI-Smoke). Kein Pfad der Geräteliste berührt. Stufe 3 über TestFlight:
Henning öffnet ⌘, auf dem Mac und klickt „Felder“ irgendwo auf der Zeile.
