# Adversary Dialog — feat-795-s3-claude-sync
Spec: docs/specs/feat-795-schnitt-3a-claude-sync.md
Datum: 2026-11-12 19:41

## Checkliste
- [x] **AC-1:** Ohne Sitzung kein Aufruf: GIVEN ein `AccountState` im Status `signedOut` (leerer Store) WHEN `sendTranscript()` und `pullOrders()` laufen THEN ist jede Rückgabe `notSignedIn`, der `FakeTransport` hat keine Anfrage erhalten und die `device`-Closure wurde nie gerufen (Test `withoutSessionNothingIsSent`).
- [x] **AC-2:** Abschrift: GIVEN `signedIn`, ein Container mit drei Aufgaben (offen, erledigt, entfernt) WHEN `sendTranscript()` läuft und der Dienst 204 antwortet THEN ist die Rückgabe `done`, genau eine Anfrage `POST app/transcript` mit dem Bearer-Token des Stores ging hinaus, und ihr Körper ist byte-gleich `TranscriptCodec.encode(TranscriptCodec.transcript(of: <alle drei>, now: <eingereichte Uhr>, calendar: <eingereichter Kalender>))` (Test `transcriptIsBuiltFromAllTasksAndSent`).
- [x] **AC-3:** Abschrift, Fehler: GIVEN `signedIn` und der Dienst antwortet auf `transcript` 401, 429, 503, 400 (`rejected`), oder der Transport wirft `CancellationError` WHEN `sendTranscript()` läuft THEN ist die Rückgabe der Reihe nach `stopped(.unauthorized)`, `stopped(.tooManyRequests)`, `stopped(.unavailable)`, `stopped(.serviceError)`, `stopped(.cancelled)`; es geht genau eine Anfrage hinaus; nach 401 ist der Status `signedOut` (Test `transcriptErrorsEndThePass`, Argumente je Fall).
- [x] **AC-4:** Nichts offen: GIVEN `signedIn` und `claim` antwortet 204 WHEN `pullOrders()` läuft THEN ist die Rückgabe `done`, genau eine Anfrage `POST app/orders/claim` ging hinaus, mit `X-Device` gleich der eingereichten UUID in Kleinschreibung und dem Bearer-Token, und kein `result` (Test `emptyClaimEndsThePass`).
- [x] **AC-5:** Auftrag ausführen und melden: GIVEN `signedIn`, eine Aufgabe mit Fälligkeit und `claim` liefert einen Auftrag `setDue` (erwarteter Stand passt), danach 204, `result` antwortet 204 WHEN `pullOrders()` läuft THEN ist die Rückgabe `done`, die Aufgabe im Container hat das neue Datum, es gibt genau eine Revision mit `field == .dueDate`, `author == .user` und `reason == "Claude"`, und der `result`-Körper ist `OrderResult(orderID:, outcome: .done, taskID:)` des Auftrags; die Anfragen kamen in der Reihenfolge `claim`, `result`, `claim` (Test `orderIsExecutedAsClaudeAndReported`).
- [x] **AC-6:** Mehrere Aufträge: GIVEN `claim` liefert nacheinander zwei Aufträge `capture`, dann 204 WHEN `pullOrders()` läuft THEN ist die Rückgabe `done`, zwei neue Aufgaben liegen im Container, und die Anfragen sind genau `claim`, `result`, `claim`, `result`, `claim` (Test `loopContinuesUntilNothingIsLeft`).
- [x] **AC-7:** Nicht lesbarer Auftrag: GIVEN `claim` liefert 200 mit einem JSON-Objekt, dessen `id` lesbar ist, dessen übrige Felder `Order` nicht entsprechen (`Claim.unreadable(id)`) WHEN `pullOrders()` läuft THEN geht ein `result` mit `OrderResult(orderID: id, outcome: .rejected, reason: .invalid, taskID: nil)` hinaus, der Container ist unverändert (keine neue Aufgabe, keine Revision), und der Durchgang holt weiter (Test `unreadableOrderIsRejectedAsInvalid`).
- [x] **AC-8:** Ausführungsfehler: GIVEN `claim` liefert einen `capture`-Auftrag und die eingereichte `execute`-Closure wirft (steht für einen gescheiterten Speichervorgang, nach dem `OrderExecutor` zurückrollt) WHEN `pullOrders()` läuft THEN ist die Rückgabe `stopped(.executionFailed)`, es ging **kein** `result` und kein zweites `claim` hinaus (Test `executionFailureReportsNothingAndEndsThePass`).
- [x] **AC-9:** Dienst verwirft das Ergebnis: GIVEN `claim` liefert einen Auftrag `capture`, `result` antwortet 409, das nächste `claim` 204 WHEN `pullOrders()` läuft THEN ist die Rückgabe `done`, die lokal erfasste Aufgabe bleibt, und es folgt ein zweites `claim` (Test `refusedResultIsDroppedAndPassContinues`).
- [x] **AC-10:** 429 bricht sofort ab: GIVEN `claim` antwortet 429 (erste Anfrage) oder `result` antwortet 429 (nach einem ausgeführten Auftrag) WHEN `pullOrders()` läuft THEN ist die Rückgabe `stopped(.tooManyRequests)`, und es ging keine weitere Anfrage hinaus, nach dem 429 weder `claim` noch `result` (Test `tooManyRequestsEndsAtOnce`, Argumente je Stelle).
- [x] **AC-11:** Weitere Fehler beenden den Durchgang: GIVEN `signedIn` und die erste Anfrage `claim` scheitert mit 401, 503, 500, einer unlesbaren Antwort (`invalidResponse`) oder `CancellationError` WHEN `pullOrders()` läuft THEN ist die Rückgabe der Reihe nach `stopped(.unauthorized)`, `stopped(.unavailable)`, `stopped(.serviceError)`, `stopped(.serviceError)`, `stopped(.cancelled)`, es ging genau eine Anfrage hinaus; bei 401 ist der Status danach `signedOut` und der Store leer (Test `otherErrorsEndThePass`, Argumente je Fall).
- [x] **AC-12:** Fehler beim Melden: GIVEN ein ausgeführter Auftrag und `result` antwortet 503 oder 500 WHEN `pullOrders()` läuft THEN endet der Durchgang mit `stopped(.unavailable)` beziehungsweise `stopped(.serviceError)`, die lokale Änderung bleibt, es folgt kein weiteres `claim` (Test `resultFailureEndsThePassAndKeepsTheChange`, Argumente je Status).
- [x] **AC-13:** Kennungsfehler: GIVEN `signedIn` und `device()` wirft WHEN `pullOrders()` läuft THEN ist die Rückgabe `stopped(.deviceIdentity)`, es ging keine Anfrage hinaus, und die Closure wurde genau einmal gerufen (Test `deviceIdentityFailureEndsWithoutRequest`).
- [x] **AC-14:** Kennung einmal je Durchgang: GIVEN `signedIn` und ein Durchgang mit zwei Aufträgen WHEN `pullOrders()` läuft THEN wurde `device()` genau einmal gerufen und alle fünf Anfragen (`claim`, `result`, `claim`, `result`, `claim`) tragen dieselbe `X-Device`; ein zweiter Durchgang ruft `device()` erneut (kein Zwischenspeicher) (Test `deviceIsReadOncePerPass`).
- [x] **AC-15:** Obergrenze: GIVEN `claim` liefert dauerhaft `capture`-Aufträge und `result` antwortet 204 WHEN `pullOrders()` läuft THEN ist die Rückgabe `limitReached`, genau 15 Aufträge wurden ausgeführt (15 neue Aufgaben), genau 30 Anfragen (15 `claim`, 15 `result`) gingen hinaus, kein 16. `claim`, und `ClaudeSync.maxOrdersPerPass == 15` (Test `passStopsAtFifteenOrders`).
- [x] **AC-16:** Wiedereintrittssperre: GIVEN `signedIn` und ein `claim`, der im Transport hängt (Hook hält die Antwort an) WHEN `pullOrders()` ein zweites Mal gerufen wird, solange der erste läuft THEN ist die Rückgabe des zweiten `busy` ohne eine eigene Anfrage; nach dem Ende des ersten startet ein dritter Aufruf wieder einen Durchgang; dasselbe für `sendTranscript()`; beide Durchgänge sperren einander nicht (Test `secondConcurrentCallDoesNotStartAPass`).
- [x] **AC-17:** Sperre wird immer frei: GIVEN ein Durchgang endet mit `stopped(...)`, `notSignedIn` oder `limitReached` WHEN derselbe Durchgang danach erneut gerufen wird THEN läuft er (nicht `busy`) (Test `lockIsReleasedAfterEveryEnding`, Argumente je Ausgang).
- [x] **AC-18:** Sitzung fällt mitten im Durchgang weg: GIVEN `signedIn` und nach dem ersten Auftrag leert der Hook den Store WHEN `pullOrders()` weiterläuft THEN ist die Rückgabe `notSignedIn`, und nach dem Wegfall ging keine Anfrage mehr hinaus (Test `sessionLostMidPassEndsQuietly`).
- [x] **AC-19:** Keine Geheimnisse im Log: GIVEN jeder Fehlerfall aus AC-3, AC-8 bis AC-13 THEN enthält `String(describing: <Rückgabe>)` und jeder `Stop.rawValue` nur Fallnamen (keine Token-, UUID- oder Textzeichenkette aus dem Test), und `ClaudeSync.swift` enthält weder `try?` noch `print(` (Test `endingsCarryNoSecrets`; die Quellsuche als Beleg im Abschlussbericht).
- [x] **AC-20:** Nichts wird aufgerufen: GIVEN die ganze Unit-Suite WHEN sie läuft THEN ist sie grün, und `rg "ClaudeSync" LooseEnds LooseEndsWatch LooseEndsWidgets LooseEndsShare Shared` findet außerhalb von `ClaudeSync.swift` keinen Treffer (Beleg im Abschlussbericht; Test: bestehende `creatingSendsNothing` in `ServiceClientTests` und die `AccountWiring`-Tests grün).

## Dialog

### Runde 1
**Adversary:** Sonde: Sperren per defer in beiden Durchgaengen (ClaudeSync.swift:58-60, 81-83) loesen in jedem Ausgang inkl. limitReached/Abbruch; Flag wird vor erstem await gesetzt. Schleife for 0..<15 (Z.85) zaehlt jeden behandelten Auftrag, auch unreadable und 409 (handle/report liefern nil, Schleife geht weiter): nach dem 15. kein 16. claim, Z.99. execute-Wurf: Z.112-115 kehrt vor report zurueck, kein result, keine Endlosschleife. device() nur lazy im withSession-Closure (Z.89), ohne Sitzung gibt withSession nil vor dem Closure (AccountState.swift:118). Logger: nur Stop.rawValue und type(of: error) (Z.139, 157); keine try?/print (rg: keine Treffer). Aufrufer ausserhalb: rg findet keinen.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Nachbohren: 409 am claim/transcript wird serviceError (kein refused-Sonderfall, nur result) - tabellenkonform. Abbruch nach execute: CancellationError beim result -> stopped(.cancelled), Aenderung bleibt (Spec). Mitten im Durchgang notSignedIn nach gesendetem result (Z.126) - korrekt. 401 beim result: withSession raeumt, Stop.unauthorized. DeviceUnreadable wird nicht von withSession verschluckt (nur unauthorized gefangen). Swift 6: @MainActor-Klasse, Closure in withSession mutiert lokale var deviceID - kompiliert, Lauf gruen. Testdiff d5b7997: nur Zwischenvariable lettersOnly, Aussage unveraendert. Restrisiko LOW: AC-19 prueft Logzeilen nicht direkt (nur Rueckgaben und Quelltext); Task.isCancelled wird zwischen Schleifendurchlaeufen nicht geprueft, aber jeder Netzaufruf wirft CancellationError.
**Implementierer:** (nicht beteiligt)

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Claude/ClaudeSync.swift:72
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:141 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Claude/ClaudeSync.swift:67
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:152 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/ClaudeSync.swift:74
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:179 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/ClaudeSync.swift:106
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:189 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Claude/ClaudeSync.swift:112
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:201 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Claude/ClaudeSync.swift:85
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:225 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Claude/ClaudeSync.swift:109
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:235 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Claude/ClaudeSync.swift:114
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:252 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Claude/ClaudeSync.swift:127
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:262 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Claude/ClaudeSync.swift:94
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:272 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: LooseEnds/Claude/ClaudeSync.swift:94
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:289 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: LooseEnds/Claude/ClaudeSync.swift:131
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:302 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: LooseEnds/Claude/ClaudeSync.swift:136
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:314 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: LooseEnds/Claude/ClaudeSync.swift:90
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:322 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: LooseEnds/Claude/ClaudeSync.swift:99
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:338 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: LooseEnds/Claude/ClaudeSync.swift:58
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:350 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: LooseEnds/Claude/ClaudeSync.swift:60
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:375 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-18
  Code reference: LooseEnds/Claude/ClaudeSync.swift:96
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:401 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-19
  Code reference: LooseEnds/Claude/ClaudeSync.swift:157
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:415 gruen (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-20
  Code reference: LooseEnds/Claude/ClaudeSync.swift:9
  Evidence: Codepfad gelesen; Test LooseEndsTests/ClaudeSyncTests.swift:141 gruen (adversary-test-output.txt); AC-20: rg ausserhalb ohne Treffer.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Claude/ClaudeSync.swift:85
  Description: Die Schleife prueft Task.isCancelled nicht selbst; Abbruch wird erst durch den naechsten Netzaufruf (CancellationError) erkannt.
  Spec requirement: AC-11 — CancellationError beendet den Durchgang
  Conflict: kein Verstoss, jeder Schleifendurchlauf beginnt mit einem Netzaufruf; nur Hinweis.
  Remediation: keine noetig.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: ClaudeSyncTests-Suite bestanden (0 failed); Messstrecken 3 von 6 uebersprungen (fehlende Korpusdateien, unabhaengig vom Schnitt)
Edge cases: alle geprueft, keine gebrochen (F001 LOW, kein Blocker)
Regressions: keine
Checklist: 20/20 points proven

## Geprüfte Dateien

- sha256:58a64db08eafe345b0ad0ffb4301bff7da58087cd21749028a525af8f3b87b49  LooseEnds/Claude/ClaudeSync.swift

## Prüfbasis

- base: 36aac30375b718bdcdb22b90638b3b71744d1d18
- blob:2fb535d1488b0f265ba9647f1e3373ddbedb843f  LooseEnds/Claude/ClaudeSync.swift

## Geprüfte Dateien

- sha256:58a64db08eafe345b0ad0ffb4301bff7da58087cd21749028a525af8f3b87b49  LooseEnds/Claude/ClaudeSync.swift

## Prüfbasis

- base: 36aac30375b718bdcdb22b90638b3b71744d1d18
- blob:2fb535d1488b0f265ba9647f1e3373ddbedb843f  LooseEnds/Claude/ClaudeSync.swift
