# Datenschutz – Entwurf

**Status:** Entwurf, Freigabe Henning. Nicht in die App eingebaut und nicht veröffentlicht. Die öffentliche
Adresse, die Apple für TestFlight verlangt, ist #705.

Geschrieben aus dem, was der Code am 2026-10-26 belegt (#342, Teil 2). Jede Aussage hat unten einen Beleg im
Code; was der Code nicht beweist, steht unter „Offen, nicht belegt“.

## Kurzfassung für Nutzer

Loose Ends speichert deine Aufgaben auf deinem Gerät und, wenn du iCloud nutzt, in deinem privaten iCloud.
Es gibt keinen eigenen Server, kein Konto bei uns, keine Werbung und kein Tracking. Gesprochenes wird auf deinem
Gerät in Text umgewandelt. Die App fragt nur nach Rechten, wenn du die Funktion benutzt, die sie braucht.

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
| Spracherkennung | Text ist hinterlegt (siehe Offen) | Umwandlung auf dem Gerät |
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
- **Verantwortlicher, Kontaktadresse, Löschung des iCloud-Bereichs:** fehlen noch; Henning ergänzt sie vor
  der Veröffentlichung (#705).
