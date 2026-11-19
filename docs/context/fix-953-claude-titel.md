# Context: fix-953-claude-titel

## Request Summary
Aufgaben, die Claude über `capture_task` anlegt, bekommen in der App vom On-Device-Modell eine neue Überschrift.
Claude ist Eingabekanal (PO 2026-11-19): was Claude anlegt, ist schon formuliert, das Modell darf die Überschrift nicht ändern.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/EnrichmentWriter.swift:44–62` | Einzige Stelle, an der das Modell `task.title` schreibt; Erstlauf: `firstRun: !userHasTouched(.title)`, Neuanalyse: `changes && !userHasTouched` |
| `Shared/Enrichment/EnrichmentWriter.swift:107–121` | `mayWrite`, `userHasTouched` (Nutzer-Revision schützt ein Feld) |
| `Shared/Services/OrderExecutor.swift:103–120` | `capture`: `CaptureService.save(text, via: .claude)`; nur mit `fields.title` wird der Titel per `markTitle` zur Nutzer-Revision |
| `Shared/Services/OrderExecutor.swift:223–233` | `write(fields, …, markTitle:)` |
| `Shared/Services/CaptureService.swift:28–33` | Titel bei der Erfassung per `TitleRule.title` (Regel, ohne Revision, #202) |
| `Shared/Models/Enums.swift:15–19` | `CaptureChannel.claude` — der Kanal ist am `TaskItem` dauerhaft gespeichert (`capturedViaRaw`) |
| `Shared/Enrichment/EnrichmentCoordinator.swift:56–130, 140–200` | Erstlauf (`processPending`) und „Erneut analysieren“ (`reanalyze`) rufen beide `EnrichmentWriter.apply` |
| `LooseEndsTests/EnrichmentTests.swift` | bestehende Writer-Tests (Muster für neue Tests) |
| `LooseEndsTests/OrderExecutorTests.swift` | Capture über Claude in Tests |

## Existing Patterns
- Ein Feld ist vor dem Modell geschützt, wenn eine Nutzer-Revision dafür existiert (`userHasTouched`). So schützt #932 einen mitgeschickten Claude-Titel.
- Regel-Felder (`ruleFields`) sperren das Modell für dieses Feld im selben Lauf.
- Unteraufgaben von Claude (`Subtasks.add(via: .claude)`) gehen nie durchs Modell (#565).

## Dependencies
- Upstream: `TitleRule` (setzt Regeltitel), `TaskItem.capturedVia`.
- Downstream: Status-Logik in derselben Writer-Stelle (`unprocessed/unverified → active` hängt am Modelltitel); alle Ansichten lesen `title`.

## Fehlerweg (Hypothese, noch nicht nachgestellt)
`capture_task` ohne `fields.title` → Titel = Regeltitel ohne Nutzer-Revision → `processPending` ruft das Modell →
`EnrichmentWriter` schreibt den Modelltitel (Autor `.ai`). Mit `fields.title` passiert es nicht (Nutzer-Revision).
`update_task` mit Titel ist ebenfalls eine Nutzer-Revision und damit geschützt, auch bei „Erneut analysieren“.

## Existing Specs
- `docs/specs/feat-932-schnitt-1-app.md` (fields auf capture/update, `markTitle`)

## Risks & Considerations
- Die Statusregel (`unverified` ohne Modelltitel) darf eine Claude-Aufgabe nicht als „unverified“ hängen lassen: der Titel steht ja.
- Andere Felder (Datum, Dauer, Tags, Wichtigkeit) laufen weiter über Regeln/Modell wie bisher (DoD).
- Ältere App-Stände auf anderen Geräten (Mac/iPad über iCloud) könnten die Anreicherung zuerst fahren und weiter umschreiben, bis alle Geräte den neuen Bau haben.
- Offene Produktfrage für die Analyse: Auch `TitleRule` kürzt/säubert Claudes Text (Datumswörter, max. 12 Wörter) — „kommt an, wie geschrieben“ würde auch das betreffen.
- Stufe 3: `EnrichmentWriter.swift` steht nicht auf der Geräteliste; `EnrichmentCoordinator.swift` schon (Modellaufruf).

## Analysis

### Type
Bug

### Nachstellung
Belegt in `docs/artifacts/fix-953-claude-titel/nachstellung.md`: Auftrag `capture` ohne `fields` → Erstlauf der Anreicherung
→ Titel „Angebot für die Gartenhütte bei Müller einholen“ wird zu „Angebot Gartenhütte einholen“ (Autor `.ai`). Dasselbe bei
„Erneut analysieren“. Echtes Modell nur durch Stub ersetzt (Simulator hat kein Apple Intelligence).

### Root Cause
`EnrichmentWriter.apply` (Titelblock, Zeilen 47–58) schützt den Titel nur über eine Nutzer-Revision (`userHasTouched(.title)`).
`OrderExecutor.capture` schreibt eine solche nur mit `fields.title`; ohne steht der Regeltitel von `CaptureService` ohne
Revision da, das Modell darf ihn im Erst- und im Neu-Lauf ersetzen. Der Kanal (`capturedVia == .claude`) wird in der
Anreicherung nirgends gelesen.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | Titelblock: bei `task.capturedVia == .claude` schreibt das Modell keinen Titel (Erstlauf und Neuanalyse); der Status wird wie bisher gehoben (`unprocessed/unverified → active`, sobald ein Titel steht), damit eine Claude-Aufgabe nicht als „unverified“ hängen bleibt |
| `LooseEndsTests/ClaudeTitleTests.swift` | CREATE | Kette Auftrag → Anreicherung (Erstlauf, Neuanalyse), Status, Dauer vom Modell bleibt, Gegenprobe Kanal `.app` wird weiter verfeinert |
| `CLAUDE.md` | MODIFY | Ein Halbsatz an der Regel „Rules before the model“: der Titel einer Claude-Aufgabe gehört nie dem Modell (#953) |

### Scope Assessment
- Files: 3
- Estimated LoC: +~90/-~3 (davon ~80 Test)
- Risk Level: LOW — eine Bedingung in einer reinen Funktion; andere Kanäle unverändert
- Stufe 3: `EnrichmentWriter.swift` steht nicht auf der Geräteliste, `EnrichmentCoordinator.swift` bleibt unverändert →
  „Kein Pfad der Geräteliste berührt.“

### Technical Approach (Empfehlung)
Kanalregel im Writer: Das Modell schreibt den Titel nur, wenn `task.capturedVia != .claude`. Grund: der Kanal ist am
`TaskItem` dauerhaft gespeichert und gilt damit auch für „Erneut analysieren“ und für Aufgaben, die schon angelegt, aber noch
nicht angereichert sind. Übrige Felder (Dauer vom Modell, alle Regeln) laufen unverändert (DoD).

### Alternativen
1. **Titel bei jeder Claude-Erfassung als Nutzer-Revision markieren** (`markTitle` auch ohne `fields.title`): nutzt den
   vorhandenen Schutz, legt aber eine Revision ohne Änderung an, zählt als „Zuletzt von Claude“ und als Nutzerwert für die
   Wiedererkennung (#244) — Nebenwirkungen, die nichts mit dem Fehler zu tun haben. Wirkt nicht auf schon gespeicherte Aufgaben.
2. **Claude-Aufgaben gar nicht ans Modell geben** (wie Unteraufgaben, #565): einfacher, aber die Dauer vom Modell fiele weg —
   widerspricht der DoD („übrige Ableitungen bleiben“).
3. **Auch `TitleRule` für Claude abschalten** („kommt an, wie geschrieben“ wörtlich): würde Datumswörter im Titel lassen und
   nach 12 Wörtern nicht kürzen. Nicht Teil der Meldung (Henning nennt „von der AI bearbeitet“); die Regel gilt für jeden
   Kanal gleich, und Claude kann mit `fields.title` den Wortlaut ohnehin festlegen. Bleibt außen vor.
Keine ADR fällt; die Regel „das Modell darf den Regeltitel verfeinern“ (#202) bekommt die Ausnahme Kanal Claude.

### Dependencies
`TaskItem.capturedVia` (vorhanden, `capturedViaRaw`), `EnrichmentCoordinator` ruft den Writer unverändert.
Restrisiko: ein Gerät mit älterem Bau (Mac per iCloud) kann eine Claude-Aufgabe zuerst anreichern, bis alle Geräte den
neuen Bau haben.

### Open Questions
- keine
