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
