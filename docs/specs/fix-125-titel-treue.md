---
entity_id: fix-125-titel-treue
type: bugfix
created: 2026-09-25
updated: 2026-09-25
status: draft
workflow: fix-125-titel-treue
---

# Spec: Bug #125 — Titel lässt sich nicht zurücksetzen und verschluckt Inhalte

## Approval

- [ ] Approved

## Purpose

Issue #125 hat zwei unabhängige Teilpunkte am KI-gesetzten Aufgabentitel: (1) ein von der KI
gesetzter Titel lässt sich nicht in einem Klick auf den Vor-KI-Wert zurücksetzen, sondern nur über
den Umweg `Show` → `RevisionsSheet`; (2) die KI kürzt den Titel auf einen aktiven Satz und lässt
dabei Inhalte ersatzlos wegfallen (Beispiel: „Termin bei Auto Senger machen für Inspektion und
Reifenwechsel" → „Termin bei Auto Senger machen"), statt Zweck/Objekt zu erhalten. Diese Spec
behebt beide Punkte getrennt, in der Reihenfolge Punkt 1 (risikoarm) vor Punkt 2 (mittleres Risiko,
nicht-deterministisch).

## Source

- **File:** `LooseEnds/Views/TaskDetailView.swift`
- **Identifier:** `struct TaskDetailView`, Titel-Section (Zeile 26–36)
- **File:** `Shared/Enrichment/FoundationModelsEnricher.swift`
- **Identifier:** `static let instructions`, `struct ModelEnrichment` / `var title` (`@Guide`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Shared/Services/RevisionService.swift` | module | `firstAIRevision(of:on:)` liefert den Vor-KI-Wert, `revert(_:on:contexts:projects:now:)` schreibt den Reset als Nutzer-Revision — beide bereits vorhanden und getestet, hier nur direkt am Titel-Feld verdrahtet |
| `Shared/Services/RevisionService.swift` | module | `aiSetFields(on:)` bestimmt, ob `.title` aktuell vom KI-Wert stammt (steuert Sichtbarkeit des Reset-Buttons) |
| `Measurement/Corpus.swift` | module | `TitleCheck.preserves/inventedNumbers/alteredNames/foreignWords` — Messgrundlage für Punkt 2, keine Änderung an der Datei selbst |
| `Measurement/date-title-corpus.json` | data | Bestehender Korpus (#67/#92), ggf. um 1–2 Fälle mit Zweck/Objekt-Phrasen ergänzt, bevor Punkt 2 gemessen wird |
| `docs/project/03-design-briefing.md` | doc | ADR „Zeile nie höher als Titel plus eine Merkmalzeile" — bleibt unverändert in Kraft, weil diese Spec keine neue Subheadline einführt (Hennings Entscheidung vom 2026-09-25) |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|--------------|
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | Reset-Icon-Button neben dem Titel-`TextField`, sichtbar nur wenn der Titel aktuell vom KI-Wert stammt; `titleDraft` wird nach dem Reset explizit nachgezogen |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | MODIFY | Prompt (`instructions`) und `@Guide`-Beschreibung von `ModelEnrichment.title` umformuliert: höheres Wortlimit, explizite Pflicht, Zweck/Objekt nicht wegzulassen |
| `Measurement/date-title-corpus.json` | MODIFY | Bei Bedarf 1–2 zusätzliche Fälle mit Zweck/Objekt-Phrasen (z. B. „für Inspektion und Reifenwechsel"), falls diese Art von Fall noch nicht als zu erhaltende Entität abgedeckt ist |
| `LooseEndsTests/RevisionServiceTests.swift` (oder passende bestehende Testdatei zu `RevisionService`) | MODIFY | Neuer Unit-Test: Reset des Titels über `firstAIRevision` + `revert` liefert den Vor-KI-Wert zurück |

### Estimated Changes
- Files: 4
- LoC: +50/-10

## Implementation Details

### Punkt 1 — 1-Klick-Reset für den Titel

In `TaskDetailView.swift` bekommt die Titel-Section neben dem `TextField("Title", text: $titleDraft)`
einen Icon-Button (`arrow.uturn.backward` o. ä., analog zum bestehenden `sparkle`-Icon-Vokabular),
der nur erscheint, wenn `aiFields.contains(.title)` (bestehende Computed Property, Zeile 22) wahr
ist. Der Button ruft:

```swift
if let revision = RevisionService.firstAIRevision(of: .title, on: task) {
    RevisionService.revert(revision, on: task, contexts: contexts, projects: projects)
    titleDraft = task.title ?? ""
}
```

`firstAIRevision(of:on:)` und `revert(_:on:contexts:projects:now:)` existieren bereits in
`RevisionService.swift` (Zeile 21–29, 72–76) und werden aktuell nur aus dem `RevisionsSheet` heraus
aufgerufen — hier direkt am Titel-Feld verdrahtet. Ohne das explizite Nachziehen von `titleDraft`
bliebe im Feld kurzzeitig der alte KI-Wert stehen, weil `titleDraft` bisher nur in `.onAppear`
(Zeile 85) gesetzt wird, nicht bei jeder Änderung von `task.title`.

Kein neues UI-Test-Rahmenwerk: Der Reset-Pfad ist über `RevisionService` bereits Unit-testbar (siehe
Test Plan), ein UI-Test für `resetRevisionButton` existiert für diesen Screen noch nicht und wird
laut CLAUDE.md erst nach Design-Freeze als Smoke-Test ergänzt — nicht Teil dieses Fixes.

### Punkt 2 — Titel darf nichts wortlos verschlucken

Root Cause: Der Informationsverlust entsteht ausschließlich im Prompt
(`FoundationModelsEnricher.swift`, `instructions` Zeile 25–32 und `@Guide`-Beschreibung von `title`
Zeile 88), nicht in Speicherung oder Anzeige — `draft()`-Trimming, `TaskItem.displayTitle` und
`TaskRow.lineLimit(1)` kürzen inhaltlich nichts, nur die Anzeige per iOS-Ellipse. Die Formulierung
„at most eight words" kombiniert mit dem Adjektiv „short" drängt das Modell dazu, Zweck/Objekt
komplett zu streichen statt nur zu straffen (Beispielfall: 9-Wort-Rohtext wurde auf 5 Wörter
gekürzt, nicht auf die erlaubten 8).

Entschiedene Lösung (Alternative a, Henning 2026-09-25): Prompt und `@Guide`-Beschreibung werden
gelockert und präzisiert, in etwa:

> „Imperative title, up to twelve words. Never drop the object or purpose of the task even if that
> means using more words."

Kein Schema-Wechsel (kein neues Feld, kein zweites Titel-Attribut), keine UI-Änderung. Die
verworfene Alternative — eine feste Unterzeile im Detail, die den weggefallenen Teil separat zeigt
— wurde von Henning explizit abgelehnt: der wegfallende Teil landet im Titel selbst, nicht in einem
separaten Element. Der Rohtext bleibt wie bisher unverändert unter dem Titel sichtbar
(`TaskDetailView.swift` Zeile 32–35, unverändert durch diese Spec). Die Liste bleibt einzeilig und
kürzt lange Titel wie bisher per iOS-Ellipse — kein Long-Press, kein Preview, kein zweites
Bedienelement.

„Regeln vor Modell" gilt hier nicht als Gegenargument: Der Titel ist eine Paraphrase des Rohtexts,
kein Teilstring — eine regelbasierte Extraktion von „Kern + Rest" ist nicht sauber möglich, die
Aufgabe bleibt Sprachverständnis und damit legitim beim Modell.

**Messpflicht vor Merge:** Die neue Prompt-Fassung läuft gegen den bestehenden Korpus
(`Measurement/date-title-corpus.json`, ausgewertet über `Measurement/Corpus.swift`,
`enum TitleCheck`: `preserves`, `inventedNumbers`, `alteredNames`, `foreignWords`). Vorab wird
geprüft, ob Zweck/Objekt-Phrasen wie „für Inspektion und Reifenwechsel" im Korpus bereits als zu
erhaltende Entität getaggt sind (`preserves`-Prüfung); falls nicht, werden 1–2 neue Korpus-Fälle mit
genau dieser Struktur (Verb + Objekt + Zweck-Anhang) ergänzt, bevor gemessen wird. Die neue
Prompt-Fassung gilt erst als angenommen, wenn sie im Korpus-Schnitt bei `preserves` mindestens so
gut abschneidet wie die bisherige Fassung, ohne Verschlechterung bei `inventedNumbers`,
`alteredNames` oder `foreignWords`.

## Test Plan

### Automated Tests (TDD RED)
- [ ] Test 1 (Punkt 1, Unit): GIVEN ein `TaskItem`, dessen `title` aus einer KI-Revision stammt
      (`titleSourceRaw == FieldSource.ai.rawValue`, eine `Revision` mit `field == .title,
      author == .ai` existiert) WHEN `RevisionService.revert(RevisionService.firstAIRevision(of:
      .title, on: task)!, on: task, contexts: [], projects: [])` aufgerufen wird THEN entspricht
      `task.title` wieder dem `oldValue` der ersten KI-Revision und es existiert eine neue
      `Revision` mit `field == .title, author == .user`.
- [ ] Test 2 (Punkt 1, Unit): GIVEN ein `TaskItem` ohne jede Titel-Revision (Titel stammt vom
      Nutzer) WHEN `RevisionService.aiSetFields(on: task)` aufgerufen wird THEN enthält das Ergebnis
      `.title` nicht — der Reset-Button in `TaskDetailView` bleibt für diesen Fall unsichtbar
      (Verhalten wird über die bestehende, bereits getestete `aiSetFields`-Logik abgesichert, kein
      zusätzlicher View-Test nötig).
- [ ] Test 3 (Punkt 2, Messung): GIVEN der Korpus `Measurement/date-title-corpus.json` inklusive der
      ggf. neu ergänzten Zweck/Objekt-Fälle WHEN die neue Prompt-Fassung gegen den Korpus gemessen
      wird (`TitleCheck.preserves`, `inventedNumbers`, `alteredNames`, `foreignWords`) THEN ist
      `preserves` für den Beispielfall „Termin bei Auto Senger machen für Inspektion und
      Reifenwechsel" wahr (Zweck/Objekt „Inspektion" und „Reifenwechsel" tauchen im Titel auf) UND
      keiner der vier Werte verschlechtert sich im Korpus-Schnitt gegenüber der alten Prompt-Fassung.

## Acceptance Criteria

- **AC-1 (Punkt 1):** Given ein Aufgaben-Titel wurde von der KI gesetzt (Detailansicht zeigt den
  Reset-Button neben dem Titelfeld) / When der Nutzer den Reset-Button antippt / Then zeigt das
  Titelfeld sofort den Vor-KI-Wert, ohne dass der Nutzer den Umweg über `Show` →
  `RevisionsSheet` gehen muss.
- **AC-2 (Punkt 1):** Given der Titel wurde soeben per Reset-Button zurückgesetzt / When die Ansicht
  neu gezeichnet wird (z. B. durch Fokuswechsel) / Then zeigt `titleDraft` weiterhin den
  zurückgesetzten Wert, nicht kurzzeitig den alten KI-Wert.
- **AC-3 (Punkt 1):** Given ein Aufgaben-Titel stammt vom Nutzer, nicht von der KI / When die
  Detailansicht angezeigt wird / Then ist kein Reset-Button neben dem Titelfeld sichtbar.
- **AC-4 (Punkt 2):** Given ein Rohtext mit einem Zweck- oder Objektanhang wie „Termin bei Auto
  Senger machen für Inspektion und Reifenwechsel" / When die KI-Anreicherung mit der neuen
  Prompt-Fassung läuft / Then enthält der erzeugte Titel den Zweck/Objekt-Teil („Inspektion",
  „Reifenwechsel"), auch wenn der Titel dafür länger als acht Wörter wird.
- **AC-5 (Punkt 2, Messpflicht):** Given der bestehende Titel-Korpus (`date-title-corpus.json`) /
  When die neue Prompt-Fassung gegen den Korpus gemessen wird / Then ist `preserves` im
  Korpus-Schnitt mindestens so gut wie mit der alten Fassung, und `inventedNumbers`,
  `alteredNames`, `foreignWords` verschlechtern sich nicht.
- **AC-6 (gesamt):** Given der bestehende Funktionsumfang (Rohtext-Anzeige, Liste, `RevisionsSheet`,
  andere KI-Felder) / When Unit-Tests laufen / Then bleiben alle bisherigen Tests grün, und die App
  baut ohne neue Warnungen aus dieser Änderung.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Punkt 1 nutzt ausschließlich bestehende, bereits im ADR-6-Muster
  („Revisions statt Undo") verankerte Bausteine (`firstAIRevision`, `revert`) und führt kein neues
  Konzept ein. Punkt 2 ändert nur den Modell-Prompt innerhalb des bestehenden ADR-3-Feldmusters
  (`title`/`titleSourceRaw`/`titleConfidence`) — kein neues Feld, kein Schema-Wechsel, kein Bruch
  der Ein-Zeilen-Vorgabe für die Liste (`03-design-briefing.md`). Die im Entwurf geprüfte
  Alternative „Titel zweizeilig" (Bruch der Ein-Zeilen-ADR) und „feste Unterzeile im Detail"
  (neues Feld nach ADR-3-Muster) wurden von Henning am 2026-09-25 explizit verworfen; beide hätten
  eine neue ADR-Nummer oder eine Änderung an einer bestehenden ADR erfordert.

## Changelog

- 2026-09-25: Initial spec created
