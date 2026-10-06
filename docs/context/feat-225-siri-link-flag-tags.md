# Context: feat-225-siri-link-flag-tags

## Request Summary
Vorbedingung für #25 (Henning, 2026-10-06: „Erst alles bauen, dann liefern“). Drei Angaben aus Siris
Reminders-Schema werden als reine Abbildungen ohne Intent und ohne Modell auf eine neue Aufgabe
gesetzt. Link → `sourceURL`. Markierung → Wichtigkeit „hoch“. Tags → nur vorhandene Kontexte; ein
unbekanntes Tag wird mit seinem Namen abgelehnt.

## Recherche (mit Quellen)
- **Sichtbare Ablehnung durch Siri:** Ein Fehler, den `perform()` wirft, zeigt Siri bzw. Kurzbefehle
  nur dann mit eigenem Text an, wenn er `Swift.Error` und `CustomLocalizedStringResourceConvertible`
  erfüllt (`localizedStringResource`). Ein reines `LocalizedError` zeigt keinen Text.
  Quellen: [Apple Developer Forums 713559](https://developer.apple.com/forums/thread/713559),
  [WWDC22 „Dive into App Intents“](https://developer.apple.com/videos/play/wwdc2022/10032/),
  [instil.co: Siri with App Intents](https://instil.co/blog/siri-with-app-intents).
- **Schema verlangt alle Parameter:** `createReminder` muss `isFlagged: Bool?`, `tags: Set<String>`,
  `urls: [URL]` und `images` deklarieren, auch wenn die App nur einen Teil nutzt
  ([Mindwtr #915](https://github.com/dongdongbh/Mindwtr/issues/915); eigener Befund im vollen Bau, #25).
  Typen laut Schnitt-1-Code von #25: `isFlagged: Bool?`, `tags: Set<String>`, `urls: [URL]`.
- Mindwtr übernimmt nur Felder, die zur eigenen Semantik passen. Ob unpassende Felder abgelehnt oder
  ignoriert werden, steht dort nicht.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Services/CaptureService.swift:11-27` | einziger Schreibweg; `save(_:via:sourceURL:in:)`, `sourceURL` nur über den `TaskItem`-Init (`TaskItem.swift:15,81-84`) |
| `Shared/Enrichment/EnrichmentCoordinator.swift:196-215` | `applyImportanceRule`: Muster für Wichtigkeit mit Revision, Herkunft, Konfidenz 1.0 |
| `Shared/Enrichment/EnrichmentCoordinator.swift:314-327` | Muster der Wiedererkennung für Kontexte (oldValue nil bei leer, sonst `EnrichmentWriter.encode(names)`) |
| `Shared/Services/CatalogService.swift:76-84` | `nameKey` / `sameName` (#157-Namensregel: getrimmt, Groß/Klein- und Akzent-unabhängig), heute **private** |
| `Shared/Services/FieldCodec.swift:18,47-50,63-67` | Kodierung von Wichtigkeit und Kontexten; `apply` vergleicht Kontextnamen **exakt** |
| `Shared/Services/SharedContent.swift:14-33` | Teilen behält genau einen Link (Priorität `message:`, sonst `urls.first`), weitere fallen still weg |
| `Shared/Services/RevisionService.swift:94-108` | Herkunft `ai`/`rule` gilt als zurücksetzbar |
| `Shared/Enrichment/RecognitionRule.swift:89-91` | Kontexte mit Autor `.ai` sind keine Quelle der Wiedererkennung |
| `Shared/Models/Enums.swift:19,31,58` | `FieldSource`, `Importance`, `RevisedField` |
| `Shared/Intents/ReminderSchema.swift` (nur im Worktree `polished-skipping-valley`, #25) | späterer Aufrufer, nicht Teil dieses Tickets |

## Existing Patterns
- Abgeleitete Felder: Wert, `*SourceRaw`, `*Confidence` und eine `Revision(task:field:oldValue:newValue:author:reason:)`.
  Siris Datum nutzt in #25 Autor `.ai`, Herkunft `ai`, Konfidenz 1.0 und Grund „Siri“. Daran richten sich Markierung und Tags aus.
- Dienste sind rein über den Modellobjekten, der Aufrufer speichert (CLAUDE.md, `Shared/Services`).
- Tests: Swift Testing, Container lokal oder in `TestStore` gehalten (`EnrichmentTests.swift:28-38`).

## Dependencies
- Upstream: `TaskItem`, `TaskContext`, `Revision`, `FieldSource`, `Importance`, die Namensregel von `CatalogService`.
- Downstream: Im Produktpfad noch keiner. Erst `CreateReminderIntent.perform()` aus #25 ruft die Abbildung auf.

## Existing Specs
- `docs/specs/intents/feat-25-reminders-schema.md` (im Worktree von #25): Abbildungsregeln für Titel, Notiz, Datum, Liste.
- Spec zu #157 (Kontexte eindeutig): Namensregel.

## Risks & Considerations
- **Konflikt mit #25:** #25 erweitert `CaptureService.save` um `titleFrom`, `due` und `project`. Ändert
  #225 dieselbe Signatur, entsteht ein Konflikt beim Zusammenführen. Vorzug: eine eigene Abbildung über
  dem fertigen `TaskItem`, die nach `save` läuft. `save` bleibt dann unberührt.
- **Tag-Ablehnung muss vor dem Speichern greifen.** Sonst entsteht eine Aufgabe, obwohl Siri einen Fehler meldet.
  Prüfen und Anwenden werden deshalb getrennt: Erst wird geprüft, ohne zu schreiben, danach gespeichert und angewendet.
- **Mehrere Links:** `sourceURL` fasst einen Link. Das Teilen kürzt heute still auf einen. Für Siri ist
  das offen: PO-Frage, ob abgelehnt wird, der erste Link genommen wird oder die übrigen in den Rohtext
  kommen (Letzteres kollidiert mit ADR-3).
- **Namensregel teilen:** `CatalogService.nameKey` ist private. Wird es sichtbar gemacht, ist das eine
  kleine Änderung an einer fremden Datei. Eine Kopie der Regel hätte dagegen zwei Wahrheiten.
- **„Neu analysieren“** darf eine Siri-Wichtigkeit bzw. Siri-Kontexte ersetzen (Autor `.ai` zählt nicht als
  Nutzerentscheidung). Das ist dasselbe Verhalten wie beim Siri-Datum in #25, Entscheidung 4.
- **`isFlagged == false` bzw. nil** setzt nichts. Dass „nicht markiert“ keine niedrige Wichtigkeit bedeutet, entspricht #220.
- Kein Pfad der Geräteliste wird berührt, solange `Shared/Intents/` nicht geändert wird.

## Analysis

### Type
Feature (reine Abbildung, kein Intent, kein Modell — Regelweg, ein Modell kommt nicht in Frage).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Services/SiriFields.swift` | CREATE | `SiriFields` (urls, isFlagged, tags), `resolve(_:in:) throws` vor dem Speichern, `apply(_:to:)` danach, `SiriFieldsError` (`unknownTag(String)`, `multipleLinks(Int)`) — ca. 90 LoC |
| `Shared/Services/CatalogService.swift` | MODIFY | `nameKey` von `private` auf intern (1 Zeile), damit es nur eine Namensregel gibt (#157) |
| `LooseEndsTests/SiriFieldsTests.swift` | CREATE | Swift Testing mit `TestStore` (`EnrichmentTests.swift:30-38`) — ca. 100 LoC |
| `docs/project/04-stand.md` | MODIFY | Verweis auf #225 beim Eintrag #25 (Zeile 128) |

`project.yml` bindet `Shared` als Ordner ein (Zeile 40), daher braucht die neue Datei dort keinen Eintrag.

### Scope Assessment
- Files: 4
- Estimated LoC: ca. +200/-1
- Risk Level: LOW. Es gibt keinen Aufrufer im Produktpfad, bis #25 kommt. Kein Pfad der Geräteliste wird berührt.

### Technical Approach
- **Zwei Schritte, `CaptureService.save` bleibt unberührt** (sonst Konflikt mit der Erweiterung in #25).
  `resolve` liest die Kontexte und gleicht jedes Tag über `CatalogService.nameKey` ab. Es schreibt nichts.
  Ein unbekanntes Tag wirft `unknownTag(name)`, dann entsteht keine Aufgabe. Schlägt ein Tag fehl, scheitert der ganze
  Vorgang, es gibt kein teilweises Ergebnis. Faltet sich ein Tag auf mehrere Kontexte (CloudKit-Dubletten), wird der
  Überlebende nach der Regel von `survivesBefore` gewählt (`CatalogService.swift:70`). Zwei Tags, die sich gleich falten,
  ergeben einen einzigen Kontext.
  `apply` ist rein über dem `TaskItem`, der Aufrufer speichert (Muster aus `Shared/Services`). Ablauf für #25:
  `resolve`, dann `save`, dann `apply`, dann `ctx.save()`. Alles läuft synchron auf dem MainActor ohne `await` dazwischen.
- **Markierung:** `isFlagged == true` setzt `importance = .high`, die Herkunft und eine Revision (oldValue
  `importanceRaw`, newValue `high`, Grund „Siri“). `false` und `nil` setzen nichts und schreiben keine Revision (#220).
- **Tags:** `task.contexts` wird direkt gesetzt, mit Herkunft und einer Revision (oldValue nil, newValue
  `EnrichmentWriter.encode(echte Kontextnamen)`). `FieldCodec.apply` scheidet aus, weil es Namen exakt vergleicht
  (`FieldCodec.swift:64`).
- **Link:** Genau ein Link (nach Entfernen von Dubletten) wird zu `sourceURL`. Keine Links setzen nichts. Für mehrere Links: siehe Open Questions.
  **Keine Revision für den Link.** Entscheidung des Tech Leads: Der Link ist Quellmaterial wie beim Teilen (heute ohne
  Revision). Ein Fall `RevisedField.sourceURL` müsste in 8 Dateien jede erschöpfende Fallunterscheidung erweitern
  (FieldCodec, FieldFormatting, FieldEditorView, RevisionService, TaskDetailView, DetailLayout, EnrichmentWriter,
  RuleTrigger) und machte den Link zu einem bearbeitbaren Feld. Die DoD-Zeile „Jede gesetzte Angabe trägt eine
  Revision“ gilt damit für Wichtigkeit und Kontexte.
- **Fehler an Siri:** `SiriFieldsError` bekommt jetzt nur `LocalizedError`. Die Konformität zu
  `CustomLocalizedStringResourceConvertible` (nötig, damit Siri den Text zeigt) kommt mit #25, weil dort der Intent
  `AppIntents` importiert. Sie wird in #25 als Akzeptanzkriterium eingetragen.

### Abhängigkeiten / Verhalten nach dem Erfassen (geprüft)
- Der Durchlauf nach dem Erfassen (`processPending`, asynchron über `ContentView` onChange) schreibt die Wichtigkeit nur, wenn sie
  leer ist (`EnrichmentCoordinator.swift:196-200`). Die Wiedererkennung schreibt Kontexte nur, wenn sie leer sind und
  der Nutzer sie nie angefasst hat (`:313-329`). Das Modell setzt keine Kontexte (#215). Die Siri-Werte überleben deshalb den ersten Lauf.
- „Neu analysieren“ (`EnrichmentWriter.mayWrite` `.reanalysis`, `EnrichmentWriter.swift:109-114`) überschreibt jedes
  Feld ohne eine Revision mit Autor `.user`.
- Die Wiedererkennung lernt nicht aus Werten mit der Herkunft `ai` (`RecognitionRule.swift:89-91`) und bevorzugt `user`.
- `TaskContext` hat kein Archiv-Flag, alle Kontexte zählen.

### Alternativen
- **Ein einziger Einstieg `SiriCapture.save(text, fields:, in:)`**, der `resolve`, `save` und `apply` bündelt. Das ist für #25
  einfacher, verdoppelt aber die Erweiterung von `save` aus #25 und muss beim Zusammenführen neu gemacht werden.
- **`CaptureService.save(..., siri: SiriFields? = nil)`** hat nur eine Aufrufstelle, kollidiert aber textlich mit #25.
- **Unbekanntes Tag ignorieren statt ablehnen:** Das widerspricht Hennings Vorgabe „nur vorhandene“ mit
  Ablehnung und hätte stillen Datenverlust zur Folge.

### PO-Entscheidungen (Henning, 2026-10-06)
- **Mehrere Links: Ablehnen.** `resolve` wirft `multipleLinks(count)` vor dem Speichern, es entsteht keine Aufgabe.
  Gleiche URLs werden vorher entdoppelt, abgelehnt wird erst bei mehr als einem verschiedenen Link.
- **Urheber von Markierung und Tags: der Nutzer.** Revision mit Autor `.user` und Grund „Siri“, Herkunft `user`,
  ohne Konfidenz (wie `RevisionService.set`, `seenAt` gesetzt). „Neu analysieren“ fasst die Werte nicht an, die
  Wiedererkennung lernt daraus, und es gibt keine KI-Tönung. Folge für #25: Siris Datum zieht auf `.user` gleich
  (als Kommentar in #25 vermerkt).

### Open Questions
- keine
