---
entity_id: issue-82-satzformen
type: feature
created: 2026-09-20
updated: 2026-09-20
status: draft
---

# Spec: #82 — Messkorpus in Hennings Satzformen (Schnitt 1: Bauformen und Bericht)

**Status:** draft · **Workflow:** issue-82-satzformen · **Erstellt:** 2026-09-20 · **Aktualisiert:** 2026-09-20

## Freigabe

- [ ] Freigegeben

## Problem
Der Messkorpus für #67 (203 Sätze) ist in einer Form geschrieben: Zeitangabe vorn, Objekt, Verb
hinten. Hennings 108 echte Rohsätze aus FocusBlox sind anders: ein Drittel Stichwörter ohne Verb,
Fragen an sich selbst, Schlüsselwort-Präfixe („Heute dringend …"), Diktatfehler in Namen („Dativ"
für Datev), nur 12 % mit Zeitangabe. Eine Trefferquote aus dem bisherigen Korpus sagt also, wie das
Modell auf meinen Sätzen arbeitet, nicht auf seinen. Henning: „Was ich sehe ist alles ziemlich
gleich vom Aufbau her."

## Zweck
Der Messkorpus für #67 bekommt je Satz eine Bauform aus einer festen Liste, damit er die
Satzformen misst, die Henning in FocusBlox tatsächlich benutzt (Stichwörter, Fragen, Diktate,
Präfixe), statt nur die bisherige einförmige Zeit-Objekt-Verb-Struktur. Der Bericht weist die
Trefferquote danach getrennt nach Bauform aus, statt eine einzige Zahl über alle Formen zu
verwischen.

## Quelle
- **Datei:** `Measurement/Corpus.swift`
- **Bezeichner:** `struct Corpus`, `struct Corpus.Entry`

## Acceptance Criteria

- **AC-1 Bauform je Satz:** Given der Korpus / When er geladen wird / Then trägt jeder Satz eine
  Bauform aus einer festen Liste (standard, stichwort, ich-satz, nebensatz, frage, diktat,
  zeit-hinten, zwei-aufgaben, denglisch, tippfehler, praefix, diktat-name); ein Satz ohne
  Angabe gilt als `standard`. Eine unbekannte Bauform lässt den Korpustest fehlschlagen.
- **AC-2 Mindestens 100 Sätze außerhalb der Standardform:** Given der Korpus / When gezählt wird /
  Then stehen mindestens 100 Sätze in anderen Bauformen als `standard`, jede Bauform mit
  mindestens 6 Sätzen, jeder mit Wahrheit als Regel gegen den Messtag wie bisher (Datum, Uhrzeit,
  Entitäten, Personen).
- **AC-3 Formen sind echt:** Given ein Satz mit Bauform / When der Korpustest läuft / Then hält
  er die Form: Stichwort höchstens 3 Wörter, Frage endet mit „?", Ich-Satz beginnt mit „ich",
  Diktat klein geschrieben und ohne Komma. Entitäten stehen wörtlich im Rohtext, auch bei
  Tipp- und Diktatfehlern (der Fehler ist Teil des Satzes).
- **AC-4 Bericht nach Bauform:** Given geholte Messläufe / When der Bericht gebaut wird / Then
  enthält er den Abschnitt „Nach Bauform" mit einer Zeile je Bauform: Sätze, Datum exakt (Anteil
  und Anzahl), Datum erfunden (Anteil und Anzahl), Titel ohne erfundene Fakten. Ein Kriterium ohne
  Sätze zeigt „–", nie 0 % oder 100 %.
- **AC-5 Alte Leser bleiben intakt:** Given der erweiterte Korpus / When Labor-App, Bericht und
  der Reminders-Benchmark (#78) ihn laden / Then laden sie ohne Änderung; die Labor-App holt die
  neuen Sätze beim nächsten Lauf nach, ohne gemessene Sätze zu wiederholen.
- **AC-6 Bestehende Tests:** Given der Funktionsumfang / When Unit-Tests laufen / Then bleiben
  alle grün, einschließlich Regelwerk, Messlauf-Datei und Bericht.

## Nicht in diesem Schnitt
- Hennings 108 Rohsätze als zweiter Korpusteil mit seiner Wahrheit je Satz und die Gewichtung der
  Kriterien nach seiner realen Verteilung: eigenes Sub-Issue, weil Export, Wahrheitsformat für
  einen Nicht-Entwickler und Messung gegen ein festes Erfassungsdatum dazukommen.
- Eine neue Messung auf dem iPhone: die Labor-App wird neu installiert, den Lauf startet Henning
  selbst (kein Fernstart, siehe Memory).

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `Corpus.load()` | Funktion | Lädt den Korpus für das Test-Bundle, die Labor-App (`LooseEndsLab/MeasurementRunner.swift`) und den Reminders-Benchmark (#78); unbekannte JSON-Schlüssel werden ignoriert, alte Leser bleiben intakt. |
| `MeasurementRunner.remaining(from:)` | Funktion | Ermittelt beim nächsten Labor-Lauf die offenen (noch nicht gemessenen) Sätze; neue IDs werden automatisch nachgeholt, ohne den laufenden Messstand zu wiederholen. |

## Umfang

### Betroffene Dateien

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/date-title-corpus.json` | MODIFY | 114 neue Sätze in 11 Bauformen mit Regel-Wahrheit; 9 bestehende Sätze (`de-diktat-*`, `en-dictation-*`, `de-lang-2..4`) nachträglich als `diktat`/`nebensatz` markiert. |
| `Measurement/Corpus.swift` | MODIFY | `form` je Eintrag (Default `standard`), `Corpus.forms`, `Corpus.standardForm`. |
| `LooseEndsTests/DateTitleReportTests.swift` | MODIFY | `FormTally`, `byForm`, Abschnitt „Nach Bauform" mit Datum exakt, Datum erfunden und Titel-Fakten je Bauform. |
| `LooseEndsTests/CorpusTests.swift` | MODIFY | RED-Test `corpusHasSentenceForms` (liegt vor): prüft AC-1, AC-2, AC-3. |
| `docs/project/04-stand.md` | MODIFY | Korpuszahl in der Messstrecke-Zeile. |

### Geschätzter Umfang
- Dateien: 5 (innerhalb der 4–5-Dateien-Grenze)
- Zeilen: Code etwa +60 (Corpus.swift +12, Report +35, Tests +45 liegen bereits als RED vor);
  Daten +114 Zeilen JSON

## Technische Umsetzung
Bauform als optionaler JSON-Schlüssel `form` nach dem bestehenden Muster für optionale Felder
(`private var xList: String?` plus berechnete Eigenschaft mit Default, wie bei `entities` und
`people`); ein fehlender Schlüssel heißt `standard`. Der Bericht führt je Bauform drei Zählwerke
(Datum exakt, Datum erfunden, Titel ohne erfundene Fakten), weil die Kriterien pro Form
auseinanderlaufen können — eine Form kann beim Datum gut und beim Titel schlecht abschneiden. Die
neuen Sätze werden per Skript angehängt (Wahrheit als Regel, Entitäten wörtlich aus dem Rohtext);
das Skript bleibt außerhalb des Repos, der Korpus selbst ist die Quelle. Formprüfungen im Test
(Stichwort höchstens 3 Wörter, Frage endet mit „?", Ich-Satz beginnt mit „ich", Diktat klein und
ohne Komma) verhindern, dass eine Form nur dem Namen nach existiert. Entitäten bei Tipp- und
Diktatfehlern werden wie getippt geführt („Dativ", „Öz Demir") — korrigiert das Modell, zählt das
als verlorene Entität; das ist der gewollte Befund. Namens-Tippfehler bekommen darum keinen
`people`-Eintrag, sonst würde die Korrektur über `alteredNames` fälschlich als erfundener Fakt
gezählt.

## Testplan

### Automatisierte Tests (TDD RED)
- [ ] `CorpusTests.corpusHasSentenceForms` (liegt vor, RED): GIVEN der Korpus / WHEN er geladen
  wird / THEN trägt jeder Satz eine Bauform aus der festen Liste, stehen mindestens 100 Sätze
  außerhalb `standard` mit mindestens 6 Sätzen je Bauform, und hält jede Form ihre Formprüfung
  (AC-1, AC-2, AC-3).
- [ ] `DateTitleReportTests.DateTitleFormSectionTests` (liegt vor, RED): GIVEN geholte Messläufe /
  WHEN der Bericht gebaut wird / THEN enthält er den Abschnitt „Nach Bauform" mit Datum exakt,
  Datum erfunden und Titel-Fakten je Bauform, und „–" statt 0 %/100 % bei leeren Kriterien (AC-4).
- [ ] Bestehende Suiten (`corpusIsSound`, Messlauf-Datei-Tests, Report-Tests): GIVEN der erweiterte
  Korpus / WHEN bestehende Leser (Labor-App, Bericht, #78-Benchmark) ihn laden / THEN bleiben sie
  unverändert lauffähig, keine Regression (AC-5, AC-6).

Kein UI-Test: kein Produktcode, keine View betroffen. Nachweis auf dem Gerät: `sim.sh lab`
installiert die Labor-App mit dem neuen Korpus; Hennings nächster Lauf zeigt „x von 317".

## Definition of Done

- [ ] AC-1 bis AC-6 erfüllt, belegt durch die genannten Tests
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh unit`), CI grün
- [ ] Korpuszahl in `docs/project/04-stand.md` aktualisiert
- [ ] PR mit `Closes` auf ein Sub-Issue von #82 (Schnitt 1) gemergt; Hennings Hauptordner nachgezogen und Projekt neu erzeugt
- [ ] Labor-App mit dem neuen Korpus auf Hennings iPhone installiert (`./scripts/sim.sh lab`), kein Fernstart
- [ ] Sub-Issue für Schnitt 2 (Hennings Rohsätze, Gewichtung) angelegt und in #82 verlinkt

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Additive Erweiterung eines bestehenden Feldmusters (optionaler JSON-Schlüssel mit
  Default, wie bereits bei `entities`/`people`). Kein neuer Architekturbaustein, keine neue
  Abhängigkeit, kein Eingriff in Produktcode — daher keine ADR nötig.

## Changelog

- 2026-09-20: Spec aus dem Analyse-Kontext (`docs/context/issue-82-satzformen.md`) erstellt;
  Pflichtfelder (Status, Freigabe, Zweck, Quelle, Abhängigkeiten, Umfang-Tabelle, ADR, Changelog)
  gegenüber dem Entwurf ergänzt.
