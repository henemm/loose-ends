# Adversary Dialog — feat-705-s2b2b-einreichung
Spec: docs/specs/feat-705-schnitt-2b2b-einreichung.md
Datum: 2026-10-28 09:37

## Checkliste
- [x] **AC-1:** Ohne den Schalter `--einreichen` sendet `asc_beta_invite.py` in keinem Szenario (erster Lauf, zweiter Lauf, bestehende Gruppe, Fehler beim Zuordnen) einen GET oder POST auf `betaAppReviewSubmissions`, und `asc-beta.yml` enthält die Zeichenfolge `betaAppReviewSubmissions` nicht. Geprüft durch `test_without_flag_never_submits`, den unveränderten `test_never_submits_and_never_enables_link` und `test_workflow_file`.
- [ ] **AC-2:** Mit `--einreichen` und bereiten Builds wird je Plattform (iOS, macOS) genau ein POST auf `/v1/betaAppReviewSubmissions` gesendet, dessen Rumpf nur die Beziehung `build` mit der Build-ID trägt; Ausgabe `einreichung plattform=<P> zustand=eingereicht review=WAITING_FOR_REVIEW`, Exit 0. Geprüft durch `test_with_flag_submits_each_platform_once`.
- [x] **AC-3:** Mit `--einreichen` wird der Build zuerst der Gruppe `Tester` zugeordnet und danach genau dieser Build eingereicht (neuester gültiger Build der Plattform, nicht ein anderer in der Gruppe). Geprüft durch `test_assignment_happens_before_submission`.
- [x] **AC-4:** Ein zweiter Lauf mit `--einreichen` schreibt nichts: bei bestehender Einreichung in jedem Zustand (`WAITING_FOR_REVIEW`, `IN_REVIEW`, `APPROVED`, `REJECTED`) kein POST, Zeile `zustand=vorhanden review=<Zustand>`, `zusammenfassung geschrieben=0`. Geprüft durch `test_second_run_sends_no_submission` und `test_existing_submission_in_any_state_is_not_repeated`.
- [x] **AC-5:** Ist `externalBuildState` nicht `READY_FOR_BETA_SUBMISSION` (auch nicht lesbar), wird nicht eingereicht: kein POST, Zeile `zustand=nicht-bereit extern=<Wert>`, Exit 0; gibt es für eine Plattform keinen gültigen Build, steht `zustand=kein-gültiger-build` ohne POST. Geprüft durch `test_not_ready_build_is_not_submitted` und `test_platform_without_valid_build_is_reported`.
- [x] **AC-6:** Antwortet Apple auf die Einreichung mit 409, meldet das Skript `einreichung plattform=<P> zustand=konflikt` und endet mit Exit 0; die andere Plattform wird trotzdem bearbeitet. Geprüft durch `test_conflict_is_a_state_not_a_crash`.
- [x] **AC-7:** Antwortet Apple mit 422 `BETA_CONTRACT_MISSING`, druckt das Skript eine `::error::`-Zeile mit `platform=<P>` und Klartext (Beta-Vereinbarung bei Apple fehlt, der Konto-Inhaber muss sie annehmen), endet mit Exit 1 und wiederholt den POST nicht. Geprüft durch `test_missing_contract_names_the_account_holder`.
- [x] **AC-8:** Antwortet Apple mit 403, enthält die Ausgabe den bestehenden Text „Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen“, Exit ≠ 0. Geprüft durch `test_forbidden_submission_uses_existing_text`.
- [ ] **AC-9:** Eine Plattform verdeckt die andere nicht: schlägt die Einreichung oder Zuordnung der einen Plattform fehl, wird die andere dennoch bearbeitet, die Schlusszeile `zusammenfassung geschrieben=<n>` steht zuletzt, und der Exit-Code ist 1. Geprüft durch `test_one_platform_failing_does_not_hide_the_other_submission`.
- [x] **AC-10:** Die Ausgabe (stdout und stderr) enthält nur Zustandswörter: keine Build-, Gruppen-, App- oder Einreichungs-IDs, keine Buildnummern, keine Links, kein Schlüsselmaterial, auch nicht in den Wiederholungszeilen der geteilten Helfer. Geprüft durch `test_submission_output_has_only_state_words` (und den unveränderten `test_output_has_only_state_words`).
- [x] **AC-11:** `.github/workflows/asc-beta.yml` bietet die Wahl `einreichen` an, der Job `submit` ruft `python3 scripts/asc_beta_invite.py --einreichen` nur bei `inputs.aktion == 'einreichen'` auf (Schlüssel mit `umask 077` und `trap rm`, `ubuntu-latest`), `probe` hängt per `needs` auch an `submit` und läuft nach `success` oder `skipped`; es gibt weiter nur die Eingabe `aktion` und keinen `push`-, `schedule`- oder `workflow_run`-Auslöser; `testflight.yml` nennt `asc_beta_invite` nicht. Geprüft durch den erweiterten `test_workflow_file`.
- [x] **AC-12:** Alle vorhandenen Skripttests (`python3 scripts/test_*.py`) sind grün, und der Diff berührt höchstens die fünf Dateien der Tabelle (±250 LoC) und keinen Pfad der Geräteliste. Geprüft durch die Testausgabe und `git diff --stat`.

## Dialog

### Runde 1
**Adversary:** Zweite Gegenprüfung nach dem Fix von F002. Belege, dass (a) die Tests und die Regression wirklich grün sind, ohne übersprungene; (b) F002 behoben ist, auch mit Rumpfformen jenseits des neuen Tests; (c) beim Bündeln der Einreichungs-Tests über `submit_ok` keine AC-Aussage verloren ging; (d) AC-1, AC-3 bis AC-8, AC-10 bis AC-12 weiter halten; (e) F001 und F003 erledigt sind.
**Implementierer:** (Vom Adversary selbst nachgeprüft, Code gelesen, Läufe selbst gestartet.)
- (a) `python3 scripts/test_asc_beta_invite.py -v` → `Ran 27 tests … OK`, exit 0; alle 28 `scripts/test_*.py` exit 0, keine Zeile `skipped` (`docs/artifacts/feat-705-s2b2b-einreichung/adversary-test-output.txt`).
- (b) Der Zugriff auf den Antwortrumpf steht jetzt in try/except (KeyError, TypeError, AttributeError): Code reference: scripts/asc_beta_invite.py:144. Eigene Proben mit 201 und Rumpf `["x"]`, data als Liste `[1]`, data als Zeichenkette, attributes null, attributes als Zeichenkette, Rumpf `"str"` und `7`: jedes Mal beide Plattformen `zustand=eingereicht review=unbekannt`, je Plattform genau 1 POST, Schlusszeile `zusammenfassung geschrieben=5` zuletzt, exit 0, kein Traceback. Nicht-UTF-8-Rumpf auf 201 → `unbekannt` (ValueError-Zweig Zeile 142). Neuer Test Code reference: scripts/test_asc_beta_invite.py:409 (`test_unexpected_submission_body_is_still_reported`, beide Formen der Vorrunde). F002 in der gemeldeten Form behoben.
- (c) Vergleich mit dem Stand 4f0dba6 der Testdatei: `submit_ok` (Code reference: scripts/test_asc_beta_invite.py:304) prüft exit 0 und jede Zeile, mit Platzhalter p je IOS und MAC_OS. Jede vorher einzeln geprüfte Zeile steht weiter da: eingereicht review=WAITING_FOR_REVIEW je Plattform (Zeile 321), vorhanden je Plattform und `zusammenfassung geschrieben=0` (Zeile 340), vorhanden je Zustand IN_REVIEW/APPROVED/REJECTED (Zeile 348), nicht-bereit PROCESSING und unbekannt je Plattform (Zeile 354), kein-gültiger-build für MAC_OS (Zeile 362), konflikt für IOS (Zeile 371); alle Rückgabecode-Prüfungen bleiben (in `submit_ok`). Die Tests mit erwartetem exit 1 (Zeilen 376, 387, 392) sind unverändert. Keine Aussage verloren.
- (d) AC-1: Schalter nur an einer Stelle gelesen, Code reference: scripts/asc_beta_invite.py:176; `post_submission` nur aus `submit_platform` (Zeile 161). AC-3/AC-5/AC-6/AC-7/AC-8: Code reference: scripts/asc_beta_invite.py:150 (`submit_platform`), 409 → None (Zeile 134), 403 → FORBIDDEN, 422 mit BETA_CONTRACT_MISSING → CONTRACT; eigene Probe: 422 mit nicht dekodierbarem Rumpf, der BETA_CONTRACT_MISSING enthält, ergibt dennoch den Klartext (decode mit errors=replace). AC-11: Code reference: .github/workflows/asc-beta.yml:71 (Job `submit`), Aufruf Zeile 88, `trap`/`umask 077` Zeilen 85/86, `probe` mit `needs: [setup, assign, submit]` Zeile 92. AC-12: hinzugefügte Zeilen ab 02956f4 außerhalb `^docs/` und `^\.github/`: asc_beta_invite.py 79 + test_asc_beta_invite.py 170 + CLAUDE.md 1 = 250 ≤ 250 (`max_loc_delta`; `edit_gate._check_loc_delta` zählt nur hinzugefügte Zeilen). Doku Code reference: CLAUDE.md:108.
- (e) F001: im Index ist nichts vorgemerkt; die fremde Datei `docs/artifacts/fix-580-veraltete-schnittstellen/adversary-dialog.md` ist weiter ungesichert geändert, nach Entscheidung des Tech Leads außerhalb von Commit und PR. Maßgeblich für AC-12 ist die Dateiliste, und die hält. F003: Hinweis „danach `aktion=probe` laufen lassen“ und `review=unbekannt` stehen in Code reference: docs/reference/testflight.md:217.

### Runde 2
**Adversary:** Runde 1 belegt nur, dass die Vorrundenform nicht mehr abstürzt. Jetzt alle neuen Pfade auf weitere Ausnahmen und Fehldeutungen: Fehlerrumpf, der beim Lesen bricht; Protokollfehler, die kein OSError sind; ein gültiger Erfolgsrumpf mit `betaReviewState` null; unerwartete Listenform beim GET der Einreichungen.
**Implementierer:** (Vom Adversary nachgeprüft, drei Befunde.)
- Probe „201, Rumpf data.attributes.betaReviewState = null“ (Unterprozess gegen FakeASC und in-process): `post_submission` gibt None zurück, Code reference: scripts/asc_beta_invite.py:145. None ist zugleich das Zeichen für 409 (Zeile 134), also meldet Code reference: scripts/asc_beta_invite.py:162 `einreichung plattform=IOS zustand=konflikt` und zählt 0, obwohl Apple die Einreichung angenommen hat. Lauf: beide Plattformen `zustand=konflikt`, `zusammenfassung geschrieben=3` statt 5, exit 0, je Plattform 1 POST. Nach einer unumkehrbaren Einreichung steht im Log ein falscher Zustand. → F004.
- In-process-Proben auf `post_submission`: 422, dessen `error.read()` mit `http.client.IncompleteRead` oder `ConnectionResetError` bricht → die Ausnahme entsteht im except-Zweig und entkommt als Nicht-Fatal (Zeile 137); `http.client.BadStatusLine` beim Absenden und `IncompleteRead` beim Lesen eines 201-Rumpfs sind `HTTPException`, kein `OSError`, und entkommen ebenso (Zeilen 131/140). `main` fängt nur Fatal (Code reference: scripts/asc_beta_invite.py:186): Traceback, andere Plattform nicht bearbeitet, keine Schlusszeile. Der 201-Fall trifft nach der Einreichung, gleiche Folge wie F002, nur über die Leitung statt über den Rumpf. → F005.
- GET `betaAppReviewSubmissions?filter[build]` mit `data` als Liste aus Zeichenkette, None oder Objekt mit attributes als Zeichenkette: AttributeError in Code reference: scripts/asc_beta_invite.py:57 (`existing[0].get`). Kein POST (fail closed), aber Traceback, MAC_OS nicht bearbeitet, keine Schlusszeile → AC-9 bricht in dieser Lage. data als Objekt statt Liste dagegen sauber: `get_data` wiederholt und meldet `::error::platform=… App Store Connect did not answer /v1/betaAppReviewSubmissions` je Plattform, Schlusszeile zuletzt, exit 1. → F006.
- Gesehen, aber nicht diesem Schnitt zuzurechnen: `buildBetaDetail` mit data als Liste wirft AttributeError in `read_extern` (Code reference: scripts/asc_beta_invite.py:101); der Ausdruck ist aus `assign_platform` von 2b-1 unverändert verschoben (gleicher Absturz schon in 02956f4 beim Zuordnen).
- Ebenfalls gesehen: ein nicht-textueller `betaReviewState` (etwa ein Objekt) würde ungefiltert in die Zeile gedruckt; Apples Feld ist ein Aufzählungstyp, daher kein eigener Befund.

Finding:
  ID: F004
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/asc_beta_invite.py:162
  Description: post_submission nutzt None als Zeichen für 409 (Zeile 134) und gibt bei einem 201 mit betaReviewState null ebenfalls None zurück (Zeile 145); submit_platform meldet dann zustand=konflikt und zählt 0 Schreibaufrufe.
  Spec requirement: AC-2 — nach erfolgreichem POST die Zeile zustand=eingereicht review=<betaReviewState>; AC-6 — konflikt nur bei 409.
  Conflict: Eine angenommene, unumkehrbare Einreichung wird als Konflikt gemeldet und nicht gezählt (zusammenfassung geschrieben=3 statt 5). Reproduktion: FakeASC.body201 = data.attributes.betaReviewState null, Aufruf mit --einreichen.
  Remediation: 409 mit eigenem Zeichen melden (eigene Konstante oder Tupel) oder den gelesenen Zustand mit `or "unbekannt"` absichern; Test mit betaReviewState null ergänzen (Erwartung eingereicht review=unbekannt, geschrieben=5).

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_beta_invite.py:137
  Description: Im 422-Zweig wird error.read() innerhalb des except-Blocks gelesen; bricht das Lesen (IncompleteRead, ConnectionResetError), entkommt die Ausnahme. Ebenso entkommen http.client.HTTPException-Fälle (BadStatusLine beim Absenden, IncompleteRead beim Lesen des 201-Rumpfs, Zeile 131), weil Zeile 140 nur URLError, TimeoutError und OSError fängt.
  Spec requirement: AC-9 — die andere Plattform wird dennoch bearbeitet, die Schlusszeile steht zuletzt.
  Conflict: Traceback statt ::error::-Zeile, MAC_OS übergangen, keine Schlusszeile; im 201-Fall nach der Einreichung. Selten (Leitungsabbruch), der nächste Lauf heilt (vorhanden).
  Remediation: http.client.HTTPException in die Ausnahmeliste von Zeile 140 aufnehmen und error.read() im 422-Zweig selbst absichern (bei Lesefehler: allgemeine HTTP-422-Meldung).

Finding:
  ID: F006
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_beta_invite.py:57
  Description: plan_submission ruft existing[0].get(...) ohne Typprüfung; ein Listenelement, das kein Objekt ist (oder attributes als Zeichenkette), wirft AttributeError.
  Spec requirement: AC-9 — eine Plattform verdeckt die andere nicht.
  Conflict: Traceback, zweite Plattform nicht bearbeitet, keine Schlusszeile. Kein POST (fail closed), Rumpfform von Apple unwahrscheinlich.
  Remediation: Nicht-Objekte wie eine vorhandene Einreichung mit review=unbekannt behandeln (sicher: kein POST) oder als Fatal melden.

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_beta_invite.py:176
  Evidence: Schalter nur hier gelesen; submit_platform nur bei submitting aufgerufen (Zeile 182); test_without_flag_never_submits (drei Szenarien, je zwei Läufe) und test_never_submits_and_never_enables_link grün; asc-beta.yml ohne betaAppReviewSubmissions (test_workflow_file).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/test_asc_beta_invite.py:330
  Evidence: Build-ID fließt aus assign_platform direkt in submit_platform; Test prüft je Build die Reihenfolge Zuordnung → Einreichung, alter Gruppenbuild B-91f3-OLD wird nicht eingereicht; Vorrundenprobe: scheitert die Zuordnung, kein GET/POST auf Einreichungen für diesen Build.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/test_asc_beta_invite.py:340
  Evidence: Zweiter Lauf nur GET, vorhanden review=WAITING_FOR_REVIEW je Plattform, geschrieben=0; Zeile 348 für IN_REVIEW, APPROVED, REJECTED ohne POST.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/test_asc_beta_invite.py:354
  Evidence: PROCESSING und unlesbarer Status (404 → unbekannt) ergeben nicht-bereit ohne POST, exit 0; Zeile 362 kein-gültiger-build für MAC_OS ohne POST.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_asc_beta_invite.py:371
  Evidence: 409 auf iOS → konflikt, exit 0, macOS eingereicht. (Die Fehldeutung in der Gegenrichtung steht in F004.)
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_asc_beta_invite.py:376
  Evidence: genau eine ::error::platform=IOS-Zeile mit Beta-Vereinbarung und Konto-Inhaber, exit 1, genau 1 iOS-POST; eigene Probe auf macOS und mit nicht dekodierbarem Rumpf ebenfalls Klartext.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_asc_beta_invite.py:387
  Evidence: 403 → bestehender FORBIDDEN-Text, exit ungleich 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/test_asc_beta_invite.py:400
  Evidence: Ausgaben dreier Läufe ohne G-7c41, B-91f3, S-5d2e, 4711/4712, APP1, Link, Schlüsselmaterial; Vorrundenprobe: GET-Wiederholungszeilen ohne ID; Fehlertexte von post_submission nennen nur den festen Pfad.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: .github/workflows/asc-beta.yml:92
  Evidence: Wahl einreichen (Zeile 21), Job submit Zeile 71 mit if inputs.aktion == 'einreichen', ubuntu-latest, trap/umask 077, einziger Aufruf mit --einreichen Zeile 88; probe needs setup/assign/submit, läuft bei success oder skipped; test_workflow_file grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: CLAUDE.md:108
  Evidence: 28 Skripttests exit 0, keine übersprungen; Diff der Spec-Dateien: asc_beta_invite.py, test_asc_beta_invite.py, asc-beta.yml, testflight.md (Code reference: docs/reference/testflight.md:211), CLAUDE.md; hinzugefügte Zeilen außerhalb docs/ und .github/ = 250 ≤ 250; kein Pfad der Geräteliste. Gilt unter der Bedingung, dass die fremde Datei aus fix-580 nicht in den Commit geht (Index derzeit leer). Ein Fix von F004 bis F006 muss innerhalb der Grenze bleiben (das Gate zählt gegen HEAD 4f0dba6, also mit Luft).
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: BROKEN

Finding F004 (MEDIUM): 201 mit betaReviewState null wird als zustand=konflikt gemeldet und nicht gezählt, obwohl die unumkehrbare Einreichung erfolgt ist (scripts/asc_beta_invite.py:145 und 162).
Finding F005 (LOW): Lesefehler im 422-Zweig und http.client.HTTPException entkommen post_submission als Traceback (scripts/asc_beta_invite.py:137 und 140), AC-9 bricht in dieser Lage.
Finding F006 (LOW): GET der Einreichungen mit Nicht-Objekt in data → AttributeError (scripts/asc_beta_invite.py:57), AC-9 bricht, kein POST.
F002 (Vorrunde) behoben, F001 per Entscheidung außerhalb des Commits, F003 behoben.
Tests: 27 bestanden, 0 fehlgeschlagen, 0 übersprungen (test_asc_beta_invite.py); Regression 28 von 28 Dateien exit 0.
Checkliste: 10 von 12 belegt; AC-2 und AC-9 in Randfällen widerlegt (F004, F005, F006).

## Geprüfte Dateien

- sha256:8cb792fba3b3a83147d7e5a0fedc76c7ec53f2d33376c1ba1f0483e28767f36d  .github/workflows/asc-beta.yml
- sha256:bda0f6fbaf2b8b8270b7de66101b6cb26e94fb345636b82cf25b813fefc8d166  CLAUDE.md
- sha256:50740d1b52f2bc7910b9ee011f87b0f410e84f11e7559839c903c575157dfb1c  scripts/asc_beta_invite.py
- sha256:fe0da7ee72f7bfbbb8344725bd4c151be8714828934f43feaddaf4c48539d45c  scripts/test_asc_beta_invite.py

## Prüfbasis

- base: 02956f433eee05f2ca61dec1a1fcc7e174b2d37a
- blob:b84cf71301f1e9d9a40c5da43c65af24735a4512  .github/workflows/asc-beta.yml
- blob:cd75f51e49ededae27d5140bb00349e65d2dbb4d  CLAUDE.md
- blob:edf8eea8dbd0094edce8722f80827ea279d057e7  scripts/asc_beta_invite.py
- blob:80ae3f158230c8058bcb9074bcd6b7c373c101c8  scripts/test_asc_beta_invite.py
