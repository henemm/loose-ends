---
entity_id: feat-88-textform-spalte
type: feature
created: 2026-10-26
updated: 2026-10-26
status: draft
---

# Spec: #88 Teil 2 (vorab, ohne Gerät) — Spalte „Titel und Dauer je Textform“ für den Laborlauf

**Status:** draft · **Workflow:** feat-88-textform-spalte · **Erstellt:** 2026-10-26 · **Aktualisiert:** 2026-10-26

## Freigabe

- [ ] Freigegeben

## Problem
Der Textform-Korpus (`Measurement/textform-corpus.json`, #70) hat 40 Inhalte in den Formen `typed`,
`dictated`, `mail` und `english`. Die Regelspalte dazu gibt es (`TextFormRuleReportTests`, `TitleRule` trifft
in allen Formen die Schlüsselwörter). Die Modellspalte fehlt: Der Laborlauf kann den Korpus nicht lesen,
denn `Corpus.load` dekodiert fest eine Liste von `Corpus.Entry`, die Datei ist aber ein Objekt mit
`entries[].forms{…}`. Mit `--corpus textform-corpus` startet der Läufer heute mit „Korpus: 0 Sätzen“
(`try?` verschluckt den Fehler). Außerdem fehlt eine Auswertung, die das Ergebnis nach Inhalt und Form
aufschlüsselt.

## Zweck
Der spätere Geräte-Durchgang misst Titel und Dauer des Modells je Textform in einem Zug. Dafür werden
vorab, ohne Gerät, gebaut: ein Adapter (Korpus → Notizen) und eine reine Auswertung (Ergebnisdatei →
Spalte), beide mit Unit-Tests. Der Lauf auf dem iPhone selbst bleibt aus, bis Henning wörtlich „jetzt ist
ein Test möglich“ schreibt.

**Ohne Modell geht es hier nicht, weil** die Spalte genau das Modell messen soll (Titel-Treue und Dauer des
Modells über Textformen); die Regelspalte (`TitleRule`) steht als Nulllinie in jeder Zeile daneben.

## Quelle
- **Dateien:** `Measurement/Corpus.swift` (`Corpus.load`), `Measurement/textform-corpus.json`
- **Bezeichner:** `Corpus.load(fileName:calendar:)`, neu `TextFormColumn`

## Acceptance Criteria

- **AC-1:** Adapter erkennt das Objektformat. Given `Corpus.load(fileName: "textform-corpus")` / When die
  Datei gelesen wird / Then liefert es `Corpus.Entry` je Inhalt × Form `typed`, `dictated`, `english`, also
  120 Notizen für 40 Inhalte. Erkannt wird am Dateiinhalt (oberster Wert ist ein Objekt mit `entries`), nicht
  am Dateinamen.
- **AC-2:** Kennung und Sprache. Given die 120 Notizen / When Kennung und Sprache gelesen werden / Then lautet
  die Kennung `<inhalt>.<form>` (z. B. `tf-01.typed`, `tf-01.dictated`, `tf-01.english`), `lang` ist `en` für
  `english` und `de` für `typed` und `dictated`, `text` ist der Wortlaut der Form unverändert.
- **AC-3:** Mail bleibt draußen. Given der Adapter / When die Notizen gezählt werden / Then kommt keine Notiz
  der Form `mail` vor (das Produkt reicht nur den Betreff weiter, der Körper ist kein Modell-Eingang).
- **AC-4:** Bestehende Korpusse unverändert. Given `date-title-corpus`, `latency-corpus` und der
  FocusBlox-Korpus / When sie über `Corpus.load` gelesen werden / Then sind Anzahl, Kennungen und Texte
  genauso wie vor der Änderung; ein Test hält das fest. `date-title`- und `latency`-Läufe ändern sich nicht.
- **AC-5:** Titel-Spalte je Form. Given `[MeasurementResult]` aus einem Lauf mit diesem Korpus / When
  ausgewertet wird / Then steht je Form (`typed`, `dictated`, `english`) der Anteil der Notizen, deren
  Modelltitel alle `truth.titleWords` des Inhalts enthält (Vergleich über `RawTextWords`), und daneben in
  derselben Zeile derselbe Anteil für den Titel, den `TitleRule` aus dem Rohtext bildet. Fehlgeschlagene
  Aufrufe (`error` gesetzt) zählen als nicht getroffen und werden mit ihrer Zahl ausgewiesen.
- **AC-6:** Dauer-Spalte ohne Wahrheit, laut. Given dieselben Ergebnisse / When die Dauer ausgewertet wird /
  Then steht je Form `dictated` und `english` der Anteil der Inhalte, deren Dauer (Mehrheit über die Läufe
  via `SelfConsistency.majority`) der Dauer der Form `typed` desselben Inhalts gleicht. Der Bericht sagt in
  einer Zeile, dass der Korpus keine Dauer-Wahrheit hat und die Zahl eine Übereinstimmung zwischen den Formen
  ist, keine Trefferquote. Inhalte ohne Dauer in `typed` oder ohne Ergebnis zählen nicht mit und werden
  gezählt ausgewiesen.
- **AC-7:** Leere Gruppe, keine erfundene Zahl. Given eine Form ohne Ergebnisse / When ausgewertet wird /
  Then zeigt ihre Zeile „–“ statt 0 %.
- **AC-8:** Bericht gesperrt, laut übersprungen. Given `TextFormModelReportTests` / When die lokale
  Ergebnisdatei fehlt / Then wird die Suite übersprungen und das laut benannt (#149, Muster
  `SelfConsistencyReportTests`, Pfad über `MeasurementData`); liegt sie vor, gibt der Test den Bericht
  nach stdout aus. Es läuft in keinem Test ein Modellaufruf.
- **AC-9:** Aufruf dokumentiert. Given `docs/reference/textform-rules.md` / When gelesen / Then ersetzt der
  Satz zum Aufruf (`--corpus textform-corpus --runs <n> --result <name>`, Auswertung) den Hinweis
  „Modellspalte fehlt noch“, und der Text sagt, dass der Lauf nur nach Hennings Wort läuft.

## Nicht in diesem Schnitt
- Der Lauf auf dem iPhone und jede Aktion auf einem Gerät von Henning (nur nach seinem „jetzt ist ein Test
  möglich“).
- Die Form `mail` als Modell-Eingang und eine Mail-Körper-Bereinigung für das Modell.
- Teil 2 von #88 im engeren Sinn (Hennings echte Rohsätze als zweite Quelle): bleibt offen.
- Änderungen am Läufer (`MeasurementRunner`), am Produktpfad oder an anderen Korpussen.
- Datum, Kontext und Energie: für diese Spalte unerheblich (Datum läuft per Regel ohne Modell).

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `Corpus.Entry` | Struktur | Zielformat des Adapters (`id`, `lang`, `text`) |
| `RawTextWords` | Funktion | Wortvergleich der Schlüsselwörter |
| `TitleRule` | Funktion | Nulllinie: Regeltitel aus dem Rohtext |
| `SelfConsistency.majority` | Funktion | Mehrheitsdauer über die Läufe |
| `MeasurementResult`, `MeasurementStore.coder` | Struktur | Ergebnisdatei lesen |
| `MeasurementData` | Hilfe | Pfad der lokalen Messdatei |

## Umfang

### Betroffene Dateien

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/Corpus.swift` | MODIFY | `load` erkennt das Objektformat und liefert `Entry` je Inhalt × Form; bisherige Korpusse unverändert |
| `Measurement/TextFormColumn.swift` | CREATE | reine Auswertung: Titel-Schlüsselwörter (Modell vs. `TitleRule`) und Dauer-Übereinstimmung mit `typed` |
| `LooseEndsTests/TextFormColumnTests.swift` | CREATE | Unit-Tests: Adapter, alte Korpusse gleich, Auswertung mit synthetischen Ergebnissen |
| `LooseEndsTests/TextFormModelReportTests.swift` | CREATE | Bericht aus lokaler Ergebnisdatei, laut übersprungen wenn sie fehlt |
| `docs/reference/textform-rules.md` | MODIFY | Aufruf und Lesart statt „Modellspalte fehlt noch“ |

### Geschätzter Umfang
- Dateien: 5 (innerhalb der 4–5-Dateien-Grenze)
- Zeilen: etwa +200 / −5 (innerhalb ±250)

## Technische Umsetzung
Der Läufer braucht nur `id`, `lang` und `text` je Satz und kennt `--corpus`, `--runs` und `--result` schon.
Deshalb sitzt der Adapter in `Corpus.load`: Er prüft am Dateiinhalt, ob der oberste Wert ein Objekt mit
`entries` ist, und baut dann die Notizen; sonst läuft der bisherige Weg unverändert. Die Auswertung ist eine
reine Funktion auf `[MeasurementResult]` plus der Korpusdatei (für `truth.titleWords`), ohne `import
LooseEnds`, damit die Datei in Lab, Tests und UI-Tests kompiliert. Der private Decoder in
`TextFormRuleReportTests` bleibt; ob er auf den neuen Typ umzieht, ist offen, solange das Limit hält und der
Regelbericht unverändert bleibt.

**Alternativen:** (A) Nichts vorab bauen, Adapter erst im Geräte-Durchgang: Henning würde nach dem Lauf
nochmal warten; keine ADR gekippt. (B) Eigene Lab-Eingabe statt `Corpus.load`-Erweiterung: mehr Code im
bisher unveränderten Läufer. (C) Den Korpus in das `Entry`-Format umschreiben: zwei Quellen neben
`TextFormRuleReportTests`. Gewählt ist die Erweiterung von `Corpus.load`, weil sie den Läufer nicht anfasst.

## Testplan

### Automatisierte Tests (TDD RED)
- [ ] `TextFormColumnTests.adapterYields120Notes` — GIVEN `textform-corpus` / WHEN geladen / THEN 120
  Notizen, keine `mail` (AC-1, AC-3).
- [ ] `TextFormColumnTests.idsAndLanguage` — GIVEN die Notizen / WHEN gelesen / THEN `tf-01.typed`,
  `.dictated`, `.english`, Sprache de/de/en, Text unverändert (AC-2).
- [ ] `TextFormColumnTests.otherCorporaUnchanged` — GIVEN die drei bisherigen Korpusse / WHEN geladen /
  THEN Anzahl und Kennungen wie zuvor (AC-4).
- [ ] `TextFormColumnTests.titleColumn` — GIVEN synthetische Ergebnisse (Treffer, Fehltreffer, Fehler) /
  WHEN ausgewertet / THEN Anteile je Form, Regelspalte daneben, Fehler gezählt (AC-5).
- [ ] `TextFormColumnTests.durationAgreement` — GIVEN Dauern über mehrere Läufe / WHEN ausgewertet / THEN
  Mehrheit gegen `typed`, Inhalte ohne Vergleich gezählt, Hinweiszeile „keine Wahrheit“ (AC-6).
- [ ] `TextFormColumnTests.emptyFormShowsDash` — GIVEN keine Ergebnisse einer Form / WHEN ausgewertet /
  THEN „–“ (AC-7).
- [ ] `TextFormModelReportTests` — GIVEN fehlende Ergebnisdatei / WHEN der Test läuft / THEN laut
  übersprungen (AC-8).
- [ ] `TextFormColumnTests.referenceDocNamesCall` — GIVEN `docs/reference/textform-rules.md` / WHEN gelesen /
  THEN enthält sie `--corpus textform-corpus` und nicht mehr „Modellspalte fehlt noch“ (AC-9).

Kein UI-Test: kein Produktcode, keine View betroffen. Geräteliste: „Kein Pfad der Geräteliste berührt.“
Abnahme Stufe 2: die Unit-Tests laufen im Simulator (`sim.sh sim-unit`); der Adapter-Test (AC-1) beweist,
dass `--corpus textform-corpus` 120 statt 0 Notizen liefert. Es gibt keine Bedienoberfläche zum Durchspielen.

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt, belegt durch die genannten Tests
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh sim-unit`), bestehende Korpus-Tests unverändert grün
- [ ] CI grün, PR gemergt; #88 bleibt mit dem Rest von Teil 2 offen
- [ ] Hennings Hauptordner nachgezogen und Projekt neu erzeugt
- [ ] Nichts auf einem Gerät von Henning gestartet

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Messwerkzeug im Test-/Lab-Umfang, kein Produktpfad, keine neue Abhängigkeit; keine
  bestehende ADR wird gekippt.

## Changelog

- 2026-10-26: Spec aus dem Analyse-Kontext (`docs/context/feat-88-textform-spalte.md`) erstellt;
  Grundlage Entscheidung Henning 2026-10-25 (Variante A, Kommentar #70).
