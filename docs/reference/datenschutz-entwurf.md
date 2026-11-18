# Datenschutz – Entwurf

**Status:** Inhalt von Henning freigegeben am 2026-10-27 (Verantwortlicher, Kontaktadresse und Umgang mit den
Apple-Diensten entschieden, siehe unten). Veröffentlicht am 2026-10-27 unter
https://www.henemm.com/legal/loose-ends/privacy-policy/ (Website-PR henemm/henemm-website#75), bei Apple als
Datenschutz-URL der Beta-Lokalisierung de-DE eingetragen (#705). Noch nicht in die App eingebaut. Die öffentliche Seite
ist die Fassung ohne die Abschnitte „Beleg im Code“ und „Offen, nicht belegt“; eine Änderung an diesem Text gilt erst,
wenn auch die Website-Seite angepasst ist.
Konto-Teil (Abschnitt „Wenn du die Verbindung zu Claude nutzt“ und die Änderungen an Kurzfassung, „Wo es liegt“ und
Löschsatz) von Henning freigegeben am 2026-11-10 (#615 Schnitt 4e, `docs/specs/feat-615-schnitt-4e-datenschutz.md`);
veröffentlicht auf der Website-Seite am 2026-11-10 (henemm/henemm-website#79), nachdem die Sicherungsfrist von
30 Tagen galt (henemm/henemm-infra#421).
Nachtrag Abschrift und Kennung dieser Installation (Absätze „Deine offenen Aufgaben für Claude.“ und „Kennung dieser
Installation.“, Löschsatz) von Henning freigegeben am 2026-11-17 (#625 Schnitt 1,
`docs/specs/feat-625-schnitt-1-datenschutztext.md`); veröffentlicht auf der Website-Seite am 2026-11-17
(henemm/henemm-website#80); der Satz zum Zeitpunkt der Abschrift am 2026-11-17 (henemm/henemm-website#81).

Geschrieben aus dem, was der Code am 2026-10-26 belegt (#342, Teil 2). Jede Aussage hat unten einen Beleg im
Code; was der Code nicht beweist, steht unter „Offen, nicht belegt“.

## Kurzfassung für Nutzer

Loose Ends speichert deine Aufgaben auf deinem Gerät und, wenn du iCloud nutzt, in deinem privaten iCloud.
Es gibt keine Werbung und kein Tracking. Gesprochenes wird auf deinem Gerät in Text umgewandelt. Die App fragt nur
nach Rechten, wenn du die Funktion benutzt, die sie braucht. Nur wenn du die freiwillige Verbindung zu Claude nutzt,
legst du ein Konto bei uns an und nutzt einen Dienst von uns; was dann gespeichert wird, steht im Abschnitt „Wenn du
die Verbindung zu Claude nutzt“.

## Verantwortlicher und Kontakt

HENEMM GmbH, Eichenaue 14, 48157 Münster, Deutschland, vertreten durch den Geschäftsführer Henning Emmrich;
E-Mail henning@henemm.com; weitere Angaben im Impressum (https://www.henemm.com/footer-information/imprint/)
(Henning, 2026-10-27, Auswahl „HENEMM GmbH“, wie bei Gregor Zwanzig). Fragen zu deinen Daten und zur Löschung: an
diese Adresse. Deine Daten löschst du selbst:
Aufgaben in der App; den iCloud-Bereich der App in den iCloud-Einstellungen unter „Speicher verwalten“; ein Konto bei
unserem Dienst mit „Konto löschen“ in den Einstellungen der App.

Du kannst jederzeit Auskunft verlangen, falsche Daten berichtigen und Daten löschen lassen; für alles andere als
das Löschen in der App und im iCloud-Bereich genügt eine E-Mail an die Adresse oben. Du kannst dich außerdem bei
einer Datenschutz-Aufsichtsbehörde beschweren, zum Beispiel bei der Landesbeauftragten für Datenschutz und
Informationsfreiheit Nordrhein-Westfalen. (Henning, 2026-10-27: Rechte wie Gregor Zwanzig)

## Was Apple dabei übernimmt

An vier Stellen handelt Apples System, nicht die App. Dort gilt Apples Datenschutz, und wir sagen nicht mehr zu,
als der Code belegt:

- **Karten:** Ortssuche und der Name deines aktuellen Ortes laufen über Apple Karten.
- **Apple Intelligence:** Der Titel wird, wo das Gerät es kann, vom Modell des Geräts verfeinert; was Apple dabei
  zusagt, ist Apples Sache.
- **Siri und Kurzbefehle:** Beim Erfassen per Siri gilt Apples Verhalten.
- **Diktat auf der Watch:** Die Watch nimmt Text über das Diktat von watchOS auf; wohin Apple das Gesprochene
  schickt, regelt Apple.

## Was erfasst wird

- Der Text, den du tippst oder sagst (der Rohtext der Aufgabe), und was du einer Aufgabe hinzufügst: Notiz,
  Unteraufgaben, Tags, Projekt, Fälligkeit, Ort, Anhänge (Dateien, Fotos, gescannte Dokumente).
- Was die App daraus ableitet (Titel, Dauer, Tags, Fälligkeit, Wichtigkeit, Dringlichkeit), samt Verlauf der
  Änderungen. Abgeleitet wird auf dem Gerät: per Regeln, und wo vorhanden mit Apple Intelligence auf dem Gerät.
- Gesprochenes wird nur zur Umwandlung in Text verwendet; gespeichert wird der Text.

## Wo es liegt

- Auf dem Gerät, in der App-Gruppe der App.
- In deiner privaten iCloud-Datenbank (CloudKit, privater Bereich), damit iPhone, iPad, Mac und Watch denselben
  Stand haben. Darauf hat nur dein Apple-Account Zugriff.
- Die gewählte Erinnerungszeit wird über den iCloud-Schlüsselwertspeicher zwischen deinen Geräten abgeglichen.
- Keine Analyse- oder Werbe-Dienste, kein Tracking. Einen eigenen Dienst (Server) gibt es nur für die freiwillige
  Verbindung zu Claude, siehe nächster Abschnitt; ohne sie verlässt nichts außer dem iCloud-Abgleich dein Gerät.

## Wenn du die Verbindung zu Claude nutzt

Das ist freiwillig. Ohne sie gibt es kein Konto bei uns und keinen Datenverkehr zu unserem Dienst. Du nutzt sie, indem
du dich in den Einstellungen unter „Claude“ mit Apple anmeldest; damit entsteht dein Konto bei uns. Dann gilt zusätzlich:

**Anmeldung.** Du meldest dich nur mit Apple an. Wir fragen Apple weder nach deinem Namen noch nach deiner
E-Mail-Adresse. Gespeichert wird nur die Kennung, die Apple für dich in dieser App vergibt, und der Zeitpunkt, zu dem
das Konto angelegt wurde.

**Was unser Dienst speichert.** Eine Anmeldung (Sitzung) speichern wir nur als Prüfsumme, nicht im Klartext; sie
endet, wenn du sie 90 Tage nicht benutzt, oder wenn du dich abmeldest. Das Zugangsmerkmal, das Apple uns bei der
Anmeldung gibt, speichern wir verschlüsselt, um es beim Löschen deines Kontos bei Apple zu widerrufen. Verbindest du
Claude (den Konnektor in claude.ai), speichern wir dessen Zugangsdaten ebenfalls nur als Prüfsumme.

**Deine offenen Aufgaben für Claude.** Solange du angemeldet bist, schickt die App eine Abschrift deiner offenen
Aufgaben an den Dienst, auch wenn du Claude noch nicht verbunden hast. Offen heißt: alle Aufgaben, die nicht erledigt
sind, auch geparkte und Unterpunkte. Je Aufgabe sind das der Titel, der Status, die Fälligkeit, deine Tags, das
Projekt, ihre Stellung unter „Als nächstes“ und ob sie das Knäuel ist. Dazu kommt, welche Aufgaben in „Jetzt“ stehen
und in welcher Reihenfolge „Fällig“, „Als nächstes“ und „Lose Enden“ sie zeigen, nur als Kennungen. Außerdem steht
darin, wann die Abschrift erstellt wurde. Der Titel entsteht
aus deinem Text und kann dessen Anfang enthalten. Nicht dabei sind der Text, den du gesagt oder getippt hast (der
Rohtext), deine Notizen, Anhänge, Orte, erledigte Aufgaben und der Verlauf der Änderungen. Die App sendet beim Start,
wenn du zur App zurückkehrst und kurz nach Änderungen an deinen Aufgaben. Der Dienst behält nur die jeweils neueste
Abschrift; jede neuere überschreibt die vorige. Sie dient dazu, dass Claude deine Aufgaben lesen kann, wenn du Claude
verbindest. „Abmelden“ hält das Senden von diesem Gerät an; die zuletzt gesendete Abschrift bleibt beim Dienst, bis du
dein Konto löschst.

**Aufträge aus Claude.** Bittest du Claude, eine Aufgabe anzulegen oder zu ändern (etwa sie zu erledigen, ihr ein
Datum zu geben, sie zurückzustellen oder einen Unterpunkt anzufügen), speichert der Dienst diesen Auftrag mit seinem
Inhalt (zum Beispiel dem Titel der neuen Aufgabe), bis deine App ihn übernimmt, und danach das Ergebnis. Aufträge und
Ergebnisse bleiben gespeichert, bis du dein Konto löschst.

**Kennung dieser Installation.** Wenn die App Aufträge von Claude abholt und deren Ergebnis meldet, schickt sie eine
zufällige Kennung dieser Installation mit. Die App erzeugt sie einmal selbst und legt sie im Schlüsselbund dieses
Geräts ab; sie wird nicht über iCloud abgeglichen und ist kein Merkmal des Geräts wie Seriennummer oder Werbekennung.
Der Dienst vermerkt sie an dem Auftrag, den dieses Gerät übernimmt, und am Ergebnis, damit ein Auftrag jeweils an ein
Gerät geht und nur dieses das Ergebnis melden kann. Sie bleibt mit dem Auftrag gespeichert, bis du dein Konto löschst.

**Wo.** Der Dienst läuft auf einem Server der Hetzner Online GmbH in Deutschland.

**Server-Protokolle.** Wenn du den Dienst aufrufst, schreibt der Webserver deine IP-Adresse, die aufgerufene Adresse,
den Zeitpunkt und den Antwortcode in ein Protokoll. Wir brauchen es, um Fehler zu finden und Missbrauch abzuwehren
(Art. 6 Abs. 1 lit. f DSGVO, berechtigtes Interesse). Die Protokolle werden nach 14 Tagen gelöscht.

**Sicherungen.** Die Datenbank des Dienstes wird nachts gesichert, verschlüsselt auf einem weiteren Rechner in
Deutschland. Sicherungen werden höchstens 30 Tage aufbewahrt.

**Löschen.** In den Einstellungen unter „Claude“ löschst du mit „Konto löschen“ dein Konto. Das entfernt dein Konto und
alle Daten, die der Dienst zu diesem Konto gespeichert hat, darunter die Abschrift deiner Aufgaben, Aufträge und
Ergebnisse, und widerruft die Anmeldung bei Apple. Vorhandene Sicherungen laufen innerhalb von 30 Tagen aus. „Abmelden“ beendet nur die Sitzung auf diesem Gerät.

**Apple und Claude.** Bei der Anmeldung handelt Apple nach Apples Datenschutz. Was Claude (Anthropic) mit dem macht,
was du dort schreibst oder abrufst, regelt Anthropics Datenschutz, nicht dieser Text.

## Welche Rechte und warum

| Recht | Wann gefragt | Wozu |
|---|---|---|
| Mikrofon | beim Sprechen einer Aufgabe | damit du eine Aufgabe sagen kannst |
| Spracherkennung | nur, falls das System danach fragt; ein Erklärungstext ist hinterlegt (siehe Offen) | Umwandlung auf dem Gerät |
| Kamera | beim Scannen eines Dokuments | ein Dokument an eine Aufgabe hängen |
| Standort „beim Verwenden“ | nur wenn du „Hier“ für einen Ort wählst | den aktuellen Ort für eine Ortserinnerung |
| Kalender (voller Zugriff) | nur wenn du die Kalenderanzeige einschaltest | Aufgaben mit Fälligkeit als Termine zeigen; die App ändert nur ihre eigenen Termine |
| Mitteilungen | im Onboarding bzw. beim Einschalten | an Fälligkeit und Orte erinnern |

Fotos und Dateien brauchen **kein** Recht: Die App bekommt über die Systemauswahl nur, was du auswählst.

Die App fragt **nicht** nach Kontakten. Sie liest keine Kontakte.

## Beleg im Code

| Aussage | Beleg |
|---|---|
| Kein Tracking, keine erfassten Datentypen deklariert | `PrivacyInfo.xcprivacy` in `LooseEnds/`, `LooseEndsWatch/`, `LooseEndsShare/`, `LooseEndsWidgets/`, `LooseEndsWatchWidgets/`: `NSPrivacyTracking` = false, `NSPrivacyCollectedDataTypes` leer (Store-Bauten); einzige deklarierte API-Kategorie `UserDefaults` (außer Watch-Komplikation: keine) |
| Manifest folgt dem Konto-Schalter: Store-Bauten leer, Konto-Bauten drei Typen aus `scripts/privacy_manifest.py` | `scripts/privacy_manifest.py` (`ACCOUNT_TYPES`: UserID, DeviceID, OtherUserContent, je verknüpft, kein Tracking, Zweck App-Funktion); `.github/workflows/testflight.yml` (`apply` im Schritt „Set the account switch“ nur bei `konto`, `check --account` in beiden Archivprüfungen, ein Befund stoppt den Upload; #625 S2) |
| Freiwillig; ohne Konto kein Verkehr zum Dienst | `LooseEnds/Claude/AccountWiring.swift` (`forApp`, nichts wird vor einem Tipp gesendet), `LooseEnds/Views/AccountSection.swift` (Gruppe „Claude“ in den Einstellungen) |
| Keine Fremd-SDKs, keine Analyse | `project.yml` ohne `packages`-Abschnitt; `URLSession` nur im Konto-Teil (`LooseEnds/Claude/`) |
| Nur Apple; kein Name, keine E-Mail | `LooseEnds/Views/AccountSection.swift:177` `requestedScopes = []`; `server/migrations/002_accounts.sql` (`apple_sub`, Anlagezeit) |
| Sitzung nur als Prüfsumme, 90 Tage Nichtbenutzung | `server/migrations/002_accounts.sql`, `server/src/accounts.ts` (`SESSION_IDLE_DAYS` = 90, #615 S4a) |
| Apple-Zugangsmerkmal verschlüsselt, zum Widerruf | `server/src/apple-vault.ts` (AES-256-GCM), `server/migrations/005_apple_tokens_per_client.sql`, `server/src/auth.ts` (`/auth/delete` widerruft) |
| Zugangsdaten des Konnektors nur als Prüfsumme | `server/migrations/004_oauth.sql`, `server/src/oauth-adapter.ts` (Ids als SHA-256) |
| Hetzner, Deutschland | `docs/artifacts/feat-615-s4d-auth-oeffnen/monitor-*.txt` (Server `rennwienix`), `docs/artifacts/feat-615-s4e-datenschutz/standort.txt` (AC-9) |
| Server-Protokolle mit IP, 14 Tage | `/etc/logrotate.d/nginx` auf `rennwienix` (`daily`, `rotate 14`), Beleg `docs/artifacts/feat-615-s4e-datenschutz/protokolle.txt` (AC-9) |
| Sicherungen nachts, verschlüsselt, höchstens 30 Tage | `henemm-infra` `docs/backup-offsite.md` und Issue #421 (Frist), Beleg `docs/artifacts/feat-615-s4e-datenschutz/sicherung.txt` (AC-10) |
| „Konto löschen“ entfernt alles zum Konto, widerruft bei Apple | `server/src/accounts.ts` (`deleteAccount`), `server/src/auth.ts` (`POST /auth/delete`), Nachweis `docs/artifacts/feat-615-s4d-auth-oeffnen/loeschen-lokal.md` |
| Aufträge aus Claude mit Inhalt und Ergebnis, bis zur Kontolöschung | `server/migrations/001_claude_schema.sql` (`orders`, `order_results`, kein Ablauf), `server/migrations/007_order_kinds.sql`, `server/src/mcp.ts` (`capture_task`, `complete_task`, `set_due` und weitere Auftragswerkzeuge), `server/src/accounts.ts` (`deleteAccount` löscht Aufträge und Ergebnisse) |
| Abschrift offener Aufgaben, genau diese Felder; sonst nichts | `Shared/Services/TranscriptCodec.swift` (`Transcript`, `Entry`); `docs/reference/claude-abschrift-vertrag.md` (Abschnitt „Abschrift“: „keinen Rohtext, keine Notiz, keine Anhänge und keine Revisionen“); `server/src/transcripts.ts` (`shape` nimmt nur diese Schlüssel, `privacy` weist `rawText` und `note` ab); `server/migrations/001_claude_schema.sql` und `006_transcript_views.sql` (CHECK auf erlaubte Schlüssel) |
| „Offen“ = nicht erledigt, auch geparkt und Unterpunkte | `TranscriptCodec.transcript` (`status != .done && != .removed`), `server/src/transcripts.ts` (`statuses`: unprocessed, unverified, active, parked) |
| Titel entsteht aus dem Rohtext | `Shared/Services/TitleRule.swift` (bereinigter Rohtext, höchstens 12 Wörter, #202) |
| Senden nur mit Anmeldung, auch ohne verbundenes Claude | `LooseEnds/Claude/ClaudeSync.swift` (`sendTranscript` über `AccountState.withSession`, ohne Sitzung `notSignedIn`); `LooseEnds/Claude/ClaudeSyncTrigger.swift` (`forApp` nur mit Konto) |
| Auslöser: Start, Rückkehr, nach Änderungen | `LooseEnds/Claude/ClaudeSyncTrigger.swift` (`start`: `didBecomeActive`, `ModelContext.didSave`, CloudKit-Import, 2 s Entprellung); `LooseEnds/App/LooseEndsApp.swift` (`ClaudeSyncTrigger.forApp`) |
| Dienst hält nur die neueste Abschrift je Konto | `server/migrations/001_claude_schema.sql` (`transcripts`, `account_id` Primärschlüssel, keine Historie); `server/src/transcripts.ts` (`putTranscript`) |
| Zweck: Claude liest die Abschrift | `server/src/mcp.ts` (Lesewerkzeuge `get_now`, `list_tasks`, `get_view` über `getTranscript`); `server/src/anleitung.ts` |
| Abmelden lässt die Abschrift stehen | `server/src/auth.ts` (`POST /auth/logout` ruft nur `endSession`), `server/src/accounts.ts` (`endSession` löscht nur die Sitzungszeile); `LooseEnds/Claude/AccountState.swift` (`signOut`) |
| „Konto löschen“ entfernt die Abschrift | `server/src/accounts.ts` (`deleteAccount`: `DELETE FROM transcripts WHERE account_id`) |
| Zufällige Kennung dieser Installation, nur dieses Gerät, kein Hardware-Merkmal | `LooseEnds/Claude/DeviceIdentity.swift` (`UUID()`, Schlüsselbund, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, kein `kSecAttrSynchronizable`) |
| Kennung geht an Auftrag abholen und Ergebnis melden, nicht an die Abschrift | `LooseEnds/Claude/ServiceClient.swift` (`X-Device` in `claimOrder`, `putResult`); `LooseEnds/Claude/ClaudeSync.swift` (`pullOrders`); `docs/reference/claude-abschrift-vertrag.md` („`transcript` braucht kein Gerät“) |
| Dienst vermerkt sie an Auftrag und Ergebnis, ein Gerät zur Zeit | `server/src/orders.ts` (`claimOrder` setzt `claimed_by`, `putResult` nur vom haltenden Gerät), `server/migrations/001_claude_schema.sql` (`orders.claimed_by`, `order_results.reported_by`) |
| Auftrag, Ergebnis und Kennung werden mit dem Konto gelöscht | `server/src/accounts.ts` (`deleteAccount` löscht `order_results`, `orders`) |
| „Abmelden“ beendet nur die Sitzung dieses Geräts | `server/src/auth.ts` (`POST /auth/logout` beendet genau diese Sitzung), `LooseEnds/Views/AccountSection.swift` (Hinweis „Signing out disconnects only this device“) |
| Sicherungen auf einem weiteren Rechner in Deutschland, verschlüsselt | `henemm-infra` `docs/backup-offsite.md` (restic, verschlüsselt, append-only), Beleg `sicherung.txt` (AC-10); Standort Deutschland: Bestätigung Henning 2026-11-11 (`docs/artifacts/feat-615-s4e-datenschutz/heimserver.txt`) |
| Apple und Anthropic handeln nach eigenem Datenschutz | kein Code-Beleg möglich; Verweis auf fremde Verantwortung, steht deshalb unter „Offen, nicht belegt“ als bewusst nicht prüfbar |
| Rechtsgrundlage Protokolle | Art. 6 Abs. 1 lit. f DSGVO (Recherche im Kontext: Server-Logs mit IP 7 bis 14 Tage gängig) |
| Speicher auf dem Gerät + privates CloudKit | `Shared/Persistence/ModelContainerFactory.swift`: `groupContainer: .identifier(appGroup)`, `cloudKitDatabase: .private(cloudContainer)`; Rückfall ohne Abgleich `cloudKitDatabase: .none` |
| iCloud-Container und App-Gruppe | `project.yml`, Entitlements der App, Watch und Share: `com.apple.developer.icloud-services: [CloudKit]`, `iCloud.com.henning.looseends`, `group.com.henning.looseends` |
| Erinnerungszeit über iCloud-Schlüsselwertspeicher | `project.yml`: `com.apple.developer.ubiquity-kvstore-identifier` (Kommentar „DueNotificationCenter syncs the reminder time“, #311) |
| Sprache wird auf dem Gerät umgewandelt | `LooseEnds/Speech/SpeechCapture.swift`: `SpeechAnalyzer`/`SpeechTranscriber`, Kommentar „nothing leaves the device“ (#64) |
| Mikrofon | `project.yml` `NSMicrophoneUsageDescription` (App, Watch); Mac-Sandbox `com.apple.security.device.audio-input` |
| Kamera nur zum Dokumentscan | `LooseEnds/Views/DocumentScanner.swift`: `VNDocumentCameraViewController`; `project.yml` `NSCameraUsageDescription` |
| Standort nur „beim Verwenden“ | `LooseEnds/Places/CurrentLocation.swift`: `requestWhenInUseAuthorization()`; kein `requestAlways` im Code; `project.yml` nur `NSLocationWhenInUseUsageDescription` |
| Kalender nur auf Wunsch | `LooseEnds/Calendar/CalendarBridge.swift`: `requestFullAccessToEvents()`; `project.yml` `NSCalendarsFullAccessUsageDescription` |
| Mitteilungen | `LooseEnds/Notifications/DueNotificationCenter.swift`: `requestAuthorization(options: [.alert, .sound, .badge])` |
| Fotos und Dateien ohne Recht | `LooseEnds/Views/AttachmentsSection.swift`: `PhotosPicker` und `fileImporter`; Mac-Sandbox `com.apple.security.files.user-selected.read-only` |
| Kein Kontakte-Recht | Suche `grep -rlnE "import Contacts\|CNContact" LooseEnds/ Shared/ LooseEndsShare/ LooseEndsWatch/ LooseEndsWidgets/` am 2026-10-26: **kein Treffer** (Exit-Code 1); `project.yml` hat kein `NSContactsUsageDescription` |
| Abgleich per stiller Push-Mitteilung | `project.yml` `aps-environment` (Kommentar: CloudKit-Abgleich) |

## Offen, nicht belegt

- **Watch-Diktat:** Die Watch erfasst über ein Textfeld (`LooseEndsWatch/WatchCaptureView.swift`, `TextField`),
  also über das System-Diktat von watchOS. Wohin Apples Diktat das Gesagte schickt, ist Apples Verhalten und im
  Code nicht belegt. Der englische Watch-Text in `project.yml` sagt „on your watch“; das ist zu prüfen.
- **Spracherkennungs-Recht:** `LooseEnds/Speech/SpeechAccess.swift` sagt, seit #293 frage die App nur das
  Mikrofon ab, `SpeechAnalyzer` brauche das Spracherkennungs-Recht nicht. Der Text
  `NSSpeechRecognitionUsageDescription` ist trotzdem hinterlegt. Ob das System ihn je zeigt, ist nicht belegt.
- **Apple-Dienste mit Netz:** Ortssuche (`MKLocalSearch`, `LooseEnds/Places/PlaceSearch.swift`) und
  Ortsname zur aktuellen Position (`MKReverseGeocodingRequest`, `CurrentLocation.swift`) fragen Apple Karten.
  Was Apple dabei erhält und speichert, regelt Apples Datenschutz, nicht dieser Code.
- **Apple Intelligence:** Der Aufruf geht an `SystemLanguageModel` auf dem Gerät
  (`Shared/Enrichment/FoundationModelsEnricher.swift`). Dass dabei nichts das Gerät verlässt, ist Apples
  Zusage, nicht im Code prüfbar.
- **Siri und Kurzbefehle:** Was Siri bei „Aufgabe erfassen“ an Apple schickt, ist Apples Verhalten.
- **Verantwortlicher, Kontaktadresse:** entschieden (oben). Der Löschhinweis zum iCloud-Bereich beschreibt die
  Systemeinstellung. Die Seite ist seit 2026-10-27 veröffentlicht; das Gegenlesen des Hinweises auf einem Gerät ist
  weiter offen und vor dem App Store nötig, nur auf Hennings ausdrückliches Wort (#705).
- **Die vier Apple-Punkte** stehen jetzt im Text als „Was Apple dabei übernimmt“ (Entscheidung Henning,
  2026-10-27); sie bleiben hier als Hinweis, dass der Code sie nicht belegen kann.
- **Weckruf (Push-Token):** Der Dienst kann je Gerät einen Push-Token speichern (`server/migrations/008_device_tokens.sql`,
  `server/src/devices.ts`); die App hat den Kern dafür (`LooseEnds/Claude/DeviceRegistration.swift`, `DeviceRegistration`),
  ruft ihn aber noch nicht auf. Im Text ist der Weckruf deshalb nicht beschrieben; der Absatz dazu kommt mit #795 S5c-2
  und ändert Text und Website-Seite erneut.
- **Anthropic:** Was Claude (Anthropic) mit Inhalten macht, die du dort schreibst oder abrufst, ist Anthropics Sache
  und im Code nicht prüfbar; der Text verweist bewusst nur darauf.

## English

**Status:** wortgetreue Übersetzung der öffentlichen deutschen Fassung vom 2026-10-27, keine Zusätze, keine Kürzungen
(Henning, 2026-10-30, pauschal über #750 freigegeben, #763). Veröffentlicht am 2026-10-31 unter
https://www.henemm.com/legal/loose-ends/privacy-policy-en/ (Website-PR henemm/henemm-website#76); bei Apple als
Datenschutz-URL der Beta-Lokalisierung en-US gesetzt, wenn `asc-beta.yml` mit `aktion=einrichten` läuft (Vorgabe im Skript
`PRIVACY_URL_EN`, die Repo-Variable `ASC_PRIVACY_POLICY_URL_EN` darf sie überstimmen). Eine Änderung am deutschen Text
gilt erst, wenn auch dieser Abschnitt und die englische Website-Seite angepasst sind.
Konto-Teil (Abschnitt 4 und die Änderungen an Abschnitt 2, 3 und 7) wortgetreu aus der Spec übernommen, von Henning
freigegeben am 2026-11-10 (#615 Schnitt 4e); veröffentlicht auf https://www.henemm.com/legal/loose-ends/privacy-policy-en/
am 2026-11-10 (henemm/henemm-website#79), nachdem die Sicherungsfrist von 30 Tagen galt (henemm/henemm-infra#421).
Nachtrag Abschrift und Kennung dieser Installation (in Abschnitt 4 die Absätze „Your open tasks for Claude.“ und
„Identifier of this installation.“ und der Löschsatz) wortgetreu aus der Spec übernommen, von Henning freigegeben am
2026-11-17 (#625 Schnitt 1, `docs/specs/feat-625-schnitt-1-datenschutztext.md`); veröffentlicht auf
https://www.henemm.com/legal/loose-ends/privacy-policy-en/ am 2026-11-17 (henemm/henemm-website#80); der Satz zum Zeitpunkt
der Abschrift am 2026-11-17 (henemm/henemm-website#81).

*Last updated: November 17, 2026*

### 1. Who is responsible?

HENEMM GmbH, Eichenaue 14, 48157 Münster, Germany

Represented by the managing director: Henning Emmrich

Email: henning@henemm.com

You will find more details in the [imprint](/footer-information/imprint/).

### 2. In short, and what is collected

Loose Ends stores your tasks on your device and, if you use iCloud, in your private iCloud.
There is no advertising and no tracking. What you say is turned into text on your device. The app only asks for
permissions when you use the function that needs them. Only if you use the voluntary connection to Claude do you create an
account with us and use a service of ours; what is stored then is described in the section "If you use the connection to Claude".

What is collected:

- The text you type or say (the raw text of the task), and what you add to a task: note,
  subtasks, tags, project, due date, place, attachments (files, photos, scanned documents).
- What the app derives from it (title, duration, tags, due date, importance, urgency), together with the history of
  changes. Deriving happens on the device: by rules, and where available with Apple Intelligence on the device.
- What you say is used only to turn it into text; the text is what is stored.

### 3. Where your data lives

- On your device, in the app's app group.
- In your private iCloud database (CloudKit, private area), so that iPhone, iPad, Mac and Watch have the same
  state. Only your Apple account has access to it.
- The reminder time you choose is synced between your devices through the iCloud key-value store.
- No analytics or advertising services, no tracking. There is a service (server) of our own only for the voluntary
  connection to Claude, see the next section; without it, nothing leaves your device except the iCloud sync.

### 4. If you use the connection to Claude

This is voluntary. Without it there is no account with us and no traffic to our service. You use it by signing in with
Apple in Settings under "Claude"; this creates your account with us. Then the following also applies:

**Sign-in.** You sign in with Apple only. We do not ask Apple for your name or your email address. What is stored is
only the identifier Apple assigns to you for this app, and the time the account was created.

**What our service stores.** We store a sign-in (session) only as a checksum, not in plain text; it ends when you do
not use it for 90 days, or when you sign out. The token Apple gives us at sign-in is stored encrypted, so that we can
revoke it with Apple when your account is deleted. If you connect Claude (the connector in claude.ai), we likewise store
its access credentials only as a checksum.

**Your open tasks for Claude.** As long as you are signed in, the app sends a transcript of your open tasks to the
service, even if you have not connected Claude yet. Open means: every task that is not completed, including parked tasks
and subtasks. For each task this is the title, the status, the due date, your tags, the project, its position under
"Next up" and whether it is the Tangle. In addition it says which tasks are in "Now" and in which order "Due", "Next up"
and "All open" show them, as identifiers only. It also states when the transcript was created. The title is derived from your text and can contain its beginning. Not
included are the text you said or typed (the raw text), your notes, attachments, places, completed tasks and the history
of changes. The app sends at start, when you return to the app, and shortly after changes to your tasks. The service
keeps only the newest transcript; each newer one overwrites the previous one. It exists so that Claude can read your
tasks if you connect Claude. "Sign out" stops sending from this device; the transcript last sent stays with the service
until you delete your account.

**Orders from Claude.** If you ask Claude to create or change a task (for example to complete it, give it a date, put
it aside or add a subtask), the service stores this order with its content (for example the title of the new task)
until your app takes it over, and then the result. Orders and results stay stored until you delete your account.

**Identifier of this installation.** When the app collects orders from Claude and reports their result, it sends a
random identifier of this installation. The app creates it once itself and keeps it in this device's keychain; it is
not synced through iCloud and is not a feature of the device such as a serial number or an advertising identifier. The
service notes it on the order this device takes over and on the result, so that an order goes to one device at a time
and only that device can report the result. It stays stored with the order until you delete your account.

**Where.** The service runs on a server of Hetzner Online GmbH in Germany.

**Server logs.** When you call the service, the web server writes your IP address, the address called, the time and
the response code to a log. We need it to find errors and to defend against abuse (Art. 6(1)(f) GDPR, legitimate
interest). The logs are deleted after 14 days.

**Backups.** The service's database is backed up at night, encrypted, on another computer in Germany. Backups are kept
for 30 days at most.

**Deleting.** In Settings under "Claude" you delete your account with "Delete account". This removes your account and
all data the service has stored for that account, including the transcript of your tasks, orders and results, and
revokes the sign-in with Apple. Existing backups expire within 30 days. "Sign out" only ends the session on this device.

**Apple and Claude.** At sign-in, Apple acts under Apple's privacy rules. What Claude (Anthropic) does with what you
write or retrieve there is governed by Anthropic's privacy policy, not by this text.

### 5. Which permissions the app needs and why

| Permission | When asked | What for |
|---|---|---|
| Microphone | when you speak a task | so that you can say a task |
| Speech recognition | only if the system asks for it; an explanatory text is provided | conversion on the device |
| Camera | when scanning a document | attaching a document to a task |
| Location "while using" | only when you choose "Here" for a place | the current place for a place reminder |
| Calendar (full access) | only when you switch on the calendar display | showing tasks with a due date as events; the app only changes its own events |
| Notifications | during onboarding or when you switch them on | reminding you of due dates and places |

Photos and files need **no** permission: through the system picker the app only receives what you select.

The app does **not** ask for contacts. It does not read contacts.

### 6. What Apple takes over

In four places Apple's system acts, not the app. There Apple's privacy rules apply, and we promise no more
than the app's code proves:

- **Maps:** Place search and the name of your current place go through Apple Maps.
- **Apple Intelligence:** Where the device can do it, the title is refined by the device's model; what Apple
  promises in doing so is Apple's matter.
- **Siri and Shortcuts:** When capturing through Siri, Apple's behavior applies.
- **Dictation on the Watch:** The Watch takes in text through watchOS dictation; where Apple sends what is said
  is for Apple to regulate.

### 7. Your rights, deletion and changes

You can ask for information, have wrong data corrected and have data deleted at any time.
You delete your tasks in the app itself, the app's iCloud area in the iCloud settings under "Manage Storage", and an
account with our service with "Delete account" in the app's settings. For everything else an email to the address above is enough.

You can also complain to a data protection supervisory authority, for example
to the State Commissioner for Data Protection and Freedom of Information of North Rhine-Westphalia.

If anything material changes, we adjust this page and name the date at the top.
