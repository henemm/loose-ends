---
entity_id: feat-355-s3-komplikation
type: feature
created: 2026-10-14
updated: 2026-10-14
status: draft
workflow: feat-355-s3-komplikation
---

# Spec: #355 Schnitt 3a — Komplikation mit dem Knoten auf dem Watch-Zifferblatt

## Approval

- [ ] Approved

## Purpose

Seit Schnitt 1 (Build 52 und 54) erkennt Siri auf der Apple Watch den App-Namen nicht (#404). Damit fehlt der Watch
jeder Weg, eine Aufgabe schnell zu erfassen. Schnitt 3a gibt ihr einen: eine Komplikation mit dem Knoten, dem Zeichen
des Logo-Fadens, auf dem Zifferblatt. Antippen öffnet die Watch-App, die als einzige Szene sofort die Erfassung zeigt.
Das Diktat beginnt mit einem Tipp aufs Feld. Es gibt keinen öffentlichen Weg, es beim Öffnen selbst zu starten; das ist
eine offen benannte Abweichung vom Design-Briefing Screen 8 („Complication öffnet direkt das Diktat“). Der Regelweg
genügt trivial: Die Komplikation zeigt eine feste Zeichnung ohne Daten, ein Modell kommt nicht vor.

## Source

- **Dateien:** `project.yml` (neues Ziel `LooseEndsWatchWidgets`, Abhängigkeit in `LooseEndsWatch`),
  `LooseEndsWatchWidgets/` (neu), `LooseEnds/Views/Thread.swift` (unverändert, wird mitkompiliert),
  `.github/workflows/testflight.yml` (Archivprüfung), `LooseEndsTests/CaptureComplicationTests.swift` (neu)
- **Ticket:** #355, Schnitt 3 von 3, hier Teil a (Henning, 2026-10-13/14)
- **Entwurf:** Variante A (Knoten) von Henning am 2026-10-14 freigegeben:
  https://claude.ai/artifact/9EwUuMYhReqLRWP9E9N9Vy, Datei `docs/artifacts/feat-355-s3-komplikation/preview.html`
- **Analyse:** `docs/context/feat-355-s3-komplikation.md`

## Recherche (Quellen)

- Kein öffentlicher Weg, das Diktat beim Öffnen von selbst zu starten: Programmatischer Fokus (`@FocusState`) öffnet
  auf watchOS keine Eingabe (Berichte ab watchOS 10); `presentTextInputController` ist eine WatchKit-Schnittstelle des
  Interface-Controllers und unter dem SwiftUI-Lebenszyklus ohne sichtbaren Controller. Drafts öffnet die Eingabe seit
  watchOS 8.1 mit Tastatur oder Scribble, seit watchOS 11 mit Diktat, wenn Diktat zuletzt benutzt wurde — also
  systemseitig, nicht per App-Aufruf. Quellen:
  https://forums.getdrafts.com/t/alert-for-apple-watch-dictation-users/11358?page=2 ,
  https://docs.getdrafts.com/docs/extensions/applewatch , https://developer.apple.com/forums/thread/650867
- Komplikationen sind WidgetKit-Erweiterungen, eingebettet in die Watch-App; ihre Kennung ist die der Watch-App plus
  Suffix. Ohne `widgetURL` öffnet ein Tipp die zugehörige App. Familien `accessoryCircular` und `accessoryCorner` zeigen
  Zeichnungen, `accessoryInline` nur Text.
- Simulator-Beleg 2026-10-13: Die Watch-App baut für watchOS 27 (Series 12, 46 mm), die Erfassung ist bereits deutsch
  („Ich höre zu“, „Fertig“): `docs/artifacts/feat-355-s3-komplikation/heute-erfassung.png`.
- Intern: #307 — der CI-Schlüssel konnte dem Widget keine iCloud-Fähigkeit an der App-ID setzen (TestFlight-Bau 26
  scheiterte). Deshalb bekommt das neue Ziel keine Berechtigungen.

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| WidgetKit (watchOS 27) | Framework | `Widget`, `TimelineProvider`, Familien `accessoryCircular`/`accessoryCorner`, `AccessoryWidgetBackground` |
| `ThreadShape(form: .knot)` in `LooseEnds/Views/Thread.swift` | Bestehender Code | Zeichnung des Knotens; Datei nur SwiftUI, kompiliert unverändert auf watchOS |
| `LooseEndsWatch/LooseEndsWatchApp.swift` | Nachbar | Einzige Szene `WatchCaptureView`; Antippen der Komplikation landet dort, keine Änderung |
| `LooseEndsWidgets/PrivacyInfo.xcprivacy` | Vorlage | Kopie ohne API-Einträge für das neue Bundle (Archivprüfung #177) |
| `.github/workflows/testflight.yml` | CI | Archivprüfung `check <Kennung> <SDK>` je Bundle |
| `scripts/test_entitlements_sync.py`, `scripts/test_ci_xcode27.py` | Skripttests | dürfen nicht brechen |
| `ThreadShapeTests`, `MenuBarThreadImageTests` | Bestehende Tests | bleiben grün, `Thread.swift` ändert sich nicht |

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `project.yml` | MODIFY (~+25) | Neues Ziel `LooseEndsWatchWidgets` (`app-extension`, `platform: watchOS`, Kennung `com.henning.looseends$(BUNDLE_ID_SUFFIX).watchkitapp.widgets`, **keine** Berechtigungen, Info-Eigenschaften mit `NSExtension.NSExtensionPointIdentifier: com.apple.widgetkit-extension`, Version und Build wie die anderen Ziele). Quellen: Ordner `LooseEndsWatchWidgets` und die einzelne Datei `LooseEnds/Views/Thread.swift`. Abhängigkeit `- target: LooseEndsWatchWidgets` im Ziel `LooseEndsWatch`. Das Testziel kompiliert zusätzlich `LooseEndsWatchWidgets/CaptureComplication.swift`. Hinweiskommentar: `Thread.swift` muss watchOS-tauglich bleiben. |
| `LooseEndsWatchWidgets/CaptureComplication.swift` | CREATE (~60) | `CaptureComplicationProvider`, `CaptureComplicationView(family:)`, `CaptureComplication: Widget` |
| `LooseEndsWatchWidgets/LooseEndsWatchWidgetsBundle.swift` | CREATE (~8) | `@main struct LooseEndsWatchWidgetsBundle: WidgetBundle`; eigene Datei, damit der Testbau `CaptureComplication.swift` ohne `@main` kompiliert |
| `LooseEndsWatchWidgets/PrivacyInfo.xcprivacy` | CREATE | Kopie von `LooseEndsWidgets/PrivacyInfo.xcprivacy` ohne API-Einträge |
| `LooseEndsWatchWidgets/Info.plist` | erzeugt | von `./scripts/sim.sh generate` aus `project.yml` geschrieben, nicht von Hand |
| `.github/workflows/testflight.yml` | MODIFY (+1) | `check com.henning.looseends.watchkitapp.widgets watchos27.` |
| `LooseEndsTests/CaptureComplicationTests.swift` | CREATE (~45) | Swift Testing, `@testable import LooseEnds` |

### Estimated Changes

- Files: 6 eingecheckte Dateien (`project.yml`, `CaptureComplication.swift`, `LooseEndsWatchWidgetsBundle.swift`,
  `PrivacyInfo.xcprivacy`, `testflight.yml`, `CaptureComplicationTests.swift`). Das ist eine Datei über der Grenze
  von 4–5; begründet, weil zwei davon rein mechanisch sind (Kopie der Datenschutzdatei, eine Zeile CI). Gegenüber der
  Analyse (8 Dateien) sparen der Verzicht auf den Umzug von `ThreadShape` nach `Shared/` und die Verschiebung der
  `sim.sh`-Watch-Befehle in „Nicht Teil“ zwei Dateien und rund 90 LoC.
- LoC: ca. +165/−0 (unter 250)

### Nicht Teil dieser Spec

- **Schnitt 3b:** Einführungstext „Erfasse in Loose Ends“ und ein Satz zum Knoten auf der Watch
  (`OnboardingView.swift`, `Localizable.xcstrings`), eigener Workflow.
- Kein Einstellungsabschnitt (Henning, 2026-10-14: Hinweis nur in der Einführung).
- Kein Autostart des Diktats (kein öffentlicher Weg, s. Recherche).
- Keine `sim.sh`-Befehle für die Watch; Stufe 2 nutzt den watchOS-Simulatorbau wie Schnitt 1 und die Paketinspektion.
- Watch-Siri-Erkennung des App-Namens (#404).
- Daten auf der Komplikation (offene Aufgaben o. Ä.): statisch, ohne App-Gruppe.
- Deutsche Fassung des Komplikationsnamens: siehe Known Risks 3.

## Implementation Details

**Ziel.** `LooseEndsWatchWidgets` folgt dem Muster von `LooseEndsWidgets`, mit drei bewussten Unterschieden: Plattform
watchOS, keine Berechtigungen (weder App-Gruppe noch iCloud — die Komplikation liest keine Daten, und eine neue
Fähigkeit an der neuen App-ID wäre das Risiko aus #307), kein `Shared/`. `Thread.swift` wird als einzelne Datei
mitkompiliert; sie importiert nur SwiftUI und benutzt nichts aus der App. Eingebettet wird über
`dependencies: - target: LooseEndsWatchWidgets` im Ziel `LooseEndsWatch`; die iOS-App bettet die Watch-App wie bisher ein.

**Provider.** `CaptureComplicationProvider: TimelineProvider` mit einem Eintrag (nur `Date`), `getTimeline` liefert genau
diesen Eintrag mit `policy: .never`. Es gibt nichts, was sich ändert.

**Ansicht.** `CaptureComplicationView` nimmt `family: WidgetFamily` als Parameter; `@Environment(\.widgetFamily)` wird
nur im `Widget`-Body gelesen und durchgereicht, damit der iOS-Test die Familie setzen kann. Beide Familien zeigen
`ThreadShape(form: .knot)` als Strich, `.widgetAccentable()`, Strichstärke relativ zur Größe (`GeometryReader`), abgerundete
Enden. `accessoryCircular` legt `AccessoryWidgetBackground()` hinter den Knoten. `accessoryCorner` zeigt den Knoten
mit `widgetLabel` „Capture“. Der Knoten ist dekorativ; die Komplikation trägt `accessibilityLabel` „Capture“ (Schlüssel
englisch). Kein Hintergrund außer dem von `.containerBackground(for: .widget)`.

**Widget.** `CaptureComplication: Widget`, `kind: "CaptureComplication"`, `StaticConfiguration`,
`configurationDisplayName("Capture")`, `description("Opens capture.")`,
`.supportedFamilies([.accessoryCircular, .accessoryCorner])`. Kein `accessoryInline` (nur Text, kein Knoten), kein
`accessoryRectangular`. Antippen öffnet die Watch-App ohne `widgetURL`; die App zeigt als einzige Szene
`WatchCaptureView`.

**Importreihenfolge im Test.** `CaptureComplication.swift` steht zusätzlich im Testziel. Dort kommt `ThreadShape` aus
`@testable import LooseEnds`; im Watch-Widget-Ziel kommt es aus der mitkompilierten Datei. Die Datei bindet das App-Modul
deshalb bedingt ein (`#if canImport(LooseEnds)` → `@testable import LooseEnds`, weil `ThreadShape` intern ist), sodass sie in beiden Zielen ohne Änderung übersetzt.

Reihenfolge (TDD): leere `CaptureComplicationView` und Provider anlegen, `CaptureComplicationTests` rot sehen
(Pixel fehlen), dann Zeichnung, `project.yml`, `./scripts/sim.sh generate`, Simulatorbauten und Paketinspektion,
zuletzt `testflight.yml` und die bestehenden Skripttests.

## Test Plan

### Automated Tests (TDD RED)

Neue Datei `LooseEndsTests/CaptureComplicationTests.swift` (Swift Testing). Rot zuerst: Die View wird als leere Hülle
angelegt, der Test scheitert an „keine Pixel gezeichnet“; ein reiner Kompilierfehler zählt nicht als rot.

- [ ] Test 1: GIVEN `CaptureComplicationView(family: .accessoryCircular)` in 76×76 pt, hell auf dunkel / WHEN per
  `ImageRenderer` gerendert / THEN enthält das Bild gezeichnete (nicht dunkle) Pixel, und die Glyphe bleibt innerhalb
  der Fläche (kein Pixel im äußeren Randstreifen von 2 pt).
- [ ] Test 2: GIVEN `family: .accessoryCorner` in 80×40 pt / WHEN gerendert / THEN dasselbe: Pixel gezeichnet, Rand frei.
- [ ] Test 3: GIVEN der Provider / WHEN `getTimeline` aufgerufen wird / THEN liefert er genau einen Eintrag mit Policy
  `.never`.
- [ ] Test 4: GIVEN beide Renderings / WHEN das Verhältnis gezeichneter Pixel gemessen wird / THEN ist der Knoten bei
  der kleinen Größe noch erkennbar gefüllt (Untergrenze), nicht ein dünner Strich. Die PNGs beider Familien werden für
  die Sichtprüfung in Stufe 2 in das Scratchpad geschrieben.

Bestehende Läufe: `ThreadShapeTests`, `MenuBarThreadImageTests`, `./scripts/sim.sh unit`,
`scripts/test_entitlements_sync.py`, `scripts/test_ci_xcode27.py` bleiben grün.

**Kein neuer UI-Test, begründet:** Eine Komplikation lässt sich im Simulator nicht per Automatisierung aufs
Zifferblatt legen und antippen; das Öffnen der App ist Systemverhalten; die Erfassung selbst bleibt unverändert und
ist durch die bestehenden Tests abgedeckt.

## Abnahme

- **Stufe 1:** `CaptureComplicationTests` erst rot, dann grün; `ThreadShapeTests`, `MenuBarThreadImageTests`,
  `./scripts/sim.sh unit`, `test_entitlements_sync.py`, `test_ci_xcode27.py`.
- **Stufe 2:** `./scripts/sim.sh generate`, watchOS-Simulatorbau und iOS-Simulatorbau (`./scripts/sim.sh build`).
  Paketinspektion: `LooseEndsWatch.app/PlugIns/LooseEndsWatchWidgets.appex` existiert; deren `Info.plist` trägt
  `CFBundleIdentifier` `com.henning.looseends.watchkitapp.widgets`, `NSExtensionPointIdentifier`
  `com.apple.widgetkit-extension`, `MinimumOSVersion` 27.0 und liegt neben `PrivacyInfo.xcprivacy`; die Appex ist
  ohne Berechtigungen signiert; der iOS-Bau enthält die Watch-App mit eingebetteter Appex. Dazu die vom Test gerenderten
  PNGs beider Familien (hell auf dunkel), die ich öffne und beschreibe. Der Start der Watch-App im Simulator zeigt
  weiter die Erfassung (Screenshot). **Der Simulator kann die Komplikation nicht aufs Zifferblatt legen:** Stufe 2
  belegt Paketinhalt, Zeichnung und unveränderte Erfassung, nicht Auswahl und Antippen.
- **Stufe 3 greift** (`project.yml`, neue `Info.plist`, neue Abhängigkeit von `LooseEndsWatch`): über TestFlight in
  Hennings normaler App — Merge, TestFlight-Bau, dann Buildnummer und Prüfschritte (Zifferblatt bearbeiten,
  Komplikation „Loose Ends“ wählen, Knoten sichtbar, Antippen öffnet die Erfassung). Keine Befehlszeile. **Nichts auf
  seinen Geräten ohne sein wörtliches „jetzt ist ein Test möglich“.** Keine Modelländerung, daher kein
  `mac-schema-init`.

## Acceptance Criteria

- **AC-1:** Ziel und Einbettung — `project.yml` führt das Ziel `LooseEndsWatchWidgets` (`app-extension`, watchOS,
  Kennung `com.henning.looseends$(BUNDLE_ID_SUFFIX).watchkitapp.widgets`, Extension-Point
  `com.apple.widgetkit-extension`, Version und Build wie die anderen Ziele), dessen Quellen `LooseEndsWatchWidgets`
  und `LooseEnds/Views/Thread.swift` sind, und `LooseEndsWatch` hängt davon ab. Nachweis: Diff von `project.yml`,
  erzeugte `LooseEndsWatchWidgets/Info.plist` nach `generate`.
- **AC-2:** Keine Berechtigungen — Das Ziel hat weder `entitlements` noch App-Gruppe, iCloud oder Siri, und kein
  `Shared/`. Nachweis: Diff von `project.yml`, `test_entitlements_sync.py` grün, `codesign -d --entitlements` der
  gebauten Appex ohne Berechtigungen (Stufe 2).
- **AC-3:** Familien rund und Ecke, kein inline — `CaptureComplication` unterstützt genau `accessoryCircular` und
  `accessoryCorner`; `accessoryInline` und `accessoryRectangular` fehlen. Nachweis: Diff und Test 1 und 2.
- **AC-4:** Knoten gerendert — `CaptureComplicationView` zeichnet in beiden Familien den Knoten
  (`ThreadShape(form: .knot)`) mit Pixeln innerhalb der Fläche, mit Mindestfüllung. Nachweis:
  `CaptureComplicationTests` (Test 1, 2, 4), davor nachweislich rot; die gerenderten PNGs beider Familien angesehen und
  beschrieben.
- **AC-5:** Statischer Provider — Der Provider liefert einen Eintrag mit Policy `.never`. Nachweis:
  `CaptureComplicationTests` (Test 3).
- **AC-6:** Datenschutzdatei und CI — `LooseEndsWatchWidgets/PrivacyInfo.xcprivacy` liegt im Bundle, und die
  Archivprüfung in `testflight.yml` hat die Zeile `check com.henning.looseends.watchkitapp.widgets watchos27.`.
  Nachweis: Diff, `test_ci_xcode27.py` grün, Paketinspektion; der Archivlauf selbst ist der Beleg im TestFlight-Bau.
- **AC-7:** Watch-Bundle enthält die Appex (Stufe 2) — Der Simulatorbau der Watch-App enthält
  `PlugIns/LooseEndsWatchWidgets.appex` mit Kennung `…watchkitapp.widgets`, Extension-Point widgetkit,
  `MinimumOSVersion` 27.0 und `PrivacyInfo.xcprivacy`; der iOS-Bau bettet die Watch-App samt Appex ein; die
  Watch-App startet im Simulator weiter in der Erfassung. Nachweis: Paketinspektion und Screenshot.
- **AC-8:** Bestehendes bleibt grün — `./scripts/sim.sh unit` (inklusive `ThreadShapeTests`,
  `MenuBarThreadImageTests`), `test_entitlements_sync.py`, `test_ci_xcode27.py` bestehen. Nachweis: Lauf-Ausgaben.
- **AC-9:** Gerätepunkt (Stufe 3) — Auf Hennings Watch lässt sich die Komplikation „Loose Ends“ auf dem Zifferblatt
  wählen, zeigt den Knoten, und Antippen öffnet die Erfassung. Nachweis: Hennings Rückmeldung zum TestFlight-Bau
  (Buildnummer und Prüfschritte nach seinem „jetzt ist ein Test möglich“); bis dahin bleibt das Ticket offen.

## Known Risks

1. **Cloud-managed Signing und die neue App-ID.** Es muss `com.henning.looseends.watchkitapp.widgets` anlegen. Ohne
   Fähigkeiten sollte das gehen; erst der TestFlight-Lauf zeigt es. Rückfall: App-ID im Developer-Portal anlegen
   (macht Claude, nicht Henning).
2. **Archivprüfung.** Die neue Zeile scheitert, wenn die Appex im Archiv fehlt — gewollt.
3. **Name nur englisch.** „Capture“ und „Opens capture.“ stehen als englische Schlüssel im Code; eine deutsche Fassung
   ist nicht Teil dieses Schnitts, weil der Name nur in der Komplikationsauswahl erscheint. Folge: Auf einer deutschen
   Watch erscheint die Auswahl unter „Loose Ends“ mit englischem Untertitel. Ein String Catalog im neuen Ordner wäre
   eine Folgeaufgabe samt `de.lproj`-Prüfung (#323).
4. **`Thread.swift` im Widget-Ziel.** Künftige Änderungen dort müssen watchOS-tauglich bleiben (nur SwiftUI);
   ein Hinweiskommentar steht in `project.yml`. Bricht es, bricht der Watch-Bau sofort und sichtbar.
5. **Lesbarkeit des Knotens.** Ob er bei 2–3 mm als Knoten erkennbar ist, zeigt erst die Watch. Rückfall: Variante B
   (SF Symbol `mic`), ein Austausch der Zeichnung ohne Änderung an Ziel oder CI.
6. **Diktat braucht einen Tipp.** Abweichung vom Briefing, siehe Purpose und Recherche; wird in „Was testen“ so gesagt.

## Alternativen

- **A (gewählt): Knoten.** Erkennbar als Loose Ends, die einzige Ausnahme von „nur SF Symbols“ (#350, Markenzeichen,
  kein Bedienelement). Hennings Wahl im Entwurf.
- **B: SF Symbol `mic`.** Einfacher und in jeder Größe lesbar, aber nicht als Loose Ends erkennbar und ohne Marke.
  Rückfall bei Risiko 5; kippt keine ADR.
- **C: Kurzbefehle-Komplikation des Nutzers, kein Bau.** Henning legt sich selbst einen Kurzbefehl „Aufgabe erfassen“
  aufs Zifferblatt. Kein Code, aber unbelegt, ob er ohne App-Start gesprochen wird, und von Hennings Einrichtung
  abhängig, die er nach seiner Regel nicht übernimmt. Verworfen als Hauptweg.
- **Controls und Smart Stack scheiden aus:** Sie können keine Eingabe abfragen (#326).
- **Regel vor Modell:** Nicht berührt. Die Komplikation zeigt eine feste Zeichnung; es gibt nichts zu verstehen.

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt und belegt (Stufen 1 und 2); AC-9 nach Hennings Rückmeldung zum TestFlight-Bau
- [ ] `./scripts/sim.sh unit` grün, Build erfolgreich, jeder Commit kompiliert
- [ ] CI grün; TestFlight-Bau mit „Was testen“-Text auf Deutsch (Zifferblatt bearbeiten, Komplikation wählen, Knoten
  sehen, antippen, Tipp aufs Feld startet das Diktat)
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
- [ ] #355 bleibt offen bis Schnitt 3b; dieser als Folgearbeit im Ticket vermerkt

## ADR

**ADR-Nr.:** keine — Grund: neues Erweiterungsziel nach bestehendem Widget-Muster, keine Architekturentscheidung.

- **Rationale:** `LooseEndsWatchWidgets` wiederholt das Muster von `LooseEndsWidgets` (app-extension, Extension-Point
  widgetkit, Archivprüfung je Bundle), ohne neue Schicht, ohne Daten, ohne Berechtigungen. Die Abweichung vom Briefing
  (Tipp statt Autostart des Diktats) ist eine Plattformgrenze, keine Entscheidung gegen eine ADR.

## Changelog

- 2026-10-14: Initial spec created (Variante A, Knoten; von Henning im Entwurf freigegeben).
