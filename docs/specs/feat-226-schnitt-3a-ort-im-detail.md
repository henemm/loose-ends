---
entity_id: feat-226-schnitt-3a-ort-im-detail
type: feature
created: 2026-10-07
updated: 2026-10-07
status: draft
workflow: feat-226-ortserinnerungen
---

# Spec: #241 Schnitt 3a — Ort im Detail setzen, ändern, entfernen (ohne Standort)

## Approval

- [x] Approved (Henning, 2026-10-07)

## Purpose

Henning gibt einer Aufgabe im Detail einen Ort, ändert ihn und entfernt ihn. Den Ort findet er über die Kartensuche
(Adresse oder Geschäft), dazu wählt er „Ankommen“ oder „Verlassen“. In der Liste zeigt ein graues Ortszeichen, dass
die Aufgabe einen Ort hat. Entwurf und Antworten F1–F7: `docs/specs/feat-226-ortserinnerungen.md`.

#241 ist für die 250-Zeilen-Grenze zu groß und berührt mit dem Standort die Geräteliste. Deshalb zwei Teile:

| Teil | Inhalt | Geräteliste |
|---|---|---|
| **3a (diese Spec)** | Ortszeile, Suchblatt mit Kartensuche, Segment, Entfernen, Hinweise „nicht überwacht“ und „Mac“, Ortszeichen in der Liste | nein: Die Kartensuche braucht keine Standort-Berechtigung |
| 3b | „Aktueller Ort“, Berechtigung samt `Info.plist`-Text, Hinweis „Standort aus“, Zuhause/Arbeit (`SavedPlace`, neues Modell in `Shared/Persistence`) | ja |

Erinnert wird erst mit Schnitt 4 (#240 Teil B). Bis dahin ist der Ort gespeichert und sichtbar, die Mitteilung kommt noch
nicht.

## Source

- **Neu:** `LooseEnds/Views/PlaceSection.swift`: Abschnitt im Detail mit Suchblatt
- **Neu:** `LooseEnds/Places/PlaceSearch.swift`: Kartensuche (`MKLocalSearch`) und eine feste Suche für UI-Tests
- **Neu:** `Shared/Services/PlaceEditing.swift`: rein, Ort setzen, Ereignis wechseln, entfernen, Hinweis wählen
- **Geändert:** `LooseEnds/Views/TaskDetailView.swift` (Abschnitt unter dem Kalender), `LooseEnds/Views/TaskRow.swift`
  (Ortszeichen)

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Services/PlaceEditing.swift` | NEU | `set(_ place:on:)`, `setEvent(_:on:)`, `remove(from:)`: jede Änderung über `RevisionService.set(.place, …)` mit Autor `.user`, gleiche Eingabe schreibt nichts. `note(for:among:isMac:) -> Note?` mit `.notWatched` (offen, Ort, steht in `PlaceReminders.plan(…).unwatched`) und `.macOnly`. |
| `LooseEnds/Places/PlaceSearch.swift` | NEU | `protocol PlaceSearching { func places(matching:) async throws -> [PlaceHit] }`. `MapKitPlaceSearch` mit `MKLocalSearch` (Freitext, Region = keine, Ergebnis: Name, Ort, Koordinate). `FixedPlaceSearch` unter `--ui-testing`: zwei feste Treffer, kein Netz. |
| `LooseEnds/Views/PlaceSection.swift` | NEU | Ohne Ort: Zeile „Add place“. Mit Ort: Zeile mit 📍 und Namen (Akzent, tippbar, öffnet die Suche), Wischen „Remove“, Segment Ankommen/Verlassen, grauer Satz („Reminds you when you arrive." / „… leave.“) und darunter der Hinweis aus `PlaceEditing.note`. Suchblatt: Suchfeld, Treffer als Name + Ort; ein Tipp setzt den Ort (Ereignis bleibt, bei neuem Ort: Ankommen) und schließt das Blatt. |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | `PlaceSection(task:)` nach dem Kalender-Abschnitt. |
| `LooseEnds/Views/TaskRow.swift` | MODIFY | Merkmal „place“ mit `location` und dem Namen, grau, nach der Fälligkeit. Die ersten drei Merkmale gewinnen wie bisher. |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Texte auf Deutsch |
| `LooseEndsTests/PlaceEditingTests.swift` | NEU | Unit-Tests |
| `LooseEndsUITests/PlaceSmokeTests.swift` | NEU | Simulator-Beleg mit der festen Suche |

Erwartet: rund 240 Zeilen Produktcode, 140 Zeilen Tests.

**Kein Pfad der Geräteliste berührt:** `project.yml`, `Info.plist`, `Shared/Persistence/` und `LooseEnds/Notifications/`
bleiben unverändert. MapKit braucht für die Suche weder Berechtigung noch Entitlement.

## Implementation Details

- **Name des Orts:** Name des Treffers, dazu der Ort, wenn er nicht schon im Namen steckt („Bauhaus, Hamburg-Altona“).
  `TaskPlace(name:latitude:longitude:event:)`; ein Treffer ohne Koordinate erscheint nicht.
- **Suche:** startet nach 0,3 s Ruhe im Feld (`.task(id: query)`) und ab zwei Zeichen. Ein Fehler (offline) zeigt
  „No places found.“, wird geloggt und nie still geschluckt.
- **Ereignis:** Das Segment schreibt eine Revision über `PlaceEditing.setEvent`; der Ort bleibt.
- **Entfernen:** Wischen auf die Ortszeile, Revision mit leerem neuen Wert.
- **Hinweise:** „Not watched right now: more than 20 places are open.“ und auf dem Mac „Reminds you on iPhone and Watch.“,
  grau, wie der Kalender-Hinweis.
- **Feste Suche:** Unter `--ui-testing` liefert die App „Bauhaus · Hamburg-Altona“ und „Bauhaus · Hamburg-Wandsbek“ mit
  festen Koordinaten, damit der UI-Test ohne Netz und ohne Apples Suchdienst läuft.

## Test Plan

`PlaceEditingTests` (TDD RED zuerst):
- `set` schreibt den Ort mit einer Revision vom Nutzer, derselbe Ort noch einmal schreibt nichts.
- `setEvent` ändert nur das Ereignis, Name und Koordinate bleiben, eine Revision; ohne Ort tut es nichts.
- `remove` leert den Ort mit einer Revision; ohne Ort tut es nichts.
- `note`: 21 offene Aufgaben mit Ort → die mit dem niedrigsten Rang bekommt `.notWatched`, die anderen nichts; auf dem Mac
  `.macOnly`; ohne Ort nie ein Hinweis.

`PlaceSmokeTests` (Simulator, feste Suche): Aufgabe erfassen → Detail → „Add place“ → „Bau“ tippen → „Bauhaus ·
Hamburg-Altona“ → Ortszeile zeigt den Namen → „Leave“ → Satz wechselt → zurück: Ortszeichen in der Zeile → Detail →
Wischen „Remove“ → „Add place“ ist wieder da. Mit Bildschirmfotos als Anhang.

## Acceptance Criteria

- **AC-1 Ort in zwei Tippern:** Given eine Aufgabe ohne Ort / When „Add place“ und ein Treffer getippt werden / Then trägt
  sie den Ort mit „Ankommen“, und es gibt genau eine Revision vom Nutzer.
- **AC-2 Ereignis:** Given eine Aufgabe mit Ort / When „Verlassen“ gewählt wird / Then bleibt der Ort, das Ereignis wechselt,
  eine Revision.
- **AC-3 Entfernen:** Given eine Aufgabe mit Ort / When die Ortszeile weggewischt wird / Then hat sie keinen Ort, eine
  Revision, „Add place“ ist wieder da.
- **AC-4 Liste:** Eine Aufgabe mit Ort zeigt in der Zeile das graue Ortszeichen.
- **AC-5 Nichts fällt still weg:** Eine Aufgabe über der 20er-Grenze zeigt im Detail „Wird gerade nicht überwacht“.
- **AC-6 Regression:** Unit, Build und UI Smoke grün.

## Alternativen (verworfen)

- **`MKLocalSearchCompleter`** (Vorschläge beim Tippen): braucht danach eine zweite Suche je Treffer für die Koordinate und
  einen Delegaten. `MKLocalSearch` liefert Name und Koordinate in einem Schritt; nach 0,3 s Ruhe ist das schnell genug.
- **Alles in einem PR mit „Aktueller Ort“:** Dann gilt die Gerätestufe für den ganzen Schnitt, und der Teil, den der
  Simulator voll belegen kann, wartet auf das Gerät.

## Definition of Done

- AC-1 bis AC-6 erfüllt, Simulator-Beleg mit Bildschirmfotos.
- `docs/project/04-stand.md` nennt Schnitt 3a.
- Abschlussbericht: „Kein Pfad der Geräteliste berührt.“
