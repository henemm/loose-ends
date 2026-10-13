# Adversary Dialog — feat-355-s1-siri-saetze-watch
Spec: docs/specs/intents/feat-355-s1-siri-saetze-watch.md
Datum: 2026-10-13 12:53

## Checkliste
- [x] **AC-1:** Neuer Satz im Code — `LooseEndsShortcuts` enthält fünf Sätze, darunter `"Capture with \(.applicationName)"`. Nachweis: `scripts/test_siri_phrases.py` (Test 1) und Diff.
- [x] **AC-2:** Katalog vollständig — `AppShortcuts.xcstrings` hat für jeden der fünf Sätze genau einen Schlüssel mit deutscher Übersetzung (`translated`), der neue lautet „Erfasse in ${applicationName}“, und es gibt keinen veralteten Schlüssel. Nachweis: `test_siri_phrases.py` grün, davor nachweislich rot.
- [x] **AC-3:** Watch-Target führt die Ressourcen — `LooseEndsWatch` bindet `AppShortcuts.xcstrings`, `Localizable.xcstrings` und `*.lproj/InfoPlist.strings` aus `LooseEnds/Resources` ein (ohne Kopie, ohne Assets). Nachweis: `test_siri_phrases.py` (Test 3).
- [x] **AC-4:** Ersatznamen im Watch-Info.plist — Das Watch-`Info.plist` enthält `CFBundleSpokenName` und `INAlternativeAppNames` mit denselben `LE_ALT_*`-Variablen wie iOS; keine Siri-Berechtigung wird hinzugefügt. Nachweis: `test_siri_phrases.py`, `test_entitlements_sync.py` grün, Diff von `project.yml`.
- [x] **AC-5:** Watch-Bundle enthält Deutsch (Stufe 2) — Das gebaute Watch-Paket enthält `de.lproj/AppShortcuts.strings` mit allen fünf deutschen Sätzen, `de.lproj/Localizable.strings` und `de.lproj/InfoPlist.strings` (de und en); die gebaute `Info.plist` enthält `CFBundleSpokenName` und `INAlternativeAppNames`. Kein `root.ssu.yaml` erwartet: Xcode führt den Schritt `AppIntentsSSUTraining` (Daten für flexibles Satz-Matching) für das Watch-Target nicht aus, passend zu WWDC23 10102 („Flexible matching with Siri is not available on Apple Watch“). Nachweis: Paketinspektion nach watchOS-Simulatorbau, Bauprotokoll ohne SSU-Schritt für `LooseEndsWatch`.
- [x] **AC-6:** iPhone-Bundle trägt den neuen Satz (Stufe 2) — Das gebaute iPhone-Paket enthält „Erfasse in ${applicationName}“ in `de.lproj/AppShortcuts.strings`. Nachweis: Paketinspektion.
- [x] **AC-7:** CI sichert das Watch-Bundle ab — Die Archivprüfung in `testflight.yml` prüft je Bundle, und für die Watch `de.lproj`, die fünf deutschen Sätze und die Siri-Namen in `InfoPlist.strings` (de/en); der neue Satz steht auch in der iPhone-Prüfung; für die Watch wird keine Siri-Berechtigung verlangt. Nachweis: Diff und `scripts/test_ci_xcode27.py` grün; der Archivlauf selbst ist der Beleg im TestFlight-Bau.
- [x] **AC-8:** Bestehendes bleibt grün — `./scripts/sim.sh unit`, `test_entitlements_sync.py`, `test_ci_xcode27.py` bestehen. Nachweis: Lauf-Ausgaben.
- [ ] **AC-9:** Gerät, TestFlight: Satz wird verstanden — Eine deutsche Siri auf Hennings Watch versteht „Erfasse in Loose Ends“ und die übrigen vier deutschen Sätze und startet den Erfassungsablauf. Nachweis: Hennings Rückmeldung zum TestFlight-Bau.
- [ ] **AC-10:** Gerät, TestFlight: Rückfrage und Speichern — Siri fragt auf der Watch nach dem Text und speichert ihn ohne App-Start als Aufgabe, die auf dem iPhone ankommt. Nachweis: Hennings Rückmeldung. Scheitert die Rückfrage (Risiko 1), wird Variante D als neues Ticket angelegt; AC-10 gilt dann als offen und nicht erfüllt.
- [ ] **AC-11:** Gerät, TestFlight: Ersatznamen — Siri erkennt „Loose End“, „LooseEnds“ oder „Lose Enden“ als App-Name auf der Watch, oder der Befund „Ersatznamen ohne Siri-Berechtigung ignoriert“ wird ausdrücklich festgehalten und als Folgeticket (Variante B) angelegt. Nachweis: Hennings Rückmeldung.

## Dialog

### Runde 1
**Adversary:** Ich glaube nichts ungeprueft. Beweise selbst erhoben (siehe docs/artifacts/feat-355-s1-siri-saetze-watch/adversary-test-output.txt):
- test_siri_phrases.py 5/5 OK, test_entitlements_sync.py 4/4 OK, test_ci_xcode27.py 17/17 OK. RED belegt: test-red-output.txt zeigt 3 FAIL (Satz, Watch-Quellen, Watch-Namen) vor der Aenderung.
- Gebaut: Watch neu mit xcodebuild (BUILD SUCCEEDED). Paket: de.lproj/{AppShortcuts,InfoPlist,Localizable}.strings, en.lproj/{InfoPlist,Localizable}.strings; Assets.car enthaelt nur "AppIcon" (Watch-eigen) - `includes` zieht also keine iOS-Assets herein. Info.plist hat CFBundleSpokenName und INAlternativeAppNames (LE_ALT_NAME/HINT_1..3), identisch zu LooseEnds/Info.plist. Keine Entitlements-Datei geaendert (Statusliste des Arbeitsverzeichnisses).
- Bauprotokoll: AppIntentsSSUTraining laeuft nur fuer target LooseEnds, nicht fuer LooseEndsWatch - AC-5 "kein root.ssu.yaml" ist so belegt.
- Edge: Satzformat "Erfasse in ${applicationName}" traegt den App-Namen (Pflicht fuer Siri) - ok. Ersatznamen-Variablen Watch vs iOS: Test 5 vergleicht die Werte aus project.yml, Info.plist-Diff zeigt gleiche Variablen.
- Edge CI: `bash -n` auf dem Siri-Block OK. siri_phrases/siri_names real gegen das gebaute Watch-Paket ausgefuehrt: 5/5 Saetze, 2x4 Namen, fail=0; gegen ein fehlendes Bundle: 5x FEHLT, fail=1 - kein stilles Bestehen. Ein fehlendes Watch-Bundle faengt `check ... watchkitapp` (fail=1), das `|| continue` in der Schleife ist daher unkritisch.
- Edge CI: Siri-Berechtigungspruefung bleibt nur fuer com.henning.looseends (innerhalb des if); Watch bekommt sie nicht verlangt - spec-konform. Kurztitel-/Localizable-Pruefungen bleiben iOS-only (Watch prueft de.lproj generisch) - akzeptabel laut Spec.
**Implementierer:** (Belege aus test-green-output.txt, bundle-inspection.txt, unit-run-4.log bestaetigt.)

### Runde 2
**Adversary:** Nachbohren:
- Unit-Lauf (AC-8): unit-run-4.log "Test run with 572 tests in 88 suites passed", XCTest 7/0, TEST SUCCEEDED. Einschraenkung: FocusBloxCalibrationTests ausgelassen (haengt im Simulator, #395; laeuft in der CI mangels Korpus nicht), Messsuiten uebersprungen - Umgebung, nicht diese Aenderung. LOW (F001), nicht blockierend.
- iPhone-Paket (AC-6): de.lproj/AppShortcuts.strings enthaelt "Capture with ${applicationName}" => "Erfasse in ${applicationName}" plus die vier alten Saetze; Katalog hat 5 Schluessel = 5 Saetze im Code.
- Regression: Der neue Satz wirkt auch auf iPhone/Mac; ein Zusatzsatz bricht keinen Aufrufer (Provider ist deklarativ). Risiko 2 (Rueckfrage Notizen/Loose Ends) ist in der Spec offen benannt, nur am Geraet pruefbar.
- Risiko 1 (Forum 720108, String-Parameter mit requestValueDialog auf watchOS) im Simulator nicht pruefbar -> AC-10.
- AC-9: nachgelagert: Stufe 3, TestFlight
- AC-10: nachgelagert: Stufe 3, TestFlight
- AC-11: nachgelagert: Stufe 3, TestFlight
**Implementierer:** keine weiteren Einwaende.

### Befunde
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_siri_phrases.py:89
  Description: Der Unit-Beleg (unit-run-4.log) lief ohne FocusBloxCalibrationTests und mit uebersprungenen Messsuiten; Test 3 prueft nur project.yml, nicht das gebaute Paket (Paketinspektion habe ich wiederholt).
  Spec requirement: AC-8 - bestehende Laeufe bleiben gruen
  Conflict: Kein Widerspruch, nur Beleglage: Auslassung ist Umgebung (#395), nicht Aenderung.
  Remediation: Keine in diesem Schnitt; #395 verfolgen.

### Bestaetigungen
Confirmation:
  AC: AC-1
  Code reference: Shared/Intents/CaptureTextIntent.swift:50
  Evidence: Fuenfter Satz "Capture with \(.applicationName)" im Provider; Test 1 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Resources/AppShortcuts.xcstrings:8
  Evidence: Schluessel "Capture with ${applicationName}" -> de "Erfasse in ${applicationName}", state translated; 5 Schluessel = 5 Saetze; Test rot->gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: project.yml:119
  Evidence: Watch-Target `path: LooseEnds/Resources` mit includes nur AppShortcuts.xcstrings, Localizable.xcstrings, *.lproj/InfoPlist.strings; gebaute Assets.car enthaelt nur AppIcon.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsWatch/Info.plist:21
  Evidence: CFBundleSpokenName (21) und INAlternativeAppNames (25) mit LE_ALT_*-Variablen wie iOS; project.yml:145 gleiche Eigenschaften; keine Entitlements-Aenderung, test_entitlements_sync 4/4 OK.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: project.yml:145
  Evidence: Neu gebautes Watch-Paket hat de.lproj (AppShortcuts mit 5 Saetzen, InfoPlist, Localizable) und en.lproj/InfoPlist.strings; gebaute Info.plist mit beiden Schluesseln; SSU-Schritt nur fuer target LooseEnds.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Resources/AppShortcuts.xcstrings:8
  Evidence: Debug-iphonesimulator/LooseEnds.app/de.lproj/AppShortcuts.strings enthaelt "Erfasse in ${applicationName}".
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: .github/workflows/testflight.yml:184
  Evidence: siri_phrases (184) und siri_names (200) je Bundle, Aufruf Zeile 256 fuer iPhone und Watch, 5 Saetze inkl. "Erfasse in"; Siri-Berechtigung nur iOS; bash -n OK; Funktionen gegen Watch-Paket (gruen) und fehlendes Bundle (rot) ausgefuehrt; test_ci_xcode27 17/17.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_siri_phrases.py:95
  Evidence: Skripttests OK (5/4/17), unit-run-4.log 572 Tests in 88 Suites passed, XCTest 7/0.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

AC-1 bis AC-8 belegt. Offen nur AC-9, AC-10, AC-11 (Geraetepunkte, Stufe 3 ueber TestFlight nach dem Merge, Hennings Rueckmeldung): nicht belegbar in dieser Phase, kein Befund gegen die Implementierung.

VERDICT: AMBIGUOUS

## Geprüfte Dateien

- sha256:d44065580b0230a15a26288462285c49d28297123af755b46c776345947d74a8  .github/workflows/testflight.yml
- sha256:1101019ede73f78cf9a0f614a0e2920f06fbe0b1b5a0620b68b15ead7d8a7380  LooseEnds/Resources/AppShortcuts.xcstrings
- sha256:426b9ba05394b786f46545909683586a1d42192a4583226ec1e384310bb54c1e  LooseEndsWatch/Info.plist
- sha256:f2329a391d5e42e57574d956c870a7c4266bb9ad55f531a1e7e753bf0a33b456  Shared/Intents/CaptureTextIntent.swift
- sha256:2ff42b52ad1b8c3dc3a93064282c7bafd6393cb68538189e1fd02adc92d11ebd  project.yml
- sha256:95ada293573fc0382b5527d73af554f993f7fadce00f7acb1ceffc71378693ae  scripts/test_siri_phrases.py

## Prüfbasis

- base: fbeeeb9cb8023f2534f64722f5158f5c62ca5e6b
- blob:4431020348a3a1fcffad1762abd9ada39d56fe59  .github/workflows/testflight.yml
- blob:96a36de44c4ddf7f45f621519c750526ae0c8b58  LooseEnds/Resources/AppShortcuts.xcstrings
- blob:b125162f9cd715537110099ba58daf0081b58b60  LooseEndsWatch/Info.plist
- blob:899b104d51c7f7e763fa4b8fa5097db7946f5653  Shared/Intents/CaptureTextIntent.swift
- blob:e07198882c15d0184797ccabc16ec3f415970927  project.yml
- blob:86212a8e6d9206fdf4b8add9287248d0a5797680  scripts/test_siri_phrases.py
