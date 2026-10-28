---
entity_id: feat-88-echte-rohsaetze
type: feature
created: 2026-10-28
updated: 2026-10-28
status: draft
---

# Spec: #88 Teil 2, Schnitt A (ohne Gerät) — Hennings echte Rohsätze als zweite Messquelle einlesen und auswerten

**Status:** draft · **Workflow:** feat-88-echte-rohsaetze · **Erstellt:** 2026-10-28 · **Aktualisiert:** 2026-10-28

## Freigabe

- [ ] Freigegeben

## Problem
Die Messung von Titel und Dauer stützt sich bisher auf erfundene oder fremde Sätze: den Datum-/Titel-Korpus,
den Textform-Korpus und die 287 FocusBlox-Titel. Hennings eigene Loose-Ends-Rohsätze, die tatsächlich in der
App entstanden sind, fehlen als Quelle. Es gibt weder ein Dateiformat dafür noch einen Weg, sie in den Läufer
(`Corpus.load`, `--corpus`) zu bringen, noch eine Auswertung. Die Wahrheit je Satz ist die eigentliche
Schwierigkeit: `TitleRule` kann nicht zugleich Maßstab und Prüfling sein, und „nicht beanstandet“ ist kein
Beleg für „richtig“. Dubletten (43-mal derselbe Satz im FocusBlox-Korpus) würden eine Rate verzerren.

## Zweck
Vorab, ohne Gerät und ohne Hennings Daten, entstehen das Dateiformat, der Einleser, die Wahrheitsstufen, die
Auswertung mit Regel-Spalte und das Gate. Alles wird mit Kunstdaten getestet. Das Holen der echten Sätze und
der Laborlauf sind Schnitt B und laufen erst nach Hennings wörtlichem „jetzt ist ein Test möglich“.

**Ohne Modell geht es hier nicht, weil** die Messung dem Modell selbst gilt (Titel-Verfeinerung und Dauer des
Modells an Hennings echten Sätzen); die Regel-Spalte (`TitleRule`, `DurationRule`) steht als Nulllinie in jeder
Zeile daneben. Für die Wahrheit wird kein Modell gebraucht: sie stammt aus Hennings eigenen Korrekturen.

## Quelle
- **Dateien:** `Measurement/Corpus.swift` (`Corpus.load`), `Measurement/TextFormColumn.swift` (Muster),
  `LooseEndsTests/MeasurementData.swift`, `LooseEndsTests/TextFormModelReportTests.swift`,
  `scripts/measurement_status.py`, `.gitignore`, `docs/context/88-echte-rohsaetze.md`
- **Bezeichner:** `Corpus.load(fileName:calendar:)`, neu `RawSentenceColumn`

## Format der Datei und Wahrheitsstufen (hier festgelegt)

**Datei** `docs/reference/loose-ends-rawtexts.json`, gitignoriert, nie eingecheckt. Oberster Wert ist eine
Liste, ein Eintrag je Satz:

| Feld | Pflicht | Inhalt |
|---|---|---|
| `id` | ja | laufende Kennung der Datei (`s-0001` …), keine Id der App |
| `rawText` | ja | der Rohtext, unverändert |
| `titleBefore` | ja | der Titel, den die App zuerst setzte |
| `titleUser` | nein | der Titel nach Hennings Korrektur (Revision mit Autor Nutzer) |
| `durationUser` | nein | die von Henning gesetzte Dauer als `DurationBucket`-Rohwert |
| `capturedAt` | ja | Zeitpunkt der Erfassung, ISO 8601 (nur für die Auswertung nach Zeitraum, nicht Teil der Wahrheit) |
| `lang` | nein | `de` oder `en`, ohne Angabe `de` |

**Wahrheitsstufen je Satz und Kriterium:**
1. **Vom Nutzer korrigiert** = Wahrheit. Titel: `titleUser` ist gesetzt und nach `RawTextWords` verschieden
   von `titleBefore` (eine Revision mit gleichem Text ist keine Korrektur). Dauer: `durationUser` gesetzt.
2. **Nicht korrigiert** = **kein Beleg**. Der Satz bildet eine eigene Gruppe, wird gezählt und nie als richtig
   gewertet.
3. **Titel ohne Korrektur, Rückfall über Schlüsselwörter: bewusst weggelassen.** Der Textform-Korpus kann
   `carriesAll` nutzen, weil er je Inhalt handgesetzte `truth.titleWords` hat. Hier gibt es keine; sie aus dem
   Rohtext abzuleiten hieße, eine zweite Regel (Substantive, Wortarten) als Maßstab einzuführen, mit eigener
   Fehlerquote und zirkulär zu `TitleRule`. Ohne Maßstab bleibt die Gruppe leer von Urteilen. Dauer kennt nur
   Stufe 1 und 2.

**Entduplizierung:** Vor dem Zählen und vor dem Lauf werden Sätze mit gleicher Wortmenge
(`RawTextWords`-Gleichheit) zu einem zusammengefasst. Vertreter ist der erste Satz mit Korrektur, sonst der
erste der Datei. Der Bericht nennt die Anzahl vor und nach der Entduplizierung.

## Acceptance Criteria

- **AC-1:** Drittes Format im Einleser. Given eine Datei im Format oben, deren oberster Wert eine Liste von
  Objekten mit `rawText` ist / When `Corpus.load(fileName:)` sie liest / Then liefert es je entduplizierten
  Satz ein `Corpus.Entry` mit `id` aus der Datei, `lang` (ohne Angabe `de`) und `text` gleich `rawText`
  unverändert. Erkannt wird am Dateiinhalt, nicht am Dateinamen.
- **AC-2:** Bisherige Korpusse unverändert. Given `date-title-corpus`, `latency-corpus`, der FocusBlox-Korpus
  und `textform-corpus` / When sie über `Corpus.load` gelesen werden / Then sind Anzahl, Kennungen und Texte
  genauso wie vor der Änderung; die Erkennung des neuen Formats greift bei keinem von ihnen.
- **AC-3:** Entduplizierung. Given Kunstdaten mit drei Sätzen gleicher Wortmenge (andere Groß-/Kleinschreibung
  und Satzzeichen) und zwei einzelnen Sätzen / When entdupliziert wird / Then bleiben drei Sätze, der
  Vertreter der Dublettengruppe ist der erste mit Korrektur (sonst der erste der Datei), und die Zählung
  nennt 5 vor und 3 nach der Entduplizierung.
- **AC-4:** Wahrheitsstufen. Given Kunstsätze mit `titleUser` verschieden von `titleBefore`, mit `titleUser`
  gleich `titleBefore`, ohne `titleUser`, sowie mit und ohne `durationUser` / When eingeteilt wird / Then
  zählt Titel „korrigiert“ nur im ersten Fall, die beiden anderen zählen als „nicht korrigiert“, Dauer
  „korrigiert“ nur bei gesetztem `durationUser`; kein Satz fällt in beide Gruppen eines Kriteriums.
- **AC-5:** Titel-Spalte mit Regel daneben. Given `[MeasurementResult]` zu Kunstsätzen und die Regel als
  Closure / When ausgewertet wird / Then steht in einer Zeile der Anteil der korrigierten Sätze, deren
  Modelltitel nach `RawTextWords` (Wortfolge, normalisiert) gleich `titleUser` ist, und daneben derselbe
  Anteil für den Titel der Regel aus dem Rohtext, jeweils über dieselben korrigierten Sätze, die im Lauf
  vorkommen. Fehlgeschlagene Aufrufe (`error` gesetzt) zählen als nicht getroffen und werden mit ihrer Zahl
  ausgewiesen. Die Gruppe „nicht korrigiert“ steht mit ihrer Zahl und dem Vermerk „kein Beleg, nicht
  gewertet“ in einer eigenen Zeile.
- **AC-6:** Dauer-Spalte mit Regel daneben. Given Ergebnisse über mehrere Läufe und die Dauerregel als
  Closure / When ausgewertet wird / Then steht der Anteil der Sätze mit `durationUser`, deren Mehrheitsdauer
  (`SelfConsistency.majority`, fehlgeschlagene Aufrufe ausgenommen) gleich `durationUser` ist, und daneben
  der Anteil für die Dauer der Regel; Sätze ohne `durationUser` stehen als „nicht korrigiert, kein Beleg“
  mit Zahl daneben und werden nie gewertet.
- **AC-7:** Mindestmenge, ehrlich. Given weniger als 30 korrigierte Sätze eines Kriteriums im Lauf / When der
  Bericht gebildet wird / Then steht in dieser Zeile „zu wenig (n von mindestens 30)“ statt einer Rate, bei
  Modell und Regel; ab 30 steht die Rate. Die Mindestmenge ist als eine benannte Konstante festgelegt.
- **AC-8:** Leere Gruppe, keine erfundene Zahl. Given ein Kriterium ohne korrigierte Sätze oder ohne
  Ergebnisse / When ausgewertet wird / Then zeigt die Zelle „–“ statt 0 %.
- **AC-9:** Nur Zählungen, nie Sätze. Given Kunstdaten mit erkennbaren Marker-Wörtern in `rawText`,
  `titleBefore` und `titleUser` / When der Bericht gerendert wird / Then enthält die Ausgabe keinen dieser
  Texte, weder ganz noch in Teilen; nur Zahlen, Raten und feste Überschriften.
- **AC-10:** Getrennter Berichtsabschnitt, laut übersprungen. Given `RawSentenceReportTests` mit dem Gate
  `loose-ends-rawtexts.json` / When die Datei fehlt / Then wird die Suite übersprungen und das laut benannt
  (#149, Pfad über `MeasurementData`, Suche im Arbeitsstand, dann im Hauptordner); liegt sie samt
  Ergebnisdatei vor, gibt der Test den Abschnitt „Echte Rohsätze“ getrennt vom FocusBlox-Teil nach stdout aus.
  In keinem Test läuft ein Modellaufruf.
- **AC-11:** Gate und Ausschluss. Given `scripts/measurement_status.py` und `.gitignore` / When geprüft wird /
  Then führt `GATES` den Eintrag `loose-ends-rawtexts.json` mit der neuen Suite, stimmt mit dem Swift-Code
  überein (`test_every_gate_is_listed_and_nothing_else`), und `.gitignore` enthält
  `docs/reference/loose-ends-rawtexts.json`.

## Nicht in diesem Schnitt
- Das Export-Skript `scripts/export-loose-ends-rawtexts.swift` und das Holen der Sätze aus Hennings Mac-Store
  oder von seinen Geräten (Schnitt B).
- Der Laborlauf und jede Aktion auf einem Gerät von Henning, nur nach seinem wörtlichen „jetzt ist ein Test
  möglich“, im selben Durchgang wie #71. Hennings Store ist bis dahin tabu.
- Jede echte Rohsatz-Datei im Repository, in Artefakten oder Issue-Kommentaren.
- Änderungen am Läufer (`MeasurementRunner`), am Produktpfad oder an `TextFormColumn`.
- Datum, Kontext und Energie.

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `Corpus.Entry`, `Corpus.load` | Struktur, Funktion | Ziel des dritten Formats |
| `RawTextWords` | Funktion | Wortfolge, Normalisierung, Dublettengleichheit |
| `TitleRule`, `DurationRule` | Funktion | Regel-Spalte, als Closure hereingereicht |
| `SelfConsistency.majority` | Funktion | Mehrheitsdauer über die Läufe |
| `MeasurementResult`, `MeasurementStore.coder` | Struktur | Ergebnisdatei lesen |
| `MeasurementData` | Hilfe | Pfad der lokalen Dateien |

## Umfang

### Betroffene Dateien

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/RawSentenceColumn.swift` | CREATE | reine Zählung ohne `import LooseEnds`: Lesen, Entduplizieren, Wahrheitsstufen, Titel- und Dauer-Spalte, Rendern |
| `Measurement/Corpus.swift` | MODIFY | `load` erkennt das dritte Format und liefert die entduplizierten Sätze als `Entry` |
| `LooseEndsTests/RawSentenceReportTests.swift` | CREATE | Tests mit Kunstdaten (Einleser, Entduplizierung, Stufen, Spalten, Datenschutz) und gesperrte Berichts-Suite; `MeasurementData.rawSentences` als Erweiterung in dieser Datei |
| `scripts/measurement_status.py` | MODIFY | `GATES` um `loose-ends-rawtexts.json` |
| `scripts/test_measurement_status.py` | MODIFY | Dateiname in der Zuordnung des Gate-Tests |
| `.gitignore` | MODIFY | eine Zeile |

### Geschätzter Umfang
- Dateien: **6**, eine mehr als die Grenze von 4–5. Die Überschreitung ist mechanisch: `.gitignore` (1 Zeile)
  und das Gate-Paar (je 2–3 Zeilen) tragen zusammen etwa 8 LoC; die tragende Arbeit liegt in drei Dateien.
  Die Gate-Zuordnung lässt sich nicht weglassen (sonst bricht der bestehende Gate-Test), die
  `MeasurementData`-Erweiterung liegt bewusst in der Testdatei, um eine siebte Datei zu vermeiden. Die
  Überschreitung gilt mit der Freigabe dieser Spec als bestätigt; will Henning sie nicht, wird die
  `.gitignore`-Zeile zu Schnitt B verschoben, mit dem Nachteil, dass Schnitt A eine echte Datei nicht
  ausschließt.
- Zeilen: etwa +240 / −2 (innerhalb ±250; Reserve gering).

## Technische Umsetzung
`RawSentenceColumn` ist eine reine Auswertung nach dem Vorbild von `TextFormColumn`: Strukturen für Satz,
Zeilen und Zählung, Funktionen auf `[MeasurementResult]` plus der eingelesenen Sätze, `TitleRule` und
`DurationRule` kommen als Closures (`(String) -> String?`), weil sie nicht im Lab-Ziel liegen. `Corpus.load`
bekommt einen dritten Zweig: ist der oberste Wert eine Liste und trägt ihr erstes Objekt den Schlüssel
`rawText`, werden die Sätze über `RawSentenceColumn.distinct` entdupliziert und als `Entry` (`id`, `lang`,
`text`) zurückgegeben; sonst läuft der bisherige Weg unverändert, das Objektformat des Textform-Korpus
bleibt vor der Listenprüfung. Der Läufer misst damit je Satz einmal, nicht 43-mal. Der Bericht liest die
Datei ein zweites Mal ungefiltert, um „vor/nach“ auszuweisen. Titelgleichheit ist strikt (Wortfolge nach
`RawTextWords.normalized`), Dauergleichheit ist Gleichheit des Bucket-Rohwerts. Der Abschnitt „Echte
Rohsätze“ steht getrennt vom FocusBlox-Teil und nennt seine Quelle („Hennings eigene Erfassungen, vom Nutzer
korrigierte Sätze als Wahrheit“).

**Alternativen:**
- **A (gewählt für Schnitt B): Export aus dem Mac-Store**, lokal, schreibgeschützt, Ausgabe gitignoriert,
  nach Vorbild `export-focusblox-corpus.swift`. Kippt keine ADR; braucht Hennings Wort.
- **B: Export-Knopf in der App** (Datei teilen). Verworfen: Produktfunktion nur für die Messung, der
  Datenschutztext (#705) müsste mit.
- **C: nur ein Berichtsabschnitt „nicht gemessen, weil …“.** Billig, belegt nichts. Bleibt als Zustand,
  solange die Datei fehlt (Gate meldet es).
- **D: CloudKit direkt lesen** (`cktool`). Verworfen: privates Datenbankschema, mit dem Management-Token
  nicht zugänglich.
- **Zum Format selbst:** (E) die Revisionen unverarbeitet exportieren und die Wahrheit erst im Einleser
  bilden: näher an der App, aber der Einleser müsste das Revisionsmodell kennen und die Datei trüge mehr
  persönliche Daten. (F) Titel lockerer vergleichen (Schlüsselwörter statt Wortfolge): braucht den Maßstab,
  der hier fehlt (siehe Stufe 3). Gewählt ist die flache, schon aufgelöste Satzliste; sie kippt keine ADR
  (R4-4 „Rohtexte als Messkorpus ja, lokal, nie im Repository“ bleibt Grundlage).

## Testplan

### Automatisierte Tests (TDD RED)
Alle mit Kunstdaten in `RawSentenceReportTests.swift`, keine echten Sätze; Struktur: ungesperrte Suite
`RawSentenceColumnTests`, gesperrte Suite `RawSentenceReportTests`.
- [ ] `RawSentenceColumnTests.thirdFormatLoads` — GIVEN Kunstdatei im Format / WHEN `Corpus.load` / THEN
  `Entry` mit Kennung, Sprache (Standard `de`) und unverändertem Text, ohne Dateinamenerkennung (AC-1).
- [ ] `RawSentenceColumnTests.otherCorporaUnchanged` — GIVEN die vier bisherigen Korpusse / WHEN geladen /
  THEN Anzahl und Kennungen wie zuvor (AC-2).
- [ ] `RawSentenceColumnTests.duplicatesFoldWithCounts` — GIVEN 5 Sätze (eine Dublettengruppe aus 3 gleichen Sätzen plus 2 einzelne) / WHEN
  entdupliziert / THEN 3, Vertreter mit Korrektur, „5 vor / 3 nach“ (AC-3).
- [ ] `RawSentenceColumnTests.truthTiers` — GIVEN Sätze mit abweichendem, gleichem und ohne `titleUser`,
  mit und ohne `durationUser` / WHEN eingeteilt / THEN Gruppen wie in AC-4, keine Doppelzählung (AC-4).
- [ ] `RawSentenceColumnTests.titleColumnWithRule` — GIVEN synthetische Ergebnisse (Treffer, Fehltreffer,
  Fehler) und Regel-Closure / WHEN ausgewertet / THEN Modell- und Regelanteil über dieselben Sätze, Fehler
  gezählt, Gruppe „nicht korrigiert“ gesondert (AC-5).
- [ ] `RawSentenceColumnTests.durationColumnWithRule` — GIVEN Dauern über mehrere Läufe / WHEN ausgewertet /
  THEN Mehrheit gegen `durationUser`, Regel daneben, unkorrigierte Sätze nur gezählt (AC-6).
- [ ] `RawSentenceColumnTests.belowMinimumSaysTooLittle` — GIVEN 29 und 30 korrigierte Sätze / WHEN
  gerendert / THEN bei 29 „zu wenig (29 von mindestens 30)“, bei 30 eine Rate (AC-7).
- [ ] `RawSentenceColumnTests.emptyGroupShowsDash` — GIVEN keine korrigierten Sätze / WHEN gerendert / THEN
  „–“ (AC-8).
- [ ] `RawSentenceColumnTests.reportNeverContainsSentences` — GIVEN Marker-Wörter in allen Textfeldern /
  WHEN gerendert / THEN keines davon in der Ausgabe (AC-9).
- [ ] `RawSentenceReportTests.printsSeparateSection` — GIVEN lokale Datei und Ergebnisdatei / WHEN der Test
  läuft / THEN Abschnitt „Echte Rohsätze“ nach stdout; fehlt die Datei, ist die Suite laut übersprungen;
  kein Modellaufruf im Test (AC-10).
- [ ] `test_measurement_status.py::test_every_gate_is_listed_and_nothing_else` (angepasst) und
  `test_measurement_status.py::test_rawtexts_file_is_gitignored` (neu, liest `.gitignore`) — GIVEN die
  Gate-Liste und die Swift-Gatter / WHEN verglichen / THEN gleich, Datei ausgeschlossen (AC-11).

Kein UI-Test: kein Produktcode, keine View betroffen. Geräteliste: „Kein Pfad der Geräteliste berührt.“
Abnahme Stufe 2: Unit-Tests im Simulator (`./scripts/sim.sh sim-unit RawSentenceColumnTests`, danach die
ganze Suite) und `python3 scripts/test_measurement_status.py`; es gibt keine Oberfläche zum Durchspielen. Der
Beleg, dass der Einleser die Kunstdatei wirklich über `Corpus.load` in `Entry` überführt (AC-1), ist der
Durchlauf-Test, nicht ein Test, der seinen Ausgangszustand selbst setzt.

## Definition of Done

- [ ] AC-1 bis AC-11 erfüllt, belegt durch die genannten Tests
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh sim-unit`), Python-Test grün, bestehende Korpus-Tests unverändert grün
- [ ] CI grün, PR gemergt; #88 bleibt mit Schnitt B offen
- [ ] Hennings Hauptordner nachgezogen und Projekt neu erzeugt
- [ ] Keine echte Rohsatz-Datei und kein echter Satz in Repository, Artefakten oder Kommentaren
- [ ] Nichts auf einem Gerät von Henning gestartet, Hennings Store nicht gelesen

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Messwerkzeug im Test-/Lab-Umfang, kein Produktpfad, keine neue Abhängigkeit; keine
  bestehende ADR wird gekippt (R4-4 bleibt Grundlage).

## Changelog

- 2026-10-28: Spec aus dem Analyse-Kontext (`docs/context/88-echte-rohsaetze.md`) erstellt, Schnitt A. Format
  und Wahrheitsstufen festgelegt; Titel-Rückfall über Schlüsselwörter begründet weggelassen; Dateizahl 6
  (eine über der Grenze) offen benannt.
