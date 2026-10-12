# Adversary Dialog — fix-274-sprache-latenz
Spec: docs/specs/fix-274-sprache-latenz-messung.md
Datum: 2026-10-09 08:22

## Checkliste
- [x] **AC-1 Startdauer sichtbar:** Given Start ≥ 3,0 s (Summe der fünf Strecken) / When das erste Ergebnis eintrifft / Then steht eine graue Zeile mit Startdauer und den fünf Strecken bis zum Ende der Erfassung. Bei 2,9 s und erstem Ergebnis < 6 s steht keine Zeile.
- [x] **AC-2 Zeit bis zum ersten Text sichtbar:** Given das erste Ergebnis kommt ≥ 6,0 s nach Zuhörbeginn / When es eintrifft / Then wechselt die Wartezeile in den Bericht „Erster Text nach X s · Start: …“ und bleibt bis zum Ende der Erfassung.
- [x] **AC-3 Wartezeile trägt den Start:** Given Fall W (6 s Ton ohne Ergebnis) / Then enthält die Zeile zusätzlich Startdauer und fünf Strecken. Ohne `timings` ist der Text identisch mit dem von heute.
- [x] **AC-4 Gesunder Fall unverändert:** Start < 3 s und erstes Ergebnis < 6 s → nie eine Zeile.
- [x] **AC-5 Schwellen:** `threshold` (6 s) und `slowStart` (3 s) stehen je genau einmal als Konstante; Regel, Prüfschleife und Tests benutzen sie.
- [x] **AC-6 Strecken zusammenhängend:** Die fünf Strecken schließen aneinander an; `start` ist ihre Summe; die Messpunkte liegen wie in der Tabelle beschrieben (Code-Lesen im Review).
- [x] **AC-7 Neustart:** Nach `stop()` und neuem Start beginnen Strecken und `firstResult` neu; ein früherer Bericht bleibt nie stehen (Beleg: Code-Lesen wie AC-5 in Schnitt 1, nicht am Gerät beobachtet).
- [x] **AC-8 Erkennung unverändert:** Keine Änderung an Transcriber, Optionen, Analyzer, Tap, Wandler, Audio-Session, Rechteabfrage; die bestehenden Tests und der UI-Smoke bleiben unverändert grün.
- [x] **AC-9 Aussehen:** Grau (`.secondary`), `.footnote`, keine Farbe, keine Schaltfläche; `CaptureView` unverändert.

## Dialog

### Runde 1
**Adversary:** F001 aus Lauf 1 bleibt weg? Ich lese jeden Pfad, auf dem `openedAt`/`timings` geschrieben, gelesen, gelöscht werden.
- Schreiben: nur `noteOpened()` (SpeechCapture.swift:65), einziger Aufrufer CaptureView.swift:178, im `speechWanted`-Zweig von `begin()` (Aufruf nur über `.onAppear`, Zeile 85; `speech` ist `@State` je Ansicht, Zeile 15, also kein altes openedAt aus früherer Szene).
- Verbrauchen: `start()` liest `openedAt` und setzt es sofort auf nil (SpeechCapture.swift:72-75), bevor irgendein Abbruchzweig kommt. Damit überleben weder Pfad `unavailable`, `needsModel`, `accessDenied`, Ticket-Abbruch noch Fehler in `begin()` ein altes openedAt. `timings = nil` in derselben Stelle.
- Pfade: (a) Szene im Tippmodus: `noteOpened()` wird nicht gerufen (else-Zweig, Zeile 183), Mikrofon später: open = 0. (b) Öffnen, Abbrechen, Öffnen: `cancel()` ruft `stop()` (setzt openedAt, timings nil), und die neue Szene hat eine neue SpeechCapture. (c) `loadModel()` -> `load` -> `start()`: openedAt war vom ersten start() schon verbraucht, open = 0; Download-Zeit steckt in keiner Strecke (LOW, Hinweis). (d) `needsModel`: wie (c). (e) `recognitionFailed`/Fehler in `begin()`: catch ruft `stop()`, löscht beides. (f) Mikrofon stoppen und neu tippen: `stop()` löscht timings, `start()` setzt neu, kein Altbericht (AC-7).
- Aufrufer `speech.start()`: CaptureView.swift:181 (mit noteOpened), :195 (Mikrofon-Taste, ohne -> open 0 wie spec), SpeechCapture.swift load() (ohne -> 0). Kein Aufrufer von noteOpened ohne start im selben Zweig; die Task kann zwischen noteOpened und start nur durch `cancel()` unterbrochen werden, dann löscht stop() openedAt.
- Test: `stopClearsOpenedAt` rot vor dem Fix (test-red-f001.txt:28, `speech.openedAt == nil` verfehlt), grün danach (test-green-output.txt:594). Der Test deckt nur stop(); die Tipp-Zweig-Zeile (CaptureView) hat keinen Test (Hinweis, kein Defekt: die UI-Tests laufen mit speechWanted == false, SpeechCapture-Start ist im Simulator nicht ausführbar).
**Implementierer:** (aus Code belegt) wie oben; keine Gegenrede nötig.

### Runde 2
**Adversary:** Rest aus Lauf 1 und neue Angriffe.
- AC-6: Strecken: open = noteOpened bis t0; modelCheck = t0 bis tModel (nach AssetInventory); rights = tModel bis tRights; analyzer = tRights bis tAnalyzer (marks.since = tRights); microphone = tAnalyzer bis tMicrophone. Lückenlos, `start` = Summe (SpeechDiagnosis.swift `start`). Kein Messpunkt nach einem Wartepunkt vergessen.
- AC-7/Concurrency: `run == self.run` (SpeechCapture.swift collect) bleibt; `timings` und `run += 1` werden ohne await hintereinander gesetzt (MainActor), alte collect-Task kann nach stop() wegen `timings == nil` nichts schreiben und nach neuem Start wegen anderer Kennung ebenfalls nicht. firstResult einmal je Zuhören, gesetzt auch bei leerem Text (Spec).
- Grenzwerte: `hint` Fall B: `start >= slowStart` (3,0 inklusive) oder `firstResult >= threshold` (6,0 inklusive); Tests 3,0/6,0 und knapp darunter vorhanden (Tests 107-123). Ohne timings kein Fall B; Fall W unverändert; Text ohne timings identisch (Test Zeile 160). `firstResult == nil` im Bericht: nur `parts`, kein "nil" (Test Zeile 129).
- AC-5: `threshold` und `slowStart` je einmal (SpeechDiagnosis.swift), Regel und Tests benutzen sie.
- AC-8: git diff gegen merge-base: Transcriber, Optionen, Analyzer, Tap, Wandler, Audio-Session, Rechteabfrage unverändert; nur lokale `let t* = ContinuousClock.now` eingefügt, `begin(...)` bekommt zusätzlich `marks`. Shared/ und TimeExpressionParser sind gegenüber dem merge-base unverändert (die Abweichung gegen origin/main ist nur dessen Fortschritt).
- Lokalisierung: drei neue Schlüssel mit en und de im xcstrings; Dezimalstelle über `.formatted` (Komma/Punkt nach Gerät).
- AC-9: grau/footnote in CaptureView unverändert vorhanden; die Datei hat genau eine Zeile Differenz (Hinweis LOW: Spec-Wortlaut "unverändert" gegen Scope "eine Zeile", Spec gesperrt, kein Defekt).
- Neulauf UI-Smoke: nicht nötig. Die verschobene Zeile liegt im `speechWanted`-Zweig, der unter `--ui-testing` nie läuft (CaptureView.swift:33-35); der Smoke-Lauf bezieht die Zeile also nicht ein, und der Binärstand der Smoke-Pfade ist gleich. Bewusst nicht neu gestartet.
- Offen, nicht lokal beweisbar: AC-10 (TestFlight-Zahlen von Henning, Gerät gesperrt) und AC-11 Speech Stress 10x (CI); beides sind laut Spec nachgelagerte Stufen.
**Implementierer:** keine Gegenrede.

## Confirmations
Confirmation:
  AC: AC-1, AC-4, AC-5
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:42
  Evidence: Fall B bei start >= 3,0 oder firstResult >= 6,0, darunter nil; Konstanten threshold und slowStart je einmal (:23); Zeile bleibt bis stop() (updateDiagnosis jede Sekunde); Unit-Tests 3,0/6,0 und 2,9/5,9 grün.

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:56
  Evidence: Wartetext plus Startteil; ohne timings der alte Text Byte für Byte.

Confirmation:
  AC: AC-2, AC-7
  Code reference: LooseEnds/Speech/SpeechCapture.swift:312
  Evidence: firstResult einmal beim ersten Ergebnis, nur bei run == self.run; stop() (:135) löscht openedAt und timings; start() setzt timings nil; Test stopClearsOpenedAt rot (test-red-f001.txt) dann grün.

Confirmation:
  AC: AC-6, AC-8
  Code reference: LooseEnds/Speech/SpeechCapture.swift:108
  Evidence: Messpunkte lückenlos, Summe in start; Transcriber, Optionen, Analyzer, Tap, Wandler, Audio-Session, Rechteabfrage laut Diff gegen den Merge-Base unverändert (:216).

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Views/CaptureView.swift:178
  Evidence: einzige Änderung ist der Meldeaufruf im speechWanted-Zweig; Aussehen unverändert; UI-Smoke grün, Screenshot angesehen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Verdachtsfeld `openedAt` (einzige Schreibstelle `noteOpened()`, SpeechCapture.swift:65). Bedingung davor: wird nur gesetzt, wenn die Erfassung im Sprachmodus erscheint (CaptureView.swift:178, `speechWanted`), und direkt von start() verbraucht oder von stop() gelöscht. Test für diesen Weg: `stopClearsOpenedAt` (SpeechDiagnosisTests.swift:170) für das Löschen; für den Aufruf im Sprachzweig keiner (nicht im Simulator auslösbar, Hinweis LOW).

## Verdict

VERDICT: VERIFIED
F001 behoben auf allen Pfaden (Tippmodus, Abbruch/Neuöffnen, loadModel -> start, needsModel, Fehler -> stop). Keine neuen Defekte.
Hinweise (LOW, kein Defekt): AC-9 Spec-Wortlaut "CaptureView unverändert" gegen eine Zeile; Download-Zeit nach loadModel() steckt in keiner Strecke; erster Start schließt das Rechte-Dialogfenster in "Öffnen" oder "Rechte" ein; Aufruf von noteOpened im Sprachzweig ohne Test.
Tests: Unit voll grün (test-green-output.txt, Exit 0, 1 Messstrecke übersprungen, nicht gemessen); UI-Smoke 2 bestanden (adversary-test-output.txt, Neulauf unnötig); 0 fehlgeschlagen.
Offen laut Spec, nicht hier prüfbar: AC-10 (Gerät, TestFlight, Henning) und AC-11 Speech Stress (CI).

## Geprüfte Dateien

- sha256:99a04148000cc4237662c7a994f95544d350eabe8f344e34da4bb4c8c9d8415a  LooseEnds/Speech/SpeechCapture.swift
- sha256:47b77c27ae622d5709e613412915c125556cc25e07a5491c41f841cea3da3153  LooseEnds/Speech/SpeechDiagnosis.swift
- sha256:2682a6a49a9eda00e8616dd39daac8485a5f9d1cb652bfb7203349eca3366d73  LooseEnds/Views/CaptureView.swift

## Prüfbasis

- base: 2216d317c48e66594e47089e32a4e5125cade705
- blob:85f7a95d793cfaed073d22f7cd984b6b8f91d3b9  LooseEnds/Speech/SpeechCapture.swift
- blob:78dca523430f29d76593e2e4b93d6161d9ddec9b  LooseEnds/Speech/SpeechDiagnosis.swift
- blob:5372d4b07bdd0968406879754e86eb843de0e095  LooseEnds/Views/CaptureView.swift

## Geprüfte Dateien

- sha256:99a04148000cc4237662c7a994f95544d350eabe8f344e34da4bb4c8c9d8415a  LooseEnds/Speech/SpeechCapture.swift
- sha256:47b77c27ae622d5709e613412915c125556cc25e07a5491c41f841cea3da3153  LooseEnds/Speech/SpeechDiagnosis.swift
- sha256:2682a6a49a9eda00e8616dd39daac8485a5f9d1cb652bfb7203349eca3366d73  LooseEnds/Views/CaptureView.swift

## Prüfbasis

- base: 2216d317c48e66594e47089e32a4e5125cade705
- blob:85f7a95d793cfaed073d22f7cd984b6b8f91d3b9  LooseEnds/Speech/SpeechCapture.swift
- blob:78dca523430f29d76593e2e4b93d6161d9ddec9b  LooseEnds/Speech/SpeechDiagnosis.swift
- blob:5372d4b07bdd0968406879754e86eb843de0e095  LooseEnds/Views/CaptureView.swift
