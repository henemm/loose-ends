---
entity_id: feat-670-testsprache
type: feature
created: 2026-10-24
updated: 2026-10-24
status: draft
workflow: fix-670-testsprache
---

# Spec: #670 Testsprache für `sim-unit` und `test-proof` (`LOOSEENDS_LANG`)

## Approval

- [ ] Approved

## Purpose

Tests, die vom Wochentags- oder Datumstext der Gerätesprache abhängen (Auslöser #659, Knäuel-Test), lassen sich lokal
nur in der Sprache des Simulators prüfen. Der Simulator soll dafür nicht umgestellt werden. `sim.sh` nimmt darum eine
Testsprache an (`LOOSEENDS_LANG=en`) und gibt sie als `-testLanguage`/`-testRegion` an `xcodebuild` weiter, nur für
die Testaktion. Reine Skriptlogik, kein Produktcode.

Ohne Modell geht es nicht: nicht relevant, reine Skriptlogik (Regeln vor Modell gilt trivial).

## Source

- **File:** `scripts/sim.sh`
- **Identifier:** `run_xcodebuild()` (Z. 288), einzige Stelle, die `xcodebuild` aufruft. Dort hängt schon
  `[ "${1:-}" = test ] && set -- "$@" -collect-test-diagnostics never` (#298); die Sprache kommt im selben Muster daneben.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `xcodebuild` (`-testLanguage`, `-testRegion`) | extern | Nimmt ISO-639-1 und ISO-3166-1, wirkt nur auf die Testaktion und überschreibt das Schema |
| `cmd_sim_unit`, `cmd_test_proof`, `cmd_watch_test_proof`, `cmd_test` in `scripts/sim.sh` | module | Aufrufer von `run_xcodebuild`; bleiben unverändert |
| `scripts/test_sim_run_xcodebuild.py` | test | Zieht `run_xcodebuild()` per Regex aus `sim.sh`, ersetzt `xcodebuild` durch eine Attrappe |
| #298 (`-collect-test-diagnostics never`), #516 (Stille-Wächter) | Vorarbeit | Bleiben unberührt; die neuen Argumente stehen vor dem Wächter |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/sim.sh | MODIFY | `run_xcodebuild()`: bei Aktion `test` und gesetztem `LOOSEENDS_LANG` Sprache prüfen und Argumente anhängen |
| scripts/test_sim_run_xcodebuild.py | MODIFY | Neue Testklasse `RunXcodebuildTestLanguageTests` (RED vor der Umsetzung) |
| CLAUDE.md | MODIFY | Eine Zeile im Abschnitt „Build“ |

### Estimated Changes
- Files: 3
- LoC: +45/-0 (ca. 15 in `sim.sh`, 29 in den Tests, 1 in `CLAUDE.md`)

## Implementation Details

**Verhalten** (alles in `run_xcodebuild`, nur wenn `$1 = test`):

1. Variable `LOOSEENDS_LANG` nicht gesetzt (`${LOOSEENDS_LANG+x}` leer): die Argumentliste bleibt byte-gleich zu heute.
2. Gesetzt, Wert passt auf `^[a-z]{2}$`: `-testLanguage <code>` anhängen. Dazu `-testRegion <R>` aus einer kleinen Tabelle:
   `en`→`US`, `de`→`DE`, `fr`→`FR`, `es`→`ES`, `it`→`IT`, `nl`→`NL`, `ja`→`JP`. Ein gültiger Code außerhalb der Tabelle bekommt nur
   `-testLanguage`, keine erfundene Region.
3. Gesetzt, aber leer oder nicht `^[a-z]{2}$` (auch `EN`, `en-US`, `e n`): Abbruch mit Meldung auf stderr im Stil der
   übrigen Skriptfehler („LOOSEENDS_LANG=<wert> ist keine Sprache: erwartet zwei Kleinbuchstaben, z. B. en“) und Exit ≠ 0, bevor
   `xcodebuild` startet, und ohne die Sperre zu verklemmen (Rückgabe wie andere Fehler in der Funktion).
4. Andere Aktionen (`build`, `build-for-testing` …): Variable wird nicht gelesen, auch nicht auf Gültigkeit geprüft.

**Reichweite:** über `run_xcodebuild` automatisch `sim-unit`, `test`, `test-proof`, `watch-test-proof` (und Mac-Testläufe). Die CI
ruft `xcodebuild` direkt und ist unberührt.

**CLAUDE.md-Zeile** (im Codeblock unter „Build“, hinter `sim.sh watch-test-proof`, im Stil der Befehlszeilen):

`LOOSEENDS_LANG=en ./scripts/sim.sh sim-unit <Klasse>  # Testsprache en (-testLanguage/-testRegion), Simulator bleibt wie er ist (#670)`

**Offene Frage, wird im Abnahmelauf beantwortet:** Wirkt `-testLanguage` unter Xcode 27 auf Unit-Tests im iOS-Simulator? Im Netz
fand sich kein Beleg (nur die xcodebuild-Manpage). Belegt wird es am echten Lauf (AC-7). Wirkt es nicht, ist der Rückfall das
Launch-Argument `-AppleLanguages (en)` für den Testlauf; dann wird diese Spec per Nachbesserung angepasst, bevor gemergt wird.

**Alternativen, nicht gewählt:**
- Zweiter, dauerhaft englischer Simulator: schwerer (Start, Platz, zweiter Gerätesatz für die Sperre), wird vergessen,
  und der Testlauf müsste ihn eigens wählen. Der Simulator umzustellen scheidet laut Ticket aus.
- `AppleLanguages` als Launch-Argument im Schema: dauerhaft im generierten Projekt (`project.yml`), gilt für jeden Lauf statt
  nur auf Wunsch, und `project.yml` löste die Geräteliste (Stufe 3) aus. Bleibt der Rückfall.

Keine ADR wird gekippt.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_sim_run_xcodebuild.py`, Klasse `RunXcodebuildTestLanguageTests`, mit der vorhandenen Attrappe, die die Argumente schreibt.

- [ ] `test_without_variable_arguments_are_unchanged`: GIVEN `LOOSEENDS_LANG` nicht in der Umgebung WHEN `run_xcodebuild test -project P.xcodeproj` THEN genau `test -project P.xcodeproj -collect-test-diagnostics never`, kein `-testLanguage`.
- [ ] `test_en_sets_language_and_region`: GIVEN `LOOSEENDS_LANG=en` WHEN `test` THEN `-testLanguage en -testRegion US` (je Wert direkt hinter dem Schalter).
- [ ] `test_de_sets_de_region`: GIVEN `de` WHEN `test` THEN `-testLanguage de -testRegion DE`.
- [ ] `test_unknown_valid_code_sets_language_only`: GIVEN `LOOSEENDS_LANG=zz` WHEN `test` THEN `-testLanguage zz`, kein `-testRegion`.
- [ ] `test_invalid_values_abort_loudly`: GIVEN je `""` (gesetzt, leer), `EN`, `en-US`, `e n`, `eng` WHEN `test` THEN Exit ≠ 0, stderr nennt `LOOSEENDS_LANG` und den Wert, die Attrappe wurde nicht aufgerufen.
- [ ] `test_build_action_ignores_variable`: GIVEN `LOOSEENDS_LANG=en` und GIVEN `LOOSEENDS_LANG=` (leer) WHEN `build -project P.xcodeproj` THEN Argumente unverändert, Exit 0, kein `-testLanguage`.

Die vorhandenen Tests der Datei (#298, #516) bleiben unverändert grün.

## Acceptance Criteria

- **AC-1:** Ohne `LOOSEENDS_LANG` ist die Argumentliste von `run_xcodebuild test …` byte-gleich zu vorher. Belegt durch `test_without_variable_arguments_are_unchanged` und die unveränderten Tests #298.
- **AC-2:** `LOOSEENDS_LANG=en` ergibt bei `test` genau `-testLanguage en -testRegion US`. Belegt durch `test_en_sets_language_and_region`; `de` durch `test_de_sets_de_region`.
- **AC-3:** Ein gültiger Code außerhalb der Region-Tabelle ergibt nur `-testLanguage`, ohne `-testRegion`. Belegt durch `test_unknown_valid_code_sets_language_only`.
- **AC-4:** Ein ungültiger Wert (leer bei gesetzter Variable, nicht `^[a-z]{2}$`) bricht mit Meldung auf stderr und Exit ≠ 0 ab, bevor `xcodebuild` läuft. Belegt durch `test_invalid_values_abort_loudly`.
- **AC-5:** Andere Aktionen als `test` bleiben unberührt, auch bei gesetzter oder leerer Variable. Belegt durch `test_build_action_ignores_variable`.
- **AC-6:** Die Wirkung gilt über `run_xcodebuild` für `sim-unit`, `test`, `test-proof` und `watch-test-proof`, ohne dass deren Funktionen geändert werden. Belegt durch Diff (nur `run_xcodebuild` in `sim.sh` geändert) und AC-7 für `sim-unit`.
- **AC-7:** Abnahme am echten Lauf (Stufe 2): `LOOSEENDS_LANG=en ./scripts/sim.sh sim-unit KnaeuelTests` ist grün, und ein sprachabhängiger Nachweis zeigt, dass wirklich Englisch gilt, ohne Variable Deutsch. Nachweis: ein nur lokal angelegter, nicht eingecheckter Wegwerf-Test in `LooseEndsTests` schreibt `Locale.preferredLanguages.first` und `Locale.current.identifier` in den Lauf (`print` im Log von `sim-unit`). Mit Variable muss `en` bzw. `en_US` stehen, ohne Variable `de`; beide Logauszüge kommen in den Abschlussbericht, der Wegwerf-Test wird vor dem Commit entfernt. Zeigt der Lauf mit Variable weiter `de`, ist die offene Frage negativ beantwortet: Rückfall `-AppleLanguages (en)` (siehe Implementation Details), Spec-Nachbesserung vor dem Merge.
- **AC-8:** `CLAUDE.md` enthält die Befehlszeile aus „Implementation Details“ im Abschnitt „Build“. Belegt durch Diff.

Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] Die sechs neuen Tests in `RunXcodebuildTestLanguageTests` waren vor der Umsetzung rot und sind danach grün.
- [ ] `scripts/test_sim_run_xcodebuild.py` läuft vollständig grün (neue Tests und die unveränderten aus #298 und #516).
- [ ] `LOOSEENDS_LANG=en ./scripts/sim.sh sim-unit KnaeuelTests` ist grün, und der Nachweis aus AC-7 zeigt `en` mit und `de` ohne Variable.
- [ ] `CLAUDE.md` enthält die Befehlszeile unter „Build“.
- [ ] Der Diff berührt nur `run_xcodebuild()` in `scripts/sim.sh`, die Testdatei und `CLAUDE.md`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Werkzeugoption in `scripts/sim.sh` nach dem Muster von #298, kippt keine ADR und ändert keine Architektur des Produkts.

## Changelog

- 2026-10-24: Initial spec created
