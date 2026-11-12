---
entity_id: feat-795-schnitt-2a-app-client
type: feature
created: 2026-11-12
updated: 2026-11-12
status: draft
workflow: feat-795-s2-app-client
---

# Spec: Die App-Wege im Client, Schnitt S2a (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S2a von sieben (S1, S1b, S2a, S2b, S3, S4, S5); das Issue bleibt offen (`Refs #795`, nie `Closes #795`): S2b (Gerätekennung und Zugang über `AccountState`), S3 (`ClaudeSync`) und S5 (Weckruf) folgen.
Analyse: `docs/context/feat-795-s2-app-client.md` (Abschnitt „Analysis“: Befunde, Empfehlung, Alternativen; verbindlich, hier auf S2a geschnitten).
Vorgänger: S1 (`docs/specs/feat-795-schnitt-1-dienst-wege.md`, die drei Wege im Dienst) und S1b (`docs/specs/feat-795-schnitt-1b-nginx.md`, nginx offen, 429-Regel im Vertrag „Wege der App“).
Es ist ein reiner App-Kern ohne Oberfläche: **zwei Dateien**, nichts in der App ruft die neuen Methoden auf.

## Für den PO

Die App bekommt das Stück, mit dem sie später ihre Aufgabenliste an den Dienst schickt, Aufträge von Claude abholt und Ergebnisse meldet. Dieser Schnitt baut nur die drei Aufrufe und die Regeln für Fehlerfälle; ausgelöst wird noch nichts, die App sendet also weiterhin keinen einzigen Byte mehr als heute. Für dich ändert sich nichts Sichtbares. Du musst nichts entscheiden und nichts tun.

Eine Sache habe ich eingebaut, die man leicht übersieht: Würde Claude einmal einen Auftrag schicken, den eine ältere App-Version nicht versteht, könnte sie ihn nie als „abgelehnt“ zurückmelden, und der Dienst reichte ihn alle zehn Minuten erneut heraus, endlos. Der Client rettet deshalb aus so einem Auftrag wenigstens die Kennung, damit die App ihn ablehnen kann.

## Purpose

`ServiceClient` kennt heute nur die drei Anmelde-Wege (`/auth/apple`, `/auth/logout`, `/auth/delete`). Der Dienst bietet seit S1 (live seit S1b) drei weitere: `POST /app/transcript`, `POST /app/orders/claim`, `POST /app/orders/result`. Dieser Schnitt ergänzt sie am Client, genau nach dem Vertrag „Wege der App“ (`docs/reference/claude-abschrift-vertrag.md`) und der Gegenstelle `server/src/app-routes.ts`:

| Methode am `ServiceClient` | Weg | Erfolg | Bemerkung |
|---|---|---|---|
| `putTranscript(_ transcript: Transcript, sessionToken: String)` | `POST /app/transcript` | 204 | Bearer, `Content-Type: application/json`, Körper nur aus `TranscriptCodec.encode`, kein `X-Device`; ein älteres Abbild ist für den Dienst ebenfalls 204 |
| `claimOrder(sessionToken: String, device: UUID) -> Claim` | `POST /app/orders/claim` | 204 oder 200 | Bearer, `X-Device` als UUID in Kleinbuchstaben, kein Körper |
| `putResult(_ result: OrderResult, sessionToken: String, device: UUID)` | `POST /app/orders/result` | 204 | Bearer, `X-Device`, `Content-Type: application/json`, Körper aus `TranscriptCodec.encode`; 409 → `ServiceError.refused` |

**`Claim`** (neu, in `ServiceClient.swift`): `enum Claim: Equatable, Sendable { case none; case order(Order); case unreadable(UUID) }`.

- 204 → `.none` (kein Auftrag offen).
- 200 mit Körper, der über `TranscriptCodec.decode(Order.self, …)` lesbar ist → `.order(Order)`. Der Dienst liefert das gespeicherte Auftragsdokument unverändert (`claimOrder` in `server/src/orders.ts` gibt `doc` zurück; Schlüssel `version`, `id`, `kind` und je nach Art `text`, `taskID`, `expectedStatus`, `date`, `hasTime`, `expectedDueDate`, `on`, `expectedNextRank`; `id` ist eine UUID als Text).
- 200 mit Körper, der kein gültiger `Order` ist (z. B. unbekannte `kind` aus einer späteren Dienstversion, unbekannter Status, fehlender Pflichtschlüssel), aber ein JSON-Objekt mit einem `id`, das eine UUID ist → `.unreadable(UUID)` („Giftauftrag“). S3 meldet dazu `rejected` mit Grund `invalid`, damit der Dienst den Auftrag nicht endlos zurückholt.
- 200 mit allem anderen (kein JSON, kein Objekt, kein `id`, `id` keine UUID, leerer Körper) → `ServiceError.invalidResponse`; ohne `id` kann kein Ergebnis gemeldet werden.

**`send` wird gemeinsam erweitert.** Neu: 429 → `ServiceError.tooManyRequests` (der Vertrag verlangt: Abholdurchgang sofort abbrechen, nie Schleife, nie Wiederholung im selben Durchgang). Neu: 409 → `ServiceError.refused` („Ergebnis zu einem Auftrag, den dieses Gerät nicht (mehr) hält“); 409 kommt in der Praxis nur von `/app/orders/result`, die Zuordnung steht trotzdem in `send`, weil es keine andere Bedeutung von 409 an diesen Wegen gibt. Unverändert: 401 `unauthorized`, 503 und jeder `URLError` außer `.cancelled` `unavailable`, abgebrochener `URLError` → `CancellationError`, sonstiger Status `rejected(Int)` (hier landen 400, 405, 413, 415, 500). Fehler tragen nie Token, Körper oder URL; ein Fehlerfall von `claimOrder` erwähnt weder den Körper noch das `id`.

**Eine Kodierung.** Körper werden ausschließlich über `TranscriptCodec.encode` (sortierte Schlüssel, ISO 8601 in ganzen Sekunden) erzeugt, gelesen über `TranscriptCodec.decode`; nirgends ein zweiter `JSONEncoder`. Zum Retten der Kennung beim Giftauftrag genügt `JSONSerialization` auf dem Körper (nur Lesen von `id` als Text, wie `signIn` es für `sessionToken` tut).

**Gerätekennung als Parameter.** `device: UUID` kommt von außen; `uuidString.lowercased()` geht in den Kopf `X-Device`. Woher die UUID stammt (Schlüsselbund, Erzeugen beim ersten Mal), ist S2b.

**Nichts wird aufgerufen.** Erzeugen oder Importieren löst keinen Netzverkehr aus; `AccountWiring`, `AccountState`, `UITestTransport` bleiben unberührt (der Test-Transport beantwortet weiter nur `auth/*`).

**Regeln vor Modell:** reine Netz- und Formatfrage ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 (Dienst für Claude, Weg B) und den Vertrag „Wege der App“ um, ohne sie zu ändern; keine neue Abhängigkeit, kein neues Verfahren, kein Schema.

- **Rationale:** Die Methoden folgen dem Muster der drei Anmelde-Wege (eine Methode, ein Erfolgsstatus, `send` bildet den Rest ab). 429 und 409 bekommen eigene Fälle, weil die App darauf **verschieden** reagieren muss (429: Durchgang abbrechen; 409: Ergebnis verwerfen, nichts wiederholen; 401: Sitzung räumen; 503/Netz: später wieder) und `rejected(Int)` diese Unterscheidung dem Aufrufer als Zahlenvergleich aufbürdete. Der Giftauftrag ist ein eigener Fall von `Claim` statt eines Fehlers, weil der Aufrufer mit der Kennung weiterarbeiten (ablehnen) soll, nicht mit einem Fehler aussteigen.

## Source

- **File:** `LooseEnds/Claude/ServiceClient.swift`
- **Identifier:** `ServiceClient.putTranscript`, `ServiceClient.claimOrder`, `ServiceClient.putResult`, `ServiceClient.Claim`, `ServiceError.tooManyRequests`, `ServiceError.refused`, `send(_:success:)`; Gegenstelle `appRoutes` in `server/src/app-routes.ts` (unverändert)

**Dateien:** `LooseEnds/Claude/ServiceClient.swift`, `LooseEndsTests/ServiceClientTests.swift`.
**Unberührt:** `server/`, `Shared/` (`Order`, `OrderResult`, `TranscriptCodec` werden nur benutzt), `AccountState`, `AccountWiring`, `project.yml`, `Info.plist`, Entitlements, alle Views.

### Schnittstelle und Festlegungen

- **Pfad und Methode:** immer `POST`, Pfade `app/transcript`, `app/orders/claim`, `app/orders/result` über dieselbe `request(path:)` wie bei den Anmelde-Wegen (Basis-URL mit oder ohne Schrägstrich oder Unterpfad wie dort).
- **Kopfzeilen:** `Authorization: Bearer <Token>` an allen dreien; `Content-Type: application/json` nur dort, wo ein Körper mitgeht (`transcript`, `result`); `X-Device` nur an `claim` und `result`, UUID in Kleinbuchstaben; `claim` sendet keinen Körper (`httpBody == nil`, kein `Content-Type`).
- **Statusabbildung** (gilt für alle drei Wege über `send`): Erfolgsstatus des Weges → Körper; 401 → `unauthorized`; 429 → `tooManyRequests`; 409 → `refused`; 503 → `unavailable`; `claim` mit 200 ist zusätzlich ein Erfolg (nur dort, `send` bekommt dafür die Menge `[200, 204]`); jeder andere Status → `rejected(Int)`. Eine Antwort, die zum Weg nicht passt (z. B. 200 bei `transcript`), ist `rejected(200)` wie bei den Anmelde-Wegen.
- **Giftauftrag:** Die Entscheidung `.order` / `.unreadable` / `invalidResponse` trifft eine kleine private Funktion am Client (≤ 25 Zeilen), geprüft in dieser Reihenfolge: erst `decode(Order.self)`, bei Fehler `JSONSerialization` → Objekt → `id` als `String` → `UUID(uuidString:)`; nichts davon wird protokolliert.
- **Sicherheit:** Kein Fehlerfall trägt den Token, den Körper oder die URL. Das Sitzungs-Token steht nur im Kopf `Authorization`, nie in URL, Körper oder Fehler.
- **Keine Wiederholung im Client:** weder bei 429 noch bei 503 versucht der Client es selbst noch einmal; Wiederholen ist Sache des Durchgangs (S3) und nur beim nächsten Anlass.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| Dienst mit den drei App-Wegen (`server/src/app-routes.ts`, S1) und offene Pfade in nginx (S1b) | bestehend |
| `TranscriptCodec`, `Transcript`, `Order`, `OrderResult` (`Shared/Services`) | bestehend, unverändert |
| `HTTPTransport`, `ServiceError`, `request(path:)`, `bearer(path:_:)`, `send` (`ServiceClient.swift`) | bestehend, `send` und `ServiceError` werden erweitert |
| `FakeTransport` in `ServiceClientTests` | bestehend |
| Downstream | S2b (`DeviceIdentity`, `AccountState.withSession`), S3 (`ClaudeSync`: senden, holen, ausführen, melden; bei `tooManyRequests` Abbruch, bei `.unreadable` Ergebnis `rejected/invalid`, bei `refused` Ergebnis verwerfen) |

## Acceptance Criteria

Jedes AC wird über einen benannten Test in `LooseEndsTests/ServiceClientTests.swift` (Swift Testing, `FakeTransport`) belegt; `Self.base` ist `https://example.test`, `Self.token` ein erkennbarer Dummy-Wert. Die vorhandenen Tests bleiben unverändert grün (die Statusabbildung der Anmelde-Wege ändert sich nur um 429 und 409).

- **AC-1:** Wire `transcript`: GIVEN ein `Transcript` und ein `FakeTransport` mit 204 WHEN `putTranscript(_:sessionToken:)` läuft THEN wird genau eine Anfrage gesendet: Methode `POST`, Pfad `/app/transcript`, `Authorization` gleich `Bearer <Token>`, `Content-Type` gleich `application/json`, kein `X-Device`, und `httpBody` ist byte-gleich `TranscriptCodec.encode(transcript)` (Test `putTranscriptWire`, Basis-URL mit und ohne Schrägstrich und mit Unterpfad als Argumente).
- **AC-2:** Wire `claim`: GIVEN ein `FakeTransport` mit 204 und die UUID `A1B2C3D4-E5F6-4711-8899-AABBCCDDEEFF` WHEN `claimOrder(sessionToken:device:)` läuft THEN ist die Anfrage `POST /app/orders/claim` mit `Authorization` gleich `Bearer <Token>`, `X-Device` gleich der Kleinschreibung `a1b2c3d4-e5f6-4711-8899-aabbccddeeff`, ohne Körper (`httpBody == nil`) und ohne `Content-Type`; die Rückgabe ist `.none` (Test `claimOrderWireAndNone`).
- **AC-3:** Wire `result`: GIVEN ein `OrderResult` und ein `FakeTransport` mit 204 und dieselbe UUID in Großschreibung WHEN `putResult(_:sessionToken:device:)` läuft THEN ist die Anfrage `POST /app/orders/result` mit `Authorization`, `X-Device` in Kleinbuchstaben, `Content-Type` gleich `application/json`, und `httpBody` ist byte-gleich `TranscriptCodec.encode(result)` (Test `putResultWire`).
- **AC-4:** Auftrag lesbar: GIVEN ein `FakeTransport` mit 200 und dem Körper `TranscriptCodec.encode(order)` für einen `Order` jeder der sechs Arten (`capture`, `complete`, `setDue`, `setNext`, `park`, `addSubtask`) WHEN `claimOrder` läuft THEN ist die Rückgabe `.order(order)`, gleich dem gesendeten (alle gesetzten Felder, auch `date` und `expectedDueDate` in ganzen Sekunden) (Test `claimOrderReadsEveryKind`, Argumente je Art).
- **AC-5:** Giftauftrag: GIVEN ein `FakeTransport` mit 200 und einem JSON-Objekt, das ein gültiges `id` (UUID) trägt, sich aber nicht als `Order` lesen lässt (unbekannte `kind` `"teleport"`; `kind` fehlt; falscher Typ in `hasTime`; unbekannter `expectedStatus`) WHEN `claimOrder` läuft THEN ist die Rückgabe `.unreadable(id)` mit genau dieser UUID, und der Aufruf wirft nicht (Test `claimOrderPoisonKeepsId`, Argumente je Fall).
- **AC-6:** Körper ohne rettbares `id`: GIVEN ein `FakeTransport` mit 200 und einem Körper, der kein JSON ist, ein leerer Körper, ein Array, ein Objekt ohne `id`, ein Objekt mit `id` als Zahl, ein Objekt mit `id` `"nicht-eine-uuid"` WHEN `claimOrder` läuft THEN wirft der Aufruf `ServiceError.invalidResponse` (Test `claimOrderWithoutIdIsInvalid`, Argumente je Fall).
- **AC-7:** 204 ist Erfolg, nichts sonst: GIVEN die Wege `transcript` und `result` mit 204 THEN kehren beide ohne Fehler zurück; GIVEN `transcript` und `result` mit 200 THEN `rejected(200)`; GIVEN `claim` mit 202 THEN `rejected(202)` (Test `successStatusPerRoute`).
- **AC-8:** 409 → `refused`: GIVEN `putResult` mit 409 WHEN er läuft THEN wirft er `ServiceError.refused` (nicht `rejected(409)`); dasselbe 409 an `transcript` und `claim` ergibt ebenfalls `refused` (Test `conflictIsRefused`).
- **AC-9:** 429 → `tooManyRequests`: GIVEN jeder der drei Wege mit 429 WHEN er läuft THEN wirft er `ServiceError.tooManyRequests` (nicht `rejected(429)`); der Client sendet dabei genau eine Anfrage, keine Wiederholung (Test `tooManyRequestsPerRoute`, `requests.count == 1`).
- **AC-10:** Übrige Status je Weg: GIVEN jeder der drei Wege WHEN der Dienst 401 antwortet THEN `unauthorized`; 503 THEN `unavailable`; 400, 413, 415, 405, 500 THEN je `rejected(<Status>)` (Test `statusMappingAppRoutes`, Argumente Weg × Status).
- **AC-11:** Transportfehler: GIVEN jeder der drei Wege WHEN der Transport `URLError` (`notConnectedToInternet`, `timedOut`, `cannotConnectToHost`) wirft THEN `unavailable`; GIVEN `URLError(.cancelled)` THEN `CancellationError`; GIVEN `CancellationError` THEN `CancellationError` (Tests `appRoutesTransportErrors`, `appRoutesCancelledIsCancellation`).
- **AC-12:** Keine Geheimnisse in Fehlern: GIVEN jeder der drei Wege und Antworten 401, 409, 429, 503, 500 und 200 mit einem Körper, der `SECRET-BODY` enthält (bei `claim` ein Auftrag mit lesbarem `id` und `SECRET-BODY` im Feld `text`, der als Fehler endet, und ein unlesbarer Körper mit `SECRET-BODY`) sowie ein `URLError` WHEN der Aufruf scheitert THEN enthält `String(describing: error)` weder den Token noch `SECRET-BODY` noch die URL `example.test` (Test `appRoutesErrorsCarryNoSecrets`).
- **AC-13:** Erzeugen und Importieren sendet nichts, Anmelde-Wege unverändert: GIVEN ein `FakeTransport` ohne Antworten WHEN ein `ServiceClient` erzeugt wird THEN ist `requests` leer (der bestehende Test `creatingSendsNothing` bleibt grün); GIVEN die bisherigen Tests der Anmelde-Wege THEN laufen sie unverändert grün, auch `statusMapping` mit 400, 405, 413, 415, 500 als `rejected` (Beleg: die gesamte Suite `ServiceClientTests` grün, kein bestehender Test geändert außer der Aufnahme von 409 und 429 in die Statusliste der Anmelde-Wege, siehe AC-14).
- **AC-14:** Auswirkung von 409 und 429 auf die Anmelde-Wege ist gewollt und belegt: GIVEN `signIn`, `logout`, `deleteAccount` WHEN der Dienst 429 antwortet THEN `tooManyRequests`, bei 409 `refused` (der bestehende Test `statusMapping` wird um die Fälle (Weg, 429, `.tooManyRequests`) und (Weg, 409, `.refused`) für alle drei Anmelde-Wege erweitert, Test `statusMapping`).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/ServiceClient.swift` | MODIFY | `Claim`, drei Methoden, zwei neue `ServiceError`-Fälle, `send` mit Menge von Erfolgsstatus und 409/429, Funktion zum Lesen des Auftrags; ≈ +65/−5 |
| `LooseEndsTests/ServiceClientTests.swift` | MODIFY | Tests zu AC-1 bis AC-14 (neue Wege, Giftauftrag, Statuslisten); ≈ +110/−5 |

### Estimated Changes

- **Dateien: 2.** Innerhalb des Limits von 4 bis 5 Dateien.
- **LoC: ≈ +175 / −10** (Code ≈ 60, Tests ≈ 110), innerhalb von ±250 LoC; keine Funktion über 50 Zeilen.
- Keine Permissions, keine `Info.plist`-Einträge, keine AppStorage-Keys, kein CloudKit-Schema, keine Audio-Dateien, keine Oberfläche, kein `generate`-Unterschied (keine neue Datei), keine neue Abhängigkeit.
- **Seiteneffekte nach außen:** keine. Nichts in der App ruft die drei Methoden auf; die App sendet nach diesem Schnitt nichts, was sie vorher nicht gesendet hat.
- **Parallele Arbeit:** vor dem PR `origin/main` und offene PRs auf Berührung von `ServiceClient.swift` prüfen (S2b ändert `AccountState` und legt `DeviceIdentity` an, nicht diese Datei).

## Risiken

- **429 und 409 gelten jetzt auch für die Anmelde-Wege.** Gemeinsames `send`. Gegengelesen: `AccountState.signInStatus(after:)` wertet `ServiceError` mit `unauthorized`, `unavailable` und einem `default` aus (kein erschöpfender `switch`), und `caseName` druckt nur den Fallnamen. Ein 429 bei der Anmeldung endet dort wie bisher `rejected(429)` im `default` (Status `signedOut`, Logzeile mit dem Fallnamen `tooManyRequests`), also ohne Verhaltensänderung und ohne Änderung an `AccountState`; der Test in AC-14 hält das fest.
- **Eigene Fälle, die eine spätere Dienstversion verschiebt.** Sollte der Dienst 409 künftig auch an `claim` oder `transcript` verwenden, trifft `refused` zu weit. Gegenmittel: Vertrag Version 1 hält es fest (S1, AC-4); eine Änderung wäre ein Vertragsschnitt mit Test.
- **Giftauftrag falsch eingeordnet.** Ein Auftrag mit gültigem `id`, aber fehlerhaftem Rest wird `.unreadable`; S3 meldet `rejected/invalid`. Ein Auftrag, der ohne `id` kommt, bleibt `invalidResponse` und wird vom Dienst nach 10 Minuten zurückgeholt; das ist ein Dienstfehler (der Dienst prüft Form und `id` vor dem Speichern, `checkOrder` in `server/src/orders.ts`), kein Clientfall.
- **Belegkraft.** Die Tests belegen Form und Abbildung gegen einen Stellvertreter-Transport, nicht den Durchlauf gegen den Live-Dienst mit echter Sitzung; der kommt mit S3.

## Test Plan

Unit-Tests (Swift Testing) in `LooseEndsTests/ServiceClientTests.swift`, Lauf: `./scripts/sim.sh sim-unit ServiceClientTests`, danach die ganze Suite `./scripts/sim.sh unit`. Keine UI-Tests: nichts Sichtbares ändert sich.

| Test | AC |
|---|---|
| `putTranscriptWire` | AC-1 |
| `claimOrderWireAndNone` | AC-2 |
| `putResultWire` | AC-3 |
| `claimOrderReadsEveryKind` | AC-4 |
| `claimOrderPoisonKeepsId` | AC-5 |
| `claimOrderWithoutIdIsInvalid` | AC-6 |
| `successStatusPerRoute` | AC-7 |
| `conflictIsRefused` | AC-8 |
| `tooManyRequestsPerRoute` | AC-9 |
| `statusMappingAppRoutes` | AC-10 |
| `appRoutesTransportErrors`, `appRoutesCancelledIsCancellation` | AC-11 |
| `appRoutesErrorsCarryNoSecrets` | AC-12 |
| `creatingSendsNothing` (bestehend) und die ganze Suite | AC-13 |
| `statusMapping` (erweitert) | AC-14 |

- [ ] Test 1 (AC-1 bis AC-3): GIVEN `FakeTransport` WHEN die drei Methoden laufen THEN Pfad, Methode, Kopfzeilen, Körper exakt wie festgelegt.
- [ ] Test 2 (AC-4 bis AC-6): GIVEN 200 mit lesbarem Auftrag, Giftauftrag oder Müll WHEN `claimOrder` läuft THEN `.order`, `.unreadable(id)` oder `invalidResponse`.
- [ ] Test 3 (AC-7 bis AC-10): GIVEN die Statuscodes 204, 200, 202, 401, 409, 429, 503, 400, 413, 415, 405, 500 WHEN die Wege laufen THEN die festgelegte Abbildung, bei 429 genau eine Anfrage.
- [ ] Test 4 (AC-11, AC-12): GIVEN `URLError`, Abbruch und Körper mit Geheimnis WHEN der Aufruf scheitert THEN `unavailable` oder `CancellationError`, und der Fehlertext ist sauber.
- [ ] Test 5 (AC-13, AC-14): GIVEN die ganze Suite WHEN sie läuft THEN grün, die Anmelde-Wege zeigen 429 und 409 wie festgelegt.

**Ehrlich zur Belegkraft:** TDD-Reihenfolge: die Tests werden vor dem Code geschrieben (RED: Kompilierfehler oder rot, weil `putTranscript`, `claimOrder`, `putResult`, `Claim`, `tooManyRequests`, `refused` fehlen), dann der Code (GREEN).

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): `Claim` mit `.unreadable(UUID)`, eigene Fälle `tooManyRequests` und `refused`** | siehe Purpose | S3 kann einen Giftauftrag ablehnen; die Reaktionen auf 429, 409, 401, 503 sind je ein Fallvergleich; der Dienst holt nichts endlos zurück | ein zusätzlicher Rückgabefall und zwei Fehlerfälle; gemeinsame `send` ändert auch die Anmelde-Wege (siehe Risiken) | nichts; keine ADR |
| **B Giftauftrag nur als `invalidResponse`** (Standard, keine `id` gerettet) | kleinster Client | einfachster Code | ohne `id` kein Ergebnis meldbar: der Dienst reicht den Auftrag nach zehn Minuten (Vertrag „Rückholen“) wieder heraus, jede App-Version, die ihn nicht lesen kann, fragt ihn alle zehn Minuten erneut ab und kommt nie weiter; die Warteschlange hinter ihm bliebe bei jedem `claim` an derselben Stelle stehen (ältester zuerst) | „Auftrag ohne Ergebnis wird zurückgeholt“ (Vertrag S1, Rückholregel); verworfen |
| **C 429 als `rejected(429)` belassen** | `ServiceError` bleibt klein | keine neue Fallzahl | die Pflicht „Durchgang sofort abbrechen“ (S1b, Vertrag) wäre ein Zahlenvergleich im Aufrufer, leicht zu vergessen; ein vergessener Fall wäre genau der Weg zur Stundensperre der Heim-Adresse (fail2ban, zehn Treffer) | die Abbruchregel aus S1b bliebe Konvention statt Typ; verworfen |
| **D Auftrag über einen eigenen Decoder mit „tolerantem“ Rest** (unbekannte `kind` → `Order` mit `kind = .unknown`) | ein Weg statt zwei | ein Rückgabewert | ändert `Order` in `Shared/` (Vertrag Version 1, Dienst und App teilen die Arten), erzwingt ein Sonderfall in `OrderExecutor` | `Order`/Vertrag Version 1; verworfen |
| **E Gerätekennung im Client erzeugen** (Teil dieses Schnitts) | ein Schnitt statt zwei | keine Parameterweitergabe | Schlüsselbund, Fehlerfälle und `AccountState` brächten den Schnitt über 4 bis 5 Dateien; der Client soll zustandslos bleiben | Schnittgröße, siehe S2b; **die Wahl der Ablage (Schlüsselbund `AfterFirstUnlockThisDeviceOnly` gegen `UserDefaults` gegen vom Dienst vergeben) ist S2b** und folgt der Analyse (Schlüsselbund, wegen Backup-Doppelkennung bei `UserDefaults`) |

## Out of Scope / Folgeschnitte

- **S2b:** `DeviceIdentity` (Kennung im Schlüsselbund, `AfterFirstUnlockThisDeviceOnly`, erzeugen-falls-fehlt, Lesefehler ist Fehler und erzeugt nie still eine neue Kennung) und `AccountState.withSession` (ohne Token nichts senden, 401 räumt die Sitzung nur bei gleichem Token); Tests `DeviceIdentityTests` und `AccountStateTests`. Nicht Teil dieser Spec.
- **S3:** `ClaudeSync` (Durchgang: senden, holen, `OrderExecutor`, melden; Abbruch bei `tooManyRequests`; `.unreadable` → `rejected/invalid`; `refused` verwerfen) und die Auslöser; **S5:** Weckruf.
- **Gebündeltes Abholen** (Alternative C aus S1b): eigener Dienstschnitt, erst nach Messung in S3.
- Änderungen an `server/`, `Shared/`, Widgets, Watch, Mac-Fenster, `project.yml`: keine.

## Abnahme

**Kein Pfad der Geräteliste berührt.** (`LooseEnds/Claude/` und `LooseEndsTests/` stehen nicht darin; kein `project.yml`, keine Entitlements, keine `Info.plist`.) Die Abnahme endet nach Stufe 2: Stufe 1 sind die Unit-Tests (neue und bestehende, `./scripts/sim.sh unit`), Stufe 2 der Beleg „App startet unverändert im Simulator“ (`./scripts/sim.sh build`, `launch`, `screenshot` und der maschinelle Beleg `./scripts/sim.sh test-proof <Klasse>` einer bestehenden Smoke-Klasse); sichtbar ändert sich nichts, und das wird im Abschlussbericht gesagt. Gerätepunkte gibt es in diesem Schnitt nicht; die App ruft die Wege erst ab S3.

## Definition of Done

- [ ] AC-1 bis AC-14 erfüllt, jeder über seinen benannten Test; Tests vor dem Code geschrieben (RED belegt)
- [ ] `./scripts/sim.sh unit` grün (gesamte Suite), Build erfolgreich
- [ ] Stufe 2: App startet unverändert im Simulator, Beleg liegt vor
- [ ] Kein Token, Körper oder URL in einem Fehlertext (AC-12)
- [ ] Doku (keine Codedatei, zählt nicht zum Dateilimit): `CLAUDE.md` im Absatz `LooseEnds/Claude` um die drei Wege, `Claim`, `tooManyRequests`, `refused` ergänzt (eine Zeile, Hotspot, vor dem PR gegen `origin/main` abgleichen); Abschnitt „Wege der App“ im Vertrag nennt den Client-Stand (S2a) nicht neu, weil er sich nicht ändert
- [ ] PR mit `Refs #795`, CI grün, Merge durch Claude; #795 kommentiert (Stand S2a, Folge S2b), Board-Karte aktuell, Memory geschrieben

## Known Limitations

Keine bekannt zum Zeitpunkt des Schreibens. Der Durchlauf gegen den Live-Dienst mit echter Sitzung ist nicht Teil dieses Schnitts (S3).

## Changelog

- 2026-11-12: Initial spec created (Schnitt S2a)
