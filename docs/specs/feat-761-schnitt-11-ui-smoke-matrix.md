---
entity_id: feat-761-schnitt-11-ui-smoke-matrix
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-761-schnitt-11-ui-smoke-matrix
---

# Spec: #761 Schnitt 11 — UI-Smoke je ausgelieferter Sprache in der CI

Epic #750. Nach #756. Modell: Haiku.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750.

## Purpose

Fast alle UI-Testklassen setzen `-AppleLanguages (en)` fest; die CI fährt eine Sprache. Das Design-Briefing verlangt
beide wegen der Textlängen. Eine Sprache wird zur Laufvariable; die CI fährt zwei Smoke-Klassen je Sprache.

Ohne Modell geht es nicht: nicht relevant.

## Source

- `LooseEndsUITests/*.swift`: `app.launchArguments = ["--ui-testing", …, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]` (InboxDrawerSmokeTests, StartNumberTests, FieldsSmokeTests, SpeechDiagnosisLineTests, SpeechListeningIndicatorTests, LaunchArgumentTests, DesignGalleryTests, RecognitionWalkthroughTests); parametrisiert: `OnboardingTests`, `MacUITestSupport`, `DriveSmokeTests`.
- `.github/workflows/ci.yml` Job `ui-smoke` (Z. 113–216), Schritt „Run UI smoke tests“ (`-only-testing:LooseEndsUITests`).
- `scripts/sim.sh` `cmd_test_proof` (Z. 634), `run_xcodebuild` (#670: `-testLanguage`).

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsUITests/LaunchLanguage.swift | NEW | `LaunchLanguage.arguments` aus `ProcessInfo.environment["LOOSEENDS_UI_LANG"]`, Standard `en`; Tabelle `en→en_US`, `de→de_DE`, sonst `<code>_<CODE>` |
| 8 UI-Testklassen | MODIFY | feste Argumente durch `LaunchLanguage.arguments` ersetzen; parametrisierte Klassen unverändert |
| scripts/sim.sh | MODIFY | `test-proof`: `LOOSEENDS_UI_LANG` als `TEST_RUNNER_LOOSEENDS_UI_LANG` durchreichen; Screenshot-Namen mit `-<lang>` |
| scripts/test_sim_run_xcodebuild.py | MODIFY | ein Test |
| .github/workflows/ci.yml | MODIFY | `ui-smoke` mit `strategy.matrix.lang` aus `python3 scripts/shipped_languages.py` (Job `languages` davor gibt JSON aus); der Matrix-Lauf fährt nur `InboxDrawerSmokeTests` und `StartNumberTests` mit `TEST_RUNNER_LOOSEENDS_UI_LANG`; der bisherige volle Lauf bleibt **einmal** (en) |
| docs/reference/abnahme-und-arbeitsweise.md, CLAUDE.md | MODIFY | ein Satz je Datei |

LoC Swift ≈ +25 / −16; YAML ≈ +40.

## Implementation Details

- `shipped_languages.py` bekommt `if __name__ == "__main__": print(json.dumps(shipped_languages(ROOT)))`.
- Matrix-Job heißt `ui-smoke-lang (de)` / `(en)`; Artefakt `ui-smoke-<lang>` mit `UITestResults.xcresult` und den Screenshots.
- Screenshots: `sim_proof.py` hängt `-<lang>` an, wenn die Variable gesetzt ist; ohne Variable unverändert.
- Laufzeit: zwei Klassen je Sprache, parallel als Matrix; der volle `ui-smoke`-Lauf bleibt wie heute.

## Test Plan

- [ ] `test_sim_run_xcodebuild.py::test_ui_lang_is_passed_through`: GIVEN `LOOSEENDS_UI_LANG=de` WHEN `test` THEN `TEST_RUNNER_LOOSEENDS_UI_LANG=de` in der Umgebung der Attrappe.
- [ ] Lokal: `LOOSEENDS_UI_LANG=de ./scripts/sim.sh test-proof StartNumberTests` grün, Screenshot zeigt deutsche Oberfläche („Jetzt“ statt „Now“); ohne Variable englisch. Beide Bilder im PR.
- [ ] CI: Matrix-Jobs `de` und `en` grün.

## Acceptance Criteria

- **AC-1:** `grep -rn '"(en)"' LooseEndsUITests` trifft nur `OnboardingTests`, `MacUITestSupport`, `DriveSmokeTests` (oder deren Parametrisierung).
- **AC-2:** CI-Lauf des PR zeigt `ui-smoke-lang (de)` und `(en)` grün mit Artefakten.
- **AC-3:** Zwei Screenshots (de/en) derselben Ansicht im PR.

## Definition of Done

- [ ] AC-1 bis AC-3 belegt. PR `ci: UI-Smoke je ausgelieferter Sprache (Refs #750, Closes #761)`; Merge; Board Done.
- [ ] „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-30: Spec erstellt.
- 2026-10-31: Umgesetzt mit zwei Abweichungen: (1) `LaunchLanguage.arguments` ersetzt die festen Argumente in den acht genannten Klassen; weitere Klassen (z. B. `PaperGroundTests`, `CaptureSmokeTests`) tragen `(en)` noch fest, sie laufen nur im vollen englischen `ui-smoke` und nicht in der Matrix, daher trifft AC-1 nicht nur die drei parametrisierten Klassen. (2) Die Simulator-Schritte stehen für den neuen Job im Composite `.github/actions/prepare-ui-simulator`; der bestehende Job `ui-smoke` bleibt unverändert.
