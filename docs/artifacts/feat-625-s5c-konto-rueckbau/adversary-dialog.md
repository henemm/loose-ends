# Adversary Dialog — feat-625-s5c-konto-rueckbau
Spec: docs/specs/feat-625-schnitt-5c-konto-rueckbau.md
Datum: 2026-11-23 18:07

## Checkliste
- [x] **AC-1:** GIVEN `.github/workflows/testflight.yml` WHEN sie als Text und als YAML gelesen wird THEN enthält `on.workflow_dispatch.inputs` keine Eingabe `konto` (die Eingaben `what_to_test` und `cleanup_dry_run` bleiben), der Text enthält weder `ACCOUNT_BUILD` noch `inputs.konto`, das Wort „Konto-Bau“ steht nicht mehr im Kopfkommentar, und `on.push.tags` bleibt `['v*']`. Test: `scripts/test_asc_what_to_test.py` `AccountBuildWorkflowTests.test_workflow_has_no_konto_input` (ersetzt `test_workflow_has_konto_input_default_true`).
- [x] **AC-2:** GIVEN die Jobs `upload` und `upload-mac` WHEN ihre Schritte gelesen werden THEN gibt es in keinem einen Schritt „Set the account switch“, und der Workflow-Text enthält weder `plutil -replace LEAccountEnabled` noch `privacy_manifest.py apply`; der Schritt „Set the APNs environment“ bleibt unbedingt und an seinem Platz. Test: `AccountBuildWorkflowTests.test_no_account_switch_step` (ersetzt `test_switch_step_is_conditional_and_between_generate_and_archive`) und `scripts/test_privacy_manifest.py` `WorkflowTests.test_apply_not_in_workflow` (ersetzt `test_apply_only_in_the_account_steps`).
- [x] **AC-3:** GIVEN die zwei Ausschnitte zwischen `# account-switch-check:begin` und `# account-switch-check:end` WHEN sie in Bash gegen Beispiel-Plists laufen THEN endet `account_switch` mit 0 nur für `LEAccountEnabled` als Bool `true`, und mit Fehler für Bool `false`, für den String `YES`, für den String `true` und für einen fehlenden Schlüssel; der Ausschnitt liest keine Umgebungsvariable `ACCOUNT_BUILD` (der Test setzt sie zur Kontrolle auf `false` und `true` und erwartet dasselbe Ergebnis). Test: `AccountBuildWorkflowTests.test_switch_check_logic` (umgebaut, 5 Fälle × beide Ausschnitte × beide Umgebungswerte).
- [x] **AC-4:** GIVEN die Archivprüfungen beider Jobs („Verify the archive is built against the iOS 27 SDK“, „Verify the macOS archive“) WHEN ihr Text gelesen wird THEN rufen beide `privacy_manifest.py check` fest mit `--account true` auf (kein `$ACCOUNT_BUILD`, kein `--account false`), setzen bei Fehler weiter `fail=1`, die iOS-Prüfung prüft weiter nur das App-Bundle (`$app_info`), die Mac-Prüfung weiter `"$APP/Contents/Resources/PrivacyInfo.xcprivacy"`, und beide rufen `account_switch` nach dem Ausschnitt auf. Test: `scripts/test_privacy_manifest.py` `WorkflowTests.test_archive_checks_call_check_with_account_true` (ersetzt `test_archive_checks_call_check_with_the_switch`) und `AccountBuildWorkflowTests.test_archive_checks_prove_switch_type_and_value`.
- [x] **AC-5:** GIVEN `scripts/asc_what_to_test.py` WHEN `main` mit `ACCOUNT_BUILD=true` in der Umgebung und mit `ACCOUNT_BUILD` ungesetzt läuft THEN sendet es in beiden Fällen den Text unverändert (ohne `ACCOUNT_BUILD_MARK`) an jede Sprachfassung; das Längenlimit von 4000 Zeichen gilt ohne Markenzuschlag (3990 Zeichen mit `ACCOUNT_BUILD=true` gehen durch); `mark_account_build` und jeder Zugriff auf `ACCOUNT_BUILD` fehlen im Skript, `ACCOUNT_BUILD_MARK` und `is_account_build` bleiben, und `ACCOUNT_BUILD_MARK` steht genau einmal im Skript. Test: `AccountBuildMarkTests.test_mark_never_added` (ersetzt `test_mark_is_added_to_every_section`, `test_mark_not_added_when_off`, `test_mark_in_every_written_localization`), `test_no_length_surcharge` (ersetzt `test_mark_respects_length_limit`) und `test_mark_defined_once` (angepasst: Skript ohne `ACCOUNT_BUILD`-Lesen).
- [x] **AC-6:** GIVEN `scripts/asc_store_version.py` WHEN die Zuordnung mit einem Bau läuft, dessen „Was testen“ `ACCOUNT_BUILD_MARK` trägt, THEN wird er weiter mit `bau IOS <n> übersprungen: konto` übersprungen, ebenso ein Bau mit unlesbaren oder leeren Texten (`texte nicht lesbar`), und ein unmarkierter Bau wird zugeordnet; der Docstring von `build_lock` sagt, dass die Sperre den alten markierten Bauten gilt (kein Hinweis mehr auf die Eingabe `konto`). Test: `scripts/test_asc_store_version.py` (bestehende Tests der Zuordnung, bleiben grün) und `scripts/test_asc_what_to_test.py` `AccountBuildMarkTests.test_store_lock_docstring_names_old_builds`.
- [x] **AC-7:** GIVEN `scripts/test_aps_environment.py` WHEN `test_account_switch_blocks_untouched` (umbenannt `test_account_switch_blocks_pinned`) läuft THEN liegt der SHA-256 beider `account-switch-check`-Blöcke bewusst auf dem neuen Wert (beide Blöcke gleich, Bool-Prüfung mit festem `true`, kein `ACCOUNT_BUILD`), der alte Hash `61a92665763135516a59c8583f71c6577e93aa8d98e591e171af777a6d8427d9` kommt in der Datei nur noch als Kommentar „Stand vor #625 S5c“ vor und passt auf keinen der Blöcke, der Block enthält nicht `LEApsEnvironment`, und `plutil -replace LEAccountEnabled` kommt im Workflow nicht vor. Test: `test_aps_environment.py` `WorkflowTests.test_account_switch_blocks_pinned`.
- [x] **AC-8:** GIVEN der Workflow-Text WHEN er auf Sonderwege für Tag-Läufe geprüft wird THEN gibt es keine Bedingung, die `github.ref`, `github.event_name` oder `startsWith(github.ref, 'refs/tags` zur Wahl des Kontoschalters oder der Archivprüfung benutzt (die Sollwerte sind für Hand- und Tag-Lauf dieselben), und die Prüfausschnitte und Aufrufe in beiden Jobs sind nicht von `if:` abhängig. Test: `AccountBuildWorkflowTests.test_tag_run_has_no_special_path`.
- [x] **AC-9:** GIVEN `docs/reference/testflight.md` und `CLAUDE.md` WHEN sie gelesen werden THEN steht in `CLAUDE.md` im Abschnitt „Ship“ und in `docs/reference/testflight.md`: Der Konto-Schalter steht an der Quelle (#625 S5b), die Eingabe `konto` und die Marke im Lauf sind seit #625 S5c entfernt, Archivprüfungen halten Bool `true` und `--account true` fest, `asc_store_version.py` überspringt weiter alte Bauten mit der Marke; die Sätze „`konto` on“, „Run workflow → Haken „Konto-Bau““, „until it is removed in #625 S5c“ und „bis dahin gelten die Sätze zu `konto` unverändert“ kommen in keiner der beiden Dateien mehr vor, und die Sitzungsregel („manual runs keep the account group, `konto` on, …“) lautet „manual runs carry over the previous build's open test points“ ohne Kontobezug. Test: `AccountBuildMarkTests.test_docs_describe_removed_mechanism` (ersetzt `test_docs_name_account_build`; prüft zusätzlich, dass der Wortlaut der Marke in keiner der beiden Dateien steht).
- [x] **AC-10:** GIVEN die Gesamt-Diffliste WHEN sie geprüft wird THEN enthält sie keine Swift-Datei, kein `project.yml`, keine `Info.plist`, keine `.entitlements` und kein `PrivacyInfo.xcprivacy`, und der Gesamtlauf `python3 -m unittest discover -s scripts -p 'test_*.py'` ist grün, einschließlich `test_info_plist_sync.py`, `test_entitlements_sync.py` und `test_app_store_datenschutzangaben.py`. Test: `scripts/test_asc_what_to_test.py` `AccountBuildWorkflowTests.test_source_files_unchanged_in_marker_set` (liest `project.yml`: `LEAccountEnabled` bleibt Bool `true`, Manifest-Quelle bleibt die drei Typen) und der Gesamtlauf.

## Dialog

### Runde 1
**Adversary:** Behauptung: Rückbau vollständig. Beweise: (1) YAML geparst, Eingaben nur what_to_test und cleanup_dry_run, push.tags ['v*'], Jobs upload/upload-mac: Schrittfolge Generate project, Set the APNs environment, Store key, Archive (kein Schritt Set the account switch). (2) Suche nach ACCOUNT_BUILD, konto=, inputs.konto außerhalb von specs/artifacts/context: nur Tests (assertNotIn) und eine Doku-Erwähnung des Verlaufs, kein Aufrufer. (3) Änderungsliste: beide account_switch-Blöcke identisch, fester Vergleich auf Typ bool und Wert true, fail=1 bleibt, fail wird weiter ausgewertet. (4) Tests: test_asc_* 379 OK (adversary-test-output.txt), test_privacy_manifest 17 OK, test_aps_environment 10 OK; Gesamtlauf 807 OK (1 Umgebungs-Skip, nicht dieser Schnitt).
Code reference: .github/workflows/testflight.yml:218 (Block iOS), :515 (Block Mac), :257 und :546 (`--account true`).
Confirmation: AC-1, AC-2, AC-3, AC-4, AC-8 CONFIRMED (Tests test_workflow_has_no_konto_input, test_no_account_switch_step, test_switch_check_logic mit 5 Fällen x 2 Blöcke x 2 Umgebungswerten, test_tag_run_has_no_special_path grün).
Code reference: scripts/asc_what_to_test.py:30 (ACCOUNT_BUILD_MARK einmal, kein mark_account_build, kein Umgebungszugriff in main). AC-5 CONFIRMED.
Code reference: scripts/asc_store_version.py:141 (Docstring nennt alte markierte Bauten; Logik unverändert). AC-6 CONFIRMED.
Code reference: scripts/test_aps_environment.py:124 (Hash bewusst neu, alter nur als Kommentar). AC-7 CONFIRMED.
Code reference: scripts/test_privacy_manifest.py:192 (check mit --account true) und :183 (apply nicht im Workflow). AC-2/AC-4 CONFIRMED.
Code reference: scripts/test_asc_what_to_test.py:337 (Prüfausschnitt in bash, 5 Plist-Fälle). AC-3 CONFIRMED.
Code reference: docs/reference/testflight.md:357 und CLAUDE.md:295. AC-9 CONFIRMED; verbotene Sätze nicht mehr vorhanden, Sitzungsregel ohne Kontobezug.
AC-10: Änderungsliste enthält nur die fünf genannten Dateien (kein Swift, project.yml, plist, entitlements, xcprivacy); Gesamtlauf grün.
Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/privacy_manifest.py:75
  Description: Docstring und Doku-Zeilen (docs/reference/datenschutz-entwurf.md:166, docs/reference/app-store-datenschutzangaben.md:7) sprechen weiter von „Konto-Bauten“ und „Manifest folgt dem Konto-Schalter“.
  Spec requirement: AC-9 betrifft nur testflight.md und CLAUDE.md
  Conflict: Kein Widerspruch zu einem AC; nur sprachlich veraltet, Datenschutzentwurf braucht PO-Freigabe.
  Remediation: Optional in S5d angleichen.
**Implementierer:** F001 wird nicht in S5c bearbeitet (Rechtstext, Scope-Grenze).

### Runde 2
**Adversary:** Zweiter Angriff. (a) Tag-Lauf: keine if-Bedingung und keine Ref-Prüfung im Prüfpfad (Test AC-8 grün). (b) Manifestprüfung iOS bleibt auf das App-Bundle begrenzt, Mac auf das Resources-Manifest. (c) Fehlerpfad: `|| { res=FEHLER; fail=1; }` bleibt, danach `[ "$fail" = 0 ]`. (d) Alte markierte Bauten: is_account_build bleibt, test_asc_store_version grün. (e) Beide Blöcke gleich, alter Hash passt auf keinen. Keine neue Schwäche gefunden. Der Nachweis durch einen echten TestFlight-Lauf steht laut Spec in der DoD.
**Implementierer:** Keine Änderung nötig.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 406 gezielt bestanden, 0 fehlgeschlagen (Gesamtlauf 807 OK, 1 Umgebungs-Skip)
Findings: F001 (LOW, nicht blockierend)
Checklist: 10/10 points proven

## Geprüfte Dateien

- sha256:d8ddf4b7e5eaca54748cb13ee3272acba1660904e9e2ac74da501daaf5d7525a  .github/workflows/testflight.yml
- sha256:65fdb8d2944b124e05061c1c2039511ea9158696c35ef387a7c9561f9cca1f66  docs/reference/testflight.md
- sha256:138c803aa0bde01a36c28552ede72208d844b31ba5b1c03f1ca8d96860b6cfe2  scripts/asc_store_version.py
- sha256:503ded728f531fba277b6cad6e2568ec72e6091831597caed4f7ab8b1278c3c0  scripts/asc_what_to_test.py
- sha256:e025829adab621b042833add2b29df7762856429647736be4ca8a7e808bb3992  scripts/privacy_manifest.py
- sha256:2427b5e500f2575d10a50bafd12d6f53efb7eaee75c10c4cd62cbb273deeb17a  scripts/test_aps_environment.py
- sha256:09fd939ea68f6ddf21a94997f0a54ba024070bee247963ca15c67391fc49a48c  scripts/test_asc_what_to_test.py
- sha256:7243a9ab0c1f1b3d33415fd921b404c26932a8c29c582ba9d0ed24740650ce29  scripts/test_privacy_manifest.py

## Prüfbasis

- base: f6214ccf2f401095d41ffbfce4cf294c827c3a7e
- blob:2d490ed4eec3386036a3e9596e5748eb6078b6ed  .github/workflows/testflight.yml
- blob:ed2cd2e4e03e3cc9a8c3ca637c7b76c3ccaee1fe  docs/reference/testflight.md
- blob:7925b802f15217ab86ad6e33c1ba05947f765b43  scripts/asc_store_version.py
- blob:6a2c7d2a7f05c5b423b08100abeeeec27c5454bd  scripts/asc_what_to_test.py
- blob:4d2a64c10c851147f3081c81eb1a1213f0b9195c  scripts/privacy_manifest.py
- blob:1c2faa3a82994ff1c54ec09b213a911f9428ab74  scripts/test_aps_environment.py
- blob:8c7adc195af6ad7b9b746cfb35a7e8be5840918b  scripts/test_asc_what_to_test.py
- blob:afc795bd91519bcde6077e2508173bef32e32c6f  scripts/test_privacy_manifest.py
