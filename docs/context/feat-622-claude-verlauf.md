# Context: feat-622-claude-verlauf

## Request Summary
#622 is built and merged (PR #867: orders `capture`, `complete`, `setDue`, `setNext`, `park`, `addSubtask`). Two DoD points
are open: (1) "Jede Änderung ist eine Nutzer-Revision mit Grund „Claude“" — today only `setDue` writes a revision; complete,
setNext, park and addSubtask leave no trace; (2) "einmal aus claude.ai belegt; erscheint in der App mit Revision" — needs the
app signed in to the service (#615 S4f waits on Henning's sign-in feedback), done by Claude afterwards, not in this workflow.
This workflow closes gap (1) and makes the trace visible in the app.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Services/OrderExecutor.swift` | runs every order; `setDue` keeps the revision and sets `reason = "Claude"`; the other four write none (comments at `setNext`: "Status and rank are no revised fields") |
| `Shared/Models/Enums.swift:65` | `RevisedField` (String raw values, stored in `Revision.fieldRaw`); last additions `notes`, `knaeuel`, `counts` appended at the end |
| `Shared/Models/Revision.swift` | `fieldRaw` String, getter falls back to `.title` for an unknown raw value; `reason`, `author`, `seenAt` |
| `Shared/Services/RevisionService.swift` | `set` writes through `FieldCodec` (encode old, apply new, revision author `.user`); `origin(of:)` exhaustive switch; `revertAll`/`automaticFields` iterate `allCases` |
| `Shared/Services/FieldCodec.swift` | exhaustive `encode`/`apply` switches over `RevisedField` |
| `Shared/Models/DetailFields.swift:34,64,84` | maps `RevisedField` ↔ `DetailField` (exhaustive) |
| `LooseEnds/Views/FieldFormatting.swift` | `label(_:)` and `value(_:for:)` for the "Changes" sheet (exhaustive) |
| `LooseEnds/Views/FieldEditorView.swift`, `FieldSettingsView.swift`, `TaskDetailView.swift` | further exhaustive switches over `RevisedField` |
| `LooseEnds/Views/TaskDetailView.swift:223-233, 852-905` | the "Changes" sheet (`RevisionsSheet`): reachable only via the row shown when `aiFields` (automatic origins) is non-empty; reset buttons only for automatic revisions |
| `Shared/Services/TaskActions.swift:36,71,103` | `complete`, `toggleNext`, `park` — used by the orders, write no revision |
| `Shared/Services/Subtasks.swift:17` | `add` — used by `addSubtask` |
| `LooseEndsTests/OrderExecutorTests.swift` | existing tests per order kind |

## Existing Patterns
- Hand-set marks as revisions: `knaeuel`/`counts` were added to `RevisedField` (#643/#645) with a `FieldCodec` case,
  `RevisionService.set(.knaeuel, …)` in `TaskActions`, label in `FieldFormatting`, no origin column (`origin` → nil).
- Reason on a revision: `OrderExecutor.setDue` and `SiriCapture` (reason "Siri") set `revision.reason` after `RevisionService.set`.
- Enum additions are appended at the end ("so existing orders stay as they are").

## Dependencies
- Upstream: `TaskActions`, `Subtasks`, `RevisionService`, `FieldCodec`, SwiftData.
- Downstream: the "Changes" sheet in the detail (iPhone, iPad, Mac share it); CloudKit syncs `Revision` rows (`fieldRaw` is a
  String — new raw values need no schema change).

## Existing Specs
- `docs/reference/claude-abschrift-vertrag.md` — order contract version 1 (unchanged by this work).
- PR #867 body: the decision not to add revision fields ("eigenes Ticket, falls Henning eine Spur will") — never reached Henning;
  the ticket text demands the revision.

## Risks & Considerations
- Scope: a new `RevisedField` case touches seven exhaustive switches (+ tests, strings) → more than 4–5 files; likely two cuts.
- Ground rule "Revisions, not undo" speaks of derived fields; status, rank and subtasks are not derived. A revision for them must
  never be resettable through the generic reset (author `.user` keeps the reset button hidden; `revertAll` only takes automatic).
- `RevisionService.set` writes through `FieldCodec.apply`; for status/rank/subtasks the change is made by `TaskActions`/`Subtasks`
  (roll-forward of repeats, Knäuel mark falls on park), so the revision must be recorded beside the action, not via `apply`.
- Visibility: the "Changes" sheet opens only when automatic fields exist; a task whose fields the user set shows no entry point,
  so even today's `setDue` revision from Claude can be invisible. Making it visible is a visible UI change → preview before spec.
- Older builds (App Store 1.0/1.0.1 on another device) decode an unknown `fieldRaw` as `.title` and would show such a row as a
  title change in their "Changes" sheet.
- `capture` is a creation, not a change; the task already carries `capturedVia = .claude`. No revision needed.
- Alternative to revisions: a per-task "Claude log" model (schema change) or a marker on `CompletionRecord` (only covers complete).

## Analysis

### Type
Feature (closes the open DoD point "Jede Änderung ist eine Nutzer-Revision mit Grund „Claude“" of #622; the claude.ai proof
waits on the signed-in app, #615 S4f, and is done afterwards, outside this workflow).

### Findings (verified in code)
- `OrderExecutor`: only `setDue` writes a revision (reason "Claude"). `complete`, `setNext`, `park`, `addSubtask` write none.
- Side effects already write revisions **without** reason: `TaskActions.complete` on a repeating task and `TaskActions.park`
  call `releaseKnaeuel` → `.knaeuel` revision. A repeating complete moves `dueDate` without any revision.
- `Subtasks.add` sets `capturedVia = .app`, also when Claude adds the line.
- Readers of user revisions: `ViewRules.postponeCount` (every `.user` dueDate revision with new > old counts as "postponed")
  and `EnrichmentWriter.userHasTouched` (blocks AI writes on that field). No learning code reads user revisions
  (`RecognitionRule`, `ContextWordLearning` don't). The unseen badge counts automatic authors only.
- Visibility: `RevisionsSheet` opens only from the row shown when `aiFields` (automatic origins) is non-empty
  (`TaskDetailView` ~223). A task Claude changed but the app never enriched has no entry point. In the sheet Claude
  appears as "You" with "Claude" as footnote.
- Older builds decode an unknown `fieldRaw` as `.title` → a new case shows as "Title: x → y" there. Only reachable for a user
  with a Claude account (store build has the account group off), i.e. Henning; cosmetic, no reset for user revisions.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Models/Enums.swift` | MODIFY | `RevisedField` + `status`, `nextRank`, `subtasks` appended at the end |
| `Shared/Services/FieldCodec.swift` | MODIFY | `encode` for the new cases; `apply` no-op (their change is made by `TaskActions`/`Subtasks`) |
| `Shared/Services/RevisionService.swift` | MODIFY | `origin` → nil for the new cases |
| `Shared/Models/DetailFields.swift` | MODIFY | `init?(revised:)` → nil for the new cases |
| `LooseEnds/Views/FieldFormatting.swift` | MODIFY | labels/values ("Status: Open → Done", "Next up: No → Yes", "Subtask: Empty → line"), author "Claude" |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | `value(of:)` switch; cut 2: entry row also for Claude revisions, author "Claude" in the sheet |
| `Shared/Services/OrderExecutor.swift` | MODIFY | a `Revision(author: .user, reason: "Claude")` per order; reason stamped on every revision the order wrote (diff of `task.revisions` ids before/after) |
| `Shared/Services/Subtasks.swift` | MODIFY | `add(…, via: CaptureSource = .app)`; executor passes `.claude` |
| `LooseEndsTests/OrderExecutorTests.swift` | MODIFY | one revision with reason "Claude" per order kind; Knäuel side revision stamped; repeating complete |
| `LooseEndsUITests/…` | CREATE/MODIFY | cut 2: entry row and "Claude" in the sheet (seeded via `--ui-testing`) |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | new labels de/en |

### Scope Assessment
- Files: ~10–11 (most are one-line switch cases); Estimated LoC: +260/-10 in total
- Over the 4–5 files limit → two cuts:
  - **Cut 1 (logic):** Enums, FieldCodec, RevisionService, DetailFields, FieldFormatting (label/value), TaskDetailView (switch only),
    OrderExecutor, Subtasks, tests, strings; ~180 LoC. The file count comes from exhaustive switches the compiler forces
    (one line each) — a technical scope question, decided by Claude per `openspec.yaml`, noted in the spec.
  - **Cut 2 (visibility):** TaskDetailView entry row + sheet author, UI test, strings; ~80 LoC. Design per preview.
- Risk Level: LOW–MEDIUM (no schema change, `fieldRaw` is a String; central types touched only additively)

### Technical Approach
Recommendation: approach A. Three new `RevisedField` cases at the end. `OrderExecutor` records the revision beside the action
(old/new taken before/after), author `.user`, reason "Claude"; afterwards every revision the order produced (e.g. the
Knäuel release) gets reason "Claude" by diffing `task.revisions` ids before/after the action. Repeating complete:
**no dueDate revision** (would count in `postponeCount` as a postponement); instead a `status` revision "Open → Done" for the
round (the `CompletionRecord` carries the date). `setDue` stays as is (a Claude postponement is the user's postponement and
should count). New revisions are never resettable (author `.user`), `revertAll` unaffected.
Cut 2 per preview, draft A (recommended): the existing bottom row also appears when Claude revisions exist and reads
"Zuletzt von Claude · <Zeit>"; in the sheet the author reads "Claude" (grey). Alternative B: own register line under "Gesagt".
Preview: `docs/artifacts/feat-622-claude-verlauf/index.html`, https://claude.ai/artifact/JJJDuT6nLHPiaC2ekYKWPu

### Alternatives
- Own log model per task (`ClaudeTrace`): CloudKit schema change and Production deploy behind Henning's sign-in; no gain.
- Rely on `CompletionRecord`/`capturedVia`: covers complete and capture only, misses DoD.
- Drop the DoD point (PR #867's unasked decision): contradicts the ticket text; would need Henning's word.
- No ADR falls for A; the ground rule "Revisions, not undo" (derived fields) is extended to status/next/subtasks for Claude orders only.

### Dependencies
`TaskActions`, `Subtasks`, `RevisionService`, `FieldCodec`, `ViewRules.postponeCount`, `EnrichmentWriter.userHasTouched`;
downstream the "Changes" sheet on iPhone, iPad and Mac; CloudKit syncs `Revision` (no schema change).

### Open Questions
- [x] PO: preview draft A or B (cut 2) — Henning chose **draft A** (bottom row "Zuletzt von Claude · <Zeit>"), 2026-11-15.
