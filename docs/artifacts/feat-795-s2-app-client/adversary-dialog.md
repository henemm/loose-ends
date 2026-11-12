# Adversary Dialog — feat-795-s2-app-client
Spec: docs/specs/feat-795-schnitt-2a-app-client.md
Datum: 2026-11-12 08:02

## Checkliste
- [x] **AC-1:** Wire `transcript`: GIVEN ein `Transcript` und ein `FakeTransport` mit 204 WHEN `putTranscript(_:sessionToken:)` läuft THEN wird genau eine Anfrage gesendet: Methode `POST`, Pfad `/app/transcript`, `Authorization` gleich `Bearer <Token>`, `Content-Type` gleich `application/json`, kein `X-Device`, und `httpBody` ist byte-gleich `TranscriptCodec.encode(transcript)` (Test `putTranscriptWire`, Basis-URL mit und ohne Schrägstrich und mit Unterpfad als Argumente).
- [x] **AC-2:** Wire `claim`: GIVEN ein `FakeTransport` mit 204 und die UUID `A1B2C3D4-E5F6-4711-8899-AABBCCDDEEFF` WHEN `claimOrder(sessionToken:device:)` läuft THEN ist die Anfrage `POST /app/orders/claim` mit `Authorization` gleich `Bearer <Token>`, `X-Device` gleich der Kleinschreibung `a1b2c3d4-e5f6-4711-8899-aabbccddeeff`, ohne Körper (`httpBody == nil`) und ohne `Content-Type`; die Rückgabe ist `.none` (Test `claimOrderWireAndNone`).
- [x] **AC-3:** Wire `result`: GIVEN ein `OrderResult` und ein `FakeTransport` mit 204 und dieselbe UUID in Großschreibung WHEN `putResult(_:sessionToken:device:)` läuft THEN ist die Anfrage `POST /app/orders/result` mit `Authorization`, `X-Device` in Kleinbuchstaben, `Content-Type` gleich `application/json`, und `httpBody` ist byte-gleich `TranscriptCodec.encode(result)` (Test `putResultWire`).
- [x] **AC-4:** Auftrag lesbar: GIVEN ein `FakeTransport` mit 200 und dem Körper `TranscriptCodec.encode(order)` für einen `Order` jeder der sechs Arten (`capture`, `complete`, `setDue`, `setNext`, `park`, `addSubtask`) WHEN `claimOrder` läuft THEN ist die Rückgabe `.order(order)`, gleich dem gesendeten (alle gesetzten Felder, auch `date` und `expectedDueDate` in ganzen Sekunden) (Test `claimOrderReadsEveryKind`, Argumente je Art).
- [x] **AC-5:** Giftauftrag: GIVEN ein `FakeTransport` mit 200 und einem JSON-Objekt, das ein gültiges `id` (UUID) trägt, sich aber nicht als `Order` lesen lässt (unbekannte `kind` `"teleport"`; `kind` fehlt; falscher Typ in `hasTime`; unbekannter `expectedStatus`) WHEN `claimOrder` läuft THEN ist die Rückgabe `.unreadable(id)` mit genau dieser UUID, und der Aufruf wirft nicht (Test `claimOrderPoisonKeepsId`, Argumente je Fall).
- [x] **AC-6:** Körper ohne rettbares `id`: GIVEN ein `FakeTransport` mit 200 und einem Körper, der kein JSON ist, ein leerer Körper, ein Array, ein Objekt ohne `id`, ein Objekt mit `id` als Zahl, ein Objekt mit `id` `"nicht-eine-uuid"` WHEN `claimOrder` läuft THEN wirft der Aufruf `ServiceError.invalidResponse` (Test `claimOrderWithoutIdIsInvalid`, Argumente je Fall).
- [x] **AC-7:** 204 ist Erfolg, nichts sonst: GIVEN die Wege `transcript` und `result` mit 204 THEN kehren beide ohne Fehler zurück; GIVEN `transcript` und `result` mit 200 THEN `rejected(200)`; GIVEN `claim` mit 202 THEN `rejected(202)` (Test `successStatusPerRoute`).
- [x] **AC-8:** 409 → `refused`: GIVEN `putResult` mit 409 WHEN er läuft THEN wirft er `ServiceError.refused` (nicht `rejected(409)`); dasselbe 409 an `transcript` und `claim` ergibt ebenfalls `refused` (Test `conflictIsRefused`).
- [x] **AC-9:** 429 → `tooManyRequests`: GIVEN jeder der drei Wege mit 429 WHEN er läuft THEN wirft er `ServiceError.tooManyRequests` (nicht `rejected(429)`); der Client sendet dabei genau eine Anfrage, keine Wiederholung (Test `tooManyRequestsPerRoute`, `requests.count == 1`).
- [x] **AC-10:** Übrige Status je Weg: GIVEN jeder der drei Wege WHEN der Dienst 401 antwortet THEN `unauthorized`; 503 THEN `unavailable`; 400, 413, 415, 405, 500 THEN je `rejected(<Status>)` (Test `statusMappingAppRoutes`, Argumente Weg × Status).
- [x] **AC-11:** Transportfehler: GIVEN jeder der drei Wege WHEN der Transport `URLError` (`notConnectedToInternet`, `timedOut`, `cannotConnectToHost`) wirft THEN `unavailable`; GIVEN `URLError(.cancelled)` THEN `CancellationError`; GIVEN `CancellationError` THEN `CancellationError` (Tests `appRoutesTransportErrors`, `appRoutesCancelledIsCancellation`).
- [x] **AC-12:** Keine Geheimnisse in Fehlern: GIVEN jeder der drei Wege und Antworten 401, 409, 429, 503, 500 und 200 mit einem Körper, der `SECRET-BODY` enthält (bei `claim` ein Auftrag mit lesbarem `id` und `SECRET-BODY` im Feld `text`, der als Fehler endet, und ein unlesbarer Körper mit `SECRET-BODY`) sowie ein `URLError` WHEN der Aufruf scheitert THEN enthält `String(describing: error)` weder den Token noch `SECRET-BODY` noch die URL `example.test` (Test `appRoutesErrorsCarryNoSecrets`).
- [x] **AC-13:** Erzeugen und Importieren sendet nichts, Anmelde-Wege unverändert: GIVEN ein `FakeTransport` ohne Antworten WHEN ein `ServiceClient` erzeugt wird THEN ist `requests` leer (der bestehende Test `creatingSendsNothing` bleibt grün); GIVEN die bisherigen Tests der Anmelde-Wege THEN laufen sie unverändert grün, auch `statusMapping` mit 400, 405, 413, 415, 500 als `rejected` (Beleg: die gesamte Suite `ServiceClientTests` grün, kein bestehender Test geändert außer der Aufnahme von 409 und 429 in die Statusliste der Anmelde-Wege, siehe AC-14).
- [x] **AC-14:** Auswirkung von 409 und 429 auf die Anmelde-Wege ist gewollt und belegt: GIVEN `signIn`, `logout`, `deleteAccount` WHEN der Dienst 429 antwortet THEN `tooManyRequests`, bei 409 `refused` (der bestehende Test `statusMapping` wird um die Fälle (Weg, 429, `.tooManyRequests`) und (Weg, 409, `.refused`) für alle drei Anmelde-Wege erweitert, Test `statusMapping`).

## Dialog

### Runde 1
**Adversary:** Lauf `./scripts/sim.sh sim-unit ServiceClientTests` (Ausgabe: adversary-test-output.txt): Test Succeeded. Ergebnisbuendel: 23 Tests bestanden, 0 fehlgeschlagen, 0 uebersprungen; 110 Einzelfaelle (Argumente) bestanden. Die Konsole zeigt nur die nicht parametrisierten Tests, die parametrisierten stehen im Buendel. Pruefung je AC gegen den Code:
- AC-1: putTranscript setzt POST app/transcript, Bearer, Content-Type, Body = TranscriptCodec.encode, kein X-Device, Erfolg nur 204. PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:81
- AC-2: claimOrder setzt X-Device als uuidString.lowercased(), keinen Body, keinen Content-Type; 204 -> .none. PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:90
- AC-3: putResult wie AC-2 plus Content-Type und Body aus encode(result). PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:98
- AC-4: 200 -> TranscriptCodec.decode(Order) (iso8601, ganze Sekunden) -> .order. PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:108
- AC-5: Decode-Fehler -> JSONSerialization -> id als UUID -> .unreadable(id); wirft nicht. PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:112
- AC-6: Kein JSON, leerer Koerper, Array, fehlende oder falsch typisierte id, keine UUID -> invalidResponse. 200 mit `null` wirft ebenfalls in jsonObject (kein fragmentsAllowed) -> invalidResponse. PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:118
- AC-7: success-Menge je Weg: 204 fuer transcript und result, [200,204] fuer claim; 200 an transcript -> rejected(200), 202 an claim -> rejected(202). PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:152
- AC-8: 409 -> refused in send, fuer alle Wege. PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:155
- AC-9: 429 -> tooManyRequests, keine Wiederholung (ein transport.send je Aufruf). PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:156
- AC-10: 401 unauthorized, 503 unavailable, Rest rejected(Status). PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:154
- AC-11: URLError.cancelled -> CancellationError, anderer URLError -> unavailable, CancellationError laeuft unveraendert durch. PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:147
- AC-12: Fehlerfaelle sind Fall-Konstanten ohne Nutzlast ausser dem Int-Status; im claim-Pfad wird der Koerper nur geparst, nie in den Fehler gegeben. PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:116
- AC-13/AC-14: signIn, logout, deleteAccount nutzen send mit success [200] bzw. [204]; Suite komplett gruen, erzeugen sendet nichts. PROVEN. Code reference: LooseEnds/Claude/ServiceClient.swift:57
Bekannte Abweichung: send gibt (body, status) zurueck. signIn (Zeile 57) liest nur .body, logout und deleteAccount (72, 77) verwerfen das Ergebnis; Statusabbildung unveraendert ausser 409/429. Korrekt und unschaedlich.
**Implementierer:** Keine Gegenrede; Ausfuehrung entspricht der Spec.

### Runde 2
**Adversary:** Gezielte Randfaelle, an Code und Gegenstelle (server/src/app-routes.ts, orders.ts) gelesen:
- Giftauftrag mit gueltigem Rest aber anderer version (z.B. 2): Order.version ist ein Int ohne Pruefung, der Auftrag dekodiert als .order; OrderExecutor.execute (Shared/Services/OrderExecutor.swift:47) antwortet dann invalid. Der Server laesst nur version 1 durch. Kein Fehler im Client, nur Hinweis.
- id in Grossschreibung im Auftrag: UUID(uuidString:) akzeptiert sie; Geraete-ID wird kleingeschrieben gesendet, passt zu app-routes.ts:42-44.
- 200 mit null oder leerem Koerper: invalidResponse. 204 mit Koerper: .none, Koerper ignoriert; gewollt.
- AccountState: signIn mit 429 oder 409 landet im default-Zweig von signInStatus -> signedOut (vorher rejected(429), gleiches Ergebnis). deleteAccount mit 429 oder 409 -> signedIn plus lastProblem retryLater, wie bei jedem anderen Fehler. signOut ignoriert das Ergebnis. Keine Regression. Code reference: LooseEnds/Claude/ServiceClient.swift:156
- Geheimnisse: caseName in AccountState gibt nur den Fallnamen; tooManyRequests und refused tragen nichts.
- Tests zu nachsichtig? Sie pruefen Fehlerfaelle per Equatable, Header und Body byte-gleich. Ein Giftauftrag mit anderer version ist nicht abgedeckt, aber nicht Teil der Spec.
- Eigene Zusatzproben als Code habe ich nicht gefahren; die Randfaelle beruhen auf Lesen des Codes und der gruenen Suite. Keine Produktions- oder Testdatei von mir veraendert.
**Implementierer:** Keine Gegenrede.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Confirmation:
  AC: AC-1 bis AC-14
  Code reference: LooseEnds/Claude/ServiceClient.swift:81
  Evidence: Wire-Form, Statusabbildung, Giftauftrag-Rettung und send-Umbau gelesen und mit gruener Suite belegt.
  Status: CONFIRMED

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: 23 passed, 0 failed, 0 uebersprungen (110 Einzelfaelle)
Edge cases: All checked, none broken
Regressions: None found
Checklist: 14/14 points proven

## Geprüfte Dateien

- sha256:bd7d6c3e45cbcaed9ae9be271cce398f0ab31bf9fa33cb41f6c900a09a20c8a8  LooseEnds/Claude/ServiceClient.swift

## Prüfbasis

- base: 5a09c81555226c1181f2dfee6a58b99f3d7d6e7a
- blob:cb4372135fea4e359785981ec0720ca4522babed  LooseEnds/Claude/ServiceClient.swift
