# Adversary Dialog — feat-893-b-einreichen
Spec: docs/specs/feat-893-schnitt-b-einreichen.md
Datum: 2026-11-10 07:10

## Checkliste
- [x] **AC-1:** Given beide Plattformen bereit und `einreichen 1.0.1`, When der Lauf startet, Then laufen je Plattform POST Einreichung, POST Item und PATCH `submitted` in dieser Reihenfolge, iOS vollständig vor MAC_OS, die Gegenprobe zeigt `WAITING_FOR_REVIEW` und der Ausgang ist 0. Belegt durch `test_einreichen_success_both_platforms_ios_first`.
- [x] **AC-2:** Given eine fehlende, leere oder von der Zielversion abweichende Nummer, When `einreichen` läuft, Then endet der Lauf mit Ausgang 1 ohne jeden Schreibaufruf. Belegt durch `test_confirmation_must_equal_version_number`.
- [x] **AC-3:** Given eine Plattform ist nicht bereit, When `einreichen` läuft, Then werden die Gründe genannt, der Ausgang ist 1 und es gibt bei beiden Plattformen keinen Schreibaufruf. Belegt durch `test_one_platform_not_ready_writes_nothing_on_both`.
- [x] **AC-4:** Given iOS ist schon eingereicht (Version und Einreichung `WAITING_FOR_REVIEW`) und Mac ist bereit, When `einreichen` läuft, Then wird iOS übersprungen, nur Mac geschrieben und der Ausgang ist 0. Belegt durch `test_resume_ios_already_submitted_only_mac`.
- [x] **AC-5:** Given genau eine `READY_FOR_REVIEW`-Einreichung ohne Item oder mit genau unserem Item, When `einreichen` läuft, Then wird sie wiederverwendet (kein neuer POST Einreichung, POST Item nur bei leerer Einreichung) und abgeschickt. Belegt durch `test_reuses_single_ready_for_review_submission`.
- [x] **AC-6:** Given eine Einreichung mit einem fremden Item, When `einreichen` läuft, Then bricht der Lauf mit klarer Meldung und Ausgang 1 ab, ohne Item hinzuzufügen, abzuschicken oder zu löschen. Belegt durch `test_foreign_item_aborts_without_delete`.
- [x] **AC-7:** Given 5xx oder Netzfehler bei POST Einreichung, POST Item oder PATCH, When `einreichen` läuft, Then wird der betroffene Aufruf genau einmal versucht, nie wiederholt, der Ausgang ist 1 mit klarer Meldung, und Mac wird nach einem iOS-Fehler nicht versucht. Belegt durch `test_no_retry_on_5xx_or_network_error`.
- [x] **AC-8:** Given 409 oder 422 von Apple, When `einreichen` läuft, Then nennt die Meldung Aufruf und Fehlercodes, nie die Rohantwort, der Ausgang ist 1 und es folgt kein weiterer Schreibaufruf. Belegt durch `test_409_and_422_clear_message_without_raw_answer`.
- [x] **AC-9:** Given der PATCH gelingt, die Zustände erreichen aber nicht `WAITING_FOR_REVIEW` oder weiter, When die Gegenprobe ausgewertet ist, Then ist der Ausgang 1 mit den Zustandswörtern; ein verzögerter Wechsel innerhalb der begrenzten Versuche genügt. Belegt durch `test_counter_check_failure_exit_one`.
- [x] **AC-10:** Given ein Lauf mit oder ohne Fehler, When die Ausgabe geprüft wird, Then enthält sie nur Zustandswörter, Zahlen und `releaseType`, nie Kennungen, Rohantwort, Store-Wortlaut oder Schlüssel. Belegt durch `test_output_has_no_ids_raw_answers_or_wording`.
- [x] **AC-11:** Given jeder Lauf von `einreichen`, When das Aufrufprotokoll geprüft wird, Then enthält es nur GET, POST `reviewSubmissions`, POST `reviewSubmissionItems` und PATCH `reviewSubmissions/{id}`, nie DELETE und nie eine Änderung an Versionen, Texten, Bildern, Review-Detail oder Bau. Belegt durch `test_never_deletes_or_touches_other_resources`.
- [x] **AC-12:** Given ein erfolgreicher Lauf, When `einreichen 1.0.1` erneut läuft, Then sind beide Plattformen `eingereicht`, es gibt keinen Schreibaufruf und der Ausgang ist 0. Belegt durch `test_second_run_writes_nothing`.
- [x] **AC-13:** Given die Änderung, When `pruefen` und eine falsche Benutzung geprüft werden, Then verhält sich `pruefen` unverändert (alle Tests aus Schnitt A grün), und keine, eine unbekannte Aktion oder `pruefen` mit Zusatzargument enden mit `::error::Aufruf: asc_store_submit.py pruefen|einreichen <nummer>` und Ausgang 1 ohne Anfrage. Belegt durch `test_pruefen_unchanged` und `test_bad_usage_makes_no_call`.
- [x] **AC-14:** Given die Workflow-Datei, When sie geprüft wird, Then bietet `aktion` `pruefen` und `einreichen`, die Eingabe `bestaetigung` existiert, `concurrency` nutzt die Gruppe `asc-store-submit` ohne Abbruch laufender Läufe, die Python-Tests laufen als erster Schritt, der Handlaufschritt hängt an `workflow_dispatch` und der Schlüssel wird nie ausgegeben. Belegt durch `test_workflow_offers_einreichen_with_confirmation_and_hides_the_key`.
- [x] **AC-15:** Given die Änderung, When `asc_store_version.py` und sein Test geprüft werden, Then sind beide unverändert, der Wächtertest „nie einreichen“ ist grün, und die Abnahme endet nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“ Belegt durch `test_store_version_script_untouched` und die Läufe von `python3 scripts/test_asc_store_submit.py`, `python3 scripts/test_asc_store_version.py` und `python3 scripts/test_asc_version_texts.py`.

## Dialog

### Runde 1
**Adversary:** Ich unterstelle: der Code ist kaputt. Angriffe und Befunde (Code gelesen, Tests selbst gelaufen):
1. Wiederholung eines Schreibaufrufs: `send_json`/`send` kommen im Skript nicht vor (nur `get_data`/`error_codes` importiert). Alle drei Schreibwege laufen über `send_once` (ein `urlopen`, keine Schleife). 5xx, 408, 429, URLError, HTTPException, TimeoutError, OSError enden als `Fatal`. 3xx: urllib folgt PATCH/POST bei 307/308 nicht, wird HTTPError, Fatal.
2. Fail-closed vor dem ersten Schreiben: `plan_platform` für beide Plattformen vor jeder Schreibschleife; unbekannte Zustände (`belegt, unbekannter Zustand`), mehrere READY_FOR_REVIEW (`mehrdeutig`), unbekannte Item-Form (`related_version` gibt None, also fremd), `include` ohne Verknüpfung (also fremd, Abbruch), Antwort ohne `data`-Liste (get_data wirft Fatal im Plan). Ein Grund einer nicht eingereichten Plattform ergibt `blocked`, Ausgang 1, vor `write_platform`.
3. Bestätigung: Vergleich exakt `versionString != number`. Eigene Probe (Scratchpad probe.py) mit `1.0.1 `, ` 1.0.1`, `v1.0.1`, `1.0.1\n`, `1.0.01`: jeweils Ausgang 1, keine Schreibaufrufe. Leer/nur Leerzeichen: `number.strip()` bricht vor jedem Aufruf ab.
4. Ausgabe: `Masked` filtert stdout (Kennung nach `/v1/<art>/` und `?name=`); `send_once` nennt den Pfad, maskiert; Rohtext nie, nur `errors[].code` nach Regex `[A-Z0-9_.]+`, höchstens 5. Fatal-Pfade laufen durch `message()`.
5. Workflow: `inputs.bestaetigung` und `inputs.aktion` nur über `env:` (BESTAETIGUNG/AKTION), im Skript als `"$BESTAETIGUNG"` in Anführungszeichen; kein `${{ inputs.* }}` im run-Block. Prüfung auf leer vor `umask` und vor dem Schreiben des Schlüssels. Das Schlüssel-Secret steht inline wie schon vorher.
6. Gegenprobe: `VERIFY_ATTEMPTS = 6`, Abstand `config["poll"]`, nur `get_one` (GET), keine Rücknahme; Fatal beim Lesen gibt Zusammenfassung und Ausgang 1.
7. Abweichungen des Entwicklers: (a) Items im Plan statt in write_platform: sicherer, weil ein fremdes Item beide Plattformen vor dem ersten Schreiben anhält (Spec: ein Grund bricht beide ab). (b) "eingereicht" verlangt, dass das einzige Item genau unsere Version ist: strenger als die Spec, fail-closed (sonst `bearbeitbare Versionen=0`, Ausgang 1). (c) Gegenprobe direkt nach jeder Plattform: stoppt Mac, wenn iOS nicht bestätigt; spec-konform bzw. sicherer. (d) include=appStoreVersion: nötig, damit die Verknüpfung geliefert wird.
Findings:
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_submit.py:237
  Description: `item_targets` verlässt sich darauf, dass Apple mit `include=appStoreVersion` die Verknüpfung `relationships.appStoreVersion.data` liefert; fehlt sie, gilt jedes Item als fremd.
  Spec requirement: AC-12 — zweiter Lauf erkennt eingereicht ohne Schreibaufruf
  Conflict: Ist Apples echte Form anders, wird beim zweiten Lauf `submitted_plan` None, der Lauf endet mit Ausgang 1 statt 0 (nie mit Schreibaufruf). Nur eine Idempotenz-, keine Sicherheitslücke.
  Remediation: Beim echten Lauf beobachten (Spec-Punkt 9); Skript korrigieren, nicht den Nachbau.
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_submit.py:304
  Description: `make_token` steht vor dem `try` in `send_once`; ein nicht-Fatal-Fehler (z. B. OSError beim Schlüssel) gäbe einen Traceback ohne `zusammenfassung`-Zeile. Es wird dann nichts geschrieben (Token wird vor dem Request gebaut), Ausgang nicht 0.
  Spec requirement: AC-10 — Ausgabe nur Zustandswörter
  Conflict: Traceback könnte Pfadnamen zeigen, keine Geheimwerte; read_config prüft die Datei vorher.
  Remediation: optional `except OSError` in main.
**Implementierer:** Beweise: `python3 scripts/test_asc_store_submit.py` 26 Tests OK; `test_einreichen_success_both_platforms_ios_first` (AC-1, write_platform :323, einreichen :365), `test_confirmation_must_equal_version_number` (AC-2, :368/:273), `test_one_platform_not_ready_writes_nothing_on_both` (AC-3, :375), `test_resume_ios_already_submitted_only_mac` (AC-4, submitted_plan :249), `test_reuses_single_ready_for_review_submission` (AC-5, :326/:337), `test_foreign_item_aborts_without_delete` (AC-6, :279), `test_no_retry_on_5xx_or_network_error` (AC-7, 9 Fälle, genau ein Treffer, send_once :301), `test_409_and_422_clear_message_without_raw_answer` (AC-8, error_codes), `test_counter_check_failure_exit_one` (AC-9, verify_platform :351), `test_einreichen_output_has_no_ids_raw_answers_or_wording` (AC-10), `test_never_deletes_or_touches_other_resources` (AC-11), `test_second_run_writes_nothing` (AC-12), `test_pruefen_unchanged` und `test_bad_usage_makes_no_call` (AC-13, main :398), `test_workflow_offers_einreichen_with_confirmation_and_hides_the_key` (AC-14), `test_store_version_script_untouched` (AC-15). git zeigt `asc_store_version.py` und beide Testdateien unverändert.

### Runde 2
**Adversary:** Zweite Runde, gezielt gegen die Lücken der ersten.
- Doppelte Einreichung nach Teilausfall: PATCH liefert 5xx, obwohl Apple annahm: nächster Lauf sieht Version und Einreichung WAITING_FOR_REVIEW mit einzigem Item = unsere Version, also `eingereicht`, kein Schreibaufruf. POST Einreichung bricht ab, Apple hat angelegt: nächster Lauf sieht genau eine READY_FOR_REVIEW, Wiederverwendung. Zwei verwaiste READY: `mehrdeutig`, blockiert. Kein Weg zu einer zweiten Einreichung.
- Reihenfolge und Nicht-Atomarität: `plans` ist ein dict in PLATFORMS-Reihenfolge (IOS, MAC_OS); bei iOS-Fehler oder Gegenprobe-Fehler kein Zugriff auf Mac.
- Bestätigung bei bereits eingereichter Plattform: `submitted_plan` vergleicht die Nummer exakt; `same_number` zählt eingereichte Plattformen nicht, aber die Bestätigung gegen beide Plattformen deckt es ab (abweichende Nummer auf der offenen Plattform: Grund `bestätigung ungleich`).
- Items-Form: `[id, id]`, `[None]`, fremder Typ: alle ungleich `[]` und `[id]`, also Grund.
- Gegenprobe läuft auch für `eingereicht`-Plattformen, 6 Versuche, Fatal beim GET gibt Zusammenfassung plus Ausgang 1. Kein DELETE im Code, nur drei send_once-Aufrufe.
- Shell-Injection: kein `${{ inputs.* }}` im run-Block; `"$BESTAETIGUNG"` in Anführungszeichen; Aktion per `[ "$AKTION" = einreichen ]`.
- Fazit: keine Spec-Verletzung, keine Sicherheitslücke. F001 und F002 bleiben LOW.
Confirmation:
  AC: AC-1
  Code reference: scripts/asc_store_submit.py:365
  Evidence: einreichen schreibt je Plattform in PLATFORMS-Reihenfolge POST, POST Item, PATCH; Gegenprobe; Ausgang 0 nur nach beiden.
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: scripts/asc_store_submit.py:273
  Evidence: exakter Vergleich der Nummer, eigene Probe mit fünf Varianten: Ausgang 1, keine Schreibaufrufe.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: scripts/asc_store_submit.py:375
  Evidence: blocked ergibt Rückgabe 1 vor write_platform.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: scripts/asc_store_submit.py:249
  Evidence: submitted_plan überspringt Schreiben, state eingereicht.
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: scripts/asc_store_submit.py:337
  Evidence: has_item überspringt POST Item, gesetzte Einreichung überspringt POST Einreichung.
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: scripts/asc_store_submit.py:279
  Evidence: Fremdes Item ergibt Grund im Plan, kein Schreiben.
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: scripts/asc_store_submit.py:301
  Evidence: send_once ohne Wiederholung, Fatal bei jedem Fehler, einreichen bricht ab.
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: scripts/asc_store_submit.py:311
  Evidence: nur error_codes im Text, nie Rohantwort.
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: scripts/asc_store_submit.py:351
  Evidence: 6 Versuche, Ausgang 1 bei falschem Zustand.
  Status: CONFIRMED
Confirmation:
  AC: AC-10
  Code reference: scripts/asc_store_submit.py:416
  Evidence: sys.stdout = Watched(Masked) filtert Kennungen.
  Status: CONFIRMED
Confirmation:
  AC: AC-11
  Code reference: scripts/asc_store_submit.py:323
  Evidence: nur drei send_once-Aufrufe (POST, POST, PATCH), kein DELETE.
  Status: CONFIRMED
Confirmation:
  AC: AC-12
  Code reference: scripts/asc_store_submit.py:257
  Evidence: zweiter Lauf: eingereicht, keine Schreibaufrufe.
  Status: CONFIRMED
Confirmation:
  AC: AC-13
  Code reference: scripts/asc_store_submit.py:398
  Evidence: Aufrufzeile nennt beide Aktionen, Argumentanzahl je Aktion geprüft.
  Status: CONFIRMED
Confirmation:
  AC: AC-14
  Code reference: .github/workflows/asc-store-submit.yml:54
  Evidence: BESTAETIGUNG über env, leer bricht vor dem Schlüssel ab, concurrency unverändert.
  Status: CONFIRMED
Confirmation:
  AC: AC-15
  Code reference: CLAUDE.md:113
  Evidence: Zeile beschreibt einreichen; asc_store_version.py und Test unverändert, drei Testläufe grün (adversary-test-output.txt).
  Status: CONFIRMED
**Implementierer:** Testausgabe docs/artifacts/feat-893-b-einreichen/adversary-test-output.txt: test_asc_store_submit 26 OK, test_asc_store_version 22 OK, test_asc_version_texts 29 OK (77 Tests, 0 Fehler, 0 übersprungen). Keine Änderung nötig; F001 wird im echten Lauf (Spec Punkt 9) beobachtet.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Umsetzung hielt dem Angriff stand. Tests: 77 bestanden, 0 fehlgeschlagen, 0 übersprungen. Edge Cases: Wiederholung, Teilausfall, Bestätigungsvarianten, Item-Formen, Ausgabe, Shell-Injection geprüft, nichts gebrochen. Regressionen: keine (asc_store_version.py und beide Testdateien unverändert). Checkliste: 15/15 bewiesen. Offen nur zwei LOW-Hinweise (F001, F002). Die Abweichungen des Entwicklers sind strenger bzw. sicherer als die Spec.

## Geprüfte Dateien

- sha256:7d6e659621a6c4bc9cad69adbd549e7ff9c9cb2e0a31b711cb4b43a5c92c27e3  .github/workflows/asc-store-submit.yml
- sha256:1d714330471aff980f294de07ab93dc41fd7ccb084e082baba1be338be1ad8de  CLAUDE.md
- sha256:4798866cd5187ccd5eda6615168d035e1dbf336382a08dc9801d42ccc70a4c5b  scripts/asc_store_submit.py

## Prüfbasis

- base: d7072d5509c049c6d7acb162b5ee0b6f64be21ec
- blob:b7f4225d3914a107517dcdba156933579bc0517b  .github/workflows/asc-store-submit.yml
- blob:24a80a27b17c88053c5c76331bf93c8f42368180  CLAUDE.md
- blob:ee0722518c1508e211e752fd768bdc6bb7507984  scripts/asc_store_submit.py

## Geprüfte Dateien

- sha256:7d6e659621a6c4bc9cad69adbd549e7ff9c9cb2e0a31b711cb4b43a5c92c27e3  .github/workflows/asc-store-submit.yml
- sha256:1d714330471aff980f294de07ab93dc41fd7ccb084e082baba1be338be1ad8de  CLAUDE.md
- sha256:4798866cd5187ccd5eda6615168d035e1dbf336382a08dc9801d42ccc70a4c5b  scripts/asc_store_submit.py

## Prüfbasis

- base: d7072d5509c049c6d7acb162b5ee0b6f64be21ec
- blob:b7f4225d3914a107517dcdba156933579bc0517b  .github/workflows/asc-store-submit.yml
- blob:24a80a27b17c88053c5c76331bf93c8f42368180  CLAUDE.md
- blob:ee0722518c1508e211e752fd768bdc6bb7507984  scripts/asc_store_submit.py
