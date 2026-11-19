# Context: feat-938-s2-dienst

## Request Summary
#938 Schnitt 2: Der Dienst nimmt `fields.repeat` (an `capture_task` und `update_task`) und `fields.link` (nur an
`capture_task`) an, prüft ihre Form und reicht sie als Auftrag an die App weiter, die sie seit Schnitt 1 (PR #949) ausführt.
Gesamtanalyse und PO-Entscheidungen: `docs/context/feat-938-wiederholung-claude.md`; App-Seite: `docs/specs/feat-938-schnitt-1-app.md`.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/orders.ts:20-23,49-66` | `Fields`-Typ, `fieldsCheck(withNotes)`, `captureFields`, `updateFields`; hier kommen `repeat` (beide) und `link` (nur capture) dazu |
| `server/src/transcripts.ts:53-142` | Prüfbausteine `shape`, `text`, `flag`, `time`, `names`, `fail` (exportiert) |
| `server/src/mcp.ts:77-87,190-207,300-369` | `capturing`/`updating` reichen `fields` unverändert durch; zod `captureFieldsSchema` (strict, partial), `updateFieldsSchema` = ohne `notes`; Werkzeugbeschreibungen nennen die Felder in Prosa |
| `server/src/anleitung.ts` | Anleitung (≤ 2048 Bytes, Test `mcp-anleitung`); evtl. ein Satz zur Wiederholung |
| `docs/reference/claude-abschrift-vertrag.md:122-133,214-235` | Form von `repeat`/`link` (Schlüssel, Wertemengen, 1…52, weekdays 1…7 nur weekly, basis), Satz „Dienst nimmt ab S2 an“; jsonc-Beispiel `capture` mit `repeat`+`link` |
| `server/test/orders.test.ts:300-360` | liest die jsonc-Blöcke des Vertrags (`find` nimmt das erste capture-Beispiel; das #938-Beispiel ist das zweite) |
| `server/test/mcp-write.test.ts` | Werkzeugtests capture/update mit `fields` (zod strict) |

## Existing Patterns
- #932 S2/S3: Form im Dienst (zod strict + `fieldsCheck`), Bedeutung (Kataloge, Zustand) in der App; `fields` geht nur mit, wenn gegeben.
- Vertrags-Beispiele werden in Tests aus dem Dokument gelesen, nie kopiert.
- `update` sendet als erwarteten Stand nur Werte aus der Abschrift; `repeat` steht nicht darin → nur `expectedStatus` (keine Änderung in `updating` nötig).

## Dependencies
- Upstream: `transcripts.ts`-Prüfbausteine, zod, MCP-SDK.
- Downstream: App `OrderExecutor` (S1, gemergt, TestFlight-Bau 2026-11-19 18:08 enthält ihn), Dienst-Rollout auf rennwienix (`scripts/deploy-loose-ends.sh` in henemm-infra), S3 Übertragung „Family“.

## Existing Specs
- `docs/specs/feat-932-schnitt-2-dienst.md`, `docs/specs/feat-932-schnitt-3-update.md` — Vorlage für Dienstschnitte.
- `docs/specs/feat-938-schnitt-1-app.md` — Gegenstelle.

## Risks & Considerations
- **Reihenfolge:** Rollout erst, wenn der TestFlight-Bau mit S1 auf Hennings Geräten läuft (alte App verwirft `repeat` still). Bau existiert seit 2026-11-19; ob er installiert ist, sieht nur Henning (TestFlight aktualisiert in der Regel automatisch) → vor dem Rollout klären, ohne Gerätezugriff.
- Form im Dienst muss deckungsgleich mit der App-Prüfung sein (interval 1…52 ganzzahlig, weekdays nicht leer und nur bei weekly, je 1…7; link http/https mit Host), sonst lehnt die App ab, was der Dienst durchließ (dann nur `invalid`, kein Schaden).
- zod `strict` auch im verschachtelten `repeat`-Objekt, damit Tippfehler abgewiesen werden.
- Anleitung bleibt ≤ 2048 Bytes.
- Abweichung „2. Samstag im Februar“ → jährlich zum Datum, Claude nennt sie (PO 2026-11-17) — gehört in Werkzeugbeschreibung oder Anleitung.

## Analysis

### Type
Feature (Dienstseite zu #938 Schnitt 1, der in der App seit PR #949 läuft)

### Befund (Code gelesen, 2026-11-19)
- Heute weist der Dienst `fields.repeat` und `fields.link` an zwei Stellen ab: zod `captureFieldsSchema` ist `.strict()`
  (`server/src/mcp.ts`), und `fieldsCheck` (`server/src/orders.ts`) kennt beide Schlüssel nicht (`shape` → „unbekannter Schlüssel“).
- Die App prüft (`Shared/Services/OrderExecutor.swift:156-172`): `frequency` ∈ daily/weekly/monthly/yearly, `basis` ∈
  fromDueDate/fromCompletion, `interval` 1…52, `weekdays` nur bei weekly, nicht leer, je 1…7; `link` per `URL(string:)`,
  Schema http/https, Host nicht leer; `link` bei `update` → invalid. Der Dienst übernimmt genau diese Form, nichts darüber hinaus.
- `updating` braucht keine Änderung: für `repeat` gilt nur `expectedStatus` (Vertrag), und der wird immer gesendet.
- Der Vertrag enthält das #938-Beispiel schon (drittes ```jsonc-Block, zweites `capture`); `captureExample()` in
  `server/test/orders.test.ts` nimmt das erste `capture` — ein neuer Test muss das Beispiel mit `repeat` gezielt finden.
- Anleitung: Quelltext 1463 Bytes, Platz ist da; der Hinweis zur Abweichung „n-ter Wochentag“ gehört aber besser in die
  Werkzeugbeschreibung von `capture_task`/`update_task`, wo Claude ihn beim Aufruf liest.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/orders.ts` | MODIFY | `Fields` um `repeat`/`link`; Prüfbausteine `repeat` (shape mit Pflicht `frequency`, optional `interval`, `weekdays`, `basis`; weekdays nur bei weekly) und `link` (text + `URL.parse`, http/https, Host); `fieldsCheck(withNotes)` → `link` nur bei capture (wie `notes`) |
| `server/src/mcp.ts` | MODIFY | zod `repeatSchema` (strict, `frequency` Pflicht), `link` als `z.string()`; `updateFieldsSchema` lässt `notes` und `link` weg; Beschreibungen beider Werkzeuge nennen Wiederholung, Link und: „jedes Jahr am n-ten Wochentag“ gibt es nicht → jährlich zum Datum, dem Nutzer die Abweichung nennen |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Satz „Der Dienst nimmt … ab Schnitt 2 an; bis dahin weist er sie … ab“ → Gegenwart |
| `server/test/orders.test.ts` | MODIFY | Gute Formen (Vertragsbeispiel mit repeat+link, Mindestform, je Häufigkeit), Fehlertabelle mit Pfaden (`fields.repeat.interval` 0/53/1.5, unbekannte frequency/basis, weekdays leer/0/8/bei monthly, fremder Schlüssel in repeat, link ftp/ohne Host/kein Text, link an update) |
| `server/test/mcp-write.test.ts` | MODIFY | capture_task/update_task reichen repeat (und link nur bei capture) unverändert durch; update_task mit link und repeat-Tippfehler → isError, kein Auftrag |

### Scope Assessment
- Files: 5
- Estimated LoC: +130/−8 (davon ~80 Tests)
- Risk Level: LOW — nur zusätzliche erlaubte Schlüssel; alles Bisherige bleibt gleich. Einziges Betriebsrisiko ist die
  Reihenfolge beim Ausrollen (unten).

### Technical Approach
Muster #932 S2/S3: Form im Dienst doppelt (zod strict für Claude, `checkOrder` für jeden Auftrag), Bedeutung in der App.
Prüfung deckungsgleich mit `OrderExecutor.isWellFormed`; weicht `URL.parse` (WHATWG) in Randfällen von Swifts `URL(string:)`
ab, lehnt die App mit `invalid` ab — kein Schaden, keine Aufgabe ohne Wissen. Dienst sortiert/entdoppelt `weekdays` nicht (macht die App).

### Alternativen
- Eigenes Werkzeug `set_repeat` (wie `set_due`): verworfen in der Gesamtanalyse (`feat-938-wiederholung-claude.md`) — zwei
  Aufträge je Aufgabe, Anker zwischen beiden falsch.
- Nur zod prüfen, `checkOrder` unverändert lassen: geht nicht, `checkOrder` weist jeden fremden Schlüssel ab (C3b); und die
  zweite Prüfung schützt die App-Route vor Aufträgen, die nicht aus zod kommen.
- Wiederholung „n-ter Wochentag“ im Modell (S1b) bleibt verworfen (PO 2026-11-17).

### Dependencies
- Upstream: `transcripts.ts` (`shape`, `text`, `fail`, `list`), zod, MCP-SDK. Downstream: App-`OrderExecutor` (S1).
- Rollout auf rennwienix (`henemm-infra`, `scripts/deploy-loose-ends.sh`, `LE_COMMIT`) erst, wenn die App mit S1 auf Hennings
  Geräten läuft: eine ältere App dekodiert `repeat`/`link` nicht (Swift `Codable` ignoriert fremde Schlüssel), legt die Aufgabe
  ohne Wiederholung an und meldet `done` — still falsch. Gehört in Phase 7 (Deploy), nicht in die Spec-Freigabe.

### Open Questions
- [ ] (Phase 7, nicht jetzt) Läuft bei Henning der TestFlight-Bau vom 2026-11-19 (mit S1)? Wird vor dem Rollout gefragt, ohne Gerätezugriff.
