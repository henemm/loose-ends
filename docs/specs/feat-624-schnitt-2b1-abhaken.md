---
entity_id: feat-624-schnitt-2b1-abhaken
type: feature
created: 2026-11-17
updated: 2026-11-17
status: draft
workflow: feat-624-s2b-knoepfe
---

# Spec: Ansicht der App im Chat, Schnitt 2b-1 (Abhaken aus dem Fenster, #624)

## Approval

- [ ] Approved

## GitHub Issue

#624 (Epic #612). Schnitt 2b-1 von vier (2a gebaut; 2b ist geteilt in 2b-1 und 2b-2; danach Schnitt 3). Das Issue bleibt offen
(PR mit `Refs #624`, nie `Closes #624`).
Analyse: `docs/context/feat-624-s2b-knoepfe.md` (Abschnitte „Protokoll“, „Analysis“, besonders „Nachtrag Analyse 2026-11-17“:
dort ist der Schnitt in 2b-1 und 2b-2 geteilt, weil Code und Tests zusammen die 250 LoC sprengen). Vorgänger:
`docs/specs/feat-624-schnitt-2a-anzeige.md` (PR #942/#943, ausgerollt, am echten Host belegt). Entwurf:
`docs/artifacts/feat-624-mcp-app/entwurf.html`, vom PO am 2026-11-16 freigegeben (Knopf, Wartezeile, grüner Haken sind darin).

## Purpose

Das Fenster zu `get_view` bekommt den ersten schreibenden Knopf: ein Kreis links an jeder Zeile hakt die Aufgabe ab. Der Tipp
schickt `complete_task` an den Dienst, die Zeile zeigt „Abgehakt, wartet auf dein Gerät …“, das Fenster fragt `get_order_result`
im Takt ab und zeigt bei Erfolg den grünen Haken, danach liest es die Ansicht neu. So wird aus „Claude, hake das ab“ ein Tipp
im Chat, ohne dass der Nutzer ein Wort schreibt. Der Knopf erscheint nur, wenn der Host dem Fenster `tools/call` erlaubt
(`hostCapabilities.serverTools`); sonst bleibt alles wie in Schnitt 2a.

**Regeln vor Modell:** kein Modellaufruf, keine Sprachaufgabe; Zustandsübergänge, Takt und Zeitgrenze sind feste Regeln. Der Satz
„Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- **Schnitt 2b-2:** Pfeil „Als nächstes“ (`set_next`) und die Etiketten aus `contexts` an den Zeilen von „Jetzt“ (ändert
  `server/src/mcp.ts`). Die Auftragsmaschine aus diesem Schnitt wird dort unverändert benutzt.
- **Schnitt 3:** Detail über `get_task`, Claude Desktop, Bilder hell/dunkel ins Ticket.
- `server/src/mcp.ts`, `server/src/orders.ts`, `server/src/anleitung.ts`, die App und jede Migration bleiben unberührt.
- Keine neue Abhängigkeit, kein `_meta.ui.csp`, kein zweites Skript.
- Kein Knopf für Knäuel oder Perle (#648); der Kreis hakt nur ab. Er steht am Knäuel wie an jeder Zeile.
- Kein Gerät von Henning beteiligt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — der Weg über den MCP-Dienst (ADR-21, Weg B) bleibt; das Fenster ruft nur vorhandene Werkzeuge
  (`complete_task`, `get_order_result`, `get_view`) über das Standard-`tools/call` der MCP-Apps-Erweiterung auf. Kein neuer
  Vertrag, kein Schema, keine Migration.

## Source

**Files:** `server/src/app-ui.ts`, `server/test/app-client.test.ts`, `CLAUDE.md`
**Identifier:** `reduce` (neue Ereignisse `tap`/`tick`, Rückgabe `later`), `rowsHtml` (Knopf, Zustandszeilen), `State`
(`caps`, `nextId`, `pending`, `rows`), `shell` (Klick-Listener, `setTimeout`)

## Implementation Details

### Quelle der Fähigkeit

`reduce` liest bei der Antwort auf `ui/initialize` (id 1) `result.hostCapabilities` und merkt `caps.serverTools` (vorhanden =
Objekt, auch leer; fehlt der Eintrag oder `hostCapabilities`, ist es aus). Spec: MCP Apps 2026-01-26, Schnittstelle
`McpUiHostCapabilities`: `serverTools` heißt, dass der Host `tools/call` an den Server weiterreicht. Quellen:
https://apps.extensions.modelcontextprotocol.io/api/interfaces/app.McpUiHostCapabilities.html,
https://apps.extensions.modelcontextprotocol.io/api/documents/overview.html. Ob claude.ai den Eintrag setzt, ist öffentlich
nicht belegt und ist der erste Prüfpunkt der Sichtprüfung (Stufe 2).

### Zustand und Ereignisse

- `State` wächst um `caps` (`serverTools` ja/nein), `nextId` (Zähler, erste Anfrage nach dem Handshake id 2; id 1 bleibt
  `ui/initialize`), `pending` (Anfrage-id → Zweck: `complete`, `poll`, `reread`, je mit `taskID`) und `rows` (taskID →
  `{ order?, phase: waiting | done | rejected | late | failed, polls }`).
- `reduce(state, message)` nimmt zusätzlich Ereignisse der Hülle: `{ kind: "tap", taskID }` und `{ kind: "tick", taskID }`.
  Rückgabe zusätzlich `later: [{ ms, event }]` für Timer; nur `shell` führt sie mit `setTimeout` aus. `reduce` bleibt rein:
  kein DOM, keine Uhr, kein `postMessage`.
- Antworten werden über `message.id` dem Zweck in `pending` zugeordnet; unbekannte ids werden ignoriert.

### Ablauf einer Zeile

1. **Tipp** (`tap`): gilt nur mit `caps.serverTools`, nur für eine taskID, die in den Zeilen der gelesenen Ansicht steht, und
   nur wenn die Zeile keine `rows`-Phase `waiting` hat. Dann ein `tools/call` mit `name: "complete_task"` und
   `arguments: { taskID, generatedAt }` (`generatedAt` der gelesenen Ansicht), eigene id ab 2, Phase `waiting`. Ein weiterer
   Tipp auf dieselbe Zeile in der Phase `waiting` erzeugt nichts.
2. **Antwort auf `complete_task`:** `result.content[0].text` ist JSON `{ orderID, state }`; die `orderID` wird gemerkt, dann
   `later: [{ ms: 3000, event: tick }]`. `isError` mit dem Text „Abschrift hat sich geändert, bitte neu lesen“ → genau ein
   `tools/call` `get_view` mit der Ansicht der gelesenen Abschrift (`arguments: { view }`), Zeile ohne Auftrag zurück (kein
   Zustand in `rows`); kommt nach dem erneuten Lesen wieder dieselbe Ablehnung, zeigt die Zeile „Hat nicht geklappt.“ und es
   gibt kein drittes Lesen. Anderer Fehler oder JSON-RPC-`error`: Phase `failed`.
3. **Takt** (`tick`): `tools/call` `get_order_result` mit `{ orderID }`, `polls` + 1. Antwort: `state` `waiting` oder `claimed`
   → nächster `tick` nach 3 s, solange `polls` < 20 (höchstens 20 Abfragen, 60 s); ist `polls` 20 erreicht ohne Ergebnis,
   Phase `late` und kein `later` mehr. `state` `result` mit `outcome: done` → Phase `done`, danach ein `get_view` (gleiche
   Ansicht) zum Neulesen. `outcome: rejected` (Grund `invalid`, `missing` oder `stale`) → Phase `rejected` und `get_view`
   zum Neulesen. `state` `unknown` oder ein Fehler → Phase `failed`.
4. **Antwort auf `get_view`:** `CallToolResult` wie beim `tool-result`, geht durch `readView`; bei Erfolg neue Ansicht und
   neu zeichnen, die Zustände der Zeilen in `rows`, die in der neuen Ansicht nicht mehr stehen, fallen weg. Unlesbar → die
   ruhige Zeile aus Schnitt 2a.
5. **Teardown** (`ui/resource-teardown`): zusätzlich zur Antwort mit `{}` setzt `reduce` ein Ende-Zeichen im Zustand; `shell`
   beendet alle laufenden Timer (`clearTimeout`) und führt danach keinen `later`-Eintrag und keinen `tick` mehr aus.

### Anzeige

- Kreisknopf links in der Zeile (`<button>` mit `aria-label="Abhaken"`, `data-act="complete"`, `data-id` escaped), Trefferfläche
  44 px, Akzent `#0F6E73` hell und `#5FC4C9` dunkel (Akzent = antippbar). Nur mit `caps.serverTools`, in allen vier Ansichten,
  auch am Knäuel. Ohne `caps.serverTools` erzeugt `rowsHtml` dieselbe Ausgabe wie in Schnitt 2a (Byte für Byte).
- Wartezeile: „Abgehakt, wartet auf dein Gerät …“ in Grau und kursiv, ruhig, ohne Knopf.
- Abschlussmoment: grüner Haken (`#3E8C5F` hell, `#35925A` dunkel, nur dieser Moment trägt Grün) und durchgestrichener Titel.
- Ruhige Zeilen (grau, kein Rot, kein Host-Fehlertext): `rejected` „Nicht übernommen – die Aufgabe hat sich geändert.“,
  `late` „Noch nicht übernommen – dein Gerät holt es beim nächsten Öffnen.“, `failed` „Hat nicht geklappt.“
- Klick: ein Listener auf `#list` (Ereignisweitergabe), liest `data-act` und `data-id` des angeklickten Knopfes und gibt nur
  das Ereignis `{ kind: "tap", taskID }` an `reduce`; die id wird dort gegen die Zeilen der gelesenen Ansicht geprüft, nie
  gegen den DOM-Text.
- Titel und jeder Nutzertext laufen in jedem Zustand durch `escape`; weiter genau ein inline-Skript, kein `src=`,
  `http://`, `https://`, `@import`, kein `xmlns`.

### Ausrollen und Sichtprüfung (Teil der Abnahme)

Nach dem Merge: Ausrollen auf `rennwienix` mit `scripts/deploy-loose-ends.sh` und `LE_COMMIT` (per `ssh rennwienix bash -s`);
Rückweg: vorheriger `LE_COMMIT`. Sichtprüfung in claude.ai im Chrome, Connector „Loose Ends“:

1. Erster Prüfpunkt: meldet claude.ai `serverTools`? Erscheint der Kreisknopf? Meldet es ihn nicht, bleibt das Fenster ohne
   Knopf (Stand 2a, kein Schaden); das wird belegt, und Alternative B (`ui/message`) wird der Weg für Schnitt 2b-2.
2. Abgehakt wird **nur** eine eigens per `capture_task` angelegte Prüfaufgabe („Prüfaufgabe Fenster #624 – darf abgehakt
   werden“), nie eine echte Aufgabe von Henning.
3. Belegt werden Knopf und Wartezeile, hell und dunkel. Der Auftrag wird erst auf Hennings Gerät ausgeführt, wenn dort eine
   App läuft; der Haken-Zustand gilt nur als belegt, wenn das Ergebnis in den 60 s eintrifft, sonst dient die Zeile „Noch nicht
   übernommen …“ als Beleg und der Bericht sagt das.
4. Kein Eingriff auf Hennings Geräten; die Prüfaufgabe bleibt, falls nicht ausgeführt, offen und wird dem Bericht nach
   genannt.

Belege unter `docs/artifacts/feat-624-s2b1-abhaken/` (Bilder werden geöffnet und beschrieben).

### Dokumentation

`CLAUDE.md`, Eintrag `src/app-ui.ts` nachführen: #624 S2b-1, Kreisknopf „Abhaken“ nur mit `hostCapabilities.serverTools`,
`complete_task` mit `generatedAt`, Abfrage `get_order_result` alle 3 s bis 20 Abfragen, Neulesen per `get_view`, `reduce`
mit `tap`/`tick`/`later`, Pfeil und Etiketten folgen in S2b-2.

## Dependencies

| Entität | Art | Zweck |
|---|---|---|
| `server/src/app-ui.ts` (S2a) | bestehend | `reduce`, `rowsHtml`, `readView`, `paint`, `shell`; wird erweitert |
| `server/src/mcp.ts` (`complete_task`, `get_order_result`, `get_view`) | bestehend, unverändert | Aufrufziele; Ablehnung „Abschrift hat sich geändert, bitte neu lesen“ (Zeile 102), Antwort `{ orderID, state }` (Zeile 126) |
| `server/src/orders.ts` (`getResult`, `OrderResult`) | bestehend, unverändert | `state` `unknown`/`waiting`/`claimed`/`result`, `outcome` `done`/`rejected`, `reason` |
| MCP-Erweiterung `io.modelcontextprotocol/ui` (Spec 2026-01-26) | extern, Spec | `hostCapabilities.serverTools`, `tools/call` aus dem Fenster |
| `docs/artifacts/feat-624-mcp-app/entwurf.html` | bestehend | Knopfgestalt, Wartezeile, grüner Haken |
| `scripts/deploy-loose-ends.sh` (henemm-infra) | extern | Ausrollen auf `rennwienix` |
| claude.ai, Connector „Loose Ends“ | extern, live | Host für die Sichtprüfung |
| App-Teil des Weckrufs (#795 S5c-2) | offen, parallel | ohne ihn führt eine geschlossene App den Auftrag erst beim nächsten Öffnen aus |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung | LoC |
|---|---|---|---|
| `server/src/app-ui.ts` | MODIFY | `State`, `reduce` (`tap`, `tick`, `later`, Antworten nach id, Teardown), Knopf und Zustandszeilen in `rowsHtml`, CSS, Klick-Listener und Timer in `shell` | +100 |
| `server/test/app-client.test.ts` | MODIFY | tabellarische Tests der Zustandsfolge, ein `vm`-Test mit Fake-Host | +110 |
| `CLAUDE.md` | MODIFY | Eintrag `src/app-ui.ts` | +1/-1 |

### Estimated Changes

- Files: 3 (Produktcode 1, Tests 1, Doku 1).
- LoC: etwa +210/-2, unter der Grenze von ±250. Die Tests bündeln Fälle tabellarisch (eine Schleife über Antwortfolgen
  und über die vier Ansichten). Läuft der Schnitt trotzdem über, kürzt er die Tests, nicht die Zustandsfälle, und der
  Überhang wird vor dem Bauen benannt.

## Test Plan

### Automated Tests (TDD RED)

Dienst-Tests (`node:test`) über `./server/scripts/test-local.sh`. Reine Funktionen direkt importiert; die Hülle mit `node:vm`
gegen ein Fake-`window`/`document` aus dem echten `viewHtml`, dessen `parent` jede ausgehende Nachricht sammelt und dessen
Timer ein Test von Hand auslöst.

- [ ] Test 1: GIVEN eine Antwort auf `ui/initialize` mit und ohne `hostCapabilities.serverTools` und alle vier Ansichten (auch eine Knäuel-Zeile) WHEN `rowsHtml` und der Handshake laufen THEN trägt jede Zeile mit `serverTools` einen Knopf mit `aria-label` „Abhaken“; ohne ist die Ausgabe gleich der aus Schnitt 2a und ein Tipp erzeugt weder `tools/call` noch Zustand.
- [ ] Test 2: GIVEN eine gelesene Ansicht und `serverTools` WHEN `tap` auf eine Zeile THEN geht genau ein `tools/call` `complete_task` mit `{ taskID, generatedAt }` der Ansicht und einer id ≥ 2 hinaus; ein zweiter `tap` auf dieselbe Zeile erzeugt nichts; ein `tap` mit einer taskID, die nicht in der Ansicht steht, erzeugt nichts.
- [ ] Test 3: GIVEN der Tipp aus Test 2 WHEN gezeichnet THEN zeigt die Zeile „Abgehakt, wartet auf dein Gerät …“ und keinen Knopf.
- [ ] Test 4: GIVEN die Antwort `{ orderID, state: "waiting" }` WHEN die Abfragen laufen mit `waiting`, `claimed`, dann `result` mit `outcome: done` THEN geht je `tick` ein `get_order_result` mit der `orderID` hinaus (ms 3000 in `later`), danach zeigt die Zeile den grünen Haken mit durchgestrichenem Titel und es geht ein `get_view` mit der gleichen Ansicht hinaus; dessen Antwort zeichnet die neue Ansicht.
- [ ] Test 5: GIVEN `result` mit `outcome: rejected` (je Grund `invalid`, `missing`, `stale`) und `state: unknown` WHEN verarbeitet THEN zeigt die Zeile „Nicht übernommen – die Aufgabe hat sich geändert.“ (bei `unknown` „Hat nicht geklappt.“), und nach `rejected` geht ein `get_view` hinaus.
- [ ] Test 6: GIVEN `complete_task` antwortet mit `isError` „Abschrift hat sich geändert, bitte neu lesen“ WHEN verarbeitet THEN geht genau ein `get_view` hinaus, die Zeile ist ohne Auftrag zurück (Knopf wieder da); bei einer zweiten gleichen Ablehnung nach dem Tipp zeigt sie „Hat nicht geklappt.“ und es geht kein drittes `get_view` hinaus.
- [ ] Test 7: GIVEN `waiting` bei jeder Abfrage WHEN die 20. Abfrage beantwortet ist THEN zeigt die Zeile „Noch nicht übernommen – dein Gerät holt es beim nächsten Öffnen.“ und `later` ist leer; es gab genau 20 Abfragen.
- [ ] Test 8: GIVEN eine JSON-RPC-`error`-Antwort auf `complete_task` oder `get_order_result` und ein anderer `isError`-Text WHEN verarbeitet THEN zeigt die Zeile „Hat nicht geklappt.“, kein Host-Fehlertext im HTML.
- [ ] Test 9: GIVEN im `vm`-Test ein laufender Takt WHEN `ui/resource-teardown` mit `id` 7 kam THEN antwortet das Fenster `{ id: 7, result: {} }`, die Timer sind beendet, und ein danach ausgelöster Timer erzeugt keine Abfrage.
- [ ] Test 10: GIVEN ein Titel mit `<b>&"'` und ein Knopf-`data-id` WHEN `rowsHtml` in den Phasen Knopf, `waiting`, `done`, `rejected`, `late`, `failed` läuft THEN steht der Titel in jeder nur als Entities, die `data-id` escaped, kein rohes `<b>`.
- [ ] Test 11: GIVEN `viewHtml` und die Tests aus Schnitt 1 und 2a WHEN der Lauf THEN genau ein `<script`, kein `src=`, `http://`, `https://`, `@import`, `xmlns`, und alle S1- und S2a-Tests bleiben grün; `server/src/mcp.ts` ist unverändert.

### Abnahme

Stufe 1: Tests 1–11 rot vor, grün nach der Umsetzung; `./server/scripts/test-local.sh` grün.
Stufe 2: Ausrollen und Sichtprüfung in claude.ai (siehe Implementation Details): erster Prüfpunkt `serverTools`; Knopf und
Wartezeile an der Prüfaufgabe, hell und dunkel; Haken-Zustand oder Zeile „Noch nicht übernommen …“ je nachdem, ob das
Ergebnis in 60 s eintrifft; Belege geöffnet und beschrieben.
Stufe 3: Kein Pfad der Geräteliste berührt. Geprüft gegen die Tabelle in `CLAUDE.md`: nur `server/` und `CLAUDE.md`.

## Acceptance Criteria

- **AC-1:** Der Kreisknopf „Abhaken“ erscheint nur, wenn die Antwort auf `ui/initialize` `hostCapabilities.serverTools` enthält, an jeder Zeile aller vier Ansichten, auch am Knäuel; ohne `serverTools` ist die Anzeige gleich Schnitt 2a und das Fenster sendet kein `tools/call` (Test 1).
- **AC-2:** Ein Tipp sendet genau ein `tools/call` `complete_task` mit `{ taskID, generatedAt }` der gelesenen Ansicht und einer id ≥ 2; eine taskID, die nicht in der Ansicht steht, und ein zweiter Tipp auf eine wartende Zeile senden nichts (Test 2).
- **AC-3:** Die Zeile zeigt nach dem Tipp „Abgehakt, wartet auf dein Gerät …“ ohne Knopf (Test 3).
- **AC-4:** Mit der `orderID` fragt das Fenster `get_order_result` alle 3 s ab, bei `waiting` und `claimed` weiter, höchstens 20 Abfragen; danach zeigt die Zeile „Noch nicht übernommen – dein Gerät holt es beim nächsten Öffnen.“ und es folgt keine Abfrage mehr (Tests 4, 7).
- **AC-5:** Bei `result` mit `outcome: done` zeigt die Zeile den grünen Haken mit durchgestrichenem Titel, danach liest das Fenster die Ansicht per `get_view` neu und zeichnet sie; Grün nur in diesem Moment (Test 4).
- **AC-6:** Bei `outcome: rejected` zeigt die Zeile „Nicht übernommen – die Aufgabe hat sich geändert.“ und die Ansicht wird neu gelesen; bei `unknown` und bei jedem anderen Fehler oder JSON-RPC-`error` zeigt sie „Hat nicht geklappt.“, nie einen Host-Fehlertext (Tests 5, 8).
- **AC-7:** Bei „Abschrift hat sich geändert, bitte neu lesen“ liest das Fenster genau einmal per `get_view` neu und die Zeile ist ohne Auftrag zurück; eine zweite gleiche Ablehnung zeigt „Hat nicht geklappt.“ ohne drittes Lesen (Test 6).
- **AC-8:** Bei `ui/resource-teardown` antwortet das Fenster mit `{}`, beendet alle Timer und sendet danach kein `tools/call` mehr (Test 9).
- **AC-9:** Titel und `data-id` erscheinen in jedem Zustand nur HTML-escaped; die Ressource enthält genau ein inline-Skript und keine Fremdquelle; `server/src/mcp.ts`, `server/package.json` und alle S1- und S2a-Tests bleiben unverändert grün (Tests 10, 11; Prüfung im Review).
- **AC-10:** Nach dem Ausrollen ist belegt, ob claude.ai `serverTools` meldet; erscheint der Knopf, sind Knopf und Wartezeile an einer eigens angelegten Prüfaufgabe in Hell und Dunkel belegt, sonst ist das Fehlen des Knopfes belegt; Belege unter `docs/artifacts/feat-624-s2b1-abhaken/` (Stufe 2, Bilder geöffnet und beschrieben, keine echte Aufgabe abgehakt).

## Definition of Done

- [ ] Tests 1–11 rot vor der Umsetzung, grün danach; `./server/scripts/test-local.sh` grün
- [ ] `CLAUDE.md` Eintrag `src/app-ui.ts` nachgeführt
- [ ] Ausgerollt auf `rennwienix` (Commit und Zeitpunkt im Beleg), Sichtprüfung in claude.ai hell und dunkel, nur Prüfaufgabe abgehakt, Belege unter `docs/artifacts/feat-624-s2b1-abhaken/`
- [ ] Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“ und der Aussage, ob der Haken-Zustand am Host belegt oder nur die Zeitgrenze gesehen wurde
- [ ] Ausgeliefert per PR mit `Refs #624`, CI grün, gemergt; #624 bleibt offen (Schnitte 2b-2 und 3)

## Alternativen

- **B: `ui/message` an Claude statt eigenem `tools/call`:** der Knopf schickt „Hake X ab“ als Nachricht, Claude ruft das Werkzeug.
  Kein eigener Auftragszustand im Fenster, aber jeder Tipp kostet eine Modellrunde, und die Rückmeldung kommt als Text statt in
  der Zeile. Rückfall, falls claude.ai `serverTools` nicht meldet; dann der Weg für Schnitt 2b-2. Keine ADR fällt.
- **C: nur Anzeige (Status quo Schnitt 2a):** nichts ändert sich, Abhaken bleibt Sache des Gesprächs. Verfehlt das Ziel von
  #624. Keine ADR fällt.
- **D: SDK `@modelcontextprotocol/ext-apps`:** nimmt Handshake und Aufrufe ab, ist aber eine neue Abhängigkeit (PO-Freigabe)
  mit einem Bündel von etwa 546 KB, das inline ins HTML müsste; der handgeschriebene Weg ist belegt. Keine ADR fällt.

## Risiken

- **`serverTools` bei claude.ai unbelegt:** erster Prüfpunkt der Sichtprüfung; ohne den Eintrag bleibt das Fenster ohne Knopf
  (kein Schaden), Alternative B wird der Weg für Schnitt 2b-2.
- **App-Teil des Weckrufs (#795 S5c-2) fehlt:** ohne offene App führt kein Gerät den Auftrag in den 60 s aus; dann greift die
  Zeitgrenze, und der Auftrag bleibt in der Warteschlange (nicht verloren, die App holt ihn beim nächsten Öffnen). Die Zeile
  sagt das ruhig.
- **Jedes Ergebnis erzeugt eine neue Abschrift:** der nächste Auftrag mit altem `generatedAt` würde abgelehnt; deshalb liest das
  Fenster nach jedem Ergebnis neu und bei „Abschrift hat sich geändert“ einmal.
- **Echte Datenänderung beim Beleg:** nur die eigens angelegte Prüfaufgabe wird abgehakt, nie eine echte Aufgabe; ein
  schreibender Fehltipp im Beleg wäre sonst nicht rückholbar (kein Rückgängig-Werkzeug).
- **Kein Browser im Test:** der `vm`-Test prüft Nachrichtenfolge, Zustände und Timer, nicht die Darstellung; die belegt die
  Sichtprüfung.

## Changelog

- 2026-11-17: Erste Fassung (Schnitt 2b-1, Abhaken; 2b-2 Pfeil und Etiketten folgen).
