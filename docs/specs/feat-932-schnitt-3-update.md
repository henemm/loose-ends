---
entity_id: feat-932-schnitt-3-update
type: feature
created: 2026-11-16
updated: 2026-11-16
status: draft
workflow: feat-932-s3-update
---

# Spec: Claude setzt Titel und Angaben, Schnitt 3 (Dienst, `update_task`, #932)

## Approval

- [ ] Approved

## GitHub Issue

#932 (Epic #612). Schnitt 3 von 3. Das Issue bleibt offen (PR mit `Refs #932`, nie `Closes #932`), bis Ausrollen und Durchlauf in claude.ai aus der Definition of Done von #932 erledigt sind.
Analyse: `docs/context/feat-932-s3-update.md` (Abschnitt „Analysis“). Vorgänger: Schnitt 1 (App, `docs/specs/feat-932-schnitt-1-app.md`, PR #934) und Schnitt 2 (Dienst, `fields` an `capture`, `docs/specs/feat-932-schnitt-2-dienst.md`, PR #935), beide gemergt.

## Purpose

Der Dienst bekommt das Werkzeug `update_task`: Claude ändert Titel, Fälligkeit, Wichtigkeit, Dringlichkeit, Dauer, Energie, Tags und Projekt einer bestehenden Aufgabe, nachdem der Nutzer zugestimmt hat. Der Dienst nimmt dafür den Auftrag `update` an (Vertrag, App seit Schnitt 1), füllt den erwarteten Stand aus der Abschrift und weckt die Geräte. Heute verwirft er `update` zweimal: `forms` in `server/src/orders.ts` kennt die Art nicht, und der CHECK `orders_kind_known` (Migration 007) lässt sie nicht in die Tabelle.

**Regeln vor Modell:** reine Formprüfung und Abschriftvergleich, kein Modellaufruf, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- **Bedeutung prüft die App, nicht der Dienst:** vorhandene Tag- und Projektnamen, leerer Titel, Status `done`/`removed`. Die App antwortet `invalid` (Schnitt 1); der Dienst reicht `expectedStatus` `done` heute auch bei den anderen Arten durch.
- **`notes` bei `update`:** nicht erlaubt (Vertrag), also kein Werkzeugschlüssel und im Dienst abgelehnt.
- **Fälligkeit entfernen** bleibt `set_due` ohne `date` (Vertrag).
- Keine Änderung an der App, an der Abschrift oder an der Vertragsversion (bleibt 1).
- **Ausrollen und claude.ai-Durchlauf** gehören in die Definition of Done, nicht in die ACs: nach dem Merge auf `rennwienix` ausrollen (`scripts/deploy-loose-ends.sh` mit `LE_COMMIT`), dann der Durchlauf in claude.ai (ein Titel, ein Tag, ein Projekt ändern). Der Testbau muss Schnitt 1 enthalten (`konto` an), sonst meldet eine ältere App `update` als unlesbar (sauber abgelehnt).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR, keine bestehende betroffen. Der Auftragsweg (ADR-21, Weg B) bleibt; eine weitere Art im bestehenden Auftrag derselben Version. Die Migration ersetzt nur einen CHECK (additiv, wie Migration 007).

## Source

**Files:** `server/migrations/009_order_update.sql`, `server/src/orders.ts`, `server/src/mcp.ts`, `server/src/anleitung.ts`, `docs/reference/claude-abschrift-vertrag.md`, `CLAUDE.md`
**Identifier:** `forms.update`, `fieldsCheck`, `checkOrder`, `expected`, `updating`, Werkzeug `update_task`, CHECK `orders_kind_known`

## Dependencies

| Entität | Art | Zweck |
|---|---|---|
| `server/src/orders.ts` | bestehend | `checkOrder`, `forms`, `fieldsCheck(false)` (lehnt `notes` ab, besteht seit S2), `orderStatus`, `oneOf` |
| `server/src/transcripts.ts` | bestehend, unverändert | `getTranscript`, Zeile mit `title`, `contexts`, optional `project`, `dueDate`, `status`; Bausteine `shape`, `text`, `time`, `id` |
| `server/src/mcp.ts` | bestehend | `expected`, `storeOrder` (prüft mit `checkOrder`, weckt Geräte), zod, `captureFieldsSchema` als Muster |
| `server/migrations/007_order_kinds.sql` | bestehend | Muster: alten CHECK per `DO $$` finden und ersetzen; der Runner hüllt in eine Transaktion |
| `server/src/anleitung.ts` | bestehend | MCP-`instructions`, Text 964 von 2048 Byte; Test `mcp-anleitung` hält Werkzeugnamen und Größe |
| `Shared/Services/OrderExecutor.swift` (App, Schnitt 1) | bestehend, unverändert | liest `expectedTitle`, `expectedContexts`, `expectedProject`, `expectedDueDate`, `expectedStatus`; fehlender Erwartungswert heißt „hatte keinen“ |
| zod (MCP-SDK) | bestehend | Eingabeschema von `update_task`, `.strict()` |

## Implementation Details

### Migration 009

`server/migrations/009_order_update.sql` ersetzt den CHECK `orders_kind_known` (Muster 007: den alten per `DO $$` über `pg_get_constraintdef … LIKE '%capture%'` finden und löschen, dann `ADD CONSTRAINT orders_kind_known CHECK (kind IN (…, 'addSubtask', 'update'))`). Kein `BEGIN`/`COMMIT`, der Runner hüllt in eine Transaktion. Nur der CHECK ändert sich; keine Spalte, keine Daten. Die Liste der Migrationen in `accounts.test.ts` und `schema.test.ts` bekommt `009_order_update.sql`.

### Form des Auftrags `update` (`orders.ts`)

`Order` bekommt `{ kind: "update"; taskID; expectedStatus; fields: Fields; expectedTitle?; expectedDueDate?; expectedContexts?; expectedProject? }`. `forms.update` hat Pflicht `taskID` (`id`), `expectedStatus` (`orderStatus`), `fields` (`fieldsCheck(false)`, also ohne `notes`, `dueDate` nur mit `dueHasTime`) und optional `expectedTitle` (`text`), `expectedDueDate` (`time`), `expectedContexts` (`names`), `expectedProject` (`text`). Ein leeres `fields` ist bei `update` ein Formfehler (der Vertrag verlangt „nicht leer“): `fields` bekommt dafür eine kleine Prüfung „mindestens ein Schlüssel“ vor `fieldsCheck(false)`, `capture` bleibt mit `{}` erlaubt (S2-Test). Fehler wie überall als `Auftrag ungültig: <pfad> …`.

### Werkzeug `update_task` (`mcp.ts`)

Eingabe `taskID`, `generatedAt`, `fields`. `fields` ist ein zod-Objekt mit den Schlüsseln von `captureFieldsSchema` ohne `notes`, `.partial().strict()`; zod streicht sonst unbekannte Schlüssel still, ein Tippfehler wie „titel“ ginge verloren. `checkOrder` bleibt die eigentliche Prüfung. Die Beschreibung nennt: erst nach dem Ja des Nutzers, Tags und Projekt nur mit Namen, die es schon gibt, `dueDate` in UTC mit Z nur zusammen mit `dueHasTime`, Fälligkeit entfernen per `set_due`, ausgeführt auf einem Gerät, Stand per `get_order_result`; Annotationen wie die anderen Schreibwerkzeuge (`readOnlyHint` false, `destructiveHint` false, `idempotentHint` false).

`expected()` bleibt die einzige Stelle, die die Abschrift liest und die Ablehnungstexte liefert (`kein Konto`, `noch keine Abschrift`, `Abschrift hat sich geändert, bitte neu lesen`, `Aufgabe nicht in der Abschrift`). `Target` bekommt zusätzlich `title`, `contexts` und `project` der Abschriftzeile (die bestehenden Werkzeuge ignorieren sie, ihre Aufträge bleiben byte-gleich). Der Handler `updating` setzt den erwarteten Stand nur für geänderte Felder:

| Feld in `fields` | Erwartungswert im Auftrag |
|---|---|
| immer | `expectedStatus` |
| `title` | `expectedTitle` (Titel der Zeile) |
| `dueDate` | `expectedDueDate`, falls die Zeile eine Fälligkeit hat |
| `contexts` | `expectedContexts`, falls die Tagliste der Zeile nicht leer ist |
| `project` | `expectedProject`, falls die Zeile eines hat |

Fehlt der Wert, hatte die Aufgabe keinen (Vertragskonvention). Wichtigkeit, Dringlichkeit, Dauer und Energie stehen nicht in der Abschrift; für sie gilt nur der Status. Nach dem Speichern wie bei den anderen: `storeOrder` weckt die Geräte des Kontos abgekoppelt, nur bei neu gespeichertem Auftrag.

### Anleitung (`anleitung.ts`)

Ein Satz: Titel und Angaben ändert Claude mit `update_task` erst nach dem Ja des Nutzers; ohne `fields` bleibt der Text, wie der Nutzer spricht. Der Text bleibt ≤ 2048 Byte (heute 964), jeder genannte Werkzeugname existiert (Test `mcp-anleitung`).

### Vertrag und Doku

`docs/reference/claude-abschrift-vertrag.md`: Zeile 10 („das Beispiel `update` prüft der Server ab #932 Schnitt 3“) wird: das Beispiel `update` liest ebenfalls `server/test/orders.test.ts`; Zeilen 123f: der Dienst nimmt `fields` an `capture` und `update` an und prüft nur die Form, der Satz „`update` erst ab Schnitt 3; bis dahin verwirft er `update`“ entfällt. `CLAUDE.md`: in der `mcp.ts`-Zeile `update_task` und Migration 009 nennen. Die drei ` ```json`-Blöcke bleiben Zeichen für Zeichen.

## Scope

### Affected Files

| Datei | Änderung | Beschreibung | LoC |
|---|---|---|---|
| `server/migrations/009_order_update.sql` | CREATE | CHECK `orders_kind_known` um `update` | +12 |
| `server/src/orders.ts` | MODIFY | `Order`-Union, `forms.update`, Prüfung „nicht leer“ | +10/-1 |
| `server/src/mcp.ts` | MODIFY | `Target` + Titel/Tags/Projekt, `updating`, Werkzeug `update_task`, zod | +38/-2 |
| `server/src/anleitung.ts` | MODIFY | ein Satz | +3 |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Zeile 10, Zeilen 123f | +3/-3 |
| `CLAUDE.md` | MODIFY | `mcp.ts`-Zeile | +2/-1 |
| `server/test/orders.test.ts` | MODIFY | Vertragsbeispiel `update`, Formfälle | +45 |
| `server/test/mcp-write.test.ts` | MODIFY | `update_task` end-to-end, Abweisungen | +70 |
| `server/test/accounts.test.ts`, `server/test/schema.test.ts` | MODIFY | Migrationsliste, je eine Zeile | +2/-2 |

### Estimated Changes

- Files: 10 (Produktcode 4 inklusive Migration, Doku 2, Tests 4).
- LoC: etwa +190 (Produkt ≈ +70, Doku ≈ +5, Tests ≈ +115), unter ±250.
- **Dateigrenze:** 10 Dateien liegen über 4–5. Der Produktcode hat 4 Dateien; die Überschreitung kommt nur von Doku (2) und Tests (4, zwei davon je eine Zeile), wie in Schnitt 2. Teilen brächte nichts: Migration, Form, Werkzeug und Anleitung sind ohne einander nicht auslieferbar.

## Test Plan

### Automated Tests (TDD RED)

XCTest-Pflicht des QA-Gates gilt für Swift; hier laufen die Tests des Dienstes (`node:test`) über `./server/scripts/test-local.sh`.

- [ ] Test 1: GIVEN eine frische Datenbank WHEN `migrate` zweimal läuft THEN steht `009_order_update.sql` genau einmal in `schema_migrations`, und ein `INSERT` eines Auftrags mit `kind` `update` in `orders` gelingt, einer mit unbekannter Art verletzt `orders_kind_known`.
- [ ] Test 2: GIVEN das ` ```jsonc`-Beispiel `update` aus dem Vertrag (gelesen, nicht kopiert) WHEN `checkOrder` THEN kein Fehler.
- [ ] Test 3: GIVEN ein `update` mit leerem `fields`, mit `notes` in `fields`, ohne `expectedStatus`, ohne `taskID`, mit `dueDate` ohne `dueHasTime` WHEN `checkOrder` THEN je ein Fehler `Auftrag ungültig:` mit dem Pfad des Schlüssels (`fields`, `fields.notes`, `expectedStatus`, `taskID`, `fields.dueHasTime`).
- [ ] Test 4: GIVEN eine Abschrift mit einer Aufgabe (Titel, Tags, Projekt, Fälligkeit, Status `active`) WHEN `update_task` mit `fields.title` THEN der gespeicherte Auftrag hat `expectedStatus` und `expectedTitle`, aber weder `expectedContexts`, `expectedProject` noch `expectedDueDate`.
- [ ] Test 5: GIVEN dieselbe Aufgabe WHEN `update_task` mit `fields` aus `contexts`, `project`, `dueDate` samt `dueHasTime` THEN stehen `expectedContexts`, `expectedProject`, `expectedDueDate` mit den Werten der Zeile, `expectedTitle` fehlt; GIVEN eine Aufgabe ohne Tags, Projekt und Fälligkeit THEN fehlen alle drei Erwartungswerte.
- [ ] Test 6: GIVEN `update_task` mit unbekanntem Schlüssel (`titel`), mit `notes`, mit leerem `fields` oder mit falschem Wert (`importance` „urgent“, `energy` 4) WHEN ausgeführt THEN abgewiesen und kein Auftrag in der Datenbank.
- [ ] Test 7: GIVEN eine unbekannte `taskID`, keine Abschrift, ein anderes `generatedAt` und kein Konto WHEN `update_task` THEN je dieselbe Ablehnung wie bei `park_task` (`Aufgabe nicht in der Abschrift`, `noch keine Abschrift`, `Abschrift hat sich geändert, bitte neu lesen`, `kein Konto`) und kein Auftrag.
- [ ] Test 8: GIVEN ein Waker WHEN `update_task` einen Auftrag neu speichert THEN wird er einmal für das Konto aufgerufen; GIVEN ein abgewiesener Aufruf THEN nicht.
- [ ] Test 9: GIVEN das zod-Schema von `update_task` WHEN die Schlüsselmenge von `fields` verglichen wird THEN gleicht sie der von `captureFields` ohne `notes`.
- [ ] Test 10: GIVEN die Anleitung WHEN der Test `mcp-anleitung` läuft THEN ≤ 2048 Byte, jeder Werkzeugname (auch `update_task`) ist registriert, und der Text enthält `update_task` und „Ja des Nutzers“.
- [ ] Test 11: GIVEN die bestehenden Tests (Formtests aller Arten, `capture_task` mit und ohne `fields`, die übrigen Schreibwerkzeuge, Werkzeugliste ohne Löschwerkzeug) WHEN der Lauf THEN unverändert grün.

### Abnahme

Stufe 1: neue Tests rot vor, grün nach der Umsetzung; `./server/scripts/test-local.sh` grün (Typprüfung und alle Dienst-Tests gegen die Wegwerf-Datenbank).
Stufe 2: Durchlauf über den lokalen Dienst: `./server/scripts/local-service.sh` mit einer Abschrift aus `local-fixture.ts`, `update_task` über den echten MCP-Handler, gespeicherter Auftrag in der Wegwerf-Datenbank (Beleg als Ausgabe, im Test 4 bis 8 ebenfalls über den echten Handler und die echte Datenbank). Es gibt keine sichtbare Oberfläche und keine App-Änderung; das wird im Abschlussbericht so benannt.
Stufe 3: Kein Pfad der Geräteliste berührt. Geprüft gegen die Tabelle in `CLAUDE.md`: nur `server/`, `docs/` und `CLAUDE.md`.

## Acceptance Criteria

- **AC-1:** Migration 009 wird einmal angewendet (`schema_migrations`) und erlaubt `update` in `orders.kind`; eine unbekannte Art verletzt weiter `orders_kind_known`; die Migrationslisten in `accounts.test.ts` und `schema.test.ts` enthalten sie (Test 1).
- **AC-2:** `checkOrder` nimmt das Vertragsbeispiel `update` aus dem ` ```jsonc`-Block an, der Test liest es aus dem Vertrag (Test 2).
- **AC-3:** `checkOrder` weist ein `update` mit leerem `fields`, mit `notes` in `fields`, ohne `expectedStatus` und ohne `taskID` mit `Auftrag ungültig: <pfad> …` ab (Test 3).
- **AC-4:** `update_task` setzt `expectedStatus` immer und `expectedTitle`, `expectedDueDate`, `expectedContexts`, `expectedProject` nur, wenn das Feld in `fields` steht und die Abschriftzeile einen (bei Tags: nicht leeren) Wert hat; ohne Wert fehlt der Schlüssel (Test 4, 5).
- **AC-5:** `update_task` weist unbekannten Schlüssel, `notes`, leeres `fields` und falsche Werte ab, ohne dass ein Auftrag entsteht (Test 6).
- **AC-6:** `update_task` lehnt unbekannte Aufgabe, fehlende Abschrift, verändertes `generatedAt` und fehlendes Konto mit denselben Texten ab wie die anderen Schreibwerkzeuge, ohne Auftrag (Test 7).
- **AC-7:** Das zod-Schema von `update_task` ist `.strict()` und hat für `fields` genau die Schlüssel von `captureFields` ohne `notes` (Test 9).
- **AC-8:** Nach einem neu gespeicherten `update`-Auftrag werden die Geräte des Kontos einmal geweckt, bei einer Abweisung nicht (Test 8).
- **AC-9:** Die Anleitung nennt `update_task` mit „erst nach dem Ja des Nutzers“, bleibt ≤ 2048 Byte, und der Werkzeugnamen-Test bleibt grün (Test 10).
- **AC-10:** Vertrag (Zeile 10 und Zeilen 123f) und `CLAUDE.md` (`mcp.ts`-Zeile) sind auf den Stand Schnitt 3 gebracht; `./server/scripts/test-local.sh` ist grün, die bestehenden Tests laufen unverändert (Test 11, Prüfung im Review).

## Definition of Done

- [ ] Neue Tests aus dem Test Plan rot vor der Umsetzung, grün danach; `./server/scripts/test-local.sh` grün; Durchlauf über den lokalen Dienst belegt
- [ ] Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“
- [ ] Ausgeliefert per PR mit `Refs #932`, CI grün, gemergt
- [ ] Nach dem Merge auf `rennwienix` ausgerollt (`scripts/deploy-loose-ends.sh` mit `LE_COMMIT`, Migration 009 angewendet), Dienst gesund
- [ ] Durchlauf in claude.ai: Claude ändert nach dem Ja des Nutzers Titel, Tag und Projekt einer Aufgabe, `get_order_result` zeigt `done`; erst danach wird #932 geschlossen

## Alternativen

- **Einzelwerkzeuge je Feld** (`rename_task`, `set_tags`, …): einfachere Beschreibung je Werkzeug, aber viele Arten und Aufrufe; verworfen in Spec S1. Fiele: die Festlegung des Feldobjekts aus S1, keine ADR.
- **Erwarteten Stand immer voll mitschicken** (alle vier Werte auch für nicht geänderte Felder): strenger, aber jede unbeteiligte Änderung (ein neuer Tag in der App) machte einen Umbenennungsauftrag `stale`. Verworfen; der Vertrag sagt „jedes geänderten Felds“.
- **`expectedContexts: []` statt Weglassen bei leerer Tagliste:** für die App gleichwertig (`nil` = leer); Weglassen folgt der Vertragskonvention „fehlt der Wert, hatte die Aufgabe keinen“.
- **Leeres `fields` still als Nichtstun annehmen:** die App würde nichts ändern und `done` melden, Claude hielte eine Änderung für erfolgt. Verworfen; der Vertrag nennt es `invalid`, der Dienst sagt es sofort.

## Risiken

- **Migration auf dem Live-Dienst:** nur ein CHECK wird ersetzt, in einer Transaktion, additiv. Gegenmittel: Test 1 und der Lauf der Migrationen gegen die Wegwerf-Datenbank; `STRICT` im `DO $$` bricht laut ab, falls der alte CHECK nicht genau einmal gefunden wird.
- **Auslieferungsreihenfolge:** eine App ohne Schnitt 1 lehnt `update` als unlesbar ab. Gegenmittel: App-Schnitt 1 ist gemergt, ausgerollt wird erst nach dem Merge und der Prüfung, dass der Testbau Schnitt 1 trägt.
- **Form doppelt beschrieben (zod und `checkOrder`):** zod ist die Sicht für Claude, `checkOrder` die Wahrheit; Test 9 fängt Auseinanderlaufen ab.
- **Anleitungsgröße:** 964 von 2048 Byte, ein Satz passt; Test 10 hält die Grenze.

## Changelog

- 2026-11-16: Erste Fassung (Schnitt 3, Dienst, `update_task`).
