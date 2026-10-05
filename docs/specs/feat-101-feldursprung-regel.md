# Spec: Feldursprung „aus deinen Worten“ statt „ai“ für regelgesetzte Felder (#101)

Grundlage: Gestaltungsentscheidung Henning, 2026-10-05, Kommentar in #101; Entwurf auf der
Design-Leinwand „Loose Ends – Backlog-Entwürfe“, Zeile #101.

## Problem

Regelgesetzte Werte (Termin: 99,3 % exakt, 0 % erfunden) und modellgeschätzte Werte (Termin damals
50 % exakt, 96,5 % erfunden) erscheinen heute beide als „von der KI gesetzt“. Wer einem gelesenen
Termin so wenig traut wie einem geschätzten, prüft zu viel. Wer einer Schätzung so sehr traut wie
einem gelesenen Wert, prüft zu wenig.

## Expected Behavior

Teil A — Daten (eigener PR, gestapelt auf #112):

- **AC-1:** `FieldSource` kennt `rule`. Bestehende Datensätze mit `ai` bleiben lesbar und gelten
  weiter als automatisch gesetzt. Ein unbekannter Wert liest sich wie bisher als `ai`. Kein
  Schemabruch: die Spalten bleiben Strings.
- **AC-2:** `DueDateRule`, `ImportanceUrgencyRule` und `RecognitionRule` schreiben Herkunft
  `rule` und Revisionen mit Autor `rule`. Das Modell (`EnrichmentWriter`) schreibt weiter `ai`.
- **AC-3:** Alles, was bisher „von der KI“ meinte, gilt für beide automatischen Herkünfte: das
  ungesehene Zeichen in der Liste, „gesehen“ beim Öffnen, Zurücksetzen (als Nutzer-Revision),
  „Alles zurücksetzen“, der Ton in der Merkmalzeile. `RevisionService.origin(of:on:)` sagt je Feld,
  wer den aktuellen Wert gesetzt hat.
- **AC-4:** Die Wiedererkennung (#136) trägt ebenfalls `rule`, mit einer Begründung, die die
  frühere Aufgabe nennt: „Wie bei ›Rasen mähen‹ vom 12. Sep.“

Teil B — Oberfläche (eigener PR, gestapelt auf Teil A):

- **AC-5:** Detail: Ein gelesener Wert trägt » «, ein geschätzter ✦. Beide sind akzentgetönt
  (Farbbudget: Akzent heißt tippbar). VoiceOver sagt „aus deinen Worten“ bzw. „von der KI
  geschätzt“.
- **AC-6:** Zusammenfassung im Detail: „n aus deinen Worten · m von der KI · Anzeigen“. Ein Teil
  mit 0 entfällt.
- **AC-7:** Feld-Editor bei gelesenem Wert: Abschnitt „Aus deinen Worten“ mit dem Rohtext, das
  auslösende Wort ist markiert, dazu Vorher, Nachher, ein Satz zur Regel und „Zurücksetzen“.
- **AC-8:** Feld-Editor bei geschätztem Wert: Abschnitt „Von Apple Intelligence geschätzt“ mit
  Vorher, Nachher, Begründung, „Zurücksetzen“ und der Fußnote „Geschätzt, nicht gelesen – ein
  Blick lohnt sich.“
- **AC-9:** In der Listenzeile bleibt es beim Ton ohne Zeichen; nur ein KI-Titel trägt den Funken.
- **AC-10:** Deutsche Texte im String-Katalog.

## Regeln vor dem Modell

Dieser Schnitt schlägt kein Modell für ein Feld vor. Er macht sichtbar, welches Feld aus den
Regeln kommt.

## Nicht-Scope

- Alte Regelwerte (vor #101 als `ai` gespeichert) nachträglich umschreiben. Das ginge nur über die
  Begründungssätze in den Revisionen und wäre geraten. Sie bleiben ✦, bis die Aufgabe neu
  analysiert wird.
- Personen und Projekt: Sie kommen weiter nur vom Modell.

## Scope

Teil A: `Shared/Models/Enums.swift`, `TaskItem.swift`, `ViewRules.swift`,
`Shared/Services/RevisionService.swift`, `Shared/Enrichment/EnrichmentCoordinator.swift`,
`RecognitionRule.swift`, Umbenennungen in `LooseEnds/Views` (`TaskRow`, `TaskDetailView`,
`FieldEditorView`, `FieldFormatting`), String-Katalog, `LooseEndsTests/FieldOriginTests.swift`
und angepasste Erwartungen in `EnrichmentTests`.

Teil B: `LooseEnds/Views/TaskDetailView.swift`, `FieldEditorView.swift`, `FieldFormatting.swift`,
eine reine Hilfe für das auslösende Wort in `Shared/Enrichment/RuleTrigger.swift` samt
Wortspanne im `DateExpressionParser`, String-Katalog, Unit- und Galerie-Tests.

## Abnahme

Stufe 1 CI, Stufe 2 Simulator über die Design-Galerie (Detail mit » « und ✦, Feld-Editor
„Aus deinen Worten“). Stufe 3 Gerät ist Pflicht, weil `EnrichmentCoordinator.swift` berührt ist.
