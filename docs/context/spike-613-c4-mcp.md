# Context: spike-613-c4-mcp (#613 Schnitt C4, MCP-Werkzeuge)

## Request Summary
Der Dienst in `server/` nimmt seit C3a/C3b Abschrift, Aufträge und Ergebnisse an, aber niemand kann sie lesen oder anlegen.
C4 macht sie für Claude als MCP-Werkzeuge erreichbar (geplant: `get_now`, `list_tasks`, `create_order`, dazu das Lesen der
Ergebnisse), noch ohne Anmeldung und ohne Konto (C6) und ohne Betrieb auf Hetzner (C7).

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/transcripts.ts` | `checkTranscript`, `putTranscript`; Prüfbausteine (`shape`, `id`, `time` …). Es gibt **kein Lesen** der Abschrift |
| `server/src/orders.ts` | `checkOrder`, `putOrder` (gespeichert/doppelt), `claimOrder`, `checkResult`, `putResult`. Es gibt **kein Lesen** der Ergebnisse |
| `server/migrations/001_claude_schema.sql` | Tabellen `transcripts` (eine je `account_id`), `orders`, `order_results` (Schlüssel `order_id`, `outcome`, `reason`, `task_id`) |
| `server/test/db.ts` | `freshPool(t)`: ein eigenes Schema je Test gegen echtes Postgres |
| `server/test/*.test.ts` | Muster: `node:test`, ein `t.test` je Tabellenzeile (Pflicht aus C1b) |
| `server/package.json`, `tsconfig.json` | Node 26 mit Type-Stripping, ohne Build-Schritt; Abhängigkeiten nur `pg`; `erasableSyntaxOnly` |
| `server/scripts/test-local.sh`, `.github/workflows/server.yml` | Prüfkette lokal und in der CI (Postgres 18) |
| `docs/reference/claude-abschrift-vertrag.md` | Vertrag v1: Abschrift, Auftrag, Ergebnis. Die Werkzeuge reichen genau diese Formen durch |
| `docs/specs/spike-613-schnitt-1-abschrift-auftraege.md` | Liste der Folgeschnitte: „C4 MCP-Werkzeuge `get_now`, `list_tasks`, `create_order`“ |
| `docs/specs/spike-613-schnitt-c3b-auftraege.md` | Abgrenzung: Lesen der Ergebnisse durch Claude und Anlegen der Aufträge über Werkzeuge = C4; kein HTTP, keine Anmeldung bis C6 |

## Existing Patterns
- Jede Schreibfunktion ist eine einzige SQL-Anweisung, sie prüft vorher die Form (`check*`) und gibt einen kleinen Status-Text zurück (`stored`/`duplicate`/`older`/`refused`).
- Formfehler sind `Error("<Gegenstand> ungültig: <Pfad>: <Grund>")`, deutsch, mit Feldpfad.
- `account_id` und `device` sind übergebene Texte, bis C6 ein Konto liefert.
- Tests laufen nur gegen echtes Postgres; ohne `DATABASE_URL` schlagen sie fehl, statt übersprungen zu werden.
- Kommentare englisch, knapp, nur wo eine Regel steht.

## Recherche (2026-11-01)
- Die aktuelle MCP-Revision ist **2026-07-28**, zustandslos: Es gibt keinen `initialize`-Handshake und kein `Mcp-Session-Id` mehr, Version und Fähigkeiten stehen in `_meta`. Bei Streamable HTTP entfällt GET, dazu kommen die Kopfzeilen `Mcp-Method`/`Mcp-Name`. Quellen: https://blog.modelcontextprotocol.io/posts/2026-07-28/, https://developers.googleblog.com/scaling-ai-agent-infrastructure-with-the-mcp-stateless-updates/
- TypeScript-SDK v2 ist die stabile Linie (v1 nur Wartung bis 2025-11-25). Pakete: `@modelcontextprotocol/server` 2.4.0 (hängt an `zod ^4.2`, Node ≥ 20), `@modelcontextprotocol/node` 2.1.2 (`toNodeHandler`, zieht `hono`), `@modelcontextprotocol/client` für Tests. Quellen: https://ts.sdk.modelcontextprotocol.io/v2/, npm.
- `createMcpHandler(factory)` baut je Anfrage eine frische Server-Instanz und ist von Haus aus zustandslos. Clients der 2025er-Generation bedient derselbe Handler ebenfalls. Werkzeuge lesen die Anmeldung als `ctx.http.authInfo`. `authInfo` wird nur durchgereicht, der Handler prüft keinen Token (das ist Sache von C6). Quelle: https://ts.sdk.modelcontextprotocol.io/v2/serving/http.html
- Tests im Prozess: `StreamableHTTPClientTransport` mit `fetch: handler.fetch`, ohne Port. `InMemoryTransport` kann nur die 2025er-Revision. Werkzeugfehler kommen als `isError: true` zurück, nicht als Ausnahme. Quelle: https://ts.sdk.modelcontextprotocol.io/v2/testing.html

## Dependencies
- Upstream: `pg`, dazu neu (Freigabe nötig: „keine neuen Dependencies ohne Freigabe“). Weg B hat Henning am 2026-10-31 als „TypeScript-Dienst mit MCP-SDK“ beschrieben: `@modelcontextprotocol/server`, `zod`, eventuell `@modelcontextprotocol/node` (+ `hono`), `@modelcontextprotocol/client` (nur Test).
- Downstream: noch niemand. Claude verbindet sich erst mit C6/C7 (Anmeldung, öffentliche Adresse), #621 baut darauf den Connector.

## Existing Specs
- `docs/specs/spike-613-schnitt-c3a-abschrift-annehmen.md`, `docs/specs/spike-613-schnitt-c3b-auftraege.md`, `docs/specs/spike-613-schnitt-c1b-schema.md`

## Risks & Considerations
- Neue Dependencies (SDK, zod, gegebenenfalls hono). Die Alternative ohne SDK, also JSON-RPC von Hand, wäre ein eigenes Protokoll-Nachbauen. Die Memory-Regel „nie eigenen OAuth bauen“ betrifft nur die Anmeldung, Protokollcode von Hand bleibt trotzdem riskant.
- Typen: Type-Stripping mit `erasableSyntaxOnly`. Das SDK liefert JS + `.d.ts`, das sollte gehen und wird im RED-Lauf belegt.
- Ohne Anmeldung darf der Dienst nicht öffentlich laufen. In C4 gibt es nur den Handler (Tests im Prozess) bzw. Loopback, keinen offenen Port. Das Konto kommt als fester Wert aus `authInfo`, sonst wird abgelehnt.
- Werkzeug-Eingaben mit zod-Schemas doppeln womöglich die `check*`-Prüfung. Eine Quelle der Wahrheit bleibt `checkOrder`.
- `create_order`: Wer erzeugt die `id` (Claude oder der Dienst)? Wer übernimmt `expectedStatus`/`expectedDueDate` aus der Abschrift? Das ist eine Designfrage für die Analyse.
- Datenschutz: Die Werkzeuge geben nur heraus, was in der Abschrift steht (kein Rohtext, keine Notiz). Protokolle ohne Inhalte.
- Umfang: Die Schnitte C1a–C3a lagen 30–65 Zeilen über 250, jeweils wegen der Tests. Für C4 deshalb Tests mit ≈ 1,5× Code schätzen und die Überschreitung schon bei der Spec-Freigabe nennen.
- Abnahme: Kein App-Pfad wird berührt, Stufe 3 entfällt. phase8 braucht trotzdem `sim.sh test-proof` (CaptureSmokeTests), siehe Memory.

## Analysis

### Type
Feature (Spike-Schnitt C4 von #613; kein App-Pfad, nur `server/`)

### Prüfung der Recherche (2026-11-01, `npm view`)
- `@modelcontextprotocol/server` 2.4.0: Abhängigkeiten `zod ^4.2.0`, `@modelcontextprotocol/core` 2.4.0, Node ≥ 20. Bestätigt.
- `@modelcontextprotocol/node` 2.1.2 zieht `hono` + `@hono/node-server`: wird nur für einen echten Port gebraucht (`toNodeHandler`
  samt `localhostHostValidation`) → **nicht in C4**, erst mit C7 (Betrieb). C4 hat keinen Port.
- `@modelcontextprotocol/client` 2.4.0 (zieht `jose`, `eventsource`, `pkce-challenge`, `cross-spawn`): nur `devDependencies`, Tests.
- `zod` 4.6.7 aktuell; direkt als Abhängigkeit, weil `mcp.ts` es importiert (Paket 2.4.0 verlangt `^4.2`).
- Freigabe der Abhängigkeiten: Henning beschrieb Weg B am 2026-10-31 als „TypeScript-Dienst mit MCP-SDK“ (Memory
  `loose-ends-612-weg-b-fenster-fuer-claude`). Das deckt SDK + zod; `hono` kommt erst mit C7 und wird dort genannt.
- `createMcpHandler(factory)` baut je Anfrage einen frischen `McpServer`; `handler.fetch(request, { authInfo })` ist web-standard,
  Werkzeuge lesen `ctx.http.authInfo`. Quelle: https://ts.sdk.modelcontextprotocol.io/v2/serving/http.html

### Entwurfsentscheidungen (Tech Lead)
1. **Werkzeuge je Art statt eines `create_order`:** `capture_task(text)`, `complete_task(taskID)`, `set_due(taskID, date?, hasTime)`.
   Ein Modell trifft drei benannte Werkzeuge mit je 1–3 Feldern sicherer als ein Sammelwerkzeug mit `kind`-Weiche.
   Lesen: `get_now` (Zahl + Zeilen von „Jetzt“ mit Titel, Fälligkeit, Knäuel), `list_tasks` (alle Aufgaben der Abschrift),
   `get_order_result(orderID)` (`pending` / `done` / `rejected` + `reason`).
2. **Die Kennung des Auftrags vergibt der Dienst** (`crypto.randomUUID()`, großgeschrieben wie in der App) und gibt sie zurück.
   Claude muss keine UUID erfinden; ein Wiederholungsaufruf legt allerdings einen zweiten Auftrag an (MCP wiederholt nicht selbst).
3. **Der erwartete Stand kommt aus der gespeicherten Abschrift**, nicht von Claude: `complete_task` übernimmt `status` und `dueDate`,
   `set_due` übernimmt `dueDate` der Aufgabe. Fehlt die Aufgabe in der Abschrift, lehnt das Werkzeug ab (`isError`), es entsteht kein
   Auftrag. Der Auftrag läuft danach weiter durch `checkOrder`/`putOrder` — eine Quelle der Wahrheit für die Form.
4. **Konto nur aus `authInfo`:** fehlt es, lehnt jedes Werkzeug ab. Bis C6 setzt nur der Test den Wert; einen offenen Port gibt es nicht.
5. **Ausgabe:** JSON-Text in `content` (Felder wie im Vertrag). Kein Rohtext, keine Notiz — die Abschrift trägt beides nicht.
6. **Zod nur für die Werkzeug-Eingaben** (das SDK verlangt ein Schema, damit Claude die Felder sieht); die Prüfung des fertigen
   Auftrags bleibt `checkOrder`.

### Scope Assessment und Schnitt
Gesamtschätzung C4: Code ≈ 170, Tests ≈ 1,5× ≈ 250 → ≈ 420 Zeilen, deutlich über 250. Deshalb **zwei Schnitte**:

| Schnitt | Inhalt | Code | Tests | Summe |
|---|---|---|---|---|
| **C4a** | Abhängigkeiten, Handler `createMcpHandler`, Konto aus `authInfo`, `getTranscript`, `get_now`, `list_tasks` | ≈ 75 | ≈ 115 | ≈ 190 |
| **C4b** | `capture_task`, `complete_task`, `set_due` (erwarteter Stand aus Abschrift), `getResult`, `get_order_result` | ≈ 95 | ≈ 140 | ≈ 235 |

Dieser Workflow baut **C4a**; C4b folgt als eigener Workflow.

### Affected Files (C4a)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/transcripts.ts` | MODIFY | `getTranscript(pool, account)`: die gespeicherte Abschrift oder `undefined` (eine Anweisung) |
| `server/src/mcp.ts` | CREATE | `mcpHandler(pool)`: Handler mit `get_now`, `list_tasks`; Konto aus `authInfo`, sonst Ablehnung |
| `server/test/mcp.test.ts` | CREATE | Client im Prozess (`StreamableHTTPClientTransport`, `fetch: handler.fetch`) gegen echtes Postgres |
| `server/package.json` (+ `package-lock.json`) | MODIFY | `@modelcontextprotocol/server`, `zod`; dev `@modelcontextprotocol/client` (Versionen fest) |
| `CLAUDE.md` | MODIFY | eine Zeile unter `server/`: MCP-Handler, noch ohne Port und Anmeldung |

- Files: 5 (Lockfile generiert, zählt nicht)
- Estimated LoC: ≈ +190/−0
- Risk Level: LOW — nur `server/`, kein Aufrufer im Produkt, kein Port, keine App-Datei

### Technical Approach (C4a)
- `get_now`: liest die Abschrift, gibt `nowCount` und die Zeilen in der Reihenfolge `knaeuel`, `today`, `lined`, `waiting` zurück,
  je Zeile die Aufgabe aus `tasks` (Kennung, Titel, Fälligkeit, Status, Knäuel). Die Zahl wird **nicht** neu gezählt (#637: eine Zahl
  überall — es ist `nowCount` der App). Keine Abschrift → Text „noch keine Abschrift“, kein Fehler.
- `list_tasks`: alle `tasks` der Abschrift, Reihenfolge wie geliefert, plus `generatedAt`, damit Claude das Alter sieht.
- Tests (je Zeile ein `t.test`): ohne `authInfo` abgelehnt; anderes Konto sieht fremde Abschrift nicht; ohne Abschrift; mit der
  Vertrags-Beispielabschrift (aus `docs/reference/claude-abschrift-vertrag.md` gelesen, wie `schema.test.ts`) kommen Zahl, Reihenfolge und
  Felder genau so heraus; `tools/list` nennt genau die zwei Werkzeuge; Typprüfung `tsc` mit SDK-Typen unter `erasableSyntaxOnly`.

### Befunde gegen den Plan
- **Abschrift-Vorrat statt Live-Stand:** Claude sieht den Stand des letzten Hochladens, nicht des Geräts. Das ist Weg B selbst (bewusst);
  `generatedAt` in der Ausgabe macht das Alter sichtbar. Kein Grund, den Plan zu ändern.
- **SDK-Gewicht:** client zieht `jose`, `cross-spawn` u. a. — nur als devDependency, nicht im laufenden Dienst.
- **Erwarteter Stand aus der Abschrift (C4b):** übernimmt der Dienst ihn aus einer inzwischen *neueren* Abschrift als der, die Claude
  gelesen hat, prüft das Gerät gegen einen Stand, den Claude nie sah. Das Gerät lehnt trotzdem ab, wenn er nicht stimmt; Schaden
  entsteht nicht. Wird in C4b entschieden und im Test belegt.

### Alternativen
- **Ohne SDK, JSON-RPC von Hand:** keine neuen Abhängigkeiten, aber eigenes Nachbauen der Protokollrevision 2026-07-28 (zustandslos,
  `_meta`, `Mcp-Method`-Kopfzeilen) samt Rückwärtsweg für 2025er-Clients. Verworfen: Protokollcode ist genau das, was man kauft.
- **Ein Sammelwerkzeug `create_order` mit dem Vertragsauftrag als Eingabe** (wie im Schnitt-1-Plan genannt): reicht die Form 1:1
  durch, Claude müsste aber `id`, `expectedStatus`, `expectedDueDate` selbst setzen. Verworfen für C4b, gekippt wird nur der Name aus
  der Folgeschnitt-Liste in `spike-613-schnitt-1-abschrift-auftraege.md` (keine ADR).
- **Supabase-MCP statt eigenem Dienst:** Rückfall laut Memory nur für OAuth, nicht für die Werkzeuge.

### Dependencies
- Upstream: `pg` (vorhanden), `@modelcontextprotocol/server` 2.4.0, `zod` 4.6.7; dev `@modelcontextprotocol/client` 2.4.0.
- Downstream: niemand. C4b baut auf dem Handler auf; C6 liefert `authInfo` aus echter Anmeldung; C7 hängt den Handler an einen Port
  (`@modelcontextprotocol/node`); #621 verbindet Claude.

### Open Questions
- keine an Henning (alles Technik). Die Aufteilung in C4a/C4b bleibt unter den 250 Zeilen je Schnitt.

### Abnahme
Kein Pfad der Geräteliste berührt. phase8 braucht `sim.sh test-proof CaptureSmokeTests` (Memory `loose-ends-613-s1-gemergt`).
