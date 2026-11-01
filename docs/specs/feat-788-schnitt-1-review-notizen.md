---
entity_id: feat-788-schnitt-1-review-notizen
type: feature
created: 2026-11-01
updated: 2026-11-01
status: draft
workflow: feat-788-review-notes
---

# Spec: #788 Schnitt 1 — App-Review-Notizen lesen und setzen (Guideline 2.1)

## Approval

- [ ] Approved

## Purpose

Apple hat die Einreichung von Version 1.0 (iOS, 2026-10-31) mit „Guideline 2.1 – Information Needed“ zurückgegeben: Es
fehlen Angaben (Zweck, Zielgruppe, Bedienung, Dienste, Regionen, Regulierung) im Feld „Notes“ der App-Review-Informationen
und eine Bildschirmaufnahme. Schnitt 1 liefert den Textteil: ein Handlauf in der CI liest den Zustand der Version und der
Review-Informationen (`lesen`) und setzt die Notizen aus `docs/reference/app-review-notizen.md` (`notizen`), nur bei
Abweichung, mit Gegenprobe. Das Video folgt in Schnitt 2, das erneute Einreichen gehört nicht zu diesem Ticket und
geschieht nur nach Hennings Wort. Henning wählte am 2026-11-01 „Zwei Schritte, automatisch“.

Ohne Modell geht es nicht: nicht relevant. Es ist ein Betriebsskript gegen die App-Store-Connect-API, kein Modell beteiligt
(Regeln vor Modell gilt trivial).

## Source

- **File:** `scripts/asc_review_notes.py` (neu)
- **Identifier:** `main(argv)` mit Aktion `lesen` oder `notizen`; Vorbild im Aufbau: `scripts/asc_beta_setup.py`
  (`plan_review_detail`, `apply_plan`, `state`: erst lesen, nur Abweichungen schreiben, Ausgabe nur Zustandswörter) und
  `scripts/asc_store_probe.py` (liest `appStoreVersions` samt `appStoreState`).

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `read_config`, `find_app_id`, `get_json`, `Fatal` (`scripts/asc_wait_build.py`) | module | Konfiguration aus den ASC-Umgebungsvariablen, JWT mit `openssl`, GET gegen die API |
| `send_json`, `get_data`, `ATTEMPTS` (`scripts/asc_what_to_test.py`) | module | PATCH mit Wiederholung bei 5xx/408/429, Liste `data` mit Wiederholung |
| `records`, `attributes` (`scripts/asc_beta_probe.py`) | module | Datensätze und Attribute aus Antworten |
| `scripts/test_asc_beta_setup.py` | test | Vorbild: lokaler HTTP-Nachbau mit Zustand, echte `openssl`-Schlüssel im Testordner, keine echten Aufrufe |
| `.github/workflows/asc-store-probe.yml` | workflow | Vorbild für Secrets und Schlüsseldatei |
| `docs/reference/app-review-notizen.md` | doc | Quelle des Textes (erster Codeblock) |
| App Store Connect API | extern | `appStoreVersions`, `appStoreReviewDetails` (`notes`, Limit 4000 Byte), `appStoreReviewAttachments` (nur lesen); [Review-Informationen](https://developer.apple.com/help/app-store-connect/reference/app-review-information), [App Store review details](https://developer.apple.com/documentation/appstoreconnectapi/app-store-review-details) |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_review_notes.py | CREATE | Aktionen `lesen` und `notizen`, Codeblock-Extraktion, Bytegrenze, Gegenprobe |
| scripts/test_asc_review_notes.py | CREATE | Tests gegen lokalen Nachbau (Grenze, Idempotenz, Extraktion, Log, Fehlerfälle) |
| .github/workflows/asc-review-notes.yml | CREATE | Handlauf `workflow_dispatch` mit Eingabe `aktion` (`lesen`, `notizen`) |
| docs/reference/app-review-notizen.md | CREATE | neu auf diesem Branch (Entwurf); Platzhalter `<HIER_VIDEO_LINK>` weg, Kopf auf neuen Stand |
| docs/reference/testflight.md | MODIFY | Handlauf in der ASC-Tabelle und Beschreibung |

### Estimated Changes
- Files: 5 (3 neu, 2 geändert)
- LoC: ca. +230/−6 (Skript ca. 95, Tests ca. 90, Workflow ca. 35, Doku ca. 10)

## Implementation Details

**Version finden.** `find_app_id`, dann `GET /v1/apps/{id}/appStoreVersions?filter[platform]=IOS&filter[versionString]=1.0`.
Genau ein Treffer wird verwendet; keiner → Abbruch „keine iOS-Version 1.0 in App Store Connect“, mehrere → Abbruch mit Zahl.
Ausgabe: `version 1.0 IOS appStoreState=<Wert>`.

**Review-Details finden.** `GET /v1/appStoreVersions/{id}/appStoreReviewDetail`. Antwort ohne `data` (404 oder `null`):
Abbruch mit eigener Meldung „Version 1.0 hat keine App-Review-Informationen“, **ohne** Anlegen per POST. Begründung: Die
Version wurde am 2026-10-31 mit Review-Informationen eingereicht und Apple hat nach genau diesem Feld gefragt, das Detail
existiert also. Ein POST würde zusätzlich Kontaktfelder anlegen, die dieses Skript nicht kennt, und aus einem Fehlerfall
einen stillen Schreibvorgang machen. Fehlt das Detail trotzdem, ist das ein Befund für Henning, kein Fall für Raten.

**`lesen` (nur lesend).** Ausgabe, jeweils nur Zustände, nie Werte: `notizen gesetzt bytes=<N>` oder `notizen leer`;
je Anhang (`GET /v1/appStoreReviewDetails/{id}/appStoreReviewAttachments`) `anhang name=<fileName> groesse=<fileSize>
assetDeliveryState=<state>`, ohne Anhänge `anhang keine`; zum Schluss `zusammenfassung geschrieben=0`. Kontaktfelder und
der Notes-Inhalt werden nie ausgegeben (das Repo ist öffentlich, Läufe sind lesbar).

**`notizen`.**
1. Text lesen: erster Codeblock (zwischen den ersten beiden Zeilen ```` ``` ```` ) aus `docs/reference/app-review-notizen.md`,
   führende und abschließende Leerzeilen entfernt, sonst unverändert. Kein Codeblock oder leer → Abbruch.
2. Prüfen **vor jedem Schreibaufruf**: UTF-8-Bytezahl ≤ 4000 (Apple zählt Byte; „ä“ zählt 2), sonst Abbruch mit Ist- und
   Sollwert; Text enthält keinen Platzhalter `<HIER_` → sonst Abbruch.
3. Aktuellen Text lesen. Gleich → Ausgabe `notizen unverändert bytes=<N>`, kein PATCH. Abweichend → genau ein
   `PATCH /v1/appStoreReviewDetails/{id}` mit `attributes.notes`, Ausgabe `notizen gesetzt bytes=<N>`.
4. Gegenprobe: erneut lesen, Gleichheit mit dem Wunschtext prüfen, Ausgabe `gegenprobe gleich=ja`; ungleich → Abbruch mit
   Fehler. Schluss: `zusammenfassung geschrieben=<0|1>`.
Ein 403/409 beim PATCH (Version in diesem Zustand nicht beschreibbar) wird als eigene Meldung „Apple lässt die Notizen im
Zustand <appStoreState> nicht zu“ ausgegeben, ohne Wiederholung (`send_json` wiederholt nur 5xx/408/429).

**Workflow.** `workflow_dispatch`, Eingabe `aktion` (Typ `choice`: `lesen`, `notizen`; Standard `lesen`; `video` kommt in
Schnitt 2). Runner `ubuntu-latest`, `timeout-minutes: 10`, `permissions: contents: read`, Secrets `ASC_KEY_ID`,
`ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` und `ASC_POLL_SECONDS: "5"` wie in `asc-store-probe.yml`; kein Xcode. Schritte:
Checkout, Unit-Tests (`python3 scripts/test_asc_review_notes.py`), dann der Aufruf mit Schlüsseldatei in `$RUNNER_TEMP` und
`trap` zum Löschen. Neue Workflow-Dateien sind erst nach dem Merge auf `main` startbar.

**Textstand.** In `app-review-notizen.md` wird der Punkt 1 (Link `<HIER_VIDEO_LINK>`) zu „Screen recording of a physical
iPhone 16 Pro, attached to this submission.“ plus den bisherigen Folgesätzen; der Kopfabsatz nennt, dass der Text per
Handlauf `notizen` gesetzt wird und die Aufnahme in Schnitt 2 folgt. Der Textblock bleibt unter 4000 Byte.

**Reihenfolge und Risiko des Textes.** Der Text behauptet eine angehängte Aufnahme, die erst Schnitt 2 liefert. Darum läuft
`notizen` erst unmittelbar vor dem Video-Schritt, und es gibt zwischen beiden keine erneute Einreichung (die ist ohnehin
nur nach Hennings Wort). Bis dahin dient `lesen` als Prüfung, ob die Version überhaupt beschreibbar ist.

**Alternativen:**
- Eintragen über die Weboberfläche von App Store Connect, bedient per Claude in Chrome mit Hennings Anmeldung: kein Code,
  keine Wartezeit auf den Merge einer neuen Workflow-Datei. Dagegen: nicht wiederholbar, keine Gegenprobe im Protokoll,
  und die Erweiterung war bei #742 nicht verbunden. Bleibt der Rückfall, falls die API die Notizen im Zustand
  „Information Needed“ verweigert.
- Öffentlicher Video-Link in den Notizen statt Anhang: **verworfen**, er veröffentlichte Hennings echte Aufgabentitel.
- Kein eigenes Skript, `asc_beta_setup.py` erweitern: verworfen, das Skript ist an die Beta-Seite und `betaAppReviewDetail`
  gebunden; die Store-Version ist ein anderes Objekt und eine andere Aktion (kein Schreiben ohne Wunsch).

Keine ADR wird gekippt.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_review_notes.py` (`unittest`, lokaler HTTP-Nachbau mit Zustand wie in `test_asc_beta_setup.py`,
echter `openssl`-Schlüssel im Testordner, Notizdatei im Testordner; Aufruf `python3 scripts/test_asc_review_notes.py`).

- [ ] `test_extracts_first_code_block`: GIVEN Datei mit Text vor, Codeblock, Text und zweitem Codeblock WHEN Extraktion THEN nur der Inhalt des ersten Blocks ohne führende und abschließende Leerzeilen; Datei ohne Codeblock → `Fatal`.
- [ ] `test_limit_4000_bytes_passes`: GIVEN Text mit genau 4000 Byte WHEN `notizen` THEN Exit 0 und ein PATCH.
- [ ] `test_4001_bytes_aborts_before_any_write`: GIVEN 4001 Byte WHEN `notizen` THEN Exit ≠ 0, Meldung mit 4001 und 4000, null Schreibaufrufe, auch kein GET auf die Review-Details nötig.
- [ ] `test_umlauts_count_two_bytes`: GIVEN 2000 mal „ä“ (2000 Zeichen, 4000 Byte) → ok; 2001 mal „ä“ → Abbruch ohne Schreibaufruf.
- [ ] `test_placeholder_aborts`: GIVEN Text mit `<HIER_VIDEO_LINK>` WHEN `notizen` THEN Abbruch, null Schreibaufrufe.
- [ ] `test_same_text_is_unchanged_no_patch`: GIVEN Nachbau mit demselben Text WHEN `notizen` THEN Ausgabe `unverändert`, null Schreibaufrufe, `geschrieben=0`.
- [ ] `test_different_text_exactly_one_patch_then_verified`: GIVEN anderer oder leerer Text WHEN `notizen` THEN genau ein PATCH mit `attributes.notes` gleich Wunschtext, danach `gegenprobe gleich=ja`, zweiter Lauf `unverändert`.
- [ ] `test_lesen_reports_states_and_never_writes`: GIVEN Nachbau mit Version `PREPARE_FOR_SUBMISSION`/`DEVELOPER_REJECTED` o. ä., gesetzten Notizen und zwei Anhängen WHEN `lesen` THEN Zeilen `version 1.0 IOS appStoreState=…`, `notizen gesetzt bytes=…`, je Anhang `name`, `groesse`, `assetDeliveryState`, null Schreibaufrufe.
- [ ] `test_lesen_without_attachments_and_with_empty_notes`: GIVEN `notes` null und keine Anhänge THEN `notizen leer` und `anhang keine`.
- [ ] `test_output_never_contains_notes_text_or_contacts`: GIVEN Nachbau mit Geheimtext in Notizen, Wunschtext und Kontaktfeldern WHEN `lesen` und `notizen` THEN weder Notes-Text noch Kontaktwerte in stdout/stderr.
- [ ] `test_missing_version_has_clear_error`: GIVEN keine Version 1.0 iOS THEN Exit ≠ 0, Meldung „keine iOS-Version 1.0“.
- [ ] `test_missing_review_detail_has_clear_error_and_no_post`: GIVEN Version ohne Review-Detail (404) WHEN `notizen` THEN Exit ≠ 0, eigene Meldung, kein POST/PATCH.
- [ ] `test_patch_refused_has_own_message`: GIVEN PATCH antwortet 409 THEN Exit ≠ 0, Meldung nennt den `appStoreState`, genau ein Versuch.
- [ ] `test_workflow_has_choice_unit_tests_and_secrets`: Workflow-Datei hat `workflow_dispatch`, Eingabe `aktion` mit `lesen` und `notizen`, ruft `test_asc_review_notes.py` vor `asc_review_notes.py` auf und nutzt die drei ASC-Secrets.

## Acceptance Criteria

- **AC-1:** Given der Nachbau mit Version 1.0 iOS, gesetzten Notizen und Anhängen, When `asc_review_notes.py lesen` läuft, Then erscheinen `appStoreState`, Notizen gesetzt/leer samt Bytezahl und je Anhang Dateiname, Größe und `assetDeliveryState`, und es gibt null Schreibaufrufe. Belegt durch `test_lesen_reports_states_and_never_writes`, `test_lesen_without_attachments_and_with_empty_notes`.
- **AC-2:** Given ein Text von genau 4000 Byte, When `notizen` läuft, Then wird er gesetzt; Given 4001 Byte (auch durch Umlaute, die je 2 Byte zählen), Then Abbruch mit Ist- und Sollwert vor jedem Schreibaufruf. Belegt durch `test_limit_4000_bytes_passes`, `test_4001_bytes_aborts_before_any_write`, `test_umlauts_count_two_bytes`.
- **AC-3:** Given der Text im Nachbau ist schon gleich dem Wunschtext, When `notizen` läuft, Then Ausgabe `unverändert` und null Schreibaufrufe. Belegt durch `test_same_text_is_unchanged_no_patch`.
- **AC-4:** Given der Text weicht ab, When `notizen` läuft, Then genau ein PATCH mit `attributes.notes` gleich dem Wunschtext, danach `gegenprobe gleich=ja`; ein zweiter Lauf meldet `unverändert`. Belegt durch `test_different_text_exactly_one_patch_then_verified`.
- **AC-5:** Given `app-review-notizen.md`, When der Text gelesen wird, Then ist es der Inhalt des ersten Codeblocks, und ein Text mit Platzhalter `<HIER_` bricht vor jedem Schreibaufruf ab. Belegt durch `test_extracts_first_code_block`, `test_placeholder_aborts`.
- **AC-6:** Given beliebige Aktion und beliebiger Ausgang (Erfolg, Abbruch, Fehler), When das Protokoll gelesen wird, Then enthält es weder den Notes-Text noch Kontaktdaten. Belegt durch `test_output_never_contains_notes_text_or_contacts`.
- **AC-7:** Given keine Version 1.0 iOS, kein Review-Detail oder ein vom Zustand verweigertes PATCH, When `notizen` oder `lesen` läuft, Then jeweils Exit ≠ 0 mit eigener, erklärender Meldung und ohne anderen Schreibaufruf (insbesondere kein POST zum Anlegen des Details). Belegt durch `test_missing_version_has_clear_error`, `test_missing_review_detail_has_clear_error_and_no_post`, `test_patch_refused_has_own_message`.
- **AC-8:** Given `.github/workflows/asc-review-notes.yml`, When geprüft, Then ist es ein `workflow_dispatch` mit Eingabe `aktion` (`lesen`, `notizen`), nutzt `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, löscht die Schlüsseldatei per `trap` und führt die Unit-Tests vor dem Aufruf aus. Belegt durch `test_workflow_has_choice_unit_tests_and_secrets`.
- **AC-9:** Given der Merge auf `main`, When der Handlauf `lesen` startet, Then zeigt das Lauf-Protokoll den echten Zustand von Version 1.0 (`appStoreState`, Notizen vorher, Anhänge); When danach `notizen` und erneut `lesen` laufen, Then zeigt das Protokoll `notizen gesetzt` mit `gegenprobe gleich=ja` und im zweiten `lesen` `notizen gesetzt bytes=<N>` mit derselben Zahl wie die Datei, ein weiteres `notizen` meldet `unverändert`. Belegt durch die Lauf-Links, die in `docs/reference/testflight.md` eingetragen werden (Abnahme ohne Gerät, siehe unten).
- **AC-10:** Given `docs/reference/app-review-notizen.md`, When geprüft, Then steht dort kein `<HIER_VIDEO_LINK>` mehr, Punkt 1 spricht von der Aufnahme „attached to this submission“, der Textblock hat höchstens 4000 Byte, und der Kopf nennt den neuen Stand. `testflight.md` enthält den Handlauf (Aufruf, Aktionen, Beleg-Lauf-Links). Belegt durch Diff und den Byte-Test in AC-2.

**Abnahmeweg.** Kein Pfad der Geräteliste berührt, es wird kein App-Code geändert. Stufe 2 im Simulator entfällt sinngemäß;
der Beleg ist der echte CI-Lauf nach dem Merge auf `main`: `lesen` vor `notizen`, `notizen`, `lesen` danach, `notizen`
nochmals (unverändert). Die Läufe werden im Abschlussbericht und in `testflight.md` verlinkt.

## Definition of Done

- [ ] Die Tests in `scripts/test_asc_review_notes.py` waren vor der Umsetzung rot und sind danach grün; die bestehenden Python-Tests der `asc_*`-Skripte bleiben grün.
- [ ] Workflow-Datei liegt auf `main`, die vier Läufe aus AC-9 sind in `docs/reference/testflight.md` verlinkt.
- [ ] `app-review-notizen.md` ist ohne Platzhalter und unter 4000 Byte.
- [ ] Der Diff berührt nur die fünf genannten Dateien (kein App-Code, kein `project.yml`, keine `Info.plist`).
- [ ] Ticket #788 bleibt offen für Schnitt 2 (Video) und die Entscheidung über das erneute Einreichen (nur nach Hennings Wort).

## Seiteneffekte

- Schreibt bei Apple ausschließlich das Feld `notes` der App-Review-Informationen von Version 1.0 (iOS), nur bei Abweichung.
- Keine neuen Berechtigungen, keine `Info.plist`, keine AppStorage-Schlüssel, keine Audio-Dateien, kein App-Code.
- Keine neuen Secrets (die drei ASC-Secrets bestehen), keine neue Abhängigkeit (Standardbibliothek und `openssl`).
- Kein Einreichen, keine Nachricht an App Review, kein Eingriff in das Resolution Center.

## Risiken

- **Version evtl. nicht beschreibbar:** Nach „Information Needed“ ist offen, ob `notes` per API änderbar ist. Darum läuft
  `lesen` zuerst; verweigert Apple den PATCH, meldet das Skript den Zustand, und der Rückfall ist die Weboberfläche (Claude
  in Chrome, siehe Alternativen).
- **Anhang-POST kann HTTP 500 liefern** ([Forum 776074](https://developer.apple.com/forums/thread/776074)), der Notizen-PATCH
  lief dort. Betrifft Schnitt 2; Schnitt 1 hängt nicht davon ab.
- **Text verweist auf einen noch nicht vorhandenen Anhang:** siehe „Reihenfolge und Risiko des Textes“.
- **Neuer Workflow erst nach dem Merge startbar:** Der erste echte Lauf kommt nach dem Merge; der Beleg dafür ist bewusst Teil
  der Abnahme, nicht der Tests.
- **`appStoreState` kann bei Apple künftig durch ein anderes Attribut ersetzt sein:** fehlt es, gibt das Skript `?` aus und
  bricht deswegen nicht ab.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebsskript und Handlauf nach dem Muster der bestehenden ASC-Skripte, kippt keine ADR und ändert keine Architektur des Produkts.

## Changelog

- 2026-11-01: Initial spec created (Schnitt 1 von 2; Schnitt 2 = Video-Anhang)
