# Loose Ends auf dem iPhone: TestFlight einrichten

Einmalige Einrichtung, etwa 30 Minuten. Danach bringt ein Klick in GitHub jede neue Version
aufs iPhone. Die Schritte 1 bis 4 kann nur der Inhaber des Apple-Developer-Accounts machen.

Was am Ende passiert: GitHub baut die App, signiert sie mit einem von Apple verwalteten
Zertifikat und lädt sie zu TestFlight hoch. Du installierst sie über die TestFlight-App.

## 1. Apple Developer Program

- Mitgliedschaft unter https://developer.apple.com/programs/ (99 € pro Jahr).
- Unter https://developer.apple.com/account → **Membership details** steht die **Team ID**
  (zehn Zeichen, zum Beispiel `AB12CD34EF`). Notieren.

## 2. App-Kennung und App-Eintrag anlegen

Unter https://developer.apple.com/account/resources/identifiers/list:

1. **Identifiers → +** → **App IDs** → **App** → Continue.
   - Description: `Loose Ends`
   - Bundle ID: **Explicit**, `com.henning.looseends`
   - Capabilities anhaken: **App Groups**, **iCloud** (mit CloudKit), **Siri**.
   - Continue → Register.
2. **Identifiers → +** → **App Groups**: Description `Loose Ends`, Identifier
   `group.com.henning.looseends` → Register.
3. **Identifiers → +** → **iCloud Containers**: Description `Loose Ends`, Identifier
   `iCloud.com.henning.looseends` → Register.
4. Die App ID `com.henning.looseends` öffnen → bei **App Groups** und **iCloud** auf
   **Configure** → die beiden gerade angelegten Einträge auswählen → Save.

Unter https://appstoreconnect.apple.com/apps:

5. **Meine Apps → +** → **Neue App**:
   - Plattformen: **iOS**
   - Name: `Loose Ends`
   - Hauptsprache: Deutsch
   - Bundle-ID: `com.henning.looseends` (aus der Liste)
   - SKU: `looseends`
   - Zugriff: Vollzugriff
   - Erstellen.

Die Kennungen für Watch-App, Widgets und Teilen-Erweiterung legt der Build beim ersten
Lauf selbst an.

## 3. API-Schlüssel für GitHub

Unter https://appstoreconnect.apple.com/access/integrations/api:

1. **Benutzer und Zugriff → Integrationen → App Store Connect API → Teamschlüssel**.
   Beim ersten Mal: **Zugriff anfordern** bestätigen.
2. **+** (Schlüssel generieren): Name `GitHub TestFlight`, Zugriff **Admin** → Generieren.
   **App-Manager reicht nicht:** Cloud-verwaltete Signierung (`-allowProvisioningUpdates`) braucht
   Entwicklerportal-Zugriff (Zertifikate/Profile), den nur **Admin** hat. Mit App-Manager schlägt der
   Export mit "Cloud signing permission error" fehl.
3. **API-Schlüssel herunterladen**. Das geht **nur einmal**; die Datei heißt
   `AuthKey_XXXXXXXXXX.p8`. Sicher ablegen (zum Beispiel im Schlüsselbund als sichere Notiz).
4. Auf derselben Seite stehen die **Aussteller-ID** (Issuer ID, eine lange UUID) und die
   **Schlüssel-ID** (Key ID, zehn Zeichen). Beide notieren.

## 4. Vier Secrets in GitHub eintragen

Unter https://github.com/henemm/loose-ends/settings/secrets/actions → **New repository secret**,
viermal:

| Name | Wert |
|------|------|
| `APPLE_TEAM_ID` | die Team ID aus Schritt 1 |
| `ASC_KEY_ID` | die Schlüssel-ID aus Schritt 3 |
| `ASC_ISSUER_ID` | die Aussteller-ID aus Schritt 3 |
| `ASC_PRIVATE_KEY` | der komplette Inhalt der `.p8`-Datei, inklusive der Zeilen `-----BEGIN PRIVATE KEY-----` und `-----END PRIVATE KEY-----` |

Die `.p8`-Datei mit einem Texteditor öffnen (nicht mit Xcode), alles markieren, kopieren,
einfügen. Die Datei selbst kommt **nie** ins Repository.

## 5. Build starten

1. https://github.com/henemm/loose-ends/actions → links **TestFlight** → rechts **Run workflow**
   → Branch `main` → **Run workflow**.
2. Etwa 15 Minuten warten. Grün heißt: hochgeladen.
3. Unter https://appstoreconnect.apple.com → **Loose Ends → TestFlight** erscheint der Build,
   erst mit "Wird verarbeitet", nach 10 bis 30 Minuten bereit. Die Export-Compliance-Frage
   stellt Apple nicht, das steht schon in der App (keine eigene Verschlüsselung).

## 6. Auf dem iPhone installieren

1. In App Store Connect → **TestFlight → Interne Tests → +** → Gruppe `Familie` anlegen,
   dich selbst als Tester hinzufügen (deine Apple-ID muss in **Benutzer und Zugriff** stehen).
2. Auf dem iPhone die App **TestFlight** aus dem App Store laden, mit derselben Apple-ID
   anmelden, Einladung annehmen, **Loose Ends** installieren.
3. Jeder weitere Build aus Schritt 5 landet automatisch bei den internen Testern.

## Wenn es hakt

- **"No profiles for 'com.henning.looseends' were found"** oder ein Fehler mit
  *entitlement*: Schritt 2 prüfen, vor allem ob App Group und iCloud-Container an der App ID
  hängen. Dann den Workflow erneut starten.
- **"Unable to authenticate"**: eines der vier Secrets stimmt nicht. Am häufigsten fehlt beim
  privaten Schlüssel eine der BEGIN/END-Zeilen.
- **Build erscheint nicht in TestFlight**: unter App Store Connect → Loose Ends → TestFlight →
  nach "Wird verarbeitet" schauen; eine E-Mail von Apple nennt sonst den Grund.
- Die Logs jedes Laufs liegen als `testflight-logs` unter dem Lauf in GitHub Actions.

## Was der Workflow tut

`.github/workflows/testflight.yml`: Projekt generieren, mit `xcodebuild archive` und
Apple-verwalteter Signatur (`-allowProvisioningUpdates` plus API-Schlüssel) archivieren, mit
`-exportArchive` direkt zu App Store Connect hochladen. Die Build-Nummer ist die laufende
Nummer des Workflow-Laufs; die Versionsnummer steht in `project.yml` (`MARKETING_VERSION`).
Die Mac-App kommt in einem späteren Schritt dazu (eigenes Archiv, eigener TestFlight-Eintrag).
