# Adversary Dialog — feat-705-s2b2b-einreichung
Spec: docs/specs/feat-705-schnitt-2b2b-einreichung.md
Datum: 2026-10-28 09:57

## Checkliste
- [x] **AC-1:** Ohne den Schalter `--einreichen` sendet `asc_beta_invite.py` in keinem Szenario (erster Lauf, zweiter Lauf, bestehende Gruppe, Fehler beim Zuordnen) einen GET oder POST auf `betaAppReviewSubmissions`, und `asc-beta.yml` enthält die Zeichenfolge `betaAppReviewSubmissions` nicht. Geprüft durch `test_without_flag_never_submits`, den unveränderten `test_never_submits_and_never_enables_link` und `test_workflow_file`.
- [x] **AC-2:** Mit `--einreichen` und bereiten Builds wird je Plattform (iOS, macOS) genau ein POST auf `/v1/betaAppReviewSubmissions` gesendet, dessen Rumpf nur die Beziehung `build` mit der Build-ID trägt; Ausgabe `einreichung plattform=<P> zustand=eingereicht review=WAITING_FOR_REVIEW`, Exit 0. Geprüft durch `test_with_flag_submits_each_platform_once`.
- [x] **AC-3:** Mit `--einreichen` wird der Build zuerst der Gruppe `Tester` zugeordnet und danach genau dieser Build eingereicht (neuester gültiger Build der Plattform, nicht ein anderer in der Gruppe). Geprüft durch `test_assignment_happens_before_submission`.
- [x] **AC-4:** Ein zweiter Lauf mit `--einreichen` schreibt nichts: bei bestehender Einreichung in jedem Zustand (`WAITING_FOR_REVIEW`, `IN_REVIEW`, `APPROVED`, `REJECTED`) kein POST, Zeile `zustand=vorhanden review=<Zustand>`, `zusammenfassung geschrieben=0`. Geprüft durch `test_second_run_sends_no_submission` und `test_existing_submission_in_any_state_is_not_repeated`.
- [x] **AC-5:** Ist `externalBuildState` nicht `READY_FOR_BETA_SUBMISSION` (auch nicht lesbar), wird nicht eingereicht: kein POST, Zeile `zustand=nicht-bereit extern=<Wert>`, Exit 0; gibt es für eine Plattform keinen gültigen Build, steht `zustand=kein-gültiger-build` ohne POST. Geprüft durch `test_not_ready_build_is_not_submitted` und `test_platform_without_valid_build_is_reported`.
- [x] **AC-6:** Antwortet Apple auf die Einreichung mit 409, meldet das Skript `einreichung plattform=<P> zustand=konflikt` und endet mit Exit 0; die andere Plattform wird trotzdem bearbeitet. Geprüft durch `test_conflict_is_a_state_not_a_crash`.
- [x] **AC-7:** Antwortet Apple mit 422 `BETA_CONTRACT_MISSING`, druckt das Skript eine `::error::`-Zeile mit `platform=<P>` und Klartext (Beta-Vereinbarung bei Apple fehlt, der Konto-Inhaber muss sie annehmen), endet mit Exit 1 und wiederholt den POST nicht. Geprüft durch `test_missing_contract_names_the_account_holder`.
- [x] **AC-8:** Antwortet Apple mit 403, enthält die Ausgabe den bestehenden Text „Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen“, Exit ≠ 0. Geprüft durch `test_forbidden_submission_uses_existing_text`.
- [x] **AC-9:** Eine Plattform verdeckt die andere nicht: schlägt die Einreichung oder Zuordnung der einen Plattform fehl, wird die andere dennoch bearbeitet, die Schlusszeile `zusammenfassung geschrieben=<n>` steht zuletzt, und der Exit-Code ist 1. Geprüft durch `test_one_platform_failing_does_not_hide_the_other_submission`.
- [x] **AC-10:** Die Ausgabe (stdout und stderr) enthält nur Zustandswörter: keine Build-, Gruppen-, App- oder Einreichungs-IDs, keine Buildnummern, keine Links, kein Schlüsselmaterial, auch nicht in den Wiederholungszeilen der geteilten Helfer. Geprüft durch `test_submission_output_has_only_state_words` (und den unveränderten `test_output_has_only_state_words`).
- [x] **AC-11:** `.github/workflows/asc-beta.yml` bietet die Wahl `einreichen` an, der Job `submit` ruft `python3 scripts/asc_beta_invite.py --einreichen` nur bei `inputs.aktion == 'einreichen'` auf (Schlüssel mit `umask 077` und `trap rm`, `ubuntu-latest`), `probe` hängt per `needs` auch an `submit` und läuft nach `success` oder `skipped`; es gibt weiter nur die Eingabe `aktion` und keinen `push`-, `schedule`- oder `workflow_run`-Auslöser; `testflight.yml` nennt `asc_beta_invite` nicht. Geprüft durch den erweiterten `test_workflow_file`.
- [x] **AC-12:** Alle vorhandenen Skripttests (`python3 scripts/test_*.py`) sind grün, und der Diff berührt höchstens die fünf Dateien der Tabelle (±250 LoC) und keinen Pfad der Geräteliste. Geprüft durch die Testausgabe und `git diff --stat`.

## Dialog

### Runde 1
**Adversary:** Dritte Gegenprüfung. Tests selbst gelaufen: `python3 scripts/test_asc_beta_invite.py -v` 27 passed, 0 failed, 0 skipped; Regression 28/28 Testdateien grün (`adversary-test-output.txt`). Ich greife die behaupteten Fixes F004–F006 an und probe eigene Fälle in-process (Scratchpad `r3/probe.py`, Helfer gestubbt):
(1) Beide Plattformen liefern denselben Build (Plattformfilter von Apple ignoriert) – entsteht ein zweiter POST? (2) Ohne `--einreichen` und mit Build-Eintrag ohne `id` (Nicht-Fatal-Ausnahme) – ändert der breite Fang das 2b-1-Verhalten, POST auf Einreichungen? (3) Ausnahme, deren Text eine Kennung trägt – leakt sie über `message()`? (4) Einreichungsliste als Objekt statt Liste. (5) `externalBuildState` = null. (6) Tippfehler im Schalter `--einreichn`.
Ergebnisse: (1) genau ein POST, MAC_OS meldet `zustand=vorhanden`, Exit 0. (2) `::error::platform=IOS 'id'`, MAC_OS läuft weiter, Exit 1, null Aufrufe auf Einreichungen. (3) `::error::platform=IOS 'B-LEAK-ID'` erscheint unmaskiert – aber nur, weil mein Stub eine KeyError mit Kennung wirft; im echten Code ist kein dict nach Kennung geschlüsselt (alle Schlüssel sind Konstanten `id`/`data`/`attributes`/Konfig), `get_json`/`get_data` werfen nur `Fatal` mit maskierbarem Pfad. Vorher wäre dieselbe Ausnahme als Traceback ungefiltert auf stderr gelandet; der Fang verschärft also nichts. (4) Fehlerzeile `0`, kein POST (real unmöglich, `get_data` liefert nur Listen). (5) `extern=None` und `nicht-bereit`, kein POST. (6) nur Zuordnung, kein POST – sichere Richtung.
Zu F005 „erneuter POST nach Fehler“: `post_submission` (scripts/asc_beta_invite.py:123) hat keine Schleife und nutzt nicht `send_json` (das 5xx/Netzfehler wiederholt); jede Plattform wird in `main` (scripts/asc_beta_invite.py:178) genau einmal durchlaufen, der Fang in Zeile 187 setzt nur `failed` und geht zur nächsten Plattform. Ein zweiter POST derselben Plattform ist strukturell ausgeschlossen.
**Implementierer:** (aus Spec und Vorrunden) F004: 201 mit leerem/null `betaReviewState` ergibt `review=unbekannt`, +1 (scripts/asc_beta_invite.py:145, Test `test_unexpected_submission_body_is_still_reported`). F005: breiter Fang mit `message()`. F006: Nicht-Objekt-Einträge gelten als vorhanden (scripts/asc_beta_invite.py:54, Test `test_existing_submission_in_any_state_is_not_repeated` mit `["x"]`, `[None]`, `[{"attributes": "x"}]`).

### Runde 2
**Adversary:** Testkürzung gegen den Stand 4f0dba6 von scripts/test_asc_beta_invite.py geprüft. Entfallen: (a) in `test_assignment_happens_before_submission` die Mengenprüfung `set(fake.submissions) == {IOS, MAC}` – ersetzt durch die Schrittfolge je Build, die den Einreichungs-POST für beide Builds verlangt; keine AC-Aussage verloren. (b) In `test_existing_submission_in_any_state_is_not_repeated` lag die Einreichung vorher auf beiden Plattformen (Prüfung `submitted == []`), jetzt nur auf iOS; macOS wird eingereicht. Belegt bleibt: iOS kein POST (Gesamtzahl 1 = macOS, Zeile `IOS zustand=vorhanden review=<Zustand>`). `zusammenfassung geschrieben=0` ist für IN_REVIEW/APPROVED/REJECTED nicht mehr direkt getestet, nur für WAITING_FOR_REVIEW (`test_second_run_sends_no_submission`); `plan_submission` gibt für jeden Zustand `vorhanden` und 0 zurück – LOW F007. (c) `test_missing_contract_names_the_account_holder` prüft jetzt den vollen Wortlaut statt Teilstrings – stärker.
AC-12: Zeilenzählung gegen 02956f4: hinzugefügt außerhalb docs/ und .github/: asc_beta_invite.py 81, Test 168, CLAUDE.md 1 = 250 (edit_gate.py sperrt erst über 250, zählt nur Hinzufügungen, Produktiv und Tests getrennt). Mit Löschungen wären es 280 im Codeanteil – nach dem Projektmaß in Ordnung, aber exakt am Limit – LOW F008. Fremd geänderte Dateien: die fix-580-Dialogdatei (F001, bleibt draußen) und zusätzlich `docs/briefings/feat-705-apple-seite-einladung.md` (+1 Zeile `spec_frozen_sha256`, vermutlich Hook) – LOW F009, gleiche Behandlung wie F001. Kein Pfad der Geräteliste berührt.
Workflow: `setup` nur bei einrichten, `assign` nur bei zuordnen, `submit` nur bei einreichen (`needs: setup`, `!cancelled()`), `probe` nach success/skipped aller drei; `--einreichen` genau einmal; `testflight.yml` nennt `asc_beta_invite` nicht. Kein `concurrency` – zwei parallele Läufe ergäben für den zweiten 409 und damit `konflikt`, kein Schaden.
2b-1-Verhalten ohne Schalter: in allen regulären Pfaden unverändert (alle 2b-1-Tests grün); nur bei unerwarteten Nicht-Fatal-Ausnahmen jetzt `::error::`-Zeile statt Traceback, und die zweite Plattform läuft weiter – Verbesserung im Sinn von AC-9, streng genommen Abweichung von „Byte für Byte“ – LOW F010.
**Implementierer:** F007–F010 sind Restrisiken ohne AC-Verstoß; keine Codeänderung in dieser Runde.

## Findings

Finding:
  ID: F007
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_asc_beta_invite.py:347
  Description: Der gekürzte Test legt die bestehende Einreichung nur auf iOS; `zusammenfassung geschrieben=0` wird für IN_REVIEW/APPROVED/REJECTED nicht mehr direkt geprüft.
  Spec requirement: AC-4 — zweiter Lauf schreibt nichts, `geschrieben=0`, in jedem Zustand.
  Conflict: Kein Verstoß; `plan_submission` (scripts/asc_beta_invite.py:54) ist zustandsunabhängig, `geschrieben=0` ist für WAITING_FOR_REVIEW getestet.
  Remediation: optional ein Szenario mit beiden Plattformen vorhanden und zugeordnet.

Finding:
  ID: F008
  Severity: LOW
  Category: spec_violation
  Code reference: scripts/asc_beta_invite.py:1
  Description: Hinzugefügte Zeilen außerhalb docs/ und .github/: 250 (81 + 168 + 1), exakt an der Grenze; mit Löschungen 280.
  Spec requirement: AC-12 — ±250 LoC.
  Conflict: Nach dem konfigurierten Maß (edit_gate.py, nur Hinzufügungen, Sperre erst über 250) erfüllt; nach der globalen Zählweise (Additions + Deletions) knapp darüber.
  Remediation: keine nötig; bei jeder weiteren Zeile aufteilen.

Finding:
  ID: F009
  Severity: LOW
  Category: anti_pattern
  Code reference: CLAUDE.md:108
  Description: Neben den fünf Dateien ist auch `docs/briefings/feat-705-apple-seite-einladung.md` (+1 Zeile `spec_frozen_sha256`) ungesichert geändert, ebenso die fremde Datei aus F001.
  Spec requirement: AC-12 — Diff berührt höchstens die fünf Dateien (plus eigene Workflow-Artefakte).
  Conflict: Nur wenn sie mit gesichert wird.
  Remediation: beim Sichern explizit nur die fünf Dateien und `docs/artifacts/feat-705-s2b2b-einreichung/` aufnehmen.

Finding:
  ID: F010
  Severity: LOW
  Category: regression
  Code reference: scripts/asc_beta_invite.py:187
  Description: `except Exception` gilt auch ohne `--einreichen`: eine unerwartete Nicht-Fatal-Ausnahme ergibt jetzt `::error::platform=<P> <Text>` statt Traceback, die andere Plattform läuft weiter. Der Text ist `message()`-maskiert; eine Kennung erschiene nur, wenn eine Ausnahme sie ohne `/v1/`-Pfad trüge, wofür es im Code keinen Weg gibt (alle Schlüssel konstant).
  Spec requirement: Implementation Details 1 — ohne Schalter Ablauf „Byte für Byte“ wie 2b-1; AC-10 nur Zustandswörter.
  Conflict: Kein Verstoß in regulären Pfaden; abweichend nur im Absturzfall, dort weniger Leck als der frühere Traceback auf stderr.
  Remediation: keine nötig.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_beta_invite.py:177
  Evidence: `submitting` nur bei `--einreichen` in argv; `submit_platform` (einziger Aufrufer von GET/POST auf SUBMISSIONS) nur unter `if submitting`. Probe (6) Tippfehler: kein Aufruf. Tests `test_without_flag_never_submits`, `test_never_submits_and_never_enables_link`, `test_workflow_file` (`betaAppReviewSubmissions` nicht in asc-beta.yml) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_beta_invite.py:123
  Evidence: Rumpf nur `relationships.build` mit Build-ID, keine Attribute; `test_with_flag_submits_each_platform_once` prüft exakt zwei Rümpfe und beide Zeilen, Exit 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_beta_invite.py:120
  Evidence: `assign_platform` gibt die zugeordnete Build-ID zurück, `main` reicht genau sie an `submit_platform`; `test_assignment_happens_before_submission` mit altem Build in der Gruppe zeigt Zuordnung vor Einreichung je Build. Probe (1): gleicher Build auf beiden Plattformen ergibt einen POST.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_beta_invite.py:54
  Evidence: nicht leere Liste ergibt `vorhanden` in jedem Zustand und jeder Form, kein POST; Tests `test_second_run_sends_no_submission` (nur GET, geschrieben=0) und `test_existing_submission_in_any_state_is_not_repeated` (IN_REVIEW, APPROVED, REJECTED, unlesbare Einträge). Restrisiko F007.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_beta_invite.py:151
  Evidence: `build_id is None` ergibt `kein-gültiger-build`; extern ungleich READY ergibt `nicht-bereit extern=<Wert>` (auch `unbekannt`, Probe (5) auch `None`), kein POST; Tests `test_not_ready_build_is_not_submitted`, `test_platform_without_valid_build_is_reported`.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/asc_beta_invite.py:134
  Evidence: 409 ergibt None und `zustand=konflikt`, Zähler 0, kein `failed`; `test_conflict_is_a_state_not_a_crash` Exit 0, macOS eingereicht.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/asc_beta_invite.py:138
  Evidence: 422 mit BETA_CONTRACT_MISSING ergibt Fatal(CONTRACT), keine Wiederholung (kein send_json, keine Schleife); Test prüft vollen Wortlaut, Exit 1, genau ein iOS-POST.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/asc_beta_invite.py:137
  Evidence: 403 ergibt Fatal(FORBIDDEN) mit bestehendem Text; `test_forbidden_submission_uses_existing_text` Exit ungleich 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/asc_beta_invite.py:187
  Evidence: Fang je Plattform (Zuordnung und Einreichung im selben try), Schlusszeile nach der Schleife, `return 1 if failed`; `test_one_platform_failing_does_not_hide_the_other_submission` und `test_one_platform_failing_does_not_hide_the_other` grün; Probe (2) Nicht-Fatal-Ausnahme ebenso.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/asc_beta_invite.py:64
  Evidence: neue Zeilen tragen nur Zustandswörter; Fehlertexte ohne Kennung (`POST /v1/betaAppReviewSubmissions` ohne ID); stdout über `Masked`. `test_submission_output_has_only_state_words` prüft stdout und stderr gegen IDs, Buildnummern, Link, Schlüsselmaterial; `test_output_has_only_state_words`, `test_retry_lines_carry_no_ids` grün. Restrisiko F010.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: .github/workflows/asc-beta.yml:71
  Evidence: Wahl `einreichen` (Zeile 21), Job `submit` mit `inputs.aktion == 'einreichen'`, `ubuntu-latest`, `trap rm -f`, `umask 077`, `--einreichen` (Zeile 88); `probe` mit `needs: [setup, assign, submit]` und `needs.submit.result` (Zeilen 92-93); `testflight.yml` nennt `asc_beta_invite` nicht; `test_workflow_file` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: docs/reference/testflight.md:211
  Evidence: 28/28 Skripttestdateien grün; Code-Diff auf die fünf Dateien begrenzt (Doku: testflight.md Zeilen 172 und 211-221, CLAUDE.md Zeile 108), hinzugefügt 250 nach Projektmaß, kein Pfad der Geräteliste. Restrisiken F008, F009.
  Status: CONFIRMED

Weitere geprüfte Stellen:
Code reference: scripts/test_asc_beta_invite.py:408
Code reference: CLAUDE.md:108

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

```
═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: 27 passed, 0 failed, 0 übersprungen (test_asc_beta_invite.py); Regression 28/28 Testdateien grün
Edge cases: gleicher Build auf beiden Plattformen, Nicht-Fatal-Ausnahmen mit und ohne Schalter, Kennung im Ausnahmetext, extern null, Tippfehler im Schalter – keiner gebrochen
Regressions: keine (nur LOW F010: Absturzfall ohne Schalter meldet jetzt statt Traceback)
Checklist: 12/12 points proven
Restrisiken: F007–F010, alle LOW, kein AC-Verstoß
```

## Geprüfte Dateien

- sha256:8cb792fba3b3a83147d7e5a0fedc76c7ec53f2d33376c1ba1f0483e28767f36d  .github/workflows/asc-beta.yml
- sha256:bda0f6fbaf2b8b8270b7de66101b6cb26e94fb345636b82cf25b813fefc8d166  CLAUDE.md
- sha256:82134864035c080c2bdcea84e59939d308f853015a7f52e14adaaa5c608acd5d  docs/reference/testflight.md
- sha256:e4c2a1d8c7530b1f5862fc94ac317d51596451bbff69114a45ef5e47fcc99e20  scripts/asc_beta_invite.py
- sha256:f27a2c5ad5afa587042b684205aaa5cf9dc1487da95f10bd311b9b62bdfe9c75  scripts/test_asc_beta_invite.py

## Prüfbasis

- base: 02956f433eee05f2ca61dec1a1fcc7e174b2d37a
- blob:b84cf71301f1e9d9a40c5da43c65af24735a4512  .github/workflows/asc-beta.yml
- blob:cd75f51e49ededae27d5140bb00349e65d2dbb4d  CLAUDE.md
- blob:0d86153bed9bd1aae062a540d229f7cdf725877a  docs/reference/testflight.md
- blob:43a8606a52ebb6a29685edcee648793807ed8ae0  scripts/asc_beta_invite.py
- blob:0597823abd8c65c489b01b1b479fd7949b18e599  scripts/test_asc_beta_invite.py
