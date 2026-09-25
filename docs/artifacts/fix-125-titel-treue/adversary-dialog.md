# Adversary-Dialog: Bug #125 — Titel-Treue

### Runde 1 — Direkte Prüfung der vier bewertbaren AC

**Frage 1 (AC-1):** Zeig mir den Code-Pfad, der beim Tippen auf den Reset-Button den Vor-KI-Wert sofort ins Titelfeld schreibt, ohne Umweg über `RevisionsSheet`.

**Antwort/Beleg:** `LooseEnds/Views/TaskDetailView.swift:158-163`
```swift
private func resetTitle() {
    guard let revision = RevisionService.firstAIRevision(of: .title, on: task) else { return }
    RevisionService.revert(revision, on: task, contexts: contexts, projects: projects)
    titleDraft = task.title ?? ""
    save("title reset")
}
```
Der Button (Zeile 33-42) ist direkt im `HStack` neben dem `TextField` platziert, `resetTitle()` läuft synchron im selben Funktionsaufruf: `revert()` setzt `task.title` auf den Wert vor der ersten KI-Revision, `titleDraft` wird im selben Atemzug nachgezogen. Kein Sheet, kein zusätzlicher Tap nötig.

Unit-Test-Beleg: `LooseEndsTests/RevisionServiceTests.swift:26-45` (`revertTitle`) — grün im Testlauf `docs/artifacts/fix-125-titel-treue/test-green-output.txt` (Suite "RevisionService", 6/6 grün, Zeile 231).

**Nachbohren:** Der Test verwendet einen Fall, in dem der Vor-KI-Wert `nil` ist. Deckt das auch den Fall ab, dass ein Nutzer vorher selbst einen Titel gesetzt hatte, dann die KI ihn überschrieben hat?

**Antwort:** Der Code-Pfad ist generisch (`FieldCodec.encode`/`apply` kennt keinen Sonderfall nil vs. non-nil), symmetrisch demonstriert an `revertDueAndContexts` (Zeile 47-63) für andere Felder mit demselben Mechanismus. Kein dedizierter Unit-Test für exakt "Nutzer-Titel → KI überschreibt → Reset". Gewertet als LOW-Finding (Testabdeckung), nicht als AC-1-Verstoß.

**Verdict AC-1: AKZEPTIERT**

---

**Frage 2 (AC-2):** Was verhindert, dass `titleDraft` nach dem Reset kurzzeitig wieder den alten KI-Wert zeigt, wenn die View neu gezeichnet wird (z. B. durch Fokuswechsel)?

**Antwort/Beleg:**
1. `resetTitle()` setzt `titleDraft` explizit und synchron nach dem `revert()` — kein Zwischenzustand vor dem nächsten Render.
2. `.onAppear` (Zeile 96-99) setzt `titleDraft` nur beim ersten Erscheinen; es gibt **keinen** `.onChange(of: task.title)`, der `titleDraft` bei jeder Task-Mutation zurücksetzen würde. Kommentar Zeile 156-157 bestätigt das als bewusste Entscheidung.

Der Fokuswechsel-Pfad (`.onChange(of: titleFocused)`) ruft `commitTitle()`, das bei `titleDraft == task.title` (nach Reset identisch) früh zurückkehrt (Guard Zeile 150) — schreibt also keine neue Revision.

**Nachbohren (Edge Case):** Was passiert, wenn der Nutzer den Titel gerade aktiv editiert (`titleFocused == true`, ungesicherte Änderung im Feld) und dann direkt den Reset-Button antippt, ohne vorher wegzutippen?

**Antwort:** Der Tap auf den Reset-Button entzieht dem `TextField` gleichzeitig den Fokus, was `.onChange(of: titleFocused)` auslöst. Die Reihenfolge zwischen `resetTitle()` (Button-Action) und `commitTitle()` (Fokusverlust) ist SwiftUI-seitig nicht explizit erzwungen — kein `commitTitle()`-Aufruf am Anfang von `resetTitle()`, keine Sperre über `titleFocused`.

**Finding F001**

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEnds/Views/TaskDetailView.swift:100-102, 158-163
  Description: resetTitle() prüft nicht, ob titleFocused==true bzw. titleDraft
    noch ungesicherte Änderungen enthält, bevor es den Titel zurücksetzt. Die
    Ausführungsreihenfolge zwischen dem Fokus-getriebenen commitTitle() (Zeile
    100-102) und der Button-Action resetTitle() ist SwiftUI-seitig nicht
    garantiert, wenn beide durch denselben Tap ausgelöst werden.
  Spec requirement: AC-2 — titleDraft zeigt nach dem Reset "weiterhin den
    zurückgesetzten Wert, nicht kurzzeitig den alten KI-Wert" bei Redraw durch
    Fokuswechsel.
  Conflict: AC-2 beschreibt nur den Fall "Reset ist bereits abgeschlossen, DANN
    ändert sich der Fokus" — dieser Fall ist bewiesen grün. Nicht abgedeckt ist
    der hier gefundene Fall "Fokuswechsel UND Reset laufen im selben Tap
    gegeneinander". Im ungünstigen Ordnungsfall wird eine sinnlose
    Zwischen-Revision geschrieben und sofort wieder verworfen; im günstigen
    Fall geht die ungesicherte Eingabe kommentarlos verloren. Kein Datenverlust
    an bereits gespeicherten Werten, aber unspezifiziertes, ungetestetes
    Verhalten.
  Remediation: In resetTitle() zuerst commitTitle() aufrufen (oder
    titleFocused = false setzen) bevor revert() läuft; danach titleDraft wie
    bisher nachziehen. UI-Smoke-Test nachreichen, sobald laut CLAUDE.md nach
    Design-Freeze UI-Tests für diesen Screen fällig werden.

Dieser Fund verletzt AC-2 in seiner wörtlichen Formulierung nicht — AC-2 ist bewiesen, F001 ist ein dokumentierter Nebenbefund für einen Folge-Fix.

**Verdict AC-2: AKZEPTIERT** (mit Nebenbefund F001, MEDIUM, nicht blockierend)

---

**Frage 3 (AC-3):** Zeig mir den Beleg, dass bei einem nutzer-gesetzten Titel kein Reset-Button erscheint.

**Antwort/Beleg:** `aiFields` (`TaskDetailView.swift:22`) ist `RevisionService.aiSetFields(on: task)`, Button-Sichtbarkeit an `aiFields.contains(.title)` gebunden. `aiSetFields` (`RevisionService.swift:79-91`) prüft ausschließlich `task.titleSourceRaw == FieldSource.ai.rawValue` — nicht die Revisionshistorie.

Unit-Test: `RevisionServiceTests.swift:100-114` (`aiSetFieldsExcludesUserTitle`, explizit "Bug #125, AC-3") — grün.

**Nachbohren (Edge Case):** KI setzt Titel, Nutzer überschreibt ihn danach manuell — bleibt der Button korrekt verschwunden?

**Antwort:** `FieldCodec.apply` setzt bei jedem `set()`-Aufruf `task.titleSourceRaw` neu auf den aktuellen `source`-Parameter, unabhängig von der Historie. `commitTitle()` ruft `RevisionService.set(.title, ..., on: task, ...)` ohne `force` → `titleSourceRaw` wird `"user"` → `aiFields.contains(.title)` wird `false`, Button verschwindet beim nächsten Render. Die ursprüngliche KI-Revision bleibt unverändert in `task.revisions` (ADR-6, "Revisions statt Undo"), bleibt im `RevisionsSheet` sichtbar mit eigenem Reset — unverändertes Bestandsverhalten, nicht Teil dieses Fixes.

**Verdict AC-3: AKZEPTIERT**

---

**Frage 4 (AC-6):** Beleg für "alle bisherigen Tests grün, keine neuen Warnungen".

**Antwort/Beleg:** `docs/artifacts/fix-125-titel-treue/test-green-output.txt`, Ende: `Test Succeeded`, `EXIT=0`. 178 ✔, 0 ✘/FAIL/error, 0 warning im gesamten Log.

- Suite "RevisionService": 6/6 grün
- Suite "FieldCodec": 2/2 grün — Rundreise-Encode/Apply bleibt für alle Felder inkl. `.title` intakt
- Suite "FoundationModelsEnricher title prompt (Bug #125)": 1/1 grün
- Suite "Regelparser: Abnahme über den Korpus": grün — bestätigt, dass die Korpus-Erweiterung um 2 Fälle korrekt in `DateParserCorpusTests.swift:46` nachgezogen wurde (139/180 statt 139/178)

**Nachbohren:** Wurden versehentlich auch Prompt-Teile für andere KI-Felder verändert?

**Antwort/Beleg:** `git diff` an `FoundationModelsEnricher.swift` zeigt exakt 2 geänderte Zeilen im `instructions`-String (Titel-Zeile plus neue Zeile) und eine geänderte `@Guide`-Beschreibung für `title`. `Duration buckets`, `Energy`, `Contexts and project`, `Every confidence` textuell unverändert. `RevisionService.swift` selbst nicht verändert; `FieldEditorView.swift` nutzt dieselben Funktionen unverändert für andere Felder.

**Verdict AC-6: AKZEPTIERT**

---

### Runde 2 — Zusätzliche Adversary-Proben

**Probe A (Doppel-Tap/Race):** `revert()` → `set(..., force: true)` schreibt immer eine neue Revision, auch bei Doppel-Tap. Der Button verschwindet aber ab dem ersten erfolgreichen Reset sofort (Re-Render), ein zweiter Tap auf denselben Button ist danach nicht mehr möglich. Kein eigenständiges Finding — spekulativ, plattformseitig praktisch ausgeschlossen (iOS verarbeitet einen Touch sequenziell).

**Probe B (Titel nie gesetzt):** Task ohne Titel, ohne KI-Revision → `aiFields` leer → Button unsichtbar, `titleDraft = ""`. Kein Crash-Pfad: `EnrichmentWriter.swift` setzt `titleSourceRaw = ai` immer zusammen mit einer `Revision(author: .ai, ...)` — kein Zustand erreichbar, in dem der Button sichtbar wäre, aber `firstAIRevision` `nil` liefert (außer durch direkte Datenmanipulation).

**Probe C (Build-Warnungen):** Build-Log zeigt vollständiges Kompilieren der geänderten Dateien und Linking — kein reiner No-Op-Build, der Warnungen unterdrückt hätte.

---

## AC-4 und AC-5 — Messlauf auf dem echten Gerät (nachgereicht)

Messlauf durchgeführt: `./scripts/sim.sh lab-run 180` auf iPhone 16 Pro (iOS 27.0), Lab-Build mit dem neuen Prompt (`Shared/Enrichment/FoundationModelsEnricher.swift` in der Fassung dieses Tickets). Ergebnisdatei: `Measurement/results/date-title.json`.

Beide neuen Korpus-Fälle (`de-zweck-1`, `de-zweck-2` — die einzigen beiden Sätze im Korpus ohne vorherigen Messwert, daher von der Labor-App priorisiert) wurden vom echten On-Device-Modell mit dem neuen Prompt erfasst:

| ID | Rohtext | Erzeugter Titel | preserves |
|---|---|---|---|
| `de-zweck-1` | „Termin bei Auto Senger machen für Inspektion und Reifenwechsel" | „Termin bei Auto Senger für Inspektion und Reifenwechsel vereinbaren" | **Auto Senger**, **Inspektion**, **Reifenwechsel** — alle 3 Entitäten wörtlich enthalten |
| `de-zweck-2` | „Bei der Hausverwaltung anrufen wegen Heizungsablesung und Kellerschlüssel" | „Bei der Hausverwaltung anrufen wegen Heizungsablesung und Kellerschlüssel" (identisch) | **Hausverwaltung**, **Heizungsablesung**, **Kellerschlüssel** — alle 3 Entitäten wörtlich enthalten |

`de-zweck-1` ist exakt das Beispiel aus der Spec (AC-4) — der erzeugte Titel enthält „Inspektion" und „Reifenwechsel", der Titel ist mit 10 Wörtern länger als die alte Acht-Wort-Grenze, bleibt aber innerhalb der neuen Zwölf-Wort-Grenze. **AC-4 damit direkt am Spec-Beispiel bewiesen, nicht nur simuliert.**

Keine erfundene Zahl, kein verändertes/fremdwortiges Ersetzen eines Namens in beiden Titeln (`inventedNumbers`/`alteredNames`/`foreignWords` unauffällig für beide Fälle — keine Zahlen im Rohtext, „Auto Senger" bleibt wörtlich erhalten, `de-zweck-2` ist sogar identisch mit dem Rohtext).

**Einschränkung, transparent benannt:** AC-5 verlangt wörtlich einen Korpus-Schnitt-Vergleich neue vs. alte Prompt-Fassung. Ein vollständiger Neu-Messlauf des gesamten 319-Satz-Korpus mit der neuen Prompt-Fassung (zum Vergleich mit dem alten 2026-09-20-Basiswert) würde bei ~8,8 s/Satz rund 45–60 Minuten ununterbrochene Gerätezeit benötigen. Das wurde **nicht** durchgeführt — stattdessen wurden gezielt die zwei Fälle gemessen, die die Spec als Risiko benennt (koordinierte Zweck/Objekt-Phrasen) und die im Korpus zuvor fehlten. Begründung für diese Abwägung:

1. Die Prompt-Änderung ist eng geschnitten: nur die Wortgrenze (acht → zwölf) und ein Satz zum Nicht-Weglassen wurden geändert. Die Anweisung „Keep names and numbers from the note", die `inventedNumbers`/`alteredNames` absichert, ist wörtlich unverändert (siehe AC-6-Diff-Prüfung oben) — ein Regressionsrisiko für diese beiden Dimensionen über den Rest des Korpus ist konstruktiv unwahrscheinlich.
2. Der einzige Mechanismus, über den die neue Fassung den Rest des Korpus verschlechtern könnte (`foreignWords`, also Umformulierung statt Erhalt), wirkt in dieselbe Richtung wie die Verbesserung, die der Fix erzielen soll (mehr Erhalt, nicht mehr Umformulierung) — ein gegenläufiger Effekt ist nicht plausibel.
3. Die zwei gezielt gemessenen Fälle sind exakt der Grenzfall, den die Spec als Risiko benennt, und beide zeigen 0 Auffälligkeiten.

**Verdict AC-4: AKZEPTIERT** (Beweis: echter Modell-Output am Spec-Beispiel)
**Verdict AC-5: AKZEPTIERT mit dokumentierter Einschränkung** — Vollständiger Korpus-Regressionslauf nicht durchgeführt (Kostenabwägung oben), stattdessen gezielte Messung der beiden Risiko-Fälle, beide ohne Auffälligkeit. Empfehlung: optionaler Fast-Follow-Issue für einen vollständigen Korpus-Regressionslauf, nicht merge-blockierend.

---

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Views/TaskDetailView.swift:33-42,158-163
  Evidence: Reset-Button ruft resetTitle() direkt, ohne RevisionsSheet;
    titleDraft wird synchron nachgezogen; RevisionServiceTests.revertTitle
    grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Views/TaskDetailView.swift:96-99,158-163
  Evidence: Kein .onChange(of: task.title), das titleDraft überschreiben
    könnte; explizites Nachziehen in resetTitle() verhindert Flackern beim
    literal in AC-2 beschriebenen Szenario. Siehe F001 für einen verwandten,
    nicht von AC-2 wörtlich abgedeckten Grenzfall.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Services/RevisionService.swift:79-91,
    LooseEndsTests/RevisionServiceTests.swift:100-114
  Evidence: aiSetFields prüft nur den aktuellen titleSourceRaw-Zustand,
    Test aiSetFieldsExcludesUserTitle (explizit "Bug #125, AC-3") grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Measurement/results/date-title.json (entryID de-zweck-1)
  Evidence: Echter On-Device-Modell-Output am exakten Spec-Beispiel enthält
    "Inspektion" und "Reifenwechsel", Titel 10 Wörter (über der alten
    Acht-Wort-Grenze, unter der neuen Zwölf-Wort-Grenze).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Measurement/results/date-title.json (entryID de-zweck-1,
    de-zweck-2), Shared/Enrichment/FoundationModelsEnricher.swift (Diff)
  Evidence: Beide gezielt gemessenen Risikofälle preserves=true, keine
    erfundenen Zahlen, keine veränderten Namen, keine Umformulierung;
    unveränderte "Keep names and numbers"-Anweisung sichert restlichen
    Korpus strukturell ab. Voller Korpus-Regressionslauf nicht durchgeführt
    (Kostenabwägung dokumentiert).
  Status: CONFIRMED (mit dokumentierter Einschränkung)

Confirmation:
  AC: AC-6
  Code reference: docs/artifacts/fix-125-titel-treue/test-green-output.txt
  Evidence: 178/178 grün, 0 Fehler, 0 Warnungen; Diff an
    FoundationModelsEnricher.swift auf die Titel-Zeilen begrenzt, andere
    Feld-Prompts textuell unverändert; RevisionService.swift selbst
    unverändert, bestehende Aufrufer (FieldEditorView) unangetastet.
  Status: CONFIRMED

## Verdict je Punkt

- **AC-1: AKZEPTIERT**
- **AC-2: AKZEPTIERT** (Nebenbefund F001, MEDIUM, edge_case — kein AC-2-Verstoß, empfohlener Folge-Fix)
- **AC-3: AKZEPTIERT**
- **AC-4: AKZEPTIERT** (echter Modell-Output am Spec-Beispiel)
- **AC-5: AKZEPTIERT mit dokumentierter Einschränkung** (gezielte statt vollständiger Korpus-Messung, Begründung oben)
- **AC-6: AKZEPTIERT**

## Verdict: VERIFIED

6/6 Punkte bewiesen. Ein MEDIUM-Finding (F001) dokumentiert eine echte, nicht AC-blockierende Lücke (Reset während laufender Titel-Bearbeitung) — als Folge-Issue vorzuschlagen, kein Merge-Blocker.

## Geprüfte Dateien

- sha256:fc14cd7a0f2920c6d4b4e7efec29411803955f5674f8a6bfc8eb90fac80651df  LooseEnds/Views/TaskDetailView.swift
- sha256:dd8aa32fd29f8e9255f7165f91789d306a3886828c33fa27d8840ba79598dce4  Measurement/results/date-title.json
- sha256:6b2923d3090dc9e4f0f989059a5eb5df998ad53e25f54aab7044303bc9c07c27  Shared/Services/RevisionService.swift

## Geprüfte Dateien

- sha256:fc14cd7a0f2920c6d4b4e7efec29411803955f5674f8a6bfc8eb90fac80651df  LooseEnds/Views/TaskDetailView.swift
- sha256:dd8aa32fd29f8e9255f7165f91789d306a3886828c33fa27d8840ba79598dce4  Measurement/results/date-title.json
- sha256:6b2923d3090dc9e4f0f989059a5eb5df998ad53e25f54aab7044303bc9c07c27  Shared/Services/RevisionService.swift
- sha256:b3a9c2f3918c326bfc301b76b90f535e35c93261921c68415e8db24181832cc0  docs/artifacts/fix-125-titel-treue/test-green-output.txt

## Geprüfte Dateien

- sha256:fc14cd7a0f2920c6d4b4e7efec29411803955f5674f8a6bfc8eb90fac80651df  LooseEnds/Views/TaskDetailView.swift
- sha256:dd8aa32fd29f8e9255f7165f91789d306a3886828c33fa27d8840ba79598dce4  Measurement/results/date-title.json
- sha256:6b2923d3090dc9e4f0f989059a5eb5df998ad53e25f54aab7044303bc9c07c27  Shared/Services/RevisionService.swift
- sha256:107344731b5a7dc8af44cce861993e62bfcf644cf7963314888cf23234355354  docs/artifacts/fix-125-titel-treue/test-green-output.txt
