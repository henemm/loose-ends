# Context: feat-615-s4b2-sitzung (#615 Schnitt 4b-2)

## Request Summary
Zweiter Teil des App-Kerns der Anmeldung, noch ohne Oberfläche: die Ablage des Sitzungstokens (`SessionStoring`, Schlüsselbund
und Ersatz im Speicher) und der Kontozustand `AccountState`, der `ServiceClient` und `Nonce` aus 4b-1 benutzt. Nichts in der App
ruft den Kern auf; Oberfläche, Berechtigung `applesignin` und `LEServiceURL` kommen in 4c. Plan und Fehlerabbildung stehen
verbindlich in `docs/context/feat-615-s4b-app-kern.md` (Abschnitte „Belege vor der Analyse“, „Technical Approach“, Zeilen 60–120).

## Ausgangslage (seit PR #884 auf main)
| Baustein | Datei | Schnittstelle |
|---|---|---|
| `Nonce` | `LooseEnds/Claude/Nonce.swift` | `init() throws` (`NonceError.randomUnavailable`), `init(raw:)`, `raw`, `hashed`, `static hash(_:)` |
| `ServiceClient` | `LooseEnds/Claude/ServiceClient.swift` | `init(baseURL:transport:)`, `signIn(identityToken:nonce:code:) -> String`, `logout(sessionToken:)`, `deleteAccount(sessionToken:)`; `HTTPTransport`; `ServiceError` (`unauthorized`, `unavailable`, `rejected(Int)`, `invalidResponse`); `CancellationError` wird durchgereicht |
| Tests | `LooseEndsTests/ServiceClientTests.swift` | `FakeTransport` (actor, zeichnet `URLRequest`s auf, Antworten je Aufruf) — Vorbild und ggf. wiederverwendbar |

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Claude/ServiceClient.swift`, `Nonce.swift` | Abhängigkeit, unverändert |
| `LooseEndsTests/ServiceClientTests.swift` | `FakeTransport` liegt dort `private`/intern; für `AccountStateTests` wiederverwenden oder eigener Fake |
| `LooseEnds/Places/SavedPlacesStore.swift`, `LooseEnds/App/FieldSettingsStore.swift` | Muster `@MainActor @Observable final class`, Abhängigkeiten per `init`, `@ObservationIgnored` für Dienste, `shared` + `forApp()` mit Ersatz unter `--ui-testing` |
| `Shared/Persistence/ModelContainerFactory.swift:16-48` | `isUITesting`, `isRunningTests` |
| `LooseEnds/App/ContentView.swift:27` | Logger-Muster `Logger(subsystem: "com.henning.looseends", category: …)` |
| `server/src/auth.ts` | Vertrag: 401 bei unbekannter/abgelaufener Sitzung (90 Tage, 4a), Abmelden 204 auch für unbekannte |
| `project.yml:52-70` | keine Keychain-Gruppe, kein `applesignin`; bleibt in 4b-2 unberührt |

## Existing Patterns
- Dienst hinter Protokoll, echter Typ plus Ersatz; Wahl an einer Stelle (`forApp`), unter `--ui-testing` immer der Ersatz.
- `@MainActor @Observable` für Zustand, den die Oberfläche später liest; Dienste `@ObservationIgnored`.
- Swift Testing, `@Test @MainActor`, Fakes per Protokoll, tabellengetrieben mit `arguments:`.
- Kein `try?`, das Fehler schluckt; `Logger` statt `print`; nie ein Token in Logs.

## Dependencies
- Upstream: `ServiceClient`, `ServiceError`, `Nonce` (4b-1); Security (`SecItemAdd/Update/CopyMatching/Delete`); OSLog.
- Downstream: 4c (Einstellungsgruppe „Konto“ liest `AccountState.status`, ruft `beginSignIn`/`completeSignIn` mit dem
  Ergebnis von `ASAuthorizationController`, belegt die echte Schlüsselbund-Ablage im Simulator über die App), #795 (Abschrift
  hochladen mit dem Sitzungstoken aus der Ablage).

## Existing Specs
- `docs/specs/feat-615-schnitt-4b1-dienst-client.md` (Vorgänger, „Nicht in diesem Schnitt“ beschreibt 4b-2)
- `docs/specs/feat-615-schnitt-4a-sitzungsablauf.md` (401 nach 90 Tagen ohne Nutzung)
- `docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md`, `-3c1-konto-loeschen.md` (Routen)

## Risks & Considerations
- **Schlüsselbund im Unit-Test nicht prüfbar** (`-34018`, Probelauf 2026-11-09, Apple-Forum thread/4743, thread/733449):
  `KeychainSessionStore` bleibt im Unit-Test ungeprüft; sein Beleg kommt in 4c im Simulator über die App. Alternative: die
  Abbildung der `OSStatus`-Werte (Duplikat → Update, NotFound beim Löschen = Erfolg) als reine Funktion herauslösen und testen.
- **Umfang:** ≈ 250 LoC für drei Dateien, an der Grenze. 4b-1 lag mit +275 schon drüber (Tests). Teilung möglich:
  4b-2 = `SessionStoring` + `InMemorySessionStore` + `AccountState` + Tests, 4b-3 = `KeychainSessionStore`.
- **Veraltete 401:** Eine 401 aus einem älteren Aufruf darf eine inzwischen neu gespeicherte Sitzung nicht löschen
  (Vergleich gespeicherter Token = benutzter Token).
- **Parallele Aufrufe:** `@MainActor` plus Status `signingIn`/`deleting` als Sperre; Doppelaufrufe werden ignoriert.
- **Abbruch (`CancellationError`)** aus dem Client: darf keinen Fehlerzustand und keine gelöschte Sitzung hinterlassen.
- **Kein Netz ohne Anmeldung:** abgemeldet → null Anfragen, auch beim Abmelden und Löschen.
- **Gerätestufe:** Kein Pfad der Geräteliste (kein `project.yml`, keine Entitlements, `LooseEnds/Claude/` steht nicht darin).

## Analysis

### Type
Feature (App-Kern ohne Oberfläche, nichts ruft ihn auf). Erkundung und strategische Bewertung stammen aus der
4b-Analyse (`docs/context/feat-615-s4b-app-kern.md`, Abschnitt „Analysis“); hier nur, was 4b-2 neu entscheidet.

### Stand vor dem Schnitt (2026-11-09)
- `origin/main` = HEAD (PR #884 gemergt), `LooseEnds/Claude/` enthält nur `Nonce.swift`, `ServiceClient.swift`.
- Offene PRs: #885 (Store-Bilder), #855 (Doku #837), #854 (Dependabot) — keiner berührt `LooseEnds/Claude/`.

### Recherche Schlüsselbund (Mac und iPhone)
- Duplikat entsteht über die Primärschlüssel-Attribute (Dienst + Konto), nicht über den Wert: `SecItemAdd` → `errSecDuplicateItem`
  (-25299) → `SecItemUpdate` mit derselben Abfrage ([Apple DTS „SecItem: Pitfalls and Best Practices“](https://developer.apple.com/forums/thread/724013)).
- macOS: ohne `kSecUseDataProtectionKeychain = true` landet das Item im dateibasierten Schlüsselbund; mit ihm immer im
  iOS-artigen ([Apple-Forum thread/678497](https://developer.apple.com/forums/thread/678497),
  [KeychainStasher.m](https://opensource.apple.com/source/Security/Security-59754.140.13/keychain/KeychainStasher/KeychainStasher.m.auto.html)).
  Folge für 4b-3: das Flag in jeder Abfrage (Hinzufügen, Lesen, Ändern, Löschen) gleich setzen.
- Testlauf: `-34018` ohne signierten Host (Probelauf 2026-11-09, [thread/759481](https://developer.apple.com/forums/thread/759481)).

### Schnitt-Entscheidung
Schätzung alles in einem: Protokoll + Speicher-Ersatz ~25, `AccountState` ~120, Schlüsselbund ~70, Tests ~140 → ~355 LoC,
klar über ±250. Daher:
- **4b-2 (dieser Schnitt):** `SessionStoring` + `InMemorySessionStore` + `AccountState` + `AccountStateTests`, ~260 LoC, 3 Dateien.
- **4b-3 (eigener Workflow im selben Issue):** `KeychainSessionStore` (generic password, Dienst `com.henning.looseends.session`,
  `AfterFirstUnlockThisDeviceOnly`, `kSecUseDataProtectionKeychain`, Duplikat → Update, NotFound beim Lesen = nil, beim
  Löschen = Erfolg) mit der `OSStatus`-Abbildung als reiner Funktion samt Test, ~90 LoC.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/SessionStore.swift` | CREATE | `protocol SessionStoring: Sendable { load() throws -> String?; save(_:) throws; clear() throws }`, `InMemorySessionStore` (für Tests, später `--ui-testing`), optional Fehler-Einspielung für Tests |
| `LooseEnds/Claude/AccountState.swift` | CREATE | `@MainActor @Observable final class`, `Status` (`signedOut`, `signingIn`, `signedIn`, `deleting`, `notAllowed`, `retryLater`), `beginSignIn() throws -> String` (gehashte Nonce für Apple), `completeSignIn(identityToken:code:)`, `cancelSignIn()`, `signOut()`, `deleteAccount()`; Logger ohne Token |
| `LooseEndsTests/AccountStateTests.swift` | CREATE | Übergänge und Fehlerabbildung tabellengetrieben, „abgemeldet → null Anfragen“, veraltete 401, Abbruch, Doppelaufruf, Speicherfehler |

### Scope Assessment
- Files: 3 (alle neu)
- Estimated LoC: +~260 / -0 (Prod ~135, Test ~125); läuft es über, wird der Testüberhang wie in 4b-1 begründet
- Risk Level: LOW — neuer Code ohne Aufrufer; „Kein Pfad der Geräteliste berührt.“

### Technical Approach
Fehlerabbildung wie in der 4b-Analyse festgelegt (verbindlich):
- Start: `init(client:store:)` liest die Ablage einmal → `signedIn` bei Token, sonst `signedOut`; Lesefehler → `signedOut`, geloggt. Kein Netz.
- `beginSignIn`: nur aus `signedOut`/`notAllowed`/`retryLater`; erzeugt neue `Nonce`, gibt `hashed` zurück, Status `signingIn`.
- `completeSignIn`: ohne offene Nonce kein Request; Nonce wird beim Aufruf verbraucht. 200 → speichern, erst dann `signedIn`
  (Speicherfehler → `signedOut`); `unauthorized` → `notAllowed`; `unavailable` → `retryLater`; `rejected`/`invalidResponse` → `signedOut`, geloggt;
  `CancellationError` → `signedOut` ohne Fehlerzustand.
- `cancelSignIn`: verwirft die Nonce, `signingIn` → `signedOut`.
- `signOut`: Token lesen, lokal löschen, Status `signedOut`, dann Dienst best effort (Ergebnis egal); ohne Token null Anfragen.
- `deleteAccount`: nur aus `signedIn`; Status `deleting`; 204 → lokal löschen, `signedOut`; `unauthorized` → lokal löschen (nur wenn
  gespeicherter Token = benutzter), `signedOut`; `unavailable` → `signedIn` bleibt, Hinweis `retryLater` als eigenes Feld
  (`lastProblem`), damit die Sitzung sichtbar bleibt; `CancellationError` → zurück auf `signedIn`.
- Doppelaufrufe während `signingIn`/`deleting` werden ignoriert (kein zweiter Request).
- Nie Token oder Nonce im Log.

Offen für die Spec: ob `retryLater` beim Löschen als Status oder als `lastProblem` neben `signedIn` steht. Empfehlung `lastProblem`
(sonst wüsste 4c nicht, dass die Sitzung noch gilt). Das ist Technik, keine PO-Frage.

### Alternativen
- **A: Schlüsselbund mit in 4b-2** (ein Schnitt, ~355 LoC) — verworfen, Grenze ±250 klar gerissen, und der Schlüsselbund ist im
  Unit-Test ohnehin nur über die reine Statusabbildung prüfbar.
- **B: Zustand als reine Zustandsmaschine (enum + `reduce`) ohne `@Observable`**, die Async-Aufrufe in 4c — prüfbarer, aber die
  Reihenfolge „erst speichern, dann angemeldet“ und die veraltete-401-Regel lägen dann in der Oberfläche. Verworfen.
- **C: Web-Anmeldung über `/oauth` statt App-Route** (siehe 4b-Analyse) — kippt den S3-Vertrag, nicht gewählt.

### Dependencies
4b-1 (gemergt) → 4b-2 → 4b-3 → 4c (Oberfläche, `applesignin`, `LEServiceURL`, Simulator-Beleg der echten Ablage) → #795.

### Open Questions
- keine PO-Frage (keine sichtbare Änderung).
