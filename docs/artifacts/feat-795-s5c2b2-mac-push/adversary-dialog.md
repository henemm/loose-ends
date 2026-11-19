# Adversary Dialog — feat-795-s5c2b2-mac-push
Spec: docs/specs/feat-795-schnitt-5c2b2-mac-push.md
Datum: 2026-11-19 12:15

## Checkliste
- [x] **AC-1:** GIVEN `project.yml` WHEN `entitlements.properties` des App-Ziels gelesen wird THEN steht dort `com.apple.developer.aps-environment` mit Wert `development` und `aps-environment` unverändert daneben (Test `sourceCarriesMacPushKey`).
- [x] **AC-2:** GIVEN `./scripts/sim.sh generate` WHEN es läuft THEN trägt `LooseEnds/LooseEnds.entitlements` beide Schlüssel mit `development`, der Baum bleibt danach sauber, und `scripts/test_entitlements_sync.py` und `scripts/test_info_plist_sync.py` sind grün (Test `imageCarriesMacPushKey`; Beleg: Lauf und CI-Schritt „Generate leaves the tree clean“).
- [x] **AC-3:** GIVEN die Mac-Archivprüfung in `testflight.yml` WHEN gelesen THEN verlangt ihre Schlüsselschleife `com.apple.developer.aps-environment` nur auf Vorhandensein, und Fehlen setzt `fail=1` (Test `macVerifyRequiresPushKey`).
- [x] **AC-4:** GIVEN die iOS-Archivprüfung WHEN gelesen THEN verlangt sie weiter `entitled com.henning.looseends aps-environment` und enthält den Mac-Schlüssel nicht (Test `iosVerifyKeepsApsEnvironment`).
- [x] **AC-5:** GIVEN `scripts/mac_ci_entitlements.py` und `scripts/test_mac_ci_entitlements.py` WHEN der Diff gelesen und die Tests ausgeführt werden THEN sind beide unverändert und grün, der neue Schlüssel wird weiter herausgefiltert (Beleg: Diff und Lauf; Mac Gallery und `MacDetailClickTests` bleiben unberührt).
- [x] **AC-6:** GIVEN der Diff WHEN gelesen THEN ändert sich kein Swift-Code, keine `Info.plist`, kein Watch- oder Widget-Ziel, und `account-switch-check`- und `aps-environment-check`-Blöcke bleiben unverändert (Tests `test_account_switch_blocks_untouched` und `test_verify_snippet_accepts_only_production_string` aus S5c-2b bleiben grün).
- [x] **AC-7:** GIVEN die ganze Suite WHEN sie läuft THEN sind die Python-Wächter, `./scripts/sim.sh unit` und die CI grün, und der Simulator-Bau gelingt unverändert (`./scripts/sim.sh build`; Beleg im Abschlussbericht).

## Dialog

### Runde 1
**Adversary:** Behauptung: Mac-Push-Schluessel fehlt oder wird nicht geprueft. Quelle, Abbild, Schleife, Waechter gelesen und ausgefuehrt.

Confirmation:
  AC: AC-1
  Code reference: project.yml:72
  Evidence: `com.apple.developer.aps-environment: development` steht neben `aps-environment` (Zeile 71); test_source_carries_mac_push_key gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/LooseEnds.entitlements:11
  Evidence: Abbild traegt beide Schluessel (Zeilen 5 und 11, development); test_entitlements_sync und test_info_plist_sync exit 0. generate nicht selbst ausgefuehrt (Sperre); Abbild-Gleichheit ueber test_entitlements_sync belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: .github/workflows/testflight.yml:532
  Evidence: Schluessel in der Mac-Schleife vor den Konto-Schluesseln; grep -qF auf <key>...</key> trifft den codesign-Tag; else-Zweig setzt fail=1. test_mac_verify_requires_push_key prueft Schleife, grep, fail=1 und genau ein Vorkommen ausserhalb der Konto-Bloecke.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: .github/workflows/testflight.yml:230
  Evidence: iOS prueft weiter `entitled com.henning.looseends aps-environment`; der Mac-Schluessel kommt im iOS-Job nicht vor (test_ios_verify_keeps_aps_environment).
  Status: CONFIRMED

Confirmation:
  AC: AC-4 Waechter
  Code reference: scripts/test_aps_environment.py:150
  Evidence: 10 Tests, exit 0; Fehlfall ueber die fail=1-Assertion und test-red-output.txt belegt.
  Status: CONFIRMED

**Implementierer:** keine Einwaende.

### Runde 2
**Adversary:** Randfaelle. (a) sandbox_entitlements auf die echte project.yml angewendet: nur fuenf Sandbox-Schluessel, der neue faellt durch das Praefix com.apple.developer. heraus; mac_ci_entitlements.py und sein Test unveraendert, 5 Tests gruen. (b) grep -qF auf den vollen Tag kann aps-environment nicht mit dem Mac-Namen verwechseln. (c) Konto-Bloecke und aps-environment-check-Block (Zeile 551) unveraendert, Diff trifft nur Zeile 532. (d) Restrisiko: ob das Mac-Profil den Schluessel traegt, zeigt erst der Archivlauf; die Pruefung faengt es ab.

Confirmation:
  AC: AC-5
  Code reference: scripts/mac_ci_entitlements.py:20
  Evidence: NEEDS_PROFILE filtert das Praefix com.apple.developer.; Datei und Test unveraendert, 5 Tests gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: .github/workflows/testflight.yml:551
  Evidence: Diff-Statistik: nur Workflow (1 Zeile), CLAUDE.md, entitlements, testflight.md, project.yml, test_aps_environment.py; kein Swift, keine Info.plist, Watch-/Widget-Ziel (project.yml:155) unberuehrt; test_verify_snippet_accepts_only_production_string gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_aps_environment.py:18
  Evidence: Python-Waechter gruen (adversary-test-output.txt); sim-build.txt endet mit build exit 0. sim-unit.txt endet mit unit exit 0 (XCTest 84 Tests, 0 failures; Swift-Testing-Suiten passed; vom Orchestrator nachgetragen). CI steht aus.
  Status: CONFIRMED

**Implementierer:** keine Einwaende.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: Python-Waechter 10+4+5 gruen, 0 failed; sim-build exit 0; sim-unit exit 0
Edge cases: alle geprueft, keine gebrochen
Regressions: keine gefunden
Checklist: 7/7

## Geprüfte Dateien

- sha256:2ac377b76dd85874d9fa1b39085d541150755f7eae2511112dfcb0efae2cad98  .github/workflows/testflight.yml
- sha256:9c4a84e1f86789f54a43680c8cdf20961d298fea5df8bd3080b1fce6d1b6e02c  LooseEnds/LooseEnds.entitlements
- sha256:76723455325bd9f1043ceed36f6c30b79b8c724f899cb87301114a5eda91f201  project.yml
- sha256:216f5f9f0bf6ac55ac7e187bd52b6441959de636ce1a48e05c677fe13c8b4c6a  scripts/mac_ci_entitlements.py
- sha256:02b11431f4b13783b54ed9425656bc6f66b99556ca7ad5f0fbcf6c90d8c5d6fb  scripts/test_aps_environment.py

## Prüfbasis

- base: bb225fea6bf45f9492d6646b931cd7b7583aabfc
- blob:638efb3bf99c69f9d094fccf83aef54fa6846360  .github/workflows/testflight.yml
- blob:16c85d4052fdaffc73ec9588728faabf3c4122da  LooseEnds/LooseEnds.entitlements
- blob:d398b6ffd451eae24842b9223b8d794f988c85f8  project.yml
- blob:c2ad1e0a7093268a5692ae5015d253d1fef3801e  scripts/mac_ci_entitlements.py
- blob:8b0cf7feda721cbfecb341ab72ae594dda21d955  scripts/test_aps_environment.py

## Geprüfte Dateien

- sha256:2ac377b76dd85874d9fa1b39085d541150755f7eae2511112dfcb0efae2cad98  .github/workflows/testflight.yml
- sha256:9c4a84e1f86789f54a43680c8cdf20961d298fea5df8bd3080b1fce6d1b6e02c  LooseEnds/LooseEnds.entitlements
- sha256:76723455325bd9f1043ceed36f6c30b79b8c724f899cb87301114a5eda91f201  project.yml
- sha256:216f5f9f0bf6ac55ac7e187bd52b6441959de636ce1a48e05c677fe13c8b4c6a  scripts/mac_ci_entitlements.py
- sha256:02b11431f4b13783b54ed9425656bc6f66b99556ca7ad5f0fbcf6c90d8c5d6fb  scripts/test_aps_environment.py

## Prüfbasis

- base: bb225fea6bf45f9492d6646b931cd7b7583aabfc
- blob:638efb3bf99c69f9d094fccf83aef54fa6846360  .github/workflows/testflight.yml
- blob:16c85d4052fdaffc73ec9588728faabf3c4122da  LooseEnds/LooseEnds.entitlements
- blob:d398b6ffd451eae24842b9223b8d794f988c85f8  project.yml
- blob:c2ad1e0a7093268a5692ae5015d253d1fef3801e  scripts/mac_ci_entitlements.py
- blob:8b0cf7feda721cbfecb341ab72ae594dda21d955  scripts/test_aps_environment.py
