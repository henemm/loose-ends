# Adversary Dialog — feat-893-d-datenschutz
Spec: docs/specs/feat-893-schnitt-d-datenschutz.md
Datum: 2026-11-10 16:28

## Checkliste
- [x] **AC-1:** Given Lokalisierungen mit und ohne Datenschutz-Adresse, When `lesen` läuft, Then zeigt die Ausgabe je Sprache `datenschutz=<adresse>` oder `datenschutz=-`, und es gibt keinen Schreibaufruf. Belegt durch `test_read_shows_privacy_url_per_locale`.
- [x] **AC-2:** Given eine Sprache mit abweichender oder fehlender Adresse, When `datenschutz` läuft, Then gibt es je abweichender Sprache genau einen PATCH mit nur `privacyPolicyUrl`, bei gleicher Adresse keinen Aufruf, danach `gegenprobe gleich=ja`. Belegt durch `test_privacy_patches_only_differing_locales`.
- [x] **AC-3:** Given bereits gesetzte Adressen, When `datenschutz` ein zweites Mal läuft, Then ist `geschrieben=0` und es gibt keinen Schreibaufruf. Belegt durch `test_privacy_second_run_writes_nothing`.
- [x] **AC-4:** Given keine oder mehrere bearbeitbare App-Infos, When `datenschutz` läuft, Then bricht es ohne Schreibaufruf mit Ausgang 1 ab. Belegt durch `test_privacy_refuses_locked_or_ambiguous_info`.
- [x] **AC-5:** Given eine fehlende oder nicht-https Adresse, When `datenschutz` läuft, Then bricht es vor jeder Anfrage mit Ausgang 1 ab. Belegt durch `test_privacy_missing_or_bad_address_stops_before_any_request`.
- [x] **AC-6:** Given eine bei Apple fehlende Lokalisierung, When `datenschutz` läuft, Then legt es nichts an (kein POST) und bricht mit Ausgang 1 ab. Belegt durch `test_privacy_missing_localization_not_created`.
- [x] **AC-7:** Given ein Apple, das den Wert nicht übernimmt, When `datenschutz` läuft, Then schlägt die Gegenprobe mit Ausgang 1 an. Belegt durch `test_privacy_verify_detects_mismatch`.
- [x] **AC-8:** Given ein Lauf mit Geheimwerten in Umgebung und Antworten, When `datenschutz` läuft, Then schreibt es nur das Feld `privacyPolicyUrl` und gibt nie Schlüssel, Token oder Rohantworten aus. Belegt durch `test_privacy_writes_only_privacy_field_and_leaks_nothing`.
- [x] **AC-9:** Given die bestehenden Tests zu `lesen` und `untertitel`, When der Skripttest läuft, Then bleiben alle grün. Belegt durch `python3 scripts/test_asc_app_info.py`.

## Dialog

### Runde 1
**Adversary:** Testlauf `python3 scripts/test_asc_app_info.py`: 24 Tests, OK (Ausgabe in adversary-test-output.txt; nur ResourceWarnings des Test-Servers). Punkte einzeln gegen den Code geprüft.

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_app_info.py:98
  Evidence: read_state hängt `datenschutz=<adresse oder '-'>` an; read_state ruft nur lesend localizations, kein send. Test scripts/test_asc_app_info.py:316.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_app_info.py:146
  Evidence: write_privacy sendet je Sprache nur bei Abweichung einen PATCH, Rumpf nur `privacyPolicyUrl`; verify nur wenn written>0. Test scripts/test_asc_app_info.py:325.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_app_info.py:153
  Evidence: gleiche Adresse gibt "unverändert" und continue, written=0, kein verify, `geschrieben=0` in main. Test scripts/test_asc_app_info.py:336.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_app_info.py:83
  Evidence: editable_info wirft Fatal bei 0 oder mehr als 1 Info im Zustand PREPARE_FOR_SUBMISSION, vor write_privacy; main gibt 1 zurück. Test scripts/test_asc_app_info.py:344.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_app_info.py:58
  Evidence: wanted_privacy läuft in main vor read_config und jedem GET; leer, Leerzeichen, http://, ohne Schema ergeben Fatal; Test prüft fake.requests == []. Test scripts/test_asc_app_info.py:355.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/asc_app_info.py:149
  Evidence: fehlende Sprache ergibt Fatal vor jedem Schreibaufruf; write_privacy enthält keinen POST. Test scripts/test_asc_app_info.py:364.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/asc_app_info.py:167
  Evidence: verify liest neu und wirft Fatal bei Abweichung, Ausgang 1. Test scripts/test_asc_app_info.py:374 (ignore_writes).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_asc_app_info.py:382
  Evidence: PATCH-Attribute == {privacyPolicyUrl}; Ausgabe, auch beim 409 über send (scripts/asc_app_info.py:106), ohne Schlüssel, Bearer oder Rohantwort.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/test_asc_app_info.py:1
  Evidence: alle 24 Tests grün, inklusive der bestehenden lesen- und untertitel-Tests.
  Status: CONFIRMED

Workflow-Datei:
  Code reference: .github/workflows/asc-app-info.yml:16 — `datenschutz` in der Auswahl; Zeile 31 setzt ASC_PRIVACY_POLICY_URL aus der öffentlichen Variable (kein Secret); Unit-Tests laufen weiter vorher.

**Implementierer:** keine Einwände.

### Runde 2
**Adversary:** Skepsis, weil in Runde 1 alles grün war. Gezielte Angriffe:
- Kein POST: write_privacy (Zeilen 146-165) enthält keinen POST; nur write_subtitles legt an. Gehalten.
- Nur privacyPolicyUrl im PATCH: Zeile 156 fest verdrahtet. Gehalten.
- Abbruch vor jeder Anfrage: in main steht wanted_privacy vor read_config (scripts/asc_app_info.py:182). Gehalten.
- ASC_PRIVACY_POLICY_URL_EN leer gesetzt: `or PRIVACY_URL_EN` (Zeile 61) fällt auf die Konstante zurück. Gehalten.
- Dritte ausgelieferte Sprache ohne Adresse: Fatal vor jeder Anfrage, kein halbes Schreiben. Gehalten.
- Gegenprobe und Idempotenz: siehe AC-3 und AC-7, Wiederholung nach Teilausfall heilt.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_app_info.py:161
  Description: Schlägt der zweite PATCH fehl, läuft die Gegenprobe des ersten nicht; Ausgang trotzdem 1.
  Spec requirement: AC-2 — Gegenprobe nach dem Schreiben
  Conflict: nur bei Teilausfall; Lauf bricht mit Ausgang 1 ab, Wiederholung ist idempotent.
  Remediation: optional, kein Blocker.

**Implementierer:** keine Änderung nötig.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Zusätzlich: `privacyPolicyUrl` wird nur in scripts/asc_app_info.py:156 geschrieben. Bedingung davor: eindeutige bearbeitbare App-Info, Sprache vorhanden, Adresse https und abweichend. Test für diesen Weg: test_privacy_patches_only_differing_locales (scripts/test_asc_app_info.py:325).

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: 24 passed, 0 failed, 0 übersprungen
Edge cases: All checked, none broken (F001 LOW, Teilausfall)
Regressions: None found
Checklist: 9/9 points proven

## Geprüfte Dateien

- sha256:08718df08eac1d26506907b5318cdc52652f4cb63afa6596599cf266d318bdf5  .github/workflows/asc-app-info.yml
- sha256:da9976fd9ae47d873e96695f15e356b5f6eaf19a03ba8e863a654270f807b47a  scripts/asc_app_info.py
- sha256:31a3669fa3f989a8d9c851cf0482778c533ee95ed04831ad00ddfcc3e8e66c66  scripts/test_asc_app_info.py

## Prüfbasis

- base: c62fbae4550368d97cf3132fcd9667fa5e8c75d8
- blob:b791a6b46c9aab831e6df4fc2054ca729364259d  .github/workflows/asc-app-info.yml
- blob:6ec0c8cdd0188b5aeac9d3dc7a39201a4114e2d6  scripts/asc_app_info.py
- blob:e4958b72095b4e71fe5b828690fd65ac4fb4e682  scripts/test_asc_app_info.py

## Geprüfte Dateien

- sha256:08718df08eac1d26506907b5318cdc52652f4cb63afa6596599cf266d318bdf5  .github/workflows/asc-app-info.yml
- sha256:da9976fd9ae47d873e96695f15e356b5f6eaf19a03ba8e863a654270f807b47a  scripts/asc_app_info.py
- sha256:31a3669fa3f989a8d9c851cf0482778c533ee95ed04831ad00ddfcc3e8e66c66  scripts/test_asc_app_info.py

## Prüfbasis

- base: c62fbae4550368d97cf3132fcd9667fa5e8c75d8
- blob:b791a6b46c9aab831e6df4fc2054ca729364259d  .github/workflows/asc-app-info.yml
- blob:6ec0c8cdd0188b5aeac9d3dc7a39201a4114e2d6  scripts/asc_app_info.py
- blob:e4958b72095b4e71fe5b828690fd65ac4fb4e682  scripts/test_asc_app_info.py
