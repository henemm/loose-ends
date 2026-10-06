# CLAUDE.md — Loose Ends

Say it, it's sorted. Task capture with on-device Apple Intelligence for iPhone, iPad, Mac and Watch.

## Ground rules (from docs/project/00-entscheidungen.md)

- **One multiplatform target.** iOS, iPadOS and macOS share every view in `LooseEnds/` and `Shared/`.
  There is no separate Mac UI. Layout adapts via `NavigationSplitView` and size classes.
- **Raw text is immutable.** Every derived field is optional and carries `*SourceRaw` and `*Confidence`.
- **Enrichment runs once** per task. `processedAt` marks the model step, `rulesAppliedAt` the rule step
  (independent of it, #144); a second run only on explicit user request.
- **Learning is recognition, not training** (ADR-5, rewritten 2026-09-27 after #69/#131). A raw text
  that was captured before sets that entry's contexts and duration again, silently, with the rule marker (#101)
  and a `Revision` like any enrichment — only values the user or a rule set, never a model guess (#215).
  The model never sets contexts (#215: it guessed differently on every run; empty beats a guess). Similarity-picked prompt examples are gone: measured on 287 real
  tasks, word overlap only carries where the text recurs almost verbatim (contexts 100 %, duration 97.2 %
  at ~60 % coverage) and drops to chance (55 %) on partial overlap; for energy it stays below the constant.
  Evidence: `docs/reference/retrieval-leave-one-out-rules.md`, decision in
  `docs/project/06-annahmen-und-experimente.md` (B1). User corrections remain first-class examples and
  completed tasks are never deleted.
- **Revisions, not undo.** Every AI or user change to a derived field is a `Revision`. Nothing is deleted.
- **Repeat without series.** `RepeatRule` on the task, roll forward on completion, `CompletionRecord` per cycle.
- **Color budget.** Accent = tappable (incl. AI tint), red = time pressure, grey = hierarchy, green = the completion moment.
- **Rules before the model** (Henning, 2026-09-20). Every derived field is first attempted with rules,
  regex, calendar, contacts or a word list. The on-device model only gets what needs language
  understanding (refining the title: since #202 `TitleRule` sets it at capture from the cleaned raw
  text, at most 12 words — 312 of 319 raw sentences have ≤ 12 words; the model may refine it). Every analysis and spec that proposes the model for a field must contain
  the line "Without the model this fails because …" with evidence from a measurement; without that line
  the rule path is the proposal. Every measurement report carries the rule-based column as baseline; if
  the rules beat the model, the rules win, and an existing ADR or schema is not a counter-argument.
  Measured 2026-09-20: model 50 % exact dates, 96.5 % invented; `NSDataDetector` 65 %, 0 % (#67, #92);
  own rule parser 99.3 %, 0 % (#92, Schnitt 1). Since #95 the rule parser sets the due date in the
  product path; the model schema lost the four due-date fields.
- **Context names are unique** (Henning, 2026-10-01, #157). Contexts are matched by name
  (`FieldCodec`), so two contexts named alike put both on a task ("Garden, Garden"). `CatalogService`
  rejects a taken name (trimmed, case- and accent-insensitive) when adding or renaming, and
  `mergeDuplicateContexts` folds existing duplicates at every start (CloudKit can deliver them later);
  the survivor is deterministic (system default, smallest `sortOrder`, smallest id) so all devices agree.
  Projects are not covered yet.
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
./scripts/sim.sh test-proof <Klasse>  # UI-Test + maschineller Simulator-Beleg (#145)
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

**Acceptance runs in stages, and the first two are never skipped** — tests, then Simulator
(`./scripts/sim.sh build`, `launch`, `screenshot`: the changed flow is played through and evidenced).
`docs/project/04-stand.md` has the reasoning and the commands. TestFlight is a distribution channel,
not a stage: it gives no debugger and no live logs, so it stays dormant until people other than
Henning test.

**Stage 3 — Henning's iPhone 16 Pro — is mandatory exactly when the change touches something the
Simulator cannot show** (Henning, 2026-09-29). Not a judgement call: the trigger is a file list, so
that it can be checked from the diff and never argued away. A device run is required when the change
touches any of these paths:

| Pfad | Was nur das Gerät zeigt |
|---|---|
| `Shared/Enrichment/FoundationModelsEnricher.swift`, `Shared/Enrichment/EnrichmentCoordinator.swift` | Apple Intelligence — der Simulator hat keine Modell-Assets |
| `Shared/Persistence/` | App-Gruppe und CloudKit-Abgleich zwischen Geräten |
| `LooseEndsWatch/` | Apple Watch |
| `LooseEndsWidgets/` | Widgets, Aktionstaste, Kurzbefehle |
| `LooseEndsShare/`, `Shared/Intents/` | Erfassung von außerhalb der App |
| `LooseEnds/Speech/` | Mikrofon und Spracherkennung |
| `LooseEnds/Notifications/` | Zustellung echter Mitteilungen |
| `project.yml`, jede `*.entitlements`, jede `Info.plist` | Signierung, Berechtigungen, Targets — die Klasse des App-Group-Absturzes |

Berührt der Schnitt keinen dieser Pfade, endet die Abnahme nach Stufe 2, und das wird im
Abschlussbericht mit genau diesem Satz begründet: „Kein Pfad der Geräteliste berührt." Berührt er
einen, läuft `./scripts/sim.sh device-status` (liest nur, installiert und startet nichts) — für
Apple Intelligence zusätzlich die Labor-App, die Henning selbst antippt. Einen nachgespielten
Bedienablauf auf dem Gerät gibt es seit dem Rückbau von #153 nicht mehr: Der Versuch dazu
überschrieb Hennings produktive Installation und bewies nicht, wofür er gebaut war. Für Watch,
Widgets, Share, Mikrofon und Mitteilungen bleibt der automatisierte Nachweis auf echter Hardware
damit offen (`docs/project/04-stand.md`, #143, #160). Seit #156 installieren Gerätebauten
(`device-build`, `lab`) unter einer eigenen Kennung (`com.henning.looseends.probe`, Anzeigename
„LE Prüfbau") mit eigener App-Gruppe und eigenem iCloud-Container — nie unter Hennings eigener
Installation. Ein Registrierungslauf (`LOOSEENDS_REGISTER=1 ./scripts/sim.sh device-build`) ist
nur nötig bei neuer Kennung, neuer Fähigkeit oder abgelaufenem Profil; nur er benutzt Hennings
Xcode-Anmeldung, der normale Bau spricht nicht mit Apple. Im Zweifel läuft die Stufe.

**⛔ Ausliefern ist Teil jedes Tickets.** Gearbeitet wird in einem Worktree, gebaut wird bei Henning aus
`/Users/hem/Developer/loose-ends`. Den Checkout hält der SessionStart-Hook
`~/.claude/scripts/loose-ends-sync-main.sh` aktuell (`main` nachziehen, Projekt neu erzeugen) — ohne ihn
läuft bei Henning der Stand von vorher (2026-09-19: eine App ohne Erfassungs-Button, weil die erzeugte
Projektdatei 70 neue Dateien nicht kannte).

Henning bekommt nur dann etwas zu tun, wenn **Stufe 3** (Geräteliste oben) greift. Dann, nach dem Merge,
genau diese eine Zeile zum Kopieren, immer dieselbe:

```bash
cd /Users/hem/Developer/loose-ends && bash ~/.claude/scripts/loose-ends-sync-main.sh && ./scripts/sim.sh device
```

Sie zieht `main` nach, erzeugt das Projekt neu und baut, installiert und startet „LE Prüfbau“ auf seinem
iPhone (entsperrt, im selben WLAN) — ohne Xcode, neben seiner eigenen Installation. Dazu ein Satz, was
er ausprobieren soll und was er sehen muss. Greift Stufe 3 nicht, endet die Abnahme nach Stufe 2 und
Henning bekommt keine Zeile, nur den Satz „Kein Pfad der Geräteliste berührt.“

**Henning ist PO, nicht Entwickler** (Henning, 2026-10-06). Claude handelt als sein Tech Lead und
entscheidet Technisches selbst nach Best Practice: Git, Branches, Merges, Konflikte, Build. Henning
bekommt keine Git-Befehle, keine Diagnoseschritte und keine Rückfragen zu Technik — nur Produktfragen
und die eine Zeile oben. Befehle für ihn sind ein einziger Copy-Paste-Block ohne `#`-Kommentare (zsh
liest sie interaktiv als Argumente). Die Labor-App (`./scripts/sim.sh lab`) ist nur für Messungen gegen
Apple Intelligence, nicht für den Test eines Tickets. Eine Cloud-Session erreicht seinen Mac und sein
iPhone nicht; das sagt sie, statt Schritte zu verteilen.

CI runs on GitHub's preview label `xcode-27` with Xcode 27.0 pinned: every job uses the composite action
`.github/actions/select-xcode-27`, which selects `/Applications/Xcode_27.app` and stops the run if it
reports any other version. The deployment target stays at 27.0, nothing in `project.yml` is changed, and
UI Smoke and Speech Stress run only on an iPhone 17 simulator with iOS 27.0 (otherwise the step stops).
If the label goes away or is renamed, follow `docs/reference/testflight.md` and adjust `runs-on` in
`ci.yml`, `speech-stress.yml` and `testflight.yml`.

## Ship

`.github/workflows/testflight.yml` archives the iOS app with cloud-managed signing and uploads it to
TestFlight (manual run or a `v*` tag). Setup for the account owner: `docs/reference/testflight.md`.
Since #174 it runs on the `xcode-27` preview image with Xcode 27.0 pinned and never lowers the
deployment targets; a step before the upload checks every target in the archive (27 SDK, minimum 27.0,
version, dSYM, privacy strings) and stops the upload on any mismatch.

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
- `Shared/Persistence` — `ModelContainerFactory` (app group + private CloudKit; identifiers read from
  `Info.plist`, keys `LEAppGroup`/`LECloudContainer`, with the production constants as fallback —
  device builds carry their own via `BUNDLE_ID_SUFFIX`, #156), `ContextSeeder`
- `Shared/Services` — `CaptureService`, `FieldCodec` (one encoding per field), `RevisionService` (reset = user revision),
  `TaskActions` (done, next up, park, move, restore), `DateExpressionParser`/`TimeExpressionParser` (rule-based
  date/time extraction DE/EN, moved from `Measurement/` in #95), `RawTextWords` (the one tokenizer for word-set
  equality, shared with `Measurement/`, moved from `TitleCheck` in #136), `TitleRule` (the title at capture: raw text
  cleaned, first 12 words, #202). All pure over the model objects; the
  caller saves.
- `Shared/Enrichment` — `TaskEnricher` protocol, `EnrichmentWriter` (threshold + revisions), `EnrichmentCoordinator`
  (catch-up pass), `FoundationModelsEnricher` (on-device model, `#if canImport(FoundationModels)`), `DueDateRule`
  (combines the rule parsers into the due date, confidence 1.0, #95), `ImportanceUrgencyRule` (keyword
  match for importance/urgency, confidence 1.0, no default on miss, #117), `RecognitionRule` (equality of
  `RawTextWords` sets contexts and duration from an earlier task, confidence 1.0, no energy, #136)
- `Shared/Intents` — App Intents shared by app, widgets and (later) the intents extension
- `LooseEnds/` — app entry and views (iPhone, iPad, Mac); `LooseEndsWatch/`, `LooseEndsWidgets/`, `LooseEndsShare/`
  (iOS share sheet: text, links, mails via `SharedContent`) — platform targets
- `LooseEnds/Speech` — `SpeechCapture` (live recognition for the capture scene, skipped under `--ui-testing`), `Waveform`
- `Shared/Notifications` — `DueReminders` (pure plan and action handling); `LooseEnds/Notifications` —
  `DueNotificationCenter` (system wiring, silent under tests)
- `Shared/` compiles into the watch and widget targets too: no SwiftUI that is unavailable on watchOS there
  (keyboard shortcuts, navigation bar modifiers). App views belong in `LooseEnds/Views`.
- `docs/project/` — decisions, user story, data model, design briefing, load-bearing assumptions with their experiments and alternatives (`06-annahmen-und-experimente.md`); `docs/reference/` — learnings carried over from FocusBlox
- `Measurement/` — measurement-only code against the fidelity, self-consistency and convention corpora
  (e.g. `RuleBaseline` for the word→context convention test, spike #69; `LeaveOneOut` for the rule-based
  leave-one-out test — Jaccard word overlap as neighbor search against a corpus-derived baseline, #131);
  compiles into `LooseEndsTests` and the lab app only, no product path

## Naming

`TaskItem` is the task model (not `Task`, which is Swift Concurrency). `TaskContext` is a context tag.
Bundle id `com.henning.looseends`, app group `group.com.henning.looseends`, CloudKit `iCloud.com.henning.looseends`.
