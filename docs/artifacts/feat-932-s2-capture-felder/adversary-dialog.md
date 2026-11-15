# Adversary Dialog — feat-932-s2-capture-felder
Spec: docs/specs/feat-932-schnitt-2-dienst.md
Datum: 2026-11-15 22:05

## Checkliste
- [x] **AC-1:** `checkOrder` nimmt ein `capture` mit `fields` aus beliebigen der Schlüssel `title`, `notes`, `dueDate` (mit `dueHasTime`), `importance`, `urgency`, `duration`, `energy`, `contexts`, `project` in gültiger Form an, ebenso ein leeres `fields` (Test 1).
- [x] **AC-2:** `checkOrder` weist je Schlüssel einen Wert in falscher Form oder außerhalb der Wertemenge mit `Auftrag ungültig: fields.<schlüssel> …` ab, darunter Energie 4, −4 und 1.5 sowie `dueDate` ohne `dueHasTime` und umgekehrt (Test 2).
- [x] **AC-3:** Ein fremder Schlüssel in `fields` und ein `fields`, das kein Objekt ist, werden als Formfehler mit Pfad abgewiesen (Test 3).
- [x] **AC-4:** Das ` ```jsonc`-Beispiel `capture` des Vertrags besteht `checkOrder`; der Vertrag enthält weiter genau drei ` ```json`-Blöcke unverändert an derselben Stelle (Test 4, Test 8).
- [x] **AC-5:** `capture_task` mit `fields` speichert sie unverändert im Auftrag; ohne `fields` hat der gespeicherte Auftrag keinen Schlüssel `fields` und ist byte-gleich zu heute (Test 5).
- [x] **AC-6:** `capture_task` mit unbekanntem Schlüssel oder falschem Wert in `fields` wird abgewiesen, ohne dass ein Auftrag gespeichert wird (Test 6).
- [x] **AC-7:** Das zod-Schema von `capture_task` ist `.strict()` und hat genau die Schlüssel von `captureFields`; ein Test hält beide gleich (Test 7).
- [x] **AC-8:** Der Dienst prüft nur die Form: kein Abgleich mit Katalogen, kein Titel-Kürzen, kein Modellaufruf; der Vertragssatz zu `fields` und `update` ist auf den Stand Schnitt 2 gebracht (Prüfung im Review, Satz im Vertrag).
- [x] **AC-9:** `./server/scripts/test-local.sh` ist grün; App, Migrationen und `anleitung.ts` sind unverändert, die Anleitung bleibt ≤ 2048 Byte (Test 8).

## Dialog

### Runde 1
**Adversary:** Voller Lauf ./server/scripts/test-local.sh (Ausgabe adversary-test-output.txt): tests 448, pass 448, fail 0, skipped 0, Exit 0. Eigene Sonden direkt gegen checkOrder: leeres fields ok; energy -0, 3, -3 ok; NaN, Infinity, "3", 4, -4, 1.5 abgewiesen mit fields.energy; dueDate ohne dueHasTime und umgekehrt abgewiesen (fields.dueHasTime / fields.dueDate), dueHasTime:false mit dueDate ok; contexts mit "" ok (nur Form, Katalog ist Sache der App), contexts [1] abgewiesen; leerer title/project ok (Sache der App laut Spec); __proto__ (per JSON.parse) und constructor als fremder Schluessel abgewiesen (Object.hasOwn); null, Zahl, Liste, fehlendes Objekt -> "fields: kein Objekt"; 30.02. und Steuerzeichen abgewiesen; fields bei complete/setDue/setNext/park/addSubtask -> "fields: unbekannter Schluessel"; kind update -> unbekannte Art. Vertrag: genau 3 json-Bloecke (Zeilen 45, 148, 218), jsonc-Beispiele Zeile 161/184; Test liest das capture-Beispiel zur Laufzeit. Geschuetzte Pfade (LooseEnds, Shared, LooseEndsTests, server/migrations, anleitung.ts) gegen 44e3a261 ohne Diff; anleitung.ts 1311 Byte.
**Implementierer:** keine Einwaende zu erheben, kein Schluessel ausserhalb der Spec gefunden.

### Runde 2
**Adversary:** Zweite Runde, Gegenprobe der Kette: mcp.ts capturing() nimmt fields nur bei !== undefined auf (kein Schluessel fields ohne, Test AC-5 prueft Schluessel id, kind, text, version); zod captureFieldsSchema ist partial().strict() mit zehn Schluesseln = FIELD_KEYS (Test AC-7 vergleicht gegen listTools-Schema und gegen checkOrder). Zod-Abweisung passiert vor dem Handler, checkOrder-Abweisung in storeOrder vor dem INSERT; Test AC-6 prueft orderCount == 0 nach zehn Fehlfaellen. Disziplin zod/checkOrder: zod laesst z.B. dueDate ohne dueHasTime und Steuerzeichen durch, checkOrder lehnt beides ab, kein Auftrag gespeichert. Vertragssatz (Zeile 122-124) nennt Stand Schnitt 2, nur Formpruefung; update bleibt unbekannte Art. Keine Katalogpruefung, kein Kuerzen, kein Modellaufruf im Diff (nur shape-Pruefungen). transcripts.ts exportiert lediglich names. Kein Befund.
**Implementierer:** bestaetigt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Bestaetigungen

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-4
  Code reference: server/src/orders.ts:50
  Evidence: fieldsCheck/captureFields (shape, paarweise dueDate/dueHasTime, energy ganze Zahl -3..3), forms.capture optional fields; Sonden Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-5, AC-6
  Code reference: server/src/mcp.ts:77
  Evidence: capturing() setzt fields nur wenn gegeben; Abweisung vor dem Speichern.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/mcp.ts:267
  Evidence: captureFieldsSchema partial().strict(), zehn Schluessel.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/transcripts.ts:142
  Evidence: nur Export von names; keine Katalog- oder Modelllogik; Vertragssatz aktualisiert.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/test/orders.test.ts:309
  Evidence: test-local.sh 448 pass, 0 fail, 0 skipped.
  Status: CONFIRMED

Confirmation:
  AC: AC-5, AC-6, AC-7
  Code reference: server/test/mcp.test.ts:443
  Evidence: Tests AC-5/6/7 (#932 S2) gruen.
  Status: CONFIRMED

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 448 passed, 0 failed, 0 uebersprungen
Edge cases: All checked, none broken
Regressions: None found
Checklist: 9/9 points proven

## Geprüfte Dateien

- sha256:86821ec6bf8124bcbeabfb72c3a94014178e0b04bbf15380320d4edf627ffdf1  server/src/mcp.ts
- sha256:482a735c65c04b03de3d30d73ce33bda5a8bf103d4c2f374c8f3188b05f18971  server/src/orders.ts
- sha256:10fec0f9e8998792c700649756df7f9ded7a09ab9690f0413b1d703b401dcfef  server/src/transcripts.ts
- sha256:37383b0a2a9dd9f73e80ea7bca6168e14e0fd36677ca2fbc84c654a9226f32b2  server/test/mcp.test.ts
- sha256:699f9a260d45d06370d6a06013705152c0ad2452dee6ff9884a992b73ffaeb84  server/test/orders.test.ts

## Prüfbasis

- base: 44e3a261ae583b9f462a78e870b9f891678605ed
- blob:827d2d81e5b6cf00edba5371148e075fcb082c81  server/src/mcp.ts
- blob:fcd7c31cc687e9dc8288a00a37fdaf1bcd45ea30  server/src/orders.ts
- blob:80e69783b2b9e1f1277466f1f12260f366eddb66  server/src/transcripts.ts
- blob:92ae831b2cc59aaf4da6fb131860d53fa8b4fceb  server/test/mcp.test.ts
- blob:e54530d9beded61de0a990a3756aac2a8acb9846  server/test/orders.test.ts
