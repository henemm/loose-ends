---
entity_id: feat-615-schnitt-4c1-konto-gruppe
type: feature
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: feat-615-s4c-konto
---

# Spec: Einstellungen, Gruppe „Claude“ (Anmelden, Abmelden, Konto löschen), Schnitt 4c-1 (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Teil-Spec für Schnitt 4c-1; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s4c-konto.md` (Abschnitte „Scope Assessment“ und „Technical Approach“ sind verbindlich).
Freigegebener Entwurf A: `docs/artifacts/feat-615-s4c-konto/entwurf.html` (Henning, 2026-11-09); der Wortlaut der Zeilen und Hinweise
dort gilt wörtlich, Alternative B ist verworfen. Vorgänger: 4b-1 bis 4b-3 (`ServiceClient`, `SessionStoring`, `AccountState`,
`KeychainSessionStore`, PR #884 bis #888). Diese Spec deckt nur 4c-1 ab; Berechtigung, Info-Schlüssel, TestFlight-Eingabe `konto`,
Store-Sperre, nginx und Datenschutztext sind 4c-2 und 4d.

## Für den PO

In den Einstellungen gibt es künftig eine Gruppe „Claude“ direkt unter iCloud (auf dem Mac direkt nach dem iCloud-Eintrag): dort
meldest du die App mit Apple an, meldest dich wieder ab oder löschst das Konto, nach einer Rückfrage. Gebaut und im Simulator
durchgespielt wird das gegen einen Ersatz-Dienst, ohne echte Anmeldung bei Apple. **In jeder echten App bleibt die Gruppe vorerst
verborgen** (auch in TestFlight und im Store): Sie wird erst in einem Folgeschnitt eingeschaltet, wenn Berechtigung und Dienst bereit
sind. Du musst nichts tun und siehst in deiner App noch nichts.

## Purpose

Die Oberfläche bildet nur `AccountState.status` auf Zeilen ab (Muster `SyncStatus.summary`): eine reine Abbildung `Layout`, eine dünne
View, dünne Apple-Verdrahtung. `AccountWiring.forApp` wählt an einer Stelle die Ablage (Schlüsselbund; unter `--ui-testing` Speicher
plus fester Ersatz-Transport) und liest `LEServiceURL` und `LEAccountEnabled` mit Fallbacks. **Regeln vor Modell:** reine Zustands- und
Oberflächenarbeit, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue — folgt ADR-21 (Weg B: nichts verlässt das Gerät ohne Tippen, Sitzungstoken nur im Schlüsselbund); keine neue Abhängigkeit (`AuthenticationServices` gehört zum System-SDK).
- **Rationale:** (1) Zustand liegt schon rein in `AccountState`; die View liest nur ihn. (2) Die Abbildung Status → Zeilen ist eine reine Funktion und im Unit-Test belegt, die View bleibt dünn. (3) Der Apple-Dialog ist im Simulator unzuverlässig (Recherche 2026-11-08), deshalb ersetzt unter `--ui-testing` ein Testknopf den Apple-Knopf; der echte Apple-Ablauf wird erst in 4c-2 (Stufe 3 über TestFlight) belegt. (4) Fallback von `LEAccountEnabled` ist **aus**: ohne Info-Schlüssel (den 4c-2 setzt) ist die Gruppe in jedem echten Bau verborgen. Das ist gewollt, weil das Store-Archiv mit TestFlight identisch ist und der Konto-Teil des Datenschutztextes erst in 4d online steht. (5) Farbbudget: Akzent für antippbare Zeilen, Rot nur im Bestätigungsdialog als Systemrolle `.destructive`; keine eigenen Symbole (der Apple-Knopf ist das Systembauteil `SignInWithAppleButton`).
- **Alternativen (verworfen):**
  - **B: eigene Seite „Claude“.** Eine Zeile in den Einstellungen öffnet eine Seite mit Erklärung und Konto (im Entwurf gezeigt, von Henning verworfen). Hätte mehr Platz für Erklärung, aber einen Schritt mehr; sie würde gewählt, wenn die Konto-Erklärung in 4d länger als ein Hinweistext wird.
  - **C: Web-Anmeldung** (`ASWebAuthenticationSession` gegen `/oauth`) statt nativer Berechtigung. Würde den Vertrag `POST /auth/apple` (Schnitt S3) kippen und die Wahl der Zeilen unverändert lassen; bleibt Rückfall, falls die Mac-Berechtigung in 4c-2 scheitert.
  - **Gruppe immer sichtbar, Anmeldung erst später freischalten:** zeigte Store-Nutzern eine Tür, die sie abweist. Verworfen (Analyse, Entscheidung Schalter).

## Source

**Files (CREATE):** `LooseEnds/Views/AccountSection.swift`, `LooseEnds/Claude/AccountWiring.swift`, `LooseEndsTests/AccountSectionTests.swift`, `LooseEndsUITests/AccountSettingsTests.swift`
**Files (MODIFY):** `LooseEnds/Views/SettingsView.swift`, `LooseEnds/App/LooseEndsApp.swift`, `LooseEnds/Resources/Localizable.xcstrings`, `CLAUDE.md` (Doku)
**Identifier:** `AccountSection`, `AccountSection.Layout`, `AccountWiring`, `AccountWiring.forApp`, `AccountWiring.isEnabled`, `UITestTransport`

### `AccountSection.Layout` (rein, `AccountSection.swift`)

`static func layout(status: AccountState.Status, problem: AccountState.Problem?) -> Layout`, `Equatable`. Felder:
`showsAppleButton: Bool`, `showsProgress: Bool`, `showsSignedInRows: Bool`, `hint: Hint` (Enum, ein Fall je Hinweissatz, siehe Texte).

| Status | Apple-Knopf | Fortschritt | Angemeldet-Zeilen | Hinweis |
|---|---|---|---|---|
| `signedOut` | ja | nein | nein | `intro` |
| `signingIn` | nein | ja („Anmelden …“) | nein | `intro` |
| `signedIn`, ohne Problem | nein | nein | ja | `signedIn` |
| `signedIn`, Problem `retryLater` (Löschen scheiterte) | nein | nein | ja | `retryLater` |
| `deleting` | nein | ja („Konto wird gelöscht …“) | nein | `signedIn` |
| `notAllowed` | ja | nein | nein | `notAllowed` |
| `retryLater` | ja | nein | nein | `retryLater` |

### Texte (de, wörtlich aus dem Entwurf; en sinngemäß im selben Ton)

- Gruppenkopf (iOS) und Mac-Kopf: „Claude“. Apple-Knopf: Systemtext „Mit Apple anmelden“ (Systembauteil, nicht im Katalog). Mac, abgemeldet: links die Zeile „Mit Claude verbinden“, rechts der Apple-Knopf.
- `intro`: „Melde dich mit Apple an, damit Claude deine offenen Aufgaben lesen und neue anlegen kann. Ohne Anmeldung verlässt nichts dieses Gerät.“ (Mac: „… nichts diesen Mac.“)
- Fortschritt: „Anmelden …“; beim Löschen: „Konto wird gelöscht …“ (Ableitung im selben Ton, nicht im Entwurf).
- Angemeldet: „Angemeldet mit Apple“ mit Wert „Dieses Gerät“ (Mac: „Dieser Mac“); Zeilen „Abmelden“ und „Konto löschen …“ (beide Akzent).
- `signedIn`: „Claude sieht deine offenen Aufgaben. Abmelden trennt nur dieses Gerät. Konto löschen entfernt alles, was der Dienst für Claude von dir aufbewahrt.“ (Mac: „… nur diesen Mac. …“)
- `notAllowed`: „Dieses Apple-Konto ist für Claude noch nicht freigegeben.“
- `retryLater`: „Der Dienst ist gerade nicht erreichbar. Versuch es später noch einmal.“
- Bestätigungsdialog (`confirmationDialog`): Titel „Konto löschen?“, Meldung „Claude sieht deine Aufgaben dann nicht mehr. Deine Aufgaben in der App bleiben, wie sie sind.“, Knopf „Konto löschen“ (Rolle `.destructive`), „Abbrechen“ (Systemrolle `.cancel`).
- Alle Schlüssel mit de und en in `Localizable.xcstrings`; das Wort „Knäuel“ und Ähnliches kommt nicht vor.

### `AccountSection` (View, `AccountSection.swift`)

- Liest `AccountState` aus der Umgebung und zeigt die Zeilen gemäß `Layout`. Abmelden ruft `signOut()` ohne Rückfrage; Konto löschen setzt nur den Dialog, erst „Konto löschen“ im Dialog ruft `deleteAccount()`; „Abbrechen“ ändert nichts.
- Accessibility-Kennungen: `accountSection`, `accountAppleButton` (Apple-Knopf bzw. unter `--ui-testing` der Testknopf), `accountSignedInRow`, `accountSignOutRow`, `accountDeleteRow`, `accountHint`.
- **Echter Apple-Weg (nicht unter `--ui-testing`):** `SignInWithAppleButton` mit `onRequest`: `nonce = try account.beginSignIn()` (bei Fehler kein Dialog), keine angeforderten Bereiche; `onCompletion`: bei Erfolg `identityToken` und `authorizationCode` als UTF-8-Text an `completeSignIn`, fehlt eines von beiden oder schlägt Apple fehl (auch Abbruch durch den Nutzer) → `cancelSignIn()`. Kein Token und keine Nonce in einem Log.
- **Unter `--ui-testing`:** statt des Apple-Knopfs ein gewöhnlicher Knopf mit Kennung `accountAppleButton`, der `beginSignIn()` und dann `completeSignIn(identityToken: "UITEST-IDENTITY", code: "UITEST-CODE")` aufruft.
- Einbau in `SettingsView.swift`: iOS direkt nach `syncSection`, vor `calendarSection`; Mac direkt nach der iCloud-Zeile (`syncSection`), vor „Notifications“. Nur wenn `AccountState` in der Umgebung liegt. Die Gruppe benutzt das vorhandene `group(title, hint:rows:)`.

### `AccountWiring` (`LooseEnds/Claude/AccountWiring.swift`)

- `static func isEnabled(info: [String: Any]?, arguments: [String]) -> Bool`: wahr, wenn `arguments` `--ui-testing` enthält, sonst der Info-Wert `LEAccountEnabled` als `Bool` (`NSNumber` oder `Bool`), bei fehlendem oder falsch typisiertem Wert **falsch**.
- `static func serviceURL(info:) -> URL`: Info-Wert `LEServiceURL`, bei fehlendem, leerem oder ungültigem Wert `https://loose-ends.henemm.com`.
- `@MainActor static func forApp(info:arguments:) -> AccountState?`: `nil`, wenn nicht aktiviert (dann wird nichts gelesen, nichts gebaut). Sonst `AccountState(client:store:)`: echt mit `ServiceClient(baseURL:)` und `KeychainSessionStore()`; unter `--ui-testing` mit `InMemorySessionStore()` und `ServiceClient(baseURL:transport: UITestTransport(outcome:))`.
- `UITestTransport: HTTPTransport`: fester Ersatz, kein Netz. Ausgang je Startargument: ohne Argument zugelassen (`/auth/apple` → 200 mit `{"sessionToken":"UITEST-SESSION"}`, `/auth/logout` und `/auth/delete` → 204); `--ui-testing-account-not-allowed` (`/auth/apple` → 401 ohne Körper); `--ui-testing-account-retry-later` (`/auth/apple` → 503). Antwortformen wie im Vertrag `server/src/auth.ts`.
- `LooseEndsApp.swift` baut `AccountState` einmal (`forApp`) und gibt ihn in die Umgebung von Hauptfenster **und** Mac-Einstellungsfenster (`Settings`-Szene); das iOS-Sheet erbt ihn vom Hauptfenster.

### Festlegungen

- **Kein Netz ohne Tippen (ADR-21):** `AccountState.init` liest nur die Ablage; beim Start der App und beim Öffnen der Einstellungen geht keine Anfrage hinaus. Nur Antippen des Apple-Knopfs, „Abmelden“ oder des bestätigten Löschens sendet.
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Swift 6 strict concurrency ohne Warnung; kein `try?`, das Fehler schluckt; `Logger` statt `print`; keine neuen Pakete; nur SF Symbols und Systembauteile.
- **Unberührt:** `project.yml`, jede `*.entitlements`, jede `Info.plist`, `Shared/`, `server/`, `LooseEnds/Claude/AccountState.swift`, `ServiceClient.swift`, `SessionStore.swift`, `KeychainSessionStore.swift`, `.github/`, `scripts/`. Nach dem Anlegen der neuen Dateien läuft `./scripts/sim.sh generate`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `AccountState`, `ServiceClient`, `HTTPTransport`, `InMemorySessionStore`, `KeychainSessionStore` (4b) | werden benutzt, unverändert |
| `SettingsView.group(title, hint:rows:)` | wird benutzt; Einbau an zwei Stellen |
| `SettingsSmokeTests.swift` | Muster für den neuen UI-Test; bleibt unverändert und grün |
| `scripts/test_catalog_languages.py` | prüft Vollständigkeit de/en der neuen Schlüssel |
| AuthenticationServices | System-SDK, keine neuen Pakete |
| Upstream | 4b-1 bis 4b-3 (gemergt) |
| Downstream | 4c-2 (Berechtigung `com.apple.developer.applesignin`, Info `LEServiceURL`/`LEAccountEnabled`, TestFlight-Eingabe `konto`, Store-Sperre, Stufe 3), 4d (nginx, `APPLE_CLIENT_IDS`, Datenschutztext), #795 |

## Acceptance Criteria

Unit-Tests mit Swift Testing (`import Testing`, `@testable import LooseEnds`), Lauf über `./scripts/sim.sh sim-unit AccountSectionTests`.
UI-Tests als XCTest in `AccountSettingsTests` (Sprache en per Startargument wie `SettingsSmokeTests`, iPhone-Simulator), Lauf und Beleg über
`./scripts/sim.sh test-proof AccountSettingsTests`. Die UI-Tests zählen nur, was sichtbar ist (Zeilen, Hinweise, Reihenfolge), nicht, dass
ein Element existiert.

- **AC-1:** Abgemeldet: Öffnen der Einstellungen (Zahnrad) zeigt die Gruppe `accountSection` mit dem Kopf „Claude“, dem Anmelden-Knopf `accountAppleButton` und dem Hinweis „Melde dich mit Apple an, damit Claude deine offenen Aufgaben lesen und neue anlegen kann. Ohne Anmeldung verlässt nichts dieses Gerät.“ (englisch in der Testsprache en); die Gruppe liegt unter der iCloud-Zeile `iCloudSyncRow` und über den Kalender-Zeilen (Vergleich der y-Position der Elemente). Test: `testSignedOutShowsGroupBelowICloud` (UI).
- **AC-2:** Anmelden: Tippen auf `accountAppleButton` führt (Ersatz zugelassen) zu `accountSignedInRow` mit „Angemeldet mit Apple“ und „Dieses Gerät“, zu den Zeilen `accountSignOutRow` („Abmelden“) und `accountDeleteRow` („Konto löschen …“) und zum Hinweis „Claude sieht deine offenen Aufgaben. Abmelden trennt nur dieses Gerät. Konto löschen entfernt alles, was der Dienst für Claude von dir aufbewahrt.“; `accountAppleButton` ist verschwunden. Test: `testSignInShowsSignedInRows` (UI).
- **AC-3:** Abmelden ohne Rückfrage: Tippen auf `accountSignOutRow` führt ohne Dialog zurück in den Abgemeldet-Zustand aus AC-1 (Knopf und Hinweis wieder da, Angemeldet-Zeilen weg). Test: `testSignOutNeedsNoConfirmation` (UI).
- **AC-4:** Löschen, Abbrechen: Tippen auf `accountDeleteRow` zeigt den Dialog mit Titel „Konto löschen?“, der Meldung „Claude sieht deine Aufgaben dann nicht mehr. Deine Aufgaben in der App bleiben, wie sie sind.“ und den Knöpfen „Konto löschen“ und „Abbrechen“; „Abbrechen“ schließt ihn, `accountSignedInRow` bleibt stehen. Test: `testDeleteCancelKeepsSignedIn` (UI).
- **AC-5:** Löschen, Bestätigen: im Dialog „Konto löschen“ führt zum Abgemeldet-Zustand (Knopf und Hinweis wie AC-1); die Angemeldet-Zeilen sind weg. Der Knopf im Dialog trägt die Systemrolle `.destructive` (Quelltext-Beleg im Validierungsprotokoll: Rot kommt nur dort vor). Test: `testDeleteConfirmSignsOut` (UI).
- **AC-6:** „Nicht freigegeben“: mit `--ui-testing-account-not-allowed` führt Tippen auf `accountAppleButton` zurück in den Zustand mit Knopf und dem Hinweis „Dieses Apple-Konto ist für Claude noch nicht freigegeben.“; es erscheinen keine Angemeldet-Zeilen. Test: `testNotAllowedShowsItsSentence` (UI).
- **AC-7:** „Später nochmal“: mit `--ui-testing-account-retry-later` führt Tippen auf `accountAppleButton` zu Knopf und Hinweis „Der Dienst ist gerade nicht erreichbar. Versuch es später noch einmal.“; ein zweiter Tipp ist möglich (der Knopf steht noch). Test: `testRetryLaterShowsItsSentence` (UI).
- **AC-8:** Abbildung `Layout`: für jede Zeile der Tabelle (`signedOut`, `signingIn`, `signedIn` ohne und mit Problem `retryLater`, `deleting`, `notAllowed`, `retryLater`) liefert `AccountSection.layout(status:problem:)` genau die Felder der Tabelle; insbesondere zeigt `signingIn` und `deleting` nie den Apple-Knopf und nie die Angemeldet-Zeilen mit Aktionen (kein zweites Tippen möglich), `notAllowed` und `retryLater` zeigen den Knopf. Test: „account: layout je status“ (Unit, tabellengetrieben).
- **AC-9:** Schalter: `AccountWiring.isEnabled` ist falsch bei fehlendem Info-Schlüssel, bei `false`, bei falschem Typ (z. B. Text) und wahr bei `true` im Info-Wörterbuch; mit `--ui-testing` in den Argumenten ist es immer wahr. `forApp` liefert bei „aus“ `nil` (kein `AccountState`, keine Ablage gelesen) und ist in der Einstellungsansicht ohne `AccountState` ohne Gruppe. `serviceURL` fällt bei fehlendem, leerem und ungültigem Wert auf `https://loose-ends.henemm.com` zurück und nimmt sonst den Info-Wert. Test: „account: wiring schalter und adresse“ (Unit).
- **AC-10:** Kein Netzaufruf ohne Tippen: `forApp` mit `--ui-testing` und ein gezählter Ersatz-Transport (eigener Zähler im Test, `AccountState.init` und das Berechnen des `Layout` für alle Zustände) lösen **null** Anfragen aus; der Zähler steigt erst mit `completeSignIn`. Test: „account: init sendet nichts“ (Unit).
- **AC-11:** Ersatz-Transport: `UITestTransport` antwortet je Ausgang laut Festlegung (zugelassen: 200 mit `sessionToken`; `not-allowed`: 401; `retry-later`: 503; Abmelden und Löschen 204) und trägt kein Netz; `ServiceClient` bildet die Antworten auf Token, `ServiceError.unauthorized` und `ServiceError.unavailable` ab. Test: „account: ersatz-transport ausgaenge“ (Unit).
- **AC-12:** Texte: alle neuen Schlüssel haben de und en; `python3 scripts/test_catalog_languages.py` ist grün. Der deutsche Wortlaut stimmt mit der Liste „Texte“ dieser Spec überein (Beleg: Stichprobe der Schlüssel im Validierungsprotokoll). Beleg: Lauf des Skripts.
- **AC-13:** Grenze und Stil: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `LooseEnds/Views/AccountSection.swift`, `LooseEnds/Claude/AccountWiring.swift`, `LooseEnds/Views/SettingsView.swift`, `LooseEnds/App/LooseEndsApp.swift`, `LooseEnds/Resources/Localizable.xcstrings`, `LooseEndsTests/AccountSectionTests.swift`, `LooseEndsUITests/AccountSettingsTests.swift` und `CLAUDE.md` (kein `project.yml`, keine Entitlements, keine `Info.plist`, nichts unter `Shared/`, `server/`, `.github/`, `scripts/`); `grep -nE 'print\(' ` in den beiden neuen Quelldateien ohne Treffer; keine Funktion über 50 Zeilen; kein Token und keine Nonce in einer Logzeile. Beleg: einmalig in `/60-validate` im Validierungsprotokoll, kein Test gegen `origin/main`.
- **AC-14:** Doku: der Eintrag „`LooseEnds/Claude`“ in `CLAUDE.md` nennt `AccountWiring` (Schalter `LEAccountEnabled` Fallback aus, `LEServiceURL`, Ersatz unter `--ui-testing`) und `AccountSection` in `LooseEnds/Views`. Beleg: `grep -n 'AccountWiring' CLAUDE.md` im Validierungsprotokoll.
- **AC-15:** Regression und Abnahme: `./scripts/sim.sh sim-unit` (alle Unit-Tests) grün; `./scripts/sim.sh build` und `./scripts/sim.sh mac-build` bauen ohne Fehler und ohne neue Warnungen aus den geänderten oder neuen Dateien; `./scripts/sim.sh test-proof AccountSettingsTests` grün mit maschinellem Beleg; die vorhandenen `SettingsSmokeTests` bleiben grün. Beleg: Läufe im Validierungsprotokoll samt geöffneten und beschriebenen Screenshots der Zustände abgemeldet, angemeldet, Dialog, „nicht freigegeben“, „später nochmal“.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/AccountSection.swift` | CREATE | `Layout` (rein), View, dünne Apple-Verdrahtung, Testknopf, ≈ +110 |
| `LooseEnds/Claude/AccountWiring.swift` | CREATE | `isEnabled`, `serviceURL`, `forApp`, `UITestTransport`, ≈ +80 |
| `LooseEnds/Views/SettingsView.swift` | MODIFY | Gruppe nach iCloud (iOS und Mac), ≈ +8 |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | `AccountState` einmal bauen, in beide Umgebungen, ≈ +10 |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | ≈ 14 Schlüssel de/en, Katalogdaten, ≈ +100 JSON-Zeilen |
| `LooseEndsTests/AccountSectionTests.swift` | CREATE | AC-8 bis AC-11, ≈ +90 |
| `LooseEndsUITests/AccountSettingsTests.swift` | CREATE | AC-1 bis AC-7, ≈ +110 |
| `CLAUDE.md` | MODIFY | Doku, +2, zählt nicht als Code |

### Estimated Changes

- **Produktcode ≈ 210 LoC** (4 Quelldateien) plus Katalog (Daten) und **Tests ≈ 200 LoC** (2 Dateien). Zählt man den Katalog als Datei, sind es 5 Produktdateien und 2 Testdateien, also 7 Dateien und rund 410 Zeilen; gegen die Regel (4 bis 5 Dateien, ±250 LoC) ist das **überschritten**, und zwar durch Test und Katalogdaten, nicht durch Produktlogik. Nach der Praxis der Schnitte 4b-2 und 4b-3 (Tests und Katalog zählen nicht gegen die Produktgrenze) bleibt die Produktseite mit ≈ 210 LoC und 4 Quelldateien in der Grenze. Das ist beim Annehmen der Spec ausdrücklich zu bestätigen.
- **Teilungsvorschlag, falls die Bestätigung ausbleibt:** **4c-1a** = `AccountWiring`, `LooseEndsApp`, Unit-Test (AC-9 bis AC-11, AC-13 bis AC-15, ohne Oberfläche, ≈ +110 Produkt +50 Test); **4c-1b** = `AccountSection`, `SettingsView`, Katalog, UI-Test (AC-1 bis AC-8, AC-12). Empfehlung: **nicht teilen**, weil 4c-1a keine sichtbare Wirkung hätte und der Durchlauf als Nutzer (AC-15) erst mit 4c-1b möglich ist.
- Keine Permissions, keine Info.plist-Änderung, keine Berechtigung, keine AppStorage-Schlüssel, kein CloudKit-Schema, keine neuen Pakete, kein Audio. **Neue lesende Info-Schlüssel** `LEServiceURL` und `LEAccountEnabled` werden nur gelesen, nicht gesetzt (Setzen ist 4c-2). Seiteneffekt im Betrieb: **keiner in einer echten App**, weil die Gruppe ohne Info-Schlüssel verborgen ist und `forApp` dann `nil` liefert (kein Schlüsselbund-Zugriff, kein Netz).

## Risiken

- **Echter Apple-Weg unbelegt:** `SignInWithAppleButton` und die Umsetzung von `ASAuthorization` in Token und Code werden im Simulator nicht durchgespielt (Simulator unzuverlässig, Testknopf ersetzt ihn); belegt erst in 4c-2 über TestFlight (Stufe 3). Der dünne Teil ist klein gehalten (Token und Code als Text, sonst `cancelSignIn`), steht aber bis dahin als ungeprüft im Abschlussbericht.
- **Echter Schlüsselbund über die App:** unter `--ui-testing` liegt der Ersatz im Speicher (Mac-CI ohne Profil liefert `-34018`); der Beleg des echten Schlüsselbunds über die App folgt mit 4c-2, wenn die App mit Berechtigung läuft. Im Abschlussbericht benannt.
- **Gruppe in jedem echten Bau verborgen:** gewollt (Fallback aus). Folge: Henning sieht in seiner TestFlight-App nach 4c-1 noch nichts; der Einschalter ist 4c-2.
- **Mac-Einstellungsfenster:** eigene `Settings`-Szene braucht die Umgebung gesondert; fehlt sie, bliebe die Gruppe dort stumm weg. Belegt durch `mac-build` und Quellprüfung, nicht durch einen Mac-UI-Test (die Mac-Reihenfolge ist nicht Teil der UI-Tests; `SettingsSmokeTests` überspringen den Mac aus demselben Grund).
- **Umfang:** siehe Estimated Changes.
- **Live-Dienst nicht erreichbar:** nginx lässt `/auth/*` erst in 4d durch; 4c-1 spricht nie mit dem Live-Dienst (nur Ersatz), das Risiko betrifft 4c-2.

## Befunde gegen den Plan

- Die Analyse nennt 4c-1 mit ≈ 250 LoC; nach Zählung mit Test und Katalog liegt der Schnitt darüber (siehe Estimated Changes). Der Unit-Test `AccountSectionTests` steht nicht in der Analyse, ist aber nötig, weil `LEAccountEnabled` = aus im UI-Test nicht prüfbar ist (unter `--ui-testing` immer an) und die Abbildung der Zustände (`signingIn`, `deleting`) im UI nicht stabil zu treffen ist.
- „Konto wird gelöscht …“ und die Hinweise bei `deleting` und `signedIn` mit Problem sind Ableitungen im Ton des Entwurfs; Henning hat den Entwurf freigegeben, nicht diese zwei Zeilen.

## Test Plan

### Automated Tests (TDD RED)

RED: Die Unit-Tests schlagen zunächst fehl, weil `AccountSection`, `AccountWiring` und `UITestTransport` nicht existieren (Test-Ziel baut nicht); die UI-Tests schlagen fehl, weil die Gruppe `accountSection` nicht existiert. Das ist der erwartete Zustand vor `/50-implement`. Gegenrichtungen bleiben Prüfungen: AC-4 (Abbrechen löscht nichts), AC-8 (kein zweites Tippen während `signingIn`/`deleting`), AC-9 (aus ohne Schlüssel, `forApp` liefert `nil`), AC-10 (kein Netz ohne Tippen).

| Testname | AC |
|---|---|
| `testSignedOutShowsGroupBelowICloud` | AC-1 |
| `testSignInShowsSignedInRows` | AC-2 |
| `testSignOutNeedsNoConfirmation` | AC-3 |
| `testDeleteCancelKeepsSignedIn` | AC-4 |
| `testDeleteConfirmSignsOut` | AC-5 |
| `testNotAllowedShowsItsSentence` | AC-6 |
| `testRetryLaterShowsItsSentence` | AC-7 |
| „account: layout je status“ | AC-8 |
| „account: wiring schalter und adresse“ | AC-9 |
| „account: init sendet nichts“ | AC-10 |
| „account: ersatz-transport ausgaenge“ | AC-11 |
| `scripts/test_catalog_languages.py` | AC-12 |
| kein dauerhafter Test, **genehmigte Abweichung** (Projektregel „Kein Diff-Test gegen main“: Dateigrenze und Doku-Stand prüft nur `/60-validate`, wie in 4b-2/4b-3): Validierungsbeleg in `/60-validate` (`git diff --name-only`, `grep`, Funktionslängen, Quelltext-Rolle `.destructive`) | AC-13, AC-14 |
| voller `./scripts/sim.sh sim-unit`, `build`, `mac-build`, `test-proof AccountSettingsTests` | AC-15 |

- [ ] Test 1 (AC-1 bis AC-3): GIVEN App mit `--ui-testing`, Sprache en WHEN Einstellungen öffnen, anmelden, abmelden THEN Gruppe unter iCloud mit Hinweis; angemeldet mit drei Zeilen und Hinweis; abgemeldet ohne Rückfrage.
- [ ] Test 2 (AC-4, AC-5): GIVEN angemeldet WHEN „Konto löschen …“ und Abbrechen bzw. Bestätigen THEN bleibt angemeldet bzw. abgemeldet.
- [ ] Test 3 (AC-6, AC-7): GIVEN Startargument für den Ausgang WHEN anmelden THEN der jeweilige Satz, kein Angemeldet-Zustand, Knopf weiter da.
- [ ] Test 4 (AC-8 bis AC-11): GIVEN alle Zustände, Info-Wörterbücher, gezählter Ersatz WHEN `layout`, `isEnabled`, `serviceURL`, `forApp`, Transport laufen THEN Tabellenwerte, Fallback aus, null Anfragen vor dem Tippen, Ausgänge wie festgelegt.

## Nicht in diesem Schnitt / Folgeschnitte

- **4c-2:** Berechtigung `com.apple.developer.applesignin` in `project.yml` (und `.probe`-Kennung, `entitled`-Prüfung, `test_entitlements_sync.py`), Info-Schlüssel `LEServiceURL` und `LEAccountEnabled` (aus), TestFlight-Eingabe `konto` (Standard aus), Store-Sperre in `scripts/asc_store_version.py` / `asc-store-version.yml`, echter Schlüsselbund und echter Apple-Weg, Stufe 3 über TestFlight, nachdem 4d-Server-Teil bereitsteht.
- **4d:** nginx genau `/auth/apple`, `/auth/logout`, `/auth/delete`, `APPLE_CLIENT_IDS`, Datenschutztext (Konto-Teil), Einschalten im Store-Bau.
- **#795:** Abschrift hochladen mit dem Sitzungstoken aus der Ablage.
- Nicht in 4c-1: jede Änderung an `project.yml`, `.github/`, `scripts/`, `server/`, am Datenschutztext und jede Handlung auf Hennings Geräten.

## Abnahme

- Stufe 1 Tests: neue Tests vorher rot (Ziel baut nicht bzw. Gruppe fehlt), danach grün über `./scripts/sim.sh sim-unit AccountSectionTests`, `./scripts/sim.sh test-proof AccountSettingsTests`, voller `sim-unit`.
- Stufe 2 Simulator: App bauen, starten mit `--ui-testing`, Einstellungen öffnen, den Ablauf als Nutzer durchspielen (anmelden, abmelden, löschen mit Abbrechen und Bestätigen, die zwei Fehlerausgänge) und Screenshots öffnen und beschreiben; in der App ohne `--ui-testing` ist die Gruppe nicht zu sehen (Fallback aus), auch das wird gezeigt.
- Stufe 3 Gerät: keine. Kein Pfad der Geräteliste berührt (`LooseEnds/Views/`, `LooseEnds/Claude/` und `LooseEnds/App/` stehen nicht darin; kein `project.yml`, keine Entitlements, keine `Info.plist`). Der Abschlussbericht begründet das mit genau dem Satz: „Kein Pfad der Geräteliste berührt.“

## Definition of Done

- [ ] AC-1 bis AC-15 erfüllt; AC-1 bis AC-11 als dauerhafte Tests, AC-12 als Skriptlauf, AC-13 und AC-14 als einmalige Belege im Validierungsprotokoll von `/60-validate` (kein dauerhafter Diff- oder grep-Test), AC-15 als Läufe
- [ ] `./scripts/sim.sh sim-unit`, `build`, `mac-build`, `test-proof AccountSettingsTests` grün, CI auf dem PR grün
- [ ] Kein Pfad der Geräteliste berührt; Abnahme endet nach Stufe 2, im Abschlussbericht mit genau diesem Satz
- [ ] Abschlussbericht benennt: echter Apple-Weg und echter Schlüsselbund über die App unbelegt bis 4c-2; Gruppe in jedem echten Bau verborgen (gewollt); die zwei abgeleiteten Zeilen („Konto wird gelöscht …“)
- [ ] #615 kommentiert (Stand 4c-1: Gruppe und Verdrahtung gegen Ersatz gebaut, in echten Bauten verborgen; Folge 4c-2), Board-Karte aktuell
- [ ] Abschlussbericht ohne Git-Vokabular: sichtbar ist in Hennings App noch nichts, er muss nichts tun

## Changelog

- 2026-11-09: Initial spec created (Schnitt 4c-1, Teil-Spec)
- 2026-11-10: AC-8 für `signingIn` ersetzt durch AC-1 von `docs/specs/feat-615-schnitt-4c2b-knopf-adresse.md` (Schnitt 4c-2b, F001): der Apple-Knopf bleibt während der Anmeldung sichtbar und deaktiviert; für `deleting` und die Angemeldet-Zeilen gilt AC-8 weiter.
