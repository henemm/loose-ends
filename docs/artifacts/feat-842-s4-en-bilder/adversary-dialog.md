# Adversary Dialog — feat-842-s4-en-bilder
Spec: docs/specs/feat-842-schnitt-4a-en-bilder-iphone-ipad.md
Datum: 2026-11-07 18:30

## Checkliste
- [x] **AC-1:** Given ein Manifest wird für `en` gebaut, When `build_manifest` läuft, Then steht `sprache: en-US` darin, für `de` (und ohne Angabe) `de-DE`, und eine andere Sprache wird mit `StoreError` abgelehnt, bevor Dateien angefasst werden. Belegt durch `test_manifest_language_follows_lang`, `test_unknown_language_is_refused`.
- [x] **AC-2:** Given eine README der Sprache existiert, When ein Store-Lauf sie neu schreiben will, Then bleibt sie unverändert; fehlt sie, Then wird eine der Sprache angelegt (englisch mit `en-US`, deutsch mit `de-DE`). Belegt durch `test_readme_is_per_language_and_never_overwritten`.
- [x] **AC-3:** Given ein vorhandenes Manifest mit Watch- und Mac-Einträgen, When die iPhone-/iPad-Bilder neu erzeugt werden, Then bleiben die Watch- und Mac-Einträge im neuen Manifest, nicht aber alte iPhone-/iPad-Einträge. Belegt durch `test_other_devices_survive_a_new_run`.
- [x] **AC-4:** Given ein Lauf für `en` schreibt nach `docs/store/screenshots/en/`, When er endet, Then ist unter `docs/store/screenshots/de/` nichts verändert, und die Belege liegen je Sprache getrennt (`store-proof-en-iphone.txt`, `store-proof-en-ipad.txt`). Belegt durch `test_en_run_leaves_de_folder_untouched` (Ordnerlogik) und den echten Lauf aus AC-6 (Belegnamen, `git status` unter `de/` leer).
- [x] **AC-5:** Given `StoreScreenshotsTests` läuft ohne `LOOSEENDS_UI_LANG` (so wie im CI-Job `ui-smoke`), When der Test startet, Then startet die App deutsch mit den deutschen Aufgaben, die Klasse also unverändert zum Stand davor; mit `LOOSEENDS_UI_LANG=en` startet sie englisch mit den englischen Aufgaben. Belegt durch das Startargument im Testprotokoll beider Läufe (`-AppleLanguages (de)` bzw. `(en)`) aus dem echten Lauf `test-proof` (AC-6, AC-7) und das unveränderte `LaunchLanguage.code` (Standard `en`) für die Matrixklassen: `ui-smoke-lang` bleibt grün.
- [x] **AC-6:** Given der freigegebene Wortlaut, When `LOOSEENDS_UI_LANG=en ./scripts/sim.sh store-screenshots` auf iPhone 17 und iPad Pro 13″ läuft, Then bestehen beide UI-Test-Läufe, es liegen zehn PNG (je fünf) unter `docs/store/screenshots/en/` mit den Maßen 1206×2622 und 2064×2752 ohne Alphakanal, `manifest.json` nennt `en-US`, Commit und beide Geräte, und die Beleg-Dateien `store-proof-en-iphone.txt`/`store-proof-en-ipad.txt` stehen da. Alle zehn Bilder wurden geöffnet und beschrieben: App und Statusleiste englisch (9:41), Aufgaben wörtlich wie freigegeben, **keine deutschen Wörter** auf dem Bild (Ausnahme: nur, was der Katalog selbst in beiden Sprachen gleich führt), keine Tastatur im Bild, bei iPad kein Fenstergriff; Etiketten Phone/Garden, Dauer „30 min“ und Tag „Computer“ im Detail wie in den deutschen Bildern. Belegt durch den echten Lauf und die Bildbeschreibung im Abnahmebericht.
- [x] **AC-7:** Given die deutschen Bilder sind schon veröffentlicht, When `LOOSEENDS_UI_LANG=de ./scripts/sim.sh store-screenshots` (und ohne Variable) neu läuft, Then entsprechen die zehn neuen deutschen Bilder den bisherigen in Aufbau, Text, Zeilenzahl, Etiketten und Maßen; erlaubte Unterschiede sind nur, was von Tag und Rendern abhängt (das Datum am Kopf der Startseite, Zeichenglättung). Vor und nach dem Lauf wurden `01-start`, `03-neu` und `04-detail` beider Geräte nebeneinander geöffnet und die Unterschiede benannt; das Manifest hat dieselben Geräteeinträge (auch `watch`, `mac`) und dieselben Dateinamen, nur `erzeugt` und `commit` unterscheiden sich. Danach sind die deutschen Dateien auf den bisherigen Stand zurückgesetzt, und der Diff dieses Schnitts enthält nichts unter `docs/store/screenshots/de/`. Belegt durch den echten Lauf, die Gegenüberstellung im Abnahmebericht und `git status` unter `de/`.
  PO-Entscheidung 2026-11-07 (AskUserQuestion, F001): AC-7 angenommen als „Text, Etiketten, Zeilen und Maße gleich, Aufbau folgt der aktuellen App“ — iPhone 01/03/04 gleich bis aufs Datum, iPad-Aufbau seit #828/#831 anders; deutsche iPad-Bilder erneuert #870; `docs/store/screenshots/de/` im Diff unberührt. Verdict bleibt AMBIGUOUS mit Override.
- [x] **AC-8:** Given der Aufruf `./scripts/sim.sh store-screenshots` mit einer anderen Sprache (`LOOSEENDS_UI_LANG=fr`), When er startet, Then bricht er mit Meldung ab, bevor ein Simulator gestartet oder eine Datei geschrieben wird. Belegt durch den echten Aufruf (Ausgabe und Rückgabecode ungleich 0, `git status` unverändert).
- [x] **AC-9:** Given die Etiketten der englischen Beispielsätze, When die englischen Bilder 03-neu und 04-detail ansehen, Then zeigt „Call Anna about Sunday today“ das Etikett Phone, „Mow the lawn“ Garden, die anderen drei keins, und der Satz „Check the tax notice today“ steht als heutige Aufgabe unter „Jetzt“ (englisch „Now“) wie sein deutsches Gegenstück; Abweichungen vom Aufbau der deutschen Bilder sind im Bericht benannt (Wortlaut zur Freigabe Punkt 5). Belegt durch die geöffneten Bilder `en/iphone/03-neu.png`, `en/iphone/04-detail.png`, `en/ipad/04-detail.png`.

## Dialog

### Runde 1
**Adversary:** Testlauf und Code-Lesung.
- `python3 -m unittest scripts/test_store_screenshots.py scripts/test_sim_run_xcodebuild.py`: 43 Tests, OK, 0 fehlgeschlagen, 0 uebersprungen (Ausgabe: docs/artifacts/feat-842-s4-en-bilder/adversary-test-output.txt).
- AC-1/2/3: `language()` wirft vor jeder Dateiarbeit (store_screenshots.py:99, in `main` vor dem Schreiben aufgerufen), `build_manifest(..., lang)` setzt `en-US`/`de-DE`, `write_readme` ueberschreibt nie (:128), `keep_other_devices` behaelt nur Eintraege ausserhalb von DEVICES (:122). Tests dazu gruen.
- AC-4: `out="docs/store/screenshots/$lang"` (sim.sh:1208 ff.), Belege `store-proof-$lang-$device.txt`. Deutscher Ordner nach dem EN-Lauf unveraendert (Git status leer); `store-proof-en-*.txt` vorhanden.
- AC-8: `LOOSEENDS_UI_LANG=fr ./scripts/sim.sh store-screenshots` selbst ausgefuehrt: "Unbekannte Sprache 'fr' ...", rc=1, kein Simulator gestartet (sim.sh:1213 vor `cd`, `trap`, `boot`).
- EXIT-Trap: sim.sh:1218 `trap 'store_clear_bars; store_restore_lang; release_testlock' EXIT`; `STORE_LANG_RESTORE` wird VOR dem Schreiben gefuellt (store_set_lang), ein Abbruch mitten im Umstellen stellt also zurueck; `trap 'exit 130' INT TERM` fuehrt in den EXIT-Trap. Der Test `test_aborted_run_restores_through_exit_trap` prueft nur eine eigene Trap-Zeile im Fake, nicht die echte Zeile 1218 (gelesen, korrekt).
- Deutscher Lauf auf deutschem Simulator: `store_set_lang` kehrt bei passender Sprache mit `return 0` zurueck und merkt nichts zum Zuruecksetzen (`test_matching_language_changes_nothing`). Im neuen DE-Lauf (store-run-de-2.log) keine Zeile "Systemsprache ... Neustart".
- AC-5: `StoreScreenshotsTests.language = env ?? "de"` (StoreScreenshotsTests.swift:11), `LaunchLanguage.code` Standard `en` unveraendert (LaunchLanguage.swift:9). CI `ui-smoke` ruft `-only-testing:LooseEndsUITests` ohne Variable (ci.yml:207), also deutsch; `ui-smoke-lang` fuehrt die Klasse nicht aus (ci.yml:378-379). ABER: das in AC-5 versprochene Startargument im Testprotokoll gibt es nicht (Suche `AppleLanguages` in Logs und xcresult: 0 Treffer); sim.sh exportiert im Store-Lauf `LOOSEENDS_UI_LANG=de` ausdruecklich, der deutsche Lauf belegt "ohne Variable" also nicht. Nur Code-Lesung.
- Bilder (alle zehn EN geoeffnet): iPhone 1206x2622, iPad 2064x2752, hasAlpha no (sips). Statusleiste 9:41 bzw. "9:41 AM Sat Nov 7", alles englisch, keine deutschen Woerter. Aufgaben wie freigegeben mit PO-Wortlaut "Call Anna today about Sunday" (Titel "Call Anna about Sunday"); Phone/Garden, 30 min, Tag Computer im Detail; "Check the tax notice" unter Now mit !!!, Detail Importance High (vom PO akzeptiert, Folgeticket #864). Keine Tastatur in 01/03/04/05; 02-erfassen zeigt sie bewusst (auch im veroeffentlichten deutschen Bild): AC-6 "keine Tastatur" meint 01/03/04/05. iPad: kein Fenstergriff.
- Manifest en: `en-US`, Commit c94566e (HEAD zum Laufzeitpunkt, inzwischen 538a4c8), beide Geraete.

**Implementierer:** (keine Antwort im Lauf; Pruefer hat nichts geaendert.)

### Runde 2
**Adversary:** Gezielt AC-7. de-vergleich/ stammt vom 7.11. 08:15 auf iOS 27.0, VOR Simulatorsprach-Umstellung und drei Teststaenderungen: belegt AC-7 fuer den jetzigen Stand NICHT. Neuer Lauf `./scripts/sim.sh store-screenshots` (ohne Variable) selbst gefahren: beide Geraete "Test Succeeded" (store-run-de-2.log), Bilder gesichert in docs/artifacts/feat-842-s4-en-bilder/de-vergleich-2/, danach deutsche Dateien per checkout auf den Stand zurueckgesetzt; Git status docs/store zeigt nur noch `?? docs/store/screenshots/en/`.
- iPhone 01-start neu gegen veroeffentlicht (HEAD) nebeneinander geoeffnet: identisch in Aufbau, Text, Zeilenzahl, Etiketten, Massen, Statusleiste "09:41", Home-Indikator; Unterschied nur das Datum (Samstag 7. Nov. statt Freitag 30. Okt.).
- iPad 04-detail neu gegen veroeffentlicht: Aufbau ANDERS. Veroeffentlicht: links Startseite ("Heute verknotet", Jetzt-Zeilen, Inhalt), Leiste mit "+" und "...". Neu: links nur der Index (INHALT, "Start", Als naechstes ...), rechts Leiste "Erledigt, Stern, Kalender, Mond, ...". Ursache: App-Aenderungen auf main seit dem 30.10. (CLAUDE.md: #828 Index der breiten iPad-Seitenleiste, #831 Leiste mit Wort); der Diff dieses Schnitts fasst keine App-Datei an. Text, Etiketten, "30 Min." wortgleich deutsch. Manifest: nur erzeugt/commit unterscheiden sich.
- AC-7 ist fuer iPad wortwoertlich nicht erfuellbar: die veroeffentlichten deutschen iPad-Bilder sind gegenueber der aktuellen App veraltet. Kein Fehler dieses Schnitts, aber PO-Entscheidung (AMBIGUOUS).
- Beobachtung: EN-iPhone-Bilder ohne Home-Indikator, deutsche mit; Inkonsistenz zwischen den Sprachen.
- Restrisiko: `keep_other_devices` liest ein kaputtes manifest.json erst nach dem Schreiben der Bilder; folgenlos.

**Implementierer:** (keine Antwort im Lauf.)

## Findings und Confirmations

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: scripts/store_screenshots.py:296
  Description: Frischer deutscher Lauf (ohne Variable): iPhone-Bilder wie veroeffentlicht, iPad-Bilder mit anderem Aufbau, weil main die iPad-Oberflaeche seit 30.10. geaendert hat (#828, #831). Belege: docs/artifacts/feat-842-s4-en-bilder/de-vergleich-2/ipad/04-detail.png gegen die veroeffentlichte docs/store/screenshots/de/ipad/04-detail.png.
  Spec requirement: AC-7 — die zehn neuen deutschen Bilder entsprechen den bisherigen in Aufbau.
  Conflict: Aufbau der deutschen iPad-Bilder weicht ab; nicht durch diesen Diff verursacht, AC-7 buchstaeblich nicht erfuellt.
  Remediation: PO entscheidet: AC-7 fuer iPad als "Text und Etiketten gleich, Aufbau folgt der aktuellen App" annehmen, veraltete deutsche iPad-Bilder als eigenes Ticket erneuern (de/ bleibt in diesem Schnitt unberuehrt).

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEndsUITests/StoreScreenshotsTests.swift:11
  Description: Standard de ohne Variable gilt per Code, aber das in AC-5 versprochene Startargument im Testprotokoll liegt in keinem Beleg vor; der Store-Lauf exportiert de ausdruecklich.
  Spec requirement: AC-5 — belegt durch Startargument im Testprotokoll.
  Conflict: nur Code-Pfad-Beleg (ci.yml:207 ohne Variable).
  Remediation: AC-5-Beleg im Abnahmebericht als Code-Lesung benennen oder einmal `test-proof StoreScreenshotsTests` ohne Variable fahren.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/sim.sh:1188
  Description: EN-iPhone-Bilder ohne Home-Indikator, DE mit (Zeitabhaengigkeit nach Simulator-Neustart store_sim_reboot moeglich); Test des EXIT-Traps prueft nicht die echte Zeile sim.sh:1218.
  Spec requirement: AC-6 — Bilder wie die deutschen.
  Conflict: kleine Abweichung zwischen den Sprachen, kein Wortlaut betroffen.
  Remediation: im Bericht benennen; optional kurze Pause nach bootstatus.

Confirmation:
  AC: AC-1
  Code reference: scripts/store_screenshots.py:99
  Evidence: language() lehnt unbekannte Sprache vor Dateiarbeit ab, build_manifest nimmt en-US/de-DE; Tests gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/store_screenshots.py:128
  Evidence: write_readme legt nur an, wenn fehlt; Test gruen; en/README.md vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/store_screenshots.py:122
  Evidence: keep_other_devices behaelt nur nicht-DEVICES-Eintraege.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/sim.sh:1208
  Evidence: Ausgabe nach docs/store/screenshots/$lang, Belege store-proof-$lang-$device.txt, de/ unberuehrt.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsUITests/LaunchLanguage.swift:9
  Evidence: Matrixklassen bleiben en, Store-Klasse de ohne Variable; nur per Code, siehe F002.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: docs/store/screenshots/en/manifest.json:2
  Evidence: zehn PNG mit korrekten Massen ohne Alpha, en-US, Bilder geoeffnet und beschrieben.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/sim.sh:1213
  Evidence: fr bricht mit rc=1 vor Simulatorstart ab, selbst ausgefuehrt.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEndsUITests/LaunchLanguage.swift:34
  Evidence: Phone/Garden-Etiketten, Tax notice unter Now, 03-neu/04-detail geoeffnet; PO-Wortlaut aus wortlaut-aenderung.md.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_sim_run_xcodebuild.py:321
  Evidence: teilweise (iPhone identisch, Sprachlogik und EXIT-Trap getestet); iPad-Aufbau weicht ab, siehe F001.
  Status: AMBIGUOUS

Confirmation:
  AC: Dokumentation
  Code reference: CLAUDE.md:64
  Evidence: CLAUDE.md-Zeilen zu store-screenshots stimmen mit dem Verhalten ueberein.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: AMBIGUOUS
Ambiguous findings: F001 (AC-7, iPad-Aufbau der veroeffentlichten deutschen Bilder veraltet durch main-Aenderungen, nicht durch diesen Diff). Proven points: 8/9. Tests: 43 passed, 0 failed, 0 uebersprungen.

## Geprüfte Dateien

- sha256:d8a3ed2cc19bf5c23e8a0805f5efc0d4b028101e86f8b736a58709521ea45a2b  CLAUDE.md
- sha256:8cc86af3ab48b14f5eb9e2cc64f856037bf2043b3a01b320d376e2c836f959ca  LooseEndsUITests/LaunchLanguage.swift
- sha256:76ce53d7542a0eab71890b376652de38757705040409938b3526137471d41eb1  LooseEndsUITests/StoreScreenshotsTests.swift
- sha256:6ff036d909d85b32039b832e4812833a69d22631a757cdd1e23a8f5ab004b4af  docs/store/screenshots/en/manifest.json
- sha256:15c441247e54fe896acc1742ba66471d3158ac6fe66ae69ba62b5a9d265b16dd  scripts/sim.sh
- sha256:06eee903b04547da3250f9aa1f15e67d0be12ce16db737d2c353e07cb958f8c5  scripts/store_screenshots.py
- sha256:1033a64c4c76af357437a9a7a5f588ad136d88cf28abb7b2a49594da1fc84e87  scripts/test_sim_run_xcodebuild.py

## Prüfbasis

- base: 239d7aad7e776387553e82ab72520e1629dd6912
- blob:03b3cd8fdbb603d2387670ff234c0b4c5d787da4  CLAUDE.md
- blob:99e6fbbb939f92cfbd30e05423be276ed406aa79  LooseEndsUITests/LaunchLanguage.swift
- blob:8373eda78d6fbb5c09f932b696b544bc0ba133c6  LooseEndsUITests/StoreScreenshotsTests.swift
- blob:7f32aed599ad3459404935dcb6515f48f852ae39  docs/store/screenshots/en/manifest.json
- blob:8f059338e904608fe8658bdfe73f81fa8b20fdd0  scripts/sim.sh
- blob:eec12c5d84f39af3ab87f6ef4dfcd6eb3d44d4f3  scripts/store_screenshots.py
- blob:9a9beeb8d5bd00d04348edbeebdd398ea634702c  scripts/test_sim_run_xcodebuild.py
