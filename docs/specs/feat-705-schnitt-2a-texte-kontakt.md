---
entity_id: feat-705-schnitt-2a-texte-kontakt
type: feature
created: 2026-10-27
updated: 2026-10-27
status: draft
workflow: feat-705-s2-einrichten
---

# Spec: #705 Schnitt 2a „Texte und Kontakt“: Beta-Beschreibung, Feedback-E-Mail und Review-Kontakt bei Apple setzen

## Approval

- [ ] Approved

## Purpose

Apple verlangt vor dem Beta-Review einer externen Gruppe eine Beta-App-Beschreibung, eine Feedback-E-Mail und Kontaktangaben
für den Reviewer. Der Befund aus Schnitt 1 (Lauf 40387004899, Kommentar in #705) zeigt: der Schlüssel liest alle Beta-Pfade, die
Lokalisierungen sind leer, das Review-Detail hat alle Felder leer. Schnitt 2a füllt genau diese Teile per Skript aus der CI:
`scripts/asc_beta_setup.py` legt die Sprachfassung `de-DE` an oder aktualisiert sie (Beschreibung aus
`docs/reference/beta-beschreibung.md`, Feedback-E-Mail und Kontakt aus Repo-Secrets) und setzt die vier Kontaktfelder des
Review-Details. Der Lauf ist idempotent (kein Schreibaufruf, wenn Apple schon die gewünschten Werte hat) und gibt nur
„gesetzt/leer/unverändert“ aus, nie Werte.

Das Repo `henemm/loose-ends` ist öffentlich. Eingaben eines `workflow_dispatch`-Laufs sind dort für alle sichtbar, darum
kommen Kontaktdaten **ausschließlich als Repo-Secrets** in den Lauf (`ASC_REVIEW_FIRST_NAME`, `ASC_REVIEW_LAST_NAME`,
`ASC_REVIEW_PHONE`, `ASC_REVIEW_EMAIL`; Henning hat die Werte am 2026-10-27 geliefert, Claude hat sie als Secrets gesetzt).
Die Beschreibung sehen Tester ohnehin; sie darf als Datei im Repo liegen.

Ohne Modell: reine API-Aufrufe und Vergleiche, kein Modellweg.

Schnitt 2 ist geteilt, weil beide Hälften zusammen etwa 450 Zeilen hätten (Limit ±250). **2a** (diese Spec) ist bis auf die
Kontaktfelder umkehrbar. **2b** (externe Gruppe, Builds zuordnen, Beta-Review einreichen, öffentlicher Link) ist
nicht rücknehmbar und bekommt eine eigene Spec.

## Source

- **File:** `scripts/asc_beta_setup.py` (neu)
- **Identifier:** `main(argv)`, `plan_localization(current, wanted)`, `plan_review_detail(current, wanted)`,
  `apply_plan(config, plan)`. Wiederverwendet, nicht geändert: `read_config`, `make_token`, `get_json`, `find_app_id`, `Fatal`
  aus `scripts/asc_wait_build.py`; `send_json`, `get_data` aus `scripts/asc_what_to_test.py` (dort auch das Muster „Sprachfassung
  `de-DE` anlegen, wenn sie fehlt“, `LOCALE`). Vorbild für den Test: `scripts/test_asc_beta_probe.py` (`FakeASC`).
  Analyse: `docs/context/feat-705-s2-einrichten.md`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/asc_wait_build.py` | Skript | `read_config`, `make_token`, `get_json`, `find_app_id`, `Fatal`; wird importiert, nicht geändert |
| `scripts/asc_what_to_test.py` | Skript | `send_json` (PATCH/POST mit Wiederholung bei 5xx/408/429, andere 4xx = `Fatal`), `get_data`, `LOCALE`; wird importiert, nicht geändert |
| `scripts/asc_beta_probe.py` | Skript | läuft nach dem Einrichten als Beleg; wird nicht geändert |
| `.github/workflows/asc-beta.yml` | Workflow | bekommt Eingabe `aktion` und den Schreibjob |
| Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | GitHub Secrets | bestehen; Schlüssel braucht jetzt Schreibrecht auf Beta-Ressourcen (bisher ungeprüft) |
| Secrets `ASC_REVIEW_FIRST_NAME`, `ASC_REVIEW_LAST_NAME`, `ASC_REVIEW_PHONE`, `ASC_REVIEW_EMAIL` | GitHub Secrets | am 2026-10-27 gesetzt; `ASC_REVIEW_EMAIL` ist zugleich Feedback-E-Mail |
| Repo-Variable `ASC_PRIVACY_POLICY_URL` (optional) | GitHub Variable | Datenschutz-URL; fehlt sie, wird sie nicht gesetzt |
| `docs/reference/datenschutz-entwurf.md`, #342 | Doku, Ticket | Datenschutz-URL wird dort freigegeben und veröffentlicht; 2a setzt sie nur, wenn die Variable existiert |
| #371 (Epic Einladung), #176 (Prüfliste) | Tickets | warten auf Gruppe und Link (2b); nur Bezug |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_beta_setup.py | CREATE | Sprachfassung `de-DE` und Review-Kontakt lesen, vergleichen, nur bei Abweichung schreiben; Ausgabe ohne Werte |
| scripts/test_asc_beta_setup.py | CREATE | `unittest` gegen lokalen API-Nachbau (`ASC_API_BASE`), plus Prüfung der Workflow-Datei |
| .github/workflows/asc-beta.yml | MODIFY | Eingabe `aktion` (`probe` Standard, `einrichten`), Schreibjob mit Secrets als `env`, danach Probe als Beleg |
| docs/reference/beta-beschreibung.md | CREATE | freigegebener Wortlaut der Beta-Beschreibung (nur der Text) |
| docs/reference/testflight.md | MODIFY | Prüfliste: Beschreibung, Feedback-E-Mail, Kontaktangaben mit Beleg; Abschnitt zum Handlauf `einrichten` |

### Estimated Changes
- Files: 5, kein Produktcode, kein Pfad der Geräteliste (`.github/workflows` steht nicht auf der Liste)
- LoC: ca. +230/-5 (ca. 90 `asc_beta_setup.py`, ca. 110 `test_asc_beta_setup.py`, ca. 20 `asc-beta.yml`, ca. 10 `beta-beschreibung.md`, ca. 15 `testflight.md`)
- Jede Funktion höchstens 50 Zeilen.

## Implementation Details

### 1. `scripts/asc_beta_setup.py`

Nur Standardbibliothek plus `openssl`. Aufruf ohne Argument. Umgebung: wie `asc_wait_build.py` (`ASC_KEY_ID`,
`ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_BUNDLE_ID`, `ASC_API_BASE`, `ASC_POLL_SECONDS`) plus

| Variable | Pflicht | Bedeutung |
|----------|---------|-----------|
| `ASC_REVIEW_FIRST_NAME`, `ASC_REVIEW_LAST_NAME`, `ASC_REVIEW_PHONE`, `ASC_REVIEW_EMAIL` | ja | Kontakt für Beta-Review; die E-Mail ist auch `feedbackEmail` |
| `ASC_PRIVACY_POLICY_URL` | nein | gesetzt: wird als `privacyPolicyUrl` geschrieben; leer oder fehlend: Feld wird nicht angefasst |
| `BETA_DESCRIPTION_FILE` | nein | Pfad zur Beschreibung; Standard `docs/reference/beta-beschreibung.md` (relativ zum Repo-Wurzelordner, vom Skriptort aus berechnet) |

**Ablauf (alles vor dem ersten Schreibaufruf):**

1. `read_config()`; Pflichtvariablen lesen. Leer oder fehlend: `Fatal` mit dem **Namen** der Variablen (nie dem Wert).
2. Telefon prüfen: muss mit `+` beginnen (Apple verlangt das internationale Format). Sonst `Fatal` ohne Wert
   („ASC_REVIEW_PHONE must start with +“).
3. Beschreibung aus der Datei lesen, an den Rändern bereinigen; leer oder über 4000 Zeichen: `Fatal`.
4. `find_app_id`, dann Ist-Zustand lesen (nur GET): `/v1/apps/APP/betaAppLocalizations` und `/v1/apps/APP/betaAppReviewDetail`.
5. Plan bilden (reine Funktionen, kein Netz): `plan_localization` vergleicht die Attribute der Fassung `de-DE` mit
   `description`, `feedbackEmail` (und `privacyPolicyUrl`, nur wenn gewünscht). Fehlt die Fassung: Plan = POST mit allen
   gewünschten Attributen. Unterscheidet sich ein Wert: Plan = PATCH nur mit den abweichenden Attributen. Gleich: kein Eintrag.
   `plan_review_detail` vergleicht `contactFirstName`, `contactLastName`, `contactPhone`, `contactEmail` und
   `demoAccountRequired` (soll `false` sein) auf dieselbe Weise; Plan = ein PATCH mit den abweichenden Attributen.
6. Plan ausführen (`apply_plan`) mit `send_json`: `POST /v1/betaAppLocalizations` (Beziehung `app`), `PATCH
   /v1/betaAppLocalizations/ID`, `PATCH /v1/betaAppReviewDetails/ID`. **Festlegung Idempotenz:** ein Plan ohne Abweichung
   führt zu **keinem** Schreibaufruf (weder PATCH noch POST); der zweite Lauf mit gleichen Werten sendet also nichts.
7. Hat der Ist-Zustand mehrere `de-DE`-Fassungen oder kein Review-Detail, bricht das Skript mit `Fatal` ab (Befund, nicht raten).

**Ausgabe** (feste Zeilen, nur Zustandswörter): `lokalisierung locale=de-DE beschreibung=gesetzt|unverändert
feedbackEmail=gesetzt|unverändert datenschutzUrl=gesetzt|unverändert|leer`, `reviewdetail kontakt=gesetzt|unverändert
demoAccountRequired=aus`, am Ende `zusammenfassung geschrieben=<n>` (Zahl der Schreibaufrufe). „leer“ steht bei der
Datenschutz-URL nur, wenn sie weder gewünscht noch bei Apple vorhanden ist. **Nie ausgegeben:** Beschreibungstext, Vorname,
Nachname, Telefon, E-Mail, Datenschutz-URL, Schlüssel, Token, Header.

**Fehler.** `send_json` macht aus jedem 4xx ein `Fatal` mit Methode und Pfad (nie Werte). Enthält die Meldung `HTTP 403`, ersetzt
das Skript sie durch „Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen“; Exit 1 mit
`::error::`. Das ist ein Befund für den Rückfall B (Oberfläche), kein Anlass zum Umgehen. Exit 0 sonst, Exit 1 bei jedem `Fatal`.

**Kein neuer HTTP-Code:** Lesen über `get_json`/`get_data`, Schreiben über `send_json`.

### 2. `.github/workflows/asc-beta.yml`

- Eingabe `aktion` (Typ `choice`, Optionen `probe` und `einrichten`, Standard `probe`). **Keine weitere Eingabe**, keine
  Kontaktdaten als Eingabe.
- Neuer Job `setup` mit `if: ${{ inputs.aktion == 'einrichten' }}`, `runs-on: ubuntu-latest`, `timeout-minutes: 10`.
  `env` mit den Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_REVIEW_FIRST_NAME`, `ASC_REVIEW_LAST_NAME`, `ASC_REVIEW_PHONE`,
  `ASC_REVIEW_EMAIL` und `ASC_PRIVACY_POLICY_URL: ${{ vars.ASC_PRIVACY_POLICY_URL }}`. Schlüsseldatei wie im Job `probe`
  (`umask 077`, `printf` nach `$RUNNER_TEMP`, `trap rm -f`). Aufruf `python3 scripts/asc_beta_setup.py`. Kontaktwerte stehen
  nur im `env`, nie in der Befehlszeile (GitHub maskiert Secrets im Log zusätzlich).
- Der bestehende Job `probe` (Matrix `IOS`/`MAC_OS`) bekommt `needs: setup` und eine Bedingung, die ihn bei `probe` wie bisher
  und bei `einrichten` **nach** erfolgreichem `setup` laufen lässt, aber nicht, wenn `setup` fehlschlägt
  (`if: ${{ !cancelled() && (needs.setup.result == 'success' || needs.setup.result == 'skipped') }}`). So ist die Probe nach dem
  Einrichten der Beleg.
- `workflow_dispatch` bleibt der einzige Auslöser; `permissions: contents: read`; `testflight.yml` bleibt unberührt.

### 3. `docs/reference/beta-beschreibung.md`

Enthält ausschließlich den von Henning am 2026-10-27 unverändert übernommenen Wortlaut (drei Absätze, Zeilenumbrüche wie
unten), keine Überschrift und keine Metadaten, damit das Skript die Datei unverändert senden kann:

> Loose Ends nimmt auf, was dir durch den Kopf geht: tippen oder sprechen, ein Satz genügt. Die App macht daraus eine Aufgabe mit Titel, Fälligkeit und Tags. Das passiert auf dem Gerät, ohne Konto und ohne eigenen Server. Deine Aufgaben liegen in deinem privaten iCloud und sind auf iPhone, iPad, Mac und Apple Watch gleich.
>
> Was du ausprobieren kannst: Aufgaben erfassen (auch per Sprache), die Liste „Jetzt“, wiederkehrende Aufgaben, Erinnerungen zur Fälligkeit und an Orten, Teilen aus anderen Apps.
>
> Rückmeldungen gehen direkt aus TestFlight: Bildschirmfoto machen oder „Feedback senden“ antippen.

### 4. `docs/reference/testflight.md`

Im Abschnitt „Einladung: Apple-Seite (#705)“ bleiben Beta-App-Beschreibung, Feedback-E-Mail und Kontaktangaben `offen`, bis der
echte Lauf sie belegt; dann steht in der Spalte „Beleg“ der Link auf den Probe-Lauf nach `einrichten` (Zeilen
`lokalisierung … beschreibung=gesetzt feedbackEmail=gesetzt` und `reviewdetail … contactFirstName=gesetzt …`). Dazu ein Absatz
„Handlauf `einrichten` (Schnitt 2a)“: Start über Actions → **ASC Beta Probe** → `aktion=einrichten`; Kontakt nur aus Secrets
(Repo ist öffentlich); die Kontaktfelder sind nach dem ersten Setzen bei Apple nicht mehr leerbar, nur überschreibbar; 403 =
Schlüssel ohne Schreibrecht, Rückfall ist die Oberfläche; Datenschutz-URL nur, wenn die Variable `ASC_PRIVACY_POLICY_URL`
existiert (gehört zu #342). Der Satz zu Schnitt 2 wird angepasst: 2a erledigt, 2b (Gruppe, Builds, Einreichung, Link) folgt.

### 5. `scripts/test_asc_beta_setup.py`

`unittest`, nur Standardbibliothek, Aufruf `python3 scripts/test_asc_beta_setup.py`. Aufbau wie `test_asc_beta_probe.py`:
Wegwerf-Schlüssel mit `openssl`, ein `FakeASC` (lokaler `HTTPServer`) mit veränderlichem Zustand (Lokalisierungen,
Review-Detail), der **jede Anfrage mit Methode und Rumpf** merkt und PATCH/POST in den Zustand übernimmt; das Skript läuft als
Unterprozess mit `ASC_API_BASE`, `ASC_POLL_SECONDS=0` und erkennbaren Testwerten (`Maxi`, `Beispiel`, `+49 170 0000000`,
`kontakt@example.test`).

### Ehrliche Grenze des Tests

Der Nachbau prüft die Form: Welche Aufrufe in welcher Reihenfolge, nichts vor der Validierung, kein Schreiben ohne Abweichung,
nichts Persönliches in der Ausgabe. Er prüft **nicht**, ob Apple Pfade, Attributnamen, Pflichtfelder und Formate (z. B. Telefon)
so annimmt und ob der Schlüssel schreiben darf. Das zeigt erst der echte Lauf `aktion=einrichten` samt anschließender Probe.

### Alternativen, nicht gewählt

- **B: einmal in der Oberfläche (App Store Connect, per Chrome mit Hennings Anmeldung):** kein Code, aber kein wiederholbarer
  Beleg; die Texte ändern sich, und 2b braucht ohnehin ein Skript (jeder neue Build muss zugeordnet und eingereicht werden).
  **Bleibt Rückfall**, wenn der Schlüssel 403 beim Schreiben liefert.
- **C: gemischt** (Texte und Kontakt per Skript, Gruppe/Link einmal in der Oberfläche): möglich für den Link in 2b, falls die
  API ihn vor der Freigabe ablehnt. Für 2a kein Unterschied zu A.
- **Kontaktdaten als Workflow-Eingabe:** verworfen, das Repo ist öffentlich, Eingaben sind in der Laufansicht sichtbar.
- **Beschreibung als Secret:** unnötig, Tester sehen sie ohnehin; als Datei ist sie prüfbar und versioniert.

Gekippt wird keine ADR.

## Freigabe vor dem echten Lauf

Der echte Schreiblauf (`aktion=einrichten`) ist für die vier Kontaktfelder **nicht umkehrbar** (Apple erlaubt nach dem ersten
Setzen kein Leeren, nur Überschreiben). Er läuft deshalb **erst nach Hennings Freigabe dieser Spec** (Freigabe getippt, nicht
durch Hook oder Agent). Die Werte hat Henning am 2026-10-27 geliefert; Tests und Umsetzung laufen vorher ohne einen
schreibenden Aufruf gegen App Store Connect.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_beta_setup.py`. Zuerst geschrieben; ohne `scripts/asc_beta_setup.py` und die Workflow-Änderung schlagen
sie fehl.

- [ ] `test_creates_missing_localization_and_patches_review_detail`: GIVEN Nachbau ohne Lokalisierung und mit leerem Review-Detail WHEN das Skript läuft THEN Exit 0, genau ein POST auf `/v1/betaAppLocalizations` (locale `de-DE`, Beschreibung gleich dem Dateiinhalt, `feedbackEmail` gleich `ASC_REVIEW_EMAIL`, Beziehung `app`) und genau ein PATCH auf `/v1/betaAppReviewDetails/D1` mit den vier Kontaktwerten und `demoAccountRequired=false`.
- [ ] `test_patches_existing_localization_only_where_different`: GIVEN Nachbau mit `de-DE`-Fassung, deren Beschreibung abweicht und deren `feedbackEmail` schon stimmt WHEN das Skript läuft THEN ein PATCH auf `/v1/betaAppLocalizations/L1`, dessen Rumpf nur `description` enthält, und kein POST.
- [ ] `test_second_run_sends_no_write`: GIVEN Nachbau, der Schreibaufrufe in seinen Zustand übernimmt, WHEN das Skript zweimal läuft THEN der zweite Lauf sendet nur GET (kein POST, kein PATCH), Exit 0, `zusammenfassung geschrieben=0`.
- [ ] `test_unchanged_state_writes_nothing`: GIVEN Nachbau, der schon alle gewünschten Werte trägt WHEN das Skript läuft THEN keine Schreibanfrage und die Ausgabe enthält `unverändert`.
- [ ] `test_privacy_url_only_when_given`: GIVEN `ASC_PRIVACY_POLICY_URL` leer WHEN das Skript läuft THEN kein gesendeter Rumpf enthält `privacyPolicyUrl`; GIVEN die Variable gesetzt THEN der Rumpf enthält sie und die Ausgabe `datenschutzUrl=gesetzt`.
- [ ] `test_missing_secret_aborts_before_any_write`: GIVEN `ASC_REVIEW_LAST_NAME` fehlt (je Pflichtvariable geprüft) WHEN das Skript läuft THEN Exit 1 mit `::error::` und dem Variablennamen, und der Nachbau hat keine Schreibanfrage (und keine einzige Anfrage) erhalten.
- [ ] `test_phone_without_plus_aborts_before_any_write`: GIVEN `ASC_REVIEW_PHONE=0170 0000000` WHEN das Skript läuft THEN Exit 1 mit `::error::`, die Meldung enthält die Nummer nicht, keine Schreibanfrage.
- [ ] `test_forbidden_write_is_reported_clearly`: GIVEN Nachbau antwortet auf PATCH/POST mit 403 WHEN das Skript läuft THEN Exit ≠ 0, Ausgabe enthält „Schlüssel ohne Schreibrecht“.
- [ ] `test_output_has_no_values_and_no_key`: GIVEN die erkennbaren Testwerte, ein Beschreibungstext und eine Datenschutz-URL WHEN das Skript läuft THEN keiner dieser Werte, kein Schlüsseltext (`BEGIN`/`PRIVATE KEY`) und kein Token (`Bearer`, `eyJ`) steht in stdout oder stderr; stattdessen `gesetzt`/`unverändert`.
- [ ] `test_ambiguous_or_missing_state_aborts`: GIVEN Nachbau mit zwei `de-DE`-Fassungen, und GIVEN Nachbau ohne Review-Detail WHEN das Skript läuft THEN jeweils Exit 1 mit `::error::` und keine Schreibanfrage.
- [ ] `test_description_file_is_sent_verbatim`: GIVEN `docs/reference/beta-beschreibung.md` des Repos WHEN das Skript mit der echten Datei läuft THEN `description` im POST gleich dem bereinigten Dateiinhalt, und die Datei enthält die drei Absätze des Wortlauts (Anfang „Loose Ends nimmt auf“, Ende „Feedback senden“ antippen.“) und ist höchstens 4000 Zeichen lang.
- [ ] `test_workflow_file`: GIVEN `.github/workflows/asc-beta.yml` THEN es enthält `workflow_dispatch`, die Eingabe `aktion` mit `probe` und `einrichten`, kein `push:`/`schedule:`/`workflow_run:`, den Aufruf `scripts/asc_beta_setup.py`, alle sechs Secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_REVIEW_FIRST_NAME`, `ASC_REVIEW_LAST_NAME`, `ASC_REVIEW_PHONE`, `ASC_REVIEW_EMAIL`) nur unter `env:` (keine `inputs.`-Referenz auf Kontaktdaten), `umask 077` und `rm -f` für die Schlüsseldatei, `needs: setup` am Job `probe`; und `testflight.yml` enthält den Namen `asc_beta_setup` nicht.
- [ ] Regression: GIVEN der geänderte Workflow WHEN `python3 scripts/test_asc_beta_probe.py` läuft THEN bleibt `test_workflow_file` der Probe grün (Matrix, Secrets, Schlüsselentfernung unverändert).

### Echter Lauf (Beleg, nach Hennings Freigabe)

Kein Gerätetest. Zuerst `aktion=einrichten`, dann die Probe aus demselben Lauf (Matrix `IOS`/`MAC_OS`).

## Acceptance Criteria

- **AC-1:** `scripts/asc_beta_setup.py` legt die Sprachfassung `de-DE` an, wenn sie fehlt, und patcht sonst nur abweichende Attribute (`description`, `feedbackEmail`; `privacyPolicyUrl` nur wenn gewünscht); die Beschreibung stammt unverändert aus `docs/reference/beta-beschreibung.md`. Belegt durch `test_creates_missing_localization_and_patches_review_detail`, `test_patches_existing_localization_only_where_different`, `test_description_file_is_sent_verbatim`.
- **AC-2:** Das Skript setzt `contactFirstName`, `contactLastName`, `contactPhone`, `contactEmail` des Review-Details aus den Secrets und `demoAccountRequired=false`; die Feedback-E-Mail ist `ASC_REVIEW_EMAIL`. Belegt durch `test_creates_missing_localization_and_patches_review_detail`.
- **AC-3:** Idempotent: stimmen die Werte bei Apple schon, sendet das Skript keinen Schreibaufruf (weder POST noch PATCH) und meldet `geschrieben=0`; ein zweiter Lauf nach einem ersten ändert nichts. Belegt durch `test_second_run_sends_no_write`, `test_unchanged_state_writes_nothing`.
- **AC-4:** Die Datenschutz-URL wird nur gesetzt, wenn `ASC_PRIVACY_POLICY_URL` gesetzt ist; sonst enthält kein Rumpf `privacyPolicyUrl`. Belegt durch `test_privacy_url_only_when_given`.
- **AC-5:** Ein fehlendes Pflicht-Secret, ein Telefon ohne führendes `+`, mehrdeutiger oder fehlender Ist-Zustand brechen mit Exit 1 und `::error::` ab, **bevor** irgendein Schreibaufruf (bei fehlendem Secret und Telefonfehler: bevor irgendeine Anfrage) gesendet wird; die Meldung nennt den Variablennamen, nie einen Wert. Belegt durch `test_missing_secret_aborts_before_any_write`, `test_phone_without_plus_aborts_before_any_write`, `test_ambiguous_or_missing_state_aborts`.
- **AC-6:** Antwortet Apple auf einen Schreibaufruf mit 403, endet das Skript mit Exit ≠ 0 und der Meldung „Schlüssel ohne Schreibrecht“. Belegt durch `test_forbidden_write_is_reported_clearly`.
- **AC-7:** Die Ausgabe enthält nur „gesetzt/leer/unverändert“, nie Beschreibung, Kontaktwerte, Feedback-E-Mail, Datenschutz-URL, Schlüssel oder Token (stdout und stderr). Belegt durch `test_output_has_no_values_and_no_key`.
- **AC-8:** `.github/workflows/asc-beta.yml` hat die Eingabe `aktion` (`probe` Standard, `einrichten`), reicht Kontaktdaten ausschließlich als Secrets im `env` an den Schreibjob (keine Eingabe dafür), lässt die Probe nach erfolgreichem Einrichten als Beleg laufen und entfernt die Schlüsseldatei; `testflight.yml` ist unverändert. Belegt durch `test_workflow_file`, die Regression der Probe-Tests und `git diff --stat` (`testflight.yml` nicht im Diff).
- **AC-9:** `docs/reference/beta-beschreibung.md` enthält den freigegebenen Wortlaut und `docs/reference/testflight.md` beschreibt den Handlauf `einrichten` samt Unumkehrbarkeit der Kontaktfelder und 403-Rückfall. Belegt durch `test_description_file_is_sent_verbatim` und Diff (`grep -n "einrichten" docs/reference/testflight.md` mindestens ein Treffer).
- **AC-10:** Der Diff berührt genau die fünf Dateien des Scopes, kein `project.yml`, kein App-Code, kein `testflight.yml`, kein Pfad der Geräteliste, höchstens ±250 LoC, jede Funktion ≤ 50 Zeilen. Belegt durch `git diff --stat` im Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“
- **AC-11:** Alle Skripttests (`python3 scripts/test_*.py`) sind grün und liefen vor Skript und Workflow-Änderung rot (TDD RED). Belegt durch die Testausgabe im Abschlussbericht.
- **AC-12:** Der echte Lauf `aktion=einrichten` läuft erst nach Hennings getippter Freigabe dieser Spec; danach zeigt die Probe desselben Laufs `lokalisierung locale=de-DE beschreibung=gesetzt feedbackEmail=gesetzt` und im `reviewdetail` die vier Kontaktfelder `gesetzt`; die Prüfliste in `testflight.md` verweist auf diesen Lauf. Belegt durch Lauf-Link im Ticket #705 und die ausgefüllte Spalte „Beleg“. Vor der Freigabe läuft kein schreibender Aufruf gegen App Store Connect und nichts auf Hennings Geräten.

Kein Pfad der Geräteliste berührt (kein App-Code; `.github/workflows` steht nicht auf der Liste). Abnahmestufe: Skripttests plus
echter CI-Lauf, kein Simulator- oder Geräteschritt.

## Out of Scope (Schnitt 2b und andere)

- **Externe Gruppe anlegen** (z. B. „Tester“, `feedbackEnabled`), **neuesten `VALID`-Build je Plattform zuordnen**,
  **Beta-Review einreichen** (nicht rücknehmbar, Schalter `submit` standardmäßig aus), **öffentlichen Link einschalten**
  (Limit 50, erst nach Freigabe). Alles 2b, eigene Spec, auch das Ziel „eine Person außer Henning installiert über den Link“.
- **Veröffentlichung der Datenschutz-Adresse** (z. B. GitHub Pages) und die Freigabe des Entwurfs: #342. 2a setzt die URL nur,
  wenn die Variable existiert. Ob Apple sie für TestFlight verlangt, ist ungeklärt und zeigt sich erst bei der Einreichung (2b).
- **Demo-Zugang und Notizen** im Review-Detail (`demoAccountName`, `demoAccountPassword`, `notes`): die App braucht kein Konto.
- **Mehrere Sprachen** der Beschreibung: nur `de-DE`.
- **Jede Änderung an `testflight.yml`, `project.yml`, App-Code und an `asc_beta_probe.py`.**
- **Alles auf Hennings Geräten.**

## Definition of Done

- [ ] `scripts/test_asc_beta_setup.py` war vor Skript und Workflow rot und ist danach grün; alle übrigen `scripts/test_*.py` bleiben grün.
- [ ] Der Diff berührt nur die fünf Dateien des Scopes; `testflight.yml` unverändert.
- [ ] Nach Hennings Freigabe: Lauf `aktion=einrichten`, danach Probe zeigt Beschreibung, Feedback-E-Mail und Kontakt `gesetzt`; Lauf-Link im Ticket #705 und in der Prüfliste.
- [ ] Zweiter Lauf `einrichten` meldet `geschrieben=0` (Idempotenz am echten Apple belegt).
- [ ] Ticket #705 bleibt offen (`Refs #705`, nicht `Closes`), bis 2b und der Einladungstest erledigt sind.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Skript mit Test, Handlauf-Workflow und Doku im bestehenden Muster von Schnitt 1 und #347; kippt keine ADR und ändert nichts an der Produktarchitektur.

## Changelog

- 2026-10-27: Initial spec created
