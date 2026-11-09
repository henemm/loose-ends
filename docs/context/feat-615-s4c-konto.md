# Context: feat-615-s4c-konto (#615 Schnitt 4c)

## Request Summary
Die Einstellungen der App (iPhone, iPad, Mac) bekommen eine Gruppe „Konto“: mit Apple anmelden, abmelden und das Konto
löschen, verdrahtet mit dem fertigen App-Kern aus 4b-1 bis 4b-3. Vor der Spec wird ein Entwurf gezeigt (PO-Regel 2026-09-22).
Die Gruppe ist im Store-Bau verborgen (`LEAccountEnabled` aus), bis der Konto-Teil des Datenschutztextes online steht (4d).

Gesamtanalyse und Schnittplan stehen in `docs/context/feat-615-s4-app-anmeldung.md` (2026-11-08); dieses Dokument ergänzt nur,
was für 4c seither feststeht.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Claude/AccountState.swift` (157 Z.) | `@MainActor @Observable`; `status` (`signedOut`, `signingIn`, `signedIn`, `deleting`, `notAllowed`, `retryLater`), `lastProblem`; `beginSignIn() -> hashed nonce`, `completeSignIn(identityToken:code:)`, `cancelSignIn()`, `signOut()`, `deleteAccount()`. Liest die Ablage einmal im `init`, sendet nichts. Die Oberfläche liest nur ihn |
| `LooseEnds/Claude/ServiceClient.swift` | `init(baseURL:transport:)`; `HTTPTransport` austauschbar → fester Ersatz unter `--ui-testing` |
| `LooseEnds/Claude/SessionStore.swift`, `KeychainSessionStore.swift` | `SessionStoring`; `InMemorySessionStore` (Ersatz) und `KeychainSessionStore` (echt, nur dieses Gerät). Die Wahl der Ablage an einer Stelle (`forApp`) fehlt noch |
| `LooseEnds/Claude/Nonce.swift` | roh 32 Byte base64url, `hashed` SHA-256 hex für `ASAuthorizationAppleIDRequest.nonce` |
| `LooseEnds/Views/SettingsView.swift` (372 Z.) | Ort der Gruppe; `group(title, hint:rows:)` (iOS `Section`, Mac Papierzeilen #478), Reihenfolge Benachrichtigungen → Loose ends → iCloud (iOS) → Kalender → Aufgabe → Menüleiste (Mac) → Über. Konto gehört vermutlich neben iCloud (Datenfluss nach außen), Lage im Entwurf zeigen |
| `LooseEnds/App/LooseEndsApp.swift`, `ContentView.swift` | wo `AccountState` entsteht und in die Umgebung kommt (Muster `FieldSettingsStore`, `SyncStatus.shared`) |
| `LooseEnds/App/FieldSettingsStore.swift` | Muster für `--ui-testing`-Schalter mit eigenen Argumenten |
| `LooseEndsUITests/SettingsSmokeTests.swift` | bestehender UI-Smoke der Einstellungen; Muster für den neuen Test |
| `project.yml` (App-Target Z. 49ff., Info Z. 73ff.) | neu: `com.apple.developer.applesignin: [Default]`; Info `LEServiceURL`, `LEAccountEnabled`. `network.client` ist schon da (Mac-Sandbox) |
| `LooseEnds/Resources/Localizable.xcstrings` | Texte de/en; `scripts/test_catalog_languages.py` |
| `docs/artifacts/feat-478-mac-einstellungen-papier/` | frühere Einstellungs-Entwürfe: Farben und Papierstil des Mac als Vorlage für die Vorschau |
| `server/src/auth.ts` | Vertrag: `POST /auth/apple` `{identityToken, nonce, code}` → 200 `{sessionToken}`; 401 nackt, 503 nur Apple unerreichbar |

## Existing Patterns
- Reine Regel getrennt von Systemverdrahtung (`SyncStatus.summary`, `ListeningHint`): Zustand liegt schon rein in `AccountState`;
  die View bildet nur `status` auf Zeilen ab, Apple-Verdrahtung (`SignInWithAppleButton` bzw. `ASAuthorizationController`) dünn.
- Systemteile unter `--ui-testing` mit festen Antworten (`PlaceSearch`, `CurrentLocation`, `--ui-testing-location-refused`):
  für Konto Ersatz-Transport und `InMemorySessionStore`, Apple-Dialog übersprungen, Ausgänge per Argument (zugelassen, nicht zugelassen, später nochmal).
- Kennungen per Info-Schlüssel mit Fallback-Konstante (`LEAppGroup`): `LEServiceURL` analog, Standard `https://loose-ends.henemm.com`.
- Destruktive Aktion mit Bestätigung (`confirmationDialog`, z. B. Löschen im Aufgabenmenü).

## Dependencies
- Upstream: App-Kern 4b (fertig, ohne Aufrufer), `AuthenticationServices`, Dienst-Routen (live, aber nginx lässt `/auth/*` erst in 4d durch).
- Downstream: 4d (nginx, `APPLE_CLIENT_IDS`, Datenschutztext, Schalter im Store-Bau an), #795 (Abschrift senden braucht die Sitzung).

## Existing Specs
- `docs/specs/feat-615-schnitt-4b1-dienst-client.md`, `…-4b2-sitzung.md`, `…-4b3-schluesselbund.md` (Kern); Dienstseite S1–S3.

## Risks & Considerations
- **Live-Dienst nicht erreichbar bis 4d:** nginx gibt `/auth/*` 404. In 4c kann die App gegen den Live-Dienst nicht anmelden; der
  TestFlight-Durchgang (Stufe 3) mit echtem Ende-zu-Ende braucht 4d vorher oder im selben Zug. In der Analyse klären: Reihenfolge 4c/4d
  oder Stufe 3 erst nach 4d.
- **Sign in with Apple im Simulator unzuverlässig** (Recherche 2026-11-08): UI-Test nur gegen Ersatz; echter Ablauf in Stufe 3.
- **Echter Schlüsselbund-Beleg** im Simulator über die App ist in 4b-3 zugesagt (Unit-Host liefert `-34018`).
- **Mac-CI ohne Profil** (`MacDetailClickTests`) liefert `-34018` beim Schlüsselbund: unter `--ui-testing` Ersatz im Speicher.
- **Signierung:** neue Fähigkeit in `project.yml` → Cloud-Signierung der TestFlight-CI und Prüfbau-Kennung `.probe` müssen sie tragen
  (Klasse #307/#311); Archivprüfung `entitled` und `test_entitlements_sync.py` mitziehen.
- **Store-Bau:** `LEAccountEnabled` aus; nur TestFlight an. Wie TestFlight- und Store-Bau sich unterscheiden (gleiches Archiv?) ist zu klären;
  sonst sieht der Store die Gruppe mit demselben Bau. Alternative: Schalter per Build-Einstellung im TestFlight-Workflow.
- **Umfang:** View + Verdrahtung + Ersatz + `project.yml` + Texte + UI-Test liegt nahe ±250 LoC → evtl. 4c-1 (Gruppe, Anmelden/Abmelden, Ersatz, UI-Test)
  und 4c-2 (Löschen mit Bestätigung, Berechtigung, Schalter).
- **Datenschutz:** Knopf im Store erst nach dem Text (Henning 2026-11-08).

## Analysis

### Type
Feature (sichtbare UI; Entwurf vor Spec, `docs/artifacts/feat-615-s4c-konto/`).

### Recherche (2026-11-09)
- TestFlight und Store teilen dasselbe Archiv: ein Info-Schlüssel kann zwischen beiden nicht unterscheiden.
- Laufzeit-Erkennung über `AppTransaction.environment`: TestFlight meldet `sandbox`, App Review ist laut Forenberichten nicht
  sicher unterscheidbar (https://developer.apple.com/forums/thread/823953, https://developer.apple.com/forums/thread/791170,
  https://developer.apple.com/forums/thread/694461); der Belegname `sandboxReceipt` gilt als veraltet. Für einen Schalter
  „Store aus, TestFlight an“ deshalb untauglich: der Prüfer sähe die Gruppe womöglich und bekäme „nicht freigegeben“.
- Mac: Sign in with Apple ist eine eingeschränkte Berechtigung, im Mac-App-Store über das Profil; mit Sandbox testen
  (https://developer.apple.com/forums/thread/760861, https://github.com/airsdk/Adobe-Runtime-Support/issues/729).
- `SignInWithAppleButton` (SwiftUI, iOS/macOS) liefert `ASAuthorization` mit `identityToken` und `authorizationCode`
  (https://developer.apple.com/documentation/authenticationservices/signinwithapplebutton).

### Entscheidung Schalter (technisch, setzt PO-Vorgabe 2026-11-08 um)
`LEAccountEnabled` in `project.yml` aus. Der TestFlight-Workflow bekommt eine Eingabe `konto` (Standard aus), die den Wert nur für
diesen Bau setzt; „Was testen“ nennt den Bau „nur TestFlight, nicht einreichen“. `asc-store-version.yml anlegen` ordnet einen Bau mit
`LEAccountEnabled` an nie einer Store-Version zu (Prüfung am Bau, harter Abbruch). Unter `--ui-testing` immer an.
Verworfen: Laufzeit-Erkennung (s. o.); „erst nach dem Datenschutztext für alle“ (zeigte Store-Nutzern eine Tür, die sie abweist).

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Views/AccountSection.swift` | CREATE | Gruppe „Claude“: Zeilen je `AccountState.Status`, Apple-Knopf, Abmelden, Löschen mit Bestätigung |
| `LooseEnds/Views/SettingsView.swift` | MODIFY | Gruppe unter iCloud einhängen, nur bei `LEAccountEnabled` |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | `AccountState` einmal bauen (Ablage `forApp`: Schlüsselbund, unter `--ui-testing` Speicher + Ersatz-Transport mit Ausgängen per Argument), in die Umgebung |
| `LooseEnds/Claude/AccountWiring.swift` | CREATE | `forApp`, `LEServiceURL`/`LEAccountEnabled` lesen, Ersatz-Transport für UI-Tests |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Texte de/en |
| `LooseEndsUITests/AccountSettingsTests.swift` | CREATE | anmelden → angemeldet, abmelden, löschen mit Bestätigung, „nicht freigegeben“, „später nochmal“ |
| `project.yml` | MODIFY (4c-2) | `com.apple.developer.applesignin`, Info `LEServiceURL`, `LEAccountEnabled` |
| `.github/workflows/testflight.yml`, `scripts/asc_store_version.py` | MODIFY (4c-2) | Eingabe `konto`, Store-Schutz |

### Scope Assessment
- Gesamt ≈ 450–550 LoC → zwei Schnitte:
  - **4c-1** Gruppe und Verdrahtung gegen Ersatz (AccountSection, Wiring, SettingsView, App, Texte, UI-Test), Schlüssel per Fallback
    „aus“, kein `project.yml` → Stufe 2 genügt, Store unverändert. ≈ 250 LoC.
  - **4c-2** Berechtigung, Info-Schlüssel, TestFlight-Eingabe, Store-Schutz; Server-Teil von 4d (nginx `/auth/apple|logout|delete`,
    `APPLE_CLIENT_IDS`) davor; dann Stufe 3 über TestFlight mit Beleg App-sub = Web-sub. Datenschutztext und Store-Schalter bleiben 4d.
- Risk Level: MEDIUM (Berechtigung/Signierung in 4c-2; öffentliche App, Schalter muss halten).

### Technical Approach
Die View liest nur `AccountState.status`; Apple-Knopf `SignInWithAppleButton` (offizielle Gestaltung, HIG schreibt sie vor), `onRequest`
setzt `nonce = beginSignIn()`, `onCompletion` reicht Token und Code an `completeSignIn`, Abbruch → `cancelSignIn`. Abmelden ohne
Rückfrage, Löschen nur nach `confirmationDialog` (rot nur dort als Systemrolle `.destructive`, Farbbudget). Kein Netzaufruf ohne Tippen
(ADR-21): `AccountState.init` liest nur die Ablage. Unter `--ui-testing` ersetzt ein fester Transport den Dienst und ein Testknopf den
Apple-Dialog (Simulator unzuverlässig).

### Alternativen
- **B: eigene Seite „Claude“** statt Gruppe: eine Zeile in den Einstellungen öffnet eine Seite mit Erklärung und Konto (im Entwurf gezeigt).
- **C: Web-Anmeldung** (`ASWebAuthenticationSession` gegen `/oauth`) statt nativer Berechtigung; kippt den Vertrag S3 `/auth/apple`. Verworfen in S4-Analyse, bleibt Rückfall, falls die Mac-Berechtigung in 4c-2 scheitert.

### Open Questions
- [x] PO (Henning, 2026-11-09): Entwurf A freigegeben (Gruppe „Claude“ direkt unter iCloud, Mac nach dem iCloud-Eintrag), Name und Wortlaut wie im Entwurf.
- Entwurf veröffentlicht 2026-11-09: https://claude.ai/artifact/SEuECJcAeasUXiQbN81qM5 (Quelle `docs/artifacts/feat-615-s4c-konto/entwurf.html`, Heute-Bilder daneben).
