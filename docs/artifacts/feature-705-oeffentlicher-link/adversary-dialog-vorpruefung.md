# Adversary Dialog — feature-705-oeffentlicher-link
Spec: docs/specs/feat-705-schnitt-2b2c-oeffentlicher-link.md
Datum: 2026-10-30 09:22

## Checkliste
- [x] **AC-1:** Das Skript schaltet den Link nicht ein, solange der neueste gültige Build einer Plattform nicht in der Gruppe `Tester` liegt oder nicht `BETA_APPROVED` ist (auch nicht lesbar): kein PATCH, Zeile `link zustand=nicht-bereit …`, Exit 0. Geprüft durch `test_not_ready_build_is_not_enabled` und `test_build_missing_in_group_is_not_ready`.
- [x] **AC-2:** Sind alle Vorbedingungen erfüllt, sendet es genau einen PATCH auf die Gruppe mit `publicLinkEnabled=true`, `publicLinkLimitEnabled=true`, `publicLinkLimit=50`, liest die Gruppe erneut und meldet `link zustand=eingeschaltet limit=50`, Exit 0. Geprüft durch `test_enable_sends_one_patch_with_limit_50`.
- [x] **AC-3:** Ein zweiter Lauf schreibt nichts: kein PATCH, `link zustand=vorhanden limit=50`, `zusammenfassung geschrieben=0`. Geprüft durch `test_second_run_writes_nothing`.
- [x] **AC-4:** Es bleibt nie ein Link ohne bestätigtes Limit 50 eingeschaltet: stimmt das Limit nach dem PATCH nicht oder ist das Gegenlesen nicht möglich, folgt ein zweiter PATCH mit `publicLinkEnabled=false`, die Zeile `link zustand=abgebrochen grund=limit` und Exit 1. Geprüft durch `test_limit_mismatch_switches_back_off` und `test_unreadable_readback_switches_back_off`.
- [x] **AC-5:** `--aus` schaltet einen eingeschalteten Link mit einem PATCH ab (`link zustand=ausgeschaltet`), bei ausgeschaltetem Link gibt es keinen PATCH (`link zustand=vorhanden aus`). Geprüft durch `test_off_switches_link_off_and_is_idempotent`.
- [x] **AC-6:** Fehlt die externe Gruppe `Tester`, endet der Lauf mit `::error::` und Exit 1 vor jedem Schreiben. Geprüft durch `test_missing_group_aborts_before_any_write`.
- [x] **AC-7:** Bei 403 steht der bestehende Text „Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen“ in der Ausgabe, bei anderen 4xx eine `::error::`-Zeile; beide Exit 1, der PATCH wird nicht wiederholt. Geprüft durch `test_forbidden_and_other_errors_are_reported`.
- [x] **AC-8:** Die Ausgabe (stdout und stderr) enthält nur Zustandswörter: nie den Einladungslink, keine Gruppen-, App- oder Build-IDs, keine Buildnummern, kein Schlüsselmaterial. Geprüft durch `test_output_has_only_state_words`.
- [x] **AC-9:** `.github/workflows/asc-beta.yml` bietet `link` und `link-aus` an; der Job `link` ruft `scripts/asc_beta_link.py` (bei `link-aus` mit `--aus`) nur bei der jeweiligen Wahl auf (Schlüssel mit `umask 077` und `trap rm`, `ubuntu-latest`); `probe` hängt per `needs` auch an `link`; es gibt nur die Eingabe `aktion` und keinen `push`-, `schedule`- oder `workflow_run`-Auslöser; die Datei nennt `publicLinkEnabled` und `betaAppReviewSubmissions` nicht; `testflight.yml` nennt das Skript nicht. Geprüft durch `test_workflow_file` (neu) und den angepassten `test_workflow_file` in `test_asc_beta_invite.py`.
- [x] **AC-10:** `asc_beta_invite.py` bleibt unverändert und enthält weiter kein PATCH und kein Schreiben von `publicLink*`; `zuordnen` und `einreichen` können den Link nicht einschalten. Geprüft durch `test_invite_script_untouched` und `git diff --stat`.
- [x] **AC-11:** `docs/reference/testflight.md` führt „Beta-Review“ als `APPROVED` mit Beleg Lauf 41019692346, die Zeile „Öffentlicher Link“ als `offen` mit Verweis auf #743 und den Handlauf `link` samt Rückfall über App Store Connect. Geprüft durch `test_testflight_doc_lists_link_row`.


## Dialog

### Runde 1
**Adversary:** Alle Tests selbst ausgefuehrt (Ausgabe: docs/artifacts/feature-705-oeffentlicher-link/adversary-test-output.txt):
test_asc_beta_link.py 14 Tests OK, test_asc_beta_invite.py 27 Tests OK (inkl. angepasstes test_workflow_file), 0 Fehler, 0 uebersprungen.
Diff-Statistik gegen HEAD: nur Workflow, testflight.md, test_asc_beta_link.py (Rest steckt im RED-Commit); asc_beta_invite.py unveraendert.
Workflow per yaml.safe_load gelesen: gueltig, einzige Eingabe aktion, Job link und probe (needs setup, assign, submit, link; needs.link.result success oder skipped). Kein publicLink und kein betaAppReviewSubmissions im Workflow; testflight.yml nennt das Skript nicht.
Eigene Angriffe gegen den Nachbau FakeLinkASC (Skripte unter docs/artifacts/feature-705-oeffentlicher-link/adversary/):
- Limit als 50.0, "50" oder True bei schon eingeschaltetem Link: confirmed() lehnt ab, erneuter PATCH auf 50 (sicher).
- Zwei externe Gruppen Tester: plan_group wirft Fatal, kein Schreiben.
- Erster PATCH liefert 5xx obwohl angewendet: test_server_error_on_enable_still_switches_off deckt den Rueckweg; Ausgabe maskiert die ID.
- ASC_PLATFORM gesetzt: platform_state ueberschreibt die Plattform je Aufruf, kein Einfluss (per Code gelesen).
Angriff A: Aufruf mit Argument --AUS (Tippfehler) ergibt "link zustand=eingeschaltet limit=50", 1 PATCH, Link an. Jedes unbekannte Argument schaltet ein.
Angriff B: Gruppe liefert publicLinkEnabled als String "true": --aus meldet "vorhanden aus", 0 PATCH, Link bleibt an.
Angriff D: Zuruecknehmen schlaegt fehl (403 bzw. 5xx) nach Limit-Abweichung: Exit 1, aber nur der 403- bzw. "did not accept PATCH"-Text; nichts sagt, dass der Link noch AN ist und ohne Limit. Endzustand im Nachbau: Link an, Limit leer.
Angriff E: Link schon an mit Limit 10000, Build PROCESSING: "nicht-bereit", Exit 0, 0 PATCH; der Link steht weiter mit falschem Limit, ohne Warnung.
Angriff F: --aus mit PATCH 422: "::error::ASC answered HTTP 422 for PATCH /v1/betaGroups/...", Exit 1, geschrieben=0, ehrlich.
Testguete: test_workflow_file prueft Teilstrings, nicht die Zuordnung --aus zu link-aus (vertauschte if blieben gruen); test_testflight_doc_lists_link_row prueft den Rueckfall ueber App Store Connect nicht (die Doku enthaelt ihn, Zeile 220ff.); test_output_has_only_state_words prueft Erfolgsweg und --aus, die Fehlerwege deckt test_server_error_on_enable_still_switches_off mit ab.
**Implementierer:** (vom Adversary erzeugt) Belege: Testlaeufe scripts/test_asc_beta_link.py und scripts/test_asc_beta_invite.py ergeben OK; Angriffsskripte adversary/c1.py, c2.py, c4.py, c5.py, c7.py. Spec-konform: die Spec verlangt weder Argumentpruefung noch Warnung beim gescheiterten Zuruecknehmen.

Befunde:

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_beta_link.py:130
  Description: Nur "--aus" wird erkannt; jedes andere Argument (--AUS, -aus) schaltet den oeffentlichen Link EIN (Lauf Angriff A).
  Spec requirement: AC-5 / AC-2 — Aus- und Einschalten sind getrennte Wege
  Conflict: kein AC verletzt (Workflow ruft nur feste Formen), aber ein Tippfehler wirkt nach aussen.
  Remediation: nur kein Argument oder --aus zulassen, sonst Exit 2 vor jedem Lesen und Schreiben.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_beta_link.py:117
  Description: Der Ausschalter prueft "is not True"; ist publicLinkEnabled ein String, fehlt oder ist null, meldet --aus "vorhanden aus" ohne PATCH (Lauf Angriff B).
  Spec requirement: AC-5 — --aus schaltet einen eingeschalteten Link ab
  Conflict: Der Ausschalter versagt offen bei unerwarteter Antwortform.
  Remediation: bei --aus nur bei exakt False ueberspringen, sonst PATCH aus.

Finding:
  ID: F003
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_beta_link.py:95
  Description: Scheitert das Zuruecknehmen nach Limit-Abweichung, endet der Lauf mit Exit 1, die Ausgabe nennt aber nur den 403- oder 5xx-Text und nicht, dass der Link noch ohne Limit an ist (Lauf Angriff D). undo_failed_enable ab Zeile 76 hat dagegen eine Fangzeile.
  Spec requirement: AC-4 — nie ein Link ohne bestaetigtes Limit
  Conflict: AC-4 ist erfuellt (zweiter PATCH, Exit 1), die Gefahr bleibt aber unsichtbar.
  Remediation: Fatal dort abfangen, "link zustand=ausschalten-gescheitert" ausgeben, dann weiterreichen.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_beta_link.py:22
  Description: Link bereits an mit abweichendem Limit und Build nicht freigegeben: Exit 0 "nicht-bereit", kein Hinweis auf den offenen Zustand (Lauf Angriff E); laut Spec-Tabelle korrekt.
  Spec requirement: AC-1
  Conflict: keiner, nur fehlende Warnung.
  Remediation: Zeile "link zustand=ohne-limit" ausgeben.

Finding:
  ID: F005
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/test_asc_beta_link.py:248
  Description: test_workflow_file bindet --aus nicht an link-aus (Teilstrings, vertauschte if blieben gruen); test_testflight_doc_lists_link_row (Zeile 268) prueft den Rueckfall nicht.
  Spec requirement: AC-9 / AC-11
  Conflict: Tests beweisen weniger als die ACs behaupten.
  Remediation: Schrittbloecke je if zerlegen, "Rueckfall" in den Doku-Test aufnehmen.

### Runde 2
**Adversary:** Nachfragen zu dem, was in Runde 1 duenn war.
1. Kann eine andere Aktion den Link-Schritt ausloesen? Nein: if des Jobs und beider Schritte nennt nur link und link-aus; assign und submit rufen weiter nur asc_beta_invite.py (Code reference: .github/workflows/asc-beta.yml:95), test_invite_script_untouched und die Diff-Statistik zeigen dort keine Aenderung. Schlaegt link fehl, laeuft probe nicht (Ergebnis failure), kein Folgeschaden.
2. Steht Link, Secret oder publicLink in Workflow oder Skriptausgabe? Im Workflow nein; das Skript druckt nur feste Zustandswoerter, Masked filtert IDs auch in Wiederholungszeilen (Angriffe D und I zeigen /v1/betaGroups/...), Ausnahmen werden zu ::error:: mit message(), kein Traceback. Offen: KeyboardInterrupt liegt ausserhalb von except Exception (im Actions-Betrieb irrelevant).
3. zusammenfassung geschrieben= im Fehlerfall: zaehlt angenommene PATCH (Angriff I: 6 Versuche, geschrieben=1; Angriff F: 0). Ein 5xx-PATCH, den Apple doch anwendete, bleibt ungezaehlt, wird aber durch undo_failed_enable zurueckgenommen; konsistent mit apply_plan, kein Befund.
4. Plattform ohne gueltigen Build: plan_link ergibt nicht-bereit mit plattform=keine, Exit 0; gemischt (eine ohne Build, eine bereit) schaltet ein, wie die Spec.
5. Doku gegen Spec: Lauf 41019692346, APPROVED, Zeile Oeffentlicher Link offen mit #743, Handlauf-Absatz mit Rueckfall stimmen ueberein (Code reference: docs/reference/testflight.md:220).
6. Angepasstes test_workflow_file im Invite-Test enthaelt die drei Zeichenfolgen (Code reference: scripts/test_asc_beta_invite.py:425), Lauf gruen.
7. Aussagekraft: test_limit_mismatch_* pruefen Endzustand im Nachbau und beide PATCH-Koerper, test_enable_* den Koerper und das Gegenlesen als letzte Anfrage; bei kaputtem Code waeren sie rot. Nur die Schwaeche F005.
Fruehe-Einigkeit-Skepsis: jeder AC wurde mit eigenem Lauf oder Codepfad belegt; die Befunde kamen aus eigenen Angriffen, keiner verletzt einen AC.
**Implementierer:** (vom Adversary erzeugt) Belege zu Punkt 1-7: yaml.safe_load der Workflow-Datei (gueltig), grep nach publicLink und asc_beta_link (nur die zwei erwarteten Aufrufe), Testlaeufe wie Runde 1. AC-1 (test_not_ready_*), AC-2 (test_enable_*), AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10, AC-11 gruen und gegengelesen.

Confirmation:
  AC: AC-1, AC-2
  Code reference: scripts/asc_beta_link.py:79
  Evidence: switch_on sendet genau einen PATCH mit Limit 50, liest gegen; plan_link blockiert bei nicht BETA_APPROVED.
  Status: CONFIRMED

Confirmation:
  AC: AC-3, AC-4, AC-5, AC-6, AC-7, AC-8
  Code reference: scripts/asc_beta_link.py:22
  Evidence: confirmed() ist streng (nur bool True und int 50); Rueckschalten, Fehlerpfade und Maskierung per Test und Angriff belegt.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: .github/workflows/asc-beta.yml:124
  Evidence: needs setup, assign, submit, link; Job link nur bei link und link-aus.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/test_asc_beta_link.py:263
  Evidence: test_invite_script_untouched gruen, asc_beta_invite.py ohne Diff.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/reference/testflight.md:220
  Evidence: Beta-Review APPROVED mit Lauf 41019692346, Link-Zeile offen mit #743, Handlauf und Rueckfall.
  Status: CONFIRMED

Confirmation:
  AC: AC-9 (Invite-Test)
  Code reference: scripts/test_asc_beta_invite.py:425
  Evidence: angepasste Zeichenfolgen needs link und needs.link.result.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Tests: 41 bestanden (14 Link, 27 Invite), 0 fehlgeschlagen, 0 uebersprungen. Alle 11 ACs belegt. F001 bis F003 (MEDIUM) und F004, F005 (LOW) sind Haertungen ausserhalb der ACs; vor dem echten Lauf empfohlen: F001 bis F003.

**VERIFIED**

## Geprüfte Dateien

- sha256:f790528370491357c03c609c2cabc32743fec5fa6b6032f2135e7e2634b4829e  .github/workflows/asc-beta.yml
- sha256:292e2965fbc87b54237daf2231363ad0c2f3119380b5f83b0981555f68930347  docs/reference/testflight.md
- sha256:1b53a85299be3267c2a150724602ce810ca17f161b681b2319482cc412d2b9c2  scripts/asc_beta_link.py
- sha256:d8f18428ec48a3f2449b02ea03ee8f9f08fa2425bdc821bc4a44e154dca2d3ec  scripts/test_asc_beta_invite.py
- sha256:fb6f66b1f3465a0ed19b69fa0b04ce148957e80401572d57e921ef7fe707eced  scripts/test_asc_beta_link.py

## Prüfbasis

- base: 754b4f0cc9ce98e20deecfe2e3f8ff79108f5b73
- blob:fa89c7b9f7f1df5e3ae26d7d1c3c824edf35b703  .github/workflows/asc-beta.yml
- blob:7903f87bc5f2a8c72c0b22d6dfd58a33020916b6  docs/reference/testflight.md
- blob:e17c0a1f7abeaf21d73000975df6201094233278  scripts/asc_beta_link.py
- blob:be2489ff7f80a574cb18fea28d3cc44fc01cd229  scripts/test_asc_beta_invite.py
- blob:208ee74baec0edb438fc35562e1ae97f292c6ce4  scripts/test_asc_beta_link.py
