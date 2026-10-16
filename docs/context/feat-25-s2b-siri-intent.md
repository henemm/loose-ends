# Context: feat-25-s2b-siri-intent (#25 Schnitt 2b)

## Request Summary
Siri legt über Apples Reminders-App-Schema (`.reminders.createReminder`) eine Aufgabe in Loose Ends an. Schnitt 2b
baut den Intent, der die Entitäten und die Übersetzung aus 2a (PR #487) mit `SiriCapture.prepare`/`commit`
(Schnitt 1, PR #432) verbindet, dazu die Fehlertexte, die Siri vorliest, und den echten Geocoder.

## Stand vor diesem Schnitt
- Schnitt 1 gemergt: `Shared/Services/SiriCapture.swift`, zwei Schritte `prepare` (async, wirft, schreibt nichts,
  `Geocode` injiziert) und `commit` (MainActor, schreibt, räumt bei Fehler auf). F1/F2/F3/F5 eingearbeitet.
- Schnitt 2a gemergt (#487, 2026-10-16): `LooseEnds/Intents/ReminderSchema.swift` (`ListEntity` inkl. virtueller
  Eingang „Loose Ends“, `ReminderEntity(task:)`, `LocationTriggerEntity`, `SectionEntity`, Enums, Queries) und
  `LooseEnds/Intents/ReminderTranslation.swift` (`input(title:note:dueDate:list:…)` → `SiriCapture.Input`).
- Es gibt **keinen** `@AppIntent(schema:)` im Code. Siri sieht bisher nichts Neues.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Intents/CreateReminderIntent.swift` | NEU: `@AppIntent(schema: .reminders.createReminder)`, `perform` = Übersetzung → `prepare` → `commit` → `ReminderEntity` |
| `LooseEnds/Intents/SiriCaptureError+Dialog.swift` (o. ä.) | NEU: `CustomLocalizedStringResourceConvertible` für alle Fälle von `SiriCaptureError` (9) und `CaptureError` |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY: Fehlertexte de/en (Quellsprache `en`) |
| `LooseEnds/Places/PlaceSearch.swift` | Vorhanden: `MapKitPlaceSearch` (`MKLocalSearch`, ohne Standortrecht) und `FixedPlaceSearch` für UI-Tests. Kandidat für den echten `Geocode` |
| `Shared/Services/SiriCapture.swift` | Ziel des Intents; bleibt unverändert (`typealias Geocode`, Fehler-Enum) |
| `LooseEnds/Intents/ReminderSchema.swift`, `ReminderTranslation.swift` | 2a, werden benutzt, nicht geändert |
| `Shared/Intents/CaptureTextIntent.swift` | Vorbild: `ModelContainerFactory.make()` + `ModelContext` im `perform`, `@MainActor`; bleibt unangetastet (AC-7 aus #25) |
| `LooseEndsTests/IntentExecutionTests.swift` | Vorbild für Intent-Tests. **Falle:** unter Tests liefert `make()` bei jedem Aufruf einen frischen In-Memory-Speicher, ein Test kann die angelegte Aufgabe darüber nicht finden |
| `LooseEndsTests/SiriCaptureTests.swift`, `ReminderTranslationTests.swift`, `ReminderEntityTests.swift` | bestehende Tests der Bausteine |
| `project.yml` | `LooseEnds/` gehört nur zum App-Ziel; Widget/Share schließen `Shared/Intents/*` einzeln aus. Neue Datei unter `LooseEnds/Intents/` braucht **keine** Änderung (in 2a per Bau belegt) |

## Existing Patterns
- Intent-Ausführung im App-Prozess, keine Extension (Schnitt-1-Spec, Entscheidung 3).
- Testbarkeit: Logik in eine Funktion mit übergebenem `ModelContext` und `Geocode` legen; `perform` ist nur Kleber.
  Sonst ist die Wirkung wegen des frischen Test-Speichers nicht prüfbar.
- Fehler an Siri: Enum mit `CustomLocalizedStringResourceConvertible`, in `perform` geworfen; das System verpackt
  es in `AppIntentError` und liest den Text vor (Apple-Doku `AppIntentError`, Forum 713559). Gibt es zusätzlich
  `CustomAppIntentErrorConvertible`, gewinnt dieses.
- Geocoding: In der App gibt es schon `MKLocalSearch` (`PlaceSearch`); Apples Nachfolger von `CLGeocoder` ist
  `MKGeocodingRequest` (iOS 26). Beides kommt ohne Standortrecht aus.
- Ort mit fester Region 150 m (`TaskPlace`), Herkunft `.user`, Grund „Siri“.

## Dependencies
- Upstream: `SiriCapture`, `ReminderTranslation`, `ReminderEntity`, `ModelContainerFactory`, `CatalogService`,
  `PlaceEditing`, `TaskPlace`, `GeoToolbox.PlaceDescriptor`, MapKit.
- Downstream: Siri / Apple Intelligence (System), Kurzbefehle-App. Nach dem Speichern greift die normale
  Veredelung (ADR-4), die Ortsmitteilung (#240) und CloudKit.

## SDK-Abgleich (iOS-27.1-SDK, Xcode lokal)
- `AppIntents.swiftinterface` kennt unter `.reminders`: `createReminder`, `updateReminder`, `deleteReminders`,
  `createList`, `createSection`, alle `@available(anyAppleOS 27.0)`, `watchOS unavailable`.
- Die Parameterliste steht nicht in der Schnittstelle, sondern in den Schema-Metadaten; das Makro verlangt **alle**
  Parameter (Recherche, Fallbericht Mindwtr #915). Sicherungsstand `origin/wip/25-siri-sicherung` deklarierte:
  `title`, `list: ListEntity?`, `note: AttributedString?`, `dueDate: DateComponents?`, `isFlagged: Bool?`,
  `images: [IntentFile]`, `tags: Set<String>`, `urls: [URL]`, `recurrence: Calendar.RecurrenceRule?`,
  `locationTrigger: LocationTriggerEntity?`, `section: SectionEntity?`; Rückgabe `ReturnsValue<ReminderEntity>`.
  Muss per vollem Bau (Metadaten-Schritt) belegt werden, nicht per Übersetzen (Memory „App-Schema-Spike: voller Bau“).

## Recherche (Quellen)
- Apple Forum, App Intents (iOS 27 Beta 4): `CreateReminderIntent` wird nie aufgerufen; Siri leitet „add eggs to my
  grocery list in AppName“ an das alte `INAddTasksIntent`; andere bekommen „I can't add items to your lists in …“.
  https://developer.apple.com/forums/tags/app-intents , https://developer.apple.com/forums/tags/sirikit
- Fehler vorlesen: https://developer.apple.com/forums/thread/713559 ,
  https://developer.apple.com/documentation/appintents/appintenterror
- Geocoding: https://developer.apple.com/forums/thread/833636 (MKGeocodingRequest), https://developer.apple.com/forums/thread/794546
- Fremde Umsetzungen: https://github.com/dongdongbh/Mindwtr/issues/915 , https://github.com/sudopark/TodoCalendar/issues/801

## Existing Specs
- `docs/specs/intents/feat-25-s1-siri-capture.md` — Schnitt 1 (prepare/commit, Fehlerfälle)
- `docs/specs/intents/feat-25-s2a-schema-entitaeten.md` — Schnitt 2a
- `docs/context/feat-25-s2-siri-intent.md` — Kontext/Analyse für 2a+2b, Abschnitt „Befunde, die gegen den Plan sprechen“

## Risks & Considerations
- **Siri ruft den Intent womöglich nie** (Forum, Beta 4). Plan aus 2a: Gerätestufe zuerst mit einem Intent, der
  nur den Titel verarbeitet; zeigt sich Ablehnung, stoppt 2b vor dem Rest. Prüfen, ob iOS 27.0/27.1 final das
  Verhalten geändert hat. Rückfall `INAddTasksIntent` ist #446.
- **Ohne Apple Intelligence greift das Schema nie** (#446).
- **Nicht automatisierbar:** Siri-Sprache lässt sich weder im Simulator noch per UI-Test auslösen. Belegbar sind
  `perform` mit übergebenem Speicher (Unit) und die Kurzbefehle-Ausführung; der echte Siri-Weg nur auf dem Gerät
  über TestFlight (Stufe 3), und nur nach Hennings „jetzt ist ein Test möglich“.
- **Gerätestufe greift?** Neue Dateien unter `LooseEnds/Intents/` stehen nicht in der Pfadliste (dort steht
  `Shared/Intents/`). Siri ist trotzdem „Erfassung von außerhalb der App“; das Ziel der Liste trifft es. In der
  Analyse entscheiden, ehrlich: Siri kann nur das Gerät zeigen.
- **Geocoder ohne Netz / ohne Treffer** → `placeNotFound` (schon in Schnitt 1). Mehrdeutige Treffer: erster Treffer
  oder Ablehnung? Offen für die Analyse.
- **Container im Intent:** `ModelContainerFactory.make()` je Aufruf wie `CaptureTextIntent`; während die App läuft,
  zwei Container auf demselben Speicher (heute schon so, funktioniert).
- **Fehlertexte:** `unmappableRepeat` trägt eine Menge von Gründen, `unknownTag` einen Namen; die Texte müssen
  das ohne Technik sagen. Deutsch und Englisch, Quellsprache des Katalogs ist Englisch.
- Scoping: Intent ~60 LoC, Fehlertexte ~60 LoC, Katalog ~80 Zeilen JSON, Tests ~100 LoC; knapp an 250.

## Analysis

### Type
Feature (#25 Schnitt 2b, M2 Siri und Orte)

### Belege aus dieser Analyse (2026-10-16)
- **Probebau (Wegwerf-Kopie, `sim.sh build`, voller Bau inkl. „Extract App Intents Metadata“):** `@AppIntent(schema:
  .reminders.createReminder)` mit genau 11 Parametern (`title: String`, `list: ListEntity?`, `note: AttributedString?`,
  `dueDate: DateComponents?`, `isFlagged: Bool?`, `images: [IntentFile]`, `tags: Set<String>`, `urls: [URL]`,
  `recurrence: Calendar.RecurrenceRule?`, `locationTrigger: LocationTriggerEntity?`, `section: SectionEntity?`), Rückgabe
  `some IntentResult & ReturnsValue<ReminderEntity>` → **Build Succeeded**, `extract.actionsdata` enthält
  `assistantDefinedSchemas: [{domain: reminders, name: CreateReminderIntent, version: 1.0.0}]` und alle 11 Parameter.
  **Keine** Warnung über fehlende Domänen-Intents: `updateReminder`/`deleteReminders`/`createList` sind nicht Pflicht.
  Kein `project.yml`-Eintrag nötig.
- **AppIntentsTesting (iOS 27) ist unbrauchbar:** Wegwerf-UI-Test `IntentDefinitions(bundleIdentifier:).intents
  ["CreateReminderIntent"].makeIntent(...).run()` übersetzt und startet, scheitert im iOS-27.0-Simulator mit
  `AppIntentsServicesSecurityErrorDomain Code=803 "Unable to run internal tests on a Customer build"`. Recherche: Apple
  sperrt die Ausführung auf Nicht-Apple-internen Systemen, Simulator und Gerät; kein Schalter
  (https://github.com/jaguero21/CarpeCarb/pull/46, https://developer.apple.com/videos/play/wwdc2026/295/).
- **Kurzbefehle-App** (`com.apple.shortcuts`) ist im iOS-27-Simulator vorhanden → Simulator-Durchlauf über Kurzbefehle
  möglich (von mir bedient, Screenshots als Beleg).
- **Siri ruft den Schema-Intent nur mit Apple Intelligence.** Der Beta-4-Bericht „nie aufgerufen“ ist erklärt: Gerät ohne
  Apple Intelligence; ohne AI nimmt Siri SiriKit `INAddTasksIntent` (#446). https://developer.apple.com/forums/thread/838792
  Ob das Schema mit deutscher Siri greift: nicht belegt, nur am Gerät prüfbar.
- **Geocoding:** `CLGeocoder` seit iOS 26 veraltet; Nachfolger `MKGeocodingRequest(addressString:)` (`init?`,
  `try await request.mapItems`), kein Standortrecht, mehrere Treffer möglich, Netz nötig.
  https://developer.apple.com/documentation/mapkit/mkgeocodingrequest
- **Fehler an Siri:** Fehler mit `CustomLocalizedStringResourceConvertible` werfen, das System verpackt ihn in
  `AppIntentError` und liest den Text; `CustomAppIntentErrorConvertible` (neu in 27) nur bei Bedarf an Rückfragen.
  https://developer.apple.com/documentation/appintents/appintenterror
- In Kurzbefehle erscheinen alle 11 Parameter, verstecken geht nicht (https://developer.apple.com/forums/thread/838658).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Intents/CreateReminderIntent.swift` | CREATE | Schema-Intent; `perform` = Kleber; testbarer Kern `create(_ input:, in:, geocode:) async throws -> TaskItem` (Übersetzung → `prepare` → `commit`), `images.count` → `imageCount` (~70 LoC) |
| `LooseEnds/Places/Geocoding.swift` | CREATE | `SiriCapture.Geocode` über `MKGeocodingRequest`, erster Treffer, `nil`/kein Treffer → nil; unter `--ui-testing` feste Werte (~25 LoC) |
| `LooseEnds/Intents/SiriCaptureError+Dialog.swift` | CREATE | `CustomLocalizedStringResourceConvertible` für 9 Fälle `SiriCaptureError` + `CaptureError` (~60 LoC) |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | 10 Fehlertexte en/de (~80 Zeilen JSON) |
| `LooseEndsTests/CreateReminderIntentTests.swift` | CREATE | Kern mit In-Memory-Speicher und Fake-Geocode: alle Felder, Fehlerfälle ohne Rest-Aufgabe, `perform`-Smoke, Texte vorhanden (~110 LoC) |
| `CLAUDE.md` | MODIFY | Geräteliste um `LooseEnds/Intents/` ergänzen (Siri = Erfassung von außerhalb der App) |

### Scope Assessment
- Files: 5–6
- Estimated LoC: ~+265 (Swift) + ~80 Zeilen Katalog → über dem Limit von 250 → **zwei Schnitte**
- Risk Level: MEDIUM — Code-Risiko niedrig (neue Dateien nur im App-Ziel, `CaptureTextIntent` und `AppShortcutsProvider`
  unberührt, kein CloudKit-Schema), Produkt-Risiko hoch (ob Siri den Weg nimmt, zeigt nur das Gerät).

### Technical Approach
Empfehlung: **2b-1 zuerst den Intent mit allen Feldern** (Kern, Kleber, Geocoder, Tests, Geräteliste; ~200 LoC). Alle
Felder werden gespeichert oder sichtbar abgelehnt — Henning, 2026-10-06 „erst alles bauen“ ist erfüllt; abgelehnt wird
mit Siris allgemeinem Fehlersatz. Nach Merge TestFlight-Bau, Henning prüft am iPhone 16 Pro (Apple Intelligence an), ob
Siri den Weg nimmt. **2b-2 danach** die vorgelesenen Fehlertexte de/en (~60 LoC + Katalog). Grund der Reihenfolge: Das
größte Risiko (nimmt Siri den Weg überhaupt, auch auf Deutsch?) wird so früh wie möglich am Gerät geklärt; bleibt Siri
stumm, fällt 2b-2 weg oder wandert zum Rückfall #446.

Alternative (Plan-Bewertung): erst Geocoder + Fehlertexte + Kern (2b-1), Intent zuletzt (2b-2). Vorteil: Siri sieht erst
Fertiges. Nachteil: Der Gerätebefund kommt einen Schnitt später, Arbeit an Texten womöglich umsonst.

Nachweis: Unit-Tests des Kerns (In-Memory, Fake-Geocode) + `perform`-Smoke; Simulator-Durchlauf von mir über die
Kurzbefehle-App mit Screenshots; Siri selbst nur am Gerät über TestFlight (Stufe 3) nach Hennings „jetzt ist ein Test
möglich“. Kein automatisierter UI-Test der Kurzbefehle-App (Apple-UI, ändert sich je Beta, geringe Beweiskraft).

Geocoder-Entscheidung (Tech Lead): `MKGeocodingRequest`, nicht `MapKitPlaceSearch` (Geschäftssuche, verwirft Treffer ohne
Namen). Mehrere Treffer → erster (MapKit sortiert nach Relevanz); Ablehnung hieße Scheitern bei jeder unscharfen Adresse.
Siri liefert meist eine Koordinate mit; der Geocoder greift nur bei reiner Adresse.

### Dependencies
`SiriCapture` (S1), `ReminderTranslation`/`ReminderSchema` (S2a), `ModelContainerFactory`, MapKit (`MKGeocodingRequest`).
Downstream: Siri/Apple Intelligence, Kurzbefehle, Veredelung (ADR-4), Ortsmitteilung (#240), CloudKit. Rückfall ohne
Apple Intelligence: #446. Keine Überschneidung mit offenem PR #500 (Mac-Start, Views).

### Befunde, die gegen den Plan sprechen
- Kein automatisierter Nachweis des Siri-Wegs möglich (AppIntentsTesting gesperrt, s. o.).
- Deutsche Siri + Schema unbelegt; ohne Apple Intelligence greift das Schema nie (#446).
- Neuer Eintrag „Erinnerung erstellen“ neben „Capture a task“ in Kurzbefehle mit allen 11 Feldern (nicht versteckbar).

### Open Questions
- [x] Reihenfolge der zwei Schnitte — **Henning, 2026-10-16: „Siri zuerst“.** 2b-1 = Intent mit allen Feldern, Geocoder,
  Tests, Geräteliste (allgemeiner Fehlersatz); danach TestFlight und Gerätetest; 2b-2 = vorgelesene Fehlertexte de/en.
  Die Spec dieses Workflows beschreibt nur 2b-1; 2b-2 wird eigener Workflow.
