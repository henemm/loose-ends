# Context: feat-613-c4b2-mcp-complete-setdue (#613 Schnitt C4b-2)

## Request Summary
C4b-1 (PR #805) brachte `capture_task` und `get_order_result`. C4b-2 ergänzt die zwei Werkzeuge, die eine bestehende Aufgabe ändern:
`complete_task` (abhaken) und `set_due` (Fälligkeit setzen oder entfernen). Wie `capture_task` legen sie nur einen Auftrag an; ausgeführt wird er später auf einem Gerät.
Weiterhin ohne Port, Anmeldung (C6) und Betrieb (C7). Der Entwurf aus `docs/context/spike-613-c4b-mcp-schreiben.md` gilt weiter; hier nur die Reste.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/mcp.ts` | `capturing(pool)` ist das Muster (Konto prüfen, Auftrag bauen, `checkOrder`, `putOrder`, `{orderID, state: "waiting"}`); hier kommen `completing` und `setting` dazu |
| `server/src/orders.ts` | `Order`-Typ und Formen von `complete` (`taskID`, `expectedStatus`, `expectedDueDate?`) und `setDue` (`taskID`, `hasTime`, `date?`, `expectedDueDate?`); unverändert |
| `server/src/transcripts.ts` | `getTranscript`: `tasks[]` mit `status` (nur unprocessed/unverified/active/parked) und `dueDate?`; Quelle des erwarteten Stands |
| `server/test/mcp.test.ts` | Muster: In-Process-Client, `connect`, `call`, Beispielabschrift aus dem Vertrag; die Werkzeugliste in AC-1/AC-3 nennt heute vier Werkzeuge und wird sechs |
| `docs/reference/claude-abschrift-vertrag.md` | Zeilen 85–104: Bedeutung von `complete`/`setDue`, erwarteter Stand, `hasTime` ohne Uhrzeit = Tagesbeginn, `date` fehlt = Fälligkeit entfernen |

## Existing Patterns
- Werkzeugfehler als `isError: true` mit kurzem deutschem Text, „kein Konto“ vor jedem Lesen oder Schreiben.
- Kennung vergibt der Dienst (`randomUUID().toUpperCase()`); Formfehler meldet `checkOrder` mit seinem Text.
- Keine Inhalte in Logs; je Anfrage frischer Server.

## Entscheidungen aus dem Vorgänger-Kontext (gelten hier)
- Erwarteter Stand kommt vom Dienst aus der letzten Abschrift: `expectedStatus` = `status`, `expectedDueDate` = `dueDate` (fehlt = „keine Fälligkeit“, Feld bleibt weg).
- Fehlt die Abschrift oder die Aufgabe darin: Werkzeugfehler, kein Auftrag.
- Das Gerät prüft den Stand noch einmal (`stale`); Lesen und Anlegen müssen nicht atomar sein.

## Offene Punkte für die Spec
- `set_due`-Eingabe: `taskID`, `date?` (ISO 8601 mit Zone; fehlt = entfernen), `hasTime` (Pflicht im Auftrag).
- `complete_task` auf eine Aufgabe, die die Abschrift nicht kennt (z. B. schon erledigt: die Abschrift führt kein `done`): „Aufgabe nicht in der Abschrift“.
- Beschreibung muss „zuerst `list_tasks` lesen“ nennen.
- Annotationen: `readOnlyHint` falsch, `destructiveHint` falsch; `idempotentHint` bei `complete_task` falsch (wiederkehrende Aufgabe rollt weiter).

## Dependencies
- Upstream: `getTranscript`, `putOrder`, `checkOrder`, `zod`. Keine neuen Pakete.
- Downstream: niemand ruft `mcpHandler` auf (C7); die App holt noch keine Aufträge.

## Existing Specs
- `docs/specs/spike-613-schnitt-c4b1-mcp-erfassen-ergebnis.md` (Vorlage für Aufbau und AC-Stil), C3b (Aufträge), C4a (Lesen)

## Risks & Considerations
- Umfang: zwei Werkzeuge plus Tests, etwa 40 Zeilen Code, 100–130 Zeilen Test; unter 250 erwartet.
- Veraltete Abschrift führt auf dem Gerät zu `stale`: gewollt.
- Datenschutz: Titel der Aufgaben gehen nicht in die Antwort, nur `orderID` und `state`.
- Regeln vor Modell: reine Regel und SQL.

## Analysis

### Type
Feature (Schnitt C4b-2 von #613; `Refs #613`, nie `Closes`).

### Befund aus dem Code (gelesen, nicht vermutet)
- `server/src/mcp.ts` hat `capturing(pool)` als Muster: Konto aus `authInfo` → Eingabe prüfen → Auftrag bauen → `checkOrder` → `putOrder` → `{orderID, state:"waiting"}`. Zwei neue Werkzeuge gleichen Bauplans passen ohne Umbau hinein.
- `server/src/orders.ts` kennt `complete` und `setDue` bereits in `Order` und `forms`; `checkOrder` prüft Form, `expectedStatus` lässt alle sechs Status durch. **Keine Änderung nötig.**
- `getTranscript(pool, account)` liefert `tasks[]` mit `status` (nur offen/geparkt) und `dueDate?`; Ids stehen in Großbuchstaben (UUID). Das ist die einzige Quelle des erwarteten Stands.
- Vertrag (`claude-abschrift-vertrag.md`, Z. 85–104): `complete` braucht `taskID`, `expectedStatus`, `expectedDueDate`; `setDue` braucht `taskID`, `hasTime`, `date?`, `expectedDueDate?`; fehlendes `expectedDueDate` heißt „keine Fälligkeit“.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/mcp.ts` | MODIFY | `completing(pool)` und `setting(pool)` samt gemeinsamem Helfer `expected(doc, taskID)`; zwei `registerTool`-Aufrufe, ~+45 |
| `server/test/mcp.test.ts` | MODIFY | beide Werkzeuge über den Prozess-Client; Werkzeugliste (AC-3) wird sechs, ~+120 |
| `CLAUDE.md` | MODIFY | `server/`-Zeile um `complete_task`, `set_due` ergänzen, ~+1 |

`server/src/orders.ts`, `transcripts.ts`, Migrationen, `package.json`, `project.yml` und jede Swift-Datei bleiben unberührt.

### Scope Assessment
- Files: 3 (Limit 4–5)
- Estimated LoC: +≈165/−≈3 (Code ≈ 45, Tests ≈ 120); unter 250
- Risk Level: LOW — isolierter Bereich, nichts ruft `mcpHandler` auf (C7), die App holt noch keine Aufträge; keine Migration, kein Schema.

### Technical Approach (Regel, kein Modell)
Ohne Modell geht es nicht? Die Frage stellt sich nicht: es gibt keine Sprachaufgabe, nur Nachschlagen in der Abschrift, Auftrag bauen, speichern.

1. Gemeinsamer Helfer `expected(doc, taskID)`: sucht die Aufgabe in `doc.tasks` (Id ohne Rücksicht auf Groß-/Kleinschreibung), liefert `{id, status, dueDate?}` oder `undefined`.
2. Reihenfolge je Werkzeug wie bei `capturing`: Konto prüfen („kein Konto“) → Abschrift holen („noch keine Abschrift“, `isError`) → Aufgabe suchen („Aufgabe nicht in der Abschrift“, `isError`) → Auftrag bauen (Kennung `randomUUID().toUpperCase()`, `taskID` = Id **aus der Abschrift**) → `checkOrder` (Meldung unverändert zurück) → `putOrder` → `{orderID, state:"waiting"}`.
3. `complete_task`: Eingabe `taskID`; `expectedStatus` = `status`, `expectedDueDate` nur wenn die Abschrift eine Fälligkeit führt (Schlüssel bleibt sonst weg).
4. `set_due`: Eingabe `taskID`, `date?` (ISO 8601 mit Zone; fehlt = Fälligkeit entfernen), `hasTime?` (fehlt = false; ohne `date` immer false); `expectedDueDate` wie oben. Schemafehler von Zod kämen als JSON-RPC-Fehler ohne `isError`, deshalb Zod nur `z.string()`/`z.boolean()` und die Formprüfung bei `checkOrder` (Muster C4a/C4b-1).
5. Annotationen: `readOnlyHint` falsch, `destructiveHint` falsch (alles über Revisionen), `idempotentHint` falsch bei beiden (`complete_task` rollt wiederkehrende weiter; ein zweiter `set_due` legt einen zweiten Auftrag an). Beschreibung beider Werkzeuge: zuerst `list_tasks` lesen, Stand über `get_order_result`.
6. Antwort enthält nur `orderID` und `state`, nie Titel; nichts nach `console`/`stdout`.

### Befunde, die gegen den Plan sprechen
- **Veraltete Sicht (echtes Loch im Entwurf).** Der Dienst nimmt den erwarteten Stand aus der *neuesten* Abschrift beim Aufruf, nicht aus der, die Claude vorher gelesen hat. Liest Claude `list_tasks` (Fälligkeit Montag), das Gerät lädt danach eine neue Abschrift (Fälligkeit Dienstag), und Claude ruft dann `set_due`, bekommt der Auftrag „Dienstag“ als erwarteten Stand — das Gerät lässt ihn durch, obwohl Claude auf Basis von „Montag“ entschieden hat. Die Absicherung `stale` greift dann nicht gegen Claudes Sicht, nur gegen die Lücke zwischen Abschrift und Gerät.
  - **Empfehlung:** Beide Werkzeuge nehmen zusätzlich `generatedAt` (steht in der Antwort von `list_tasks` und `get_now`); weicht es von der gespeicherten Abschrift ab, Werkzeugfehler „Abschrift hat sich geändert, bitte neu lesen“, kein Auftrag. ~+6 Zeilen Code, +2 Tests. Das ändert nicht den Grundsatz „Dienst liefert den erwarteten Stand“, es schließt nur die Lücke.
- Sonst keine: Mess- oder Variantenvergleich entfällt (keine Modellfrage).

### Alternativen (bewusst benannt)
- **A: Claude übergibt den erwarteten Stand selbst** (`expectedStatus`, `expectedDueDate` als Eingabe). Ehrlicher gegenüber dem, was Claude sah, braucht kein `generatedAt`; aber Claude muss Felder korrekt abschreiben und kann sie falsch melden, und die Werkzeug-Oberfläche wird sperrig. Würde die Entscheidung aus dem Vorgänger-Kontext („Erwarteter Stand kommt vom Dienst“) kippen.
- **B: ein einziges Werkzeug `change_task`** mit `kind`. Weniger Registrierungen, aber Claude bekäme eine Union-Eingabe mit Pflichtfeldern je Art; zwei klar benannte Werkzeuge lesen sich für ein Modell besser und tragen eigene Annotationen.
- **C (gewählt, mit Ergänzung):** Dienst liest den Stand, Claude bestätigt mit `generatedAt`, dass es denselben meint.

### Dependencies
- Upstream: `getTranscript`, `putOrder`, `checkOrder`, `zod`, `node:crypto`; keine neuen Pakete.
- Downstream: niemand (C7 hängt den Handler an einen Port, C6 die Anmeldung, ein Gerätekanal holt Aufträge ab).

### Risks
- Branchname `feat-613-c4b-mcp-schreiben` wurde schon für C4b-1 benutzt (PR #805 gemergt): vor dem Bau von aktuellem `origin/main` ausgehen, nicht auf dem alten Zweigstand aufbauen.
- Ausführung auf dem Gerät (`OrderExecutor`) bleibt ungeprüft durch diesen Schnitt; die Werkzeuge beweisen nur, dass ein formgerechter Auftrag mit erwartetem Stand entsteht.
- Kein Pfad der Geräteliste berührt (nur `server/` und `CLAUDE.md`).

### Open Questions
- [ ] `generatedAt` als Pflichteingabe beider Werkzeuge (Empfehlung) oder weglassen und die Lücke offen lassen? Technische Entscheidung, Claude entscheidet in der Spec: Pflichteingabe.
- [ ] `complete_task` für eine Aufgabe, die die Abschrift nicht führt (z. B. schon erledigt): „Aufgabe nicht in der Abschrift“, kein Auftrag (aus dem Vorgänger-Kontext übernommen, keine Rückfrage nötig).
