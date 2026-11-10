---
entity_id: feat-893-schnitt-d-datenschutz
type: feature
created: 2026-11-10
updated: 2026-11-10
status: draft
workflow: feat-893-d-datenschutz
---

# Spec: #893 Schnitt D — Datenschutz-Adresse in den App-Informationen sichtbar machen und setzen

## Approval

- [ ] Approved

Der echte Einreichlauf (2026-11-10, Lauf 42840824572) endete bei iOS mit 409 `STATE_ERROR.ENTITY_STATE_INVALID`. Schnitt C zeigte den Grund: `/v1/appInfoLocalizations/<id>=ENTITY_ERROR.ATTRIBUTE.REQUIRED` — Apple verlangt in einer App-Info-Lokalisierung ein Pflichtfeld, das fehlt. Schnitt D belegt, welches Feld fehlt, setzt es und macht danach den nächsten Einreichversuch möglich. `approved` gibt die Umsetzung frei. Ein Schreibaufruf gegen Apple (und der erneute Einreichlauf) folgt erst nach der Umsetzung, im Rahmen des Auftrags „#893 einreichen“; beides sind keine Aufgaben für Henning.

## Purpose

Ohne die fehlende Pflichtangabe lässt sich Version 1.0.1 nicht einreichen. Fallberichte (Apple-Forum 826478) nennen die Datenschutz-Adresse je Sprache als Pflichtfeld einer Lokalisierung. Das ist bisher **nur eine Hypothese**: Weder `lesen` noch die Store-Probe zeigen `privacyPolicyUrl`, und `asc_beta_setup.py` setzt die Adresse nur an der TestFlight-Beschreibung (`betaAppLocalizations`), nicht an `appInfoLocalizations`. Die en-US-Lokalisierung wurde von `asc_app_info.py` nur mit `locale`, `name`, `subtitle` angelegt.

Schnitt D hat zwei Teile, in dieser Reihenfolge:

1. **Sichtbar machen (nur lesend):** `lesen` zeigt zusätzlich `privacyPolicyUrl` je Sprache. Ein echter `lesen`-Lauf bestätigt oder widerlegt die Hypothese, bevor etwas geschrieben wird.
2. **Setzen:** neue Aktion `datenschutz` setzt die Adresse je Sprache, nur bei Abweichung, nur in die bearbeitbare App-Info, mit Gegenprobe im selben Lauf. Quellen: de-DE = Repo-Variable `ASC_PRIVACY_POLICY_URL`, en-US = `PRIVACY_URL_EN` (Konstante in `asc_beta_setup.py`, überschreibbar per `ASC_PRIVACY_POLICY_URL_EN`, wie dort).

Für Henning ändert sich im Produkt nichts; die Datenschutz-Adresse steht schon öffentlich auf seiner Website (seit 2026-10-27) und wird nur zusätzlich in den Store-Daten hinterlegt. Der Einreichweg von 1.0.1 kommt damit einen Schritt näher.

Nicht in diesem Schnitt (Out of Scope):

- Weitere Pflichtfelder (`privacyChoicesUrl`, Name, Altersfreigabe). Zeigt der Lesebefund oder die erneute Einreichung weitere Gründe, wird daraus ein neuer Befund, nicht geraten.
- Das erneute Einreichen selbst (`asc-store-submit.yml`) bleibt unverändert; es wird nach dem Setzen als eigener Lauf ausgeführt.
- Änderungen an `asc_store_submit.py`, `asc_beta_setup.py` oder dem Datenschutztext.
- **Produktcode:** keiner.

Ohne Modell geht es nicht: nicht relevant. Betriebsskript, Regelweg.

## Source

- **File:** `scripts/asc_app_info.py` (erweitert), `scripts/test_asc_app_info.py` (erweitert), `.github/workflows/asc-app-info.yml` (erweitert)
- **Identifier:** `read_state` (Ausgabe erweitert), neue Funktionen `wanted_privacy` und `write_privacy`, neue Aktion `datenschutz` in `ACTIONS`/`main`; im Test der Nachbau der API (Muster der vorhandenen Tests)
- **Beleg:** `docs/artifacts/feat-893-d-datenschutz/` (Ausgabe des echten `lesen`-Laufs vor dem Setzen, des `datenschutz`-Laufs und des erneuten Einreichlaufs; nur öffentliche Werte)
- **Recherche 2026-11-10:** https://developer.apple.com/forums/thread/826478 (Privacy Policy URL je Lokalisierung als Pflicht, blockiert den Review-Start), https://rxliuli.com/blog/app-store-connect-new-required-fields (neu verlangte Felder, 409 am Submission-Item), https://developer.apple.com/forums/thread/749254. Zur wörtlichen Kombination `ENTITY_ERROR.ATTRIBUTE.REQUIRED` + `appInfoLocalizations` gibt es keinen Treffer; deshalb wird erst gelesen, dann geschrieben.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `localizations`, `editable_info`, `verify`, `send`, `Fatal` (`scripts/asc_app_info.py`) | Modul | Lesen der Lokalisierungen, Auswahl der einen bearbeitbaren App-Info, Gegenprobe und klare Meldungen |
| `asc_locales()` (`scripts/asc_locales.py`) | Modul | die ausgelieferten Sprachen (de-DE, en-US) |
| `PRIVACY_URL_EN` (`scripts/asc_beta_setup.py`) | Konstante | Adresse der englischen Seite |
| `ASC_PRIVACY_POLICY_URL` (Repo-Variable) | Konfiguration | Adresse der deutschen Seite, gesetzt seit 2026-10-27 |
| ASC-API `GET/PATCH /v1/appInfoLocalizations` | extern | Lesen und Setzen von `privacyPolicyUrl` |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_app_info.py | MODIFY | `lesen` gibt `privacyPolicyUrl` je Sprache aus; Aktion `datenschutz` (PATCH nur bei Abweichung, nur bearbeitbare App-Info, Gegenprobe) (ca. +55 LoC) |
| scripts/test_asc_app_info.py | MODIFY | Tests mit nachgestellter API je Regel (ca. +60 LoC) |
| .github/workflows/asc-app-info.yml | MODIFY | `datenschutz` in der Auswahl, `ASC_PRIVACY_POLICY_URL` in der Umgebung (ca. +5 LoC) |

Beleg unter `docs/artifacts/feat-893-d-datenschutz/` kommt mit den echten Läufen.

Nicht betroffen (geprüft): `asc_store_submit.py`, `asc_beta_setup.py`, `asc_locales.py`, `CLAUDE.md` (Aktionsliste dort nennt `asc-app-info` nicht im Einzelnen; falls doch, kurze Ergänzung im selben PR), Produktcode, `project.yml`.

### Estimated Changes
- Dateien: **3** (Grenze 4–5 eingehalten). LoC: ca. **+120**, unter der 250er-Grenze.
- Produktcode: keiner. „Kein Pfad der Geräteliste berührt.“

## Implementation Details

**1. `lesen` zeigt das Feld.** In `read_state` hängt die Zeile je Sprache `datenschutz=<adresse>` an (`-`, wenn leer oder fehlend). Die Adresse ist öffentlich und darf im Protokoll stehen.

**2. Aktion `datenschutz`.** `ACTIONS` erhält `datenschutz`.
- `wanted_privacy()` liefert `{Locale: Adresse}` für jede Sprache aus `asc_locales()`: en-US = `ASC_PRIVACY_POLICY_URL_EN` (gesetzt) sonst `PRIVACY_URL_EN`; de-DE = `ASC_PRIVACY_POLICY_URL` (getrimmt). Eine ausgelieferte Sprache ohne Adresse (z. B. de-DE leer) bricht **vor jeder Anfrage** mit `Fatal` ab: „Datenschutz-Adresse für <Sprache> fehlt, nichts geschrieben“. Die Adresse muss mit `https://` beginnen, sonst ebenfalls Abbruch vor jeder Anfrage.
- `write_privacy(config, info_id, wanted)`: nutzt `editable_info` (nie eine gesperrte oder mehrdeutige App-Info) und `localizations`. Je Sprache: fehlt die Lokalisierung bei Apple, Abbruch mit klarer Meldung (Anlegen ist Sache von `untertitel`, nicht dieses Schnitts); trägt sie schon die gewünschte Adresse, `datenschutz unverändert`, kein Aufruf; sonst genau ein `PATCH /v1/appInfoLocalizations/<id>` mit nur `privacyPolicyUrl`. Danach Gegenprobe über `verify` (jede geschriebene Adresse muss bei Apple stehen), Ausgabe `gegenprobe gleich=ja`.
- Ausgabe `<Sprache> datenschutz gesetzt: <adresse>` und zum Schluss `zusammenfassung geschrieben=<n>`; Ausgang 0, bei `Fatal` Ausgang 1.
- Läuft `datenschutz` ein zweites Mal, schreibt es nichts (`geschrieben=0`).

**3. Nie.** Kein Löschen, kein Einreichen, kein Schreiben in eine gesperrte App-Info, kein anderes Feld als `privacyPolicyUrl`, keine Änderung von Name oder Untertitel, kein Anlegen einer Lokalisierung. Schlüssel, Token und Apples Rohantworten erscheinen nie (Regel des Moduls bleibt).

**4. Workflow.** `asc-app-info.yml` erhält `datenschutz` in der Auswahl und `ASC_PRIVACY_POLICY_URL: ${{ vars.ASC_PRIVACY_POLICY_URL }}` in der Umgebung (öffentlicher Wert, kein Secret); die vorhandenen Unit-Tests laufen weiter vor dem Aufruf.

**5. Echte Läufe (Nachweis, Teil der Definition of Done).** Nach dem Merge, in dieser Reihenfolge: (a) `asc-app-info.yml aktion=lesen` — zeigt, welche Sprache `datenschutz=-` trägt; bestätigt oder widerlegt die Hypothese. Fehlt in keiner Sprache die Adresse, wird **nicht geschrieben**, sondern ein neuer Befund erhoben. (b) Nur bei bestätigter Hypothese `aktion=datenschutz`. (c) `asc-store-submit.yml aktion=einreichen bestaetigung=1.0.1` erneut (verwendet die leere `READY_FOR_REVIEW`-Einreichung wieder, Schnitt B AC-5). Nennt Apple weiter Gründe, gibt Schnitt C sie aus; daraus entsteht ein neuer Befund. Die Ausgaben stehen unter `docs/artifacts/feat-893-d-datenschutz/`.

### Alternativen

| Weg | trägt? | Haken |
|---|---|---|
| **Eigene Aktion `datenschutz`, erst lesen, dann setzen, Gegenprobe (gewählt)** | ja | ein zusätzlicher Handlauf; dafür belegt und wiederholbar |
| A Eintrag im Browser in App Store Connect | ja | nicht wiederholbar, Arbeit weitergereicht (Henning müsste sich anmelden); verworfen |
| B Setzen in `untertitel` einbauen | ja | vermischt zwei Ziele, jeder Untertitel-Lauf schriebe mehr; verworfen |
| C Adresse fest im Skript verdrahten | ja | Doppelpflege neben `ASC_PRIVACY_POLICY_URL`; verworfen (en-US nutzt die vorhandene Konstante) |

Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_app_info.py` (`unittest`, ohne Netz, mit dem vorhandenen API-Nachbau, der um das Feld `privacyPolicyUrl` und PATCH darauf erweitert wird). RED: die Aktion `datenschutz` und die Ausgabe des Feldes gibt es noch nicht.

- [ ] `test_read_shows_privacy_url_per_locale`: GIVEN en-US ohne und de-DE mit Adresse WHEN `lesen` läuft THEN steht `en-US … datenschutz=-` und `de-DE … datenschutz=<adresse>`, kein Schreibaufruf.
- [ ] `test_privacy_patches_only_differing_locales`: GIVEN en-US ohne Adresse, de-DE mit der richtigen WHEN `datenschutz` läuft THEN genau ein PATCH (en-US, nur `privacyPolicyUrl`), de-DE „unverändert“, Gegenprobe gleich, Ausgang 0.
- [ ] `test_privacy_second_run_writes_nothing`: GIVEN beide Adressen gesetzt WHEN `datenschutz` läuft THEN `geschrieben=0`, kein Schreibaufruf.
- [ ] `test_privacy_refuses_locked_or_ambiguous_info`: GIVEN keine oder zwei App-Infos in `PREPARE_FOR_SUBMISSION` WHEN `datenschutz` läuft THEN Abbruch mit Meldung, kein Schreibaufruf, Ausgang 1.
- [ ] `test_privacy_missing_or_bad_address_stops_before_any_request`: GIVEN `ASC_PRIVACY_POLICY_URL` leer bzw. ohne `https://` WHEN `datenschutz` läuft THEN Abbruch vor jeder Anfrage, Ausgang 1.
- [ ] `test_privacy_missing_localization_not_created`: GIVEN en-US-Lokalisierung fehlt bei Apple WHEN `datenschutz` läuft THEN Abbruch mit Meldung, kein POST, Ausgang 1.
- [ ] `test_privacy_verify_detects_mismatch`: GIVEN der Nachbau übernimmt den PATCH nicht WHEN `datenschutz` läuft THEN meldet die Gegenprobe die Abweichung, Ausgang 1.
- [ ] `test_privacy_writes_only_privacy_field_and_leaks_nothing`: GIVEN ein Lauf mit Geheimwerten in Schlüssel und Antworten WHEN `datenschutz` läuft THEN enthält der PATCH-Rumpf nur `privacyPolicyUrl`, die Ausgabe nie einen Geheimwert.

Die bestehenden Tests zu `lesen` und `untertitel` laufen unverändert mit (die erweiterte `lesen`-Zeile darf sie nicht brechen; wo sie die Zeile wörtlich prüfen, wird die Erwartung um das neue Feld ergänzt, der Test bleibt sonst gleich).

## Acceptance Criteria

- **AC-1:** Given Lokalisierungen mit und ohne Datenschutz-Adresse, When `lesen` läuft, Then zeigt die Ausgabe je Sprache `datenschutz=<adresse>` oder `datenschutz=-`, und es gibt keinen Schreibaufruf. Belegt durch `test_read_shows_privacy_url_per_locale`.
- **AC-2:** Given eine Sprache mit abweichender oder fehlender Adresse, When `datenschutz` läuft, Then gibt es je abweichender Sprache genau einen PATCH mit nur `privacyPolicyUrl`, bei gleicher Adresse keinen Aufruf, danach `gegenprobe gleich=ja`. Belegt durch `test_privacy_patches_only_differing_locales`.
- **AC-3:** Given bereits gesetzte Adressen, When `datenschutz` ein zweites Mal läuft, Then ist `geschrieben=0` und es gibt keinen Schreibaufruf. Belegt durch `test_privacy_second_run_writes_nothing`.
- **AC-4:** Given keine oder mehrere bearbeitbare App-Infos, When `datenschutz` läuft, Then bricht es ohne Schreibaufruf mit Ausgang 1 ab. Belegt durch `test_privacy_refuses_locked_or_ambiguous_info`.
- **AC-5:** Given eine fehlende oder nicht-https Adresse, When `datenschutz` läuft, Then bricht es vor jeder Anfrage mit Ausgang 1 ab. Belegt durch `test_privacy_missing_or_bad_address_stops_before_any_request`.
- **AC-6:** Given eine bei Apple fehlende Lokalisierung, When `datenschutz` läuft, Then legt es nichts an (kein POST) und bricht mit Ausgang 1 ab. Belegt durch `test_privacy_missing_localization_not_created`.
- **AC-7:** Given ein Apple, das den Wert nicht übernimmt, When `datenschutz` läuft, Then schlägt die Gegenprobe mit Ausgang 1 an. Belegt durch `test_privacy_verify_detects_mismatch`.
- **AC-8:** Given ein Lauf mit Geheimwerten in Umgebung und Antworten, When `datenschutz` läuft, Then schreibt es nur das Feld `privacyPolicyUrl` und gibt nie Schlüssel, Token oder Rohantworten aus. Belegt durch `test_privacy_writes_only_privacy_field_and_leaks_nothing`.
- **AC-9:** Given die bestehenden Tests zu `lesen` und `untertitel`, When der Skripttest läuft, Then bleiben alle grün. Belegt durch `python3 scripts/test_asc_app_info.py`.

**Abnahmeweg.** Stufe 1: Python-Tests (AC-1 bis AC-9). Stufe 2: die echten Läufe nach dem Merge (siehe Implementation Details 5 und Definition of Done; kein AC, weil erst nach dem Merge erfüllbar). Stufe 3 greift nicht; auf Hennings Geräten läuft nichts.

## Definition of Done

- [ ] Die Tests waren vor dem Skript vorhanden (RED) und sind danach grün; die übrigen Skript-Tests bleiben grün.
- [ ] PR gemergt, CI grün.
- [ ] Echter Lauf `lesen` belegt, welche Sprache(n) die Adresse nicht tragen (Beleg unter `docs/artifacts/feat-893-d-datenschutz/`); nur bei bestätigter Hypothese lief `datenschutz` einmal, mit Gegenprobe gleich.
- [ ] `einreichen` mit `bestaetigung=1.0.1` lief erneut; der Ausgang ist belegt. Nennt Apple weitere Gründe, ist daraus ein Befund bzw. ein Folgeschnitt entstanden; #893 bleibt bis zur Einreichung beider Plattformen offen und wird erst nach `WAITING_FOR_REVIEW` geschlossen.

## Seiteneffekte

- Geänderte Dateien: die drei oben; Beleg unter `docs/artifacts/feat-893-d-datenschutz/`.
- Bei Apple: der spätere `datenschutz`-Lauf schreibt die bereits öffentliche Datenschutz-Adresse in die bearbeitbare App-Info (höchstens ein PATCH je Sprache), nichts wird gelöscht oder eingereicht.
- Keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.

## Risiken

- **Hypothese falsch.** Gegenmaßnahme: Schritt (a) ist rein lesend; stimmt der Befund nicht, wird nicht geschrieben und die Ursache neu erhoben (Schnitt C liefert bei jeder Ablehnung die Gründe).
- **Falsche Adresse im Store.** Gegenmaßnahme: Quellen sind die schon freigegebenen Adressen (Variable, Konstante), https-Pflicht, Gegenprobe, Wiederholung jederzeit per PATCH korrigierbar.
- **API-Form von `privacyPolicyUrl`.** Das Attribut liegt laut Apple an der Lokalisierung; bestätigt erst der echte Lauf. Weicht die Antwort ab (z. B. 409 am PATCH), gibt `send` die Codes aus und der Lauf bricht ab, ohne Schaden.

## Known Limitations

- Weitere Pflichtangaben (z. B. Altersfreigabe) erkennt das Werkzeug nicht vorab; sie zeigen sich erst als Gründe einer Ablehnung.
- Das Anlegen einer fehlenden Lokalisierung gehört weiter zu `untertitel`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebsskript für Store-Daten, ohne Produktcode; es wird keine bestehende ADR gekippt.
- **Rationale:** Erst lesen, dann schreiben macht die Ursache zu einem Befund statt zu einer Vermutung; eine eigene Aktion hält Untertitel und Datenschutz getrennt.

## Changelog

- 2026-11-10: Initial spec created (Schnitt D von #893: `privacyPolicyUrl` in `lesen` sichtbar, Aktion `datenschutz` setzt sie je Sprache mit Gegenprobe)
