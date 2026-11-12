# Context: feat-795-s2-app-client (#795 Schnitt S2)

## Request Summary
Die App bekommt den Client für die drei App-Wege des Dienstes (`/app/transcript`, `/app/orders/claim`, `/app/orders/result`,
live seit S1/S1b): Aufrufe im `ServiceClient`, eine Gerätekennung je Installation und einen Weg, über den `AccountState` den
Aufruf mit dem gespeicherten Sitzungs-Token ausführt. Nichts in der App ruft es auf; die Auslöser kommen in S3 (`ClaudeSync`).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Claude/ServiceClient.swift` (102 Z.) | `HTTPTransport`, `ServiceError` (unauthorized, unavailable, rejected(Int), invalidResponse), `request/bearer/send`; hier kommen die drei Wege dazu und 429 als eigener Fall |
| `LooseEnds/Claude/AccountState.swift` | Hält Status und Store; liest Token über `storedToken(in:)`; Muster `dropSession(token)` bei 401 (nur löschen, wenn noch derselbe Token gespeichert) |
| `LooseEnds/Claude/SessionStore.swift` | `SessionStoring`, `InMemorySessionStore` mit Fehler-Einspielung |
| `LooseEnds/Claude/AccountWiring.swift` | `forApp`, `UITestTransport` (beantwortet nur `auth/*`; neue Wege werden in S2 nicht aufgerufen) |
| `Shared/Services/OrderExecutor.swift` | `Order`, `OrderResult` (Codable) |
| `Shared/Services/TranscriptCodec.swift` | `Transcript` (Codable), `TranscriptCodec.encode/decode` (sortierte Schlüssel, ISO 8601 ganze Sekunden) |
| `LooseEndsTests/ServiceClientTests.swift` (145 Z.) | `FakeTransport` (actor, Antworten und Fehler einspielen), Swift Testing |
| `LooseEndsTests/AccountStateTests.swift` (308 Z.) | Muster für Zustandstests |
| `docs/reference/claude-abschrift-vertrag.md` § „Wege der App“ | Vertrag: Methode POST, Bearer, `X-Device` (UUID), Codes 204/200/204/409/400/401/413/415/429, Abbruchregel bei 429 |
| `server/src/app-routes.ts` | Gegenstelle |

## Existing Patterns
- Ein Aufruf = eine Methode am `ServiceClient`, Erfolgsstatus je Weg, alles andere über `send(_:success:)` abgebildet;
  ein abgebrochener `URLError` wird `CancellationError`, jeder andere `URLError` `unavailable`.
- Fehler tragen nie Token, Körper oder URL. Logzeilen nennen nur den Fallnamen.
- Kodierung ausschließlich über `TranscriptCodec.encode/decode` (eine Kodierung, gleiche Datumsform wie der Vertrag).
- `AccountState` ist `@MainActor @Observable`; ein 401 räumt die Sitzung nur, wenn noch derselbe Token gespeichert ist.
- Persistente Kleinwerte der App: `UserDefaults` (z. B. `FieldSettingsStore`, `SavedPlacesStore`), Token in der Keychain (`KeychainSessionStore`, „this device only“).

## Dependencies
- Upstream: `Foundation`/`URLSession`, `TranscriptCodec`, `Order`/`OrderResult`, `SessionStoring`.
- Downstream: S3 `ClaudeSync` (Senden/Holen/Ausführen), S5 Weckruf. Heute niemand.

## Existing Specs
- `docs/specs/feat-795-schnitt-1-dienst-wege.md` (Folgeschnitte: „S2 App-Client: `ServiceClient.putTranscript/claimOrder/putResult`,
  Gerätekennung je Installation, `AccountState` gibt Aufruf mit Token“)
- `docs/specs/feat-795-schnitt-1b-nginx.md` (429-Regel)

## Risks & Considerations
- **Gerätekennung „je Installation“:** `UserDefaults` überlebt kein Löschen der App (gewollt), wird aber per iCloud-Backup auf ein
  neues Gerät mitgenommen → zwei Geräte gleicher Kennung möglich (Folge: beide dürfen einen Auftrag melden, den eines holte; durch
  den erwarteten Stand harmlos, aber gegen „nur ein Gerät“). Keychain mit `ThisDeviceOnly` wandert nicht ins Backup auf andere
  Geräte, überlebt aber Neuinstallation. `identifierForVendor` gibt es auf dem Mac nicht. → in der Analyse entscheiden.
- **429** muss ein eigener Fehler sein (Vertrag: Durchgang sofort abbrechen); heute wäre es `rejected(429)`.
- **401 auf einem App-Weg** heißt: Sitzung beim Dienst unbekannt (abgelaufen nach 90 Tagen ohne Nutzung, gelöscht). `AccountState`
  sollte dann wie bei `deleteAccount` die Sitzung räumen, sonst fragt jedes Gerät ewig mit totem Token.
- **Ohne Konto kein Netzverkehr** (DoD #795): der Weg über `AccountState` darf ohne gespeicherten Token nichts senden.
- 200 bei `claim` mit Auftrag, der nicht dekodiert → `invalidResponse`; Folge (Ergebnis `invalid` melden?) ist S3-Sache, aber
  ohne `id` kann kein Ergebnis gemeldet werden.
- Keine Pfade der Geräteliste berührt (`LooseEnds/Claude/` steht nicht darin) → Abnahme endet nach Stufe 2.

## Analysis

### Type
Feature (Infrastruktur ohne sichtbare Änderung; kein Entwurf nötig, nichts Sichtbares)

### Befunde
- **Kodierung passt:** `Order`/`OrderResult` (Swift) und `server/src/orders.ts` haben dieselben Schlüssel (`id`, `kind`, `orderID`,
  `outcome`, `reason`, `taskID`). Der Dienst nimmt Zeitpunkte mit Bruchsekunden und Versatz an (`transcripts.ts` `iso`); nachgestellt
  im Skript mit `JSONDecoder.iso8601` auf macOS 27: `…Z`, `…+02:00` und `….123Z` dekodieren alle (Bruchteil wird abgeschnitten). Keine Lücke.
- **Giftauftrag:** Ein Auftrag, den die App nicht dekodiert (z. B. neue `kind` aus einer späteren Dienstversion, alte App), wäre heute
  nur `invalidResponse` ohne `id` → kein Ergebnis meldbar → der Dienst holt ihn alle 10 min zurück, ewig. Der Client muss aus einem
  sonst unlesbaren Körper das `id` retten, damit S3 `rejected/invalid` melden kann.
- **429** ist heute `rejected(429)`; der Vertrag verlangt Abbruch des Durchgangs → eigener Fall `ServiceError.tooManyRequests`.
- **401 auf App-Wegen** = Sitzung beim Dienst unbekannt → Sitzung räumen wie `dropSession` (nur wenn noch derselbe Token).
- **Gerätekennung:** Recherche (Apple-Foren 802526, 106493, 738597; DEPT „Securely Storing Data on iOS“): Schlüsselbund-Einträge
  überleben das Löschen der App; `…ThisDeviceOnly` wandert bei Wiederherstellung auf ein *anderes* Gerät nicht mit. `UserDefaults`
  wandert per Backup mit → neues iPhone aus Backup trüge dieselbe Kennung wie das alte → beide bekämen über Regel (d) denselben Auftrag
  → `capture` doppelt (der einzige ungeschützte Auftrag). `identifierForVendor` gibt es auf dem Mac nicht.

### Empfehlung (eine)
Gerätekennung im Schlüsselbund, `AfterFirstUnlockThisDeviceOnly`, Data-Protection-Keychain (wie das Sitzungs-Token, gleiche
`KeychainOperations`), einmal erzeugt, danach nur gelesen. Ein Lesefehler ist ein Fehler (nie still eine neue Kennung erzeugen,
sonst holt das Gerät zurückgeholte Aufträge als „fremdes“ Gerät).

### Alternativen
- `UserDefaults`-UUID: einfacher (keine Keychain-Fehlerfälle), aber Backup-Doppelkennung → doppelte Erfassung. Verworfen.
- Kennung vom Dienst vergeben (Antwort auf `claim`): ändert den Vertrag aus S1 (`X-Device` vom Gerät) und braucht trotzdem lokale
  Ablage. Verworfen; keine ADR betroffen. Die Schlüsselbund-Wahl folgt ADR-21 (Geheimnisse/Gerätezustand nie in `UserDefaults`).

### Affected Files (with changes) — in zwei Schnitten (Limit 4–5 Dateien / ±250 LoC)
**S2a (dieser Workflow): Wege im Client**
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/ServiceClient.swift` | MODIFY | `putTranscript(_:sessionToken:)` (204), `claimOrder(sessionToken:device:)` → `Claim` (`.none` bei 204, `.order(Order)`, `.unreadable(UUID)` wenn nur `id` lesbar; sonst `invalidResponse`), `putResult(_:sessionToken:device:)` (204; 409 → `ServiceError.refused`), `X-Device` klein geschrieben, `Content-Type: application/json`, Kodierung nur über `TranscriptCodec`; 429 → `tooManyRequests` in `send` |
| `LooseEndsTests/ServiceClientTests.swift` | MODIFY | Pfad, Methode, Kopfzeilen, Körper je Weg; 204/200/409/429/401/503/413; Giftauftrag; abgebrochener `URLError` |

**S2b (Folgeworkflow): Gerät und Zugang**
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/DeviceIdentity.swift` | CREATE | Kennung im Schlüsselbund (eigener `service`), erzeugen-falls-fehlt, Fehler werfen |
| `LooseEnds/Claude/AccountState.swift` | MODIFY | `withSession { client, token in … }`: ohne Token nichts senden (`nil`), 401 → Sitzung räumen (gleicher Token), sonst Fehler durchreichen |
| `LooseEndsTests/DeviceIdentityTests.swift` | CREATE | erste Erzeugung, stabil beim zweiten Lesen, Lesefehler ≠ neue Kennung |
| `LooseEndsTests/AccountStateTests.swift` | MODIFY | kein Aufruf ohne Konto, 401 räumt nur denselben Token |

### Scope Assessment
- S2a: 2 Dateien, ca. +170 LoC (≈ 60 Code, 110 Tests). S2b: 4 Dateien, ca. +200 LoC.
- Risk Level: LOW — nichts in der App ruft die neuen Wege auf (Auslöser erst S3); kein Pfad der Geräteliste (`LooseEnds/Claude/`)
  → Abnahme endet nach Stufe 2; sichtbar ändert sich nichts, der Nachweis läuft über Unit-Tests (Stufe-2-Beleg: App startet unverändert).

### Dependencies
- Upstream: `TranscriptCodec`, `Order`/`OrderResult`, `HTTPTransport`, `KeychainOperations`, `SessionStoring`.
- Downstream: S3 `ClaudeSync` (Durchgang: senden, holen, `OrderExecutor`, melden; bei `tooManyRequests` Abbruch), S5 Weckruf.

### Open Questions
- keine an den PO (rein technisch, nichts Sichtbares).
