---
entity_id: feat-932-schnitt-2-dienst
type: feature
created: 2026-11-15
updated: 2026-11-15
status: draft
workflow: feat-932-s2-capture-felder
---

# Spec: Claude setzt Titel und Angaben, Schnitt 2 (Dienst, Erfassen mit Feldern, #932)

## Approval

- [ ] Approved

## GitHub Issue

#932 (Epic #612). Schnitt 2 von 3; das Issue bleibt offen (PR mit `Refs #932`, nie `Closes #932`), weil Schnitt 3 und der claude.ai-Durchlauf aus der Definition of Done von #932 offen bleiben.
Analyse: `docs/context/feat-932-s2-capture-felder.md` (Abschnitt „Analysis“), Gesamtanalyse `docs/context/feat-932-claude-felder.md`. Vorgänger: Schnitt 1 (App, `docs/specs/feat-932-schnitt-1-app.md`, PR #934, gemergt).

## Purpose

Der Dienst nimmt beim Werkzeug `capture_task` ab jetzt optional ein Objekt `fields` an (Titel, Notiz, Fälligkeit, Wichtigkeit, Dringlichkeit, Dauer, Energie, Tags, Projekt), prüft dessen Form und speichert es im Auftrag `capture`, damit die App (Schnitt 1) die Werte beim Erfassen auf die neue Aufgabe setzen kann. Ohne `fields` bleibt jeder Auftrag Zeichen für Zeichen wie heute.

**Regeln vor Modell:** reine Formprüfung (Schlüssel, Typen, Wertemengen), kein Modellaufruf, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- **Schnitt 3:** `update`/`update_task` (neue Art, erwartete Werte, Migration 009), die Anleitung (`server/src/anleitung.ts`, ob und wann Claude Angaben mitgibt), Testbau mit `konto` an, Ausrollen, claude.ai-Durchlauf.
- **Nicht ausgerollt:** Dieser Schnitt wird gemergt, aber nicht auf `rennwienix` ausgerollt. Grund: Eine App ohne Schnitt 1 ignoriert `fields` still und meldet `done`. Ausgerollt wird in Schnitt 3, wenn Hennings Testbau Schnitt 1 enthält.
- **Bedeutung prüft die App, nicht der Dienst:** vorhandene Tag- und Projektnamen, Titel nach Kürzen nicht leer. Die App antwortet `invalid` (Schnitt 1). Der Dienst reicht solche Werte durch, wie er `expectedStatus` `done` heute durchreicht.
- Keine Änderung an Abschrift, App, Migrationen oder Anleitung. Version bleibt 1.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — der Auftragsweg (ADR-21, Weg B) bleibt; ein optionales Objekt im bestehenden Auftrag derselben Version, ohne Schemawechsel (der Auftrag liegt als JSON-Dokument in der Datenbank, keine Migration).

## Source

**Files:** `server/src/orders.ts`, `server/src/transcripts.ts`, `server/src/mcp.ts`, `server/test/orders.test.ts`, `server/test/mcp.test.ts`, `docs/reference/claude-abschrift-vertrag.md`
**Identifier:** `forms.capture`, `captureFields`, `checkOrder`, `capturing`, Werkzeug `capture_task`

## Implementation Details

### Form von `fields` bei `capture`

`fields` ist optional. Fehlt es, ist der gespeicherte Auftrag byte-gleich zu heute (kein Schlüssel `fields`). Ist es da, muss es ein Objekt sein; ein leeres Objekt ist bei `capture` erlaubt (der Vertrag verbietet leeres `fields` nur bei `update`). Jeder Schlüssel ist optional, ein fremder Schlüssel ist ein Formfehler mit Pfad (`Auftrag ungültig: fields.<schlüssel> …`):

| Schlüssel | Form |
|---|---|
| `title` | Text (leer oder nach Kürzen leer: Sache der App) |
| `notes` | Text (nur bei `capture` erlaubt) |
| `dueDate` | Zeitstempel (wie `date` bei `setDue`) |
| `dueHasTime` | Bool; mit `dueDate` nur gemeinsam, eines allein ist ein Formfehler mit Pfad `fields.dueHasTime` bzw. `fields.dueDate` |
| `importance`, `urgency` | `low`, `medium`, `high` |
| `duration` | `minutes5`, `minutes15`, `minutes30`, `hour1`, `hours2plus` |
| `energy` | ganze Zahl von −3 bis 3 (4, −4 und 1.5 sind Formfehler) |
| `contexts` | Liste von Texten, leere Liste erlaubt |
| `project` | Text |

`fields` kein Objekt (Zahl, Text, Liste, `null`) ist ein Formfehler mit Pfad `fields`.

### Eine Wahrheit für die Form

`checkOrder` in `server/src/orders.ts` prüft `fields` vollständig, wie jede Art: `Order`-Typ `capture` bekommt `fields?`; ein Baustein `captureFields` (mit `shape` aus `transcripts.ts`, Wertemengen per `oneOf`, Energie als ganze Zahl −3…3, Paar `dueDate`/`dueHasTime`) wird in `forms.capture` als optionales Feld eingehängt (`[{ text }, { fields: captureFields }]`). Für Schnitt 3 wird er als Fabrik `fieldsCheck(withNotes)` angelegt, S2 benutzt nur `capture` (mit Notiz). `transcripts.ts` exportiert dafür `names` (die Textliste), eine Exportzeile.

Das zod-Schema von `capture_task` in `server/src/mcp.ts` beschreibt dieselben Schlüssel und Wertemengen, damit Claude sie im Werkzeugschema sieht, und ist `.strict()`: zod streicht unbekannte Schlüssel sonst still, ein Tippfehler wie „titel“ ginge verloren. Die eigentliche Prüfung bleibt `checkOrder`. Ein Test hält die Schlüsselmengen von zod und `captureFields` gleich. `capturing` legt `fields` nur bei Angabe in den Auftrag. Die Werkzeugbeschreibung nennt: Rohtext unverändert, Angaben optional, Tags und Projekt nur mit Namen, die es schon gibt.

### Vertrag

`docs/reference/claude-abschrift-vertrag.md`: der Satz in den Zeilen 122f („Der Dienst nimmt `fields` erst ab #932 Schnitt 2 und `update` erst ab Schnitt 3 an …“) wird: Der Dienst nimmt `fields` an `capture` ab #932 Schnitt 2 an, `update` erst ab Schnitt 3; bis dahin verwirft er `update` (unbekannte Art). Der Kopfsatz „Server liest die Beispiele“ nennt zusätzlich: die drei ` ```json`-Blöcke und das ` ```jsonc`-Beispiel `capture`; das Beispiel `update` prüft der Server ab Schnitt 3. Die Dreier-Zählung der ` ```json`-Blöcke bleibt (mehrere Testdateien zählen sie), die drei Blöcke bleiben Zeichen für Zeichen; der Test für das Beispiel `capture` liest den `jsonc`-Block mit eigenem Muster.

## Dependencies

| Entität | Art | Zweck |
|---|---|---|
| `server/src/transcripts.ts` | bestehend, eine Exportzeile | Bausteine `shape`, `text`, `time`, `flag`, `list`, `fail`; `names` wird exportiert |
| `server/src/orders.ts` | bestehend | `checkOrder`, `oneOf`, `forms` |
| zod (MCP-SDK) | bestehend | Eingabeschema von `capture_task`, `.strict()` |
| `docs/reference/claude-abschrift-vertrag.md` | bestehend | Abschnitt „Auftrag“, Beispiel `capture` mit `fields` (Schnitt 1) |
| `Shared/Services/OrderExecutor.swift` (App, Schnitt 1) | bestehend, unverändert | dekodiert und führt `fields` aus |
| `server/src/anleitung.ts` | bestehend, unverändert | 1311 von 2048 Byte; Anpassung in Schnitt 3 |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung | LoC |
|---|---|---|---|
| `server/src/orders.ts` | MODIFY | `Order` + `fields?`, `captureFields`/`fieldsCheck`, `forms.capture` | +30/-3 |
| `server/src/transcripts.ts` | MODIFY | `names` in die Exportzeile | +1/-1 |
| `server/src/mcp.ts` | MODIFY | zod `fields` strict, `capturing`, Beschreibung | +14/-1 |
| `server/test/orders.test.ts` | MODIFY | Formtests je Schlüssel, Vertragsbeispiel `capture` | +65 |
| `server/test/mcp.test.ts` | MODIFY | `capture_task` mit/ohne `fields`, Abweisungen, Schlüsselgleichheit | +45 |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Satz Z. 122f, Kopfsatz | +3/-2 |

### Estimated Changes

- Files: 6 (Produktcode 3, Tests 2, Vertrag 1).
- LoC: etwa +165 (Produkt +45/−5, Tests +110, Doku +3), unter ±250.
- **Dateigrenze:** 6 Dateien liegen über 4–5; `server/src/transcripts.ts` ist nur eine Exportzeile, ohne sie 5 Dateien. Teilen brächte nichts, die Zeile gehört untrennbar zum Baustein.

## Test Plan

### Automated Tests (TDD RED)

XCTest-Pflicht des QA-Gates gilt für Swift; hier laufen die Tests des Dienstes (`node:test`) über `./server/scripts/test-local.sh`.

- [ ] Test 1: GIVEN ein `capture` mit `fields` aus allen Schlüsseln in gültiger Form WHEN `checkOrder` THEN kein Fehler; GIVEN ein leeres `fields` THEN ebenfalls kein Fehler.
- [ ] Test 2: GIVEN `fields` mit je einem falschen Wert (`importance` „urgent“, `urgency` 1, `duration` „hour3“, `energy` 4, −4 und 1.5, `dueDate` ohne `dueHasTime`, `dueHasTime` ohne `dueDate`, `contexts` kein Array oder mit Zahl, `project` Zahl, `title` Zahl) WHEN `checkOrder` THEN je ein Fehler `Auftrag ungültig:` mit dem Pfad `fields.<schlüssel>`.
- [ ] Test 3: GIVEN `fields` mit fremdem Schlüssel (`titel`) und `fields` als Zahl, Text, Liste und `null` WHEN `checkOrder` THEN Formfehler mit Pfad `fields.titel` bzw. `fields`.
- [ ] Test 4: GIVEN das ` ```jsonc`-Beispiel `capture` aus dem Vertrag WHEN gelesen und mit `checkOrder` geprüft THEN besteht; GIVEN die ` ```json`-Zählung der Testdateien THEN weiterhin genau drei Blöcke.
- [ ] Test 5: GIVEN ein Aufruf `capture_task` mit `fields` WHEN der Auftrag gespeichert wird THEN steht `fields` unverändert im gespeicherten Auftrag; GIVEN ein Aufruf ohne `fields` THEN der gespeicherte Auftrag hat keinen Schlüssel `fields` und ist byte-gleich zu dem vor der Änderung.
- [ ] Test 6: GIVEN ein Aufruf `capture_task` mit unbekanntem Schlüssel in `fields` oder mit einem falschen Wert WHEN ausgeführt THEN wird er abgewiesen und es entsteht kein Auftrag in der Datenbank.
- [ ] Test 7: GIVEN das zod-Schema von `capture_task` und `captureFields` WHEN die Schlüsselmengen verglichen werden THEN sind sie gleich.
- [ ] Test 8: GIVEN die bestehenden Tests (Formtests aller Arten, `capture_task` ohne `fields`, Werkzeugliste, Anleitung ≤ 2048 Byte) WHEN der Lauf THEN unverändert grün.

### Abnahme

Stufe 1: neue Tests rot vor, grün nach der Umsetzung; `./server/scripts/test-local.sh` grün (Typprüfung und alle Dienst-Tests gegen die Wegwerf-Datenbank).
Stufe 2: Es gibt keine sichtbare Oberfläche und keine App-Änderung; der Ablauf „Aufruf des Werkzeugs → gespeicherter Auftrag“ wird im Test über den echten MCP-Handler und die echte Datenbank durchlaufen (Test 5, 6). Das wird im Abschlussbericht so benannt.
Stufe 3: Kein Pfad der Geräteliste berührt. Geprüft gegen die Tabelle in `CLAUDE.md`: nur `server/` und `docs/`.

## Acceptance Criteria

- **AC-1:** `checkOrder` nimmt ein `capture` mit `fields` aus beliebigen der Schlüssel `title`, `notes`, `dueDate` (mit `dueHasTime`), `importance`, `urgency`, `duration`, `energy`, `contexts`, `project` in gültiger Form an, ebenso ein leeres `fields` (Test 1).
- **AC-2:** `checkOrder` weist je Schlüssel einen Wert in falscher Form oder außerhalb der Wertemenge mit `Auftrag ungültig: fields.<schlüssel> …` ab, darunter Energie 4, −4 und 1.5 sowie `dueDate` ohne `dueHasTime` und umgekehrt (Test 2).
- **AC-3:** Ein fremder Schlüssel in `fields` und ein `fields`, das kein Objekt ist, werden als Formfehler mit Pfad abgewiesen (Test 3).
- **AC-4:** Das ` ```jsonc`-Beispiel `capture` des Vertrags besteht `checkOrder`; der Vertrag enthält weiter genau drei ` ```json`-Blöcke unverändert an derselben Stelle (Test 4, Test 8).
- **AC-5:** `capture_task` mit `fields` speichert sie unverändert im Auftrag; ohne `fields` hat der gespeicherte Auftrag keinen Schlüssel `fields` und ist byte-gleich zu heute (Test 5).
- **AC-6:** `capture_task` mit unbekanntem Schlüssel oder falschem Wert in `fields` wird abgewiesen, ohne dass ein Auftrag gespeichert wird (Test 6).
- **AC-7:** Das zod-Schema von `capture_task` ist `.strict()` und hat genau die Schlüssel von `captureFields`; ein Test hält beide gleich (Test 7).
- **AC-8:** Der Dienst prüft nur die Form: kein Abgleich mit Katalogen, kein Titel-Kürzen, kein Modellaufruf; der Vertragssatz zu `fields` und `update` ist auf den Stand Schnitt 2 gebracht (Prüfung im Review, Satz im Vertrag).
- **AC-9:** `./server/scripts/test-local.sh` ist grün; App, Migrationen und `anleitung.ts` sind unverändert, die Anleitung bleibt ≤ 2048 Byte (Test 8).

## Definition of Done

- [ ] Neue Tests aus dem Test Plan rot vor der Umsetzung, grün danach; `./server/scripts/test-local.sh` grün
- [ ] Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“ und dem Hinweis „nicht ausgerollt, Ausrollen in Schnitt 3“
- [ ] Ausgeliefert per PR mit `Refs #932`, CI grün, gemergt; #932 bleibt offen (Schnitt 3, claude.ai-Durchlauf)

## Alternativen

- **zod nur grob (`record<string, unknown>`), Schlüssel nur in der Beschreibung:** eine Stelle weniger, aber Claude sähe die Wertemengen nur als Fließtext und riefe öfter falsch auf. Verworfen; keine ADR fällt.
- **Kein `fields` beim Erfassen, nur Erfassen plus `update_task` (Schnitt 3):** Claude kennt die `taskID` erst nach dem Geräte-Ergebnis, also zwei Runden und ein Zwischenzustand mit Regeltitel. Fiele: die Festlegung des Schnittplans aus Spec S1 (`fields` an `capture`).
- **Prüfung nur in der App, Dienst reicht `fields` ungeprüft durch:** widerspricht dem Vertrag (C3b: je Art genau die Felder, kein weiterer Schlüssel) und ließe Claude Formfehler erst Minuten später als `rejected/invalid` erfahren. Fiele: Vertrag C3b.
- **Regelweg statt Felder** (Angaben in den Erfassungstext schreiben): verworfen in Spec S1 (Rohtext bleibt Hennings Wortlaut, ADR-3, Anleitung #623).

## Risiken

- **Auslieferungsreihenfolge:** Eine App ohne Schnitt 1 ignoriert `fields` still und meldet `done`. Gegenmittel: dieser Schnitt wird nicht ausgerollt; Ausrollen erst in Schnitt 3, nach Prüfung, dass Hennings Testbau Schnitt 1 enthält.
- **Form doppelt beschrieben (zod und `checkOrder`):** zod ist nur die Sicht für Claude, `checkOrder` die Wahrheit; der Schlüsselgleichheitstest fängt Auseinanderlaufen ab, Wertemengen halten beide aus denselben Konstanten, soweit zod das zulässt.
- **Test-Kopplung des Vertrags:** das Beispiel steht als ` ```jsonc`, damit die Dreier-Zählung bleibt; wer die Kennzeichnung ändert, bricht mehrere Testdateien laut.

## Changelog

- 2026-11-15: Erste Fassung (Schnitt 2, Dienst).
