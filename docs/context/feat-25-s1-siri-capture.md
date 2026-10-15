# Context: feat-25-s1-siri-capture

## Request Summary
#25 Schnitt 1: `SiriCapture` in `Shared/Services`, ein reiner Dienst ohne Siri-Typen. Er prüft alle Siri-Angaben
(`prepare`, wirft vor dem Speichern) und schreibt sie danach in eine neue Aufgabe (`commit`). Schnitt 2 (Intent und
Entität, Gerätestufe) und Schnitt 3 (Ändern, Parken, Liste anlegen) folgen. Ausgeliefert wird erst nach #240.

Entscheidungen von Henning (2026-10-06 bis 08, Ticket #25): Siri-Angaben tragen Autor `.user` mit Grund „Siri“;
F1 Notiz wird mit Zeilenumbruch an den Rohtext angehängt; F2 unbekannte Liste legt das Projekt an (Eindeutigkeit
der Namen wie bei Kontexten); F3 Siri parkt statt zu löschen; F5 Abschnitt und Bilder sichtbar ablehnen.
Der Cloud-Entwurf der Spec (Kommentar in #25 vom 2026-10-08) ist die Vorlage, F2/F3 dort überholt.

## Related Files
| Datei | Relevanz |
|---|---|
| `Shared/Services/CaptureService.swift:12` | `save(_:via:sourceURL:in:)` legt die Aufgabe an (Rohtext, Kanal, Titel per `TitleRule`); bleibt unverändert |
| `Shared/Services/SiriFields.swift` | `resolve` (prüft Links ≤ 1, Tags) vor dem Speichern, `apply` (Link, Markierung, Kontexte, Revision „Siri“) danach |
| `Shared/Services/SiriRepeatMapping.swift` | `map` → `.rule` oder `.unmappable(Set<Unmappable>)`; `apply` setzt `RepeatRule` mit Autor `.user` |
| `Shared/Services/RevisionService.swift:61` | `set(field, encoded, task, …, now, force)` erzeugt die Revision mit Autor |
| `Shared/Services/CatalogService.swift:14,129` | `addProject(named:in:existing:)`, `nameKey` (trim, Groß/Klein, Akzente); **Projekte haben keine Namensprüfung** (CLAUDE.md: „Projects are not covered yet“) |
| `Shared/Services/FieldCodec.swift:74` | Projektzuordnung über Namen |
| `Shared/Models/TaskPlace.swift` | Struct mit Name, Koordinate, Ereignis; Radius fest 150 m; Init liefert `nil` bei leerem Namen/ungültiger Koordinate |
| `Shared/Services/PlaceEditing.swift:16` | `set(_:on:now:)` schreibt den Ort mit Revision |
| `Shared/Intents/CaptureTextIntent.swift:17` | heutiger Siri-Weg, `CaptureService.save(text, via: .siri)` |
| `LooseEndsTests/EnrichmentTests.swift:31` | `TestStore` hält den Container als Feld (sonst Absturz) |
| `LooseEndsTests/SiriFieldsTests.swift`, `SiriRepeatMappingTests.swift`, `TaskPlaceTests.swift` | Vorbilder für Testaufbau |

Nicht vorhanden auf `main`: `ReminderSchema`, `ReminderEntity`, `TaskEntity`. Der Code aus der Sicherung
(`wip/25-siri-sicherung`, `wip/25-siri-red-tests`) kompiliert auf aktuellem `main` (Simulator-Bau 2026-10-15
erfolgreich, einschließlich App-Intents-Metadaten); er gehört zu Schnitt 2.

## Existing Patterns
- Zwei Schritte „prüfen, dann schreiben“ wie bei `SiriFields` (`resolve` → `save` → `apply` → `ctx.save()`).
- Reine Logik über Modellobjekten, der Aufrufer speichert (Abschnitt „Where things live“ in CLAUDE.md).
- Siri-Werte sind Nutzerwerte: Autor `.user`, damit „Neu analysieren“ sie nicht überschreibt (#225).
- Fehler als eigene Enums; für Siri später `CustomLocalizedStringResourceConvertible` (Schnitt 2, wegen `AppIntents`).

## Dependencies
- Upstream: `CaptureService`, `SiriFields`, `SiriRepeatMapping`, `PlaceEditing`, `RevisionService`, `CatalogService`.
- Downstream: noch keiner im Produktpfad. Schnitt 2 ruft `SiriCapture` aus dem Intent auf.

## Existing Specs
- `docs/specs/feat-226-ortserinnerungen.md` (Ort von Siri: dort `.rule`, durch die Entscheidung vom 2026-10-06 jetzt `.user`)
- `docs/specs/` zu #224/#225 (SiriRepeatMapping, SiriFields)
- Cloud-Entwurf in #25 (Kommentar 2026-10-08), alte Spec nur auf `wip/25-siri-red-tests`

## Risks & Considerations
- **Projekt-Eindeutigkeit (F2):** Für Projekte gibt es heute keine Namensprüfung. Siri-Anlegen darf kein Doppel
  erzeugen; die Prüfung per `nameKey` gehört in diesen Schnitt (oder ein Vorgänger-Baustein), nicht in die UI.
- **Geocoding:** Nur Adresse ohne Koordinate braucht einen Aufruf; die Funktion wird injiziert, im Test ein Fake.
- **Fehlerfall ohne Rest:** Nach jedem Fehler darf keine Aufgabe zurückbleiben (`hasChanges == false`).
- **SDK-Felder (U1–U6):** Schnitt 1 kennt keine Schema-Typen, das Risiko liegt bei Schnitt 2.
- **Geräteliste:** Schnitt 1 berührt keinen Pfad (`Shared/Services`). Abnahme endet nach Stufe 2.
- **Umfang:** Cloud-Entwurf schätzt ca. 140 Zeilen Code; Tests zählen nicht zur Grenze.

## Analysis

### Type
Feature (reine Logik, Schnitt 1 von 3 zu #25).

### Without the model this fails because …
Gilt nicht: Es ist kein Modell im Spiel. Siri liefert fertig strukturierte Werte; es gibt nichts auszulegen,
nur zuzuordnen (Regeln vor Modell). Die Veredelung läuft danach wie bei jeder Erfassung (ADR-4) und füllt nur
Felder, die Siri leer ließ.

### Affected Files (with changes)
| File | Change Type | Description |
|---|---|---|
| `Shared/Services/SiriCapture.swift` | CREATE | `Input`, `prepare` (async, liest, wirft), `commit` (MainActor, ohne `await`), `SiriCaptureError` (~140 LoC) |
| `Shared/Services/CatalogService.swift` | MODIFY | Projektsuche über `nameKey` (vorhandenes Projekt benutzen statt Doppel), für F2 (~+10 LoC) |
| `Shared/Services/SiriFields.swift` | MODIFY | Link gleich, wenn nur der leere Pfad `/` fehlt; leere Tags ignorieren (~+8 LoC) |
| `LooseEndsTests/SiriCaptureTests.swift` | CREATE | Tests (zählen nicht zur Grenze) |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | `sourceURL` „oder Siri-Link“, Abbildung der Schema-Felder |

4 bis 5 Dateien, rund 160 Zeilen Code: innerhalb der Grenzen. `CaptureService.save` bleibt unverändert.

### Scope Assessment
- Files: 5 · Estimated LoC: +160 Code / −0 · Risk Level: LOW bis MEDIUM
  (neuer Dienst ohne Aufrufer im Produktpfad; Risiko liegt in der Zuordnung der Felder, nicht im Umfeld).

### Technical Approach
1. **Zwei Schritte.** `prepare` löst alles auf (Links ≤ 1, Tags, Wiederholung über `SiriRepeatMapping.map`,
   Liste, Ort, Abschnitt/Bilder) und wirft vor jedem Schreiben. `commit` läuft synchron auf dem MainActor:
   `CaptureService.save` → Datum → Projekt → Wiederholung → Ort → `SiriFields.apply` → `ctx.save()`.
   Nach jedem Fehler bleibt keine Aufgabe zurück.
2. **Keine Siri-Typen in `Shared/Services`.** `Input` ist ein reines Struct (Strings, `Date`, `URL`,
   `Calendar.RecurrenceRule`, Ort als Name/Adresse/Koordinate/Ereignis). Die Übersetzung aus den Schema-Typen
   macht in Schnitt 2 der Intent. So ist alles ohne Siri testbar.
3. **F1 Notiz:** Rohtext = Titel, Zeilenumbruch, Notiz. `TitleRule` fasst Zeilenumbrüche zu Leerzeichen zusammen und
   nähme die Notiz in den Titel; deshalb wird der Titel aus Siris Titel allein gebildet (`TitleRule.title(from:)`
   auf den Titel, nach dem Speichern gesetzt), der Rohtext bleibt unverändert beide Teile.
4. **F2 Liste:** vorhandenes Projekt über `nameKey` (Groß/Klein, Akzente, Leerzeichen) benutzen, sonst anlegen
   (`addProject`). Das Anlegen geschieht erst in `commit`, damit ein Fehler nichts hinterlässt.
5. **Datum:** über den vorhandenen Feldweg (`RevisionService.set(.dueDate …)`, Autor `.user`, Grund „Siri“);
   `dueHasTime` aus dem Eingabewert (Uhrzeit vorhanden ja/nein). Wiederholung ohne Datum bekommt kein erfundenes Datum.
6. **Ort:** Koordinate direkt, nur Adresse einmal über eine injizierte Funktion (im Test ein Fake, produktiv in
   Schnitt 2); kein Treffer → `placeNotFound`. Name: Siris Name, sonst die Adresse. Herkunft `user`, nicht `rule`.
7. **F5:** Abschnitt oder Bilder mit Inhalt → `unsupported`, keine Aufgabe.

### Alternativen (und was sie kippen würden)
- **A: Schlankes `CaptureService.save` erweitern** (`titleFrom`, `due`, `project`). Weniger Dateien, aber jede
  künftige Erfassung (Teilen, Watch) erbt die Siri-Parameter; die Hülle würde zum Sammelbecken. Verworfen; kippt
  nichts, `save` bleibt der eine Einstieg.
- **B: Fehler erst im Intent prüfen, `SiriCapture` nur schreiben.** Dann lägen Prüfregeln im Intent und wären ohne
  Siri nicht testbar. Verworfen.
- **C: Siri-Angaben als `.ai` mit Überprüfung.** Wäre die Linie vor der Entscheidung vom 2026-10-06; Henning hat
  `.user` festgelegt. Kippt nur, wenn er die Entscheidung ändert.

### Dependencies
- Upstream: wie im Kontext. Downstream: Schnitt 2 (Intent), danach Schnitt 3.

### Open Questions
- [ ] Datum aus Siri: `Date` oder `DateComponents`? Entscheidet, ob „mit Uhrzeit“ erkennbar ist (U3). Schnitt 1
      nimmt `Date` plus ein Feld `hasTime`; die Zuordnung aus dem SDK folgt in Schnitt 2.
- [ ] Gleichnamige Projekte, die schon doppelt existieren: erstes nach `sortOrder` benutzen (deterministisch wie bei
      Kontexten). Kein Zusammenführen in diesem Schnitt.
