# Context: fix-580-veraltete-schnittstellen

## Request Summary
#580 (Epic #226, M3): Der iOS-27-Bau meldet sechs Warnungen über veraltete Schnittstellen. Sie werden ersetzt, das Verhalten
bleibt gleich (Teilen von Text, Link, Mail, Foto, Datei; Detailansicht; tägliche Neuplanung der Mitteilungen).

## Die sechs Warnungen (frisch aus dem Bau, 2026-10-24, nicht aus dem Ticket)
Die Zeilen im Ticket sind verschoben (`TaskDetailView:123/124` ist heute `.labelsHidden()`). Maßgeblich ist dieser Bau:

| Stelle | Warnung (Wortlaut des SDK) |
|---|---|
| `LooseEndsShare/ShareViewController.swift:74` (Mail), `:78` (URL), `:82` (Text) | `loadItem(forTypeIdentifier:options:)` was deprecated in iOS 27.0: Use `loadObjectOfClass:completionHandler:` instead |
| `LooseEnds/Views/TaskDetailView.swift:151`, `:152` | `+` was deprecated in iOS 26.0: Use string interpolation on `Text` instead |
| `LooseEnds/Notifications/BackgroundRefresh.swift:40` | `submit` was deprecated in iOS 27.0: Use `submitTaskRequest(_:completionHandler:)` (or `try await submitTaskRequest(_:)`) to capture all error conditions |

## Recherche (Apple-Dokumentation und Forum, mit Quellen im Intake)
- `Text +`: Ersatz ist ein einziger `Text` mit Interpolation von `Text`-Werten; Wortreihenfolge in einem Stück, bessere Lokalisierung.
- `submit`: Ersatz `submitTaskRequest`, ab iOS 27. Apple warnt vor Aufruf auf dem Main-Thread; `BackgroundRefresh` ist `@MainActor`.
  Ein Forenbericht (nicht bestätigt) nennt einen XPC-Fehler beim neuen Weg auf iOS 27.
- `loadItem`: das SDK nennt `loadObject(ofClass:)` als Ersatz. Für die Mail (`UTType.emailMessage`, kein `NSItemProviderReading`-Typ)
  passt es nicht; dort liegt `loadDataRepresentation(forTypeIdentifier:)` nahe, das dieselbe Datei schon benutzt (Zeile 127).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsShare/ShareViewController.swift:56-96` | `collect`: drei `loadItem`-Zweige; `loadedKind(_:branch:)` und `string(from:)` (Zeilen 154-172) werten das Ergebnis als `NSSecureCoding` aus (Data, URL, String, NSAttributedString) |
| `LooseEnds/Views/TaskDetailView.swift:148-157` | „Said“-Kopf, zwei Leerzeichen, Rohtext als eine Zeile mit `Text +`; Stile je Teil (caption2, tracking 1; serif subheadline italic) |
| `LooseEnds/Notifications/BackgroundRefresh.swift:35-44` | `schedule()` (static, `@MainActor`, synchron, wird aus Register-Handler, App-Wechsel und nach jedem Lauf gerufen) |
| `Shared/Services/SharedContent.swift` | reine Logik hinter dem Teilen (`make`, `probeLine`); `LooseEndsTests/SharedContentTests.swift` prüft sie |
| `LooseEndsUITests/…` (`detailRawText`) | Kennung `detailRawText` und Label des Rohtexts werden in mehreren UI-Tests benutzt; muss bleiben |

## Existing Patterns
- `loadFileRepresentation` und `loadDataRepresentation` sind im Share-Pfad schon in Gebrauch (Anhänge, Zeilen 110 und 127), mit `withCheckedThrowingContinuation`.
- Ein Probenzeilen-Vertrag (#24 AC-1): `SharedContent.probeLine` loggt Typkennungen und den geladenen Typ, nie den Inhalt. Die neue Ladeweise muss `kind` weiter liefern.
- Fehler werden geloggt, nie verschluckt (`logger.error`), kein `try?`.

## Dependencies
- Upstream: `NSItemProvider`, `BGTaskScheduler`, SwiftUI `Text`, Katalog `Localizable.xcstrings` (Schlüssel „Said“).
- Downstream: `SharedContent.make` (erwartet `texts`, `urls`, `mails` als Strings/URLs); `ContentView`/`LooseEndsApp` rufen `BackgroundRefresh.schedule()`; UI-Tests lesen `detailRawText`.

## Existing Specs
- `docs/specs/fast/fix-659-knaeuel-sprache.md` (Muster einer Mini-Spec); für Teilen und Hintergrundabgleich gibt es keine eigene Spec, nur die Tickets #24, #399, #442, #553.

## Risks & Considerations
- **Verhaltensgleichheit beim Teilen ist das Hauptrisiko.** `loadItem` lieferte je nach Absender URL, Data, String oder Datei-URL; `loadObject(ofClass:)` liefert genau die gewünschte Klasse oder scheitert. Bekannte Absender (Safari, Mail, Notizen, Nachrichten) müssen weiter als Text/Link/Mail ankommen. Simulator kann das Teilen nur eingeschränkt; Nachweis voraussichtlich Gerät über TestFlight.
- **`submitTaskRequest` auf dem Main-Thread:** Apple rät ab. Die Funktion läuft heute synchron auf `@MainActor`; der Ersatz braucht eine Entscheidung (Aufruf in einer nicht isolierten Task, Fehler im Handler loggen). Der Forenbericht zum XPC-Fehler ist im Simulator nicht prüfbar, ein Daueraufruf täglich bleibt unsichtbar scheitern, falls er stimmt.
- **`Text`-Interpolation:** Die zwei Stile müssen bleiben; die Zeile bleibt ein laufender Satz (#438). Barrierefreiheit (`accessibilityLabel(task.rawText)`) und Kennung unverändert.
- **Geräteliste:** Der Schnitt berührt `LooseEndsShare/` und `LooseEnds/Notifications/`, also ist Stufe 3 Pflicht (TestFlight, nach Hennings Wort).
- **Scope:** drei Produktdateien, vermutlich unter 100 LoC; Tests für die reine Auswertung (`string(from:)`/Art) wären nur möglich, wenn sie aus dem Controller in eine testbare Stelle wandert, das entscheidet `/20-analyse`.
- **Alternative zu prüfen:** `loadItem` mit `loadDataRepresentation` für alle drei Zweige (ein Weg, selbst dekodiert) statt `loadObject`; und `BackgroundRefresh` mit `try await submitTaskRequest` in einer Task.

## Analysis

### Type
Wartung (Feature-Schnitt ohne neues Verhalten): sechs Warnungen im iOS-27-Bau, Verhalten bleibt gleich. Kein Fehler, also keine Reproduktion nötig; der Nachweis ist der Bau ohne die sechs Zeilen.

### Recherche (vor allem anderen, Quellen)
- `Text +`: Apple-Seite zu `+(_:_:)` nennt als Grund die feste Wortreihenfolge (Lokalisierung, Rechts-nach-links); Ersatz ist ein `Text` mit Interpolation, und ein gestalteter `Text` darf darin stehen (https://developer.apple.com/documentation/swiftui/text/+(_:_:).md, https://nilcoalescing.com/blog/TextConcatenationVsTextInterpolationInSwiftUI, https://www.hackingwithswift.com/forums/100-days-of-swiftui/day-71-text-interpolation-deprecated-on-ios-26/30390).
- `submit`: Ersatz `submitTaskRequest(_:completionHandler:)`, ab iOS 27 (https://developer.apple.com/tutorials/data/documentation/backgroundtasks/bgtaskscheduler/submittaskrequest(_:completionHandler:).md). Die Header-Zeile „nicht vom Main-Thread aufrufen“ ist laut Apple-DTS **falsch**: „The new API is definitely intended to support being called from any thread, including the main thread“ (https://developer.apple.com/forums/thread/840876, Bug FB24179736). Ein async-Überlad steht nicht in der Doku, nur in der SDK-Warnung. Der XPC-Fehlerbericht zu iOS 27 ist ein Einzelfall ohne Apple-Bestätigung.
- `loadItem`: Die Apple-Seite zu `NSItemProvider` führt `loadItem` noch ohne Hinweis; die Veraltung steht nur in der SDK-Warnung („Use `loadObject(ofClass:completionHandler:)`“). `loadObject(ofClass:)` gibt es für `NSItemProviderReading`-Klassen (URL, String), `loadDataRepresentation` und `loadFileRepresentation` sind die Wege für alles andere (https://developer.apple.com/documentation/foundation/nsitemprovider.md).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsShare/ShareViewController.swift` | MODIFY | drei `loadItem`-Zweige: URL und Text über `loadObject`, Mail über `loadDataRepresentation`; `loadedKind`/`string(from:)` entfallen |
| `Shared/Services/SharedContent.swift` | MODIFY | reine Funktion „Bytes einer Mail/eines Textes → String“ (UTF-8, sonst Latin-1), aus dem Controller herausgezogen, damit testbar |
| `LooseEndsTests/SharedContentTests.swift` | MODIFY | Tests für die Dekodierung (UTF-8, Latin-1, leer, ungültig) |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | „Said“-Zeile als ein `Text` mit zwei gestalteten `Text`-Werten in der Interpolation |
| `LooseEnds/Notifications/BackgroundRefresh.swift` | MODIFY | `submitTaskRequest(_:completionHandler:)`, Fehler im Handler geloggt |
| `LooseEnds/Localizable.xcstrings` | MODIFY (nur falls Xcode den Interpolationsschlüssel anlegt) | Schlüssel `%@  %@`, keine Übersetzung nötig |

### Scope Assessment
- Files: 5 (6 mit Katalog)
- Estimated LoC: +60/-45
- Risk Level: MEDIUM (Teilen ist der einzige Pfad, den der Simulator kaum zeigt)

### Technical Approach
Rules-before-model entfällt: reine API-Ablösung, kein Modell im Spiel.
1. **BackgroundRefresh:** `submitTaskRequest(request) { error in … logger.error … }`. `schedule()` bleibt synchron und `@MainActor`; Apple-DTS bestätigt den Main-Thread-Aufruf. Neu: Fehler, die `submit` früher still beim Aufruf warf, kommen jetzt im Handler an und werden geloggt, nicht verschluckt.
2. **TaskDetailView:** `Text("\(kopf)  \(rohtext)")` mit `kopf` = gestalteter `Text` (caption2 semibold, tracking 1) und `rohtext` = gestalteter `Text` (serif subheadline, italic); `foregroundStyle`, `accessibilityLabel(task.rawText)` und Kennung `detailRawText` unverändert. Nachweis: Simulator-Screenshot vorher/nachher (dasselbe Bild).
3. **Share:** URL → `loadObject(ofClass: URL.self)`, Text → `loadObject(ofClass: String.self)`, Mail → `loadDataRepresentation(forTypeIdentifier: emailMessage)` und Dekodierung in der reinen Funktion. Die Probenzeile (#24 AC-1) behält ihren Vertrag: Typkennungen und Art, nie Inhalt; Art ist künftig `url`, `text` oder `data`.

### Alternativen
- **Share, ein einziger Weg:** `loadDataRepresentation` für alle drei Zweige, selbst dekodiert (URL aus den Bytes). Weniger Verzweigung, aber die URL-Dekodierung (Safari liefert teils Bookmark-Daten) wäre eigener Code, den `loadObject` Apple überlässt. Verworfen, bleibt Rückfall, falls `loadObject(URL)` auf dem Gerät fehlschlägt.
- **Share, `Transferable`/`loadTransferable`:** moderner, aber verlangt eigene Typen; kippt die Entscheidung, `SharedContent` auf Strings/URLs aufzubauen. Für eine reine Warnungsbereinigung zu groß.
- **Detail, `AttributedString`:** ein Text aus zwei Läufen, kein neuer Katalogschlüssel. Gleichwertig; Rückfall, falls die Interpolation den Katalog stört oder die Zeile anders umbricht. Kein ADR berührt.
- **BackgroundRefresh, `try await`:** verlangt, `schedule()` async zu machen; drei Aufrufer ändern sich. Kein Gewinn.

### Befunde, die gegen den Plan sprechen
Keiner, der den Plan kippt. Offen bleibt: (a) ob `loadObject(URL)` für alle Absender wie `loadItem` liefert (Safari, Mail, Notizen, Nachrichten) — nur das Gerät zeigt es; (b) ob der XPC-Fehler auf iOS 27 echt ist — der Log zeigt ihn künftig.

### Dependencies
Upstream: `NSItemProvider`, `BGTaskScheduler`, SwiftUI `Text`, Katalog. Downstream: `SharedContent.make`, `LooseEndsApp`/`ContentView` rufen `BackgroundRefresh.schedule()`, UI-Tests lesen `detailRawText`.

### Abnahme
Stufe 1: Unit-Tests (Dekodierung). Stufe 2: Simulator, Detailansicht mit Rohtext als Screenshot, Bau ohne die sechs Warnungen (Log). Stufe 3 ist Pflicht (berührt `LooseEndsShare/` und `LooseEnds/Notifications/`): TestFlight nach Hennings Wort „jetzt ist ein Test möglich“; geprüft werden Teilen aus Safari (Link), Notizen (Text), Mail (Mail), Fotos (Foto), Dateien (Datei).

### Entwurf vor Spec
Entfällt: Die Detailzeile ändert ihr Aussehen nicht, sie wird nur anders zusammengesetzt; der Screenshot-Vergleich ist der Nachweis.

### Open Questions
- [ ] Legt Xcode für die Interpolation einen Katalogschlüssel an, und stört er die Katalogprüfung? (klärt `/30-write-spec` beim Bau; Rückfall `AttributedString`)
