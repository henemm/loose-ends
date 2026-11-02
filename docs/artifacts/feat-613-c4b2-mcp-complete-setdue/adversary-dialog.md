# Adversary Dialog — feat-613-c4b2-mcp-complete-setdue
Spec: docs/specs/feat-613-c4b2-mcp-complete-setdue.md
Datum: 2026-11-02

## Checkliste
- [x] **AC-1:** sechs Namen sortiert, `complete_task`/`set_due` mit drei Hinweisen false, Beschreibung nennt `list_tasks` und `get_order_result` (mcp.ts:143-155)
- [x] **AC-2:** ohne `authInfo` „kein Konto“ vor dem Lesen, `orders` unverändert (mcp.ts:65-66)
- [x] **AC-3:** ohne Abschrift „noch keine Abschrift“, kein Auftrag (mcp.ts:68)
- [x] **AC-4:** abweichende `generatedAt` „Abschrift hat sich geändert, bitte neu lesen“, gleiche legt an (mcp.ts:70)
- [x] **AC-5:** unbekannte oder entfallene `taskID` abgelehnt, Kleinbuchstaben findet, Kennung aus der Abschrift (mcp.ts:71-73)
- [x] **AC-6:** complete-Auftrag mit erwartetem Stand, Schlüssel `expectedDueDate` fehlt ohne Fälligkeit
- [x] **AC-7:** setDue mit `date`/`hasTime` wie übergeben, ohne `date` ist `hasTime` falsch und der Schlüssel fehlt (mcp.ts:103-108)
- [x] **AC-8:** Antworttext gleich der Meldung von `checkOrder`, einschließlich Leerstring (mcp.test.ts:389-400)
- [x] **AC-9:** zwei Aufträge mit verschiedenen Kennungen, `waiting`
- [x] **AC-10:** kein Titel in Antworten, `anna` ohne Zugriff, Zähler unverändert
- [x] **AC-11:** keine Ausgabe nach `console`/`stdout`
- [x] **AC-12:** `typecheck` und 102/102 lokal grün; `server.yml` auf dem PR erst nach dem Öffnen prüfbar
- [x] **AC-13:** nur `CLAUDE.md`, `server/src/mcp.ts`, `server/test/mcp.test.ts` geändert; `orders.ts`, `transcripts.ts`, Migrationen, `package.json`, `project.yml` unberührt

## Dialog

### Runde 1
**Adversary:** `./server/scripts/test-local.sh` selbst gelaufen: typecheck ok, 102 Tests, 102 bestanden, 0 fehlgeschlagen. Dateiliste: nur CLAUDE.md, server/src/mcp.ts, server/test/mcp.test.ts. Angriffe: (a) taskID mit Leerzeichen oder leer; (b) generatedAt leer; (c) date als Leerstring; (d) hasTime wahr ohne date; (e) Status parked; (f) Schlüssel mit Wert undefined; (g) Titel oder Kennung in Logs oder Antworten; (h) geänderte Testzeile AC-7; (i) Mutationsfestigkeit.
**Implementierer:** Belege:
- (a) Vergleich `x.id.toUpperCase() === taskID.toUpperCase()` ohne trim; " ID" und "" finden nichts, „Aufgabe nicht in der Abschrift“, vor jedem Schreiben. Code reference: server/src/mcp.ts:64-74
- (b) leeres generatedAt ist ungleich, „Abschrift hat sich geändert, bitte neu lesen“. Code reference: server/src/mcp.ts:70
- (c) date "" trifft `checkOrder` und wird mit isError abgelehnt. Code reference: server/src/mcp.ts:77-84
- (d) `hasTime = date !== undefined && (args.hasTime ?? false)`. Code reference: server/src/mcp.ts:103; server/test/mcp.test.ts:369-387
- (e) parked wird als expectedStatus übernommen (AC-6-Test). Code reference: server/test/mcp.test.ts:348-365
- (f) Spreads sind bedingt; `Object.hasOwn`-Prüfung im Test. Code reference: server/src/mcp.ts:73,105-108
- (g) kein console/stdout in mcp.ts, Antwort nur `{orderID, state}`, AC-11 mockt console.log und stdout. Code reference: server/test/mcp.test.ts:419-432
- (h) Testzeile AC-7 berechtigt: `orders.id` ist uuid und kommt aus Postgres kleingeschrieben, das Dokument trägt Großbuchstaben. Code reference: server/test/mcp.test.ts:369-387
- (i) Mutationen gedanklich: toUpperCase entfernen → AC-5 rot; generatedAt-Prüfung entfernen → AC-4 rot; hasTime-Gating entfernen → AC-7 rot; Spread entfernen → Fälle ohne Fälligkeit rot.
Code reference: CLAUDE.md:459

### Runde 2
**Adversary:** (1) Ist `checkOrder` in `storing` wirksam, wo `putOrder` ohnehin prüft? (2) Prüft AC-8 die Meldung oder nur /date/? (3) Kommt „kein Konto“ vor jedem Lesen? (4) Ist das AC-5-Szenario echt? (5) Seiteneffekt bei anna?
**Implementierer:**
1. `putOrder` prüft selbst (orders.ts:64); Entfernen würde Tests nicht rot machen (F001, LOW). Code reference: server/src/mcp.ts:77-84
2. AC-8 prüfte nur `/date/` statt den Wortlaut (F002, LOW). Code reference: server/test/mcp.test.ts:389-399
3. `account(ctx)` ist die erste Anweisung. Code reference: server/src/mcp.ts:65-67
4. Szenario echt: ältere Abschrift führt fakeID(7), neuere ersetzt sie. Code reference: server/test/mcp.test.ts:328-346
5. anna: „noch keine Abschrift“, Zähler bleibt 2. Code reference: server/test/mcp.test.ts:402-417

### Runde 3
**Adversary:** Nachprüfung F002 und F001, `test-local.sh` neu gelaufen.
**Implementierer:** 102 Tests, 102 bestanden, 0 fehlgeschlagen.
- F002 behoben: AC-8 läuft über "", "morgen", "2026-03-12T17:00:00", "2026-02-30T10:00:00Z" und vergleicht den Antworttext exakt mit der Meldung von `checkOrder`. Code reference: server/test/mcp.test.ts:389-400
- F001: Mutationsprobe real ausgeführt (checkOrder in `storing` entfernt, 102/102 blieben grün, Code danach wiederhergestellt). Grund: `putOrder` wirft dieselbe Meldung. Bewertung: verhaltensgleiche Redundanz wie in `capturing` (mcp.ts:51), kein Defekt. Code reference: server/src/mcp.ts:77-84
- Dateiliste unverändert (+224/−4, unter 250). Code reference: CLAUDE.md:459

## Herkunft der Vorbedingungen
kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

Begründung: 102/102 Tests grün, alle Randfälle halten, F002 behoben, F001 als verhaltensgleiche Redundanz bewertet. Offen: `server.yml` auf dem PR (erst nach dem Öffnen prüfbar).

## Geprüfte Dateien

- sha256:a7af2c4ee9bfef0539d2be1d1f3fc80956ce2b1b6d833e77817da21a61fc61d9  CLAUDE.md

## Prüfbasis

- base: 66b3616df0a9ffa9fb5e58a9eb034b9797b2a20e
- blob:e3583874388c4347b744cb6252186160ad8660b9  CLAUDE.md

## Geprüfte Dateien

- sha256:a7af2c4ee9bfef0539d2be1d1f3fc80956ce2b1b6d833e77817da21a61fc61d9  CLAUDE.md

## Prüfbasis

- base: 66b3616df0a9ffa9fb5e58a9eb034b9797b2a20e
- blob:e3583874388c4347b744cb6252186160ad8660b9  CLAUDE.md
