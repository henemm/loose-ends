---
entity_id: bug-953-claude-titel
type: bugfix
created: 2026-11-19
updated: 2026-11-19
status: draft
workflow: fix-953-claude-titel
---

# Spec: Claude-Aufgaben behalten ihren Titel (Bug #953)

## Approval

- [ ] Approved

## GitHub Issue

#953 (Epic #612). Analyse: `docs/context/fix-953-claude-titel.md` (Abschnitt „Analysis“). Nachstellung: `docs/artifacts/fix-953-claude-titel/nachstellung.md`.

## Purpose

Eine Aufgabe, die Claude über `capture_task` ohne `fields.title` anlegt, bekommt heute vom On-Device-Modell eine neue Überschrift, weil der Titel nur über eine Nutzer-Revision vor dem Modell geschützt ist. Claude ist Eingabekanal (PO 2026-11-19): was Claude anlegt, ist schon formuliert, das Modell darf die Überschrift nicht ändern.

**Regeln vor Modell:** Es kommt kein Modellaufruf hinzu, im Gegenteil: dem Modell wird ein Feld abgenommen. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- `TitleRule` bleibt für alle Kanäle unverändert (Datumswörter säubern, höchstens 12 Wörter). Wer den Wortlaut exakt festlegen will, schickt `fields.title` (#932).
- Der Dienst (`server/`) und `EnrichmentCoordinator.swift` bleiben unverändert.
- Alle anderen Felder (Modell-Dauer, alle Regeln) laufen wie bisher.
- Keine Migration schon gespeicherter, bereits umgeschriebener Titel (die alten Titel sind nicht rekonstruierbar).

## Root Cause

`EnrichmentWriter.apply` (Titelblock) schützt den Titel nur über `userHasTouched(.title)`. `OrderExecutor.capture` schreibt eine Nutzer-Revision für den Titel nur mit `fields.title`; ohne steht der Regeltitel von `CaptureService` ohne Revision da, und das Modell ersetzt ihn im Erstlauf und bei „Erneut analysieren“. Der Kanal (`capturedVia == .claude`) wird in der Anreicherung nirgends gelesen. Belegt in der Nachstellung: „Angebot für die Gartenhütte bei Müller einholen“ wird zu „Angebot Gartenhütte einholen“ (Autor `.ai`).

## Alternativen

1. **Titel bei jeder Claude-Erfassung als Nutzer-Revision markieren** (`markTitle` auch ohne `fields.title`): nutzt den vorhandenen Schutz, legt aber eine Revision ohne Änderung an, zählt als „Zuletzt von Claude“ und als Nutzerwert für die Wiedererkennung (#244) und wirkt nicht auf schon gespeicherte Aufgaben. Verworfen.
2. **Claude-Aufgaben gar nicht ans Modell geben** (wie Unteraufgaben, #565): einfacher, aber die Dauer vom Modell fiele weg. Verworfen.
3. **Auch `TitleRule` für Claude abschalten** („kommt an, wie geschrieben“ wörtlich): nicht Teil der Meldung, und Claude kann mit `fields.title` den Wortlaut festlegen. Bleibt außen vor.

Gewählt: Kanalregel im Writer. Der Kanal ist am `TaskItem` dauerhaft gespeichert und gilt damit auch für „Erneut analysieren“ und für schon angelegte, noch nicht angereicherte Aufgaben.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR. Die Regel „das Modell darf den Regeltitel verfeinern“ (#202) bekommt die Ausnahme Kanal Claude; keine bestehende ADR fällt.
- **Rationale:** Eine Bedingung in einer reinen Funktion, kein Schemawechsel, Revisions-Prinzip unberührt.

## Source

- **File:** `Shared/Enrichment/EnrichmentWriter.swift`
- **Identifier:** `EnrichmentWriter.apply` (Titelblock)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `TaskItem.capturedVia` (`capturedViaRaw`) | module | Kanal der Erfassung, dauerhaft am Task gespeichert |
| `CaptureChannel.claude` | module | Unterscheidet Claude-Aufgaben von App-Aufgaben |
| `OrderExecutor.capture` | module | Legt die Aufgabe mit `via: .claude` an (unverändert) |
| `EnrichmentCoordinator` | module | Ruft `EnrichmentWriter.apply` im Erstlauf und bei `reanalyze` (unverändert) |
| `TitleRule` / `CaptureService` | module | Setzt den Regeltitel bei der Erfassung (unverändert) |
| `StubEnricher` | test | Ersetzt das Modell in den Tests |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | Titelblock: bei `task.capturedVia == .claude` schreibt das Modell keinen Titel (Erstlauf und Neuanalyse); Status wird wie bisher gehoben (`unprocessed`/`unverified` → `active`) |
| `LooseEndsTests/ClaudeTitleTests.swift` | CREATE | XCTest: Kette Auftrag → Anreicherung (Erstlauf, Neuanalyse), Status, Dauer vom Modell bleibt, Gegenprobe Kanal `.app` |
| `CLAUDE.md` | MODIFY | Halbsatz an „Rules before the model“: der Titel einer Claude-Aufgabe gehört nie dem Modell (#953) |

### Estimated Changes

- Files: 3
- LoC: +~90/-~3 (davon ~80 Test)

Stufe 3: Kein Pfad der Geräteliste berührt (`EnrichmentWriter.swift` steht nicht auf der Liste, `EnrichmentCoordinator.swift` bleibt unverändert).

## Implementation Details

Im Titelblock von `EnrichmentWriter.apply` darf das Modell den Titel nur schreiben, wenn `task.capturedVia != .claude`. Die bestehenden Bedingungen (Erstlauf ohne Nutzer-Revision, Neuanalyse nur bei Änderung ohne Nutzer-Revision, Regelfelder) bleiben daneben bestehen. Der Statuswechsel `unprocessed`/`unverified` → `active` hängt heute am Modelltitel; für Claude-Aufgaben wird er entkoppelt und läuft, sobald ein Titel steht, damit die Aufgabe nicht als `unverified` hängen bleibt. Das Modell darf weiterhin Dauer und die übrigen Felder liefern; Regeln laufen unverändert. Der Titel bleibt der Regeltitel (oder Claudes `fields.title`, geschützt durch die Nutzer-Revision wie bisher).

Restrisiko: Ein Gerät mit älterem Bau (Mac/iPad per iCloud) kann eine Claude-Aufgabe zuerst anreichern und den Titel umschreiben, bis alle Geräte den neuen Bau haben.

## Test Plan

### Automated Tests (TDD RED)

Alle in `LooseEndsTests/ClaudeTitleTests.swift` (XCTest), Lauf mit `./scripts/sim.sh sim-unit ClaudeTitleTests`.

- [ ] Test 1: GIVEN ein `capture`-Auftrag ohne `fields`, ausgeführt von `OrderExecutor`, und ein Stub-Modell mit verkürztem Titel (Konfidenz 0,9) WHEN `processPending` läuft THEN bleibt `task.title` der Regeltitel und es gibt keine Titel-Revision mit Autor `.ai`.
- [ ] Test 2: GIVEN dieselbe Aufgabe nach dem Erstlauf WHEN „Erneut analysieren“ (`reanalyze`) mit demselben Stub läuft THEN bleibt `task.title` unverändert.
- [ ] Test 3: GIVEN eine Claude-Aufgabe mit Status `unprocessed` WHEN der Writer das Modellergebnis anwendet THEN steht der Status auf `active`, nicht `unverified`.
- [ ] Test 4: GIVEN ein Stub-Modell, das Titel und Dauer liefert, und eine Claude-Aufgabe ohne Dauer WHEN die Anreicherung läuft THEN setzt das Modell die Dauer, der Titel bleibt.
- [ ] Test 5 (Gegenprobe): GIVEN eine Aufgabe mit Kanal `.app` und demselben Stub WHEN die Anreicherung läuft THEN wird der Titel weiter vom Modell verfeinert.
- [ ] Test 6: GIVEN ein `capture`-Auftrag mit `fields.title` WHEN die Anreicherung läuft THEN bleibt Claudes Titel (Nutzer-Revision, unverändert zu #932).

Zusätzlich: Simulatorbeleg (`./scripts/sim.sh test-proof` bzw. Nachstellungslauf mit Stub), dass der Ablauf aus `nachstellung.md` den Fehler nicht mehr zeigt.

## Acceptance Criteria

- **AC-1:** Eine per `capture` ohne `fields` angelegte Claude-Aufgabe behält nach dem Erstlauf der Anreicherung ihren Regeltitel; das Modell schreibt keine Titel-Revision (Test 1).
- **AC-2:** Bei „Erneut analysieren“ einer Claude-Aufgabe bleibt der Titel unverändert (Test 2).
- **AC-3:** Eine Claude-Aufgabe endet nach der Anreicherung mit Status `active`, nie hängend in `unverified` (Test 3).
- **AC-4:** Die vom Modell gelieferte Dauer (und die Regelfelder) werden bei Claude-Aufgaben weiter gesetzt (Test 4).
- **AC-5:** Gegenprobe: Eine aus der App erfasste Aufgabe (Kanal `.app`) wird weiter vom Modell verfeinert (Test 5).
- **AC-6:** Ein von Claude mit `fields.title` gesetzter Titel bleibt erhalten (Test 6).
- **AC-7:** Der Nachstellungslauf aus `docs/artifacts/fix-953-claude-titel/nachstellung.md` zeigt im Simulator den Fehler nicht mehr (Titel bleibt „Angebot für die Gartenhütte bei Müller einholen“, Erstlauf und Neuanalyse).

## Definition of Done

- [ ] Build grün (`./scripts/sim.sh build`)
- [ ] `ClaudeTitleTests` (Tests 1–6) und alle übrigen Unit-Tests grün
- [ ] Simulatorbeleg zu AC-7 registriert: Fehler vorher gezeigt (Nachstellung), nachher weg
- [ ] Halbsatz in `CLAUDE.md` an „Rules before the model“ gesetzt
- [ ] Ausgeliefert (PR mit `Closes #953`, CI grün, gemergt); Abschlussbericht mit „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-11-19: Initial spec created
