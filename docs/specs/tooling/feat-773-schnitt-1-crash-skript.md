---
entity_id: feat-773-schnitt-1-crash-skript
type: feature
created: 2026-10-31
updated: 2026-10-31
status: draft
workflow: feat-773-testflight-crashes
---

# Spec: #773 Schnitt 1 „Crash-Skript“: TestFlight-Absturzmeldungen per App-Store-Connect-API abholen

## Approval

- [ ] Approved

## Purpose

Henning und später externe Tester schicken Absturzberichte über TestFlight an Apple. Claude soll sie selbst abholen und
auswerten, ohne dass Henning etwas herunterlädt. Apple dokumentiert dafür seit WWDC25 zwei Pfade:
`GET /v1/apps/{id}/betaFeedbackCrashSubmissions` (Liste der Meldungen) und
`GET /v1/betaFeedbackCrashSubmissions/{id}/crashLog` (Bericht, einziges Attribut `logText`). Schnitt 1 baut das **Skript**, das
beides abfragt und je Meldung zwei Dateien in einen Zielordner schreibt. Der Weg zur CI und die Verschlüsselung folgen in Schnitt 2
(eigene Spec); die Aufteilung ergibt sich aus dem Limit von ±250 LoC (Skript und Test ca. 240, Workflow, Schlüssel und Doku
kommen dazu).

Das Repo ist öffentlich: Lauf-Logs sind für jeden mit GitHub-Konto lesbar, und die Meldungen enthalten E-Mail, Kommentar,
Gerätemodell und Zeitzone der Tester. Darum druckt das Skript **nur Zahlen und eine Kennzeile je Meldung** (Id, Bundle-ID,
Plattform, Datum) und nie Kommentar, E-Mail, Gerätedaten oder Berichtstext. Der Klartext landet ausschließlich im Zielordner.

Ohne Modell: reine API-Abfragen, kein Modellweg.

**Alternativen** (Analyse `docs/context/feat-773-testflight-crashes.md`, Regel „In Alternativen denken“):

- **B: Ablage in einem privaten Repo** (Deploy-Key als Secret, die CI schiebt die Dateien hinein). Datenschutz gut, aber die
  Testerdaten lägen dauerhaft in der Git-Historie, dazu ein neues Repo, ein neuer Schlüssel und eine Löschregel.
- **C: lokal abholen** mit einem ASC-Schlüssel auf diesem Mac. Kippt die bewusste Entscheidung „kein lokaler ASC-Schlüssel“
  (Memory `loose-ends-testflight-belege-abrufbar`).
- **D: Henning lädt die ZIP in App Store Connect herunter.** Handarbeit je Absturz, das ist sein Ausschluss im Ticket.
- **E: Xcode Organizer auf dem Mac.** Null Aufwand, aber unzuverlässig: meine `xcodebuild`-Läufe melden sein Xcode-Konto ab, und
  der Organizer zeigt nicht alles, was App Store Connect hat (Apple-Forum, Thread 742210).

Gewählt ist **A: Skript (dieser Schnitt) plus später ein Handlauf in der CI, dessen Ergebnis als GPG-Chiffrat im Artefakt liegt**
(Schnitt 2). Das Skript selbst bleibt unabhängig vom Übertragungsweg und läuft auch lokal, falls C je gewählt würde. Gekippt
wird keine ADR.

## Source

- **File:** `scripts/asc_crashes.py` (neu)
- **Identifier:** `main(argv)`, `fetch_all(config, app_id)`, `fetch_log(config, submission_id)`; Bausteine aus
  `scripts/asc_wait_build.py` (`Fatal`, `read_config`, `get_json`, `find_app_id`). Vorbild für den Test:
  `scripts/test_asc_what_to_test.py` (`FakeASC`). Analyse: `docs/context/feat-773-testflight-crashes.md`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/asc_wait_build.py` | Skript | `read_config`, `get_json`, `find_app_id`, `Fatal`; wird importiert, nicht geändert |
| `.github/workflows/ci.yml` | Workflow | Zeile 33 `unittest discover -s scripts -p 'test_*.py'` nimmt die neue Testdatei von selbst mit; keine Änderung |
| Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | GitHub Secrets | Gibt es schon; erst Schnitt 2 benutzt sie, Schnitt 1 läuft nur gegen den Nachbau |
| #705 / `scripts/asc_beta_probe.py` | Ticket, Skript | Vorbild für ein reines Lese-Skript; wird weder importiert noch geändert |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_crashes.py | CREATE | Listet alle Absturzmeldungen (paginiert), holt je Meldung den Bericht, schreibt `<id>.json` und `<id>.crash` |
| scripts/test_asc_crashes.py | CREATE | `unittest` gegen lokalen API-Nachbau (`FakeASC`-Muster), Skript als Unterprozess |

### Estimated Changes
- Files: 2, kein Produktcode, kein Pfad der Geräteliste
- LoC: ca. +240/-0 (ca. 110 `asc_crashes.py`, ca. 130 `test_asc_crashes.py`)

## Implementation Details

### 1. `scripts/asc_crashes.py`

Nur Standardbibliothek plus `openssl` (wie die anderen ASC-Skripte). Aufruf: `python3 scripts/asc_crashes.py <zielordner>`.
Umgebung wie `asc_wait_build.py` (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_BUNDLE_ID`, `ASC_API_BASE`,
`ASC_POLL_SECONDS`). **Kein Plattformfilter**: iOS und macOS stehen in einer Liste, die Plattform steht je Meldung im Attribut
`appPlatform`. Es gibt keinen schreibenden Aufruf; das Skript benutzt nur `get_json`.

**Ablauf.**

1. Argument prüfen: genau ein nicht leerer Zielordner, sonst Hinweis `usage: asc_crashes.py <target-folder>` auf stderr und
   Exit 2 (wie `asc_wait_build.py`). Zielordner mit `Path.mkdir(parents=True, exist_ok=True)` anlegen, falls er fehlt.
2. `config = read_config()`, `app_id = find_app_id(config)`.
3. **Liste.** Start: `/v1/apps/{app_id}/betaFeedbackCrashSubmissions?limit=200`. Danach `links.next` folgen, bis es fehlt. Apple liefert
   `next` als absolute Adresse; das Skript schneidet Schema und Host ab (`urllib.parse.urlsplit`, Pfad plus Abfrage) und hängt
   das Ergebnis an `config["base"]`, damit `get_json` (das `config["base"] + path` bildet) und der Nachbau dieselbe Adresse
   sehen. Fehlt `links` oder `next`, endet die Schleife. Eine Seite, deren `data` keine Liste ist, zählt als nicht beantwortet.
4. **Bericht je Meldung.** `GET /v1/betaFeedbackCrashSubmissions/{id}/crashLog`; `data.attributes.logText` ist der Text. Fehlt
   `logText` oder ist er leer, gilt die Meldung als „ohne Bericht“.
5. **Dateien je Meldung** im Zielordner: `<id>.json` mit den Attributen der Meldung **wie geliefert**
   (`json.dumps(attributes, indent=2, sort_keys=True, ensure_ascii=False)`, UTF-8) und, wenn ein Bericht da ist, `<id>.crash` mit
   `logText` unverändert (UTF-8). Dateien werden mit Modus `0600` angelegt (`os.open(..., 0o600)`), weil sie personenbezogene
   Daten enthalten. Eine vorhandene Datei gleichen Namens wird überschrieben (der Lauf ist wiederholbar), eine veraltete
   `<id>.crash` bleibt, wenn der Bericht inzwischen fehlt, nicht stehen: sie wird dann entfernt.
6. **Id als Dateiname.** Eine Id, die nicht `^[A-Za-z0-9._-]+$` entspricht (oder `.`/`..` ist), wird nicht als Pfad benutzt, sondern
   bricht mit `Fatal("Unexpected submission id")` ab; das schließt Pfadtricks aus, falls Apples Antwort je unerwartet aussähe.

**Wiederholung und Fehler.** `get_json` gibt `None` zurück, wenn Apple 5xx, 408 oder 429 antwortet oder das Netz nicht
erreichbar ist. Das Skript kapselt `get_json` in `fetch(config, path)`: bis zu fünf Versuche mit `ASC_POLL_SECONDS` Pause; ist
die Antwort nach dem fünften Versuch immer noch `None`, `Fatal("No answer from App Store Connect for <pfad ohne Abfrage>")`.
`get_json` wirft für **jeden** anderen 4xx-Status (401, 403, 404 …) `Fatal("ASC answered HTTP <code> for <pfad>…")` und
unterscheidet 404 nicht von anderen Fehlern, außer im Text. **Festlegung (kleinste Änderung, `asc_wait_build.py` bleibt
unberührt):** nur beim Bericht fängt `fetch_log` das `Fatal` ab und prüft, ob `str(error)` mit `"ASC answered HTTP 404 for "`
beginnt (der Text steht in `get_json` fest); trifft das zu, gilt die Meldung als „ohne Bericht“ (kein Abbruch), jedes andere
`Fatal` wird unverändert weitergereicht. Bei der Liste selbst gilt 404 als Fehler (die App hat dann keinen solchen Pfad). Wird
`get_json` je geändert und der Text weicht ab, schlägt `test_missing_crashlog_counts_as_without_report` fehl; das ist die
Absicherung dieser Kopplung.

**Log (Datenschutz).** Ausgegeben wird nur:

- je Meldung eine Zeile `meldung id=<id> bundle=<buildBundleId> plattform=<appPlatform> datum=<createdDate> bericht=ja|nein`
  (fehlt ein Attribut, steht `unbekannt`);
- am Ende `zusammenfassung meldungen=<n> mit_bericht=<a> ohne_bericht=<b>`;
- ohne eine einzige Meldung genau die Zeile `keine Absturzmeldungen` (keine Zusammenfassung), Exit 0.
- die Wiederholungszeilen von `get_json` (`ASC answered HTTP <code> for <pfad>, retrying`, `No answer from ASC for <pfad> …`,
  `ASC sent no JSON for <pfad>, retrying`): sie enthalten nur Statuscode und Pfad ohne Abfrage, keinen Antwortinhalt.

**Nie ausgegeben:** `email`, `comment`, `deviceModel`, `deviceFamily`, `devicePlatform`, `locale`, `timeZone`, `osVersion`,
`architecture`, `connectionType`, `batteryPercentage`, `diskBytesAvailable`, `diskBytesTotal`, `screenWidthInPoints`,
`screenHeightInPoints`, `appUptimeInMilliseconds`, `pairedAppleWatch`, nie `logText`, nie Schlüssel,
Token, Signatur oder Header. Die Zeile nennt nur die vier erlaubten Felder; es wird kein Attribut-Wörterbuch gedruckt und kein
Ausnahmetext mit Antwortinhalt (die `Fatal`-Meldungen von `get_json` enthalten nur Statuscode und Pfad).

**Exit-Codes.** 0 bei Erfolg (auch bei null Meldungen und bei Meldungen ohne Bericht). 1 mit `::error::<Meldung>` bei `Fatal`
(Konfiguration fehlt, App nicht gefunden, 4xx außer dem Bericht-404, nach fünf Versuchen keine Antwort, unerwartete Id). 2 bei
falschem Aufruf.

### 2. `scripts/test_asc_crashes.py`

`unittest`, nur Standardbibliothek, Aufruf `python3 scripts/test_asc_crashes.py`; läuft in der CI über `unittest discover`.
Aufbau wie `test_asc_what_to_test.py`: `setUp` erzeugt mit `openssl` einen Wegwerf-Schlüssel, `FakeASC` (lokaler `HTTPServer`)
beantwortet die App-Suche, die Liste und den Bericht und merkt sich **Methode und Pfad jeder Anfrage**; das Skript läuft als
Unterprozess mit `ASC_API_BASE` auf den Nachbau und `ASC_POLL_SECONDS=0`. Der Nachbau liefert `links.next` als absolute Adresse
auf sich selbst (wie Apple) und kann je Pfad eine Statusfolge abspielen (z. B. erst 500, dann 200). Die Testdaten tragen
**eindeutige Markierungsstrings**, die in keinem Log vorkommen dürfen: `tester-MARKER@example.test`, `COMMENT-MARKER`,
`iPhone-MARKER`, `LOG-MARKER` (im `logText`), `LOCALE-MARKER`, `ZONE-MARKER`.

### Alternativen, nicht gewählt

- **Plattformen getrennt abfragen** (zwei Läufe): nicht nötig, `appPlatform` steht je Meldung, und ein Lauf holt alles.
- **Eigene Abfrage mit Status statt `get_json`** (wie `asc_beta_probe.py`): würde 404 sauber trennen, kostet aber ein zweites
  HTTP-Stück im Repo. Der Textabgleich auf `HTTP 404` ist kleiner und durch einen Test gesichert.
- **Berichte gleich auf dem Runner symbolisieren:** erst sinnvoll, wenn ein echter Bericht zeigt, dass er unsymbolisiert kommt.

## Expected Behavior

- **Eingabe:** `python3 scripts/asc_crashes.py <zielordner>` mit `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_BUNDLE_ID` in der Umgebung.
- **Ausgabe:** je Meldung `<id>.json` und, wenn Apple einen Bericht hat, `<id>.crash` im Zielordner (Modus `0600`); im Log
  nur die Zeilen aus „Log (Datenschutz)“, ohne Meldung genau `keine Absturzmeldungen`.
- **Seiteneffekte:** nur GET-Anfragen an App Store Connect, Schreiben nur unterhalb des Zielordners; keine App-Datei, keine
  Workflow-Datei, kein Secret.

## Known Limitations

**Ehrliche Grenze des Tests.**

Der Nachbau prüft **nur die Form**: Dass das Skript die richtigen Pfade abfragt, `links.next` folgt, Dateien richtig schreibt,
Fehler richtig einordnet und nichts Persönliches druckt. Er prüft **nicht**, ob Apple diese Pfade und Attribute so beantwortet,
ob jede Meldung einen Bericht hat (ein Hänger ohne echten Absturz liefert oft keinen) und ob der Bericht symbolisiert ist
(`uploadSymbols` ist an, belegt ist es noch nicht). Das zeigt erst der echte Lauf in Schnitt 2, und ein Lauf ohne Meldung belegt den Weg nur halb.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_crashes.py`. Zuerst geschrieben; ohne `scripts/asc_crashes.py` schlagen sie fehl.

- [ ] `test_no_submissions`: GIVEN Nachbau mit leerer Liste WHEN das Skript läuft THEN Exit 0, stdout enthält die Zeile `keine Absturzmeldungen`, der Zielordner ist angelegt und leer.
- [ ] `test_two_pages_via_links_next`: GIVEN Seite 1 mit zwei Meldungen und `links.next` auf Seite 2 mit einer Meldung WHEN das Skript läuft THEN Exit 0, drei `meldung id=…`-Zeilen, `zusammenfassung meldungen=3`, und der Nachbau hat die Liste mit `limit=200` angefragt sowie Seite 2 genau einmal.
- [ ] `test_files_have_expected_content`: GIVEN Meldung `S1` mit Attributen und Bericht WHEN das Skript läuft THEN `S1.json` enthält die Attribute der Meldung unverändert (als JSON gelesen gleich dem gelieferten Objekt), `S1.crash` enthält den `logText` Zeichen für Zeichen (auch Umlaute und Zeilenumbrüche), beide Dateien haben Modus `0600`.
- [ ] `test_missing_crashlog_counts_as_without_report`: GIVEN Meldung `S2`, deren `crashLog` mit 404 antwortet, und Meldung `S1` mit Bericht WHEN das Skript läuft THEN Exit 0, die `S2`-Zeile endet auf `bericht=nein`, `zusammenfassung meldungen=2 mit_bericht=1 ohne_bericht=1`, `S2.json` existiert, `S2.crash` existiert nicht.
- [ ] `test_empty_logtext_counts_as_without_report`: GIVEN `crashLog` mit leerem `logText` THEN `bericht=nein`, keine `.crash`-Datei.
- [ ] `test_server_error_once_is_retried`: GIVEN Nachbau antwortet auf die Liste zuerst mit 500, dann mit 200 WHEN das Skript läuft THEN Exit 0 und alle Meldungen sind geschrieben.
- [ ] `test_server_error_always_exits_1`: GIVEN Nachbau antwortet auf die Liste immer mit 500 THEN Exit 1 mit `::error::` und genau fünf Versuchen auf diesem Pfad.
- [ ] `test_forbidden_exits_1`: GIVEN Nachbau antwortet auf die Liste mit 403 WHEN das Skript läuft THEN Exit 1, stdout enthält `::error::` und `HTTP 403`, es wird keine Datei geschrieben. Ebenso bei 403 auf dem `crashLog` (kein „ohne Bericht“).
- [ ] `test_log_has_no_personal_data`: GIVEN Meldung mit E-Mail, Kommentar, Gerätemodell, Sprache und Zeitzone sowie Bericht mit den Markierungsstrings WHEN das Skript läuft THEN keiner der Strings (`tester-MARKER@example.test`, `COMMENT-MARKER`, `iPhone-MARKER`, `LOG-MARKER`, `LOCALE-MARKER`, `ZONE-MARKER`) steht in stdout oder stderr, und weder `BEGIN`/`PRIVATE KEY` noch `Bearer`/`eyJ`; die Zeile enthält dagegen `id=`, `bundle=`, `plattform=` und `datum=`. Gilt auch für den Fehlerfall (`test_forbidden_exits_1` prüft stdout und stderr auf dieselben Strings).
- [ ] `test_both_platforms_in_one_run`: GIVEN eine Meldung `appPlatform=IOS` und eine `appPlatform=MAC_OS` WHEN das Skript läuft THEN beide stehen im Log mit ihrer Plattform und die Anfrage der Liste trägt keinen Plattformfilter (`filter` kommt im Pfad nicht vor).
- [ ] `test_only_get_requests`: GIVEN beliebiger Lauf THEN der Nachbau hat ausschließlich GET empfangen.
- [ ] `test_unsafe_id_exits_1`: GIVEN Meldung mit Id `../evil` WHEN das Skript läuft THEN Exit 1 mit `::error::`, und außerhalb des Zielordners wurde nichts geschrieben.
- [ ] `test_usage_and_missing_environment`: GIVEN kein Argument THEN Exit 2 mit `usage:`; GIVEN fehlende `ASC_KEY_ID` THEN Exit 1 mit `Missing environment`.

### Manuelle Tests

Keine, auch nicht auf Hennings Geräten. Der echte Lauf gegen Apple gehört zu Schnitt 2.

## Acceptance Criteria

- **AC-1:** `scripts/asc_crashes.py <zielordner>` holt alle Absturzmeldungen der App über `betaFeedbackCrashSubmissions?limit=200` und folgt `links.next` bis zum Ende, ohne Plattformfilter (iOS und Mac in einem Lauf, `appPlatform` je Meldung). Belegt durch `test_two_pages_via_links_next`, `test_both_platforms_in_one_run`.
- **AC-2:** Je Meldung entstehen im Zielordner `<id>.json` (Attribute unverändert) und `<id>.crash` (`logText` unverändert), beide mit Modus `0600`; der Zielordner wird angelegt, falls er fehlt. Belegt durch `test_files_have_expected_content`, `test_no_submissions`.
- **AC-3:** Fehlt der Bericht (404 beim `crashLog` oder leerer `logText`), wird die Meldung als „ohne Bericht“ gezählt, `<id>.json` entsteht, `<id>.crash` nicht, Exit 0. Belegt durch `test_missing_crashlog_counts_as_without_report`, `test_empty_logtext_counts_as_without_report`.
- **AC-4:** Fehlerbehandlung: 5xx, 408, 429 und Netzfehler werden bis zu fünfmal wiederholt (danach Exit 1 mit `::error::`); jeder andere 4xx-Status, auch ein 403 beim Bericht, ist Exit 1 mit `::error::` ohne Dateien. Belegt durch `test_server_error_once_is_retried`, `test_server_error_always_exits_1`, `test_forbidden_exits_1`.
- **AC-5:** Das Log enthält nur Anzahl Meldungen, Anzahl mit und ohne Bericht, je Meldung Id, Bundle-ID, Plattform und Datum sowie die Wiederholungszeilen von `get_json` (Statuscode und Pfad); nie E-Mail, Kommentar, Gerätemodell, Sprache, Zeitzone, `logText`, Schlüssel oder Token, weder bei Erfolg noch bei Fehler. Ohne Meldungen steht genau `keine Absturzmeldungen` und Exit 0. Belegt durch `test_log_has_no_personal_data`, `test_no_submissions`, `test_forbidden_exits_1`.
- **AC-6:** Das Skript führt ausschließlich GET-Anfragen aus und schreibt nur unterhalb des Zielordners (unzulässige Ids brechen ab). Belegt durch `test_only_get_requests`, `test_unsafe_id_exits_1` und Diff-Durchsicht (kein `send_json`, kein PATCH/POST/DELETE im Skript).
- **AC-7:** Aufruf und Konfiguration: ohne Argument Exit 2 mit `usage:`, bei fehlender Umgebung Exit 1 mit `Missing environment`; `asc_wait_build.py` bleibt unverändert. Belegt durch `test_usage_and_missing_environment` und `git diff --stat` (nur die zwei Dateien des Scopes).
- **AC-8:** Die Tests laufen ohne Änderung an `ci.yml` über `unittest discover -s scripts -p 'test_*.py'` mit; alle vorhandenen Skripttests bleiben grün. Belegt durch `python3 -m unittest discover -s scripts -p 'test_*.py'` und `git diff --stat` (`ci.yml` nicht im Diff).
- **AC-9:** Der Diff berührt genau die zwei Dateien des Scopes, kein `project.yml`, kein App-Code, keine Workflow-Datei, kein Pfad der Geräteliste, und liegt bei höchstens ±250 LoC. Belegt durch `git diff --stat` im Abschlussbericht, mit dem Satz „Kein Pfad der Geräteliste berührt.“ Stufe 2 (Simulator) entfällt, weil die App nicht berührt wird; die Abnahme endet nach den Tests.
- **AC-10:** Während der Umsetzung läuft nichts auf Hennings Geräten, kein TestFlight-Lauf und kein Aufruf gegen die echte App-Store-Connect-API. Belegt durch Abschlussbericht (Befehlsliste).

Kein Pfad der Geräteliste berührt.

## Out of Scope (Schnitt 2, eigene Spec)

- **Workflow `.github/workflows/asc-crashes.yml`** (`workflow_dispatch`, Schlüssel wie in `asc-beta.yml`, Skript schreibt nach
  `$RUNNER_TEMP`, `tar` plus `gpg --encrypt` zu `crashes.tar.gpg`, Klartext per `trap rm` weg, Aufbewahrung 14 Tage).
- **GPG-Schlüssel:** Erzeugung ohne Passphrase auf diesem Mac, öffentlicher Teil im Repo (Name und Secrets-Guard in der Spec von
  Schnitt 2), privater Teil nur im GnuPG-Verzeichnis dieses Macs.
- **Doku** in `docs/reference/testflight.md`: Abschnitt „Absturzberichte abholen“ (Lauf, `gh run download`, Entschlüsseln, Symbolisieren).
- **Probelauf gegen Apple:** klärt, ob jede Meldung einen Bericht hat und ob er symbolisiert ist. Gibt es keine Meldung, belegt der Lauf den Weg nur halb.
- **Symbolisierung (`atos` gegen das dSYM)** erst, wenn ein echter Bericht zeigt, dass sie nötig ist.
- **Restock (#242):** Übertragung nach Abschluss dieses Tickets, mit eigener Bibliothek und eigener Sichtbarkeitsprüfung.
- **Alles auf Hennings Geräten.**

## Definition of Done

- [ ] `scripts/test_asc_crashes.py` war vor dem Skript rot und ist danach grün (13 Tests).
- [ ] Alle vorhandenen Skripttests (`python3 -m unittest discover -s scripts -p 'test_*.py'`) bleiben grün.
- [ ] Der Diff berührt nur die zwei Dateien des Scopes; `asc_wait_build.py` und `ci.yml` unverändert.
- [ ] Ticket #773 bleibt offen (`Refs #773`); Schnitt 2 wird als eigene Spec geschrieben.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reines Lese-Skript mit Test; kippt keine ADR und ändert keine Architektur des Produkts.

## Changelog

- 2026-10-31: Initial spec created
