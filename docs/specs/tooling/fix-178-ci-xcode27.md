---
entity_id: fix-178-ci-xcode27
type: feature
created: 2026-10-05
updated: 2026-10-05
status: draft
workflow: ci-178-xcode27
---

# Spec: #178 — CI auf Xcode 27 umstellen, Absenkung auf 26.0 entfernen

## Approval

- [ ] Approved

## Purpose

Die CI (`ci.yml`, `speech-stress.yml`) läuft auf dem Standard-Image `macos-26` ohne Xcode 27 und senkt
die Deployment-Ziele in `project.yml` per `sed` still auf 26.0 ab. Sie prüft damit eine andere App
(SDK 26.6) als die, die Henning aus Xcode 27.0 baut. Anlass ist #25 (Reminders-App-Schema): Dessen
Umsetzung steht hinter `#if compiler(>=6.4)`, den die CI nie übersetzt; die Umsetzung ist angehalten,
bis dieses Ticket erledigt ist. Diese Spec stellt alle CI-Jobs auf das Image `xcode-27` mit fest
gewähltem Xcode 27.0 und Deployment-Ziel 27.0 um, zieht die Auswahl in eine gemeinsame Composite Action
(eine Stelle statt vier Kopien), macht die Simulatorwahl streng (nur iPhone 17 mit iOS 27.0) und
entfernt den Compiler-Schalter. Es ändert sich kein Produktverhalten und nichts Sichtbares in der App.

## Source

- **File:** `.github/workflows/ci.yml`
- **Identifier:** drei Jobs `unit-tests`, `ios-build`, `ui-smoke`, je `runs-on: macos-26` (Zeilen 20, 64, 94), je Schritt „Select newest Xcode (27 when the image has it)" mit `sed`-Absenkung (Zeilen 23, 67, 97); Schritt „Pick a simulator" (Zeile 111) mit Rückfall auf das erste iPhone; Kopfkommentar beschreibt die Absenkung
- **File:** `.github/workflows/speech-stress.yml`
- **Identifier:** `runs-on: macos-26`, Xcode-Auswahl mit `sed`-Absenkung (Zeilen 29–41), Simulatorwahl
- **File:** `.github/workflows/testflight.yml`
- **Identifier:** Schritt „Select Xcode 27.0" (Vorbild aus #174); bleibt unverändert
- **File:** `Measurement/MeasurementRun.swift`
- **Identifier:** `#if compiler(>=6.4)` / `#endif` um den `LanguageModelError`-Zweig (ca. Zeile 228) samt veraltetem Kommentar „CI still builds with Xcode 26"
- **File:** `CLAUDE.md`
- **Identifier:** Abschnitt zur CI („CI runs on GitHub's `macos-26` image … `#available` …", im Abschnitt Build)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| GitHub-Runner-Label `xcode-27` (Vorschau, arm64, macOS 27) | tooling | Liefert Xcode 27.0 (27A266a), Simulator iOS 27.0, Host macOS 27.0 (Unit-Job mit Ziel 27.0 auf dem Mac) |
| `/Applications/Xcode_27.app` | tooling | Fest gewählte Toolchain; daneben liegen `Xcode_27.1_beta.app` und `Xcode_27.2_beta.app`, die nicht gewählt werden |
| Simulator iPhone 17 / Laufzeit `com.apple.CoreSimulator.SimRuntime.iOS-27-0` | tooling | Einziges zulässiges Ziel für UI Smoke und Speech-Stress |
| XcodeGen (`brew install xcodegen`), xcbeautify | tooling | Projekt erzeugen, Ausgabe formatieren (bestehende Schritte) |
| `docs/specs/tooling/fix-174-testflight-ios27.md`, `docs/reference/testflight.md` | docs | Vorbild der Xcode-Wahl; Vorgehen bei Wegfall des Vorschau-Labels |
| #25, #208, #172 | issues | #25 wartet auf dieses Ticket; #208 (Simulator mit Modell) ist der Hänger bei rotem UI Smoke; #172 (UI-Tests beim ersten Versuch grün) schließt Wiederholungen aus |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `.github/actions/select-xcode-27/action.yml` | CREATE | Composite Action: `xcode-select -s /Applications/Xcode_27.app`, `xcodebuild -version` protokollieren, Abbruch mit `::error::` wenn nicht „Xcode 27.0“ (Logik wie testflight.yml) |
| `.github/workflows/ci.yml` | MODIFY | Drei Jobs `runs-on: xcode-27`; Auswahlschritt durch `uses: ./.github/actions/select-xcode-27` ersetzt; `sed`-Absenkung raus; Kopfkommentar neu; UI Smoke: strenge Simulatorwahl und Diagnoseschritt; Check-Namen unverändert |
| `.github/workflows/speech-stress.yml` | MODIFY | Gleiche Umstellung (Runner, Composite Action, `sed` raus, strenge Simulatorwahl) |
| `Measurement/MeasurementRun.swift` | MODIFY | `#if compiler(>=6.4)`/`#endif` und veralteten Kommentar entfernen |
| `CLAUDE.md` | MODIFY | CI-Abschnitt: `xcode-27`, fest 27.0, keine Absenkung, Vorgehen bei Wegfall des Labels (Verweis auf `docs/reference/testflight.md`); `#available`-Satz zur CI streichen |
| `LooseEndsUITests/CaptureCancelCrashTests.swift` | MODIFY | Nachtrag 2026-10-06 (Änderung 5): Startargument `-speechServerRecognitionAllowed NO`, damit der App-Dialog „Recognize speech via Apple?“ den Abbrechen-Tipp nicht mehr zufällig schluckt |

`testflight.yml` und `project.yml` bleiben unverändert.

### Estimated Changes

- Files: 6 (1 neu) — eine Datei über der Grenze von 4–5, vom PO am 2026-10-06 ausdrücklich freigegeben (Nachtrag unten)
- LoC: ca. +45/−60, innerhalb von ±250
- Kein Produktcode außer dem Entfernen eines Compiler-Schalters. Keine neuen Abhängigkeiten, keine neuen Berechtigungen, keine AppStorage-Schlüssel, keine Audiodateien, keine Änderung an `project.yml`, Entitlements oder Info.plist.

## Definition of Done

- [ ] Alle CI-Jobs (`Unit Tests (macOS destination)`, `Build (iOS Simulator)`, `UI Smoke (iOS Simulator)`) laufen grün mit Xcode 27.0 und Deployment-Ziel 27.0 (AC-1, AC-8)
- [ ] Kein `sed` auf `project.yml` und keine Absenkung mehr in `.github` (AC-3)
- [ ] `CLAUDE.md`, Abschnitt CI, nachgezogen (AC-12)
- [ ] Drei Jobs auf `runs-on: xcode-27`, Xcode 27.0 fest (AC-1, AC-2)
- [ ] Simulatorwahl iPhone 17 / iOS 27.0 streng (AC-4)
- [ ] Lauf- und Wartezeit gegen die bisherige CI verglichen und in der PR-Beschreibung (AC-10)
- [ ] `speech-stress` per `workflow_dispatch` (Iterations 3) grün (AC-9)
- [ ] `MeasurementRun.swift` ohne Compiler-Schalter übersetzt (AC-11)
- [ ] `speech-stress` ohne 600-s-Diagnose-Wartezeit, Durchlauf unter 300 s (AC-15)
- [ ] Abbrechen-Test ohne Zustimmungsdialog, `speech-stress` mit 10 Durchläufen grün (AC-16)

## Implementation Details

### Ausgangslage mit Beleg

Alle Jobs wählen die „neueste" Xcode-27-App, sonst senken sie per `sed` auf 26.0 ab. Auf `macos-26`
gibt es kein Xcode 27 (CI-Lauf 37108095080: „No Xcode 27 on this image: deployment targets lowered to
26.0", Xcode 26.6). Auf dem Image `xcode-27` hätte `ls -d Xcode_27*.app | sort -V | tail -1` die
27.2-Beta gewählt. Ein bloßer Labelwechsel genügt deshalb nicht; die Version wird fest gewählt und
geprüft. Das Image läuft seit September auf macOS 27. Damit kann der Unit-Job mit Ziel 27.0 auf dem
Mac-Host laufen (Mac hostet Tests nur bei macOS ≥ Target, siehe CLAUDE.md).

### Änderung 1 — Composite Action `select-xcode-27`

```yaml
name: Select Xcode 27.0
description: Selects /Applications/Xcode_27.app and fails unless it is Xcode 27.0.
runs:
  using: composite
  steps:
    - shell: bash
      run: |
        sudo xcode-select -s /Applications/Xcode_27.app
        xcodebuild -version
        version=$(xcodebuild -version | sed -n 1p)   # sed liest bis zum Ende: kein SIGPIPE unter pipefail
        if [ "$version" != "Xcode 27.0" ]; then
          echo "::error::Expected Xcode 27.0 at /Applications/Xcode_27.app, got: $version. Not building an older or beta toolchain. See docs/reference/testflight.md"
          exit 1
        fi
```

Geprüft wird nur „Xcode 27.0"; die Build-Kennung wird protokolliert, aber nicht verglichen, damit ein
Image-Update auf 27.0.x nicht bricht. Das `sed -n 1p` in der Action liest nur die Ausgabe von
`xcodebuild -version` und ändert keine Datei; die DoD-Prüfung (AC-3) sucht daher nach `sed -i` und
nach Zugriffen auf `project.yml`, nicht nach dem Wort `sed` allein. Jeder Job nutzt die Action nach
`actions/checkout` (die Action liegt im Repository).

### Änderung 2 — `ci.yml` und `speech-stress.yml`

- `runs-on: xcode-27` in allen drei CI-Jobs und in `speech-stress.yml`.
- Der Schritt „Select newest Xcode …" wird `- uses: ./.github/actions/select-xcode-27`. Die `sed`-Absenkung
  entfällt ersatzlos, ebenso jeder Verweis auf 26.0. Der Kopfkommentar von `ci.yml` beschreibt Image,
  feste Version und das Ausbleiben einer Absenkung.
- Job-Namen (`Unit Tests (macOS destination)`, `Build (iOS Simulator)`, `UI Smoke (iOS Simulator)`)
  bleiben unverändert. Für `main` gibt es keinen Branch-Schutz; gleiche Namen vermeiden dennoch jeden
  Nebeneffekt.
- Simulatorwahl (UI Smoke und Speech-Stress) strikt: Name „iPhone 17" und Laufzeit
  `com.apple.CoreSimulator.SimRuntime.iOS-27-0` aus `xcrun simctl list devices available -j`. Gibt es
  kein solches Gerät, bricht der Schritt mit `::error::` und der Liste der vorhandenen Geräte ab. Kein
  Rückfall auf ein beliebiges iPhone.
- Diagnoseschritt im UI-Smoke-Job (vor den Tests): `xcodebuild -version`, gewählte Simulator-Laufzeit
  und Gerätebeschreibung, soweit erhebbar die Verfügbarkeit des On-Device-Modells (z. B. Ausgabe der
  Gerätefähigkeiten aus `simctl`/Systemprotokoll); ist sie nicht erhebbar, schreibt der Schritt „Modellverfügbarkeit
  nicht erhebbar" ins Protokoll statt zu raten. Der Schritt bricht nie ab.

### Änderung 3 — `MeasurementRun.swift`

`#if compiler(>=6.4)`, das zugehörige `#endif` und den Kommentar „CI still builds with Xcode 26 …"
entfernen. Der `LanguageModelError`-Zweig steht danach unbedingt im Code und wird von der CI mit
übersetzt (Voraussetzung für #25).

### Änderung 4 — `CLAUDE.md`

Der CI-Absatz (derzeit „CI runs on GitHub's `macos-26` image … lowers the deployment targets … must be
guarded with `#available`") wird ersetzt durch: CI läuft auf dem Vorschau-Label `xcode-27` mit fest
gewähltem Xcode 27.0 (Composite Action `.github/actions/select-xcode-27`), Deployment-Ziel 27.0 ohne
Absenkung, Simulator nur iPhone 17 / iOS 27.0; fällt das Label weg oder wird es umbenannt, gilt das
Vorgehen in `docs/reference/testflight.md` (Label nachschlagen, `runs-on` in `ci.yml`,
`speech-stress.yml` und `testflight.yml` anpassen). Der Satz zu `#available`-Guards wegen CI entfällt.

### Nachtrag 2026-10-06 — Befund aus dem ersten Lauf auf `xcode-27`

CI-Lauf 37415824465 war in allen drei Jobs grün. `speech-stress` aber nicht: Lauf 37415827670
(`workflow_dispatch`, 3 Durchläufe) endete mit „passed 2, failed 1 of 3“, und Lauf 37415824453 (PR, 10
Durchläufe) wurde nach 75 Minuten abgebrochen. Zwei belegte Ursachen:

1. **600 s Diagnose je Durchlauf.** Der Test selbst dauert 61 s wie bisher. Danach meldet `xcodebuild`
   „Failure collecting diagnostics from simulator: Timed out after 600.0 seconds“. Jeder Durchlauf dauert so
   ~700 s statt ~60 s (Vergleich: Lauf 37297700749 auf `macos-26`, 30/30 grün, 53–216 s). Das ist ein
   bekanntes Verhalten seit Xcode 26 (`simctl diagnose --timeout=600`). Abhilfe ist
   `-collect-test-diagnostics never` (in Xcode 27 lokal geprüft: `on-failure|never`). Quellen:
   https://github.com/bitomule/simpool/pull/32, https://github.com/cad0p/vvterm/issues/251,
   https://github.com/actions/runner-images/issues/8693. Die Haupt-CI zeigte die Wartezeit nicht.
2. **Wettlauf mit dem Zustimmungsdialog.** Im iOS-27-Simulator auf GitHub scheitert die Erkennung auf dem
   Gerät. Dann zeigt die App wie vorgesehen (#63, `CaptureView.swift:80`) „Recognize speech via Apple?“.
   In Durchlauf 1 erschien der Dialog genau beim Abbrechen-Tipp. XCTest meldete „Computed hit point
   {-1, -1}“, der Tipp ging ins Leere, und die UI-Hierarchie beim Fehlschlag zeigt das Alert über dem
   Blatt. Die App verhält sich richtig. Der Test prüft den Absturz beim Abbrechen (#184), nicht die
   Server-Zustimmung.

**Änderung 5:**
- `speech-stress.yml`: `-collect-test-diagnostics never` an `xcodebuild test-without-building`.
- `CaptureCancelCrashTests.swift`: Startargument `-speechServerRecognitionAllowed NO` (Argument-Domain wie
  `-onboardingDone`). Damit endet eine gescheiterte Erkennung ohne Dialog im Zustand „nicht verfügbar“.
  Mikrofon, Erkennung und Abbrechen laufen weiter wie bisher. Regelweg statt Unterbrechungs-Monitor: Der
  Zustand ist von vornherein festgelegt, statt einen Dialog abzufangen, der irgendwann erscheint.

**Alternative (verworfen):** `addUIInterruptionMonitor` für das Alert. Das würde den Wettlauf nur verlagern
(XCTest prüft Unterbrechungen nur vor einer Aktion), deshalb nicht deterministisch.

### Vorgehen: Reproduktion zuerst

1. **RED vorher:** Zeilen „No Xcode 27 on this image: deployment targets lowered to 26.0" und
   `xcodebuild -version` (Xcode 26.6) aus CI-Lauf 37108095080 oder 37330631849 zitieren; das ist der
   Ausgangszustand. Dazu `grep -rn "26.0\|sed -i\|project.yml" .github` zeigt die Absenkung.
2. Änderungen 1–4 umsetzen. Lokal: `./scripts/sim.sh generate` und `./scripts/sim.sh unit` grün nach
   Entfernen des Schalters.
3. Syntaxprüfung der Workflows und der Action (YAML parsebar, `actionlint` falls vorhanden), `bash -n`
   auf den Schrittblöcken.
4. PR-Lauf: alle drei CI-Jobs grün; Protokollzeilen und Zeiten zitieren.
5. `speech-stress` per `workflow_dispatch` (Iterations 3).

### Risiko: Simulator mit Modell, Vorgehen

iOS-27-Simulatoren haben lokal Apple Intelligence, und das Modell überschreibt dort Titel und Felder
während der UI-Tests (#208). Auf der CI ist das voraussichtlich gegenstandslos: Apple Intelligence
läuft nicht in virtuellen Maschinen (Apple-Forum 787445), GitHub-Mac-Runner sind VMs (runner-images
#2187). Das wird im ersten Lauf belegt (Diagnoseschritt). **Wird UI Smoke wegen eines aktiven Modells rot,
gibt es keine Wiederholung und kein Retry (#172), sondern das Ticket hängt an #208 oder einem Folgeticket;
der Befund wird dort dokumentiert.**

### Vorgehen bei Wegfall oder Umbenennung des Labels

`xcode-27` ist eine Vorschau. Fällt es weg, startet kein Runner. Dann gilt das Vorgehen in
`docs/reference/testflight.md` (Abschnitt „Wenn das Vorschau-Image wegfällt oder umbenannt wird"):
neues Label in den Runner-Images nachschlagen, `runs-on` in allen drei Workflows anpassen. Die
Versionsprüfung der Composite Action bleibt. Es gibt bewusst keinen Rückweg auf 26.

### Alternativen

- **Status quo (`macos-26` + Absenkung):** prüft gegen ein anderes SDK als Henning; #25 bleibt blockiert. Verworfen.
- **Nur Unit + Build auf `xcode-27`, UI Smoke bleibt auf 26:** halbiert das Risiko aus #208, aber die UI-Tests prüfen weiter eine 26.0-App. Kippt das Ziel des Tickets. Verworfen.
- **Selbst gehosteter Runner auf Hennings Mac:** einzige Variante mit echtem Modell im Simulator, blockiert aber seinen Rechner ca. 35 Min. pro PR und öffnet seinen Mac für Code aus PRs. Verworfen.
- **Kopien statt Composite Action:** keine neue Datei, aber vier gleiche Blöcke, die bei Wegfall des Labels einzeln nachzuziehen wären. Verworfen zugunsten einer Stelle.
- **Neueste Xcode-27-Version statt fester 27.0:** wählt heute eine Beta. Verworfen (Begründung aus #174).

### Abgegrenzt

- `testflight.yml` (erledigt in #174) bleibt unverändert.
- #25 (Reminders-App-Schema) wird danach weiterbearbeitet; nicht Teil dieses Tickets.
- #208 (Modell im Simulator) nur bei rotem UI Smoke.

### Nicht belegt und offen

- Ob das Modell im CI-Simulator wirklich aus ist (erwartet: ja); belegt der erste Lauf.
- Ob neue Warnungen oder Fehler auf macOS-27-Host und SDK 27 auftreten, die auf 26 verdeckt waren; lokal laufen die Tests mit Xcode 27 grün (320 Tests am 2026-10-05).
- Ob das Vorschau-Label Wartezeit hat; gemessen in TestFlight-Läufen 37233766254 und 37142589043: 0,1 Min., wie `macos-26` (0,1–0,2 Min.).

### Recherche (Quellen)

- GitHub Changelog 2026-09-10, Xcode-27-Image läuft auf macOS 27, Label `xcode-27` nur arm64, weiter Public Preview: https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/
- Public Preview 2026-07-16: https://github.blog/changelog/2026-07-16-xcode-27-runner-image-now-in-public-preview/
- runner-images #14404: https://github.com/actions/runner-images/issues/14404; Release `xcode-27-arm64/20260928.0222`: https://github.com/actions/runner-images/releases/tag/xcode-27-arm64/20260928.0222
- Apple Intelligence nicht in VMs: https://developer.apple.com/forums/thread/787445; Mac-Runner als VMs: https://github.com/actions/runner-images/issues/2187

## Test Plan

Reine CI-Änderung ohne geändertes Produktverhalten (der entfernte Compiler-Schalter lässt den Zweig
nur mit übersetzen). Deshalb kein neuer Unit-Test und kein UI-Test: Es gibt kein neues Verhalten, das
ein Test prüfen könnte; ein UI-Test würde nur die bestehenden Smoke-Tests wiederholen. Nachweis sind
lokale Prüfungen und der CI-Lauf selbst als Abnahme.

### Automated Tests (TDD RED)

- [ ] Test 1 (RED, alter Zustand): GIVEN das Protokoll des CI-Laufs 37108095080 (oder 37330631849) WHEN die Zeilen zur Xcode-Wahl gelesen werden THEN steht dort „deployment targets lowered to 26.0" und Xcode 26.6.
- [ ] Test 2 (lokal, Syntax): GIVEN die geänderten Workflows und die Action WHEN sie als YAML geparst werden (`actionlint`, falls vorhanden, sonst `python3 -c "import yaml…"` oder `ruby -ryaml`) THEN gibt es keinen Fehler, und `bash -n` auf den Schrittblöcken ist fehlerfrei.
- [ ] Test 3 (lokal, grep): GIVEN der geänderte Stand WHEN `grep -rnE "sed -i|26\.0|macos-26" .github` und `grep -rn "project.yml" .github` laufen THEN gibt es keinen Treffer.
- [ ] Test 4 (lokal, Schalter): GIVEN `MeasurementRun.swift` WHEN `grep -rn "compiler(>=6.4)" . --include=*.swift` läuft THEN gibt es keinen Treffer, und `./scripts/sim.sh unit` ist grün.
- [ ] Test 5 (lokal, Versionsprüfung): GIVEN der Prüfblock der Composite Action mit einer Attrappe, die „Xcode 26.6" meldet WHEN er läuft THEN endet er mit Exit-Code 1 und einer `::error::`-Zeile; mit „Xcode 27.0" endet er mit Exit-Code 0.
- [ ] Test 6 (CI, echter Lauf): GIVEN die PR WHEN `CI` läuft THEN sind alle drei Jobs grün (Details in den Acceptance Criteria).
- [ ] Test 7 (CI, speech-stress): GIVEN der Branch WHEN `speech-stress` per `workflow_dispatch` mit Iterations 3 läuft THEN ist der Lauf grün.
- [ ] Test 8 (lokal, Nachtrag): GIVEN `scripts/test_ci_xcode27.py` WHEN die Tests laufen THEN prüfen zwei neue Fälle, dass der `xcodebuild test-without-building`-Aufruf in `speech-stress.yml` `-collect-test-diagnostics never` enthält und dass `CaptureCancelCrashTests` mit `-speechServerRecognitionAllowed NO` startet. Beide sind vor der Änderung rot (RED), danach grün.
- [ ] Test 9 (CI, Nachtrag): GIVEN der Branch WHEN `speech-stress` durch die PR mit 10 Durchläufen läuft THEN ist er grün, jeder Durchlauf dauert unter 300 s, und kein Protokoll enthält „Timed out after 600.0 seconds“ oder „Recognize speech via Apple?“ (AC-15, AC-16). Für den Wettlauf gibt es keinen lokalen Test: Er tritt nur auf, wenn die Erkennung auf dem Gerät scheitert, und das passiert im lokalen Simulator mit installierten Sprachmodellen nicht. Der Beleg ist deshalb der Lauf mit 10 Durchläufen.

## Acceptance Criteria

- [ ] AC-1 Xcode-Version: GIVEN ein Lauf auf der PR WHEN die Schritte „Select Xcode 27.0" jedes der drei CI-Jobs und von `speech-stress` laufen THEN steht im Protokoll `Xcode 27.0` aus `xcodebuild -version`. Beleg: Lauf-ID und Protokollzeile je Job im Bericht.
- [ ] AC-2 Abbruch bei falscher Version: GIVEN ein Image, dessen `/Applications/Xcode_27.app` nicht 27.0 meldet WHEN die Composite Action läuft THEN bricht sie mit `::error::Expected Xcode 27.0 …` und Exit-Code 1 ab. Beleg: Test 5 (lokale Attrappe, Exit-Code und Zeile zitiert); Quelltext der Action.
- [ ] AC-3 Keine Absenkung: GIVEN der Stand der PR WHEN `grep -rnE "sed -i|26\.0|macos-26" .github` und `grep -rn "project.yml" .github` laufen THEN gibt es keinen Treffer (erlaubt ist nur das lesende `sed -n 1p` in der Composite Action). Beleg: Ausgabe beider Befehle im Bericht.
- [ ] AC-4 Strenge Simulatorwahl: GIVEN UI Smoke und Speech-Stress WHEN der Schritt „Pick a simulator" läuft THEN wird nur „iPhone 17" mit Laufzeit `com.apple.CoreSimulator.SimRuntime.iOS-27-0` gewählt; fehlt es, bricht der Schritt mit `::error::` und Liste der vorhandenen Geräte ab, ohne Rückfall auf ein anderes iPhone. Beleg: Protokollzeile mit gewähltem Gerät und Laufzeit im echten Lauf; Quelltext des Schritts zeigt den Abbruchzweig.
- [ ] AC-5 Diagnoseschritt: GIVEN der UI-Smoke-Job WHEN der Diagnoseschritt läuft THEN stehen im Protokoll `xcodebuild -version`, die Simulator-Laufzeit, die Gerätebeschreibung und die Modellverfügbarkeit (oder die Zeile „Modellverfügbarkeit nicht erhebbar"). Beleg: Protokollzeilen mit Lauf-ID. Der Schritt bricht nie ab.
- [ ] AC-6 Check-Namen unverändert: GIVEN die PR WHEN die Check-Liste geöffnet wird THEN heißen die Checks weiter `Unit Tests (macOS destination)`, `Build (iOS Simulator)` und `UI Smoke (iOS Simulator)`. Beleg: `gh pr checks`-Ausgabe im Bericht.
- [ ] AC-7 Deployment-Ziel 27.0: GIVEN der CI-Lauf WHEN das Projekt mit `xcodegen generate` aus der unveränderten `project.yml` erzeugt wird THEN steht in den Build-Protokollen Ziel 27.0 (iOS-27.0-Simulator, macOS-27.0-Host) und kein Schritt ändert `project.yml`. Beleg: Protokollzeile des Build-Schritts und Test 3.
- [ ] AC-8 Alle CI-Jobs grün: GIVEN die PR WHEN `CI` läuft THEN sind `Unit Tests (macOS destination)`, `Build (iOS Simulator)` und `UI Smoke (iOS Simulator)` grün, ohne Wiederholung. Beleg: Lauf-ID. Wird UI Smoke wegen eines aktiven Modells im Simulator rot, wird nicht wiederholt, sondern das Ticket hängt an #208 bzw. einem Folgeticket (Beleg: Diagnosezeile aus AC-5).
- [ ] AC-9 Speech-Stress: GIVEN der Branch WHEN `speech-stress` per `workflow_dispatch` mit Iterations 3 läuft THEN ist der Lauf grün. Beleg: Lauf-ID.
- [ ] AC-10 Zeiten verglichen: GIVEN der erste grüne Lauf auf `xcode-27` WHEN Wartezeit bis Start und Laufzeit je Job gemessen werden THEN stehen sie neben den Ausgangswerten (Unit 2,3–3,0 Min., Build 1,3–1,7 Min., UI Smoke 30,2–34,5 Min.; Läufe 37330631849, 37321457390) in der PR-Beschreibung, mit Bewertung. Beleg: PR-Beschreibung.
- [ ] AC-11 Schalter entfernt: GIVEN `Measurement/MeasurementRun.swift` WHEN `grep -rn "compiler(>=6.4)" . --include=*.swift` läuft THEN gibt es keinen Treffer, `./scripts/sim.sh unit` ist lokal grün, und der CI-Build übersetzt die Datei ohne Compiler-Schalter. Beleg: grep-Ausgabe, Unit-Ergebnis, CI-Lauf.
- [ ] AC-12 Dokumentation: GIVEN `CLAUDE.md` WHEN der CI-Abschnitt gelesen wird THEN nennt er `xcode-27`, fest 27.0, keine Absenkung, den Verweis auf `docs/reference/testflight.md` für den Wegfall des Labels, und enthält keinen `#available`-Satz zur CI mehr. Beleg: Diff.
- [ ] AC-13 Abnahmestufe: Kein Pfad der Geräteliste berührt. Das Diff berührt nur `.github/`, `Measurement/MeasurementRun.swift`, `CLAUDE.md`, `LooseEndsUITests/CaptureCancelCrashTests.swift` und `scripts/test_ci_xcode27.py` (plus Workflow-Artefakte unter `docs/`); `project.yml`, Entitlements, Info.plist, `Shared/Persistence/`, Enrichment, Speech, Notifications, Intents, Watch, Widgets und Share bleiben unberührt. Keine sichtbare UI-Änderung, daher keine Entwurfsvorschau. Beleg: `git diff --name-only` im Bericht.
- [ ] AC-14 Ausliefern: Nach dem Merge ist `bash ~/.claude/scripts/loose-ends-sync-main.sh` gelaufen.
- [ ] AC-15 Keine Diagnose-Wartezeit: GIVEN `speech-stress` auf `xcode-27` WHEN ein Durchlauf endet THEN enthält das Protokoll kein „Timed out after 600.0 seconds“, und ein Durchlauf dauert unter 300 s. Beleg: Lauf-ID, `summary.txt` mit Sekunden je Durchlauf.
- [ ] AC-16 Kein Zustimmungsdialog im Abbrechen-Test: GIVEN `CaptureCancelCrashTests` startet mit `-speechServerRecognitionAllowed NO` WHEN die Erkennung auf dem Gerät scheitert THEN erscheint kein „Recognize speech via Apple?“-Alert, und `speech-stress` mit 10 Durchläufen (PR-Auslöser) ist grün. Beleg: Lauf-ID, keine Alert-Zeile im Protokoll der Durchläufe.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Änderung an der Build- und Prüfkonfiguration der CI ohne Architekturwirkung; es wird keine bestehende Entscheidung gekippt, die Absenkung auf 26.0 war ein Übergangsbehelf bis zum Xcode-27-Image.
- **Rationale:** Feste Toolchain mit Versionsprüfung und strenger Simulatorwahl (Regelweg) ist einfacher und belastbarer als „die neueste Version" mit stillem Rückfall. Die Composite Action hält die Auswahl an einer Stelle. Ein selbst gehosteter Runner wäre eine neue Entscheidung und ist nicht Teil dieses Tickets.

## Changelog

- 2026-10-05: Initial spec created (Analyse in `docs/context/ci-178-xcode27.md`).
- 2026-10-06: Nachtrag nach dem ersten `xcode-27`-Lauf: Änderung 5 (`-collect-test-diagnostics never`, Startargument im Abbrechen-Test), sechste Datei, AC-15/AC-16. PO-Freigabe des Umfangs am 2026-10-06, Spec-Sperre per „override“ geöffnet.
