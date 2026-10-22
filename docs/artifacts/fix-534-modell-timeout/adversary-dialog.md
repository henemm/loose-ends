# Adversary Dialog — fix-534-modell-timeout
Spec: docs/specs/fix-534-schnitt-1-mac-latenz.md
Datum: 2026-10-21 22:28

## Checkliste
- [x] **AC-1:** Neue Suite `RealModelLatencyTests` trägt dieselben Gates wie `RealModelTests` (`.enabled(if: RealModel.isRequested)`, `.serialized`, Verfügbarkeitsprüfung); ohne `LOOSEENDS_REAL_MODEL=1` wird sie übersprungen, nie rot. `RealModelGateTests` prüft das im Quelltext auch für die neue Suite.
- [x] **AC-2:** Je Prozess: ein erster Aufruf (kalt) mit `RealModel.notes[0]`, danach 10 warme Aufrufe (die sechs Notizen reihum). Jede Probe wird mit `ContinuousClock` gemessen und als Zeile `{gruppe: "kalt"|"warm", note, sekunden, fehler?}` in eine JSON-Datei geschrieben, deren Pfad die Umgebungsvariable `LOOSEENDS_LATENCY_OUT` nennt. Ohne diese Variable schreibt die Suite nichts und bleibt trotzdem grün. Ein fehlgeschlagener Aufruf wird als Probe mit `fehler` festgehalten und bricht die Reihe nicht ab.
- [x] **AC-3:** `./scripts/sim.sh real-model-latency <n>` baut einmal (`build-for-testing`), startet dann n Prozesse nacheinander (`test-without-building`, nur `RealModelLatencyTests`) und sammelt die n JSON-Dateien unter `docs/artifacts/534-modell-latenz/`. Es holt die Testsperre wie `real-model`, prüft macOS >= Target und Apple Silicon und bricht bei einer fehlenden Datei mit Meldung ab. Es fasst kein iPhone, iPad oder keine Watch an.
- [x] **AC-4:** `scripts/latency_summary.py <ordner>` liest die Rohdaten und gibt je Gruppe n, Minimum, Median, p95 und Maximum aus, Fehlerproben getrennt gezählt. Fehlt eine Gruppe oder ist der Ordner leer: klare Meldung, Exit ≠ 0. `scripts/test_latency_summary.py` prüft das mit festen Beispielwerten.
- [x] **AC-5:** Gemessen sind mindestens 15 Prozesse (15 kalte, 150 warme Proben). Der Bericht `docs/reference/modell-latenz.md` enthält: Gerät und System (`sw_vers`, Chip), Bau, Weg, Läufe; die Kennzahlen aus AC-4 getrennt kalt/warm; die Aussage „prozess-kalt, nicht system-kalt“; die Einordnung aus „Purpose“ (wofür das Modell noch gebraucht wird, mit Verweisen); eine **Empfehlung** zu Alternative B (zwei Grenzen) mit Zahlen (Kalt-Maximum gegen Warm-Maximum, Schwelle Faktor 5); den Vermerk, dass p95 bei n=15 nur beschreibt und das Maximum die Grenze trägt; den offenen Punkt „iPhone → Schnitt 2“. Der Bericht legt **keine** neue Zahl für das Produkt fest.
- [x] **AC-6:** `EnrichmentCoordinator.swift` und alles unter `Shared/` bleiben unverändert (die Dateiliste des PR enthält dort nichts).

## Dialog

### Runde 1
**Adversary:** Alles aktiv geprüft, nicht nur gelesen.
- AC-1: RealModelLatencyTests.swift trägt `.enabled(if: RealModel.isRequested ...)`, `.serialized` und am Test `.enabled(if: RealModel.isAvailable ...)`; RealModelGateTests.latencySuiteIsGated prüft alle drei plus LOOSEENDS_LATENCY_OUT im Quelltext. Gate-Lauf (test-green-swift.txt): 3 bestanden, 0 fehlgeschlagen, 0 übersprungen.
- AC-2: kalt mit `RealModel.notes[0]`, 10 warme Aufrufe reihum (`index % notes.count`); ContinuousClock; Fehler im do/catch zur Probe mit `fehler` (Reihe läuft weiter), kein `try?`. Ohne LOOSEENDS_LATENCY_OUT: Rückkehr vor dem Schreiben, Test grün. Nachgerechnet: alle 15 Dateien beginnen mit genau 1 kalt, dann 10 warm, zusammen 15/150.
- AC-3: `bash -n scripts/sim.sh` ok. cmd_real_model_latency: Argumentprüfung (n >= 1), acquire_testlock, mac_hosts_tests, arm64-Prüfung, build-for-testing einmal, n mal test-without-building mit nur RealModelLatencyTests, `[ -s "$file" ]` bricht mit Meldung ab. Kein devicectl/Gerätezugriff. Hilfezeile (3,35p) und case-Eintrag ergänzt.
- AC-4: `python3 scripts/test_latency_summary.py`: 5 Tests OK. Randfälle: Ordner nur mit Fehlerproben -> "Gruppe ohne gültige Probe: kalt, warm", rc 1; leerer Ordner -> Meldung, rc 1; nicht vorhandener Ordner -> rc 1; p95 nearest-rank: n=10 -> 10, n=20 -> 19, n=1 -> Wert; Fehlerproben zählen nicht in die Statistik.
- AC-5: `latency_summary.py docs/artifacts/534-modell-latenz` ergibt kalt 15 / 2,77 / 3,15 / 4,20 / 4,20 / 0 und warm 150 / 2,52 / 3,14 / 3,73 / 4,67 / 0; identisch zum Bericht. 4,20/4,67 = 0,90; 30/4,67 = 6,42. Bericht enthält Gerät/System (M4, macOS 27.0.1, lokal `sw_vers` ebenfalls 27.0.1), Bau, Weg, Läufe, Kennzahlen kalt/warm, "prozess-kalt" mit Abgrenzung zu system-kalt, Einordnung mit Verweisen #202/#95/#215, Empfehlung zu Alternative B mit Zahlen und Faktor 5, p95-Vermerk, offenen Punkt Schnitt 2. Keine neue Produktzahl (die "vorläufige Rechnung" ist ausdrücklich "nicht festgelegt").
- AC-6: Diff gegen HEAD über Shared und LooseEnds ist leer; die Dateiliste seit Commit 17190e7 zeigt nichts unter Shared/.
Befunde: F001 und F002 (beide LOW).
**Implementierer:** F001/F002 liegen außerhalb der AC-Formulierung (klare Meldung nur für leeren Ordner/fehlende Gruppe verlangt).

### Runde 2
**Adversary:** (a) Suite übersprungen (Apple Intelligence aus) ergibt grünen xcodebuild ohne Datei; `[ -s "$file" ]` fängt das mit Meldung ab. (b) Probe mit sekunden 0 würde zählen; Daten zeigen min 2,52 s, kein Ausreißer. (c) Messlog zeigt 15 Läufe und dieselbe Ausgabe wie lokal reproduziert. (d) Das Verhältnis 0,9 hängt am Warm-Maximum; der Bericht sagt, das Maximum trägt die Grenze. Keine weiteren Brüche. Der echte Messlauf wurde nicht wiederholt.
**Implementierer:** Keine Änderung nötig.

## Befunde

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/latency_summary.py:42
  Description: `read_folder` ruft `json.loads` ohne Fehlerbehandlung; kaputtes JSON endet in einem Traceback (JSONDecodeError), eine Zeile ohne `sekunden` in KeyError.
  Spec requirement: AC-4 — klare Meldung nur bei fehlender Gruppe/leerem Ordner
  Conflict: Keine Verletzung des Wortlauts; Exit ist != 0, nur ohne klare Meldung.
  Remediation: Optional JSONDecodeError/KeyError abfangen und mit Dateinamen melden.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/sim.sh:419
  Description: `rm -f "$out"/lauf-*.json` löscht vorhandene Rohdaten vor dem Bau; scheitert der Bau, fehlen sie bis zum Checkout.
  Spec requirement: AC-3
  Conflict: Keiner; Daten liegen nach dem Commit im Repo.
  Remediation: Optional erst nach erfolgreichem build-for-testing löschen.

## Bestätigungen

Confirmation:
  AC: AC-1
  Code reference: LooseEndsTests/RealModelLatencyTests.swift:13
  Evidence: Suite-Gates isRequested + .serialized, Test-Gate isAvailable.
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: LooseEndsTests/RealModelGateTests.swift:18
  Evidence: latencySuiteIsGated prüft alle Gates im Quelltext; Lauf 3/3 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsTests/RealModelLatencyTests.swift:56
  Evidence: kalt + 10 warm reihum, Fehlerprobe via catch, Schreiben nur mit LOOSEENDS_LATENCY_OUT; Rohdaten 15x(1+10) verifiziert.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/sim.sh:410
  Evidence: cmd_real_model_latency mit Sperre, macOS/arm64-Prüfung, build-for-testing einmal, n Prozesse, Abbruch bei fehlender Datei; kein Gerätezugriff; bash -n ok.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/latency_summary.py:57
  Evidence: Kennzahlen je Gruppe, Fehlerproben getrennt, Exit 1 bei leerem Ordner/fehlender Gruppe; scripts/test_latency_summary.py:1 fünf Tests OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: docs/reference/modell-latenz.md:25
  Evidence: Zahlen deckungsgleich mit latency_summary.py über docs/artifacts/534-modell-latenz/lauf-01.json bis lauf-15.json (15/150); alle geforderten Bestandteile vorhanden; Messlog docs/artifacts/fix-534-modell-timeout/messlauf.log:1.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/sim.sh:1
  Evidence: Änderungsmenge enthält nichts unter Shared/ oder EnrichmentCoordinator.swift.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Tests: Python 5 bestanden, 0 fehlgeschlagen; RealModelGateTests (Log) 3 bestanden, 0 fehlgeschlagen, 0 übersprungen.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:1ae40ad1b545f41482b103382036e29d959b7d18fe6291cdee1fcdf3610f174d  LooseEndsTests/RealModelGateTests.swift
- sha256:c94b9a73462e1f9398a3aab43c2ba1626a57b6651821fdf4d37e075e459d0d7a  LooseEndsTests/RealModelLatencyTests.swift
- sha256:13e0b958621639a3c2442cf8d68fc410f602381c42801a17d39d727e09a7d39f  docs/reference/modell-latenz.md
- sha256:8a2a89847a68f10cd8f900078d1d0dba2e11b81580f31bf9fe823ebf1913812b  scripts/latency_summary.py
- sha256:0ad0a62f2e8641ce69d4a977d9e4e3489da26ae13c24113f56084c4e1ff1a8b7  scripts/sim.sh

## Prüfbasis

- base: 17190e7ca2dbc0a403938879079de35656990789
- blob:c8926ce6a5d164e2c454c9dc3391b8cde811778d  LooseEndsTests/RealModelGateTests.swift
- blob:ec0aac1609c6a4411ef9cc22f31d42041fce2488  LooseEndsTests/RealModelLatencyTests.swift
- blob:f483dcf0e083a261060bcdca5b6e9f62705d3d56  docs/reference/modell-latenz.md
- blob:b54318bca0f86f41a60b77aacb1b679915a2988a  scripts/latency_summary.py
- blob:ffd24c0c26881dce90c3ad38c9e7afb57d362bf3  scripts/sim.sh
