---
entity_id: bug-746-ipad-weisse-flaechen
type: bug
created: 2026-10-30
updated: 2026-10-30
status: draft
workflow: fix-746-ipad-weisse-flaechen
---

# Spec: #746 — iPad Hochformat: weiße Flächen auf Startseite und „Erledigt“

## Approval

- [ ] Approved

Befund aus der Bildprüfung von #742 (Schnitt 1). Henning, 2026-10-30: „Erst die App reparieren.“

## Purpose

Auf dem iPad im Hochformat steht die Detailspalte (Startseite, „Erledigt“, Kataloge) auf einer weißen Fläche, die so hoch ist
wie ihre Zeilen; darunter ist der Grund beige. Gewollt ist durchgehend das Papier-Beige (`Paper.ground`, #180).
Nachgestellt im Simulator (iPad Pro 13-inch (M5), Hochformat, `--ui-testing`): Startseite weiß von x=465 bis zum rechten Rand und
von y=125 bis y=463 (von 2000).

**Ursache.** `PaperRow` (`LooseEnds/Views/Paper.swift:81-96`) malt den beigen Zeilenhintergrund nur im schmalen Fenster
(`horizontalSizeClass == .compact`). Im breiten Fenster bleibt `.paperRow()` wirkungslos; die Listen der Detailspalte sind `.plain`
und zeichnen für Zeilen ohne eigenen Hintergrund den Systemhintergrund (weiß). Nur Zeilen mit `.wideListRow()` malen auch im
breiten Fenster. Die Seitenleiste (Seitenleisten-Stil, durchsichtige Zeilen) verlässt sich auf „breit = unverändert“.

## Source

- **Geändert:** `LooseEnds/Views/Paper.swift` — `PaperRow` malt auf iOS in jeder Fensterbreite `Paper.ground`; neue `sidebarRow()`
  mit dem bisherigen Verhalten (nur schmal malen) für die Seitenleiste
- **Geändert:** `LooseEnds/Views/SidebarView.swift` — alle sechs Aufrufe `.paperRow()` (Zeilen 133, 174, 192, 275, 305, 326; 305 und 326
  sind die Aufgabenzeilen der Seitenleiste mit `.tag(.task)`) werden `.sidebarRow()`
- **Neu:** `LooseEndsUITests/PaperGroundTests.swift` — iPad-Test mit Pixelprobe
- **Neu:** diese Spec

Nicht geändert: macOS (der Mac-Zweig von `PaperRow` bleibt wie er ist, Mac-Galerie und Fenstertests unberührt), iPhone (schmal malt
schon), Detailseite (`detailRow()`, `detailColumn`), Modell, `project.yml`.

## Implementation Details

`PaperRow.body` auf iOS: immer `content.listRowBackground(Paper.ground)`. `SidebarRow` ist die bisherige Fassung (schmal malen,
breit `content`). `View.sidebarRow()` neben `paperRow()`. Zeilen, die zusätzlich `.wideListRow()` tragen, setzen denselben
Hintergrund zweimal; das ändert nichts.

Verworfene Wege: den Zeilengrund am Listen-Behälter setzen (SwiftUI reicht `listRowBackground` nicht an alle Zeilen durch); jede
Zeile mit `.wideListRow()` ausstatten (ändert Abstände und Mac-Verhalten mit).

## Acceptance Criteria

- **AC-1:** iPad Pro 13-inch (M5), Hochformat, Startseite: der Farbwert in der Fläche einer Zeile (rechts neben der Seitenleiste)
  ist derselbe wie darunter im leeren Bereich (`PaperGroundTests.testStartPageRowsShareThePaperGround`). Vorher rot, nachher grün.
- **AC-2:** dasselbe auf „Erledigt“ mit einer erledigten Aufgabe, also mit der Fadenzeile (`PaperGroundTests.testDoneRowsShareThePaperGround`).
- **AC-3:** Die Seitenleiste bleibt wie bisher: Zeilen durchsichtig, Auswahlmarkierung sichtbar (Bildvergleich vorher/nachher der
  Seitenleiste; bestehende Smoke-Tests der Seitenleiste grün).
- **AC-4:** iPhone und Mac unverändert: UI-Smoke auf iPhone 17 und Mac-Galerie grün.
- **AC-5:** Vorher/nachher-Bilder von Startseite und „Erledigt“ liegen im Abschlussbericht.

## Scope

| Datei | Art | Schätzung |
|-------|-----|-----------|
| `LooseEnds/Views/Paper.swift` | MODIFY | +25 / -6 |
| `LooseEnds/Views/SidebarView.swift` | MODIFY | +6 / -6 |
| `LooseEndsUITests/PaperGroundTests.swift` | CREATE | +90 |

3 Dateien, rund +120 / -12 Zeilen, innerhalb der Grenzen (4–5 Dateien, ±250). Risiko niedrig bis mittel: Listen aller Detailansichten im breiten iPad-Fenster.

## Dependencies

| Abhängigkeit | Art |
|--------------|-----|
| `Paper.ground` (Farbasset „Paper“) | benutzt, unverändert |
| `StartPage`, `TaskListView`, `CatalogPage`, `Knaeuel`, `Beads`, `StartZones` | rufen `paperRow()` auf, ändern sich im Code nicht |
| #742 Schnitt 1 (Store-Bilder) | wartet auf dieses Ticket |

## Test Plan

| Test | Datei | Art | Erwartung |
|------|-------|-----|-----------|
| `testStartPageRowsShareThePaperGround` | `PaperGroundTests.swift` | UI, iPad Hochformat | Farbe in der Zeilenfläche = Farbe darunter; vorher rot |
| `testDoneRowsShareThePaperGround` | `PaperGroundTests.swift` | UI, iPad Hochformat | dasselbe auf „Erledigt“ mit Fadenzeile; vorher rot |
| bestehende Seitenleisten-Smoke-Tests, UI-Smoke iPhone 17, Mac-Galerie | vorhanden | UI | grün, unverändert |

## Definition of Done

- [ ] Fehler im Simulator nachgestellt (Startseite erledigt, „Erledigt“ im roten Test)
- [ ] Beide neuen Tests vorher rot, nachher grün
- [ ] Vorher/nachher-Bilder von Startseite und „Erledigt“ im Abschlussbericht
- [ ] Seitenleiste, iPhone, Mac unverändert (bestehende Tests grün)
- [ ] `./scripts/sim.sh store-screenshots` neu gelaufen, #742 Schnitt 1 weitergeführt

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — reine Darstellungskorrektur an einer bestehenden Regel (Papier-Beige, #180), kippt keine Entscheidung.

## Changelog

- 2026-10-30: Erstfassung (Workflow fix-746-ipad-weisse-flaechen); Seitenleiste mit allen sechs Aufrufen, nach Spec-Prüfung.

## Abnahme

Stufe 1 und 2: Unit-/UI-Tests, Simulator-Durchlauf auf dem iPad mit `./scripts/sim.sh test-proof PaperGroundTests`
(`LOOSEENDS_SIM="iPad Pro 13-inch (M5)"`). Der iPad-Test läuft lokal; in der CI läuft UI-Smoke nur auf iPhone 17, ein iPad-Lauf
wäre ein eigenes Ticket. Kein Pfad der Geräteliste berührt. Danach `./scripts/sim.sh store-screenshots` neu laufen lassen und
#742 Schnitt 1 abschließen.
