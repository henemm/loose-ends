# Context: fix-125-titel-treue

## Request Summary
Issue #125 (Henning, 2026-09-24): (1) eine KI-gesetzte Überschrift lässt sich nicht in einem
Klick zurücksetzen; (2) die KI kürzt die Überschrift auf einen aktiven Satz und lässt dabei
Inhalte ersatzlos wegfallen (Beispiel: "Termin bei Auto Senger machen für Inspektion und
Reifenwechsel" → "Termin bei Auto Senger machen"), statt sie in eine Subheadline zu verschieben.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Views/TaskDetailView.swift` | Titel-`TextField`, Rohtext-Zeile direkt darunter (Zeile 27–35), Zugriff auf Reset nur über den "Show"-Button → `RevisionsSheet` (Zeile 61–70, 91–93) |
| `LooseEnds/Views/TaskRow.swift` | Listenzeile: nur `task.displayTitle`, `lineLimit(1)`, kein Platz für eine zweite Inhaltszeile ohne Regelbruch |
| `Shared/Services/RevisionService.swift` | `firstAIRevision(of:on:)` liefert den Vor-KI-Wert direkt, `revert(_:on:...)` schreibt den Reset als Nutzer-Revision — beide bereits vorhanden, aktuell nur aus dem `RevisionsSheet` heraus verdrahtet |
| `Shared/Enrichment/FoundationModelsEnricher.swift` (Zeile 27, 88) | Prompt/`@Guide`: „at most eight words" — hier entsteht der Informationsverlust, nicht erst bei der Anzeige |
| `Shared/Models/TaskItem.swift` (Zeile 31–34, 114–117) | Bestehendes Feld-Muster: `title` / `titleSourceRaw` / `titleConfidence`; `displayTitle` als Fallback auf `rawText` |
| `docs/project/03-design-briefing.md` (Zeile 70, 80) | ADR-Text: „Eine Zeile ist nie höher als Titel plus eine Merkmalzeile, auch wenn alle Attribute gepflegt sind" — steht der Idee einer permanenten Subheadline in der Liste direkt entgegen. Für Detail bereits festgelegt: „Oben der Titel, editierbar. Darunter, klein, der Rohtext, nicht editierbar." — das existiert schon (s.o.) |

## Existing Patterns
- **Optionales abgeleitetes Feld** (ADR-3): Wert + `*SourceRaw` + `*Confidence`, durchgängig für title, dueDate, importance, urgency, duration, energy, people, contexts.
- **Regeln vor Modell**: `DueDateRule`, `ImportanceUrgencyRule` — deterministisch, Konfidenz 1.0, kein Modellaufruf. Kein passendes Beispiel für „Text aufteilen in Kern + Rest" per Regel, weil der Titel eine Paraphrase ist, kein Teilstring des Rohtexts — eine regelbasierte Extraktion des „Rests" ist damit nicht sauber möglich.
- **Revisions statt Undo** (ADR-6): jeder Reset ist eine neue Nutzer-Revision mit dem alten Wert, nichts wird gelöscht. `RevisionsSheet` nutzt das bereits für "Reset" je Revision und "Reset all".

## Dependencies
- Upstream: `FoundationModelsEnricher` → `EnrichmentWriter` (Schwelle 0,6) → `TaskItem.title/titleSourceRaw/titleConfidence`.
- Downstream: `TaskRow.displayTitle`, `TaskDetailView` Titel-Feld und Rohtext-Zeile, `RevisionsSheet` (Reset-Liste), `FieldFormatting`.

## Existing Specs
- Keine dedizierte Spec zu Titel-Darstellung in `docs/specs/` — nur im Design-Briefing (`03-design-briefing.md`) festgelegt, nicht in einer separaten Entity-Spec.
- `docs/specs/enrichment/feat-95-parser-in-app.md` zeigt das Muster für „Regel ersetzt Modellfeld im Produktpfad" (Vorbild, falls Punkt 2 rule-first gelöst wird).

## Risks & Considerations
- **ADR-Konflikt:** Eine sichtbare Subheadline in der Listenzeile widerspricht direkt der bestehenden Festlegung „nie höher als Titel plus eine Merkmalzeile". Diese Festlegung wäre die Alternative, die für Option „Subheadline in der Liste" gekippt werden müsste — braucht laut Hennings Vorgabe („In Alternativen denken") eine explizite Gegenüberstellung, keine stille Änderung.
- **Rohtext ist in Detail bereits sichtbar:** Der Informationsverlust ist nicht endgültig — wer die Aufgabe öffnet, sieht den vollen Rohtext klein unter dem Titel. Die eigentliche Frage ist, ob das genügt oder ob eine kuratierte Subheadline (statt des rohen Satzes) nötig ist, und ob das auch in der Liste sichtbar sein muss.
- **Modell-Erweiterung wäre ein Rückschritt gegen „Regeln vor Modell":** Ein von der KI erzeugtes Subheadline-Feld hat dieselbe Fehlklasse wie das jetzige Problem (das Modell entscheidet erneut, was wichtig ist, und kann wieder etwas weglassen). Eine deterministische Alternative (immer der Rohtext als zweite Zeile, kein neues Modellfeld) vermeidet dieses Risiko vollständig.
- **Punkt 1 (1-Klick-Reset) ist risikoarm:** `RevisionService.firstAIRevision` + `revert` existieren bereits und werden nur nicht direkt am Titel-Feld angeboten. Kleiner, isolierter Fix ohne Schema-Änderung.
- **UI-Änderung → Entwurf vor Spec:** Da Punkt 2 etwas sichtbar umgestaltet (Zeile oder Detail-Layout), braucht `/20-analyse` laut Hennings Vorgabe eine Artefakt-Vorschau (Heute vs. Entwurf, Hell/Dunkel, mindestens eine Alternative) vor der Spec-Phase.

## Analysis

### Type
Bug (zwei unabhängige Teilpunkte aus #125)

### Entwurf (Heute vs. Alternativen)
https://claude.ai/artifact/CGGfwjhgny3UzZjG3vUbd9 — Kopie im Repo: `docs/artifacts/fix-125-titel-treue/`

### Punkt 1 — 1-Klick-Reset für den Titel
**Technischer Ansatz:** Reset-Icon-Button neben dem Titel-`TextField` in `TaskDetailView.swift`,
sichtbar nur wenn `RevisionService.aiSetFields(on: task).contains(.title)`. Ruft
`RevisionService.revert(RevisionService.firstAIRevision(of: .title, on: task)!, ...)`. Nach dem
Reset muss `titleDraft` explizit mit `task.title` nachgezogen werden (aktuell nur in `.onAppear`
gesetzt) — sonst zeigt das Feld kurzzeitig weiter den alten KI-Wert.
**Umfang:** 1 Datei (`TaskDetailView.swift`), ~20–25 LoC. Test: Unit-Test auf
`RevisionService`-Ebene (Reset-Button löst `revert(firstAIRevision(of: .title,...))` korrekt aus);
kein neuer UI-Test-Rahmen nötig (CLAUDE.md: UI-Tests erst nach Design-Freeze, nur als Smoke-Test —
es existiert noch keiner für `resetRevisionButton`/`revisionsButton`).
**Risiko:** Niedrig. Rein additiv, nutzt bestehende, bereits getestete Bausteine, keine
Schema-Änderung, kein ADR-Konflikt.
**Offene Frage:** Keine — wird wie beschrieben gebaut.

### Punkt 2 — Titel darf nichts wortlos verschlucken
**Root Cause bestätigt und präzisiert:** Der Verlust entsteht ausschließlich im Prompt
(`FoundationModelsEnricher.swift:26-27,88-89`) — nicht in Speicherung oder Anzeige (geprüft:
`draft()`-Trimming, `TaskItem.displayTitle`, `TaskRow.lineLimit(1)` kürzen inhaltlich nichts, nur
Anzeige-Ellipsis). Wichtig: Das Beispiel „Termin bei Auto Senger machen für Inspektion und
Reifenwechsel" (9 Wörter) wurde auf 5 Wörter gekürzt, nicht auf die erlaubten 8 — das Adjektiv
„short" in der Guide-Beschreibung drängt zusätzlich zur reinen Wortgrenze. Eine reine Anhebung des
Wortlimits würde dieses Beispiel also vermutlich **nicht** fixen; der Guide-Text muss explizit
verlangen, Zweck/Objekt zu erhalten, auch wenn das mehr Wörter kostet.

**Drei Alternativen (siehe Entwurf):**
- **(a) Prompt/Guide lockern und umformulieren** — z. B. „Imperative title, up to twelve words.
  Never drop the object or purpose of the task even if that means using more words." Kein
  Schema-, kein ADR-Wechsel. Bleibt Modell-Aufgabe (Titel aus Freitext ist Sprachverständnis,
  „Regeln vor Modell" verlangt hier keine Regel).
- **(b) Titel zweizeilig in Liste + Detail** — kippt ADR-14 („Zeile nie höher als Titel + eine
  Merkmalzeile") bewusst, bräuchte explizite Freigabe.
- **(c) Feste Unterzeile im Detail** (Hennings eigener Vorschlag in #125) — entweder redundant zum
  bereits sichtbaren Rohtext, oder ein neues persistiertes Feld nach ADR-3-Muster
  (`*Raw`/`*SourceRaw`/`*Confidence` + zweite Guide-Property im Enrichment-Schema) — würde die
  4–5-Datei/250-LoC-Grenze für einen Bugfix sprengen und wäre damit ein Feature, kein Fix mehr.
  Variante „bestehendes `titleReason`-Feld anzeigen" spart zwar das neue Feld, misst aber aktuell
  eine Begründung, keine Aufzählung weggelassener Inhalte — bräuchte denselben
  Prompt-Umschreibungs-Aufwand wie (c) selbst, ohne echten Zusatznutzen zu (a).

**Risiko: Mittel** (nicht niedrig) — zwei Gründe:
1. Eine Prompt-Änderung an einem on-device LLM ist nicht deterministisch beweisbar wie ein
   regelbasierter Fix; „besser" heißt bestenfalls „im Korpus-Schnitt besser", nicht „dieser Fall ist
   jetzt garantiert richtig".
2. Nebenwirkungsrisiko: ein gelockerter Prompt kann an anderer Stelle neue Fehler erzeugen (mehr
   `foreignWords`/`inventedNumbers`, oder systematisch längere Titel, was der Ein-Zeilen-Absicht der
   Liste auch ohne ADR-Bruch zuwiderläuft).

**Messpflicht (CLAUDE.md „Regeln vor Modell"):** Es existiert bereits die passende
Messinfrastruktur — `Measurement/Corpus.swift` (`enum TitleCheck`: `preserves`, `inventedNumbers`,
`alteredNames`, `foreignWords`) und der Korpus `Measurement/date-title-corpus.json` (#67/#92). Vor
dem Merge muss die neue Prompt-Fassung gegen den Korpus laufen; zu prüfen, ob „Zweck/Objekt"-Phrasen
wie „für Inspektion und Reifenwechsel" dort schon als zu erhaltende Entität getaggt sind — sonst
bräuchte der Korpus 1–2 neue Fälle, bevor die Änderung belastbar gemessen werden kann.

**Empfehlung:** (a), mit der oben präzisierten Formulierung, gemessen gegen den bestehenden Korpus
vor dem Merge. Abweichung von Hennings eigenem Vorschlag (c) — deshalb wird das nicht still
umgesetzt, sondern ihm mit den Alternativen zur Entscheidung vorgelegt (Entwurf-Link oben).

### Reihenfolge
Punkt 1 und Punkt 2 sind unabhängig (kein Dateiüberlapp), aber Punkt 1 zuerst: schafft einen
risikofreien Reset-Pfad, bevor der riskantere Prompt-Eingriff aus Punkt 2 live geht — falls ein
Titel nach der Prompt-Änderung schlechter wird, ist er mit einem Tipp korrigierbar.

### Scope Assessment (gesamt)
- Dateien: `TaskDetailView.swift` (Punkt 1), `FoundationModelsEnricher.swift` +
  `Measurement/date-title-corpus.json` (ggf. erweitert) + zugehöriger Unit-Test (Punkt 2) — 3–4
  Dateien, deutlich unter der 4–5-Datei-Grenze für einen Bugfix.
- Geschätzt: +50/-10 LoC insgesamt (ohne Korpus-JSON-Daten).
- Risiko: Punkt 1 niedrig, Punkt 2 mittel.

### Entscheidung (Henning, 2026-09-25)
Punkt 2 wird als **(a) Prompt lockern** umgesetzt. Rückfrage geklärt: der wegfallende Teil
("für Inspektion und Reifenwechsel") landet im Titel selbst, nicht in einem separaten Element —
beim Öffnen der Aufgabe steht er unverkürzt da. Kein neues Bedienelement (kein Long-Press/Preview
in der Liste); die Liste bleibt einzeilig und kürzt wie jeder lange Titel heute schon per iOS-Ellipse.
Entwurf entsprechend ergänzt: `docs/artifacts/fix-125-titel-treue/entwurf.html`.

### Open Questions
Keine mehr offen.

### RED-Phase (2026-09-25) — tatsächliche Testdateien
- **Test 1** (Spec-Testplan) ist bereits durch den bestehenden Test `RevisionServiceTests.revertTitle`
  (`LooseEndsTests/RevisionServiceTests.swift:26`) abgedeckt — identisches Szenario. Kein Duplikat
  angelegt; Test bleibt unverändert grün, dient als Regressions-Absicherung für den Reset-Button.
- **Test 2** ist neu: `RevisionServiceTests.aiSetFieldsExcludesUserTitle`
  (`LooseEndsTests/RevisionServiceTests.swift`). Lief sofort grün — bestätigt, dass `aiSetFields`
  den Reset-Button für AC-3 bereits korrekt verbirgt, ohne dass dafür neuer Code nötig ist.
- **Test 3** ist neu: `TitleFidelityPromptTests.instructionsPreserveObjectAndPurpose`
  (`LooseEndsTests/TitleFidelityPromptTests.swift`). RED bestätigt (3 fehlgeschlagene Assertions,
  siehe `docs/artifacts/fix-125-titel-treue/test-red-output.txt`): prüft `FoundationModelsEnricher.instructions`
  als reinen String-Inhalt (kein Modellaufruf) auf das neue Wortlimit („twelve words") und die
  explizite Zweck/Objekt-Schutzklausel. Wird durch die Prompt-Änderung in Implementation Details grün.
- **Korpus-Messung (AC-5)** läuft NICHT als Xcode-Test: braucht Apple Intelligence, nicht
  deterministisch reproduzierbar in CI/Simulator. Läuft wie jede Korpus-Messung dieses Projekts in
  der Labor-App (`LooseEndsLab`), in Scheiben, vor dem Merge — manueller Mess-Schritt während
  `/50-implement`, kein automatisierter Unit-Test.
