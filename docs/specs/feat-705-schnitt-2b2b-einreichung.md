---
entity_id: feat-705-schnitt-2b2b-einreichung
type: feature
created: 2026-10-28
updated: 2026-10-28
status: draft
workflow: feat-705-s2b2b-einreichung
---

# Spec: #705 Schnitt 2b-2b „Einreichung“: die der Gruppe `Tester` zugeordneten Builds (iOS mit Watch, macOS) einmal zum Beta-App-Review einreichen

## Approval

- [ ] Approved

## Purpose

Für die erste externe TestFlight-Einladung muss Apple den Build der Gruppe `Tester` einmal im Beta-App-Review freigeben. Bis hier
ist alles Vorbereitende erledigt und per Probe belegt: Beschreibung, Feedback-E-Mail und Review-Kontakt (2a), die externe Gruppe
`Tester` mit dem neuesten gültigen Build je Plattform und `externalBuildState=READY_FOR_BETA_SUBMISSION` (2b-1), die
Datenschutz-URL (2b-2a). Die Probe zeigt weiter `einreichung keine`. Es fehlt der Schritt selbst.

Schnitt 2b-2b fügt ihn als eigenen Handlauf hinzu: `asc-beta.yml` bekommt die Wahl `aktion=einreichen`. Der Lauf ordnet wie
`zuordnen` den neuesten gültigen Build je Plattform der Gruppe zu und reicht genau diesen Build ein
(`POST /v1/betaAppReviewSubmissions`, Rumpf nur die Beziehung `build`; Apple antwortet mit `betaReviewState`, anfangs
`WAITING_FOR_REVIEW`). Die Probe desselben Laufs ist der Beleg.

**Plattformen.** Eingereicht wird je Plattform ein eigener Build, also je Plattform eine Einreichung:

- **iOS** (Henning, 2026-10-28: „iPhone/iPad und Mac und Apple Watch“). Der iOS-Build deckt iPhone, iPad **und die eingebettete
  Watch-App** ab (`project.yml`: `LooseEndsWatch` mit `platformFilter: iOS` im iOS-Build eingebettet; `testflight.yml` prüft
  `com.henning.looseends.watchkitapp` im iOS-Archiv). Es gibt **keine eigene watchOS-Einreichung** und keine dritte Plattform im
  Skript.
- **macOS** (`MAC_OS`).

Eine Plattform verdeckt die andere nicht: Fehler oder „nicht bereit“ auf der einen lassen die andere weiterlaufen.

**Unumkehrbar.** Apples OpenAPI kennt für `/v1/betaAppReviewSubmissions` nur GET und POST; eine Einreichung lässt sich per API
nicht zurückziehen, und eine Ablehnung kostet einen Review-Zyklus von Stunden bis Tagen. Deshalb gilt:

- Ohne den Schalter `--einreichen` sendet das Skript nie einen POST auf `betaAppReviewSubmissions`. `zuordnen`, `probe` und
  `einrichten` bleiben so ausgeschlossen; `asc-beta.yml` nennt den Pfad weiterhin nirgends.
- Der **echte Lauf** bei Apple steht nicht als AC, sondern in Definition of Done / Abnahme, und läuft **nur nach Hennings
  ausdrücklicher Freigabe** (Gate-Kreis aus 2b-2a: ein AC „echter Lauf“ sperrt in 6b den Commit, obwohl der Lauf erst nach dem
  Merge möglich und erlaubt ist).

Ohne Modell: API-Aufruf mit Vorbedingungsprüfung, kein Modellweg.

## Source

- **Skript (erweitert):** `scripts/asc_beta_invite.py` (Gruppe, Zuordnung `assign_platform`, `apply_plan`, `message()`, `Masked`,
  `FORBIDDEN`). Neu: Schalter `--einreichen`, Funktionen `plan_submission` und `submit_platform`, Zustandswörter der Einreichung.
- **Geteilte Helfer, unverändert:** `asc_wait_build.py` (`read_config`, `find_app_id`, `get_json`, `platform_filter`, `Fatal`),
  `asc_what_to_test.py` (`get_data`, `send_json`).
- **Lesen für die Vorbedingung:** `GET /v1/betaAppReviewSubmissions?filter[build]=<Build>` (dieselbe Abfrage nutzt
  `scripts/asc_beta_probe.py`) und `GET /v1/builds/<Build>/buildBetaDetail` (`externalBuildState`, in `assign_platform` schon gelesen).
- **Schreiben:** `POST /v1/betaAppReviewSubmissions` mit
  `{"data":{"type":"betaAppReviewSubmissions","relationships":{"build":{"data":{"type":"builds","id":<Build>}}}}}`.
  Quellen: Apple-Dokumentation zu „Create a Beta App Review Submission“, Forenbeitrag https://developer.apple.com/forums/thread/852029
  (Rumpf), thread/841564 (nur `builds` als Beziehung).
- **Fehlerbilder (Foren):** 422 `ENTITY_UNPROCESSABLE.BETA_CONTRACT_MISSING` (Beta-Vereinbarung fehlt), 409 bei schon bestehender
  Einreichung oder Zustandskonflikt (thread/849771, 841564), 403 bei fehlender Rolle.
- **Beleg:** `scripts/asc_beta_probe.py` (Zeilen `einreichung build=… zustand=…`), unverändert.
- **Identifier:** keiner neu — Skript-Schalter `--einreichen`, Workflow-Wahl `einreichen`, Job `submit`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| 2a, 2b-1, 2b-2a (erledigt) | Zustand bei Apple | Beschreibung, Kontakt, Gruppe `Tester`, Datenschutz-URL |
| Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | Repo-Secrets | API-Zugang (nie als Dispatch-Eingabe, das Repo ist öffentlich) |
| `scripts/test_asc_beta_invite.py` (`FakeASC`) | Test | Nachbau mit Zustand, wird um die Einreichungs-Routen erweitert |
| Apple-Vereinbarung für Beta-Tests | Konto | fehlt sie, antwortet Apple 422 `BETA_CONTRACT_MISSING`; Aktion liegt beim Konto-Inhaber |
| #724 (offen) | Ticket | neue Builds automatisch zuordnen; hier für den einen Lauf überbrückt, weil `einreichen` vorher zuordnet |
| 2b-2c | Folgeschnitt | öffentlicher Link, erst nach `APPROVED` |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_beta_invite.py | MODIFY | Schalter `--einreichen`; `plan_submission` (Vorbedingung), `submit_platform` (höchstens ein POST je Plattform, Fehlerwörter); `assign_platform` gibt zusätzlich die Build-ID zurück; Kopfkommentar |
| scripts/test_asc_beta_invite.py | MODIFY | `FakeASC` um die Einreichungs-Routen (GET-Liste, POST mit Zustand, 409/422 über `fail`); neue Tests; `assert_clean` und Workflow-Test angepasst |
| .github/workflows/asc-beta.yml | MODIFY | Wahl `einreichen`, Job `submit` (`asc_beta_invite.py --einreichen`), `probe` hängt per `needs` auch an `submit`; Kopfkommentar |
| docs/reference/testflight.md | MODIFY | Prüfliste „Beta-Review (Einreichung)“, Absatz zu Schnitt 2: Handlauf `einreichen`, Watch im iOS-Build |
| CLAUDE.md | MODIFY | ein Halbsatz: `asc-beta.yml aktion=einreichen` (Einreichung, nur nach Hennings Wort) |

### Estimated Changes

5 Dateien, ca. +220/−5 LoC (Skript ~60, Tests ~120, Workflow ~25, Doku ~15), unter dem Limit von 250. Funktionen je ≤ 50 LoC.
**Kein Pfad der Geräteliste berührt.** (Nur `scripts/`, Workflow-Datei und Doku; kein App-Code, kein `project.yml`, keine `Info.plist`.)

## Implementation Details

### 1. Skript `asc_beta_invite.py`

`main(argv)` liest den Schalter `--einreichen` aus `argv`. Ohne Schalter bleibt der Ablauf Byte für Byte der von 2b-1 (Gruppe,
Zuordnung, Zusammenfassung).

Mit Schalter: derselbe Anfang (Gruppe sicherstellen, je Plattform `assign_platform`), danach je Plattform `submit_platform`.
`assign_platform` gibt dafür die Build-ID mit zurück (`(geschrieben, Zeile, build_id|None)`), ein Plattform-Fehler beim Zuordnen
überspringt die Einreichung dieser Plattform und lässt die andere laufen.

`plan_submission(existing, extern)` ist rein und liefert einen von drei Plänen:

| Lage | Plan | Ausgabezeile |
|------|------|--------------|
| `existing` (Liste der Einreichungen des Builds) nicht leer, jeder Zustand | kein POST | `einreichung plattform=<P> zustand=vorhanden review=<betaReviewState>` |
| leer, aber `extern != READY_FOR_BETA_SUBMISSION` (auch `unbekannt`) | kein POST | `einreichung plattform=<P> zustand=nicht-bereit extern=<Wert>` |
| leer und `extern == READY_FOR_BETA_SUBMISSION` | ein POST | `einreichung plattform=<P> zustand=eingereicht review=<betaReviewState>` |

Kein gültiger Build für die Plattform: `einreichung plattform=<P> zustand=kein-gültiger-build`, kein POST.

`submit_platform` liest zuerst (`GET …?filter[build]=<Build>`, `externalBuildState`), wendet den Plan an und fängt Fehler:

- **409** → Zeile `einreichung plattform=<P> zustand=konflikt`, **Exit 0** (kein Absturz; die Probe zeigt Apples Zustand).
- **422 mit `BETA_CONTRACT_MISSING`** → `::error::platform=<P> Beta-Vereinbarung bei Apple fehlt: der Konto-Inhaber muss sie in App
  Store Connect annehmen`, Exit 1 am Ende.
- **403** → bestehender `FORBIDDEN`-Text (`Schlüssel ohne Schreibrecht: …`), Exit 1 am Ende.
- jeder andere Fehler → `::error::platform=<P> <message(error)>`, Exit 1 am Ende.

Alle Plattformen werden durchlaufen; die Schlusszeile `zusammenfassung geschrieben=<n>` zählt Zuordnungen und Einreichungen
zusammen. Ausgaben bleiben Zustandswörter: keine IDs, keine Links, keine Buildnummern (das Repo ist öffentlich); `Masked` und
`message()` gelten unverändert auch für die neuen Pfade `/v1/betaAppReviewSubmissions`.

Funktion ≤ 50 LoC je Einheit; `submit_platform` ist dafür in Lesen (`read_submission_state`) und Absenden getrennt.

### 2. Workflow `asc-beta.yml`

- Wahl `einreichen` in `inputs.aktion`; Beschreibung: „einreichen = Zuordnen und Beta-Review einreichen (nicht rücknehmbar)“.
- Neuer Job `submit` nach dem Muster von `assign`: `if: ${{ !cancelled() && inputs.aktion == 'einreichen' }}`, `needs: setup`
  wie bei `assign`, `ubuntu-latest`, `timeout-minutes: 10`, gleiche Secrets, Schlüsseldatei mit `umask 077` und `trap rm`, Aufruf
  `python3 scripts/asc_beta_invite.py --einreichen`.
- `probe`: `needs: [setup, assign, submit]` und die `if`-Bedingung um `needs.submit.result` ergänzt (`success` oder `skipped`).
- Die Datei nennt weiter weder `betaAppReviewSubmissions` noch `publicLinkEnabled`; die Einreichung steckt nur im Skript hinter dem
  Schalter. Keine neue Eingabe außer `aktion`, kein `push`, `schedule` oder `workflow_run`.

### 3. Doku

- `docs/reference/testflight.md`: Prüflistenzeile „Beta-Review (Einreichung)“ bleibt `offen`, bis der echte Lauf belegt ist; im
  Absatz Schnitt 2 steht der Handlauf `einreichen` mit Hinweis „nicht rücknehmbar, nur nach Hennings Wort“, die erwarteten Zeilen
  und der Satz, dass die Watch-App im iOS-Build mitgeprüft wird.
- `CLAUDE.md`: ein Halbsatz bei der Nennung von `asc-beta.yml`.

### Alternative

**Eigenes Skript `asc_beta_submit.py`**, das nur einreicht, was schon in `Tester` liegt (Plattform per
`GET /v1/builds/{id}?include=preReleaseVersion`). Vorteil: strikte Dateitrennung „kann nie einreichen“ / „reicht ein“. Nachteil:
ca. 300 LoC (über dem Limit, also zwei Schnitte), Build-Wahl, Maskierung und `FakeASC` doppelt, und es reicht womöglich einen
veralteten Build ein, weil die Gruppen-Buildliste keine Plattform trägt und alte Builds enthalten kann (#724 offen). **Verworfen**
zugunsten des Schalters; die Trennung sichert dort ein Test (AC-1) statt einer Datei. Eine ADR wird dadurch nicht gekippt.

Weitere erwogene Wege, verworfen: Einreichen in der Oberfläche von App Store Connect (nicht belegt, nicht wiederholbar; bleibt
Notausgang bei 403) und nur iOS einreichen (widerspricht Hennings Auftrag „iPhone/iPad und Mac und Apple Watch“).

## Test Plan

### Automated Tests

Alle Tests laufen gegen den lokalen Nachbau `FakeASC` in `scripts/test_asc_beta_invite.py` (`python3 scripts/test_asc_beta_invite.py`).
Der Nachbau bekommt Einreichungen als Zustand: `GET /v1/betaAppReviewSubmissions?filter[build]=<id>` liest, `POST
/v1/betaAppReviewSubmissions` schreibt (Antwort 201 mit `betaReviewState=WAITING_FOR_REVIEW`) und legt die Einreichung an; 409 und
422 werden über `fail` und einen Antwortrumpf mit Fehlercode eingespielt. `buildBetaDetail` liefert den `externalBuildState` je
Szenario (Standard `READY_FOR_BETA_SUBMISSION`).

- [ ] `test_without_flag_never_submits`: Aufruf ohne Schalter in allen bisherigen Szenarien (erster Lauf, zweiter Lauf, vorhandene
  Gruppe, 422 beim Zuordnen) sendet keinen Aufruf auf `betaAppReviewSubmissions` (GET und POST); der bestehende
  `test_never_submits_and_never_enables_link` bleibt unverändert grün. Die Prüfung `assert_clean` unterscheidet künftig: ohne
  Schalter jeder Pfad `betaAppReviewSubmissions` verboten, mit Schalter nur POST auf genau diesen Pfad.
- [ ] `test_with_flag_submits_each_platform_once`: Schalter, leerer Nachbau → je Plattform genau ein POST mit dem Rumpf der Spec
  (Beziehung `build` mit der Build-ID, keine Attribute), iOS und macOS zusammen genau zwei; Zeilen `einreichung plattform=IOS
  zustand=eingereicht review=WAITING_FOR_REVIEW` und dieselbe für `MAC_OS`; Exit 0.
- [ ] `test_assignment_happens_before_submission`: der POST auf die Gruppen-Zuordnung steht je Plattform vor dem POST auf die
  Einreichung, und eingereicht wird die Build-ID, die zugeordnet wurde (nicht ein anderer Build).
- [ ] `test_second_run_sends_no_submission`: zweiter Lauf mit Schalter → keine Schreibaufrufe; `einreichung plattform=… zustand=vorhanden
  review=WAITING_FOR_REVIEW`; `zusammenfassung geschrieben=0`.
- [ ] `test_existing_submission_in_any_state_is_not_repeated`: bestehende Einreichung mit `IN_REVIEW`, `APPROVED` und `REJECTED` →
  kein POST, Zeile `zustand=vorhanden review=<Zustand>`.
- [ ] `test_not_ready_build_is_not_submitted`: `externalBuildState` ist `PROCESSING` bzw. nicht lesbar (`unbekannt`) → kein POST,
  `zustand=nicht-bereit extern=<Wert>`, Exit 0.
- [ ] `test_platform_without_valid_build_is_reported`: nur ein iOS-Build vorhanden → iOS wird eingereicht, macOS meldet
  `zustand=kein-gültiger-build` ohne POST, Exit 0.
- [ ] `test_conflict_is_a_state_not_a_crash`: 409 auf den POST der iOS-Einreichung → `einreichung plattform=IOS zustand=konflikt`,
  Exit 0, macOS wird trotzdem eingereicht.
- [ ] `test_missing_contract_names_the_account_holder`: 422 mit `BETA_CONTRACT_MISSING` → `::error::` mit `platform=<P>` und dem
  Klartext zur fehlenden Vereinbarung und zum Konto-Inhaber, Exit 1; kein zweiter POST für diese Plattform.
- [ ] `test_forbidden_submission_uses_existing_text`: 403 auf den POST → Ausgabe enthält `Schlüssel ohne Schreibrecht`, Exit ≠ 0.
- [ ] `test_one_platform_failing_does_not_hide_the_other_submission`: Fehler (422 anderer Art) für iOS → `::error::platform=IOS`,
  macOS wird dennoch eingereicht, Schlusszeile `zusammenfassung geschrieben=` steht zuletzt, Exit 1.
- [ ] `test_submission_output_has_only_state_words`: Ausgabe (stdout und stderr) enthält keine Build-IDs, Gruppen-IDs, App-ID,
  Einreichungs-IDs, Buildnummern, Links, Schlüsselmaterial; enthält `plattform=`, `zustand=`, `review=`, `geschrieben=`.
- [ ] `test_workflow_file` erweitert: Wahl `- einreichen`, Job `submit` mit `scripts/asc_beta_invite.py --einreichen`, `umask 077`,
  `rm -f`, `runs-on: ubuntu-latest`, `inputs.aktion == 'einreichen'`; `needs: [setup, assign, submit]` und `needs.submit.result`
  im Job `probe`; `workflow.count("inputs.") == workflow.count("inputs.aktion")`; die Datei enthält weiter weder
  `betaAppReviewSubmissions` noch `publicLinkEnabled`, kein `push:`, `schedule:`, `workflow_run:`; `testflight.yml` nennt
  `asc_beta_invite` weiterhin nicht.

Regression: alle übrigen `python3 scripts/test_*.py` unverändert grün.

### Echte Aufrufe (nach dem Merge, nicht Teil der ACs)

Siehe Definition of Done: ein Lauf `aktion=einreichen` auf `main`, **nur nach Hennings ausdrücklicher Freigabe** (unumkehrbar),
danach die Probe desselben Laufs als Beleg.

## Acceptance Criteria

- **AC-1:** Ohne den Schalter `--einreichen` sendet `asc_beta_invite.py` in keinem Szenario (erster Lauf, zweiter Lauf, bestehende
  Gruppe, Fehler beim Zuordnen) einen GET oder POST auf `betaAppReviewSubmissions`, und `asc-beta.yml` enthält die Zeichenfolge
  `betaAppReviewSubmissions` nicht. Geprüft durch `test_without_flag_never_submits`, den unveränderten
  `test_never_submits_and_never_enables_link` und `test_workflow_file`.
- **AC-2:** Mit `--einreichen` und bereiten Builds wird je Plattform (iOS, macOS) genau ein POST auf `/v1/betaAppReviewSubmissions`
  gesendet, dessen Rumpf nur die Beziehung `build` mit der Build-ID trägt; Ausgabe `einreichung plattform=<P> zustand=eingereicht
  review=WAITING_FOR_REVIEW`, Exit 0. Geprüft durch `test_with_flag_submits_each_platform_once`.
- **AC-3:** Mit `--einreichen` wird der Build zuerst der Gruppe `Tester` zugeordnet und danach genau dieser Build eingereicht
  (neuester gültiger Build der Plattform, nicht ein anderer in der Gruppe). Geprüft durch
  `test_assignment_happens_before_submission`.
- **AC-4:** Ein zweiter Lauf mit `--einreichen` schreibt nichts: bei bestehender Einreichung in jedem Zustand (`WAITING_FOR_REVIEW`,
  `IN_REVIEW`, `APPROVED`, `REJECTED`) kein POST, Zeile `zustand=vorhanden review=<Zustand>`, `zusammenfassung geschrieben=0`.
  Geprüft durch `test_second_run_sends_no_submission` und `test_existing_submission_in_any_state_is_not_repeated`.
- **AC-5:** Ist `externalBuildState` nicht `READY_FOR_BETA_SUBMISSION` (auch nicht lesbar), wird nicht eingereicht: kein POST, Zeile
  `zustand=nicht-bereit extern=<Wert>`, Exit 0; gibt es für eine Plattform keinen gültigen Build, steht `zustand=kein-gültiger-build`
  ohne POST. Geprüft durch `test_not_ready_build_is_not_submitted` und `test_platform_without_valid_build_is_reported`.
- **AC-6:** Antwortet Apple auf die Einreichung mit 409, meldet das Skript `einreichung plattform=<P> zustand=konflikt` und endet mit
  Exit 0; die andere Plattform wird trotzdem bearbeitet. Geprüft durch `test_conflict_is_a_state_not_a_crash`.
- **AC-7:** Antwortet Apple mit 422 `BETA_CONTRACT_MISSING`, druckt das Skript eine `::error::`-Zeile mit `platform=<P>` und
  Klartext (Beta-Vereinbarung bei Apple fehlt, der Konto-Inhaber muss sie annehmen), endet mit Exit 1 und wiederholt den POST nicht.
  Geprüft durch `test_missing_contract_names_the_account_holder`.
- **AC-8:** Antwortet Apple mit 403, enthält die Ausgabe den bestehenden Text „Schlüssel ohne Schreibrecht: Rolle des
  API-Schlüssels in App Store Connect prüfen“, Exit ≠ 0. Geprüft durch `test_forbidden_submission_uses_existing_text`.
- **AC-9:** Eine Plattform verdeckt die andere nicht: schlägt die Einreichung oder Zuordnung der einen Plattform fehl, wird die
  andere dennoch bearbeitet, die Schlusszeile `zusammenfassung geschrieben=<n>` steht zuletzt, und der Exit-Code ist 1. Geprüft durch
  `test_one_platform_failing_does_not_hide_the_other_submission`.
- **AC-10:** Die Ausgabe (stdout und stderr) enthält nur Zustandswörter: keine Build-, Gruppen-, App- oder Einreichungs-IDs, keine
  Buildnummern, keine Links, kein Schlüsselmaterial, auch nicht in den Wiederholungszeilen der geteilten Helfer. Geprüft durch
  `test_submission_output_has_only_state_words` (und den unveränderten `test_output_has_only_state_words`).
- **AC-11:** `.github/workflows/asc-beta.yml` bietet die Wahl `einreichen` an, der Job `submit` ruft `python3
  scripts/asc_beta_invite.py --einreichen` nur bei `inputs.aktion == 'einreichen'` auf (Schlüssel mit `umask 077` und `trap rm`,
  `ubuntu-latest`), `probe` hängt per `needs` auch an `submit` und läuft nach `success` oder `skipped`; es gibt weiter nur die
  Eingabe `aktion` und keinen `push`-, `schedule`- oder `workflow_run`-Auslöser; `testflight.yml` nennt `asc_beta_invite` nicht.
  Geprüft durch den erweiterten `test_workflow_file`.
- **AC-12:** Alle vorhandenen Skripttests (`python3 scripts/test_*.py`) sind grün, und der Diff berührt höchstens die fünf Dateien
  der Tabelle (±250 LoC) und keinen Pfad der Geräteliste. Geprüft durch die Testausgabe und `git diff --stat`.

Kein Pfad der Geräteliste berührt. Abnahmestufe: Skripttests; es gibt keine App-Änderung, also weder Simulator- noch Geräteschritt.

## Out of Scope

- **Öffentlicher Link** (`publicLinkEnabled`, Limit 50, Maskierung von `url=` in der Probe): Schnitt 2b-2c, erst nach `APPROVED`.
- **Automatische Zuordnung oder Einreichung je neuem Build** (#724) und je neuer Version.
- **Zurückziehen einer Einreichung**: per API nicht möglich; kein DELETE und kein PATCH im Skript.
- **Eigene watchOS-Einreichung**: es gibt keine, die Watch-App steckt im iOS-Build.
- **Änderungen an Beschreibung, Kontakt, Datenschutz-URL, Gruppe** und an `asc_beta_setup.py`, `asc_beta_probe.py`, `testflight.yml`.
- **Der echte Lauf selbst**: kein AC, siehe Definition of Done.
- **Test auf Hennings Geräten**: nichts, kein Gerätepfad berührt.

## Definition of Done

- [ ] Skript, Tests, Workflow, Doku und `CLAUDE.md` umgesetzt und per PR gemergt; alle Skripttests grün (AC-1 bis AC-12).
- [ ] **Echter Lauf `aktion=einreichen` auf `main`: erst nach Hennings ausdrücklicher Freigabe** (Einreichung ist unumkehrbar; Frage
  per AskUserQuestion mit Kontext, Henning bestätigt wörtlich). Vorher prüft die Probe `aktion=probe` den Stand: beide Builds
  `extern=READY_FOR_BETA_SUBMISSION`, `einreichung keine`, Datenschutz-URL gesetzt.
- [ ] Nach dem Lauf: Probe desselben Laufs zeigt je Plattform `einreichung build=… zustand=WAITING_FOR_REVIEW`; ein zweiter Lauf
  `einreichen` bestätigt `zustand=vorhanden` und `geschrieben=0`. Lauf-Links mit Zeilenauszug in #705 und in der Prüfliste in
  `docs/reference/testflight.md`; die Zeile „Beta-Review (Einreichung)“ wechselt erst dann von `offen` auf den belegten Stand.
- [ ] Wird der Lauf mit 422 `BETA_CONTRACT_MISSING` abgewiesen: Henning bekommt in Alltagssprache die eine Aktion für den
  Konto-Inhaber (Vereinbarung in App Store Connect annehmen), danach Wiederholung.
- [ ] Kommentar in #705: Einreichung, Lauf-Links, Hinweis, dass 2b-2c (Link) erst nach `APPROVED` folgt. Ticket #705 bleibt offen
  (`Refs #705`, nicht `Closes`).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Erweiterung eines Handlauf-Skripts um einen ausdrücklichen Schalter und eine Workflow-Wahl; keine Produktarchitektur, kein App-Code, keine Änderung an einer ADR.

## Changelog

- 2026-10-28: Initial spec created
