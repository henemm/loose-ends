---
entity_id: feat-613-c4b2-mcp-complete-setdue
type: feature
created: 2026-11-02
updated: 2026-11-02
status: draft
workflow: feat-613-c4b2-mcp-complete-setdue
---

# Spec: MCP-Werkzeuge complete_task und set_due, Schnitt C4b-2 (#613, Weg B „Fenster für Claude“)

## Approval

- [ ] Approved

## GitHub Issue

#613 (Spike, Epic #612). Schnitt C4b-2; das Issue bleibt offen (`Refs #613`, nie `Closes #613`).
Vorgänger: C4b-1 (`docs/specs/spike-613-schnitt-c4b1-mcp-erfassen-ergebnis.md`, PR #805), C4a (Lesen), C3b (Aufträge), Vertrag v1 (`docs/reference/claude-abschrift-vertrag.md`, Abschnitt „Auftrag“).
Analyse: `docs/context/feat-613-c4b2-mcp-complete-setdue.md`. Nicht Teil dieser Spec: Anmeldung und Konto (C6), Port und Betrieb (C7), ein Gerätekanal in der App.

## Purpose

Claude kann seit C4b-1 erfassen und den Stand eines Auftrags lesen, aber keine bestehende Aufgabe ändern. Dieser Schnitt liefert die zwei übrigen Auftragsarten des Vertrags:
`complete_task` (abhaken) und `set_due` (Fälligkeit setzen oder entfernen). Wie `capture_task` legen sie nur einen Auftrag an; ausgeführt wird er später auf einem Gerät (`OrderExecutor`, Grund „Claude“).

Jeder Auftrag trägt den **erwarteten Stand** (`expectedStatus`, `expectedDueDate`). Den bildet der Dienst aus der letzten Abschrift, nicht Claude. Damit er mit dem übereinstimmt, was Claude gesehen hat, nennt Claude die `generatedAt` der Abschrift, auf die sich seine Entscheidung stützt; weicht sie ab, entsteht kein Auftrag (schließt die Lücke „Abschrift wurde zwischen Lesen und Schreiben erneuert“).

**Regeln vor Modell:** Nachschlagen, Auftrag bauen, speichern: SQL und Regel. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt, es gibt keine Sprachaufgabe.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Weg B ist in #612 entschieden (ADR-21 folgt in C8); dieser Schnitt setzt die zwei übrigen Auftragsarten um.

## Source

**Files:** `server/src/mcp.ts`, `server/test/mcp.test.ts`
**Identifier:** `complete_task`, `set_due`, `completing`, `setting`, `expected`

### Gemeinsamer Ablauf (Helfer `expected`)

Reihenfolge je Aufruf, beide Werkzeuge gleich; jeder Fehler ist `isError: true` mit kurzem deutschem Text, nie eine Ausnahme, und kommt **vor** dem Schreiben:

1. Konto aus `authInfo`, sonst „kein Konto“ (vor jedem Lesen).
2. Letzte Abschrift holen (`getTranscript`), sonst „noch keine Abschrift“.
3. `generatedAt` der Eingabe muss der der Abschrift gleichen (Textvergleich), sonst „Abschrift hat sich geändert, bitte neu lesen“.
4. Aufgabe in `tasks` suchen (`taskID` ohne Rücksicht auf Groß-/Kleinschreibung), sonst „Aufgabe nicht in der Abschrift“ (so auch eine schon erledigte: die Abschrift führt kein `done`). Im Auftrag steht die **Kennung aus der Abschrift**, nicht die Eingabe.
5. Auftrag bauen, `id` = `randomUUID().toUpperCase()`, `version` 1; `expectedStatus` = `status`; `expectedDueDate` = `dueDate`, **der Schlüssel fehlt**, wenn die Abschrift keine Fälligkeit führt. Umsetzung: bedingter Spread (`...(x === undefined ? {} : { key: x })`, Muster `nowRows`), nie ein Schlüssel mit Wert `undefined`: `checkOrder` prüft mit `Object.hasOwn` und lehnte ihn als fehlerhaften Zeitpunkt ab.
6. `checkOrder` (Meldung unverändert zurück, keine zweite Prüfung), `putOrder`, Antwort `{ "orderID": "<Kennung>", "state": "waiting" }`.

### Werkzeuge

- **`complete_task`:** Eingabe `taskID`, `generatedAt` (Zod nur `z.string()`; ein Schemafehler käme als JSON-RPC-Fehler ohne `isError`, die Formprüfung macht `checkOrder`). Auftrag `{ version, id, kind: "complete", taskID, expectedStatus, expectedDueDate? }`.
- **`set_due`:** Eingabe `taskID: z.string()`, `generatedAt: z.string()`, `date: z.string().optional()` (fehlt = Fälligkeit entfernen), `hasTime: z.boolean().optional()` (fehlt = falsch; ohne `date` immer falsch, also `hasTime = date !== undefined && (hasTime ?? false)`). Auftrag `{ version, id, kind: "setDue", taskID, hasTime, date?, expectedDueDate? }`; fehlt `date`, fehlt der Schlüssel (bedingter Spread). Ein ungültiges `date` (kein Zeitpunkt mit Zone, ungültiger Kalendertag) meldet `checkOrder`. Die Beschreibung nennt das Format des Vertrags (UTC, ganze Sekunden, `Z`); der Dienst ist bewusst nachsichtiger und lässt jede Zone und Bruchsekunden durch, wie `checkOrder` es seit C3b tut. Getestet wird mit `Z`.
- **Annotationen beider:** `readOnlyHint` falsch, `destructiveHint` falsch (alles über Revisionen), `idempotentHint` falsch (`complete_task` rollt eine wiederkehrende Aufgabe weiter, ein zweiter `set_due` ist ein zweiter Auftrag). Beschreibung von `set_due` zusätzlich: Ein Zeitpunkt, den die Aufgabe schon hat, mit nur geändertem `hasTime` wird vom Gerät als `invalid` abgelehnt (#777); der Dienst prüft das nicht (Bedeutung bleibt beim Gerät), Claude erfährt es über `get_order_result`. Beschreibung beider: zuerst `list_tasks` oder `get_now` lesen und deren `generatedAt` mitgeben; ausgeführt wird auf einem Gerät; Stand über `get_order_result`.
- **Abweichung von C4a:** Fehlt die Abschrift, melden die Schreibwerkzeuge `isError` (anders als `get_now`/`list_tasks`): ein Auftrag ohne Stand wäre ein Fehlschlag, kein leeres Ergebnis.
- **Datenschutz:** Antwort nur `orderID` und `state`, nie ein Titel; nichts nach `console`/`stdout`, keine Kennung und kein Datum in Logs.

`server/src/orders.ts`, `transcripts.ts`, Migrationen sind unverändert (`complete`/`setDue` und ihre Formprüfung gibt es seit C3b).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/src/orders.ts` (`checkOrder`, `putOrder`, `claimOrder`, `putResult`) | bestehend, **unverändert** |
| `server/src/transcripts.ts` (`getTranscript`, `putTranscript`) | bestehend, **unverändert**, Quelle des erwarteten Stands |
| `server/src/mcp.ts`, `server/test/mcp.test.ts` (C4a/C4b-1) | Muster: `capturing`, Prozess-Client mit `authInfo` je Anfrage |
| `server/test/db.ts` (`freshPool`), Beispielabschrift aus dem Vertrag | Testaufbau gegen echtes Postgres |
| `@modelcontextprotocol/server`, `zod`, `node:crypto` | bestehend, **keine neuen Pakete** |

## Acceptance Criteria

Alle Tests in `server/test/mcp.test.ts` (im Prozess, kein Port, echtes Postgres); Testnamen tragen das Suffix „(C4b-2)“, damit die AC-Nummern nicht mit denen von C4b-1 verwechselt werden.

- **AC-1:** `tools/list` nennt genau `capture_task`, `complete_task`, `get_now`, `get_order_result`, `list_tasks`, `set_due` (sortierte Namensliste); `complete_task` und `set_due` tragen `readOnlyHint` falsch, `destructiveHint` falsch, `idempotentHint` falsch; ihre Beschreibung nennt `list_tasks` und `get_order_result`.
- **AC-2:** Ohne `authInfo` lehnen beide ab (`isError`, „kein Konto“); die Zeilenzahl in `orders` bleibt gleich.
- **AC-3:** Ohne gespeicherte Abschrift antworten beide mit `isError` und „noch keine Abschrift“, kein Auftrag.
- **AC-4:** Mit abweichender `generatedAt` antworten beide mit `isError` und „Abschrift hat sich geändert, bitte neu lesen“, kein Auftrag; mit gleicher wird ein Auftrag angelegt.
- **AC-5:** Eine `taskID`, die die Abschrift nicht führt (unbekannt, oder eine Aufgabe, die eine ältere Abschrift führte und die neue nicht mehr), ergibt `isError` und „Aufgabe nicht in der Abschrift“, kein Auftrag. Die `taskID` in Kleinbuchstaben findet die Aufgabe, der Auftrag trägt die Großbuchstaben-Kennung der Abschrift.
- **AC-6:** `complete_task` für eine Aufgabe mit Fälligkeit legt genau einen Auftrag des Kontos an: Antwort `orderID` (Großbuchstaben, UUID-Form) und `state` „waiting“; die Zeile hat `kind` `complete`, `expectedStatus` = Status der Abschrift, `expectedDueDate` = Fälligkeit der Abschrift, `claimed_by` leer; `checkOrder` nimmt das Dokument an. Für eine Aufgabe ohne Fälligkeit fehlt der Schlüssel `expectedDueDate`.
- **AC-7:** `set_due` mit `date` und `hasTime` wahr legt einen `setDue`-Auftrag mit genau diesen Werten und dem erwarteten Stand (`expectedDueDate` aus der Abschrift, Schlüssel weg bei keiner Fälligkeit) an; ohne `hasTime` ist es falsch; ohne `date` fehlt der Schlüssel `date` und `hasTime` ist falsch, auch wenn `hasTime` wahr übergeben wurde.
- **AC-8:** `set_due` mit ungültigem `date` (z. B. „morgen“, ohne Zone, 30. Februar) legt keinen Auftrag an und antwortet mit `isError` und der Meldung von `checkOrder`.
- **AC-9:** Zwei Aufrufe mit gleichen Eingaben erzeugen zwei Aufträge mit verschiedenen Kennungen; `get_order_result` meldet für eine Kennung daraus `waiting`.
- **AC-10:** Die Antworten enthalten keinen Aufgabentitel; ein anderes Konto (`anna`) kann die Aufgabe von `henning` nicht ändern (für sie „noch keine Abschrift“ oder „Aufgabe nicht in der Abschrift“) und legt keinen Auftrag an.
- **AC-11:** Weder `complete_task` noch `set_due` schreibt etwas nach `console`/`stdout`.
- **AC-12:** `npm run typecheck` und `./server/scripts/test-local.sh` sind grün (bestehende Tests unverändert, bis auf die Werkzeugliste in den C4a/C4b-1-Tests, die sechs Namen nennt) und räumen auf; `server.yml` ist auf dem PR grün.
- **AC-13:** Die Dateiliste des PR enthält außer `server/src/mcp.ts`, `server/test/mcp.test.ts` und `CLAUDE.md` nichts, ausgenommen `docs/specs/`, `docs/context/`, `docs/briefings/`. `server/src/orders.ts`, `transcripts.ts`, `server/migrations/`, `server/package.json`, `project.yml` und jede Swift-Datei bleiben unberührt. `CLAUDE.md` nennt in der `server/`-Zeile zusätzlich `complete_task`, `set_due`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/mcp.ts` | MODIFY | `expected`, `completing`, `setting`, zwei `registerTool`, ~+50 |
| `server/test/mcp.test.ts` | MODIFY | beide Werkzeuge über den Prozess-Client, Werkzeugliste sechs, ~+120 |
| `CLAUDE.md` | MODIFY | Zusatz in der `server/`-Zeile, ~+1 |

### Estimated Changes

- Files: 3 (innerhalb von 4–5)
- LoC: ≈ +170/−3 (Code ≈ 50, Tests ≈ 120); unter 250. Zeichnet sich eine Überschreitung ab, wird gestoppt und nachgefragt. Jede Funktion ≤ 50 Zeilen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Migration, keine neuen Pakete, kein `generate`. Seiteneffekt außerhalb des Tickets: keiner; nichts in der App ruft den Dienst auf.

## Test Plan

### Automated Tests (TDD RED)

RED: Die Tests zuerst; `complete_task` und `set_due` fehlen, die Aufrufe schlagen fehl.

- [ ] Test 1 (AC-1): GIVEN der Handler WHEN `tools/list` THEN sechs Namen, Annotationen, Beschreibung.
- [ ] Test 2 (AC-2, AC-3): GIVEN kein `authInfo` bzw. keine Abschrift WHEN beide Werkzeuge THEN Fehlertext, `orders` unverändert.
- [ ] Test 3 (AC-4, AC-5): GIVEN die Beispielabschrift WHEN abweichende `generatedAt`, unbekannte `taskID`, `taskID` in Kleinbuchstaben THEN Fehler bzw. Auftrag mit Kennung aus der Abschrift.
- [ ] Test 4 (AC-6): GIVEN Aufgabe mit und ohne Fälligkeit WHEN `complete_task` THEN Auftragszeile wie beschrieben, `checkOrder` nimmt sie an.
- [ ] Test 5 (AC-7, AC-8): GIVEN Aufgabe mit und ohne Fälligkeit WHEN `set_due` mit `date`+`hasTime`, ohne `hasTime`, ohne `date` (mit `hasTime` wahr), mit ungültigem `date` THEN Zeilen bzw. Fehler.
- [ ] Test 6 (AC-9, AC-10, AC-11): GIVEN zwei gleiche Aufrufe, Konto `anna`, überwachte Ausgabe THEN zwei Kennungen, `waiting`, kein Titel, kein Fremdzugriff, keine Ausgabe.
- [ ] Prüfung AC-12/AC-13: `./server/scripts/test-local.sh` grün; Dateiliste des PR; `server.yml` grün.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A: Claude übergibt den erwarteten Stand selbst** (`expectedStatus`, `expectedDueDate` als Eingabe): braucht kein `generatedAt`, aber Claude müsste Felder fehlerfrei abschreiben, die Oberfläche wird sperrig; kippt die Entscheidung „Erwarteter Stand kommt vom Dienst“. Nicht gewählt.
- **B: ein Werkzeug `change_task(kind, …)`:** weniger Registrierungen, aber eine Union-Eingabe mit Pflichtfeldern je Art; zwei klar benannte Werkzeuge mit eigenen Annotationen lesen sich für ein Modell besser. Nicht gewählt.
- **C: ohne `generatedAt`, Dienst nimmt die neueste Abschrift:** einfacher, lässt aber die Lücke offen, dass Claude auf Basis von „Montag“ entscheidet und der Auftrag „Dienstag“ als erwarteten Stand trägt. Nicht gewählt.
- **Vorschlag statt Auftrag** (Claude schlägt vor, Henning bestätigt in der App): kein Schreibweg nötig, kippt aber „Aufträge als Nutzeränderung“ aus Weg B. Nicht gewählt, der Vertrag steht.

## Nicht in diesem Schnitt / Folgeschnitte

- C6 Anmeldung, C7 Betrieb (Port, Handler anhängen), C8 ADR-21; ein Gerätekanal (Abholen in der App) ist offen, bis dahin bleiben Aufträge „wartet auf ein Gerät“.
- Die Ausführung auf dem Gerät (`OrderExecutor`) prüft dieser Schnitt nicht; er beweist nur, dass ein formgerechter Auftrag mit erwartetem Stand entsteht.

## Abnahme

- Stufe 1: `./server/scripts/test-local.sh` grün; `server.yml` grün auf dem PR.
- Stufe 2: Pflicht für den Abschluss. `./scripts/sim.sh test-proof CaptureSmokeTests` liefert den maschinellen Beleg aus einem echten Lauf auf dem aktuellen Stand; er zeigt nur, dass die App auf dem Stand startet und erfasst, ein Bedienablauf für die Werkzeuge existiert nicht.
- Stufe 3: entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #613 kommentiert (Stand C4b-2), Board-Karte aktuell

## Changelog

- 2026-11-02: Initial spec created (Schnitt C4b-2)
