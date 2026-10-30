# Adversary Dialog — feat-742-store-screenshots
Spec: docs/specs/feat-742-schnitt-1-iphone-ipad.md
Datum: 2026-10-30 10:15

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
**Adversary:** Tests: `python3 -m unittest scripts/test_store_screenshots.py` -> 8 Tests, OK (adversary-test-output.txt). sips je Datei: iPhone alle 1206x2622, iPad alle 2064x2752, hasAlpha überall no. Manifest zwei Geräte mit korrekten Pixelmaßen und 01..05 in Reihenfolge, README nennt Zuordnung. Alle zehn Bilder geöffnet. iPhone: 01 Startseite "Heute zwei Dinge fällig", Jetzt 2 mit Steuerbescheid und Anna (Telefon); 02 Erfassen-Sheet mit Text "Fahrrad zur Inspektion bringen" und Tastatur (gewollt, iPhone); 03 Neu mit vier Aufgaben; 04 Detail Steuerbescheid mit Fällig "Heute"; 05 Erledigt mit "Blumen gießen". Alle deutsch, hell, 09:41, Akku voll, WLAN/Balken, keine Rahmen/Bildunterzeilen. iPad: 01 bis 05 ohne Tastatur, Statusleiste 09:41, untere Bildhälfte leer (Inhalt nur oben), 02 zeigt getippte Zeile statt Fenster (bekannte Abweichung), ein kleiner grauer Bogen unten rechts auf allen iPad-Bildern (vermutlich Fenstergriff des Simulators), weiße Flächenreste im Detailbereich von 01/02/05. Persönliche Daten: keine; nur Testsätze, Datum "Freitag 30. Okt." ist das Tagesdatum. Belege: store-proof-iphone.txt (Passed, 1/1, head e9d8869, 10:04) und simulator-run.txt = iPad (Passed, 10:06); Testdatei-Hash im Beleg gleich der Arbeitskopie, Test (09:58) und sim.sh (09:58) sind älter als die Läufe, Bilder (10:06) jünger: Bilder stammen vom aktuellen Stand. Keine Gerätezugriffe: Suche nach devicectl/device in store_screenshots.py und StoreScreenshotsTests.swift ohne Treffer; der sim.sh-Befehl nutzt nur $SIMCTL auf Simulatoren. simctl status_bar list beider Simulatoren: keine Überschreibung mehr. test-proof löscht vorher den alten Beleg und das xcresult (sim.sh:649), also keine veralteten Exporte.
**Implementierer:** Abweichungen sind bekannt und vom PO freigegeben (discharging statt charged, iPad-02 ohne Fenster, Perle fehlt, Umfang über 250 LoC).

### Runde 2
**Adversary:** Randfälle. (a) Fehlender Anhang: `finish_device` bricht mit "Bild fehlt" ab (store_screenshots.py:44-46), getestet. (b) Falsche Größe/Alpha: Abbruch mit beiden Größen (:58-61), getestet. (c) Doppelte Anhänge: `read_export` überschreibt still, letzter gewinnt (:101-105); LOW. (d) `finish_device` löscht den Geräteordner vor der Prüfung (:48-50): ein Fehlschlag hinterlässt Teilbilder und vernichtet die letzten guten; LOW, wiederherstellbar über die Versionsverwaltung. (e) Manifest-"commit" ist HEAD (e9d8869), obwohl der Arbeitsstand nicht eingecheckt ist (:117); LOW, belegt durch Testdatei-Prüfsumme. (f) Tastatur: `putKeyboardAway` lehnt ein Bild mit sichtbarer Tastatur per XCTAssertFalse ab (StoreScreenshotsTests.swift:95-102), Prüfung über Rahmen gegen App-Rahmen; plausibel, iPad-Bilder 01/02 belegen es. (g) Fehlerpfad: `trap 'store_clear_bars; release_testlock' EXIT` und INT/TERM -> exit 130; Fehler in test-proof und xcresulttool schlagen durch, der Trap läuft; Zustand nach Erfolgslauf: keine Überschreibung. Ein absichtlich abgebrochener Lauf wurde laut Auftrag nicht gefahren; Nachweis nur über Code und Zustand. (h) Inhalt: 04-detail zeigt auf beiden Geräten die Karte "Noch nicht sortiert ... sobald Apple Intelligence bereitsteht"; für Store-Bilder fragwürdig, nicht Teil der AC; MEDIUM als Hinweis an den PO. iPad: untere Bildhälfte leer, Bogen unten rechts; kosmetisch.
**Implementierer:** (c) bis (e) sind Randfälle des Werkzeugs, kein Produktcode; Bilder sind versioniert wiederherstellbar.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Findings und Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/store_screenshots.py:39
  Evidence: finish_device schreibt fünf Dateien, prüft Größe und Alpha; build_manifest (Zeile 66) liefert beide Größen; sips-Werte aller zehn Bilder stimmen.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_store_screenshots.py:1
  Evidence: 8 Tests laufen grün (Ran 8 tests, OK).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/sim.sh:1137
  Evidence: cmd_store_screenshots mit trap (EXIT/INT/TERM), status_bar override und clear je Gerät, test-proof je Gerät, Beleg-Kopien; kein devicectl; Statusleiste danach ohne Überschreibung.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsUITests/StoreScreenshotsTests.swift:137
  Evidence: --ui-testing, Deutsch, Zwischenprüfungen (Jetzt >= 2, Neu >= 2, field_dueDate, Erledigt nicht leer), Tastaturprüfung Zeile 95; Bilder bestätigen es.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: CLAUDE.md:64
  Evidence: Befehlszeile store-screenshots im Abschnitt Build vorhanden; Belege store-proof-iphone.txt und simulator-run.txt Passed.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/store_screenshots.py:48
  Description: Geräteordner wird vor Größen- und Alphaprüfung gelöscht, bei Abbruch bleiben ungeprüfte Teilbilder.
  Spec requirement: AC-7 — keine Altbilder; Abbruch bei falscher Größe
  Conflict: Keine Verletzung der AC, aber Teilzustand nach Abbruch.
  Remediation: In Temp-Ordner schreiben, nach erfolgreicher Prüfung austauschen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/store_screenshots.py:105
  Description: Doppelte Anhänge gleichen Namens überschreiben sich still.
  Spec requirement: AC-1 — genau fünf Bilder je Gerät
  Conflict: Keine Warnung bei Wiederholungsläufen.
  Remediation: Bei Duplikat abbrechen oder bewusst den neuesten wählen.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: scripts/sim.sh:1157
  Description: batteryState discharging statt charged (vom PO freigegeben), iPad-02 ohne Fenster (freigegeben); abgebrochener Lauf nicht gefahren.
  Spec requirement: AC-3 / AC-7
  Conflict: Bekannte Abweichungen; Akku im Bild voll.
  Remediation: Im Abschlussbericht nennen.

Finding:
  ID: F004
  Severity: MEDIUM
  Category: anti_pattern
  Code reference: LooseEndsUITests/StoreScreenshotsTests.swift:162
  Description: 04-detail zeigt die Karte "Noch nicht sortiert ... Apple Intelligence bereitsteht" (Simulator ohne Modell); iPad-Bilder mit leerer unterer Hälfte.
  Spec requirement: keine AC betroffen
  Conflict: Inhaltliche Qualität, nicht Spec.
  Remediation: PO entscheiden lassen.

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:c235ee148ce5bfca493f0723781f306644610ca7992719c15f0e5196159acf94  CLAUDE.md
- sha256:b72440389bd69caee76e509aba872dd7aa5b1112cce6ad552c0bede2f73403f5  LooseEndsUITests/StoreScreenshotsTests.swift
- sha256:be8c36caa35a4feed8d8572e6ee464fd87e68225f6f3b75b34aba1f423de0690  scripts/sim.sh
- sha256:3765a050afb3df18759840f4c6e5dece34e793567134a832c1edc06b134b5355  scripts/store_screenshots.py
- sha256:3cc501551f3df9db078fd832b766968c49fd6ca2162f9395b3422a7c3be7acab  scripts/test_store_screenshots.py

## Prüfbasis

- base: 754b4f0cc9ce98e20deecfe2e3f8ff79108f5b73
- blob:209ef1a70b8f7443ca9298aab1a2fd3f9ec53303  CLAUDE.md
- blob:622fb777ac0252d4c13b4f0049518ca93a3c1c52  LooseEndsUITests/StoreScreenshotsTests.swift
- blob:d773e2a8b2dd010b9e9d1249ffb3702a6b258f6b  scripts/sim.sh
- blob:6f4b020c8dfa34f04372d462e5d8839af67111ea  scripts/store_screenshots.py
- blob:9acdd410c2089eada9f9f20a6c87218cf3db61cd  scripts/test_store_screenshots.py
