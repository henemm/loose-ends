---
entity_id: feat-615-schnitt-4b3-schluesselbund
type: feature
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: feat-615-s4b3-schluesselbund
---

# Spec: App-Kern Anmeldung, Schnitt 4b-3: Sitzungstoken im Schlüsselbund (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Teil-Spec für Schnitt 4b-3; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s4b3-schluesselbund.md` (Abschnitt „Technical Approach“ ist verbindlich). Vorgänger: Schnitt 4b-2
(`docs/specs/feat-615-schnitt-4b2-sitzung.md`, PR #886: `SessionStoring`, `InMemorySessionStore`, `AccountState`). Diese Spec deckt nur
4b-3 ab; Oberfläche und Wahl der Ablage in der App sind Schnitt 4c.

## Für den PO

Dieser Schritt baut im Inneren der App den sicheren Speicher auf dem Gerät, in dem später die Anmeldung beim Dienst für Claude abgelegt
wird (der Schlüsselbund, in dem Apple Passwörter verwahrt). Außerdem wird eine kleine Unsauberkeit beim Abbrechen einer Anfrage
behoben. Du siehst davon nichts: Die App benutzt den Speicher noch nirgends, es gibt keine Schaltfläche. Du musst nichts tun.

## Purpose

`KeychainSessionStore` ist die echte Ablage hinter `SessionStoring` aus 4b-2. Das Systemstück (`SecItem*`) steht hinter einem schlanken
Protokoll `KeychainOperations` (Muster wie `HTTPTransport`), damit Abfragen, Statusabbildung und der Ablauf von `save`, `load` und `clear`
im Unit-Test belegt sind, obwohl der echte Schlüsselbund im Testhost `-34018` liefert. Dazu F4 aus dem Prüfdialog von 4b-2:
`ServiceClient` reicht `URLError(.cancelled)` als `CancellationError` weiter statt als `unavailable`. Nichts in der App ruft den Store
auf. **Regeln vor Modell:** Protokoll- und Zustandsarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue — Ausgestaltung von ADR-21 (Weg B, Sitzungstoken nur im Schlüsselbund, nie in `UserDefaults`); keine neue Abhängigkeit (Security.framework gehört zum System-SDK).
- **Rationale:** (1) Das Systemstück ist dünn und austauschbar (`KeychainOperations`), die Logik rein und testbar. (2) Duplikat → Update nur mit dem Wert, kein Löschen-dann-Anlegen: das verliert keine Metadaten und hat kein Zeitfenster ohne Token. (3) Jeder unbekannte Status, auch `-34018` (fehlende Berechtigung), ist ein Fehler, nie `nil`: sonst läse die App eine fehlende Berechtigung als „abgemeldet“. (4) `kSecUseDataProtectionKeychain` steht in jeder Abfrage, damit macOS den Data-Protection-Speicher statt des veralteten Datei-Schlüsselbunds nimmt (auf iOS wirkungslos). (5) Kein Fehlerwert enthält das Token.
- **Alternativen (verworfen):**
  - **A:** Echter Schlüsselbund-Test über die App im Simulator: einziger Beleg des echten Systems, gehört aber in 4c (App-Host, Ablagewahl `forApp`), wie in 4b-2 geplant. Ergänzt diesen Schnitt, ersetzt ihn nicht.
  - **B:** Ablage als Datei mit Data Protection: Token im Klartext auf der Platte, widerspricht 4b-2 und ADR-21 — verworfen.
  - **Ohne `KeychainOperations` (nur reine Funktionen für Abfragen und Status):** kleiner, aber der Ablauf von `save` (Add → Duplikat → Update) bliebe bis 4c unbelegt. Rückfall nur bei Überschreitung der LoC-Grenze (siehe Estimated Changes).

## Source

**Files (CREATE):** `LooseEnds/Claude/KeychainSessionStore.swift`, `LooseEndsTests/KeychainSessionStoreTests.swift`
**Files (MODIFY):** `LooseEnds/Claude/SessionStore.swift`, `LooseEnds/Claude/ServiceClient.swift`, `LooseEndsTests/ServiceClientTests.swift`, `CLAUDE.md` (Doku)
**Identifier:** `KeychainSessionStore`, `KeychainOperations`, `KeychainQuery`, `SessionStoreError.keychain(OSStatus)`, `SessionStoreError.corruptData`

### `KeychainOperations` (`KeychainSessionStore.swift`)

- `protocol KeychainOperations: Sendable` mit vier Operationen, jede gibt einen `OSStatus` zurück (Lesen zusätzlich die Daten): `add(_ attributes: [String: Any]) -> OSStatus`, `copyMatching(_ query: [String: Any]) -> (OSStatus, Data?)`, `update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus`, `delete(_ query: [String: Any]) -> OSStatus`. Die genaue Signatur wählt der Bau; sie ist `Sendable`-sauber unter Swift 6 strict concurrency.
- Die echte Hülle (`SystemKeychain: KeychainOperations`) ruft nur `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete` und enthält sonst keine Logik.

### Reine Teile (`KeychainQuery` bzw. gleichwertig, `KeychainSessionStore.swift`)

- `base`: `kSecClass = kSecClassGenericPassword`, `kSecAttrService = "com.henning.looseends.session"`, `kSecAttrAccount` = ein festes Konto (Konstante), `kSecUseDataProtectionKeychain = true`. **In jeder Abfrage** (add, read, update, delete) enthalten; kein `kSecAttrSynchronizable` in irgendeiner.
- `add`: `base` + `kSecValueData` (Token als UTF-8) + `kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- `read`: `base` + `kSecReturnData = true` + `kSecMatchLimit = kSecMatchLimitOne`.
- `update`: Suchabfrage `base`; Änderungsattribute **nur** `kSecValueData`.
- Statusabbildung je Operation als reine Funktion: Erfolg `errSecSuccess`; beim Lesen `errSecItemNotFound` → `nil`; beim Löschen `errSecItemNotFound` → Erfolg; beim Anlegen `errSecDuplicateItem` → Update; jeder andere Status → `SessionStoreError.keychain(status)`.
- Dekodierung: `Data?` → `String`; leere Daten oder Daten ohne gültiges UTF-8 → `SessionStoreError.corruptData`.

### `KeychainSessionStore: SessionStoring` (`KeychainSessionStore.swift`)

- `init(operations: any KeychainOperations = SystemKeychain())`; `Sendable`.
- `save(_ token:)`: `add`; bei `errSecDuplicateItem` genau ein `update` mit nur dem Wert (kein `delete`); meldet das Update `errSecItemNotFound` (Rennen: der Eintrag ist zwischen Add und Update verschwunden), ist das ein Fehler `keychain(errSecItemNotFound)`, **kein** Wiederholen. Jeder andere Nicht-Erfolgsstatus → `keychain(status)`.
- `load()`: `copyMatching`; NotFound → `nil`; Erfolg → dekodieren; sonst `keychain(status)`.
- `clear()`: `delete`; Erfolg und NotFound → kein Fehler; sonst `keychain(status)`.
- Weder ein Fehlerwert noch ein Log nennt das Token; es gibt kein `print`, kein `try?` und keinen Logger-Aufruf mit Tokenwert.

### Änderungen an Bestehendem

- `SessionStoreError` (`SessionStore.swift`) um `case keychain(OSStatus)` und `case corruptData` erweitert (`Equatable` bleibt); der Doc-Kommentar „The keychain store follows in S4b-3“ wird angepasst.
- `ServiceClient.send(_:success:)` (`ServiceClient.swift`): eigener `catch let error as URLError where error.code == .cancelled` **vor** dem allgemeinen `catch is URLError`, wirft `CancellationError()`; alle übrigen `URLError`-Codes bleiben `ServiceError.unavailable`. Doc-Kommentar angepasst.
- `CLAUDE.md`: Der Eintrag „`LooseEnds/Claude`“ unter „Where things live“ nennt zusätzlich `SessionStoring`/`InMemorySessionStore`/`SessionStoreError`, `KeychainSessionStore` hinter `KeychainOperations` (Schlüsselbund, noch ohne Aufrufer) und `AccountState` (Kontozustand aus 4b-2, noch ohne Aufrufer).

### Festlegungen

- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Swift 6 strict concurrency ohne Warnung; kein `try?`, das Fehler schluckt; `Logger` statt `print`; keine neuen Pakete.
- **Unberührt:** `project.yml`, jede `*.entitlements`, jede `Info.plist`, `Shared/`, `server/`, `AccountState.swift`, `LooseEnds/Views`. Keine neuen Dateien in Zielordnern außer den zwei genannten; nach dem Anlegen läuft `./scripts/sim.sh generate`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `LooseEnds/Claude/SessionStore.swift` (4b-2, `SessionStoring`) | wird erweitert (Fehlerfälle) |
| `LooseEnds/Claude/ServiceClient.swift` (4b-1) | wird geändert (F4) |
| `LooseEnds/Claude/AccountState.swift` | unverändert; bildet `CancellationError` → `signedOut`, Ablagefehler werden dort nur mit Typnamen geloggt |
| `LooseEndsTests/ServiceClientTests.swift` (`FakeTransport`) | wiederverwendet, um F4-Test ergänzt |
| Security.framework | System-SDK, keine neuen Pakete |
| Upstream | 4b-2 (gemergt) |
| Downstream | 4c (Ablagewahl `forApp`, Ersatz im Speicher unter `--ui-testing`, Simulator-Beleg des echten Schlüsselbunds), #795 |

## Acceptance Criteria

Alle Tests mit Swift Testing (`import Testing`, `@testable import LooseEnds`; wie `ServiceClientTests` und `AccountStateTests`), Lauf über
`./scripts/sim.sh sim-unit KeychainSessionStoreTests` und `./scripts/sim.sh sim-unit ServiceClientTests`. Das Systemstück ersetzt ein Fake
`KeychainOperations` in der Testdatei, das jeden Aufruf (Operation, Abfrage) aufzeichnet und je Aufruf einen vorbereiteten Status liefert.
Fehlerfälle tabellengetrieben (`@Test(arguments:)`).

- **AC-1:** Abfragen: Jede der vier Abfragen (add, read, update-Suche, delete) enthält `kSecClass == kSecClassGenericPassword`, `kSecAttrService == "com.henning.looseends.session"`, das feste Konto und `kSecUseDataProtectionKeychain == true`; keine enthält `kSecAttrSynchronizable`. Die Add-Attribute tragen zusätzlich `kSecAttrAccessible == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` und `kSecValueData` mit dem Token als UTF-8; die Lese-Abfrage `kSecReturnData == true` und `kSecMatchLimitOne`; die Update-Änderungsattribute enthalten **nur** den Schlüssel `kSecValueData`. Test: „keychain: abfragen“.
- **AC-2:** Statusabbildung (tabellengetrieben): `save` mit Add-Status `errSecSuccess` ist Erfolg und löst kein Update und kein Delete aus; Add-Status `-34018` (`errSecMissingEntitlement`), `errSecInteractionNotAllowed` und ein beliebiger anderer Wert werfen `SessionStoreError.keychain(<Status>)`. Test: „keychain: statusabbildung save“.
- **AC-3:** Ablauf `save` bei Duplikat: Add liefert `errSecDuplicateItem` → genau ein Update mit der Suchabfrage `base` und den Änderungsattributen nur `kSecValueData` (neues Token); Update `errSecSuccess` ergibt Erfolg; die aufgezeichnete Folge ist genau Add, Update, ohne Delete. Test: „keychain: save duplikat wird update“.
- **AC-4:** Rennen nach Duplikat: Add `errSecDuplicateItem`, Update `errSecItemNotFound` wirft `keychain(errSecItemNotFound)`; es gibt keinen zweiten Add und kein zweites Update (genau zwei Aufrufe). Ein anderer Update-Fehler (z. B. `-34018`) wirft `keychain(<Status>)`. Test: „keychain: update ohne treffer ist fehler ohne retry“.
- **AC-5:** `load`: NotFound → `nil` (kein Fehler); Erfolg mit den Daten von `"T1"` → `"T1"`; jeder andere Status (`-34018`, `errSecInteractionNotAllowed`, beliebig) wirft `keychain(<Status>)` und liefert nie `nil`. Test: „keychain: load statusabbildung“.
- **AC-6:** `clear`: Erfolg und NotFound → kein Fehler; jeder andere Status (`-34018`, beliebig) wirft `keychain(<Status>)`; die Abfrage ist die Delete-Abfrage aus AC-1. Test: „keychain: clear statusabbildung“.
- **AC-7:** Dekodierung: Lese-Erfolg mit leeren Daten, mit `nil`-Daten und mit Daten ohne gültiges UTF-8 (z. B. `0xFF 0xFE`) wirft `SessionStoreError.corruptData`, nie `nil`, nie einen Absturz. Test: „keychain: leere und ungueltige daten“.
- **AC-8:** `-34018` bleibt Fehler: für `save`, `load` und `clear` liefert Status `-34018` jeweils `keychain(-34018)`, und `load` ergibt in keinem Fall `nil`. Test: „keychain: fehlende berechtigung ist kein nil“.
- **AC-9:** Keine Preisgabe: Der Marker `SECRET-TOKEN` als Token in `save` und als Daten in `load` taucht in `String(describing:)` keines geworfenen Fehlers auf (alle Fehlerpfade aus AC-2 bis AC-7). Test: „keychain: fehler ohne token“.
- **AC-10:** F4: `ServiceClient` mit `FakeTransport(.fail(URLError(.cancelled)))` wirft für alle drei Routen (`signIn`, `logout`, `delete`) `CancellationError` (nicht `ServiceError.unavailable`); die übrigen Codes `notConnectedToInternet`, `timedOut`, `cannotConnectToHost` bleiben `ServiceError.unavailable`, eine echte `CancellationError` aus dem Transport bleibt `CancellationError`. Test: „serviceclient: abbruch ist cancellation“ (in `ServiceClientTests.swift`); die bestehenden Tests dort bleiben grün.
- **AC-11:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `LooseEnds/Claude/KeychainSessionStore.swift`, `LooseEnds/Claude/SessionStore.swift`, `LooseEnds/Claude/ServiceClient.swift`, `LooseEndsTests/KeychainSessionStoreTests.swift`, `LooseEndsTests/ServiceClientTests.swift` und `CLAUDE.md` (kein `project.yml`, keine Entitlements, keine `Info.plist`, nichts unter `Shared/` oder `server/`, kein Aufrufer des Stores); `grep -nE 'print\(' LooseEnds/Claude/KeychainSessionStore.swift` ohne Treffer; keine Funktion über 50 Zeilen. Beleg: einmalig in `/60-validate` im Validierungsprotokoll, kein Test gegen `origin/main`.
- **AC-12:** Doku: Der Eintrag „`LooseEnds/Claude`“ in `CLAUDE.md` nennt `SessionStoring`, `KeychainSessionStore` und `AccountState` (jeweils mit „noch ohne Aufrufer“). Beleg: einmalig in `/60-validate` per `grep -n 'KeychainSessionStore' CLAUDE.md` im Validierungsprotokoll.
- **AC-13:** Regression: `./scripts/sim.sh sim-unit` (alle Unit-Tests) ist grün; `./scripts/sim.sh build` baut die App mit der neuen Datei (nach `generate`) ohne Fehler und ohne neue Warnungen aus den geänderten oder neuen Dateien. Beleg: Lauf im Validierungsprotokoll.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/KeychainSessionStore.swift` | CREATE | `KeychainOperations`, `SystemKeychain`, `KeychainQuery`, `KeychainSessionStore`, ≈ +110 |
| `LooseEnds/Claude/SessionStore.swift` | MODIFY | `SessionStoreError` um `keychain(OSStatus)`, `corruptData`, Doc-Kommentar, ≈ +4 |
| `LooseEnds/Claude/ServiceClient.swift` | MODIFY | F4: eigener `catch` für `.cancelled`, ≈ +4/−3 |
| `LooseEndsTests/KeychainSessionStoreTests.swift` | CREATE | Fake-Operationen, AC-1 bis AC-9, ≈ +100 |
| `LooseEndsTests/ServiceClientTests.swift` | MODIFY | F4-Test, ≈ +6 |
| `CLAUDE.md` | MODIFY | Doku, +2, zählt nicht als Code |

### Estimated Changes

- **Files: 5** Code/Test (plus `CLAUDE.md` als Doku; Spec und Kontext zählen nicht), innerhalb der 4 bis 5. **LoC ≈ +225/−3**, knapp unter der Grenze ±250. Wird sie beim Bau überschritten, entfällt `KeychainOperations`/`SystemKeychain` (nur reine Funktionen für Abfragen, Statusabbildung, Dekodierung); AC-2 bis AC-4 und AC-9 reduzieren sich dann auf die reinen Funktionen, und die Lücke („Ablauf von `save` ungeprüft bis 4c“) steht im Abschlussbericht. Die Entscheidung trifft `/50-implement`, nicht still.
- Keine Permissions, keine Info.plist-Änderung, keine AppStorage-Schlüssel, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, keine Entitlements, kein Audio. Seiteneffekt im Betrieb: keiner, weil nichts den Store aufruft; F4 wirkt nur auf Pfade, die ebenfalls keinen Aufrufer haben.

## Risiken

- **Echter Schlüsselbund bleibt in 4b-3 unbelegt:** Im Unit-Testhost liefert er `-34018` (Probelauf 4b-2). Belegt sind Abfragen, Statusabbildung und Ablauf gegen das Fake; ob das System die Abfragen wie erwartet annimmt, zeigt erst 4c im Simulator über die App. Das steht im Abschlussbericht.
- **Mac-CI ohne Profil:** `MacDetailClickTests` signiert die App ohne Profil neu; dort würde der Schlüsselbund `-34018` liefern. Ohne Aufrufer in 4b-3 kein Risiko; für 4c merken (Ersatz im Speicher unter `--ui-testing`).
- **`-34018` nie als `nil`:** sonst sähe die App eine fehlende Berechtigung als „abgemeldet“ (AC-8).
- **Rennen nach Duplikat:** Verschwindet der Eintrag zwischen Add und Update, meldet `save` einen Fehler und wiederholt nicht (AC-4); `AccountState` behandelt das als `signedOut` mit Log.
- **Kaputte Daten im Eintrag:** eigener Fehler `corruptData` statt `nil` oder Absturz (AC-7).
- **Umfang:** ≈ 225 LoC knapp unter der Grenze, Rückfall siehe Estimated Changes.

## Befunde gegen den Plan

- **F4 ändert Verhalten:** Bricht `URLSession` selbst ab (ohne Task-Abbruch), wird das still (`AccountState`: `.signedOut` bei der Anmeldung, `.signedIn` beim Löschen) statt „später erneut“. Mit der ephemeren Sitzung ohne `invalidateAndCancel` praktisch nicht auslösbar. Kein bestehender Test erwartet `.cancelled` als `unavailable` (per grep geprüft).
- **Race nach Duplikat** wird als Fehler gemeldet, nicht wiederholt (AC-4).
- **Echter Schlüsselbund-Beleg erst in 4c** über die App im Simulator; im Unit-Testhost gilt `-34018`.
- **Mac-CI ohne Profil** liefert `-34018`; relevant erst, wenn 4c einen Aufrufer hat.

## Test Plan

### Automated Tests (TDD RED)

RED: Alle neuen Tests schlagen zunächst fehl, weil `KeychainSessionStore`, `KeychainOperations` und `SessionStoreError.keychain`/`.corruptData` nicht existieren (Test-Ziel baut nicht); der F4-Test schlägt fehl, weil `.cancelled` heute `unavailable` ergibt. Das ist der erwartete Zustand vor `/50-implement`.
Die Gegenrichtungen bleiben Prüfungen: AC-4 (kein zweiter Versuch), AC-8 (nie `nil` bei fehlender Berechtigung), AC-3 (kein Delete).

| Testname | AC |
|---|---|
| „keychain: abfragen“ | AC-1 |
| „keychain: statusabbildung save“ | AC-2 |
| „keychain: save duplikat wird update“ | AC-3 |
| „keychain: update ohne treffer ist fehler ohne retry“ | AC-4 |
| „keychain: load statusabbildung“ | AC-5 |
| „keychain: clear statusabbildung“ | AC-6 |
| „keychain: leere und ungueltige daten“ | AC-7 |
| „keychain: fehlende berechtigung ist kein nil“ | AC-8 |
| „keychain: fehler ohne token“ | AC-9 |
| „serviceclient: abbruch ist cancellation“ | AC-10 |
| kein Test: Validierungsbeleg in `/60-validate` (`git diff --name-only`, `grep`, Funktionslängen) | AC-11, AC-12 |
| voller `./scripts/sim.sh sim-unit` und `./scripts/sim.sh build` | AC-13 |

- [ ] Test 1 (AC-1): GIVEN ein Fake, das Aufrufe aufzeichnet WHEN `save`, `load`, `clear` und ein Duplikat-`save` laufen THEN jede Abfrage trägt die Basisschlüssel samt Data-Protection-Flag, keine `kSecAttrSynchronizable`, Add mit Zugänglichkeit, Update nur mit dem Wert.
- [ ] Test 2 (AC-2 bis AC-4): GIVEN Add-/Update-Status aus einer Tabelle WHEN `save` läuft THEN Erfolg, Duplikat → genau Add, Update, sonst `keychain(status)`, kein Retry.
- [ ] Test 3 (AC-5 bis AC-8): GIVEN Lese-/Lösch-Status und Daten (leer, kein UTF-8, gültig) WHEN `load` und `clear` laufen THEN NotFound → `nil` bzw. Erfolg, `corruptData`, `-34018` bleibt Fehler.
- [ ] Test 4 (AC-9): GIVEN Marker `SECRET-TOKEN` WHEN alle Fehlerpfade durchlaufen sind THEN kein Fehlerwert enthält den Marker.
- [ ] Test 5 (AC-10): GIVEN `FakeTransport` mit `URLError(.cancelled)` und anderen Codes WHEN die drei Routen laufen THEN `CancellationError` bzw. `ServiceError.unavailable`.

**Keine UI-Tests:** Der Store hat keine Oberfläche und kein sichtbares Verhalten; nichts in der App ruft ihn auf. Ein UI-Test hätte nichts zu bedienen (wie in 4b-1 und 4b-2). Die erste Oberfläche und ihr UI-Test entstehen in 4c.

## Nicht in diesem Schnitt / Folgeschnitte

- **4c Einstellungen:** Gruppe „Konto“, `ASAuthorizationController`, Berechtigung „Mit Apple anmelden“ in `project.yml`, `LEServiceURL`/`LEAccountEnabled`, Texte de/en, Wahl der Ablage an einer Stelle (`forApp`: Schlüsselbund, unter `--ui-testing` der Ersatz im Speicher), UI-Test gegen Ersatz-Dienst, **Beleg der echten Schlüsselbund-Ablage im Simulator über die App**; Entwurf der Gruppe vor der Spec (PO-Regel 2026-09-22); Stufe 3 über TestFlight.
- **4d Freigabe nach außen:** nginx genau `/auth/apple`, `/auth/logout`, `/auth/delete`, `APPLE_CLIENT_IDS`, Datenschutztext (Konto-Teil).
- **#795:** Abschrift hochladen mit dem Sitzungstoken aus der Ablage.

## Abnahme

- Stufe 1 Tests: neue Tests vorher rot (Ziel baut nicht bzw. F4-Test rot), danach grün über `./scripts/sim.sh sim-unit KeychainSessionStoreTests` und `ServiceClientTests`, voller `./scripts/sim.sh sim-unit` grün.
- Stufe 2 Simulator: Kein sichtbarer Ablauf der App ändert sich; die App ruft den Store nicht auf (wie `OrderExecutor`). Beleg ist der Unit-Lauf im Simulator samt `./scripts/sim.sh build`, im Abschlussbericht benannt. Es gibt keinen Bedienablauf, der durchzuspielen wäre; der echte Schlüsselbund bleibt bis 4c unbelegt.
- Stufe 3 Gerät: keine. Kein Pfad der Geräteliste berührt (`LooseEnds/Claude/` steht nicht darin; kein `project.yml`, keine Entitlements, keine `Info.plist`).

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt; AC-1 bis AC-10 als dauerhafte Tests, AC-11 und AC-12 als einmalige Belege im Validierungsprotokoll von `/60-validate` (kein dauerhafter Diff- oder grep-Test), AC-13 als Lauf
- [ ] `./scripts/sim.sh sim-unit` grün, `./scripts/sim.sh build` grün, CI auf dem PR grün
- [ ] Kein Pfad der Geräteliste berührt; Abnahme endet nach Stufe 2, im Abschlussbericht mit genau diesem Satz
- [ ] Abschlussbericht benennt: echter Schlüsselbund unbelegt bis 4c; F4-Verhaltensänderung
- [ ] #615 kommentiert (Stand 4b-3: Schlüsselbund-Ablage und F4 gebaut, nichts ruft sie auf; Folge 4c), Board-Karte aktuell
- [ ] Abschlussbericht ohne Git-Vokabular: im Produkt ist nichts sichtbar, Henning muss nichts tun

## Changelog

- 2026-11-09: Initial spec created (Schnitt 4b-3, Teil-Spec)
