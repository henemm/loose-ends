# Adversary Dialog — feat-615-s4b-app-kern
Spec: docs/specs/feat-615-schnitt-4b1-dienst-client.md
Datum: 2026-11-09 07:04

## Checkliste
- [x] **AC-1:** Nonce-Testvektor: `Nonce.hash("abc")` ist `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`; `Nonce(raw: "abc").hashed` ist derselbe Wert; das Ergebnis hat 64 Zeichen, nur `0-9a-f`. Ein zweiter Vektor mit Nicht-ASCII-Zeichen (`"äö"`) belegt, dass über die UTF-8-Bytes des Strings gehasht wird (erwarteter Wert fest im Test, einmal mit `shasum -a 256` auf dem UTF-8-Text berechnet und im Test kommentiert). Test: „nonce: hash testvektoren“.
- [x] **AC-2:** Zufall und Form: `Nonce()` liefert `raw` mit 43 Zeichen aus `[A-Za-z0-9_-]`, ohne `=`; die Rückkodierung (base64url → 32 Byte) ergibt genau 32 Byte; zwei Aufrufe liefern verschiedene `raw`; `hashed` ist `Nonce.hash(raw)`. Test: „nonce: roher wert 32 byte base64url und verschieden“.
- [x] **AC-3:** Erzeugen sendet nichts: Nach `ServiceClient(baseURL:transport:)` und ohne weiteren Aufruf hat der `FakeTransport` null Anfragen; ebenso nach dem Erzeugen von `Nonce()`. Test: „serviceclient: erzeugen sendet nichts“.
- [x] **AC-4:** Draht-Vertrag `signIn`: Genau eine Anfrage, Methode `POST`, Pfad `/auth/apple` (auch mit und ohne Schrägstrich am Ende der Dienst-Adresse und mit einem Pfadpräfix in der Adresse, z. B. `https://example.test/api` → `/api/auth/apple`), Header `Content-Type: application/json`, kein `Authorization`-Header, Body als JSON-Objekt mit genau den Schlüsseln `identityToken`, `nonce`, `code` und den übergebenen Werten (Schlüsselmenge wird geprüft, nicht nur Werte). Bei 200 mit `{"sessionToken":"abc123"}` ist das Ergebnis `"abc123"`. Test: „serviceclient: signin draht-vertrag“.
- [x] **AC-5:** Antwort von `signIn`: 200 mit leerem `sessionToken`, fehlendem Schlüssel, `sessionToken` kein String, JSON-Array statt Objekt und kaputtem JSON liefert je `ServiceError.invalidResponse` (tabellengetrieben). Test: „serviceclient: signin ungueltige antwort“.
- [x] **AC-6:** Draht-Vertrag `logout` und `deleteAccount`: je genau eine Anfrage, Methode `POST`, Pfad `/auth/logout` bzw. `/auth/delete`, Header `Authorization: Bearer <token>` (Wert genau `Bearer ` plus Token), kein Body (`httpBody == nil`), kein `Content-Type`; Antwort 204 ergibt Erfolg ohne Rückgabewert. Test: „serviceclient: logout und delete draht-vertrag“.
- [x] **AC-7:** Statusabbildung je Route (tabellengetrieben über Route und Status): 401 → `unauthorized`; 503 → `unavailable`; 400, 405, 413, 415, 500 → `rejected(<Status>)`; bei `signIn` zusätzlich 204 → `rejected(204)`, bei `logout`/`deleteAccount` zusätzlich 200 → `rejected(200)` (Erfolg ist genau der Status der Route). Test: „serviceclient: statusabbildung je route“.
- [x] **AC-8:** Transportfehler: `URLError(.notConnectedToInternet)`, `URLError(.timedOut)` und `URLError(.cannotConnectToHost)` aus dem Transport ergeben je Route `ServiceError.unavailable`; ein `CancellationError` wird unverändert weitergereicht (nicht in `unavailable` umgedeutet). Test: „serviceclient: transportfehler“.
- [x] **AC-9:** Keine Preisgabe: Der Wert jedes `ServiceError` aus AC-5 bis AC-8 enthält weder das übergebene Token noch den Antwortkörper (Test setzt erkennbare Marker wie `"SECRET-TOKEN"` ein und prüft, dass `String(describing: error)` sie nicht enthält); der Client ruft `Logger` und `print` nirgends auf (Beleg: `grep -nE 'Logger|print\(' LooseEnds/Claude/Nonce.swift LooseEnds/Claude/ServiceClient.swift` ohne Treffer, einmalig in `/60-validate` im Protokoll, kein dauerhafter Test). Test: „serviceclient: fehler ohne token und koerper“.
- [x] **AC-10:** Grenze, Länge, Doku: Die neuen Dateien liegen unter `LooseEnds/Claude/` und `LooseEndsTests/`; `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `LooseEnds/Claude/Nonce.swift`, `LooseEnds/Claude/ServiceClient.swift`, `LooseEndsTests/ServiceClientTests.swift` und `CLAUDE.md` (kein `project.yml`, keine Entitlements, keine `Info.plist`, keine Datei unter `Shared/` oder `server/`); keine Funktion über 50 Zeilen. Der Abschnitt „Where things live“ in `CLAUDE.md` bekommt einen Eintrag `LooseEnds/Claude` mit einem Halbsatz je Typ (`Nonce`: roher Wert 32 Byte base64url, `hashed` = SHA-256 Hex klein; `ServiceClient`: die drei Routen über `HTTPTransport`, `ServiceError`, kein Token im Fehler; nichts in der App ruft den Kern auf, #615 S4b-1). Beleg: einmalig in `/60-validate` im Validierungsprotokoll (`git diff --name-only`, Zählung der Funktionslängen, `grep -n 'LooseEnds/Claude' CLAUDE.md` mit genau einem Treffer im Abschnitt „Where things live“); kein Test gegen `origin/main`.
- [x] **AC-11:** Regression: `./scripts/sim.sh sim-unit` (alle Unit-Tests) ist grün; `./scripts/sim.sh build` baut die App mit dem neuen Ordner (nach `generate`) ohne Fehler und ohne neue Warnungen aus den neuen Dateien. Beleg: Lauf im Validierungsprotokoll.

## Dialog

### Runde 1
**Adversary:** Gegen den Server-Vertrag gelesen (server/src/auth.ts parseLogin Z.53-61, bearerToken Z.23, isJson Z.28; apple.ts Z.75: SHA-256 hex des Roh-Nonce).
Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Claude/Nonce.swift:32
  Evidence: SHA256 ueber Data(raw.utf8), "%02x" = Hex klein; Test-Vektoren "abc" und "aeoe" (UTF-8) fest.
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Claude/Nonce.swift:19
  Evidence: 32 Byte SecRandomCopyBytes, Fehler wirft (Z.18), base64url ohne '=' (Z.19-22) = 43 Zeichen; Test prueft Alphabet, Rueckdekodierung 32 Byte, Verschiedenheit.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Claude/ServiceClient.swift:32
  Evidence: init speichert nur; Test zaehlt 0 Requests.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Claude/ServiceClient.swift:39
  Evidence: appending(path:) ergibt kein '//' (Test mit/ohne Slash/Praefix /api), Body genau drei Schluessel (Test vergleicht Dictionary), Content-Type json, kein Authorization; passt zu parseLogin.
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Claude/ServiceClient.swift:52
  Evidence: leerer/fehlender/Nicht-String-Token, Array, kaputtes JSON -> invalidResponse (5 Tabellenfaelle).
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Claude/ServiceClient.swift:76
  Evidence: nur Authorization "Bearer <token>", httpBody nil, kein Content-Type (Test Z.102 erzwingt), Erfolg genau 204 (Z.60, Z.65).
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Claude/ServiceClient.swift:92
  Evidence: switch success/401/503/default rejected(code); Tabelle ueber 3 Routen x 8 Status inkl. 204 bei signIn bzw. 200 bei logout/delete (ServiceClientTests.swift:105).
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Claude/ServiceClient.swift:89
  Evidence: catch is URLError -> unavailable, CancellationError nicht gefangen, Test Z.117-125.
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Claude/ServiceClient.swift:20
  Evidence: ServiceError traegt nur Int; grep 'Logger|print|try?' ueber beide Dateien: kein Treffer.
  Status: CONFIRMED
Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Claude/Nonce.swift:11
  Evidence: Diff-Namensliste gegen origin/main (ohne docs/.claude) = genau CLAUDE.md, Nonce.swift, ServiceClient.swift, ServiceClientTests.swift; laengste Funktion signIn 19 Zeilen; grep 'LooseEnds/Claude' CLAUDE.md = ein Treffer (Z.446, Where things live).
  Status: CONFIRMED
Confirmation:
  AC: Testabdeckung
  Code reference: LooseEndsTests/ServiceClientTests.swift:83
  Evidence: Tests erzwingen Schluesselmenge, Header-Abwesenheit, Statustabelle (nicht nur Existenz).
  Status: CONFIRMED
Eigener Lauf: sim-unit ServiceClientTests gruen (xcresult: 43 Faelle bestanden, 0 fehlgeschlagen, 0 uebersprungen; Log zeigt parametrisierte Tests nicht einzeln). AC-11: voller Lauf in test-green-output.txt: Test Succeeded, Unit-Tests bestanden; Messstrecken 3 von 6 uebersprungen einzeln benannt (RawSentenceReportTests, SelfConsistencyReportTests, TextFormModelReportTests) plus 2 Latenz-Messungen "nicht gemessen"; die Zahl 1228/13 habe ich nicht nachgezaehlt; keine Warnung aus Claude/ im Log.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Claude/ServiceClient.swift:89
  Description: `catch is URLError` bildet jeden URLError auf unavailable ab. Ein echtes URLSession-Task-Cancel wirft URLError(.cancelled), nicht CancellationError, und wird daher zu unavailable.
  Spec requirement: AC-8 — nur CancellationError aus dem Transport wird durchgereicht; URLError.cancelled ist nicht gefordert.
  Conflict: Kein Verstoss gegen den Wortlaut; spaeterer Aufrufer (4b-2) koennte Abbruch als Ausfall melden.
  Remediation: In 4b-2 beim Aufrufer beachten oder URLError.cancelled auf CancellationError abbilden.

Finding:
  ID: F002
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsTests/ServiceClientTests.swift:133
  Description: `do { try await call } catch { ... }` im Test errorsCarryNoSecrets besteht auch, wenn gar nichts geworfen wird.
  Spec requirement: AC-9 — Marker duerfen nicht im Fehlerwert stehen.
  Conflict: Schwache Behauptung; praktisch ist jeder Fall durch AC-5/7/8-Tests als Wurf festgenagelt, daher kein Defekt.
  Remediation: Optional Issue.record nach dem try.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsTests/ServiceClientTests.swift:1
  Description: Code+Test 275 LoC (diff --stat gegen origin/main, ohne docs), Ziel 250.
  Spec requirement: Spec verlangt nur Nennung mit Zahl.
  Conflict: Kein Defekt; Zahl hiermit genannt.
  Remediation: Keine.
**Implementierer:** (nicht beteiligt; Adversary-Lauf ohne Rueckfrage)

### Runde 2
**Adversary:** Zweiter, gezielter Bruchversuch. (a) Nonce-Hash: Server nutzt createHash("sha256").update(string) = UTF-8, Hex klein; Swift identisch. (b) Pfad: baseURL mit Praefix und Slash ergibt kein '//' (Testfaelle gruen). (c) signIn sendet zusaetzlich Accept-Header: serverseitig irrelevant (isJson prueft nur Content-Type, auth.ts Z.28). (d) logout/delete ohne Body: Server liest dort keinen Body; Erfolg 204 stimmt (auth.ts Z.101). (e) Token mit Leerzeichen im Bearer-Header: Aufrufer-Sache, Server antwortet 401 -> unauthorized. (f) Swift 6: Nonce, ServiceClient, ServiceError Sendable, HTTPTransport: Sendable; keine Warnung aus Claude/ im Log. (g) Fehlerwerte: ServiceError traegt nur Int. (h) Timeout 15 s, ephemere Session: kein Cookie/Cache. (i) Nonce() bei SecRandom-Fehler wirft, kein schwacher Wert. Nichts gebrochen; nur F001-F003 (LOW).
**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)


## Verdict

VERDICT: VERIFIED

Tests: ServiceClientTests 43 Faelle bestanden, 0 fehlgeschlagen; voller Lauf gruen, 3 Messstrecken einzeln benannt uebersprungen.
Checklist: 11/11 points proven. Findings F001-F003 nur LOW.

## Geprüfte Dateien

- sha256:764b7f50e69da8b2d54bdb3c68c50a321174fe253baf868cb60b66977f333a57  LooseEnds/Claude/Nonce.swift
- sha256:e53b10b2da3ea550c87e6a0b7d218e377aa92fc16389d8f65c4b48cfbd7e8894  LooseEnds/Claude/ServiceClient.swift
- sha256:14041d30cc2a7d1976b3b9fc681062e90834f57ae66cb367c0b3d8f6dc66cf84  LooseEndsTests/ServiceClientTests.swift

## Prüfbasis

- base: f034db319b4d8575977fe5099df3632ce038215a
- blob:809e041a37914e6762db049e290aa6a105739440  LooseEnds/Claude/Nonce.swift
- blob:8d4f810b64fb02db08ed07b363ff922911423b75  LooseEnds/Claude/ServiceClient.swift
- blob:8f789e6af7ef25367ea61ec02384425181a871dc  LooseEndsTests/ServiceClientTests.swift
