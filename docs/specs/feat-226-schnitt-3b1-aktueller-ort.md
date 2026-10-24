---
entity_id: feat-226-schnitt-3b1-aktueller-ort
type: feature
created: 2026-10-23
updated: 2026-10-23
status: draft
workflow: feat-226-ortserinnerungen
---

# Spec: #241 Schnitt 3b-1 — „Aktueller Ort“ und die Hinweise zum Standort

## Approval

- [x] Approved (Henning, 2026-10-24: Reihenfolge 3b-1 vor 3b-2, Satz „beim nächsten Ankommen“ immer, beide Hinweise)

## Purpose

Henning setzt den Ort, an dem er gerade steht, mit einem Tipp: „Aktueller Ort“ oben im Suchblatt. Die Ortszeile sagt ehrlich,
wann sie erinnert und wann nicht: beim nächsten Ankommen (nicht sofort, gemessen am 2026-10-08) und gar nicht, wenn der Standort
in den Einstellungen aus ist. Entwurf, F1–F7: `docs/specs/feat-226-ortserinnerungen.md`; Schnitt 3a: `feat-226-schnitt-3a-ort-im-detail.md`.

**Stand vor diesem Schnitt** (geprüft gegen `main` 21548a3): Die Frage nach „Beim Verwenden der App“ und der `Info.plist`-Text
kamen schon mit #240 Schnitt 2 (`PlaceNotificationCenter`, `project.yml:100`). Die Debug-Starthilfe `-le-seed-place` ist schon
entfernt. Offen aus der Liste von #241 bleiben: „Aktueller Ort“, „Standort aus“, der Hinweis „nächstes Ankommen“ und
Zuhause/Arbeit.

**Schnitt.** Zuhause/Arbeit braucht das neue Modell `SavedPlace` (CloudKit-Schema, `Shared/Persistence`, Doppel-Auflösung wie #157)
und damit die Gerätestufe und einen Klick von Henning in der CloudKit-Konsole. Das wird **3b-2** mit eigener Spec. 3b-1 hier
ändert kein Modell und keinen Pfad der Geräteliste.

**Regeln vor dem Modell:** Kein Modell beteiligt. Der Ort kommt aus Core Location, sein Name aus der Rückwärtssuche von MapKit.

## Source

- **Neu:** `LooseEnds/Places/CurrentPlace.swift`: ein Standort auf Anfrage, Name per Rückwärtssuche, feste Antwort unter UI-Tests
- **Geändert:** `Shared/Services/PlaceEditing.swift` (Hinweis `.locationOff`, `.preciseOff`; Rangfolge)
- **Geändert:** `LooseEnds/Views/PlaceSection.swift` (Zeile „Aktueller Ort“ im Blatt, Satz „nächstes Ankommen“, neue Hinweise)
- **Geändert:** `LooseEnds/Resources/Localizable.xcstrings`
- **Tests:** `LooseEndsTests/PlaceEditingTests.swift` (erweitert), `LooseEndsUITests/PlaceSmokeTests.swift` (erweitert)

Erwartet: rund 150 Zeilen Produktcode, 90 Zeilen Tests.

## Verhalten

- **AC-1 Aktueller Ort:** Auf iPhone und iPad steht im Suchblatt über dem Suchfeld „Aktueller Ort“ (`location`, Akzent). Ein Tipp
  holt einen Standort (höchstens 10 s), sucht seinen Namen (Straße und Hausnummer, sonst der Ort, sonst „Aktueller Ort“) und setzt
  ihn wie einen Treffer: Ereignis bleibt, bei neuem Ort „Ankommen“, eine Revision vom Nutzer, Blatt schließt.
- **AC-2 Berechtigung:** Ist sie noch nicht erfragt, fragt der Tipp „Beim Verwenden der App“ (derselbe `Info.plist`-Text). Abgelehnt
  oder aus: Die Zeile zeigt grau „Standort ist aus.“, das Blatt bleibt offen, die Suche geht weiter.
- **AC-3 Fehler:** Kein Standort binnen 10 s oder ein Fehler: grau „Standort nicht gefunden.“, geloggt, das Blatt bleibt offen.
  Fehlt nur der Name, wird der Ort trotzdem gesetzt („Aktueller Ort“).
- **AC-4 Nächstes Ankommen:** Der graue Satz bei „Ankommen“ heißt „Erinnert beim nächsten Ankommen.“ statt „Erinnert, wenn du
  ankommst.“ (Beleg: `docs/artifacts/feat-226-schnitt-2b/simulator-durchlauf.md`, 13 h ohne Mitteilung, weil schon dort).
  „Verlassen“ bleibt „Erinnert, wenn du gehst.“
- **AC-5 Standort aus:** Hat die Aufgabe einen Ort und ist der Standort abgelehnt oder eingeschränkt, steht unter der Ortszeile
  „Standort ist in den Einstellungen aus. Der Ort ist gespeichert, erinnert aber nicht.“ (Wortlaut des Entwurfs).
- **AC-6 Genauer Standort aus:** Erlaubt, aber ohne „Genauer Standort“ (das System stellt dann keine Ortsmitteilung zu,
  `PlaceNotifications.isAuthorized`): „Genauer Standort ist aus. Der Ort ist gespeichert, erinnert aber nicht.“
- **AC-7 Rangfolge der Hinweise:** Standort aus vor genauer Standort aus vor „nicht überwacht“; auf dem Mac nur „Erinnert auf
  iPhone und Watch.“ (der Mac fragt nie nach dem Standort). Noch nicht erfragt: kein Hinweis, gefragt wird wie bisher beim ersten Ort.
- **AC-8 Mac:** Kein „Aktueller Ort“ auf dem Mac (er bräuchte eine eigene Berechtigung in `project.yml`, und er erinnert ohnehin
  nicht). Folgeticket nur, wenn Henning es will.
- **AC-9 Regression:** Unit, Build, UI Smoke und Mac-Galerie grün.

## Implementation Details

- `CurrentPlace.locate() async throws -> PlaceHit`: `CLLocationUpdate.liveUpdates()` bis zum ersten Standort mit
  `horizontalAccuracy ≤ 100 m` oder 10 s; dann `MKReverseGeocodingRequest`. Unter `--ui-testing` feste Antwort „Teststraße 1,
  Hamburg“ ohne Core Location.
- Berechtigung lesen: `CLLocationManager().authorizationStatus` und `accuracyAuthorization`, abgebildet auf
  `PlaceNotifications.Permission` (dieselbe Abbildung wie `PlaceNotificationCenter`, dorthin nur verschoben, wenn kein Pfad der
  Geräteliste berührt wird; sonst eine zweite kleine Abbildung in `LooseEnds/Places`).
- `PlaceEditing.note(for:among:isMac:permission:fullAccuracy:)` bleibt rein; der View reicht den gelesenen Stand hinein.

## Test Plan

`PlaceEditingTests` (RED zuerst): Rangfolge AC-7 für jede Kombination aus Erlaubnis, Genauigkeit, 20er-Grenze und Mac; ohne Ort nie
ein Hinweis; nicht erfragt ohne Hinweis.

`PlaceSmokeTests` (Simulator, feste Antworten): Aufgabe → Detail → „Ort hinzufügen“ → „Aktueller Ort“ → Ortszeile „Teststraße 1,
Hamburg“, Satz „Reminds you the next time you arrive.“ → „Leave“ → Satz „… leave.“. Bildschirmfotos als Anhang.

## Abnahme

Stufe 1 und 2 über die CI. Kein Pfad der Geräteliste berührt. Der echte Standort und der Systemdialog zeigen sich auf dem Gerät; das
prüft Henning mit 3b-2 in TestFlight zusammen mit Zuhause/Arbeit.

## Alternativen (verworfen)

- **`CLLocationManager.requestLocation()`** mit Delegat: dasselbe Ergebnis, mehr Code; `liveUpdates` ist async und hört von selbst auf.
- **Zuhause/Arbeit gleich mit:** zieht Modell, Schema und Gerätestufe in den Schnitt, der sonst im Simulator voll belegt ist.

## Definition of Done

- AC-1 bis AC-9 erfüllt, Simulator-Beleg mit Bildschirmfotos.
- Abschlussbericht: „Kein Pfad der Geräteliste berührt.“
