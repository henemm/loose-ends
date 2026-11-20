# Context: fix-862-menubar-panel

## Request Summary
Der Mac-Galerie-Test `testPanelTypedGerman` wird in der CI gelegentlich rot („Menu bar panel shows no Open Loose Ends“) und erst
bei Wiederholung grün. Ziel (#862): beim ersten Versuch grün, Ursache belegt, Beleg über mehrere CI-Läufe.

## Befund aus Lauf 42269478152 (Logs beider Versuche, Intake 2026-11-20, Issue-Kommentar)
- **Rot:** Nach Return schließt `MacWindows.closeMenuBarPanel()` das Panel per `NSWindow.close()`. Kein Hauptfenster da
  (`startCaptureField` 10 s nicht gefunden), also Weg über das Menüleistensymbol: zwei Klicks (24,8 s und 40,4 s), danach je 10 s
  kein Panel.
- **Grün:** Nach Return war das Hauptfenster schon da; der Symbolweg wurde nicht betreten. Ob die App beim Start ein Fenster
  öffnet, schwankt in der CI (#513, geschlossen: Eigenheit des XCUITest-Starts, „nichts bauen“).
- **Gleiches Muster, grün:** `testWindowFromMenuBarFitsScreen` im roten Lauf: Panel zuvor über „Open Loose Ends“ geschlossen
  (wieder `closeMenuBarPanel`), ⌘W; der erste Symbolklick blieb wirkungslos, der zweite öffnete. Im grünen Versuch (kein Panel
  vorher) öffnete der erste Klick.
- Frische Starts (testSettings*, testStartNumber*, testPanel*): der erste Symbolklick öffnet immer.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Mac/MenuBarCapture.swift` | `MenuBarCaptureView` (Return → `closeMenuBarPanel`, „Open Loose Ends“ → `closeMenuBarPanel` + `showMain`); `MacWindows.closeMenuBarPanel()` (Z. 99: erstes sichtbares Key-`NSPanel` → `close()`); `applyDockPolicy` (wechselt `.regular`/`.accessory`); `MacAppDelegate` beobachtet `didBecomeKey`/`willClose` und ruft `applyDockPolicy` |
| `LooseEnds/App/LooseEndsApp.swift:229–237` | `MenuBarExtra { MenuBarCaptureView } label: { Image(nsImage:) }.menuBarExtraStyle(.window)` — keine Präsentationsbindung |
| `LooseEndsUITests/MacUITestSupport.swift:38–63` | `macOpenMainWindowIfNeeded`: wartet bis Panel weg, Klick, nach 10 s zweiter Klick, dann Fehler (Z. 57) — Rückfall aus #597 |
| `LooseEndsUITests/MacGalleryTests.swift:97–111, 312–328, 390–435` | `testWindowFromMenuBarFitsScreen`, `openPanel`, `testPanelTypedGerman` |
| `.github/workflows/ci.yml:533–` | Job „Mac Gallery (macOS)“, nur dort laufen Mac-UI-Tests (nie auf Hennings Mac) |

## Existing Patterns
- Wackelnde UI-Tests werden an der Ursache behoben, nicht per CI-Wiederholung (#172, #597).
- Mac-Bilder und Mac-UI-Tests nur in der CI (#511); Logs/xcresult als Artefakt `MacGalleryResults`.
- Fenster/Dock-Steuerung zentral in `MacWindows` (pure Regel `DockPolicy` unit-getestet).

## Dependencies
- Upstream: SwiftUI `MenuBarExtra` (`.window`-Stil, keine API zum programmatischen Schließen oder Abfragen des Zustands),
  AppKit `NSPanel`, `NSApp.setActivationPolicy`.
- Downstream: Nutzer-Ablauf „Menüleiste → tippen → Return / Open Loose Ends“ (#356, #400, #402, #479), alle Mac-Galerie-Tests,
  die über `macOpenMainWindowIfNeeded` gehen.

## Existing Specs
- `docs/specs/feat-479-mac-menueleiste.md`, `docs/specs/fix-402-menueleiste-layout.md`, `docs/specs/fix-366-menubar-faden.md`

## Recherche
- Kein Apple-Dokument oder Forum-Beitrag beschreibt „erster Klick nach programmatischem Schließen wirkungslos“.
  Apple-Forum 836113 (NSStatusItem unter macOS 27): andere Fehler (Hover, Hervorhebung, occlusionState).
- `orchetect/MenuBarExtraAccess` existiert, weil `MenuBarExtra` keine `isPresented`-Bindung hat; bietet Bindung und Zugriff auf das
  `NSWindow`. Neue Abhängigkeit → nur mit PO-Freigabe.

## Risks & Considerations
- Zwei Kandidaten für die Ursache, noch nicht getrennt: (a) `MenuBarExtra` hält seinen Zustand nach `NSWindow.close()` für „offen“;
  (b) der Wechsel der Aktivierungsrichtlinie in `applyDockPolicy` beim Schließen stört das Statussymbol.
- Ist (a) richtig, ist es ein Nutzerfehler (zwei Klicks nach Return), nicht nur ein Testproblem.
- Nachstellen geht nur in der CI (Lauf ≈ 30–40 min); ein deterministischer Reproduktionstest (Panel öffnen, Return, Symbol
  einmal klicken → Panel muss da sein) ist der Hebel.
- Ein reiner Test-Umbau (dritter Klick) würde einen echten Fehler verdecken.
