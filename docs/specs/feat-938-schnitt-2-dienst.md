---
entity_id: feat-938-schnitt-2-dienst
type: feature
created: 2026-11-19
updated: 2026-11-19
status: draft
workflow: feat-938-s2-dienst
---

# Spec: Claude legt wiederkehrende Aufgaben und Links an, Schnitt 2 (Dienst, `fields.repeat` und `fields.link`, #938)

## Approval

- [ ] Approved

## GitHub Issue

#938 (Epic #612). Schnitt 2 von 3. Das Issue bleibt offen (PR mit `Refs #938`, nie `Closes #938`), bis Ausrollen und Durchlauf in claude.ai aus der Definition of Done erledigt sind.
Analyse: `docs/context/feat-938-s2-dienst.md` (Abschnitt „Analysis“), Gesamtanalyse `docs/context/feat-938-wiederholung-claude.md`. Gegenstelle: Schnitt 1 (App, `docs/specs/feat-938-schnitt-1-app.md`, PR #949, gemergt). Vorbilder: `docs/specs/feat-932-schnitt-2-dienst.md`, `docs/specs/feat-932-schnitt-3-update.md`.

## Purpose

Der Dienst nimmt `fields.repeat` (an `capture_task` und `update_task`) und `fields.link` (nur an `capture_task`) an, prüft ihre Form und reicht sie im Auftrag an die App weiter, die beides seit Schnitt 1 ausführt. Heute weist er beide Schlüssel zweimal ab: zod `captureFieldsSchema` ist `.strict()`, und `fieldsCheck` in `server/src/orders.ts` kennt sie nicht („unbekannter Schlüssel“). Damit kann Claude „alle 26 Wochen Zahnarzt Kontrolle“ samt Praxis-Link in einem Zug anlegen.

**Regeln vor Modell:** reine Formprüfung, kein Modellaufruf, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- **Bedeutung prüft die App:** Anker, Uhrzeit der Regel, Revisionen, Wirkung von `weekdays` (Sortieren, Entdoppeln) sind Sache der App (Vertrag). Der Dienst sortiert und entdoppelt `weekdays` nicht.
- **`link` bei `update`** und eine Wiederholung entfernen gibt es nicht (Vertrag, Version 1).
- **„Jedes Jahr am n-ten Wochentag“** (z. B. 2. Samstag im Februar) gibt es nicht (PO-Entscheidung 2026-11-17): Claude legt jährlich zum Datum an und nennt dem Nutzer die Abweichung. Das steht in den Werkzeugbeschreibungen; die Anleitung bleibt unverändert.
- Keine Änderung an der App, an der Abschrift (sie trägt keine Wiederholung), an der Vertragsversion (bleibt 1), an `updating` (für `repeat` gilt nur `expectedStatus`, der immer mitgeht), an Migrationen.
- **Ausrollen** gehört in die Definition of Done, nicht in die ACs (siehe dort, Reihenfolge).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR, keine bestehende betroffen. Der Auftragsweg (ADR-21, Weg B) und das Muster „Form im Dienst, Bedeutung in der App“ aus #932 bleiben; es kommen nur zwei erlaubte Schlüssel in `fields`, derselben Vertragsversion.
- **Rationale:** additive Erweiterung eines bestehenden Auftrags ohne Schema- oder Protokolländerung.

## Source

**Files:** `server/src/orders.ts`, `server/src/mcp.ts`, `docs/reference/claude-abschrift-vertrag.md`, `server/test/orders.test.ts`, `server/test/mcp-write.test.ts`
**Identifier:** `Fields`, `fieldsCheck`, `captureFields`, `updateFields`, `captureFieldsSchema`, `updateFieldsSchema`, Werkzeuge `capture_task` und `update_task`

## Dependencies

| Entität | Art | Zweck |
|---|---|---|
| `server/src/transcripts.ts` | bestehend, unverändert | exportierte Prüfbausteine `shape`, `text`, `fail`, `list` (Fehlertexte mit Pfad) |
| `server/src/orders.ts` | bestehend | `fieldsCheck(withNotes)`, `checkOrder`, `oneOf` |
| `server/src/mcp.ts` | bestehend | `capturing`/`updating` reichen `fields` unverändert durch; zod-Schemata |
| zod, MCP-SDK | bestehend | Eingabeschema, `.strict()` |
| `Shared/Services/OrderExecutor.swift` (`isWellFormed`, App, Schnitt 1) | bestehend, unverändert | Gegenstelle; die Dienstprüfung ist deckungsgleich |
| `docs/reference/claude-abschrift-vertrag.md` | bestehend | Form und Beispiel; Tests lesen das Beispiel daraus |

## Implementation Details

### Form (`orders.ts`)

`Fields` bekommt `repeat?: Repeat` und `link?: string`. Zwei neue Prüfbausteine, gebaut aus `shape`, `text`, `oneOf`, `fail`:

- `repeat`: Objekt, `shape` strikt; Pflicht `frequency` ∈ `daily`/`weekly`/`monthly`/`yearly`; optional `interval` (ganzzahlig 1…52, sonst Fehler „keine ganze Zahl von 1 bis 52“), `weekdays` (Liste, nicht leer, je ganzzahlig 1…7; nur wenn `frequency` `weekly` ist, sonst Fehler am Pfad `….weekdays`), `basis` ∈ `fromDueDate`/`fromCompletion`. Fremder Schlüssel: „unbekannter Schlüssel“ mit Pfad (`fields.repeat.<schlüssel>`).
- `link`: Text (`text`), `URL.parse` liefert eine URL, Schema `http:` oder `https:`, Host nicht leer; sonst Fehler am Pfad `fields.link`.

`fieldsCheck(withNotes)` nimmt `repeat` immer und `link` nur, wenn `withNotes` gilt (wie `notes`: nur bei `capture`). Bei `update` ist `link` damit „unbekannter Schlüssel“ mit Pfad `fields.link`. Die Fehler laufen wie bisher als `Auftrag ungültig: <pfad> …`. Der Fall „`fields` leer“ bei `update` bleibt wie in #932 S3.

Deckungsgleich mit der App: Wertemengen, Grenzen 1…52 und 1…7, „weekdays nur bei weekly und nicht leer“, http/https mit Host, `link` nur bei `capture`. Weicht `URL.parse` (WHATWG) in Randfällen von Swifts `URL(string:)` ab, lehnt die App mit `invalid` ab; es entsteht keine Aufgabe, kein Schaden.

### Werkzeuge (`mcp.ts`)

`captureFieldsSchema` bekommt `repeat` (zod-Objekt, `frequency` Pflicht als `z.enum`, `interval` `z.number().int().min(1).max(52)` optional, `weekdays` `z.array(z.number().int().min(1).max(7)).min(1)` optional, `basis` `z.enum` optional, **`.strict()`**, damit ein Tippfehler im Objekt abgewiesen statt gestrichen wird) und `link` als `z.string()`. `updateFieldsSchema` lässt `notes` und `link` weg (`omit({ notes: true, link: true })`, `.strict()`). `checkOrder` bleibt die eigentliche Prüfung; `capturing` und `updating` ändern sich nicht (`fields` geht unverändert mit, nur wenn gegeben; Aufträge ohne `repeat`/`link` bleiben byte-gleich).

Die Beschreibungen beider Werkzeuge nennen `repeat` (Häufigkeit, Abstand 1…52, Wochentage 1 = Sonntag bis 7 nur bei weekly, Basis) und, bei `capture_task`, `link` (http/https, wird Quelle der Aufgabe). Beide sagen: „Jedes Jahr am n-ten Wochentag“ gibt es nicht; dann jährlich zum Datum anlegen und dem Nutzer diese Abweichung nennen. `update_task` sagt zusätzlich: eine Wiederholung lässt sich nicht entfernen. Die Anleitung (`anleitung.ts`) bleibt unverändert, ≤ 2048 Byte.

### Vertrag (`docs/reference/claude-abschrift-vertrag.md`)

Der Satz „Der Dienst nimmt `repeat` und `link` ab #938 Schnitt 2 an; bis dahin weist er sie als unbekannte Schlüssel ab.“ wird Gegenwart: der Dienst nimmt beide an und prüft nur die Form (#938 Schnitt 2). Der Satz „Der Dienst nimmt `fields` an … (#932 Schnitt 2 und 3)“ nennt zusätzlich #938. Die jsonc-Beispiele und die drei ` ```json`-Blöcke bleiben Zeichen für Zeichen.

## Scope

### Affected Files

| Datei | Änderung | Beschreibung | LoC |
|---|---|---|---|
| `server/src/orders.ts` | MODIFY | `Fields`, Prüfbausteine `repeat`/`link`, `fieldsCheck` | +22/-2 |
| `server/src/mcp.ts` | MODIFY | zod `repeat`/`link`, `updateFieldsSchema` ohne `link`, zwei Beschreibungen | +16/-4 |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Satz in Gegenwart | +3/-2 |
| `server/test/orders.test.ts` | MODIFY | gute Formen, Fehlertabelle, Vertragsbeispiel | +50 |
| `server/test/mcp-write.test.ts` | MODIFY | Durchreichen, Abweisungen, Schlüsselmengen | +40/-2 |

### Estimated Changes

- Files: 5 (Produktcode 2, Doku 1, Tests 2), im Limit von 4–5.
- LoC: etwa +130/−8 (davon ≈ 90 Tests), unter ±250.

## Test Plan

### Automated Tests (TDD RED)

Tests des Dienstes (`node:test`) über `./server/scripts/test-local.sh`; das #938-Beispiel wird gezielt aus dem Vertrag gelesen (das zweite ` ```jsonc`-Beispiel `capture`, jenes mit `fields.repeat`), nie kopiert; `captureExample()` bleibt beim ersten.

- [ ] Test 1: GIVEN das ` ```jsonc`-Beispiel `capture` mit `repeat` und `link` aus dem Vertrag (gelesen) WHEN `checkOrder` THEN kein Fehler, und `putOrder` speichert es, wie gegeben.
- [ ] Test 2: GIVEN `repeat` nur mit `frequency` und je eine Form mit `daily`, `weekly` mit `weekdays` `[2,4]` und `interval` 1 bzw. 52, `monthly`, `yearly`, `basis` `fromCompletion` WHEN `checkOrder` bei `capture` und bei `update` THEN kein Fehler.
- [ ] Test 3: GIVEN `repeat` mit `interval` 0, 53, 1.5, unbekannter `frequency`, unbekannter `basis`, `weekdays` leer, mit 0, mit 8, mit 1.5, `weekdays` bei `monthly`, fremdem Schlüssel im `repeat`, ohne `frequency`, als Text statt Objekt WHEN `checkOrder` THEN je ein Fehler `Auftrag ungültig:` mit dem Pfad (`fields.repeat.interval`, `fields.repeat.frequency`, `fields.repeat.basis`, `fields.repeat.weekdays`, `fields.repeat.<schlüssel>`, `fields.repeat`), und nichts wird gespeichert.
- [ ] Test 4: GIVEN `link` `https://…` und `http://…` mit Host bei `capture` WHEN `checkOrder` THEN kein Fehler; GIVEN `link` `ftp://…`, ohne Host (`https://`), ohne Schema (`example.org`), als Zahl WHEN `checkOrder` THEN Fehler mit Pfad `fields.link`.
- [ ] Test 5: GIVEN ein `update` mit `fields.link` (auch mit gültiger Adresse) WHEN `checkOrder` THEN Fehler `Auftrag ungültig: fields.link …`; GIVEN ein `update` nur mit `fields.repeat` THEN kein Fehler.
- [ ] Test 6: GIVEN `capture_task` mit `fields` aus `repeat` und `link` WHEN ausgeführt THEN der gespeicherte Auftrag trägt beide unverändert; GIVEN `update_task` mit `fields.repeat` THEN der Auftrag trägt `repeat`, `expectedStatus` und keinen weiteren Erwartungswert (kein `expectedTitle`, `expectedDueDate`, `expectedContexts`, `expectedProject`).
- [ ] Test 7: GIVEN `update_task` mit `fields.link`, `capture_task` oder `update_task` mit einem Tippfehler im `repeat` (`frequenz`, `intervall`), `interval` 0 oder 53, `weekdays` `[]` WHEN ausgeführt THEN isError und kein Auftrag in der Datenbank, der Geräte-Waker nicht gerufen.
- [ ] Test 8: GIVEN die Werkzeugliste WHEN die Schlüsselmengen von `fields` verglichen werden THEN hat `update_task` genau die Schlüssel von `capture_task` ohne `notes` und `link` (nach der Änderung 10 gegen 12), beide `.strict()`, `repeat` ist in beiden ein Objekt mit `additionalProperties` false und Pflicht `frequency`.
- [ ] Test 9: GIVEN die Beschreibungen von `capture_task` und `update_task` WHEN aus der Werkzeugliste gelesen THEN nennen beide „Wochentag“ mit der Anweisung, jährlich zum Datum anzulegen und die Abweichung zu nennen, und `capture_task` nennt `link`.
- [ ] Test 10: GIVEN die bestehenden Tests (Aufträge ohne `repeat`/`link`, alle Formtests, Anleitung `mcp-anleitung` ≤ 2048 Byte, Werkzeugliste ohne Löschwerkzeug) WHEN der Lauf THEN unverändert grün, soweit nicht Test 8 die Schlüsselzahl (9 → 10) nachzieht.

### Abnahme

Stufe 1: neue Tests rot vor, grün nach der Umsetzung; `./server/scripts/test-local.sh` grün (Typprüfung und alle Dienst-Tests gegen die Wegwerf-Datenbank).
Stufe 2: Durchlauf über den echten MCP-Handler und die echte Wegwerf-Datenbank (Tests 1, 6, 7; optional `./server/scripts/local-service.sh` mit einer Abschrift aus `local-fixture.ts`): `capture_task` mit Wiederholung und Link, gespeicherter Auftrag, Beleg als Ausgabe. Es gibt keine sichtbare Oberfläche und keine App-Änderung; das wird im Abschlussbericht so benannt.
Stufe 3: Kein Pfad der Geräteliste berührt. Geprüft gegen die Tabelle in `CLAUDE.md`: nur `server/` und `docs/`.

## Acceptance Criteria

- **AC-1:** `checkOrder` nimmt das Vertragsbeispiel `capture` mit `repeat` und `link` an; der Test liest es gezielt aus dem Vertrag, und der Auftrag wird unverändert gespeichert (Test 1).
- **AC-2:** `checkOrder` nimmt `repeat` mit `frequency` allein und mit jeder Kombination aus `interval` 1…52, `weekdays` (nur `weekly`, nicht leer, je 1…7) und `basis` bei `capture` und `update` an (Test 2).
- **AC-3:** `checkOrder` weist ein `repeat` mit `interval` außerhalb 1…52 oder nicht ganzzahlig, unbekannter `frequency` oder `basis`, falschen `weekdays` (leer, außerhalb 1…7, nicht ganzzahlig, nicht bei `weekly`), fehlender `frequency`, fremdem Schlüssel oder Nicht-Objekt mit `Auftrag ungültig: <pfad> …` ab, ohne dass etwas gespeichert wird (Test 3).
- **AC-4:** `checkOrder` nimmt einen `link` mit Schema `http` oder `https` und Host bei `capture` an und weist andere Schemata, fehlenden Host, fehlendes Schema und Nicht-Text mit Pfad `fields.link` ab (Test 4).
- **AC-5:** `checkOrder` weist `fields.link` bei `update` mit `Auftrag ungültig: fields.link …` ab; ein `update` nur mit `repeat` wird angenommen (Test 5).
- **AC-6:** `capture_task` und `update_task` reichen `repeat` (und `link` bei `capture_task`) unverändert in den Auftrag; `update_task` setzt für `repeat` nur `expectedStatus` und keinen weiteren Erwartungswert (Test 6).
- **AC-7:** Die Werkzeuge weisen `link` bei `update_task`, ein Tippfehler im `repeat` und Werte außerhalb der Form ab, ohne Auftrag und ohne Wecken der Geräte (Test 7).
- **AC-8:** Das zod-Schema ist `.strict()`, auch für das `repeat`-Objekt; `update_task` hat genau die Schlüssel von `capture_task` ohne `notes` und `link` (Test 8).
- **AC-9:** Die Beschreibungen beider Werkzeuge nennen die Abweichung „n-ter Wochentag“ (jährlich zum Datum, dem Nutzer nennen), `capture_task` nennt `link`; die Anleitung ist unverändert und ≤ 2048 Byte (Test 9, 10).
- **AC-10:** Der Vertrag beschreibt die Annahme von `repeat` und `link` in der Gegenwart (kein „bis dahin weist er sie ab“ mehr), die Beispielblöcke sind unverändert; alle bestehenden Tests bleiben grün, Aufträge ohne `repeat`/`link` sind byte-gleich; `./server/scripts/test-local.sh` ist grün (Test 10, Prüfung im Review).

## Definition of Done

- [ ] Neue Tests aus dem Test Plan rot vor der Umsetzung, grün danach; `./server/scripts/test-local.sh` grün; Durchlauf über den echten Handler belegt
- [ ] Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“
- [ ] Ausgeliefert per PR mit `Refs #938`, CI grün, gemergt
- [ ] **Ausrollreihenfolge:** Der Dienst wird erst auf `rennwienix` ausgerollt (`scripts/deploy-loose-ends.sh` mit `LE_COMMIT`, Dienst gesund), wenn der TestFlight-Bau mit Schnitt 1 (Bau vom 2026-11-19) auf Hennings Geräten läuft. Eine ältere App dekodiert `repeat`/`link` nicht (Swift `Codable` ignoriert fremde Schlüssel), legt die Aufgabe ohne Wiederholung an und meldet `done`: still falsch. Vor dem Ausrollen wird geklärt, ob der Bau installiert ist, ohne Gerätezugriff.
- [ ] Durchlauf in claude.ai: Claude legt „alle 26 Wochen Zahnarzt Kontrolle“ mit Link an, `get_order_result` zeigt `done`, die Aufgabe wiederholt sich in der App; erst danach wird #938 geschlossen (S3 „Family“ bleibt eigener Schnitt)

## Alternativen

- **Eigenes Werkzeug `set_repeat`** (wie `set_due`): verworfen in der Gesamtanalyse; zwei Aufträge je Aufgabe, der Anker zwischen beiden stünde falsch. Fiele: die Festlegung „`fields` ist der eine Weg“ aus #932, keine ADR.
- **Nur zod prüfen, `checkOrder` unverändert:** geht nicht, `checkOrder` weist jeden fremden Schlüssel ab; und die zweite Prüfung schützt die App-Route vor Aufträgen, die nicht aus zod kommen.
- **Wiederholung „n-ter Wochentag“ im Modell (S1b):** verworfen (PO 2026-11-17); stattdessen jährlich zum Datum mit Hinweis an den Nutzer.
- **Anleitung statt Werkzeugbeschreibung für den Hinweis:** der Hinweis steht dort, wo Claude ihn beim Aufruf liest; die Anleitung bleibt klein (≤ 2048 Byte).
- **`weekdays` im Dienst sortieren und entdoppeln:** brächte eine zweite Wahrheit neben der App; verworfen, der Vertrag überlässt es ihr.

## Risiken

- **Ausrollreihenfolge:** siehe Definition of Done; Gegenmittel ist die Klärung vor dem Ausrollen.
- **Form doppelt beschrieben (zod und `checkOrder`) und gegenüber der App:** `checkOrder` ist die Wahrheit, Test 8 fängt Auseinanderlaufen von zod und `checkOrder` bei den Schlüsseln ab; weicht die App ab, lehnt sie mit `invalid` ab, ohne dass eine Aufgabe entsteht.
- **`URL.parse` gegen Swifts `URL(string:)`:** Randfälle können abweichen; Folge nur `invalid` der App.
- **Beschreibungslänge der Werkzeuge:** zwei Sätze mehr; kein Größenlimit betroffen, Test 9 hält die Aussage.

## Changelog

- 2026-11-19: Erste Fassung (Schnitt 2, Dienst, `repeat` und `link`).
