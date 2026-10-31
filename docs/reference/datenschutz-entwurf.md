# Datenschutz – Entwurf

**Status:** Inhalt von Henning freigegeben am 2026-10-27 (Verantwortlicher, Kontaktadresse und Umgang mit den
Apple-Diensten entschieden, siehe unten). Veröffentlicht am 2026-10-27 unter
https://www.henemm.com/legal/loose-ends/privacy-policy/ (Website-PR henemm/henemm-website#75), bei Apple als
Datenschutz-URL der Beta-Lokalisierung de-DE eingetragen (#705). Noch nicht in die App eingebaut. Die öffentliche Seite
ist die Fassung ohne die Abschnitte „Beleg im Code“ und „Offen, nicht belegt“; eine Änderung an diesem Text gilt erst,
wenn auch die Website-Seite angepasst ist.

Geschrieben aus dem, was der Code am 2026-10-26 belegt (#342, Teil 2). Jede Aussage hat unten einen Beleg im
Code; was der Code nicht beweist, steht unter „Offen, nicht belegt“.

## Kurzfassung für Nutzer

Loose Ends speichert deine Aufgaben auf deinem Gerät und, wenn du iCloud nutzt, in deinem privaten iCloud.
Es gibt keinen eigenen Server, kein Konto bei uns, keine Werbung und kein Tracking. Gesprochenes wird auf deinem
Gerät in Text umgewandelt. Die App fragt nur nach Rechten, wenn du die Funktion benutzt, die sie braucht.

## Verantwortlicher und Kontakt

HENEMM GmbH, Eichenaue 14, 48157 Münster, Deutschland, vertreten durch den Geschäftsführer Henning Emmrich;
E-Mail henning@henemm.com; weitere Angaben im Impressum (https://www.henemm.com/footer-information/imprint/)
(Henning, 2026-10-27, Auswahl „HENEMM GmbH“, wie bei Gregor Zwanzig). Fragen zu deinen Daten und zur Löschung: an
diese Adresse. Deine Daten löschst du selbst:
Aufgaben in der App; den iCloud-Bereich der App in den iCloud-Einstellungen unter „Speicher verwalten“.

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
- Kein eigenes Backend, keine Analyse- oder Werbe-Dienste, kein Tracking.

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
| Kein Tracking, keine erfassten Datentypen deklariert | `PrivacyInfo.xcprivacy` in `LooseEnds/`, `LooseEndsWatch/`, `LooseEndsShare/`, `LooseEndsWidgets/`, `LooseEndsWatchWidgets/`: `NSPrivacyTracking` = false, `NSPrivacyCollectedDataTypes` leer; einzige deklarierte API-Kategorie `UserDefaults` (außer Watch-Komplikation: keine) |
| Kein eigenes Backend, keine Fremd-SDKs | `project.yml` hat keinen `packages`-Abschnitt; im App-Code (`LooseEnds/`, `Shared/`, `LooseEndsShare/`, `LooseEndsWatch/`) kein `URLSession`; `https://` kommt nur als Apple-Karten-Link (`Shared/Services/NoteLinks.swift`), in einem Kommentar (`LooseEnds/Views/EditorPage.swift`) und in einem Doc-Kommentar (`Shared/Services/SiriFields.swift`) vor |
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

## English

**Status:** wortgetreue Übersetzung der öffentlichen deutschen Fassung vom 2026-10-27, keine Zusätze, keine Kürzungen
(Henning, 2026-10-30, pauschal über #750 freigegeben, #763). Veröffentlicht am 2026-10-31 unter
https://www.henemm.com/legal/loose-ends/privacy-policy-en/ (Website-PR henemm/henemm-website#76); bei Apple als
Datenschutz-URL der Beta-Lokalisierung en-US gesetzt, wenn `asc-beta.yml` mit `aktion=einrichten` läuft (Vorgabe im Skript
`PRIVACY_URL_EN`, die Repo-Variable `ASC_PRIVACY_POLICY_URL_EN` darf sie überstimmen). Eine Änderung am deutschen Text
gilt erst, wenn auch dieser Abschnitt und die englische Website-Seite angepasst sind.

*Last updated: October 27, 2026*

### 1. Who is responsible?

HENEMM GmbH, Eichenaue 14, 48157 Münster, Germany

Represented by the managing director: Henning Emmrich

Email: henning@henemm.com

You will find more details in the [imprint](/footer-information/imprint/).

### 2. In short, and what is collected

Loose Ends stores your tasks on your device and, if you use iCloud, in your private iCloud.
There is no server of our own, no account with us, no advertising and no tracking. What you say is turned into text on your
device. The app only asks for permissions when you use the function that needs them.

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
- No backend of our own, no analytics or advertising services, no tracking.

### 4. Which permissions the app needs and why

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

### 5. What Apple takes over

In four places Apple's system acts, not the app. There Apple's privacy rules apply, and we promise no more
than the app's code proves:

- **Maps:** Place search and the name of your current place go through Apple Maps.
- **Apple Intelligence:** Where the device can do it, the title is refined by the device's model; what Apple
  promises in doing so is Apple's matter.
- **Siri and Shortcuts:** When capturing through Siri, Apple's behavior applies.
- **Dictation on the Watch:** The Watch takes in text through watchOS dictation; where Apple sends what is said
  is for Apple to regulate.

### 6. Your rights, deletion and changes

You can ask for information, have wrong data corrected and have data deleted at any time.
You delete your tasks in the app itself, and the app's iCloud area in the iCloud settings under
"Manage Storage". For everything else an email to the address above is enough.

You can also complain to a data protection supervisory authority, for example
to the State Commissioner for Data Protection and Freedom of Information of North Rhine-Westphalia.

If anything material changes, we adjust this page and name the date at the top.
