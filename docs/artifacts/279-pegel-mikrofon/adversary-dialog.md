# Adversary Dialog — 279-pegel-mikrofon
Spec: docs/specs/fix-279-hoert-zu-anzeige.md
Datum: 2026-10-10 10:55

## Checkliste
- AC-1 (Runde 2: siehe Runde 4) Skala: level(of:) in dBFS, -50 -> 0, -30 -> 0,5, -10 -> 1, Stille/leer -> 0 (Unit-Tests gruen, NaN -> 0, Inf -> 1)
- AC-2 (Runde 2: siehe Runde 4) Sprachhoehe: nur am Geraet (Stufe 3) belegbar, nicht im Simulator, nicht bewiesen
- AC-3 (Runde 2: siehe Runde 4) Grundlinie: Linie wird vor den Balken ueber volle Breite gezeichnet, Balken Akzent/grau (Code + Screenshot hell/dunkel)
- AC-4 (Runde 2: siehe Runde 4) Hinweis: "Listening ..." grau an Platzhalterstelle, Punkte nacheinander (Code, UI-Test, Screenshot); Punkt-Animation selbst nicht automatisiert belegt
- AC-5 (Runde 2: siehe Runde 4) Ersetzen: nicht-leerer Text -> .none (Unit-Tests, UI-Test testHintIsReplacedByTypedText); nicht zuhoeren + leer -> Platzhalter
- AC-6 (Runde 2: siehe Runde 4) Sofort: im Code ohne Verzoegerung (Regel haengt nur an isListening), der echte Pfad (speech.isListening) ist im Simulator nicht durchlaufen, nur der Festzustand; nicht bewiesen
- AC-7 (Runde 2: siehe Runde 4) Knopf: gefuellter Akzentkreis, mic.fill, Ring .smooth, mic.slash grau, Labels und micButton, 56 pt Flaeche (Code + Screenshot)
- AC-8 (Runde 2: siehe Runde 4) Reduce Motion: im Code belegt (lit nil, Ring fest 50, animation nil), aber kein Lauf mit Bewegung reduzieren; Geraet offen
- AC-9 (Runde 2: siehe Runde 4) Farbbudget: Akzent nur Knopf, Ring, Balken beim Zuhoeren; Hinweis .secondary; kein Rot/Gruen
- AC-10 (Runde 2: siehe Runde 4) Erkennung unveraendert: git diff beruehrt SpeechCapture.swift nicht, nur Waveform.level(of:) wird vom Tap aufgerufen
- AC-11 (Runde 2: siehe Runde 4) Festzustand: UI-Test gruen (Hinweis, "Stop listening", ohne Argument kein Hinweis), toggleListening im Festzustand gesperrt
- AC-12 (Runde 2: siehe Runde 4) Regression: Unit, Simulator-UI und Mac-Build gruen; UI-Smoke komplett und Speech Stress (CI) nicht gelaufen, nicht bewiesen

## Dialog

### Runde 1
Adversary: Tests selbst ausgefuehrt. sim-unit: 509 Haken, 0 Fehler (Waveform- und Listening-hint-Suites gruen). SpeechListeningIndicatorTests: 3 Tests, 0 Failures. mac-build: Build Succeeded (geteilte View kompiliert auch auf macOS, accessibilityVoiceOverEnabled ok).
Screenshots green-hell.png / green-dunkel.png geoeffnet: Oben graues "Listening ..." an Platzhalterstelle (Punkte gedimmt), darunter Wellenform in Akzent (Teal, dunkel heller) mit grauer Linie sichtbar an den Raendern, rechts gefuellter Akzentkreis mit weissem mic.fill und Ring. Kein Rot/Gruen.
Edge Cases: NaN-Probe -> rms NaN, guard rms > 0 false -> 0. Inf -> 1. Leere Probe -> 0. Unter -50 -> 0 (clamp).
Code reference: LooseEnds/Speech/Waveform.swift:24
Code reference: LooseEnds/Speech/ListeningHint.swift:5
Code reference: LooseEnds/Views/CaptureView.swift:251
Implementierer: n/a (isolierte Pruefung).

### Runde 2
Adversary: Bohren nach.
- Hinweis blockiert Tippen: Overlay hat allowsHitTesting(false); UI-Test tippt und schreibt "Milch", Hinweis verschwindet. OK.
- VoiceOver-Name: Feld behaelt Titel "What should I remember?", Hinweis ist bei VoiceOver ausgeblendet. OK (nur im Code, nicht mit VoiceOver gelaufen).
- Zuhoeren endet mit Text im Feld: Regel liefert .none, Text bleibt. OK.
- Fixture vs. echter Pfad: Fixture setzt isListening/levels direkt (CaptureView.swift:52). Der echte Pfad speech.isListening -> hintState ist derselbe Ausdruck, aber im Simulator nicht belegt (kein Mikrofon). Finding F001.
- Ring im Festzustand: letzter Fixture-Pegel 0,5 -> feste Groesse, Wachstum mit Pegelbewegung im Simulator nicht sichtbar. Finding F002.
- Punkte-Animation: TimelineView, kein Test prueft Reduce Motion. Finding F003.
- Swift 6: Views auf MainActor, keine neue Closure auf Audio-Strang; Mac-Build gruen.
- Messberichte: docs/reference/retrieval-leave-one-out-rules.md vom Unit-Lauf veraendert und zurueckgesetzt.

Findings:
Finding F001: Severity MEDIUM, Category edge_case. Code reference: LooseEnds/Views/CaptureView.swift:52. Description: isListening/levels werden im Festzustand direkt gesetzt, der echte Pfad (speech.isListening, speech.waveform) ist im Simulator nicht durchlaufen. Spec requirement: AC-6. Conflict: "ohne Verzoegerung ab Beginn des Zuhoerens" nur per Codelesen belegt. Remediation: Beleg am Geraet (Stufe 3, nur nach Hennings Wort).
Finding F002: Severity LOW, Category edge_case. Code reference: LooseEnds/Views/CaptureView.swift:307. Description: Ringgroesse 46 + level*10 pt; Wachstum mit Pegel im Festzustand nicht belegt, Ring ist auch bei Pegel 0 sichtbar. Spec requirement: AC-7. Conflict: Verhalten nur am Geraet pruefbar. Remediation: Geraetebeleg.
Finding F003: Severity LOW, Category edge_case. Code reference: LooseEnds/Views/CaptureView.swift:280. Description: Reduce-Motion-Zweig (lit nil, Ring 50, animation nil) ist durch keinen Test abgedeckt. Spec requirement: AC-8. Conflict: Nur Codelesen. Remediation: Geraet/Simulator mit Bewegung reduzieren pruefen.
Finding F004: Severity LOW, Category anti_pattern. Code reference: LooseEnds/Views/CaptureView.swift:73. Description: Hinweis ist Overlay mit leerem prompt; bei Whitespace-Text liegt er ueber den Leerzeichen. Spec requirement: AC-5. Conflict: kosmetisch, Spec nennt Whitespace als leer. Remediation: keine noetig.

Geraeteliste: LooseEnds/Speech/ beruehrt, Stufe 3 offen (nicht angefasst, kein Geraetezugriff).


## Verdict Runde 2 (überholt)
Nicht bewiesen: AC-2, AC-6, AC-8, AC-12 (CI/Speech Stress). Keine Spec-Verletzung gefunden; die offenen Punkte sind nur am Geraet bzw. in CI belegbar.
Tests: 509 Unit-Haken gruen, 3 UI-Tests gruen, Mac-Build gruen, 0 failed, 0 uebersprungen

Urteil Runde 2 (überholt): AMBIGUOUS

### Runde 3
Adversary: Nachbesserung (ungesicherter Diff: Waveform.swift, CaptureView.swift, WaveformTests.swift) gelesen, Tests selbst gefahren.
- sim-unit (adv2_unit.txt): Test Succeeded, 511 Haken, 0 Fehler; Suite "Waveform" gruen inkl. testRingScale. 1 von 5 Messstrecken uebersprungen (SelfConsistencyReport, Korpusdatei fehlt, nicht gemessen). Messberichte focusblox-calibration-report.md und retrieval-leave-one-out-rules.md per git checkout zurueckgesetzt.
- SpeechListeningIndicatorTests (adv2_ui.txt): 3 Tests, 0 Failures.
- Screenshots green2-hell.png / green2-dunkel.png geoeffnet: oben graues "Listening ..." (Punkte gedimmt), Wellenform mit grauer Grundlinie in Akzent (hell Teal, dunkel Tuerkis), rechts gefuellter Akzentkreis mit weissem mic.fill und Ring (Pegel 0,5 -> x1,175 = 61 pt) mit sichtbarem Abstand zum Kreis, vollstaendig sichtbar, nicht abgeschnitten, kein Rot/Gruen.
- Bohren ringScale: NaN am Eingang ergaebe NaN (Swift min/max geben NaN weiter), ist aber ueber level(of:) nicht erreichbar: NaN-rms scheitert an guard rms > 0 -> 0, Inf wird auf 1 geklemmt. Nur unerreichbar, kein Test dafuer (F005, LOW).
- Ring bei Pegel 0: Durchmesser 52, Strich 3 -> Innenkante r=24,5 gegenueber Kreis r=22, also 2,5 pt Luft; im Screenshot sichtbar getrennt (bei 0,5). Bei 0 nur gerechnet.
- Rahmen 74 pt: groesster Ring 52*1,35 = 70,2 + 3 pt Strich = 73,2 <= 74, Tippflaeche 74 >= 44. Aber: der Rahmen ist auch bei mic.slash 74 pt, die Zeile wird um 18 pt hoeher als vorher (56) -- gewollt wegen Ring, kein Test.
- Layout schmal: 320-pt-iPhone -> Balkenbreite ca. 202 pt, Slot ca. 5 pt (40 Balken); Mac minWidth 440 -> ca. 300 pt. Nur gerechnet, kein Lauf auf iPad/Mac/schmal (F006, LOW).
- Animation bei leerem levels: levels.last ?? 0 -> Pegel 0, Ring ruht bei 52, keine Animation noetig. OK.
- Spec-Abweichung Ruhering: Spec-Formel "Kreis x (1+0,35 Pegel)" ergaebe 44..59,4; Umsetzung folgt dem freigegebenen Entwurf (inset -4 px -> 52..70,2). Die Spec nennt "wie im Entwurf" und der Entwurf ist massgeblich, die Formelzeile ist ungenau. Wertung: vertretbar, aber Spec-Text bleibt widerspruechlich (F007, MEDIUM, Spec nachziehen).
- Ring-Wachstum im Test: kein Test prueft ringDiameter oder die Ringgroesse im UI (nur die Formel ringScale). Bewegung mit echtem Pegel im Simulator nicht gezeigt (F002 bleibt).

### Runde 4
Adversary: Punkt fuer Punkt mit Beweis. Teilevidenz PO-Foto aus Build 23 zeigt im echten Pfad Text und Balken (alte Skala), nicht die neue Skala und nicht den neuen Ring.
- [x] AC-1 Skala -55/-40/-25 -> 0/0,5/1, Stille/leer -> 0. Code reference: LooseEnds/Speech/Waveform.swift:19 (Konstanten), :29 (level), Tests Waveform gruen.
- [ ] AC-2 Sprachhoehe am iPhone: nur Teilevidenz (Foto Build 23, -40 dBFS ausgemessen, Einzelmessung); Wirkung der neuen Skala am Geraet nicht belegt. Code reference: LooseEnds/Speech/Waveform.swift:19
- [x] AC-3 Grundlinie und Balkenfarbe unveraendert, Screenshot hell/dunkel zeigt Linie und Akzentbalken. Code reference: LooseEnds/Views/CaptureView.swift:251
- [x] AC-4 Hinweis "Listening ..." grau an Platzhalterstelle (Screenshots, UI-Test gruen). Code reference: LooseEnds/Views/CaptureView.swift:73
- [x] AC-5 Ersetzen durch Text: Unit- und UI-Test gruen (testHintIsReplacedByTypedText). Code reference: LooseEnds/Speech/ListeningHint.swift:5
- [ ] AC-6 Hinweis im echten Pfad sofort: Foto Build 23 zeigt Text im echten Pfad, ob der Hinweis sofort erscheint, ist nicht belegt; Simulator nur Festzustand. Code reference: LooseEnds/Views/CaptureView.swift:57
- [x] AC-7 Ring waechst mit Pegel: ringDiameter = 52 x ringScale (52..70,2), Rahmen 74 pt, Strich passt (73,2), Tippflaeche >= 44, Kreis und Symbol ruhig, Screenshot Ring unbeschnitten. Einschraenkung: Wachstum im Lauf nicht gezeigt, nur Formel getestet. Code reference: LooseEnds/Views/CaptureView.swift:313
- [x] AC-8 Reduce Motion: Ring fest x1,15 = 59,8 pt, animation nil (Code, kein Lauf mit Bewegung reduzieren; F003 bleibt als LOW, im Code eindeutig). Code reference: LooseEnds/Views/CaptureView.swift:322
- [x] AC-9 Farbbudget: Ring Akzent 0,35, Hinweis grau, kein Rot/Gruen (Screenshots). Code reference: LooseEnds/Views/CaptureView.swift:321
- [x] AC-10 Erkennung unveraendert: Diff beruehrt SpeechCapture.swift nicht, nur Konstanten und ringScale. Code reference: LooseEnds/Speech/Waveform.swift:25
- [x] AC-11 Festzustand: UI-Test 3/3 gruen, Fixture-Pegel 0,5. Code reference: LooseEnds/Views/CaptureView.swift:50
- [ ] AC-12 Regression: Unit 511 gruen, UI 3/3 gruen, Mac-Build nicht neu gefahren (optional, Runde 1 gruen vor der Nachbesserung); UI-Smoke komplett und Speech Stress (CI) nicht gelaufen. Code reference: LooseEndsTests/WaveformTests.swift:47
- Coverage Dateien: LooseEnds/Speech/ListeningHint.swift:5, LooseEnds/Speech/Waveform.swift:25, LooseEnds/Views/CaptureView.swift:313, LooseEndsTests/WaveformTests.swift:47

Findings (Nachbesserung):
Finding F005: Severity LOW, Category edge_case. Code reference: LooseEnds/Speech/Waveform.swift:25. Description: ringScale(for:) reicht NaN durch (min/max). Spec requirement: AC-7. Conflict: ueber level(of:) unerreichbar, kein Test. Remediation: optional NaN -> 0 oder Test.
Finding F006: Severity LOW, Category edge_case. Code reference: LooseEnds/Views/CaptureView.swift:177. Description: 74-pt-Knopf auf schmalem iPhone, iPad, Mac nur gerechnet, nicht gelaufen; Zeile 18 pt hoeher, auch bei mic.slash. Spec requirement: AC-7. Conflict: keine. Remediation: Screenshot schmales Geraet.
Finding F007: Severity MEDIUM, Category spec_violation. Code reference: LooseEnds/Views/CaptureView.swift:309. Description: Ruhering 52 pt (Entwurf) statt 44 pt (Spec-Formel "Kreis x (1+0,35 Pegel)"). Spec requirement: AC-7 / Abschnitt Runder Knopf. Conflict: Spec-Text und Umsetzung weichen ab, Entwurf ist freigegeben und gibt die Umsetzung gedeckt. Remediation: Spec-Formel auf "Ruhering (Kreis + 8 pt) x (1 + 0,35 Pegel)" aendern (Spec-Nachbesserung braucht override).
Finding F008: Severity MEDIUM, Category edge_case. Code reference: LooseEnds/Speech/Waveform.swift:19. Description: Skala stuetzt sich auf eine Messung am Foto (ein Raum, ein Abstand); ob der Ring am iPhone sichtbar pulsiert, ist offen. Spec requirement: AC-2. Conflict: nicht am Geraet belegt. Remediation: PO prueft in TestFlight.

## Herkunft der Vorbedingungen
kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
Nicht belegt: AC-2, AC-6 (Geraet/TestFlight, PO), AC-12 (CI-Smoke, Speech Stress, Mac-Build nicht neu). Keine Regression gefunden; F007 ist eine Spec-Formel-Ungenauigkeit.
Tests: 511 Unit-Haken gruen, 3 UI-Tests gruen, 0 failed, 1 von 5 Messstrecken uebersprungen

VERDICT: AMBIGUOUS

## Geprüfte Dateien

- sha256:49bdc8afe5f6e4951d862be64480f72f4fbff53d360565ce4b87f4a6dd3e1370  LooseEnds/Speech/ListeningHint.swift
- sha256:c64c7b9b61ed6c924bb55258d9473242186b7f48d27bf363f62e3df065681f2b  LooseEnds/Speech/Waveform.swift
- sha256:615dfb0e5bf90b1b9c7be4ded52c722c99cc0d59961ab792e1b64b1ac7f0a52f  LooseEnds/Views/CaptureView.swift

## Prüfbasis

- base: b7220d1364eca3bc4249825a0d7936f4c21d2c92
- blob:9be0033c30a0e872eddfe8c1ba94412f71e41fe7  LooseEnds/Speech/ListeningHint.swift
- blob:624851b501f0254a4b60eadaf3715bf008f8e4c0  LooseEnds/Speech/Waveform.swift
- blob:f7391060c36b991d238c50990425e246755ed92b  LooseEnds/Views/CaptureView.swift
