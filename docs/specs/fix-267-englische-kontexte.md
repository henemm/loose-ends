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

## Nachtrag 2026-10-08: „Out and about“ blieb auf Hennings iPhone

Nach #271 waren auf Hennings iPhone alle englischen Doppel weg, nur „Out and about“ stand weiter neben
„Unterwegs“. Auch nach einem Neustart der App blieb es, eine verspätete Lieferung aus iCloud scheidet
damit aus. Henning hat es nie selbst angelegt oder umbenannt (Entscheidung: trotzdem zusammenführen).
Woran die Regel scheitert, ist ohne Zugriff auf seine Daten nicht belegbar. In Frage kommen eine fehlende
Systemstandard-Markierung und ein Leerzeichen-Unterschied im Namen. Beides wird abgedeckt:

- **AC-7:** „Out and about“ wird auch ohne `isSystemDefault` mit „Unterwegs“ zusammengeführt
  (`CatalogService.englishDefaultsFoldedUnmarked`). Für die übrigen Paare bleibt AC-3.
- **AC-8:** Beim Namensvergleich dieser Regel zählt jede Folge von Leerraum, auch ein geschütztes
  Leerzeichen, als ein Leerzeichen.
