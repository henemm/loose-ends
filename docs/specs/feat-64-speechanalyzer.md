---
entity_id: feat-64-speechanalyzer
type: feature
created: 2026-10-07
updated: 2026-10-07
status: draft
workflow: feat-64-speechanalyzer
---

# Spec: #64 — Spracherfassung auf SpeechAnalyzer umstellen

## Approval

- [ ] Approved

## Purpose

Die Erfassung erkennt Sprache über die neue Schnittstelle `SpeechAnalyzer` mit `SpeechTranscriber`, ausschließlich auf dem
Gerät. Die alte Schnittstelle `SFSpeechRecognizer` behauptete „verfügbar", obwohl das Modell fehlte, und konnte es nicht
nachladen (2026-09-19). Die neue sagt ehrlich, ob das Modell da ist, und lädt es auf Wunsch nach.

Produktentscheidungen (Henning, 2026-10-07):
- **Modell fehlt → erst fragen.** Die Erfassung zeigt einen Hinweis mit Knopf „Laden". Erst der Tipp lädt, mit Fortschritt
  in Prozent. Tippen geht die ganze Zeit.
- **Nur auf dem Gerät.** Die Einmal-Frage „Spracherkennung über Apple?" und der Server-Versuch entfallen. Geht es auf dem
  Gerät nicht, bleibt Tippen.
- **Sprache des Geräts**, wie bisher.

Ein Modell (Apple Intelligence) kommt nicht vor; Spracherkennung ist keine Anreicherung.

## Belegte Schnittstellen (iOS-27-SDK, CI-Probe 2026-10-07)

Aus `Speech.swiftinterface` und `AVFAudio.swiftinterface` von Xcode 27.0 gelesen, nicht aus dem Gedächtnis:

| Schnittstelle | Zweck |
|---|---|
| `AssetInventory.status(forModules:) async -> Status` mit `.unsupported`, `.supported`, `.downloading`, `.installed` | Stufe 0: Sprache unterstützt, Modell da? |
| `AssetInventory.assetInstallationRequest(supporting:) async throws -> AssetInstallationRequest?`, dort `progress: Progress` und `downloadAndInstall() async throws` | Stufe 1: Modell laden, mit Fortschritt |
| `SpeechTranscriber(locale:transcriptionOptions:reportingOptions:attributeOptions:)`, `reportingOptions: [.volatileResults]`, `results` (`isFinal`, `text`) | Erkennung, flüchtige und feste Ergebnisse |
| `SpeechTranscriber.supportedLocale(equivalentTo:) async -> Locale?` | Gerätesprache auf eine unterstützte abbilden |
| `SpeechAnalyzer(modules:)`, `start(inputSequence:)`, `finalizeAndFinishThroughEndOfInput()`, `cancelAndFinishNow()` | Lauf starten und beenden |
| **neu in 27:** `AnalyzerInputConverter.converter(compatibleWith:)` und `convert(_:at:) throws -> [AnalyzerInput]` | Tonformat umwandeln, mit Fehler statt stumm nichts |
| **neu in 27:** `AVAudioNode.installAudioTap(onBus:bufferSize:format:tapProvider:) throws` mit `AVReadOnlyAudioPCMBuffer` | Ersatz für das veraltete `installTap`; wirft statt abzustürzen |
| `AVAudioPCMBuffer(copying: AVReadOnlyAudioPCMBuffer)` | Puffer für Wandler und Wellenform |

Der Wandler aus iOS 27 nimmt der Umstellung die größte Falle aus der Recherche ab: ein falsches Format wirft jetzt, statt
stumm nichts zu liefern. Es gibt keine eigene `AVAudioConverter`-Logik.

## Source

- **Neu:** `LooseEnds/Speech/SpeechReadiness.swift` — reine Abbildung `AssetInventory.Status` → was die Erfassung zeigt
- **Umgebaut:** `LooseEnds/Speech/SpeechCapture.swift`
- **Geändert:** `LooseEnds/Views/CaptureView.swift` (Hinweis mit „Laden" und Fortschritt; Server-Frage entfernt)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Speech/SpeechReadiness.swift` | NEU | `enum SpeechReadiness { case unsupported, needsModel, loading, ready }` und `static func from(_ status: AssetInventory.Status)`. Dazu `static func fraction(_ progress: Progress) -> Double` (0…1, nie NaN). Rein, ohne Systemzugriff. |
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | `State`: `idle`, `listening`, `unavailable(String)`, `needsModel`, `loadingModel(Double)`. `needsServerConsent`, `serverConsent`, `triedServerRecognition`, `availableRecognizer`, `RequestBox` und der `SFSpeechRecognizer`-Pfad entfallen. Neu: `loadModel()`. Siehe unten. |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | Zeile für `needsModel` mit Knopf „Load" (`speechLoadModelButton`), Zeile für `loadingModel` mit Fortschritt (`speechLoadingLabel`). Die Server-Frage (`alert`) und `needsConsentBinding` entfallen. |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Neue Texte auf Deutsch; die drei Texte der Server-Frage raus. |
| `LooseEndsUITests/CaptureCancelCrashTests.swift` | MODIFY | Startargument `-speechServerRecognitionAllowed` entfällt, weil es den Schalter nicht mehr gibt. |
| `LooseEndsUITests/SpeechListeningTests.swift` | MODIFY | Die Regel „nie scheinbar zuhören" erkennt zusätzlich `speechLoadModelButton` als sichtbare Antwort; der Zweig für `speechConsentLabel` entfällt. |
| `LooseEndsTests/SpeechReadinessTests.swift` | NEU | Unit-Tests zur Abbildung und zum Fortschritt |
| `docs/context/spracherfassung-teststufen.md` | MODIFY | Stufe 3 nennt den Wandler aus iOS 27; die Server-Frage ist Geschichte |

Erwartet: rund 180 Zeilen Produktcode (davon rund 90 entfernt) und 60 Zeilen Tests.

**Geräteliste berührt:** `LooseEnds/Speech/`. Stufe 3 (Hennings iPhone) ist Pflicht. `project.yml`, `Info.plist` und die
Entitlements bleiben unverändert: Die Texte für Mikrofon und Spracherkennung gibt es schon.

### Nicht in diesem Ticket

- Watch: Sie kennt `SpeechAnalyzer` nicht. Dort bleibt das Systemdiktat.
- Stufe 4 (Erkennung mit Audiodatei in CI): Der Simulator hat keine Sprachmodelle (`status` = `unsupported`). Den Test gibt
  es erst, wenn ein CI-Simulator Modelle hat; bis dahin belegt Stufe 7 auf dem Gerät die Erkennung.
- Wortschatz-Hinweise (`contextualStrings`): Die neue Schnittstelle hat keine, gebraucht wurden sie nie.

## Implementation Details

### Ablauf in `SpeechCapture.start()`

1. Gerätesprache über `SpeechTranscriber.supportedLocale(equivalentTo: .current)`. `nil` → `unavailable("Speech recognition
   is not available for this language. You can type instead.")`.
2. Transcriber anlegen, `SpeechReadiness.from(await AssetInventory.status(forModules: [transcriber]))`:
   - `unsupported` → `unavailable(…)` wie in Schritt 1
   - `needsModel` → `state = .needsModel`, Ende. Kein Download ohne Tipp.
   - `loading` (das System lädt schon, etwa aus einer anderen App) → wie `needsModel`; der Tipp hängt sich an denselben
     Download.
   - `ready` → weiter
3. Mikrofon- und Spracherkennungsrecht wie bisher. Ob `SpeechAnalyzer` das Spracherkennungsrecht überhaupt braucht, ist
   nicht dokumentiert. Die Abfrage bleibt; der Zustand wird geloggt und auf dem Gerät gelesen (Stufe 7).
4. Ticket-Prüfung gegen `stopCount` wie bisher (#184): Kam in der Zeit ein `stop()`, öffnet nichts das Mikrofon.
5. Audiositzung wie bisher. `converter = try await AnalyzerInputConverter.converter(compatibleWith: [transcriber])`.
   `AsyncStream<AnalyzerInput>.makeStream()`. `try await analyzer.start(inputSequence:)`.
6. Tap über `installAudioTap`: Puffer kopieren (`AVAudioPCMBuffer(copying:)`), Pegel für die Wellenform, `converter.convert`
   und jedes Ergebnis in den Stream. Wirft der Wandler, wird das einmal geloggt, und die Erfassung endet sichtbar
   (`unavailable`). Der Wandler ist keine `Sendable`-Klasse; er liegt wie bisher der Request in einer Box mit Sperre, die nur
   der Audio-Strang benutzt.
7. Ergebnisse in einer `Task`: `isFinal` hängt an den festen Text, sonst ersetzt der flüchtige Teil den letzten flüchtigen.
   `transcript = fest + flüchtig`. Ein Fehler in `results` beendet das Zuhören sichtbar, wie bisher bei
   `recognitionFailed` (Stufe 6).

### `stop()`

Synchron wie bisher (Abbrechen ruft es): `stopCount += 1`, Tap entfernen, Engine stoppen, Stream beenden, Ergebnis-Task
abbrechen, `analyzer.cancelAndFinishNow()` in einer losgelösten `Task`, Audiositzung freigeben. Läuft ein Download, bricht
`stop()` das Warten darauf ab. Den Download selbst führt das System zu Ende; er ist beim nächsten Öffnen fertig.

### `loadModel()`

`assetInstallationRequest(supporting:)` liefert `nil` → das Modell ist inzwischen da → `start()`. Sonst
`state = .loadingModel(0)`. Der Fortschritt wird alle 0,5 s aus `request.progress` gelesen (`SpeechReadiness.fraction`), bis
`downloadAndInstall()` zurückkehrt. Danach `start()`. Wirft der Download (offline, kein Platz), zeigt die Erfassung
`unavailable("The speech model could not be loaded. You can type instead.")`, und der nächste Öffnen fragt erneut.

### Oberfläche (CaptureView)

| Zustand | Zeile unter dem Textfeld |
|---|---|
| `needsModel` | „Speech model for German is missing." + Knopf „Load" (Akzent, tappbar) |
| `loadingModel(f)` | „Loading speech model … 42 %" mit `ProgressView(value: f)` |
| `unavailable` | wie bisher, ein Satz in Grau |
| `idle`, `listening` | wie bisher: Wellenform und Mikrofon-Knopf |

Die Sprache im Hinweis kommt aus `Locale.current.localizedString(forLanguageCode:)`. Abbrechen und Tippen ins Feld gehen in
jedem Zustand.

## Test Plan

### Automated Tests (TDD RED zuerst)

`SpeechReadinessTests`:
- `.unsupported` → `unsupported`, `.supported` → `needsModel`, `.downloading` → `loading`, `.installed` → `ready`
- `fraction`: 0 von 0 ist 0 (nicht NaN), 50 von 100 ist 0,5, mehr als fertig bleibt 1

UI (bestehend, angepasst):
- `SpeechListeningTests.testCaptureNeverPretendsToListen`: Im Simulator meldet `status` `unsupported`; die Erfassung zeigt
  innerhalb von 15 s `speechUnavailableLabel`. Ein `speechLoadModelButton` zählt ebenfalls als Antwort.
- `CaptureCancelCrashTests`: Abbrechen schließt das Blatt, (+) öffnet es erneut. Speech Stress (10×) läuft mit, weil die PR
  `LooseEnds/Speech/**` berührt.

### Gerät (Stufe 7, Pflicht)

Auf „LE Prüfbau" (eigene Installation, Modelle wie bei Henning):
1. (+) antippen und einen Satz sprechen. Der Text erscheint live, „Fertig" legt die Aufgabe an.
2. Spricht Henning zum ersten Mal nach der Installation, prüft das Protokoll `Speech`: `status installed`, Ton kommt an.
3. Fehlt das Modell (Gerätesprache auf eine andere umgestellt, etwa Englisch UK), zeigt die Erfassung „Load". Nach dem Tipp
   läuft der Fortschritt, danach hört das Mikrofon zu.

## Acceptance Criteria

- **AC-1 Ehrlich:** Given ein Gerät ohne Modell für die Gerätesprache / When die Erfassung öffnet / Then zeigt sie „Load"
  und lädt nichts ohne Tipp. Tippen geht sofort.
- **AC-2 Laden sichtbar:** Given „Load" ist getippt / When das Modell lädt / Then steht der Fortschritt in Prozent da, und
  danach hört das Mikrofon zu, ohne erneuten Tipp.
- **AC-3 Abbrechbar:** Given das Modell lädt / When Henning „Abbrechen" tippt oder ins Feld tippt / Then schließt das Blatt
  bzw. endet das Warten sofort, und nichts hängt.
- **AC-4 Nur auf dem Gerät:** Es gibt keinen Pfad zu Apples Servern mehr und keine Frage danach.
- **AC-5 Nie scheinbar zuhören:** `SpeechListeningTests` bleibt grün.
- **AC-6 Keine Veralt-Warnungen** aus `LooseEnds/Speech` im CI-Build.
- **AC-7 Regression:** Unit, Build, UI-Smoke und Speech Stress (10×) grün.

## Risiken

- **Im Simulator nicht prüfbar:** Erkennung, Laden und Fortschritt laufen nur auf dem Gerät. Deshalb ist die Logik dahinter
  (`SpeechReadiness`) rein und getestet, und Stufe 7 ist Pflicht.
- **Speech Stress verliert Abdeckung:** Im Simulator endet die Erfassung jetzt bei `unsupported`, bevor das Mikrofon
  öffnet. Der Stresstest prüft dann Abbrechen ohne laufende Engine. Der Absturz aus #184 lag im Engine-Start; den deckt der
  Simulator nicht mehr ab. Das ist ehrlich: Bisher startete er dort eine Engine, deren Erkennung nie lief.
- **Spracherkennungsrecht:** Braucht `SpeechAnalyzer` es nicht, fragt die App einmal zu viel. Wird auf dem Gerät gelesen
  und, falls überflüssig, in einem eigenen Ticket entfernt (dann mit Änderung an `Info.plist`).

## Alternativen (verworfen)

- **`CaptureInputSequenceProvider`** (neu in 27, liefert `AnalyzerInput` direkt von einem `AVCaptureDevice`): kein Tap, kein
  Wandler. Aber die Wellenform braucht die Pegel, und `AnalyzerInput.buffer` ist in 27 veraltet. Engine + Tap behält die
  Wellenform ohne Umweg.
- **`DictationTranscriber`** statt `SpeechTranscriber`: gedacht für Geräte ohne `SpeechTranscriber`-Modelle. Henning hat ein
  iPhone 16 Pro. Kann später als Rückfall ergänzt werden, wenn `status` dort `unsupported` meldet.
- **Eigener `AVAudioConverter`**: Der Wandler aus iOS 27 erledigt das und wirft bei falschem Format. Eigener Code wäre die
  Falle „stumm nichts", die die Recherche beschreibt.

## Definition of Done

- AC-1 bis AC-7 erfüllt; Stufe 7 auf dem Gerät von Henning bestätigt.
- `docs/project/04-stand.md` nennt die Umstellung.
- Abschlussbericht mit der Gerätezeile.
