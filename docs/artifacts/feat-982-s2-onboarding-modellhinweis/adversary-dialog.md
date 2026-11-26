# Adversary Dialog — feat-982-s2-onboarding-modellhinweis
Spec: docs/specs/enrichment/feat-982-schnitt-2-onboarding-ohne-modellhinweis.md
Datum: 2026-11-26 20:19

## Checkliste
- [x] **AC-1:** Schritt 1 des Onboardings zeigt keinen Modellhinweis, auch nicht mit dem früheren Testargument `--ui-testing-model-reason=…` (Test 1, Screenshot geöffnet und beschrieben).
- [x] **AC-2:** Im App- und Unit-Test-Code gibt es keine `ModelNote`, kein `modelNote`, kein `modelUnavailableReason` außerhalb der Labor-App, kein `onboardingModelReason` und kein `--ui-testing-model-reason`: `grep -rn "ModelNote\|modelNote\|onboardingModelReason\|ui-testing-model-reason" LooseEnds Shared LooseEndsTests` ist leer. In `LooseEndsUITests` steht das frühere Argument nur noch in `OnboardingTests`, die es für AC-1 absichtlich übergibt.
- [x] **AC-3:** `Localizable.xcstrings` enthält die drei Schlüssel „Apple Intelligence is off. …“, „Apple Intelligence is still getting ready. …“ und „This device has no Apple Intelligence. …“ nicht mehr; der Katalogwächter ist grün.
- [x] **AC-4:** Durchlauf und Überspringen des Onboardings funktionieren unverändert; alle übrigen Tests grün (Tests 2, 3).

## Dialog

### Runde 1
**Adversary:** Beweise je AC. AC-1: Screenshot simulator-run/0538FA8D-....png geöffnet: Schritt 1 zeigt Mikrofon-Symbol, Titel "Capture without opening the app", Siri-Text, Skip, Continue; kein Hinweistext zu Apple Intelligence. Der Test startet mit Argument reason "deviceNotEligible" und prüft Fehlen von onboardingModelNote und jedes Textes mit "Apple Intelligence". Gefahr: Test grün, weil Argument ignoriert wird - dann aber genau das Ziel (RED lief gegen 6d8bbc1).
**Implementierer:** simulator-run.txt: 3/3 bestanden, 0 übersprungen; test-red-output.txt belegt RED vorher.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/OnboardingView.swift:13
  Evidence: body beginnt mit stepContent, der bedingte modelNote-Block ist entfernt (Diff); Screenshot ohne Hinweis.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/OnboardingFlow.swift:40
  Evidence: ModelNote-Enum und modelNote(for:) entfernt; grep ModelNote|modelNote|onboardingModelReason|ui-testing-model-reason über LooseEnds Shared LooseEndsTests leer; in LooseEndsUITests nur OnboardingTests.swift (Zeilen 15, 77, 81, absichtlich). modelUnavailableReason in ContentView entfernt: LooseEnds/App/ContentView.swift:213 ruft OnboardingView ohne Grund auf; einziger Aufrufer.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Resources/Localizable.xcstrings:396
  Evidence: die drei Schlüssel sind im Diff gelöscht, grep im Quellcode zeigt keine Verwendung; test_catalog_languages.py: 9 Tests OK (selbst gelaufen); test_onboarding_ohne_modell.py: 2 OK.
  Status: CONFIRMED

### Runde 2
**Adversary:** Edge Cases: (a) Deutsch: Hinweis nur über Katalogschlüssel, Schlüssel samt de-Übersetzung entfernt, kein Rest. (b) Mac: nur ein Aufrufer von OnboardingView, keine #if-Zweige mit Resten (grep leer). (c) Durchlauf/Überspringen: Buttons und OnboardingFlow.advance/finish unverändert im Diff; unit-all.txt 105 Tests, 0 Fehler; UI 3/3. (d) Verwaiste Doku: docs/reference/modell-verfuegbarkeit.md:36 nennt noch OnboardingFlowTests.modelNote.
**Implementierer:** Doku ist historischer Bestand.

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEnds/Views/OnboardingFlow.swift:8
  Description: Der Code ist sauber, aber docs/reference/modell-verfuegbarkeit.md:36 verweist noch auf den gelöschten Test OnboardingFlowTests.modelNote.
  Spec requirement: AC-2 - Code ohne Hinweis (Doku nicht gefordert)
  Conflict: Nur veralteter Verweis in einer Referenzdoku, kein Verhalten betroffen.
  Remediation: Verweis bei Gelegenheit streichen (nicht blockierend).

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/App/ContentView.swift:215
  Evidence: onFinish und requestNotifications unverändert verdrahtet; Tests Durchlauf und Überspringen grün (3/3).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
Tests: 3 UI bestanden, 105 Unit bestanden, 0 fehlgeschlagen, 0 übersprungen; Python 2+9 OK
Edge cases: alle geprüft, nichts gebrochen (F001 LOW, Doku-Verweis)
Regressions: keine
Checklist: 4/4 proven

## Geprüfte Dateien

- sha256:74950e14aeff08ffacfebee3498e94a7b769cb0e10709c8176e539d135220871  LooseEnds/App/ContentView.swift
- sha256:69d771ff75b273fc12a9900ea01d3a61ffb7b654c7a203c4cea77e682722694c  LooseEnds/Resources/Localizable.xcstrings
- sha256:9de051af40eec9fdb9b3f609424f02ad7e63d4000db91e14bc7e575aa8171abb  LooseEnds/Views/OnboardingFlow.swift
- sha256:523182c529ea8ca6d9d5bb9ae39c9d34e2479d372158ea1860c177795f8f37e4  LooseEnds/Views/OnboardingView.swift

## Prüfbasis

- base: 7e2dff6d752da789e3cd9965152e1a44ffef1ebc
- blob:540770fcf1cda967d54d53361525290c08e3d13a  LooseEnds/App/ContentView.swift
- blob:f720d43de4e9644728c9b38f9f15d4f71bce8576  LooseEnds/Resources/Localizable.xcstrings
- blob:236f7e1b2cd16f10d51fe1e54e64fa52a9e7fa5e  LooseEnds/Views/OnboardingFlow.swift
- blob:14a5cc56eb6bb6edf6c54a3322cdb2f0d6638977  LooseEnds/Views/OnboardingView.swift

## Geprüfte Dateien

- sha256:74950e14aeff08ffacfebee3498e94a7b769cb0e10709c8176e539d135220871  LooseEnds/App/ContentView.swift
- sha256:69d771ff75b273fc12a9900ea01d3a61ffb7b654c7a203c4cea77e682722694c  LooseEnds/Resources/Localizable.xcstrings
- sha256:9de051af40eec9fdb9b3f609424f02ad7e63d4000db91e14bc7e575aa8171abb  LooseEnds/Views/OnboardingFlow.swift
- sha256:523182c529ea8ca6d9d5bb9ae39c9d34e2479d372158ea1860c177795f8f37e4  LooseEnds/Views/OnboardingView.swift

## Prüfbasis

- base: 7e2dff6d752da789e3cd9965152e1a44ffef1ebc
- blob:540770fcf1cda967d54d53361525290c08e3d13a  LooseEnds/App/ContentView.swift
- blob:f720d43de4e9644728c9b38f9f15d4f71bce8576  LooseEnds/Resources/Localizable.xcstrings
- blob:236f7e1b2cd16f10d51fe1e54e64fa52a9e7fa5e  LooseEnds/Views/OnboardingFlow.swift
- blob:14a5cc56eb6bb6edf6c54a3322cdb2f0d6638977  LooseEnds/Views/OnboardingView.swift
