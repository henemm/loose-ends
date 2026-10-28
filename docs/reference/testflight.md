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
   - Die Watch-Kennung `com.henning.looseends.watchkitapp` trägt seit #355 ebenfalls **Siri**; der CI-Bau hat die
     Fähigkeit beim ersten Archiv mit der Berechtigung selbst angelegt (TestFlight-Build 54).
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

## 5a. CloudKit-Schema vor jedem Build mit Modelländerung (#175)

TestFlight spricht mit der CloudKit-Umgebung **Production**, Xcode-Läufe mit **Development**. Production legt kein
Schema von selbst an. Fehlt dort ein Typ oder ein Feld, scheitert der Abgleich der TestFlight-Fassung, sobald dieses
Feld zum ersten Mal einen Wert hat. Development legt Felder nur an, wenn ein Datensatz sie mit Wert schreibt, und ist
deshalb fast immer lückenhaft.

**Seit #448 über die CI, ohne Hennings Mac.** Das Schema steht als Datei in `cloudkit/schema.ckdb`. Wer ein Feld oder
einen Typ ins Modell bringt, ergänzt es dort im selben PR. Ein Unit-Test prüft, dass kein Modellfeld fehlt. Nach dem
Merge schreibt `.github/workflows/cloudkit-schema.yml` die Datei mit `cktool import-schema` nach Development. Den Schritt
nach Production lässt Apple nur in der Console zu (`cktool` kann es nicht): Henning klickt dort **Deploy Schema Changes**,
und erst danach startet der Build. Den aktuellen Stand liest der Workflow mit `export-production` bzw. `export-development`.
Er braucht das Secret `CLOUDKIT_MANAGEMENT_TOKEN`: einmalig in der Console unter Settings → Tokens → Management Token
angelegt und mit `gh secret set` hinterlegt. Der Token gilt ein Jahr. Modelländerungen werden gebündelt, damit Henning
selten klicken muss.

**Schranke vor jedem TestFlight-Build (#268).** Der TestFlight-Lauf beginnt mit dem Job `schema-check`
(„Production knows the CloudKit schema"). Er liest Production mit `cktool export-schema --environment production` und
vergleicht mit `scripts/check_cloudkit_production.py`, ob jeder Typ und jedes Feld aus `cloudkit/schema.ckdb` dort steht
(nur Namen; mehr in Production ist erlaubt). Fehlt etwas, wird weder iOS noch Mac archiviert oder hochgeladen. Es gibt
keinen Notausgang: kein Eingabefeld, keinen Schalter. Drei Meldungen, alle als `::error::`:

- **„Secret CLOUDKIT_MANAGEMENT_TOKEN fehlt"**: den Token wie oben anlegen und mit `gh secret set` hinterlegen.
- **„Production-Schema nicht lesbar"**: Netz, abgelaufener Token oder fehlende Berechtigung. Der Token vom 2026-10-15
  läuft am 2027-10-15 ab; dann einen neuen anlegen und das Secret ersetzen. Ein nicht prüfbarer Stand ist kein grüner Stand.
- **„CloudKit Production kennt diese Typen/Felder … nicht"** mit der Liste (`record type CD_<Typ>` bzw.
  `CD_<Typ>.CD_<feld>`): Weg nach dem Halt: Abbild im selben PR ergänzen, nach dem Merge importiert die CI es nach
  Development, Henning klickt in der CloudKit Console **Deploy Schema Changes**, dann den TestFlight-Lauf wiederholen.

Rückfallweg ohne CI. Bei jeder Änderung an `Shared/Models` (neues Feld, neuer Typ), **bevor** ein TestFlight-Build gestartet wird:

1. `./scripts/sim.sh mac-schema-init`: signierter Mac-Debug-Bau der Hauptkennung, der mit
   `-LEInitializeCloudKitSchema` startet. Er legt das volle Schema aus dem Modell in Development an
   (`initializeCloudKitSchema`) und beendet sich mit 0. Der App-Gruppen-Speicher wird dabei nicht geöffnet. Beim
   ersten Mal oder wenn das Profil abgelaufen ist, läuft er mit `LOOSEENDS_REGISTER=1`.
   Rückfallweg, falls die Mac-Signierung scheitert: der Prüfbau (`.probe`) mit demselben Argument auf dem iPhone,
   danach mit `cktool export-schema` aus Probe-Development und `cktool import-schema` nach Haupt-Development.
2. In der CloudKit Console (Container `iCloud.com.henning.looseends`, Development) die Typen und Felder ansehen.
3. **Deploy Schema Changes** in der Console. Das ist ein Vorgang an Hennings Konto und wird von ihm freigegeben.
4. Danach Production gegen Development vergleichen. Erst dann den Build starten.

**Production ist ab dem ersten Deploy nur noch additiv:** Neue Felder und neue Typen gehen, Löschen und Umbenennen
nicht. Ein Feld, das im Modell umbenannt wird, bleibt in Production als totes Feld stehen. Modelländerungen werden
deshalb als Zusatz geplant, nie als Umbau.

## 5. Build starten

1. https://github.com/henemm/loose-ends/actions → links **TestFlight** → rechts **Run workflow**
   → Branch `main` → Feld **Was testen** ausfüllen → **Run workflow**. Ohne Text bricht der Lauf
   ab (#347); bei einem `v*`-Tag gilt die Nachricht des getaggten Commits.
2. Etwa 15 Minuten bis zum Upload, danach bis zu 45 Minuten Wartezeit im zweiten Job. Der Lauf hat zwei
   Jobs: „Archive and upload (iOS)" grün heißt nur hochgeladen. „Confirm Apple processed the build"
   wartet danach bis zu 45 Minuten und ist erst grün, wenn App Store Connect den Build als `VALID`
   meldet; sein Protokoll nennt `build=<Nummer> processingState=… uploadedDate=… treffer=<k>`.
   Danach trägt er den Text unter „Was testen“ in TestFlight ein (`build=<Nummer> whatToTest gesetzt
   für …`). Der API-Schlüssel braucht dafür die Rolle App Manager oder Admin.
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

Die Testgruppen werden **unter #342 Teil 3** angelegt, nicht unter #176: die interne Gruppe `Familie` (interne Tests) und
die externen Gruppen für die Einladung.

**Prüfliste vor der Einladung (#176):** Bevor externe Tester eingeladen werden, wird
[`abnahme-testflight.md`](abnahme-testflight.md) auf den Build bezogen durchgegangen. Belegte Schritte tragen Ticket und
Buildnummer; die Lücken gehen gebündelt als ein Prüfblock („Was testen“) in einen Build, erst nach Hennings wörtlichem
„jetzt ist ein Test möglich“.

## Einladung: Apple-Seite (#705)

Was Apple vor der ersten externen Einladung braucht. Die Gruppen (oben unter #342 Teil 3 genannt) richtet #705 ein. Status
bleibt `offen` und Beleg leer, bis ein Lauf ihn füllt.

| Teil | Status | Beleg |
|------|--------|-------|
| Exportnachweis | erledigt: `ITSAppUsesNonExemptEncryption=false` in `project.yml`, im Archiv geprüft (Verify-Schritt) | `project.yml`, Verify-Schritt; [Lauf 40387004899](https://github.com/henemm/loose-ends/actions/runs/40387004899) `extern=READY_FOR_BETA_SUBMISSION` (nicht `MISSING_EXPORT_COMPLIANCE`) |
| Beta-App-Beschreibung | erledigt: `de-DE` aus `beta-beschreibung.md` (2026-10-27) | [Lauf 40466472742](https://github.com/henemm/loose-ends/actions/runs/40466472742) `beschreibung=gesetzt`; [Lauf 40466601395](https://github.com/henemm/loose-ends/actions/runs/40466601395) `geschrieben=0` |
| Feedback-E-Mail | erledigt (2026-10-27) | Lauf 40466472742 `feedbackEmail=gesetzt` |
| Kontaktangaben (Beta-Review-Detail) | erledigt: vier Felder, `demoAccountRequired=aus` (2026-10-27) | Lauf 40466472742 `contactFirstName…contactEmail=gesetzt` |
| Datenschutz-URL | erledigt: https://www.henemm.com/legal/loose-ends/privacy-policy/ veröffentlicht und bei Apple gesetzt, Repo-Variable `ASC_PRIVACY_POLICY_URL` (2026-10-27) | [Lauf 40583033733](https://github.com/henemm/loose-ends/actions/runs/40583033733) `lokalisierung locale=de-DE beschreibung=unverändert feedbackEmail=unverändert datenschutzUrl=gesetzt`, `zusammenfassung geschrieben=1`, Probe `datenschutzUrl=gesetzt`, `link=aus` für `Tester`, `einreichung keine`; [Lauf 40583443351](https://github.com/henemm/loose-ends/actions/runs/40583443351) `datenschutzUrl=unverändert`, `geschrieben=0` |
| Interne Gruppe `Familie` | erledigt: besteht, Link aus, Feedback an | Lauf 40387004899; [Lauf 40534641955](https://github.com/henemm/loose-ends/actions/runs/40534641955) `gruppe name=Familie intern=ja` |
| Externe Gruppe `Tester` | erledigt: angelegt 2026-10-27, Link aus, Feedback an | [Lauf 40516649071](https://github.com/henemm/loose-ends/actions/runs/40516649071) `zustand=angelegt` (Zuordnung dort 403, behoben in #721); Lauf 40534641955 `gruppe name=Tester intern=nein link=aus` |
| Öffentlicher Link | offen (Schnitt 2b-2) | |
| Build-Zuordnung iOS und macOS | erledigt: neuester gültiger Build je Plattform (2026-10-27), `extern=READY_FOR_BETA_SUBMISSION` | Lauf 40534641955 `zustand=gesetzt` IOS und MAC_OS, `geschrieben=2`; [Lauf 40535068594](https://github.com/henemm/loose-ends/actions/runs/40535068594) `zustand=vorhanden`, `geschrieben=0` |
| Beta-Review (Einreichung) | offen (Schnitt 2b-2b, Handlauf `einreichen`) | Lauf 40535068594 `einreichung keine` |
| Rückmeldeweg: TestFlight-Feedback | erledigt auf Apples Seite: Gruppe `Tester` `feedback=an` | Lauf 40534641955 |

**Handlauf `asc-beta.yml` (Schnitt 1, nur lesend):** GitHub → Actions → **ASC Beta Probe** → **Run workflow**. Er läuft je
Plattform einmal (Matrix `IOS` und `MAC_OS`, auf `ubuntu-latest`) und schreibt nichts in App Store Connect. Im Log belegen:

- `zugriff abfrage=… http=…`: ob der Schlüssel die Abfrage darf; `befund=` bei 403/404 (kein Zugriff oder Pfad unbekannt).
- `gruppe name=… intern=ja|nein link=an|aus url=… feedback=an|aus`: interne Gruppe `Familie`, externe Gruppe, öffentlicher
  Link, Rückmeldeweg TestFlight-Feedback.
- `lokalisierung locale=… beschreibung=… feedbackEmail=… datenschutzUrl=…`: Beschreibung, Feedback-E-Mail, Datenschutz-URL
  (nur `gesetzt`/`leer`).
- `reviewdetail attribute=…`: Kontaktangaben, Attributnamen und je Feld `gesetzt`/`leer`, nie die Werte.
- `build nummer=… plattform=… processingState=… intern=… extern=… einreichung=…` und `einreichung build=… zustand=…`:
  Build-Zuordnung je Plattform und Beta-Review.
- `zusammenfassung antworten=… von=… befunde=…`: Exit 1 nur, wenn gar keine Abfrage antwortet.

**Handlauf `einrichten` (Schnitt 2a):** GitHub → Actions → **ASC Beta Probe** → **Run workflow** → `aktion=einrichten`.
Der Job `setup` (`scripts/asc_beta_setup.py`) legt die Sprachfassung `de-DE` an oder schreibt nur abweichende Felder:
Beschreibung aus [`beta-beschreibung.md`](beta-beschreibung.md), Feedback-E-Mail und die vier Kontaktfelder des
Review-Details aus den Secrets `ASC_REVIEW_FIRST_NAME`, `ASC_REVIEW_LAST_NAME`, `ASC_REVIEW_PHONE` (mit `+`),
`ASC_REVIEW_EMAIL`, dazu `demoAccountRequired=false`. Kontaktdaten nie als Eingabe: das Repo ist öffentlich, Eingaben stehen
in der Laufansicht. Danach läuft die Probe als Beleg (`beschreibung=gesetzt feedbackEmail=gesetzt`, im `reviewdetail` die
Kontaktfelder `gesetzt`). Ein zweiter Lauf schreibt nichts (`zusammenfassung geschrieben=0`).

- Die Kontaktfelder sind nach dem ersten Setzen bei Apple nicht mehr leerbar, nur überschreibbar.
- `Schlüssel ohne Schreibrecht` (HTTP 403): der API-Schlüssel darf nicht schreiben; Rückfall ist die Oberfläche von App Store
  Connect, nicht das Umgehen.
- Die Datenschutz-URL wird nur gesetzt, wenn die Repo-Variable `ASC_PRIVACY_POLICY_URL` existiert. Sie besteht seit
  2026-10-27 mit dem Wert https://www.henemm.com/legal/loose-ends/privacy-policy/ (#705 Schnitt 2b-2a).

**Handlauf `zuordnen` (Schnitt 2b-1):** GitHub → Actions → **ASC Beta Probe** → **Run workflow** → `aktion=zuordnen`.
Der Job `assign` (`scripts/asc_beta_invite.py`) legt die externe Gruppe `Tester` an, falls sie fehlt (Feedback an, Link
aus), und ordnet ihr je Plattform den neuesten `VALID`-Build zu (`zuordnung plattform=… zustand=gesetzt|vorhanden|kein-gültiger-build
extern=…`). Er reicht **nichts** zum Review ein und schaltet **keinen** Link ein; die Zuordnung ist umkehrbar. Danach läuft
die Probe als Beleg; ein zweiter Lauf schreibt nichts (`zusammenfassung geschrieben=0`).

- Jeder spätere Build braucht wieder einen Lauf `zuordnen` (Automatisierung in `testflight.yml` ist ein Folgeticket).
- `Schlüssel ohne Schreibrecht` (HTTP 403): Rückfall ist die Oberfläche von App Store Connect.

**Handlauf `einreichen` (Schnitt 2b-2b), nicht rücknehmbar, nur nach Hennings Wort:** `aktion=einreichen`. Der Job `submit`
(`scripts/asc_beta_invite.py --einreichen`) ordnet wie `zuordnen` zu und reicht danach genau diesen Build je Plattform einmal
zum Beta-Review ein. Erwartete Zeilen: `einreichung plattform=IOS|MAC_OS zustand=eingereicht review=WAITING_FOR_REVIEW`, beim
zweiten Lauf `zustand=vorhanden` und `geschrieben=0`; sonst `nicht-bereit extern=…`, `kein-gültiger-build` oder `konflikt`
(409). `Beta-Vereinbarung bei Apple fehlt` (422): der Konto-Inhaber nimmt sie in App Store Connect an. Die Watch-App steckt im
iOS-Build und wird mit ihm geprüft; eine eigene watchOS-Einreichung gibt es nicht. Scheitert eine Plattform (Exit 1), ist die
andere womöglich schon eingereicht, und die Probe desselben Laufs fällt aus: danach `aktion=probe` laufen lassen, um den Stand
beider Plattformen zu lesen. Ein unerwarteter Antwortrumpf nach erfolgreicher Einreichung ergibt `review=unbekannt`.

**Schnitt 2:** 2a (Texte und Kontakt), 2b-1 (externe Gruppe, Build-Zuordnung) und 2b-2b (Einreichung) sind die Handläufe
oben. Der öffentliche Link (2b-2c) folgt erst nach `APPROVED`.

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
- **„Your account has reached the maximum number of certificates" / „Choose a certificate to
  revoke"** im Schritt „Archive": Jeder Lauf startet auf einem leeren Runner, Xcode legt dort ein
  Entwicklungs-Zertifikat „Created via API" an, dessen privater Schlüssel mit dem Runner verloren
  geht. Der Workflow widerruft diese Zertifikate jetzt selbst (#191, siehe „Was der Workflow tut").
  Ist ein Schritt „Clear …" rot: sein Protokoll lesen (je Zertifikat `aktion=widerruf` oder
  `bleibt`, Fehler als `::error::`). Rot vor dem Archiv („Clear leftover …"): Lauf neu starten,
  hochgeladen wurde nichts. Rot am Ende („Clear … of this run"): nur ein Hinweis, der Upload-Job
  bleibt grün und `confirm` prüft den Build trotzdem (#183); der nächste Lauf räumt vor dem Archiv
  nach. Scheitert das Aufräumen dauerhaft (etwa Schlüssel ohne Admin-Rolle, 401/403), scheitert im
  nächsten Lauf das Aufräumen vor dem Archiv hart und stoppt den Lauf; dann gilt der folgende Eintrag
  zu 401/403. Nie von Hand im Entwicklerportal widerrufen.
- **Schritt „Clear …" rot mit HTTP 401 oder 403**: Schlüssel-ID, Aussteller-ID oder privater
  Schlüssel stimmen nicht, oder der Schlüssel hat nicht die Rolle **Admin** (nötig zum Widerrufen).
  Das betrifft beide Aufräum-Schritte, also auch einen roten Schritt am Ende eines sonst grünen Laufs.
- **Job „Production knows the CloudKit schema" rot**: Die Schranke aus 5a (#268) hat angehalten, archiviert und
  hochgeladen wurde nichts. Die Meldung sagt, welcher der drei Fälle es ist (Secret fehlt, Production nicht lesbar,
  Typ/Feld fehlt); den Weg dazu nennt 5a. Es gibt keinen Weg daran vorbei.
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

Berechtigungen (#311) gehören in `project.yml` (`entitlements.properties` des Ziels), nie nur in die
erzeugte `.entitlements`-Datei: XcodeGen schreibt sie bei jedem `generate` neu, ein nur dort
eingetragener Schlüssel fehlt dann im TestFlight-Bau (so fehlte `com.apple.developer.ubiquity-kvstore-identifier`
ab Build 29). Zwei Prüfungen sichern das ab: `python3 scripts/test_entitlements_sync.py` (läuft in der CI im
Schritt „Script tests") vergleicht `project.yml` typgenau mit allen eingecheckten `.entitlements`; die Zeile
`entitled` der Archivprüfung liest die signierten Berechtigungen der Haupt-App per `codesign` und stoppt
den Upload, wenn der Schlüssel fehlt.

Nach dem Upload läuft der Job `confirm` („Confirm Apple processed the build") auf `ubuntu-latest`.
Er ruft `scripts/asc_wait_build.py` mit der Lauf-Nummer auf: Das Skript ermittelt über die App
Store Connect API die App zur Bundle-Kennung, fragt alle 30 Sekunden den Build mit dieser Nummer ab
und schreibt je Runde `build=<Nummer> processingState=<…> uploadedDate=<…> treffer=<k>` ins Protokoll
(`processingState=nicht-gelistet treffer=<k>`, solange Apple ihn noch nicht führt). `treffer` ist
die Zahl der Datensätze, die Apple auf die Abfrage mit `filter[version]` liefert, vor dem eigenen
Abgleich der Nummer. `k=1` ist bei gesetztem Filter der erwartete Normalfall; `k>1` ist auffällig
und der Anlass, die Antwort zu prüfen (der Filter greift dann möglicherweise nicht serverseitig, oder
dieselbe Build-Nummer existiert unter mehreren Versionsnummern). Das Skript gleicht in jedem Fall
selbst auf `attributes.version` ab. Grün nur bei `VALID`; rot bei
`INVALID`, `FAILED`, nach 45 Minuten ohne `VALID` und bei abgelehntem Schlüssel. Schlägt nur dieser
Job fehl, bleibt der Upload-Job grün, der Lauf insgesamt wird rot. Lokal ist die Abfrage nicht
möglich (der Schlüssel liegt nur in den Secrets); lokal laufen nur die Tests
`python3 scripts/test_asc_wait_build.py`.

Zwei Aufräum-Schritte halten das Zertifikatskonto klein (#191): „Clear leftover development
certificates" vor dem Archiv (räumt, was frühere Läufe hinterlassen haben) und „Clear the development
certificates of this run" am Ende, auch wenn vorher etwas fehlschlug. Scheitert das Aufräumen am
Ende, wird nur dieser Schritt als fehlgeschlagen markiert (Fehlermeldung im Protokoll), der
Upload-Job bleibt grün und `confirm` läuft trotzdem; übrig gebliebene Zertifikate räumt der nächste
Lauf vor dem Archiv (#183). Scheitert das Aufräumen vor dem Archiv, bricht der Lauf ab. Beide rufen
`scripts/asc_cleanup_certs.py` auf. Widerrufen wird nur, was den Typ Entwicklung (`DEVELOPMENT`,
`IOS_DEVELOPMENT`) und genau den Namen „Apple Development: Created via API" trägt (so nennt ihn Apple im Konto, belegt im
Probelauf 37136927454); Distribution-Zertifikate und Hennings
eigene Zertifikate aus Xcode bleiben. Das Protokoll listet jedes Zertifikat mit Typ, Name, Ablauf,
gekürzter ID und `aktion=widerruf`/`bleibt` und endet mit
`zertifikate vorher=<n> nachher=<m> widerrufen=<k>` (auch in der Zusammenfassung des Laufs). Mit dem
Schalter `cleanup_dry_run` (Run workflow → Haken „Zertifikate nur auflisten, nichts widerrufen") wird
nur aufgelistet, die Zeile endet dann mit `wuerde-widerrufen=<k>`. Gerätebauten (#156) signieren mit
gespeicherten Profilen und sind davon nicht berührt. Lokal laufen nur die Tests
`python3 scripts/test_asc_cleanup_certs.py` (der Schlüssel liegt nur in den Secrets).

Die Mac-App (#389): Der Job `upload-mac` läuft nach dem iOS-Job, archiviert `generic/platform=macOS`, prüft das Archiv
(SDK, Mindestversion, Kategorie, Sandbox, iCloud) und lädt unter derselben Buildnummer hoch; `confirm-mac` wartet auf `VALID`
und schreibt „Was testen“ (`ASC_PLATFORM=MAC_OS`). Einmalig im Konto: in App Store Connect bei „Loose Ends“ die Plattform
**macOS** hinzufügen (gleiche Bundle-ID, universeller Kauf); die Mac-Profile legt die Cloud-Signierung selbst an.
Beim Installieren in der TestFlight-App am Mac oben rechts **„macOS“** wählen; sonst installiert TestFlight die iOS-Fassung im
Mac-Wrapper (`/Applications/Loose Ends.app` mit `Wrapper/LooseEnds.app`), die kein Menüleistensymbol hat (#405).

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
`ARCHIVE=<Pfad zum .xcarchive> BUILD=<Nummer>`; erst bei vier Zeilen „OK" hochladen. Auch dieser
Weg legt ein Zertifikat „Created via API" an; der nächste CI-Lauf widerruft es.

## Prüfbauten fürs iPhone (#156)

`./scripts/sim.sh device-build` und `./scripts/sim.sh lab` signieren nur mit den Profilen, die auf
dem Mac schon gespeichert sind, und sprechen dabei nicht mit Apple. So kann der Bau die Anmeldung in
Xcode nicht abmelden. Für eine neue Kennung, eine neue Fähigkeit oder nach Ablauf eines Profils läuft
einmal `LOOSEENDS_REGISTER=1 ./scripts/sim.sh device-build` (bzw. `… lab`): Dieser Lauf benutzt die
Anmeldung in Xcode und legt Kennungen und Profile an. Der API-Schlüssel reicht dafür nicht, weil
xcodebuild mit ihm keine neuen Entwicklungsprofile anlegen kann.
