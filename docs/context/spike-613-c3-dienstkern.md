# Context: spike-613-c3-dienstkern (#613, Schnitt C3)

## Request Summary
Der Dienstkern ohne Anmeldung: Abschrift annehmen (mit Formprüfung, nur bei neuerem `generatedAt` überschreiben), Aufträge
annehmen (Formprüfung inkl. `version`), einen Auftrag genau einem Gerät vergeben (`FOR UPDATE SKIP LOCKED`), Ergebnis annehmen.
Dazu die offenen Pflichtpunkte aus C2 und C1b. Kein MCP (C4), keine Anmeldung (C6), kein Betrieb (C7).

## Pflichtpunkte aus früheren Schnitten (werden ACs)
- **F005 / verschachtelter `rawText`** (C1b): `now` muss ein Objekt mit genau `knaeuel` (UUID, optional), `today`, `lined`,
  `waiting` (Listen von UUIDs) sein; `contexts` Liste von Strings; `title`, `project` Strings. Sonst Ablehnung beim Annehmen.
- **`version` beim Annehmen** (C2): Auftrag ohne/anderer `version` → abgewiesen, bevor er in `orders` landet.
- **`setDue` prüft den Status nicht** (C2): `OrderExecutor.setDue` setzt die Fälligkeit auch an einer erledigten/gelöschten
  Aufgabe. Vorgesehen: `stale`. Swift-Änderung in `Shared/Services/OrderExecutor.swift:75` + Test in
  `LooseEndsTests/OrderExecutorTests.swift`; Vertragsabsatz „Ebenso offen in Version 1“ anpassen.
- **Testaufbau** (C1b): ein `t.test` je Zeile der Abweichungstabellen.
- Vorgemerkt, nicht C3: Advisory-Lock für `migrate`, `client.on("error")`/Pool-Listener (C7).

## Related Files
| File | Relevance |
|------|-----------|
| `server/migrations/001_claude_schema.sql` | Tabellen `transcripts` (PK `account_id`), `orders` (`claimed_by`/`claimed_at`), `order_results` (PK = FK auf `orders`); darf bis C7 noch geändert werden |
| `server/src/migrate.ts` | Muster: eine Transaktion je Schritt, `client.release(broken)` bei kaputtem ROLLBACK |
| `server/test/db.ts` | `freshPool(t)`: eigenes Schema je Test, `DATABASE_URL` Pflicht |
| `server/test/schema.test.ts` | liest die drei JSON-Beispiele aus dem Vertrag; `refused(...)`-Helfer mit SQLSTATE |
| `server/scripts/test-local.sh`, `.github/workflows/server.yml` | Testkette (Wegwerf-Postgres 18 lokal, `postgres:18` in der CI) |
| `docs/reference/claude-abschrift-vertrag.md` | Vertrag v1: Abschrift, Auftrag, Ergebnis; Abschnitt „Ebenso offen in Version 1“ |
| `Shared/Services/OrderExecutor.swift` | App-Ausführer; `setDue` ohne Statusprüfung (:75–:88) |
| `Shared/Services/TranscriptCodec.swift` | erzeugt die Abschrift (Quelle der Form, die der Dienst prüft) |
| `LooseEndsTests/OrderExecutorTests.swift` | Tests des Ausführers |

## Existing Patterns
- TypeScript direkt unter Node 26 (Type Stripping, kein Build), `node --test`, `assert/strict`, nur Abhängigkeit `pg`.
- Fehler deutsch im Text (`throw new Error("…")`), Kommentare englisch, knapp.
- Der Dienst rechnet nichts nach (Vertrag): er prüft Form und reicht weiter.
- Die jsonb-Spalte ist die eine Quelle; abgeleitete Spalten werden generiert.

## Dependencies
- Upstream: Postgres 18, `pg` 8.23.1, Schema 001, Vertrag v1.
- Downstream: C4 MCP (liest Abschrift, legt Aufträge an, liest Ergebnisse), C5 A/B-Nachweis (App ↔ Dienst), C6 Anmeldung
  (liefert später `account_id`, heute ein übergebener Wert), C7 Betrieb.

## Existing Specs
- `docs/specs/spike-613-schnitt-1-abschrift-auftraege.md` (C2), `…-c1a-server-geruest.md`, `…-c1b-schema.md` (Folgeschnitte: C3 =
  Annehmen mit Formprüfung, Vergabe, Überschreiben bei neuerem `generatedAt`, `setDue`-Status).

## Offene Entscheidungen für die Analyse
- HTTP schon in C3 (eingebautes `node:http`, keine neue Abhängigkeit) oder nur Dienstfunktionen über `pg`, HTTP mit C4/C6?
- Formprüfung: handgeschrieben in TS oder Bibliothek (neue Abhängigkeit braucht Freigabe)?
- Schnittgrenze: 250-LoC-Limit → voraussichtlich C3a (Abschrift + Swift `setDue`) und C3b (Aufträge, Vergabe, Ergebnis).

## Risks & Considerations
- Vergabe an genau ein Gerät nur mit echtem Postgres und zwei Verbindungen prüfbar (bewusst kein PGlite, C1a).
- Überschreiben nur bei neuerem `generatedAt`: gleichzeitige Uploads → `INSERT … ON CONFLICT DO UPDATE … WHERE` atomar.
- Swift-Änderung berührt `Shared/Services/` — kein Pfad der Geräteliste; Simulator-Beleg (`test-proof`) bleibt Pflicht für phase8.
- LoC: C3 war mit ~240 geschätzt, plus Formprüfung und Tests je Zeile → Teilung nötig.

## Analysis

### Type
Feature (Spike #613, Weg B, Schnitt C3). Geteilt in **C3a** (dieser Workflow) und **C3b** (Folgeworkflow), weil das Ganze
mit Formprüfung und einem Test je Abweichungszeile über 250 LoC liegt (Schätzung gesamt ~470).

### Recherche (2026-11-01)
- Vergabe an genau ein Gerät: das übliche Muster ist eine einzige Anweisung `UPDATE … WHERE id = (SELECT id … FOR UPDATE
  SKIP LOCKED LIMIT 1) RETURNING …`; ein gesperrter Auftrag wird übersprungen statt erwartet. SKIP LOCKED garantiert keine
  strenge Reihenfolge, und ein abgestürztes Gerät hält seinen Auftrag, solange es keine Rückholregel gibt.
  Quellen: hackernoon.com/skip-locked-vs-redis-when-should-you-use-a-database-queue,
  vincentschmalbach.com/building-a-queue-with-postgresql-skip-locked/, dev.to/romiteld/the-queue-was-a-table-…
- Nur neuere Abschrift überschreibt: `INSERT … ON CONFLICT (account_id) DO UPDATE … WHERE transcripts.generated_at <
  excluded.generated_at` ist atomar; ist die Bedingung falsch, wird still nichts geändert und `RETURNING` liefert keine Zeile
  — daran erkennt der Dienst „veraltet, verworfen“. Quellen: docs.turso.tech/sql-reference/statements/upsert.md,
  elixirforum.com/t/ecto-upsert-insert-all-only-update-on-conflict-if-an-item-datetime-is-newer-than-db-record-datetime/51210

### Schnitt C3a — Abschrift annehmen + `setDue` prüft den Status
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/transcripts.ts` | CREATE | `checkTranscript(doc)` (Formprüfung, wirft deutsche Fehlermeldung) und `putTranscript(pool, account, doc)` → `"stored"` / `"older"` per Upsert mit `WHERE … <` |
| `server/test/transcripts.test.ts` | CREATE | Vertragsbeispiel wird angenommen; ein `t.test` je Abweichungszeile (F005: `now` kein Objekt, fremder/fehlender Schlüssel in `now`, `knaeuel` keine UUID, `today`/`lined`/`waiting` keine UUID-Liste, `contexts` keine String-Liste, `title`/`project` kein String, falsche `version`, …); ältere und gleich alte Abschrift ändern nichts; zwei gleichzeitige Uploads → die neuere bleibt |
| `Shared/Services/OrderExecutor.swift` | MODIFY | `setDue`: Aufgabe nicht in `completable` (erledigt/gelöscht) → `stale`, nichts geändert (~+2 Zeilen) |
| `LooseEndsTests/OrderExecutorTests.swift` | MODIFY | erledigte und gelöschte Aufgabe mit unveränderter Fälligkeit → `stale`, keine Revision |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | „Ebenso offen in Version 1“: `setDue`-Punkt wird Regel (Status zählt zum erwarteten Stand); Satz zur Annahme der Abschrift (Form, nur neuere überschreibt) |

Schätzung C3a: ~+230/-5 LoC, 5 Dateien. Risiko: **niedrig** — neuer, noch ungenutzter Dienstteil; die Swift-Änderung
verschärft nur eine Ablehnung, kein Pfad der Geräteliste (Stufe 2 mit `test-proof` bleibt Pflicht).

### Schnitt C3b — Aufträge, Vergabe, Ergebnis (Folgeworkflow)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/orders.ts` | CREATE | `checkOrder` (inkl. `version` = 1, Felder je `kind`), `putOrder`, `claimOrder(pool, account, device)` per `FOR UPDATE SKIP LOCKED`, `putResult(pool, account, device, doc)` nur für einen Auftrag, den dieses Gerät hält |
| `server/test/orders.test.ts` | CREATE | ein `t.test` je Abweichungszeile; zwei Verbindungen holen gleichzeitig → jeder Auftrag genau einmal; zweites Ergebnis abgewiesen |
| `CLAUDE.md` | MODIFY | Zeile `server/` um Dienstkern ergänzen |

Schätzung C3b: ~+230 LoC, 3 Dateien.

### Technical Approach (Empfehlung)
- **Kein HTTP in C3.** Der Kern sind Funktionen über `pg`, getestet gegen echtes Postgres. Den Transport legt C4 (MCP für
  Claude) bzw. die Anmeldung C6 (Endpunkte der App) fest; ein HTTP-Gerüst jetzt würde ohne Anmeldung gebaut und später
  umgebaut. `account_id` und Gerätename sind heute übergebene Werte.
- **Formprüfung handgeschrieben in TS**, keine neue Abhängigkeit. Der Vertrag hat wenige, flache Felder; eine Bibliothek
  (zod/ajv) bräuchte Freigabe und brächte nur Schreibkomfort.
- **Die Datenbank bleibt die zweite Wand:** die vorhandenen CHECKs (Version, Datenschutzlinie, `generatedAt` mit Zone)
  bleiben unverändert; die TS-Prüfung liefert vorher die verständliche Fehlermeldung.
- **Der Dienst rechnet nichts nach** (Vertrag): keine Prüfung, ob `now`-Kennungen in `tasks` stehen oder `nowCount` stimmt.
- `setDue`: dieselbe Menge `completable` wie bei `complete`; ein erledigter/gelöschter Stand ist `stale` (Claude liest neu).

### Alternativen
1. **Formprüfung als SQL-CHECK in Migration 001** (jsonpath je Feld, 001 darf bis C7 noch geändert werden). Vorteil: eine
   Wand für jeden Weg in die Tabelle. Nachteil: verschachtelte jsonpath-Ausdrücke für `now` und Feldtypen sind schwer lesbar,
   und der Fehler kommt als SQLSTATE ohne Feldnamen. Kippt keine ADR. Nicht empfohlen, aber ein Teil davon (z. B. `now` ist ein
   Objekt) wäre billig zusätzlich.
2. **HTTP schon in C3** mit `node:http` (keine Abhängigkeit). Vorteil: früher von außen ansprechbar. Nachteil: ohne Anmeldung
   ein offener Endpunkt, und die Form hängt an C4/C6. Nicht empfohlen.
3. **Kein Dienst-Kern, MCP direkt auf die Tabellen** (C4 schreibt SQL selbst). Spart eine Schicht, verteilt aber Prüfung und
   Vergabe auf MCP und App-Endpunkte doppelt. Nicht empfohlen.

### Dependencies
- Upstream: Schema 001 (unverändert), Vertrag v1, `freshPool`, Muster aus `schema.test.ts`.
- Downstream: C3b nutzt dieselbe Prüfmuster-Hilfe; C4 ruft `putTranscript`-Gegenstück zum Lesen und `putOrder` auf.

### Bewusst nicht in C3 (notiert für C7 bzw. C5)
- **Rückholung eines geholten Auftrags**, wenn ein Gerät abstürzt, bevor es ein Ergebnis meldet. `complete`/`setDue` wären
  dank erwartetem Stand gefahrlos erneut ausführbar, `capture` nicht (doppelte Erfassung) — braucht vorher eine
  Doppelerkennung über die Auftragskennung in der App (C5). Bis dahin bleibt ein geholter Auftrag geholt.
- Advisory-Lock für `migrate`, `client.on("error")` (C7).

### Open Questions
- keine für Henning (alles technisch; Entscheidungen oben).
