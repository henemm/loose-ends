# Adversary Dialog — feat-355-s1-siri-saetze-watch
Spec: docs/specs/intents/feat-355-s1-siri-saetze-watch.md
Datum: 2026-10-13 16:51

## Checkliste
- [x] **AC-1:** Neuer Satz im Code — `LooseEndsShortcuts` enthält fünf Sätze, darunter `"Capture with \(.applicationName)"`. Nachweis: `scripts/test_siri_phrases.py` (Test 1) und Diff.
- [x] **AC-2:** Katalog vollständig — `AppShortcuts.xcstrings` hat für jeden der fünf Sätze genau einen Schlüssel mit deutscher Übersetzung (`translated`), der neue lautet „Erfasse in ${applicationName}“, und es gibt keinen veralteten Schlüssel. Nachweis: `test_siri_phrases.py` grün, davor nachweislich rot.
- [x] **AC-3:** Watch-Target führt die Ressourcen — `LooseEndsWatch` bindet `AppShortcuts.xcstrings`, `Localizable.xcstrings` und `*.lproj/InfoPlist.strings` aus `LooseEnds/Resources` ein (ohne Kopie, ohne Assets). Nachweis: `test_siri_phrases.py` (Test 3).
- [x] **AC-4:** Ersatznamen im Watch-Info.plist — Das Watch-`Info.plist` enthält `CFBundleSpokenName` und `INAlternativeAppNames` mit denselben `LE_ALT_*`-Variablen wie iOS, und die Watch-Berechtigungen in `project.yml` (und damit `LooseEndsWatch.entitlements`) enthalten `com.apple.developer.siri: true` wie die App. Nachweis: `test_siri_phrases.py` (erst rot, dann grün), `test_entitlements_sync.py` grün, Diff von `project.yml`.
- [x] **AC-5:** Watch-Bundle enthält Deutsch (Stufe 2) — Das gebaute Watch-Paket enthält `de.lproj/AppShortcuts.strings` mit allen fünf deutschen Sätzen, `de.lproj/Localizable.strings` und `de.lproj/InfoPlist.strings` (de und en); die gebaute `Info.plist` enthält `CFBundleSpokenName` und `INAlternativeAppNames`. Kein `root.ssu.yaml` erwartet: Xcode führt den Schritt `AppIntentsSSUTraining` (Daten für flexibles Satz-Matching) für das Watch-Target nicht aus, passend zu WWDC23 10102 („Flexible matching with Siri is not available on Apple Watch“). Nachweis: Paketinspektion nach watchOS-Simulatorbau, Bauprotokoll ohne SSU-Schritt für `LooseEndsWatch`.
- [x] **AC-6:** iPhone-Bundle trägt den neuen Satz (Stufe 2) — Das gebaute iPhone-Paket enthält „Erfasse in ${applicationName}“ in `de.lproj/AppShortcuts.strings`. Nachweis: Paketinspektion.
- [x] **AC-7:** CI sichert das Watch-Bundle ab — Die Archivprüfung in `testflight.yml` prüft je Bundle, und für die Watch `de.lproj`, die fünf deutschen Sätze und die Siri-Namen in `InfoPlist.strings` (de/en); der neue Satz steht auch in der iPhone-Prüfung; die Siri-Berechtigung wird für App und Watch im signierten Bundle verlangt. Nachweis: Diff und `scripts/test_ci_xcode27.py` grün; der Archivlauf selbst ist der Beleg im TestFlight-Bau.
- [x] **AC-8:** Bestehendes bleibt grün — `./scripts/sim.sh unit`, `test_entitlements_sync.py`, `test_ci_xcode27.py` bestehen. Nachweis: Lauf-Ausgaben.

## Dialog

### Runde 1
**Adversary:** Alle 8 ACs einzeln gegen Code, Diff und Rohlauf geprüft (Ausgaben in adversary-test-output.txt). Skeptisch: (a) Spec-Ehrlichkeit - der Abschnitt 'Gerätebefund' nennt Watch-Siri ausdrücklich nicht erfüllt (Build 52/54, 'Los Angeles'/'Dose Enden'), 'Was dieser Schnitt ausliefert' beschränkt sich auf Paketinhalt und iPhone/Mac-Satz; nirgends steht, Watch-Siri funktioniere. Purpose und Definition of Done formulieren noch das Ziel ('soll ... verstehen', 'Satz sprechen, Rückfrage, Speichern' im TestFlight-Text), stehen aber im Zusammenhang mit dem Gerätebefund; kein Widerspruch, nur LOW-Hinweis. (b) Hat 'Erfasse in' wirklich nur 1 Schlüssel? Ja, Katalog 5 Schlüssel/5 Sätze. (c) Stufe-2-Behauptung 'kein root.ssu.yaml' wird durch Bauprotokoll (kein SSU für LooseEndsWatch) belegt. (d) Archivbelege Build 54 zeigen signierte Watch-Berechtigung und alle Zeilen.
**Implementierer:** Belege vorhanden: test_siri_phrases 6 ok, entitlements 4 ok, ci_xcode27 17 ok, bash -n rc 0, Unit 574 grün.

### Runde 2
**Adversary:** Zweite Runde, Angriff auf Regressionen: CaptureTextIntent.swift nur +1 Zeile (Satz); testflight.yml-Refactor verschiebt Siri-Prüfung für App aus dem if-Block in Funktionen und behält Prüfung für iPhone (Archiv Build 54: iPhone-Zeilen vollständig, widgets/share ohne Siri-Zeilen wie zuvor). Fehlerpfad: fehlt ein Text, setzt fail=1 und gibt ::error:: aus (Code gelesen). Watch-Berechtigung nicht in AC-4 verwechselt: entitlements und project.yml konsistent (Sync-Test grün). Kein Befund; Frühkonvergenz geprüft durch eigene Läufe und Codelesung, nicht durch Übernahme der Vorberichte.
**Implementierer:** Keine Änderung nötig.

Confirmation:
  AC: AC-1
  Code reference: Shared/Intents/CaptureTextIntent.swift:50
  Evidence: Fuenfter Satz "Capture with \(.applicationName)" in LooseEndsShortcuts; test_siri_phrases Test 1 ok.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Resources/AppShortcuts.xcstrings:8
  Evidence: Schluessel mit de 'Erfasse in ${applicationName}', state translated; 5 Sätze = 5 Schlüssel, kein veralteter (test_stale_key_is_reported ok; RED-Läufe test-red-output*.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: project.yml:115
  Evidence: Watch-Target bindet LooseEnds/Resources mit includes AppShortcuts, Localizable, *.lproj/InfoPlist.strings; keine Kopie, keine Assets.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsWatch/Info.plist:21
  Evidence: CFBundleSpokenName + INAlternativeAppNames mit LE_ALT_*; project.yml:130,147 und LooseEndsWatch/LooseEndsWatch.entitlements:15 com.apple.developer.siri true; test_entitlements_sync ok.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsWatch/Info.plist:30
  Evidence: bundle-inspection.txt: Watch-Paket de.lproj mit Sätzen, Spoken/Alt-Namen; SSU-Schritt nur fuer Widgets/Share/App, nicht Watch (Zeile 133-138); Build 54 Archiv bestaetigt de.lproj/en.lproj mit 5 Sätzen.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Resources/AppShortcuts.xcstrings:8
  Evidence: bundle-inspection.txt Zeile 114/124 iPhone-Paket enthält 'Erfasse in'; Archiv Build 54 iPhone-Zeile vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_siri_phrases.py:1
  Evidence: testflight.yml: siri_phrases/siri_names je Bundle inkl. watchkitapp, 5 Sätze, Siri-Berechtigung fuer App+Watch (Zeilen 182-260); bash -n rc 0, test_ci_xcode27 17 ok; Archivlauf Build 54 zeigt alle Zeilen vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_siri_phrases.py:1
  Evidence: test_entitlements_sync 4 ok, test_ci_xcode27 17 ok, test_siri_phrases 6 ok; unit-run-4.log 574 Tests grün, seit b1d2f12 kein Swift geändert (nur eine Zeile in CaptureTextIntent.swift, vorher enthalten).
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: .github/workflows/testflight.yml:182
  Evidence: siri_phrases/siri_names-Funktionen, Schleife ueber vier Bundles inkl. com.henning.looseends.watchkitapp, Siri-Berechtigungsprüfung fuer App und Watch.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Confirmation:
  AC: AC-4
  Code reference: LooseEndsWatch/LooseEndsWatch.entitlements:15
  Evidence: com.apple.developer.siri true im erzeugten Watch-Entitlements.
  Status: CONFIRMED

Finding F001 (LOW, nur Hinweis, kein Blocker): Purpose-Abschnitt formuliert das Watch-Siri-Ziel im Präsens/Soll; durch Abschnitt 'Gerätebefund' ehrlich eingeschränkt.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:d187890d866cd93b044c8f6339da9acb64e0afbb22ba69c00c2bf51628ce8d88  .github/workflows/testflight.yml
- sha256:1101019ede73f78cf9a0f614a0e2920f06fbe0b1b5a0620b68b15ead7d8a7380  LooseEnds/Resources/AppShortcuts.xcstrings
- sha256:426b9ba05394b786f46545909683586a1d42192a4583226ec1e384310bb54c1e  LooseEndsWatch/Info.plist
- sha256:cfceb41c18af14feffdcbe95a07dbc8c7723a07def0e498f313b7aeb69970592  LooseEndsWatch/LooseEndsWatch.entitlements
- sha256:f2329a391d5e42e57574d956c870a7c4266bb9ad55f531a1e7e753bf0a33b456  Shared/Intents/CaptureTextIntent.swift
- sha256:25f26479e5f252e96cff241c26429c02f465ae417b4219f584ce3499e709109c  project.yml
- sha256:388583d8f88cda23718874fdcd6a14355d0197cc5ff071235afc165c54bf957b  scripts/test_siri_phrases.py

## Prüfbasis

- base: 0fd1938ecd3f1c894875e14e4763c4577f5ac00d
- blob:1cb8b8081493351849db289da1313e53509d6553  .github/workflows/testflight.yml
- blob:96a36de44c4ddf7f45f621519c750526ae0c8b58  LooseEnds/Resources/AppShortcuts.xcstrings
- blob:b125162f9cd715537110099ba58daf0081b58b60  LooseEndsWatch/Info.plist
- blob:e011708df224468e914a5b6ade53c559fced7216  LooseEndsWatch/LooseEndsWatch.entitlements
- blob:899b104d51c7f7e763fa4b8fa5097db7946f5653  Shared/Intents/CaptureTextIntent.swift
- blob:b45614cc47f54e26dd283b024e16372cb593788b  project.yml
- blob:59a3db1eaff9f51e7695c1d276aed342b3e286c4  scripts/test_siri_phrases.py
