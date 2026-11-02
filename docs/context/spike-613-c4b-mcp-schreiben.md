# Context: spike-613-c4b-mcp-schreiben (#613 Schnitt C4b, MCP-Schreibwerkzeuge)

## Request Summary
C4a (PR #798) macht die Abschrift für Claude lesbar (`get_now`, `list_tasks`). C4b ergänzt die Werkzeuge, mit denen Claude etwas auslöst:
`capture_task`, `complete_task`, `set_due`, dazu `get_order_result` samt `getResult` im Dienst. Weiterhin ohne Port, ohne Anmeldung (C6) und ohne Betrieb (C7).

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/mcp.ts` | `mcpHandler`, `account(ctx)`, `reply`, `reading`: hier kommen vier Werkzeuge dazu; das Konto-Muster („kein Konto“, `isError`) gilt weiter |
| `server/src/orders.ts` | `putOrder` (`stored`/`duplicate`, prüft die Form mit `checkOrder`), `claimOrder`, `putResult`. Es gibt **kein Lesen eines Ergebnisses** → neu `getResult` |
| `server/src/transcripts.ts` | `getTranscript(pool, account)`; liefert `tasks[]` mit `status`, `dueDate`: Quelle des erwarteten Stands |
| `server/migrations/001_claude_schema.sql` | `orders` (`claimed_by`, `claimed_at`, `account_id`), `order_results` (Schlüssel `order_id`); **unverändert** |
| `server/test/mcp.test.ts` | Muster aus C4a: `Client` + `StreamableHTTPClientTransport` mit `fetch: handler.fetch`, `authInfo` je Anfrage, `freshPool`, Beispielabschrift aus dem Vertrag |
| `docs/reference/claude-abschrift-vertrag.md` | Vertrag v1: Auftrag (`capture`, `complete`, `setDue`), erwarteter Stand, Ergebnis (`done`/`rejected`, `invalid`/`missing`/`stale`) |
| `docs/specs/spike-613-schnitt-c4a-mcp-lesen.md` | Abgrenzung: C4b = `capture_task`, `complete_task`, `set_due` (erwarteter Stand aus der Abschrift, Kennung vom Dienst), `getResult`, `get_order_result` |

## Existing Patterns
- Jede Dienstfunktion ist eine einzige SQL-Anweisung und gibt einen kleinen Status zurück; Formfehler sind `Error("<Gegenstand> ungültig: <Pfad>: <Grund>")`.
- Werkzeugfehler kommen als `isError: true` mit kurzem deutschem Text, nie als Ausnahme; ohne Konto „kein Konto“ **vor** jedem Lesen oder Schreiben.
- Je Anfrage eine frische Server-Instanz (zustandslos), nichts wird zwischengespeichert; keine Inhalte in Logs.
- Kennungen sind UUIDs in Großbuchstaben (Vertrag). Die Kennung des Auftrags vergibt der Dienst, nicht Claude (C4a-Spec, Alternative `create_order` verworfen).

## Entwurfsfragen für /20-analyse
1. **Erwarteter Stand:** `complete_task`/`set_due` lesen `getTranscript` und übernehmen `status` und `dueDate` der Aufgabe als `expectedStatus`/`expectedDueDate` (fehlendes `dueDate` = „keine Fälligkeit“). Fehlt die Abschrift oder die Aufgabe, antwortet das Werkzeug mit Fehler, ohne einen Auftrag anzulegen. Das Gerät prüft den Stand ohnehin noch einmal (`stale`), Lesen und Anlegen müssen deshalb nicht atomar sein.
2. **`getResult(pool, account, orderID)`:** drei Zustände aus `orders` + `order_results`: unbekannt (oder fremdes Konto, gleiche Antwort), „wartet auf ein Gerät“ (`claimed_by` leer), „bei einem Gerät“ (vergeben, noch kein Ergebnis), Ergebnis (`doc`). Konto-Zaun wie bei der Abschrift.
3. **Eingaben:** Zod-Schemas je Werkzeug (`text`; `taskID`; `taskID`, `date?`, `hasTime`); `date` und `taskID` prüft am Ende `checkOrder` (Form), die Werkzeuge erfinden keine zweite Prüfung.
4. **Tool-Annotationen** (`readOnlyHint`, `destructiveHint`, `idempotentHint`) für die drei Schreibwerkzeuge: Claude-Clients zeigen danach Bestätigungen an.
5. **Wiederholung:** Ruft Claude `capture_task` zweimal, entstehen zwei Aufträge (neue Kennung je Aufruf). Für `complete_task`/`set_due` fängt der erwartete Stand die Doppelung auf dem Gerät als `stale` ab.

## Dependencies
- Upstream: `@modelcontextprotocol/server` 2.4.0, `zod` 4.6.7, `pg`; `node:crypto` für die Kennung. Keine neuen Pakete.
- Downstream: noch niemand ruft `mcpHandler` auf (C7 hängt ihn an einen Port, C6 liefert `authInfo`, #621 verbindet Claude). Die App holt Aufträge erst, wenn ein Gerätekanal gebaut ist (offen).

## Existing Specs
- `docs/specs/spike-613-schnitt-c4a-mcp-lesen.md`, `docs/specs/spike-613-schnitt-c3b-auftraege.md`, `docs/specs/spike-613-schnitt-c3a-abschrift-annehmen.md`

## Risks & Considerations
- **Umfang:** C1a, C1b, C3a, C3b-Nachbarn lagen 30–65 Zeilen über 250, jedes Mal durch die Tests; C4a lag bei 253. Vier Werkzeuge plus `getResult` mit Tests (≈ 1,5× Code) reißen die Grenze wahrscheinlich. Die Spec schätzt das ehrlich und spricht es bei der Freigabe an. Mögliche Teilung: C4b-1 `capture_task` + `get_order_result`, C4b-2 `complete_task` + `set_due`.
- **Veraltete Abschrift:** Claude sieht den Stand des letzten Hochladens. Ein Auftrag auf Basis einer alten Abschrift wird vom Gerät als `stale` abgelehnt; das ist gewollt und gehört in die Werkzeugbeschreibung („zuerst `list_tasks` lesen“).
- **Kein Gerätekanal:** Ohne Abholen auf der App-Seite bleiben Aufträge „wartet auf ein Gerät“; `get_order_result` muss das ehrlich sagen, nicht „erledigt“ vortäuschen.
- **Datenschutz:** Auftragsinhalt (Text, Kennungen) nicht in Logs; `get_order_result` gibt nur das Ergebnisdokument aus.
- **Regeln vor Modell:** alles Regel, SQL und Protokoll, kein Sprachmodell.

## Analysis

### Type
Feature (Dienst `server/`, kein Sichtbares in der App; keine UI-Vorschau nötig).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/orders.ts` | MODIFY | `getResult(pool, account, orderID)`: eine SQL-Anweisung über `orders` + `order_results`, vier Zustände (unbekannt/fremd, wartet auf ein Gerät, bei einem Gerät, Ergebnis) |
| `server/src/mcp.ts` | MODIFY | `capture_task`, `complete_task`, `set_due`, `get_order_result`; Konto-Muster („kein Konto“, `isError`) und Annotationen |
| `server/test/mcp.test.ts` | MODIFY | Schreibwerkzeuge über denselben In-Process-Client, Beispielabschrift aus dem Vertrag |
| `server/test/orders.test.ts` | MODIFY | `getResult`: vier Zustände, Konto-Zaun |
| `docs/specs/spike-613-schnitt-c4b-*.md` | CREATE | Teil-Spec(s) |

### Scope Assessment
- Files: 4 geänderte (+ Spec)
- Estimated LoC: ≈ +300/-0 gesamt (Code ≈ 110, Tests ≈ 190). Das reißt die 250-LoC-Grenze (wie C1a/C1b/C3).
- Teilung (Empfehlung): **C4b-1** `getResult` + `get_order_result` + `capture_task` (≈ 150), **C4b-2** `complete_task` + `set_due` mit erwartetem Stand aus der Abschrift (≈ 150). C4b-1 ist für sich prüfbar und liefert den Rückkanal zuerst.
- Risk Level: LOW (reiner Dienst, kein Port, keine Anmeldung, keine App-Berührung; „Kein Pfad der Geräteliste berührt.“)

### Technical Approach
Alles Regel/SQL/Protokoll, kein Sprachmodell („Ohne Modell geht es nicht“ entfällt: es gibt keine Sprachaufgabe).
1. **Kennung vergibt der Dienst** (`crypto.randomUUID().toUpperCase()`), `putOrder` prüft die Form per `checkOrder`; die Werkzeuge bauen keine zweite Prüfung.
2. **Erwarteter Stand aus der Abschrift** (`getTranscript`): `status` und `dueDate` der Aufgabe werden `expectedStatus`/`expectedDueDate` (fehlend = keine Fälligkeit). Ohne Abschrift oder Aufgabe: Fehler, kein Auftrag. Lesen und Anlegen sind nicht atomar; das Gerät prüft ohnehin `stale`.
3. **`getResult`** als eine Anweisung (LEFT JOIN, Filter `account_id`): fremdes Konto = unbekannt, gleiche Antwort. Ehrlich „wartet auf ein Gerät“, solange `claimed_by` leer ist.
4. **Annotationen** `readOnlyHint:false`, `destructiveHint:false` (alles geht über Revisionen, nichts wird gelöscht), `idempotentHint:false` für `capture_task`; Beschreibung nennt „zuerst `list_tasks` lesen“.
5. Je Anfrage frische Server-Instanz, keine Inhalte in Logs.

### Alternativen (und was sie kippen würden)
- **Ein Werkzeug `create_order(kind, …)`** statt dreier: weniger Code, aber Claude müsste den erwarteten Stand selbst liefern und die Kennung wählen; kippt die C4a-Entscheidung „Kennung vom Dienst“.
- **Erwarteter Stand von Claude statt aus der Abschrift:** einfacher, verlagert Fehler auf Claude und erzeugt mehr `stale`; kippt Entwurfsfrage 1.
- **Kein `get_order_result`, Ergebnis nur über die nächste Abschrift:** spart ein Werkzeug, Claude erführe aber nie, warum ein Auftrag abgelehnt wurde; kippt den Vertrag (jeder Auftrag bekommt ein Ergebnis).
- **Vorschlag statt Auftrag** (Claude schlägt vor, Henning bestätigt in der App): kein Schreibpfad nötig, aber kippt ADR Weg B „Aufträge als Nutzeränderung“; nicht gewählt, da der Vertrag bereits steht.

### Dependencies
`@modelcontextprotocol/server` 2.4.0, `zod` 4.6.7, `pg`, `node:crypto`; keine neuen Pakete. Downstream niemand (C6 Anmeldung, C7 Betrieb, Gerätekanal offen).

### Open Questions
- [x] Teilung C4b-1/C4b-2: technische Entscheidung, Claude entscheidet (Teil-Spec je Schnitt). Diese Sitzung: C4b-1.
