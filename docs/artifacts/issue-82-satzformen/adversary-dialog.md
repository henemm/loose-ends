# Adversary-Dialog: issue-82-satzformen

Spec: `docs/specs/measurement/issue-82-satzformen.md` · Datum: 2026-09-20
Rollen: Orchestrator (Hauptkontext), Developer-Agent, implementation-validator (Adversary)

## Checkliste

- [x] AC-1 Bauform je Satz aus fester Liste, ohne Angabe `standard`, unbekannte Form lässt den Korpustest fehlschlagen
- [x] AC-2 Mindestens 100 Sätze außerhalb `standard`, jede Bauform mindestens 6 Sätze, Wahrheit als Regel gegen den Messtag
- [x] AC-3 Formen sind echt (Stichwort ≤ 3 Wörter, Frage endet mit „?", Ich-Satz beginnt mit „ich", Diktat klein und ohne Komma); Entitäten wörtlich im Rohtext, auch bei Tipp- und Diktatfehlern
- [x] AC-4 Bericht enthält „Nach Bauform" mit einer Zeile je Bauform (Sätze, Datum exakt, Datum erfunden, Titel ohne erfundene Fakten); Kriterium ohne Sätze zeigt „–"
- [x] AC-5 Alte Leser (Labor-App, Bericht, Reminders-Benchmark #78) laden den erweiterten Korpus ohne Änderung; Labor-App holt neue Sätze nach, ohne gemessene zu wiederholen
- [x] AC-6 Alle Unit-Tests grün (Regelwerk, Messlauf-Datei, Bericht)

### Runde 1

**Adversary** prüft die vorgelegten Beweise: vollen Testlauf (`docs/artifacts/issue-82-satzformen/test-green-output.txt`, 90 bestanden, 0 fehlgeschlagen), Korpus (`Measurement/date-title-corpus.json`, 317 Sätze), Bericht (`docs/reference/date-title-fidelity.md`) und die Leser des Korpus. Er vertraut dem Artefakt nicht allein, sondern rechnet per eigenem Python-Skript nach und führt `CorpusTests` und `DateTitleFormSectionTests` selbst im Simulator aus (Output: Scratchpad `adversary_test_output.txt`).

- AC-1 AKZEPTIERT: geschlossene Liste `Corpus.forms` (Measurement/Corpus.swift:23-25), `form` optional mit Default `standard` (Zeilen 42, 45); 0 unbekannte Formen in 317 Sätzen; Fehlerpfad LooseEndsTests/CorpusTests.swift:121 (`#expect(Corpus.forms.contains(entry.form))`) gelesen.
- AC-2 AKZEPTIERT: 123 Sätze außerhalb `standard`; je Form: denglisch 11, diktat 12, diktat-name 11, frage 11, ich-satz 11, nebensatz 11, praefix 11, stichwort 12, tippfehler 11, zeit-hinten 11, zwei-aufgaben 11; 139 mit Datum, 170 Kontrollen (eigene Zählung).
- AC-3 AKZEPTIERT: 0 Formregel-Verstöße, 0 Entitäten-Verstöße (eigene NFKD-Faltung); Tippfehler-Entitäten wie getippt („Rechnug", „Zahnartz", „Özdemri"), verfremdete Namen ohne `people`-Eintrag; 0 Sätze mit Uhrzeit ohne Datum.
- AC-4 AKZEPTIERT mit Nachfrage F001: `formSection` iterierte nur über gemessene Formen (`report.byForm.sorted`), ungemessene Bauformen fehlten als Zeile ganz. Spec sagt „eine Zeile je Bauform". Frage an den Orchestrator: welche Lesart gilt?
- AC-5 AKZEPTIERT: `remaining(from:)` (Measurement/MeasurementRun.swift:99-103) und `MeasurementRunner` (LooseEndsLab/MeasurementRunner.swift:55-56, 98) unverändert und korpusgrößen-agnostisch; kein hartkodierter Zähler; realer Bericht zeigt 31 von 317 gemessen, alles Standard-IDs, keine Wiederholung.
- AC-6 AKZEPTIERT: Artefakt 90 ✔ / 0 ✘, „Test Succeeded"; zwei Suiten selbst neu gelaufen.

**Orchestrator** entscheidet F001: Die Spec gilt wörtlich. Jede der 12 Bauformen bekommt immer eine Zeile, ungemessene mit 0 Sätzen und „–" in allen drei Kriterien; Fremdschlüssel werden sortiert angehängt. Begründung: Eine fehlende Zeile läse sich wie „diese Form ist in Ordnung". **Developer-Agent** setzt es in `formSection` um (Iteration über `Corpus.forms + unknown`, `tally = report.byForm[form] ?? FormTally()`), Test `DateTitleFormSectionTests` unverändert; Testläufe grün, Bericht neu erzeugt mit 12 Zeilen, voller Lauf 90/0 als Artefakt neu gespeichert.

### Runde 2

**Adversary** prüft F001 nach: Diff von `LooseEndsTests/DateTitleReportTests.swift` (Zeilen 222-238, +7/−2, keine Seiteneffekte), eigener Lauf `DateTitleFormSectionTests` grün, Bericht „## Nach Bauform" mit genau 12 Zeilen in `Corpus.forms`-Reihenfolge nachgezählt (`standard | 31 | 45.2 % von 31 | – | 100.0 %`, die übrigen 11 mit `0 | – | – | –`), Artefakt des vollen Laufs erneut geprüft (90 ✔, 0 ✘, „Test Succeeded").

Finding F001:
- ID: F001
- Severity: MEDIUM
- Category: spec_violation
- Description: Ungemessene Bauformen fehlten im Abschnitt „Nach Bauform" als Zeile.
- Evidence: LooseEndsTests/DateTitleReportTests.swift:226 (alt: `for (form, tally) in report.byForm.sorted`)
- Remediation: Iteration über `Corpus.forms + unknown` mit leerem `FormTally` für ungemessene Formen. Umgesetzt und verifiziert.
- Status: RESOLVED

Confirmations:
- AC-1 — Status: CONFIRMED
- AC-2 — Status: CONFIRMED
- AC-3 — Status: CONFIRMED
- AC-4 — Status: CONFIRMED (nach F001)
- AC-5 — Status: CONFIRMED
- AC-6 — Status: CONFIRMED

Geprüfte Randfälle: Bauform-Zeile bei 0 Sätzen, Uhrzeit ohne Datum, Entitäten mit Diakritika, Namens-Tippfehler ohne `people`, unbekannte Bauform (Codepfad), Nachholen offener Sätze in der Labor-App. Keine Regression gefunden.

## Verdict
**VERIFIED**

VERDICT: VERIFIED
