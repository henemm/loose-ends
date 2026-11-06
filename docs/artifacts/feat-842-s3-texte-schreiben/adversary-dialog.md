# Adversary Dialog — feat-842-s3-texte-schreiben
Spec: docs/specs/feat-842-schnitt-3-texte-schreiben.md
Datum: 2026-11-06 19:48

## Checkliste
- [x] **AC-1:** Given eine Textdatei mit fehlendem Pflichtfeld (Beschreibung, Schlüsselwörter, Support-URL), Beschreibung über 4000 Zeichen, Werbetext über 170 Zeichen, Schlüsselwörtern über 100 Bytes oder mit Leerzeichen nach Kommas, Support-URL ohne `https://` oder ungültigem Beschreibungsblock, When `texte` läuft, Then bricht der Lauf mit klarer Meldung (Locale, Feld, Zahl) ab, bevor die erste Anfrage hinausgeht. Belegt durch `test_invalid_text_file_aborts_before_any_request`.
- [x] **AC-2:** Given eine gültige Textdatei mit mehrzeiliger Beschreibung, When sie gelesen wird, Then entspricht die Beschreibung exakt dem Markerblock und die Einzelfelder stimmen; die im Repo liegende Datei ist gültig, hält alle Grenzen ein und enthält keinen deutschen Abschnitt. Belegt durch `test_text_file_parses_description_block_and_fields`, `test_repo_text_file_parses_and_fits_limits`.
- [x] **AC-3:** Given Versionen verschiedener Plattformen und Zustände, When `texte` läuft, Then wird je Plattform nur die eine Version im Zustand `PREPARE_FOR_SUBMISSION` gewählt (Attribute `platform`, `appStoreState`) und gesperrte Versionen werden nie gelesen oder geschrieben. Belegt durch `test_selects_only_editable_version_per_platform`.
- [x] **AC-4:** Given eine Plattform ohne bearbeitbare Version, When `texte` läuft, Then meldet der Lauf `keine bearbeitbare Version <Plattform>` mit den Zuständen, schreibt dort nichts und endet ohne Fehler (Rückgabecode 0); gibt es auf keiner Plattform eine, steht `geschrieben=0`. Belegt durch `test_no_editable_version_prints_message_and_exits_zero`.
- [x] **AC-5:** Given zwei bearbeitbare Versionen derselben Plattform, When `texte` läuft, Then bricht der Lauf mit `mehrdeutig` ab und schreibt nichts. Belegt durch `test_several_editable_versions_of_one_platform_abort`.
- [x] **AC-6:** Given ein vorhandener Datensatz mit abweichenden Feldern, When `texte` läuft, Then geht genau ein `PATCH /v1/appStoreVersionLocalizations/{id}` mit nur den abweichenden Feldern hinaus, auch wenn alle Felder leer sind (heutiger Zustand von iOS 1.0.1 en-US). Belegt durch `test_different_text_patches_once_with_changed_fields_only`, `test_empty_en_us_record_gets_all_fields_by_patch`.
- [x] **AC-7:** Given eine bearbeitbare Version ohne Datensatz für die Locale aus der Datei, When `texte` läuft, Then geht genau ein `POST /v1/appStoreVersionLocalizations` mit Locale, allen Feldern und der Relationship `appStoreVersion` auf diese Version hinaus. Belegt durch `test_missing_record_posts_with_locale_fields_and_relationship`.
- [x] **AC-8:** Given alle Felder bei Apple gleich dem Wunschtext, When `texte` läuft, Then geht kein Schreibaufruf hinaus und es steht `geschrieben=0`. Belegt durch `test_equal_values_write_nothing`.
- [x] **AC-9:** Given Datensätze weiterer Sprachen bei Apple (deutsch), When `texte` läuft, Then werden nur Locales aus der Textdatei angefasst; der deutsche Datensatz bleibt unverändert und nie Ziel eines Aufrufs. Belegt durch `test_only_locales_from_file_are_touched`.
- [x] **AC-10:** Given eine Textdatei ohne Werbetext, When `texte` läuft, Then wird `promotionalText` weder geschrieben noch geleert; mit Werbetext in der Datei wird er geschrieben. Belegt durch `test_promotional_text_is_optional`.
- [x] **AC-11:** Given geschriebene Felder, When Apple sie nach dem Schreiben nicht exakt zurückgibt, Then endet der Lauf mit Fehler `Gegenprobe`; bei Übereinstimmung steht `gegenprobe gleich=ja`. Belegt durch `test_verification_mismatch_is_error`, `test_empty_en_us_record_gets_all_fields_by_patch`.
- [x] **AC-12:** Given Apple antwortet auf einen Schreibaufruf mit 403 oder 409, When `texte` läuft, Then endet der Lauf mit klarer Meldung (409 mit Fehlercode) ohne Apples Rohantwort. Belegt durch `test_403_and_409_give_clear_message`.
- [x] **AC-13:** Given `lesen`, When der Lauf endet, Then wurde nichts geschrieben und die Ausgabe nennt Versionszustände sowie Zeichenzahlen und Wortlaut der Felder; eine kaputte Textdatei stört `lesen` nicht. Belegt durch `test_lesen_never_writes_and_prints_values`.
- [x] **AC-14:** Given jeder schreibende Lauf, When er Anfragen sendet, Then gehen alle Schreibaufrufe nur an `/v1/appStoreVersionLocalizations` (nichts wird eingereicht), eine unbekannte Aktion bricht vor der ersten Anfrage ab, und die Ausgabe enthält keine Zugangsdaten. Belegt durch `test_writes_only_localization_paths_and_submits_nothing`, `test_unknown_action_aborts_before_any_request`, `test_output_has_no_secrets`.
- [x] **AC-15:** Given der Handlauf-Workflow, When er geprüft wird, Then ist er nur manuell auslösbar mit der Auswahl `lesen`/`texte`, führt die Unit-Tests vor dem Skript aus und hält den Schlüssel nur im Lauf. Belegt durch `test_workflow_has_choice_unit_tests_and_secrets`.

## Dialog

### Runde 1
**Adversary:** Parser und Vorprüfung mit Grenzfällen direkt aufgerufen: CRLF-Datei, Schlüsselwörter 100/101 Bytes (Mehrbyte), Werbetext 170/171, Beschreibung 4000/4001 Zeichen, Backticks und Feldzeilen im Beschreibungsblock, `HTTPS://`, nur Leerraum, Abschnitt ohne Pflichtfeld, fehlender Schlussmarker, keine Abschnitte. Alle Fehlerfälle brechen mit Locale/Feld/Zahl ab, `requests == []`. Auffälligkeiten: F001 doppelter Abschnitt `## en-US` wird ohne Meldung zusammengeführt (späterer Wert gewinnt); F002 Überschrift `## en-US (draft)` wird als Locale angenommen.
**Implementierer:** Verhalten durch den Code belegt.
Code reference: scripts/asc_version_texts.py:44
Code reference: scripts/asc_version_texts.py:64
Code reference: scripts/asc_version_texts.py:196
Code reference: scripts/test_asc_version_texts.py:190

### Runde 2
**Adversary:** Versionswahl, Schreiben, Gegenprobe, Ausgabe gegen den Nachbau als Unterprozess: kleingeschriebener Zustand und fehlendes `platform` wählen nichts (Rückgabecode 0, `geschrieben=0`); `appVersionState` wird nirgends gelesen; Mehrdeutigkeit bricht vor dem ersten Schreiben ab; Schreibaufrufe nur an `/v1/appStoreVersionLocalizations`; de-DE nie angefasst; PATCH nur abweichende Felder; 401/403/409/422/500 ohne Rohrumpf. Mutationstest mit sieben eingebauten Defekten, jeder von mindestens einem Test erkannt. Wortlaut in `docs/reference/app-store-texte.md` Zeichen für Zeichen gleich dem der Spec (1493 Zeichen / 1531 Bytes, Schlüsselwörter 94, Werbetext 125). Workflow: nur `workflow_dispatch`, `inputs.` nur als `inputs.aktion`, Schlüssel nur im Lauf. Auffälligkeiten: F003 `lesen` bricht bei Mehrdeutigkeit ab; F004 keine Paginierung bei `limit=50` (spec-konform); F005 tatsächlicher Umfang höher als geschätzt.
**Implementierer:** Belege mit Code-Zeilen.
Code reference: scripts/asc_version_texts.py:110
Code reference: scripts/asc_version_texts.py:143
Code reference: scripts/asc_version_texts.py:157
Code reference: scripts/asc_version_texts.py:186
Code reference: docs/reference/app-store-texte.md:9
Code reference: .github/workflows/asc-version-texts.yml:6
Code reference: scripts/test_asc_version_texts.py:412

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

Tests: 19 bestanden, 0 fehlgeschlagen. Checkliste 15 von 15 bewiesen. Findings nicht blockierend: F001 MEDIUM (doppelter Abschnitt wird still zusammengeführt, Spec schweigt), F002–F005 LOW.

## Geprüfte Dateien

- sha256:f1212a3f9313fd8f5a4dcdfceb54b24517068a327bd479cd0d1d494e118bc63c  .github/workflows/asc-version-texts.yml
- sha256:e227a8828623922afd14e82269d9129ad068ae54251bb9e3e2ca62c888e2ab4d  docs/reference/app-store-texte.md
- sha256:d16a6ecfb7805ccbf4690635b8256ec2525853453d86a34986a9c11b506a62d2  scripts/asc_version_texts.py
- sha256:3299c7cfe22d9058e5cd1c5a086b09d0c14338f8598f3a9a563aeb6ba247be77  scripts/test_asc_version_texts.py

## Prüfbasis

- base: 2018dd93cfdf58f97d31c4d6dbd8fefd4ed8eb58
- blob:e629e98d480e7f3ab4c69bf1eddf7abbf13e2916  .github/workflows/asc-version-texts.yml
- blob:94bd70a7259a77bcafd618e2e357a3ee3d4560d1  docs/reference/app-store-texte.md
- blob:102c6f082f4ccce9f1eb648f1904e8fac33cb178  scripts/asc_version_texts.py
- blob:111cb18ba22d0f6a19ec5bfc473807b5372a863c  scripts/test_asc_version_texts.py
