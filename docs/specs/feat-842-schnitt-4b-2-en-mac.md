---
entity_id: feat-842-schnitt-4b-2-en-mac
type: feature
created: 2026-11-08
updated: 2026-11-08
status: draft
workflow: feat-842-s4b2-en-mac
---

# Spec: #842 Schnitt 4b-2 — Englische App-Store-Bilder des Mac erzeugen

## Approval

- [ ] Approved

Der englische Wortlaut der vier Beispielaufgaben ist seit Schnitt 4a freigegeben und wird unverändert übernommen (`LaunchLanguage`, Schlüssel `storeTask1` bis `storeTask4`). Henning muss hier nichts neu entscheiden; `approved` gibt die Umsetzung frei.

## Purpose

Die englische Seite des App Store hat seit 4a Bilder für iPhone und iPad und seit 4b-1 für die Apple Watch, aber noch keine für den Mac. Schnitt 4b-2 erzeugt die vier Mac-Bilder (`01-start`, `03-neu`, `04-detail`, `05-erledigt`, 1280×800, 16:10) in englischer Sprache aus demselben Fototest wie die deutschen. Sie landen unter `docs/store/screenshots/en/mac/` und im englischen Manifest (`en-US`) als Mac-Eintrag. Die deutschen Mac-Bilder bleiben unverändert.

Für Henning ändert sich: nichts, was er tun müsste. Danach liegen die englischen Mac-Bilder im Repo, bereit zum Hochladen (Schnitt 4c). Am Produkt ändert sich nichts; die App wird nicht angefasst. Die Mac-Bilder entstehen wie bisher ausschließlich in der CI, nie auf Hennings Mac.

Nicht in diesem Schnitt:

- **Hochladen und Platzieren bei Apple** ist Schnitt 4c; hier wird bei Apple nichts gelesen oder geschrieben.
- **Deutsche Mac-Bilder neu schreiben.** Der deutsche Lauf dient nur als Gegenprobe (AC-6); veröffentlichte Dateien unter `de/` bleiben im Diff unberührt.
- **Englische Bilder für iPhone, iPad, Watch** sind erledigt (4a, 4b-1).

Ohne Modell geht es nicht: nicht relevant. Test- und Werkzeugarbeit; die Fälligkeit „heute“ der Beispielaufgaben kommt wie bei den englischen iPhone-Bildern allein aus dem Satztext über `DueDateRule` mit `EnglishPack`.

## Source

- **File:** `LooseEndsUITests/MacStoreScreenshotsTests.swift`, `.github/workflows/store-mac.yml`, `scripts/test_store_screenshots.py`, `docs/store/screenshots/en/README.md`
- **Identifier:** `MacStoreScreenshotsTests.testPhotographStoreScreens`, Job `store-mac` (`workflow_dispatch.inputs.language`), `main_mac(out_root, export)`, `MacLanguageTests`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LaunchLanguage` (`LooseEndsUITests/LaunchLanguage.swift`) | Test-Hilfe | `locale(for:)` und `phrase(_:in:)` mit `storeTask1` bis `storeTask4` (de/en, Wortlaut seit 4a freigegeben). Die Datei gehört zum Testziel `LooseEndsUITests` (`project.yml` schließt nur `Watch/**` aus) und kompiliert damit auch ins Mac-UI-Testziel; sie bleibt unverändert. Ihr Standard `en` wird bewusst nicht gekippt. |
| `macLaunch(dark:locale:extra:)` (`MacUITestSupport.swift`) | Test-Hilfe | setzt `-AppleLanguages (xx)` aus dem Locale-Präfix und `-AppleLocale`; bleibt unverändert |
| `StoreScreenshotsTests` (4a) | Muster | eigene Standardsprache `de` aus `LOOSEENDS_UI_LANG`, Phrasen über `LaunchLanguage.phrase(_:in:)` |
| `scripts/store_screenshots.py` `main_mac` | Skript | schreibt `mac/` und ersetzt nur den Mac-Eintrag im Manifest; sprachneutral (die Sprache steckt im Zielordner), Reihenfolge `MAC["order"]` = 01-start, 03-neu, 04-detail, 05-erledigt; bleibt unverändert |
| `store-mac.yml` | CI | einziger Weg zu Mac-Bildern (#742 S2b); Artefakt mit den Anhängen `store-*` |
| Accessibility-IDs `startCaptureField`, `viewRow_new`, `taskRow_*`, `detailRawTextMarker`, `detailCompleteButton`, `viewRow_done` | App | sprachunabhängig, der Testablauf bleibt gleich |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsUITests/MacStoreScreenshotsTests.swift | MODIFY | Sprache aus `LOOSEENDS_UI_LANG`, Standard `de`; Locale über `LaunchLanguage.locale(for:)`, die vier Aufgaben über `LaunchLanguage.phrase("storeTask1…4", in:)`; Klassenkommentar „German or English“ (ca. 20 LoC) |
| .github/workflows/store-mac.yml | MODIFY | `workflow_dispatch.inputs.language` (choice `de`/`en`, Standard `de`); im Testschritt `env: TEST_RUNNER_LOOSEENDS_UI_LANG: ${{ inputs.language \|\| 'de' }}` (ein Push auf `store/mac` trägt keine Eingaben); Artefaktname `StoreMac-<Sprache>` (ca. 10 LoC) |
| scripts/test_store_screenshots.py | MODIFY | Klasse `MacLanguageTests` nach Muster `WatchLanguageTests`; schließt die Lücke „bisher kein Test für `main_mac`“ (ca. 50 LoC) |
| docs/store/screenshots/en/README.md | MODIFY | 2–3 Zeilen: Watch (`watch/`, 416×496, seit 4b-1 fehlend) und Mac (`mac/`, 1280×800, `store-mac.yml` mit `language=en`); das Skript überschreibt die README nie |
| docs/store/screenshots/en/mac/*.png, docs/store/screenshots/en/manifest.json | CREATE/MODIFY (erzeugt) | vier Bilder und der Mac-Eintrag — Ergebnis des CI-Laufs, eigener zweiter PR, kein Code |

Nicht betroffen (geprüft): `scripts/sim.sh` (kein Mac-Store-Befehl), `ci.yml`, die CI-Wächter (`test_ci_*.py` lesen `store-mac.yml` nicht), `LaunchLanguage.swift`, `MacUITestSupport.swift`, `scripts/store_screenshots.py`, `docs/store/screenshots/de/`.

### Estimated Changes
- **PR 1:** 4 Dateien (Grenze 4–5 eingehalten), ca. **+85/−5 LoC** (Test 20, Workflow 10, Python-Test 50, README 5), unter der 250er-Grenze.
- **PR 2:** erzeugte Bilder und Manifest; zählen nicht als Code.
- Produktcode: keiner. Es ändert sich weder App noch Berechtigung.

## Implementation Details

**1. Fototest (`MacStoreScreenshotsTests`).** Die Sprache kommt aus `LOOSEENDS_UI_LANG`, **Standard `de`** (wie `StoreScreenshotsTests`): `private static let language = ProcessInfo.processInfo.environment["LOOSEENDS_UI_LANG"] ?? "de"`. Der Start ruft `macLaunch(dark: false, locale: LaunchLanguage.locale(for: Self.language), extra: ["--ui-testing-store-window"])`, die Aufgaben sind `["storeTask1", "storeTask2", "storeTask3", "storeTask4"].map { LaunchLanguage.phrase($0, in: Self.language) }`. Die deutschen Texte in `LaunchLanguage` sind wortgleich mit den bisherigen Literalen im Test (geprüft), also ändern sich die deutschen Bilder inhaltlich nicht. Der Ablauf (Erfassen, „Neu“, Detail, Erledigt) und die sprachneutralen Accessibility-IDs bleiben unverändert. Der Klassenkommentar nennt „German or English“ statt „German“. Eine andere Sprache als `de`/`en` bricht über `LaunchLanguage.phrase` mit Meldung ab (kein stilles Deutsch).

**2. Workflow (`store-mac.yml`).** Neue Eingabe `language` (Typ `choice`, Optionen `de`, `en`, Standard `de`). Der Schritt „Photograph the Mac app“ bekommt `env: TEST_RUNNER_LOOSEENDS_UI_LANG: ${{ inputs.language || 'de' }}`, wie `ui-smoke-lang` es für die Matrix tut. Ein Lauf ohne Eingabe (Push auf `store/mac`, leere Dispatch-Eingabe) bleibt deutsch. Der Artefaktname wird `StoreMac-${{ inputs.language || 'de' }}`, damit die Sprache am Download erkennbar ist.

**3. Python-Test (`MacLanguageTests`).** Nach dem Muster von `WatchLanguageTests`: ein Export mit den vier Mac-Anhängen (`store-01-start`, `store-03-neu`, `store-04-detail`, `store-05-erledigt`), `sips` durch feste Maße ersetzt (1280×800). Details siehe Test Plan.

**4. README (`en/README.md`).** Zwei bis drei Zeilen ergänzen: `watch/` gehört zur Größe der Uhr (416×496), `mac/` zu „Mac (16:10)“ (1280×800), Mac-Bilder entstehen nur mit `store-mac.yml` (`language=en`). Der Satz „Made with …“ bleibt.

**5. Reihenfolge der Umsetzung.** Eine neue Dispatch-Eingabe ist erst nach dem Merge auf `main` wählbar, und ein Push trägt keine Eingaben. Deshalb:
1. PR 1 (Test, Workflow, Python-Test, README), CI grün, Merge.
2. `gh workflow run store-mac.yml -f language=en` auf `main`, zusätzlich `-f language=de` als Gegenprobe.
3. Artefakt `StoreMac-en` laden (`gh run download`), alle vier Bilder öffnen und beschreiben, dann `python3 scripts/store_screenshots.py --mac docs/store/screenshots/en <export>`.
4. PR 2 mit Bildern und Manifest. Zeigt ein Bild einen Umbruchfehler, wird der Test korrigiert und der Lauf wiederholt (neuer Durchgang), das Bild wird nie nachbearbeitet.

**6. Umbruch.** Englische Titel und Seitenleistenwörter können im 1280×800-Fenster anders umbrechen als die deutschen. Das entscheidet die Sichtprüfung der Bilder, nicht eine Vermutung.

### Alternativen

| Weg | trägt? | Haken |
|---|---|---|
| **A Umgebungsvariable `LOOSEENDS_UI_LANG`, Dispatch-Eingabe `language` (gewählt)** | ja | Neue Eingabe erst nach dem Merge wählbar (zwei PRs); sonst dasselbe Muster wie 4a/4b-1, ein Ablauf im Test |
| B Eigene englische Testklasse `MacStoreScreenshotsEnTests` | ja | kein Eingabeparameter nötig, ein Push könnte beide liefern; aber ca. 40 LoC doppelter Ablauf, beide Klassen laufen auseinander |
| C Matrix de+en in einem Lauf | ja | beide Sprachen auf einmal, aber doppelte Runner-Zeit bei jedem Lauf und deutsche Bilder ohne Anlass neu; sinnvoll nur, wenn 4c beide aus einem Lauf bräuchte, 4c lädt aber Dateien aus dem Repo |
| D Eigene Datei `store-mac-en.yml` | ja | ca. 50 Zeilen Workflow dupliziert, zwei Stellen für Runner-Setup (Bildschirmauflösung, Automation) |
| E Deutsche Bilder nachbearbeiten (Texte tauschen) | nein | zeigt nicht die echte App; widerspricht „Bilder entstehen nur aus echten UI-Tests“ (4a, Alternative C) |
| F Lokal auf diesem Mac fotografieren | nein | verboten: Mac-Bilder kommen nie von Hennings Mac (#742 S2b) |

Warum A: gleiches Muster wie die beiden Vorgänger, kleinster Eingriff, deutsche Bilder bleiben der Standard. Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Python (`unittest`, `scripts/test_store_screenshots.py`, `sips` ersetzt wie bei den übrigen Tests der Datei, Klasse `MacLanguageTests`):

- [ ] `test_mac_entry_is_added_to_en_manifest`: GIVEN ein Zielordner `en/` mit Manifest `en-US` (iPhone, iPad, Watch) und ein Mac-Export mit `store-01-start`, `store-03-neu`, `store-04-detail`, `store-05-erledigt` THEN legt `main_mac(en, export)` `en/mac/01-start.png`, `03-neu.png`, `04-detail.png`, `05-erledigt.png` an, das Manifest hat danach die Einträge `iphone`, `ipad`, `watch`, `mac` in dieser Reihenfolge, `sprache` bleibt `en-US`, die ersten drei Einträge sind byte-gleich zu vorher, der Mac-Eintrag nennt Pixel `1280x800`, Ordner `mac` und die vier Dateien. (RED: die Klasse gibt es nicht; rot ist der Test, wenn `main_mac` das Manifest oder die Sprache verändert.)
- [ ] `test_mac_rerun_replaces_only_the_mac_entry`: GIVEN ein Manifest mit altem Mac-Eintrag (anderes Format, eine Datei) THEN ersetzt ein erneuter `main_mac` nur `mac`; `iphone`, `ipad`, `watch` bleiben unverändert und `mac` steht genau einmal.
- [ ] `test_mac_run_leaves_readme_and_de_untouched`: GIVEN `en/README.md` mit Zusatzzeilen und ein `de/` mit Marker-Dateien (darunter `de/mac/01-start.png`) THEN bleiben README und alles unter `de/` nach `main_mac(en, …)` byte-gleich.
- [ ] `test_mac_wrong_size_aborts`: GIVEN ein Mac-Bild mit einer Größe außerhalb von `MAC["sizes"]` THEN `StoreError`, der vorhandene Mac-Ordner bleibt wie vorher und das Manifest ist unverändert (sichert, dass ein Umbruch- oder Skalierungsfehler nicht still durchgeht).

Swift: Die Änderung am Fototest hat keinen Unit-Test-Zugang (UI-Testziel, `#if os(macOS)`, läuft nur in der CI mit der Sandbox des Mac-Runners). Der Fototest ist selbst der Beleg: Er bricht ab, wenn die Startseite, „Neu“, das Detail oder „Erledigt“ fehlen, und liefert ohne Bilder kein Ergebnis. Das ist der ausdrücklich benannte Ausnahmefall der Scoping-Regeln; er wird durch die echten CI-Läufe (AC-4, AC-5, AC-6) belegt.

## Acceptance Criteria

- **AC-1:** Given ein englischer Zielordner mit Manifest (`en-US`; iPhone, iPad, Watch) und ein Mac-Export mit den vier Anhängen, When `main_mac` die Mac-Bilder einträgt, Then stehen `mac/01-start.png`, `03-neu.png`, `04-detail.png`, `05-erledigt.png` im Ordner, das Manifest nennt die Reihenfolge iPhone, iPad, Watch, Mac mit unverändertem `en-US` und unveränderten Einträgen der anderen Geräte, und der Mac-Eintrag nennt `1280x800`. Belegt durch `test_mac_entry_is_added_to_en_manifest` (rot vor, grün nach dem Lauf der Python-Tests).
- **AC-2:** Given ein Manifest mit altem Mac-Eintrag und eine README mit Zusatzzeilen sowie ein Ordner `de/`, When `main_mac` erneut läuft, Then wird nur der Mac-Eintrag ersetzt (genau einmal vorhanden), die anderen Geräte, README und alles unter `de/` bleiben byte-gleich; ein Bild mit nicht erlaubter Größe bricht mit `StoreError` ab und lässt Mac-Ordner und Manifest stehen. Belegt durch `test_mac_rerun_replaces_only_the_mac_entry`, `test_mac_run_leaves_readme_and_de_untouched`, `test_mac_wrong_size_aborts`.
- **AC-3:** Given die geänderte `store-mac.yml`, When sie gelesen und mit `workflow_dispatch` ohne Eingabe, mit `language=de` und mit `language=en` durchgespielt wird, Then steht die Eingabe `language` als Auswahl `de`/`en` mit Standard `de` im Workflow, der Testschritt setzt `TEST_RUNNER_LOOSEENDS_UI_LANG` auf `${{ inputs.language || 'de' }}` (ein Push auf `store/mac` und eine leere Eingabe ergeben `de`), und der Artefaktname trägt die Sprache. Belegt durch Lesen der Datei im Diff und durch das Protokoll der beiden echten Läufe (Umgebungsvariable und Artefaktname `StoreMac-en` bzw. `StoreMac-de`); die CI-Prüfung des PR 1 (YAML gültig, Wächter-Tests grün) zeigt, dass der Workflow lädt.
- **AC-4:** Given der Fototest ohne `LOOSEENDS_UI_LANG` oder mit `de` (Standard), When er in der CI läuft, Then startet die App deutsch (`-AppleLanguages (de)`, `-AppleLocale de_DE`) und der Test fotografiert die vier deutschen Aufgaben wortgleich zu den bisherigen Literalen („Steuerbescheid heute prüfen“, „Anna heute wegen Sonntag anrufen“, „Blumen heute gießen“, „Rasen mähen“); mit `en` startet sie englisch (`-AppleLanguages (en)`, `-AppleLocale en_US`) und der Test erfasst die vier freigegebenen englischen Aufgaben („Check the tax notice today“, „Call Anna today about Sunday“, „Water the flowers today“, „Mow the lawn“). Belegt durch die Startargumente im Protokoll beider CI-Läufe und den sichtbaren Text auf `01-start`.
- **AC-5:** Given PR 1 ist gemergt, When `gh workflow run store-mac.yml -f language=en` auf `main` läuft, Then besteht der Lauf, das Artefakt `StoreMac-en` enthält die vier Anhänge `store-01-start`, `store-03-neu`, `store-04-detail`, `store-05-erledigt`, und nach `python3 scripts/store_screenshots.py --mac docs/store/screenshots/en <export>` liegen vier PNG (1280×800, ohne Alphakanal) unter `docs/store/screenshots/en/mac/`; das englische `manifest.json` enthält zusätzlich den Mac-Eintrag bei unverändertem iPhone-/iPad-/Watch-Teil. Alle vier Bilder wurden geöffnet und beschrieben: `01-start` zeigt die englische Oberfläche mit den englischen Aufgaben unter „Now“, `03-neu` die Liste „New“ mit einer englischen Aufgabe, `04-detail` das Detail mit englischem Rohtext und der Schaltfläche zum Erledigen, `05-erledigt` die Liste „Completed“ mit der erledigten Aufgabe; Titel und Seitenleistenwörter brechen im Fenster nicht unleserlich um; **keine deutschen Wörter** auf allen vier Bildern; das Fenster passt auf den Bildschirm (`macAssertWindowFitsScreen` hat bestanden). Belegt durch die Run-ID des CI-Laufs, `sips`-Maße und die Bildbeschreibung im Abnahmebericht.
- **AC-6:** Given die deutschen Mac-Bilder sind veröffentlicht, When `gh workflow run store-mac.yml -f language=de` (und der Lauf ohne Eingabe) als Gegenprobe läuft, Then bestehen sie und die Bilder entsprechen den bisherigen in Aufbau, Text, Zeilenzahl und Maßen (1280×800); erlaubter Unterschied ist nur, was am Lauftag hängt („heute“, Datumsangaben). Vor und nach dem Lauf wurden ein deutsches und ein bisheriges Bild nebeneinander geöffnet und der Unterschied benannt; es gibt keinen Pixelvergleich. Die Dateien des Gegenlaufs werden nicht ins Repo übernommen: im Diff des Schnitts steht nichts unter `docs/store/screenshots/de/`. Belegt durch die Run-IDs, die Gegenüberstellung im Abnahmebericht und `git status` unter `de/`.
- **AC-7:** Given PR 1 und PR 2, When der Schnitt gemergt ist, Then sind alle Tests grün: `python3 -m unittest scripts/test_store_screenshots.py` samt den übrigen Skript-Tests, die CI des PR 1 (`ui-smoke` und der Rest; `Mac Gallery (macOS)` kompiliert das geänderte `MacStoreScreenshotsTests` im selben Testziel mit), und `./scripts/sim.sh build` übersetzt. Belegt durch die Laufbelege und die grüne CI beider PRs.
- **AC-8:** Given die Änderung berührt nur `LooseEndsUITests/`, `.github/`, `scripts/` und `docs/`, When der Schnitt abgenommen wird, Then endet die Abnahme nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“; der „Benutzen“-Beleg ist der echte CI-Fotolauf (AC-5 mit geöffneten Bildern, AC-6 als Gegenprobe). Auf Hennings Geräten läuft nichts, und Mac-Bilder entstehen nie auf seinem Mac. Belegt durch die Dateiliste des Diffs gegen die Geräteliste und den Abschlussbericht.

**Abnahmeweg.** Stufe 1: Python-Tests und Übersetzen (AC-1, AC-2, AC-7). Stufe 2: die echten CI-Läufe `store-mac.yml` für `en` und `de` (AC-3 bis AC-6); sie sind zugleich der Beleg, weil die Bilder das Ergebnis sind. Stufe 3 greift nicht.

## Definition of Done

- [ ] Die neuen Python-Tests (`MacLanguageTests`) waren vor der Umsetzung vorhanden, soweit sie Neues prüfen (RED), und sind danach grün; die vorhandenen Tests von `test_store_screenshots.py` bleiben grün.
- [ ] PR 1 (Test, Workflow, Python-Test, README) ist gemergt, die CI grün.
- [ ] Vier englische Mac-Bilder und der Mac-Eintrag im englischen Manifest liegen im Repo (PR 2); alle vier Bilder wurden geöffnet und im Abnahmebericht beschrieben.
- [ ] Die deutsche Gegenprobe ist gefahren und beschrieben; `docs/store/screenshots/de/` ist im Diff unberührt.
- [ ] `docs/store/screenshots/en/README.md` nennt Watch und Mac.
- [ ] #842 kommentiert: Schnitt 4b-2 erledigt, offen 4c (Hochladen).

## Seiteneffekte

- Geänderte Dateien in PR 1: die vier oben; PR 2: `docs/store/screenshots/en/mac/*.png`, `en/manifest.json`; dazu die Belege unter `docs/artifacts/feat-842-s4b2-en-mac/`.
- Keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.
- Neue Workflow-Eingabe `language` (Auswahl `de`/`en`); der Artefaktname ändert sich von `StoreMac` auf `StoreMac-<Sprache>`. Nichts anderes liest ihn (`store-mac.yml` wird nur von Hand oder durch Push auf `store/mac` gestartet).
- Das Verhalten für Deutsch bleibt: ohne Eingabe gleiche Aufgaben, gleiche Locale, gleiches Ziel `de`.

## Risiken

- **Nur in der CI prüfbar.** Jeder Versuch kostet einen Lauf auf dem Mac-Runner (`xcode-27`, ca. 15–30 min). Gegenmaßnahme: Wortlaut und Ablauf wiederverwenden, nichts Neues erfinden.
- **Umbruch.** Englische Titel und Seitenleistenwörter können im 1280×800-Fenster anders umbrechen; die Bilder werden geöffnet und beschrieben, ein Fehler führt zur Testkorrektur und zu einem neuen Lauf, nie zur Nachbearbeitung.
- **Falsche Standardsprache.** Ein Lauf ohne Eingabe darf die deutschen Bilder nicht englisch machen; AC-3, AC-4 und AC-6 belegen den Standard `de` auf allen Wegen (leere Eingabe, Push auf `store/mac`).
- **Zwei PRs nötig.** Die Eingabe `language` ist erst nach dem Merge wählbar; PR 2 erscheint also erst nach dem Lauf. Das ist Ablauf, kein Risiko für das Ergebnis.
- **„Heute“ hängt am Lauftag.** Deshalb kein Pixelvergleich der deutschen Gegenprobe, sondern Sichtvergleich.
- **README.** Die englische README nannte Watch und Mac bisher nicht; die Ergänzung ist hier mit eingeplant und verändert keine erzeugten Dateien.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Test- und Werkzeugerweiterung ohne Produktcode; es wird keine bestehende ADR gekippt (die Alternativen B bis D würden ebenfalls keine ADR berühren).

## Changelog

- 2026-11-08: Initial spec created (Schnitt 4b-2 von #842: englische Mac-Bilder aus dem Fototest per `LOOSEENDS_UI_LANG` und Dispatch-Eingabe `language` in `store-mac.yml`, Standard `de`, `MacLanguageTests`, Ablage `docs/store/screenshots/en/mac/`, zwei PRs, Abnahme endet nach Stufe 2; Hochladen ist 4c)
