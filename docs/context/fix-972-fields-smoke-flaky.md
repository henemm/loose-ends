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
