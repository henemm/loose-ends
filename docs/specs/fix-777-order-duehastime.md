---
entity_id: fix-777-order-duehastime
type: bugfix
created: 2026-11-02
updated: 2026-11-02
status: draft
workflow: fix-777-order-duehastime
---

# Spec: #777 — `setDue` aus Claude ändert `dueHasTime` nie ohne Revision

## Approval

- [ ] Approved (Henning)

## Purpose

Der Auftragsweg aus Claude (`OrderExecutor`, Epic #612, Refs #613) soll keine Änderung an einer Aufgabe zulassen, die keine
Revision hinterlässt („Revisions, not undo“). Das Ticket nennt zwei Teile:

- **Teil 2 (`setDue` prüft den Status nicht): erledigt** in PR #791 (C3a). `OrderExecutor.setDue` prüft
  `completable.contains(task.status)`; `OrderExecutorTests` AC-19 bis AC-21 belegen es. Dafür gibt es hier keine Arbeit; das
  Ticket bekommt einen Kommentar mit Verweis.
- **Teil 1 (F003): offen, Gegenstand dieser Spec.** `setDue` schreibt `task.dueHasTime = stored != nil && hasTime` auch dann,
  wenn `RevisionService.set(.dueDate, …)` nil liefert, weil der neue gespeicherte Zeitpunkt in ganzen Sekunden dem alten gleicht.
  Dann wechselt `dueHasTime`, ohne dass eine Revision entsteht. `dueHasTime` gehört nicht zum erwarteten Stand des Auftrags
  (`Order` hat kein `expectedHasTime`) und ist kein Revisionsfeld (`FieldCodec` kodiert unter `.dueDate` nur das Datum).

**Hat es bisher funktioniert?** Der Fall ist nie behandelt worden; er steckt seit C2/C3a im Auftragsweg und ist als „Bekannte
Grenze von Version 1“ im Vertrag vermerkt. Nichts in der App ruft `OrderExecutor` auf (nur Tests), das Produkt ist nicht betroffen.

### Root Cause

`OrderExecutor.setDue` (`Shared/Services/OrderExecutor.swift`, Zeilen 75–89): `stored` ist `date` selbst (mit Uhrzeit) oder
`calendar.startOfDay(for: date)` (ohne). Fällt `stored` auf den Zeitpunkt, den die Aufgabe schon hat, vergleicht
`RevisionService.set` die Sekunden-Texte, findet keinen Unterschied und gibt nil zurück. Zeile 86 setzt `dueHasTime`
trotzdem. Das passiert nur um Mitternacht: nur dort fallen „Tagesbeginn ohne Uhrzeit“ und „00:00 mit Uhrzeit“ auf denselben
Zeitpunkt. Beispiel: Aufgabe fällig 00:00 mit Uhrzeit (`dueHasTime` true), Auftrag `setDue` mit genau diesem Datum und
`hasTime` false → Datum gleich, `dueHasTime` wird false, keine Revision.

### Recherche und Regelweg

Interne Frage am eigenen Vertrag, keine Apple-Schnittstelle und kein Modell: kein Suchbedarf im Netz, die Ursache liegt in
Zeile 86 und im Vertragstext (Abschnitt „Bekannte Grenze“). Regelweg (Regeln vor Modell): eine Prüfung vor dem ersten Schreiben.
Die Ablehnung vor dem Schreiben ist das Muster aller anderen Gründe in `OrderExecutor` (`refuse`).

## Source

- **Geändert:** `Shared/Services/OrderExecutor.swift` (`setDue`)
- **Geändert:** `LooseEndsTests/OrderExecutorTests.swift` (neue Tests im selben Stil, Swift Testing)
- **Geändert:** `docs/reference/claude-abschrift-vertrag.md` (Absatz „Bekannte Grenze von Version 1“ und Bedeutung von `invalid`)
- **Unverändert, geprüft:** `Shared/Services/TaskActions.swift` (App-Weg `setDue` hat dieselbe Form; bewusst nicht Teil des
  Tickets), `Shared/Services/FieldCodec.swift`, `Shared/Models` (kein Schema), `server/` (kennt nur die Form des Auftrags)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Services/OrderExecutor.swift` | MODIFY | `setDue`: vor dem ersten Schreiben `invalid`, wenn `stored` nicht nil, `same(stored, task.dueDate)` und `task.dueHasTime != hasTime` |
| `LooseEndsTests/OrderExecutorTests.swift` | MODIFY | Mitternacht mit/ohne Uhrzeit → `invalid` mit unverändertem `Snapshot`; Gegenproben |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | „Bekannte Grenze“ durch die Regel ersetzen; `invalid` um den Fall ergänzen; Version bleibt 1 |

Drei Dateien, geschätzt **+~45 / −~4 LoC**. Innerhalb der Scoping-Limits.

**Geräteliste berührt:** nein. Kein Pfad der Geräteliste berührt. Abnahme endet nach Stufe 2.

**Side-Effects:** Keine Änderung an Info.plist, Entitlements, `project.yml`, AppStorage-Schlüsseln, Datenmodell, CloudKit-Schema,
Texten oder Katalogen. Ein neuer `OrderResult.Reason` entsteht nicht; der Vertrag bleibt Version 1. Die Vertragsbeispiele
(`documentCarriesFixtures`) bleiben unberührt, weil nur Fließtext geändert wird.

### Nicht in diesem Ticket

- `TaskActions.setDue` (App-Weg) hat dieselbe Lücke. Eigenes Ticket nur auf Wunsch; Drive-by-Änderungen gibt es nicht.
- Teil 2 des Tickets (Statusprüfung): bereits ausgeliefert, nur Kommentar und Schließen beim Merge.
- Kein `expectedHasTime` im Auftrag, keine Vertragsversion 2.

## Implementation Details

In `OrderExecutor.setDue`, nach der Fälligkeits-Prüfung (`same(order.expectedDueDate, task.dueDate)`) und vor `RevisionService.set`:

```swift
// The same instant with another `hasTime` could only change `dueHasTime`, which is no revision field.
if let stored, same(stored, task.dueDate), task.dueHasTime != hasTime { return refuse(order, .invalid, task: id) }
```

`stored` wird dafür vor der Prüfung berechnet (Zeile 81 rückt nach oben). Gleicher Zeitpunkt mit gleichem `hasTime` bleibt wie
heute `done` ohne Änderung und ohne Revision. Entfernen (`date` nil) ändert `dueHasTime` nicht und ist nicht betroffen
(`stored` nil). Ablehnung ohne Schreiben, also bleibt der Speicher wie er war.

### Vertrag

„Bekannte Grenze von Version 1“ wird ersetzt durch: Ein `setDue`, das denselben Zeitpunkt träfe und nur `hasTime` ändern würde
(möglich nur um Mitternacht), wird als `invalid` abgelehnt, weil `dueHasTime` kein Revisionsfeld ist und die Änderung sonst ohne
Revision geschähe. Bei `invalid` (Zeile „falsche Version, ein Pflichtfeld fehlt …“) kommt dieser Fall hinzu.

## Expected Behavior

- **Input:** `setDue` mit `date` = heutiger Fälligkeit der Aufgabe (Mitternacht, in ganzen Sekunden gleich) und abweichendem `hasTime`.
- **Output:** `OrderResult(outcome: .rejected, reason: .invalid, taskID: …)`; Speicher unverändert (`Snapshot` gleich).
- **Gegenproben (unverändert):** gleicher Zeitpunkt, gleiches `hasTime` → `done`, keine Revision; anderer Zeitpunkt → `done`
  mit einer Revision, auch wenn `hasTime` wechselt; Entfernen → `done`.
- **Side effects:** keine.

## Test Plan

### Automated Tests (TDD RED zuerst)

`LooseEndsTests/OrderExecutorTests.swift` nutzt **Swift Testing**. Das QA-Gate zählt nur XCTest-Zeilen; Beleg ist der volle Lauf
`./scripts/sim.sh sim-unit`, der Einzellauf `sim-unit OrderExecutorTests` dient der schnellen Rückmeldung.

- `setDueSameInstantOtherHasTimeIsInvalid` (`arguments: [(true, false), (false, true)]`): Aufgabe fällig um Mitternacht
  (`startOfDay`) mit `dueHasTime` gesetzt; Auftrag gleicher Zeitpunkt, anderes `hasTime`, `expectedDueDate` = Fälligkeit →
  `.rejected/.invalid`, `Snapshot` gleich, `dueHasTime` unverändert.
- `setDueSameInstantSameHasTimeChangesNothing`: gleicher Zeitpunkt, gleiches `hasTime` → `.done`, keine neue Revision.
- `setDueOtherInstantMayChangeHasTime`: neuer Tag mit anderem `hasTime` → `.done`, eine Revision, `dueHasTime` entsprechend.

**RED vor der Änderung:** der erste Test schlägt fehl (heute `.done`, `dueHasTime` gewechselt, keine Revision).

### Abnahme (Stufen)

1. **Tests:** voller `./scripts/sim.sh sim-unit` grün; neue Tests vorher rot.
2. **Simulator:** Kein sichtbarer Ablauf der App ändert sich; `OrderExecutor` wird von der App nicht aufgerufen. Beleg ist der
   Unit-Lauf im Simulator, im Abschlussbericht benannt. Es gibt keinen Bedienablauf, der durchzuspielen wäre.
3. **Gerät:** keine. Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given eine offene Aufgabe, fällig um Mitternacht mit `dueHasTime` = true, / When ein `setDue` mit genau diesem Datum,
  `hasTime` = false und passendem `expectedDueDate` ausgeführt wird, / Then ist das Ergebnis `rejected` mit Grund `invalid` und
  dem `taskID`, und `Snapshot` (Aufgaben, Revisionen, Abschlüsse, Felder inkl. `dueHasTime`) ist gleich dem Stand davor.
  - Test: LooseEndsTests/OrderExecutorTests.swift::setDueSameInstantOtherHasTimeIsInvalid
- **AC-2:** Given dieselbe Lage in Gegenrichtung (Fälligkeit um Mitternacht, `dueHasTime` = false, Auftrag `hasTime` = true) /
  When ausgeführt / Then ebenso `invalid` und unveränderter Speicher.
  - Test: LooseEndsTests/OrderExecutorTests.swift::setDueSameInstantOtherHasTimeIsInvalid
- **AC-3:** Given gleicher Zeitpunkt und gleiches `hasTime` / When ausgeführt / Then `done`, keine neue Revision, Felder unverändert
  (Verhalten wie heute).
  - Test: LooseEndsTests/OrderExecutorTests.swift::setDueSameInstantSameHasTimeChangesNothing
- **AC-4:** Given ein anderer Zeitpunkt als der alte, mit wechselndem `hasTime` / When ausgeführt / Then `done`, genau eine
  `dueDate`-Revision mit Grund „Claude“ und `dueHasTime` wie im Auftrag; bestehende Tests `setDueDayOnly`, `setDueWithTime`,
  `setDueRemoves`, `setDueStale`, AC-19 bis AC-21 bleiben grün.
  - Test: LooseEndsTests/OrderExecutorTests.swift::setDueOtherInstantMayChangeHasTime
- **AC-5:** Given der Diff / When er geprüft wird / Then berührt er nur `OrderExecutor.swift`, `OrderExecutorTests.swift` und
  `claude-abschrift-vertrag.md`; der Vertrag nennt die Regel statt der „Bekannten Grenze“, bleibt Version 1, und der volle
  `sim-unit`-Lauf (inklusive `documentCarriesFixtures`) ist grün.
  - Test: voller Lauf `./scripts/sim.sh sim-unit`

## Dependencies

| Komponente | Beschreibung |
|---|---|
| `RevisionService.set` | liefert nil bei gleichem Wert; Auslöser des Falls |
| `OrderExecutor.same(_:_:)` | Sekundenvergleich |
| `Snapshot` (Test) | vorhanden |

Keine neue Abhängigkeit.

## Risiken

- **Echter Auftrag wird abgelehnt (sehr niedrig):** nur wenn Claude um Mitternacht den bestehenden Zeitpunkt mit anderem
  `hasTime` setzt. Die Ablehnung ist ehrlich und sichtbar; kein Nutzerverlust, und nichts in der App ruft den Weg auf.
- **Uneinheitlich zum App-Weg (niedrig, benannt):** `TaskActions.setDue` bleibt vorerst bei der Lücke.

## Alternativen

- **A: `expectedHasTime` im Auftrag, Vertragsversion 2.** Sauberer Stand, aber Formänderung in Dienst und Vertrag für einen Fall,
  der nur um Mitternacht auftritt. Nur bei echtem Bedarf. Gekippt würde dafür „Version 1 bleibt“ aus C3a/C3b.
- **B: Still `done` ohne Änderung.** Verworfen: meldet ein Ergebnis, das nicht eintrat.
- **C: `dueHasTime` als Revisionsfeld.** Verworfen: Modell- und CloudKit-Schemaänderung, additiv zwar möglich, aber unverhältnismäßig.
- **D: `dueHasTime` trotzdem setzen und einen Revisionseintrag erzwingen.** Verworfen: `FieldCodec` kodiert nur das Datum; die
  Revision wäre inhaltsleer (alt = neu).
- **Kein Modell:** Es ist eine deterministische Prüfung; die Frage nach dem Modell stellt sich nicht.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Fehlerbehebung in einem Randfall, Vertrag bleibt Version 1, keine Architekturentscheidung
- **Rationale:** Ablehnung vor dem ersten Schreiben ist das bestehende Muster des Auftragswegs.

## Known Limitations

- `TaskActions.setDue` (App-Weg) ändert `dueHasTime` in demselben Fall weiter ohne Revision.
- Ein Auftrag, der um Mitternacht nur `hasTime` umschalten will, ist nicht möglich; er muss einen anderen Zeitpunkt wählen.

## Definition of Done

- [ ] AC-1 bis AC-5 erfüllt; neue Tests vorher rot, danach grün; voller `sim-unit`-Lauf grün.
- [ ] Vertrag aktualisiert, Version 1.
- [ ] Kein Pfad der Geräteliste berührt; Abnahme endet nach Stufe 2, im Abschlussbericht mit genau diesem Satz.
- [ ] PR verweist mit `Closes #777`; Ticket-Kommentar nennt Teil 2 als mit PR #791 erledigt.
- [ ] Abschlussbericht ohne Git-Vokabular: Der Auftragsweg aus Claude lehnt den einen Randfall (Mitternacht, nur Uhrzeit-Kennzeichen
  ändern) jetzt ab, statt still etwas ohne Spur zu ändern; im Produkt ist nichts sichtbar, Henning muss nichts tun.

## Changelog

- 2026-11-02: Initiale Spec für #777 Teil 1: Ablehnung als `invalid` vor dem ersten Schreiben; Alternative `expectedHasTime` /
  Vertragsversion 2 verworfen.
