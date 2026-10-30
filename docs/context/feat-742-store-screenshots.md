# Context: feat-742-store-screenshots

## Request Summary
Henning (2026-10-30): „Bereite für das Going Live die Screenshots für alle Geräte vor, so dass ich sie über eine Claude Desktop Session hochladen lassen kann.“
Entscheidungen: nur Deutsch; iPhone, iPad, Mac, Watch; reine App-Bilder ohne Rahmen und ohne Bildunterzeile. Ticket #742 (M3, P1, M).

## Recherche (Stand 2026-10-30, Apples Seite „Screenshot specifications“)
Quelle: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- 1 bis 10 Bilder je Gerätegröße; `.jpeg`/`.jpg`/`.png`; **kein Alphakanal**.
- **iPhone Pflicht:** Dynamic Island (medium) 1179×2556 oder **1206×2622** (hochkant). Größere Sätze optional. Ab April 2027 Pflicht für Apps mit iOS-27.1-SDK: Duo-Bilder (optional, hier nicht gebraucht).
- **iPad Pflicht (App läuft auf iPad):** 13″ **2064×2752** oder 2048×2732.
- **Mac:** 16:10; 1280×800, 1440×900, 2560×1600, **2880×1800**.
- **Watch:** eine Größe für alle Sprachen; z. B. **416×496** (Series 12/11/10), Ultra 4/3 422×514.
- Skalierung: Bei gleichbleibender Oberfläche genügt die größte Größe.
- Drittseiten stimmen im Wesentlichen überein, Apples Seite gilt.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsUITests/DesignGalleryTests.swift` | Fotografiert Hauptbildschirme (Attachments `gallery-*`), Englisch, hell/dunkel; Vorlage für Start, Erfassen, Aufgabendaten |
| `LooseEndsUITests/MacGalleryTests.swift`, `MacUITestSupport.swift` | Mac-Fenster in der CI (`mac-gallery-*`), Fensterfoto beliebiger Größe, nicht 16:10 |
| `LooseEndsUITests/Watch/WatchCaptureUITests.swift` | Watch-UI-Test im watchOS-Simulator (`snapshot(...)`), `watch-test-proof` |
| `.github/workflows/ci.yml` (Z. 294–317, 333–462) | Export der Attachments als Artefakte `DesignGallery`, `MacGallery` |
| `scripts/sim.sh` | Simulator-Befehle (`test-proof`, `watch-test-proof`, `screenshot`) |
| `LooseEnds/App/*` | Startargumente `--ui-testing`, `--ui-testing-dark`, `--ui-testing-fields-standard` … |

## Existing Patterns
- Bilder entstehen als `XCTAttachment` (`keepAlways`) und werden aus dem `.xcresult` exportiert (`xcresulttool export attachments`).
- Sprache per Startargument `-AppleLanguages (de)`; Daten kommen aus dem Test (Aufgaben per Erfassen), nicht aus dem echten Bestand. Unter `--ui-testing` ist der Speicher leer und im Arbeitsspeicher.
- Mac-Bilder nur aus der CI (Regel in CLAUDE.md), nie von Hennings Mac.

## Simulatoren lokal
iPhone 17 (1206×2622, Dynamic Island medium: erfüllt die Pflicht), iPad Pro 13-inch (M5) (2064×2752), Apple Watch Series 12 46 mm (416×496). Kein iPhone 17 Pro Max (6,9″) vorhanden, nicht nötig.

## Dependencies
- Upstream: bestehende Bildtests und Startargumente; Simulator-Sperre `/tmp/loose-ends-testlauf.lock`.
- Downstream: Upload durch Claude-Desktop-Sitzung in App Store Connect (Bilder + Manifest); #625/#705 (Store-Angaben) laufen daneben.

## Risks & Considerations
- **Mac ist 16:10, das Fensterfoto nicht.** Fenster auf feste Größe bringen (z. B. 1440×900 pt = 2880×1800 px @2x, CI-Bildschirm muss reichen) oder Foto auf 16:10-Fläche setzen. Entscheidung in `/20-analyse`.
- **Alphakanal:** Simulator-PNGs können Alpha tragen; Export muss es entfernen.
- **Statusleiste:** echte Uhrzeit/Akku im Simulator; `simctl status_bar override` (9:41, voll) für saubere Bilder prüfen.
- **Inhalte:** keine persönlichen Daten; erfundene, stimmige deutsche Aufgaben. Hell wie gewählt („reine App-Bilder“); Dunkel nur falls Henning es will.
- **Watch** läuft im watchOS-Simulator, nicht in der CI-Galerie; Wege prüfen (`watch-test-proof`).
- Kein Gerätezugriff nötig, Hennings Geräte bleiben unberührt.
- Upload ist nicht Teil des Tickets; Manifest muss eindeutig sagen: Gerätegröße → Dateien in Reihenfolge.

## Analysis (2026-10-30, /20-analyse)

### Befund
- **iPhone/iPad:** Simulatoren liefern die Pflichtgrößen unmittelbar (iPhone 17 = 1206×2622, iPad Pro 13″ M5 = 2064×2752). Weg: neue Testklasse nach Vorbild `DesignGalleryTests`, aber Deutsch (`-AppleLanguages (de)`), Statusleiste per `simctl status_bar override` (9:41, voll), Export aus dem `.xcresult`, Alphakanal entfernen. Erfasste Sätze mit Datumswort ("morgen", "heute 15 Uhr") landen per Regel (`DueDateRule`) in „Jetzt“ — kein Modell nötig, keine Testdaten-Einspeisung.
- **Watch:** `WatchNowView` zeigt nur `ViewRules.nowRows`; unter `--ui-testing` ist der Speicher leer, eine Erfassung auf der Uhr landet in „Neu“, nicht in „Jetzt“. Für ein gefülltes Zifferblatt-Bild braucht die Uhr einen Startparameter, der deutsche Beispielaufgaben anlegt (kleine Änderung in `LooseEndsWatch/`, nur unter `--ui-testing`). Größe 416×496 kommt vom Series-12-Simulator (46 mm).
- **Mac (das eigentliche Problem):** Der CI-Mac hat einen Bildschirm von **1024×768 pt bei 1×** (Lauf 40914459991, `mac-gallery-light-window-size`: Fenster 1024×674 pt = 1024×674 px). Größtes 16:10-Bild darin: 1024×640 — **unter Apples Mindestgröße 1280×800**. Vom eigenen Mac scheidet aus (CLAUDE.md: Mac-Bilder nur aus der CI; Gerätewort).

### Wege für den Mac
1. **(Empfehlung) CI-Bildschirm vergrößern, Rückfall hochskalieren.** Zuerst im CI-Lauf `displayplacer`/`system_profiler` prüfen, ob sich die Auflösung auf ≥ 1440×900 stellen lässt; dann Fenster 1440×900 pt. Gelingt das nicht: Fensterfoto (≈1024×640) auf 1280×800 hochrechnen — leicht weich, aber zulässig und ohne Rahmen/Beschriftung.
2. **Vom eigenen Mac fotografieren** (2880×1800, scharf): braucht Hennings Wort „jetzt ist ein Test möglich“ und kippt die CLAUDE.md-Regel „Mac-Bilder nur aus der CI“. Als Alternative genannt, nicht empfohlen.
3. **Bild nachbauen (Mockup)** — verworfen: „reine App-Bilder“.

### Umfang / Scoping
Neue Dateien: `LooseEndsUITests/StoreScreenshotsTests.swift` (iPhone+iPad), Mac-Teil in `MacGalleryTests`-Nähe, Watch-Fixture + Test, `scripts/store-screenshots.sh` (Lauf, Export, Alpha entfernen, Größenprüfung, Manifest), `docs/reference/store-bilder.md` + Manifest. Schätzung ≈ 5 Dateien Code, ±250 LoC; bei Überschreitung in Schnitt 1 (iPhone+iPad+Manifest) und Schnitt 2 (Watch+Mac) teilen.

### Bildsatz (Vorschlag, je Gerät dieselbe Geschichte)
1 Start „Jetzt“ · 2 Erfassen (Text getippt) · 3 Liste „Neu“ · 4 Aufgabendetail · 5 „Erledigt“ nach Wochen mit Perlen. Watch: „Jetzt“-Liste, Erfassen. Hell, nur Deutsch, ohne Rahmen/Zeile.

### Ohne Modell
Nicht berührt; alle Inhalte kommen aus Regeln und Testtexten.

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsUITests/StoreScreenshotsTests.swift | CREATE | iPhone/iPad-Bilder auf Deutsch, 5 hell |
| LooseEndsUITests/MacGalleryTests.swift (oder Nachbar) | MODIFY/CREATE | Mac-Bilder 16:10, mind. 1280×800 |
| LooseEndsUITests/Watch/ (neuer Test) + LooseEndsWatch/LooseEndsWatchApp.swift | CREATE/MODIFY | Beispielaufgaben unter `--ui-testing`, 2 Bilder 416×496 |
| scripts/store-screenshots.sh | CREATE | Lauf, Export, Alpha entfernen, Größenprüfung, Manifest |
| docs/reference/store-bilder.md + Manifest | CREATE | Zuordnung Gerätegröße → Dateien, Anleitung für die Desktop-Sitzung |

### Scope Assessment
- Files: ~5 Code + 2 Doku
- Estimated LoC: +250 (bei Überschreitung zwei Schnitte: iPhone/iPad/Manifest, dann Watch/Mac)
- Risk Level: LOW (nur Test- und Skriptcode; einzige App-Änderung ein Testmodus-Parameter der Uhr). Mac-Größe ist das Risiko.

### Technical Approach
Siehe Wege oben: Simulator für iPhone/iPad/Watch, CI für Mac (Bildschirm vergrößern, Rückfall hochskalieren). Bildsatz von Henning bestätigt (2026-10-30): 5 hell je Gerät, Uhr 2, nur Deutsch, ohne Rahmen/Zeile.

### Dependencies
Simulator-Sperre `/tmp/loose-ends-testlauf.lock`; CI-Job „Mac Gallery“; #625/#705 laufen daneben.

### Open Questions
- [ ] Lässt sich der CI-Bildschirm auf ≥1440×900 stellen? (erst im CI-Lauf zu klären, Rückfall steht)
