# Context: ci-178-xcode27

## Request Summary
Issue #178: Die CI soll mit derselben Xcode-Version (27.0) und demselben Deployment-Ziel (27.0) prüfen,
mit denen Henning baut. Die stille Absenkung auf 26.0 (`sed` auf `project.yml`) verschwindet. Anlass ist
#25 (Reminders-App-Schema). Dessen Umsetzung steht hinter einem Compiler-Schalter, den die CI auf
Xcode 26.6 nie übersetzt. Die Umsetzung ist angehalten, bis dieses Ticket erledigt ist (Kommentar auf #25).

## Recherche (2026-10-05)
- [GitHub Changelog 2026-09-10: Xcode 27 runner image now runs on macOS 27](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27/)
  - Die Labels `xcode-27` und `xcode-27-xlarge` gibt es nur auf arm64. Der Status ist weiter „public preview“.
  - Seit September läuft das Image auf **macOS 27** (vorher macOS 26).
- [Public Preview 2026-07-16](https://github.blog/changelog/2026-07-16-xcode-27-runner-image-now-in-public-preview/),
  [runner-images #14404](https://github.com/actions/runner-images/issues/14404),
  letztes Release [xcode-27-arm64/20260928.0222](https://github.com/actions/runner-images/releases/tag/xcode-27-arm64/20260928.0222).
- Ein Image entspricht einer Xcode-Hauptversion. Laut #174-Befund liegen darauf Xcode 27.0 (`Xcode_27.app`, 27A266a),
  27.1 und eine 27.2-Beta. Die bisherige Auswahl `ls -d Xcode_27* | sort -V | tail -1` würde die **Beta** wählen.
- Folge aus macOS 27: Der Unit-Job (`-destination 'platform=macOS'`) kann die Tests jetzt auf dem Mac-Host mit
  Ziel 27.0 ausführen. Auf macOS 26 wäre das nicht gegangen (CLAUDE.md: Der Mac hostet die Tests nur, wenn
  macOS ≥ Target).

## Related Files
| Datei | Relevanz |
|------|-----------|
| `.github/workflows/ci.yml` | Drei Jobs (`unit-tests`, `ios-build`, `ui-smoke`), alle `runs-on: macos-26`, jeder mit dem Schritt „Select newest Xcode (27 when the image has it)“ samt `sed`-Absenkung. Der Kopfkommentar beschreibt die Absenkung. |
| `.github/workflows/speech-stress.yml` | Ebenfalls `runs-on: macos-26` mit derselben Auswahl und `sed`-Absenkung (Zeile 29–41). Läuft bei jeder PR, die die Spracherfassung berührt. Gehört zum DoD-Punkt „kein `sed` mehr in der CI“. |
| `.github/workflows/testflight.yml` | **Vorbild aus #174:** `runs-on: xcode-27`, `sudo xcode-select -s /Applications/Xcode_27.app`, Versionsprüfung `xcodebuild -version` = „Xcode 27.0“, sonst `::error::` und Abbruch. |
| `docs/specs/tooling/fix-174-testflight-ios27.md` | Spec zu #174 mit Befund, Vorgehen bei Wegfall des Vorschau-Labels und Begründung für die feste Version statt der neuesten. |
| `docs/reference/testflight.md` | Abschnitt „Wenn das Vorschau-Image wegfällt oder umbenannt wird“. Kann für die CI mitgenutzt oder verlinkt werden. |
| `CLAUDE.md` (Zeile 115–118) | Abschnitt CI beschreibt die Absenkung auf 26.0 und `#available`-Guards. Muss laut DoD nachgezogen werden. |
| `docs/project/04-stand.md` (Zeile 128) | #25 „braucht Xcode 27 in der CI“. |
| `Measurement/MeasurementRun.swift:228` | Einziger `#if compiler(>=6.4)`-Schalter im Repo. Nach diesem Ticket entbehrlich. Ob er mit entfernt wird, entscheidet die Analyse (Umfang). |
| `scripts/sim.sh` | Lokale Destinationswahl (Mac-Host nur bei macOS ≥ Target, Simulator nur mit Laufzeit ≥ Target). Die CI nutzt das Skript nicht, sie hat eigene `xcodebuild`-Aufrufe. |

## Existing Patterns
- Die Xcode-Version wird fest gewählt und geprüft, mit Abbruch bei Abweichung (testflight.yml, #174). Es wird nicht „die neueste“ genommen.
- Die Simulatorwahl im UI-Smoke nimmt per `simctl … -j` „iPhone 17“, sonst das erste iPhone.
- Jeder Job erzeugt das Projekt mit `xcodegen generate`. Signieren ist aus (`CODE_SIGNING_ALLOWED=NO`, `DEVELOPMENT_TEAM=`).

## Dependencies
- Upstream: GitHub-Runner-Image `xcode-27` (Vorschau, arm64, macOS 27), XcodeGen über brew, xcbeautify.
- Downstream:
  - Jede PR, denn alle CI-Checks müssen grün sein, bevor gemergt wird (04-stand.md).
  - Die PR zu #25 (Compiler-Schalter entfällt danach).
  - `speech-stress.yml`.
- Branch-Schutz: Für `main` gibt es keinen (API 404). Die Check-Namen dürfen sich also ändern, besser bleiben sie trotzdem gleich.

## Existing Specs
- `docs/specs/tooling/fix-174-testflight-ios27.md`: gleiche Umstellung für TestFlight
- `docs/specs/tooling/fix-172-ui-tests-first-try.md`: UI-Tests beim ersten Versuch grün (CI-Stabilität)

## Risks & Considerations
1. **Vorschau-Image:** Das Label kann wegfallen oder umbenannt werden, dann startet kein Runner. Vorgehen wie bei #174.
   Wartezeit und Laufzeit sind gegen `macos-26` zu messen (DoD-Teil 3, Gedächtnis: UI-Smoke dauert heute ca. 36 Min).
2. **Simulatoren:** Auf dem Image muss es „iPhone 17“ mit iOS 27.0 geben. Fehlt es, greift der Fallback auf das erste
   iPhone, auch eines mit falscher Laufzeit. Bei Ziel 27.0 lehnt Xcode solche Ziele ab.
3. **Simulator mit Modell:** iOS-27-Simulatoren haben Apple Intelligence. Lokal überschreibt das Modell Titel und
   Felder während der UI-Tests (Gedächtnis „Simulator hat ein Modell“, Folgeticket zu #208). Auf der CI lief bisher
   iOS 26. Mit iOS 27 können UI-Smoke-Tests, die lokal schon wackeln, in der CI rot werden. **Das ist das
   größte Risiko dieses Tickets.**
4. **Neue Warnungen und Fehler:** Unit-Tests auf dem macOS-27-Host mit SDK 27 können Abweichungen zeigen, die auf
   26 verdeckt waren (z. B. iOS-27-Verhalten im Modellzweig). Lokal laufen sie schon mit Xcode 27 grün (320 Tests am 2026-10-05).
5. **Kosten und Wartezeit:** Bei Vorschau-Labels ist die Warteschlange möglicherweise länger.
6. **Kein Rückweg mehr auf 26:** Ohne `sed`-Zweig bricht die CI hart ab, statt still abzusenken. Das ist gewollt.

## Analysis

### Type
Feature (Werkzeug/CI-Umstellung, keine Änderung am Produkt)

### Befunde der Analyse (2026-10-05)
- **Image-Ausstattung belegt** (Readme `xcode-27-arm64/20260928`): `/Applications/Xcode_27.app` = 27.0 (27A266a, Standard,
  auch `Xcode.app` zeigt darauf), daneben `Xcode_27.1_beta.app` (27.1) und `Xcode_27.2_beta.app` (27.2 Beta, Symlink
  `Xcode_27.2.app`). Die bisherige Auswahl `ls … | sort -V | tail -1` hätte also die 27.2-Beta gewählt.
  Simulator-Laufzeit **nur iOS 27.0**, Geräte u. a. **iPhone 17**. Host macOS 27.0, deshalb kann der Unit-Job mit Ziel 27.0 auf dem Mac laufen.
- **Wartezeit auf das Vorschau-Label gemessen** (TestFlight-Läufe 37233766254, 37142589043): 0,1 Min. bis zum Start,
  genauso wie `macos-26` (0,1–0,2 Min.). Keine Warteschlange erkennbar.
- **Ausgangswerte `macos-26`** (Läufe 37330631849, 37321457390 auf `main`): Unit 2,3–3,0 Min., Build 1,3–1,7 Min.,
  UI Smoke 30,2–34,5 Min. Gegen diese Werte wird der erste Lauf auf `xcode-27` verglichen (DoD-Teil 3).
- **Risiko 3 (Simulator mit Modell) ist auf der CI voraussichtlich gegenstandslos:** Apple Intelligence läuft nicht in
  virtuellen Maschinen ([Apple-Forum 787445](https://developer.apple.com/forums/thread/787445)). GitHub-Mac-Runner
  sind VMs auf dem Virtualization Framework ([runner-images #2187](https://github.com/actions/runner-images/issues/2187)).
  Der iOS-27-Simulator auf der CI meldet das Modell also vermutlich als nicht verfügbar, wie heute auf iOS 26. Lokal
  (echter Mac) bleibt der Wettlauf (#208) bestehen. **Belegt wird das im ersten CI-Lauf:** Der Lauf schreibt die
  Verfügbarkeit ins Protokoll. Ist das Modell doch aktiv und wird UI Smoke deshalb rot, hängt dieses Ticket an #208.
- `#if compiler(>=6.4)` in `Measurement/MeasurementRun.swift:228` ist der einzige Schalter. Sein Kommentar
  („CI still builds with Xcode 26“) wird mit diesem Ticket falsch. Ohne Schalter übersetzt die CI den Zweig ab jetzt mit.
- Keine Gerätestufe nötig: `project.yml` bleibt unverändert (die Absenkung lief nur im CI-Schritt), kein Pfad der Geräteliste wird berührt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `.github/actions/select-xcode-27/action.yml` | CREATE | Gemeinsamer Schritt: `xcode-select -s /Applications/Xcode_27.app`, Abbruch mit `::error::` wenn nicht „Xcode 27.0“ (Logik wie testflight.yml). Ersetzt vier gleiche Kopien. |
| `.github/workflows/ci.yml` | MODIFY | Drei Jobs `runs-on: xcode-27`, Auswahl-Schritt → Composite Action, `sed` raus, Kopfkommentar neu. UI Smoke: Simulator **nur** „iPhone 17“ mit Laufzeit iOS 27.0, sonst Abbruch (kein Rückfall auf beliebiges iPhone). Check-Namen bleiben gleich. |
| `.github/workflows/speech-stress.yml` | MODIFY | Gleiche Umstellung (Runner, Auswahl, `sed` raus, Simulatorwahl). |
| `Measurement/MeasurementRun.swift` | MODIFY | `#if compiler(>=6.4)`/`#endif` und den veralteten Kommentar entfernen. |
| `CLAUDE.md` | MODIFY | Abschnitt CI: läuft auf `xcode-27` mit fester 27.0, keine Absenkung, Vorgehen bei Wegfall des Labels (Verweis auf `docs/reference/testflight.md`). `#available`-Satz streichen. |

`testflight.yml` bleibt unverändert (Auslieferungspfad, keine Nebenwirkung in diesem Ticket).

### Scope Assessment
- Files: 5 (1 neu)
- Estimated LoC: +40 / −60
- Risk Level: MEDIUM — kein Produktcode betroffen, aber jede PR hängt an der CI; Vorschau-Image kann wegfallen.

### Technical Approach
1. Composite Action für die feste Xcode-Wahl mit Versionsprüfung (Muster aus #174, eine Stelle statt vier).
2. Alle vier Jobs auf `runs-on: xcode-27`, Absenkung entfernt.
3. Simulatorwahl streng: Laufzeit-Schlüssel `com.apple.CoreSimulator.SimRuntime.iOS-27-0` und Name „iPhone 17“, sonst
   `::error::` mit Liste der vorhandenen Geräte.
4. Compiler-Schalter in `MeasurementRun.swift` entfernen, damit die CI den iOS-27-Zweig übersetzt.
5. Ein Diagnoseschritt im UI-Smoke-Job gibt `xcodebuild -version`, die Simulator-Laufzeit und die
   Gerätebeschreibung ins Protokoll (Beleg für DoD-Teil 1 und 2).
6. Abnahme: PR-Lauf grün in allen drei CI-Jobs plus ein manueller Lauf von `speech-stress` (workflow_dispatch,
   Iterations 3). Zeiten gegen die Ausgangswerte oben in die PR-Beschreibung.

### Alternativen (geprüft, nicht empfohlen)
- **Status quo (`macos-26` + Absenkung):** prüft gegen ein anderes SDK als Henning; #25 bleibt blockiert. Verworfen.
- **Nur Unit + Build auf `xcode-27`, UI Smoke bleibt auf 26:** halbiert das Risiko aus #208, aber die UI-Tests prüfen
  weiter eine 26.0-App. Kippt das Ziel des Tickets. Verworfen.
- **Selbst gehosteter Runner auf Hennings Mac:** einzige Variante mit echtem Modell im Simulator, aber blockiert seinen
  Rechner ~35 Min. pro PR und öffnet seinen Mac für Code aus PRs. Verworfen.
- **Kopien statt Composite Action:** null neue Dateien, aber vier gleiche Blöcke, die bei Wegfall des Labels einzeln
  nachgezogen werden müssen. Verworfen zugunsten einer Stelle.
- **Neueste Xcode-27-Version statt fester 27.0:** wählt heute eine Beta. Verworfen (Begründung aus #174).

### Dependencies
- Upstream: Label `xcode-27` (Vorschau, arm64), Pfad `/Applications/Xcode_27.app`, Simulator iPhone 17 / iOS 27.0.
- Downstream: jede PR (alle Checks), #25 (kann danach weiter), `speech-stress`.

### Open Questions
- keine PO-Fragen. Technisch offen und im ersten Lauf zu belegen: Ist das Modell im CI-Simulator wirklich aus (erwartet: ja)?
  Wenn nein und UI Smoke wird deshalb rot → #208 vorziehen, statt Wiederholungen einzubauen (#172).
