---
entity_id: feat-615-schnitt-4b2-sitzung
type: feature
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: feat-615-s4b2-sitzung
---

# Spec: App-Kern Anmeldung, Schnitt 4b-2: Sitzungsablage und Kontozustand (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Teil-Spec für Schnitt 4b-2; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s4b2-sitzung.md` (Abschnitt „Technical Approach“ ist verbindlich), Plan und Fehlerabbildung
`docs/context/feat-615-s4b-app-kern.md` (Zeilen 60–120). Vorgänger: Schnitt 4b-1 (`docs/specs/feat-615-schnitt-4b1-dienst-client.md`,
PR #884: `Nonce`, `ServiceClient`). Diese Spec deckt nur 4b-2 ab; der Schlüsselbund (`KeychainSessionStore`) ist Schnitt 4b-3.

## Für den PO

Dieser Schritt baut im Inneren der App den Teil, der sich merkt, ob jemand beim Dienst für Claude angemeldet ist, und der die
Anmeldung, das Abmelden und das Löschen des Kontos Schritt für Schritt führt, auch wenn das Netz weg ist oder der Dienst ablehnt.
Du siehst davon nichts: Die App ruft diesen Teil noch nirgends auf, und es gibt noch keine Schaltfläche. Der sichere Speicher auf dem
Gerät folgt im nächsten kleinen Schritt, die Oberfläche in den Einstellungen danach.

## Purpose

Zwei neue Kernbausteine in `LooseEnds/Claude/`, die `ServiceClient` und `Nonce` aus 4b-1 benutzen: die Ablage des Sitzungstokens hinter dem
Protokoll `SessionStoring` (hier nur der Ersatz im Speicher) und der Kontozustand `AccountState`, den die Oberfläche in 4c liest.
Nichts in der App ruft den Kern auf (wie `OrderExecutor`). **Regeln vor Modell:** Zustandsführung und Protokollarbeit, keine
Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Server-Vertrag (nur gelesen, unverändert): `POST /auth/apple` liefert `{ sessionToken }`, 401 nackt, 503 bei fehlender Konfiguration oder
nicht erreichbarem Apple; `POST /auth/logout` ist 204 mit jedem Bearer; `POST /auth/delete` ist 204, 401 bei fehlendem, unbekanntem oder
seit 4a nach 90 Tagen ohne Nutzung abgelaufenem Token. Der `ServiceClient` bildet das auf `ServiceError` ab (`unauthorized`, `unavailable`,
`rejected(Int)`, `invalidResponse`) und reicht `CancellationError` unverändert durch.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue — Ausgestaltung von ADR-21 (Weg B: Dienst für Claude, Anmeldung nur mit Apple, Sitzungstoken serverseitig als Hash); keine neue Abhängigkeit (Foundation, OSLog, Synchronization gehören zum System-SDK).
- **Rationale:** (1) Die Ablage steht hinter einem Protokoll, damit der Zustand ohne Schlüsselbund prüfbar ist: Der Schlüsselbund ist im Unit-Test nicht belegbar (`-34018` ohne signierten Host, Probelauf 2026-11-09), der Ersatz im Speicher dient später auch unter `--ui-testing`. (2) `AccountState` ist `@MainActor @Observable` (Muster `SavedPlacesStore`), der Client ist `@ObservationIgnored`; Status `signingIn` und `deleting` sind zugleich die Sperre gegen Doppelaufrufe, weil alles auf dem Hauptakteur läuft. (3) „Erst speichern, dann angemeldet“ und „lokal löschen vor dem Dienstaufruf“ stehen im Zustandsobjekt und sind dort testbar, nicht in der späteren Oberfläche. (4) Ein misslungenes Löschen lässt die Sitzung sichtbar bestehen: `retryLater` steht dort als `lastProblem` neben `signedIn`, nicht als Status, sonst wüsste die Oberfläche nicht, dass die Sitzung noch gilt. (5) Ein Fehlerwert, ein Log und der Zustand nennen nie ein Token oder eine Nonce.
- **Alternativen (verworfen):**
  - **A:** Schlüsselbund gleich mit in 4b-2 (ein Schnitt, ≈ 355 LoC): reißt die Grenze ±250 klar; der Schlüsselbund ist im Unit-Test ohnehin nur über die reine Statusabbildung prüfbar. Er kommt als 4b-3.
  - **B:** reine Zustandsmaschine (enum + `reduce`) ohne `@Observable`, die Async-Aufrufe in der Oberfläche: besser prüfbar im Kleinen, aber „erst speichern, dann angemeldet“ und die Regel gegen veraltete 401 lägen dann in 4c. Gekippt würde nichts Bestehendes.
  - **C:** Anmeldung über den Web-Weg (`/oauth`) statt App-Route: kippt den S3-Vertrag (`POST /auth/apple`), nicht gewählt.
  - **Token in `UserDefaults`:** verworfen, ein Sitzungstoken gehört in den Schlüsselbund (4b-3).

## Source

**Files (CREATE):** `LooseEnds/Claude/SessionStore.swift`, `LooseEnds/Claude/AccountState.swift`, `LooseEndsTests/AccountStateTests.swift`
**Identifier:** `SessionStoring`, `InMemorySessionStore`, `AccountState`, `AccountState.Status`, `AccountState.Problem`, `AccountError`

### Schnittstelle `SessionStoring` und `InMemorySessionStore` (`SessionStore.swift`)

- `protocol SessionStoring: Sendable { func load() throws -> String?; func save(_ token: String) throws; func clear() throws }`. `load` liefert `nil`, wenn nichts gespeichert ist; `clear` ohne gespeichertes Token ist kein Fehler.
- `final class InMemorySessionStore: SessionStoring, @unchecked Sendable` bzw. mit `Mutex` aus `Synchronization` (Wahl beim Bau, Swift 6 strict concurrency muss ohne Warnung durchlaufen): `init(token: String? = nil)`; `var token: String?` (lesender Zugriff für Tests); `func failNext(load:save:clear:)` bzw. gleichwertig, womit ein Test dem nächsten `load`, `save` oder `clear` einen Fehler einspielt (`SessionStoreError.injected`, eigener kleiner Fehlertyp ohne Token im Wert). Ohne eingespielten Fehler arbeitet der Ersatz fehlerfrei.
- Keine Schlüsselbund-Anbindung in diesem Schnitt.

### Schnittstelle `AccountState` (`AccountState.swift`)

- `@MainActor @Observable final class AccountState`. `enum Status: Equatable, Sendable { signedOut, signingIn, signedIn, deleting, notAllowed, retryLater }`. `enum Problem: Equatable, Sendable { case retryLater }`. `enum AccountError: Error, Equatable { case notPossibleNow }`.
- `private(set) var status: Status`, `private(set) var lastProblem: Problem?`.
- `init(client: ServiceClient, store: any SessionStoring)`: liest die Ablage einmal und sendet nichts. Token vorhanden → `signedIn`, kein Token → `signedOut`, Lesefehler → `signedOut` (geloggt). Client und Ablage sind `@ObservationIgnored`. Die offene `Nonce` ist ein privates Feld.
- `func beginSignIn() throws -> String`: nur aus `signedOut`, `notAllowed`, `retryLater`; sonst `AccountError.notPossibleNow`, Status unverändert. Erzeugt eine neue `Nonce` (ein Fehler von `Nonce()` wird weitergeworfen und ändert den Status nicht), setzt Status `signingIn`, `lastProblem = nil`, gibt `nonce.hashed` zurück (das gehört in die Apple-Anfrage, 4c).
- `func completeSignIn(identityToken: String, code: String) async`: wirkt nur bei Status `signingIn` mit offener Nonce, sonst Rückkehr ohne Anfrage und ohne Zustandsänderung. Die Nonce wird beim Aufruf verbraucht (vor dem Request). Dann `client.signIn(identityToken:nonce:code:)` mit `nonce.raw`. Ergebnis: Token → `store.save`, erst bei Erfolg Status `signedIn`; Speicherfehler → Status `signedOut` und nichts gespeichert (geloggt). `ServiceError.unauthorized` → `notAllowed`; `unavailable` → `retryLater`; `rejected`/`invalidResponse` → `signedOut` (geloggt); `CancellationError` → `signedOut` ohne Fehlerzustand und ohne Log als Fehler. Während der Anfrage bleibt der Status `signingIn`.
- `func cancelSignIn()`: nur bei Status `signingIn` mit noch offener Nonce (Anfrage noch nicht gestartet): verwirft die Nonce, Status `signedOut`. In jedem anderen Zustand, auch während die Anfrage läuft, wirkungslos.
- `func signOut() async`: nur aus `signedIn`, `notAllowed`, `retryLater`, `signedOut` (nicht in `signingIn` und `deleting`: wirkungslos). Liest das Token aus der Ablage. Kein Token (oder Lesefehler): Status `signedOut`, null Anfragen. Mit Token: zuerst `store.clear()` und Status `signedOut` und `lastProblem = nil`, danach `client.logout(sessionToken:)` als Best-Effort; jedes Ergebnis des Dienstes (auch Fehler und `CancellationError`) ändert den Zustand nicht. Ein Löschfehler der Ablage wird geloggt, der Status ist trotzdem `signedOut`, der Dienstaufruf läuft trotzdem.
- `func deleteAccount() async`: nur aus `signedIn`, sonst wirkungslos ohne Anfrage. Liest das Token (kein Token oder Lesefehler: Status `signedOut`, null Anfragen, geloggt). Status `deleting`, `lastProblem = nil`, `client.deleteAccount(sessionToken:)` mit dem gelesenen Token. Ergebnis: Erfolg → `store.clear()`, `signedOut`; `unauthorized` → Sitzung gilt nicht mehr: `store.clear()` **nur wenn das gespeicherte Token noch das benutzte ist** (sonst bleibt die Ablage unberührt), Status danach `signedIn`, wenn die Ablage ein Token hält, sonst `signedOut`; `unavailable`, `rejected`, `invalidResponse` → Status `signedIn`, Token bleibt, `lastProblem = .retryLater`, geloggt; `CancellationError` → Status `signedIn`, Token bleibt, `lastProblem = nil`.
- Doppelaufrufe: Solange der Status `signingIn` (Anfrage läuft) oder `deleting` ist, löst ein weiterer `completeSignIn`, `deleteAccount` oder `signOut` keine zweite Anfrage aus; `beginSignIn` wirft `notPossibleNow`.
- **Stille:** Logger `Logger(subsystem: "com.henning.looseends", category: "account")`, kein `print`. Geloggt werden nur der Name des Fehlerfalls und der Übergang, nie Token, Nonce, Identity-Token, Code oder Antwortkörper.

### Festlegungen

- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Swift 6 strict concurrency; kein `try?`, das Fehler schluckt; keine neuen Pakete.
- **Unberührt:** `project.yml`, jede `*.entitlements`, jede `Info.plist`, `Shared/`, `server/`, `CLAUDE.md` (der Eintrag `LooseEnds/Claude` aus 4b-1 wird in 4b-3 um Ablage und Zustand ergänzt, damit ein Text für beide Schnitte entsteht; ist 4b-3 nicht absehbar, ergänzt `/60-validate` einen Halbsatz, das zählt dann als eigene Änderung). Der App-Target nimmt `LooseEnds/` ordnerweise; nach dem Anlegen läuft `./scripts/sim.sh generate`.
- **Festlegung über die Analyse hinaus:** `rejected`/`invalidResponse` beim Löschen behandeln wie `unavailable` (Sitzung bleibt, `lastProblem = .retryLater`), weil das Konto dann ebenfalls noch besteht und der Nutzer es erneut versuchen kann.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `LooseEnds/Claude/ServiceClient.swift`, `Nonce.swift` (4b-1) | Abhängigkeit, unverändert |
| `LooseEndsTests/ServiceClientTests.swift` (`ServiceClientTests.FakeTransport`) | wiederverwendet, unverändert |
| `LooseEnds/Places/SavedPlacesStore.swift` | Vorbild `@MainActor @Observable`, unverändert |
| `server/src/auth.ts` | Vertrag (401, 204), nur gelesen |
| Foundation, OSLog, Synchronization | System-SDK, keine neuen Pakete |
| Upstream | 4b-1 (gemergt), 4a (Sitzungen laufen nach 90 Tagen ab) |
| Downstream | 4b-3 (`KeychainSessionStore`), 4c (Oberfläche, `applesignin`, `LEServiceURL`, Beleg der echten Ablage im Simulator), #795 |

## Acceptance Criteria

Alle Tests mit Swift Testing (`import Testing`, `@testable import LooseEnds`, `@Test @MainActor`) in `LooseEndsTests/AccountStateTests.swift`,
Lauf über `./scripts/sim.sh sim-unit AccountStateTests`. Als Transport dient `ServiceClientTests.FakeTransport` (zeichnet Anfragen auf, Antworten je Aufruf);
für „während die Anfrage läuft“ und „gespeichertes Token wechselt“ ein kleiner Haken-Transport in der Testdatei, der vor der Antwort einen Block ausführt.
Fehlerfälle tabellengetrieben (`@Test(arguments:)`).

- **AC-1:** Start mit gespeichertem Token: `AccountState(client:store:)` ergibt Status `signedIn`, `lastProblem == nil`, null Anfragen am Transport. Test: „account: start mit token“.
- **AC-2:** Start ohne Token ergibt `signedOut`; ein Lesefehler der Ablage ergibt ebenfalls `signedOut`; beide Fälle mit null Anfragen. Test: „account: start ohne token und bei lesefehler“.
- **AC-3:** `beginSignIn` aus `signedOut`, `notAllowed` und `retryLater` (letztere beiden über einen vorangegangenen Lauf hergestellt) gibt einen 64 Zeichen langen Hex-String in Kleinbuchstaben zurück und setzt Status `signingIn`; aus `signingIn`, `signedIn` und `deleting` wirft es `AccountError.notPossibleNow` und lässt Status und offene Nonce unverändert. Test: „account: beginsignin nur aus erlaubten zustaenden“.
- **AC-4:** Das von `beginSignIn` Zurückgegebene ist der Hash der Nonce, die `completeSignIn` sendet: Der Anfragekörper von `POST /auth/apple` trägt `nonce` (roh, 43 Zeichen) mit `Nonce.hash(<nonce>) ==` Rückgabewert von `beginSignIn`, dazu die übergebenen Werte `identityToken` und `code` und sonst nichts. Zwei `beginSignIn`-Läufe liefern verschiedene Werte. Test: „account: body traegt rohe nonce zum hash“.
- **AC-5:** `completeSignIn` ohne vorheriges `beginSignIn` sendet nichts und ändert den Status nicht (aus `signedOut` und aus `signedIn`); die Nonce wird verbraucht: ein zweiter `completeSignIn` nach einem ersten (egal wie ausgegangen) sendet keine zweite Anfrage. Test: „account: completesignin ohne nonce und nonce einmalig“.
- **AC-6:** Erfolg: 200 mit `{"sessionToken":"T1"}` speichert `T1` in der Ablage und setzt dann Status `signedIn`; `lastProblem == nil`. Test: „account: anmelden speichert und ist angemeldet“.
- **AC-7:** Speicherfehler beim Speichern: Der Dienst antwortet 200, `save` wirft; Ergebnis Status `signedOut`, Ablage ohne Token (nie ein Zwischenzustand `signedIn`: der Test prüft den Status nach dem Aufruf und dass die Ablage leer ist). Test: „account: speicherfehler ergibt abgemeldet“.
- **AC-8:** Fehlerabbildung `completeSignIn` (tabellengetrieben, Ablage bleibt in jedem Fall leer): `unauthorized` → `notAllowed`; `unavailable` (auch als `URLError` aus dem Transport) → `retryLater`; `rejected(400)`, `rejected(500)` und `invalidResponse` (200 mit leerem Token) → `signedOut`; `CancellationError` aus dem Transport → `signedOut` und `lastProblem == nil`. Test: „account: anmelden fehlerabbildung“.
- **AC-9:** `cancelSignIn` aus `signingIn` mit offener Nonce ergibt `signedOut` und verwirft die Nonce (ein folgender `completeSignIn` sendet nichts); in `signedOut`, `signedIn` und während die Anfrage von `completeSignIn` läuft ist es wirkungslos (Status und Ergebnis der laufenden Anmeldung unverändert). Test: „account: cancelsignin“.
- **AC-10:** `signOut` mit Token: Zum Zeitpunkt der Dienstanfrage ist die Ablage bereits leer und der Status bereits `signedOut` (Haken-Transport prüft beides); genau eine Anfrage `POST /auth/logout` mit `Authorization: Bearer <Token>`. Ob der Dienst 204, 401, 503 oder `CancellationError` liefert: Status bleibt `signedOut`, `lastProblem == nil`. Test: „account: signout lokal zuerst dann dienst“.
- **AC-11:** `signOut` ohne Token (Ablage leer oder Lesefehler) sendet null Anfragen und endet in `signedOut`; schlägt `clear` fehl, ist der Status trotzdem `signedOut` und die Anfrage `POST /auth/logout` wird dennoch gesendet. Test: „account: signout ohne token und bei loeschfehler“.
- **AC-12:** `deleteAccount` mit Token, Antwort 204: genau eine Anfrage `POST /auth/delete` mit `Authorization: Bearer <Token>`, danach Ablage leer, Status `signedOut`, `lastProblem == nil`. Aus jedem anderen Status als `signedIn` (`signedOut`, `signingIn`, `notAllowed`, `retryLater`, `deleting`) sendet es nichts; ist die Ablage bei Status `signedIn` leer oder nicht lesbar, sendet es nichts und endet in `signedOut`. Test: „account: konto loeschen erfolg und nur aus signedin“.
- **AC-13:** Fehlerabbildung `deleteAccount` (tabellengetrieben): `unauthorized` → Ablage leer, Status `signedOut`; `unavailable`, `rejected(500)` und `invalidResponse` → Status `signedIn`, Token weiter in der Ablage, `lastProblem == .retryLater`; `CancellationError` → Status `signedIn`, Token weiter in der Ablage, `lastProblem == nil`. Ein folgender erfolgreicher Löschversuch setzt `lastProblem` zurück. Test: „account: konto loeschen fehlerabbildung“.
- **AC-14:** Veraltete 401: Wechselt während der Löschanfrage das gespeicherte Token von `T1` auf `T2` (Haken-Transport ersetzt es in der Ablage vor der Antwort 401), bleibt `T2` in der Ablage stehen und der Status ist `signedIn`; nur wenn die Ablage noch `T1` hält, wird sie geleert. Test: „account: veraltete 401 loescht keine neue sitzung“.
- **AC-15:** Doppelaufrufe: Läuft eine Anfrage (Haken-Transport hält sie an), erzeugen ein zweites `completeSignIn` bzw. ein zweites `deleteAccount` sowie `signOut` keine zweite Anfrage und `beginSignIn` wirft `notPossibleNow`; am Ende hat der Transport genau eine Anfrage gesehen und der Zustand entspricht dem Ergebnis der ersten. Test: „account: doppelaufrufe waehrend anfrage“.
- **AC-16:** Keine Preisgabe: Weder `lastProblem` noch `status` noch ein geworfener `AccountError` enthalten Token oder Nonce (`String(describing:)` mit Markern wie `"SECRET-TOKEN"` in Token und Dienstantwort). Der Kern ruft `print` nirgends auf und loggt nur Fallnamen; Beleg einmalig in `/60-validate` im Protokoll: `grep -nE 'print\(' LooseEnds/Claude/SessionStore.swift LooseEnds/Claude/AccountState.swift` ohne Treffer und Sichtung jeder `logger.`-Zeile auf Token-, Nonce- und Körperfreiheit (kein dauerhafter Test für den grep-Teil). Test (Marker-Teil): „account: zustand ohne token und nonce“.
- **AC-17:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `LooseEnds/Claude/SessionStore.swift`, `LooseEnds/Claude/AccountState.swift` und `LooseEndsTests/AccountStateTests.swift` (kein `project.yml`, keine Entitlements, keine `Info.plist`, nichts unter `Shared/` oder `server/`, keine Schlüsselbund-Anbindung); keine Funktion über 50 Zeilen. Beleg: einmalig in `/60-validate` im Validierungsprotokoll, kein Test gegen `origin/main`.
- **AC-18:** Regression: `./scripts/sim.sh sim-unit` (alle Unit-Tests) ist grün; `./scripts/sim.sh build` baut die App mit den neuen Dateien (nach `generate`) ohne Fehler und ohne neue Warnungen aus ihnen. Beleg: Lauf im Validierungsprotokoll.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/SessionStore.swift` | CREATE | `SessionStoring`, `InMemorySessionStore`, `SessionStoreError`, ≈ +30 |
| `LooseEnds/Claude/AccountState.swift` | CREATE | `AccountState`, `Status`, `Problem`, `AccountError`, ≈ +105 |
| `LooseEndsTests/AccountStateTests.swift` | CREATE | Tests AC-1 bis AC-16 mit Haken-Transport und Tabellen, ≈ +125 |

### Estimated Changes

- **Files: 3** (Spec und Kontext zählen nicht), innerhalb der 4 bis 5. **LoC ≈ +260** nach der Tabelle (30 + 105 + 125), an der Grenze von ±250. Ziel beim Bauen ist ≤ 250: die Fehlerabbildungen (AC-8, AC-13) laufen als je eine parametrisierte Testtabelle, der Haken-Transport ist ein kleiner gemeinsamer Helfer. Liegt der Stand nach `/50-implement` darüber, wird die Zahl im Validierungsprotokoll benannt und der Überhang wie in 4b-1 mit den Sicherheitstests (veraltete 401, Doppelaufrufe) begründet.
- Keine Permissions, keine Info.plist-Änderung, keine AppStorage-Schlüssel, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, keine Entitlements, kein Audio. Seiteneffekt: keiner im Betrieb, weil nichts den Kern aufruft und `/auth/*` per nginx noch 404 liefert.

## Risiken

- **Schlüsselbund nicht im Unit-Test belegbar:** gehört zu 4b-3; sein Beleg kommt in 4c im Simulator über die App. 4b-2 berührt keinen Schlüsselbund und beweist nur die Zustandsführung gegen den Ersatz.
- **Ersatz ≠ echte Ablage:** Dass `load`/`save`/`clear` des Schlüsselbunds sich wie der Ersatz verhalten (Duplikat → Update, NotFound beim Lesen = `nil`, beim Löschen = Erfolg), ist hier Annahme des Protokolls und wird in 4b-3 über die `OSStatus`-Abbildung als reine Funktion geprüft.
- **Rennen um die Ablage:** Zwei `AccountState`-Instanzen (nicht vorgesehen) könnten dieselbe Ablage ändern. Die Regel „löschen nur, wenn das gespeicherte Token das benutzte ist“ (AC-14) fängt den Fall der veralteten 401 ab; alles Weitere gibt es erst, wenn jemand eine zweite Instanz baut.
- **Abbruch mitten in der Anmeldung:** Verbrauchte Nonce plus `CancellationError` bedeutet `signedOut`; die Oberfläche startet mit `beginSignIn` neu. Kein Zwischenzustand bleibt hängen.
- **Umfang:** ≈ 260 LoC an der Grenze (siehe Estimated Changes).

## Befunde gegen den Plan

- **F1:** Der Ablauf nach 90 Tagen zeigt sich erst beim nächsten Dienstaufruf als 401. `AccountState` beginnt nach dem Start deshalb als `signedIn`, auch wenn das Token längst serverseitig abgelaufen ist; erst `deleteAccount` (oder später die Abschrift in #795) deckt es auf. 4c darf nicht annehmen, die Anzeige „angemeldet“ sei geprüft.
- **F2:** `signOut` beendet die lokale Sitzung auch dann, wenn der Dienst nicht erreichbar ist; die serverseitige Sitzung läuft dann spätestens nach 90 Tagen ohne Nutzung ab (4a). Das ist gewollt (lokal zuerst) und kein Fehlerzustand.
- **F3:** Der ADR-21-Satz „bis dahin ruft die App den Dienst nirgends auf“ bleibt in 4b-2 wahr (keine Aufrufer); die Anpassung folgt in 4c.

## Test Plan

### Automated Tests (TDD RED)

RED: Alle Tests schlagen zunächst fehl, weil `AccountState`, `SessionStoring` und `InMemorySessionStore` nicht existieren (Test-Ziel baut nicht); das ist der erwartete Zustand vor `/50-implement`.
Die Gegenrichtungen bleiben auch nach der Implementierung Prüfungen: AC-2/AC-5/AC-11/AC-12 (nichts wird ohne Anmeldung gesendet), AC-14 (keine fremde Sitzung gelöscht), AC-15 (kein zweiter Request).

| Testname | AC |
|---|---|
| „account: start mit token“ | AC-1 |
| „account: start ohne token und bei lesefehler“ | AC-2 |
| „account: beginsignin nur aus erlaubten zustaenden“ | AC-3 |
| „account: body traegt rohe nonce zum hash“ | AC-4 |
| „account: completesignin ohne nonce und nonce einmalig“ | AC-5 |
| „account: anmelden speichert und ist angemeldet“ | AC-6 |
| „account: speicherfehler ergibt abgemeldet“ | AC-7 |
| „account: anmelden fehlerabbildung“ | AC-8 |
| „account: cancelsignin“ | AC-9 |
| „account: signout lokal zuerst dann dienst“ | AC-10 |
| „account: signout ohne token und bei loeschfehler“ | AC-11 |
| „account: konto loeschen erfolg und nur aus signedin“ | AC-12 |
| „account: konto loeschen fehlerabbildung“ | AC-13 |
| „account: veraltete 401 loescht keine neue sitzung“ | AC-14 |
| „account: doppelaufrufe waehrend anfrage“ | AC-15 |
| „account: zustand ohne token und nonce“ | AC-16 (Marker-Teil) |
| kein Test: Validierungsbeleg in `/60-validate` (`grep`, `git diff --name-only`, Funktionslängen) | AC-16 (grep-Teil), AC-17 |
| voller `./scripts/sim.sh sim-unit` und `./scripts/sim.sh build` | AC-18 |

- [ ] Test 1 (AC-1 bis AC-3): GIVEN eine Ablage mit, ohne und mit fehlschlagendem Lesen WHEN `AccountState` entsteht und `beginSignIn` in allen sechs Zuständen aufgerufen wird THEN Startstatus und null Anfragen, `beginSignIn` nur aus drei Zuständen mit 64-Hex-Rückgabe.
- [ ] Test 2 (AC-4 bis AC-9): GIVEN ein `FakeTransport` mit vorbereiteten Antworten WHEN die Anmeldung vollständig, ohne Nonce, mit Speicherfehler, mit jedem Fehlertyp und mit Abbruch läuft THEN genau die Zustände und Anfragen der Spec, Ablage nur im Erfolgsfall gefüllt.
- [ ] Test 3 (AC-10, AC-11): GIVEN ein Haken-Transport, der beim Eintreffen der Anfrage Ablage und Status liest WHEN `signOut` mit und ohne Token läuft THEN lokal zuerst gelöscht, danach genau eine Abmeldeanfrage mit Bearer; ohne Token null Anfragen.
- [ ] Test 4 (AC-12 bis AC-15): GIVEN Antworten 204, 401, 503, 500, 200 ohne Token, Abbruch, ein Tokenwechsel während der Anfrage und eine angehaltene Anfrage WHEN `deleteAccount` und die Doppelaufrufe laufen THEN die Tabelle der Spec, kein Löschen einer neueren Sitzung, keine zweite Anfrage.
- [ ] Test 5 (AC-16): GIVEN Marker `SECRET-TOKEN` in Token und Antwort WHEN alle Pfade durchlaufen sind THEN kein Zustandswert und kein Fehler enthält den Marker.

**Keine UI-Tests:** Der Kern hat keine Oberfläche und kein sichtbares Verhalten; nichts in der App ruft ihn auf. Ein UI-Test hätte nichts zu bedienen (wie in 4b-1). Die erste Oberfläche und ihr UI-Test gegen einen Ersatz-Dienst entstehen in 4c.

## Nicht in diesem Schnitt / Folgeschnitte

- **4b-3 (eigener Workflow im selben Issue):** `KeychainSessionStore` (generic password, Dienst `com.henning.looseends.session`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecUseDataProtectionKeychain` in jeder Abfrage, Duplikat → Update, NotFound beim Lesen = `nil`, beim Löschen = Erfolg) mit der `OSStatus`-Abbildung als reiner, getesteter Funktion, ≈ 90 LoC; `CLAUDE.md`-Eintrag `LooseEnds/Claude` um Ablage und Zustand ergänzt.
- **4c Einstellungen:** Gruppe „Konto“, `ASAuthorizationController`, Berechtigung „Mit Apple anmelden“ in `project.yml`, `LEServiceURL`/`LEAccountEnabled`, Texte de/en, Wahl der Ablage an einer Stelle (`forApp`, unter `--ui-testing` der Ersatz im Speicher), UI-Test gegen Ersatz-Dienst, Beleg der echten Schlüsselbund-Ablage im Simulator über die App; Entwurf der Gruppe vor der Spec (PO-Regel 2026-09-22); Stufe 3 über TestFlight.
- **4d Freigabe nach außen:** nginx genau `/auth/apple`, `/auth/logout`, `/auth/delete`, `APPLE_CLIENT_IDS`, Datenschutztext (Konto-Teil).
- **#795:** Abschrift hochladen mit dem Sitzungstoken aus der Ablage.

## Abnahme

- Stufe 1 Tests: neue Tests vorher rot (Ziel baut nicht), danach grün über `./scripts/sim.sh sim-unit AccountStateTests`, voller `./scripts/sim.sh sim-unit` grün.
- Stufe 2 Simulator: Kein sichtbarer Ablauf der App ändert sich; die App ruft `AccountState` und `SessionStoring` nicht auf (wie `OrderExecutor`, vgl. 4b-1). Beleg ist der Unit-Lauf im Simulator samt `./scripts/sim.sh build`, im Abschlussbericht benannt. Es gibt keinen Bedienablauf, der durchzuspielen wäre.
- Stufe 3 Gerät: keine. Kein Pfad der Geräteliste berührt (`LooseEnds/Claude/` steht nicht darin; kein `project.yml`, keine Entitlements, keine `Info.plist`).

## Definition of Done

- [ ] AC-1 bis AC-18 erfüllt; AC-1 bis AC-15 und der Marker-Teil von AC-16 als dauerhafte Tests, der grep-Teil von AC-16 sowie AC-17 und AC-18 als einmalige Belege im Validierungsprotokoll von `/60-validate` (kein dauerhafter Diff- oder grep-Test)
- [ ] `./scripts/sim.sh sim-unit` grün, `./scripts/sim.sh build` grün, CI auf dem PR grün
- [ ] Kein Pfad der Geräteliste berührt; Abnahme endet nach Stufe 2, im Abschlussbericht mit genau diesem Satz
- [ ] #615 kommentiert (Stand 4b-2: Ablage-Protokoll mit Ersatz und Kontozustand gebaut, nichts ruft sie auf; Folge 4b-3 Schlüsselbund), Board-Karte aktuell
- [ ] Abschlussbericht ohne Git-Vokabular: im Produkt ist nichts sichtbar, Henning muss nichts tun

## Changelog

- 2026-11-09: Initial spec created (Schnitt 4b-2, Teil-Spec)
