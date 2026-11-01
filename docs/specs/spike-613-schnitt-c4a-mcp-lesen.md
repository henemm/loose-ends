---
entity_id: spike-613-schnitt-c4a-mcp-lesen
type: feature
created: 2026-11-01
updated: 2026-11-01
status: draft
workflow: spike-613-c4-mcp
---

# Spec: MCP-Handler mit den Lese-Werkzeugen get_now und list_tasks, Schnitt C4a (#613, Weg B „Fenster für Claude“)

## Approval

- [ ] Approved

## GitHub Issue

#613 (Spike, Epic #612). Schnitt C4a; das Issue bleibt offen (`Refs #613`, nie `Closes #613`).
Vorgänger: C3b (`docs/specs/spike-613-schnitt-c3b-auftraege.md`, PR #793), C3a (`docs/specs/spike-613-schnitt-c3a-abschrift-annehmen.md`, PR #791), C1b (`docs/specs/spike-613-schnitt-c1b-schema.md`), Vertrag v1 (`docs/reference/claude-abschrift-vertrag.md`).
Analyse: `docs/context/spike-613-c4-mcp.md`. Nicht Teil dieser Spec: C4b (`capture_task`, `complete_task`, `set_due`, `get_order_result`, dazu `getResult`), Anmeldung und Konto (C6), Port und Betrieb (C7).

## Purpose

Der Dienst nimmt seit C3a/C3b Abschrift, Aufträge und Ergebnisse an, aber niemand kann sie lesen. Dieser Schnitt macht die Abschrift für Claude als MCP-Werkzeug erreichbar:
`getTranscript(pool, account)` liest die gespeicherte Abschrift; `mcpHandler(pool)` ist ein zustandsloser MCP-Handler (Protokollrevision 2026-07-28, SDK v2) mit zwei Werkzeugen:
`get_now` (die Zahl über „Jetzt“ und die Zeilen von „Jetzt“) und `list_tasks` (alle Aufgaben der Abschrift samt `generatedAt`).
Das Konto kommt ausschließlich aus `authInfo` der Anfrage; fehlt es, lehnt jedes Werkzeug ab. Es gibt keinen Port und keine Anmeldung: der Handler wird nur im Prozess aufgerufen (Tests), bis C6/C7 ihn anschließen.

Der Dienst rechnet nichts nach: `get_now` gibt `nowCount` der App unverändert aus und zählt die Zeilen nicht neu (#637, „eine Zahl überall“).
Claude sieht den Stand des letzten Hochladens, nicht des Geräts (Weg B selbst); `generatedAt` macht das Alter sichtbar.

**Regeln vor Modell:** Alles ist Regel, SQL und Protokoll; kein Sprachmodell beteiligt. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Keine neue Produktentscheidung: Weg B (eigener Dienst für Abschrift und Auftragsweg, „TypeScript-Dienst mit MCP-SDK“, Henning 2026-10-31) ist in #612 entschieden und wird mit ADR-21 in C8 festgehalten. Dieser Schnitt setzt den Lesezweig um.

## Source

**Files:** `server/src/mcp.ts` (neu), `server/src/transcripts.ts` (`getTranscript`), `server/test/mcp.test.ts` (neu)
**Identifier:** `mcpHandler`, `getTranscript`

### Neue Abhängigkeiten (feste Versionen, Freigabe: Henning beschrieb Weg B am 2026-10-31 als „TypeScript-Dienst mit MCP-SDK“)

| Paket | Version | Art | Grund |
|---|---|---|---|
| `@modelcontextprotocol/server` | 2.4.0 | dependencies | `createMcpHandler`, `McpServer`; zustandslos nach Revision 2026-07-28 |
| `zod` | 4.6.7 | dependencies | Eingabeschemas der Werkzeuge (das SDK verlangt sie; `mcp.ts` importiert es direkt, das Paket verlangt `^4.2`) |
| `@modelcontextprotocol/client` | 2.4.0 | devDependencies | Testclient `Client` und `StreamableHTTPClientTransport` |

Nicht in C4a: `@modelcontextprotocol/node` und `hono` (sie bräuchte nur ein echter Port, also C7). `package-lock.json` wird erzeugt und zählt nicht als Datei.

### Server: `getTranscript(pool, account): Promise<Transcript | undefined>`

Eine Anweisung: `SELECT doc FROM transcripts WHERE account_id = $1`. Eine Zeile: ihre `doc`; keine: `undefined`. Es prüft nichts nach (die Form wurde beim Annehmen geprüft).

### Server: `mcpHandler(pool)`

Gibt den Handler von `createMcpHandler` zurück (Web-Standard, `handler.fetch(request, { authInfo })`); je Anfrage entsteht eine frische Server-Instanz mit genau zwei Werkzeugen, beide ohne Eingabefelder (leeres Zod-Objekt).

- **Konto:** nur `ctx.http.authInfo.extra.account` (Text, nicht leer). Fehlt `authInfo` oder das Konto, antwortet das Werkzeug mit `isError: true` und dem Text „kein Konto“; es liest nichts. Der Handler prüft keinen Token (C6).
- **Ohne Abschrift:** beide Werkzeuge antworten mit dem Text „noch keine Abschrift“, ohne `isError`.
- **`get_now`:** JSON-Text `{ "nowCount": <Zahl der Abschrift, unverändert>, "generatedAt": "...", "rows": [ … ] }`. `rows` hat die Zeilen in der Reihenfolge `knaeuel` (nur wenn vorhanden), dann `today`, `lined`, `waiting`, je Zeile in der Reihenfolge der Abschrift; je Eintrag `{ id, title, dueDate (nur wenn vorhanden), dueHasTime, status, isKnaeuel, group }` aus der Aufgabe mit dieser Kennung in `tasks` (`group`: `knaeuel`, `today`, `lined` oder `waiting`). Steht die Kennung nicht in `tasks`, erscheint nur `{ id, group }`; der Dienst gleicht nichts ab.
- **`list_tasks`:** JSON-Text `{ "generatedAt": "...", "tasks": [ … ] }` mit allen Aufgaben der Abschrift, Reihenfolge wie geliefert, je Aufgabe genau die Felder der Abschrift (`id`, `title`, `status`, `dueDate`, `dueHasTime`, `contexts`, `project`, `nextRank`, `isKnaeuel`; fehlende optionale Felder fehlen).
- **Datenschutz:** Ausgaben tragen nur, was die Abschrift trägt (kein Rohtext, keine Notiz); der Handler schreibt keine Inhalte (Titel, Kennungen) in Logs.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/migrations/001_claude_schema.sql` | Tabelle `transcripts` (eine Zeile je `account_id`), **unverändert** |
| `server/src/transcripts.ts` (C3a/C3b) | Typ `Transcript`, `putTranscript` (im Test zum Befüllen) |
| `server/test/db.ts` (`freshPool`), `server/src/migrate.ts` (`migrate`) | Testaufbau: eigenes Schema je Test gegen echtes Postgres |
| Vertrag v1 `docs/reference/claude-abschrift-vertrag.md` | Quelle der Beispielabschrift (Test liest den ersten ```json-Block zur Laufzeit) |
| `@modelcontextprotocol/server` 2.4.0, `zod` 4.6.7, dev `@modelcontextprotocol/client` 2.4.0 | **neu**, siehe oben |
| Postgres 18 (lokal Wegwerf-Instanz, CI `postgres:18`), `pg` 8.23.1, `node:test` | bestehend |

## Acceptance Criteria

Alle Tests liegen in `server/test/mcp.test.ts`, je Fall ein `t.test`/`test`, im Prozess über `Client` mit `StreamableHTTPClientTransport` und `fetch: handler.fetch` (kein Port), gegen echtes Postgres (`freshPool`, `migrate`). Das Konto setzt der Test über `authInfo`.

- **AC-1:** `tools/list` nennt genau zwei Werkzeuge, `get_now` und `list_tasks` (Test: Namensliste gleich `["get_now", "list_tasks"]` nach Sortierung).
- **AC-2:** Ohne `authInfo` (kein Konto) lehnt `get_now` ab: `isError` ist wahr, der Text nennt „kein Konto“; dasselbe für `list_tasks`. Der Test hinterlegt vorher eine Abschrift für `henning` und belegt, dass sie nicht ausgegeben wird.
- **AC-3:** Ein anderes Konto sieht keine fremde Abschrift: mit gespeicherter Abschrift für `henning` liefert `get_now` und `list_tasks` für das Konto `anna` den Text „noch keine Abschrift“ ohne `isError`; die Titel der Abschrift von `henning` kommen in der Antwort nicht vor.
- **AC-4:** Ohne gespeicherte Abschrift antworten `get_now` und `list_tasks` für ein bekanntes Konto mit dem Text „noch keine Abschrift“ und `isError` ist nicht gesetzt.
- **AC-5:** `get_now` gibt mit der Beispielabschrift des Vertrags (zur Laufzeit gelesen, nicht abgeschrieben) `nowCount` unverändert aus; mit einem geänderten Wert (`nowCount` = 7 bei weiterhin drei Zeilen) kommt 7, nicht 3 (der Dienst zählt nicht neu).
- **AC-6:** `get_now` liefert die Zeilen in der Reihenfolge `knaeuel`, `today`, `lined`, `waiting`: für die Beispielabschrift die Kennungen `…0003` (Knäuel), `…0001` (heute), `…0002` (als nächstes) in dieser Reihenfolge, mit `group` je Zeile; bei einer Abschrift mit mehreren Kennungen je Gruppe bleibt die Reihenfolge innerhalb der Gruppe wie geliefert; ohne `knaeuel` beginnt die Liste mit `today`.
- **AC-7:** Jede Zeile von `get_now` trägt Kennung, Titel, Fälligkeit (`dueDate`, nur wenn die Aufgabe eine hat), `dueHasTime`, Status und `isKnaeuel` der Aufgabe aus `tasks` (Beispiel: „Müll rausbringen“ mit `dueDate` `2026-03-12T17:00:00Z`, `dueHasTime` wahr, `active`; „Steuer machen“ mit `isKnaeuel` wahr); `get_now` nennt zusätzlich `generatedAt`. Eine Kennung in `now`, die in `tasks` fehlt, erscheint nur mit `id` und `group`, ohne Fehler.
- **AC-8:** `list_tasks` liefert alle `tasks` der Beispielabschrift (drei) in der gelieferten Reihenfolge (auch umgestellt: ein Test mit vertauschter `tasks`-Liste behält die vertauschte Reihenfolge), jeweils mit genau den Feldern der Abschrift (`contexts`, `project`, `nextRank` wo vorhanden, sonst fehlend), und `generatedAt` der Abschrift.
- **AC-9:** Keine Ausgabe trägt Rohtext oder Notiz: die Texte beider Werkzeuge enthalten weder den Schlüssel `rawText` noch `note`; der Handler schreibt nichts nach `console`/`stdout` (Test: `process.stdout.write` und `console.log` werden während der Aufrufe überwacht, kein Aufruf).
- **AC-10:** Eine nach den Werkzeugaufrufen neu hochgeladene Abschrift (`putTranscript` mit neuerem `generatedAt`) wird beim nächsten Aufruf gelesen: der Handler hält keinen Zwischenspeicher (zustandslos).
- **AC-11:** `npm run typecheck` ist grün unter `erasableSyntaxOnly` mit den SDK-Typen von `@modelcontextprotocol/server`/`client` (Beleg: `npm run typecheck` im Abschlusslauf ohne Fehler; zeigt schon der RED-Lauf, dass das Type-Stripping mit den SDK-Typen unverträglich ist, wird das vor dem Weiterbauen offen gemeldet).
- **AC-12:** `package.json` enthält die drei Pakete mit festen Versionen ohne `^`/`~` (`@modelcontextprotocol/server` 2.4.0, `zod` 4.6.7 unter `dependencies`, `@modelcontextprotocol/client` 2.4.0 unter `devDependencies`); weder `@modelcontextprotocol/node` noch `hono` ist Abhängigkeit; `package-lock.json` ist erzeugt.
- **AC-13:** `getTranscript(pool, "henning")` liefert nach `putTranscript` die Abschrift gleich dem Dokument, für ein anderes Konto und ohne Zeile `undefined`.
- **AC-14:** `./server/scripts/test-local.sh` ist grün (Typprüfung und alle Tests gegen das Wegwerf-Postgres, auch die bestehenden Tests unverändert) und räumt auf; der Workflow `server.yml` ist auf dem PR grün.
- **AC-15:** Die Dateiliste des PR enthält außer `server/src/transcripts.ts`, `server/src/mcp.ts`, `server/test/mcp.test.ts`, `server/package.json` (samt `server/package-lock.json`) und `CLAUDE.md` nichts, ausgenommen die Workflow-Unterlagen `docs/specs/`, `docs/context/` und `docs/briefings/`. `server/migrations/`, `project.yml` und jede Swift-Datei bleiben unberührt; `CLAUDE.md` bekommt genau eine Zeile unter `server/`: MCP-Handler `mcpHandler` mit `get_now` und `list_tasks`, noch ohne Port und Anmeldung.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/transcripts.ts` | MODIFY | `getTranscript(pool, account)`, eine Anweisung, ~+6 |
| `server/src/mcp.ts` | CREATE | `mcpHandler(pool)` mit `get_now`, `list_tasks`, Konto aus `authInfo`, ~70 |
| `server/test/mcp.test.ts` | CREATE | Client im Prozess, ein `t.test` je Fall (AC-1 bis AC-13), ~115 |
| `server/package.json` (+ `package-lock.json`, generiert) | MODIFY | drei Pakete mit festen Versionen, ~+3 |
| `CLAUDE.md` | MODIFY | eine Zeile unter `server/`, ~+1 |

### Estimated Changes

- Files: 5 (Lockfile generiert, zählt nicht; innerhalb von 4–5)
- LoC: ≈ +190/−0 (Code ≈ 75, Tests ≈ 115). Das liegt unter 250; die Reserve beträgt etwa 60 Zeilen. Gefahr einer Überschreitung besteht beim Testaufbau (Client, Transport, `authInfo`), weil das Muster neu ist; wird das Limit absehbar überschritten, wird gestoppt und nachgefragt, nicht stillschweigend verlängert. Jede Funktion ≤ 50 Zeilen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Änderung an `project.yml`, keine Migration; `./scripts/sim.sh generate` ist nicht nötig. Keine Audiodateien. Keine Swift-Datei.
- Seiteneffekt außerhalb des Tickets: keiner. Nichts in der App und nichts im Dienst ruft `mcpHandler` auf, bis C7 ihn an einen Port hängt.

## Test Plan

### Automated Tests (TDD RED)

RED: `server/test/mcp.test.ts` wird zuerst geschrieben. Ohne `server/src/mcp.ts` und ohne die Pakete schlägt der Import fehl. Der Test liest die Beispielabschrift zur Laufzeit aus dem Vertrag (erster ```json-Block von genau drei, Muster aus `transcripts.test.ts`), befüllt sie über `putTranscript` und nutzt `freshPool(t)` mit `migrate` auf dem echten Migrationsordner; `server/test/db.ts` bleibt unverändert. Verbunden wird im Prozess mit `StreamableHTTPClientTransport` und `fetch: handler.fetch`; das Konto kommt über `authInfo` (ein Hilfsaufruf des Tests setzt es je Anfrage).

- [ ] Test 1 (AC-1): GIVEN der Handler WHEN `tools/list` THEN genau `get_now` und `list_tasks`.
- [ ] Test 2 (AC-2): GIVEN eine Abschrift für `henning`, aber kein `authInfo` WHEN beide Werkzeuge THEN `isError`, „kein Konto“, kein Titel in der Antwort.
- [ ] Test 3 (AC-3): GIVEN Abschrift für `henning` WHEN Konto `anna` fragt THEN „noch keine Abschrift“, kein Fehler, kein Titel.
- [ ] Test 4 (AC-4): GIVEN keine Abschrift WHEN beide Werkzeuge THEN „noch keine Abschrift“, kein `isError`.
- [ ] Test 5 (AC-5): GIVEN die Beispielabschrift (auch mit `nowCount` = 7) WHEN `get_now` THEN die Zahl unverändert.
- [ ] Test 6 (AC-6): GIVEN die Beispielabschrift und eine mit mehreren Kennungen je Gruppe, ohne Knäuel WHEN `get_now` THEN Reihenfolge `knaeuel`, `today`, `lined`, `waiting`, innerhalb der Gruppe wie geliefert.
- [ ] Test 7 (AC-7): GIVEN Aufgaben mit und ohne Fälligkeit, ein Knäuel und eine Kennung ohne Aufgabe WHEN `get_now` THEN Felder je Zeile wie beschrieben, fehlende Aufgabe nur mit `id`/`group`.
- [ ] Test 8 (AC-8): GIVEN die Beispielabschrift und eine mit vertauschten `tasks` WHEN `list_tasks` THEN alle Aufgaben in gelieferter Reihenfolge, Felder genau wie in der Abschrift, plus `generatedAt`.
- [ ] Test 9 (AC-9): GIVEN beide Werkzeuge WHEN aufgerufen THEN kein `rawText`/`note` in der Antwort und keine Ausgabe auf `console`/`stdout`.
- [ ] Test 10 (AC-10): GIVEN ein erster Aufruf WHEN eine neuere Abschrift gespeichert wird THEN der zweite Aufruf liefert die neue.
- [ ] Test 11 (AC-13): GIVEN `putTranscript` WHEN `getTranscript` für `henning`, ein anderes Konto und ohne Zeile THEN Dokument bzw. `undefined`.
- [ ] Prüfung AC-11/AC-12/AC-15: `npm run typecheck` grün; Durchsicht von `package.json` (feste Versionen, kein `node`/`hono`) und der Dateiliste des PR.
- [ ] Prüfung AC-14: `./server/scripts/test-local.sh` grün; Workflow `server.yml` grün auf dem PR.

Läufe: `./server/scripts/test-local.sh` (Gesamtkette des Servers), danach der Workflow `server.yml` auf dem PR.

**Keine UI-Tests:** Der Schnitt ändert keine Oberfläche und keinen sichtbaren Ablauf; nichts in der App ruft den Dienst auf.

## Alternativen

- **Ohne SDK, JSON-RPC von Hand:** keine neuen Abhängigkeiten, aber ein eigenes Nachbauen der Protokollrevision 2026-07-28 (zustandslos, `_meta`, `Mcp-Method`-Kopfzeilen) samt Rückwärtsweg für Clients der 2025er-Generation. Verworfen: Protokollcode ist genau das, was man kauft. Gekippt würde nur die Festlegung „MCP-SDK“ aus Hennings Beschreibung von Weg B (keine ADR).
- **Ein Sammelwerkzeug `create_order` mit dem Vertragsauftrag als Eingabe:** reicht die Form 1:1 durch, Claude müsste aber `id`, `expectedStatus`, `expectedDueDate` selbst setzen. Betrifft C4b und ist dort verworfen (je Art ein Werkzeug); gekippt wird nur der Name aus der Folgeschnitt-Liste in `docs/specs/spike-613-schnitt-1-abschrift-auftraege.md` (keine ADR).
- **Supabase-MCP statt eigenem Dienst:** nur Rückfall für die Anmeldung (OAuth), nicht für die Werkzeuge. Verworfen; gekippt würde Weg B als „eigener Dienst“ (#612, ADR-21 in C8).
- **Live-Stand vom Gerät statt Abschrift-Vorrat:** Claude fragte das Gerät direkt. Verworfen: das Gerät ist oft nicht erreichbar; der Vorrat ist Weg B selbst, `generatedAt` zeigt das Alter.
- **`get_now` zählt die Zeilen selbst:** wäre unabhängig von der App, aber eine zweite Quelle für die Zahl und gegen #637 („eine Zahl überall“). Verworfen.

## Nicht in diesem Schnitt / Folgeschnitte

- **C4b:** `capture_task`, `complete_task`, `set_due` (erwarteter Stand aus der Abschrift, Kennung des Auftrags vom Dienst), `getResult`, `get_order_result`. Eigener Workflow, eigene Spec.
- C6 Anmeldung und Konto aus echtem Token (liefert `authInfo`), C7 Betrieb auf Hetzner (Port, `@modelcontextprotocol/node`, `hono`, Rückholregel), C8 ADR-21; #621 verbindet Claude.
- Zugriffsprotokoll, Begrenzung der Aufrufe und Zeitlimit: erst mit dem Betrieb (C7).

## Abnahme

- Stufe 1: `./server/scripts/test-local.sh` grün (Typprüfung und alle Servertests gegen echtes Postgres); der Workflow `server.yml` grün auf dem PR.
- Stufe 2: Pflicht für den Abschluss. `./scripts/sim.sh test-proof CaptureSmokeTests` liefert den maschinellen Simulator-Beleg aus einem echten Lauf auf dem aktuellen Stand (Commit-Kennung und Zeitstempel passen), nie von Hand gesetzt. Der Beleg zeigt, dass die App auf dem Stand startet und erfasst; ein Bedienablauf für die Werkzeuge existiert noch nicht, weil nichts in der App und kein Port sie aufruft.
- Stufe 3: entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-15 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, Workflow `server.yml` grün
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #613 kommentiert (Stand C4a, Folgeschnitte C4b bis C8), Board-Karte aktuell

## Changelog

- 2026-11-01: Initial spec created (Schnitt C4a)
