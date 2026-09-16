# CLAUDE.md — Loose Ends

Say it, it's sorted. Task capture with on-device Apple Intelligence for iPhone, iPad, Mac and Watch.

## Ground rules (from docs/project/00-entscheidungen.md)

- **One multiplatform target.** iOS, iPadOS and macOS share every view in `LooseEnds/` and `Shared/`.
  There is no separate Mac UI. Layout adapts via `NavigationSplitView` and size classes.
- **Raw text is immutable.** Every derived field is optional and carries `*SourceRaw` and `*Confidence`.
- **Enrichment runs once** per task (`processedAt`). A second run only on explicit user request.
- **Learning is retrieval, not training.** Similar past tasks and user corrections are prompt examples.
- **Revisions, not undo.** Every AI or user change to a derived field is a `Revision`. Nothing is deleted.
- **Repeat without series.** `RepeatRule` on the task, roll forward on completion, `CompletionRecord` per cycle.
- **Color budget.** Accent = tappable (incl. AI tint), red = time pressure, grey = hierarchy, green = the completion moment.
- No `try?` that swallows errors, `Logger` not `print`, Swift 6 strict concurrency, deployment target 27.

## Build

The Xcode project is generated. Never edit `LooseEnds.xcodeproj` by hand.

```bash
brew install xcodegen xcbeautify
xcodegen generate
xcodebuild test -project LooseEnds.xcodeproj -scheme LooseEnds -destination 'platform=macOS' | xcbeautify
```

Set `DEVELOPMENT_TEAM` once in Xcode (Signing & Capabilities); it is intentionally empty in `project.yml`.

CI runs on GitHub's `macos-26` image. Until that image ships Xcode 27, CI compiles against the iOS 26.5 SDK
and warns about the 27.0 deployment target; iOS-27-only APIs (App Schemas, Private Cloud Compute model)
must be guarded with `#available` or wait for the image. The workflow selects Xcode 27 automatically once present.

## Process

Plugin `henemm/agent-os-openspec`. Fast-track for scaffolding, standard workflow with the 250-LoC limit after that.
Unit tests for enrichment, view rules, repeat rules and revisions come first; UI tests only after the design freeze, and only as smoke tests.

## Where things live

- `Shared/Models` — SwiftData model, enums, `RepeatRule`, `ViewRules` (pure view computation)
- `Shared/Persistence` — `ModelContainerFactory` (app group + private CloudKit)
- `Shared/Intents` — App Intents shared by app, widgets and (later) the intents extension
- `LooseEnds/` — app entry and views; `LooseEndsWatch/`, `LooseEndsWidgets/` — platform targets
- `docs/project/` — decisions, user story, data model, design briefing; `docs/reference/` — learnings carried over from FocusBlox

## Naming

`TaskItem` is the task model (not `Task`, which is Swift Concurrency). `TaskContext` is a context tag.
Bundle id `com.henning.looseends`, app group `group.com.henning.looseends`, CloudKit `iCloud.com.henning.looseends`.
