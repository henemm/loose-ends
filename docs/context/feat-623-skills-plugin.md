# Context: feat-623-skills-plugin

## Request Summary
#623: Claude nutzt Loose Ends so, wie die App gedacht ist, nicht nach Gutdünken. Drei Abläufe: Tag planen (Jetzt + Fällig), Wochenrückblick (Abschlüsse), Text oder Mail in Aufgaben zerlegen (ein Rohtext je Aufgabe). Henning (2026-11-13): Kein Eintrag im Claude-Verzeichnis (#612/#625 umgeschrieben); Frieda liefert dasselbe Muster schon.

## Befund (Stand 2026-11-13)
- Die Schreib- und Lesewerkzeuge existieren in `server/src/mcp.ts`: `get_now`, `list_tasks`, `get_view`, `search_tasks`, `get_task`, `list_projects`, `list_contexts`, `capture_task`, `get_order_result`, `complete_task`, `set_due`, `set_next`, `park_task`, `add_subtask`. #622 ist offen, weil nur der Nachweis aus claude.ai fehlt.
- `mcp.ts` Zeile ~193: `new McpServer({ name: "loose-ends", version: "1" })`, **ohne `instructions`**. Der Dienst schickt Claude beim Verbinden keine Anleitung mit.
- Frieda (Connector in Hennings claude.ai) liefert ihre Anleitung („Du bist Frieda …“, Regeln, Rollen, Bestätigungspflichten) als MCP-Server-Anleitung beim Verbinden. In `henemm/frieda-reist` liegen weder Plugin noch Skills; die Schnittstelle steckt in `engine/konnektor.py`, `engine/schnittstelle.py`, `engine/oauth.py` (noch nicht gelesen).

## Vorschlag (Regeln-vor-Modell, einfachster Weg zuerst)
- **Weg 1 (empfohlen):** Die drei Abläufe als Server-Anleitung (`instructions`) in `mcp.ts`, wirkt sofort auf Handy, Desktop und Web, kein Plugin, kein Zip. Test: Der Dienst nennt die Anleitung beim `initialize`.
- **Alternative:** Plugin mit drei Skills (`.claude-plugin/plugin.json`, `skills/*/SKILL.md`, `.mcp.json`) wirkt nur in Claude Code; für claude.ai bräuchte es je Skill ein Zip zum Hochladen. Fiele: nichts in den ADRs, nur der Ticket-Entwurf „Plugin bündelt Connector-Eintrag und Skills“.
- Skills als Anthropic-Dokument: Quellen https://code.claude.com/docs/en/plugins-reference, https://claude.com/docs/skill.md.

## Related Files
| File | Relevance |
|------|-----------|
| server/src/mcp.ts | Hier käme `instructions` hin; Datei gehört #612, Nachbarsitzung „#612 App und Weckruf“ fasst sie möglichst nicht an (Absprache 2026-11-13) |
| server/test/mcp.test.ts, mcp-read.test.ts, mcp-write.test.ts | Muster für den Test der Anleitung |
| docs/reference/claude-abschrift-vertrag.md | Vertrag; Nachbarsitzung ändert dort „Wege der App“ (S5a), vorher nicht anfassen |

## Absprache mit der Nachbarsitzung (2026-11-13)
- Migration 008 gehört ihr (`device_tokens`), ich nehme 009 ff.
- Vor Änderungen an `orders.ts`, `main.ts`, `app-routes.ts`, dem Vertrag: vorher Bescheid geben. `mcp.ts` nur für #622/#624/#623.

## Offen für /20-analyse
1. Frieda-Schnittstelle lesen (`engine/konnektor.py`, `engine/schnittstelle.py`): wie wird die Anleitung geliefert, wie lang, wie getestet.
2. Prüfen, ob `McpServer` die Option `instructions` annimmt (SDK-Version in `server/package.json`).
3. Wortlaut der drei Abläufe aus `docs/project/01-user-story.md` und den Ansichten (`get_view`: now, due, next, open) ableiten.
4. Entscheidung: Weg 1 allein oder zusätzlich das Plugin.

## Risks & Considerations
- Eine zu lange Anleitung belastet jede Claude-Unterhaltung; kurz halten.
- Kein Löschen, keine Massenersetzung (aus #622).

## Analysis

### Type
Feature (Claude-Integration, Epic #612, wartet formal auf #622; Werkzeuge sind gebaut, nur der claude.ai-Nachweis von #622 fehlt)

### Recherche (2026-11-13, Quellen)
- MCP-Spezifikation: `InitializeResult.instructions` ist ein optionales Feld „wie der Server zu benutzen ist“ (https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle.md). Der Server-SDK 2.4.0 (`@modelcontextprotocol/server`, `package.json`) kennt `instructions?: string` (geprüft in den Typen des Pakets).
- Claude Code liest `instructions`, kürzt sie auf **2 KB** (Drittquelle https://sunpeak.ai/blogs/mcp-server-instructions-chatgpt-claude). Ob claude.ai (Web/Handy) sie liest, steht in keiner Anthropic-Quelle; ein Fallbericht meldet für Claude Desktop „gespeichert, nie gelesen“ (Stand unbekannt).
- **Eigener Beleg:** In dieser Sitzung kommen Friedas Anleitung („Du bist Frieda …“) und die der Reise als „MCP Server Instructions“ im Systemtext an, und Frieda setzt genau dieses Muster ein (`engine/konnektor.py`: `initialize` liefert `instructions`). Dort erscheint sie gekürzt („[truncated]“): kurz halten.
- Plugin-Aufbau: `.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`, `.mcp.json` (Remote-Server als Eintrag möglich) (https://code.claude.com/docs/en/plugins-reference). Ein Plugin wirkt in Claude Code; claude.ai bekommt Skills nur per Zip-Upload.

### Befund, der gegen das Ticket spricht
**Der Wochenrückblick geht mit den heutigen Daten nicht.** Die Abschrift trägt „alle Aufgaben, die nicht erledigt und nicht gelöscht sind“ (`docs/reference/claude-abschrift-vertrag.md`, Abschnitt Abschrift). Erledigtes, Abschlusszeitpunkte und Perlen kommen nicht an. Dafür bräuchte es Vertrag Version 2 samt Freigabe im Datenschutztext (#625-Regel im Vertrag). Mit `get_view` gehen: Tag planen (now, due, next) und Zerlegen (`capture_task`, `add_subtask`).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| server/src/mcp.ts | MODIFY | `new McpServer({...}, { instructions })` mit kurzer Anleitung (≤ 2 KB, Byte-gezählt) |
| server/src/anleitung.ts | CREATE | Der Anleitungstext als Konstante, getrennt von mcp.ts (Nachbarsitzung fasst mcp.ts kaum an) |
| server/test/mcp-anleitung.test.ts | CREATE | `initialize` nennt die Anleitung; ≤ 2048 Byte; nennt nur existierende Werkzeuge |
| plugin/ (optional, Weg 2) | CREATE | plugin.json, drei SKILL.md, .mcp.json |

### Scope Assessment
- Weg 1: 3 Dateien, ca. +90 LoC (Text eingerechnet), Risiko LOW
- Weg 2 zusätzlich: 5 Dateien, ca. +120 LoC, Risiko LOW (reine Textdateien)

### Technical Approach
**Ohne Modell, ohne Plugin zuerst:** Weg 1, Server-Anleitung. Sie wirkt in jeder Verbindung (Claude Code sicher, claude.ai belegt durch Frieda-Muster), braucht keine Installation und bleibt mit den Werkzeugen versioniert. Inhalt, drei Abläufe in einfachen Regeln:
1. Tag planen: `get_view now`, dann `due`; Zahl über „Jetzt“ nennen; nichts umsortieren, was die App sortiert; `generatedAt` nennen.
2. Text/Mail zerlegen: ein Rohtext je Aufgabe über `capture_task`, Wortlaut des Nutzers unverändert, Teilschritte nur über `add_subtask`; vorher dem Nutzer die Liste zeigen und bestätigen lassen.
3. Rückblick: nur ehrlich sagen, was die Abschrift hergibt (Offenes, Fälliges), solange Erledigtes fehlt.
Dazu Grundregeln: nie das Knäuel oder eine Perle vorschlagen (#648), nichts löschen, Aufträge erst als „angenommen“ melden, wenn `get_order_result` ein Ergebnis zeigt.

### Alternativen
- **Weg 2, Plugin mit drei Skills + `.mcp.json`:** nur Claude Code; claude.ai bräuchte je Skill ein Zip. Gewinn: ausführlichere Abläufe ohne 2-KB-Grenze. Kippt: nichts in den ADRs, nur den Ticketentwurf „Plugin bündelt Connector-Eintrag und Skills“; DoD „Plugin installiert“ würde neu gefasst.
- **Weg 3, beides:** Anleitung kurz im Server, Details in Skills. Mehr Pflege, zwei Quellen für dieselben Regeln.
- **Wochenrückblick:** (a) streichen und als eigenes Ticket „Abschrift Version 2: Erledigtes“ mit Datenschutz-Freigabe anlegen, (b) Abschrift jetzt erweitern. Empfehlung (a).

### Dependencies
SDK 2.4.0 (`instructions` vorhanden). `mcp.ts` gehört #622/#624/#623 (Absprache Nachbarsitzung); `main.ts`, `orders.ts`, Vertrag bleiben unberührt. DoD „Plugin in Claude installiert, jeder Skill einmal durchgespielt“ passt nicht zu Weg 1 und müsste im Ticket umformuliert werden („Anleitung kommt in claude.ai an, drei Abläufe einmal durchgespielt“).

### Open Questions
- [x] Henning 2026-11-13: Wochenrückblick ganz streichen (kein eigenes Ticket). Weg 1 (Server-Anleitung) entscheidet Claude technisch; Anleitung nennt nur Tag planen und Zerlegen, Rückblick entfällt.
- [ ] Nachweis in claude.ai (Handy/Web) braucht seine Verbindung; der Nachweis von #622 ist derselbe Durchlauf.
