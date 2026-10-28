# Context: feat-71-guardrail-iphone-spalte (#71, Schnitt 2)

## Request Summary
Annahme B3 (Epic #370, M3): Lässt das Modell Alltagstext durch? Schnitt 1 (Mac, PR #727) misst 2 von 387 Texten abgelehnt = 0,52 %, obere
95-%-Grenze 1,86 %. Schnitt 2 ist die iPhone-Spalte in der Labor-App (andere Modellgeneration als der Mac). Erst danach wird B3 entschieden.
Der Gerätelauf läuft nur nach Hennings wörtlichem „jetzt ist ein Test möglich“, gebündelt mit #88 Teil 2. Dieser Schnitt baut und belegt
nur den Messcode ohne Gerät. Die Hintergründe und die Recherche stehen in `docs/context/spike-71-guardrail-rate.md`.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsLab/MeasurementRunner.swift` | Läufer. `measureRemaining` stoppt nach 3 Fehlern in Folge, wartet 60 s nach einem Fehler und beendet sich bei `--exit-when-done` selbst. Hier kommt der Schalter `--count-failures` hinein. |
| `LooseEndsLab/LabApp.swift` | Liest die Argumente (`--corpus`, `--runs`, `--result`, `--context-words`, `--exit-when-done`) und gibt sie an den Läufer weiter. |
| `Measurement/MeasurementRun.swift` | `remaining(...)` zählt nur **erfolgreiche** Ergebnisse (`succeeded`) als erledigt. Ein abgelehnter Satz bleibt deshalb ewig offen. Mit `--exit-when-done` würde er in jedem Durchgang erneut gemessen, ohne Ende. Das ist die eigentliche Falle (siehe Risiken 1). `MeasurementPacing` und `MeasurementErrorKind` liegen hier. |
| `Measurement/GuardrailReport.swift` | Reine Auswertung: `GuardrailProbe` (Textschlüssel `menge/gruppe/sprache/id`, `durchlauf`, `fehlerart`) und Zählung je Text mit Wilson-Grenze. Wird wiederverwendet. Ein `MeasurementResult` muss in eine `GuardrailProbe` übersetzt werden: `entryID`, `runIndex`, `errorKind`. |
| `Measurement/Corpus.swift` | `Corpus.load(fileName:)` kennt zwei Formate (Liste von Einträgen, Textform-Objekt). Das FocusBlox-Format (`lang`, `rawText`) kennt es nicht. `Corpus.url` sucht nur im Bundle oder neben der Quelldatei. |
| `Measurement/guardrail-corpus.json` | 100 heikle Texte, liegt im Bundle der Labor-App, weil `project.yml` den ganzen Ordner `Measurement` als Quelle listet. |
| `LooseEndsTests/RealModelGuardrailTests.swift` | Der Mac-Weg: Menge `heikel` + `alltag` (Id `alltag-<Index>`, nie der Satz), 2 Durchläufe je Text, kein Wiederholen. Rohdatei ohne Alltagswortlaut, lokale Auswertung mit Wortlaut nur nach `$TMPDIR`. Dasselbe Verhalten muss die iPhone-Spalte haben. |
| `LooseEndsTests/MeasurementRunTests.swift`, `GuardrailReportTests.swift` | Muster für Unit-Tests von `remaining`/`pass` und der Zählung. |
| `scripts/sim.sh` (`cmd_lab`, `lab_latency_launch`, `cmd_lab_latency`, `cmd_lab_fetch`) | Muster für den Gerätelauf: Start per `devicectl ... --measure --corpus ... --runs 2 --result ... --exit-when-done`, Datei per `devicectl device copy from` zurück. Ein Aufruf `lab-guardrail` käme hierher. Nur nach Hennings Wort. |
| `docs/reference/modell-guardrails.md` | Bericht. Die Mac-Spalte steht, die iPhone-Spalte wird ergänzt. |
| `docs/artifacts/71-guardrails/mac-rohdaten.json` | Rohdaten Mac; daneben käme `iphone-rohdaten.json`. |
| `docs/reference/focusblox-corpus.json` | 287 echte Sätze mit `rawText`. **Gitignored**, liegt nur im Hauptordner `/Users/hem/Developer/loose-ends/docs/reference/`, nicht in diesem Worktree. |

## Existing Patterns
- Die Labor-App wird mit Startargumenten gesteuert; Ergebnisse liegen in `Documents/<name>.json` und werden per `devicectl` geholt.
- Persönliche Sätze kommen nie ins Repo: Rohdaten tragen nur `alltag-<Index>`; der Wortlaut bleibt in einer lokalen Datei außerhalb.
- Ein neuer Verhalten-Schalter gilt nur, wenn er gesetzt ist, damit #88 (Textform-Spalte) und die Latenzreihe (#534) unverändert laufen.
- Rule-based-Spalte: Für diese Messung leer, Regeln lehnen nie ab. Der Bericht sagt das schon (Schnitt 1).

## Dependencies
- Upstream: Schnitt 1 (`GuardrailReport`, Korpus #276), `MeasurementErrorKind.classify` (#536), `MeasurementRunner`/`MeasurementRun` (#65, #83, #534).
- Downstream: Entscheidung über B3 und damit Epic #370 (Einladung externer Tester) und #176 (wartet auf #71 und #88). Bei Überschreitung ein Folgeticket „Modell hat abgelehnt“ als sichtbarer Zustand.
- Gebündelt mit #88 Teil 2: dasselbe Gerät, dieselbe Labor-App, eigener Start je Korpus.

## Existing Specs
- Keine Spec zu #71. Muster für einen Spike mit Gerätelauf: `docs/specs/` zu #534.

## Risks & Considerations
1. **Endlosschleife bei Ablehnung.** `remaining()` zählt nur erfolgreiche Ergebnisse. Mit `--exit-when-done` misst `pass` einen abgelehnten Satz immer wieder; der Dreifehler-Stopp bräche zusätzlich den Lauf ab. `--count-failures` muss einen Satz mit jedem Ergebnis (auch mit Fehler) als gemessen zählen, ohne Pause und ohne Dreifehler-Stopp. Ausnahme müsste ein Fehler sein, der nichts über den Text sagt (rateLimited, timeout): der Bericht schließt diese Proben schon aus dem Nenner, der Läufer darf sie aber nicht als „gemessen“ verbuchen, sonst fehlt die Probe. Das ist in der Analyse zu entscheiden.
2. **Die 287 persönlichen Sätze auf dem Gerät.** Sie dürfen weder ins Repo noch ins Bündel der Labor-App (der Ordner `Measurement` wird mitgebündelt). Zu klären: Datei per `devicectl` in `Documents/` der Labor-App legen und von dort laden, statt sie zu bündeln. Die Labor-App ist Hennings eigene Wegwerf-App; die Dateien liegen nur in ihrem Container und verschwinden mit der Deinstallation.
3. **Eigene Kennung, ohne Konkurrenz.** Die Labor-App läuft unter `com.henning.looseends.lab`, nie unter der Alltags-App. `lab-latency` deinstalliert sie vorher; für diesen Lauf ist das nicht nötig, solange der Ergebnisname neu ist.
4. **Dauer.** Mac: 774 Aufrufe in 2638 s (3,4 s). Auf dem iPhone nach #534 Latenz deutlich länger (Schätzung für Henning folgt aus der Latenzmessung; 25 s ist die Obergrenze je Aufruf). Der Lauf muss in Scheiben möglich sein, da Henning das Gerät benutzt (Memory: Handy ist kein Prüfstand). Der Läufer macht das schon: Datei nach jedem Satz, Weiterlauf beim nächsten Start.
5. **Umfang.** Schnitt 1 hatte +527 Zeilen (Limit 250). Hier höchstens 4–5 Dateien: Läufer, Argument-Leser, Übersetzung Ergebnis → Probe, Test, Skript. Der Bericht (Doku) und das Skript zählen mit.
6. **Geräteliste.** Berührt `LooseEndsLab/`, `Measurement/`, `scripts/`, `docs/`. Kein Pfad der Geräteliste im Produkt. Der Gerätelauf selbst ist die Messung und kommt erst nach Hennings Wort. Eine Änderung an `project.yml` ist nicht vorgesehen, sonst greift die Geräteliste.
7. **Zwei Modellgenerationen.** Mac = ältere Generation, iPhone 16 Pro = aktuelle. Beide Spalten stehen getrennt, die Mac-Zahl ersetzt die iPhone-Zahl nicht.

## Analysis

### Type
Feature (Spike, Messung). Kein Fehler im Alltag; eine tragende Annahme wird geprüft.
„Hat es bisher funktioniert?“ trifft nicht zu, die iPhone-Messung ist neu.

### Befund zum Weg
Ohne Modell geht es nicht, weil die Frage lautet, ob **das Modell** ablehnt. Regeln lehnen nie ab, die Nulllinie dieser Spalte ist 0 %. Der Regelweg ist die Alternative bei Überschreitung (Parser ohne Modell für diese Aufgabe).

### Alternative zum bisherigen Weg
- **Kein Laborlauf auf dem iPhone, B3 auf der Mac-Zahl entscheiden.** Würde die Entscheidung kippen, dass Mac und iPhone wegen verschiedener Modellgenerationen getrennt gemessen werden. Verworfen, weil die obere Grenze 1,86 % über der Schwelle liegt und die Generation wechselt.
- **Messung ohne persönliche Sätze:** nur die 100 heiklen Texte auf dem iPhone. Trägt die 1-%-Schwelle nicht (ein Treffer = 1 %), deshalb nur als Notlösung.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/MeasurementRun.swift` | MODIFY | `remaining`/`pass` mit `countRefusals`: Ein Satz, den das Modell ablehnt (`guardrail`, `refusal`), zählt als gemessen. `rateLimited`, `timeout` u. a. bleiben offen. |
| `LooseEndsLab/MeasurementRunner.swift` | MODIFY | Schalter durchreichen. Eine Ablehnung ist weder Fehlversuch für den Dreifehler-Stopp noch löst sie die 60 s Pause aus. |
| `Measurement/Corpus.swift` | MODIFY | `Corpus.countRefusals(from:)` (`--count-failures`). `url(fileName:)` sucht zusätzlich in `Documents/`, damit die 287 persönlichen Sätze nie ins Bündel gehen. |
| `LooseEndsLab/LabApp.swift` | MODIFY | Argument lesen, an den Läufer geben. |
| `LooseEndsTests/MeasurementRunTests.swift` | MODIFY | Tests für `remaining`/`pass` mit Ablehnung, Fehlerart `rateLimited`, Abbruch ohne Endlosschleife. |
| Schnitt 2b: `scripts/sim.sh` (`lab-guardrail`), `Measurement/GuardrailReport.swift` (Ergebnis → Probe), Test, `docs/reference/modell-guardrails.md`, `docs/artifacts/71-guardrails/iphone-rohdaten.json` | MODIFY/CREATE | Gerätelauf-Skript, Auswertung, Bericht. Läuft erst nach Hennings „jetzt ist ein Test möglich“. |

### Scope Assessment
- Schnitt 2a (jetzt, ohne Gerät): 5 Dateien (4 Produktion, 1 Test), ca. +60/−10 Produktionszeilen, ca. +120 Testzeilen. Unter dem Limit.
- Schnitt 2b (Skript, Auswertung, Bericht): 4–5 Dateien, ca. +150 Zeilen. Gesamt über 250, deshalb zwei Teil-Specs (wie bei Schnitt 1, das mit +527 überzog).
- Risk Level: LOW. Nur Labor-App und Messcode, kein Produktpfad, keine Geräteliste, kein `project.yml`.

### Technical Approach
1. **Korpus ohne Bündel.** Ein Skript baut auf dem Mac eine Datei `guardrail-iphone.json` nach `$TMPDIR`: die 100 heiklen Texte (Id `heikel:<id>`, Form als `form`) und die 287 `rawText` aus `focusblox-corpus.json` (Id `alltag-<Index>`, nie der Satz). Sie kommt per `devicectl` in `Documents/` der Labor-App. Die Datei liegt nur im Container der Wegwerf-App und nicht im Repo oder Bündel.
2. **Schalter `--count-failures` (nur wenn gesetzt).** Als gemessen zählt ein Ergebnis, wenn es erfolgreich ist oder die Fehlerart `guardrail`/`refusal` trägt, also das Modell Nein sagt. `rateLimited`, `timeout`, `assetsUnavailable`, `contextWindow` u. a. sagen nichts über den Text: Sie zählen nicht und werden in einer späteren Scheibe wiederholt. Der Bericht schließt sie ohnehin aus dem Nenner (Schnitt 1). Das löst die Endlosschleife aus Risiko 1: Mit `--exit-when-done` misst ein abgelehnter Satz nicht immer wieder.
3. **Pacing.** Eine Ablehnung setzt `consecutiveFailures` nicht hoch und löst keine 60 s Pause aus, sonst dauerte der Lauf Stunden länger. Echte Fehler behalten Pause und Dreifehler-Stopp.
4. **Dasselbe Verhalten wie am Mac:** 2 Durchläufe je Text, kein Wiederholen eines abgelehnten Satzes, Rohdaten ohne Alltagswortlaut.
5. **Ohne Modell geht es nicht, weil** die Frage lautet, ob *das Modell* ablehnt. Regeln lehnen nie ab, die Regel-Spalte ist 0 % (Beleg: Schnitt 1, `docs/reference/modell-guardrails.md`).

### Alternativen
- **Auf der Mac-Zahl entscheiden** (0,52 %, obere Grenze 1,86 %): würde die Annahme kippen, dass die Modellgenerationen getrennt zählen. Verworfen: Die Grenze liegt über 1 %, und das iPhone hat die neuere Generation.
- **Nur die 100 heiklen Texte** auf dem iPhone: ein Treffer wäre schon 1 %. Nur Notlösung, falls Henning die persönlichen Sätze nicht aufs Gerät lassen will.
- **Läufer gar nicht ändern**, abgelehnte Sätze von Hand ausschließen: bräche den Aufbau (Endlosschleife) und beweist nichts. Verworfen.
- Gekippte ADR: keine. B3 wird erst nach dem Gerätelauf entschieden.

### Dependencies
Schnitt 1 (`GuardrailReport`, Korpus #276), `MeasurementErrorKind.classify` (#536), Läufer (#65, #83, #534). Downstream: B3, Epic #370, #176 (wartet auf #71 und #88). Der Gerätelauf wird mit #88 Teil 2 gebündelt.

### Open Questions
- [ ] Keine für Henning offen. Der Gerätelauf braucht sein wörtliches „jetzt ist ein Test möglich“ und wird dann per AskUserQuestion mit Dauer angefragt (nicht in diesem Schnitt).
