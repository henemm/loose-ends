# Adversary Dialog — feat-88-b1b-export
Spec: docs/specs/measurement/feat-88-b1b-export.md
Datum: 2026-10-29 13:30

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
**Adversary:** Code und Tests Zeile für Zeile gelesen. Befunde zuerst, dann Bestätigungen.

Finding:
  ID: F001
  Severity: HIGH
  Category: spec_violation
  Code reference: Measurement/RawTextExport.swift:141
  Description: `resolved(_:)` löst Symlinks nur im Elternordner auf und behält die letzte Komponente. Ist die letzte Komponente von `root` selbst ein Symlink, bleibt `base` der Symlink-Pfad, `target` (über denselben Symlink erreicht) wird aber zum echten Pfad aufgelöst; `starts(with:)` schlägt fehl und `insideRoot` ist falsch.
  Spec requirement: AC-10 — jeden Pfad unter `root` außerhalb von `docs/reference/` verweigern, auch über einen Symlink erreicht
  Conflict: Gegenprobe (Runde 2): `checkTarget(g/link/other/x.json, root: g/link)` und `checkTarget(g/real/other/x.json, root: g/link)`, wobei link auf real zeigt, ergeben ALLOWED; das Ziel läge im Repo außerhalb von docs/reference. Der Test `outputPathGuard` legt nur Symlinks unter `root` an, nie einen als `root` selbst. Praktisches Risiko klein (`root` kommt aus `#filePath`), aber die Regel hält nicht.
  Remediation: `root` vollständig mit `resolvingSymlinksInPath()` auflösen (nicht nur den Elternordner), dazu ein Testfall mit Symlink als `root`.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: Measurement/RawTextExport.swift:180
  Description: `SQLITE_OPEN_READONLY` auf einer WAL-Datenbank ohne vorhandene -wal/-shm-Dateien scheitert mit Code 14 (CANTOPEN), `sqlite3 -readonly` ebenso. Die Meldung ist laut und benannt (Art, Code, Pfad), es wird nichts geschrieben; kein Verstoß gegen AC-8 oder AC-9.
  Spec requirement: AC-8/AC-9 — nur lesend, laut statt leer
  Conflict: Hinweis für B2: liegt Hennings Speicher bei geschlossener App ohne Nebendateien, bricht der Export ab, statt zu lesen. Die Fixture des Tests hat -wal/-shm, den Fall bildet kein Test ab.
  Remediation: In B2 die App laufen lassen oder den Fall in Doku und Meldung benennen; nicht auf READWRITE wechseln.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/RawTextExportTests.swift:159
  Description: Testlücken ohne Codefehler: `durationFromLastUserRevision` fügt die Revisionen aufsteigend ein und beweist die Ordnung nach createdAt nicht; gleiche createdAt und leerer Text als Dauer sind ungetestet. Die Gegenprobe zeigt, dass der Code beides richtig behandelt.
  Spec requirement: AC-5 — letzte Nutzer-Revision, leere Dauer weglassen
  Conflict: Beleg dünn, Verhalten korrekt.
  Remediation: Optional Tests ergänzen.

Bestätigungen (je Code und Test gelesen):
Confirmation:
  AC: AC-1
  Code reference: LooseEndsTests/RawTextExportTests.swift:94
  Evidence: Speicher kommt von der echten Modellschicht (SwiftData, Datei), `run` schreibt, `RawSentenceColumn.decode` und `Corpus.entries(from:)` laden die Daten, Zählung 3 gleich 3. Testlauf grün.
  Status: CONFIRMED
Confirmation:
  AC: AC-2, AC-3
  Code reference: Measurement/RawTextExport.swift:113
  Evidence: erste Titelrevision liefert oldValue, letzte newValue, sortiert nach (createdAt, Zeilenreihenfolge) in Zeile 109. Der Test fügt die Revisionen in umgekehrter Zeitfolge ein (RawTextExportTests.swift:135), echte Reihenfolge-Probe; `titleCorrected` mit dem echten Decoder geprüft.
  Status: CONFIRMED
Confirmation:
  AC: AC-4, AC-5, AC-6
  Code reference: Measurement/RawTextExport.swift:103
  Evidence: Filter authorRaw gleich user (103) schließt ai und rule aus, ohne Titelrevision gilt der aktuelle Titel (115), titleUser nil; leere oder nil Dauer ergibt nil (116); newValue nil auf Titel ergibt leeren Text (119), titleCorrected im Test falsch.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: Measurement/RawTextExport.swift:84
  Evidence: Sortierung nach (capturedAt, Z_PK), Ids index+1; keine UUID in der Ausgabe (Test 205-212, eigene Ausgabe mit 4 Sätzen: Ids 1 bis 4 ohne Lücke).
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: Measurement/RawTextExport.swift:180
  Evidence: einzige Öffnung mit SQLITE_OPEN_READONLY, nur prepare/step auf SELECT und PRAGMA table_info. Prüfsumme vor/nach und Verzeichnisliste im Test; eigene Gegenprobe: Prüfsumme unverändert.
  Status: CONFIRMED
Confirmation:
  AC: AC-9, AC-11
  Code reference: scripts/export-loose-ends-rawtexts.swift:30
  Evidence: `run` prüft Ziel, liest, bricht bei leerer Liste ab und schreibt erst am Ende atomar (RawTextExport.swift:159-170); Failure-Texte tragen nur Art, Code, Pfad; das Skript gibt bei Fremdfehlern nur den Typnamen aus (Zeile 36). Test mit Marker ZEBRAKUCHEN.
  Status: CONFIRMED
Confirmation:
  AC: AC-12
  Code reference: docs/reference/messung-rohsaetze.md:9
  Evidence: eine Aufrufzeile mit swiftc, Standardspeicher und Ziel; Abschnitt "Echter Speicher erst nach Hennings Wort" mit dem wörtlichen Satz "jetzt ist ein Test möglich".
  Status: CONFIRMED
AC-10 bleibt offen wegen F001.
**Implementierer:**

### Runde 2
**Adversary:** Eigene Gegenproben, vom Implementierer nicht gebaut (Ausgaben im Scratchpad):
1. Skript mit swiftc gebaut (wie in der Doku), Wegwerf-Speicher kopiert, per sqlite3 vier Zeilen ergänzt: Rohtext mit Anführungszeichen, Backslash, Zeilenumbruch und Umlaut; Aufgaben mit fast gleichem capturedAt; Nutzer-Revision mit oldValue NULL; KI-Revision neuer als Nutzer-Revision; zwei Nutzer-Titelrevisionen mit gleichem createdAt; KI-Dauer. Ergebnis: JSON korrekt escaped, ISO-Zeit in UTC mit Z, Ids 1 bis 4, KI-Revisionen ignoriert, Gleichstand entscheidet die Zeilenreihenfolge (B), KI-Dauer fehlt. rc=0.
2. Skript mit relativem und mit absolutem Ausgabepfad ins Repo außerhalb docs/reference: beide verweigert (rc=1), nichts geschrieben.
3. checkTarget mit eigener Probe: Symlink in docs/reference als Ausgabedatei: run ersetzt den Symlink, schreibt nicht in dessen Ziel (sicher). Symlink als root: ALLOWED (F001). Groß-/Kleinschreibung (APFS) und docs/reference2: korrekt behandelt.
4. Speicher im WAL-Modus ohne Nebendateien: Code 14, Datei unverändert, keine Ausgabe (F002).
5. Test im Simulator einmal gelaufen (docs/artifacts/feat-88-b1b-export/adversary-test-output.txt): 13 Tests grün, 0 rot; die zwei Hilfstests (writeFixtureStoreForScriptRun, readScriptResult) ohne Umgebungsvariable nicht gelaufen. Die XCTest-Zeile meldet "Executed 0 tests", die Swift-Testing-Zeilen zeigen die 13.
Fazit: Alle ACs außer AC-10 halten. AC-10 ist durch F001 widerlegt.
**Implementierer:**


## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: BROKEN

## Geprüfte Dateien

- sha256:48c2ca3e7308d4400a4188aa981c8a3f7c6f12352979dcfe9330c99c66c5f27c  LooseEndsTests/RawTextExportTests.swift
- sha256:ae13d118b5d687472c087392e782482047ba3ed72c5f5e9542ede809bf3ea68d  Measurement/RawTextExport.swift
- sha256:1b461b0fd40e327fd2eb8126c048cb6c53b83269236d5496427ddca7da6f96ff  docs/reference/messung-rohsaetze.md
- sha256:6c54d95ceea97a5bfd2154d704fec4ba22a5a6a147b5025204f260ccc908e4e0  scripts/export-loose-ends-rawtexts.swift

## Prüfbasis

- base: 14f8c91619aebc17828768b1482376814011d875
- blob:02ffc8f49fa42731fd7cb86f6a62efc9566b9e2f  LooseEndsTests/RawTextExportTests.swift
- blob:9b5561d61bb29cc248e658c84f17a9841f0e9900  Measurement/RawTextExport.swift
- blob:80b4c7779bb01bd0109f5168d72e747f04d1a8bc  docs/reference/messung-rohsaetze.md
- blob:485d576a1b556137f72ca48ea94723dce5e460f7  scripts/export-loose-ends-rawtexts.swift
