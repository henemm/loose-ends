# Spec: Kontextnamen sind eindeutig (#157)

Entscheidung Henning, 2026-10-01: gleichnamige Kontexte sind verboten, bestehende werden zusammengeführt.

## Problem

Kontexte werden über den Namen zugeordnet (`FieldCodec`: `available.filter { names.contains($0.name) }`).
Zwei Kontexte „Garden" ergeben an einer Aufgabe „Garden, Garden" (Reproduktion im Simulator:
`LooseEndsUITests/ContextDuplicateReproTests`, Bilder geprüft). `CatalogService.addContext` und
`rename` prüfen keine Eindeutigkeit; SwiftData mit CloudKit kennt keine Unique-Constraints, Dubletten
können also auch von einem anderen Gerät nachgeliefert werden.

Nicht Teil dieses Tickets: Projekte (gleiche Anlage, aber kein belegter Befund), die Frage, wie die
Dubletten und das „Garten" im #153-Gerätelauf entstanden (bleibt in #157 offen).

## Expected Behavior

- **AC-1:** `CatalogService.addContext` wirft `CatalogError.duplicateName`, wenn ein Kontext mit
  gleichem Namen existiert. Verglichen wird getrimmt, ohne Groß-/Kleinschreibung und ohne
  Akzentunterschiede („garden " == „Garden"). „Garden" und „Garten" sind verschiedene Namen.
- **AC-2:** `CatalogService.rename(_ taskContext:to:)` wirft `duplicateName`, wenn ein *anderer*
  Kontext den Namen trägt. Umbenennen auf den eigenen Namen (auch nur anderes Casing) ist erlaubt.
  Dafür bekommt `rename` den Parameter `among:` (alle Kontexte).
- **AC-3:** `CatalogService.mergeDuplicateContexts(in:)` führt gleichnamige Kontexte zusammen: Die
  Aufgaben aller Dubletten hängen danach am überlebenden Kontext (je Aufgabe einmal), die Dubletten
  sind gelöscht, keine Aufgabe geht verloren. Rückgabe: Anzahl gelöschter Kontexte. Ohne Dubletten
  passiert nichts (idempotent).
- **AC-4:** Der Überlebende ist deterministisch, damit zwei Geräte dieselbe Wahl treffen:
  zuerst `isSystemDefault`, dann kleinste `sortOrder`, dann kleinste `id.uuidString`.
- **AC-5:** Die App ruft die Zusammenführung bei jedem Start nach dem Säen auf und speichert.
- **AC-6:** Die Seitenleiste zeigt bei einem abgelehnten Namen eine Meldung (Alert) „Einen Kontext mit
  diesem Namen gibt es schon." und legt nichts an; deutsch übersetzt.
- **AC-7:** Im Simulator: legt man „Garden" ein zweites Mal an, ist es abgelehnt, und der Feldeditor
  einer Aufgabe bietet genau eine Zeile „Garden".

## Scope

Dateien: `Shared/Services/CatalogService.swift`, `LooseEnds/Views/SidebarView.swift`,
`LooseEnds/App/ContentView.swift`, `LooseEnds/Resources/Localizable.xcstrings`,
`LooseEndsTests/CatalogServiceTests.swift`, `LooseEndsUITests/ContextUniquenessTests.swift`
(entstanden aus der Reproduktion, jetzt Regressionstest). Geschätzt +150 LoC.

## Alternativen (verworfen)

- Zuordnung über die ID statt über den Namen: größerer Umbau von `FieldCodec` (eine Kodierung je
  Feld, lesbarer Text); nicht nötig, solange Namen eindeutig sind. Bleibt Option, falls
  Namenszuordnung an weiteren Stellen auffällt.
- Nur die Anzeige je Aufgabe auf einen Eintrag je Name kürzen: lässt die Dubletten in der Liste.
