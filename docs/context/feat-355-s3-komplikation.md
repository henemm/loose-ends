# Context: feat-355-s3-komplikation (#355 Schnitt 3)

## Request Summary

Auf dem Zifferblatt der Apple Watch soll eine Komplikation mit dem Knoten-Symbol direkt in die Erfassung führen
(Design-Briefing Screen 8: „Complication öffnet direkt das Diktat“). Seit Schnitt 1 (Build 52/54) erkennt Siri auf der
Watch den App-Namen nicht (#404) — die Komplikation wird damit der Hauptweg auf der Watch. Dazu der Hinweistext für das
Erfassen von außerhalb der App (Onboarding), angeglichen an den neuen Satz „Erfasse in Loose Ends“.

## Related Files

| File | Relevance |
|------|-----------|
| `project.yml` (Targets `LooseEnds`, `LooseEndsWatch`, `LooseEndsWidgets`) | Neues Watch-Widget-Ziel nötig: `LooseEndsWidgets` hat `supportedDestinations: [iOS, macOS]`; Watch-Target bettet bisher nichts ein |
| `LooseEndsWatch/LooseEndsWatchApp.swift` | Einziger Scene: `WindowGroup { WatchCaptureView() }` — jeder App-Start landet schon in der Erfassung |
| `LooseEndsWatch/WatchCaptureView.swift` | `TextField("I'm listening")` + „Done“; kein Fokus beim Öffnen (Diktat startet erst nach Antippen des Feldes), englisch (Schnitt 2) |
| `LooseEndsWatch/Info.plist`, `LooseEndsWatch.entitlements` | Watch-Bundle `com.henning.looseends$(BUNDLE_ID_SUFFIX).watchkitapp`, App-Gruppe, CloudKit, Siri |
| `LooseEndsWidgets/LooseEndsWidgetsBundle.swift`, `NextUpWidget.swift` | Muster für WidgetBundle/TimelineProvider; kompiliert `Shared/` ohne `CaptureTextIntent.swift` (#326) |
| `LooseEnds/Views/Thread.swift` (`ThreadShape`, `curvePoints(form:)`) | Logo-Faden (Knoten) als Shape; einzige Ausnahme von „nur SF Symbols“ (#350). Liegt in `LooseEnds/`, nicht in `Shared/` → im Watch-Ziel nicht verfügbar |
| `LooseEnds/Mac/MenuBarThreadImage.swift`, `MenuBarThreadRaster` | Vorbild: Faden als Template-Bild aus `curvePoints` (#366) |
| `LooseEnds/Views/OnboardingView.swift:44-47` | Seite „Capture without opening the app“: „Say “Capture in Loose Ends” to Siri …“ (de: „In Loose Ends erfassen“) — der zu angleichende Hinweis |
| `LooseEnds/Views/SettingsView.swift` | Es gibt **keinen** Einstellungsabschnitt „Erfassen von außerhalb“ (Ticket-Punkt 4 nennt ihn) — nur Mitteilungen, iCloud, Kalender, Menüleiste, Über |
| `.github/workflows/testflight.yml:150-160` | Archivprüfung `check <id> <sdk> …` je Bundle (SDK 27, Minimum 27.0, Version, dSYM, PrivacyInfo.xcprivacy); ein neues Watch-Widget-Bundle braucht eine eigene Zeile `check …watchkitapp.widgets watchos27.` und PrivacyInfo |
| `LooseEnds/Resources/Localizable.xcstrings` | Ist schon im Watch-Target (Schnitt 1) — deutsche Texte der Komplikation können dort liegen |
| `scripts/sim.sh` | Kennt **keinen** Watch-Simulator-Bau/-Start/-Screenshot; Schnitt 1 hat das Watch-Bundle nur aus dem eingebetteten iOS-Bau inspiziert |

## Existing Patterns

- Widget-Ziel: `type: app-extension`, `NSExtensionPointIdentifier: com.apple.widgetkit-extension`, eigenes Bundle
  `….widgets`, App-Gruppe ohne iCloud (#307: CI-Schlüssel kann iCloud am Widget nicht setzen).
- Einbettung: iOS-App `dependencies: - target: LooseEndsWatch, platformFilter: iOS`; analog bettet die Watch-App ihr
  Widget-Ziel ein.
- Faden-Symbol außerhalb SwiftUI-Hierarchie: `MenuBarThreadImage` zeichnet `curvePoints` in ein Template-Bild;
  `MenuBarThreadRaster` ist plattformneutral und unit-getestet.
- Archivprüfung erzwingt für jedes Bundle `PrivacyInfo.xcprivacy` (#177) und deutsche `de.lproj` für Bundles mit
  eigenem String Catalog (#323).
- Bündel-Kennungen der Prüfbauten tragen `$(BUNDLE_ID_SUFFIX)` (#156).

## Dependencies

- Upstream: WidgetKit (watchOS 27, Familien `accessoryCircular`, `accessoryCorner`, `accessoryInline`,
  `accessoryRectangular`), `ThreadShape.curvePoints`, Watch-App als Ziel des Antippens.
- Downstream: TestFlight-Archivprüfung, Signierung (neue App-ID `…watchkitapp.widgets` muss Cloud-Signing anlegen
  können), Stufe 3 (Hennings Watch über TestFlight).

## Existing Specs

- `docs/specs/intents/feat-355-s1-siri-saetze-watch.md` — Schnitt 1; „Nicht Teil“: Schnitt 2 (`WatchCaptureView`
  deutsch, wieder bereit), Schnitt 3 (Komplikation, Einstellungshinweis, Onboarding-Text).
- `docs/project/03-design-briefing.md` Screen 8 (Watch) und 9 (Widgets).

## Risks & Considerations

1. **„Direkt ins Diktat“**: Ob watchOS 27 beim Öffnen per Komplikation ein Diktat sofort starten kann (Fokus auf
   `TextField`, `presentTextInputController`-Nachfolger) ist offen → Recherche in `/20-analyse`. Ohne das öffnet die
   Komplikation die Erfassung und ein Tipp aufs Feld startet das Diktat.
2. **Neues Bundle in der Signierung**: Cloud-managed Signing im TestFlight-Lauf muss die App-ID
   `com.henning.looseends.watchkitapp.widgets` mit App-Gruppe anlegen; #307 zeigte, dass der CI-Schlüssel nicht jede
   Fähigkeit setzen kann (iCloud nein, App-Gruppe ja). Braucht die Komplikation überhaupt die App-Gruppe? Eine statische
   Komplikation ohne Daten nicht.
3. **Faden im Watch-Ziel**: `ThreadShape` liegt in `LooseEnds/Views`; für die Komplikation muss die Kurve nach `Shared/`
   oder ins Widget-Ziel. Alternative: SF Symbol — CLAUDE.md erlaubt den Faden als Markenzeichen, das Ticket nennt das
   Knoten-Symbol.
4. **Simulator-Nachweis**: `sim.sh` kann keinen Watch-Simulator bauen/starten/screenshotten; Stufe 2 verlangt Screenshot
   der Erfassung und der Komplikation → Skript-Erweiterung oder Teil der Spec. Komplikation auf dem Zifferblatt im
   Simulator zu platzieren ist nicht per `simctl` automatisierbar; Vorschau über `#Preview`/Snapshot-Rendering.
5. **Scope**: Neues Ziel + Faden-Umzug + Archivprüfung + Onboarding + Sim-Skript kann die 250 LoC sprengen →
   Teilung prüfen (Onboarding-Text getrennt).
6. **Einstellungshinweis**: Kein Abschnitt existiert; Ticket-Punkt 4 meint am ehesten die Onboarding-Seite. Klären,
   ob ein neuer Einstellungsabschnitt gewollt ist (PO-Frage) oder nur der Onboarding-Text.
7. Stufe 3 greift (`LooseEndsWatch/`, `project.yml`, neue `Info.plist`/`.entitlements`).

## Analysis

### Type
Feature

### Recherche (2026-10-13)
- Kein öffentlicher Weg, das Diktat beim Öffnen von selbst zu starten: programmatischer Fokus (`@FocusState`) öffnet
  auf watchOS keine Eingabe (Berichte ab watchOS 10); `presentTextInputController` ist WatchKit-Schnittstelle
  (Interface-Controller), unter SwiftUI-Lebenszyklus ohne sichtbaren Controller. Drafts: seit watchOS 8.1 öffnet Eingabe
  mit Tastatur/Scribble, seit watchOS 11 mit Diktat, wenn Diktat zuletzt benutzt wurde.
  Quellen: https://forums.getdrafts.com/t/alert-for-apple-watch-dictation-users/11358?page=2 ,
  https://docs.getdrafts.com/docs/extensions/applewatch , https://developer.apple.com/forums/thread/650867
- Komplikationen = WidgetKit-Erweiterung, eingebettet in die Watch-App (Kennung = Watch-Kennung + Suffix); Antippen
  öffnet die App ohne `widgetURL`. Familien `accessoryCircular`, `accessoryCorner`; `accessoryInline` nur Text.
- Simulator-Beleg 2026-10-13: Watch-App baut für watchOS 27 (Series 12, 46 mm), Erfassung ist bereits deutsch
  („Ich höre zu“, „Fertig“) — `docs/artifacts/feat-355-s3-komplikation/heute-erfassung.png`.

### Entwurf (Vorschau vor Spec)
`docs/artifacts/feat-355-s3-komplikation/preview.html` (Artefakt https://claude.ai/artifact/9EwUuMYhReqLRWP9E9N9Vy):
A Knoten (Empfehlung), B SF Symbol `mic`, C Kurzbefehle-Komplikation des Nutzers (kein Bau). Einführungstext:
„Erfasse in Loose Ends“ + Satz zum Knoten auf der Watch.

### Schnitt (technische Entscheidung)
- **S3a Komplikation** (dieser Workflow): neues Ziel `LooseEndsWatchWidgets` (app-extension, watchOS, Kennung
  `com.henning.looseends$(BUNDLE_ID_SUFFIX).watchkitapp.widgets`, **keine Entitlements**, statischer TimelineProvider,
  `.widgetAccentable()`, `.containerBackground`), eingebettet über `dependencies` des Ziels `LooseEndsWatch`.
  `ThreadShape` (nur Shape + `curvePoints`) zieht nach `Shared/Views/ThreadShape.swift`; `Thread.swift` behält
  `ThreadGlyph`/Animation. Archivprüfung `check com.henning.looseends.watchkitapp.widgets watchos27.`, PrivacyInfo.
- **S3b Einführungstext** (eigener Workflow, klein): `OnboardingView.swift` + `Localizable.xcstrings`.

### Affected Files (S3a)
| File | Change Type | Description |
|------|-------------|-------------|
| project.yml | MODIFY | Ziel `LooseEndsWatchWidgets`, Abhängigkeit in `LooseEndsWatch` (+~25) |
| Shared/Views/ThreadShape.swift | CREATE | `ThreadShape` aus `Thread.swift` verschoben (~45, netto 0) |
| LooseEnds/Views/Thread.swift | MODIFY | `ThreadShape` entfernt (−45) |
| LooseEndsWatchWidgets/CaptureComplication.swift | CREATE | WidgetBundle, Provider, Ansicht rund/Ecke (~70) |
| LooseEndsWatchWidgets/PrivacyInfo.xcprivacy | CREATE | Pflicht der Archivprüfung (Kopie ohne API-Einträge) |
| .github/workflows/testflight.yml | MODIFY | eine `check`-Zeile |
| LooseEndsTests/CaptureComplicationTests.swift | CREATE | Knoten-Glyphe per `ImageRenderer` (~40) |
| scripts/sim.sh | MODIFY | `watch-build`/`watch-screenshot` für Stufe 2 (~30) |

### Scope Assessment
- Files: 8 (davon 3 mechanisch: Verschiebung, PrivacyInfo, eine Zeile) — über dem 4–5-Dateien-Limit, LoC ~+210/−45.
  Muss in `/30-write-spec` begründet oder weiter geteilt werden (Option: `sim.sh`-Watch-Befehle als eigener Vorlauf).
- Risk Level: MEDIUM — neue App-ID in der Cloud-Signierung (erst ein TestFlight-Lauf zeigt es), Archivprüfung.

### Technical Approach
Statische, berechtigungsfreie Watch-Widget-Erweiterung mit dem Knoten (rund + Ecke, kein inline). Antippen öffnet
`WatchCaptureView`; das Diktat startet mit einem Tipp aufs Feld (kein öffentlicher Weg zum Autostart). Nachweis
Stufe 2: Einbettung im iOS-Simulatorbau prüfen (`.appex` in `Watch/LooseEndsWatch.app/PlugIns`), Watch-Screenshot,
`ImageRenderer`-Test der Glyphe. Komplikation auf dem Zifferblatt + Antippen: nur Stufe 3 (TestFlight, Hennings Watch).

### Alternativen
- SF Symbol `mic` statt Knoten (einfacher, aber nicht als Loose Ends erkennbar).
- Keine eigene Komplikation: Kurzbefehle-Komplikation „Aufgabe erfassen“ des Nutzers (ungeprüft, ob ohne App-Start).
- Controls/Smart Stack: können keine Eingabe abfragen (#326).

### Dependencies
WidgetKit watchOS 27; `ThreadShape.curvePoints` (auch `MenuBarThreadImage`, Tests `ThreadShapeTests`,
`MenuBarThreadImageTests`); Archivprüfung `testflight.yml`; Cloud-Signierung.

### Open Questions
- [x] PO: Variante A (Knoten) — Henning 2026-10-14, Entwurf freigegeben
- [x] PO: Hinweis nur in der Einführung, kein Einstellungsabschnitt — Henning 2026-10-14

### Befund TDD RED (2026-10-14)
- `WidgetFamily.accessoryCorner` ist auf iOS nicht verfügbar („'accessoryCorner' is unavailable in iOS“). Die Ansicht
  nimmt deshalb eine eigene Form `CaptureComplicationView.Face` (`.circular`, `.corner`); das Widget bildet
  `@Environment(\.widgetFamily)` darauf ab. Der Provider bekommt `static func timeline()`, weil sich ein
  `TimelineProviderContext` im Test nicht bauen lässt; `getTimeline` reicht ihn durch.
- RED ist ein Übersetzungsfehler (Typen fehlen): Der Phasen-Wächter lässt in Phase 5 keine Produktionsdatei zu, eine
  leere Hülle war deshalb nicht möglich. Die Pixelprüfungen werden in Phase 6 zuerst gegen eine leere Hülle rot gesehen.
