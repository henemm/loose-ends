---
entity_id: feat-950-titel-getippt
type: feature
created: 2026-11-20
updated: 2026-11-20
status: draft
workflow: feat-950-titel-getippt
---

# Spec: Getippte Aufgaben behalten ihren Titel (Feature #950)

## Approval

- [ ] Approved

## GitHub Issue

#950 (Henning: „Bearbeitung des Titels fallweise deaktivieren — Kommen neue Aufgaben über die Claudeapp oder werden Sie per Tastatur eingegeben, sollen sie nicht von der AI interpretiert und überarbeitet werden.“). Analyse: `docs/context/feat-950-titel-getippt.md` (Abschnitt „Analysis“). Der Claude-Teil ist mit #953 erledigt; dieser Schnitt schließt den Tastatur-Weg.

## Purpose

Wer eine Aufgabe selbst tippt, hat sie schon formuliert; heute darf das On-Device-Modell die Überschrift trotzdem verfeinern, weil die App getippte und gesprochene Erfassung beide als Kanal `.app` speichert. Getippte Aufgaben bekommen einen eigenen Kanal `.keyboard`, und der Writer lässt dem Modell bei diesem Kanal (wie bei Claude) den Titel.

**Regeln vor Modell:** Es kommt kein Modellaufruf hinzu, dem Modell wird ein Feld abgenommen. Die Unterscheidung getippt/gesprochen ist eine Regel am Kanal, kein Modellurteil. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- `TitleRule` bleibt für alle Kanäle aktiv (Datumswörter säubern, höchstens 12 Wörter), wie bei #953.
- Teilen und Mail (`.share`, `.mail`), Watch und Siri bleiben beim Modell: der Text kommt aus einer anderen App oder ist gesprochen.
- Teilschritte (`Subtasks.add`, #565) bleiben unberührt, das Modell sieht sie nie.
- Keine Migration bestehender `.app`-Aufgaben, keine CloudKit-Schemaänderung (`CD_capturedViaRaw` ist ein `STRING`).
- `LooseEnds/Speech/`, `EnrichmentCoordinator.swift` und der Dienst (`server/`) bleiben unverändert.
- Alle anderen Felder (Dauer, Energie, Regelfelder) laufen wie bisher.

## Entscheidungen zur Abgrenzung

- **Gemischt zählt als gesprochen:** Hat beim Zuhören ein nicht-leeres Sprachergebnis das Feld erreicht, bleibt der Kanal `.app`, auch wenn danach per Tastatur korrigiert wurde. Das Modell darf dann Erkennungsfehler glätten.
- **Diktat über die iOS-Tastatur** ist von Tippen nicht unterscheidbar und zählt als getippt.
- **Nur `.app` wird zu `.keyboard`:** Ein anderer übergebener Kanal (z. B. `.share`) bleibt, wie er ist.

## Alternativen

1. **Merker `titleLocked` am Task** statt Kanal: trennt Absicht vom Kanal und ließe sich für weitere Quellen nutzen, kostet aber eine CloudKit-Schemaänderung samt Production-Deploy, und ältere Builds ignorieren ihn. Verworfen: zu viel für das Ziel.
2. **Modell für getippte Aufgaben ganz aus** (wie Teilschritte, #565): dann setzt das Modell auch Dauer und Energie nicht mehr. Geht über den Wortlaut des Issues hinaus (nur „Titel“). Verworfen.
3. **Auch `TitleRule` für getippt aus:** bei #953 bewusst nicht gemacht; bleibt konsistent aus. Wer den Wortlaut exakt festlegen will, kürzt selbst.

Gewählt: neuer Kanal plus Regel `keepsWording`. Der Kanal steht dauerhaft am Task und gilt damit für den Erstlauf, „Erneut analysieren“ und noch nicht angereicherte Aufgaben.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR. Die Regel „das Modell darf den Regeltitel verfeinern“ (#202) hat seit #953 die Ausnahme Kanal Claude und bekommt den Kanal Tastatur dazu; keine bestehende ADR fällt.
- **Rationale:** Ein neuer String-Rohwert im vorhandenen Kanalfeld und eine Bedingung in einer reinen Funktion, kein Schemawechsel, Revisions-Prinzip unberührt.

## Source

- **File:** `Shared/Enrichment/EnrichmentWriter.swift`
- **Identifier:** `EnrichmentWriter.apply` (Titelblock, `let fromClaude = task.capturedVia == .claude`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `CaptureChannel` (`Shared/Models/Enums.swift`) | module | Bekommt `.keyboard`, `keepsWording` und `forTyping(heard:)` |
| `TaskItem.capturedVia` (`capturedViaRaw`) | module | Kanal dauerhaft am Task; unbekannter Rohwert liest sich als `.app` |
| `CaptureService.save(_:via:)` | module | Einziger Schreibweg, setzt den Regeltitel (unverändert) |
| `SpeechCapture` (`transcript`, `isListening`) | module | Quelle für „wurde gesprochen“ in `CaptureView` (unverändert) |
| `EnrichmentCoordinator` | module | Ruft `EnrichmentWriter.apply` im Erstlauf und bei `reanalyze` (unverändert) |
| `TitleRule` | module | Regeltitel bei der Erfassung (unverändert) |
| `StubEnricher` | test | Ersetzt das Modell in den Unit-Tests |
| `ModelOffEnricher` (`LooseEndsApp.swift`) | app | Unter `--ui-testing` ist das Modell aus; UI-Tests belegen die Kette bis zum gespeicherten Titel, nicht die Verfeinerung |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Models/Enums.swift` | MODIFY | `CaptureChannel.keyboard`; `keepsWording` (true für `.claude`, `.keyboard`); `forTyping(heard:)` (`.app` ohne Gehörtes → `.keyboard`, sonst unverändert) |
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | `fromClaude` wird `task.capturedVia.keepsWording`; Statushebung `unprocessed`/`unverified` → `active` bleibt wie bei #953 |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | `@State heard`: wahr, sobald beim Zuhören ein nicht-leeres Transkript in `text` landet (Guard `!transcript.isEmpty`); `save()` übergibt `channel.forTyping(heard: heard)` (Sheet iPhone/iPad, Mac-Fenster, Menüleisten-Panel) |
| `LooseEnds/Views/InboxDrawerView.swift` | MODIFY | Schreibzeile unter „Neu“ speichert `.keyboard` statt `.app` (Zeile 176) |
| `CLAUDE.md` | MODIFY | Halbsatz an „Rules before the model“: der Titel einer getippten Aufgabe (`capturedVia == .keyboard`) gehört nie dem Modell (#950) |
| `LooseEndsTests/KeyboardTitleTests.swift` | CREATE | XCTest nach Muster `ClaudeTitleTests` |
| `LooseEndsUITests/CaptureSmokeTests.swift` | MODIFY | Ein Smoke-Test: im Sheet getippt, Titel in der Detailansicht ist der eigene Wortlaut |
| `LooseEndsUITests/InboxDrawerSmokeTests.swift` | MODIFY | Ein Smoke-Test: in der Schreibzeile getippt, Titel bleibt der eigene Wortlaut |

### Estimated Changes

- Files: 5 Produktiv und Doku (`Enums.swift`, `EnrichmentWriter.swift`, `CaptureView.swift`, `InboxDrawerView.swift`, `CLAUDE.md`), dazu 3 Testdateien
- LoC: +~190/-~4 (davon ~15 Produktiv, ~170 Test)

Stufe 3: Kein Pfad der Geräteliste berührt (`EnrichmentWriter.swift`, `Enums.swift` und die Views stehen nicht auf der Liste, `LooseEnds/Speech/` bleibt unverändert).

## Implementation Details

`CaptureChannel` bekommt den Fall `keyboard` (Rohwert `"keyboard"`). Ältere Builds lesen einen unbekannten Rohwert über den bestehenden Rückfall in `TaskItem.capturedVia` als `.app`. `keepsWording` ist `true` für `.claude` und `.keyboard`. `forTyping(heard:)` liefert `.keyboard`, wenn der Kanal `.app` ist und nichts gehört wurde, sonst den Kanal selbst.

Im Titelblock von `EnrichmentWriter.apply` ersetzt `task.capturedVia.keepsWording` die Prüfung auf `.claude`; Erstlauf, „Erneut analysieren“ und die Statushebung laufen wie bei #953 (der Zweig für Aufgaben mit festem Wortlaut hebt `unprocessed`/`unverified` auf `active`, sobald ein Titel steht).

In `CaptureView` merkt sich `@State heard` ein nicht-leeres Transkript: `onChange(of: speech.transcript)` setzt `heard = true`, wenn `speech.isListening` und das Transkript nicht leer ist. Der Wechsel nicht-leer → leer löst `onChange` ebenfalls aus; der Guard verhindert, dass er etwas ändert. `save()` ruft `CaptureService.save(text, via: channel.forTyping(heard: heard), …)` auf. Die Schreibzeile in `InboxDrawerView` kennt kein Mikrofon und übergibt `.keyboard` direkt.

Restrisiko: Ein Gerät mit älterem Bau (Mac/iPad per iCloud) liest `.keyboard` als `.app` und kann eine getippte Aufgabe zuerst anreichern und den Titel verfeinern, bis alle Geräte den neuen Bau haben.

## Test Plan

### Automated Tests (TDD RED)

Unit-Tests in `LooseEndsTests/KeyboardTitleTests.swift` (XCTest), Lauf mit `./scripts/sim.sh sim-unit KeyboardTitleTests`. Die Kette läuft wie auf dem Gerät: `CaptureService.save` legt die Aufgabe an, `EnrichmentCoordinator` reichert sie an, nur das Modell ist der `StubEnricher`.

- [ ] Test 1: GIVEN eine mit `via: .keyboard` gespeicherte Aufgabe und ein Stub-Modell mit verkürztem Titel (Konfidenz 0,9) WHEN `processPending` läuft THEN bleibt `task.title` der Regeltitel und es gibt keine Titel-Revision mit Autor `.ai`.
- [ ] Test 2: GIVEN dieselbe Aufgabe nach dem Erstlauf WHEN „Erneut analysieren“ (`reanalyze`) mit demselben Stub läuft THEN bleibt `task.title` unverändert.
- [ ] Test 3: GIVEN eine `.keyboard`-Aufgabe mit Status `unprocessed` WHEN der Writer das Modellergebnis anwendet THEN steht der Status auf `active`, nicht `unverified`.
- [ ] Test 4: GIVEN ein Stub-Modell, das Titel und Dauer liefert, und eine `.keyboard`-Aufgabe ohne Dauer WHEN die Anreicherung läuft THEN setzt das Modell die Dauer, der Titel bleibt.
- [ ] Test 5 (Gegenprobe): GIVEN Aufgaben mit Kanal `.app` und `.watch` und demselben Stub WHEN die Anreicherung läuft THEN wird der Titel weiter vom Modell verfeinert.
- [ ] Test 6: GIVEN eine per `OrderExecutor` angelegte Claude-Aufgabe WHEN die Anreicherung läuft THEN bleibt ihr Titel unverändert (Verhalten aus #953 unberührt).
- [ ] Test 7: GIVEN der Rohwert `"keyboard"` WHEN er an einem `TaskItem` gespeichert und gelesen wird THEN ist `capturedVia == .keyboard`; GIVEN ein unbekannter Rohwert THEN liest er sich als `.app`.
- [ ] Test 8: GIVEN `forTyping(heard:)` WHEN Kanal `.app` und nichts gehört THEN `.keyboard`; WHEN Kanal `.app` und gehört THEN `.app`; WHEN Kanal `.share` und nichts gehört THEN `.share`.

UI-Smoke-Tests (XCUITest, Lauf mit `./scripts/sim.sh test-proof CaptureSmokeTests` und `./scripts/sim.sh test-proof InboxDrawerSmokeTests`). Unter `--ui-testing` ist das Modell aus (`ModelOffEnricher`) und der Kanal ist in der Oberfläche nicht sichtbar; die Tests belegen deshalb den echten Erfassungsweg bis zur gespeicherten Aufgabe mit unverändertem Wortlaut, der Kanal selbst ist durch Test 8 und die Kette in Test 1 bis 4 belegt.

- [ ] Test 9: GIVEN die App unter `--ui-testing` WHEN im Erfassungssheet ein Satz ohne Datums-, Wichtigkeits- und Kontextwörter getippt und gesichert wird THEN zeigt die Detailansicht der Aufgabe diesen Satz als Titel.
- [ ] Test 10: GIVEN die App unter `--ui-testing` WHEN in der Schreibzeile unter „Neu“ derselbe Satz getippt und mit Return gesichert wird THEN steht die Aufgabe mit diesem Wortlaut als Titel in der Liste dieser Sitzung.

## Acceptance Criteria

- **AC-1:** Eine mit Kanal `.keyboard` gespeicherte Aufgabe behält nach dem Erstlauf der Anreicherung ihren Regeltitel; das Modell schreibt keine Titel-Revision (Test 1).
- **AC-2:** Bei „Erneut analysieren“ einer `.keyboard`-Aufgabe bleibt der Titel unverändert (Test 2).
- **AC-3:** Eine `.keyboard`-Aufgabe endet nach der Anreicherung mit Status `active`, nie hängend in `unverified` (Test 3).
- **AC-4:** Die vom Modell gelieferte Dauer und die Regelfelder werden bei `.keyboard`-Aufgaben weiter gesetzt (Test 4).
- **AC-5:** Gegenprobe: Aufgaben mit Kanal `.app` und `.watch` werden weiter vom Modell verfeinert; das Verhalten für `.claude` bleibt unverändert (Tests 5 und 6).
- **AC-6:** `CaptureChannel.keyboard` hat den Rohwert `"keyboard"`; ein unbekannter Rohwert liest sich als `.app` (Test 7).
- **AC-7:** `forTyping(heard:)` macht aus `.app` ohne Gehörtes `.keyboard`, lässt `.app` mit Gehörtem und jeden anderen Kanal unverändert (Test 8).
- **AC-8:** Im Erfassungssheet getippte Aufgaben und Aufgaben aus der Schreibzeile unter „Neu“ werden gespeichert und behalten im Simulator ihren eigenen Wortlaut als Titel (Tests 9 und 10).

## Definition of Done

- [ ] Build grün (`./scripts/sim.sh build`)
- [ ] `KeyboardTitleTests` (Tests 1–8) und alle übrigen Unit-Tests grün
- [ ] UI-Smoke-Tests 9 und 10 grün; Simulatorbeleg registriert über `./scripts/sim.sh test-proof` (Sheet und Schreibzeile werden im Simulator durchgespielt)
- [ ] Halbsatz in `CLAUDE.md` an „Rules before the model“ gesetzt
- [ ] Ausgeliefert (PR mit `Closes #950`, CI grün, gemergt); Abschlussbericht mit „Kein Pfad der Geräteliste berührt.“ und dem Hinweis auf das Restrisiko älterer Builds

## Changelog

- 2026-11-20: Initial spec created
