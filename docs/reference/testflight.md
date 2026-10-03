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
2. Etwa 15 Minuten bis zum Upload, danach bis zu 45 Minuten Wartezeit im zweiten Job. Der Lauf hat zwei
   Jobs: „Archive and upload (iOS)" grün heißt nur hochgeladen. „Confirm Apple processed the build"
   wartet danach bis zu 45 Minuten und ist erst grün, wenn App Store Connect den Build als `VALID`
   meldet; sein Protokoll nennt `build=<Nummer> processingState=… uploadedDate=…`.
3. Zur Kontrolle in der Oberfläche: Unter https://appstoreconnect.apple.com → **Loose Ends → TestFlight** erscheint der Build,
   erst mit "Wird verarbeitet", nach 10 bis 30 Minuten bereit. Die Export-Compliance-Frage
   stellt Apple nicht, das steht schon in der App (keine eigene Verschlüsselung).

Fehlt auf dem Runner Xcode 27.0, bricht der Lauf gleich am Anfang mit klarer Meldung ab, statt
still mit einer älteren oder Beta-Version zu bauen (siehe „Wenn es hakt").

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
- **Lauf bricht mit „Expected Xcode 27.0" ab**: Das Image liefert unter
  `/Applications/Xcode_27.app` nicht mehr Xcode 27.0 (Image-Update oder anderes Label). Im Readme
  des Images nachsehen, wo 27.0 jetzt liegt, und Pfad oder `runs-on` in `testflight.yml` anpassen.
  Nicht auf eine Beta oder ältere Version ausweichen.
- **Nachweisschritt rot**: Die Tabelle nennt Ziel und Abweichung (SDK, Mindestversion,
  Versionsnummer, dSYM, Datenschutztext). Sie steht in der Zusammenfassung des Laufs und im
  Protokoll des Schritts (`gh run view <id> --log`). Der Upload ist dann nicht gelaufen.
- **Job „Confirm Apple processed the build" rot mit `INVALID` oder `FAILED`**: Apple hat den Build
  angenommen, aber nicht verarbeitet. Den Grund nennen die E-Mail von Apple und App Store Connect
  unter dem Build. Der Upload-Job war trotzdem grün.
- **Job „Confirm …" rot mit „not VALID after 45 min"**: Die Verarbeitung dauerte länger als
  45 Minuten. In App Store Connect nachsehen; den Job neu zu starten ist nicht nötig, der Build
  kommt gegebenenfalls später an.
- **Job „Confirm …" rot mit HTTP 401 oder 403**: Schlüssel-ID, Aussteller-ID oder privater
  Schlüssel stimmen nicht, oder die Rolle des Schlüssels darf keine Builds lesen.
- Die Logs jedes Laufs liegen als `testflight-logs` unter dem Lauf in GitHub Actions.

## Was der Workflow tut

`.github/workflows/testflight.yml` läuft auf dem Runner-Label `xcode-27` (Vorschau-Image von
GitHub) und wählt dort fest Xcode 27.0 (`/Applications/Xcode_27.app`), nicht die neueste Version;
die Build-Kennung wird nur protokolliert. Die Deployment-Ziele aus `project.yml` werden nicht mehr
abgesenkt. Dann: Projekt generieren, mit `xcodebuild archive` und Apple-verwalteter Signatur
(`-allowProvisioningUpdates` plus API-Schlüssel) archivieren, mit `-exportArchive` direkt zu App
Store Connect hochladen. Die Build-Nummer ist die laufende Nummer des Workflow-Laufs; die
Versionsnummer steht in `project.yml` (`MARKETING_VERSION`).

Zwischen Archiv und Upload prüft der Schritt „Verify the archive is built against the iOS 27 SDK"
App, Watch-App, Widgets und Teilen-Erweiterung (gefunden über ihre Bundle-Kennung): SDK
(`iphoneos27.`/`watchos27.`), Mindestversion 27.0, Version `0.1.0 (<Lauf-Nummer>)`, dSYM im
Archiv, Datenschutz-Zweckbeschreibungen nicht leer, `ITSAppUsesNonExemptEncryption` = `false`. Das
Ergebnis steht als Tabelle in der Zusammenfassung des Laufs und im Protokoll des Schritts (abrufbar
mit `gh run view <id> --log`); jede Abweichung stoppt den Upload.

Nach dem Upload läuft der Job `confirm` („Confirm Apple processed the build") auf `ubuntu-latest`.
Er ruft `scripts/asc_wait_build.py` mit der Lauf-Nummer auf: Das Skript ermittelt über die App
Store Connect API die App zur Bundle-Kennung, fragt alle 30 Sekunden den Build mit dieser Nummer ab
und schreibt je Runde `build=<Nummer> processingState=<…> uploadedDate=<…>` ins Protokoll
(`processingState=nicht-gelistet`, solange Apple ihn noch nicht führt). Grün nur bei `VALID`; rot bei
`INVALID`, `FAILED`, nach 45 Minuten ohne `VALID` und bei abgelehntem Schlüssel. Schlägt nur dieser
Job fehl, bleibt der Upload-Job grün, der Lauf insgesamt wird rot. Lokal ist die Abfrage nicht
möglich (der Schlüssel liegt nur in den Secrets); lokal laufen nur die Tests
`python3 scripts/test_asc_wait_build.py`.

Die Mac-App kommt in einem späteren Schritt dazu (eigenes Archiv, eigener TestFlight-Eintrag).

## Wenn das Vorschau-Image wegfällt oder umbenannt wird

Das Label `xcode-27` ist eine Vorschau. Fällt es weg oder wird es umbenannt, startet der Lauf nicht
(kein passender Runner). Dann im README der Runner-Images
(https://github.com/actions/runner-images, Abschnitt Xcode 27) das aktuelle Label nachschlagen,
`runs-on` in `testflight.yml` anpassen, Lauf neu starten. Hat `macos-26` oder ein Nachfolger
Xcode 27.0 als Standard, wechselt das Label dorthin. Versionsprüfung und Nachweisschritt bleiben.

## Notweg: lokaler Archiv-Lauf

Nur wenn kein Runner Xcode 27.0 liefert. Auf Hennings Mac mit Xcode 27.0, dieselben Befehle wie im
Workflow (`archive`, dann `-exportArchive`), **ausschließlich mit eigenem ASC-Schlüssel**
(`-authenticationKeyPath`, `-authenticationKeyID`, `-authenticationKeyIssuerID`), nie mit der
Anmeldung in Xcode (#156). `CURRENT_PROJECT_VERSION` muss über der letzten Build-Nummer der CI
liegen, sonst lehnt App Store Connect den Upload als Dublette ab. Vor dem Export den Block des
Nachweisschritts aus `testflight.yml` lokal gegen das Archiv laufen lassen, mit
`ARCHIVE=<Pfad zum .xcarchive> BUILD=<Nummer>`; erst bei vier Zeilen „OK" hochladen.

## Prüfbauten fürs iPhone (#156)

`./scripts/sim.sh device-build` und `./scripts/sim.sh lab` signieren nur mit den Profilen, die auf
dem Mac schon gespeichert sind, und sprechen dabei nicht mit Apple. So kann der Bau die Anmeldung in
Xcode nicht abmelden. Für eine neue Kennung, eine neue Fähigkeit oder nach Ablauf eines Profils läuft
einmal `LOOSEENDS_REGISTER=1 ./scripts/sim.sh device-build` (bzw. `… lab`): Dieser Lauf benutzt die
Anmeldung in Xcode und legt Kennungen und Profile an. Der API-Schlüssel reicht dafür nicht, weil
xcodebuild mit ihm keine neuen Entwicklungsprofile anlegen kann.
