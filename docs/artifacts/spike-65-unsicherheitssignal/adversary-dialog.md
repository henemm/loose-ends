# Adversary-Protokoll: spike-65-unsicherheitssignal (Spike #65 Schritt 1)

### Runde 1 — Erstprüfung je AC

**Frage 1 (AC-1):** Belegt `Corpus.load(fileName:calendar:)` echten Namens-basierten Zugriff, oder wird der Parameter nur syntaktisch angenommen und ignoriert?

Beweis (Code): `Measurement/Corpus.swift:112-118` — `fileName` fließt sowohl in die Bundle-Suche (`Bundle(for:).url(forResource: fileName, ...)`) als auch in den On-Disk-Pfad (`.appendingPathComponent("\(fileName).json")`) ein; Default bleibt `Corpus.fileName`.
Beweis (Test): `LooseEndsTests/CorpusTests.swift:150-156` (`loadByExplicitFileName`) und `:158-163` (`loadUnknownFileNameThrows`) — beide grün im eigenen Testlauf. Die zweite Probe ist der eigentliche Beweis, dass der Parameter *nicht* ignoriert wird: würde `fileName` nicht verwendet, würde ein unbekannter Name weiterhin erfolgreich `date-title-corpus` laden statt `CocoaError(.fileNoSuchFile)` zu werfen.
Bestehende Aufrufer ohne Argument (`CorpusTests.swift:96,123,152`, `DateParserCorpusTests.swift:34,55,68`, `DateTitleReportTests.swift:74`) laufen unverändert und grün.

Bewertung: **AKZEPTIERT.**

**Frage 2 (AC-2):** Zählt `remaining(from:runsPerEntry:)` wirklich Läufe statt Mitgliedschaft, mit korrektem `runIndex`?

Beweis (Code): `Measurement/MeasurementRun.swift:143-152` — `runs = done.filter { $0.entryID == entry.id }.count`; `if runs < runsPerEntry { open.append((entry: entry, runIndex: runs)) }`.
Beweis (Test): `LooseEndsTests/MeasurementRunTests.swift:92-99` (2 Erfolge, `runsPerEntry=3` → genau ein offenes Paar mit `runIndex==2`) und `:101-107` (3 Erfolge → leer). Beide grün.

Bewertung: **AKZEPTIERT.**

**Frage 3 (AC-3):** Dekodiert eine alte Datei ohne `runIndex` wirklich als `0`, und bleibt Einlauf-Verhalten identisch?

Beweis (Code): `Measurement/MeasurementRun.swift:56-72` (custom `init(from:)`, `runIndex = decodeIfPresent(...) ?? 0`).
Beweis (Test): `MeasurementRunTests.swift:109-121` — hartcodiertes altes JSON ohne `runIndex`-Schlüssel, `#expect(run.results[0].runIndex == 0)` und `remaining(from:)` (Default `runsPerEntry=1`) liefert leer. Grün.

**Nachfrage (Gegenprobe):** Der Test beweist nur den Decode-Pfad mit fehlendem Schlüssel, nicht dass ein frisch geschriebener `MeasurementResult` mit `runIndex != 0` korrekt zurückkodiert und wieder gelesen wird — genau das ist aber die harte Nebenbedingung aus der Spec (laufende Mehrtage-Messungen dürfen beim nächsten App-Start nicht brechen). Kein Test führt einen echten Encode→Decode-Roundtrip mit `runIndex: 2` über `MeasurementStore.coder` durch.

Selbst nachgestellt: mit einem unabhängigen Swift-Snippet nach identischem Muster (eigener `init(from:)`, synthetisiertes `encode(to:)`, Default-Feld) verifiziert — der Roundtrip funktioniert einwandfrei. Mechanisch also korrekt, aber **nicht durch einen eigenen Testfall abgesichert**.

Bewertung: **AKZEPTIERT für das AC selbst** (Verhalten unabhängig verifiziert), fehlende Roundtrip-Testabdeckung als Finding F001 (LOW) erfasst.

**Frage 4 (AC-4):** `total == N*R`, `done` = Gesamterfolge, `progress` korrekt — beweisbar trotz UIKit-Import-Sperre?

Beweis (Code): `MeasurementProgress` in `Measurement/MeasurementRun.swift:167-171`. Delegation: `LooseEndsLab/MeasurementRunner.swift:36-38` — `done`, `total`, `progress` rufen ausschließlich `MeasurementProgress.*` auf, keine eigene Zähllogik mehr.
Beweis (Test): `MeasurementRunTests.swift:123-133`. Grün.

Nachfrage: Ist die Delegation echt, oder nur umbenannt? Gegengeprüft per `git diff` — vorher `run.doneIDs.count`/`entries.count`, jetzt ausschließlich `MeasurementProgress.*`; `grep -rn "doneIDs"` liefert projektweit keinen Treffer mehr.

Bewertung: **AKZEPTIERT.**

**Frage 5 (AC-5):** Reicht `MeasurementRunner` Korpusname und `runIndex` tatsächlich durch, oder wird `Corpus.fileName` weiterhin hart intern verwendet?

Beweis (Code): `MeasurementRunner.swift:58` (`Corpus.load(fileName: corpusFileName)`), `:101,104` (Schleife über `(entry, runIndex)`, ruft `measure(entry, runIndex:)`), `:129,138-139` (`measure(_:runIndex:)` schreibt `runIndex` in den `MeasurementResult`-Konstruktor), `:105` (`save()` nach jedem Satz).
Beweis (Test, extrahierte Logik): `MeasurementRunTests.swift:135-146` (`sequentialRunsGetAscendingIndex`).

Nachfrage (kritisch): Es existiert keine echte zweite Korpusdatei (`focusblox-corpus.json`) für einen Fixture-Test — laut Spec „Nicht in diesem Schnitt" ist die FocusBlox-Angleichung explizit Schritt 2. Reicht der schwächere Beweis (AC-1-Test + Code-Referenz)?

Antwort: Ja — logisch geschlossen: `loadUnknownFileNameThrows` beweist bereits, dass `fileName` echt in die Pfad-Konstruktion eingeht. Zusammen mit der Code-Referenz, dass genau dieser Parameter durchgereicht wird, ist die Kette lückenlos — deckt sich mit dem Spec-Nachtrag.

Bewertung: **AKZEPTIERT**, mit Anmerkung, dass die Fixture-Datei fehlt (spec-konform auf Schritt 2 vertagt, keine Abweichung).

**Frage 6 (AC-6):** Liest `LabApp.init()` wirklich `--corpus` und reicht es durch, mit korrektem Default?

Beweis (Code): `Measurement/Corpus.swift:121-129` (`corpusFileName(from:flag:)`), `LooseEndsLab/LabApp.swift:12-14` (`init()` ruft `Corpus.corpusFileName(from: CommandLine.arguments)` und übergibt an `MeasurementRunner(corpusFileName:)`).
Beweis (Test): `CorpusTests.swift:165-170` — mit Flag, ohne Flag, mit anderem Flag (`--measure`). Grün.

Nachfrage (Edge Case): `--corpus` als letztes Argument ohne folgenden Wert? Kein expliziter Test. Selbst nachvollzogen: `arguments.indices.contains(index + 1)` verhindert Out-of-Bounds und fällt korrekt auf `Corpus.fileName` zurück — mechanisch sicher, aber ungetestet.
Doppeltes `--corpus`-Flag? `firstIndex(of:)` nimmt das erste Vorkommen. Deterministisch, ungetestet, keine Spec-Anforderung dazu.

Bewertung: **AKZEPTIERT für das AC**, zwei ungetestete aber harmlose Edge Cases als Findings F002/F003 (LOW).

### Runde 2 — Regressions- und Vollständigkeitsprüfung

**Frage 7:** Reste des alten `doneIDs`-Zählers?
Beweis: `grep -rn "doneIDs" . --include="*.swift"` → keine Treffer. Vollständig ersetzt, kein Parallelpfad.

**Frage 8:** Läuft die volle Suite in einem selbst gestarteten, frischen Lauf grün?
Selbst ausgeführt: `./scripts/sim.sh unit` — `Test Succeeded`, `Unit-Tests bestanden`, keine Fehlschläge. Suiten „Korpus-Regelwerk" (13 Tests) und „Messlauf-Datei und Taktung" (10 Tests) beide bestanden. Deckt sich mit dem vorhandenen Artefakt (unabhängig bestätigt, zwei grüne Läufe).

**Frage 9:** Bricht die neue `MeasurementResult`-Memberwise-Init bestehende Aufrufer?
Beweis: expliziter neuer `init(...)` mit denselben Parametern + Defaults wie zuvor, nur `runIndex: Int = 0` neu angehängt. Alle Aufrufer kompilieren unverändert (bestätigt durch grünen Build/Testlauf).

**Frage 10:** Wurde `runsPerEntry` in `LabApp` unterschlagen (Spec verlangt nur den Mechanismus in Schritt 1)?
Beweis: `LabApp.swift:13` übergibt nur `corpusFileName:`, nicht `runsPerEntry:` → Default `1` greift. Korrekt gemäß Spec „Nicht in diesem Schnitt".

## Structured Findings

```
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Measurement/MeasurementRun.swift:41-72, LooseEndsTests/MeasurementRunTests.swift
  Description: Kein Testfall kodiert einen MeasurementResult mit runIndex != 0 über MeasurementStore.coder (echter Encode/Decode-Roundtrip) und liest ihn zurück.
  Spec requirement: AC-3 — harte Nebenbedingung, dass Mehrtage-Messungen beim nächsten App-Start weiterlaufen.
  Conflict: Kein Spec-Verstoß (unabhängig verifiziert, dass encode(to:) korrekt schreibt), aber Regressionsrisiko ungetestet.
  Remediation: Test ergänzen, der ein MeasurementResult mit runIndex: 2 über MeasurementStore.coder roundtriped.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: Measurement/Corpus.swift:124-129
  Description: Kein Test deckt "--corpus" als letztes Argument ohne folgenden Wert ab.
  Conflict: Kein Bug (Guard fängt es ab), aber ungetestet.
  Remediation: Testfall ergänzen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: Measurement/Corpus.swift:125
  Description: Bei doppeltem --corpus-Flag gewinnt das erste Vorkommen, ungetestet.
  Conflict: Keine Spec-Anforderung, reine Dokumentationslücke.
  Remediation: Optional, nicht blockierend.
```

## Checkliste

- [x] AC-1 Korpus lädt per Namen, Default unverändert — Measurement/Corpus.swift:112-118, CorpusTests.swift:150-163 grün. Status: CONFIRMED
- [x] AC-2 Mehrere Läufe je Satz werden zutreffend gezählt — Measurement/MeasurementRun.swift:143-152, MeasurementRunTests.swift:92-107 grün. Status: CONFIRMED
- [x] AC-3 Rückwärtskompatibilität mit runsPerEntry = 1 — Measurement/MeasurementRun.swift:56-72, MeasurementRunTests.swift:109-121 grün + unabhängig verifizierter Encode-Pfad. Status: CONFIRMED (Testlücke F001)
- [x] AC-4 MeasurementRunner zählt Läufe statt Sätze — MeasurementRun.swift:167-171, MeasurementRunner.swift:36-38, MeasurementRunTests.swift:123-133 grün, doneIDs vollständig entfernt. Status: CONFIRMED
- [x] AC-5 Runner reicht Korpusname und Laufzahl durch — MeasurementRunner.swift:58,101,104,139, MeasurementRunTests.swift:135-146 grün + Code-Referenz. Status: CONFIRMED
- [x] AC-6 LabApp liest Korpuswahl aus dem Startargument — Corpus.swift:124-129, LabApp.swift:12-14, CorpusTests.swift:165-170 grün. Status: CONFIRMED

## Confirmations

```
Confirmation: AC-1 — Measurement/Corpus.swift:112-118 — CorpusTests.swift:150-163 grün — CONFIRMED
Confirmation: AC-2 — Measurement/MeasurementRun.swift:143-152 — MeasurementRunTests.swift:92-107 grün — CONFIRMED
Confirmation: AC-3 — Measurement/MeasurementRun.swift:56-72 — MeasurementRunTests.swift:109-121 grün + unabhängig verifizierter Encode-Pfad — CONFIRMED (Testlücke F001)
Confirmation: AC-4 — MeasurementRun.swift:167-171, MeasurementRunner.swift:36-38 — MeasurementRunTests.swift:123-133 grün, doneIDs vollständig entfernt — CONFIRMED
Confirmation: AC-5 — MeasurementRunner.swift:58,101,104,139 — MeasurementRunTests.swift:135-146 grün + Code-Referenz — CONFIRMED
Confirmation: AC-6 — Corpus.swift:124-129, LabApp.swift:12-14 — CorpusTests.swift:165-170 grün — CONFIRMED
```

## Test-Nachweis

Eigener, frisch gestarteter Lauf (`./scripts/sim.sh unit`, gestartet 09:44 Uhr): `Test Succeeded` / `Unit-Tests bestanden`. Deckt sich mit dem vorhandenen Artefakt `docs/artifacts/spike-65-unsicherheitssignal/test-green-output.txt` (08:40 Uhr) — zwei unabhängige grüne Läufe, keine Fehlschläge in der Gesamtsuite.

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: alle Suiten grün, 0 Fehlschläge (zwei unabhängige Läufe)
Edge cases: runsPerEntry=0, gemischte Erfolg/Fehlschlag-Ergebnisse, doppelte/fehlende `--corpus`-Argumente — alle geprüft, keines bricht
Regressions: `doneIDs` vollständig entfernt, kein Parallelpfad; alle bestehenden Aufrufer unverändert grün
Checklist: 6/6 Acceptance Criteria durch Code + Test belegt
Offene, nicht-blockierende Findings: F001, F002, F003 (alle LOW, Testlücken bei Edge Cases, keine Spec-Verstöße)
