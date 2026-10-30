---
entity_id: feat-760-schnitt-10-vertrieb
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-760-schnitt-10-vertrieb
---

# Spec: #760 Schnitt 10 — Vertrieb je Sprache: „Was testen“ und Beta-Text

Epic #750. Unabhängig; `asc_beta_setup.py` auch in #763 (Konflikt mergen). Modell: Haiku.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750. Der englische Beta-Text ist als Übersetzung des deutschen vorab freigegeben.

## Purpose

TestFlight-Texte je Sprachfassung. Belege aus Skripttests und dem Workflow-Log.

Ohne Modell geht es nicht: nicht relevant.

## Source

- `scripts/asc_what_to_test.py`: `LOCALE = "de-DE"` (Z. 19), `write_what_to_test` (Z. 64–77: schreibt `text` in jede Fassung, legt `de-DE` an), `main` (Z. 80, `WHAT_TO_TEST` aus Umgebung).
- `scripts/asc_beta_setup.py`: `plan_localization` (Z. 61) nur `LOCALE`; Text aus `BETA_DESCRIPTION_FILE` (Z. 31).
- `.github/workflows/testflight.yml`: Eingabe `what_to_test` (Z. 13–16), `WHAT_TO_TEST` (Z. 31), Aufrufe Z. 537, 559.
- `docs/reference/beta-beschreibung.md`, `scripts/test_asc_beta_setup.py`, `scripts/shipped_languages.py` (#756).

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_locales.py | NEW | `ASC_LOCALES = {"de": "de-DE", "en": "en-US"}`, `asc_locales(root)` über `shipped_languages`; unbekannter Code → `Fatal` |
| scripts/asc_what_to_test.py | MODIFY | `split_sections(text) -> dict[locale, text]`; je Fassung ihr Text, Rückfall `de-DE`-Text; fehlende Fassungen anlegen |
| scripts/asc_beta_setup.py | MODIFY | `plan_localization` je Locale; Text je Abschnitt aus `beta-beschreibung.md` |
| docs/reference/beta-beschreibung.md | MODIFY | Abschnitte `## de-DE` (heutiger Text) und `## en-US` (Übersetzung, gleicher Umfang, keine Ausrufezeichen) |
| scripts/test_asc_what_to_test.py | NEW | vier Tests |
| scripts/test_asc_beta_setup.py | MODIFY | zwei Tests |
| .github/workflows/testflight.yml | MODIFY | nur `description:` der Eingabe (Format), kein Schrittwechsel |
| CLAUDE.md, README.md | MODIFY | „Ship“: Format; README: englischer Absatz oben (drei Sätze) |

`project.yml` unberührt. LoC Python ≈ +120 / −20.

## Implementation Details

- Format `what_to_test`: Zeilen, die mit `de:` oder `en:` beginnen (Sprachcode aus `shipped_languages`, Doppelpunkt),
  eröffnen einen Abschnitt bis zum nächsten Marker; Text ohne Marker ist Deutsch. Jeder Abschnitt ≤ 4000 Zeichen (heutige Grenze).
- `write_what_to_test`: für jede Locale aus `asc_locales()` den Abschnitt der Sprache, sonst den deutschen; Fassungen, die
  Apple noch nicht hat, anlegen (heute nur `de-DE`); fremde vorhandene Fassungen (z. B. `fr-FR`) bekommen den deutschen Text wie heute.
- Beta-Beschreibung: `BETA_DESCRIPTION_FILE` wird in Abschnitte `## <locale>` geteilt; ohne Überschriften gilt die ganze
  Datei als `de-DE` (Rückwärtskompatibel). `plan_localization` wird je Locale gerufen; `feedbackEmail` und
  `privacyPolicyUrl` wie heute (URL je Locale kommt in #763).

## Test Plan

- [ ] `test_asc_what_to_test.py::test_sections_split_by_language_marker`: GIVEN `"de: A\nen: B"` THEN `{"de-DE": "A", "en-US": "B"}`.
- [ ] `::test_text_without_marker_is_german`: GIVEN `"A"` THEN `{"de-DE": "A"}`.
- [ ] `::test_missing_section_falls_back_to_german`: GIVEN nur `de:` WHEN Fassungen `de-DE`, `en-US` THEN beide bekommen A; `en-US` wird angelegt, wenn sie fehlt.
- [ ] `::test_unknown_language_code_fails`: GIVEN `shipped` mit `zz` ohne Tabelleneintrag THEN `Fatal` nennt `zz`.
- [ ] `test_asc_beta_setup.py::test_description_sections_per_locale`, `::test_file_without_headings_is_german`.
- [ ] Alle bestehenden Skripttests grün.

## Acceptance Criteria

- **AC-1:** Skripttests grün in der CI.
- **AC-2:** Nach dem Merge ein Lauf von `testflight.yml` (`workflow_dispatch`, `what_to_test` mit `de:`/`en:`-Abschnitten, dispatcht der Agent): das Log des Schritts `asc_what_to_test.py` zeigt `whatToTest gesetzt für de-DE, en-US`. Zeile im PR-Kommentar mit Lauf-Link. Scheitert der Lauf vor diesem Schritt an Signierung oder Apple, zählt AC-1 und der Kommentar nennt den Lauf und den Schritt.
- **AC-3:** README beginnt mit dem englischen Absatz; CLAUDE.md „Ship“ nennt das Format.

## Definition of Done

- [ ] AC-1 bis AC-3 belegt. PR `feat: TestFlight-Texte je Sprachfassung (Refs #750, Closes #760)`; Merge; Board Done.
- [ ] Nie `asc-beta.yml` mit `aktion=einreichen`.
- [ ] „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-30: Spec erstellt.
