# Context: 279-pegel-mikrofon (#279 Teil B und C)

## Request Summary
Die Erfassungs-Szene soll ab dem ersten Moment eindeutig zeigen, dass zugehört wird und Ton ankommt:
die Pegelanzeige (Wellenform) muss bei normaler Sprache deutlich ausschlagen (B), und der Zustand
„hört zu“ / „hört nicht zu“ muss am Mikrofon-Symbol eindeutig sein (C). Anlass: Henning, Gerätelauf
#274 (2026-10-08) und Anforderung 2026-10-09: „Es muss für den User klar werden, dass schon
aufgezeichnet wird, auch wenn der Text noch nicht direkt erscheint.“ Die Lücke bis zum ersten Wort
liegt nach #274 bei 1,5–2 s.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Speech/Waveform.swift` | Pegelrechnung: RMS × 6, linear, auf 0…1 begrenzt; Ringpuffer 40 Werte (= 4 s bei 100-ms-Puffern). Kern von B. |
| `LooseEnds/Views/CaptureView.swift` (`listeningRow`, `WaveformView`) | Zeile mit Wellenform (Canvas, 32 pt hoch, Akzentfarbe, Balken min. 2 pt) und Mikrofonknopf (`mic.fill` / `mic`, `.title2`, keine Farbe/Bewegung). Kern von C. |
| `LooseEnds/Speech/SpeechCapture.swift` | `state` (`.idle`, `.listening`, …), `isListening`, `waveform`; Tap ruft `Waveform.level(of:)` je 100-ms-Puffer. Audio-Session `.record`, Modus **`.measurement`** (seit #8, f928954). |
| `LooseEndsTests/WaveformTests.swift` | Unit-Tests der Pegelrechnung; legt heute fest, dass Sprache ±0,05 zwischen 0,2 und 0,5 liegt — muss bei neuer Kurve angepasst werden. |
| `LooseEndsUITests/SpeechDiagnosisLineTests.swift` | Festzustand `--ui-testing-speech-diagnosis` zeigt die Zeile ohne Mikrofon; Knopf steht dort auf „Listen“ (idle). Vorbild für einen Festzustand „hört zu mit Pegel“. |
| `LooseEndsUITests/SpeechListeningTests.swift` | Bestehender Sprach-UI-Test. |
| `docs/project/03-design-briefing.md` | „Mikrofon hört sofort, Wellenform zeigt es“; Farbbudget ADR-14: Akzent = tippbar, Rot = Zeitdruck, Grau = Hierarchie, Grün = Erledigen; muss in Graustufen funktionieren. |

## Existing Patterns
- Reine, testbare Logik in `LooseEnds/Speech/` (Waveform, SpeechDiagnosis, SpeechAccess), View liest nur.
- UI-Tests ohne Mikrofon: Festzustände über Startargumente (`--ui-testing-speech-diagnosis`), weil Simulator und CI kein Mikrofon haben.
- Barrierefreiheit: Knopf trägt `accessibilityLabel` „Listen“ / „Stop listening“, Wellenform ist ausgeblendet.

## Dependencies
- Upstream: AVAudioEngine-Tap (100-ms-Puffer, Float32), `AVAudioSession` (iOS) Modus `.measurement`.
- Downstream: nur `CaptureView`. Die Erkennung bekommt den Puffer unabhängig vom Pegel (`box.feed`).

## Research (2026-10-10)
- `AVAudioSession.Mode.measurement` minimiert die Signalverarbeitung des Systems, schaltet u. a. die
  automatische Verstärkung ab → Eingangspegel deutlich niedriger als im Standardmodus.
  Quelle: Apple-Doku AVAudioSession.Mode (https://developer.apple.com/tutorials/data/documentation/avfaudio/avaudiosession/mode-swift.struct/voicechat.md)
- Übliche Pegelanzeigen rechnen RMS in Dezibel um und bilden einen festen Bereich (z. B. −50 … 0 dB
  oder −80 … 0 dB) linear auf 0…1 ab. Quelle: Kodeco AVAudioEngine-Tutorial
  (https://www.kodeco.com/21672160-avaudioengine-tutorial-for-ios-getting-started?page=2),
  Apple-Forum https://developer.apple.com/forums/thread/704486.
- Vermutete Ursache für B (noch zu belegen in der Analyse): lineare Skala + `.measurement`-Modus →
  Sprach-RMS typischerweise ~0,005–0,05 → Balken 3–30 % Höhe.

## Existing Specs
- `docs/specs/fix-274-sprache-latenz-messung.md` — Zeitmessung/Diagnose, gleiche Szene.
- Verwandt: #297 („Ich höre …“ kurz nach dem Öffnen) — gleiche Lücke, anderes Mittel (Text statt Pegel/Symbol).

## Risks & Considerations
- `LooseEnds/Speech/` und `CaptureView` → Gerätestufe 3 Pflicht; nur nach Hennings „jetzt ist ein Test möglich“.
- Den Session-Modus zu ändern (`.measurement` → `.default`/`.spokenAudio`) beeinflusst auch die Erkennung (Pegel, Rauschunterdrückung); #274 hängt an diesem Pfad. Lieber nur die Anzeige skalieren, Modus nur mit Beleg.
- Ohne Mikrofon im Simulator ist die echte Pegelhöhe nur am Gerät belegbar; Simulator zeigt das Aussehen über einen Festzustand.
- Farbbudget: „hört zu“ darf nicht Rot (Zeitdruck) oder Grün (Erledigen) werden; Akzent ist zulässig, da tippbar.
- Mac teilt die View; Session-Modus gilt nur auf iOS, Pegel am Mac anders.
- Scope ≤ 250 LoC, 4–5 Dateien.

## Analysis

### Type
Bug (Anzeige): Pegel kaum sichtbar (B), Zustand des Mikrofons mehrdeutig (C). Teil A (Latenz) ist durch #274 (`.fastResults`) weitgehend erledigt und hier nicht im Schnitt.

### Befund (2026-10-10, Code + Rechnung, Simulator-Bild)
- `Waveform.level` = RMS × 6, linear. Ohne automatische Verstärkung (`.measurement`) liegt Sprache bei
  etwa −40 … −25 dBFS → RMS 0,01 … 0,056 → 0,06 … 0,34 → **2 … 11 pt von 32 pt**, Ruhe 2 pt (Mindesthöhe) =
  „gepunktete Linie“. Gerätewerte nicht gemessen (Stufe 3, nur mit Hennings Freigabe).
- Vor dem ersten Puffer ist `levels` leer → die Zeile zeigt gar nichts, nur das Mikrofon (Simulator-Bild
  `docs/artifacts/279-pegel-mikrofon/heute-*.png`).
- Mikrofon: `mic.fill` vs. `mic`, gleiche Farbe, `.title2`, keine Bewegung → Zustand nur an der Füllung erkennbar.

### Entwurf (vor der Spec, wartet auf Hennings Wahl)
Artefakt: https://claude.ai/artifact/AzbEoV5CNYbvDvP3KjRFTi, Quelle `docs/artifacts/279-pegel-mikrofon/entwurf.html`.
- **A (Empfehlung):** dB-Skala −50 … −10 dBFS → 0 … 1; graue Grundlinie über volle Breite ab Öffnen; Mikrofon als
  runder Knopf: hört zu = gefüllter Akzentkreis + Ring, der mit dem Pegel wächst; aus = grau umrandet, `mic.slash`, Linie grau.
- **B (Alternative):** gleiche Skala/Grundlinie, Symbol bleibt, Statuswort „Hört zu“ (Akzent) / „Pausiert“ (grau) über der Linie.
- Verworfen: Messmodus abschalten (ändert Erkennungspfad aus #274, ohne Messung nicht), nur Faktor erhöhen
  (leise flach, laut am Anschlag), Rot (Farbbudget: Zeitdruck).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Speech/Waveform.swift` | MODIFY | `level(of:)` in dBFS, Bereich −50 … −10 auf 0 … 1 |
| `LooseEndsTests/WaveformTests.swift` | MODIFY | Skala-Tests an dB-Stützpunkten (−50 → 0, −30 → 0,5, −10 → 1, Stille → 0) |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | `WaveformView`: Grundlinie, Farbe nach Zustand; Mikrofonknopf nach Entwurf; Festzustand für UI-Test |
| `LooseEndsUITests/SpeechListeningIndicatorTests.swift` | CREATE | Festzustand `--ui-testing-speech-listening` (hört zu, feste Pegel): Knopf-Label/Wert, Screenshot-Beleg |

### Scope Assessment
- Files: 4
- Estimated LoC: +110/−20
- Risk Level: LOW–MEDIUM (nur Anzeige; die Erkennung bekommt den Puffer unabhängig vom Pegel; aber `LooseEnds/Speech/` → Gerätestufe 3)

### Technical Approach
Reine Pegelrechnung in dB (testbar ohne Mikrofon), View liest nur. Zustand über `speech.isListening`; der Ring
folgt dem letzten Pegelwert (`levels.last`), mit `.smooth`-Animation, bei „Bewegung reduzieren“ fest. Mac teilt die View;
dort gibt es keinen Messmodus, die dB-Skala passt trotzdem (eher lauter). Der Pegel am Gerät wird bei Stufe 3 mit
Hennings Freigabe geprüft; vorher Simulator mit Festzustand.

### Dependencies
`AVAudioEngine`-Tap → `Waveform.level` → `SpeechCapture.waveform` → `CaptureView`. Nichts sonst liest `Waveform`.

### Open Questions
- [x] Henning (2026-10-10) zu A/B: „Ich hätte das Wort dahin geschrieben wo später die erkannten Worte erscheinen. Mit einer Animation“
  → das ist #297 („Ich höre …“), gleiches Ziel → **#297 in diesen Schnitt gebündelt**. Neuer Entwurf C in der Vorschau (Version 2):
  grau „Ich höre“ + drei Punkte (nacheinander, Reduce Motion: still) an der Stelle des Platzhalters im Textfeld, solange
  zugehört wird und noch kein Text da ist; erstes Wort ersetzt es; nicht zuhören → gewohnter Platzhalter. Dazu dB-Pegel
  mit grauer Grundlinie; Mikrofon unverändert. Erscheint ab Beginn des Zuhörens, ohne extra Verzögerung.
- [x] **Freigabe Henning 2026-10-10:** „Ich finde den runden Atmenden Knopf gut plus das Wort das bei erkanntem Text ersetzt wird.“
  → **Spec-Umfang = Entwurf C + Mikrofonknopf aus A:** (1) dB-Pegel −50 … −10 dBFS mit grauer Grundlinie ab Öffnen;
  (2) grau „Ich höre“ + drei nacheinander aufleuchtende Punkte an der Platzhalterstelle des Textfelds, solange zugehört wird und
  noch kein Text da ist, erstes erkanntes Wort ersetzt es, nicht zuhören → gewohnter Platzhalter; (3) Mikrofon als runder Knopf:
  hört zu = gefüllter Akzentkreis + Ring, der mit dem Pegel wächst; aus = grau umrandet, `mic.slash`, Linie grau.
  Reduce Motion: Punkte und Ring stehen still. Schließt #279 (B, C) und #297.
- Scope mit C + A-Knopf: ~+150/−20 LoC in 4–5 Dateien (`Waveform.swift`, `WaveformTests.swift`, `CaptureView.swift`, neuer UI-Test, ggf. kleine reine Regel für den Hinweis in `LooseEnds/Speech/`).
