# Context: feat-624-s2-client

## Request Summary
#624 Schnitt 2: Das Fenster zu `get_view` wird lebendig. Statt des Platzhalters aus Schnitt 1 zeigt es die Ansicht der App
(now, due, next, open) in Gestalt A (Papier der App, vom PO am 2026-11-16 freigegeben) mit zwei Knöpfen je Zeile: abhaken
(`complete_task`) und „Als nächstes“ (`set_next`), mit Warte- und Ergebniszustand (`get_order_result`); danach Ausrollen auf
`rennwienix` und erste Sichtprüfung in claude.ai. Detail, Fehlerfälle, Bilder ins Ticket und Claude Desktop sind Schnitt 3.

Grundlage: `docs/context/feat-624-mcp-app.md` (Recherche, Analyse, Entwurf, PO-Entscheide) und
`docs/specs/feat-624-schnitt-1-ressource.md` (gemergt PR #940, nicht ausgerollt). Entwurf: `docs/artifacts/feat-624-mcp-app/entwurf.html`.

## Stand nach Schnitt 1 (origin/main 84d5f0c)
- `server/src/app-ui.ts`: `UI_URI`, `UI_MIME`, `viewHtml` (Platzhalter, CSS hell/dunkel, kein Skript).
- `server/src/mcp.ts`: `registerUi` (Ressource, ohne Konto), `get_view` mit `_meta.ui.resourceUri`; Textantwort unverändert:
  `{ view, generatedAt, nowCount? (nur now), count, rows }`; Zeile bei now: `{ id, title, dueDate?, dueHasTime, status, isKnaeuel,
  group: knaeuel|today|lined|waiting }`, sonst `summary`: `{ id, title, status, dueHasTime, isKnaeuel, contexts, dueDate?, project?, nextRank? }`.
- `complete_task(taskID, generatedAt)`, `set_next(taskID, generatedAt, on)` → Text `{ orderID, state: "waiting" }` oder `isError`
  mit Klartext (`stale`-artige Meldungen aus `expected`); `get_order_result(orderID)` → `unknown | waiting | claimed | result`.
- Kein `structuredContent` an `get_view`; das Fenster liest das JSON aus `content[0].text` (Host reicht den `CallToolResult` durch).

## Protokoll (Recherche 2026-11-16, zweite Runde)
Quellen: Spec https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx, Typen aus dem
Paket `@modelcontextprotocol/ext-apps@2.1.0` (`dist/src/spec.types.d.ts`, nur gelesen, nicht installiert).
- Transport: JSON-RPC 2.0 über `window.parent.postMessage(msg, "*")`; Antworten kommen als `message`-Ereignis von `window.parent`.
- Handshake: View → `ui/initialize` mit `{ protocolVersion: "2026-01-26", appInfo: { name, version }, appCapabilities: {} }`
  (die Spec-Prosa und das SDK nennen `appInfo`/`appCapabilities`; das Spec-Beispiel `clientInfo`/`capabilities` ist veraltet);
  Ergebnis `{ protocolVersion, hostInfo, hostCapabilities, hostContext }`; danach View → `ui/notifications/initialized`.
  Der Host sendet vorher nichts.
- Danach Host → `ui/notifications/tool-input` (`{ arguments }`, höchstens einmal) und `ui/notifications/tool-result`
  (`CallToolResult`); `ui/notifications/tool-cancelled`; `ui/notifications/host-context-changed` (Teilmenge, zusammenführen);
  Request `ui/resource-teardown` (Antwort `{}`).
- `hostContext`: `theme` light|dark, `styles.variables` (`--color-*`, `--font-*`, …), `displayMode`, `containerDimensions`,
  `safeAreaInsets`, `locale`, `timeZone`.
- View → `tools/call` (Standard-MCP) auf Werkzeuge desselben Servers; Sichtbarkeit Standard `["model","app"]`, also für
  `complete_task`, `set_next`, `get_order_result` ohne Änderung erlaubt. View → `ui/notifications/size-changed` `{ width, height }`.
- Externe Quellen gesperrt (kein `_meta.ui.csp`) → Skript inline im HTML.

## Related Files
| File | Relevance |
|------|-----------|
| server/src/app-ui.ts | wird ersetzt: HTML + CSS der Gestalt A + Client-Skript inline |
| server/src/mcp.ts | `get_view` (Antwortform), `complete_task`, `set_next`, `get_order_result`; voraussichtlich keine Änderung |
| server/test/mcp-app.test.ts | S1-Tests: „kein `<script>`“ und „keine externe Quelle“ — der erste muss in S2 fallen bzw. umgeschrieben werden |
| server/test/mcp-read.test.ts, mcp-write.test.ts | Muster für Handler-Tests |
| docs/artifacts/feat-624-mcp-app/entwurf.html | freigegebene Gestalt A: Farben, Zeilenaufbau, Zustände (gestrichelter Kreis „wartet auf dein Gerät“, grüner Haken) |
| docs/reference/claude-abschrift-vertrag.md | Felder der Abschrift |
| LooseEnds/Views/ (Paper, StartZones) | Farbwerte der App (Papier, Tinte, Akzent, Rot für Zeitdruck, Grün für den Abschluss) |
| server/package.json | Testlauf `node --test`; keine DOM-Bibliothek vorhanden |

## Existing Patterns
- Dienst ohne Build-Schritt (Node 26 type stripping); HTML als Template-String in TS.
- Tests über `./server/scripts/test-local.sh` (`node:test`, Wegwerf-Postgres).
- Änderungen erst nach `get_order_result` als ausgeführt melden (Anleitung an Claude) — das Fenster folgt derselben Regel.
- Knäuel/Perle nur anzeigen, nie anbieten (Regel #648); beim Knäuel ist „Als nächstes“ ausgegraut (Entwurf).

## Dependencies
- Upstream: Abschrift mit `views` (#621 S5), Aufträge (#622), Weckruf im Dienst live (#795 S5b); der App-Teil des Weckrufs
  (#795 S5c-2) fehlt noch → ein Haken bleibt „wartet auf dein Gerät“, bis die App das nächste Mal aktiv wird.
- Downstream: claude.ai-Connector auf dem Live-Dienst; Ausrollen über `scripts/deploy-loose-ends.sh` (henemm-infra) mit `LE_COMMIT`.
- PR #937 (#932 S3) offen, ändert `mcp.ts` (`registerOrders`); S2 fasst `mcp.ts` voraussichtlich nicht an.

## Risks & Considerations
- Testbarkeit des Skripts ohne Browser: keine DOM-Bibliothek; Weg: Logik (Zeilen → HTML-String, Zustandsübergänge,
  Nachrichtenfolge) als reine Funktionen, die der Test aus dem Skripttext lädt (`new Function`/`vm`) und mit einem Fake-Host prüft.
- Handshake nur aus Spec/SDK bekannt, erst am echten Host prüfbar → nach dem Merge sofort ausrollen und in claude.ai ansehen
  (Chrome, Hennings Anmeldung besteht). Rückfall: SDK `ext-apps` 2.x (neue Abhängigkeit, PO-Freigabe nötig).
- Ausrollen macht das Fenster für jeden `get_view` in claude.ai sichtbar; ein kaputtes Fenster stört den Alltag → Rückweg:
  vorheriger `LE_COMMIT`.
- HTML-Escaping der Titel (Nutzertext) Pflicht; keine `innerHTML` mit Rohtext.
- Abfrage `get_order_result` begrenzen (z. B. alle 3 s, höchstens 1 min), dann ruhige Zeile statt Endlosschleife.
- Umfang: HTML/CSS + Client + Tests wahrscheinlich über ±250 LoC → in der Analyse teilen (z. B. S2a Anzeige ohne Knöpfe +
  Ausrollen + Sichtprüfung, S2b Abhaken/Als nächstes).
- Gestaltungsregeln von Claude: inline ohne eigenes Scrollen, Tippziele ≥ 44 pt; hell/dunkel aus `hostContext.theme`
  (nicht nur `prefers-color-scheme`).

## Analysis

### Type
Feature (sichtbare UI im Chat-Host; Entwurf A am 2026-11-16 vom PO freigegeben, alle vier Ansichten)

### Befunde der Analyse (2026-11-16)
- **Abschrift veraltet nach dem ersten Ergebnis.** `expected()` in `mcp.ts` lehnt jeden Auftrag ab, dessen `generatedAt` nicht
  mehr der gespeicherten Abschrift entspricht („Abschrift hat sich geändert, bitte neu lesen“). Sobald das Gerät einen Auftrag
  ausführt, schickt die App eine neue Abschrift (`ClaudeSyncTrigger`: jedes Speichern sendet). Ohne Gegenmaßnahme scheitert
  im Fenster der zweite Tipp nach dem ersten Ergebnis. Folge: Nach jedem `result` (und bei dieser Ablehnung) ruft das Fenster
  `get_view` mit derselben Ansicht erneut per `tools/call` auf und zeichnet neu; nur bei einer echten Ablehnung zeigt es eine
  ruhige Zeile. Mehrere Tipps hintereinander, bevor das Gerät etwas übernommen hat, gehen (Abschrift unverändert).
- **Ergebnisform:** `get_order_result` → `{ state: unknown|waiting|claimed|result, result? }`, `result.outcome` = `done` | `rejected`
  (+ `reason`). `claimed` = Gerät hat übernommen, noch kein Ergebnis → weiter „wartet …“.
- **Zeilen von „Jetzt“ tragen keine Etiketten** (`nowRows`: id, title, dueDate, dueHasTime, status, isKnaeuel, group). Der Entwurf
  zeigt „Telefon“ unter einer Jetzt-Zeile. Die anderen drei Ansichten (`summary`) tragen `contexts`, `project`, `nextRank`.
  Entscheidung (technisch): S2a zeigt nur, was die Zeile trägt; `contexts` kommt in S2b als zusätzliches Feld an die Jetzt-Zeilen
  (additiv, Text-Hosts unberührt), nach dem Merge von PR #937, der `mcp.ts` ebenfalls ändert.
- **Randmarke** aus der Abschrift ableitbar ohne eigene Logik: `group` (knaeuel → Knäuel-Zeichen, today → „Heute“ rot,
  lined → „Nächstes“, waiting → „Wartet“) in „Jetzt“; in den anderen Ansichten `dueDate` (heute/überfällig rot) bzw. nichts.
  Heute/überfällig nur über das Datum in `timeZone` des Host-Kontexts — Vergleich Tag gegen Tag, keine weitere Regel.
- **S1-Test AC-3** („kein `<script>`“) fällt mit S2 und wird ersetzt: genau ein inline-Skript, weiterhin kein `http://`, `https://`,
  `@import`, kein `src=`. Inline-SVG ohne `xmlns`-Attribut (das enthielte `http://`).
- **Testbarkeit ohne Browser und ohne neue Abhängigkeit:** Die Client-Logik als reine Funktionen in TS schreiben (`escape`,
  `rowsHtml(view, rows, today)`, `reduce(state, message)` → neuer Zustand + ausgehende Nachrichten), sie direkt aus dem Modul
  testen und per `Function.prototype.toString()` in das HTML einbetten (Node 26 type stripping ersetzt Typen durch Leerraum,
  der Text ist gültiges JS). Ein Test führt das eingebettete Skript mit `node:vm` gegen einen Fake-`window`/`document`/`parent`
  aus und prüft die Nachrichtenfolge `ui/initialize` → `ui/notifications/initialized`.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| server/src/app-ui.ts | MODIFY | Gestalt A (CSS hell/dunkel über `data-theme` aus `hostContext.theme`, Rückfall `prefers-color-scheme`), reine Client-Funktionen, inline eingebettet; S2b Knöpfe + Abfrage |
| server/test/mcp-app.test.ts | MODIFY | AC-3 umschreiben (ein inline-Skript, keine Fremdquelle) |
| server/test/app-client.test.ts | CREATE | Render (Escaping, Randmarken, vier Ansichten, leere Liste), Handshake per `vm` + Fake-Host, S2b Zustandsübergänge mit `mock.timers` |
| server/src/mcp.ts | MODIFY (nur S2b) | `contexts` an Jetzt-Zeilen, nach PR #937 |
| CLAUDE.md | MODIFY | Eintrag `src/app-ui.ts` nachführen |

### Scope Assessment
Ein Schnitt S2 läge bei ~400 LoC (HTML/CSS ~80, Client ~150, Tests ~170) → über der Grenze, daher zwei Teile:
- **S2a Anzeige** (~240 LoC, 4 Dateien): Handshake, Host-Kontext (Thema, Zeitzone), `tool-result` lesen, alle vier Ansichten in
  Gestalt A ohne Knöpfe, leere Liste, `size-changed`; danach **sofort ausrollen** und in claude.ai ansehen (hell und dunkel).
  Zweck: den Handshake am echten Host belegen, bevor die Knöpfe gebaut werden.
- **S2b Knöpfe** (~220 LoC, 4 Dateien): Abhaken und „Als nächstes“ (beim Knäuel ausgegraut; `on` = nicht bereits `nextRank`),
  Wartezustand (gestrichelter Kreis, „wartet auf dein Gerät …“), Abfrage alle 3 s höchstens 60 s, dann ruhige Zeile,
  nach `result` neu lesen; `contexts` an Jetzt-Zeilen; Ausrollen und Sichtprüfung mit einem echten Abhaken.
- Risk Level: MEDIUM — Handshake nur aus Spec/SDK bekannt; Ausrollen zeigt das Fenster bei jedem `get_view` in claude.ai
  (Rückweg: vorheriger `LE_COMMIT`); Text-Hosts unverändert (AC-5 aus S1 bleibt).

### Technical Approach
Weg A ohne Abhängigkeit (s. Tabelle in `feat-624-mcp-app.md`): Client von Hand per `postMessage`-JSON-RPC, Logik als reine
Funktionen mit Einbettung per `toString()`. Titel nur escaped in HTML. Knäuel/Perle nur angezeigt, nie angeboten.
Das Fenster meldet eine Änderung erst als ausgeführt, wenn `get_order_result` ein `result` liefert (wie die Anleitung an Claude).

**Alternativen:**
- B: SDK `@modelcontextprotocol/ext-apps` 2.1.0 (neue Abhängigkeit, 546 KB inline, PO-Freigabe) — Rückfall, falls der
  Handshake in S2a am echten Host scheitert. Keine ADR fällt.
- Ein Schnitt S2 ohne Teilung: spart einen Ausroll-Durchgang, sprengt aber die Grenze und baut die Knöpfe auf einen
  unbelegten Handshake.
- Status quo ohne Fenster (Claude antwortet in Text): funktioniert heute; das Fenster ist reine Zugabe.

### Dependencies
- PR #937 (#932 S3, ändert `mcp.ts`): S2a fasst `mcp.ts` nicht an; S2b nach dessen Merge.
- Ausrollen: `scripts/deploy-loose-ends.sh` (henemm-infra) mit `LE_COMMIT` per `ssh rennwienix bash -s`.
- Sichtprüfung: claude.ai im Chrome (Hennings Anmeldung besteht), Connector „Loose Ends“; kein Gerät von Henning beteiligt.
- Weckruf-App-Teil (#795 S5c-2) fehlt → in S2b kann „wartet auf dein Gerät“ bis zum nächsten App-Start stehen; die 60-s-Grenze
  und die ruhige Zeile fangen das ab.

### Open Questions
- [x] Gestalt A, alle vier Ansichten (PO 2026-11-16).
- Keine offene PO-Frage: Teilung S2a/S2b, Abfragetakt, Einbettung sind technische Entscheidungen.
