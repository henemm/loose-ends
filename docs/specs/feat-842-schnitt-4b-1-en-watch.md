---
entity_id: feat-842-schnitt-4b-1-en-watch
type: feature
created: 2026-11-08
updated: 2026-11-08
status: draft
workflow: feat-842-s4b-en-watch
---

# Spec: #842 Schnitt 4b-1 — Englische App-Store-Bilder der Apple Watch erzeugen

## Approval

- [ ] Approved

Mit dem getippten `approved` gibt Henning zugleich frei (oder ändert vorher) den Abschnitt **Wortlaut zur Freigabe** (die englischen Beispielaufgaben, die als sichtbarer Inhalt auf den englischen Watch-Bildern stehen).

## Purpose

Die englische Seite des App Store hat seit Schnitt 4a englische Bilder für iPhone und iPad, aber noch keine für die Apple Watch. Schnitt 4b-1 erzeugt die zwei Watch-Bilder (`01-jetzt`: die Liste „Now“ mit „Capture“ und zwei sichtbaren Aufgaben, `02-gespeichert`: die Bestätigung „Saved“) in englischer Sprache aus demselben Foto-Test wie die deutschen. Sie landen unter `docs/store/screenshots/en/watch/` und im englischen Manifest (`en-US`) als dritter Geräteeintrag neben iPhone und iPad. Die deutschen Watch-Bilder bleiben unverändert.

Für Henning ändert sich: Er liest die englischen Beispielaufgaben unten und gibt sie frei oder ändert sie. Danach liegen die englischen Watch-Bilder im Repo, bereit zum Hochladen (Schnitt 4c). Weil dafür eine kleine Änderung in der Uhr-App nötig ist (die Beispielaufgaben legt die Uhr-App selbst an, nur im Testmodus), greift **Stufe 3**: nach dem Merge kommt ein TestFlight-Bau, und Henning prüft einmal, dass die Uhr-App normal startet. Mehr ist es nicht; die Uhr-App ändert sich im normalen Betrieb nicht.

Nicht in diesem Schnitt:

- **Mac-Bilder** (englisch) sind Schnitt 4b-2.
- **Hochladen und Platzieren bei Apple** ist Schnitt 4c; hier wird bei Apple nichts gelesen oder geschrieben.
- **Deutsche Watch-Bilder neu schreiben.** Die Uhrzeit auf der Uhr ist echte Zeit, der Watch-Simulator kann sie nicht setzen (`simctl status_bar override`: „Operation not supported“, #742). Ein Neuschreiben würde die veröffentlichten Bilder nur durch andere Uhrzeiten ersetzen. Der deutsche Lauf wird nur als Vergleich gefahren (AC-6).

Ohne Modell geht es nicht: nicht relevant. Die Uhr-App führt weder `EnrichmentCoordinator` noch `DueDateRule` aus, deshalb setzt der Seed die Fälligkeit „heute“ von Hand; ein Regelweg über den Satztext scheidet auf der Uhr aus (siehe Alternative A).

## Source

- **File:** `LooseEndsWatch/LooseEndsWatchApp.swift`, `LooseEndsUITests/Watch/WatchCaptureUITests.swift`, `scripts/sim.sh`, `scripts/store_screenshots.py`, `scripts/test_store_screenshots.py`
- **Identifier:** `LooseEndsWatchApp.seedStoreSample`, `WatchCaptureUITests.testPhotographStoreScreens`, `cmd_store_watch`, `main_watch(out_root, export)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `CaptureService.save(_:via:in:)` | Code | legt die Beispielaufgaben an; die Fälligkeit „heute“ setzt der Seed von Hand |
| `ModelContainerFactory.isUITesting` | Code | der Seed läuft nur unter `--ui-testing` und `--ui-testing-store-sample`; neu zusätzlich liest er die Texte aus `--ui-testing-store-sample-texts` |
| `store_set_lang` / `store_restore_lang` (`scripts/sim.sh`, seit 4a) | Skript | stellt die Systemsprache des Watch-Simulators um (Uhrzeit der Statusleiste im 12-Stunden-Format) und per EXIT-Trap zurück |
| `run_xcodebuild` in `sim.sh` (Zeile 318) | Skript | reicht `LOOSEENDS_UI_LANG` als `TEST_RUNNER_LOOSEENDS_UI_LANG` an die UI-Tests durch, aber nur wenn die Variable gesetzt ist |
| `LaunchLanguage.swift` | Test-Hilfe | **nicht nutzbar**: `project.yml` übersetzt für `LooseEndsWatchUITests` nur `LooseEndsUITests/Watch`, die Datei gehört nicht zum Watch-Testziel; der Watch-Test bekommt deshalb eine kleine eigene Tabelle (kein Verschieben der Datei in dieses Ziel, das wäre eine `project.yml`-Änderung ohne Not) |
| `xcrun xcresulttool export attachments` | Werkzeug | holt die Anhänge `store-*` aus dem Testergebnis |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsWatch/LooseEndsWatchApp.swift | MODIFY | `seedStoreSample` nimmt die drei Texte aus dem Startargument `--ui-testing-store-sample-texts <a\|b\|c>`; ohne Argument die heutige deutsche Liste. Nur unter `--ui-testing` und `--ui-testing-store-sample`. |
| LooseEndsUITests/Watch/WatchCaptureUITests.swift | MODIFY | `testPhotographStoreScreens` liest `LOOSEENDS_UI_LANG` (Standard `de`), setzt `-AppleLanguages`/`-AppleLocale`, die Beispieltexte (Startargument) und den erfassten Satz je Sprache aus einer kleinen Tabelle in der Datei |
| scripts/sim.sh | MODIFY | `cmd_store_watch`: Sprache `de` (Standard) oder `en`, sonst Abbruch vor dem Simulatorstart; Ziel `docs/store/screenshots/$lang`; Systemsprache des Watch-Simulators per `store_set_lang` und EXIT-Trap |
| scripts/test_store_screenshots.py | MODIFY | Tests für `main_watch` auf einem englischen Zielordner |
| CLAUDE.md | MODIFY | im Abschnitt Build: Zeile `store-watch` nennt die Sprache (`LOOSEENDS_UI_LANG=en`) und das Ziel je Sprache |
| docs/store/screenshots/en/watch/*.png, docs/store/screenshots/en/manifest.json | CREATE/MODIFY (erzeugt) | zwei Bilder und der Watch-Eintrag — Ergebnis des Laufs, kein Code |

`scripts/store_screenshots.py` bleibt unverändert: `main_watch` bekommt das Ziel vom Aufrufer (die Sprache steckt im Zielordner) und ersetzt nur den Watch-Eintrag im vorhandenen Manifest; ein Test sichert das zu (AC-1, AC-2).

### Estimated Changes
- Code-/Testdateien: **4** (Grenze 4–5 eingehalten), dazu eine Dokumentationszeile in `CLAUDE.md` und die erzeugten Bilder samt Manifest (zählen nicht als Code).
- LoC ehrlich geschätzt: `LooseEndsWatchApp` ca. 8, `WatchCaptureUITests` ca. 20, `sim.sh` ca. 25, `test_store_screenshots.py` ca. 40, `CLAUDE.md` 2 — zusammen **ca. +95/-5 LoC**, unter der 250er-Grenze (die Schätzung der Analyse von +60 war ohne die Tests der Sprachprüfung gerechnet).
- Produktcode: nur `LooseEndsWatchApp.seedStoreSample`, hinter `--ui-testing` und `--ui-testing-store-sample`; im normalen Betrieb ändert sich nichts.

## Implementation Details

**1. Seed mit Texten aus dem Startargument (`LooseEndsWatchApp`).** `seedStoreSample` liest die Texte aus `ProcessInfo.processInfo.arguments`: steht `--ui-testing-store-sample-texts` darin, ist das **nächste Argument** eine Liste, getrennt durch `|`. Sie wird nur übernommen, wenn sie genau drei nichtleere Einträge hat; sonst gilt die deutsche Liste („Steuerbescheid prüfen“, „Anna wegen Geburtstag anrufen“, „Blumen gießen“). Der Rest bleibt wie heute: `CaptureService.save(text, via: .watch, …)`, Fälligkeit `startOfDay(Date())`, ein `save`. Der Pfad bleibt hinter `--ui-testing` und `--ui-testing-store-sample`, also unerreichbar im normalen Start.

**2. Foto-Test (`testPhotographStoreScreens`).** Die Sprache kommt aus `LOOSEENDS_UI_LANG`, **Standard `de`** (wie `StoreScreenshotsTests` in 4a; der Test läuft in keiner CI-Datei, nur von Hand über `store-watch`). Eine kleine Tabelle in der Datei liefert je Sprache die Texte:

| | de | en |
|---|---|---|
| Sprachargumente | `-AppleLanguages (de) -AppleLocale de_DE` | `-AppleLanguages (en) -AppleLocale en_US` |
| Beispieltexte | Steuerbescheid prüfen \| Anna wegen Geburtstag anrufen \| Blumen gießen | Check the tax notice \| Call Anna about her birthday \| Water the flowers |
| erfasster Satz (Bild 02) | Steuerbescheid heute prüfen | Check the tax notice today |

Eine andere Sprache bricht den Test mit Meldung ab (kein stilles Deutsch). Die Bestätigung erkennt der Test schon an „Saved“ und „Gespeichert“, die Schaltflächen „Done“/„Fertig“ ebenso; daran ändert sich nichts. Die Zusicherung „mindestens zwei Zeilen unter Now“ (`watch.now.row`) bleibt und fängt einen Umbruch der englischen Titel, der eine Zeile aus dem Bild drängt.

**3. Aufruf (`sim.sh store-watch`).** `cmd_store_watch` setzt `lang="${LOOSEENDS_UI_LANG:-de}"`, prüft `de|en` (sonst Fehler **vor** dem ersten Simulatorstart, die Sprache wird Pfadbestandteil) und exportiert `LOOSEENDS_UI_LANG="$lang"`, damit `run_xcodebuild` sie durchreicht. Dann: Watch-Simulator wie in `cmd_watch_test` festlegen (`Apple Watch Series 12 (46mm)`), booten, `store_set_lang "$id" "$lang"`, EXIT-Trap `store_restore_lang`, danach der Lauf `cmd_watch_test WatchCaptureUITests/testPhotographStoreScreens`, Export der Anhänge und `python3 scripts/store_screenshots.py --watch docs/store/screenshots/$lang "$tmp"`. Die Systemsprache muss umgestellt werden, weil SpringBoard die Uhrzeit in der Sprache des Simulators zeichnet (nicht der App); auf Englisch steht die Uhrzeit im 12-Stunden-Format. Die echte Zeit bleibt (nicht setzbar) und ist hingenommen. Die Abschlussmeldung nennt Sprache und Ziel. Ob der Watch-Simulator den Neustart von `store_sim_reboot` verträgt, zeigt der erste echte Lauf; scheitert er dort, wird das Werkzeug repariert und nicht umgangen.

**4. Deutscher Vergleichslauf ohne Spuren.** `LOOSEENDS_UI_LANG=de ./scripts/sim.sh store-watch` (und ohne Variable) schreibt nach `docs/store/screenshots/de/watch/`. Vorher werden `01-jetzt.png` und `02-gespeichert.png` gesichert (Kopie außerhalb des Repos, im Scratchpad); der Lauf wird verglichen (AC-6), danach werden die deutschen Dateien und `de/manifest.json` auf den bisherigen Stand zurückgesetzt. Im Diff des Schnitts steht nichts unter `docs/store/screenshots/de/`.

**5. Zeilenumbruch.** Die englischen Titel haben 20, 28 und 17 Zeichen, die deutschen 21, 29 und 13; der längste englische („Call Anna about her birthday“) ist nur ein Zeichen kürzer als der deutsche, der auf 416 px schon umbricht oder passt. Englische Wörter brechen an anderen Stellen, deshalb entscheidet das Bild. Das Bild zeigt es: Brechen die ersten beiden Zeilen so, dass weniger als zwei Aufgaben unter „Now“ sichtbar sind, wird der Text geändert (nach Rücksprache mit Henning), das Bild nicht nachbearbeitet.

**Alternativen** (Plan-Bewertung; „Geräteliste“ = berührt einen Pfad der Stufe 3):

| Weg | Geräteliste | trägt? | Haken |
|---|---|---|---|
| A Erfassen per Oberfläche (wie iPhone/iPad) | nein | **nein** | Die Uhr setzt aus dem Text keine Fälligkeit (`LooseEndsWatch/` ruft weder `EnrichmentCoordinator` noch `DueDateRule`), also stünde nichts unter „Now“. |
| B Seed nach `Shared/` verlegen | ja (Aufruf bleibt in der App) | teilweise | gleiche Stufe 3, mehr Code, `Shared/` kompiliert auch in Widget-Ziele |
| C Store vom Test vorbefüllen | nein | zweifelhaft | Der Testprozess kommt nicht in die Sandbox der Uhr-App (App-Group und Container), nicht belegt tragfähig |
| D Deutsche Bilder nachbearbeiten (Texte tauschen) | nein | **nein** | zeigt nicht die echte App; widerspricht „Bilder entstehen nur aus echten UI-Tests“ (4a, Alternative C) |
| **E Startargument `--ui-testing-store-sample-texts` (gewählt)** | ja | ja | Stufe 3 (TestFlight), sonst minimal: Texte kommen aus dem Test, Deutsch bleibt der Rückfall |
| F Sprache aus `Locale.current` in der App, Texte in der App | ja | ja | Testdaten (zwei Sprachlisten) im Produktcode, sonst gleich E |

Warum E: Die Testdaten liegen im Test, wo die iPhone-/iPad-Sätze auch liegen; der Produktcode bekommt nur ein Argument statt einer zweiten Textliste (F). Kippt keine ADR. Eine echte Alternative zum Stand „fest verdrahtete deutsche Liste im Produktcode“ ist damit F oder, ohne Produktänderung, nur A/C/D, die nicht tragen.

## Wortlaut zur Freigabe

Das sind die englischen Beispielaufgaben, die auf den englischen Watch-Bildern zu lesen sind. Sie sind erfunden und gelten nur im Testmodus, kein Eintrag in der echten App. Sie sind sinngemäß die deutschen Watch-Aufgaben und stehen als Gegenstück zum englischen iPhone-Wortlaut aus 4a („Check the tax notice today“, „Water the flowers today“). Henning gibt sie mit `approved` frei oder nennt Änderungen.

| Deutsch (heute auf den Watch-Bildern) | Englisch (Vorschlag) |
|---|---|
| Steuerbescheid prüfen | Check the tax notice |
| Anna wegen Geburtstag anrufen | Call Anna about her birthday |
| Blumen gießen | Water the flowers |
| Steuerbescheid heute prüfen (erfasst, nur Bild 02) | Check the tax notice today |

Auf Bild 01 sind zwei der drei Aufgaben unter „Now“ sichtbar (die Reihenfolge bestimmt die App); die dritte steht darunter und ist angeschnitten oder nicht im Bild.

## Test Plan

### Automated Tests (TDD RED)

Python (`unittest`, `scripts/test_store_screenshots.py`, `sips` ersetzt wie bei den übrigen Tests der Datei, Klasse `WatchLanguageTests`):

- [ ] `test_watch_entry_is_added_to_en_manifest`: GIVEN ein Zielordner `en/` mit Manifest `en-US` (iPhone, iPad) und ein Watch-Export mit `store-01-jetzt`, `store-02-gespeichert` THEN `main_watch(en, export)` legt `en/watch/01-jetzt.png`, `02-gespeichert.png` an, das Manifest hat danach die Einträge `iphone`, `ipad`, `watch` in dieser Reihenfolge, `sprache` bleibt `en-US`, die Einträge von iPhone und iPad sind byte-gleich zu vorher, der Watch-Eintrag nennt Pixel `416x496`, Ordner `watch`, die beiden Dateien. (RED: der Test gibt es nicht; rot ist er, wenn `main_watch` das Manifest oder die Sprache verändert. Die Funktion ist schon sprachneutral, der Test hält das fest.)
- [ ] `test_watch_rerun_replaces_only_the_watch_entry`: GIVEN ein Manifest mit altem Watch-Eintrag und Mac-Eintrag THEN ersetzt ein erneuter `main_watch` nur `watch`; `iphone`, `ipad`, `mac` bleiben unverändert.
- [ ] `test_watch_run_leaves_readme_and_de_untouched`: GIVEN `en/README.md` mit Zusatzzeilen und ein `de/` mit Marker-Dateien THEN bleiben README und alles unter `de/` nach `main_watch(en, …)` byte-gleich.
- [ ] `test_watch_wrong_size_aborts`: GIVEN ein Watch-Bild mit anderen Maßen als 416×496 THEN `StoreError` und der Watch-Ordner bleibt wie vorher (nutzt `finish_device`; sichert, dass ein englischer Umbruch-/Skalierungsfehler nicht still durchgeht).

Shell (`sim.sh`, kein eigener Testrahmen vorhanden, wie in 4a): Die Sprachprüfung von `cmd_store_watch` wird durch den echten Aufruf belegt (AC-3), vor allem Ausgabe, Rückgabecode ungleich 0 und kein Simulatorstart.

Swift: `seedStoreSample` ist `private static` in der Uhr-App und aus einem Unit-Test-Ziel nicht erreichbar (die Uhr-App ist kein Testziel von `LooseEndsTests`). Statt eines Unit-Tests belegen es die echten Foto-Läufe (AC-4, AC-5, AC-6); das ist der Ausnahmefall der Scoping-Regeln, ausdrücklich benannt. Der **Watch-UI-Test** `testPhotographStoreScreens` ist selbst der Fotolauf (kein Ergebnis ohne Bilder): Er bricht ab, wenn weniger als zwei Zeilen unter „Now“ stehen oder die Bestätigung fehlt.

## Acceptance Criteria

- **AC-1:** Given ein englischer Zielordner mit Manifest (`en-US`, iPhone, iPad), When `main_watch` die Watch-Bilder einträgt, Then stehen `watch/01-jetzt.png` und `watch/02-gespeichert.png` im Ordner, das Manifest nennt die Reihenfolge iPhone, iPad, Watch mit unverändertem `en-US` und unveränderten iPhone-/iPad-Einträgen, und der Watch-Eintrag nennt `416x496`. Belegt durch `test_watch_entry_is_added_to_en_manifest`.
- **AC-2:** Given ein Manifest mit altem Watch- und Mac-Eintrag und eine README mit Zusatzzeilen, When `main_watch` erneut läuft, Then wird nur der Watch-Eintrag ersetzt, Mac, iPhone, iPad, README und der Ordner `de/` bleiben unverändert; ein Bild mit falschen Maßen bricht mit `StoreError` ab und lässt den Watch-Ordner stehen. Belegt durch `test_watch_rerun_replaces_only_the_watch_entry`, `test_watch_run_leaves_readme_and_de_untouched`, `test_watch_wrong_size_aborts`.
- **AC-3:** Given der Aufruf `LOOSEENDS_UI_LANG=fr ./scripts/sim.sh store-watch`, When er startet, Then bricht er mit Meldung („nur de oder en“) und Rückgabecode ungleich 0 ab, bevor ein Simulator gestartet oder eine Datei geschrieben wird. Belegt durch den echten Aufruf (Ausgabe, Code, Simulatorliste und `git status` unverändert).
- **AC-4:** Given `store-watch` läuft ohne `LOOSEENDS_UI_LANG` oder mit `de`, When der Test startet, Then startet die Uhr-App deutsch und der Seed legt die deutsche Liste an (Rückfall ohne `--ui-testing-store-sample-texts`); mit `LOOSEENDS_UI_LANG=en` startet sie englisch (`-AppleLanguages (en)`) und der Seed legt die drei freigegebenen englischen Texte an. Belegt durch das Startargument im Testprotokoll beider Läufe und den sichtbaren Text auf `01-jetzt` (deutsch bzw. englisch). Außerhalb von `--ui-testing` ist der Seed nicht erreichbar: Beleg durch Lesen von `LooseEndsWatchApp.init` (beide Argumente sind Bedingung) und den bestehenden Test `testAppOpensOnNow`, der ohne `--ui-testing-store-sample` eine leere Liste („watch.now.empty“) sieht.
- **AC-5:** Given der freigegebene Wortlaut, When `LOOSEENDS_UI_LANG=en ./scripts/sim.sh store-watch` im Watch-Simulator (Series 12, 46 mm) läuft, Then besteht der Test, es liegen zwei PNG (416×496, ohne Alphakanal) unter `docs/store/screenshots/en/watch/`, und das englische `manifest.json` enthält zusätzlich den Watch-Eintrag bei unverändertem iPhone-/iPad-Teil; die README `en` ist unberührt. Beide Bilder wurden geöffnet und beschrieben: `01-jetzt` zeigt die englische Oberfläche („Now“, „Capture“), mindestens zwei der Aufgaben wörtlich wie freigegeben und die Uhrzeit im 12-Stunden-Format (echte Zeit, hingenommen); `02-gespeichert` zeigt „Saved“ mit Haken; **keine deutschen Wörter** auf beiden Bildern. Belegt durch den echten Lauf, `sips`-Maße und die Bildbeschreibung im Abnahmebericht.
- **AC-6:** Given die deutschen Watch-Bilder sind veröffentlicht, When `LOOSEENDS_UI_LANG=de ./scripts/sim.sh store-watch` (und ohne Variable) als Vergleich läuft, Then entsprechen die dabei entstandenen deutschen Bilder (nur zum Vergleich, danach zurückgesetzt) den bisherigen in Aufbau, Text, Zeilenzahl und Maßen; erlaubter Unterschied ist nur die Uhrzeit in der Statusleiste (echte Zeit, nicht setzbar). Vor und nach dem Lauf wurden beide Bilder nebeneinander geöffnet, der Unterschied benannt, danach sind die deutschen Dateien samt `de/manifest.json` auf den bisherigen Stand zurückgesetzt, und der Diff des Schnitts enthält nichts unter `docs/store/screenshots/de/`. Belegt durch den echten Lauf, die Gegenüberstellung im Abnahmebericht und `git status` unter `de/`.
- **AC-7:** Given ein Lauf mit Sprache `en`, When er endet (auch bei Abbruch), Then steht die Systemsprache des Watch-Simulators wieder so wie vorher (EXIT-Trap, `store_restore_lang`). Belegt durch `defaults read -g AppleLanguages` und `AppleLocale` im Watch-Simulator vor und nach dem Lauf (gleiche Werte) und die Logzeile „Systemsprache … → en/en_US“ ohne Warnung „nicht zurückgesetzt“.
- **AC-8:** Given die Änderung am Produktcode, When die Unit-Tests, die Skript-Tests und der Watch-UI-Test `testAppOpensOnNow` laufen, Then sind alle grün: `./scripts/sim.sh sim-unit` (alle Klassen), `python3 -m unittest scripts/test_store_screenshots.py` samt den übrigen Skript-Tests, `./scripts/sim.sh watch-test-proof WatchCaptureUITests`; `./scripts/sim.sh build` übersetzt Uhr-App und Watch-Testziel. Belegt durch die Laufbelege (`test-proof`-Beleg des Watch-Laufs).
- **AC-9:** Given (Stufe 3) die Änderung berührt `LooseEndsWatch/` (Geräteliste, CLAUDE.md), When der Schnitt gemergt ist, Then entsteht ein TestFlight-Bau (Buildnummer im Bericht) und Henning bekommt die Nummer und den einen Prüfschritt: Uhr-App öffnen, sie startet wie bisher mit „Jetzt“ und „Erfassen“, seine eigenen Aufgaben statt Beispielaufgaben aus dem Fototest, kein Absturz; seine Rückmeldung schließt den Geräte-Punkt. Bis dahin bleibt #842 offen. Auf Hennings Geräten läuft vorher nichts (auch nichts Lesendes) ohne sein wörtliches „jetzt ist ein Test möglich“; der Beleg für AC-4 bis AC-8 kommt aus dem Simulator.

**Abnahmeweg.** Stufe 1: Python-Tests, Unit-Tests, Übersetzen (AC-1, AC-2, AC-8). Stufe 2: die echten Läufe `store-watch` für `en` und `de` im Watch-Simulator (AC-3 bis AC-7); sie sind zugleich der Beleg, weil die Bilder das Ergebnis sind. **Stufe 3 greift** (`LooseEndsWatch/` steht in der Geräteliste): ehrlich benannt ist, dass die Änderung im normalen Betrieb nichts bewirkt und der Geräte-Schritt nur belegt, dass die Uhr-App unverändert startet.

## Definition of Done

- [ ] Die neuen Python-Tests waren vor der Umsetzung vorhanden (RED, soweit sie die neue Sprachführung prüfen) und sind danach grün; die vorhandenen `test_store_screenshots.py`-Tests und `scripts/test_sim_run_xcodebuild.py` bleiben grün.
- [ ] Henning hat die englischen Beispielaufgaben freigegeben oder geändert; die Bilder zeigen genau den freigegebenen Wortlaut.
- [ ] Zwei englische Watch-Bilder und der Watch-Eintrag im englischen Manifest liegen im Repo; beide Bilder wurden geöffnet und im Abnahmebericht beschrieben.
- [ ] Der deutsche Vergleichslauf ist gefahren und beschrieben; `docs/store/screenshots/de/` ist im Diff unberührt.
- [ ] `CLAUDE.md` (Abschnitt Build) nennt die Sprache beim Befehl `store-watch`.
- [ ] TestFlight-Bau nach dem Merge, Buildnummer an Henning, seine Rückmeldung zum Start der Uhr-App liegt vor (AC-9).
- [ ] #842 kommentiert: Schnitt 4b-1 erledigt, offen 4b-2 (Mac) und 4c (Hochladen).

## Seiteneffekte

- Geänderte Dateien: die vier oben plus `CLAUDE.md`; neue Dateien nur `docs/store/screenshots/en/watch/*.png`, geänderte `en/manifest.json` und die Belege unter `docs/artifacts/feat-842-s4b-en-watch/`.
- Neues Startargument `--ui-testing-store-sample-texts` (nur im Testmodus der Uhr-App); keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies.
- Der Watch-Simulator bekommt für die Dauer des Englisch-Laufs die Systemsprache Englisch und wird danach zurückgesetzt (Neustart des Simulators, wie bei iPhone/iPad in 4a).
- Das Verhalten für Deutsch bleibt: ohne Argument gleiche Liste, gleiches Ziel `de` bei gesetztem `LOOSEENDS_UI_LANG=de` oder ohne Variable.

## Risiken

- **Stufe 3.** Jede Änderung unter `LooseEndsWatch/` löst den Gerätelauf aus, auch wenn sie nur den Testmodus berührt. Gegenmaßnahme: Änderung minimal, hinter zwei Startargumenten (AC-4, AC-9).
- **Uhrzeit.** Echte Zeit, nicht setzbar; auf den englischen Bildern im 12-Stunden-Format. Hingenommen und im Bericht genannt; der Store zeigt sie ohnehin als Momentaufnahme.
- **Zeilenumbruch.** „Call Anna about her birthday“ kann auf 416 px umbrechen; zwei Aufgaben müssen sichtbar bleiben (Test-Zusicherung, AC-5).
- **Neustart des Watch-Simulators.** `store_set_lang` und `store_restore_lang` sind bisher nur auf iPhone und iPad gelaufen; ob `store_sim_reboot` den Watch-Simulator sauber zurückbringt, ist ungeprüft. Scheitert es, wird die Funktion repariert (AC-7).
- **Falsche Standardsprache.** Ein Lauf ohne `LOOSEENDS_UI_LANG` darf nicht englisch laufen (der Watch-Test soll Deutsch als Standard haben, ausdrückliche Zuweisung in `sim.sh`); AC-4 und AC-6 belegen es.
- **Kein Unit-Test für den Seed.** Die Uhr-App ist kein Unit-Test-Ziel; der Seed wird nur durch die echten Läufe belegt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Test- und Werkzeugerweiterung; die einzige Produktcode-Änderung ist ein Testmodus-Argument ohne Eingriff in eine Architekturentscheidung.

## Changelog

- 2026-11-08: Initial spec created (Schnitt 4b-1 von #842: englische Watch-Bilder, Texte per Startargument `--ui-testing-store-sample-texts`, Sprache als Parameter von `store-watch`, Ablage `docs/store/screenshots/en/watch/`, deutscher Lauf nur als Vergleich, Stufe 3 benannt; Mac ist 4b-2, Hochladen 4c)
