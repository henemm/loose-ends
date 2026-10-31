# Adversary Dialog — feat-773-testflight-crashes
Spec: docs/specs/tooling/feat-773-schnitt-1-crash-skript.md
Datum: 2026-10-31 12:18

## Checkliste
- [x] **Eingabe:** `python3 scripts/asc_crashes.py <zielordner>` mit `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_BUNDLE_ID` in der Umgebung.
- [x] **Ausgabe:** je Meldung `<id>.json` und, wenn Apple einen Bericht hat, `<id>.crash` im Zielordner (Modus `0600`); im Log
- [x] **Seiteneffekte:** nur GET-Anfragen an App Store Connect, Schreiben nur unterhalb des Zielordners; keine App-Datei, keine
- [x] **AC-1:** `scripts/asc_crashes.py <zielordner>` holt alle Absturzmeldungen der App über `betaFeedbackCrashSubmissions?limit=200` und folgt `links.next` bis zum Ende, ohne Plattformfilter (iOS und Mac in einem Lauf, `appPlatform` je Meldung). Belegt durch `test_two_pages_via_links_next`, `test_both_platforms_in_one_run`.
- [x] **AC-2:** Je Meldung entstehen im Zielordner `<id>.json` (Attribute unverändert) und `<id>.crash` (`logText` unverändert), beide mit Modus `0600`; der Zielordner wird angelegt, falls er fehlt. Belegt durch `test_files_have_expected_content`, `test_no_submissions`.
- [x] **AC-3:** Fehlt der Bericht (404 beim `crashLog` oder leerer `logText`), wird die Meldung als „ohne Bericht“ gezählt, `<id>.json` entsteht, `<id>.crash` nicht, Exit 0. Belegt durch `test_missing_crashlog_counts_as_without_report`, `test_empty_logtext_counts_as_without_report`.
- [x] **AC-4:** Fehlerbehandlung: 5xx, 408, 429 und Netzfehler werden bis zu fünfmal wiederholt (danach Exit 1 mit `::error::`); jeder andere 4xx-Status, auch ein 403 beim Bericht, ist Exit 1 mit `::error::` ohne Dateien. Belegt durch `test_server_error_once_is_retried`, `test_server_error_always_exits_1`, `test_forbidden_exits_1`.
- [x] **AC-5:** Das Log enthält nur Anzahl Meldungen, Anzahl mit und ohne Bericht, je Meldung Id, Bundle-ID, Plattform und Datum sowie die Wiederholungszeilen von `get_json` (Statuscode und Pfad); nie E-Mail, Kommentar, Gerätemodell, Sprache, Zeitzone, `logText`, Schlüssel oder Token, weder bei Erfolg noch bei Fehler. Ohne Meldungen steht genau `keine Absturzmeldungen` und Exit 0. Belegt durch `test_log_has_no_personal_data`, `test_no_submissions`, `test_forbidden_exits_1`.
- [x] **AC-6:** Das Skript führt ausschließlich GET-Anfragen aus und schreibt nur unterhalb des Zielordners (unzulässige Ids brechen ab). Belegt durch `test_only_get_requests`, `test_unsafe_id_exits_1` und Diff-Durchsicht (kein `send_json`, kein PATCH/POST/DELETE im Skript).
- [x] **AC-7:** Aufruf und Konfiguration: ohne Argument Exit 2 mit `usage:`, bei fehlender Umgebung Exit 1 mit `Missing environment`; `asc_wait_build.py` bleibt unverändert. Belegt durch `test_usage_and_missing_environment` und `git diff --stat` (nur die zwei Dateien des Scopes).
- [x] **AC-8:** Die Tests laufen ohne Änderung an `ci.yml` über `unittest discover -s scripts -p 'test_*.py'` mit; alle vorhandenen Skripttests bleiben grün. Belegt durch `python3 -m unittest discover -s scripts -p 'test_*.py'` und `git diff --stat` (`ci.yml` nicht im Diff).
- [x] **AC-9:** Der Diff berührt genau die zwei Dateien des Scopes, kein `project.yml`, kein App-Code, keine Workflow-Datei, kein Pfad der Geräteliste, und liegt bei höchstens ±250 LoC. Belegt durch `git diff --stat` im Abschlussbericht, mit dem Satz „Kein Pfad der Geräteliste berührt.“ Stufe 2 (Simulator) entfällt, weil die App nicht berührt wird; die Abnahme endet nach den Tests.
- [x] **AC-10:** Während der Umsetzung läuft nichts auf Hennings Geräten, kein TestFlight-Lauf und kein Aufruf gegen die echte App-Store-Connect-API. Belegt durch Abschlussbericht (Befehlsliste).

## Dialog

### Runde 1
**Adversary:** Alle 15 Tests des Schnitts selbst gefahren (15 OK, adversary-test-output.txt), volle Suite 425 Tests OK, 0 Fehler, 0 uebersprungen. AC-4-Kanten der App-Suche per Probe gegen `app_id` (get_json ersetzt, keine echte API): leere data-Liste -> Fatal "No app with bundle id ..." nach 1 Aufruf; Antwort ohne `data`, `data: null`, Eintrag ohne id, Eintrag kein dict -> je 5 Versuche, dann Fatal "No answer"; None,None,ok -> id nach 3 Aufrufen. 408/429/Netzfehler liefern in `get_json` (asc_wait_build.py:71-79) None und laufen damit durch denselben `fetch` mit 5 Versuchen; andere 4xx sind dort sofort Fatal. Alter Defekt (Wiederholung bis ASC_TIMEOUT_SECONDS) behoben: `find_app_id` nicht mehr importiert.
Finding-Suche: kein Defekt gefunden.
Confirmation:
  AC: AC-4
  Code reference: scripts/asc_crashes.py:35
  Evidence: (app_id ueber fetch, 5 Versuche, leere Liste Fatal ohne Wiederholung) und scripts/asc_crashes.py:24 (fetch, ATTEMPTS=5). Evidence: Probe und Test. 
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: scripts/test_asc_crashes.py:170
  Evidence: (test_app_lookup_server_error_exits_1: 500 auf /v1/apps -> genau 5 Aufrufe, Exit 1, `::error::`, keine Dateien). 
  Status: CONFIRMED
**Implementierer:** (entfaellt, Adversary-Lauf)

### Runde 2
**Adversary:** Zweiter Angriff auf die uebrigen Punkte. AC-1/AC-2: scripts/asc_crashes.py:55 (fetch_all folgt links.next, limit=200, kein Plattformfilter) und :79 (write_private, os.open 0600 plus fchmod, auch bei vorhandener Datei); Tests two_pages, both_platforms, files_have_expected_content gruen. AC-3: scripts/asc_crashes.py:65 (fetch_log, nur 404 oder leerer logText -> None; 403 bleibt Fatal); unlink(missing_ok) entfernt veraltete .crash. AC-5: Log-Zeilen in store() nur id/bundle/plattform/datum; Fatal-Texte enthalten nur Pfad ohne Query; test_log_has_no_personal_data gruen. AC-6: nur get_json (GET), Ids per SAFE_ID und "."/".." geprueft (asc_crashes.py:92), kein send_json/PATCH/POST/DELETE per grep. AC-7: Usage Exit 2 (asc_crashes.py:119), asc_wait_build.py unveraendert. AC-8: ci.yml und asc_wait_build.py nicht im Diff, discover 425 OK. AC-9: Diff gegen 31976e3 fuer scripts, .github, project.yml, LooseEnds, Shared zeigt nur scripts/asc_crashes.py (142) und scripts/test_asc_crashes.py (235); 377 Zeilen, Ueberschreitung der 250-LoC-Grenze ist vom PO am 2026-10-31 ausdruecklich akzeptiert, kein Defekt. Kein Pfad der Geraeteliste beruehrt. AC-10: nur Fake-Server und Monkeypatch, keine echte API, nichts auf Geraeten. Test-Referenzen: scripts/test_asc_crashes.py:204 (test_only_get_requests), :210 (test_unsafe_id_exits_1), :225 (test_usage_and_missing_environment).
Bekannter Nebenbefund (nicht gewertet): ResourceWarning "unclosed socket" in Tests.
**Implementierer:** (entfaellt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Tests: 425 passed (volle Suite), 15 passed (test_asc_crashes), 0 failed, 0 uebersprungen
Edge cases: App-Suche 408/429/Netz/5xx/ohne data/leere Liste/ohne id geprueft, keine Defekte
Regressions: None found
Checklist: 13/13 points proven

## Geprüfte Dateien

- sha256:3457fe80b7e13f8c32c91bbefc0509c316a7772a23231c8dae9e2afec9bd9625  scripts/asc_crashes.py
- sha256:cf3ade1a624ab214f29b1cc62d1d885e824d7225df8098a9c7d7add101ac9cd3  scripts/test_asc_crashes.py

## Prüfbasis

- base: 31976e37502ea51a4e50767aba6c01f1e3d01722
- blob:3e8fd4015930e3a9e8891a13120d82dc8f911595  scripts/asc_crashes.py
- blob:0a4647a236b833d53918ccdb67d5aca556dbccf5  scripts/test_asc_crashes.py
