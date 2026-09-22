# Context: Spike #65 — Unsicherheitssignal für Feld-Konfidenz (A1)

## Request Summary

Prüfen, ob eines von zwei Ersatzsignalen (Selbstkonsistenz über mehrere Läufe, Enthaltung bei
signalfreiem Text) die Felder trennt, bei denen `FoundationModelsEnricher` bisher eine
selbstberichtete Konfidenz liefert (`importance`, `urgency`, `duration`, `energy`) — denn diese
selbstberichtete Zahl trennt laut Kalibrierung zu #23 nicht (Precision bleibt über Schwellen 0,3–0,9
konstant, drei der vier Felder nahe Zufallsniveau). Das dritte im Issue genannte Signal
(Zweitmeinung eines stärkeren Modells) ist laut PO-Entscheidung aus dieser Sitzung **nicht** Teil
dieses Spikes — es hängt an einer noch fehlenden Freigabe (#74) und wird bei Bedarf als eigenes
Issue nachgezogen.

## Bereits entschiedene Fakten (nicht neu zu verhandeln)

- **Datum** ist bereits raus aus dem Modell: `DueDateRule` liefert es deterministisch (#95),
  99,3 % exakt. A1 betrifft das Datum nicht mehr.
- **Titel** ist bereits vermessen und sauber (#67, 99,7 % ohne erfundene Fakten über alle
  Bauformen). A1 betrifft den Titel nicht — kein Bedarf für ein Unsicherheitssignal dort.
- Betroffen sind ausschließlich die vier Felder mit selbstberichteter Konfidenz, für die die
  Kalibrierung in #23 schon eine Nulllinie liefert: `importance`, `urgency`, `duration`, `energy`
  (`contexts`, `people`, `project` hat #23 nicht vermessen — außerhalb des Spikes, außer
  `/20-analyse` findet einen Grund, sie mitzunehmen).

## Related Files

| File | Relevanz |
|---|---|
| `Shared/Enrichment/FoundationModelsEnricher.swift` | Modell-Adapter; `ModelEnrichment` liefert je Feld Wert + selbstberichtete Konfidenz + Begründung — genau die Konfidenz, die A1 in Frage stellt |
| `Shared/Enrichment/EnrichmentDraft.swift` | `EnrichmentDraft.Guess<Value>` (Wert, Konfidenz, Begründung); `EnrichmentInput`/`EnrichmentExample` |
| `Shared/Enrichment/EnrichmentWriter.swift` | Schreib-Schwelle `confidenceThreshold = 0.6`; genau der Wert, den ein neues Signal ersetzen oder ergänzen müsste |
| `LooseEndsTests/FocusBloxCalibrationTests.swift` | Bestehende Kalibrierung zu #23: lädt `docs/reference/focusblox-corpus.json` (Wahrheit aus FocusBlox), ruft das Modell 60× auf, baut Precision/Recall-Tabellen je Schwelle für genau die vier Felder — direkte Vorlage für Signal „Selbstkonsistenz", müsste aber um Mehrfachläufe je Satz erweitert werden |
| `docs/reference/focusblox-calibration-report.md` | Die Nulllinie, gegen die jedes neue Signal sich schlagen muss (siehe unten) |
| `scripts/export-focusblox-corpus.swift` | Exportiert FocusBlox-Store (287 Aufgaben) nach `docs/reference/focusblox-corpus.json` — gitignored, enthält echte Aufgabentitel, liegt nur lokal bei Henning |
| `Measurement/Corpus.swift`, `Measurement/MeasurementRun.swift` | Bestehende Mess-Infrastruktur aus #67: Korpus-Laden, Ergebnis-Datei-Format (`MeasurementResult`, `MeasurementRun`, `MeasurementStore`), Drosselungs-Logik (`MeasurementPacing`) — kompiliert in Tests und Lab-App, kein Produktpfad |
| `LooseEndsLab/LabApp.swift`, `LooseEndsLab/MeasurementRunner.swift` | Die Labor-App: misst ein Korpus (aktuell hart auf `"date-title"` verdrahtet) einen Satz nach dem anderen, nur im Vordergrund, sichert nach jedem Satz, macht bei Unterbrechung später weiter |
| `scripts/sim.sh` (Ziele `lab`, `lab-fetch`, `device-measure`) | Baut/installiert die Labor-App aufs Gerät, holt Ergebnisdateien ab, ruft `measurement-summary.py` |
| `docs/project/06-annahmen-und-experimente.md` | Annahme A1 in der Tabelle „Stufe A"; Abschnitt „Die Messumgebung" mit den drei Befunden unten |

## Die Nulllinie: Kalibrierung zu #23 (bereits gemessen, 2026-09-xx, `docs/reference/focusblox-calibration-report.md`)

60 von 287 FocusBlox-Aufgaben, Schreib-Schwelle 0,6:

| Feld | Precision bei Schwelle 0,6 | Bereich über alle Schwellen 0,3–0,9 |
|---|---|---|
| importance | 35 % | 33–38 % (praktisch konstant) |
| urgency | 25 % | 25–29 % (praktisch konstant) |
| duration | 51 % | 50–53 % (praktisch konstant) |
| energy | 23 % | 23–27 % (praktisch konstant) |

Diese Zeile ist die Vergleichsbasis für jedes neue Signal (Regel „Die Nulllinie zählt",
[[feedback-rules-before-model]]): Trennt Selbstkonsistenz oder Enthaltung merklich besser als diese
Werte, ist es das gesuchte Signal. Trennt es nicht besser, ist die Antwort auf A1 „kein Signal
funktioniert" — und damit zählt das Abbruchkriterium aus #65 (kein Signal ≥ 85 % Trefferquote bei
≥ 30 % Abdeckung).

## Existing Patterns

- **Mess-Report-Format:** Eine reine Markdown-Tabelle in `docs/reference/*.md`, von einem
  Swift-Test oder -Skript selbst geschrieben (`FocusBloxCalibrationTests.calibrate()` schreibt
  seinen eigenen Report; `date-title-fidelity.md` ebenso). Kein Dashboard, keine App-UI für Reports.
- **Mess-Ergebnis-Format:** `MeasurementResult`/`MeasurementRun` (JSON, `Codable`), append-only,
  nach jedem Satz gesichert. Für Selbstkonsistenz (5 Läufe je Satz) fehlt aktuell ein Weg, mehrere
  Ergebnisse zu demselben `entryID` zu unterscheiden — `doneIDs`/`remaining(from:)` gehen von genau
  einem Ergebnis pro Satz aus.
- **Korpus-Wahrheit:** Zwei getrennte Korpora mit unterschiedlicher Wahrheitsquelle — das
  Datums-/Titelkorpus (`Measurement/date-title-corpus.json`, Regel-basierte Wahrheit, versioniert)
  und der FocusBlox-Export (`docs/reference/focusblox-corpus.json`, echte bestätigte Werte,
  gitignored, nur lokal). A1 braucht für importance/urgency/duration/energy den FocusBlox-Korpus,
  da nur dort eine echte Wahrheit existiert.

## Harte Projektregel für den Messaufbau

**[[feedback-phone-is-not-a-test-bench]] — „Handy ist kein Prüfstand":** Messungen laufen in der
Labor-App in Scheiben, **nie als Xcode-Testlauf**. `FocusBloxCalibrationTests.swift` ruft das Modell
zwar in einer Testfunktion auf — das ist die Vorlage aus #23, vor dieser Regel entstanden. Ein neuer
Messaufbau für A1 (erst recht mit 5 Läufen je Satz statt einem) darf dieses Muster **nicht**
fortführen; er gehört in die Labor-App mit derselben Drosselungs-/Fortsetzungs-Logik wie
`MeasurementRunner`. Das ist der wahrscheinlich größte Konflikt, den `/20-analyse` auflösen muss:
Wie führt die Labor-App 5 Läufe je Satz durch (statt einem), ohne die bestehende Fortsetzbarkeit bei
Unterbrechung zu verlieren?

## Weitere Randbedingungen aus „Die Messumgebung" (bereits nachgemessen, 2026-09-19)

- Der Simulator misst nichts (`SystemLanguageModel` meldet verfügbar, jeder Aufruf scheitert am
  fehlenden Modell-Katalog auf macOS 26). Jede Messung läuft ausschließlich auf dem iPhone.
- Reine Logiktests laufen auf dem Gerät nicht ohne Träger-App; dafür existiert bereits
  `sim.sh device-measure` mit eigener Info.plist zum Signieren.
- Am Akku drosselt Apple nach wenigen Aufrufen automatisch; Messläufe brauchen das iPhone am
  Strom, entsperrt, ohne automatische Sperre.
- Der Mac misst eine andere Modellgeneration als das iPhone (2025er- vs. 27er-Modell) — für A1
  zählt nur die Messung auf dem iPhone.

## Dependencies

- **Upstream:** `SystemLanguageModel` / `LanguageModelSession` (Foundation Models), verfügbar nur
  auf dem iPhone mit aktivierter Apple Intelligence, Deutsch.
- **Downstream (wer von einem A1-Ergebnis betroffen wäre):** `EnrichmentWriter.confidenceThreshold`
  (0,6) und die vier Felder in `ModelEnrichment`/`EnrichmentDraft` — ein neues Signal würde entweder
  die Schreib-Schwelle ersetzen oder als zusätzliche Bedingung neben ihr stehen. Das ist eine
  Design-Entscheidung für `/20-analyse`, nicht für diesen Kontext.

## Existing Specs

Keine `docs/specs/`-Einträge zu Konfidenz oder Enrichment gefunden — die Entscheidungen zu diesem
Bereich stehen bisher nur in `docs/project/06-annahmen-und-experimente.md` und im Code selbst
(Kommentare bei `EnrichmentWriter`, `confidenceThreshold`).

## Analysis

### Type

Feature (Spike / Messaufbau, kein Bugfix)

### Entscheidung (Henning, 2026-09-21): Signale nacheinander mit Entscheidungspunkt

Statt beide Signale aus #65 parallel zu bauen, wird zuerst nur **Selbstkonsistenz** gemessen und
ausgewertet. Zeigt das Ergebnis bereits eindeutig „kein Signal trennt" (nahe der Nulllinie aus #23:
Precision 33–38 % importance, 25–29 % urgency, 50–53 % duration, 23–27 % energy), wird das im Report
vermerkt und **Enthaltung** als eigenes, ggf. zurückgestelltes Folge-Issue behandelt statt automatisch
mitgebaut. Das erfüllt die DoD aus #65 nicht zwangsläufig wörtlich (dort werden „Kurven je Feld und
**Signal**" gefordert, Plural), spart aber den vollen Mehrtage-Messaufwand für ein zweites Signal,
wenn die Antwort nach dem ersten schon feststeht.

**Alternative (verworfen):** Beide Signale unabhängig vom Zwischenergebnis bauen, wie im Issue grob
skizziert — erfüllt die DoD wörtlich, kostet aber den vollen Aufwand auch dann, wenn Selbstkonsistenz
allein schon zeigt, dass kein Signal trennt. Henning hat sich am 2026-09-21 explizit für die gestufte
Variante entschieden.

### Affected Files — Schritt 1: Mess-Infrastruktur (Fundament, gemeinsam für beide Signale)

| File | Change Type | Description |
|---|---|---|
| `Measurement/Corpus.swift` | MODIFY | `load(fileName:calendar:)` — Dateiname parametrisierbar statt `Corpus.fileName`-Konstante fest verdrahtet |
| `Measurement/MeasurementRun.swift` | MODIFY | `MeasurementResult.runIndex: Int = 0` neu; `doneIDs`/`remaining(from:)` von Mengen-Mitgliedschaft auf Laufzähler (`runsPerEntry`) umstellen |
| `LooseEndsLab/MeasurementRunner.swift` | MODIFY | Korpusname durchreichen (`Corpus.load(fileName:)` statt `Corpus.load()`), `runsPerEntry`-Konstante, `measure(_:runIndex:)`, `done`/`total`/`progress` auf Läufe statt Sätze umstellen |
| `LooseEndsLab/LabApp.swift` | MODIFY | Korpuswahl aus Startargument lesen (analog zum bestehenden `--measure`-Flag) |

~4 Dateien, geschätzt gut unter 250 LoC (reine Parametrisierung + eine neue Zählvariante bestehender
Logik, keine neuen Konzepte). Passt in den Scoping-Rahmen.

### Affected Files — Schritt 2: Selbstkonsistenz-Signal (bedingt durch Schritt 1)

| File | Change Type | Description |
|---|---|---|
| `scripts/export-focusblox-corpus.swift` | MODIFY | Export-Format an `Corpus.Entry`-Schema angleichen, damit der FocusBlox-Korpus durch denselben Runner läuft wie das Datums-/Titelkorpus |
| `Measurement/` (neu, Name TBD in Spec) | CREATE | Reine Vergleichs-/Aggregationslogik: Einstimmigkeit über 5 Läufe als Ersatz-Konfidenz, Trefferquote-über-Abdeckung-Kurve je Feld — Vorlage: `outcome(guess:truth:)`/`table(field:outcomes:)` aus `FocusBloxCalibrationTests.swift`, aber als reine Funktionen ohne XCTest-Bindung, unit-testbar auf dem Mac |
| Report-Skript (Erweiterung `scripts/measurement-summary.py` oder neues Swift-Skript) | MODIFY/CREATE | Schreibt `docs/reference/`-Report aus den gesammelten Mehrfachlauf-Ergebnissen |
| `docs/reference/uncertainty-signal-selfconsistency-report.md` | CREATE (durch Skript) | Ergebnis-Report: Kurve je Feld, Vergleich gegen Nulllinie aus #23 |

~3–4 Dateien zusätzlich. Enthält auch den eigentlichen Mehrtage-Gerätelauf (kein Code, aber der
zeitkritische Teil).

### Schritt 3 (bedingt, eigenes Folge-Issue): Enthaltungs-Signal

Nur wenn Schritt 2 keine eindeutige Antwort liefert. Braucht zusätzlich eine signalfreie Teilmenge des
FocusBlox-Korpus (Wortliste „enthält kein Dringlichkeits-/Dauer-/Energie-Wort" — deterministisch,
[[feedback-rules-before-model]]) und eine eigene Auswertung. Umfang wird erst in der Spec für dieses
Folge-Issue geschätzt.

### Scope Assessment

- Schritt 1 (Infrastruktur): 4 Dateien, niedrig-mittleres Risiko, keine Produktcode-Berührung
  (`Measurement/`, `LooseEndsLab/` — kompilieren nicht in die Haupt-App).
- Schritt 2 (Selbstkonsistenz): 3–4 Dateien, niedrig-mittleres Risiko, plus der eigentliche
  mehrtägige Messlauf auf Hennings Gerät (Zeitrisiko, kein Code-Risiko).
- **Empfehlung:** Schritt 1 und 2 als getrennte, aufeinanderfolgende Spec/PR-Paare behandeln (jede für
  sich innerhalb der 4–5-Datei-/250-LoC-Grenze), nicht als eine große Spec. Schritt 3 wird erst als
  eigenes Issue angelegt, wenn Schritt 2 abgeschlossen ist und die Nulllinie nicht reicht.
- Risk Level: **Niedrig** — reine Test-/Mess-Infrastruktur, kein Pfad in die ausgelieferte App, keine
  Nutzerdaten betroffen.

### Technical Approach

1. Mess-Infrastruktur so erweitern, dass mehrere Läufe pro Satz gezählt (nicht nur binär
   erledigt/nicht-erledigt) und ein zweites Korpus (FocusBlox statt Datums-/Titelkorpus) geladen
   werden kann — beides minimalinvasiv auf bestehenden Typen (`MeasurementResult`, `doneIDs`,
   `remaining(from:)`), keine neue Architektur.
2. FocusBlox-Export auf `Corpus.Entry`-Schema angleichen, damit derselbe Runner (Lab-App, Pacing,
   Fortsetzbarkeit) für beide Korpora funktioniert — kein Parallel-Code-Pfad.
3. Selbstkonsistenz-Auswertung als reine, auf dem Mac testbare Funktionen bauen (Vorlage aus
   `FocusBloxCalibrationTests`, aber **nicht** als XCTest-Lauf gegen das Modell — der Modellaufruf
   selbst bleibt in der Lab-App, [[feedback-phone-is-not-a-test-bench]]).
4. `FocusBloxCalibrationTests.swift` bleibt unverändert als historische Nulllinien-Referenz stehen —
   sie hat ihren Zweck (Report vom 2026-09-xx) bereits erfüllt und wird nicht weiterentwickelt.

### Dependencies

- **Reihenfolge:** Schritt 1 muss vor Schritt 2 abgeschlossen sein (Schritt 2 baut direkt auf der
  parametrisierten Korpus-/Lauf-Logik auf).
- **Upstream:** `SystemLanguageModel`, nur auf dem iPhone verfügbar (siehe „Die Messumgebung" oben).
- **Downstream:** `EnrichmentWriter.confidenceThreshold` (aktuell eine einzige globale Konstante für
  alle neun Felder, `EnrichmentWriter.swift:8`) — eine Design-Entscheidung, ob/wie ein neues Signal
  diese Schwelle ersetzt oder ergänzt, ist explizit **nicht** Teil dieser Spec, sondern eines
  Folge-Issues nach Messergebnis (DoD aus #65).

### Open Questions

- [ ] FocusBlox-Korpus-Format-Abgleich: Deckt `focusblox-corpus.json` (aktuell für die eigene
  `CorpusTask`-Struktur in `FocusBloxCalibrationTests`) alle Felder ab, die `Corpus.Entry` braucht
  (id/lang/text/date/…)? Wird in Schritt 2 beim Bau des Export-Skripts geklärt, nicht vorab.
- [ ] Stichprobengröße für Selbstkonsistenz (5 Läufe × wie viele Sätze) — Entscheidung für die Spec
  von Schritt 2, nicht für diese Analyse.
- [ ] Die im Issue-Text genannte `device-measure`-Zielbezeichnung existiert in `scripts/sim.sh` nicht
  (tatsächliche Ziele: `lab`, `lab-run`, `lab-fetch`) — Doku-Diskrepanz, wird bei Gelegenheit korrigiert,
  blockiert diesen Spike nicht.

## Risks & Considerations

- **Enthaltungs-Signal braucht eine signalfreie Teilmenge**, die für importance/urgency/duration im
  FocusBlox-Korpus noch nicht als solche markiert ist (anders als beim Datum, wo die 170 Kontrollsätze
  im Datums-/Titelkorpus bereits vorliegen). Muss entweder aus dem FocusBlox-Korpus per Wortliste
  abgeleitet oder neu aufgebaut werden — Kandidat für Regel-vor-Modell: eine Wortliste, die
  „enthält kein Dringlichkeits-/Dauer-Wort" entscheidet, ist selbst deterministisch baubar.
- **5 Läufe je Satz** bedeuten fünffache Messzeit gegenüber #67/#23 (dort einmal). Bei ~8,8 s/Satz
  (#67-Erfahrungswert) und Drosselung nach wenigen Aufrufen ist das ein mehrtägiger Lauf in Scheiben
  auf Hennings Alltagsgerät — Umfang und Stichprobengröße sind eine Entscheidung für die Spec, nicht
  für den Kontext.
- **Zweitmeinung (drittes Signal aus dem Issue) ist expliziter Nicht-Umfang** dieses Spikes (PO-Vorgabe
  in dieser Sitzung). Der Report muss das vermerken, damit #65 nicht fälschlich als vollständig
  beantwortet gilt.
- **DoD aus #65 fordert Folge-Issues** für die Konsequenzen — abhängig vom Messergebnis (Signal
  funktioniert → Schwelle ersetzen; kein Signal funktioniert → eine der Alternativen aus der
  Annahmen-Tabelle: Vorschlag statt Setzen, Feld aus Historie, Feld weglassen).
