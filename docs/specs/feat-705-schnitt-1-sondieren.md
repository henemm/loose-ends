---
entity_id: feat-705-schnitt-1-sondieren
type: feature
created: 2026-10-26
updated: 2026-10-26
status: draft
workflow: feat-705-apple-seite-einladung
---

# Spec: #705 Schnitt 1 „Sondieren“: Apples Beta-Seite nur lesend abfragen

## Approval

- [ ] Approved

## Purpose

Die Apple-Seite der ersten externen Einladung (Beta-Review, Beschreibung, Kontaktangaben, Gruppen, öffentlicher Link,
Build-Zuordnung für iPhone, iPad und Mac) soll per App-Store-Connect-API eingerichtet werden. Bisher stützt sich die Analyse
auf Apple-Hilfeseiten und Drittquellen (fastlane, Foren); Attributnamen der Detail-Objekte waren bei Apple nicht abrufbar, und
Rolle und Rechte des Schlüssels sind nicht belegt. Schnitt 1 beantwortet das, **bevor irgendetwas geschrieben wird**: ein
Skript, das ausschließlich liest und eine Belegtabelle in den Lauf-Log druckt (Rolle/Zugriff, vorhandene Gruppen, Beschreibungs-
und Kontaktfelder als „gesetzt/leer“, Builds beider Plattformen samt Prüfstatus, bestehende Beta-Einreichungen). Apples echte
Antworten ersetzen die Drittquellen. Die Einreichung an Apple ist per API nicht zurückziehbar; darum entsteht erst der Befund
(Schnitt 1), dann das Einrichten und Einreichen (Schnitt 2, eigene Spec).

Ohne Modell: reine API-Abfragen, kein Modellweg.

Alternative B (einmal in der App-Store-Connect-Oberfläche nachsehen statt Skript) wurde erwogen: weniger Code, aber kein
Beleg im Lauf-Log, nicht wiederholbar je Build und Plattform, und Henning bekäme Klickarbeit (Regel „ich übernehme“). Gewählt
ist **A (Skript plus Handlauf in der CI)**: der Beleg steht im Lauf-Log, der Lauf ist je Build und Plattform wiederholbar, und
Apples echte Antworten ersetzen die Drittquellen der Analyse. B bleibt Rückfall für alles, was die API nicht kann.

## Source

- **File:** `scripts/asc_beta_probe.py` (neu)
- **Identifier:** `main(argv)`, Ausgabe der Belegtabelle (ein Abschnitt je Abfrage); Bausteine aus `scripts/asc_wait_build.py`
  (`Fatal`, `make_token`, `get_json`, `find_app_id`, `platform_filter`, `read_config`) und `scripts/asc_what_to_test.py` (`get_data`).
  Vorbild für den Test: `scripts/test_asc_what_to_test.py` (`FakeASC`). Analyse: `docs/context/feat-705-apple-seite-einladung.md`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/asc_wait_build.py` | Skript | JWT (`make_token`), `get_json`, `find_app_id`, `read_config`, `platform_filter`; wird importiert, nicht geändert |
| `scripts/asc_what_to_test.py` | Skript | `get_data` (Liste `data` mit Wiederholung); wird importiert, nicht geändert |
| `.github/workflows/testflight.yml` | Workflow | Vorbild für Runner und Schlüsseldatei im Job `confirm` (`ubuntu-latest`, `printf` in `$RUNNER_TEMP`, `umask 077`, `trap rm`); bleibt unberührt |
| Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | GitHub Secrets | Gibt es schon (testflight.md Schritt 4); kein neues Secret |
| #342 / PR #709 | Ticket | Datenschutz-Entwurf und Texte; berührt keine Datei dieses Schnitts |
| #371 | Epic | Einladung externer Tester; Schnitt 1 ist die Grundlage für Schnitt 2 |
| #176 | Ticket | Abnahme vor der Einladung; nur Bezug |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_beta_probe.py | CREATE | Nur GET: Belegtabelle zu Zugriff, Gruppen, Lokalisierungen, Review-Detail, Builds, Einreichungen |
| scripts/test_asc_beta_probe.py | CREATE | `unittest` gegen lokalen API-Nachbau (`FakeASC`-Muster) plus Prüfung der Workflow-Datei |
| .github/workflows/asc-beta.yml | CREATE | Handlauf (`workflow_dispatch`), je Plattform ein Probe-Lauf; `testflight.yml` bleibt unberührt |
| docs/reference/testflight.md | MODIFY | Abschnitt „Einladung: Apple-Seite (#705)“ mit Prüfliste (Status „offen“, Spalte „Beleg“ leer) |

### Estimated Changes
- Files: 4, kein Produktcode, kein Pfad der Geräteliste
- LoC: ca. +200/-0 (ca. 90 `asc_beta_probe.py`, ca. 70 `test_asc_beta_probe.py`, ca. 20 `asc-beta.yml`, ca. 25 `testflight.md`)

## Implementation Details

### 1. `scripts/asc_beta_probe.py`

Nur Standardbibliothek plus `openssl` (wie die anderen ASC-Skripte). Aufruf: `asc_beta_probe.py` ohne Argument. Umgebung wie
`asc_wait_build.py` (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_BUNDLE_ID`, `ASC_API_BASE`, `ASC_PLATFORM`,
`ASC_POLL_SECONDS`). **Es gibt keinen schreibenden Aufruf**: weder `send_json` noch PATCH/POST/DELETE werden importiert oder benutzt.

**Eigene Abfrage statt `get_json`-Fatal.** `get_json` macht aus 401/403/404 ein `Fatal`. Die Probe braucht den Status als Befund.
Sie ruft darum eine kleine eigene Funktion `probe(config, path)` auf, die `make_token` benutzt und `(status, body)` zurückgibt:
`(200, dict)` bei Erfolg, `(403, None)`/`(404, None)`/andere 4xx als Befund, bei 5xx/408/429/Netzfehler bis zu fünf Versuche
mit `ASC_POLL_SECONDS` Pause, danach `(None, None)` = „keine Antwort“. `find_app_id` wird unverändert aus `asc_wait_build` benutzt
(App nicht gefunden = Konfigurationsfehler, `Fatal`).

**Abfragen** (alle GET; `APP` = App-Id):

| Nr | Pfad | Zeigt |
|----|------|-------|
| 1 | `/v1/apps/APP/betaGroups` | Zugriff auf Gruppen (HTTP-Status) und die Gruppen selbst |
| 2 | `/v1/apps/APP/betaAppReviewDetail` | Zugriff (HTTP-Status) und Attributnamen des Review-Details |
| 3 | `/v1/apps/APP/betaAppLocalizations` | Zugriff (HTTP-Status) und Beschreibungs-, Feedback-, Datenschutzfelder je Sprache |
| 4 | `/v1/builds?filter[app]=APP&sort=-version&limit=5` plus `platform_filter` | Builds der Plattform aus `ASC_PLATFORM` |
| 5 | je Build `/v1/builds/ID/buildBetaDetail` und `/v1/builds/ID/betaAppReviewSubmission` | externer und interner Prüfstatus des Builds |
| 6 | `/v1/betaAppReviewSubmissions?filter[build]=ID` je Build | bestehende Beta-Review-Einreichungen und ihr Zustand |

Die Pfade stammen aus der Analyse (Apple-Dokumentation, teils Drittquelle). **Welche davon Apple wirklich so annimmt, ist ein
Ergebnis des Handlaufs**: antwortet Apple 404 oder 400, steht das als Befund in der Tabelle (und führt in Schnitt 2 zur
Korrektur des Pfads), nicht als Skriptfehler.

**Ausgabe: Belegtabelle im Lauf-Log**, Textzeilen mit festem Muster `schluessel=wert`, damit man sie greppen und abhaken kann:

1. **Zugriff** (je Abfrage 1–6; Abfragen 5 und 6 je Build, mit `build=<Nummer>` in der Zeile): `zugriff abfrage=betaGroups http=200`, `… http=403` usw. Feste Namen: `betaGroups`, `betaAppReviewDetail`, `betaAppLocalizations`, `builds` (Abfrage 4), `buildBetaDetail` (5), `betaAppReviewSubmissions` (6). Bei „keine Antwort“ (5xx/Netzfehler nach allen Versuchen) steht `http=keine`. Ein 403 oder 404 wird als
   `befund=…` **auf derselben Zeile** gemeldet („Schlüssel hat keinen Zugriff oder Pfad unbekannt“), nicht als Fehler. Die Rolle des Schlüssels
   schließt der Leser aus dem Muster der Stati; die Probe behauptet sie nicht.
2. **Gruppen**: je Gruppe `gruppe name=… intern=ja|nein link=an|aus url=… feedback=an|aus`. Der öffentliche Link (`publicLink`)
   ist ein Einladungslink ohne Personenbezug und darf stehen. Keine Gruppe: `gruppe keine`.
3. **Lokalisierungen**: je Sprache `lokalisierung locale=… beschreibung=gesetzt|leer feedbackEmail=gesetzt|leer
   datenschutzUrl=gesetzt|leer`. **Nur „gesetzt/leer“, nie der Inhalt.**
4. **Review-Detail**: `reviewdetail attribute=<Namen kommagetrennt>` und je Attribut `gesetzt|leer` (z. B. Kontaktvorname,
   -nachname, -telefon, -e-mail, Demo-Zugang). **Nur Namen und „gesetzt/leer“, nie die Werte.** Das beantwortet offene Frage 2
   der Analyse (welche Felder Apple liefert).
5. **Builds** (je Plattform): `build nummer=… plattform=IOS|MAC_OS processingState=… intern=<Status> extern=<Status>
   einreichung=<Zustand>|keine`. Der Lauf-Workflow ruft die Probe je Plattform auf (`ASC_PLATFORM=IOS`, dann `MAC_OS`); leer
   gesetztes `ASC_PLATFORM` zeigt alle Builds ohne Filter.
6. **Einreichungen**: `einreichung build=… zustand=…` je gefundener Einreichung, sonst `einreichung keine`.

**Nie ausgegeben:** Schlüssel, Token, Signatur, Header, Inhalt von Kontaktdaten (Name, Telefon, E-Mail), Feedback-E-Mail,
Beschreibungstext, Datenschutz-URL (nur „gesetzt“). Die `Fatal`-Meldungen enthalten wie bisher nie Header oder Schlüssel.

**Ende und Exit-Code.** Am Schluss eine Zeile `zusammenfassung antworten=<n> von=<k> befunde=<m>` (k = Zahl aller gestellten Abfragen, Abfragen 5 und 6 je Build gezählt). Exit 0, auch wenn einzelne Abfragen
403/404 liefern (Befund). Exit 1 (`::error::`) nur bei Konfigurationsfehler (fehlende Umgebung, App nicht gefunden, `openssl`
kann nicht signieren) oder wenn **keine** Abfrage geantwortet hat. „Geantwortet“ heißt: irgendein HTTP-Status kam an, auch 403 oder 404 (das ist ein Befund, Exit 0). „Keine Antwort“ ist nur `(None, None)`: 5xx, 408, 429 oder Netzfehler bei allen Versuchen und allen Abfragen (Netz/Apple ganz unbrauchbar). Exit 2 gibt es nicht
(kein Argument).

### 2. `.github/workflows/asc-beta.yml`

- Auslöser: nur `workflow_dispatch` (keine Eingabe nötig; kein `push`, kein `schedule`, kein `workflow_run`).
- Rechte: `permissions: contents: read`.
- Ein Job `probe` mit Matrix `platform: [IOS, MAC_OS]`, `runs-on: ubuntu-latest`, `timeout-minutes: 10`,
  `env: ASC_KEY_ID, ASC_ISSUER_ID` aus Secrets, `ASC_PLATFORM: ${{ matrix.platform }}`.
- Schritte: `actions/checkout@v7`; dann ein Schritt nach dem Muster des Jobs `confirm` in `testflight.yml`:
  `trap 'rm -f "$RUNNER_TEMP/asc_key.p8"' EXIT`, `umask 077`, Schlüssel per `printf` aus `secrets.ASC_PRIVATE_KEY` schreiben,
  `ASC_KEY_FILE="$RUNNER_TEMP/asc_key.p8" python3 scripts/asc_beta_probe.py`. Kein macOS-Runner (keine Minuten).
- `testflight.yml` wird **nicht** geändert. Das Skript läuft nicht automatisch nach einem Build.

### 3. `scripts/test_asc_beta_probe.py`

`unittest`, nur Standardbibliothek, Aufruf `python3 scripts/test_asc_beta_probe.py`. Wie in `test_asc_what_to_test.py` erzeugt
`setUp` einen Wegwerf-Schlüssel mit `openssl`, ein `FakeASC` (lokaler `HTTPServer`) beantwortet die Pfade der Tabelle oben und
merkt sich **jede Anfrage mit ihrer Methode**; das Skript läuft als Unterprozess mit `ASC_API_BASE` auf den Nachbau,
`ASC_POLL_SECONDS=0`. Der Nachbau nimmt nur GET an; jede andere Methode macht den Test rot.

### 4. `docs/reference/testflight.md`

Neuer Abschnitt **„Einladung: Apple-Seite (#705)“** (nach Abschnitt 6): eine Tabelle `Teil | Status | Beleg` mit diesen Zeilen,
Status überall `offen` (Ausnahme Exportnachweis), Spalte Beleg leer, bis ein Lauf sie füllt:

| Teil | Status | Beleg |
|------|--------|-------|
| Exportnachweis | erledigt: `ITSAppUsesNonExemptEncryption=false` in `project.yml`, im Archiv geprüft (Verify-Schritt) | `project.yml`, Verify-Schritt |
| Beta-App-Beschreibung | offen | |
| Feedback-E-Mail | offen | |
| Kontaktangaben (Beta-Review-Detail) | offen | |
| Datenschutz-URL | offen | |
| Interne Gruppe `Familie` | offen | |
| Externe Gruppe mit öffentlichem Link | offen | |
| Build-Zuordnung iOS und macOS | offen | |
| Beta-Review (Einreichung) | offen | |
| Rückmeldeweg: TestFlight-Feedback | offen | |

Darunter: wie der Handlauf `asc-beta.yml` gestartet und gelesen wird (Matrix IOS/MAC_OS, welche Zeilen des Logs welchen Teil
belegen) und der Hinweis, dass **Schnitt 2** (Einrichten und Einreichen) separat folgt: nur auf ausdrücklichen Lauf, Schalter
`submit` standardmäßig aus, Eingaben (Beschreibung, Kontakt, Feedback-E-Mail) von Henning, nie aus dem Repo geraten. Der
bestehende Satz in Abschnitt 6 „unter #342 Teil 3“ bleibt; der neue Abschnitt verweist für die Gruppen auf #705.

### Ehrliche Grenze des Tests

Der Nachbau prüft **nur die Form**: Dass die Probe die erwarteten Pfade abfragt, nur liest, Befunde statt Fehler meldet und nichts
Persönliches druckt. Er prüft **nicht**, ob Apple diese Pfade, Attributnamen und Rollen so beantwortet; er ist von denselben
Drittquellen abgeleitet wie die Analyse. Apples echte Antworten zeigt erst der echte Handlauf nach dem Merge. Darum verlangt
N-1 einen dokumentierten Handlauf als Beleg im Ticket, und das Ticket bleibt offen (`Refs #705`).

### Alternativen, nicht gewählt

- **B: einmal in der Oberfläche nachsehen** (siehe Purpose): billig, aber ohne Beleg, nicht wiederholbar, Klickarbeit für Henning.
- **Die Abfragen in `testflight.yml` (`confirm`) einbauen:** läuft bei jedem Build mit, belegt den Zustand je Build. Verworfen, weil
  die Pipeline des Uploads nicht gefährdet werden soll (Analyse, Risiko) und ein Lesebefund keinen Build-Lauf braucht.
- **Gleich schreiben (Schnitt 1 und 2 in einem):** schneller, aber die Einreichung ist nicht rücknehmbar (kein DELETE) und
  braucht Hennings Wortlaut und Kontaktdaten; ohne Befund würden Pfade und Pflichtfelder geraten. Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_beta_probe.py`. Zuerst geschrieben; ohne `scripts/asc_beta_probe.py` und `asc-beta.yml` schlagen sie fehl.

- [ ] `test_everything_present`: GIVEN Nachbau mit zwei Gruppen (eine intern, eine extern mit öffentlichem Link), Lokalisierung mit gesetzter Beschreibung, Review-Detail, einem Build mit Einreichung WHEN die Probe läuft THEN Exit 0 und die Ausgabe enthält je eine Zeile `zugriff … http=200` für alle sechs Abfragen, die `gruppe`-Zeilen mit `intern=ja`/`nein`, `link=an`, `url=<Adresse>` und `feedback=an`, `lokalisierung … beschreibung=gesetzt`, eine Zeile `reviewdetail attribute=` mit den Attributnamen des Nachbaus und je Attribut `gesetzt`/`leer`, `build nummer=…` mit `processingState=`, `intern=` und `extern=`, sowie `einreichung build=…`.
- [ ] `test_forbidden_on_groups_is_a_finding`: GIVEN Nachbau antwortet auf `betaGroups` mit 403 WHEN die Probe läuft THEN Exit 0, Ausgabe enthält `zugriff abfrage=betaGroups http=403` und `befund=` auf derselben Zeile; zusätzlich erscheinen die Zeilen `reviewdetail attribute=` und `build nummer=` trotzdem (Abschnitte nach dem 403 laufen weiter).
- [ ] `test_empty_description_is_reported_as_empty`: GIVEN Lokalisierung mit leerer Beschreibung und ohne `feedbackEmail` WHEN die Probe läuft THEN `beschreibung=leer` und `feedbackEmail=leer`.
- [ ] `test_no_group`: GIVEN `betaGroups` mit leerer Liste WHEN die Probe läuft THEN Exit 0 und `gruppe keine`.
- [ ] `test_both_platforms`: GIVEN Nachbau mit je einem Build für IOS und MAC_OS und ein Lauf je `ASC_PLATFORM` THEN der Lauf mit `IOS` meldet `plattform=IOS`, der mit `MAC_OS` meldet `plattform=MAC_OS`, und die Anfrage trägt jeweils `filter[preReleaseVersion.platform]=…`.
- [ ] `test_only_get_requests`: GIVEN beliebiger Lauf THEN der Nachbau hat ausschließlich GET empfangen (kein PATCH, POST, DELETE).
- [ ] `test_output_has_no_contact_values_and_no_key`: GIVEN Nachbau mit erkennbaren Kontaktwerten (z. B. `Maxi Beispiel`, `+49 170 0000000`, `kontakt@example.test`), Beschreibungstext und Datenschutz-URL WHEN die Probe läuft THEN keiner dieser Werte, kein Schlüsseltext (`BEGIN`/`PRIVATE KEY`), kein Token (`Bearer`, `eyJ`) steht in stdout oder stderr; stattdessen `gesetzt`.
- [ ] `test_nothing_answers_exits_1`: GIVEN Nachbau, der die App-Suche beantwortet und jede weitere Abfrage mit 500 (alle Versuche), WHEN die Probe läuft THEN Exit 1 mit `::error::`.
- [ ] `test_all_404_is_findings_exit_0`: GIVEN Nachbau, der die App-Suche beantwortet und jede weitere Abfrage mit 404 WHEN die Probe läuft THEN Exit 0, jede `zugriff`-Zeile trägt `http=404` und `befund=` auf derselben Zeile.
- [ ] `test_app_not_found_exits_1`: GIVEN Nachbau mit leerer App-Suche WHEN die Probe läuft THEN Exit 1 mit `::error::` (Konfigurationsfehler).
- [ ] `test_missing_environment_exits_1`: GIVEN fehlende `ASC_KEY_ID` THEN Exit 1 mit `Missing environment`.
- [ ] `test_workflow_file`: GIVEN `.github/workflows/asc-beta.yml` THEN es enthält `workflow_dispatch`, kein `push:`/`schedule:`/`workflow_run:`, die Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, die Matrix `platform: [IOS, MAC_OS]` samt `ASC_PLATFORM: ${{ matrix.platform }}`, `runs-on: ubuntu-latest`, `scripts/asc_beta_probe.py`, `umask 077` und das Entfernen der Schlüsseldatei (`rm -f`), und `testflight.yml` enthält den Namen `asc_beta_probe` nicht.

### Manuelle Tests

Keine auf Hennings Geräten (Apple-Seite braucht kein Gerät). Der Handlauf in GitHub Actions ist der Nachweis aus N-1, kein manueller Gerätetest.

## Acceptance Criteria

- **AC-1:** `scripts/asc_beta_probe.py` existiert und führt ausschließlich GET-Anfragen aus; der Nachbau empfängt keine andere Methode. Belegt durch `python3 scripts/test_asc_beta_probe.py` (`test_only_get_requests`) und Diff-Durchsicht (kein `send_json`, kein PATCH/POST/DELETE im Skript).
- **AC-2:** Die Probe meldet je Abfrage den HTTP-Status als Zeile `zugriff … http=<Status>`; 403 und 404 einzelner Abfragen sind ein Befund (`befund=`) mit Exit 0, die übrigen Abschnitte erscheinen trotzdem. Belegt durch `test_everything_present`, `test_forbidden_on_groups_is_a_finding`.
- **AC-3:** Die Probe listet vorhandene Gruppen mit Name, interner/externer Gruppe, öffentlichem Link (an/aus und Adresse) und Feedback (an/aus); ohne Gruppe steht `gruppe keine`. Belegt durch `test_everything_present`, `test_no_group`.
- **AC-4:** Lokalisierungen und Review-Detail erscheinen nur als „gesetzt/leer“ je Feld, das Review-Detail zusätzlich mit den Attributnamen, die Apple liefert; nie mit dem Inhalt. Belegt durch `test_everything_present`, `test_empty_description_is_reported_as_empty` und `test_output_has_no_contact_values_and_no_key`.
- **AC-5:** Die Probe zeigt Builds der Plattform aus `ASC_PLATFORM` (IOS und MAC_OS getrennt) mit Nummer, `processingState`, Prüfstatus und bestehenden Beta-Review-Einreichungen. Belegt durch `test_both_platforms`, `test_everything_present`.
- **AC-6:** Weder Schlüssel, Token, Signatur noch persönliche Daten (Kontaktwerte, Feedback-E-Mail, Beschreibungstext, Datenschutz-URL) stehen in stdout oder stderr. Belegt durch `test_output_has_no_contact_values_and_no_key`.
- **AC-7:** Exit 0 bei Befunden einzelner Abfragen; Exit 1 mit `::error::` nur bei Konfigurationsfehler oder wenn keine Abfrage antwortet. Belegt durch `test_forbidden_on_groups_is_a_finding`, `test_all_404_is_findings_exit_0`, `test_nothing_answers_exits_1`, `test_app_not_found_exits_1`, `test_missing_environment_exits_1`.
- **AC-8:** `.github/workflows/asc-beta.yml` startet nur per `workflow_dispatch`, nutzt die Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, läuft die Probe je Plattform (IOS, MAC_OS) auf `ubuntu-latest` und entfernt die Schlüsseldatei; `.github/workflows/testflight.yml` ist unverändert. Belegt durch `test_workflow_file` und `git diff --stat` (testflight.yml nicht im Diff).
- **AC-10:** `docs/reference/testflight.md` enthält den Abschnitt „Einladung: Apple-Seite (#705)“ mit den zehn Teilen (Exportnachweis, Beta-App-Beschreibung, Feedback-E-Mail, Kontaktangaben, Datenschutz-URL, interne Gruppe `Familie`, externe Gruppe mit öffentlichem Link, Build-Zuordnung iOS und macOS, Beta-Review, Rückmeldeweg TestFlight-Feedback), Status „offen“ und leerer Spalte „Beleg“ (Exportnachweis „erledigt“ mit Verweis auf `project.yml`), dazu den Hinweis auf Schnitt 2 (nur auf ausdrücklichen Lauf, `submit` aus als Standard, Eingaben von Henning). Belegt durch Diff (`grep -n "Apple-Seite (#705)" docs/reference/testflight.md` ein Treffer, `grep -n "submit" docs/reference/testflight.md` mindestens ein Treffer).
- **AC-11:** Der Diff berührt genau die vier Dateien des Scopes, kein `project.yml`, kein App-Code, kein `testflight.yml`, kein Pfad der Geräteliste, und liegt bei höchstens ±250 LoC. Belegt durch `git diff --stat` im Abschlussbericht, mit dem Satz „Kein Pfad der Geräteliste berührt.“
- **AC-12:** Während der Umsetzung läuft nichts auf Hennings Geräten (kein `devicectl`, `sim.sh device*`, `launch-measure`, `lab`), kein TestFlight-Lauf und kein schreibender Aufruf gegen App Store Connect. Belegt durch Abschlussbericht (Befehlsliste).

Kein Pfad der Geräteliste berührt.

## Nachweise nach dem Merge

Diese zwei Punkte sind keine Abnahmekriterien der Umsetzung, weil sie vor dem Merge nicht belegbar sind (Henning, `override` 2026-10-26: aus der AC-Liste genommen, damit das Gate nicht an Unbeweisbarem hängt). Sie bleiben Pflicht, und das Ticket bleibt bis dahin offen.

- **N-1:** Nach dem Merge läuft der Workflow `asc-beta` einmal von Hand (Matrix IOS und MAC_OS), und der Befund steht als Beleg im Ticket #705: Status je Abfrage, Gruppen, gesetzt/leer der Felder, Builds. Dort steht ausdrücklich, was Apples echte Antworten von der Analyse und vom Nachbau unterscheidet (Pfade, Attributnamen, Rolle des Schlüssels); Abweichungen gehen in die Spec von Schnitt 2. Belegt durch Ticketkommentar mit Link auf den Lauf. Der Nachbau allein belegt dies **nicht**.
- **N-2:** Der PR trägt `Refs #705`, nicht `Closes #705`; das Ticket bleibt offen bis Schnitt 2 und der Einladungstest. Belegt durch PR-Text.

## Out of Scope

- **Alle schreibenden Aufrufe** (Schnitt 2): Beschreibung, Feedback-E-Mail, Kontaktangaben setzen, Gruppe anlegen, öffentlichen Link
  einschalten, Build zuordnen, Beta-Review einreichen. Grund: Die Einreichung ist per API nicht zurückziehbar (kein DELETE), geht
  nach außen an Apple und braucht Hennings Wortlaut und seine Kontaktdaten; zuerst muss der Befund zeigen, welche Pfade und Felder
  Apple tatsächlich annimmt.
- **GitHub Pages / Veröffentlichung der Datenschutz-Adresse.** Eigener Schritt nach Hennings Freigabe des Entwurfs
  (`docs/reference/datenschutz-entwurf.md`). Die Probe meldet nur, ob `privacyPolicyUrl` gesetzt ist.
- **Jede Änderung an `testflight.yml`, `project.yml` und App-Code.** Die Upload-Pipeline darf nicht gefährdet werden; der
  Exportnachweis ist schon beantwortet.
- **Wortlaut der Beta-Beschreibung, Kontaktdaten, Feedback-E-Mail.** Kommen von Henning (Schnitt 2).
- **Alles auf Hennings Geräten.** Keine Installation, kein Start, keine Messung.

## Definition of Done

- [ ] `scripts/test_asc_beta_probe.py` war vor Skript und Workflow rot und ist danach grün (12 Tests).
- [ ] Alle vorhandenen Skripttests (`python3 scripts/test_*.py`) bleiben grün.
- [ ] Der Diff berührt nur die vier Dateien des Scopes; `testflight.yml` unverändert.
- [ ] Nach dem Merge: Handlauf `asc-beta` je Plattform, Befund als Beleg im Ticket #705 (N-1); Schnitt 2 wird auf Grundlage dieses Befunds spezifiziert.
- [ ] Ticket #705 bleibt offen (`Refs #705`).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reines Lese-Skript mit Test, Handlauf-Workflow und Doku; kippt keine ADR und ändert keine Architektur des Produkts.

## Changelog

- 2026-10-26: Initial spec created
