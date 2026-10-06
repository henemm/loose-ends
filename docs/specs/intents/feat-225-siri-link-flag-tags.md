---
entity_id: feat-225-siri-link-flag-tags
type: feature
created: 2026-10-06
updated: 2026-10-06
status: draft
workflow: feat-225-siri-link-flag-tags
---

# Spec: #225 — Siri-Link, -Markierung und -Tags abbilden (Vorbedingung für #25)

## Approval

- [ ] Approved

## Purpose

Henning hat am 2026-10-06 für #25 entschieden: „Erst alles bauen, dann liefern.“ Siris
Reminders-Schema (`createReminder`) verlangt neben Titel, Notiz, Datum und Liste auch `urls: [URL]`,
`isFlagged: Bool?` und `tags: Set<String>`. Die App speichert diese drei Angaben bisher nirgends;
ungenutzte Schemafelder wären stiller Datenverlust. #225 bildet sie als **reine Abbildung ohne
Intent und ohne Modell** auf eine neue Aufgabe ab:

- **Link** → `TaskItem.sourceURL`
- **Markierung** → Wichtigkeit „hoch“
- **Tags** → nur vorhandene Kontexte; ein unbekanntes Tag wird mit seinem Namen abgelehnt

Regelweg: Es gibt nichts zu verstehen, nur zuzuordnen. Ein Modell kommt nicht in Frage, weil kein
Sprachverstehen verlangt ist: Link, Flag und Tag-Namen sind strukturierte Werte. Der Aufrufer
(`CreateReminderIntent.perform()`) kommt erst mit #25; bis dahin gibt es keinen Aufrufer im Produktpfad.

## Source

- **Datei:** `Shared/Services/SiriFields.swift` (neu)
- **Bezeichner:** `struct SiriFields`, `static func resolve(_:in:) throws`, `static func apply(_:to:)`,
  `enum SiriFieldsError: LocalizedError`
- **Datei:** `Shared/Services/CatalogService.swift`
- **Bezeichner:** `nameKey(_:)` (von `private` auf intern)

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `CatalogService.nameKey` / `survivesBefore` (#157) | Namensregel | Eine Namensregel für „vorhandener Kontext“: getrimmt, Groß/Klein- und Akzent-unabhängig. `survivesBefore` wählt bei Dubletten den Überlebenden. |
| `RevisionService.set` | Vorbild | Nutzerrevision: Autor `.user`, `createdAt` und `seenAt` gesetzt, Herkunft `user`, keine Konfidenz |
| `EnrichmentWriter.encode(_:)` / `FieldCodec.encode` | Kodierung | Kontextnamen als JSON-Liste für die Revision (`newValue`) |
| `TaskItem`, `TaskContext`, `Revision`, `RevisedField`, `FieldSource`, `Importance` | Modell | Zielobjekte der Abbildung |
| `CaptureService.save` | Nachbar | bleibt **unberührt** (#25 erweitert die Signatur um `titleFrom`, `due`, `project`; eine zweite Änderung daran würde beim Zusammenführen kollidieren) |
| `EnrichmentCoordinator.applyImportanceRule`, Wiedererkennung | Downstream | schreiben Wichtigkeit nur bei leerem Feld, Kontexte nur bei leerem Feld und ohne Nutzereingriff: Siri-Werte überleben den ersten Lauf (geprüft, `EnrichmentCoordinator.swift:196-200`, `:313-329`) |
| `EnrichmentWriter.mayWrite` (`.reanalysis`) | Downstream | überschreibt nichts, was eine Revision mit Autor `.user` trägt: „Neu analysieren“ fasst Siri-Markierung und -Tags nicht an |
| `RecognitionRule` | Downstream | lernt aus Werten mit Herkunft `user`, nicht aus `ai` |
| #25 (`ReminderSchema`, `CreateReminderIntent`) | Aufrufer (später) | ruft `resolve`, `save`, `apply`, `ctx.save()` |

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `Shared/Services/SiriFields.swift` | CREATE | `SiriFields` (`urls`, `isFlagged`, `tags`), `resolve(_:in:) throws` (liest nur), `apply(_:to:)` (schreibt rein auf dem `TaskItem`, Aufrufer speichert), `SiriFieldsError` (`unknownTag(String)`, `multipleLinks(Int)`), ca. 90 LoC |
| `Shared/Services/CatalogService.swift` | MODIFY | `nameKey` von `private` auf intern, 1 Zeile |
| `LooseEndsTests/SiriFieldsTests.swift` | CREATE | Swift Testing mit `TestStore`, ca. 100 LoC |
| `docs/project/04-stand.md` | MODIFY | Verweis auf #225 beim Eintrag #25 |

**Umfang:** 4 Dateien (innerhalb der 4–5-Richtgröße), ca. +200/−1 LoC (unter 250). `project.yml` bindet
`Shared` als Ordner ein; die neue Datei braucht dort keinen Eintrag. Kein Pfad der Geräteliste wird
berührt.

## Implementation Details

**Zwei Schritte statt eines Einstiegs.** Siri darf keine Aufgabe zurücklassen, wenn es einen Fehler
meldet. Deshalb wird vor dem Speichern geprüft und erst danach geschrieben:

```
struct SiriFields: Sendable {
    var urls: [URL]
    var isFlagged: Bool?
    var tags: Set<String>

    struct Resolved { let url: URL?; let flagged: Bool; let contexts: [TaskContext] }

    /// Liest nur. Wirft vor dem Speichern, schreibt nichts.
    static func resolve(_ fields: SiriFields, in context: ModelContext) throws -> Resolved
    /// Schreibt rein auf dem TaskItem. Der Aufrufer speichert.
    static func apply(_ resolved: Resolved, to task: TaskItem, now: Date = Date())
}

enum SiriFieldsError: LocalizedError, Equatable {
    case unknownTag(String)     // Originalname, wie Siri ihn lieferte
    case multipleLinks(Int)     // Anzahl verschiedener Links
}
```

Ablauf für #25: `resolve` → `CaptureService.save` → `apply` → `ctx.save()`, alles synchron auf dem
MainActor ohne `await` dazwischen.

**Link.** `urls` wird entdoppelt (gleiche `URL` zählt einmal, Reihenfolge erhalten). Ergibt das genau
einen Link, wird er `sourceURL`. Kein Link setzt nichts. Mehr als ein verschiedener Link wirft
`multipleLinks(count)` (PO-Entscheidung, siehe unten). `sourceURL` wird gesetzt wie beim Teilen
(`SharedContent`): auf dem fertigen `TaskItem`, ohne Revision.

**Markierung.** `isFlagged == true` setzt `importance = .high`, `importanceSourceRaw = "user"`,
`importanceConfidence = nil` und schreibt genau eine Revision (`field: .importance`, `oldValue` =
bisheriges `importanceRaw`, `newValue` = `"high"`, Autor `.user`, Grund „Siri“, `createdAt` und
`seenAt` = `now`). `false` und `nil` setzen nichts und schreiben keine Revision: „nicht markiert“ heißt
nicht „niedrige Wichtigkeit“ (#220, #117: nie ein Standardwert bei fehlendem Signal).

**Tags.** Jedes Tag wird über `CatalogService.nameKey` mit den Namen aller `TaskContext` abgeglichen.
`FieldCodec.apply` scheidet aus, weil es Namen exakt vergleicht (`FieldCodec.swift:65`) und „garten“
nicht auf „Garten“ träfe. `resolve` liefert die gefundenen Kontexte:

- Kein Treffer für ein Tag → `unknownTag(name)` mit dem **Originalnamen**; der ganze Vorgang scheitert,
  es gibt kein Teilergebnis.
- Faltet sich ein Tag auf mehrere Kontexte (CloudKit-Dubletten, die `mergeDuplicateContexts` noch nicht
  bereinigt hat), gilt der Überlebende nach `survivesBefore` (Systemvorgabe, kleinste `sortOrder`,
  kleinste `id`), derselbe, den die Zusammenführung behalten wird.
- Zwei Tags, die sich auf denselben Kontext falten („garten“, „Garten“), ergeben einen Kontext.
- Leere Tag-Menge setzt nichts.

`apply` setzt `task.contexts` direkt, `contextsSourceRaw = "user"`, `contextsConfidence = nil` und
schreibt genau eine Revision (`field: .contexts`, `oldValue` = bisherige `FieldCodec.encode(.contexts)`
bzw. `nil` bei leerer Liste, `newValue` = `EnrichmentWriter.encode(Kontextnamen)`, Autor `.user`, Grund
„Siri“, `seenAt` = `now`). Die Kontextnamen sind die der echten Kontexte, nicht die von Siri gelieferte
Schreibweise. Die Reihenfolge ist nach `sortOrder`, dann `id` deterministisch.

**Urheber `.user` (PO-Entscheidung).** Siri-Markierung und -Tags gelten als Entscheidung des Nutzers:
Er hat sie selbst gesagt. Folgen: keine KI-Tönung im Detail, „Neu analysieren“ fasst die Werte nicht an,
die Wiedererkennung lernt daraus. Mit Autor `.ai` wäre alles davon anders.

**Link ohne Revision (bewusste Abweichung von der DoD-Zeile).** Issue #225 verlangt „Jede gesetzte
Angabe trägt eine Revision.“ Das gilt hier für Wichtigkeit und Kontexte. Der Link bekommt **keine**
Revision: Er ist Quellmaterial wie beim Teilen (dort ebenfalls ohne Revision). Ein neuer Fall
`RevisedField.sourceURL` müsste in 8 Dateien jede erschöpfende Fallunterscheidung erweitern
(`FieldCodec`, `FieldFormatting`, `FieldEditorView`, `RevisionService`, `TaskDetailView`, `DetailLayout`,
`EnrichmentWriter`, `RuleTrigger`) und machte den Link zu einem bearbeitbaren Feld, was weder gewünscht
noch im Scope ist. Diese Abweichung wird hier offen ausgewiesen, nicht verschwiegen.

**Fehlertext an Siri: nicht Teil dieses Tickets.** Siri zeigt einen Fehler aus `perform()` nur mit
eigenem Text an, wenn er `CustomLocalizedStringResourceConvertible` erfüllt; ein reines `LocalizedError`
zeigt keinen Text (Apple Developer Forums 713559, WWDC22 „Dive into App Intents“). `SiriFieldsError`
bekommt jetzt `LocalizedError`; die Konformität zu `CustomLocalizedStringResourceConvertible` kommt mit
#25, weil erst dort `AppIntents` importiert wird. Sie wird in #25 als Akzeptanzkriterium eingetragen.

**Folge für #25 (Hinweis, nicht Teil dieser Spec):** Siris Datum nutzt in #25 bisher Autor `.ai`. Es
zieht auf `.user` gleich, damit Datum, Markierung und Tags dieselbe Herkunft haben (Kommentar in #25
vermerkt).

## Test Plan

### Automated Tests (TDD RED)

Neue Datei `LooseEndsTests/SiriFieldsTests.swift`, Swift Testing. Jeder Test hält den `TestStore` lokal
(ein `ModelContext` hält seinen Container nicht).

- `singleLinkBecomesSourceURL`: Given eine Aufgabe und `urls = [A]` / When `resolve`, `apply` / Then
  `task.sourceURL == A`, keine Revision zum Link.
- `duplicateLinksCountOnce`: Given `urls = [A, A]` / When `resolve` / Then kein Fehler, `url == A`.
- `multipleLinksAreRejectedBeforeAnythingIsWritten`: Given `urls = [A, B]` / When `resolve` / Then wirft
  `multipleLinks(2)`, und der `ModelContext` hat keine Änderungen (`hasChanges == false`).
- `noLinksSetsNothing`: Given `urls = []` / When `resolve`, `apply` / Then `sourceURL == nil`.
- `flaggedSetsHighImportanceAsUser`: Given `isFlagged = true`, Wichtigkeit leer / When `apply` / Then
  `importance == .high`, `importanceSourceRaw == "user"`, `importanceConfidence == nil`; genau eine
  `.importance`-Revision (`oldValue == nil`, `newValue == "high"`, Autor `.user`, Grund „Siri“, `seenAt`
  gesetzt).
- `flaggedRevisionKeepsPreviousValue`: Given Wichtigkeit `medium` vorher / When `apply` mit `true` / Then
  Revision `oldValue == "medium"`.
- `notFlaggedWritesNothing` (parametrisiert `false` und `nil`): Then `importance == nil`, keine
  `.importance`-Revision (#220).
- `tagsMatchIgnoringCaseAndAccents`: Given Kontext „Garten“, Tag „garten “ / When `resolve`, `apply` /
  Then `task.contexts` enthält genau „Garten“, Revision `newValue` ist `["Garten"]` mit dem echten Namen.
- `tagsAreWrittenAsUserWithRevision`: Then `contextsSourceRaw == "user"`, `contextsConfidence == nil`,
  genau eine `.contexts`-Revision (`oldValue == nil`, Autor `.user`, Grund „Siri“, `seenAt` gesetzt).
- `unknownTagIsRejectedWithItsName`: Given Kontexte „Garten“, Tags `["Garten", "Bürro"]` / When `resolve` /
  Then wirft `unknownTag("Bürro")` mit dem Originalnamen; es gibt kein Teilergebnis.
- `tagsFoldingToTheSameContextGiveOne`: Given Tags `["garten", "GARTEN"]` / Then
  `task.contexts.count == 1`.
- `duplicateContextsPickTheSurvivor`: Given zwei Kontexte „Garten“ (verschiedene `sortOrder`, einer
  Systemvorgabe) / When `resolve` / Then der Überlebende nach `survivesBefore`, nicht der andere.
- `emptyTagsSetNothing`: Given `tags = []` / Then `task.contexts` leer, keine `.contexts`-Revision.
- `siriValuesSurviveReanalysis`: Given Aufgabe mit angewendeter Markierung / When `EnrichmentWriter` im
  Modus `.reanalysis` einen Entwurf mit anderer Wichtigkeit schreibt / Then bleibt `importance == .high`
  (die Nutzerrevision schützt das Feld).
- `siriValuesSurviveFirstPass`: Given Aufgabe mit angewendeter Markierung und Tag „Garten“ sowie ein
  früher erfasster Eintrag mit gleichem Rohtext und anderem Kontext / When der Durchlauf nach dem
  Erfassen (`EnrichmentCoordinator`, Regel- und Wiedererkennungsschritt, mit einem Test-Enricher, der
  eine andere Wichtigkeit liefert) läuft / Then bleiben `importance == .high` und `contexts == ["Garten"]`.
- `fullPathResolveSaveApply`: Given Kontext „Garten“ und alle drei Angaben / When `resolve`,
  `CaptureService.save`, `apply`, `context.save()` und neues `fetch` / Then trägt die Aufgabe Link,
  Wichtigkeit und Kontext (Durchlauf der Kette, nicht nur der Einzelteile).

**Kein neuer UI-Test, begründet:** Es entsteht keine View, kein UI-Element und kein sichtbarer Ablauf,
und es gibt bis #25 keinen Aufrufer im Produktpfad. Es existiert nichts, was ein UI-Test bedienen
könnte. Die Kette `resolve` → `save` → `apply` wird im Unit-Test `fullPathResolveSaveApply` über die
echten Dienste durchgespielt; den echten Siri-Durchlauf belegt #25 mit seinem Intent. CLAUDE.md verlangt
UI-Tests erst nach dem Design-Freeze und nur als Smoke-Tests.

## Acceptance Criteria

- **AC-1 Ein Link:** Given `urls` enthält nach Entdoppeln genau einen Link / When `resolve` und `apply`
  laufen / Then trägt `task.sourceURL` diesen Link, und es entsteht keine Revision dafür.
- **AC-2 Mehrere Links werden vor dem Speichern abgelehnt:** Given `urls` enthält mehr als einen
  verschiedenen Link / When `resolve` läuft / Then wirft es `multipleLinks(count)` mit der Anzahl der
  verschiedenen Links, vor `CaptureService.save`, und es entsteht keine Aufgabe. Gleiche URLs zählen
  vorher einmal.
- **AC-3 Keine Links:** Given `urls` ist leer / Then bleibt `sourceURL` leer und nichts wird abgelehnt.
- **AC-4 Markierung:** Given `isFlagged == true` / When `apply` läuft / Then ist `importance == .high`,
  `importanceSourceRaw == "user"`, `importanceConfidence == nil`, und es entsteht genau eine Revision
  (`.importance`, Autor `.user`, Grund „Siri“, `oldValue` = vorheriger Rohwert oder `nil`,
  `newValue == "high"`, `seenAt` gesetzt).
- **AC-5 Nicht markiert:** Given `isFlagged == false` oder `nil` / When `apply` läuft / Then bleibt die
  Wichtigkeit unverändert und es entsteht keine Revision (#220).
- **AC-6 Tags nur vorhandene Kontexte:** Given jedes Tag trifft nach der Namensregel (getrimmt,
  Groß/Klein- und Akzent-unabhängig) einen vorhandenen Kontext / When `apply` läuft / Then trägt die
  Aufgabe genau diese Kontexte, `contextsSourceRaw == "user"`, `contextsConfidence == nil`, und es
  entsteht genau eine Revision (`.contexts`, Autor `.user`, Grund „Siri“, `newValue` = JSON-Liste der
  echten Kontextnamen, `seenAt` gesetzt).
- **AC-7 Unbekanntes Tag lehnt alles ab:** Given mindestens ein Tag trifft keinen Kontext / When
  `resolve` läuft / Then wirft es `unknownTag(name)` mit dem Originalnamen dieses Tags, vor dem
  Speichern, ohne Teilergebnis: weder Link noch Markierung noch Kontexte werden gesetzt, es entsteht
  keine Aufgabe.
- **AC-8 Dubletten und Faltung:** Given ein Tag faltet sich auf mehrere Kontexte / Then gilt der
  Überlebende nach `survivesBefore`. Given zwei Tags falten sich auf denselben Kontext / Then trägt die
  Aufgabe ihn einmal.
- **AC-9 Leere Tags:** Given `tags` ist leer / Then bleibt `contexts` unverändert, keine Revision.
- **AC-10 Schutz vor Überschreiben:** Given Markierung und Tags sind angewendet / When „Neu analysieren“
  (`.reanalysis`) schreibt oder der erste Durchlauf nach dem Erfassen läuft / Then bleiben Wichtigkeit
  und Kontexte erhalten (belegt durch `siriValuesSurviveReanalysis` und `siriValuesSurviveFirstPass`).
- **AC-11 `resolve` schreibt nichts:** Given beliebige Eingabe / When `resolve` läuft, auch bei Fehler /
  Then ist der `ModelContext` unverändert (keine eingefügten oder geänderten Objekte).
- **AC-12 `CaptureService.save` unberührt:** Signatur und Rumpf von `CaptureService.save` sind nach dem
  Ticket unverändert (im Diff prüfbar).
- **AC-13 Eine Namensregel:** `nameKey` ist die einzige Implementierung der Namensfaltung; `SiriFields`
  enthält keine Kopie davon.

## Risiken

1. **Konflikt mit #25 beim Zusammenführen.** Gegenmaßnahme: eigene Datei, `CaptureService.save`
   unberührt (AC-12). Verbleibende Berührung: #25 ruft `resolve`/`apply` um sein eigenes `save` herum.
2. **Aufgabe entsteht trotz Siri-Fehler.** Gegenmaßnahme: Prüfen und Schreiben sind getrennt (AC-2,
   AC-7, AC-11); der Aufrufer muss `resolve` vor `save` aufrufen. Das legt #25 als Akzeptanzkriterium fest.
3. **Siri zeigt keinen Fehlertext.** Gegenmaßnahme: Out of Scope hier, Konformität kommt mit #25.
4. **Link ohne Revision weicht von der DoD-Zeile ab.** Offen ausgewiesen, Begründung unter
   „Implementation Details“. Wollte Henning den Link revisionspflichtig, wäre das ein eigenes Ticket mit
   acht Folgeänderungen.
5. **Siris Tag-Schreibweise entspricht keinem Kontext.** Gewollt abgelehnt („nur vorhandene“), statt
   still zu ignorieren oder anzulegen.

## Alternativen

- **Ein einziger Einstieg `SiriCapture.save(text, fields:, in:)`**, der `resolve`, `save` und `apply`
  bündelt: einfacher für #25, verdoppelt aber die Erweiterung von `save` aus #25 und müsste beim
  Zusammenführen neu gemacht werden. Verworfen. Würde die Entscheidung „`CaptureService.save` bleibt
  unberührt“ kippen; keine ADR betroffen.
- **`CaptureService.save(..., siri: SiriFields? = nil)`:** nur eine Aufrufstelle, kollidiert aber
  textlich mit #25. Verworfen.
- **Unbekanntes Tag ignorieren oder als neuen Kontext anlegen** statt ablehnen: widerspricht Hennings
  Vorgabe „nur vorhandene“ mit Ablehnung. Ignorieren wäre stiller Datenverlust, Anlegen verschmutzte den
  Katalog, den #157 eindeutig hält.
- **Mehrere Links: den ersten nehmen oder die übrigen in den Rohtext schreiben:** Der erste Link wäre
  ein stilles Wegwerfen der anderen, der Rohtext ist unveränderlich (ADR-3). Von Henning zugunsten von
  Ablehnen verworfen.
- **Autor `.ai` wie beim Siri-Datum in #25:** gäbe KI-Tönung und ließe „Neu analysieren“ die Siri-Werte
  überschreiben, obwohl der Nutzer sie gesagt hat. Von Henning verworfen; kippt die Annahme „Siri-Angaben
  sind `.ai`“ aus #25 (Entscheidung 4), siehe Folge-Hinweis.
- **Revision für den Link (`RevisedField.sourceURL`):** konsistenter mit der DoD-Zeile, kostet aber acht
  Dateien und macht den Link zum bearbeitbaren Feld. Verworfen.
- **Modell statt Abbildung:** kein Beleg, dass es etwas zu verstehen gäbe; der Regelweg ist die Lösung,
  das Modell nicht einmal eine Alternative.

## Out of Scope

- `CreateReminderIntent`, `ReminderSchema` und jeder Aufruf aus Siri (#25).
- `CustomLocalizedStringResourceConvertible` am Fehler (kommt mit #25).
- `images` aus dem Schema.
- Umstellen von Siris Datum auf Autor `.user` (Hinweis für #25).
- Neue Kontexte aus Tags anlegen; Projekte aus Tags.
- UI und sichtbare Texte (der Fehlertext erreicht erst mit #25 eine Oberfläche).

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt, belegt durch die im Test Plan genannten Tests
- [ ] `./scripts/sim.sh unit` grün
- [ ] Build erfolgreich (`./scripts/sim.sh build` ohne Errors), jeder Commit kompiliert
- [ ] Abnahme nach Stufe 2 (Tests, Simulator-Start der App). Begründung im Abschlussbericht: „Kein Pfad
      der Geräteliste berührt.“ (`Shared/Services` ist nicht `Shared/Intents`, `Shared/Persistence` oder
      `FoundationModelsEnricher`/`EnrichmentCoordinator`; `project.yml` bleibt unverändert)
- [ ] Eintrag #25 in `docs/project/04-stand.md` verweist auf #225
- [ ] PR schließt #225 (`Closes #225`); Hinweis auf die Folgen für #25 (Reihenfolge `resolve`, `save`,
      `apply`; Fehlertext-Konformität; Siri-Datum auf `.user`) als Kommentar in #25
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
- [ ] CI grün
- [ ] Kein manueller Testhinweis an Henning

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — die Änderung bewegt sich innerhalb bestehender Entscheidungen und führt keine neue Schicht ein.

- **Rationale:** `SiriFields` ist ein weiterer reiner Baustein in `Shared/Services` neben
  `CaptureService` und `CatalogService` (ADR-3 abgeleitete Felder mit Herkunft; ADR-6 Revisionen statt
  Undo; ADR-5 Lernen ist Wiedererkennen, daher Autor `.user`). „Regeln vor Modell“ steht als Arbeitsregel
  in `CLAUDE.md`; die einzige Namensregel für Kontexte stammt aus #157. Die Entscheidung „Link ohne
  Revision“ ist begründet und unter „Implementation Details“ ausgewiesen, rechtfertigt aber keine eigene
  ADR-Nummer.

## Changelog

- 2026-10-06: Spec aus Analyse und PO-Entscheidungen (mehrere Links ablehnen; Autor `.user` für
  Markierung und Tags) erstellt.
- 2026-10-06: Test `siriValuesSurviveFirstPass` für AC-10 ergänzt (Fund aus dem PO-Briefing).
