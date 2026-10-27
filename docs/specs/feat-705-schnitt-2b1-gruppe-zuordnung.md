---
entity_id: feat-705-schnitt-2b1-gruppe-zuordnung
type: feature
created: 2026-10-27
updated: 2026-10-27
status: draft
workflow: feat-705-s2b-einladung
---

# Spec: #705 Schnitt 2b-1 „Gruppe und Zuordnung“: externe TestFlight-Gruppe anlegen und den neuesten gültigen Build je Plattform zuordnen

## Approval

- [ ] Approved

## Purpose

Für die erste externe Einladung braucht Apple eine externe Testgruppe, in der ein Build liegt. Nach Schnitt 1 (nur Gruppe
`Familie`, intern) und Schnitt 2a (Beschreibung, Feedback-E-Mail, Review-Kontakt, PR #716, Läufe 40466472742 und
40466601395) fehlt genau das. Schnitt 2b-1 legt per Skript aus der CI die externe Gruppe `Tester` an (Feedback an,
öffentlicher Link **aus**) und ordnet ihr je Plattform (`IOS`, `MAC_OS`) den neuesten gültigen Build zu. Der Name ist für
Tester nicht sichtbar. Der Lauf ist idempotent (zweiter Lauf `geschrieben=0`) und gibt nur Zustandswörter aus.

**Was 2b-1 bewusst nicht tut:** keine Einreichung zum Beta-Review (`betaAppReviewSubmissions`), kein öffentlicher Link
(`publicLinkEnabled` bleibt `false`, kein Link-Limit gesetzt). Beides ist nicht rücknehmbar bzw. öffentlich und gehört in
Schnitt 2b-2. Die Zuordnung dagegen ist umkehrbar und löst keinen Review aus: Per API bleibt der Build nach der Zuordnung auf
`READY_FOR_BETA_SUBMISSION`, erst die Einreichung schickt ihn in den Review (Apple-Forum 693864; Apples Oberfläche fügt den
Build ebenfalls erst der Gruppe hinzu, dann „Submit Review“). Die Probe nach dem Lauf zeigt, was Apple aus der Zuordnung
macht, bevor 2b-2 das Unumkehrbare tut.

Ohne Modell: reine API-Aufrufe und Vergleiche, kein Modellweg.

Das Repo `henemm/loose-ends` ist öffentlich. Der Workflow bekommt deshalb keine neue Eingabe außer der Auswahl `zuordnen`;
der Gruppenname ist eine Konstante im Skript, kein Secret.

## Source

- **File:** `scripts/asc_beta_invite.py` (neu)
- **Identifier:** `main(argv)`, `plan_group(groups)`, `plan_assignment(build_id, build_groups, group_id)`,
  `apply_plan(config, plan)`. Wiederverwendet, nicht geändert: `read_config`, `get_json`, `find_app_id`, `platform_filter`,
  `Fatal` aus `scripts/asc_wait_build.py`; `send_json`, `get_data` aus `scripts/asc_what_to_test.py`. Vorbild für Aufbau und
  Test: `scripts/asc_beta_setup.py`, `scripts/test_asc_beta_setup.py` (`FakeASC`).
  Analyse: `docs/context/feat-705-s2b-einladung.md`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/asc_wait_build.py` | Skript | `read_config`, `get_json`, `find_app_id`, `platform_filter`, `Fatal`; wird importiert, nicht geändert |
| `scripts/asc_what_to_test.py` | Skript | `send_json` (POST mit Wiederholung bei 5xx/408/429, andere 4xx = `Fatal` mit Methode und Pfad), `get_data`; wird importiert, nicht geändert |
| `scripts/asc_beta_probe.py` | Skript | läuft nach dem Zuordnen als Beleg (`gruppe …`, `build … extern=…`); wird nicht geändert |
| `scripts/asc_beta_setup.py` | Skript | Vorbild (Prüfen vor Schreiben, reine `plan_*`, 403-Meldung); wird nicht geändert |
| `.github/workflows/asc-beta.yml` | Workflow | bekommt die Wahl `zuordnen` und den Job `assign` |
| Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` | GitHub Secrets | bestehen; Schreibrecht auf Beta-Ressourcen ist seit 2a belegt (kein 403) |
| Interne Gruppe `Familie` | Apple-Zustand | Voraussetzung einer externen Gruppe; besteht laut Schnitt 1 |
| `docs/reference/testflight.md` | Doku | Prüfliste „Einladung: Apple-Seite (#705)“ |
| #371 (Epic Einladung), #176 (Prüfliste) | Tickets | warten auf Gruppe und Link; nur Bezug |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_beta_invite.py | CREATE | externe Gruppe `Tester` anlegen falls fehlt; je Plattform neuesten gültigen Build suchen und zuordnen falls noch nicht geschehen; Ausgabe nur Zustandswörter |
| scripts/test_asc_beta_invite.py | CREATE | `unittest` gegen lokalen API-Nachbau (`ASC_API_BASE`), plus Prüfung der Workflow-Datei |
| .github/workflows/asc-beta.yml | MODIFY | Wahl `zuordnen` (Standard bleibt `probe`), Job `assign` vor der Probe, Probe als Beleg |
| docs/reference/testflight.md | MODIFY | Prüfliste: externe Gruppe, Zuordnung iOS/macOS, Exportnachweis mit Beleg; Absatz „Handlauf `zuordnen` (Schnitt 2b-1)“; Hinweis auf 2b-2 |

### Estimated Changes
- Files: 4, kein Produktcode, kein Pfad der Geräteliste (`scripts/`, `.github/workflows`, `docs/` stehen nicht auf der Liste)
- LoC: ca. +230 (ca. 100 `asc_beta_invite.py`, ca. 100 `test_asc_beta_invite.py`, ca. 15 `asc-beta.yml`, ca. 15 `testflight.md`)
- Jede Funktion höchstens 50 Zeilen.

## Implementation Details

### 1. `scripts/asc_beta_invite.py`

Nur Standardbibliothek plus `openssl` (über `make_token`). Aufruf ohne Argument. Umgebung wie `asc_wait_build.py`
(`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILE`, `ASC_BUNDLE_ID`, `ASC_API_BASE`, `ASC_POLL_SECONDS`). `ASC_PLATFORM` wird
nicht gelesen: das Skript geht die Plattformen `IOS` und `MAC_OS` selbst nacheinander durch (für `platform_filter` mit einer
Kopie der Konfiguration, in der `platform` gesetzt ist). Konstanten: `GROUP_NAME = "Tester"`, `PLATFORMS = ("IOS", "MAC_OS")`.

**Ablauf:**

1. `read_config()`, `find_app_id`. Es gibt keine Pflicht-Secrets außer den Schlüsseldaten; alles Weitere ist Konstante.
2. **Gruppe lesen** (nur GET): `get_data(config, "/v1/apps/APP/betaGroups")`. `plan_group(groups)` (rein, kein Netz) wählt unter
   den Gruppen mit `isInternalGroup=false` und `name == "Tester"`: genau eine = `("vorhanden", id)`; keine = `("anlegen",)`;
   mehr als eine = `Fatal` („App Store Connect has N external beta groups named Tester“) **vor jedem Schreibaufruf**, es wird
   nicht geraten. Interne Gruppen gleichen Namens zählen nicht.
3. **Gruppe anlegen**, falls geplant: `POST /v1/betaGroups` mit Attributen `name="Tester"`, `isInternalGroup=false`,
   `feedbackEnabled=true`, `publicLinkEnabled=false` und Beziehung `app`. **Nie** `publicLinkEnabled=true`, nie
   `publicLinkLimit`/`publicLinkLimitEnabled` (Link und Limit 50 gehören zu 2b-2). Die Antwort liefert die Gruppen-ID für die
   Zuordnung. Lag die Gruppe schon vor, wird nichts an ihr geändert (kein PATCH, auch wenn Apple dort einen Link eingeschaltet
   hätte; das meldet die Probe).
4. **Je Plattform nacheinander** (`for platform in PLATFORMS`, jede Plattform in eigenem `try`):
   a. Neuesten gültigen Build suchen: `GET /v1/builds?filter[app]=APP&filter[processingState]=VALID&filter[expired]=false&sort=-uploadedDate&limit=1`
      plus `platform_filter`. Kein Treffer: Zustandswort `zuordnung plattform=P zustand=kein-gültiger-build`, kein Schreiben,
      **kein Fehler** (eine Plattform ohne gültigen Build ist ein Befund, kein Abbruch); der Lauf geht zur nächsten Plattform.
   b. `GET /v1/betaGroups/GROUP/relationships/builds?limit=200` (Build-IDs der Gruppe; `GET /v1/builds/ID/betaGroups` gibt
      es bei Apple nicht, Antwort 403). `plan_assignment(build_id, assigned_ids, group_id)` (rein): liegt der Build schon in
      der Gruppe, ist der Plan leer; ein Lesefehler gilt als Fehler dieser Plattform (Schritt 5); sonst `POST /v1/betaGroups/GROUP/relationships/builds` mit `{"data":[{"type":"builds","id":ID}]}`.
      Wurde die Gruppe in diesem Lauf eben angelegt, ist die Liste leer und die Zuordnung folgt.
   c. Nach der Zuordnung `GET /v1/builds/ID/buildBetaDetail` und das Zustandswort `externalBuildState` ausgeben.
5. **Fehler einer Plattform verdeckt die andere nicht:** ein `Fatal` in Schritt 4 wird mit Plattform gemeldet
   (`::error::platform=P …`), gemerkt, und die nächste Plattform läuft trotzdem. Am Ende `Exit 1`, wenn irgendein Fehler
   aufgetreten ist; die Zusammenfassung wird dennoch gedruckt. Ein `Fatal` in Schritt 1 bis 3 (Gruppe) bricht ab, weil ohne
   Gruppe keine Zuordnung möglich ist; es folgt Exit 1 ohne Zuordnungsversuch.
6. **Idempotenz:** ein Plan ohne Abweichung führt zu **keinem** Schreibaufruf. Zweiter Lauf: Gruppe `vorhanden`, Zuordnung
   `vorhanden`, `zusammenfassung geschrieben=0`.

**Ausgabe** (feste Zeilen, nur Zustandswörter): `gruppe name=Tester zustand=angelegt|vorhanden`,
`zuordnung plattform=IOS|MAC_OS zustand=gesetzt|vorhanden|kein-gültiger-build extern=<externalBuildState>` (`extern=` nur, wenn
ein Build da ist), am Ende `zusammenfassung geschrieben=<n>` (Zahl der Schreibaufrufe). Gedruckt werden nur Namen und
Zustandswörter, die auch die Probe druckt (`name=`, `extern=`); **nie** Gruppen-ID, Build-ID, Buildnummer, Link-URL,
Schlüssel, Token, Header.

**Fehler.** `send_json` macht aus jedem 4xx ein `Fatal` mit Methode und Pfad (nie Werte). Enthält die Meldung `HTTP 403`, ersetzt
das Skript sie durch „Schlüssel ohne Schreibrecht: Rolle des API-Schlüssels in App Store Connect prüfen“ (Wortlaut wie in
`asc_beta_setup.py`); Exit 1 mit `::error::`. Das ist ein Befund für den Rückfall B (Oberfläche), kein Anlass zum Umgehen.
Eine 422-Antwort (z. B. `BETA_CONTRACT_MISSING`, Kontoseite) wird als `Fatal` mit Methode und Pfad gemeldet, nicht
umgangen. Exit 0 sonst.

**Kein neuer HTTP-Code:** Lesen über `get_json`/`get_data`, Schreiben über `send_json`. **Nie gesendet:** jeder Pfad
`betaAppReviewSubmissions`, jedes `publicLinkEnabled=true`, jedes DELETE.

### 2. `.github/workflows/asc-beta.yml`

- Die Eingabe `aktion` bekommt die dritte Option `zuordnen` (Optionen `probe`, `einrichten`, `zuordnen`; Standard bleibt `probe`).
  **Keine weitere Eingabe.** Der Kopfkommentar nennt `zuordnen` (Schnitt 2b-1).
- Neuer Job `assign` mit `if: ${{ inputs.aktion == 'zuordnen' }}`, `runs-on: ubuntu-latest`, `timeout-minutes: 10`; `env` mit
  `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_POLL_SECONDS: "5"`. Schlüsseldatei wie in den anderen Jobs (`umask 077`, `printf` nach
  `$RUNNER_TEMP`, `trap rm -f`). Aufruf `python3 scripts/asc_beta_invite.py`.
- Der Job `probe` bekommt `needs: [setup, assign]` und die Bedingung
  `!cancelled() && (needs.setup.result == 'success' || needs.setup.result == 'skipped') && (needs.assign.result == 'success' || needs.assign.result == 'skipped')`.
  Bei `probe` und `einrichten` läuft er wie bisher, bei `zuordnen` nach erfolgreichem `assign` als Beleg; schlägt `assign`
  fehl, läuft die Probe nicht (der Fehler steht dann allein im Log).
- `workflow_dispatch` bleibt der einzige Auslöser; `permissions: contents: read`; `testflight.yml` bleibt unberührt.

### 3. `docs/reference/testflight.md`

In der Prüfliste „Einladung: Apple-Seite (#705)“: Zeile „Exportnachweis“ bekommt als zusätzlichen Beleg den Probe-Befund
(`extern=READY_FOR_BETA_SUBMISSION`, nicht `MISSING_EXPORT_COMPLIANCE`, Lauf 40387004899); „Interne Gruppe `Familie`“ verweist auf
denselben Lauf; „Externe Gruppe mit öffentlichem Link“ wird in „Externe Gruppe `Tester`“ (Zeile bleibt `offen`/`erledigt` je nach
Lauf, Beleg = Lauf-Link `gruppe name=Tester`) und „Öffentlicher Link“ (`offen`, 2b-2) geteilt; „Build-Zuordnung iOS und macOS“
erhält den Lauf-Link, sobald der echte Lauf stattfand. Dazu ein Absatz „Handlauf `zuordnen` (Schnitt 2b-1)“: Start über Actions
→ **ASC Beta Probe** → `aktion=zuordnen`; legt die externe Gruppe `Tester` an (Link aus) und ordnet den neuesten `VALID`-Build
je Plattform zu; reicht **nichts** zum Review ein und schaltet **keinen** Link ein; die Zuordnung ist umkehrbar; jeder spätere
Build braucht wieder einen Lauf (Automatisierung als Folgeticket an `testflight.yml`); 403 = Schlüssel ohne Schreibrecht,
Rückfall ist die Oberfläche. Der Satz zu Schnitt 2 nennt 2b-1 erledigt und 2b-2 (Einreichung, Link) als nächsten Schnitt.

### 4. `scripts/test_asc_beta_invite.py`

`unittest`, nur Standardbibliothek, Aufruf `python3 scripts/test_asc_beta_invite.py`. Aufbau wie `test_asc_beta_setup.py`:
Wegwerf-Schlüssel mit `openssl`, ein `FakeASC` (lokaler `HTTPServer`) mit veränderlichem Zustand (Gruppen, Builds je
Plattform, Zuordnungen, `externalBuildState`), der **jede Anfrage mit Methode, Pfad und Rumpf** merkt und POSTs in den Zustand
übernimmt; das Skript läuft als Unterprozess mit `ASC_API_BASE` und `ASC_POLL_SECONDS=0`.

### Ehrliche Grenze des Tests

Der Nachbau prüft die Form: welche Aufrufe in welcher Reihenfolge, nichts vor der Gruppenprüfung, kein Schreiben ohne
Abweichung, nie Einreichung oder Link, nichts Verbotenes in der Ausgabe. Er prüft **nicht**, ob Apple Pfade, Attributnamen und
die Beziehung `builds` so annimmt, ob die Filter `processingState`/`expired` und die Sortierung `-uploadedDate` auf `/v1/builds`
gelten, ob der Schlüssel schreiben darf und was Apple aus der Zuordnung macht (Status, Exportprüfung). Das zeigt erst der echte
Lauf `aktion=zuordnen` samt Probe.

### Alternativen

- **A: Skript aus der CI (gewählt, Empfehlung):** wiederholbar, belegt, Grundlage für die Zuordnung jedes späteren Builds.
  Nachteil: Apples Verhalten wird erst im echten Lauf sichtbar; deshalb der Schnitt in 2b-1 und 2b-2.
- **B: einmal in der App-Store-Connect-Oberfläche** (per Chrome mit Hennings Anmeldung): schnell, kein Code, aber nicht
  wiederholbar; jeder neue Build müsste wieder per Hand zugeordnet werden. **Bleibt Notausgang**, falls die API eine Hürde
  setzt (403, 422), und ist für 2b-2 der Rückfall, falls Apple die Einreichung an die Oberfläche bindet.
- **C: gemischt** (Gruppe und Link einmal per Klick, Zuordnung und Einreichung je Build per Skript): wenig Code für das
  Einmalige, aber Zustand teils unversioniert; die Gruppe ist im Skript billig. Für 2b-1 kein Vorteil gegenüber A.

Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_beta_invite.py`. Zuerst geschrieben; ohne `scripts/asc_beta_invite.py` und die Workflow-Änderung
schlagen sie fehl.

- [ ] `test_first_run_creates_group_and_assigns_both_platforms`: GIVEN Nachbau ohne externe Gruppe und je Plattform einem gültigen Build WHEN das Skript läuft THEN Exit 0, genau ein POST auf `/v1/betaGroups` (`name=Tester`, `isInternalGroup=false`, `feedbackEnabled=true`, `publicLinkEnabled=false`, Beziehung `app`) und je Plattform genau ein POST auf `/v1/betaGroups/G1/relationships/builds` mit der Build-ID der Plattform; Ausgabe enthält `gruppe name=Tester zustand=angelegt` und `zustand=gesetzt` für `IOS` und `MAC_OS`.
- [ ] `test_second_run_sends_no_write`: GIVEN Nachbau, der Schreibaufrufe in seinen Zustand übernimmt, WHEN das Skript zweimal läuft THEN der zweite Lauf sendet nur GET, Exit 0, Ausgabe `gruppe name=Tester zustand=vorhanden`, `zustand=vorhanden` je Plattform und `zusammenfassung geschrieben=0`.
- [ ] `test_existing_group_only_assigns_missing_build`: GIVEN Nachbau mit externer Gruppe `Tester`, in der nur der iOS-Build liegt WHEN das Skript läuft THEN kein POST auf `/v1/betaGroups`, genau ein POST auf `relationships/builds` (macOS-Build), `geschrieben=1`.
- [ ] `test_newest_valid_build_is_chosen_per_platform`: GIVEN Nachbau, der `/v1/builds` nur mit den Filtern `filter[processingState]=VALID`, `filter[expired]=false`, `sort=-uploadedDate`, `limit=1` und `filter[preReleaseVersion.platform]=IOS`/`MAC_OS` beantwortet WHEN das Skript läuft THEN je Plattform eine Abfrage mit genau diesen Parametern und es wird der Build zugeordnet, den der Nachbau dafür liefert.
- [ ] `test_platform_without_valid_build_is_reported_not_failed`: GIVEN Nachbau, der für `MAC_OS` keinen gültigen Build liefert WHEN das Skript läuft THEN Exit 0, Ausgabe `zuordnung plattform=MAC_OS zustand=kein-gültiger-build`, die iOS-Zuordnung ist trotzdem geschrieben, kein Schreibaufruf für macOS.
- [ ] `test_one_platform_failing_does_not_hide_the_other`: GIVEN Nachbau, bei dem der POST der Zuordnung für `IOS` mit 422 antwortet WHEN das Skript läuft THEN Exit 1, Ausgabe enthält `::error::` mit `platform=IOS`, die macOS-Zuordnung wurde dennoch gesendet, und `zusammenfassung` steht am Ende.
- [ ] `test_never_submits_and_never_enables_link`: GIVEN die Läufe aller übrigen Szenarien (Erstlauf, Zweitlauf, vorhandene Gruppe, Fehler) WHEN die vom Nachbau gemerkten Anfragen geprüft werden THEN keine Anfrage an einen Pfad mit `betaAppReviewSubmissions`, kein gesendeter Rumpf mit `"publicLinkEnabled": true`, `publicLinkLimit` oder `publicLinkLimitEnabled`, kein DELETE und kein PATCH.
- [ ] `test_duplicate_external_groups_abort_before_any_write`: GIVEN Nachbau mit zwei externen Gruppen namens `Tester` WHEN das Skript läuft THEN Exit 1 mit `::error::`, und der Nachbau hat keine Schreibanfrage erhalten; eine **interne** Gruppe namens `Tester` neben genau einer externen löst dagegen keinen Fehler aus.
- [ ] `test_forbidden_write_is_reported_clearly`: GIVEN Nachbau antwortet auf POST mit 403 WHEN das Skript läuft THEN Exit ≠ 0, Ausgabe enthält „Schlüssel ohne Schreibrecht“.
- [ ] `test_output_has_only_state_words`: GIVEN Nachbau mit erkennbaren Kennungen (Gruppen-ID, Build-IDs, Buildnummern, Link-URL, Schlüsseltext) WHEN das Skript läuft THEN keine dieser Kennungen, kein `BEGIN`/`PRIVATE KEY`, kein `Bearer`/`eyJ` in stdout oder stderr; erlaubt sind `name=Tester`, `plattform=`, `zustand=`, `extern=`, `geschrieben=`.
- [ ] `test_workflow_file`: GIVEN `.github/workflows/asc-beta.yml` THEN es enthält `workflow_dispatch`, die Eingabe `aktion` mit `probe`, `einrichten` und `zuordnen` (Standard `probe`), kein `push:`/`schedule:`/`workflow_run:`, den Job `assign` mit Aufruf `scripts/asc_beta_invite.py`, `umask 077` und `rm -f` für die Schlüsseldatei, `needs:` am Job `probe` mit `setup` und `assign`, und es enthält weder `betaAppReviewSubmissions` noch `publicLinkEnabled`; `testflight.yml` enthält den Namen `asc_beta_invite` nicht.
- [ ] Regression: GIVEN der geänderte Workflow WHEN `python3 scripts/test_asc_beta_probe.py` und `python3 scripts/test_asc_beta_setup.py` laufen THEN bleiben beide grün, insbesondere ihre `test_workflow_file`.

### Echter Lauf (Beleg, nach dem Merge)

Kein Gerätetest. Handlauf `aktion=zuordnen` auf `main`, danach die Probe aus demselben Lauf (Matrix `IOS`/`MAC_OS`), dann ein
zweiter Lauf `aktion=zuordnen` (Idempotenz). Was die Probe nach dem Lauf zeigt (`gruppe name=Tester … link=aus`,
`build … extern=…`, `einreichung` leer), steht als Kommentar in #705 und bestimmt die Einzelheiten von 2b-2.

## Acceptance Criteria

- **AC-1:** `scripts/asc_beta_invite.py` legt die externe Gruppe `Tester` an, wenn sie fehlt (`isInternalGroup=false`, `feedbackEnabled=true`, `publicLinkEnabled=false`, Beziehung `app`), und ordnet je Plattform `IOS` und `MAC_OS` den Build zu. Belegt durch `test_first_run_creates_group_and_assigns_both_platforms`.
- **AC-2:** Als Build gilt je Plattform der neueste mit `processingState=VALID` und `expired=false` (`sort=-uploadedDate`, `limit=1`, Plattformfilter); ist er der Gruppe schon zugeordnet, wird nur der fehlende zugeordnet. Belegt durch `test_newest_valid_build_is_chosen_per_platform`, `test_existing_group_only_assigns_missing_build`.
- **AC-3:** Das Skript sendet nie eine Einreichung (`betaAppReviewSubmissions`), nie `publicLinkEnabled=true`, nie ein Link-Limit, nie DELETE oder PATCH; der Workflow nennt beides ebenfalls nicht. Belegt durch `test_never_submits_and_never_enables_link`, `test_workflow_file`; im echten Lauf zeigt die Probe `einreichung` leer und `link=aus` für `Tester`.
- **AC-4:** Idempotent: stimmen Gruppe und Zuordnung bei Apple schon, sendet das Skript keinen Schreibaufruf und meldet `zusammenfassung geschrieben=0`; ein zweiter Lauf nach einem ersten ändert nichts. Belegt durch `test_second_run_sends_no_write`; am echten Apple durch den zweiten Handlauf `aktion=zuordnen` mit `geschrieben=0`.
- **AC-5:** Ein Fehler bei einer Plattform verdeckt die andere nicht: die andere Plattform wird trotzdem bearbeitet, die Zusammenfassung wird gedruckt, der Lauf endet mit Exit 1 und einer Meldung mit Plattform. Belegt durch `test_one_platform_failing_does_not_hide_the_other`.
- **AC-6:** Hat eine Plattform keinen gültigen Build, meldet das Skript `kein-gültiger-build`, schreibt dafür nichts und endet nicht allein deshalb mit Fehler. Belegt durch `test_platform_without_valid_build_is_reported_not_failed`.
- **AC-7:** Antwortet Apple auf einen Schreibaufruf mit 403, endet das Skript mit Exit ≠ 0 und der Meldung „Schlüssel ohne Schreibrecht“. Belegt durch `test_forbidden_write_is_reported_clearly`.
- **AC-8:** Gibt es zwei externe Gruppen namens `Tester`, bricht das Skript mit Exit 1 und `::error::` ab, bevor irgendein Schreibaufruf gesendet wird; eine interne Gruppe gleichen Namens zählt nicht. Belegt durch `test_duplicate_external_groups_abort_before_any_write`.
- **AC-9:** Die Ausgabe enthält nur Zustandswörter und `name=Tester`, `plattform=`, `extern=` (Felder, die auch die Probe druckt), nie Gruppen- oder Build-IDs, Buildnummern, Link-URL, Schlüssel oder Token (stdout und stderr). Belegt durch `test_output_has_only_state_words`.
- **AC-10:** `.github/workflows/asc-beta.yml` hat die Wahl `zuordnen` (Standard bleibt `probe`), den Job `assign` ohne zusätzliche Eingabe, entfernt die Schlüsseldatei und lässt die Probe nach erfolgreichem `assign` als Beleg laufen; `testflight.yml` ist unverändert, die Tests von Probe und 2a bleiben grün. Belegt durch `test_workflow_file`, die Regression und `git diff --stat` (`testflight.yml` nicht im Diff).
- **AC-11:** `docs/reference/testflight.md` beschreibt den Handlauf `zuordnen` (kein Review, kein Link, umkehrbar, 403-Rückfall, spätere Builds brauchen einen neuen Lauf) und führt externe Gruppe, Zuordnung und Exportnachweis mit Beleg. Belegt durch Diff (`grep -n "zuordnen" docs/reference/testflight.md` mindestens ein Treffer).
- **AC-12:** Der Diff berührt genau die vier Dateien des Scopes, kein `project.yml`, kein App-Code, kein `testflight.yml`, keine Änderung an `asc_beta_probe.py`, `asc_wait_build.py`, `asc_what_to_test.py`, kein Pfad der Geräteliste, höchstens ±250 LoC, jede Funktion ≤ 50 Zeilen. Belegt durch `git diff --stat` im Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“
- **AC-13:** Alle Skripttests (`python3 scripts/test_*.py`) sind grün und liefen vor Skript und Workflow-Änderung rot (TDD RED). Belegt durch die Testausgabe im Abschlussbericht.
- **AC-14:** Echter Lauf nach dem Merge: `aktion=zuordnen` auf `main`, danach zeigt die Probe desselben Laufs `gruppe name=Tester intern=nein link=aus` und je Plattform eine `build …`-Zeile, und das Skript meldet je Plattform `zustand=gesetzt` (ein zweiter Lauf `zustand=vorhanden`, `geschrieben=0`; die Probe selbst druckt keine Gruppenzuordnung); der Lauf-Link und der beobachtete Build-Zustand (`extern=…`) stehen in #705 und in der Prüfliste. Belegt durch Lauf-Link im Ticket #705 und die ausgefüllte Spalte „Beleg“. Vorher läuft kein schreibender Aufruf gegen App Store Connect und nichts auf Hennings Geräten.

Kein Pfad der Geräteliste berührt (kein App-Code; `scripts/`, `.github/workflows` und `docs/` stehen nicht auf der Liste).
Abnahmestufe: Skripttests plus echter CI-Lauf, kein Simulator- oder Geräteschritt.

## Out of Scope (Schnitt 2b-2 und andere)

- **Beta-Review einreichen** (`POST /v1/betaAppReviewSubmissions`, nicht rücknehmbar, eigene Aktion, nur nach Hennings Freigabe)
  und **öffentlichen Link einschalten** (Limit 50, erst nach Freigabe eines Builds, sonst Zustandswort `link=wartet`): Schnitt
  2b-2, eigener Workflow und eigene Spec. Dort entscheidet sich auch, ob Apple die Datenschutz-URL bei der Einreichung verlangt.
- **Datenschutz-URL** und die Veröffentlichung der Datenschutzseite: #342 (Board „In progress“, nicht anfassen).
- **Zuordnung späterer Builds automatisch in `testflight.yml`:** eigenes Folgeticket, nach 2b anzulegen.
- **Änderungen an `asc_beta_probe.py`, `asc_wait_build.py`, `asc_what_to_test.py`, `asc_beta_setup.py`, `testflight.yml`,
  `project.yml` und App-Code.**
- **Einzelne Tester einladen, Gruppe löschen oder umbenennen, Zuordnung entfernen.**
- **Ziel „eine Person außer Henning installiert über den Link“:** erst nach 2b-2.
- **Alles auf Hennings Geräten.**

## Definition of Done

- [ ] `scripts/test_asc_beta_invite.py` war vor Skript und Workflow rot und ist danach grün; alle übrigen `scripts/test_*.py` bleiben grün.
- [ ] Der Diff berührt nur die vier Dateien des Scopes; `testflight.yml` und die bestehenden Skripte unverändert.
- [ ] Nach dem Merge: Handlauf `aktion=zuordnen`, danach Probe zeigt Gruppe `Tester` (Link aus) und je Plattform einen zugeordneten Build; Lauf-Link in #705 und in der Prüfliste.
- [ ] Zweiter Lauf `zuordnen` meldet `geschrieben=0` (Idempotenz am echten Apple belegt).
- [ ] Folgerungen für 2b-2 (Build-Zustand nach Zuordnung, Exportstatus) als Kommentar in #705; Folgeticket „spätere Builds zuordnen in `testflight.yml`“ angelegt.
- [ ] Ticket #705 bleibt offen (`Refs #705`, nicht `Closes`), bis 2b-2 und der Einladungstest erledigt sind.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Skript mit Test, Handlauf-Workflow und Doku im bestehenden Muster von Schnitt 1, 2a und #347; kippt keine ADR und ändert nichts an der Produktarchitektur.

## Changelog

- 2026-10-27: Initial spec created
- 2026-10-27: Zuordnung über GET /v1/betaGroups/{id}/relationships/builds, weil Apple GET /v1/builds/{id}/betaGroups mit 403 ablehnt (Lauf 40516649071, Apple-Doku Builds/Beta Groups)
