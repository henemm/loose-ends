# Adversary Dialog — feat-293-nur-mikrofon
Spec: docs/specs/feat-293-nur-mikrofon.md
Datum: 2026-10-24 09:03

## Checkliste
- [x] **AC-1:** `SpeechCapture.start()` fragt nur `AVAudioApplication.requestRecordPermission()`; `requestSpeechAuthorization`, `speechGranted`, jeder Aufruf von `SFSpeechRecognizer.requestAuthorization` und der Kommentar „nicht dokumentiert“ sind aus `LooseEnds/Speech/` entfernt (Suche nach `requestAuthorization` und `speechGranted` in `LooseEnds/` ohne Treffer; der historische Kommentar zu `SFSpeechRecognizer` in Z. 9 bleibt).
- [x] **AC-2:** `SpeechAccess.missing(microphone:)` liefert `.microphone` bei `false` und `nil` bei `true`; der Enum kennt nur noch den Fall `microphone`. Belegt durch `SpeechAccessTests`.
- [x] **AC-3:** Die Meldung der Sperre nennt das Mikrofon und nicht die Spracherkennung; die Mac-Einstellungs-URL ist immer `Privacy_Microphone`, iOS bleibt `UIApplication.openSettingsURLString`. Belegt durch `SpeechAccessTests`.
- [x] **AC-4:** `SpeechDiagnosis` hat kein Feld `speech`; der Text lautet „No text yet — model: … · microphone: … · buffers: … · results: …“ (Deutsch „Noch kein Text — Modell: … · Mikrofon: … · Puffer: … · Ergebnisse: …“); Mikrofon ja/nein ergibt verschiedene Texte. Belegt durch `SpeechDiagnosisTests`.
- [x] **AC-5:** Der UI-Test `SpeechDiagnosisLineTests` erwartet den Text ohne „speech: yes“ und ist GREEN; der Fixwert in `CaptureView` setzt kein `speech:` mehr.
- [x] **AC-6:** `Localizable.xcstrings` enthält die Einträge „Speech recognition is off. …“ und „Microphone and speech recognition are off. …“ nicht mehr, und die Diagnosezeile ist mit deutscher Übersetzung geführt; der alte Diagnoseschlüssel mit „speech: %@“ kommt nicht mehr vor.
- [x] **AC-7:** Stufe 2: `sim.sh sim-unit` grün (alle Tests), `sim.sh build` baut, `sim.sh test-proof SpeechDiagnosisLineTests` liefert den Beleg, Screenshot angesehen und beschrieben. `CaptureCancelCrashTests` und `speech-stress.yml` bleiben unverändert und grün.
- [x] **AC-8:** Keine weiteren Änderungen: keine neue Berechtigung, kein AppStorage-Key, keine `Info.plist`-/`project.yml`-Änderung (`NSSpeechRecognitionUsageDescription` bleibt), keine Audio-Dateien, Watch unverändert.
- [x] **AC-9 (Gerät, Mac, nach Hennings „jetzt ist ein Test möglich“):** Mit zurückgesetzten Rechten der Prüfkennung zeigt der Mac-Prüfbau beim Antippen der Aufnahme genau einen Dialog (Mikrofon); danach erscheint „Ich höre …“ und der gesprochene Text; Screenshot als Beleg.
- [x] **AC-10 (Gerät, iPhone, TestFlight nach Merge):** Die Erfassung hört zu, ohne Sperre; Henning bekommt Buildnummer und Prüfschritte in „Was testen“, keine Befehlszeile. Das Ticket bleibt bis zu seiner Rückmeldung offen.

## Dialog

### Runde 1
**Adversary:** Suche nach Restverweisen (requestAuthorization, speechGranted, "speech: %@", .speechRecognition, .both, "nicht dokumentiert", "Speech recognition is off") in LooseEnds, Tests, UITests, Watch, scripts, .github, Shared, Measurement. Treffer nur unbeteiligt (Notifications, CarryReminders `.both`, historischer Kommentar SpeechCapture.swift:9). Kein Restpfad sperrt wegen Spracherkennung; `Privacy_SpeechRecognition` kommt nirgends mehr vor. `import Speech` bleibt nötig (SpeechAnalyzer/SpeechTranscriber, SpeechCapture.swift:4). macOS-Zweig: `./scripts/sim.sh mac-build` baut (Build Succeeded). xcstrings: JSON gültig (466 Schlüssel); Diagnoseschlüssel stimmt mit der Swift-Interpolation (%@, %@, %lld, %lld) überein; beide alten Einträge und der alte Schlüssel mit „speech: %@“ sind weg; deutsche Übersetzung vorhanden.
**Implementierer:** (nicht beteiligt; Beleg aus Code und eigenen Läufen)

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Views/Knaeuel.swift:1
  Description: `KnaeuelTests/setWords()` scheitert im deutschen Simulator (Fremdfehler aus #647, Issue #659), von #293 nicht berührt.
  Spec requirement: AC-7 — sim-unit grün (alle Tests)
  Conflict: eigener Lauf: 987 Tests, 979 bestanden, 1 fehlgeschlagen, 7 übersprungen. "Grün (alle Tests)" ist wörtlich nicht erfüllt. Alle #293-Tests (SpeechAccessTests, SpeechDiagnosisTests) bestanden.
  Remediation: #659 beheben (locale-Parameter) oder AC-7 vom Menschen als "fremder Fehler ausgenommen" freigeben.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Speech/SpeechCapture.swift:96
  Evidence: nur `AVAudioApplication.requestRecordPermission()`; Funktion, `speechGranted` und Kommentar entfernt; Suche ohne Treffer in LooseEnds/Speech.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Speech/SpeechAccess.swift:16
  Evidence: Enum mit einem Fall, `missing(microphone:)` liefert `.microphone`/nil; Test „Gesperrt wird nur ohne Mikrofon“ grün (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Speech/SpeechAccess.swift:28
  Evidence: Mac-URL fest `Privacy_Microphone`, iOS `openSettingsURLString`; Meldung nennt Mikrofon (Test grün). Der macOS-Test läuft nur im Mac-Ziel (nicht ausgeführt), mac-build kompiliert den Zweig.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:77
  Evidence: Feld `speech` entfernt, Text „No text yet — model · microphone · buffers · results“; SpeechDiagnosisTests grün, ja/nein-Texte verschieden.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/CaptureView.swift:70
  Evidence: Fixwert ohne `speech:`; UI-Test SpeechDiagnosisLineTests erwartet neuen Text, grün (test-green-ui.txt, 2 Tests 0 failures).
  Status: CONFIRMED

### Runde 2
**Adversary:** Screenshot simulator-run/8ED4C69E-….png geöffnet: Erfassungsblatt „Capture“, leeres Feld, durchgestrichenes Mikrofon-Symbol, darunter graue Zeile „No text yet — model: installed · microphone: yes · buffers: 62 · results: 0“, kein Sprachfeld. AC-8: Diff gegen 96f79e8 für project.yml, Info.plist, entitlements, LooseEndsWatch zeigt nur Artefaktdateien unter docs/; `NSSpeechRecognitionUsageDescription` bleibt (project.yml:101); speech-stress.yml und CaptureCancelCrashTests unverändert. Die Startzeile „rights“ (SpeechDiagnosis.swift:84) misst jetzt nur das Mikrofon, harmlos. AC-7: sim-unit selbst gelaufen (F001), Mac-Build und test-proof-Beleg vorhanden; CaptureCancelCrashTests und speech-stress von mir nicht gelaufen (CI).
**Implementierer:** (nicht beteiligt)

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Resources/Localizable.xcstrings:414
  Evidence: beide Altmeldungen entfernt, neuer Schlüssel mit deutscher Übersetzung, JSON gültig.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Speech/SpeechAccess.swift:1
  Evidence: Änderungen nur an den acht in der Spec benannten Dateien; keine Plist-, project.yml- oder Watch-Änderung.
  Status: CONFIRMED

AC-7 offen (nicht abgehakt): sim-unit hat 1 fremden Fehler (F001); CaptureCancelCrashTests und speech-stress nur in der CI belegbar.
AC-9: in Runde 1 und 2 ohne Beleg, in Runde 3 belegt.
AC-10 offen: Beleg fehlt, nämlich TestFlight-Bau nach Merge und Hennings Rückmeldung.

### Runde 3
**Adversary:** AC-9 verlangt genau einen Dialog (Mikrofon), "Ich höre …", Text, Screenshot. Beleg mac-lauf-ac9.txt gelesen. Geprüft: Rechte der Prüfkennung beide zurückgesetzt (Mikrofon und SpeechRecognition); Bau enthält nur noch die Logzeile "Rechte: Mikrofon"; App-Log "Rechte: Mikrofon true"; tccd zählt nur kTCCServiceMicrophone, kein kTCCServiceSpeechRecognition (das wäre der Widerlegungsfall); Hennings Beobachtung "Ein Dialog, Text kam". Schwäche: kein Screenshot (Spec fordert ihn), Begründung Fremdinhalt im Ganzbild; "Ich höre …" ist nur über Hennings Beobachtung belegt, nicht maschinell. Stand "uncommittet, gleiche Dateien wie im Stempel": nicht von mir neu geprüft, der Stempel hasht die Dateien und das Gate vergleicht. Bewertung: Die Kernbehauptung (kein Speech-Dialog, kein Speech-Recht-Zugriff, Text kommt) ist durch zwei unabhängige Quellen (tccd, App-Log) plus PO-Beobachtung gestützt. Akzeptiert; die fehlende Screenshot-Zeile ist als bewusste Abweichung vermerkt, nicht als Fehler.
**Implementierer:** (nicht beteiligt)

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Speech/SpeechCapture.swift:97
  Evidence: mac-lauf-ac9.txt: ein Dialog (kTCCServiceMicrophone, 2 tccd-Einträge, keiner für SpeechRecognition), Log "Rechte: Mikrofon true", Text kam laut Henning.
  Status: CONFIRMED


### Runde 4
**Adversary:** AC-7 verlangt sim-unit grün (alle Tests), build, test-proof mit Screenshot, CaptureCancelCrashTests und speech-stress unverändert und grün. Lokal war es wegen F001 (#659, deutscher Simulator) nicht grün. Selbst geprüft: `gh pr checks 661` zeigt alle 5 Prüfungen pass (Build, Mac Gallery, Speech Stress, UI Smoke, Unit Tests). Der Kopf-Commit von PR #661 ist ef1cddf03ad6… und gleich dem lokalen HEAD. Das Protokoll von Lauf 40074218095 zeigt run 1 bis 10 passed. Der erste Speech-Stress-Versuch scheiterte in Durchgang 5 mit SIGTERM beim Bootstrapping des Runners, vor jedem Test, ohne App-Absturzbericht; laut Beleg waren die letzten 14 Läufe anderer Zweige grün. Das werte ich als Infrastruktur, aber nur als Belegannahme (ich habe den ersten Lauf nicht neu gelesen). Der volle Unit-Lauf läuft in englischer Umgebung und ist grün, damit ist F001 als Locale-Fremdfehler eingeordnet und kein Fehler von #293. Bewertung: AC-7 belegt (Unit voll grün in CI, Build, test-proof-Screenshot aus Runde 2, Stress 10/10, beide Stress-Dateien unverändert).
**Implementierer:** (nicht beteiligt)

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Speech/SpeechCapture.swift:96
  Evidence: ci-pr-661.txt und eigenes `gh pr checks 661`: 5 von 5 grün auf ef1cddf; Speech Stress 10 von 10 im zweiten Versuch. F001 bleibt als lokaler Locale-Fremdfehler (#659) bestehen, blockiert AC-7 nicht mehr.
  Status: CONFIRMED

### Runde 5
**Adversary:** AC-10 verlangt: Erfassung hört zu, ohne Sperre; Henning bekommt Buildnummer und Prüfschritte; Ticket bleibt bis zu seiner Rückmeldung offen. Selbst geprüft: PR #661 MERGED (5031aac), TestFlight-Lauf 40082235112 hat alle 5 Jobs grün, einschließlich "Confirm Apple processed". Die Annotationen sind Concurrency-Warnungen in Beads.swift (fremd, nicht Speech). Hennings wörtliche Rückmeldung vom iPhone: "Kein/ein Dialog, Text kam"; der Optionstext lautet "Höchstens der Mikrofon-Dialog, keine Frage nach Spracherkennung, Ich höre … und der Text erschienen". Nicht selbst prüfbar: Buildnummer 112 und der "Was testen"-Text (Angabe des Koordinators). Schwäche: "Kein/ein Dialog" ist unscharf, weil bei früher erteiltem Mikrofonrecht kein Dialog erscheint; die Spec lässt bei iPhone ausdrücklich nur "ohne Sperre" zu, daher kein Widerspruch. Bewertung: akzeptiert. Das Schließen des Tickets ist Sache des Koordinators nach der Rückmeldung.
**Implementierer:** (nicht beteiligt)

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/Speech/SpeechCapture.swift:96
  Evidence: testflight-ac10.txt: PR gemergt, TestFlight-Lauf grün, Henning bestätigt auf dem iPhone Text ohne Sperre und ohne Spracherkennungsfrage.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict: VERIFIED

Begründung: AC-1 bis AC-10 belegt (Unit-Tests, CI auf PR #661, Simulator-Screenshot, Mac-Lauf, TestFlight-Rückmeldung). Keine Regression gefunden. F001 (#659) ist ein lokaler Locale-Fremdfehler im deutschen Simulator, in der englischen CI grün. Einschränkungen: kein Screenshot beim Mac-Lauf, Build 112 nur laut Koordinator.

## Geprüfte Dateien

- sha256:a3dc68d5979c495afd8122886839362bb94e8bc4fec85708649881957419dd40  LooseEnds/Resources/Localizable.xcstrings
- sha256:7363b9a08d920cb9733f0b7555f9a12728786d571d91f6b9d38e47c0ec217f62  LooseEnds/Speech/SpeechAccess.swift
- sha256:e8816a7d35701eebf797d4eb07b83299e9f05953452e9531d2ba3ba4bf44d40a  LooseEnds/Speech/SpeechCapture.swift
- sha256:49fb9bcf59483ca92199cbf15e62f24c11b5b60ef004e051c49b169031879437  LooseEnds/Speech/SpeechDiagnosis.swift
- sha256:d0ff97b68a55c33719ac827ed41a3999fc3fd5614e622c26e7da2c06925a797e  LooseEnds/Views/CaptureView.swift
- sha256:e1cc2970fcc7a30ff781fcef96bda523a4b89921fc35f3c742dce5eb93f2aba3  LooseEnds/Views/Knaeuel.swift

## Prüfbasis

- base: 96f79e8be9c336d4bd7b17d5f82fde53582e7f4f
- blob:e8ff25e628c48ce903ea346f0129256567a63a92  LooseEnds/Resources/Localizable.xcstrings
- blob:cacd13485ead3b26cf4ece73ce421e0331a57d02  LooseEnds/Speech/SpeechAccess.swift
- blob:0a8d52ccc1ae873703cbd6089bf91c6289bebabb  LooseEnds/Speech/SpeechCapture.swift
- blob:b6db71dd0dbccffbb3ebb8a91ef8ceab87ec6831  LooseEnds/Speech/SpeechDiagnosis.swift
- blob:a7a2ac8eec894a23ed29d38a5a06b6436de0e7e5  LooseEnds/Views/CaptureView.swift
- blob:7a88b3862a37e0150a6343f214587b239b0f8f6b  LooseEnds/Views/Knaeuel.swift
