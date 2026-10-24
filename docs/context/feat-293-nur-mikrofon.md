# Context: feat-293-nur-mikrofon

## Request Summary
Die Spracherfassung soll nur noch nach dem Mikrofon fragen, nicht zusätzlich nach dem Recht „Spracherkennung“
(#293). Auslöser: Auf Hennings Mac erschien nie ein Dialog, weil für die Hauptkennung schon eine Ablehnung
gespeichert war (am 2026-10-09 nachgestellt). Jedes zusätzliche Recht ist eine weitere Möglichkeit, in der Sperre
„Recht fehlt“ zu landen. Umgebaut wird nur, wenn belegt ist, dass `SpeechAnalyzer` mit abgelehnter
Spracherkennung trotzdem Text liefert.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Speech/SpeechCapture.swift` | `start()` Z. 98–107 fragt `AVAudioApplication.requestRecordPermission()` und `requestSpeechAuthorization()` (Z. 389–397, `SFSpeechRecognizer.requestAuthorization`, `nonisolated` wegen #60). Mit `SpeechAccess.missing(...)` → `.accessDenied`. `speechGranted` fließt in die Diagnose (Z. 320). Kommentar Z. 100: „Ob SpeechAnalyzer das Spracherkennungsrecht braucht, ist nicht dokumentiert“ |
| `LooseEnds/Speech/SpeechAccess.swift` | reine Abbildung (#280): `.microphone`, `.speechRecognition`, `.both`, Meldetexte, Einstellungs-URL (Mac: `Privacy_Microphone` / `Privacy_SpeechRecognition`) |
| `LooseEndsTests/SpeechAccessTests.swift` | 35 Zeilen, prüft alle vier Kombinationen, Texte und URLs |
| `LooseEnds/Speech/SpeechDiagnosis.swift` | Diagnosezeile „Ton ohne Text“ (#274/#402) zeigt `speech: <ja/nein>` (Z. 78–79). Fällt die Abfrage weg, wird das Feld bedeutungslos oder muss aus `SFSpeechRecognizer.authorizationStatus()` gelesen werden (ohne Abfrage) |
| `LooseEndsTests/SpeechDiagnosisTests.swift`, `LooseEndsUITests/SpeechDiagnosisLineTests.swift` | prüfen die Diagnosezeile mit dem Feld `speech` |
| `LooseEnds/Views/CaptureView.swift` Z. 193–207 | zeigt `access.message` und „Open Settings“ (`speechUnavailableLabel`, `speechOpenSettingsButton`) |
| `LooseEnds/Resources/Localizable.xcstrings` | Texte „Speech recognition is off…“, „Microphone and speech recognition are off…“ |
| `project.yml` Z. 101 (iOS/Mac), Z. 159 (Watch) | `NSSpeechRecognitionUsageDescription`. Der Schlüssel kann bleiben; ihn zu entfernen würde `project.yml` und `Info.plist` berühren (Geräteliste) und bringt nichts |
| `LooseEndsUITests/CaptureCancelCrashTests.swift` + `.github/workflows/speech-stress.yml` | Stresslauf setzt die Rechte vor jedem Lauf zurück (`simctl privacy reset all`), `allowSystemAlerts` tippt bis zu zwei Dialoge weg, also funktioniert er auch mit nur einem Dialog |
| `LooseEndsWatch/WatchCaptureView.swift` | Watch nutzt das System-Diktat, kein `SFSpeechRecognizer`/`SpeechAnalyzer` → nicht betroffen |

## Existing Patterns
- Rechteabfragen sind `nonisolated static` (Rückruf kommt auf einem Hintergrund-Strang, #60).
- Fehlende Rechte werden als reine Abbildung (`SpeechAccess`) getestet, ohne TCC.
- Recht abgelehnt → Hinweis plus „Open Settings“, weil das System nie erneut fragt (#280).
- Unter `--ui-testing` wird die Spracherkennung übersprungen. Der Erfassungsweg ohne `--ui-testing` läuft nur im Stresslauf.

## Dependencies
- Upstream: `AVAudioApplication.requestRecordPermission()`, `SFSpeechRecognizer.requestAuthorization`,
  `SpeechAnalyzer`/`SpeechTranscriber`/`AssetInventory` (Speech, iOS/macOS 26+), TCC.
- Downstream: `CaptureView` (Anzeige der Sperre), `SpeechDiagnosis` (Feld `speech`), Mac-Menüleisten-Panel (dieselbe `CaptureView`).

## Existing Specs
- `docs/specs/feat-64-speechanalyzer.md` Z. 94 und 174: offene Frage „braucht SpeechAnalyzer das Recht?“, sollte auf dem Gerät gelesen werden. Wurde nie beantwortet.
- `docs/specs/bug-60-speech-authorization-crash.md`: Absturz an der Abfrage, Grund für `nonisolated`.
- `docs/specs/fix-274-*`: Diagnosezeile mit Rechte-Feldern.

## Risks & Considerations
- **Kernfrage unbelegt:** Liefert `SpeechTranscriber` mit abgelehnter Spracherkennung Text? Ticket-Recherche
  (WWDC25 Session 277, Blogbeitrag) sagt ja, Apples Doku sagt dazu nichts ausdrücklich. Ohne Beleg kein Umbau, dann greift die Alternative (nur Hinweistext).
- **Wo beweisen:** Der Simulator hat keine Modell-Assets (Memory: seit #228 unter `--ui-testing` abgeschaltet). Ob
  `SpeechTranscriber` im iOS-27-Simulator überhaupt Text liefert, muss geprüft werden. Der Mac ist laut Regel
  Hennings Gerät, also läuft ein Mac-Testprogramm nur nach „jetzt ist ein Test möglich“.
- **Plattformen:** Die Änderung gilt für iPhone, iPad und Mac gleichermaßen. Auf iOS bleibt das Recht in den Einstellungen sichtbar, solange der Plist-Schlüssel da ist; das ist unschädlich.
- **Bestehende Ablehnung:** Nutzer mit abgelehnter Spracherkennung (Henning auf dem Mac früher) wären nach dem Umbau nicht mehr gesperrt. Das ist erwünscht.
- **Geräteliste:** `LooseEnds/Speech/` → Stufe 3 über TestFlight (Mac und iPhone).
- **Diagnosezeile:** Feld `speech` muss weg oder auf den reinen Lesestatus umgestellt werden. Dazu gehört die Anpassung von Unit- und UI-Test.

## Analysis

### Type
Feature (Vereinfachung der Rechteabfrage), mit vorgeschaltetem Beweisversuch.

### Recherche (2026-10-24)
- WWDC25 Session 277 (https://developer.apple.com/videos/play/wwdc2025/277/): Beispiel prüft nur das Mikrofon
  („user denied mic permission“), kein `SFSpeechRecognizer.requestAuthorization`.
- https://blakecrosley.com/blog/speech-framework-vs-sfspeechrecognizer: SpeechAnalyzer nutze das Speech-Recht nicht, aber ohne Beleg.
- Gegenstimmen ohne Beleg: https://levelup.gitconnected.com/bring-advanced-speech-to-text-to-your-app-with-speechanalyzer-6ed25a84586c,
  https://tessl.io/registry/dpearson2699/swift-ios-skills/3.9.0/files/skills/speech-recognition/SKILL.md (beide Rechte).
- https://github.com/simonw/speech-analyzer-cli: „first transcription should prompt for Speech Recognition“, aber der Quelltext
  (`AppleTranscriber.swift`) ruft `requestAuthorization` selbst, also kein Beleg für eine Prüfung in SpeechAnalyzer.
- Fazit: Keine Quelle beweist es, Apples Doku schweigt. Der Versuch entscheidet.

### Beweisort
Simulator und GitHub-Läufer haben keine Sprachmodelle (`installedLocales` leer, #419, CI-Lauf 39217743850). Bleibt Hennings
Mac (de_DE `installed`, #274). Testprogramm `docs/artifacts/feat-293-nur-mikrofon/` (eigene Kennung
`com.henning.speechprobe293`, Sandbox + `audio-input`, Ton aus Datei per `say`, kein Mikrofon): `run.sh` fährt
(1) Recht nie erfragt → transkribieren, (2) einmal fragen, Henning tippt „Nicht erlauben“, (3) abgelehnt → transkribieren,
danach `tccutil reset` für die Probe-Kennung. Gebaut, nicht gestartet — wartet auf „jetzt ist ein Test möglich“.

### Affected Files (bei Ergebnis „Text kommt“)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | `requestSpeechAuthorization` und `speechGranted` raus, Sperre nur bei fehlendem Mikrofon |
| `LooseEnds/Speech/SpeechAccess.swift` | MODIFY | nur noch `.microphone`; `missing(microphone:)`; Mac-URL immer `Privacy_Microphone` |
| `LooseEnds/Speech/SpeechDiagnosis.swift` | MODIFY | Feld `speech` aus der Diagnosezeile |
| `LooseEndsTests/SpeechAccessTests.swift`, `LooseEndsTests/SpeechDiagnosisTests.swift` | MODIFY | an die eine Abfrage anpassen |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | zwei Texte („Speech recognition is off…“, „Microphone and speech recognition…“) entfallen |
Plist-Schlüssel `NSSpeechRecognitionUsageDescription` bleibt (sonst Geräteliste `project.yml`, kein Nutzen).
UI-Test `SpeechDiagnosisLineTests` nur, falls er `speech:` prüft.

### Scope Assessment
- Files: 5–6 (davon 2 Tests, 1 Strings-Katalog)
- Estimated LoC: +20/−60
- Risk Level: LOW nach positivem Beweis (fällt eine Sperre weg, nichts Neues kommt hinzu); MEDIUM ohne Beweis
- Geräteliste: `LooseEnds/Speech/` → Stufe 3 über TestFlight (Mac: genau ein Dialog, danach hört die Erfassung zu)

### Technical Approach
Empfehlung: Versuch fahren. Kommt in (1) und (3) Text → nur noch Mikrofon erfragen (Tabelle oben).
Kommt in (3) kein Text oder ein Fehler → kein Umbau; Alternative greift (siehe unten), Ergebnis ins Ticket.

### Alternativen
1. Nur Hinweistext ändern („macOS fragt nur einmal, schalte es hier ein“), beide Abfragen bleiben (Ticket-Alternative).
2. Speech-Recht nur lesen statt fragen (`authorizationStatus()`), nie sperren, nur in der Diagnose zeigen — Mittelweg, falls der Versuch nur „nie erfragt“ bestätigt, „abgelehnt“ aber scheitert.
3. Auf `DictationTranscriber` wechseln (WWDC: braucht keine Siri-/Diktat-Einstellung) — kippt die Wahl aus #64/#279A, nur wenn SpeechTranscriber das Recht wirklich verlangt.
Keine ADR wird gekippt (die Doppelabfrage war nie eine Entscheidung, nur Vorsicht aus #64, Spec Z. 94/174).

### Dependencies
`AVAudioApplication.requestRecordPermission`, `SpeechAnalyzer`/`SpeechTranscriber`, TCC. Downstream `CaptureView`, Mac-Menüleisten-Panel, Diagnosezeile.

### Versuchsergebnis (2026-10-24, Hennings Mac, nach „jetzt ist ein Test möglich“)
| Lauf | Speech-Recht | Text |
|------|--------------|------|
| 1 nie erfragt | notDetermined (bleibt, kein Dialog durch SpeechAnalyzer) | «morgen früh beim Bäckerbrot kaufen.» |
| 2 erfragt | → denied (Henning: „Nicht erlauben“) | — |
| 3 abgelehnt | denied | «morgen früh beim Bäckerbrot kaufen.» |
Protokolle: `docs/artifacts/feat-293-nur-mikrofon/result-*.txt`. SpeechAnalyzer prüft das Speech-Recht nicht und fragt nie selbst.
Befund gegen den Plan: keiner. Das Mikrofonrecht selbst wurde nicht geprüft (Ton aus Datei), es bleibt ohnehin die eine Abfrage.
Nebenbei: `tccutil reset` findet die Probe-Kennung nicht (Bundle unter /private/tmp, LaunchServices -10814); der Eintrag „denied“
für `com.henning.speechprobe293` bleibt, betrifft nur das Wegwerfprogramm.

### Entscheidung
Umbau nach Tabelle „Affected Files“: nur noch das Mikrofon erfragen. Alternativen 1–3 entfallen, weil der Beweis positiv ist.

### Open Questions
- keine
