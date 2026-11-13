# Context: feat-795-s3b2-debug-weg (#795 Schnitt S3b-2)

## Request Summary

Der Durchgang `ClaudeSync` (S3a) und seine Auslöser (S3b-1) laufen bisher nur gegen Stellvertreter. S3b-2 schließt die Kette
gegen einen echten, lokal laufenden Dienst: ein Debug-Weg schaltet im Simulator Konto, lokale Adresse und Sitzung ohne
Apple-Anmeldung ein, ein Skript startet den Dienst samt Konto, Sitzung und Auftrag, und zwei Simulatoren liefern den Nachweis A/B
aus der DoD von #795. Verbindlicher Ausgangspunkt: Abschnitt „Schnitt“ in `docs/context/feat-795-s3b-ausloeser.md` und
„Folgeschnitte“ in `docs/specs/feat-795-schnitt-3b1-ausloeser.md` (Z. 186).

## Related Files

| File | Relevance |
|------|-----------|
| `LooseEnds/Claude/AccountWiring.swift` (125) | `isEnabled` (nur `--ui-testing` oder Info `LEAccountEnabled`), `serviceURL(info:allowsLocalHTTP:)` (http nur `localhost`/`127.0.0.1` im Debug), `forApp` (unter `--ui-testing` `InMemorySessionStore` + `UITestTransport`, sonst `KeychainSessionStore`). Hier kommt der Debug-Weg hin (nur `#if DEBUG`) |
| `LooseEnds/Claude/AccountState.swift` | `init(client:store:)` setzt `signedIn`, wenn der Store einen Token hält → `InMemorySessionStore(token:)` genügt für eine Sitzung ohne Apple |
| `LooseEnds/Claude/SessionStore.swift` | `InMemorySessionStore(token: String? = nil)` |
| `LooseEnds/Claude/ClaudeSyncTrigger.swift` | `forApp(... silent: isRunningTests \|\| isUITesting)` → unter `--ui-testing` stumm. **Der Debug-Lauf darf daher nicht `--ui-testing` tragen**, sonst sendet nichts |
| `LooseEnds/App/LooseEndsApp.swift` Z. 61–64 | `account = AccountWiring.forApp(info:arguments:)`, dann Trigger nur mit Konto; keine Änderung nötig, wenn `forApp` den Debug-Weg kennt |
| `LooseEndsTests/AccountSectionTests.swift` | einzige Testdatei, die `AccountWiring` prüft (`isEnabled`, `serviceURL`); eine eigene `AccountWiringTests.swift` gibt es nicht (die Planung von S3b nannte sie fälschlich als MODIFY) |
| `server/scripts/test-local.sh` | Muster: Wegwerf-Postgres 18 (initdb, freier Port, nur TCP, `trap cleanup`) |
| `server/src/main.ts` Z. 266, 294 | `DATABASE_URL` Pflicht, `PORT` (Standard 8080), `HOST` (Standard 127.0.0.1); ohne `APPLE_*` läuft er (`/auth/apple` 503), App-Wege laufen; ohne OAuth-Schlüssel `/mcp` auf `rejectAll` |
| `server/src/accounts.ts` | `findOrCreate(pool, appleSub)` (Test-Helfer), `createSession(pool, accountId)` → Rohtoken |
| `server/src/orders.ts` | `putOrder(pool, account, doc)`, `getResult(pool, account, orderID)`; Arten `capture`, `complete`, `setDue`, `setNext`, `park`, `addSubtask` |
| `server/src/transcripts.ts` | `getTranscript(pool, account)` → Abschrift von A lesbar |
| `scripts/sim.sh` `cmd_launch` (Z. 729) | reicht Startargumente an `simctl launch` durch; `LOOSEENDS_SIM` wählt den Simulator per Name → zwei Simulatoren für A und B |

## Existing Patterns

- Debug-only Startargumente: `-LEInitializeCloudKitSchema` (`#if DEBUG`, `CloudKitSchemaInitializer.shouldRun`).
- Adressregel `serviceURL` (#615 S4c-2b): http nur auf `localhost`/`127.0.0.1` und nur im Debug-Bau; wiederverwenden statt neu prüfen.
- Testbare reine Funktionen mit `info`/`arguments` als Parameter (`isEnabled`, `serviceURL`).
- Server-Skripte in Bash mit `set -euo pipefail` und Aufräumen per `trap`; TypeScript läuft direkt mit Node 26 (keine Build-Stufe).

## Dependencies

- Upstream: `ClaudeSync`, `ClaudeSyncTrigger` (S3a/S3b-1, auf main), `AccountState`, `InMemorySessionStore`, `DeviceIdentity`, `ServiceClient`;
  Server: `accounts.ts`, `orders.ts`, `transcripts.ts`, `migrate.ts`, `main.ts`.
- Downstream: S5 (Weckruf, Hintergrund-Auffrischen) nutzt denselben lokalen Weg für seine Nachweise; #625 (Store-Schalter).

## Existing Specs

- `docs/specs/feat-795-schnitt-3b1-ausloeser.md` — Auslöser; benennt S3b-2 als Folgeschnitt.
- `docs/specs/feat-795-schnitt-3a-claude-sync.md` — Durchgang, Ausgänge.
- `docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md` — Adressregel.
- `docs/reference/claude-abschrift-vertrag.md` — Vertrag „Wege der App“.

## Risks & Considerations

- **ATS:** laut Recherche aus S3b (Apple, `NSAllowsLocalNetworking`: seit iOS 17 keine IP-Adressen ohne Ausnahme) nur
  `http://localhost:<port>`, nie `127.0.0.1`. Erster Schritt der Analyse: im Simulator nachstellen, dass eine Anfrage ankommt.
  Scheitert das, neu entscheiden — eine ATS-Ausnahme in der `Info.plist` wäre ein Pfad der Geräteliste.
- **Nie im Release:** Der Debug-Weg muss in jedem Release-Bau wirkungslos sein (`#if DEBUG`, Test über `allowsLocalHTTP`-artigen Parameter).
- **`--ui-testing` macht den Trigger stumm:** Der Nachweis läuft ohne `--ui-testing`, also mit dem echten Simulator-Store der App.
- **Zwei Simulatoren, getrennte Daten:** Ohne iCloud-Anmeldung teilen A und B keinen Bestand. Ein `complete`-Auftrag auf eine Aufgabe von A
  liefe auf B in `missing`. Der Nachweis nutzt daher `capture` (B erfasst, Revision „Claude“) oder bezieht die Aufgabe aus B's eigener
  Abschrift; in der Analyse festlegen. Beide teilen dieselbe Sitzung (ein Konto), aber verschiedene Gerätekennungen.
- **Sitzung im Startargument** steht im Prozessaufruf; im Debug-Simulator gegen Wegwerf-Datenbank unkritisch, aber nie gegen den Live-Dienst
  (Adressregel lässt https zu → Debug-Argument muss auf localhost beschränkt bleiben oder bewusst nur lokal gelten).
- **Testsperre:** `launch` holt `/tmp/loose-ends-testlauf.lock`; zwei Simulatoren nacheinander starten.
- **Umfang:** geplant ~4 Dateien/~220 LoC (`AccountWiring.swift`, `AccountSectionTests.swift` oder neue Testdatei, `server/scripts/local-service.sh`,
  `server/scripts/local-fixture.ts`); innerhalb der Grenze.
- **Gerätestufe:** kein Pfad der Geräteliste (`LooseEnds/Claude/`, `LooseEndsTests/`, `server/scripts/`).

## Analysis

### Type
Feature (Entwicklerweg und Nachweis; für den Nutzer ändert sich nichts Sichtbares).

### Recherche und Nachstellen (2026-11-13)
- Apple, `NSAllowsLocalNetworking` (developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking):
  seit iOS 10 erlaubt ATS unqualifizierte Namen (`localhost`), `.local` und IP-Adressen ohne Ausnahme; seit iOS 17 keine IP-Adressen mehr
  ohne Eintrag in `NSExceptionDomains`.
- Nachgestellt im iOS-27-Simulator (iPhone 17) mit einem Wegwerf-Test im Unit-Host (Info.plist der App, keine ATS-Schlüssel), Server
  `python3 -m http.server` an `127.0.0.1:58795`: `http://localhost:58795/health -> 200`, `http://127.0.0.1:58795/health -> 200`.
  Loopback ist im Simulator also auch per IP offen; wir bleiben trotzdem bei `localhost` (Doku-konform, gilt auch, falls ein späteres
  OS die Loopback-IP sperrt). Keine `Info.plist`-Änderung nötig → kein Pfad der Geräteliste. Probe danach gelöscht.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Claude/AccountWiring.swift` | MODIFY (~40) | Reine Funktion `debugService(arguments:debugBuild:) -> (url, token)?`: nur im Debug-Bau, nur wenn beide Argumente `-LEDebugService <url>` und `-LEDebugSession <token>` da sind, nur `http://localhost:<port>` (sonst nil, also nie gegen den Live-Dienst und nie mit https-Fremdadresse). `isEnabled` wird damit auch ohne `LEAccountEnabled` wahr; `forApp` baut dann `AccountState` mit echtem `ServiceClient(baseURL:)` (URLSession) und `InMemorySessionStore(token:)` — kein Schlüsselbund-Eintrag, kein `--ui-testing` (sonst ist der Auslöser stumm). |
| `LooseEndsTests/AccountSectionTests.swift` | MODIFY (~60) | Debug-Argumente: beide da → Adresse + Sitzung; eins fehlt, https, `127.0.0.1`, fremder Host, leerer Token → nil; `debugBuild: false` → nil und `isEnabled` bleibt aus (Release-Fall). `forApp` mit Argumenten → `signedIn`. |
| `server/scripts/local-service.sh` | CREATE (~70) | Wegwerf-Postgres (Muster `test-local.sh`), `node src/main.ts` an `127.0.0.1:<port>` ohne `APPLE_*`/OAuth, schreibt `DATABASE_URL`, `PORT`, Sitzung in eine Zustandsdatei im Temp-Ordner, läuft bis Strg-C/Signal, räumt immer auf. |
| `server/scripts/local-fixture.ts` | CREATE (~70) | Unterbefehle gegen dieselbe Datenbank über die vorhandenen Funktionen: `session` (`findOrCreate` + `createSession`, Token ausgeben), `transcript` (`getTranscript`, Anzahl Aufgaben und Titel), `order <text>` (`putOrder` `capture` mit neuer UUID, id ausgeben), `result <id>` (`getResult`). |

Doku (zählt nicht zum Dateilimit): Beleg unter `docs/artifacts/feat-795-s3b2-debug-weg/` (Protokoll des A/B-Laufs, Screenshots), eine Zeile in `CLAUDE.md` (Abschnitt `LooseEnds/Claude`, Build-Liste um `local-service.sh`).

### Scope Assessment
- Files: 4 Code-/Testdateien
- Estimated LoC: ≈ +240/-5
- Risk Level: LOW — der neue Weg existiert nur im Debug-Bau und nur mit zwei ausdrücklichen Startargumenten auf `localhost`; Release-Bauten und Henning's TestFlight-App bleiben unberührt (Unit-Test mit `debugBuild: false`). Kein Pfad der Geräteliste.

### Technical Approach
Nachweis A/B, deterministisch, weil der Dienst einen Auftrag dem ersten Gerät gibt, das holt (`claimOrder` ohne Gerätebindung):
1. `local-service.sh` starten; `local-fixture.ts session` → Token.
2. Simulator A (`LOOSEENDS_SIM="iPhone 17"`) ohne `--ui-testing` mit `-LEDebugService http://localhost:<port> -LEDebugSession <token>` starten, eine Aufgabe erfassen; Start/`didSave` senden die Abschrift. `local-fixture.ts transcript` zeigt A's Aufgabe. A beenden (`simctl terminate`).
3. Erst jetzt `local-fixture.ts order "<Text>"` (Art `capture`: A und B teilen ohne iCloud keinen Bestand, ein `complete` auf A's Aufgabe liefe auf B in `missing`).
4. Simulator B (`LOOSEENDS_SIM="iPhone Air"` o. ä., eigene Gerätekennung) mit denselben Argumenten starten → holt, führt aus, meldet. `local-fixture.ts result <id>` → `done` mit `taskID`; B's neue Abschrift enthält die Aufgabe.
5. Revision „Claude“ auf B belegen: B's Store im Simulator-Datencontainer nur lesend (`sqlite3 -readonly`, `ZREVISION`), plus Screenshot der Aufgabe auf B.
Beide Simulatoren teilen eine Sitzung (ein Konto), haben aber verschiedene `X-Device`-Kennungen.

### Alternativen
- **Debug-Einstellungsseite** (Adresse und Sitzung in der App eintippen): sichtbare UI, braucht Entwurf und UI-Test, für einen reinen Entwicklerweg zu viel; verworfen.
- **Nachweis gegen den Live-Dienst mit echter Apple-Anmeldung über TestFlight**: belegt den echten Pfad inkl. nginx, braucht aber Hennings Gerät und Konto pro Lauf; bleibt Stufe 3 von S5 (DoD #795). Keine ADR fällt.
- **`127.0.0.1` statt `localhost`**: funktioniert im Simulator heute, widerspricht aber Apples Doku seit iOS 17; verworfen.
- **Sitzung über Umgebungsvariable (`SIMCTL_CHILD_…`) statt Startargument**: hält den Token aus der Prozessliste, aber `sim.sh launch` reicht nur Argumente durch; gegen eine Wegwerf-Datenbank unkritisch. Verworfen für jetzt.
- Keine ADR betroffen; ADR-21 (Weg B) bleibt.

### Dependencies
`ClaudeSync`/`ClaudeSyncTrigger` (S3a/S3b-1, auf main), `AccountState(client:store:)`, `InMemorySessionStore(token:)`, `ServiceClient`, `DeviceIdentity`, `OrderExecutor`; Server `accounts.ts`, `orders.ts`, `transcripts.ts`, `main.ts` unverändert.

### Open Questions
- keine PO-Frage (rein technischer Schnitt, nichts Sichtbares). Abnahme: „Kein Pfad der Geräteliste berührt.“
