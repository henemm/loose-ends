---
entity_id: feat-625-schnitt-5d-1-store-werkzeug
type: feature
created: 2026-11-24
updated: 2026-11-24
status: draft
workflow: feat-625-s5d-store-einreichen
---

# Spec: Store-Werkzeug für die Einreichung 1.0.2 (Schnitt 5d-1, #625)

## Approval

- [ ] Approved

## GitHub Issue

#625 (Store-Schalter, Einreichung). Schnitt 5d-1; das Issue bleibt offen (`Refs #625`, nie `Closes #625`).
Analyse: `docs/context/feat-625-s5d-store-einreichen.md` (Abschnitte „Analysis“, „Affected Files (S5d-1)“, „Technical Approach“, „Alternativen“).
Vorgänger: `docs/specs/feat-625-schnitt-5c-konto-rueckbau.md`, Formvorbild für das Skript: `docs/specs/feat-842-schnitt-5a-1-mac-version-anlegen.md`.

**Nicht im Umfang (S5d-2, eigene Spec danach):** TestFlight-Bau 1.0.2, die Handläufe gegen Apple selbst (`anlegen`, Texte, Bilder, Notizen), Bildschirmaufnahme der Konto-Funktion, Betriebs-Tür `ALLOWED_APPLE_SUBS=*` mit Tagesgrenze, Datenschutz-Etikett im ASC-Web (braucht Hennings datiertes Ja), `asc-store-submit` `pruefen`/`einreichen` (nur nach Hennings Wort). Dieser Schnitt schreibt bei Apple nichts; er liefert nur das Werkzeug und den Notiztext.

## Für den PO

Für die Einreichung der neuen Version fehlen drei Dinge im Werkzeug: Es kann die iPhone-/iPad-Version 1.0.2 nicht selbst anlegen, es kennt die Marketing-Adresse nicht, und die Hinweise für Apples Prüfer sind auf Version 1.0 festgelegt und sagen, die App habe kein Konto und keinen eigenen Server. Das stimmt mit der Verbindung zu Claude nicht mehr. Dieser Schnitt behebt alle drei. Es ändert sich nichts an der App, und es wird bei Apple noch nichts angelegt oder eingereicht. Du musst nichts entscheiden.

## Purpose

`scripts/asc_store_version.py` `anlegen` legt heute nur die Mac-Version an und nimmt die Nummer der schon bearbeitbaren iOS-Version; eine iOS-Version 1.0.2 kann es nicht anlegen. `scripts/asc_version_texts.py` kennt das Feld `marketingUrl` nicht. `scripts/asc_review_notes.py` ist fest auf iOS „1.0“ verdrahtet, und `docs/reference/app-review-notizen.md` behauptet „no account registration, login or account deletion“ und „We run no server of our own“. Der Schnitt erweitert `anlegen` um die iOS-Version (Nummer aus `project.yml`, eine Quelle), ergänzt die Marketing-URL und lässt die Notizen je Plattform in die eine bearbeitbare Version schreiben, mit neuem, wahrem Text.

**Regeln vor Modell:** reine Liefer- und Dateiprüfung, die Zeile „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine neue ADR
- **Rationale:** Erweiterung bestehender Handlauf-Skripte nach dem Muster #842 S5a-1 (Plan nur aus GET, Gegenprobe im Lauf, nie löschen, nie einreichen); keine neue Abhängigkeit, kein neues Verfahren. Keine bestehende ADR fällt. Alternative „iOS-Version im ASC-Web anlegen“ ist in der Analyse verworfen (nicht wiederholbar, nicht gegenprüfbar).

## Source

**Dateien (Skriptcode und Notiztext, 5):** `scripts/asc_store_version.py`, `scripts/asc_version_texts.py`, `scripts/asc_review_notes.py`, `docs/reference/app-review-notizen.md`, `docs/reference/app-store-texte.md`.
**Dazu (zählen nicht zum Limit):** `scripts/test_asc_store_version.py`, `scripts/test_asc_version_texts.py`, `scripts/test_asc_review_notes.py`.
**Identifier:** `plan_mac_version` (wird zu einem Plan beider Plattformen), `anlegen`, `verify`, `the_mac_version`, `LINE_FIELDS`/`LABELS`/`check_section` (Marketing-URL), `VERSION_STRING`, `find_version`, `get_detail`, `main` in `asc_review_notes.py`.

**Gegen den Stand geprüft (2026-11-24):**

- `asc_store_version.py`: `plan_mac_version` bricht ab, wenn keine bearbeitbare iOS-Version existiert; die Zielnummer ist die der iOS-Version. `anlegen` schreibt höchstens ein POST (Mac) und je Plattform ein PATCH der Bau-Zuordnung; `pick_build` überspringt per `build_lock` markierte und unlesbare Bauten.
- `asc_version_texts.py`: `LINE_FIELDS` kennt `Support-URL` → `supportUrl`, Prüfung `startswith("https://")`; `marketingUrl` fehlt. `write_locale` schreibt nur Abweichungen, `verify` liest zurück.
- `asc_review_notes.py`: `VERSION_STRING = "1.0"`, Filter `filter[platform]=IOS`; `get_detail` bricht ohne Review-Detail ab und legt nichts an; Grenze `MAX_BYTES = 4000` (Bytes, nicht Zeichen), Platzhalter `<HIER_`.
- `project.yml` Zeile 24: `MARKETING_VERSION: "1.0.2"`. Bei Apple gibt es iOS 1.0 und 1.0.1, Mac 1.0 und 1.0.1, alle `READY_FOR_SALE`.
- `docs/reference/app-store-texte.md`: `Support-URL:` steht in beiden Abschnitten (`en-US` Z. 71, `de-DE` Z. 129), `Marketing-URL:` fehlt.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `project.yml` (`MARKETING_VERSION`) | quelle | einzige Quelle der Zielnummer; unverändert |
| `scripts/asc_version_texts.py` (`editable_version`, `app_versions`, `EDITABLE`, `PLATFORMS`) | skript | Plan und Auswahl der bearbeitbaren Version; Marketing-URL kommt hier hinein |
| `scripts/asc_wait_build.py`, `scripts/asc_what_to_test.py`, `scripts/asc_beta_probe.py` | skript | `read_config`, `get_data`, `send_json`, `Fatal`, `is_account_build`; unverändert |
| `.github/workflows/asc-store-version.yml`, `asc-version-texts.yml`, `asc-review-notes.yml` | workflow | rufen die Skripte; Aktionen und Eingaben bleiben, ein Eingabewert „Version“ kommt nirgends dazu |
| `docs/reference/app-store-texte.md`, `docs/reference/app-review-notizen.md` | doku | Eingabedateien der Handläufe |
| Downstream S5d-2 | schnitt | führt die Handläufe gegen Apple aus |

## Acceptance Criteria

Alle ACs sind Python-Unittests unter `scripts/` oder Textprüfungen darin (Stand der Dateien als Text gelesen); der Lauf `python3 -m unittest discover -s scripts -p 'test_*.py'` ist der Nachweis. Die Tests laufen gegen den Test-Fake `FakeASC`, nie gegen Apple.

**Anlegen (`scripts/test_asc_store_version.py`)**

- **AC-1:** GIVEN `project.yml` mit `MARKETING_VERSION: "1.0.2"` und bei Apple iOS 1.0 und 1.0.1 (beide `READY_FOR_SALE`), keine bearbeitbare iOS-Version, keine Mac-Version 1.0.2 WHEN `anlegen` läuft THEN wird zuerst die iOS-Version 1.0.2 per `POST /v1/appStoreVersions` angelegt (Plattform `IOS`, `versionString` 1.0.2), danach die Mac-Version mit derselben Nummer, danach je Plattform die Bau-Zuordnung wie bisher; es gibt genau zwei POST und höchstens zwei PATCH. Test: `test_anlegen_creates_ios_then_mac_version_from_project_yml`.
- **AC-2:** GIVEN die Zielnummer ist nicht größer als irgendeine vorhandene Version der Plattform, die angelegt würde (zum Beispiel `MARKETING_VERSION: "1.0.1"` oder `"1.0"` bei vorhandenem iOS 1.0.1; der Vergleich ist numerisch je Teil, 1.0.10 ist größer als 1.0.2), oder `MARKETING_VERSION` fehlt, ist leer oder keine Nummer der Form `\d+(\.\d+)*` WHEN `anlegen` läuft THEN endet der Lauf mit Fatal und Grund, bevor der erste Schreibaufruf (POST oder PATCH) abgesetzt wird. Test: `test_anlegen_aborts_before_writing_when_target_not_greater`, `test_anlegen_aborts_on_unreadable_marketing_version`.
- **AC-3:** GIVEN schon eine bearbeitbare (`PREPARE_FOR_SUBMISSION`) iOS- oder Mac-Version mit einer anderen Nummer als die Zielnummer WHEN `anlegen` läuft THEN Fatal mit Plattform und beiden Nummern, vor dem ersten Schreibaufruf; GIVEN die bearbeitbare Version hat die Zielnummer THEN wird sie nicht noch einmal angelegt („schon vorhanden, übersprungen“), und nur fehlende Teile (zum Beispiel die Mac-Version) werden geschrieben; mehr als eine bearbeitbare Version einer Plattform bleibt Fatal wie bisher. Test: `test_anlegen_aborts_on_editable_version_with_other_number`, `test_anlegen_skips_existing_editable_ios_version`, `test_anlegen_does_not_create_second_mac_version` (bestehend, bleibt grün).
- **AC-4:** GIVEN der Plan WHEN er gebildet wird THEN benutzt er ausschließlich GET-Aufrufe (Versionen, vorhandene Bau-Zuordnung, Bauwahl samt `build_lock`); die Wahl der Bauten beider Plattformen für die Zielnummer (`pick_build`: gültig, nicht abgelaufen, höchste Buildnummer, nie umgehängt, nie ein Bau mit der Konto-Marke oder mit unlesbaren oder leeren Texten) geschieht vor dem ersten Schreibaufruf, soweit sie ohne die neue Version möglich ist; fehlt für eine Plattform jeder passende Bau, endet der Lauf mit Fatal „kein gültiger Bau … nichts geschrieben“, bevor irgendeine Version angelegt wird. Test: `test_anlegen_plan_uses_only_get`, `test_anlegen_without_matching_build_writes_nothing`, `AccountBuildLockTests` (bestehend, bleiben grün: `test_pick_build_skips_account_builds`, `test_pick_build_fail_closed_on_unreadable`, `test_pick_build_fail_closed_on_empty`, `test_anlegen_never_assigns_account_build`).
- **AC-5:** GIVEN ein POST oder PATCH scheitert (HTTP 403, 409 oder anderer Fehler) WHEN `anlegen` läuft THEN wird der Schreibaufruf nie wiederholt (jede Anfrage-Nummer genau einmal im Aufrufprotokoll), die Meldung nennt den Grund ohne Apples Rohantwort, und ein bereits angelegter Teil bleibt stehen (keine Löschanfrage). Test: `test_write_errors_are_clear_without_raw_answer` (bestehend, erweitert um den iOS-POST) und `test_post_is_never_repeated`.
- **AC-6:** GIVEN `anlegen` hat geschrieben WHEN der Lauf endet THEN liest er im selben Lauf gegen: genau eine bearbeitbare Version je Plattform mit der Zielnummer und je Plattform ein Bau, dessen Vorabversion die Zielnummer trägt; bei Abweichung Fatal „Gegenprobe: …“, bei Gleichheit die Zeile `gegenprobe gleich=ja` und danach die Ausgabe wie `lesen`. Test: `test_verification_fails_on_deviation` (bestehend, auf beide Plattformen erweitert) und `test_anlegen_prints_gegenprobe_and_state`.
- **AC-7:** GIVEN beliebige Eingaben WHEN `asc_store_version.py` läuft THEN gibt es nie `DELETE` und nie einen Schreibaufruf an Einreichung, Review-Submission, Texte, Bilder oder Review-Detail (erlaubt sind nur `POST /v1/appStoreVersions` und `PATCH …/relationships/build`); `lesen` setzt keinen Schreibaufruf ab. Test: `test_never_deletes_submits_or_writes_texts` und `test_lesen_reports_state_and_never_writes` (bestehend, bleiben grün; ersterer prüft zusätzlich beide POST-Plattformen).

**Marketing-URL (`scripts/test_asc_version_texts.py`)**

- **AC-8:** GIVEN ein Abschnitt in `app-store-texte.md` mit der Zeile `Marketing-URL: https://…` WHEN die Datei gelesen wird THEN steht der Wert als `marketingUrl` im Wunschtext der Locale und wird von `write_locale` bei Abweichung geschrieben und von `verify` gegengeprüft; ohne die Zeile ist das Feld nicht im Wunschtext und wird nicht angefasst (optional). Test: `test_marketing_url_line_is_parsed_and_written`, `test_marketing_url_is_optional`.
- **AC-9:** GIVEN eine `Marketing-URL:`-Zeile ohne `https://` am Anfang oder ohne Host (zum Beispiel `https://` allein, `http://…`) WHEN `wanted_texts` läuft THEN Fatal mit Locale und „Marketing-URL muss mit https:// beginnen“ beziehungsweise „Host“, vor jeder Anfrage; die Prüfung gilt genauso für `Support-URL` ohne Host. Test: `test_marketing_url_must_be_https_with_host`.
- **AC-10:** GIVEN `docs/reference/app-store-texte.md` WHEN sie gelesen wird THEN steht in den Abschnitten `en-US` und `de-DE` je genau eine Zeile `Marketing-URL: https://www.henemm.com/loose-ends/`, und `wanted_texts` auf die echte Datei gibt für beide Locales `marketingUrl` zurück. Test: `test_real_file_has_marketing_url_in_both_locales`.

**Review-Notizen (`scripts/test_asc_review_notes.py`)**

- **AC-11:** GIVEN je eine bearbeitbare Version iOS und Mac WHEN `asc_review_notes.py notizen` läuft THEN werden die Notizen je Plattform in das Review-Detail genau dieser einen bearbeitbaren Version geschrieben (nur bei Abweichung, je ein PATCH, nie wiederholt) und je Plattform gegengeprüft (`gegenprobe gleich=ja`); die Konstante `VERSION_STRING = "1.0"` und der feste Versionsfilter entfallen, und `lesen` schreibt nichts. Test: `test_notizen_writes_to_editable_version_of_each_platform`, `test_notizen_unchanged_when_equal`, `test_lesen_never_writes`.
- **AC-12:** GIVEN keine bearbeitbare Version einer Plattform, mehr als eine, oder eine bearbeitbare Version ohne Review-Detail (404 oder `data: null`) WHEN `notizen` läuft THEN Fatal mit Plattform und Grund, und es wird nichts angelegt (kein POST auf `appStoreReviewDetails`); eine Plattform ohne bearbeitbare Version bricht vor dem ersten Schreibaufruf ab, auch wenn die andere Plattform in Ordnung wäre. Test: `test_notizen_aborts_without_editable_version`, `test_notizen_aborts_without_review_detail_and_creates_nothing`, `test_notizen_aborts_before_writing_when_one_platform_fails`.
- **AC-13:** GIVEN `docs/reference/app-review-notizen.md` WHEN der erste Codeblock gelesen wird THEN ist er höchstens 4000 Byte lang (die Grenze, die `MAX_BYTES` in `wanted_notes` hält; Apples Feld erlaubt 4000 Zeichen, die Byte-Grenze ist strenger und bleibt), trägt keinen Platzhalter `<HIER_`, und `wanted_notes()` auf die echte Datei läuft ohne Fehler. Test: `test_real_notes_fit_the_limit`.
- **AC-14:** GIVEN derselbe Notiztext WHEN er als Text geprüft wird THEN enthält er (Groß-/Kleinschreibung ignoriert) weder „no account registration“, „login or account deletion“, „No login“ noch „no server of our own“ und sagt in englischer Sprache: Anmeldung nur über „Sign in with Apple“ mit der eigenen Apple-ID des Prüfers, keine Demo-Zugangsdaten nötig; Konto löschen in der App (mit Verweis auf Guideline 5.1.1(v)); der eigene Dienst läuft auf einem Server in Deutschland; die Verbindung zu Claude als Connector in claude.ai (braucht ein Claude-Konto, die Bildschirmaufnahme zeigt den Ablauf); die App ist ohne Konto voll nutzbar. Geprüft wird je Aussage ein Schlüsselbegriff (`Sign in with Apple`, `5.1.1(v)`, `Germany`, `claude.ai`, `Claude account`, `without an account`, `no demo credentials`). Test: `test_notes_have_no_false_statements`, `test_notes_state_account_facts`.

**Gesamtlauf**

- **AC-15:** GIVEN die Gesamt-Diffliste WHEN sie geprüft wird THEN enthält sie keine Swift-Datei, kein `project.yml`, keine `Info.plist`, keine `.entitlements` und kein `PrivacyInfo.xcprivacy`, und der Gesamtlauf `python3 -m unittest discover -s scripts -p 'test_*.py'` ist grün; die Workflows `asc-store-version.yml`, `asc-version-texts.yml` und `asc-review-notes.yml` bleiben unverändert und bieten weiter nur die Aktionen `lesen`/`anlegen`, `lesen`/`texte` und `lesen`/`notizen` (Bestandstests `WorkflowTests` grün). Test: `scripts/test_asc_store_version.py` `WorkflowTests.test_workflow_offers_both_actions_and_hides_the_key` (bestehend) und der Gesamtlauf.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_store_version.py` | MODIFY | Plan beider Plattformen aus `project.yml`; iOS-Version anlegen; Abbruchbedingungen vor dem ersten Schreiben; Gegenprobe beider Plattformen; ca. +55/−15 |
| `scripts/asc_version_texts.py` | MODIFY | Zeile `Marketing-URL` → `marketingUrl`, https- und Host-Prüfung; ca. +10/−2 |
| `scripts/asc_review_notes.py` | MODIFY | je Plattform die eine bearbeitbare Version statt fest „1.0“; Abbruch ohne Review-Detail; ca. +25/−15 |
| `docs/reference/app-review-notizen.md` | MODIFY | Notiztext für 1.0.2 neu (englisch), Kopf auf den neuen Stand; Textdatei, keine Codezeilen |
| `docs/reference/app-store-texte.md` | MODIFY | zwei Zeilen `Marketing-URL:` (en-US, de-DE) |
| `scripts/test_asc_store_version.py` | MODIFY | Tests zu AC-1 bis AC-7 (zählt nicht ins Limit) |
| `scripts/test_asc_version_texts.py` | MODIFY | Tests zu AC-8 bis AC-10 (zählt nicht ins Limit) |
| `scripts/test_asc_review_notes.py` | MODIFY | Tests zu AC-11 bis AC-14 (zählt nicht ins Limit) |

### Estimated Changes

- Files: 5 ohne Tests (Limit 4 bis 5 eingehalten), dazu 3 Testdateien.
- LoC (Skriptcode): ca. +90/−32, zusammen weit unter ±250; Notiztext ca. +35/−30 Zeilen (Text, kein Code); Tests ca. 250 (zählen nicht).
- **App-Code (Swift):** keiner. Kein Pfad der Geräteliste berührt, Stufe 3 entfällt.
- **Berührte Berechtigungen und Schlüssel (explizit):** keine; kein AppStorage-Schlüssel, kein CloudKit-Schema, keine Audio-Dateien, kein Eintrag in `project.yml` oder `Info.plist` (nur gelesen).
- **Seiteneffekte (explizit):**
  1. `anlegen` nimmt die Zielnummer künftig aus `project.yml` statt aus der bearbeitbaren iOS-Version; eine bearbeitbare Version mit anderer Nummer ist jetzt ein Abbruch statt der Quelle der Nummer. Bestandstests, die das alte Verhalten festhielten, werden umgestellt (die Nummer kommt über eine Testdatei für `project.yml`).
  2. `asc_review_notes.py` arbeitet nicht mehr nur auf iOS „1.0“; ohne bearbeitbare Version bricht es ab, wo es vorher die alte 1.0 (`READY_FOR_SALE`) beschrieben hätte.
  3. Die Handläufe werden in diesem Schnitt nicht gegen Apple ausgeführt.
- **Parallele Arbeit:** Hotspot `CLAUDE.md` wird nicht geändert; vor dem PR `origin/main` und offene PRs prüfen.

## Implementation Details

Reihenfolge (TDD): zuerst die Tests in den drei Testdateien schreiben und rot belegen, dann die Skripte und die Texte ändern, dann grün.

1. `asc_store_version.py`: `target_version()` liest `MARKETING_VERSION` per Regex aus `project.yml` (Pfad relativ zum Skript, für Tests über die Umgebungsvariable `PROJECT_FILE` überschreibbar, Fehler → Fatal ohne Dateiinhalt). `plan_versions(versions, target)` ersetzt `plan_mac_version`: je Plattform die bearbeitbare Version (andere Nummer → Fatal, mehrere → Fatal), fehlt sie, muss `target` numerisch größer sein als jede vorhandene Nummer der Plattform. `anlegen` wählt danach die Bauten (GET), legt fehlende Versionen an (iOS zuerst, dann Mac, je ein POST, nie wiederholt), liest die neuen bearbeitbaren Versionen neu und ordnet die Bauten zu; `verify` prüft beide Plattformen auf genau eine bearbeitbare Version mit Zielnummer. Der Bau-Plan für eine noch nicht angelegte Version nutzt nur Plattform und Zielnummer (`pick_build` filtert schon so), nicht die Versions-ID.
2. `asc_version_texts.py`: `LINE_FIELDS`, `LABELS` und `OPTIONAL` um `Marketing-URL`/`marketingUrl`; `check_section` prüft beide URL-Felder mit `urllib.parse.urlparse` auf Schema `https` und nicht leeren Host.
3. `asc_review_notes.py`: `find_version` wird `editable_versions(config, app_id)` über `editable_version` aus `asc_version_texts.py` für beide Plattformen; Plan (Version und Review-Detail beider Plattformen lesen) vor dem ersten PATCH; `write_notes` je Plattform, Ausgabe mit Plattformkürzel; Bytegrenze und Platzhalterprüfung bleiben vor der ersten Anfrage.
4. Notiztext: Struktur der Punkte 1 bis 6 bleibt (Bildschirmaufnahme, Zweck, Bedienung, externe Dienste, Regionen, regulierte Branche); Punkt 1 Satz zur Kontolosigkeit weg; Punkt 3 „How to use it“ nennt: App voll nutzbar ohne Konto, kein Login nötig für die Aufgabenerfassung; Verbindung zu Claude optional unter Einstellungen › Claude, Anmeldung nur mit „Sign in with Apple“ (eigene Apple-ID des Prüfers, keine Demo-Zugangsdaten nötig), „Delete account“ in der App (Guideline 5.1.1(v)); Punkt 4: Dienst auf einem Server in Deutschland, hält nur eine Kopie offener Aufgaben (Titel und Felder, nie Rohtext, Notizen, Anhänge), Verbindung als Connector in claude.ai (braucht ein Claude-Konto, die Bildschirmaufnahme zeigt den Ablauf), iCloud-Satz ohne „no server“. Kopf der Datei: Stand 2026-11-24, Version 1.0.2 iOS und Mac, eine Quelle für beide Plattformen.
5. `app-store-texte.md`: zwei Zeilen `Marketing-URL: https://www.henemm.com/loose-ends/`, je direkt unter `Support-URL:`.

Keine Änderung an Gate-Konfiguration, Hooks oder Workflow-Dateien. Der PR geht mit `Refs #625`, die CI muss grün sein, danach Merge.

## Test Plan

### Automated Tests (TDD RED)

RED zuerst: neue und umgestellte Tests müssen vor der Änderung gegen den alten Code rot sein.

- [ ] Test 1 (AC-1): GIVEN iOS 1.0 und 1.0.1 bei Apple, `project.yml` 1.0.2 WHEN `anlegen` läuft THEN POST iOS, POST Mac, zwei Bau-Zuordnungen, Gegenprobe gleich; rot (iOS-POST fehlt).
- [ ] Test 2 (AC-2): GIVEN Zielnummer 1.0.1, 1.0 oder kaputt WHEN `anlegen` läuft THEN Fatal, null Schreibaufrufe; rot; dazu 1.0.10 gegen 1.0.2 numerisch.
- [ ] Test 3 (AC-3): GIVEN bearbeitbare Version mit anderer Nummer / mit Zielnummer WHEN `anlegen` läuft THEN Abbruch ohne Schreiben / übersprungen; rot für den Abbruch der iOS-Seite.
- [ ] Test 4 (AC-4): GIVEN Bauwahl WHEN der Plan läuft THEN nur GET, kein Bau → null Schreibaufrufe, markierte und unlesbare Bauten gesperrt; rot für die Reihenfolge (heute wird Mac vor der Bau-Prüfung der neuen Version nicht angelegt, iOS fehlt ganz).
- [ ] Test 5 (AC-5): GIVEN 409/403 auf POST WHEN `anlegen` läuft THEN eine Anfrage, klare Meldung, kein zweiter Versuch; grün bei Mac bestehend, rot für iOS.
- [ ] Test 6 (AC-6): GIVEN Abweichung nach dem Schreiben WHEN `verify` läuft THEN Fatal „Gegenprobe“ je Plattform; rot.
- [ ] Test 7 (AC-7): GIVEN alle Läufe WHEN das Aufrufprotokoll geprüft wird THEN nie DELETE, nie Einreichung, nie Text- oder Review-Detail-Schreiben; Gegenprobe, grün vorher und nachher.
- [ ] Test 8 (AC-8, AC-9, AC-10): GIVEN Textdateien mit und ohne `Marketing-URL`, mit `http://`, ohne Host, und die echte Datei WHEN gelesen THEN geparst, optional, abgelehnt, in beiden Locales vorhanden; rot (Feld und Zeilen fehlen).
- [ ] Test 9 (AC-11, AC-12): GIVEN FakeASC mit je einer bearbeitbaren Version, ohne Version, mit zwei Versionen, ohne Review-Detail WHEN `notizen` läuft THEN je Plattform ein PATCH mit Gegenprobe beziehungsweise Abbruch vor dem Schreiben ohne Anlegen; rot (fest „1.0“, nur iOS).
- [ ] Test 10 (AC-13, AC-14): GIVEN die echte Notizdatei WHEN gelesen THEN höchstens 4000 Byte, ohne Platzhalter, ohne die falschen Sätze, mit den fünf Aussagen; rot gegen den alten Text.
- [ ] Test 11 (AC-15): GIVEN der Gesamtlauf WHEN `unittest discover -s scripts -p 'test_*.py'` läuft THEN grün.

Keine UI-Tests und keine Unit-Tests der App: der Schnitt berührt keinen Swift-Code. Benannte Lücke: ob Apple die iOS-Version 1.0.2 wirklich so annimmt (Felder, Übernahme von Texten und Bildern) und das Review-Detail mit anlegt, belegt erst der Betriebslauf in S5d-2 (`lesen` nach `anlegen`); die Annahme stützt sich auf den Mac-Befund von #842 S5a-1/S5a-2.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **Gewählt: `anlegen` erweitern, Zielnummer aus `project.yml`** | iOS und Mac per Handlauf, ein Skript | wiederholbar, gegengeprüft, eine Quelle für die Nummer | Skript wächst um ca. 40 Zeilen | — |
| iOS-Version im ASC-Web anlegen | Claude im Chrome, Henning meldet sich an | spart ca. 30 Zeilen; Apple übernimmt laut Hilfe mehr Metadaten | braucht Hennings Anmeldung, nicht gegenprüfbar, bricht das Muster „alles per Handlauf“ | verworfen; keine ADR |
| Zielnummer als Eingabe des Workflows | Version als Parameter | kein Lesen von `project.yml` | zweite Quelle der Nummer, Tippfehler möglich, Workflow-Datei ändert sich | verworfen; keine ADR |
| Notizen bleiben nur iOS | Mac nicht mitschreiben | kleiner | Mac-Prüfung hätte Notizen von 1.0 oder keine; die Einreichung läuft beide Plattformen (#893) | verworfen; keine ADR |

Keine ADR fällt bei einer Variante.

## Risiken

- **Doppelte Version durch wiederholten POST.** Gegenmittel: AC-5 (nie wiederholt), AC-3 (vorhandene bearbeitbare Version wird nie noch einmal angelegt), Plan nur aus GET (AC-4).
- **Halbes Ergebnis:** iOS angelegt, Mac scheitert. Gegenmittel: Der nächste Lauf erkennt die vorhandene iOS-Version (AC-3) und legt nur das Fehlende an; nichts wird gelöscht (AC-7).
- **Falsche Notiztexte gehen an Apple.** Gegenmittel: AC-14 als Textprüfung, AC-13 Längengrenze; der Schreiblauf selbst gehört zu S5d-2 und läuft erst nach der Bildschirmaufnahme.
- **Bytegrenze strenger als Apples Zeichengrenze.** Bewusst beibehalten (4000 Byte ≤ 4000 Zeichen), damit nie ein Text knapp an der Grenze von Apple abgelehnt wird.
- **Marketing-Seite liefert kein 200.** Nicht Teil dieses Schnitts; S5d-2 prüft die Adresse, bevor `texte` läuft.

## Out of Scope / Folgeschnitte

- S5d-2: Betrieb und Einreichung (siehe oben), eigene Spec.
- Anlegen des Review-Details, falls Apple es bei iOS 1.0.2 nicht mit anlegt: erst bei Befund in S5d-2.
- Änderungen an `asc_store_submit.py`, `asc_app_info.py`, `asc_store_probe.py` und an den Workflow-Dateien.

## Definition of Done

- [ ] AC-1 bis AC-15 erfüllt; Python-Tests grün (RED-Lauf und GREEN-Lauf belegt), CI grün
- [ ] PR mit `Refs #625` (nie `Closes`), gemergt
- [ ] Abschlussbericht mit dem Satz: „Kein Pfad der Geräteliste berührt.“ (Stufe 3 entfällt; Stufe 1 sind die Tests, Stufe 2 die CI, kein App-Code geändert)
- [ ] #625 kommentiert (Stand Schnitt 5d-1, Folge 5d-2), Board-Karte aktuell, Memory geschrieben

## Changelog

- 2026-11-24: Initial spec created (Schnitt 5d-1 von #625, Store-Werkzeug für die Einreichung 1.0.2)
