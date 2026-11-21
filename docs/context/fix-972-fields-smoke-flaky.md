# Context: fix-972-fields-smoke-flaky

## Request Summary
`FieldsSmokeTests.testLowAndMediumShowNoSignInTheRowButTheLadderInTheDetail` fails in CI now and then: after choosing a
level in a register line's editor, the wait for the line to show the new value runs out. Goal: prove the cause from the
run's `.xcresult`, make the test wait for the right state, ten green runs in a row, five green `main` runs.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsUITests/FieldsSmokeTests.swift:224-234` | helper `choose(_:in:app:)`: tap line, tap option `label == level`, then `XCTNSPredicateExpectation(label CONTAINS level)` on the line with a 5 s `XCTWaiter` |
| `LooseEndsUITests/FieldsSmokeTests.swift:188-219` | the failing test (Medium, Low on importance, Low on urgency) |
| `LooseEnds/Views/TaskDetailView.swift:744-800` | `fieldRow`: the register line, one `Button` with `.accessibilityElement(children: .combine)`, id `field_<field>` |
| `LooseEnds/Views/TaskDetailView.swift:313` | iPhone: the editor is pushed (`navigationDestination(item: $editingField)`), popover only on the Mac |
| `LooseEnds/Views/FieldEditorView.swift:121-124` | `choose`: `apply(encoded)` then `dismiss()` (pop) |
| `LooseEnds/Views/EditorPage.swift:60-95` | `LevelLadder`: buttons `levelOption_<raw>` with label None/Low/Medium/High |

## Evidence from CI (run 44814947423, PR #971, UI Smoke part 5, artifact `UITestResults-5` id 14679371183)
Activity timeline of the failed test (epoch seconds, `xcresulttool get test-results activities`):
- 762.74 tap on `levelOption_low` in the urgency editor, 763.10 synthesized event done, then "wait for idle"
- 764.57 first check of `label CONTAINS "Low"` on `field_urgency`: its *Find* runs until **768.79** (4.2 s), followed by
  "Capturing element debug description" — the element query itself stalled/failed
- 770.34 failure `XCTWaiterResult 2 (timedOut)`; the message's own read of the label (768.9) gives **"Urgency, Low"**
- Screen recording (attachment "Screen Recording", frames at 57.8 s = 764.3 and 62.7 s = 769.2): from 764.3 on the
  detail stands still and shows **Urgency Low** and Importance Low. The app did the right thing within ~1.2 s of the tap.

So: not a lost tap, not a late label. One accessibility query on the loaded CI simulator took 4.2 s and ate the 5 s
budget of the waiter, which polls about once per second and got only one evaluation.
Sources: Wealthfront on XCTWaiter's fixed 1 s polling (https://eng.wealthfront.com/?p=3423), Christian Tietze on short
predicate timeouts (https://christiantietze.de/posts/2021/01/xctestexpectation-predicate-interval/).

Second artifact (id 14680808375, re-run): this test passed (1 min 3 s); `FieldsSmokeTests.testCalendarWaitsForADate`
failed instead: "Row label was Due, Today, From your words" for "Steuerbescheid morgen prüfen", run at 00:08 UTC.
A different cause (date around midnight), same class and same goal (FieldsSmokeTests green in CI) — decide in the
analysis whether it is bundled here or gets its own issue.

## Existing Patterns
- 18 uses of `XCTNSPredicateExpectation`/`XCTWaiter()` across seven UI test classes, mostly 5 s timeouts.
- `waitForExistence(timeout:)` with 5–10 s everywhere; CI runs six parts in parallel (#939, #971) on loaded runners.

## Dependencies
- Upstream: XCUITest query engine, CI simulator load (`host-load.log` in the artifact).
- Downstream: the CI check "UI Smoke (iOS Simulator)" is red unless every part is green (#939).

## Existing Specs
- `docs/specs/fix-939-ci-ui-smoke-zeitbudget.md` — part split and time limits.
- `docs/artifacts/feat-344-symbole/` — origin of this test (#344).

## Risks & Considerations
- Only test code changes; no app path, no device stage (no path of the device list touched).
- A longer timeout alone hides real regressions only if it is generous beyond reason; the label still has to change.
- Alternative to a longer budget: wait for the editor to be gone (pop finished) before reading the label once.

## Analysis

### Type
Bug (test only; the app behaves correctly in both failures)

### Root cause, proven from the run's `.xcresult`
1. `testLowAndMediumShowNoSignInTheRowButTheLadderInTheDetail` (artifact 14679371183): the app showed "Urgency, Low"
   about 1.2 s after the tap (screen recording). One accessibility *Find* on the loaded CI simulator took 4.2 s; the
   `XCTWaiter` (5 s budget, polls about once a second) got a single evaluation and timed out. Cause: the 5 s budget
   in `choose(_:in:app:)` is shorter than what one query can cost on a loaded runner, and nothing waits for the
   editor to be gone before the line is read.
2. `testCalendarWaitsForADate` (artifact 14680808375): activity timeline shows "Done" tapped at **23:59:58.7 UTC**,
   the row read after **00:00:04**. The rule set the due date to tomorrow = 21 Nov; read on 21 Nov the line correctly
   says "Today". The assertion `contains("Tomorrow")` assumes the day does not change during the test.

Both are timing assumptions in the same class with the same goal (FieldsSmokeTests green in CI) → bundled here
(rule "Folgearbeit bündeln").

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/FieldsSmokeTests.swift` | MODIFY | `choose`: hold the option by id `levelOption_<raw>`, wait for it to be gone (editor popped, 15 s), then wait for the line label with 15 s; `testCalendarWaitsForADate`: note the calendar day before capture, expect "Today" if the day changed by the time the row is read, else "Tomorrow" |

No app code. No path of the device list touched.

### Scope Assessment
- Files: 1 (test code; app LoC 0)
- Estimated LoC: +15/-5
- Risk Level: LOW — a longer wait only costs time when the state is late; a wrong value still fails.

### Technical Approach (recommendation)
- `choose`: `option = app.buttons["levelOption_\(raw)"]` (`Medium`→`medium`, `Low`→`low`), tap, then
  `XCTAssertTrue(option.waitForNonExistence(timeout: 15))`, then the label predicate with a 15 s budget. Waiting on the
  editor's disappearance separates "tap not taken" from "label late" in the failure message.
- Calendar: `let day = Calendar.current.startOfDay(for: Date())` before capture; after reading the row compute the
  expected word from whether `startOfDay(Date())` still equals `day`. The test's process clock and the simulator's
  clock are the same host clock, so the comparison holds.
- Proof: ten runs in a row of both tests in the simulator (`sim.sh test-proof FieldsSmokeTests` repeated), then five
  green `main` runs in CI (DoD).

### Alternatives (considered, not recommended)
- A fixed clock for UI tests (`--ui-testing-now <date>` read by `DueDateRule` and the formatting): makes every
  date test independent of the hour, but touches app code in several places (parser reference day, `isDateInToday`
  in views, `NewDateRule`) for a one-second window per day — out of proportion. Would be its own issue if more date
  tests start wobbling.
- Only raising the waiter's timeout without waiting for the editor to vanish: fixes the symptom too, but a lost tap
  would then show up as a 15 s "label" failure with the wrong explanation.
- Re-running failed tests in CI (`-retry-tests-on-failure`): rejected earlier (#172 removed CI retries; goal "green on
  the first attempt").

### Findings against the plan
None blocking: the other 17 `XCTNSPredicateExpectation` uses in six other classes carry the same 5 s pattern; they have
not failed in the recorded runs, so they stay out of scope (no drive-by changes). If one of them fails the same way,
it becomes its own issue.

### Open Questions
- none (no product decision; test code only)

## TDD RED (2026-11-21)
Two app-free tests in `FieldsSmokeTests` reproduce both CI failures deterministically:
- `testLineWaitOutlastsOneSlowQuery`: `SlowLine` answers its first `label` read after 4.2 s with the old value, then the
  chosen one; `waitUntil` with `lineBudget = 5` ends `XCTWaiterResult 2 (timedOut)`, the same result as run 44814947423.
- `testDueWordFollowsMidnight`: captured 23:59:58Z, read 00:00:04Z → expects "Today"; the stub `dueWord` returns "Tomorrow".
GREEN (/50-implement): `lineBudget` 15; `dueWord` = "Today" if `calendar.startOfDay` of the two dates differs, else
"Tomorrow"; in `choose` hold the option as `app.buttons["levelOption_\(level.lowercased())"]`, tap, then
`XCTAssertTrue(option.waitForNonExistence(timeout: 15))` before `waitUntil`. Evidence: `docs/artifacts/fix-972-fields-smoke-flaky/test-red-*.txt`.
