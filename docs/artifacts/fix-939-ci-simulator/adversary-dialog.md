# Adversary Dialog — fix-939-ci-simulator
Spec: docs/specs/fix-939-ci-ui-smoke-zeitbudget.md
Datum: 2026-11-20 21:16

## Checkliste
- [x] **AC-1:** Bei N = 6 kommt jede Testmethode der Klassen aus `LooseEndsUITests/` (ohne `Watch/`, Gewicht > 0) genau einmal in den Teilen vor; keine Klasse steht ganz und zerlegt zugleich (Test liest Klassen und Methoden unabhängig per Regex und vergleicht).
- [x] **AC-2:** Bei N = 6 ist kein Teil leer, `only` ist in keinem Teil leer, keine Gewicht-0-Klasse steht in `only`, und `DesignGalleryTests` und `StoreScreenshotsTests` liegen in verschiedenen Teilen.
- [x] **AC-3:** Kein Teil wiegt mehr als die Zielgröße (Gesamtgewicht / N, aufgerundet) plus das größte Einzelgewicht einer unzerlegten Einheit; die Planausgabe für N = 6 am echten Verzeichnis hält diese Grenze (Hochrechnung der Analyse: größter Teil rund 21 Tests), und der größte Teil liegt unter den 31 Tests von heute.
- [x] **AC-4:** Die Aufteilung ist deterministisch (zweimal berechnet, gleiche Ausgabe), und eine neue Testklasse in einem temporären Verzeichnis wird automatisch einem Teil zugeordnet.
- [x] **AC-5:** `ci.yml` ruft `ui_smoke_shards.py 6` auf, der Schritt „Run UI smoke tests“ hat `timeout-minutes: 55`, der Job `ui-smoke-shard` 70, die Schritte „Upload design gallery“ und „Upload UI test results“ haben `continue-on-error: true`, und genau ein Job heißt `UI Smoke (iOS Simulator)` mit `if: always()` und `needs: [ui-smoke-shard]` (Test liest die YAML).

## Dialog

### Runde 1
**Adversary:** Beweis je AC. AC-1: unabhaengige Nachzaehlung per eigenem Regex (`func test\w*(`) ergibt 164 Methoden im Verzeichnis (inkl. Mac-only-Klassen, Gewicht 0). Planausgabe N=6: 55 `only`-Eintraege, keine Duplikate (Zaehler ueber alle Teile). Nur `CaptureSmokeTests` wird zerlegt; keine Klasse steht ganz und zerlegt zugleich. Frage: Methoden aus Basisklassen/Extensions, die bei Zerlegung verloren gehen? Gleichnamige Methoden in zwei Klassen? Klasse genau gleich Zielgroesse?
**Implementierer:** `grep -E "class \w+ *: *\w+"` ausser XCTestCase: keine Unterklasse einer Testklasse, also keine geerbten Tests. Die einzige Extension (`MacUITestSupport.swift:9`, `extension XCTestCase`) hat 0 `func test`. Methoden-IDs sind `Klasse/test`, gleiche Namen in zwei Klassen kollidieren nicht. Bedingung `weight > target` (ui_smoke_shards.py:72): Klasse gleich Ziel bleibt ganz, korrekt, da Grenze AC-3 dann haelt. Format `-only-testing:LooseEndsUITests/CaptureSmokeTests/testX` (ui_smoke_shards.py:99) ist xcodebuild-konform. Auskommentierte Tests: Regex ist zeilenanfangsverankert (`^\s*`), `// func test` wuerde nicht zaehlen; Treffer per grep: keine.
**Adversary:** AC-2/3/4/5: Teile haben 2,10,11,11,10,11 only-Eintraege, keiner leer. Gewichte je Teil [21,21,21,21,20,20], Gesamt 124, Ziel 21, groesster Teil 21 < 31. Zweimal berechnet: `cmp` identisch. YAML: ci.yml:127 `ui_smoke_shards.py 6`, :135 Job-timeout 70, :227 Schritt 55, :350/:358 `continue-on-error: true` an beiden Uploads, :374 genau ein Job `UI Smoke (iOS Simulator)` mit `needs: [ui-smoke-shard]` und `if: always()`. Unittests: 13 OK (adversary-test-output.txt).
**Implementierer:** Keine Gegenbeispiele. Teil 1 hat nur 2 Eintraege (Fotoklasse 4 + Klasse), weil Gewicht, nicht Anzahl, balanciert wird.

### Runde 2
**Adversary:** Skepsis gegen Frueh-Einigkeit: gibt es Zeilen, die das Test-Regex verfehlt (z. B. `func test` mit Parametern, die xcodebuild nicht als Test sieht)? Greift der Code, wenn eine Klasse in einer Datei mit `#if os(macOS)` steht?
**Implementierer:** `grep func test..(` ohne leere Klammern: keine Treffer; Mac-Dateien erhalten Gewicht 0 (ui_smoke_shards.py:45) und kommen nie in `only` (Zeile 100). Ausfuehrung der Tests belegt das (test_f002_*). Rest-Risiko ohne Finding: ein Methodenname, der nicht mit `test` beginnt, ist fuer XCTest ohnehin kein Test. CLAUDE.md-Aenderung (sechs Teile, 70/55, Upload-Hinweis) stimmt mit ci.yml ueberein.
**Adversary:** Keine Findings. Alle AC bewiesen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Confirmation:
  AC: AC-1
  Code reference: scripts/ui_smoke_shards.py:72
  Evidence: Zerlegung nur bei weight > target; 55 Einheiten, keine Duplikate, eigener Regex zaehlt gleich
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/ui_smoke_shards.py:100
  Evidence: only filtert Gewicht 0; leeres only -> sys.exit (Zeile 103); Fotoklassen getrennt (Zeile 86)
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/test_ui_smoke_shards.py:106
  Evidence: Teilgewichte [21,21,21,21,20,20], Ziel 21, unter 31
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/test_ui_smoke_shards.py:116
  Evidence: cmp zweier Laeufe identisch; neue Klasse wird zugeordnet
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: .github/workflows/ci.yml:374
  Evidence: Sammel-Job needs ui-smoke-shard, if always; Timeouts 70/55 (Zeilen 138, 227), continue-on-error Zeilen 350, 358
  Status: CONFIRMED

Confirmation:
  AC: Doku
  Code reference: CLAUDE.md:261
  Evidence: beschreibt sechs Teile, 70/55 Minuten, Methoden-Zerlegung
  Status: CONFIRMED

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 13 passed, 0 failed, 0 übersprungen
Edge cases: All checked, none broken
Regressions: None found
Checklist: 5/5 points proven

## Geprüfte Dateien

- sha256:c6b753ef603742b52ce21e821c26fb9a4b9ab3c8488540314ac5876101e257d4  .github/workflows/ci.yml
- sha256:a7c21fa813f78cd0176e83e41499d5743279e34e9b8a8d8ecff5447ec1646277  CLAUDE.md
- sha256:cae938cce7983969ec1ee3d57ca654437fa3a97ec4377e32e0ecdb633a4904bb  scripts/test_ui_smoke_shards.py
- sha256:abb07ea9d5a945a61a34fea632394eca3557c95f40edab55df18628e0bdc9b70  scripts/ui_smoke_shards.py

## Prüfbasis

- base: a8da1e3818942594852204f612379cea4bd245d0
- blob:a175d3a693f7f0a446c4ebbb43d2a6a5a4dacca8  .github/workflows/ci.yml
- blob:ac561a8bfe8098c17c8c43d71f223a58dd07cd18  CLAUDE.md
- blob:1c658e8b85435e16cddcecd52d4531bf5b01871d  scripts/test_ui_smoke_shards.py
- blob:0c5be9b6590bb10c74668ba057a5a7a86ea45a69  scripts/ui_smoke_shards.py
