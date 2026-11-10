# CLAUDE.md — Loose Ends

Say it, it's sorted. Task capture with on-device Apple Intelligence for iPhone, iPad, Mac and Watch.

## Rollen und Zusammenarbeit (PO-Vorgabe 2026-11-08, gilt für jede Sitzung, auch Cloud)

- **Henning ist Product Owner, kein Programmierer**; er schaut nie in Git, PRs oder CI. Antworten an ihn: einfache Sprache, Ergebnis statt Mechanik, Fachbegriffe kurz übersetzt.
- **Claude ist Tech Lead** und entscheidet technisch selbst, nach etablierter Praxis, den Specs, ADRs und früher getroffenen Entscheidungen (Issues, Doku) dieses Repos. Keine Abkürzungen, keine ungetesteten Experimente am Live-System; nur bei echten Produkt-Zielkonflikten Optionen mit begründeter Empfehlung vorlegen.
- **Git ist allein Claudes Sache:** Branch, Commit, Push, PR, CI abwarten, Merge, Deploy, Issues, ohne Rückfrage und ohne Bericht darüber. Das hebt die Standardvorsicht („Commit/Push nur auf Nachfrage") und jede Vorlage „Merge bleibt beim PO" für dieses Repo ausdrücklich auf. Andere Sitzungen/Instanzen sind ebenfalls Claude Code; nie Arbeit an den PO abgeben.
- **Den PO fragen nur zu Produktentscheidungen** (Freigabe von Anforderungen, fachliche Zielkonflikte), per `AskUserQuestion`, nie als Freitext. Tooling, Git, Hooks, Server-Mechanik klärt Claude selbst.
- **Aufgaben nur als GitHub-Issues** in diesem Repo; ein Issue erst schließen, wenn es end-to-end erledigt ist.
- **Form der Antworten an den Product Owner** (jede Antwort, auch nach langer Arbeit): Das Ergebnis steht zuerst, in ein bis zwei Sätzen, danach nur, was er entscheiden oder tun muss. Keine Dateinamen, Commit- oder PR-Nummern, Testzahlen, Werkzeug- oder Funktionsnamen, außer er fragt danach. Was nicht geklappt hat, in einem Satz mit dem nächsten Schritt. Kurze Absätze, keine langen Listen und Tabellen; Fachwörter, die sich nicht vermeiden lassen, in einem Halbsatz erklären. Technische Einzelheiten gehören in das Issue oder den Pull Request, nicht in den Chat.

## Feste Arbeitsregeln (Kurzfassung, Begründungen in `docs/reference/zusammenarbeit.md`)

- **Henning bekommt nie einen Befehl zum Eintippen** und kein Git-Vokabular, auch keine Klickwege für Einstellungen;
  blockiert ein Hook oder eine Berechtigung, repariert Claude den Mechanismus. Er bekommt nur, was sich am Produkt geändert
  hat und ob er etwas entscheiden oder auf dem Gerät ausprobieren soll.
- **Keine manuellen Tests für Henning.** Nie „bitte testen“ oder „was hast du gesehen?“ als Ersatz für eigene Prüfung;
  die einzige Ausnahme ist Stufe 3 über TestFlight (unten). Belege (Screenshots) werden geöffnet und beschrieben, bevor
  ein Haken gesetzt wird; jeder übersprungene Test wird einzeln benannt.
- **Fragen an Henning:** zuerst ein zusammenhängender Kontextblock in Alltagssprache (worum es geht, was sich sichtbar
  ändert, Befund, was er entscheidet), dann `AskUserQuestion` mit Empfehlung zuerst. Seine direkte Frage wird zuerst
  direkt beantwortet. Auf „status?“ beginnt die Antwort mit „Du musst nichts tun“ oder „Du bist dran: …“. Seine
  ausdrückliche Bestätigung gilt und wird nicht aus Akten angezweifelt.
- **Fehler:** zuerst im Internet recherchieren (wörtliche Meldung, API-Stand der Zielversion, Quellen nennen), dann
  fragen oder aus Ticket und Verlauf beantworten „Hat es bisher funktioniert, seit welchem Stand?“, dann auf dem Weg
  nachstellen, den Henning nimmt, erst dann die Ursache benennen. Sein Symptom wird wörtlich genommen.
- **Vor jedem Ticket zuerst lesen, was in Bearbeitung ist** (Board „In progress“/„In review“, offene PRs,
  `gh pr list --search "#N" --state all`): parallele Sitzungen arbeiten im selben Repo.
- **Einstieg immer über `/00-intake #N`** (`/00-bug` gibt es nicht mehr); jede Phase über ihren Slash-Befehl, Gates
  nie von Hand öffnen. Reine Store-Bild- und Werkzeugarbeit ohne Produktcode läuft ohne Workflow.
- **Entwurf vor Spec bei sichtbaren UI-Änderungen:** veröffentlichte Vorschau „Heute“ neben „Entwurf“ in den echten
  App-Farben, Hell und Dunkel, mit mindestens einer grafisch eigenständigen Alternative, abgelegt unter
  `docs/artifacts/<workflow>/`; erst nach Hennings Freigabe die Spec.
- **In Alternativen denken:** jede Analyse nennt mindestens eine echte Alternative samt der ADR, die dafür fiele.
- **Umfang:** je Schnitt höchstens 4–5 Dateien und ±250 LoC (`openspec.yaml`); zeichnet sich mehr ab, vor dem Bauen
  teilen oder per `AskUserQuestion` annehmen lassen. Folgearbeit nach Ziel bündeln, ein Issue je Ziel.
  Sagt Henning, etwas soll nicht mehr kommen, wird das Issue sofort als „not planned“ geschlossen.
- **Henning merkt sich keine Termine:** wartet ein Nachweis auf später, wird der Auslöser vorgezogen oder der offene
  Schritt mit Datum im Issue festgehalten und von Claude selbst nachgeholt.
- **Präferenzen landen im Repo:** äußert Henning eine dauerhafte Vorgabe, steht sie in derselben Antwort hier oder in
  der Doku, nicht nur im lokalen Gedächtnis (Cloud-Sitzungen sehen nur das Repo).

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
- **One number, everywhere** (Henning, 2026-10-23, #637). The number on the app icon is the number over "Now" and on "Start",
  the same on iPhone, iPad and Mac, and nobody has to add. One source (`ViewRules.now`), no place computes it again; a test
  holds the icon number equal to the rows of "Now".
- **Color budget.** Accent = tappable (incl. AI tint), red = time pressure, grey = hierarchy, green = the completion moment.
- **The app never proposes the Knäuel or a bead** (Henning, 2026-10-26, #648 dropped): no row, no preselected menu
  entry, no notification suggests a task as the Knäuel or as a bead. Both are set by the user alone.
- **SF Symbols only** (Henning, 2026-10-12, #350). Every sign in the app is an SF Symbol, outline where one exists:
  no emoji, no characters standing in for a symbol (»«, →), no own images. The one exception is the logo's thread
  (knot, loose thread, #180): it is the brand mark, not a control. Since #642 (Henning, 2026-10-23) its family holds two
  more drawn signs: the Knäuel (English UI: “the Tangle”, #758; `ThreadShape.Form.knaeuel`, the one avoided task, #643) and the bead (`PearlGlyph`, a
  task that counts on the week's string, #645); every other sign stays an SF Symbol.
- **Rules before the model** (Henning, 2026-09-20). Every derived field is first attempted with rules,
  regex, calendar, contacts or a word list. The on-device model only gets what needs language
  understanding (refining the title: since #202 `TitleRule` sets it at capture from the cleaned raw
  text, at most 12 words — 312 of 319 raw sentences have ≤ 12 words; the model may refine it). Every analysis and spec that proposes the model for a field must contain
  the line "Without the model this fails because …" with evidence from a measurement; without that line
  the rule path is the proposal. Every measurement report carries the rule-based column as baseline; if
  the rules beat the model, the rules win, and an existing ADR or schema is not a counter-argument.
  Measured 2026-09-20: model 50 % exact dates, 96.5 % invented; `NSDataDetector` 65–68 % depending on the weekday of the run (it takes no reference day, so its column is frozen, #148), 0 % (#67, #92);
  own rule parser 99.3 %, 0 % (#92, Schnitt 1). Since #95 the rule parser sets the due date in the
  product path; the model schema lost the four due-date fields. A subtask gets the due date and context word rules
  at add and on "Analyze again", never the model (#565).
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
./scripts/sim.sh store-screenshots    # App-Store-Bilder iPhone 17 + iPad Pro 13″, de, hell, 9:41, nach docs/store/screenshots/de/ samt manifest.json (#742); Watch-/Mac-Einträge und README bleiben stehen
LOOSEENDS_UI_LANG=en ./scripts/sim.sh store-screenshots  # dasselbe englisch nach docs/store/screenshots/en/ (en-US), nur de|en, Belege store-proof-<lang>-<gerät>.txt (#842)
./scripts/sim.sh store-watch          # App-Store-Bilder Apple Watch 416×496 nach docs/store/screenshots/de/watch/, Beispielaufgaben nur unter --ui-testing-store-sample (#742)
LOOSEENDS_UI_LANG=en ./scripts/sim.sh store-watch  # dasselbe englisch nach docs/store/screenshots/en/watch/, nur de|en, Beispieltexte per --ui-testing-store-sample-texts, Systemsprache des Watch-Simulators danach zurück (#842)
gh workflow run store-mac.yml -f language=en  # App-Store-Bilder Mac 1280×800 nur in der CI (Artefakt StoreMac-<Sprache>, Standard de); Übernahme mit python3 scripts/store_screenshots.py --mac docs/store/screenshots/<lang> <export> (#842)
gh workflow run asc-store-images.yml -f aktion=lesen -f sprache=en [-f plattform=ios|mac]  # Store-Bilder einer Sprache in Apples Asset-Bibliothek: `lesen` (nur GET, mit den Platzierungen je Gruppe) oder `hochladen` (Namen `<sprache>-<gerät>-<datei>`, vorhandene übersprungen, auch wenn platziert), Mac nur mit bearbeitbarer Mac-Version (#842 S4c-1); `platzieren` (nur `en`) setzt sie auf die bearbeitbare iOS-Version (`plattform=mac`: die vier Mac-Bilder auf die bearbeitbare Mac-Version, en-US, Gruppe `MAC_PROFILE`-Typ, iOS-Lauf lässt sie unberührt, #842 S5b), en-US, in Manifest-Reihenfolge, Vorhandenes übersprungen, Fremdes bricht vor jedem Schreiben ab, Gegenprobe im selben Lauf, de-DE nur gelesen; nie einreichen oder löschen (#842 S4c-2)
gh workflow run asc-store-version.yml -f aktion=lesen  # App-Store-Versionen je Plattform: `lesen` (nur GET: Zustand, Bau, Zeichenzahlen je Feld, Bildsätze, Review-Detail) oder `anlegen` (Mac-Version mit der Nummer der bearbeitbaren iOS-Version, nur wenn keine bearbeitbare Mac-Version existiert; ordnet je Plattform den gültigen Bau der Zielversion mit der höchsten Nummer zu, einen vorhandenen nie um; einen mit der Konto-Marke gekennzeichneten oder unlesbaren Bau nie (#615 S4c-2a); Gegenprobe im selben Lauf); nie einreichen, löschen oder Texte/Bilder schreiben (#842 S5a-1)
gh workflow run asc-store-submit.yml -f aktion=pruefen  # Vorprüfung vor dem Einreichen, nur GET, beide Plattformen (IOS, MAC_OS): genau eine bearbeitbare Version gleicher Nummer, Bau gültig und passend, Texte de-DE/en-US, Bilder je Locale, Review-Detail, keine belegende Einreichung; je Plattform `bereit` oder alle Gründe, Ausgang 0 nur wenn beide bereit; `-f aktion=einreichen -f bestaetigung=1.0.1` reicht ein: die Versionsnummer der Zielversion ist die Bestätigung (Skript und Workflow prüfen sie), erst Plan beider Plattformen nur mit GET (ein Grund hält beide an), dann je Plattform iOS zuerst Einreichung anlegen oder die eine `READY_FOR_REVIEW` wiederverwenden, Version als Item (fremdes Item bricht ab), abschicken; jeder Schreibaufruf genau einmal, nie wiederholt; eine schon eingereichte Plattform wird übersprungen; Gegenprobe `WAITING_FOR_REVIEW` im selben Lauf; nie löschen oder stornieren (#893)
./scripts/sim.sh watch-test <Klasse>  # Watch-UI-Test im watchOS-Simulator ohne Beleg (Bilder, Sichtprüfung)
LOOSEENDS_LANG=en ./scripts/sim.sh sim-unit <Klasse>  # Testsprache en (-testLanguage/-testRegion), Simulator bleibt wie er ist (#670)
./scripts/sim.sh launch-measure <n>   # Kaltstart-Messung, n Starts auf dem Gerät (#22)
./scripts/sim.sh real-model            # echtes On-Device-Modell auf diesem Mac, nur lokal (#531)
./scripts/sim.sh real-model-latency <n> # Latenz kalt/warm, n Prozesse auf dem Mac, Rohdaten + Auswertung (#534, docs/reference/modell-latenz.md)
./scripts/sim.sh real-model-guardrail   # Verweigerungsrate auf dem Mac, 2 Durchläufe je Text, Rohdaten nach docs/artifacts/71-guardrails/ (#71)
./scripts/sim.sh lab-latency <n>       # dasselbe auf dem iPhone über die Labor-App (#534 Schnitt 2); nur nach Hennings „jetzt ist ein Test möglich“
./scripts/sim.sh lab-guardrail [--dry-run] # Guardrail-Rate auf dem iPhone (#71 Schnitt 2b-2): Korpus bauen, Scheiben fahren, Bericht; --dry-run baut nur den Korpus und rührt kein Gerät an; Lauf nur nach „jetzt ist ein Test möglich“
```

The server (`server/`, #613) has its own chain, no Xcode: `./server/scripts/test-local.sh` starts a throwaway Postgres 18
(temp data folder, free port, TCP only), runs `npm run typecheck` and `npm test` in `server/` against it and always cleans up;
with a `DATABASE_URL` set, both run directly in `server/`.

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
wegziehen. Wer zuerst wartet, bekommt die Sperre zuerst: jeder Wartende stellt eine Marke `<Zeit_ns>-<pid>` in die
Warteliste `<Sperre>.queue`, nur der Kopf greift zu, tote Marken fallen heraus, Handskripte ohne Liste können
vordrängeln, ohne etwas zu verklemmen (#516). Schreibt `xcodebuild` 15 min nichts ins Log (`LOOSEENDS_SILENCE_MAX`, Sekunden), beendet ein Wächter nur den
Lauf dieser Sitzung und meldet „hängt seit N min, abgebrochen“ samt letzter Logzeile; die Sperre wird frei,
CoreSimulatorService startet er nicht neu (#516). `boot` und der CI-Job `ui-smoke` rufen `scripts/sim_prepare.sh` auf (#578): es markiert den Tastatur-Hinweis „Speed up your typing…“ als gezeigt
(auf einem frischen Simulator hängt er sonst jede UI-Abfrage nach dem ersten `typeText` auf) und erteilt der App den Kalenderzugriff vorab
per `simctl privacy grant`. Der Kalender-Systemdialog wird in der CI nicht mehr durchgespielt; die 3-s-Suche im Test bleibt als Rückfall.
DerivedData liegt je Worktree unter `LooseEnds-session-<Ordnername>` (`CLAUDE_SESSION_ID` überschreibt den
Schlüssel). Die Handabsprache per Sperrdatei zwischen Sitzungen entfällt.

Das Projekt ist generiert und nicht versioniert: Nach jedem neuen Stand muss `generate` laufen,
sonst kennt Xcode die neu hinzugekommenen Dateien nicht und baut eine App ohne die neuen Views.

Berechtigungen gehören in `project.yml` (`entitlements.properties`), nie nur in die erzeugte `.entitlements`-Datei:
`generate` überschreibt sie (#311). `scripts/test_entitlements_sync.py` und die Archivprüfung `entitled` sichern das ab
(`docs/reference/testflight.md`). Dasselbe gilt für jede `Info.plist`: Quelle ist `info.properties` in `project.yml`, die Datei im Repo
nur das Abbild (#499); `scripts/test_info_plist_sync.py` vergleicht beide, und der CI-Schritt „Generate leaves the tree clean“
schlägt fehl, wenn `generate` einen Diff hinterlässt. Berechtigungstexte brauchen zusätzlich einen deutschen Eintrag in
`LooseEnds/Resources/de.lproj/InfoPlist.strings` (App und Watch bündeln dieselbe Datei), sonst zeigt ein deutsches Gerät den
Dialog englisch; `scripts/test_catalog_languages.py` prüft das für jede Sprache aus `LanguagePacks.shipped` und die Vollständigkeit der fünf `*.xcstrings` (#342, #756).
Der Datenschutztext liegt in `docs/reference/datenschutz-entwurf.md` (Freigabe Henning); öffentlich steht er seit 2026-10-27
unter https://www.henemm.com/legal/loose-ends/privacy-policy/ (Website-Repo `henemm/henemm-website`, `content/legal/loose-ends/`),
bei Apple gesetzt über die Repo-Variable `ASC_PRIVACY_POLICY_URL` (en-US: Konstante `PRIVACY_URL_EN` im Skript, englische Seite `…/privacy-policy-en/`, #763) und `asc-beta.yml` `aktion=einrichten` (#705; `aktion=einreichen` reicht zum Beta-Review ein, nur nach Hennings Wort). Eine Änderung
am Text gilt erst, wenn auch die Website-Seite angepasst ist.

`DEVELOPMENT_TEAM` steht in `project.yml` (`XK87E2B3VR`) und darf dort nicht geleert werden: Xcode
legt das Team in der erzeugten Projektdatei ab, die bei jedem `generate` neu geschrieben wird — ein
leerer Wert heißt, dass Xcode nach dem nächsten Stand jeden Gerätestart verweigert.

**Acceptance runs in stages, and the first two are never skipped** — tests, then Simulator
(`./scripts/sim.sh build`, `launch`, `screenshot`: the changed flow is played through and evidenced).
Compiling is not building, building is not installing, installing is not **using**: only using is the stage, and
`phase8_complete` demands its receipt from `./scripts/sim.sh test-proof` (#145).
`docs/reference/abnahme-und-arbeitsweise.md` has the reasoning and the commands. TestFlight gives no debugger and no
live logs, so it never replaces stages 1 and 2; since #279 it is the channel for stage 3 (below).

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

Ausnahme (Henning, 2026-10-30, #758): Änderungen in `LooseEndsWidgets/`, die nur Katalogschlüssel oder Textliterale betreffen (kein Layout, keine Logik, keine Intents, keine `Info.plist`), enden nach Stufe 2. Beleg: Katalogwächter grün und Screenshot der Widget-Galerie im Simulator.
Ausnahme (Henning, 2026-10-25, #680): Ändert ein Schnitt in `EnrichmentCoordinator.swift` nur den Regelzweig (Wortliste, Kalender, Kontakte, Orte) und nicht den Modellaufruf, endet die Abnahme nach Stufe 2; der Bericht sagt „Regelzweig, kein Modellaufruf, im Simulator belegt“.

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
dann bekommt Henning in einfachen Worten, was er ausprobieren soll und was er sehen muss (welcher Bau gemeint ist,
steht in TestFlights „Was testen“) — keine Befehlszeile, keine Buildnummer im Chat, außer er fragt danach. Seine Rückmeldung schließt die Gerätepunkte ab; bis dahin bleibt das Ticket offen (PR mit
`Refs #N` statt `Closes #N`). Die Gerätepunkte stehen in der Definition of Done, nie als AC der Spec (das QA-Gate
kennt keinen Aufschub). Alles ist fertig gebaut, bevor Henning gerufen wird; er wartet nie auf Claude.

„LE Prüfbau“ neben seiner Installation (`./scripts/sim.sh device` fürs iPhone, `./scripts/sim.sh mac` für den Mac
nach `~/Applications`, nie seine normale App, beim ersten Mac-Lauf mit `LOOSEENDS_REGISTER=1`, #287) startet Claude
nur selbst, nur nach seinem „jetzt ist ein Test möglich“ und nur auf seinem Rechner. Die Labor-App
(`./scripts/sim.sh lab`) ist nur für Messungen gegen Apple Intelligence, nicht für den Test eines Tickets; nie eine
App auf seinem iPhone fernstarten. Eine Cloud-Session erreicht seinen Mac und sein iPhone nicht; das sagt sie, statt
Schritte zu verteilen. Greift Stufe 3 nicht, bekommt Henning nur den Satz „Kein Pfad der Geräteliste berührt.“

**⛔ Ausliefern ist Teil jedes Tickets.** Gearbeitet wird in einem eigenen Zweig (Worktree), ausgeliefert per PR,
grüner CI und Merge — durch Claude, ohne Rückfrage. Hennings Hauptcheckout auf seinem Mac hält ein SessionStart-Hook
aktuell (`main` nachziehen, Projekt neu erzeugen; `docs/reference/abnahme-und-arbeitsweise.md`) — ohne ihn lief bei
Henning der Stand von vorher (2026-09-19: eine App ohne Erfassungs-Button, weil die erzeugte Projektdatei 70 neue
Dateien nicht kannte).

**Workflow-Freigaben tippt Henning** (`go`, `approved`, …, `openspec.yaml`): der Hook des Plugins sieht nur getippte
Nachrichten, keine `AskUserQuestion`-Antwort. Claude nennt dann genau das Wort und genau einen Slash-Befehl, den
Pflicht-Schritt des aktiven Workflows; die Entscheidung dahinter kommt zusätzlich als Auswahl, wenn sie eine echte
Wahl ist.

CI runs on GitHub's preview label `xcode-27` with Xcode 27.0 pinned: every job uses the composite action
`.github/actions/select-xcode-27`, which selects `/Applications/Xcode_27.app` and stops the run if it
reports any other version. The deployment target stays at 27.0, nothing in `project.yml` is changed, and
UI Smoke and Speech Stress run only on an iPhone 17 simulator with iOS 27.0 (otherwise the step stops).
The job `ui-smoke-lang` runs `InboxDrawerSmokeTests` and `StartNumberTests` once per shipped language (matrix from `LanguagePacks.shipped`, `LOOSEENDS_UI_LANG`, `LooseEndsUITests/LaunchLanguage.swift`, #761).
If the label goes away or is renamed, follow `docs/reference/testflight.md` and adjust `runs-on` in
`ci.yml`, `speech-stress.yml` and `testflight.yml`.
The job „Mac Gallery (macOS)“ photographs the Mac app (`MacGalleryTests`, start page, New, detail, light and dark) and
uploads the pictures `mac-gallery-*` as the artifact `MacGallery` (#511); Mac pictures come only from there, never from
Henning's Mac. The same job runs `MacDetailClickTests` (#544) in the **App Sandbox of the real app**: it builds, re-signs the
app with the sandbox keys of `project.yml` (`scripts/mac_ci_entitlements.py`, minus what needs a profile) and tests without
rebuilding. Each test starts fresh, opens the detail from Loose ends or the start page and clicks the visible words: title,
note, subtask add and check, File and Photo. Without the sandbox the open panel opened in CI and not in TestFlight build 89.
The helpers both share live in `MacUITestSupport.swift` (`mac` prefix). Every fetch of the main window there runs
`macAssertWindowFitsScreen` (#593): a window wider than the screen, or past its right or bottom edge, fails the test with
both sizes; the gallery notes `mac-gallery-*-window-size` name window and screen size, and `testWindowFromMenuBarFitsScreen`
opens the window through the menu bar on every run.

## Ship

`.github/workflows/testflight.yml` archives the iOS app with cloud-managed signing and uploads it to
TestFlight (manual run or a `v*` tag). Setup for the account owner: `docs/reference/testflight.md`.
Since #174 it runs on the `xcode-27` preview image with Xcode 27.0 pinned and never lowers the
deployment targets; a step before the upload checks every target in the archive (27 SDK, minimum 27.0,
version, dSYM, privacy strings) and stops the upload on any mismatch.
The input `konto` (off by default, never on a tag) switches the account group on in the archive (`LEAccountEnabled`, proven as Bool with `applesignin` in both archive checks), marks the build in „Was testen“, and `scripts/asc_store_version.py` never assigns a marked or unreadable build to a store version (#615 S4c-2a).

**Every TestFlight build says what to test (Henning, 2026-10-12, #347).** A manual run requires the
input `what_to_test`; a `v*` tag uses the tagged commit's message. After Apple reports the build as
`VALID`, `scripts/asc_what_to_test.py` writes the text into TestFlight's „Was testen“ (every existing
localization, plus one for every shipped language that has none). Write it for Henning, in German: which flow, which steps,
what he should see. The run fails without it. Since #760 the text may carry one section per shipped language: lines starting `de:` or `en:` open one;
text without a marker is German, and a language without a section gets the German text. The beta description in `docs/reference/beta-beschreibung.md`
has one `## de-DE` / `## en-US` section per language, and `scripts/asc_locales.py` maps each language code of `LanguagePacks.shipped` to its App Store Connect locale.

**CloudKit schema through CI (#448, Henning 2026-10-15: „Bündeln + CI-Weg“).** The schema lives in
`cloudkit/schema.ckdb`; a model change adds its fields there in the same PR (`scripts/test_cloudkit_schema.py` fails
otherwise). On merge, `.github/workflows/cloudkit-schema.yml` imports the file into Development with `cktool` (secret
`CLOUDKIT_MANAGEMENT_TOKEN`); `export-production`/`export-development` read the live schema. Apple allows the step to
Production only in the CloudKit Console behind Henning's Apple sign-in: Claude opens the page in his browser, Henning
only signs in (passkey), Claude checks the diff (additions only) and deploys, then the build starts. Bundle model
changes so he is needed rarely. `mac-schema-init` below is the fallback.

**CloudKit schema before every TestFlight build that changes the model (#175).** TestFlight talks to the
CloudKit environment Production, Xcode runs to Development. Production never creates a schema by itself, and
Development only knows fields some record wrote with a value. So after any change in `Shared/Models`, before
the build: `./scripts/sim.sh mac-schema-init` (signed Mac debug build of the main bundle id, starts with
`-LEInitializeCloudKitSchema`, writes the full schema into Development via `initializeCloudKitSchema`, never
opens the app-group store; `LOOSEENDS_REGISTER=1` on the first run), then the deploy in the CloudKit Console
as above. **Production is additive only from the first deploy:** new fields and types work, deleting or renaming
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
the milestones** (M1 Alltag stabil → M2 Orte und Mail-Rücksprung → M3 Bereit für externe Tester → M4 Nach der
ersten Einladung; the order inside each is in the milestone description), not in a document. M2 was „Siri und Orte“
until 2026-10-19: after #25 (Siri via the Reminders schema) was rolled back on 2026-10-17, the Siri epic #369 moved
to M4 and Siri stays on the App Shortcut „Aufgabe erfassen“.
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
**One session, one Epic** (2026-10-26/27, #715): the herdr session name is the Epic. The Epic is the topmost parent of the leading `#N`
(`#N` itself if it has no parent but sub-issues). `scripts/next-ticket.sh` proposes the next free lowest-level sub-issue of that Epic: it skips In
progress/In review, an open PR (`Closes/Fixes/Refs #N` or branch name), a live session lock (phase below `phase8_complete`)
and an open "blocked by"; order is Priority, then board order; it reports hotspot overlap (`project.yml`, schema,
`*.xcstrings`, `CLAUDE.md`, start page) with open PRs and live branches. Its first line is `NEXT=#N`, `NEXT=none` or
`NEXT=unknown`; it reads only and never writes to GitHub.
`docs/project/04-stand.md`
is dissolved (2026-10-12): never recreate a status or priority file, and never resurrect a status column in
`docs/project/01-user-story.md` (it's a one-time snapshot from the briefing, not maintained). The first
invitation of external testers waits for everything in the user story, places included
(Henning, 2026-10-12; the Siri schema left that list with #369 → M4, 2026-10-19). Opening a PR for an issue: reference it (`Closes #N`) so it auto-closes on
merge; if it doesn't auto-close, close it by hand. New work discovered mid-task becomes a new issue,
not scope creep on the current one.

## Where things live

- `Shared/Models` — SwiftData model, enums, `InboxDrawer` (#601: the writing line under "New"; pure: `didCapture` opens and
  orders, `close` ends the sitting, `rows(in:)` this sitting's open tasks; the view `LooseEnds/Views/InboxDrawerView.swift`
  is one row of both start lists: "New" in accent in the margin with "N to look over" beside it at row-title size (#693, variant B;
  no tinted head, #677), this sitting's rows between that head and the line, the question always shown in italics, soft 0.4 s motion, no spring; on folding the rows slide up into the head and the sentence lights up once, not under reduced motion), `RepeatRule` (its `anchor` holds the rhythm, a moved round does not shift it, #552),
  `ViewRules` (pure view computation), `NewDateRule` (a deadline that passed is no deadline, #548: with a time after the
  time, without one after the day; the evening look reads a day-only date as passed after the reminder time; the trace
  "was 15:00" under the "New date" button), `DetailFields` (#538: what a task offers, five groups in one order, a section
  only with content, one word line for everything empty, dependent fields wait, off is not offered but never hidden;
  `DetailFieldSettings` with the standard on Note, Attachments, Calendar, Duration, Tags; the app's `FieldSettingsStore` in
  `LooseEnds/App` keeps the choice in defaults and the iCloud key-value store, everything on under UI tests)
- `Shared/Models` — the drive fields (#642; the Knäuel is “the Tangle” in the English UI, German keeps “das Knäuel”, #758): `TaskItem.knaeuelAt` (#643, the one avoided task, `isKnaeuel` while open) and
  `countsAt` (#645, a bead once completed, no limit on how many open tasks carry one (#818); the Knäuel always `counts`), both set by
  hand only as user revisions (`RevisedField.knaeuel`/`.counts`), both `DetailField`s of the group `drive`, off by default.
  `ViewRules.knaeuel(in:)` (latest mark wins), `week(containing:)` (Monday to Sunday, whatever the locale),
  `weekBeads(in:)` (every completion of a counting task in the week, a repeating one per record), `currentString(in:)` (the start
  page's string of `length` beads (#824: `FieldSettingsStore.stringLength`, "Beads per string" in Settings › Fields, 3 to 20 = `ViewRules.stringLengths`, 5 until set, defaults plus iCloud key-value store; `stringLength` = 5 is the standard), #655/#825: the first `length` beads after `since` (the moment of the last confirmation, nil = never);
  full = the win, it stands until the user confirms (`BeadString.confirmed` = a string was confirmed before); `recentBeads(in:limit:)` the last n beads), `weekToSpeakOf(in:)` (the
  Sunday sentence's beads: this week's from Sunday 16:00, last week's on Monday until the first new bead, #646) and
  `groupedByCompletionWeek` ("Completed" by weeks with each week's beads, the days inside); "Now" leads with the Knäuel (#703, Henning 2026-10-26: it always counts, with or without a date; `NowTasks.knaeuel`, never in
  `all`, `count` = rows + Knäuel = `nowCount`). Views: `LooseEnds/Views/Knaeuel.swift` (`StartHeaderRows`: the date in the margin (`StartDateMargin`, the knot over it
  while no task is the Knäuel) beside the sentence of the day; the Knäuel's row `KnaeuelHead` (the Knäuel in the margin
  beside the title, plays the completion moment, #644; draft C3, #677) stands first under "Now", built and kept for its moment by `NowBlock` in `StartZones.swift`; `KnaeuelSince`),
  `KnaeuelThread.swift` (`KnaeuelThread`: two trochoid loops from the Knäuel's tail end, no longer drawn since #677, `LooseningKnaeuel`:
  the Knäuel blended into the knot) and `Beads.swift` (`PearlGlyph`, `WeekString` with the sag and the 1.1 s green,
  `WeekStringRows` at the end of the start page without a caption (#677; iPhone under the contents): the string of five with its empty places as dots, `RewardLine` "For the beads: …" while it
  fills, `FullStringLine` "The string is full. For the beads: …" once it is, with the button "Begin a new string" (#825): a full string stands until it is tapped; beads completed meanwhile do not count into the next one; the moment is `FieldSettingsStore.stringSince`, defaults plus iCloud key-value store, no model field; #647/#655). The user-facing word for `countsAt` is "Perle sammeln" (#655), never "Zählt". The
  question before the Knäuel moves is `movesKnaeuel` in `TaskInteractions.swift`; the detail's lines under the raw text
  ("The Knäuel · since Monday" with Release, "Counts always, it is the Knäuel") are `TaskDetailView.driveSection`. The menu
  entries are actions (#667): "Make it the Knäuel" / "No longer the Knäuel" (SF Symbol `scribble.variable`), "Attach a bead" /
  "Take the bead off", the same words under the raw text in the detail. **One menu for list and detail** (#667): the detail's "…" renders `TaskInteractions.menu` (Complete, Next up, Knäuel,
  bead, Move, Park, Analyze again, Divider, Delete); `didComplete` and `didDelete` leave the detail, `analyze` is the
  detail's own run with its note or `TaskInteractions.listAnalysis` from a list; `onDeleted` on `TaskDetailView` lets
  `ContentView` drop its selection.
- `Shared/Models/RowKeyAction.swift` (#480 Schnitt 1, pure): which key does what in a Mac list (arrows choose, space completes only where the swipe offers done, delete asks first, nothing while a text field has focus); `TaskListView` wires it up on the Mac only (`onKeyPress`, `ChosenRows` keeps the chosen row per list so it survives detail and back), `Paper.wideListRow(selected:)` paints it accent 12 %, hover grey 7 %; Schnitt 2: the start page's "Now" rows take the same keys on the Mac only (`StartPage.macNowRow`/`keyed`, `ChosenRows.start`; only the visible rows, 5 folded; list focus only from a click or when the writing line lets go, never on appear; iPhone and iPad rows unchanged), main window at least 760 × 520 pt of content
- `Shared/Models/DetailBack.swift` (#830, pure): where "Back" leads from a task the sidebar's selection opened (start page, writing
  line, side column, widget); `ContentView` follows every change of the selection and shows `detailBackButton` on Mac and wide iPad.
  The wide iPad's sidebar is the Mac's index (#828): `ContentView` hands the window's size class into the sidebar column, which
  itself always reports compact on the iPad. The wide detail's bar holds Complete (a word), Next up, Move and Park (#831).
- `Shared/Persistence` — `ModelContainerFactory` (app group + private CloudKit; identifiers read from
  `Info.plist`, keys `LEAppGroup`/`LECloudContainer`, with the production constants as fallback —
  device builds carry their own via `BUNDLE_ID_SUFFIX`, #156), `ContextSeeder`,
  `CloudKitSchemaInitializer` (Debug only: writes the full CloudKit schema into Development, never opens the app-group store, #175)
- `Shared/Language` — language packs (#750, #751–#755): `LanguagePack` holds every rule word of one language (weekdays, months, time and
  duration words, importance/urgency, place phrases, title lead-ins, context words); `GermanPack` and `EnglishPack` are the shipped ones.
  `LanguagePacks.shipped` is the one list of shipped languages (scripts read it with `scripts/shipped_languages.py`); the rules read all
  of them at once (no language field in the product). Tests plug a pack in with the task-local hook `LanguagePacks.pluggedIn` (`active` reads
  it, `withPacks` in `LooseEndsTests/Language`); `LanguagePackConformanceTests` hold the tables clean, `RuleGoldenTests` hold the rule output
  of every corpus sentence equal (`LooseEndsTests/Fixtures/rule-golden.json`, refreshed with `LOOSEENDS_UPDATE_GOLDEN=1`). The way a
  third language gets in is the eight-point list in `docs/reference/neue-sprache.md`; it enters `shipped` last.
- `Shared/Services` — `CaptureService`, `FieldCodec` (one encoding per field), `RevisionService` (reset = user revision),
  `TaskActions` (done, next up, park, move, restore), `DateExpressionParser`/`TimeExpressionParser` (rule-based
  date/time extraction DE/EN, moved from `Measurement/` in #95), `RawTextWords` (the one tokenizer for word-set
  equality, shared with `Measurement/`, moved from `TitleCheck` in #136), `TitleRule` (the title at capture: raw text
  cleaned, first 12 words, #202), `SiriFields` (Siri's link, flag, tags onto a new task: `resolve` checks before
  saving, `apply` writes after; not in the product path until #25, #225), `SiriCapture` (Siri's reminder fields onto a
  new task in two steps: `prepare` (async, checks everything, writes nothing, geocoder injected) and `commit`
  (MainActor, writes with author `.user`, reason "Siri", F1 notes appended to the raw text, F2 unknown list creates the
  project via `CatalogService.project(named:in:)` by `nameKey`; on any error nothing is left behind); no Siri types in
  `Shared/Services`; not in the product path until #25 Schnitt 2), `Subtasks` (#565, concept D: a line under a task
  that becomes a task when needed; `add` keeps the typed words as title, `traits` what a line carries of its own, `open`
  the lines a completion asks about; the due date and tag word rules read a line in
  `EnrichmentCoordinator.applySubtaskRules`, the model never), `PendingCompletions` (the three-second undo window;
  "Complete all" checks the open lines off with the task, #565), `WaitingOn` ("waiting on" set by hand:
  link, loosen, picker candidates without loops, a user revision per change, #251), `SharedAttachment` (a shared photo or
  file before saving: temp file, never `Data`; title from the file name, photo name, ≤ 50 MB and ≤ 10 per share;
  `CaptureService.save(attachments:)` reads each once, #399), `SharedAttachmentFile` (the share extension's file I/O: which
  registered type is an attachment, copy out of the provider's handler into a temp folder, over 50 MB not copied, remove the
  folder on Done and Cancel, #442). All pure over the model objects; the
  caller saves. Exception: `OrderExecutor` (#613, Weg B) runs an order from Claude (`capture`, `complete`, `setDue`) as a user
  change with the reason "Claude", checks the expected state before the first write (`stale`, `missing`, `invalid`) and saves
  itself; `TranscriptCodec` builds the transcript for Claude (open tasks, "Now" and its count from `ViewRules`, no raw text or
  note). Contract version 1: `docs/reference/claude-abschrift-vertrag.md`. Nothing in the app calls either yet.
- `Shared/Enrichment` — `TaskEnricher` protocol (`StubEnricher` in the tests plays hang, empty answer, answer per note and
  refusal, #530), `ModelDeadline` (time limit per model call, 25 s in the coordinator, from the measurement #534; a timeout counts as a failed call, #530), `EnrichmentWriter` (threshold + revisions; never writes the model's contexts or project, #215/#469), `EnrichmentCoordinator`
  (catch-up pass), `FoundationModelsEnricher` (on-device model, `#if canImport(FoundationModels)`), `DueDateRule`
  (combines the rule parsers into the due date, confidence 1.0, #95), `ImportanceUrgencyRule` (keyword
  match for importance/urgency, confidence 1.0, no default on miss, #117), `DurationRule` (a length the text names, "20 Minuten",
  rounded up to its bucket, confidence 1.0; runs after recognition and only where it found no duration, never for a line
  under a task, no catch-up once `rulesAppliedAt` is set, only "Analyze again", #441/#673), `RecognitionRule` (equality of
  `RawTextWords` sets contexts and duration from an earlier task, confidence 1.0, no energy, #136), `ContextWordRule`
  (a short word list per default context plus each context's own name sets the contexts; no hit stays empty, #232),
  `ContextWordLearning` (#233: the word list grows from the user's own tag assignments, N = 1 as measured in
  `docs/reference/context-word-learning.md`; the coordinator learns once per pass from every task whose contexts the user set,
  never from a rule or model value (#244), and applies fixed and learned words together; the reason names the learned word;
  the tags page shows "Recognizes: …" under each tag and `LearnedWordsSheet` strikes a word into `TaskContext.forgottenWords`),
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
- `LooseEnds/Places` — the place sheet's helpers (#241): `PlaceSearch` (MapKit, fixed hits under `--ui-testing`),
  `SavedPlacesStore` (home and work, Schnitt 3b: `UserDefaults` plus the iCloud key-value store under the one key
  `savedPlaces`, last writer wins, like `FieldSettingsStore`; the value `Shared/Models/SavedPlaces.swift` is pure, a slot never
  touches a task that carries its place), `CurrentLocation` (`CurrentLocating`: one `requestLocation`, the "while using" prompt
  once while undecided, the name by `MKReverseGeocodingRequest`; nil on the Mac, where the row is not offered; under
  `--ui-testing` a fixed fix, `--ui-testing-location-here` on the Altona hit, `--ui-testing-location-refused`). The rules
  (`isAlreadyThere`: haversine ≤ 150 m + accuracy, accuracy over 100 m or negative = unknown; the note order not watched >
  location off > Mac) live in `PlaceEditing`. `./scripts/sim.sh location <lat> <lon>` fakes the simulator's location
- `LooseEnds/Mac` — `MenuBarCapture` (Mac only, #356): the menu bar panel with the same `CaptureView`, Dock icon only
  while a list window is open (`DockPolicy`), login item via `SMAppService` (on from the first start, never under tests);
  `MenuBarThreadImage` (#366): the menu bar symbol is the logo's thread, drawn from `ThreadShape.curvePoints` into a
  template `NSImage` (18 pt, 1x/2x, black on transparent; the raster in `MenuBarThreadRaster` is platform-neutral and unit-tested);
  `MainWindowPlacement` (#593, pure, unit-tested): the main window's first frame via `.defaultWindowPlacement`, the wish
  1200 × 780 cut to the screen's visible area and centred there, never below 760 × 520 (then at its top left corner)
- `LooseEnds/Claude` — the app's core for the service for Claude (#615 S4b-1): `Nonce` (raw value of 32 random bytes as
  base64url, `hashed` = SHA-256 as lowercase hex for Apple) and `ServiceClient` (`/auth/apple`, `/auth/logout`, `/auth/delete`
  over the replaceable `HTTPTransport`, failures as `ServiceError`, never a token or body in an error; a cancelled `URLError` is a `CancellationError`, S4b-3);
  `SessionStoring` with `InMemorySessionStore` and `SessionStoreError` (S4b-2) and `AccountState` (the account's state, S4b-2);
  `KeychainSessionStore` behind `KeychainOperations` (the token in the keychain, this device only, S4b-3).
  `AccountWiring` (S4c-1): `forApp` builds the one `AccountState` in `LooseEndsApp` (main window and Mac settings window), only
  when `isEnabled`: Info `LEAccountEnabled` as Bool (`project.yml` holds `false`; only the TestFlight input `konto` sets it true in the archive, #615 S4c-2a), fallback **off** (missing or another type hides the group in every real build);
  `serviceURL` reads Info `LEServiceURL`: https with a host, http only to `localhost`/`127.0.0.1` in a Debug build, anything else
  the fallback `https://loose-ends.henemm.com` (S4c-2b); under `--ui-testing` always on, store in memory
  and the stand-in `UITestTransport` (no network; `--ui-testing-account-not-allowed` 401, `--ui-testing-account-retry-later` 503,
  `--ui-testing-account-slow` answers after 15 s). While signing in the Apple button stays, disabled, above the progress row (S4c-2b).
  The view is `LooseEnds/Views/AccountSection.swift`: the group "Claude" in the settings right under iCloud, rows from the pure
  `AccountSection.layout(status:problem:)`, `SignInWithAppleButton` (a plain test button under `--ui-testing`), sign out without a
  question, delete only after the `.destructive` confirmation; nothing is sent before a tap
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
  `LOOSEENDS_PUSH=<file.apns> ./scripts/sim.sh test-proof <class>`; replans on a CloudKit import, #553),
  `BackgroundRefresh` (iOS only, #553: a daily `BGAppRefreshTask` rewrites the plan without an app start; identifier
  `com.henning.looseends.refresh` in `project.yml`; its system closures are `@Sendable` and never inherit a main-actor
  binding, #780), `PlaceNotificationCenter` (iOS/iPadOS only, #240
  Schnitt 2: `UNLocationNotificationTrigger` with a 150 m region, permission „When in use“ only, never `CLMonitor` or
  „Always“; reconcile removes first, adds, then writes the handover list, errors are logged and never thrown; the
  simulator cannot fire the real trigger and rejects `add` with 2003, so arrival is proven on the device only)
- `Shared/` compiles into the watch and widget targets too: no SwiftUI that is unavailable on watchOS there
  (keyboard shortcuts, navigation bar modifiers). App views belong in `LooseEnds/Views`.
- `docs/project/` — decisions, user story, data model, design briefing, load-bearing assumptions with their experiments and alternatives (`06-annahmen-und-experimente.md`); `docs/reference/` — learnings carried over from FocusBlox
- `Measurement/` — measurement-only code against the fidelity, self-consistency and convention corpora
  (e.g. `RuleBaseline` for the word→context convention test, spike #69; `LeaveOneOut` for the rule-based
  leave-one-out test — Jaccard word overlap as neighbor search against a corpus-derived baseline, #131);
  compiles into `LooseEndsTests` and the lab app only, no product path; `RawSentenceColumn` (#88 Teil 2, Schnitt A) reads
  Henning's own captures from the gitignored `docs/reference/loose-ends-rawtexts.json` (third format of `Corpus.load`, recognized
  by `rawText` + `titleBefore` + `capturedAt`): duplicates folded by word set, only his corrections count as truth (uncorrected =
  no evidence), rule column beside the model, under 30 corrected sentences the report says "zu wenig", counts only and never a
  sentence. The export and the lab run are Schnitt B and wait for his "jetzt ist ein Test möglich". Schnitt B1a (#88): `Corpus.loadReport` names a missing, unreadable or empty corpus (`Corpus.Problem`), the lab runner pauses with that reason instead of reporting "0 Sätze"; `Corpus.url` also looks in `docs/reference/`; the lab target copies the raw-text file into its bundle only if it exists (post-build script in `project.yml`), `sim.sh lab` links it from the main folder
  Schnitt B1b (#88): `RawTextExport` reads a store read only (`SQLITE_OPEN_READONLY`, tables `ZTASKITEM`/`ZREVISION`) and writes that file:
  the user's first title revision gives `titleBefore`, the last `titleUser`, the last duration revision `durationUser`; ids are numbers in
  capture order; it writes only below `docs/reference/` or outside the repo; built alone with `swiftc` together with
  `scripts/export-loose-ends-rawtexts.swift` (call in `docs/reference/messung-rohsaetze.md`); Henning's real store only after his word (B2)
- `server/` — the service for Claude (Weg B, #613): TypeScript that Node 26 runs directly (type stripping, no build step), Postgres.
  `src/migrate.ts` applies numbered `NNN_name.sql` exactly once, each in its own transaction with its row in `schema_migrations`;
  a gap or a duplicate number is refused before the database is touched. The schema exists only as numbered migrations, and once
  the service runs they are only ever added. CI: `.github/workflows/server.yml` on Linux with `postgres:18`
  `src/mcp.ts` (`mcpHandler`, C4a): stateless MCP handler with the read tools `get_now` and `list_tasks`, account only from `authInfo`; C4b-1 adds `capture_task`, `get_order_result` (`getResult` in `src/orders.ts`: unknown, waiting, claimed, result; another account's order is unknown); C4b-2 adds `complete_task`, `set_due` (expected state from the transcript, `generatedAt` required); no sign-in yet; #621 S5 adds the read tools `get_view` (now, due, next, open: the app's own lists, ids in the optional transcript key `views`, migration 006; an old transcript without it is told so, nothing is recomputed), `search_tasks`, `get_task`, `list_projects`, `list_contexts` (counted from the open tasks); #622 adds the order tools `set_next`, `park_task`, `add_subtask` (orders `setNext`, `park`, `addSubtask`, migration 007; `OrderExecutor` runs them, no revision because status, rank and subtasks are no revised fields; moving a date is `set_due`; no delete tool)
  `src/main.ts` (#796 S1): process entry with a route table (`/health`, `/mcp`), pool with an error listener, migrate with retry at
  start, `/health` 200 only after migrate + `SELECT 1`, 503 at > 50 % 5xx in 5 min (≥ 20 requests); `npm start` in `server/`
  `migrate` (#796 S3) runs on one client under the session advisory lock `MIGRATE_LOCK_ID` and reads the state only after it, so
  parallel starts apply each migration once; a broken connection is discarded, which frees the lock. `server/Dockerfile` (#796 S2):
  `node:26-slim`, user `node`, `npm ci --omit=dev`, no `HEALTHCHECK` (Compose and `monitor.sh` check `/health`); the CI job `image`
  starts it against Postgres 18 (health, log without secrets, SIGTERM → exit 0). Deploy on `rennwienix` is S4
  `migrations/002_accounts.sql` (#615 S1): accounts keyed by `apple_sub`, sessions stored only as SHA-256, a column for the encrypted Apple refresh token;
  `src/accounts.ts` (`findOrCreate`, `createSession`, `resolveSession`, `endSession`, `deleteAccount`: one transaction, removes the account's transcript, orders and results too, locks the account first, returns `tokens` as a list of `{ blob, clientId }` ordered by `client_id`, #621 S4c-1; sessions expire sliding: `SESSION_IDLE_DAYS` = 90 days without use, boundary `>`, database time, an expired row stays invisible and is never revived, no cleanup, `endSession` without deadline check, #615 S4a); called by `src/auth.ts`. Product callers create accounts only through `admit` (#621 S6a): a set `ALLOWED_APPLE_SUBS` holds for everyone, existing accounts too; without it only the first account is created, then the door is shut (`pg_advisory_xact_lock` on `ACCOUNT_LOCK_ID`); an invalid value stops the start with `allowed subs invalid: ALLOWED_APPLE_SUBS`; a refusal logs only `account refused`; `findOrCreate` is a test helper; the rule goes with #625
  `src/apple.ts` (#615 S2a): `loadAppleConfig` (five `APPLE_*` variables, an error names only the variable) and `verifyIdentityToken` (RS256 only, iss, aud exact, exp/iat with 60 s leeway, nonce as SHA-256; key lookup passed in, JWKS cache in S2b; success carries the checked `aud`, S3a); `loadAppleConfig` called by `main.ts`, `verifyIdentityToken` by `src/auth.ts`.
  #621 S4a: optional `APPLE_WEB_CLIENT_ID` (Services ID for the browser sign-in) as `webClientId`, never in `clientIds`; equal to an app id or with a comma it throws, set alone it stops `main()` like the other `APPLE_*`; `verifyIdentityToken` takes `audiences` (default `config.clientIds`, so `/auth/apple` keeps refusing web tokens)
  `src/apple-jwks.ts` (#615 S2b-1): `createJwks` fetches Apple's keys (fetch and clock passed in), cache 1 h, a reload for an unknown kid at most once in 60 s (a failed one counts too), one shared fetch for concurrent callers, fail-closed once expired (`keys_unavailable`); one instance per `start()` in `main.ts`
  `src/apple-vault.ts` (#615 S2b-2): `encryptToken`/`decryptToken` (AES-256-GCM, blob `[0x01 | iv 12 | tag 16 | ct]`, the account as AAD, `authTagLength: 16`; decrypt gives `null` on any failure and never throws) and `storeRefreshToken` (one token per account and client: upsert `ON CONFLICT (account_id, client_id)`, `client_id` NOT NULL and part of the key since `migrations/005_apple_tokens_per_client.sql`, #621 S4c-1; an empty client id throws before the database; `created_at = now()`, `false` for an unknown account/23503); called by `src/auth.ts`
  `src/apple-client.ts` (#615 S2c-1): `clientSecret` (ES256 JWT per call, 5 min, `ieee-p1363`) and `redeemCode` (POST /auth/token, form without redirect_uri, 5 s timeout, `sub` read from `id_token`; reasons `apple:<error>`, `apple_status`, `unavailable`, `malformed_response`, never throws on Apple's answer); S2c-2 `revokeToken` (POST /auth/revoke, same secret and shared POST; `ok` on 200 only means "not refused", Apple may answer 200 for an invalid token; reasons `apple:<error>`, `apple_status`, `unavailable`); called by `src/auth.ts`.
  #621 S4a: all three accept the app ids and `webClientId`, any other id throws before the network; `redeemCode` adds `redirect_uri` only with the option `redirectUri` (the app form stays byte-equal) and checks the `id_token`'s `aud` against the id it redeemed with and since S4b-2a returns it as `idToken` (the return verifies its nonce); `authorizeUrl(config, { redirectUri, state, nonce })` builds Apple's authorize address (web id, `response_type=code`, `response_mode=form_post`, no `scope`, nonce as SHA-256 hex like `verifyIdentityToken`); `appleReturnUrl(publicUrl)` = origin + `/oauth/apple/return`; nothing calls them yet (S4b)
  `src/auth.ts` (#615 S3b): `authRoutes(deps)` with `POST /auth/apple` (order: 503 without config or keys, 405, 415, 413 at 16 KiB counted while reading, 400, identity token, code redeemed once the token holds, same `sub`, `findOrCreate`, `storeRefreshToken`, `createSession` last → 200 `{sessionToken}`, `no-store`; every refusal a bare 401, only Apple unreachable 503) and `POST /auth/logout` (ends exactly this session, 204 also for an unknown one); `bearerToken(request)`; no console output; `start()` mounts them through the option `auth` (503 before `migrate`)
  `POST /auth/delete` (#615 S3c-1): session, then delete, then revoke at Apple, one row after the other with each row's own `client_id` (app ids and the web id allowed; best effort: 204 also when it fails or is skipped, an unknown or undecryptable row is skipped, #621 S4c-1); runs without Apple config; optional `AuthDeps.log` gets only `apple revoke skipped`/`apple revoke failed`; mounted by `start()` with the other auth routes (503 before `migrate`)
  `src/main.ts` (#615 S3c-2): `main()` always passes `auth`; `appleConfigFromEnv`: no `APPLE_*` set → `/auth/apple` 503, logout and delete run; partly set or invalid → start stops before pool and listen with `apple config invalid: <variable>` and exit 1; one lazy `createJwks` instance per `start()`, only with a config, shared by `/auth/apple` and the issuer's `appleInteraction` (#621 S4b-1); bodies over 1 MiB (counted while reading) get 413 without a body and `connection: close`, past `dispatch`, so not in the error window; `/health` and `/mcp` cannot be replaced; `logError` never throws. Still open: nginx lets `/auth/*` through and `APPLE_*` in the Compose stack (S4/#621)
  `migrations/004_oauth.sql` + `src/oauth-adapter.ts` (#621 S2): storage for the OAuth server (S3), one table `oauth_records` for every oidc-provider model; `PgAdapter(pool, model, now)` with `upsert`/`find`/`findByUid`/`consume`/`destroy`/`revokeByGrantId` (`findByUserCode` throws, no device flow); ids only as SHA-256, `jti` and `consumed` never in the payload; expired rows invisible to `find`, deleted at most every 10 min on an `upsert` (a failed cleanup never fails it); `consume` and `ReplayDetection` atomic in one statement (a second one throws); `account_id` references `accounts` with cascade, and `deleteAccount` also removes rows known only by one of the account's grants (Interaction); used by the issuer since S3
  `src/oauth-provider.ts` (#621 S3, ADR-21 addendum): the OAuth issuer, `oidc-provider` 9.13.3 pinned exactly; `createProvider` (issuer = origin of the public URL, `proxy` on, routes under `/oauth/`, both discovery documents, CIMD draft-02 only for `https://claude.ai`, auth method `none`, PKCE S256 required, the one resource `<publicUrl>/mcp` with scope `tasks` and opaque tokens, refresh rotation, `devInteractions` off; the product interaction answers a fixed 501 and never signs anyone in until S4); `providerVerifier` (token looked up in `oauth_records`: unknown, expired, foreign `aud` or no account → 401, else `extra.account`); `oauthKeysFromEnv` (`OAUTH_COOKIE_KEYS` comma list, each ≥ 32 characters; `OAUTH_SIGNING_JWK` private ES256 JWK; none set → no issuer, one set or invalid → `main()` stops with `oauth config invalid: <variable>` and exit 1 before pool and port). `main.ts` hands the issuer's paths the raw request before `bridge` (the library reads the body itself, limit 56 KiB), 503 without a body before `migrate` or without keys; its answers count in the error window except the deliberate 501; library errors are logged only as `oauth server error`/`oauth error` (an FK error's `detail` names the account). Without keys `/mcp` stays on `rejectAll`. Still open: the real interaction (S4), consent page (S5), nginx and keys in Compose (S6)
  `src/oauth-interaction.ts` (#621 S4b-1): `appleInteraction`, the way out to Apple; built by `mountIssuer` only with `APPLE_WEB_CLIENT_ID`, OAuth keys and no `oauth.interaction` set (tests keep their own), else `productInteraction` (fixed 501). Prompt `login`: the path uid must equal the cookie's (`interactionDetails`, which does not compare them), random `state` and raw `nonce` stored as `state → { uid, nonce }` under the model `AppleLogin` (`PgAdapter`, hashed, TTL `min(600, rest of the interaction)`), then 303 to `authorizeUrl` with `no-store` and `no-referrer`; no cookie, a foreign cookie, no time left or a failed store → fixed 400 `bad request`, never a redirect without stored state; prompt `consent` stays the 501 unless the option `consent` is set (S5, below). Logs only `oauth interaction refused`/`oauth interaction store failed`. the way back `/oauth/apple/return` is built since S4b-2a (`src/oauth-return.ts`); the web Apple token is stored by the way back (`src/oauth-return.ts`, S4c-2).
  S4b-2b: the path splits into `<uid>` (the way there above), `<uid>/finish` (the closing) and anything else (fixed 400). `finish`: GET only (else 405 `allow: GET`), the cookie's interaction (`interactionDetails`) must be the path's uid and in prompt `login` (no 501 fallback), exactly one non-empty `ticket`, the ticket (`TICKET_MODEL`) found, in exactly one of the two forms and for this uid, only then consumed (a wrong cookie or ticket burns nothing), then `interactionFinished` with `{ login: { accountId, remember: false } }` or `{ error }` (no description, `mergeWithLastSubmission: false`), the library's 303 to `/oauth/auth/<uid>`; a database error or a library throw → 400 and `oauth interaction store failed`, every other refusal 400 and `oauth interaction refused`
  `src/oauth-consent.ts` (#621 S5): the consent page, mounted by `main.ts` with the Apple interaction. GET `/oauth/interaction/<uid>` in prompt `consent` shows one page (client name from its metadata, clipped and escaped; read and change, no delete; no script, CSP `default-src 'none'` without `form-action` because Chrome applies it to the redirect to Claude); `POST …/confirm` adds exactly the scopes the library lists as missing to a Grant and finishes with `consent`, `POST …/abort` finishes with `access_denied`; both need the interaction cookie, the path's uid, prompt `consent` and `Origin` equal to the issuer's origin (CSRF), else the fixed 400. One right (`tasks`), no read-only choice. `userinfo` and RP-initiated logout are off (S3 notes). Still open: S6 nginx and keys in Compose (`henemm-infra`)
  `src/oauth-return.ts` (#621 S4b-2a): `appleReturn`, Apple's `form_post` back to `POST /oauth/apple/return`; built by `mountIssuer` under exactly the conditions of `appleInteraction` (same JWKS instance), `createProvider` routes only this exact path to it (else the issuer's 404). Order: 405, 415, 413 at 16 KiB counted while reading, 400 for missing or doubled `state`/`code`/`error` (`user` never read), `state` redeemed once (`AppleLogin`), then Apple's `error` → `access_denied`, `redeemCode` with the web id and `verifyIdentityToken` on its `idToken` with the raw nonce (unreachable/`keys_unavailable` → `temporarily_unavailable`, every other refusal `access_denied`), else `findOrCreate`; the result `{ uid, accountId }` or `{ uid, error }` as a one-time ticket (`AppleTicket`, 60 s, hashed, `account_id` with cascade), then 303 to `/oauth/interaction/<uid>/finish?ticket=…` (`no-store`, `no-referrer`); a failed store a fixed 400, never a redirect without ticket. After `findOrCreate` the way back stores the web refresh token encrypted under `webClientId` (`encryptToken`, `storeRefreshToken`, #621 S4c-2); an account deleted during the sign-in (`false`) gives the ticket `access_denied` without account id, a database error the fixed 400 `store failed`; `/auth/delete` revokes that row with the web id. Logs only `oauth return refused`/`oauth return store failed`. `Ticket` and `TICKET_MODEL` are exported, the one source for the writer here and `finish` in `src/oauth-interaction.ts` (S4b-2b)
  `src/oauth-resource.ts` (#621 S1): the service as an OAuth protected resource; `metadataRoute` serves `/.well-known/oauth-protected-resource/mcp` (GET only, issuer = origin of the public URL, not gated, not replaceable), `bearerGate` (SDK `requireBearerAuth`, audience = `<publicUrl>/mcp` from the config, never the Host header) puts `/mcp` behind a bearer token: without one 401 with `WWW-Authenticate` and `resource_metadata`, a checked token hands `authInfo` to `mcp.ts`; the default verifier `rejectAll` refuses every token (app session tokens too) as long as no issuer runs (no OAuth keys); with keys `providerVerifier` takes its place (S3), and app session tokens are refused there too; `publicUrlFromEnv` (`PUBLIC_URL`, default `https://loose-ends.henemm.com`, https origin or http on localhost) — invalid stops `main()` with `public url invalid` and exit 1
  Betrieb (#796 S4a, #621 S6b): `https://loose-ends.henemm.com`; public since S6b (2026-11-08) by an allowlist in nginx: `/health`, `/mcp` (streaming, zone `loose_ends_mcp`), the three
  `/.well-known/` documents and `/oauth/` (zone `loose_ends_oauth`, 64 KiB); `/auth/*` (#615 S4) and everything else stay 404. Apple: Services ID
  `com.henning.looseends.web`, key `SF83PT3Q22`; the door is shut (`ALLOWED_APPLE_SUBS` set, one account, Henning's). claude.ai is connected as a
  custom connector since S6b (CIMD `https://claude.ai/oauth/mcp-oauth-client-metadata`); evidence `docs/artifacts/feat-621-s6b-betrieb/`. fail2ban's
  `nginx-limit-req` bans an address for 1 h after 10 limit hits (henemm-infra#397); stack and nginx host live in `henemm-infra` (`loose-ends/`, `nginx/loose-ends.henemm.com.conf`, service on `127.0.0.1:8780`, `postgres:18.6`); rolled out by hand on `rennwienix` with `scripts/deploy-loose-ends.sh` at a fixed commit (`LE_COMMIT`); nightly plain-SQL dump of `loose-ends-db` in rennwienix's backup (`scripts/backup-loose-ends-snapshot.sh` from `backup.sh`, local `/home/hem/backups/loose-ends/` keeps only the latest, history off-site via restic; tests in `henemm-infra`), restore proven 2026-11-04 from the off-site snapshot; the weekly automatic restore test follows with S4b-2

## Naming

`TaskItem` is the task model (not `Task`, which is Swift Concurrency). `TaskContext` is a context tag.
Bundle id `com.henning.looseends`, app group `group.com.henning.looseends`, CloudKit `iCloud.com.henning.looseends`.
