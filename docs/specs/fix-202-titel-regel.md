---
entity_id: fix-202-titel-regel
type: bugfix
created: 2026-10-05
updated: 2026-10-05
status: draft
workflow: bug-202-titel
---

# Spec: Bug #202 — Titel ab Erfassung per Regel, „Zurücksetzen" führt auf einen Titel

## Approval

- [ ] Approved

## Purpose

Henning (Issue #202, aus #198) meldet zwei Dinge aus eigener Benutzung: (1) der Titel wird
unzuverlässig gesetzt, (2) „Wiederherstellen des Titels aus der originalen Spracherkennung"
funktioniert nicht. Beides hat eine Ursache: der Titel entsteht allein im Sprachmodell. Liefert es
nichts (nicht verfügbar, gedrosselt, Konfidenz unter 0,6, leerer Titel), bleibt das Titelfeld leer
und die Aufgabe `unverified`. Und weil die Aufgabe ohne Titel angelegt wird, trägt die erste
KI-Revision `oldValue = nil`; „Zurücksetzen" setzt den Titel genau darauf, das Feld ist danach leer.

Nachgestellt im Simulator auf Hennings Weg (Erfassen, Neu, Detail): Titelfeld leer mit Platzhalter
„Title", Liste zeigt den Rohtext kursiv mit „Not sorted yet"
(`docs/artifacts/bug-202-titel/simulator-run.txt`, Bilder geöffnet). Teil 2 ist im Simulator nicht
auslösbar (der Reset-Knopf erscheint nur bei KI-Titel, der Simulator hat kein Modell); belegt ist er
über den bestehenden Test `RevisionServiceTests.revertTitle` (nach dem Reset `task.title == nil`) und
über den Code (siehe Source). Ob der Titel auf dem iPhone aus Drosselung, Konfidenz oder Fehler
ausbleibt, ist nicht belegt (#159 bleibt offen); für das Ergebnis ist das gleichgültig, in allen
drei Fällen schreibt `EnrichmentWriter` keinen Titel.

Lösung (Entwurf A, von Henning am 2026-10-05 freigegeben): Jede Aufgabe bekommt beim Erfassen per
Regel einen Titel aus dem Rohtext, ohne Modell, ohne KI-Markierung, ohne Revision. Das Modell darf
ihn später wie bisher überschreiben; „Zurücksetzen" führt dann auf diesen Anfangstitel statt auf ein
leeres Feld.

**Ohne Modell geht es nicht, weil …** — gilt hier nur für lange Diktate: 312 von 319 Korpus-Rohsätzen
haben höchstens 12 Wörter (Median 6), der Rohtext ist fast immer schon der Titel; das Modell bringt
Kürzen und Umformulieren nur bei den 7 längeren. Die Regel ist deshalb der Weg (CLAUDE.md „Rules
before the model"), das Modell die Verfeinerung. Nulllinie: die Regel erzeugt nichts Erfundenes
(der Titel besteht nur aus Wörtern des Rohtexts), das Modell erfand beim Titel 0,3 %.

## Source

- **File:** `Shared/Services/CaptureService.swift`
- **Identifier:** `CaptureService.save` (Zeile 20: `TaskItem(rawText:…)` legt die Aufgabe ohne Titel an)
- **File:** `Shared/Services/RevisionService.swift`
- **Identifier:** `revert` (Zeile 21–30), `revertAll` (Zeile 34–48), `firstAIRevision` (Zeile 72–76)
- **File:** `Shared/Models/TaskItem.swift`
- **Identifier:** `displayTitle` (Zeile 118–121)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Shared/Enrichment/EnrichmentWriter.swift` | module | schreibt `record(.title, old: task.title, …)` — **bleibt unverändert**: mit gesetztem Regeltitel trägt die erste KI-Revision automatisch den Regeltitel als `oldValue` |
| `Shared/Services/FieldCodec.swift` | module | `apply` setzt bei leerem Titel auch `titleSourceRaw` auf nil, bei gesetztem Titel auf die übergebene Quelle (hier `.user` beim Zurücksetzen) — unverändert |
| `LooseEnds/Views/DetailLayout.swift` | module | `showsRawText` blendet „You said:" aus, solange die Wortmengen von Titel und Rohtext gleich sind (`RawTextWords`) — unverändert, wirkt jetzt ab Erfassung |
| `LooseEnds/Views/TaskDetailView.swift` | view | `titleDraft` kommt aus `task.title` (`.onAppear`), Reset-Knopf nur bei `aiSetFields.contains(.title)` — unverändert |
| `LooseEnds/Views/TaskRow.swift` | view | kursiv bei `task.title == nil` oder `unverified` — unverändert |
| `Shared/Services/CalendarSync.swift`, `Shared/Notifications/DueReminders.swift`, `LooseEndsWidgets/NextUpWidget.swift`, `LooseEnds/Views/SubtasksSection.swift` | reader | lesen `displayTitle`; sehen jetzt den Regeltitel statt des Rohtexts, solange das Modell nichts geliefert hat |
| `Shared/Services/Subtasks.swift` | module | legt Unteraufgaben mit `TaskItem(rawText:…)` direkt an, nicht über `CaptureService` — bleibt ohne Titel (siehe Entscheidung 5) |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|--------------|
| `Shared/Services/TitleRule.swift` | CREATE | reine Regel `TitleRule.title(from:) -> String?` |
| `Shared/Services/CaptureService.swift` | MODIFY | setzt `item.title` aus der Regel; `titleSourceRaw` und `titleConfidence` bleiben nil, keine Revision |
| `Shared/Services/RevisionService.swift` | MODIFY | `revert` und `revertAll`: Titel mit Vor-KI-Wert nil (Altbestand) setzen `TitleRule.title(from: task.rawText)` statt nil |
| `Shared/Models/TaskItem.swift` | MODIFY | `displayTitle`: Klausel `status != .unverified` entfällt (Entscheidung 3) |
| `CLAUDE.md` | MODIFY | Zeile „Rules before the model": Titel hat eine Regel-Vorstufe (Doku) |
| `LooseEndsTests/TitleRuleTests.swift` | CREATE | Regel, Erfassung, Zurücksetzen nach KI-Lauf und bei Altbestand, `displayTitle` |
| `LooseEndsTests/RevisionServiceTests.swift` | MODIFY | `revertTitle` und `revertAll` erwarten den Anfangstitel statt nil |
| `LooseEndsTests/CaptureServiceTests.swift` | MODIFY | Zeile 23: `stored.title == nil` wird zur Erwartung des Regeltitels |
| `LooseEndsUITests/CaptureSmokeTests.swift` | MODIFY | neuer UI-Test: Erfassen, Detail zeigt Titel (vorhandene Klasse) |

### Estimated Changes
- Files: 9 (4 Produktivcode, 1 Doku, 4 Tests)
- LoC: ca. +150/−10 (Produktivcode ca. +45/−5, Tests ca. +100/−5)

**Scoping-Grenze ehrlich benannt:** Die Grenze „4–5 Dateien" ist bei der Dateizahl überschritten (9),
die Grenze ±250 LoC nicht. Die Überschreitung kommt von den Tests (4 Dateien, davon 2 nur
Erwartungswerte, die sich mit dem Verhalten ändern) und der CLAUDE.md-Zeile, nicht von Produktivcode
(4 Dateien, davon 2 mit wenigen Zeilen). Ein Schnitt in „Regel + Erfassung" und „Zurücksetzen"
würde den Zustand dazwischen erzeugen, in dem die Regel einen Titel setzt, aber Zurücksetzen bei
Altbestand weiter ein leeres Feld liefert — der Fehler (2) bliebe offen. Empfehlung: als ein Ticket
umsetzen. Das ist eine Ausnahme von der Dateizahl, die bei der Freigabe ausdrücklich bestätigt wird.

## Implementation Details

### 1. `TitleRule` (neu, rein, ohne Modell)

```swift
enum TitleRule {
    static let maxWords = 12
    static func title(from rawText: String) -> String?
}
```

Regeln, in dieser Reihenfolge:

1. **Wörter:** Rohtext an Whitespace (Leerzeichen, Tabs, Zeilenumbrüche) trennen, leere Teile
   verwerfen. Mehrfach-Leerzeichen und Umbrüche werden so zu einem Leerzeichen. (Bewusst nicht
   `RawTextWords`: das normalisiert Groß-/Kleinschreibung und Satzzeichen für den Vergleich; der Titel
   soll die Wörter unverändert behalten.)
2. **Kürzen:** bei mehr als 12 Wörtern die ersten 12 behalten. Keine Auslassungspunkte, kein
   Umformulieren.
3. **Abschließende Satzzeichen:** am Ende alle Zeichen aus `. , ; : ! ? …` entfernen (auch
   mehrere, auch nach dem Kürzen, auch wenn Leerraum dazwischen stand). Satzzeichen mitten im Text
   und öffnende/schließende Anführungszeichen und Klammern bleiben.
4. **Erster Buchstabe groß:** ist das erste Zeichen ein Buchstabe, wird es großgeschrieben, aber nur
   wenn das Ergebnis ein einzelnes Zeichen bleibt (`ß` ergäbe „SS", dann unverändert lassen). Der
   Rest bleibt unangetastet (Eigennamen, Abkürzungen wie „iPhone" ab dem zweiten Wort bleiben).
   Beginnt der Text mit Ziffer, Anführungszeichen oder Symbol, bleibt er unverändert.
5. **Leer:** bleibt nach den Schritten nichts übrig (leer, nur Leerzeichen, nur Satzzeichen), ist das
   Ergebnis `nil`.

Die Regel ist idempotent (`title(from: title(from: x)) == title(from: x)`) und gibt nur Wörter des
Rohtexts zurück, nichts Erfundenes.

### 2. `CaptureService.save`

Nach `TaskItem(rawText: text, …)`:

```swift
item.title = TitleRule.title(from: text)
```

`titleSourceRaw` und `titleConfidence` bleiben nil (der Titel stammt nicht von der KI und ist keine
Nutzerentscheidung), es wird keine `Revision` geschrieben. `status` bleibt `.unprocessed`.
`CaptureService` ist der eine Schreibweg für App, Siri, Watch, Control Center und Share, alle
bekommen den Titel damit gleichermaßen.

### 3. `RevisionService.revert` / `revertAll` — Altbestand

Die Auflösung des Zurücksetz-Werts für ein Feld wird zentral:

```swift
private static func restoreValue(of revision: Revision, on task: TaskItem) -> String? {
    if revision.field == .title, revision.oldValue == nil { return TitleRule.title(from: task.rawText) }
    return revision.oldValue
}
```

`revert` und `revertAll` benutzen sie statt `revision.oldValue` / `first.oldValue`. Neue Aufgaben
(ab dieser Änderung) haben nie `oldValue == nil` bei der ersten Titel-Revision, weil `task.title`
beim Modelllauf gesetzt ist. Die Regel greift nur für Altbestand (Aufgaben, die ohne Titel erfasst
wurden und danach vom Modell einen Titel bekamen). Die #125-Semantik „Zurücksetzen = Wert vor der
ersten KI-Revision" bleibt, hat jetzt aber immer einen Wert.

Nach dem Zurücksetzen trägt der Titel `titleSourceRaw == "user"` (die bestehende Folge von
`FieldCodec.apply(…, as: .user)` bei nicht leerem Wert) und eine Nutzer-Revision. Der Reset-Knopf
verschwindet damit wie bisher (`aiSetFields` enthält `.title` nicht mehr).

### 4. `displayTitle`

```swift
var displayTitle: String {
    if let title, !title.isEmpty { return title }
    return rawText
}
```

Die Klausel `status != .unverified` entfällt (Begründung unter Entscheidung 3).

### 5. Verhalten in Detail und Liste, nach Lesen des Codes

| Stelle | Heute (ohne Titel) | Neu (Regeltitel gesetzt) |
|---|---|---|
| Titelfeld (`titleDraft`, `.onAppear` aus `task.title`) | leer, Platzhalter „Title" | zeigt den Regeltitel; Nutzer kann ihn wie jeden Titel bearbeiten (`commitTitle` schreibt eine Nutzer-Revision, bei `unverified` wird die Aufgabe `active`) |
| „You said:"-Zeile (`DetailLayout.showsRawText`) | immer sichtbar (kein Titel) | sichtbar nur, wenn die Wortmengen von Titel und Rohtext verschieden sind: bei Rohtext über 12 Wörtern oder nach Modell-Titel; bei Rohtext bis 12 Wörter verschwindet sie (Groß-/Kleinschreibung und Satzzeichen zählen nicht) |
| Reset-Knopf | nur bei KI-Titel | unverändert: nur bei KI-Titel, nach der Erfassung allein also nicht sichtbar |
| `TaskRow` | kursiv (`task.title == nil`), Rohtext | nicht mehr kursiv bei `unprocessed` mit Regeltitel; kursiv bleibt bei `unverified` (Code unverändert) und bei fehlendem Titel (Altbestand); KI-Funke nur bei `titleSourceRaw == ai` |
| Liste „Not sorted yet" / Ansicht Neu | `unprocessed` und `unverified` | unverändert, hängt am Status, nicht am Titel |
| Mitteilung, Kalender, Widget, Unteraufgaben-Zeile (`displayTitle`) | Rohtext | Regeltitel (gekürzt, bereinigt) |

### Entscheidungen (offene Punkte aus der Analyse, hier festgehalten)

1. **Status bleibt bis zum Modelllauf `unprocessed`** (nur der Titel ist schon da). Begründung:
   `unprocessed` heißt „Anreicherung noch nicht gelaufen" (`Enums.swift`) und steuert Ansicht Neu,
   „Not sorted yet" und den Nachzügler-Lauf des `EnrichmentCoordinator`. Setzte die Erfassung
   `active`, käme die Aufgabe nicht mehr zum Modell. `EnrichmentWriter` hebt den Status wie bisher
   auf `active` (Modelltitel) oder `unverified` (kein Modelltitel).
2. **Altbestand ohne Titel wird nicht nachgezogen**, nur beim Zurücksetzen. Begründung: eine
   Migration über alle vorhandenen Aufgaben hätte Revisionen, CloudKit-Abgleich und
   `Shared/Persistence` (Gerätestufe) zur Folge; der Nutzen (Titelfeld in alten Aufgaben nicht leer)
   ist klein, die Liste zeigt dort schon den Rohtext. Wird das gewünscht, ist es ein eigenes Ticket.
3. **`displayTitle` zeigt bei `unverified` den Regeltitel, nicht mehr den Rohtext.** Fall: Modell
   liefert nichts, Status wird `unverified`, `task.title` ist der Regeltitel. Mit der alten Klausel
   zeigte die Liste den vollen Rohtext, das Detail den gekürzten Regeltitel im Feld: zwei Wahrheiten
   für dieselbe Aufgabe, und bei einem 30-Wörter-Diktat eine überlange Zeile. Die Klausel
   `status != .unverified` hatte nur Sinn, solange `unverified` immer „kein Titel" hieß; das ist mit
   dieser Änderung nicht mehr so. Der Hinweis „noch nicht bestätigt" bleibt über die Kursivschrift
   (`TaskRow`, unverändert) und „Not sorted yet" erhalten. Folge für Altbestand: `unverified` ohne
   Titel zeigt weiter den Rohtext (Rückfall in `displayTitle`).
4. **Vom Nutzer geleerter Titel bleibt leer.** `FieldCodec.apply` setzt beim Leeren `title = nil`
   und `titleSourceRaw = nil`; `CaptureService` läuft nur beim Erfassen und füllt nichts nach. Die
   Liste fällt wie bisher auf den Rohtext zurück. Wer wieder einen Titel will, tippt einen oder
   nutzt (nach KI-Lauf) Zurücksetzen.
5. **Unteraufgaben** (`Subtasks.add`) legen `TaskItem` direkt an und bekommen keinen Regeltitel;
   ihre Zeile zeigt weiter den Rohtext über `displayTitle`. Nicht Teil von #202 (Hennings Meldung
   betrifft erfasste Aufgaben), kein Seiteneffekt.
6. **Modell liefert denselben Text wie der Regeltitel** (häufig bei kurzen Sätzen): `EnrichmentWriter`
   schreibt trotzdem eine KI-Revision mit `old == new` und setzt die KI-Markierung (Funke im Detail,
   Reset-Knopf, der auf denselben Text führt). Harmlos, aber unnötig laut. `EnrichmentWriter`
   bleibt in diesem Schnitt unberührt; Folgearbeit nur auf Wunsch (kein neues Ticket ohne
   Rückmeldung nach der Abnahme).

### Gerätestufe

Kein Pfad der Geräteliste berührt. (`Shared/Services/` und `Shared/Models/` stehen nicht darin;
`FoundationModelsEnricher`, `EnrichmentCoordinator`, `Shared/Persistence/` bleiben unberührt.) Die
Abnahme endet nach Stufe 2 (Tests, Simulator).

### Datenänderung

Kein neues Feld, keine Migration, keine AppStorage-Keys, keine neuen Permissions, keine
Info.plist-/Entitlement-Änderung. `TaskItem.title` existiert bereits; neue Aufgaben füllen es früher.
Vorhandene Aufgaben bleiben unverändert (Entscheidung 2). Das Schema für CloudKit ändert sich nicht.

### CLAUDE.md

In der Zeile „Rules before the model" wird der Halbsatz, der den Titel als das Modellfeld nennt
(„The on-device model only gets what needs language understanding (the title)"), angepasst: der
Titel hat seit #202 eine Regel-Vorstufe (`TitleRule`, Rohtext bereinigt, höchstens 12 Wörter,
Messung 312 von 319 Rohsätzen ≤ 12 Wörter), das Modell darf ihn danach verfeinern. Zusätzlich ein
Eintrag unter „Where things live" (`Shared/Services`: `TitleRule`).

## Test Plan

### Automated Tests (TDD RED)

`LooseEndsTests/TitleRuleTests.swift` (Unit, neu):

- [ ] Test 1: GIVEN „  Rasen mähen  " WHEN `TitleRule.title(from:)` THEN „Rasen mähen" (getrimmt).
- [ ] Test 2: GIVEN „", „   ", „\n\t " und „..." / „?!" WHEN die Regel läuft THEN `nil`.
- [ ] Test 3: GIVEN „Zahnarzt anrufen." WHEN die Regel läuft THEN „Zahnarzt anrufen" (Endpunkt weg);
      GIVEN „Zahnarzt anrufen…" und „Zahnarzt anrufen. ." THEN ebenfalls „Zahnarzt anrufen".
- [ ] Test 4: GIVEN „Wann kommt der Handwerker?" WHEN die Regel läuft THEN „Wann kommt der Handwerker"
      (Fragezeichen am Ende weg, Satzzeichen mitten im Text bleiben: „Anruf, dann Mail" bleibt).
- [ ] Test 5: GIVEN genau 12 Wörter WHEN die Regel läuft THEN alle 12 bleiben; GIVEN 13 und 30 Wörter
      THEN genau die ersten 12 Wörter, ohne Auslassungspunkte; GIVEN das 12. Wort endet auf Komma
      THEN das Komma ist weg.
- [ ] Test 6: GIVEN „ärgerlich: Steuer abgeben" und „überweisen" WHEN die Regel läuft THEN
      „Ärgerlich: Steuer abgeben" und „Überweisen" (Umlaut am Anfang groß); GIVEN „ßtraße prüfen"
      THEN unverändert (Großschreibung würde zwei Zeichen ergeben).
- [ ] Test 7: GIVEN „3 Pakete abholen", „„Brief“ senden" und „#Steuer prüfen" WHEN die Regel läuft
      THEN unverändert (erstes Zeichen kein Buchstabe); GIVEN „iPhone laden" THEN „IPhone laden"
      (Regel macht nur den ersten Buchstaben groß; so festgehalten, kein Sonderfall).
- [ ] Test 8: GIVEN „Rasen   mähen\nund   düngen" WHEN die Regel läuft THEN „Rasen mähen und düngen"
      (Mehrfach-Leerzeichen und Umbruch zu einem Leerzeichen).
- [ ] Test 9: GIVEN beliebige Eingaben aus den Tests 1–8 WHEN die Regel zweimal angewandt wird THEN
      gleiches Ergebnis (idempotent).
- [ ] Test 10 (Erfassung): GIVEN ein leerer In-Memory-Speicher WHEN
      `CaptureService.save("termin bei Auto Senger machen für Inspektion und Reifenwechsel.", via: .app, in:)`
      THEN `title == "Termin bei Auto Senger machen für Inspektion und Reifenwechsel"`,
      `titleSourceRaw == nil`, `titleConfidence == nil`, `revisions` leer, `status == .unprocessed`,
      `rawText` unverändert (nur getrimmt).
- [ ] Test 11 (Erfassung, kein Marker): GIVEN die Aufgabe aus Test 10 WHEN
      `RevisionService.aiSetFields(on:)` THEN enthält das Ergebnis `.title` nicht.
- [ ] Test 12 (Zurücksetzen nach KI-Lauf, neue Aufgabe): GIVEN eine per `CaptureService` erfasste
      Aufgabe, auf die `EnrichmentWriter.apply` einen Modelltitel (Konfidenz 0,9) schreibt WHEN
      `RevisionService.firstAIRevision(of: .title, …)` gelesen wird THEN `oldValue` ist der Regeltitel;
      WHEN `revert` THEN `task.title` ist der Regeltitel, `titleSourceRaw == "user"`, eine
      Nutzer-Revision mit `newValue` = Regeltitel existiert, und `aiSetFields` enthält `.title` nicht.
- [ ] Test 13 (Zurücksetzen bei Altbestand): GIVEN eine Aufgabe ohne Titel (`TaskItem(rawText: "Rasen mähen.")`
      direkt angelegt), auf die ein Modelltitel geschrieben wurde (erste KI-Revision `oldValue == nil`)
      WHEN `revert` und, auf einer zweiten gleichen Aufgabe, `revertAll` THEN ist `task.title ==
      "Rasen mähen"` (Regeltitel des Rohtexts), nicht nil.
- [ ] Test 14 (Zurücksetzen bei Altbestand, anderes Feld unberührt): GIVEN die Aufgabe aus Test 13
      WHEN `revert` für `.dueDate` mit `oldValue == nil` THEN bleibt das Datum leer (die Sonderregel
      gilt nur für `.title`).
- [ ] Test 15 (`displayTitle`): GIVEN Aufgabe mit Regeltitel und `status == .unverified` THEN
      `displayTitle` ist der Regeltitel; GIVEN Aufgabe ohne Titel und `unverified` THEN der Rohtext;
      GIVEN Aufgabe mit Titel und `unprocessed` THEN der Titel.
- [ ] Test 16 (Nutzer leert Titel): GIVEN eine erfasste Aufgabe WHEN `RevisionService.set(.title, to: nil, …)`
      THEN ist `title == nil`, `titleSourceRaw == nil`, und ein erneutes Lesen der Aufgabe füllt ihn
      nicht wieder (kein Nachziehen durch Capture).

Angepasste bestehende Tests:

- [ ] `RevisionServiceTests.revertTitle`: erwartet statt `task.title == nil` den Titel
      „Rasenmäher Ölwechsel am Samstag", `titleSourceRaw == "user"`, `written.newValue` = dieser Titel.
- [ ] `RevisionServiceTests.revertAll`: `task.title == nil && …` wird zu `task.title == "Rasenmäher
      Ölwechsel am Samstag"` (Datum und Dauer bleiben nil, Zählung 4 bleibt).
- [ ] `CaptureServiceTests` (Zeile 23): `stored.title == nil` wird zu
      `stored.title == "Rasenmäher Ölwechsel am Wochenende"`.
- [ ] `EnrichmentTests` (Zeile 106–107, Konfidenz unter Schwelle): Aufgabe wird direkt angelegt, also
      ohne Titel; bleibt unverändert grün (Absicherung für Altbestand).

UI-Test (`LooseEndsUITests/CaptureSmokeTests.swift`, vorhandene Klasse, im Simulator ohne Modell):

- [ ] Test 17: GIVEN die App im `--ui-testing`-Modus (leerer Speicher, kein Modell) WHEN der Nutzer
      „termin bei Auto Senger machen für Inspektion und Reifenwechsel." erfasst, in Neu die Zeile
      öffnet THEN steht im `detailTitleField` der Wert „Termin bei Auto Senger machen für Inspektion und
      Reifenwechsel" (nicht leer, nicht der Platzhalter), und `detailRawText` existiert nicht (gleiche
      Wörter, keine „You said:"-Zeile); WHEN der Nutzer zurück zur Liste geht THEN zeigt die Zeile
      denselben Titel.
- [ ] Test 18: GIVEN die App im selben Modus WHEN der Nutzer einen Text mit 14 Wörtern erfasst und das
      Detail öffnet THEN enthält das `detailTitleField` die ersten 12 Wörter, und `detailRawText`
      zeigt den vollständigen Rohtext.

Abnahme: Stufe 2 gespielt (Simulator, `./scripts/sim.sh test-proof CaptureSmokeTests`), Bilder
geöffnet und beschrieben. „Kein Pfad der Geräteliste berührt."

## Acceptance Criteria

- **AC-1:** Given ich erfasse eine Aufgabe, z. B. „Termin bei Auto Senger machen für Inspektion und
  Reifenwechsel." / When ich sie in der Liste öffne / Then steht im Titelfeld sofort ein Titel („Termin
  bei Auto Senger machen für Inspektion und Reifenwechsel", ohne Punkt), auch wenn Apple Intelligence
  nicht antwortet oder nicht verfügbar ist.
- **AC-2:** Given ich erfasse eine Aufgabe mit mehr als zwölf Wörtern / When ich das Detail öffne /
  Then enthält der Titel die ersten zwölf Wörter, und darunter steht „You said:" mit dem vollständigen
  Text.
- **AC-3:** Given ich erfasse eine Aufgabe mit höchstens zwölf Wörtern / When ich das Detail öffne /
  Then steht keine „You said:"-Zeile da, weil sie dasselbe wie der Titel sagen würde.
- **AC-4:** Given eine Aufgabe, deren Titel das Modell ersetzt hat / When ich das Zurücksetzen-Symbol
  neben dem Titel antippe / Then steht im Titelfeld wieder der Anfangstitel aus meiner Spracherkennung
  (bereinigt, höchstens zwölf Wörter), nie ein leeres Feld.
- **AC-5:** Given eine Aufgabe, die ich vor dieser Änderung ohne Titel erfasst habe und die das Modell
  inzwischen betitelt hat / When ich „Zurücksetzen" nutze (am Titel oder im Änderungsblatt „Alles
  zurücksetzen") / Then steht im Titelfeld der bereinigte Rohtext, nicht ein leeres Feld.
- **AC-6:** Given ich habe eine Aufgabe soeben erfasst und das Modell hat noch nichts getan / When ich
  die Liste ansehe / Then steht die Aufgabe weiter unter „Not sorted yet" bzw. in „New", und neben dem
  Titel steht kein KI-Funke und im Detail kein Zurücksetzen-Symbol.
- **AC-7:** Given das Modell liefert zu einer Aufgabe nichts (Aufgabe wird „nicht bestätigt") / When
  ich die Liste ansehe / Then zeigt die Zeile den bereinigten Titel (höchstens zwölf Wörter), nicht
  den vollen Rohtext; sie bleibt kursiv als „noch nicht bestätigt". Bei einer alten Aufgabe ohne Titel
  zeigt die Zeile wie bisher den Rohtext.
- **AC-8:** Given ich habe den Titel einer Aufgabe selbst geleert / When ich die Liste ansehe / Then
  bleibt der Titel leer (die Zeile zeigt den Rohtext), die App setzt ihn nicht wieder ein.
- **AC-9:** Given Mitteilung, Kalendereintrag oder Widget zu einer neuen Aufgabe, die noch keinen
  Modelltitel hat / When sie erscheinen / Then tragen sie den bereinigten Titel statt des vollen
  Rohtexts.
- **AC-10 (gesamt):** Given der bestehende Funktionsumfang (Rohtext unveränderlich, Revisionen,
  Wiederholen, Unteraufgaben, andere KI-Felder) / When alle Unit- und UI-Tests laufen / Then bleiben
  sie grün, der Rohtext einer Aufgabe ist nach der Erfassung unverändert (nur getrimmt), und die App
  baut ohne neue Warnungen aus dieser Änderung.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — kein neues Konzept: `title`/`titleSourceRaw`/`titleConfidence` (ADR-3) und
  „Revisions statt Undo" (ADR-6) bleiben, „Rohtext unveränderlich" bleibt; die Regel setzt nur den
  Anfangswert des bestehenden Feldes. Die Änderung ist eine Anwendung der CLAUDE.md-Regel „Rules
  before the model" (Henning, 2026-09-20), kein Beschluss, der eine ADR-Nummer braucht; die
  Doku-Anpassung der Regelzeile steht unter Implementation Details.
- **Rationale:** Der Titel hing allein am Modell, einem nicht verlässlichen Lieferanten (Foundation
  Models: `SystemLanguageModel.availability` kennt `.deviceNotEligible`, `.appleIntelligenceNotEnabled`,
  `.modelNotReady`; eigene Messung: 23 Fehlversuche, davon 11 gedrosselt; Forum thread 794408,
  in #159 zitiert). Der Rohtext ist in 312 von 319 Fällen schon ein Titel. Eine Regel liefert ihn
  immer, sofort, ohne Erfindung; das Modell bleibt für das Verfeinern (Verb, Straffen langer
  Diktate) zuständig. Dass „Zurücksetzen" nun immer einen Wert hat, folgt ohne weitere Änderung aus
  `EnrichmentWriter` (`old: task.title`).
- **In Alternativen gedacht (mit gekippter Entscheidung):**
  - **B — Rohtext nur als Platzhalter im leeren Feld.** Keine Datenänderung, aber Liste,
    Mitteilungen und Kalender bleiben ohne eigenen Titel, und Zurücksetzen führt weiter auf ein
    leeres Feld; löst Teil 2 nicht. Gekippt würde: nichts, es wäre der schwächere Weg.
  - **C — Knopf „Use what you said" statt automatisch.** Kippt „Anreicherung ohne Zutun" (Kernversprechen:
    Sagen, und es ist sortiert) und kostet einen Tipp je Aufgabe.
  - **D — Modell zuverlässiger machen** (Wiederholung, anderer Prompt). Hängt an #159
    (Ursache auf dem Gerät offen), im Simulator nicht beweisbar, berührt `FoundationModelsEnricher`
    (Gerätestufe), löst Teil 2 nicht. Kippt: die Annahme, dass der Titel ein reines Modellfeld ist
    (diese Spec kippt sie ohnehin).
  - **E — Modell nur für Texte über zwölf Wörter anfragen.** Würde Modellaufrufe sparen (nur 7 von
    319), berührt `EnrichmentCoordinator` und `FoundationModelsEnricher` (Gerätestufe) und nähme dem
    Modell die Chance, andere Felder (Energie, Kontexte) ohne Titel zu füllen. Ein späterer Schnitt,
    falls Messungen zeigen, dass der Modelltitel bei kurzen Texten nichts bringt. Kippt: ADR-4
    „Anreicherung läuft einmal je Aufgabe" für alle Aufgaben gleich.
  - **Sunk-cost-Hinweis:** Die bestehende Architektur (Titel nur vom Modell, `*SourceRaw` nur bei
    KI) ist kein Gegenargument; die Regel passt in dieselben Felder ohne Schemaänderung.
- **Folgen:** `TitleRule` ist ab jetzt die Nulllinie für jede künftige Titel-Messung; ein Bericht über
  den Modelltitel führt die Regel-Spalte (Titel = Rohtext, bereinigt) mit.

## Changelog

- 2026-10-05: Initial spec created
