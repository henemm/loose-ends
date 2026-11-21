---
entity_id: fix-862-menubar-panel
type: bugfix
created: 2026-11-20
updated: 2026-11-20
status: draft
workflow: fix-862-menubar-panel
---

# Spec: #862 Menüleisten-Panel öffnet nach Return und „Open Loose Ends“ beim ersten Klick

## Approval

- [ ] Approved (Henning)

## Purpose

Das Panel der Mac-Menüleiste (Schnellerfassung, #356) schließt sich nach Return und nach „Open Loose Ends“ über
`NSWindow.close()`. Danach öffnet der nächste Klick aufs Menüleistensymbol das Panel nicht; erst der zweite öffnet es. Für
Henning heißt das: nach dem Speichern einer Aufgabe per Return braucht er zwei Klicks, um die nächste zu erfassen. In der CI
zeigt sich dasselbe als wackelnder Test (`testPanelTypedGerman`, „Menu bar panel shows no Open Loose Ends“; zusätzlich
`testWindowFromMenuBarFitsScreen`). Ziel: Das Panel schließt sich über den Weg, den SwiftUI selbst vorsieht, und das Symbol
öffnet es danach mit einem Klick; der Zweitklick-Rückfall im Test entfällt.

**Hat es bisher funktioniert?** Ein früherer guter Stand ist nicht belegt: Seit #597 trägt `macOpenMainWindowIfNeeded` einen
Zweitklick-Rückfall, der das Muster schon damals verdeckte. Analyse und Belege (Lauf 42269478152, beide Versuche) in
`docs/context/fix-862-menubar-panel.md`.

## Ursache (Hypothese, in der CI noch nicht nachgestellt)

Seit macOS 27 steuert AppKit ein `.window`-`MenuBarExtra` über eine private „expanded interface session“ am `NSStatusItem`
(Quelle: `orchetect/MenuBarExtraAccess`, `NSStatusItem+ExpandedInterfaceSession.swift`: Target/Action des Buttons sind nil, die
Session ist non-nil, solange das Fenster gezeigt wird). `MacWindows.closeMenuBarPanel()` schließt nur das `NSWindow`; die
Session bleibt offen, der nächste Klick beendet sie (sichtbar: nichts), erst der übernächste öffnet.

Nicht ganz erklärt: Im roten `testPanelTypedGerman` öffnete auch der zweite Klick nicht (15,6 s später, Entprellung also
unwahrscheinlich). Kandidat (b), der Wechsel der Aktivierungsrichtlinie in `applyDockPolicy`, ist dort unwahrscheinlich
(kein Hauptfenster, Richtlinie vermutlich `.accessory`), aber nicht ausgeschlossen. Die Nachstellung (AC-1, AC-2) trennt das.

**Abbruchregel:** Sind die Nachstellungstests (Test 1 und 2) mit dem heutigen Code grün, ist die Ursache falsch. Dann kein
Fix, Rückkehr in die Analyse.

## Source

- **File:** `LooseEnds/Mac/MenuBarCapture.swift`
- **Identifier:** `struct MenuBarCaptureView`, `MacWindows.closeMenuBarPanel()`

## Lösung

1. **`LooseEnds/Mac/MenuBarCapture.swift`.** `MenuBarCaptureView` liest `@Environment(\.dismiss)`. Return (Abschluss von
   `CaptureView`): Rules anstoßen wie bisher, dann `dismiss()` statt `MacWindows.closeMenuBarPanel()`. „Open Loose Ends“: erst
   `dismiss()`, dann `MacWindows.showMain { openWindow(id:) }`. `MacWindows.closeMenuBarPanel()` hat nur diese zwei Aufrufer
   (geprüft per Suche im Repo; sonst nur ein Testkommentar und Specs) und entfällt.
2. **`LooseEndsUITests/MacGalleryTests.swift`.** Zwei neue Tests (Test 1 und 2, unten), die der CI-Job „Mac Gallery (macOS)“
   über `-only-testing:LooseEndsUITests/MacGalleryTests` ohne Änderung an `ci.yml` mitnimmt. Der Kommentar in
   `testPanelTypedGerman` („`closeMenuBarPanel` closes the panel's window“) wird angepasst.
3. **`LooseEndsUITests/MacUITestSupport.swift`.** In `macOpenMainWindowIfNeeded` entfällt der Zweitklick-Rückfall und die
   Wartezeit auf ein sich schließendes Panel; ein Klick, dann `waitForExistence`.

Reihenfolge (TDD): zuerst nur Schritt 2 pushen und den CI-Lauf abwarten (RED, Abbruchregel beachten), dann Schritt 1 und 3.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | `dismiss` aus der SwiftUI-Umgebung statt `NSWindow.close()`; `closeMenuBarPanel` entfernt |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | zwei Ein-Klick-Nachstellungstests, Kommentar in `testPanelTypedGerman` |
| `LooseEndsUITests/MacUITestSupport.swift` | MODIFY | Zweitklick-Rückfall in `macOpenMainWindowIfNeeded` entfernt |

### Estimated Changes

- Files: 3
- LoC: App-Code ca. +10/−15; Testcode ca. +60 bis +80 (zählt nicht gegen ±250)

Keine Änderung an `project.yml`, `Info.plist`, Entitlements oder AppStorage-Schlüsseln, keine neue Abhängigkeit.

**Geräteliste (CLAUDE.md):** Berührt werden `LooseEnds/Mac/` und `LooseEndsUITests/`; beide stehen nicht auf der Liste.
Kein Pfad der Geräteliste berührt.

## Test Plan

Mac-UI-Tests laufen nur im CI-Job „Mac Gallery (macOS)“ (macOS 27, App Sandbox), nie auf Hennings Mac. Beide Tests hängen
Zeitpunkte der Klicks und `app.debugDescription` als Anhang (`.keepAlways`) an, damit ein roter Lauf auswertbar ist.

### Automated Tests (TDD RED)

- [ ] Test 1 (`testMenuBarReopensAfterReturnWithOneClick`): GIVEN ein frischer Start und das Panel über das Symbol geöffnet
  WHEN Text getippt, Return gedrückt und das Symbol danach genau einmal geklickt wird THEN ist das Panel (`menuBarOpenApp`)
  innerhalb von 10 s wieder da. Mit dem heutigen Code muss er rot sein.
- [ ] Test 2 (`testMenuBarReopensAfterOpenAppWithOneClick`): GIVEN ein frischer Start WHEN „Open Loose Ends“ im Panel geklickt,
  das Hauptfenster erscheint, ⌘W es schließt und das Symbol genau einmal geklickt wird THEN ist das Panel innerhalb von 10 s da.
  Mit dem heutigen Code muss er rot sein.
- [ ] Test 3 (bestehend, `testPanelTypedGerman`): GIVEN das deutsche Panel mit getipptem Text WHEN Return gedrückt wird THEN
  schließt das Panel, das Hauptfenster öffnet über den Symbolweg ohne Zweitklick und New zeigt die Aufgabe.
- [ ] Test 4 (bestehend, `testWindowFromMenuBarFitsScreen`): GIVEN das Hauptfenster über die Menüleiste geöffnet und per ⌘W
  geschlossen WHEN das Symbol einmal geklickt wird THEN öffnet das Fenster über „Open Loose Ends“ und passt auf den Bildschirm.

### Abnahme (Stufen)

1. **Tests:** RED-Lauf der CI mit nur den neuen Tests (beide rot, sonst Abbruchregel), GREEN-Lauf nach dem Fix. Unit-Tests und
   iOS-Bau bleiben grün (`./scripts/sim.sh sim-unit`, `./scripts/sim.sh build`); `MenuBarCapture.swift` ist `#if os(macOS)`.
2. **Simulator / Benutzung:** Die Mac-Klassen laufen nur im CI-Job „Mac Gallery (macOS)“; dort öffnet die echte Mac-App, das ist
   die Stufe für diese Änderung. `test-proof` im iOS-Simulator greift nicht. Beleg: Artefakte `MacGallery` und
   `MacGalleryResults`, Anhänge der beiden neuen Tests geöffnet und beschrieben.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given ein frischer Start, das Panel über das Symbol geöffnet, Text getippt und Return gedrückt / When das Symbol genau
  einmal geklickt wird / Then ist das Panel innerhalb von 10 s da. Belegt durch Test 1, zuerst rot im CI-Lauf mit dem heutigen
  Code, dann grün.
- **AC-2:** Given ein frischer Start, „Open Loose Ends“ geklickt, Hauptfenster da und per ⌘W geschlossen / When das Symbol genau
  einmal geklickt wird / Then ist das Panel innerhalb von 10 s da. Belegt durch Test 2, zuerst rot, dann grün.
- **AC-3:** Given `MenuBarCaptureView` / When der Diff geprüft wird / Then schließen Return und „Open Loose Ends“ das Panel über
  `@Environment(\.dismiss)` („Open Loose Ends“: erst `dismiss()`, dann `showMain`), `MacWindows.closeMenuBarPanel` ist entfernt und
  kein Aufrufer bleibt übrig. Belegt durch Diff-Prüfung und einen grünen Mac-Bau.
- **AC-4:** Given `macOpenMainWindowIfNeeded` / When der Diff geprüft wird / Then enthält sie keinen zweiten Klick auf das
  Symbol und keine Wartezeit auf ein sich schließendes Panel mehr. Belegt durch Diff-Prüfung.
- **AC-5:** Given der Mac-Galerie-Job / When er nach dem Fix läuft / Then sind `testPanelTypedGerman` und
  `testWindowFromMenuBarFitsScreen` beim ersten Versuch grün, ohne Wiederholung der CI. Belegt durch den Lauf.
- **AC-6:** Given der Job „Mac Gallery (macOS)“ / When er nach dem Fix in drei aufeinanderfolgenden CI-Läufen (verschiedene
  Pushes oder Neustarts ohne Codeänderung, jeweils erster Versuch) läuft / Then ist er jedes Mal grün (Galerie, Klick- und
  Tastatur-Tests). Belegt durch die Lauf-Nummern im Abschlussbericht.
- **AC-7:** Given der Diff / When er geprüft wird / Then berührt er nur die drei genannten Dateien, kein `try?`, kein `print`, jede
  Funktion ≤ 50 LoC, kein Eintrag in `project.yml`, `Info.plist` oder Entitlements; alle Unit-Tests und der iOS-Bau sind grün.

**Stop-Regel:** Bleibt Test 1 oder 2 nach dem Fix rot, beendet `dismiss` die Session nicht. Dann Stopp und PO-Frage zu den
Alternativen unten (MenuBarExtraAccess oder eigenes `NSStatusItem`); kein privater SPI-Aufruf, kein dritter Klick im Test.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| SwiftUI `MenuBarExtra(.window)` (`LooseEnds/App/LooseEndsApp.swift`, Z. 229–237) | API | Panel und Symbol; Aufruf unverändert |
| SwiftUI `@Environment(\.dismiss)` | API | öffentlicher Schließweg des Panels |
| AppKit `NSStatusItem` (macOS-27-Session-Mechanik) | System | verwaltet die Session, die offen blieb |
| `MacWindows.showMain`, `applyDockPolicy`, `MacAppDelegate` | module | bleiben; Kandidat (b) der Ursache |
| `macLaunch`, `macWait`, `macMainWindow`, `openPanel` (MacGalleryTests) | Test-Hilfen | Aufbau der neuen Tests |
| CI-Job „Mac Gallery (macOS)“ (`ci.yml`, `-only-testing:…/MacGalleryTests`) | CI | einziger Ort der Mac-UI-Tests |
| #356, #400, #402, #479, #511, #597 | Vorarbeit | Panel, Layout, Galerie, bisheriger Rückfall |

Keine neue externe Abhängigkeit.

## Risiken

- **Hypothese (mittel):** Die Wirkung von `dismiss` auf die Session ist nicht dokumentiert und zeigt sich nur in der CI
  (Lauf ca. 30–40 min). Der RED-Lauf und die Stop-Regel fangen das ab.
- **Rest-Ursache (niedrig bis mittel):** Der rote `testPanelTypedGerman` ist durch die Session allein nicht ganz erklärt;
  Kandidat (b) bleibt offen, bis die Tests grün sind.
- **Nutzerfehler (hoch bedeutsam):** Stimmt (a), ist es ein echter Produktfehler (zwei Klicks nach Return), nicht nur ein
  Testproblem; ein reiner Testumbau würde ihn verdecken.
- **Ob das Hauptfenster beim Start öffnet (niedrig):** schwankt in der CI (#513, Eigenheit des XCUITest-Starts); Test 1 und 2
  hängen davon nicht ab, weil sie das Panel über das Symbol öffnen.

## Alternativen

- **MenuBarExtraAccess als Abhängigkeit** (`isPresented`-Bindung, macOS-27-Unterstützung über SPI): nur, wenn `dismiss` die
  Session nicht beendet. Neue Abhängigkeit, braucht Freigabe; fiele: die Regel „keine neuen Dependencies“.
- **Eigenes `NSStatusItem` + `NSPanel` statt `MenuBarExtra`:** volle Kontrolle, ca. 150–250 LoC, Fokus, Dunkelmodus und Position
  neu; fiele: die Entscheidung aus #356 für `MenuBarExtra`.
- **SPI selbst aufrufen** (`expandedInterfaceSession.cancel`): klein, aber private API im App Store. Verworfen.
- **`performClick` am Statusbutton:** auf macOS 27 wirkungslos (Target/Action nil). Verworfen.
- **Nur den Test anpassen** (dritter Klick): verdeckt einen Nutzerfehler. Verworfen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** — (keine neue ADR)
- **Rationale:** Der Fix tauscht den Schließweg innerhalb der bestehenden Lösung (`MenuBarExtra`, #356); Speicherort, Datenmodell,
  Plattformzuschnitt und Abgleich bleiben. Eine ADR wäre erst nötig, wenn die Alternativen greifen: MenuBarExtraAccess kippt die
  Regel „keine neuen Dependencies“, ein eigenes `NSStatusItem` kippt die Entscheidung für `MenuBarExtra` aus #356.

## Offene Fragen

- Beendet `dismiss` im `MenuBarExtra`-Inhalt die Session? Klärt der GREEN-Lauf; falls nein, greift die Stop-Regel.

## Definition of Done

- [ ] AC-1 bis AC-7 erfüllt; RED-Lauf (beide neuen Tests rot) und GREEN-Lauf dokumentiert.
- [ ] Mac-Galerie in drei aufeinanderfolgenden CI-Läufen beim ersten Versuch grün, Lauf-Nummern im Bericht; Anhänge geöffnet.
- [ ] Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ PR mit `Closes #862`.

## Known Limitations

- **AC-2 schwankt selten (PO-Entscheidung 2026-11-21: ausliefern):** AC-2 ist durch CI-Lauf 44877016605, Versuch 1, belegt
  (rot vor dem Fix, grün danach). In 2 von 15 Läufen mit dem Fix-Code (Versuche 3 und 4 desselben Laufs) öffnete sich das Panel
  nach „Open Loose Ends“ + ⌘W und schloss sich binnen 5 s wieder; in den übrigen 13 Läufen (2 normale CI-Versuche, 11 Diagnoseläufe,
  davon 4 mit unverändertem Fix-Code) trat es nie auf. Ursache offen, Weitersuche in #978. Bis dahin ist `testMenuBarReopensAfterOpenAppWithOneClick` per
  `XCTSkip` ausgesetzt und zählt nicht in AC-6.

## Changelog

- 2026-11-20: Initiale Spec für #862 (Schließen über `dismiss`, Nachstellung in der CI).
- 2026-11-21: Known Limitations ergänzt: seltenes Schließen im AC-2-Weg → #978, Test bis dahin ausgesetzt (PO 2026-11-21).
