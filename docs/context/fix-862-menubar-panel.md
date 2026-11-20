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

## Analysis

### Type
Bug (Nutzer- und Testfehler: nach Return oder „Open Loose Ends“ öffnet der erste Klick aufs Menüleistensymbol das Panel nicht)

### Ursache (Hypothese, belegt durch Quelltext, noch nicht in der CI nachgestellt)
Seit macOS 27 steuert AppKit ein `.window`-`MenuBarExtra` über eine private „expanded interface session“ am `NSStatusItem`
(Quelle: `orchetect/MenuBarExtraAccess`, `Sources/MenuBarExtraAccess/NSStatusItem+ExpandedInterfaceSession.swift`, Kommentar
Z. 11–30 und 62–72: Target/Action des Buttons sind nil, die Session ist non-nil, solange das Fenster gezeigt wird; ein Begin mit
einem Zeitstempel vor dem Ende der vorigen Session wird still verworfen). `MacWindows.closeMenuBarPanel()` schließt nur das
`NSWindow` (`close()`), die Session bleibt offen. Der nächste Klick beendet die verwaiste Session (sichtbar: nichts), erst ein
weiterer öffnet. Das passt zu `testWindowFromMenuBarFitsScreen` (zweiter Klick öffnet). Der rote `testPanelTypedGerman` (auch der
zweite Klick öffnete nicht) ist damit noch nicht ganz erklärt: Kandidat Entprellung (Zweitklick 15,6 s später, also eher nicht)
oder (b) unten — die Nachstellung muss das klären.
- (b) Wechsel der Aktivierungsrichtlinie in `applyDockPolicy`: im roten `testPanelTypedGerman` gab es kein Hauptfenster, die
  Richtlinie blieb also vermutlich `.accessory`; (b) ist dort unwahrscheinlich, aber nicht ausgeschlossen.
- Ausgeschlossen als Fix: `performClick` am Statusbutton (auf macOS 27 wirkungslos, Target/Action nil, gleiche Quelle).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | Panel über SwiftUIs eigenen Schließweg schließen (`@Environment(\.dismiss)` im `MenuBarCaptureView`) statt `NSWindow.close()`; `closeMenuBarPanel` entfällt oder bleibt nur als Rückfall |
| `LooseEndsUITests/MacGalleryTests.swift` (oder neue Klasse `MacMenuBarReopenTests.swift`) | MODIFY/CREATE | Nachstellung: frischer Start → Panel → tippen → Return → Symbol GENAU EINMAL → Panel da; Variante „Open Loose Ends“ → ⌘W → ein Klick |
| `LooseEndsUITests/MacUITestSupport.swift` | MODIFY | Zweitklick-Rückfall in `macOpenMainWindowIfNeeded` entfernen, sobald die Nachstellung grün ist |

### Scope Assessment
- Files: 2–3
- Estimated LoC: App-Code ca. +10/−5, Tests ca. +60
- Risk Level: MEDIUM — Verhalten hängt an nicht dokumentierter Systemmechanik; nur in der CI (macOS 27, `xcode-27`) prüfbar

### Technical Approach
1. TDD RED = Nachstellung: der Ein-Klick-Test muss mit dem heutigen Code in der CI rot sein (sonst ist die Ursache falsch → zurück
   in die Analyse). Die Tests hängen `debugDescription`/Zeitpunkte als Anhang an.
2. Fix: `dismiss` aus der SwiftUI-Umgebung des Panels (öffentliche API, nimmt SwiftUIs eigenen Weg und beendet die Session).
   „Open Loose Ends“: erst `dismiss()`, dann `showMain`.
3. GREEN: Ein-Klick-Tests grün, Zweitklick-Rückfall entfernt, Mac-Galerie in mehreren CI-Läufen beim ersten Versuch grün (DoD).

### Alternativen
- **MenuBarExtraAccess als Abhängigkeit** (`isPresented`-Bindung, macOS-27-Unterstützung über SPI): wenn `dismiss` die Session nicht
  beendet. Neue Abhängigkeit → PO-Freigabe; fiele: Regel „keine neuen Dependencies“.
- **Eigenes `NSStatusItem` + `NSPanel` statt `MenuBarExtra`**: volle Kontrolle, ca. 150–250 LoC, Fokus/Dunkel/Position neu; fiele: die
  Entscheidung aus #356 für `MenuBarExtra`.
- **SPI selbst aufrufen** (`expandedInterfaceSession.cancel`): klein, aber private API im App Store → nicht empfohlen.
- **Nur Test anpassen** (dritter Klick): verdeckt einen Nutzerfehler → verworfen.

### Dependencies
SwiftUI `MenuBarExtra(.window)`, AppKit `NSStatusItem` (macOS 27 Session-Mechanik), `MacAppDelegate`-Beobachter (`applyDockPolicy`).

### Open Questions
- [ ] Beendet `dismiss` im `MenuBarExtra`-Inhalt die Session? (klärt der GREEN-Lauf in der CI; falls nein → Alternative mit PO-Frage)
