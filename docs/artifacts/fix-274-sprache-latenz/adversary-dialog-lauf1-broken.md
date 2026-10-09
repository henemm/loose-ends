# Adversary Dialog — fix-274-sprache-latenz
Spec: docs/specs/fix-274-sprache-latenz-messung.md
Datum: 2026-10-09 07:55

## Checkliste
- [x] **AC-1 Startdauer sichtbar:** Given Start ≥ 3,0 s (Summe der fünf Strecken) / When das erste Ergebnis eintrifft / Then steht eine graue Zeile mit Startdauer und den fünf Strecken bis zum Ende der Erfassung. Bei 2,9 s und erstem Ergebnis < 6 s steht keine Zeile.
- [x] **AC-2 Zeit bis zum ersten Text sichtbar:** Given das erste Ergebnis kommt ≥ 6,0 s nach Zuhörbeginn / When es eintrifft / Then wechselt die Wartezeile in den Bericht „Erster Text nach X s · Start: …“ und bleibt bis zum Ende der Erfassung.
- [x] **AC-3 Wartezeile trägt den Start:** Given Fall W (6 s Ton ohne Ergebnis) / Then enthält die Zeile zusätzlich Startdauer und fünf Strecken. Ohne `timings` ist der Text identisch mit dem von heute.
- [x] **AC-4 Gesunder Fall unverändert:** Start < 3 s und erstes Ergebnis < 6 s → nie eine Zeile.
- [x] **AC-5 Schwellen:** `threshold` (6 s) und `slowStart` (3 s) stehen je genau einmal als Konstante; Regel, Prüfschleife und Tests benutzen sie.
- [ ] **AC-6 Strecken zusammenhängend:** Die fünf Strecken schließen aneinander an; `start` ist ihre Summe; die Messpunkte liegen wie in der Tabelle beschrieben (Code-Lesen im Review).
- [ ] **AC-7 Neustart:** Nach `stop()` und neuem Start beginnen Strecken und `firstResult` neu; ein früherer Bericht bleibt nie stehen (Beleg: Code-Lesen wie AC-5 in Schnitt 1, nicht am Gerät beobachtet).
- [x] **AC-8 Erkennung unverändert:** Keine Änderung an Transcriber, Optionen, Analyzer, Tap, Wandler, Audio-Session, Rechteabfrage; die bestehenden Tests und der UI-Smoke bleiben unverändert grün.
- [x] **AC-9 Aussehen:** Grau (`.secondary`), `.footnote`, keine Farbe, keine Schaltfläche; `CaptureView` unverändert.
- [ ] **AC-10 Gerät:** Henning sendet aus der neuen TestFlight-Fassung (iPhone, wenn möglich auch iPad) die Zeile mit den Zahlen. Daraus wird im Ticket festgehalten, **welche** Strecke (Start: welche der fünf; oder erstes Ergebnis) die Zeit trägt. Das Ticket bleibt offen; der Fix ist Schnitt 2.
- [ ] **AC-11 Regression:** Unit, Build, UI-Smoke grün; Speech Stress (10×, weil `LooseEnds/Speech/**` berührt) grün.

## Dialog

### Runde 1
**Adversary:**
Beweisforderungen und Angriffe:
1. AC-6: Stehen die Messpunkte exakt wie in der Tabelle? Forderung: Code-Stellen. Außerdem: Was ist `open` in Pfaden, in denen `noteOpened()` ruft, aber `start()` nicht sofort folgt?
2. AC-7: Setzen `stop()` und jeder Start ALLES zurück, was in die Strecken eingeht (nicht nur `timings`)? Greift `run == self.run` für `firstResult` auch zwischen `stop()` und neuem `begin()`?
3. Swift 6: Hat der Audio-Strang eine neue MainActor-Bindung?
4. Grenzwerte 3,0 / 6,0 inklusive; Text ohne "nil".
5. AC-8: Berührt der Diff Transcriber/Optionen/Analyzer/Tap/Wandler/Session/Rechteabfrage?
6. AC-9: Spec sagt "CaptureView unverändert", der Diff hat eine Zeile.
7. Pfad Start nach Modellladen / Mikrofontaste: `open` = 0?
8. Lokalisierung, Platzhalter. 9. Können Zeiten negativ werden?

**Implementierer:** (Antworten vom Adversary aus Code und Läufen belegt)
1. Messpunkte: t0 hinter dem `isListening`-Guard (LooseEnds/Speech/SpeechCapture.swift:72), `tModel` direkt nach `AssetInventory.status` (:81), `tRights` nach beiden Rechteabfragen (:97), `tAnalyzer` direkt nach `analyzer.start` (:230), `tMicrophone` direkt nach `engine.start()` (:261). Strecken sind Differenzen aufeinanderfolgender Marken (modelCheck = tModel-t0, rights = tRights-tModel, analyzer = tAnalyzer-tRights via `marks.since`, microphone = tMicrophone-tAnalyzer), `open` = t0-openedAt. Summe = `SpeechTimings.start` (SpeechDiagnosis.swift:15). Lückenlos bis auf `open`, siehe Punkt 7.
2. `timings` wird in stop() (SpeechCapture.swift:135) und am Start (:76) auf nil gesetzt; `firstResult` lebt in `timings`, wird also mit zurückgesetzt. `collect` schreibt nur bei `run == self.run` (:307) und nur, wenn `timings` nicht nil ist; zwischen stop() und neuem begin() ist `timings` nil, ein spätes Ergebnis eines Altlaufs schreibt ins Leere. `run` wird erst in begin() hochgezählt, nach dem Setzen von `timings` und `listeningSince`. ABER: `openedAt` wird von stop() NICHT zurückgesetzt und nur in start() verbraucht (:73-74).
3. `seconds` ist `nonisolated static` (:221); die einzigen MainActor-Tasks (:252, :255) waren schon da. `StartMarks` ist ein privates Wert-Struct nur auf dem Hauptakteur. Keine neue Bindung.
4. `hint`: `waiting` (>= threshold) und `isSlow` (`start >= slowStart || firstResult >= threshold`, SpeechDiagnosis.swift:51-53). Tests "exactly 3 s", "exactly 6 s" grün (test-green-output.txt, Suite "Speech diagnosis (#274)", 19 Tests). Text: `firstResult == nil` gibt nur den Startteil (:62), kein "nil".
5. Der Diff zeigt nur zusätzliche Marken/Zeilen; Transcriber (`Self.transcriber()`), Optionen, `AnalyzerInputConverter`, installTap, Session-Aufrufe, `requestRecordPermission`/`requestSpeechAuthorization` stehen unverändert im Kontext.
6. CaptureView.swift:177 `speech.noteOpened()` ist die einzige Änderung. Spec nennt sie in Source/Affected Files/Tabelle ausdrücklich als Eine-Zeile-Änderung; AC-9 "CaptureView unverändert" meint Aussehen. Defekt der Spec-Formulierung (LOW), nicht des Codes.
7. Start nach Modellladen: der erste start() hat openedAt verbraucht, der zweite sieht nil, open = 0, wie spec'd (:73). Der Mikrofon-Tipp im Tippmodus: siehe Runde 2.
8. Schlüssel gültig, DE/EN vorhanden, gleiche Platzhalterzahl und -reihenfolge (6 x %@ bzw. 1 x %@), Join-Schlüssel vorhanden.
9. `ContinuousClock` ist monoton, Differenzen >= 0. Nicht negativ. Unsinnig groß aber möglich (siehe F001).

### Runde 2
**Adversary:**
Nachprüfung Punkt 7 und 2: `begin()` in CaptureView ruft `speech.noteOpened()` bedingungslos (CaptureView.swift:177), aber `speech.start()` nur wenn `speechWanted` (:178-184); sonst `isFocused = true` (Tippmodus). `toggleListening()` (:191-195) ruft später `speech.start()` ohne `noteOpened()`. `openedAt` bleibt dann bis zum Tipp stehen: `open = t0 - openedAt` = Sekunden, die der Nutzer getippt hat (beliebig groß). Folge: `start >= 3` -> Fall B erzeugt beim ersten Ergebnis einen falschen Bericht "Öffnen 42,0 ..." und verfälscht genau die Messung, die Henning absendet. Auch stop() leert `openedAt` nicht (SpeechCapture.swift:122-145). Das widerspricht der Spec-Aussage "Ohne noteOpened() ... 0" und AC-7 "stop() und jeder Start setzen zurück" für die Zeitbasis.
**Implementierer:** (aus Code belegt) Keine Gegenmaßnahme im Code: `openedAt` wird nur in noteOpened() gesetzt, in start() verbraucht, nie in stop() gelöscht. Unit-Tests decken SpeechCapture nicht ab (kein Test triggert diesen Pfad, siehe Herkunft). Antwort entkräftet nicht: Defekt bestätigt.
**Adversary (Bewertung):** F001 gilt. Übrige Punkte (Grenzwerte, Concurrency, AC-8, Lokalisierung, Textform) belegt. AC-9-Widerspruch ist Spec-Wortwahl (F002 LOW). Stufe 3 (AC-10) und Speech Stress (AC-11) noch nicht erbracht, daher offen. Unit 501 grün, UI-Smoke SpeechDiagnosisLineTests grün (adversary-test-output.txt), Screenshot zeigt unveränderte Zeile; Simulator belegt Messstrecken nicht (sagt die Spec selbst).

### Findings
Finding:
  ID: F001
  Severity: HIGH
  Category: edge_case
  Code reference: LooseEnds/Views/CaptureView.swift:177
  Description: `noteOpened()` wird bedingungslos in `begin()` gerufen, auch im Tippmodus (kein `start()`); `openedAt` bleibt stehen (LooseEnds/Speech/SpeechCapture.swift:73-74 verbraucht nur in start(), stop() :122 leert nicht). Der spätere Mikrofon-Tipp (CaptureView.swift:195) nimmt die Tippzeit als `open`.
  Spec requirement: AC-6/AC-7 — Strecken zusammenhängend und Neustart beginnt neu; Implementation Details: ohne noteOpened() ist open 0
  Conflict: `open` und damit `start` werden beliebig groß; falscher Fall-B-Bericht und verfälschte Messung für Schnitt 2.
  Remediation: `noteOpened()` nur rufen, wenn `speechWanted`, und/oder `openedAt = nil` in `stop()`; Test ergänzen (Zeitbasis als Parameter).

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEnds/Views/CaptureView.swift:177
  Description: Eine Zeile ergänzt; AC-9 sagt "CaptureView unverändert", Source/Scope nennen die Eine-Zeile-Änderung.
  Spec requirement: AC-9
  Conflict: Interner Widerspruch der Spec, Code folgt dem Scope-Abschnitt.
  Remediation: AC-9 umformulieren ("Aussehen und Ablauf von CaptureView unverändert").

### Confirmations
Confirmation:
  AC: AC-1, AC-2, AC-4, AC-5
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:42
  Evidence: `hint` mit `waiting`/`report`, `isSlow` (>= slowStart, >= threshold), Konstanten je einmal (:12, :14); Unit-Tests grün inkl. 3,0/6,0 und 2,9/5,9.

Confirmation:
  AC: AC-3, AC-8
  Code reference: LooseEnds/Speech/SpeechCapture.swift:94
  Evidence: nur Marken und Zähler ergänzt; Erkennungsaufrufe unverändert; Text ohne timings = `waitingText` unverändert, UI-Smoke grün.

Confirmation:
  AC: AC-9
  Code reference: LooseEnds/Views/CaptureView.swift:177
  Evidence: Darstellung unverändert, nur Meldeaufruf (Wortlaut-Widerspruch siehe F002).

Confirmation:
  AC: AC-6 (Messpunkte), AC-7 (timings/firstResult)
  Code reference: LooseEnds/Speech/SpeechCapture.swift:262
  Evidence: Marken exakt an den Tabellenpunkten; timings/firstResult in stop() und start() zurückgesetzt; Vorbehalt F001 für `openedAt`, daher AC-6/AC-7 nicht abgehakt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Verdachtsfeld `openedAt` (einzige Schreibstelle `noteOpened()`, SpeechCapture.swift:65). Bedingung davor: wird bei jedem Öffnen der Erfassung geschrieben, auch im Tippmodus ohne start(). Test für diesen Weg: keiner (Finding F001).

## Verdict

VERDICT: BROKEN
Finding F001 (HIGH): openedAt bleibt im Tippmodus stehen, Mikrofon-Tipp später misst die Tippzeit als Öffnen -> falscher Bericht. Reproduktion: Erfassung im Tippmodus öffnen, 20 s warten, Mikrofon tippen, sprechen; open ~ 20 s.
Tests: 501 Unit bestanden, 0 fehlgeschlagen, 1 Messstrecke übersprungen; UI-Smoke 2 bestanden. AC-10 und AC-11 (Speech Stress) offen.

## Geprüfte Dateien

- sha256:723ce435c83edcc8936719a6bd5027fb6152ca19a3a57b79a68942f518986d1f  LooseEnds/Speech/SpeechCapture.swift
- sha256:47b77c27ae622d5709e613412915c125556cc25e07a5491c41f841cea3da3153  LooseEnds/Speech/SpeechDiagnosis.swift
- sha256:b458bfa81b65b5ddce042dc6af281a966e1f580094014c3c93c04c00471d2123  LooseEnds/Views/CaptureView.swift

## Prüfbasis

- base: 2216d317c48e66594e47089e32a4e5125cade705
- blob:d7e581bc1b78635ece2b438fe591df89e3e389b2  LooseEnds/Speech/SpeechCapture.swift
- blob:78dca523430f29d76593e2e4b93d6161d9ddec9b  LooseEnds/Speech/SpeechDiagnosis.swift
- blob:b2c12ec81e8128dab4b69787f98d260ed92b4bcf  LooseEnds/Views/CaptureView.swift
