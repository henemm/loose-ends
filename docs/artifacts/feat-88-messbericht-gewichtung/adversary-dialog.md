# Adversary Dialog — feat-88-messbericht-gewichtung
Spec: docs/specs/measurement/feat-88-messbericht-gewichtung.md
Datum: 2026-10-24 09:10

## Checkliste
- [x] **AC-1 Gewichte mit Quelle:** `Corpus.Weights` trägt `keywordShare = 1/3`, `timeShare = 0.12` und den Vermerk „Angabe Henning aus 108 FocusBlox-Rohsätzen, nicht nachgezählt“. Keine Gewichtung über Formen oder Kreuzzellen.
- [x] **AC-2 Gewichtete Titel-Zahl:** Modell 99,8 %, Regel 100,0 % (1/3 × Stichwort + 2/3 × übrige Formen).
- [x] **AC-3 Gewichtete Datum-Zahl:** Modell 10,0 %, Regel 99,9 %; Formel steht im Bericht.
- [x] **AC-4 Leere Gruppe, keine stille Umnormierung:** `weighted` liefert `nil`, Bericht zeigt „– (Gruppe ohne Sätze, nicht gewichtet)“.
- [x] **AC-5 Zählung als zweite Zeile (eingefroren):** Konstante `counted` mit 287 Titeln und Messdatum 2026-10-24, kein Dateizugriff; Zeile trägt die Pflichthinweise.
- [x] **AC-6 Gewichte gekennzeichnet:** „Angabe Henning, nicht nachgezählt“; alle elf übrigen Formen als „kein Gewicht“.
- [x] **AC-7 Regel-Spalten in „Nach Bauform“:** Regelzahlen je Formzeile, leere Kriterien „–“.
- [x] **AC-8 Bericht bleibt reproduzierbar und lesbar:** fester Kalender und Bezugstag, `test_compare_reports.py` 13 Tests OK, Überschriften und Reihenfolge der alten Abschnitte unverändert.
- [x] **AC-9 Bestehende Tests:** voller `sim-unit`-Lauf auf dem aufgesetzten Stand (96c7d20, mit #663): Exit 0, „Test Succeeded“, kein ✘, 976 ✔; der Knäuel-Test ist grün.

## Dialog

### Runde 1
**Adversary:**
Gewichte und Formel: Die Gewichte stehen als Konstanten, die zweite Gruppe ist immer `1 − Anteil`, die Summe ist konstruktiv 1. Es gibt keine Schleife mit Gewichten über `Corpus.forms` und keine Kreuzzelle.
Code reference: Measurement/Corpus.swift:27-51
Code reference: LooseEndsTests/DateTitleReportTests.swift:316-321

Leere Gruppe: `weighted` liefert `nil`, sobald eine Gruppe 0 Sätze hat; nirgends wird umnormiert.
Code reference: LooseEndsTests/DateTitleReportTests.swift:350-353

Eingefrorene Zählung: Konstante `Count(titles: 287, keywordTitles: 211, timeTitles: 1, measured: "2026-10-24")`, 211/287 = 73,5 %, kein `Data(contentsOf:)`, kein `FileManager`.
Code reference: Measurement/Corpus.swift:50

Regel-Spalte: `scoreTitleRule` nutzt dieselben `TitleCheck`-Prüfungen wie das Modell. Die Nenner sind ungleich (Regel 307 + 12, Modell 299 + 12), weil die 8 Wiederholungssätze nur bei der Regel zählen. Das entspricht der Spec, steht aber nirgends im Bericht (F002).
Code reference: LooseEndsTests/DateTitleReportTests.swift:190-198

Reihenfolge und Lesbarkeit: neuer Abschnitt zwischen „Nach Bauform“ und „Titel“, `test_compare_reports.py` grün.
Code reference: LooseEndsTests/DateTitleReportTests.swift:205-209

Befund F001 (MEDIUM): Die Zählzeile „0,3 % mit Zeitangabe“ steht neben dem Gewicht „12 %“ ohne Absolutzahl und ohne Grund. Ein Leser kann sie als Widerlegung der 12 % lesen. Sie ist eine Titel-Zahl, die Titel enthalten Zeitangaben kaum.
Befund F002 (LOW): Die Satzzahlen 307 und 299 sind nicht erklärt; „Datum erfunden“ in „Nach Bauform“ (Erfindungsquote) und „kein Datum erfunden“ im gewichteten Abschnitt (Treffer) zählen in entgegengesetzter Richtung.
Befund F003 (MEDIUM): Der Test `Since when it is the Knäuel (#647)` ist lokal rot. Er liegt nicht im Diff gegen 96f79e8; `Knaeuel.swift:322-336` nutzt `String(localized:)` und hängt damit an der Systemsprache des Simulators (de-DE), die CI läuft auf Englisch. Die Ursache ist plausibel, aber nicht durch einen Lauf unter englischer Sprache bewiesen.
Code reference: LooseEnds/Views/Knaeuel.swift:322-336

**Implementierer:**
F001 behoben: Die Zählzeile nennt „1 von 287“ (aus `counted.timeTitles` und `counted.titles`) und den Grund „Titel enthalten Zeitangaben kaum, die Zahl ist deshalb keine Gegenprobe der 12 % der Rohsätze“. Die Pflichthinweise bleiben wortgleich.
F002 behoben: Fußnotenblock am Ende des Abschnitts. Er nennt 307 plus 12 gegen 299 plus 12 mit den 8 Wiederholungssätzen und die entgegengesetzte Zählrichtung beider Spalten. Alle Zahlen sind berechnet, nicht fest eingetippt.
Code reference: LooseEndsTests/DateTitleReportTests.swift (weightedSection)
Bericht über `buildReport` neu erzeugt, danach grün. Voller `sim-unit`: 968 bestanden, genau ein Test rot (Knäuel).
F003: nicht in dieser Änderung behoben (Scoping, anderes Ticket). Ticket #659 angelegt. Offen bleibt der Gegenlauf unter englischer Simulatorsprache.

### Runde 2
**Adversary:**
Zweiter Versuch, die Befunde zu widerlegen: Es gibt keine versteckte Gewichtung über Formen (die einzige Schleife über `Corpus.forms` erzeugt die „kein Gewicht“-Zeilen). Die Handrechnung stimmt: Titel Modell 1/3 × 12/12 + 2/3 × 298/299 = 99,8 %; Datum Modell 0,12 × 69/139 + 0,88 × 8/172 = 10,0 %. Die Summe der Regel-Zellen in „Nach Bauform“ ergibt 138 von 139 (99,3 %) und stimmt mit „Exakt getroffen“ überein. Das Datum-Kriterium nutzt für Modell und Regel dieselben 139 und 172 Sätze und ist damit fair. Gerundet wird erst bei der Ausgabe.
Code reference: LooseEndsTests/DateTitleReportTests.swift:343-344
Code reference: LooseEndsTests/WeightedReportTests.swift:1-131
Code reference: docs/reference/date-title-fidelity.md:65-120
Restrisiko (LOW): Der Text „0,12 ×“ und „12 %“ im Abschnitt sind Literale, gerechnet wird mit `Corpus.Weights.timeShare`. Wird die Konstante geändert, stimmt der Text nicht mehr. Kein Fehler jetzt.

**Implementierer:**
Das Restrisiko ist bekannt und bleibt: Die Konstante ist eine Angabe von Henning und ändert sich nur durch Teil 2 von #88; dann wird der Text mit angefasst.

### Runde 3
**Adversary:**
Widerlegungsversuch AC-9 am Output `test-green-output.txt` (1705 Zeilen, Lauf 2026-10-24 11:36 auf 96c7d20 plus Arbeitsstand): kein ✘ (0 Treffer), „Test Succeeded“ (Zeile 1698), „Unit-Tests bestanden“. Der frühere Rotfall „Since when it is the Knäuel (#647)“ steht grün (Zeile 865), die Suite „Das Knäuel (#643)“ ist passed. Übersprungen sind nur die Messstrecke SelfConsistencyReportTests (selfconsistency-run.json fehlt) und die zwei Sprach-Latenztests (de_DE im Simulator nicht verfügbar); keiner gehört zur Änderung. Der Diff gegen origin/main (Stat) berührt nur Berichtstests (DateTitleReportTests, WeightedReportTests), `Measurement/Corpus.swift`, den Bericht sowie Workflow-Dokumente und Spec; kein Produktcode, `Knaeuel.swift` ist nicht mehr im Diff. AC-1 bis AC-8 nach dem Aufsetzen: Suite „Bericht: Gewichtung nach Hennings Verteilung“ mit allen 8 Tests grün (Zeilen 1687-1696), Suite DateTitleReportTests passed (Zeile 661), `date-title-fidelity.md` ist im Arbeitsstand verändert und wird im Lauf aus denselben Tests erzeugt. Einschränkung: Ich habe den Lauf nicht neu gestartet (Testsperre, Auftrag); ausgewertet ist der vorhandene Output.
Code reference: Measurement/Corpus.swift:1-26
Code reference: LooseEndsTests/DateTitleReportTests.swift:343-344
Code reference: LooseEndsTests/WeightedReportTests.swift:1-131
Code reference: docs/reference/date-title-fidelity.md:65-120

**Implementierer:**
Nichts zu ändern. Der Rotfall lag nicht in dieser Änderung und ist mit #663 (#659) auf main behoben.

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Keine Produktions-Schreibstellen: der Schnitt ändert nur Berichtscode im Test-Target und Konstanten in `Measurement/`.

## Verdict
**VERIFIED**

Begründung: AC-1 bis AC-9 belegt. Der volle Lauf auf dem aufgesetzten Stand ist grün (kein ✘, 976 bestanden, Knäuel-Test grün). Übersprungen sind nur drei Messstrecken-Tests ohne Bezug zur Änderung (Selbstkonsistenz-Lauf fehlt, Sprache de_DE im Simulator). Der Diff berührt keinen Produktcode.

## Geprüfte Dateien

- sha256:e1cc2970fcc7a30ff781fcef96bda523a4b89921fc35f3c742dce5eb93f2aba3  LooseEnds/Views/Knaeuel.swift
- sha256:2e47564b7e18f4a6b671373d0181295186a826f0c9b5b0de41fcbe5f889af657  LooseEndsTests/DateTitleReportTests.swift
- sha256:41358e571c516d0a7583914d3d8767ead1094edf19c36ef596a97f74b4d8942e  LooseEndsTests/WeightedReportTests.swift
- sha256:bda31ebbc2db07375d794e908c304923860faa0343b254ef9233c5333cc092ee  Measurement/Corpus.swift
- sha256:2d26a6c5e20349e4eb729c4926faca3e3d9de9a908e93120aecf3f5d6588ee34  docs/reference/date-title-fidelity.md

## Prüfbasis

- base: 96f79e8be9c336d4bd7b17d5f82fde53582e7f4f
- blob:7a88b3862a37e0150a6343f214587b239b0f8f6b  LooseEnds/Views/Knaeuel.swift
- blob:20375c95e1f6615160756ffb3458f0a3d459cf9c  LooseEndsTests/DateTitleReportTests.swift
- blob:f44ea1765d4f90fffdeca6b28b2cf10cd7408af5  LooseEndsTests/WeightedReportTests.swift
- blob:610b72da95c8e0e323485e5a77d9d3d4b4075ef9  Measurement/Corpus.swift
- blob:fa5cf6a802cad76120b3db17c9b7f9bb0e7c14f6  docs/reference/date-title-fidelity.md

## Geprüfte Dateien

- sha256:95f33362474c1f87ac2f2e2e81a2ad0e674bc976dab3f652d03c9e7653357bdf  LooseEnds/Views/Knaeuel.swift
- sha256:2e47564b7e18f4a6b671373d0181295186a826f0c9b5b0de41fcbe5f889af657  LooseEndsTests/DateTitleReportTests.swift
- sha256:41358e571c516d0a7583914d3d8767ead1094edf19c36ef596a97f74b4d8942e  LooseEndsTests/WeightedReportTests.swift
- sha256:bda31ebbc2db07375d794e908c304923860faa0343b254ef9233c5333cc092ee  Measurement/Corpus.swift
- sha256:2d26a6c5e20349e4eb729c4926faca3e3d9de9a908e93120aecf3f5d6588ee34  docs/reference/date-title-fidelity.md

## Prüfbasis

- base: 96c7d2060f45b86ce9b25f87a8e66310980f766e
- blob:d4aba68b85264a8b6928bdcc283c8572f0890f8a  LooseEnds/Views/Knaeuel.swift
- blob:20375c95e1f6615160756ffb3458f0a3d459cf9c  LooseEndsTests/DateTitleReportTests.swift
- blob:f44ea1765d4f90fffdeca6b28b2cf10cd7408af5  LooseEndsTests/WeightedReportTests.swift
- blob:610b72da95c8e0e323485e5a77d9d3d4b4075ef9  Measurement/Corpus.swift
- blob:fa5cf6a802cad76120b3db17c9b7f9bb0e7c14f6  docs/reference/date-title-fidelity.md

## Geprüfte Dateien

- sha256:95f33362474c1f87ac2f2e2e81a2ad0e674bc976dab3f652d03c9e7653357bdf  LooseEnds/Views/Knaeuel.swift
- sha256:2e47564b7e18f4a6b671373d0181295186a826f0c9b5b0de41fcbe5f889af657  LooseEndsTests/DateTitleReportTests.swift
- sha256:41358e571c516d0a7583914d3d8767ead1094edf19c36ef596a97f74b4d8942e  LooseEndsTests/WeightedReportTests.swift
- sha256:bda31ebbc2db07375d794e908c304923860faa0343b254ef9233c5333cc092ee  Measurement/Corpus.swift
- sha256:2d26a6c5e20349e4eb729c4926faca3e3d9de9a908e93120aecf3f5d6588ee34  docs/reference/date-title-fidelity.md

## Prüfbasis

- base: 96c7d2060f45b86ce9b25f87a8e66310980f766e
- blob:d4aba68b85264a8b6928bdcc283c8572f0890f8a  LooseEnds/Views/Knaeuel.swift
- blob:20375c95e1f6615160756ffb3458f0a3d459cf9c  LooseEndsTests/DateTitleReportTests.swift
- blob:f44ea1765d4f90fffdeca6b28b2cf10cd7408af5  LooseEndsTests/WeightedReportTests.swift
- blob:610b72da95c8e0e323485e5a77d9d3d4b4075ef9  Measurement/Corpus.swift
- blob:fa5cf6a802cad76120b3db17c9b7f9bb0e7c14f6  docs/reference/date-title-fidelity.md
