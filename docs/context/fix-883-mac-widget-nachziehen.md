# Context: fix-883-mac-widget-nachziehen

## Request Summary
Henning (2026-11-09, TestFlight-Stand vom 2026-11-08): Das Mac-Widget „Als nächstes“ zeigt nach Änderungen keinen neuen Stand.
Seine Erwartung im Intake: Es soll auch nachziehen, ohne dass er in der Hauptapp etwas ändert (Änderung von außen). Auf dem Mac
bewusst nie gesehen, also keine belegte Verschlechterung.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/App/ContentView.swift:166-171` | **Einzige** Stelle mit `WidgetCenter.shared.reloadTimelines(ofKind: "NextUp")`, ausgelöst von `ModelContext.didSave` (eigener Kontext der App, #307) |
| `LooseEndsWidgets/NextUpWidget.swift:27-61` | `NextUpProvider`: liest per `ModelContainerFactory.make(syncs: false)`, Zeitplan `.after(now + 15 min)` |
| `Shared/Persistence/ModelContainerFactory.swift:75-96` | Widget öffnet denselben App-Gruppen-Store ohne Spiegelung, Container im Prozess zwischengespeichert (`localCache`) |
| `LooseEnds/Notifications/DueNotificationCenter.swift:73-96` | Vorbild (#553): `NSPersistentCloudKitContainer.eventChangedNotification` (Import, erfolgreich, `endDate != nil`) → `storeChangedElsewhere()`; dieser Weg erreicht das Widget heute nicht |
| `Shared/Persistence/SyncStatus.swift:110` | zweiter Beobachter derselben Meldung |
| `LooseEnds/Notifications/BackgroundRefresh.swift` | iOS-only, schreibt den Plan ohne App-Start neu; ruft auch `storeChangedElsewhere` |
| `Shared/Intents/NextUpWidgetIntents.swift` | Haken im Widget schreibt in den Store; WidgetKit lädt danach selbst neu |
| `LooseEndsWidgets/LooseEndsWidgets.entitlements` | Sandbox + App-Gruppe, **kein iCloud** (Widget spiegelt nie selbst) |
| `LooseEndsTests/NextUpWidgetTests.swift` | bestehende Tests: Aktionen, Zeilen, Plan, Marke; **nichts** zum Neuladen |

## Existing Patterns
- Das Widget hat keinen eigenen Abgleich; es sieht Änderungen anderer Geräte erst, wenn die **App** sie importiert hat.
- Neuladen wird nur über die App angestoßen (`didSave`), sonst gilt der 15-Minuten-Zeitplan.
- #553 hat für Mitteilungen genau die Lücke „Speicher ändert sich ohne eigenes Speichern (Import)“ geschlossen; für das Widget fehlt das Gegenstück.
- `WidgetCenter` wird nur in `ContentView` benutzt; `ContentView` ist die gemeinsame Oberfläche auf iPhone, iPad und Mac.

## Dependencies
- Upstream: WidgetKit (`WidgetCenter`), CloudKit-Ereignisse (`NSPersistentCloudKitContainer`), App-Gruppen-Store.
- Downstream: alle Widget-Größen von „NextUp“ auf iPhone, iPad, Mac (ein Widget-Typ, `kind` = „NextUp“); Watch-Komplikation ist ein eigenes Ziel und nicht betroffen.

## Existing Specs
- `docs/specs/` enthält keine Spec zum Widget-Nachziehen; #307/#320/#322 (Haken und Nachziehen, nur iPhone/iPad belegt), #521, #706 sind die Vorgänger.

## Recherche (vor Analyse, Quellen)
- [Apple-Forum 830698](https://developer.apple.com/forums/thread/830698): WidgetKit hat kein eigenes Signal für CloudKit-Importe bei SwiftData.
- [Apple-Forum 668144](https://developer.apple.com/forums/thread/668144): nach `reloadTimelines` kann der Abruf alte Zeilen liefern; Apple fragt, ob App und Widget eine Datei teilen.
- [Apple-Forum 816024](https://developer.apple.com/forums/thread/816024): Neuladen wird nach App-Start aus dem Widget teils verzögert.
- Apple-Doku `TimelineProvider`: Daten im Gruppenordner, `reloadTimelines(ofKind:)` nur bei echter Änderung.

## Risks & Considerations
- **Hypothese 1 (stark):** Ein CloudKit-Import von einem anderen Gerät schreibt nicht über den `ModelContext` der App; `didSave` feuert dann nicht, das Widget wartet bis zu 15 Minuten, auf dem Mac gedrosselt auch länger. Erst am Mac nachzustellen.
- **Hypothese 2:** Der im Widget-Prozess zwischengespeicherte Container (`localCache`) zeigt nach einem Neuladen alte Zeilen (Forum 668144). Nur am echten Widget auf dem Mac prüfbar.
- **Hypothese 3:** Läuft die Mac-App nicht, importiert niemand, und das Widget bleibt zwangsläufig alt (die App startet per Anmeldeobjekt der Menüleiste, aber nicht immer).
- Nachstellen auf dem Mac ist Gerätearbeit (Hennings Rechner): nur nach seinem wörtlichen „jetzt ist ein Test möglich“; Simulator zeigt kein Mac-Widget. Ohne Mac-Lauf keine Ursachenbenennung.
- Änderungsziel klein halten: Beobachter für Importe plus Neuladen; `Shared/Persistence` wäre Gerätestufe, `LooseEndsWidgets/` ebenfalls (Pfadliste).
- Testbar ohne Gerät: die Entscheidung „Import erfolgreich → Widget neu laden“ als reine Regel mit eingespeistem Neuladen (Muster `DueNotificationCenter`).

## Analysis

### Type
Bug (auf dem Mac nie belegt, keine belegte Verschlechterung; Antwort auf „Hat es bisher funktioniert?“: nach Aktenlage nie auf dem Mac geprüft)

### Befund aus dem Code (zusätzlich zu den Hypothesen oben)
- **Hypothese 4 (stärkste, im Code belegbar):** Das Neuladen hängt an `.onReceive(ModelContext.didSave)` **in `ContentView`**
  (`LooseEnds/App/ContentView.swift:166-171`). `ContentView` lebt nur im `WindowGroup(id: "main")` (`LooseEndsApp.swift:140`). Auf dem Mac läuft die
  App aber auch mit geschlossenem Fenster (Menüleiste, `MenuBarExtra` mit eigener Erfassung, Dock-Symbol nur bei offenem Fenster, #356/#366).
  Ohne Fenster gibt es keinen Beobachter: weder Erfassung aus der Menüleiste noch ein CloudKit-Import lädt das Widget neu → nur der 15-Minuten-Zeitplan.
- Auf iPhone/iPad sieht man das nie: die App ist beim Test im Vordergrund (Fenster lebt), Importe im Hintergrund erreichen die Szene ohnehin kaum.
- Zweiter, davon unabhängiger Weg: CloudKit-Import schreibt nicht über den `ModelContext` der App (`didSave` feuert nicht) – gilt auch mit offenem Fenster.
- Die Beobachter für Mitteilungen (#553) sitzen dagegen **auf App-Ebene** (`DueNotificationCenter`, in `LooseEndsApp` erzeugt) und überleben das Fenster. Das Widget hat kein Gegenstück.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/App/WidgetReload.swift` | CREATE | Kleine Einheit: reine Regel „Import erfolgreich/Speichern → Widget neu laden“ (Neuladen eingespeist), plus Beobachter für `ModelContext.didSave` und `NSPersistentCloudKitContainer.eventChangedNotification` (Import, `endDate != nil`, `succeeded`), gedrosselt (Zusammenfassen ~1 s) |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | Eine Instanz auf App-Ebene erzeugen und starten (wie `notifications`) |
| `LooseEnds/App/ContentView.swift` | MODIFY | `WidgetCenter.shared.reloadTimelines` aus dem Fensterbeobachter entfernen (sonst doppelt) |
| `LooseEndsTests/WidgetReloadTests.swift` | CREATE | Regel- und Beobachtertests ohne Gerät (Neuladen eingespeist, Meldungen von Hand gesendet) |

### Scope Assessment
- Files: 4 (2 neu, 2 geändert), im Limit
- Estimated LoC: +110/−3
- Risk Level: LOW–MEDIUM (Neuladen ist billig; Risiko: zu häufiges Neuladen → Drosselung nötig; Mac-Widget-Verhalten nur am echten Mac prüfbar)

### Technical Approach (Regel vor Modell: kein Modell im Spiel)
1. Beobachter auf App-Ebene, unabhängig vom Fenster: `didSave` **und** erfolgreicher CloudKit-Import lösen `reloadTimelines(ofKind: "NextUp")` aus.
2. Zusammenfassen (Debounce ~1 s), damit ein Importstoß nicht dutzendfach neu lädt.
3. Reine Entscheidungsfunktion + eingespeistes Neuladen → Unit-Test ohne WidgetKit (Muster `DueNotificationCenter`).
4. Nicht umsetzen: nichts an `NextUpProvider`, `Shared/Persistence`, Entitlements.

### Alternativen (und welche Entscheidung fiele)
- **A (empfohlen):** App-weiter Beobachter wie oben. Kippt nichts; ergänzt #307 (dort sitzt der Beobachter im Fenster).
- **B:** Zeitplan des Widgets kürzer (z. B. 5 Min). Ohne App-Signal; Mac drosselt ohnehin, Akku/Budget, und bleibt träge → löst die Beschwerde nicht.
- **C:** Widget beobachtet selbst den Store (History/Dateiänderung). Widget-Prozess lebt nicht dauerhaft; kippt die Entscheidung „Widget öffnet Store ohne Spiegelung, kein iCloud“ (#307) nicht, bringt aber nichts. Verworfen.
- **D:** Widget bekommt selbst iCloud. Geht mit dem CI-Schlüssel nicht (#307), kippte jene ADR/Entscheidung. Verworfen.

### Dependencies
WidgetKit (`WidgetCenter`), CoreData-Ereignis `NSPersistentCloudKitContainer.eventChangedNotification` (schon von `DueNotificationCenter` und `SyncStatus` benutzt, `#if canImport(CoreData)`), `ModelContext.didSave`. Niemand sonst ruft `reloadTimelines` auf.

### Without the model this fails because … (entfällt)
Kein Modell vorgeschlagen; reine Regel.

### Befunde, die gegen den Plan sprechen
- Ursache ist **nicht auf dem Mac nachgestellt** (Hennings Mac nur nach seinem „jetzt ist ein Test möglich“; Simulator hat kein Mac-Widget). Belegt ist im Code nur: ein Weg ohne Fenster fehlt. Ob zusätzlich Hypothese 2 (zwischengespeicherter Container im Widget-Prozess liefert alte Zeilen, Forum 668144) greift, zeigt erst der Mac-Lauf. Plan: Test zeigt die Lücke (RED: Import/Save ohne Fenster → kein Neuladen), Abnahme über TestFlight auf dem Mac beweist die Wirkung; bleibt das Widget dort alt, ist Hypothese 2 der nächste Schnitt (Container im Widget nicht cachen).
- Pfadliste Stufe 3: dieser Schnitt berührt `LooseEnds/App/` (nicht in der Liste); das Ticket verlangt die Mac-Abnahme aber ausdrücklich in der DoD → Stufe 3 über TestFlight bleibt, `Refs #883` statt `Closes`.

### Open Questions
- [ ] Nur Entscheidung nach dem Bau: Bleibt das Mac-Widget trotz App-Beobachter alt → Schnitt 2 (Hypothese 2). Keine Frage an Henning nötig jetzt.
