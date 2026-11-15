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
