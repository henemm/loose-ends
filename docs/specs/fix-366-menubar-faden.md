---
entity_id: fix-366-menubar-faden
type: feature
created: 2026-10-12
updated: 2026-10-12
status: draft
workflow: fix-366-menubar-faden
---

# Spec: #366 — Mac: Logo-Faden als Menüleisten-Symbol

## Approval

- [ ] Approved (Henning)

## Purpose

Henning (Issue #366, 2026-10-12): Das Menüleisten-Symbol der Mac-App soll nicht der Apple-Standard (`text.badge.plus`)
sein, sondern der Knoten mit dem losen Faden aus dem Logo. Einfarbig, passt sich an Hell und Dunkel an. Das Farb-Icon
ist für die Menüleiste ungeeignet. Das Logo ist die in `CLAUDE.md` (SF-Symbols-Regel, #350) genannte Ausnahme.

Entwurf ist freigegeben: **Variante A** (Knoten in Logo-Strichstärke, 72 von 1024), Henning 2026-10-12. Vorschau:
`docs/artifacts/fix-366-menubar-faden/preview.html`.

**Ist:** `MenuBarExtra("Loose Ends", systemImage: "text.badge.plus")` in `LooseEnds/App/LooseEndsApp.swift` (Z. 77, nur
macOS).

**Soll:** ein einfarbiges Template-Bild (`NSImage.isTemplate = true`, 18 pt hoch, 1x und 2x) des Knotens, aus derselben
Trochoide wie `ThreadShape`, im Label des `MenuBarExtra`.

### Warum ein vorgezeichnetes Bild

Recherche (Stand 2026-10-12): Eigene Menüleisten-Bilder müssen Templates sein (nur Schwarz plus Transparenz, ca. 18 pt),
sonst stimmt die Tönung in Hell und Dunkel nicht (nilcoalescing.com, „Build a macOS menu bar utility in SwiftUI“). Der
Label-Inhalt von `MenuBarExtra` ist eingeschränkt, ein SwiftUI-`Shape` wird dort nicht verlässlich als Template gerendert
(Apple-Forum 725960, 726565). Belegter Weg: Bild vorab zeichnen und als `Image(nsImage:)` ins Label geben.

Regelweg-Vermerk (Regeln vor Modell): Reine Zeichnung aus einer Formel, kein Modell beteiligt.

### Plattformfrage (geprüft)

Die Quellordner `LooseEnds` und `Shared` kompilieren in `project.yml` für iOS und macOS. Dateien unter `LooseEnds/Mac/`
werden deshalb auch für den iOS-Simulator übersetzt, ihr Inhalt steht in `#if os(macOS)` (so `MenuBarCapture.swift`). Die
Unit-Tests laufen im Simulator (Hennings Regel: nie auf dem Mac) und sehen daher nichts, was in `#if os(macOS)` steht.
Folge für den Schnitt:

1. **Plattformneutral (kompiliert im Simulator, getestet dort):** die Kurvenpunkte und das Rastern in ein `CGImage` per
   `CGContext` (CoreGraphics gibt es auf iOS und macOS).
2. **Nur macOS (`#if os(macOS)`, dünn):** die Hülle, die das `CGImage` als `NSImage` mit `isTemplate = true` und
   `size = 18 pt` verpackt.

## Lösung

1. `LooseEnds/Views/Thread.swift`: Die Punkteberechnung (a, b, Bereich, 120 Schritte, normiert) wird aus
   `ThreadShape.path(in:)` in eine gemeinsame Funktion `ThreadShape.curvePoints(form:)` (Rohpunkte, ungeskaliert)
   herausgezogen. `path(in:)` ruft sie auf; Verhalten und bestehende Tests unverändert.
2. `LooseEnds/Mac/MenuBarThreadImage.swift` (neu):
   - `MenuBarThreadRaster` (plattformneutral, außerhalb von `#if`): `static func cgImage(scale: Int) -> CGImage?` zeichnet
     den Knoten (`.knot`, `curvePoints`) in einen `CGContext` der Größe `(18 * scale)` Höhe, schwarz auf transparent,
     Strichstärke 72/1024 der Logo-Höhe, runde Enden und Ecken, einfaches Antialiasing, Kurve auf die Fläche mit kleinem
     Rand eingepasst (wie `ThreadShape`: die längere Seite füllt).
   - `MenuBarThreadImage` (`#if os(macOS)`): `static let image: NSImage` mit Darstellungen für 1x und 2x (je ein
     `NSBitmapImageRep` aus dem `CGImage`), `size` 18 pt Höhe, `isTemplate = true`. Einmal beim Start erzeugt.
3. `LooseEnds/App/LooseEndsApp.swift`: `MenuBarExtra("Loose Ends", systemImage: …) { … }` wird zu
   `MenuBarExtra { … } label: { Image(nsImage: MenuBarThreadImage.image) }`; die Beschriftung „Loose Ends“ bleibt als
   Barrierefreiheitsbezeichnung (`.accessibilityLabel`). Kommentar „SF Symbol, not the logo“ wird angepasst auf „the logo's
   thread, the one exception of #350“. Panel (`MenuBarCaptureView`) und `.menuBarExtraStyle(.window)` unverändert.

**Rückfall B (ohne Rückfrage):** Läuft die Kreuzungslücke bei 1x im Mac-Prüfbau zu (Knoten nicht mehr als Knoten
erkennbar), wird die Strichstärke angehoben und die Lücke weggelassen (kräftigerer Faden). Das ist eine Konstante im
Raster, keine Änderung des Schnitts; die Entscheidung steht im Abschlussbericht mit beiden Screenshots.

## Source

- **Geändert:** `LooseEnds/Views/Thread.swift` (Punkteberechnung herausgezogen)
- **Neu:** `LooseEnds/Mac/MenuBarThreadImage.swift`
- **Geändert:** `LooseEnds/App/LooseEndsApp.swift` (Label des `MenuBarExtra`)
- **Neu:** `LooseEndsTests/MenuBarThreadImageTests.swift`

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Views/Thread.swift` | MODIFY | `curvePoints(form:)` als gemeinsame Formel, `path(in:)` nutzt sie |
| `LooseEnds/Mac/MenuBarThreadImage.swift` | CREATE | CGContext-Raster (neutral) und Template-`NSImage` (macOS) |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | `MenuBarExtra` mit Bild-Label statt `systemImage:` |
| `LooseEndsTests/MenuBarThreadImageTests.swift` | CREATE | Tests des Rasters und der gemeinsamen Formel (Simulator) |

Geschätzt **+95 / −10 LoC**, 4 Dateien, innerhalb der Scoping-Limits (4–5 Dateien, ±250 LoC). Funktionen je ≤ 50 LoC.

**Geräteliste:** Kein Pfad der Geräteliste berührt (`LooseEnds/App/`, `LooseEnds/Mac/`, `LooseEnds/Views/` stehen nicht
darin; `project.yml` und Berechtigungen bleiben unverändert). Die Abnahme endet nach Stufe 2.

**Side-Effects:** Nur das Symbol in der Mac-Menüleiste ändert sich. Keine neuen Berechtigungen, keine Info.plist-Änderung,
keine AppStorage-Schlüssel, keine Audio-Dateien, kein Datenmodell. iOS, iPadOS, Watch, Widgets bleiben unberührt (die
Mac-Teile stehen hinter `#if os(macOS)`; `ThreadShape` verhält sich unverändert).

### Nicht in diesem Ticket

- Eine animierte oder zustandsabhängige Menüleisten-Grafik (z. B. beim Zuhören).
- Eine Änderung des Panels, der Erfassung, des Dock-Verhaltens oder des Anmeldeobjekts (#356).
- Eigene Bilddateien oder ein eigenes SF Symbol (der Faden bleibt eine Formel, siehe `Thread.swift`).

## Test Plan

### Automated Tests (TDD RED zuerst)

`LooseEndsTests/MenuBarThreadImageTests.swift` (Swift Testing, Simulator via `./scripts/sim.sh unit`; die Tests rufen nur
den plattformneutralen Teil auf):

- `curvePointsMatchThreadShape`: `ThreadShape(form: .knot).path(in:)` und das Raster verwenden dieselben Rohpunkte;
  `curvePoints(form: .knot)` hat 121 Punkte, der erste und der letzte Punkt entsprechen der Formel
  `x = 90·t − 230·sin t`, `y = −230·cos t` bei t = −3,5 und t = 3,0. Bestehende `ThreadShapeTests` bleiben grün.
- `rasterSizeIs18PointAtBothScales`: `cgImage(scale: 1)` ist 18 px hoch, `cgImage(scale: 2)` 36 px hoch; die Breite folgt
  dem Seitenverhältnis des Knotens.
- `rasterIsNotEmpty`: Bei 2x ist mindestens ein Pixel mit Alpha > 0 gesetzt, ein Pixel in einer Ecke ist transparent.
- `rasterIsBlackOnTransparent`: Alle Pixel mit Alpha > 0 haben die Farbe Schwarz (Voraussetzung für ein Template).
- `crossingGapExistsAt2x`: Am Kreuzungspunkt der Kurve liegen bei 2x beide Striche, zwischen den beiden Armen (Mitte der
  Lücke, aus den Kurvenpunkten berechnet) ist ein Pixel transparent. Belegt, dass der Knoten bei 2x als Knoten lesbar ist.
- `templateFlagAndSize` ist **nicht** im Simulator testbar (`NSImage`); dieser Teil ist per Mac-Prüfbau belegt (AC-2, AC-3).

**RED vor der Umsetzung:** Die Tests übersetzen nicht (Funktionen fehlen), der Lauf ist rot. **GRÜN nach der Umsetzung.**
Der volle Lauf `./scripts/sim.sh unit` bleibt grün (auch `ThreadShapeTests`).

### Abnahme (Stufen)

1. **Tests:** neue Tests rot (vorher), grün (nachher); `./scripts/sim.sh unit` grün.
2. **Simulator:** `./scripts/sim.sh generate`, `./scripts/sim.sh build` (iOS-App baut ohne Änderung, Regressionslauf);
   die iOS-Oberfläche ist nicht berührt, das wird am Simulator-Screenshot einer Liste mit dem Faden (z. B. dem
   Erledigt-Knoten oder dem Logo-Zustand) bestätigt. **Zusätzlich Mac-Prüfbau** (`./scripts/sim.sh mac`, „LE Prüfbau“,
   nie die normale Mac-App) mit Screenshot der Menüleiste in **Hell und Dunkel**. Der Mac-Prüfbau startet ein Programm auf
   Hennings Mac und läuft **nur nach seinem wörtlichen „jetzt ist ein Test möglich“**; bis dahin bleibt dieser Punkt offen.
3. **Gerät:** entfällt. „Kein Pfad der Geräteliste berührt.“

## Acceptance Criteria

- **AC-1 Gemeinsame Formel:** Given `ThreadShape` und das Raster / When beide den Knoten bilden / Then stammen die Rohpunkte
  aus derselben Funktion `curvePoints(form:)`; `ThreadShapeTests` bleiben unverändert grün.
- **AC-2 Template:** Given der Mac-Prüfbau / When die Menüleiste gezeigt wird / Then ist das Symbol ein Template-Bild
  (`isTemplate = true`, 18 pt, 1x und 2x) und nimmt die Systemtönung an: schwarz in der hellen, weiß in der dunklen
  Menüleiste. Beleg: Screenshot beider Modi.
- **AC-3 Erkennbar:** Given die Menüleiste in Originalgröße (1x) und Retina (2x) / When man den Knoten ansieht / Then ist
  die Kreuzung als Knoten mit losem Faden erkennbar. Läuft die Lücke bei 1x zu, gilt Rückfall B (kräftigerer Faden ohne
  Lücke) ohne Rückfrage, dokumentiert mit Screenshot.
- **AC-4 Raster:** Given `MenuBarThreadRaster.cgImage(scale:)` / When es bei 1x und 2x läuft / Then ist das Bild 18 bzw.
  36 px hoch, nicht leer, nur schwarz auf transparent, und die Kreuzungslücke ist bei 2x transparent (Simulator-Tests).
- **AC-5 Panel unverändert:** Given das neue Symbol / When man es anklickt / Then öffnet dasselbe Panel und erfasst wie
  bisher (Text, Mikrofon, Return speichert, Panel schließt); `menuBarOpenApp` und `menuBarQuit` funktionieren.
- **AC-6 Nichts sonst:** Der Diff berührt nur die vier genannten Dateien; iOS-, Watch- und Widget-Verhalten ändern sich
  nicht; alle bestehenden Tests grün; der iOS-Simulatorbau ist grün.

## Dependencies

| Komponente | Beschreibung |
|---|---|
| `ThreadShape` (`Views/Thread.swift`) | liefert die Formel (a = 90, b = 230, t −3,5…3,0) |
| CoreGraphics | `CGContext`/`CGImage`, auf iOS und macOS vorhanden |
| AppKit (`NSImage`, nur macOS) | Template-Hülle für das `MenuBarExtra`-Label |
| `docs/design/logo/README.md` | Strichstärke 72 auf dem 1024er Raster, runde Enden |

Keine neue Abhängigkeit.

## Risiken

- **Template-Rendering (mittel):** Ein SwiftUI-`Shape` im Label wird nicht verlässlich als Template gezeigt. Gegenmittel:
  vorgezeichnetes `NSImage` mit `isTemplate = true`; im Mac-Prüfbau in Hell und Dunkel belegt, nicht angenommen.
- **Lesbarkeit bei 18 pt (mittel):** Die Kreuzungslücke (72/1024) kann bei 1x zulaufen. Gegenmittel: Rückfall B, im Entwurf
  bereits gezeigt und freigegeben.
- **Simulator sieht den Mac-Teil nicht (niedrig):** Die `NSImage`-Hülle ist nur ein paar Zeilen; ihre Wirkung belegt der
  Mac-Prüfbau, die Zeichnung selbst ist im Simulator getestet.
- **Mac-Prüfbau braucht Freigabe (Ablauf):** ohne Hennings „jetzt ist ein Test möglich“ bleibt der Screenshot-Beleg offen.

## Alternativen

- **A Knoten in Logo-Strichstärke (gewählt, von Henning freigegeben).**
- **B Knoten kräftiger, ohne Kreuzungslücke:** gröber, immer lesbar; Rückfall, wenn A bei 1x zuläuft.
- **C Loser Faden ohne Kreuzung (`.loose`):** einfacher zu zeichnen, zeigt aber den Knoten nicht und ist weniger das Logo.
- **SwiftUI-`Shape` direkt im Label:** weniger Code, aber Template-Verhalten unzuverlässig. Verworfen.
- **Eigene Bilddatei (PDF/PNG) im Asset-Katalog:** verletzt „eine Formel für Icon und App“ und die Regel „keine eigenen
  Bilder“ außer dem Logo-Faden. Verworfen.

Keine frühere Entscheidung wird gekippt; die Logo-Ausnahme der SF-Symbols-Regel (#350) deckt den Faden bereits.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Darstellungsänderung eines Symbols, keine Architekturentscheidung

## Definition of Done

- AC-1 bis AC-6 erfüllt; neue Tests zuerst rot, dann grün; `./scripts/sim.sh unit` und `./scripts/sim.sh build` grün.
- Mac-Prüfbau-Screenshots Hell und Dunkel liegen im Ticket (nach Hennings „jetzt ist ein Test möglich“); Entscheidung
  A oder Rückfall B dokumentiert.
- Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“ und ohne Git-Vokabular.
- Der PR enthält `Closes #366`.

## Changelog

- 2026-10-12: Initiale Spec für #366 (Variante A freigegeben, plattformneutrales Raster, Template-Hülle nur macOS).
