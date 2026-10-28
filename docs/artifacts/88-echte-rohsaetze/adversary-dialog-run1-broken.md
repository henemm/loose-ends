# Adversary Dialog — 88-echte-rohsaetze
Spec: docs/specs/measurement/feat-88-echte-rohsaetze.md
Datum: 2026-10-28 13:53

## Checkliste
- [x] **AC-1:** Drittes Format im Einleser. Given eine Datei im Format oben, deren oberster Wert eine Liste von Objekten mit `rawText` ist / When `Corpus.load(fileName:)` sie liest / Then liefert es je entduplizierten Satz ein `Corpus.Entry` mit `id` aus der Datei, `lang` (ohne Angabe `de`) und `text` gleich `rawText` unverändert. Erkannt wird am Dateiinhalt, nicht am Dateinamen.
- [ ] **AC-2:** Bisherige Korpusse unverändert. Given `date-title-corpus`, `latency-corpus`, der FocusBlox-Korpus und `textform-corpus` / When sie über `Corpus.load` gelesen werden / Then sind Anzahl, Kennungen und Texte genauso wie vor der Änderung; die Erkennung des neuen Formats greift bei keinem von ihnen.
- [x] **AC-3:** Entduplizierung. Given Kunstdaten mit drei Sätzen gleicher Wortmenge (andere Groß-/Kleinschreibung und Satzzeichen) und zwei einzelnen Sätzen / When entdupliziert wird / Then bleiben drei Sätze, der Vertreter der Dublettengruppe ist der erste mit Korrektur (sonst der erste der Datei), und die Zählung nennt 5 vor und 3 nach der Entduplizierung.
- [x] **AC-4:** Wahrheitsstufen. Given Kunstsätze mit `titleUser` verschieden von `titleBefore`, mit `titleUser` gleich `titleBefore`, ohne `titleUser`, sowie mit und ohne `durationUser` / When eingeteilt wird / Then zählt Titel „korrigiert“ nur im ersten Fall, die beiden anderen zählen als „nicht korrigiert“, Dauer „korrigiert“ nur bei gesetztem `durationUser`; kein Satz fällt in beide Gruppen eines Kriteriums.
- [ ] **AC-5:** Titel-Spalte mit Regel daneben. Given `[MeasurementResult]` zu Kunstsätzen und die Regel als Closure / When ausgewertet wird / Then steht in einer Zeile der Anteil der korrigierten Sätze, deren Modelltitel nach `RawTextWords` (Wortfolge, normalisiert) gleich `titleUser` ist, und daneben derselbe Anteil für den Titel der Regel aus dem Rohtext, jeweils über dieselben korrigierten Sätze, die im Lauf vorkommen. Fehlgeschlagene Aufrufe (`error` gesetzt) zählen als nicht getroffen und werden mit ihrer Zahl ausgewiesen. Die Gruppe „nicht korrigiert“ steht mit ihrer Zahl und dem Vermerk „kein Beleg, nicht gewertet“ in einer eigenen Zeile.
- [x] **AC-6:** Dauer-Spalte mit Regel daneben. Given Ergebnisse über mehrere Läufe und die Dauerregel als Closure / When ausgewertet wird / Then steht der Anteil der Sätze mit `durationUser`, deren Mehrheitsdauer (`SelfConsistency.majority`, fehlgeschlagene Aufrufe ausgenommen) gleich `durationUser` ist, und daneben der Anteil für die Dauer der Regel; Sätze ohne `durationUser` stehen als „nicht korrigiert, kein Beleg“ mit Zahl daneben und werden nie gewertet.
- [x] **AC-7:** Mindestmenge, ehrlich. Given weniger als 30 korrigierte Sätze eines Kriteriums im Lauf / When der Bericht gebildet wird / Then steht in dieser Zeile „zu wenig (n von mindestens 30)“ statt einer Rate, bei Modell und Regel; ab 30 steht die Rate. Die Mindestmenge ist als eine benannte Konstante festgelegt.
- [x] **AC-8:** Leere Gruppe, keine erfundene Zahl. Given ein Kriterium ohne korrigierte Sätze oder ohne Ergebnisse / When ausgewertet wird / Then zeigt die Zelle „–“ statt 0 %.
- [x] **AC-9:** Nur Zählungen, nie Sätze. Given Kunstdaten mit erkennbaren Marker-Wörtern in `rawText`, `titleBefore` und `titleUser` / When der Bericht gerendert wird / Then enthält die Ausgabe keinen dieser Texte, weder ganz noch in Teilen; nur Zahlen, Raten und feste Überschriften.
- [x] **AC-10:** Getrennter Berichtsabschnitt, laut übersprungen. Given `RawSentenceReportTests` mit dem Gate `loose-ends-rawtexts.json` / When die Datei fehlt / Then wird die Suite übersprungen und das laut benannt (#149, Pfad über `MeasurementData`, Suche im Arbeitsstand, dann im Hauptordner); liegt sie samt Ergebnisdatei vor, gibt der Test den Abschnitt „Echte Rohsätze“ getrennt vom FocusBlox-Teil nach stdout aus. In keinem Test läuft ein Modellaufruf.
- [x] **AC-11:** Gate und Ausschluss. Given `scripts/measurement_status.py` und `.gitignore` / When geprüft wird / Then führt `GATES` den Eintrag `loose-ends-rawtexts.json` mit der neuen Suite, stimmt mit dem Swift-Code überein (`test_every_gate_is_listed_and_nothing_else`), und `.gitignore` enthält `docs/reference/loose-ends-rawtexts.json`.

## Dialog

### Runde 1
**Adversary:** Ausgefuehrt: voller Lauf `./scripts/sim.sh sim-unit` (Log: docs/artifacts/88-echte-rohsaetze/adversary-full-run.log, Test Succeeded, enthaelt meine temporaere Probe-Suite, danach geloescht), `python3 -m unittest scripts.test_measurement_status` (20 OK), `scripts/measurement_status.py` (6 Gates, RawSentenceReportTests als uebersprungen benannt). Probe-Tests (Wegwerf, entfernt) gegen `Corpus.entries(from:)`:
- Leere Liste: 0 Eintraege, kein Wurf. Kaputtes JSON: wirft. Textform-Objekt: unveraendert. Liste ohne rawText im ersten Objekt: faellt auf Entry-Dekodierung (wirft nur wegen fehlendem lang, bestehendes Verhalten).
- ECHTER FocusBlox-Korpus (287 Eintraege, jeder hat `rawText`, kein `titleBefore`): `Corpus.entries` wirft `keyNotFound titleBefore`. Der Laeufer ruft `try? Corpus.load(fileName: corpusFileName)` mit Rueckfall `[]` (LooseEndsLab/MeasurementRunner.swift:63); `--corpus focusblox-corpus` ist ein dokumentierter Weg (CorpusTests.swift:167). Folge: stiller leerer Korpus (Probe lab-style count = 0). AC-2 verletzt. Der Test `otherCorporaUnchanged` prueft FocusBlox nicht, daher gruen.
- Leere Wortmenge: `?!`, `...`, leerer Text fallen zusammen (kept a1,d4 von 4), Measurement/RawSentenceColumn.swift:68.
- Titel: `titleUser = ""` gilt als korrigiert und ein Lauf mit Fehler zaehlt als leerer Titel, also als Modelltreffer: modelHits=1 bei nur fehlgeschlagenem Lauf (RawSentenceColumn.swift:99-102). AC-5 verlangt: fehlgeschlagene Aufrufe zaehlen als nicht getroffen.
- Titelmehrheit: 1 richtiger Lauf gegen 2 fehlgeschlagene = Fehltreffer (Fehler stimmen als leerer Titel ab), waehrend die Dauer Fehler ausnimmt (AC-6). Uneinheitlich, nicht spezifiziert.
- Render: 29 -> "zu wenig (29 von mindestens 30)", 30 -> Rate, 0 -> Strich; 5/40 = 12 %, 1/40 = 2 %. Render nimmt nur Ints, keine Satztexte. Dublettenvertreter: erster mit Korrektur (b2 mit Dauer vor spaeterem c3 mit Titel).
- Gate: Python-GATES und Swift-Suite stimmen (unittest gruen), Ausschluss-Zeile in der Ignore-Datei vorhanden.
**Implementierer:** (nicht beteiligt; Befunde gehen an den Auftraggeber)

### Runde 2
**Adversary:** Nachpruefung mit Quelltext: Measurement/Corpus.swift:159 prueft nur `list.first?["rawText"] != nil`; der FocusBlox-Korpus erfuellt das. Eine Pflichtfeldpruefung (`titleBefore` und `capturedAt`) oder ein Rueckfall auf `[Entry]` bei Dekodierfehler wuerde AC-2 retten. AC-1 bewiesen (thirdFormatLoads). AC-3 bewiesen (duplicatesFoldWithCounts, 5 vor und 3 nach). AC-4 bewiesen (truthTiers). AC-5 nicht angehakt: Spalten und gemeinsamer Nenner stimmen, aber der Fehlerfall mit leerem titleUser verfehlt die Vorgabe (F002). AC-6 bewiesen. AC-7/8/9 bewiesen (Tests plus Probe). AC-10: Suite uebersprungen und laut benannt, kein Modellaufruf im Code. AC-11 bewiesen. Gesamt: AC-2 DISPROVEN, AC-5 teilweise.
**Implementierer:** (nicht beteiligt)


## Findings

Finding:
  ID: F001
  Severity: HIGH
  Category: regression
  Code reference: Measurement/Corpus.swift:159
  Description: Die Formaterkennung greift bei jeder Liste, deren erstes Objekt `rawText` traegt. Der FocusBlox-Korpus (287 Eintraege, jeder mit rawText, ohne titleBefore/capturedAt) wird in RawSentenceColumn.decode gelenkt und wirft keyNotFound titleBefore.
  Spec requirement: AC-2 — FocusBlox-Korpus ueber Corpus.load wie vor der Aenderung; die Erkennung des neuen Formats greift bei keinem der Korpusse.
  Conflict: Probe Corpus.entries(from: echter FocusBlox-Korpus) wirft; der Laeufer (LooseEndsLab/MeasurementRunner.swift:63, try? mit Rueckfall leer) bekommt still 0 Saetze bei --corpus focusblox-corpus. otherCorporaUnchanged (LooseEndsTests/RawSentenceReportTests.swift:55) prueft FocusBlox nicht.
  Remediation: Erkennung an Pflichtfeldern festmachen (erstes Objekt hat rawText UND titleBefore UND capturedAt) oder bei Dekodierfehler auf [Entry] zurueckfallen; Test mit FocusBlox-geformter Kunstzeile hinzufuegen.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: Measurement/RawSentenceColumn.swift:100
  Description: Ein fehlgeschlagener Lauf wird als leerer Titel gewertet. Ist titleUser leer oder nur Satzzeichen (gilt als korrigiert, Zeile 24), ist die Wahrheit ebenfalls leer und der Fehlerlauf zaehlt als Modelltreffer.
  Spec requirement: AC-5 — fehlgeschlagene Aufrufe zaehlen als nicht getroffen.
  Conflict: Probe: titleUser leer, einziger Lauf mit error -> corrected=1, modelHits=1. Bei 1 richtigem gegen 2 fehlgeschlagene Laeufe gewinnen die Fehler (modelHits=0), waehrend durationRow Fehler ausnimmt.
  Remediation: Fehlerlaeufe aus der Mehrheitsbildung ausnehmen und leeren titleUser nicht als Korrektur zaehlen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: Measurement/RawSentenceColumn.swift:68
  Description: Saetze ohne Woerter (leer, nur Satzzeichen) haben dieselbe leere Wortmenge und werden zu einem zusammengefasst.
  Spec requirement: AC-3 — Saetze mit gleicher Wortmenge falten.
  Conflict: Probe: "?!", "..." und leerer Text -> nur einer bleibt (kept a1,d4 von 4). Streng nach Spec, aber verschiedene Saetze werden vermischt.
  Remediation: Saetze mit leerer Wortmenge nicht falten.

## Bestaetigungen

Confirmation:
  AC: AC-1
  Code reference: Measurement/Corpus.swift:154
  Evidence: thirdFormatLoads gruen; id, lang (Standard de) und text unveraendert, Erkennung am Inhalt.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Measurement/RawSentenceColumn.swift:64
  Evidence: duplicatesFoldWithCounts, 5 vor und 3 nach, Vertreter mit Korrektur; Probe: Dauer-Korrektur vor spaeterer Titel-Korrektur bleibt Vertreter.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Measurement/RawSentenceColumn.swift:81
  Evidence: truthTiers, keine Doppelzaehlung.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Measurement/RawSentenceColumn.swift:110
  Evidence: durationColumnWithRule; Fehler ausgenommen, Regel ueber dieselben Saetze.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Measurement/RawSentenceColumn.swift:141
  Evidence: 29 -> zu wenig, 30 -> Rate, 0 -> Strich (AC-8), Konstante minimumCorrected = 30.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Measurement/RawSentenceColumn.swift:125
  Evidence: render erhaelt nur Int-Zaehlungen, kein String-Parameter; reportNeverContainsSentences gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: Measurement/RawSentenceColumn.swift:7
  Evidence: Suite gesperrt; measurement_status.py nennt RawSentenceReportTests als uebersprungen; kein Modellaufruf im Code.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: Measurement/RawSentenceColumn.swift:9
  Evidence: test_measurement_status 20 OK, GATES-Eintrag und Ausschluss-Zeile vorhanden.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Verdachtsfeld ohne Produktionsschreibstelle: die Messcode-Dateien unter Measurement/ schreiben nichts in den Produktpfad. Zeile titleCorrected: Bedingung davor = titleUser gesetzt und Wortfolge verschieden von titleBefore; Test fuer diesen Weg = RawSentenceColumnTests.truthTiers (nicht fuer leeren titleUser, siehe F002).

## Verdict

VERDICT: BROKEN

Begruendung: AC-2 ist verletzt (F001, HIGH): Die neue Formaterkennung faengt den echten FocusBlox-Korpus ab und wirft; der Laeufer macht daraus still einen leeren Korpus. AC-5-Randfall (F002) und leere Wortmengen (F003) kleiner. Tests: voller sim-unit Lauf gruen (0 fehlgeschlagen), python unittest 20 OK.

## Geprüfte Dateien

- sha256:adeb66b9b89069bdd0df0b8d84cb4964a801304399ba9d404ccb442738b337be  Measurement/Corpus.swift
- sha256:8b0abaf0a4f7772794bd32107b1c89ad9922d3d1e7420663327f279b8ae552a9  Measurement/RawSentenceColumn.swift

## Prüfbasis

- base: 8211af4b2e85ecb42e4a82c4a29dc484c1d90f9e
- blob:3733a5c18de52520a2a022f481190ac831b6b231  Measurement/Corpus.swift
- blob:774b62c2eebb74ca7f23730623952b7370b37626  Measurement/RawSentenceColumn.swift
