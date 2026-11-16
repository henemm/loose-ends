---
entity_id: feat-624-schnitt-2a-anzeige
type: feature
created: 2026-11-16
updated: 2026-11-16
status: draft
workflow: feat-624-s2-client
---

# Spec: Ansicht der App im Chat, Schnitt 2a (Fenster zeigt die Ansicht, ohne Knöpfe, #624)

## Approval

- [ ] Approved

## GitHub Issue

#624 (Epic #612). Schnitt 2a von 3 (2 ist geteilt in 2a und 2b); das Issue bleibt offen (PR mit `Refs #624`, nie `Closes #624`).
Analyse: `docs/context/feat-624-s2-client.md` (Abschnitte „Protokoll“, „Analysis“, „Scope Assessment“), Recherche und
PO-Entscheide: `docs/context/feat-624-mcp-app.md`. Vorgänger: `docs/specs/feat-624-schnitt-1-ressource.md` (PR #940, nicht
ausgerollt). Entwurf: `docs/artifacts/feat-624-mcp-app/entwurf.html`, vom PO am 2026-11-16 freigegeben: Gestalt A (Papier der
App), alle vier Ansichten von `get_view`.

## Purpose

Das Fenster, das ein Host (claude.ai) zu `get_view` zeigt, ersetzt den Platzhalter aus Schnitt 1 durch die echte Ansicht der
App: „Jetzt“, „Fällig“, „Als nächstes“ und „Offen“ in Gestalt A, hell und dunkel, mit Kopf (Name, Zahl, Stand) und Randmarken.
Das Fenster spricht dazu das MCP-Apps-Protokoll (Handshake, Host-Kontext, Werkzeugergebnis lesen) von Hand, ohne Abhängigkeit.
Es zeigt nur an; Knöpfe und Aufrufe kommen mit Schnitt 2b. Danach wird sofort ausgerollt und in claude.ai angesehen, damit der
Handshake am echten Host belegt ist, bevor Knöpfe darauf gebaut werden.

**Regeln vor Modell:** kein Modellaufruf, keine Sprachaufgabe; Randmarken und „heute/überfällig“ sind Tagesvergleiche. Der Satz
„Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- **Schnitt 2b:** Knöpfe (Abhaken über `complete_task`, „Als nächstes“ über `set_next`), Warte- und Ergebniszustand mit Abfrage
  über `get_order_result`, erneutes Lesen nach einem Ergebnis, `contexts` als zusätzliches Feld an die Zeilen von „Jetzt“
  (ändert `mcp.ts`, nach dem Merge von PR #937).
- **Schnitt 3:** Detail über `get_task`, sichtbare Fehlerfälle von Aufträgen, Bilder hell/dunkel ins Ticket, Claude Desktop.
- Kein `tools/call`, kein Knopf, kein anklickbares Element in diesem Schnitt. Knäuel und Perle werden nur angezeigt, nie angeboten.
- `server/src/mcp.ts` bleibt unberührt: Textantwort von `get_view` und alle Werkzeuge unverändert (S1-AC-5 gilt weiter).
- Keine neue Abhängigkeit, keine Migration, keine Änderung an der App oder an `server/src/anleitung.ts`.
- Kein Gerät von Henning beteiligt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — der Weg über den MCP-Dienst (ADR-21, Weg B) bleibt; es ändert sich nur der Inhalt der Ressource aus
  Schnitt 1 nach der offenen Erweiterung `io.modelcontextprotocol/ui` (Spec 2026-01-26). Keine Schema- oder Vertragsänderung.

## Source

**Files:** `server/src/app-ui.ts`, `server/test/mcp-app.test.ts`, `server/test/app-client.test.ts` (neu), `CLAUDE.md`
**Identifier:** `viewHtml`, `escape`, `rowsHtml`, `reduce` (reine Client-Funktionen, per `Function.prototype.toString()` ins HTML
eingebettet)

## Implementation Details

### Protokoll (Client im HTML, ein inline-Skript)

- Transport: JSON-RPC 2.0 über `window.parent.postMessage(nachricht, "*")`; Antworten und Mitteilungen kommen als
  `message`-Ereignis, nur von `window.parent` angenommen.
- Beim Start sendet das Fenster `ui/initialize` mit `protocolVersion: "2026-01-26"`, `appInfo` (Name „Loose Ends“, Version) und
  `appCapabilities: {}`. Auf die Antwort folgt `ui/notifications/initialized`. Vorher wird nichts anderes gesendet.
- Aus der Antwort und aus `ui/notifications/host-context-changed` wird der Host-Kontext zusammengeführt (Teilmengen
  überschreiben nur ihre Schlüssel): `theme` (`light`|`dark`) setzt `data-theme` am Wurzelelement, `timeZone` bestimmt „heute“.
  Ohne `theme` greift `prefers-color-scheme`; ohne `timeZone` die Zeitzone des Browsers.
- `ui/notifications/tool-result`: das Fenster liest das JSON aus `content[0].text`. Ist `isError` gesetzt oder das JSON nicht
  lesbar oder von unbekannter Form, zeigt es eine ruhige Zeile statt der Liste (kein Rohtext, keine Fehlermeldung des Hosts).
- Nach jedem Zeichnen sendet das Fenster `ui/notifications/size-changed` mit `{ width, height }` der Dokumenthöhe.
- Die Anfrage `ui/resource-teardown` wird mit `{}` und derselben `id` beantwortet. Unbekannte Mitteilungen werden ignoriert.

### Anzeige (Gestalt A)

- Kopf: Ansichtsname („Jetzt“, „Fällig“, „Als nächstes“, „Offen“), Zahl (`nowCount` bei `now`, sonst `count`) und Stand aus
  `generatedAt`.
- Zeile: Titel, dazu die Randmarke. In `now` aus `group`: `knaeuel` → Knäuel-Zeichen (Inline-SVG), `today` → „Heute“ in Rot,
  `lined` → „Nächstes“, `waiting` → „Wartet“. In den anderen Ansichten aus `dueDate`: heute oder überfällig in Rot, sonst das
  Datum in Grau; ohne `dueDate` keine Marke. Der Vergleich geht Tag gegen Tag in der `timeZone` des Hosts, ohne weitere Regel.
- Farben nach dem Entwurf und dem Farbbudget der App: Akzent = antippbar (hier unbenutzt), Rot = Zeitdruck, Grau = Hierarchie.
- Leere Liste: eine ruhige Kursivzeile. Kein Scrollbereich im Fenster; es wächst mit dem Inhalt.
- Titel und jeder Nutzertext laufen ausnahmslos durch `escape`; kein `innerHTML` mit Rohtext (Zeilen entstehen aus bereits
  escapten Zeichenketten, dynamische Werte nie aus Rohtext).
- Das Skript steht inline; kein `src=`, kein `http://`, `https://`, `@import`; Inline-SVG ohne `xmlns`-Attribut. Weiterhin
  kein `_meta.ui.csp`.

### Reine Funktionen und Einbettung

`escape(text)`, `rowsHtml(view, rows, today)` und `reduce(state, message)` (neuer Zustand plus ausgehende Nachrichten) sind
reine TS-Funktionen in `app-ui.ts`, vom Test direkt importiert und per `toString()` in das Skript eingebettet (Node 26 type
stripping macht den Text zu gültigem JS). Das Skript selbst enthält nur die dünne Hülle (Ereignis, `postMessage`, DOM-Zuweisung).

### Ausrollen und Sichtprüfung (Teil der Abnahme)

Nach dem Merge: Ausrollen auf `rennwienix` mit `scripts/deploy-loose-ends.sh` und `LE_COMMIT` (per `ssh rennwienix bash -s`);
Rückweg: vorheriger `LE_COMMIT`. Sichtprüfung in claude.ai im Chrome, Connector „Loose Ends“, mindestens `now`, hell und dunkel.
Belege unter `docs/artifacts/feat-624-s2a-anzeige/` (Bilder werden geöffnet und beschrieben). Scheitert der Handshake am echten
Host, gilt die Alternative B als Rückfall (siehe unten), nicht ein Raten am Protokoll.

### Dokumentation

`CLAUDE.md`, Eintrag `src/app-ui.ts` nachführen: #624 S2a, Fenster zeigt die vier Ansichten, handgeschriebener Handshake, ein
inline-Skript, Knöpfe folgen in S2b.

## Dependencies

| Entität | Art | Zweck |
|---|---|---|
| `server/src/app-ui.ts` (S1) | bestehend | `UI_URI`, `UI_MIME`, `viewHtml`, wird erweitert |
| `server/src/mcp.ts` (`get_view`, `registerUi`) | bestehend, unverändert | Antwortform `{ view, generatedAt, nowCount?, count, rows }` |
| MCP-Erweiterung `io.modelcontextprotocol/ui` (Spec 2026-01-26) | extern, Spec | Nachrichten `ui/initialize`, `tool-result`, `host-context-changed`, `size-changed`, `resource-teardown` |
| `docs/artifacts/feat-624-mcp-app/entwurf.html` | bestehend | Gestalt A: Farben, Zeilenaufbau, Randmarken |
| `scripts/deploy-loose-ends.sh` (henemm-infra) | extern | Ausrollen auf `rennwienix` |
| claude.ai, Connector „Loose Ends“ | extern, live | Host für die Sichtprüfung |
| PR #937 (#932 S3) | parallel, offen | ändert `mcp.ts`; S2a unberührt |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung | LoC |
|---|---|---|---|
| `server/src/app-ui.ts` | MODIFY | CSS Gestalt A, `escape`, `rowsHtml`, `reduce`, Skript-Hülle, Einbettung | +140/-15 |
| `server/test/mcp-app.test.ts` | MODIFY | S1-AC-3 „kein Skript“ wird „genau ein inline-Skript, keine Fremdquelle“ | +6/-6 |
| `server/test/app-client.test.ts` | CREATE | Render, Escaping, Randmarken, Handshake per `node:vm` | +80 |
| `CLAUDE.md` | MODIFY | Eintrag `src/app-ui.ts` | +1/-1 |

### Estimated Changes

- Files: 4 (Produktcode 1, Tests 2, Doku 1).
- LoC: etwa +227/-22, zusammen rund 249 inklusive Tests; Produktcode etwa 155. Die Grenze ±250 LoC ist knapp; die Tests
  bündeln deshalb Fälle tabellarisch (eine Schleife über die vier `group`-Werte und die Datumsfälle). Läuft der Schnitt
  trotzdem über, kürzt er die Tests, nicht den Handshake, und der Überhang wird vor dem Bauen benannt.

## Test Plan

### Automated Tests (TDD RED)

Dienst-Tests (`node:test`) über `./server/scripts/test-local.sh`. Reine Funktionen direkt importiert; der Handshake mit `node:vm`
gegen Fake-`window`/`document`/`parent` aus dem echten `viewHtml`.

- [ ] Test 1: GIVEN ein Titel mit `<b>&"'` WHEN `escape` und `rowsHtml` THEN steht er nur als Entities in der Ausgabe, kein rohes `<b>`.
- [ ] Test 2: GIVEN Zeilen von `now` mit den vier `group`-Werten WHEN `rowsHtml` THEN trägt jede die passende Randmarke („Heute“ mit Rot-Klasse, „Nächstes“, „Wartet“, Knäuel-Zeichen).
- [ ] Test 3: GIVEN Zeilen von `due`/`next`/`open` mit `dueDate` gestern, heute, morgen und ohne, `today` in einer Zeitzone nahe Mitternacht WHEN `rowsHtml` THEN sind gestern und heute rot, morgen grau mit Datum, ohne Datum keine Marke (Tag gegen Tag in der `timeZone`).
- [ ] Test 4: GIVEN eine leere Zeilenliste WHEN `rowsHtml` THEN eine ruhige Zeile statt Zeilen; GIVEN `isError` oder unlesbares JSON im `tool-result` WHEN `reduce` THEN eine ruhige Zeile, keine Liste.
- [ ] Test 5: GIVEN das Skript aus `viewHtml` im Fake-Fenster WHEN es startet THEN ist die erste ausgehende Nachricht `ui/initialize` mit `protocolVersion` „2026-01-26“, `appInfo` und `appCapabilities` `{}`; nach der Antwort folgt `ui/notifications/initialized`, vorher nichts anderes.
- [ ] Test 6: GIVEN ein `tool-result` mit dem JSON einer Ansicht in `content[0].text` und `theme` `dark` im Host-Kontext WHEN verarbeitet THEN trägt das Wurzelelement `data-theme="dark"`, der Kopf zeigt Ansichtsname, `nowCount` und den Stand aus `generatedAt`, die Zeilen stehen im Dokument und danach geht `ui/notifications/size-changed` hinaus; ein späteres `host-context-changed` nur mit `timeZone` lässt `theme` stehen.
- [ ] Test 7: GIVEN die Anfrage `ui/resource-teardown` mit `id` 7 WHEN verarbeitet THEN antwortet das Fenster `{ id: 7, result: {} }`; eine unbekannte Mitteilung wird ohne Fehler ignoriert; während des gesamten Ablaufs geht kein `tools/call` hinaus.
- [ ] Test 8: GIVEN `viewHtml` WHEN nach Fremdquellen gesucht THEN genau ein `<script`, kein `src=`, `http://`, `https://`, `@import`, kein `xmlns`; `prefers-color-scheme: dark` und `data-theme` sind enthalten (ersetzt S1-AC-3).
- [ ] Test 9: GIVEN die Tests aus Schnitt 1 (Ressource, Verweis nur an `get_view`, Textantwort aller vier Ansichten, Anleitung) WHEN der Lauf THEN unverändert grün.

### Abnahme

Stufe 1: Tests 1–9 rot vor, grün nach der Umsetzung; `./server/scripts/test-local.sh` grün.
Stufe 2: Ausrollen und Sichtprüfung in claude.ai (siehe Implementation Details): `get_view` mit `now` zeigt das Fenster hell
und dunkel in Gestalt A, mit Kopf, Zeilen und Randmarken; Belege geöffnet und beschrieben.
Stufe 3: Kein Pfad der Geräteliste berührt. Geprüft gegen die Tabelle in `CLAUDE.md`: nur `server/` und `CLAUDE.md`.

## Acceptance Criteria

- **AC-1:** Titel und jeder Nutzertext erscheinen nur HTML-escaped; kein `innerHTML` mit Rohtext (Test 1).
- **AC-2:** In `now` zeigen die Zeilen die Randmarke aus `group` (Knäuel-Zeichen, „Heute“ rot, „Nächstes“, „Wartet“) (Test 2).
- **AC-3:** In `due`, `next` und `open` ist die Randmarke aus `dueDate` abgeleitet: heute und überfällig rot, Vergleich Tag gegen Tag in der `timeZone` des Hosts, sonst Datum in Grau, ohne Datum keine Marke (Test 3).
- **AC-4:** Der Kopf zeigt Ansichtsname, Zahl (`nowCount` bei `now`, sonst `count`) und Stand aus `generatedAt` (Test 6).
- **AC-5:** Eine leere Liste und eine Fehlerantwort (`isError` oder unlesbares JSON) zeigen je eine ruhige Zeile (Test 4).
- **AC-6:** Das Fenster beginnt mit `ui/initialize` (`protocolVersion` „2026-01-26“, `appInfo`, `appCapabilities` `{}`), sendet erst nach der Antwort `ui/notifications/initialized` und vorher nichts anderes (Test 5).
- **AC-7:** `theme` aus dem Host-Kontext setzt `data-theme`, `host-context-changed` wird zusammengeführt, ohne `theme` greift `prefers-color-scheme`; nach dem Zeichnen geht `ui/notifications/size-changed` hinaus (Test 6, Test 8).
- **AC-8:** `ui/resource-teardown` wird mit `{}` beantwortet; unbekannte Mitteilungen werden ignoriert; das Fenster sendet in diesem Schnitt kein `tools/call` und bietet keinen Knopf an (Test 7).
- **AC-9:** Die Ressource enthält genau ein inline-Skript und keine Fremdquelle (kein `src=`, `http://`, `https://`, `@import`, `xmlns`); `server/src/mcp.ts`, `server/package.json` und die Textantwort von `get_view` bleiben unverändert (Tests 8, 9; Prüfung im Review).
- **AC-10:** Nach dem Ausrollen zeigt claude.ai zu `get_view` mit `now` das Fenster mit Kopf und Zeilen, in Hell und Dunkel; Belege liegen unter `docs/artifacts/feat-624-s2a-anzeige/` (Abnahme Stufe 2, Bilder geöffnet und beschrieben).

## Definition of Done

- [ ] Tests 1–9 rot vor der Umsetzung, grün danach; `./server/scripts/test-local.sh` grün
- [ ] `CLAUDE.md` Eintrag `src/app-ui.ts` nachgeführt
- [ ] Ausgerollt auf `rennwienix` (Commit und Zeitpunkt im Beleg), Sichtprüfung in claude.ai hell und dunkel, Belege unter `docs/artifacts/feat-624-s2a-anzeige/`
- [ ] Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“
- [ ] Ausgeliefert per PR mit `Refs #624`, CI grün, gemergt; #624 bleibt offen (Schnitte 2b und 3)

## Alternativen

- **B: SDK `@modelcontextprotocol/ext-apps` 2.1.0** (Client `App` mit Handshake und Typen): nimmt die Protokollpflege ab, ist
  aber eine neue Abhängigkeit (PO-Freigabe nötig) und brächte ein Bündel von etwa 546 KB, das inline ins HTML müsste. Für
  diesen Schnitt brächte es nur vier Nachrichten. Rückfall, wenn der handgeschriebene Handshake am echten Host scheitert;
  keine ADR fällt.
- **Ungeteilter Schnitt 2 (Anzeige und Knöpfe zusammen):** spart einen Ausroll-Durchgang, sprengt aber die Grenze (etwa 400 LoC)
  und baut Knöpfe auf einen unbelegten Handshake. Verworfen.
- **Status quo ohne Fenster:** Claude antwortet in Text, Änderungen per Zuruf; das funktioniert heute. Fiele: das Ziel von #624.
  Das Fenster ist reine Zugabe, Text-Hosts bleiben unberührt.

## Risiken

- **Handshake nur aus Spec und SDK-Typen bekannt:** das Spec-Beispiel nennt `clientInfo`/`capabilities`, Prosa und SDK
  `appInfo`/`appCapabilities`; gesetzt wird die SDK-Form. Zeigt claude.ai nichts, zuerst dort nachsehen (Recherche vor Änderung).
- **Ausrollen zeigt das Fenster bei jedem `get_view`:** ein kaputtes Fenster stört den Alltag; Rückweg ist der vorherige `LE_COMMIT`.
- **Zeilen von „Jetzt“ tragen keine Etiketten:** der Entwurf zeigt „Telefon“ unter einer Zeile; S2a zeigt nur, was die Zeile
  trägt, `contexts` folgt mit S2b.
- **Tests ohne Browser:** der `vm`-Test prüft die Nachrichtenfolge, nicht die Darstellung; die Darstellung belegt die
  Sichtprüfung in claude.ai.

## Changelog

- 2026-11-16: Erste Fassung (Schnitt 2a, Anzeige ohne Knöpfe).
