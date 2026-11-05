---
entity_id: feat-846-waechter-appinfo
type: feature
created: 2026-11-05
updated: 2026-11-05
status: draft
workflow: feat-846-waechter-appinfo
---

# Spec: #846 — Täglicher Wächter meldet in #837, sobald der Untertitel schreibbar ist oder Mac 1.0 die Prüfung verlässt

## Approval

- [ ] Approved (Henning)

## Purpose

#837 AC-9 (Untertitel in App Store Connect schreiben) kann erst laufen, wenn eine App-Info `PREPARE_FOR_SUBMISSION` zeigt. Solange
macOS 1.0 in Prüfung ist, sind die gemeinsamen App-Infos gesperrt. Bisher merkt es nur eine zufällig startende Sitzung. Henning:
„bist sicher, dass wir auch auf etwas warten, was kommen wird?“ — und: er merkt sich keine Termine für Claude.

Ein täglicher, nur lesender GitHub-Lauf prüft ASC und kommentiert in #837 **genau einmal je Lage**:

- `editierbar`: genau eine App-Info steht auf `PREPARE_FOR_SUBMISSION` → AC-9 kann laufen.
- `mac_fertig`: keine App-Info ist editierbar, aber die Mac-Version (`platform=MAC_OS`) hat die Prüfung verlassen
  (z. B. `PENDING_DEVELOPER_RELEASE`, `REJECTED`, `READY_FOR_SALE`).
- `warten`: sonst. Keine Meldung.

**Ohne Modell:** zwei GET-Abfragen, ein Vergleich, ein Marker im Kommentartext. Regeln vor Modell trifft hier nicht als Konflikt auf; es gibt kein Modell.

**Hat es bisher funktioniert?** Nicht anwendbar, neues Werkzeug. Der Wächter ist der erste Cron-Lauf im Repo (bisher alles `workflow_dispatch`).

### Alternativen (verworfen)

- **Repo-Variable per `gh variable set`** als Gedächtnis: braucht `variables: write` für Zustand, den ein Kommentar ohnehin sichtbar zeigt.
- **Selbst-Deaktivierung (`gh workflow disable`)** nach der Meldung: braucht `actions: write` und verhindert die zweite Meldung bei späterem
  Wechsel (erst `mac_fertig`, dann `editierbar`).
- **Kein Wächter, Erinnerung an Henning:** widerspricht „Henning merkt sich keine Termine für mich“ (2026-11-04).

Kein ADR berührt.

## Source

- **Neu:** `scripts/asc_watch_appinfo.py`, `scripts/test_asc_watch_appinfo.py`, `.github/workflows/asc-watch-appinfo.yml`
- **Vorlagen:** `scripts/asc_app_info.py` (`app_infos`, `EDITABLE`, `Fatal`-Muster), `scripts/asc_store_probe.py` (Versionsabfrage
  `/v1/apps/{id}/appStoreVersions`), `scripts/test_asc_app_info.py` (`FakeASC`), `.github/workflows/asc-app-info.yml` (Secrets-Umgang)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `asc_wait_build` (`read_config`, `find_app_id`, `Fatal`) | skript | Zugang, App-ID, Fehlerart |
| `asc_what_to_test.get_data` | skript | GET gegen ASC mit Wiederholung bei 5xx |
| `asc_beta_probe` (`records`, `attributes`) | skript | Antwort lesen |
| `asc_app_info.app_infos`, `EDITABLE` | skript | Zustand der App-Infos |
| `gh` auf dem Runner, `GITHUB_TOKEN` | werkzeug | Kommentar in #837 |
| #837 AC-9, `asc-app-info.yml aktion=untertitel` | ticket/workflow | Nutzer der Meldung; danach wird der Wächter entfernt |

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `scripts/asc_watch_appinfo.py` | CREATE | `lage(infos, versions)` (rein), Hauptlauf liest nur (GET), gibt `LAGE=<lage>` und eine Klartextzeile aus |
| `scripts/test_asc_watch_appinfo.py` | CREATE | `FakeASC`-Nachbau mit Zustand; Lagen, Fehler, Ausgabe ohne Zugangsdaten, Workflow-Text |
| `.github/workflows/asc-watch-appinfo.yml` | CREATE | `schedule` täglich + `workflow_dispatch`, `concurrency`, Rechte `contents: read` + `issues: write`, Tests vor dem Lauf, Kommentar nur bei fehlendem Marker |

Geschätzt: Skript ≈ 70, Tests ≈ 170, Workflow ≈ 50 → **≈ 290 LoC, 3 Dateien, alle neu.** Das liegt über dem 250er-Limit; die Tests tragen
den Überhang (Sicherheitstests ≈ 2,5× Code, wie bei #615). **Zeilengrenze für diesen Schnitt: 300 LoC** — Freigabe mit `approved` dieser Spec
(Memory „LoC-Überhang durch Sicherheitstests“).

Keine Produktänderung, kein Swift-Code, keine Berechtigungen der App, keine AppStorage-Schlüssel, keine Info.plist, keine neuen Dependencies,
keine neuen Secrets. **Geräteliste:** Kein Pfad der Geräteliste berührt. Nichts läuft auf Hennings Geräten. Keine sichtbare UI, kein Entwurf nötig.

## Definition of Done

- [ ] `lage()` liefert `editierbar` / `mac_fertig` / `warten` nach den Regeln unten (AC-1 bis AC-4)
- [ ] 5xx und Netzfehler bleiben still und der Lauf grün; 401/403 macht den Lauf rot (AC-5, AC-6)
- [ ] Ausgabe enthält Zustände, nie Schlüssel, Token oder Apples Rohantwort (AC-7)
- [ ] Workflow: Zeitplan täglich + manuell, `concurrency`, Rechte minimal, Marker-Prüfung, genau ein Kommentar je Lage (AC-8 bis AC-10)
- [ ] Skripttests zuerst rot, dann grün; alle übrigen Skripttests in `scripts/` grün (AC-11)
- [ ] Nach dem Merge ein echter manueller Lauf (`workflow_dispatch`) belegt Lage `warten` ohne Kommentar, solange Mac 1.0 in Prüfung ist (Handlauf, kein AC)
- [ ] Abschaltung eingeplant: nach #837 AC-9 wird `asc-watch-appinfo.yml` entfernt (Aufgabe im Ticketende von #846/#837)

## Implementation Details

1. **`lage(infos, versions)`** (rein, ohne Netz):
   - `editierbar`, wenn genau eine App-Info `state == PREPARE_FOR_SUBMISSION` hat. Hat mehr als eine diesen Zustand, ebenfalls `editierbar`
     (der Schreibweg `asc_app_info.py` lehnt Mehrdeutigkeit selbst ab; der Wächter meldet nur, dass etwas schreibbar ist). `editierbar` hat Vorrang.
   - `mac_fertig`, wenn keine App-Info editierbar ist **und** es eine Version mit `platform == MAC_OS` gibt, deren `appStoreState` **nicht** in
     `{IN_REVIEW, WAITING_FOR_REVIEW, PREPARE_FOR_SUBMISSION, READY_FOR_REVIEW}` liegt. Gilt die Version mit der höchsten `versionString`;
     gibt es keine Mac-Version, ist es `warten`.
   - sonst `warten`. Fehlende Daten (leere Listen, Zustand `None`) sind nie ein Auslöser.
2. **Hauptlauf:** `read_config`, `find_app_id`, `app_infos(config, app_id)`, `GET /v1/apps/{id}/appStoreVersions?limit=10`. Ausgabe:
   `appinfo id=… state=…`, `version MAC_OS 1.0 state=…`, danach genau eine Zeile `LAGE=<lage>`; bei `GITHUB_OUTPUT` zusätzlich dorthin.
3. **Fehler:** `get_data` wiederholt bei 5xx/Netz und endet mit `Fatal`. Der Wächter unterscheidet: 401/403 → Exit 1 mit `::error::` (Schlüssel abgelaufen,
   sichtbar); alles andere → Hinweiszeile `::notice::ASC nicht erreichbar, nichts gemeldet`, `LAGE=warten`, Exit 0.
4. **Workflow `asc-watch-appinfo.yml`:**
   - `on: schedule: cron "17 7 * * *"` und `workflow_dispatch`; `permissions: contents: read, issues: write`;
     `concurrency: group: asc-watch-appinfo, cancel-in-progress: false`; `timeout-minutes: 10`; `runs-on: ubuntu-latest`.
   - Schritte: `actions/checkout@v7`, Skripttest, Lauf mit Schlüsseldatei (`umask 077`, `trap` löscht, wie `asc-app-info.yml`), dann Kommentarschritt.
   - Kommentarschritt: nur wenn `LAGE` ≠ `warten`. Marker `<!-- wachter-846:<lage> -->`; per `gh issue view 837 --json comments` suchen; fehlt er,
     `gh issue comment 837 --body-file` mit Marker und einem deutschen Satz (was ist eingetreten, was folgt: bei `editierbar` „#837 AC-9 kann laufen:
     `asc-app-info.yml aktion=untertitel`“, bei `mac_fertig` „Mac 1.0 hat die Prüfung verlassen (Zustand …), App-Infos prüfen“). Kein Marker-Fund → Kommentar; Fund → still.
   - Der Kommentartext enthält Zustände, nichts Geheimes.
5. **Tests (`unittest`, Stil `test_asc_app_info.py`):** `FakeASC` lokal, `ASC_API_BASE` umgebogen, kein Netz. Workflow-Datei als Text geprüft
   (Cron, Rechte, `concurrency`, Marker, kein `contents: write`, kein Schreibaufruf gegen ASC).

## Test Plan

| Test | Datei | Prüft |
|---|---|---|
| `test_editable_wins` | `test_asc_watch_appinfo.py` | App-Info `PREPARE_FOR_SUBMISSION` → `LAGE=editierbar`, auch wenn Mac zugleich fertig (AC-1, AC-4) |
| `test_mac_left_review` | dito | App-Infos gesperrt, Mac `PENDING_DEVELOPER_RELEASE` / `REJECTED` → `mac_fertig` (AC-2) |
| `test_mac_in_review_waits` | dito | Mac `IN_REVIEW`, App-Infos gesperrt → `warten` (AC-3) |
| `test_missing_data_waits` | dito | keine Mac-Version / leere Listen / fehlender Zustand → `warten` (AC-3) |
| `test_5xx_stays_quiet` | dito | ASC 503 → Exit 0, `LAGE=warten`, Notice (AC-5) |
| `test_401_fails_loudly` | dito | ASC 401/403 → Exit 1, `::error::` (AC-6) |
| `test_output_has_no_secrets` | dito | Schlüsseltext/Token nicht in der Ausgabe (AC-7) |
| `test_workflow_shape` | dito | Cron + Dispatch, Rechte, `concurrency`, Marker, kein ASC-Schreibzugriff (AC-8 bis AC-10) |
| Handlauf nach Merge | CI | `workflow_dispatch`, `LAGE=warten`, kein Kommentar in #837 (kein AC, siehe Definition of Done) |

Die Tests werden zuerst rot geschrieben (Skript fehlt).

## Acceptance Criteria

- **AC-1:** Given eine App-Info steht auf `PREPARE_FOR_SUBMISSION`, When der Wächter läuft, Then gibt er `LAGE=editierbar` aus, unabhängig vom Mac-Zustand.
- **AC-2:** Given keine App-Info ist editierbar und die Mac-Version steht nicht in `IN_REVIEW`/`WAITING_FOR_REVIEW`/`PREPARE_FOR_SUBMISSION`/`READY_FOR_REVIEW`, When der Wächter läuft, Then gibt er `LAGE=mac_fertig` aus.
- **AC-3:** Given keine App-Info ist editierbar und die Mac-Version ist in Prüfung, fehlt oder die Daten sind leer, When der Wächter läuft, Then gibt er `LAGE=warten` aus und meldet nichts.
- **AC-4:** Given beide Auslöser treffen zugleich zu, When der Wächter läuft, Then hat `editierbar` Vorrang.
- **AC-5:** Given ASC antwortet mit 5xx oder ist nicht erreichbar, When der Wächter läuft, Then endet er mit Exit 0, `LAGE=warten` und einem Hinweis, ohne Kommentar.
- **AC-6:** Given ASC antwortet mit 401 oder 403, When der Wächter läuft, Then endet er mit Exit 1 und `::error::`, damit ein abgelaufener Schlüssel sichtbar wird.
- **AC-7:** Given ein beliebiger Lauf, When die Ausgabe gelesen wird, Then enthält sie Zustände und IDs, aber weder Schlüsseltext noch Token noch Apples Rohantwort.
- **AC-8:** Given der Workflow, When er gelesen wird, Then läuft er täglich per `schedule` und manuell per `workflow_dispatch`, hat nur `contents: read` und `issues: write` und eine `concurrency`-Gruppe ohne Abbruch.
- **AC-9:** Given `LAGE` ist `editierbar` oder `mac_fertig` und #837 trägt den Marker `<!-- wachter-846:<lage> -->` noch nicht, When der Kommentarschritt läuft, Then legt er genau einen Kommentar mit diesem Marker in #837 an.
- **AC-10:** Given #837 trägt den Marker dieser Lage schon, oder `LAGE` ist `warten`, When der Kommentarschritt läuft, Then kommentiert er nicht; eine andere Lage (später `editierbar` nach `mac_fertig`) darf einen eigenen Kommentar bekommen.
- **AC-11:** Given der Stand vor der Umsetzung, When `scripts/test_asc_watch_appinfo.py` läuft, Then ist er rot; nach der Umsetzung grün, ebenso alle übrigen Skripttests in `scripts/`.

Der Handlauf nach dem Merge (`LAGE=warten`, kein Kommentar, solange Mac 1.0 in Prüfung ist) steht in Definition of Done und Testplan, nicht hier: er
entsteht erst nach dem PR und würde das QA-Gate vor dem Commit sperren.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — reines CI-Werkzeug ohne Architekturwirkung; kein bestehender ADR wird berührt oder gekippt.

## Changelog

- 2026-11-05 — Spec angelegt (#846), Zeilengrenze 300 LoC zur Freigabe vorgeschlagen.
