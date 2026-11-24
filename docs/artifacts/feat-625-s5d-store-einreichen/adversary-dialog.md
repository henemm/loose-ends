# Adversary Dialog — feat-625-s5d-store-einreichen
Spec: docs/specs/feat-625-schnitt-5d-1-store-werkzeug.md
Datum: 2026-11-24 08:43

## Checkliste
- [x] **AC-1:** GIVEN `project.yml` mit `MARKETING_VERSION: "1.0.2"` und bei Apple iOS 1.0 und 1.0.1 (beide `READY_FOR_SALE`), keine bearbeitbare iOS-Version, keine Mac-Version 1.0.2 WHEN `anlegen` läuft THEN wird zuerst die iOS-Version 1.0.2 per `POST /v1/appStoreVersions` angelegt (Plattform `IOS`, `versionString` 1.0.2), danach die Mac-Version mit derselben Nummer, danach je Plattform die Bau-Zuordnung wie bisher; es gibt genau zwei POST und höchstens zwei PATCH. Test: `test_anlegen_creates_ios_then_mac_version_from_project_yml`.
- [x] **AC-2:** GIVEN die Zielnummer ist nicht größer als irgendeine vorhandene Version der Plattform, die angelegt würde (zum Beispiel `MARKETING_VERSION: "1.0.1"` oder `"1.0"` bei vorhandenem iOS 1.0.1; der Vergleich ist numerisch je Teil, 1.0.10 ist größer als 1.0.2), oder `MARKETING_VERSION` fehlt, ist leer oder keine Nummer der Form `\d+(\.\d+)*` WHEN `anlegen` läuft THEN endet der Lauf mit Fatal und Grund, bevor der erste Schreibaufruf (POST oder PATCH) abgesetzt wird. Test: `test_anlegen_aborts_before_writing_when_target_not_greater`, `test_anlegen_aborts_on_unreadable_marketing_version`.
- [x] **AC-3:** GIVEN schon eine bearbeitbare (`PREPARE_FOR_SUBMISSION`) iOS- oder Mac-Version mit einer anderen Nummer als die Zielnummer WHEN `anlegen` läuft THEN Fatal mit Plattform und beiden Nummern, vor dem ersten Schreibaufruf; GIVEN die bearbeitbare Version hat die Zielnummer THEN wird sie nicht noch einmal angelegt („schon vorhanden, übersprungen“), und nur fehlende Teile (zum Beispiel die Mac-Version) werden geschrieben; mehr als eine bearbeitbare Version einer Plattform bleibt Fatal wie bisher. Test: `test_anlegen_aborts_on_editable_version_with_other_number`, `test_anlegen_skips_existing_editable_ios_version`, `test_anlegen_does_not_create_second_mac_version` (bestehend, bleibt grün).
- [x] **AC-4:** GIVEN der Plan WHEN er gebildet wird THEN benutzt er ausschließlich GET-Aufrufe (Versionen, vorhandene Bau-Zuordnung, Bauwahl samt `build_lock`); die Wahl der Bauten beider Plattformen für die Zielnummer (`pick_build`: gültig, nicht abgelaufen, höchste Buildnummer, nie umgehängt, nie ein Bau mit der Konto-Marke oder mit unlesbaren oder leeren Texten) geschieht vor dem ersten Schreibaufruf, soweit sie ohne die neue Version möglich ist; fehlt für eine Plattform jeder passende Bau, endet der Lauf mit Fatal „kein gültiger Bau … nichts geschrieben“, bevor irgendeine Version angelegt wird. Test: `test_anlegen_plan_uses_only_get`, `test_anlegen_without_matching_build_writes_nothing`, `AccountBuildLockTests` (bestehend, bleiben grün: `test_pick_build_skips_account_builds`, `test_pick_build_fail_closed_on_unreadable`, `test_pick_build_fail_closed_on_empty`, `test_anlegen_never_assigns_account_build`).
- [x] **AC-5:** GIVEN ein POST oder PATCH scheitert (HTTP 403, 409 oder anderer Fehler) WHEN `anlegen` läuft THEN wird der Schreibaufruf nie wiederholt (jede Anfrage-Nummer genau einmal im Aufrufprotokoll), die Meldung nennt den Grund ohne Apples Rohantwort, und ein bereits angelegter Teil bleibt stehen (keine Löschanfrage). Test: `test_write_errors_are_clear_without_raw_answer` (bestehend, erweitert um den iOS-POST) und `test_post_is_never_repeated`.
- [x] **AC-6:** GIVEN `anlegen` hat geschrieben WHEN der Lauf endet THEN liest er im selben Lauf gegen: genau eine bearbeitbare Version je Plattform mit der Zielnummer und je Plattform ein Bau, dessen Vorabversion die Zielnummer trägt; bei Abweichung Fatal „Gegenprobe: …“, bei Gleichheit die Zeile `gegenprobe gleich=ja` und danach die Ausgabe wie `lesen`. Test: `test_verification_fails_on_deviation` (bestehend, auf beide Plattformen erweitert) und `test_anlegen_prints_gegenprobe_and_state`.
- [x] **AC-7:** GIVEN beliebige Eingaben WHEN `asc_store_version.py` läuft THEN gibt es nie `DELETE` und nie einen Schreibaufruf an Einreichung, Review-Submission, Texte, Bilder oder Review-Detail (erlaubt sind nur `POST /v1/appStoreVersions` und `PATCH …/relationships/build`); `lesen` setzt keinen Schreibaufruf ab. Test: `test_never_deletes_submits_or_writes_texts` und `test_lesen_reports_state_and_never_writes` (bestehend, bleiben grün; ersterer prüft zusätzlich beide POST-Plattformen).
- [x] **AC-8:** GIVEN ein Abschnitt in `app-store-texte.md` mit der Zeile `Marketing-URL: https://…` WHEN die Datei gelesen wird THEN steht der Wert als `marketingUrl` im Wunschtext der Locale und wird von `write_locale` bei Abweichung geschrieben und von `verify` gegengeprüft; ohne die Zeile ist das Feld nicht im Wunschtext und wird nicht angefasst (optional). Test: `test_marketing_url_line_is_parsed_and_written`, `test_marketing_url_is_optional`.
- [x] **AC-9:** GIVEN eine `Marketing-URL:`-Zeile ohne `https://` am Anfang oder ohne Host (zum Beispiel `https://` allein, `http://…`) WHEN `wanted_texts` läuft THEN Fatal mit Locale und „Marketing-URL muss mit https:// beginnen“ beziehungsweise „Host“, vor jeder Anfrage; die Prüfung gilt genauso für `Support-URL` ohne Host. Test: `test_marketing_url_must_be_https_with_host`.
- [x] **AC-10:** GIVEN `docs/reference/app-store-texte.md` WHEN sie gelesen wird THEN steht in den Abschnitten `en-US` und `de-DE` je genau eine Zeile `Marketing-URL: https://www.henemm.com/loose-ends/`, und `wanted_texts` auf die echte Datei gibt für beide Locales `marketingUrl` zurück. Test: `test_real_file_has_marketing_url_in_both_locales`.
- [x] **AC-11:** GIVEN je eine bearbeitbare Version iOS und Mac WHEN `asc_review_notes.py notizen` läuft THEN werden die Notizen je Plattform in das Review-Detail genau dieser einen bearbeitbaren Version geschrieben (nur bei Abweichung, je ein PATCH, nie wiederholt) und je Plattform gegengeprüft (`gegenprobe gleich=ja`); die Konstante `VERSION_STRING = "1.0"` und der feste Versionsfilter entfallen, und `lesen` schreibt nichts. Test: `test_notizen_writes_to_editable_version_of_each_platform`, `test_notizen_unchanged_when_equal`, `test_lesen_never_writes`.
- [x] **AC-12:** GIVEN keine bearbeitbare Version einer Plattform, mehr als eine, oder eine bearbeitbare Version ohne Review-Detail (404 oder `data: null`) WHEN `notizen` läuft THEN Fatal mit Plattform und Grund, und es wird nichts angelegt (kein POST auf `appStoreReviewDetails`); eine Plattform ohne bearbeitbare Version bricht vor dem ersten Schreibaufruf ab, auch wenn die andere Plattform in Ordnung wäre. Test: `test_notizen_aborts_without_editable_version`, `test_notizen_aborts_without_review_detail_and_creates_nothing`, `test_notizen_aborts_before_writing_when_one_platform_fails`.
- [x] **AC-13:** GIVEN `docs/reference/app-review-notizen.md` WHEN der erste Codeblock gelesen wird THEN ist er höchstens 4000 Byte lang (die Grenze, die `MAX_BYTES` in `wanted_notes` hält; Apples Feld erlaubt 4000 Zeichen, die Byte-Grenze ist strenger und bleibt), trägt keinen Platzhalter `<HIER_`, und `wanted_notes()` auf die echte Datei läuft ohne Fehler. Test: `test_real_notes_fit_the_limit`.
- [x] **AC-14:** GIVEN derselbe Notiztext WHEN er als Text geprüft wird THEN enthält er (Groß-/Kleinschreibung ignoriert) weder „no account registration“, „login or account deletion“, „No login“ noch „no server of our own“ und sagt in englischer Sprache: Anmeldung nur über „Sign in with Apple“ mit der eigenen Apple-ID des Prüfers, keine Demo-Zugangsdaten nötig; Konto löschen in der App (mit Verweis auf Guideline 5.1.1(v)); der eigene Dienst läuft auf einem Server in Deutschland; die Verbindung zu Claude als Connector in claude.ai (braucht ein Claude-Konto, die Bildschirmaufnahme zeigt den Ablauf); die App ist ohne Konto voll nutzbar. Geprüft wird je Aussage ein Schlüsselbegriff (`Sign in with Apple`, `5.1.1(v)`, `Germany`, `claude.ai`, `Claude account`, `without an account`, `no demo credentials`). Test: `test_notes_have_no_false_statements`, `test_notes_state_account_facts`.
- [x] **AC-15:** GIVEN die Gesamt-Diffliste WHEN sie geprüft wird THEN enthält sie keine Swift-Datei, kein `project.yml`, keine `Info.plist`, keine `.entitlements` und kein `PrivacyInfo.xcprivacy`, und der Gesamtlauf `python3 -m unittest discover -s scripts -p 'test_*.py'` ist grün; die Workflows `asc-store-version.yml`, `asc-version-texts.yml` und `asc-review-notes.yml` bleiben unverändert und bieten weiter nur die Aktionen `lesen`/`anlegen`, `lesen`/`texte` und `lesen`/`notizen` (Bestandstests `WorkflowTests` grün). Test: `scripts/test_asc_store_version.py` `WorkflowTests.test_workflow_offers_both_actions_and_hides_the_key` (bestehend) und der Gesamtlauf.

## Dialog

### Runde 1
**Adversary:** Lauf der drei Testdateien (84 Tests, OK, Ausgabe in `adversary-test-output.txt`); Gesamtlauf 824 Tests OK, 1 übersprungen (`test-green-output.txt`). Ad-hoc-Proben gegen `target_version`, `plan_versions`, `check_url`.

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_store_version.py:260
  Evidence: `create_versions` läuft über PLATFORMS (IOS, MAC_OS), je ein POST; `plan_versions` liefert bei iOS 1.0/1.0.1 und Ziel 1.0.2 beide None. Test `test_anlegen_creates_ios_then_mac_version_from_project_yml` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_store_version.py:131
  Evidence: Probe: Ziel 1.0.2 gegen vorhandenes 1.0.10 -> Fatal (numerisch), Ziel 1.0 gegen 1.0.0 -> Fatal, unlesbare Nummer "abc" -> Fatal (fail-closed); `target_version` (Zeile 114) lehnt "", "1.0.", fehlende Zeile ab. Alles vor dem ersten Schreibaufruf, da `anlegen` (Zeile 276) erst nach Plan schreibt.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_store_version.py:131
  Evidence: Probe: bearbeitbares iOS 1.0.2 + Mac None -> nur Mac fehlt; zwei bearbeitbare -> Fatal mehrdeutig; bearbeitbar 1.0.3 bei Ziel 1.0.2 -> Fatal mit beiden Nummern.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_store_version.py:247
  Evidence: `anlegen` ruft `plan_builds` (nur GET, `pick_build` je Plattform) vor `create_versions`; Tests `test_anlegen_without_matching_build_writes_nothing` und `AccountBuildLockTests` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_store_version.py:189
  Evidence: `send_once` hat ein einzelnes `urlopen`, keine Schleife, Fehlertext nur Status und Codes, nie Rohantwort; Netzfehler ebenfalls einmal. `test_post_is_never_repeated` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/asc_store_version.py:233
  Evidence: `verify` prüft je Plattform `the_version` und Vorabversion des Baus; Abweichung -> Fatal "Gegenprobe". Tests `test_verification_covers_both_new_versions`, `test_anlegen_prints_gegenprobe_and_state` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/asc_store_version.py:189
  Evidence: einzige Schreibstellen sind `send` -> `send_once` mit POST /v1/appStoreVersions und PATCH …/relationships/build; kein DELETE im Code; `test_never_deletes_submits_or_writes_texts` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/asc_version_texts.py:26
  Evidence: `LINE_FIELDS`/`LABELS` kennen `marketingUrl`; nicht in REQUIRED, also optional. Tests `test_marketing_url_line_is_parsed_and_written`, `test_marketing_url_is_optional` grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/asc_version_texts.py:104
  Evidence: Probe: `https://`, `https://user@/`, `https:///x`, `https://:80/` -> Fatal "braucht einen Host"; gilt für Support-URL und Marketing-URL (URL_FIELDS).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/test_asc_version_texts.py:601
  Evidence: Diff zeigt je eine Zeile `Marketing-URL: https://www.henemm.com/loose-ends/` in en-US und de-DE; Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: scripts/asc_review_notes.py:139
  Evidence: `main` wählt je Plattform die eine bearbeitbare Version (`editable_versions`, Zeile 59), liest alle Review-Details zuerst, schreibt je Plattform nur bei Abweichung ein PATCH über `send_once`, Gegenprobe `gegenprobe gleich=ja`; `VERSION_STRING` entfernt.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: scripts/asc_review_notes.py:73
  Evidence: `get_detail` wirft Fatal bei 404/null ohne Anlegen; alle Details werden vor der Schreibschleife geholt, `required=True` bei `notizen`; Test `test_notizen_aborts_before_writing_when_one_platform_fails` (scripts/test_asc_review_notes.py:300) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: scripts/asc_review_notes.py:52
  Evidence: `wanted_notes()` auf die echte Datei: 3515 Byte, kein Platzhalter, kein Fehler. Test `test_real_notes_fit_the_limit` (scripts/test_asc_review_notes.py:342) grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: scripts/test_asc_review_notes.py:352
  Evidence: Textprobe: keine der vier verbotenen Phrasen enthalten; Schlüsselbegriffe vorhanden; "Germany" gedeckt durch Datenschutztext Zeile 130 (Hetzner in Deutschland); Menütexte stimmen mit LooseEnds/Views/AccountSection.swift überein.
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: scripts/asc_store_version.py:1
  Evidence: Diff umfasst nur drei Skripte und zwei Markdown-Dateien, keine Swift-/plist-/yml-Änderung, Workflows unverändert; Gesamtlauf grün (test-green-output.txt).
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_version_texts.py:104
  Description: `check_url` ruft `urlparse(value).hostname` ohne ValueError abzufangen. Reproduktion: `Marketing-URL: https://[::1` wirft ValueError statt Fatal; `https://a b/` wird akzeptiert.
  Spec requirement: AC-9 — Fatal mit Locale und Grund vor jeder Anfrage
  Conflict: Traceback statt Meldung; der Lauf bricht trotzdem vor jeder Anfrage ab. Nur Repo-Datei.
  Remediation: ValueError zu Fatal, Leerzeichen verbieten.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_version.py:114
  Description: Der Regex nimmt die erste MARKETING_VERSION-Zeile und akzeptiert ein einzelnes öffnendes Anführungszeichen (`"1.0.2`) sowie führende Nullen (`01.0`).
  Spec requirement: AC-2 — keine Nummer der Form \d+(\.\d+)* -> Fatal
  Conflict: Wert 1.0.2 ist korrekt; nur unsaubere Quelle wird toleriert. project.yml:24 steht heute richtig.
  Remediation: Anführungszeichen paarweise prüfen; optional.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: docs/reference/app-review-notizen.md:35
  Description: Der Text sagt, der Prüfer nehme seine eigene Apple-ID. Die App zeigt für nicht freigegebene Konten "This Apple account is not yet cleared for Claude." (LooseEnds/Views/AccountSection.swift:59); die Tür ist derzeit zu.
  Spec requirement: AC-14 — Aussage "eigene Apple-ID des Prüfers" wahr
  Conflict: Wahr erst nach Öffnen der Tür in S5d-2; dieser Schnitt schreibt nichts bei Apple. Kein Defekt hier, aber Reihenfolge in S5d-2 zwingend.
  Remediation: In S5d-2 vor `notizen` die Tür öffnen.

### Runde 2
**Adversary:** Wiederholung und Schreibreihenfolge geprüft. `send_once` (scripts/asc_store_version.py:189) hat keine Schleife; ein Timeout nach serverseitigem Anlegen führt beim nächsten Lauf zu "schon vorhanden, übersprungen". `anlegen` schreibt erst nach `plan_versions` und `plan_builds`; abweichende bearbeitbare Nummer, Ziel nicht größer, kaputtes project.yml: alle Fatal ohne Schreibaufruf. 1.0.10 gegen 1.0.2 numerisch korrekt. Notizen: Details beider Plattformen vor dem ersten PATCH gelesen (scripts/asc_review_notes.py:139); `lesen` ohne bearbeitbare Version meldet Summary 0, schreibt nichts (spec-konform). Kein DELETE im Code. Nichts oberhalb LOW.
**Implementierer:** keine Antwort nötig.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 84 gezielt bestanden, Gesamtlauf 824 bestanden, 0 fehlgeschlagen, 1 übersprungen
Edge cases: geprüft, nur drei LOW (F001-F003), keine blockierend
Regressions: keine gefunden
Checklist: 15/15 points proven

## Geprüfte Dateien

- sha256:40354a54f2f3d25c6c5719aa27d34af4ecc846fab2dc0172faacf702d52c72ce  docs/reference/app-review-notizen.md
- sha256:d8ecf165c9940e9424588e08248a479ca3bb19dcf34843e6a2f5b52e18bfe82b  scripts/asc_review_notes.py
- sha256:d42a03469be329a2b2d17e6ab2e655cdce5f16f33c60d6375e59510b3ff575dd  scripts/asc_store_version.py
- sha256:c8efbc0c1aed003118a9777083b9426e27f8692ac113a4c6375b1daaf3fffd76  scripts/asc_version_texts.py
- sha256:b0b9cc3d0bab337a9eae3f55864cdb9259f5ec5745e9ed0f32d34d2933d33542  scripts/test_asc_review_notes.py
- sha256:44bb28d804629ad2e0e652525822b1a3f7dcb06f9dfd279d6713935918a01083  scripts/test_asc_version_texts.py

## Prüfbasis

- base: ee54eccaa9accd02e80e98a3b6bbdb35e183d38b
- blob:de6b4ce621935968d5bd17ebca8876488e039693  docs/reference/app-review-notizen.md
- blob:465f4ef6348a177eadf1a4b55943a2b107e13235  scripts/asc_review_notes.py
- blob:bc48faf23ce24393ca2008cb0d41278ac51dfb72  scripts/asc_store_version.py
- blob:286b14387a879240352f8c6f58457e880154ad6f  scripts/asc_version_texts.py
- blob:2e32bbd55634b36a49f36c2203619eb9699db295  scripts/test_asc_review_notes.py
- blob:60c8ba1c628793fb5a30cdb591ca434b1b5c1400  scripts/test_asc_version_texts.py
