# Adversary Dialog — feat-88-b1b-export
Spec: docs/specs/measurement/feat-88-b1b-export.md
Datum: 2026-10-29 14:06

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
- [x] **AC-10:** Ziel geschützt. Given ein Ausgabepfad und der Repo-Stamm `root` / When `RawTextExport.checkTarget(_, root:)` läuft / Then verweigert es jeden Pfad unter `root`, der nicht unter `root/docs/reference/` liegt (auch über `..` oder einen Symlink erreicht), mit einer Meldung, und erlaubt `root/docs/reference/…` sowie Pfade außerhalb von `root` (z. B. einen temporären Ordner); `run` schreibt bei Verweigerung nichts.
- [x] **AC-11:** Keine Sätze in Meldungen. Given Kunstdaten mit Marker-Wörtern im Rohtext / When der Export einen Fehler meldet oder eine Zusammenfassung ausgibt / Then enthalten Fehlertexte und die Zusammenfassung (`RawTextExport.summary`) nur Zahlen und Pfade („N Sätze, davon M mit Titelkorrektur, K mit Dauer“), keinen Satz.
- [x] **AC-12:** Aufrufweise belegt. Given `docs/reference/messung-rohsaetze.md` / When man den Export nachschlägt / Then steht dort der Aufruf (Bau mit `swiftc`, der Standardpfad des Speichers der normalen Mac-App, Ziel) in einer Zeile, und der Hinweis, dass der Lauf auf dem echten Speicher erst nach Hennings „jetzt ist ein Test möglich“ geschieht (B2).

## Dialog

### Runde 1
**Adversary:** Dritter Durchgang, Code und Tests neu gelesen, nichts aus den Durchgängen 1/2 übernommen. Hinweis: Die bekannte Textabweichung der Spec (relativer Skriptpfad, standardizedFileURL) ist nicht gemeldet; Ist-Zustand: absoluter Bau, `root(fromScriptPath:)`, `realpath`.
Sim-Lauf `sim-unit RawTextExportTests`: 19 Tests bestanden, 0 fehlgeschlagen; 2 Hilfstests (`writeFixtureStoreForScriptRun`, `readScriptResult`, nur mit Umgebungsvariable aktiv) übersprungen; 3 Messstrecken außerhalb dieser Suite übersprungen (nicht gemessen). Ausgabe: docs/artifacts/feat-88-b1b-export/adversary-test-output.txt.

Confirmation: AC-1 — Code reference: LooseEndsTests/RawTextExportTests.swift:94 (Kette über `run`, `RawSentenceColumn.decode` und `Corpus.entries`, Speicher von der echten SwiftData-Schicht, Rohtexte paarweise verschieden); Measurement/RawTextExport.swift:204 (`run`). Status: CONFIRMED
Confirmation: AC-2 — Code reference: Measurement/RawTextExport.swift:117 (`row(for:)`: before = old der ersten, user = new der letzten Nutzer-Revision); Test LooseEndsTests/RawTextExportTests.swift:118 prüft `titleCorrected` über den echten Decoder. Status: CONFIRMED
Confirmation: AC-3 — Code reference: Measurement/RawTextExport.swift:114 (Sortierung nach createdAt, Tie-Break Zeilenreihenfolge); Test LooseEndsTests/RawTextExportTests.swift:132 fügt in umgekehrter Reihenfolge ein, :180 prüft den Gleichstand gegen die Z_PK-Reihenfolge der Datei. Status: CONFIRMED
Confirmation: AC-4 — Code reference: Measurement/RawTextExport.swift:108 (nur Autor "user"), :120 (Rückfall auf aktuellen Titel); Test LooseEndsTests/RawTextExportTests.swift:146 mit .ai- und .rule-Revisionen. Status: CONFIRMED
Confirmation: AC-5 — Code reference: Measurement/RawTextExport.swift:121 (letzte Nutzer-Dauer, leer weggelassen); Tests LooseEndsTests/RawTextExportTests.swift:159, :170, :219. Status: CONFIRMED
Confirmation: AC-6 — Code reference: Measurement/RawTextExport.swift:124 (`new ?? ""`, kein Weglassen); Test LooseEndsTests/RawTextExportTests.swift:230 mit `titleCorrected` falsch über den echten Decoder. Status: CONFIRMED
Confirmation: AC-7 — Code reference: Measurement/RawTextExport.swift:89 (Sortierung capturedAt, Z_PK), :123 (Id = laufende Nummer, nie Z_PK oder Uuid); Tests LooseEndsTests/RawTextExportTests.swift:244, :255. Status: CONFIRMED
Confirmation: AC-8 — Code reference: Measurement/RawTextExport.swift:225 (`SQLITE_OPEN_READONLY`); Test LooseEndsTests/RawTextExportTests.swift:268 (SHA-256 vorher/nachher, Ordnerinhalt gleich). Gegenprobe Runde 2: Kopie ohne -wal/-shm lässt sich nicht öffnen (Code 14, benannt), es entstehen keine Dateien. Status: CONFIRMED
Confirmation: AC-9 — Code reference: Measurement/RawTextExport.swift:82 und :262 (storeMissing, notADatabase, tableMissing, columnMissing), :207 (noTasks), :210 (Schreiben erst am Ende, atomar); Test LooseEndsTests/RawTextExportTests.swift:287. Status: CONFIRMED
Confirmation: AC-10 — Code reference: Measurement/RawTextExport.swift:146 (`checkTarget`), :162 (`physical`), :138 (`root(fromScriptPath:)`); Tests LooseEndsTests/RawTextExportTests.swift:355, :406, :428. Status: CONFIRMED
Confirmation: AC-11 — Code reference: Measurement/RawTextExport.swift:44 (Meldungen nur Art und Pfad), :193 (`summary` nur Zahlen); scripts/export-loose-ends-rawtexts.swift:29 (Fehlerpfade geben nur `message` oder den Typnamen aus); Test LooseEndsTests/RawTextExportTests.swift:441. Status: CONFIRMED
Confirmation: AC-12 — Code reference: scripts/export-loose-ends-rawtexts.swift:5 (Bauzeile im Skriptkopf); docs/reference/messung-rohsaetze.md Zeilen 9-15 (Aufruf in einer Zeile mit swiftc, Standardspeicher, Ziel) und Abschnitt zum echten Speicher erst nach Hennings Wort. Status: CONFIRMED

Angriff auf `physical` (Measurement/RawTextExport.swift:162): Jede Schleifenrunde verschiebt genau eine Komponente von `existing` nach `rest`; `existing.count > 1` bricht ab, bei "/" läuft die Schleife nie. Terminierung ist strukturell bewiesen, unabhängig von Symlinks (`realpath` liefert bei Schleife ELOOP, also nil, also weiter kürzen) oder unlesbaren Ordnern. `appendingLexically` kürzt `..` nur über 1 Komponente, kann nie unter die Wurzel. Angriff auf `root(fromScriptPath:)` (Measurement/RawTextExport.swift:138): relativer Pfad, leer und "~" haben kein "/"-Präfix und werden benannt verweigert. "/x.swift" ergibt root "/" (bzw. "/.."), dann ist base = ["/"], alles liegt unter root, nur "/docs/reference" ist erlaubt: das schließt zu, es erlaubt nicht alles. Ein Schreibziel kann root nicht beeinflussen: er kommt allein aus `#filePath` zur Bauzeit. Test-Fixture-Falle: Die Wächtertests legen reale Ordner und Symlinks auf der Platte an (LooseEndsTests/RawTextExportTests.swift:355-425) und rufen `checkTarget` ohne Selbstaufbau des Ergebnisses auf. Schwäche: Der Test `rootNeedsAbsoluteScriptPath` prüft nur die Funktion, nicht dass das Skript sie benutzt (scripts/export-loose-ends-rawtexts.swift:27); das belegt Runde 2 über die echte Kommandozeile. Regression AC-1 bis AC-9, AC-11: keine.
**Implementierer:** (nicht beteiligt, Durchgang 3)

### Runde 2
**Adversary:** Eigene Gegenproben über die echte Kommandozeile. Bau mit absolutem Pfad aus einem Repo-Nachbau im Scratchpad (adv3/repo mit Symlinks `repolink`, `esc2`, `outside/intorepo`, Schleife loop1 und loop2, Selbstlink selfl), `--store` auf Kopie von fixture.store samt -wal/-shm, jeder Start unter `timeout 20`. Alle rund 35 Starts endeten von selbst, kein Timeout.
- Ziel außerhalb: geschrieben, rc 0. `repo/other/x.json`: verweigert, rc 1. `outside/intorepo/other/x.json` (Symlink ins Repo) und `repolink/other/x.json` (Symlink auf den Stamm): verweigert. `repolink/docs/reference/ok2.json`: erlaubt. `docs/reference/esc2/x.json` (Symlink nach other) und `esc2/../x.json`: verweigert. `docs/reference/missing/..` und `docs/reference/..`: verweigert, endet sofort (F002 aus Durchgang 2 behoben). `docs/reference/sub/../../../other/x.json`: verweigert. Falsche Schreibweise `repo/OTHER/x.json` und `REPO/other/x.json`: verweigert (APFS ohne Unterscheidung, realpath kanonisiert); `Docs/Reference/x.json` landet in docs/reference, erlaubt, korrekt.
- Sonderpfade `/`, `//`, `/..`, `/.`, `/a/../..`, `loop1/x.json` (Symlink-Schleife): enden mit "Schreiben fehlgeschlagen", rc 1, keine Endlosschleife. Symlink als Ziel (`outside/linkfile`, Link auf repo/other): der Link wird durch die Datei ersetzt, das Linkziel bleibt unberührt (repo/other leer), wie dokumentiert. Ein hängender Link in docs/reference: Schreiben schlägt fehl, nichts im Repo.
- Relativ gebautes Binary: mit und ohne `--out` bricht es mit "Skriptpfad relativ, Repo-Stamm unbestimmt" ab, rc 1, schreibt nichts (scripts/export-loose-ends-rawtexts.swift:27). Absolutes Binary ohne `--out` schreibt in `repo/docs/reference/loose-ends-rawtexts.json` des Nachbaus.
- Argumente: `--store` ohne Wert, `--out` zweimal, `--foo`, positionales `x`: Aufrufhilfe, rc 2. Fehlender Speicher, Verzeichnis als Speicher, Textdatei als Speicher, Kopie ohne -wal/-shm: benannte Meldung mit Pfad, rc 1, kein Rohtext. Erfolgsausgabe nur die Zahlenzeile und der Zielpfad.
- Eigenes Versehen der Gegenprobe: `--out "~/x"` schrieb die synthetische Kunstdatei nach /Users/hem/x (Tilde wird absichtlich erweitert, scripts/export-loose-ends-rawtexts.swift:37). Kunstdaten, sofort entfernt; kein Befund am Code.
Prozesse: keine übrig. Hennings echter Speicher und Geräte nicht berührt.
**Implementierer:** (nicht beteiligt, Durchgang 3)

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/export-loose-ends-rawtexts.swift:56
  Description: `parse` nimmt den nächsten Token ungeprüft als Wert; `--store --out` setzt den Speicher auf die Zeichenfolge "--out".
  Spec requirement: AC-9 — benannte Ursache statt Leere
  Conflict: kein Verstoß; der Lauf endet mit "Speicher fehlt" und dem Pfad, rc 1, nichts geschrieben. Nur eine unschöne Hilfe.
  Remediation: Werte, die mit "--" beginnen, als fehlenden Wert werten (optional).

## Belege je Datei

Confirmation:
  AC: AC-1 bis AC-11
  Code reference: Measurement/RawTextExport.swift:162
  Evidence: `physical` terminiert strukturell, `checkTarget` (Zeile 146) verweigert alles unter root außer docs/reference, `run` (Zeile 204) schreibt erst nach allen Prüfungen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/export-loose-ends-rawtexts.swift:27
  Evidence: root nur aus absolutem `#filePath`, relativ gebautes Binary bricht mit benannter Meldung ab (Gegenprobe Runde 2).
  Status: CONFIRMED

Confirmation:
  AC: AC-1 bis AC-11
  Code reference: LooseEndsTests/RawTextExportTests.swift:355
  Evidence: Wächtertests legen echte Ordner und Symlinks an; 19 Tests bestanden im Simulator.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:0e243f5930816e67feeac20f876a0f19a1f2b5c22273ea587ef5598be82eb58c  LooseEndsTests/RawTextExportTests.swift
- sha256:a5f0645edd62893456651b94f9200addc9c7f3d18caa69f46443b1bd7d8b7a20  Measurement/RawTextExport.swift
- sha256:1aaf0163bb75262ed811e0bacbda1ec99e7370a85f5480c4d68af6e6bce1dccd  scripts/export-loose-ends-rawtexts.swift

## Prüfbasis

- base: 14f8c91619aebc17828768b1482376814011d875
- blob:e9c692d6156965dad6a555517f19a865591b0893  LooseEndsTests/RawTextExportTests.swift
- blob:424c574c2a9b0bf5e7c981dfa925b1ab26248fef  Measurement/RawTextExport.swift
- blob:1b4d1169b6048a16d2e55c16b0339b1dd0a1acb0  scripts/export-loose-ends-rawtexts.swift
