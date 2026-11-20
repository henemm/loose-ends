# Context: fix-939-ci-simulator

## Request Summary
Die UI-Test-Jobs der CI (`ci.yml`: UI Smoke part 1–4, ui-smoke-lang, UI iPad, Mac Gallery) scheitern immer wieder an Simulator,
Runner und Zeitlimits statt am Code; fast jeder PR braucht einen zweiten oder dritten Versuch (Henning, 2026-11-16: „kannst du das
Simulator-Thema endlich mal reparieren?“). Ziel: mehrere CI-Läufe hintereinander beim ersten Versuch grün.

## Related Files
| File | Relevance |
|------|-----------|
| `.github/workflows/ci.yml` | Jobs `ui-smoke-plan` (115), `ui-smoke-shard` (131, Job 60 min, Testschritt 45 min, Z. 227), `ui-smoke` (371, Sammel-Check mit geschütztem Namen), `ui-smoke-lang` (407, 40 min), `ui-ipad` (474, 45 min), `mac-gallery` (536, 40 min) |
| `.github/actions/prepare-ui-simulator/action.yml` | Simulator wählen, `simctl boot`, `bootstatus -b`, `sim_prepare.sh`, Poster-Dienste aus (genutzt von lang und iPad; `ui-smoke-shard` hat dieselben Schritte noch inline) |
| `.github/actions/select-xcode-27/action.yml` | `xcode-select` auf `/Applications/Xcode_27.app`, bricht ab, wenn nicht „Xcode 27.0“ |
| `scripts/sim_prepare.sh` | Tastatur-Hinweis aus, Kalenderzugriff vorab (#578), auch von `sim.sh boot` genutzt |
| `scripts/ui_smoke_shards.py` | Teilt Klassen in N Teile, Gewicht = Testanzahl (Foto-Klassen fest 4), gierig; Argument `4` in `ci.yml` |
| `LooseEndsUITests/*` | Die Tests selbst; feste Wartezeiten (z. B. 60 s Dateiauswahl, #948) |
| `scripts/test_ui_smoke_shards.py` (falls vorhanden) | Tests der Aufteilung |

## Existing Patterns
- Jeder UI-Job baut selbst: `xcodebuild test` = Bau + Test im selben Schritt, also zählt der Bau gegen das 45-min-Limit des Testschritts.
  Nur `mac-gallery` trennt bereits `build-for-testing` und `test-without-building` (Sandbox-Neusignierung, #544).
- Diagnose-Schritte nach dem Test (`if: always()`): Modellverfügbarkeit, Systemlog, Hostlast alle 20 s (`host-load.log`, #228).
- Frühere Reparaturen derselben Klasse: #228 (Poster-Dienste, Speicherdruck, `bootstatus -b`), #578 (Tastatur-Hinweis, Kalender),
  #905 (Limits 160/135 min), #910 (Aufteilung in vier Teile), #948 (Dateiauswahl 20 → 60 s), #882 (Kalender-/Dateiauswahl wackeln).

## Erster harter Befund (2026-11-20, PR #967, nur Doku geändert)
Lauf 44705007016, UI Smoke part 1 (`CaptureSmokeTests SettingsSmokeTests StartNumberTests`), rot nach 45-min-Schrittlimit:
- Testschritt Start 17:05:46, erster Test 17:27:24 → **Bau innerhalb des Testschritts ≈ 21,6 min**.
- 13 Tests bis zum Abbruch, alle grün, je 37–216 s (Mittel ≈ 90 s; `testCompletingWithAnOpenSubtaskAsks` 216 s,
  `testAnalyzeAgainReportsBack` 188 s). Kein Testfehler, kein „Restarting“ in diesem Teil.
- xcbeautify-Ausgabe kam gebündelt erst um 17:47:57 im Log an (gepuffert), der Lauffortschritt ist also im Live-Log nicht sichtbar.
- Folge: Zeitbudget = Bau (~22 min) + Tests (~13 × 90 s ≈ 20 min) liegt schon im Normalfall am 45-min-Limit.

## Recherche (2026-11-20)
- „Unable to find a device matching the provided destination specifier“: tritt bei fehlender/abweichender Laufzeit oder wenn
  xcodebuild das Gerät (noch) nicht als Ziel sieht; Diagnose `xcodebuild -showdestinations`; auch auf GitHub-Runner-Images gemeldet
  ([Apple Forum 790844](https://developer.apple.com/forums/thread/790844), [Apple Forum 810605](https://developer.apple.com/forums/thread/810605),
  [runner-images #9591](https://github.com/actions/runner-images/issues/9591)).
- „Restarting after unexpected exit, crash, or test timeout“: bekannte XCTest-Meldung ohne offizielle Abhilfe; „Checking for crash reports“
  kann selbst lange dauern ([Apple Forum 729729](https://developer.apple.com/forums/thread/729729),
  [Apple Forum 813260](https://developer.apple.com/forums/thread/813260)).
- Bau einmal, Tests verteilt: `build-for-testing` in einem Job, `.xctestrun` + Produkte weiterreichen, `test-without-building -xctestrun`
  je Teil ([GitHub Engineering](https://github.blog/engineering/infrastructure/how-github-reduced-testing-time-for-ios-apps-with-new-runner-features/),
  [Tuist Test-Sharding](https://tuist.dev/en/docs/guides/features/test-sharding/xcode)). GitHub nennt Grenzen gleichzeitiger macOS-Runner je Plan.

## Dependencies
- Upstream: Runner-Label `xcode-27` (Vorschau-Image), Xcode 27.0, iOS-27.0-Simulator iPhone 17 / iPad Pro 13″, xcodegen, xcbeautify.
- Downstream: geschützter Check „UI Smoke (iOS Simulator)“ (Branch-Schutz), alle PRs aller Sitzungen; `sim.sh boot` nutzt `sim_prepare.sh`.

## Existing Specs
- `docs/specs/` zu #910 (Aufteilung), #905, #228, #578 — Muster für Limits und Simulator-Vorbereitung.

## Risks & Considerations
- Der Check-Name „UI Smoke (iOS Simulator)“ ist geschützt und darf sich nicht ändern.
- Mehr Teile = mehr gleichzeitige macOS-Runner; die Plan-Grenze gleichzeitiger Runner kann Jobs in die Warteschlange schieben
  (andere Sitzungen arbeiten parallel im selben Repo).
- Weitergereichte Bauprodukte (Artefakt/Cache) müssen zum selben Commit gehören; Simulator-Ziel beim Test ohne Bau muss zur gebauten Plattform passen.
- Höheres Schrittlimit allein verschiebt nur das Problem (Alternative, aber kein Ursachenfix).
- Beleg erfordert mehrere aufeinanderfolgende CI-Läufe; das ist Wartezeit, kein Henning-Schritt.

## Klassifikation (94 fehlgeschlagene Job-Versuche, 2026-11-06 bis 11-20; voll: `docs/artifacts/fix-939-ci-simulator/klassifikation.md`)
- **b1 Schrittlimit 45 min: 43** (part 1: 23, 3: 11, 4: 6, 2: 3). In allen liefen Tests noch, kein Hänger. Bau im Testschritt
  Median 14,3 min (7,6–21,6). In 20 von 43 lief schon der letzte Test (z. B. Lauf 44781254072 part 4: „Executed 28 tests … 0 failures“, danach Abbruch).
  Häufung 11-19/11-20 auf Image 20261119.0378.1 (alle 20 Fehlschläge dort b1).
- **c echter Testfehler: 28** (10 davon am selben Commit später grün = wacklig). Wiederholer: `testFileAndPhotoButtonsOpenTheirPickers` (14×, zuletzt 11-17, vor #948),
  `testDefaultCalendarIsStampedOnSwitchOn` (5×, #882), `testDeleteCancelKeepsSignedIn` (4×), Mac Gallery `testSubtaskOpensItsOwnDetailAndLeadsBack` (3×).
- **d Simulator-Laufzeit mitten im Job verloren: 8** („The iOS 27.0 simulator runtime is not available“, „Mach error -308 server died“), + **a Ziel nicht gefunden: 3**;
  10 der 11 am 2026-11-16 auf Image 20261112.0361.1 (Image-Ereignis, seither nicht wieder).
- **b2 UI-Abfrage hängt / Läufer-Neustart: 7** („Timed out while evaluating UI query“ 4, „acquiring background assertion“ 2).
- **d sonstiges: 5** (Artefakt-Upload ENOTFOUND/404 3, Mac Gallery exit 139, simctl-Absturz in `sim_prepare`). Xcode-Auswahl schlug nie fehl.
- **Grüne Teile (37 Stichproben):** Testschritt Median 37,8 min, p90 40,4, max 44,9; Bau Median 10,6 min (4,1–15,8) + Tests 24,7 (17,0–32,4).
  Reserve ≈ 7 min — ein Bau über ~17 min oder ein langsamer Testteil kippt den Teil.
- „Restarting after unexpected exit“ ist in grünen Läufen nicht sichtbar (xcbeautify verschluckt die Zeile, Rohlog nur bei Fehlschlag).
- Unit Tests und Build scheiterten nie.
