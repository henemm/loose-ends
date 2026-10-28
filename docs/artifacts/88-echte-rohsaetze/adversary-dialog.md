# Adversary Dialog — 88-echte-rohsaetze
Spec: docs/specs/measurement/feat-88-echte-rohsaetze.md
Datum: 2026-10-28 14:31

## Checkliste
- [x] **AC-1:** Drittes Format im Einleser. Given eine Datei im Format oben, deren oberster Wert eine Liste von Objekten mit `rawText` ist / When `Corpus.load(fileName:)` sie liest / Then liefert es je entduplizierten Satz ein `Corpus.Entry` mit `id` aus der Datei, `lang` (ohne Angabe `de`) und `text` gleich `rawText` unverändert. Erkannt wird am Dateiinhalt, nicht am Dateinamen.
- [x] **AC-2:** Bisherige Korpusse unverändert. Given `date-title-corpus`, `latency-corpus`, der FocusBlox-Korpus und `textform-corpus` / When sie über `Corpus.load` gelesen werden / Then sind Anzahl, Kennungen und Texte genauso wie vor der Änderung; die Erkennung des neuen Formats greift bei keinem von ihnen.
- [x] **AC-3:** Entduplizierung. Given Kunstdaten mit drei Sätzen gleicher Wortmenge (andere Groß-/Kleinschreibung und Satzzeichen) und zwei einzelnen Sätzen / When entdupliziert wird / Then bleiben drei Sätze, der Vertreter der Dublettengruppe ist der erste mit Korrektur (sonst der erste der Datei), und die Zählung nennt 5 vor und 3 nach der Entduplizierung.
- [x] **AC-4:** Wahrheitsstufen. Given Kunstsätze mit `titleUser` verschieden von `titleBefore`, mit `titleUser` gleich `titleBefore`, ohne `titleUser`, sowie mit und ohne `durationUser` / When eingeteilt wird / Then zählt Titel „korrigiert“ nur im ersten Fall, die beiden anderen zählen als „nicht korrigiert“, Dauer „korrigiert“ nur bei gesetztem `durationUser`; kein Satz fällt in beide Gruppen eines Kriteriums.
- [x] **AC-5:** Titel-Spalte mit Regel daneben. Given `[MeasurementResult]` zu Kunstsätzen und die Regel als Closure / When ausgewertet wird / Then steht in einer Zeile der Anteil der korrigierten Sätze, deren Modelltitel nach `RawTextWords` (Wortfolge, normalisiert) gleich `titleUser` ist, und daneben derselbe Anteil für den Titel der Regel aus dem Rohtext, jeweils über dieselben korrigierten Sätze, die im Lauf vorkommen. Fehlgeschlagene Aufrufe (`error` gesetzt) zählen als nicht getroffen und werden mit ihrer Zahl ausgewiesen. Die Gruppe „nicht korrigiert“ steht mit ihrer Zahl und dem Vermerk „kein Beleg, nicht gewertet“ in einer eigenen Zeile.
- [x] **AC-6:** Dauer-Spalte mit Regel daneben. Given Ergebnisse über mehrere Läufe und die Dauerregel als Closure / When ausgewertet wird / Then steht der Anteil der Sätze mit `durationUser`, deren Mehrheitsdauer (`SelfConsistency.majority`, fehlgeschlagene Aufrufe ausgenommen) gleich `durationUser` ist, und daneben der Anteil für die Dauer der Regel; Sätze ohne `durationUser` stehen als „nicht korrigiert, kein Beleg“ mit Zahl daneben und werden nie gewertet.
- [x] **AC-7:** Mindestmenge, ehrlich. Given weniger als 30 korrigierte Sätze eines Kriteriums im Lauf / When der Bericht gebildet wird / Then steht in dieser Zeile „zu wenig (n von mindestens 30)“ statt einer Rate, bei Modell und Regel; ab 30 steht die Rate. Die Mindestmenge ist als eine benannte Konstante festgelegt.
- [x] **AC-8:** Leere Gruppe, keine erfundene Zahl. Given ein Kriterium ohne korrigierte Sätze oder ohne Ergebnisse / When ausgewertet wird / Then zeigt die Zelle „–“ statt 0 %.
- [x] **AC-9:** Nur Zählungen, nie Sätze. Given Kunstdaten mit erkennbaren Marker-Wörtern in `rawText`, `titleBefore` und `titleUser` / When der Bericht gerendert wird / Then enthält die Ausgabe keinen dieser Texte, weder ganz noch in Teilen; nur Zahlen, Raten und feste Überschriften.
- [x] **AC-10:** Getrennter Berichtsabschnitt, laut übersprungen. Given `RawSentenceReportTests` mit dem Gate `loose-ends-rawtexts.json` / When die Datei fehlt / Then wird die Suite übersprungen und das laut benannt (#149, Pfad über `MeasurementData`, Suche im Arbeitsstand, dann im Hauptordner); liegt sie samt Ergebnisdatei vor, gibt der Test den Abschnitt „Echte Rohsätze“ getrennt vom FocusBlox-Teil nach stdout aus. In keinem Test läuft ein Modellaufruf.
- [x] **AC-11:** Gate und Ausschluss. Given `scripts/measurement_status.py` und `.gitignore` / When geprüft wird / Then führt `GATES` den Eintrag `loose-ends-rawtexts.json` mit der neuen Suite, stimmt mit dem Swift-Code überein (`test_every_gate_is_listed_and_nothing_else`), und `.gitignore` enthält `docs/reference/loose-ends-rawtexts.json`.

## Dialog

### Runde 1
**Adversary:** Frischer Lauf nach Behebung von F001-F003. Ausgefuehrt: `./scripts/sim.sh generate`, voller `./scripts/sim.sh sim-unit` (Log: docs/artifacts/88-echte-rohsaetze/adversary-run2-full.log), `python3 scripts/test_measurement_status.py` (20 Tests OK). xcresult: 0 failed, 1080 passed, 10 uebersprungen; die Messstrecken-Suiten RawSentenceReportTests, SelfConsistencyReportTests, TextFormModelReportTests stehen laut sim.sh namentlich als "nicht gemessen" (fehlende lokale Datei). Suite RawSentenceColumnTests: 14 Tests gruen (AC-1..AC-9 inkl. Regressionstests zu F001/F002/F003).
F001 selbst gegen den echten FocusBlox-Korpus geprueft (nur Zahlen): Liste, 287 Objekte, 287 mit rawText, 0 mit titleBefore, 287 mit capturedAt, 287 eindeutige ids. Die Erkennung in Measurement/Corpus.swift:158-165 verlangt rawText+titleBefore+capturedAt am ersten Objekt, trifft hier also nicht; der Korpus faellt in den bisherigen Entry-Decoder. BEHOBEN. F002: RawSentenceColumn.swift:23-27 (leerer/wortloser titleUser ist keine Korrektur) und :94-111 (Mehrheit nur ueber nicht fehlgeschlagene Laeufe, Fehler gezaehlt). F003: RawSentenceColumn.swift:67-80 (wortlose Saetze bleiben einzeln).
Neue Suche: (a) Liste, deren erstes Objekt die Felder hat, spaetere nicht: RawSentenceColumn.decode wirft keyNotFound, Corpus.entries propagiert (kein try? in Measurement/). Laut. Umgekehrt (erstes ohne Felder): Entry-Decoder wirft wegen fehlendem text. (b) DurationBucket-Rohwerte minutes5/minutes15/minutes30/hour1/hours2plus (Shared/Models/Enums.swift:55); Regel liefert `.guess.value.rawValue`, Modell `MeasurementResult.duration` als String, Vergleich als String-Rohwert, konsistent. (c) Berichtsausgabe RawSentenceColumn.render (:128-142) nimmt nur Zahlen; AC-9-Test mit vier Markern gruen. (d) Entduplizierung: Vertreter ersetzt in place am Platz des ersten, Dateireihenfolge bleibt. (e) mehrere Laeufe je Satz: Dictionary(grouping:) nach entryID, Mehrheit ueber SelfConsistency.majority (deterministisch bei Gleichstand). (f) Messdatei-Namen: loose-ends-rawtexts.json / loose-ends-rawtexts-run.json ueber MeasurementData.reference (Arbeitsstand, dann Hauptordner); Gate in scripts/measurement_status.py:33-35, Gate-Test und test_rawtexts_file_is_gitignored gruen. (g) MeasurementRun-Dekodierung in RawSentenceReportTests identisch zu TextFormModelReportTests. Der gesperrte Berichtstest selbst laeuft ohne Datei nicht (laut uebersprungen, AC-10 wie spezifiziert); sein Code kompiliert gegen TitleRule/DurationRule.
Gefunden (LOW, nicht blockierend): Corpus.url(fileName:) (Measurement/Corpus.swift:170-177) sucht nur im Bundle und neben der Quelle (Measurement/), nicht in docs/reference; `--corpus loose-ends-rawtexts` ergaebe im Laeufer (LooseEndsLab/MeasurementRunner.swift:63, `try?` vorbestehend) leise 0 Eintraege. Das ist Schnitt B (Laeufer laut Spec unveraendert) und beruehrt AC-1 nicht. Ausserdem prueft thirdFormatLoads `Corpus.entries(from:)` statt `Corpus.load(fileName:)`; load ist ein Einzeiler darauf (Corpus.swift:147-149).
**Implementierer:** Behebungen F001-F003 wie oben; Laeufer-Pfad ist Schnitt B.

### Runde 2
**Adversary:** Skepsis gegen fruehe Einigung, nochmals je AC am Code. AC-1 Corpus.swift:158-165 + thirdFormatLoads (ids, lang Standard de, Text unveraendert). AC-2 otherCorporaUnchanged (date-title, latency, textform=120) plus FocusBlox-Form-Test und echter Korpus (287, ohne titleBefore). AC-3 RawSentenceColumn.swift:67 + duplicatesFoldWithCounts (5 vor, 3 nach, Vertreter b). AC-4 :23,:83 + truthTiers (disjunkt). AC-5 :94 + titleColumnWithRule (corrected 3, Modell 1, Regel 1, errors 1, uncorrected 1; Satz ausserhalb des Laufs nicht gezaehlt). AC-6 :113 + durationColumnWithRule. AC-7 minimumCorrected = 30 (:9), 29 -> "zu wenig (29 von mindestens 30)", 30 -> "50 %". AC-8 cell() :144, total 0 -> "–". AC-9 render ohne Satztexte. AC-10 Suite per .enabled(if:) gesperrt, im Lauf namentlich uebersprungen, kein Modellaufruf. AC-11 Gate + .gitignore + Python-Tests. Keine weiteren Defekte; F004 bleibt Hinweis fuer Schnitt B.
**Implementierer:** Keine Aenderung noetig.

## Findings und Confirmations

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: Measurement/Corpus.swift:170
  Description: Corpus.url(fileName:) findet nur Bundle-Ressourcen und Dateien neben der Quelle, nicht docs/reference/loose-ends-rawtexts.json; der Laeufer schluckt den Fehler per try? (LooseEndsLab/MeasurementRunner.swift:63, vorbestehend).
  Spec requirement: AC-1 — Corpus.load(fileName:) liest die Datei (Laeufer ausdruecklich unveraendert)
  Conflict: Fuer den echten Lauf nicht auffindbar, ohne Meldung; betrifft Schnitt B, nicht AC-1 in Schnitt A.
  Remediation: In Schnitt B Ablage/Bundling klaeren und den Laeufer bei leerem Korpus laut scheitern lassen.

Confirmation:
  AC: AC-1
  Code reference: Measurement/Corpus.swift:158
  Evidence: Erkennung am Inhalt, Entry aus id/lang/rawText; Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Measurement/Corpus.swift:166
  Evidence: Fallthrough auf Entry-Decoder; FocusBlox (287, ohne titleBefore) unveraendert.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Measurement/RawSentenceColumn.swift:67
  Evidence: distinct() mit Vertreter, vor/nach, wortlose Saetze einzeln.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Measurement/RawSentenceColumn.swift:23
  Evidence: titleCorrected/durationCorrected, tiers() disjunkt.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Measurement/RawSentenceColumn.swift:94
  Evidence: titleRow mit Regel-Closure, Fehlerzaehlung, Unkorrigierte gesondert.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Measurement/RawSentenceColumn.swift:113
  Evidence: durationRow mit SelfConsistency.majority ueber beantwortete Laeufe.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Measurement/RawSentenceColumn.swift:9
  Evidence: benannte Konstante minimumCorrected = 30, cell() zeigt "zu wenig".
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Measurement/RawSentenceColumn.swift:144
  Evidence: cell() liefert "–" bei total 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Measurement/RawSentenceColumn.swift:128
  Evidence: render nimmt nur Zaehlungen; Markertest gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEndsTests/RawSentenceReportTests.swift:227
  Evidence: Suite per .enabled(if:) gesperrt, im Lauf namentlich uebersprungen, kein Modellaufruf.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: scripts/measurement_status.py:33
  Evidence: Gate-Eintrag, .gitignore-Zeile, Python-Tests 20 OK.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 1080 passed, 0 failed, 10 uebersprungen (Messstrecken namentlich: RawSentenceReportTests, SelfConsistencyReportTests, TextFormModelReportTests wegen fehlender lokaler Dateien); Python 20 OK
Edge cases: geprueft, F004 LOW nicht blockierend (Schnitt B)
Regressions: keine
Checklist: 11/11 Punkte bewiesen

## Geprüfte Dateien

- sha256:653a9f041135f1b000d963425a60bbfa505265264eeeffd865b86b776febea32  LooseEndsTests/RawSentenceReportTests.swift
- sha256:6c5c370341851ca0e73048b891bdab2959dffc5009eb335504eac6cf4329b9f3  Measurement/Corpus.swift
- sha256:a7ff278d25896264c3807c49b8f8768dcb522eeb0df301bc69cdf7c0b881aa70  Measurement/RawSentenceColumn.swift
- sha256:8e00dccf4b2c911b5a945db9541083ca01356d5eb2ee96d732eee1b1d709af07  scripts/measurement_status.py

## Prüfbasis

- base: 8211af4b2e85ecb42e4a82c4a29dc484c1d90f9e
- blob:33d2bea088a2cc641ff0176522b0aa82331a518e  LooseEndsTests/RawSentenceReportTests.swift
- blob:fd884cc710ba88408de85a008822380073f1f8eb  Measurement/Corpus.swift
- blob:dc9f23872ad71430fd801b6438cf22fb323a93de  Measurement/RawSentenceColumn.swift
- blob:41d55a6bb6277459d567302d28dccc3207035687  scripts/measurement_status.py
