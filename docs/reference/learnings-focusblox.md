# Learnings & Gotchas

Gesammelte Erkenntnisse aus der Entwicklung.

## SwiftUI UI Testing

- `Picker` Labels sind NICHT als `StaticText` zugänglich in XCTest
- Teste Picker-Existenz (`app.buttons["pickerName"]`), nicht einzelne Optionen
- Für Picker-Optionen: Teste indirekt über Ergebnis (z.B. Task erstellen, prüfen ob gespeichert)

## Workflow State

- `.claude/workflow_state.json` wird von ALLEN Claude-Sessions geteilt
- **NIEMALS** fremde Workflows ändern - nur den eigenen aktiven Workflow
- Bei Unsicherheit: Workflow State in Ruhe lassen, nur Roadmap aktualisieren

## macOS App Icons

**Problem:** SwiftUI Icon-Code (`FocusBloxIcon`) existiert, aber App zeigt altes Icon.

**Root Cause:**
- `scripts/render-icon.swift` generierte nur `foreground.png` für iOS Icon Composer
- Die PNG-Dateien in `FocusBloxMac/Assets.xcassets/AppIcon.appiconset/` wurden **nie aktualisiert**
- macOS braucht 10 separate PNG-Dateien (16x16 @1x/@2x bis 512x512 @1x/@2x)

**Lösung:**
1. `render-icon.swift` muss ALLE macOS-Größen generieren
2. Nach Änderungen am Icon-Code: `swift scripts/render-icon.swift` ausführen
3. DerivedData löschen: `rm -rf ~/Library/Developer/Xcode/DerivedData/FocusBlox-*`
4. Icon-Cache löschen: `rm -rf ~/Library/Caches/com.apple.iconservices.store && killall Finder`
5. Clean Build durchführen

**Checkliste bei Icon-Änderungen:**
- [ ] SwiftUI-Code in `FocusBloxIconLayers.swift` ändern
- [ ] AUCH den Code in `scripts/render-icon.swift` synchronisieren (Duplikat!)
- [ ] Script ausführen: `swift scripts/render-icon.swift`
- [ ] Verifizieren dass ALLE Icons generiert wurden:
  - `AppIcon.icon/Assets/foreground.png` (iOS Icon Composer)
  - `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (iOS Fallback)
  - `FocusBloxMac/Assets.xcassets/AppIcon.appiconset/icon_*.png` (macOS)
- [ ] Caches löschen + Clean Build

## Xcode Schemes verschwinden

**Problem:** Nach DerivedData-Löschung fehlen Xcode Schemes (z.B. FocusBlox iOS).

**Root Cause:**
- Xcode generiert Schemas automatisch, speichert sie aber NICHT als Dateien
- `xcschememanagement.plist` referenziert `FocusBlox.xcscheme_^#shared#^_`
- Aber der Ordner `xcshareddata/xcschemes/` ist **leer**
- Nach DerivedData-Löschung findet Xcode die Schemas nicht mehr

**Lösung:**
1. Schemas müssen als **Dateien** in `FocusBlox.xcodeproj/xcshareddata/xcschemes/` existieren
2. Nach Erstellung: **Sofort committen** (`git add *.xcscheme && git commit`)

**NIEMALS MACHEN:**
- `rm -rf ~/Library/Developer/Xcode/DerivedData/` ohne vorher Schemas zu sichern
- Davon ausgehen, dass Schemas als Dateien existieren - **immer prüfen!**

**Prüf-Befehl:**
```bash
ls FocusBlox.xcodeproj/xcshareddata/xcschemes/
# Sollte FocusBlox.xcscheme, FocusBloxMac.xcscheme etc. zeigen
```

**Schema manuell erstellen:**
1. Target-ID finden: `grep -E "^\t+[A-F0-9]+ /\* FocusBlox \*/ = \{$" *.pbxproj`
2. Schema-XML erstellen mit korrekter BlueprintIdentifier
3. In `xcshareddata/xcschemes/` speichern

---

## SwiftUI Path in ViewBuilder

**Problem:** `Path` Views in einem `ZStack` mit `.offset()` werden nicht zuverlässig positioniert, da Paths keine intrinsische Größe haben.

**Falscher Ansatz:**
```swift
ZStack {
    Path { path in ... }
        .offset(x: -50, y: -50)  // ❌ Unzuverlässig
    Path { path in ... }
        .offset(x: 50, y: -50)   // ❌ Kann aus dem Bereich verschwinden
}
```

**Korrekter Ansatz - Canvas verwenden:**
```swift
Canvas { context, size in
    let centerX = size.width / 2
    let centerY = size.height / 2

    var path = Path()
    path.move(to: CGPoint(x: centerX - 50, y: centerY))
    // ... Pfad definieren relativ zum Zentrum

    context.stroke(path, with: .color(.white), style: ...)
}
.frame(width: 200, height: 200)  // ✅ Feste Größe definieren
```

**Grund:** `Canvas` gibt volle Kontrolle über Koordinaten und hat eine definierte Größe.

---

## SwiftData Reference-Type Crash (nil vor Delete)

**Problem (BUG_112):** macOS crasht beim Löschen einer Wiederholungsserie mit:
`Fatal error: This backing data was detached from a context without resolving attribute faults: \LocalTask.tags`

**Root Cause:**
`LocalTask` ist ein SwiftData-Modell und damit ein **Reference Type** (Klasse). Nach dem Aufruf einer Delete-Funktion, die das Objekt selbst löscht, ist das Objekt sofort detached. Jeder nachfolgende Zugriff auf Properties des Objekts (z.B. `.tags` im SwiftUI-Re-render) führt zu einem Fatal Error.

**Falscher Ansatz:**
```swift
deleteRecurringSeries(task)   // task ist ab hier detached
taskToDeleteRecurring = nil   // zu spät — SwiftUI hat bereits re-rendered
```

**Korrekter Ansatz:**
```swift
taskToDeleteRecurring = nil           // 1. State auf nil setzen (UI entkoppeln)
selectedTasks.removeAll()             // 2. Selektionen leeren
SyncEngine.deleteRecurringSeries(     // 3. Erst jetzt löschen — kein LocalTask-Objekt mehr
    groupID: task.recurrenceGroupID
)
```

**Generelle Regel:** Bei SwiftData-Objekten, die nach ihrer Deletion noch von SwiftUI referenziert werden könnten:
1. Immer State-Variablen (Optional, Selection) auf nil/leer setzen **vor** dem Delete
2. Delete-Funktionen sollten möglichst mit primitiven IDs (String, UUID) arbeiten, nicht mit dem Objekt selbst
3. `@State var item: LocalTask?` — nach Delete sofort auf `nil` setzen bevor `modelContext.delete(item)` aufgerufen wird

---

## SwiftUI List: Mehrere interaktive Buttons pro Zeile (RW_3.2)

**Problem:** Ein zweiter Button in einer `List`-Zeile (z.B. ein "Los"-Sprint-Button neben bestehendem Content) wird nicht zuverlässig getappt — stattdessen triggert die Zeile die Row-Aktion.

**Root Causes & Fixes:**

1. **`.buttonStyle(.plain)` in List-Zeilen** leitet Taps manchmal an die übergeordnete Geste weiter. Verwende stattdessen **`.buttonStyle(.borderless)`** — das isoliert den Tappable-Bereich korrekt.

2. **`.contentShape(Rectangle())`** auf dem HStack einer Zeile überschreibt das Hit-Testing und fängt alle Taps für die gesamte Zeile ab — auch solche, die für Buttons innerhalb des HStack gedacht sind. Lösung: `.contentShape(Rectangle())` entfernen, wenn mehrere Buttons in der Zeile existieren.

3. **Section-Level `.accessibilityIdentifier`** überschreibt die Identifier aller Kind-Elemente. Identifier immer auf einem konkreten View (z.B. `HStack`) setzen, nicht auf `Section`.

4. **Tab-Bar verdeckt letzte Zeile:** Ein Button in der letzten List-Zeile kann nicht getappt werden, wenn er unter der Tab-Bar liegt. Fix: `.safeAreaInset(edge: .bottom)` mit ausreichend Abstand (z.B. 120 pt) auf der `List` oder dem umgebenden `ScrollView`.

**Generelle Regel:** In SwiftUI Lists mit mehreren interaktiven Elementen pro Zeile immer `.buttonStyle(.borderless)` verwenden und kein `.contentShape(Rectangle())` auf dem äußersten HStack.

---

## macOS Cross-View Refresh: `taskDataChanged` Notification Pattern

**Problem (#189, #190, #191):** `ContentView` (Backlog) hält `@State tasks` und ruft `refreshTasks()` auf. Child-Views (`MacFocusView`, `TaskInspector`, `MacPlanningView`) ändern Task-Daten via `modelContext.save()`, aber `ContentView` bekommt davon nichts mit — das Backlog veraltet.

**Pattern: Notification posten nach jeder Task-Mutation**

Definition (in `ContentView.swift`):
```swift
extension Notification.Name {
    static let taskDataChanged = Notification.Name("taskDataChanged")
}
```

Observer in `ContentView`:
```swift
.onReceive(NotificationCenter.default.publisher(for: .taskDataChanged)) { _ in
    refreshTasks()
}
```

Sender in jeder mutierenden Child-View nach `modelContext.save()`:
```swift
NotificationCenter.default.post(name: .taskDataChanged, object: nil)
```

**Regel:** Jede macOS-View, die Task-Daten ändert und `modelContext.save()` aufruft, MUSS danach `.taskDataChanged` posten. Gilt für: Status-Toggles, Completion, isNextUp, Planning-Aktionen.

**Betroffene Views (Stand 2026-04-03):**
- `MacFocusView` — nach `markTaskComplete()` und `returnIncompleteTasksToNextUp()`
- `TaskInspector` — via `saveAndNotify()` Helper (kapselt save + post)
- `MacPlanningView` — nach assign/remove/create/addTask-Aktionen
- `CoachView` (macOS) — nach Intention-Speicherung (`saveDayIntention()`)

---

---

## macOS XCTest: Element-Abfrage in NavigationSplitView

**Problem (#197):** `app.otherElements["identifier"]` findet keine Elemente im Content-Bereich einer `NavigationSplitView`. Der Content-Bereich wird von XCTest nicht als direkt abfragbares `otherElement` exponiert.

**Falscher Ansatz:**
```swift
app.otherElements["coachContent"].waitForExistence(timeout: 5)  // ❌ findet nichts
```

**Korrekter Ansatz — `descendants(matching:)` verwenden:**
```swift
app.descendants(matching: .any)["coachContent"].waitForExistence(timeout: 5)  // ✅
```

**Grund:** `descendants(matching: .any)` durchsucht den gesamten Accessibility-Baum unabhängig von der Element-Hierarchie, während `otherElements` nur eine bestimmte Accessibility-Kategorie trifft, die in `NavigationSplitView`-Content-Areas nicht zuverlässig gesetzt ist.

**Generelle Regel für macOS UI Tests mit `NavigationSplitView`:**
- Sidebar-Elemente: `app.outlineRows` oder `app.buttons["Label"]`
- Content-Bereich: `app.descendants(matching: .any)["identifier"]`
- Toolbar-Buttons: `app.buttons["Label"]` (funktioniert weiterhin direkt)

---

Erstellt: 2026-01-23
Aktualisiert: 2026-04-03 (CoachView zu taskDataChanged-Liste; macOS XCTest NavigationSplitView, #197)
