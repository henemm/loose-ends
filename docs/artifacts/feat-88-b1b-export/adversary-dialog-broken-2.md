# Adversary Dialog — feat-88-b1b-export
Spec: docs/specs/measurement/feat-88-b1b-export.md
Datum: 2026-10-29 13:42

## Checkliste
- [x] **AC-1:** Kette Modell → Datei → Läufer. Given ein Wegwerf-Speicher, den die echte Modellschicht (SwiftData, Datei auf der Platte) mit Aufgaben und Revisionen gefüllt hat / When `RawTextExport` ihn liest und die Ausgabe geschrieben wird / Then lädt `RawSentenceColumn.decode` sie ohne Fehler, `Corpus.entries(from:)` (die Formaterkennung, auf der `Corpus.loadReport` aus B1a aufsetzt) erkennt sie als Rohsatz-Datei und liefert Einträge, und die Zahl der Sätze, die `decode` liefert, ist die Zahl der Aufgaben. Die Kunstdaten haben paarweise verschiedene Rohtexte, weil `Corpus.entries(from:)` Rohsätze mit gleicher Wortmenge zu einem Eintrag faltet (Auswertung, nicht Export). Der Test arbeitet mit den Daten der Datei in einem temporären Ordner; Suchort und Meldungen von `loadReport` sind B1a und hier nicht erneut Gegenstand.
- [x] **AC-2:** Korrigierter Titel. Given eine Aufgabe, deren Titel der Nutzer einmal geändert hat / When der Export läuft / Then ist `titleBefore` der alte Wert, `titleUser` der neue, und `titleCorrected` der Auswertung ist wahr.
- [x] **AC-3:** Mehrere Korrekturen. Given eine Aufgabe mit zwei Nutzer-Revisionen auf `title` / When der Export läuft / Then ist `titleBefore` der `oldValue` der ersten und `titleUser` der `newValue` der letzten nach `createdAt`, unabhängig von der Reihenfolge der Zeilen in der Datenbank.
- [x] **AC-4:** Unkorrigiert. Given eine Aufgabe ohne Nutzer-Revision auf `title` / When der Export läuft / Then ist `titleBefore` der aktuelle Titel und `titleUser` fehlt; Revisionen anderer Autoren (Modell, Regel) ändern daran nichts.
- [x] **AC-5:** Dauer. Given eine Aufgabe mit Nutzer-Revision auf `duration` / When der Export läuft / Then steht ihr `newValue` in `durationUser`; eine Revision anderer Autoren oder eine leere Dauer lässt das Feld weg.
- [x] **AC-6:** Leerer Titel. Given eine Aufgabe, deren Titel der Nutzer geleert hat / When der Export läuft / Then ist `titleUser` der leere Text (nicht weggelassen) und `titleCorrected` ist falsch, weil ein leerer Titel keine Korrektur ist.
- [x] **AC-7:** Reihenfolge und Ids. Given mehrere Aufgaben in beliebiger Speicherreihenfolge / When der Export läuft / Then sind die Sätze nach `capturedAt` geordnet und tragen die Ids „1“, „2“, … ohne Lücke; keine App-Id und kein Uuid-Text steht in der Datei.
- [x] **AC-8:** Nur lesend. Given ein Wegwerf-Speicher / When der Export läuft / Then ist die Datenbank danach byte-gleich (Prüfsumme vor und nach), es entsteht keine `-journal`-, `-wal`- oder `-shm`-Datei, die vorher fehlte; ein Schreibversuch wäre ein Fehler der Öffnungsart.
- [x] **AC-9:** Laut statt leer. Given ein Pfad ohne Datei, eine Datei, die keine Datenbank ist, oder eine Datenbank ohne die erwarteten Tabellen / When `RawTextExport.run` läuft / Then bricht es mit einer benannten Ursache ab (Art und Pfad, nie Inhalt) und schreibt keine Ausgabedatei (der Test prüft, dass das Ziel danach nicht existiert und eine vorhandene Datei unverändert bleibt); eine Datenbank ohne Aufgaben schreibt keine leere Liste, sondern bricht mit „keine Aufgaben“ ab.
- [ ] **AC-10:** Ziel geschützt. Given ein Ausgabepfad und der Repo-Stamm `root` / When `RawTextExport.checkTarget(_, root:)` läuft / Then verweigert es jeden Pfad unter `root`, der nicht unter `root/docs/reference/` liegt (auch über `..` oder einen Symlink erreicht), mit einer Meldung, und erlaubt `root/docs/reference/…` sowie Pfade außerhalb von `root` (z. B. einen temporären Ordner); `run` schreibt bei Verweigerung nichts.
- [x] **AC-11:** Keine Sätze in Meldungen. Given Kunstdaten mit Marker-Wörtern im Rohtext / When der Export einen Fehler meldet oder eine Zusammenfassung ausgibt / Then enthalten Fehlertexte und die Zusammenfassung (`RawTextExport.summary`) nur Zahlen und Pfade („N Sätze, davon M mit Titelkorrektur, K mit Dauer“), keinen Satz.
- [x] **AC-12:** Aufrufweise belegt. Given `docs/reference/messung-rohsaetze.md` / When man den Export nachschlägt / Then steht dort der Aufruf (Bau mit `swiftc`, der Standardpfad des Speichers der normalen Mac-App, Ziel) in einer Zeile, und der Hinweis, dass der Lauf auf dem echten Speicher erst nach Hennings „jetzt ist ein Test möglich“ geschieht (B2).

## Dialog

### Runde 1
**Adversary:** Alle ACs gegen Code und Test neu geprüft, den Erstdurchgang nicht übernommen. Simulator-Lauf `./scripts/sim.sh sim-unit RawTextExportTests`: 16 Tests bestanden, 0 fehlgeschlagen; 2 Hilfstests (`writeFixtureStoreForScriptRun`, `readScriptResult`) sind per `.enabled(if:)` übersprungen und stehen nicht in der Ausgabe (docs/artifacts/feat-88-b1b-export/adversary-test-output.txt). Der grüne Lauf belegt AC-10 nicht gegen die echte Aufrufweise: der Test übergibt `root` absolut und selbst.

Confirmation:
  AC: AC-1
  Code reference: Measurement/RawTextExport.swift:177
  Evidence: `run` prüft das Ziel, liest, schreibt zuletzt atomar. Test exportLoadsWithRawSentenceDecoderAndCorpusEntries (LooseEndsTests/RawTextExportTests.swift:94) lädt mit decode (3 Sätze) und Corpus.entries (3). Gegenprobe: Skript auf Kopie des Wegwerf-Speichers, Ausgabe mit 2 Sätzen, Schlüssel passend.
  Status: CONFIRMED

Confirmation:
  AC: AC-2, AC-3, AC-4, AC-5, AC-6
  Code reference: Measurement/RawTextExport.swift:114
  Evidence: `row(for:)` nimmt die erste Nutzer-Revision für titleBefore, die letzte für titleUser und durationUser; leere Dauer fällt über flatMap weg; geleerter Titel wird "" und nicht nil. Revisionen sind nach (createdAt, Z_PK-Position) sortiert (Zeile 111); die Tests fügen absichtlich gegen die Zeitfolge ein (RawTextExportTests.swift:131, :158, :169) und laden mit dem echten Leser (titleCorrected wahr bzw. falsch).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Measurement/RawTextExport.swift:86
  Evidence: Sortierung nach (capturedAt, Z_PK), Ids ab 1 per enumerated(); Test sentencesAreOrderedAndNumbered (RawTextExportTests.swift:243) mit umgekehrter Einfügung, dazu der UUID-Regex-Test.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Measurement/RawTextExport.swift:198
  Evidence: `SQLITE_OPEN_READONLY`. Test exportLeavesStoreUntouched (RawTextExportTests.swift:267) prüft SHA-256 und Ordnerinhalt nach `settle`. Gegenprobe: eine Kopie mit vorhandenen -wal/-shm lässt sich lesen; ohne Nebendateien Code 14 mit Hinweis, nichts geschrieben.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Measurement/RawTextExport.swift:79
  Evidence: vier Fehlerfälle (fehlend, keine DB, fremde Tabellen, keine Aufgaben) werfen Failure vor dem Schreiben; Test RawTextExportTests.swift:287 prüft Ziel fehlt bzw. unverändert. Gegenprobe Ordner ohne Schreibrecht: Meldung "Schreiben fehlgeschlagen", vorhandene Datei bleibt, kein Rest.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: Measurement/RawTextExport.swift:43
  Evidence: Failure.message nennt nur Art, Code und Pfad; `summary` (Zeile 166) nur Zahlen; Test RawTextExportTests.swift:407 mit Marker-Wort.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: scripts/export-loose-ends-rawtexts.swift:15
  Evidence: docs/reference/messung-rohsaetze.md enthält die Aufrufzeile in einer Zeile (swiftc, Standardspeicher, Ziel) und den Abschnitt "Echter Speicher erst nach Hennings Wort" mit dem Wortlaut "jetzt ist ein Test möglich".
  Status: CONFIRMED

Prüfung des F001-Fixes aus Durchgang 1 (`physical`): realpath löst root-Symlink, Symlink-Elternordner, `..` hinter Symlink und /tmp gegen /private/tmp auf; mit absolutem root hält er (Test outputPathGuard, RawTextExportTests.swift:355, und meine Gegenproben in Runde 2). Test-Fixture-Falle: `equalCreatedAtFallsBackToRowOrder` ist nicht zirkulär, weil die Erwartung aus der Datei kommt (Z_PK-Reihenfolge) und der Export sie unabhängig über ORDER BY Z_PK ableitet; schwach nur, falls SwiftData Z_PK stets in Einfügereihenfolge vergibt und der Export Einfügereihenfolge statt Z_PK nähme. `walStoreWithoutSideFilesNamesTheCause` baut den Zustand real (WAL-Modus, Nebendateien nach dem Schließen entfernt) und deckt sich mit meiner Gegenprobe an der Kopie des Wegwerf-Speichers (Code 14).
**Implementierer:** (zweiter Durchgang, keine Antwort im Protokoll)

### Runde 2
**Adversary:** Eigene Gegenproben mit dem gebauten Skript (swiftc mit relativen Pfaden wie im Doku-Aufruf), Repo-Nachbau unter dem Scratchpad (adv/repo mit docs/reference, other, scripts, Symlinks), Speicher = Kopie des Wegwerf-Speichers.

Finding:
  ID: F001
  Severity: HIGH
  Category: security
  Code reference: scripts/export-loose-ends-rawtexts.swift:19
  Description: `root` kommt aus `#filePath`. Beim dokumentierten Bau mit relativem Skriptpfad ist `#filePath` relativ (strings im Binary: scripts/export-loose-ends-rawtexts.swift); `URL(fileURLWithPath:)` löst ihn zur Laufzeit gegen das aktuelle Arbeitsverzeichnis auf. Läuft das Binary nicht im Repo-Stamm, ist `root` falsch.
  Spec requirement: AC-10 — jeden Pfad unter root verweigern, der nicht unter root/docs/reference liegt; Entscheidung 3 (Repo-Stamm aus dem Ort des Skripts).
  Conflict: Reproduktion: Binary im Repo-Nachbau gebaut, Lauf mit cwd=repo/docs und --out repo/other/b.json endet mit Exit 0 und "Geschrieben", die Datei liegt in repo/other; ebenso --out repo/scripts/c.json. Mit cwd=repo kommt "Ziel verweigert". Der Schutz hängt am Arbeitsverzeichnis, nicht am Ort des Skripts. Der Test deckt das nicht, weil er root absolut übergibt.
  Remediation: Im Skript prüfen, dass #filePath mit "/" beginnt (sonst Abbruch mit Hinweis), oder den Bau mit absolutem Skriptpfad vorschreiben (Doku-Zeile); Test für den relativen Fall.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: Measurement/RawTextExport.swift:147
  Description: `physical` läuft endlos (100 % CPU), wenn der letzte Pfadbestandteil des Ziels ".." ist und der Elternordner nicht existiert. `URL.deletingLastPathComponent()` hängt bei einem Pfad mit ".." am Ende "/.." an statt zu kürzen, `existing` wächst bei jedem Durchlauf, `realpath` scheitert immer.
  Spec requirement: AC-10 — checkTarget verweigert oder erlaubt mit Meldung, ".." ist ausdrücklich genannt.
  Conflict: Reproduktion: --out repo/docs/reference/nonexist/.. und --out repo/other/nonexist/.. laufen über 5 s hinaus (ein Lauf ohne Zeitlimit lief 2:23 min bei 100 % CPU, per pkill beendet). Nichts wird geschrieben, aber der Aufruf kehrt nie zurück. Mit vorhandenem Elternordner (docs/reference/..) wird korrekt verweigert.
  Remediation: Pfad vor der Schleife über pathComponents lexikalisch normalisieren statt deletingLastPathComponent, oder die Schleife an existing == "/" und eine Schrittgrenze binden; Test mit nicht vorhandenem Ordner und ".." am Ende.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: Measurement/RawTextExport.swift:183
  Description: Eine vorhandene schreibgeschützte Zieldatei (Modus 444) wird durch das atomare Schreiben ersetzt (Modus bleibt 444, Inhalt neu). Ein Symlink als Ziel-Datei wird durch eine Datei ersetzt, nicht durchgeschrieben (geprüft: das Linkziel bleibt unberührt, gewollt laut Kommentar Zeile 146).
  Spec requirement: AC-9/AC-10 — keine Vorgabe zu Schreibschutz.
  Conflict: Kein Verstoß; Hinweis, dass Schreibschutz kein Überschreibschutz ist.
  Remediation: keine nötig; optional in der Doku erwähnen.

Gegenproben, Ergebnis (cwd = Repo-Stamm, absolute Pfade): verweigert werden docs/reference/esc/b.json (Symlink nach other), esc/../c.json, rootlink/other/d.json (root-Symlink), outside/intorepo/f.json und intorepo/newdir/g.json (Symlink von außen ins Repo, auch mit fehlendem Unterordner), docs/reference/../other/i.json, docs/reference2/j.json, other/, docs/reference/.. und docs/reference (der Ordner selbst), die /tmp-Schreibweise eines Repo-Pfads (macOS-Alias). Erlaubt und geschrieben: docs/reference/ok.json, rootlink/docs/reference/e.json sowie über abweichende Großschreibung DOCS/reference/k.json und docs/Reference/l.json (landen im selben Ordner, realpath kanonisiert; ein Repo-Pfad in ADV/REPO wird korrekt verweigert). Pfade mit Leerzeichen/Unicode: Ordner nicht angelegt, deshalb "Schreiben fehlgeschlagen", keine Umgehung. Skriptlauf liefert zwei Sätze, titleBefore/titleUser/durationUser wie erwartet, keine App-Ids. Abbruch beim Schreiben: Ordner ohne Schreibrecht ergibt "Schreiben fehlgeschlagen", die vorhandene Datei bleibt, kein Tempfile zurück; eine Unterbrechung mitten im Schreiben wurde nicht gesondert erzwungen (atomar über Temp-Datei und Rename).
Regression AC-1 bis AC-9 und AC-11 durch den Umbau: keine gefunden. AC-10 ist durch F001 und F002 nicht bewiesen und bleibt offen.
**Implementierer:** (zweiter Durchgang, keine Antwort im Protokoll)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Geprüfte Code-Dateien
Code reference: Measurement/RawTextExport.swift:134
Code reference: scripts/export-loose-ends-rawtexts.swift:19
Code reference: LooseEndsTests/RawTextExportTests.swift:355

## Verdict
Tests: 16 bestanden, 0 fehlgeschlagen, 2 übersprungen (Hilfstests mit Umgebungsvariable)
Blockierend: F001 (HIGH, Schutz hängt vom Arbeitsverzeichnis ab), F002 (MEDIUM, Endlosschleife). Hinweis: F003.
VERDICT: BROKEN

## Geprüfte Dateien

- sha256:ae8a3d987ec7103b415ddab346078c25ee87553d8e10b470020bd7a0a4972ab0  LooseEndsTests/RawTextExportTests.swift
- sha256:43f0b9a9dec617735641442d2748c1a624efbdb2eba152a55ecf5adc392189a6  Measurement/RawTextExport.swift
- sha256:6c54d95ceea97a5bfd2154d704fec4ba22a5a6a147b5025204f260ccc908e4e0  scripts/export-loose-ends-rawtexts.swift

## Prüfbasis

- base: 14f8c91619aebc17828768b1482376814011d875
- blob:e3458f46717187e377c7bd0480ccf9dab5d72fdd  LooseEndsTests/RawTextExportTests.swift
- blob:55b4a7a53e74adb5d2f32867776d679188f24510  Measurement/RawTextExport.swift
- blob:485d576a1b556137f72ca48ea94723dce5e460f7  scripts/export-loose-ends-rawtexts.swift
