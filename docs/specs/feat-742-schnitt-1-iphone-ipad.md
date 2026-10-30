---
entity_id: feat-742-schnitt-1-iphone-ipad
type: feature
created: 2026-10-30
updated: 2026-10-30
status: draft
workflow: feat-742-store-screenshots
---

# Spec: #742 Schnitt 1 — App-Store-Bilder für iPhone und iPad (Deutsch, hell)

## Approval

- [ ] Approved

## Purpose

Für das Going Live braucht App Store Connect Bilder der App je Gerätegröße. Henning will sie nicht von Hand
aufnehmen, sondern einer Claude-Desktop-Sitzung zum Hochladen übergeben. Schnitt 1 erzeugt aus dem iOS-Simulator
reproduzierbar fünf Bilder für das iPhone (1206×2622) und fünf für das iPad (2064×2752): deutsch, hell, reine App-Bilder
ohne Rahmen und ohne Bildunterzeile, saubere Statusleiste (9:41, Akku voll), ohne Alphakanal. Dazu ein Manifest, das je
Gerätegröße die Dateien in Upload-Reihenfolge nennt. Der Upload selbst gehört nicht zum Ticket.

Watch (416×496) und Mac (16:10, mind. 1280×800) folgen in **Schnitt 2** (eigene Spec): Die Uhr braucht eine Änderung in
`LooseEndsWatch/`, der Mac die offene Frage nach der CI-Bildschirmgröße.

Kein Modellpfad. Die Inhalte entstehen aus erfassten Testsätzen; die Fälligkeit setzt `DueDateRule`
(Regel) beim Erfassen, kein Modell. Kein Gerät von Henning wird berührt, nur Simulatoren.

Quelle der Größen: Apple, „Screenshot specifications“ (https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications,
Stand 2026-10-30): iPhone Pflicht 1206×2622 oder 1179×2556, iPad 13″ Pflicht 2064×2752 oder 2048×2732; 1 bis 10 Bilder je Größe;
`.png`/`.jpg`; kein Alphakanal.

## Source

- **File:** `LooseEndsUITests/StoreScreenshotsTests.swift` (neu), `scripts/store_screenshots.py` (neu), `scripts/sim.sh` (neuer Befehl)
- **Identifier:** `StoreScreenshotsTests.testPhotographStoreScreens`, `store_screenshots.py` (`finish`, `build_manifest`), `cmd_store_screenshots`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `DesignGalleryTests` | Vorbild | Gleiche Hilfen (`capture`, `element`, Startargumente); wird nicht verändert, Hilfen werden kopiert, nicht geteilt |
| `--ui-testing`, `-AppleLanguages (de)`, `-contextsEmptiedByUser NO`, `-startShowsProjects/Contexts NO` | Startargumente | Leerer Speicher im Arbeitsspeicher, Deutsch, Startseite wie beim ersten Start |
| `simctl status_bar <id> override/clear` | extern | Uhrzeit 9:41, Akku voll, volle Balken |
| `xcrun xcresulttool export attachments` | extern | Bilder aus dem Ergebnisbündel holen (wie die CI bei `DesignGallery`) |
| `sips` | extern (macOS) | Alphakanal entfernen, Größe und `hasAlpha` lesen |
| `scripts/sim.sh` (`run_xcodebuild`, Sperre `/tmp/loose-ends-testlauf.lock`, `cmd_boot`) | Skript | Lauf, Simulatorwahl per `LOOSEENDS_SIM` |
| Simulatoren „iPhone 17“, „iPad Pro 13-inch (M5)“ | Umgebung | Liefern die Pflichtgrößen unmittelbar |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsUITests/StoreScreenshotsTests.swift | CREATE | Ein Test, fünf Bilder pro Lauf, für iPhone und iPad dieselbe Geschichte |
| scripts/store_screenshots.py | CREATE | Export lesen, Alphakanal entfernen, Größen prüfen, Dateien benennen, `manifest.json` und `README.md` schreiben |
| scripts/test_store_screenshots.py | CREATE | Tests der reinen Teile (Benennung, Größenprüfung, Manifest) |
| scripts/sim.sh | MODIFY | Befehl `store-screenshots` samt Kopfkommentar: Statusleiste setzen, je Gerät Test fahren, exportieren, Statusleiste zurücksetzen |
| CLAUDE.md | MODIFY | Eine Befehlszeile im Abschnitt „Build“ |
| docs/store/screenshots/de/** | CREATE (erzeugt) | Bilder, `manifest.json`, `README.md` für die Desktop-Sitzung, eingecheckt |

### Estimated Changes
- Files: 5 (4 Code/Skript + `CLAUDE.md`) + erzeugte Ablage
- LoC: +260/-0 (Test ≈ 110, `store_screenshots.py` ≈ 70, Python-Test ≈ 50, `sim.sh` ≈ 28, `CLAUDE.md` 2)
- Die Schätzung liegt knapp über ±250. Wird die Grenze im Bau tatsächlich gerissen, werden `manifest.json`/`README.md` samt Python-Test in einen Schnitt 1b abgespalten.

## Implementation Details

**Bildsatz (je Gerät, hell, Deutsch)** — Dateien `01-start`, `02-erfassen`, `03-neu`, `04-detail`, `05-erledigt`:

1. `01-start`: Startseite mit „Jetzt“ gefüllt (Sätze mit Datumswort, z. B. „Steuerbescheid heute prüfen“, „Anna morgen wegen Sonntag anrufen“, „Rasen mähen“; Regel `DueDateRule` bringt sie nach „Jetzt“).
2. `02-erfassen`: Erfassen-Fenster offen, ein Satz getippt, vor „Fertig“.
3. `03-neu`: Liste „Neu“ mit mindestens zwei Aufgaben.
4. `04-detail`: Aufgabendetail einer Aufgabe mit Fälligkeit („Steuerbescheid …“).
5. `05-erledigt`: Ansicht „Erledigt“ mit mindestens einer erledigten Aufgabe (Wischen auf „Erledigt“, Rückgängig-Frist von 3 s abwarten).

Die erfundenen Aufgaben sind harmlos und stammen nicht aus dem echten Bestand (unter `--ui-testing` ist der Speicher leer und im Arbeitsspeicher).
Eine Perle am erledigten Eintrag (Analyse: „nach Wochen mit Perlen“) gehört **nicht** zur Pflicht dieses Schnitts: Das Feld „Perle sammeln“
ist standardmäßig aus, der Weg über das Menü ist im UI-Test bisher ungeprüft. Geht er stabil, kommt die Perle dazu; sonst steht die Abweichung im Abschlussbericht.

**Aufnahme:** `XCUIScreen.main.screenshot()` (ganzer Bildschirm samt Statusleiste, nicht nur das App-Fenster), Ausrichtung hochkant
(`XCUIDevice.shared.orientation = .portrait`), als `XCTAttachment` `keepAlways` mit den Namen `store-<nn>-<name>`. Der Test verzweigt nicht nach Gerät;
iPad im Hochformat nimmt wie das iPhone den kompakten Startzweig (Navigation per Schieben).

**`sim.sh store-screenshots`:** (1) Sperre holen, Projekt erzeugen. (2) Je Gerät in der Liste `iPhone 17`, `iPad Pro 13-inch (M5)` (Ordner `iphone/` und `ipad/`): starten, `simctl status_bar override --time 9:41 --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3`, Test `StoreScreenshotsTests` fahren (über `cmd_test_proof`, also mit `-resultBundlePath` und dem Beleg aus #145, den AC-8 meint), Anhänge exportieren, `status_bar clear` (auch bei Fehlschlag). (3) `store_screenshots.py` aufrufen. Das Skript nimmt `--dry-run` nicht an; Bilder entstehen nur aus einem echten Lauf.

**`store_screenshots.py`:** je Gerät aus dem Export die fünf `store-*`-Anhänge lesen, Alphakanal entfernen (PNG→BMP→PNG über `sips`, bleibt verlustfrei; Rückfall: JPEG bester Güte, dann Endung `.jpg`), Größe und `hasAlpha` mit `sips -g` prüfen, nach `docs/store/screenshots/de/<gerät>/<nn>-<name>.png` schreiben, `manifest.json` erzeugen. Bricht mit Meldung ab, wenn ein Bild fehlt, falsch groß ist oder Alpha behält. Alte Dateien des Geräteordners werden vorher entfernt, damit keine Altbilder bleiben.

**Manifest:** `docs/store/screenshots/de/manifest.json`: Sprache `de-DE`, je Gerätegröße ein Eintrag `{ "anzeige": "iPhone 6.3\" (Dynamic Island)", "pixel": "1206x2622", "dateien": [Reihenfolge 01…05] }`, ebenso iPad 13″ `2064x2752`; dazu Erzeugungszeit und Commit-Kennung. `README.md` daneben: eine Anleitung in zwei Sätzen für die Desktop-Sitzung (Apples Namen der Gerätegrößen, Reihenfolge = Dateinamen, keine Bildunterzeilen). Die ASC-API-Bezeichner der Anzeigegrößen werden **nicht** geraten; die Desktop-Sitzung ordnet nach Pixelgröße.

**Alternativen, nicht gewählt:**
- *Bilder von Hennings Geräten:* verboten ohne sein Wort, bringt echte Daten ins Bild.
- *Gerahmte Bilder mit Texten (Marketing-Look):* von Henning ausgeschlossen („reine App-Bilder“).
- *Fastlane `snapshot`:* neue Abhängigkeit ohne Freigabe; `xcresulttool` genügt.
- *Größte Größe (iPhone 6.9″) liefern:* Apple verlangt sie nicht; 1206×2622 erfüllt die Pflicht, und ein weiterer Simulator wäre Mehraufwand.

Keine ADR wird gekippt.

## Test Plan

### Automated Tests (TDD RED)

`scripts/test_store_screenshots.py` (Standardbibliothek, `sips` durch Attrappe ersetzt):
- [ ] `test_names_follow_order`: GIVEN fünf Anhänge `store-01-start` … `store-05-erledigt` WHEN Dateinamen gebildet THEN `01-start.png` … `05-erledigt.png`, in dieser Reihenfolge.
- [ ] `test_missing_image_aborts`: GIVEN nur vier Anhänge WHEN `finish` THEN Exit ≠ 0, Meldung nennt `05-erledigt`.
- [ ] `test_wrong_size_aborts`: GIVEN iPhone-Bild 1179×2556 WHEN `finish` THEN Abbruch mit beiden Größen in der Meldung.
- [ ] `test_alpha_aborts_when_not_removed`: GIVEN `hasAlpha: yes` nach der Entfernung THEN Abbruch.
- [ ] `test_manifest_lists_both_sizes`: GIVEN beide Geräte vollständig THEN `manifest.json` hat genau zwei Einträge mit `1206x2622` und `2064x2752`, je fünf Dateien in Reihenfolge, Sprache `de-DE`.
- [ ] `test_old_files_removed`: GIVEN eine Altdatei `99-alt.png` im Geräteordner WHEN `finish` THEN sie ist weg.

`LooseEndsUITests/StoreScreenshotsTests.swift` (UI-Test, läuft per `sim.sh test-proof StoreScreenshotsTests` auf dem iPhone und mit `LOOSEENDS_SIM="iPad Pro 13-inch (M5)"` auf dem iPad):
- [ ] `testPhotographStoreScreens`: GIVEN leerer Speicher, Deutsch WHEN drei Sätze erfasst, einer erledigt und die fünf Ansichten erreicht THEN je Ansicht ein Anhang `store-<nn>-<name>`; Zwischenstände werden per Kennung geprüft (Zeile „Jetzt“ vorhanden, Detail geöffnet, „Erledigt“ nicht leer).

## Acceptance Criteria

- **AC-1:** `./scripts/sim.sh store-screenshots` erzeugt je Gerät fünf PNG-Dateien `01-start` … `05-erledigt` unter `docs/store/screenshots/de/iphone/` und `…/ipad/`. Belegt durch Lauf und Dateiliste.
- **AC-2:** Alle iPhone-Bilder sind exakt 1206×2622 px, alle iPad-Bilder exakt 2064×2752 px, keines hat einen Alphakanal. Belegt durch `sips -g pixelWidth -g pixelHeight -g hasAlpha` je Datei (Ausgabe im Abschlussbericht) und die Python-Tests `test_wrong_size_aborts`, `test_alpha_aborts_when_not_removed`.
- **AC-3:** Die Bilder sind deutsch und hell, ohne Rahmen und ohne Bildunterzeile; die Statusleiste zeigt 9:41 mit vollem Akku. Belegt durch Ansehen aller zehn Bilder (geöffnet und beschrieben im Abschlussbericht, nicht gezählt) und `simctl status_bar … clear` danach.
- **AC-4:** Die Bilder enthalten keine persönlichen Daten: nur die Testsätze des Tests. Belegt durch Ansehen (AC-3) und Prüfung, dass der Test nur im Arbeitsspeicher läuft (`--ui-testing`).
- **AC-5:** `01-start` zeigt „Jetzt“ mit mindestens zwei Zeilen, `03-neu` mindestens zwei Aufgaben, `04-detail` das Detail mit Fälligkeit, `05-erledigt` mindestens eine erledigte Aufgabe. Belegt durch Ansehen (AC-3) und die Zwischenprüfungen des UI-Tests.
- **AC-6:** `manifest.json` nennt je Gerätegröße Pixelmaß und die Dateien in Upload-Reihenfolge; `README.md` erklärt der Desktop-Sitzung die Zuordnung. Belegt durch `test_manifest_lists_both_sizes` und Diff.
- **AC-7:** Die Statusleiste des Simulators wird auch bei einem fehlgeschlagenen Lauf zurückgesetzt, und ein zweiter Lauf lässt keine Altbilder zurück. Belegt durch `test_old_files_removed` und einen absichtlich abgebrochenen Lauf (`simctl status_bar … list` zeigt danach keine Überschreibung).
- **AC-8:** Die App wird für die Abnahme benutzt, nicht nur gebaut: Der Lauf aus AC-1 ist der Nachweis (`test-proof`-Beleg für iPhone und iPad). Belegt durch `docs/artifacts/feat-742-store-screenshots/simulator-run.txt`.

Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] Die sechs Python-Tests waren vor der Umsetzung rot und sind danach grün.
- [ ] `./scripts/sim.sh store-screenshots` läuft grün; zehn Bilder liegen in `docs/store/screenshots/de/`, geprüft nach AC-2.
- [ ] Alle zehn Bilder wurden angesehen und beschrieben (AC-3, AC-4, AC-5).
- [ ] `manifest.json` und `README.md` liegen bei den Bildern.
- [ ] `scripts/sim.sh` Kopfkommentar und `CLAUDE.md` („Build“) enthalten den neuen Befehl.
- [ ] Ticket #742 bleibt offen für Schnitt 2 (Watch, Mac); Folgeticket-Verweis steht im Abschlussbericht.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Test- und Werkzeugcode, kein Produktcode, keine Architekturänderung.

## Changelog

- 2026-10-30: Initial spec created
