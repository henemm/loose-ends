# Adversary Dialog — feat-624-s2b-knoepfe
Spec: docs/specs/feat-624-schnitt-2b1-abhaken.md
Datum: 2026-11-17 17:05

## Checkliste
- [x] **AC-1:** Der Kreisknopf „Abhaken“ erscheint nur, wenn die Antwort auf `ui/initialize` `hostCapabilities.serverTools` enthält, an jeder Zeile aller vier Ansichten, auch am Knäuel; ohne `serverTools` ist die Anzeige gleich Schnitt 2a und das Fenster sendet kein `tools/call` (Test 1).
- [x] **AC-2:** Ein Tipp sendet genau ein `tools/call` `complete_task` mit `{ taskID, generatedAt }` der gelesenen Ansicht und einer id ≥ 2; eine taskID, die nicht in der Ansicht steht, und ein zweiter Tipp auf eine wartende Zeile senden nichts (Test 2).
- [x] **AC-3:** Die Zeile zeigt nach dem Tipp „Abgehakt, wartet auf dein Gerät …“ ohne Knopf (Test 3).
- [x] **AC-4:** Mit der `orderID` fragt das Fenster `get_order_result` alle 3 s ab, bei `waiting` und `claimed` weiter, höchstens 20 Abfragen; danach zeigt die Zeile „Noch nicht übernommen – dein Gerät holt es beim nächsten Öffnen.“ und es folgt keine Abfrage mehr (Tests 4, 7).
- [x] **AC-5:** Bei `result` mit `outcome: done` zeigt die Zeile den grünen Haken mit durchgestrichenem Titel, danach liest das Fenster die Ansicht per `get_view` neu und zeichnet sie; Grün nur in diesem Moment (Test 4).
- [x] **AC-6:** Bei `outcome: rejected` zeigt die Zeile „Nicht übernommen – die Aufgabe hat sich geändert.“ und die Ansicht wird neu gelesen; bei `unknown` und bei jedem anderen Fehler oder JSON-RPC-`error` zeigt sie „Hat nicht geklappt.“, nie einen Host-Fehlertext (Tests 5, 8).
- [x] **AC-7:** Bei „Abschrift hat sich geändert, bitte neu lesen“ liest das Fenster genau einmal per `get_view` neu und die Zeile ist ohne Auftrag zurück; eine zweite gleiche Ablehnung zeigt „Hat nicht geklappt.“ ohne drittes Lesen (Test 6).
- [x] **AC-8:** Bei `ui/resource-teardown` antwortet das Fenster mit `{}`, beendet alle Timer und sendet danach kein `tools/call` mehr (Test 9).
- [x] **AC-9:** Titel und `data-id` erscheinen in jedem Zustand nur HTML-escaped; die Ressource enthält genau ein inline-Skript und keine Fremdquelle; `server/src/mcp.ts`, `server/package.json` und alle S1- und S2a-Tests bleiben unverändert grün (Tests 10, 11; Prüfung im Review).
- [ ] **AC-10:** (offen, nach dem Ausrollen zu belegen) Nach dem Ausrollen ist belegt, ob claude.ai `serverTools` meldet; erscheint der Knopf, sind Knopf und Wartezeile an einer eigens angelegten Prüfaufgabe in Hell und Dunkel belegt, sonst ist das Fehlen des Knopfes belegt; Belege unter `docs/artifacts/feat-624-s2b1-abhaken/` (Stufe 2, Bilder geöffnet und beschrieben, keine echte Aufgabe abgehakt).

## Dialog

### Runde 1
**Adversary:** Gesamtlauf ./server/scripts/test-local.sh (adversary-test-output.txt): 483 Tests, 482 bestanden, 1 rot, 0 übersprungen. Das eine rote ist migrate.test.ts:207 "AC-3: after a failed run the lock is free ... (S3)" (Issue #869, lokal rot, CI grün, nicht Teil dieses Schnitts, kein Befund). Alle Tests aus app-client.test.ts (S1, S2a, S2b-1) grün. Diff von mcp.ts und package.json gegen b51a142: leer (AC-9). Ohne serverTools ist rowsHtml byteweise der Code aus b51a142 (acts undefined, cls/cell/note leer, app-ui.ts:57-58).
AC-1: reduce liest hostCapabilities.serverTools per Boolean(...) (server/src/app-ui.ts:169); Knopf in rowAct (app-ui.ts:47) an jeder Zeile unabhängig von der Gruppe; Test server/test/app-client.test.ts:259 (vier Ansichten, Knäuel).
AC-2: onEvent (app-ui.ts:115-120) prüft serverTools, taskID in state.result.rows und Phase != waiting; id aus nextId ab 2 (app-ui.ts:97); Test app-client.test.ts:279. Eigene Probe: tap auf bekannte id sendet genau ein complete_task mit generatedAt.
AC-3: Phase waiting gibt leere Zelle und die Wartezeile (app-ui.ts:44,49); Test :293.
AC-4: Takt 3000 ms (app-ui.ts:146), polls beim tick erhöht (:124), bei polls>=20 und waiting/claimed Phase late ohne later (:155); Tests :302, :361. Genau 20 Abfragen.
AC-5/6: done/rejected gehen über settle mit reread (app-ui.ts:157-158), unknown/Fehler zu failed (:159); Grün nur im tick-Span (app-ui.ts:48,249); Tests :302, :326, :371. CSS-Spezifität: .tick{color:var(--green)} liegt auf einem Span der zweiten Zelle, die graue Regel ".row > span:first-child" trifft nur die Randmarke; kein Konflikt wie F001 im Vorgänger.
AC-7: stale-Text exakt verglichen (app-ui.ts:149), einmal get_view, Eintrag {polls:0,retried:true} ohne phase, Knopf wieder da; zweite gleiche Ablehnung führt zu failed (:150-151); Test :340.
AC-8: teardown setzt ended und antwortet {} (app-ui.ts:177); shell löscht Timer, Callback prüft ended (app-ui.ts:199, 203); onEvent und Antworten bei ended gesperrt (:114, :178); Test :391.
AC-9: escape für title und data-id (app-ui.ts:47,58); Notizzeilen sind statische Literale; genau ein Script; Tests :403, :429.
Randfälle ohne Defekt: doppelte oder unbekannte Antwort-ids (pending wird beim ersten Treffer entfernt, app-ui.ts:129,178); tick nach done/late/rejected (onEvent liefert none, :122); get_view-Antwort ohne die Zeile (rows gefiltert, :135); Fremdquelle verworfen (shell prüft event.source, app-ui.ts:209).
**Implementierer:** (nicht anwesend; Code und Tests gelesen)

### Runde 2
**Adversary:** Gezielte Brüche, per Node-Probe gegen reduce bestätigt.
F001 (LOW, edge_case): Eine Hostnachricht ohne jsonrpc wird in reduce (app-ui.ts:165) als interne Shell-Aufgabe behandelt. Probe: reduce(state,{kind:"tap",taskID:"a"}) liefert direkt ein tools/call complete_task. Die shell reicht jede Nachricht des Parent unverändert an run() (app-ui.ts:208-211). Der Host ist vertrauenswürdig (event.source === parent) und kann selbst tools/call stellen, deshalb nur LOW. Abhilfe: Hostnachrichten nur mit jsonrpc "2.0" an run() geben.
Code reference: server/src/app-ui.ts:165
F002 (LOW, edge_case): pending ist ein normales Objekt; eine Hostantwort mit id "constructor" trifft pending["constructor"] (app-ui.ts:178), onAnswer legt eine Zeile unter dem Schlüssel "undefined" mit Phase failed an (Probe bestätigt). Folgenlos für die Anzeige. Abhilfe: Object.hasOwn oder Map.
Code reference: server/src/app-ui.ts:178
Bewertung „Knopf bei failed wieder sichtbar“ (app-ui.ts:49; Spec erlaubt Tipp außer bei waiting): vertretbar. Nebenwirkungen: (a) failed aus einer Abfrage heraus (Auftrag existiert evtl. noch) erlaubt einen zweiten Auftrag für dieselbe Aufgabe; (b) failed setzt retried zurück (app-ui.ts:147), jeder neue Tipp hat frisches Lesebudget. Beides nutzergetrieben und begrenzt; ein zweiter complete_task auf eine erledigte Aufgabe wird als stale abgelehnt. Kein Defekt.
Weiter: zwischen stale-Antwort und get_view-Antwort ist der Knopf sichtbar; ein Tipp dort endet über retried=true in failed (kein Endlosloop, app-ui.ts:150). CSS: kein Rot in den neuen Zeilen, Knopf Akzent, Grün nur in .tick (app-ui.ts:248-249). Keine Fremd-URL, genau ein Script.
Code reference: server/test/app-client.test.ts:259
Code reference: server/test/app-client.test.ts:429
**Implementierer:** (nicht anwesend)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Neue Zustandsfelder (caps, pending, rows) werden nur in reduce/onEvent/onAnswer geschrieben. Bedingung davor: serverTools, bekannte taskID, Phase != waiting. Test für genau diesen Weg: server/test/app-client.test.ts:279 (Tipp) und :302 (Antwort und Takt).

## Verdict

Confirmation:
  AC: AC-1
  Code reference: server/src/app-ui.ts:169
  Evidence: caps.serverTools aus hostCapabilities; Knopf Z.47 an jeder Zeile; ohne serverTools byteweise 2a; Test app-client.test.ts:259 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/src/app-ui.ts:115
  Evidence: tap nur mit serverTools, bekannter taskID, nicht waiting; id ab 2; Test :279 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/app-ui.ts:44
  Evidence: waiting-Zeile ohne Knopf mit Wartezeile; Test :293 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/app-ui.ts:155
  Evidence: 3000 ms Takt, genau 20 Abfragen, dann late ohne later; Tests :302, :361 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/src/app-ui.ts:158
  Evidence: done zeigt Haken (Grün nur .tick, Z.249), durchgestrichen Z.250, Neulesen per get_view; Test :302 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/app-ui.ts:159
  Evidence: rejected/unknown/Fehler/JSON-RPC-error führen zu statischen ruhigen Zeilen, nie Hosttext; Tests :326, :371 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/app-ui.ts:150
  Evidence: stale genau einmal neu gelesen, zweite Ablehnung failed ohne drittes Lesen; Test :340 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/app-ui.ts:177
  Evidence: teardown mit {} und ended; Timer gelöscht (Z.199), Callback prüft ended (Z.203); Test :391 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/app-ui.ts:58
  Evidence: title und data-id escaped in allen Phasen; ein Script; mcp.ts und package.json ohne Diff gegen b51a142; Tests :403, :429.
  Status: CONFIRMED

AC-10: offen, nach dem Ausrollen zu belegen (Ausrollen auf rennwienix, Sichtprüfung in claude.ai, serverTools-Meldung).

VERDICT: AMBIGUOUS
Gilt für AC-1 bis AC-9. AC-10 ist in dieser Phase nicht belegbar und bleibt offen. Findings: F001 (LOW), F002 (LOW), nicht blockierend.
Tests: 482 passed, 1 failed (migrate AC-3 S3, Issue #869, nicht dieser Schnitt), 0 übersprungen
Regressions: none found
Checklist: 9/10 points proven, AC-10 offen

## Geprüfte Dateien

- sha256:0e6bc5ee1349c03812391d837ad37a70204e9886b12827f64d4b02c05de1124f  server/src/app-ui.ts
- sha256:d12a75432f6aea0f41ece526d3cdd0c509cb73f5a3b45b45391c04e2cc528134  server/test/app-client.test.ts

## Prüfbasis

- base: b51a1420fd3baf7a051c22e96607bddfc3b3c7a4
- blob:345c257f79337b70b4a9d2afab9d292f571c0f6c  server/src/app-ui.ts
- blob:50828c2303c4541cc7c6a54bdce56ecdb0f4a0fe  server/test/app-client.test.ts

## Geprüfte Dateien

- sha256:0e6bc5ee1349c03812391d837ad37a70204e9886b12827f64d4b02c05de1124f  server/src/app-ui.ts
- sha256:d12a75432f6aea0f41ece526d3cdd0c509cb73f5a3b45b45391c04e2cc528134  server/test/app-client.test.ts

## Prüfbasis

- base: b51a1420fd3baf7a051c22e96607bddfc3b3c7a4
- blob:345c257f79337b70b4a9d2afab9d292f571c0f6c  server/src/app-ui.ts
- blob:50828c2303c4541cc7c6a54bdce56ecdb0f4a0fe  server/test/app-client.test.ts
