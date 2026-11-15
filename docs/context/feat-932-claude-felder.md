# Context: feat-932-claude-felder

## Request Summary
Claude soll Titel und Angaben einer Aufgabe setzen können: beim Erfassen (`capture_task` mit optionalen Feldern) und danach
(neues Werkzeug `update_task`). Jede Änderung ist eine Nutzerrevision mit Grund „Claude“, der Rohtext bleibt unverändert, und
weder Regeln noch Modell überschreiben einen Wert, den Claude gesetzt hat (#932, Anlass: claude.ai-Durchlauf #622/#623).

Felder laut Issue: Titel, Notiz (nur beim Erfassen), Fälligkeit, Wichtigkeit, Dringlichkeit, Dauer, Energie, Tags, Projekt.
Nicht: Knäuel, Perle, Anhänge, Kalender, Ort, Wiederholung. Tags/Projekt nur vorhandene Namen, unbekannt → `invalid`.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/orders.ts` | `Order`-Typ und `forms` je Art (Pflicht-/Optionalschlüssel); neue Art `update`, optionale Felder an `capture` |
| `server/src/transcripts.ts` | Prüfbausteine `Check`, `text`, `time`, `id`, `flag`, `rank`, `shape`; neue Bausteine für Enums, Namenslisten |
| `server/src/mcp.ts` | `capturing`, `expected()` (erwarteter Stand aus der Abschrift), `registerOrders`; neues Werkzeug `update_task` |
| `server/migrations/007_order_kinds.sql` | Muster: CHECK auf `orders.kind` ersetzen; Migration 009 für `update` |
| `server/src/anleitung.ts` | Anleitung ≤ 2048 Byte; Werkzeugnamen-Test `server/test/mcp-anleitung.test.ts` |
| `server/test/mcp-write.test.ts`, `orders.test.ts`, `schema.test.ts` | Tests der Auftragswerkzeuge; `schema.test.ts` liest Beispiele aus dem Vertrag |
| `docs/reference/claude-abschrift-vertrag.md` | Vertrag Version 1: Arten, erwarteter Stand, Gründe; „mehr Felder in der Abschrift = Version 2 + Datenschutzfreigabe (#625)“ |
| `Shared/Services/OrderExecutor.swift` | `Order` (Codable), `execute`, `recording(...)` für Claude-Revisionen, `refuse`, `commit` |
| `Shared/Services/RevisionService.swift` | `set(field,to:...)` = Nutzerrevision; `isByClaude`/`lastClaudeChange` (Zeile „Zuletzt von Claude“, #622 S2) |
| `Shared/Services/FieldCodec.swift` | eine Kodierung je Feld: Tags als JSON-Namensliste, Projekt als Name, Energie als Zahl |
| `Shared/Enrichment/EnrichmentWriter.swift` | Modell schreibt Titel im Erstlauf ohne `userHasTouched`-Schutz (Zeile 54: `may(.title, firstRun: true, …)`) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | Regeln: Fälligkeit/Wichtigkeit/Dringlichkeit schützen nur über „Feld leer“, Dauer/Tags/Projekt/Notiz zusätzlich über `userHasTouched` |
| `Shared/Services/CaptureService.swift` | `save(text, via: .claude)` setzt den Regeltitel; Basis für Erfassen mit Feldern |
| `Shared/Services/SiriCapture.swift` | Vorbild: Erfassen mit Feldern als Nutzerrevisionen mit Grund („Siri“), alles vor dem ersten Schreiben geprüft |
| `Shared/Services/CatalogService.swift` | Namensabgleich für Tags/Projekte (eindeutig, #157) |
| `Shared/Services/TranscriptCodec.swift` | Abschrift trägt nur id, title, status, dueDate, dueHasTime, contexts, project, nextRank, isKnaeuel |
| `LooseEndsTests/OrderExecutorTests.swift` | Tests je Art; Vertragsbeispiele wörtlich |
| `LooseEnds/Claude/ClaudeSync.swift` | dekodiert Aufträge; unlesbarer Auftrag → `rejected/invalid` |

## Existing Patterns
- Jede Auftragsart: Dienst prüft nur Form (`forms` in `orders.ts`), App prüft Bedeutung und antwortet `invalid`/`missing`/`stale`.
- Erwarteter Stand kommt im Dienst aus der zuletzt gelesenen Abschrift (`expected()`), nie von Claude selbst.
- `OrderExecutor` prüft alles vor dem ersten Schreiben; `recording` schreibt eine Nutzerrevision mit Grund „Claude“ und vergibt
  den Grund auch an Nebenrevisionen.
- Neue Auftragsart = Migration, die den CHECK auf `orders.kind` ersetzt (007).
- Werte-Enums: Importance/Urgency `low|medium|high`, DurationBucket `minutes5|minutes15|minutes30|hour1|hours2plus`,
  Energy Int −3…3 (`FieldCodec` speichert die Zahl als Text).

## Dependencies
- Upstream: `RevisionService`, `FieldCodec`, `CatalogService`, `CaptureService`, `TitleRule`, zod-Schemas der MCP-SDK.
- Downstream: `ClaudeSync` (führt Aufträge aus), Detailzeile „Zuletzt von Claude“, `EnrichmentCoordinator` (läuft nach dem
  Erfassen über die neue Aufgabe), Abschrift → Claude.

## Existing Specs
- `docs/reference/claude-abschrift-vertrag.md` (Vertrag v1)
- #622 Schnitt 1/2 (Revisionen für Aufträge, Claudes Spur im Detail)

## Risks & Considerations
- **Modell überschreibt Claudes Titel:** Im Erstlauf schreibt das Modell den Titel ohne Nutzerschutz. Ein von Claude beim
  Erfassen gesetzter Titel würde sofort vom Modell ersetzt; braucht `!userHasTouched(.title)` im Erstlauf.
- **Erwarteter Stand für Felder außerhalb der Abschrift:** Wichtigkeit, Dringlichkeit, Dauer, Energie und Notiz stehen nicht in
  der Abschrift; ein `update` kann für sie keinen alten Wert erwarten. Sie in die Abschrift zu nehmen wäre laut Vertrag Version 2
  und braucht die Freigabe im Datenschutztext (#625). Ohne sie: erwarteter Stand nur über Status (und Titel, wo geändert).
- **Reihenfolge der Auslieferung:** Swift-`Codable` ignoriert unbekannte Schlüssel. Eine ältere App würde ein `capture` mit
  Feldern als reinen Text erfassen und `done` melden – Felder still verloren. Dienst-Schnitt erst ausrollen, wenn die App die
  Felder kennt, oder die App lehnt unbekannte Schlüssel ab / Version 2 des Auftrags.
- **Tags/Projekt nur aus offenen Aufgaben sichtbar:** `list_contexts`/`list_projects` zählen nur Namen offener Aufgaben; ein
  Tag ohne offene Aufgabe ist für Claude unsichtbar, auf dem Gerät aber vorhanden.
- **Regeln danach:** Fälligkeit/Wichtigkeit/Dringlichkeit schützt nur „Feld nicht leer“; setzt Claude ein Feld leer
  (entfernen), darf die Regel es bei „Erneut analysieren“ wieder füllen? `mayWrite(.reanalysis)` prüft `userHasTouched` – passt.
- Umfang: Dienst + Vertrag (S1) und App (S2) getrennt, je ≤ 250 LoC.

## Analysis

### Type
Feature

### Befund aus dem Code (2026-11-15)
- Jedes Feld der Liste hat schon ein `RevisedField` und eine Kodierung in `FieldCodec` (Titel, Notiz, Fälligkeit,
  Wichtigkeit, Dringlichkeit, Dauer, Energie, Tags als Namensliste, Projekt als Name). Die App braucht **kein neues
  Modellfeld und keine CloudKit-Änderung**: `RevisionService.set(field, to:…)` schreibt jede Änderung als Nutzerrevision,
  der Grund „Claude“ kommt wie in `setDue` dazu. Tags/Projekt löst `RevisionService` über die übergebenen Kataloge auf.
- **Schutz vor Regeln und Modell:** Regeln für Tags, Projekt, Notiz, Dauer prüfen im Erstlauf `userHasTouched`; Fälligkeit,
  Wichtigkeit, Dringlichkeit prüfen „Feld leer“ (ein von Claude gesetzter Wert ist nicht leer); „Erneut analysieren“ prüft
  überall `userHasTouched`. **Einzige Lücke: der Titel.** `EnrichmentWriter` schreibt den Modelltitel im Erstlauf mit
  `may(.title, firstRun: true, …)` ohne Nutzerschutz. Ein beim Erfassen gesetzter Claude-Titel würde sofort ersetzt.
  Fix: `firstRun: !userHasTouched(.title, on: task)`. Kontexte und Projekt schreibt das Modell nie (#215/#469).
- **Ältere App-Stände:** Swift-`Codable` ignoriert unbekannte Schlüssel. Ein `capture` mit Feldern an eine App ohne
  Feldkenntnis würde als reiner Text erfasst und `done` gemeldet – Felder still weg. Eine **neue Art** (`update`) lehnt eine
  alte App dagegen sauber ab (unlesbar → `rejected/invalid`). Aufträge führt heute nur Hennings Testbau aus (Konto-Gruppe
  nur mit `konto` an), also genügt eine feste Reihenfolge: **erst App im Testbau, dann Dienst ausrollen.**
- **Erwarteter Stand:** Die Abschrift trägt `title`, `status`, `dueDate`, `contexts`, `project`. Für diese Felder nimmt der
  Dienst den erwarteten Wert aus der Abschrift (`expected()` wie bei `complete`), die App vergleicht vor dem ersten
  Schreiben. Wichtigkeit, Dringlichkeit, Dauer, Energie stehen nicht in der Abschrift; für sie gilt nur der erwartete
  Status (letzter Schreiber gewinnt, vorher Hennings Ja laut Anleitung). Sie in die Abschrift aufzunehmen wäre Vertrag
  Version 2 und bräuchte die Freigabe im Datenschutztext (#625) – nicht in diesem Ticket.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Services/OrderExecutor.swift` | MODIFY | `Order.fields` (optional, ein Objekt), Art `update`; Prüfung aller Felder vor dem ersten Schreiben (Enum-Werte, Energie −3…3, Titel nicht leer, Tag-/Projektnamen vorhanden per `nameKey` → sonst `invalid`); Schreiben je Feld über `RevisionService.set` mit Grund „Claude“; `capture` setzt die Felder nach `CaptureService.save` |
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | Modelltitel im Erstlauf nur ohne Nutzerrevision am Titel |
| `LooseEndsTests/OrderExecutorTests.swift` | MODIFY | je Feld ein Test (Grund „Claude“, `lastClaudeChange`), unbekannter Name/Wert → `invalid` ohne Schreiben, `stale` für Titel/Tags/Projekt/Fälligkeit, Vertragsbeispiele wörtlich |
| `LooseEndsTests/EnrichmentWriterTests.swift` (o. ä.) | MODIFY | Modell überschreibt Claudes Titel im Erstlauf nicht |
| `server/src/orders.ts`, `server/src/transcripts.ts` | MODIFY | Form von `fields` (Prüfbausteine für Enums, Energie, Namensliste), Art `update` |
| `server/migrations/009_update_kind.sql` | CREATE | CHECK auf `orders.kind` um `update` erweitern (Muster 007) |
| `server/src/mcp.ts` | MODIFY | `capture_task` mit optionalen Feldern, neues `update_task` (Aufgabe, `generatedAt`, Felder; erwarteter Stand aus der Abschrift) |
| `server/src/anleitung.ts` | MODIFY | „Titel und Angaben ändern nur nach Hennings Ja; Tags/Projekte nur aus list_contexts/list_projects“ (≤ 2048 Byte) |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | `fields`, Art `update`, Beispiele (von Swift- und Server-Tests gelesen) |
| `server/test/*.test.ts` | MODIFY | Form, Werkzeuge, Namenstest der Anleitung |

### Scope Assessment
- Gesamt deutlich über einem Schnitt (geschätzt ~600 LoC mit Tests). Drei Schnitte, je ≤ 5 Dateien / ±250 LoC:
  - **S1 App:** `OrderExecutor` (Felder + `update`), Titelschutz im `EnrichmentWriter`, Tests, Vertragsabschnitt mit
    Beispielen. ~230 LoC. Unschädlich ohne Dienst (nichts schickt Felder).
  - **S2 Dienst, Erfassen mit Feldern:** Form `fields` in `orders.ts`/`transcripts.ts`, `capture_task` mit Feldern, Tests. ~200 LoC.
  - **S3 Dienst, `update_task`:** Migration, Werkzeug mit erwartetem Stand, Anleitung, Tests; danach Testbau (konto an),
    Ausrollen, claude.ai-Durchlauf laut DoD. ~220 LoC.
- Risk Level: MEDIUM — Aufträge ändern echte Daten; Schutz liegt in der Prüfung vor dem ersten Schreiben, dem erwarteten
  Stand und der Reihenfolge App vor Dienst.
- Geräteliste: `Shared/Persistence/`, Modell, `project.yml` unberührt; `EnrichmentWriter` ist nicht `FoundationModelsEnricher`/
  `EnrichmentCoordinator`. Stufe 3 läuft trotzdem über den claude.ai-Durchlauf der DoD im Testbau.

### Technical Approach (Empfehlung)
Ein gemeinsames Objekt `fields` für `capture` und die neue Art `update` (Schlüssel: `title`, `notes` nur bei `capture`,
`dueDate`+`dueHasTime`, `importance`, `urgency`, `duration`, `energy`, `contexts`, `project`). Der Dienst prüft nur die Form,
die App die Bedeutung (Namen vorhanden, Titel nicht leer) – wie bei allen Arten. Ein Feld, das fehlt, bleibt unberührt;
Leeren ist nicht Teil dieses Tickets (außer Tags per leerer Liste; Fälligkeit entfernen bleibt `set_due`). `update` erwartet
Status sowie den Abschriftwert jedes geänderten Feldes, das die Abschrift trägt; sonst `stale`. Reihenfolge S1 → Testbau →
S2/S3 → Ausrollen.

### Alternativen
1. **Regelweg statt Felder (Regeln vor Modell):** Claude schreibt die Angaben in den Erfassungstext („… 20 Minuten #Garten“),
   die vorhandenen Regeln leiten sie ab. Kein neuer Vertrag. Verworfen, weil der Rohtext dann nicht mehr Hennings Wortlaut
   ist (Anleitung #623: „mit seinem Wortlaut, unverändert“), Energie/Projekt keine sichere Regel haben und Umbenennen danach
   gar nicht geht – genau der Anlass.
2. **Je Feld ein eigenes Werkzeug** (`rename_task`, `set_tags`, …) wie `set_due`: einfachere Einzelprüfung, aber neun Arten,
   neun Migrationseinträge und viele Aufrufe pro Aufgabe. Verworfen zugunsten eines `update` mit Feldobjekt.
3. **Abschrift Version 2 mit allen Feldern** (volle Stand-Prüfung auch für Dauer/Energie/Wichtigkeit): kippt die Festlegung
   des Vertrags „mehr Felder = Version 2 + Datenschutzfreigabe (#625)“; als Folgearbeit möglich, nicht hier.

### Dependencies
Upstream: `RevisionService`, `FieldCodec`, `CatalogService` (`nameKey`), `CaptureService`, `TitleRule`, zod (MCP-SDK).
Downstream: `ClaudeSync` (unlesbar → `invalid`), Detailzeile „Zuletzt von Claude“ (#622 S2), `EnrichmentCoordinator` nach dem Erfassen.

### Open Questions
- [x] Keine PO-Frage offen: Felder, Ausschlüsse und „nur vorhandene Namen“ legt das Issue fest; Rest ist technisch.

### Umfang (PO, 2026-11-15)
Henning nahm in /30-write-spec den Umfang von etwa 420 LoC für Schnitt 1 an („Annehmen“); Überhang = Prüf- und Ablehnungstests, Produktcode + Vertrag ≈ 186. In /60-validate nicht erneut fragen, solange der Endstand nicht nennenswert über ≈ 470 liegt.
