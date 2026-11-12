---
entity_id: feat-795-schnitt-2b-device-identity
type: feature
created: 2026-11-12
updated: 2026-11-12
status: draft
workflow: feat-795-s2b-device-identity
---

# Spec: Gerätekennung und Zugang zu den App-Wegen, Schnitt S2b (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S2b von sieben (S1, S1b, S2a, S2b, S3, S4, S5); das Issue bleibt offen (`Refs #795`, nie `Closes #795`): S3 (`ClaudeSync`) und S5 (Weckruf) folgen.
Analyse: `docs/context/feat-795-s2b-device-identity.md` (Abschnitt „Analysis“: Festlegungen, Alternativen; verbindlich). Die Wahl der Ablage steht in `docs/context/feat-795-s2-app-client.md` und in Alternative E der Vorgänger-Spec.
Vorgänger: S2a (`docs/specs/feat-795-schnitt-2a-app-client.md`, die drei App-Wege am `ServiceClient`; dort „Out of Scope“ und Alternative E zeichnen diesen Schnitt vor).
Es ist ein reiner App-Kern ohne Oberfläche: **vier Dateien**, nichts in der App ruft die neuen Teile auf.

## Für den PO

Die App bekommt zwei Dinge, die sie später braucht, wenn sie mit dem Dienst für Claude Aufträge abgleicht. Erstens eine feste Kennung für dieses Gerät, die sie beim ersten Mal selbst vergibt und danach immer wieder vorfindet, damit der Dienst weiß, welches Gerät einen Auftrag hält. Zweitens eine einzige Tür zu den Wegen des Dienstes: ohne Anmeldung geht nichts hinaus, und wenn der Dienst die Anmeldung nicht mehr kennt, räumt die App sie ab, aber nur, wenn nicht inzwischen eine neuere Anmeldung da ist.

Für dich ändert sich nichts Sichtbares, die App sendet weiterhin nichts mehr als heute. Du musst nichts entscheiden und nichts tun.

## Purpose

S2a hat die drei Wege `POST /app/transcript`, `/app/orders/claim` und `/app/orders/result` am `ServiceClient` ergänzt; `device` und `sessionToken` kommen dort von außen. Dieser Schnitt liefert beides, ohne es aufzurufen:

**1. `DeviceIdentity`** (neu, `LooseEnds/Claude/DeviceIdentity.swift`): `struct DeviceIdentity: Sendable` über `KeychainOperations`, `func current() throws -> UUID`. Der Eintrag ist eigen (`service` `com.henning.looseends.device`, `account` `device`, Wert = `uuidString` als UTF-8) und nutzt dieselbe Abfrageform wie der Sitzungseintrag (`kSecClassGenericPassword`, `kSecUseDataProtectionKeychain`, nicht synchronisiert), geschrieben mit `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (der Weckruf in S5 läuft im Hintergrund). Fehlerfälle als eigenes `Equatable`-Enum ohne Geheimnis: `DeviceIdentityError { keychain(OSStatus), corruptData }`.

`current()` in fünf Schritten:

1. `copyMatching` mit Erfolg: die Daten als UUID lesen; ergeben sie keine UUID, wird `corruptData` geworfen (Fehler, kein stilles Ersetzen).
2. `errSecItemNotFound`: eine neue `UUID()` erzeugen, mit `add` (`AfterFirstUnlockThisDeviceOnly`) speichern; bei Erfolg zurückgeben.
3. `add` meldet `errSecDuplicateItem` (ein zweiter Aufrufer war schneller): genau einmal neu lesen, die gespeicherte Kennung gewinnt; nie `update`, nie überschreiben.
4. Jeder andere Status (auch -34018 `errSecMissingEntitlement` im Test-Host, -25308 `errSecInteractionNotAllowed` vor dem ersten Entsperren, ebenso beim erneuten Lesen aus Schritt 3) ergibt `keychain(status)`; nie eine neue Kennung.
5. Kein Zwischenspeicher im Speicher: der Typ ist zustandslos wie `KeychainSessionStore`; S3 liest einmal je Durchgang.

**2. `AccountState.withSession`** (`LooseEnds/Claude/AccountState.swift`): der einzige Zugang zu den App-Wegen.

`func withSession<T: Sendable>(_ call: (ServiceClient, String) async throws -> T) async throws -> T?`

1. Nur aus `signedIn`; sonst `nil`, nichts gesendet, die Closure läuft nicht. Der Token wird bei jedem Gebrauch frisch aus dem Store gelesen; kein Token oder ein Lesefehler ergibt `nil`.
2. Andere Fehler als 401 gehen unverändert an den Aufrufer (`tooManyRequests`, `refused`, `unavailable`, `CancellationError` und alles andere); der Status bleibt.
3. `ServiceError.unauthorized`: der Store wird nur geleert, wenn er noch genau diesen Token hält; der Status wird nur dann `signedOut`, wenn er noch `signedIn` ist (eine laufende Anmeldung oder Löschung wird nie überschrieben). Danach wird `unauthorized` weitergeworfen, damit S3 den Durchgang beendet.
4. `lastProblem` bleibt unberührt (S2b hat keine Oberfläche).

`dropSession(_:)`, bisher nur für `deleteAccount` (feste Logzeile „delete: …“), wird zu `private func dropSession(_ token: String, during reason: StaticString) -> Status` verallgemeinert: die Logzeile trägt den Anlass (`"delete"` aus `deleteAccount`, `"session"` aus `withSession`; nie Token oder Werte) statt fest „delete“. Das Verhalten von `deleteAccount` bleibt unverändert.

**Nichts wird aufgerufen.** Weder `DeviceIdentity` noch `withSession` hat einen Aufrufer; `AccountWiring`, `ServiceClient`, `KeychainSessionStore` und `UITestTransport` bleiben unberührt. Der Schlüsselbund wird in diesem Schnitt nicht angefasst, solange niemand `current()` ruft.

**Regeln vor Modell:** reine Speicher- und Zustandsfrage ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt ADR-21 (Dienst für Claude, Weg B, trägt die Wahl des Schlüsselbunds) und den Vertrag „Wege der App“ (`X-Device` = UUID der Installation) um, ohne sie zu ändern; keine neue Abhängigkeit, kein neues Verfahren, kein Schema.

- **Rationale:** Der Schlüsselbund überlebt in der Praxis das Löschen und Neuinstallieren der App (kein API-Versprechen, Apple-Forum https://developer.apple.com/forums/thread/72271), `identifierForVendor` kann sich bei Neuinstallation ändern (https://developer.apple.com/forums/thread/109900); eine eigene UUID im nicht synchronisierten Schlüsselbund ist die übliche Lösung. `…ThisDeviceOnly` wandert nicht auf ein neues Gerät: neues Gerät, neue Kennung, gewollt (der Dienst vergibt Aufträge je Gerät). Der Zugang als Methode von `AccountState` hält die Wahrheit über die Sitzung an einer Stelle: der 401 ändert den sichtbaren Status, und das darf nur der tun, der den Status besitzt.

## Source

- **File:** `LooseEnds/Claude/DeviceIdentity.swift` (neu), `LooseEnds/Claude/AccountState.swift`
- **Identifier:** `DeviceIdentity`, `DeviceIdentity.current()`, `DeviceIdentityError`, `AccountState.withSession(_:)`, `AccountState.dropSession(_:)`; benutzt `KeychainOperations`, `SystemKeychain` (`KeychainSessionStore.swift`, unverändert), `ServiceClient`, `ServiceError.unauthorized`

**Dateien:** `LooseEnds/Claude/DeviceIdentity.swift` (neu), `LooseEnds/Claude/AccountState.swift`, `LooseEndsTests/DeviceIdentityTests.swift` (neu), `LooseEndsTests/AccountStateTests.swift`.
**Unberührt:** `KeychainSessionStore.swift`, `SessionStore.swift`, `ServiceClient.swift`, `AccountWiring.swift`, `server/`, `Shared/`, `project.yml`, `Info.plist`, Entitlements, alle Views.

### Schnittstelle und Festlegungen

- **Eintrag:** `service` `com.henning.looseends.device`, `account` `device`; Wert `uuidString` als UTF-8; Zugriff `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecUseDataProtectionKeychain` gesetzt, nicht synchronisiert (`kSecAttrSynchronizable` aus). Kein Sitzungseintrag wird berührt.
- **Statusabbildung:** nur `errSecSuccess` und (je nach Schritt) `errSecItemNotFound` / `errSecDuplicateItem` haben eine Bedeutung; alles andere ist `keychain(status)`; -34018 ist nie „nichts da“ (wie beim Sitzungseintrag).
- **Kein `update`, kein `delete`:** `DeviceIdentity` ruft nur `copyMatching` und `add`; ein bestehender Eintrag wird nie geändert oder entfernt.
- **Sicherheit:** `DeviceIdentityError` und die Logzeilen tragen nie die UUID oder Token, nur Fallnamen und Statuszahlen. Die Kennung ist kein Geheimnis, wird aber nicht ohne Grund gedruckt.
- **`withSession` und Gleichzeitigkeit:** Die Prüfung „Store hält noch diesen Token“ und „Status noch `signedIn`“ geschieht nach dem `await`, auf dem Main-Actor, in einem Zug ohne Unterbrechung; so überschreibt ein 401 zu einem alten Token weder eine neuere Sitzung noch einen laufenden Ablauf.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `KeychainOperations`, `SystemKeychain`, Abfrageform des Sitzungseintrags (`KeychainSessionStore.swift`) | bestehend, unverändert |
| `SessionStoring`, `SessionStoreError`, `InMemorySessionStore` (`SessionStore.swift`) | bestehend, unverändert |
| `ServiceClient` mit `putTranscript`, `claimOrder`, `putResult`, `ServiceError` (S2a) | bestehend, unverändert |
| `KeychainSessionStoreTests.FakeKeychain` (verschachtelt, `internal`) | bestehend, wiederverwendet |
| `Wire`-Transport in `AccountStateTests` | bestehend, erweitert um `withSession`-Fälle |
| Downstream | S3 (`ClaudeSync` ruft `withSession` und `DeviceIdentity.current()` je Durchgang), S5 (Weckruf im Hintergrund, daher `AfterFirstUnlock`) |

## Acceptance Criteria

Jedes AC wird über einen benannten Test belegt: `DeviceIdentity` in `LooseEndsTests/DeviceIdentityTests.swift` (Swift Testing, `FakeKeychain` mit Statusfolge und Aufrufprotokoll), `withSession` in `LooseEndsTests/AccountStateTests.swift` (`Wire`-Transport, `InMemorySessionStore`). Die vorhandenen Tests bleiben unverändert grün.

- **AC-1:** Erste Erzeugung: GIVEN ein `FakeKeychain`, dessen `copyMatching` `errSecItemNotFound` meldet und dessen `add` Erfolg meldet WHEN `current()` läuft THEN wird genau einmal gelesen und genau einmal `add` gerufen, kein `update`, kein `delete`; die Rückgabe ist eine UUID, und der an `add` übergebene Wert ist deren `uuidString` als UTF-8 (Test `firstCallCreatesAndStoresOnce`).
- **AC-2:** Eintragsform: GIVEN dieselbe Lage wie AC-1 THEN trägt das `add` `service` `com.henning.looseends.device`, `account` `device`, die Klasse `kSecClassGenericPassword`, `kSecUseDataProtectionKeychain` gleich `true`, `kSecAttrAccessible` gleich `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` und kein `kSecAttrSynchronizable` gleich `true`; die Leseabfrage trägt dieselben `service`/`account` (Test `entryUsesDeviceOnlyAccessAndOwnService`).
- **AC-3:** Vorhandene Kennung: GIVEN `copyMatching` liefert Erfolg mit den UTF-8-Daten einer gültigen UUID WHEN `current()` zweimal läuft THEN ist die Rückgabe beide Male genau diese UUID, es wird nie `add`, `update` oder `delete` gerufen (Test `storedIdentityIsReturnedUnchanged`).
- **AC-4:** Kein Zwischenspeicher: GIVEN dieselbe Lage wie AC-3 WHEN `current()` zweimal läuft THEN liest der Schlüsselbund zweimal (zwei `copyMatching`-Aufrufe), die zweite Antwort zählt (Test `noInMemoryCache`, mit zwei verschiedenen eingespielten Werten).
- **AC-5:** Lesefehler erzeugt nie eine Kennung: GIVEN `copyMatching` meldet -34018, -25308 (`errSecInteractionNotAllowed`) oder einen anderen Fehlerstatus WHEN `current()` läuft THEN wirft es `DeviceIdentityError.keychain(<Status>)` mit genau diesem Status und ruft nie `add` (Test `readErrorThrowsAndNeverCreates`, Argumente je Status).
- **AC-6:** Kaputter Eintrag: GIVEN `copyMatching` liefert Erfolg mit Daten, die keine UUID sind (Text `nicht-eine-uuid`, leere Daten, Daten, die kein UTF-8 sind) WHEN `current()` läuft THEN wirft es `DeviceIdentityError.corruptData` und ruft nie `add`, `update` oder `delete` (Test `corruptEntryThrowsAndIsNotReplaced`, Argumente je Fall).
- **AC-7:** Schreibfehler: GIVEN `copyMatching` meldet `errSecItemNotFound` und `add` meldet einen Fehlerstatus (außer `errSecDuplicateItem`, z. B. -34018 oder -25308) WHEN `current()` läuft THEN wirft es `keychain(<Status>)`, es wird nicht erneut gelesen und kein zweites Mal `add` gerufen (Test `addErrorThrows`, Argumente je Status).
- **AC-8:** Gleichzeitiges Erzeugen: GIVEN `copyMatching` meldet zuerst `errSecItemNotFound`, `add` meldet `errSecDuplicateItem`, das zweite `copyMatching` liefert eine gespeicherte UUID WHEN `current()` läuft THEN ist die Rückgabe die gespeicherte UUID (nicht die selbst erzeugte), es gab genau zwei Lesungen, genau ein `add` und kein `update` (Test `duplicateReturnsStoredIdentity`).
- **AC-9:** Duplikat ohne lesbare Gegenstelle: GIVEN `add` meldet `errSecDuplicateItem` und das zweite `copyMatching` meldet `errSecItemNotFound` oder einen Fehlerstatus oder kaputte Daten WHEN `current()` läuft THEN wirft es `keychain(<Status>)` beziehungsweise `corruptData`; es wird nie ein drittes Mal gelesen und nie ein zweites Mal `add` gerufen (Test `duplicateThenUnreadableThrows`, Argumente je Fall).
- **AC-10:** Keine Geheimnisse in Fehlern: GIVEN jeder Fehlerfall aus AC-5 bis AC-9 THEN enthält `String(describing: error)` keine UUID-Zeichenkette (weder die gespeicherte noch die erzeugte) und nur den Fallnamen und gegebenenfalls die Statuszahl (Test `errorsCarryNoIdentity`).
- **AC-11:** Zugang nur aus `signedIn`: GIVEN ein `AccountState` im Status `signedOut`, `signingIn`, `deleting`, `notAllowed` oder `retryLater` WHEN `withSession` läuft THEN ist die Rückgabe `nil`, die Closure läuft nicht und der `Wire`-Transport hat keine Anfrage erhalten (Test `withSessionOnlyWhenSignedIn`, Argumente je Status).
- **AC-12:** Token fehlt oder unlesbar: GIVEN `signedIn`, dessen Store inzwischen keinen Token hält oder dessen `load` wirft WHEN `withSession` läuft THEN ist die Rückgabe `nil`, die Closure läuft nicht, nichts wurde gesendet (Test `withSessionWithoutReadableTokenIsNil`).
- **AC-13:** Erfolgsweg: GIVEN `signedIn` mit gespeichertem Token WHEN `withSession` läuft THEN erhält die Closure den `ServiceClient` und genau den frisch gelesenen Token und deren Ergebnis ist die Rückgabe; ein nach dem Anmelden im Store ersetzter Token kommt bei der nächsten Nutzung an (Test `withSessionPassesFreshToken`).
- **AC-14:** Andere Fehler bleiben Sache des Aufrufers: GIVEN `signedIn` und die Closure wirft `ServiceError.tooManyRequests`, `.refused`, `.unavailable`, `.rejected(500)`, `.invalidResponse` oder `CancellationError` WHEN `withSession` läuft THEN wird genau dieser Fehler weitergeworfen, der Store hält den Token weiter, der Status bleibt `signedIn` (Test `withSessionKeepsSessionOnOtherErrors`, Argumente je Fehler).
- **AC-15:** 401 räumt die Sitzung: GIVEN `signedIn` und die Closure wirft `ServiceError.unauthorized`, der Store hält noch denselben Token WHEN `withSession` läuft THEN ist danach der Store leer, der Status `signedOut`, und `unauthorized` wurde weitergeworfen (Test `unauthorizedClearsSameToken`).
- **AC-16:** 401 zu einem alten Token räumt eine neuere Sitzung nicht: GIVEN `signedIn` und während die Closure läuft wird im Store ein anderer Token gespeichert, danach wirft sie `unauthorized` WHEN `withSession` zurückkehrt THEN hält der Store weiter den neuen Token, der Status ist `signedIn`, `unauthorized` wurde weitergeworfen (Test `unauthorizedKeepsNewerToken`, mit dem Hook des `Wire`-Transports).
- **AC-17:** 401 überschreibt keinen laufenden Ablauf: GIVEN `signedIn` und während die Closure läuft wechselt der Status auf `signingIn` oder `deleting` (Ablauf aus dem Hook), danach wirft sie `unauthorized` WHEN `withSession` zurückkehrt THEN bleibt der Status der des laufenden Ablaufs, `unauthorized` wurde weitergeworfen (Test `unauthorizedNeverOverwritesRunningFlow`, Argumente je Status).
- **AC-18:** Keine Oberfläche berührt: GIVEN jeder Fall aus AC-12 bis AC-17 THEN ist `lastProblem` danach unverändert (`nil`, wenn es vorher `nil` war) (Test `withSessionLeavesLastProblemAlone`).
- **AC-19:** `deleteAccount` unverändert: GIVEN die vorhandenen Tests zu `deleteAccount` (`deleteFailures` mit 401 bei gleichem Token räumt, `staleUnauthorized` mit 401 bei neuerem Token räumt nicht) THEN laufen sie unverändert grün, nach der Verallgemeinerung von `dropSession` (Beleg: die gesamte Suite `AccountStateTests` grün, kein bestehender Test geändert).
- **AC-20:** Nichts wird aufgerufen: GIVEN die ganze Unit-Suite WHEN sie läuft THEN ist sie grün, und `rg "DeviceIdentity|withSession" LooseEnds LooseEndsWatch LooseEndsWidgets LooseEndsShare Shared` findet außerhalb von `DeviceIdentity.swift` und `AccountState.swift` keinen Treffer (Beleg im Abschlussbericht; Test: bestehender `creatingSendsNothing` in `ServiceClientTests` und `AccountWiring`-Tests grün).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/DeviceIdentity.swift` | CREATE | `DeviceIdentity`, `DeviceIdentityError`, `current()`; ≈ +55 |
| `LooseEnds/Claude/AccountState.swift` | MODIFY | `withSession(_:)`, `dropSession` verallgemeinert (Logzeile mit Anlass); ≈ +30/−5 |
| `LooseEndsTests/DeviceIdentityTests.swift` | CREATE | Tests zu AC-1 bis AC-10, mit `FakeKeychain`; ≈ +75 |
| `LooseEndsTests/AccountStateTests.swift` | MODIFY | Tests zu AC-11 bis AC-19 mit dem vorhandenen `Wire`-Transport; ≈ +70 |

### Estimated Changes

- **Dateien: 4** (2 neu, 2 geändert). Innerhalb des Limits von 4 bis 5 Dateien.
- **LoC: ≈ +230 / −5** (Code ≈ 85, Tests ≈ 145), innerhalb von ±250 LoC; keine Funktion über 50 Zeilen.
- Keine Permissions, keine `Info.plist`-Einträge (der Schlüsselbund-Zugriff braucht keine; die Data-Protection-Keychain nutzt die vorhandene Berechtigung des Sitzungseintrags), keine AppStorage-Keys, kein CloudKit-Schema, keine Audio-Dateien, keine Oberfläche, keine neue Abhängigkeit. `generate` muss laufen, weil zwei Dateien neu sind (CLAUDE.md, Build).
- **Seiteneffekte nach außen:** keine. Nichts in der App ruft die neuen Teile auf; der Schlüsselbund bekommt keinen neuen Eintrag, solange `current()` niemand ruft; die App sendet nach diesem Schnitt nichts, was sie vorher nicht gesendet hat.
- **Parallele Arbeit:** vor dem PR `origin/main` und offene PRs auf Berührung von `AccountState.swift` und `AccountStateTests.swift` prüfen (zur Analysezeit berührten #908, #903, #855, #854 keine der vier Dateien).

## Risiken

- **Lesefehler vor dem ersten Entsperren.** Ein Hintergrundlauf unmittelbar nach dem Start des Geräts liest -25308 oder -34018. `current()` wirft dann (AC-5), S3 beendet den Durchgang und versucht es beim nächsten Anlass; eine neue Kennung entstünde sonst und der Dienst gäbe die Aufträge der alten Kennung nach zehn Minuten wieder heraus, mit 409 für deren Ergebnisse (Doppelvergabe).
- **Gleichzeitiges erstes Erzeugen.** Zwei Aufrufer: das zweite `add` meldet `errSecDuplicateItem`, die gespeicherte Kennung gewinnt (AC-8); ein verlorenes Rennen kostet nichts.
- **401 während einer Anmeldung.** Ein verspäteter 401 zu einem alten Token darf die frische Sitzung nicht räumen (AC-16, AC-17); beide Bedingungen werden nach dem `await` in einem Zug auf dem Main-Actor geprüft.
- **`dropSession` verändert `deleteAccount` nicht.** Nur die Logzeile bekommt einen Anlass; AC-19 hält das Verhalten fest.
- **Belegkraft.** Die Tests belegen die Abfolge gegen einen Stellvertreter-Schlüsselbund; der echte Schlüsselbund antwortet im Test-Host -34018, der Durchlauf mit dem echten Eintrag kommt mit S3, wenn die App `current()` zum ersten Mal ruft. Dass der Eintrag Löschen und Neuinstallation überlebt, ist kein API-Versprechen (siehe Rationale); ein Verlust bedeutet nur eine neue Kennung, was der Dienst hinnimmt (gehaltene Aufträge werden nach zehn Minuten zurückgeholt).

## Test Plan

Unit-Tests (Swift Testing, wie die vorhandenen Testdateien dieses Bereichs) in `LooseEndsTests/DeviceIdentityTests.swift` und `LooseEndsTests/AccountStateTests.swift`. Lauf: `./scripts/sim.sh sim-unit DeviceIdentityTests`, `./scripts/sim.sh sim-unit AccountStateTests`, danach die ganze Suite `./scripts/sim.sh unit`.
**Keine UI-Tests:** der Schnitt hat keine Oberfläche und ändert nichts Sichtbares; es gibt keinen Ablauf, den ein UI-Test bedienen könnte (die Kontogruppe unter `--ui-testing` bleibt unberührt, ihre bestehenden Tests laufen unverändert mit).

| Test | AC |
|---|---|
| `firstCallCreatesAndStoresOnce` | AC-1 |
| `entryUsesDeviceOnlyAccessAndOwnService` | AC-2 |
| `storedIdentityIsReturnedUnchanged` | AC-3 |
| `noInMemoryCache` | AC-4 |
| `readErrorThrowsAndNeverCreates` | AC-5 |
| `corruptEntryThrowsAndIsNotReplaced` | AC-6 |
| `addErrorThrows` | AC-7 |
| `duplicateReturnsStoredIdentity` | AC-8 |
| `duplicateThenUnreadableThrows` | AC-9 |
| `errorsCarryNoIdentity` | AC-10 |
| `withSessionOnlyWhenSignedIn` | AC-11 |
| `withSessionWithoutReadableTokenIsNil` | AC-12 |
| `withSessionPassesFreshToken` | AC-13 |
| `withSessionKeepsSessionOnOtherErrors` | AC-14 |
| `unauthorizedClearsSameToken` | AC-15 |
| `unauthorizedKeepsNewerToken` | AC-16 |
| `unauthorizedNeverOverwritesRunningFlow` | AC-17 |
| `withSessionLeavesLastProblemAlone` | AC-18 |
| bestehende `deleteFailures`, `staleUnauthorized`, `deleteOnlyWhenSignedIn` und die ganze Suite `AccountStateTests` | AC-19 |
| ganze Suite, `creatingSendsNothing` (bestehend), Suche nach Aufrufern | AC-20 |

- [ ] Test 1 (AC-1 bis AC-4): GIVEN `FakeKeychain` mit Statusfolge WHEN `current()` läuft THEN Erzeugen genau einmal mit `ThisDeviceOnly`, Wiederfinden ohne `add`, kein Zwischenspeicher.
- [ ] Test 2 (AC-5 bis AC-7): GIVEN Lese-, Daten- und Schreibfehler WHEN `current()` läuft THEN `keychain(<Status>)` oder `corruptData`, nie eine neue Kennung, nie ein `update`.
- [ ] Test 3 (AC-8 bis AC-10): GIVEN `errSecDuplicateItem` WHEN `current()` läuft THEN die gespeicherte Kennung gewinnt, genau eine Wiederholung des Lesens, Fehlertexte ohne UUID.
- [ ] Test 4 (AC-11 bis AC-14, AC-18): GIVEN jeder Status, fehlender Token, Erfolg und jeder Nicht-401-Fehler WHEN `withSession` läuft THEN `nil`, Ergebnis oder weitergereichter Fehler, Sitzung und `lastProblem` unberührt.
- [ ] Test 5 (AC-15 bis AC-17): GIVEN 401 bei gleichem Token, neuerem Token und laufendem Ablauf WHEN `withSession` zurückkehrt THEN geräumt nur im ersten Fall, Status nur dann `signedOut`.
- [ ] Test 6 (AC-19, AC-20): GIVEN die ganze Suite WHEN sie läuft THEN grün, `deleteAccount` verhält sich wie vorher, kein Aufrufer außerhalb der beiden Dateien.

**Ehrlich zur Belegkraft:** TDD-Reihenfolge: die Tests werden vor dem Code geschrieben (RED: Kompilierfehler, weil `DeviceIdentity`, `DeviceIdentityError` und `withSession` fehlen), dann der Code (GREEN).

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): Schlüsselbund-Eintrag `AfterFirstUnlockThisDeviceOnly`, Lesefehler und kaputter Eintrag sind Fehler, Zugang als `AccountState.withSession`** | siehe Purpose | überlebt Neuinstallation in der Praxis, keine Doppelkennung über Backup, läuft im Hintergrund; eine Wahrheit über die Sitzung | ein kaputter Eintrag blockiert den Abgleich dieses Geräts (siehe Known Limitations) | nichts; keine ADR |
| **B Kaputten Eintrag selbst heilen** (ersetzen statt Fehler) | der Abgleich liefe weiter | kein Stillstand | heilt einen Zustand, den nur ein eigener Fehler erzeugen kann; ein Dekodierfehler im eigenen Code würde bei jedem Durchgang eine neue Kennung erzeugen, und jeder gehaltene Auftrag bekäme 409 | „Fehler statt stillem Ersetzen“ (diese Spec); verworfen |
| **C Zugang als eigener Typ `SessionAccess`** neben `AccountState` | `AccountState` bleibt kleiner | klare Trennung | der 401 muss den sichtbaren Status ändern, also gäbe es eine zweite Wahrheit über die Sitzung, die mit `AccountState` abgeglichen werden müsste | die Regel „der Besitzer des Status ändert ihn“; verworfen |
| **D Kennung in `UserDefaults` oder vom Dienst vergeben** | einfacher, oder serverseitig eindeutig | kein Schlüsselbund-Code | `UserDefaults` wandert mit dem Backup auf ein zweites Gerät: zwei Geräte mit derselben Kennung, dann 409 und Doppelvergabe; vom Dienst vergeben ändert den Vertrag Version 1 | ADR-21 (Schlüsselbund-Wahl) und der Vertrag „Wege der App“; verworfen |
| **E Kennung im Speicher zwischenspeichern** | ein Lesen weniger je Durchgang | schneller | der Zustand könnte vom Schlüsselbund abweichen, `KeychainSessionStore` ist ebenfalls zustandslos; ein Lesen je Durchgang kostet nichts | „zustandslos wie `KeychainSessionStore`“; verworfen |

## Out of Scope / Folgeschnitte

- **S3:** `ClaudeSync` (Durchgang: senden, holen, `OrderExecutor`, melden; ruft `withSession` und `DeviceIdentity.current()`; Abbruch bei `tooManyRequests`; `.unreadable` → `rejected/invalid`; `refused` verwerfen; bei `unauthorized` Durchgang beenden) und die Auslöser; **S5:** Weckruf. Ein Weg, einen kaputten Kennungs-Eintrag zu beheben, falls er je auftritt, gehört dorthin.
- Anzeige des Zustands (`lastProblem`, Hinweis auf eine abgeräumte Sitzung): keine Oberfläche in S2b.
- Änderungen an `ServiceClient.swift`, `KeychainSessionStore.swift`, `AccountWiring.swift`, `server/`, `Shared/`, Widgets, Watch, Mac-Fenster, `project.yml`: keine.

## Abnahme

**Kein Pfad der Geräteliste berührt.** (`LooseEnds/Claude/` und `LooseEndsTests/` stehen nicht darin; kein `project.yml`, keine Entitlements, keine `Info.plist`.) Die Abnahme endet nach Stufe 2: Stufe 1 sind die Unit-Tests (neue und bestehende, `./scripts/sim.sh unit`), Stufe 2 der Beleg „App startet unverändert im Simulator“ (`./scripts/sim.sh build`, `launch`, `screenshot` und der maschinelle Beleg `./scripts/sim.sh test-proof <Klasse>` einer bestehenden Smoke-Klasse; die Kontogruppe unter `--ui-testing` zeigt sich wie bisher); sichtbar ändert sich nichts, und das wird im Abschlussbericht gesagt. Gerätepunkte gibt es in diesem Schnitt nicht; die App ruft die neuen Teile erst ab S3.

## Definition of Done

- [ ] AC-1 bis AC-20 erfüllt, jeder über seinen benannten Test; Tests vor dem Code geschrieben (RED belegt)
- [ ] `./scripts/sim.sh unit` grün (gesamte Suite), Build erfolgreich
- [ ] Stufe 2: App startet unverändert im Simulator, Beleg liegt vor
- [ ] Kein Token, keine UUID und kein Wert in einem Fehlertext oder einer Logzeile (AC-10)
- [ ] Doku (keine Codedatei, zählt nicht zum Dateilimit): `CLAUDE.md` im Absatz `LooseEnds/Claude` um `DeviceIdentity` und `AccountState.withSession` ergänzt (eine Zeile, Hotspot, vor dem PR gegen `origin/main` abgleichen)
- [ ] PR mit `Refs #795`, CI grün, Merge durch Claude; #795 kommentiert (Stand S2b, Folge S3), Board-Karte aktuell, Memory geschrieben

## Known Limitations

- Ein kaputter Kennungs-Eintrag (keine UUID) blockiert den Abgleich dieses Geräts, bis S3 oder S5 einen Weg zeigt, ihn zu beheben; er wird bewusst nicht still ersetzt (Alternative B).
- Der Schlüsselbund-Eintrag überlebt das Löschen und Neuinstallieren der App nur in der Praxis, nicht per Zusage von Apple; geht er verloren, entsteht eine neue Kennung. Ein neues Gerät bekommt immer eine neue Kennung (gewollt).
- Der Durchlauf gegen den echten Schlüsselbund und den Live-Dienst ist nicht Teil dieses Schnitts (S3).

## Changelog

- 2026-11-12: Initial spec created (Schnitt S2b)
