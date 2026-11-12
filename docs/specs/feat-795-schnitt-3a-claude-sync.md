---
entity_id: feat-795-schnitt-3a-claude-sync
type: feature
created: 2026-11-12
updated: 2026-11-12
status: draft
workflow: feat-795-s3-claude-sync
---

# Spec: ClaudeSync-Durchgang, Schnitt S3a (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S3a von acht (S1, S1b, S2a, S2b, S3a, S3b, S4, S5); das Issue bleibt offen (`Refs #795`, nie `Closes #795`): S3b (Auslöser, Verdrahtung, Nachweis mit zwei Simulatoren) und S5 (Weckruf, Hintergrund-Auffrischen) folgen.
Analyse: `docs/context/feat-795-s3-claude-sync.md` (Abschnitte „Analysis“, „Reaktionstabelle des Durchgangs“, „Schnittvorschlag“, „Alternativen“; verbindlich, mit den Abweichungen unter „Abweichungen von der Analyse“).
Vorgänger: S2a (`docs/specs/feat-795-schnitt-2a-app-client.md`, die drei App-Wege am `ServiceClient`) und S2b (`docs/specs/feat-795-schnitt-2b-device-identity.md`, `DeviceIdentity` und `AccountState.withSession`); beide nennen S3 als ersten Aufrufer.
Es ist ein reiner App-Kern ohne Oberfläche: **zwei Dateien**, nichts in der App ruft `ClaudeSync` auf.

## Für den PO

Die App bekommt den Ablauf, mit dem sie später dem Dienst für Claude ihre Aufgabenliste zeigt, offene Aufträge von Claude abholt, ausführt und das Ergebnis zurückmeldet. In diesem Schnitt ist der Ablauf nur gebaut und gründlich geprüft, die App benutzt ihn noch nicht: Wann er läuft (beim Start, beim Zurückkehren in die App, nach dem Speichern), kommt im nächsten Schnitt.

Für dich ändert sich nichts Sichtbares, die App sendet weiterhin nichts mehr als heute. Du musst nichts entscheiden und nichts tun.

## Purpose

S2a hat die Wege am `ServiceClient` geliefert, S2b die Gerätekennung und den einzigen Zugang `AccountState.withSession`. Dieser Schnitt setzt daraus den Durchgang zusammen, ohne ihn aufzurufen: `ClaudeSync` (neu, `LooseEnds/Claude/ClaudeSync.swift`), `@MainActor final class ClaudeSync`.

**Abhängigkeiten werden eingereicht** (`init(account:container:device:execute:now:calendar:)`): der `AccountState`, der `ModelContainer` (ausgeführt wird auf `container.mainContext`), eine Closure `device: () throws -> UUID` (in S3b `DeviceIdentity().current`; keine Änderung an `DeviceIdentity.swift`), eine Closure `execute: (Order, ModelContext, Date, Calendar) throws -> OrderResult` mit dem Standardwert `OrderExecutor.execute` (einzige Testnaht für den Ausführungsfehler, AC-8; alle anderen Tests laufen durch den echten `OrderExecutor`), `now: () -> Date` und `calendar: Calendar`. Jeder Netzaufruf geht über `account.withSession`; ohne Sitzung geschieht nichts.

**Rückgabe.** Beide Durchgänge liefern `Ending` (Equatable, Sendable): `notSignedIn` (`withSession` gab `nil`), `busy` (Wiedereintrittssperre), `done`, `limitReached` und `stopped(Stop)`. `Stop` (String-Enum, `rawValue` = Fallname, auch das Logwort): `unauthorized`, `tooManyRequests`, `unavailable`, `serviceError` (`rejected(_)` und `invalidResponse`), `cancelled`, `deviceIdentity`, `storeUnreadable` (die Aufgaben ließen sich nicht lesen), `executionFailed`. Der Rückgabewert dient den Tests und S3b; nichts im Durchgang hängt davon ab.

**1. `sendTranscript() async -> Ending`.** Liest alle `TaskItem` aus `mainContext` (`FetchDescriptor<TaskItem>()`), baut `TranscriptCodec.transcript(of:now:calendar:)` und schickt sie mit `putTranscript` über `withSession`. Ein Lesefehler wird geloggt und ergibt `stopped(.storeUnreadable)` ohne Anfrage (im In-Memory-Container nicht herbeiführbar, daher ohne eigenen Test; siehe Known Limitations). `204` ergibt `done` (auch wenn der Dienst eine neuere Abschrift hat, das entscheidet er). Fehler wie in der Tabelle unten.

**2. `pullOrders() async -> Ending`.** Die Schleife, je Durchlauf ein `claimOrder` über `withSession`:

| Fall | Reaktion |
|---|---|
| `withSession` gibt `nil` (nicht angemeldet; auch mitten im Durchgang, wenn die Sitzung weg ist) | `notSignedIn`, keine Anfrage mehr |
| `device()` wirft (Schlüsselbund vor dem ersten Entsperren, kaputter Eintrag) | `stopped(.deviceIdentity)`, keine Anfrage |
| `Claim.none` | `done` |
| `Claim.order(order)` | `OrderExecutor.execute(order, in: mainContext, now:, calendar:)` → `putResult` |
| `Claim.unreadable(id)` | `putResult(OrderResult(orderID: id, outcome: .rejected, reason: .invalid, taskID: nil))`, nichts ausgeführt |
| `execute` wirft (Speichern scheitert, `OrderExecutor` rollt zurück) | **kein** Ergebnis gemeldet, `stopped(.executionFailed)` |
| `putResult` wirft `refused` (409) | Ergebnis verwerfen (die lokale Änderung bleibt), weiter mit dem nächsten `claim` |
| 15 Aufträge in diesem Durchgang erledigt (`maxOrdersPerPass`) | `limitReached`, kein weiteres `claim` |
| `unauthorized` | `stopped(.unauthorized)` (`withSession` hat die Sitzung schon geräumt) |
| `tooManyRequests` (429) | `stopped(.tooManyRequests)` sofort, keine weitere Anfrage, keine Wiederholung |
| `unavailable` | `stopped(.unavailable)` |
| `rejected(_)`, `invalidResponse` | `stopped(.serviceError)` |
| `CancellationError` | `stopped(.cancelled)` |

Die Gerätekennung wird höchstens einmal je Durchgang gelesen, träge innerhalb des ersten `withSession`-Aufrufs (ohne Sitzung wird der Schlüsselbund nicht angefasst), und dann in einer lokalen Variable gehalten; es gibt keinen Zwischenspeicher über Durchgänge hinweg (wie `DeviceIdentity`). Der Durchgang liest die Kennung also nie, wenn `withSession` ohne Sitzung `nil` gibt.

**Warum Ausführungsfehler den Durchgang beenden.** Meldet die App kein Ergebnis, gibt der Dienst denselben Auftrag demselben Gerät beim nächsten `claim` sofort zurück (Vertrag „Rückholen“ (d)). „Holen, bis keiner mehr da ist“ liefe dann im selben Durchgang endlos; der Dienst holt den Auftrag nach zehn Minuten ohnehin zurück. Ein Ausführungsfehler wird deshalb nie als `invalid` gemeldet (er wäre keine Eigenschaft des Auftrags).

**Obergrenze 15.** nginx lässt je Adresse einen Stoß von 40 Anfragen zu (Vertrag „Mengengrenze“); je Auftrag gibt es höchstens zwei Anfragen (`claim`, `result`), nach dem 15. Auftrag folgt kein weiteres `claim`: ein Holdurchgang hat höchstens 30 Anfragen, mit einer Abschrift aus demselben Anlass 31. Der Rest wartet auf den nächsten Anlass. Die Grenze zählt jeden behandelten Auftrag, auch einen `unreadable` und einen mit verworfenem Ergebnis (409).

**Wiedereintrittssperre.** `sendTranscript` und `pullOrders` haben je ein Merkflag auf dem Main Actor, das vor dem ersten `await` gesetzt und in jedem Ausgang (auch bei Abbruch) zurückgenommen wird. Ruft jemand denselben Durchgang auf, während er läuft, kommt sofort `busy` zurück und es geht keine Anfrage hinaus. Dass `execute` selbst speichert und damit später eine neue Abschrift anstößt, ist gewollt (Claude sieht das Ergebnis); das Holen hängt nie am Speichern, das ist Sache von S3b.

**Log.** `Logger(subsystem: "com.henning.looseends", category: "claude-sync")`; jede Zeile trägt nur Fallnamen (`Stop.rawValue`, `String(describing: type(of: error))`), nie Token, Gerätekennung, Körper, Auftrags- oder Aufgabentext. Kein `try?`; jeder Fehler wird behandelt oder geloggt und in ein `Stop` abgebildet.

**Nichts wird aufgerufen.** `LooseEndsApp`, `AccountWiring`, `WidgetReload`, `BackgroundRefresh`, `UITestTransport` und `DeviceIdentity.swift` bleiben unberührt; die App sendet nach diesem Schnitt nichts, was sie vorher nicht gesendet hat.

**Abweichungen von der Analyse** (nach dem Code gerichtet): (1) Die Analyse nennt pauschal eine Revision „Claude“; `OrderExecutor` schreibt sie nur bei `setDue` (`complete`, `setNext`, `park`, `capture` schreiben keine), daher prüft AC-5 sie an `setDue`. (2) `OrderExecutor.refuse` ist privat; das Ergebnis für einen unlesbaren Auftrag baut `ClaudeSync` direkt als `OrderResult(orderID: id, outcome: .rejected, reason: .invalid, taskID: nil)`. (3) Statt eines Speicherfehlers im Container prüft AC-8 den Ausführungsfehler über die eingereichte `execute`-Closure.

**Regeln vor Modell:** reine Ablauflogik ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 (Dienst für Claude, Weg B) und den Vertrag „Wege der App“ (`docs/reference/claude-abschrift-vertrag.md`: 429 bricht den Durchgang ab, Rückholen nach 10 Minuten, 409) um, ohne sie zu ändern; keine neue Abhängigkeit, kein neues Verfahren, kein Schema.

- **Rationale:** Der Durchgang ist als eigene Klasse mit eingereichten Abhängigkeiten gebaut, damit jede Zeile der Reaktionstabelle mit einem Stellvertreter-Transport und einem Speicher-Container geprüft werden kann, bevor ein Auslöser sie je aufruft. Die Fehlerbehandlung folgt dem Vertrag: so wenige Anfragen wie möglich, nie in einer Schleife wiederholen, der Dienst ist die Wahrheit über Vergabe und Rückholung.

## Source

- **File:** `LooseEnds/Claude/ClaudeSync.swift` (neu)
- **Identifier:** `ClaudeSync`, `ClaudeSync.Ending`, `ClaudeSync.Stop`, `ClaudeSync.maxOrdersPerPass`, `sendTranscript()`, `pullOrders()`; benutzt `AccountState.withSession`, `ServiceClient` (`putTranscript`, `claimOrder` → `Claim`, `putResult`), `ServiceError`, `OrderExecutor.execute`, `Order`, `OrderResult`, `TranscriptCodec`, `TaskItem`

**Dateien:** `LooseEnds/Claude/ClaudeSync.swift` (neu), `LooseEndsTests/ClaudeSyncTests.swift` (neu).
**Unberührt:** `DeviceIdentity.swift`, `AccountState.swift`, `ServiceClient.swift`, `AccountWiring.swift`, `LooseEndsApp.swift`, `LooseEnds/Notifications/`, `Shared/`, `server/`, `project.yml`, `Info.plist`, Entitlements, alle Views.

### Schnittstelle und Festlegungen

- **Ausführen auf dem Main Actor** über `container.mainContext`; `now()` wird je Auftrag beziehungsweise je Abschrift gerufen, `calendar` ist der eingereichte Wert; nie `Date()` im Durchgang.
- **Nutzeränderung „Claude“:** das Ausführen ist `OrderExecutor.execute` unverändert; dessen Revisionen tragen `author == .user` und `reason == "Claude"` (nachweisbar am Auftrag `setDue`; `complete`, `setNext`, `park` und `capture` schreiben keine Revision, siehe `OrderExecutor`).
- **Gerät:** `X-Device` kommt aus der eingereichten Closure, die UUID wird vom `ServiceClient` in Kleinschreibung geschickt (S2a).
- **Keine Wiederholung, kein Warten:** nach keinem Fehler gibt es einen zweiten Versuch im selben Durchgang, kein `Task.sleep`, keinen Timer; Anlässe kommen von außen (S3b, S5).
- **Reihenfolge je Auftrag:** erst ausführen und speichern (`execute`), dann melden. Scheitert das Melden mit einem anderen Fehler als 409, bleibt die lokale Änderung; der Dienst holt den Auftrag nach zehn Minuten zurück und das Gerät sieht dann `stale` (Vertrag (c)); `capture` kann dabei doppelt erfasst werden (bekannte Grenze des Vertrags, kein Fix in S3a).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `AccountState.withSession` (`LooseEnds/Claude/AccountState.swift`, S2b) | bestehend, unverändert |
| `ServiceClient.putTranscript`, `claimOrder`, `putResult`, `Claim`, `ServiceError` (S2a) | bestehend, unverändert |
| `DeviceIdentity.current()` (S2b) | bestehend, unverändert; nur als Closure eingereicht (in S3a nur Stellvertreter) |
| `OrderExecutor.execute`, `Order`, `OrderResult` (`Shared/Services/OrderExecutor.swift`) | bestehend, unverändert |
| `TranscriptCodec.transcript(of:now:calendar:)` (`Shared/Services/TranscriptCodec.swift`) | bestehend, unverändert |
| `AccountStateTests.Wire` (actor-Transport mit Antwortfolge und Aufrufprotokoll) und `InMemorySessionStore` | bestehend; `ClaudeSyncTests` bringt einen eigenen `FakeTransport` mit Antworten je Pfad (Body, Status, Fehler), weil `Wire` keine Antwortkörper für Aufträge kennt |
| Downstream | S3b (Auslöser, Verdrahtung, A/B-Nachweis), S5 (Weckruf und Hintergrund-Auffrischen rufen denselben `pullOrders`) |

## Acceptance Criteria

Jedes AC wird über einen benannten Test in `LooseEndsTests/ClaudeSyncTests.swift` belegt (Swift Testing, `@Suite @MainActor`, wie die Vorgängerspecs). Die Tests nutzen einen `FakeTransport` (protokolliert jede Anfrage mit Pfad, Header und Körper und antwortet aus einer Folge je Pfad), `InMemorySessionStore(token:)`, einen `AccountState` darüber und einen In-Memory-Container (`ModelContainerFactory.make(inMemory: true)`, im Test gehalten, damit der Kontext lebt). Die vorhandenen Tests bleiben unverändert grün.

- **AC-1:** Ohne Sitzung kein Aufruf: GIVEN ein `AccountState` im Status `signedOut` (leerer Store) WHEN `sendTranscript()` und `pullOrders()` laufen THEN ist jede Rückgabe `notSignedIn`, der `FakeTransport` hat keine Anfrage erhalten und die `device`-Closure wurde nie gerufen (Test `withoutSessionNothingIsSent`).
- **AC-2:** Abschrift: GIVEN `signedIn`, ein Container mit drei Aufgaben (offen, erledigt, entfernt) WHEN `sendTranscript()` läuft und der Dienst 204 antwortet THEN ist die Rückgabe `done`, genau eine Anfrage `POST app/transcript` mit dem Bearer-Token des Stores ging hinaus, und ihr Körper ist byte-gleich `TranscriptCodec.encode(TranscriptCodec.transcript(of: <alle drei>, now: <eingereichte Uhr>, calendar: <eingereichter Kalender>))` (Test `transcriptIsBuiltFromAllTasksAndSent`).
- **AC-3:** Abschrift, Fehler: GIVEN `signedIn` und der Dienst antwortet auf `transcript` 401, 429, 503, 400 (`rejected`), oder der Transport wirft `CancellationError` WHEN `sendTranscript()` läuft THEN ist die Rückgabe der Reihe nach `stopped(.unauthorized)`, `stopped(.tooManyRequests)`, `stopped(.unavailable)`, `stopped(.serviceError)`, `stopped(.cancelled)`; es geht genau eine Anfrage hinaus; nach 401 ist der Status `signedOut` (Test `transcriptErrorsEndThePass`, Argumente je Fall).
- **AC-4:** Nichts offen: GIVEN `signedIn` und `claim` antwortet 204 WHEN `pullOrders()` läuft THEN ist die Rückgabe `done`, genau eine Anfrage `POST app/orders/claim` ging hinaus, mit `X-Device` gleich der eingereichten UUID in Kleinschreibung und dem Bearer-Token, und kein `result` (Test `emptyClaimEndsThePass`).
- **AC-5:** Auftrag ausführen und melden: GIVEN `signedIn`, eine Aufgabe mit Fälligkeit und `claim` liefert einen Auftrag `setDue` (erwarteter Stand passt), danach 204, `result` antwortet 204 WHEN `pullOrders()` läuft THEN ist die Rückgabe `done`, die Aufgabe im Container hat das neue Datum, es gibt genau eine Revision mit `field == .dueDate`, `author == .user` und `reason == "Claude"`, und der `result`-Körper ist `OrderResult(orderID:, outcome: .done, taskID:)` des Auftrags; die Anfragen kamen in der Reihenfolge `claim`, `result`, `claim` (Test `orderIsExecutedAsClaudeAndReported`).
- **AC-6:** Mehrere Aufträge: GIVEN `claim` liefert nacheinander zwei Aufträge `capture`, dann 204 WHEN `pullOrders()` läuft THEN ist die Rückgabe `done`, zwei neue Aufgaben liegen im Container, und die Anfragen sind genau `claim`, `result`, `claim`, `result`, `claim` (Test `loopContinuesUntilNothingIsLeft`).
- **AC-7:** Nicht lesbarer Auftrag: GIVEN `claim` liefert 200 mit einem JSON-Objekt, dessen `id` lesbar ist, dessen übrige Felder `Order` nicht entsprechen (`Claim.unreadable(id)`) WHEN `pullOrders()` läuft THEN geht ein `result` mit `OrderResult(orderID: id, outcome: .rejected, reason: .invalid, taskID: nil)` hinaus, der Container ist unverändert (keine neue Aufgabe, keine Revision), und der Durchgang holt weiter (Test `unreadableOrderIsRejectedAsInvalid`).
- **AC-8:** Ausführungsfehler: GIVEN `claim` liefert einen `capture`-Auftrag und die eingereichte `execute`-Closure wirft (steht für einen gescheiterten Speichervorgang, nach dem `OrderExecutor` zurückrollt) WHEN `pullOrders()` läuft THEN ist die Rückgabe `stopped(.executionFailed)`, es ging **kein** `result` und kein zweites `claim` hinaus (Test `executionFailureReportsNothingAndEndsThePass`).
- **AC-9:** Dienst verwirft das Ergebnis: GIVEN `claim` liefert einen Auftrag `capture`, `result` antwortet 409, das nächste `claim` 204 WHEN `pullOrders()` läuft THEN ist die Rückgabe `done`, die lokal erfasste Aufgabe bleibt, und es folgt ein zweites `claim` (Test `refusedResultIsDroppedAndPassContinues`).
- **AC-10:** 429 bricht sofort ab: GIVEN `claim` antwortet 429 (erste Anfrage) oder `result` antwortet 429 (nach einem ausgeführten Auftrag) WHEN `pullOrders()` läuft THEN ist die Rückgabe `stopped(.tooManyRequests)`, und es ging keine weitere Anfrage hinaus, nach dem 429 weder `claim` noch `result` (Test `tooManyRequestsEndsAtOnce`, Argumente je Stelle).
- **AC-11:** Weitere Fehler beenden den Durchgang: GIVEN `signedIn` und die erste Anfrage `claim` scheitert mit 401, 503, 500, einer unlesbaren Antwort (`invalidResponse`) oder `CancellationError` WHEN `pullOrders()` läuft THEN ist die Rückgabe der Reihe nach `stopped(.unauthorized)`, `stopped(.unavailable)`, `stopped(.serviceError)`, `stopped(.serviceError)`, `stopped(.cancelled)`, es ging genau eine Anfrage hinaus; bei 401 ist der Status danach `signedOut` und der Store leer (Test `otherErrorsEndThePass`, Argumente je Fall).
- **AC-12:** Fehler beim Melden: GIVEN ein ausgeführter Auftrag und `result` antwortet 503 oder 500 WHEN `pullOrders()` läuft THEN endet der Durchgang mit `stopped(.unavailable)` beziehungsweise `stopped(.serviceError)`, die lokale Änderung bleibt, es folgt kein weiteres `claim` (Test `resultFailureEndsThePassAndKeepsTheChange`, Argumente je Status).
- **AC-13:** Kennungsfehler: GIVEN `signedIn` und `device()` wirft WHEN `pullOrders()` läuft THEN ist die Rückgabe `stopped(.deviceIdentity)`, es ging keine Anfrage hinaus, und die Closure wurde genau einmal gerufen (Test `deviceIdentityFailureEndsWithoutRequest`).
- **AC-14:** Kennung einmal je Durchgang: GIVEN `signedIn` und ein Durchgang mit zwei Aufträgen WHEN `pullOrders()` läuft THEN wurde `device()` genau einmal gerufen und alle fünf Anfragen (`claim`, `result`, `claim`, `result`, `claim`) tragen dieselbe `X-Device`; ein zweiter Durchgang ruft `device()` erneut (kein Zwischenspeicher) (Test `deviceIsReadOncePerPass`).
- **AC-15:** Obergrenze: GIVEN `claim` liefert dauerhaft `capture`-Aufträge und `result` antwortet 204 WHEN `pullOrders()` läuft THEN ist die Rückgabe `limitReached`, genau 15 Aufträge wurden ausgeführt (15 neue Aufgaben), genau 30 Anfragen (15 `claim`, 15 `result`) gingen hinaus, kein 16. `claim`, und `ClaudeSync.maxOrdersPerPass == 15` (Test `passStopsAtFifteenOrders`).
- **AC-16:** Wiedereintrittssperre: GIVEN `signedIn` und ein `claim`, der im Transport hängt (Hook hält die Antwort an) WHEN `pullOrders()` ein zweites Mal gerufen wird, solange der erste läuft THEN ist die Rückgabe des zweiten `busy` ohne eine eigene Anfrage; nach dem Ende des ersten startet ein dritter Aufruf wieder einen Durchgang; dasselbe für `sendTranscript()`; beide Durchgänge sperren einander nicht (Test `secondConcurrentCallDoesNotStartAPass`).
- **AC-17:** Sperre wird immer frei: GIVEN ein Durchgang endet mit `stopped(...)`, `notSignedIn` oder `limitReached` WHEN derselbe Durchgang danach erneut gerufen wird THEN läuft er (nicht `busy`) (Test `lockIsReleasedAfterEveryEnding`, Argumente je Ausgang).
- **AC-18:** Sitzung fällt mitten im Durchgang weg: GIVEN `signedIn` und nach dem ersten Auftrag leert der Hook den Store WHEN `pullOrders()` weiterläuft THEN ist die Rückgabe `notSignedIn`, und nach dem Wegfall ging keine Anfrage mehr hinaus (Test `sessionLostMidPassEndsQuietly`).
- **AC-19:** Keine Geheimnisse im Log: GIVEN jeder Fehlerfall aus AC-3, AC-8 bis AC-13 THEN enthält `String(describing: <Rückgabe>)` und jeder `Stop.rawValue` nur Fallnamen (keine Token-, UUID- oder Textzeichenkette aus dem Test), und `ClaudeSync.swift` enthält weder `try?` noch `print(` (Test `endingsCarryNoSecrets`; die Quellsuche als Beleg im Abschlussbericht).
- **AC-20:** Nichts wird aufgerufen: GIVEN die ganze Unit-Suite WHEN sie läuft THEN ist sie grün, und `rg "ClaudeSync" LooseEnds LooseEndsWatch LooseEndsWidgets LooseEndsShare Shared` findet außerhalb von `ClaudeSync.swift` keinen Treffer (Beleg im Abschlussbericht; Test: bestehende `creatingSendsNothing` in `ServiceClientTests` und die `AccountWiring`-Tests grün).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/ClaudeSync.swift` | CREATE | `ClaudeSync`, `Ending`, `Stop`, `sendTranscript()`, `pullOrders()`, Sperren, Log; ≈ +130 |
| `LooseEndsTests/ClaudeSyncTests.swift` | CREATE | `FakeTransport`, Aufbau mit In-Memory-Container und -Store, Tests zu AC-1 bis AC-19; ≈ +440 |

### Estimated Changes

- **Dateien: 2** (beide neu). Innerhalb des Limits von 4 bis 5 Dateien.
- **LoC: ≈ +570** (Code ≈ 130, Tests ≈ 440). Schätzung nach den Erfahrungswerten dieses Repos für Status-Tabellen mit Stellvertreter-Transport: ≈ 20 Zeilen je AC (19 Test-ACs, mehrere mit Argumenten je Fall) plus ≈ 60 Zeilen Attrappe und Aufbau. **Überschreitung der 250 LoC, fast ganz durch Tests**; der Code allein liegt bei ≈ 130, keine Funktion über 50 Zeilen (die Schleife von `pullOrders` ist in kleine Hilfsfunktionen für „Auftrag behandeln“ und „Fehler auf `Stop` abbilden“ geteilt). Die Überschreitung nimmt der PO vor dem Bauen per `AskUserQuestion` an (gemeinsam mit der Spec-Freigabe), sonst wird der Schnitt geteilt; **Meldeschwelle 650 LoC**: liegt der Stand nach RED oder GREEN darüber, wird vor dem Weiterbauen erneut gefragt.
- Keine Permissions, keine `Info.plist`-Einträge, keine AppStorage-Keys, kein CloudKit-Schema, keine Audio-Dateien, keine Oberfläche, keine neue Abhängigkeit. `generate` muss laufen, weil zwei Dateien neu sind (CLAUDE.md, Build).
- **Seiteneffekte nach außen:** keine. Nichts in der App ruft `ClaudeSync` auf; es entsteht kein Netzverkehr und kein Schlüsselbund-Zugriff, die App sendet nach diesem Schnitt nichts, was sie vorher nicht gesendet hat.
- **Parallele Arbeit:** vor dem PR `origin/main` und offene PRs auf Berührung von `LooseEnds/Claude/` prüfen; `CLAUDE.md` ist Hotspot.

## Risiken

- **Endlosschleife bei Ausführungsfehler.** Ohne Ergebnis käme derselbe Auftrag sofort zurück; deshalb beendet `executionFailed` den Durchgang (AC-8). Der Dienst holt nach zehn Minuten zurück.
- **Mengengrenze am nginx.** 15 Aufträge bleiben unter dem Stoß von 40 (AC-15); jedes 429 beendet den Durchgang sofort (AC-10), sonst droht die Stundensperre der Adresse für alle Dienste des Servers (Vertrag „Mengengrenze“).
- **Doppelte Ausführung.** „Mindestens einmal“ (Vertrag (c)): ein `capture` kann doppelt erfasst werden, wenn das Melden scheitert und der Dienst zurückholt (AC-12); bekannte Grenze, nicht Teil dieses Schnitts.
- **Rückkopplung.** `execute` speichert und stößt in S3b eine entprellte Abschrift an; das Holen hängt nie am Speichern. In S3a gibt es keinen Auslöser, die Frage entsteht erst mit S3b.
- **Belegkraft.** Die Tests belegen den Ablauf gegen einen Stellvertreter-Transport und einen Speicher-Container; der Durchlauf gegen den echten Dienst und die echte Gerätekennung kommt mit dem A/B-Nachweis in S3b.

## Test Plan

Unit-Tests (Swift Testing) in `LooseEndsTests/ClaudeSyncTests.swift`. Lauf: `./scripts/sim.sh sim-unit ClaudeSyncTests`, danach die ganze Suite `./scripts/sim.sh unit`.
**Keine UI-Tests:** der Schnitt hat keine Oberfläche und ändert nichts Sichtbares; es gibt keinen Ablauf, den ein UI-Test bedienen könnte.

| Test | AC |
|---|---|
| `withoutSessionNothingIsSent` | AC-1 |
| `transcriptIsBuiltFromAllTasksAndSent` | AC-2 |
| `transcriptErrorsEndThePass` | AC-3 |
| `emptyClaimEndsThePass` | AC-4 |
| `orderIsExecutedAsClaudeAndReported` | AC-5 |
| `loopContinuesUntilNothingIsLeft` | AC-6 |
| `unreadableOrderIsRejectedAsInvalid` | AC-7 |
| `executionFailureReportsNothingAndEndsThePass` | AC-8 |
| `refusedResultIsDroppedAndPassContinues` | AC-9 |
| `tooManyRequestsEndsAtOnce` | AC-10 |
| `otherErrorsEndThePass` | AC-11 |
| `resultFailureEndsThePassAndKeepsTheChange` | AC-12 |
| `deviceIdentityFailureEndsWithoutRequest` | AC-13 |
| `deviceIsReadOncePerPass` | AC-14 |
| `passStopsAtFifteenOrders` | AC-15 |
| `secondConcurrentCallDoesNotStartAPass` | AC-16 |
| `lockIsReleasedAfterEveryEnding` | AC-17 |
| `sessionLostMidPassEndsQuietly` | AC-18 |
| `endingsCarryNoSecrets` | AC-19 |
| ganze Suite, `creatingSendsNothing` (bestehend), Suche nach Aufrufern | AC-20 |

- [ ] Test 1 (AC-1, AC-2, AC-3): GIVEN Konto abgemeldet beziehungsweise angemeldet WHEN `sendTranscript()` läuft THEN keine Anfrage beziehungsweise genau die Abschrift aus allen Aufgaben, jeder Fehler beendet.
- [ ] Test 2 (AC-4 bis AC-7): GIVEN `claim` mit 204, Auftrag, mehreren Aufträgen, unlesbarem Auftrag WHEN `pullOrders()` läuft THEN nach der Tabelle ausgeführt und gemeldet, Revision „Claude“ nachweisbar.
- [ ] Test 3 (AC-8 bis AC-12): GIVEN Ausführungsfehler, 409, 429 und jeder andere Fehler an `claim` und `result` WHEN `pullOrders()` läuft THEN die Reaktion der Tabelle, bei 429 und Ausführungsfehler keine weitere Anfrage.
- [ ] Test 4 (AC-13, AC-14): GIVEN `device()` wirft beziehungsweise liefert WHEN `pullOrders()` läuft THEN keine Anfrage beziehungsweise genau eine Lesung je Durchgang.
- [ ] Test 5 (AC-15 bis AC-18): GIVEN Dauerstrom von Aufträgen, ein hängender `claim`, jeder Ausgang, ein Sitzungsverlust WHEN `pullOrders()` läuft THEN Obergrenze 15, `busy`, Sperre frei, still beendet.
- [ ] Test 6 (AC-19, AC-20): GIVEN jeder Fehlerfall und die ganze Suite WHEN sie läuft THEN nur Fallnamen, grün, kein Aufrufer außerhalb der Datei.

**Ehrlich zur Belegkraft:** TDD-Reihenfolge: die Tests werden vor dem Code geschrieben (RED: Kompilierfehler, weil `ClaudeSync` fehlt), dann der Code (GREEN). Den Ausführungsfehler (AC-8) erzeugt der Test über die eingereichte `execute`-Closure, die wirft: ein Speicherfehler lässt sich im In-Memory-Container nicht verlässlich herbeiführen, und dass `OrderExecutor` bei einem gescheiterten Speichern zurückrollt und wirft, ist dessen eigene Sache. Alle übrigen Tests (AC-5, AC-15 u. a.) laufen durch den echten `OrderExecutor`, keine Nachbildung.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): S3a reiner Durchgang, S3b Auslöser und Nachweis** | siehe Purpose | jede Zeile der Reaktionstabelle einzeln prüfbar, ohne dass die App etwas sendet; kleiner Review | der Nachweis „Abschrift von A, Auftrag auf B ausgeführt“ kommt erst mit S3b | nichts; keine ADR |
| **B Ein Schnitt S3 (Durchgang, Auslöser, Debug-Schalter, A/B)** | alles zusammen | Nachweis früher | ≈ 450 LoC, 4 bis 5 Dateien, Verdrahtung und Testdatei in einem Review; erste echte Aufrufe an den Live-Dienst im selben Schnitt wie die Logik | die Schnittgrenze von #795 (Teilschnitte, je 4–5 Dateien); verworfen |
| **C Abschrift im Takt** (höchstens einmal je Minute statt bei jedem Speichern) | weniger Anfragen | schont die Mengengrenze | Claude sähe Änderungen bis zu einer Minute später; bei 2 s Entprellung und 10 r/s am nginx unnötig; betrifft S3b, nicht diesen Schnitt | keine ADR; in S3b entschieden |
| **D Mac als ständiger Ausführer** (Menüband-App holt jede Minute) | ersetzt für Nutzer mit laufendem Mac den Weckruf | Aufträge ohne Weckruf | Produktfrage; gegen den Entwurf „stille Mitteilung“ (S5) in #795, mehr Anfragen, Mac nicht immer an | der Weckruf-Entwurf in #795 (S5); verworfen für jetzt, kommt mit S5 |
| **E Ausführungsfehler als `invalid` melden** | Auftrag wäre erledigt, keine Schleife | kein Warten auf die Rückholung | ein Speicherfehler ist keine Eigenschaft des Auftrags; Claude bekäme ein falsches „abgelehnt“ und die Aufgabe bliebe unverändert | „der Dienst ist die Wahrheit über Vergabe und Rückholung“ (Vertrag); verworfen |

## Out of Scope / Folgeschnitte

- **S3b:** Auslöser (senden bei Speichern und fertigem Import, 2 s entprellt, und beim Start; holen beim Start und beim Wechsel in den Vordergrund, prozessweit nach dem Muster `WidgetReload`), Verdrahtung in `LooseEndsApp`, Debug-Schalter für lokalen Dienst und Sitzung ohne Apple, Nachweis A/B mit zwei Simulatoren gegen `server/scripts/test-local.sh`.
- **S5:** Hintergrund-Auffrischen (`LooseEnds/Notifications/BackgroundRefresh.swift`, Pfad der Geräteliste, Stufe 3) **und** Weckruf zusammen; das Hintergrund-Auffrischen wandert aus S3 dorthin.
- Anzeige des Zustands in der Oberfläche; Änderungen an `ServiceClient.swift`, `DeviceIdentity.swift`, `AccountState.swift`, `AccountWiring.swift`, `OrderExecutor.swift`, `server/`, Widgets, Watch, `project.yml`: keine.

## Abnahme

**Kein Pfad der Geräteliste berührt.** (`LooseEnds/Claude/` und `LooseEndsTests/` stehen nicht darin; kein `project.yml`, keine Entitlements, keine `Info.plist`.) Die Abnahme endet nach Stufe 2: Stufe 1 sind die Unit-Tests (neue und bestehende, `./scripts/sim.sh unit`), Stufe 2 der Beleg „App startet unverändert im Simulator“ (`./scripts/sim.sh build`, `launch`, `screenshot` und der maschinelle Beleg `./scripts/sim.sh test-proof <Klasse>` einer bestehenden Smoke-Klasse), wie bei S2a und S2b; sichtbar ändert sich nichts, und das wird im Abschlussbericht gesagt. Gerätepunkte gibt es in diesem Schnitt nicht; der Durchlauf mit dem echten Dienst kommt mit S3b.

## Definition of Done

- [ ] AC-1 bis AC-20 erfüllt, jeder über seinen benannten Test; Tests vor dem Code geschrieben (RED belegt)
- [ ] `./scripts/sim.sh unit` grün (gesamte Suite), Build erfolgreich
- [ ] Abnahme: „Kein Pfad der Geräteliste berührt.“
- [ ] Stufe 2: App startet unverändert im Simulator, Beleg liegt vor
- [ ] Kein Token, keine Gerätekennung, kein Auftrags- oder Aufgabentext in einer Logzeile oder einem Rückgabewert (AC-19); kein `try?`
- [ ] Doku (keine Codedatei, zählt nicht zum Dateilimit): `CLAUDE.md` im Absatz `LooseEnds/Claude` um `ClaudeSync` ergänzt (eine Zeile, Hotspot, vor dem PR gegen `origin/main` abgleichen)
- [ ] PR mit `Refs #795`, CI grün, Merge durch Claude; #795 kommentiert (Stand S3a, Folge S3b), Board-Karte aktuell, Memory geschrieben

## Known Limitations

- Nichts ruft `ClaudeSync` auf; die App gleicht bis S3b nichts ab.
- Ein `capture` kann nach Rückholen doppelt erfasst werden (Vertrag (c)).
- Das Melden eines ausgeführten Auftrags kann scheitern, ohne dass die App es später nachholt; der Dienst holt nach zehn Minuten zurück und das Gerät erhält `stale`.
- Ein kaputter Gerätekennungs-Eintrag (`DeviceIdentity` wirft `corruptData`) beendet jeden Durchgang mit `deviceIdentity`, bis S3b oder S5 einen Weg zeigt, ihn zu beheben.
- Der Durchlauf gegen den echten Dienst und den echten Schlüsselbund ist nicht Teil dieses Schnitts (S3b).
- Der Lesefehler der Aufgaben (`storeUnreadable`) hat keinen eigenen Test, weil der In-Memory-Container ihn nicht liefert; die Abbildung prüft die Durchsicht im Prüfdialog am Code.
- AC-19 (Quellsuche nach `try?`/`print(`) und AC-20 (Suche nach Aufrufern) sind Belege im Abschlussbericht, keine Swift-Tests.

## Changelog

- 2026-11-12: Initial spec created (Schnitt S3a)
- 2026-11-12: Validierung: Stufe 2 Pflicht, AC-14 fünf Anfragen, Abweichungen benannt, Obergrenze angeglichen, LoC realistisch geschätzt (≈ 570, Meldeschwelle 650), `execute`-Naht für AC-8
