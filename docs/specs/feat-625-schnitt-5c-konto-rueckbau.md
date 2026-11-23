---
entity_id: feat-625-schnitt-5c-konto-rueckbau
type: feature
created: 2026-11-23
updated: 2026-11-23
status: draft
workflow: feat-625-s5c-konto-rueckbau
---

# Spec: Konto-Mechanik im TestFlight-Lauf zurückbauen (Schnitt 5c, #625)

## Approval

- [ ] Approved

## GitHub Issue

#625 (Store-Schalter, Einreichung). Schnitt 5c; das Issue bleibt offen (`Refs #625`, nie `Closes #625`).
Analyse: `docs/context/feat-625-s5c-konto-rueckbau.md`. Schnittplan S5a bis S5d und PO-Entscheidung vom 2026-11-22: `docs/context/feat-625-konto-schalter.md`.
Vorgänger: `docs/specs/feat-625-schnitt-5b-schalter-quelle.md` (Schalter und Manifest an der Quelle), `docs/specs/feat-625-schnitt-2-privacy-manifest.md` (Manifest folgt dem Schalter; dort wurde `check --account` und der Schritt „Set the account switch“ um `apply` erweitert), `docs/specs/feat-615-schnitt-4c2a-freischalten.md` (Konto-Bau-Mechanik).

**Nicht in diesem Schnitt:** S5d (Store: datiertes Ja zur Fragebogen-Vorlage, Etikett im ASC-Web, Version 1.0.2, Texte, Review-Notizen, Einreichen, Betriebs-Tür auf `ALLOWED_APPLE_SUBS=*`).

## Für den PO

Die Verbindung zu Claude ist seit dem letzten Schnitt immer an. Der Sonderschalter „Konto-Bau“ beim Start eines TestFlight-Laufs ist damit überflüssig und sogar im Weg: Ein Lauf, der automatisch bei einer Versionsmarke startet, scheitert heute. Dieser Schnitt entfernt den Schalter. Ein TestFlight-Lauf läuft danach immer gleich durch, von Hand oder per Versionsmarke, und in „Was testen“ steht kein Hinweis „KONTO-BAU“ mehr. Für dich ändert sich nichts, du musst nichts entscheiden. Für den Store-Bau in S5d ist das die Voraussetzung.

## Purpose

Seit S5b trägt die Quelle `LEAccountEnabled = true` und das Manifest mit den drei `ACCOUNT_TYPES`. Die CI-Mechanik aus #615 S4c-2a und #625 S2 (Eingabe `konto`, `env.ACCOUNT_BUILD`, Schritt „Set the account switch“ in beiden Jobs, Marke in „Was testen“, Archivprüfungen gegen `ACCOUNT_BUILD`) ist damit wirkungslos, und ein `v*`-Tag-Lauf (`ACCOUNT_BUILD=false`) scheitert an der Archivprüfung, weil die Quelle `true` trägt. Der Schnitt baut die Mechanik zurück, behält die Archivprüfungen aber als Wächter mit festem Sollwert: ein versehentlich abgeschalteter Quellwert fängt weiter vor dem Hochladen.

**Regeln vor Modell:** reine Liefer- und Dateiprüfung, die Zeile „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Setzt die PO-Entscheidung vom 2026-11-22 um (Schalter an der Quelle, Rückbau der CI-Mechanik als S5c); kein neues Verfahren, keine neue Abhängigkeit. Keine bestehende ADR fällt.

## Source

**Dateien (Liefer-/Skriptcode, 3):** `.github/workflows/testflight.yml`, `scripts/asc_what_to_test.py`, `scripts/asc_store_version.py` (nur Docstring).
**Dazu (zählen nicht zum Limit):** `scripts/test_asc_what_to_test.py`, `scripts/test_privacy_manifest.py`, `scripts/test_aps_environment.py`, `scripts/test_asc_store_version.py` (nur falls nötig), `docs/reference/testflight.md`, `CLAUDE.md`.
**Identifier:** Eingabe `konto`, `env.ACCOUNT_BUILD`, Schritt „Set the account switch“, `account_switch()` im Block `account-switch-check`, `mark_account_build`, `ACCOUNT_BUILD_MARK`, `is_account_build`, `build_lock` (Sperre „konto“).

**Gegen den Stand geprüft (2026-11-23):**

- `testflight.yml`: Eingabe `konto` Z. 21–24; Kopfkommentar Z. 34–35; `ACCOUNT_BUILD` Z. 38; Schritt „Set the account switch“ Z. 119–124 (`upload`) und Z. 456–461 (`upload-mac`), je mit `plutil -replace LEAccountEnabled` und `privacy_manifest.py apply`; `account_switch` mit `want="${ACCOUNT_BUILD:-false}"` Z. 233–244 und Z. 538–549; Manifestprüfung `--account "$ACCOUNT_BUILD"` Z. 268–274 und Z. 567–571. Kein anderer Workflow liest `konto` oder `ACCOUNT_BUILD`.
- `asc_what_to_test.py`: `main` Z. 153 hängt die Marke nur bei `ACCOUNT_BUILD=true` an; `asc_store_version.py` liest `ACCOUNT_BUILD_MARK` und `is_account_build` (`build_lock`, Sperre „konto“).
- Die Tests `test_asc_what_to_test.py` (`AccountBuildWorkflowTests`, `AccountBuildMarkTests`, `test_docs_name_account_build`), `test_privacy_manifest.py` (AC-9 bis AC-11 der Manifest-Spec) und `test_aps_environment.py` (`test_account_switch_blocks_untouched`, Hash `61a92665…`) halten den alten Stand fest und werden umgedreht.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `project.yml`, `LooseEnds/Info.plist`, `LooseEnds/PrivacyInfo.xcprivacy` (S5b) | quelle | tragen `LEAccountEnabled` Bool `true` und die drei Typen; unverändert |
| `scripts/privacy_manifest.py` (`check --account true|false`, `apply`) | skript | unverändert; `apply` hat keinen CI-Aufrufer mehr, bleibt als Werkzeug |
| `scripts/asc_store_version.py` | skript | liest `ACCOUNT_BUILD_MARK`/`is_account_build`, überspringt markierte Altbauten weiter |
| `.github/workflows/testflight.yml` | workflow | wird geändert |
| `scripts/test_aps_environment.py` | test | hält den Hash der Prüfblöcke; wird bewusst neu gesetzt |
| Downstream S5d | schnitt | ordnet den 1.0.2-Bau zu; der Bau muss ein Lauf nach S5c sein (unmarkiert) |

## Acceptance Criteria

Alle ACs sind Python-unittests unter `scripts/`; der Lauf `python3 -m unittest discover -s scripts -p 'test_*.py'` ist der Nachweis. Der Nachweis-TestFlight-Lauf nach dem Merge steht in der Definition of Done, nicht hier.

- **AC-1:** GIVEN `.github/workflows/testflight.yml` WHEN sie als Text und als YAML gelesen wird THEN enthält `on.workflow_dispatch.inputs` keine Eingabe `konto` (die Eingaben `what_to_test` und `cleanup_dry_run` bleiben), der Text enthält weder `ACCOUNT_BUILD` noch `inputs.konto`, das Wort „Konto-Bau“ steht nicht mehr im Kopfkommentar, und `on.push.tags` bleibt `['v*']`. Test: `scripts/test_asc_what_to_test.py` `AccountBuildWorkflowTests.test_workflow_has_no_konto_input` (ersetzt `test_workflow_has_konto_input_default_true`).
- **AC-2:** GIVEN die Jobs `upload` und `upload-mac` WHEN ihre Schritte gelesen werden THEN gibt es in keinem einen Schritt „Set the account switch“, und der Workflow-Text enthält weder `plutil -replace LEAccountEnabled` noch `privacy_manifest.py apply`; der Schritt „Set the APNs environment“ bleibt unbedingt und an seinem Platz. Test: `AccountBuildWorkflowTests.test_no_account_switch_step` (ersetzt `test_switch_step_is_conditional_and_between_generate_and_archive`) und `scripts/test_privacy_manifest.py` `WorkflowTests.test_apply_not_in_workflow` (ersetzt `test_apply_only_in_the_account_steps`).
- **AC-3:** GIVEN die zwei Ausschnitte zwischen `# account-switch-check:begin` und `# account-switch-check:end` WHEN sie in Bash gegen Beispiel-Plists laufen THEN endet `account_switch` mit 0 nur für `LEAccountEnabled` als Bool `true`, und mit Fehler für Bool `false`, für den String `YES`, für den String `true` und für einen fehlenden Schlüssel; der Ausschnitt liest keine Umgebungsvariable `ACCOUNT_BUILD` (der Test setzt sie zur Kontrolle auf `false` und `true` und erwartet dasselbe Ergebnis). Test: `AccountBuildWorkflowTests.test_switch_check_logic` (umgebaut, 5 Fälle × beide Ausschnitte × beide Umgebungswerte).
- **AC-4:** GIVEN die Archivprüfungen beider Jobs („Verify the archive is built against the iOS 27 SDK“, „Verify the macOS archive“) WHEN ihr Text gelesen wird THEN rufen beide `privacy_manifest.py check` fest mit `--account true` auf (kein `$ACCOUNT_BUILD`, kein `--account false`), setzen bei Fehler weiter `fail=1`, die iOS-Prüfung prüft weiter nur das App-Bundle (`$app_info`), die Mac-Prüfung weiter `"$APP/Contents/Resources/PrivacyInfo.xcprivacy"`, und beide rufen `account_switch` nach dem Ausschnitt auf. Test: `scripts/test_privacy_manifest.py` `WorkflowTests.test_archive_checks_call_check_with_account_true` (ersetzt `test_archive_checks_call_check_with_the_switch`) und `AccountBuildWorkflowTests.test_archive_checks_prove_switch_type_and_value`.
- **AC-5:** GIVEN `scripts/asc_what_to_test.py` WHEN `main` mit `ACCOUNT_BUILD=true` in der Umgebung und mit `ACCOUNT_BUILD` ungesetzt läuft THEN sendet es in beiden Fällen den Text unverändert (ohne `ACCOUNT_BUILD_MARK`) an jede Sprachfassung; das Längenlimit von 4000 Zeichen gilt ohne Markenzuschlag (3990 Zeichen mit `ACCOUNT_BUILD=true` gehen durch); `mark_account_build` und jeder Zugriff auf `ACCOUNT_BUILD` fehlen im Skript, `ACCOUNT_BUILD_MARK` und `is_account_build` bleiben, und `ACCOUNT_BUILD_MARK` steht genau einmal im Skript. Test: `AccountBuildMarkTests.test_mark_never_added` (ersetzt `test_mark_is_added_to_every_section`, `test_mark_not_added_when_off`, `test_mark_in_every_written_localization`), `test_no_length_surcharge` (ersetzt `test_mark_respects_length_limit`) und `test_mark_defined_once` (angepasst: Skript ohne `ACCOUNT_BUILD`-Lesen).
- **AC-6:** GIVEN `scripts/asc_store_version.py` WHEN die Zuordnung mit einem Bau läuft, dessen „Was testen“ `ACCOUNT_BUILD_MARK` trägt, THEN wird er weiter mit `bau IOS <n> übersprungen: konto` übersprungen, ebenso ein Bau mit unlesbaren oder leeren Texten (`texte nicht lesbar`), und ein unmarkierter Bau wird zugeordnet; der Docstring von `build_lock` sagt, dass die Sperre den alten markierten Bauten gilt (kein Hinweis mehr auf die Eingabe `konto`). Test: `scripts/test_asc_store_version.py` (bestehende Tests der Zuordnung, bleiben grün) und `scripts/test_asc_what_to_test.py` `AccountBuildMarkTests.test_store_lock_docstring_names_old_builds`.
- **AC-7:** GIVEN `scripts/test_aps_environment.py` WHEN `test_account_switch_blocks_untouched` (umbenannt `test_account_switch_blocks_pinned`) läuft THEN liegt der SHA-256 beider `account-switch-check`-Blöcke bewusst auf dem neuen Wert (beide Blöcke gleich, Bool-Prüfung mit festem `true`, kein `ACCOUNT_BUILD`), der alte Hash `61a92665763135516a59c8583f71c6577e93aa8d98e591e171af777a6d8427d9` kommt in der Datei nur noch als Kommentar „Stand vor #625 S5c“ vor und passt auf keinen der Blöcke, der Block enthält nicht `LEApsEnvironment`, und `plutil -replace LEAccountEnabled` kommt im Workflow nicht vor. Test: `test_aps_environment.py` `WorkflowTests.test_account_switch_blocks_pinned`.
- **AC-8:** GIVEN der Workflow-Text WHEN er auf Sonderwege für Tag-Läufe geprüft wird THEN gibt es keine Bedingung, die `github.ref`, `github.event_name` oder `startsWith(github.ref, 'refs/tags` zur Wahl des Kontoschalters oder der Archivprüfung benutzt (die Sollwerte sind für Hand- und Tag-Lauf dieselben), und die Prüfausschnitte und Aufrufe in beiden Jobs sind nicht von `if:` abhängig. Test: `AccountBuildWorkflowTests.test_tag_run_has_no_special_path`.
- **AC-9:** GIVEN `docs/reference/testflight.md` und `CLAUDE.md` WHEN sie gelesen werden THEN steht in `CLAUDE.md` im Abschnitt „Ship“ und in `docs/reference/testflight.md`: Der Konto-Schalter steht an der Quelle (#625 S5b), die Eingabe `konto` und die Marke im Lauf sind seit #625 S5c entfernt, Archivprüfungen halten Bool `true` und `--account true` fest, `asc_store_version.py` überspringt weiter alte Bauten mit der Marke; die Sätze „`konto` on“, „Run workflow → Haken „Konto-Bau““, „until it is removed in #625 S5c“ und „bis dahin gelten die Sätze zu `konto` unverändert“ kommen in keiner der beiden Dateien mehr vor, und die Sitzungsregel („manual runs keep the account group, `konto` on, …“) lautet „manual runs carry over the previous build's open test points“ ohne Kontobezug. Test: `AccountBuildMarkTests.test_docs_describe_removed_mechanism` (ersetzt `test_docs_name_account_build`; prüft zusätzlich, dass der Wortlaut der Marke in keiner der beiden Dateien steht).
- **AC-10:** GIVEN die Gesamt-Diffliste WHEN sie geprüft wird THEN enthält sie keine Swift-Datei, kein `project.yml`, keine `Info.plist`, keine `.entitlements` und kein `PrivacyInfo.xcprivacy`, und der Gesamtlauf `python3 -m unittest discover -s scripts -p 'test_*.py'` ist grün, einschließlich `test_info_plist_sync.py`, `test_entitlements_sync.py` und `test_app_store_datenschutzangaben.py`. Test: `scripts/test_asc_what_to_test.py` `AccountBuildWorkflowTests.test_source_files_unchanged_in_marker_set` (liest `project.yml`: `LEAccountEnabled` bleibt Bool `true`, Manifest-Quelle bleibt die drei Typen) und der Gesamtlauf.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `.github/workflows/testflight.yml` | MODIFY | Eingabe `konto`, `ACCOUNT_BUILD`, Kopfkommentar und beide Schritte „Set the account switch“ weg; `account_switch` fest Bool `true`; Manifestprüfung fest `--account true`; ca. −35/+6 |
| `scripts/asc_what_to_test.py` | MODIFY | `mark_account_build` und Lesen von `ACCOUNT_BUILD` weg, Docstring angepasst; ca. −10/+1 |
| `scripts/asc_store_version.py` | MODIFY | nur Docstring von `build_lock`; ca. +2/−2 |
| `scripts/test_asc_what_to_test.py` | MODIFY | Erwartungen umgedreht (siehe Testplan) |
| `scripts/test_privacy_manifest.py` | MODIFY | `apply` nicht im Workflow, Prüfung mit `--account true` |
| `scripts/test_aps_environment.py` | MODIFY | Hash der Prüfblöcke bewusst neu, kein `plutil -replace LEAccountEnabled` |
| `docs/reference/testflight.md` | MODIFY | Konto-Absatz (ca. Z. 356–375) auf den neuen Stand |
| `CLAUDE.md` | MODIFY | Ship-Absatz zu `konto` (Z. 295) und Sitzungsregel (Z. 357) |

`scripts/test_asc_store_version.py` bleibt inhaltlich unverändert (liest weiter `ACCOUNT_BUILD_MARK`) und läuft als Gegenprobe grün.

### Estimated Changes

- Files: 3 Liefer-/Skriptdateien (Limit 4 bis 5 eingehalten), dazu Tests und zwei Doku-Dateien, die nicht zum Limit zählen.
- LoC (Liefer-/Skriptcode): `testflight.yml` ca. −35/+6, `asc_what_to_test.py` ca. −10/+1, `asc_store_version.py` ca. +2/−2; zusammen weit unter ±250. Tests ca. 60 (zählen nicht), Doku ca. +10/−10.
- **App-Code (Swift):** keiner. Kein Pfad der Geräteliste berührt. Stufe 3 entfällt.
- **Berührte Berechtigungen und Schlüssel (explizit):** keine; kein neuer AppStorage-Schlüssel, kein CloudKit-Schema, keine Audio-Dateien, kein Eintrag in `project.yml` oder `Info.plist`.
- **Seiteneffekte (explizit):**
  1. Ein TestFlight-Lauf hat die Eingabe `konto` nicht mehr; ein Aufruf mit `-f konto=…` wird von GitHub abgewiesen. Kein anderer Workflow und kein Skript ruft ihn so auf (geprüft).
  2. Ein `v*`-Tag-Lauf läuft durch dieselben Prüfungen wie ein Handlauf.
  3. Neue TestFlight-Bauten tragen keine Marke mehr; alte Bauten mit Marke bleiben markiert, `asc_store_version.py` überspringt sie weiter. Der 1.0.2-Bau für S5d muss deshalb ein Lauf nach S5c sein.
- **Parallele Arbeit:** Hotspots `CLAUDE.md` und `.github/workflows/`; vor dem PR `origin/main` und offene PRs prüfen.

## Implementation Details

Reihenfolge (TDD): zuerst die Tests umdrehen und rot belegen, dann `testflight.yml`, die Skripte und die Doku ändern, dann grün.

1. `testflight.yml`: Eingabe `konto`, Kopfkommentar zum Konto-Bau, `env.ACCOUNT_BUILD` und beide Schritte „Set the account switch“ entfernen. `account_switch` in beiden Blöcken vergleicht mit festem `true`, die Fehlermeldung nennt „expected bool true (#625)“, die Blöcke bleiben byte-gleich zueinander. Manifestprüfung beider Jobs: `check … --account true`, Zeile und Fehlermeldung ohne Variable.
2. `asc_what_to_test.py`: `mark_account_build` und den Zweig in `main` entfernen, Docstring (Z. 9) und Kommentar an `ACCOUNT_BUILD_MARK` anpassen („Marke alter Konto-Bauten, #615 S4c-2a; wird nicht mehr gesetzt“); `ACCOUNT_BUILD_MARK` und `is_account_build` bleiben.
3. `asc_store_version.py`: Docstring von `build_lock`: Sperre gilt den alten markierten Bauten und unlesbaren Texten.
4. Hash in `test_aps_environment.py`: aus dem neuen Block mit `hashlib.sha256` berechnet und als Konstante eingetragen, der alte Wert als Kommentar; das ist eine bewusste Änderung dieses Schnitts, kein Nebeneffekt.
5. Doku auf den neuen Stand (AC-9).

Keine Änderung an der Gate-Konfiguration (`openspec.yaml`) und an keiner Hook-Datei. Der PR geht mit `Refs #625`, die CI muss grün sein, danach Merge.

## Test Plan

### Automated Tests (TDD RED)

RED zuerst: Diese bestehenden Tests werden vor der Änderung umgedreht und müssen gegen den alten Workflow und die alten Skripte rot sein.

- [ ] Test 1 (AC-1): GIVEN der Workflow WHEN `test_workflow_has_no_konto_input` läuft THEN fehlt die Eingabe `konto` und `ACCOUNT_BUILD`; rot gegen den alten Stand (ersetzt `test_workflow_has_konto_input_default_true`).
- [ ] Test 2 (AC-2): GIVEN beide Jobs WHEN `test_no_account_switch_step` und `test_apply_not_in_workflow` laufen THEN gibt es weder Schritt, noch `plutil -replace LEAccountEnabled`, noch `privacy_manifest.py apply`; rot (ersetzen `test_switch_step_is_conditional_and_between_generate_and_archive` und `test_apply_only_in_the_account_steps`).
- [ ] Test 3 (AC-3): GIVEN der Prüfausschnitt WHEN `test_switch_check_logic` mit fünf Beispiel-Plists und beiden Umgebungswerten läuft THEN besteht nur Bool `true`; rot (umgedreht: Bool `false` und `ACCOUNT_BUILD=false` bestanden bisher).
- [ ] Test 4 (AC-4): GIVEN beide Archivprüfungen WHEN `test_archive_checks_call_check_with_account_true` und `test_archive_checks_prove_switch_type_and_value` laufen THEN steht `--account true` fest da; rot.
- [ ] Test 5 (AC-5): GIVEN `ACCOUNT_BUILD=true` WHEN `test_mark_never_added` und `test_no_length_surcharge` laufen THEN erscheint keine Marke und 3990 Zeichen gehen durch; rot (umgedreht aus `test_mark_is_added_to_every_section`, `test_mark_in_every_written_localization`, `test_mark_respects_length_limit`; `test_mark_not_added_when_off` geht darin auf).
- [ ] Test 6 (AC-6): GIVEN markierte und unmarkierte Bauten WHEN die Zuordnungstests in `test_asc_store_version.py` laufen THEN wird der markierte weiter übersprungen; grün vorher und nachher (Gegenprobe, nicht RED).
- [ ] Test 7 (AC-7): GIVEN die Prüfblöcke WHEN `test_account_switch_blocks_pinned` läuft THEN passt nur der neue Hash; rot gegen den alten Block.
- [ ] Test 8 (AC-8): GIVEN der Workflow WHEN `test_tag_run_has_no_special_path` läuft THEN gibt es keine Tag- oder Ereignisbedingung am Kontoschalter; grün bei der gewollten Form, rot gegen den alten Stand durch Test 1 bis 4 mit abgedeckt.
- [ ] Test 9 (AC-9): GIVEN die Doku WHEN `test_docs_describe_removed_mechanism` läuft THEN stehen die alten Sätze nicht mehr darin; rot gegen den alten Stand (ersetzt `test_docs_name_account_build`).
- [ ] Test 10 (AC-10): GIVEN der Gesamtlauf WHEN `unittest discover -s scripts -p 'test_*.py'` läuft THEN grün.

Keine neuen UI-Tests und keine Unit-Tests der App: der Schnitt berührt keinen Swift-Code. Benannte Lücke: Ob der echte Lauf in GitHub beide Archivprüfungen besteht und „Was testen“ ohne Marke schreibt, belegt erst der Nachweis-Lauf nach dem Merge (Definition of Done).

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **Gewählt: Mechanik raus, Wächter fest auf `true`, Store-Sperre für Altbauten bleibt** | Eingabe, Variable, Schalter-Schritte und Marke entfallen | ein Lauf für alle; Quellwert bleibt vor dem Upload geprüft; alte Beschriftung „nie für den App Store“ bleibt wahr | Skript trägt noch eine Marken-Konstante und `is_account_build` | — |
| **Sperre `konto` ebenfalls entfernen** | alte Konto-Bauten wären zuordenbar | inhaltlich gleich dem Store-Bau | ihr „Was testen“ sagt „nie für den App Store“; dem Prüfer läge ein so beschrifteter Bau vor | verworfen; keine ADR |
| **Archivprüfung des Schalters ganz streichen** | weniger Code | einfacher | kein Wächter mehr gegen einen abgeschalteten Quellwert im Store-Bau (die #625-DoD verlangt die Gruppe im Store); der Wächter kostet nichts | verworfen; keine ADR |
| **`privacy_manifest.py apply` mitentfernen** | kein toter Pfad | sauberer | `apply` ist das Werkzeug, mit dem die Quelle erzeugt wurde (S5b) und das ein Zurückdrehen erlaubt; der Schnitt bleibt klein | verworfen; keine ADR |

Keine ADR fällt bei keiner Variante.

## Risiken

- **Ein TestFlight- oder Tag-Lauf zwischen S5b-Merge und S5c-Merge scheitert** (Quelle an, Erwartung aus). Gegenmittel: S5c folgt unmittelbar, Läufe startet nur die Epic-Sitzung; der Fehler ist laut.
- **Der Hash in `test_aps_environment.py` wird nur mitgezogen, ohne den Block zu prüfen.** Gegenmittel: AC-7 prüft den Blockinhalt (festes `true`, kein `ACCOUNT_BUILD`) zusätzlich zum Hash; der neue Wert wird aus dem geänderten Block berechnet, nicht kopiert.
- **Alte markierte Bauten verdecken die Zuordnung.** Gegenmittel: Der 1.0.2-Bau für S5d ist ein Lauf nach S5c; `asc_store_version.py aktion=lesen` zeigt vor der Zuordnung, welcher Bau übersprungen wird.
- **Ein vergessener Aufrufer von `-f konto=…`.** Gegenmittel: Suche im Repo (Workflows, Skripte, Doku) in AC-1 und AC-9 abgedeckt.

## Out of Scope / Folgeschnitte

- S5d (Store, Betriebs-Tür).
- Entfernen von `privacy_manifest.py apply` oder `--account false`.
- Änderung an `asc_store_version.py` über den Docstring hinaus.

## Definition of Done

- [ ] AC-1 bis AC-10 erfüllt; Python-Tests grün (RED-Lauf und GREEN-Lauf belegt), CI grün
- [ ] PR mit `Refs #625` (nie `Closes`), gemergt
- [ ] Nachweis nach dem Merge (kein AC, weil erst dann prüfbar): ein TestFlight-Lauf von Hand ohne die Eingabe `konto` läuft durch beide Archivprüfungen (iOS und Mac), „Was testen“ des neuen Baus trägt keine Marke; der Bau ist zugleich der Kandidat für S5d. Der Lauf kommt von der Epic-Sitzung (#612/#625), Henning bekommt keinen Auftrag
- [ ] Abschlussbericht mit dem Satz: „Kein Pfad der Geräteliste berührt.“ (Stufe 3 entfällt, Abnahme endet nach Stufe 2; Stufe 1 sind die Tests, Stufe 2 ist der Nachweis-Lauf der CI, kein App-Code geändert)
- [ ] #625 kommentiert (Stand Schnitt 5c, Folge S5d), Board-Karte aktuell, Memory geschrieben

## Changelog

- 2026-11-23: Initial spec created (Schnitt 5c von #625, Konto-Mechanik im TestFlight-Lauf zurückbauen)
