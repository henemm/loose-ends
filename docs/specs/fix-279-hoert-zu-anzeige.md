---
entity_id: fix-279-hoert-zu-anzeige
type: bugfix
created: 2026-10-10
updated: 2026-10-10
status: draft
workflow: 279-pegel-mikrofon
---

# Spec: #279 — Erfassung zeigt eindeutig, dass zugehört wird (Pegel, „Ich höre …“, runder Mikrofonknopf)

## Approval

- [ ] Approved (Henning)

## Purpose

Die Erfassung soll ab dem ersten Moment zeigen, dass zugehört wird und Ton ankommt, auch wenn der erste Text noch nicht
da ist (Lücke bis zum ersten Wort nach #274: 1,5–2 s). Heute versagt das aus drei Gründen:

1. **Pegel (#279 B):** `Waveform.level(of:)` rechnet RMS × 6, linear. Die Audio-Session läuft im Modus `.measurement`
   (ohne automatische Verstärkung); normale Sprache liegt bei etwa −30 dBFS (RMS ≈ 0,03) und ergibt damit rund 0,19, also
   gut 6 pt von 32 pt. Leise Sprache bleibt bei der Mindesthöhe von 2 pt („gepunktete Linie“). Gerätewerte sind nicht
   gemessen (Stufe 3).
2. **Leere Zeile:** Vor dem ersten Puffer ist `levels` leer, die Zeile zeigt nichts außer dem Mikrofon.
3. **Zustand mehrdeutig (#279 C):** `mic.fill` gegen `mic`, gleiche Farbe, keine Bewegung — erkennbar nur an der Füllung.

Dazu kommt #297: Ein Hinweis „Ich höre …“ an der Stelle, an der später der erkannte Text erscheint.

Freigegebener Umfang (Henning, 2026-10-10): „Ich finde den runden Atmenden Knopf gut plus das Wort das bei erkanntem Text
ersetzt wird.“ Entwurf: `docs/artifacts/279-pegel-mikrofon/entwurf.html` (Entwurf C plus Mikrofonknopf aus A).

Umfang:

1. **Pegel in Dezibel.** `Waveform.level(of:)` rechnet RMS in dBFS (20·log10) und bildet −55 … −25 dBFS linear auf 0 … 1
   ab (Stille und leere Probe → 0, ≥ −25 dBFS → 1). Normale Sprache (am iPhone gemessen ≈ −40 dBFS, Build 23) landet bei 0,5, also etwa halber Höhe.
2. **Graue Grundlinie** über die volle Breite der Wellenform, sobald die Zeile sichtbar ist (auch vor dem ersten Puffer).
   Balken: Akzentfarbe beim Zuhören, grau, wenn nicht zugehört wird.
3. **Hinweis „Ich höre …“** (EN „Listening …“), grau, an der Platzhalterstelle des Textfelds, solange zugehört wird **und** das
   Textfeld leer ist. Drei Punkte leuchten nacheinander auf. Das erste erkannte Wort ersetzt den Hinweis an derselben Stelle.
   Wird nicht zugehört, steht der gewohnte Platzhalter „What should I remember?“.
4. **Mikrofon als runder Knopf.** Hört zu: gefüllter Kreis in Akzentfarbe, kontrastierendes `mic.fill`, ein Ring darum, der mit
   dem letzten Pegel wächst (`.smooth`). Nicht zuhören: grau umrandeter Kreis mit `mic.slash`. Accessibility-Labels „Listen“ /
   „Stop listening“ und Kennung `micButton` bleiben; Mindest-Tippfläche 44 pt.
5. **Bewegung reduzieren:** Punkte und Ring stehen still.
6. **Farbbudget (ADR-14):** Akzent nur für den tippbaren Knopf und den Pegel beim Zuhören; Hinweis grau; kein Rot, kein Grün.

**Rein regelbasiert.** Pegelrechnung und Hinweisregel sind reine Funktionen; kein Modell, keine neue Abhängigkeit. Die
Erkennung und die Audio-Session bleiben unverändert.

### Abweichungen und Bündelung (ausdrücklich)

- **#297 ist hierher gebündelt** (Ziel gleich: „es hört zu“ vor dem ersten Wort; Henning, 2026-10-10: „Ich hätte das Wort dahin
  geschrieben, wo später die erkannten Worte erscheinen. Mit einer Animation.“). Schließt #297. #279 bleibt offen: Die Verzögerung bis zum ersten Wort und die stoßweisen Ergebnisse (Teil A) sind unverändert (Henning, 2026-10-10: „die Lücke hat sich bisher nicht verändert … Deine bisherigen Versuche haben nichts gebracht“); diese Änderung macht die Wartezeit nur sichtbar, sie verkürzt sie nicht.
- **#297 wünschte „kurze Verzögerung nach dem Öffnen“; freigegeben ist Erscheinen ab Beginn des Zuhörens**, ohne zusätzliche
  Verzögerung.
- **Mac:** Die View ist geteilt. Dort gibt es keinen Messmodus, der Pegel liegt eher höher; die Skala −55 … −25 dBFS passt
  trotzdem (laute Eingabe sättigt bei 1).
- **Nicht im Umfang:** Teil A (Latenz, Vorstart; #274) und jede Änderung des Audio-Session-Modus.

## Source

- **Geändert:** `LooseEnds/Speech/Waveform.swift` (`level(of:)` in dBFS)
- **Neu:** `LooseEnds/Speech/ListeningHint.swift` — reine Regel, kein Framework
- **Geändert:** `LooseEnds/Views/CaptureView.swift` (Grundlinie, Hinweis im Textfeld, runder Knopf, Festzustand)
- **Geändert:** `LooseEnds/Resources/Localizable.xcstrings` (ein Text, DE/EN)
- **Tests:** `LooseEndsTests/WaveformTests.swift` (angepasst, plus Hinweisregel), `LooseEndsUITests/SpeechListeningIndicatorTests.swift` (neu)

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Speech/Waveform.swift` | MODIFY | `level(of samples:)`: RMS → `20·log10(rms)`; `Waveform.floorDecibel = -55`, `ceilingDecibel = -25`; Ergebnis `clamp((db − floor)/(ceiling − floor), 0, 1)`; RMS 0 oder leere Probe → 0 (kein `log10(0)`). Die Puffer-Variante bleibt, sie ruft die Proben-Variante. |
| `LooseEnds/Speech/ListeningHint.swift` | NEU | `enum ListeningHint { case hint, placeholder, none }` und `static func state(isListening: Bool, text: String) -> ...`: zuhören und Text leer (nur Leerraum zählt als leer) → Hinweis; Text vorhanden → kein Hinweis (das Feld zeigt den Text); nicht zuhören und leer → Platzhalter. Rein, ohne Systemzugriff. |
| `LooseEnds/Views/CaptureView.swift` | MODIFY | Textfeld: Hinweis „Listening …“ mit drei nacheinander aufleuchtenden Punkten als grauer Überlagerung an der Platzhalterstelle (`allowsHitTesting(false)`, ausgeblendet für VoiceOver, Kennung `listeningHint`), solange die Regel „Hinweis“ liefert; sonst Platzhalter wie heute. `WaveformView`: graue Grundlinie über die volle Breite, Balkenfarbe nach Zustand. Neuer privater `MicButton`: Kreis, Symbol, Ring nach letztem Pegel (`.smooth`), `reduceMotion` friert Ring und Punkte ein. Festzustand `--ui-testing-speech-listening`. |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Eintrag `Listening …` → `Ich höre …`. Reine Textdatei. |
| `LooseEndsTests/WaveformTests.swift` | MODIFY | Test „speech between 0.2 and 0.5“ ersetzt durch dB-Stützpunkte; Tests der Hinweisregel (Swift Testing, dieselbe Datei, um die Dateizahl klein zu halten). |
| `LooseEndsUITests/SpeechListeningIndicatorTests.swift` | NEU | UI-Smoke im Festzustand (siehe Test Plan). |

Geschätzt **+150 / −20 LoC** (Produktcode rund 100, Tests rund 70).

**Ausnahme von der Dateigrenze (4–5 Dateien): 6 Dateien, ausdrücklich.** Begründung: `Localizable.xcstrings` ist eine reine
Textdatei mit einem Eintrag ohne Logik; der UI-Test ist nach der globalen Regel Pflicht für sichtbare Änderungen. Die
Hinweisregel liegt in einer eigenen kleinen Datei, ihre Tests in `WaveformTests.swift`. Die Änderung ist ein Stück
(Pegel, Hinweis, Knopf bilden zusammen die Antwort auf „hört es zu?“); getrennt entstünden Zwischenstände mit halber
Anzeige. LoC-Grenze (±250) wird eingehalten. Kein Drive-by-Refactoring.

**Geräteliste berührt:** `LooseEnds/Speech/`. Stufe 3 (Hennings iPhone) ist Pflicht. `project.yml`, `Info.plist` und
Entitlements bleiben unverändert. Keine neuen Berechtigungen, keine neuen AppStorage-Schlüssel, keine Audio-Dateien, keine
Änderung an Persistenz oder Modell. Lokalisierung läuft wie bei allen Texten über den String Catalog
(`Localizable.xcstrings`, englischer Schlüssel, deutsche Übersetzung); `LooseEndsShare` hat einen eigenen Katalog, braucht den
Text aber nicht, weil es dort kein Zuhören gibt.

## Implementation Details

### Pegel

`level(of:)`: `rms = sqrt(mean(x²))`. Bei `rms <= 0` Ergebnis 0. Sonst `db = 20 · log10(rms)`, Ergebnis
`min(1, max(0, (db + 55) / 30))`. Stützpunkte: −55 dBFS → 0, −40 dBFS (RMS ≈ 0,01) → 0,5, −25 dBFS (RMS ≈ 0,0562) → 1.
Ein Vollausschlag (RMS 1) und alles über −25 dBFS ergibt 1. Der Ringpuffer (`append`, Kapazität 40) bleibt unverändert.
Die Audio-Session (`.measurement`, #8) bleibt unverändert, weil der Erkennungspfad aus #274 daran hängt.

### Grundlinie und Balken

Die Zeile zeigt ab Sichtbarkeit eine graue Linie über die volle Breite (Hierarchie-Grau, `.secondary`-Ton, 1–2 pt). Die Balken
werden darüber gezeichnet: Akzentfarbe bei `speech.isListening`, sonst grau. Mindesthöhe der Balken bleibt 2 pt.

### Hinweis „Ich höre …“

`ListeningHint.state(isListening:text:)` entscheidet; die View zeigt entsprechend Hinweis oder Platzhalter. Der Hinweis
erscheint in derselben Runde, in der `isListening` wahr wird (keine Verzögerung). Die Punkte laufen als Dreiertakt (jeweils
ein Punkt hell, zwei gedämpft); bei „Bewegung reduzieren“ (`accessibilityReduceMotion`) stehen alle drei gleich. Sobald
`text` nicht leer ist, liefert die Regel „kein Hinweis“, und das Feld zeigt den Text an derselben Stelle. Das Zurückschalten
auf den Platzhalter bei beendetem Zuhören und leerem Feld geschieht über dieselbe Regel.

### Runder Knopf

Mindestens 44 × 44 pt Tippfläche. Hört zu: gefüllter Kreis (`Color.accentColor`), `mic.fill` in `.white`, Ring (Kreislinie,
Akzent mit geringer Deckkraft) mit Durchmesser wachsend aus dem letzten Pegel (`waveform.levels.last`): Durchmesser = Ruhering 52 pt × (1 + 0,35 × Pegel), also 52 → ≈ 70 pt um den 44-pt-Kreis, wie im Entwurf;
die reine Rechnung ist `Waveform.ringScale(for:)` und unit-getestet), Animation `.smooth`. Der Knopf selbst bleibt ruhig, kein
Atmen in der Stille. Nicht zuhören: Kreis nur umrandet in Grau, `mic.slash` in Grau, kein Ring.
`accessibilityLabel` „Stop listening“ / „Listen“, Kennung `micButton`. Reduce Motion: Ring wird nicht animiert und bekommt
die feste Größe × 1,15. Die Tippfläche wächst so mit, dass der größte Ring (× 1,35) nicht abgeschnitten wird.

### Festzustand für den UI-Test

`--ui-testing-speech-listening` wirkt nur zusammen mit `--ui-testing` (Vorbild `--ui-testing-speech-diagnosis`). Dann zeigt
die Erfassung die Zeile, startet **kein** Mikrofon und keine Erkennung, gilt als „hört zu“, hat feste Pegel (u. a. −40 dBFS-Wert
0,5) und ein leeres Textfeld. Der Mikrofonknopf löst im Festzustand nichts aus. Ohne das Argument ändert sich unter
`--ui-testing` nichts.

## Test Plan

### Automated Tests (TDD RED zuerst)

`WaveformTests` (Swift Testing, Unit):

- `testSilenceAndEmptyAreZero`: GIVEN `[]` und `[0, 0, 0, 0]` WHEN `level(of:)` THEN 0.
- `testFloorIsZero`: GIVEN konstante Amplitude für −55 dBFS (≈ 0,00178) THEN Ergebnis 0 (Toleranz 0,01).
- `testMeasuredSpeechIsHalf`: GIVEN −40 dBFS (≈ 0,01, am iPhone gemessene Sprache) THEN 0,5 (Toleranz 0,01).
- `testCeilingIsOne`: GIVEN −25 dBFS (≈ 0,0562) THEN 1 (Toleranz 0,01); GIVEN `[1, -1, 1, -1]` THEN 1.
- `testBelowFloorClampsToZero`: GIVEN −70 dBFS THEN 0.
- `testPeaksAreAboveHalf`: GIVEN −36 dBFS (gemessene Spitzen, ≈ 0,0158) THEN ≈ 0,63 (Toleranz 0,02).
- `testRingScale`: `Waveform.ringScale(for:)` liefert 0 → 1, 0,5 → 1,175, 1 → 1,35; Werte außerhalb 0 … 1 werden begrenzt.
- Der bestehende Ringpuffer-Test bleibt unverändert.
- `testHintWhileListeningAndEmpty`: GIVEN zuhören, Text `""` THEN Hinweis.
- `testHintWhileListeningAndOnlyWhitespace`: GIVEN zuhören, Text `"  "` THEN Hinweis.
- `testNoHintWhenTextPresent`: GIVEN zuhören, Text `"Milch"` THEN kein Hinweis.
- `testPlaceholderWhenNotListening`: GIVEN nicht zuhören, Text `""` THEN Platzhalter.
- `testNoHintWhenNotListeningWithText`: GIVEN nicht zuhören, Text `"Milch"` THEN kein Hinweis.

`SpeechListeningIndicatorTests` (UI-Smoke, Simulator, Englisch erzwungen, Startargumente `--ui-testing`,
`--ui-testing-speech-listening`, `-AppleLanguages (en)`, `-AppleLocale en_US`):

- `testListeningFixedStateShowsHintAndStopButton`: GIVEN Festzustand WHEN Erfassung geöffnet THEN erscheint
  `listeningHint` innerhalb von 10 s mit Label **gleich** `Listening …` (`XCTAssertEqual`, keine CONTAINS-Prüfung), und
  `micButton.label` ist **gleich** `Stop listening`. Screenshot wird angehängt und geöffnet angesehen (hell und dunkel, dunkel
  über das bestehende `--ui-testing-dark`).
- `testHintIsReplacedByTypedText`: GIVEN Festzustand WHEN der Test Text ins Feld tippt THEN verschwindet `listeningHint`.
  (Belegt Ersetzen durch Text in der View; der Erkennungspfad selbst ist im Simulator nicht prüfbar.)
- `testNoHintWithoutArgument`: GIVEN nur `--ui-testing` WHEN Erfassung geöffnet THEN existiert `listeningHint` nicht (der
  gewohnte Platzhalter bleibt).

Der Simulator hat weder Mikrofon noch Sprachmodelle: Die echte Pegelhöhe belegt nur das Gerät (Stufe 3). Der UI-Test belegt
Aussehen und Zustandswechsel, nicht die Pegelwerte.

### Simulator (Stufe 2)

`./scripts/sim.sh build`, `launch` mit Festzustand, `screenshot` hell und dunkel; Screenshots werden geöffnet und beschrieben
(Grundlinie sichtbar, Balken in Akzent, Hinweis grau an der Platzhalterstelle, runder Knopf mit Ring).

### Gerät (Stufe 3, Pflicht, nur nach Hennings wörtlichem „jetzt ist ein Test möglich“)

Prüfbau auf dem iPhone (`./scripts/sim.sh device-build` auf genau dem Stand, vorher `generate`), nie vorher und nie ohne
seine Freigabe, auch nicht lesend: Erfassung öffnen, → „Ich höre …“ mit Punkten steht sofort an der Platzhalterstelle, der
Knopf ist gefüllt mit Ring. Normal sprechen → Balken erreichen etwa die halbe Höhe, der Ring wächst mit; das erste erkannte
Wort ersetzt den Hinweis. Mikrofon abschalten → grauer Knopf mit `mic.slash`, graue Linie, Platzhalter „Was soll ich
aufnehmen?“. Reduce Motion an → Punkte und Ring stehen still.

## Acceptance Criteria

- **AC-1 Skala:** `Waveform.level(of:)` liefert −55 dBFS → 0, −40 dBFS → 0,5, −25 dBFS → 1, Stille und leere Probe → 0
  (Unit-Tests).
- **AC-2 Sprachhöhe:** Normale Sprache (≈ −40 dBFS) erreicht etwa die halbe Balkenhöhe (Belegt am Gerät, Stufe 3).
- **AC-3 Grundlinie:** Die graue Grundlinie über die volle Breite steht, sobald die Zeile sichtbar ist, auch vor dem ersten
  Puffer. Balken sind beim Zuhören Akzent, sonst grau.
- **AC-4 Hinweis:** Solange zugehört wird und das Textfeld leer ist, steht „Ich höre …“ (EN „Listening …“) grau an der
  Platzhalterstelle; die Punkte leuchten nacheinander auf.
- **AC-5 Ersetzen:** Das erste erkannte Wort (nicht-leerer Text) ersetzt den Hinweis an derselben Stelle; bei beendetem
  Zuhören und leerem Feld steht der Platzhalter „What should I remember?“.
- **AC-6 Sofort:** Der Hinweis erscheint ab Beginn des Zuhörens ohne zusätzliche Verzögerung (Abweichung von #297, siehe oben).
- **AC-7 Knopf:** Zuhören = gefüllter Akzentkreis mit `mic.fill` und Ring, der mit dem Pegel wächst (`.smooth`); nicht
  zuhören = grau umrandeter Kreis mit `mic.slash`. Labels „Listen“ / „Stop listening“ und Kennung `micButton` unverändert;
  Tippfläche mindestens 44 pt.
- **AC-8 Reduce Motion:** Mit „Bewegung reduzieren“ stehen Punkte und Ring still.
- **AC-9 Farbbudget:** Akzent nur für Knopf und Pegel beim Zuhören; Hinweis grau; kein Rot, kein Grün; die Szene funktioniert
  in Graustufen.
- **AC-10 Erkennung unverändert:** Keine Änderung an Audio-Session-Modus, Transcriber, Analyzer, Tap, Wandler, Rechteabfrage.
- **AC-11 Festzustand:** Mit `--ui-testing` und `--ui-testing-speech-listening` zeigt die Erfassung Hinweis und Knopf
  „Stop listening“ ohne Mikrofon; ohne das zweite Argument bleibt `--ui-testing` unverändert.
- **AC-12 Regression:** Unit, Build, UI-Smoke und Speech Stress (`LooseEnds/Speech/**` berührt) grün.

## Dependencies

| Komponente | Version | Beschreibung |
|---|---|---|
| `Waveform` / `SpeechCapture.waveform` | bestehend | Pegel-Ringpuffer; nur `level(of:)` ändert sich |
| `SpeechCapture.isListening` | bestehend | Zustand für Knopf, Linie, Hinweis |
| `CaptureView` | bestehend | einziger Leser von `Waveform` |
| `Localizable.xcstrings` | bestehend | ein neuer Eintrag |
| `--ui-testing`, `--ui-testing-dark` | bestehend | Rahmen für den Festzustand |
| Neue Abhängigkeit | – | keine |

## Risiken

- **Gerätepegel aus einem Bildschirmfoto.** Die ursprünglich gerechneten −30 dBFS lagen 10 dB zu hoch: Build 23 zeigte am iPhone
  ≈ −40 dBFS für normale Sprache, ausgemessen an den Balkenhöhen eines Bildschirmfotos des PO. Das ist eine Messung mit einer
  Sprecherin bzw. einem Sprecher in einem Raum; ein anderer Abstand verschiebt den Pegel. Stufe 3 (TestFlight) prüft die Höhe erneut,
  und nachzuziehen wären wieder nur die zwei Konstanten.
- **Überlagerung statt echtem Platzhalter.** Ein `TextField`-Platzhalter kennt keine Animation; der Hinweis ist deshalb eine
  Überlagerung bei leerem Feld. Er darf den Cursor und das Tippen nicht blockieren (`allowsHitTesting(false)`), und der
  VoiceOver-Name des Felds bleibt der Platzhalter-Text.
- **Mac:** keine Messmodus-Dämpfung, Pegel eher lauter und häufiger am Anschlag; akzeptiert (siehe Abweichungen).
- **Ring und Pegelfluss:** `levels.last` ändert sich alle 100 ms; `.smooth` verhindert Flackern. Kein neuer Abschluss mit
  Hauptstrang-Bindung auf dem Audio-Strang; der Tap bleibt unverändert.

## Alternativen (verworfen)

- **Messmodus abschalten (`.measurement` → `.default` / `.spokenAudio`):** würde die automatische Verstärkung zurückbringen,
  ändert aber den Erkennungspfad aus #274 ohne Messung. Verworfen, bis ein Beleg es verlangt; die Anzeige wird stattdessen
  korrekt skaliert.
- **Nur den Faktor erhöhen (z. B. × 6 → × 20):** Leise bleibt flach, laut sättigt sofort am Anschlag; die Dezibel-Skala
  entspricht dem Hören und braucht dieselbe Zeilenzahl. Verworfen.
- **Rot-Markierung für „hört nicht zu“:** Rot heißt Zeitdruck (ADR-14). Verworfen; Grau für aus, Akzent für an.
- **Entwurf B (Statuswort „Hört zu“ über der Linie, Symbol unverändert):** zeigt den Zustand nur als Text an einer zweiten
  Stelle; Henning wählte das Wort an der Platzhalterstelle plus runden Knopf (Entwurf C + A).
- **Kein Modell:** Die Aufgabe ist Anzeige und Arithmetik; ein Modell kommt nicht vor, deshalb entfällt die Zeile „Without the
  model this fails because …“. Rein regelbasiert.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — kein neues Konzept: Es ändern sich eine Pegelformel, eine reine Hinweisregel und die Darstellung der Szene. Rohtext, Anreicherung, Revisions und Persistenz bleiben unberührt; das Farbbudget (ADR-14) und „Regeln vor Modell“ werden eingehalten, keine bestehende ADR wird gekippt.

## Definition of Done

- AC-1 bis AC-12 erfüllt; die neuen und angepassten Unit-Tests sowie `SpeechListeningIndicatorTests` grün, alle bestehenden
  Tests grün.
- Festzustand im Simulator als Screenshot hell und dunkel belegt und angesehen.
- Stufe 3 nur nach Hennings wörtlichem „jetzt ist ein Test möglich“: Pegelhöhe bei normaler Sprache (etwa halbe Balkenhöhe) und
  Hinweis → Wort am Gerät belegt.
- `docs/project/04-stand.md` nennt die Änderung; #297 wird geschlossen, #279 bleibt für Teil A (Verzögerung, Stöße) offen und bekommt einen Kommentar, dass B und C erledigt sind.
- Abschlussbericht ohne Git-Vokabular: was Henning in der Erfassung sieht und was er ausprobieren soll.

## Changelog

- 2026-10-10: Initiale Spec für #279 (B, C) mit gebündeltem #297; Umfang vom PO freigegeben (Entwurf C plus runder Knopf aus A).
- 2026-10-10: #279 wird nicht geschlossen; Teil A ist ungelöst (Hinweis des PO bei der Freigabe).
- 2026-10-10 (Nachbesserung nach Build 23, PO: „das Mikrophone (im Kreis) pulsiert nicht!“): Am iPhone kommt normale Sprache bei
  ≈ −40 dBFS an (Spitzen ≈ −36), ausgemessen am Bildschirmfoto des PO; die Balken erreichten 0,2–0,34. Skala deshalb −55 … −25 dBFS
  (−40 → 0,5). Ring wächst wie im Entwurf: Durchmesser = Ruhering 52 pt × (1 + 0,35 × Pegel), statt 46 → 56 pt; der Knopf selbst bleibt ruhig,
  kein Atmen in der Stille (PO-Wahl „Ring wächst deutlich“). Reduce Motion: Ring fest bei × 1,15.
- 2026-10-10 (F007, mit `override` des PO): Ringformel berichtigt. Bezugsgröße ist der Ruhering 52 pt (Kreis 44 + 8, `MicButton.ringRest`)
  wie im Entwurf und im Code, nicht der 44-pt-Kreis. Nur Text, keine Verhaltensänderung.
