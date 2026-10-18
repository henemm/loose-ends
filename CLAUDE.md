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
  and a `Revision` like any enrichment — only values the user set (#244): never a model guess (#215), and no rule value either, since it may be a guess an earlier recognition already copied.
  The model never sets contexts (#215: it guessed differently on every run; empty beats a guess). Similarity-picked prompt examples are gone: measured on 287 real
  tasks, word overlap only carries where the text recurs almost verbatim (contexts 100 %, duration 97.2 %
  at ~60 % coverage) and drops to chance (55 %) on partial overlap; for energy it stays below the constant.
  Evidence: `docs/reference/retrieval-leave-one-out-rules.md`, decision in
  `docs/project/06-annahmen-und-experimente.md` (B1). User corrections remain first-class examples and
  completed tasks are never deleted.
- **Revisions, not undo.** Every AI or user change to a derived field is a `Revision`. Nothing is deleted.
- **Repeat without series.** `RepeatRule` on the task, roll forward on completion, `CompletionRecord` per cycle.
- **Color budget.** Accent = tappable (incl. AI tint), red = time pressure, grey = hierarchy, green = the completion moment.
- **SF Symbols only** (Henning, 2026-10-12, #350). Every sign in the app is an SF Symbol, outline where one exists:
  no emoji, no characters standing in for a symbol (»«, →), no own images. The one exception is the logo's thread
  (knot, loose thread, #180): it is the brand mark, not a control.
- **Rules before the model** (Henning, 2026-09-20). Every derived field is first attempted with rules,
  regex, calendar, contacts or a word list. The on-device model only gets what needs language
  understanding (refining the title: since #202 `TitleRule` sets it at capture from the cleaned raw
  text, at most 12 words — 312 of 319 raw sentences have ≤ 12 words; the model may refine it). Every analysis and spec that proposes the model for a field must contain
  the line "Without the model this fails because …" with evidence from a measurement; without that line
  the rule path is the proposal. Every measurement report carries the rule-based column as baseline; if
  the rules beat the model, the rules win, and an existing ADR or schema is not a counter-argument.
  Measured 2026-09-20: model 50 % exact dates, 96.5 % invented; `NSDataDetector` 65–68 % depending on the weekday of the run (it takes no reference day, so its column is frozen, #148), 0 % (#67, #92);
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
./scripts/sim.sh unit         # Unit-Tests im iOS-Simulator (Mac als Host nur mit LOOSEENDS_MAC_HOST=1)
./scripts/sim.sh build        # iOS-App für den Simulator
./scripts/sim.sh test-proof <Klasse>  # UI-Test + maschineller Simulator-Beleg (#145)
./scripts/sim.sh watch-test-proof <Klasse>  # dasselbe im watchOS-Simulator, App vorher deinstalliert (#409)
./scripts/sim.sh launch-measure <n>   # Kaltstart-Messung, n Starts auf dem Gerät (#22)
./scripts/sim.sh real-model            # echtes On-Device-Modell auf diesem Mac, nur lokal (#531)
```

`launch-measure` baut einen Release-Prüfbau und startet ihn per devicectl; es läuft nur nach Hennings
ausdrücklichem „jetzt ist ein Test möglich“ (Regel im Stufe-3-Absatz unten, nicht umgehen).

Immer über `scripts/sim.sh` gehen, nicht direkt über `xcodebuild`. Das Skript wählt Destinationen,
die zum Deployment Target passen: Ein Simulator zählt nur mit Laufzeit ≥ iOS-Target — Gerätenamen
wie „iPhone 17" gibt es unter mehreren iOS-Versionen, und die falsche lehnt Xcode als Ziel ab.
`unit` läuft im Simulator; der Mac hostet die Unit-Tests nur mit `LOOSEENDS_MAC_HOST=1` und macOS ≥ Target
(#294, #374).

Parallele Sitzungen (#341, #304, #413): `build`, `unit`, `sim-unit`, `test`, `test-proof`, `launch` und
`mac-build` holen die rechnerweite Sperre `/tmp/loose-ends-testlauf.lock` (Datei `pid`: PID, Startzeit,
Worktree, Befehl). Wer wartet, sieht alle 30 s den Halter und bricht nach 30 min ab; eine verwaiste Sperre
(Prozess tot oder PID wiederverwendet) wird sofort übernommen, eine Sperre ohne `pid`-Datei erst nach 30 min.
Übernommen wird nur unter `<Sperre>.takeover`, damit zwei Wartende sich nicht gegenseitig die neue Sperre
wegziehen. `boot` markiert auf jedem iOS-Simulator den Tastatur-Hinweis „Speed up your typing…“ als gezeigt:
auf einem frischen Simulator hängt er sonst jede UI-Abfrage nach dem ersten `typeText` auf.
DerivedData liegt je Worktree unter `LooseEnds-session-<Ordnername>` (`CLAUDE_SESSION_ID` überschreibt den
Schlüssel). Die Handabsprache per Sperrdatei zwischen Sitzungen entfällt.

Das Projekt ist generiert und nicht versioniert: Nach jedem neuen Stand muss `generate` laufen,
sonst kennt Xcode die neu hinzugekommenen Dateien nicht und baut eine App ohne die neuen Views.

Berechtigungen gehören in `project.yml` (`entitlements.properties`), nie nur in die erzeugte `.entitlements`-Datei:
`generate` überschreibt sie (#311). `scripts/test_entitlements_sync.py` und die Archivprüfung `entitled` sichern das ab
(`docs/reference/testflight.md`).

`DEVELOPMENT_TEAM` steht in `project.yml` (`XK87E2B3VR`) und darf dort nicht geleert werden: Xcode
legt das Team in der erzeugten Projektdatei ab, die bei jedem `generate` neu geschrieben wird — ein
leerer Wert heißt, dass Xcode nach dem nächsten Stand jeden Gerätestart verweigert.

**Acceptance runs in stages, and the first two are never skipped** — tests, then Simulator
(`./scripts/sim.sh build`, `launch`, `screenshot`: the changed flow is played through and evidenced).
`docs/reference/abnahme-und-arbeitsweise.md` has the reasoning and the commands. TestFlight is a distribution channel,
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
| `LooseEndsWatch/`, `LooseEndsWatchWidgets/` | Apple Watch, Komplikation auf dem Zifferblatt |
| `LooseEndsWidgets/` | Widgets, Aktionstaste, Kurzbefehle |
| `LooseEndsShare/`, `Shared/Intents/` | Erfassung von außerhalb der App |
| `LooseEnds/Speech/` | Mikrofon und Spracherkennung |
| `LooseEnds/Notifications/` | Zustellung echter Mitteilungen |
| `project.yml`, jede `*.entitlements`, jede `Info.plist` | Signierung, Berechtigungen, Targets — die Klasse des App-Group-Absturzes |

Berührt der Schnitt keinen dieser Pfade, endet die Abnahme nach Stufe 2, und das wird im
Abschlussbericht mit genau diesem Satz begründet: „Kein Pfad der Geräteliste berührt." **⛔ Nichts
auf Hennings Geräten, auch nichts Lesendes, bevor er wörtlich „jetzt ist ein Test möglich“ geschrieben
hat** (Henning, 2026-10-08) — eine Ankündigung ist keine Frage, die Stufe ist keine Dauererlaubnis.
Erst dann, und nur für diesen einen Durchgang, läuft `./scripts/sim.sh device-status` (liest nur, installiert und startet nichts) — für
Apple Intelligence zusätzlich die Labor-App, die Henning selbst antippt. Einen nachgespielten
Bedienablauf auf dem Gerät gibt es seit dem Rückbau von #153 nicht mehr: Der Versuch dazu
überschrieb Hennings produktive Installation und bewies nicht, wofür er gebaut war. Für Watch,
Widgets, Share, Mikrofon und Mitteilungen bleibt der automatisierte Nachweis auf echter Hardware
damit offen (`docs/reference/abnahme-und-arbeitsweise.md`). Seit #156 installieren Gerätebauten
(`device-build`, `lab`) unter einer eigenen Kennung (`com.henning.looseends.probe`, Anzeigename
„LE Prüfbau") mit eigener App-Gruppe und eigenem iCloud-Container — nie unter Hennings eigener
Installation. Ein Registrierungslauf (`LOOSEENDS_REGISTER=1 ./scripts/sim.sh device-build`) ist
nur nötig bei neuer Kennung, neuer Fähigkeit oder abgelaufenem Profil; nur er benutzt Hennings
Xcode-Anmeldung, der normale Bau spricht nicht mit Apple. Im Zweifel läuft die Stufe.

**Stufe 3 läuft über TestFlight** (Henning, 2026-10-10, #279: „Mache den Test über die normale App und
TestFlight."): Statt „LE Prüfbau“ testet Henning in seiner normalen App aus TestFlight, wann er es
einrichten kann. Ablauf: Merge, TestFlight-Bau (bei Modelländerung vorher `mac-schema-init` und Deploy),
dann bekommt Henning die Buildnummer und die Prüfschritte, keine Befehlszeile. Seine Rückmeldung
schließt die Gerätepunkte der Spec ab; bis dahin bleibt das Ticket offen.

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
er ausprobieren soll und was er sehen muss.

Zeigt sich der Schnitt auf dem Mac (macOS-Verhalten, Mac-Rechte, Mac-Layout), bekommt er stattdessen oder
zusätzlich die Mac-Zeile (#287). Sie baut „LE Prüfbau“ für den Mac (Prüfkennung, eigene Daten), legt ihn
nach `~/Applications` und startet ihn — nie seine normale Mac-App (Henning, 2026-10-08):

```bash
cd /Users/hem/Developer/loose-ends && bash ~/.claude/scripts/loose-ends-sync-main.sh && ./scripts/sim.sh mac
```

Beim allerersten Mal (noch kein Mac-Profil der Prüfkennung) steht `LOOSEENDS_REGISTER=1` vor `./scripts/sim.sh mac`. Greift Stufe 3 nicht, endet die Abnahme nach Stufe 2 und
Henning bekommt keine Zeile, nur den Satz „Kein Pfad der Geräteliste berührt.“

**Henning ist PO, nicht Entwickler** (Henning, 2026-10-06). Claude handelt als sein Tech Lead und
entscheidet Technisches selbst nach Best Practice: Git, Branches, Merges, Konflikte, Build. Henning
bekommt keine Git-Befehle, keine Diagnoseschritte und keine Rückfragen zu Technik — nur Produktfragen
und die eine Zeile oben. Befehle für ihn sind ein einziger Copy-Paste-Block ohne `#`-Kommentare (zsh
liest sie interaktiv als Argumente). Die Labor-App (`./scripts/sim.sh lab`) ist nur für Messungen gegen
Apple Intelligence, nicht für den Test eines Tickets. Eine Cloud-Session erreicht seinen Mac und sein
iPhone nicht; das sagt sie, statt Schritte zu verteilen.

**Fragen an Henning immer über das AskUserQuestion-Tool** (Henning, 2026-10-08): jede Produktfrage,
jede Auswahl zwischen nächsten Schritten, jede Bitte um Freigabe — als Auswahl mit Empfehlung zuerst,
nie als Frage im Fließtext am Ende einer Antwort.

CI runs on GitHub's preview label `xcode-27` with Xcode 27.0 pinned: every job uses the composite action
`.github/actions/select-xcode-27`, which selects `/Applications/Xcode_27.app` and stops the run if it
reports any other version. The deployment target stays at 27.0, nothing in `project.yml` is changed, and
UI Smoke and Speech Stress run only on an iPhone 17 simulator with iOS 27.0 (otherwise the step stops).
If the label goes away or is renamed, follow `docs/reference/testflight.md` and adjust `runs-on` in
`ci.yml`, `speech-stress.yml` and `testflight.yml`.
The job „Mac Gallery (macOS)“ photographs the Mac app (`MacGalleryTests`, start page, New, detail, light and dark) and
uploads the pictures `mac-gallery-*` as the artifact `MacGallery` (#511); Mac pictures come only from there, never from
Henning's Mac.

## Ship

`.github/workflows/testflight.yml` archives the iOS app with cloud-managed signing and uploads it to
TestFlight (manual run or a `v*` tag). Setup for the account owner: `docs/reference/testflight.md`.
Since #174 it runs on the `xcode-27` preview image with Xcode 27.0 pinned and never lowers the
deployment targets; a step before the upload checks every target in the archive (27 SDK, minimum 27.0,
version, dSYM, privacy strings) and stops the upload on any mismatch.

**Every TestFlight build says what to test (Henning, 2026-10-12, #347).** A manual run requires the
input `what_to_test`; a `v*` tag uses the tagged commit's message. After Apple reports the build as
`VALID`, `scripts/asc_what_to_test.py` writes the text into TestFlight's „Was testen“ (every existing
localization, `de-DE` created if missing). Write it for Henning, in German: which flow, which steps,
what he should see. The run fails without it.

**CloudKit schema through CI (#448, Henning 2026-10-15: „Bündeln + CI-Weg“).** The schema lives in
`cloudkit/schema.ckdb`; a model change adds its fields there in the same PR (`scripts/test_cloudkit_schema.py` fails
otherwise). On merge, `.github/workflows/cloudkit-schema.yml` imports the file into Development with `cktool` (secret
`CLOUDKIT_MANAGEMENT_TOKEN`); `export-production`/`export-development` read the live schema. Apple allows the step to
Production only in the CloudKit Console: Henning clicks „Deploy Schema Changes“ once, then the build starts. Bundle model
changes so he clicks rarely. `mac-schema-init` below is the fallback.

**CloudKit schema before every TestFlight build that changes the model (#175).** TestFlight talks to the
CloudKit environment Production, Xcode runs to Development. Production never creates a schema by itself, and
Development only knows fields some record wrote with a value. So after any change in `Shared/Models`, before
the build: `./scripts/sim.sh mac-schema-init` (signed Mac debug build of the main bundle id, starts with
`-LEInitializeCloudKitSchema`, writes the full schema into Development via `initializeCloudKitSchema`, never
opens the app-group store; `LOOSEENDS_REGISTER=1` on the first run), then Henning deploys in the CloudKit
Console. **Production is additive only from the first deploy:** new fields and types work, deleting or renaming
does not — plan model changes as additions. The TestFlight run starts with `schema-check`, which compares
`cloudkit/schema.ckdb` with `cktool export-schema --environment production` and stops before archiving if a type or
field is missing (own messages for a missing secret, an unreadable Production and missing names); no way around it
(#268). Steps and fallback: `docs/reference/testflight.md` (5a).

## Process

Plugin `henemm/agent-os-openspec`. Fast-track for scaffolding, standard workflow with the 250-LoC limit after that.
It lives in Henning's own marketplace, not the official one, so register that first:

```bash
claude plugin marketplace add henemm/agent-os-openspec@main
claude plugin install agent-os-openspec
```
Unit tests for enrichment, view rules, repeat rules and revisions come first; UI tests only after the design freeze, and only as smoke tests.

**GitHub Issues is the one and only backlog.** Every open task — feature, bug, spike — is a GitHub
issue with its own Definition of Done, not a bullet in a markdown file. **The priority order lives in
the milestones** (M1 Alltag stabil → M2 Siri und Orte → M3 Bereit für externe Tester → M4 Nach der ersten
Einladung; the order inside each is in the milestone description), not in a document.
**The GitHub Project "loose ends" (henemm, project 1) is the Kanban view of those issues** (Henning, 2026-10-12):
Status (Backlog → Ready → In progress → In review → Done), Priority (P0–P2) and Size (XS–XL) live there.
Priority follows the milestone (M1 = P0, M2 and M3 = P1, M4 = P2; without milestone by content). Claude keeps the board
current without being asked: a new issue goes onto the board with Priority and Size, In progress when work starts
(`/00-intake`), In review when the PR opens, Done on merge. Commands: `gh project item-edit` (field and option ids from
`gh project field-list 1 --owner henemm --format json`); the token needs the `project` scope. A cloud session cannot reach
the board directly; it dispatches `.github/workflows/board.yml` (`list`, `set`) and reads the result as an annotation
(`docs/reference/board.md`, #385).
Henning orders cards by dragging (view without sort): `gh project item-list` returns the manual order, top = most
relevant. Pick the next ticket by Priority first, then by that order; his drag beats the milestone order inside a
priority (2026-10-12: #355 moved to the top). Raw notes from him (no body yet) get Priority and Size at `/00-intake`.
`docs/project/04-stand.md`
is dissolved (2026-10-12): never recreate a status or priority file, and never resurrect a status column in
`docs/project/01-user-story.md` (it's a one-time snapshot from the briefing, not maintained). The first
invitation of external testers waits for everything in the user story, Siri schema and places included
(Henning, 2026-10-12). Opening a PR for an issue: reference it (`Closes #N`) so it auto-closes on
merge; if it doesn't auto-close, close it by hand. New work discovered mid-task becomes a new issue,
not scope creep on the current one.

## Where things live

- `Shared/Models` — SwiftData model, enums, `RepeatRule`, `ViewRules` (pure view computation)
- `Shared/Persistence` — `ModelContainerFactory` (app group + private CloudKit; identifiers read from
  `Info.plist`, keys `LEAppGroup`/`LECloudContainer`, with the production constants as fallback —
  device builds carry their own via `BUNDLE_ID_SUFFIX`, #156), `ContextSeeder`,
  `CloudKitSchemaInitializer` (Debug only: writes the full CloudKit schema into Development, never opens the app-group store, #175)
- `Shared/Services` — `CaptureService`, `FieldCodec` (one encoding per field), `RevisionService` (reset = user revision),
  `TaskActions` (done, next up, park, move, restore), `DateExpressionParser`/`TimeExpressionParser` (rule-based
  date/time extraction DE/EN, moved from `Measurement/` in #95), `RawTextWords` (the one tokenizer for word-set
  equality, shared with `Measurement/`, moved from `TitleCheck` in #136), `TitleRule` (the title at capture: raw text
  cleaned, first 12 words, #202), `SiriFields` (Siri's link, flag, tags onto a new task: `resolve` checks before
  saving, `apply` writes after; not in the product path until #25, #225), `SiriCapture` (Siri's reminder fields onto a
  new task in two steps: `prepare` (async, checks everything, writes nothing, geocoder injected) and `commit`
  (MainActor, writes with author `.user`, reason "Siri", F1 notes appended to the raw text, F2 unknown list creates the
  project via `CatalogService.project(named:in:)` by `nameKey`; on any error nothing is left behind); no Siri types in
  `Shared/Services`; not in the product path until #25 Schnitt 2), `WaitingOn` ("waiting on" set by hand:
  link, loosen, picker candidates without loops, a user revision per change, #251), `SharedAttachment` (a shared photo or
  file before saving: temp file, never `Data`; title from the file name, photo name, ≤ 50 MB and ≤ 10 per share;
  `CaptureService.save(attachments:)` reads each once, #399), `SharedAttachmentFile` (the share extension's file I/O: which
  registered type is an attachment, copy out of the provider's handler into a temp folder, over 50 MB not copied, remove the
  folder on Done and Cancel, #442). All pure over the model objects; the
  caller saves.
- `Shared/Enrichment` — `TaskEnricher` protocol (`StubEnricher` in the tests plays hang, empty answer, answer per note and
  refusal, #530), `ModelDeadline` (time limit per model call, 30 s in the coordinator; a timeout counts as a failed call, #530), `EnrichmentWriter` (threshold + revisions; never writes the model's contexts or project, #215/#469), `EnrichmentCoordinator`
  (catch-up pass), `FoundationModelsEnricher` (on-device model, `#if canImport(FoundationModels)`), `DueDateRule`
  (combines the rule parsers into the due date, confidence 1.0, #95), `ImportanceUrgencyRule` (keyword
  match for importance/urgency, confidence 1.0, no default on miss, #117), `RecognitionRule` (equality of
  `RawTextWords` sets contexts and duration from an earlier task, confidence 1.0, no energy, #136), `ContextWordRule`
  (a short word list per default context plus each context's own name sets the contexts; no hit stays empty, #232),
  `ProjectNameRule` (a project's own name in the note sets it; the model never does, its old guesses are released at start
  by `GuessedProjects`, #469)
- `Shared/Intents` — App Intents shared by app, widgets and (later) the intents extension
- `LooseEnds/Intents` — app target only (iOS/macOS 27, never watch, widget or share, no `project.yml` entry): `ReminderSchema`
  (Apple's reminders schema entities, read-only: `ListEntity` = project plus the virtual inbox „Loose Ends“, `ReminderEntity`
  from `TaskItem`, `LocationTriggerEntity` and `SectionEntity` with empty queries) and `ReminderTranslation` (Siri's SDK
  types onto `SiriCapture.Input`: incomplete date dropped without error, coordinate before address); no intent yet (#25 Schnitt 2a)
- `LooseEnds/` — app entry and views (iPhone, iPad, Mac); `LooseEndsWatch/`, `LooseEndsWidgets/`, `LooseEndsShare/`
  (iOS share sheet: text, links, mails via `SharedContent`) — platform targets
- `LooseEndsWatchWidgets/` — watch complication (#355 Schnitt 3a): the logo's knot, families `accessoryCircular` and
  `accessoryCorner`, static (one entry, `.never`), no entitlements and no `Shared/`; it compiles `LooseEnds/Views/Thread.swift`
  as a single file, so that file must stay watchOS-safe (SwiftUI only). A tap opens the watch app's capture.
- `LooseEnds/Mac` — `MenuBarCapture` (Mac only, #356): the menu bar panel with the same `CaptureView`, Dock icon only
  while a list window is open (`DockPolicy`), login item via `SMAppService` (on from the first start, never under tests);
  `MenuBarThreadImage` (#366): the menu bar symbol is the logo's thread, drawn from `ThreadShape.curvePoints` into a
  template `NSImage` (18 pt, 1x/2x, black on transparent; the raster in `MenuBarThreadRaster` is platform-neutral and unit-tested)
- `LooseEnds/App/LaunchTimings.swift` — cold-start measuring points (#22): signposts always, `Documents/launch-timings.json`
  only in the probe build (`.probe`); launch argument `-measureLaunch` opens the capture scene
- `LooseEnds/Speech` — `SpeechCapture` (live recognition for the capture scene, skipped under `--ui-testing`; the transcriber
  is built only in `makeTranscriber` with `.volatileResults` and `.fastResults` — without the latter the first word takes
  ~12 s instead of ~1 s, #274), `Waveform` (level in dBFS, scale −55…−25 → 0…1, mic ring grows up to 35 % from 52 pt, #279),
  `ListeningHint` (pure rule: "Listening …" while the mic listens and the field is empty, #297),
  `SpeechDiagnosis` (pure rule: 6 s after the first audible level (`audibleLevel` 0.1; silence never triggers) without any
  result the capture shows a grey line with model status, permissions, buffer and result counts, #274/#402; the start-time
  report only in the probe build; on the Mac one calm line „Sound arrives, but no text recognized“ with the values in `.help`;
  `--ui-testing-speech-diagnosis` fixes that state for the UI smoke test)
- `Shared/Notifications` — `DueReminders` (pure plan and action handling); `PlaceReminders` (which ≤ 20 places
  to watch, #226) and `PlaceDelivery` (what to hand to the system, replace or withdraw, from a per-device
  handover list; the system never reports delivery, #226 Schnitt 2a); `PlaceNotifications` (#240 Schnitt 1, pure
  building blocks: categories with both button rows, authorization decision, ask once only with a place
  and in the foreground, answer sets the mark, `place_` / `due_` prefixes apart, re-entry lock); `LooseEnds/Notifications` —
  `DueNotificationCenter` (system wiring, silent under tests; completion-handler delegate methods, not async, #295; the
  only notification delegate and the only `setNotificationCategories` call; routes `place_` answers by prefix;
  `reschedule()` runs the place reconcile after the due pass; the UI test gets its banner via
  `LOOSEENDS_PUSH=<file.apns> ./scripts/sim.sh test-proof <class>`), `PlaceNotificationCenter` (iOS/iPadOS only, #240
  Schnitt 2: `UNLocationNotificationTrigger` with a 150 m region, permission „When in use“ only, never `CLMonitor` or
  „Always“; reconcile removes first, adds, then writes the handover list, errors are logged and never thrown; the
  simulator cannot fire the real trigger and rejects `add` with 2003, so arrival is proven on the device only)
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
