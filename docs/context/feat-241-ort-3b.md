# Context: feat-241-ort-3b

## Request Summary
#241 Schnitt 3b (Rest von #226 Schnitt 3): im Orts-Suchblatt „Aktueller Ort“ und Zuhause/Arbeit anbieten, den Hinweis
„Standort aus“ zeigen und beim Setzen eines Orts, an dem man schon ist, „Erinnert beim nächsten Ankommen“ sagen.
Schnitt 3a (Kartensuche, Segment, Entfernen, Hinweise „nicht überwacht“/„Mac“, Ortszeichen) ist seit PR #259 gemergt.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/PlaceSection.swift` | `PlaceSection` (Ortszeile, Segment, Footer-Hinweise) und `PlaceSearchSheet` (Suchfeld + Treffer). Hier kommen „Aktueller Ort“, Zuhause/Arbeit, „Standort aus“-Hinweis dazu. |
| `Shared/Services/PlaceEditing.swift` | rein: `set`, `setEvent`, `remove`, `note(for:among:isMac:)` mit `Note.{notWatched, macOnly}`. Kommentar dort: „The location permission note comes with Schnitt 3b“. |
| `Shared/Models/TaskPlace.swift` | Wertetyp (name, lat, lon, event), Radius fest 150 m; als ein Feld `.place` revidiert (`FieldCodec`). |
| `LooseEnds/Places/PlaceSearch.swift` | `PlaceHit`, `PlaceSearching`, `MapKitPlaceSearch`, `FixedPlaceSearch` (UI-Test-Treffer). |
| `LooseEnds/Notifications/PlaceNotificationCenter.swift` | iOS-only. `SystemPlaceLocation` (CLLocationManager-Hülle, `permission`, `requestWhenInUseAuthorization`), Protokoll `PlaceLocating`; der Reconcile fragt „Beim Verwenden“ einmal, sobald ein Ort zu überwachen ist, im Vordergrund. |
| `Shared/Notifications/PlaceNotifications.swift` | `Permission` (.notDetermined/.whenInUse/.always/.refused), Entscheidung zur Abfrage. |
| `Shared/Persistence/ModelContainerFactory.swift` | `LooseEndsSchema.models`: ein neues Modell (`SavedPlace`) wird hier eingetragen. |
| `cloudkit/schema.ckdb` | Neue Felder/Typen müssen hier stehen (`scripts/test_cloudkit_schema.py`), Import in Development per CI, Production-Deploy per Console-Klick. |
| `LooseEnds/Info.plist`, `project.yml`, `Resources/*/InfoPlist.strings` | `NSLocationWhenInUseUsageDescription` steht schon (Schnitt 2). Kein Eingriff nötig. |
| `LooseEndsTests/PlaceEditingTests.swift`, `LooseEndsUITests/PlaceSmokeTests.swift` | bestehende Tests, Muster für neue (feste Suche unter `--ui-testing`). |

## Existing Patterns
- Reine Regeln in `Shared/Services` (`PlaceEditing`), Ansicht dünn; jede Änderung eine Nutzer-Revision, gleiche Eingabe schreibt nichts.
- Systemzugriffe hinter Protokoll mit Ersatz für Tests (`PlaceLocating`, `PlaceSearching` → `FixedPlaceSearch`).
- Eindeutigkeit bei CloudKit-Dubletten: deterministischer Gewinner (Kontexte #157); die Spec sieht dasselbe für `SavedPlace` vor (ältester gewinnt).
- Neue Modelle nur additiv (Production nur additiv).

## Befund zum Ist-Stand
- `SavedPlace` existiert nicht im Code (Schnitt 1 hat es nicht geliefert). Neues Modell → `LooseEndsSchema.models`, `schema.ckdb`, Production-Deploy.
- Die Berechtigung wird nicht beim Setzen im Detail gefragt, sondern vom Reconcile (`PlaceNotificationCenter`), wenn ein Ort überwacht werden soll. Der Detail-Hinweis „Standort aus“ braucht nur den Lesezugriff auf `permission`. „Aktueller Ort“ braucht eine einmalige Standortabfrage (`requestLocation`) und, falls noch nicht entschieden, die Frage „Beim Verwenden“.
- `PlaceNotificationCenter`/`SystemPlaceLocation` sind `#if os(iOS)`; der Mac braucht einen eigenen Zweig (Mac erinnert nicht; der Hinweis „Reminds you on iPhone and Watch“ steht schon).
- `-le-seed-place` ist im Code nicht mehr vorhanden (nichts zu entfernen).
- Messbefund 2026-10-08 (#226 S2b AC-12): ein Ort, an dem man bereits ist, löst nicht sofort aus. Hinweis „Erinnert beim nächsten Ankommen.“ (Wortlaut kommt in den Entwurf). Beleg: `docs/artifacts/feat-226-schnitt-2b/simulator-durchlauf.md`.

## Dependencies
- Upstream: CoreLocation (`CLLocationManager.requestLocation`, Swift 6), MapKit (Treffer), `RevisionService`, `FieldCodec`.
- Downstream: `PlaceReminders.plan`, `PlaceDelivery`, Liste (`TaskRow`, Ortszeichen), Siri-Übersetzung nutzt `TaskPlace`.

## Existing Specs
- `docs/specs/feat-226-ortserinnerungen.md` (Entwurf, Datenmodell, Antworten F1–F7; Zuhause/Arbeit: „Henning legt sie einmal selbst fest“, 2026-10-06)
- `docs/specs/feat-226-schnitt-3a-ort-im-detail.md`, `feat-226-schnitt-4-zustellung.md`, `feat-226-zustellung.md` (unter `docs/context/`)

## Risks & Considerations
- Gerätestufe 3 greift (`Shared/Persistence/`, Standort): Test nur über TestFlight, nichts auf Hennings Geräten ohne sein Wort.
- Der Simulator kann „Aktueller Ort“ nur über einen vorgetäuschten Standort (`simctl location`) zeigen. Die echte Berechtigungsfrage ist im Simulator prüfbar, ein echter Ortswechsel nicht.
- Neues CloudKit-Modell: Production-Deploy-Klick vor dem TestFlight-Bau; mit anderen Modelländerungen bündeln.
- Scoping: 4–5 Dateien / ±250 LoC. SavedPlace + Standortabfrage + Blatt + Hinweis können das sprengen → 3b ggf. in zwei Teile (Aktueller Ort + Hinweise / Zuhause + Arbeit).
- Alternative zu `SavedPlace` (Pflicht laut CLAUDE.md): „Zuletzt verwendet“ aus Orten bestehender Aufgaben. Kein Modell, kein Deploy; kippt Hennings Entscheidung vom 2026-10-06 (F2), deshalb in der Analyse messen und ihm vorlegen.

## Analysis

### Type
Feature (Schnitt 3b von #226). Kein Fehler, daher keine Reproduktion; die Frage „hat es bisher funktioniert?“ entfällt.

### Recherche (vor allem anderen, 2026-10-23)
- `CLLocationManager.requestLocation()` ist in der aktuellen Dokumentation unverändert und nicht ersetzt: ein einmaliger Standort, dann stoppt der Dienst; der Delegat muss `didUpdateLocations` und `didFailWithError` umsetzen; bei Zeitnot kommt ein ungenauerer Wert statt eines Fehlers, sonst `CLError.locationUnknown`. Quelle: https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation()
- Der Strom `CLLocationUpdate.liveUpdates` ist der neuere Weg für laufende Updates. Für einen einzelnen Punkt ist er kein Gewinn. Quelle: https://developer.apple.com/documentation/corelocation/cllocationupdate
- Zu `CLServiceSession` und zum Stand in iOS 26/27 fand die Suche nichts Belastbares (Seite 404). Das bleibt offen und wird in der Spec als „im Simulator belegen“ geführt.
- `NSUbiquitousKeyValueStore`: 1 MB gesamt, 1024 Schlüssel, Abgleich ohne Zeitgarantie (bis ca. 30 s nach Start berichtet). Reicht für zwei Orte. Quelle: https://developer.apple.com/forums/thread/785350

### Befund: Spec und Code weichen ab
- Die Spec (#226) sagt, die Berechtigung werde gefragt, wenn Henning zum ersten Mal einen Ort setzt. Im Code fragt der Abgleich in `PlaceNotificationCenter.askIfNeeded` (einmal, im Vordergrund, sobald ein Ort zu überwachen ist). Setzen im Detail fragt nichts. „Standort aus“ liest daher nur `permission`.
- `SavedPlace` fehlt im Code, `-le-seed-place` ebenfalls (nichts zu entfernen).
- Der Hinweis „Erinnert beim nächsten Ankommen“ braucht zwei Dinge: ein Ereignis „Ankommen“ und den Befund, dass man schon dort ist. Dafür braucht es einen aktuellen Standort. Ohne Berechtigung oder Standort: kein Hinweis (nicht raten).

### Regelweg, kein Modell
Alles ist Regel: Abstand (Haversine) zwischen Standort und Ort ≤ 150 m (Radius) plus gemeldete Ungenauigkeit ⇒ „schon dort“. „Ohne Modell geht es nicht, weil …“ entfällt, denn kein Modell kommt vor.

### Affected Files (Vorschlag Schnitt 3b-1)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Places/CurrentLocation.swift` | CREATE | Protokoll `CurrentLocating` (Erlaubnis lesen, einmal Standort holen), `SystemCurrentLocation` (iOS, `requestLocation`), `FixedCurrentLocation` (UI-Test). Mac: nicht angeboten. |
| `Shared/Services/PlaceEditing.swift` | MODIFY | `Note.locationOff`; reine Regel `isAlreadyThere(place:at:)`; `Note`-Reihenfolge: nicht überwacht > Standort aus > Mac. |
| `LooseEnds/Views/PlaceSection.swift` | MODIFY | Zeile „Aktueller Ort“ im Suchblatt, Hinweis „Standort aus“, Hinweis „Erinnert beim nächsten Ankommen“. |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Neue Texte DE/EN. |
| `LooseEndsTests/PlaceEditingTests.swift` | MODIFY | Regeln für Abstand, Hinweisreihenfolge. |
| `LooseEndsUITests/PlaceSmokeTests.swift` | MODIFY | Aktueller Ort wählen, Hinweise sichtbar. |

### Scope Assessment
- 3b-1: 6 Dateien (eine davon Texte), ca. +200 LoC. Knapp über „4–5 Dateien“; Texte und Tests zählen mit. Vorschlag: 3b-1 so lassen oder die Texte in die Zählung der Ansicht rechnen; sonst teilen (Aktueller Ort | Hinweise).
- 3b-2 (Zuhause/Arbeit): eigener Schnitt, siehe unten.
- Risk Level: MEDIUM (Standortberechtigung, Gerät; kein Datenmodell, kein Schema in 3b-1).

### Technical Approach
1. **Schnitt 3b-1, ohne neues Modell:** „Aktueller Ort“ (nur iPhone/iPad), Hinweis „Standort aus“, Hinweis „Erinnert beim nächsten Ankommen“. Kein CloudKit-Deploy, kein `project.yml`, keine `Info.plist` (Text `NSLocationWhenInUseUsageDescription` steht seit Schnitt 2).
2. **Schnitt 3b-2, Zuhause/Arbeit:** siehe Alternativen.
3. Die Standortabfrage liegt in `LooseEnds/Places/`, nicht in `LooseEnds/Notifications/`. Die Geräteliste (CLAUDE.md) wird dadurch nicht berührt; der Abgleich und `PlaceNotificationCenter` bleiben unangetastet. Ehrlich dazu: ein echter Standort lässt sich im Simulator nur vorgetäuscht zeigen (siehe Risiken).

### Alternativen (Pflicht)
| | Weg | Preis | Kippt |
|---|---|---|---|
| A (Spec) | `SavedPlace` als SwiftData-Modell, CloudKit | neues Schema, Production-Deploy per Konsolen-Klick, Dublettenregel | – |
| B | Zuhause/Arbeit im iCloud-Schlüsselspeicher (`NSUbiquitousKeyValueStore`, wie `FieldSettingsStore` und `DueNotificationCenter` es schon nutzen) | kein Schema, kein Deploy; Abgleich ohne Zeitgarantie, bei zwei Orten unkritisch | Teil der Spec „eigenes Modell `SavedPlace`“ (F2-Umsetzung, nicht das Ziel) |
| C | „Zuletzt verwendet“: Orte bestehender Aufgaben anbieten, Zuhause/Arbeit entfällt | nichts Neues zu speichern; erkennt Zuhause nicht als Zuhause | Hennings Entscheidung vom 2026-10-06 (Zuhause/Arbeit legt er selbst fest) |
Empfehlung: **B**. Es erfüllt, was Henning wollte (einmal selbst festlegen, danach oben im Blatt), ohne Schema und ohne seinen Klick in der Konsole. A bleibt als Rückfall, falls der Abgleich per Schlüsselspeicher Probleme macht. Messung der Alternative C auf Hennings Daten ist nicht möglich (Daten liegen auf seinen Geräten, gesperrt ohne sein Wort); darum wird C nur als Alternative genannt, nicht gemessen.
Für die Ortsabfrage selbst: Alternative zu „Aktueller Ort“ als eigene Zeile ist, den aktuellen Ort ganz oben als ersten Treffer der Suche zu führen (kein eigener Tipp). Vorschau unten.

### Dependencies
CoreLocation (`requestLocation`), `PlaceReminders.plan`, `RevisionService`, `FieldCodec`, MapKit-Suche (`PlaceSearching`), `FieldSettingsStore`-Muster für B.

### Risiken
- Simulator: Standort muss vorgetäuscht werden. `sim.sh` kennt dafür kein Unterkommando; das Werkzeug wird um `location <lat> <lon>` ergänzt (nicht an Henning weitergereicht). Der UI-Test nutzt unter `--ui-testing` einen festen Standort (wie `FixedPlaceSearch`); er prüft damit nur den halben Weg. Der echte Weg (`SystemCurrentLocation`) wird deshalb im Simulator mit vorgetäuschtem Standort einmal von Hand durchgespielt und belegt.
- Mac: `requestLocation` braucht dort einen Sandbox-Schlüssel (`project.yml`). Darum wird „Aktueller Ort“ am Mac nicht angeboten (er erinnert dort ohnehin nicht).
- Berechtigung verweigert: „Aktueller Ort“ bleibt sichtbar und führt zu einer grauen Zeile „Standort ist in den Einstellungen aus“; kein Fehlerdialog.

### Open Questions
- [ ] Entwurf (Vorschau) freigeben: Aktueller Ort als eigene Zeile oder als erster Treffer.
- [ ] Zuhause/Arbeit: B (Schlüsselspeicher) statt A (`SavedPlace`) — kippt den Modellteil der Spec.
- [ ] 3b-1 mit 6 Dateien so schneiden, oder teilen?

### Entscheidungen Henning (2026-10-23, AskUserQuestion)
- **Entwurf A** (eigene Zeilen im Suchblatt, Hinweise unter der Ortszeile). Vorschau: `docs/artifacts/feat-241-ort-3b/entwurf.html` (veröffentlicht: https://claude.ai/artifact/SEtKup2ZjLFphVrqPnCXax), Ist-Bilder `heute-suche.png`, `heute-detail.png` aus `PlaceSmokeTests` im Simulator.
- **Zuhause/Arbeit im iCloud-Schlüsselspeicher** statt `SavedPlace`: kein Schema, kein Deploy, kein Konsolen-Klick. Kippt den Modellteil der Spec (`SavedPlace`), nicht ihr Ziel.
- **Alles in einem Schnitt** (gegen meine Empfehlung 3b-1/3b-2). Schätzung für die Spec: ca. 8 Dateien, ca. +400 LoC (CurrentLocation, SavedPlaces-Speicher, PlaceEditing, PlaceSection, Texte, Unit-Tests, UI-Test, Simulator-Standort in `sim.sh`) — über den Limits 4–5 Dateien / ±250 LoC; die Spec hält das als bewusste, von Henning gewählte Überschreitung fest und teilt die Tests in klar getrennte Dateien.
- Offene Beobachtung (nicht Teil dieses Tickets): im Detail steht „Place“ zweimal übereinander (graue Zeile und Kopf „PLACE“) — Ist-Bild `heute-detail.png`. Eigenes Ticket, wenn bestätigt.
