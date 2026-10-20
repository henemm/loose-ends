# Context: feat-479-mac-menueleiste

## Request Summary
Epic #467, Ticket #479: Das Menüleisten-Panel der Mac-App (Klick auf das Fadensymbol) bekommt den Papierstil
der freigegebenen Tafel „Menüleiste“ (`docs/artifacts/feat-408-mac-entwurf/Menueleiste.dc.html`). Die Funktion
bleibt: dieselbe `CaptureView` wie im Fenster, Return speichert, das Panel schließt (#356, #400, #402).

## Soll laut Tafel
- Panel 440 pt breit, Papier (`#F4F3EE` / dunkel `#171816`), Haarlinie, Rundung 14.
- Oben Knoten (`ThreadGlyph`) neben „NEUE AUFGABE“ in Großbuchstaben (SF 11 pt, Grau, gesperrt).
- Eingabefeld in Serif 22 pt, mindestens 110 pt hoch, Platzhalter-Grau, **kein** grauer Kasten wie heute.
- Zeile darunter: Mikrofon (46 pt, Ring in Akzent), Hinweis „Sprich los oder tippe. Return speichert.“ (grau 13 pt),
  rechts „Abbrechen“ (grau) und „Fertig“ (Akzentkapsel, weiß, 30 pt hoch).
- Unter einer Haarlinie „Loose Ends öffnen“ und „Beenden“ (grau 12 pt).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Mac/MenuBarCapture.swift` | `MenuBarCaptureView`: Rahmen des Panels (CaptureView + Divider + Fußzeile, 440 pt). Hier entsteht der Papierrahmen. |
| `LooseEnds/Views/CaptureView.swift` | Die Erfassung selbst, **geteilt mit iPhone/iPad**. Mac-Zweige schon vorhanden: `Layout`, `FieldSurface` (grauer Kasten, 14 pt Inset), `macDiagnosisLine` (#402), `frame(minWidth: 440, minHeight: 280)`. `onFinish != nil` = Panel (Knöpfe unter dem Feld). Mikrofon `MicButton` 44 pt, `WaveformView`, `ListeningHintView` („Listening …“). |
| `LooseEnds/App/LooseEndsApp.swift:120` | `MenuBarExtra { MenuBarCaptureView } .menuBarExtraStyle(.window)`. Hier ändert sich nichts außer evtl. Farbschema unter Test. |
| `LooseEnds/Views/Paper.swift` | `Paper.ground` (Farbe „Paper“, hell/dunkel im Asset-Katalog), `captionHead()` (graue gesperrte Großbuchstaben). Die Bausteine, die #477/#478 benutzen. |
| `LooseEnds/Views/Thread.swift` | `ThreadGlyph` (Knoten, nur SwiftUI), für die Kopfzeile. |
| `LooseEnds/Views/SettingsView.swift` | Wie #478 Papier und Haarlinien auf dem Mac macht (Vorbild). |
| `LooseEnds/Resources/Localizable.xcstrings` | Neue Texte brauchen Einträge: „New task“ (Kopf), „Speak or type. Return saves.“ (Hinweis). Vorhanden: „Open Loose Ends“ (de „Loose Ends öffnen“), „Quit Loose Ends“ (de „Loose Ends beenden“), „Cancel“, „Done“, „What should I remember?“ (de „Was soll ich aufnehmen?“). |
| `LooseEndsUITests/MacUITestSupport.swift` | Hilfen: `app.statusItems.firstMatch.click()` öffnet das Panel, `menuBarOpenApp` wird darin gefunden. Panel ist ein eigenes Fenster der App (`MenuBarExtra`). |
| `LooseEndsUITests/MacGalleryTests.swift` | Galerie (CI-Job „Mac Gallery“) fotografiert Fenster und Einstellungen; Panel fehlt noch. Muster für `testPanelLight/Dark`. |
| `LooseEndsTests/MenuBarTests.swift` | Einziger Unit-Test der Menüleiste (`DockPolicy`). |

## Abweichungen Tafel ↔ App (zu klären in der Analyse)
- Platzhalter: Tafel „Was soll ich mir merken?“, App „What should I remember?“ / de „Was soll ich aufnehmen?“. Der Text ist
  Teil von Hennings freigegebenem Wortlaut der Startseite; für das Panel gilt der App-Text (gleiches Feld wie im Fenster),
  die Tafel ist hier nur Bildplatzhalter. Vorschlag: App-Text behalten.
- Hinweis „Sprich los oder tippe. Return speichert.“ existiert nicht; heute steht an der Stelle „Listening …“ (nur wenn das
  Mikrofon lauscht und das Feld leer ist, #297) bzw. die ruhige Diagnosezeile (#402). Der Hinweis darf diese beiden nicht
  verdrängen: er ist die Ruhezeile, wenn das Mikrofon **nicht** lauscht und nichts im Feld steht.
- Mikrofon 46 pt (Tafel) gegen 44 pt (App, mit 74-pt-Rahmen für den Pegelring). Der Pegelring (#279) bleibt.
- Wellenform (`WaveformView`) kommt in der Tafel nicht vor. Sie ist Teil von #279 („Ich höre …“); Frage an die Analyse, ob
  sie im Panel bleibt (Funktion „bleibt“ laut Ticket) – Vorschlag: bleibt, dünn, zwischen Mikrofon und Hinweis.
- „Beenden“ (Tafel) gegen „Loose Ends beenden“ (App-Text, Menüleisten-Konvention). Vorschlag: App-Text behalten.

## Existing Patterns
- Mac-Zweig in geteilter Ansicht per `#if os(macOS)` (`Layout`, `FieldSurface`, `macDiagnosisLine`).
- Papier: `Paper.ground` als Hintergrund, Haarlinien statt Karten, Serif per `.fontDesign(.serif)` / `.font(.system(.title3, design: .serif))`.
- Akzent nur für Antippbares (ADR-14): „Fertig“ als Akzentkapsel, Mikrofon-Ring.
- Nur SF Symbols (#350); Ausnahme der Knoten als Markenzeichen.
- UI-Test-Farbschema: `--ui-testing-dark` färbt den Fensterinhalt; `LooseEndsApp.uiTestColorScheme` wird für Einstellungen schon gesetzt, für das Panel noch nicht (Dunkel-Galerie braucht es, vgl. Commit `78f201f`).

## Dependencies
- Upstream: `SpeechCapture`, `CaptureService.save`, `EnrichmentCoordinator.processPending()`, `MacWindows`, `Paper`, `ThreadGlyph`.
- Downstream: `CaptureView` wird auch vom iPhone/iPad (Sheet, Aktionstaste, Teilen) und im Fenster-⌘N benutzt – jede Änderung außerhalb `#if os(macOS)` oder ohne `onFinish != nil` trifft sie. Bestehende UI-Tests: `captureTextField`, `captureDoneButton`, `captureCancelButton`, `micButton`, `listeningHint`, `speechDiagnosisLabel`, `menuBarOpenApp`, `menuBarQuit` (IDs müssen bleiben).

## Existing Specs / Entscheidungen
- `docs/project/03-design-briefing.md`, Abschnitt „Mac-App“ (Zeile „Liste, Detail, Einstellungen, Menüleisten-Panel auf Papier mit Haarlinien“).
- #356 (Panel), #400 (Knöpfe nie verdeckt), #402 (Diagnosezeile ruhig), #279/#297 (Hören-Anzeige), #478 (Einstellungen, Vorbild).
- Keine eigene Spec zu #479 vorhanden.

## Risks & Considerations
- **Panel-Höhe:** #400 – frühere Fassung ließ „Abbrechen“/„Fertig“ unter die Fußzeile rutschen. Panel muss feste ideale Höhe behalten (`fixedSize` vertikal); nach dem Umbau mit Foto belegen.
- **Geteilte Ansicht:** Umbau von `CaptureView` nur für `onFinish != nil` auf dem Mac; iPhone/iPad-Sheet bleibt Pixel für Pixel gleich (Gegenprobe: bestehende UI-Smoke-Tests iOS).
- **Fotografieren des Panels:** neu. `statusItems.click()` öffnet das Panel, `app.windows.containing(.any, identifier: "menuBarOpenApp")` sollte es greifen; auf dem CI-Mac ungeprüft (Panel schließt bei Fokusverlust, siehe Memory „Mac-Lauf vorher durchdenken“). Erst im Galerie-Job der CI beweisbar.
- **Dunkel:** Panel unter `MenuBarExtra` erbt das Systemschema, nicht `--ui-testing-dark`; Test braucht `preferredColorScheme` wie bei den Einstellungen.
- **Geräteliste (CLAUDE.md):** Es werden weder `Shared/Persistence`, `project.yml` noch Entitlements berührt → „Kein Pfad der Geräteliste berührt.“ Abnahme endet nach Stufe 2 (Tests + Mac-Galerie-Bilder); das Ticket verlangt zusätzlich „Abnahme über TestFlight auf dem Mac“ (Henning schaut selbst nach dem Build).
- **Zustand des Arbeitsordners:** Branch `feat/478-mac-einstellungen-papier` ist gemergt (PR #549), 2 Stände hinter `main`. Vor dem Bau neuer Zweig von `origin/main` (Rebase-Gate).
- Keine Modellfeld-, Schema- oder Permission-Änderung, keine neuen AppStorage-Schlüssel.

## Alternative (für /20-analyse)
Eigenes schlankes Mac-Panel statt Umbau von `CaptureView`: sicherer für iPhone/iPad, aber doppelt Sprache/Speichern/Diagnose.
Vorläufige Empfehlung: ein `CaptureView` mit Mac-Panel-Zweig (`onFinish != nil`), weil Funktion laut Ticket „bleibt“.

## Analysis

### Type
Feature (reine Optik des Mac-Menüleisten-Panels; Funktion aus #356/#400/#402 bleibt).

### Recherche (zuerst, mit Quelle)
- `MenuBarExtra` im Stil `.window` ist ein popover-artiges Fenster; Hintergrundfarbe und Rundung des Containers sind per
  SwiftUI-API nicht einstellbar, sie folgen dem System. Folge: Das Papier muss der **Inhalt** füllen (`Paper.ground` als
  Hintergrund der ganzen Panelansicht), die Systemrundung bleibt außen. Eine eigene Rundung 14 wie in der Tafel ist nicht
  erreichbar; Alternative wäre ein eigenes `NSPanel` (FluidMenuBarExtra-Ansatz), das #356 und #400 neu aufmacht und für
  reine Optik zu viel ist.
- Quellen: https://developer.apple.com/documentation/swiftui/menubarextrastyle/window ,
  https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI ,
  https://github.com/lfroms/fluid-menu-bar-extra/blob/main/README.md

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/CaptureView.swift` | MODIFY | Zweig `#if os(macOS)` **und** `onFinish != nil`: Kopfzeile (Knoten + „NEW TASK“), Feld ohne Kasten in Serif 22 pt, min. 110 pt, eine Zeile Mikrofon / Hinweis-oder-Welle / Abbrechen / Fertig (Akzentkapsel), Diagnosezeile darunter (Platz reserviert). iPhone, iPad und Fenster-⌘N (`onFinish == nil`) bleiben unverändert. |
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | Papierhintergrund, Haarlinie, Fußzeile „Open Loose Ends“ / „Quit Loose Ends“ grau 12 pt. |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | `.preferredColorScheme(Self.uiTestColorScheme)` am Panel (nur für die Dunkel-Aufnahme, wie bei den Einstellungen). |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | „New task“ (de „Neue Aufgabe“), „Speak or type. Return saves.“ (de „Sprich los oder tippe. Return speichert.“). |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | `testPanelLight/Dark`: Fadensymbol anklicken, Panel greifen (`windows.containing(.any, identifier: "menuBarOpenApp")`), Knöpfe sichtbar und innerhalb des Panels prüfen, Foto `mac-gallery-panel-*`. |
| `LooseEndsTests/` (Reinregel) | CREATE (klein) | Nur falls eine Regel entsteht (z. B. Hinweis/Welle/Diagnose-Vorrang als reine Funktion); sonst entfällt die Datei. |

### Scope Assessment
- Files: 5 (6 mit Unit-Test); Estimated LoC: +170/-40 (unter 250); Risk Level: MEDIUM — `CaptureView` ist mit iPhone/iPad geteilt, der Umbau hängt aber hinter `os(macOS)` und `onFinish != nil`.

### Technical Approach
**Empfehlung: ein `CaptureView` mit Panel-Zweig** statt eines zweiten Panels. Ohne Modell, nur Layout.
- Kopf: `ThreadGlyph` + Text mit `captionHead()`. Feld: `.font(.system(size: 22, design: .serif))`, `FieldSurface` im Panel durch Mindesthöhe 110 und Inset ersetzt (kein grauer Kasten); Platzhalter bleibt der App-Text „Was soll ich aufnehmen?“ (gleiches Feld wie im Fenster, Wortlaut ist freigegeben).
- Zeile: `MicButton` bleibt (44 pt mit 74-pt-Rahmen für den Pegelring #279; Tafel 46 pt ist Bildmaß). Mittelfeld: **hört zu →** `WaveformView` (dünn), **sonst →** Hinweis „Speak or type. Return saves.“ in grau 13 pt. Der „Listening …“-Text im Feld (#297) und die ruhige Diagnosezeile (#402) bleiben unverändert und werden vom Hinweis nicht verdrängt, weil er nur in der Ruhe steht.
- „Fertig“ als Akzentkapsel (Akzent = antippbar, ADR-14), „Abbrechen“ grau; IDs `captureDoneButton`, `captureCancelButton`, `captureTextField`, `micButton`, `menuBarOpenApp`, `menuBarQuit`, `speechDiagnosisLabel`, `listeningHint` bleiben.
- Höhe: weiter `fixedSize(vertical)` um die Erfassung (#400); Belegfoto, dass beide Fußzeilen sichtbar sind.
- Fußzeile: App-Text „Loose Ends beenden“ bleibt (Menüleisten-Konvention) statt Tafel-„Beenden“.

### Alternative(n)
1. **Eigenes schlankes Mac-Panel** statt `CaptureView`-Zweig: iPhone/iPad sicher, aber Sprache, Speichern und Diagnose doppelt gepflegt; kippt die Zusage „dasselbe CaptureView“ aus #356. Verworfen.
2. **Eigenes `NSPanel`** (volle Kontrolle über Rundung 14, Schatten, Haarlinie): würde Tafel pixelgenau treffen, aber #356/#400-Verhalten (Schließen bei Fokusverlust, Tastaturfokus) neu bauen. Verworfen; Rundung bleibt die des Systems.
3. **Tafel wörtlich** (Platzhalter „Was soll ich mir merken?“, „Beenden“): kippt Hennings freigegebenen Wortlaut der Startseite — nicht ohne seine Ansage.
Gekippte frühere Entscheidung bei Weg 1/2: ADR zu #356 („ein Panel, dieselbe Erfassung“).

### Befunde, die gegen den Plan sprechen
- Panel-Außenrundung und Haarlinie der Tafel sind mit `.window`-Stil nicht erreichbar (Recherche oben): Abweichung von der Tafel an der Ecke, innen deckungsgleich. Ob das Papier an den Ecken sauber abschließt, zeigt erst das Foto aus der CI.
- Fotografieren des Panels in der CI ist neu; `statusItems.click()` + `menuBarOpenApp` funktionieren dort schon (`macOpenMainWindowIfNeeded`, #511), das Panelfenster wird über diese ID gegriffen.

### Dependencies
- Upstream: `SpeechCapture`, `CaptureService.save`, `EnrichmentCoordinator.processPending()`, `MacWindows`, `Paper`, `ThreadGlyph`.
- Downstream: `CaptureView` auch in `ContentView` (⌘N/Sheet, iOS); keine Modell-, Schema-, Rechte- oder AppStorage-Änderung.

### Abnahme
- Stufe 1: bestehende Unit- und UI-Tests grün (iOS-Smoke als Gegenprobe für die geteilte Ansicht), neue Panel-Galerie (hell/dunkel) in der CI.
- Stufe 2: Mac-Galerie-Bilder der CI öffnen und beschreiben (Mac-Bilder kommen nur von dort). Kein Pfad der Geräteliste berührt. Ticket verlangt zusätzlich Henning-Blick über TestFlight (Mac).

### Open Questions
- [ ] Keine Produktfrage offen; Wortlaut (Platzhalter, „Loose Ends beenden“) bleibt App-Text — nur auf Hennings Zuruf ändern.
