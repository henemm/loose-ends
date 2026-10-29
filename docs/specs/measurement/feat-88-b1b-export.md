---
entity_id: feat-88-b1b-export
type: feature
created: 2026-10-29
updated: 2026-10-29
status: draft
---

# Spec: #88 Schnitt B1b (ohne Gerät) — Export der eigenen Rohsätze aus dem Datenspeicher

**Status:** draft · **Workflow:** feat-88-b1b-export · **Erstellt:** 2026-10-29 · **Aktualisiert:** 2026-10-29

## Freigabe

- [ ] Freigegeben

## Problem
Die Auswertung der echten Rohsätze (Schnitt A, PR #733) und der Läufer, der ihren Korpus laut meldet (B1a, PR #736), sind
gemergt. Es fehlt der Weg, auf dem die Datei `docs/reference/loose-ends-rawtexts.json` entsteht. Ohne ihn bleibt die
Messung an Hennings eigenen Sätzen ein Plan: niemand kann die Datei erzeugen, und von Hand abtippen wäre weder
nachvollziehbar noch fehlerfrei.

## Zweck
Ein Werkzeug, das den Datenspeicher der normalen Mac-App nur lesend öffnet und daraus je Aufgabe eine Zeile im Format
von `RawSentenceColumn.Sentence` schreibt. Die Wahrheit liegt schon im Speicher: jede Korrektur des Nutzers an Titel
oder Dauer ist eine `Revision` mit Autor `user`. Das Werkzeug misst nichts und bewertet nichts, es übersetzt nur.

**Ohne Modell:** Das Ganze ist reine Datenumformung (Tabellen lesen, Werte kopieren). Ein Modell oder eine Regel kommt
nicht vor; die Regel-Spalte der Auswertung wird hier nicht berührt.

## Quelle
- **Dateien:** `Measurement/RawSentenceColumn.swift` (Zielformat, nur gelesen), `Shared/Persistence/ModelContainerFactory.swift` (Name und App-Gruppe des Speichers), `Shared/Models/Revision.swift`,
  `Shared/Services/FieldCodec.swift` (beide nur zum Nachlesen der Namen und der Kodierung, nicht im Bau des Skripts), `scripts/export-focusblox-corpus.swift` (Vorbild für den
  Lesezugriff), `.gitignore` (Zeile für die Zieldatei steht schon), `docs/context/88-b1b-export.md`
- **Bezeichner:** `RawSentenceColumn.Sentence`, `RawSentenceColumn.decode`, `Revision.fieldRaw/oldValue/newValue/authorRaw`

## Entscheidungen (hier festgelegt)
1. **Die Umformung steht in einer Messdatei, das Skript ist dünn.** `Measurement/RawTextExport.swift` (rein, ohne
   `import LooseEnds`, mit `import SQLite3`) liest die Datenbank, baut die Sätze, prüft das Ziel, schreibt die Datei und
   bildet die Zusammenfassung (`run(store:out:root:)`, `checkTarget`, `summary`). `scripts/export-loose-ends-rawtexts.swift`
   liest nur die Aufrufargumente, ruft `run` auf und gibt dessen Text oder Fehler aus. Grund: Die Unit-Tests laufen im iOS-Simulator
   (Regel „Tests nie auf dem Mac“), dort gibt es kein `Process`. Ein Test kann also kein Skript starten, wohl aber die
   Messdatei direkt aufrufen. Gebaut wird von außen, mit `swiftc -parse-as-library` aus der Messdatei und dem Skript (Befehl unter „Technische Umsetzung“).
   Verworfen: das gesamte Verhalten im Skript (dann ist der Test nur ein Aufruf von außen, im Simulator unmöglich).
2. **Swift, nicht Python; ohne `Shared/`.** Der Zwei-Dateien-Bau kennt weder `FieldSource` noch `FieldCodec`. Dasselbe gilt für
   `RawSentenceColumn.swift`: Sie ruft `RawTextWords` aus `Shared/` auf und liegt deshalb nicht im Bau. Die Messdatei
   definiert ein eigenes Ausgabe-Struct `RawTextExport.Row` (`Encodable`) mit denselben Schlüsseln wie
   `RawSentenceColumn.Sentence`; der Test lädt die Ausgabe mit dem echten `RawSentenceColumn.decode` und fängt so jede
   Abweichung der Schlüssel. Die Messdatei führt außerdem drei Konstanten selbst: Autor `"user"` sowie die Feldnamen `"title"` und `"duration"`, und sie dekodiert
   nichts: `FieldCodec.encode` speichert Titel als einfachen Text und Dauer als Rohwert der Stufe (`.title: task.title`,
   `.duration: task.durationRaw`), also steht in `oldValue`/`newValue` schon der Klartext. Dass die Konstanten zum Modell
   passen, beweist der Test: Er füllt den Speicher mit der echten Modellschicht über `FieldSource.user.rawValue` und
   `RevisedField.title.rawValue`; ändert jemand einen Namen, wird der Test rot. Die Ausgabe lädt der Test mit
   `RawSentenceColumn.decode`. Verworfen: Python (kürzer, aber ein zweiter Ort für dieselben Namen).
3. **Nur lesend, nie in einen versionierten Pfad.** Die Datenbank wird mit `SQLITE_OPEN_READONLY` geöffnet. Geschrieben wird
   nur nach `docs/reference/` des Arbeitsstands oder außerhalb des Arbeitsstands; jedes andere Ziel innerhalb davon
   verweigert `checkTarget` (AC-10). „Arbeitsstand“ ist der Repo-Stamm, den das Skript aus seinem eigenen Ort
   (`#filePath`, eine Ebene über `scripts/`) ableitet und als `root` übergibt; die Regel ist ein Pfadpräfix-Vergleich
   nach `standardizedFileURL`, kein Programmaufruf.
4. **Der echte Speicher wird in diesem Schnitt nicht berührt.** Bau und Test laufen gegen einen Wegwerf-Speicher. Der
   erste Lauf auf Hennings echtem Speicher gehört zu B2 und braucht sein wörtliches „jetzt ist ein Test möglich“.

## Ableitung je Aufgabe

| Feld der Ausgabe | Quelle |
|---|---|
| `id` | laufende Nummer ab 1 in Reihenfolge von `capturedAt`, als Text; keine App-Id |
| `rawText` | `TaskItem.rawText` |
| `capturedAt` | `TaskItem.capturedAt`, ISO 8601 |
| `titleBefore` | `oldValue` der ersten Nutzer-Revision auf `title` (fehlt der Wert: leerer Text); ohne solche Revision der aktuelle `title` (fehlt er: leerer Text) |
| `titleUser` | `newValue` der letzten Nutzer-Revision auf `title` (fehlt der Wert: leerer Text); ohne solche Revision weggelassen |
| `durationUser` | `newValue` der letzten Nutzer-Revision auf `duration`; ohne solche Revision oder bei leerem Wert weggelassen |
| `lang` | weggelassen (das Modell kennt kein Sprachfeld) |

„Nutzer-Revision“ heißt `authorRaw == FieldSource.user.rawValue`. „Erste“ und „letzte“ ordnet `createdAt`.

## Acceptance Criteria

- **AC-1:** Kette Modell → Datei → Läufer. Given ein Wegwerf-Speicher, den die echte Modellschicht (SwiftData, Datei auf der
  Platte) mit Aufgaben und Revisionen gefüllt hat / When `RawTextExport` ihn liest und die Ausgabe geschrieben wird / Then
  lädt `RawSentenceColumn.decode` sie ohne Fehler, `Corpus.entries(from:)` (die Formaterkennung, auf der `Corpus.loadReport`
  aus B1a aufsetzt) erkennt sie als Rohsatz-Datei und liefert Einträge, und die Zahl der Sätze, die `decode` liefert, ist die Zahl der Aufgaben. Die Kunstdaten haben paarweise verschiedene Rohtexte,
  weil `Corpus.entries(from:)` Rohsätze mit gleicher Wortmenge zu einem Eintrag faltet (Auswertung, nicht Export).
  Der Test arbeitet mit den Daten der Datei in einem temporären Ordner; Suchort und Meldungen von `loadReport` sind B1a und
  hier nicht erneut Gegenstand.
- **AC-2:** Korrigierter Titel. Given eine Aufgabe, deren Titel der Nutzer einmal geändert hat / When der Export läuft / Then
  ist `titleBefore` der alte Wert, `titleUser` der neue, und `titleCorrected` der Auswertung ist wahr.
- **AC-3:** Mehrere Korrekturen. Given eine Aufgabe mit zwei Nutzer-Revisionen auf `title` / When der Export läuft / Then ist
  `titleBefore` der `oldValue` der ersten und `titleUser` der `newValue` der letzten nach `createdAt`, unabhängig von der
  Reihenfolge der Zeilen in der Datenbank.
- **AC-4:** Unkorrigiert. Given eine Aufgabe ohne Nutzer-Revision auf `title` / When der Export läuft / Then ist `titleBefore`
  der aktuelle Titel und `titleUser` fehlt; Revisionen anderer Autoren (Modell, Regel) ändern daran nichts.
- **AC-5:** Dauer. Given eine Aufgabe mit Nutzer-Revision auf `duration` / When der Export läuft / Then steht ihr `newValue` in
  `durationUser`; eine Revision anderer Autoren oder eine leere Dauer lässt das Feld weg.
- **AC-6:** Leerer Titel. Given eine Aufgabe, deren Titel der Nutzer geleert hat / When der Export läuft / Then ist `titleUser`
  der leere Text (nicht weggelassen) und `titleCorrected` ist falsch, weil ein leerer Titel keine Korrektur ist.
- **AC-7:** Reihenfolge und Ids. Given mehrere Aufgaben in beliebiger Speicherreihenfolge / When der Export läuft / Then sind
  die Sätze nach `capturedAt` geordnet und tragen die Ids „1“, „2“, … ohne Lücke; keine App-Id und kein Uuid-Text steht
  in der Datei.
- **AC-8:** Nur lesend. Given ein Wegwerf-Speicher / When der Export läuft / Then ist die Datenbank danach byte-gleich
  (Prüfsumme vor und nach), es entsteht keine `-journal`-, `-wal`- oder `-shm`-Datei, die vorher fehlte; ein Schreibversuch wäre ein
  Fehler der Öffnungsart.
- **AC-9:** Laut statt leer. Given ein Pfad ohne Datei, eine Datei, die keine Datenbank ist, oder eine Datenbank ohne die
  erwarteten Tabellen / When `RawTextExport.run` läuft / Then bricht es mit einer benannten Ursache ab (Art und Pfad, nie Inhalt) und
  schreibt keine Ausgabedatei (der Test prüft, dass das Ziel danach nicht existiert und eine vorhandene Datei unverändert bleibt); eine Datenbank ohne Aufgaben schreibt keine leere Liste, sondern bricht mit „keine Aufgaben“ ab.
- **AC-10:** Ziel geschützt. Given ein Ausgabepfad und der Repo-Stamm `root` / When `RawTextExport.checkTarget(_, root:)`
  läuft / Then verweigert es jeden Pfad unter `root`, der nicht unter `root/docs/reference/` liegt (auch über `..` oder
  einen Symlink erreicht), mit einer Meldung, und erlaubt `root/docs/reference/…` sowie Pfade außerhalb von `root`
  (z. B. einen temporären Ordner); `run` schreibt bei Verweigerung nichts.
- **AC-11:** Keine Sätze in Meldungen. Given Kunstdaten mit Marker-Wörtern im Rohtext / When der Export einen Fehler meldet oder
  eine Zusammenfassung ausgibt / Then enthalten Fehlertexte und die Zusammenfassung (`RawTextExport.summary`) nur Zahlen und Pfade („N Sätze, davon M mit
  Titelkorrektur, K mit Dauer“), keinen Satz.
- **AC-12:** Aufrufweise belegt. Given `docs/reference/messung-rohsaetze.md` / When man den Export nachschlägt / Then steht dort der Aufruf
  (Bau mit `swiftc`, der Standardpfad des Speichers der normalen Mac-App, Ziel) in einer Zeile, und der Hinweis, dass der Lauf auf dem
  echten Speicher erst nach Hennings „jetzt ist ein Test möglich“ geschieht (B2).

## Nicht in diesem Schnitt
- Der Lauf gegen Hennings echten Speicher, der Laborlauf, der Messbericht (B2) und jede Aktion auf einem seiner Geräte.
- Ein Export-Knopf in der App, ein CloudKit-Weg (siehe Alternativen).
- Änderungen an `RawSentenceColumn`, `Corpus`, dem Läufer oder dem Produktcode. Keine echte Rohsatz-Datei im Repository.

## Abhängigkeiten

| Baustein | Art | Zweck |
|----------|-----|-------|
| `RawSentenceColumn.decode` | Funktion | Zielformat, im Test als Gegenprobe |
| `Revision`, `FieldCodec`, `FieldSource.user` | Modell | Herkunft und Kodierung der Werte |
| `import SQLite3` | Systembibliothek | lesen; auf iOS und macOS vorhanden, keine neue Abhängigkeit |
| `scripts/export-focusblox-corpus.swift` | Vorbild | Öffnungsart und Spaltenlesen |
| #71 | Ticket | derselbe Gerätedurchgang später, hier nicht berührt |

## Umfang

### Betroffene Dateien

| Datei | Änderungsart | Beschreibung |
|-------|---------------|--------------|
| `Measurement/RawTextExport.swift` | CREATE | liest nur lesend, baut die Sätze, `checkTarget`, `run` (schreibt), `summary` (AC-2 bis AC-11) |
| `scripts/export-loose-ends-rawtexts.swift` | CREATE | dünn: Argumente, `root` aus `#filePath`, ruft `run`, gibt Text aus |
| `LooseEndsTests/RawTextExportTests.swift` | CREATE | Wegwerf-Speicher mit der echten Modellschicht, Prüfung von AC-1 bis AC-11 |
| `docs/reference/messung-rohsaetze.md` | CREATE | Aufrufweise in einer Zeile (AC-12) |
| `CLAUDE.md` | MODIFY | eine Zeile zu `Measurement/` (Export) |

### Geschätzter Umfang
- Dateien: **5**, innerhalb der Grenze. Zeilen: etwa +230 / −0. Funktionen bleiben unter 50 Zeilen.
- `Measurement/` kompiliert in die Test-Bündel und die Labor-App, nicht in den Produktpfad; es kommt keine neue Quelle
  in `project.yml`.

## Technische Umsetzung
`RawTextExport.sentences(fromStoreAt:)` öffnet die Datei mit `SQLITE_OPEN_READONLY`, liest `ZTASKITEM` (`ZRAWTEXT`,
`ZCAPTUREDAT`, `ZTITLE`, Schlüssel) und `ZREVISION` (`ZFIELDRAW`, `ZOLDVALUE`, `ZNEWVALUE`, `ZAUTHORRAW`, `ZCREATEDAT`,
Verweis auf die Aufgabe) und gruppiert die Revisionen je Aufgabe. Datumsspalten sind Sekunden seit 2001-01-01 und werden
mit `Date(timeIntervalSinceReferenceDate:)` zu ISO 8601. Die genauen Spalten- und Tabellennamen sind aus dem Wegwerf-Speicher
abzulesen (`PRAGMA table_info`), nicht zu raten; der Test legt sie als Erwartung fest, damit eine Änderung des Modells
laut auffällt. Fehler sind ein `enum Failure: Error` mit deutscher Beschreibung ohne Inhalte. Das Skript enthält keinen Top-Level-Code, sondern einen `@main`-Einstieg (nötig für `-parse-as-library`). Es kennt genau zwei Argumente: `--store <Pfad>` (Datenbankdatei; ohne Angabe der Standardspeicher der normalen
Mac-App; sein Pfad ist eine Konstante im Skript: `~/Library/Group Containers/group.com.henning.looseends/Library/Application
Support/LooseEnds.store`, abgeleitet aus `ModelContainerFactory` (Konfigurationsname „LooseEnds“, App-Gruppe
`group.com.henning.looseends`); er wird beim Bau nur als Text festgelegt, nie geöffnet, und AC-12 verlangt ihn in der Doku) und `--out <Pfad>` (ohne Angabe
`<root>/docs/reference/loose-ends-rawtexts.json`); jedes andere Argument bricht mit der Aufrufhilfe ab. Gebaut und gestartet wird von außen:
`swiftc -parse-as-library Measurement/RawTextExport.swift scripts/export-loose-ends-rawtexts.swift -o <temporärer Ordner>/export`,
damit kein Binary im Arbeitsstand liegt.

**Alternativen** (der bisherige Weg ist hier schon die einfachste Lösung, keine Gegenentscheidung nötig):
(B) Export-Knopf in der App: eine Produktfunktion nur für die Messung, der Datenschutztext (#705) müsste mit; verworfen.
(C) Auslesen über CloudKit: privater Container, das Verwaltungs-Token liest keine Nutzerdaten; scheidet aus.
(D) Kein Export, die Sätze aus der Mac-App per Hand kopieren: nicht nachvollziehbar, nicht wiederholbar; verworfen.
Es wird keine ADR gekippt.

## Testplan

### Automatisierte Tests (TDD RED)
`RawTextExportTests.swift` legt mit der echten Modellschicht eine SwiftData-Datei in einem temporären Ordner an (Container
lokal gehalten, damit kein Absturz beim Speichern entsteht), mit Kunstdaten ohne echte Sätze:
- [ ] `exportLoadsWithRawSentenceDecoderAndCorpusEntries` — ganze Kette über `run`, Anzahl der Sätze (AC-1)
- [ ] `correctedTitleCarriesBeforeAndAfter` (AC-2), `severalRevisionsUseFirstOldAndLastNew` mit vertauschter Speicherreihenfolge (AC-3)
- [ ] `uncorrectedTaskKeepsCurrentTitleAndIgnoresNonUserRevisions` (AC-4)
- [ ] `durationFromLastUserRevision` und `nonUserOrEmptyDurationIsOmitted` (AC-5)
- [ ] `clearedTitleIsEmptyTextAndNoCorrection` (AC-6)
- [ ] `sentencesAreOrderedAndNumbered` und `outputHasNoApplicationIds` (AC-7)
- [ ] `exportLeavesStoreUntouched` — Prüfsumme vor/nach, keine neue `-wal`/`-shm`/`-journal`-Datei (AC-8)
- [ ] `missingFileNotADatabaseMissingTablesAndNoTasksFailLoudly` — vier Fälle über `run`, Ziel existiert danach nicht, vorhandene Datei bleibt (AC-9)
- [ ] `writeFixtureStoreForScriptRun` und `readScriptResult` — Hilfstests für die Abnahme Stufe 2, nur mit gesetzter
  Umgebungsvariable aktiv (sonst einzeln als übersprungen benannt): der erste legt den Kunst-Speicher in
  `LOOSEENDS_EXPORT_FIXTURE_DIR` ab, der zweite lädt die vom Skript geschriebene Datei `LOOSEENDS_EXPORT_RESULT` mit
  `RawSentenceColumn.decode`
- [ ] `outputPathGuard` — `docs/reference` und temporärer Ordner erlaubt; Pfad unter `root` außerhalb von `docs/reference`, mit `..` und per Symlink verweigert, `run` schreibt dann nichts (AC-10)
- [ ] `messagesCarryNoSentences` — Marker-Wörter im Rohtext fehlen in Fehlern und in `summary` (AC-11)

Die Reihenfolge in AC-3 und der leere Titel in AC-6 sind die Stellen, an denen ein Testaufbau, der seinen Ausgangszustand
selbst herstellt, die Kette nicht schließen würde; deshalb schreibt die Modellschicht die Datei und nicht der Test von Hand.

### Abnahme Stufe 2 (Durchlauf, Pflicht)
1. Ein Hilfstest `writeFixtureStoreForScriptRun` in `RawTextExportTests` legt denselben Kunst-Speicher als Datei `fixture.store` an einem festen
   Ort ab, den der Lauf per Umgebungsvariable übergibt, nach dem Repo-Muster von `sim.sh` (`TEST_RUNNER_`-Präfix, wie
   `TEST_RUNNER_LOOSEENDS_LATENCY_OUT`): `TEST_RUNNER_LOOSEENDS_EXPORT_FIXTURE_DIR=<Ordner unter dem Scratchpad>
   ./scripts/sim.sh sim-unit RawTextExportTests`. Der Test liest `LOOSEENDS_EXPORT_FIXTURE_DIR` (Simulator-Prozesse
   schreiben ins Dateisystem des Macs). Ohne die Variable ist der Test übersprungen und wird im
   Abschlussbericht einzeln als solcher benannt; im regulären Lauf und in der CI belegt er nichts außer dem Überspringen.
2. Das Skript auf dieser Wegwerf-Datenbank aufrufen: Bau mit `swiftc` wie unter „Technische Umsetzung“, Lauf mit **beiden** Argumenten
   ausdrücklich gesetzt, `--store <Ordner aus Punkt 1>/fixture.store` und `--out <Scratchpad>/rawtexts-fixture.json`, nie ohne
   `--store` (der Standardspeicher ist der echte und bleibt in diesem Schnitt unberührt); Zusammenfassung lesen; danach
   `TEST_RUNNER_LOOSEENDS_EXPORT_RESULT=<Ausgabedatei> ./scripts/sim.sh sim-unit RawTextExportTests` lässt `readScriptResult`
   die Datei mit `RawSentenceColumn.decode` laden. Die Ausgabe wird außerdem geöffnet und beschrieben, nicht nur gezählt.
3. AC-12: `grep` auf die Aufrufzeile und den Hinweis „jetzt ist ein Test möglich“ in `docs/reference/messung-rohsaetze.md`.
4. Danach die ganze Unit-Suite im Simulator (`./scripts/sim.sh sim-unit`) und die CI.

Keine UI-Tests: kein Produktcode, keine View. **Stufe 3:** „Kein Pfad der Geräteliste berührt.“ **Nichts auf Hennings Geräten
und sein echter Speicher nicht gelesen** — das gehört zu B2 nach seinem wörtlichen „jetzt ist ein Test möglich“.

## Definition of Done

- [ ] AC-1 bis AC-11 erfüllt, belegt durch Tests und den Durchlauf auf dem Wegwerf-Speicher; AC-12 belegt durch `grep` (Stufe 2, Punkt 3)
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh sim-unit`), CI grün, PR gemergt; #88 bleibt mit B2 offen
- [ ] Hauptordner nachgezogen und Projekt neu erzeugt
- [ ] Keine echte Rohsatz-Datei und kein echter Satz in Repository, Artefakten oder Kommentaren
- [ ] Nichts auf einem Gerät von Henning gestartet, sein echter Speicher nicht gelesen
- [ ] `CLAUDE.md` (Zeile zu `Measurement/` und dem Export) und Issue #88 aktualisiert

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Messwerkzeug, kein Produktpfad, keine neue Abhängigkeit; keine bestehende ADR wird gekippt.

## Changelog

- 2026-10-29: Vierter Validator-Befund: AC-1 prüft `Corpus.entries(from:)` auf den Dateidaten statt `loadReport` (dessen Suchort
  fände einen temporären Ordner nie), Hilfstests für Stufe 2 in die Testliste, AC-12 in der Definition of Done ehrlich per `grep`.
- 2026-10-29: Dritter Validator-Befund: eigenes Ausgabe-Struct statt `RawSentenceColumn.swift` im Bau (diese Datei
  braucht `Shared/`), `TEST_RUNNER_`-Umgebungsvariable nach Repo-Muster, Lesequellen in der Quelle als „nur nachlesen“ markiert.
- 2026-10-29: Zweiter Validator-Befund: Konstanten statt `Shared/` im Zwei-Dateien-Bau festgelegt und durch den Test
  gesichert, Hilfstest für den Skriptdurchlauf der Stufe 2 benannt, `-shm` in AC-8.
- 2026-10-29: Nach Validator-Befund: Zielprüfung, Schreiben und Zusammenfassung als reine Funktionen in die Messdatei
  (testbar im Simulator), „Arbeitsstand“ als Pfadpräfix definiert, Doku-Datei und `CLAUDE.md` benannt (5 Dateien).
- 2026-10-29: Spec aus `docs/context/88-b1b-export.md` erstellt. Abweichung von der Analyse: Die Umformung steht in
  `Measurement/RawTextExport.swift` statt im Skript, weil die Unit-Tests im iOS-Simulator laufen und dort kein Skript
  starten können; dadurch mehr Dateien als in der Analyse, Umfang weiter innerhalb der Grenzen.
