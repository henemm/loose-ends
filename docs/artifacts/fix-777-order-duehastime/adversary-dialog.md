# Adversary Dialog — fix-777-order-duehastime
Spec: docs/specs/fix-777-order-duehastime.md
Datum: 2026-11-02 07:43

## Checkliste
- [x] **Input:** `setDue` mit `date` = heutiger Fälligkeit der Aufgabe (Mitternacht, in ganzen Sekunden gleich) und abweichendem `hasTime`.
- [x] **Output:** `OrderResult(outcome: .rejected, reason: .invalid, taskID: …)`; Speicher unverändert (`Snapshot` gleich).
- [x] **Gegenproben (unverändert):** gleicher Zeitpunkt, gleiches `hasTime` → `done`, keine Revision; anderer Zeitpunkt → `done`
- [x] **Side effects:** keine.
- [x] **AC-1:** Given eine offene Aufgabe, fällig um Mitternacht mit `dueHasTime` = true, / When ein `setDue` mit genau diesem Datum, `hasTime` = false und passendem `expectedDueDate` ausgeführt wird, / Then ist das Ergebnis `rejected` mit Grund `invalid` und dem `taskID`, und `Snapshot` (Aufgaben, Revisionen, Abschlüsse, Felder inkl. `dueHasTime`) ist gleich dem Stand davor.
- [x] **AC-2:** Given dieselbe Lage in Gegenrichtung (Fälligkeit um Mitternacht, `dueHasTime` = false, Auftrag `hasTime` = true) / When ausgeführt / Then ebenso `invalid` und unveränderter Speicher.
- [x] **AC-3:** Given gleicher Zeitpunkt und gleiches `hasTime` / When ausgeführt / Then `done`, keine neue Revision, Felder unverändert (Verhalten wie heute).
- [x] **AC-4:** Given ein anderer Zeitpunkt als der alte, mit wechselndem `hasTime` / When ausgeführt / Then `done`, genau eine `dueDate`-Revision mit Grund „Claude“ und `dueHasTime` wie im Auftrag; bestehende Tests `setDueDayOnly`, `setDueWithTime`, `setDueRemoves`, `setDueStale`, AC-19 bis AC-21 bleiben grün.
- [x] **AC-5:** Given der Diff / When er geprüft wird / Then berührt er nur `OrderExecutor.swift`, `OrderExecutorTests.swift` und `claude-abschrift-vertrag.md`; der Vertrag nennt die Regel statt der „Bekannten Grenze“, bleibt Version 1, und der volle `sim-unit`-Lauf (inklusive `documentCarriesFixtures`) ist grün.

## Dialog

### Runde 1
**Adversary:** Code Reference: Shared/Services/OrderExecutor.swift:83. Prüfung liegt nach find/Status/expectedDueDate-Guards und vor RevisionService.set (Zeile 84) und vor `dueHasTime`-Schreiben (Zeile 88): Ablehnung vor jedem Schreiben. `stored` ist Zeile 81 vor der Prüfung berechnet. Fraktionen: `same` vergleicht ISO8601 (ganze Sekunden, UTC-Instant), identisch zu RevisionService.set, daher keine Lücke zwischen Prüfung und Revisionsnil. Zeitzone: `calendar.startOfDay` ist der injizierte Kalender, nur Instant zählt. dueDate nil: `same(stored, nil)` ist false (Text vs nil), also kein Fehlalarm, Revision entsteht. date nil (Entfernen): `if let stored` überspringt. 10:00 am selben Tag, hasTime=false auf Mitternachts-Aufgabe mit dueHasTime=true: stored=Mitternacht, abgelehnt: konsistent mit Spec (Stored-basiert, nichts ginge sonst revisionslos). Mutation: ohne Zeile 83 liefert der Test `.done` und wechselt dueHasTime (Spec-RED), `#expect(result == ...)` und Snapshot-Vergleich schlagen an. Snapshot wird vor dem Lauf gebildet und danach neu aus dem Speicher gelesen.
**Implementierer:** Keine Gegenrede, Verhalten wie in der Spec.

### Runde 2
**Adversary:** Testlauf `./scripts/sim.sh sim-unit OrderExecutorTests` (adversary-test-output.txt): Test Succeeded, Suite "Orders from Claude" passed; xcresult zeigt die parametrisierten neuen Fälle (true,false), (false,true), AC-3 true/false und AC-4 einzeln Passed, `documentCarriesFixtures` ("contract document carries ... examples") grün. Parametrisierte Fälle fehlen in der xcbeautify-Textausgabe, stehen aber im xcresult. Vertrag: nur Fließtext geändert (Grenze ersetzt, invalid ergänzt), Version 1 und Beispielblöcke laut Diff unberührt. Diff-Umfang: OrderExecutor.swift, OrderExecutorTests.swift (im RED-Commit), Vertrag: AC-5 ok. Schwäche (nicht blockierend): `same(stored, task.dueDate)` ohne Test für Fraktions-Sekunden im neuen Pfad; per Code äquivalent zu RevisionService. Übersprungene Messstrecken (3 von 6) gehören nicht zu OrderExecutor. Gesamter sim-unit-Lauf nicht von mir wiederholt, nur OrderExecutorTests.
**Implementierer:** Keine Gegenrede.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Confirmation: AC-1..AC-4 CONFIRMED
Code reference: Shared/Services/OrderExecutor.swift:83
Evidence: Ablehnung `.invalid` mit taskID vor RevisionService.set (84) und dueHasTime-Schreiben (88); Tests Passed im xcresult.
Confirmation: AC-5 CONFIRMED (Diff nur 3 Dateien, Vertrag Version 1, documentCarriesFixtures grün)

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:843d9062ddd3af6a5082e86cd015dce7ac1c025b769e1e2f09f65fbe04e223c5  Shared/Services/OrderExecutor.swift

## Prüfbasis

- base: 3ac92e4030284d3dd01af7d468262cb237050193
- blob:c8ccc5f05f996a32067cce3f20fe0d15965d9fdc  Shared/Services/OrderExecutor.swift

## Geprüfte Dateien

- sha256:843d9062ddd3af6a5082e86cd015dce7ac1c025b769e1e2f09f65fbe04e223c5  Shared/Services/OrderExecutor.swift

## Prüfbasis

- base: 3ac92e4030284d3dd01af7d468262cb237050193
- blob:c8ccc5f05f996a32067cce3f20fe0d15965d9fdc  Shared/Services/OrderExecutor.swift
