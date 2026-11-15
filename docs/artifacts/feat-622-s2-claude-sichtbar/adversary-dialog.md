# Adversary Dialog — feat-622-s2-claude-sichtbar
Spec: docs/specs/feat-622-schnitt-2-claude-sichtbar.md
Datum: 2026-11-15 09:25

## Checkliste
- [x] **AC-1:** `RevisionService.lastClaudeChange(on:)` liefert die Claude-Revision (Autor `.user`, Grund „Claude“) mit dem neuesten `createdAt`, nil ohne eine solche (Tests 1 und 4, `RevisionServiceClaudeTests`).
- [x] **AC-2:** KI-Revisionen, Regelrevisionen, Nutzerrevisionen ohne Grund und Nutzerrevisionen mit anderem Grund zählen nicht als Claude (`isByClaude` false) (Tests 2 und 3, `RevisionServiceClaudeTests`).
- [x] **AC-3:** Hat nur Claude eine Aufgabe geändert, erscheint die Einstiegszeile im Detail mit dem Text „Zuletzt von Claude · <Tag> <Uhrzeit>“ (Test 7, `ClaudeChangeTests`).
- [x] **AC-4:** Gibt es automatische Felder und eine Claude-Änderung, steht die bekannte Zusammenfassung vorn und der Claude-Teil angehängt; ohne Claude-Änderung bleibt der Text unverändert (Test 7 für den Claude-Teil, Test 5 für das Nebeneinander von KI- und Claude-Revision, bestehende Kennungen in `DriveSmokeTests`/`DesignGalleryTests` bleiben grün).
- [x] **AC-5:** Die Zeit zeigt „heute“/„gestern“ plus Uhrzeit, für ältere Änderungen Datum plus Uhrzeit (Test 7, `ClaudeChangeTests`: die Saat ist von heute, der Text enthält „heute“).
- [x] **AC-6:** Das Änderungsblatt zeigt für eine Claude-Revision den Urheber „Claude“ statt „Du“; `FieldFormatting.author(of:)` liefert dafür „Claude“ und für andere Revisionen unverändert das bisherige Wort (Tests 6 und 8).
- [x] **AC-7:** Für Claude-Zeilen gibt es keinen Zurücksetzen-Knopf, und die Fußnote „Claude“ erscheint nicht zusätzlich zum Urheber; andere Gründe bleiben sichtbar (Test 8, `ClaudeChangeTests`).
- [x] **AC-8:** Die Kennungen `originSummary` und `revisionsButton` bleiben, `DriveSmokeTests.testChangeListNamesTheBeadMarkInGerman` und `DesignGalleryTests` bleiben grün.
- [x] **AC-9:** Das Ungesehen-Abzeichen zählt Claude-Änderungen nicht: `RevisionService.automaticFields` ignoriert die Claude-Revision (Test 5, `RevisionServiceClaudeTests`).
- [x] **AC-10:** Die Saat `--ui-testing-claude-change` wirkt nur mit `ModelContainerFactory.isUITesting` und erzeugt die Revision über einen echten `OrderExecutor`-Auftrag (belegt durch Test 7: die Zeile erscheint ohne handgemachte Revision).
- [x] **AC-11:** Alle neuen Katalogschlüssel haben deutsche und englische Werte; `scripts/test_catalog_languages.py` bleibt grün.
- [x] **AC-12:** Alle Unit-Tests sind grün, und `./scripts/sim.sh test-proof ClaudeChangeTests` ist grün mit registriertem Beleg samt Screenshots hell und dunkel (Test 9).

## Dialog

### Runde 1
**Adversary:** Tests selbst gefahren: `./scripts/sim.sh sim-unit RevisionServiceClaudeTests` (6 Tests, 0 Fehler) und `scripts/test_catalog_languages.py` (8 Tests, OK), Ausgabe in `adversary-test-output.txt`. Belege des Implementierers gelesen: test-green-output.txt (39 Unit-Tests ohne Fehler), test-green-ui.txt (ClaudeChangeTests 3/3, DriveSmokeTests 4/4, DesignGalleryTests 1/1, 0 übersprungen), simulator-run.txt (3 bestanden). Diff vollständig gelesen. Screenshots geöffnet: Detail dunkel zeigt unten grau „Zuletzt von Claude · heute 09:13“ mit Knopf „Anzeigen“; Änderungsblatt hell zeigt eine Zeile „Fällig / Leer → 15. Nov. 2026 / 15. Nov., 09:13“ mit Urheber „Claude“ in Grau, ohne Zurücksetzen-Knopf, ohne Fußnote; „Alle zurücksetzen“ ausgegraut.

Angriffe:
1. Marke zu weit/eng? `isByClaude` verlangt `.user` und Grund „Claude“ (Code reference: Shared/Services/RevisionService.swift:89); KI mit Grund „Claude“ und „Siri“-Nutzer sind Test 3. Standhaft.
2. `lastClaudeChange` bei nil-`revisions` und Gleichstand: `(task.revisions ?? [])`, `max` nach `createdAt` (Shared/Services/RevisionService.swift:94). nil-sicher.
3. Fußnote anderer Gründe: unterdrückt nur bei `isByClaude` (LooseEnds/Views/TaskDetailView.swift:883); „Siri“ o. Ä. bleibt. Per Code bewiesen, kein UI-Test dafür.
4. Zeile ohne Claude unverändert: Bedingung `!aiFields.isEmpty || lastClaudeChange != nil` (LooseEnds/Views/TaskDetailView.swift:223), Claude-Teil nur bei Treffer angehängt (TaskDetailView.swift:381). DriveSmoke/DesignGallery grün.
5. „gestern“/älteres Datum: `when(_:)` (LooseEnds/Views/TaskDetailView.swift:389) verzweigt über `isDateInToday`/`isDateInYesterday`, sonst `.day().month().hour().minute()`; Schlüssel de+en. Nur „heute“ getestet: LOW (F001).
6. Autor im Blatt: `FieldFormatting.author(of:)` (LooseEnds/Views/FieldFormatting.swift:146) nutzt `isByClaude`; Farbe `.secondary`, da `isAutomatic` für `.user` falsch; Screenshot zeigt Grau.
7. Abzeichen: `automaticFields` unverändert, Test 5 beweist es (AC-9).
8. Saat: Guard `ModelContainerFactory.isUITesting` UND Flag (LooseEnds/App/LooseEndsApp.swift:146), Fehler per `Logger`.
9. Katalog: Schlüssel „Claude“ existiert schon (Zeile 496, nur de; en fällt auf identischen Schlüssel zurück): LOW (F002).

**Implementierer:** Saat setzt processedAt/rulesAppliedAt, damit die Regelstufe keine zusätzliche Kontext-Regelrevision anlegt.

### Runde 2
**Adversary:** Abweichung zu AC-10: Die Claude-Revision entsteht weiterhin ausschließlich durch `OrderExecutor.execute` mit echtem `Order(kind: .setDue …)` (LooseEnds/App/LooseEndsApp.swift:158); gesetzt werden nur Anreicherungs-Zeitstempel an der Aufgabe, keine Revision. AC-10 (echter Auftrag, nicht handgemacht, nur unter isUITesting) ist erfüllt; die Marken sind eine zulässige Testvorbedingung. Ohne sie entstünde eine Regelrevision „Telefon“ mit Reset-Knopf und verfälschte Test 8. Einschränkung: Das Nebeneinander Claude plus Regelzeile im Blatt ist UI-seitig ungetestet, Test 5 deckt es auf Dienstebene ab (LOW, kein Verstoß). Regression: andere Aufrufer von `aiFields` (TaskDetailView.swift:86, 167, 745) unberührt; die Zeile erscheint nun auch bei reinen Claude-Änderungen (gewollt).
**Implementierer:** keine weiteren Einwände.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Views/TaskDetailView.swift:389
  Description: `when(_:)` unterscheidet heute/gestern/älter; getestet ist nur der Zweig „heute“, die Funktion ist private static.
  Spec requirement: AC-5 — gestern und ältere Zeitangabe
  Conflict: Code korrekt gelesen, aber „gestern“ und Datumsform nicht durch Test belegt.
  Remediation: In eine reine Funktion heben und testen; optional.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEnds/Resources/Localizable.xcstrings:496
  Description: Schlüssel „Claude“ hat nur einen de-Wert, keinen en-Eintrag (Fallback identisch).
  Spec requirement: AC-11 — deutsche und englische Werte
  Conflict: formal fehlt en; Katalogwächter grün, Wirkung identisch.
  Remediation: en-Eintrag ergänzen; optional.

## Bestätigungen

Confirmation:
  AC: AC-1
  Code reference: Shared/Services/RevisionService.swift:94
  Evidence: lastClaudeChange filtert isByClaude, max nach createdAt; Tests 1 und 4 grün (eigener Lauf).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Services/RevisionService.swift:89
  Evidence: isByClaude verlangt .user und Grund „Claude“; Tests 2, 3 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Views/TaskDetailView.swift:223
  Evidence: Zeilenbedingung erweitert; Screenshot „Zuletzt von Claude · heute 09:13“, UI-Test 3/3 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Views/TaskDetailView.swift:381
  Evidence: Claude-Teil hinten angehängt, ohne Claude unverändert; DriveSmoke 4/4, DesignGallery 1/1 grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: LooseEnds/Views/TaskDetailView.swift:389
  Evidence: heute/gestern/Datum je Zweig mit Katalogschlüsseln; „heute“ per UI-Test und Screenshot belegt (siehe F001).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Views/FieldFormatting.swift:146
  Evidence: author(of:) liefert „Claude“ für die Marke, sonst bisheriges Wort; Test 6 und Screenshot.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Views/TaskDetailView.swift:883
  Evidence: Fußnote nur ohne Claude-Marke; Reset nur für isAutomatic; UI-Test: „Claude“ einmal, 0 resetRevision_; Screenshot.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Views/TaskDetailView.swift:226
  Evidence: Kennungen unverändert; DriveSmokeTests und DesignGalleryTests grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: Shared/Services/RevisionService.swift:98
  Evidence: automaticFields unverändert; Test 5 grün: nur [.title].
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: LooseEnds/App/LooseEndsApp.swift:146
  Evidence: Guard isUITesting plus Flag; Revision durch echten OrderExecutor.execute; die processedAt-Marken sind zulässige Vorbedingung.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: LooseEnds/Resources/Localizable.xcstrings:148
  Evidence: drei neue Schlüssel de+en; test_catalog_languages.py OK (eigener Lauf), siehe F002.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: LooseEnds/App/LooseEndsApp.swift:40
  Evidence: Unit 39 grün, eigener Lauf 6/6; simulator-run.txt Passed 3/3, 0 übersprungen, 4 Screenshots hell/dunkel geöffnet und beschrieben.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: 6 passed (eigener Lauf RevisionServiceClaudeTests), 39 Unit und 8 UI laut Belegen, 0 failed, 0 übersprungen
Edge cases: geprüft, nur zwei LOW-Hinweise (F001, F002)
Regressions: None found
Checklist: 12/12 points proven

## Geprüfte Dateien

- sha256:120c12c16474b3fba4724320f6c37f7ef6ad170c2a3d606341e8914f25522b32  LooseEnds/App/LooseEndsApp.swift
- sha256:362573bde2516ec6c4e6eaf839d62ea140ec7fddda4fede50550950494db202e  LooseEnds/Resources/Localizable.xcstrings
- sha256:cb8a89c1d154c4f5e72e533273514df6dfea21570003e77a877526cef77c5cc0  LooseEnds/Views/FieldFormatting.swift
- sha256:84062210cb6d6dbe6b5b8551d5ec044d878e9f7c75c9f6275d6402ea0a3f6af0  LooseEnds/Views/TaskDetailView.swift
- sha256:07866336c2cb4090b80907d205bef458fd2851ba9243334a1e408abccd0a3e99  Shared/Services/RevisionService.swift

## Prüfbasis

- base: c82871d5383cbe225c827dae5768a9750e41166a
- blob:1ddf3a41eca657ae52727a654eab26bfa1bc92b0  LooseEnds/App/LooseEndsApp.swift
- blob:178f539bb01e54a0031d96d584e59576c8e2fedc  LooseEnds/Resources/Localizable.xcstrings
- blob:5fee4f8257273285adc9b0a80a22eb1032dc4911  LooseEnds/Views/FieldFormatting.swift
- blob:9b750255c4b20888a052aa2896b3cca789023393  LooseEnds/Views/TaskDetailView.swift
- blob:fc5325a50e31f7c77ad833e52e5d6b5343651773  Shared/Services/RevisionService.swift
