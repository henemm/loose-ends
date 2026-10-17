# Adversary Dialog — feat-511-ci-mac-galerie
Spec: docs/specs/tooling/feat-511-ci-mac-galerie.md
Datum: 2026-10-17 09:48

## Checkliste
- [x] **AC-1:** `MacGalleryTests` existiert in `LooseEndsUITests/MacGalleryTests.swift`, die ganze Datei steht in `#if os(macOS)`, und sie enthält zwei Tests (hell und dunkel). Nachweis: Quelltext im Diff; Test 4 (iOS-Build übersetzt, Klasse fehlt im iOS-Lauf).
- [x] **AC-2:** Der Job `UI Smoke (iOS Simulator)` ist unverändert und führt `MacGalleryTests` nicht aus. Nachweis: Diff von `ci.yml` zeigt keine Änderung am Job `ui-smoke`; im CI-Protokoll von UI Smoke taucht `MacGalleryTests` nicht auf; pytest-Test aus Test 1.
- [x] **AC-3:** Der neue Job „Mac Gallery (macOS)“ läuft auf `runs-on: xcode-27` mit der Action `select-xcode-27`, ist nicht `continue-on-error` und ruft `xcodebuild` nur mit `-only-testing:LooseEndsUITests/MacGalleryTests` auf. Nachweis: pytest-Test aus Test 1; Protokollzeile `Xcode 27.0` im Lauf.
- [x] **AC-4:** Vor dem Testschritt läuft `sudo automationmodetool enable-automationmode-without-authentication`; der Testaufruf trägt `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS=`. Scheitert diese Signatur im Lauf, ist der Rückfall `CODE_SIGNING_ALLOWED=NO` und wird im Bericht benannt. Nachweis: pytest-Test aus Test 1; Quelltext des Schritts.
- [x] **AC-5:** Nach dem Lauf liegt das Artefakt `MacGallery` vor; Diagnose-, Export- und Upload-Schritt laufen mit `if: always()`, der Diagnoseschritt scheitert nie. Nachweis: pytest-Test aus Test 1; Artefaktliste des Laufs (`gh run view`).
- [ ] **AC-6:** Das Artefakt enthält sechs Bilder: `mac-gallery-light-1-start`, `mac-gallery-light-2-list-new`, `mac-gallery-light-3-detail` und die drei `mac-gallery-dark-*`. Jedes ist ein Foto des Hauptfensters (das Fenster mit `viewRow_new`), nicht des ganzen Bildschirms und nicht des Menüleisten-Panels. Nachweis: Dateiliste des heruntergeladenen Artefakts; Bilder geöffnet. [offen: braucht CI-Lauf]
- [x] **AC-7:** Die iPhone-Galerie und die übrigen Jobs bleiben unverändert: `Unit Tests (macOS destination)`, `Build (iOS Simulator)`, `UI Smoke (iOS Simulator)` heißen weiter so, laufen grün und der Artefaktname `DesignGallery` ist unverändert. Nachweis: `gh pr checks`; Diff von `ci.yml` zeigt nur den hinzugefügten Job; bestehender Test `test_check_names_unchanged`.
- [x] **AC-8:** `project.yml`, jede `*.entitlements` und jede `Info.plist` sind unverändert, ebenso `LooseEnds/App/LooseEndsApp.swift`. Nachweis: `git diff --name-only` nennt genau `LooseEndsUITests/MacGalleryTests.swift`, `.github/workflows/ci.yml`, `scripts/test_ci_xcode27.py`, `CLAUDE.md` (plus Workflow-Artefakte unter `docs/`).
- [x] **AC-9:** `python3 scripts/test_ci_xcode27.py` ist grün, einschließlich des neuen Tests, der vor Änderung 2 rot war (RED vor GREEN belegt) und alle Prüfpunkte aus Test 1 abdeckt. Nachweis: Testausgabe vorher und nachher; Unit-Job der CI führt die Skript-Tests aus.
- [ ] **AC-10:** „Mac Gallery (macOS)“ ist im CI-Lauf auf dem PR-Zweig grün, ohne Wiederholung. Beide Tests bestehen; das Hauptfenster ist mindestens 700 pt breit. Nachweis: Lauf-ID, Protokollzeilen des Testschritts, Diagnoseschritt (Automationsstatus). [offen: braucht CI-Lauf]
- [ ] **AC-11:** Die Bilder aus dem PR-Lauf sind heruntergeladen, geöffnet und beschrieben: je Bild, was zu sehen ist (Seitenleiste, Startseite mit Aufgaben, Liste „Neu“, Detail), ob hell/dunkel stimmt (auch Titelleiste und Seitenleiste im Dunkelbild), und die tatsächliche Fenstergröße aus dem Anhang `window-size`. Ist das Fenster schmaler als 1120 pt (die rechte Spalte der Startseite fehlt dann), wird ein eigenes Ticket für `defaultSize` angelegt und hier nichts geändert. Nachweis: Beschreibung im Bericht, nicht nur Dateiliste. [offen: braucht CI-Lauf]
- [ ] **AC-12:** Nach dem Merge liefert ein CI-Lauf auf `main` das Artefakt `MacGallery` mit den Bildern (DoD-Punkt 4 aus #511). Nachweis: Lauf-ID auf `main`, Artefaktliste. [offen: braucht CI-Lauf]
- [x] **AC-13:** `CLAUDE.md` nennt im CI-Abschnitt in einem Satz den Job „Mac Gallery (macOS)“, das Artefakt `MacGallery` und dass Mac-Bilder nur dort entstehen. Nachweis: Diff.
- [x] **AC-14:** Abnahmestufe: Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2 (Bilder aus dem Artefakt angesehen); auf Hennings Mac oder seinen Geräten läuft nichts. Nachweis: `git diff --name-only` aus AC-8.

## Dialog

### Runde 1
**Adversary:**
Forderung je Punkt, Belege selbst beschafft (Tests: `docs/artifacts/feat-511-ci-mac-galerie/adversary-test-output.txt`, 25 Tests, OK; iOS `build-for-testing` generic/platform=iOS Simulator: TEST BUILD SUCCEEDED; macOS-Build-Log: TEST BUILD SUCCEEDED; nichts auf dem Mac gestartet).

Confirmation:
  AC: AC-1
  Code reference: LooseEndsUITests/MacGalleryTests.swift:1
  Evidence: Zeile 1 `#if os(macOS)`, letzte Zeile `#endif`, zwei Tests (testGalleryLight Z.107, testGalleryDark Z.112). Die iOS-UI-Test-Bundle-Binaerdatei (Debug-iphonesimulator/LooseEndsUITests.xctest) enthaelt 0 Treffer fuer `MacGallery` (strings und nm), aber 8 fuer `DesignGalleryTests`: die Datei uebersetzt unter iOS leer, die Klasse fehlt.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: .github/workflows/ci.yml:186
  Evidence: Der Diff gegen 85ed8a2 hat genau einen Hunk `@@ -310,3 +310,83 @@`, nur Zeilen mit `+`, keine Entfernung; ui-smoke (bis Z.310) unveraendert. pytest `test_ui_smoke_neither_runs_nor_exports_the_mac_gallery` gruen. Dass `MacGalleryTests` im UI-Smoke-Protokoll nicht auftaucht, folgt strukturell aus AC-1; das CI-Protokoll selbst liegt noch nicht vor.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: .github/workflows/ci.yml:319
  Evidence: Job mac-gallery, `name: Mac Gallery (macOS)`, `runs-on: xcode-27`, Pflicht-Action `./.github/actions/select-xcode-27`, kein `continue-on-error` am Job, genau ein `-only-testing:LooseEndsUITests/MacGalleryTests`. YAML parst (Jobs unit-tests, ios-build, ui-smoke, mac-gallery). Protokollzeile `Xcode 27.0`: braucht CI-Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: .github/workflows/ci.yml:330
  Evidence: Schritt "Enable UI automation (#511)" steht vor "Run Mac gallery"; `sudo automationmodetool enable-automationmode-without-authentication` ohne `|| true`, der Job scheitert also laut statt still; die Schritte mit `if: always()` (Diagnose, Export, Upload) laufen danach trotzdem. Nur `DevToolsSecurity -enable` hat `|| true`, vertretbar (Status steht im Diagnoseschritt). Signaturargumente vollstaendig (CODE_SIGN_IDENTITY=-, CODE_SIGN_STYLE=Manual, DEVELOPMENT_TEAM=, CODE_SIGN_ENTITLEMENTS=); pytest prueft sie per `run.split()`.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: .github/workflows/ci.yml:352
  Evidence: Diagnose (`if: always()`, `continue-on-error: true`, jede Zeile `|| true`), Export (`if: always()`), Upload `MacGallery` (`if: always()`, `if-no-files-found: warn`), zusaetzlich `MacGalleryResults`. Der Exportschritt wird von pytest mit gefaelschtem xcrun und Manifest wirklich ausgefuehrt: nur `mac-gallery-*`, .png und .txt, Suffix erhalten, `gallery-*` und Fremdanhaenge fallen heraus. Echte Artefaktliste: braucht CI-Lauf.
  Status: CONFIRMED (Konfiguration)

Confirmation:
  AC: AC-7
  Code reference: scripts/test_ci_xcode27.py:144
  Evidence: `test_check_names_unchanged` und `test_every_job_runs_on_xcode_27_with_the_action` gruen (adversary-test-output.txt); Diff nur hinzugefuegt (AC-2); DesignGallery-Name per Test geprueft. `gh pr checks`: braucht PR.
  Status: CONFIRMED (Konfiguration)

Confirmation:
  AC: AC-8
  Code reference: .github/workflows/ci.yml:314
  Evidence: `git diff --name-only 85ed8a2`: ci.yml, CLAUDE.md, MacGalleryTests.swift, test_ci_xcode27.py plus docs/ (Artefakte, Briefing, Kontext, Spec). Weder project.yml noch *.entitlements noch Info.plist noch LooseEndsApp.swift; Info.plist nach den Builds unveraendert (`git status --short` leer).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/test_ci_xcode27.py:144
  Evidence: Neue Klasse MacGallery (8 Tests) deckt alle Punkte aus Test 1; Gesamtlauf `Ran 25 tests ... OK`. RED-Beleg liegt als docs/artifacts/feat-511-ci-mac-galerie/test-red-output.txt im Diff. Der Unit-Job fuehrt die Skript-Tests aus (test_unit_job_runs_every_script_test gruen).
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: CLAUDE.md:170
  Evidence: Ein Satz ueber drei Zeilen im CI-Abschnitt direkt nach dem xcode-27-Absatz: nennt "Mac Gallery (macOS)", `MacGalleryTests`, Artefakt `MacGallery`, `mac-gallery-*`, "never from Henning's Mac".
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: .github/workflows/ci.yml:314
  Evidence: Keine Datei der Geraeteliste im Diff (AC-8); in dieser Pruefung wurde nichts auf dem Mac oder einem Geraet gestartet, nur uebersetzt.
  Status: CONFIRMED

Offen (braucht CI-Lauf): AC-6, AC-10, AC-11, AC-12.

Plausibilitaet des Fototests gegen den App-Quelltext (Identifier existieren und sind auf dem Mac erreichbar):
- `viewRow_new`: SidebarView.swift:64 erzeugt `viewRow_<kind>`; `.new` steht in `ViewRules.indexViews` immer (ViewRules.swift:66); auf dem Mac nimmt SidebarView den Zweig `isMac` mit `ContentsIndex` (SidebarView.swift:112); StartZones.swift:206 setzt `.accessibilityIdentifier(line.id)`. Die Seitenleiste bleibt auf jedem Bildschirm (ContentView.swift:38), die Fensterwahl per `containing` traegt also auch nach dem Klick auf Neu. Das MenuBarExtra-Panel hat diese Zeile nicht.
- `startCaptureField`: StartPage.swift:151, nur bei `selection == nil`; das Panel nutzt `captureTextField`. Reihenfolge im Test stimmt: erst erfassen, dann klicken.
- Onboarding: unter `--ui-testing` false (OnboardingFlow.swift:37), kein Sheet vor dem Feld.
- `taskRow_*`: TaskRow.swift:16/46 Standardpraefix; Seitenleiste nutzt `nowRow_`, Startseite `startNowRow_`, also ist `taskRow_` nur in der Liste Neu. Neue Aufgaben liegen in "Neu" (isInNew: unprocessed/unverified); Modell unter `--ui-testing` aus.
- `detailRawTextMarker`: TaskDetailView.swift:83, immer gesetzt.
- Reihenfolge: Fotos vor der Breiten-Zusicherung (Z.82, 95, 99 vor Z.102); Groessenanhang nach Foto 1; `window.screenshot()`, kein `app.screenshot()`. Dunkel: `--ui-testing-dark` wird in LooseEndsApp.swift:91 gelesen.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:65
  Description: Die Leere-Pruefung `value == nil OR value == ''` auf `startCaptureField`. Auf iOS liefert `value` eines leeren TextFields den Platzhalter; ob SwiftUI auf macOS bei leerem Feld "", nil oder den Platzhalter liefert, ist ungeprueft und nur im CI-Lauf klaerbar. Liefert es den Platzhalter, scheitert `capture` nach 5 s mit "Field kept ..." und `continueAfterFailure = false` beendet den Test ohne ein einziges Foto.
  Spec requirement: AC-6/AC-10 — sechs Bilder, beide Tests bestehen
  Conflict: Kein Spec-Verstoss (die Spec nennt die Pruefung), aber ein plausibler Erstlauf-Fehler, der alle Bilder kostet, obwohl die Aufgabe gespeichert wurde.
  Remediation: Den Platzhaltertext als leer zulassen, oder statt auf das Feld auf das Ergebnis warten (Zaehler/Zeile in der Seitenleiste). Nicht blockierend; im Lauf beobachten.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: .github/workflows/ci.yml:356
  Description: Der Diagnoseschritt ruft `log show --last 15m ... | tail -200` ohne eigene Zeitgrenze; `continue-on-error` faengt Fehler, keinen Haenger. Export und Upload kommen danach und teilen sich nur das Job-Limit (40 min).
  Spec requirement: AC-5 — Diagnoseschritt scheitert nie
  Conflict: Kein Fehlschlag, aber moeglicher Zeitfresser vor Export und Upload.
  Remediation: `timeout-minutes: 5` am Diagnoseschritt. Nicht blockierend.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/test_ci_xcode27.py:226
  Description: `test_gallery_source_is_mac_only` prueft den Quelltext per Zeichenkettensuche; das beweist nicht, dass der Test auf dem Mac laeuft, nur dass die Woerter dastehen.
  Spec requirement: AC-9 — pytest deckt die Pruefpunkte ab
  Conflict: Schwach, aber nicht falsch; der echte Nachweis ist der CI-Lauf.
  Remediation: Keine Pflicht.

Belege fuer Runde 2 (AC-6, AC-10, AC-11, AC-12):
1. Lauf-ID des PR-Zweigs und des Jobs "Mac Gallery (macOS)" (gruen, ohne Wiederholung); Protokollzeile `Xcode 27.0`; Schritt "Enable UI automation" ohne Fehler; Testschritt mit `testGalleryLight` und `testGalleryDark` passed, ohne "Timed out while enabling automation mode"; Ausgabe des Diagnoseschritts (Automationsstatus, DevToolsSecurity, Aufloesung).
2. Ausgabe des Exportschritts und Artefaktliste (`gh run view <id>`): Artefakte `MacGallery` und `MacGalleryResults`; in `MacGallery` genau sechs `mac-gallery-{light,dark}-{1-start,2-list-new,3-detail}.png` plus zwei `...-window-size.txt`.
3. Die sechs heruntergeladenen Bilder geoeffnet und je Bild beschrieben: Hauptfenster (nicht ganzer Bildschirm, kein Panel), Seitenleiste mit Neu und Zaehler, Startseite mit drei Aufgaben, Liste Neu mit drei Zeilen, Detail mit Rohtext; Dunkelbilder: Titelleiste und Seitenleiste dunkel?; Inhalt der window-size-Dateien (Breite x Hoehe in pt; Mindestbreite 700; ab 1120 rechte Spalte) und ob ein Ticket fuer `defaultSize` noetig ist.
4. Lauf auf `main` nach dem Merge (Lauf-ID, Artefaktliste), AC-12.
5. Falls der Erstlauf rot ist: Fehlerzeile und Entscheidung zum Rueckfall (`CODE_SIGNING_ALLOWED=NO`, F001-Platzhalterproblem); der Rueckfall muss im Bericht benannt sein.
**Implementierer:**

### Runde 2
**Adversary:**
**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS

Runde 2 nach CI-Lauf: AC-6, AC-10, AC-11 und AC-12 lassen sich nur mit einem echten CI-Lauf (PR-Zweig und main) belegen. Alle uebrigen ACs sind bestaetigt; kein Defekt im Sinne der Spec gefunden (F001 MEDIUM, F002 und F003 LOW als Beobachtungen).
Tests: 25 passed, 0 failed, 0 übersprungen (scripts.test_ci_xcode27); iOS-build-for-testing gruen, kein Symbol MacGalleryTests im iOS-Bundle.

## Geprüfte Dateien

- sha256:b7467fcea63cd5c2376eff5ea7cd651476ea97b4473953c156ebfca7bcfe8368  .github/workflows/ci.yml
- sha256:2e60fe057af10d92b66dae86b8ef44d4f962d227bbc7d63a1cdc2b0b40db9f1a  CLAUDE.md
- sha256:6fdebdcd8d04d9ff244c765a529141470f8ea563dadc7ac15e0d8f12bf691ed4  LooseEndsUITests/MacGalleryTests.swift
- sha256:2038cfd163fadf8353e6b33b633accd3ca98cef09215178aef9e6d52e99331c4  scripts/test_ci_xcode27.py

## Prüfbasis

- base: 85ed8a236cebb548bfa946fce08da949fcfbe886
- blob:6efef9a5364703396d36763347d6ec349ac4a5d6  .github/workflows/ci.yml
- blob:9d9a3f49ee67dac02acee31e06c09c3025f1c8ab  CLAUDE.md
- blob:43de9abb5c8969303ae2f7d1164203e7f1d08434  LooseEndsUITests/MacGalleryTests.swift
- blob:4177e7140415901814647eb4e0441422af9e9eb9  scripts/test_ci_xcode27.py
