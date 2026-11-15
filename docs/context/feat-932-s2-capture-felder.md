# Context: feat-932-s2-capture-felder

## Request Summary
#932 Schnitt 2 (Dienst): `capture_task` nimmt optionale Angaben (`fields`) an, der Dienst prüft deren Form und speichert sie im
Auftrag `capture`. Die App kennt `fields` seit Schnitt 1 (PR #934); `update`/`update_task` folgt in Schnitt 3.
Gesamtanalyse und Alternativen: `docs/context/feat-932-claude-felder.md`; Vertrag: `docs/reference/claude-abschrift-vertrag.md`
(Abschnitt „Auftrag“, Beispiel `capture` mit `fields` als ` ```jsonc`).

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/orders.ts` | `Order`-Typ, `forms.capture = [{ text }, {}]` → optional `fields` mit eigener Form |
| `server/src/transcripts.ts` | Bausteine `shape`, `text`, `time`, `flag`, `list`, `fail`; `names` (Textliste) ist intern, nicht exportiert |
| `server/src/mcp.ts` | `capturing()` baut den Auftrag aus `{ text }`; `registerOrders` → `capture_task` zod-Schema `{ text }` |
| `server/test/orders.test.ts` | Formtests je Art (AC-5 Z4 capture: fehlender/falscher Text, fremder Schlüssel) |
| `server/test/mcp.test.ts` | `capture_task` speichert einen Auftrag je Aufruf; Werkzeugliste |
| `server/test/schema.test.ts` | liest genau drei ` ```json`-Blöcke aus dem Vertrag; die ` ```jsonc`-Beispiele prüft bisher nur Swift |
| `server/src/anleitung.ts` | 1311 Byte von 2048; Erfassen „mit seinem Wortlaut, unverändert“ |
| `docs/reference/claude-abschrift-vertrag.md` | Zeile 122f: „Der Dienst nimmt `fields` erst ab #932 Schnitt 2 … an“ → anpassen |

## Existing Patterns
- Dienst prüft nur Form (Schlüssel, Typen, Wertemengen), Bedeutung (Namen vorhanden, Titel nicht leer nach Kürzen) prüft die App
  und antwortet `invalid`.
- Formfehler: `checkOrder` wirft `Auftrag ungültig: <pfad> <grund>`; `storeOrder` gibt die Meldung an Claude zurück.
- Wertemengen per `oneOf(values, reason)` in `orders.ts`.
- Tests lesen Vertragsbeispiele wörtlich; neue Beispiele stehen als ` ```jsonc`, damit die Dreier-Zählung bleibt.

## Dependencies
- Upstream: zod (MCP-SDK) für das Eingabeschema, `checkOrder` als eigentliche Prüfung.
- Downstream: App `OrderExecutor` (Schnitt 1) dekodiert `fields`; `ClaudeSync` holt Aufträge ab; Weckruf nach `storeOrder`.

## Existing Specs
- `docs/specs/feat-932-schnitt-1-app.md` (Schnittplan S1–S3, Form von `fields`)

## Risks & Considerations
- **Reihenfolge der Auslieferung:** Eine App ohne Schnitt 1 ignoriert `fields` still (Codable) und meldet `done`. Ausrollen des
  Dienstes erst, wenn Hennings Testbau (konto an) Schnitt 1 enthält; vorher prüfen, welcher Bau aktuell ist.
- **Form doppelt beschrieben:** zod-Schema am Werkzeug und `checkOrder`; zod nur grob (Objekt mit optionalen Schlüsseln),
  die genaue Prüfung bleibt `checkOrder`, damit es eine Wahrheit gibt.
- `dueDate` und `dueHasTime` nur gemeinsam (Vertrag); `energy` ganze Zahl −3…3; `title` als Text (leer → App `invalid`);
  `notes` nur bei `capture`; `contexts` Textliste (leer erlaubt), `project` Text.
- Leeres `fields`-Objekt beim Erfassen: Vertrag verbietet leeres `fields` nur bei `update`; bei `capture` harmlos.
- Server-Test für das ` ```jsonc`-Beispiel `capture` ergänzen (Spec S1: „Die Serverstests prüfen sie in S2/S3“).
- Anleitung: ob Claude beim Erfassen Angaben mitgeben soll und wann, ist Teil von S3 (Anleitung dort gesamt); S2 nur die
  Werkzeugbeschreibung.

## Analysis

### Type
Feature (#932 Schnitt 2 von 3, nur Dienst; nicht ausgerollt — Testbau mit Schnitt 1 und Ausrollen sind Teil von Schnitt 3).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/orders.ts` | MODIFY | `Order`-Typ `capture` + `fields?`; Prüfbaustein `captureFields`: `shape(v, p, {}, { title: text, notes: text, dueDate: time, dueHasTime: flag, importance, urgency, duration, energy, contexts: names, project: text })`, Wertemengen per `oneOf`, `energy` ganze Zahl −3…3, `dueDate`/`dueHasTime` nur gemeinsam (Form, Pfad `fields.dueHasTime`); `forms.capture = [{ text }, { fields: captureFields }]`. Für S3 als Fabrik `fieldsCheck(withNotes)` angelegt, nur `capture` benutzt |
| `server/src/transcripts.ts` | MODIFY | `names` in die Exportzeile (eine Zeile) |
| `server/src/mcp.ts` | MODIFY | `capture_task`: zod `fields` optional, Schlüssel und Wertemengen sichtbar für Claude, `.strict()` (zod streicht sonst unbekannte Schlüssel still, ein Tippfehler „titel“ ginge verloren); `capturing` legt `fields` nur bei Angabe in den Auftrag; Beschreibung nennt Rohtext unverändert, Angaben optional, Namen nur vorhandener Tags/Projekte |
| `server/test/orders.test.ts` | MODIFY | Formtests je Schlüssel (Typ, Wertemenge, Energie 4 / 1.5, Paar Datum/Uhrzeit, fremder Schlüssel in `fields`, `fields` kein Objekt), leeres `fields` bei `capture` erlaubt; das ` ```jsonc`-Beispiel `capture` aus dem Vertrag besteht `checkOrder` (eigener Regex auf `jsonc`, Dreier-Zählung bleibt) |
| `server/test/mcp.test.ts` | MODIFY | `capture_task` mit `fields` speichert sie unverändert im Auftrag; ohne `fields` kein Schlüssel; unbekannter Schlüssel und falscher Wert werden abgewiesen, nichts gespeichert; zod-Schlüssel = Schlüssel von `captureFields` |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Satz Z. 122f: Dienst nimmt `fields` an `capture` ab Schnitt 2 an, `update` ab Schnitt 3; Kopfsatz „Server liest …“ um die `jsonc`-Prüfung ergänzen |

### Scope Assessment
- Files: 6 (davon `transcripts.ts` eine Exportzeile)
- Estimated LoC: Produkt +45/−5, Tests +110, Doku +3 → ≈ 165, unter ±250
- Risk Level: LOW — Dienst nur erweitert, ohne `fields` bleibt jeder Auftrag Zeichen für Zeichen wie heute; nicht ausgerollt bis S3

### Technical Approach
Eine Wahrheit für die Form: `checkOrder` prüft `fields` vollständig (wie alle Arten). zod am Werkzeug beschreibt dieselben Schlüssel
und Wertemengen, damit Claude sie im Werkzeugschema sieht, und ist `.strict()`; ein Test hält die Schlüsselmengen gleich, damit beide
nicht auseinanderlaufen. Bedeutung (Name vorhanden, Titel nach Kürzen nicht leer) bleibt Sache der App (`invalid`), wie bei jeder Art.
Kein Modell, kein Sprachverstehen: reine Formprüfung (Regeln vor Modell erfüllt, kein Modellaufruf).

### Alternatives
- **zod nur grob (`record<string, unknown>`), Schlüssel nur in der Beschreibung:** eine Stelle weniger, aber Claude sieht Wertemengen
  nur als Fließtext und ruft öfter falsch auf. Verworfen wegen schlechterer Aufrufe; kein ADR betroffen.
- **Kein `fields` beim Erfassen, nur Erfassen + `update_task` (S3):** Claude kennt die `taskID` erst nach dem Geräte-Ergebnis, also zwei
  Runden und ein Zwischenzustand mit Regeltitel. Fiele die Entscheidung aus Spec S1 (Schnittplan, `fields` an `capture`).
- **Prüfung nur in der App:** Dienst reicht `fields` ungeprüft durch; widerspricht Vertrag C3b („je Art genau die Felder, kein weiterer
  Schlüssel“).

### Dependencies
zod (MCP-SDK) für das Eingabeschema; `checkOrder`/`shape`/`oneOf`; App `OrderExecutor` (S1, gemergt PR #934) dekodiert `fields`.

### Open Questions
- keine PO-Frage: rein technischer Schnitt, keine sichtbare Änderung, Limits eingehalten. Ausrollreihenfolge (Testbau mit S1 vor Dienst)
  ist in S3 eingeplant.
