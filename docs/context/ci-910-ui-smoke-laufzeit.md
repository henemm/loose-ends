# Context: ci-910-ui-smoke-laufzeit

## Request Summary
Der CI-Job `UI Smoke (iOS Simulator)` braucht 100–113 min (Schritt „Run UI smoke tests“ rund 85–110 min), die
Nachbarjobs 15–30 min. Ursache finden, größten Posten verkürzen; Ziel mit Beleg unter 60 min (DoD aus #910).

## Befund (Lauf 43200602690, main, 2026-11-12, grün; Artefakt `UITestResults` ausgewertet)
- 98 Tests (11 übersprungen = Mac-Klassen auf iOS) laufen **nacheinander** in einem Simulator
  (`-parallel-testing-enabled NO`, #228): 4675 s reine Testzeit = 78 min. Dazu Bau 7 min, Boot und Beruhigen 7 min.
- Im Schnitt 48 s je Test, auch für triviale. Keine einzelne Klasse und kein einzelner Test ist der Hauptposten:

  | Klasse | s | Tests | s/Test |
  |---|---|---|---|
  | CaptureSmokeTests | 1242 | 26 | 47.8 |
  | StartScreenInteractionTests | 973 | 20 | 48.7 |
  | AccountSettingsTests | 398 | 8 | 49.7 |
  | PlaceSmokeTests | 352 | 7 | 50.2 |
  | DriveSmokeTests | 296 | 4 | 74.1 |
  | CalendarTargetTests | 261 | 3 | 87.1 |
  | FieldsSmokeTests | 261 | 5 | 52.1 |
  | DesignGalleryTests | 183 | 1 | 183.2 |
  | StoreScreenshotsTests | 156 | 1 | 155.5 |
  | OnboardingTests | 107 | 7 | 15.2 |
  | übrige 11 Klassen | rund 440 | 16 | – |

- Aktivitätsprotokoll von `AccountSettingsTests/testSignedOutShowsGroupBelowICloud` (43 s): App-Start bis „idle“ 9 s,
  jedes `waitForExistence` beginnt seine Prüfung erst nach ≥ 1 s Wartezeit (auch wenn das Element da ist), jede
  Abfrage/Suche 0,5–1 s, ein `swipeUp(velocity: .slow)` 1,5 s. Viele kleine Wartezeiten statt eines Hängers.
- Der Runner ist nicht ausgelastet (`host-load.log`: meist unter 50 % CPU, freier Speicher 33–50 %, keine neuen Swapouts):
  die Tests warten, sie rechnen nicht.
- Verlauf: 2026-11-04 (#178) 25 Tests in 34 min (≈ 41 s/Test). Die Laufzeit folgt der Testzahl, nicht einer Verlangsamung.
- Nachbarjobs: `UI iPad` 5 Tests 26 min, `ui-smoke-lang` je 18–20 min (jeweils Bau + Start + 2–5 Tests).

## Related Files
| File | Relevance |
|------|-----------|
| `.github/workflows/ci.yml` (Zeilen 113–338) | Job `ui-smoke`: Boot, `sim_prepare.sh`, Poster-Beruhigung, Host-Load-Sampler, ein `xcodebuild test -only-testing:LooseEndsUITests`, Diagnoseschritte, Galerie-Export, Upload `UITestResults` |
| `.github/workflows/ci.yml` (355–421, 422–483) | `ui-smoke-lang` (Matrix je Sprache) und `ui-ipad`: Vorbild für Matrix und die Composite-Action `prepare-ui-simulator` |
| `.github/actions/prepare-ui-simulator` | gemeinsamer Simulator-Aufbau der Nachbarjobs (der große Job hat ihn noch inline mit zusätzlicher Diagnose) |
| `LooseEndsUITests/*.swift` | 29 Testklassen im Ziel `LooseEndsUITests`; `LooseEndsUITests/Watch` gehört zum Ziel `LooseEndsWatchUITests` (project.yml 372–376) |
| `scripts/sim_prepare.sh` | Simulator-Vorbereitung (#578) |
| `CLAUDE.md` (Abschnitte CI / `ui-smoke`) | beschreibt den Job; bei Umbau nachziehen |

## Existing Patterns
- Matrix-Jobs mit `strategy.matrix`, `fail-fast: false`, Artefakt je Matrixwert (`ui-smoke-${{ matrix.lang }}`).
- Python-Skripte in `scripts/` mit `scripts/test_*.py` daneben, gelesen aus Code (z. B. `shipped_languages.py`).
- Zeitgrenzen: `timeout-minutes` am Job und am Testschritt (#905, derzeit 160/135).

## Dependencies / Dependents
- Upstream: `xcodegen generate`, Simulator iPhone 17 / iOS 27.0, `sim_prepare.sh`.
- Downstream: **Branch-Schutz auf `main` verlangt die Prüfung mit dem Namen `UI Smoke (iOS Simulator)`** (neben Unit, Build,
  Shipped languages, UI iPad, Mac Gallery). Wird der Job zur Matrix, entsteht ein anderer Prüfname; ohne Sammel-Job mit
  dem alten Namen wäre jeder PR blockiert. Ein Sammel-Job muss mit `if: always()` laufen, sonst zählt „übersprungen“
  als bestanden.
- Artefakte `DesignGallery` (nur `DesignGalleryTests`) und `UITestResults` (xcresult, Logs); `StoreScreenshotsTests`
  und `DesignGalleryTests` fotografieren und laufen heute mit.
- `docs/artifacts/*` verweisen nur beschreibend auf den Jobnamen.

## Existing Specs
- Keine Spec zu CI-Aufbau; Vorarbeiten: #905 (Zeitgrenze), #228 (Parallelbetrieb im Simulator verworfen, Speicherdruck),
  #578 (Simulator-Vorbereitung), #761 (Sprach-Matrix).

## Risks & Considerations
- Konkurrenz um Runner: Mit 4 Teilen laufen gleichzeitig 11 macOS-Jobs; bisher liefen 7–8 gleichzeitig ohne Warteschlange.
  Ob mehr gehen, zeigt erst ein Lauf (Beleg nötig).
- Jedes Teil baut selbst (≈ 7 min) und bootet (≈ 4 min): Fester Aufwand je Teil ≈ 12 min. Bei 4 Teilen ≈ 20 min Tests + 12 = 32 min.
- Neue Testklassen dürfen nicht aus der Aufteilung herausfallen (feste Klassenlisten würden sie still nicht laufen lassen):
  Aufteilung aus dem Code lesen und per Test sichern, dass jede Klasse in genau einem Teil liegt.
- Verbleibende Hebel ohne Aufteilung (Alternative): feste Wartezeiten in den Hilfsfunktionen kürzen — schätzbar 10–15 min, erreicht 60 min allein nicht.
- `-parallel-testing-enabled`/mehrere Simulatoren im selben Job: durch #228 widerlegt.

## Analysis

### Type
Feature (CI-Umbau, kein Produktcode)

### Recherche / Nulllinie
Ohne Aufteilung geht es nicht, weil: 98 Tests × 48 s Wartezeit-dominierte Laufzeit (Runner < 50 % CPU) = 78 min reine Testzeit; Hilfsfunktionen
zu kürzen (Alternative B) spart geschätzt 10–15 min und erreicht 60 min nicht. Mehrere Simulatoren im selben Job scheiden durch #228 aus
(Speicherdruck, gemessen). GitHub-Matrix mit einem Simulator je Job ist der etablierte Weg und im Repo schon in Gebrauch (`ui-smoke-lang`).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/ci.yml` | MODIFY | Job `ui-smoke` wird Matrix `ui-smoke-shard` (4 Teile, `fail-fast: false`, Artefakt je Teil, `-only-testing` je Klasse aus Script); neuer Sammel-Job mit dem alten Namen `UI Smoke (iOS Simulator)`, `needs`, `if: always()`, rot bei jedem Ergebnis ≠ `success`; Zeitgrenzen je Teil enger (Vorschlag 60/45) |
| `scripts/ui_smoke_shards.py` | CREATE | liest die Klassen aus `LooseEndsUITests/*.swift` (XCTestCase), zählt `func test…`, verteilt gierig (schwerste zuerst) auf N Teile, gibt Matrix-JSON aus; Mac-Klassen (laufen auf iOS nur als übersprungen) in einem Teil mit Gewicht 0 |
| `scripts/test_ui_smoke_shards.py` | CREATE | Beweis: jede Klasse in genau einem Teil, keine leeren Teile, Aufteilung deterministisch, neue Klasse wird automatisch einsortiert |
| `CLAUDE.md` | MODIFY | Abschnitt CI: Job `ui-smoke` als 4er-Matrix mit Sammel-Prüfung beschreiben |

### Scope Assessment
- Files: 4
- Estimated LoC: +~170/-~60 (ci.yml-Umbau nutzt die vorhandene Composite-Action `prepare-ui-simulator` statt der Inline-Schritte)
- Risk Level: MEDIUM — Branch-Schutz verlangt den Prüfnamen `UI Smoke (iOS Simulator)`; ein Fehler im Sammel-Job blockiert jeden PR oder lässt rote Teile durch.

### Technical Approach
Empfehlung: **4 Teile + Sammel-Job**, Aufteilung aus dem Code gelesen (kein feste Klassenliste, die neue Klassen still verschluckt).
Erwartung: ≈ 20 min Tests + ≈ 12 min Bau/Boot je Teil ≈ 32 min (Ziel < 60 min, Beleg per echtem CI-Lauf auf dem PR).
Sammel-Job: `needs: [ui-smoke-shard]`, `if: always()`, Schritt prüft `needs.ui-smoke-shard.result == 'success'`, sonst `exit 1`
(„übersprungen“ und „abgebrochen“ zählen als rot). Design-Galerie: `DesignGalleryTests` landet in einem Teil; Export-Schritt
läuft in jedem Teil und toleriert „keine Bilder“; Artefaktnamen `DesignGallery-<n>`/`UITestResults-<n>`.
Gewicht je Klasse = Testzahl; die zwei Foto-Klassen (`DesignGalleryTests`, `StoreScreenshotsTests`, je 1 Test, 155–183 s) bekommen
festes Gewicht 4, damit sie nicht im selben Teil liegen.

**Alternative A (verworfen als Hauptweg):** Teilzahl 5–6 → ≈ 28 min, aber 12–13 gleichzeitige macOS-Jobs, bisher 7–8 ohne Warteschlange; erst nach Beleg erhöhen (nur Zahl im Workflow).
**Alternative B (Ergänzung, eigenes Ticket falls nötig):** feste Wartezeiten in `waitForExistence`-Helfern kürzen: −10–15 min, ändert Teststabilität, eigene Messung nötig.
**Alternative C:** UI-Smoke nur bei Änderungen an App-Pfaden laufen lassen. Verworfen: Branch-Schutz verlangt die Prüfung immer; kippt keine ADR, aber verbirgt Regressionen.
Gekippte ADR: keine (#228 „kein Parallelbetrieb im Simulator“ bleibt, jeder Teil hat seinen eigenen Simulator).

### Dependencies
Branch-Schutz-Prüfname (unverändert halten); `ui-smoke-lang` und `ui-ipad` unberührt; `docs/reference/abnahme-und-arbeitsweise.md` nennt den Job nur beschreibend.
Abnahme: Stufe 1–2 = echter CI-Lauf auf dem PR (Laufzeit je Teil und Gesamtzeit als Beleg, rote Probe: ein absichtlich roter Teil macht den Sammel-Job rot, vorab per `workflow_dispatch`/Testzweig).
„Kein Pfad der Geräteliste berührt.“

### Open Questions
- [ ] Keine, die Henning entscheiden muss (reine CI-Technik). Teilzahl 4 ist Startwert; Erhöhung nach Messung.
