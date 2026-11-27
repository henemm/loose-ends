# Adversary Dialog — feat-1001-regeln-schaerfen
Spec: docs/specs/enrichment/feat-1001-tageszeit-im-titel.md
Datum: 2026-11-27 18:49

## Checkliste
- [x] **AC-1:** „Pakete wegbringen heute Morgen“ ergibt den Titel „Pakete wegbringen“, Datum heute, keine Uhrzeit gesetzt.
- [x] **AC-2:** „Heute Abend um 20 Uhr Oma anrufen“ ergibt „Oma anrufen“; „Müll rausstellen heute Abend“ ergibt „Müll rausstellen“; „Morgen früh um 7:30 den Hund zum Tierarzt“ ergibt „Den Hund zum Tierarzt“.
- [x] **AC-3:** „Morgen Mittag um 12 …“, „tomorrow morning hand in …“ und „Montag Abend …“ verlieren das Tageszeitwort im Titel; „am Montag am Abend“ verliert auch das „am“ vor dem Tageszeitwort.
- [x] **AC-4:** „Call mom tonight“ setzt das Datum auf heute und ergibt den Titel „Call mom“.
- [x] **AC-5:** Gegenproben bleiben: „Heute Abendessen kochen“ → „Abendessen kochen“; „Am Abend Tabletten nehmen“ (kein Datum) unverändert; „Morgen Morgenrunde laufen“ → „Morgenrunde laufen“; „Parents' evening at primary school Friday at 7 pm“ behält „Parents' evening“; „Montagabend“ und „Samstagmorgen“ bleiben ganze Wörter.
- [x] **AC-6:** In allen Tageszeitfällen ohne Zahl wird keine Uhrzeit gesetzt; der Parser (`DateExpressionParser`, `TimeExpressionParser`) ist unverändert.
- [x] **AC-7:** `rule-golden.json` ändert sich nur in den sechs Zeilen de-heute-2, de-morgen-2, de-zeit-5, de-zeit-hinten-2, de-lang-1, en-long-1, nur im Feld `title`.
- [x] **AC-8:** Alle Unit-Tests (`./scripts/sim.sh unit`) einschließlich `LanguagePackConformanceTests` und `RuleGoldenTests` sind grün; der UI-Test der Abnahme Stufe 2 ist grün.
- [x] **AC-9:** Der App-Code-Umfang bleibt innerhalb von 4 Dateien und ±250 LoC; `docs/reference/neue-sprache.md` nennt Tageszeiten als Punkt für neue Sprachen.

## Dialog

### Runde 1
**Adversary:** Beweise je AC gefordert. Eigene Läufe: `./scripts/sim.sh sim-unit DayPartTitleTests` (adv-daypart-run.txt, alle Fälle grün), ganzer Unit-Lauf test-run-output.txt (0 Fehler, "Test Succeeded"; Messstrecken 2 von 6 übersprungen sind Messläufe, keine Tests). Golden-Diff geprüft: genau sechs `title`-Zeilen (de-heute-2, de-lang-1, de-morgen-2, de-zeit-5, de-zeit-hinten-2, en-long-1), sonst nichts. `git diff origin/main --stat -- Shared/Enrichment Shared/Services`: nur TitleRule.swift; Parser und DueDateRule unverändert.
**Implementierer:** Tageszeit-Erweiterung in `TitleRule.withDayParts` (Shared/Services/TitleRule.swift:87), Wortliste je Pack.

Confirmation:
  AC: AC-1
  Code reference: Shared/Services/TitleRule.swift:87
  Evidence: „heute Morgen“: Span „heute“, Wort danach „morgen“ in dayParts, gestrichen; Test dayPartLeaves und heuteMorgenIsToday grün; Sonde „Wegbringen heute früh“ ergibt „Wegbringen“, time=false.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Language/GermanPack.swift:87
  Evidence: Wortliste abend, fruh (gefaltet), mittag usw.; „Heute Abend um 20 Uhr Oma anrufen“ ergibt „Oma anrufen“ (Golden de-heute-2), „Morgen früh um 7:30 ...“ ergibt „Den Hund zum Tierarzt“ (de-morgen-2).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Services/TitleRule.swift:104
  Evidence: dayPartLeadIn (am, in the) vor dem Tageszeitwort; „Am Montag am Abend ...“ ergibt „Kinokarten kaufen“; tomorrow morning und Montag Abend im Test grün; Sonden „By tomorrow evening send report“ ergibt „Send report“, „On Friday night call Anna“ ergibt „Call Anna“.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Language/EnglishPack.swift:16
  Evidence: relativeDays enthält „tonight“: 0; Test tonightIsToday grün (Datum heute, hasTime false, Titel „Call mom“).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Language/LanguagePack.swift:68
  Evidence: Ganzwort-Vergleich über ExpressionText.words; Abendessen, Morgenrunde, Montagabend, Samstagmorgen, „Am Abend Tabletten nehmen“ (kein Datum), „Parents' evening ...“ bleiben (Test contentStays grün). „morgen“ vor dem Span wird nicht gestrichen (TitleRule.swift:95); Sonden „Morgen Montag Bäcker anrufen“ ergibt „Montag Bäcker anrufen“, „Morgen Morgen Müll“ ergibt „Müll“.
  Status: CONFIRMED

### Runde 2
**Adversary:** Edge Cases per Wegwerf-Sonde (Testdatei danach gelöscht, Projekt neu generiert). Ohne Datum bleibt alles: „Call at night“, „Bis Abend Bericht schicken“, „Um Mittag Oma anrufen“, „Gestern Abend Bericht“ unverändert. Die Zeile „Heute Abend“ bleibt als Titel erhalten (kein leerer Titel). „Dinner tonight at 8 pm“ ergibt „Dinner“, time=true nur wegen „8 pm“. Keine Uhrzeit erfunden in allen zahllosen Fällen (time=false).
**Implementierer:** Ein Befund, siehe unten.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: Shared/Services/TitleRule.swift:91
  Description: Ein Tageszeitwort direkt hinter einem Datum wird auch gestrichen, wenn es Teil eines Inhaltsnamens ist: „Am Freitag Nacht der Museen planen“ ergibt „Der Museen planen“.
  Spec requirement: AC-5 — Inhaltswörter bleiben (genannt: Zusammensetzungen, Genitiv, Tageszeit ohne Datum)
  Conflict: Spec-konform (Wort hängt am Span), aber Falschstreichung bei Titeln, die mit einem Tageszeit-Substantiv beginnen. Selten.
  Remediation: Akzeptieren und im Issue vermerken; kein Eingriff in diesem Schnitt.

Beobachtung (nicht aus #1001): „Montag und Dienstag Abend Sport“ ergibt „Und Dienstag Abend Sport“; das kommt aus dem unveränderten Parser-Span.

Confirmation:
  AC: AC-6
  Code reference: Shared/Services/TitleRule.swift:58
  Evidence: Nur Titelstreichung; Parser und DueDateRule per git diff unverändert; Sonden ohne Zahl: time=false.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Language/GermanPack.swift:87
  Evidence: git diff rule-golden.json zeigt genau sechs title-Zeilen, keine anderen Felder. en-long-1 endet auf „, otherwise“, weil der Rohtext so weitergeht.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: Shared/Language/EnglishPack.swift:61
  Evidence: Unit-Teil bewiesen (test-run-output.txt: Test Succeeded, 0 Fehler, RuleGolden und Conformance enthalten). UI-Test DayPartTitleUITests per `./scripts/sim.sh test-proof` nachgereicht: simulator-run.txt „ergebnis: Passed, tests: 1 gesamt, 1 bestanden“; 3 Screenshots angesehen: Schreibzeile und „Jetzt“ zeigen „Pakete wegbringen“ (Today), Detail Titel „Pakete wegbringen“, SAID „Pakete wegbringen heute Morgen“, Due Today ohne Uhrzeit.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Language/LanguagePack.swift:127
  Evidence: 4 App-Dateien (EnglishPack, GermanPack, LanguagePack, TitleRule), 36 Zeilen hinzugefügt, 2 entfernt (numstat); neue-sprache.md Zeile 11 nennt dayParts und Tageszeiten.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`).

## Verdict

VERDICT: VERIFIED
Unit-Beweise vollständig, ein LOW-Befund (F001, akzeptiert). AC-8 UI-Teil offen bis /60-validate.

## Geprüfte Dateien

- sha256:fc710c2622b5949b27e3099f4ea59056ead9904e50c7d98a67407d93b7555b9a  Shared/Language/EnglishPack.swift
- sha256:19c6cb629a8561d03ce08e5aa80a46e2feeaed08870a0a07a5cb1b337a8b6098  Shared/Language/GermanPack.swift
- sha256:c1e56eb677aa86f1310cd06594b0445bb3e5f566080d1502739d6d62742009fd  Shared/Language/LanguagePack.swift
- sha256:89a6cc1877880e0d713d5ad70284bf408239f69958d53056997b421337c0d7b0  Shared/Services/TitleRule.swift

## Prüfbasis

- base: 3794047bf90fb7fa97c2a1f09c0da24cdbae5699
- blob:f99c882e543d3650a9f791f9de77a8b09ca80aaa  Shared/Language/EnglishPack.swift
- blob:a33fdcd32ee255a8da992597822be886fbb718ac  Shared/Language/GermanPack.swift
- blob:393022eb12328b66b4f9685bbe02a015d087fe30  Shared/Language/LanguagePack.swift
- blob:56fcd43597fe356fc75fbad951140974098567ff  Shared/Services/TitleRule.swift

## Geprüfte Dateien

- sha256:fc710c2622b5949b27e3099f4ea59056ead9904e50c7d98a67407d93b7555b9a  Shared/Language/EnglishPack.swift
- sha256:19c6cb629a8561d03ce08e5aa80a46e2feeaed08870a0a07a5cb1b337a8b6098  Shared/Language/GermanPack.swift
- sha256:c1e56eb677aa86f1310cd06594b0445bb3e5f566080d1502739d6d62742009fd  Shared/Language/LanguagePack.swift
- sha256:89a6cc1877880e0d713d5ad70284bf408239f69958d53056997b421337c0d7b0  Shared/Services/TitleRule.swift

## Prüfbasis

- base: 3794047bf90fb7fa97c2a1f09c0da24cdbae5699
- blob:f99c882e543d3650a9f791f9de77a8b09ca80aaa  Shared/Language/EnglishPack.swift
- blob:a33fdcd32ee255a8da992597822be886fbb718ac  Shared/Language/GermanPack.swift
- blob:393022eb12328b66b4f9685bbe02a015d087fe30  Shared/Language/LanguagePack.swift
- blob:56fcd43597fe356fc75fbad951140974098567ff  Shared/Services/TitleRule.swift

## Geprüfte Dateien

- sha256:fc710c2622b5949b27e3099f4ea59056ead9904e50c7d98a67407d93b7555b9a  Shared/Language/EnglishPack.swift
- sha256:19c6cb629a8561d03ce08e5aa80a46e2feeaed08870a0a07a5cb1b337a8b6098  Shared/Language/GermanPack.swift
- sha256:c1e56eb677aa86f1310cd06594b0445bb3e5f566080d1502739d6d62742009fd  Shared/Language/LanguagePack.swift
- sha256:89a6cc1877880e0d713d5ad70284bf408239f69958d53056997b421337c0d7b0  Shared/Services/TitleRule.swift

## Prüfbasis

- base: 3794047bf90fb7fa97c2a1f09c0da24cdbae5699
- blob:f99c882e543d3650a9f791f9de77a8b09ca80aaa  Shared/Language/EnglishPack.swift
- blob:a33fdcd32ee255a8da992597822be886fbb718ac  Shared/Language/GermanPack.swift
- blob:393022eb12328b66b4f9685bbe02a015d087fe30  Shared/Language/LanguagePack.swift
- blob:56fcd43597fe356fc75fbad951140974098567ff  Shared/Services/TitleRule.swift
