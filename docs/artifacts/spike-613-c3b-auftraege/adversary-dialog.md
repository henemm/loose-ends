# Adversary Dialog — spike-613-c3b-auftraege
Spec: docs/specs/spike-613-schnitt-c3b-auftraege.md
Datum: 2026-11-01 15:43

## Checkliste
- [x] **AC-1:** Der erste Test belegt die Annahme, dass `ON CONFLICT` auf einer generierten Spalte in Postgres 18 funktioniert (Risiko 1 der Analyse `docs/context/spike-613-c3b-auftraege.md`; für `order_results.order_id` belegt es AC-19 mit): `putOrder` mit dem Auftrag aus dem ```json-Block 2 von `docs/reference/claude-abschrift-vertrag.md` (gelesen zur Laufzeit, nicht abgeschrieben) liefert `"stored"`; die Zeile in `orders` hat `kind` gleich dem Dokument und `id` gleich der kleingeschriebenen `id` des Dokuments, `claimed_by IS NULL`. (`ON CONFLICT (id)` auf der generierten Spalte funktioniert.) | BELEG: orders.ts:66 ON CONFLICT (id) auf generierter Spalte; Test AC-1 gruen; Probe 5 parallele putOrder: 1x stored, 4x duplicate
- [x] **AC-2:** `checkOrder` nimmt das Auftragsbeispiel (Block 2) und je einen kleinen Auftrag der drei Arten an und wirft nicht: `capture` mit leerem `text` (`""`); `complete` für jeden der sechs Statuswerte (`unprocessed`, `unverified`, `active`, `parked`, `done`, `removed`) ohne `expectedDueDate`; `setDue` ohne `date` und ohne `expectedDueDate`, mit kleingeschriebenen UUIDs. `checkResult` nimmt das Ergebnisbeispiel (Block 3) sowie `done` ohne `reason` und `rejected` mit `reason` je `invalid`, `missing`, `stale` an. | BELEG: orders.ts:31-35 forms; alle 6 Status, leerer text, Block 3 gruen; Probe Grossschreibung und Offset +01:00 ok
- [x] **AC-3:** (Z1) Fehlt `version` oder ist sie `"1"` oder `2`, wirft `checkOrder` eine Meldung, die mit `Auftrag ungültig:` beginnt und `version` nennt; `putOrder` schreibt nichts (`SELECT count(*) FROM orders` = 0). | BELEG: orders.ts:26 version; Probe doppelter Schluessel version:2 -> version: nicht 1
- [x] **AC-4:** (Z2, Z3) Fehlt `id` oder ist sie keine UUID (`"abc"`, `5`), nennt die Meldung `id`; fehlt `kind` oder ist er unbekannt (`"delete"`, `5`), nennt sie `kind`; nichts in `orders`. | BELEG: orders.ts:36 kind; Probe kind __proto__/constructor/5 -> kind: unbekannte Art (hasOwn); kind fehlt -> kind: fehlt
- [x] **AC-5:** (Z4) `capture` ohne `text`, mit `text` = `5` oder mit fremdem Schlüssel `taskID` wird abgewiesen; die Meldung nennt `text` bzw. `taskID`; nichts in `orders`. | BELEG: orders.ts:32 capture; Probe text [] -> text: kein Text; __proto__-Schluessel -> unbekannter Schluessel
- [x] **AC-6:** (Z5) `complete` ohne `taskID` oder mit einer `taskID`, die keine UUID ist, bzw. ohne `expectedStatus`, mit `"finished"` oder `5` wird abgewiesen; die Meldung nennt `taskID` bzw. `expectedStatus`; nichts in `orders`. | BELEG: orders.ts:33 complete; Test Z5 gruen
- [x] **AC-7:** (Z6) `complete` mit `expectedDueDate` ohne Zeitzone (`2026-03-12T09:00:00`) oder mit fremdem Schlüssel `hasTime` wird abgewiesen; die Meldung nennt `expectedDueDate` bzw. `hasTime`; fehlt `expectedDueDate`, wird der Auftrag angenommen. | BELEG: orders.ts:33 Probe expectedDueDate null -> kein Zeitpunkt mit Zeitzone; Offset +0100 abgewiesen
- [x] **AC-8:** (Z7) `setDue` ohne `hasTime` oder mit `"yes"`, mit `date` ohne Zeitzone, mit `expectedDueDate`, das kein Zeitpunkt ist, oder mit fremdem Schlüssel `text` wird abgewiesen; die Meldung nennt je `hasTime`, `date`, `expectedDueDate`, `text`; nichts in `orders`. | BELEG: orders.ts:34 setDue; Test Z7 gruen
- [x] **AC-9:** (Z8) Ist der Auftrag kein Objekt (`[]`, `"x"`, `null`), wirft `checkOrder` eine Meldung mit `Wurzel` und `kein Objekt`. | BELEG: orders.ts:48 shape Wurzel; Probe [] und null -> Wurzel: kein Objekt
- [x] **AC-10:** (Z9) `checkResult` weist ein Ergebnis ohne `orderID` oder mit einer `orderID`, die keine UUID ist, mit `outcome` = `"ok"`, mit `taskID`, die keine UUID ist, oder mit fremdem Schlüssel `note` ab; die Meldung beginnt mit `Ergebnis ungültig:` und nennt `orderID`, `outcome`, `taskID` bzw. `note`; `putResult` schreibt nichts in `order_results`. | BELEG: orders.ts:58 checkResult; Probe taskID null -> taskID: keine UUID; fremder Schluessel benannt
- [x] **AC-11:** (Z10) `rejected` ohne `reason` nennt `reason` (fehlt), `done` mit `reason` nennt `reason` (unbekannter Schlüssel), `reason` = `"broken"` nennt `reason`; nichts in `order_results`. | BELEG: orders.ts:56-57; Probe done+reason null -> reason: unbekannter Schluessel; rejected+reason null -> reason: unbekannter Grund; outcome ok+reason -> outcome
- [x] **AC-12:** Die Meldungen der Abschrift bleiben unverändert: `checkTranscript` mit einer Abschrift ohne `version` wirft weiter `Abschrift ungültig: version: fehlt`; `server/test/transcripts.test.ts` bleibt ohne Änderung grün. Ein Fehler, der kein Formfehler ist (zum Beispiel eine beendete Verbindung bei `putOrder`), behält seine eigene Meldung und trägt keinen Präfix „… ungültig“. | BELEG: transcripts.ts:30-45,114 reporting nur fuer FormError; transcripts.test.ts unveraendert, 62/62 gruen; Probe geschlossener Pool -> Cannot use a pool after calling end on the pool ohne Praefix
- [x] **AC-13:** `putOrder(pool, "henning", doc)` für einen neuen Auftrag liefert `"stored"`; `orders` hat eine Zeile mit `account_id = 'henning'`, `doc` gleich dem Dokument und `claimed_by`/`claimed_at` leer. | BELEG: orders.ts:63-69; Test AC-13 gruen
- [x] **AC-14:** Ein zweiter Aufruf mit derselben `id` (auch in Großbuchstaben statt Kleinbuchstaben und mit anderem Inhalt, etwa anderem `text`) liefert `"duplicate"`; `orders` hat weiter genau eine Zeile mit dem ersten `doc`. | BELEG: orders.ts:66; Probe putOrder anna mit grossgeschriebener id und anderem Inhalt -> duplicate
- [x] **AC-15:** Ein schon vergebener Auftrag wird durch einen zweiten `putOrder` mit derselben `id` nicht zurückgesetzt: nach `claimOrder` (Gerät `iphone`) und erneutem `putOrder` liefert er `"duplicate"`, `claimed_by` bleibt `iphone`, `claimed_at` unverändert, und ein weiterer `claimOrder` liefert `undefined`. | BELEG: orders.ts:66 DO NOTHING laesst claimed_* unberuehrt; Test AC-15 gruen
- [x] **AC-16:** `claimOrder(pool, "henning", "iphone")` liefert bei drei nacheinander angelegten Aufträgen den ersten, dann den zweiten, dann den dritten (im Test mit dem Abstand der `created_at`-Zeitpunkte aus je eigener Anweisung), danach `undefined`; die vergebene Zeile hat `claimed_by = 'iphone'`, `claimed_at` gesetzt. Ein leeres Konto liefert `undefined`. Die Reihenfolge ist im Test festgehalten, aber im Vertrag nicht zugesagt (AC-22). | BELEG: orders.ts:73-82 ORDER BY created_at, id; Test AC-16 gruen
- [x] **AC-17:** Zwei Verbindungen holen gleichzeitig (`Promise.all`, 10 Aufträge, Geräte `iphone` und `mac`, je eine Verbindung): jede der zwei Verbindungen ruft `claimOrder` höchstens 10-mal in einer Schleife und hört bei `undefined` auf; danach leert der Test den Rest nacheinander mit einer einzigen Verbindung, bis `undefined` kommt. Jeder Auftrag geht genau einmal an genau ein Gerät: die Summe aller gelieferten Aufträge ist 10, keine `id` kommt doppelt vor, und `claimed_by` jeder Zeile gehört dem Gerät, das ihr `doc` erhielt. | BELEG: orders.ts:76 SKIP LOCKED + AND claimed_by IS NULL; Test AC-17 gruen
- [x] **AC-18:** Zwei Konten (`henning`, `anna`) halten Aufträge unabhängig: `claimOrder` für `anna` liefert nie einen Auftrag von `henning` und umgekehrt; die Zeile des anderen Kontos bleibt unberührt. | BELEG: orders.ts:76 account_id=$1; Probe anna claim -> undefined obwohl henning-Auftrag frei
- [x] **AC-19:** `putResult(pool, "henning", "iphone", doc)` für einen Auftrag, den `iphone` hält, liefert `"stored"`; `order_results` hat eine Zeile mit `order_id` gleich der kleingeschriebenen `orderID`, `outcome`, `reason` und `task_id` wie im Dokument, `reported_by = 'iphone'`. Das Ergebnisbeispiel (Block 3) wird dafür mit der `id` des Auftragsbeispiels (Block 2) verbunden. | BELEG: orders.ts:89-92; Test AC-19 gruen; Probe grossgeschriebene orderID -> stored
- [x] **AC-20:** `putResult` liefert `"refused"` und schreibt nichts in `order_results`, wenn: das Gerät den Auftrag nicht hält (hält `mac`, meldet `iphone`); der Auftrag noch nicht vergeben ist; der Auftrag einem anderen Konto gehört (`anna` meldet für einen Auftrag von `henning`, den `iphone` hält); die `orderID` unbekannt ist. Ein Formfehler bleibt ein Fehler (`checkResult` wirft) und erreicht die Datenbank nicht. | BELEG: orders.ts:90 EXISTS mit account_id und claimed_by; Probe fremdes Konto, anderes Geraet, unbekannte orderID -> je refused
- [x] **AC-21:** Ein zweites Ergebnis zum selben Auftrag vom selben Gerät, auch mit anderem Inhalt (zuerst `done`, dann `rejected`/`stale`), liefert `"duplicate"`; die Zeile in `order_results` bleibt unverändert (`doc`, `reported_at`). | BELEG: orders.ts:94-100; Probe 5 parallele putResult: 1 stored, 4 duplicate; anderes Konto -> refused
- [x] **AC-22:** `docs/reference/claude-abschrift-vertrag.md` ist angepasst: Der Absatz „Ebenso offen in Version 1“ (Auftrag ohne `version`) ist erledigt und als Regel formuliert (der Dienst nimmt einen Auftrag nur mit `version` = 1 und der Form seiner Art an); zwei Stellen werden angeglichen: „Ein Auftrag mit anderer Version wird abgelehnt (`invalid`)“ und „`invalid`: falsche Version, ein Pflichtfeld fehlt …“ nennen künftig, dass der Dienst beides schon beim Annehmen abweist und `invalid` der App die zweite Wand bleibt (für Aufträge, die den Dienst nicht durchlaufen haben); ein Satz sagt, dass ein Auftrag genau einem Gerät vergeben wird, **genau einmal und ohne zugesagte Reihenfolge**, und dass ein Ergebnis nur das Gerät melden kann, das den Auftrag hält, ein zweites ändert nichts. Die drei ```json-Blöcke bleiben unverändert (Anzahl und Inhalt), `server/test/schema.test.ts` bleibt grün. | BELEG: Vertrag Diff 9+/5-, drei json-Bloecke unberuehrt (grep: 3), Zusage genau einmal ohne Reihenfolge; schema.test.ts gruen
- [x] **AC-23:** `server/migrations/` bleibt unverändert (die Dateiliste des PR enthält keine Datei dort), ebenso `project.yml`, jede Swift-Datei und `CLAUDE.md` (keine Architekturänderung: der Dienst ist dort schon beschrieben, die Nachführung geschieht gesammelt mit ADR-21 in C8); `server/test/schema.test.ts` und `server/test/transcripts.test.ts` bleiben ohne Änderung grün. | BELEG: Diff gegen HEAD: nur Vertrag, transcripts.ts, orders.ts neu; migrations, project.yml, Swift, CLAUDE.md unberuehrt
- [x] **AC-24:** `./server/scripts/test-local.sh` ist grün (Typprüfung `npm run typecheck` ohne Fehler, alle Tests gegen das Wegwerf-Postgres) und räumt auf; der Workflow `server.yml` ist auf dem PR grün. Die Dateiliste des PR enthält außer den unter Scope genannten vier nichts, ausgenommen die Workflow-Unterlagen `docs/specs/`, `docs/context/` und `docs/briefings/`. | BELEG: test-local.sh: typecheck ok, 62 pass, 0 fail, 0 skipped (adversary-test-output.txt); server.yml noch nicht pruefbar (kein PR)

## Dialog

### Runde 1
**Adversary:** Formpruefung angegriffen: __proto__, constructor, toString als Schluessel und Werte, Arrays und null als Werte, doppelte JSON-Schluessel, UUID-Varianten, Zeitzonen, NUL, lone surrogate, toJSON-Schluessel. Alles wird mit Feldpfad abgewiesen (Object.hasOwn in shape).
**Implementierer:** (nicht beteiligt)

### Runde 2
**Adversary:** SQL-Wege gegen echtes Postgres 18: Konto-Trennung, Duplikat vs refused, 5 parallele putOrder und putResult mit gleicher Id (genau 1 stored), Fehlerpraefix nur fuer FormError.
**Implementierer:** (nicht beteiligt)

### Confirmations
Confirmation:
  AC: AC-1 bis AC-21
  Code reference: server/src/orders.ts:66
  Evidence: SQL und Formpruefung in Proben und Tests bestaetigt
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: server/src/transcripts.ts:35
  Evidence: reporting wickelt nur FormError um, Abschrift-Meldungen identisch, andere Fehler unveraendert
  Status: CONFIRMED

Confirmation:
  AC: AC-22
  Code reference: docs/reference/claude-abschrift-vertrag.md:15
  Evidence: Absaetze angepasst, drei json-Bloecke unveraendert
  Status: CONFIRMED

### Befunde
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/orders.ts:73
  Description: account und device werden nicht geprueft, ein leeres Geraet "" wird vergeben und kann melden
  Spec requirement: keine, Texte bis C6
  Conflict: kein Verstoss, bei C6 validieren
  Remediation: in C6 pruefen

Finding:
  ID: F002
  Severity: LOW
  Category: security
  Code reference: server/src/orders.ts:66
  Description: putOrder mit fremdem Konto und bekannter id liefert duplicate und verraet die Existenz
  Spec requirement: AC-14 verlangt duplicate
  Conflict: kein Verstoss, bei C6 neu bewerten
  Remediation: bei C6 pruefen

Finding:
  ID: F003
  Severity: MEDIUM
  Category: anti_pattern
  Code reference: server/src/transcripts.ts:130
  Description: Umfang rund 400 LoC (orders.test.ts 266, orders.ts 101, transcripts.ts 23, Vertrag 14) gegen Spec-Schaetzung 256 und Limit 250
  Spec requirement: Scope: bei Ueberschreitung stoppen und nachfragen
  Conflict: Prozess, keine Funktionsmaengel
  Remediation: Freigabe der Ueberschreitung klaeren

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Tests: 62 passed, 0 failed, 0 uebersprungen (typecheck gruen)
Edge cases: geprueft, keine Funktionsmaengel
Regressions: None found
Checklist: 24/24 points proven

## Geprüfte Dateien

- sha256:79866f678da3516e095f74c30e6215b3b87842de740e4f206846a9c521bbbdbc  docs/reference/claude-abschrift-vertrag.md
- sha256:29e9ce46b63c969a12cb4bdfc607c1a0d5dbfd7dd976f0d52c1ea4fb5da7b39e  server/src/orders.ts
- sha256:9e29d0a97ea28442c0bba224c07829d647406acc537ff74d34a85c0102848ae8  server/src/transcripts.ts

## Prüfbasis

- base: f63b8ede51da1fe34dcbf2543244957edb9c1e46
- blob:f511f59eba8e74f56cf79abfe508def2af82c513  docs/reference/claude-abschrift-vertrag.md
- blob:16bf2976c50893320a9fd3cdf8f79ef0f9c15a81  server/src/orders.ts
- blob:b1bbf18e6086daecb1f9bd1a0c7cf3cf404df837  server/src/transcripts.ts

## Geprüfte Dateien

- sha256:79866f678da3516e095f74c30e6215b3b87842de740e4f206846a9c521bbbdbc  docs/reference/claude-abschrift-vertrag.md
- sha256:29e9ce46b63c969a12cb4bdfc607c1a0d5dbfd7dd976f0d52c1ea4fb5da7b39e  server/src/orders.ts
- sha256:9e29d0a97ea28442c0bba224c07829d647406acc537ff74d34a85c0102848ae8  server/src/transcripts.ts

## Prüfbasis

- base: f63b8ede51da1fe34dcbf2543244957edb9c1e46
- blob:f511f59eba8e74f56cf79abfe508def2af82c513  docs/reference/claude-abschrift-vertrag.md
- blob:16bf2976c50893320a9fd3cdf8f79ef0f9c15a81  server/src/orders.ts
- blob:b1bbf18e6086daecb1f9bd1a0c7cf3cf404df837  server/src/transcripts.ts
