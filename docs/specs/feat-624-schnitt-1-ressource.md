---
entity_id: feat-624-schnitt-1-ressource
type: feature
created: 2026-11-16
updated: 2026-11-16
status: draft
workflow: feat-624-mcp-app
---

# Spec: Ansicht der App im Chat, Schnitt 1 (Dienst: Ressource und Verweis, #624)

## Approval

- [ ] Approved

## GitHub Issue

#624 (Epic #612). Schnitt 1 von 3; das Issue bleibt offen (PR mit `Refs #624`, nie `Closes #624`), weil Schnitt 2 (Liste mit
Abhaken und „Als nächstes“, Ausrollen, Sichtprüfung in claude.ai) und Schnitt 3 (Detail, Fehlerfälle, Bilder hell/dunkel ins
Ticket, Claude Desktop) aus der Definition of Done offen bleiben.
Analyse: `docs/context/feat-624-mcp-app.md` (Abschnitt „Analysis“). Entwurf: `docs/artifacts/feat-624-mcp-app/entwurf.html`,
vom PO am 2026-11-16 freigegeben: Gestalt A (Papier der App), alle vier Ansichten von `get_view`.

## Purpose

Der Dienst stellt eine Oberfläche als MCP-App-Ressource bereit (`ui://loose-ends/view.html`, MIME `text/html;profile=mcp-app`)
und hängt an das Werkzeug `get_view` den Verweis `_meta.ui.resourceUri` darauf. Ein Host, der MCP Apps kann (claude.ai, Claude
Desktop), weiß damit, welches Fenster er zu `get_view` zeigen soll; ein Host ohne MCP Apps (Claude Code) bekommt dieselbe
Textantwort wie heute. Die Ressource enthält in diesem Schnitt nur ein Platzhalter-HTML im Papierstil ohne Skript; die Liste
selbst und ihre Bedienung kommen in Schnitt 2.

**Regeln vor Modell:** kein Modellaufruf, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- **Schnitt 2:** der Fenster-Client (Handshake `ui/initialize`, Empfang des Werkzeugergebnisses, Liste in Gestalt A, Abhaken über
  `complete_task`, „Als nächstes“ über `set_next`, Warte- und Ergebniszustand über `get_order_result`, hell/dunkel aus dem
  Host-Kontext), Ausrollen auf `rennwienix`, erste Sichtprüfung in claude.ai.
- **Schnitt 3:** Detail über `get_task`, sichtbare Fehlerfälle (`stale`, `invalid`), Größenmeldung, Bilder hell/dunkel ins Ticket,
  Prüfung in Claude Desktop.
- **Nicht ausgerollt:** Gemergt, aber nicht ausgerollt. Grund: claude.ai zeigte sonst zu jedem `get_view` eine leere
  Platzhalter-Karte. Ausgerollt wird mit Schnitt 2.
- Keine neue Abhängigkeit (`@modelcontextprotocol/ext-apps` nicht, siehe Alternativen). Kein neues Werkzeug, keine Änderung an
  `get_now`, den Auftragswerkzeugen, der Abschrift, Migrationen, der App oder `server/src/anleitung.ts`.
- Kein `structuredContent` an `get_view`; ob der Client es braucht, entscheidet Schnitt 2.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — der Weg über den MCP-Dienst (ADR-21, Weg B) bleibt; eine zusätzliche Ressource und ein Metadatum am
  bestehenden Werkzeug nach der offenen Erweiterung `io.modelcontextprotocol/ui` (Spec 2026-01-26), ohne Schema- oder
  Vertragswechsel.

## Source

**Files:** `server/src/app-ui.ts` (neu), `server/src/mcp.ts`, `server/test/mcp-app.test.ts` (neu), `CLAUDE.md`
**Identifier:** `UI_URI`, `UI_MIME`, `viewHtml`, `registerUi`, Werkzeug `get_view`

## Implementation Details

### `server/src/app-ui.ts` (neu)

- `export const UI_URI = "ui://loose-ends/view.html"` und `export const UI_MIME = "text/html;profile=mcp-app"`.
- `export const viewHtml`: ein vollständiges HTML-Dokument (`<!doctype html>`, `lang="de"`, `charset`, `viewport`) mit inline CSS,
  **ohne** `<script>`, ohne externe Quelle (kein `src=`, kein `href=` auf http/https, kein `@import`, kein `url(http…)`).
  Inhalt: Papiergrund und Serifenschrift der Gestalt A in Hell und Dunkel (`@media (prefers-color-scheme: dark)`), eine Zeile
  „Loose Ends“ und eine Kursivzeile „Die Ansicht folgt.“ Mehr nicht; Schnitt 2 ersetzt den Inhalt.
- Externe Quellen bleiben gesperrt: die Ressource setzt kein `_meta.ui.csp` (Standard des Hosts = nichts Externes erlaubt) und
  kein `_meta.ui.domain`.

### `server/src/mcp.ts`

- `registerUi(server)` registriert die Ressource per `server.registerResource("view", UI_URI, { title: "Loose Ends",
  mimeType: UI_MIME }, …)`; der Lese-Rückruf liefert genau einen Inhalt `{ uri: UI_URI, mimeType: UI_MIME, text: viewHtml }`.
  Kein Konto nötig (die Ressource enthält keine Daten), aber sie liegt wie alles hinter `/mcp` und damit hinter dem Bearer-Tor.
- `mcpHandler` ruft `registerUi(server)` neben `registerViews`, `registerLookups`, `registerOrders`.
- `get_view` bekommt `_meta: { ui: { resourceUri: UI_URI } }`. Sonst bleibt `get_view` unverändert: Beschreibung,
  Eingabeschema, Annotationen und Textantwort (Zeichen für Zeichen).
- Kein anderes Werkzeug bekommt `_meta`.
- Eingriff minimal halten: PR #937 (#932 Schnitt 3) ändert `mcp.ts` ebenfalls (`registerOrders`); dieser Schnitt fasst
  `registerOrders` nicht an. Wer zuerst gemergt wird, der andere zieht nach.

### Dokumentation

`CLAUDE.md`, Abschnitt „Where things live“ unter `server/`: eine Zeile zu `src/app-ui.ts` (#624 S1: Ressource
`ui://loose-ends/view.html`, MIME `text/html;profile=mcp-app`, Verweis nur an `get_view`, Platzhalter ohne Skript, nicht
ausgerollt; Client in S2).

## Dependencies

| Entität | Art | Zweck |
|---|---|---|
| `@modelcontextprotocol/server` 2.4.0 | bestehend | `registerResource`, `registerTool` mit `_meta` |
| `server/src/mcp.ts` (`registerViews`) | bestehend | `get_view` |
| MCP-Erweiterung `io.modelcontextprotocol/ui` (SEP-1865, Spec 2026-01-26) | extern, Spec | Form von Ressource, MIME und `_meta.ui.resourceUri` |
| PR #937 (#932 S3) | parallel, offen | ändert `mcp.ts` (`registerOrders`), keine Überschneidung im Inhalt |
| `server/src/anleitung.ts` | bestehend, unverändert | kein neues Werkzeugwort; Test AC-3 der Anleitung bleibt grün |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung | LoC |
|---|---|---|---|
| `server/src/app-ui.ts` | CREATE | `UI_URI`, `UI_MIME`, `viewHtml` (Platzhalter, CSS hell/dunkel) | +40 |
| `server/src/mcp.ts` | MODIFY | Import, `registerUi`, Aufruf, `_meta` an `get_view` | +12 |
| `server/test/mcp-app.test.ts` | CREATE | Tests 1–6 über den echten Handler | +90 |
| `CLAUDE.md` | MODIFY | eine Zeile unter `server/` | +1 |

### Estimated Changes

- Files: 4 (Produktcode 2, Test 1, Doku 1).
- LoC: etwa +145, unter ±250.

## Test Plan

### Automated Tests (TDD RED)

XCTest-Pflicht des QA-Gates gilt für Swift; hier laufen die Tests des Dienstes (`node:test`) über `./server/scripts/test-local.sh`.
Muster wie `server/test/mcp-anleitung.test.ts`: `mcpHandler(pool)` und ein `Client` mit `StreamableHTTPClientTransport`, das jede
Anfrage direkt an `handler.fetch` mit `authInfo` gibt.

- [ ] Test 1: GIVEN ein verbundener Client WHEN `resources/list` THEN steht genau eine Ressource mit `uri` `ui://loose-ends/view.html` und `mimeType` `text/html;profile=mcp-app` darin.
- [ ] Test 2: GIVEN ein verbundener Client WHEN `resources/read` auf `ui://loose-ends/view.html` THEN genau ein Inhalt mit dieser `uri`, diesem `mimeType` und einem `text`, der mit `<!doctype html>` beginnt (ohne Groß-/Kleinschreibung) und `lang="de"` enthält.
- [ ] Test 3: GIVEN der gelesene Text WHEN nach Skript und externen Quellen gesucht THEN kein `<script`, kein `http://`, kein `https://`, kein `@import`; GIVEN der Text WHEN nach dem Dunkelmodus gesucht THEN enthält er `prefers-color-scheme: dark`.
- [ ] Test 4: GIVEN `tools/list` WHEN `get_view` gelesen wird THEN trägt es `_meta.ui.resourceUri` = `ui://loose-ends/view.html`; GIVEN jedes andere Werkzeug THEN hat es kein `_meta.ui`.
- [ ] Test 5: GIVEN eine gespeicherte Abschrift WHEN `get_view` mit `now`, `due`, `next` und `open` aufgerufen wird THEN ist die Antwort genau ein Textinhalt, dessen JSON gleich dem bisherigen Ergebnis ist (dieselben Schlüssel und Werte wie in `server/test/mcp-read.test.ts`), ohne `structuredContent`.
- [ ] Test 6: GIVEN die bestehenden Tests (Werkzeugliste, Anleitung ≤ 2048 Byte und nur bekannte Werkzeugwörter, Lese- und Auftragswerkzeuge) WHEN der Lauf THEN unverändert grün.

### Abnahme

Stufe 1: neue Tests rot vor, grün nach der Umsetzung; `./server/scripts/test-local.sh` grün (Typprüfung und alle Dienst-Tests
gegen die Wegwerf-Datenbank).
Stufe 2: Keine sichtbare Oberfläche in einem Host in diesem Schnitt (nicht ausgerollt, Platzhalter); der Ablauf „Host fragt
Werkzeugliste, liest den Verweis, liest die Ressource“ wird im Test über den echten MCP-Handler durchlaufen (Tests 1–4). Die
Sichtprüfung in claude.ai ist Teil von Schnitt 2. Das wird im Abschlussbericht so benannt.
Stufe 3: Kein Pfad der Geräteliste berührt. Geprüft gegen die Tabelle in `CLAUDE.md`: nur `server/` und `CLAUDE.md`.

## Acceptance Criteria

- **AC-1:** Der Dienst führt genau eine Ressource `ui://loose-ends/view.html` mit MIME `text/html;profile=mcp-app` (Test 1).
- **AC-2:** Das Lesen der Ressource liefert genau einen Inhalt mit dieser URI, diesem MIME und einem vollständigen HTML-Dokument mit `lang="de"` (Test 2).
- **AC-3:** Das HTML enthält kein Skript und keine externe Quelle und bringt Hell und Dunkel mit (Test 3).
- **AC-4:** Nur `get_view` trägt `_meta.ui.resourceUri` = `ui://loose-ends/view.html`; kein anderes Werkzeug trägt `_meta.ui` (Test 4).
- **AC-5:** Die Antwort von `get_view` bleibt für alle vier Ansichten Zeichen für Zeichen wie heute: ein Textinhalt, kein `structuredContent` (Test 5).
- **AC-6:** Keine neue Abhängigkeit in `server/package.json`; `anleitung.ts`, Abschrift, Migrationen und App sind unverändert; `./server/scripts/test-local.sh` ist grün (Test 6, Prüfung im Review).

## Definition of Done

- [ ] Neue Tests aus dem Test Plan rot vor der Umsetzung, grün danach; `./server/scripts/test-local.sh` grün
- [ ] `CLAUDE.md` um die Zeile zu `src/app-ui.ts` ergänzt
- [ ] Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“ und dem Hinweis „nicht ausgerollt, Ausrollen mit Schnitt 2“
- [ ] Ausgeliefert per PR mit `Refs #624`, CI grün, gemergt; #624 bleibt offen (Schnitte 2 und 3)

## Alternativen

- **SDK `@modelcontextprotocol/ext-apps` 2.1.0** (`registerAppTool`, `registerAppResource`, Fenster-Client `App`): nimmt die
  Protokollpflege ab, ist aber eine neue Abhängigkeit (Freigabe nötig) und brächte für den Client ein Bündel von 546 KB, das
  inline ins HTML müsste (externes Laden rendert in claude.ai laut ext-apps#671 nicht). Für diesen Schnitt brächte es nur zwei
  Hilfsfunktionen. Rückfall, wenn der handgeschriebene Handshake in Schnitt 2 am echten Host scheitert; Schnitt 1 bleibt dann
  gültig. Keine ADR fällt.
- **Verweis an `get_now` statt `get_view`:** `get_now` ist die ältere Leseform ohne `view`; der PO hat alle vier Ansichten
  festgelegt, das trägt nur `get_view`. Verworfen.
- **Keine App, Status quo:** Claude antwortet in Text, Änderungen per Zuruf; funktioniert heute schon. Fiele: das Ziel von #624.
- **Platzhalter weglassen, Ressource erst mit Schnitt 2:** spart nichts Wesentliches und verschiebt die Prüfung von Ressource
  und Verweis in einen ohnehin großen Schnitt. Verworfen.

## Risiken

- **Host liest den Verweis anders als die Spec:** ältere Hosts lasen einen flachen Schlüssel `_meta["ui/resourceUri"]`. Die
  Spec 2026-01-26 nennt `_meta.ui.resourceUri`; nur das wird gesetzt. Zeigt claude.ai in Schnitt 2 kein Fenster, ist das die
  erste Stelle zum Nachsehen (Recherche vor Änderung).
- **Zustandsloser Dienst prüft die Fähigkeit des Hosts nicht:** jeder Aufruf baut einen frischen Server, die Fähigkeiten des
  Clients aus `initialize` sind dort nicht greifbar; der Verweis steht deshalb immer am Werkzeug. Hosts ohne MCP Apps
  ignorieren `_meta` (Test 5 hält die Textantwort gleich).
- **Konflikt mit PR #937:** beide ändern `mcp.ts`; dieser Schnitt bleibt außerhalb von `registerOrders`, der Nachzug ist ein
  kleiner Abgleich.

## Changelog

- 2026-11-16: Erste Fassung (Schnitt 1, Ressource und Verweis).
