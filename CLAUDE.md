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
- **Rules before the model** (Henning, 2026-09-20). Every derived field is first attempted with rules,
  regex, calendar, contacts or a word list. The on-device model only gets what needs language
  understanding (the title). Every analysis and spec that proposes the model for a field must contain
  the line "Without the model this fails because …" with evidence from a measurement; without that line
  the rule path is the proposal. Every measurement report carries the rule-based column as baseline; if
  the rules beat the model, the rules win, and an existing ADR or schema is not a counter-argument.
  Measured 2026-09-20: model 50 % exact dates, 96.5 % invented; `NSDataDetector` 65 %, 0 % (#67, #92);
  own rule parser 99.3 %, 0 % (#92, Schnitt 1). Since #95 the rule parser sets the due date in the
  product path; the model schema lost the four due-date fields.
- No `try?` that swallows errors, `Logger` not `print`, Swift 6 strict concurrency, deployment target 27.
- A `ModelContext` does not retain its `ModelContainer`. Keep the container alive for as long as the context
  is used (tests: hold it in a local or a helper struct), or the next save or fetch crashes the process.

## Build

The Xcode project is generated. Never edit `LooseEnds.xcodeproj` by hand.

```bash
brew install xcodegen xcbeautify
./scripts/sim.sh generate     # LooseEnds.xcodeproj aus project.yml
./scripts/sim.sh unit         # Unit-Tests
./scripts/sim.sh build        # iOS-App für den Simulator
```

Immer über `scripts/sim.sh` gehen, nicht direkt über `xcodebuild`. Das Skript wählt Destinationen,
die zum Deployment Target passen: Der Mac hostet die Tests nur, wenn sein macOS ≥ Target ist
(sonst laufen sie im Simulator), und ein Simulator zählt nur mit Laufzeit ≥ iOS-Target — Gerätenamen
wie „iPhone 17" gibt es unter mehreren iOS-Versionen, und die falsche lehnt Xcode als Ziel ab.

Das Projekt ist generiert und nicht versioniert: Nach jedem neuen Stand muss `generate` laufen,
sonst kennt Xcode die neu hinzugekommenen Dateien nicht und baut eine App ohne die neuen Views.

`DEVELOPMENT_TEAM` steht in `project.yml` (`XK87E2B3VR`) und darf dort nicht geleert werden: Xcode
legt das Team in der erzeugten Projektdatei ab, die bei jedem `generate` neu geschrieben wird — ein
leerer Wert heißt, dass Xcode nach dem nächsten Stand jeden Gerätestart verweigert.

**Acceptance runs in three stages and none may be skipped** — tests, then Simulator, then Henning's
iPhone 16 Pro (`./scripts/sim.sh device`, paired over the local network). A change is only done once
it ran on the device. `docs/project/04-stand.md` has the reasoning and the commands. TestFlight is a
distribution channel, not a stage: it gives no debugger and no live logs, so it stays dormant until
people other than Henning test.

**⛔ Ausliefern ist Teil jedes Tickets — der letzte Schritt vor Hennings eigenem Test.** Gearbeitet
wird in einem Worktree, gebaut wird bei Henning aus `/Users/hem/Developer/loose-ends`. Nach dem Merge
und bevor er selbst testet, muss dort beides stimmen:

```bash
bash ~/.claude/scripts/loose-ends-sync-main.sh   # main nachziehen + Projekt neu erzeugen
```

Ohne diesen Schritt startet Xcode bei ihm den Stand von vorher — am 2026-09-19 war das eine App ohne
Erfassungs-Button, weil die erzeugte Projektdatei 70 neue Dateien nicht kannte. Ein Ticket ohne
diesen Schritt ist nicht fertig, egal wie grün die Tests sind.

CI runs on GitHub's `macos-26` image. Until that image ships Xcode 27, each CI job lowers the deployment
targets in `project.yml` to 26.0 before generating the project (Xcode only offers simulators that meet
the project's deployment target). iOS-27-only APIs (App Schemas, Private Cloud Compute model) must be
guarded with `#available` until then. The workflow selects Xcode 27 automatically once present.

## Ship

`.github/workflows/testflight.yml` archives the iOS app with cloud-managed signing and uploads it to
TestFlight (manual run or a `v*` tag). Setup for the account owner: `docs/reference/testflight.md`.

## Process

Plugin `henemm/agent-os-openspec`. Fast-track for scaffolding, standard workflow with the 250-LoC limit after that.
It lives in Henning's own marketplace, not the official one, so register that first:

```bash
claude plugin marketplace add henemm/agent-os-openspec@main
claude plugin install agent-os-openspec
```
Unit tests for enrichment, view rules, repeat rules and revisions come first; UI tests only after the design freeze, and only as smoke tests.

**GitHub Issues is the one and only backlog.** Every open task — feature, bug, spike — is a GitHub
issue with its own Definition of Done, not a bullet in a markdown file. `docs/project/04-stand.md`
only holds the priority order and links to issue numbers; never re-list scope or DoD there, and never
resurrect a status column in `docs/project/01-user-story.md` (it's a one-time snapshot from the
briefing, not maintained). Opening a PR for an issue: reference it (`Closes #N`) so it auto-closes on
merge; if it doesn't auto-close, close it by hand. New work discovered mid-task becomes a new issue,
not scope creep on the current one.

## Where things live

- `Shared/Models` — SwiftData model, enums, `RepeatRule`, `ViewRules` (pure view computation)
- `Shared/Persistence` — `ModelContainerFactory` (app group + private CloudKit), `ContextSeeder`
- `Shared/Services` — `CaptureService`, `FieldCodec` (one encoding per field), `RevisionService` (reset = user revision),
  `TaskActions` (done, next up, park, move, restore), `DateExpressionParser`/`TimeExpressionParser` (rule-based
  date/time extraction DE/EN, moved from `Measurement/` in #95). All pure over the model objects; the caller saves.
- `Shared/Enrichment` — `TaskEnricher` protocol, `EnrichmentWriter` (threshold + revisions), `EnrichmentCoordinator`
  (catch-up pass), `FoundationModelsEnricher` (on-device model, `#if canImport(FoundationModels)`), `DueDateRule`
  (combines the rule parsers into the due date, confidence 1.0, #95), `ImportanceUrgencyRule` (keyword
  match for importance/urgency, confidence 1.0, no default on miss, #117)
- `Shared/Intents` — App Intents shared by app, widgets and (later) the intents extension
- `LooseEnds/` — app entry and views (iPhone, iPad, Mac); `LooseEndsWatch/`, `LooseEndsWidgets/`, `LooseEndsShare/`
  (iOS share sheet: text, links, mails via `SharedContent`) — platform targets
- `LooseEnds/Speech` — `SpeechCapture` (live recognition for the capture scene, skipped under `--ui-testing`), `Waveform`
- `Shared/Notifications` — `DueReminders` (pure plan and action handling); `LooseEnds/Notifications` —
  `DueNotificationCenter` (system wiring, silent under tests)
- `Shared/` compiles into the watch and widget targets too: no SwiftUI that is unavailable on watchOS there
  (keyboard shortcuts, navigation bar modifiers). App views belong in `LooseEnds/Views`.
- `docs/project/` — decisions, user story, data model, design briefing, load-bearing assumptions with their experiments and alternatives (`06-annahmen-und-experimente.md`); `docs/reference/` — learnings carried over from FocusBlox
- `Measurement/` — measurement-only code against the fidelity corpus; compiles into `LooseEndsTests` and
  the lab app only, no product path

## Naming

`TaskItem` is the task model (not `Task`, which is Swift Concurrency). `TaskContext` is a context tag.
Bundle id `com.henning.looseends`, app group `group.com.henning.looseends`, CloudKit `iCloud.com.henning.looseends`.
