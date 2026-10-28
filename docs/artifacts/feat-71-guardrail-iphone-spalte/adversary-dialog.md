# Adversary Dialog — feat-71-guardrail-iphone-spalte
Spec: docs/specs/spike-71-schnitt-2a-laeufer-ablehnung.md
Datum: 2026-10-28 14:40

## Checkliste
- [x] **AC-1:** `MeasurementRun.remaining(from:runsPerEntry:countRefusals:)` und `pass(after:from:runsPerEntry:untilDone:countRefusals:)` haben den Parameter `countRefusals: Bool = false`. Ohne ihn (Standard) bleibt ein Satz, dessen Ergebnis `guardrail` oder `refusal` trägt, offen, die Rückgabe ist identisch zu der vor der Änderung (Regressionsschutz für #88 und #534).
- [x] **AC-2:** Mit `countRefusals: true` zählt ein Ergebnis als gemessen, wenn es erfolgreich ist oder `errorKind` `guardrail` oder `refusal` trägt. Ergebnisse mit `rateLimited`, `timeout`, `assetsUnavailable` oder `contextWindow` zählen nicht und der Satz bleibt in `remaining` offen.
- [x] **AC-3:** Mit `countRefusals: true` und `untilDone: true` terminiert `pass` (kein Satz bleibt wegen einer Ablehnung dauerhaft offen): Eine Simulation über `MeasurementRun`-Ergebnisse, in der ein Satz immer abgelehnt wird, endet nach endlich vielen Pässen mit leerer Liste. Ohne Modell, ohne Gerät.
- [x] **AC-4:** Bei `runsPerEntry: 2` zählt jeder abgelehnte Durchlauf einzeln: Nach einer Ablehnung (runIndex 0) bleibt der Satz mit `runIndex` 1 offen, nach zwei Ablehnungen ist er erledigt. Gemischte Folgen (Erfolg + Ablehnung) zählen beide.
- [x] **AC-5:** `MeasurementPacing.countsAsFailure(_ result:countRefusals:)` liefert `false` für Erfolge, mit Schalter auch für `guardrail` und `refusal`, und `true` für alle übrigen Fehlerarten; ohne Schalter `true` für jeden Fehler. `MeasurementRunner.measureRemaining` benutzt sie: Eine Ablehnung setzt den Zähler `consecutiveFailures` auf 0, löst keine 60-s-Pause aus und zählt nicht zum Dreifehler-Stopp; echte Fehler behalten Pause und Stopp. Die Schwellen `giveUpAfterConsecutiveFailures` (3) und `waitAfterFailure` (60) bleiben unverändert.
- [x] **AC-6:** `MeasurementProgress.done(in:countRefusals:)` zählt mit Schalter die Ergebnisse, die `countsAsMeasured` erfüllen; ohne Schalter ist `done(in:)` unverändert `run.succeeded.count`. Der Läufer nutzt den Wert für `done`, `progress` und das Ende-Log.
- [x] **AC-7:** `Corpus.countRefusals(from:flag:)` liefert `true`, wenn `--count-failures` in den Argumenten steht, sonst `false`. `LabApp` liest das Argument und übergibt es an `MeasurementRunner(countRefusals:)`. Ohne Argument verhält sich die Labor-App wie bisher.
- [x] **AC-8:** `Corpus.url(fileName:)` findet eine Datei `<fileName>.json` in `Documents/` der App als dritte Stelle. Liegt dieselbe Datei im Bündel, gewinnt das Bündel; die Datei neben der Quelle gewinnt vor `Documents/`. Das Verhalten für bestehende Korpora bleibt gleich. Fehlt die Datei überall, wirft `url` weiter `CocoaError(.fileNoSuchFile)`.
- [x] **AC-9:** Der PR berührt genau diese fünf Dateien: `Measurement/MeasurementRun.swift`, `Measurement/Corpus.swift`, `LooseEndsLab/MeasurementRunner.swift`, `LooseEndsLab/LabApp.swift`, `LooseEndsTests/MeasurementRunTests.swift`. Insbesondere bleiben `Shared/`, `FoundationModelsEnricher.swift`, `EnrichmentCoordinator.swift`, `project.yml`, `scripts/sim.sh` und `Measurement/GuardrailReport.swift` unverändert (Dateiliste des PR). Es läuft nichts auf einem Gerät.

## Dialog

### Runde 1
**Adversary:** Beweise für AC-1 bis AC-4: Bleibt das Standardverhalten ohne Schalter identisch? Kann die Schleife mit Schalter und Endlos-Ablehnung terminieren? Zählt jeder Durchlauf einzeln? Kann errorKind nil mit error gesetzt als gemessen gelten?
**Implementierer:** (Belege vom Adversary selbst durch Lesen und Ausführen gesammelt)
- AC-1:
Code reference: Measurement/MeasurementRun.swift:171 und :186, beide `countRefusals: Bool = false`. Bei `false` ist `countsAsMeasured` (Zeile 103) = `succeeded` (`error == nil`, Zeile 95), also `remaining` = Erfolge je Satz wie vorher (alt: `succeeded`, neu: `results.filter{countsAsMeasured}`, äquivalent). Keine weiteren Aufrufer von remaining/pass/done außerhalb Runner und Tests (grep). Test "Ohne Schalter bleibt ein abgelehnter Satz offen, auch mit untilDone (AC-1)" grün (adversary-test-output.txt).
- AC-2:
Code reference: Measurement/MeasurementRun.swift:101 `wasRefused` nur guardrail/refusal; rateLimited, timeout, assetsUnavailable, contextWindow, decoding, other bleiben offen. Test "Mit Schalter zählen guardrail und refusal als gemessen, die übrigen Fehlerarten nicht (AC-2)" grün.
- AC-3:
Code reference: Measurement/MeasurementRun.swift:186-188. Mit Schalter schließt jede Ablehnung ihren Durchlauf, die Menge offener (entry, runIndex) schrumpft monoton; Test "Ein immer abgelehnter Satz hält einen untilDone-Start nicht endlos fest (AC-3)" grün (passes == 2, results.count == 4). Der Test hat eine Schutzgrenze von 20 Pässen; passes == 2 beweist, dass sie nicht greift.
- AC-4:
Code reference: Measurement/MeasurementRun.swift:172 zählt je entryID alle gemessenen Läufe; Test "Bei zwei Durchläufen zählt jeder abgelehnte Durchlauf einzeln (AC-4)" prüft runIndex 1 offen, nach zwei Ablehnungen leer, gemischt Erfolg+Ablehnung leer. Grün.
- Pfad "errorKind nil, error gesetzt": `wasRefused` verlangt errorKind (Zeile 101), also nie gemessen (konservativ, offen bleibt offen). Umgekehrt errorKind gesetzt, error nil: `succeeded` true, zählt als Erfolg wie bisher. Kein Pfad, in dem eine Nicht-Ablehnung als gemessen gilt.

### Runde 2
**Adversary:** Beweise für AC-5 bis AC-9: Verdrahtung im Läufer und in LabApp (nur Diff belegt, reicht das?), rateLimited mit Schalter, Documents als letzte Stelle, Wirksamkeit der Test-Assertion, Dateiliste.
**Implementierer:** (Belege vom Adversary selbst gesammelt)
- AC-5:
Code reference: Measurement/MeasurementRun.swift:205 `countsAsFailure = !countsAsMeasured`; LooseEndsLab/MeasurementRunner.swift:123 setzt `consecutiveFailures` bei Nicht-Fehlversuch auf 0, sonst +1; `delayBeforeNext` (Schwellen 3/60, unverändert, Test prüft beide Konstanten) bleibt. rateLimited gilt mit Schalter weiter als Fehlversuch (Pause, Stopp mit Drosselmeldung, Runner Zeile 125-127 unverändert). Beobachtung (kein Finding): Wechseln sich Drosselung und Ablehnung ab, setzt eine Ablehnung den Zähler zurück; der Lauf bleibt endlich, weil jede Ablehnung ihren Satz schließt. Die Schleife selbst ist ohne Gerät nicht testbar (FoundationModels, UIApplication); der Test deckt die pure Entscheidung ab, die Schleife nutzt sie direkt in einer Zeile: ausreichend.
- AC-6:
Code reference: Measurement/MeasurementRun.swift:214 `done(in:countRefusals:)`; LooseEndsLab/MeasurementRunner.swift:36 (`done` speist `progress` und das Ende-Log) und :66 (Startzustand `.finished` mit Schalter). Test "Der Fortschritt zählt mit Schalter ..." grün (1 / 1 / 2).
- AC-7:
Code reference: Measurement/Corpus.swift:231 `arguments.contains("--count-failures")`; LooseEndsLab/LabApp.swift:20 reicht an `MeasurementRunner(countRefusals:)` (Runner-Init Zeile 58/64, Standard false). Test "--count-failures schaltet ..." grün. Die LabApp-Zeile ist eine Ein-Zeilen-Verdrahtung mit Standardwert; ohne Argument false.
- AC-8:
Code reference: Measurement/Corpus.swift:156-166: `bundled ?? local`, local = erstes existierendes aus [onDisk, documents]; Documents ist letzte Stelle, Bündel gewinnt, Quellordner vor Documents, sonst `CocoaError(.fileNoSuchFile)`. Assertion-Prüfung: Der Positivfall (Zufallsname nur in Documents, Ergebnis == Datei) kann ohne die neue Stelle nicht grün sein (alter Code warf). Der Vorrangfall legt `Corpus.fileName` als Schatten in Documents an und verlangt, dass url sie NICHT liefert: würde Documents das Bündel verdecken, wäre er rot. Schwäche (LOW, kein Finding): Der Vorrang "Quellordner vor Documents" ist nur indirekt gedeckt, wenn das Bündel die Datei nicht trägt; der Code zeigt die Reihenfolge eindeutig. Test grün.
- AC-9:
Code reference: Measurement/Corpus.swift:231 (Diffstat: LooseEndsLab/LabApp.swift, LooseEndsLab/MeasurementRunner.swift, Measurement/Corpus.swift, Measurement/MeasurementRun.swift, 38+/12-); LooseEndsTests/MeasurementRunTests.swift im HEAD-Commit 41a714c (+130). Statusliste: sonst nur untracked .claude/, docs/artifacts, docs/context; Shared/, project.yml, scripts/sim.sh, GuardrailReport.swift, FoundationModelsEnricher.swift, EnrichmentCoordinator.swift unverändert. Nichts auf einem Gerät gelaufen (nur sim-unit im Simulator).
- Testlauf: `./scripts/sim.sh sim-unit MeasurementRunTests`, Ausgabe docs/artifacts/feat-71-guardrail-iphone-spalte/adversary-test-output.txt: "Test Succeeded", "Unit-Tests bestanden", 0 fehlgeschlagen, alle 8 neuen Tests (AC-1 bis AC-8) und die bestehenden Suiten grün. Übersprungen: nur die fremden Messstrecken SelfConsistencyReportTests und TextFormModelReportTests (fehlende Messdateien, nicht Teil dieser Änderung).

Code reference: LooseEndsLab/MeasurementRunner.swift:123
Code reference: LooseEndsLab/LabApp.swift:20

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict: VERIFIED

## Geprüfte Dateien

- sha256:70bd40bfedd7d74281a3f1fafb258611d428db9b32febe32b528494e4b3d1325  LooseEndsLab/LabApp.swift
- sha256:1e130de582fe4eef447b35a980933c4e450d89cace5499cec68024059de110d5  LooseEndsLab/MeasurementRunner.swift
- sha256:db7d133a61bb15de896ba13d1f4d1f54f21fa29c153acc093fd5323cf2d2535c  Measurement/Corpus.swift
- sha256:440e8e143484ece35623762ef4cde9dbc3a7128b56b3321831a11c5e2933082d  Measurement/MeasurementRun.swift

## Prüfbasis

- base: 8211af4b2e85ecb42e4a82c4a29dc484c1d90f9e
- blob:1e4e8ba4001f527ff85491c02e7f00ca586f5579  LooseEndsLab/LabApp.swift
- blob:d9df1b226edb95abd968ab8cb9dd6334be484ae8  LooseEndsLab/MeasurementRunner.swift
- blob:bdefd653e78ee760d344ff8f40987ed8ff485033  Measurement/Corpus.swift
- blob:9542289bf4c90cf8d5e9b0dedfbfa12f1c3b197d  Measurement/MeasurementRun.swift
