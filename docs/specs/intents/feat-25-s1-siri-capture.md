---
entity_id: feat-25-s1-siri-capture
type: feature
created: 2026-10-15
updated: 2026-10-15
status: draft
workflow: feat-25-s1-siri-capture
---

# Spec: #25 Schnitt 1 — SiriCapture (reine Logik für Siri-Erinnerungen)

## Approval

- [ ] Approved

## Purpose

Wer Siri sagt „Erinnere mich morgen um 9 an die Steuererklärung, Liste Büro, wiederholt jede Woche“, soll
danach in Loose Ends genau eine Aufgabe mit diesen Angaben finden, und jede Angabe soll dort bleiben, wo Siri
sie hingelegt hat. Schnitt 1 baut dafür den Dienst `SiriCapture` in `Shared/Services`: Er prüft alle
Siri-Angaben, bevor etwas gespeichert wird (`prepare`), und schreibt sie danach in eine neue Aufgabe
(`commit`). Geht etwas nicht (unbekannter Ort, Abschnitt, Bilder, nicht abbildbare Wiederholung), meldet er den
Grund und hinterlässt keine Aufgabe. Der Dienst kennt keine Siri-Typen und hat bis Schnitt 2 keinen Aufrufer
im Produktpfad.

**Ohne Modell:** Siri liefert fertig strukturierte Werte (Titel, Datum, Liste, Ort, Wiederholung, Link,
Markierung, Tags). Es gibt nichts auszulegen, nur zuzuordnen. Ein Modell wäre nur denkbar, wenn Sprache zu
verstehen wäre; hier ist keine. Die Veredelung läuft danach wie bei jeder Erfassung (ADR-4) und füllt nur
Felder, die Siri leer ließ.

## Source

- **Datei:** `Shared/Services/SiriCapture.swift` (neu)
- **Bezeichner:** `enum SiriCapture` mit `struct Input`, `struct Prepared`, `static func prepare(...) async throws`,
  `@MainActor static func commit(...)`, `enum SiriCaptureError`
- **Datei:** `Shared/Services/CatalogService.swift`, Bezeichner `project(named:in:)` (neu, Suche über `nameKey`)
- **Datei:** `Shared/Services/SiriFields.swift`, Bezeichner `resolve`, `matchingContexts`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `CaptureService.save(_:via:sourceURL:in:)` | module | legt die Aufgabe an (Rohtext, Kanal `.siri`, Titel per `TitleRule`); bleibt unverändert |
| `SiriFields` (#225) | module | Link (höchstens einer), Markierung, Tags auf vorhandene Kontexte; `resolve` vor, `apply` nach dem Speichern |
| `SiriRepeatMapping` (#224) | module | `map` liefert `.rule` oder `.unmappable(...)`; `apply` setzt die `RepeatRule` mit Autor `.user` |
| `PlaceEditing.set(_:on:now:)` (#226) | module | schreibt den Ort mit Revision |
| `TaskPlace` | model | Name, Koordinate, Ereignis; Radius fest 150 m; Init liefert `nil` bei leerem Namen oder ungültiger Koordinate |
| `RevisionService.set` | module | Datumsfeld mit Revision, Autor `.user`, Grund „Siri“ |
| `CatalogService.addProject`, `nameKey`, `survivesBefore` | module | Projekt anlegen und Namensregel (getrimmt, Groß/Klein, Akzente) |
| `FieldCodec` | module | Projektzuordnung über den Namen |
| `TitleRule.title(from:)` | module | Titel aus Siris Titel allein (F1) |
| `EnrichmentCoordinator`, `EnrichmentWriter` | module | Downstream: schreiben nur leere Felder und nie über Nutzerwerte |
| `TestStore` (`LooseEndsTests/EnrichmentTests.swift`) | test | hält den Container als Feld (sonst Absturz im nächsten Speichern) |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Services/SiriCapture.swift` | CREATE | `Input`, `prepare` (async, liest, wirft), `commit` (MainActor, ohne `await`), `SiriCaptureError` (ca. 140 LoC) |
| `Shared/Services/CatalogService.swift` | MODIFY | Projektsuche über `nameKey`: vorhandenes Projekt benutzen statt Doppel (ca. +10 LoC) |
| `Shared/Services/SiriFields.swift` | MODIFY | Link gleich, wenn nur der leere Pfad `/` fehlt; leere Tags ignorieren (ca. +8 LoC) |
| `LooseEndsTests/SiriCaptureTests.swift` | CREATE | Swift Testing, `TestStore` lokal (Tests zählen nicht zur Grenze) |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | `sourceURL` „oder Siri-Link“, Abbildung der Siri-Felder |

### Estimated Changes

- Files: 5
- LoC: +160/-0 (Code ohne Tests), innerhalb der Grenzen (4 bis 5 Dateien, 250 LoC)

### Out of Scope

- Schnitt 2: Intent, Entität, Schema-Typen (`AppIntents`), Übersetzung der SDK-Typen in `Input`, Ausführung im
  App-Prozess statt in einer App-Intents-Extension (Abweichung von ADR-9, dort entschieden), Fehlertext an
  Siri (`CustomLocalizedStringResourceConvertible`), Geocoding-Aufruf im Produktpfad, Gerätestufe.
- Schnitt 3: Ändern, Parken (F3), Liste anlegen als eigene Siri-Handlung.
- Ort aus dem Rohtext (#237) und alles zur Zustellung der Ortsmitteilung (#240).
- Zusammenführen bereits doppelt vorhandener Projekte; Namensprüfung für Projekte in der Oberfläche.
- Ausgeliefert wird #25 erst nach #240.

## Implementation Details

**Zwei Schritte.** `prepare` löst alles auf (Link höchstens einer, Tags, Wiederholung über
`SiriRepeatMapping.map`, Ort, Abschnitt/Bilder) und wirft vor jedem Schreiben; es liest nur. `commit` läuft
synchron auf dem MainActor ohne `await`: `CaptureService.save`, Titel, Datum, Projekt, Wiederholung, Ort,
`SiriFields.apply`, `ctx.save()`. Nach jedem Fehler bleibt keine Aufgabe und kein ungespeicherter Rest zurück
(`hasChanges == false`).

**Keine Siri-Typen in `Shared/Services`.** `Input` ist ein reines Struct: Titel, optionale Notiz, optionales
Datum mit `hasTime`, optionaler Listenname, Wiederholung als `Calendar.RecurrenceRule`, Ort (Name, Adresse,
Koordinate, Ereignis), Links, Markierung, Tags, Hinweis „Abschnitt/Bilder vorhanden“. Die Übersetzung aus
Schema-Typen macht Schnitt 2. Offene Frage U3 (Siris Datum als `Date` oder `DateComponents`): Schnitt 1 nimmt
`Date` plus `hasTime`.

**Festlegungen von Henning (Ticket #25).**

- Alle Siri-Angaben tragen Autor `.user` mit Grund „Siri“. „Neu analysieren“ überschreibt sie nicht, die
  Wiedererkennung lernt daraus.
- **F1 Notiz:** Rohtext = Titel, Zeilenumbruch, Notiz. `TitleRule` fasst Zeilenumbrüche zu Leerzeichen und
  nähme die Notiz in den Titel; deshalb wird der Titel aus Siris Titel allein gebildet und nach dem Speichern
  gesetzt. Der Rohtext bleibt unverändert beide Teile.
- **F2 Liste:** Eine unbekannte Liste legt ein Projekt an. Ein vorhandenes Projekt gleichen Namens (`nameKey`:
  Groß/Klein, Akzente, Leerzeichen) wird benutzt, es entsteht kein Doppel. Gibt es schon mehrere gleichnamige,
  gilt das mit der kleinsten `sortOrder`. Das Anlegen geschieht erst in `commit`, damit ein Fehler nichts
  hinterlässt.
- **F5:** Ein Abschnitt oder Bilder mit Inhalt werden mit Grund abgelehnt (`unsupported`), es entsteht keine
  Aufgabe. Ein leerer Abschnitt oder eine leere Bilderliste lehnt nichts ab.
- **Ort:** Herkunft `user`, nicht `rule`. Eine Koordinate wird direkt benutzt, ohne Geocoding. Nur eine Adresse
  ohne Koordinate ruft eine injizierte Funktion einmal auf (im Test ein Fake). Kein Treffer ergibt
  `placeNotFound`. Name: Siris Name, sonst die Adresse.
- **Wiederholung ohne Datum** erfindet kein Datum: Die Aufgabe bekommt die Regel, aber keine Fälligkeit.
- **Datum:** über den vorhandenen Feldweg (`RevisionService.set(.dueDate …)`), `dueHasTime` aus dem
  Eingabewert.

**Abbildung Siri-Feld zu Ziel.**

| Siri-Feld | Ziel | Baustein | Verhalten bei Problem |
|---|---|---|---|
| Titel | Rohtext (Anfang), Titel per `TitleRule` | `CaptureService.save`, `TitleRule.title(from:)` | leerer Titel: `emptyTitle`, keine Aufgabe |
| Notiz | Rohtext, nach Zeilenumbruch | `SiriCapture.commit` | keine Notiz: Rohtext = Titel |
| Datum | Fälligkeit, `dueHasTime` | `RevisionService.set`, Autor `.user`, Grund „Siri“ | kein Datum: Feld bleibt leer, nichts erfunden |
| Liste | Projekt (vorhanden oder neu) | `CatalogService.project(named:in:)`, `addProject` | Name leer: kein Projekt; Doppel ausgeschlossen |
| Wiederholung | `RepeatRule` | `SiriRepeatMapping.map`, `apply` | `.unmappable`: `unmappableRepeat(Set)`, keine Aufgabe |
| Ort | `TaskPlace` | `PlaceEditing.set`, Geocoding-Funktion nur bei Adresse | `placeNotFound`; ungültige Koordinate: `invalidPlace` |
| Link(s) | `sourceURL` | `SiriFields.resolve`/`apply` | mehr als ein verschiedener Link: `multipleLinks(n)` |
| Markierung | Wichtigkeit „hoch“ | `SiriFields.apply` | `false`/`nil` setzt nichts |
| Tags | vorhandene Kontexte | `SiriFields.resolve`/`apply` | unbekanntes Tag: `unknownTag(name)`; leere Tags ignoriert |
| Abschnitt, Bilder | keines | `prepare` | mit Inhalt: `unsupported`, keine Aufgabe |

**Änderung an `SiriFields`.** Ein Link gilt als gleich, wenn sich zwei URLs nur im leeren Pfad `/` unterscheiden
(`https://a.de` und `https://a.de/`); so zählt Siris doppelte Lieferung einmal. Leere Tags (nach dem Trimmen
leere Zeichenfolge) werden ignoriert und lehnen nichts ab.

**Alternativen.**

- `CaptureService.save` um `titleFrom`, `due`, `project` erweitern: weniger Dateien, aber jede künftige
  Erfassung (Teilen, Watch) erbt Siri-Parameter. Verworfen; `save` bleibt der eine Einstieg.
- Fehler erst im Intent prüfen, `SiriCapture` nur schreiben: Prüfregeln wären ohne Siri nicht testbar.
  Verworfen.
- Siri-Angaben als `.ai` mit Überprüfung: war die Linie vor der Entscheidung vom 2026-10-06. Henning hat
  `.user` festgelegt; kippt nur, wenn er das ändert.

## Test Plan

### Automated Tests (TDD RED)

Neue Datei `LooseEndsTests/SiriCaptureTests.swift`, Swift Testing. Jeder Test hält den `TestStore` lokal.

- [ ] `titleOnlyCreatesTask`: GIVEN nur ein Titel WHEN `prepare` und `commit` THEN genau eine Aufgabe, Kanal
  `.siri`, Rohtext = Titel, keine Revision.
- [ ] `allFieldsLandOnTheTask`: GIVEN Titel, Notiz, Datum mit Uhrzeit, Liste, Wiederholung, Koordinate, Link,
  Markierung, Tag WHEN `commit` und neues `fetch` THEN trägt die Aufgabe alle Werte (vollständiger Pfad
  persistiert).
- [ ] `everyErrorLeavesNoTaskAndNoChanges` (parametrisiert: leerer Titel, zwei Links, unbekanntes Tag,
  nicht abbildbare Wiederholung, Ort nicht gefunden, ungültige Koordinate, Abschnitt mit Inhalt, Bilder mit
  Inhalt): GIVEN die Eingabe WHEN `prepare` THEN wirft den passenden Fehler, es gibt keine `TaskItem`, kein
  neues Projekt, und `hasChanges == false`.
- [ ] `coordinateNeedsNoGeocoding`: GIVEN Koordinate WHEN `prepare` THEN Geocoding-Fake wurde 0-mal aufgerufen.
- [ ] `addressOnlyGeocodesOnce`: GIVEN nur Adresse WHEN `prepare` THEN Fake genau 1-mal aufgerufen; Name = Adresse,
  wenn Siri keinen Namen lieferte.
- [ ] `addressWithoutHitIsPlaceNotFound`: GIVEN Fake ohne Treffer WHEN `prepare` THEN `placeNotFound`.
- [ ] `siriValuesAreUserRevisionsWithReasonSiri`: GIVEN Datum, Wiederholung, Ort, Projekt WHEN `commit` THEN je
  Feld genau eine Revision mit Autor `.user` und Grund „Siri“, Herkunft `user`.
- [ ] `repeatWithoutDateInventsNoDate`: GIVEN Wiederholung ohne Datum WHEN `commit` THEN Regel gesetzt,
  Fälligkeit leer.
- [ ] `noteIsAppendedToRawTextButNotToTitle`: GIVEN Titel „Steuer“ und Notiz „Belege holen“ WHEN `commit` THEN
  Rohtext „Steuer\nBelege holen“, Titel „Steuer“.
- [ ] `unknownListCreatesProject`: GIVEN keine Liste „Büro“ WHEN `commit` THEN genau ein Projekt „Büro“ und die
  Aufgabe darin.
- [ ] `existingProjectIsReusedByNameKey` (parametrisiert „büro“, „BÜRO “, „Buro“-Akzentvariante): GIVEN Projekt
  „Büro“ WHEN `commit` THEN weiterhin ein Projekt, die Aufgabe liegt darin.
- [ ] `duplicateProjectsPickSmallestSortOrder`: GIVEN zwei gleichnamige Projekte WHEN `commit` THEN das mit der
  kleinsten `sortOrder`.
- [ ] `linkWithAndWithoutTrailingSlashCountsOnce`: GIVEN `https://a.de` und `https://a.de/` WHEN `prepare` THEN
  kein Fehler, ein Link.
- [ ] `emptyTagsAreIgnored`: GIVEN Tags `["", " "]` WHEN `prepare` THEN kein Fehler, keine Kontexte, keine
  Revision.
- [ ] `siriValuesSurviveFirstEnrichmentPass`: GIVEN Aufgabe mit allen Siri-Feldern und ein Test-Enricher, der
  andere Werte liefert WHEN der `EnrichmentCoordinator` einmal läuft THEN bleiben alle Siri-Werte erhalten.
- [ ] `saveSignatureUnchanged`: GIVEN die bestehenden `CaptureService`-Tests WHEN die Suite läuft THEN grün ohne
  Änderung an `CaptureService.save`.

Kein UI-Test: Es entsteht keine sichtbare Änderung und kein Aufrufer im Produktpfad. Den echten Siri-Durchlauf
belegt Schnitt 2.

## Acceptance Criteria

- **AC-1:** Given nur ein Titel / When `prepare` und `commit` laufen / Then entsteht genau eine Aufgabe mit
  Kanal `.siri`, Rohtext gleich Titel, ohne Revision und ohne Projekt.
- **AC-2:** Given alle Felder (Titel, Notiz, Datum mit Uhrzeit, Liste, Wiederholung, Ort, Link, Markierung,
  Tag) / When `commit` läuft und die Aufgabe neu geladen wird / Then trägt sie jeden Wert, der Pfad ist
  persistiert.
- **AC-3:** Given eine Eingabe mit leerem Titel, zwei verschiedenen Links, unbekanntem Tag, nicht abbildbarer
  Wiederholung, nicht gefundenem Ort, ungültiger Koordinate, Abschnitt mit Inhalt oder Bildern mit Inhalt /
  When `prepare` läuft / Then wirft es den passenden Fehler, es entsteht keine Aufgabe und kein Projekt, und
  der `ModelContext` hat `hasChanges == false`.
- **AC-4:** Given ein Ort mit Koordinate / When `prepare` läuft / Then wird die Geocoding-Funktion nicht
  aufgerufen; Given ein Ort nur mit Adresse / Then genau einmal, und ohne Treffer wirft `prepare`
  `placeNotFound`.
- **AC-5:** Given Datum, Wiederholung, Ort und Liste / When `commit` läuft / Then hat jedes dieser Felder genau
  eine Revision mit Autor `.user` und Grund „Siri“, und die Herkunft des Orts ist `user`.
- **AC-6:** Given eine Wiederholung ohne Datum / When `commit` läuft / Then trägt die Aufgabe die Regel, aber
  keine Fälligkeit.
- **AC-7:** Given Siri-Werte in allen Feldern / When der erste Veredelungsdurchlauf des
  `EnrichmentCoordinator` mit einem Test-Enricher läuft, der andere Werte liefert / Then bleiben alle
  Siri-Werte erhalten.
- **AC-8:** Given der Stand nach diesem Schnitt / When der Diff geprüft wird / Then sind Signatur und Rumpf
  von `CaptureService.save` unverändert.
- **AC-9:** Given eine Liste, die als Projekt schon existiert (gleicher `nameKey`) / When `commit` läuft /
  Then bleibt die Zahl der Projekte gleich und die Aufgabe liegt im vorhandenen; Given mehrere gleichnamige
  Projekte / Then gilt das mit der kleinsten `sortOrder`; Given eine unbekannte Liste / Then entsteht genau
  ein Projekt.
- **AC-10:** Given Titel „Steuer“ und Notiz „Belege holen“ / When `commit` läuft / Then ist der Rohtext
  „Steuer“, Zeilenumbruch, „Belege holen“, und der Titel lautet „Steuer“.
- **AC-11:** Given die Links `https://a.de` und `https://a.de/` / When `prepare` läuft / Then zählen sie als
  ein Link und es gibt keinen Fehler; Given leere Tags / Then gibt es keinen Fehler, keine Kontexte und keine
  Revision.
- **AC-12:** Given `prepare` mit beliebiger Eingabe, auch mit Fehler / When es läuft / Then schreibt es nichts
  in den `ModelContext`.

## Abnahme

Abnahme nach Stufe 2 (Tests, Simulator-Start der App). Schnitt 1 liegt in `Shared/Services`, hat keinen
Aufrufer im Produktpfad und ändert weder `project.yml` noch Entitlements noch Info.plist. Begründung im
Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ Keine UI-Tests, weil nichts Sichtbares entsteht. Kein
Testhinweis an Henning.

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt, belegt durch die im Test Plan genannten Tests
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh sim-unit`), jeder Fehlerfall mit `hasChanges == false`
- [ ] Build erfolgreich (`./scripts/sim.sh build`), jeder Commit kompiliert
- [ ] App im Simulator gestartet und unverändert lauffähig (Stufe 2), Beleg registriert
- [ ] `docs/project/02-datenmodell-und-ansichten.md` aktualisiert
- [ ] CLAUDE.md-Abschnitt „Where things live“ nennt `SiriCapture`
- [ ] Folgearbeit (Schnitt 2, Schnitt 3) im Ticket #25 vermerkt, nichts davon in diesem Schnitt
- [ ] CI grün, Ticket-Board aktuell

## Risiken

1. **Keine Namensprüfung für Projekte heute.** Ein Doppel entstünde sonst durch Siri; Gegenmaßnahme ist die
   Suche über `nameKey` in `commit` (AC-9). Bestehende Dubletten werden nicht zusammengeführt.
2. **Aufgabe trotz Fehler.** Gegenmaßnahme: Prüfen und Schreiben getrennt, Test über alle Fehlerfälle (AC-3).
3. **Geocoding.** Nur Adresse braucht den Aufruf; er ist injiziert und im Test ein Fake. Der echte Dienst
   kommt in Schnitt 2.
4. **Schema-Felder des SDK (U1 bis U6).** Schnitt 1 kennt keine Schema-Typen; das Risiko liegt bei Schnitt 2.
5. **Datum als `Date` oder `DateComponents` (U3).** Schnitt 1 nimmt `Date` plus `hasTime`; ändert Schnitt 2 die
   Form, ändert sich nur die Übersetzung, nicht `commit`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — der Schnitt führt einen weiteren reinen Baustein in `Shared/Services` ein und bewegt
  sich in bestehenden Entscheidungen (ADR-3 abgeleitete Felder mit Herkunft, ADR-4 Veredelung nach der
  Erfassung, ADR-5 Lernen ist Wiedererkennen, ADR-6 Revisionen statt Undo).
- **Rationale:** Die Abweichung von ADR-9 (Ausführung im App-Prozess statt in einer App-Intents-Extension) ist
  Thema von Schnitt 2 und wird dort entschieden; Schnitt 1 hat keinen Intent und berührt sie nicht.

## Changelog

- 2026-10-15: Initial spec created (Schnitt 1 von 3 zu #25), aus Analyse und den Festlegungen von Henning
  (Autor `.user`, F1, F2, F5, Ort, Wiederholung ohne Datum).
