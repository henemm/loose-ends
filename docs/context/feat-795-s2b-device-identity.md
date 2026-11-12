# Context: feat-795-s2b-device-identity

## Request Summary
#795 Schnitt S2b: die App bekommt eine feste Kennung je Installation (`DeviceIdentity`, Schlüsselbund) für den Kopf
`X-Device`, und `AccountState` bekommt den einzigen Zugang zu den App-Wegen (`withSession`): ohne Sitzung kein Aufruf,
ein 401 räumt die Sitzung nur, wenn noch derselbe Token gespeichert ist. Vorgezeichnet in
`docs/specs/feat-795-schnitt-2a-app-client.md` (Out of Scope, Alternative E). Noch kein Aufrufer (der kommt mit S3 `ClaudeSync`).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Claude/KeychainSessionStore.swift` | `KeychainOperations` (Ersatz in Tests), `SystemKeychain`, `KeychainQuery` (Session-Eintrag, `AfterFirstUnlockThisDeviceOnly`, `kSecUseDataProtectionKeychain`, Statusabbildung: alles außer Erfolg ist Fehler, -34018 nie „nichts da“) — Vorbild und wiederverwendbar |
| `LooseEnds/Claude/SessionStore.swift` | `SessionStoring`, `SessionStoreError`, `InMemorySessionStore` (Muster für einen In-Memory-Ersatz mit eingespielten Fehlern) |
| `LooseEnds/Claude/AccountState.swift` | Status `signedIn` usw., privater `client` und `store`; `dropSession(token)` räumt nur bei gleichem Token (heute nur für `deleteAccount`, Logzeile „delete: …“) — wird zu `withSession` verallgemeinert |
| `LooseEnds/Claude/ServiceClient.swift` | `putTranscript(_:sessionToken:)`, `claimOrder(sessionToken:device:)`, `putResult(_:sessionToken:device:)`; `ServiceError.unauthorized/unavailable/rejected/invalidResponse/tooManyRequests/refused` |
| `LooseEnds/Claude/AccountWiring.swift` | baut `AccountState` (Keychain-Store, unter `--ui-testing` In-Memory); bleibt in S2b unverändert |
| `LooseEndsTests/KeychainSessionStoreTests.swift` | `FakeKeychain` (Statusfolge, Aufrufprotokoll) — Muster für `DeviceIdentityTests` |
| `LooseEndsTests/AccountStateTests.swift` | `Wire`-Transport mit Antwortfolge und Hook — wird um `withSession` erweitert |
| `docs/reference/claude-abschrift-vertrag.md` (Z. 166–196) | `X-Device` = UUID der Installation, Dienst führt sie klein; Vergabe je Gerät, 409 bei fremdem Gerät, Rückholen nach 10 min |

## Existing Patterns
- Schlüsselbund nur über `KeychainOperations`; Tests spielen Statusfolgen ein, der echte Schlüsselbund antwortet im Test-Host -34018.
- Fehlerfälle als eigene `Equatable`-Enums ohne Geheimnis; Logzeilen nennen nur Fallnamen.
- `AccountState` ist `@MainActor @Observable`; Token wird bei jedem Gebrauch frisch aus dem Store gelesen.

## Dependencies
- Upstream: Security (`SecItem*`), `ServiceClient`, `SessionStoring`.
- Downstream: S3 `ClaudeSync` (ruft `withSession` und `DeviceIdentity` auf), S5 Weckruf (läuft im Hintergrund → `AfterFirstUnlock` nötig).

## Existing Specs
- `docs/specs/feat-795-schnitt-2a-app-client.md` — S2b-Abgrenzung, Wahl Schlüsselbund statt `UserDefaults`.
- `docs/specs/feat-615-*` (S4b-2/S4b-3) — `AccountState`, `KeychainSessionStore`.

## Recherche (2026-11-12)
- Schlüsselbund-Einträge überleben Löschen und Neuinstallation der App in der Praxis (Apple-Forum, iOS 10.3-Beta-Autolöschung kam nicht in Release; kein API-Versprechen): https://developer.apple.com/forums/thread/72271
- `identifierForVendor` kann sich bei Neuinstallation ändern; üblich ist eine eigene UUID im nicht synchronisierten Schlüsselbund: https://developer.apple.com/forums/thread/109900
- `…ThisDeviceOnly` wandert nicht auf ein neues Gerät (Allgemeinwissen, in der Suche nicht belegt) → neues Gerät = neue Kennung, gewollt.

## Risks & Considerations
- Gleichzeitiges erstes Erzeugen (zwei Aufrufer): zweites `add` → `errSecDuplicateItem` → erneut lesen, gespeicherte Kennung gewinnt; nie überschreiben.
- Lesefehler (-34018, gesperrt) darf nie still eine neue Kennung erzeugen (sonst 409 für gehaltene Aufträge, Doppelvergabe).
- Kaputter Eintrag (keine UUID): Fehler, keine stille Neuerzeugung (Entscheidung in der Analyse).
- `withSession` nur aus `signedIn`; 401 während Anmeldung eines neuen Tokens darf die neue Sitzung nicht räumen.
- Dateigrenze: `DeviceIdentity.swift` (neu), `AccountState.swift`, `DeviceIdentityTests.swift` (neu), `AccountStateTests.swift` = 4 Dateien; `KeychainSessionStore.swift` möglichst nicht anfassen.
- Kein Pfad der Geräteliste (`LooseEnds/Claude/` steht nicht darin).

## Analysis

### Type
Feature (reiner App-Kern ohne Oberfläche; kein Aufrufer bis S3)

### Grundlage
Die Ablage-Entscheidung ist in `docs/context/feat-795-s2-app-client.md` („Analysis“, Empfehlung + Alternativen) und in
`docs/specs/feat-795-schnitt-2a-app-client.md` (Alternative E, Out of Scope S2b) gefallen: Schlüsselbund,
`AfterFirstUnlockThisDeviceOnly`, Data-Protection-Keychain. Diese Analyse legt nur noch die Einzelheiten fest.
Offene PRs (#908, #903, #855, #854) berühren keine der vier Dateien.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/DeviceIdentity.swift` | CREATE | `struct DeviceIdentity: Sendable` über `KeychainOperations`; `func current() throws -> UUID`; eigener Eintrag (`service` `com.henning.looseends.device`, `account` `device`, Wert = `uuidString` als UTF-8); eigenes Fehler-Enum `DeviceIdentityError { keychain(OSStatus), corruptData }` |
| `LooseEnds/Claude/AccountState.swift` | MODIFY | `withSession(_:)`; `dropSession` verallgemeinert (Logzeile mit Anlass statt fest „delete“) |
| `LooseEndsTests/DeviceIdentityTests.swift` | CREATE | mit `FakeKeychain` aus `KeychainSessionStoreTests.swift` (dort `internal`, wiederverwendbar) |
| `LooseEndsTests/AccountStateTests.swift` | MODIFY | `withSession`-Fälle mit dem vorhandenen `Wire`-Transport |

`KeychainSessionStore.swift`, `ServiceClient.swift`, `AccountWiring.swift`: unverändert.

### Festlegungen (technisch, von Claude entschieden)
**DeviceIdentity.current()**
1. `copyMatching` → Erfolg: Daten als UUID lesen; keine UUID → `corruptData` (Fehler, kein stilles Ersetzen).
2. `errSecItemNotFound` → neue `UUID()`, `add` mit `AfterFirstUnlockThisDeviceOnly`; Erfolg → zurückgeben.
3. `add` → `errSecDuplicateItem` (zweiter Aufrufer war schneller) → genau einmal neu lesen, die gespeicherte gewinnt; nie `update`.
4. Jeder andere Status (auch -34018, `errSecInteractionNotAllowed` vor dem ersten Entsperren) → `keychain(status)`; nie eine neue Kennung.
5. Kein Zwischenspeicher im Speicher (zustandslos wie `KeychainSessionStore`; S3 liest einmal je Durchgang).

**AccountState.withSession**
`func withSession<T: Sendable>(_ call: (ServiceClient, String) async throws -> T) async throws -> T?`
1. Nur aus `signedIn`; sonst `nil`, nichts gesendet. Token frisch aus dem Store; kein Token oder Lesefehler → `nil`.
2. Andere Fehler als 401 gehen unverändert an den Aufrufer (`tooManyRequests`, `refused`, `unavailable`, `CancellationError` …); Status bleibt.
3. `ServiceError.unauthorized` → Store nur leeren, wenn er noch genau diesen Token hält; Status nur dann auf `signedOut`, wenn er
   noch `signedIn` ist (eine laufende Anmeldung oder Löschung wird nie überschrieben); danach wird `unauthorized` weitergeworfen,
   damit S3 den Durchgang beendet.
4. `lastProblem` bleibt unberührt (S2b hat keine Oberfläche).

### Scope Assessment
- Files: 4 (2 neu, 2 geändert)
- Estimated LoC: ca. +230 (≈ 55 `DeviceIdentity`, ≈ 30 `AccountState`, ≈ 145 Tests) / −5
- Risk Level: LOW — nichts ruft es auf; kein Pfad der Geräteliste (`LooseEnds/Claude/`) → Abnahme endet nach Stufe 2
  („Kein Pfad der Geräteliste berührt.“); Stufe-2-Beleg: App startet unverändert, Kontogruppe unter `--ui-testing` wie bisher.

### Technical Approach
Wie oben. Tests zuerst: `DeviceIdentityTests` (erste Erzeugung schreibt genau einmal mit `ThisDeviceOnly`; zweites Lesen gleich;
Lesefehler -34018/-25308 wirft und ruft nie `add`; Duplikat → gespeicherte Kennung; kaputter Wert wirft; `add`-Fehler wirft),
`AccountStateTests` (abgemeldet → kein Request, `nil`; angemeldet → Token erreicht Closure; 401 mit gleichem Token → Store leer,
`signedOut`, Fehler geworfen; 401 nachdem ein neuer Token gespeichert wurde → neuer bleibt, `signedIn`; 429 → Sitzung bleibt).

### Alternativen (bewusst nicht gewählt)
- **Kaputten Eintrag selbst heilen** (ersetzen statt Fehler): heilt einen Zustand, den nur ein eigener Fehler erzeugen kann; ein
  Dekodierfehler im eigenen Code würde dann bei jedem Durchgang eine neue Kennung erzeugen → 409 für jeden gehaltenen Auftrag.
  Verworfen; Folge als Known Limitation: ein kaputter Eintrag blockiert den Abgleich dieses Geräts, bis S3/S5 einen Weg zeigt.
- **Zugang als eigener Typ `SessionAccess`** neben `AccountState`: der 401 muss den sichtbaren Status ändern → zweite Wahrheit
  über die Sitzung. Verworfen.
- **`UserDefaults`-UUID / Kennung vom Dienst**: siehe S2-Analyse; verworfen (Backup-Doppelkennung, Vertragsänderung). Keine ADR fällt;
  ADR-21 trägt die Schlüsselbund-Wahl.

### Open Questions
- keine (keine Produktentscheidung; nichts Sichtbares)
