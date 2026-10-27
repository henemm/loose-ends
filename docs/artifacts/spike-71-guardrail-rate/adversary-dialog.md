# Adversary Dialog — spike-71-guardrail-rate
Spec: docs/specs/spike-71-schnitt-1-mac-guardrails.md
Datum: 2026-10-27 20:09

## Checkliste
- [x] **AC-1:** `Measurement/GuardrailReport.swift` wertet eine Liste von Proben `{id, menge ("heikel"|"alltag"), sprache, gruppe, durchlauf, fehlerart?}` rein (ohne Modell, ohne Dateizugriff) aus. Die Verweigerungsrate zählt **nur** `guardrail` und `refusal`, je Art getrennt ausgewiesen (und als Summe). `rateLimited`, `timeout`, `contextWindow` und übrige Arten zählen **nicht** in die Verweigerungsrate und werden separat je Art gezählt; sie stehen nicht im Nenner der Rate (Nenner = Proben ohne diese Fehlerarten) und der Bericht nennt ihre Zahl.
- [x] **AC-2:** Die Auswertung weist Raten je Menge (heikel, Alltag) einzeln, je Sprache, je Themengruppe und über alle Texte gemeinsam aus. Ein Text ist ein **Treffer „immer“**, wenn er in allen seinen Durchläufen verweigert wurde, **„manchmal“**, wenn nur in einem Teil; jeder Treffer wird mit Wortlaut, Menge, Gruppe, Sprache und der Fehlerart je Durchlauf aufgelistet.
- [x] **AC-3:** Je Rate gibt es die obere 95-%-Grenze nach Wilson; bei 0 Treffern zusätzlich den Hinweis der Dreierregel (3/n). Die **Schwelle 1 %** wird am Gesamtwert über **alle Texte gemeinsam** (heikel + FocusBlox = „Alltagstext“, Entscheidung dieser Spec) geprüft: „unter“, wenn die Rate ≤ 1 % ist; der Bericht nennt zusätzlich, ob die obere Grenze über 1 % liegt (dann nur „nicht widerlegt“). Beide Mengen stehen einzeln daneben, tragen die Schwelle aber nicht allein. Gezählt wird je Text (ein Text, der in mindestens einem Durchlauf verweigert wurde, ist ein Treffer); die Rate je Durchlauf wird zusätzlich ausgewiesen.
- [x] **AC-4:** `GuardrailReportTests` (Simulator, `sim.sh sim-unit`) prüfen mit gestellten Ergebnissen: jede Fehlerart landet in der richtigen Spalte; `rateLimited` und `timeout` erhöhen die Verweigerungsrate nicht; 0 Treffer (Rate 0, Wilson-Grenze und Dreierregel-Hinweis stimmen für n = 387); 1 Treffer (≈ 0,26 %, Grenze ≈ 1,4 %); „immer“ gegen „manchmal“ bei zwei Durchläufen; Rate je Menge, Sprache und Gruppe; Schwellenurteil am Gesamtwert (z. B. 4 von 387 > 1 %).
- [x] **AC-5:** Die neue Suite `RealModelGuardrailTests` trägt dieselben Gates wie `RealModelLatencyTests` (`.enabled(if: RealModel.isRequested)`, `.enabled(if: RealModel.isAvailable)`, `.serialized`); ohne `LOOSEENDS_REAL_MODEL=1` wird sie übersprungen, nie rot, und läuft nie in der CI. `RealModelGateTests` prüft das im Quelltext auch für die neue Suite, einschließlich der Namen `LOOSEENDS_GUARDRAIL_OUT` und `LOOSEENDS_FOCUSBLOX_CORPUS`.
- [x] **AC-6:** Die Suite läuft je Text **2 Durchläufe** (jeder Text einmal je Durchlauf, auch nach einem Fehlschlag; kein Wiederholen, kein Abbruch nach Fehlern in Folge) über die 100 Texte aus `guardrail-corpus.json` und, wenn `LOOSEENDS_FOCUSBLOX_CORPUS` auf die Datei zeigt, über die 287 `rawText`-Sätze. Fehler werden mit `MeasurementErrorKind.classify` eingeordnet. Die Rohproben gehen als JSON nach `LOOSEENDS_GUARDRAIL_OUT`; ohne diese Variable schreibt die Suite nichts und bleibt grün. Die Rohdaten tragen die FocusBlox-Sätze nicht im Klartext: nur `id` (Index) und Menge, den Wortlaut nur für die heiklen 100 und für Treffer in der **lokalen** Auswertung, nicht in den eingecheckten Rohdaten (persönliche Daten). Ohne die Variable stehen im Lauf-Kopf der Rohdaten „nur 100er-Menge“, und der Bericht sagt das.
- [x] **AC-7:** `./scripts/sim.sh real-model-guardrail` holt die Testsperre wie `real-model-latency`, prüft macOS ≥ Target und Apple Silicon, baut (`build-for-testing`), startet nur `RealModelGuardrailTests` (`test-without-building`), schreibt die Rohdaten nach `docs/artifacts/71-guardrails/` und bricht bei fehlender Datei mit Meldung ab. Es fasst kein iPhone, iPad oder keine Watch an.
- [x] **AC-8:** Der Mess-Durchlauf ist gelaufen (Nachweis: der Lauf selbst, kein automatischer Test; die Suite steht hinter dem Gate) und der Bericht `docs/reference/modell-guardrails.md` enthält: Gerät und System (`sw_vers`, Chip), Weg, Läufe und ob der FocusBlox-Korpus dabei war; die Raten je Fehlerart getrennt (guardrail, refusal, rateLimited, timeout, übrige) je Menge, Sprache und Gruppe; jeden Treffer mit Wortlaut und „immer/manchmal“; die **Nulllinie** (Regel-Spalte 0 % per Konstruktion) mit dem Satz „Ohne Modell geht es nicht, weil …“; den Statistikabschnitt (387 Texte, 1 % ≈ 3,9 Treffer, obere Grenze bei 0 Treffern ≈ 0,8 % und bei 1 Treffer ≈ 1,4 %, die 100 heiklen allein tragen die Schwelle nicht: ein Treffer = 1 %, 0 Treffer → obere Grenze ≈ 3 %); den Hinweis „Mac = ältere Modellgeneration, ersetzt das iPhone nicht“; die Recherche-Quellen mit den Befunden aus „Purpose“; die **Entscheidung gemäß Abbruchkriterium** für die Mac-Spalte (≤ 1 %: B3 trägt auf dem Mac; > 1 %: Folgeticket „Modell hat abgelehnt“ als sichtbarer Zustand statt stummem „ungeprüft“, mit den Alternativen A/B/C und dem Regelweg); den offenen Punkt „iPhone → Schnitt 2, nur nach Hennings wörtlichem ‚jetzt ist ein Test möglich‘, gebündelt mit #88 Teil 2“. Der Bericht entscheidet B3 **nicht** endgültig vor Schnitt 2.
- [x] **AC-9:** `EnrichmentCoordinator.swift`, `FoundationModelsEnricher.swift`, `Measurement/Corpus.swift`, `LooseEndsLab/MeasurementRunner.swift` und alles unter `Shared/` bleiben unverändert (die Dateiliste des PR enthält dort nichts). `docs/reference/focusblox-corpus.json` wird nicht eingecheckt.

## Dialog

### Runde 1
**Adversary:**
Angriffsflächen: (a) Rechnung Wilson/Dreierregel/Schwelle, n=0, (b) Zählung je Text mit Mehrfach-ids und excluded-Durchläufen, (c) Klartext in Rohdaten und Repo, (d) Gates, (e) sim.sh, (f) Bericht gegen Rohdaten, (g) Geräte-Kapitel, (h) Dateiliste.

Testlauf selbst ausgeführt (`docs/artifacts/spike-71-guardrail-rate/adversary-test-output.txt`): `sim-unit GuardrailReportTests` 10 von 10 grün; `sim-unit RealModelGateTests` 4 von 4 grün, 0 rot, 0 übersprungen in diesen beiden Suiten (die Zeilen „2 von 5 übersprungen“ am Ende betreffen die Messstrecken SelfConsistency/TextForm, nicht diese Änderung).

(a) Eigenrechnung in Python (Wilson z=1,96): 2/387 = 0,517 % / 1,86 %; 1/287 = 0,348 % / 1,95 %; 1/100 = 1,0 % / 5,45 %; 2/377 = 0,531 % / 1,91 %; 0/10 = 27,75 %; 0/387 = 0,98 % (Dreierregel 3/387 = 0,775 %); 1/387 = 0,258 % / 1,45 %; 4/387 = 1,034 % (über 1 %); 0/100 = 3,70 % (Dreierregel 3 %). `wilsonUpper` (Measurement/GuardrailReport.swift:120-128) ist dieselbe Formel; n=0 liefert 0 (Zeile 121), `textRate` und `probeRate` fangen n=0 und gemessen=0 ab (Zeilen 39-43); `ruleOfThree` nur bei 0 Treffern und n>0 (Zeile 47). Test `emptyReport` deckt n=0 ab. Abweichung in der Spec: AC-4/AC-8 nennen „obere Grenze bei 0 Treffern ≈ 0,8 %“; das ist die Dreierregel, Wilson gibt 0,98 %. Code und Bericht weisen beide Werte korrekt getrennt aus; die Spec-Zahl ist eine Ungenauigkeit der Spec, kein Umsetzungsfehler.

(b) Zählung: `textKey` = menge/gruppe/sprache/id (Zeile 22), gleiche ids in verschiedenen Gruppen kollidieren nicht; in den Rohdaten sind es 387 eindeutige Schlüssel mit je genau 2 Proben. Ein Text mit teils excluded Durchläufen bleibt „gemessen“, solange ein Durchlauf nicht excluded ist (Zeile 55); ein Text mit nur excluded Durchläufen fällt aus Texten und Nenner (Test `rateLimitAndTimeoutDoNotCount`: 35 Texte). Randfall: Durchlauf 1 = timeout, Durchlauf 2 = guardrail ergibt Treffer „manchmal“ (Zeile 115, `allSatisfy(isRefused)`), obwohl in allen gemessenen Durchläufen verweigert; die Spec sagt „in allen seinen Durchläufen“, also formal richtig, `kindsPerRun` zeigt das timeout. In den echten Daten nicht aufgetreten (nur `guardrail` 4). Nicht blockierend.

(c) Rohdaten per Skript geprüft (keine Satzinhalte ausgegeben): 774 Proben; `alltag` 574 Proben ohne Feld `text`; `heikel` 200 Proben mit `text`; Kopf `nurHeikel: false`, `durchlaeufe: 2`, Gerät `Mac16,12`, System 27.0.1. Alle 262 FocusBlox-Sätze (≥ 15 Zeichen) gegen jede Datei dieser Änderung gesucht (Rohdaten, Bericht, Dialog, Log, Spec, Swift-Dateien, sim.sh, CLAUDE.md, Briefing, Kontext, Testausgaben): 0 Treffer. Die Korpusdatei steht in der Ignorierliste (Zeile 13) und nicht in der Dateiliste des Repos. Treffer in älteren Dateien (z. B. EnergyTests.swift) sind Altbestand, nicht Teil dieser Änderung. Schreibweg: `writeRaw` setzt `text = nil` für jede Menge außer „heikel“ (LooseEndsTests/RealModelGuardrailTests.swift:116-120); die lokale Auswertung mit Wortlaut geht nur nach `LOOSEENDS_GUARDRAIL_LOCAL` = `$TMPDIR` (scripts/sim.sh:463-465), nicht ins Repo. Der Bericht nennt vom zweiten Treffer nur den Gegenstand: ein Hauch persönlicher Inhalt, aber so gewollt, kein Satz.

(d) Gates: Suite `.enabled(if: RealModel.isRequested)` + `.serialized` (RealModelGuardrailTests.swift:13-16), Test zusätzlich `.enabled(if: RealModel.isAvailable)` (Zeile 93), identisch zu `RealModelLatencyTests.swift:12-15`. Die Suche nach REAL_MODEL in `.github` liefert nichts; `ciNeverAsksForTheRealModel` grün. Der neue Quelltext-Test (RealModelGateTests.swift:26-34) prüft beide Gates, `.serialized` und beide Variablennamen; grün.

(e) scripts/sim.sh:455-482: `acquire_testlock` (456), `mac_hosts_tests` (458), arm64-Prüfung (459), `build-for-testing` und `test-without-building` nur mit `-only-testing` der neuen Suite, fehlende Rohdaten → Meldung und return 1. Kein `devicectl`, kein Gerätebefehl in der Funktion. Dispatch Zeile 1043, Hilfe-Bereich auf 3,38 erweitert. Hinweis: `rm -f "$file"` löscht vorhandene Rohdaten vor dem Lauf, damit „Datei fehlt“ ehrlich anzeigt, ob dieser Lauf schrieb.

(f) Bericht gegen Rohdaten: 774 Aufrufe, 2638 s (Log 2638.370 s), 3,4 s je Aufruf (2638/774 = 3,41) stimmen; guardrail 4, sonst nichts (Rohdaten: None 770, guardrail 4); Treffer `gr-047` (kinder, de, beide Durchläufe guardrail) und `alltag-55` (alltag, de, beide guardrail); „kein Treffer manchmal“ stimmt; Deutsch 377 = 90 + 287, Englisch 10 (Gruppe english, 20 Proben); übrige Gruppen 0. Alle Raten und Grenzen im Bericht stimmen mit meiner Rechnung überein.

(g) Gerätekapitel: Die Spec verlangt den Satz „Mac = ältere Modellgeneration“. `sw_vers` dieses Rechners meldet macOS 27.0.1 (Build 26A434), Chip Apple M4; die Rohdaten tragen dasselbe System, und `docs/reference/modell-latenz.md:39` weist das iPhone mit iOS 27.0.1 aus. Die Prämisse der Spec (Mac auf 26.x) ist überholt; „ältere Generation“ wäre unbelegt. Der Bericht sagt stattdessen „nicht belegt“ und hält den Kern („ersetzt das iPhone nicht“) aufrecht. Die Begründung trägt, der Bericht bleibt sauber und die Abweichung steht transparent im Text.

(h) AC-9: Die Diff-Liste gegen die Merge-Basis 694adbf (festgeschriebene und noch offene Änderungen) nennt nur: GuardrailReportTests, RealModelGateTests, test-red-output, Briefing, Kontext, Spec, CLAUDE.md, sim.sh; neu und unversioniert GuardrailReport.swift, RealModelGuardrailTests.swift, Bericht, Rohdaten, Artefakte. Nichts unter `Shared/`, kein EnrichmentCoordinator, FoundationModelsEnricher, Corpus.swift oder MeasurementRunner. Die Diff-Liste gegen origin/main zeigt zusätzlich Dateien von #715; das ist Drift von origin/main, nicht von dieser Änderung.

Offene Frage (selbst beantwortet): Fehlerarten je Menge/Sprache/Gruppe in AC-8: der Bericht zeigt Fehlerarten nur gesamt (guardrail 4, übrige 0) und abgelehnte Proben je Menge/Sprache; da nur `guardrail` auftrat, ist die Aufschlüsselung eindeutig ableitbar. Als erfüllt gewertet, mit Hinweis.
**Implementierer:** nicht erreichbar; Beweise vom Prüfer selbst beschafft.

### Runde 2
**Adversary:**
Zweiter, gezielter Angriff auf die schwächsten Stellen.

1. Kippt die Schwellenaussage bei einer Wertkombination? `isUnder` = `textRate <= 0.01` (GuardrailReport.swift:87). Genau 1 % ist bei 387 Texten nicht erreichbar (3,87 Treffer), also kein Rundungsrand. Test `threshold` deckt 4 (über), 3 (unter, Grenze darüber) und 100 heikle allein mit exakt 0,01 ab; grün.
2. Doppelzählung über Gruppen: `textKey` enthält die Gruppe, also zählt kein Text in zwei Gruppen; `total` zählt jeden Schlüssel einmal (387).
3. Sprache der FocusBlox-Sätze: alle 287 `lang == de`; jede Probe trägt `sprache` aus dem Korpus.
4. Gate-Umgehung: ohne `LOOSEENDS_REAL_MODEL` bleibt die Suite via `.enabled(if:)` übersprungen, nicht rot; mit Variable aber ohne Apple Intelligence überspringt der Test (Zeile 93), `sim.sh` meldet dann „Keine Rohdaten“. CI setzt nichts; `sim-unit` hat `isRequested` false.
5. Klartext im Log: `Logger` gibt nur `item.id` aus (RealModelGuardrailTests.swift:86); Suche im Lauf-Log: 0 Sätze. Die lokale Auswertung mit Wortlaut liegt in `$TMPDIR`, nicht im Repo.
6. Rohdatenkopf `nurHeikel: false` (Zeile 106) passt zum Bericht („FocusBlox war dabei“).
7. Spec-Spannung AC-6 vs AC-8 (Wortlaut jedes Treffers im Bericht, aber FocusBlox-Wortlaut nicht im Repo): zugunsten des Datenschutzes gelöst (Gegenstand statt Wortlaut für den persönlichen Treffer, Wortlaut für `gr-047`). Vertretbar.
8. Bericht-Entscheidung: „≤ 1 % (0,52 %): B3 trägt auf dem Mac“, mit Vorbehalt der Grenze 1,86 %, ausdrücklich ohne endgültige B3-Entscheidung; Abschnitt „Offen: iPhone (Schnitt 2)“ mit Hennings Wortlaut und #88 Teil 2; Quellen 793876, 787736, 835777, WWDC26 241 und 339 mit den Befunden aus Purpose; Nulllinie mit „Ohne Modell geht es nicht, weil …“.
9. Regression: sim.sh, CLAUDE.md und RealModelGateTests ändern nur additiv; bestehende Gate-Tests grün (4 von 4).

Ergebnis: kein Defekt gefunden. Nicht blockierende Beobachtungen: (i) Spec nennt 0,8 % als Wilson-Wert, tatsächlich 0,98 % (Dreierregel 0,78 %), Bericht weist beides aus; (ii) „Mac = ältere Modellgeneration“ bewusst nicht übernommen, weil macOS 27.0.1 belegt ist; (iii) ein Treffer mit einem excluded Durchlauf würde als „manchmal“ geführt, trat nicht auf.

Confirmation:
  AC: AC-1
  Code reference: Measurement/GuardrailReport.swift:14-19
  Evidence: `isRefused` nur guardrail/refusal, `isExcluded` alle anderen Fehlerarten; `byKind` zählt je Art (Zeile 53), Nenner `probes - excludedProbes` (Zeile 41); Tests kindsAreSeparated und rateLimitAndTimeoutDoNotCount grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Measurement/GuardrailReport.swift:103-117
  Evidence: Raten je Menge, Sprache, Gruppe, gesamt (Zeilen 90-96); Treffer „immer/manchmal“ mit Menge, Gruppe, Sprache und `kindsPerRun`; Tests alwaysAndSometimes und slices grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Measurement/GuardrailReport.swift:120-128
  Evidence: Wilson-Formel, n=0-Schutz, Dreierregel (Zeile 47), Schwelle am Gesamtwert (Zeilen 86-88); mit Python nachgerechnet (2/387: 0,517 % / 1,86 %; 0/387: 0,98 %; 1/387: 1,45 %; 4/387: 1,034 %).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsTests/GuardrailReportTests.swift:63-83
  Evidence: Zehn Tests zu Spalten, rateLimited/timeout, 0 und 1 Treffer bei n=387, immer/manchmal, Menge/Sprache/Gruppe, Schwelle 4 von 387; eigener Lauf 10 von 10 grün (adversary-test-output.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEndsTests/RealModelGateTests.swift:26-34
  Evidence: Quelltest prüft beide Gates, `.serialized` und beide Variablennamen; Suite-Gates in LooseEndsTests/RealModelGuardrailTests.swift:13-16 und 93; kein REAL_MODEL in `.github`; eigener Lauf 4 von 4 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEndsTests/RealModelGuardrailTests.swift:95-120
  Evidence: Zwei Durchläufe, jeder Text je Lauf ohne Wiederholung und ohne Abbruch (Zeilen 100-102), `classify` (85), Rohdaten ohne Alltagstext (116-120); Rohdatenprüfung: 774 Proben, 574 alltag ohne `text`, 0 Klartextsätze im Repo.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/sim.sh:455-482
  Evidence: Testsperre, macOS/arm64-Prüfung, build-for-testing, test-without-building nur der Suite, Abbruch bei fehlender Datei, kein Gerätebefehl; Lauf-Log zeigt „Test Execute Succeeded“ und Rohdatenpfad.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/reference/modell-guardrails.md:76
  Evidence: Alle Pflichtabschnitte vorhanden und gegen Rohdaten nachgerechnet; Gerätekapitel weicht begründet vom Spec-Wortlaut ab (macOS 27.0.1 belegt), „ersetzt das iPhone nicht“ bleibt. Rohdaten: docs/artifacts/71-guardrails/mac-rohdaten.json:1.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: CLAUDE.md:68
  Evidence: Dateiliste enthält nur CLAUDE.md (eine Zeile), sim.sh, die genannten Tests, Spec und Artefakte; nichts unter `Shared/`, nicht EnrichmentCoordinator, FoundationModelsEnricher, Corpus.swift, MeasurementRunner; Korpusdatei ignoriert und nicht in der Dateiliste des Repos.
  Status: CONFIRMED

**Implementierer:** nicht erreichbar.

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`); keine Tabelle angehängt. Es gibt keine verdächtigen Zeilen mit nur einer Produktions-Schreibstelle: die Änderung liegt in Messcode (`Measurement/`, Tests, Skript) und schreibt kein Produktfeld.

## Verdict
═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hielt dem Prüfversuch stand.
Tests: 14 bestanden (GuardrailReportTests 10, RealModelGateTests 4), 0 fehlgeschlagen, 0 übersprungen in diesen Suiten
Edge cases: geprüft, keine gebrochen (nicht blockierend: Spec-Zahl 0,8 % ist die Dreierregel, Wilson 0,98 %; Geräte-Satz bewusst abgewandelt; „manchmal“ bei excluded Durchlauf)
Regressions: keine gefunden
Checklist: 9/9 Punkte belegt

Code reference (Dateiabdeckung): Measurement/GuardrailReport.swift:120, LooseEndsTests/RealModelGuardrailTests.swift:13, LooseEndsTests/GuardrailReportTests.swift:63, LooseEndsTests/RealModelGateTests.swift:26, scripts/sim.sh:455, CLAUDE.md:68

## Geprüfte Dateien

- sha256:3e17a070a6fb0aaee5b898916db95abddb6fbf04d5e3fe7a7cbd1f8440856410  CLAUDE.md
- sha256:5e2125a155336e783011068a65bb50c6b429207ac3d833e27b9c81906fe47718  LooseEndsTests/GuardrailReportTests.swift
- sha256:a77bac074b9aa32759455e8fb22d94c79f5b7744cb6e94b6977adae64be1b283  LooseEndsTests/RealModelGateTests.swift
- sha256:c97dc28755a19de3b88c002716c21523776c01f831cafbaf34f85b7350f06c4a  LooseEndsTests/RealModelGuardrailTests.swift
- sha256:a920d306b1b619e72d53b28260a5903f7ff9162211837ffcea2ec44e7ef67145  Measurement/GuardrailReport.swift
- sha256:03ab0e5d77a412ab3d2d9c0bf7c216aaefd84d19a523bd75b0d3574a87ca73ad  docs/reference/modell-guardrails.md
- sha256:6d5b057ecde56eda24a0a274cc79d370ed6e01909cba5421b6b8f9f7d50c8030  scripts/sim.sh

## Prüfbasis

- base: 694adbf3289b2af1b45363b70eb348a18e25998f
- blob:cbbf6dd45aeb2a8c1c099cac5013bdf1c0e67d86  CLAUDE.md
- blob:477e05ca543f791be342a30a68bc3e7513b94810  LooseEndsTests/GuardrailReportTests.swift
- blob:3e25765cf131250b6efc593b23f69b29fc426f51  LooseEndsTests/RealModelGateTests.swift
- blob:e37d19863d5f01881cae829f2b1d8b505000dc50  LooseEndsTests/RealModelGuardrailTests.swift
- blob:55d719aeef2cae573b14536f42d20d36a4ed1634  Measurement/GuardrailReport.swift
- blob:5e0ecee816d23112e81f3d6e3536c6d3e6afa5a8  docs/reference/modell-guardrails.md
- blob:db6ca48771602c36cd6c3720910aac5676668abf  scripts/sim.sh
