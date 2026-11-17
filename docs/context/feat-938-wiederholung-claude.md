# Context: feat-938-wiederholung-claude

## Request Summary
Claude soll beim Erfassen (`capture_task`) und Ändern (`update_task`) eine Wiederholung mitgeben können; die App
legt sie als `RepeatRule` mit einer Nutzer-Revision „Claude“ an (wie die `fields` aus #932). Danach werden die
wiederkehrenden Aufgaben der Erinnerungsliste „Family“ über Claude übertragen (Titel, nächstes Datum, Rhythmus, Tag, Link).

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Models/RepeatRule.swift:5-81` | Modell: `frequency` (daily/weekly/monthly/yearly), `interval`, `weekdays` (nur weekly, 1 = So), `basis`, `hour`/`minute`, `anchor` (#552); kein „n-ter Wochentag“ |
| `Shared/Models/TaskItem.swift:15,45` | `sourceURL: URL?` (Link, ohne `RevisedField`), `repeatRule: RepeatRule?` (CloudKit `CD_repeatRule BYTES`, schema.ckdb:221) |
| `Shared/Services/FieldCodec.swift:22,81-82,100-110` | `.repeatRule` als sortiertes JSON kodiert/angewandt |
| `Shared/Services/SiriRepeatMapping.swift:13-106` | Vorbild: Fremdregel → `RepeatRule`, lehnt `.nthWeekday` ab; `apply` schreibt eine `.repeatRule`-Revision `author: .user` |
| `LooseEnds/Views/FieldEditorView.swift:579-590` | `applyRepeat`: neue Regel → `anchor = dueDate ?? firstDueDate()`, setzt fehlende Fälligkeit mit |
| `Shared/Services/OrderExecutor.swift:8-55,88-123,186-209` | `Order`, `OrderFields` (kein repeat, kein Link), `capture`, `update`, `write` (je Feld `RevisionService.set` + Grund „Claude“) |
| `Shared/Services/TranscriptCodec.swift:31-40` | Abschrift ohne Wiederholung (Vertrag Z. 22-23, 40: mehr Felder = Version 2) |
| `server/src/orders.ts:6-78` | `Fields`, `fieldsCheck`, `captureFields`, `updateFields`, `forms` |
| `server/src/mcp.ts:77-87,189-207,301-369` | zod `captureFieldsSchema`/`updateFieldsSchema`, Werkzeugbeschreibungen (Feldliste in Prosa) |
| `server/src/anleitung.ts` | Anleitung an Claude (≤ 2048 Bytes), Test hält Werkzeugnamen gleich |
| `docs/reference/claude-abschrift-vertrag.md:88-211` | Auftrag, `fields`-Absatz (113-121), jsonc-Beispiele (Tests lesen sie) |

## Existing Patterns
- #932: jedes gesetzte Feld = eine Nutzer-Revision mit Grund „Claude“; Form-Prüfung im Dienst (zod strict + `fieldsCheck`), Namen/Zustand in der App.
- Siri (#225): Fremdregel → `RepeatRule` mit Ablehnung nicht abbildbarer Regeln, Revision mit Herkunftsgrund.
- Editor: neue Regel bekommt `anchor` und notfalls eine erste Fälligkeit.

## Dependencies
- Upstream: `RevisionService.set`, `FieldCodec`, `CaptureService.save(sourceURL:)`, `TaskActions.complete` (Weiterrollen).
- Downstream: Vertrag + Tests (`OrderExecutorFieldsTests`, `server/test/orders.test.ts`, `mcp-write.test.ts`), Dienst-Rollout auf rennwienix, App-Auslieferung über TestFlight.

## Existing Specs
- `docs/specs/feat-932-schnitt-1-app.md`, `-2-dienst.md`, `-3-update.md` — Vorlage für den Schnitt App/Dienst/update.

## Risks & Considerations
- Modelllücke „jedes Jahr am 2. Samstag im Februar“: Modellerweiterung (CloudKit additiv) vs. jährlich zum Datum mit Hinweis.
- Link: `sourceURL` hat keine Revision; Alternative Notiz (nur beim Erfassen).
- Stale-Prüfung bei `update` mit Wiederholung: Abschrift kennt keine Wiederholung → nur Status prüfbar, oder Vertrag Version 2.
- Vertrags-jsonc-Blöcke müssen gültiges JSON bleiben (Tests lesen sie).
- Geteilte Liste: Personenzuordnungen gehen verloren (PO vorher sagen).
- Mehrere Schnitte nötig (Scoping 4–5 Dateien / ±250 LoC): App, Dienst, Übertragung.
- Dienst-Rollout und TestFlight gehören der Epic-Sitzung (#612) — das ist diese.

## Analysis

### Type
Feature

### Befund (2026-11-17)
- `RepeatRule` trägt alles aus der Liste „Family“ außer „jedes Jahr am 2. Samstag im Februar“: „alle 26/52 Wochen“ = `weekly`, `interval` 26/52 (der Editor erlaubt 1…52, `FieldEditorView.swift:478`), Uhrzeit = `hour`/`minute`, die tägliche Gewohnheit „morgens/abends“ = `daily` mit Uhrzeit.
- `repeatRule` ist in CloudKit ein `BYTES`-Feld mit JSON: ein neuer Schlüssel in `RepeatRule` braucht keine Schemaänderung; eine alte App ignoriert ihn beim Dekodieren (rechnet dann jährlich zum Datum).
- Der Link hat ein eigenes Feld: `TaskItem.sourceURL`, gesetzt nur beim Erfassen (`CaptureService.save(sourceURL:)`), im Detail als „Source · Open the source“ (`TaskDetailView.swift:237`). Keine Revision dafür (wie bei Share/Mail).
- Die Abschrift kennt keine Wiederholung: bei `update` mit `repeat` ist nur der Status der erwartete Zustand (wie bei Wichtigkeit/Dauer, #932). Kein Vertrag Version 2.
- **Reihenfolge-Risiko:** Swift `Codable` ignoriert unbekannte Schlüssel. Ein Dienst, der `repeat` schon annimmt, während auf Hennings Gerät noch die alte App die Aufträge ausführt, legt die Aufgabe *ohne* Wiederholung an und meldet `done`. Deshalb: App-Schnitt zuerst, Dienst erst ausrollen, wenn der TestFlight-Bau mit S1 auf seinen Geräten läuft.

### Vertragsform (Vorschlag)
`fields.repeat = { frequency: "daily"|"weekly"|"monthly"|"yearly", interval?: 1…52 (Standard 1), weekdays?: [1…7] (nur weekly, 1 = So), basis?: "fromDueDate"|"fromCompletion" (Standard fromDueDate) }`
- Uhrzeit der Regel = Uhrzeit von `dueDate`, wenn `dueHasTime` (keine eigene Zeitangabe → kein Widerspruch möglich).
- Neue Regel wie `FieldEditorView.applyRepeat`: `anchor` = gesetzte/vorhandene Fälligkeit, sonst `firstDueDate(now)` und diese Fälligkeit mitsetzen. Vorhandene Regel ersetzen: `anchor` bleibt, außer `dueDate` kommt im selben Auftrag.
- Eine `.repeatRule`-Revision `author: .user`, Grund „Claude“, wie die übrigen Felder.
- `fields.link` (nur `capture_task`, wie `notes`): https/http-URL → `sourceURL`.
- Wiederholung entfernen: nicht in diesem Ticket (eigene Form `null` nötig; bei Bedarf Folge-Issue).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Services/OrderExecutor.swift` | MODIFY | `OrderFields.repeat`/`link`, Form-Prüfung, Schreiben mit Anker + Revision |
| `LooseEndsTests/Services/OrderExecutorRepeatTests.swift` | CREATE | Erfassen/Ändern mit Wiederholung, Anker, Uhrzeit, Ablehnungen, Link |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | `repeat`/`link`-Absatz, jsonc-Beispiel |
| `server/src/orders.ts` | MODIFY | `Fields.repeat`/`link`, `fieldsCheck` |
| `server/src/mcp.ts` | MODIFY | zod-Schema `repeat`/`link`, Werkzeugbeschreibungen |
| `server/src/anleitung.ts` | MODIFY (evtl.) | ein Satz: Wiederholung mitgeben, Abweichungen nennen |
| `server/test/orders.test.ts`, `server/test/mcp-write.test.ts` | MODIFY | Form-Prüfungen |

### Schnitte
- **S1 App** (4 Dateien, ~+220 LoC): OrderExecutor + Tests + Vertrag. Auslieferung per TestFlight.
- **S2 Dienst** (4–5 Dateien, ~+150 LoC): Prüfung, Schema, Beschreibung, Tests; Rollout auf rennwienix erst nach S1 auf den Geräten.
- **S3 Übertragung** (kein Code): Liste „Family“ über die Loose-Ends-Werkzeuge, nach Hennings Ja zur geplanten Liste; Durchlauf in claude.ai als DoD-Beleg.
- Optional **S1b Modell** „n-ter Wochentag“ (nur bei PO-Wahl A): `RepeatRule.ordinal` + `nextDueDate` + Anzeigetext + Tests, ~4 Dateien.

### Scope Assessment
- Files: S1 4, S2 5
- Estimated LoC: S1 +220, S2 +150
- Risk Level: MEDIUM (Auftrags-Vertrag zwischen Dienst und App; Reihenfolge der Auslieferung)

### Technical Approach
Wiederholung als weiteres `fields`-Feld nach dem Muster #932 (Form im Dienst, Bedeutung in der App), Anker-Logik wie der Editor, Link nur beim Erfassen auf `sourceURL`. Alternative: eigenes Werkzeug `set_repeat` (wie `set_due`) — verworfen, weil die Familie-Übertragung dann zwei Aufträge je Aufgabe braucht und der Anker zwischen beiden Aufträgen falsch stünde. Für die Liste: Alternative zum Screenshot ist das direkte Lesen der Erinnerungen-Liste auf dem Mac (exakte Regeln, Links, Tags, Uhrzeiten) — PO-Frage.

### Open Questions
- [x] „2. Samstag im Februar“: Henning 2026-11-17 → jährlich zum Datum, Claude nennt die Abweichung. Kein S1b.
- [x] Quelle der Liste: Henning 2026-11-17 → Claude liest „Family“ einmal nur lesend aus Erinnerungen auf dem Mac, zeigt die geplante Liste, überträgt erst nach seinem Ja (S3).
- [x] Link: eigenes Feld `link` → `sourceURL`, nur beim Erfassen.
- [x] Zuordnungen zu Personen gehen verloren — Henning wird es gesagt.

## Umfangsfreigabe (2026-11-17)

Nach RED: Tests 409 Zeilen, Produktcode ≈105, Vertrag ≈30, gesamt ≈515 statt 250. Henning (AskUserQuestion, vor /50-implement): „So weiterbauen“. In /60-validate nicht erneut fragen, solange der Endstand nicht nennenswert über ≈560 liegt.
