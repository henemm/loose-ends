# Context: Deutsche Begründungstexte der Terminregel (#98)

## Request Summary
`DueDateRule` liefert für jede Ausdrucksart einen englischen Begründungssatz ("From 'next' plus a
weekday in the note: the following week."), der im Aufgaben-Detail und im Feld-Editor erklärt,
woher das Fälligkeitsdatum kommt. Die neun Sätze fehlen im String-Katalog vollständig — auf einem
deutschen Gerät fällt die Anzeige auf den englischen Schlüssel zurück. Aufgabe: die neun Sätze auf
Deutsch hinterlegen und beweisen, dass ein deutsches Gerät den deutschen Satz zeigt.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/DueDateRule.swift` | Definiert die neun Sätze in `reason(for:)` über `String(localized:)` — die zu übersetzenden Schlüssel, wörtlich |
| `LooseEnds/Resources/Localizable.xcstrings` | String-Katalog, `sourceLanguage: en`, aktuell 125 Schlüssel, `de` vollständig für alle vorhandenen Einträge — die neun Schlüssel fehlen komplett |
| `Shared/Enrichment/EnrichmentDraft.swift` | `Guess<Value>.reason: String` — der Rohsatz, den `DueDateRule.match` erzeugt |
| `Shared/Enrichment/EnrichmentWriter.swift` | Übernimmt `reason` unverändert in die `Revision` (`record(.dueDate, …, reason: due.reason)`) |
| `Shared/Models/Revision.swift` | `var reason: String?` — der Anzeigetext landet hier |
| `LooseEnds/Views/TaskDetailView.swift:183-184` | Zeigt `revision.reason` als `Text(reason)` im Aufgaben-Detail |
| `LooseEnds/Views/FieldEditorView.swift:32-33` | Zeigt denselben Text im Feld-Editor |
| `LooseEndsTests/DueDateRuleTests.swift` | Bestehende Tests prüfen nur `!reason.isEmpty` und dass sich die neun Sätze paarweise unterscheiden — keiner prüft den Wortlaut oder die Sprache |

## Existing Patterns
- **Lokalisierung generell:** `SWIFT_EMIT_LOC_STRINGS: true` und `LOCALIZATION_PREFERS_STRING_CATALOGS: true`
  (project.yml) — `String(localized:)`-Aufrufe werden beim Build automatisch in den Katalog
  extrahiert, wenn er neu erzeugt wird. Bereits vorhandene Einträge wie `"From due date"` →
  „Ab Fälligkeit" oder `"From completion"` → „Ab Erledigung" sind der Formulierungsstil, an dem
  sich die neun neuen Sätze orientieren sollten (kurz, sachlich, kein Punkt-Redundanz).
- **Sprache erzwingen ohne Geräteeinstellung:** Kein bestehender Test schaltet die App-Sprache um.
  Zwei bekannte, unabhängige Wege für #98:
  - Unit-Test: `Bundle(path: Bundle.main.path(forResource: "de", ofType: "lproj")!)!.localizedString(forKey:value:table:)`
    liest die deutsche Übersetzung direkt aus dem gebauten Bundle, unabhängig von der
    Simulator-/Geräte-Systemsprache. Trifft die eigentliche DoD-Frage ("steht die deutsche
    Übersetzung im gebauten Katalog") ohne Produktcode anzufassen.
  - UI-Test: `app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]` beim
    Start von `XCUIApplication` erzwingt die App-Sprache für den Testlauf — Standardmuster für
    XCUITest, unabhängig von der Simulator-Grundeinstellung.
- **UI-Test-Infrastruktur:** `CaptureSmokeTests.swift` zeigt das Muster — `--ui-testing`-Flag für
  In-Memory-Store, `continueAfterFailure = false`, Element-Zugriff über Accessibility-Identifier,
  `waitForExistence`/`XCTNSPredicateExpectation` für asynchrones Enrichment.
- **Regelpfad läuft immer:** `EnrichmentCoordinator.processPending()` führt `DueDateRule` unabhängig
  vom Modell aus — ein `unavailableReason` (Simulator ohne Apple Intelligence) stoppt nur den
  Modellschritt, nicht die Regel (#95, AC-7). Ein UI-Test kann also einen Text mit Datumsausdruck
  erfassen und sich auf einen regelbasierten Fälligkeits-Grund verlassen, ohne das Modell zu
  brauchen.

## Dependencies
- **Upstream:** `DateExpression` (in `DateExpressionParser`) — die neun Fälle (`offsetDays`,
  `weekday`, `weekdayNextWeek`, `weekdayEitherNext`, `endOfMonth`, `dayOfMonth`, `weekend`,
  `monthRange`, `dayAndMonth`) legen die Anzahl und Bedeutung der Sätze fest. Diese Aufgabe ändert
  die Fallliste nicht, nur die Übersetzung der neun vorhandenen Strings.
- **Downstream:** `TaskDetailView`, `FieldEditorView` zeigen den Text unverändert an; kein weiterer
  Konsument bekannt.

## Existing Specs
- `docs/specs/enrichment/feat-95-parser-in-app.md` — Spec zu #95, in der `DueDateRule` und die
  neun Ausdrucksarten entstanden sind; keine Aussage zur Lokalisierung der Begründungstexte.

## Risks & Considerations
- **Katalog wird bei jedem `xcodegen generate` nicht überschrieben** (er ist eine eigene Ressource,
  keine generierte Datei) — die Übersetzungen bleiben nach `generate` erhalten, kein Risiko dort.
- **Neuextraktion kann Anführungszeichen normalisieren:** Die Quelltexte nutzen typografische
  Anführungszeichen (`“…”`), die exakt so im Katalogschlüssel stehen müssen, sonst matcht Xcode
  den Schlüssel nicht und legt einen zweiten, leeren Eintrag an.
- **Scope-Grenze:** Uhr, Widgets und Teilen-Erweiterung bauen `Shared/` mit, sehen den
  Haupt-App-Katalog `LooseEnds/Resources/Localizable.xcstrings` aber nicht — dort bliebe der Text
  englisch, wenn er dort je angezeigt würde. Aktuell zeigt keine dieser Oberflächen `revision.reason`
  an; wird das relevant, ist es ein eigenes Ticket, kein Teil von #98.
- **Kein bestehender Sprach-Umschalt-Mechanismus** in Unit- oder UI-Tests — beide Testarten müssen
  für #98 neu eingeführt werden (siehe Existing Patterns oben), das ist die eigentliche Arbeit,
  nicht das Eintragen der neun Übersetzungen selbst.

## Analysis

### Type
Feature (kleine Lokalisierungsergänzung, kein Bug — die englischen Sätze funktionieren korrekt,
es fehlt nur die deutsche Übersetzung im Katalog)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|--------------|
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Neun `de`-Übersetzungen ergänzen, Keys wörtlich aus `DueDateRule.swift` kopiert (nicht neu getippt) |
| `LooseEndsTests/DueDateRuleTests.swift` | MODIFY | Neuer Test: alle neun Reason-Keys haben im gehosteten `de.lproj`-Bundle eine Übersetzung, die vom Key selbst abweicht (RED vor der Katalog-Ergänzung) |

Kein Produktcode ändert sich — `DueDateRule.swift`, `EnrichmentDraft.swift`, `EnrichmentWriter.swift`,
`Revision.swift`, `TaskDetailView.swift`, `FieldEditorView.swift` bleiben unangetastet.

### Scope Assessment
- Files: 2
- Estimated LoC: +~120/-0 (davon ~80 reine JSON-Katalogdaten, ~40 Testcode)
- Risk Level: NIEDRIG — reine Übersetzungsdaten, keine Logikänderung, betrifft nur Anzeige

### Technical Approach
Gehosteter Unit-Test genügt als Beweis; kein UI-Test nötig. Begründung: `LooseEndsTests` läuft mit
`TEST_HOST` gegen `LooseEnds.app` (project.yml:195-210), `Bundle.main` im Testprozess ist damit der
App-Bundle. `Bundle.main.path(forResource: "de", ofType: "lproj")` liefert das kompilierte
Katalog-Bundle, `localizedString(forKey:value:table:)` mit den neun Original-Schlüsseln aus
`DueDateRule.swift` prüft exakt den Laufzeit-Mechanismus, deterministisch, ohne Async-Timing. Ein
zusätzlicher UI-Test (Sprache erzwingen, Task erfassen, Enrichment abwarten, Text lesen) würde
denselben Bundle-Lookup nur über eine deutlich fragilere Kette (Async-Timing der Enrichment-Pipeline,
Datumsausdruck-Erkennung, UI-Rendering) erneut zeigen — kaum zusätzliche Beweiskraft, deutlich mehr
Flakiness-Risiko. Projekt-Regel deckt das: UI-Tests erst nach Design-Freeze und nur als Smoke-Test;
dieses Ticket ist reine Content-Ergänzung, kein UI-Verhalten.

**TDD RED:** Test zuerst schreiben (erwartet für jeden der neun Keys eine deutsche Übersetzung, die
vom Key abweicht) → schlägt fehl, da der Katalog noch keine `de`-Einträge für diese Keys hat und
`localizedString` auf den Key selbst zurückfällt. Danach die neun Katalog-Einträge ergänzen → GREEN.

**Übersetzungsentwurf** (Stil an bestehenden Katalog-Einträgen orientiert — kurz, sachlich, kein
Redundanz-Punkt; deutsche Anführungszeichen „…" in der Übersetzung, die englischen Schlüssel
selbst bleiben mit “…” unverändert):

| Case | Englischer Schlüssel (Katalog-Key, unverändert) | Deutsche Übersetzung |
|------|--------------------------------------------------|------------------------|
| offsetDays | From a day count in the note. | Aus einer Tagesangabe in der Notiz. |
| weekday | From the weekday named in the note. | Aus dem Wochentag in der Notiz. |
| weekdayNextWeek | From a weekday of next week in the note. | Aus einem Wochentag der nächsten Woche in der Notiz. |
| weekdayEitherNext | From “next” plus a weekday in the note: the following week. | Aus „nächsten" plus Wochentag in der Notiz: die Folgewoche. |
| endOfMonth | From “end of the month” in the note. | Aus „Ende des Monats" in der Notiz. |
| dayOfMonth | From the day of the month in the note. | Aus dem Tag des Monats in der Notiz. |
| weekend | From “weekend” in the note: Saturday. | Aus „Wochenende" in der Notiz: Samstag. |
| monthRange | From “next month” in the note: the first of that month. | Aus „nächsten Monat" in der Notiz: der Erste des Monats. |
| dayAndMonth | From the day and month in the note. | Aus Tag und Monat in der Notiz. |

### Dependencies
- **Upstream:** `DateExpression`-Fälle (unverändert, #92/#95) legen Anzahl und Bedeutung der neun
  Sätze fest.
- **Downstream:** keine — `TaskDetailView`/`FieldEditorView` zeigen `revision.reason` unverändert an.
- **Reihenfolge:** kein Blocker, keine Abhängigkeit zu anderen offenen Issues.

### Risks (verifiziert, mit Gegenmaßnahme)
- **Anführungszeichen-Mismatch:** Die drei Keys mit “…” (weekdayEitherNext, endOfMonth, weekend,
  monthRange) müssen im Katalog byte-exakt wie im Swift-Quelltext stehen, sonst legt Xcode bei der
  nächsten Neu-Extraktion einen zweiten, leeren Eintrag an und die Übersetzung „verschwindet"
  unbemerkt. Gegenmaßnahme: Keys direkt aus `DueDateRule.swift` kopieren, nicht neu tippen.
  Der Unit-Test aus TDD RED deckt eine falsche Kopie sofort auf (Testkeys stammen aus derselben
  Quelle wie die Katalog-Keys).
- **`.xcstrings` ist generiertes JSON mit Xcode-eigener Formatierung:** manuelles Editieren kann
  Diff-Rauschen erzeugen; nach dem Speichern in Xcode oder per Skript die JSON-Validität prüfen
  (`python3 -m json.tool` reicht).
- **`extractionState` je neuem Eintrag auf `translated` setzen** (wie bei bestehenden Einträgen),
  sonst markiert Xcode sie als „needs review" trotz vorhandener Übersetzung.

### Alternative (geprüft, nicht empfohlen)
`reason(for:)` liefert statt eines fertigen Satzes einen strukturierten Fall (Enum), die View baut
den Satz lokal per `switch` + `String(localized:)`. Würde die bestehende Festlegung aus #95 kippen
("eine Funktion liefert den fertigen, bereits lokalisierten Satz") und Produktcode in `DueDateRule`,
`EnrichmentDraft`, `EnrichmentWriter`, `TaskDetailView` und `FieldEditorView` anfassen — für eine
reine Übersetzungslücke unverhältnismäßig. Nicht empfohlen; als Alternative hier festgehalten, falls
künftig weitere Sprachen oder dynamische Satzbausteine (z. B. das konkrete Datum im Satz) gebraucht
werden — dann würde sich die Abwägung ändern.

### Open Questions
Keine — Henning entscheidet nichts Produktseitiges hier, technischer Ansatz ist eindeutig.
