# Adversary Dialog — feat-842-s4b2-en-mac
Spec: docs/specs/feat-842-schnitt-4b-2-en-mac.md
Datum: 2026-11-08 16:02

## Checkliste
- [x] **AC-1:** Given ein englischer Zielordner mit Manifest (`en-US`; iPhone, iPad, Watch) und ein Mac-Export mit den vier Anhängen, When `main_mac` die Mac-Bilder einträgt, Then stehen `mac/01-start.png`, `03-neu.png`, `04-detail.png`, `05-erledigt.png` im Ordner, das Manifest nennt die Reihenfolge iPhone, iPad, Watch, Mac mit unverändertem `en-US` und unveränderten Einträgen der anderen Geräte, und der Mac-Eintrag nennt `1280x800`. Belegt durch `test_mac_entry_is_added_to_en_manifest` (rot vor, grün nach dem Lauf der Python-Tests).
- [x] **AC-2:** Given ein Manifest mit altem Mac-Eintrag und eine README mit Zusatzzeilen sowie ein Ordner `de/`, When `main_mac` erneut läuft, Then wird nur der Mac-Eintrag ersetzt (genau einmal vorhanden), die anderen Geräte, README und alles unter `de/` bleiben byte-gleich; ein Bild mit nicht erlaubter Größe bricht mit `StoreError` ab und lässt Mac-Ordner und Manifest stehen. Belegt durch `test_mac_rerun_replaces_only_the_mac_entry`, `test_mac_run_leaves_readme_and_de_untouched`, `test_mac_wrong_size_aborts`.
- [ ] **AC-3:** Given die geänderte `store-mac.yml`, When sie gelesen und mit `workflow_dispatch` ohne Eingabe, mit `language=de` und mit `language=en` durchgespielt wird, Then steht die Eingabe `language` als Auswahl `de`/`en` mit Standard `de` im Workflow, der Testschritt setzt `TEST_RUNNER_LOOSEENDS_UI_LANG` auf `${{ inputs.language || 'de' }}` (ein Push auf `store/mac` und eine leere Eingabe ergeben `de`), und der Artefaktname trägt die Sprache. Belegt durch Lesen der Datei im Diff und durch das Protokoll der beiden echten Läufe (Umgebungsvariable und Artefaktname `StoreMac-en` bzw. `StoreMac-de`); die CI-Prüfung des PR 1 (YAML gültig, Wächter-Tests grün) zeigt, dass der Workflow lädt. [offen: braucht CI-Lauf store-mac.yml (en, de)]
- [ ] **AC-4:** Given der Fototest ohne `LOOSEENDS_UI_LANG` oder mit `de` (Standard), When er in der CI läuft, Then startet die App deutsch (`-AppleLanguages (de)`, `-AppleLocale de_DE`) und der Test fotografiert die vier deutschen Aufgaben wortgleich zu den bisherigen Literalen („Steuerbescheid heute prüfen“, „Anna heute wegen Sonntag anrufen“, „Blumen heute gießen“, „Rasen mähen“); mit `en` startet sie englisch (`-AppleLanguages (en)`, `-AppleLocale en_US`) und der Test erfasst die vier freigegebenen englischen Aufgaben („Check the tax notice today“, „Call Anna today about Sunday“, „Water the flowers today“, „Mow the lawn“). Belegt durch die Startargumente im Protokoll beider CI-Läufe und den sichtbaren Text auf `01-start`. [offen: braucht CI-Lauf store-mac.yml (en, de)]
- [ ] **AC-5:** Given PR 1 ist gemergt, When `gh workflow run store-mac.yml -f language=en` auf `main` läuft, Then besteht der Lauf, das Artefakt `StoreMac-en` enthält die vier Anhänge `store-01-start`, `store-03-neu`, `store-04-detail`, `store-05-erledigt`, und nach `python3 scripts/store_screenshots.py --mac docs/store/screenshots/en <export>` liegen vier PNG (1280×800, ohne Alphakanal) unter `docs/store/screenshots/en/mac/`; das englische `manifest.json` enthält zusätzlich den Mac-Eintrag bei unverändertem iPhone-/iPad-/Watch-Teil. Alle vier Bilder wurden geöffnet und beschrieben: `01-start` zeigt die englische Oberfläche mit den englischen Aufgaben unter „Now“, `03-neu` die Liste „New“ mit einer englischen Aufgabe, `04-detail` das Detail mit englischem Rohtext und der Schaltfläche zum Erledigen, `05-erledigt` die Liste „Completed“ mit der erledigten Aufgabe; Titel und Seitenleistenwörter brechen im Fenster nicht unleserlich um; **keine deutschen Wörter** auf allen vier Bildern; das Fenster passt auf den Bildschirm (`macAssertWindowFitsScreen` hat bestanden). Belegt durch die Run-ID des CI-Laufs, `sips`-Maße und die Bildbeschreibung im Abnahmebericht. [offen: braucht CI-Lauf store-mac.yml (en, de)]
- [ ] **AC-6:** Given die deutschen Mac-Bilder sind veröffentlicht, When `gh workflow run store-mac.yml -f language=de` (und der Lauf ohne Eingabe) als Gegenprobe läuft, Then bestehen sie und die Bilder entsprechen den bisherigen in Aufbau, Text, Zeilenzahl und Maßen (1280×800); erlaubter Unterschied ist nur, was am Lauftag hängt („heute“, Datumsangaben). Vor und nach dem Lauf wurden ein deutsches und ein bisheriges Bild nebeneinander geöffnet und der Unterschied benannt; es gibt keinen Pixelvergleich. Die Dateien des Gegenlaufs werden nicht ins Repo übernommen: im Diff des Schnitts steht nichts unter `docs/store/screenshots/de/`. Belegt durch die Run-IDs, die Gegenüberstellung im Abnahmebericht und `git status` unter `de/`. [offen: braucht CI-Lauf store-mac.yml (en, de)]
- [ ] **AC-7:** Given PR 1 und PR 2, When der Schnitt gemergt ist, Then sind alle Tests grün: `python3 -m unittest scripts/test_store_screenshots.py` samt den übrigen Skript-Tests, die CI des PR 1 (`ui-smoke` und der Rest; `Mac Gallery (macOS)` kompiliert das geänderte `MacStoreScreenshotsTests` im selben Testziel mit), und `./scripts/sim.sh build` übersetzt. Belegt durch die Laufbelege und die grüne CI beider PRs. [offen: braucht CI-Lauf store-mac.yml (en, de)]
- [ ] **AC-8:** Given die Änderung berührt nur `LooseEndsUITests/`, `.github/`, `scripts/` und `docs/`, When der Schnitt abgenommen wird, Then endet die Abnahme nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“; der „Benutzen“-Beleg ist der echte CI-Fotolauf (AC-5 mit geöffneten Bildern, AC-6 als Gegenprobe). Auf Hennings Geräten läuft nichts, und Mac-Bilder entstehen nie auf seinem Mac. Belegt durch die Dateiliste des Diffs gegen die Geräteliste und den Abschlussbericht. [offen: braucht CI-Lauf store-mac.yml (en, de)]

## Dialog
### Runde 1
**Adversary:**
Tests: python3 -m unittest scripts/test_store_screenshots.py -v ergibt 30 Tests, OK, 0 übersprungen (docs/artifacts/feat-842-s4b2-en-mac/adversary-test-output.txt). Die vier MacLanguageTests (plus 2 weitere: Fototest-Quelltext, Workflow-Eingabe) sind grün.

Confirmation:
  AC: AC-1
  Code reference: scripts/test_store_screenshots.py:302
  Evidence: test_mac_entry_is_added_to_en_manifest grün; Manifest-Reihenfolge, en-US, 1280x800 geprüft.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_store_screenshots.py:314
  Evidence: test_mac_rerun_replaces_only_the_mac_entry, test_mac_run_leaves_readme_and_de_untouched (:322), test_mac_wrong_size_aborts (:334) grün.
  Status: CONFIRMED

Teilbelege (Punkte bleiben offen, weil CI-Lauf fehlt):
- AC-3 Dateiteil: Code reference: .github/workflows/store-mac.yml:5 Eingabe language, choice, [de, en], default de (:5-11); Zeile 38 setzt TEST_RUNNER_LOOSEENDS_UI_LANG auf inputs.language mit Rückfall 'de'; Zeile 59 Artefaktname StoreMac plus Sprache (gleicher Rückfall). Push auf store/mac: inputs.language ist leer, also 'de'. Gleiches Muster wie ci.yml:371 (matrix.lang), dort liest LaunchLanguage.code die Variable; ob der Präfix auch bei platform=macOS ankommt, ist nur im CI-Lauf beweisbar.
- AC-4 Codeteil: Code reference: LooseEndsUITests/MacStoreScreenshotsTests.swift:10 Standard "de"; :11-12 Aufgaben über LaunchLanguage.phrase(_, in:); :20 Locale über LaunchLanguage.locale(for:). LaunchLanguage.swift:13-18 liefert en_US/de_DE; :33-36 deutsche Literale wortgleich zu den alten (per Diff verglichen). MacUITestSupport.swift:18 setzt -AppleLanguages aus locale.prefix(2) und -AppleLocale. Unbekannte Sprache führt zu preconditionFailure (LaunchLanguage.swift:51), kein stilles Deutsch.
- AC-7 lokal: Mac-Testziel kompiliert, TEST BUILD SUCCEEDED im mac-build.log (1 Treffer).
- AC-8 Dateiliste: Diff = .github/workflows/store-mac.yml, LooseEndsUITests/MacStoreScreenshotsTests.swift, docs/store/screenshots/en/README.md (plus scripts/test_store_screenshots.py im letzten Commit). Kein Pfad der Geräteliste berührt; nichts unter docs/store/screenshots/de/.
  Code reference: docs/store/screenshots/en/README.md:5 (Watch/Mac-Zeile), :9 (Mac nur per store-mac.yml, language=en).

**Implementierer:**
(nicht beteiligt, Kontext isoliert)

### Runde 2
**Adversary:**
Nachbohren an Edge Cases:
- Leere Eingabe / Push: inputs ist im push-Event leer, der Fallback 'de' greift; Artefaktname gleich. Kein Defekt.
- LOOSEENDS_UI_LANG leer gesetzt: der Standard greift nur bei nil, ein leerer String würde phrase() abbrechen. Der Workflow setzt nie leer, nur theoretisch.
- Fehlermeldungen der Assertions bleiben deutsch; betrifft keine Bilder.
- Deutsche Gegenprobe: Literale wortgleich, Locale de_DE wie zuvor.
- Umbruch und englische Wörter im 1280x800-Fenster: ohne CI-Bilder nicht prüfbar (AC-5).

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsUITests/MacStoreScreenshotsTests.swift:6
  Description: Klassenkommentar spricht von five attachments, der Test macht vier (01, 03, 04, 05); schon vor der Änderung so.
  Spec requirement: keine AC betroffen
  Conflict: nur Kommentar-Ungenauigkeit
  Remediation: optional four schreiben.

Kein Defekt gefunden, der AC-1 bis AC-8 verletzt. Offen sind ausschließlich CI-abhängige Punkte.

**Implementierer:**
(nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (precondition_origins.default_lang)

## Verdict

VERDICT: AMBIGUOUS

Offen (kein Defekt): AC-3, AC-4, AC-5, AC-6, AC-7 CI-Teil, AC-8 Benutzen-Beleg - offen: braucht CI-Lauf store-mac.yml (en, de).
Tests: 30 passed, 0 failed, 0 übersprungen

## Geprüfte Dateien

- sha256:719363b8f7539568bcb4f3ec682aae73056437c7cddbb75ecd41b6a40e89a42b  LooseEndsUITests/MacStoreScreenshotsTests.swift
- sha256:4bd4ebc3b73e0c54f76a7f58cad09bdab86f84367d0b88e616c5d90825be137b  docs/store/screenshots/en/README.md
- sha256:71cc17f8e6f83d6323a61e0f1598317682946d269be061fa89bb0b21cded0eab  scripts/test_store_screenshots.py

## Prüfbasis

- base: e65f99b93fd865b65404d6d8ee8c2fbb464150aa
- blob:222c5c2091b17f545416a8241b8074994628103f  LooseEndsUITests/MacStoreScreenshotsTests.swift
- blob:d24f4e2022896e3c76378d5e606b3ab3049928bf  docs/store/screenshots/en/README.md
- blob:7869a5a38d93735fffd6b547aacf91e8d80034bd  scripts/test_store_screenshots.py
