# Adversary Dialog — spike-613-c4-mcp
Spec: docs/specs/spike-613-schnitt-c4a-mcp-lesen.md
Datum: 2026-11-01 21:38

## Checkliste
- [x] **AC-1:** `tools/list` nennt genau zwei Werkzeuge, `get_now` und `list_tasks` (Test: Namensliste gleich `["get_now", "list_tasks"]` nach Sortierung). | BELEG: server/test/mcp.test.ts:56 listTools sortiert == [get_now,list_tasks]; server/src/mcp.ts:45,49 genau zwei registerTool; Lauf 82/82 gruen
- [x] **AC-2:** Ohne `authInfo` (kein Konto) lehnt `get_now` ab: `isError` ist wahr, der Text nennt „kein Konto“; dasselbe für `list_tasks`. Der Test hinterlegt vorher eine Abschrift für `henning` und belegt, dass sie nicht ausgegeben wird. | BELEG: server/src/mcp.ts:35 isError+kein Konto vor getTranscript; mcp.test.ts:62-74; Sonde: authInfo undefined/{}/account leer/5/{} -> alle isError, Pool-Mock warf bei jedem Lesen, wurde nie gelesen
- [x] **AC-3:** Ein anderes Konto sieht keine fremde Abschrift: mit gespeicherter Abschrift für `henning` liefert `get_now` und `list_tasks` für das Konto `anna` den Text „noch keine Abschrift“ ohne `isError`; die Titel der Abschrift von `henning` kommen in der Antwort nicht vor. | BELEG: server/src/transcripts.ts:134 WHERE account_id=$1; mcp.test.ts:76-90 (anna sieht henning nicht, kein isError, kein Titel)
- [x] **AC-4:** Ohne gespeicherte Abschrift antworten `get_now` und `list_tasks` für ein bekanntes Konto mit dem Text „noch keine Abschrift“ und `isError` ist nicht gesetzt. | BELEG: server/src/mcp.ts:37 doc===undefined -> reply ohne isError; mcp.test.ts:76-90 Fall AC-4
- [x] **AC-5:** `get_now` gibt mit der Beispielabschrift des Vertrags (zur Laufzeit gelesen, nicht abgeschrieben) `nowCount` unverändert aus; mit einem geänderten Wert (`nowCount` = 7 bei weiterhin drei Zeilen) kommt 7, nicht 3 (der Dienst zählt nicht neu). | BELEG: server/src/mcp.ts:48 nowCount: doc.nowCount, keine Zaehlung; mcp.test.ts:92-100 (Vertrag und 7 bei drei Zeilen)
- [x] **AC-6:** `get_now` liefert die Zeilen in der Reihenfolge `knaeuel`, `today`, `lined`, `waiting`: für die Beispielabschrift die Kennungen `…0003` (Knäuel), `…0001` (heute), `…0002` (als nächstes) in dieser Reihenfolge, mit `group` je Zeile; bei einer Abschrift mit mehreren Kennungen je Gruppe bleibt die Reihenfolge innerhalb der Gruppe wie geliefert; ohne `knaeuel` beginnt die Liste mit `today`. | BELEG: server/src/mcp.ts:18-21 Reihenfolge knaeuel,today,lined,waiting, flatMap erhaelt Reihenfolge; mcp.test.ts:102-120
- [x] **AC-7:** Jede Zeile von `get_now` trägt Kennung, Titel, Fälligkeit (`dueDate`, nur wenn die Aufgabe eine hat), `dueHasTime`, Status und `isKnaeuel` der Aufgabe aus `tasks` (Beispiel: „Müll rausbringen“ mit `dueDate` `2026-03-12T17:00:00Z`, `dueHasTime` wahr, `active`; „Steuer machen“ mit `isKnaeuel` wahr); `get_now` nennt zusätzlich `generatedAt`. Eine Kennung in `now`, die in `tasks` fehlt, erscheint nur mit `id` und `group`, ohne Fehler. | BELEG: server/src/mcp.ts:23-28 Felder aus tasks, dueDate nur wenn vorhanden, fehlende Aufgabe nur id+group; mcp.test.ts:122-142; generatedAt mcp.ts:48
- [x] **AC-8:** `list_tasks` liefert alle `tasks` der Beispielabschrift (drei) in der gelieferten Reihenfolge (auch umgestellt: ein Test mit vertauschter `tasks`-Liste behält die vertauschte Reihenfolge), jeweils mit genau den Feldern der Abschrift (`contexts`, `project`, `nextRank` wo vorhanden, sonst fehlend), und `generatedAt` der Abschrift. | BELEG: server/src/mcp.ts:52 tasks unveraendert; mcp.test.ts:144-153 deepEqual Vertrag und tasks.reverse()
- [x] **AC-9:** Keine Ausgabe trägt Rohtext oder Notiz: die Texte beider Werkzeuge enthalten weder den Schlüssel `rawText` noch `note`; der Handler schreibt nichts nach `console`/`stdout` (Test: `process.stdout.write` und `console.log` werden während der Aufrufe überwacht, kein Aufruf). | BELEG: mcp.ts schreibt nirgends nach console/stdout (Durchsicht); mcp.test.ts:155-167 Spy console.log/stdout.write == 0, kein rawText/note; putTranscript lehnt rawText/note ohnehin ab
- [x] **AC-10:** Eine nach den Werkzeugaufrufen neu hochgeladene Abschrift (`putTranscript` mit neuerem `generatedAt`) wird beim nächsten Aufruf gelesen: der Handler hält keinen Zwischenspeicher (zustandslos). | BELEG: server/src/mcp.ts:43 frische Instanz je Anfrage, kein Modulzustand; mcp.test.ts:169-178
- [x] **AC-11:** `npm run typecheck` ist grün unter `erasableSyntaxOnly` mit den SDK-Typen von `@modelcontextprotocol/server`/`client` (Beleg: `npm run typecheck` im Abschlusslauf ohne Fehler; zeigt schon der RED-Lauf, dass das Type-Stripping mit den SDK-Typen unverträglich ist, wird das vor dem Weiterbauen offen gemeldet). | BELEG: npm run typecheck (tsc --noEmit) in adversary-test-output.txt Zeile 3-4 ohne Fehler
- [x] **AC-12:** `package.json` enthält die drei Pakete mit festen Versionen ohne `^`/`~` (`@modelcontextprotocol/server` 2.4.0, `zod` 4.6.7 unter `dependencies`, `@modelcontextprotocol/client` 2.4.0 unter `devDependencies`); weder `@modelcontextprotocol/node` noch `hono` ist Abhängigkeit; `package-lock.json` ist erzeugt. | BELEG: package.json: server 2.4.0, zod 4.6.7 unter dependencies, client 2.4.0 unter devDependencies, ohne ^/~; kein hono und kein @modelcontextprotocol/node in package.json und package-lock.json (Treffer 0); Lock zod 4.6.7
- [x] **AC-13:** `getTranscript(pool, "henning")` liefert nach `putTranscript` die Abschrift gleich dem Dokument, für ein anderes Konto und ohne Zeile `undefined`. | BELEG: server/src/transcripts.ts:134-137; mcp.test.ts:180-186
- [x] **AC-14:** `./server/scripts/test-local.sh` ist grün (Typprüfung und alle Tests gegen das Wegwerf-Postgres, auch die bestehenden Tests unverändert) und räumt auf; der Workflow `server.yml` ist auf dem PR grün. | BELEG: test-local.sh: Exit 0, 82 pass, 0 fail, 0 skipped, typecheck gruen, Wegwerf-Postgres aufgeraeumt (adversary-test-output.txt); server.yml noch nicht pruefbar (kein PR)
- [x] **AC-15:** Die Dateiliste des PR enthält außer `server/src/transcripts.ts`, `server/src/mcp.ts`, `server/test/mcp.test.ts`, `server/package.json` (samt `server/package-lock.json`) und `CLAUDE.md` nichts, ausgenommen die Workflow-Unterlagen `docs/specs/`, `docs/context/` und `docs/briefings/`. `server/migrations/`, `project.yml` und jede Swift-Datei bleiben unberührt; `CLAUDE.md` bekommt genau eine Zeile unter `server/`: MCP-Handler `mcpHandler` mit `get_now` und `list_tasks`, noch ohne Port und Anmeldung. | BELEG: Dateiliste gegen Basis a065089 plus untracked: CLAUDE.md, transcripts.ts, mcp.ts, mcp.test.ts, package.json, package-lock.json plus docs/specs, docs/context, docs/briefings, docs/artifacts; keine Migration, kein project.yml, keine Swift-Datei; CLAUDE.md +1 Zeile unter server/ (CLAUDE.md:459)

## Dialog

### Runde 1
**Adversary:** Erste Pruefung aller 15 ACs gegen Code und Lauf. Code reference: server/src/mcp.ts:35 (Konto-Pruefung vor dem Lesen), server/src/mcp.ts:48 (nowCount unveraendert), server/src/transcripts.ts:134 (getTranscript, eine Anweisung mit account_id), server/test/mcp.test.ts:56 (Testaufbau im Prozess), server/package.json:14 (feste Versionen). Suite komplett: 82 pass, 0 fail, 0 skipped, typecheck gruen. Weil in Runde 1 alles gruen ist, wurde nicht akzeptiert, sondern in Runde 2 gezielt gebrochen.
**Implementierer:** Alle ACs mit Test und Codepfad belegt (siehe Checkliste).

### Runde 2
**Adversary:** Eigene Sonden (Scratchpad, Pool-Mock der bei jedem Lesen wirft): authInfo mit extra undefined, {}, account leer, account 5, account {} -> beide Werkzeuge isError mit kein Konto, Pool nie gelesen (Code reference: server/src/mcp.ts:11). Konto-Isolation per SQL-Parameter. Abschrift ohne knaeuel: Test AC-6 gruen (mcp.ts:19). Zeile ohne Aufgabe: nur id+group (mcp.ts:25). Zustandslos: Factory je Anfrage (mcp.ts:43), kein Modulzustand. Lock ohne hono und @modelcontextprotocol/node. Befund F001: faellt die Datenbank beim Lesen aus, gibt das Werkzeug die rohe Fehlermeldung als Text an den Client (Sonde: Text DB must not be read mit isError). SDK-Standard; bei pg koennte die Meldung Verbindungsdetails enthalten; die Spec verlangt dazu nichts, kein AC verletzt.
**Implementierer:** F001 betrifft den Betrieb mit echtem Port (C7); als Folgepunkt vermerkt, kein Blocker fuer C4a.

Code reference: server/test/mcp.test.ts:155
Code reference: server/package.json:14

Finding:
  ID: F001
  Severity: LOW
  Category: security
  Code reference: server/src/mcp.ts:36
  Description: getTranscript wird nicht abgefangen; ein Datenbankfehler wird vom SDK als isError-Text mit der Rohmeldung an den Client gereicht.
  Spec requirement: AC-9 - Ausgaben tragen nur, was die Abschrift traegt (Datenschutz); Fehlerfall nicht geregelt
  Conflict: Keine Verletzung eines AC; Spec schweigt zum Fehlerfall, Rohmeldungen koennten in C7 Betriebsdetails verraten.
  Remediation: In C7 (Port) Fehler in eine feste Meldung ueberfuehren und serverseitig ohne Inhalte loggen.

Confirmation:
  AC: AC-1 bis AC-15
  Code reference: server/src/mcp.ts:42
  Evidence: siehe BELEG je Checklistenzeile; Tests 82/82 gruen
  Status: CONFIRMED

Code reference: server/src/transcripts.ts:134

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Tests: 82 passed, 0 failed, 0 uebersprungen (typecheck gruen)
Edge cases: geprueft, F001 (LOW, Betrieb C7) offen vermerkt
Regressions: None found
Checklist: 15/15 points proven (AC-14: server.yml noch nicht pruefbar, kein PR)

## Geprüfte Dateien

- sha256:d91bbbd9093c9ecb710dc3601d684af0f3caba76d3fb3f1e944a38046e1eb967  server/package.json
- sha256:b64ca27acfdfc800a5039b9d505cfa14fc24111a5f2117610adb84e72db661bd  server/src/mcp.ts
- sha256:bcb95e94d1e511c8e74d0ad44ab4e84e62483ed5ba85341b6cd7e2c5dd2dce72  server/src/transcripts.ts
- sha256:4f53969504e0da68a5c7daca9109ea114257501d5bd296b0e8ac27343c9ff831  server/test/mcp.test.ts

## Prüfbasis

- base: a06508986771be14e93834ae57ddf6bb3ebe8345
- blob:5b30c08eb750f986496e904624bef7c62dadcc91  server/package.json
- blob:b3d8e3093509239ea5ee0fbf12773a148a15d9fd  server/src/mcp.ts
- blob:cf71da115c518ae2b97d95cfcc7db2e18f6b44e1  server/src/transcripts.ts
- blob:13920d603d1348b3836c9347610c890d544381ea  server/test/mcp.test.ts
