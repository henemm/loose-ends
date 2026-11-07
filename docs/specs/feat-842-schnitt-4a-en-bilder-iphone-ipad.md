---
entity_id: feat-842-schnitt-4a-en-bilder-iphone-ipad
type: feature
created: 2026-11-07
updated: 2026-11-07
status: draft
workflow: feat-842-s4-en-bilder
---

# Spec: #842 Schnitt 4a — Englische App-Store-Bilder für iPhone und iPad erzeugen

## Approval

- [ ] Approved

Mit dem getippten `approved` gibt Henning zugleich frei (oder ändert vorher) den Abschnitt **Wortlaut zur Freigabe** (die englischen Beispielaufgaben, die als sichtbarer Inhalt auf den Store-Bildern stehen).

## Purpose

Die englische Seite des App Store hat seit Schnitt 3 Texte, aber keine Bilder. Schnitt 4a erzeugt die englischen Bilder für iPhone und iPad aus denselben UI-Tests wie die deutschen: dieselben fünf Bilder (Start, Erfassen, Neu, Detail, Erledigt), nur mit englischer App und englischen Beispielaufgaben. Die Sprache wird ein Parameter des Store-Laufs (`de` oder `en`); die Bilder landen unter `docs/store/screenshots/en/` mit eigenem Manifest (`en-US`). Die deutschen Bilder bleiben unverändert, auch wenn der Lauf für Deutsch neu gefahren wird.

Für Henning ändert sich: Er liest die englischen Beispielaufgaben unten und gibt sie frei oder ändert sie; die fertigen englischen Bilder liegen danach im Repo, bereit zum Hochladen (Schnitt 4c). Er muss nichts tippen oder hochladen.

Nicht in diesem Schnitt:

- **Hochladen und Platzieren bei Apple** (Bibliothek, Platzierungen, Reihenfolge) ist Schnitt 4c; hier wird bei Apple nichts gelesen oder geschrieben.
- **Apple Watch und Mac** (Watch-Beispielaufgaben im Produktcode `LooseEndsWatch/`, `MacStoreScreenshotsTests`, `store-mac.yml`) ist Schnitt 4b. `cmd_store_watch` und der Mac-Pfad bleiben unberührt und schreiben weiter nach `de/`.

Ohne Modell geht es nicht: nicht relevant, Test- und Werkzeugarbeit; die Beispielaufgaben bekommen ihre Etiketten und Fälligkeiten allein aus den Regeln (`EnglishPack`).

## Source

- **File:** `LooseEndsUITests/StoreScreenshotsTests.swift`, `LooseEndsUITests/LaunchLanguage.swift`, `scripts/sim.sh`, `scripts/store_screenshots.py`, `scripts/test_store_screenshots.py`
- **Identifier:** `StoreScreenshotsTests`, `LaunchLanguage`, `cmd_store_screenshots`, `build_manifest(names, commit, created, lang)`, `keep_other_devices(manifest, previous)`, `write_readme(out_root, lang)`, `main(argv)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LaunchLanguage` (`LooseEndsUITests/LaunchLanguage.swift`) | Test-Hilfe | Startargumente `-AppleLanguages`/`-AppleLocale` und Phrasen je Sprache (#761); Standard dort `en`, wird hier bewusst nicht gekippt |
| `scripts/sim.sh` `run_xcodebuild` (Zeile 318) | Skript | reicht `LOOSEENDS_UI_LANG` als `TEST_RUNNER_LOOSEENDS_UI_LANG` an die UI-Tests durch, aber nur wenn die Variable gesetzt ist |
| `scripts/sim_proof.py` `suffix_screenshots` | Skript | hängt `-<lang>` an Bilder des Belegordners, wenn `LOOSEENDS_UI_LANG` gesetzt ist; betrifft nur den Belegordner, nicht den Store-Export |
| `Shared/Language/EnglishPack.swift`, `GermanPack.swift` | Regeln | Etiketten, Fälligkeit, Wichtigkeit der Beispielsätze |
| `LooseEnds/Resources/Localizable.xcstrings` | Katalog | englische Beschriftungen, die der Test abfragt (Dauerauswahl: Schlüssel `30 min`, Deutsch „30 Min.“, Englisch bleibt `30 min`) |
| `.github/workflows/ci.yml` (Job `ui-smoke`, `-only-testing:LooseEndsUITests`) | CI | fährt auch `StoreScreenshotsTests` und zwar ohne `LOOSEENDS_UI_LANG`; darf dadurch nicht plötzlich englisch laufen |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsUITests/StoreScreenshotsTests.swift | MODIFY | Sprache aus der Umgebung (Standard `de`), Aufgabentexte und sprachabhängige Abfragen je Sprache |
| LooseEndsUITests/LaunchLanguage.swift | MODIFY | Startargumente und Phrasen für eine übergebene Sprache; Store-Phrasen de/en; Standard von `code` bleibt `en` |
| scripts/sim.sh | MODIFY | `store-screenshots`: Sprache `de` (Standard) oder `en`, Ziel `docs/store/screenshots/<lang>`, Belege je Sprache |
| scripts/store_screenshots.py | MODIFY | Sprache als Argument; Manifest `sprache` de-DE/en-US; README je Sprache, nur anlegen wenn nicht vorhanden; Watch-/Mac-Einträge eines vorhandenen Manifests behalten |
| scripts/test_store_screenshots.py | MODIFY | Tests für Sprache, README, Behalten fremder Geräteeinträge |
| docs/store/screenshots/en/** | CREATE (erzeugt) | zehn Bilder, `manifest.json`, `README.md` — Ergebnis des Laufs, kein Code |
| CLAUDE.md | MODIFY | im Abschnitt Build zwei Zeilen: `LOOSEENDS_UI_LANG=en ./scripts/sim.sh store-screenshots`, Ziel je Sprache |

### Estimated Changes
- Code-Dateien: **5** (Grenze 4–5 eingehalten), dazu eine Dokumentationszeile in `CLAUDE.md` (Definition of Done verlangt sie bei geänderten Befehlen) und die erzeugten Bilder samt Manifest (zählen nicht als Code).
- LoC ehrlich geschätzt: `StoreScreenshotsTests` ca. 30, `LaunchLanguage` ca. 20, `sim.sh` ca. 20, `store_screenshots.py` ca. 30, `test_store_screenshots.py` ca. 50, `CLAUDE.md` 3 — zusammen **ca. 150 LoC**, unter der 250er-Grenze.
- Kein Produktcode (nichts unter `LooseEnds/`, `Shared/`, `LooseEndsWatch/`): reiner Test- und Werkzeugschnitt.

## Implementation Details

**1. Sprache im UI-Test (`StoreScreenshotsTests`).** Die Sprache kommt aus `LOOSEENDS_UI_LANG`, **Standard `de`** — anders als `LaunchLanguage.code` (Standard `en`). Grund: Der CI-Job `ui-smoke` führt `-only-testing:LooseEndsUITests` ohne die Variable aus und damit auch diese Klasse; sie lief bisher deutsch und soll es dort weiter tun. `LaunchLanguage` bekommt dafür die Form `arguments(for:)`, `locale(for:)` und `phrase(_:in:)` mit der Sprache als Parameter; `code`, `locale`, `arguments` und `phrase(_:)` bleiben für die Matrixklassen (#761) unverändert und rufen die neuen mit `code` auf. `launch()` ersetzt das feste `"-AppleLanguages", "(de)", "-AppleLocale", "de_DE"` durch `LaunchLanguage.arguments(for: Self.language)`.

**2. Sprachabhängiges im Test.** Aus dem Test werden diese Stellen über Phrasen gelöst (Schlüssel mit Präfix `store…` in `LaunchLanguage.phrases`):

| Stelle (Zeile heute) | de | en |
|---|---|---|
| Aufgaben (L10–15) | Steuerbescheid heute prüfen / Anna heute wegen Sonntag anrufen / Blumen heute gießen / Rasen mähen | siehe Wortlaut zur Freigabe |
| getippte Aufgabe (L15) | Fahrrad zur Inspektion bringen | siehe Wortlaut zur Freigabe |
| Dauerknopf (L97) | `30 Min.` | `30 min` (Katalog: Schlüssel `30 min` hat keine englische Übersetzung, der Schlüssel ist die Anzeige) |
| `complete(…)` (L203) | `Blumen` | `flowers` |
| Zeile in „Fällig“ (L232) | `Steuerbescheid` | `tax notice` |

Schon zweisprachig und unverändert: Zurück-Knopf (`Zurück`/`Back`), Tastatur ausblenden (`ausblenden`/`dismiss`), Seitenleiste (`Seitenleiste ausblenden`/`Hide Sidebar`), die Kennungen `viewRow_*`, `nowRow_*`, `taskRow_*` und `Computer` (heißt in beiden Sprachen gleich). Fehlt für eine Sprache eine Phrase, bricht `phrase` wie bisher mit dem Schlüssel ab. Die Meldungstexte der Asserts bleiben deutsch (nur für das Log).

**3. Aufruf (`sim.sh store-screenshots`).** Die Sprache steht in `LOOSEENDS_UI_LANG`; `cmd_store_screenshots` setzt `lang="${LOOSEENDS_UI_LANG:-de}"` und prüft sie: nur `de` oder `en`, sonst Fehler vor dem ersten Simulatorstart (die Sprache wird Pfadbestandteil). Danach `export LOOSEENDS_UI_LANG="$lang"`, damit `run_xcodebuild` sie durchreicht; **ohne diese ausdrückliche Zuweisung liefe ein Lauf ohne Variable mit der Standardsprache der Matrixklassen**, das ist der Fehlerfall, den der deutsche Vergleichslauf (AC-7) ausschließt. Ziel: `docs/store/screenshots/$lang`. Belege: `docs/artifacts/$wf/store-proof-$lang-<gerät>.txt` (je Sprache und Gerät eigene Datei, nichts wird überschrieben). Die Abschlussmeldung nennt Sprache und Ziel. Der Aufruf von `store_screenshots.py` bekommt `--lang $lang`.

**4. `store_screenshots.py`.** Neue Option `--lang <de|en>` (Standard `de`) vor dem Ziel; `LANGUAGES = {"de": {"manifest": "de-DE", …}, "en": {"manifest": "en-US", …}}`, unbekannte Sprache → `StoreError`.

- `build_manifest(names, commit, created, lang="de")` schreibt `"sprache"` aus der Tabelle (`de-DE`, `en-US`).
- `write_readme(out_root, lang)` legt die README der Sprache an (englische Fassung: „App Store pictures (English)“, `en-US`, gleiche Größenangaben und Hinweis auf `sim.sh store-screenshots`), **überschreibt aber eine vorhandene nicht**. Bisher ersetzte jeder Lauf die von Hand um Watch und Mac erweiterte deutsche README durch die Kurzfassung.
- `keep_other_devices(manifest, previous)` übernimmt aus einem vorhandenen `manifest.json` die Einträge `watch` und `mac` in das neue Manifest. Bisher ging der Eintrag beim Neulauf verloren (Manifest nur iPhone und iPad). Für `en` gibt es noch keine, also ändert sich dort nichts; für `de` bleibt das Manifest bis auf `erzeugt` und `commit` gleich.
- `--watch` und `--mac` bleiben wie sie sind (Ziel kommt vom Aufrufer, `cmd_store_watch` nutzt weiter `de`).

**5. Etiketten der englischen Beispielsätze (`EnglishPack` gegen `GermanPack`).** Geprüft in den Regeltabellen, nicht geraten:

| Deutsch | Englisch | Etikett de | Etikett en | Fälligkeit | Wichtigkeit |
|---|---|---|---|---|---|
| Steuerbescheid heute prüfen | Check the tax notice today | keins (`steuer` = „official“-Wichtigkeit, kein Kontext) | keins (`tax` = „official“, kein Kontext) | heute / `today` | amtlich, beide gleich |
| Anna heute wegen Sonntag anrufen | Call Anna about Sunday today | Phone (`anrufen`) | Phone (`call`) | heute und Wochentag in beiden Sprachen im Satz | — |
| Blumen heute gießen | Water the flowers today | keins | keins (`water`/`flowers` stehen in keiner Liste) | heute | — |
| Rasen mähen | Mow the lawn | Garden (`rasen`) | Garden (`mow`, `lawn`) | keine | — |
| Fahrrad zur Inspektion bringen | Take the bike in for a service | keins | keins | keine | — |

**Abweichungen, die offen stehen:** (a) Keine Abweichung bei Etiketten: Phone und Garden in beiden Sprachen, die übrigen ohne. (b) „Check the tax notice today“ und „Take the bike in for a service“ enthalten die Wörter `in`/`after`, die der englische Zeitparser als Einleitung einer Zeitangabe kennt (`pointInTime`); er verlangt dort eine Zahl mit Einheit, hier folgt keine, ein Treffer ist deshalb nicht zu erwarten — das entscheiden aber erst die echten Bilder (Datum in „Neu“ und im Detail), nicht diese Tabelle. (c) Das Wort „Sunday“ in Satz 2 setzt wie „Sonntag“ im Deutschen eine Wochentagsfälligkeit neben „today“; beide Sprachen verhalten sich gleich, die Bilder zeigen, welche gewinnt, und müssen der deutschen Fassung im Aufbau entsprechen. Weicht ein englisches Bild im Aufbau vom deutschen ab (andere Zeilenzahl, anderes Etikett, anderer Fälligkeitsblock), wird der Satz nach Rücksprache mit Henning geändert, nicht das Bild nachbearbeitet.

**6. Ablage.** `docs/store/screenshots/en/{iphone,ipad}/{01-start,02-erfassen,03-neu,04-detail,05-erledigt}.png`, `manifest.json` (`sprache: en-US`, Commit, Zeit), `README.md`. Pixelmaße wie deutsch (1206×2622 und 2064×2752, ohne Alphakanal, iPad-Griff entfernt) — die Prüfung in `finish_device` ist sprachunabhängig.

**Alternativen:**
- **A (gewählt):** dieselben UI-Tests, Sprache als Parameter. Eine Quelle der Wahrheit für Abläufe und Abfragen; ändert sich ein Bild, ändern sich beide Sprachen mit. Kippt keine ADR.
- **B:** eigener englischer Test (Kopie von `StoreScreenshotsTests`). Würde 250 Zeilen duplizieren; nach dem ersten Eingriff in den iPad-Tastaturpfad laufen die beiden auseinander. Verworfen.
- **C:** englische Bilder aus den deutschen durch Austausch der Texte (Bildbearbeitung/Übersetzung der Bildtexte). Keine echte App auf dem Bild, wäre ein Store-Bild, das die App nicht zeigt (und widerspricht „Bilder entstehen nur aus echten UI-Tests“). Verworfen.
- **D:** Henning macht die englischen Bilder per Hand am Gerät. Nicht wiederholbar, Hennings Geräte nur auf sein Wort; verworfen.
- **E:** `LaunchLanguage.code` auf Standard `de` für alle Klassen stellen statt der Klasse allein. Kippt #761 (Matrix und lokale Läufe laufen englisch); verworfen.

## Wortlaut zur Freigabe

Das sind die englischen Beispielaufgaben, die auf den englischen Store-Bildern zu lesen sind (Start, Neu, Detail, Eingabefeld beim Erfassen). Sie sind erfunden und gelten nur im Testmodus, kein Eintrag in der echten App. Sie sind sinngemäß die deutschen Aufgaben, sprachlich so, wie jemand sie in die englische App spräche. Henning gibt sie mit `approved` frei oder nennt Änderungen.

| Deutsch (heute auf den Bildern) | Englisch (Vorschlag) |
|---|---|
| Steuerbescheid heute prüfen | Check the tax notice today |
| Anna heute wegen Sonntag anrufen | Call Anna about Sunday today |
| Blumen heute gießen | Water the flowers today |
| Rasen mähen | Mow the lawn |
| Fahrrad zur Inspektion bringen (getippt, nur Bild 02) | Take the bike in for a service |

Die Watch-Aufgabe („Anna wegen Geburtstag anrufen“ → „Call Anna about her birthday“) gehört zu Schnitt 4b und wird dort freigegeben.

## Test Plan

### Automated Tests (TDD RED)

Python (`unittest`, `scripts/test_store_screenshots.py`, `sips` und Export ersetzt wie bisher):

- [ ] `test_manifest_language_follows_lang`: GIVEN `build_manifest(…, lang="en")` THEN `sprache == "en-US"`; ohne `lang` oder mit `"de"` `de-DE`; sonst unverändert (zwei Geräte, Pixelmaße, Dateien).
- [ ] `test_unknown_language_is_refused`: GIVEN `lang="fr"` in `build_manifest` und in `main(["--lang", "fr", …])` THEN `StoreError` vor jeder Dateiarbeit.
- [ ] `test_readme_is_per_language_and_never_overwritten`: GIVEN leerer Zielordner THEN `write_readme(…, "en")` legt eine englische README mit `en-US` an, `"de"` eine deutsche mit `de-DE`; GIVEN eine vorhandene README mit Zusatzzeilen THEN bleibt sie byte-gleich.
- [ ] `test_other_devices_survive_a_new_run`: GIVEN vorhandenes Manifest mit `watch` und `mac` THEN `keep_other_devices` übernimmt beide unverändert hinter iPhone und iPad; GIVEN Manifest ohne sie THEN nichts hinzugefügt; GIVEN ein veralteter `iphone`-Eintrag im alten Manifest THEN er wird nicht übernommen.
- [ ] `test_en_run_leaves_de_folder_untouched`: GIVEN Zielordner `en/` neben einem `de/` mit Marker-Dateien THEN `finish_device` in `en/` ändert nichts unter `de/`.

Swift (kein eigener Unit-Test möglich, weil UI-Test): Die Sprachauflösung liegt in `LaunchLanguage` und wird durch die echten Läufe belegt (AC-5 bis AC-9). Beim Übersetzen des UI-Test-Targets (`./scripts/sim.sh build` läuft es mit) muss `LaunchLanguage.swift` fehlerfrei in beiden Test-Targets kompilieren, die es einbinden.

## Acceptance Criteria

- **AC-1:** Given ein Manifest wird für `en` gebaut, When `build_manifest` läuft, Then steht `sprache: en-US` darin, für `de` (und ohne Angabe) `de-DE`, und eine andere Sprache wird mit `StoreError` abgelehnt, bevor Dateien angefasst werden. Belegt durch `test_manifest_language_follows_lang`, `test_unknown_language_is_refused`.
- **AC-2:** Given eine README der Sprache existiert, When ein Store-Lauf sie neu schreiben will, Then bleibt sie unverändert; fehlt sie, Then wird eine der Sprache angelegt (englisch mit `en-US`, deutsch mit `de-DE`). Belegt durch `test_readme_is_per_language_and_never_overwritten`.
- **AC-3:** Given ein vorhandenes Manifest mit Watch- und Mac-Einträgen, When die iPhone-/iPad-Bilder neu erzeugt werden, Then bleiben die Watch- und Mac-Einträge im neuen Manifest, nicht aber alte iPhone-/iPad-Einträge. Belegt durch `test_other_devices_survive_a_new_run`.
- **AC-4:** Given ein Lauf für `en` schreibt nach `docs/store/screenshots/en/`, When er endet, Then ist unter `docs/store/screenshots/de/` nichts verändert, und die Belege liegen je Sprache getrennt (`store-proof-en-iphone.txt`, `store-proof-en-ipad.txt`). Belegt durch `test_en_run_leaves_de_folder_untouched` (Ordnerlogik) und den echten Lauf aus AC-6 (Belegnamen, `git status` unter `de/` leer).
- **AC-5:** Given `StoreScreenshotsTests` läuft ohne `LOOSEENDS_UI_LANG` (so wie im CI-Job `ui-smoke`), When der Test startet, Then startet die App deutsch mit den deutschen Aufgaben, die Klasse also unverändert zum Stand davor; mit `LOOSEENDS_UI_LANG=en` startet sie englisch mit den englischen Aufgaben. Belegt durch das Startargument im Testprotokoll beider Läufe (`-AppleLanguages (de)` bzw. `(en)`) aus dem echten Lauf `test-proof` (AC-6, AC-7) und das unveränderte `LaunchLanguage.code` (Standard `en`) für die Matrixklassen: `ui-smoke-lang` bleibt grün.
- **AC-6:** Given der freigegebene Wortlaut, When `LOOSEENDS_UI_LANG=en ./scripts/sim.sh store-screenshots` auf iPhone 17 und iPad Pro 13″ läuft, Then bestehen beide UI-Test-Läufe, es liegen zehn PNG (je fünf) unter `docs/store/screenshots/en/` mit den Maßen 1206×2622 und 2064×2752 ohne Alphakanal, `manifest.json` nennt `en-US`, Commit und beide Geräte, und die Beleg-Dateien `store-proof-en-iphone.txt`/`store-proof-en-ipad.txt` stehen da. Alle zehn Bilder wurden geöffnet und beschrieben: App und Statusleiste englisch (9:41), Aufgaben wörtlich wie freigegeben, **keine deutschen Wörter** auf dem Bild (Ausnahme: nur, was der Katalog selbst in beiden Sprachen gleich führt), keine Tastatur im Bild, bei iPad kein Fenstergriff; Etiketten Phone/Garden, Dauer „30 min“ und Tag „Computer“ im Detail wie in den deutschen Bildern. Belegt durch den echten Lauf und die Bildbeschreibung im Abnahmebericht.
- **AC-7:** Given die deutschen Bilder sind schon veröffentlicht, When `LOOSEENDS_UI_LANG=de ./scripts/sim.sh store-screenshots` (und ohne Variable) neu läuft, Then entsprechen die zehn neuen deutschen Bilder den bisherigen in Aufbau, Text, Zeilenzahl, Etiketten und Maßen; erlaubte Unterschiede sind nur, was von Tag und Rendern abhängt (das Datum am Kopf der Startseite, Zeichenglättung). Vor und nach dem Lauf wurden `01-start`, `03-neu` und `04-detail` beider Geräte nebeneinander geöffnet und die Unterschiede benannt; das Manifest hat dieselben Geräteeinträge (auch `watch`, `mac`) und dieselben Dateinamen, nur `erzeugt` und `commit` unterscheiden sich. Danach sind die deutschen Dateien auf den bisherigen Stand zurückgesetzt, und der Diff dieses Schnitts enthält nichts unter `docs/store/screenshots/de/`. Belegt durch den echten Lauf, die Gegenüberstellung im Abnahmebericht und `git status` unter `de/`.
- **AC-8:** Given der Aufruf `./scripts/sim.sh store-screenshots` mit einer anderen Sprache (`LOOSEENDS_UI_LANG=fr`), When er startet, Then bricht er mit Meldung ab, bevor ein Simulator gestartet oder eine Datei geschrieben wird. Belegt durch den echten Aufruf (Ausgabe und Rückgabecode ungleich 0, `git status` unverändert).
- **AC-9:** Given die Etiketten der englischen Beispielsätze, When die englischen Bilder 03-neu und 04-detail ansehen, Then zeigt „Call Anna about Sunday today“ das Etikett Phone, „Mow the lawn“ Garden, die anderen drei keins, und der Satz „Check the tax notice today“ steht als heutige Aufgabe unter „Jetzt“ (englisch „Now“) wie sein deutsches Gegenstück; Abweichungen vom Aufbau der deutschen Bilder sind im Bericht benannt (Wortlaut zur Freigabe Punkt 5). Belegt durch die geöffneten Bilder `en/iphone/03-neu.png`, `en/iphone/04-detail.png`, `en/ipad/04-detail.png`.

**Abnahmeweg.** Keiner der Pfade der Geräteliste (CLAUDE.md, Stufe 3) wird berührt: Geändert werden nur `LooseEndsUITests/`, `scripts/`, `CLAUDE.md` und Bilder unter `docs/`. Die Abnahme endet nach Stufe 2, und der Abschlussbericht enthält den Satz „Kein Pfad der Geräteliste berührt.“ Stufe 1: Python-Tests (`python3 -m unittest scripts/test_store_screenshots.py` samt den übrigen Skript-Tests) und Übersetzen; Stufe 2: die echten Läufe `store-screenshots` für `en` und `de` im Simulator (AC-6 bis AC-9); sie sind zugleich der Beleg, weil die Bilder selbst das Ergebnis sind. Auf Hennings Geräten läuft nichts.

## Definition of Done

- [ ] Die neuen Python-Tests waren vor der Umsetzung rot und sind danach grün; die vorhandenen `test_store_screenshots.py`-Tests und `scripts/test_sim_run_xcodebuild.py` bleiben grün.
- [ ] Henning hat die englischen Beispielaufgaben freigegeben oder geändert; die Bilder zeigen genau den freigegebenen Wortlaut.
- [ ] Zehn englische Bilder und Manifest liegen unter `docs/store/screenshots/en/`, jedes Bild wurde geöffnet und im Abnahmebericht beschrieben.
- [ ] Der deutsche Vergleichslauf ist gefahren und beschrieben; `docs/store/screenshots/de/` ist im Diff unberührt.
- [ ] `ui-smoke` und `ui-smoke-lang` in der CI bleiben grün (StoreScreenshotsTests läuft dort ohne Variable weiter deutsch).
- [ ] `CLAUDE.md` (Abschnitt Build) nennt die Sprache beim Befehl `store-screenshots`.
- [ ] #842 kommentiert: Schnitt 4a erledigt, offen 4b (Watch, Mac) und 4c (Hochladen).

## Seiteneffekte

- Geänderte Dateien: die fünf oben (plus `CLAUDE.md`); neue Dateien nur unter `docs/store/screenshots/en/` und die Belege unter `docs/artifacts/feat-842-s4-en-bilder/`.
- Keine neuen Berechtigungen, keine `Info.plist`, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.
- Belegnamen ändern sich: `store-proof-<gerät>.txt` heißt nun `store-proof-<lang>-<gerät>.txt` (die alten Belege liegen im Ordner des Workflows `feat-742-store-screenshots` und bleiben stehen).
- Der Neulauf für `de` schreibt keine README mehr über die von Hand erweiterte und behält die Watch-/Mac-Einträge im Manifest — beides war ein Mangel des alten Verhaltens, kein neues Verhalten für `en`.
- Die Simulatoren bekommen für die Dauer des Laufs die Statusleiste 9:41 und werden danach zurückgesetzt (wie bisher, `trap`).

## Risiken

- **Test läuft unter dem falschen Standard.** `LaunchLanguage.code` hat Standard `en`; fiele `StoreScreenshotsTests` darauf zurück, liefen CI und ein Store-Lauf ohne Variable englisch. Gegenmaßnahme: Standard `de` in der Klasse und ausdrückliche Zuweisung in `sim.sh` (AC-5, AC-7).
- **Englisches Layout läuft anders.** Längere englische Wörter können Zeilen umbrechen oder Etiketten verschieben; die Bilder werden geöffnet und gegen die deutschen gehalten (AC-6, AC-9). Weicht ein Bild ab, wird der Satz geändert, nicht das Bild nachbearbeitet.
- **Zeitparser liest „in“/„Sunday“.** Siehe Punkt 5; die echten Bilder entscheiden.
- **Datum im Bild.** Die deutschen Bilder tragen das Datum vom 2026-10-30; ein Neulauf zeigt ein anderes. Deshalb ist der deutsche Lauf ein Vergleich und wird zurückgesetzt, nicht übernommen.
- **Umfang.** Nahe an der 5-Dateien-Grenze (5 Code-Dateien, plus Dokumentationszeile). Wächst der Code über 250 LoC, wird das vor dem Weiterbauen gemeldet.
- **Lauf braucht Simulatoren und Zeit.** Zwei Läufe je Sprache (iPhone und iPad), je mit Bau; die rechnerweite Testsperre gilt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Test- und Werkzeugerweiterung ohne Eingriff in eine Architekturentscheidung.

## Changelog

- 2026-11-07: Initial spec created (Schnitt 4a von #842: englische Store-Bilder für iPhone und iPad aus denselben UI-Tests, Sprache als Parameter, Ablage `docs/store/screenshots/en/`, Wortlaut zur Freigabe; Watch und Mac Schnitt 4b, Hochladen Schnitt 4c)
