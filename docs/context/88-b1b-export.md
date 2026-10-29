# Analyse: 88-b1b-export

## Auftrag
#88 Schnitt B1b: Ein Export-Skript, das aus dem Datenspeicher der normalen Mac-App Hennings Rohsätze in
`docs/reference/loose-ends-rawtexts.json` schreibt (gitignoriert, nie eingecheckt). B2 (Lauf, Bericht) bleibt offen.

## Stand (gelesen, nichts angefasst)
- Board: nur #71 „In progress“ (Schnitt 2b-2, Gerätedurchgang). Kein offener PR. #88 ist frei; B1a ist gemergt (PR #736).
- Zielformat steht fest (`RawSentenceColumn.Sentence`): `id`, `rawText`, `titleBefore`, `titleUser?`, `durationUser?`,
  `capturedAt`, `lang?`. Keine App-Ids, `id` ist eine laufende Nummer.
- Wahrheit liegt schon im Speicher: jede Nutzerkorrektur ist eine `Revision` mit `authorRaw == user` (`fieldRaw` title / duration,
  `oldValue`/`newValue` als kodierter Text). Die Regel wird nicht als Maßstab benutzt, nichts zirkulär.
- Vorbild: `scripts/export-focusblox-corpus.swift` (SQLite, nur lesend).

## Ableitung je Aufgabe
| Feld | Quelle |
|---|---|
| `rawText`, `capturedAt` | `TaskItem.rawText`, `capturedAt` |
| `titleBefore` | `oldValue` der ersten Nutzer-Revision auf `title`; ohne Korrektur der aktuelle `title` |
| `titleUser` | `newValue` der letzten Nutzer-Revision auf `title`; sonst weggelassen |
| `durationUser` | `newValue` der letzten Nutzer-Revision auf `duration`; sonst weggelassen |

Offen, am Test-Speicher zu klären (nicht am echten): Spaltennamen der Tabellen (`ZTASKITEM`, `ZREVISION`), Zeitbasis der Datumsspalten
(Sekunden seit 2001, wie im Vorbild) und ob `oldValue`/`newValue` JSON-Anführungszeichen tragen (`FieldCodec`).

## Reproduktion / Beweis
Kein Fehler, sondern neue Funktion; das Gegenstück zur Reproduktion ist der Durchlauf an einem **Wegwerf-Speicher**: ein
Unit-Test legt mit der echten Modellschicht Aufgaben mit Revisionen an (korrigiert, unkorrigiert, nur Dauer, leerer Titel),
speichert in eine SQLite-Datei, das Skript liest sie, und die Ausgabe wird mit `RawSentenceColumn.decode` geladen. So prüft die
Kette „Modell schreibt → Skript liest → Läufer lädt“ den ganzen Weg, nicht nur die Hälfte.

## Hennings Geräte
Der echte Speicher liegt im Gruppen-Container seiner Mac-App. Ihn zu lesen ist Zugriff auf sein Gerät. Dieser Schnitt baut und testet
nur gegen den Wegwerf-Speicher. Der erste Lauf auf dem echten Speicher gehört in B2, nach seinem wörtlichen „jetzt ist ein Test möglich“.

## Alternativen
- **A (Empfehlung): Skript, das die SQLite-Datei nur liest.** Kein Produktcode, keine ADR berührt, Datenschutztext unverändert.
- **B: Export-Knopf in der App.** Verworfen in der Analyse zu B/A: Produktfunktion nur für die Messung, Datenschutztext (#705) müsste mit.
- **C: Auslesen über CloudKit.** Scheidet aus: privater Container, das Verwaltungs-Token liest keine Nutzerdaten.
- **D: Das Skript in Python statt Swift.** Kein Übersetzen, kürzer; aber die Dekodierung der Werte bliebe doppelt zur `FieldCodec`.
  Offen für die Spec; Swift wegen Vorbild und Kodierung bevorzugt.
- Ohne Modell: Das Ganze ist reine Datenumformung, Modell oder Regel kommen nicht vor.

## Umfang
`scripts/export-loose-ends-rawtexts.swift` (neu, ca. +90 LoC), ein Test mit Wegwerf-Speicher (neu, ca. +80 LoC), eine Zeile in
`docs/reference/` zur Aufrufweise. 3 Dateien, ca. +180 LoC, innerhalb der Grenzen. Risiko LOW, kein Pfad der Geräteliste:
„Kein Pfad der Geräteliste berührt.“

## Risiken
- Der Speicher einer laufenden App hat eine Journal-Datei (WAL); das Skript öffnet nur lesend und bricht bei gesperrter Datei laut ab.
- Die Ausgabe enthält echte Sätze: Standardpfad ist die gitignorierte Datei, das Skript weigert sich, in einen versionierten Pfad zu schreiben.
- Eine Aufgabe ohne Wörter im Rohtext bleibt drin (die Entduplizierung der Auswertung behandelt sie).

## Analysis

### Type
Feature

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/export-loose-ends-rawtexts.swift` | CREATE | liest den Speicher nur lesend, schreibt `docs/reference/loose-ends-rawtexts.json` (gitignoriert) |
| `LooseEndsTests/RawTextExportTests.swift` | CREATE | Wegwerf-Speicher mit Aufgaben und Nutzer-Revisionen, Skript lesen lassen, Ausgabe mit `RawSentenceColumn.decode` laden |
| `docs/reference/` (Aufrufweise, eine Zeile) | MODIFY | Aufruf und Pfade |

### Scope Assessment
- Files: 3
- Estimated LoC: +180/-0
- Risk Level: LOW (kein Pfad der Geräteliste, kein Produktcode)

### Technical Approach
Schreibgeschütztes Swift-Skript nach Vorbild `export-focusblox-corpus.swift`. `titleBefore` ist der `oldValue` der ersten
Nutzer-Revision auf `title` (ohne Korrektur der aktuelle Titel), `titleUser` und `durationUser` je der `newValue` der letzten
Nutzer-Revision. Beweis am Wegwerf-Speicher über die ganze Kette. Der Lauf auf Hennings echtem Speicher gehört zu B2 und braucht
sein „jetzt ist ein Test möglich“. Alternativen (App-Knopf, CloudKit, Python) stehen oben.

### Dependencies
`Measurement/RawSentenceColumn.swift` (Zielformat), `Shared/Models/Revision.swift`, `Shared/Services/FieldCodec.swift`
(Kodierung der Werte), `.gitignore`. Ticket #88 (B2 folgt), #71 (derselbe Gerätedurchgang).

### Open Questions
- [ ] Tabellen- und Spaltennamen und Zeitbasis am Wegwerf-Speicher bestätigen
- [ ] Swift oder Python für das Skript (Empfehlung Swift)
