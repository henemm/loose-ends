---
entity_id: feat-795-schnitt-5c1-weckruf-kern
type: feature
created: 2026-11-15
updated: 2026-11-15
status: draft
workflow: feat-795-s5c-weckruf-app
---

# Spec: Weckruf in der App, reiner Kern, Schnitt S5c-1 (#795, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#795 (Epic #612). Schnitt S5c-1 (erster von drei Teilen von S5c); das Issue bleibt offen (`Refs #795`, nie `Closes #795`).
Analyse: `docs/context/feat-795-s5c-weckruf-app.md` (Abschnitte „Analysis“, „Recherche“, „Risks“; verbindlich, die Detailnamen wurden gegen den Code geprüft und unten angepasst).
Vorgänger: S5a-1 (Dienstweg `POST /app/device`, `server/src/devices.ts`), S5a-2a/b (Absender, Weckruf eingehängt), S5b (Betrieb live, `/app/device` außen offen), S3b-1 (`ClaudeSyncTrigger`, `docs/specs/feat-795-schnitt-3b1-ausloeser.md`), S2b (`DeviceIdentity`, `AccountState.withSession`).
Es ist ein reiner App-Kern ohne Oberfläche: **fünf Dateien**, nichts in der App ruft die neuen Teile auf.

## Für den PO

Der Dienst für Claude kann seit Kurzem ein Gerät per stiller Mitteilung wecken, wenn ein neuer Auftrag da ist. Die App muss dafür dem Dienst sagen, unter welcher Adresse sie erreichbar ist, und beim Wecken sofort ihre Aufträge abholen. Dieser Schnitt baut die Bausteine dafür, ohne sie schon zu benutzen.

Für dich ändert sich nichts Sichtbares, und es geht nichts ins Netz, solange die späteren Schnitte die Bausteine nicht anschließen. Du musst nichts entscheiden und nichts tun.

## Purpose

Die App soll ihr Gerätetoken samt APNs-Umgebung beim Dienst anmelden und auf den Weckruf mit einem Durchgang „senden, dann holen“ antworten. Das ist zu groß für einen Schnitt (Delegates, Umgebungsmarke im Bau, Client, Registrierer, Trigger-Eingang). S5c-1 liefert den reinen, ohne Gerät testbaren Kern:

**1. `ServiceClient.putDevice(token:environment:sessionToken:device:)`** (`LooseEnds/Claude/ServiceClient.swift`): `POST /app/device` mit `Authorization: Bearer`, `X-Device` als UUID in Kleinschreibung (wie `claimOrder`/`putResult`), `Content-Type: application/json` und genau dem Körper `{"token": <Hex>, "environment": "sandbox" | "production"}`. Erfolg nur bei 204. Fehlerabbildung unverändert über das vorhandene private `send(_:success:)`: 401 `unauthorized`, 409 `refused`, 429 `tooManyRequests`, 503 und jeder `URLError` `unavailable`, abgebrochen `CancellationError`, jeder andere Status `rejected(n)` (auch 200). Nie Token, Körper oder URL in einem Fehler.

**2. `LooseEnds/Claude/DeviceRegistration.swift`** (neu):

- `enum PushEnvironment: String, Sendable { case sandbox, production }`: die Rohwerte sind genau die, die der Dienst erwartet. `init(infoValue: Any?)`: genau der String `"production"` ergibt `.production`, alles andere (fehlend, leer, falsche Schreibweise, anderer Typ, `"sandbox"`) ergibt `.sandbox`. `static var current` liest `Bundle.main.object(forInfoDictionaryKey: "LEApsEnvironment")`. Der Schlüssel kommt erst mit S5c-2b in `project.yml`; bis dahin ergibt `current` immer `.sandbox`.
- `@MainActor final class DeviceRegistration`: `init(account: AccountState, device: @escaping () throws -> UUID, environment: PushEnvironment)`. `func register(token: Data) async -> Outcome` mit `Outcome: Equatable, Sendable { registered, unchanged, notSignedIn, busy, failed(Failure) }` und `Failure: String { unauthorized, tooManyRequests, unavailable, serviceError, cancelled, deviceIdentity }` (der Rohwert ist der Fallname und das Einzige, was ins Log kommt; die Abbildung der Fehler entspricht der von `ClaudeSync`, dort ist sie privat und bleibt unberührt).
- Ablauf: `static func hex(_ token: Data) -> String` (kleingeschriebenes Hex, zwei Ziffern je Byte). Das Paar aus Hex und Umgebung ist der Wert. Ist es gleich dem zuletzt **erfolgreich** gemeldeten, geschieht nichts (`unchanged`, kein Netzaufruf). Läuft schon eine Meldung, wird nicht parallel gesendet (`busy`). Sonst genau ein Aufruf über `account.withSession` (die einzige Tür; ohne Sitzung `nil`, nichts gesendet, `notSignedIn`), das Gerät wird darin gelesen (Lesefehler ergibt `deviceIdentity`, nie eine neue Kennung). Bei 204 wird das Paar im Speicher gemerkt (`registered`); bei jedem Fehler wird nichts gemerkt, der nächste Aufruf sendet erneut (der Wiederholanlass kommt aus S5c-2a, hier gibt es weder Timer noch Schleife). Ein 401 räumt die Sitzung ab wie überall (`withSession`).
- Das Gemerkte lebt nur im Speicher: nach jedem Prozessstart wird einmal gesendet; das ist gewollt (der Dienst überschreibt eine Zeile je Konto und Gerät, `upsert`).
- Log: `Logger(subsystem: "com.henning.looseends", category: "device-registration")`, nur Fallnamen und der Typname des Fehlers, nie Token, Hex, Gerätekennung oder Sitzung. Kein `try?`, kein `print`.

**3. `ClaudeSyncTrigger.wake() async`** (`LooseEnds/Claude/ClaudeSyncTrigger.swift`): der Eingang für den Weckruf. Er läuft wie „senden, dann holen“ (Start, Vordergrund), kehrt aber erst zurück, nachdem ein Holen **beendet** ist, das **nach dem Aufruf von `wake()` begonnen** hat. Ein Holen, das schon vor dem Aufruf lief, zählt nicht, weil es einen Auftrag, der erst kurz vorher beim Dienst ankam, verpasst haben kann.

- Läuft schon ein Senden, wird nicht parallel gesendet; der Wartende kommt nach dem Senden samt vorgemerkter Wiederholung und dem folgenden Holen dran (Regeln aus S3b-1: nie zwei Sendungen gleichzeitig, höchstens eine wartende Neusendung, Holen nur nach dem Senden).
- Läuft schon ein Holen, wird das für `wake()` nötige Holen erst gestartet, wenn das laufende beendet ist (nicht parallel: `ClaudeSync` würde dort `busy` melden und nichts holen, und `wake()` hätte ohne Holen zurückgegeben).
- Mehrere Wartende werden alle genau einmal geweckt; ein Holen, das nach allen ihren Aufrufen begann, deckt sie gemeinsam ab; wer erst während eines Holens kommt, bekommt ein weiteres.
- `wake()` braucht kein vorheriges `start()` und registriert keine Beobachter. Bricht der Aufrufer ab, bleibt sein Wartender bis zum nächsten Holen stehen und wird dann ohne Wirkung geweckt (der Aufrufer in S5c-2a setzt die Frist selbst, mit einer eigenen Aufgabe daneben; hier gibt es keinen Abbruchpfad, der den Wartenden verlieren könnte).
- Ergebnistyp: **`Void`**, nicht `ClaudeSync.Ending?`. Die eingereichten Aktionen des Triggers (`send`, `pull`: `() async -> Void`) liefern kein `Ending` zurück, und `Ending.done` unterscheidet „Aufträge ausgeführt“ nicht von „nichts da“; ein ehrliches `.newData`/`.noData` ließe sich daraus ohnehin nicht ableiten. Der Handler in S5c-2a meldet nach einem beendeten `wake()` `.newData` und nach der Frist `.noData`; die Endungen stehen wie bisher im Log der Fabrik. Das ändert die Signatur von `init`, `forApp` und der Aktionen nicht.
- Unter `silent` (Tests) sind die Aktionen leer; `wake()` läuft den Ablauf mit den leeren (oder von Tests eingespeisten) Aktionen und kehrt danach zurück.

**Nichts wird aufgerufen.** `putDevice`, `DeviceRegistration`, `PushEnvironment` und `wake()` haben keinen Aufrufer in der App; `LooseEndsApp`, die Delegates, `AccountWiring`, `project.yml` und jede `Info.plist` bleiben unberührt. Das Anschließen (Delegates, `registerForRemoteNotifications`, Weckruf-Eingang) ist S5c-2a, die Umgebungsmarke im Bau ist S5c-2b.

**Regeln vor Modell:** reine Wire-, Zustands- und Ablauffrage ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR; setzt ADR-21 (Dienst für Claude, Weg B) samt Addendum Weckruf und den Vertrag „Wege der App“ (`docs/reference/claude-abschrift-vertrag.md`, `POST /app/device`) um, ohne sie zu ändern. Keine neue Abhängigkeit, kein Schema, keine Berechtigung.
- **Rationale:** Die Umgebung kommt aus einer Marke im Bau (`LEApsEnvironment`, Vorgabe `sandbox`, nur der TestFlight-Lauf setzt `production`, im Archiv gegen das signierte Entitlement geprüft in S5c-2b) statt aus einer Vermutung zur Laufzeit; `PushEnvironment` liest nur diese Marke. Registrierer und Trigger-Eingang sind eigene, mit Attrappen prüfbare Bausteine (Muster `ClaudeSyncTrigger`, #795 S3b-1), damit die Delegates in S5c-2a nur noch verdrahten.

## Source

- **File:** `LooseEnds/Claude/DeviceRegistration.swift` (neu); geändert `LooseEnds/Claude/ServiceClient.swift`, `LooseEnds/Claude/ClaudeSyncTrigger.swift`
- **Identifier:** `ServiceClient.putDevice(token:environment:sessionToken:device:)`, `PushEnvironment`, `DeviceRegistration.register(token:)`, `DeviceRegistration.hex(_:)`, `ClaudeSyncTrigger.wake()`

**Unberührt:** `ClaudeSync.swift`, `AccountState.swift`, `DeviceIdentity.swift`, `AccountWiring.swift`, `LooseEnds/App/`, `LooseEnds/Mac/`, `LooseEnds/Notifications/`, `Shared/`, `server/`, `project.yml`, jede `Info.plist`, Entitlements, `.github/`, `ServiceClientTests.swift` (Swift Testing; die neuen Wire-Tests stehen in XCTest, weil das QA-Gate nur XCTest zählt).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `AccountState.withSession` (S2b) | bestehend, unverändert; einzige Tür zum neuen Weg |
| `DeviceIdentity().current()` (S2b) | bestehend, unverändert; als Closure eingereicht (`device`) |
| `ServiceClient.send(_:success:)`, `ServiceError`, `HTTPTransport` | bestehend, unverändert |
| `ClaudeSyncTrigger` (S3b-1) und seine Regeln | bestehend, erweitert um `wake()` |
| Dienst `POST /app/device` (`server/src/devices.ts`, S5a-1; live seit S5b) | bestehend, unverändert: Körper genau `token` (Hex, gerade Länge, 64 bis 200) und `environment` |
| Downstream | S5c-2b (Umgebungsmarke im Bau), S5c-2a (Delegates, Weckruf-Eingang), die Reihenfolge ist 2b vor 2a, damit `current` nie ungeprüft `sandbox` meldet |

## Acceptance Criteria

Belegt durch benannte XCTest-Tests: `LooseEndsTests/DeviceRegistrationTests.swift` (neu: AC-1 bis AC-10, eigene Transport-Attrappe, `AccountState` mit `InMemorySessionStore` im Status `signedIn`) und `LooseEndsTests/ClaudeSyncTriggerTests.swift` (AC-11 bis AC-15, die vorhandene Hilfsklasse `Calls` bekommt eine einstellbare Dauer für `pull`, die vorhandenen Tests bleiben unverändert grün). Gewartet wird mit Fristen (`waitUntil`), nie mit festem langem Schlafen.

- **AC-1:** Wire: GIVEN ein Client mit Attrappe-Transport und Antwort 204 WHEN `putDevice(token: "ab12…", environment: .production, sessionToken: S, device: D)` läuft THEN ging genau eine Anfrage `POST` an `/app/device` (auch unter Basis mit Pfad) mit `Authorization: Bearer S`, `X-Device` gleich `D` in Kleinschreibung, `Content-Type: application/json` und einem Körper, dessen Schlüssel genau `token` und `environment` sind (Werte `ab12…` und `production`); für `.sandbox` steht `sandbox` (Test `putDeviceWire`).
- **AC-2:** Statusabbildung: GIVEN dieselbe Lage WHEN der Dienst 401, 409, 429, 503, 400, 413, 500 oder 200 antwortet THEN wirft `putDevice` der Reihe nach `unauthorized`, `refused`, `tooManyRequests`, `unavailable`, `rejected(400)`, `rejected(413)`, `rejected(500)`, `rejected(200)`; nur 204 ist Erfolg (Test `putDeviceStatusMapping`).
- **AC-3:** Fehler ohne Geheimnis: GIVEN Antworten 401, 500 und 200 mit einem Körper, der „SECRET-BODY“ enthält, und ein `URLError(.timedOut)` WHEN `putDevice` mit Sitzungstoken „SECRET-SESSION“ und Gerätetoken „SECRET-DEVICE“ läuft THEN enthält die Beschreibung keines geworfenen Fehlers eines dieser Wörter; `URLError(.cancelled)` ergibt `CancellationError`, ein anderer `URLError` ergibt `unavailable` (Test `putDeviceErrorsCarryNoSecrets`).
- **AC-4:** Umgebung: GIVEN die Werte `"production"`, `"sandbox"`, `"Production"`, `""`, `nil`, `42` und `"prod"` WHEN `PushEnvironment(infoValue:)` sie liest THEN ergibt nur der String `"production"` `.production`, alle anderen `.sandbox`; die Rohwerte der Fälle sind `sandbox` und `production` (Test `environmentFromInfoValue`).
- **AC-5:** Hex: GIVEN `Data` aus den Bytes `00 0f a0 ff` und 32 Bytes von `0x00` bis `0x1f` WHEN `DeviceRegistration.hex` sie umsetzt THEN entstehen `000fa0ff` und ein kleingeschriebener String von 64 Zeichen (Test `hexIsLowercaseTwoDigitsPerByte`).
- **AC-6:** Melden: GIVEN ein angemeldetes Konto, ein Gerät `D`, Umgebung `.sandbox` und Antwort 204 WHEN `register(token:)` läuft THEN ist das Ergebnis `registered`, und genau eine Anfrage ging mit dem Hex des Tokens, `sandbox`, dem Sitzungstoken des Stores und `X-Device` gleich `D` hinaus (Test `registersTokenThroughTheSession`).
- **AC-7:** Ohne Sitzung kein Netz: GIVEN ein Konto im Status `signedOut` WHEN `register(token:)` läuft THEN ist das Ergebnis `notSignedIn` und der Transport hat keine Anfrage erhalten; ebenso wird `device` nicht gelesen (Test `withoutSessionNothingIsSent`).
- **AC-8:** Gleiches Paar nicht erneut: GIVEN ein erfolgreich gemeldetes Paar WHEN `register` mit demselben Token und derselben Umgebung noch einmal läuft THEN ist das Ergebnis `unchanged` und es ging keine zweite Anfrage hinaus; mit einem anderen Token geht eine zweite Anfrage hinaus, und eine zweite `DeviceRegistration` mit `.production` für denselben Token sendet ebenfalls (Test `samePairIsSentOnlyOnce`).
- **AC-9:** Fehler wird wiederholt: GIVEN Antworten 503 und danach 204 WHEN `register` zweimal mit demselben Token läuft THEN ist das erste Ergebnis `failed(.unavailable)`, das zweite `registered` (zwei Anfragen); für 429 `failed(.tooManyRequests)`, für 500 `failed(.serviceError)`, für 401 `failed(.unauthorized)` und das Konto ist danach `signedOut`; wirft `device` einen Fehler, ist das Ergebnis `failed(.deviceIdentity)` und es ging nichts hinaus (Test `failureIsRetriedAndNothingIsRemembered`).
- **AC-10:** Nie parallel: GIVEN eine Antwort, die erst nach einer Verzögerung kommt WHEN `register` während der laufenden Meldung ein zweites Mal gerufen wird THEN ist das zweite Ergebnis `busy` und es ging nur eine Anfrage hinaus (Test `noSecondRegistrationWhileOneRuns`).
- **AC-11:** `wake` im Leerlauf: GIVEN ein Trigger mit gezählten Aktionen, `start()` nicht gerufen WHEN `wake()` aufgerufen wird THEN laufen `send`, dann `pull` je einmal in dieser Reihenfolge, und `wake()` kehrt erst nach dem Ende von `pull` zurück (`pull` mit Verzögerung; der Rückkehrzeitpunkt liegt nach dem Eintrag „pulled“) (Test `wakeReturnsAfterSendAndPull`).
- **AC-12:** `wake` während eines Sendens: GIVEN ein `send`, das erst nach einer Verzögerung endet WHEN währenddessen `wake()` aufgerufen wird THEN laufen nie zwei `send` gleichzeitig, `pull` beginnt erst nach dem Ende des laufenden Sendens (und einer vorgemerkten Wiederholung), und `wake()` kehrt erst nach diesem Holen zurück; ein Kaltstart `start()` gefolgt von sofortigem `wake()` verhält sich ebenso und der Weckrufer wartet auf das Holen, nicht nur auf den Start-Durchgang (Test `wakeDuringASendWaitsForTheFollowingPull`).
- **AC-13:** `wake` während eines Holens: GIVEN ein `pull`, das noch läuft, weil es vor dem Aufruf begann WHEN `wake()` aufgerufen wird THEN läuft ein zweites Holen erst nach dem Ende des ersten (nie zwei gleichzeitig) und `wake()` kehrt erst nach dem Ende dieses zweiten Holens zurück (Test `wakeDuringAPullWaitsForAnotherPull`).
- **AC-14:** Mehrere Wartende: GIVEN drei `wake()`-Aufrufe in schneller Folge WHEN der Durchgang läuft THEN kehren alle drei genau einmal zurück, jeder erst nach einem Holen, das nach seinem Aufruf begann, und es laufen nie zwei `send` oder zwei `pull` gleichzeitig; ein weiterer Aufruf, der erst mitten im Holen kommt, wird von einem zusätzlichen Holen bedient (Test `severalWakesAreAllWokenOnce`).
- **AC-15:** Regeln aus S3b-1 bleiben: GIVEN `wake()` läuft WHEN `didSave` gepostet wird THEN folgt weiter nur ein entprelltes `send` und kein `pull` aus dem Speichern; `wake()` registriert keine Beobachter (ohne `start()` löst `didBecomeActive` nichts aus); unter Unit-Test ohne eingereichte Aktionen kehrt `wake()` sofort und ohne Absturz zurück (Test `wakeKeepsTheTriggerRules`). Alle vorhandenen Tests von `ClaudeSyncTriggerTests` und `ServiceClientTests` laufen unverändert grün.
- **AC-16:** Nichts ruft den Kern auf, ohne Geheimnis im Log: GIVEN der Quelltext WHEN er durchsucht wird THEN stehen `putDevice(`, `DeviceRegistration` und `.wake(` außerhalb der eigenen Dateien und der Tests nirgends in `LooseEnds/`; `DeviceRegistration.swift` und die geänderten Zeilen enthalten weder `try?` noch `print(`, und keine Logzeile enthält Token, Hex oder Gerätekennung (Quellsuche als Beleg im Abschlussbericht; kein Swift-Test).
- **AC-17:** Ganze Suite grün: GIVEN die ganze Unit-Suite WHEN sie im Simulator läuft THEN ist sie grün und das Projekt baut für iOS-Simulator ohne Fehler (`./scripts/sim.sh unit`, `./scripts/sim.sh build`; Beleg im Abschlussbericht).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/ServiceClient.swift` | MODIFY | `putDevice(token:environment:sessionToken:device:)` nach dem Muster von `putResult`; ≈ +10 |
| `LooseEnds/Claude/DeviceRegistration.swift` | CREATE | `PushEnvironment`, `DeviceRegistration`, `Outcome`, `Failure`, Log; ≈ +75 |
| `LooseEnds/Claude/ClaudeSyncTrigger.swift` | MODIFY | `wake()`, Warteliste, Holen nach dem Aufruf und nie parallel; ≈ +35 |
| `LooseEndsTests/DeviceRegistrationTests.swift` | CREATE | Wire-, Status- und Registrierungstests (AC-1 bis AC-10), eigene Attrappe; ≈ +130 |
| `LooseEndsTests/ClaudeSyncTriggerTests.swift` | MODIFY | `pull`-Dauer in `Calls`, Tests zu `wake` (AC-11 bis AC-15); ≈ +70 |
| `CLAUDE.md` | MODIFY | Doku, zählt nicht zum Dateilimit: eine Zeile im Absatz `LooseEnds/Claude` (Hotspot, vor dem PR gegen `origin/main` abgleichen) |

### Estimated Changes

- **Dateien: 5** (zwei neu, drei geändert), am oberen Rand des Limits von 4 bis 5.
- **LoC: ≈ +420** insgesamt, davon Code ≈ 120 und Tests ≈ 300 (17 ACs, Nebenläufigkeit und Fehlertabellen, nach den Erfahrungswerten früherer Schnitte ≈ 18 Zeilen je AC plus Attrappe). Das liegt über ±250; der Überhang sind Sicherheits- und Reihungstests (Wire, Fehlerabbildung ohne Geheimnis, `wake`-Reihenfolgen), Kürzen schwächte die Prüfung. Eine Teilung (Registrierer und `wake()` getrennt) wäre möglich, brächte aber zwei Schnitte ohne Aufrufer. Die Annahme dieses Umfangs ist Teil der Freigabe; nach RED werden die Testzeilen gezählt, und über **520** gesamt wird vor dem Bauen gemeldet. Keine Funktion über 50 Zeilen.
- Keine Permissions, keine `Info.plist`-Einträge, keine AppStorage-Keys, kein CloudKit-Schema, keine Audio-Dateien, keine Oberfläche, keine neue Abhängigkeit. `generate` muss laufen, weil zwei Dateien neu sind.
- **Seiteneffekte nach außen:** keine; nichts ruft den neuen Code auf (AC-16).
- **Parallele Arbeit:** vor dem PR `origin/main` und offene PRs auf Berührung von `LooseEnds/Claude/` prüfen; die Sitzung für #932 (Titel und Felder aus Claude) berührt `server/` und eventuell `OrderExecutor`, nicht diese Dateien.

## Implementation Details

- `putDevice` ist ein Dreizeiler über `bearer(path:)` und `send(success: [204])`; der Körper wird mit `JSONSerialization` aus einem `[String: String]` gebaut, `X-Device` wie in `putResult`.
- `DeviceRegistration` ist `@MainActor`, damit `lastSent` und `running` ohne Sperre geschützt sind; das Paar wird als `String` `"<hex>|<environment>"` oder als kleine Struktur gehalten. Der Aufruf in `withSession` liest `device()` innerhalb der Closure (wie `ClaudeSync`), damit ohne Sitzung nichts gelesen wird (AC-7).
- `wake()`: Weckrufer tragen sich in eine Liste von `CheckedContinuation<Void, Never>` ein und setzen die vorhandene Marke „holen nach senden“; beim Start eines Holens im `drain` wird die Liste als Gruppe übernommen und geleert, nach dem Ende des Holens wird genau diese Gruppe geweckt; ist die Liste danach nicht leer (Aufrufe kamen während des Holens), läuft der Ablauf noch einmal. Das Holen wird vom Trigger selbst gereiht (ein Merker `pulling`), nicht auf `ClaudeSync.busy` verlassen. Das bestehende Verhalten für Start und Vordergrund bleibt dabei dasselbe.

## Test Plan

### Automated Tests (TDD RED)

Unit-Tests (XCTest). Lauf: `./scripts/sim.sh sim-unit DeviceRegistrationTests`, `./scripts/sim.sh sim-unit ClaudeSyncTriggerTests`, danach die ganze Suite `./scripts/sim.sh unit`. TDD-Reihenfolge: die Tests werden vor dem Code geschrieben (RED: Kompilierfehler, weil `putDevice`, `DeviceRegistration` und `wake` fehlen), dann der Code (GREEN). **Keine neuen UI-Tests:** der Schnitt hat keine Oberfläche, nichts Sichtbares, keinen Ablauf, den ein UI-Test bedienen könnte.

- [ ] Test 1 (AC-1 bis AC-3): GIVEN ein Client mit Attrappe-Transport WHEN `putDevice` mit 204, den Fehlerstatus und Transportfehlern läuft THEN stimmen Weg, Kopfzeilen, Körper und Fehlerfälle, und kein Fehler trägt ein Geheimnis.
- [ ] Test 2 (AC-4, AC-5): GIVEN Info-Werte und Token-Bytes WHEN `PushEnvironment` und `hex` sie umsetzen THEN nur „production“ ergibt production und das Hex ist klein und zweistellig je Byte.
- [ ] Test 3 (AC-6 bis AC-10): GIVEN ein Konto mit und ohne Sitzung WHEN `register` läuft THEN wird über die Sitzung gemeldet, ohne Sitzung nichts gesendet, dasselbe Paar nicht erneut, ein Fehler erneut versucht und nie parallel gesendet.
- [ ] Test 4 (AC-11 bis AC-15): GIVEN gezählte Aktionen mit Verzögerung in `send` und `pull` WHEN `wake()` im Leerlauf, während eines Sendens, während eines Holens und mehrfach gerufen wird THEN kehrt jeder Aufruf erst nach einem Holen zurück, das nach ihm begann, ohne dass Sendungen oder Holen sich überlappen.

**Ehrlich zur Belegkraft:** Die Tests belegen den Draht, die Regeln des Registrierers und die Reihung des Triggers gegen Attrappen. Dass ein echtes Gerät den Token liefert, dass der Dienst den Weckruf an den richtigen Host schickt und dass die Delegates beides anstoßen, belegt dieser Schnitt nicht; das ist S5c-2a (mit Stufe 3 über TestFlight).

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): Umgebung aus einer Marke im Bau, `PushEnvironment` liest nur sie** | Info `LEApsEnvironment`, Vorgabe `sandbox`, nur TestFlight setzt `production` (S5c-2b), im Archiv gegen das Entitlement geprüft | belegbar richtig, kein Raten; Muster `LEAccountEnabled` | braucht den Bau-Schritt in S5c-2b; bis dahin immer `sandbox` | nichts; keine ADR |
| **B `embedded.mobileprovision` zur Laufzeit lesen** | `aps-environment` aus dem Provisioning-Profil | übliche Praxis (Firebase) | Format proprietär; ob TestFlight-Bauten die Datei enthalten, ist nicht belegt (Recherche in der Analyse); eine falsche Umgebung lässt den Dienst den Token löschen (S5a-2a) und den Weckruf still sterben | nichts; keine ADR; verworfen |
| **C Beide Umgebungen melden** | Token einmal als `sandbox`, einmal als `production` | kein Raten nötig | der Dienst hält eine Zeile je Konto und Gerät (`device_tokens`, Migration 008), die zweite überschriebe die erste | die Tabellenform aus S5a-1 (Migration 008, ADR-21-Addendum Weckruf); verworfen |
| **D Kein App-Teil, nur Holen bei Start und Vordergrund** | der Zustand heute | kein Aufwand, kein Gerätepfad | der Weckruf des Dienstes (live seit S5b) hätte keinen Empfänger; fällt hinter die PO-Entscheidung A vom 2026-11-13 | die PO-Entscheidung A und das ADR-21-Addendum Weckruf; verworfen |
| **E `wake()` liefert `ClaudeSync.Ending?`** | ehrliche Rückgabe an den Handler | Handler könnte `.noData` bei `notSignedIn` melden | die Aktionen des Trigger-Inits liefern kein `Ending`, das Signaturen von `init`, `forApp` und alle Tests änderte; `done` unterscheidet „Aufträge“ nicht von „nichts da“, der Gewinn wäre gering | nichts; keine ADR; verworfen für diesen Schnitt |
| **F Registrierung in `ClaudeSync` oder im Trigger** | ein Ort für alles | weniger Dateien | vermischt Abschrift und Gerätemeldung, `ClaudeSync` bliebe nicht unverändert; die Meldung hat einen eigenen Anlass (Token-Rückruf) | nichts; keine ADR; verworfen |

## Out of Scope / Folgeschnitte

- **S5c-2b** (eigener Workflow, Pfad der Geräteliste `project.yml`): Info `LEApsEnvironment: sandbox` in `project.yml`, `testflight.yml` setzt per `plutil` `production`, Archivprüfung kreuzweise gegen das signierte Entitlement (iOS und Mac; der Mac-Schlüssel ist dort zu klären). Kommt vor S5c-2a.
- **S5c-2a** (eigener Workflow, Pfade der Geräteliste): iOS-App-Delegate (neu) und `MacAppDelegate`, Token- und Fehler-Rückrufe an `DeviceRegistration`, `didReceiveRemoteNotification` nur für den Schlüssel `looseends` (CloudKit-Mitteilungen sofort `.noData`), Abschluss genau einmal (Lehre #780/#782), Frist gegen `wake()`, Übergabe von `account` und `claudeSync` an den Delegate, `registerForRemoteNotifications` beim Start mit Konto und nach späterer Anmeldung, Wiederholanlass für ein fehlgeschlagenes Melden, Stufe 3 über TestFlight (CloudKit-Koexistenz nur auf dem Gerät belegbar).
- Änderungen an `ClaudeSync.swift`, `AccountState.swift`, `DeviceIdentity.swift`, `server/`, Oberfläche, Watch, Widgets: keine.

## Abnahme

**Kein Pfad der Geräteliste berührt.** (`LooseEnds/Claude/` und `LooseEndsTests/` stehen nicht in der Liste; kein `project.yml`, keine Entitlements, keine `Info.plist`.) Die Abnahme endet nach Stufe 2: Stufe 1 sind die Unit-Tests (neue und bestehende, `./scripts/sim.sh unit`). Stufe 2 ist hier der Lauf dieser Unit-Tests im iOS-Simulator samt erfolgreichem Simulator-Bau (`./scripts/sim.sh build`), weil der Schnitt keinen sichtbaren Ablauf hat: nichts ruft den Kern auf, es gibt keine Oberfläche und keinen Bedienweg, den man durchspielen oder fotografieren könnte, und die App startet unverändert. Das wird im Abschlussbericht so gesagt, und es wird nicht behauptet, die Kette bis zum Dienst oder zum Gerät sei belegt; sie schließt erst mit S5c-2a. Gerätepunkte gibt es in diesem Schnitt nicht.

## Definition of Done

- [ ] AC-1 bis AC-17 erfüllt, jeder über seinen benannten Test beziehungsweise Beleg; Tests vor dem Code geschrieben (RED belegt)
- [ ] `./scripts/sim.sh unit` grün (gesamte Suite), Simulator-Bau erfolgreich
- [ ] Abnahme: „Kein Pfad der Geräteliste berührt.“
- [ ] Kein Token, kein Hex, keine Gerätekennung in einer Logzeile; kein `try?`, kein `print(` (AC-16)
- [ ] Doku (zählt nicht zum Dateilimit): `CLAUDE.md` im Absatz `LooseEnds/Claude` um `putDevice`, `DeviceRegistration` und `ClaudeSyncTrigger.wake()` ergänzt (Hotspot, vor dem PR gegen `origin/main` abgleichen)
- [ ] PR mit `Refs #795`, CI grün, Merge durch Claude; #795 kommentiert (Stand S5c-1, Folge S5c-2b, dann S5c-2a), Board-Karte aktuell, Memory geschrieben

## Known Limitations

- Bis S5c-2b liefert `PushEnvironment.current` immer `.sandbox`; S5c-2a darf deshalb nicht vor S5c-2b ausgeliefert werden, sonst meldet ein TestFlight-Bau die falsche Umgebung und der Dienst löscht den Token.
- Das Gemerkte im Registrierer lebt nur im Speicher; jeder Prozessstart meldet einmal erneut (harmlos, der Dienst überschreibt).
- `wake()` meldet nicht, ob Aufträge ausgeführt wurden (siehe Alternative E); der Handler in S5c-2a behandelt jedes beendete `wake()` als „neue Daten“.
- Ein abgebrochener Aufrufer von `wake()` lässt seinen Wartenden bis zum nächsten Holen stehen; er wird dann ohne Wirkung geweckt.
- AC-16 (Quellsuche) und AC-17 (Suite und Bau) sind Belege im Abschlussbericht, keine einzelnen Swift-Tests.

## Changelog

- 2026-11-15: Initial spec created (Schnitt S5c-1)
