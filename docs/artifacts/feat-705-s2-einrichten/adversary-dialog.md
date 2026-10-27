# Adversary Dialog — feat-705-s2-einrichten
Spec: docs/specs/feat-705-schnitt-2a-texte-kontakt.md
Datum: 2026-10-27 08:03

## Checkliste
- [x] **AC-1:** `scripts/asc_beta_setup.py` legt die Sprachfassung `de-DE` an, wenn sie fehlt, und patcht sonst nur abweichende Attribute (`description`, `feedbackEmail`; `privacyPolicyUrl` nur wenn gewünscht); die Beschreibung stammt unverändert aus `docs/reference/beta-beschreibung.md`. Belegt durch `test_creates_missing_localization_and_patches_review_detail`, `test_patches_existing_localization_only_where_different`, `test_description_file_is_sent_verbatim`.
- [x] **AC-2:** Das Skript setzt `contactFirstName`, `contactLastName`, `contactPhone`, `contactEmail` des Review-Details aus den Secrets und `demoAccountRequired=false`; die Feedback-E-Mail ist `ASC_REVIEW_EMAIL`. Belegt durch `test_creates_missing_localization_and_patches_review_detail`.
- [x] **AC-3:** Idempotent: stimmen die Werte bei Apple schon, sendet das Skript keinen Schreibaufruf (weder POST noch PATCH) und meldet `geschrieben=0`; ein zweiter Lauf nach einem ersten ändert nichts. Belegt durch `test_second_run_sends_no_write`, `test_unchanged_state_writes_nothing`.
- [x] **AC-4:** Die Datenschutz-URL wird nur gesetzt, wenn `ASC_PRIVACY_POLICY_URL` gesetzt ist; sonst enthält kein Rumpf `privacyPolicyUrl`. Belegt durch `test_privacy_url_only_when_given`.
- [x] **AC-5:** Ein fehlendes Pflicht-Secret, ein Telefon ohne führendes `+`, mehrdeutiger oder fehlender Ist-Zustand brechen mit Exit 1 und `::error::` ab, **bevor** irgendein Schreibaufruf (bei fehlendem Secret und Telefonfehler: bevor irgendeine Anfrage) gesendet wird; die Meldung nennt den Variablennamen, nie einen Wert. Belegt durch `test_missing_secret_aborts_before_any_write`, `test_phone_without_plus_aborts_before_any_write`, `test_ambiguous_or_missing_state_aborts`.
- [x] **AC-6:** Antwortet Apple auf einen Schreibaufruf mit 403, endet das Skript mit Exit ≠ 0 und der Meldung „Schlüssel ohne Schreibrecht“. Belegt durch `test_forbidden_write_is_reported_clearly`.
- [x] **AC-7:** Die Ausgabe enthält nur „gesetzt/leer/unverändert“, nie Beschreibung, Kontaktwerte, Feedback-E-Mail, Datenschutz-URL, Schlüssel oder Token (stdout und stderr). Belegt durch `test_output_has_no_values_and_no_key`.
- [x] **AC-8:** `.github/workflows/asc-beta.yml` hat die Eingabe `aktion` (`probe` Standard, `einrichten`), reicht Kontaktdaten ausschließlich als Secrets im `env` an den Schreibjob (keine Eingabe dafür), lässt die Probe nach erfolgreichem Einrichten als Beleg laufen und entfernt die Schlüsseldatei; `testflight.yml` ist unverändert. Belegt durch `test_workflow_file`, die Regression der Probe-Tests und `git diff --stat` (`testflight.yml` nicht im Diff).
- [x] **AC-9:** `docs/reference/beta-beschreibung.md` enthält den freigegebenen Wortlaut und `docs/reference/testflight.md` beschreibt den Handlauf `einrichten` samt Unumkehrbarkeit der Kontaktfelder und 403-Rückfall. Belegt durch `test_description_file_is_sent_verbatim` und Diff (`grep -n "einrichten" docs/reference/testflight.md` mindestens ein Treffer).
- [x] **AC-10:** Der Diff berührt genau die fünf Dateien des Scopes, kein `project.yml`, kein App-Code, kein `testflight.yml`, kein Pfad der Geräteliste, höchstens ±250 LoC, jede Funktion ≤ 50 Zeilen. Belegt durch `git diff --stat` im Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“
- [x] **AC-11:** Alle Skripttests (`python3 scripts/test_*.py`) sind grün und liefen vor Skript und Workflow-Änderung rot (TDD RED). Belegt durch die Testausgabe im Abschlussbericht.
- [x] **AC-12:** Der echte Lauf `aktion=einrichten` läuft erst nach Hennings getippter Freigabe dieser Spec; danach zeigt die Probe desselben Laufs `lokalisierung locale=de-DE beschreibung=gesetzt feedbackEmail=gesetzt` und im `reviewdetail` die vier Kontaktfelder `gesetzt`; die Prüfliste in `testflight.md` verweist auf diesen Lauf. Belegt durch Lauf-Link im Ticket #705 und die ausgefüllte Spalte „Beleg“. Vor der Freigabe läuft kein schreibender Aufruf gegen App Store Connect und nichts auf Hennings Geräten.

## Dialog

### Runde 1
**Adversary:** Tests selbst gelaufen (docs/artifacts/feat-705-s2-einrichten/adversary-test-output.txt): test_asc_beta_setup.py Ran 12 tests, OK; alle scripts/test_*.py OK (test_board.py ist kein unittest, druckt nur Usage, nicht Teil der Änderung). YAML via yaml.safe_load gültig, Jobs setup+probe.
Confirmation:
  AC: AC-1
  Code reference: scripts/asc_beta_setup.py:47
  Evidence: plan_localization: POST mit allen Attributen wenn de-DE fehlt, sonst PATCH nur mit differing() (Z.43); Beschreibung aus Datei (Z.30), 613 Zeichen, Wortlaut gleich Spec (docs/reference/beta-beschreibung.md:1).
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: scripts/asc_beta_setup.py:39
  Evidence: Vier Kontaktfelder + demoAccountRequired False; feedbackEmail = ASC_REVIEW_EMAIL (Z.35); plan_review_detail Z.58.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: scripts/asc_beta_setup.py:66
  Evidence: apply_plan(None)=0, kein Schreibaufruf ohne Abweichung; Tests second_run und unchanged grün.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: scripts/asc_beta_setup.py:36
  Evidence: privacyPolicyUrl nur bei nichtleerer Variable aufgenommen.
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: scripts/asc_beta_setup.py:93
  Evidence: wanted_values() läuft vor read_config und jeder Anfrage; Fatal nennt nur Variablennamen (Z.26/28). Beide Pläne (Z.98-99) entstehen vor dem ersten apply_plan (Z.102): doppeltes de-DE oder fehlendes Review-Detail brechen vor jedem Schreiben ab.
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: scripts/asc_beta_setup.py:79
  Evidence: HTTP 403 im Fatal-Text wird durch FORBIDDEN ersetzt, Exit 1 über Z.111.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: scripts/asc_beta_setup.py:105
  Evidence: Ausgabe nur Zustandswörter und Zahl; Fehler/Retry-Pfade von send_json (scripts/asc_what_to_test.py:36-39) und get_json (scripts/asc_wait_build.py:72-82) drucken nur Methode, Pfad, Fehlerklasse, nie Rumpf, Token oder Wert.
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: .github/workflows/asc-beta.yml:48
  Evidence: Eingabe aktion choice probe/einrichten, Default probe, keine weitere Eingabe; Kontaktsecrets nur im env des Jobs setup (Z.27-35); trap rm -f und umask 077 (Z.40-41); probe needs setup mit !cancelled() und (success oder skipped): bei probe läuft probe (setup skipped), bei setup-Fehlschlag nicht. testflight.yml unverändert (nicht im Arbeitsbaum-Diff) und ohne asc_beta_setup. Der API-Schlüssel wird wie im Bestandsjob in den run-Text interpoliert.
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: docs/reference/testflight.md:187
  Evidence: Absatz Handlauf einrichten (Schnitt 2a) mit Unumkehrbarkeit, 403-Rückfall, Datenschutz-Variable; Wortlaut in docs/reference/beta-beschreibung.md:1 entspricht der Spec.
  Status: CONFIRMED
Confirmation:
  AC: AC-10
  Code reference: scripts/test_asc_beta_setup.py:1
  Evidence: asc_beta_setup.py 117 Zeilen (<=250), längste Funktion main ca. 23 Zeilen; Testdatei 253 Zeilen (Budget 500); nur Scope-Dateien geändert, kein Pfad der Geräteliste berührt.
  Status: CONFIRMED
Confirmation:
  AC: AC-11
  Code reference: scripts/test_asc_beta_setup.py:1
  Evidence: Alle Skripttests grün; RED-Commit ed67b93 (Prüfungen rot) liegt vor der Implementierung.
  Status: CONFIRMED
Confirmation:
  AC: AC-12
  Code reference: .github/workflows/asc-beta.yml:24
  Evidence: Vor dem Lauf nichts gegen Apple geschrieben (Tests nur gegen lokalen Nachbau; Auslöser nur workflow_dispatch). Echter Lauf samt Belegspalte in Phase 7/8 nach Hennings getippter Freigabe zu belegen, kein Defekt.
  Status: CONFIRMED
**Implementierer:** (nicht anwesend)

### Runde 2
**Adversary:** Edge-Case-Bohrung.
Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_beta_setup.py:97
  Description: get_json liefert bei 5xx/408/429/Netzfehler None, das Skript macht daraus {} und data=None, ohne Wiederholung (anders als get_data bei den Lokalisierungen).
  Spec requirement: AC-5 — fehlender Ist-Zustand bricht ab, ohne zu schreiben
  Conflict: Abbruch ist sicher (nichts geschrieben), aber ein vorübergehender 5xx erscheint als irreführendes "has no beta app review detail" statt Wiederholung; der echte Lauf kann grundlos rot werden.
  Remediation: Review-Detail ebenfalls mit Wiederholung lesen oder Meldung unterscheiden. Nicht blockierend.
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_beta_setup.py:44
  Description: differing() vergleicht exakt. Normalisiert Apple Werte (Telefonformat, Zeilenumbrüche), schreibt jeder Lauf erneut.
  Spec requirement: AC-3 — Idempotenz am echten Apple (DoD)
  Conflict: Im Nachbau nicht erkennbar; keine Spec-Verletzung, erst beim zweiten echten Lauf sichtbar.
  Remediation: Zweiten echten Lauf in Phase 8 belegen; bei Abweichung normalisiert vergleichen.
Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_beta_setup.py:30
  Description: read_text() ohne encoding und nur OSError gefangen; UnicodeDecodeError gäbe Traceback statt ::error::.
  Spec requirement: AC-5
  Conflict: Randfall ohne Wertleck (Datei ist öffentlich) und ohne Schreibaufruf davor.
  Remediation: read_text(encoding="utf-8") und ValueError mitfangen.
Ohne Befund geprüft: kein Schreibaufruf vor Validierung (Z.93-103); Retries geben nur Methode und Pfad aus; probe-Logik bei aktion=probe und bei setup-Fehlschlag korrekt; Teilschreiben (Lokalisierung ok, Detail 4xx) ist per Neustart heilbar.
**Implementierer:** (nicht anwesend)

### Runde 3
**Adversary:** Nachprüfung der Korrekturen. Tests neu gelaufen (docs/artifacts/feat-705-s2-einrichten/adversary-test-output.txt): Ran 12 tests, OK; alle scripts/test_*.py OK (test_board.py wie zuvor kein unittest).
Confirmation:
  AC: AC-5
  Code reference: scripts/asc_beta_setup.py:45
  Evidence: F001 behoben: get_detail wiederholt bei None (5xx/408/429/Netz) bis ATTEMPTS mit sleep(poll), dann Fatal "did not answer <Pfad>"; Pfad enthält nur die App-ID. 404 und andere 4xx bleiben Fatal aus get_json. main nutzt get_detail (Z.111) vor beiden Plänen, also weiterhin kein Schreiben vor Validierung.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: scripts/asc_beta_setup.py:33
  Evidence: F003 behoben: read_text(encoding="utf-8"), Fang von (OSError, UnicodeDecodeError); Meldung enthält nur den Namen der Fehlerklasse, keinen Dateiinhalt, keine Bytes, keinen Wert. Neue Fehlerpfade geben keine Kontaktwerte, Beschreibung, URL oder Token aus.
  Status: CONFIRMED
F001 und F003: erledigt. F002 bleibt bewusst offen (LOW, am echten zweiten Lauf in Phase 8 zu belegen).
**Implementierer:** (nicht anwesend)

### Runde 4
**Adversary:** Echte Läufe selbst lesend nachgeprüft (Protokollzeilen der Läufe, nichts gestartet). Tests neu gelaufen (docs/artifacts/feat-705-s2-einrichten/adversary-test-output.txt): Ran 12 tests, OK; alle scripts/test_*.py OK (test_board.py wie zuvor kein unittest).
Confirmation:
  AC: AC-12
  Code reference: docs/reference/testflight.md:164
  Evidence: Lauf 40466472742 (einrichten): lokalisierung locale=de-DE beschreibung=gesetzt feedbackEmail=gesetzt datenschutzUrl=leer, reviewdetail kontakt=gesetzt demoAccountRequired=aus, geschrieben=2; Probe IOS und MAC_OS danach contactFirstName/LastName/Phone/Email=gesetzt, beschreibung/feedbackEmail=gesetzt, befunde=0. Die Läufe liefen nach der getippten Freigabe; die Belegspalte in testflight.md:164-166 verweist auf die Läufe (Zeile 164 Beschreibung mit beiden Links, 165 Feedback-E-Mail, 166 Kontaktangaben). Datenschutz-URL bleibt offen (#342), gehört nicht zu 2a.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: scripts/asc_beta_setup.py:66
  Evidence: F002 widerlegt am echten Apple: Lauf 40466601395 meldet alles unverändert, zusammenfassung geschrieben=0, Probe danach weiterhin gesetzt. Apple normalisiert die Werte nicht so, dass erneut geschrieben würde.
  Status: CONFIRMED
Log-Prüfung: In den Ausgaben beider Läufe stehen nur Zustandswörter, keine Kontaktwerte, Beschreibung oder Token (AC-7 am echten Lauf bestätigt). F001, F003 erledigt (Runde 3), F002 widerlegt.
**Implementierer:** (nicht anwesend)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Kein verdächtiger Schreibort (Skript und Workflow, kein Modellfeld).

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:6bf937f0a7f65e685a9c424985b2b98fdfda361aa1dd07b77d5da1a6e1e93ae7  .github/workflows/asc-beta.yml
- sha256:a043655c4ce82b2c1333d05ee8b0f00f79e65d4f63c1692f1f0017e45fb5f31a  docs/reference/testflight.md
- sha256:674b1f68a9f515c1fde24f2244236b0d00e6293a14075f0003ae70d03556859f  scripts/asc_beta_setup.py
- sha256:28e5579cbd8936660583e2f9663ca4a25c0e01736819365e8a1f066f30d63f6e  scripts/test_asc_beta_setup.py

## Prüfbasis

- base: 582126e0e266453605b6a182b9420be2d1590e93
- blob:2ceb6ffabf623a6bc1a06fa4634785ab3d408e3c  .github/workflows/asc-beta.yml
- blob:647739898e9a442e3659685ad00c45773166ba20  docs/reference/testflight.md
- blob:7f8820cfa68b762d4555c370b7b6ef359912757d  scripts/asc_beta_setup.py
- blob:f9f8c280cde1579518ebd56904cc00de74c35aa4  scripts/test_asc_beta_setup.py
