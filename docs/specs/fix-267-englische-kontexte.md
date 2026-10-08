# Spec: Englische Test-Kontexte mit den deutschen zusammenführen (#267)

Folge von #163. Entscheidungen Henning, 2026-10-08: eigenes Ticket; ein englischer Standardkontext
wird auch dann zusammengeführt, wenn er schon an neuen Aufgaben hängt; ohne deutsche Entsprechung
bleibt er unverändert.

## Problem

Bis #250 glich der Testspeicher mit Hennings iCloud ab. Die englisch gesäten Standardkontexte der
Tests („Garden“, „Phone“ …) stehen deshalb neben seinen deutschen („Garten“, „Telefon“ …).
`mergeDuplicateContexts` (#157) fasst nur gleichnamige zusammen.

## Erkennung

Ein Kontext ist ein englisches Doppel, wenn

1. `isSystemDefault == true` — ein von Hand angelegter Kontext ist das nie (`CatalogService.addContext`),
2. sein Name (getrimmt, ohne Groß-/Kleinschreibung und Akzente, `CatalogService.nameKey`) ein
   englischer Standardname mit eigener deutscher Übersetzung ist, und
3. ein Kontext mit dem deutschen Namen existiert (Systemstandard oder von Hand angelegt).

Paare (aus `TaskContext.defaultNameKeys` und `Localizable.xcstrings`): Phone→Telefon, Home→Haus,
Garden→Garten, Errands→Besorgung, Out and about→Unterwegs. „Computer“ heißt in beiden Sprachen gleich
und fällt schon unter #157. Die Tabelle steht fest im Code, nicht über `String(localized:)`: Das Ergebnis
darf nicht von der Sprache des Geräts abhängen.

## Expected Behavior

- **AC-1:** `CatalogService.mergeEnglishDefaults(in:)` hängt die Aufgaben jedes englischen Doppels an
  seine deutsche Entsprechung (je Aufgabe einmal, übrige Kontexte der Aufgabe bleiben) und löscht das
  Doppel. Rückgabe: Anzahl gelöschter Kontexte. Der Aufrufer speichert.
- **AC-2:** Gibt es mehrere passende deutsche Kontexte, gewinnt der erste nach `survivesBefore` (#157) —
  deterministisch auf allen Geräten.
- **AC-3:** Ein von Hand angelegter englischer Kontext (`isSystemDefault == false`) bleibt samt Aufgaben.
- **AC-4:** Ein englischer Standardkontext ohne deutsche Entsprechung bleibt unverändert.
- **AC-5:** Ein zweiter Lauf ändert nichts; ein Bestand ohne Doppel ebenso.
- **AC-6:** Die App ruft das bei jedem Start direkt nach `mergeDuplicateContexts` auf und speichert
  (jeder Start statt einmal: CloudKit kann Doppel später nachliefern, und der Lauf ist idempotent).
- Keine `Revision` je Aufgabe — wie bei #157 ist das eine Bereinigung doppelter Katalogeinträge, keine
  Änderung durch KI oder Nutzer an einem Feld.

## Scope

`Shared/Services/CatalogService.swift`, `LooseEnds/App/ContentView.swift`,
`LooseEndsTests/CatalogServiceTests.swift`, `docs/project/04-stand.md`. Geschätzt +120 LoC.

Gerätestufe: kein Pfad der Geräteliste berührt; die DoD verlangt trotzdem den Blick auf Hennings
iPhone, weil nur dort die verschmutzten iCloud-Daten liegen.

## Alternativen (verworfen)

- Nur Kontexte ohne Aufgaben nach #250 zusammenführen: `TaskContext` hat kein Anlagedatum, und die
  Aufgaben gehen beim Zusammenführen ohnehin nicht verloren (Henning: trotzdem zusammenführen).
- Englisches Doppel ohne Partner umbenennen: brächte einen gelöschten deutschen Kontext dem Sinn nach
  zurück (Henning: unverändert lassen).
