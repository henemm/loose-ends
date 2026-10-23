---
entity_id: feat-241-schnitt-3b-aktueller-ort-zuhause-arbeit
type: feature
created: 2026-10-23
updated: 2026-10-23
status: draft
workflow: feat-241-ort-3b
---

# Spec: #241 Schnitt 3b — Aktueller Ort, Zuhause/Arbeit, Hinweise „Standort aus“ und „nächstes Ankommen“

## Approval

- [ ] Approved

## Purpose

Im Suchblatt „Ort“ bietet die App oben drei Zeilen an: **Aktueller Ort**, **Zuhause**, **Arbeit**. Unter der Ortszeile im
Detail stehen zwei neue graue Hinweise: „Standort ist in den Einstellungen aus“ und, wenn man den Ort schon erreicht
hat, „Erinnert beim nächsten Ankommen“. Das ist der Rest von #226 Schnitt 3 (3a: PR #259, gemergt). Entwurf und Antworten
F1–F7: `docs/specs/feat-226-ortserinnerungen.md`; Vorschau (freigegeben, Variante A):
`docs/artifacts/feat-241-ort-3b/entwurf.html`.

## Source

Entscheidungen Henning, 2026-10-23: Entwurf A (eigene Zeilen im Suchblatt, Hinweise unter der Ortszeile); Zuhause/Arbeit im
iCloud-Schlüsselspeicher statt als Modell `SavedPlace`; alles in einem Schnitt (gegen die Empfehlung 3b-1/3b-2).

## Scope

**Bewusste Überschreitung der Grenzen** (4–5 Dateien, ±250 LoC): rund 11 Dateien (zwei davon Texte und Doku), rund +400 Zeilen, von Henning gewählt. Die
Tests liegen in klar getrennten Dateien.

| Datei | Änderung | Beschreibung |
|---|---|---|
| `Shared/Services/PlaceEditing.swift` | MODIFY | `Note.locationOff`; Reihenfolge der Hinweise `.notWatched` > `.locationOff` > `.macOnly`; reine Regeln `isAlreadyThere(_ place:, at fix:)`, `showsAlreadyThere(...)` (Ereignis, Berechtigung, Standort) und `offersCurrentLocation(isMac:)`. |
| `Shared/Models/SavedPlaces.swift` | NEU | Wertetyp `SavedPlaces` (`home`, `work`: je ein `SavedSpot?` mit Name, Breite, Länge), `Codable`; reine Regeln `setting(_:to:)`, `place(_ slot:, event:) -> TaskPlace?`. |
| `LooseEnds/Places/SavedPlacesStore.swift` | NEU | `@Observable`-Speicher nach dem Muster von `FieldSettingsStore`: `UserDefaults` plus iCloud-Schlüsselspeicher (ein Schlüssel `savedPlaces`, JSON), `activate()` übernimmt Änderungen anderer Geräte; unter `--ui-testing` eigene Defaults-Suite, ohne iCloud. |
| `LooseEnds/Places/CurrentLocation.swift` | NEU | `protocol CurrentLocating` (`permission`, `currentFix() async throws -> LocationFix`, `requestPermissionIfNeeded()`); `SystemCurrentLocation` (iOS, `CLLocationManager.requestLocation`, Name per Rückwärts-Geocoding, Rückfall „Aktueller Ort“); `FixedCurrentLocation` unter `--ui-testing`. Am Mac gibt es keine Umsetzung, die Zeile wird dort nicht angeboten. |
| `LooseEnds/Views/PlaceSection.swift` | MODIFY | Suchblatt: Zeilen Aktueller Ort / Zuhause / Arbeit über dem Suchfeld; Hinweise „Standort aus“ und „nächstes Ankommen“ unter der Ortszeile. |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Neue Texte Deutsch/Englisch. |
| `LooseEndsTests/PlaceEditingTests.swift` | MODIFY | Abstandsregel, Reihenfolge der Hinweise. |
| `LooseEndsTests/SavedPlacesTests.swift` | NEU | Wertetyp, Kodierung, Wirkung auf Aufgaben. |
| `LooseEndsTests/SavedPlacesStoreTests.swift` | NEU | Speicher: Defaults, Cloud-Hülle, Übernahme fremder Werte. |
| `CLAUDE.md` | MODIFY | „Where things live“ nennt `SavedPlaces`, `SavedPlacesStore`, `CurrentLocation`. |
| `LooseEndsUITests/PlaceSmokeTests.swift` | MODIFY | Aktueller Ort, Zuhause festlegen und nutzen, Hinweise. |
| `scripts/sim.sh` | MODIFY | Unterkommando `location <breite> <länge>` (`simctl location`), damit der echte Weg im Simulator mit vorgetäuschtem Standort belegbar ist. |

**Geräteliste (CLAUDE.md):** `Shared/Persistence/`, `project.yml`, `Info.plist`, Entitlements und `LooseEnds/Notifications/`
bleiben unverändert. `NSLocationWhenInUseUsageDescription` steht seit Schnitt 2; der Schlüsselspeicher ist seit #311
berechtigt. Kein neues Modell, kein `schema.ckdb`, kein Production-Deploy. Der Standort selbst lässt sich nur auf einem
Gerät voll zeigen; dafür gilt der TestFlight-Weg (Stufe 3 nach dem Merge, erst auf Hennings Wort).

## Implementation Details

- **Regelweg, kein Modell.** „Schon dort“ ist `Abstand(Standort, Ort) ≤ TaskPlace.radius + horizontale Genauigkeit` (Haversine).
  Ist die Genauigkeit negativ (ungültig) oder größer als 100 m, ist die Antwort „unbekannt“, nicht „ja“. Ohne Modell geht
  nichts schief, weil keines vorkommt.
- **Aktueller Ort.** Tipp auf die Zeile: ist die Berechtigung offen, fragt die App einmal „Beim Verwenden“ (im Vordergrund,
  Sheet ist offen); bei Zusage ein Standort per `requestLocation`, daraus ein `TaskPlace` (Name: Rückwärts-Geocoding,
  Rückfall „Aktueller Ort“; Ereignis: bleibt, bei neuem Ort Ankommen) und das Blatt schließt. Bei Ablehnung oder Fehler
  bleibt das Blatt offen, die Zeile zeigt grau „Standort ist in den Einstellungen aus“ bzw. „Kein Standort gefunden“; kein
  Fehlerdialog, Fehler werden geloggt.
- **Zuhause/Arbeit.** Nicht festgelegt: Zeile grau „noch nicht festgelegt“; ein Tipp öffnet im selben Blatt die Suche mit
  der Überschrift „Zuhause festlegen“ bzw. „Arbeit festlegen“, ein Treffer speichert den Platz (setzt keine Aufgabe).
  Festgelegt: Zeile zeigt den Ortsnamen; ein Tipp setzt ihn wie einen Treffer. Wischen: „Ändern“ (Suche wie oben) und
  „Entfernen“. Zwei Geräte, die gleichzeitig ändern: der zuletzt geschriebene Wert gewinnt, kein Merge (zwei Werte).
- **Hinweis „Standort aus“.** Zeigt `PlaceEditing.note` `.locationOff`, wenn die Aufgabe einen Ort hat und die Berechtigung
  verweigert ist: „Standort ist in den Einstellungen aus. Der Ort ist gespeichert, erinnert aber nicht.“ (grau, nicht rot:
  Rot = Zeitdruck). Bei „noch nicht entschieden“ kein Hinweis; die Frage kommt vom Abgleich. Am Mac nie.
- **Hinweis „nächstes Ankommen“.** Nur bei Ereignis Ankommen, nur wenn die Berechtigung schon erteilt ist (die Ansicht fragt
  dafür nie), und nur wenn ein einmal geholter Standort `isAlreadyThere` bejaht. Geholt wird beim Setzen des Orts und wenn der
  Abschnitt erscheint; ohne Standort, mit Fehler oder bei „unbekannt“ kein Satz — nichts wird geraten. Wortlaut:
  „Du bist schon hier. Erinnert beim nächsten Ankommen.“
- **Reihenfolge der Hinweise** unter dem grauen Ereignissatz: nicht überwacht, dann Standort aus, dann Mac; der Satz „schon
  hier“ steht nur, wenn kein anderer Hinweis gilt (ein nicht überwachter oder stummer Ort erinnert ohnehin nicht).
- **Zeichen:** nur SF Symbols (`location`, `house`, `briefcase`, `mappin.and.ellipse`), Umrissvarianten.
- **Unter `--ui-testing`:** `FixedCurrentLocation` liefert einen festen Standort (zwei Startargumente: „am Ort“ = Altona-Treffer
  der festen Suche, „anderswo“) und eine umschaltbare Berechtigung (`--ui-testing-location-refused`).

## Test Plan

Unit (TDD RED zuerst):
- `isAlreadyThere`: Punkt 100 m vom Ort, Genauigkeit 20 m → ja; 300 m, Genauigkeit 20 m → nein; 200 m, Genauigkeit 60 m → ja;
  Genauigkeit −1 und 150 m → unbekannt; Genauigkeit 500 m → unbekannt, auch wenn der Abstand 0 ist.
- `note`: Verweigert + Ort → `.locationOff`; verweigert + über der 20er-Grenze → `.notWatched` gewinnt; verweigert am Mac →
  `.macOnly`; unentschieden → kein Hinweis; ohne Ort nie ein Hinweis.
- `SavedPlaces`: leer; `setting` ändert nur den gewählten Platz; Kodieren/Dekodieren rund; beschädigter Wert liest als leer;
  Platz mit ungültiger Koordinate wird nicht gespeichert; `place(_:event:)` erzeugt einen gültigen `TaskPlace`.
- `SavedPlacesStore`: schreibt in Defaults und Cloud-Hülle; `takeCloud` übernimmt fremden Wert und meldet die Änderung;
  gleicher Wert meldet keine.

UI Smoke (Simulator, feste Suche und fester Standort):
- Aufgabe → Detail → „Add place“ → „Aktueller Ort“ → Ortszeile zeigt den Ort; steht der Standort am Ort, erscheint „Du bist
  schon hier. Erinnert beim nächsten Ankommen.“; steht er woanders, nicht.
- „Zuhause“ → „noch nicht festgelegt“ → Suche → Treffer → Zeile zeigt den Namen; neue Aufgabe → „Zuhause“ setzt ihn mit einem
  Tipp.
- Start mit verweigerter Berechtigung: Ort setzen über die Suche → Hinweis „Standort ist in den Einstellungen aus“.
- Bildschirmfotos als Anhang (hell/dunkel).

Zuordnung zu den Kriterien (jeder Fall ist ein eigener Test):
- AC-1: Unit `PlaceEditingTests.currentFixSetsPlaceWithOneUserRevision` (Standort → `TaskPlace` → eine Revision, Autor Nutzer, Ereignis Ankommen); UI `PlaceSmokeTests.currentLocationSetsPlaceAndClosesSheet` (Blatt schließt, Ortszeile zeigt den Ort).
- AC-2: UI `PlaceSmokeTests.currentLocationRefusedKeepsSheetOpen` (Start mit `--ui-testing-location-refused`: Tipp auf „Aktueller Ort“ → Blatt bleibt offen, Zeile nennt „Standort ist in den Einstellungen aus“, kein Dialog, Aufgabe ohne Ort); Unit `PlaceEditingTests.currentLocationAsksOnce` (Ersatz zählt `requestPermissionIfNeeded`-Aufrufe: genau einer bei „unentschieden“, keiner bei erteilt/verweigert).
- AC-3: Unit `SavedPlacesTests.settingHomeLeavesTasksUntouched` (Aufgaben ohne Ort bleiben ohne Ort, keine Revision); UI `PlaceSmokeTests.homeCanBeDefinedFromSearch`; Abgleich `SavedPlacesStoreTests.takeCloudAdoptsOtherDevicesValue` (Wert eines zweiten Geräts über die Cloud-Hülle).
- AC-4: UI `PlaceSmokeTests.homeRowSetsPlaceWithOneTap`; Unit `SavedPlacesTests.changeAndRemoveSlotDoNotTouchTasks` (eine Aufgabe trägt den Ort schon: nach „Ändern“/„Entfernen“ unverändert, keine neue Revision).
- AC-5: Unit `PlaceEditingTests.noteLocationOffWithPlace`, `noteNotWatchedBeatsLocationOff`, `noteMacOnlyBeatsLocationOffOnMac`, `noteNoneWhenUndecided`, `noteNeverWithoutPlace`.
- AC-6: Unit `PlaceEditingTests.alreadyThereWithin`, `alreadyThereBeyond`, `alreadyThereAccuracyExtendsRadius`, `alreadyThereInvalidAccuracyUnknown`, `alreadyThereHugeAccuracyUnknown` plus `PlaceEditingTests.alreadyThereNeedsGrantedPermissionAndArriveEvent` (verweigert/unentschieden → kein Satz; Verlassen → kein Satz; Standort fehlt/Fehler → kein Satz); UI `PlaceSmokeTests.alreadyHereNoteOnlyAtThePlace` (am Ort ja, anderswo nein).
- AC-7: Unit `PlaceEditingTests.currentLocationRowOfferedOnlyOnIOS` (reine Regel `offersCurrentLocation(isMac:)`: am Mac nein); Mac-Galerie/`MacGalleryTests` bleibt grün; Zuhause/Arbeit am Mac durch `SavedPlacesStoreTests` (plattformneutral, Cloud-Hülle).
- AC-8: Standortlauf (nächster Absatz). AC-9: voller Unit-Lauf, Build, UI Smoke, `generate`-Diff.

Echter Weg (Pflicht, ohne den die Abnahme nicht schließt): `./scripts/sim.sh location <breite> <länge>` auf den Altona-Treffer,
App mit `SystemCurrentLocation` (ohne `--ui-testing`) starten, „Aktueller Ort“ tippen, Berechtigungsfrage beantworten, Ort
und Hinweis „nächstes Ankommen“ im Bild belegen, danach `location` auf einen fernen Punkt und den Hinweis verschwinden sehen.

## Acceptance Criteria

- **AC-1:** Aktueller Ort. Given ein offenes Suchblatt mit erteilter Berechtigung / When „Aktueller Ort“ getippt wird / Then
  trägt die Aufgabe einen Ort mit dem Standort als Koordinate und Ankommen, es gibt genau eine Revision vom Nutzer, und das
  Blatt schließt.
- **AC-2:** Erstfrage. Given die Berechtigung ist offen / When „Aktueller Ort“ getippt wird / Then fragt das System einmal
  „Beim Verwenden“; bei Zusage folgt AC-1, bei Ablehnung bleibt das Blatt offen und die Zeile nennt „Standort ist in den
  Einstellungen aus“, ohne Dialog und ohne Ort zu setzen.
- **AC-3:** Zuhause/Arbeit festlegen. Given „Zuhause“ ist nicht festgelegt / When die Zeile getippt und ein Treffer gewählt
  wird / Then zeigt die Zeile den Namen, die Aufgabe bekommt dadurch keinen Ort, und ein zweites Gerät übernimmt den Wert
  über den Schlüsselspeicher.
- **AC-4:** Zuhause/Arbeit nutzen. Given „Zuhause“ ist festgelegt / When die Zeile getippt wird / Then trägt die Aufgabe diesen
  Ort, eine Revision. „Ändern“ und „Entfernen“ wirken nur auf den Platz, nie auf Aufgaben, die ihn schon tragen.
- **AC-5:** Standort aus. Given eine Aufgabe mit Ort und verweigerter Berechtigung / Then steht unter der Ortszeile „Standort
  ist in den Einstellungen aus …“ (grau); bei offener oder erteilter Berechtigung nicht; am Mac nie; hinter „nicht überwacht“.
- **AC-6:** Schon dort. Given eine Aufgabe mit Ort und Ankommen, erteilter Berechtigung, Standort innerhalb Radius plus
  Genauigkeit (Genauigkeit ≤ 100 m) / Then steht „Du bist schon hier. Erinnert beim nächsten Ankommen.“; bei Verlassen,
  fernem, unbekanntem oder fehlendem Standort steht er nicht.
- **AC-7:** Mac. Am Mac fehlt die Zeile „Aktueller Ort“; Zuhause/Arbeit gibt es dort und gleichen über den Schlüsselspeicher ab.
- **AC-8:** Echter Weg belegt. Der Durchlauf mit vorgetäuschtem Standort im Simulator ohne feste Ersatzumsetzung zeigt AC-1,
  AC-2 und AC-6 im Bild (`sim.sh test-proof` plus Standortlauf).
- **AC-9:** Regression. Unit, Build und UI Smoke grün; `generate` hinterlässt keinen Diff.

## Alternativen (verworfen)

- **`SavedPlace` als SwiftData-Modell (Spec #226):** neues Schema, Dublettenregel, Production-Deploy per Konsolen-Klick. Der
  Schlüsselspeicher trägt zwei Orte problemlos (1 MB, 1024 Schlüssel); Preis: Abgleich ohne Zeitgarantie, letzter Schreiber
  gewinnt. Kippt den Modellteil der Spec #226, nicht ihr Ziel. Rückfall, falls der Abgleich Probleme macht.
- **„Zuletzt verwendet“ aus Orten bestehender Aufgaben:** nichts Neues zu speichern, erkennt Zuhause aber nicht als Zuhause;
  kippt Hennings Festlegung vom 2026-10-06.
- **Kapseln statt Zeilen (Entwurf B):** spart Höhe, zeigt aber keine Namen und braucht eine eigene Darstellung für „nicht
  festgelegt“.
- **`CLLocationUpdate.liveUpdates`:** neuerer Strom für laufende Updates; für einen einzelnen Punkt kein Gewinn
  (`requestLocation` ist unverändert dokumentiert).

## Offene Punkte

- `CLServiceSession`/Verhalten von `requestLocation` unter iOS 27: Dokumentation nicht auffindbar, wird im Standortlauf (AC-8)
  im Simulator belegt.
- Die doppelte Beschriftung „Place“ im Detail (graue Zeile und Kopf) ist nicht Teil dieses Tickets, bei Bestätigung eigenes Ticket.

**ADR-Nr.:** keine — Teilrücknahme der Spec #226 (Zuhause/Arbeit als Modell `SavedPlace`) auf Hennings Wort vom 2026-10-23; der Schlüsselspeicher folgt dem bestehenden Muster (#311, #538), eine ADR ist dafür nicht nötig.

## Definition of Done

- AC-1 bis AC-9 erfüllt, Simulator-Beleg samt Standortlauf.
- Abschlussbericht benennt die Geräteliste ehrlich: Pfade der Liste unverändert, der Standort selbst läuft über TestFlight
  (Stufe 3 erst auf Hennings Wort).
- CLAUDE.md „Where things live“ nennt `SavedPlaces`, `SavedPlacesStore`, `CurrentLocation`.
