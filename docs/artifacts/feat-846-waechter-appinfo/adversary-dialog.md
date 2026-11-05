# Adversary Dialog — feat-846-waechter-appinfo
Spec: docs/specs/tooling/feat-846-waechter-appinfo.md
Datum: 2026-11-05

## Checkliste
- [x] **AC-1:** Given eine App-Info steht auf `PREPARE_FOR_SUBMISSION`, When der Wächter läuft, Then gibt er `LAGE=editierbar` aus, unabhängig vom Mac-Zustand.
- [x] **AC-2:** Given keine App-Info ist editierbar und die Mac-Version steht nicht in `IN_REVIEW`/`WAITING_FOR_REVIEW`/`PREPARE_FOR_SUBMISSION`/`READY_FOR_REVIEW`, When der Wächter läuft, Then gibt er `LAGE=mac_fertig` aus.
- [x] **AC-3:** Given keine App-Info ist editierbar und die Mac-Version ist in Prüfung, fehlt oder die Daten sind leer, When der Wächter läuft, Then gibt er `LAGE=warten` aus und meldet nichts.
- [x] **AC-4:** Given beide Auslöser treffen zugleich zu, When der Wächter läuft, Then hat `editierbar` Vorrang.
- [x] **AC-5:** Given ASC antwortet mit 5xx oder ist nicht erreichbar, When der Wächter läuft, Then endet er mit Exit 0, `LAGE=warten` und einem Hinweis, ohne Kommentar.
- [x] **AC-6:** Given ASC antwortet mit 401 oder 403, When der Wächter läuft, Then endet er mit Exit 1 und `::error::`, damit ein abgelaufener Schlüssel sichtbar wird.
- [x] **AC-7:** Given ein beliebiger Lauf, When die Ausgabe gelesen wird, Then enthält sie Zustände und IDs, aber weder Schlüsseltext noch Token noch Apples Rohantwort.
- [x] **AC-8:** Given der Workflow, When er gelesen wird, Then läuft er täglich per `schedule` und manuell per `workflow_dispatch`, hat nur `contents: read` und `issues: write` und eine `concurrency`-Gruppe ohne Abbruch.
- [x] **AC-9:** Given `LAGE` ist `editierbar` oder `mac_fertig` und #837 trägt den Marker `<!-- wachter-846:<lage> -->` noch nicht, When der Kommentarschritt läuft, Then legt er genau einen Kommentar mit diesem Marker in #837 an.
- [x] **AC-10:** Given #837 trägt den Marker dieser Lage schon, oder `LAGE` ist `warten`, When der Kommentarschritt läuft, Then kommentiert er nicht; eine andere Lage (später `editierbar` nach `mac_fertig`) darf einen eigenen Kommentar bekommen.
- [x] **AC-11:** Given der Stand vor der Umsetzung, When `scripts/test_asc_watch_appinfo.py` läuft, Then ist er rot; nach der Umsetzung grün, ebenso alle übrigen Skripttests in `scripts/`.

## Dialog

### Runde 1
**Adversary:** Erste Prüfung ergab BROKEN.
- F001 HIGH: Der Workflow setzte `ASC_TIMEOUT_SECONDS` nicht. `find_app_id` wiederholt bei 5xx bis zur Frist (Standard 2700 s). Der Lauf wäre nach dem 10-min-Limit rot geworden statt Exit 0 / `LAGE=warten` (AC-5). Die Tests verdeckten das, weil sie die Frist selbst verkürzen.
- F002 MEDIUM: Die Marker-Suche per Pipe `gh ... | grep -qF` brach unter `-o pipefail` bei großem Kommentarbestand ab (SIGPIPE) und hätte Doppelkommentare erzeugt (AC-10).
- F003 MEDIUM: Konfigurationsfehler (fehlende Secrets, openssl, unbekannte Bundle-ID, 404) enden als `::notice::` und Exit 0. Spec Punkt 3 verlangt Lautstärke nur für 401/403. Spec-Lücke, kein AC-Bruch.
- Lagenlogik gebrochen versucht: `1.10` gegen `1.9`, nicht numerische und `None`-Versionen, fremde Eintragstypen, iOS-Version fertig bei Mac in Prüfung. Kein Absturz, Ergebnis jeweils spec-konform. Ausgabe enthält nur feste Texte plus id/state/platform/versionString.

**Implementierer:**
- F001: `ASC_TIMEOUT_SECONDS: "60"` im Job-env.
- F002: Marker-Suche über die Datei `$RUNNER_TEMP/comments.txt`, kein Pipe.
- Zwei neue Tests: `test_workflow_sets_short_asc_timeout`, `test_marker_search_without_pipe`.
- F003: Entscheidung des Tech Leads: im Rahmen der Spec belassen, Risiko dokumentieren; der Handlauf nach dem Merge prüft das Log auf die Notice-Zeile und die Zustandszeilen.
Code reference: scripts/asc_watch_appinfo.py:34
Code reference: .github/workflows/asc-watch-appinfo.yml:26

### Runde 2
**Adversary:** Fixes selbst nachgestellt.
1. F001: Mit der Workflow-Umgebung (Poll 5 s, Frist 60 s) gegen einen Server, der überall 503 liefert (auch beim App-Lookup): Exit 0 nach 60,4 s, Notice, `LAGE=warten`, Kommentarschritt übersprungen. Kontrolle mit Frist 2700: lief weiter, Diagnose der Vorrunde bestätigt. Aussetzer von 12 s: Exit 0, `LAGE=editierbar`.
2. F002: Den echten run-Block mit Fake-`gh` unter `bash -e -o pipefail` und `bash -e` ausgeführt. Marker vorn in ~30 MB: kein Kommentar; nur Marker `editierbar` bei Lage `mac_fertig`: ein Kommentar; kein Marker: ein Kommentar; `gh issue view` scheitert: Exit 1, kein Kommentar.
3. Mutationstest an Kopien: Zeile entfernt oder Wert 2700 lässt den Timeout-Test, wiederhergestellte Pipe den Marker-Test scheitern.
4. Tests: Wächter-Test 13 OK; Gesamtlauf `unittest discover` 526 Tests OK, 0 übersprungen.
5. Neue Hinweise (LOW, kein Defekt): Timeout-Test prüft nur Text; ein Aussetzer über 20 s mitten im Lauf verschiebt die Meldung um einen Tag (nie falsche Meldung); Worst-case-Laufzeit ≈ 450 s unter dem 10-min-Limit.

**Implementierer:** Keine Einwände. F003 bleibt bewusst akzeptierte Spec-Lücke (Code reference unten); optional später "Missing environment" und "No app with bundle id" laut machen.
Code reference: scripts/asc_watch_appinfo.py:64
Code reference: .github/workflows/asc-watch-appinfo.yml:47
Code reference: scripts/test_asc_watch_appinfo.py:224

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

| Feld | Produktions-Schreibstellen | Bedingung davor | Test für diesen Weg |
|---|---|---|---|
| `LAGE` / `MAC_STATE` (GITHUB_OUTPUT) | 1 — `scripts/asc_watch_appinfo.py:55` (`announce`) | Nur wenn `GITHUB_OUTPUT` gesetzt ist. Erfolgspfad: alle drei ASC-Abfragen ohne `Fatal`. Fehlerpfad: `Fatal` ohne "HTTP 401"/"HTTP 403". Bei 401/403 wird nichts geschrieben, Exit 1. | Erfolg: `test_editable_wins`, `test_mac_left_review`, `test_mac_in_review_waits`, `test_missing_data_waits`, `test_newest_mac_version_counts`. Fehler: `test_5xx_stays_quiet`. 401/403: `test_401_fails_loudly`. Konfigurationsfehler (F003) bewusst ohne eigenen Test. |

## Verdict
**VERIFIED**

F001 und F002 sind nachweislich behoben (Lauf gegen Dauer-503-Server, Ausführung des echten Kommentarschritts, Mutationstest). F003 ist eine dokumentierte, akzeptierte Spec-Lücke. 11/11 Punkte belegt, Gesamtlauf der Skripttests grün.

## Geprüfte Dateien

- sha256:8482a9bfefa757c9e2aea2f69a13a0cd05db29a9c523a0116cbf06f2b0c10320  .github/workflows/asc-watch-appinfo.yml
- sha256:8d8157e92fe809fbf8d90a324efe572696cc242ffa55aa8fe7241ab2ed56c7d5  scripts/asc_watch_appinfo.py
- sha256:9ecb59e3d2e39741375c4bab7ca7b45e42ae03d82caa934cd01fc0aa6d50daa9  scripts/test_asc_watch_appinfo.py

## Prüfbasis

- base: 185099961651feeed2bda73e65eb552c416e15ee
- blob:f07eb05e9e1d26b71261b4fc25c45642fb1da13f  .github/workflows/asc-watch-appinfo.yml
- blob:60ee635875350b3161e30219504b0304a96aae80  scripts/asc_watch_appinfo.py
- blob:90ebf642b5e1e2458ecb8dac40cd96a94ca2c598  scripts/test_asc_watch_appinfo.py

## Geprüfte Dateien

- sha256:8482a9bfefa757c9e2aea2f69a13a0cd05db29a9c523a0116cbf06f2b0c10320  .github/workflows/asc-watch-appinfo.yml
- sha256:8d8157e92fe809fbf8d90a324efe572696cc242ffa55aa8fe7241ab2ed56c7d5  scripts/asc_watch_appinfo.py
- sha256:9ecb59e3d2e39741375c4bab7ca7b45e42ae03d82caa934cd01fc0aa6d50daa9  scripts/test_asc_watch_appinfo.py

## Prüfbasis

- base: 185099961651feeed2bda73e65eb552c416e15ee
- blob:f07eb05e9e1d26b71261b4fc25c45642fb1da13f  .github/workflows/asc-watch-appinfo.yml
- blob:60ee635875350b3161e30219504b0304a96aae80  scripts/asc_watch_appinfo.py
- blob:90ebf642b5e1e2458ecb8dac40cd96a94ca2c598  scripts/test_asc_watch_appinfo.py
