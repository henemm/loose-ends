# Context: feat-615-s4b-app-kern (#615 Schnitt 4b)

## Request Summary
App-Kern der Anmeldung am Dienst, noch ohne Oberfläche: Zustand der Kontozeile, Nonce, Dienst-Client für die drei
Routen `/auth/apple`, `/auth/logout`, `/auth/delete` und die Ablage des Sitzungstokens. Nichts in der App ruft den Kern
auf (wie `OrderExecutor`); Oberfläche, Berechtigung und `project.yml` kommen erst in 4c. Vorgänger 4a (Sitzungsablauf,
PR #880). Gesamtplan: `docs/context/feat-615-s4-app-anmeldung.md` (Abschnitte „Technical Approach“, 4b).

## Server-Vertrag (fertig, unverändert)
| Route | Request | Antworten |
|---|---|---|
| `POST /auth/apple` (`server/src/auth.ts:83-93`, `signIn` :64-80) | `Content-Type: application/json` (Parameter erlaubt), Body ≤ 16 KiB, Objekt mit genau den Pflichtfeldern `identityToken`, `nonce`, `code` (nicht leere Strings, `auth.ts:14`, :53-61); kein `clientId` (aud kommt aus dem Token) | 200 `{ sessionToken }` + `no-store`; 401 nackt (Token, Code, `sub` ungleich, Tür `admit` zu, Ablage); 503 (keine Konfiguration/Schlüssel, Apple unerreichbar); 400, 405, 413, 415 |
| `POST /auth/logout` (:96-102) | `Authorization: Bearer <token>` (`/^bearer ([^\s]+)$/i`, :22-26) | 204 immer mit Bearer (auch unbekannt); 401 ohne/ungültiger Bearer; 405 |
| `POST /auth/delete` (:129-140) | Bearer, kein Body nötig | 204; 401 (kein Bearer, unbekannte/abgelaufene Sitzung, parallel gelöscht); 405 |

**Nonce** (`server/src/apple.ts:68-77`): Der Body trägt den **rohen** Nonce; das Claim `nonce` im Identity-Token muss
`SHA-256(roh)` als **Hex** (klein) sein. Die App setzt also den Hex-Wert in `ASAuthorizationAppleIDRequest.nonce` und
schickt den rohen Wert an den Dienst. Sitzungen laufen seit 4a nach 90 Tagen ohne Nutzung ab → 401.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/auth.ts`, `server/src/apple.ts` | Vertrag oben, nur lesen |
| `Shared/Persistence/ModelContainerFactory.swift:16-48` | `isUITesting` (exakt `--ui-testing`), `isRunningTests`; Info-Schlüssel lesen (`resolveIdentifiers(from:)`, Rückfall auf Konstante, Fehlerlog) — Muster für `LEServiceURL` |
| `LooseEnds/Places/PlaceSearch.swift:24-63` | Protokoll `PlaceSearching: Sendable` + `static var current` + fester Ersatz unter `--ui-testing` |
| `LooseEnds/Places/CurrentLocation.swift:11-91` | `@MainActor`-Protokoll, Ersatz mit Launch-Argumenten |
| `LooseEnds/App/FieldSettingsStore.swift`, `LooseEnds/Places/SavedPlacesStore.swift` | `@MainActor @Observable final class`, Abhängigkeiten per `init`, `forApp(arguments:)`, eigene Suite unter UI-Tests |
| `LooseEndsTests/SavedPlacesStoreTests.swift` | Teststil: Swift Testing (`import Testing`, `@testable import LooseEnds`, `@Test @MainActor`), Fakes per Protokoll |
| `project.yml:35-40`, `:323-348` | App-Target nimmt `LooseEnds/` ordnerweise (neuer Ordner `LooseEnds/Claude/` ohne Eintrag); `LooseEndsTests` erreicht App-Code über Host-App und `@testable import`; Watch/Widgets/Share kompilieren `LooseEnds/` nicht |
| `project.yml:52-70` | Entitlements: `network.client: true` (Mac-Sandbox), keine Keychain-Gruppe, kein `applesignin` (kommt in 4c) |
| `docs/project/00-entscheidungen.md:308-324` | ADR-21: „bis dahin ruft die App den Dienst nirgends auf“ (:321-322) |

## Existing Patterns
- Dienst mit Protokoll, echter Umsetzung und festem Ersatz unter `--ui-testing`; Wahl an einer Stelle (`static var current`).
- Logger je Typ: `private static let logger = Logger(subsystem: "com.henning.looseends", category: "…")`, unter Swift 6 ggf. `nonisolated static let`.
- Reine Regeln als eigene Typen in `Shared/Models` bzw. pure Funktionen, getestet ohne Systemzugriff.
- Kein `try?`, das Fehler schluckt; Swift 6 strict concurrency.

## Neu (nichts davon existiert)
- Kein `URLSession`, kein `SecItem*`, kein `AuthenticationServices`, kein CryptoKit im Produktcode; keine URLProtocol-Attrappe in den Tests.
- Ordner `LooseEnds/Claude/` existiert nicht.

## Dependencies
- Upstream: Foundation (`URLSession`), Security (Keychain), CryptoKit (SHA-256), OSLog; Dienst unter `https://loose-ends.henemm.com` (`/auth/*` per nginx noch 404 bis 4d).
- Downstream: 4c (Einstellungsgruppe „Konto“, `ASAuthorizationController`, Berechtigung `applesignin`, `LEServiceURL`/`LEAccountEnabled` in `project.yml`), #795 (Abschrift hochladen mit Sitzungstoken).

## Existing Specs
- `docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md`, `-3c1-konto-loeschen.md` (Routenvertrag)
- `docs/specs/feat-615-schnitt-4a-sitzungsablauf.md` (Folgeschnitte, „401 verwirft die lokale Sitzung“)

## Risks & Considerations
- **Keychain in Tests:** Unit-Tests laufen in der iOS-Simulator-Host-App; `SecItem` kann ohne Signierung/Zugriffsgruppe mit `errSecMissingEntitlement` (-34018) scheitern. Muss vor der Spec belegt werden (Recherche + ein Probelauf), sonst Ablage hinter Protokoll, echter Keychain-Test nur dort, wo er läuft.
- **Mac-Sandbox:** Keychain-Zugriff der sandboxed Mac-App ohne `keychain-access-groups` (Standard: Team-ID.Bundle-ID); unter `--ui-testing` In-Memory-Ablage (Mac-UI-Tests in echter Sandbox, #544).
- **Kein Netzaufruf ohne Anmeldung:** Der Client darf beim Erzeugen nichts senden; ein Test hält „abgemeldet → null Anfragen“ fest. In 4b ruft niemand den Kern auf.
- **Umfang:** Zustand + Nonce + Client + Ablage + Tests ≈ 350–450 LoC → wahrscheinlich in 4b-1 (Nonce, Client gegen Attrappe) und 4b-2 (Ablage, Zustand) teilen; in der Analyse entscheiden.
- **Fehlerabbildung:** 401 → Sitzung verwerfen (abgemeldet / „nicht zugelassen“ beim Anmelden), 503/Netz → „später nochmal“; Abmelden lokal zuerst, Löschen lokal erst nach 204.
- **Dienst-Adresse:** Konstante vs. Info-Schlüssel `LEServiceURL` (der erst mit `project.yml` in 4c kommt); in 4b per `init` injiziert.

## Analysis

### Type
Feature (App-Kern ohne Oberfläche, nichts ruft ihn auf)

### Belege vor der Analyse
- **Schlüsselbund im Testlauf: geht nicht.** Probelauf 2026-11-09 (`sim.sh sim-unit` mit Wegwerftest, danach entfernt):
  `SecItemAdd` und `SecItemCopyMatching` liefern beide `-34018` (`errSecMissingEntitlement`). Recherche bestätigt das Muster:
  ohne signierten Host mit `application-identifier`/`keychain-access-groups` scheitert SecItem im Simulator-Testlauf
  (Apple-Forum thread/4743 und thread/733449, DTS-Hinweis „dummy host app with entitlements“).
  Folge: Die Ablage steht hinter einem Protokoll; Unit-Tests nutzen den Ersatz im Speicher. Die echte Keychain-Ablage
  wird in 4c im Simulator über die App selbst belegt (UI-Test: anmelden gegen Ersatz-Dienst, Neustart, weiter angemeldet),
  nicht im Unit-Test.
- **Nonce:** `request.nonce = hex(SHA-256(roh))` klein, roher Wert an den Dienst (Firebase/Identity-Platform-Doku
  „Signing in users with Apple on iOS“), deckt sich mit `server/src/apple.ts:68-77`.

### Affected Files (with changes)
| File | Change Type | Description | Schnitt |
|------|-------------|-------------|---------|
| `LooseEnds/Claude/Nonce.swift` | CREATE | roher Zufallswert (32 Byte), `hashed` = SHA-256 Hex klein (CryptoKit), `static hash(_:)` | 4b-1 |
| `LooseEnds/Claude/ServiceClient.swift` | CREATE | `HTTPTransport`-Protokoll + `URLSession`-Anbindung (ephemeral), `ServiceError` (`unauthorized`, `unavailable`, `rejected(Int)`, `invalidResponse`, ohne Token/Body), `ServiceClient(baseURL:transport:)` mit `signIn`, `logout`, `deleteAccount` | 4b-1 |
| `LooseEndsTests/ServiceClientTests.swift` | CREATE | Nonce-Testvektor (`abc` → `ba7816bf…`), Draht-Vertrag je Route (Methode, Pfad, Header, JSON genau drei Felder, Bearer), Statusabbildung, Erzeugen sendet nichts; `FakeTransport` zeichnet auf | 4b-1 |
| `LooseEnds/Claude/SessionStore.swift` | CREATE | `SessionStoring` (`load/save/clear`), `KeychainSessionStore` (generic password, `AfterFirstUnlockThisDeviceOnly`, Duplikat → Update, NotFound beim Löschen = Erfolg), `InMemorySessionStore` | 4b-2 |
| `LooseEnds/Claude/AccountState.swift` | CREATE | `@MainActor @Observable`, Status `signedOut/signingIn/signedIn/deleting/notAllowed/retryLater`, Nonce einmalig, Fehlerabbildung unten | 4b-2 |
| `LooseEndsTests/AccountStateTests.swift` | CREATE | Übergänge, Fehlerfälle, „abgemeldet → null Anfragen“, veraltete 401 löscht neue Sitzung nicht | 4b-2 |

### Scope Assessment
- 4b-1: 3 Dateien, ~200 LoC (Prod ~110, Test ~90)
- 4b-2: 3 Dateien, ~250 LoC (kann überlaufen → dann `KeychainSessionStore` als 4b-3, ~70 LoC)
- Risk Level: LOW — neuer Ordner, keine Aufrufer, kein `project.yml`, keine Gerätestufe („Kein Pfad der Geräteliste berührt.“)

### Technical Approach
HTTP per Protokoll `HTTPTransport` statt URLProtocol-Attrappe (Repo-Muster `PlaceSearching`, Swift-6-tauglich ohne
globalen Zustand, Anfragen direkt prüfbar inkl. „null Anfragen“); ungetestet bleibt nur die dreizeilige
`URLSession`-Anbindung. `AccountState` importiert kein `AuthenticationServices` (Abbruch durch den Nutzer bildet 4c auf
`cancelSignIn()` ab). Dienst-Adresse per `init`, `LEServiceURL` erst in 4c.

Fehlerabbildung (4b-2): Anmelden 200 → Token speichern, erst dann `signedIn` (Speicherfehler = nicht angemeldet);
401 → `notAllowed`, nichts gespeichert; 503/Netz → `retryLater`; 400/405/413/415 → `rejected`, geloggt. Jede 401 mit
Sitzung verwirft die lokale Sitzung, aber nur, wenn der gespeicherte Token noch der benutzte ist. Abmelden: lokal zuerst
löschen, dann Dienst best effort, Ergebnis egal; ohne Token null Anfragen. Konto löschen: lokal erst nach 204;
503/Netz → Sitzung bleibt, `retryLater`; 401 → abgemeldet. Doppelaufrufe während `signingIn`/`deleting` ignoriert.
Nonce gilt einmal: `completeSignIn` ohne `beginSignIn` → kein Request. Nie Token loggen.

### Befunde gegen den Plan
- F1: Ablauf nach 90 Tagen zeigt sich erst beim nächsten Aufruf (401); 4c darf nicht annehmen, die Zeile wisse es vorher.
- F2: Echte Keychain-Ablage ist im Unit-Test nicht belegbar (-34018, oben) → Beleg in 4c im Simulator über die App.
- F3: ADR-21-Satz „die App ruft den Dienst nirgends auf“ bleibt in 4b wahr (keine Aufrufer); Anpassung erst in 4c.

### Alternativen
- A: ein `AccountService`-Protokoll, ganze Dienstseite als Ersatz in `AccountStateTests`, ~4 Dateien in einem Schnitt.
  Verworfen: der Draht-Vertrag (Header, Body) bliebe bis zum Serverbetrieb ungetestet.
- B: URLProtocol-Attrappe statt `HTTPTransport`: prüft den echten `URLSession`-Weg, kostet globalen Zustand unter Swift 6
  und parallelem Swift Testing. Später als Ergänzung möglich.
- C: Anmeldung über den Web-Weg (`ASWebAuthenticationSession` gegen `/oauth`), siehe Gesamtplan, kippt S3-Vertrag. Nicht gewählt.
- Token in `UserDefaults`: verworfen (Sitzungstoken gehört in den Schlüsselbund).

### Dependencies
4b-1 vor 4b-2 (Typen `ServiceClient`, `ServiceError`). 4b vor 4c.

### Open Questions
- keine PO-Frage (keine sichtbare Änderung). Spec zuerst für 4b-1 (Teil-Spec), 4b-2 folgt im selben Workflow.
