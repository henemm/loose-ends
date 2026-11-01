---
entity_id: spike-613-schnitt-c3b-auftraege
type: feature
created: 2026-11-01
updated: 2026-11-01
status: draft
workflow: spike-613-c3b-auftraege
---

# Spec: Aufträge annehmen, einem Gerät vergeben, Ergebnis annehmen, Schnitt C3b (#613, Weg B „Fenster für Claude“)

## Approval

- [ ] Approved

## GitHub Issue

#613 (Spike, Epic #612). Schnitt C3b; das Issue bleibt offen (`Refs #613`, nie `Closes #613`).
Vorgänger: C3a (`docs/specs/spike-613-schnitt-c3a-abschrift-annehmen.md`, PR #791), C1b (`docs/specs/spike-613-schnitt-c1b-schema.md`, PR #789), C1a (`docs/specs/spike-613-schnitt-c1a-server-geruest.md`, PR #785), Vertrag v1 (`docs/reference/claude-abschrift-vertrag.md`).
Analyse: `docs/context/spike-613-c3b-auftraege.md`. Weitere Folgeschnitte (MCP, A/B-Nachweis, Anmeldung, Betrieb) sind nicht Teil dieser Spec.

## Purpose

Der Dienstkern kennt seit C3a die Abschrift. Dieser Schnitt baut den zweiten Teil: den Auftragsweg. Funktionen über `pg`, ohne HTTP, ohne Anmeldung
(`account_id` und `device` sind übergebene Texte bis C6):
`checkOrder(doc)` und `checkResult(doc)` prüfen die Form und nennen bei einer Abweichung den Feldpfad;
`putOrder(pool, account, doc)` legt einen Auftrag an, ein doppelt angelegter ändert nichts;
`claimOrder(pool, account, device)` vergibt den nächsten freien Auftrag des Kontos an genau ein Gerät;
`putResult(pool, account, device, doc)` nimmt das Ergebnis nur für einen Auftrag an, den dieses Gerät hält.
Damit ist auch der Punkt aus dem Vertrag erledigt, dass ein Auftrag ohne `version` für die App kein gültiges JSON ist: der Dienst prüft `version` schon beim Annehmen.

Der Dienst prüft Form, keine Bedeutung. Ein `complete` mit `expectedStatus` `done` oder `removed` wird durchgereicht; `invalid` bleibt, wie im Vertrag, ein Ergebnis der App.
Die Datenbank bleibt die zweite Wand; Migration 001 ändert sich nicht.

**Regeln vor Modell:** Alles ist Regel, Formprüfung und SQL (Typen, UUID-Muster, Schlüsselmengen, eine Anweisung je Vergabe); kein Sprachmodell beteiligt. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Keine neue Produktentscheidung: Weg B (iCloud bleibt der Abgleich, eigener Dienst nur für Abschrift und Auftragsweg) ist in #612 entschieden und wird mit ADR-21 in C8 festgehalten;
  der Grundsatz „der Dienst rechnet nichts nach“ und die Rolle der App als Ausführer stehen im Vertrag v1. Dieser Schnitt setzt sie im Dienst um.

## Source

**Files:** `server/src/orders.ts` (neu), `server/src/transcripts.ts` (Bausteine exportiert, `fail` mit Präfix je Gegenstand)
**Identifier:** in `orders.ts`: `checkOrder`, `checkResult`, `putOrder`, `claimOrder`, `putResult`, die Typen `Order`, `OrderResult` und der Baustein `orderStatus`; in `transcripts.ts`: `FormError`, `reporting`

### Server: Umbau in `transcripts.ts`

- `shape`, `id`, `text`, `flag`, `time`, `list`, `fail` und der Typ `Check` werden mit einer einzigen Zeile `export { … }` am Dateiende freigegeben, ohne sie zu verschieben und ohne ihre Zeilen anzufassen (das hält den Diff klein). `isObject` und `privacy` bleiben privat: der Auftrag und das Ergebnis haben keine Datenschutzlinie, und `shape` prüft die Wurzel selbst.
- `fail(path, reason)` verliert sein fest eingebautes Präfix „Abschrift ungültig:“ und wirft einen `FormError` mit nur `<Pfad>: <Grund>` (Unterklasse von `Error`, exportiert); die kleine Hilfe `reporting(subject, run)` fängt ihn und wirft ihn mit dem Präfix des Gegenstands neu; `checkTranscript`, `checkOrder` und `checkResult` laufen durch sie.
  Die Meldung lautet `<Gegenstand> ungültig: <Pfad>: <Grund>` mit „Abschrift“, „Auftrag“ oder „Ergebnis“. Die Meldungen der Abschrift bleiben Zeichen für Zeichen unverändert (`transcripts.test.ts` bleibt ohne Änderung grün).
- Fehler, die kein `FormError` sind (Datenbank, Verbindung), werden nicht umbenannt und nicht verschluckt.

### Server: `checkOrder(doc: unknown): asserts doc is Order`

Wirft `Error` mit der Meldung `Auftrag ungültig: <Feldpfad>: <Grund>` bei der ersten Abweichung. Erlaubt ist die Form des Vertrags (Abschnitt „Auftrag“) und von `Order` in `OrderExecutor.swift`; dort sind `text`, `taskID`, `expectedStatus` und `hasTime` optional, der Dienst macht sie je Art zur Pflicht (ein fehlendes Feld ist ein Formfehler mit Feldnamen, nicht erst `invalid` der App):

- Gemeinsam, Pflicht: `version` (die Zahl 1), `id` (UUID, Groß- und Kleinschreibung), `kind` (`capture`, `complete` oder `setDue`; sonst `kind: unbekannte Art`).
- `capture`: `text` (String). Kein weiterer Schlüssel. Ein leerer Text ist formgültig; ihn lehnt die App als `invalid` ab.
- `complete`: `taskID` (UUID), `expectedStatus` (neuer Baustein `orderStatus` in `orders.ts`, denn `status` aus `transcripts.ts` kennt nur vier Werte; einer der sechs Statuswerte der App: `unprocessed`, `unverified`, `active`, `parked`, `done`, `removed`); optional `expectedDueDate` (Zeitpunkt mit Zeitzone, `time`-Baustein; fehlt = keine Fälligkeit erwartet).
- `setDue`: `taskID` (UUID), `hasTime` (Boolean); optional `date` und `expectedDueDate` (je Zeitpunkt mit Zeitzone).
- Ein Schlüssel außerhalb der Liste der Art ist `<Pfad>: unbekannter Schlüssel` (zum Beispiel `text` an einem `setDue`).
- Der Dienst rechnet nichts nach: ob `taskID` in der Abschrift steht oder `expectedStatus` zum Auftrag passt, wird nicht geprüft.

### Server: `checkResult(doc: unknown): asserts doc is OrderResult`

Meldung `Ergebnis ungültig: <Feldpfad>: <Grund>`. Schlüssel: `orderID` (UUID), `outcome` (`done` oder `rejected`) Pflicht; `reason` (`invalid`, `missing` oder `stale`) genau bei `rejected` (bei `done` ist `reason` ein unbekannter Schlüssel, bei `rejected` ohne `reason` meldet der Dienst `reason: fehlt`); `taskID` (UUID) optional; kein weiterer Schlüssel.
Die Datenbank erzwingt „`reason` genau bei `rejected`“ schon; der Dienst prüft es vorher, damit die Meldung einen Feldnamen trägt.

### Server: `putOrder(pool, account, doc): Promise<"stored" | "duplicate">`

1. `checkOrder(doc)`; bei Abweichung wirft die Funktion und schreibt nichts.
2. Eine Anweisung: `INSERT INTO orders (doc, account_id) VALUES ($1::jsonb, $2) ON CONFLICT (id) DO NOTHING RETURNING id`.
3. Eine Zeile: `"stored"`. Keine: `"duplicate"` (die Zeile, auch ein schon vergebener Auftrag mit `claimed_by`, bleibt unverändert).

`ON CONFLICT (id)` zielt auf eine generierte Spalte (`id` aus `doc->>'id'`). Postgres erlaubt das (die Spalte trägt den eindeutigen Index des Primärschlüssels); der erste RED-Test belegt es, bevor darauf gebaut wird.

### Server: `claimOrder(pool, account, device): Promise<Order | undefined>`

Eine Anweisung:
`UPDATE orders SET claimed_by = $2, claimed_at = now() WHERE id = (SELECT id FROM orders WHERE account_id = $1 AND claimed_by IS NULL ORDER BY created_at, id FOR UPDATE SKIP LOCKED LIMIT 1) AND claimed_by IS NULL RETURNING doc`.
Eine Zeile: ihre `doc` (der Auftrag). Keine: `undefined` (nichts frei, oder der freie ist gerade bei einer anderen Verbindung in Vergabe).
Ein gesperrter Auftrag wird übersprungen; ein zweites Gerät bekommt den nächsten oder nichts. **Zugesagt wird nur „genau einmal“**: `SKIP LOCKED` garantiert keine strenge Reihenfolge, `created_at, id` ist die bevorzugte, aber keine zugesagte.
Ein Gerät, das nach der Vergabe abstürzt, hält seinen Auftrag, bis es eine Rückholregel gibt (C7, nicht hier).

### Server: `putResult(pool, account, device, doc): Promise<"stored" | "duplicate" | "refused">`

1. `checkResult(doc)`; bei Abweichung wirft die Funktion und schreibt nichts (Formfehler bleiben Fehler, nur ein fremder Auftrag ist ein Wert).
2. Eine Anweisung: `INSERT INTO order_results (doc, reported_by) SELECT $1::jsonb, $3 WHERE EXISTS (SELECT 1 FROM orders WHERE id = ($1::jsonb->>'orderID')::uuid AND account_id = $2 AND claimed_by = $3) ON CONFLICT (order_id) DO NOTHING RETURNING order_id`.
3. Eine Zeile: `"stored"`. Keine Zeile: Folgeabfrage, ob zu dieser `orderID` schon ein Ergebnis eines Auftrags dieses Kontos da ist, das dieses Gerät meldete: dann `"duplicate"`, sonst `"refused"` (unbekannter Auftrag, Auftrag eines anderen Kontos, nicht vergeben, von einem anderen Gerät gehalten).

Ein zweites Ergebnis ändert nichts (Primärschlüssel = Fremdschlüssel auf den Auftrag).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/migrations/001_claude_schema.sql` (C1b) | Tabellen `orders` (generierte `id`, `kind`; `claimed_by`/`claimed_at` beide oder keins) und `order_results` (PK = FK, `reason` genau bei `rejected`), **unverändert** |
| `server/src/transcripts.ts` (C3a) | Formbausteine (`shape`, `id`, `text`, `flag`, `time`, `list`, `fail`, Typ `Check`), jetzt exportiert |
| `server/test/db.ts` (`freshPool`), `server/src/migrate.ts` (`migrate`) | Testaufbau: eigenes Schema je Test, Migration auf den echten Ordner |
| Vertrag v1 `docs/reference/claude-abschrift-vertrag.md` | Quelle der Beispiele (Test liest die ```json-Blöcke zur Laufzeit: Block 2 = Auftrag, Block 3 = Ergebnis) |
| `Shared/Services/OrderExecutor.swift`, `Shared/Models/Enums.swift` | nur gelesen: Form von `Order`/`OrderResult`, sechs Werte von `TaskStatus`; **keine Swift-Datei geändert** |
| Postgres 18 (lokal Wegwerf-Instanz, CI `postgres:18`), `pg` 8.23.1, `node:test` | bestehend; **keine neuen Abhängigkeiten** |

## Abweichungstabelle der Formprüfung

Je Zeile ein eigener `t.test` in `server/test/orders.test.ts`: das Vertragsbeispiel der jeweiligen Art, eine Änderung, Ablehnung mit deutscher Meldung, die den Feldpfad nennt, und danach ist `orders` (bzw. `order_results`) leer.
Die Beispiele je `kind` und für `capture` stammen aus dem Vertragsblock 2 (zur Laufzeit gelesen) und werden dort, wo der Block die Art nicht zeigt, vom Test aus ihm abgeleitet (Schlüssel getauscht).

| Zeile | Änderung am Beispiel | Meldung nennt |
|---|---|---|
| Z1 | `version` fehlt; `"1"`; `2` | `Auftrag ungültig: version` |
| Z2 | `id` fehlt; keine UUID (`"abc"`, `5`) | `id` |
| Z3 | `kind` fehlt; `"delete"`; `5` | `kind` |
| Z4 | `capture`: `text` fehlt; `text` ist `5`; fremder Schlüssel `taskID` | `text`; `taskID` |
| Z5 | `complete`: `taskID` fehlt oder keine UUID; `expectedStatus` fehlt, `"finished"` oder `5` | `taskID`; `expectedStatus` |
| Z6 | `complete`: `expectedDueDate` ohne Zeitzone (`2026-03-12T09:00:00`); fremder Schlüssel `hasTime` | `expectedDueDate`; `hasTime` |
| Z7 | `setDue`: `hasTime` fehlt oder `"yes"`; `date` ohne Zeitzone; `expectedDueDate` kein Zeitpunkt; fremder Schlüssel `text` | `hasTime`; `date`; `expectedDueDate`; `text` |
| Z8 | Auftrag ist kein Objekt (`[]`, `"x"`, `null`) | `Wurzel` |
| Z9 | Ergebnis: `orderID` fehlt oder keine UUID; `outcome` `"ok"`; `taskID` keine UUID; fremder Schlüssel `note` | `orderID`; `outcome`; `taskID`; `note` |
| Z10 | Ergebnis: `rejected` ohne `reason`; `done` mit `reason`; `reason` `"broken"` | `Ergebnis ungültig: reason` |

## Acceptance Criteria

- **AC-1:** Der erste Test belegt die Annahme, dass `ON CONFLICT` auf einer generierten Spalte in Postgres 18 funktioniert (Risiko 1 der Analyse `docs/context/spike-613-c3b-auftraege.md`; für `order_results.order_id` belegt es AC-19 mit): `putOrder` mit dem Auftrag aus dem ```json-Block 2 von `docs/reference/claude-abschrift-vertrag.md` (gelesen zur Laufzeit, nicht abgeschrieben) liefert `"stored"`; die Zeile in `orders` hat `kind` gleich dem Dokument und `id` gleich der kleingeschriebenen `id` des Dokuments, `claimed_by IS NULL`. (`ON CONFLICT (id)` auf der generierten Spalte funktioniert.)
- **AC-2:** `checkOrder` nimmt das Auftragsbeispiel (Block 2) und je einen kleinen Auftrag der drei Arten an und wirft nicht: `capture` mit leerem `text` (`""`); `complete` für jeden der sechs Statuswerte (`unprocessed`, `unverified`, `active`, `parked`, `done`, `removed`) ohne `expectedDueDate`; `setDue` ohne `date` und ohne `expectedDueDate`, mit kleingeschriebenen UUIDs. `checkResult` nimmt das Ergebnisbeispiel (Block 3) sowie `done` ohne `reason` und `rejected` mit `reason` je `invalid`, `missing`, `stale` an.
- **AC-3:** (Z1) Fehlt `version` oder ist sie `"1"` oder `2`, wirft `checkOrder` eine Meldung, die mit `Auftrag ungültig:` beginnt und `version` nennt; `putOrder` schreibt nichts (`SELECT count(*) FROM orders` = 0).
- **AC-4:** (Z2, Z3) Fehlt `id` oder ist sie keine UUID (`"abc"`, `5`), nennt die Meldung `id`; fehlt `kind` oder ist er unbekannt (`"delete"`, `5`), nennt sie `kind`; nichts in `orders`.
- **AC-5:** (Z4) `capture` ohne `text`, mit `text` = `5` oder mit fremdem Schlüssel `taskID` wird abgewiesen; die Meldung nennt `text` bzw. `taskID`; nichts in `orders`.
- **AC-6:** (Z5) `complete` ohne `taskID` oder mit einer `taskID`, die keine UUID ist, bzw. ohne `expectedStatus`, mit `"finished"` oder `5` wird abgewiesen; die Meldung nennt `taskID` bzw. `expectedStatus`; nichts in `orders`.
- **AC-7:** (Z6) `complete` mit `expectedDueDate` ohne Zeitzone (`2026-03-12T09:00:00`) oder mit fremdem Schlüssel `hasTime` wird abgewiesen; die Meldung nennt `expectedDueDate` bzw. `hasTime`; fehlt `expectedDueDate`, wird der Auftrag angenommen.
- **AC-8:** (Z7) `setDue` ohne `hasTime` oder mit `"yes"`, mit `date` ohne Zeitzone, mit `expectedDueDate`, das kein Zeitpunkt ist, oder mit fremdem Schlüssel `text` wird abgewiesen; die Meldung nennt je `hasTime`, `date`, `expectedDueDate`, `text`; nichts in `orders`.
- **AC-9:** (Z8) Ist der Auftrag kein Objekt (`[]`, `"x"`, `null`), wirft `checkOrder` eine Meldung mit `Wurzel` und `kein Objekt`.
- **AC-10:** (Z9) `checkResult` weist ein Ergebnis ohne `orderID` oder mit einer `orderID`, die keine UUID ist, mit `outcome` = `"ok"`, mit `taskID`, die keine UUID ist, oder mit fremdem Schlüssel `note` ab; die Meldung beginnt mit `Ergebnis ungültig:` und nennt `orderID`, `outcome`, `taskID` bzw. `note`; `putResult` schreibt nichts in `order_results`.
- **AC-11:** (Z10) `rejected` ohne `reason` nennt `reason` (fehlt), `done` mit `reason` nennt `reason` (unbekannter Schlüssel), `reason` = `"broken"` nennt `reason`; nichts in `order_results`.
- **AC-12:** Die Meldungen der Abschrift bleiben unverändert: `checkTranscript` mit einer Abschrift ohne `version` wirft weiter `Abschrift ungültig: version: fehlt`; `server/test/transcripts.test.ts` bleibt ohne Änderung grün. Ein Fehler, der kein Formfehler ist (zum Beispiel eine beendete Verbindung bei `putOrder`), behält seine eigene Meldung und trägt keinen Präfix „… ungültig“.
- **AC-13:** `putOrder(pool, "henning", doc)` für einen neuen Auftrag liefert `"stored"`; `orders` hat eine Zeile mit `account_id = 'henning'`, `doc` gleich dem Dokument und `claimed_by`/`claimed_at` leer.
- **AC-14:** Ein zweiter Aufruf mit derselben `id` (auch in Großbuchstaben statt Kleinbuchstaben und mit anderem Inhalt, etwa anderem `text`) liefert `"duplicate"`; `orders` hat weiter genau eine Zeile mit dem ersten `doc`.
- **AC-15:** Ein schon vergebener Auftrag wird durch einen zweiten `putOrder` mit derselben `id` nicht zurückgesetzt: nach `claimOrder` (Gerät `iphone`) und erneutem `putOrder` liefert er `"duplicate"`, `claimed_by` bleibt `iphone`, `claimed_at` unverändert, und ein weiterer `claimOrder` liefert `undefined`.
- **AC-16:** `claimOrder(pool, "henning", "iphone")` liefert bei drei nacheinander angelegten Aufträgen den ersten, dann den zweiten, dann den dritten (im Test mit dem Abstand der `created_at`-Zeitpunkte aus je eigener Anweisung), danach `undefined`; die vergebene Zeile hat `claimed_by = 'iphone'`, `claimed_at` gesetzt. Ein leeres Konto liefert `undefined`. Die Reihenfolge ist im Test festgehalten, aber im Vertrag nicht zugesagt (AC-22).
- **AC-17:** Zwei Verbindungen holen gleichzeitig (`Promise.all`, 10 Aufträge, Geräte `iphone` und `mac`, je eine Verbindung): jede der zwei Verbindungen ruft `claimOrder` höchstens 10-mal in einer Schleife und hört bei `undefined` auf; danach leert der Test den Rest nacheinander mit einer einzigen Verbindung, bis `undefined` kommt. Jeder Auftrag geht genau einmal an genau ein Gerät: die Summe aller gelieferten Aufträge ist 10, keine `id` kommt doppelt vor, und `claimed_by` jeder Zeile gehört dem Gerät, das ihr `doc` erhielt.
- **AC-18:** Zwei Konten (`henning`, `anna`) halten Aufträge unabhängig: `claimOrder` für `anna` liefert nie einen Auftrag von `henning` und umgekehrt; die Zeile des anderen Kontos bleibt unberührt.
- **AC-19:** `putResult(pool, "henning", "iphone", doc)` für einen Auftrag, den `iphone` hält, liefert `"stored"`; `order_results` hat eine Zeile mit `order_id` gleich der kleingeschriebenen `orderID`, `outcome`, `reason` und `task_id` wie im Dokument, `reported_by = 'iphone'`. Das Ergebnisbeispiel (Block 3) wird dafür mit der `id` des Auftragsbeispiels (Block 2) verbunden.
- **AC-20:** `putResult` liefert `"refused"` und schreibt nichts in `order_results`, wenn: das Gerät den Auftrag nicht hält (hält `mac`, meldet `iphone`); der Auftrag noch nicht vergeben ist; der Auftrag einem anderen Konto gehört (`anna` meldet für einen Auftrag von `henning`, den `iphone` hält); die `orderID` unbekannt ist. Ein Formfehler bleibt ein Fehler (`checkResult` wirft) und erreicht die Datenbank nicht.
- **AC-21:** Ein zweites Ergebnis zum selben Auftrag vom selben Gerät, auch mit anderem Inhalt (zuerst `done`, dann `rejected`/`stale`), liefert `"duplicate"`; die Zeile in `order_results` bleibt unverändert (`doc`, `reported_at`).
- **AC-22:** `docs/reference/claude-abschrift-vertrag.md` ist angepasst: Der Absatz „Ebenso offen in Version 1“ (Auftrag ohne `version`) ist erledigt und als Regel formuliert (der Dienst nimmt einen Auftrag nur mit `version` = 1 und der Form seiner Art an); zwei Stellen werden angeglichen: „Ein Auftrag mit anderer Version wird abgelehnt (`invalid`)“ und „`invalid`: falsche Version, ein Pflichtfeld fehlt …“ nennen künftig, dass der Dienst beides schon beim Annehmen abweist und `invalid` der App die zweite Wand bleibt (für Aufträge, die den Dienst nicht durchlaufen haben); ein Satz sagt, dass ein Auftrag genau einem Gerät vergeben wird, **genau einmal und ohne zugesagte Reihenfolge**, und dass ein Ergebnis nur das Gerät melden kann, das den Auftrag hält, ein zweites ändert nichts.
  Die drei ```json-Blöcke bleiben unverändert (Anzahl und Inhalt), `server/test/schema.test.ts` bleibt grün.
- **AC-23:** `server/migrations/` bleibt unverändert (die Dateiliste des PR enthält keine Datei dort), ebenso `project.yml`, jede Swift-Datei und `CLAUDE.md` (keine Architekturänderung: der Dienst ist dort schon beschrieben, die Nachführung geschieht gesammelt mit ADR-21 in C8); `server/test/schema.test.ts` und `server/test/transcripts.test.ts` bleiben ohne Änderung grün.
- **AC-24:** `./server/scripts/test-local.sh` ist grün (Typprüfung `npm run typecheck` ohne Fehler, alle Tests gegen das Wegwerf-Postgres) und räumt auf; der Workflow `server.yml` ist auf dem PR grün.
  Die Dateiliste des PR enthält außer den unter Scope genannten vier nichts, ausgenommen die Workflow-Unterlagen `docs/specs/`, `docs/context/` und `docs/briefings/`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/orders.ts` | CREATE | `checkOrder` (Form je `kind`), `checkResult`, `putOrder`, `claimOrder`, `putResult`, ~90 Zeilen |
| `server/test/orders.test.ts` | CREATE | Abweichungstabelle je `kind` (ein `t.test` je Zeile), Beispiele aus dem Vertrag, Anlegen, Vergabe über zwei Verbindungen, Ergebnis nur vom haltenden Gerät, zwei Konten, ~140 Zeilen |
| `server/src/transcripts.ts` | MODIFY | Bausteine eine `export { … }`-Zeile, `FormError`, Präfix je Gegenstand über `reporting`, ~+15/−2 |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Absatz „Ebenso offen in Version 1“ erledigt, Zusage zur Vergabe, ~+5/−4 |

### Estimated Changes

- Files: 4 (innerhalb von 4–5)
- LoC: ~+250/−6 = ~256 (90 + 140 + 15 + 5 Zugänge, Löschungen 2 + 4); **das liegt an der Grenze von 250 Zeilen und knapp darüber**, die Überschreitung um wenige Zeilen wird hiermit zur Freigabe genannt (Tests haben den Faktor ~1,5 zum Code, nicht verhandelbar bei Nebenläufigkeit).
  Jede Funktion ≤ 50 Zeilen (die Formprüfung je Art ist eine Tabelle aus Prüfern, `shape` aus C3a wird wiederverwendet; Testfälle als Tabellen gebündelt).
  Bei Überschreitung von 250 Zeilen: stoppen und nachfragen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Änderung an `project.yml`, keine Migration; `./scripts/sim.sh generate` ist nicht nötig. Keine Audiodateien. Keine Swift-Datei.
- Seiteneffekt außerhalb des Tickets: keiner. Nichts in der App und nichts im Dienst ruft die neuen Funktionen auf (MCP kommt mit C4, die App holt Aufträge mit C5).

## Test Plan

### Automated Tests (TDD RED)

RED: `server/test/orders.test.ts` wird zuerst geschrieben. Ohne `server/src/orders.ts` schlägt der Import fehl; als erster Test läuft AC-1 (Beleg für `ON CONFLICT` auf der generierten Spalte), bevor die übrigen Funktionen gebaut werden.
Der Test liest die Beispiele zur Laufzeit aus dem Vertrag (Muster aus `schema.test.ts` und `transcripts.test.ts`) und nutzt `freshPool(t)` mit `migrate` auf dem echten Migrationsordner; für zwei Verbindungen baut der Test den zweiten Pool selbst über `SELECT current_schema()` des ersten und `options: -c search_path=…` (Muster aus `transcripts.test.ts`); `server/test/db.ts` bleibt unverändert.

- [ ] Test 1 (AC-1): GIVEN das Auftragsbeispiel (Block 2) WHEN `putOrder` THEN `"stored"`, `id` und `kind` der Zeile stimmen.
- [ ] Test 2 (AC-2): GIVEN formgültige Aufträge und Ergebnisse (alle sechs Statuswerte, leerer `text`, kleine Fälle) WHEN `checkOrder`/`checkResult` THEN werfen nicht.
- [ ] Tests zu AC-3 bis AC-11 (Nummerierung entfällt hier; zehn `t.test`, einer je Tabellenzeile Z1 bis Z10, AC-4 deckt Z2 und Z3; die übrigen Einträge tragen die Nummer ihres AC): GIVEN das Beispiel der Art WHEN je Tabellenzeile geändert und `putOrder` bzw. `putResult` aufgerufen wird THEN wirft es mit Meldung, die Gegenstand und Feldpfad enthält, und `orders`/`order_results` ist leer.
- [ ] Test 12 (AC-12): GIVEN eine Abschrift ohne `version` und eine geschlossene Verbindung WHEN `checkTranscript`/`putOrder` THEN unveränderte Abschrift-Meldung bzw. Fehler ohne Präfix „… ungültig“; `transcripts.test.ts` unverändert grün.
- [ ] Test 13 (AC-13): GIVEN ein leeres Konto WHEN `putOrder` THEN `"stored"` und die Zeile steht da, ohne Gerät und ohne Vergabezeit.
- [ ] Test 14 (AC-14): GIVEN eine Zeile WHEN derselbe Auftrag (auch großgeschriebene UUID, anderer Inhalt) kommt THEN `"duplicate"`, Zeile unverändert.
- [ ] Test 15 (AC-15): GIVEN ein vergebener Auftrag WHEN er nochmals angelegt wird THEN `"duplicate"`, `claimed_by`/`claimed_at` unverändert, kein weiterer Abruf liefert ihn.
- [ ] Test 16 (AC-16): GIVEN drei Aufträge WHEN dreimal `claimOrder` THEN der Reihe nach, danach `undefined`; leeres Konto `undefined`.
- [ ] Test 17 (AC-17): GIVEN zehn Aufträge und zwei Verbindungen WHEN beide gleichzeitig `claimOrder` rufen (`Promise.all`) THEN jeder Auftrag genau einmal an genau ein Gerät, keine Doppelten.
- [ ] Test 18 (AC-18): GIVEN zwei Konten THEN `claimOrder` kreuzt nie.
- [ ] Test 19 (AC-19): GIVEN ein vom Gerät gehaltener Auftrag WHEN `putResult` THEN `"stored"`, Zeile mit `reported_by`; das belegt zugleich `ON CONFLICT (order_id)` auf der generierten Spalte von `order_results`.
- [ ] Test 20 (AC-20): GIVEN fremdes Gerät, nicht vergeben, fremdes Konto, unbekannte `orderID` WHEN `putResult` THEN je `"refused"`, `order_results` leer.
- [ ] Test 21 (AC-21): GIVEN ein Ergebnis WHEN ein zweites mit anderem Inhalt kommt THEN `"duplicate"`, Zeile unverändert.
- [ ] Test 22 (AC-22): Diff-Durchsicht des Vertrags; `schema.test.ts` liest weiter genau drei Blöcke.
- [ ] Test 23 (AC-23): Diff-Durchsicht: `server/migrations/`, `project.yml`, Swift-Dateien, `CLAUDE.md` unberührt; die Tests von C1b und C3a grün.
- [ ] Test 24 (AC-24): `./server/scripts/test-local.sh` grün; Workflow `server.yml` grün auf dem PR.

Läufe: `./server/scripts/test-local.sh` (Gesamtkette des Servers), danach der Workflow `server.yml` auf dem PR.

**Keine UI-Tests:** Der Schnitt ändert keine Oberfläche und keinen sichtbaren Ablauf; nichts in der App ruft den Dienst auf.

## Alternativen

- **A, Vergabe ohne `SKIP LOCKED`** (`UPDATE … WHERE claimed_by IS NULL` mit Unterabfrage ohne Sperrüberspringen): für einen einzigen Nutzer fast ausreichend, es ist dieselbe eine Anweisung. Nachteil: Greifen zwei Geräte gleichzeitig zu, wartet das zweite auf die Sperre
  und bekommt nach ihrem Ende `undefined`, obwohl weitere Aufträge frei sind (Leerlauf bis zum nächsten Abruf). `SKIP LOCKED` kostet nichts. Beibehalten; gekippt würde keine ADR, nur die Festlegung dieser Analyse, dass die Vergabe im Dienst liegt.
- **B, ganz ohne Vergabe:** jedes Gerät holt alle offenen Aufträge, die App erkennt Doppelte an der Auftragskennung. Das kippt die Spalten `claimed_by`/`claimed_at` aus Schema 001 und verlegt die Last in die App (C5), die noch keine Doppelerkennung hat.
  Verworfen: der Dienst ist die einzige Stelle, die „genau einmal“ heute garantieren kann. Eine Änderung des Schemas wäre eine neue, nur ergänzende Migration (kein Umschreiben von 001), falls C5 anders entscheidet; gekippt würde die Festlegung aus C1b zur Vergabe im Dienst (keine ADR).
- **C, nur ein Gerät führt Aufträge aus** (zum Beispiel das iPhone): keine Vergabe nötig. Nachteil: ein ausgeschaltetes iPhone staut alles. Verworfen; gekippt würde die Annahme „jedes Gerät mit der App kann ausführen“ aus Weg B (#612, keine ADR).
- **Ergebnis bei fremdem Auftrag als Fehler werfen** statt `"refused"`: eindeutiger für den Aufrufer, aber ein Formfehler und ein Zugriffsfehler wären nicht mehr zu trennen, und `putTranscript` liefert Werte. Verworfen.
- **`complete` mit `expectedStatus` `done`/`removed` schon beim Annehmen abweisen:** früher und mit Feldnamen, aber der Vertrag legt `invalid` ausdrücklich in die App; der Dienst würde Bedeutung prüfen. Verworfen; gekippt würde die Zeile „Der Dienst rechnet nichts nach“ im Vertrag (keine ADR).
- **Strenge Reihenfolge der Vergabe zusagen** (Warteschlange mit Sequenz): `SKIP LOCKED` garantiert sie nicht, und ein Auftragsstau ist kein Fehler. Verworfen: nur „genau einmal“ wird zugesagt.
- **Formprüfung des Auftrags als SQL-CHECK** (jsonpath je Art): schwer lesbar, Fehler als SQLSTATE ohne Feldnamen; gilt hier wie in C3a. Verworfen.

## Nicht in diesem Schnitt / Folgeschnitte

- Rückholung eines geholten Auftrags nach Absturz des Geräts (braucht Doppelerkennung über die Auftragskennung in der App, C5, und die Rückholregel, C7); Aufräumen alter Aufträge und Ergebnisse (C7); Advisory-Lock für `migrate` und `client.on("error")` (C7).
- Lesen der Ergebnisse durch Claude und Anlegen der Aufträge über Werkzeuge: C4 (MCP). Kein HTTP, keine Anmeldung, kein Konto (C6).
- C5 A/B-Nachweis (die App holt Aufträge und meldet Ergebnisse), C7 Betrieb auf Hetzner, C8 ADR-21.

## Abnahme

- Stufe 1: `./server/scripts/test-local.sh` grün (Typprüfung und alle Servertests gegen echtes Postgres); der Workflow `server.yml` grün auf dem PR.
- Stufe 2: Pflicht für den Abschluss. `./scripts/sim.sh test-proof CaptureSmokeTests` liefert den maschinellen Simulator-Beleg aus einem echten Lauf auf dem aktuellen Stand (Commit-Kennung und Zeitstempel passen), nie von Hand gesetzt.
  Der Beleg belegt, dass die App auf dem Stand startet und erfasst; ein Bedienablauf für Aufträge existiert noch nicht, weil nichts in der App Aufträge holt.
- Stufe 3: entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-24 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, Workflow `server.yml` grün
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #613 kommentiert (Stand C3b, Folgeschnitte C4 bis C8), Board-Karte aktuell

## Changelog

- 2026-11-01: Initial spec created (Schnitt C3b)
