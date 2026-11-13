# Adversary Dialog — feat-623-skills-plugin
Spec: docs/specs/feat-623-skills-plugin.md
Datum: 2026-11-13 17:36

## Checkliste
- [x] **AC-1:** Anleitung kommt an: GIVEN ein Client im Prozess über `mcpHandler` mit Konto WHEN er `initialize` abgeschlossen hat THEN liefert `client.getInstructions()` genau den Text aus `anleitung.ts` (Test `initializeCarriesTheInstructions`).
- [x] **AC-2:** Kurz genug: GIVEN `anleitung` THEN ist `Buffer.byteLength(anleitung, "utf8")` höchstens 2048 und der Text nicht leer (Test `instructionsFitTwoKilobytes`).
- [x] **AC-3:** Nur wirkliche Werkzeuge: GIVEN die Anleitung WHEN alle Wörter der Form `[a-z]+_[a-z_]+` aus ihr gezogen werden THEN kommt jedes davon in `client.listTools()` vor, und die Anleitung nennt mindestens `get_view`, `capture_task`, `add_subtask` und `get_order_result` (Test `instructionsNameOnlyExistingTools`).
- [x] **AC-4:** Inhalt der Regeln: GIVEN die Anleitung THEN enthält sie die Wörter „Jetzt“, „Fällig“, „löschen“, „Knäuel“ und „Perle“, und enthält weder „Wochenrückblick“ noch „Rückblick“ (Test `instructionsHoldTheRulesAndNoReview`).
- [x] **AC-5:** Ohne Konto weiter 401: GIVEN ein Aufruf ohne Konto in `authInfo` THEN verhält sich der Dienst wie vorher (bestehende Tests in `mcp.test.ts` unverändert grün); die Anleitung öffnet keinen Weg ohne Anmeldung (Beleg: Suite).
- [x] **AC-6:** Nichts anderes geändert: GIVEN die Änderung THEN zeigt `git diff --stat origin/main...HEAD` genau `server/src/anleitung.ts`, `server/src/mcp.ts` (höchstens 3 geänderte Zeilen), `server/test/mcp-anleitung.test.ts` sowie Spec, Kontext, Briefing, Belege und die `CLAUDE.md`-Zeile; `docs/reference/claude-abschrift-vertrag.md` und `server/src/main.ts` fehlen darin (Beleg: Ausgabe im Abschlussbericht).
- [x] **AC-7:** Serverkette grün: GIVEN `./server/scripts/test-local.sh` THEN ist `typecheck` sauber und alle Tests grün (Beleg: Lauf im Abschlussbericht).

## Dialog

### Runde 1
**Adversary:** Alle sieben ACs einzeln angegriffen, nicht auf den grünen Lauf (412 Tests, 0 fail, 0 skipped, `test-green-output.txt`) verlassen.

Confirmation:
  AC: AC-1
  Code reference: server/src/mcp.ts:194
  Evidence: `new McpServer({ name: "loose-ends", version: "1" }, { instructions: anleitung })`; Test server/test/mcp-anleitung.test.ts:34-37 vergleicht `client.getInstructions()` mit `anleitung` per `assert.equal` (grün). Test heißt `AC-1: initialize carries ...` statt des Spec-Namens `initializeCarriesTheInstructions`, Inhalt entspricht.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/anleitung.ts:3
  Evidence: selbst gemessen mit node: 964 Byte UTF-8 (Grenze 2048), nicht leer; Test mcp-anleitung.test.ts:39-42.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/test/mcp-anleitung.test.ts:44
  Evidence: Regex `[a-z]+_[a-z_]+` auf die echte Anleitung angewendet: get_view, capture_task, add_subtask, get_order_result, set_due, complete_task, get_now. Alle sind in mcp.ts registriert (get_now :195, get_view :203, capture_task :248, get_order_result :254, complete_task :259, set_due :265, add_subtask :287). Pflichtnamen alle vorhanden. camelCase (nowCount, generatedAt) fällt aus der Regex, ist aber real (mcp.ts:198, :211). Typ-Zeile 47 (`: string[]`) ändert nur den Typ, nicht die Prüfung (Diff gegen HEAD angesehen).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/anleitung.ts:6
  Evidence: enthält „Jetzt“ (:6), „Fällig“ (:6), „löschen“ (:13), „Knäuel“ und „Perle“ (:14); weder „Wochenrückblick“ noch „Rückblick“; kein Satz zu Erledigtem/Perlen-Zusagen. Test :52-55.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/test/mcp.test.ts:68
  Evidence: Ohne-Konto-Tests (mcp.test.ts:68, :199, :299) unverändert (Datei nicht in der Änderungsliste), in der Suite grün. `instructions` ist reiner Text im initialize, die Werkzeuge verlangen weiter den Account aus authInfo; kein neuer Pfad.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/mcp.ts:7
  Evidence: `diff --stat` gegen Basis 82c5e31: nur Spec, Kontext, Briefing, RED-Beleg, mcp.ts (3 Zeilen: 2+/1-, Import :7 und Zeile :194) und mcp-anleitung.test.ts; anleitung.ts (neu, noch unversioniert). server/src/main.ts und docs/reference/claude-abschrift-vertrag.md: leerer Diff. OFFEN (kein Codedefekt): die CLAUDE.md-Zeile zu `src/anleitung.ts` fehlt noch (Suche leer); Ticket-/Epic-Text laut DoD ebenfalls später. Der Diff gegen origin/main wird erst nach Commit aussagekräftig.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/test/mcp-anleitung.test.ts:47
  Evidence: test-green-output.txt: tests 412, pass 412, fail 0, skipped 0; Typ-Zeile 47 (`: string[]`) behebt den Typecheck-Fehler der RED-Fassung. Den Lauf selbst nicht wiederholt (Datei gelesen).
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Behauptungen der Anleitung gegen die Werkzeug-Schemas.

- „kein Löschwerkzeug“: registerTool-Liste mcp.ts:195-287 hat get_now, list_tasks, get_view, search_tasks, get_task, list_projects, list_contexts, capture_task, get_order_result, complete_task, set_due, set_next, park_task, add_subtask: 14, kein delete. Wahr.
- „generatedAt mitgeben“ bei set_due/complete_task: inputSchema verlangt `generatedAt: z.string()` (mcp.ts:262, :271). Wahr.
- „get_view mit now / due“: Beschreibung mcp.ts:204 nennt now und due; nowCount nur bei view now (:211). Wahr.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/anleitung.ts:17
  Description: Regel „Vor set_due, complete_task und anderen Änderungen get_now oder get_view lesen und generatedAt mitgeben“ ist zu weit gefasst: capture_task ist eine Änderung, hat aber kein generatedAt (mcp.ts:251, inputSchema nur `text`).
  Spec requirement: Teil 1 Punkt 4 — Spec wörtlich „bei set_due, complete_task und anderen Änderungen“; der Code folgt der Spec.
  Conflict: Claude könnte vor capture_task unnötig lesen. Kein Spec-Verstoß, kein Blocker.
  Remediation: optional „außer capture_task“ ergänzen (964 von 2048 Byte), zusammen mit Spec-Anpassung.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: server/test/mcp-anleitung.test.ts:34
  Description: Testnamen weichen von den in der Spec genannten ab (`AC-1: initialize carries...` statt `initializeCarriesTheInstructions` usw.).
  Spec requirement: Source/AC-1..AC-4 — Namen der Tests
  Conflict: rein formal; die Prüfungen sind inhaltlich gleich.
  Remediation: Namen angleichen oder Spec anpassen.

Frühe Übereinstimmung geprüft: Byte-Zahl selbst gemessen, Regex selbst ausgeführt, Diff selbst gelesen. Keine Regression: mcp.ts-Änderung betrifft nur den Konstruktor in `mcpHandler`, dessen Aufrufer unverändert.
**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Es werden keine Modellfelder geschrieben; reine Textkonstante, keine verdächtigen Schreibstellen.

## Verdict
**VERIFIED**

Tests: 412 passed, 0 failed, 0 übersprungen (Beleg gelesen, nicht neu gelaufen)
Edge cases: geprüft, nur F001/F002 (LOW)
Regressions: keine
Checklist: 7/7 bewiesen; offen (kein Codedefekt): CLAUDE.md-Zeile, Ticket-/Epic-Text, Diff gegen origin/main nach Commit

## Geprüfte Dateien

- sha256:a0da4175905c527a6aa472461e805ac80cee93835abd898a9c17be150a65aacf  server/src/anleitung.ts
- sha256:f5be2ddac33fda8c9a91f11edcc4f6c8a234547e7b79a1176dc701241a729424  server/src/mcp.ts
- sha256:38a17862a0b2f6f8794b01bf7526257bcc2d39b60f40d78e9cd177cfe2e746b0  server/test/mcp-anleitung.test.ts
- sha256:9f2497b237ed973a66a836d0d5c778474a5352751a654649b1d49645ca8cbbb2  server/test/mcp.test.ts

## Prüfbasis

- base: 82c5e318db29407709de8173327e61b39d4eaa00
- blob:e220cbb506a2140aa4995404dd616ba4d102ed18  server/src/anleitung.ts
- blob:f59ef403fc6002e8b05056d7f27056c7ec65a836  server/src/mcp.ts
- blob:2b0645b8b01a30cd646422cefe4b6d0c107a0535  server/test/mcp-anleitung.test.ts
- blob:a48b1bfd490e21894f570f9c5f36b61159d92865  server/test/mcp.test.ts

## Geprüfte Dateien

- sha256:a0da4175905c527a6aa472461e805ac80cee93835abd898a9c17be150a65aacf  server/src/anleitung.ts
- sha256:f5be2ddac33fda8c9a91f11edcc4f6c8a234547e7b79a1176dc701241a729424  server/src/mcp.ts
- sha256:38a17862a0b2f6f8794b01bf7526257bcc2d39b60f40d78e9cd177cfe2e746b0  server/test/mcp-anleitung.test.ts
- sha256:9f2497b237ed973a66a836d0d5c778474a5352751a654649b1d49645ca8cbbb2  server/test/mcp.test.ts

## Prüfbasis

- base: 82c5e318db29407709de8173327e61b39d4eaa00
- blob:e220cbb506a2140aa4995404dd616ba4d102ed18  server/src/anleitung.ts
- blob:f59ef403fc6002e8b05056d7f27056c7ec65a836  server/src/mcp.ts
- blob:2b0645b8b01a30cd646422cefe4b6d0c107a0535  server/test/mcp-anleitung.test.ts
- blob:a48b1bfd490e21894f570f9c5f36b61159d92865  server/test/mcp.test.ts
