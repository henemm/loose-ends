---
entity_id: feat-511-ci-mac-galerie
type: feature
created: 2026-10-17
updated: 2026-10-17
status: draft
workflow: feat-511-ci-mac-galerie
---

# Spec: #511 — CI-Mac-Galerie: Bildschirmfotos der Mac-App in der CI

## Approval

- [ ] Approved

## Purpose

Die CI fotografiert die iPhone-App seit #182 (Artefakt `DesignGallery`), die Mac-App aber nicht. Für die
Mac-Tickets des Epics #467 (#477–#480) fehlt damit ein Bild von „Heute“ und ein Nachweis, der ohne Hennings Mac
entsteht (Henning, 2026-10-17, in #477: Mac-Fotos nur aus der CI). Diese Spec fügt einen eigenen CI-Job
„Mac Gallery (macOS)“ hinzu, der einen nur für macOS übersetzten UI-Test ausführt. Der Test legt drei Aufgaben an und
fotografiert Startseite, Liste „Neu“ und Detail, hell und dunkel, und der Job lädt die Bilder als Artefakt `MacGallery`
hoch. Es ändert sich nichts an der App und nichts an den bestehenden Jobs.

**Experiment-Charakter:** Kein Mac-UI-Test ist je gelaufen (die `#if os(macOS)`-Zweige in `SettingsSmokeTests` und
`StartScreenInteractionTests` sind nur `XCTSkip`). Ob der `xcode-27`-Runner Mac-UI-Automation zulässt
(Automationsmodus, TCC) und welche Fenstergröße ohne `defaultSize` entsteht, klärt erst der CI-Lauf. Die Rückfälle
stehen unten; der erste Lauf ist Teil der Abnahme, nicht der Vorbereitung.

## Source

- **File:** `LooseEndsUITests/DesignGalleryTests.swift`
- **Identifier:** Vorbild (#182): `launch(dark:)` mit `--ui-testing`, `-AppleLanguages (en)`, `-AppleLocale en_US`, `-contextsEmptiedByUser NO`, `-startShowsProjects NO`, `-startShowsContexts NO` und `--ui-testing-dark`; `shot()` mit `XCTAttachment`, `lifetime = .keepAlways`. Die iPhone-Abläufe (Sheet, Wischen, Zurück-Knopf) gibt es auf dem Mac nicht; die Datei bleibt unverändert.
- **File:** `.github/workflows/ci.yml`
- **Identifier:** Job `ui-smoke` mit den Schritten „Export design gallery“ und „Upload design gallery“ (Vorlage für Export und Upload); Job `unit-tests` (belegt: `-destination 'platform=macOS'` mit `CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM=` baut auf dem Runner)
- **File:** `.github/actions/select-xcode-27/action.yml`
- **Identifier:** Pflicht-Action in jedem Job (#178)
- **File:** `scripts/test_ci_xcode27.py`
- **Identifier:** prüft alle Jobs (`runs-on: xcode-27` plus Action) und die drei bestehenden Jobnamen; Ort des neuen Tests
- **File:** `LooseEnds/App/LooseEndsApp.swift`, `LooseEnds/App/ContentView.swift`, `LooseEnds/Views/SidebarView.swift`, `LooseEnds/Views/StartPage.swift`
- **Identifier:** nur gelesen: `--ui-testing-dark`, Mac-`NavigationSplitView`, `viewRow_<kind>`, `startCaptureField`, `taskRow_*`, `detailRawTextMarker`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| Runner-Label `xcode-27` mit Xcode 27.0 und Pflicht-Action `.github/actions/select-xcode-27` | tooling | Toolchain und Mac-Host für den Job |
| XcodeGen, `xcodebuild`, `xcresulttool` | tooling | Projekt erzeugen, Test ausführen, Anhänge exportieren |
| Automationsmodus (`automationmodetool`) und TCC des Runner-Images | tooling | Erlaubnis für Mac-UI-Automation; Zustand auf `xcode-27` unbekannt |
| `LooseEndsUITests` mit `supportedDestinations: [iOS, macOS]` (`project.yml`, Host `LooseEnds`) | tooling | Das Testziel übersetzt schon für macOS; `project.yml` bleibt unverändert |
| #477, #478, #479, #480 | issues | Downstream: nutzen `MacGallery` als „Heute“ und Nachweis |
| Apple-Forum 693850 und 793307, Bitrise-Artikel „Enabling UI automation for macOS tests“, Jesse Squires zu Hardened Runtime | docs | Recherche 2026-10-17 (siehe Analyse `docs/context/feat-511-ci-mac-galerie.md`) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacGalleryTests.swift` | CREATE | Ganze Datei in `#if os(macOS)`; zwei Tests (hell, dunkel), je drei Aufgaben erfassen, drei Fotos des Hauptfensters |
| `.github/workflows/ci.yml` | MODIFY | Neuer Job „Mac Gallery (macOS)“ auf `xcode-27`; Automationsmodus, Test, Diagnose, Export, Upload `MacGallery` |
| `scripts/test_ci_xcode27.py` | MODIFY | Neuer Test für den Job (Label und Action, nur `MacGalleryTests`, Automationsmodus vor dem Test, `if: always()`, Jobnamen unverändert) |
| `CLAUDE.md` | MODIFY | Ein Satz im Abschnitt zur CI: wo die Mac-Bilder entstehen |

`project.yml`, jede `*.entitlements`, jede `Info.plist`, `LooseEndsApp.swift` und alle anderen Jobs in `ci.yml` bleiben
unverändert.

### Estimated Changes

- Files: 4 (1 neu)
- LoC: ca. +230 / −0, innerhalb von ±250
- Keine neuen Abhängigkeiten, keine neuen Berechtigungen, keine AppStorage-Schlüssel, keine Audiodateien. Der Test
  ändert keine Produktdatei.

## Definition of Done

- [ ] `MacGalleryTests` mit zwei Tests, nur unter macOS übersetzt; der Job `ui-smoke` führt sie nicht aus (AC-1, AC-2)
- [ ] Neuer Job „Mac Gallery (macOS)“ auf `xcode-27` mit Pflicht-Action, nur `MacGalleryTests`, ohne `continue-on-error` (AC-3, AC-4)
- [ ] Artefakt `MacGallery` mit sechs Bildern `mac-gallery-*` (AC-5, AC-6)
- [ ] iPhone-Galerie und übrige Jobs unverändert, `project.yml` und `*.entitlements` unberührt (AC-7, AC-8)
- [ ] pytest-Erweiterung grün (AC-9)
- [ ] CI-Lauf auf dem PR-Zweig grün, Bilder angesehen und beschrieben (AC-10, AC-11)
- [ ] Lauf auf `main` nach dem Merge liefert die Bilder (AC-12)
- [ ] `CLAUDE.md` nachgezogen (AC-13)

## Implementation Details

### Änderung 1 — `MacGalleryTests.swift`

Ganze Datei in `#if os(macOS)`, damit die Klasse im iPhone-Lauf (`-only-testing:LooseEndsUITests`) nicht mitläuft. Keine
Kopie der iPhone-Datei, weil der Mac-Ablauf ein anderer ist (Erfassen über das eingebettete Feld `startCaptureField`
statt Sheet, Seitenleiste statt Liste, kein Wischen, kein Zurück-Knopf).

- **Zwei Tests**, `testGalleryLight` und `testGalleryDark`, damit ein Teilerfolg trotzdem Bilder liefert.
- **Start:** `--ui-testing`, `-AppleLanguages (en)`, `-AppleLocale en_US`, `-contextsEmptiedByUser NO`,
  `-startShowsProjects NO`, `-startShowsContexts NO` wie die iPhone-Galerie. Hell ohne weiteres Argument; dunkel mit
  `--ui-testing-dark` (die App liest es selbst) und zusätzlich `-AppleInterfaceStyle Dark` (färbt auch Titelleiste und
  Seitenleiste; `.preferredColorScheme` färbt nur den Fensterinhalt).
- **Hauptfenster:** das Fenster, das `viewRow_new` enthält (Prädikat), nicht `windows.firstMatch`: Das
  `MenuBarExtra`-Panel besitzt unter Tests ein eigenes Fenster. Elemente über `descendants(matching: .any)[id]`
  (Lehre aus FocusBlox, `docs/reference/learnings-focusblox.md`), Bedienung mit `click()` statt `tap()`.
- **Aufgaben:** drei Aufgaben („Steuerbescheid morgen prüfen“, „Anna wegen Sonntag anrufen“, „Rasen mähen“) über
  `startCaptureField`: Feld anklicken, `typeText(text + "\n")`, danach warten, bis das Feld leer ist.
- **Fotos** mit `window.screenshot()` (nicht `app.screenshot()`, das auf dem Mac den ganzen Bildschirm nimmt), als
  `XCTAttachment` mit `lifetime = .keepAlways`: `mac-gallery-<light|dark>-1-start` (Startseite),
  `mac-gallery-<light|dark>-2-list-new` (Klick auf `viewRow_new`), `mac-gallery-<light|dark>-3-detail` (Klick auf die erste
  `taskRow_*`, Wartepunkt `detailRawTextMarker`).
- **Zusicherungen:** nur „Bildschirm erreicht“ (Element des jeweiligen Bildschirms existiert) und eine Mindestbreite des
  Hauptfensters von **700 pt** (Seitenleiste ab 220 pt plus Liste sichtbar). Jedes Foto wird **vor** der Breitenprüfung
  angehängt, damit auch ein zu schmales Fenster Bilder liefert. Die tatsächliche Fenstergröße (Breite × Höhe in pt) wird
  als Textanhang `mac-gallery-<light|dark>-window-size` mitgeschrieben. Die volle Startseite mit rechter Spalte braucht
  mindestens **1120 pt** (Seitenleiste 220 pt + 900 pt, `StartPage.swift`, #473); das ist keine Zusicherung, sondern
  wird in AC-11 am Bild bewertet. Die Bilder sind der Zweck, nicht die Logik.

### Änderung 2 — Job „Mac Gallery (macOS)“ in `ci.yml`

`name: Mac Gallery (macOS)`, `runs-on: xcode-27`, Schritte:

1. `actions/checkout`, `uses: ./.github/actions/select-xcode-27`, `brew install xcodegen`, `xcodegen generate`.
2. **Automationsmodus:** `sudo automationmodetool enable-automationmode-without-authentication` und
   `DevToolsSecurity -enable`, jeweils vor dem Testschritt (Apple-Forum 693850: sonst „Timed out while enabling
   automation mode“). Ob das Image ihn schon gesetzt hat, ist offen; der Schritt kostet nichts.
3. **Test:** `xcodebuild test -project LooseEnds.xcodeproj -scheme LooseEnds -destination 'platform=macOS'
   -only-testing:LooseEndsUITests/MacGalleryTests -parallel-testing-enabled NO -resultBundlePath MacGallery.xcresult`
   mit `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS=` (ad hoc, ohne
   eingeschränkte Rechte wie iCloud und `aps-environment`; sonst kann macOS die App beim Start beenden, und der
   XCTRunner braucht eine gültige Signatur). Unter `--ui-testing` liegt der Speicher ohnehin im Arbeitsspeicher.
   **Rückfall**, falls das scheitert: `CODE_SIGNING_ALLOWED=NO` wie im Unit-Job. Die Entitlements werden nur im
   CI-Aufruf überschrieben, nie in `project.yml` oder der `.entitlements`-Datei.
4. **Diagnose** (`if: always()`, `continue-on-error: true`, scheitert nie): Automationsstatus, `DevToolsSecurity -status`,
   Fenster-/Bildschirmgröße des Runners, Auszug aus `log show` für `testmanagerd` und TCC der letzten Minuten.
5. **Export** (`if: always()`): `xcrun xcresulttool export attachments` aus `MacGallery.xcresult`, Filter auf den
   Namenspräfix `mac-gallery-` wie bei der iPhone-Galerie.
6. **Upload** (`if: always()`): `actions/upload-artifact` mit Name `MacGallery`; zusätzlich das `xcresult` als Diagnoseartefakt.

Der Job ist **nicht** `continue-on-error`: Eine Galerie, die still scheitert, ist kein Nachweis. Er läuft parallel zu den
anderen Jobs und ändert keinen von ihnen (Alternative B unten verworfen).

### Änderung 3 — `scripts/test_ci_xcode27.py`

Ein Test (oder eine kleine Gruppe), der `ci.yml` liest und prüft, dass der Job „Mac Gallery (macOS)“ existiert und
(a) `runs-on: xcode-27` mit der Action hat, (b) nur `-only-testing:LooseEndsUITests/MacGalleryTests` aufruft (kein
breiteres `-only-testing`), (c) `automationmodetool enable-automationmode-without-authentication` vor dem Testschritt
steht, (d) Diagnose, Export und Upload `if: always()` tragen und der Artefaktname `MacGallery` lautet, (e) der Job nicht
`continue-on-error` ist, (f) die Signaturargumente im Aufruf stehen. Dazu: die bestehenden drei Jobnamen und der
`ui-smoke`-Job sind unverändert (der vorhandene Test `test_check_names_unchanged` bleibt grün).

### Änderung 4 — `CLAUDE.md`

Ein Satz im CI-Abschnitt: Der Job „Mac Gallery (macOS)“ fotografiert die Mac-App (`MacGalleryTests`, Artefakt
`MacGallery`, Bilder `mac-gallery-*`); Mac-Bilder entstehen nur dort, nie auf Hennings Mac.

### Experiment und Rückfälle

| Unbekannt | Geklärt durch | Rückfall |
|---|---|---|
| Lässt der `xcode-27`-Runner Mac-UI-Automation zu (Automationsmodus, TCC)? | erster CI-Lauf, Diagnoseschritt | Zusätzliche Schritte nach den Hinweisen aus der Diagnose (Apple-Forum 793307, Bitrise); lässt sich die Automation nicht freischalten, wird das Ticket mit dem Befund offen gelassen und Alternative C (`ImageRenderer`) neu bewertet |
| Reicht die ad hoc Signatur ohne Entitlements? | erster CI-Lauf | `CODE_SIGNING_ALLOWED=NO` wie im Unit-Job |
| Welche Fenstergröße entsteht ohne `defaultSize`? | Anhang `window-size`, Zusicherung ≥ 700 pt, Bilder (volle Startseite ab 1120 pt) | Zu kleines Fenster: eigenes Ticket für `defaultSize` an `LooseEndsApp` (Alternative D), **nicht** in diesem Schnitt |
| Färbt `-AppleInterfaceStyle Dark` Titelleiste und Seitenleiste mit? | Bilder dunkel | Befund beschreiben; ohne Wirkung bleibt `--ui-testing-dark` allein, mit Vermerk im Bericht |

### Abnahme

- **Stufe 1:** `python3 scripts/test_ci_xcode27.py` grün; „Mac Gallery (macOS)“ im CI-Lauf auf dem PR-Zweig grün.
- **Stufe 2:** die Bilder aus dem Artefakt `MacGallery` herunterladen, öffnen und beschreiben (je Bild: was zu sehen
  ist, hell/dunkel, Fenstergröße). Es gibt **keinen lokalen Mac-Start**: Hennings Mac ist tabu (Regel „nur auf sein
  Wort“).
- Lauf auf `main` nach dem Merge liefert die Bilder (DoD-Punkt 4 des Issues).
- Kein Pfad der Geräteliste berührt.

### Alternativen

| Alternative | Pro | Contra |
|---|---|---|
| **A. Eigener Job (gewählt)** | Fehler getrennt, bestehende Jobs unverändert | Ein Runner mehr auf dem knappen Vorschau-Label (Mac-Lauf nur Minuten) |
| B. Schritte im Unit-Job | Kein zusätzlicher Runner | Ändert einen belegt grünen Job; ein Experiment macht ihn rot |
| C. `ImageRenderer`-Bilder im Unit-Test | Keine UI-Automation, kein TCC | Seitenleiste, Werkzeugleiste und Fensterrahmen werden nicht gezeichnet, also kein echtes „Heute“ |
| D. Fenstergröße in der App festlegen (`defaultSize`) | Gleich große Bilder | Produktänderung an `LooseEndsApp` nur für Fotos; erst, wenn der erste Lauf zu kleine Fenster zeigt (eigenes Ticket) |
| E. Lokal auf Hennings Mac | Schnell | Ausgeschlossen (Henning, 2026-10-17) |

## Test Plan

Werkzeug-Änderung ohne geändertes Produktverhalten. Geprüft wird die CI-Konfiguration (pytest) und der Galerie-Test
selbst; der eigentliche Nachweis ist der CI-Lauf mit angesehenen Bildern.

### Automated Tests (TDD RED)

- [ ] Test 1 (pytest, RED vor der Änderung): GIVEN `scripts/test_ci_xcode27.py` mit neuem Test WHEN er gegen `ci.yml` ohne den Job läuft THEN ist er rot; nach Änderung 2 grün. Er prüft: Job „Mac Gallery (macOS)“ auf `xcode-27` mit der Action `select-xcode-27`; Aufruf nur mit `-only-testing:LooseEndsUITests/MacGalleryTests`; `automationmodetool enable-automationmode-without-authentication` steht vor dem Testschritt; Diagnose-, Export- und Upload-Schritt mit `if: always()`; Artefaktname `MacGallery`; kein `continue-on-error` am Job; Signaturargumente `CODE_SIGN_IDENTITY=-`, `CODE_SIGN_STYLE=Manual`, `DEVELOPMENT_TEAM=`, `CODE_SIGN_ENTITLEMENTS=`; bestehende Jobnamen und `ui-smoke` unverändert.
- [ ] Test 2 (`MacGalleryTests`, nur macOS): `testGalleryLight` und `testGalleryDark`. Zusicherungen: Startseite, Liste „Neu“ und Detail sind erreicht (Elemente existieren); das Hauptfenster (das Fenster mit `viewRow_new`) ist mindestens 700 pt breit; die Fenstergröße steht als Textanhang `mac-gallery-<light|dark>-window-size` im Ergebnis; jedes Foto wird vor der Breitenprüfung angehängt. Fotos: `mac-gallery-<light|dark>-1-start`, `-2-list-new`, `-3-detail`, jeweils per `window.screenshot()` des Hauptfensters. Der Test läuft nur im CI-Job (RED: vor Änderung 2 gibt es keinen Lauf, vor Änderung 1 keine Klasse).
- [ ] Test 3 (lokal, Syntax): GIVEN der geänderte `ci.yml` WHEN sie als YAML geparst wird (`actionlint`, falls vorhanden, sonst `python3 -c "import yaml…"`) THEN gibt es keinen Fehler, und `bash -n` auf den Schrittblöcken des neuen Jobs ist fehlerfrei.
- [ ] Test 4 (lokal, Übersetzung für iOS): GIVEN `MacGalleryTests.swift` WHEN `./scripts/sim.sh build` und der iOS-Test-Build laufen THEN übersetzt die Datei (leer unter iOS) ohne Fehler, und `-only-testing:LooseEndsUITests` unter iOS enthält die Klasse nicht.
- [ ] Test 5 (CI, echter Lauf): GIVEN der PR-Zweig WHEN `CI` läuft THEN ist „Mac Gallery (macOS)“ grün und das Artefakt `MacGallery` enthält die Bilder (AC-5 bis AC-11).

## Acceptance Criteria

- **AC-1:** `MacGalleryTests` existiert in `LooseEndsUITests/MacGalleryTests.swift`, die ganze Datei steht in `#if os(macOS)`, und sie enthält zwei Tests (hell und dunkel). Nachweis: Quelltext im Diff; Test 4 (iOS-Build übersetzt, Klasse fehlt im iOS-Lauf).
- **AC-2:** Der Job `UI Smoke (iOS Simulator)` ist unverändert und führt `MacGalleryTests` nicht aus. Nachweis: Diff von `ci.yml` zeigt keine Änderung am Job `ui-smoke`; im CI-Protokoll von UI Smoke taucht `MacGalleryTests` nicht auf; pytest-Test aus Test 1.
- **AC-3:** Der neue Job „Mac Gallery (macOS)“ läuft auf `runs-on: xcode-27` mit der Action `select-xcode-27`, ist nicht `continue-on-error` und ruft `xcodebuild` nur mit `-only-testing:LooseEndsUITests/MacGalleryTests` auf. Nachweis: pytest-Test aus Test 1; Protokollzeile `Xcode 27.0` im Lauf.
- **AC-4:** Vor dem Testschritt läuft `sudo automationmodetool enable-automationmode-without-authentication`; der Testaufruf trägt `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS=`. Scheitert diese Signatur im Lauf, ist der Rückfall `CODE_SIGNING_ALLOWED=NO` und wird im Bericht benannt. Nachweis: pytest-Test aus Test 1; Quelltext des Schritts.
- **AC-5:** Nach dem Lauf liegt das Artefakt `MacGallery` vor; Diagnose-, Export- und Upload-Schritt laufen mit `if: always()`, der Diagnoseschritt scheitert nie. Nachweis: pytest-Test aus Test 1; Artefaktliste des Laufs (`gh run view`).
- **AC-6:** Das Artefakt enthält sechs Bilder: `mac-gallery-light-1-start`, `mac-gallery-light-2-list-new`, `mac-gallery-light-3-detail` und die drei `mac-gallery-dark-*`. Jedes ist ein Foto des Hauptfensters (das Fenster mit `viewRow_new`), nicht des ganzen Bildschirms und nicht des Menüleisten-Panels. Nachweis: Dateiliste des heruntergeladenen Artefakts; Bilder geöffnet.
- **AC-7:** Die iPhone-Galerie und die übrigen Jobs bleiben unverändert: `Unit Tests (macOS destination)`, `Build (iOS Simulator)`, `UI Smoke (iOS Simulator)` heißen weiter so, laufen grün und der Artefaktname `DesignGallery` ist unverändert. Nachweis: `gh pr checks`; Diff von `ci.yml` zeigt nur den hinzugefügten Job; bestehender Test `test_check_names_unchanged`.
- **AC-8:** `project.yml`, jede `*.entitlements` und jede `Info.plist` sind unverändert, ebenso `LooseEnds/App/LooseEndsApp.swift`. Nachweis: `git diff --name-only` nennt genau `LooseEndsUITests/MacGalleryTests.swift`, `.github/workflows/ci.yml`, `scripts/test_ci_xcode27.py`, `CLAUDE.md` (plus Workflow-Artefakte unter `docs/`).
- **AC-9:** `python3 scripts/test_ci_xcode27.py` ist grün, einschließlich des neuen Tests, der vor Änderung 2 rot war (RED vor GREEN belegt) und alle Prüfpunkte aus Test 1 abdeckt. Nachweis: Testausgabe vorher und nachher; Unit-Job der CI führt die Skript-Tests aus.
- **AC-10:** „Mac Gallery (macOS)“ ist im CI-Lauf auf dem PR-Zweig grün, ohne Wiederholung. Beide Tests bestehen; das Hauptfenster ist mindestens 700 pt breit. Nachweis: Lauf-ID, Protokollzeilen des Testschritts, Diagnoseschritt (Automationsstatus).
- **AC-11:** Die Bilder aus dem PR-Lauf sind heruntergeladen, geöffnet und beschrieben: je Bild, was zu sehen ist (Seitenleiste, Startseite mit Aufgaben, Liste „Neu“, Detail), ob hell/dunkel stimmt (auch Titelleiste und Seitenleiste im Dunkelbild), und die tatsächliche Fenstergröße aus dem Anhang `window-size`. Ist das Fenster schmaler als 1120 pt (die rechte Spalte der Startseite fehlt dann), wird ein eigenes Ticket für `defaultSize` angelegt und hier nichts geändert. Nachweis: Beschreibung im Bericht, nicht nur Dateiliste.
- **AC-12:** Nach dem Merge liefert ein CI-Lauf auf `main` das Artefakt `MacGallery` mit den Bildern (DoD-Punkt 4 aus #511). Nachweis: Lauf-ID auf `main`, Artefaktliste.
- **AC-13:** `CLAUDE.md` nennt im CI-Abschnitt in einem Satz den Job „Mac Gallery (macOS)“, das Artefakt `MacGallery` und dass Mac-Bilder nur dort entstehen. Nachweis: Diff.
- **AC-14:** Abnahmestufe: Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2 (Bilder aus dem Artefakt angesehen); auf Hennings Mac oder seinen Geräten läuft nichts. Nachweis: `git diff --name-only` aus AC-8.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reine CI- und Test-Werkzeugänderung ohne Architekturwirkung; es wird keine bestehende Entscheidung gekippt, und an der App ändert sich nichts.
- **Rationale:** Ein eigener Job (Regelweg: Konfiguration und ein UI-Test, kein Modell) hält das Experiment von den belegt grünen Jobs fern; die Signatur wird nur im CI-Aufruf überschrieben, damit die Geräteliste unberührt bleibt. Eine Änderung der Fenstergröße in der App wäre eine Produktentscheidung und gehört in ein eigenes Ticket.

## Changelog

- 2026-10-17: Mindestbreite beziffert (700 pt Zusicherung, 1120 pt volle Startseite, Größe als Anhang), nach PO-Briefing.
- 2026-10-17: Initial spec created (Analyse in `docs/context/feat-511-ci-mac-galerie.md`).
