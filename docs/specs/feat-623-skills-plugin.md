---
entity_id: feat-623-skills-plugin
type: feature
created: 2026-11-13
updated: 2026-11-13
status: draft
workflow: feat-623-skills-plugin
---

# Spec: Anleitung des Dienstes für Claude, zwei Abläufe (#623, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#623 (Epic #612). Analyse: `docs/context/feat-623-skills-plugin.md` (Abschnitt „Analysis“, verbindlich).
Das Ticket verlangte ein Plugin mit drei Skills. Entschieden (Henning 2026-11-13 und Tech Lead): kein Plugin, keine Skills; der Dienst schickt Claude beim Verbinden eine kurze Anleitung mit (`instructions` im MCP-`initialize`). Wochenrückblick entfällt ganz (kein eigenes Ticket). Die Definition of Done des Tickets („Plugin in Claude installiert“) wird im Ticket entsprechend umgeschrieben (Teil der Lieferung).
Das Issue bleibt bis zum Nachweis in claude.ai offen (`Refs #623`); der Nachweis ist derselbe Durchlauf wie der von #622.

## Für den PO

Wenn du Claude mit Loose Ends verbunden hast, weiß Claude künftig von selbst, wie es mit deinen Aufgaben umgehen soll: beim Planen des Tages zuerst „Jetzt“ und „Fällig“ ansehen, beim Zerlegen eines Textes oder einer Mail ihr die Liste zeigen und erst nach deinem Ja anlegen, nie etwas löschen und nie ein Knäuel oder eine Perle vorschlagen. Du musst nichts installieren. Den Wochenrückblick gibt es nicht (gestrichen).

## Purpose

Der Dienst (`server/src/mcp.ts`) legt heute `new McpServer({ name: "loose-ends", version: "1" })` ohne Anleitung an: Claude sieht 14 Werkzeuge, aber keine Regeln, wie sie zu benutzen sind. Die Anleitung steht als Textkonstante im Dienst, wirkt in jeder Verbindung und bleibt mit den Werkzeugen versioniert.

**Regeln vor Modell:** reiner Text, keine Modellaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

### Teil 1: `server/src/anleitung.ts` (neu)

Exportiert `export const anleitung: string` (Deutsch, einfacher Text). Länge: **höchstens 2048 Byte** (UTF-8; Claude Code kürzt darüber, Quelle in der Analyse). Inhalt, in dieser Reihenfolge:

1. Ein Satz: was Loose Ends ist (Aufgaben, die der Nutzer per Sprache und Text festhält) und dass Claude nur über die Werkzeuge arbeitet.
2. **Tag planen:** `get_view` mit `now`, dann mit `due`; die Zahl über „Jetzt“ (`nowCount`) nennen; die Reihenfolge der App nicht umsortieren; den Stand der Abschrift (`generatedAt`) nennen.
3. **Text oder Mail zerlegen:** erst die geplante Liste dem Nutzer zeigen und sein Ja abwarten; dann je Aufgabe ein `capture_task` mit dem Wortlaut des Nutzers unverändert (ein Rohtext je Aufgabe); Teilschritte nur mit `add_subtask`.
4. **Grundregeln:** nie löschen (es gibt kein Löschwerkzeug); nie das Knäuel oder eine Perle vorschlagen oder setzen (#648); Änderungen erst als ausgeführt melden, wenn `get_order_result` ein Ergebnis zeigt (sie laufen auf einem Gerät des Nutzers, nicht sofort); bei `set_due`, `complete_task` und anderen Änderungen vorher `get_now` oder `get_view` lesen und `generatedAt` mitgeben.

Kein Abschnitt zum Wochenrückblick; kein Satz, der Erledigtes oder Perlen in Aussicht stellt (die Abschrift trägt sie nicht, `docs/reference/claude-abschrift-vertrag.md`).

### Teil 2: `server/src/mcp.ts` (ändern, eine Zeile)

`new McpServer({ name: "loose-ends", version: "1" }, { instructions: anleitung })`; Import aus `./anleitung.ts`. Sonst keine Änderung an `mcp.ts`: keine Werkzeuge, keine Beschreibungen (die Nachbarsitzung fasst die Datei kaum an, Absprache 2026-11-13).

### Teil 3: `server/test/mcp-anleitung.test.ts` (neu)

Muster `mcp.test.ts` (Client im Prozess über `mcpHandler`, `freshPool`, Konto in `authInfo`).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR; ADR-21 (Dienst für Claude, Weg B) bleibt unverändert und wird belegt. Keine neue Abhängigkeit, kein Schema, keine Migration.

- **Rationale:** Die Anleitung ist eine Konstante in eigener Datei, damit `mcp.ts` fast unberührt bleibt und der Text ohne Serverlogik prüfbar ist. Server-Anleitung statt Plugin, weil sie ohne Installation in jeder Verbindung ankommt; Beleg: Frieda liefert ihre Anleitung auf demselben Weg (`initialize` mit `instructions`) und sie kommt in Hennings Sitzung an.

## Source

- **Files:** `server/src/anleitung.ts` (neu, Export `anleitung`), `server/src/mcp.ts` (eine Zeile plus Import, `mcpHandler`), `server/test/mcp-anleitung.test.ts` (neu, Tests `initializeCarriesTheInstructions`, `instructionsFitTwoKilobytes`, `instructionsNameOnlyExistingTools`, `instructionsHoldTheRulesAndNoReview`)

## Dependencies

| Name | Art | Hinweis |
|---|---|---|
| `@modelcontextprotocol/server` 2.4.0 | Bibliothek | kennt `instructions?: string` in den Server-Optionen (geprüft in den Typen des Pakets) |
| `server/src/mcp.ts` | Datei | als einzige berührt |
| `main.ts`, `orders.ts`, `app-routes.ts`, Vertrag, Migrationen | Dateien | bleiben unberührt |

## Acceptance Criteria

- **AC-1:** Anleitung kommt an: GIVEN ein Client im Prozess über `mcpHandler` mit Konto WHEN er `initialize` abgeschlossen hat THEN liefert `client.getInstructions()` genau den Text aus `anleitung.ts` (Test `initializeCarriesTheInstructions`).
- **AC-2:** Kurz genug: GIVEN `anleitung` THEN ist `Buffer.byteLength(anleitung, "utf8")` höchstens 2048 und der Text nicht leer (Test `instructionsFitTwoKilobytes`).
- **AC-3:** Nur wirkliche Werkzeuge: GIVEN die Anleitung WHEN alle Wörter der Form `[a-z]+_[a-z_]+` aus ihr gezogen werden THEN kommt jedes davon in `client.listTools()` vor, und die Anleitung nennt mindestens `get_view`, `capture_task`, `add_subtask` und `get_order_result` (Test `instructionsNameOnlyExistingTools`).
- **AC-4:** Inhalt der Regeln: GIVEN die Anleitung THEN enthält sie die Wörter „Jetzt“, „Fällig“, „löschen“, „Knäuel“ und „Perle“, und enthält weder „Wochenrückblick“ noch „Rückblick“ (Test `instructionsHoldTheRulesAndNoReview`).
- **AC-5:** Ohne Konto weiter 401: GIVEN ein Aufruf ohne Konto in `authInfo` THEN verhält sich der Dienst wie vorher (bestehende Tests in `mcp.test.ts` unverändert grün); die Anleitung öffnet keinen Weg ohne Anmeldung (Beleg: Suite).
- **AC-6:** Nichts anderes geändert: GIVEN die Änderung THEN zeigt `git diff --stat origin/main...HEAD` genau `server/src/anleitung.ts`, `server/src/mcp.ts` (höchstens 3 geänderte Zeilen), `server/test/mcp-anleitung.test.ts` sowie Spec, Kontext, Briefing, Belege und die `CLAUDE.md`-Zeile; `docs/reference/claude-abschrift-vertrag.md` und `server/src/main.ts` fehlen darin (Beleg: Ausgabe im Abschlussbericht).
- **AC-7:** Serverkette grün: GIVEN `./server/scripts/test-local.sh` THEN ist `typecheck` sauber und alle Tests grün (Beleg: Lauf im Abschlussbericht).

## Scope

| Datei | Art | Umfang |
|---|---|---|
| `server/src/anleitung.ts` | neu | ca. 25 LoC (Text) |
| `server/src/mcp.ts` | ändern | 2–3 LoC |
| `server/test/mcp-anleitung.test.ts` | neu | ca. 50 LoC |

Drei Code-/Testdateien, ca. +80 LoC; `CLAUDE.md`-Zeile (Abschnitt `server/`), Ticket-Text und Belege zählen nicht zum Limit.

## Risiken

- **Claude liest die Anleitung nicht:** Claude Code liest sie (Drittquelle), für claude.ai gibt es keine Anthropic-Aussage; ein Fallbericht meldet für Claude Desktop „gespeichert, nie gelesen“. Gegenbeleg: Frieda kommt in Hennings Sitzung an. Der Nachweis in claude.ai steht aus und ist Teil von #622/#623; bleibt er negativ, ist Weg 2 (Plugin) die Alternative und das Ticket wird neu geschnitten.
- **Länge:** über 2 KB wird gekürzt; AC-2 hält die Grenze.
- **Drift:** nennt die Anleitung ein Werkzeug, das fehlt oder umbenannt wird, schlägt AC-3 fehl.

## Test Plan

Ein Testfile, vier Tests (AC-1 bis AC-4), Muster `mcp.test.ts`; AC-5 und AC-7 über die ganze Serverkette. Rot zuerst: ohne `anleitung.ts` schlägt der Import fehl, ohne die Zeile in `mcp.ts` ist `getInstructions()` leer.

## Alternativen

| Weg | Was | Dagegen | Gekippt würde |
|---|---|---|---|
| **A (gewählt): Server-Anleitung** | `instructions` im `initialize` | 2-KB-Grenze; Wirkung in claude.ai ungeprüft | nichts |
| **B Plugin mit Skills + `.mcp.json`** | ausführlichere Abläufe | wirkt nur in Claude Code, claude.ai bräuchte Zips; Pflege zweier Quellen; verworfen | der Ticketentwurf „Plugin bündelt Connector-Eintrag und Skills“, keine ADR |
| **C Beides** | kurz im Server, Details in Skills | zwei Quellen für dieselben Regeln | wie B |
| **D Wochenrückblick jetzt bauen** | Abschrift Version 2 mit Erledigtem | Datenschutz-Freigabe (#625-Regel im Vertrag), Vertragsänderung; von Henning gestrichen | nichts |

ADR-21 (Weg B) bleibt; keine frühere Entscheidung fällt.

## Out of Scope / Folgeschnitte

- Wochenrückblick, Abschrift Version 2, Plugin, Skills, Änderungen an Werkzeugbeschreibungen, Vertrag, `main.ts`.
- Nachweis in claude.ai (Handy/Web): braucht Hennings Verbindung, gemeinsam mit #622.

## Abnahme

Tests und Serverkette (Stufe 1). Kein App-Code, daher kein Simulator: „Kein Pfad der Geräteliste berührt.“ Der Nachweis in claude.ai bleibt offen bis zum gemeinsamen Durchlauf mit #622.

## Definition of Done

- [ ] AC-1 bis AC-7 erfüllt, `./server/scripts/test-local.sh` grün.
- [ ] `CLAUDE.md`: eine Zeile zu `src/anleitung.ts` im Abschnitt `server/`.
- [ ] Ticket #623: Definition of Done auf „Anleitung kommt in claude.ai an, zwei Abläufe einmal durchgespielt“ umgeschrieben, Wochenrückblick gestrichen; Ticket bleibt offen (`Refs #623`).
- [ ] Epic #612 aktualisiert.

## Known Limitations

- Zwei Abläufe statt drei; ohne Erledigtes in der Abschrift ist kein Rückblick möglich.
- Ob claude.ai die Anleitung zeigt, ist erst mit dem Nachweis belegt.

## Changelog

- 2026-11-13: Erstfassung.
