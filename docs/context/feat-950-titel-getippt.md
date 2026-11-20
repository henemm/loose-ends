# Context: feat-950-titel-getippt

## Request Summary
Issue #950 (Henning): Aufgaben, die über Claude kommen oder per Tastatur eingegeben werden, sollen vom On-Device-Modell
nicht interpretiert und überarbeitet werden (Titel). Der Claude-Teil ist mit #953 erledigt (Writer überspringt den
Modelltitel bei `capturedVia == .claude`); offen ist der Tastatur-Weg.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/EnrichmentWriter.swift` (Titelblock, ~Z. 44–66) | `let fromClaude = task.capturedVia == .claude` — die eine Stelle, an der die Kanalregel greift; Status wird dort ohne Modelltitel trotzdem gehoben |
| `Shared/Models/Enums.swift` (`CaptureChannel`) | `siri, watch, control, share, mail, app, actionButton, claude`; kein Unterschied getippt/gesprochen |
| `Shared/Models/TaskItem.swift` (`capturedViaRaw`, Z. 14/129) | Kanal als String gespeichert, unbekannter Wert liest sich als `.app` (ältere Builds stürzen nicht) |
| `Shared/Services/CaptureService.swift` | einziger Schreibweg; setzt `TitleRule`-Titel ohne Revision |
| `LooseEnds/Views/CaptureView.swift` | Erfassungs-Sheet (iPhone/iPad „+“, Mac-Fenster) **mischt Sprache und Tastatur**: `speech.transcript` schreibt in `text` solange `speech.isListening`; Fokus aufs Feld stoppt das Mikrofon (Z. 86); Speichern `save()` Z. 392 mit `channel` (Standard `.app`) |
| `LooseEnds/Views/InboxDrawerView.swift` (Z. 176) | Schreibzeile unter „Neu“: nur Tastatur, kein Mikrofon (Diktat der iOS-Tastatur möglich, nicht unterscheidbar), speichert `.app` |
| `LooseEnds/Mac/MenuBarCapture.swift` (Z. 16) | Mac-Menüleisten-Panel, `CaptureView(channel: .app)` — Sprache und Tastatur wie im Sheet |
| `LooseEndsShare/ShareCaptureView.swift`, `Shared/Services/SharedContent.swift` | Teilen/Mail: Text kommt aus anderer App, nicht getippt (`.share`/`.mail`) |
| `LooseEndsWatch/*`, `Shared/Intents/CaptureTextIntent.swift`, `SiriCapture` | Watch/Siri: gesprochen |
| `Shared/Services/TitleRule.swift` | Regeltitel: säubert Datumswörter, höchstens 12 Wörter (#202/#217) |
| `LooseEndsTests/ClaudeTitleTests.swift` | Testmuster aus #953 (Kette Erfassung → Anreicherung mit `StubEnricher`, Erstlauf + Neuanalyse, Gegenprobe) |
| `cloudkit/schema.ckdb` Z. 167 | `CD_capturedViaRaw STRING` existiert — ein neuer Enum-Wert braucht keine Schemaänderung |

## Existing Patterns
- Kanalregel im Writer statt Revision (#953): dauerhaft am Task, gilt für Erstlauf, „Erneut analysieren“ und alte unangereicherte Aufgaben.
- Unteraufgaben gehen gar nicht ans Modell (#565) — Alternative „Modell ganz aus“.
- Neue Enum-Werte als String-Raw-Value, Rückfall `.app` für ältere Builds (wie `TaskStatus.removed`, #605).

## Dependencies
- Upstream: `TaskItem.capturedVia`, `CaptureService.save(via:)`, `SpeechCapture` (Zustand `isListening`, `transcript`).
- Downstream: `EnrichmentWriter.apply`, `EnrichmentCoordinator` (Erstlauf, `reanalyze`), alle Stellen, die `.app` speichern.

## Existing Specs
- `docs/specs/bug-953-claude-titel.md` — Vorbild; nannte „Auch TitleRule abschalten“ als bewusst ausgelassene Alternative.
- `docs/specs/fix-202-titel-regel.md`, `feat-217-titel-ohne-regelwoerter.md`, `fix-125-titel-treue.md` — Titelregel und Modellverfeinerung.

## Offene Punkte für /20-analyse
- **Unterscheidung getippt/gesprochen im Sheet:** Vorschlag: gesprochen, sobald ein Sprachergebnis in `text` gelandet ist; sonst getippt. Gemischt (diktiert, dann per Tastatur korrigiert) → PO-Frage oder Regel „einmal gesprochen = gesprochen“.
- **Kanal-Abbildung:** neuer Wert (z. B. `.keyboard`) statt `.app` für getippte Erfassung, oder Bool-Feld (Schemaänderung, vermeiden).
- **Reichweite:** nur Titel (wie #953) oder auch `TitleRule`-Kürzung (12 Wörter, Datumswörter) aus? Issue sagt „nicht interpretiert und überarbeitet“ — PO-Frage aus dem Intake.
- Teilen/Mail: nicht getippt, bleiben beim Modell (laut Issue-Wortlaut).

## Risks & Considerations
- Ältere Builds auf anderen Geräten lesen den neuen Kanal als `.app` und könnten den Titel noch verfeinern, falls sie die Anreicherung zuerst fahren (CloudKit-Abgleich). Hinnehmbar, im Bericht nennen.
- Diktat über die Tastatur ist nicht von Tippen unterscheidbar → zählt als getippt.
- Bestehende Aufgaben (`.app`) bleiben unverändert; keine Migration.
- Geräteliste: `Shared/Enrichment/EnrichmentWriter.swift` steht nicht darauf; `LooseEnds/Speech/` nur, falls `SpeechCapture` geändert werden muss.

## Analysis

### Type
Feature (Fortsetzung von #953: Claude-Weg erledigt, offen ist der Tastatur-Weg)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Models/Enums.swift` | MODIFY | neuer Kanal `CaptureChannel.keyboard` (String-Rohwert) + `keepsWording` (true für `.claude`, `.keyboard`) |
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | `fromClaude` → `task.capturedVia.keepsWording`; Status wird wie bei #953 trotzdem gehoben |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | `@State heard`: wahr, sobald ein **nicht-leeres** Transkript beim Zuhören in `text` landet; `save()` speichert `.keyboard`, wenn nichts gehört wurde und der Kanal `.app` ist (Sheet iPhone/iPad, Mac-Fenster, Menüleisten-Panel) |
| `LooseEnds/Views/InboxDrawerView.swift` | MODIFY | Schreibzeile unter „Neu“ speichert `.keyboard` statt `.app` |
| `LooseEndsTests/KeyboardTitleTests.swift` (o. ä.) | CREATE | Kette Erfassung → Anreicherung mit `StubEnricher` nach Muster `ClaudeTitleTests`: `.keyboard` behält den Titel bei Erstlauf und „Erneut analysieren“, Status wird gehoben; Gegenprobe `.app`/`.watch` wird verfeinert |
| UI-Test (Smoke) | CREATE/MODIFY | getippte Erfassung im Sheet und in der Schreibzeile wird als `.keyboard` gespeichert, Titel bleibt der eigene Wortlaut |

### Scope Assessment
- Files: 4 Produktiv + 1–2 Test
- Estimated LoC: ca. +15 Produktiv, ca. +80–100 Tests
- Risk Level: LOW — eine Regelstelle im Writer, neuer Enum-Wert ohne Schemaänderung (`CD_capturedViaRaw` ist STRING)
- Geräteliste: kein Pfad berührt (`LooseEnds/Speech/` bleibt unverändert) → Abnahme endet nach Stufe 2

### Technical Approach
Kanalregel wie #953: Der Kanal steht dauerhaft am Task und gilt für Erstlauf, „Erneut analysieren“ und alte, noch
unangereicherte Aufgaben. `TitleRule` (Regeltitel, Datumswörter, höchstens 12 Wörter) bleibt wie bei #953 aktiv.
Abgrenzung getippt/gesprochen im Sheet: gesprochen, sobald ein nicht-leeres Sprachergebnis in das Feld kam (auch wenn
danach per Tastatur korrigiert wurde — das Modell glättet Erkennungsfehler); sonst getippt. Diktat über die iOS-Tastatur
ist nicht unterscheidbar und zählt als getippt.

Geprüft (Plan-Agent): kein erschöpfender `switch` über `CaptureChannel`, kein Vergleich `== .app` im Produktcode,
nichts in `Measurement/`, `scripts/`, Labor-App. `onChange(of: speech.transcript)` feuert nicht beim Start (`""` → `""`),
kann aber bei nicht-leer → leer feuern → Guard `!transcript.isEmpty`.
Teilschritte (`Subtasks.add` speichert `.app`) sind nicht betroffen: das Modell sieht sie nie (#565,
`EnrichmentCoordinator` Zweig `task.parent != nil`).

### Alternatives
- **Merker `titleLocked` am Task** statt Kanal: trennt Absicht vom Kanal, auch für weitere Quellen nutzbar; kostet
  aber eine CloudKit-Schemaänderung samt Production-Deploy, ältere Builds ignorieren ihn. Verworfen: zu viel für das Ziel.
- **Modell für getippte Aufgaben ganz aus** (wie Teilschritte, #565): dann setzt das Modell auch Energie u. a. nicht
  mehr. Geht über den Wortlaut des Issues hinaus (nur „Titel“).
- **Auch `TitleRule` aus** für getippt: wurde bei #953 bewusst nicht gemacht; bleibt konsistent aus.

### Risks
- Ältere Builds auf anderen Geräten lesen `.keyboard` als `.app` und könnten den Titel noch verfeinern, falls sie die
  Anreicherung zuerst fahren. Akzeptierter Rest bis zum Update.
- Bestehende Aufgaben (`.app`) bleiben unverändert, keine Migration.

### Open Questions
- keine (Mischform und TitleRule technisch entschieden, oben begründet; Spec-Freigabe durch PO)
