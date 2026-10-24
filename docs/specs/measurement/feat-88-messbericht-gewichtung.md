---
entity_id: feat-88-messbericht-gewichtung
type: feature
created: 2026-10-24
updated: 2026-10-24
status: draft
---

# Spec: #88 Teil 1 — Messbericht mit Gewichtung nach Hennings Verteilung und Regel-Spalte

**Status:** draft · **Workflow:** feat-88-messbericht-gewichtung · **Erstellt:** 2026-10-24 · **Aktualisiert:** 2026-10-24

## Freigabe

- [ ] Freigegeben

## Problem
Der Bericht zu #67 (`docs/reference/date-title-fidelity.md`) nennt eine Gesamtzahl, die jeden Satz des
Messkorpus gleich zählt. Der Korpus hat aber 188 Sätze in der Form `standard` und je rund elf in den
anderen elf Formen; Hennings echte Verteilung ist eine andere (ein Drittel Stichwörter, nur 12 % mit
Zeitangabe, Angaben aus seinen 108 FocusBlox-Rohsätzen). Die Gesamtzahl sagt also nicht, wie das
Verfahren auf seinen Sätzen abschneidet. Zudem steht in „Nach Bauform“ nur das Modell: die Regel-Spalte
fehlt dort ganz, und beim Titel kommt `TitleRule` im Bericht nirgends vor. Das widerspricht der Regel
„jeder Bericht führt die Regel-Spalte“.

## Zweck
Der Bericht weist die Gesamtzahl zusätzlich nach Hennings Verteilung gewichtet aus, mit Regel-Spalte
neben dem Modell, und kennzeichnet ehrlich, woher die Gewichte stammen. Er gewichtet nur über die zwei
belegten Angaben (Stichwort ≈ 1/3, Zeitangabe ≈ 12 %), nie über alle zwölf Formen, weil für die übrigen
Formen keine Anteile existieren.

## Quelle
- **Datei:** `LooseEndsTests/DateTitleReportTests.swift`
- **Bezeichner:** `DateTitleReportTests` (`formSection`, neu: `weightedSection`), `FormTally`, `Report`
- **Gewichte:** `Measurement/Corpus.swift`, neuer Typ `Corpus.Weights`

## Acceptance Criteria

- **AC-1 Gewichte mit Quelle:** Given der Korpus-Code / When die Gewichte gelesen werden / Then stehen sie
  als benannte Konstanten in `Corpus.Weights` (`keywordShare = 1/3`, `timeShare = 0.12`) mit dem Vermerk
  „Angabe Henning aus 108 FocusBlox-Rohsätzen, nicht nachgezählt“. Eine Gewichtung über die zwölf Formen
  oder über Kreuzzellen (Stichwort × Zeitangabe) gibt es nicht.
- **AC-2 Gewichtete Titel-Zahl:** Given die Messläufe / When der Bericht gebaut wird / Then steht im neuen
  Abschnitt „Gewichtet nach Hennings Verteilung“ für „Titel ohne erfundene Fakten“ die Gesamtzahl
  `1/3 × Anteil(Form stichwort) + 2/3 × Anteil(alle übrigen Formen zusammen)`, für Modell und Regel
  (`TitleRule`) je eine Spalte.
- **AC-3 Gewichtete Datum-Zahl:** Given die Messläufe / When der Bericht gebaut wird / Then steht dort für
  „Datum richtig behandelt“ die Gesamtzahl `0,12 × Anteil(Datum exakt, Sätze mit Datum) + 0,88 ×
  Anteil(kein Datum erfunden, Sätze ohne Datum)`, für Modell und Regelparser je eine Spalte. Die Formel
  steht im Bericht.
- **AC-4 Leere Gruppe, keine stille Umnormierung:** Given eine Gruppe ohne Sätze / When der Bericht
  gebaut wird / Then zeigt ihre Zeile „–“ und die Gesamtzahl dieses Kriteriums lautet „– (Gruppe ohne
  Sätze, nicht gewichtet)“. Die übrigen Gewichte werden nie auf 1 hochgerechnet.
- **AC-5 Zählung als zweite Zeile (eingefroren):** Given die 287 FocusBlox-Titel / When der Bericht
  gebaut wird / Then steht unter jeder Gewichtszeile eine zweite Zeile „Zählung an 287 FocusBlox-Titeln,
  Stand 2026-10-24“ mit den regelbasiert gezählten Anteilen (Stichwort = höchstens 3 Wörter: 73,5 %;
  Zeitangabe über den Regelparser). Die Zahlen sind benannte Konstanten mit Messdatum (wie
  `FrozenDetector`), der Bericht liest die Datei nie live: sie liegt nur im Hauptordner, und ein Bericht,
  der vom Vorhandensein einer Datei abhängt, wäre in der CI nicht reproduzierbar (#99, #148). Die Zeile
  trägt die Hinweise: Titel, keine Rohsätze; Zählskript nicht im Repo, Zahlen nicht nachzählbar.
- **AC-6 Gewichte gekennzeichnet:** Given der Abschnitt / When er gelesen wird / Then steht bei den
  Gewichten „Angabe Henning, nicht nachgezählt“, und jede Form ohne belegten Anteil ist als „kein
  Gewicht“ aufgeführt (alle elf Formen außer `stichwort` für das Titel-Kriterium; für das Datum-Kriterium
  zählt das Merkmal „Zeitangabe“, keine Form).
- **AC-7 Regel-Spalten in „Nach Bauform“:** Given der Abschnitt „Nach Bauform“ / When der Bericht gebaut
  wird / Then hat jede Formzeile neben den Modellzahlen die Regelzahlen: Datum exakt und Datum erfunden
  des Regelparsers und „Titel ohne erfundene Fakten“ von `TitleRule` (gemessen mit denselben
  `TitleCheck`-Prüfungen am Titel, den `TitleRule` aus dem Rohtext bildet). Kriterien ohne Sätze zeigen
  „–“ wie bisher.
- **AC-8 Bericht bleibt reproduzierbar und lesbar:** Given der neu erzeugte Bericht / When
  `DateTitleReportTests` und `scripts/test_compare_reports.py` laufen / Then ist der Bericht
  deterministisch (fester Kalender, feste Bezugstage wie #148), `compare_reports.py` liest ihn
  unverändert, und die bestehenden Abschnittsüberschriften behalten Namen und Reihenfolge; der neue
  Abschnitt steht nach „Nach Bauform“ und vor „Titel“.
- **AC-9 Bestehende Tests:** Given der Funktionsumfang / When Unit-Tests laufen / Then bleiben alle grün,
  der eingecheckte Bericht wird nur über den bestehenden Weg neu erzeugt (#543, #147), nie bei jedem
  Lauf ohne Prüfung.

## Nicht in diesem Schnitt
- **Teil 2** von #88 (echte Rohsätze aus Loose Ends, Wahrheit je Satz, Messung gegen sie): wartet auf
  Hennings Wort und braucht sein Gerät.
- Gewichte für die übrigen elf Formen: es gibt keine Anteile; sie entstehen erst durch Teil 2.
- Neue Messläufe auf dem iPhone: der Schnitt rechnet nur über vorhandene Läufe und den Korpus.
- Änderungen an `compare_reports.py`: es darf den neuen Abschnitt ignorieren, solange es nicht stört.

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `Corpus`, `Corpus.Entry.form`, `Corpus.forms` | Struktur | Gruppen aus der Form (`stichwort` gegen alle übrigen) |
| `TitleRule.title(from:reference:calendar:)` | Funktion | Regelweg des Titels für die Regel-Spalte |
| `TitleCheck` (`inventedNumbers`, `alteredNames`, in `Measurement/Corpus.swift`) | Funktion | gleiche Prüfung für Modell- und Regeltitel |
| `DateExpressionParser`, `TimeExpressionParser` | Funktion | Regelparser-Zahlen je Form; Zeitangabe-Zählung an den FocusBlox-Titeln |
| `scripts/compare_reports.py` | Leser | liest den Bericht, darf nicht brechen |

## Umfang

### Betroffene Dateien

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `LooseEndsTests/DateTitleReportTests.swift` | MODIFY | `FormTally` um Regelzahlen erweitern, `weightedSection`, Regel-Spalten in `formSection`, Zählung der FocusBlox-Titel |
| `Measurement/Corpus.swift` | MODIFY | `Corpus.Weights` mit den zwei Gewichten, der eingefrorenen Zählung und ihrer Quelle |
| `LooseEndsTests/WeightedReportTests.swift` | CREATE | Tests der Rechnung: Gewichtssumme 1, leere Gruppe, keine Umnormierung, Zählung fehlt |
| `docs/reference/date-title-fidelity.md` | MODIFY | neu erzeugter Bericht |

### Geschätzter Umfang
- Dateien: 4 (innerhalb der 4–5-Dateien-Grenze)
- Zeilen: etwa +150 / −10 (innerhalb ±250)

## Technische Umsetzung
Regeln vor Modell: reine Rechnung über vorhandene Zähler, kein Modell, keine neue Messung. Die Gesamtzahl
ist ein gewichtetes Mittel über **zwei Gruppen je Kriterium**. Für den Titel: Gruppe `stichwort`
(Gewicht 1/3) gegen alle übrigen Formen zusammen (2/3). Für das Datum: Sätze mit Datum (0,12) gegen
Sätze ohne Datum (0,88), wobei die zweite Gruppe „kein Datum erfunden“ misst. Kreuzzellen entfallen,
weil sie Unabhängigkeit der beiden Merkmale voraussetzten, die nirgends belegt ist.

`FormTally` bekommt Regelzähler (`ruleDate`, `ruleInvented`, `ruleFacts`), befüllt in
`scoreRuleParser` und einer neuen Titel-Regelauswertung über den ganzen Korpus (`TitleRule` auf
`entry.text`, danach dieselben `TitleCheck`-Prüfungen). Die Gewichtsrechnung ist eine reine Funktion
`weighted(_ groups: [(weight: Double, tally: Tally)]) -> Double?`; sie liefert `nil`, sobald eine Gruppe
leer ist, und der Bericht schreibt dann „–“. So ist Umnormieren konstruktiv ausgeschlossen. Die
Zählung der FocusBlox-Titel (einmal am 2026-10-24 mit denselben Regeln gezählt) steht als eingefrorene
Konstanten `Corpus.Weights.counted` mit Messdatum im Code; das Zählskript liegt nicht im Repo, die
Regeln stehen in der Konstante beschrieben. Der eingecheckte Bericht entsteht weiter nur in `buildReport` (#543, #147).

**Alternativen:** (1) Spanne statt Gewicht (schlechteste/beste Form): nichts geschätzt, aber keine
Gesamtzahl nach seiner Verteilung — von Henning zugunsten von Gewichten mit Gegenzählung verworfen.
(2) Nur Zählung der 287 Titel: nachprüfbar, aber Titel statt Rohsätze. (3) Teil 2 vorziehen: belegt
die Gewichte, braucht sein Gerät und „jetzt ist ein Test möglich“. Keine ADR wird gekippt.

## Testplan

### Automatisierte Tests (TDD RED)
- [ ] `WeightedReportTests.weightsAreHennings` — GIVEN `Corpus.Weights` / WHEN gelesen / THEN
  `keywordShare == 1/3`, `timeShare == 0.12`, die Quelle ist benannt (AC-1, AC-6).
- [ ] `WeightedReportTests.titleWeighting` — GIVEN Tallies Stichwort 100 %, übrige 90 % / WHEN
  gewichtet / THEN `1/3 + 2/3 × 0,9 = 93,3 %` (AC-2).
- [ ] `WeightedReportTests.dateWeighting` — GIVEN exakt 50 %, erfunden-frei 100 % / WHEN gewichtet /
  THEN `0,12 × 0,5 + 0,88 × 1 = 94,0 %` (AC-3).
- [ ] `WeightedReportTests.emptyGroupIsNotRenormalised` — GIVEN eine leere Gruppe / WHEN gewichtet /
  THEN `nil`, der Abschnitt zeigt „–“ und den Wortlaut „(Gruppe ohne Sätze, nicht gewichtet)“, nicht den Mittelwert der anderen (AC-4).
- [ ] `WeightedReportTests.countLine` — GIVEN die eingefrorene Zählung / WHEN der Abschnitt gebaut wird /
  THEN steht die zweite Zeile mit N = 287, Messdatum und dem Hinweis „Titel, keine Rohsätze“ unter
  beiden Gewichtszeilen (AC-5).
- [ ] `DateTitleReportTests` (Form-Abschnitt erweitert) — GIVEN gefüllte Tallies / WHEN
  `formSection` gebaut wird / THEN jede Formzeile trägt die Regelzahlen, leere Kriterien „–“ (AC-7).
- [ ] `DateTitleReportTests.buildReport` und `scripts/test_compare_reports.py` — GIVEN der neue Bericht /
  WHEN beide laufen / THEN grün, Überschriften und Reihenfolge der alten Abschnitte unverändert (AC-8, AC-9).

Kein UI-Test: kein Produktcode, keine View betroffen. Geräteliste: „Kein Pfad der Geräteliste berührt.“
Abnahme Stufe 2 (Simulator-Beleg): die Unit-Tests laufen im Simulator (`sim.sh sim-unit`), der Bericht
wird dort erzeugt und gelesen; es gibt keine Bedienoberfläche zum Durchspielen.

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt, belegt durch die genannten Tests
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh sim-unit`)
- [ ] `docs/reference/date-title-fidelity.md` neu erzeugt, geprüft und mitcommittet
- [ ] CI grün, PR mit `Closes` auf das Teilticket von #88, gemergt
- [ ] Hennings Hauptordner nachgezogen und Projekt neu erzeugt
- [ ] Teil 2 von #88 bleibt als offener Rest im Issue benannt

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Reine Berichtsrechnung im Test-Target über vorhandene Zähler; kein neuer
  Architekturbaustein, keine Abhängigkeit, kein Eingriff in Produktcode. Schnitt 1 von #82
  (`issue-82-satzformen`) bleibt unberührt.

## Changelog

- 2026-10-24: Spec aus dem Analyse-Kontext (`docs/context/feat-88-messbericht-gewichtung.md`) erstellt;
  Entscheidung Henning (2026-10-24): Gewichte = seine Angaben, gekennzeichnet, mit Zählung als zweiter Zeile.
