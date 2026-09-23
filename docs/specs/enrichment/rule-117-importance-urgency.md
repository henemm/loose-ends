---
entity_id: rule-117-importance-urgency
type: feature
created: 2026-09-23
updated: 2026-09-23
status: draft
workflow: rule-117-importance-urgency
---

# Spec: #117 — Wichtigkeit und Dringlichkeit regelbasiert (Teil von #112, Alternative 1)

## Approval

- [ ] Approved

## Purpose

`importance` und `urgency` kommen bisher vom On-Device-Modell (`FoundationModelsEnricher`,
Konfidenzschwelle 0.6). Issue #111 hat gezeigt: Die FocusBlox-„Wahrheit", mit der diese Felder
bisher verglichen wurden, war selbst nie ein echtes Urteil, sondern zu 43 %/74 % nur ein
Fallback-Standardwert — ein Datenproblem, kein Modellproblem, aber Grund genug, den Feldern eine
verlässlichere Quelle zu geben. Henning hat entschieden (#112, Alternative 1): Beide Felder werden
künftig ausschließlich über Textmuster/Schlüsselwörter bestimmt, kein Modellaufruf mehr dafür — nach
demselben Muster, mit dem #95 bereits das Fälligkeitsdatum vom Modell auf `DueDateRule` umgestellt
hat, und passend zur Projektregel „Regeln vor Modell" (CLAUDE.md, Henning 2026-09-20).

## Source

- **Datei:** `Shared/Enrichment/ImportanceUrgencyRule.swift` (neu)
- **Bezeichner:** `enum ImportanceUrgencyRule`, `static func matchImportance(in:)`, `static func matchUrgency(in:)`
- **Datei:** `Shared/Enrichment/EnrichmentCoordinator.swift`
- **Bezeichner:** `private func applyRules(to:)`

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `Shared/Enrichment/DueDateRule.swift` (#95) | Vorbild | Exakt dasselbe Muster (reiner Baustein, Guess-Tripel, Konfidenz 1.0, Coordinator-Guard vor Modellaufruf), bereits gebaut und bewährt |
| `EnrichmentDraft.Guess<T>` | Typ | Rückgabetyp der beiden Match-Funktionen, unverändert |
| `Shared/Models/Enums.swift` (`Importance`, `Urgency`) | Enum | Rohwerte `low`/`medium`/`high`; die Regel setzt ausschließlich `.high`, siehe Implementation Details |
| `Revision`, `RevisedField` (`.importance`, `.urgency` existieren bereits) | Typen | Für die direkte Task-Schreibung analog `dueDate`, kein neuer Enum-Fall nötig |
| `FieldSource` (`.ai`) | Enum | Feldursprung bleibt `ai`, wie in #95 für `dueDate` entschieden (2026-09-21) — kein neuer „Regel"-Wert |
| `ViewRules.byUrgencyThenImportance` | Downstream | Nutzt nur die Enum-Werte, nicht die Konfidenz — bleibt unverändert lauffähig |
| `FieldCodec.swift`, `RevisionService.swift` | Downstream | Feldquellen-unabhängig — keine Änderung nötig |
| `TaskDetailView.swift`, `FieldEditorView.swift` | Downstream | Zeigen `revision.reason` bereits heute an — der Regelsatz durchläuft denselben, ungeänderten Anzeigepfad |
| `#118` (Folge-Issue) | Issue | Bereinigung von `FocusBloxCalibrationTests`/`SelfConsistencyReportTests`, die nach diesem Umbau für importance/urgency ins Leere liefen — bewusst nicht Teil dieser Spec |

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `Shared/Enrichment/ImportanceUrgencyRule.swift` | CREATE | `matchImportance(in:)` und `matchUrgency(in:)`, Schlüsselwortkategorien DE/EN, Konfidenz 1.0, `nil` bei Nichttreffer |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | `applyRules(to:)` um zwei Guard-Blöcke erweitert (`guard task.importance == nil`, `guard task.urgency == nil`), analog `dueDate` |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | MODIFY | `ModelEnrichment` verliert die sechs importance/urgency-Eigenschaften (`importance`, `importanceConfidence`, `importanceReason`, `urgency`, `urgencyConfidence`, `urgencyReason`); `instructions` verliert den Signalsatz (Z. 28); `prompt(for:)` verliert die zwei Zeilen, die Beispiel-Aufgaben mit `importance`/`urgency` beschriften (Z. 47–48); `draft(from:capturedAt:calendar:)` verliert das Mapping (Z. 67–72) |
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | Die zwei Schwellenwert-Schreibblöcke für `importance`/`urgency` (Z. 47–59) entfernt — nach dem Umbau nie mehr erreicht, weil `EnrichmentDraft.importance`/`.urgency` vom Modell-Adapter nicht mehr befüllt werden |
| `LooseEndsTests/ImportanceUrgencyRuleTests.swift` | CREATE | Beispiel-Tests analog `LooseEndsTests/DueDateRuleTests.swift`: Konfidenz 1.0, Treffer je Schlüsselwortkategorie, `nil` bei fehlendem Signal, Unabhängigkeit der Felder, Übersetzungsprüfung |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Fünf neue Begründungssätze von Anfang an DE+EN (anders als #98, das nachträglich übersetzt hat) |

**Geschätzter Umfang:** 4 Produktionsdateien + 1 Lokalisierungsdatei + 1 Testdatei, ca. 130–190 LoC
Produktivcode (unter der 250-LoC-Grenze) und ca. 150–250 LoC Testcode. Sechs Dateien liegen einen
über der 4–5-Richtgröße aus CLAUDE.md; die Lokalisierungsdatei ist dabei eine reine Werteliste ohne
eigene Logik, kein sechster inhaltlicher Änderungsort — trotzdem hier transparent benannt statt
stillschweigend übergangen.

## Implementation Details

**Zwei unabhängige Funktionen, kein kombiniertes Tripel.** Anders als bei Datum/Uhrzeit (#95, ein
`Date`-Wert aus zwei Teilausdrücken) sind Wichtigkeit und Dringlichkeit laut Datenmodell und
`ViewRules.byUrgencyThenImportance` orthogonale Felder — „dringend, aber unwichtig" ist valide.
`ImportanceUrgencyRule` liefert deshalb zwei getrennte Guess-Werte:

```
enum ImportanceUrgencyRule {
    static let confidence = 1.0
    static func matchImportance(in text: String) -> EnrichmentDraft.Guess<Importance>?
    static func matchUrgency(in text: String) -> EnrichmentDraft.Guess<Urgency>?
}
```

Beide Funktionen nehmen **keinen Referenzzeitpunkt** entgegen — anders als `DueDateRule.match(in:reference:calendar:)`.
Das ist mit Absicht die strukturelle Garantie für „Alter der Notiz ist kein Wichtigkeits-Signal"
(wörtlich aus dem bisherigen Modell-Prompt, `FoundationModelsEnricher.swift:29`): eine Funktion ohne
Datumsparameter kann `capturedAt` gar nicht auswerten, kein Aufrufer kann es versehentlich
hineinreichen.

**Nur `.high`, nie `.medium` oder `.low`.** Die Schlüsselwortkategorien (unten) erkennen positive
Signale für „das hier ist wichtig" bzw. „das hier eilt". Für „mittel" oder „niedrig" gibt es keinen
zuverlässigen Textmarker — ihr Fehlen zu unterstellen wäre genau der Fallback-Standardwert, den #111
als Problem der alten FocusBlox-„Wahrheit" identifiziert hat. Kein Treffer heißt `nil`, nicht
„.low" oder „.medium".

**Schlüsselwortkategorien (DE/EN), je mit eigenem lokalisierten Grundsatz** — Fundstelle: heutiger
Modell-Prompt, `FoundationModelsEnricher.swift:28`. Groß-/Kleinschreibung wird ignoriert, Treffer an
Wortgrenzen (kein Teilstring-Treffer mitten in einem anderen Wort):

*Wichtigkeit (`matchImportance`), jeweils → `.high`:*
- **money** — Geldbeträge/Zahlungsbezug: „Euro", „€", „Rechnung", „Kredit", „Gehalt", „invoice",
  „amount" … → „From an amount of money in the note."
- **official** — Amts-/Rechtssprache: „Finanzamt", „Amt", „Behörde", „Gericht", „Anwalt", „Vertrag",
  „Steuer", „tax", „official", „contract", „court" … → „From official or legal language in the note."
- **peopleWaiting** — jemand wartet darauf: „wartet auf", „erwartet eine Antwort", „is waiting for",
  „is expecting" … → „From someone waiting for this in the note."

*Dringlichkeit (`matchUrgency`), jeweils → `.high`:*
- **immediacy** — unmittelbarer Zeitdruck: „dringend", „sofort", „jetzt", „umgehend", „urgent",
  „immediately", „asap" … → „From an urgency word in the note."
- **deadline** — Fristbezug: „Frist", „Stichtag", „spätestens", „Mahnung", „Kündigungsfrist",
  „deadline", „reminder", „cancellation" … → „From a deadline reference in the note."

Trifft ein Text auf mehrere Kategorien desselben Feldes zu, bleibt der Rückgabewert `.high` (es gibt
keinen höheren Wert), der Grundsatz folgt einer festen Priorität (`money` vor `official` vor
`peopleWaiting`; `deadline` vor `immediacy`) — deterministisch, nicht zufällig, damit derselbe Text
bei jedem Lauf denselben Grund liefert.

**Der Coordinator-Guard läuft wie bei `dueDate`, aber für beide Felder getrennt.** `applyRules(to:)`
bekommt zwei weitere, unabhängige Guard-Blöcke nach demselben Muster wie der bestehende für
`dueDate` (`EnrichmentCoordinator.swift:83-100`): `guard task.importance == nil` bzw.
`guard task.urgency == nil`, dann `ImportanceUrgencyRule.matchImportance`/`matchUrgency`, bei Treffer
eine `Revision(field: .importance, …, author: .ai)` bzw. `.urgency` und die direkte Task-Schreibung
(`task.importance`, `task.importanceSourceRaw = FieldSource.ai.rawValue`, `task.importanceConfidence`,
analog für Dringlichkeit) — ohne `processedAt` zu berühren, aus demselben Grund wie beim Datum: das
Feld bleibt sonst auf einem Gerät ohne Apple Intelligence für immer offen für Titel & Co. Der Guard
gegen das leere Feld verhindert eine zweite Revision beim Nachhol-Lauf, sobald das Modell verfügbar
ist.

**Modellschema schrumpft.** `ModelEnrichment` verliert die sechs importance/urgency-Eigenschaften,
`instructions` den Signalsatz, `prompt(for:)` die zwei Zeilen, die vergangene Beispielaufgaben mit
`importance`/`urgency` beschriften — das Modell bekommt diese Information nicht mehr, weil es sie
nicht mehr vorhersagt. `draft(from:capturedAt:calendar:)` verliert das zugehörige Mapping.
`EnrichmentWriter` verliert die beiden jetzt nie mehr erreichten Schreibblöcke für `importance`/`urgency`
(Aufrufer liefert für diese Felder ab jetzt strukturell immer `nil` im `EnrichmentDraft`).

**Feldursprung bleibt `ai`** (Fortführung der PO-Entscheidung aus #95, 2026-09-21, nicht neu
verhandelt): Die Regel schreibt über denselben Pfad wie bisher der Modellwert
(`task.importanceSourceRaw = "ai"`, `task.importanceConfidence`, eine `Revision` mit `author: .ai`).

## Test Plan

### Automated Tests (TDD RED)

**Neu**
- `LooseEndsTests/ImportanceUrgencyRuleTests.swift`: GIVEN „250 Euro an den Verein überweisen" /
  WHEN `matchImportance(in:)` / THEN `.high`, Konfidenz 1.0, nicht-leerer Grundsatz (AC-1, money).
- Dieselbe Datei: GIVEN „Die Steuererklärung fürs Finanzamt abgeben" / WHEN `matchImportance(in:)` /
  THEN `.high`, anderer Grundsatz als beim money-Fall (AC-1, official).
- Dieselbe Datei: GIVEN „Er wartet auf meine Antwort" / WHEN `matchImportance(in:)` / THEN `.high`,
  dritter, wieder anderer Grundsatz (AC-1, peopleWaiting).
- Dieselbe Datei: GIVEN „Dringend das Formular ausfüllen" / WHEN `matchUrgency(in:)` / THEN `.high`,
  Konfidenz 1.0, nicht-leerer Grundsatz (AC-2, immediacy).
- Dieselbe Datei: GIVEN „Die Frist läuft morgen ab" / WHEN `matchUrgency(in:)` / THEN `.high`,
  anderer Grundsatz als beim immediacy-Fall (AC-2, deadline).
- Dieselbe Datei: GIVEN „Blumen gießen" (keine der fünf Kategorien trifft) / WHEN beide
  Match-Funktionen laufen / THEN beide liefern `nil`, nicht `.low` oder `.medium` (AC-3).
- Dieselbe Datei: GIVEN „Sofort zurückrufen" (nur immediacy) / WHEN beide Match-Funktionen laufen /
  THEN `matchUrgency` liefert `.high`, `matchImportance` liefert `nil` — und umgekehrt mit „250 Euro
  an den Verein überweisen" (nur money): `matchImportance` liefert `.high`, `matchUrgency` liefert
  `nil` (AC-4).
- Dieselbe Datei: GIVEN derselbe Text mit zwei sehr weit auseinanderliegenden Zeitstempeln als
  `capturedAt` an `EnrichmentCoordinator` übergeben (Reflexions-/Integrationstest, weil die
  Match-Funktionen selbst keinen Datumsparameter besitzen) / WHEN `applyRules` je einmal läuft / THEN
  identisches Ergebnis für `importance`/`urgency` in beiden Fällen (AC-5).
- `LooseEndsTests/EnrichmentTests.swift`, neue Fälle in `EnrichmentCoordinatorTests`: GIVEN eine
  Aufgabe, deren `importance` bereits gesetzt ist (Regel oder vorheriger Lauf) / WHEN `applyRules`
  erneut läuft / THEN keine zweite `.importance`-Revision, Wert unverändert — derselbe Test separat
  für `urgency` (AC-6).
- `LooseEndsTests/EnrichmentTests.swift` oder neue Datei: GIVEN `ModelEnrichment` nach dem
  Schemaschrumpf / WHEN der Typ per Reflection/Compile-Check geprüft wird / THEN existieren
  `importance`, `importanceConfidence`, `importanceReason`, `urgency`, `urgencyConfidence`,
  `urgencyReason` nicht mehr als Eigenschaften (AC-7).
- `LooseEndsTests/ImportanceUrgencyRuleTests.swift`, Test analog `DueDateRuleTests.reasonsAreTranslatedToGerman()`:
  GIVEN die fünf neuen Begründungssätze / WHEN im gebauten `de.lproj`-Bundle nachgeschlagen / THEN
  jeder Satz hat eine deutsche Übersetzung, keiner fällt auf den englischen Schlüsseltext zurück
  (AC-8).

**Geändert**
- `LooseEndsTests/EnrichmentWriterTests.swift` (falls dort `importance`/`urgency`-Fälle über die
  Schwelle testen): Fälle, die ausschließlich den jetzt entfernten Schreibpfad für `importance`/`urgency`
  prüfen, entfallen kontrolliert; alle übrigen `EnrichmentWriterTests`-Fälle (Titel, Datum, Dauer,
  Energie, Kontexte, Personen, Projekt) bleiben unverändert.

**Entfallend**
- Jeder bestehende Test, der `ModelEnrichment` mit importance/urgency-Werten von Hand aufbaut oder
  einen `StubEnricher`-Draft mit `importance`/`urgency` erwartet, dass `EnrichmentWriter` diese ab
  Schwelle 0.6 schreibt — der Aufrufer liefert diese Werte im Produktpfad nicht mehr.

Kein neuer UI-Test: Es entsteht keine neue View und kein neues UI-Element. `TaskDetailView.swift` und
`FieldEditorView.swift` zeigen `revision.reason` bereits heute an — der Regelsatz durchläuft denselben,
ungeänderten Anzeigepfad. Das Projekt schreibt UI-Tests erst nach dem Design-Freeze und nur als
Smoke-Tests (CLAUDE.md).

## Acceptance Criteria

- **AC-1 Wichtigkeits-Treffer je Kategorie:** Given je ein Satz mit einem money-, official- oder
  peopleWaiting-Signal (z. B. „250 Euro an den Verein überweisen", „Die Steuererklärung fürs
  Finanzamt abgeben", „Er wartet auf meine Antwort") / When `ImportanceUrgencyRule.matchImportance(in:)`
  ihn verarbeitet / Then liefert er `.high` mit Konfidenz 1.0 und einem nicht-leeren, je Kategorie
  unterschiedlichen Grundsatz.
- **AC-2 Dringlichkeits-Treffer je Kategorie:** Given je ein Satz mit einem immediacy- oder
  deadline-Signal (z. B. „Dringend das Formular ausfüllen", „Die Frist läuft morgen ab") / When
  `ImportanceUrgencyRule.matchUrgency(in:)` ihn verarbeitet / Then liefert er `.high` mit Konfidenz
  1.0 und einem nicht-leeren, je Kategorie unterschiedlichen Grundsatz.
- **AC-3 Kein Treffer bleibt `nil`, kein Default:** Given ein Satz ohne jede der fünf Kategorien
  (z. B. „Blumen gießen") / When beide Match-Funktionen ihn verarbeiten / Then liefern beide `nil` —
  nicht `.low` und nicht `.medium`.
- **AC-4 Wichtigkeit und Dringlichkeit sind unabhängig:** Given ein Satz mit nur einem
  Dringlichkeits-Signal ohne Wichtigkeits-Signal (z. B. „Sofort zurückrufen") sowie ein Satz mit nur
  einem Wichtigkeits-Signal ohne Dringlichkeits-Signal (z. B. „250 Euro an den Verein überweisen") /
  When beide Match-Funktionen auf beide Sätze laufen / Then liefert jeweils nur die passende Funktion
  `.high`, die andere `nil` — kein Feld wird aus dem Treffer des anderen abgeleitet.
- **AC-5 Alter der Notiz ist kein Signal:** Given die Signaturen `matchImportance(in text: String)`
  und `matchUrgency(in text: String)` ohne Datums-/Referenzzeit-Parameter / When derselbe Text über
  `EnrichmentCoordinator.applyRules(to:)` mit zwei stark unterschiedlichen `capturedAt`-Zeitpunkten
  verarbeitet wird / Then ist das Ergebnis für `importance` und `urgency` in beiden Fällen identisch.
- **AC-6 Guard gegen Doppel-Revision, getrennt je Feld:** Given eine Aufgabe, deren `importance`
  bereits gesetzt ist / When `applyRules(to:)` erneut läuft / Then entsteht keine zweite
  `.importance`-Revision und der Wert bleibt unverändert — derselbe Nachweis separat für `urgency`.
- **AC-7 Modellschema verliert die sechs Eigenschaften:** Given der Schemaschrumpf in
  `ModelEnrichment` / When `./scripts/sim.sh unit` läuft / Then existieren `importance`,
  `importanceConfidence`, `importanceReason`, `urgency`, `urgencyConfidence`, `urgencyReason` nicht
  mehr als Eigenschaften von `ModelEnrichment`, die zugehörigen Zeilen in `instructions` und
  `prompt(for:)` sind entfernt, und `EnrichmentWriter` schreibt `importance`/`urgency` nicht mehr über
  einen Modell-Draft.
- **AC-8 Lokalisierung von Anfang an:** Given die fünf neuen Begründungssätze in
  `Localizable.xcstrings` / When im gebauten `de.lproj`-Bundle nachgeschlagen wird (wie
  `DueDateRuleTests.reasonsAreTranslatedToGerman()`) / Then hat jeder der fünf Sätze eine deutsche
  Übersetzung, keiner fällt auf den englischen Schlüsseltext zurück.

## Risiken

1. **Schlüsselwortlisten sind unvollständig, echte Signale werden verpasst.** Gegenmaßnahme: Der
   Ausfall ist `nil`, nicht ein falscher Wert — genau die Eigenschaft, die #111 an der alten Lösung
   fehlte. Ohne belastbare externe Wahrheit (#111) lässt sich eine Trefferquote nicht sauber messen;
   beobachtete Lücken werden als eigene, kleine Folge-Issues nachgezogen, statt die Liste jetzt
   spekulativ zu vergrößern.
2. **Schlüsselwörter treffen in unpassendem Kontext (falsch positiv), z. B. „Konto" in einem Satz
   ohne Geldbezug.** Gegenmaßnahme: wortgrenzenbasiertes, aber weiterhin kontextfreies Matching wie
   bei `DateExpressionParser`; dieselbe epistemische Lage wie beim Modell, das ebenfalls keine
   verlässliche externe Wahrheit für diese Felder hatte (#111) — kein Rückschritt gegenüber dem
   Status quo.
3. **Begründungssätze fehlen im deutschen Katalog wie bei #98.** Gegenmaßnahme (AC-8): Übersetzung
   ist Teil dieser Spec von Anfang an, nicht nachgezogen wie bei #98.
4. **Schemaschrumpf bricht bestehende Tests, die `ModelEnrichment` mit importance/urgency-Werten von
   Hand aufbauen.** Gegenmaßnahme (AC-7): kontrollierte Anpassung als Teil dieses Tickets, belegt
   durch grünes `./scripts/sim.sh unit`.
5. **`FocusBloxCalibrationTests`/`SelfConsistencyReportTests` messen nach diesem Umbau ein Feld, das
   jetzt die Regel statt das Modell setzt.** Bewusst nicht Teil dieser Spec (anderer Dateibereich,
   `FocusBloxCalibrationTests` ist zudem gated und läuft nie in CI); als #118 vorgemerkt.

## Alternativen

- **Kombiniertes Guess-Tripel wie bei `DueDateRule`** (ein Aufruf liefert beide Felder zusammen):
  verworfen. Wichtigkeit und Dringlichkeit sind laut Datenmodell und
  `ViewRules.byUrgencyThenImportance` orthogonale Felder — ein kombinierter Rückgabewert würde eine
  Kopplung suggerieren, die es im Produkt nicht gibt („dringend, aber unwichtig" ist valide). Kippt
  keine bestehende Entscheidung, ist eine reine Konsistenzfrage zu #95.
- **Bei fehlendem Signal `.low` statt `nil` setzen:** würde jeder Aufgabe sofort einen sortierbaren
  Wert geben (praktisch für `ViewRules.byUrgencyThenImportance`, das heute `nil` ans Ende sortiert)
  und den entsprechenden Downstream-Code vereinfachen. Verworfen, weil das exakt der
  Fallback-Standardwert wäre, den #111 als Ursache der irreführenden FocusBlox-„Wahrheit"
  identifiziert hat. Würde die PO-Entscheidung aus #112 („kein Default-Wert") kippen — nur infrage,
  falls Henning diese Entscheidung ausdrücklich revidiert.
- **Modellbasiert bleiben, nur die Konfidenzschwelle erhöhen** (z. B. auf 0.9 statt 0.6): verworfen.
  #111 hat gezeigt, dass die Vergleichsbasis selbst unzuverlässig war — eine höhere Schwelle löst das
  Datenproblem nicht, sie verschiebt nur, wie oft `nil` statt eines (weiterhin ungeprüften)
  Modellwerts herauskommt. Würde Hennings eigene Entscheidung aus #112 (Alternative 1: regelbasiert)
  kippen; dort bereits abgewogen und verworfen.
- **Eigener wiederverwendbarer Baustein für Schlüsselwort-Matching** (analog
  `DateExpressionParser`/`TimeExpressionParser` als eigenständiges Modul mit eigener Messung):
  architektonisch sauberer, falls ein drittes Feld denselben Mechanismus braucht. Heute unbegründet —
  ein zweiter Aufrufer existiert nicht. Wird nachgeholt, sobald ein zweites Feld denselben Bedarf
  zeigt (derselbe Grundsatz wie beim `RuleFirstEnricher`-Dekorator in #95).

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt, belegt durch die im Test Plan genannten Tests
- [ ] `./scripts/sim.sh unit` grün nach Regelschritt, Coordinator-Umbau und Schemaschrumpf
- [ ] Build erfolgreich (`./scripts/sim.sh build` ohne Errors), jeder Commit kompiliert
- [ ] Drei Abnahmestufen durchlaufen: Tests → Simulator → Hennings iPhone 16 Pro
      (`./scripts/sim.sh device`) — kein Schritt entfällt, TestFlight ist kein Ersatz dafür
- [ ] Nach dem Zusammenführen: Hennings Hauptordner nachgezogen und Projekt neu erzeugt
      (`bash ~/.claude/scripts/loose-ends-sync-main.sh`)
- [ ] PR schließt #117 (`Closes #117`)
- [ ] Kein manueller Testhinweis an Henning — jede Acceptance Criterion ist automatisiert bewiesen
- [ ] CI grün
- [ ] #118 (Bereinigung `FocusBloxCalibrationTests`/`SelfConsistencyReportTests`) bleibt offen und
      referenziert diese Spec als Auslöser

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Die Änderung bewegt sich innerhalb bestehender Architektur-Entscheidungen
  (ADR-3 Rohtext unveränderlich/abgeleitete Felder mit Herkunft und Konfidenz; ADR-4 Veredelung genau
  einmal pro Aufgabe; ADR-6 Revisionen statt Undo; ADR-11 Tests mit Fake-Modell über das
  `TaskEnricher`-Protokoll) und führt keinen neuen Architekturbaustein ein, der eine eigene Nummer
  rechtfertigt — `ImportanceUrgencyRule` ist ein weiterer reiner Baustein neben `DueDateRule` und
  `EnrichmentWriter`, keine neue Schicht. Die zugrunde liegende Produktentscheidung „Regeln vor
  Modell" ist bereits als projektweite Arbeitsregel in `CLAUDE.md` geführt, nicht als Einzel-ADR
  (dieselbe Begründung wie in `docs/specs/enrichment/feat-95-parser-in-app.md`). Diese Spec setzt die
  Regel für Wichtigkeit und Dringlichkeit um, wie #95 sie für das Fälligkeitsdatum umgesetzt hat.

## Changelog

- 2026-09-23: Spec aus der Analyse-Zusammenfassung (Phase 2, #117, Teil-Umsetzung von #112,
  Alternative 1) erstellt.
