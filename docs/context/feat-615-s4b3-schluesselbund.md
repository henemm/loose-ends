# Context: feat-615-s4b3-schluesselbund

## Request Summary
#615 Schnitt 4b-3: Das Sitzungstoken des Dienstes für Claude bekommt seine echte Ablage im Schlüsselbund
(`KeychainSessionStore` hinter dem Protokoll `SessionStoring` aus 4b-2). Dazu F4 aus dem Prüfdialog von 4b-2:
`ServiceClient.send` reicht `URLError(.cancelled)` als `CancellationError` weiter statt `unavailable`. Ohne Aufrufer,
keine Oberfläche; die Wahl der Ablage (`forApp`, Ersatz unter `--ui-testing`) und ihr Simulator-Beleg kommen in 4c.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Claude/SessionStore.swift` | `SessionStoring` (load/save/clear), `SessionStoreError`, `InMemorySessionStore`; Doc-Kommentar verweist auf 4b-3 |
| `LooseEnds/Claude/ServiceClient.swift` | `send(_:success:)`: `catch is URLError` → `unavailable`; hier kommt `.cancelled` → `CancellationError` |
| `LooseEnds/Claude/AccountState.swift` | Verbraucher: `signInStatus(after:)` bildet `CancellationError` → `.signedOut`, `ServiceError.unavailable` → `.retryLater`; Ablage-Fehler werden geloggt (nur Typname) |
| `LooseEndsTests/ServiceClientTests.swift` | `FakeTransport(.fail(URLError(code)))`, Schleife über Codes Zeile ~119 → Muster für den Cancel-Test |
| `LooseEndsTests/AccountStateTests.swift` | Zustand gegen den Ersatz im Speicher |
| `docs/specs/feat-615-schnitt-4b2-sitzung.md` | Zeilen 137/138/187: Vorgaben für 4b-3 (generic password, Dienst `com.henning.looseends.session`, `AfterFirstUnlockThisDeviceOnly`, `kSecUseDataProtectionKeychain` in jeder Abfrage, Duplikat → Update, NotFound beim Lesen = nil, beim Löschen = Erfolg, OSStatus-Abbildung als reine Funktion) |
| `CLAUDE.md` (Where things live, `LooseEnds/Claude`) | Eintrag nennt bisher nur `Nonce`, `ServiceClient`; um Ablage und Zustand ergänzen |
| `project.yml` (`LooseEnds.entitlements`) | Mac: App Sandbox, iCloud/CloudKit, App-Gruppe — kein `keychain-access-groups`; wird **nicht** geändert |

## Existing Patterns
- Reine Bausteine mit injizierbarer Grenze (`HTTPTransport`, `SessionStoring`) — das echte Systemstück dünn, die Logik als reine Funktion testbar.
- Fehlerwerte tragen nie Token/Body/URL (`ServiceError`, `SessionStoreError`); Logs nur Typnamen.
- Kein `try?`, `Logger` statt `print`, Swift 6 strict concurrency (`Sendable`-Protokoll).
- Keine bestehende Schlüsselbund-Nutzung im Repo (`SecItem*` nirgends) — erster Einsatz.

## Dependencies
- Upstream: Security.framework (`SecItemAdd`/`CopyMatching`/`Update`/`Delete`), `SessionStoring`.
- Downstream: 4c (`AccountState` mit echter Ablage in der App, Simulator-Beleg), #795.

## Recherche (2026-11-09)
- Duplikat: `SecItemAdd` liefert `errSecDuplicateItem`, Muster ist dann `SecItemUpdate` mit nur dem Wert; kein Löschen-dann-Anlegen (Race, verliert Metadaten). Schlüssel eines generic password: Dienst + Konto (+ Zugriffsgruppe, synchronizable). Quellen: [Apple kSecClassGenericPassword](https://developer.apple.com/documentation/security/ksecclassgenericpassword), [Apple Forum 86961](https://developer.apple.com/forums/thread/86961).
- `-34018` (`errSecMissingEntitlement`): Data-Protection-Schlüsselbund braucht `application-identifier` oder `keychain-access-groups`; im Sandbox-Mac ohne beides „client has neither application-identifier nor keychain-access-groups entitlements“. Unser Mac-Bau hat über iCloud/CloudKit ein Profil und damit `application-identifier`. Quellen: [Forum 114456 Troubleshooting -34018](https://developer.apple.com/forums/thread/114456), [Forum 733449](https://developer.apple.com/forums/thread/733449), [Forum 759481](https://developer.apple.com/forums/thread/759481).
- `kSecUseDataProtectionKeychain` (oder `kSecAttrSynchronizable`) wählt auf macOS den Data-Protection-Speicher, sonst den veralteten Datei-Schlüsselbund; auf iOS wirkungslos/Standard. Quelle: [Forum 130264](https://developer.apple.com/forums/thread/130264).

## Risks & Considerations
- **Nicht im Unit-Test belegbar:** Probelauf 4b-2 ergab `-34018` im Testhost. Prüfbar sind nur die reinen Teile: Abfrage-Wörterbücher (Klasse, Dienst, Konto, Zugänglichkeit, Data-Protection-Flag in jeder Abfrage, kein `kSecAttrSynchronizable`) und die `OSStatus`-Abbildung. Echter Beleg in 4c über die App im Simulator.
- **Mac-CI:** `MacDetailClickTests` signiert ohne Profil neu → dort würde der Schlüsselbund `-34018` liefern. Ohne Aufrufer in 4b-3 kein Risiko; für 4c merken (Ersatz unter `--ui-testing`).
- **`-34018` muss ein Fehler bleiben, kein `nil`:** sonst sähe die App eine fehlende Berechtigung als „abgemeldet“.
- **Leere/ungültige Daten beim Lesen** (kein UTF-8): eigener Fehler statt `nil` oder Absturz.
- **F4:** `.cancelled` ist auch die Antwort, wenn `URLSession` selbst abbricht; `AccountState` behandelt `CancellationError` als stilles `.signedOut` — gewollt (Task-Abbruch = Nutzer hat abgebrochen).
- Kein Pfad der Geräteliste berührt (`LooseEnds/Claude/` steht nicht darin), keine Entitlements-Änderung.

## Analysis

### Type
Feature (Schnitt 4b-3 von #615, ohne Aufrufer, ohne Oberfläche)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/KeychainSessionStore.swift` | CREATE | `KeychainSessionStore: SessionStoring` über ein schlankes Protokoll `KeychainOperations` (add/copy/update/delete, echte Hülle um `SecItem*`); reine Teile: `KeychainQuery` (base/read/add/update, `kSecUseDataProtectionKeychain` in `base`, kein synchronizable), Statusabbildung je Operation, `decode(Data?)` (leer/kein UTF-8 → `corruptData`), ≈ +110 |
| `LooseEnds/Claude/SessionStore.swift` | MODIFY | `SessionStoreError` um `keychain(OSStatus)` und `corruptData`; Doc-Kommentar „follows in S4b-3“ angepasst, ≈ +4 |
| `LooseEnds/Claude/ServiceClient.swift` | MODIFY | F4: `URLError(.cancelled)` → `CancellationError` vor dem allgemeinen `URLError`-Fang, Kommentar angepasst, ≈ +4 |
| `LooseEndsTests/KeychainSessionStoreTests.swift` | CREATE | Abfragen, Statustabelle, Ablauf von `save` (Add → Duplikat → Update), `load`/`clear` gegen Fake-Operationen, Daten ohne UTF-8, kein Token in Fehlern, ≈ +100 |
| `LooseEndsTests/ServiceClientTests.swift` | MODIFY | F4-Test: `.cancelled` → `CancellationError`, übrige Codes bleiben `unavailable`, ≈ +6 |
| `CLAUDE.md` | MODIFY | Eintrag `LooseEnds/Claude` um Ablage, Schlüsselbund und Zustand ergänzt (Doku, zählt nicht als Code), +2 |

### Scope Assessment
- Files: 5 Code/Test + CLAUDE.md
- Estimated LoC: ≈ +225/−3 (Grenze ±250 knapp gehalten)
- Risk Level: LOW — kein Aufrufer, kein Pfad der Geräteliste, keine Entitlements

### Technical Approach
Entscheidung (Tech Lead): Variante C — das Systemstück hinter `KeychainOperations` (Muster wie `HTTPTransport`), damit nicht nur Abfragen und Statusabbildung, sondern auch der Ablauf von `save` (Add, bei `errSecDuplicateItem` Update nur mit `kSecValueData`), `load` (NotFound = nil) und `clear` (NotFound = Erfolg) im Unit-Test belegt sind. Jeder andere Status, auch `-34018`, wird `SessionStoreError.keychain(status)` (nie nil, nie Token). Treibt C den Schnitt über ±250 LoC, fällt C weg und die Lücke (Ablauf von `save` ungeprüft) steht im Abschlussbericht. F4 als eigener `catch` vor dem allgemeinen `URLError`. Reihenfolge: Tests rot → Fehlerfälle → F4 → Store → CLAUDE.md → `sim-unit` + `build`.

### Alternativen
- A) Echter Schlüsselbund-Test über die App im Simulator: einziger Beleg des echten Systems; gehört nach 4c (App-Host, Ablagewahl `forApp`), wie in der 4b-2-Spec geplant.
- B) Ablage als Datei mit Data Protection statt Schlüsselbund: Token im Klartext auf der Platte, widerspricht Spec 4b-2 — verworfen.
- Ohne C (nur reine Funktionen): kleiner, aber der Ablauf von `save` bliebe bis 4c unbelegt — Rückfall nur bei LoC-Überschreitung.

### Befunde gegen den Plan
- Der echte Schlüsselbund bleibt in 4b-3 unbelegt (`-34018` im Testhost); Beleg in 4c. Steht im Abschlussbericht.
- F4 ändert Verhalten: ein Abbruch durch `URLSession` ohne Task-Abbruch wird still (`.signedOut` bzw. `.signedIn` beim Löschen) statt „später erneut“. Mit der ephemeren Sitzung ohne `invalidateAndCancel` praktisch nicht auslösbar; im Spec-Kommentar festgehalten. Kein bestehender Test erwartet `.cancelled` als `unavailable` (geprüft per grep).
- Race nach Duplikat (Update findet nichts) wird als Fehler gemeldet, nicht wiederholt.
- Mac-CI ohne Profil liefert `-34018` — erst relevant, wenn 4c einen Aufrufer hat (Ersatz unter `--ui-testing`).

### Dependencies
Security.framework; `SessionStoring` (4b-2); Verbraucher `AccountState` unverändert. Downstream 4c, #795.

### Open Questions
- keine (rein technisch, kein PO-Thema)
