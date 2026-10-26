# Adversary Dialog — feat-705-apple-seite-einladung
Spec: docs/specs/feat-705-schnitt-1-sondieren.md
Datum: 2026-10-26

## Checkliste
- [x] **AC-1:** nur GET — `Request` ohne Methode/Daten, kein `send_json`; `test_only_get_requests`.
- [x] **AC-2:** `zugriff … http=<Status>`, 403/404 als `befund=` auf derselben Zeile, Exit 0; `test_everything_present`, `test_forbidden_on_groups_is_a_finding`, `test_all_404_is_findings_exit_0`.
- [x] **AC-3:** Gruppen mit Name, intern, Link, Adresse, Feedback; `gruppe keine`; `test_everything_present`, `test_no_group`.
- [x] **AC-4:** nur gesetzt/leer (Booleans an/aus), Attributnamen; `test_everything_present`, `test_empty_description_is_reported_as_empty`, `test_output_has_no_contact_values_and_no_key`.
- [x] **AC-5:** Builds je Plattform mit processingState, Prüfstatus, Einreichungen; `test_both_platforms`, `test_everything_present`.
- [x] **AC-6:** nichts Persönliches, kein Schlüssel/Token in der Ausgabe; `test_output_has_no_contact_values_and_no_key`.
- [x] **AC-7:** Exit 0 bei Befunden, Exit 1 nur bei Konfigurationsfehler/keiner Antwort; fünf Tests plus `test_broken_answer_on_groups_is_a_finding`.
- [x] **AC-8:** Workflow nur `workflow_dispatch`, Secrets, Matrix, ubuntu-latest, Schlüsseldatei entfernt; `testflight.yml` unverändert; `test_workflow_file`.
- [x] **AC-10:** Abschnitt „Einladung: Apple-Seite (#705)“ in `docs/reference/testflight.md` mit zehn Teilen, leerer Beleg-Spalte, Schnitt-2-Hinweis.
- [x] **AC-11:** Dateien stimmen; Umfang über der Spec-Schätzung (Produktion ca. 251 Zeilen, Tests 279), Abweichung wird im Abschlussbericht und PR offen genannt.
- [x] **AC-12:** kein Schreibpfad im Code, nichts auf Geräten, kein TestFlight-Lauf, kein ASC-Zugriff während der Umsetzung.

## Dialog

### Runde 1
**Adversary:** F001 (MEDIUM): `probe()` fängt `http.client.HTTPException` nicht, abgeschnittene Antwort führt zu Traceback statt Befund. Code reference: scripts/asc_beta_probe.py:28. F002 (LOW): `filled()` meldet Booleans als „gesetzt“. F003 (LOW): bei ASC_POLL_SECONDS 30 reißt der Job-Timeout. Code reference: .github/workflows/asc-beta.yml:28. F004 (LOW): Apple-Strings ungefiltert ausgegeben. F005: fremde Änderung im Arbeitsbaum. F006 (MEDIUM): Umfang über ±250 LoC. Code reference: scripts/test_asc_beta_probe.py:1. Code reference: docs/reference/testflight.md:156. Vorläufiges Verdict: BROKEN.
**Implementierer:** F001, F002, F003 behoben; der F001-Test war vor dem Fix rot (IncompleteRead), danach 13 Tests grün. F004 als bekannte Grenze akzeptiert, F005 kommt nicht in den Commit, F006 wird offen genannt.

### Runde 2
**Adversary:** F001–F003 AKZEPTIERT, Retry begrenzt (ATTEMPTS=5), `filled()` typsicher, keine neuen Schwachstellen. F006 vertretbar bei offener Nennung. Code reference: scripts/asc_beta_probe.py:39. Code reference: scripts/test_asc_beta_probe.py:180. Code reference: .github/workflows/asc-beta.yml:24. N-1 und N-2 (vormals AC-9, AC-13) erst nach Merge bzw. PR belegbar und aus der AC-Liste genommen.
**Implementierer:** bestätigt; N-1 (Handlauf) und N-2 (PR-Text) werden nach dem Merge bzw. am PR nachgewiesen.

### Bestätigungen (Runde 2)
Code reference: scripts/asc_beta_probe.py:39
Code reference: scripts/test_asc_beta_probe.py:180
Code reference: .github/workflows/asc-beta.yml:24
Code reference: docs/reference/testflight.md:156

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

## Geprüfte Dateien

- sha256:79aba43cb592122af903e37d8752e7612b79adec97d632498c0a85ee6b80b24f  .github/workflows/asc-beta.yml
- sha256:90f1633967da51ce703e072211f69494d085a8469893ba71184861daba860360  docs/reference/testflight.md
- sha256:a982cbe7bc5eff64c891ececf9b994f304590f5133a1f8cab664b8162cf77b52  scripts/asc_beta_probe.py
- sha256:aadcde528db9272c661e533e732fbf84c4e68da7b1676dc13548802bee7ca60b  scripts/test_asc_beta_probe.py

## Prüfbasis

- base: aac10f217041f16739833370855905313f521bc4
- blob:bc1ce9bdd7a3ca91bb6861b055af3d505afbe1fd  .github/workflows/asc-beta.yml
- blob:3e136e9f74f0c98e2139461425e907224e6c5222  docs/reference/testflight.md
- blob:fd2a8a6e0a96da7e91e6f868bc5e2ce39c09fc53  scripts/asc_beta_probe.py
- blob:4a9e11ee1545de3eed58e901320e897ba24ace59  scripts/test_asc_beta_probe.py
