# Context: fix-341-testlaeufe-verlaesslich

## Request Summary
Testbelege sollen verlässlich sein: UI- und Unit-Tests laufen lokal wie in der CI beim ersten Versuch grün, nie mit
Hennings Mac als Testhost, und parallele Sitzungen verfälschen einander nicht. #341 bündelt fünf geschlossene Tickets
(#208, #168, #305, #304, #294); #336 zählt für die DoD mit. Henning hat am 2026-10-17 „ein Ablauf“ gewählt (kein Schnitt).

## Stand der fünf Teile (aktueller main, 1772f63)

| Teil | Ticket | Stand laut Code | Offen |
|---|---|---|---|
| 1 Modell im Simulator | #208 | **Vermutlich überholt:** seit #228 (aa00942, 2026-10-06) nimmt die App unter `--ui-testing` `ModelOffEnricher` (`LooseEnds/App/LooseEndsApp.swift:31`). Das Modell schreibt in UI-Tests also nichts mehr. | Belegen (Klassenlauf `CaptureSmokeTests` zweimal grün), dann als erledigt einordnen |
| 2 Wiedererkennung | #168 | Code-Teil erfüllt (Kommentar 2026-10-08: `topRow(in:)` + `detailRawTextMarker`). „Mit aktivem Modell“ gibt es unter UI-Tests seit #228 nicht mehr. | `test-proof RecognitionWalkthroughTests` dreimal lokal grün |
| 3 Lokal rot, CI grün | #305 | `ContextUniquenessTests`: Hypothese aus Kommentar 2026-10-13 — `@AppStorage("startShowsContexts")` (`LooseEnds/Views/SidebarView.swift:35`) überlebt Läufe; der Test setzt `-startShowsContexts` nicht. Seit #428 (e28dcb1) öffnet `contextsToggle` eine eigene Seite, die Hypothese ist neu zu prüfen. `CalendarTargetTests/testSwitchOnShowsTargetCalendar`: Ursache unbekannt; Kandidaten: Kalenderfreigabe im Simulator (TCC), persistierter Gerätestandard `CalendarSync.deviceDefault()` / `calendarIdentifier` in UserDefaults, übrig gebliebener „Loose Ends“-Kalender, `testDefaultCalendarIsStampedOnSwitchOn` setzt einen fremden Standard und stellt ihn erst am Ende zurück. | Reproduzieren, Ursache belegen, beheben |
| 4 Sitzungen trennen | #304 | **Ursache bestätigt (2026-10-17):** `scripts/sim.sh:54` liest `CLAUDE_SESSION_ID`; die Variable ist in Claude-Code-Sitzungen leer, gesetzt ist `CLAUDE_CODE_SESSION_ID`. Also `default` für alle → gemeinsames DerivedData `LooseEnds-session-default`. Zusätzlich: `LOCK_DIR="$PROJECT_DIR/.claude/sim_lock.d"` liegt je Worktree, sperrt also nicht über Worktrees hinweg; alle nehmen denselben Simulator `iPhone 17` (`SIM_NAME`, Zeile 46). | DerivedData und Simulator je Sitzung trennen, Beleg mit zwei Sitzungen |
| 5 Unit nur im Simulator | #294 | `cmd_unit` (`sim.sh:181`) nimmt `platform=macOS`, sobald `mac_hosts_tests` (Zeile 167) wahr ist. Kopfkommentar Zeile 10 sagt „macOS-Destination“. | `unit` → Simulator; Mac nur per ausdrücklicher Variable; CLAUDE.md |
| DoD | #336 | Geschlossen (PR #346, drei CI-Läufe grün belegt). | Nur einordnen |

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/sim.sh` | `SESSION_ID` (54), `SESSION_DERIVED_DATA` (55), `LOCK_DIR` + `acquire_lock` (56–80), `mac_hosts_tests` (167), `cmd_unit` (181), `cmd_sim_unit` (298), `cmd_test`/`cmd_test_proof` (308–363), Kopfkommentar (1–38) |
| `scripts/test_sim_run_xcodebuild.py` | Python-Test, der `run_xcodebuild` wörtlich aus `sim.sh` zieht und mit `SESSION_DERIVED_DATA` aufruft; läuft in jeder CI (#185) |
| `scripts/test_sim_proof.py`, `scripts/sim_proof.py` | Beleg aus `test-proof`; liest `.claude/active_workflow` |
| `LooseEndsUITests/ContextUniquenessTests.swift` | `addContext` (40–58), Startargumente ohne `-startShowsContexts` (62–66) |
| `LooseEndsUITests/CalendarTargetTests.swift` | `testSwitchOnShowsTargetCalendar` (Fehlerzeile „The detail should name the calendar…“), `testDefaultCalendarIsStampedOnSwitchOn` |
| `LooseEndsUITests/DesignGalleryTests.swift:26` | Vorbild: setzt `-startShowsContexts NO` |
| `LooseEndsUITests/StartScreenInteractionTests.swift` | Vorbild `scrollTo` |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift`, `CaptureSmokeTests.swift` | Belegläufe für Teile 1 und 2 |
| `LooseEnds/Calendar/CalendarBridge.swift` | `suppressed` (40–44), `deviceDefault`, Schlüssel `calendarIdentifier`, `calendarIdentifiersWritten`, `sync()` / Freigabe |
| `LooseEnds/Views/SidebarView.swift:35` | `@AppStorage("startShowsContexts")` |
| `LooseEnds/App/LooseEndsApp.swift:31` | `ModelOffEnricher` unter `--ui-testing` |
| `.github/workflows/ci.yml` | Unit-Job ruft `xcodebuild … -destination 'platform=macOS'` direkt (nicht `sim.sh`) auf GitHubs Rechner — von #294 nicht betroffen; UI Smoke mit eigenem Simulator |
| `CLAUDE.md` | Build-Abschnitt nennt `./scripts/sim.sh unit` als Unit-Tests |

## Existing Patterns
- Startzustand über Startargumente: `-key VALUE` setzt UserDefaults für den Lauf (`-contextsEmptiedByUser NO`, `-startShowsContexts NO`).
- Sperre per atomarem `mkdir` mit Zeitstempel und Stale-Erkennung (600 s) in `acquire_lock`.
- Testkommandos bauen ihr Ziel aus `sim_id` (Name + Laufzeit ≥ Target).
- Gerätebauten trennen sich bereits je Sitzung: `device_derived_data` (Zeile 402) mit `SESSION_ID`.
- Sitzungsabsprache bisher von Hand: `/tmp/loose-ends-testlauf.lock` (Memory „Sitzungen abstimmen“).

## Dependencies
- Upstream: `xcrun simctl`, `xcodebuild`, Claude-Code-Umgebung (`CLAUDE_CODE_SESSION_ID`, ggf. `CLAUDE_PROJECT_DIR`), `.claude/active_workflow`.
- Downstream: jede Sitzung, jeder Workflow-Hook und jeder Beleg (`test-proof`) geht über `sim.sh`; die Python-Skripttests in der CI ziehen Funktionen wörtlich aus `sim.sh`.

## Existing Specs
- `docs/specs/*/fix-172-ui-tests-first-try.md` — Vorgänger (gleiches Ziel)
- `docs/specs/*/fix-298-testlauf-nachlauf.md` — `run_xcodebuild`
- `docs/specs/*/feat-145-simulator-beleg.md` — `test-proof`
- `docs/specs/feat-203-teil-c-zielkalender.md`, `feat-203-teil-c2-standardkalender.md` — Kalenderpfad
- `docs/specs/fix-157-kontexte-eindeutig.md`, `feat-428-etiketten-seite.md` — Kontexte, Etiketten-Seite

## Risks & Considerations
- **Überschneidung mit #413** (offen, gleiches Epic #465): rechnerweite Sperre für jeden Bau-/Testlauf. Teil 4 hier
  (eigener Simulator je Sitzung) und #413 (nur ein Lauf zugleich) ziehen in verschiedene Richtungen: eigener Simulator
  je Sitzung erhöht die Last, die #413 senken will. Die Analyse muss entscheiden, ob eine Sperre über alle Sitzungen
  (aus #413) Teil 4 schon löst, und ob #413 hier aufgeht.
- **Scoping:** `sim.sh`, 2–3 Testdateien, CLAUDE.md, evtl. ein Python-Test → 5 Dateien an der Grenze.
- **Kalendertest berührt den echten Simulatorkalender** (`--ui-testing-calendar`); eine Härtung darf ihn nicht abschwächen (#305-DoD).
- **Reproduktion braucht den Simulator** (kein Gerät); parallele Sitzungen vorher per ListAgents abstimmen.
- Teile 1/2 nicht neu bauen, wenn #228 sie schon löst — nur belegen.
- CI-Unit-Job läuft auf GitHubs macOS-Rechner, nicht auf Hennings Mac; #294 betrifft nur `sim.sh unit`.
- Memory „Simulator hat ein Modell“ ist seit #228 für UI-Tests überholt (prüfen und berichtigen).

## Analysis

### Type
Bug (Werkzeug und Tests; kein Produktcode, keine sichtbare Änderung an der App)

### Recherche (2026-10-17)
- Claude Code setzt in Bash-Aufrufen `CLAUDE_CODE_SESSION_ID` (seit v2.1.132), nicht `CLAUDE_SESSION_ID`:
  https://claudeissues.com/issue/56879-docs-environment-variables-claude-code-session-id-not-documented-in-env-vars-ref
- Parallele xcodebuild-Läufe: eigener DerivedData-Pfad je Checkout, Simulator nie gleichzeitig von zwei Läufen benutzen
  (Kollisionen beim Installieren derselben Bundle-ID): https://developer.apple.com/forums/thread/833677,
  https://spin.atomicobject.com/ci-parallel-ios-test-jobs/
- SwiftUI-List erzeugt Zeilen unter dem Bildrand nicht; seit Xcode 14 sieht XCUITest sie erst nach dem Scrollen, ein
  festes einmaliges Wischen ist als wackelig bekannt: https://developer.apple.com/forums/thread/719444,
  https://betterprogramming.pub/ios-extracting-lazily-loaded-elements-for-ui-testing-5541ea190586
- UserDefaults/@AppStorage überleben UI-Läufe; Startzustand per Startargument setzen:
  https://blog.codecentric.de/resetting-ios-application-state-userdefaults-ui-tests

### Reproduktion (2026-10-17, iPhone 17 / iOS 27.0, benutzter Simulator, eigenes DerivedData)
| Teil | Ergebnis |
|---|---|
| 4 Sitzungsschlüssel | `${CLAUDE_SESSION_ID:-default}` → `default` in dieser Sitzung; `LooseEnds-session-default` zuletzt 2026-10-17 06:59 beschrieben; Variable steht so seit 47c52fa (2026-09-16) → hat nie funktioniert. Andere Ordner (`v409`, `s25-2a-dev` …) stammen von Sitzungen, die die Variable von Hand setzten. `CLAUDE_PROJECT_DIR` ist in Bash leer, `PROJECT_DIR` = Worktree-Wurzel. |
| 4 Sperre | `LOCK_DIR` liegt je Worktree → sperrt nicht über Sitzungen; verwaist nach 600 s per Zeitstempel (UI-Läufe dauern länger), Warte-Timeout 300 s; `build` und `unit` sperren gar nicht. |
| 5 Mac-Host | macOS 27.0.1 ≥ Target 27.0 → `mac_hosts_tests` wahr → `unit` testet auf dem Mac (nicht ausgeführt, nur ausgewertet). |
| 3a ContextUniquenessTests | 4× grün: 3× mit `startShowsContexts=true`, 1× nach `defaults write … NO`. Seit #428 öffnet die Tags-Zeile auf dem iPhone eine Seite; `startShowsContexts` wirkt nur im iPad/Mac-Faltzweig (`SidebarView.swift:126–157`). Hypothese vom 2026-10-13 auf dem iPhone überholt → nichts zu ändern, nur belegen. |
| 3b CalendarTargetTests | `testSwitchOnShowsTargetCalendar` 1× **rot** („The detail should name the calendar the event goes to“), 1× grün, ganze Klasse grün. |

**Ursache 3b (belegt am Ergebnisbündel):** `calendarTargetRow` existiert in **beiden** Läufen nicht, bis der Test einmal
`app.swipeUp()` ausführt: Die Zeile liegt in der List unter dem Bildrand und wird nicht erzeugt. Im grünen Lauf schiebt
das eine Wischen sie ins Bild. Im roten Lauf bewegt sich die Liste nicht (74 Hierarchie-Schnappschüsse, Termin-Zeile stets
bei y=842; Videobilder vor/nach dem Wischen gleich), also erscheint die Zeile nie. Nebenbefund: `allowCalendarAccessIfAsked`
wartet in jedem Lauf volle 30 s, weil es auf genau diese unsichtbare Zeile wartet. Kalenderfreigabe (TCC = 2, erteilt
2026-10-12) und gemerkter Gerätestandard (keine `defaultAccount`/`defaultName`-Schlüssel) sind **nicht** die Ursache.
Offen bleibt, warum das eine Wischen in diesem Lauf nicht scrollte; die Härtung darf sich deshalb nicht auf ein
zweites identisches Wischen verlassen.

**Teil 1/2 (#208/#168):** Unter `--ui-testing` nimmt die App `ModelOffEnricher` (`LooseEndsApp.swift:31`, seit #228);
das Modell schreibt in UI-Tests nichts. Kein Code, nur Belegläufe (`CaptureSmokeTests` 2×, `RecognitionWalkthroughTests` 3×).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/sim.sh` | MODIFY | (A) DerivedData-Schlüssel = bereinigter Worktree-Ordnername, `CLAUDE_SESSION_ID` bleibt Override, Ausgabe ohne 8-Zeichen-Kürzung, auch `device_derived_data`; (B) rechnerweite Sperre `/tmp/loose-ends-testlauf.lock` (Verzeichnis + `pid`-Datei mit PID, Startzeit, Worktree, Befehl), verwaist = PID tot oder Startzeit anders, Handsperre ohne `pid` erst nach langer Frist, Übernahme per `mv`, reentrant, Zeile alle 30 s, Obergrenze 30 min, um build/unit/sim-unit/test/test-proof/launch/mac-build; (C) `unit` = Simulator, Mac-Host nur mit `LOOSEENDS_MAC_HOST=1`, Kopfkommentar |
| `scripts/test_sim_lock.py` | CREATE | Skripttest: Schlüssel aus Ordnername/Override; zwei gleichzeitige Sperrversuche laufen nacheinander; Sperre eines per kill -9 beendeten Laufs wird übernommen; `unit` wählt nie `platform=macOS` ohne Schalter |
| `LooseEndsUITests/CalendarTargetTests.swift` | MODIFY | (D) Helfer „scrollen bis die Zeile da ist“ (mehrere Wischversuche auf die Liste, langsam, mit klarer Meldung) statt Ein-Wischen an den 5 Stellen; Zugriffsabfrage wartet auf die Systemabfrage, nicht 30 s auf die Zeile |
| `CLAUDE.md` | MODIFY | Build-Abschnitt: `unit` läuft im Simulator, Sperre und Bauordner je Worktree, Handsperre entfällt |
| `LooseEndsUITests/ContextUniquenessTests.swift` | — | unverändert, nur belegen |

### Scope Assessment
- Files: 4 (3 MODIFY, 1 CREATE)
- Estimated LoC: +200 bis +250 / −20 (sim.sh ~70, Skripttest ~90, Kalendertest ~35, CLAUDE.md ~15)
- Risk Level: MEDIUM — jede Sitzung und jeder Beleg geht über `sim.sh`; eine fehlerhafte Sperre blockiert alle Sitzungen

### Technical Approach
Empfehlung: **ein Ablauf**, wie am 2026-10-17 gewählt, mit #413 und #374 eingeschlossen (sie lösen dasselbe Ziel; ohne
rechnerweite Sperre erfüllt Teil 4 seine DoD nicht, weil zwei Läufe sonst gleichzeitig dieselbe App in denselben Simulator
installieren). Reihenfolge: C → A → B → D → Belegläufe (Teile 1, 2, 3a, 3b mehrfach; zwei Worktrees gleichzeitig).
Reißt die Spec die 250 LoC, wird B als #413 abgetrennt (Plan-Agent empfahl diesen Schnitt vorsorglich).

**Alternativen:**
1. Eigener geklonter Simulator je Worktree (`simctl clone`): echte Trennung von Installation und UserDefaults, parallele
   Läufe möglich — verworfen, weil es die Last erhöht, über die sich Henning am 2026-10-14 beschwerte (7 Simulatoren,
   Last 260–370), plus Aufräumen und >100 LoC.
2. Schlüssel aus `CLAUDE_CODE_SESSION_ID` (eine Zeile): wechselt bei jedem `/clear` → kalter Bau und wachsender
   Plattenverbrauch; nur als Rückfall, wenn kein Ordnername ermittelbar ist.
3. Nur Sperre, DerivedData bleibt gemeinsam: Bauten aus verschiedenen Worktrees überschreiben einander weiter → reicht nicht.
4. Kalendertest: statt Scrollen die Kalenderzeile weiter nach oben in der Detailansicht setzen — verworfen, das wäre eine
   Produktänderung für einen Test.

### Dependencies
- `scripts/test_sim_run_xcodebuild.py` zieht `run_xcodebuild()` per Regex aus `sim.sh` → Funktion nicht umbenennen,
  Sperre außerhalb davon.
- `scripts/test_sim_proof.py` kopiert `sim.sh` in ein Temp-Verzeichnis und ruft `test-proof` (setzt `CLAUDE_PROJECT_DIR`)
  → die rechnerweite Sperre muss dort per Variable umlenkbar sein (`LOOSEENDS_LOCK_DIR`), sonst blockiert der CI-Skripttest
  oder er stört eine echte Sitzung.
- Neue Funktionen in `sim.sh` als `^name() {` … `^}` schreiben, damit Skripttests sie herausziehen können.
- Geschlossen bzw. einzuordnen: #208, #168, #305, #304, #294 (bereits zu); #374, #413 gehen hier auf; #336 geschlossen.
- Nicht hier: #395 (Unit-Lauf hängt in `FocusBloxCalibrationTests`, Modell im Simulator bei Unit-Tests), #419.

### Open Questions
- [x] Schnitt oder ein Ablauf? → ein Ablauf (Henning 2026-10-17), #413/#374 eingeschlossen (technische Entscheidung, Grund oben)
- [ ] keine offene Produktfrage
