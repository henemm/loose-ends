# Context: fix-883-widget-schnitt2

## Request Summary
Henning (2026-11-13): Das Widget „Als nächstes“ zeigt nach Änderungen keinen neuen Stand, auf dem Mac **und** auf dem iPad.
Auf Rückfrage: er hat auf **einem anderen Gerät** (iPhone oder Mac) geändert, das iPad-Widget blieb alt. Also der Weg
„Änderung kommt per iCloud von außen“, nicht „in der App auf dem iPad abgehakt“.

## Stand vor diesem Schnitt
- Schnitt 1 (PR #901, gemergt 2026-11-10 21:48Z, `Refs #883`): `LooseEnds/App/WidgetReload.swift` lädt das Widget bei jedem
  `ModelContext.didSave` und bei jedem beendeten, erfolgreichen CloudKit-Import (`NSPersistentCloudKitContainer.eventChangedNotification`),
  auf App-Ebene, 1 s zusammengefasst. Vorher nur in `ContentView` (Fenster).
- **Dieser Stand steckt in keinem TestFlight-Bau.** Letzter Lauf `testflight.yml`: 2026-11-10 04:02Z (Commit d7072d5), also vor dem Merge.
  Hennings Beobachtung stammt damit vom Stand **ohne** Schnitt 1. Schnitt 1 wurde nie am Widget nachgestellt oder belegt
  (Spec: „Ursache nicht auf dem Mac nachgestellt“); belegt waren nur Unit-Tests und ein Simulator-Smoke ohne Widget.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/App/WidgetReload.swift` | Schnitt 1; Beobachter für Speichern und Import, ruft `reloadTimelines(ofKind: "NextUp")` |
| `LooseEnds/App/LooseEndsApp.swift` | erzeugt und startet `WidgetReload` |
| `LooseEndsWidgets/NextUpWidget.swift:27-61` | `NextUpProvider.load` öffnet den Store je Aufruf über `ModelContainerFactory.make(syncs: false)`, Zeitplan `.after(+15 min)` |
| `Shared/Persistence/ModelContainerFactory.swift:75-96` | `syncs: false`: Container ohne Spiegelung, **pro Prozess zwischengespeichert** (`localCache`, `ProcessCache`) |
| `LooseEnds/Notifications/BackgroundRefresh.swift` | iOS: tägliche App-Auffrischung (nur Mitteilungsplan, lädt das Widget nicht) |
| `project.yml:96` | `UIBackgroundModes: [remote-notification, fetch]`; kein `didReceiveRemoteNotification` im Code, SwiftData/CloudKit verarbeitet Pushes selbst |
| `LooseEndsWidgets/LooseEndsWidgets.entitlements` | Widget hat App-Gruppe, **kein iCloud**: es sieht Änderungen anderer Geräte erst, wenn die App sie importiert hat |
| `LooseEndsTests/WidgetReloadTests.swift`, `NextUpWidgetTests.swift` | prüfen Entscheidung und Zeilenwahl, **nicht** den Widget-Prozess |

## Existing Patterns
- Kette „anderes Gerät → Widget“: CloudKit-Push → App-Prozess wird (im Hintergrund) geweckt → Import in den App-Gruppen-Store →
  `eventChangedNotification` → `WidgetReload` → `reloadTimelines` → Widget-Prozess liest denselben Store.
  Jedes Glied kann reißen; keines ist bisher am echten Ablauf belegt.
- Vorbild für Importereignisse: `DueNotificationCenter` (#553), `SyncStatus`.

## Hypothesen (alle noch nicht nachgestellt)
1. **Die App wird nicht geweckt / importiert nicht**, solange sie im Hintergrund oder beendet ist (iPad: App weggewischt = kein
   Hintergrundstart durch stille Pushes). Dann gibt es nichts, was das Widget neu laden könnte; erst beim nächsten Öffnen.
2. **Zwischengespeicherter Container im Widget-Prozess** (`localCache`) liefert nach `reloadTimelines` alte Zeilen
   ([Apple-Forum 668144](https://developer.apple.com/forums/thread/668144)); greift auf allen Plattformen, passt zu „iPad wie Mac“.
3. Schnitt 1 allein reicht nicht, weil Hypothese 1 oder 2 dahinter liegt. Oder er genügt, und es fehlt nur der Bau (dann Abnahme).

## Dependencies
- Upstream: WidgetKit, CloudKit-Spiegelung (`NSPersistentCloudKitContainer`), App-Gruppen-Store (SQLite/WAL, zwei Prozesse).
- Downstream: alle Größen des Widgets `NextUp` auf iPhone, iPad, Mac; Watch-Komplikation ist ein eigenes Ziel.

## Existing Specs
- `docs/specs/fix-883-mac-widget-nachziehen.md` (Schnitt 1), Vorgänger #307, #320/#322, #521, #706.

## Risks & Considerations
- Pfadliste Stufe 3: `LooseEndsWidgets/` und `Shared/Persistence/` berühren → Abnahme über TestFlight bei Henning; Geräte nie ohne sein
  „jetzt ist ein Test möglich“. Der Simulator kennt kein CloudKit; ein Widget lässt sich dort nur über die Home-Bildschirm-Galerie hinzufügen.
- Nachstellbar ohne Gerät ist vor allem Hypothese 2: zwei Prozesse auf dasselbe SQLite-File, Schreiben in Prozess A, Lesen in
  Prozess B mit zwischengespeichertem Container. Hypothese 1 (Hintergrundstart) nur am Gerät.
- `Shared/Models` bleibt unberührt (kein CloudKit-Deploy).

## Recherche (2026-11-13, vor der Analyse)
- [Forum 668144](https://developer.apple.com/forums/thread/668144): Widget liest nach `reloadTimelines` alte Core-Data-Zeilen; Abhilfe der Community: den Kontext vor dem Fetch auf die aktuelle Store-Generation setzen. Passt zu Hypothese 2 (zwischengespeicherter Container).
- [Forum 791794](https://developer.apple.com/forums/thread/791794): App und Widget haben getrennte Container in getrennten Prozessen; Änderungen des anderen Prozesses sind „remote“ und nicht beobachtbar.
- [Forum 654059](https://developer.apple.com/forums/thread/654059), [682156](https://developer.apple.com/forums/thread/682156), [739864](https://developer.apple.com/forums/thread/739864): stille CloudKit-Pushes starten eine beendete oder weggewischte App praktisch nie; Hintergrund-Sync ist umstritten. Passt zu Hypothese 1.
- [Forum 652946](https://developer.apple.com/forums/thread/652946): `reloadTimelines` wirkt im Hintergrund nur eingeschränkt; WidgetKit budgetiert Reloads. Neu: Hypothese 4.
- [Forum 830698](https://developer.apple.com/forums/thread/830698): Widgets geräteübergreifend nach SwiftData+CloudKit zuverlässig aktualisieren, gleiche Frage, ohne belastbare Apple-Antwort.

## Analysis

### Type
Bug (Schnitt 2 von #883; Schnitt 1 ist gemergt, aber in keinem Bau)

### Befund
Die Kette „anderes Gerät → Widget" hat vier Glieder, keines ist am echten Ablauf belegt:
1. App wird von der stillen Push geweckt und importiert (beendete App: laut Foren nein).
2. `eventChangedNotification` → `WidgetReload` (Schnitt 1, per Unit-Test belegt).
3. `reloadTimelines` kommt im Hintergrund an (budgetiert, ggf. verworfen).
4. Widget-Prozess liest frisch: `NextUpProvider.load` nutzt `ModelContainerFactory.make(syncs: false)` über `localCache`, also **einen Container je Prozess**, der bei langlebigem Widget-Prozess alte Zeilen liefern kann.

Glied 4 ist ohne Gerät nachstellbar (zwei Prozesse oder zwei Container auf demselben SQLite-File, Schreiben in A, Lesen in B über zwischengespeicherten Container). Glied 1 und 3 nur am Gerät.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsWidgets/NextUpWidget.swift` | MODIFY | Widget liest je Aufruf frisch (neuer Container oder Kontext auf aktuelle Store-Generation), falls Nachstellung Hypothese 2 bestätigt |
| `Shared/Persistence/ModelContainerFactory.swift` | MODIFY (ggf.) | `syncs: false` ohne Prozess-Cache für das Widget |
| `LooseEndsTests/…` | CREATE | Test: Schreiben über zweiten Container, Lesen über Widget-Ladeweg zeigt neuen Stand |
| `LooseEnds/App/WidgetReload.swift` | MODIFY (ggf.) | nur wenn Nachstellung Glied 3 belegt (z. B. Reload auch beim Wechsel in den Vordergrund) |

### Scope Assessment
- Files: 3–4, Estimated LoC: +80/-10, Risk Level: MEDIUM (`Shared/Persistence/` und `LooseEndsWidgets/` = Stufe 3)

### Technical Approach
Erst nachstellen, dann ändern (Reihenfolge fest):
1. Test-Reproduktion Glied 4 (zwei Container, ein Store-File). Rot = Ursache belegt, dann Fix: Widget öffnet je Zeitleistenaufruf einen frischen Container (kein `localCache`).
2. Zusätzlich billig und regelbasiert: `WidgetReload` auch beim Wechsel der App in den Vordergrund auslösen (deckt Hypothese 1 ab, soweit sie sich ohne Hintergrundstart lösen lässt).
3. Gerät: Abnahme über TestFlight bei Henning (Stufe 3); ohne sein Wort nichts auf Geräten.

### Alternative(n)
- **Widget bekommt eigenes iCloud und synchronisiert selbst**: scheitert laut `NextUpWidget`-Kommentar am Entitlement (#307); würde ADR zur App-Gruppe als einziger Schreib-/Lesequelle kippen. Verworfen.
- **Kein Push-Weg, nur Zeitplan kürzen** (`.after(+15 min)` auf 5 min): einfach, aber budgetiert und ändert nichts, wenn Glied 4 die Ursache ist.
- **Nichts bauen, nur Schnitt 1 ausliefern und prüfen**: legitim, weil Henning ohne Schnitt 1 beobachtet hat. Empfohlen als erster Schritt neben der Nachstellung: einen TestFlight-Bau mit Schnitt 1 erzeugen, bevor mehr gebaut wird.

### Dependencies
WidgetKit-Budget, CloudKit-Spiegelung der App, App-Gruppen-Store (WAL, zwei Prozesse); `Shared/Models` bleibt unberührt (kein CloudKit-Deploy).

### Open Questions
- [ ] Bestätigt die Zwei-Container-Nachstellung Hypothese 2? (entscheidet über Umfang)
- [ ] Soll zuerst ein TestFlight-Bau mit Schnitt 1 allein zu Henning, damit klar ist, ob Schnitt 1 schon genügt? (Empfehlung: ja, parallel)
