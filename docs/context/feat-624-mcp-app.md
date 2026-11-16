# Context: feat-624-mcp-app

## Request Summary
#624 (Epic #612): Claude zeigt eine Ansicht der App (z. B. „Jetzt“) als interaktive Liste im Chat (MCP App): abhaken,
als nächstes markieren, Detail öffnen. Papierstil und Farbbudget der App, hell und dunkel, Handybreite. Dieselben
Operationen wie #622 (Schnitt 2), keine eigene Logik. DoD: läuft in claude.ai und Claude Desktop, Bilder hell/dunkel im Ticket.

## Recherche (2026-11-16)
- MCP Apps = Erweiterung `io.modelcontextprotocol/ui` (SEP-1865, Spec 2026-01-26): Ressource `ui://…` mit MIME
  `text/html;profile=mcp-app`, Werkzeug verweist per `_meta.ui.resourceUri`; der Host rendert in einer Sandbox
  (iframe; mobil WKWebView). Quellen: https://claude.com/docs/connectors/building/mcp-apps/quickstart,
  https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx
- SDK `@modelcontextprotocol/ext-apps`: 1.x passt zu MCP-SDK 1.x, **2.x** (aktuell 2.1.0, Peer `@modelcontextprotocol/server ^2`)
  passt zu unserem `@modelcontextprotocol/server` 2.4.0. Server: `registerAppTool`, `registerAppResource`,
  `RESOURCE_MIME_TYPE`; im Fenster: `App` (`connect`, `ontoolresult`, `callServerTool`), Bündel `app-with-deps`.
- Externe Herkunft ist standardmäßig gesperrt (`_meta.ui.csp`); ein Bericht (ext-apps#671): Laden vom CDN rendert in
  claude.ai nicht → **Client inline ins HTML bündeln**, keine externe Quelle.
- Gestaltung (https://claude.com/docs/connectors/building/mcp-apps/design-guidelines.md): Inline-Karte ohne eigenes
  Scrollen, höchstens 2 Aktionen, 4–5 Datenpunkte, keine Menüs/Popover; Vollbild für Listen mit eigener Bedienung;
  Tippziele ≥ 44 pt, ab 320 px Breite, Safe-Area aus `hostContext`; hell/dunkel Pflicht, Strukturfarben aus den
  Host-Variablen (`--color-*`, `--font-*`), eigene Akzentfarbe erlaubt.
- `ui.domain` für Claude = SHA-256(Server-URL)[0:32] + `.claudemcpcontent.com` (nur nötig bei eigenem OAuth im Fenster/fester Herkunft).
- Claude Code rendert keine Apps (nur Text) → Sichtprüfung nur in claude.ai / Claude Desktop über den bestehenden Connector.

## Related Files
| File | Relevance |
|------|-----------|
| server/src/mcp.ts | `mcpHandler`, `registerViews` (get_view, get_task), `registerOrders` (complete_task, set_next, get_order_result); Antworten bisher nur Text-JSON, keine Ressourcen |
| server/src/anleitung.ts | `instructions` ≤ 2048 Byte; jedes snake_case-Wort muss ein Werkzeug sein (Test mcp-anleitung.test.ts:46) |
| server/src/orders.ts | Aufträge, `getResult` |
| server/package.json | `@modelcontextprotocol/server` 2.4.0, zod 4.6.7; ext-apps fehlt |
| server/test/mcp-read.test.ts, mcp-write.test.ts | Muster: `mcpHandler(pool)` + `StreamableHTTPClientTransport` über `handler.fetch`, eigenes `call()` |
| docs/reference/claude-abschrift-vertrag.md | Abschrift: Aufgabe = id, title, status, dueDate?, dueHasTime, contexts, project?, nextRank?, isKnaeuel; `now`, `views` |

## Existing Patterns
- Lesewerkzeuge über `reading(pool, render)`; Änderungen über `expected(…generatedAt)` + `storeOrder` (Auftrag „waiting“, Weckruf).
- Änderungen laufen erst auf einem Gerät; Ergebnis über `get_order_result`. Die App-Ansicht muss diesen Zwischenzustand zeigen.
- Ein Werkzeug-Satz für alle Hosts; Text-Hosts (Claude Code) müssen weiter funktionieren.

## Dependencies
- Upstream: Abschrift der App (`views` seit #621 S5), Aufträge (#622), Weckruf (#795 S5: Dienst live, App-Teil S5c-2 offen →
  ohne ihn erscheint ein Haken erst, wenn die App das nächste Mal aktiv wird).
- Downstream: claude.ai-Connector (Live-Dienst auf rennwienix), Claude Desktop.

## Risks & Considerations
- Neue Abhängigkeit (`ext-apps` 2.x) — braucht Freigabe des PO laut globalen Regeln; Alternative: Ressource und `_meta` von Hand (Spec ist offen) und den Fenster-Client selbst schreiben (postMessage/JSON-RPC).
- Bündeln ohne Build-Schritt (der Dienst hat keinen): Client-Bündel als Datei aus `node_modules` zur Laufzeit inline einsetzen.
- Gestaltungsregeln von Claude (≤ 2 Aktionen inline) gegen „Liste zum Abhaken“: Ansicht eher Vollbild oder kompakte Zeilen mit einem Haken.
- Knäuel/Perle: die Ansicht schlägt nie eines vor und bietet kein Setzen an.
- Ausrollen auf rennwienix nötig (Deploy-Skript), danach Sichtprüfung im Browser (claude.ai) mit Hennings Anmeldung.
- Scope über die Grenze (4–5 Dateien, ±250 LoC) wahrscheinlich → in Schnitte teilen.
- Zuständigkeit: Epic #612 hält Sitzung w1; #624 auf Hennings Anweisung in w3, w1 informiert. Offener PR #937 (#932 S3) ändert mcp.ts ebenfalls.

## Analysis

### Type
Feature (sichtbare UI im Chat-Host; Entwurf vor Spec Pflicht)

### Entwurf (vor Spec, wartet auf PO)
- Vorschau: https://claude.ai/artifact/BeLJTsSmPf3E6j5wT8stY2 — Datei `docs/artifacts/feat-624-mcp-app/entwurf.html` (+ `heute-app.png`)
- A (Empfehlung): Papier der App (Papiergrund, Serifentitel, Randmarke „Heute“ rot, Knäuel-Zeichen, Akzent für Etiketten),
  zwei Knöpfe je Zeile (Kreis = abhaken, Pfeil = Als nächstes; beim Knäuel ausgegraut), Tipp auf Titel klappt Angaben auf.
  Zustände: gestrichelter Kreis + Kursivzeile „wartet auf dein Gerät“, grüner Haken + durchgestrichen nach Ergebnis.
- B (Alternative): Karte in Claudes Gestalt (Host-Farben, Sans, Kästchen links, Marken-Chips, „Als nächstes“ im Detail).
- PO-Entscheid 2026-11-16: A, alle vier Ansichten.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| server/src/app-ui.ts | CREATE | `UI_URI` (`ui://loose-ends/view.html`), MIME `text/html;profile=mcp-app`, HTML mit inline CSS + JS (Client) |
| server/src/mcp.ts | MODIFY | `registerResource` der UI, `_meta.ui.resourceUri` an get_view, ggf. `structuredContent`; Eingriff minimal (PR #937 ändert mcp.ts) |
| server/test/mcp-app.test.ts | CREATE | Ressource lesbar, MIME, `_meta` an get_view, Text-JSON byte-gleich, Anleitungstest grün |
| server/test/app-client.test.ts | CREATE | Client ohne Browser: Fake-Host (postMessage), Handshake-Reihenfolge, Render als String, tools/call complete_task/set_next mit generatedAt, Warte-/Ergebnis-/Ablehnungszustand (mock.timers) |
| server/src/anleitung.ts | KEINE ÄNDERUNG | kein neues snake_case-Wort, 2048-Byte-Grenze fast erreicht |

### Scope Assessment
- Gesamt über der Grenze → drei Schnitte:
  - S1 Server: Ressource + `_meta` + Platzhalter-HTML + Test (~80 LoC, 3 Dateien)
  - S2 Client: Liste, Abhaken, Als nächstes, Warte-/Ergebniszustand, hell/dunkel aus Host-Kontext + Test (~200 LoC); danach sofort Ausrollen und Sichtprüfung in claude.ai (Handshake früh bestätigen)
  - S3 Detail (get_task), Fehlerfälle (stale/invalid sichtbar), Größenmeldung, Bilder hell/dunkel ins Ticket, Claude Desktop
- Risk Level: MEDIUM — Handshake nur aus der Spec bekannt, erst am echten Host prüfbar; Text-Hosts dürfen sich nicht ändern.

### Technical Approach
Pfad A ohne neue Abhängigkeit: Ressource per `server.registerResource`, `_meta: { ui: { resourceUri } }` an get_view;
Fenster-Client von Hand (postMessage JSON-RPC: `ui/initialize` → `ui/notifications/initialized`, `ui/notifications/tool-result`,
`tools/call` auf die vorhandenen Werkzeuge, `ui/notifications/host-context-changed`, `ui/notifications/size-changed`).
Änderungen über `complete_task`/`set_next` mit `generatedAt` der Abschrift, dann `get_order_result` alle ~3 s, höchstens ~1 min
(Weckruf-App-Teil #795 S5c-2 fehlt noch → „wartet auf dein Gerät“ kann länger stehen; danach Hinweis statt Endlosschleife).
Keine eigene Logik: Reihenfolge, Zahl, Gruppen aus der Abschrift. Knäuel/Perle nur angezeigt, nie angeboten.

| | A: von Hand | B: ext-apps 2.1.0 |
|---|---|---|
| Abhängigkeit | keine | neu (Peers passen zu server 2.4.0), Freigabe nötig |
| Größe | wenige KB | 546 KB `app-with-deps` inline je Ressource |
| Protokollpflege | selbst (Spec 2026-01-26) | SDK |
| Restrisiko | Handshake-Details | Bündel inline, ext-apps#671 (CDN rendert nicht) |
| Testbarkeit | reine Funktionen, node:test | Bündel kaum testbar |
Rückfall: scheitert der Handshake am echten Host nach S2, Wechsel auf B; S1 bleibt.
Alternative ohne App: Status quo (Claude antwortet in Text, Änderungen per Zuruf) — funktioniert heute schon; keine ADR fällt.

### Dependencies
- PR #937 (#932 S3) ändert mcp.ts → zuerst gemergt abwarten oder danach nachziehen.
- Ausrollen über deploy-loose-ends.sh auf rennwienix; Sichtprüfung in claude.ai im Browser (Hennings Anmeldung, über Chrome).
- Claude Code rendert keine Apps → Text-Weg bleibt Pflicht.

### Open Questions
- [x] PO 2026-11-16: Gestalt A (Papier der App) freigegeben.
- [x] PO 2026-11-16: alle vier Ansichten von get_view (now, due, next, open) in derselben Gestalt.
