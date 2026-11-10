---
entity_id: fix-883-mac-widget-nachziehen
type: bug
created: 2026-11-10
updated: 2026-11-10
status: draft
workflow: fix-883-mac-widget-nachziehen
---

# Spec: #883 — Das Widget „Als nächstes“ zieht auch nach, wenn das App-Fenster zu ist oder die Änderung von außen kommt

## Approval

- [ ] Approved (Henning)

Henning, TestFlight-Stand vom 2026-11-08, Mac: Das Widget „Als nächstes“ zeigt nach Änderungen keinen neuen Stand. Erwartung im
Intake: Es zieht auch nach, ohne dass er in der Hauptapp etwas ändert (Änderung von einem anderen Gerät). Auf dem Mac nie zuvor
geprüft, also keine belegte Verschlechterung.

## Purpose

Das Neuladen des Widgets hängt heute nur an `ModelContext.didSave` **in `ContentView`**, also nur solange das Hauptfenster lebt und
nur für Speichern in der App selbst. Auf dem Mac läuft die App auch mit geschlossenem Fenster (Menüleiste, Erfassung dort), und ein
CloudKit-Import von einem anderen Gerät speichert nicht über den Kontext der App. In beiden Fällen bleibt nur der 15-Minuten-Zeitplan
des Widgets. Dieser Schnitt legt einen Beobachter auf App-Ebene an, der das Widget bei jedem Speichern und bei jedem erfolgreichen
Import neu lädt, unabhängig vom Fenster. Kein Modell im Spiel; Regel und Beobachter.

Nicht Teil dieses Schnitts: `NextUpProvider`, `Shared/Persistence`, Entitlements, Zeitplan des Widgets. Zeigt das Mac-Widget nach dem
Bau weiter alte Zeilen, ist der zwischengespeicherte Container im Widget-Prozess (Forum 668144) der nächste Schnitt.

## Source

- **Neu:** `LooseEnds/App/WidgetReload.swift`
- **Geändert:** `LooseEnds/App/LooseEndsApp.swift` (eine Instanz auf App-Ebene, wie `notifications`)
- **Geändert:** `LooseEnds/App/ContentView.swift` (`reloadTimelines` aus dem Fensterbeobachter entfernen)
- **Neu:** `LooseEndsTests/WidgetReloadTests.swift`

## Implementation Details

**`WidgetReload` (`@MainActor`, Muster `DueNotificationCenter`).** Hält das Neuladen als eingespeisten Closure
(`reload: @MainActor () -> Void`; im Produkt `WidgetCenter.shared.reloadTimelines(ofKind: "NextUp")`, die Art steht an einer Stelle).
`start()` hängt zwei Beobachter an:

1. `ModelContext.didSave` (eigener Kontext der App, #307) → `reloadSoon()`.
2. `NSPersistentCloudKitContainer.eventChangedNotification` unter `#if canImport(CoreData)`; zählt nur, wenn `event.type == .import`,
   `event.endDate != nil` und `event.succeeded` (dieselbe Regel wie #553, als reine Funktion `isFinishedImport(_:)` herausgezogen
   und von beiden Beobachtern des Hauses lesbar; `DueNotificationCenter` bleibt unverändert) → `reloadSoon()`.

`reloadSoon()` fasst zusammen: ein laufender Wartetask wird abgebrochen, nach 1 s ruft ein neuer `reload` genau einmal. Ein Importstoß
mit Dutzenden Meldungen lädt das Widget also einmal neu. Unter `--ui-testing` und in Unit-Tests ohne eigenes Neuladen bleibt der
Produkt-Closure still (kein WidgetKit-Aufruf), wie `DueNotificationCenter.suppressed`.

**`LooseEndsApp`.** Neben `notifications` wird eine Instanz erzeugt und sofort `start()` gerufen, damit sie so lange lebt wie der
Prozess und nicht wie das Fenster.

**`ContentView`.** Die Zeile `WidgetCenter.shared.reloadTimelines(ofKind: "NextUp")` samt Kommentar entfällt (sonst doppeltes Neuladen);
`rescheduleSoon()` und `syncSoon()` bleiben. Ist `import WidgetKit` danach in der Datei unbenutzt, entfällt auch er.

## Acceptance Criteria

- **AC-1:** Ein erfolgreicher, beendeter CloudKit-Import löst genau ein Neuladen aus (Unit-Test, Meldung von Hand gesendet,
  Neuladen eingespeist). Ein Import ohne `endDate`, ein fehlgeschlagener Import und ein Export lösen keines aus.
- **AC-2:** Ein Speichern im Kontext der App (`ModelContext.didSave`) löst ein Neuladen aus, **ohne dass eine `ContentView` existiert**
  (Unit-Test: nur `WidgetReload` gestartet, kein Fenster).
- **AC-3:** Zehn Meldungen innerhalb einer Sekunde ergeben genau ein Neuladen (Zusammenfassen).
- **AC-4:** `ContentView` ruft `reloadTimelines` nicht mehr selbst auf, damit ein Speichern nicht doppelt neu lädt. Fester Test in
  `WidgetReloadTests`: liest `LooseEnds/App/ContentView.swift` über `#filePath` und schlägt fehl, wenn dort `reloadTimelines` steht;
  ein zweiter Test prüft, dass `LooseEndsApp.swift` eine `WidgetReload`-Instanz erzeugt und `start()` ruft (der Beobachter hängt am
  Prozess, nicht am Fenster).
- **AC-5:** iPhone und iPad unverändert: Speichern in der App lädt das Widget weiter neu (derselbe Beobachter, Simulator-Smoke läuft grün).
- **AC-6:** `scripts/sim.sh unit` und `build` grün, `generate` hinterlässt keinen Diff.

## Definition of Done

- AC-1 bis AC-6 erfüllt, Unit-Tests und Build grün, PR mit `Refs #883`, gemergt nach grüner CI.
- Gerätepunkt (Stufe 3, TestFlight, Mac): Bei geschlossenem App-Fenster erledigt Henning am iPhone eine Aufgabe; das Mac-Widget
  „Als nächstes“ zeigt den neuen Stand binnen weniger Minuten. Erst seine Rückmeldung schließt das Ticket; bleibt das Widget alt,
  folgt Schnitt 2 (Container im Widget nicht zwischenspeichern).

## Test Plan

Alle Tests in `LooseEndsTests/WidgetReloadTests.swift`, Neuladen eingespeist, Meldungen von Hand gesendet:

- `testFinishedImportReloadsOnce` (AC-1), `testUnfinishedFailedAndExportDoNotReload` (AC-1)
- `testDidSaveReloadsWithoutAnyView` (AC-2)
- `testBurstOfTenMessagesReloadsOnce` (AC-3)
- `testContentViewNoLongerCallsReloadTimelines`, `testAppCreatesAndStartsWidgetReload` (AC-4, Quelltext über `#filePath`)
- AC-5 und AC-6: `./scripts/sim.sh unit`, `build`, `generate` ohne Diff; UI-Smoke in der CI.

## Abnahme

Stufe 1 (Unit-Tests) und Stufe 2 (Simulator: App startet, Aufgabe erfassen, Beobachter ruft Neuladen; ein Mac-Widget gibt es im
Simulator nicht) sind Pflicht. Die Wirkung auf dem Mac-Widget lässt sich nur auf dem Mac belegen: **Stufe 3 über TestFlight**
(Henning, 2026-10-10, #279), Gerätepunkt in der Definition of Done des Tickets, nicht als AC dieser Spec; der PR trägt `Refs #883`
statt `Closes #883`. Henning bekommt danach in einfachen Worten, was er prüfen soll (Fenster zu, am iPhone eine Aufgabe erledigen,
Mac-Widget zeigt den neuen Stand binnen Sekunden bis wenigen Minuten). Berührt der Schnitt `LooseEnds/App/`, der nicht in der
Geräteliste steht, wird dies im Bericht so genannt; die Mac-Prüfung verlangt das Ticket trotzdem ausdrücklich.

## Alternativen (verworfen)

- **B:** Kürzerer Zeitplan im Widget (z. B. 5 min): ohne App-Signal, Mac drosselt ohnehin, löst die Beschwerde nicht.
- **C:** Widget beobachtet selbst den Store: Widget-Prozess lebt nicht dauerhaft, bringt nichts.
- **D:** Widget bekommt selbst iCloud: geht mit dem CI-Schlüssel nicht (#307), würde jene Entscheidung kippen.

## Scope

4 Dateien (2 neu, 2 geändert), etwa +110/−3 LoC, im Limit. Keine Berechtigung, kein Schlüssel, kein Katalogeintrag.

## ADR

**ADR-Nr.:** keine neue; ergänzt #307 (Neuladen auch ohne Fenster und bei Import).
