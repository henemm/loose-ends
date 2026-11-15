# Context: feat-622-s2-claude-sichtbar

## Request Summary
#622 Schnitt 2 (Epic #612): what Claude changed on a task becomes visible in the app. Draft A, chosen by Henning on
2026-11-15 (`docs/artifacts/feat-622-claude-verlauf/index.html`): the known row at the end of the detail also appears
when only Claude changed something and names it — "Zuletzt von Claude · heute 14:02" — and opens the same "Changes"
sheet, where the author reads "Claude" (grey like "You", no Reset). Logic is done since Schnitt 1 (PR #927).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/TaskDetailView.swift:223-235` | entry row, shown only `if !aiFields.isEmpty`; `originSummary` (375-382) builds "N from your words · N from AI" |
| `LooseEnds/Views/TaskDetailView.swift:847-905` | `RevisionsSheet`: author via `FieldFormatting.author(revision.author)`, tint for automatic, grey otherwise; reason as footnote; Reset only for automatic |
| `LooseEnds/Views/FieldFormatting.swift:145-151` | `author(_ source: FieldSource)`: AI / You / Your words — no notion of Claude |
| `Shared/Services/OrderExecutor.swift:43` | `static let reason = "Claude"`; every order writes `Revision(author: .user, reason: "Claude")` (Schnitt 1) |
| `Shared/Services/RevisionService.swift` | `automaticFields(on:)`, `origin(of:on:)`; natural home of a pure "last Claude change" query |
| `Shared/Models/Revision.swift` | `author: FieldSource`, `reason: String?`, `createdAt` |
| `LooseEnds/App/LooseEndsApp.swift:111-140` | pattern for UI-test seeding under a `--ui-testing-*` flag in the in-memory store (`seedLeftoversIfAsked`) |
| `LooseEndsUITests/DriveSmokeTests.swift:210-227` | pattern: open detail, `scrolledTo("revisionsButton")`, tap, assert texts in the sheet, `shot(...)` |
| `LooseEnds/Resources/Localizable.xcstrings` | new keys need a German value (`scripts/test_catalog_languages.py`) |

## Existing Patterns
- Claude's mark is data, not a new author: `author == .user && reason == OrderExecutor.reason`. No `FieldSource.claude`
  (would change the CloudKit-synced enum raw values and reset semantics; Schnitt 1 decided against it).
- Seeded UI states use a `--ui-testing-*` launch flag that only acts with `ModelContainerFactory.isUITesting`.
- Relative time in the app: `Text(date, format: .dateTime...)`/`RelativeDateTimeFormatter`; the draft says "heute 14:02".

## Dependencies
- Upstream: `Revision`, `OrderExecutor.reason`, `RevisionService`.
- Downstream: detail on iPhone, iPad and Mac (one shared view); `DesignGalleryTests` and `DriveSmokeTests` find
  `revisionsButton`/`originSummary` — the identifiers stay.

## Existing Specs
- `docs/specs/feat-622-schnitt-1-claude-revisionen.md` (Schnitt 1, section "Nicht in diesem Schnitt" defines this cut)
- `docs/context/feat-622-claude-verlauf.md` (full analysis of #622)

## Open points for the analysis
- Row text when automatic fields AND a Claude revision exist: append ("2 aus deinen Worten · Zuletzt von Claude · heute 14:02")
  vs. show only one. Draft A shows the Claude part; proposal: append.
- Reason footnote "Claude" would repeat the author "Claude" in the sheet → hide the reason when it is the Claude marker.
- Gegenprüfung Schnitt 1: `park` drops `nextRank` without its own revision. Proposal: no extra row (status "Parked"
  already says it; parking always leaves "Next up", the app's own park writes no rank revision either).
- UI test needs a Claude revision without network: seed flag (e.g. `--ui-testing-claude-change`) that runs one
  `OrderExecutor` order on a seeded task — exercises the real order path, not a hand-made revision.

## Risks & Considerations
- Scope: TaskDetailView, FieldFormatting (or RevisionService), LooseEndsApp seed, xcstrings, one UI test + unit test
  → 5–6 files; LoC ~120.
- Device list: no path touched (`LooseEnds/Views`, `LooseEnds/App`, `Shared/Services`, `Localizable.xcstrings`).
- Unseen badge counts automatic authors only — Claude changes must not light it (they are the user's own via Claude).

## Analysis

### Type
Feature (#622 Schnitt 2, Epic #612). Draft A approved by Henning 2026-11-15.

### Findings (verified in code, 2026-11-15)
- The entry row (`TaskDetailView.swift:223`) shows only `if !aiFields.isEmpty`; `aiFields` = `RevisionService.automaticFields`
  (AI/rule authors). A task Claude only completed, moved or parked has no automatic field → no row, the change is invisible.
- `RevisionsSheet` already lists every revision, Claude's too, but labels them "You" with the footnote "Claude".
- `markSeen` touches automatic authors only → Claude revisions never light the unseen badge (wanted, no change).
- `capture` leaves no revision (`CaptureService.save(via: .claude)`); the raw text is the user's own dictation. Not part of
  this cut: the row speaks of changes; a capture by Claude would need its own wording (decision below).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Services/RevisionService.swift` | MODIFY | pure `lastClaudeChange(on:) -> Revision?` (author `.user`, reason `OrderExecutor.reason`, newest `createdAt`) and `isByClaude(_:)` |
| `LooseEnds/Views/FieldFormatting.swift` | MODIFY | `author(of revision:)`: "Claude" for the Claude mark, else `author(_:)` unchanged |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | row shows when `aiFields` or a Claude change exist; `originSummary` appends "Last by Claude · <relative date + time>"; sheet: Claude as author (grey), reason footnote hidden when it is the Claude mark |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | seed flag `--ui-testing-claude-change`: seeds a task and runs one real `OrderExecutor` order (e.g. `setDue`) on it |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | "Last by Claude · %@", "Claude" with German values |
| `LooseEndsTests/…RevisionServiceClaudeTests.swift` | CREATE | unit tests for `lastClaudeChange`/`isByClaude` (newest wins, AI/plain user/other reason ignored) |
| `LooseEndsUITests/ClaudeChangeTests.swift` | CREATE | open seeded detail, row text contains "Claude", tap `revisionsButton`, sheet shows "Claude", no Reset; screenshots light/dark |

### Scope Assessment
- Files: 5 modified + 2 test files (tests count against the limit as one slice; ~7 total, production 5)
- Estimated LoC: ~+130 / -10 (production ~60, tests ~70)
- Risk Level: LOW — display only, no model or schema change, no device-list path (`LooseEnds/Views`, `LooseEnds/App`,
  `Shared/Services`, xcstrings). Acceptance ends after stage 2: „Kein Pfad der Geräteliste berührt."

### Technical Approach (recommendation)
Claude stays data, not an author: `author == .user && reason == OrderExecutor.reason` (decided in Schnitt 1). One pure query
in `RevisionService`, the view only reads it. Row text:
- only Claude: "Zuletzt von Claude · heute 14:02"
- both: "2 aus deinen Worten · Zuletzt von Claude · heute 14:02" (appended; keeps the known summary, draft A's Claude part last)
- time: `Date.FormatStyle` relative day + time ("heute 14:02", "gestern 09:10", older: "12. Nov. 14:02").
Sheet: author label "Claude" in grey (`.secondary`, like "You"), no Reset (it is not automatic), footnote "Claude" suppressed
so the word does not stand twice; any other reason still shows.
Identifiers `originSummary`/`revisionsButton` stay (DesignGallery, DriveSmoke use them).

### Alternatives
- **New author `FieldSource.claude`**: cleanest label logic, but changes a CloudKit-synced enum raw value set, reset semantics
  (`isAutomatic`) and learning (ADR-5: user corrections are examples) → would overturn the Schnitt 1 decision; rejected.
- **Own row/section "Von Claude"** instead of appending to the known row (draft B in the artifact): Henning chose A.
- **Badge for unseen Claude changes**: rejected — Claude acts on the user's own words; the badge is for guesses.

### Decisions taken (tech lead)
- `park` drops `nextRank` without its own revision: no extra row (status "Parked" says it; app's own park does the same).
- Capture by Claude: not named in this cut (no revision exists; raw text is the user's). Can follow as its own issue if wanted.

### Dependencies
Upstream: `Revision`, `OrderExecutor.reason`, `RevisionService`, `FieldFormatting`. Downstream: the one shared detail view
(iPhone, iPad, Mac), `DesignGalleryTests`, `DriveSmokeTests`.

### Open Questions
- none (draft approved; remaining choices are technical)
