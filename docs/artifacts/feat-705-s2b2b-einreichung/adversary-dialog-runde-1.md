# Adversary Dialog — feat-705-s2b2b-einreichung
Spec: docs/specs/feat-705-schnitt-2b2b-einreichung.md
Datum: 2026-10-28 09:18

## Checkliste
- [x] **AC-1:** Ohne den Schalter `--einreichen` sendet `asc_beta_invite.py` in keinem Szenario (erster Lauf, zweiter Lauf, bestehende Gruppe, Fehler beim Zuordnen) einen GET oder POST auf `betaAppReviewSubmissions`, und `asc-beta.yml` enthält die Zeichenfolge `betaAppReviewSubmissions` nicht. Geprüft durch `test_without_flag_never_submits`, den unveränderten `test_never_submits_and_never_enables_link` und `test_workflow_file`.
- [x] **AC-2:** Mit `--einreichen` und bereiten Builds wird je Plattform (iOS, macOS) genau ein POST auf `/v1/betaAppReviewSubmissions` gesendet, dessen Rumpf nur die Beziehung `build` mit der Build-ID trägt; Ausgabe `einreichung plattform=<P> zustand=eingereicht review=WAITING_FOR_REVIEW`, Exit 0. Geprüft durch `test_with_flag_submits_each_platform_once`.
- [x] **AC-3:** Mit `--einreichen` wird der Build zuerst der Gruppe `Tester` zugeordnet und danach genau dieser Build eingereicht (neuester gültiger Build der Plattform, nicht ein anderer in der Gruppe). Geprüft durch `test_assignment_happens_before_submission`.
- [x] **AC-4:** Ein zweiter Lauf mit `--einreichen` schreibt nichts: bei bestehender Einreichung in jedem Zustand (`WAITING_FOR_REVIEW`, `IN_REVIEW`, `APPROVED`, `REJECTED`) kein POST, Zeile `zustand=vorhanden review=<Zustand>`, `zusammenfassung geschrieben=0`. Geprüft durch `test_second_run_sends_no_submission` und `test_existing_submission_in_any_state_is_not_repeated`.
- [x] **AC-5:** Ist `externalBuildState` nicht `READY_FOR_BETA_SUBMISSION` (auch nicht lesbar), wird nicht eingereicht: kein POST, Zeile `zustand=nicht-bereit extern=<Wert>`, Exit 0; gibt es für eine Plattform keinen gültigen Build, steht `zustand=kein-gültiger-build` ohne POST. Geprüft durch `test_not_ready_build_is_not_submitted` und `test_platform_without_valid_build_is_reported`.
- [x] **AC-6:** Antwortet Apple auf die Einreichung mit 409, meldet das Skript `einreichung plattform=<P> zustand=konflikt` und endet mit Exit 0; die andere Plattform wird trotzdem bearbeitet. Geprüft durch `test_conflict_is_a_state_not_a_crash`.
- [x] **AC-7:** Antwortet Apple mit 422 `BETA_CONTRACT_MISSING`, druckt das Skript eine `::error::`-Zeile mit `platform=<P>` und Klartext (Beta-Vereinbarung bei Apple fehlt, der Konto-Inhaber muss sie annehmen), endet mit Exit 1 und wiederholt den POST nicht. Geprüft durch `test_missing_contract_names_the_account_holder`.
- [x] **AC-8:** Antwortet Apple mit 403, enthält die Ausgabe den bestehenden Text „Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen“, Exit ≠ 0. Geprüft durch `test_forbidden_submission_uses_existing_text`.
- [ ] **AC-9:** Eine Plattform verdeckt die andere nicht: schlägt die Einreichung oder Zuordnung der einen Plattform fehl, wird die andere dennoch bearbeitet, die Schlusszeile `zusammenfassung geschrieben=<n>` steht zuletzt, und der Exit-Code ist 1. Geprüft durch `test_one_platform_failing_does_not_hide_the_other_submission`.
- [x] **AC-10:** Die Ausgabe (stdout und stderr) enthält nur Zustandswörter: keine Build-, Gruppen-, App- oder Einreichungs-IDs, keine Buildnummern, keine Links, kein Schlüsselmaterial, auch nicht in den Wiederholungszeilen der geteilten Helfer. Geprüft durch `test_submission_output_has_only_state_words` (und den unveränderten `test_output_has_only_state_words`).
- [x] **AC-11:** `.github/workflows/asc-beta.yml` bietet die Wahl `einreichen` an, der Job `submit` ruft `python3 scripts/asc_beta_invite.py --einreichen` nur bei `inputs.aktion == 'einreichen'` auf (Schlüssel mit `umask 077` und `trap rm`, `ubuntu-latest`), `probe` hängt per `needs` auch an `submit` und läuft nach `success` oder `skipped`; es gibt weiter nur die Eingabe `aktion` und keinen `push`-, `schedule`- oder `workflow_run`-Auslöser; `testflight.yml` nennt `asc_beta_invite` nicht. Geprüft durch den erweiterten `test_workflow_file`.
- [ ] **AC-12:** Alle vorhandenen Skripttests (`python3 scripts/test_*.py`) sind grün, und der Diff berührt höchstens die fünf Dateien der Tabelle (±250 LoC) und keinen Pfad der Geräteliste. Geprüft durch die Testausgabe und `git diff --stat`.

## Dialog

### Runde 1
**Adversary:** Beweise für AC-1 bis AC-12, nicht nur die mitgelieferten Tests. Konkret: (a) Gibt es ohne `--einreichen` irgendeinen Weg zu `betaAppReviewSubmissions`? (b) Wird der POST je wiederholt, auch bei 5xx oder Timeout? (c) Wird genau der zugeordnete Build eingereicht? (d) Wird nach einem gescheiterten Zuordnen trotzdem eingereicht? (e) Lecken IDs über Fehler- oder Wiederholungszeilen? (f) Hält die Probe-Bedingung, wenn `submit` scheitert? (g) LoC gegen `openspec.yaml`.
**Implementierer:** (Belegt durch Code und Läufe, vom Adversary selbst nachgeprüft.)
- Tests: `python3 scripts/test_asc_beta_invite.py -v` → `Ran 26 tests … OK`, exit 0; alle 28 `scripts/test_*.py` exit 0, keine übersprungenen (`docs/artifacts/feat-705-s2b2b-einreichung/adversary-test-output.txt`).
- (a) Der Schalter wird nur an einer Stelle gelesen: Code reference: scripts/asc_beta_invite.py:173 (`submitting = "--einreichen" in argv[1:]`); `submit_platform` wird nur in Code reference: scripts/asc_beta_invite.py:179 aufgerufen, `post_submission` nur aus `submit_platform` (Zeile 158). Eigene Probe `probe_flag_variants_do_not_submit`: `--einreichen=ja`, `--EINREICHEN`, `einreichen`, `-einreichen` → kein Aufruf auf den Pfad (`assert_clean`). Test Code reference: scripts/test_asc_beta_invite.py:303 (`test_without_flag_never_submits`, drei Szenarien × zwei Läufe, also auch zweiter Lauf) und der unveränderte `test_never_submits_and_never_enables_link` (Zeile 234).
- (b) `post_submission` benutzt NICHT `send_json` (das 5× wiederholt), sondern ein eigenes einmaliges `urlopen`: Code reference: scripts/asc_beta_invite.py:129. Probe `probe_post_503_not_retried`: 503 auf iOS → genau 1 POST für iOS, `::error::platform=IOS ASC answered HTTP 503 for POST /v1/betaAppReviewSubmissions`, macOS `eingereicht`, exit 1. Netzfehler/Timeout → `Fatal` ohne Wiederholung (Zeile 140). 401 → je Plattform genau 1 POST (`probe_401_on_post`).
- (c) Die Build-ID fließt aus `assign_platform` (Rückgabe Zeile 119) direkt in `submit_platform`; Test Code reference: scripts/test_asc_beta_invite.py:324 (alter Build `B-91f3-OLD` in der Gruppe wird nicht eingereicht, Reihenfolge Zuordnung → Einreichung je Build).
- (d) Probe `probe_assign_fail_with_flag`: 422 auf die iOS-Zuordnung → `::error::platform=IOS …/relationships/builds`, KEIN Aufruf auf `betaAppReviewSubmissions` mit der iOS-ID (weder GET noch POST), macOS zugeordnet und eingereicht, Schlusszeile `zusammenfassung geschrieben=3` zuletzt, exit 1. (Die eigene Erwartung `=2` war falsch: Gruppe + macOS-Zuordnung + macOS-Einreichung = 3.)
- (e) Fehlertexte von `post_submission` enthalten nur den festen Pfad ohne ID (Zeile 139/141); GET-Wiederholungszeilen schneiden die Query ab (`asc_wait_build.get_json`, `url_path = path.split("?")[0]`). Probe `probe_get_submissions_down_fail_closed`: 5× `ASC answered HTTP 503 for /v1/betaAppReviewSubmissions, retrying`, keine ID in stdout/stderr, und kein POST (fail closed). Test Code reference: scripts/test_asc_beta_invite.py:409.
- (f) Code reference: .github/workflows/asc-beta.yml:93 — `probe` läuft nur bei `needs.submit.result` `success` oder `skipped`; scheitert `submit` (exit 1), wird `probe` übersprungen. Das ist genau AC-11. `submit` (Code reference: .github/workflows/asc-beta.yml:71) hat `if: !cancelled() && inputs.aktion == 'einreichen'`, `umask 077`, Aufräumen per trap, `ubuntu-latest`, einziger Aufruf mit `--einreichen` (Zeile 88).
- (g) `openspec.yaml` scope_guard: 250, nur hinzugefügte Zeilen, `^docs/` und `^\.github/` ausgenommen, `scripts/test_*` zählt NICHT als Testpfad. Hinzugefügt: `scripts/asc_beta_invite.py` 76 + `scripts/test_asc_beta_invite.py` 170 + `CLAUDE.md` 1 = 247 ≤ 250 (knapp). Doku Code reference: docs/reference/testflight.md:211 und Code reference: CLAUDE.md:108.

### Runde 2
**Adversary:** Runde 1 hat nur Fehler-Antworten mit HTTP-Status geprüft. Was passiert bei einer erfolgreichen, aber unerwartet geformten Antwort auf den unumkehrbaren POST, und berührt der Arbeitsstand wirklich nur die fünf Dateien?
**Implementierer:** (Vom Adversary nachgeprüft, zwei Befunde.)
- Probe `probe_non_object_body_201` (Apple antwortet 201 mit `["x"]`) und `probe_data_is_list_201` (201 mit `{"data":[1]}`): Die Einreichung ist im Nachbau angelegt (1 POST), dann `AttributeError: 'list' object has no attribute 'get'` in Code reference: scripts/asc_beta_invite.py:144. Folge: keine Zeile `einreichung … eingereicht` für iOS, keine `::error::`-Zeile, macOS wird nicht bearbeitet, keine Schlusszeile `zusammenfassung`, Traceback auf stderr, exit 1, also `probe` übersprungen. Der geteilte Helfer `get_json` fängt genau diesen Fall ab („ASC sent an unexpected body“), der neue POST-Pfad nicht. Der nächste Lauf heilt (iOS `vorhanden`, macOS eingereicht), es gibt keine Doppel-Einreichung; aber AC-9 („die andere wird dennoch bearbeitet“, „Schlusszeile steht zuletzt“) bricht hier. → F002.
- Bodyloser Erfolg (204/leer): `zustand=eingereicht review=unbekannt`, exit 0 (`probe_empty_204`), in Ordnung. 422 `BETA_CONTRACT_MISSING` auf macOS: `::error::platform=MAC_OS Beta-Vereinbarung bei Apple fehlt: der Konto-Inhaber muss sie …`, iOS eingereicht (`probe_contract_on_mac`). 409: Code reference: scripts/asc_beta_invite.py:133 → `konflikt`, Schreibzähler 0, exit 0 (Test Zeile 378).
- Arbeitsstand: `docs/artifacts/fix-580-veraltete-schnittstellen/adversary-dialog.md` ist ungesichert geändert (9 Zeilen: AC-6 bis AC-8 und die Geräte-ACs AC-12 bis AC-17 eines anderen Workflows von `[ ]` auf `[x]`). Diese Datei steht nicht in der Tabelle der Spec und hat mit #705 nichts zu tun; gerät sie in den PR, verstößt der Diff gegen AC-12 und hakt fremde Gerätepunkte ohne Beleg ab. → F001.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: CLAUDE.md:108
  Description: Neben den fünf Spec-Dateien (CLAUDE.md:108 ist die letzte der fünf) ist im Arbeitsstand die fremde Datei docs/artifacts/fix-580-veraltete-schnittstellen/adversary-dialog.md geändert: neun Checklistenpunkte eines anderen Workflows, darunter die Gerätepunkte AC-12 bis AC-17, von offen auf abgehakt.
  Spec requirement: AC-12 — der Diff berührt höchstens die fünf Dateien der Tabelle.
  Conflict: Werden alle Änderungen übernommen, landet eine fremde Änderung im PR und hakt Gerätepunkte von #580 ohne Beleg ab.
  Remediation: Diese Datei nicht übernehmen (auf den letzten gesicherten Stand zurücksetzen), nur die fünf Dateien plus die eigenen Workflow-Artefakte aufnehmen; Herkunft der Änderung klären.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_beta_invite.py:144
  Description: post_submission nimmt an, dass body und body["data"] Objekte sind. Bei einer 201-Antwort mit JSON-Liste oder data als Liste wirft Zeile 144 AttributeError NACH dem erfolgreichen, unumkehrbaren POST; main fängt nur Fatal (Zeile 183).
  Spec requirement: AC-9 — eine Plattform verdeckt die andere nicht, die Schlusszeile steht zuletzt.
  Conflict: Die Einreichung von iOS ist erfolgt, aber ungemeldet; macOS wird nicht bearbeitet, keine Schlusszeile, Traceback statt Zustandswort, probe übersprungen. Reproduktion: Scratchpad-Probe probe_non_object_body_201 / probe_data_is_list_201.
  Remediation: Vor Zeile 144 body = body if isinstance(body, dict) else {} und data = body.get("data"); data = data if isinstance(data, dict) else {}; einen Test mit 201 und unerwartetem Rumpf ergänzen (Erwartung eingereicht review=unbekannt, macOS bearbeitet, Schlusszeile zuletzt).

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: .github/workflows/asc-beta.yml:93
  Description: Scheitert submit nur auf einer Plattform (z. B. macOS 422), ist die andere eingereicht, submit endet aber mit exit 1 und probe wird übersprungen.
  Spec requirement: AC-11 — probe läuft nach success oder skipped (so umgesetzt); Purpose — „Die Probe desselben Laufs ist der Beleg“.
  Conflict: Kein Verstoß gegen AC-11, aber bei Teilerfolg fehlt der Beleg desselben Laufs; es braucht einen zweiten Lauf aktion=probe.
  Remediation: Optional probe auch nach failure von submit laufen lassen, oder in testflight.md festhalten, dass bei Teilerfolg ein Lauf probe folgt.

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_beta_invite.py:173
  Evidence: Schalter nur hier gelesen; ohne ihn kein Aufruf von submit_platform; test_without_flag_never_submits und Probe mit Schalter-Varianten grün; asc-beta.yml enthält betaAppReviewSubmissions nicht (test_workflow_file).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_asc_beta_invite.py:312
  Evidence: Genau zwei POSTs mit Rumpf nur relationships.build; Zeilen eingereicht review=WAITING_FOR_REVIEW, exit 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_beta_invite.py:119
  Evidence: assign_platform gibt die zugeordnete build_id zurück, die unverändert in submit_platform/post_submission geht; Test Zeile 324 mit altem Build in der Gruppe; Probe: gescheiterte Zuordnung → keine Einreichung dieser Plattform.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_beta_invite.py:54
  Evidence: plan_submission liefert bei nicht leerer Liste immer vorhanden; Tests Zeile 334 (WAITING_FOR_REVIEW, nur GET, geschrieben=0) und 345 (IN_REVIEW, APPROVED, REJECTED, kein POST).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_beta_invite.py:150
  Evidence: build_id None → kein-gültiger-build ohne Lesen/Schreiben; extern != READY (auch unbekannt aus read_extern) → nicht-bereit; Tests Zeile 354 und 367. Probe: GET der Einreichungsliste dauerhaft 503 → kein POST (fail closed).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/asc_beta_invite.py:133
  Evidence: 409 → None → konflikt, Zähler 0; Test Zeile 378: exit 0, macOS eingereicht.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/asc_beta_invite.py:137
  Evidence: 422 mit BETA_CONTRACT_MISSING → Fatal(CONTRACT) → ::error::platform=<P> Beta-Vereinbarung … Konto-Inhaber …; Test Zeile 385 (genau ein POST für iOS, exit 1), Probe für MAC_OS.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/asc_beta_invite.py:135
  Evidence: 403 → Fatal(FORBIDDEN) mit dem vollständigen bestehenden Text; Test Zeile 396.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/test_asc_beta_invite.py:409
  Evidence: Ausgaben dreier Szenarien ohne G-/B-/S-IDs, Buildnummern, APP1, Link, Schlüssel; Probe: Wiederholungszeilen der Einreichungsliste ohne ID.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: .github/workflows/asc-beta.yml:71
  Evidence: Job submit mit inputs.aktion == 'einreichen', umask 077, trap mit Löschen der Schlüsseldatei, ubuntu-latest, --einreichen genau einmal; probe needs [setup, assign, submit] mit success/skipped (Zeile 92–93); nur Eingabe aktion, kein push/schedule/workflow_run; test_workflow_file grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12 (Teil Tests und LoC)
  Code reference: docs/reference/testflight.md:211
  Evidence: Alle 28 Skripttests grün, 247 hinzugefügte Zeilen im Produktivbudget (≤ 250), kein Pfad der Geräteliste. Offen nur F001 (fremde Datei im Arbeitsstand).
  Status: CONFIRMED (Teil), Rest siehe F001


## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: BROKEN

Finding F002: Unerwartet geformte 201-Antwort auf den unumkehrbaren POST lässt das Skript nach der Einreichung abstürzen (AttributeError); die andere Plattform wird nicht bearbeitet, keine Schlusszeile.
  Severity: MEDIUM
  Evidence: scripts/asc_beta_invite.py:144
  Reproduction: FakeASC.write für POST /v1/betaAppReviewSubmissions auf (201, ["x"]) umbiegen, asc_beta_invite.py --einreichen → Traceback nach 1 POST, kein MAC_OS, keine zusammenfassung.

Finding F001: Fremde Änderung an docs/artifacts/fix-580-veraltete-schnittstellen/adversary-dialog.md (Gerätepunkte von #580 abgehakt) im Arbeitsstand; darf nicht in den PR.
  Severity: MEDIUM
  Evidence: Arbeitsstand, 9 geänderte Checklistenzeilen dieser Datei

Finding F003 (LOW): Bei Teilerfolg von submit fällt die Probe desselben Laufs aus (spec-konform, Beleg fehlt).

Tests: 26 passed, 0 failed, 0 übersprungen (test_asc_beta_invite.py); Regression 28/28 Skripte grün
Checklist: 10/12 belegt (AC-9 durch F002 gebrochen, AC-12 durch F001 offen)

## Geprüfte Dateien

- sha256:8cb792fba3b3a83147d7e5a0fedc76c7ec53f2d33376c1ba1f0483e28767f36d  .github/workflows/asc-beta.yml
- sha256:bda0f6fbaf2b8b8270b7de66101b6cb26e94fb345636b82cf25b813fefc8d166  CLAUDE.md
- sha256:ddb312973a27b7f8894c0a7adfb2dde5f3d9d97e671d916a4cf2975b2b9ff267  docs/reference/testflight.md
- sha256:b254bf20bf74c028754b6773500120d3ed5b414f84113bd73069ca8ff63765a4  scripts/asc_beta_invite.py
- sha256:0b12531dfadd1e8217b35e542ec0423316245fafb0c7bdc848f30ad0397ac5fa  scripts/test_asc_beta_invite.py

## Prüfbasis

- base: 02956f433eee05f2ca61dec1a1fcc7e174b2d37a
- blob:b84cf71301f1e9d9a40c5da43c65af24735a4512  .github/workflows/asc-beta.yml
- blob:cd75f51e49ededae27d5140bb00349e65d2dbb4d  CLAUDE.md
- blob:5abde94d4de0847970a2c4d80fb4d061ba4a7d1d  docs/reference/testflight.md
- blob:74e7a4635ba320839286d7dd4572c6d1fa0d0df7  scripts/asc_beta_invite.py
- blob:baa9c2e9f4581dca165a643f1d4bb63a7cdd56f4  scripts/test_asc_beta_invite.py
