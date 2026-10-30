---
entity_id: feat-705-schnitt-2b2c-oeffentlicher-link
type: feature
created: 2026-10-30
updated: 2026-10-30
status: draft
workflow: feature-705-oeffentlicher-link
---

# Spec: #705 Schnitt 2b-2c „Öffentlicher Link“: den Einladungslink der Gruppe `Tester` (Limit 50) per Handlauf ein- und ausschalten

## Approval

- [ ] Approved

## Purpose

Apple hat Build 125 für externe Tester freigegeben (iOS mit Watch und macOS, `extern=BETA_APPROVED`, Einreichung `APPROVED`,
gemessen am 2026-10-30, Lauf 41019692346). Die Gruppe `Tester` besteht, ihr Link ist aus (`link=aus`). Es fehlt der Schritt, der
den öffentlichen Einladungslink einschaltet, damit bis zu 50 Fremde die App installieren können.

Schnitt 2b-2c liefert ihn als eigenen Handlauf: `asc-beta.yml` bekommt die Wahlen `link` und `link-aus`, beide rufen das neue Skript
`scripts/asc_beta_link.py` (`--aus` für den Rückweg). Es ist rücknehmbar (der Link lässt sich per PATCH wieder abschalten), wirkt aber
nach außen. Deshalb:

- Der **echte Lauf** steht nicht als AC, sondern in der Definition of Done und läuft **nur nach Hennings ausdrücklichem Wort**.
- Der Link wird nie ohne Limit eingeschaltet: Weicht das Limit nach dem Einschalten von 50 ab, schaltet das Skript den Link sofort
  wieder aus und endet mit Fehler.
- Das Skript druckt den Link nie. Henning holt ihn in App Store Connect (Gruppe `Tester`). Das Repo und seine Lauf-Logs sind öffentlich.
- Vorbedingung des echten Laufs ist #743 (die Probe zeigt `url=` sonst unmaskiert).

Ohne Modell: Schnittstellenaufruf mit Vorbedingungsprüfung, kein Modellweg.

## Source

- **Neues Skript:** `scripts/asc_beta_link.py`. Es nutzt `plan_group`, `read_extern`, `message`, `Masked`, `FORBIDDEN` aus
  `scripts/asc_beta_invite.py` (importiert, unverändert) und die geteilten Helfer `read_config`, `find_app_id`, `get_json`,
  `platform_filter`, `Fatal` (`asc_wait_build.py`) sowie `get_data`, `send_json` (`asc_what_to_test.py`).
- **Lesen:** `GET /v1/apps/<App>/betaGroups` (Attribute `publicLinkEnabled`, `publicLinkLimitEnabled`, `publicLinkLimit`),
  `GET /v1/builds?filter[app]=…&filter[processingState]=VALID&filter[expired]=false&sort=-uploadedDate&limit=1` je Plattform,
  `GET /v1/betaGroups/<Gruppe>/relationships/builds?limit=200`, `GET /v1/builds/<Build>/buildBetaDetail` (`externalBuildState`).
- **Schreiben:** `PATCH /v1/betaGroups/<Gruppe>` mit
  `{"data":{"type":"betaGroups","id":<Gruppe>,"attributes":{"publicLinkEnabled":true,"publicLinkLimitEnabled":true,"publicLinkLimit":50}}}`;
  zum Ausschalten `{"publicLinkEnabled":false}`.
- **Quellen:** Apple „Modify a beta group … including changing its TestFlight public link status“
  (https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-betagroups-_id_); Attributnamen aus Apples Beispielantwort und
  Fastlane `create_beta_group`. **Nicht belegt** (Apples Attributseite war nicht abrufbar): ob `publicLinkLimit` und
  `publicLinkLimitEnabled` in einem PATCH zusammen genommen werden und ob die Schlüsselrolle ausreicht. Das Skript fängt Abweichungen
  ab (siehe Implementation Details); der echte Lauf klärt es. Rückfall ist die Oberfläche von App Store Connect.
- **Beleg:** `scripts/asc_beta_probe.py` (`gruppe name=Tester … link=an`), unverändert.
- **Identifier:** keiner neu im Datenmodell. Skript-Schalter `--aus`, Workflow-Wahlen `link` und `link-aus`, Job `link`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| 2b-1 und 2b-2b (erledigt) | Zustand bei Apple | Gruppe `Tester`, Build 125 zugeordnet, Beta-Review `APPROVED` |
| Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | Repo-Secrets | API-Zugang (nie als Eingabe, das Repo ist öffentlich) |
| `scripts/test_asc_beta_invite.py` (`FakeASC`) | Test | Nachbau mit Zustand; der neue Test baut eigene, schlanke Routen |
| #743 | Ticket | Probe maskiert `url=`; **Vorbedingung des echten Laufs**, nicht des Codes |
| #724 (offen) | Ticket | neue Builds automatisch zuordnen; der Link gilt nur für freigegebene Builds der Gruppe |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_beta_link.py | CREATE | Link ein-/ausschalten: Vorbedingungen lesen, höchstens ein PATCH zum Einschalten, Gegenlesen, bei Abweichung zurückschalten; Ausgabe nur Zustandswörter |
| scripts/test_asc_beta_link.py | CREATE | Tests gegen einen lokalen Nachbau (Zustand, Anfragenliste) und die Workflow-Datei |
| .github/workflows/asc-beta.yml | MODIFY | Wahlen `link` und `link-aus`, Job `link`; `probe` hängt per `needs` auch an `link`; Kopfkommentar |
| scripts/test_asc_beta_invite.py | MODIFY | `test_workflow_file`: `needs: [setup, assign, submit, link]` und `needs.link.result` statt der alten Zeichenfolgen (3 Zeilen) |
| docs/reference/testflight.md | MODIFY | Prüfliste: „Beta-Review“ auf `APPROVED` (Beleg Lauf 41019692346), Zeile „Öffentlicher Link“, Absatz Handlauf `link` |

Unverändert: `scripts/asc_beta_invite.py` (seine Zusage „nie Link, nie PATCH“ gilt für `zuordnen`/`einreichen` weiter),
`scripts/asc_beta_probe.py` (#743), `CLAUDE.md`.

### Estimated Changes

5 Dateien, ca. +245/−3 LoC (Skript ~85, Test ~120, Workflow ~18, Invite-Test 3, Doku ~20). Funktionen je ≤ 50 LoC.
**Kein Pfad der Geräteliste berührt.** (Nur `scripts/`, Workflow-Datei und Doku; kein App-Code, kein `project.yml`, keine `Info.plist`.)

## Implementation Details

### 1. Skript `asc_beta_link.py`

Aufruf `asc_beta_link.py [--aus]`, Umgebung wie `asc_beta_invite.py`. `sys.stdout` läuft durch `Masked`.

`main` liest Konfiguration, App und die Gruppenliste; die externe Gruppe `Tester` kommt aus `plan_group`. Fehlt sie, endet der Lauf
vor jedem Schreiben mit `::error::` und Exit 1.

**Einschalten (ohne `--aus`).** `plan_link(group, readiness)` ist rein:

| Lage | Plan | Ausgabezeile |
|------|------|--------------|
| Link an, Limit an, Limit = 50 | kein PATCH | `link zustand=vorhanden limit=50` |
| mindestens eine Plattform: neuester gültiger Build nicht in der Gruppe oder `externalBuildState != BETA_APPROVED` (auch `unbekannt`) | kein PATCH | `link zustand=nicht-bereit plattform=<P> extern=<Wert>` |
| alle Plattformen mit gültigem Build bereit, sonst Link aus oder Limit abweichend | ein PATCH | siehe unten |

Eine Plattform ohne gültigen Build zählt nicht als Hindernis (`link plattform=<P> zustand=kein-gültiger-build`); gibt es auf
keiner Plattform einen gültigen Build, ist es `nicht-bereit`.

Nach dem PATCH liest das Skript die Gruppe erneut. Gilt `publicLinkEnabled == true`, `publicLinkLimitEnabled == true` und
`publicLinkLimit == 50`: `link zustand=eingeschaltet limit=50`, Exit 0. In jedem anderen Fall (Limit abweichend, Feld fehlt, Antwort
nicht lesbar) sendet das Skript einen zweiten PATCH mit `publicLinkEnabled=false`, druckt `link zustand=abgebrochen grund=limit`
und endet mit Exit 1. Es ist nie ein Link ohne bestätigtes Limit draußen.

**Ausschalten (`--aus`).** Ist der Link an: ein PATCH mit `publicLinkEnabled=false`, `link zustand=ausgeschaltet`. Ist er aus:
kein PATCH, `link zustand=vorhanden aus`. Vorbedingungen für das Ausschalten gibt es keine.

**Fehler.** 403 → `FORBIDDEN`; andere 4xx → `::error::<message(error)>`; alle Exit 1. Der PATCH wird bei 4xx nicht wiederholt
(`send_json` wiederholt nur 5xx, 408, 429). Die Schlusszeile `zusammenfassung geschrieben=<n>` zählt PATCH-Aufrufe (ein Zurückschalten
zählt mit).

**Ausgabe.** Nur Zustandswörter: nie der Link (`publicLink`), nie IDs, nie Buildnummern.

### 2. Workflow `asc-beta.yml`

- `inputs.aktion` bekommt `link` und `link-aus`; Beschreibung: „link = öffentlichen Link einschalten (Limit 50, nur nach Hennings Wort), link-aus = wieder ausschalten“.
- Job `link` nach dem Muster von `submit`: `if: ${{ !cancelled() && (inputs.aktion == 'link' || inputs.aktion == 'link-aus') }}`,
  `needs: setup`, `ubuntu-latest`, `timeout-minutes: 10`, gleiche Secrets, Schlüsseldatei mit `umask 077` und `trap rm`; zwei Schritte
  mit `if` je Aktion, einer ruft `python3 scripts/asc_beta_link.py`, der andere `python3 scripts/asc_beta_link.py --aus`.
- `probe`: `needs: [setup, assign, submit, link]` und die `if`-Bedingung um `needs.link.result` (`success` oder `skipped`) ergänzt,
  damit die Probe nach dem Link-Lauf liest.
- Die Datei nennt weiter weder `publicLinkEnabled` noch `betaAppReviewSubmissions`; nur `aktion` als Eingabe, kein `push`, `schedule`, `workflow_run`.

### 3. Doku

`docs/reference/testflight.md`: Zeile „Beta-Review (Einreichung)“ → `APPROVED` mit Beleg Lauf 41019692346 (iOS und macOS, Build
125); Zeile „Öffentlicher Link“ bleibt `offen`, bis der echte Lauf belegt ist, und verweist auf #743 als Vorbedingung; neuer Absatz
Handlauf `link` / `link-aus` mit erwarteten Zeilen, dem Hinweis „nur nach Hennings Wort“ und dem Rückfall über App Store Connect.

### Alternativen

**Link von Hand in App Store Connect einschalten** (Gruppe `Tester` → Öffentlichen Link aktivieren, Limit 50). Zwei Minuten, kein
Code, kein Log-Thema. Verworfen als Hauptweg, weil nicht belegt, nicht wiederholbar und nicht per Probe prüfbar; bleibt der
**Rückfall**, falls Apple das Limit per Schlüssel nicht annimmt. **Link gar nicht nutzen, Tester einzeln einladen:** vorsichtiger,
widerspricht aber der Definition of Done von #705 („Einladungslink“); Entscheidung liegt bei Henning. **Skript `asc_beta_invite.py`
erweitern:** verworfen, weil seine Zusage „nie Link, nie PATCH“ und deren Tests sonst fallen. Keine ADR wird gekippt.

## Test Plan

### Automated Tests

Alle Tests laufen gegen einen lokalen Nachbau in `scripts/test_asc_beta_link.py` (`python3 scripts/test_asc_beta_link.py`): ein
HTTP-Server mit Zustand (Gruppe mit `publicLink*`-Attributen, zugeordnete Builds, `externalBuildState` je Build), der PATCH auf die
Gruppe annimmt, sich die Anfragen merkt und über einen Schalter das Limit ignoriert oder 403/422 liefert.

- [ ] `test_not_ready_build_is_not_enabled`: `externalBuildState` ist `READY_FOR_BETA_SUBMISSION`, `PROCESSING` oder nicht lesbar →
  kein PATCH, `link zustand=nicht-bereit plattform=… extern=…`, Exit 0.
- [ ] `test_build_missing_in_group_is_not_ready`: neuester gültiger Build liegt nicht in der Gruppe → kein PATCH, `nicht-bereit`.
- [ ] `test_enable_sends_one_patch_with_limit_50`: beide Plattformen `BETA_APPROVED` → genau ein PATCH mit
  `publicLinkEnabled=true`, `publicLinkLimitEnabled=true`, `publicLinkLimit=50`, danach Gegenlesen; Zeile `link zustand=eingeschaltet limit=50`; Exit 0.
- [ ] `test_second_run_writes_nothing`: zweiter Lauf → kein PATCH, `link zustand=vorhanden limit=50`, `zusammenfassung geschrieben=0`.
- [ ] `test_limit_mismatch_switches_back_off`: der Nachbau ignoriert das Limit → zweiter PATCH mit `publicLinkEnabled=false`,
  `link zustand=abgebrochen grund=limit`, Exit 1; am Ende ist der Link im Nachbau aus.
- [ ] `test_unreadable_readback_switches_back_off`: das Gegenlesen schlägt fehl → derselbe Rückweg.
- [ ] `test_off_switches_link_off_and_is_idempotent`: `--aus` bei eingeschaltetem Link → ein PATCH, `link zustand=ausgeschaltet`; zweiter Lauf → kein PATCH, `vorhanden aus`.
- [ ] `test_missing_group_aborts_before_any_write`: keine Gruppe `Tester` → `::error::`, kein PATCH, Exit 1.
- [ ] `test_forbidden_and_other_errors_are_reported`: 403 → Text „Schlüssel ohne Schreibrecht“, 422 → `::error::`, beide Exit 1, kein zweiter Versuch.
- [ ] `test_output_has_only_state_words`: Ausgabe (stdout und stderr) enthält weder den Link noch Gruppen-, App- oder Build-IDs, Buildnummern, Schlüsselmaterial.
- [ ] `test_workflow_file`: Wahlen `- link` und `- link-aus`, Job `link` mit `scripts/asc_beta_link.py`, `umask 077`, `rm -f`,
  `runs-on: ubuntu-latest`, `inputs.aktion == 'link'`; `probe` mit `needs.link.result`; `workflow.count("inputs.") == workflow.count("inputs.aktion")`;
  Datei enthält weder `publicLinkEnabled` noch `betaAppReviewSubmissions`, kein `push:`, `schedule:`, `workflow_run:`;
  `testflight.yml` nennt `asc_beta_link` nicht.
- [ ] `test_invite_script_untouched`: `asc_beta_invite.py` enthält weiter kein `PATCH` und kein `publicLink`-Schreiben (Zeichenprüfung der Datei), seine bestehenden Tests laufen unverändert.
- [ ] `test_testflight_doc_lists_link_row`: `docs/reference/testflight.md` enthält die Prüflistenzeile „Beta-Review“ mit `APPROVED` und dem Beleg `41019692346`, die Zeile „Öffentlicher Link“ mit `offen` und `#743`, und den Abschnitt zum Handlauf `aktion=link` samt `link-aus`.
- [ ] `test_workflow_file` in `test_asc_beta_invite.py` (angepasst): die drei geänderten Zeichenfolgen `needs: [setup, assign, submit, link]`, `needs.link.result` und der unveränderte Rest bleiben grün.

Regression: alle übrigen `python3 scripts/test_*.py` grün (Gate der Definition of Done).

### Echte Aufrufe (nach dem Merge, nicht Teil der ACs)

Siehe Definition of Done: ein Lauf `aktion=link` auf `main`, **nur nach Hennings ausdrücklichem Wort** und erst nach Merge von #743.

## Acceptance Criteria

- **AC-1:** Das Skript schaltet den Link nicht ein, solange der neueste gültige Build einer Plattform nicht in der Gruppe `Tester` liegt
  oder nicht `BETA_APPROVED` ist (auch nicht lesbar): kein PATCH, Zeile `link zustand=nicht-bereit …`, Exit 0. Geprüft durch
  `test_not_ready_build_is_not_enabled` und `test_build_missing_in_group_is_not_ready`.
- **AC-2:** Sind alle Vorbedingungen erfüllt, sendet es genau einen PATCH auf die Gruppe mit `publicLinkEnabled=true`,
  `publicLinkLimitEnabled=true`, `publicLinkLimit=50`, liest die Gruppe erneut und meldet `link zustand=eingeschaltet limit=50`,
  Exit 0. Geprüft durch `test_enable_sends_one_patch_with_limit_50`.
- **AC-3:** Ein zweiter Lauf schreibt nichts: kein PATCH, `link zustand=vorhanden limit=50`, `zusammenfassung geschrieben=0`.
  Geprüft durch `test_second_run_writes_nothing`.
- **AC-4:** Es bleibt nie ein Link ohne bestätigtes Limit 50 eingeschaltet: stimmt das Limit nach dem PATCH nicht oder ist das
  Gegenlesen nicht möglich, folgt ein zweiter PATCH mit `publicLinkEnabled=false`, die Zeile `link zustand=abgebrochen grund=limit`
  und Exit 1. Geprüft durch `test_limit_mismatch_switches_back_off` und `test_unreadable_readback_switches_back_off`.
- **AC-5:** `--aus` schaltet einen eingeschalteten Link mit einem PATCH ab (`link zustand=ausgeschaltet`), bei ausgeschaltetem Link
  gibt es keinen PATCH (`link zustand=vorhanden aus`). Geprüft durch `test_off_switches_link_off_and_is_idempotent`.
- **AC-6:** Fehlt die externe Gruppe `Tester`, endet der Lauf mit `::error::` und Exit 1 vor jedem Schreiben. Geprüft durch
  `test_missing_group_aborts_before_any_write`.
- **AC-7:** Bei 403 steht der bestehende Text „Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen“
  in der Ausgabe, bei anderen 4xx eine `::error::`-Zeile; beide Exit 1, der PATCH wird nicht wiederholt. Geprüft durch
  `test_forbidden_and_other_errors_are_reported`.
- **AC-8:** Die Ausgabe (stdout und stderr) enthält nur Zustandswörter: nie den Einladungslink, keine Gruppen-, App- oder
  Build-IDs, keine Buildnummern, kein Schlüsselmaterial. Geprüft durch `test_output_has_only_state_words`.
- **AC-9:** `.github/workflows/asc-beta.yml` bietet `link` und `link-aus` an; der Job `link` ruft `scripts/asc_beta_link.py` (bei
  `link-aus` mit `--aus`) nur bei der jeweiligen Wahl auf (Schlüssel mit `umask 077` und `trap rm`, `ubuntu-latest`); `probe`
  hängt per `needs` auch an `link`; es gibt nur die Eingabe `aktion` und keinen `push`-, `schedule`- oder `workflow_run`-Auslöser;
  die Datei nennt `publicLinkEnabled` und `betaAppReviewSubmissions` nicht; `testflight.yml` nennt das Skript nicht. Geprüft durch
  `test_workflow_file` (neu) und den angepassten `test_workflow_file` in `test_asc_beta_invite.py`.
- **AC-10:** `asc_beta_invite.py` bleibt unverändert und enthält weiter kein PATCH und kein Schreiben von `publicLink*`; `zuordnen`
  und `einreichen` können den Link nicht einschalten. Geprüft durch `test_invite_script_untouched` und `git diff --stat`.
- **AC-11:** `docs/reference/testflight.md` führt „Beta-Review“ als `APPROVED` mit Beleg Lauf 41019692346, die Zeile „Öffentlicher
  Link“ als `offen` mit Verweis auf #743 und den Handlauf `link` samt Rückfall über App Store Connect. Geprüft durch
  `test_testflight_doc_lists_link_row`.

Umfang und Gesamtlauf (alle `python3 scripts/test_*.py` grün; Diff höchstens die fünf Dateien der Tabelle, ±250 LoC, kein Pfad der
Geräteliste) sind ein Gate der Definition of Done, kein AC.

Kein Pfad der Geräteliste berührt. Abnahmestufe: Skripttests; es gibt keine App-Änderung, also weder Simulator- noch Geräteschritt.

## Out of Scope

- **Maskieren von `url=` in der Probe:** #743, vor dem echten Lauf.
- **Der echte Lauf selbst:** kein AC, siehe Definition of Done.
- **Automatische Zuordnung neuer Builds und neue Beta-Prüfung je Build:** #724.
- **Weitergabe des Links an Tester** und die Auswahl der Tester: Henning, nach dem Lauf.
- **Änderungen an Beschreibung, Kontakt, Datenschutz-URL, Gruppe, Einreichung** und an `testflight.yml`, `CLAUDE.md`.
- **Test auf Hennings Geräten:** nichts; kein Gerätepfad berührt.

## Definition of Done

- [ ] Skript, Tests, Workflow und Doku umgesetzt und per PR gemergt; AC-1 bis AC-11 erfüllt.
- [ ] Gate: alle `python3 scripts/test_*.py` grün; `git diff --stat` zeigt höchstens die fünf Dateien der Tabelle, ±250 LoC, keinen Pfad der Geräteliste.
- [ ] #743 (Probe maskiert `url=`) ist gemergt, **bevor** der echte Lauf startet.
- [ ] **Echter Lauf `aktion=link` auf `main`: erst nach Hennings ausdrücklichem Wort** (Link wirkt nach außen; Frage per
  AskUserQuestion mit Kontext). Vorher prüft `aktion=probe` den Stand: beide Builds `BETA_APPROVED`, `link=aus`.
- [ ] Nach dem Lauf: Probe desselben Laufs zeigt `gruppe name=Tester … link=an`, `url=gesetzt` (nie der Link); ein zweiter Lauf
  bestätigt `vorhanden` und `geschrieben=0`. Lauf-Links in #705 und in der Prüfliste; die Zeile „Öffentlicher Link“ wechselt erst dann von `offen`.
- [ ] Weist Apple den PATCH ab (403, 422 oder Limit nicht übernommen): Henning bekommt in Alltagssprache den Rückfall (Link in App
  Store Connect einschalten, Limit 50) statt einer Befehlszeile; der Fall wird in #705 festgehalten.
- [ ] Henning bekommt den Einladungslink in Alltagssprache (Fundort in App Store Connect). Kommentar in #705; das Ticket bleibt offen
  (`Refs #705`) bis der Löschhinweis aus dem Gerätedurchgang gegengelesen ist.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: neues Handlauf-Skript samt Workflow-Wahl für einen Apple-Schalter; keine Produktarchitektur, kein App-Code, keine Änderung an einer ADR.

## Changelog

- 2026-10-30: Initial spec created
