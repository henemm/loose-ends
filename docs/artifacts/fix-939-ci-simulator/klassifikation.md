# CI #939 — classification of failed UI/test job attempts, workflow `CI` (ci.yml), 2026-11-06 … 2026-11-20

Source: `gh api …/runs/<id>/attempts/<n>/jobs` for every attempt of all 223 CI runs since 2026-11-06, logs via `…/jobs/<id>/logs`. Carried-over jobs of re-run attempts deduplicated (same run+name+start). Before 2026-11-13 (#910) UI Smoke was one job `UI Smoke (iOS Simulator)` (~100 tests, no step timeout reached); its failed attempts are included as 'UI Smoke (mono)'. Aggregator failures of `UI Smoke (iOS Simulator)` after #910 (0 min, 'All parts green') are consequences, not counted.

Runner: every job ran on label `xcode-27`, image `xcode-27-arm64`; Xcode 27.0 Build version 27A266a in all attempts (the Xcode guard never failed). Image versions seen: 20261104.0337.1 (54), 20261119.0378.1 (20), 20261112.0361.1 (18), 20261026.0314.1 (2) among failures.

## Summary per class (failed job attempts)

| class | count | jobs |
|---|---|---|
| a | 3 | UI Smoke 3 |
| b1 | 43 | UI Smoke 43 |
| b2 | 7 | UI Smoke 4, ui-smoke-lang (en) 2, UI iPad (iOS Simulator) 1 |
| c | 28 | UI Smoke 13, UI Smoke (mono) 10, Mac Gallery (macOS) 4, ui-smoke-lang (en) 1 |
| d-artifact-upload | 3 | UI Smoke (mono) 1, Mac Gallery (macOS) 1, UI Smoke 1 |
| d-segfault-139 | 1 | Mac Gallery (macOS) 1 |
| d-sim-runtime-lost | 8 | UI Smoke 4, ui-smoke-lang (en) 2, ui-smoke-lang (de) 1, UI iPad (iOS Simulator) 1 |
| d-simctl-crash | 1 | ui-smoke-lang (de) 1 |
| **total** | **94** | |

Definitions: a = destination not found; b1 = step 'Run UI smoke tests' killed at 45 min; b2 = test runner restart / launch failure / UI query hang (`Failed to get matching snapshots: Timed out while evaluating UI query`, `Timed out while acquiring background assertion`); c = assertion failure in a test; d-sim-runtime-lost = `The iOS 27.0 simulator runtime is not available` or `Mach error -308 (ipc/mig) server died` while installing/launching (simulator runtime vanished mid-job, sibling of a); d-* other.

## b1 detail — step timeouts (45 min incl. build)

The 45-min limit covers `xcodebuild test` = build-for-testing + tests. Column 'build' = minutes from step start to `Test Suite 'Selected tests' started`; 'launches' = number of app launches xcodebuild logged (`IDELaunchParametersSnapshot`, ≈ one per test) from the raw log dumped by the failure step; 'gap' = minutes between the last launch and the kill. 'passed (console)' is a lower bound: xcbeautify output is flushed in blocks, so the tail is lost when the step is killed.

| run | att | job | date | build min | launches | last launch → kill gap (min) | passed (console) | failed tests before kill |
|---|---|---|---|---|---|---|---|---|
| 43324304849 | 1 | UI Smoke part 1 | 2026-11-13 00:40 | 13.9 | 30 | 1.6 | 18 | - |
| 43493201891 | 1 | UI Smoke part 3 | 2026-11-13 19:58 | n/a (console cut) | 18 | -0.2 | 0 | - |
| 43582704014 | 2 | UI Smoke part 1 | 2026-11-14 11:54 | 14.8 | 30 | 0.7 | 12 | testFileAndPhotoButtonsOpenTheirPickers, testImportanceEditorUpdatesDetail |
| 43812511947 | 2 | UI Smoke part 4 | 2026-11-16 07:06 | 14.7 | 23 | 4.1 | 18 | - |
| 43813547492 | 1 | UI Smoke part 1 | 2026-11-16 07:11 | 18.2 | 19 | 0.7 | 12 | testFileAndPhotoButtonsOpenTheirPickers, testImportanceEditorUpdatesDetail |
| 43813547492 | 2 | UI Smoke part 1 | 2026-11-16 08:49 | 10.0 | 28 | 0.3 | 15 | - |
| 43887446831 | 1 | UI Smoke part 3 | 2026-11-16 14:37 | 14.6 | 24 | 1.5 | 22 | - |
| 43887446831 | 1 | UI Smoke part 1 | 2026-11-16 14:56 | 14.2 | 31 | -0.5 | 13 | testFileAndPhotoButtonsOpenTheirPickers |
| 43813547492 | 4 | UI Smoke part 1 | 2026-11-16 15:50 | 8.7 | 31 | -0.0 | 13 | testFileAndPhotoButtonsOpenTheirPickers |
| 43894593893 | 1 | UI Smoke part 3 | 2026-11-16 16:14 | n/a (console cut) | 19 | -0.5 | 0 | testDeleteCancelKeepsSignedIn |
| 43952899545 | 1 | UI Smoke part 3 | 2026-11-16 21:37 | 13.8 | 24 | 1.6 | 19 | - |
| 44063585503 | 1 | UI Smoke part 3 | 2026-11-17 11:23 | n/a (console cut) | 18 | 0.1 | 0 | - |
| 44076601507 | 1 | UI Smoke part 1 | 2026-11-17 12:49 | 12.7 | 31 | 0.6 | 14 | - |
| 44077363301 | 1 | UI Smoke part 1 | 2026-11-17 12:52 | 7.6 | 28 | -0.1 | 14 | - |
| 44124912380 | 1 | UI Smoke part 1 | 2026-11-17 17:24 | 14.3 | 31 | 1.6 | 13 | testFileAndPhotoButtonsOpenTheirPickers |
| 44378805060 | 1 | UI Smoke part 3 | 2026-11-18 19:49 | 12.7 | 24 | 0.7 | 19 | - |
| 44405085922 | 1 | UI Smoke part 1 | 2026-11-18 22:07 | 13.6 | 31 | 0.6 | 14 | - |
| 44487253413 | 1 | UI Smoke part 1 | 2026-11-19 08:56 | 13.9 | 31 | -1.2 | 14 | - |
| 44489694629 | 1 | UI Smoke part 3 | 2026-11-19 10:09 | n/a (console cut) | 18 | 0.6 | 0 | testLowAndMediumShowNoSignInTheRowButTheLadderInTheDetail |
| 44514460983 | 1 | UI Smoke part 1 | 2026-11-19 12:12 | 11.2 | 31 | 1.4 | 12 | testAnalyzeAgainReportsBack |
| 44514460983 | 2 | UI Smoke part 1 | 2026-11-19 13:07 | 10.7 | 31 | 1.2 | 14 | - |
| 44584442546 | 1 | UI Smoke part 2 | 2026-11-19 18:23 | 19.2 | 22 | 1.2 | 18 | - |
| 44601771004 | 1 | UI Smoke part 1 | 2026-11-19 19:50 | 11.8 | 28 | 1.2 | 13 | - |
| 44601771004 | 2 | UI Smoke part 1 | 2026-11-19 21:30 | 17.5 | 26 | -0.3 | 13 | - |
| 44623378672 | 1 | UI Smoke part 4 | 2026-11-19 21:58 | 16.5 | 23 | 2.6 | 17 | - |
| 44623378672 | 1 | UI Smoke part 3 | 2026-11-19 22:12 | 15.6 | 24 | -0.2 | 18 | - |
| 44704523664 | 1 | UI Smoke part 1 | 2026-11-20 09:00 | 18.9 | 19 | 0.3 | 13 | - |
| 44704523664 | 1 | UI Smoke part 3 | 2026-11-20 09:19 | n/a (console cut) | 17 | 0.3 | 0 | - |
| 44705007016 | 1 | UI Smoke part 1 | 2026-11-20 09:55 | 12.9 | 31 | 0.2 | 13 | - |
| 44705007016 | 1 | UI Smoke part 4 | 2026-11-20 09:56 | 18.6 | 20 | 0.2 | 17 | - |
| 44705007016 | 1 | UI Smoke part 2 | 2026-11-20 10:14 | 21.4 | 22 | 0.4 | 18 | - |
| 44705007016 | 2 | UI Smoke part 4 | 2026-11-20 11:45 | 19.1 | 23 | 1.4 | 17 | - |
| 44705007016 | 2 | UI Smoke part 1 | 2026-11-20 11:45 | 16.2 | 28 | 0.3 | 13 | - |
| 44729680546 | 1 | UI Smoke part 1 | 2026-11-20 12:25 | 11.1 | 31 | 1.3 | 31 | - |
| 44729680546 | 1 | UI Smoke part 3 | 2026-11-20 12:39 | n/a (console cut) | 20 | 0.3 | 0 | - |
| 44705007016 | 4 | UI Smoke part 1 | 2026-11-20 14:12 | 14.0 | 28 | 0.1 | 13 | - |
| 44756917595 | 1 | UI Smoke part 4 | 2026-11-20 15:06 | n/a (console cut) | 19 | 0.0 | 0 | testSecondGardenIsRejected |
| 44756917595 | 1 | UI Smoke part 1 | 2026-11-20 15:07 | 17.6 | 30 | -0.3 | 13 | - |
| 44756917595 | 1 | UI Smoke part 3 | 2026-11-20 15:23 | n/a (console cut) | 17 | 0.7 | 0 | - |
| 44705007016 | 5 | UI Smoke part 1 | 2026-11-20 16:02 | 10.4 | 31 | 0.4 | 13 | - |
| 44705007016 | 6 | UI Smoke part 1 | 2026-11-20 16:57 | 21.6 | 18 | 0.1 | 13 | - |
| 44781254072 | 1 | UI Smoke part 4 | 2026-11-20 17:30 | 15.4 | 22 | 4.2 | 21 | - |
| 44781254072 | 1 | UI Smoke part 2 | 2026-11-20 17:49 | 14.9 | 28 | 2.9 | 18 | - |

b1: 43 attempts; gap last launch→kill: median 0.4 min, max 4.2 min — tests were still progressing at the kill in every case, no silent hang. Build part in timed-out attempts: median 14.3 min (range 7.6–21.6). With a failed test before the kill: 9. Restarts seen in b1: 0.

Slowest single tests (max seen, s): testChangeListNamesTheBeadMarkInGerman 350, testCancelAfterCaptureOpensLeavesAppAlive 344, testAnalyzeAgainReportsBack 322, testPhotographMainScreens 309, testDefaultCalendarIsStampedOnSwitchOn 281, testCompletingWithAnOpenSubtaskAsks 237, testNowFoldsAgainOnceFiveAreLeft 215, testCountsShowsTheBeadAndTheWeekString 213, testPhotographStoreScreens 212, testDeletingATaskLiftsItsSubtask 209

## Green UI Smoke part runs (sample of 37, spread over 2026-11-13 … 11-20)

| date | part | image | step min | build min | tests min | tests (executed) |
|---|---|---|---|---|---|---|
| 2026-11-13 03:16 | 2 | 20261104.0337.1 | 44.9 | 15.8 | 28.1 | 29 |
| 2026-11-13 09:24 | 3 | 20261104.0337.1 | 33.4 | 9.6 | 23.1 | 26 |
| 2026-11-13 13:04 | 3 | 20261104.0337.1 | 39.1 | 9.1 | 29.2 | 26 |
| 2026-11-13 16:35 | 4 | 20261104.0337.1 | 40.3 | 14.9 | 24.6 | 26 |
| 2026-11-13 20:04 | 2 | 20261104.0337.1 | 32.7 | 8.4 | 23.3 | 29 |
| 2026-11-14 08:08 | 3 | 20261104.0337.1 | 33.6 | 9.0 | 24.0 | 26 |
| 2026-11-14 11:26 | 3 | 20261104.0337.1 | 38.8 | 13.5 | 24.5 | 26 |
| 2026-11-14 14:33 | 4 | 20261104.0337.1 | 23.4 | 5.8 | 17.0 | 27 |
| 2026-11-15 04:01 | 1 | 20261104.0337.1 | 33.5 | 4.1 | 28.7 | 30 |
| 2026-11-15 10:46 | 4 | 20261104.0337.1 | 33.4 | 8.7 | 23.8 | 27 |
| 2026-11-15 15:06 | 1 | 20261104.0337.1 | 32.0 | 7.2 | 23.8 | 31 |
| 2026-11-15 19:13 | 1 | 20261104.0337.1 | 39.3 | 11.2 | 27.4 | 31 |
| 2026-11-15 21:57 | 3 | 20261104.0337.1 | 37.4 | 9.6 | 27.0 | 27 |
| 2026-11-16 07:08 | 4 | 20261104.0337.1 | 34.5 | 11.9 | 21.9 | 27 |
| 2026-11-16 20:26 | 3 | 20261104.0337.1 | 38.6 | 13.3 | 24.7 | 27 |
| 2026-11-16 23:44 | 1 | 20261104.0337.1 | 30.5 | 7.5 | 22.5 | 31 |
| 2026-11-17 11:09 | 1 | 20261104.0337.1 | 39.1 | 9.9 | 28.3 | 31 |
| 2026-11-17 15:46 | 3 | 20261104.0337.1 | 38.9 | 10.6 | 27.4 | 27 |
| 2026-11-17 19:14 | 1 | 20261104.0337.1 | 36.9 | 10.9 | 25.1 | 31 |
| 2026-11-17 23:03 | 3 | 20261104.0337.1 | 38.6 | 13.0 | 25.1 | 27 |
| 2026-11-18 19:36 | 2 | 20261104.0337.1 | 39.3 | 14.3 | 23.8 | 31 |
| 2026-11-19 06:49 | 3 | 20261104.0337.1 | 38.5 | 12.0 | 25.3 | 27 |
| 2026-11-19 09:59 | 2 | 20261104.0337.1 | 33.3 | 10.8 | 21.6 | 31 |
| 2026-11-19 13:59 | 4 | 20261104.0337.1 | 36.0 | 11.8 | 23.3 | 27 |
| 2026-11-19 16:57 | 3 | 20261104.0337.1 | 37.8 | 10.5 | 26.6 | 27 |
| 2026-11-19 21:13 | 3 | 20261104.0337.1 | 35.3 | 8.5 | 26.2 | 27 |
| 2026-11-20 07:54 | 3 | 20261104.0337.1 | 33.0 | 9.3 | 23.1 | 27 |
| 2026-11-20 09:58 | 3 | 20261104.0337.1 | 40.4 | 11.7 | 27.7 | 27 |
| 2026-11-20 11:45 | 2 | 20261104.0337.1 | 32.7 | 8.7 | 22.9 | 31 |
| 2026-11-20 12:39 | 4 | 20261104.0337.1 | 38.9 | 11.3 | 26.6 | 27 |
| 2026-11-20 13:25 | 4 | 20261119.0378.1 | 23.7 | 5.7 | 17.5 | 27 |
| 2026-11-20 15:16 | 2 | 20261104.0337.1 | 32.1 | 8.9 | 22.4 | 31 |
| 2026-11-20 16:21 | 1 | 20261119.0378.1 | 43.4 | 10.3 | 32.4 | 31 |
| 2026-11-20 16:21 | 3 | 20261119.0378.1 | 42.8 | 13.9 | 27.8 | 28 |
| 2026-11-20 16:21 | 4 | 20261119.0378.1 | 39.1 | 14.1 | 23.7 | 28 |
| 2026-11-20 17:19 | 3 | 20261119.0378.1 | 40.7 | 13.2 | 26.5 | 28 |
| 2026-11-20 17:39 | 1 | 20261104.0337.1 | 40.1 | 11.4 | 28.0 | 31 |

Green step duration (min): min 23.4, median 37.8, p90 40.4, max 44.9; ≥40 min: 7/37; ≥43 min: 2/37.
Green build part: median 10.6 (range 4.1–15.8); green test part: median 24.7 (range 17.0–32.4).
- part 1: n=8, tests ['30', '31'], step median 38.0, max 43.4
- part 2: n=6, tests ['29', '31'], step median 33.0, max 44.9
- part 3: n=15, tests ['26', '27', '28'], step median 38.6, max 42.8
- part 4: n=8, tests ['26', '27', '28'], step median 35.25, max 40.3

'Restarting after unexpected exit' in green runs: not visible — the console shows only xcbeautify output (which drops that line) and the raw-log dump step runs only `if: failure()`. In the failed logs it appeared exactly twice (both with a remounted simulator runtime). Checking green runs would need the UITestResults-<n> xcresult artifacts.

## All failed job attempts

| run | att | job | date | class | evidence (verbatim) | image | test step min | failed tests | same SHA green elsewhere |
|---|---|---|---|---|---|---|---|---|---|
| 42178316689 | 1 | ui-smoke-lang (de) | 2026-11-06 07:21 | d-simctl-crash | `sim_prepare: 'defaults write DidShowContinuousPathIntroduction' failed (simctl: uncaught NSException in CoreSimulator, Abort trap 6)` | 20261026.0314.1 | 0.0 | - | no |
| 42208930286 | 1 | UI Smoke (mono) | 2026-11-06 11:21 | c | `testFileAndPhotoButtonsOpenTheirPickers, XCTAssertTrue failed - File should open the document picker` | 20261026.0314.1 | 107.5 | testFileAndPhotoButtonsOpenTheirPickers | no |
| 42269478152 | 1 | Mac Gallery (macOS) | 2026-11-06 18:18 | c | `testPanelTypedGerman, failed - Menu bar panel shows no Open Loose Ends` | 20261104.0337.1 | 9.9 | testPanelTypedGerman | yes |
| 42344900835 | 1 | Mac Gallery (macOS) | 2026-11-07 05:57 | c | `testSubtaskOpensItsOwnDetailAndLeadsBack, XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Field kept Einkaufen` | 20261104.0337.1 | 9.6 | testSubtaskOpensItsOwnDetailAndLeadsBack | yes |
| 42386154935 | 1 | UI Smoke (mono) | 2026-11-07 15:56 | c | `testDefaultCalendarIsStampedOnSwitchOn, XCTAssertTrue failed - The picker should list the calendar to choose` | 20261104.0337.1 | 84.6 | testDefaultCalendarIsStampedOnSwitchOn | yes |
| 42516375954 | 1 | UI Smoke (mono) | 2026-11-08 20:50 | c | `testDefaultCalendarIsStampedOnSwitchOn, XCTAssertTrue failed - The picker should list the calendar to choose` | 20261104.0337.1 | 97.3 | testDefaultCalendarIsStampedOnSwitchOn, testFileAndPhotoButtonsOpenTheirPickers | yes |
| 42537654452 | 1 | UI Smoke (mono) | 2026-11-08 23:57 | c | `testDefaultCalendarIsStampedOnSwitchOn, XCTAssertTrue failed - The picker should list the calendar to choose` | 20261104.0337.1 | 87.0 | testDefaultCalendarIsStampedOnSwitchOn | no |
| 42537654452 | 1 | ui-smoke-lang (en) | 2026-11-09 00:02 | c | `testReturnOpensTheDrawerAndATapBesideFoldsIt, Failed to synthesize event: Neither element nor any descendant has keyboard focus. Event dispatch snapshot: TextField, {{84.0, 196.7},` | 20261104.0337.1 | 14.3 | testReturnOpensTheDrawerAndATapBesideFoldsIt | no |
| 42636517921 | 1 | UI Smoke (mono) | 2026-11-09 14:37 | c | `testDefaultCalendarIsStampedOnSwitchOn, XCTAssertTrue failed - Settings should offer the default calendar` | 20261104.0337.1 | 93.2 | testDefaultCalendarIsStampedOnSwitchOn, testSettingsShowDefaultCalendarRow | no |
| 42724959793 | 1 | UI Smoke (mono) | 2026-11-10 00:07 | c | `testDeleteCancelKeepsSignedIn, XCTAssertTrue failed - Signing in should show the signed-in row` | 20261104.0337.1 | 99.1 | testDeleteCancelKeepsSignedIn | yes |
| 42776562383 | 1 | UI Smoke (mono) | 2026-11-10 07:37 | c | `testSigningInKeepsDisabledAppleButton, XCTUnwrap failed: expected non-nil value of type "XCUIElementSnapshot" - The sign-in button stays while Apple's answer is on its way` | 20261104.0337.1 | 93.4 | testSigningInKeepsDisabledAppleButton | no |
| 42789957379 | 1 | UI Smoke (mono) | 2026-11-10 09:26 | c | `testSigningInKeepsDisabledAppleButton, XCTUnwrap failed: expected non-nil value of type "XCUIElementSnapshot" - The sign-in button stays while Apple's answer is on its way` | 20261104.0337.1 | 96.2 | testSigningInKeepsDisabledAppleButton | no |
| 42818122145 | 1 | Mac Gallery (macOS) | 2026-11-10 12:44 | d-segfault-139 | `Process completed with exit code 139.` | 20261104.0337.1 | 9.0 | - | yes |
| 42877961319 | 1 | UI iPad (iOS Simulator) | 2026-11-10 18:45 | d-sim-runtime-lost | `[MT] IDELaunchReport: 3afacafa1c9f9f00:3afacafa1c9fa0c0:Installing built products Finished with error: The iOS 27.0 simulator runtime is not availab` | 20261104.0337.1 | 6.2 | - | no |
| 42908572616 | 1 | UI Smoke (mono) | 2026-11-10 21:48 | c | `testFileAndPhotoButtonsOpenTheirPickers, XCTAssertTrue failed - File should open the document picker` | 20261104.0337.1 | 107.0 | testFileAndPhotoButtonsOpenTheirPickers | no |
| 42971851805 | 1 | Mac Gallery (macOS) | 2026-11-11 06:21 | d-artifact-upload | `Failed to CreateArtifact: Unable to make request: ENOTFOUND` | 20261104.0337.1 | 9.9 | - | yes |
| 43082458141 | 1 | UI Smoke (mono) | 2026-11-11 18:58 | d-artifact-upload | `Failed to FinalizeArtifact: Received non-retryable error: Failed request: (404) Not Found: artifact not found` | 20261104.0337.1 | 96.7 | - | no |
| 43129539552 | 1 | UI Smoke (mono) | 2026-11-12 00:45 | c | `testDeleteCancelKeepsSignedIn, XCTAssertTrue failed - Signing in should show the signed-in row` | 20261104.0337.1 | 98.8 | testDeleteCancelKeepsSignedIn | no |
| 43324304849 | 1 | UI Smoke part 1 | 2026-11-13 00:40 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.3 | - | yes |
| 43324304849 | 1 | UI Smoke part 4 | 2026-11-13 00:52 | c | `testChangeListNamesTheBeadMarkInGerman, XCTAssertTrue failed - The detail offers no change list` | 20261104.0337.1 | 31.9 | testChangeListNamesTheBeadMarkInGerman | no |
| 43340777559 | 1 | UI Smoke part 1 | 2026-11-13 01:55 | c | `testFileAndPhotoButtonsOpenTheirPickers, XCTAssertTrue failed - File should open the document picker` | 20261104.0337.1 | 38.7 | testFileAndPhotoButtonsOpenTheirPickers | no |
| 43324304849 | 2 | UI Smoke part 4 | 2026-11-13 02:14 | c | `testChangeListNamesTheBeadMarkInGerman, XCTAssertTrue failed - The detail offers no change list` | 20261104.0337.1 | 42.9 | testChangeListNamesTheBeadMarkInGerman | no |
| 43421718193 | 1 | Mac Gallery (macOS) | 2026-11-13 12:36 | c | `testSubtaskOpensItsOwnDetailAndLeadsBack, XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Field kept Einkaufen` | 20261104.0337.1 | 10.6 | testSubtaskOpensItsOwnDetailAndLeadsBack | yes |
| 43447849133 | 1 | Mac Gallery (macOS) | 2026-11-13 15:07 | c | `testSubtaskOpensItsOwnDetailAndLeadsBack, XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Field kept Einkaufen` | 20261104.0337.1 | 9.3 | testSubtaskOpensItsOwnDetailAndLeadsBack | no |
| 43465291180 | 1 | UI Smoke part 2 | 2026-11-13 18:04 | c | `testHintIsReplacedByTypedText, XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 2)") is not equal to ("XCTWaiterResult(rawValue: 1)") - Hinweis bleibt trotz Text stehen` | 20261104.0337.1 | 34.7 | testHintIsReplacedByTypedText | yes |
| 43493201891 | 1 | UI Smoke part 3 | 2026-11-13 19:58 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | - | no |
| 43508589616 | 1 | UI Smoke part 3 | 2026-11-13 21:27 | c | `testDeleteCancelKeepsSignedIn, XCTAssertTrue failed - Signing in should show the signed-in row` | 20261104.0337.1 | 33.7 | testDeleteCancelKeepsSignedIn | no |
| 43582851002 | 1 | ui-smoke-lang (en) | 2026-11-14 10:51 | b2 | `testReturnOpensTheDrawerAndATapBesideFoldsIt, Failed to get background assertion for target app with pid 25819: Timed out while acquiring background assertion.` | 20261104.0337.1 | 11.2 | testReturnOpensTheDrawerAndATapBesideFoldsIt | yes |
| 43582704014 | 1 | UI Smoke part 1 | 2026-11-14 11:06 | c | `testFileAndPhotoButtonsOpenTheirPickers, XCTAssertTrue failed - File should open the document picker` | 20261104.0337.1 | 41.5 | testFileAndPhotoButtonsOpenTheirPickers | yes |
| 43582704014 | 2 | UI Smoke part 1 | 2026-11-14 11:54 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | testFileAndPhotoButtonsOpenTheirPickers, testImportanceEditorUpdatesDetail | yes |
| 43733737644 | 1 | UI Smoke part 1 | 2026-11-15 16:25 | c | `testFileAndPhotoButtonsOpenTheirPickers, XCTAssertTrue failed - File should open the document picker` | 20261104.0337.1 | 40.5 | testFileAndPhotoButtonsOpenTheirPickers | no |
| 43812511947 | 1 | UI Smoke part 4 | 2026-11-16 05:47 | a | `##[error]xcodebuild: error: Unable to find a device matching the provided destination specifier:` | 20261112.0361.1 | 1.3 | - | yes |
| 43812511947 | 1 | ui-smoke-lang (de) | 2026-11-16 06:15 | d-sim-runtime-lost | `[MT] IDELaunchReport: 1b55ee549d454940:1b55ee549d4549c0:Installing built products Finished with error: The iOS 27.0 simulator runtime is not availa` | 20261112.0361.1 | 17.3 | - | yes |
| 43813547492 | 1 | UI iPad (iOS Simulator) | 2026-11-16 06:42 | b2 | `testDoneRowsShareThePaperGround, Failed to get matching snapshots: Timed out while evaluating UI query.` | 20261112.0361.1 | 18.8 | testDoneRowsShareThePaperGround | yes |
| 43813547492 | 1 | UI Smoke part 3 | 2026-11-16 06:45 | d-sim-runtime-lost | `[MT] IDELaunchReport: d7c172d3eb9f03c0:d7c172d3eb9f0640:Installing built products Finished with error: The iOS 27.0 simulator runtime is not availa` | 20261112.0361.1 | 12.2 | - | yes |
| 43812511947 | 2 | UI Smoke part 4 | 2026-11-16 07:06 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261112.0361.1 | 45.3 | - | yes |
| 43813547492 | 1 | UI Smoke part 1 | 2026-11-16 07:11 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261112.0361.1 | 45.2 | testFileAndPhotoButtonsOpenTheirPickers, testImportanceEditorUpdatesDetail | yes |
| 43813547492 | 2 | UI Smoke part 1 | 2026-11-16 08:49 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261112.0361.1 | 45.2 | - | yes |
| 43887446831 | 1 | UI Smoke part 3 | 2026-11-16 14:37 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.0 | - | no |
| 43887446831 | 1 | UI Smoke part 4 | 2026-11-16 14:38 | d-sim-runtime-lost | `[MT] IDELaunchReport: 4ed279ab7b3451c0:4ed279ab7b345880:Installing built products Finished with error: The iOS 27.0 simulator runtime is not availab` | 20261112.0361.1 | 19.0 | - | no |
| 43887446831 | 1 | UI Smoke part 2 | 2026-11-16 14:52 | d-sim-runtime-lost | `[MT] IDELaunchReport: 2472a030f623d140:2472a030f623d780:Launching LooseEndsUITests Finished with error: The operation couldn’t be completed. (Mach e` | 20261112.0361.1 | 16.1 | - | no |
| 43887446831 | 1 | UI Smoke part 1 | 2026-11-16 14:56 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261112.0361.1 | 45.2 | testFileAndPhotoButtonsOpenTheirPickers | no |
| 43887446831 | 1 | ui-smoke-lang (en) | 2026-11-16 15:12 | d-sim-runtime-lost | `[MT] IDELaunchReport: bf25e07f11375980:bf25e07f11375000:Launching LooseEndsUITests Finished with error: The operation couldn’t be completed. (Mach e` | 20261112.0361.1 | 16.3 | - | no |
| 43813547492 | 3 | UI Smoke part 1 | 2026-11-16 15:15 | a | `##[error]xcodebuild: error: Unable to find a device matching the provided destination specifier:` | 20261112.0361.1 | 1.4 | - | yes |
| 43894593893 | 1 | ui-smoke-lang (en) | 2026-11-16 15:50 | d-sim-runtime-lost | `[MT] IDELaunchReport: 94bc4d011b674ac0:94bc4d011b674c80:Installing built products Finished with error: The iOS 27.0 simulator runtime is not availab` | 20261112.0361.1 | 5.8 | - | yes |
| 43813547492 | 4 | UI Smoke part 1 | 2026-11-16 15:50 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261112.0361.1 | 45.2 | testFileAndPhotoButtonsOpenTheirPickers | yes |
| 43894593893 | 1 | UI Smoke part 1 | 2026-11-16 15:55 | d-sim-runtime-lost | `6400:	LooseEndsUITests-Runner encountered an error (Failed to prepare device 'iPhone 17' for impending launch. (Underlying Error: The iOS 27.0 simulator runtime is not available. r` | 20261112.0361.1 | 17.5 | - | no |
| 43894593893 | 1 | UI Smoke part 3 | 2026-11-16 16:14 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261112.0361.1 | 45.2 | testDeleteCancelKeepsSignedIn | no |
| 43894593893 | 2 | UI Smoke part 3 | 2026-11-16 17:14 | a | `##[error]xcodebuild: error: Unable to find a device matching the provided destination specifier:` | 20261112.0361.1 | 2.8 | - | no |
| 43894593893 | 2 | UI Smoke part 1 | 2026-11-16 17:14 | b2 | `} (error = Error Domain=NSPOSIXErrorDomain Code=3 "No such process" UserInfo={SimCallingSelector=launchApplicationWithID:options:pid:error:, NSLocalizedDescription=Simulator device` | 20261112.0361.1 | 38.5 | - | no |
| 43941369308 | 1 | UI Smoke part 1 | 2026-11-16 20:23 | b2 | `testAnalyzeAgainReportsBack, Failed to get matching snapshots: Timed out while evaluating UI query.` | 20261104.0337.1 | 32.7 | testAnalyzeAgainReportsBack | yes |
| 43952899545 | 1 | UI Smoke part 3 | 2026-11-16 21:37 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.3 | - | no |
| 43952899545 | 1 | UI Smoke part 1 | 2026-11-16 21:37 | c | `testFileAndPhotoButtonsOpenTheirPickers, XCTAssertTrue failed - File should open the document picker` | 20261104.0337.1 | 38.1 | testFileAndPhotoButtonsOpenTheirPickers | no |
| 43975996030 | 1 | UI Smoke part 2 | 2026-11-16 23:36 | b2 | `testNowFoldsAgainOnceFiveAreLeft, Failed to get matching snapshots: Timed out while evaluating UI query.` | 20261104.0337.1 | 38.8 | testNowFoldsAgainOnceFiveAreLeft | yes |
| 43975996030 | 2 | UI Smoke part 2 | 2026-11-17 07:04 | c | `testCaptureNeverPretendsToListen, XCTAssertNotEqual failed: ("nichts") is equal to ("nichts") - Die Erfassung hat 15 Sekunden lang zugehört, ohne zu erkennen und ohne es zu sagen` | 20261104.0337.1 | 38.1 | testCaptureNeverPretendsToListen | yes |
| 44063585503 | 1 | UI Smoke part 3 | 2026-11-17 11:23 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | - | yes |
| 44076601507 | 1 | UI Smoke part 3 | 2026-11-17 12:37 | c | `testDefaultCalendarIsStampedOnSwitchOn, failed - calendarTargetRow nach 5 Wischversuchen nicht erzeugt` | 20261104.0337.1 | 38.2 | testDefaultCalendarIsStampedOnSwitchOn, testSettingsShowDefaultCalendarRow | no |
| 44076601507 | 1 | UI Smoke part 1 | 2026-11-17 12:49 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | - | no |
| 44077363301 | 1 | UI Smoke part 1 | 2026-11-17 12:52 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | - | yes |
| 44103289216 | 1 | UI Smoke part 4 | 2026-11-17 15:30 | c | `testNoNoteWhileTheModelIsThere, XCTAssertFalse failed - The simulator has a model: no note` | 20261104.0337.1 | 34.9 | testNoNoteWhileTheModelIsThere | yes |
| 44114626511 | 1 | UI Smoke part 1 | 2026-11-17 16:37 | c | `testFileAndPhotoButtonsOpenTheirPickers, XCTAssertTrue failed - File should open the document picker` | 20261104.0337.1 | 34.0 | testFileAndPhotoButtonsOpenTheirPickers | no |
| 44124912380 | 1 | UI Smoke part 1 | 2026-11-17 17:24 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.3 | testFileAndPhotoButtonsOpenTheirPickers | no |
| 44124912380 | 2 | UI Smoke part 1 | 2026-11-17 19:37 | c | `testFileAndPhotoButtonsOpenTheirPickers, XCTAssertTrue failed - File should open the document picker` | 20261104.0337.1 | 36.1 | testFileAndPhotoButtonsOpenTheirPickers | no |
| 44365754033 | 1 | UI Smoke part 2 | 2026-11-18 18:09 | b2 | `testReturnOpensTheDrawerAndATapBesideFoldsIt, Failed to get matching snapshots: Timed out while evaluating UI query.` | 20261104.0337.1 | 34.2 | testReturnOpensTheDrawerAndATapBesideFoldsIt | yes |
| 44378805060 | 1 | UI Smoke part 3 | 2026-11-18 19:49 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | - | yes |
| 44405085922 | 1 | UI Smoke part 1 | 2026-11-18 22:07 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | - | no |
| 44487253413 | 1 | UI Smoke part 1 | 2026-11-19 08:56 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | - | yes |
| 44489694629 | 1 | UI Smoke part 3 | 2026-11-19 10:09 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | testLowAndMediumShowNoSignInTheRowButTheLadderInTheDetail | no |
| 44514460983 | 1 | UI Smoke part 1 | 2026-11-19 12:12 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | testAnalyzeAgainReportsBack | yes |
| 44514460983 | 2 | UI Smoke part 1 | 2026-11-19 13:07 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | - | yes |
| 44566874474 | 1 | ui-smoke-lang (en) | 2026-11-19 16:39 | b2 | `testReturnOpensTheDrawerAndATapBesideFoldsIt, Failed to get background assertion for target app with pid 24787: Timed out while acquiring background assertion.` | 20261104.0337.1 | 16.4 | testReturnOpensTheDrawerAndATapBesideFoldsIt | yes |
| 44584442546 | 1 | UI Smoke part 2 | 2026-11-19 18:23 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |
| 44601771004 | 1 | UI Smoke part 1 | 2026-11-19 19:50 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | yes |
| 44601771004 | 2 | UI Smoke part 1 | 2026-11-19 21:30 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | yes |
| 44623378672 | 1 | UI Smoke part 4 | 2026-11-19 21:58 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |
| 44623378672 | 1 | UI Smoke part 3 | 2026-11-19 22:12 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |
| 44704523664 | 1 | UI Smoke part 1 | 2026-11-20 09:00 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |
| 44704523664 | 1 | UI Smoke part 3 | 2026-11-20 09:19 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |
| 44705007016 | 1 | UI Smoke part 1 | 2026-11-20 09:55 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |
| 44705007016 | 1 | UI Smoke part 4 | 2026-11-20 09:56 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | yes |
| 44705007016 | 1 | UI Smoke part 2 | 2026-11-20 10:14 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | yes |
| 44705007016 | 2 | UI Smoke part 4 | 2026-11-20 11:45 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.3 | - | yes |
| 44705007016 | 2 | UI Smoke part 1 | 2026-11-20 11:45 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |
| 44729680546 | 1 | UI Smoke part 1 | 2026-11-20 12:25 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.1 | - | no |
| 44729680546 | 1 | UI Smoke part 3 | 2026-11-20 12:39 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.3 | - | no |
| 44705007016 | 3 | UI Smoke part 1 | 2026-11-20 13:20 | d-artifact-upload | `Failed to CreateArtifact: Unable to make request: ENOTFOUND` | 20261104.0337.1 | 41.4 | - | no |
| 44705007016 | 4 | UI Smoke part 1 | 2026-11-20 14:12 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |
| 44756917595 | 1 | UI Smoke part 4 | 2026-11-20 15:06 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | testSecondGardenIsRejected | yes |
| 44756917595 | 1 | UI Smoke part 1 | 2026-11-20 15:07 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | - | yes |
| 44756917595 | 1 | UI Smoke part 3 | 2026-11-20 15:23 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | yes |
| 44705007016 | 5 | UI Smoke part 1 | 2026-11-20 16:02 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |
| 44705007016 | 6 | UI Smoke part 1 | 2026-11-20 16:57 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |
| 44781254072 | 1 | UI Smoke part 4 | 2026-11-20 17:30 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261104.0337.1 | 45.2 | - | no |
| 44781254072 | 1 | UI Smoke part 2 | 2026-11-20 17:49 | b1 | `The action 'Run UI smoke tests' has timed out after 45 minutes.` | 20261119.0378.1 | 45.2 | - | no |

## c / b2 failing tests — recurrence

| test | class | failed attempts |
|---|---|---|
| testFileAndPhotoButtonsOpenTheirPickers | c | 9 |
| testFileAndPhotoButtonsOpenTheirPickers | b1 | 5 |
| testDefaultCalendarIsStampedOnSwitchOn | c | 5 |
| testReturnOpensTheDrawerAndATapBesideFoldsIt | b2 | 3 |
| testDeleteCancelKeepsSignedIn | c | 3 |
| testSubtaskOpensItsOwnDetailAndLeadsBack | c | 3 |
| testSettingsShowDefaultCalendarRow | c | 2 |
| testImportanceEditorUpdatesDetail | b1 | 2 |
| testChangeListNamesTheBeadMarkInGerman | c | 2 |
| testSigningInKeepsDisabledAppleButton | c | 2 |
| testSecondGardenIsRejected | b1 | 1 |
| testAnalyzeAgainReportsBack | b1 | 1 |
| testLowAndMediumShowNoSignInTheRowButTheLadderInTheDetail | b1 | 1 |
| testNoNoteWhileTheModelIsThere | c | 1 |
| testNowFoldsAgainOnceFiveAreLeft | b2 | 1 |
| testAnalyzeAgainReportsBack | b2 | 1 |
| testDeleteCancelKeepsSignedIn | b1 | 1 |
| testDoneRowsShareThePaperGround | b2 | 1 |
| testHintIsReplacedByTypedText | c | 1 |
| testReturnOpensTheDrawerAndATapBesideFoldsIt | c | 1 |
| testPanelTypedGerman | c | 1 |
| testCaptureNeverPretendsToListen | c | 1 |

## Additional findings

- UI Smoke part attempts (since #910, deduplicated): 321 green / 68 failed (17.5 %). Per day (green/failed): 11-13 58/7, 11-14 28/2, 11-15 61/1, 11-16 27/19, 11-17 46/9, 11-18 19/3, 11-19 48/9, 11-20 20/18.
- b1 by part: part 1 23, part 3 11, part 4 6, part 2 3. By day: 11-13 2, 11-14 1, 11-16 8, 11-17 4, 11-18 2, 11-19 9, 11-20 17. By image: 20261119.0378.1 20 (every failure on that image is b1), 20261104.0337.1 17, 20261112.0361.1 6.
- b1: in 20 of 43 the last test of the part had already launched (launches ≥ test count of the part), e.g. run 44781254072 part 4 printed `Executed 28 tests, with 7 tests skipped and 0 failures (0 unexpected) in 1724.218` and was then killed; run 44729680546 part 1: all 31 passed, killed 1.3 min after the last launch. The others were mid-part; none had stalled (max gap last launch → kill 4.2 min).
- Budget: green = build median 10.6 + tests median 24.7 + ~2 min overhead ≈ 37.8 min; b1 attempts had build median 14.3 (up to 21.6 min), so a slow build alone pushes a 25–32-min test part over 45.
- c, flaky vs real (same SHA + same job green in another attempt/run): 10 of 28 flaky. Recurring: `testFileAndPhotoButtonsOpenTheirPickers` ("File should open the document picker", 14 failed attempts: 9 c + 5 inside b1, last 2026-11-17), `testDefaultCalendarIsStampedOnSwitchOn`/`testSettingsShowDefaultCalendarRow` (mono era + 11-17), `testDeleteCancelKeepsSignedIn` (4), `testSigningInKeepsDisabledAppleButton` (11-10 only), `testChangeListNamesTheBeadMarkInGerman` (11-13, both attempts of one SHA = real at that commit), Mac `testSubtaskOpensItsOwnDetailAndLeadsBack` (3).
- d-sim-runtime-lost + a: 11 attempts, 10 of them on 2026-11-16 (image 20261112.0361.1): the iOS 27.0 runtime vanished during the job (`The iOS 27.0 simulator runtime is not available`, `Mach error -308 - (ipc/mig) server died`), and re-runs then hit `Unable to find a device matching the provided destination specifier`. The only two "Restarting after unexpected exit" lines in all failed logs coincide with a changed runtime mount path (`SimulatorRuntime-v24.1.434.0.4GbnBz` → `.Hk61Tk`). One earlier case 11-10 (iPad).
- Cancelled jobs (not counted): 42 UI Smoke parts, 40 ui-smoke-lang, 27 Mac Gallery, 25 iPad, 22 Unit, 15 Build; part durations 30–43 min, consistent with `concurrency: cancel-in-progress` on a new push (none reached the 60-min job limit).
- Unit Tests and Build (iOS Simulator) never failed in the window.
