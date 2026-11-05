# Adversary Dialog — feat-837-s2-schreibweg
Spec: docs/specs/feat-837-schnitt-2-schreibweg.md
Datum: 2026-11-05 09:04

## Checkliste
- [x] **AC-1:** Given nur App-Infos ohne `PREPARE_FOR_SUBMISSION` (wie heute), When `untertitel` läuft, Then bricht der Lauf mit „App-Informationen gesperrt“ samt Zuständen ab und es gibt 0 Schreibaufrufe. Belegt durch `test_locked_appinfos_abort_with_zero_writes`.
- [x] **AC-2:** Given mehr als eine App-Info im Zustand `PREPARE_FOR_SUBMISSION`, When `untertitel` läuft, Then Abbruch ohne Schreiben (es wird nie geraten, welche gemeint ist). Belegt durch `test_several_editable_appinfos_abort`.
- [x] **AC-3:** Given Name und Untertitel in ASC schon gleich dem Wunsch, When `untertitel` läuft, Then wird nichts geschrieben und die Ausgabe endet mit `zusammenfassung geschrieben=0`. Belegt durch `test_equal_values_write_nothing`.
- [x] **AC-4:** Given de-DE hat einen abweichenden Untertitel, When `untertitel` läuft, Then geht genau ein PATCH hinaus, der nur `subtitle` trägt. Belegt durch `test_different_subtitle_patches_once_with_subtitle_only`.
- [x] **AC-5:** Given en-US fehlt an der App-Info, When `untertitel` läuft, Then geht genau ein POST mit `locale`, `name`, `subtitle` und `relationships.appInfo` hinaus. Belegt durch `test_missing_en_us_posts_once_with_locale_name_subtitle_and_appinfo`.
- [x] **AC-6:** Given Name oder Untertitel länger als 30 Zeichen oder ein fehlender Sprachabschnitt, When `untertitel` läuft, Then bricht der Lauf ab, bevor die erste Anfrage hinausgeht. Belegt durch `test_too_long_text_aborts_before_any_request`, `test_missing_section_aborts_before_any_request`.
- [x] **AC-7:** Given Apple antwortet mit 403 oder 409, oder die Gegenprobe zeigt einen abweichenden Wert, When `untertitel` läuft, Then endet der Lauf mit klarer Meldung und Exit ≠ 0; nie bleibt ein stiller Erfolg. Belegt durch `test_403_and_409_give_clear_message`, `test_verification_mismatch_is_error`.
- [x] **AC-8:** Given die Aktion `lesen` und jeder Fehlerfall, When der Lauf Ausgabe erzeugt, Then wird nur gelesen, Zustand, Name und Untertitel stehen sichtbar und Zugangsdaten nie. Belegt durch `test_lesen_never_writes_and_prints_values`, `test_output_has_no_secrets`, `test_repo_text_file_parses_and_fits_limit`.
- [ ] **AC-9:** (offen, später zu belegen) Given die Mac-Prüfung von macOS 1.0 ist beendet und genau eine App-Info steht auf `PREPARE_FOR_SUBMISSION`, When der Handlauf `asc-app-info` mit `aktion=untertitel` läuft, Then meldet ASC danach in der Gegenprobe de-DE „Einfach sagen. Kopf frei.“ und en-US „Say it. Clear your head.“ mit Name „Loose Ends“ (Lauf-Link, Wert aus ASC; das belegt zugleich den PATCH-Rumpf). **Heute** bricht derselbe Lauf mit „gesperrt“ ab; dieser Abbruchlauf (`aktion=untertitel` nach dem Merge, 0 geschrieben, Zustände im Protokoll) ist der heutige Beleg für den Abbruchzweig, nicht für das Schreiben. Der Schreibbeleg bleibt offen und wird später in #837 nachgetragen.

## Dialog

### Runde 1
**Adversary:** Testlauf `python3 scripts/test_asc_app_info.py`: 14 Tests, OK (voller Lauf in `docs/artifacts/feat-837-s2-schreibweg/adversary-test-output.txt`); alle bestehenden `scripts/test_asc_*.py` gruen (kein FAIL). Pruefe je AC den Code-Pfad statt dem Test zu glauben.
- AC-1/AC-2: Code reference: scripts/asc_app_info.py:65 (`editable_info`: filtert nur auf `state == PREPARE_FOR_SUBMISSION`, 0 Treffer -> Fatal mit allen Zustaenden, mehr als 1 -> Fatal mehrdeutig, nie die erste). Gegenprobe: Zustand-Feld fehlt -> `?`, gesperrt (Probe 5); keine App-Infos -> gesperrt (Probe 7); jeweils 0 Schreibaufrufe. Die Wahl passiert in `main` (Zeile 145) vor `write_subtitles`, also vor jedem PATCH/POST.
- AC-3: Code reference: scripts/asc_app_info.py:104 (gleicher Untertitel -> `continue`, `written` bleibt 0, Zeile 146 druckt `zusammenfassung geschrieben=0`). CRLF-Datei (Probe 8) parst gleich, 0 Writes.
- AC-4: Code reference: scripts/asc_app_info.py:108 (PATCH, `attributes` nur `subtitle`, type und id im Umschlag). Wert mit Doppelpunkt (`Sag: Kopf frei`, Probe 4) kommt vollstaendig an, da `partition(":")` nur am ersten Doppelpunkt trennt (Zeile 32). Untertitel `null` bei Apple (Probe 1) -> ein PATCH.
- AC-5: Code reference: scripts/asc_app_info.py:113 (POST mit locale, name, subtitle, relationships.appInfo auf die gewaehlte Info-ID aus `editable_info`).
- AC-6: Code reference: scripts/asc_app_info.py:25 (`wanted_texts`: Abschnitt- und 30-Zeichen-Pruefung); `main` liest den Text in Zeile 139 vor `read_config` und jeder Anfrage. Leerer Untertitel (nur Leerzeichen, Probe 9) -> Abbruch, 0 Requests.
- AC-7: Code reference: scripts/asc_app_info.py:87 (`send` uebersetzt HTTP 403/409 in feste Meldung ohne Rohantwort), Zeile 125 `verify` wirft bei Abweichung. Der Rohantwort-Marker taucht in der Ausgabe nicht auf (Zeilen 93/95 sind feste Texte).
- AC-8: Code reference: scripts/asc_app_info.py:77 (`read_state`: nur GET, Zustand, Name, Untertitel). Fatal-Texte kommen aus den Hilfsmodulen ohne Zugangsdaten. Code reference: docs/reference/app-store-untertitel.md:10 (de-DE Untertitel, 25 Zeichen) und docs/reference/app-store-untertitel.md:14 (en-US Name 10, Untertitel 24 Zeichen) = freigegebener Wortlaut.
- Workflow: Code reference: .github/workflows/asc-app-info.yml:28 (`aktion` nur ueber `env`, Typ choice, nie direkt in `run` interpoliert), :31 Tests vor dem Schreiben, :37 Zugangsdatei mit umask 077 und trap-Loeschung; identisch zur Vorlage `asc-review-notes.yml`. Nur `workflow_dispatch`, `contents: read`.
**Implementierer:** Keine Gegenargumente; die Pfade sind wie beschrieben. Offen aus Runde 1: Teilfehler und Namensabweichung.

### Runde 2
**Adversary:** Gezielte Randfaelle.
- F001 (LOW, edge_case): Teilausfall zwischen zwei Sprachen. Code reference: scripts/asc_app_info.py:101 (Schleife schreibt je Sprache sofort; wirft die zweite Anfrage 403/409, entweicht `Fatal` vor `verify` (Zeile 121) und vor der Summenzeile (Zeile 146)). Die erste Sprache bleibt geschrieben, ohne Gegenprobe und ohne `zusammenfassung`. Mildernd: Ausgabe nennt "untertitel gesetzt", Exit 1, Neustart ist idempotent (schreibt nur bei Abweichung). Die Spec verlangt die Summe nur am Ende eines erfolgreichen Laufs.
- F002 (LOW, edge_case): Code reference: scripts/asc_app_info.py:104 vergleicht nur den Untertitel. Existiert en-US mit gleichem Untertitel, aber anderem Namen (Probe 3), schreibt der Lauf nichts und meldet 0, obwohl AC-3 "Name und Untertitel gleich" nennt. Spec Schritt 3 definiert ausdruecklich nur den Untertitel-Vergleich; Name wird nur beim Anlegen gesetzt. Kein Defekt gegen die Detailvorgabe, Luecke zwischen AC-3 und Schritt 3.
- F003 (LOW, edge_case): Code reference: scripts/asc_app_info.py:62 (dict pro Locale: bei doppelten Lokalisierungen gleicher Sprache gewinnt die letzte, Probe 6 patcht L4). Von Apple nicht zu erwarten.
- 403 beim GET: `get_json` in scripts/asc_wait_build.py wirft Fatal mit HTTP 403 und Hinweis auf die Einstellungen, ohne Rohantwort; GETs laufen vor allen Writes, also nichts geschrieben. Nur die erste Seite der Listen wird gelesen (unkritisch bei zwei App-Infos).
- Workflow-Injection: einzige Eingabe `aktion` ist ein choice und laeuft ueber `$AKTION` in Anfuehrungszeichen. Die Zugangsdatei wird exakt wie in der bestehenden Vorlage geschrieben (Code reference: .github/workflows/asc-app-info.yml:37); GitHub maskiert das Geheimnis.
- Die Tests pruefen Methode, Pfad und Rumpf der aufgezeichneten Anfragen am zustandsbehafteten Nachbau und `fake.requests == []` bei AC-6; kein Scheintest.
**Implementierer:** F001-F003 sind LOW und aendern weder Spec-Verhalten noch Sicherheit. Optional: Summe auch im Fehlerfall ausgeben; Namensvergleich in Schnitt 3 klaeren.

### Belege (Code-Referenzen je Datei)
Confirmation AC-1/AC-2 (CONFIRMED):
Code reference: scripts/asc_app_info.py:65
Confirmation AC-3 bis AC-5 (CONFIRMED):
Code reference: scripts/asc_app_info.py:101
Confirmation AC-6 bis AC-8 (CONFIRMED):
Code reference: scripts/asc_app_info.py:25
Confirmation Workflow (CONFIRMED):
Code reference: .github/workflows/asc-app-info.yml:31
Confirmation Wunschtext (CONFIRMED):
Code reference: docs/reference/app-store-untertitel.md:10
Confirmation Tests (CONFIRMED):
Code reference: scripts/test_asc_app_info.py:159
Finding F001 (LOW, edge_case) Teilausfall ohne Summe:
Code reference: scripts/asc_app_info.py:121

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

**VERIFIED** fuer AC-1 bis AC-8: Testlauf 14 passed, 0 failed, 0 uebersprungen; bestehende asc-Tests gruen; eigene Gegenproben (Untertitel null, fehlender Zustand, keine App-Infos, Doppelpunkt, CRLF, leerer Untertitel, Namensabweichung) brechen nichts. Nur LOW-Funde F001-F003. AC-9 bleibt bewusst offen: es verlangt einen echten CI-Lauf gegen App Store Connect nach Ende der Mac-Pruefung, der heute nicht existiert.

## Geprüfte Dateien

- sha256:a64e0c474a05d9ce993fd9bf0a00a41a99b1d4ed2c0728f7e9a9bd314d413f0c  .github/workflows/asc-app-info.yml
- sha256:83ee9e7df4cf10c87291090c40c3e60ac4a74ebaee0d02ed2868ea042d7524c3  docs/reference/app-store-untertitel.md
- sha256:c4b8e0ca620a0e287f563c14bbaff0ae3acf4f9369e619c0dd52334a27eb31e0  scripts/asc_app_info.py
- sha256:3cfc3351f28dc6f1e684a20367bea739b2e74370cef7129e06bc067b0d45eb05  scripts/test_asc_app_info.py

## Prüfbasis

- base: 940f830dace12b106ac78c9648705002776ffa9a
- blob:f6f65857c969f238bd724a8e8827a0fa48118642  .github/workflows/asc-app-info.yml
- blob:b75a22aabfc3421a4a6dcc41da908c7743f96520  docs/reference/app-store-untertitel.md
- blob:a2a3616b30adbb43d360acbc82c0cef7992e4262  scripts/asc_app_info.py
- blob:4685c708b069147cb0d373357668bd14eeb7833a  scripts/test_asc_app_info.py
