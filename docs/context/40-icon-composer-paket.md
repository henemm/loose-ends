# Context: 40-icon-composer-paket

## Request Summary
Issue #40 (M3, Epic #371, vor der ersten Einladung, Henning 2026-10-26): Das App-Icon bekommt Ebenentiefe. Aus den zwei
vorhandenen SVG-Ebenen (`layer-background.svg`, `layer-thread.svg`) entsteht ein `AppIcon.icon`-Paket, das Xcode zu
Liquid Glass in Hell, Dunkel, Getönt und Klar kompiliert (iOS, Mac, Watch). Motiv und Farbe bleiben (`docs/project/05-logo.md`).

## Related Files
| File | Relevance |
|------|-----------|
| `docs/design/logo/layer-background.svg`, `layer-thread.svg` | Die zwei Quell-Ebenen, 1024-Raster, Grund `#F4F3EE` flach, Faden als Pfad mit Maske |
| `docs/design/logo/README.md`, `generate.py.txt` | Anleitung (Icon Composer per GUI) und Generator der SVGs |
| `docs/project/05-logo.md` (Abschnitt „Technische Form“) | Entscheidung: `.icon` ist Textdateien, „ohne GUI erzeugbar“, im Repo versionierbar; PNG bleibt Fallback |
| `LooseEnds/Resources/Assets.xcassets/AppIcon.appiconset/` | Heutige PNGs: iOS hell, dunkel, getönt, Mac hell |
| `LooseEndsWatch/Assets.xcassets/AppIcon.appiconset/` | Watch-Icon, eigener Katalog, eigenes Target |
| `project.yml:119` | `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` beim Target `LooseEnds` (iOS und Mac, ein Target) |
| `project.yml` Target `LooseEndsWatch` | Hat eigenen Katalog; die Issue-DoD nennt nur `LooseEnds` |
| `scripts/sim.sh` | `build` (Simulator), `mac-build`, `device-build` — der Bau, der das Paket belegt |

## Existing Patterns
- **Echte Icon-Composer-Pakete auf diesem Rechner** (von der GUI gespeichert), brauchbar als Schemabeleg:
  `/Users/hem/Developer/my-daily-sprints/AppIcon.icon` (`icon.json` mit `fill`, `groups[].layers[]` mit `image-name`, `name`,
  `supported-platforms` `{circles:[watchOS], squares:shared}`; Ebenen als PNG unter `Assets/`). FocusBlox
  (`agent-os-openspec/timebox-ios/AppIcon.icon`) nutzt ein älteres, flacheres Format (`layers[].filename`).
- Reverse-engineertes Schema (peterpoliwoda/icon-composer-template): `groups[]` mit `lighting`, `specular`, `shadow`,
  `layers[]` mit `glass`, `fill`, `opacity`, `position`; Erscheinungsbilder über `*-specializations`. Nicht von Apple.
- Zwei Ebenen = zwei Gruppen (Grund flach, Faden mit Glas), maximal vier Gruppen erlaubt.

## Dependencies
- Upstream: Xcode 27.1 hier (CI pinnt 27.0) mit `Icon Composer.app` und `ictool` (`/Applications/Xcode.app/Contents/Developer/usr/bin/ictool`,
  ohne Argumente: „consult man ictool“, `--help` unbekannt); XcodeGen 2.46.0 (kennt `.icon` als Quelle nicht dokumentiert — offen).
- Downstream: Asset-Katalog-Icon, `entitled`-/Archivprüfung des TestFlight-Laufs, Probe-Bau (`BUNDLE_ID_SUFFIX`),
  Mac-Dock, Watch-Komplikation nutzt das Icon nicht.

## Fakten aus Apple (Recherche, vor Analyse)
- Apple: Ein `.icon` im Projekt **ersetzt** jeden Asset-Katalog-Icon-Satz für dasselbe Ziel; für Vorgänger-Releases erzeugt Xcode
  die Bilder beim Bau selbst ([Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer.md)).
  Deployment Target hier ist 27.0, es gibt keine älteren Releases.
- Der Name im Feld „App Icon“ muss dem Dateinamen ohne Endung entsprechen; mehrere `.icon` im Projekt sind möglich.
- Watch-Leinwand: 1088 × 1088 statt 1024; Ebenen sollen ohne Effekte, Schatten und Verläufe geliefert werden (Apple-Hinweis).
- Specular „Inside/Outside“ und Refraction wirken erst ab OS 27; davor nur Specular-Highlights.
- Forum-Fall: `Exception while running actool` mit `.icon` unter Xcode 27 Beta, ungelöst ([Apple Forum 831309](https://developer.apple.com/forums/thread/831309)).

## Existing Specs
- Keine für das Icon. `docs/design/logo/README.md` und `05-logo.md` sind die Vorgaben. Frühere Arbeit: #19 (Motiv), #49 (Balken unten).

## Risks & Considerations
1. **DoD widerspricht Apple:** „PNG-Fallbacks bleiben im Asset-Katalog“ — Xcode nimmt das `.icon` anstelle des Katalog-Satzes. Beide mit Namen `AppIcon`
   könnten kollidieren (`actool`-Fehler). Mit Target 27.0 braucht es keinen Fallback. Zu klären im Bau.
2. **Schema ungeprüft:** Das Manifest wird von Hand geschrieben. Beleg ist nur der Bau und das Rendern (`ictool` bzw. Simulator-Bild).
3. **Watch** hat ein eigenes Target und einen eigenen Katalog; die Issue-DoD deckt es nicht ab, die Anleitung nennt es („Mac und Watch“).
4. **XcodeGen:** unbekannt, ob ein `.icon` unter `sources` als Ressource des Targets landet und die Build-Setting `ASSETCATALOG_COMPILER_APPICON_NAME` greift.
5. **Stufe 3** (`project.yml`, Icon auf Gerät/Watch/Dock): im selben TestFlight-Durchgang wie #176; nichts auf Hennings Geräten ohne sein Wort.
6. Hell/Dunkel/Getönt/Klar entstehen nur, wenn das Manifest die Darstellungen angibt; sonst sieht das Dunkel-Icon wie das helle aus (heute eigene PNGs).
7. Der Faden-SVG nutzt eine **Maske** (`<mask>`); Icon Composer unterstützt nicht alle SVG-Funktionen — gegebenenfalls als PNG oder ohne Maske neu erzeugen.

## Analysis

### Type
Feature (Aussehen des App-Icons, keine Funktionsänderung). Kein Modell im Spiel; Regelweg-Frage entfällt.

### Spike-Befund (2026-10-26, Wegwerf-Projekt im Scratchpad, nichts im Repo geändert)
- Ein von Hand geschriebenes `AppIcon.icon` (`icon.json` + SVG) wird von `actool` (Xcode 27.1) übersetzt; der erste Versuch scheiterte mit
  der Meldung „A fill should be one of: orientation, solid, linear-gradient or automatic-gradient“ → Schema ist `"fill": {"solid": "srgb:r,g,b,a"}`,
  nicht ein String. Die Fehlermeldungen von `actool` sind brauchbar, das Schema lässt sich damit sicher ableiten.
- XcodeGen 2.46 nimmt `AppIcon.icon` unter `sources` an (`lastKnownFileType = wrapper.icon`, Resources-Phase). `xcodebuild` für iOS-Simulator: BUILD SUCCEEDED.
- **Das DoD-Wort „PNG-Fallbacks bleiben“ ist wirkungslos:** Liegen `AppIcon.icon` und `AppIcon.appiconset` nebeneinander, baut es fehlerfrei und die
  `Assets.car` ist byte-gleich groß (5 229 032) wie ohne Katalog-Satz; das `.icon` gewinnt, die PNGs werden ignoriert. Nichts kollidiert.
- Echter Lauf im iOS-27-Simulator (iPhone 17e): Home-Screen hell zeigt das neue Icon mit Glanz und Kantenlicht, Maske am Kreuzungspunkt des Fadens bleibt erhalten
  (`<mask>` im SVG funktioniert). Vorschau: `docs/artifacts/40-icon-composer-paket/` (heute.png, entwurf.png, vorschau.html).
- Dunkel: Ein fester heller Grund bleibt auch im Dunkelmodus hell (sichtbar im Test). Mit `fill-specializations` (`appearance: dark`) und
  `image-name-specializations` baut es; in der `Assets.car` erscheint die zusätzliche Dunkel-Füllung (`Color-3`). Ob der Faden dort `#5FC4C9` trägt,
  ist NICHT gesehen: `simctl ui appearance` schaltet den Icon-Stil des Home-Screens nicht um (auch das heutige PNG bleibt hell), und `ictool` hat keine dokumentierten Argumente.
  Offen für die Spec: Beleg über die gerenderten Bilder der `Assets.car` oder den Gerätedurchgang.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Resources/AppIcon.icon/icon.json` | CREATE | Manifest: Fill hell/dunkel, eine Gruppe mit Glas-Ebene Faden, `supported-platforms` squares shared + watchOS |
| `LooseEnds/Resources/AppIcon.icon/Assets/layer-thread.svg`, `layer-thread-dark.svg` | CREATE | Faden hell (`#0F6E73`) und dunkel (`#5FC4C9`) |
| `project.yml` | MODIFY | `.icon` ist durch `path: LooseEnds/Resources` schon Quelle des Targets `LooseEnds`; zu prüfen, ob ein Eintrag nötig ist; Watch-Target bekommt dasselbe Paket (eigener Katalog, 1088er Leinwand) |
| `docs/design/logo/README.md` | MODIFY | „Nächster Schritt auf dem Mac“ ersetzen: Paket ist von Hand erzeugt, kein GUI-Schritt |
| `scripts/` Test (Python, wie `test_info_plist_sync.py`) | CREATE | prüft: Manifest lesbar, SVG-Dateien vorhanden, `actool` übersetzt, `Assets.car` enthält Hell/Dunkel/Getönt |

### Scope Assessment
- Files: 5–6, Estimated LoC: ca. +120 (davon SVG-Pfade als Daten), keine Löschung
- Risk Level: LOW–MEDIUM — betrifft nur das Icon, aber `project.yml` ist Pfad der Geräteliste (Stufe 3).

### Technical Approach (Empfehlung)
1. **Grund als `fill`, nicht als Ebene.** Der Grund soll flach bleiben; ein Fill erfüllt das ohne zweite Ebene. Das Icon hat eine Gruppe: Faden mit Glas, Specular, neutralem Schatten.
2. **Dunkel mit eigenem Grund** (dunkles Petrol-Schwarz) und Faden `#5FC4C9`; getönt und klar leitet das System selbst ab (in den Bilddaten vorhanden).
3. **Watch** mit demselben Paket, `supported-platforms` enthält `circles: [watchOS]`; Mac läuft über dasselbe Target (squares shared).
4. **PNG-Sätze bleiben vorerst liegen** (kostenlos, DoD verlangt es), werden aber in der Doku als ungenutzt benannt; löschen wäre eine eigene, spätere Aufräumfrage.
5. Test: Python-Skript wie bei den anderen Sync-Tests plus `sim.sh build`; Stufe 2 = Home-Screen im Simulator (hell), Dunkel/Getönt/Klar auf dem Gerät im Durchgang mit #176 (nur nach Hennings „jetzt ist ein Test möglich“).

### Alternativen
- **A (Empfehlung):** `.icon` mit Fill, Faden als Glas-Ebene.
- **B: Nichts bauen.** Die PNGs sehen auf iOS 26/27 korrekt aus, nur flach. Spart den Gerätedurchgang für Watch/Dock; widerspricht Hennings Beschluss vom 2026-10-26 (Icon vor der Einladung).
- **C: Grund als eigene Ebene** (wie README und `05-logo.md` „zwei Ebenen“): sieht gleich aus, kostet eine Ebene mehr und kippt nichts außer dem Wortlaut „zwei Ebenen“ in `05-logo.md`.
- **Dunkel:** eigener Grund (Empfehlung) vs. durchsichtig wie heute (System legt Grund darunter). Zweites ist die Linie der heutigen PNG und von `05-logo.md` („einfarbig hell oder dunkel“).
- Gekippt würde: `05-logo.md` „Fallback: AppIcon-1024.png bleibt für ältere Werkzeuge“ (es gibt keine älteren Ziele, Target 27.0) und der Wortlaut „Ebene 1 Hintergrundfläche“.

### Without the model
Kein Modell beteiligt.

### Dependencies
`actool`/XcodeGen wie oben; TestFlight-`entitled`-/Archivprüfung muss das Icon im Archiv weiter finden (Prüfen im Bau); Probe-Bau unverändert.

### Open Questions
- [x] Dunkel: eigener dunkler Grund (Henning, 2026-10-26, nach Vorschau)
- [ ] Beleg für die Fadenfarbe im Dunkel-Bild (technisch, in Spec/RED lösen)
- [ ] Muss `project.yml` überhaupt geändert werden (Pfad ist bereits Quelle)? Falls nein, greift Stufe 3 nur über das Watch-Target
