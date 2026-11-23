# App-Store-Datenschutzangaben

Vorlage für Apples Datenschutz-Etikett („App Privacy“) in App Store Connect (#625 Schnitt 3,
`docs/specs/feat-625-schnitt-3-fragebogen.md`, Analyse `docs/context/feat-625-s3-fragebogen.md`). Sie hält fest, was
bei eingeschaltetem Konto (Verbindung zu Claude) anzukreuzen ist und was bewusst nicht, jeweils mit Grund. Die Tabelle
unter „Antworten mit Konto“ folgt `ACCOUNT_TYPES` in `scripts/privacy_manifest.py`, der einen Quelle auch für das
Manifest der Konto-Bauten; `scripts/test_app_store_datenschutzangaben.py` hält beide gleich. Apples Begriffe stehen auf
Englisch, wie in Apples Dokumentation; die deutschen Beschriftungen in App Store Connect sind nicht belegt und stehen
nur als „vermutlich“ da. Der Wortlaut ist Grundlage einer Rechtsaussage und wird erst nach Hennings Freigabe eingetragen.

## Stand heute

Das Store-Etikett lautet „Data Not Collected“ (vermutlich deutsch „Keine Daten erhoben“). Das Etikett gilt app-weit,
für alle Plattformen und Versionen zugleich, und es stimmt, solange der Konto-Schalter `LEAccountEnabled` aus ist.
Seit #625 S5b steht er an der Quelle an (`project.yml` hält `true`) und das Manifest trägt die drei Typen unten; das
Etikett „Data Not Collected“ gilt damit nur noch für Bauten vor S5b und muss mit der Einreichung (#625 S5d) auf die
Typen unten umgestellt werden. Früher (#625 S2) hatten Store-Bauten ein leeres Manifest und nur der TestFlight-Lauf mit dem
Eingang `konto` schaltete die Gruppe „Claude“ ein; Rückbau dieser CI-Mechanik in S5c.

## Antworten mit Konto

Mit eingeschaltetem Konto sind genau diese drei Typen anzugeben, je mit der Identität des Nutzers verknüpft, ohne
Tracking und nur für die Funktion der App (App Functionality):

| Manifest-Schlüssel | Apple-Typ (ASC, englisch) | Verknüpft | Tracking | Zweck | Beleg im Code |
|---|---|---|---|---|---|
| `NSPrivacyCollectedDataTypeUserID` | Identifiers › User ID | ja | nein | `NSPrivacyCollectedDataTypePurposeAppFunctionality` | Apple-Kennung (`apple_sub`) als Konto-Schlüssel: `server/migrations/002_accounts.sql`, `server/src/accounts.ts` (`admit`), `server/src/auth.ts` (`POST /auth/apple`) |
| `NSPrivacyCollectedDataTypeDeviceID` | Identifiers › Device ID | ja | nein | `NSPrivacyCollectedDataTypePurposeAppFunctionality` | Kennung dieser Installation (`X-Device`, zufällige UUID): `LooseEnds/Claude/DeviceIdentity.swift`, `LooseEnds/Claude/ServiceClient.swift` (`claimOrder`, `putResult`, `putDevice`), `server/src/orders.ts`; APNs-Gerätetoken für den Weckruf: `LooseEnds/Claude/DeviceRegistration.swift`, `server/migrations/008_device_tokens.sql`, `server/src/devices.ts` |
| `NSPrivacyCollectedDataTypeOtherUserContent` | User Content › Other User Content | ja | nein | `NSPrivacyCollectedDataTypePurposeAppFunctionality` | Abschrift offener Aufgaben: `Shared/Services/TranscriptCodec.swift`, `server/src/transcripts.ts`, `docs/reference/claude-abschrift-vertrag.md`; Aufträge aus Claude mit Inhalt und Ergebnis: `server/migrations/001_claude_schema.sql` (`orders`, `order_results`), `server/src/mcp.ts` |

Verknüpft heißt hier: Jeder Wert hängt am Konto, das „Konto löschen“ samt Abschrift, Aufträgen, Ergebnissen und
Gerätetoken entfernt (`server/src/accounts.ts`, `deleteAccount`). Tracking gibt es nicht: keine Werbung, keine
Weitergabe an Dritte, keine Verknüpfung mit fremden Daten. Andere Zwecke (Analytics, Product Personalization, Third-Party
Advertising, Developer's Advertising or Marketing, Other Purposes) treffen auf keinen Typ zu.

## Bewusst nicht angegeben

- **Name und E-Mail-Adresse (Contact Info):** Die App fragt bei der Anmeldung mit Apple keine Angaben an
  (`requestedScopes = []` in `LooseEnds/Views/AccountSection.swift`); der Dienst speichert nur `apple_sub` und die
  Anlagezeit.
- **Standort (Location):** Orte, Ortssuche und Ortserinnerungen laufen auf dem Gerät und über Apple Karten
  (`LooseEnds/Places`); nichts davon steht in der Abschrift oder erreicht den Dienst.
- **Kontakte (Contacts):** Die App hat keinen Zugriff auf Kontakte (kein `NSContactsUsageDescription`, kein
  `import Contacts`).
- **Fotos und Dateien (Photos or Videos, Other User Content als Anhang):** Anhänge bleiben auf dem Gerät und im
  privaten iCloud des Nutzers; die Abschrift enthält keine Anhänge (`docs/reference/claude-abschrift-vertrag.md`).
- **Rohtext und Notizen außerhalb der Abschrift:** Die Abschrift enthält laut Vertrag „keinen Rohtext, keine Notiz,
  keine Anhänge und keine Revisionen“; `server/src/transcripts.ts` weist `rawText` und `note` ab. Was Claude selbst
  per Auftrag schreibt, ist unter Other User Content schon angegeben.
- **Absturz- und Leistungsdaten (Diagnostics):** Nur Apple erhebt sie über die eigenen Absturzberichte; laut Apple ist
  der Entwickler dafür nicht zuständig („You are not responsible for disclosing data collected by Apple.“). Die App
  sendet keine eigenen Diagnosedaten.
- **Nutzungsanalyse (Usage Data, Analytics):** Es gibt keine Nutzungsanalyse und keine Fremd-SDKs (`project.yml` ohne
  `packages`-Abschnitt).
- **Privates iCloud (CloudKit):** Aufgaben liegen in der privaten iCloud-Datenbank des Nutzers; der Entwickler kann sie
  nicht lesen, sie gelten deshalb nicht als erhoben. Das ist gängige Auslegung, steht aber nicht wörtlich auf Apples
  Seite (Apple nennt CloudKit nur als Beispiel, wenn der Entwickler daraus Daten erhebt); Henning gibt sie mit dem
  Wortlaut frei.
- **Anmeldung mit Apple selbst:** Was Apple bei „Sign in with Apple“ erhebt, erhebt Apple, nicht wir; angegeben ist nur,
  was unser Dienst davon behält (User ID).
- **IP-Adresse im nginx-Protokoll, 14 Tage:** kein eigener Typ. Apple schreibt: „Declare the relevant data types based
  on how you use IP address, such as precise location, coarse location, device ID, or diagnostics.“ Die Adresse steht
  14 Tage im nginx-Protokoll auf `rennwienix` (`rotate 14`) und dient nur Fehlersuche und Missbrauchsabwehr (App
  Functionality); wir leiten daraus weder einen Standort noch Diagnosedaten ab, und Device ID mit Zweck App
  Functionality ist ohnehin angegeben.

## Zeitpunkt und Ablauf

Eingetragen wird erst mit dem Schalter-Schnitt (`LEAccountEnabled` an), im selben Zug wie die Einreichung, nie vorher:
Die Antworten gelten app-weit und wirken sofort, und die laufende Store-Version 1.0.x erhebt nichts. Pflicht ist die
Eintragung vor jeder Einreichung mit eingeschaltetem Konto.

Es gibt keine offizielle App-Store-Connect-API für diese Angaben, also geht es nur im ASC-Web: Claude öffnet die Seite
„App Privacy“ in Hennings Browser, Henning meldet sich nur an (wie beim CloudKit-Deploy), Claude trägt ein und prüft
die Vorschau gegen diese Vorlage. Eingetragen wird nur nach Hennings ausdrücklichem Ja zum Wortlaut dieser Vorlage; die
Auto-Ampel reicht nicht, weil es eine Rechtsaussage ist.

## Quellen

- https://developer.apple.com/support/app-privacy-on-the-app-store (gelesen 2026-11-21): Definitionen von User ID,
  Device ID, Other User Content, App Functionality, „collect“ (Übertragung aus der App, die länger gespeichert wird,
  als für die Echtzeit-Antwort nötig), der Satz zu von Apple erhobenen Daten und der Absatz zu IP-Adressen.
- `scripts/privacy_manifest.py` (`ACCOUNT_TYPES`), die eine Quelle für Manifest und diese Tabelle.
- `docs/reference/datenschutz-entwurf.md`, Abschnitt „Beleg im Code“.
