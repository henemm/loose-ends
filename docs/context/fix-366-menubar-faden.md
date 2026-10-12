# Context: fix-366-menubar-faden

## Request Summary
Henning (2026-10-12): Das Menüleisten-Symbol der Mac-App soll der Knoten mit dem losen Faden aus dem
Logo sein statt des Apple-Symbols `text.badge.plus`. Einfarbig, passt sich an Hell/Dunkel an.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/App/LooseEndsApp.swift:77` | `MenuBarExtra("Loose Ends", systemImage: "text.badge.plus")` — hier wird das Symbol gesetzt (`#if os(macOS)`) |
| `LooseEnds/Views/Thread.swift` | `ThreadShape(form: .knot)` und `ThreadGlyph`: der Faden als Form aus derselben Trochoide wie das Icon (a=90, b=230, t −3,5…3,0) |
| `docs/design/logo/README.md`, `layer-thread.svg` | Logo-Quelle: Strichstärke 72 auf 1024er Raster, runde Enden |
| `LooseEnds/Mac/MenuBarCapture.swift` | Panel hinter dem Symbol; unverändert |
| `LooseEndsTests/ThreadShapeTests.swift` | bestehende Tests der Form |

## Existing Patterns
- Das Logo ist die einzige Ausnahme der SF-Symbols-Regel (CLAUDE.md, #350: „the logo's thread … brand mark, not a control“).
- Der Faden ist eine `Shape`, kein Symbol und kein Bild (Thread.swift-Kommentar): eine Formel für Icon und App.
- Farbbudget: Die Menüleiste ist systemgesteuert einfarbig (Template), keine App-Farbe.

## Dependencies
- Upstream: `ThreadShape` (SwiftUI, liegt in `LooseEnds/Views`, kompiliert nur in der App).
- Downstream: nichts hängt am Menüleisten-Symbol außer `MenuBarExtra`; UI-Tests greifen über `menuBarOpenApp`/`menuBarQuit` auf das Panel, nicht auf das Symbol.

## Existing Specs
- Keine Spec zum Symbol. #356 (Menüleiste) ist gemergt.

## Risks & Considerations
- **Template-Darstellung:** Ein SwiftUI-`Shape` im `MenuBarExtra`-Label wird womöglich nicht als Template (Systemtönung) gerendert. Sicherer Weg: `NSImage` mit `isTemplate = true` aus dem Pfad zeichnen. Im Prüfbau belegen, nicht annehmen.
- **Lesbarkeit:** Die Menüleiste ist etwa 18 pt hoch; die Lücke in der Kreuzung (Strich 72/1024) kann zulaufen. Der Entwurf zeigt Originalgröße, Retina und eine Alternative (dickerer Faden ohne Lücke).
- **Geräteliste:** kein Pfad berührt (`LooseEnds/App/` und `Views/` stehen nicht darin) → Abnahme endet nach Simulator/Mac-Prüfbau.
- Mac-Prüfbau ist der Nachweis (Screenshot Hell/Dunkel); iOS ist nicht betroffen.

## Analysis

### Type
Feature (kleine Änderung am Mac-Menüleisten-Symbol, kein Fehler).

### Recherche (Stand 2026-10-12)
- Eigene Menüleisten-Bilder müssen ein Template sein (`NSImage.isTemplate = true`, nur Schwarz + Transparenz, ca. 18 pt), sonst stimmt die Tönung in Hell/Dunkel nicht. Quellen: nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI, Apple-Forum 725960/726565 (Label-Inhalt von `MenuBarExtra` ist eingeschränkt).
- Ein SwiftUI-`Shape` im Label wird nicht verlässlich als Template gerendert; belegter Weg: Bild vorab rendern (`ImageRenderer`/`NSImage`) und als `Image(nsImage:)` ins Label geben.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | `MenuBarExtra(... systemImage:)` → `MenuBarExtra { } label: { Image(nsImage: MenuBarThreadImage.image) }`; Kommentar „SF Symbol, not the logo“ anpassen |
| `LooseEnds/Mac/MenuBarThreadImage.swift` | CREATE | zeichnet `ThreadShape(.knot)` per Core Graphics in ein 18-pt-`NSImage`, `isTemplate = true` (macOS only) |
| `LooseEndsTests/MenuBarThreadImageTests.swift` | CREATE | Bild ist Template, Größe 18 pt, nicht leer (Pixel gesetzt), Kreuzungslücke bei 2× vorhanden |

### Scope Assessment
- Files: 3 (+ ggf. `Thread.swift`, falls die Kurvenpunkte als gemeinsame Funktion herausgezogen werden, damit Bild und Shape dieselbe Formel nutzen)
- Estimated LoC: +80/−3
- Risk Level: LOW (isoliert, Panel und Erfassung unberührt)

### Technical Approach
Ohne Modell, reine Zeichnung. Die Punkte der Trochoide kommen aus derselben Formel wie `ThreadShape`; das Bild entsteht einmal beim Start. Template-Verhalten wird im Mac-Prüfbau in Hell und Dunkel belegt (Screenshot), nicht angenommen.

### Alternativen
- A Knoten, Logo-Strichstärke (Empfehlung) · B Knoten kräftiger (Rückfall, wenn die Kreuzungslücke bei 1× zuläuft) · C loser Faden ohne Kreuzung (andere Zeichnung, zeigt den Knoten nicht).
- Gekippte Entscheidung: keine ADR; nur die SF-Symbols-Regel (#350) hat die Logo-Ausnahme schon.

### Dependencies
`ThreadShape` (Views/Thread.swift) wird mitkompiliert; Mac-only über `#if os(macOS)`.

### Entwurf
`docs/artifacts/fix-366-menubar-faden/preview.html` (veröffentlicht: https://claude.ai/artifact/7NExY9sfpcvLQt24QMecmy). „Heute“ ist nachgezeichnet, kein Screenshot: ein echter Screenshot bräuchte einen Start auf Hennings Mac.

### Open Questions
- [x] Variante A (Henning, 2026-10-12); Wechsel auf B ohne Rückfrage, falls die Kreuzung bei 1× im Prüfbau zuläuft.
- [ ] Geräteliste: kein Pfad berührt → Abnahme Tests + Simulator/Mac-Prüfbau (Mac-Prüfbau läuft nur nach „jetzt ist ein Test möglich“).
