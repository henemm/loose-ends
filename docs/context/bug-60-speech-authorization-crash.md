# Context: Bug #60 — App stirbt beim Öffnen der Erfassung

## Request Summary
(+) öffnet die Erfassung, danach reagiert die App auf nichts mehr — auf Hennings iPhone und im
Simulator gleichermaßen. Ursache ist ein harter Prozessabbruch bei der Rechteabfrage für die
Spracherkennung.

## Related Files
| Datei | Bedeutung |
|------|-----------|
| `LooseEnds/Speech/SpeechCapture.swift` | `requestSpeechAuthorization()` — der abstürzende Rückruf |
| `LooseEnds/Views/CaptureView.swift` | ruft `speech.start()` in `onAppear`; `speechWanted` schaltet die Erfassung unter `--ui-testing` ab |
| `LooseEndsUITests/CaptureSmokeTests.swift` | startet immer mit `--ui-testing`, deckt den Weg daher nie ab |
| `LooseEndsUITests/CaptureCancelCrashTests.swift` | neuer Nachstell-Test, startet ohne den Schalter |

## Beleg
Absturzbericht `LooseEnds-2026-09-19-130218.ips`, auslösender Strang `com.apple.root.default-qos`:

    _dispatch_assert_queue_fail
    _swift_task_checkIsolatedSwift
    closure #1 in closure #1 in static SpeechCapture.requestSpeechAuthorization()
    __TCCAccessRequest_block_invoke_8

Der Nachstell-Test war vor dem Fix rot: `com.henning.looseends crashed`.

## Existing Patterns
- `AVAudioApplication.requestRecordPermission()` wird direkt `await`-et und braucht keinen eigenen
  Abschluss — nur die Speech-Autorisierung hat noch die Rückruf-Form.
- Das restliche Projekt hält Aktor-Grenzen sauber: der Audio-Tap springt mit `Task { @MainActor in }`
  zurück, statt Zustand quer zu schreiben.

## Dependencies
- Upstream: `Speech` (SFSpeechRecognizer), `AVFoundation`, TCC-Dienst des Systems
- Downstream: `CaptureView` (jeder Erfassungsweg: (+), Teilen-Erweiterung, Kurzbefehl „Open capture")

## Risks & Considerations
- Der Fix entfernt nur eine Aktor-Bindung; `state` und `transcript` bleiben hauptstrang-gebunden.
- Die eigentliche Lücke ist die Testlage: solange UI-Tests die Spracherfassung abschalten, bleibt
  dieser Weg ungedeckt. Der neue Test schließt genau das.
- Getrennt davon offen: die Kurzbefehle tun nichts (eigener Vorgang, eigene Nachstellung).
