# Adversary Dialog — feat-742-store-screenshots

Spec: docs/specs/feat-742-schnitt-1-iphone-ipad.md
Datum: 2026-10-30 (nach #746 und Entfernung des Fenster-Griffs; Bilder und Skripte neu erzeugt, noch nicht festgeschrieben)
Vorgänger: adversary-dialog-vorher.md (VERIFIED vor der iPad-Nachbesserung), danach AMBIGUOUS wegen weißer Flächen (F001) und Fenster-Griff (F008). Beides ist behoben.

## Checkliste

- [x] **AC-1:** Je Gerät fünf PNG-Dateien `01-start` … `05-erledigt` unter `docs/store/screenshots/de/iphone/` und `…/ipad/`. PROVEN: Die Ordner enthalten genau diese Dateien. Läufe grün (iPhone 17: 17:35:00, iPad Pro 13-inch (M5): 17:37:07).
- [x] **AC-2:** Größen und Alphakanal. PROVEN: `sips` liefert für alle iPad-Bilder 2064×2752, `hasAlpha: no`; iPhone 1206×2622, `hasAlpha: no`.
- [x] **AC-3:** Deutsch, hell, ohne Rahmen und Bildunterzeile, 9:41, Akku voll. PROVEN: Alle zehn Bilder angesehen. Der Fenster-Griff ist auf iPad 01, 03, 04 und 05 weg (Pixelvergleich der Ecke: 0 abweichende Pixel).
- [x] **AC-4:** Keine persönlichen Daten. PROVEN: nur Testsätze, Start mit `--ui-testing`, Speicher nur im Arbeitsspeicher.
- [x] **AC-5:** Inhalte je Bild. PROVEN: 01 „Jetzt 2“ mit zwei Zeilen, 03 vier Aufgaben, 04 Detail mit „Fällig Heute“, 05 „Blumen gießen“ erledigt (iPhone wie iPad).
- [x] **AC-6:** Manifest und README. PROVEN: `manifest.json` mit `de-DE`, je Gerät fünf Dateien in Reihenfolge; README vorhanden.
- [x] **AC-7:** Statusleiste zurücksetzen, Altbilder entfernen. PROVEN: Trap in `scripts/sim.sh`, `rmtree` in `scripts/store_screenshots.py`, Tests grün, `status_bar list` leer.
- [x] **AC-8:** Benutzen statt bauen. PROVEN: `simulator-run.txt` und `store-proof-ipad.txt` (17:37:07, iPad) sowie `store-proof-iphone.txt` (17:35:00, iPhone 17): je 1 bestanden, 0 fehlgeschlagen, 0 übersprungen.

## Dialog

### Runde 1

**Adversary:** Behauptung: Der Griff ist auf iPad 01, 03, 04, 05 weg, 02 unverändert, Inhalt unbeschädigt. `python3 -m unittest scripts/test_store_screenshots.py`: 15 Tests, 0 übersprungen, OK (WindowGripTests, GripHookTests). Alle fünf iPad-Bilder neu geöffnet: unten rechts durchgehend Papier-Beige, im 150×150-Eckbereich 0 Pixel mit mehr als 2 Abweichung je Kanal, bei allen vier Bildern. 02-erfassen: Ecke enthält die Tastatur, sichtbar unverändert, kein Griff sichtbar. Die weißen Flächen auf 01 und 05 sind nicht mehr vorhanden.

**Implementierer:** Die Entfernung läuft in der Nachbearbeitung (`scripts/store_screenshots.py`), nur für iPad, weil sich der Griff im Simulator nicht abschalten ließ (Recherche und Suche in den Simulator-Einstellungen ohne Schalter).

### Runde 2

**Adversary:** Nachfrage zu Grenzen und Schäden. `clear_grip_bmp` nimmt das Eckquadrat 72×72 (GRIP_CORNER), liest einen 8-Pixel-Streifen links und darüber (GRIP_BAND) und übermalt nur, wenn alle Streifenpixel auf höchstens 2 je Kanal (GRIP_TOLERANCE) übereinstimmen; sonst bleiben die Daten unverändert. Der Hook läuft nur für `device == "ipad"`. Grenzen: Läge echter Inhalt im Quadrat auf einfarbigem Papier, würde er übermalt (F005). Ist der Streifen uneinheitlich, bleibt der Griff still stehen (F006). Ränder rundherum unbeschädigt (Seitenleiste, Trennlinie, Schaltflächen). Belege: `manifest.json` erzeugt 2026-10-30T16:37:10Z, passend zu den Beleg-Läufen. F003 aus dem Vorlauf erledigt: beide Geräte belegt.

**Implementierer:** Beide Grenzen sind bekannt und für die fünf vorliegenden Bilder ohne Folge; bei Layoutänderungen bleibt die Sichtprüfung Pflicht.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: scripts/store_screenshots.py:113
  Description: Der Fenster-Griff wird per `clear_grip_bmp` entfernt; auf iPad 01, 03, 04, 05 nachweislich weg. BEHOBEN. Restrisiko: Bei uneinheitlichem Streifen wird still nicht gemalt (F006).
  Spec requirement: AC-3 — reine App-Bilder.
  Conflict: keiner mehr.
  Remediation: keine nötig.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: scripts/sim.sh:1152
  Description: Die Statusleiste wird mit `--batteryState discharging --batteryLevel 100` gesetzt, die Spec nennt `charged`. Im Bild kein Unterschied.
  Spec requirement: Implementation Details — `charged`.
  Conflict: wörtliche Abweichung.
  Remediation: im Abschlussbericht nennen.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: docs/store/screenshots/de/manifest.json:4
  Description: `commit` im Manifest ist der Stand vor dem Festschreiben der Bilder.
  Spec requirement: Manifest nennt eine Commit-Kennung.
  Conflict: verweist nicht auf den Commit, der die Bilder enthält.
  Remediation: hinnehmen, im Bericht nennen.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: scripts/store_screenshots.py:125
  Description: Das Eckquadrat wird übermalt, wenn der Randstreifen einfarbig ist, auch wenn im Quadrat echter Inhalt läge.
  Spec requirement: Bilder zeigen den App-Inhalt unverändert.
  Conflict: theoretisch; bei den fünf Bildern kein Schaden.
  Remediation: akzeptieren; Sichtprüfung bei Layoutänderungen.

Finding:
  ID: F006
  Severity: LOW
  Category: edge_case
  Code reference: scripts/store_screenshots.py:130
  Description: Bei uneinheitlichem Streifen gibt die Funktion die Daten unverändert zurück, ohne Meldung.
  Spec requirement: AC-3.
  Conflict: stiller Rückfall.
  Remediation: Warnung oder Prüfung, optional.

Finding:
  ID: F007
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_store_screenshots.py:186
  Description: Kein Test für Inhalt im Quadrat bei einfarbigem Streifen (Grenze aus F005).
  Spec requirement: Testplan.
  Conflict: Lücke bei einer Randbedingung.
  Remediation: optional.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/store_screenshots.py:40
  Evidence: `finish_device` schreibt je Gerät fünf Dateien und ruft für iPad den Griff-Hook; zehn Dateien vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/store_screenshots.py:90
  Evidence: `sips` je Datei: iPad 2064×2752, iPhone 1206×2622, `hasAlpha: no`.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/store_screenshots.py:138
  Evidence: `sips_clear_grip` PNG→BMP→PNG ohne Alphakanal; Eckbereich 150×150 auf iPad 01, 03, 04, 05 ohne abweichende Pixel; alle Bilder angesehen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsUITests/StoreScreenshotsTests.swift:26
  Evidence: Startargument `--ui-testing`, nur Testsätze im Bild.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsUITests/StoreScreenshotsTests.swift:23
  Evidence: Hochformat; Inhalte je Bild wie in der Checkliste.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: docs/store/screenshots/de/manifest.json:1
  Evidence: zwei Einträge 1206x2622 und 2064x2752, je fünf Dateien in Reihenfolge, `de-DE`; README vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/sim.sh:1140
  Evidence: `store_clear_bars` im Trap, Altbild-Entfernung getestet, `status_bar list` ohne Überschreibung.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/artifacts/feat-742-store-screenshots/simulator-run.txt:1
  Evidence: iPad-Lauf 17:37:07 und iPhone-Lauf 17:35:00, je Passed, 1 bestanden, 0 fehlgeschlagen, 0 übersprungen.
  Status: CONFIRMED

Weitere zitierte Dateien (Abdeckung): Code reference: scripts/test_store_screenshots.py:162 (WindowGripTests), Code reference: scripts/test_store_screenshots.py:205 (GripHookTests), Code reference: docs/store/screenshots/de/README.md:1.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Kein Produktionscode geändert; Test- und Werkzeugcode, keine verdächtigen Zeilen.

## Verdict

VERDICT: VERIFIED
Tests: 15 Python passed, 0 failed, 0 übersprungen; UI-Läufe iPhone 17 und iPad Pro 13-inch (M5) je 1 bestanden, 0 fehlgeschlagen, 0 übersprungen. Alle acht ACs belegt. Offen nur LOW-Punkte (F002, F004 bis F007), kein Blocker.

## Geprüfte Dateien

- sha256:971db4179bd2eb24b6f3b8dd4b6b0d134c3c6e9af60c0aca0dccfaaacfff7d3f  LooseEndsUITests/StoreScreenshotsTests.swift
- sha256:fa28bea027ccab9f6f2b929f2ecb8994699c533122995c0ce1b93478110ddc38  docs/artifacts/feat-742-store-screenshots/simulator-run.txt
- sha256:3db4e426bfc10fa7f0c3f4954847b17554e571d522d3a8684e17919d88cc4bb0  docs/store/screenshots/de/manifest.json
- sha256:be8c36caa35a4feed8d8572e6ee464fd87e68225f6f3b75b34aba1f423de0690  scripts/sim.sh
- sha256:b454a38730ddf693e1f1002eafe280a7636fd63e489bdf057253a033589d0733  scripts/store_screenshots.py
- sha256:3de861aa6ac3fedae36962a52e58f2516d2fd8fd079a62639ba3339182979549  scripts/test_store_screenshots.py

## Prüfbasis

- base: 991c2e62abc40f2122c9a9da0afb67f14b6a9d47
- blob:c13e9f26cda5398870bd1d4e731932771494a1b0  LooseEndsUITests/StoreScreenshotsTests.swift
- blob:71efc1a1cf16a4411bcbe6abf29f3e692764d420  docs/artifacts/feat-742-store-screenshots/simulator-run.txt
- blob:fad3465bff4091d5966e0fbfb84dddda1d137bdf  docs/store/screenshots/de/manifest.json
- blob:d773e2a8b2dd010b9e9d1249ffb3702a6b258f6b  scripts/sim.sh
- blob:d4da5f57646896509fc8fcbe2f9c326d34f2ada0  scripts/store_screenshots.py
- blob:f6f0dfa95f6cce8cc3805a23fd92fb0e1d2485ad  scripts/test_store_screenshots.py
