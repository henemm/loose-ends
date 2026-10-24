---
entity_id: feat-293-nur-mikrofon
type: feature
created: 2026-10-24
updated: 2026-10-24
status: draft
workflow: feat-293-nur-mikrofon
---

# Spec: Spracherfassung fragt nur noch nach dem Mikrofon (#293)

## Approval

- [ ] Approved

## GitHub Issue

#293 „Spracherfassung: nur noch das Mikrofon erfragen (Mac zeigte keinen Dialog)“. Kontext, Analyse und Versuchsergebnis: `docs/context/feat-293-nur-mikrofon.md`, Rohprotokolle `docs/artifacts/feat-293-nur-mikrofon/result-*.txt`.

## Purpose

Die Erfassung fragt heute zwei Rechte ab (Mikrofon und `SFSpeechRecognizer`-Spracherkennung) und sperrt sich, wenn eines fehlt. Auf Hennings Mac erschien nie ein Dialog, weil für die Hauptkennung schon eine Ablehnung gespeichert war; die Erfassung blieb gesperrt.
Jedes zusätzliche Recht ist eine weitere Möglichkeit, in der Sperre „Recht fehlt“ zu landen. Der Versuch vom 2026-10-24 auf Hennings Mac belegt: `SpeechAnalyzer`/`SpeechTranscriber` liefert Text, wenn die Spracherkennung „nie erfragt“ (bleibt `notDetermined`, kein Dialog) und wenn sie „abgelehnt“ ist (`denied`) —
in beiden Läufen «morgen früh beim Bäckerbrot kaufen.». Das Spracherkennungsrecht wird nicht gebraucht. Es wird nicht mehr erfragt und nicht mehr geprüft; die Erfassung erfragt und prüft nur noch das Mikrofon.

**Ohne Modell:** Dieses Ticket führt kein Modell ein und berührt keines; es streicht eine Rechteabfrage.

## Source

- **File:** `LooseEnds/Speech/SpeechCapture.swift`, `LooseEnds/Speech/SpeechAccess.swift`, `LooseEnds/Speech/SpeechDiagnosis.swift`
- **Identifier:** `SpeechCapture.start()`, `SpeechCapture.requestSpeechAuthorization()` (entfällt), `enum SpeechAccess`, `struct SpeechDiagnosis`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `AVAudioApplication.requestRecordPermission` | System-API | die eine verbleibende Abfrage |
| `SpeechAnalyzer`, `SpeechTranscriber`, `AssetInventory` | System-API (Speech, iOS/macOS 26+) | Transkription, prüft das Spracherkennungsrecht nachweislich nicht |
| TCC | System | Rechtespeicher; Ablehnungen früherer Läufe bleiben gespeichert, spielen aber für die Speech-Abfrage keine Rolle mehr |
| `LooseEnds/Views/CaptureView.swift` | Downstream | Sperranzeige (Z. 193–207, `State.accessDenied(SpeechAccess)`) bleibt unverändert; Diagnosefixwert Z. 70 |
| Mac-Menüleisten-Panel (`LooseEnds/Mac`) | Downstream | nutzt dieselbe `CaptureView`, keine eigene Änderung |
| `LooseEndsUITests/CaptureCancelCrashTests`, `.github/workflows/speech-stress.yml` | Downstream | Stresslauf setzt Rechte zurück (`simctl privacy reset all`), `allowSystemAlerts` tippt bis zu zwei Dialoge weg; funktioniert mit einem Dialog, bleibt unverändert |
| `LooseEndsWatch/WatchCaptureView.swift` | nicht betroffen | System-Diktat, kein `SFSpeechRecognizer`/`SpeechAnalyzer` |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Speech/SpeechCapture.swift` | MODIFY | `requestSpeechAuthorization()` samt Funktion, `speechGranted` (Z. 50, 103, 320) und Kommentar Z. 100 entfernen; Logzeile nur Mikrofon; Sperre über `SpeechAccess.missing(microphone:)`. Die Zeitmarke `rights` bleibt und misst jetzt nur die Mikrofonabfrage |
| `LooseEnds/Speech/SpeechAccess.swift` | MODIFY | nur noch `case microphone`; `static func missing(microphone: Bool) -> SpeechAccess?`; Meldung „Microphone access is off…“; Mac-URL immer `Privacy_Microphone`, iOS unverändert `UIApplication.openSettingsURLString` |
| `LooseEnds/Speech/SpeechDiagnosis.swift` | MODIFY | Feld `speech` aus Struct, `make`-Parameter und Text; neuer Text „No text yet — model: %@ · microphone: %@ · buffers: %lld · results: %lld“ |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | Z. 70: `speech: true` aus dem Fixwert für `--ui-testing-speech-diagnosis` (eine Zeile) |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | „Speech recognition is off. …“ und „Microphone and speech recognition are off. …“ entfernen; Diagnoseschlüssel ersetzen, Deutsch „Noch kein Text — Modell: %@ · Mikrofon: %@ · Puffer: %lld · Ergebnisse: %lld“ |
| `LooseEndsTests/SpeechAccessTests.swift` | MODIFY | auf die eine Abfrage umbauen |
| `LooseEndsTests/SpeechDiagnosisTests.swift` | MODIFY | Z. 12–16, 63–71, 91: Feld `speech` raus, neue Prüfungen |
| `LooseEndsUITests/SpeechDiagnosisLineTests.swift` | MODIFY | Z. 38: erwarteter Text ohne „speech: yes“ |

### Estimated Changes

- Files: 8 (5 Produktiv, davon `CaptureView` eine Zeile und `Localizable.xcstrings` reine Daten; 3 Test)
- LoC: ca. +30/−70

**Überschreitung der Dateigrenze, offen benannt:** 8 Dateien liegen über der Grenze von 4–5, der Umfang (±100 LoC) deutlich darunter. Eine Teilung ginge nur so: Schnitt 1 streicht die Abfrage und lässt das Diagnosefeld `speech` stehen — es zeigte dann einen Wert, den niemand mehr setzt (bedeutungslos, irreführend) —, oder das Feld wird in ein Mini-Ticket ausgelagert, was der PO nicht will (Bündeln nach Ziel, Henning 2026-10-02). Die Dateien gehören zu einem Ziel und ändern sich gemeinsam; Vorschlag: ein Schnitt.

**Bewusst nicht Teil des Schnitts:** Der Plist-Schlüssel `NSSpeechRecognitionUsageDescription` (`project.yml` Z. 101 iOS/Mac, Z. 159 Watch) bleibt. Ihn zu entfernen berührt `project.yml` und `Info.plist` (Geräteliste) ohne Nutzen. Folge: auf iOS bleibt der Schalter „Spracherkennung“ in den App-Einstellungen sichtbar; er ist unschädlich, die App liest ihn nicht.

## Implementation Details

1. `SpeechCapture.start()` fragt nur `AVAudioApplication.requestRecordPermission()`. Fehlt es, geht der Zustand wie bisher auf `.accessDenied(.microphone)`. `requestSpeechAuthorization()` und `speechGranted` entfallen, ebenso der Kommentar „nicht dokumentiert“ (Z. 100); die Frage ist durch den Versuch beantwortet.
2. `SpeechAccess` bleibt als Enum (mit einem Fall), damit `State.accessDenied(SpeechAccess)` und `CaptureView` unverändert bleiben. `settingsURL` auf dem Mac zeigt immer auf `Privacy_Microphone`.
3. `SpeechDiagnosis` verliert das Feld `speech`; die Diagnose bleibt sonst gleich (Auslösung nach 6 s ab erstem hörbarem Pegel, Fixwert unter `--ui-testing-speech-diagnosis`).
4. Strings: zwei Texte entfallen, einer (Diagnosezeile) ändert sich im Schlüssel. Kein Text kommt neu hinzu außer dem Ersatzschlüssel der Diagnose.
5. Nutzer mit früher abgelehnter Spracherkennung (Henning auf dem Mac) sind danach nicht mehr gesperrt; das ist erwünscht.

**Side-Effects, ausdrücklich:** keine neuen Berechtigungen, kein AppStorage-Key, keine `Info.plist`- oder `project.yml`-Änderung, keine Audio-Dateien, kein CloudKit-Feld. Zwei Texte entfallen, einer ändert sich.

## Test Plan

### Automated Tests (TDD RED)

- [ ] `SpeechAccessTests`: GIVEN Mikrofon fehlt WHEN `SpeechAccess.missing(microphone: false)` THEN `.microphone`; GIVEN Mikrofon da WHEN `missing(microphone: true)` THEN `nil`.
- [ ] `SpeechAccessTests`: GIVEN `.microphone` WHEN `message` gelesen THEN nennt sie das Mikrofon und nicht die Spracherkennung.
- [ ] `SpeechAccessTests` (macOS-Ziel, sonst bedingt übersprungen mit Benennung): GIVEN `.microphone` WHEN `settingsURL` THEN enthält `Privacy_Microphone`.
- [ ] `SpeechDiagnosisTests`: GIVEN die Diagnose ohne Feld `speech` WHEN Mikrofon ja und Mikrofon nein THEN verschiedene Texte, und kein Text enthält „speech“ oder „Sprache“ als Feldbezeichnung.
- [ ] `SpeechDiagnosisTests`: GIVEN die bestehenden Auslöse- und Zähler-Fälle (Z. 12–16, 63–71, 91) WHEN ohne `speech` erzeugt THEN unverändertes Verhalten.
- [ ] `SpeechDiagnosisLineTests` (UI, `--ui-testing-speech-diagnosis`): GIVEN der Fixwert WHEN die Erfassung öffnet THEN steht in `speechDiagnosisLabel` „No text yet — model: installed · microphone: yes · buffers: 62 · results: 0“.
- Alle drei zuerst RED (Compile-Fehler bzw. alter Text), danach GREEN. Gesamtlauf: `./scripts/sim.sh sim-unit`.

### Simulator (Stufe 2)

`./scripts/sim.sh test-proof SpeechDiagnosisLineTests`; der Screenshot der Diagnosezeile wird geöffnet und beschrieben (Zeile ohne Sprachfeld).

### Gerät (Stufe 3)

`LooseEnds/Speech/` steht auf der Geräteliste. Nichts auf Hennings Geräten vor seinem wörtlichen „jetzt ist ein Test möglich“.
Mac: Rechte der Prüfkennung `com.henning.looseends.probe` zurücksetzen (`tccutil reset Microphone` und `SpeechRecognition`), Mac-Prüfbau starten, Aufnahme antippen: genau ein Dialog (Mikrofon), danach „Ich höre …“ und Text; Screenshot. iPhone: über TestFlight nach dem Merge, Erfassung hört zu, keine Sperre. Henning bekommt keine Befehlszeilen.

## Acceptance Criteria

- **AC-1:** `SpeechCapture.start()` fragt nur `AVAudioApplication.requestRecordPermission()`; `requestSpeechAuthorization`, `speechGranted`, jeder Aufruf von `SFSpeechRecognizer.requestAuthorization` und der Kommentar „nicht dokumentiert“ sind aus `LooseEnds/Speech/` entfernt (Suche nach `requestAuthorization` und `speechGranted` in `LooseEnds/` ohne Treffer; der historische Kommentar zu `SFSpeechRecognizer` in Z. 9 bleibt).
- **AC-2:** `SpeechAccess.missing(microphone:)` liefert `.microphone` bei `false` und `nil` bei `true`; der Enum kennt nur noch den Fall `microphone`. Belegt durch `SpeechAccessTests`.
- **AC-3:** Die Meldung der Sperre nennt das Mikrofon und nicht die Spracherkennung; die Mac-Einstellungs-URL ist immer `Privacy_Microphone`, iOS bleibt `UIApplication.openSettingsURLString`. Belegt durch `SpeechAccessTests`.
- **AC-4:** `SpeechDiagnosis` hat kein Feld `speech`; der Text lautet „No text yet — model: … · microphone: … · buffers: … · results: …“ (Deutsch „Noch kein Text — Modell: … · Mikrofon: … · Puffer: … · Ergebnisse: …“); Mikrofon ja/nein ergibt verschiedene Texte. Belegt durch `SpeechDiagnosisTests`.
- **AC-5:** Der UI-Test `SpeechDiagnosisLineTests` erwartet den Text ohne „speech: yes“ und ist GREEN; der Fixwert in `CaptureView` setzt kein `speech:` mehr.
- **AC-6:** `Localizable.xcstrings` enthält die Einträge „Speech recognition is off. …“ und „Microphone and speech recognition are off. …“ nicht mehr, und die Diagnosezeile ist mit deutscher Übersetzung geführt; der alte Diagnoseschlüssel mit „speech: %@“ kommt nicht mehr vor.
- **AC-7:** Stufe 2: `sim.sh sim-unit` grün (alle Tests), `sim.sh build` baut, `sim.sh test-proof SpeechDiagnosisLineTests` liefert den Beleg, Screenshot angesehen und beschrieben. `CaptureCancelCrashTests` und `speech-stress.yml` bleiben unverändert und grün.
- **AC-8:** Keine weiteren Änderungen: keine neue Berechtigung, kein AppStorage-Key, keine `Info.plist`-/`project.yml`-Änderung (`NSSpeechRecognitionUsageDescription` bleibt), keine Audio-Dateien, Watch unverändert.
- **AC-9 (Gerät, Mac, nach Hennings „jetzt ist ein Test möglich“):** Mit zurückgesetzten Rechten der Prüfkennung zeigt der Mac-Prüfbau beim Antippen der Aufnahme genau einen Dialog (Mikrofon); danach erscheint „Ich höre …“ und der gesprochene Text; Screenshot als Beleg.
- **AC-10 (Gerät, iPhone, TestFlight nach Merge):** Die Erfassung hört zu, ohne Sperre; Henning bekommt Buildnummer und Prüfschritte in „Was testen“, keine Befehlszeile. Das Ticket bleibt bis zu seiner Rückmeldung offen.

## Alternativen

- **Nur den Hinweistext ändern („macOS fragt nur einmal, schalte es hier ein“), beide Abfragen bleiben:** verworfen. Der Versuch zeigt, dass das Recht nie gebraucht wird; der Text würde den Nutzer in die Einstellungen schicken, um ein überflüssiges Recht zu erteilen, und die Sperre bliebe bestehen.
- **Recht nur lesen statt fragen (`authorizationStatus()`), nie sperren, nur in der Diagnose zeigen:** verworfen. Es wäre der Mittelweg, falls nur „nie erfragt“ funktioniert hätte; „abgelehnt“ liefert ebenfalls Text (Lauf 3), also gibt es nichts zu lesen, was eine Entscheidung stützt, und das Feld bliebe bedeutungslos.
- **Auf `DictationTranscriber` wechseln:** verworfen. Es würde die Wahl aus #64/#279A kippen, nur nötig, wenn `SpeechTranscriber` das Recht verlangte; der Versuch belegt das Gegenteil. Ein Wechsel des Transkribierers wäre ein eigenes Ziel (Latenz, #279A) und gehört nicht in dieses Ticket.
- **Gewählt:** nur das Mikrofon erfragen und prüfen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — die Doppelabfrage war nie eine Entscheidung, nur Vorsicht aus #64 (offene Frage in `docs/specs/feat-64-speechanalyzer.md` Z. 94/174), jetzt durch den Versuch beantwortet; keine ADR wird gekippt.
- **Rationale:** Streichung einer überflüssigen Abfrage ohne neue Struktur, Dependency oder Datenform.

## Definition of Done

- [ ] AC-1 bis AC-8 durch Tests und Simulator belegt
- [ ] PR mit `Closes #293`, CI grün, gemergt, Hauptordner aktuell
- [ ] TestFlight-Bau mit „Was testen“, Rückmeldung Hennings und Mac-Beleg schließen AC-9 und AC-10
- [ ] Beobachtbar: die Erfassung hört auf dem Mac nach genau einem Dialog zu; die Sperre „Spracherkennung fehlt“ gibt es nicht mehr
- [ ] Regressionslauf grün

## Changelog

- 2026-10-24: Initial spec created
