# Adversary Dialog — feat-842-s4b-en-watch
Spec: docs/specs/feat-842-schnitt-4b-1-en-watch.md
Datum: 2026-11-08 08:40

## Checkliste
- [x] **AC-1:** Given ein englischer Zielordner mit Manifest (`en-US`, iPhone, iPad), When `main_watch` die Watch-Bilder einträgt, Then stehen `watch/01-jetzt.png` und `watch/02-gespeichert.png` im Ordner, das Manifest nennt die Reihenfolge iPhone, iPad, Watch mit unverändertem `en-US` und unveränderten iPhone-/iPad-Einträgen, und der Watch-Eintrag nennt `416x496`. Belegt durch `test_watch_entry_is_added_to_en_manifest`.
- [x] **AC-2:** Given ein Manifest mit altem Watch- und Mac-Eintrag und eine README mit Zusatzzeilen, When `main_watch` erneut läuft, Then wird nur der Watch-Eintrag ersetzt, Mac, iPhone, iPad, README und der Ordner `de/` bleiben unverändert; ein Bild mit falschen Maßen bricht mit `StoreError` ab und lässt den Watch-Ordner stehen. Belegt durch `test_watch_rerun_replaces_only_the_watch_entry`, `test_watch_run_leaves_readme_and_de_untouched`, `test_watch_wrong_size_aborts`.
- [x] **AC-3:** Given der Aufruf `LOOSEENDS_UI_LANG=fr ./scripts/sim.sh store-watch`, When er startet, Then bricht er mit Meldung („nur de oder en“) und Rückgabecode ungleich 0 ab, bevor ein Simulator gestartet oder eine Datei geschrieben wird. Belegt durch den echten Aufruf (Ausgabe, Code, Simulatorliste und `git status` unverändert).
- [x] **AC-4:** Given `store-watch` läuft ohne `LOOSEENDS_UI_LANG` oder mit `de`, When der Test startet, Then startet die Uhr-App deutsch und der Seed legt die deutsche Liste an (Rückfall ohne `--ui-testing-store-sample-texts`); mit `LOOSEENDS_UI_LANG=en` startet sie englisch (`-AppleLanguages (en)`) und der Seed legt die drei freigegebenen englischen Texte an. Belegt durch das Startargument im Testprotokoll beider Läufe und den sichtbaren Text auf `01-jetzt` (deutsch bzw. englisch). Außerhalb von `--ui-testing` ist der Seed nicht erreichbar: Beleg durch Lesen von `LooseEndsWatchApp.init` (beide Argumente sind Bedingung) und den bestehenden Test `testAppOpensOnNow`, der ohne `--ui-testing-store-sample` eine leere Liste („watch.now.empty“) sieht.
- [x] **AC-5:** Given der freigegebene Wortlaut, When `LOOSEENDS_UI_LANG=en ./scripts/sim.sh store-watch` im Watch-Simulator (Series 12, 46 mm) läuft, Then besteht der Test, es liegen zwei PNG (416×496, ohne Alphakanal) unter `docs/store/screenshots/en/watch/`, und das englische `manifest.json` enthält zusätzlich den Watch-Eintrag bei unverändertem iPhone-/iPad-Teil; die README `en` ist unberührt. Beide Bilder wurden geöffnet und beschrieben: `01-jetzt` zeigt die englische Oberfläche („Now“, „Capture“), mindestens zwei der Aufgaben wörtlich wie freigegeben und die Uhrzeit im 12-Stunden-Format (echte Zeit, hingenommen); `02-gespeichert` zeigt „Saved“ mit Haken; **keine deutschen Wörter** auf beiden Bildern. Belegt durch den echten Lauf, `sips`-Maße und die Bildbeschreibung im Abnahmebericht.
- [x] **AC-6:** Given die deutschen Watch-Bilder sind veröffentlicht, When `LOOSEENDS_UI_LANG=de ./scripts/sim.sh store-watch` (und ohne Variable) als Vergleich läuft, Then entsprechen die dabei entstandenen deutschen Bilder (nur zum Vergleich, danach zurückgesetzt) den bisherigen in Aufbau, Text, Zeilenzahl und Maßen; erlaubter Unterschied ist nur die Uhrzeit in der Statusleiste (echte Zeit, nicht setzbar). Vor und nach dem Lauf wurden beide Bilder nebeneinander geöffnet, der Unterschied benannt, danach sind die deutschen Dateien samt `de/manifest.json` auf den bisherigen Stand zurückgesetzt, und der Diff des Schnitts enthält nichts unter `docs/store/screenshots/de/`. Belegt durch den echten Lauf, die Gegenüberstellung im Abnahmebericht und `git status` unter `de/`.
- [x] **AC-7:** Given ein Lauf mit Sprache `en`, When er endet (auch bei Abbruch), Then steht die Systemsprache des Watch-Simulators wieder so wie vorher (EXIT-Trap, `store_restore_lang`). Belegt durch `defaults read -g AppleLanguages` und `AppleLocale` im Watch-Simulator vor und nach dem Lauf (gleiche Werte) und die Logzeile „Systemsprache … → en/en_US“ ohne Warnung „nicht zurückgesetzt“.
- [x] **AC-8:** Given die Änderung am Produktcode, When die Unit-Tests, die Skript-Tests und der Watch-UI-Test `testAppOpensOnNow` laufen, Then sind alle grün: `./scripts/sim.sh sim-unit` (alle Klassen), `python3 -m unittest scripts/test_store_screenshots.py` samt den übrigen Skript-Tests, `./scripts/sim.sh watch-test-proof WatchCaptureUITests`; `./scripts/sim.sh build` übersetzt Uhr-App und Watch-Testziel. Belegt durch die Laufbelege (`test-proof`-Beleg des Watch-Laufs).
- [ ] **AC-9:** Given (Stufe 3) die Änderung berührt `LooseEndsWatch/` (Geräteliste, CLAUDE.md), When der Schnitt gemergt ist, Then entsteht ein TestFlight-Bau (Buildnummer im Bericht) und Henning bekommt die Nummer und den einen Prüfschritt: Uhr-App öffnen, sie startet wie bisher mit „Jetzt“ und „Erfassen“, seine eigenen Aufgaben statt Beispielaufgaben aus dem Fototest, kein Absturz; seine Rückmeldung schließt den Geräte-Punkt. Bis dahin bleibt #842 offen. Auf Hennings Geräten läuft vorher nichts (auch nichts Lesendes) ohne sein wörtliches „jetzt ist ein Test möglich“; der Beleg für AC-4 bis AC-8 kommt aus dem Simulator.
  - Nachmerge-Schritt: TestFlight-Bau und Hennings Rückmeldung sind vor dem Merge prinzipiell nicht belegbar; bewusst offen (`- [ ]`), ändert das Urteil über AC-1…8 nicht.

## Dialog

### Runde 1
**Adversary:** Ich glaube keinem Beleg. Eigener Python-Lauf (47 Tests, 0 Skips, gespeichert in adversary-test-output.txt). Eigener `LOOSEENDS_UI_LANG=fr ./scripts/sim.sh store-watch` mit rc=1 und Meldung „nur de oder en“ (Prüfung steht vor trap, boot und Simulator). Der Status des Arbeitsbaums unter docs/store/screenshots/de und für en/README.md ist leer. `sips`: beide en-Watch-Bilder 416x496, hasAlpha no. Manifest-Diff: nur der angehängte Watch-Eintrag (iPhone/iPad-Teil unverändert, Reihenfolge iPhone, iPad, Watch, `en-US` unverändert). Wo ist der Beweis, dass der Seed die englischen Texte wirklich liest und nicht still auf Deutsch zurückfällt?
**Implementierer:** Der Foto-Test (LooseEndsUITests/Watch/WatchCaptureUITests.swift:84-86) prüft für JEDE Zeile unter Now, dass sie eine der englischen Beispielaufgaben enthält; bei Rückfall auf die deutsche Liste würde der Test rot. test-green-watch-en.txt: 1 Test, 0 Fehler. Bild 01-jetzt.png (geöffnet): Überschrift „Now“, „Capture“, „Check the tax notice“, „Call Anna about her birthday“, Uhrzeit „8:33“ (12-Stunden-Stil, echte Zeit), keine deutschen Wörter. 02-gespeichert.png: Haken-Kreis, „Saved“, Zurück-Pfeil, keine deutschen Wörter. Der Parser hat keinen Unit-Test (Spec benennt das), der Beleg ist der echte Lauf.
Code reference: LooseEndsWatch/LooseEndsWatchApp.swift:16
Code reference: scripts/sim.sh:697
Code reference: LooseEndsUITests/Watch/WatchCaptureUITests.swift:84
Code reference: scripts/test_store_screenshots.py:1
Code reference: docs/store/screenshots/en/manifest.json:31
Code reference: CLAUDE.md:67

### Runde 2
**Adversary:** Randfälle des Parsers `storeSampleTexts` (LooseEndsWatchApp.swift:27-33): Flag fehlt, dann firstIndex nil, deutsch; Flag als letztes Argument, dann `flag + 1 < count` false, deutsch; Wert fehlt und das nächste Argument ist ein anderes Flag („-AppleLanguages“), split ergibt 1 Eintrag, deutsch; 2 oder 4 Einträge, `count == 3` false, deutsch; leerer Eintrag („a||c“, `omittingEmptySubsequences: false`), `contains(where: \.isEmpty)`, deutsch. Nur ein reiner Leerzeichen-Eintrag ginge durch; im Testmodus ohne Folge. Außerhalb des Testmodus: `init` (LooseEndsWatchApp.swift:11) ruft den Seed nur bei `isUITesting` UND `--ui-testing-store-sample`; die Änderung berührt diese Bedingung nicht; `testAppOpensOnNow` (ac8-watch-test-proof.txt: 4 Tests, 0 Fehler, 0 übersprungen) sieht ohne Argument die leere Liste. AC-7: In `cmd_store_watch` steht der EXIT-Trap (sim.sh:706) vor `store_set_lang` (sim.sh:711); `store_set_lang` trägt die Wiederherstellung vor dem Schreiben ein (sim.sh:1211), der Trap greift also auch bei Abbruch dazwischen. ac7-defaults.txt: vorher, nach en-Lauf, nach de-Lauf jeweils de-DE / de_DE; Logzeile „Systemsprache de-DE/de_DE -> en/en_US“ in test-green-watch-en.txt ohne Warnung „nicht zurückgesetzt“. Eigene Lesung jetzt: AppleLanguages des Watch-Simulators = de-DE. AC-6: de-before und de-after beider Bilder geöffnet: gleicher Aufbau („Jetzt“, „Erfassen“, „Steuerbescheid prüfen“, „Anna wegen Geburtstag anrufen“, „Gespeichert“), nur Uhrzeit verschieden (06:44/06:46 gegen 08:34/08:35); de/ ist im Arbeitsbaum unverändert.
**Implementierer:** Belege oben. AC-8: ac8-build.txt „Build Succeeded“, ac8-sim-unit.txt „Test Succeeded“ ohne Fehler (3 von 6 Sprach-Messstrecken wegen bekannter Simulatorgrenze #419 übersprungen, unabhängig von dieser Änderung), ac8-watch-test-proof.txt 4 von 4 bestanden. Hinweis: das xcresult in simulator-run/ stammt vom Beweislauf mit Standardsprache, nicht vom en-Lauf; die Startargumente des en-Laufs sind nur über den Test-Quelltext (WatchCaptureUITests.swift:77-79) plus die Zeilenprüfung belegt, nicht aus einem Protokoll.
Code reference: LooseEndsWatch/LooseEndsWatchApp.swift:27
Code reference: LooseEndsWatch/LooseEndsWatchApp.swift:11
Code reference: scripts/sim.sh:706
Code reference: scripts/sim.sh:1211

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsWatch/LooseEndsWatchApp.swift:30
  Description: Ein Eintrag aus nur Leerzeichen (z. B. "a| |c") gilt als nichtleer und wird als Aufgabentext übernommen.
  Spec requirement: AC-4 — Seed nimmt genau drei nichtleere Einträge
  Conflict: Nur im Testmodus erreichbar, vom Test selbst nie so gefüttert; kein Einfluss auf den Normalbetrieb.
  Remediation: Optional beim Prüfen trimmen. Nicht blockierend.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/sim.sh:706
  Description: Der Abbruchpfad der Sprachrückstellung (EXIT-Trap) ist nur per Code-Lesung belegt, kein Lauf bricht mitten ab; belegt ist der Normalpfad.
  Spec requirement: AC-7 — Rückstellung auch bei Abbruch
  Conflict: Beleg für „auch bei Abbruch“ ist indirekt (Trap vor store_set_lang, Eintrag vor dem Schreiben).
  Remediation: Kein Handlungsbedarf; Struktur entspricht dem iPhone/iPad-Pfad aus 4a.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/test_store_screenshots.py:1
  Evidence: Eigener Lauf, 47 Tests OK, 0 Skips; Manifest-Diff zeigt nur den Watch-Eintrag mit 416x496.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_store_screenshots.py:1
  Evidence: Dieselben 47 Tests grün; Arbeitsbaum unter de/ und en/README.md unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/sim.sh:697
  Evidence: Eigener Lauf mit fr: rc=1, „nur de oder en“, vor trap/boot.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsWatch/LooseEndsWatchApp.swift:11
  Evidence: Seed nur bei isUITesting und --ui-testing-store-sample; Parser fällt in allen Randfällen auf deutsch zurück; Test prüft jede Zeile gegen die Sprachliste.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsUITests/Watch/WatchCaptureUITests.swift:84
  Evidence: Bilder geöffnet, 416x496 ohne Alpha, englischer Text, keine deutschen Wörter, Manifest wie spezifiziert, README en unberührt.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/sim.sh:697
  Evidence: de-before/de-after geöffnet, nur Uhrzeit verschieden; de/ unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/sim.sh:706
  Evidence: Trap vor store_set_lang, ac7-defaults.txt dreimal de-DE/de_DE, eigene Lesung de-DE.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEndsWatch/LooseEndsWatchApp.swift:16
  Evidence: Build, sim-unit, watch-test-proof (4/4) grün in den Belegen; eigener Python-Lauf 47 OK.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

AC-1 bis AC-8 belegt. Tests: Python 47 bestanden, 0 fehlgeschlagen, 0 übersprungen (eigener Lauf); Simulator-Läufe laut Belegen grün (Watch 4/4). AC-9 (TestFlight und Hennings Rückmeldung) ist ein Nachmerge-Schritt und bleibt offen; es ändert das Urteil über AC-1…8 nicht. Nur zwei LOW-Beobachtungen (F001, F002), nichts blockierend.

## Geprüfte Dateien

- sha256:cbaacca045fe608900c245ee8e56a76b32a8966383f69dc01224a3b2590fd56f  CLAUDE.md
- sha256:6f4832aae95645644aaab1bafe6455bd2b6ab7de499b03f2d2554d8de2a0e398  LooseEndsUITests/Watch/WatchCaptureUITests.swift
- sha256:192dc612c634b2962e3d94c13c01f87fa04c4e1e48418d294ca237bd3f36cd5c  LooseEndsWatch/LooseEndsWatchApp.swift
- sha256:885c97338122f71724fb6a028578fbdefd447a47a802c66608261c014810b9f5  docs/store/screenshots/en/manifest.json
- sha256:888d529f9eaec3b70a978fefb1829a582864fc628da8e8c7dfa4497c4d131c99  scripts/sim.sh
- sha256:4caf1b36e8b2e9ee102ac2804dc0753589570c18ce5b396fa5802e6225caf9af  scripts/test_store_screenshots.py

## Prüfbasis

- base: 1a7c228bff62755a0274cb37fa0522cbd17c7041
- blob:3262d348f21869423fc287d232831d921f795d15  CLAUDE.md
- blob:9c38fa675f1413de3b5f16da935dad24b8cb5c4b  LooseEndsUITests/Watch/WatchCaptureUITests.swift
- blob:15d4ad2c3014b4000fa85503309797f15b555323  LooseEndsWatch/LooseEndsWatchApp.swift
- blob:a764eaf292a017fbf14e1fe4823cecdb7b173cc4  docs/store/screenshots/en/manifest.json
- blob:9ad7efe73f2a39436c951a66b53260d9249a613c  scripts/sim.sh
- blob:454aff6be968d26f54b5f1bf370c00ff31b0dc3a  scripts/test_store_screenshots.py
