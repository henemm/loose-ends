# Context: feat-624-s2b-knoepfe

## Request Summary
#624 Schnitt 2b: Das Fenster zu `get_view` (S2a, live seit 2026-11-17) bekommt die zwei Knöpfe aus dem freigegebenen Entwurf A:
Kreis = abhaken (`complete_task`), Pfeil = „Als nächstes“ an/aus (`set_next`). Nach dem Tipp zeigt die Zeile „wartet auf dein
Gerät …“, bis `get_order_result` ein Ergebnis liefert; danach liest das Fenster die Ansicht neu. Dazu `contexts` an den Zeilen
von „Jetzt“ (Etiketten in Akzentfarbe unter dem Titel, wie im Entwurf). Detail (`get_task`), Claude Desktop und die Bilder ins
Ticket bleiben Schnitt 3. Issue bleibt offen (`Refs #624`).

## Stand nach S2a (origin/main b51a142)
- `server/src/app-ui.ts` (150 Z.): reine Funktionen `escape`, `dayIn`, `mark`, `rowsHtml`, `readView`, `paint`, `reduce`,
  per `toString()` in genau ein inline-Skript eingebettet; `shell` hält Zustand, `postMessage`, `draw`, `size-changed`.
  `reduce(state, message)` → `{ state, out, draw }`; nimmt nur die Antwort mit `id: 1` (Handshake) an.
- `server/test/app-client.test.ts` (198 Z.): Render- und Zustandstests direkt aus dem Modul, ein `vm`-Test mit Fake-Host.
- Am echten Host belegt: Handshake, `tool-result`, Thema hell/dunkel, Randmarken (Bilder `docs/artifacts/feat-624-s2a-anzeige/`).
- PR #937 (#932 S3) ist gemergt (8176d6c) — die Abhängigkeit aus S2a für `mcp.ts` ist erfüllt.

## Protokoll (aus `docs/context/feat-624-s2-client.md`, Spec 2026-01-26)
- View → Host: `tools/call` (Standard-MCP-Request `{ name, arguments }`), Antwort als JSON-RPC-`result` = `CallToolResult`
  oder JSON-RPC-`error`. Sichtbarkeit der Werkzeuge ist Standard `["model","app"]` → `complete_task`, `set_next`,
  `get_order_result`, `get_view` ohne Änderung aufrufbar.
- `hostCapabilities.serverTools` meldet, dass der Host `tools/call` an den Server weiterreicht. Fehlt es, bietet das Fenster
  keine Knöpfe an (Anzeige wie S2a). Was claude.ai meldet, ist noch nicht gesehen → in der Analyse/Sichtprüfung belegen.

## Related Files
| File | Relevance |
|------|-----------|
| server/src/app-ui.ts | Knöpfe in `rowsHtml`, Zustand je Zeile (wartet/erledigt/abgelehnt/zeitüberschritten), Anfragen mit eigener id, Abfrage-Takt, Klick-Weiterleitung in `shell`, CSS für `.btn`, `.wait`, `.done`, Etiketten |
| server/src/mcp.ts | `nowRows` bekommt `contexts` (additiv); `get_order_result`, `complete_task`, `set_next` unverändert |
| server/test/app-client.test.ts | Zustandsübergänge Tipp → Auftrag → Abfrage → Ergebnis → neu lesen; Ablehnung; 60-s-Grenze; Knäuel ohne „Als nächstes“; kein Knopf ohne `serverTools` |
| server/test/mcp-read.test.ts | `get_now`/`get_view now` tragen `contexts` |
| server/src/orders.ts | `getResult` → `{ state: unknown|waiting|claimed|result, result? }`, `result.outcome` `done`/`rejected` (+`reason`) |
| docs/artifacts/feat-624-mcp-app/entwurf.html | Knopf-Gestalt (44 px, Akzent `#0F6E73`/`#5FC4C9`, Grün `#3E8C5F`/`#35925A`), Zeile „Abgehakt, wartet auf dein Gerät …“, grüner Haken + Durchstreichen |
| CLAUDE.md | Eintrag `src/app-ui.ts` nachführen |

## Existing Patterns
- Reine Funktionen + Einbettung per `toString()`; `shell` ist die einzige Stelle mit DOM, Timern und `postMessage`.
- Änderung erst als ausgeführt melden, wenn `get_order_result` ein `result` zeigt (Anleitung an Claude, `src/anleitung.ts`).
- Knäuel/Perle nur anzeigen, nie anbieten (#648); beim Knäuel ist „Als nächstes“ ausgegraut.
- Farbbudget: Akzent = tippbar, Rot = Zeitdruck, Grau = Hierarchie, Grün = nur der Abschlussmoment.

## Dependencies
- Upstream: Aufträge (#622), `update_task`-Stand von `mcp.ts` (#932 S3, gemergt), Weckruf serverseitig live (#795 S5b);
  App-Teil des Weckrufs (#795 S5c-2) fehlt → ohne geöffnete App bleibt „wartet …“ bis zur 60-s-Grenze.
- Downstream: claude.ai-Connector auf dem Live-Dienst; Ausrollen per `scripts/deploy-loose-ends.sh` (henemm-infra, `LE_COMMIT`).

## Risks & Considerations
- **Veraltete Abschrift:** Jedes ausgeführte Ergebnis lässt die App eine neue Abschrift senden; `expected()` lehnt danach jeden
  Auftrag mit altem `generatedAt` ab („Abschrift hat sich geändert, bitte neu lesen“). → Nach jedem `result` und bei genau
  dieser Ablehnung `get_view` neu per `tools/call` lesen und neu zeichnen; eine zweite Ablehnung wird als ruhige Zeile gezeigt.
- **Abfrage begrenzen:** alle 3 s, höchstens 60 s (20 Abfragen), dann ruhige Zeile „Noch nicht übernommen – dein Gerät holt es
  beim nächsten Öffnen.“; kein Endlos-Takt, Timer bei `ui/resource-teardown` beenden.
- **Doppel-Tipp:** eine Zeile mit offenem Auftrag nimmt keinen weiteren Tipp an.
- **`set_next`-Richtung:** „Jetzt“-Zeilen tragen kein `nextRank`; `on` = Gruppe ≠ `lined`; in den anderen Ansichten `on` = kein `nextRank`.
- **Echte Änderung beim Sichtnachweis:** Ein Abhaken in claude.ai ändert Hennings Daten. Für den Beleg eine eigens per
  `capture_task` angelegte Prüfaufgabe nutzen und nur diese abhaken; ausgeführt wird sie auf seinem Gerät erst, wenn die App läuft
  (kein Eingriff auf seinem Gerät durch mich).
- Escaping bleibt Pflicht (Etiketten sind Nutzertext); ids nur aus der Abschrift, nie aus dem DOM-Text.

## Analysis

### Type
Feature (sichtbare UI im Chat-Host, Entwurf A am 2026-11-16 freigegeben inkl. Knöpfen und Wartezustand → kein neuer Entwurf nötig)

### Technical Approach
- `State` erweitert um `caps` (`serverTools` vorhanden?), `nextId` (ab 2), `pending` (Anfrage-id → Zweck), `rows` (Zeilen-id →
  `{ order?, phase: waiting|done|rejected|late, polls }`).
- `reduce` bekommt zusätzlich Ereignisse aus der `shell`: `{ kind: "tap", action: "complete"|"next", taskID }` und
  `{ kind: "tick", taskID }`. Rückgabe zusätzlich `later: [{ ms, event }]` für Timer; `shell` führt sie mit `setTimeout` aus.
- Antworten: `complete_task`/`set_next` → `orderID` speichern, Abfrage planen; `isError` mit „Abschrift hat sich geändert“ →
  `get_view` neu lesen; andere Fehler → Zeile `rejected` mit ruhigem Text. `get_order_result` → `result.done` ⇒ Zeile `done`
  (grüner Haken) und `get_view` neu; `rejected` ⇒ ruhige Zeile; `waiting`/`claimed` ⇒ nächste Abfrage bis 20.
- Antwort auf `get_view` = `CallToolResult` wie `tool-result` → `readView`.
- Klicks: ein Listener auf `#list`, `data-act` + `data-id` (escaped) an den Knöpfen.
- `mcp.ts`: `nowRows` gibt `contexts` mit (eine Zeile).

### Alternativen
- **B: Knopf schickt `ui/message` an Claude** („Hake X ab“), Claude ruft das Werkzeug selbst: kein eigener Auftragszustand im
  Fenster, aber jeder Tipp kostet eine Modellrunde und die Rückmeldung kommt als Text statt in der Zeile. Keine ADR fällt.
- **C: Keine Knöpfe, nur Anzeige** (Stand S2a): ändert nichts, das Abhaken bleibt Sache des Gesprächs. Kein Ziel des Issues.
- **D: SDK `@modelcontextprotocol/ext-apps`** statt Handarbeit: neue Abhängigkeit (PO-Freigabe); nicht nötig, der Handshake ist belegt.

### Scope Assessment
- Dateien: `app-ui.ts`, `mcp.ts`, `app-client.test.ts`, `mcp-read.test.ts`, `CLAUDE.md` (5)
- Geschätzt: Code ~130 LoC (app-ui ~125, mcp 3), Tests ~150 LoC
- Risk Level: MEDIUM — erste schreibende Aufrufe aus dem Fenster; Rückweg: vorheriger `LE_COMMIT`.

### Open Questions
- Keine PO-Frage: Knöpfe, Wartezeile und Haken sind im freigegebenen Entwurf A; Takt, Grenzen und Fehlertexte sind technisch.

### Nachtrag Analyse 2026-11-17 (nach /clear)

**Recherche `serverTools`:** Laut MCP-Apps-Spezifikation antwortet der Host auf `ui/initialize` mit `hostCapabilities`;
`serverTools` heißt, dass er `tools/call` aus dem Fenster an den Server weiterreicht; ohne den Eintrag soll das Fenster nur
anzeigen. Quellen: https://apps.extensions.modelcontextprotocol.io/api/interfaces/app.McpUiHostCapabilities.html,
https://apps.extensions.modelcontextprotocol.io/api/documents/overview.html,
https://sunpeak.ai/blogs/mcp-app-capability-detection-fallbacks. Ob claude.ai den Eintrag setzt, ist öffentlich nicht
belegt → erster Prüfpunkt der Sichtprüfung nach dem Ausrollen. Meldet claude.ai ihn nicht, bleibt das Fenster ohne Knöpfe
(Stand S2a, kein Schaden) und Alternative B (`ui/message`) wird der Weg für Schnitt 2b-2.

**Umfang und Schnitt (Tech-Lead-Entscheidung):** Code ~130 + Tests ~150 LoC = ~280 > 250 (`server/test/` zählt mit).
Daher zwei Schnitte:
- **S2b-1 Abhaken:** `hostCapabilities.serverTools` lesen, Kreisknopf an jeder Zeile (auch Knäuel), Auftrag `complete_task`
  mit `generatedAt` der Ansicht, Wartezeile „Abgehakt, wartet auf dein Gerät …“, Abfrage `get_order_result` alle 3 s bis
  60 s, Ergebnis `done` → grüner Haken + Durchstreichen, dann `get_view` neu; `rejected`/Zeitgrenze → ruhige Zeile;
  „Abschrift hat sich geändert“ → einmal neu lesen. Dateien: `app-ui.ts`, `app-client.test.ts`, `CLAUDE.md`.
  Schätzung Code ~100, Tests ~110.
- **S2b-2 Als nächstes + Etiketten:** Pfeilknopf `set_next` an/aus (beim Knäuel ausgegraut, Richtung nach Gruppe bzw.
  `nextRank`), `contexts` in `nowRows` und als Etiketten unter dem Titel. Dateien: `app-ui.ts`, `mcp.ts`, beide Tests,
  `CLAUDE.md`. Schätzung Code ~35, Tests ~50. Nutzt die Auftragsmaschine aus S2b-1 unverändert.

Dieser Workflow (`feat-624-s2b-knoepfe`) baut **S2b-1**; Spec `docs/specs/feat-624-schnitt-2b1-abhaken.md`.
Keine PO-Frage: Knopf, Wartezeile und Haken sind im freigegebenen Entwurf A (2026-11-16).
