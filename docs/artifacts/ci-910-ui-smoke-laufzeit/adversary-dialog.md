# Adversary Dialog — ci-910-ui-smoke-laufzeit
Spec: docs/specs/feat-910-ui-smoke-aufteilung.md
Datum: 2026-11-12 16:46

## Checkliste
- [x] **AC-1:** `ui_smoke_shards.py` ordnet jede `XCTestCase`-Klasse aus `LooseEndsUITests/` (ohne `Watch/`) genau einem Teil zu; keine Klasse fehlt, keine liegt doppelt (Test liest die Klassen unabhängig per Regex und vergleicht).
- [x] **AC-2:** Bei N = 4 ist kein Teil leer, und `DesignGalleryTests` und `StoreScreenshotsTests` liegen in verschiedenen Teilen.
- [x] **AC-3:** Die Aufteilung ist deterministisch (zweimal aufgerufen, gleiche Ausgabe), und eine neu angelegte Testklasse in einem temporären Verzeichnis wird automatisch einem Teil zugeordnet.
- [x] **AC-4:** Das Gewicht des schwersten Teils übersteigt den Durchschnitt höchstens um das größte Einzelgewicht (Güte der gierigen Verteilung, geprüft am echten Verzeichnis).
- [x] **AC-5:** In `ci.yml` heißt genau ein Job `UI Smoke (iOS Simulator)`, es ist der Sammel-Job mit `if: always()` und `needs: [ui-smoke-shard]`; der Test liest die YAML und prüft das.

Hinweis (2026-11-12): AC-6 bis AC-8 sind in der Spec seither die Belege A bis C der Definition of Done (Phase 7, echter CI-Lauf auf dem PR) und stehen nicht mehr in der Checkliste; die Bewertung „Aufbau tauglich“ unten bleibt gültig.

## Dialog

### Runde 1
**Adversary:** Testlauf `python3 -m unittest discover -s scripts -p 'test_*.py'`: Ran 728 tests, OK (skipped=1); Ausgabe in docs/artifacts/ci-910-ui-smoke-laufzeit/adversary-test-output.txt. Die eine übersprungene ist scripts/test_asc_crashes.py:355 (skipTest, Schlüssel nicht im Schlüsselbund, nur CI), unabhängig von #910. scripts/test_ui_smoke_shards.py: 6 Tests grün. `ui_smoke_shards.py 4` liefert vier Teile mit Gewicht 29/29/28/29, kein Teil leer, Foto-Klassen getrennt (Teil 3 und 4). ci.yml parst; Jobnamen: "UI Smoke (iOS Simulator)" genau einmal (Schlüssel ui-smoke), "UI Smoke part N", "UI Smoke plan". Grep auf ui-smoke im Repo: nur ci.yml, CLAUDE.md, Skript-Tests und ein Action-Kommentar betroffen; ui-smoke-lang und Artefakt ui-smoke-<lang> kollidieren nicht mit UITestResults-<n>; ui-ipad, mac-gallery haben kein needs auf ui-smoke; speech-stress/testflight referenzieren ihn nicht.
**Implementierer:** (nicht beteiligt, Kontextisolation)

Pruefpunkte: AC-1 bis AC-5 am echten Verzeichnis belegt. Sammel-Job: needs [ui-smoke-shard], if always(), RESULT ungleich success führt zu exit 1. Scheitert der Plan-Job, ist der Matrix-Job übersprungen, needs.ui-smoke-shard.result ist dann skipped und damit rot; failure und cancelled ebenso, fail-fast ist aus. Logik stimmt; Beleg AC-6/AC-7 steht auf dem PR aus (kein Defekt). Shell: ONLY kommt über env: (nicht in den Skripttext interpoliert), ungequotet gewollt, enthält nur -only-testing:LooseEndsUITests/Name ohne Glob- oder Leerzeichen. fromJSON(needs.ui-smoke-plan.outputs.matrix) korrekt (include-Liste mit shard, classes, only). Artefaktnamen mit matrix.shard eindeutig; Galerie-Export toleriert fehlende Anhänge; if-no-files-found warn. Zeitgrenzen: Job 60, Testschritt 45, Plan 10, Sammel 10.

### Runde 2
**Adversary:** Gezielte Angriffe auf Klassenerkennung und Aufbau.
(a) Probe mit temporären Dateien: Attribut MainActor in eigener Zeile vor `final class AAA: XCTestCase` wird erkannt; dasselbe Attribut in derselben Zeile wie die Klasse und eine Unterklasse `final class Sub: Base` werden NICHT erkannt (weights liefert nur AAA und Base). Im heutigen Verzeichnis kommt keins von beiden vor (grep), aber eine solche neue Klasse fiele still aus dem Lauf, genau das, was das Spec verhindern will; der AC-1-Test nutzt dieselbe Regex wie das Skript und fängt das nicht (nicht unabhängig).
(b) Ganze Datei unter `#if os(macOS)` (MacDetailClickTests, MacGalleryTests, MacKeyboardTests, MacStoreScreenshotsTests): Gewicht 0 korrekt, aber diese Klassen existieren im iOS-Build gar nicht; Teil 3 übergibt vier -only-testing für nicht vorhandene Klassen. Das Spec nimmt "laufen auf iOS nur als übersprungen" an; tatsächlich sind sie wegkompiliert. Ob xcodebuild das still ignoriert oder abbricht, ist hier nicht belegbar, sichtbar erst im PR-Lauf (AC-6).
(c) Inline-Schritte statt Composite-Action (Abweichung vom Spec): Schritte unverändert zum alten Job, test_ci_settle_sync, test_ci_xcode27 und test_sim_lock grün (Zieljob angepasst). Begründet, sicherer, akzeptiert. Kosmetisch: scripts/test_ci_settle_sync.py:7 nennt noch den Job ui-smoke.
(d) Sammel- und Plan-Job laufen auf dem macOS-Label xcode-27 mit Checkout und Xcode-Auswahl, obwohl nur eine Variable geprüft wird: eine weitere Queue-Abhängigkeit; ohne freien Runner bleibt der geschützte Check pending statt rot.
(e) CLI: N=0 bricht mit Meldung ab. Mehr Teile als Klassen ergäbe leere Teile mit leerem ONLY, und `xcodebuild test` ohne Filter führte das ganze Target aus. Bei N=4 nicht erreichbar.
(f) Teil 1 hält CaptureSmokeTests (26 Tests) als größten Block; Gewicht balanciert, tatsächliche Zeit wird auf dem PR gemessen.
**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** Nachprüfung nach Behebung von F001, F002, F004. Testlauf `python3 -m unittest discover -s scripts -p 'test_*.py'`: Ran 731 tests, OK (skipped=1, scripts/test_asc_crashes.py:355, unabhängig von #910); Ausgabe in docs/artifacts/ci-910-ui-smoke-laufzeit/adversary-test-output.txt (überschrieben). ci.yml unverändert; alle Workflows und Actions laden als YAML.
(a) F001, Gegenproben in temporärem Verzeichnis (Klassen A: `@MainActor final class A: XCTestCase` in einer Zeile; Base: XCTestCase mit `class func`/`class var`; `final class Sub: Base`; `class Help` ohne Basis mit `func testNot`; `class Other: NSObject`; `@available(iOS 17, *) public final class Tail : XCTestCase { func testT() {} }`; Mac-only-Datei): weights = A 2, Base 0, Sub 2 (Vererbung erkannt), MacOnly 0; Help und Other (keine XCTestCase) korrekt ausgeschlossen; `class func`/`class var` nicht als Klasse gelesen; mehrere Klassen je Datei und Test nach einer Helper-Klasse (Help vor Tail) richtig zugeordnet. Neue Randfälle: (e1) Tail (alles in einer Zeile, `func` nicht am Zeilenanfang) bekommt Gewicht 0, weil die TEST-Regex `^\s*...func test` verlangt; Ein-Zeilen-Klassen sind bei SwiftFormat/Projektstil nicht zu erwarten, kein heutiger Defekt, LOW, nicht blockierend. (e2) N größer als Anzahl Klassen mit Tests: matrix bricht mit `part 3 has no class with tests to run` ab statt leeres ONLY zu liefern; N=0 bricht mit `N must be at least 1` ab.
(b) F002: `ui_smoke_shards.py 4` am echten Verzeichnis: Teile 1 bis 4 nicht leer; `classes` enthält alle Klassen (inkl. MacDetailClickTests, MacGalleryTests, MacKeyboardTests, MacStoreScreenshotsTests in Teil 3); `only` enthält keinen dieser vier Namen; AccountSettingsTests, SettingsSmokeTests und StartScreenInteractionTests (nur teilweise unter `#if os(macOS)`, iOS-Tests vorhanden) bleiben korrekt in `only`; DesignGalleryTests (Teil 3) und StoreScreenshotsTests (Teil 4) getrennt.
(c) AC-1 bis AC-5 grün (siehe Lauf oben; neue Tests test_f001_..., test_f002_... in scripts/test_ui_smoke_shards.py).
(d) Regression: `grep ui-smoke` im Repo (ohne docs/artifacts): keine alten Verweise auf einen Einzeljob ausser historische docs/context-Notizen; CLAUDE.md:244-249 und scripts/test_ci_settle_sync.py:7, scripts/test_sim_lock.py:262-274 nennen `ui-smoke-shard` (F004 behoben).
**Implementierer:** (nicht beteiligt)

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/ui_smoke_shards.py:20
  Status: BEHOBEN (Runde 3, Probe a)
  Description: Die CLASS-Regex erkennt nur `class X: XCTestCase` (optional final) am Zeilenanfang. Ein Attribut in derselben Zeile und Unterklassen einer eigenen Basisklasse werden nicht erkannt (Probe belegt). Heute kommt beides nicht vor.
  Spec requirement: AC-1 und ADR-Rationale — eine neue Testklasse darf nie still ausfallen
  Conflict: Eine künftige Klasse in dieser Schreibweise fiele aus der CI; der AC-1-Test (scripts/test_ui_smoke_shards.py:22) nutzt dieselbe Regex und merkt es nicht.
  Remediation: Regex für Attribute/Basisklassen erweitern oder Wächter-Test: jede `class …:` in LooseEndsUITests/*.swift muss erkannt werden, sonst rot.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: .github/workflows/ci.yml:239
  Status: BEHOBEN (Runde 3, Probe b; scripts/ui_smoke_shards.py:75)
  Description: Teil 3 übergibt -only-testing für vier Mac-Klassen, die im iOS-Build wegen `#if os(macOS)` nicht existieren; das Spec behauptet "übersprungen". Verhalten von xcodebuild für unbekannte Klassen ist hier nicht belegt.
  Spec requirement: AC-6 — alle vier Teile grün
  Conflict: Bricht xcodebuild bei unbekanntem Test-Bezeichner ab, wird Teil 3 rot. Auf dem PR zu klären, aber vermeidbar.
  Remediation: Gewicht-0-Klassen (Mac-only) nicht in `only` aufnehmen (weiter in `classes` ausweisen), oder im PR-Lauf bestätigen.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: .github/workflows/ci.yml:371
  Status: AKZEPTIERT (LOW; Label xcode-27 wird von bestehendem Test für jeden Job verlangt; Risiko pending statt rot auf dem PR beobachten)
  Description: Sammel- und Plan-Job nutzen das knappe macOS-Label mit Checkout und Xcode-Auswahl; ein Linux-Runner genügt. Außerdem führt leeres ONLY (N größer als Klassenzahl, ci.yml:239) zum Lauf des ganzen Targets.
  Spec requirement: Risiko — Sammelprüfung darf nie blockieren oder durchrutschen
  Conflict: Zusätzliche Queue-Abhängigkeit; leeres ONLY nur bei Erhöhung von N relevant.
  Remediation: Sammel-Job auf ubuntu-latest ohne Checkout; Skript bricht ab, wenn N größer als Klassenzahl.

Finding:
  ID: F004
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/test_ci_xcode27.py:131
  Status: BEHOBEN (Runde 3; scripts/test_ci_settle_sync.py:7, scripts/test_sim_lock.py:262)
  Description: Docstring scripts/test_ci_settle_sync.py:7 und Meldungen in scripts/test_sim_lock.py:268-270 nennen noch "ui-smoke" statt "ui-smoke-shard".
  Spec requirement: keine
  Conflict: Irreführende Fehlermeldungen.
  Remediation: Texte anpassen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/ui_smoke_shards.py:43
  Evidence: 31 Dateien gelesen, jede Klasse genau einem Teil, Watch/ nicht durchsucht (glob ohne Rekursion); Test grün; Einschränkung F001.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/ui_smoke_shards.py:19
  Evidence: Bei N=4 vier nicht leere Teile; DesignGalleryTests in Teil 3, StoreScreenshotsTests in Teil 4; Sonderregel in split.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/test_ui_smoke_shards.py:55
  Evidence: Sortierung nach (-Gewicht, Name), Tie-Break per Index; zwei Aufrufe identisch; neue Klasse im Temp-Verzeichnis zugeordnet.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/test_ui_smoke_shards.py:67
  Evidence: Summen 29/29/28/29, Durchschnitt 28,75, Maximum 29 nicht größer als 28,75 + 26.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: .github/workflows/ci.yml:371
  Evidence: genau ein Job mit dem Namen "UI Smoke (iOS Simulator)", needs [ui-smoke-shard], if always(), Prüfung RESULT ungleich success führt zu exit 1 (ci.yml:386); Plan-Fehler führt zu skipped und damit rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: .github/workflows/ci.yml:131
  Evidence: Auf PR nachzuweisen. Aufbau tauglich: Matrix aus fromJSON, fail-fast false, Grenzen 60/45 min, Schritte unverändert.
  Status: CONFIRMED (Aufbau; Messung steht auf dem PR aus)

Confirmation:
  AC: AC-7
  Code reference: .github/workflows/ci.yml:383
  Evidence: Auf PR nachzuweisen. Logik: failure, cancelled, skipped führen zu RESULT ungleich success und damit rot.
  Status: CONFIRMED (Logik; rote Probe steht auf dem PR aus)

Confirmation:
  AC: AC-8
  Code reference: .github/workflows/ci.yml:352
  Evidence: Artefakte DesignGallery-<n> und UITestResults-<n> je Teil, Export toleriert fehlende Bilder; Teil 3 enthält DesignGalleryTests. Nicht-leer-Beleg auf PR.
  Status: CONFIRMED (Aufbau)

Weitere Dateien (Abdeckung):
Code reference: .github/actions/prepare-ui-simulator/action.yml:3
Code reference: CLAUDE.md:244
Code reference: scripts/test_sim_lock.py:262
Code reference: scripts/test_ci_xcode27.py:135
Code reference: scripts/test_ui_smoke_shards.py:85

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

F001, F002, F004 behoben und belegt; F003 akzeptiert (LOW). Neu nur e1 (Ein-Zeilen-Klasse, LOW, nicht blockierend).
Proven points: AC-1 bis AC-5 bewiesen; AC-6 bis AC-8 nur Aufbau tauglich, Nachweis auf dem PR (Definition: auf PR nachzuweisen).
Tests: 731 passed, 0 failed, 1 übersprungen (scripts/test_asc_crashes.py:355, unabhängig von #910)
Regressions: keine gefunden.

Code reference: scripts/ui_smoke_shards.py:20
Code reference: scripts/ui_smoke_shards.py:75
Code reference: scripts/test_ui_smoke_shards.py:74
Code reference: scripts/test_ci_settle_sync.py:7
Code reference: scripts/test_sim_lock.py:262
Code reference: scripts/test_ci_xcode27.py:131
Code reference: .github/workflows/ci.yml:239
Code reference: .github/actions/prepare-ui-simulator/action.yml:3
Code reference: CLAUDE.md:244

## Geprüfte Dateien

- sha256:fba6da164bc2653764fb6175b12fc4d65231dd5485e0bc1500a57a0d52773254  .github/actions/prepare-ui-simulator/action.yml
- sha256:5ddda20ecce0f2cf61f6dc9a99be20fab922967a274ae6177c2b66b8a1547e5a  .github/workflows/ci.yml
- sha256:29b987f33b2dfadedf99f51eaf6732f7017bfb36b1813bc644e660007cfe261c  CLAUDE.md
- sha256:2401917ebe962b9a30c6f41cbc8ac3d9b698abee8e643f0989890af3e7c50772  scripts/test_ci_settle_sync.py
- sha256:a111e3b9c7ace265a209ab9f1580a92680caa36031b9096b65c36b7d44dfd39b  scripts/test_ci_xcode27.py
- sha256:89eced9fa9f5a81fd232eed3990c3208422f321e70cad721495a5d2259e489dc  scripts/test_sim_lock.py
- sha256:eb1455902a8a708f62600400b780eadb9039d700c41bb71103d0fa89c4d91403  scripts/test_ui_smoke_shards.py
- sha256:a89a50f1a8f5556d115f8335e01449e62b82463ceb4750f4440bed3b6fde5f83  scripts/ui_smoke_shards.py

## Prüfbasis

- base: 36aac30375b718bdcdb22b90638b3b71744d1d18
- blob:ece15828c7982544dbfa8db4fe8c9b58dd1e20b4  .github/actions/prepare-ui-simulator/action.yml
- blob:f8bec764fa38f8ed27e46322cde27d5865fdc37d  .github/workflows/ci.yml
- blob:3c2733ba988c9e438ae6b4466453123b7dc88760  CLAUDE.md
- blob:a94180bec022fced4f175045d1cbc4768918665a  scripts/test_ci_settle_sync.py
- blob:503d1e2fb06628e9d71df6782416d801a8ac6d6d  scripts/test_ci_xcode27.py
- blob:e863577b16433726fd83d6c91fa81a783ce2d997  scripts/test_sim_lock.py
- blob:15e84eb9989e521dc1e8d9de82994f0f8592423f  scripts/test_ui_smoke_shards.py
- blob:740c312c65d81ba49cd31242b5547858618564c6  scripts/ui_smoke_shards.py

## Geprüfte Dateien

- sha256:fba6da164bc2653764fb6175b12fc4d65231dd5485e0bc1500a57a0d52773254  .github/actions/prepare-ui-simulator/action.yml
- sha256:5ddda20ecce0f2cf61f6dc9a99be20fab922967a274ae6177c2b66b8a1547e5a  .github/workflows/ci.yml
- sha256:29b987f33b2dfadedf99f51eaf6732f7017bfb36b1813bc644e660007cfe261c  CLAUDE.md
- sha256:2401917ebe962b9a30c6f41cbc8ac3d9b698abee8e643f0989890af3e7c50772  scripts/test_ci_settle_sync.py
- sha256:a111e3b9c7ace265a209ab9f1580a92680caa36031b9096b65c36b7d44dfd39b  scripts/test_ci_xcode27.py
- sha256:89eced9fa9f5a81fd232eed3990c3208422f321e70cad721495a5d2259e489dc  scripts/test_sim_lock.py
- sha256:eb1455902a8a708f62600400b780eadb9039d700c41bb71103d0fa89c4d91403  scripts/test_ui_smoke_shards.py
- sha256:a89a50f1a8f5556d115f8335e01449e62b82463ceb4750f4440bed3b6fde5f83  scripts/ui_smoke_shards.py

## Prüfbasis

- base: 36aac30375b718bdcdb22b90638b3b71744d1d18
- blob:ece15828c7982544dbfa8db4fe8c9b58dd1e20b4  .github/actions/prepare-ui-simulator/action.yml
- blob:f8bec764fa38f8ed27e46322cde27d5865fdc37d  .github/workflows/ci.yml
- blob:3c2733ba988c9e438ae6b4466453123b7dc88760  CLAUDE.md
- blob:a94180bec022fced4f175045d1cbc4768918665a  scripts/test_ci_settle_sync.py
- blob:503d1e2fb06628e9d71df6782416d801a8ac6d6d  scripts/test_ci_xcode27.py
- blob:e863577b16433726fd83d6c91fa81a783ce2d997  scripts/test_sim_lock.py
- blob:15e84eb9989e521dc1e8d9de82994f0f8592423f  scripts/test_ui_smoke_shards.py
- blob:740c312c65d81ba49cd31242b5547858618564c6  scripts/ui_smoke_shards.py
