# Context: feat-511-ci-mac-galerie

## Request Summary
Die CI fotografiert die Mac-App wie die iPhone-Galerie (#182): Startseite, Liste „Neu“ und Detail, jeweils hell und
dunkel, als Artefakt `MacGallery`. Damit gibt es für die Mac-Tickets (#477–#480) ein Bild von „Heute“ und einen
Nachweis, ohne Hennings Mac (Henning, 2026-10-17, in #477). Teil von Epic #467.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsUITests/DesignGalleryTests.swift` | Vorbild (#182): `launch(dark:)` mit `--ui-testing`, `-AppleLanguages (en)`, `-contextsEmptiedByUser NO`, `--ui-testing-dark`; `shot()` legt `XCTAttachment` mit `lifetime = .keepAlways` und Namen `gallery-*` an. iPhone-Abläufe (Sheet, `swipeLeft`, `navigationBars.buttons`) gibt es so auf dem Mac nicht |
| `.github/workflows/ci.yml` | Job `ui-smoke` (Z. 99 ff.) läuft `-only-testing:LooseEndsUITests` im iPhone-Simulator; Schritte „Export design gallery“ (xcresulttool export attachments + Python-Filter auf `gallery-`) und „Upload design gallery“ sind die Vorlage. Job `unit-tests` zeigt, dass `-destination 'platform=macOS'` mit `CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM=` auf dem Runner baut und Unit-Tests ausführt |
| `.github/actions/select-xcode-27` | Pflicht in jedem Job (Test `test_every_job_runs_on_xcode_27_with_the_action`) |
| `scripts/test_ci_xcode27.py` | Prüft alle Jobs in `ci.yml`: `runs-on: xcode-27` + Action, Jobnamen „Unit Tests (macOS destination)“, „Build (iOS Simulator)“, „UI Smoke (iOS Simulator)“ unverändert. Ein neuer Job muss diese Tests bestehen; ein eigener Test für den neuen Job gehört hierher |
| `project.yml` | `LooseEndsUITests` ist schon `supportedDestinations: [iOS, macOS]` (Z. 318 ff.), Host `LooseEnds`. Kein Hardened Runtime gesetzt. `CODE_SIGN_STYLE: Automatic`, Team `XK87E2B3VR`. Steht auf der Geräteliste: möglichst nicht ändern |
| `LooseEnds/LooseEnds.entitlements` | App-Sandbox, App-Gruppe, iCloud/CloudKit, `aps-environment`, Siri, Kalender, Mikrofon: eingeschränkte Rechte, die ohne Bereitstellungsprofil auf macOS den Start verhindern können |
| `Shared/Persistence/ModelContainerFactory.swift` | Unter `--ui-testing` Speicher nur im Arbeitsspeicher, `cloudKitDatabase: .none`; unsignierte Bauten ohne App-Gruppen-Recht fallen auf lokalen Speicher zurück (#55) |
| `LooseEnds/App/LooseEndsApp.swift` | `--ui-testing-dark` → `.preferredColorScheme(.dark)` am Fensterinhalt; Mac: `Settings`-Szene, `MenuBarExtra` (Menüleisten-Panel), `MacAppDelegate` |
| `LooseEnds/App/ContentView.swift` | Mac-Zweig: `NavigationSplitView`, Seitenleiste 220–300 pt; Erfassen-Knopf `captureButton` in der Detailspalte; auf der Startseite (breit) fokussiert er das eingebettete Feld `startCaptureField` statt eines Sheets |
| `LooseEnds/Views/StartPage.swift` | `startPage`, `startHeader`, `startHeadline`, `startCaptureField` (Z. 151) |
| `LooseEnds/Views/SidebarView.swift` | Mac-Zweig (Z. 51 ff.) mit `IndexLine(id: "viewRow_<kind>")` — Einstieg in „Neu“ |
| `LooseEnds/Mac/MenuBarCapture.swift` | Anmeldeobjekt (Login Item) unter Tests und `--ui-testing` abgeschaltet (Z. 99) |
| `LooseEndsUITests/SettingsSmokeTests.swift`, `StartScreenInteractionTests.swift` | Haben schon `#if os(macOS)`-Zweige; `DueNotificationTapTests`, `PlaceNotificationTapTests` sind `#if os(iOS)` — das UI-Testziel übersetzt also für den Mac |
| `docs/reference/learnings-focusblox.md` (Z. 200–212) | FocusBlox-Lehre: Mac-UI-Tests in `NavigationSplitView` — Seitenleiste über `outlineRows`/`buttons`, Inhalt über `descendants(matching: .any)[id]` |
| `docs/context/feat-477-mac-papierstil.md` | Wartet auf diese Bilder (Heute-Bild und Nachweis) |

## Existing Patterns
- Galerie = ein Test, der nur Zustände erreicht und fotografiert; Zusicherungen nur, dass jeder Bildschirm erreicht ist.
- Hell/Dunkel über eigenes Startargument der App, nicht über Systemschalter (iPhone-Simulator ignorierte `XCUIDevice.appearance`, #182).
- Artefakt-Export: `xcresulttool export attachments` → `manifest.json` → nach Namenspräfix filtern.
- Diagnose-Schritte in der CI scheitern nie (`continue-on-error`, `if: always()`).
- Plattformspezifische UI-Tests per `#if os(...)` um die ganze Datei.

## Dependencies
- Upstream: Xcode 27.0 auf `xcode-27`, XcodeGen, `xcresulttool`, XCTest-UI-Automatisierung auf macOS (testmanagerd, Automationsmodus, TCC).
- Downstream: #477, #478, #479, #480 nutzen die Bilder als „Heute“ und Nachweis. Die iPhone-Galerie und `ui-smoke` dürfen sich nicht ändern.

## Existing Specs
- `docs/specs/tooling/fix-178-ci-xcode27.md` — CI auf `xcode-27`, Pflicht-Action.
- `docs/specs/tooling/fix-172-ui-tests-first-try.md` — UI-Tests beim ersten Versuch grün.
- Keine Spec für die iPhone-Galerie (#182 lief ohne).

## Recherche (Internet, 2026-10-17)
- **Automationsmodus:** Seit Monterey, verschärft ab Sequoia, fragt testmanagerd vor Mac-UI-Tests nach einem
  Passwort; in der CI endet das als „Timed out while enabling automation mode“. Apples Antwort (DTS) ist
  `sudo automationmodetool enable-automationmode-without-authentication` vor dem Test
  ([Apple-Forum 693850](https://developer.apple.com/forums/thread/693850),
  [Apple-Forum 793307](https://developer.apple.com/forums/thread/793307),
  [Bitrise](https://support.bitrise.io/en/articles/9676606-enabling-ui-automation-for-macos-tests)).
  Ob das GitHub-Image ihn schon gesetzt hat, ist offen — der Schritt kostet nichts und gehört in den Job.
- **Signatur / Hardened Runtime:** Mac-UI-Tests scheitern mit „mapped file has no Team ID“, wenn Hardened Runtime
  an ist ([Jesse Squires](https://www.jessesquires.com/blog/2020/02/23/mac-app-tests-fail-with-hardened-runtime/));
  hier ist er nicht gesetzt. Gängiger CI-Weg ist „Sign to Run Locally“ (Ad-hoc, `CODE_SIGN_IDENTITY=-`).
  Ob `CODE_SIGNING_ALLOWED=NO` (wie im Unit-Job) für den UI-Test-Runner auf dem Mac reicht, ist offen.
- **TCC:** Bedienrechte, Automation und Bildschirmaufnahme sind Systemdialoge außerhalb des Prozesses; XCUITest kann
  sie nicht wegklicken. Gehostete GitHub-Runner sind interaktive Sitzungen, eine Anzeige ist da
  ([tessl xcuitest-suite, macOS](https://tessl.io/registry/testland/xcuitest-suite/files/references/macos.md)).

## Risks & Considerations
- **Start mit Rechten ohne Profil:** Ad-hoc signiert mit iCloud/App-Gruppe/`aps-environment` kann macOS die App beim
  Start beenden. Möglicher Ausweg nur im CI-Aufruf (z. B. ohne Entitlements übersetzen) — `project.yml` und
  `*.entitlements` stehen auf der Geräteliste und sollen unberührt bleiben.
- **Automationsmodus / TCC** auf dem `xcode-27`-Vorschau-Image unbekannt → erster Lauf ist ein Experiment.
- **Mac-Ablauf anders als iPhone:** Erfassen über `startCaptureField` statt Sheet, Seitenleiste statt Liste,
  kein Wischen, kein Zurück-Knopf. Neue Testdatei, keine Kopie der iPhone-Datei.
- **Dunkelmodus:** `.preferredColorScheme` färbt den Fensterinhalt, ob Fensterrahmen/Leiste mitgehen, ist offen
  (Alternative: `-AppleInterfaceStyle Dark` als Argument).
- **Bildausschnitt:** `app.screenshot()` auf dem Mac nimmt ggf. den ganzen Bildschirm; Fenster-Foto
  (`app.windows.firstMatch.screenshot()`) und feste Fenstergröße sind zu prüfen.
- **Menüleisten-Panel und Login Item:** unter `--ui-testing` aus bzw. nicht im Weg — prüfen.
- **iPhone unverändert:** Neue Klasse muss `#if os(macOS)` sein, sonst läuft sie im `ui-smoke`-Job mit.
  Der Mac-Job muss `-only-testing:LooseEndsUITests/MacGalleryTests` nehmen, sonst laufen alle UI-Tests auf dem Mac.
- **Runner-Kapazität:** zusätzlicher paralleler Job auf dem knappen `xcode-27`-Vorschau-Label verlängert ggf.
  Wartezeiten; Mac-Bau dauert aber nur Minuten statt 34–39 Min. UI Smoke.
- **Nachweis nur in der CI:** Mac ist Hennings Gerät (Regel „nur auf sein Wort“); lokal wird nichts auf dem Mac
  gestartet. Belege entstehen ausschließlich aus CI-Läufen.
- **Geräteliste:** Schnitt berührt voraussichtlich nur `LooseEndsUITests/` und `.github/` (+ `scripts/test_ci_xcode27.py`)
  → keine Stufe 3.

## Analysis

### Type
Feature (Werkzeug/CI, keine sichtbare Änderung an der App → kein Entwurf vor der Spec nötig)

### Stand vor dem Schnitt (2026-10-17)
- Auf `origin/main` (85ed8a2) nachgezogen; kein offener PR, kein anderer Zweig zu #511.
- Kein Mac-UI-Test ist je gelaufen: die `#if os(macOS)`-Zweige in `SettingsSmokeTests`/`StartScreenInteractionTests`
  sind nur `XCTSkip`. Belegt ist nur, dass das UI-Testziel für macOS übersetzt (Schema baut es beim Unit-Job mit) und
  dass die unsignierte App auf dem Runner startet (Unit-Tests hosten in `LooseEnds.app`, `CODE_SIGNING_ALLOWED=NO`, grün).
- Mac-Aufbau (`ContentView`): zwei Spalten. Seitenleiste mit `viewRow_<kind>`; Detailspalte = `StartPage` bei leerer
  Auswahl, sonst `TaskListView` in einem `NavigationStack`, Zeilen sind `NavigationLink` (`taskRow_*`) → Detail
  (`detailRawTextMarker`). Erfassen auf der breiten Startseite über `startCaptureField` (`onSubmit` speichert, Feld leert sich).
- `WindowGroup(id: "main")` ohne `defaultSize`; `MenuBarExtra` existiert auch unter Tests (eigenes Fenster), Login Item
  unter `--ui-testing` aus.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacGalleryTests.swift` | CREATE | ganze Datei `#if os(macOS)`; zwei Tests (hell, dunkel), je 3 Aufgaben erfassen, Fotos `mac-gallery-<hell/dunkel>-1-start`, `-2-list-new`, `-3-detail` vom Hauptfenster |
| `.github/workflows/ci.yml` | MODIFY | neuer Job „Mac Gallery (macOS)“ auf `xcode-27` mit Pflicht-Action; Automationsmodus, Test, Diagnose, Export, Upload `MacGallery` |
| `scripts/test_ci_xcode27.py` | MODIFY | Test für den neuen Job (Label + Action, nur `MacGalleryTests`, Automationsmodus vor dem Test, Export/Upload `if: always()`, bestehende Jobnamen unverändert) |
| `CLAUDE.md` | MODIFY | ein Satz unter „Ship/CI“: wo die Mac-Bilder entstehen |

### Scope Assessment
- Files: 4
- Estimated LoC: ca. +230 / -0
- Risk Level: MEDIUM — die App bleibt unberührt, bestehende Jobs unverändert; unsicher ist allein, ob der
  `xcode-27`-Runner Mac-UI-Automation zulässt (erster CI-Lauf ist das Experiment).
- Geräteliste: kein Pfad berührt (`project.yml`, `*.entitlements` bleiben unverändert) → Abnahme endet nach Stufe 2,
  der Nachweis ist der CI-Lauf mit angesehenen Bildern.

### Technical Approach (Empfehlung)
1. **Eigener Job**, parallel zu den anderen, nicht `continue-on-error`: eine Galerie, die still scheitert, ist kein Nachweis.
   Er ist kein Pflicht-Check der Zweigregeln (nichts daran wird geändert).
2. **Signatur:** `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS=` auf der
   Befehlszeile: ad hoc, ohne eingeschränkte Rechte (iCloud, `aps-environment`), damit macOS die App nicht beendet und der
   XCTRunner eine gültige Signatur hat. Unter `--ui-testing` ist der Speicher ohnehin im Arbeitsspeicher. Rückfall, falls
   das scheitert: `CODE_SIGNING_ALLOWED=NO` wie im Unit-Job.
3. **Vor dem Test:** `sudo automationmodetool enable-automationmode-without-authentication` und `DevToolsSecurity -enable`;
   ein nie scheiternder Diagnoseschritt (Automationsstatus, testmanagerd-/TCC-Log) nach dem Test.
4. **Test:** `click()` statt `tap()`; Elemente über `descendants(matching: .any)[id]`; nach jedem `typeText(text + "\n")`
   warten, bis das Feld leer ist. Hauptfenster per Prädikat wählen (das Fenster, das `viewRow_new` enthält), nicht
   `firstMatch` (Menüleisten-Panel). Foto mit `window.screenshot()`, nicht `app.screenshot()` (ganzer Bildschirm).
   Zusicherung einer Mindestbreite, damit Seitenleiste und breite Startseite sichtbar sind.
5. **Hell/Dunkel:** `--ui-testing-dark` plus `-AppleInterfaceStyle Dark` (färbt auch Titelleiste und Seitenleiste);
   hell ohne beides. Zwei getrennte Tests, damit ein Teilerfolg trotzdem Bilder liefert.
6. **Export:** wie bei der iPhone-Galerie über `xcresulttool export attachments`, Filter `mac-gallery-`.

### Alternativen
| Alternative | Pro | Contra |
|---|---|---|
| **A. Eigener Job (Empfehlung)** | Fehler getrennt, bestehende Jobs unverändert | ein Runner mehr auf dem knappen Vorschau-Label (Mac-Lauf nur Minuten) |
| B. Schritte im Unit-Job | kein zusätzlicher Runner | ändert einen belegt grünen Job; ein Experiment macht ihn rot |
| C. `ImageRenderer`-Bilder im Unit-Test | keine UI-Automation, kein TCC | Seitenleiste, Werkzeugleiste, Fensterrahmen werden nicht gezeichnet → kein echtes „Heute“ |
| D. Fenstergröße in der App festlegen (`defaultSize`) | gleich große Bilder | Produktänderung an `LooseEndsApp` nur für Fotos; erst, wenn der erste Lauf zu kleine Fenster zeigt (eigenes Ticket) |
| E. Lokal auf Hennings Mac | schnell | ausgeschlossen (Henning, 2026-10-17) |

### Dependencies
- Upstream: Xcode 27.0 auf `xcode-27`, XcodeGen, `xcresulttool`, Automationsmodus/TCC des Runner-Images.
- Downstream: #477–#480 nutzen `MacGallery` als „Heute“ und Nachweis.

### Recherche-Quellen
- Apple-Forum 693850 (testmanagerd fragt nach Passwort, `automationmodetool`), Apple-Forum 793307, Bitrise-Artikel
  „Enabling UI automation for macOS tests“, Jesse Squires zu Hardened Runtime (s. Abschnitt Recherche oben).
- Nicht gefunden: ob das GitHub-Image den Automationsmodus schon freischaltet → Schritt kostet nichts, bleibt drin.

### Open Questions
- Keine Produktfragen. Technisch offen und nur per CI-Lauf klärbar: Automationsmodus/TCC auf `xcode-27`, Fenstergröße
  ohne `defaultSize`. Beides wird in der Spec als Experiment mit Rückfall festgehalten.
