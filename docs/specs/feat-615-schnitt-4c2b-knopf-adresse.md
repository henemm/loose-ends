---
entity_id: feat-615-schnitt-4c2b-knopf-adresse
type: feature
created: 2026-11-10
updated: 2026-11-10
status: draft
workflow: feat-615-s4c2b-knopf-adresse
---

# Spec: Apple-Knopf bleibt während der Anmeldung stehen, Dienst-Adresse nur über https, Schnitt 4c-2b (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Teil-Spec für Schnitt 4c-2b; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s4c2b-knopf-adresse.md` (Abschnitte „Recherche“, „Affected Files“, „Technical Approach“, „Alternativen“ sind verbindlich).
Vorgänger: 4c-1 (`docs/specs/feat-615-schnitt-4c1-konto-gruppe.md`, PR #889), 4c-2a (`docs/specs/feat-615-schnitt-4c2a-freischalten.md`, PR #892).
Befund F001: `docs/artifacts/feat-615-s4c-konto/adversary-dialog.md:35`. F002 stammt aus derselben Prüfung. Beide wurden in 4c-2a ausdrücklich an 4c-2b verwiesen.
Diese Spec deckt nur 4c-2b ab. Folgeschnitte siehe „Nicht in diesem Schnitt“.

## Für den PO

Die Gruppe „Claude“ ist in jedem echten Bau ausgeschaltet; du siehst von diesem Schnitt in deiner App nichts. Er macht zwei Dinge sicherer,
bevor der Dienst für die App geöffnet wird: Beim Anmelden bleibt der Apple-Knopf grau stehen, statt zu verschwinden (so kann Apples
Anmeldefenster seine Antwort nicht verlieren, und ein zweites Tippen ist unmöglich). Und die App akzeptiert als Dienst-Adresse nur noch
eine verschlüsselte (https); eine unverschlüsselte gilt nur auf dem eigenen Rechner im Entwicklungsbau. **Du musst nichts tun.**

## Purpose

Zwei kleine, getrennt prüfbare Bausteine aus den Restbefunden von 4c-1/4c-2a:

- **F001:** In `signingIn` verschwindet heute der `SignInWithAppleButton`, obwohl er das laufende Apple-Fenster hält. Es gibt keinen Beleg,
  dass `onCompletion` eines aus der Hierarchie entfernten Knopfes zuverlässig ankommt; Fallberichte zeigen Ausfälle (Recherche unten).
  Der Knopf bleibt deshalb in der Hierarchie, sichtbar und deaktiviert; die Fortschrittszeile steht darunter. Ein deaktivierter Knopf
  ruft `onRequest` nicht auf, also kein zweites `beginSignIn` und kein Apple-Fenster ohne Nonce.
- **F002:** `AccountWiring.serviceURL` nimmt heute auch `http`. Künftig nur `https` mit Host; `http` höchstens für `localhost` und
  `127.0.0.1` und nur, wenn der Aufrufer es freigibt (Standard: Debug-Bau). Alles andere fällt auf `https://loose-ends.henemm.com`
  zurück. Regel wie auf der Serverseite (`publicUrlFromEnv` in `server/src/oauth-resource.ts`).

**Regeln vor Modell:** reine App- und Regelarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue — folgt ADR-21 (Weg B: nichts verlässt das Gerät ohne Tippen) und 4c-1 („Apples eigener Knopf“); keine neue Abhängigkeit.
- **Rationale:** (1) Die Abbildung Status → Zeilen bleibt die eine Quelle (`AccountSection.layout`), deshalb ein neues Feld `appleButtonEnabled`
  statt Sonderlogik in der View. (2) Deaktivieren statt Entfernen ist der sichere Weg, der den Simulator-Beleg nicht braucht: Das Apple-Fenster
  läuft unter `--ui-testing` nicht, ob Entfernen dort schadet, ist nicht belegbar. (3) `deleting` bleibt unverändert (Knopf weg): dort gibt
  es keinen Apple-Dialog, der etwas halten müsste. (4) Die Freigabe von lokalem `http` ist ein Parameter (`allowsLocalHTTP`), nicht nur ein
  `#if DEBUG` im Rumpf, damit der Unit-Test, der im Debug-Bau läuft, beide Zweige prüfen kann; der Standardwert `#if DEBUG` hält Release-Bauten
  fail-closed. (5) `LEServiceURL` steht in keinem echten Bau (`project.yml` setzt ihn nicht), also ändert F002 für echte Bauten nichts Sichtbares.
- **Alternativen (verworfen):**
  - **Knopf entfernen wie bisher, `onCompletion` über einen eigenen `ASAuthorizationController`** (Delegate außerhalb der View): robust gegen
    Entfernen, aber eigener Controller statt Apples SwiftUI-Knopf, mehr Code und kippt die Entscheidung aus 4c-1 („Apples eigener Knopf“).
    Ohne Nutzen gegenüber Deaktivieren, daher verworfen. Würde gewählt, wenn sich zeigt, dass auch ein deaktivierter Knopf `onCompletion` verliert.
  - **Fortschritt als Überlagerung im Knopf** (`ProgressView` als Overlay) statt eigener Zeile: optisch neu, bräuchte einen Entwurf; verworfen für diesen Schnitt.
  - **`LEServiceURL` ganz streichen, nur Konstante:** kippt den lokalen Prüfweg (Debug gegen einen lokalen Server); verworfen.
  - **Nur `https` ohne jede http-Ausnahme:** einfacher, aber nähme dem Debug-Bau den Weg gegen `localhost`; die Serverseite lässt ihn aus demselben Grund offen.

## Recherche (2026-11-10, Quellen)

- `onCompletion` bei entferntem oder in einem Modal sitzenden `SignInWithAppleButton`: Completion feuert nie, wenn der Knopf in einem eigenen
  Modal sitzt (https://developer.apple.com/forums/thread/698652, https://developer.apple.com/forums/thread/656784); Präsentation „from a SwiftUI
  view not in a hierarchy“ führt zum Absturz (https://developer.apple.com/forums/thread/710183). Ein positiver Beleg für das Entfernen fehlt.
- Vorbild Adressregel: `publicUrlFromEnv` in `server/src/oauth-resource.ts` (https; http nur `localhost`/`127.0.0.1`).
- **Entwurf-vor-Spec entfällt begründet:** kein neu gestalteter Screen, kein neues Element; der in Entwurf A (4c) freigegebene Knopf bleibt
  während der ein bis zwei Sekunden der Anmeldung grau stehen, statt zu verschwinden. Die Fortschrittszeile besteht schon.

## Source

**Files (MODIFY):** `LooseEnds/Views/AccountSection.swift`, `LooseEnds/Claude/AccountWiring.swift`, `LooseEndsTests/AccountSectionTests.swift`, `LooseEndsUITests/AccountSettingsTests.swift`
**Identifier:** `AccountSection.Layout.appleButtonEnabled`, `AccountWiring.serviceURL(info:allowsLocalHTTP:)`, `UITestTransport.delay`, Startargument `--ui-testing-account-slow`

### 1. `AccountSection.swift` (F001)

- `Layout` bekommt `let appleButtonEnabled: Bool`. Neue Tabelle (ändert die Tabelle aus 4c-1, Abschnitt „`AccountSection.Layout`“):

| Status | Apple-Knopf sichtbar | Knopf bedienbar | Fortschritt | Angemeldet-Zeilen | Hinweis |
|---|---|---|---|---|---|
| `signedOut` | ja | ja | nein | nein | `intro` |
| `signingIn` | **ja** | **nein** | ja („Signing in …“) | nein | `intro` |
| `signedIn`, ohne Problem | nein | nein | nein | ja | `signedIn` |
| `signedIn`, Problem `retryLater` | nein | nein | nein | ja | `retryLater` |
| `deleting` | nein | nein | ja („Deleting account …“) | nein | `signedIn` |
| `notAllowed` | ja | ja | nein | nein | `notAllowed` |
| `retryLater` | ja | ja | nein | nein | `retryLater` |

- Kein Knopf, wo `showsAppleButton` falsch ist; dort ist `appleButtonEnabled` ebenfalls falsch.
- `body`: Knopf-Zeile und Fortschrittszeile können gleichzeitig stehen; die Reihenfolge ist Knopf, dann Fortschritt.
- `appleButton`: `.disabled(!layout.appleButtonEnabled)` an **beiden** Varianten (Apples `SignInWithAppleButton` und der einfache Knopf unter `--ui-testing`); der Wert wird an `signInRow`/`appleButton` durchgereicht.
- Keine neuen Texte, keine neuen Katalogschlüssel.

### 2. `AccountWiring.swift` (F002 und UI-Test-Hilfe)

- `static func serviceURL(info: [String: Any]?, allowsLocalHTTP: Bool = AccountWiring.debugBuild) -> URL` mit `private static let debugBuild: Bool`, im Rumpf per `#if DEBUG` auf `true`, sonst `false` gesetzt. Regel:
  - `https` (Schema ohne Rücksicht auf Groß-/Kleinschreibung) mit nicht leerem Host → angenommen;
  - `http` → angenommen nur, wenn der Host `localhost` oder `127.0.0.1` ist **und** `allowsLocalHTTP` wahr ist;
  - alles andere (anderes Schema, kein Host, nicht lesbar, fehlt, falscher Typ, leer) → `fallbackURL`.
- `forApp` ruft `serviceURL(info:)` mit dem Standard; Verhalten sonst unverändert.
- `UITestTransport` bekommt `let delay: Duration` (Standard `.zero`), gesetzt aus dem Startargument `--ui-testing-account-slow` auf 15 Sekunden; `send` wartet vor der Antwort `try await Task.sleep(for: delay)`, wenn `delay > .zero`. Die Ausgänge (`allowed`, `notAllowed`, `retryLater`) bleiben unverändert; `slow` ist unabhängig kombinierbar. Ohne das Argument antwortet der Ersatz wie bisher sofort.

### 3. Tests

Siehe Acceptance Criteria und Test Plan; keine Quelländerungen sonst.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `AccountState.beginSignIn` (nur aus `signedOut`/`notAllowed`/`retryLater`, sonst `notPossibleNow`), `cancelSignIn` (nur in `signingIn`) | unverändert |
| `SignInWithAppleButton` (AuthenticationServices) | Hierarchie-Verhalten, siehe Recherche |
| Info-Wörterbuch (`LEServiceURL`, `LEAccountEnabled`) | unverändert; `LEServiceURL` steht in keinem echten Bau |
| `SettingsView` (Gruppe „Claude“), `LooseEndsApp`/Mac-Einstellungsfenster über `AccountWiring.forApp` | unverändert |
| `server/src/oauth-resource.ts` (`publicUrlFromEnv`) | nur Vorbild der Regel, keine Änderung |
| Upstream | 4c-1, 4c-2a (gemergt) |
| Downstream | 4d (nginx, Datenschutztext, TestFlight-Bau mit `konto=true`, Geräteprobe der Anmeldung) |

## Acceptance Criteria

Unit-Tests im Swift-Testing-Stil von `AccountSectionTests`, UI-Test als `XCTestCase` in `AccountSettingsTests` (iPhone-Simulator).

- **AC-1:** Abbildung `Layout`: für jede Zeile der Tabelle oben liefert `AccountSection.layout(status:problem:)` genau die Felder der Tabelle; insbesondere zeigt `signingIn` den Apple-Knopf (`showsAppleButton == true`), er ist nicht bedienbar (`appleButtonEnabled == false`) und die Fortschrittszeile steht (`showsProgress == true`); `deleting` zeigt den Knopf nicht (`showsAppleButton == false`, `appleButtonEnabled == false`); `signedOut`, `notAllowed`, `retryLater` zeigen ihn bedienbar. Das **ersetzt AC-8 der 4c-1-Spec** („`signingIn` zeigt nie den Apple-Knopf“) für `signingIn`; für `deleting` und die Angemeldet-Zeilen gilt AC-8 weiter. Test: „account: layout je status“ (Unit, tabellengetrieben, angepasst).
- **AC-2:** Kein zweites Tippen: in jedem Status ist `appleButtonEnabled` höchstens dann wahr, wenn `showsAppleButton` wahr ist, und während `signingIn` und `deleting` nie wahr; in der View steht `.disabled(!layout.appleButtonEnabled)` an beiden Knopf-Varianten. Test: „account: laufende anfrage hat keinen bedienbaren knopf“ (Unit, über alle `AccountState.Status`-Fälle) und der UI-Test aus AC-3 (tippt den deaktivierten Knopf ein zweites Mal; es entsteht weder ein Fehler noch eine zweite Anmeldung).
- **AC-3:** Sichtbar im laufenden Ablauf: mit Startargument `--ui-testing-account-slow` und dem Weg „Einstellungen öffnen, Knopf antippen“ existiert während der Wartezeit der Knopf `accountAppleButton` (`exists == true`), `isEnabled == false`, und die Zeile `accountProgressRow` ist sichtbar mit dem Text „Signing in …“; ein weiteres Tippen auf den Knopf ändert nichts; danach (Wartezeit bis 30 s) steht `accountSignedInRow` und der Knopf existiert nicht mehr. Test: `testSigningInKeepsDisabledAppleButton` in `AccountSettingsTests` (UI) mit Screenshot-Beleg `account-signing-in`, aufgenommen erst nach der Prüfung des Zwischenstands, der geöffnet und beschrieben wird.
- **AC-4:** Ersatz-Dienst langsam: `UITestTransport` mit dem Argument `--ui-testing-account-slow` hat eine Verzögerung von 15 Sekunden; ein Ersatz mit gesetzter Verzögerung antwortet erst danach; ohne das Argument ist die Verzögerung null und die Antwort sofort; die Ausgänge `allowed`/`notAllowed`/`retryLater` bleiben je Argument wie festgelegt; die bestehenden UI-Tests laufen ohne Verzögerung. Test: „account: ersatz-transport langsam nur auf wunsch“ (Unit: `UITestTransport` aus `arguments:`, `delay` mit und ohne Argument, Ausgang unverändert, Antwort eines Transports mit kurzer ausdrücklicher Verzögerung erst nach dieser Wartezeit, damit der Unit-Lauf nicht 15 s steht) sowie der unveränderte vorhandene Satz in `AccountSettingsTests`.
- **AC-5:** Adressregel (Tabelle unten): `https` mit Host wird angenommen; `http` nur für `localhost` und `127.0.0.1` und nur mit `allowsLocalHTTP: true`; jeder andere Fall liefert `AccountWiring.fallbackURL`. Test: „account: dienstadresse nur https“ (Unit, tabellengetrieben, `allowsLocalHTTP` ausdrücklich gesetzt, damit beide Zweige im Debug-Lauf gelten).
- **AC-6:** Standardfreigabe: ohne Angabe von `allowsLocalHTTP` gilt im Debug-Bau (`#if DEBUG`) `http://localhost:8780` als angenommen, in einem Bau ohne `DEBUG` als abgelehnt (Fallback); `forApp` benutzt diesen Standard und nimmt unter `--ui-testing` mit `LEServiceURL = http://fremd.example` die Fallback-Adresse als Basis des Ersatz-Dienstes. Test: „account: dienstadresse standard folgt debug“ (Unit: Erwartung per `#if DEBUG` im Test selbst, so dass sie in jedem Bau gilt, in dem der Test laufen kann) und `forApp` im selben Test.
- **AC-7:** Keine Wirkung auf das Vorhandene: der bestehende Satz „account: wiring schalter und adresse“ (Schalter, `forApp` ohne Schlüssel gleich `nil`, Fallback bei fehlendem, leerem, kaputtem oder falsch getyptem Wert, `https://dienst.example` angenommen) bleibt unverändert grün; alle Fälle von `AccountSettingsTests` (Gruppe unter iCloud, Anmelden zeigt Angemeldet-Zeilen, Abmelden, Löschen abbrechen/bestätigen, `notAllowed`, `retryLater`) bleiben grün; die Gruppe „Claude“ bleibt in jedem echten Bau ausgeschaltet. Test: vorhandener `sim-unit`-Satz und `./scripts/sim.sh test-proof AccountSettingsTests` (maschineller Simulator-Beleg, Stufe 2).
- **AC-8:** Bauten und Grenze: `./scripts/sim.sh generate` hinterlässt keinen Diff; `./scripts/sim.sh build` und `./scripts/sim.sh mac-build` bauen ohne Fehler und ohne neue Warnungen (die Änderung in `AccountSection` und `AccountWiring` wirkt auf iOS und Mac); `python3 scripts/test_catalog_languages.py` unverändert grün (keine neuen Texte, keine neuen Schlüssel). Die Dateigrenze des Schnitts (nur die Tabelle „Affected Files“) prüft `/60-validate` einmalig, kein Test gegen `origin/main` (Projektregel). Test: `sim-unit` (alle Unit-Tests), `build`, `mac-build`, `test_catalog_languages.py`, CI-Schritt „Generate leaves the tree clean“ auf dem PR.

### Tabelle der Adressfälle (AC-5)

| Wert von `LEServiceURL` | `allowsLocalHTTP` | Ergebnis |
|---|---|---|
| `https://dienst.example` | beliebig | `https://dienst.example` |
| `HTTPS://Dienst.example` | beliebig | angenommen (Schema ohne Rücksicht auf Schreibweise) |
| `http://dienst.example` (http, fremder Host) | beliebig | Fallback |
| `http://localhost:8780` | `true` | `http://localhost:8780` |
| `http://localhost:8780` | `false` | Fallback |
| `http://127.0.0.1:8780` | `true` | `http://127.0.0.1:8780` |
| `http://127.0.0.1:8780` | `false` | Fallback |
| `ftp://dienst.example` | beliebig | Fallback |
| `https://` (ohne Host) | beliebig | Fallback |
| `https:///pfad` (ohne Host) | beliebig | Fallback |
| fehlt (`nil`), leer, `kein url`, Zahl `42` (falscher Typ) | beliebig | Fallback |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/AccountSection.swift` | MODIFY | `Layout.appleButtonEnabled`, Tabelle, `.disabled` an beiden Knopf-Varianten, ≈ +14/−6 |
| `LooseEnds/Claude/AccountWiring.swift` | MODIFY | `serviceURL(info:allowsLocalHTTP:)`, `UITestTransport.delay` und `--ui-testing-account-slow`, ≈ +24/−4 |
| `LooseEndsTests/AccountSectionTests.swift` | MODIFY | AC-1, AC-2, AC-4 bis AC-6, ≈ +45 |
| `LooseEndsUITests/AccountSettingsTests.swift` | MODIFY | AC-3, ≈ +25 |

### Estimated Changes

- 4 Dateien (Grenze 4 bis 5), geschätzt **+108/−10 LoC** (Summe der Tabelle) (Grenze ±250): innerhalb des Limits, kein Teilen nötig.
- Permissions: keine neuen, kein `Info.plist`-Eintrag, keine neuen AppStorage-Schlüssel, kein CloudKit-Schema, keine neuen Pakete, kein Audio, keine neuen Katalogschlüssel.
- Seiteneffekte: keine sichtbare Änderung in echten Bauten (Gruppe ausgeschaltet, `LEServiceURL` ungesetzt). Im Debug-Bau und unter `--ui-testing` ist der Apple-Knopf während der Anmeldung grau statt verschwunden.

## Risiken

- **Deaktivierter Apple-Knopf und Apples Fenster:** Ob auch ein deaktivierter `SignInWithAppleButton` seine Antwort sicher zustellt, ist wie bei jedem Apple-Fenster nur auf dem Gerät belegbar (der Simulator führt es unter `--ui-testing` nicht aus). Das Deaktivieren hält ihn in der Hierarchie und ist damit der sicherere Weg als das Entfernen; der echte Beleg ist die Geräteprobe der Anmeldung in 4d. Rückfall: Alternative „eigener `ASAuthorizationController`“.
- **Zeitgeber im UI-Test:** `--ui-testing-account-slow` (15 s) muss lang genug sein, dass der Test den Zwischenstand auch auf dem langsamen CI-Rechner trifft (gemessen 2026-11-10: rund 10 s zwischen Tippen und Abfrage, mit 2 s schlug der Test dort fehl), und kurz genug für die Wartezeit des Tests (bis 30 s). Das Wartefenster des Tests ist deshalb eine Anwesenheitsprüfung mit `waitForExistence`, kein Zeitvergleich.
- **Debug-Standard in Release:** `#if DEBUG` darf im Release-Bau nicht `true` sein; AC-6 prüft die Erwartung im Test über dieselbe Bedingung, nicht über die Implementierung selbst.

## Test Plan

### Automated Tests (TDD RED)

RED: Die Unit-Tests schlagen zunächst fehl, weil `Layout` kein `appleButtonEnabled` hat (Test-Ziel baut nicht), `serviceURL` den Parameter `allowsLocalHTTP` nicht kennt und `UITestTransport.delay` fehlt; der UI-Test schlägt fehl, weil der Knopf in `signingIn` nicht existiert. Gegenrichtungen sind Prüfungen: AC-2 (kein bedienbarer Knopf während einer Anfrage), AC-5 (http fremd bleibt Fallback), AC-7 (Vorhandenes unverändert).

| Testname | AC |
|---|---|
| „account: layout je status“ (angepasst) | AC-1 |
| „account: laufende anfrage hat keinen bedienbaren knopf“, `testSigningInKeepsDisabledAppleButton` | AC-2 |
| `testSigningInKeepsDisabledAppleButton` | AC-3 |
| „account: ersatz-transport langsam nur auf wunsch“ | AC-4 |
| „account: dienstadresse nur https“ | AC-5 |
| „account: dienstadresse standard folgt debug“ | AC-6 |
| „account: wiring schalter und adresse“, `AccountSettingsTests` (vorhandener Satz), `test-proof AccountSettingsTests` | AC-7 |
| `sim-unit`, `build`, `mac-build`, `test_catalog_languages.py`, CI „Generate leaves the tree clean“ | AC-8 |

- [ ] Test 1 (AC-1, AC-2): GIVEN alle Status WHEN `layout` THEN Tabellenwerte; `signingIn` zeigt den Knopf nicht bedienbar mit Fortschritt, `deleting` ohne Knopf.
- [ ] Test 2 (AC-5): GIVEN die Adressfälle der Tabelle WHEN `serviceURL(info:allowsLocalHTTP:)` THEN genau die Ergebnisse der Tabelle.
- [ ] Test 3 (AC-3): GIVEN `--ui-testing --ui-testing-account-slow` WHEN die Einstellungen offen sind und der Knopf getippt wird THEN der Knopf existiert mit `isEnabled == false`, `accountProgressRow` zeigt „Signing in …“, ein zweites Tippen ändert nichts, danach steht `accountSignedInRow` und der Knopf ist weg.
- [ ] Test 4 (AC-4): GIVEN `UITestTransport` mit und ohne `--ui-testing-account-slow` WHEN `delay` gelesen und gesendet wird THEN 15 s bzw. sofort, Ausgänge unverändert.

## Nicht in diesem Schnitt / Folgeschnitte

- **4d:** nginx öffnet genau `/auth/apple`, `/auth/logout`, `/auth/delete` mit eigener Limit-Zone (Repo `henemm-infra`); Konto-Teil des Datenschutztextes (#625) auf henemm.com; danach TestFlight-Bau mit `konto=true` und die Geräteprobe (Anmelden, Abmelden, Löschen). Dort entsteht auch der echte Beleg, dass der deaktivierte Knopf Apples Antwort zustellt.
- **#795:** Abschrift hochladen mit dem Sitzungstoken.
- Kein neuer Entwurf, keine neuen Texte, nichts an `server/`, `Shared/`, `project.yml`, am Datenschutztext und nichts auf Hennings Geräten.

## Abnahme

- Stufe 1 Tests: neue Fälle vorher rot, danach grün (voller `sim-unit`).
- Stufe 2 Simulator: `./scripts/sim.sh build`, danach `./scripts/sim.sh test-proof AccountSettingsTests` mit maschinellem Beleg; der Screenshot `account-signing-in` wird geöffnet und beschrieben (Knopf grau, Fortschrittszeile darunter), ebenso `account-signed-in`.
- Stufe 3 Gerät: **entfällt.** Der Schnitt berührt nur `LooseEnds/Views`, `LooseEnds/Claude` und Tests, keinen Pfad der Geräteliste in `CLAUDE.md`. Der Abschlussbericht begründet das mit dem Satz: „Kein Pfad der Geräteliste berührt.“

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt, als Tests bzw. Bauläufe; die Dateigrenze einmalig im Validierungsprotokoll
- [ ] `sim-unit`, `build`, `mac-build`, `test-proof AccountSettingsTests`, `test_catalog_languages.py`, CI auf dem PR grün
- [ ] Abschluss nach Stufe 2 belegt (Simulator-Beleg, Screenshots geöffnet und beschrieben); Gerätepunkte gibt es keine
- [ ] AC-8 der 4c-1-Spec in der Doku-Spur als ersetzt vermerkt (durch AC-1 dieser Spec); `CLAUDE.md` bleibt unverändert, weil die Zeile zu `AccountWiring` keine http-Aussage trifft
- [ ] #615 kommentiert (Stand 4c-2b: F001 und F002 geschlossen; Folge 4d), Board-Karte aktuell
- [ ] Abschlussbericht ohne Git-Vokabular; benennt: kein sichtbarer Unterschied in echten Bauten, echter Beleg zum deaktivierten Knopf und Apple-Fenster erst in der Geräteprobe von 4d

## Changelog

- 2026-11-10: Initial spec created (Schnitt 4c-2b, Teil-Spec)
- 2026-11-10: Nachbesserung nach roter CI (UI Smoke, PR #897): Verzögerung des langsamen Ersatz-Dienstes 2 s → 15 s, Wartezeit des UI-Tests 10 s → 30 s, Zwischenstand vor dem Screenshot prüfen; Unit-Test misst die Wartezeit mit kurzer ausdrücklicher Verzögerung. Ursache: auf dem CI-Rechner lagen rund 10 s zwischen Tippen und Abfrage, der Ersatz hatte schon geantwortet.
