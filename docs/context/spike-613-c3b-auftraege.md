# Context: spike-613-c3b-auftraege (#613, Schnitt C3b)

## Request Summary
Der zweite Teil des Dienstkerns ohne Anmeldung: einen Auftrag von Claude annehmen (Formprüfung inkl. `version`, je `kind`),
ihn genau einem Gerät vergeben (`FOR UPDATE SKIP LOCKED`) und das Ergebnis annehmen, aber nur für einen Auftrag, den dieses Gerät
hält. Kein MCP (C4), keine Anmeldung (C6), kein Betrieb (C7). Der Plan stammt aus der Spec C3a (`docs/specs/spike-613-schnitt-c3a-abschrift-annehmen.md`, Abschnitt Folgeschnitt).

## Stand nach C3a (gemergt, PR #791)
- `server/src/transcripts.ts` hat die Formprüfung als Bausteine (`shape`, `id`, `text`, `flag`, `time`, `list`, `fail`), alle bisher **nicht exportiert**; `checkTranscript` und `putTranscript(pool, account, doc)` sind exportiert.
- `putTranscript`: eine Anweisung `INSERT … ON CONFLICT (account_id) DO UPDATE … WHERE transcripts.generated_at < excluded.generated_at RETURNING`, Rückgabe `"stored" | "older"`. Das ist das Muster für `putOrder`/`putResult`.
- Fehlermeldungen deutsch, Präfix `Abschrift ungültig: <Pfad>: <Grund>`; Kommentare englisch, knapp.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/transcripts.ts` | Formbausteine; für C3b nur `export` davor setzen (kein Verschieben, damit der Diff klein bleibt) |
| `server/migrations/001_claude_schema.sql` | `orders` (`id`/`kind` generiert aus `doc`, `claimed_by`/`claimed_at` beide oder keins), `order_results` (PK = FK auf `orders`, `reason` genau bei `rejected`, `reported_by`); darf bis C7 noch geändert werden |
| `server/test/db.ts`, `server/test/transcripts.test.ts` | `freshPool(t)`; Beispiel liest der Test aus dem Vertrag (Block 2 = Auftrag, Block 3 = Ergebnis); Tabellenstil: ein `t.test` je Abweichungszeile |
| `docs/reference/claude-abschrift-vertrag.md` | Absatz „Ebenso offen in Version 1“ (Auftrag ohne `version`) wird mit C3b erledigt und angepasst |
| `Shared/Services/OrderExecutor.swift` | Quelle der Form: `Order` (`version`, `id`, `kind`, `text?`, `taskID?`, `expectedStatus?`, `date?`, `hasTime?`, `expectedDueDate?`) und `OrderResult` (`orderID`, `outcome`, `reason?`, `taskID?`) |

## Form der Aufträge (aus Vertrag und `OrderExecutor`)
- Gemeinsam, Pflicht: `version` = 1, `id` (UUID), `kind` (`capture` | `complete` | `setDue`).
- `capture`: `text` (String, Pflicht); sonst nichts. Ein leerer Text ist laut Vertrag `invalid` und ein Ergebnis der App, nicht des Dienstes.
- `complete`: `taskID`, `expectedStatus` (Pflicht); `expectedDueDate` optional (fehlt = keine Fälligkeit erwartet).
- `setDue`: `taskID`, `hasTime` (Pflicht); `date` und `expectedDueDate` optional.
- Zeitpunkte wie in der Abschrift (`time`-Baustein). Kein Feld außerhalb der Liste der jeweiligen Art.

## Form des Ergebnisses
`orderID` (UUID), `outcome` (`done` | `rejected`), `reason` (`invalid` | `missing` | `stale`) genau bei `rejected`, `taskID` optional. Die Datenbank erzwingt `reason` genau bei `rejected` bereits; der Dienst prüft es vorher, damit die Meldung einen Feldnamen trägt.

## Vergabe und Ergebnis (Recherche aus C3a gilt)
- Eine Anweisung `UPDATE orders SET claimed_by = $2, claimed_at = now() WHERE id = (SELECT id FROM orders WHERE account_id = $1 AND claimed_by IS NULL ORDER BY created_at, id FOR UPDATE SKIP LOCKED LIMIT 1) RETURNING doc`. Ein gesperrter Auftrag wird übersprungen; ein zweites Gerät bekommt den nächsten oder nichts.
- SKIP LOCKED garantiert keine strenge Reihenfolge; ein abgestürztes Gerät hält seinen Auftrag, solange es keine Rückholregel gibt (C7, nicht C3b).
- Ergebnis: nur für einen Auftrag, der dem Konto gehört und von **diesem** Gerät gehalten wird; ein zweites Ergebnis zum selben Auftrag ändert nichts (PK).

## Existing Patterns
- TypeScript direkt unter Node 26, `node --test`, `assert/strict`, nur `pg`.
- Der Dienst rechnet nichts nach: er prüft Form und reicht weiter.
- `account_id` ist heute ein übergebener Text (C6 liefert ihn später); `device` entsprechend ein übergebener Text.

## Dependencies
- Upstream: Schema 001, Vertrag v1, Formbausteine aus C3a.
- Downstream: C4 (MCP legt Aufträge an, liest Ergebnisse), C5 (A/B-Nachweis App ↔ Dienst: die App holt Aufträge und meldet Ergebnisse), C6 (Konto), C7 (Rückholregel, Aufräumen).

## Risks & Considerations
- Gleichzeitige Vergabe ist nur mit echtem Postgres und zwei Verbindungen prüfbar (bewusst kein PGlite, C1a): Test mit `Promise.all` über zwei Verbindungen aus einem Pool, mehrere Aufträge, jeder geht genau einmal raus.
- Doppelt angelegter Auftrag (gleiche `id`) darf den bereits vergebenen nicht zurücksetzen: `ON CONFLICT (id) DO NOTHING`.
- UUIDs: die App führt Großbuchstaben, die Spalte `uuid` normalisiert; Vergleich in Tests gegen die kleingeschriebene Form.
- Umfang: Dienstcode ~90 Zeilen, Tests mit Faktor 1,5 ≈ 140, Exporte und Vertragsabsatz ≈ 10 → knapp 250. Vier Dateien (`orders.ts`, `orders.test.ts`, `transcripts.ts`, Vertrag). Eine Überschreitung wird bei der Spec-Freigabe genannt (Muster aus C1a, C1b, C3a).
- Kein Pfad der Geräteliste berührt (`server/`, `docs/`); Simulator-Beleg für phase8 trotzdem per `sim.sh test-proof` (CaptureSmokeTests), wie bei den Vorschnitten.

## Offene Punkte für die Analyse (/20-analyse)
1. `complete` mit `expectedStatus` `done`/`removed`: der Dienst weist beim Annehmen ab (früher, mit Feldnamen) oder reicht durch, und die App meldet `invalid`? Vorschlag: durchreichen, denn der Vertrag legt `invalid` ausdrücklich in die App; der Dienst prüft nur die Form.
2. Rückgabe von `putResult`, wenn der Auftrag nicht dem Gerät gehört: Fehler werfen oder Wert zurückgeben? Vorschlag: Wert (`"stored" | "duplicate" | "refused"`), wie `putTranscript`.
3. Alternative zur festen Reihenfolge der Vergabe: keine Reihenfolge zusagen (nur „genau einmal“). Vorschlag: `created_at, id` als Reihenfolge nutzen, aber im Vertrag nichts zusagen.

## Analysis

### Type
Feature (Dienstkern, zweiter Teil; kein Bug, daher keine Reproduktion). Regel- und Formprüfung plus SQL, kein Sprachmodell: der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/orders.ts` | CREATE | `checkOrder`, `checkResult`, `putOrder`, `claimOrder`, `putResult` |
| `server/test/orders.test.ts` | CREATE | Abweichungstabelle je `kind`, Vergabe über zwei Verbindungen, Ergebnis nur vom haltenden Gerät; Beispiele aus dem Vertrag (Block 2 und 3) |
| `server/src/transcripts.ts` | MODIFY | Bausteine `export`; `fail` wirft einen `FormError`, `reporting(subject, run)` setzt den Präfix („Abschrift“, „Auftrag“, „Ergebnis“ ungültig: …) |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Absatz „Ebenso offen in Version 1“ erledigt; Zusage zur Vergabe: genau einmal, keine Reihenfolge |

### Scope Assessment
- Files: 4
- Estimated LoC: ca. +240 / -5 (Dienst ~90, Tests ~140, Umbau transcripts ~10) → an der 250er-Grenze, Überschreitung wird bei der Spec-Freigabe genannt (Muster C1a, C1b, C3a)
- Risk Level: LOW (nur `server/` und `docs/`; keine App-Datei; Schema 001 bleibt)

### Technical Approach
- **Form (Auftrag):** gemeinsam `version` (=1), `id` (UUID), `kind`; je Art: `capture` → `text`; `complete` → `taskID`, `expectedStatus`, optional `expectedDueDate`; `setDue` → `taskID`, `hasTime`, optional `date`, `expectedDueDate`. Kein Schlüssel außerhalb der Liste der Art. Zeitpunkte mit dem vorhandenen `time`-Baustein.
- **Form (Ergebnis):** `orderID`, `outcome`, `reason` genau bei `rejected`, `taskID` optional.
- **putOrder:** `INSERT … ON CONFLICT (id) DO NOTHING` (ein doppelt angelegter Auftrag setzt einen vergebenen nie zurück); Rückgabe `"stored" | "duplicate"`.
- **claimOrder(pool, account, device):** eine Anweisung `UPDATE orders SET claimed_by, claimed_at = now() WHERE id = (SELECT id … WHERE account_id = $1 AND claimed_by IS NULL ORDER BY created_at, id FOR UPDATE SKIP LOCKED LIMIT 1) AND claimed_by IS NULL RETURNING doc`; Rückgabe der Auftrags-`doc` oder `undefined`.
- **putResult(pool, account, device, doc):** eine Anweisung `INSERT … SELECT … WHERE EXISTS (Auftrag des Kontos, gehalten von diesem Gerät) ON CONFLICT DO NOTHING`; bei 0 Zeilen eine Folgeabfrage, ob schon ein Ergebnis da ist → `"stored" | "duplicate" | "refused"`.

### Entscheidungen zu den offenen Punkten
1. `complete` mit `expectedStatus` `done`/`removed`: **durchreichen**. Der Dienst akzeptiert alle sechs Statuswerte der App (`TaskStatus`), `invalid` bleibt Ergebnis der App (Vertrag). Der Dienst prüft Form, keine Bedeutung.
2. `putResult` bei fremdem/ungehaltenem Auftrag: **Wert statt Fehler** (`"refused"`), wie `putTranscript`; Formfehler bleiben Fehler.
3. Reihenfolge: `created_at, id` nutzen, im Vertrag nur „genau einmal“ zusagen.

### Befunde, die gegen den Plan sprechen / Alternativen
- **Alternative A, ohne `SKIP LOCKED`:** Ein einfaches `UPDATE … WHERE claimed_by IS NULL` ohne Sperrüberspringen genügt für einen einzigen Nutzer fast: das zweite Gerät bekäme bei gleichzeitigem Abruf einmal „nichts“ und beim nächsten Abruf den nächsten. Es ist dieselbe eine Anweisung, `SKIP LOCKED` kostet nichts, vermeidet aber das Leerlaufen. Beibehalten.
- **Alternative B, ganz ohne Vergabe:** jedes Gerät holt alle offenen Aufträge, die App erkennt Doppelte an der Auftragskennung. Das kippt die Spalten `claimed_by`/`claimed_at` aus Schema 001 und verlegt die Last in die App (C5). Verworfen: die App hat noch keine Doppelerkennung, der Dienst ist die einzige Stelle, die schon heute „genau einmal“ garantieren kann. Schema darf bis C7 geändert werden, falls C5 anders entscheidet.
- **Alternative C, nur ein Gerät führt Aufträge aus** (z. B. das iPhone): keine Vergabe nötig, aber ein ausgeschaltetes iPhone staut alles. Verworfen.
- **Risiko 1:** `ON CONFLICT` auf generierter Primärspalte (`id`, `order_id`) ist in Postgres erlaubt (eindeutiger Index), wird aber im ersten RED-Test belegt, bevor darauf gebaut wird.
- **Risiko 2:** Ein Gerät, das abstürzt, hält seinen Auftrag für immer (Rückholregel gehört in C7, hier nicht).
- **Risiko 3:** Der Präfix der Meldung ist heute fest „Abschrift ungültig“; ohne den `FormError`-Umbau würden Auftragsfehler falsch benannt.
- Weiteres gegen den Plan: keine.

### Dependencies
Upstream: Schema 001, Vertrag v1, Bausteine aus C3a. Downstream: C4 (MCP), C5 (App holt Aufträge), C6 (Konto), C7 (Rückholregel).

### Open Questions
- [ ] Keine Produktfrage offen; die Umfangsüberschreitung (knapp 250) wird bei der Spec genannt.
