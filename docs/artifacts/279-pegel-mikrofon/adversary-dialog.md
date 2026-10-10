# Adversary Dialog — 279-pegel-mikrofon
Spec: docs/specs/fix-279-hoert-zu-anzeige.md
Datum: 2026-10-10 10:55

## Checkliste
- [x] AC-1 Skala: level(of:) in dBFS, -50 -> 0, -30 -> 0,5, -10 -> 1, Stille/leer -> 0 (Unit-Tests gruen, NaN -> 0, Inf -> 1)
- [ ] AC-2 Sprachhoehe: nur am Geraet (Stufe 3) belegbar, nicht im Simulator, nicht bewiesen
- [x] AC-3 Grundlinie: Linie wird vor den Balken ueber volle Breite gezeichnet, Balken Akzent/grau (Code + Screenshot hell/dunkel)
- [x] AC-4 Hinweis: "Listening ..." grau an Platzhalterstelle, Punkte nacheinander (Code, UI-Test, Screenshot); Punkt-Animation selbst nicht automatisiert belegt
- [x] AC-5 Ersetzen: nicht-leerer Text -> .none (Unit-Tests, UI-Test testHintIsReplacedByTypedText); nicht zuhoeren + leer -> Platzhalter
- [ ] AC-6 Sofort: im Code ohne Verzoegerung (Regel haengt nur an isListening), der echte Pfad (speech.isListening) ist im Simulator nicht durchlaufen, nur der Festzustand; nicht bewiesen
- [x] AC-7 Knopf: gefuellter Akzentkreis, mic.fill, Ring .smooth, mic.slash grau, Labels und micButton, 56 pt Flaeche (Code + Screenshot)
- [ ] AC-8 Reduce Motion: im Code belegt (lit nil, Ring fest 50, animation nil), aber kein Lauf mit Bewegung reduzieren; Geraet offen
- [x] AC-9 Farbbudget: Akzent nur Knopf, Ring, Balken beim Zuhoeren; Hinweis .secondary; kein Rot/Gruen
- [x] AC-10 Erkennung unveraendert: git diff beruehrt SpeechCapture.swift nicht, nur Waveform.level(of:) wird vom Tap aufgerufen
- [x] AC-11 Festzustand: UI-Test gruen (Hinweis, "Stop listening", ohne Argument kein Hinweis), toggleListening im Festzustand gesperrt
- [ ] AC-12 Regression: Unit, Simulator-UI und Mac-Build gruen; UI-Smoke komplett und Speech Stress (CI) nicht gelaufen, nicht bewiesen

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

## Herkunft der Vorbedingungen
kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
Nicht bewiesen: AC-2, AC-6, AC-8, AC-12 (CI/Speech Stress). Keine Spec-Verletzung gefunden; die offenen Punkte sind nur am Geraet bzw. in CI belegbar.
Tests: 509 Unit-Haken gruen, 3 UI-Tests gruen, Mac-Build gruen, 0 failed, 0 uebersprungen

VERDICT: AMBIGUOUS

## Geprüfte Dateien

- sha256:49bdc8afe5f6e4951d862be64480f72f4fbff53d360565ce4b87f4a6dd3e1370  LooseEnds/Speech/ListeningHint.swift
- sha256:5358ec291bd85dce9f5be56aedc16757bf019beca2c5fef5cab338375cf4e995  LooseEnds/Speech/Waveform.swift
- sha256:8cf133798f950b21337582b028840d77e7082e784db93b8ec43b2bde64c64f0a  LooseEnds/Views/CaptureView.swift

## Prüfbasis

- base: 5037f0ee63f82d1803090c66ee78064768f75852
- blob:9be0033c30a0e872eddfe8c1ba94412f71e41fe7  LooseEnds/Speech/ListeningHint.swift
- blob:f08c3974a706bafe7c06a432b8b7b682b9342ad9  LooseEnds/Speech/Waveform.swift
- blob:1baa8e762d2d574b40703c6a45a69ac307966455  LooseEnds/Views/CaptureView.swift
