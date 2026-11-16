# Context: feat-932-s3-update (#932 Schnitt 3)

## Request Summary
Der Dienst bekommt das Werkzeug `update_task`: Claude ändert Titel, Fälligkeit, Wichtigkeit, Dringlichkeit, Dauer, Energie,
Tags und Projekt einer bestehenden Aufgabe. Der Auftrag `update` (Vertrag, App seit Schnitt 1) wird vom Dienst angenommen,
der erwartete Stand kommt aus der Abschrift; die Anleitung sagt, dass Claude erst nach dem Ja des Nutzers ändert.

## Stand vor diesem Schnitt
- S1 (PR #934): App versteht `update` und `fields` (`OrderExecutor`), Vertrag beschreibt beides samt ```jsonc-Beispiel `update`.
- S2 (PR #935): Dienst nimmt `fields` an `capture` an (`fieldsCheck(withNotes)`, `captureFieldsSchema` in `mcp.ts`).
- Der Dienst verwirft `update` heute zweimal: `forms` in `orders.ts` kennt die Art nicht, und der CHECK `orders_kind_known`
  (Migration 007) lässt sie nicht in die Tabelle.

## Related Files
| File | Relevance |
|------|-----------|
| `server/migrations/009_order_update.sql` (neu) | CHECK `orders_kind_known` um `update` erweitern (Muster 007) |
| `server/src/orders.ts` | `Order`-Union + `forms.update`: Pflicht `taskID`, `expectedStatus`, `fields` (`fieldsCheck(false)`, nicht leer); optional `expectedTitle`, `expectedDueDate`, `expectedContexts`, `expectedProject` |
| `server/src/mcp.ts` | Werkzeug `update_task` (`taskID`, `generatedAt`, `fields`), Handler `updating`; `expected()` liefert heute Status, Datum, Rang — braucht Titel, Tags, Projekt aus der Abschriftzeile |
| `server/src/anleitung.ts` | Satz: Titel/Angaben ändern erst nach dem Ja; ohne Felder Text so, wie der Nutzer spricht (Kommentar #932). 964 von 2048 Byte |
| `docs/reference/claude-abschrift-vertrag.md` | „`update` erst ab Schnitt 3“ → angenommen; Kopfsatz „prüft der Server ab Schnitt 3“ |
| `CLAUDE.md` | `mcp.ts`-Zeile: `update_task`, Migration 009 |
| Tests: `server/test/orders.test.ts`, `mcp-write.test.ts`, `accounts.test.ts`/`schema.test.ts` (Liste der Migrationen) | |

## Existing Patterns
- Schreibwerkzeuge: `expected(pool, ctx, taskID, generatedAt)` → `Target` oder Ablehnungstext; `storeOrder` prüft mit `checkOrder`
  und weckt die Geräte. Ein Werkzeug je Handler (`completing`, `lining`, `parking`, `subtasking`, `setting`).
- Migration 007: alten CHECK per `DO $$` finden und ersetzen; der Runner hüllt in eine Transaktion.
- Strenges zod-Schema für `fields` (`captureFieldsSchema`, `.strict()`), `checkOrder` bleibt die eigentliche Prüfung.
- Vertragsbeispiel aus dem ```jsonc-Block lesen, nie kopieren (`captureExample()` in `orders.test.ts`).

## Dependencies
- Upstream: `getTranscript` (`transcripts.ts`, Zeile mit `title`, `contexts`, optional `project`, `dueDate`, `status`), `shape`/Checks aus `transcripts.ts`.
- Downstream: App `OrderExecutor.update` (S1) liest `expectedTitle`, `expectedContexts`, `expectedProject`, `expectedDueDate`, `expectedStatus`.
  Konvention: fehlt der erwartete Wert, hatte die Aufgabe keinen.

## Kurzanalyse (Summe 2, Kontext und Analyse in einem Durchgang)
- **Erwarteter Stand nur für geänderte Felder:** Der Dienst setzt `expectedTitle` nur, wenn `fields.title` da ist,
  `expectedDueDate` nur bei `fields.dueDate`, `expectedContexts` nur bei `fields.contexts`, `expectedProject` nur bei
  `fields.project` (und die Abschrift eins hat). `expectedStatus` immer. So entspricht es dem Vertragsbeispiel.
- **Leeres `fields`:** wird schon im Dienst abgelehnt (Vertrag: `invalid`), bei `capture` bleibt `{}` erlaubt (S2-Test).
- **`notes` bei `update`:** `fieldsCheck(false)` lässt `notes` nicht zu → Ablehnung im Dienst; zod-Schema ohne `notes`.
- **Status `done`/`removed`:** Dienst prüft Form, nicht Bedeutung (wie bei den anderen Arten); die App antwortet `invalid`.
- **Reihenfolge Auslieferung:** App S1 ist gemergt; ein Gerät ohne S1 lehnt `update` sauber als unlesbar ab. Ausrollen nach Merge.

### Alternativen
- **Einzelwerkzeuge je Feld** (`rename_task`, `set_tags` …): einfachere Beschreibung je Werkzeug, aber viele Arten und Aufrufe;
  verworfen in S1 (Spec Schnitt 1, „Alternativen“). Fiele: keine ADR, nur das gewählte Feldobjekt.
- **Erwarteten Stand immer voll mitschicken** (alle vier Werte, auch für nicht geänderte Felder): strenger, aber jede
  unbeteiligte Änderung (z. B. ein neuer Tag in der App) machte einen Umbenennungsauftrag `stale`. Verworfen; der Vertrag
  sagt „jedes geänderten Felds“.

## Risks & Considerations
- Migration läuft auf dem Live-Dienst: nur CHECK ersetzen, additiv; Test „Migration 009 einmal angewendet“.
- Zwei Server-Tests listen alle Migrationen (`accounts.test.ts`, `schema.test.ts`) und müssen 009 aufnehmen.
- Anleitung ≤ 2048 Byte, jeder Werkzeugname darin muss existieren (Test `mcp-anleitung`).
- Nach Merge: Ausrollen auf rennwienix (`deploy-loose-ends.sh` mit `LE_COMMIT`), danach Durchlauf in claude.ai (DoD #932);
  Testbau mit `konto` an, falls der aktuelle TestFlight-Bau S1 noch nicht trägt.

## Analysis

### Type
Feature (Dienst-Schnitt 3 von #932; App-Seite seit Schnitt 1 fertig)

### Geprüfter Stand (2026-11-16)
- `orders.ts` `forms` kennt `capture … addSubtask`, kein `update`; `fieldsCheck(false)` existiert schon (lehnt `notes` ab).
- `mcp.ts` `Target`/`expected()` liefert nur Status, Datum, Rang; `captureFieldsSchema` ist das Muster für ein strenges `fields`.
- Migration 007 ersetzt den CHECK per `DO $$`; nächste Nummer 009. `accounts.test.ts:66` und `schema.test.ts:61` listen alle Migrationen.
- App `OrderExecutor.update`/`matchesTranscript`: vergleicht Titel, Datum, Tags, Projekt nur, wenn das Feld in `fields` steht;
  fehlender Erwartungswert = „hatte keinen“ (Tags als Namensschlüssel-Menge, `nil` = leer). `dueDate` nur paarweise mit `dueHasTime`;
  Entfernen der Fälligkeit bleibt `set_due`.
- `anleitung.ts` 1311 Byte Quelle (Text 964 von 2048 Byte).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/migrations/009_order_update.sql` | CREATE | CHECK `orders_kind_known` um `update` (Muster 007) |
| `server/src/orders.ts` | MODIFY | `Order`-Union + `forms.update` (Pflicht `taskID`, `expectedStatus`, `fields` nicht leer via `fieldsCheck(false)`; optional `expectedTitle`, `expectedDueDate`, `expectedContexts`, `expectedProject`) |
| `server/src/mcp.ts` | MODIFY | `expected()` gibt zusätzlich Titel, Tags, Projekt der Zeile zurück; Werkzeug `update_task` (`taskID`, `generatedAt`, `fields` ohne `notes`, strict); Handler `updating` setzt Erwartungswerte nur für geänderte Felder |
| `server/src/anleitung.ts` | MODIFY | ein Satz: Titel/Angaben mit `update_task` erst nach dem Ja des Nutzers |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | „`update` erst ab Schnitt 3 / bis dahin verworfen“ → angenommen |
| `CLAUDE.md` | MODIFY | `mcp.ts`-Zeile: `update_task`, Migration 009 |
| `server/test/orders.test.ts`, `mcp-write.test.ts`, `accounts.test.ts`, `schema.test.ts` | MODIFY | Vertragsbeispiel `update` aus dem jsonc-Block, Formfälle, Werkzeug end-to-end, Migrationslisten |

### Scope Assessment
- Produktdateien: 3 Server + 1 Migration; Doku 2; Tests 4 (zwei davon je eine Zeile)
- Estimated LoC: Produkt ≈ +70, Doku ≈ +5/−3, Tests ≈ +130 → knapp über 200; Dateizahl über 5 nur durch Tests/Doku (wie S2)
- Risk Level: LOW–MEDIUM — additiv; einziges Live-Risiko ist die Migration (nur CHECK ersetzen, in Transaktion)

### Technical Approach
Wie Kontext-Kurzanalyse: `update_task` als ein Werkzeug mit Feldobjekt; der Dienst füllt den erwarteten Stand aus der Abschrift
nur für die geänderten Felder (`expectedStatus` immer; `expectedTitle` bei `title`, `expectedDueDate` bei `dueDate` falls vorhanden,
`expectedContexts` bei `contexts` falls nicht leer, `expectedProject` bei `project` falls vorhanden). Leeres `fields` und `notes`
lehnt schon der Dienst ab (zod + `checkOrder`). Status `done`/`removed` prüft der Dienst nicht inhaltlich (App: `invalid`), wie bei
den übrigen Arten. Nach Merge Ausrollen auf rennwienix, dann Durchlauf in claude.ai (DoD #932).

### Alternativen
- Einzelwerkzeuge je Feld — verworfen in S1 (keine ADR betroffen).
- Erwarteten Stand immer voll mitschicken — verworfen: macht unbeteiligte App-Änderungen zu `stale`; Vertrag sagt „jedes geänderten Felds“.
- `expectedContexts: []` statt weglassen bei leerer Tagliste — gleichwertig für die App (`nil` = leer); weglassen folgt der Vertragskonvention.

### Dependencies
Upstream `getTranscript` (Zeile mit `title`, `contexts`, `project?`, `dueDate?`, `status`); Downstream App `OrderExecutor.update` (S1, gemergt).

### Open Questions
- keine (Produktentscheidungen in #932 und S1-Spec getroffen)
