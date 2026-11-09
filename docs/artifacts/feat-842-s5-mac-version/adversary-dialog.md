# Adversary Dialog — feat-842-s5-mac-version
Spec: docs/specs/feat-842-schnitt-5a-1-mac-version-anlegen.md
Datum: 2026-11-09 11:34

## Checkliste
- [x] **AC-1:** Given iOS 1.0.1 im Zustand `PREPARE_FOR_SUBMISSION` und keine bearbeitbare Mac-Version, When `anlegen` läuft, Then entsteht genau ein `POST /v1/appStoreVersions` mit `platform` `MAC_OS`, `versionString` gleich der iOS-Zielversion (1.0.1) und Relation `app`, und danach gibt es genau eine bearbeitbare Mac-Version dieser Nummer. Belegt durch `test_anlegen_creates_mac_version_with_ios_number`.
- [x] **AC-2:** Given eine bearbeitbare Mac-Version mit der Zielversion existiert schon, When `anlegen` läuft (auch wiederholt), Then wird keine zweite angelegt und die Zeile „schon vorhanden, übersprungen“ erscheint. Belegt durch `test_anlegen_does_not_create_second_mac_version`.
- [x] **AC-3:** Given eine bearbeitbare Mac-Version mit anderer Nummer als iOS, oder keine oder mehrere bearbeitbare iOS-Versionen, When `anlegen` läuft, Then bricht es mit `::error::` und nennender Meldung ab, ohne einen Nicht-GET-Aufruf. Belegt durch `test_anlegen_fails_on_mac_version_mismatch` und `test_anlegen_fails_without_or_with_several_ios_versions`.
- [x] **AC-4:** Given Bauten verschiedener Plattform, Version, Zustand und Ablauf, When `anlegen` einer Version ohne Bau einen zuordnet, Then ist es ein Bau der passenden Plattform mit Vorabversion gleich der Zielversion, `processingState` `VALID` und nicht abgelaufen; bei mehreren gilt die höchste Buildnummer (numerisch), und die Wahl steht im Log. Zugeordnet wird per `PATCH /v1/appStoreVersions/{id}/relationships/build`. Belegt durch `test_build_is_picked_by_platform_version_and_valid` und `test_build_highest_number_wins_and_is_logged`.
- [x] **AC-5:** Given eine Version hat schon einen Bau, When `anlegen` läuft, Then bleibt dieser unverändert (kein PATCH auf diese Version, auch wenn ein neuerer gültiger Bau existiert) und das Log nennt ihn. Belegt durch `test_existing_build_is_left_alone`.
- [x] **AC-6:** Given für eine Plattform existiert kein passender gültiger Bau der Zielversion, When `anlegen` läuft, Then bricht es mit `::error::` ab, nennt Plattform und Version und hat vorher weder eine Mac-Version angelegt noch einen Bau zugeordnet. Belegt durch `test_no_matching_build_is_fatal_and_writes_nothing`.
- [x] **AC-7:** Given Apple antwortet auf einen Schreibaufruf mit 403 oder 409, When das Skript scheitert, Then nennt die Meldung den Grund (und bei 409 `errors[].code`), nie Apples Rohantwort. Belegt durch `test_write_errors_are_clear_without_raw_answer`.
- [x] **AC-8:** Given der Lauf hat angelegt und zugeordnet, When die Gegenprobe läuft, Then existiert die Mac-Version genau einmal bearbeitbar mit der Zielversion und beide bearbeitbaren Versionen haben einen Bau der Zielversion, sonst `Fatal` mit Plattform, Soll und Ist; danach folgt dieselbe Ausgabe wie `lesen`. Belegt durch `test_verification_fails_on_deviation`.
- [x] **AC-9:** Given `lesen`, When es läuft, Then zeigt die Ausgabe je Version Zustand und Bau (oder „kein Bau“), je Lokalisierung Zeichenzahlen der Felder `description`, `keywords`, `promotionalText`, `whatsNew`, `supportUrl` (nie den Wortlaut), Zahl der Bildsätze, Bilder und Platzierungen und ob ein Review-Detail existiert, und die Anfragen bestehen nur aus GET. Belegt durch `test_lesen_reports_state_and_never_writes`.
- [x] **AC-10:** Given jeder Lauf von `anlegen` und `lesen`, When die Anfragen geprüft werden, Then enthalten sie nie `DELETE`, nie eine Einreichung und keinen Schreibaufruf auf Texte, Bilder, Platzierungen oder das Review-Detail; die einzigen Schreibaufrufe sind `POST /v1/appStoreVersions` (nur `MAC_OS`) und `PATCH …/relationships/build`. Eine unbekannte Aufrufform endet mit Ausgang 1 ohne Anfrage. Belegt durch `test_never_deletes_submits_or_writes_texts` und `test_bad_usage_makes_no_call`.
- [x] **AC-11:** Given die Workflow-Datei, When sie geprüft wird, Then bietet `aktion` `lesen` (Standard) und `anlegen`, es gibt `concurrency` ohne `cancel-in-progress`, die Python-Tests laufen als erster Schritt, und der Schlüssel wird nie ausgegeben. Belegt durch `test_workflow_offers_both_actions_and_hides_the_key`.
- [x] **AC-12:** Given der Zweig ist im Remote und die Läufe aus Punkt 6 gehören zu dieser Fassung, When vom Zweig `lesen`, `anlegen`, `anlegen` (zweites Mal), `lesen` und die Store-Probe laufen, Then besteht jeder Lauf; das erste `anlegen` legt die Mac-Version 1.0.1 an und ordnet fehlende Bauten zu, das zweite legt und ordnet nichts, das `lesen` danach zeigt beide bearbeitbaren Versionen 1.0.1 mit Bau 133 (oder dem gewählten Bau der Zielversion) samt Lokalisierungen, Bildsätzen und Review-Detail-Stand, und die Store-Probe zeigt Mac 1.0.1 `PREPARE_FOR_SUBMISSION`. Belegt durch Run-IDs und zitierte Protokollzeilen unter `docs/artifacts/feat-842-s5-mac-version/`; erst danach der Merge.
- [x] **AC-13:** Given die Änderung berührt nur `scripts/` und `.github/workflows/`, When der Schnitt abgenommen wird, Then endet die Abnahme nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“; der „Benutzen“-Beleg sind die echten Handläufe aus AC-12 gegen Apple. Auf Hennings Geräten läuft nichts. `python3 scripts/test_asc_store_version.py` und die übrigen Skript-Tests (`scripts/test_asc_version_texts.py`, `scripts/test_asc_store_images.py`, `scripts/test_asc_store_probe.py`) sind grün. Belegt durch Dateiliste des Diffs gegen die Geräteliste und die Testläufe.

## Dialog

### Runde 1
**Adversary:**
Tests: `python3 scripts/test_asc_store_version.py -v` 14 Tests OK; test_asc_version_texts 19 OK, test_asc_store_images 26 OK, test_asc_store_probe 20 OK, 0 übersprungen (Ausgabe: docs/artifacts/feat-842-s5-mac-version/adversary-test-output.txt). Early-Agreement-Skepsis: Ich habe nicht auf die Tests vertraut, sondern den Code je AC gelesen.

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_store_version.py:172
  Evidence: POST /v1/appStoreVersions nur bei `mac is None`, Payload platform MAC_OS, versionString = iOS-Ziel, Relation app; Zeile 176 prüft danach genau eine bearbeitbare Mac-Version (the_mac_version, Z.134-140). Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_store_version.py:179
  Evidence: Ist `mac` vorhanden, gibt es keinen POST, Zeile „schon vorhanden, übersprungen“. Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_store_version.py:88
  Evidence: plan_mac_version wirft Fatal bei fehlender iOS-Version (Z.91) oder abweichender Mac-Nummer (Z.94) vor jedem Schreiben; mehrere iOS-Versionen wirft editable_version (asc_version_texts.py:110ff). Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_store_version.py:100
  Evidence: Filter plattform/version/VALID/expired=false serverseitig UND nochmals clientseitig (Z.106); Wahl numerisch über int-Liste (Z.110), nicht textlich: "133" schlägt "99"; Log Z.111; PATCH Z.130. Nicht numerische Buildnummern werden still verworfen (siehe F002). Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_store_version.py:164
  Evidence: Vorhandener Bau (GET /build) → kein pick_build, kein PATCH, Log nennt ihn. Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/asc_store_version.py:169
  Evidence: Beide pick_build-Aufrufe (iOS und Mac) laufen in der Planschleife Z.163-169, vor dem ersten POST (Z.172); fehlender Bau → Fatal Z.109. Gesamte Planung (app_versions, beide /build, beide /builds, iOS-Ziel) ist GET. Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/asc_store_version.py:115
  Evidence: send() fängt 403/409 und baut eigene Meldung; nur `(codes: …)` aus send_json (asc_what_to_test.py:53) wird übernommen, kein Rohkörper. Andere 4xx: Meldung nur mit Status und Pfad. Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/asc_store_version.py:143
  Evidence: verify() prüft genau eine bearbeitbare Mac-Version und je Plattform Soll/Ist des Baus (Z.152), dann read_state (Z.184). Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/asc_store_version.py:55
  Evidence: report_version gibt Bau, nur Zeichenzahlen (len), Bildsätze, Bilder, Platzierungen, Review-Detail aus; ausschließlich get_data/get_one/get_json (GET). Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/asc_store_version.py:188
  Evidence: Einzige Schreibstellen sind Z.172 (POST, fest MAC_OS) und Z.130 (PATCH build); kein DELETE-Pfad im Modul; Aufrufprüfung Z.190 vor read_config, also vor jeder Anfrage. Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: .github/workflows/asc-store-version.yml:20
  Evidence: concurrency group ohne cancel-in-progress=true (false), Default lesen (Z.15), Unit-Tests erster Schritt (Z.35), Schlüssel nur in Datei mit umask 077 und trap rm, Muster identisch zu asc-version-texts.yml/asc-store-images.yml; aktion läuft über env, nicht per Interpolation in die Shell. Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: scripts/test_asc_store_version.py:178
  Evidence: Diff berührt nur scripts/, .github/workflows/ und docs/ (keine Pfade der Geräteliste); alle vier Skript-Tests grün (siehe oben). Status: CONFIRMED

AC-12 bleibt offen: echte Handläufe vom Zweig fehlen (braucht Commit+Push).

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_version.py:184
  Description: Nach den Schreibaufrufen läuft read_state (inkl. `/placements`-Abfragen, Z.68). `count` wirft bei einem 4xx Fatal; die Store-Probe (asc_store_probe.py:48) behandelt dieselbe Abfrage dagegen als „fehler, Lauf geht weiter“. Ein Fehler in einer reinen Anzeige-Abfrage ließe `anlegen` mit Exit 1 enden, obwohl alles geschrieben und per verify bewiesen ist.
  Spec requirement: AC-8 — Gegenprobe, danach dieselbe Ausgabe wie lesen
  Conflict: Kein Datenverlust, ein erneuter Lauf ist idempotent; nur irreführender Fehlschlag.
  Remediation: Anzeige-Abfragen nach der Gegenprobe tolerant (Zeile „fehler“) statt Fatal; im Handlauf zuerst `lesen` fahren, das genau diese Pfade prüft.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_version.py:106
  Description: Builds ohne numerische Nummer werden still verworfen; kein Log, wie viele. Außerdem `limit=50` ohne Seitenwechsel (get_data paginiert nicht) bei unbestimmter Apple-Standardsortierung. Bei mehr als 50 gültigen Bauten derselben Version könnte der höchste fehlen.
  Spec requirement: AC-4 — höchste Buildnummer
  Conflict: Für 1.0.1 (wenige Bauten, Build 133) unerheblich; theoretische Falschwahl.
  Remediation: `sort=-uploadedDate` oder Warnzeile bei verworfenen/50 Treffern.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_version.py:31
  Description: get_one behandelt ein HTTP 404 auf `/appStoreVersions/{id}/build` als „kein Bau“. Ein unerwartetes 404 für einen vorhandenen Bau würde zu einem PATCH führen, der einen Bau umhängt. Apple antwortet laut Spec mit `data: null`, 404 ist nur Fremdform.
  Spec requirement: AC-5 — vorhandener Bau nie umhängen
  Conflict: Nur bei fehlerhafter Apple-Antwort; der Handlauf `lesen` vorab prüft die Form.
  Remediation: 404 nur für Review-Detail tolerieren, für /build Fatal.

Weitere Prüfungen ohne Befund: Halbzustand nach POST (the_mac_version Z.176 oder PATCH scheitert) ist möglich, aber unvermeidbar und beim Wiederholen idempotent (Mac-Version vorhanden, Bau fehlt → nur Zuordnung); alle Plan-GETs liegen vor Z.172. Eine Mac-Version in Prüfzuständen (WAITING_FOR_REVIEW, DEVELOPER_REJECTED) zählt nicht als bearbeitbar: POST würde dann von Apple mit 409 abgelehnt, nie eine zweite Version. Kein Pfad für iOS-Anlage, DELETE, Einreichung, Text-/Bild-/Review-Schreibzugriffe. Fehlertexte enthalten nie Rohantwort oder Schlüssel (asc_what_to_test.py:54 nur Status, Pfad, Codes).

**Nachprüfung F001/F003:** F001 und F003 sind behoben. Ergebnis: kein neuer Defekt.
- F003 behoben: `get_one` macht aus HTTP 404 nur noch bei `missing_ok_404=True` (allein Review-Detail) „keine“; für `/build` und `/preReleaseVersion` ist ein 404 Fatal ohne Schreiben. Das gilt auch in der Gegenprobe (`verify` nutzt `current_build`), die damit unverändert streng bleibt; `verify` verwendet `count` nicht. Test `test_404_on_build_lookup_is_fatal_and_never_reassigns` prüft Fatal, keine Writes, unveränderten Bau, kein Rohtext. Restrisiko: antwortete Apple bei „kein Bau“ real mit 404 statt `data: null`, würde der Handlauf `lesen` Fatal melden (sichere Richtung, aber AC-12 würde es zeigen).
- F001 behoben: `count`/`failed` liefern bei Fatal den String `fehler HTTP <status>`, nie Apples Rohtext. Der String kann keine Zahl verfälschen: Er erscheint nur anstelle der Zählung, die Summe der Bilder wird bei einem Fehler zum Fehlertext (nicht zu einer Teilsumme). Bei Fehler beim Laden der Bildsätze sind `bildsaetze` und `bilder` beide `fehler`. `anlegen` läuft nach `verify` weiter und endet mit Exit 0, die Gegenprobe selbst bleibt hart. Test `test_failed_count_query_is_reported_and_run_continues`.
Tests: 16 + 19 + 26 + 20 = 81 OK, 0 übersprungen (adversary-test-output.txt neu geschrieben).
Code reference: scripts/asc_store_version.py:25
Code reference: scripts/asc_store_version.py:54
Code reference: scripts/asc_store_version.py:162
Code reference: scripts/test_asc_store_version.py:376
Code reference: .github/workflows/asc-store-version.yml:20
**Implementierer:** F001 und F003 behoben (siehe Nachprüfung).

### Runde 2
**Adversary:**
Belege gegen Apple geprüft (`gh run view`: alle sechs Läufe conclusion=success, headSha 20402d7; Lauf 42603889995 event=pull_request, die fünf Handläufe event=workflow_dispatch; Skript identisch mit der Implementierung). Logs gelesen:
- lesen vorher (42603992405): Mac nur `MAC_OS 1.0 READY_FOR_SALE`, "keine bearbeitbare Version MAC_OS", iOS 1.0.1 `bau IOS kein Bau`, geschrieben=0.
- anlegen (42604117870): "version MAC_OS 1.0.1 angelegt", Bau 133 gewählt (von 3 gültigen) und beiden zugeordnet, `gegenprobe gleich=ja`, `geschrieben=3`.
- anlegen2 (42604272844): "schon zugeordnet: 133, unverändert" (beide), "schon vorhanden, übersprungen", `gegenprobe gleich=ja`, `geschrieben=0`.
- lesen2 (42604409575): beide Versionen 1.0.1 PREPARE_FOR_SUBMISSION mit Bau 1.0.1 (133) VALID, geschrieben=0.
- Store-Probe (42604414929): `version=1.0.1/MAC_OS/PREPARE_FOR_SUBMISSION` mit de-DE Beschreibung 1638, Schlüsselwörter 100, Werbetext 0, Bildsatz APP_DESKTOP anzahl=4, 4 Platzierungen MAC_PROFILE.
In allen Logs sind die Zugangsdaten maskiert (`***`).

Befund (was Apple beim API-Anlegen von Mac 1.0 übernahm): de-DE Beschreibung 1638, Schlüsselwörter 100, supportUrl 50 Zeichen; Werbetext 0 und whatsNew 0 (nicht übernommen); 1 Bildsatz APP_DESKTOP mit 4 Bildern und 4 Platzierungen MAC_PROFILE (übernommen); Review-Detail vorhanden; kein en-US für Mac (muss in 5a-2 angelegt werden). Grundlage für 5a-2 und 5b.

AC-11 nach Änderung (Commit 20402d7): `pull_request` mit `paths` nur auf Skript, Test und Workflow; der Job hat keine Secrets im Job-Env, alle Zugangsdaten und AKTION stehen nur im Schritt „Store version“ unter `if: github.event_name == 'workflow_dispatch'`; permissions contents: read; Tests als erster Schritt. Fork-PRs: GitHub gibt ihnen ohnehin keine Secrets, und der Schreibschritt läuft nur bei workflow_dispatch; der geänderte Test prüft Gate vor Skript vor Secret-Nutzung, genau ein Gate. Beobachtung (kein Defekt): Ein PR im selben Repo könnte die Workflow-Datei ändern; das gilt für jeden Workflow des Repos und setzt Schreibrecht voraus. PR-Läufe teilen die concurrency-Gruppe und warten nur.

Tests: 16 + 19 + 26 + 20 = 81 OK, 0 übersprungen (adversary-test-output.txt neu geschrieben).
Confirmation:
  AC: AC-12
  Code reference: scripts/asc_store_version.py:178
  Evidence: Läufe 42603992405, 42604117870, 42604272844, 42604409575, 42604414929 auf 20402d7 (success); erstes anlegen geschrieben=3, zweites geschrieben=0, Probe Mac 1.0.1 PREPARE_FOR_SUBMISSION. Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: .github/workflows/asc-store-version.yml:37
  Evidence: Schreibschritt nur bei workflow_dispatch, Zugangsdaten nur dort. Status: CONFIRMED

Code reference: scripts/test_asc_store_version.py:406
**Implementierer:** Belege der Läufe angelegt, pull_request-Auslöser ergänzt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Alle Punkte AC-1 bis AC-13 bewiesen, AC-12 durch echte Läufe auf 20402d7.
Tests: 81 passed, 0 failed, 0 übersprungen
Findings: F001 und F003 behoben, F002 LOW offen (kein Blocker).
Proven points: 13/13

## Geprüfte Dateien

- sha256:8380c961e792562e8e55c76604589ba71d0ad7a23a23f91f9c062c8708558d05  .github/workflows/asc-store-version.yml
- sha256:e57a496ad05f629e766a944ec02660dd3084774ecd7c08ac8eec63e4c70ef3c1  scripts/asc_store_version.py
- sha256:701124022f63f45e9fb811a2105af8aea65702fba1ce6d9bdb57ba062e6f9aab  scripts/test_asc_store_version.py

## Prüfbasis

- base: 8967580370673d60b5633c6185a5c4c2b5cdf7a6
- blob:8a65a63a28b0d88fb9f99811c65b16a36444bd48  .github/workflows/asc-store-version.yml
- blob:28125a77669b87f78ee522969a8dd09817438755  scripts/asc_store_version.py
- blob:6f5bed2eeb44c49e2a40ff3d4c36b9c41b683f48  scripts/test_asc_store_version.py
