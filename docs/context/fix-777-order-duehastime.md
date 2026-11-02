# Context: fix-777-order-duehastime

## Request Summary
#777 (Epic #612, Refs #613): Der Auftragsweg aus Claude (`OrderExecutor`) lässt keine Änderung ohne Revision zu.
Das Ticket nennt zwei Teile; Teil 2 ist schon erledigt, übrig bleibt Teil 1.

## Stand der beiden Teile
- **Teil 2 (`setDue` prüft den Status nicht): erledigt** in PR #791 (C3a). `OrderExecutor.setDue` prüft
  `completable.contains(task.status)` (Zeile 78), Tests `OrderExecutorTests` AC-19 (erledigt/entfernt → `stale`),
  AC-20, AC-21 (geparkt geht). Im Ticket mit Verweis zu schließen, keine Arbeit.
- **Teil 1 (F003): offen.** `setDue` schreibt `task.dueHasTime = stored != nil && hasTime` (Zeile 86) auch dann,
  wenn `RevisionService.set(.dueDate…)` nil liefert (gleicher Zeitpunkt in ganzen Sekunden). Dann wechselt
  `dueHasTime` ohne Revision. `dueHasTime` gehört nicht zum erwarteten Stand (`Order` hat kein `expectedHasTime`).

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Services/OrderExecutor.swift` | `setDue` (Z. 75–89): hier entsteht der Fall |
| `LooseEndsTests/OrderExecutorTests.swift` | Swift-Testing-Suite; Muster `setDueDayOnly`, `setDueWithTime`, `Snapshot` für „nichts geändert“ |
| `docs/reference/claude-abschrift-vertrag.md` | Z. 99–100 „Bekannte Grenze von Version 1“; Z. 130 Bedeutung von `invalid` |
| `Shared/Services/TaskActions.swift` | `setDue` (Z. 192): dieselbe Form, auch dort ohne Revision für `dueHasTime`; App-Weg, nicht Teil des Tickets |
| `Shared/Services/FieldCodec.swift` | `.dueDate` kodiert nur das Datum (Z. 13, 46–49); `dueHasTime` ist kein Revisionsfeld |

## Existing Patterns
- Jede Ablehnung prüft vor dem ersten Schreiben (`refuse(order, reason, task:)`), Test mit `Snapshot` gleich vorher/nachher.
- `OrderResult.Reason`: `invalid`, `stale`, `missing`. Neuer Grund würde den Vertrag ändern, ein bestehender nicht.
- Vertragsbeispiele sind im Dokument wörtlich und werden vom Test `documentCarriesFixtures` gegen die Fixtures geprüft;
  eine Änderung am Fließtext berührt sie nicht.

## Dependencies
- Upstream: `RevisionService.set`, `calendar.startOfDay`, `same(_:_:)` (Sekundenvergleich).
- Downstream: nichts in der App ruft `OrderExecutor` auf (nur Tests); der Dienst (`server/`) kennt nur die Form des Auftrags.

## Weg
Empfehlung: Vor dem ersten Schreiben ablehnen als `invalid`, wenn der neue gespeicherte Zeitpunkt dem alten entspricht
und `dueHasTime` sich dadurch änderte. Vertrag bleibt Version 1, Absatz „Bekannte Grenze“ wird durch die Regel ersetzt.
Alternative: `expectedHasTime` im Auftrag, Vertragsversion 2 (größer, nur bei echtem Bedarf; Fall tritt nur bei Mitternacht auf,
denn nur dort fallen „Tagesbeginn“ und „00:00 mit Uhrzeit“ auf denselben Zeitpunkt).
Verworfen: still `done` melden ohne Änderung (lügt über das Ergebnis); `dueHasTime` als Revisionsfeld (Modell- und Schemaänderung).

## Risks & Considerations
- Gleicher Zeitpunkt, gleiches `hasTime`: bleibt eine Auftragsausführung ohne Änderung und ohne Revision, wie heute (`done`).
- Ablehnung gilt auch, wenn nur `date` nil ist? Nein: Entfernen ohne Fälligkeit ändert `dueHasTime` nicht (bleibt false).
- Der App-Weg `TaskActions.setDue` hat dieselbe Lücke; bewusst nicht Teil dieses Tickets (Scoping, kein Drive-by).

## Analysis

### Type
Bug (Teil 1 von #777; Teil 2 ist mit PR #791 erledigt, Ticket-Kommentar und Schließen beim Merge)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Services/OrderExecutor.swift` | MODIFY | `setDue`: vor dem ersten Schreiben `invalid`, wenn gespeicherter Zeitpunkt gleich dem alten ist und `dueHasTime` sich dadurch ändern würde |
| `LooseEndsTests/OrderExecutorTests.swift` | MODIFY | Test: Mitternacht mit/ohne Uhrzeit → `invalid`, `Snapshot` gleich; Gegenprobe gleiches `hasTime` → `done` ohne Revision |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Absatz „Bekannte Grenze von Version 1“ durch die Regel ersetzen; Version bleibt 1 |

### Scope Assessment
- Files: 3
- Estimated LoC: +45/-4
- Risk Level: LOW (nichts in der App ruft `OrderExecutor` auf)

### Technical Approach
Rule-based, kein Modell. Bedingung: `stored != nil`, `same(stored, task.dueDate)` und `task.dueHasTime != hasTime` → `refuse(order, .invalid)`.
Fall tritt nur um Mitternacht auf (Tagesbeginn = 00:00 mit Uhrzeit). Alternative: `expectedHasTime` im Auftrag, Vertragsversion 2 (größer, nur bei echtem Bedarf).
Verworfen: still `done` ohne Änderung; `dueHasTime` als Revisionsfeld (Schemaänderung).

### Dependencies
`RevisionService.set`, `same(_:_:)`, `Snapshot` im Test. App-Weg `TaskActions.setDue` hat dieselbe Lücke, bewusst nicht Teil dieses Tickets.

### Open Questions
- [ ] Keine. (Optional später: eigenes Ticket für `TaskActions.setDue`.)
