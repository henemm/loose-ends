---
entity_id: spike-613-schnitt-c4b1-mcp-erfassen-ergebnis
type: feature
created: 2026-11-02
updated: 2026-11-02
status: draft
workflow: spike-613-c4b-mcp-schreiben
---

# Spec: MCP-Werkzeuge capture_task und get_order_result samt getResult, Schnitt C4b-1 (#613, Weg B „Fenster für Claude“)

## Approval

- [ ] Approved

## GitHub Issue

#613 (Spike, Epic #612). Schnitt C4b-1; das Issue bleibt offen (`Refs #613`, nie `Closes #613`).
Vorgänger: C4a (`docs/specs/spike-613-schnitt-c4a-mcp-lesen.md`, PR #798), C3b (`docs/specs/spike-613-schnitt-c3b-auftraege.md`), Vertrag v1 (`docs/reference/claude-abschrift-vertrag.md`).
Analyse: `docs/context/spike-613-c4b-mcp-schreiben.md`. Nicht Teil dieser Spec: C4b-2 (`complete_task`, `set_due` mit erwartetem Stand aus der Abschrift), Anmeldung und Konto (C6), Port und Betrieb (C7), ein Gerätekanal in der App.

## Purpose

Claude kann seit C4a lesen, aber nichts auslösen und nichts zurückbekommen. Dieser Schnitt liefert den ersten Schreibweg und zugleich den Rückkanal:
`getResult(pool, account, orderID)` liest den Stand eines Auftrags; `capture_task` legt einen `capture`-Auftrag an (die Kennung vergibt der Dienst); `get_order_result` gibt den Stand zurück.
Der Rückkanal kommt zuerst, damit Claude nie im Dunkeln schreibt. Ohne Gerätekanal in der App holt noch niemand Aufträge ab: `get_order_result` muss das ehrlich sagen („wartet auf ein Gerät“), nie „erledigt“ vortäuschen.

**Regeln vor Modell:** SQL, Regel und Protokoll, kein Sprachmodell. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt, es gibt keine Sprachaufgabe.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Weg B ist in #612 entschieden (ADR-21 folgt in C8); dieser Schnitt setzt den Schreib- und Rückzweig um.

## Source

**Files:** `server/src/orders.ts` (`getResult`), `server/src/mcp.ts` (zwei Werkzeuge), `server/test/orders.test.ts`, `server/test/mcp.test.ts`
**Identifier:** `getResult`, `capture_task`, `get_order_result`

### Server: `getResult(pool, account, orderID): Promise<OrderState>`

Eine Anweisung (`orders` LEFT JOIN `order_results`, Filter `account_id = $1` und `id = $2::uuid`). Die Kennung wird ohne Rücksicht auf Groß-/Kleinschreibung gelesen; ist sie keine UUID, ist der Stand `unknown` (kein Fehler, keine Ausnahme aus Postgres). Vier Zustände:

- `{ state: "unknown" }`: keine Zeile, **oder der Auftrag gehört einem anderen Konto** (gleiche Antwort, nichts verrät, dass es ihn gibt).
- `{ state: "waiting" }`: Auftrag da, `claimed_by` leer („wartet auf ein Gerät“).
- `{ state: "claimed" }`: vergeben, noch kein Ergebnis („bei einem Gerät“).
- `{ state: "result", result: <doc> }`: das Ergebnisdokument unverändert.

Ergebnis ohne Vergabe kann es nicht geben (Fremdschlüssel plus `putResult`); die Reihenfolge der Prüfung ist trotzdem Ergebnis, dann Vergabe, dann Warten.

### Server: `capture_task` und `get_order_result` in `mcpHandler`

Beide wie C4a: je Anfrage eine frische Server-Instanz, Konto nur aus `authInfo` (fehlt es: `isError: true`, Text „kein Konto“, **vor** jedem Lesen oder Schreiben), Fehler als `isError` mit kurzem deutschem Text, nie als Ausnahme.

- **`capture_task`:** Eingabe `text` (Zod nur `z.string()`: ein Schemafehler käme als JSON-RPC-Fehler ohne `isError`; die Leere-Prüfung macht deshalb das Werkzeug selbst nach der Kontoprüfung: ein Text, der nach `trim()` leer ist, wird mit `isError` und dem Text „Text fehlt“ abgelehnt, ohne `putOrder`). Der Dienst bildet `{ version: 1, id: <crypto.randomUUID() in Großbuchstaben>, kind: "capture", text }` und ruft `putOrder`. Antwort: JSON `{ "orderID": "<Kennung>", "state": "waiting" }`. Verletzt der Auftrag die Form (z. B. ein NUL-Zeichen im Text), antwortet das Werkzeug mit `isError` und der Meldung von `checkOrder` (die Werkzeuge erfinden keine zweite Prüfung). Jeder Aufruf erzeugt einen neuen Auftrag (zwei Aufrufe, zwei Aufträge). Annotationen: `readOnlyHint: false`, `destructiveHint: false` (alles läuft über Revisionen), `idempotentHint: false`. Die Beschreibung sagt, dass die Aufgabe auf einem Gerät erfasst wird, sobald eines den Auftrag abholt, und verweist auf `get_order_result`.
- **`get_order_result`:** Eingabe `orderID` (Text). Antwort je Zustand von `getResult` als JSON-Text: `{ "state": "unknown" }`, `{ "state": "waiting" }`, `{ "state": "claimed" }`, `{ "state": "result", "result": { … } }`. Annotation `readOnlyHint: true`. Ausgegeben wird nur das Ergebnisdokument, kein Auftragstext.
- **Datenschutz:** der Auftragstext und die Kennungen gehen in keine Log-Zeile.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/migrations/001_claude_schema.sql` | Tabellen `orders`, `order_results`, **unverändert** |
| `server/src/orders.ts` (`putOrder`, `claimOrder`, `putResult`, `checkOrder`) | bestehend, im Test zum Vergeben und Melden |
| `server/src/mcp.ts`, `server/test/mcp.test.ts` (C4a) | Muster: `Client` + `StreamableHTTPClientTransport` mit `fetch: handler.fetch`, `authInfo` je Anfrage |
| `server/test/db.ts` (`freshPool`), `server/src/migrate.ts` | Testaufbau: eigenes Schema je Test gegen echtes Postgres |
| `@modelcontextprotocol/server` 2.4.0, `zod` 4.6.7, `node:crypto` | bestehend, **keine neuen Pakete** |

## Acceptance Criteria

Die Tests zu `getResult` liegen in `server/test/orders.test.ts`, die zu den Werkzeugen in `server/test/mcp.test.ts` (im Prozess, kein Port, echtes Postgres).

- **AC-1:** `getResult` liefert `unknown` für eine nie angelegte Kennung, für eine Kennung eines **anderen Kontos** (gleiche Antwort wie nie angelegt) und für einen Text, der keine UUID ist (keine Ausnahme).
- **AC-2:** `getResult` liefert `waiting` für einen angelegten, nicht vergebenen Auftrag (auch mit der Kennung in Kleinbuchstaben angefragt), `claimed` nach `claimOrder`, und `result` mit dem Ergebnisdokument gleich dem übergebenen nach `putResult` (`done` und `rejected` mit Grund).
- **AC-3:** `tools/list` nennt genau `capture_task`, `get_order_result`, `get_now`, `list_tasks` (sortierte Namensliste); `capture_task` trägt `readOnlyHint` falsch, `destructiveHint` falsch, `idempotentHint` falsch; `get_order_result` trägt `readOnlyHint` wahr.
- **AC-4:** Ohne `authInfo` lehnen `capture_task` und `get_order_result` ab (`isError`, Text „kein Konto“); der abgelehnte Aufruf von `capture_task` legt **keinen** Auftrag an (Zeilenzahl in `orders` vorher gleich nachher).
- **AC-5:** `capture_task` mit `text` legt genau einen Auftrag für das Konto an: die Antwort trägt eine `orderID` in Großbuchstaben (UUID-Form) und `state` „waiting“; die Zeile in `orders` hat `kind` `capture`, den Text unverändert, das Konto aus `authInfo` und `claimed_by` leer; `checkOrder` nimmt das Dokument an.
- **AC-6:** Zwei Aufrufe mit demselben Text erzeugen zwei Aufträge mit verschiedenen Kennungen.
- **AC-7:** Ein leerer oder nur aus Leerraum bestehender Text legt keinen Auftrag an und antwortet mit `isError` und dem Text „Text fehlt“; ein Text mit ungültigem Zeichen (z. B. NUL `\u0000`, ungepaartes Surrogat) legt keinen an und antwortet mit `isError` und der Meldung von `checkOrder`. Eine Längengrenze gibt es in der Formprüfung nicht und wird hier nicht eingeführt.
- **AC-8:** `get_order_result` gibt für einen mit `capture_task` angelegten Auftrag `waiting`, nach `claimOrder` `claimed`, nach `putResult` `result` mit dem Dokument; für eine unbekannte oder fremde Kennung `unknown` ohne `isError`; der Text eines Auftrags erscheint in keiner Antwort.
- **AC-9:** Ein anderes Konto sieht den Auftrag und sein Ergebnis nicht: dieselbe Kennung ergibt für `anna` `unknown`, nie `waiting` oder ein Ergebnis von `henning`.
- **AC-10:** Weder `capture_task` noch `get_order_result` schreibt etwas nach `console`/`stdout` (überwacht wie in C4a).
- **AC-11:** `npm run typecheck` ist grün; `./server/scripts/test-local.sh` ist grün (alle bestehenden Tests unverändert) und räumt auf; der Workflow `server.yml` ist auf dem PR grün.
- **AC-12:** Die Dateiliste des PR enthält außer den vier Dateien aus „Source“ und `CLAUDE.md` nichts, ausgenommen `docs/specs/`, `docs/context/`, `docs/briefings/`. `server/migrations/`, `server/package.json`, `project.yml` und jede Swift-Datei bleiben unberührt. `CLAUDE.md` bekommt in der `server/`-Zeile den Zusatz `capture_task`, `get_order_result` (`getResult`).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/orders.ts` | MODIFY | `getResult`, eine Anweisung, ~+20 |
| `server/src/mcp.ts` | MODIFY | `capture_task`, `get_order_result`, ~+40 |
| `server/test/orders.test.ts` | MODIFY | `getResult`: Zustände, Konto-Zaun, ~+45 |
| `server/test/mcp.test.ts` | MODIFY | beide Werkzeuge über den Prozess-Client, ~+75 |
| `CLAUDE.md` | MODIFY | Zusatz in der `server/`-Zeile, ~+1 |

### Estimated Changes

- Files: 5 (innerhalb von 4–5)
- LoC: ≈ +180/−0 (Code ≈ 60, Tests ≈ 120). Reserve ≈ 70 Zeilen unter 250. Zeichnet sich eine Überschreitung ab, wird gestoppt und nachgefragt. Jede Funktion ≤ 50 Zeilen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Migration, keine neuen Pakete, kein `generate`. Seiteneffekt außerhalb des Tickets: keiner; nichts in der App ruft den Dienst auf.

## Test Plan

### Automated Tests (TDD RED)

RED: Die Tests werden zuerst geschrieben; `getResult` und die zwei Werkzeuge fehlen, die Aufrufe schlagen fehl.

- [ ] Test 1 (AC-1): GIVEN ein Auftrag von `henning` WHEN `getResult` für unbekannt, fremdes Konto, Nicht-UUID THEN je `unknown`, keine Ausnahme.
- [ ] Test 2 (AC-2): GIVEN ein Auftrag WHEN angelegt, vergeben, mit Ergebnis (`done`, `rejected`+Grund) THEN `waiting` (auch Kleinbuchstaben), `claimed`, `result` mit Dokument.
- [ ] Test 3 (AC-3): GIVEN der Handler WHEN `tools/list` THEN vier Namen und die Annotationen.
- [ ] Test 4 (AC-4): GIVEN kein `authInfo` WHEN beide Werkzeuge THEN „kein Konto“, `orders` unverändert.
- [ ] Test 5 (AC-5, AC-6): GIVEN Konto `henning` WHEN `capture_task` (zweimal) THEN Zeilen und Kennungen wie beschrieben.
- [ ] Test 6 (AC-7): GIVEN leerer Text, nur Leerzeichen und Text mit NUL-Zeichen WHEN `capture_task` THEN `isError`, kein Auftrag.
- [ ] Test 7 (AC-8, AC-9): GIVEN ein Auftrag WHEN `get_order_result` durch die Zustände, danach als `anna` THEN die Zustände, dann `unknown`.
- [ ] Test 8 (AC-10): GIVEN beide Werkzeuge WHEN aufgerufen THEN keine Ausgabe auf `console`/`stdout`.
- [ ] Prüfung AC-11/AC-12: `./server/scripts/test-local.sh` grün; Dateiliste des PR; Workflow `server.yml` grün.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **Ein Sammelwerkzeug `create_order(kind, …)`:** weniger Code, aber Claude müsste Kennung und erwarteten Stand selbst liefern. Verworfen; kippt die C4a-Entscheidung „Kennung vom Dienst“.
- **Kein `get_order_result`, Ergebnis nur über die nächste Abschrift:** spart ein Werkzeug, aber Claude erführe nie, warum ein Auftrag abgelehnt wurde. Verworfen; kippt den Vertrag (jeder Auftrag bekommt ein Ergebnis).
- **Vorschlag statt Auftrag** (Claude schlägt vor, Henning bestätigt in der App): kein Schreibweg nötig, aber kippt „Aufträge als Nutzeränderung“ aus Weg B. Nicht gewählt, der Vertrag steht.
- **Fremde Kennung mit eigenem Fehler „nicht deins“:** hilfreicher für Claude, verrät aber, dass es den Auftrag gibt. Verworfen, gleiche Antwort wie unbekannt.

## Nicht in diesem Schnitt / Folgeschnitte

- **C4b-2:** `complete_task` und `set_due` mit erwartetem Stand (`status`, `dueDate`) aus der Abschrift; eigene Spec.
- C6 Anmeldung, C7 Betrieb, C8 ADR-21; ein Gerätekanal (Abholen in der App) ist offen, bis dahin bleiben Aufträge „wartet auf ein Gerät“.

## Abnahme

- Stufe 1: `./server/scripts/test-local.sh` grün; `server.yml` grün auf dem PR.
- Stufe 2: Pflicht für den Abschluss. `./scripts/sim.sh test-proof CaptureSmokeTests` liefert den maschinellen Beleg aus einem echten Lauf auf dem aktuellen Stand; er zeigt nur, dass die App auf dem Stand startet und erfasst, ein Bedienablauf für die Werkzeuge existiert nicht.
- Stufe 3: entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #613 kommentiert (Stand C4b-1, Folge C4b-2), Board-Karte aktuell

## Changelog

- 2026-11-02: Initial spec created (Schnitt C4b-1)
