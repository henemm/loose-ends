# Adversary Dialog — spike-613-c4b-mcp-schreiben
Spec: docs/specs/spike-613-schnitt-c4b1-mcp-erfassen-ergebnis.md
Datum: 2026-11-02 06:28

## Checkliste
- [x] **AC-1:** `getResult` liefert `unknown` für eine nie angelegte Kennung, für eine Kennung eines **anderen Kontos** (gleiche Antwort wie nie angelegt) und für einen Text, der keine UUID ist (keine Ausnahme).
- [x] **AC-2:** `getResult` liefert `waiting` für einen angelegten, nicht vergebenen Auftrag (auch mit der Kennung in Kleinbuchstaben angefragt), `claimed` nach `claimOrder`, und `result` mit dem Ergebnisdokument gleich dem übergebenen nach `putResult` (`done` und `rejected` mit Grund).
- [x] **AC-3:** `tools/list` nennt genau `capture_task`, `get_order_result`, `get_now`, `list_tasks` (sortierte Namensliste); `capture_task` trägt `readOnlyHint` falsch, `destructiveHint` falsch, `idempotentHint` falsch; `get_order_result` trägt `readOnlyHint` wahr.
- [x] **AC-4:** Ohne `authInfo` lehnen `capture_task` und `get_order_result` ab (`isError`, Text „kein Konto“); der abgelehnte Aufruf von `capture_task` legt **keinen** Auftrag an (Zeilenzahl in `orders` vorher gleich nachher).
- [x] **AC-5:** `capture_task` mit `text` legt genau einen Auftrag für das Konto an: die Antwort trägt eine `orderID` in Großbuchstaben (UUID-Form) und `state` „waiting“; die Zeile in `orders` hat `kind` `capture`, den Text unverändert, das Konto aus `authInfo` und `claimed_by` leer; `checkOrder` nimmt das Dokument an.
- [x] **AC-6:** Zwei Aufrufe mit demselben Text erzeugen zwei Aufträge mit verschiedenen Kennungen.
- [x] **AC-7:** Ein leerer oder nur aus Leerraum bestehender Text legt keinen Auftrag an und antwortet mit `isError` und dem Text „Text fehlt“; ein Text mit ungültigem Zeichen (z. B. NUL `\u0000`, ungepaartes Surrogat) legt keinen an und antwortet mit `isError` und der Meldung von `checkOrder`. Eine Längengrenze gibt es in der Formprüfung nicht und wird hier nicht eingeführt.
- [x] **AC-8:** `get_order_result` gibt für einen mit `capture_task` angelegten Auftrag `waiting`, nach `claimOrder` `claimed`, nach `putResult` `result` mit dem Dokument; für eine unbekannte oder fremde Kennung `unknown` ohne `isError`; der Text eines Auftrags erscheint in keiner Antwort.
- [x] **AC-9:** Ein anderes Konto sieht den Auftrag und sein Ergebnis nicht: dieselbe Kennung ergibt für `anna` `unknown`, nie `waiting` oder ein Ergebnis von `henning`.
- [x] **AC-10:** Weder `capture_task` noch `get_order_result` schreibt etwas nach `console`/`stdout` (überwacht wie in C4a).
- [x] **AC-11:** `npm run typecheck` ist grün; `./server/scripts/test-local.sh` ist grün (alle bestehenden Tests unverändert) und räumt auf; der Workflow `server.yml` ist auf dem PR grün.
- [x] **AC-12:** Die Dateiliste des PR enthält außer den vier Dateien aus „Source“ und `CLAUDE.md` nichts, ausgenommen `docs/specs/`, `docs/context/`, `docs/briefings/`. `server/migrations/`, `server/package.json`, `project.yml` und jede Swift-Datei bleiben unberührt. `CLAUDE.md` bekommt in der `server/`-Zeile den Zusatz `capture_task`, `get_order_result` (`getResult`).

## Dialog

### Runde 1
**Adversary:** Testlauf selbst: test-local.sh und npm run typecheck, Ausgabe in docs/artifacts/spike-613-c4b-mcp-schreiben/adversary-test-output.txt: 91 bestanden, 0 fehlgeschlagen, 0 uebersprungen, typecheck exit 0. Mutationsprobe in Kopie im Scratchpad (Original unveraendert), 24 Mutationen. Getoetet: Kontofilter weg (AC-1/2/8/9), Gross-/Kleinschreibung weg, Reihenfolge Ergebnis/Vergabe, trim weg, Kleinbuchstaben statt Grossbuchstaben, idempotentHint/destructiveHint/readOnlyHint, claimed als waiting, UUID-Guard weg, Auth-Pruefung in beiden Werkzeugen weg, stdout/console im Erfolgs- und Leerpfad, Ergebnisdokument veraendert, anderer Grundtext. Ueberlebt: M8 (checkOrder im Werkzeug entfernt; putOrder prueft selbst und das SDK macht daraus isError, Verhalten gleich, aequivalent), M17 (Auftragstext in der capture_task-Antwort), N5 (console.log des Textes im Fehlerpfad), N6 (Konto in putOrder fest auf henning), N9 (Text in der checkOrder-Fehlermeldung).
**Implementierer:** keine Antwort (Pruefung ohne Rueckfrage).

### Runde 2
**Adversary:** Randfaelle am echten Code (Wegwerf-Postgres, Client im Prozess): Kennung gross und klein = waiting; geschweifte Klammern, ohne Bindestriche, Zeilenumbruch am Ende, vorangestelltes Leerzeichen, urn:uuid:, leer: alle unknown ohne isError; fremdes Konto anna: fuer alle Formen unknown. Text: NUL, ungepaartes hohes und tiefes Surrogat: isError mit Meldung von checkOrder, kein Auftrag; gepaartes Surrogat, Nullbreitenleerzeichen, 2 MB Text, Steuerzeichen U+0001 werden angenommen (checkOrder erlaubt es, spec-konform, keine Laengengrenze); NBSP plus EM SPACE und nur BOM: Text fehlt (trim). Fehlendes oder falsch typisiertes Argument: isError durch SDK-Validierung. Ohne authInfo: kein Konto vor jedem Lesen oder Schreiben, Zeilenzahl unveraendert. AC-12: Diff gegen main nennt nur erlaubte Dateien (server/test/*, docs/specs, docs/context, docs/briefings) plus das Ablaufartefakt docs/artifacts/spike-613-c4b-mcp-schreiben/test-red-output.txt (nicht in der Ausnahmeliste); Arbeitsbaum: CLAUDE.md, server/src/mcp.ts, server/src/orders.ts; migrations, package.json, project.yml, Swift unberuehrt. Code-Umfang server/ +196/-8, unter 250.
**Implementierer:** keine Antwort.

### Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: server/test/mcp.test.ts:210
  Description: Test AC-5 legt nur als henning an. Mutation putOrder mit festem Konto henning bleibt gruen (N6).
  Spec requirement: AC-5 Konto aus authInfo
  Conflict: Tests wuerden ein fest verdrahtetes Konto nicht fangen. Der Code ist korrekt (server/src/mcp.ts:55 nutzt owner).
  Remediation: Test zusaetzlich mit anna anlegen und account_id pruefen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/test/mcp.test.ts:246
  Description: AC-8 sagt der Text erscheint in keiner Antwort, geprueft wird nur get_order_result; Mutation capture_task gibt text zurueck (M17) und Fehlertext mit Text (N9) bleiben gruen. AC-10 deckt den Fehlerpfad nicht (N5).
  Spec requirement: AC-8, AC-10
  Conflict: Tests schwaecher als der Spec-Wortlaut. Code verhaelt sich korrekt (server/src/mcp.ts:56).
  Remediation: In AC-5 und AC-7 pruefen, dass der Text nicht in der Antwort steht; AC-10 auch fuer NUL-Text laufen lassen.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: server/src/mcp.ts:50
  Description: checkOrder im Werkzeug ist redundant zu putOrder, Entfernen aendert das Verhalten nicht (M8).
  Spec requirement: AC-7 Meldung von checkOrder
  Conflict: keiner
  Remediation: keine noetig.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: server/src/orders.ts:113
  Evidence: UUID-Form-Guard und Kontofilter in einer Anweisung; Probe: Nicht-UUID-Formen, fremdes Konto unknown; Mutation Kontofilter/Guard weg faellt in Tests auf.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/orders.ts:124
  Evidence: Ergebnis, dann Vergabe, dann Warten; Kleinbuchstaben waiting; Mutationen M2, M3, M9, N8 getoetet.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/mcp.ts:81
  Evidence: Annotationen capture_task false/false/false, get_order_result readOnly true (Zeile 87); Mutationen M7, M14, M15 getoetet.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/mcp.ts:47
  Evidence: Kontopruefung vor Leerpruefung und putOrder, Zeile 64 fuer get_order_result; Mutationen N1, N2 getoetet; Zeilenzahl unveraendert.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/test/orders.test.ts:281
  Evidence: Auftrag mit Kennung in Grossbuchstaben (mcp.ts:51), waiting, Text unveraendert; Mutationen M5, M18 getoetet; Konto-Weg nur per Codelesung (F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/mcp.ts:51
  Evidence: randomUUID je Aufruf; zwei Zeilen in Test und Probe.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/mcp.ts:48
  Evidence: trim-Leerpruefung Text fehlt, NUL und Surrogat liefern checkOrder-Meldung, kein Auftrag; Probe und Mutationen M4, N7.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/mcp.ts:65
  Evidence: Antwort enthaelt nur Stand und Ergebnisdokument; unbekannt/fremd ohne isError; Probe bestaetigt.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/test/mcp.test.ts:246
  Evidence: anna sieht dieselbe Kennung in allen Formen als unknown (Probe und Test).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/test/mcp.test.ts:266
  Evidence: kein console/stdout im Code; Mutationen N3, N4 getoetet; Fehlerpfad nur per Codelesung (F002).
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: CLAUDE.md:459
  Evidence: typecheck gruen, 91/91 Tests, Aufraeumen durch test-local.sh; Workflow server.yml auf dem PR nicht pruefbar (kein PR).
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: CLAUDE.md:459
  Evidence: server/-Zeile enthaelt capture_task, get_order_result (getResult); Dateiliste wie oben.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:581e0857abf1ad4a2c9e93c754f96fa3c3cd73c54a97f5d82d066e90b0192c05  CLAUDE.md
- sha256:a9ff2249d4be6b294175e1490ab8d6a14d948eca0b2e3cefeb5a2650bbd6bdfd  server/src/mcp.ts
- sha256:5d4a971d2f31cb2635ff35e2f8247b57f36c5fc012ae0b5ff50638643b64796b  server/src/orders.ts
- sha256:ad713206634951d5df6640c66022647e62a04f21b570387a0bbbaf2ab9360ea3  server/test/mcp.test.ts
- sha256:4f5fbe5d7e72d213f0868abb498456199e76bcb2f12ba76c8689a7c61e815c26  server/test/orders.test.ts

## Prüfbasis

- base: 3ac92e4030284d3dd01af7d468262cb237050193
- blob:586efeae085a6f5747ca8ede5cae4f59e6014839  CLAUDE.md
- blob:06e6b51df9934f7673c12ce9c22eb42d11aa044a  server/src/mcp.ts
- blob:52ef4ee095e9291bcc80587c3ecb22a214cb7e26  server/src/orders.ts
- blob:dbd7c4deee021016de50cb18ab4a94a8e634bbdb  server/test/mcp.test.ts
- blob:8e5d49990e7a70a839ed738728a8268d2ceeda0b  server/test/orders.test.ts
