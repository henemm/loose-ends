---
entity_id: feat-615-schnitt-4b1-dienst-client
type: feature
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: feat-615-s4b-app-kern
---

# Spec: App-Kern Anmeldung, Schnitt 4b-1: Nonce und Dienst-Client (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Teil-Spec für Schnitt 4b-1; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s4b-app-kern.md` (Abschnitt „Analysis“ ist verbindlich), Gesamtplan `docs/context/feat-615-s4-app-anmeldung.md`.
Vorgänger: Schnitt 4a (`docs/specs/feat-615-schnitt-4a-sitzungsablauf.md`, PR #880), Routenvertrag aus 3b
(`docs/specs/feat-615-schnitt-3b-anmelden-abmelden.md`) und 3c-1 (`docs/specs/feat-615-schnitt-3c1-konto-loeschen.md`).
Diese Spec deckt nur 4b-1 ab. 4b-2 (Ablage, Zustand) bekommt im selben Workflow später eine eigene Teil-Spec.

## Für den PO

Dieser Schritt baut im Inneren der App die beiden Bausteine, mit denen sie später mit dem Dienst für Claude sprechen kann:
einen Zufallswert, der die Anmeldung mit Apple gegen Nachahmer absichert, und den Teil, der dem Dienst die drei Anfragen
„anmelden“, „abmelden“ und „Konto löschen“ schickt. Du siehst davon nichts: Die App ruft diese Bausteine noch nirgends auf
und sendet nichts ins Netz. Es ist der erste von zwei kleinen Schritten für den Kern der Anmeldung; die Oberfläche in den
Einstellungen folgt danach.

## Purpose

Zwei neue, reine Kernbausteine in `LooseEnds/Claude/`, die der Server-Vertrag aus `server/src/auth.ts` und `server/src/apple.ts` verlangt:
`Nonce` (roher Zufallswert und sein SHA-256) und `ServiceClient` (die drei Routen `/auth/apple`, `/auth/logout`, `/auth/delete` über ein
austauschbares `HTTPTransport`). Nichts in der App ruft sie auf (wie `OrderExecutor`). **Regeln vor Modell:** Protokoll- und Betriebsarbeit,
keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Server-Vertrag (nur gelesen, unverändert):

- `POST /auth/apple`: `Content-Type: application/json`, Body ≤ 16 KiB, ein Objekt mit den drei nicht leeren Strings `identityToken`, `nonce`, `code`
  (`auth.ts` `parseLogin`). Antwort 200 `{ sessionToken }`; 401 nackt; 503 (keine Konfiguration, Schlüssel oder Apple nicht erreichbar); 400/405/413/415.
- **Nonce** (`apple.ts` `claimsReason`): Der Body trägt den **rohen** Wert als String; geprüft wird `SHA-256(UTF-8-Bytes des Strings)` als **Hex in Kleinbuchstaben**
  gegen das Claim `nonce` im Identity-Token. Die App setzt also `hashed` in die Apple-Anfrage (4c) und schickt `raw` an den Dienst.
- `POST /auth/logout`: Bearer; 204 mit jedem Bearer (auch unbekannt), 401 ohne Bearer. `POST /auth/delete`: Bearer, kein Body; 204, 401 bei fehlendem, unbekanntem, abgelaufenem Token (seit 4a nach 90 Tagen ohne Nutzung).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue — Ausgestaltung von ADR-21 (Weg B: Dienst für Claude, Anmeldung nur mit Apple, Sitzungstoken serverseitig als Hash); keine neue Abhängigkeit (Foundation, CryptoKit, Security gehören zum System-SDK).
- **Rationale:** (1) HTTP läuft über ein eigenes Protokoll `HTTPTransport` statt über eine `URLProtocol`-Attrappe: Das ist das Repo-Muster (`PlaceSearching`), kommt ohne globalen Zustand aus (Swift 6, parallele Swift-Testing-Läufe), und Tests prüfen die gesendete Anfrage direkt, einschließlich „es wurde nichts gesendet“. Ungeprüft bleibt nur die kurze `URLSession`-Anbindung. (2) Der rohe Nonce wird base64url ohne Auffüllung kodiert (43 Zeichen aus 32 Byte): ASCII, JSON-sicher, ohne Maskierung, und der Server hasht ohnehin den String, nicht die Bytes. (3) Der Fehlertyp trägt nie Token oder Antwortkörper, damit nichts davon in Logs oder Meldungen gelangt. (4) Die Dienst-Adresse kommt per `init`; der Info-Schlüssel `LEServiceURL` folgt erst mit `project.yml` in 4c.
- **Alternativen (verworfen):**
  - **A:** ein `AccountService`-Protokoll für die ganze Dienstseite, in den Zustandstests ersetzt. Der Draht-Vertrag (Header, Body, Statusabbildung) bliebe bis zum Serverbetrieb ungetestet. Gekippt würde nichts Bestehendes.
  - **B:** `URLProtocol`-Attrappe statt `HTTPTransport`: prüft auch den echten `URLSession`-Weg, kostet aber globalen Zustand unter Swift 6 und paralleler Testausführung. Später als Ergänzung möglich.
  - **C:** Anmeldung über den Web-Weg (`ASWebAuthenticationSession` gegen `/oauth`): würde den S3-Vertrag (`POST /auth/apple` mit Identity-Token und Code) kippen; nicht gewählt.
  - **Token in `UserDefaults`:** verworfen, ein Sitzungstoken gehört in den Schlüsselbund (4b-2).

## Source

**Files (CREATE):** `LooseEnds/Claude/Nonce.swift`, `LooseEnds/Claude/ServiceClient.swift`, `LooseEndsTests/ServiceClientTests.swift`; `CLAUDE.md` (MODIFY)
**Identifier:** `Nonce`, `HTTPTransport`, `URLSessionTransport`, `ServiceError`, `ServiceClient`

### Schnittstelle `Nonce`

- `struct Nonce: Sendable, Equatable` mit `let raw: String`.
- `init() throws`: 32 Byte aus `SecRandomCopyBytes(kSecRandomDefault, …)`; ein Status ungleich `errSecSuccess` wirft `NonceError.randomUnavailable(OSStatus)` (nicht verschlucken, nicht auf `SystemRandomNumberGenerator` zurückfallen), das Ergebnis ist base64url ohne Auffüllung (`-` und `_`, kein `=`), also 43 Zeichen.
- `init(raw: String)`: für Tests und Wiederherstellung; prüft nichts.
- `var hashed: String`: `Nonce.hash(raw)`.
- `static func hash(_ raw: String) -> String`: SHA-256 (CryptoKit) über `Data(raw.utf8)`, Hex in Kleinbuchstaben, 64 Zeichen. Testvektor: `hash("abc")` = `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`.
- `enum NonceError: Error, Equatable { case randomUnavailable(Int32) }`.

### Schnittstelle `ServiceClient`

- `protocol HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) }`.
- `struct URLSessionTransport: HTTPTransport`: `URLSession(configuration: .ephemeral)` (kein Cookie-, Cache- oder Anmeldedaten-Speicher), eine Antwort, die kein `HTTPURLResponse` ist, wirft `ServiceError.invalidResponse`. Wird in 4b-1 nicht aufgerufen (kein Test, keine Aufrufer).
- `enum ServiceError: Error, Equatable { case unauthorized, unavailable, rejected(Int), invalidResponse }`: ohne Token, Körper oder URL im Wert.
- `struct ServiceClient: Sendable` mit `init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport())`. **Erzeugen sendet nichts.**
  - `func signIn(identityToken: String, nonce: String, code: String) async throws -> String`: `POST <baseURL>/auth/apple`, `Content-Type: application/json`, `Accept: application/json`, Body ist ein JSON-Objekt mit **genau** den drei Schlüsseln `identityToken`, `nonce`, `code` (kein `clientId`, nichts weiter). Erfolg ist 200 mit einem JSON-Objekt, dessen `sessionToken` ein nicht leerer String ist; das Ergebnis ist dieser String. Fehlt er, ist er leer oder ist der Körper kein JSON-Objekt: `invalidResponse`.
  - `func logout(sessionToken: String) async throws`: `POST <baseURL>/auth/logout`, `Authorization: Bearer <token>`, kein Body; Erfolg ist genau 204.
  - `func deleteAccount(sessionToken: String) async throws`: `POST <baseURL>/auth/delete`, `Authorization: Bearer <token>`, kein Body; Erfolg ist genau 204.
  - Der Pfad wird an die Dienst-Adresse angehängt (`appending(path:)`); ein Schrägstrich am Ende der Adresse ergibt keinen doppelten.
  - Alle Anfragen haben `timeoutInterval` 15 s und `cachePolicy = .reloadIgnoringLocalCacheData`.
- **Statusabbildung** (gleich für alle drei Routen, gilt, wenn der Status nicht der Erfolgsstatus der Route ist): 401 → `unauthorized`; 503 → `unavailable`; jeder andere Status → `rejected(status)`. Eine `URLError` aus dem Transport → `unavailable` (kein Netz, Zeitüberschreitung, Dienst nicht erreichbar). Jeder andere Fehler aus dem Transport (z. B. `CancellationError`) wird unverändert weitergereicht. Bei einem Erfolgsstatus von `logout`/`deleteAccount` wird der Körper nicht gelesen.
- **Stille:** kein `Logger`, kein `print`; der Client schreibt nichts, weder Token noch Körper. Das Loggen von Ergebnissen gehört in 4b-2 und 4c und nennt nie ein Token.

### Festlegungen

- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Swift 6 strict concurrency (alle Typen `Sendable`, kein globaler Zustand); kein `try?`, das Fehler schluckt; keine neuen Pakete.
- **Unberührt:** `project.yml`, jede `*.entitlements`, jede `Info.plist`, `Shared/`, Server, Watch/Widgets/Share (sie kompilieren `LooseEnds/` nicht). Der App-Target nimmt `LooseEnds/` ordnerweise, der neue Ordner braucht keinen Eintrag; nach dem Anlegen läuft `./scripts/sim.sh generate`.
- **ADR-21-Satz** „bis dahin ruft die App den Dienst nirgends auf“ bleibt wahr, weil kein Aufrufer existiert; seine Anpassung folgt erst in 4c.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/src/auth.ts` (`parseLogin`, `bearerToken`, Routen), `server/src/apple.ts` (`claimsReason`) | Vertrag, nur gelesen, unverändert |
| Foundation (`URLSession`, `URLRequest`, `JSONSerialization`), CryptoKit (`SHA256`), Security (`SecRandomCopyBytes`) | System-SDK, keine neuen Pakete |
| `LooseEnds/Places/PlaceSearch.swift` (Muster Protokoll + `Sendable`), `LooseEndsTests/SavedPlacesStoreTests.swift` (Teststil) | Vorbild, unverändert |
| Upstream | 4a (Sitzungen laufen ab, 401 auf jedem Aufruf möglich) |
| Downstream | 4b-2 (`SessionStore`, `AccountState` nutzen `ServiceClient`, `ServiceError`, `Nonce`), 4c (Oberfläche, Berechtigung `applesignin`, `LEServiceURL`), 4d (nginx lässt `/auth/*` durch), #795 |

## Acceptance Criteria

Alle Tests mit Swift Testing (`import Testing`, `@testable import LooseEnds`) in `LooseEndsTests/ServiceClientTests.swift`, Lauf über
`./scripts/sim.sh sim-unit ServiceClientTests`. Der `FakeTransport` ist ein `actor` (oder an ein `Mutex` gebunden), zeichnet jede `URLRequest` auf und
liefert je Aufruf eine vorgegebene Antwort (Status und Körper) oder wirft einen vorgegebenen Fehler. Ablehnungsfälle tabellengetrieben (`@Test(arguments:)`), ein Fall je Zeile.

- **AC-1:** Nonce-Testvektor: `Nonce.hash("abc")` ist `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`; `Nonce(raw: "abc").hashed` ist derselbe Wert; das Ergebnis hat 64 Zeichen, nur `0-9a-f`. Ein zweiter Vektor mit Nicht-ASCII-Zeichen (`"äö"`) belegt, dass über die UTF-8-Bytes des Strings gehasht wird (erwarteter Wert fest im Test, einmal mit `shasum -a 256` auf dem UTF-8-Text berechnet und im Test kommentiert). Test: „nonce: hash testvektoren“.
- **AC-2:** Zufall und Form: `Nonce()` liefert `raw` mit 43 Zeichen aus `[A-Za-z0-9_-]`, ohne `=`; die Rückkodierung (base64url → 32 Byte) ergibt genau 32 Byte; zwei Aufrufe liefern verschiedene `raw`; `hashed` ist `Nonce.hash(raw)`. Test: „nonce: roher wert 32 byte base64url und verschieden“.
- **AC-3:** Erzeugen sendet nichts: Nach `ServiceClient(baseURL:transport:)` und ohne weiteren Aufruf hat der `FakeTransport` null Anfragen; ebenso nach dem Erzeugen von `Nonce()`. Test: „serviceclient: erzeugen sendet nichts“.
- **AC-4:** Draht-Vertrag `signIn`: Genau eine Anfrage, Methode `POST`, Pfad `/auth/apple` (auch mit und ohne Schrägstrich am Ende der Dienst-Adresse und mit einem Pfadpräfix in der Adresse, z. B. `https://example.test/api` → `/api/auth/apple`), Header `Content-Type: application/json`, kein `Authorization`-Header, Body als JSON-Objekt mit genau den Schlüsseln `identityToken`, `nonce`, `code` und den übergebenen Werten (Schlüsselmenge wird geprüft, nicht nur Werte). Bei 200 mit `{"sessionToken":"abc123"}` ist das Ergebnis `"abc123"`. Test: „serviceclient: signin draht-vertrag“.
- **AC-5:** Antwort von `signIn`: 200 mit leerem `sessionToken`, fehlendem Schlüssel, `sessionToken` kein String, JSON-Array statt Objekt und kaputtem JSON liefert je `ServiceError.invalidResponse` (tabellengetrieben). Test: „serviceclient: signin ungueltige antwort“.
- **AC-6:** Draht-Vertrag `logout` und `deleteAccount`: je genau eine Anfrage, Methode `POST`, Pfad `/auth/logout` bzw. `/auth/delete`, Header `Authorization: Bearer <token>` (Wert genau `Bearer ` plus Token), kein Body (`httpBody == nil`), kein `Content-Type`; Antwort 204 ergibt Erfolg ohne Rückgabewert. Test: „serviceclient: logout und delete draht-vertrag“.
- **AC-7:** Statusabbildung je Route (tabellengetrieben über Route und Status): 401 → `unauthorized`; 503 → `unavailable`; 400, 405, 413, 415, 500 → `rejected(<Status>)`; bei `signIn` zusätzlich 204 → `rejected(204)`, bei `logout`/`deleteAccount` zusätzlich 200 → `rejected(200)` (Erfolg ist genau der Status der Route). Test: „serviceclient: statusabbildung je route“.
- **AC-8:** Transportfehler: `URLError(.notConnectedToInternet)`, `URLError(.timedOut)` und `URLError(.cannotConnectToHost)` aus dem Transport ergeben je Route `ServiceError.unavailable`; ein `CancellationError` wird unverändert weitergereicht (nicht in `unavailable` umgedeutet). Test: „serviceclient: transportfehler“.
- **AC-9:** Keine Preisgabe: Der Wert jedes `ServiceError` aus AC-5 bis AC-8 enthält weder das übergebene Token noch den Antwortkörper (Test setzt erkennbare Marker wie `"SECRET-TOKEN"` ein und prüft, dass `String(describing: error)` sie nicht enthält); der Client ruft `Logger` und `print` nirgends auf (Beleg: `grep -nE 'Logger|print\(' LooseEnds/Claude/Nonce.swift LooseEnds/Claude/ServiceClient.swift` ohne Treffer, einmalig in `/60-validate` im Protokoll, kein dauerhafter Test). Test: „serviceclient: fehler ohne token und koerper“.
- **AC-10:** Grenze, Länge, Doku: Die neuen Dateien liegen unter `LooseEnds/Claude/` und `LooseEndsTests/`; `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `LooseEnds/Claude/Nonce.swift`, `LooseEnds/Claude/ServiceClient.swift`, `LooseEndsTests/ServiceClientTests.swift` und `CLAUDE.md` (kein `project.yml`, keine Entitlements, keine `Info.plist`, keine Datei unter `Shared/` oder `server/`); keine Funktion über 50 Zeilen. Der Abschnitt „Where things live“ in `CLAUDE.md` bekommt einen Eintrag `LooseEnds/Claude` mit einem Halbsatz je Typ (`Nonce`: roher Wert 32 Byte base64url, `hashed` = SHA-256 Hex klein; `ServiceClient`: die drei Routen über `HTTPTransport`, `ServiceError`, kein Token im Fehler; nichts in der App ruft den Kern auf, #615 S4b-1). Beleg: einmalig in `/60-validate` im Validierungsprotokoll (`git diff --name-only`, Zählung der Funktionslängen, `grep -n 'LooseEnds/Claude' CLAUDE.md` mit genau einem Treffer im Abschnitt „Where things live“); kein Test gegen `origin/main`.
- **AC-11:** Regression: `./scripts/sim.sh sim-unit` (alle Unit-Tests) ist grün; `./scripts/sim.sh build` baut die App mit dem neuen Ordner (nach `generate`) ohne Fehler und ohne neue Warnungen aus den neuen Dateien. Beleg: Lauf im Validierungsprotokoll.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/Nonce.swift` | CREATE | `Nonce`, `NonceError`, ≈ +35 |
| `LooseEnds/Claude/ServiceClient.swift` | CREATE | `HTTPTransport`, `URLSessionTransport`, `ServiceError`, `ServiceClient`, ≈ +95 |
| `LooseEndsTests/ServiceClientTests.swift` | CREATE | `FakeTransport`, Tests AC-1 bis AC-9, ≈ +120 |
| `CLAUDE.md` | MODIFY | Eintrag `LooseEnds/Claude` unter „Where things live“, ≈ +4 |

### Estimated Changes

- **Files: 4** (Spec und Kontext zählen nicht), innerhalb der 4 bis 5. **LoC ≈ +254** nach der Tabelle in Affected Files (35 + 95 + 120 + 4) und damit knapp an der Grenze von ±250. Ziel beim Bauen ist ≤ 250: die Statusabbildung (AC-7, AC-8) läuft als eine parametrisierte Testtabelle über alle drei Routen statt je Route einzeln; der Code wird dafür nicht gestrafft. Liegt der Stand nach `/50-implement` trotzdem über 250, wird das im Validierungsprotokoll mit der Zahl benannt.
- Keine Permissions, keine Info.plist-Änderung, keine AppStorage-Schlüssel, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, keine Entitlements, kein Audio. Seiteneffekt: keiner im Betrieb, weil nichts den Kern aufruft und `/auth/*` per nginx noch 404 liefert.

## Risiken

- **Zufallsquelle fällt aus:** `SecRandomCopyBytes` scheitert praktisch nie; wenn doch, wirft `Nonce()` und 4b-2 meldet „nicht angemeldet“, statt mit einem schwachen Wert weiterzumachen.
- **`URLSessionTransport` ungetestet:** Die dreizeilige Anbindung läuft erst in 4c gegen einen Ersatz-Dienst im Simulator. Das ist bewusst (Alternative B); ein Fehler dort zeigt sich im UI-Test von 4c, nicht im Produkt, weil nichts aufruft.
- **Server-Antwortform ändert sich:** Der Client erwartet `{ "sessionToken": "…" }` (heutiger Stand `auth.ts`). Ändert der Server das, schlägt AC-4 nicht an, weil der Test den Server nicht kennt; deshalb ist der Vertrag in diesem Abschnitt „Purpose“ mit Quellzeile genannt und der Serverbetrieb (4d) prüft ihn einmal end-to-end.
- **Umfang:** ≈ 250 LoC an der Grenze; die Tabellen in den Tests halten sie klein (siehe Estimated Changes).

## Befunde gegen den Plan

- **F1:** Der Ablauf nach 90 Tagen zeigt sich erst beim nächsten Aufruf als 401. Der Client bildet das auf `unauthorized` ab; 4b-2 und 4c dürfen nicht annehmen, die Anzeige wisse es vorher.
- **F2:** Die echte Schlüsselbund-Ablage ist im Unit-Test nicht belegbar (`-34018`, Probelauf 2026-11-09); sie gehört zu 4b-2 und ihr Beleg zu 4c im Simulator über die App. Dieser Schnitt berührt keinen Schlüsselbund.
- **F3:** Der ADR-21-Satz „die App ruft den Dienst nirgends auf“ bleibt in 4b-1 wahr (keine Aufrufer), die Anpassung folgt in 4c.

## Test Plan

### Automated Tests (TDD RED)

RED: Alle Tests schlagen zunächst fehl, weil `Nonce` und `ServiceClient` nicht existieren (Test-Ziel baut nicht); das ist der erwartete Zustand vor `/50-implement`.
Zusätzlich gilt für die Gegenrichtung: AC-3 (nichts gesendet) und AC-9 (kein Token im Fehler) bleiben auch nach der Implementierung Prüfungen gegen versehentliches Senden und Loggen.

| Testname | AC |
|---|---|
| „nonce: hash testvektoren“ | AC-1 |
| „nonce: roher wert 32 byte base64url und verschieden“ | AC-2 |
| „serviceclient: erzeugen sendet nichts“ | AC-3 |
| „serviceclient: signin draht-vertrag“ | AC-4 |
| „serviceclient: signin ungueltige antwort“ | AC-5 |
| „serviceclient: logout und delete draht-vertrag“ | AC-6 |
| „serviceclient: statusabbildung je route“ | AC-7 |
| „serviceclient: transportfehler“ | AC-8 |
| „serviceclient: fehler ohne token und koerper“ | AC-9 |
| kein Test: Validierungsbeleg in `/60-validate` (`git diff --name-only`, Funktionslängen, `grep`) | AC-9 (Teil), AC-10 |
| voller `./scripts/sim.sh sim-unit` und `./scripts/sim.sh build` | AC-11 |

- [ ] Test 1 (AC-1, AC-2): GIVEN der Eingabewert `abc` bzw. ein frisch erzeugter `Nonce` WHEN gehasht bzw. geprüft THEN der SHA-256-Testvektor, 64 Hexzeichen klein, `raw` mit 43 base64url-Zeichen und zwei Nonces verschieden.
- [ ] Test 2 (AC-3, AC-4, AC-5): GIVEN ein Client mit `FakeTransport` WHEN erzeugt und danach `signIn` aufgerufen wird THEN null Anfragen nach dem Erzeugen, danach genau eine `POST /auth/apple` mit genau drei Körperfeldern; ungültige 200-Antworten ergeben `invalidResponse`.
- [ ] Test 3 (AC-6, AC-7): GIVEN ein Client WHEN `logout` und `deleteAccount` mit einem Token laufen THEN `Authorization: Bearer <token>`, kein Körper, 204 ist Erfolg, und 401, 503 und andere Status werden je Route auf `unauthorized`, `unavailable`, `rejected(n)` abgebildet.
- [ ] Test 4 (AC-8, AC-9): GIVEN ein Transport, der `URLError` bzw. `CancellationError` wirft, und Fehlerantworten mit erkennbaren Markern WHEN die Routen laufen THEN `unavailable` bzw. durchgereichtes `CancellationError`, und kein Fehlerwert enthält Token oder Körper.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Nicht in diesem Schnitt / Folgeschnitte

- **4b-2 (im selben Workflow, eigene Teil-Spec):** `SessionStoring` mit `KeychainSessionStore` und `InMemorySessionStore`, `AccountState` (`@MainActor @Observable`, Status `signedOut/signingIn/signedIn/deleting/notAllowed/retryLater`, Nonce einmalig, 401 verwirft die lokale Sitzung nur, wenn der gespeicherte Token noch der benutzte ist), `AccountStateTests` inkl. „abgemeldet → null Anfragen“. Möglicherweise Teilung in 4b-3 (`KeychainSessionStore`), falls der Umfang überläuft.
- **4c Einstellungen:** Gruppe „Konto“, `ASAuthorizationController`, Berechtigung „Mit Apple anmelden“ in `project.yml`, `LEServiceURL`/`LEAccountEnabled`, Texte de/en, UI-Test gegen Ersatz-Dienst, Beleg der echten Keychain-Ablage im Simulator; Entwurf der Gruppe vor der Spec (PO-Regel 2026-09-22); Stufe 3 über TestFlight.
- **4d Freigabe nach außen:** nginx genau `/auth/apple`, `/auth/logout`, `/auth/delete`, `APPLE_CLIENT_IDS` mit App- und Prüfbau-Kennung, Datenschutztext (Konto-Teil), dann `LEAccountEnabled` im Store-Bau an.

## Abnahme

- Stufe 1 Tests: neue Tests vorher rot (Ziel baut nicht), danach grün über `./scripts/sim.sh sim-unit ServiceClientTests`, voller `./scripts/sim.sh sim-unit` grün.
- Stufe 2 Simulator: Kein sichtbarer Ablauf der App ändert sich; die App ruft `Nonce` und `ServiceClient` nicht auf (wie bei `OrderExecutor`, vgl. `docs/specs/fix-777-order-duehastime.md`). Beleg ist der Unit-Lauf im Simulator samt `./scripts/sim.sh build`, im Abschlussbericht benannt. Es gibt keinen Bedienablauf, der durchzuspielen wäre.
- Stufe 3 Gerät: keine. Kein Pfad der Geräteliste berührt (`LooseEnds/Claude/` steht nicht darin; kein `project.yml`, keine Entitlements, keine `Info.plist`).

## Definition of Done

- [ ] AC-1 bis AC-11 erfüllt; AC-1 bis AC-8 und der Marker-Teil von AC-9 als dauerhafte Tests, die grep-Prüfung aus AC-9 sowie AC-10 und AC-11 als einmalige Belege im Validierungsprotokoll von `/60-validate` (kein dauerhafter Diff- oder grep-Test)
- [ ] `./scripts/sim.sh sim-unit` grün, `./scripts/sim.sh build` grün, CI auf dem PR grün
- [ ] `CLAUDE.md` („Where things live“) nennt `LooseEnds/Claude`
- [ ] Kein Pfad der Geräteliste berührt; Abnahme endet nach Stufe 2, im Abschlussbericht mit genau diesem Satz
- [ ] #615 kommentiert (Stand 4b-1: Nonce und Dienst-Client gebaut, nichts ruft sie auf; Folge 4b-2), Board-Karte aktuell
- [ ] Abschlussbericht ohne Git-Vokabular: im Produkt ist nichts sichtbar, Henning muss nichts tun

## Changelog

- 2026-11-09: Initial spec created (Schnitt 4b-1, Teil-Spec)
