# Adversary Dialog — feat-742-store-screenshots
Spec: docs/specs/feat-742-schnitt-1-iphone-ipad.md
Datum: 2026-10-30 10:29

## Checkliste
- [x] **AC-1:** `./scripts/sim.sh store-screenshots` erzeugt je Gerät fünf PNG-Dateien `01-start` … `05-erledigt` unter `docs/store/screenshots/de/iphone/` und `…/ipad/`. Belegt durch Lauf und Dateiliste.
- [x] **AC-2:** Alle iPhone-Bilder sind exakt 1206×2622 px, alle iPad-Bilder exakt 2064×2752 px, keines hat einen Alphakanal. Belegt durch `sips -g pixelWidth -g pixelHeight -g hasAlpha` je Datei (Ausgabe im Abschlussbericht) und die Python-Tests `test_wrong_size_aborts`, `test_alpha_aborts_when_not_removed`.
- [x] **AC-3:** Die Bilder sind deutsch und hell, ohne Rahmen und ohne Bildunterzeile; die Statusleiste zeigt 9:41 mit vollem Akku. Belegt durch Ansehen aller zehn Bilder (geöffnet und beschrieben im Abschlussbericht, nicht gezählt) und `simctl status_bar … clear` danach.
- [x] **AC-4:** Die Bilder enthalten keine persönlichen Daten: nur die Testsätze des Tests. Belegt durch Ansehen (AC-3) und Prüfung, dass der Test nur im Arbeitsspeicher läuft (`--ui-testing`).
- [x] **AC-5:** `01-start` zeigt „Jetzt“ mit mindestens zwei Zeilen, `03-neu` mindestens zwei Aufgaben, `04-detail` das Detail mit Fälligkeit, `05-erledigt` mindestens eine erledigte Aufgabe. Belegt durch Ansehen (AC-3) und die Zwischenprüfungen des UI-Tests.
- [x] **AC-6:** `manifest.json` nennt je Gerätegröße Pixelmaß und die Dateien in Upload-Reihenfolge; `README.md` erklärt der Desktop-Sitzung die Zuordnung. Belegt durch `test_manifest_lists_both_sizes` und Diff.
- [x] **AC-7:** Die Statusleiste des Simulators wird auch bei einem fehlgeschlagenen Lauf zurückgesetzt, und ein zweiter Lauf lässt keine Altbilder zurück. Belegt durch `test_old_files_removed` und einen absichtlich abgebrochenen Lauf (`simctl status_bar … list` zeigt danach keine Überschreibung).
- [x] **AC-8:** Die App wird für die Abnahme benutzt, nicht nur gebaut: Der Lauf aus AC-1 ist der Nachweis (`test-proof`-Beleg für iPhone und iPad). Belegt durch `docs/artifacts/feat-742-store-screenshots/simulator-run.txt`.

## Dialog

### Runde 1
**Adversary:** Ich behaupte, die Lieferung ist kaputt. Gepruefte Punkte mit Belegen:
- AC-1/AC-2: `sips` je Datei: iPhone 01-05 je 1206x2622 hasAlpha no, iPad 01-05 je 2064x2752 hasAlpha no. Je fuenf Dateien pro Geraet, kein Zwischenordner `.iphone-neu`/`.ipad-neu` (ls -a zeigt nur ipad, iphone, manifest.json, README.md). Code reference: scripts/store_screenshots.py:48 (Staging, Pruefung Zeile 59-63, Austausch Zeile 67-69). `python3 -m unittest scripts/test_store_screenshots.py` -> "Ran 10 tests ... OK" (adversary-test-output.txt). Code reference: scripts/test_store_screenshots.py:1
- AC-3/AC-4/AC-5 (alle zehn PNG geoeffnet): iPhone 01 deutsch, hell, 09:41, voller Akku, "Heute zwei Dinge faellig", Jetzt 2 Zeilen, erfundene Saetze, keine Tastatur; 02 Erfassen-Sheet mit Tastatur (gewollt) und getipptem Satz; 03 Neu mit vier Aufgaben; 04 Detail Steuerbescheid mit Faellig Heute, Dauer 30 Min., Etiketten Computer, KEINE Karte "Noch nicht sortiert"; 05 Erledigt mit "Blumen giessen". iPad 01 und 02 ohne Tastatur (02 zeigt die getippte Zeile statt Fenster, freigegebene Abweichung), 03 Neu mit vier Aufgaben, 04 Detail mit Faellig/30 Min./Computer, keine Karte, 05 Erledigt mit einer Aufgabe. Keine persoenlichen Daten, kein Rahmen, keine Bildunterzeile. Kosmetisch: iPad 01/05 zeigen einen weissen Panel-Streifen (App-Verhalten, kein Spec-Verstoss).
- AC-6: manifest.json nennt beide Groessen, Pixelmass und Dateien 01..05; README erklaert die Zuordnung. Code reference: scripts/store_screenshots.py:73
- AC-7: Statusleiste per trap auch bei Fehler/Abbruch zurueckgesetzt, Altbilder werden durch Austausch des ganzen Ordners entfernt. Code reference: scripts/sim.sh:1141 (trap Zeile 1143-1144)
- AC-8: Belege store-proof-iphone.txt (10:26:34) und store-proof-ipad.txt/simulator-run.txt (10:28:43): Passed, 1 bestanden, 0 uebersprungen; Hash der Testdatei im Beleg 9e3405... = shasum der Arbeitskopie; mtime StoreScreenshotsTests.swift 10:24:42, store_screenshots.py 10:17:18, sim.sh 09:58:47, alle aelter als beide Belege; Bilder 10:28 aus demselben Lauf. Code reference: LooseEndsUITests/StoreScreenshotsTests.swift:91 (fillDetail prueft Computer in Zeile 115, 30 in 116, keine reviewNote in 114).
- Kein Geraetezugriff: grep devicectl in sim.sh trifft nur alte Geraetebefehle (Zeilen 799-1088), nicht den neuen Block 1137-1163. CLAUDE.md nennt den Befehl. Code reference: CLAUDE.md:64

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/store_screenshots.py:124
  Description: main() ersetzt den iPhone-Ordner, bevor der iPad-Export geprueft ist. Scheitert iPad danach, liegen neue iPhone-Bilder neben altem iPad-Ordner und altem manifest.json (Commit-Feld veraltet).
  Spec requirement: AC-7 — zweiter Lauf laesst keine Altbilder zurueck
  Conflict: Teilzustand nach Abbruch; Nutzer sieht Fehlermeldung, Exit 1, kein stiller Erfolg.
  Remediation: Beide Staging-Ordner pruefen, dann beide tauschen. Nicht blockierend.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/StoreScreenshotsTests.swift:113
  Description: waitForNonExistence(confirm) besteht auch, wenn "Passt" nie erschien; die Pruefung auf Dauer/Etikett (Zeile 115-116) und fehlende reviewNote (114) faengt das Ergebnis aber ab.
  Spec requirement: AC-5 — Detail mit Faelligkeit
  Conflict: schwache Zwischenpruefung, Ergebnis dennoch abgesichert.
  Remediation: keine noetig.

**Implementierer:** F003/F004 sind LOW, F001/F002 aus dem ersten Durchgang sind behoben (Staging Zeile 48-69, Doppelanhang Zeile 112-113).

### Runde 2
**Adversary:** Nachgebohrt: Zwischenordner-Fehlerpfad raeumt per `except BaseException` (store_screenshots.py:64) auf, alter Ordner bleibt unberuehrt; alter `.xxx-neu` wird beim Start entfernt (Zeile 50). Doppelanhang bricht ab (test dazu in den 10 Tests gruen). Frueher bekannte Abweichungen (discharging, iPad-02 getippte Zeile, keine Perle, Umfang) vom PO freigegeben. Keine Regression: Aufrufer von finish_device nur main (Zeile 124). Detail oeffnet ueber "Faellig", dadurch nie die Karte.
**Implementierer:** Keine weiteren Einwaende. Sichtbare Bilder und Belege decken alle ACs.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
Tests: 10 Python passed, 0 failed; UI-Test StoreScreenshotsTests je Geraet 1 bestanden, 0 uebersprungen (Belege). Edge cases: nur LOW F003/F004. Checklist 8/8.

Confirmation:
  AC: AC-1
  Code reference: scripts/sim.sh:1141
  Evidence: cmd_store_screenshots fuehrt je Geraet test-proof aus, trap setzt Statusleiste zurueck.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_store_screenshots.py:1
  Evidence: 10 Tests OK inkl. Groesse/Alpha/Doppelanhang/Altbilder.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsUITests/StoreScreenshotsTests.swift:91
  Evidence: fillDetail prueft Computer, 30, keine reviewNote.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: CLAUDE.md:64
  Evidence: Befehl dokumentiert; manifest.json und README gelesen.
  Status: CONFIRMED

## Geprüfte Dateien

- sha256:c235ee148ce5bfca493f0723781f306644610ca7992719c15f0e5196159acf94  CLAUDE.md
- sha256:9e340577aca267acc1b58e67d295d6ef2e0e39ae9a423d8c6b78a712d6cd6fbf  LooseEndsUITests/StoreScreenshotsTests.swift
- sha256:be8c36caa35a4feed8d8572e6ee464fd87e68225f6f3b75b34aba1f423de0690  scripts/sim.sh
- sha256:289611bedcdb08ecaf527b2a54f76f8a0469fa3a518cf4ced0f9e0ab0a98e6f5  scripts/store_screenshots.py
- sha256:c18c4a36a776a63089561296dd64cbb2ab05979960c204c655d488322485f154  scripts/test_store_screenshots.py

## Prüfbasis

- base: 754b4f0cc9ce98e20deecfe2e3f8ff79108f5b73
- blob:209ef1a70b8f7443ca9298aab1a2fd3f9ec53303  CLAUDE.md
- blob:82cf762fdeab98d221b5ac6aaee0b0966ce24173  LooseEndsUITests/StoreScreenshotsTests.swift
- blob:d773e2a8b2dd010b9e9d1249ffb3702a6b258f6b  scripts/sim.sh
- blob:29ea28dd53f2c0a353408d9d4e957540c34060f9  scripts/store_screenshots.py
- blob:eb960acabfaf8e4c0d380fd2e8e60a40314686d1  scripts/test_store_screenshots.py
