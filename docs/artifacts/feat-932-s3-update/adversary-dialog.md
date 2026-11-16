# Adversary Dialog — feat-932-s3-update
Spec: docs/specs/feat-932-schnitt-3-update.md
Datum: 2026-11-16 06:51

## Checkliste
- [x] **AC-1:** Migration 009 wird einmal angewendet (`schema_migrations`) und erlaubt `update` in `orders.kind`; eine unbekannte Art verletzt weiter `orders_kind_known`; die Migrationslisten in `accounts.test.ts` und `schema.test.ts` enthalten sie (Test 1).
- [x] **AC-2:** `checkOrder` nimmt das Vertragsbeispiel `update` aus dem ` ```jsonc`-Block an, der Test liest es aus dem Vertrag (Test 2).
- [x] **AC-3:** `checkOrder` weist ein `update` mit leerem `fields`, mit `notes` in `fields`, ohne `expectedStatus` und ohne `taskID` mit `Auftrag ungültig: <pfad> …` ab (Test 3).
- [x] **AC-4:** `update_task` setzt `expectedStatus` immer und `expectedTitle`, `expectedDueDate`, `expectedContexts`, `expectedProject` nur, wenn das Feld in `fields` steht und die Abschriftzeile einen (bei Tags: nicht leeren) Wert hat; ohne Wert fehlt der Schlüssel (Test 4, 5).
- [x] **AC-5:** `update_task` weist unbekannten Schlüssel, `notes`, leeres `fields` und falsche Werte ab, ohne dass ein Auftrag entsteht (Test 6).
- [x] **AC-6:** `update_task` lehnt unbekannte Aufgabe, fehlende Abschrift, verändertes `generatedAt` und fehlendes Konto mit denselben Texten ab wie die anderen Schreibwerkzeuge, ohne Auftrag (Test 7).
- [x] **AC-7:** Das zod-Schema von `update_task` ist `.strict()` und hat für `fields` genau die Schlüssel von `captureFields` ohne `notes` (Test 9).
- [x] **AC-8:** Nach einem neu gespeicherten `update`-Auftrag werden die Geräte des Kontos einmal geweckt, bei einer Abweisung nicht (Test 8).
- [x] **AC-9:** Die Anleitung nennt `update_task` mit „erst nach dem Ja des Nutzers“, bleibt ≤ 2048 Byte, und der Werkzeugnamen-Test bleibt grün (Test 10).
- [x] **AC-10:** Vertrag (Zeile 10 und Zeilen 123f) und `CLAUDE.md` (`mcp.ts`-Zeile) sind auf den Stand Schnitt 3 gebracht; `./server/scripts/test-local.sh` ist grün, die bestehenden Tests laufen unverändert (Test 11, Prüfung im Review).

## Dialog

### Runde 1
**Adversary:** Beweis je AC verlangt, nicht geglaubt. Volllauf `./server/scripts/test-local.sh` selbst gestartet (docs/artifacts/feat-932-s3-update/adversary-test-output.txt): Exit 0, 458 pass, 0 fail, 0 skipped, Typprüfung grün. Danach je AC den Codepfad gelesen.

Confirmation:
  AC: AC-1
  Code reference: server/migrations/009_order_update.sql:5
  Evidence: DO-Block mit SELECT INTO STRICT findet genau den alten CHECK (LIKE '%capture%') und löscht ihn, ADD CONSTRAINT orders_kind_known kennt 'update'; kein BEGIN/COMMIT. Läuft im Volllauf gegen die Wegwerf-Datenbank (STRICT hätte sonst abgebrochen). Bestehende Aufträge: ADD CONSTRAINT prüft sie, die neue Liste ist Obermenge der alten, also kein Konflikt.
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: server/test/accounts.test.ts:66
  Evidence: Migrationsliste enthält 009_order_update.sql; Gegenstück server/test/schema.test.ts:61 ebenso. Test AC-1 in server/test/orders.test.ts:364 prüft schema_migrations-Zeile, INSERT update gelingt, Art "rename" verletzt orders_kind_known.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/test/orders.test.ts:373
  Evidence: updateExample() (Zeile 354) liest das jsonc-Beispiel kind update aus dem Vertrag, checkOrder nimmt es an; Test grün im Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/orders.ts:63
  Evidence: updateFields prüft zuerst "leer" (Objekt ohne Schlüssel), dann fieldsCheck(false); forms.update (orders.ts:75) macht taskID, expectedStatus, fields Pflicht. Eigene Probe per Wegwerfskript: null/[] -> "fields: kein Objekt", {} -> "fields: leer, mindestens ein Feld", {notes} -> "fields.notes: unbekannter Schlüssel", {dueHasTime} allein -> "fields.dueDate: fehlt", {energy:4} abgewiesen; {contexts:[]}, {title:""} formal ok (Bedeutung ist App-Sache laut Spec). Tabelle in server/test/orders.test.ts:387-401 deckt zusätzlich fehlendes taskID/expectedStatus/fields und Fremdschlüssel (text) ab.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/mcp.ts:188
  Evidence: updating(): expectedStatus immer; expectedTitle nur bei has("title"); expectedDueDate nur bei dueDate-Schlüssel und Zeilenwert; expectedContexts nur bei contexts-Schlüssel und nicht leerer Tagliste; expectedProject nur bei project-Schlüssel und Zeilenwert (Object.hasOwn). Nur importance -> nur expectedStatus (Test server/test/mcp-write.test.ts:198 "quiet"). contexts:[] bei Zeile mit Tags -> expectedContexts = Tags der Zeile (richtig, ändert Tags weg). project bei Zeile ohne Projekt -> Schlüssel fehlt (mcp-write.test.ts:198, bare()). dueHasTime ohne dueDate -> checkOrder in storeOrder lehnt ab. Target-Erweiterung mcp.ts:88/101-108; die anderen Handler (mcp.ts:132,145,157,168,178) destrukturieren nur ihre alten Felder, ihre Aufträge bleiben byte-gleich; Tests mcp.test.ts/mcp-write.test.ts unverändert grün.
  Status: CONFIRMED

### Runde 2
**Adversary:** Nachbohren an Randfällen und Kopplungen.

Confirmation:
  AC: AC-5
  Code reference: server/src/mcp.ts:296
  Evidence: updateFieldsSchema = captureFieldsSchema.omit({notes}).strict(); zod streicht daher kein "titel" still. Test mcp-write.test.ts:215 weist titel, notes, {}, importance "urgent", energy 4, dueDate ohne dueHasTime und fehlendes fields ab und prüft 0 Aufträge. Doppelt abgesichert durch checkOrder in storeOrder.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/mcp.ts:101
  Evidence: expected() bleibt die einzige Stelle der Ablehnungstexte; Groß-/Kleinschreibung der taskID wird per toUpperCase verglichen und der Auftrag trägt die ID der Abschrift. Test mcp-write.test.ts:225 prüft unbekannte Aufgabe, anderes generatedAt, fehlende Abschrift, kein Konto, je 0 Aufträge.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/mcp.ts:349
  Evidence: registerUpdate: inputSchema z.object({taskID, generatedAt, fields: updateFieldsSchema}), Annotationen read false/destructive false/idempotent false. Test mcp-write.test.ts:261 vergleicht Schlüsselmenge (9 Schlüssel) mit capture ohne notes und additionalProperties false. Die Werkzeugliste in server/test/mcp.test.ts:60 ist um update_task ergänzt, weiterhin kein Löschwerkzeug.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/test/mcp-write.test.ts:243
  Evidence: Test "a stored order wakes the account once, a refusal never": wake einmal für henning nach Erfolg, bei leerem fields und unbekannter Aufgabe unverändert; Waker hängt in storeOrder (bestehend), nur bei neu gespeichertem Auftrag.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/anleitung.ts:12
  Evidence: Satz "Titel und Angaben ändern: erst nach dem Ja des Nutzers, dann mit update_task. ..."; Test server/test/mcp-anleitung.test.ts:52 prüft Registrierung und Satzinhalt "Ja des Nutzers"; Größentest (Zeile 41) <= 2048 Byte grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: docs/reference/claude-abschrift-vertrag.md:10
  Evidence: Zeile 10 nennt das update-Beispiel ebenfalls in orders.test.ts, Zeilen 123f: "Dienst nimmt fields an capture und update an und prüft nur die Form (#932 Schnitt 2 und 3)"; die json-Blöcke sind laut Diff unberührt. Volllauf 458/0.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: CLAUDE.md:545
  Evidence: mcp.ts-Zeile nennt update_task, Migration 009, fields ohne notes, Erwartungswerte nur für geänderte Felder; Änderung rein additiv.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: server/test/mcp-write.test.ts:278
  Description: Der Schematest wurde in der Umsetzung von ">= 10" auf "== 9" geändert, obwohl die Spec "bestehende Tests unverändert" verlangt. Es ist ein in Schnitt 3 neu geschriebener Test (RED-Commit), kein bestehender; die neue Zahl ist richtig (capture ohne notes = 9 Schlüssel) und strenger.
  Spec requirement: AC-10 — bestehende Tests laufen unverändert
  Conflict: nur formal; keine Verhaltenslücke
  Remediation: keine nötig, nicht blockierend

Nicht gebrochen trotz Versuch: Datenbank mit Bestandsaufträgen (neuer CHECK ist Obermenge), Abschriftwerte title/contexts/project bestehen dieselben text/names-Bausteine wie die Formprüfung des Auftrags (Import orders.ts:2), ein Erwartungswert sprengt also nie die eigene Formprüfung. Zwei parallele update_task erzeugen zwei Aufträge mit eigener UUID; den Konflikt löst die App per stale (Vertrag).

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hat dem Angriff standgehalten.
Tests: 458 passed, 0 failed, 0 übersprungen (docs/artifacts/feat-932-s3-update/adversary-test-output.txt)
Edge cases: alle geprüft, keine gebrochen
Regressions: keine gefunden
Checklist: 10/10 Punkte bewiesen
Offen: F001 (LOW, formal, nicht blockierend)
Stufe 2: lokaler Dienst nicht möglich, siehe stufe2-lokaler-dienst.txt

## Geprüfte Dateien

- sha256:63ff08cf61f0e57161c195146d2f19acfe928347ce1e92c7af4fe592b2e6d48f  CLAUDE.md
- sha256:01ff0b24e9a4932e0c45eea4c8147b59a251a2dacf9d286997d27e59da571cad  docs/reference/claude-abschrift-vertrag.md
- sha256:824caf8c10a209c5b96244ad7273ce5d1494afc0c9d052c302638b10e9f76951  server/migrations/009_order_update.sql
- sha256:c44ea5fa4c5b02fe76a5976d1fc2f8a29ad107a78d0b79d95a307d29bc906c35  server/src/anleitung.ts
- sha256:83392b343dcbfc62ea9738b9fbcf7476494e7a7d58e040a3787f0190bad5b8fc  server/src/mcp.ts
- sha256:a6fa12c2134bfb41a4b393225cd58916659b349b8269307923b8f50ff4986a1d  server/src/orders.ts
- sha256:78ce8a7110664bc04ba42d0d3a03e9cb70790207e54241a445a7d8401410a830  server/test/accounts.test.ts
- sha256:4b5888e46aec75ae0fbcb6eb47a5390a36fd4a9c8b1f76970e4722b9104affd7  server/test/mcp-write.test.ts
- sha256:534439190ab359b1203b0ae8f77f196df50dac32cf01ef9679e63e432d0bbdf9  server/test/orders.test.ts

## Prüfbasis

- base: 965f4e992f806cb86c1e0871d6b7476f883155ee
- blob:3542452092bee8b3e65431d9deeec8b184cc15a6  CLAUDE.md
- blob:248e497e5c602b6be9fb24c51d5ced084ab94324  docs/reference/claude-abschrift-vertrag.md
- blob:11800e478efea653e6fb3d380b24d862b258b6b6  server/migrations/009_order_update.sql
- blob:1315236e5427ac12d5295c758b4b6747908fde2b  server/src/anleitung.ts
- blob:cac9481323b28a8b48c3b1e0a384bd739bf9f01f  server/src/mcp.ts
- blob:3b435848b26f055734398e27cbdb501b673f9959  server/src/orders.ts
- blob:193f8d1051df60b705376f3e796ac8fc2ce53d91  server/test/accounts.test.ts
- blob:073c9b350e4b29b98bf8f5ff4ac7a957950a5115  server/test/mcp-write.test.ts
- blob:75e8b401d696d69114e58587f1042223748c04e5  server/test/orders.test.ts
