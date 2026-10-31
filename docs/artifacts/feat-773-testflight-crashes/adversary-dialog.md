# Adversary Dialog — feat-773-testflight-crashes
Spec: docs/specs/tooling/feat-773-schnitt-1-crash-skript.md
Datum: 2026-10-31 10:51

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
**Adversary:** Gefordert: Beweis je AC. Volle Suite `python3 -m unittest discover -s scripts -p "test_*.py" -v` ausgefuehrt, Ausgabe in `docs/artifacts/feat-773-testflight-crashes/adversary-test-output.txt`: Ran 423 tests, OK, 0 skipped, die 13 Tests aus `scripts/test_asc_crashes.py` laufen mit (ci.yml und asc_wait_build.py nicht in der Diff-Statistik gegen 31976e3). Danach eigene Randfaelle gegen das Skript mit dem FakeASC der Testdatei (Probe nur im Speicher, keine Produktdatei geaendert, kein Aufruf gegen Apple). Ergebnisse: Liste 404 -> Exit 1 `::error::ASC answered HTTP 404` (asc_crashes.py:49 ueber get_json, kein Sonderfall); `data` nicht Liste (null) -> genau 5 Versuche, Exit 1; `links.next` absolut mit Query wird zu Pfad plus Query, ohne Query ebenfalls korrekt (zweite Seite genau einmal); 403 auf crashLog der zweiten Meldung -> Exit 1, Zielordner leer (collect() holt alle Berichte vor dem ersten Schreiben, asc_crashes.py:115); vorhandene S1.crash wird bei fehlendem Bericht entfernt (asc_crashes.py:97), vorhandene 0644-S1.json danach 0600 (fchmod, asc_crashes.py:72); crashLog dauerhaft 500 -> fuenf Versuche, Exit 1; Meldung ohne attributes -> `unbekannt` in allen vier Feldern, Exit 0; Id None, "..", ".", "a/b", "", "a b" -> Exit 1 mit `::error::Unexpected submission id`; nur GET (Test test_only_get_requests, Fake zeichnet auch POST/PATCH/DELETE auf); Fatal-Texte tragen nur Statuscode und Pfad.
**Implementierer:** Verweis auf Tests und Code; Runde 1 ohne Einwand zu den ACs 1-5, 7, 8, 10.

### Runde 2
**Adversary:** Nachgebohrt an den Waechtern. (a) Die Id-Pruefung `SAFE_ID = re.compile(r"^[A-Za-z0-9._-]+$")` mit `.match` (asc_crashes.py:20, :82): in Python erlaubt `$` ein abschliessendes Newline. Die Id "x\n" besteht die Pruefung, es kommt NICHT `Fatal("Unexpected submission id")`, sondern ein ungefangener `http.client.InvalidURL` (Traceback, Exit 1, keine `::error::`-Zeile). Es wird nichts geschrieben, weil urllib die Anfrage ablehnt, aber der Waechter laesst genau das durch, wofuer die Spec ihn verlangt (Spec Ablauf 6, AC-6, test_unsafe_id_exits_1 deckt nur "../evil"). Reproduktion: FakeASC mit Meldung id="x\n", Exit 1, stderr Traceback `URL cant contain control characters`. Behebung: `fullmatch` oder `\Z`. (b) Alle anderen OSError sind ungefangen: `.crash` als Verzeichnis -> PermissionError beim unlink (asc_crashes.py:97), Zielordner existiert als Datei -> FileExistsError (asc_crashes.py:113); jeweils Traceback, Exit 1, aber ohne `::error::`; Spec nennt diese Faelle nicht, nur LOW. (c) Attribut mit Zeilenumbruch (buildBundleId="x\nzusammenfassung meldungen=0") erzeugt gefaelschte Zusammenfassungszeile im Log (asc_crashes.py:101-103); Quelle ist Apple, LOW, nur die vier erlaubten Felder werden gedruckt, keine personenbezogenen. (d) Doppelte Ids (zwei Seiten, gleiche Id) werden doppelt gezaehlt und ueberschrieben; zyklisches links.next hat keine Schleifenbremse (asc_crashes.py:48-51); LOW, Apple liefert das nicht. (e) AC-9: Diff-Statistik gegen 31976e3 zeigt 6 Dateien, 911 Zeilen, davon Code 129 plus 218 = 347 Zeilen (Skript+Test), der Rest Spec/Kontext/Briefing/Artefakte. Die Spec nennt "ca. 240" Schnittschaetzung, tatsaechlich 347 und damit ueber 250, wenn Testcode mitzaehlt; "genau die zwei Dateien" gilt nur fuer Code. Strittig, siehe Verdict.
**Implementierer:** keine Antwort, Findings unten.

### Runde 3
**Adversary:** Neuer Stand nach BROKEN. Volle Suite erneut: Ran 424 tests, OK, 0 skipped (adversary-test-output.txt). F001: `scripts/asc_crashes.py:82` nutzt `SAFE_ID.fullmatch`; Probe mit Id "x\n" -> Exit 1, stdout `::error::Unexpected submission id`, kein Traceback; `scripts/test_asc_crashes.py:202` prueft per subTest "../evil", "x\n", "a/b". F002: `scripts/asc_crashes.py:126` faengt OSError; Probe Zielordner als Datei -> Exit 1 `::error::Cannot write <ordner>: File exists`; `.crash` als Verzeichnis -> Exit 1 `::error::Cannot write ...S1.crash: Operation not permitted`; Test `scripts/test_asc_crashes.py:210`. Die Meldung nennt nur Pfad des Zielordners und strerror, keine Meldungsdaten. F003 (LOW) bleibt offen, vom Implementierer bewusst nicht behoben (nur bei unerwarteter Apple-Antwort, kein Datenleck, nicht in der Spec): bekannte Grenze. AC-9 unter der Festlegung des Tech Leads: das Scoping-Limit wird gemessen wie das Werkzeug-Gate (Produktcode und Testcode getrennt, je eigene Schwelle, agent-os-openspec Issue 94); Produktcode 132 Zeilen, Test 227, zusammen 359 gegen die Spec-Schaetzung 240; Code-Diff beruehrt nur die zwei Scope-Dateien, asc_wait_build.py und ci.yml unveraendert. Bewertung: unter dieser Festlegung erfuellt; die Ueberschreitung der Schaetzung (359 gesamt) wird im Abschlussbericht an den PO offen genannt. Kein Pfad der Geraeteliste beruehrt.
**Implementierer:** F001 und F002 behoben, F003 bewusst offen.

### Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: scripts/asc_crashes.py:82
  Description: SAFE_ID.match mit `$` akzeptiert eine Id mit abschliessendem Newline ("x\n"); sie wird nicht mit Fatal("Unexpected submission id") abgewiesen, sondern erreicht get_json und endet in einem ungefangenen InvalidURL (Traceback, kein ::error::).
  Spec requirement: AC-6 / Ablauf 6 — Id, die nicht ^[A-Za-z0-9._-]+$ entspricht, bricht mit Fatal ab.
  Conflict: Der Waechter hat ein Loch; nur die Urllib-Ablehnung verhindert, dass "x\n.json" als Dateiname entsteht. test_unsafe_id_exits_1 (scripts/test_asc_crashes.py:202) prueft nur "../evil".
  Remediation: `SAFE_ID.fullmatch(sid)` (oder `\Z`), plus Testfall mit "x\n".

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_crashes.py:97
  Description: OSError (unlink auf Verzeichnis, mkdir auf Datei, Schreibfehler) wird nicht gefangen; Traceback und Exit 1 ohne ::error::.
  Spec requirement: Exit-Codes — 1 mit ::error:: bei Fatal.
  Conflict: Kein Datenleck, Exit-Code stimmt, nur das Format weicht ab; Spec nennt den Fall nicht.
  Remediation: OSError in main() zu Fatal umwandeln (ohne Pfad der Daten).

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_crashes.py:101
  Description: Zeilenumbruch in buildBundleId/appPlatform/createdDate faelscht Logzeilen; doppelte Ids und zyklisches links.next (asc_crashes.py:48) werden nicht abgefangen.
  Spec requirement: AC-5 — Log nur die definierten Zeilen.
  Conflict: Nur bei unerwarteter Apple-Antwort; keine personenbezogenen Daten betroffen.
  Remediation: Werte auf eine Zeile zusammenfalten, besuchte next-Adressen merken.

### Bestaetigungen

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_crashes.py:47
  Evidence: limit=200, links.next wird zu Pfad plus Abfrage, kein Filter; test_two_pages_via_links_next und test_both_platforms_in_one_run gruen, eigene Probe bestaetigt.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_crashes.py:71
  Evidence: os.open mit 0600 plus fchmod; Probe: 0644-Datei wird zu 0600; test_files_have_expected_content (scripts/test_asc_crashes.py:133) gruen; Zielordner per mkdir parents.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_crashes.py:60
  Evidence: 404 (Praefix-Abgleich) und leerer logText ergeben None; .crash wird entfernt, .json bleibt; Tests und Probe gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_crashes.py:26
  Evidence: fuenf Versuche (Probe: Liste 5, crashLog 5), 403 auf Liste und crashLog Exit 1 ohne Dateien (scripts/test_asc_crashes.py:170), Liste 404 Exit 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_crashes.py:102
  Evidence: nur id, bundle, plattform, datum, bericht; Marker-Test scripts/test_asc_crashes.py:180 gruen, Fatal-Texte nur Statuscode und Pfad.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/asc_crashes.py:108
  Evidence: Exit 2 mit usage bei keinem, leerem, Leerzeichen- oder zwei Argumenten; Missing environment Exit 1; asc_wait_build.py nicht in der Diff-Statistik gegen 31976e3.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_asc_crashes.py:87
  Evidence: volle Suite 423 Tests OK, 0 skipped, ci.yml nicht in der Diff-Statistik.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/test_asc_crashes.py:102
  Evidence: Skript wurde nur gegen den lokalen FakeASC (127.0.0.1) gestartet, ASC_API_BASE gesetzt; kein Geraet, kein TestFlight, keine echte API; Kommandoliste: unittest discover, Diff-Statistik, Probe gegen FakeASC.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED — F001 und F002 behoben und nachgeprueft (424 Tests OK, Probe x\\n und Zielordner-als-Datei gruen), F003 (LOW) als bekannte Grenze akzeptiert, AC-9 unter der Festlegung Produkt- und Testcode getrennt (132 bzw. 227 Zeilen, Gesamt 359 ueber der Spec-Schaetzung, offen an PO zu nennen) erfuellt. Alle 10 ACs belegt.

## Geprüfte Dateien

- sha256:c80ebd28d24683ab13d31ab0cc8f874cd9a407ff9baae05da073853caeae30be  scripts/asc_crashes.py
- sha256:177305b43c9cd375f621cfb9cee6533448947b85f966823205f81cdb572c1115  scripts/test_asc_crashes.py

## Prüfbasis

- base: 31976e37502ea51a4e50767aba6c01f1e3d01722
- blob:4ea4689461989e2c9b166e32d81b4f95720667e9  scripts/asc_crashes.py
- blob:d8d12fcd9db705b2899021d2c1abbf7400d8b4ba  scripts/test_asc_crashes.py
