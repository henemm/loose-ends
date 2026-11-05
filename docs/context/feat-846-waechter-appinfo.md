# Context: feat-846-waechter-appinfo

## Request Summary
#846: Ein täglicher, nur lesender GitHub-Lauf (cron) prüft App Store Connect und kommentiert in #837 genau einmal, sobald
(a) eine App-Info `PREPARE_FOR_SUBMISSION` zeigt (Untertitel schreibbar, #837 AC-9 kann laufen) oder
(b) macOS 1.0 die Prüfung verlässt (z. B. `PENDING_DEVELOPER_RELEASE`, `REJECTED`), ohne dass eine App-Info editierbar wurde.
Anlass: Henning, 2026-11-05 — „bist sicher, dass wir auch auf etwas warten, was kommen wird?“ Bisher merkt es nur eine zufällig startende Sitzung.

## Stand in ASC (aus #837 S2, Probe 2026-11-05 07:14Z)
- App-Info 1 `READY_FOR_DISTRIBUTION`, App-Info 2 `IN_REVIEW`, keine `PREPARE_FOR_SUBMISSION`.
- Versionen: iOS 1.0 `READY_FOR_SALE`, iOS 1.0.1 `PREPARE_FOR_SUBMISSION`, Mac 1.0 `IN_REVIEW`.
- Gemeinsame App-Infos sind gesperrt, solange Mac 1.0 in Prüfung ist; Henning: warten.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_app_info.py` | `app_infos(config, app_id)`, `EDITABLE = "PREPARE_FOR_SUBMISSION"`, `Fatal`-Muster, Ausgabe `::error::`; Quelle der Zustandsabfrage (nur GET) |
| `scripts/asc_store_probe.py` (Z. 59–64) | liest `/v1/apps/{id}/appStoreVersions?limit=5` mit `versionString`/`platform`/`appStoreState` — Vorlage für die Versionsabfrage |
| `scripts/asc_wait_build.py` | `read_config`, `find_app_id`, `get_json`, `make_token`, `Fatal` |
| `scripts/asc_beta_probe.py` | `records`, `attributes` |
| `scripts/asc_what_to_test.py` | `get_data` |
| `scripts/test_asc_app_info.py` | Testmuster: lokaler `FakeASC`-Server mit Zustand, `ASC_API_BASE` umgebogen, Prüfung von Workflow-Datei (YAML-Text) und Ausgabe ohne Zugangsdaten |
| `.github/workflows/asc-app-info.yml`, `asc-crashes.yml` | Vorlage Secrets-Umgang (`umask 077`, Schlüsseldatei mit `trap` löschen), Unit-Tests vor dem Lauf, `actions/checkout@v7` |
| `.github/workflows/board.yml` | einziger Workflow mit Schreibrecht auf Issues/Board (Rechte-Muster) |

## Existing Patterns
- ASC-Skripte laufen nur in der CI; Tests mit lokalem Nachbau, kein Netz.
- Bisher **kein** Workflow mit `schedule:`; alle ASC-Läufe sind `workflow_dispatch`. Der Wächter ist der erste Cron-Lauf und braucht `issues: write` (nur Kommentar in #837) — sonst `contents: read`.
- Ausgabe: Zustände ja, Schlüssel/Token/Apples Rohantwort nie.

## Dependencies / Dependents
- Upstream: ASC-API (`/v1/apps/{id}/appInfos`, `/v1/apps/{id}/appStoreVersions`), Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, `GITHUB_TOKEN` (Issue-Kommentar).
- Downstream: #837 AC-9 (Schreiben des Untertitels per `asc-app-info.yml aktion=untertitel`); nach AC-9 wird der Zeitplan entfernt.

## Offene Entwurfsfragen für /20-analyse
- **„Genau einmal“ ohne Zustandsspeicher:** Wie merkt sich der Lauf, was gemeldet ist? Alternativen: (1) Marker im Kommentartext in #837 suchen (`gh issue view --comments`), kein neuer Speicher; (2) Repo-Variable per `gh variable set`; (3) Lauf deaktiviert sich nach der Meldung selbst (`gh workflow disable`). Regelweg zuerst: (1).
- Zustandswechsel-Definition: Meldung (a) bei jeder editierbaren App-Info; (b) wenn die Mac-Version nicht mehr `IN_REVIEW`/`WAITING_FOR_REVIEW` ist **und** (a) nicht gilt. Welche Zustände zählen als „verlässt die Prüfung“ (Plattform `MAC_OS`, `appStoreState`)?
- Unerreichbares ASC / 5xx → still (kein Fehlalarm), aber 401/403 → Lauf rot (sichtbar), damit abgelaufene Schlüssel nicht still den Wächter töten.
- GitHub deaktiviert Cron-Workflows nach 60 Tagen ohne Repo-Aktivität; für die erwartete Wartezeit unkritisch.
- Gerätestufe: berührt keinen Pfad der Geräteliste (nur `scripts/`, `.github/workflows/`) → Abnahme endet nach Stufe 2; Simulator-Nutzung hier nicht anwendbar (kein App-Code).

## Risks & Considerations
- Cron-Lauf auf `main` startet erst nach Merge; Wirksamkeit nur über einen echten (manuellen) Lauf belegbar (`workflow_dispatch` zusätzlich anbieten).
- Doppelmeldung bei parallelen Läufen → `concurrency`-Gruppe setzen.
- Scoping: ein Skript + Test + ein Workflow ≈ 3 Dateien, Tests ≈ 2,5× Code — Schätzung in der Analyse nennen.

## Analysis

### Type
Feature (CI-Werkzeug, kein App-Code).

### Recherche (Pflicht, zuerst)
- `GITHUB_TOKEN` mit `issues: write` darf Kommentare anlegen; `schedule:` läuft nur auf dem Default-Branch, Cron-Läufe in öffentlichen Repos werden nach 60 Tagen ohne Aktivität deaktiviert (GitHub Docs, „Events that trigger workflows“). Für die erwartete Wartezeit unkritisch.
- ASC: `appInfos.state` und `appStoreVersions.appStoreState`/`platform` sind bereits in `asc_app_info.py` und `asc_store_probe.py` im Einsatz; keine neue Schnittstelle.

### Ohne Modell, ohne Zustandsspeicher
Reine Regel: zwei GET-Abfragen, ein Vergleich, ein Marker im Kommentartext. Modell nicht beteiligt.

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_watch_appinfo.py` | CREATE | liest appInfos + appStoreVersions, entscheidet `lage()` → `editierbar` / `mac_fertig` / `warten`, gibt Meldung + Marker aus; nur GET |
| `scripts/test_asc_watch_appinfo.py` | CREATE | `FakeASC` wie in `test_asc_app_info.py`; 4 DoD-Fälle plus 401, 5xx, beide Auslöser zugleich |
| `.github/workflows/asc-watch-appinfo.yml` | CREATE | `schedule` täglich + `workflow_dispatch`, `concurrency`, Rechte `contents: read` + `issues: write`, Tests vor dem Lauf, Kommentar nur per `gh issue comment 837`, wenn Marker fehlt |

### Scope Assessment
- Files: 3 (alle neu, keine Berührung von Produktcode)
- Geschätzt: Skript ≈ 70 LoC, Tests ≈ 170 LoC, Workflow ≈ 50 LoC → ≈ 290 LoC. **Über dem 250er-Limit** (Tests ≈ 2,5× Code, siehe Memory „LoC-Überhang durch Sicherheitstests“). Vor dem Bauen Freigabe der Zeilengrenze in der Spec einholen oder den Test auf die vier DoD-Fälle + 401 kürzen (≈ 230).
- Risk Level: LOW (nur lesend gegen ASC, schreibt nur einen Kommentar in #837)

### Technical Approach
1. **Entscheidung im Skript, Kommentar im Workflow.** Das Skript gibt auf stdout `LAGE=editierbar|mac_fertig|warten` plus Klartext; der Workflow-Schritt kommentiert nur bei `editierbar`/`mac_fertig`.
2. **„Genau einmal“ ohne Speicher:** Marker `<!-- wachter-846:<lage> -->` im Kommentartext; der Workflow prüft mit `gh issue view 837 --json comments` auf diesen Marker und bleibt dann still. Kein neuer Speicher, kein Selbst-Abschalten.
3. **Lage:** `editierbar`, wenn genau eine App-Info `PREPARE_FOR_SUBMISSION` hat (Vorrang). `mac_fertig`, wenn keine editierbar ist und die Version `platform=MAC_OS` nicht mehr in `IN_REVIEW`/`WAITING_FOR_REVIEW`/`PREPARE_FOR_SUBMISSION`/`READY_FOR_REVIEW` steht (z. B. `PENDING_DEVELOPER_RELEASE`, `REJECTED`, `READY_FOR_SALE`). Sonst `warten`. Eine Mac-Version ganz ohne Eintrag zählt als `warten` (nie Fehlalarm aus fehlenden Daten).
4. **Fehler:** 5xx/Netz → `get_data` wiederholt und endet mit `Fatal`; im Wächter wird das als Hinweis ausgegeben und der Lauf bleibt grün (still). 401/403 → `Fatal` mit Exit 1, Lauf rot und sichtbar.
5. **Cron:** täglich, z. B. `17 7 * * *` (krumme Minute gegen Lastspitzen). `workflow_dispatch` zusätzlich, damit der Nachweis nicht auf den Zeitplan wartet.
6. **Abschalten:** nach #837 AC-9 wird die Datei entfernt (steht als Aufgabe im Ticketende).

### Alternativen
- **Repo-Variable per `gh variable set`** als Gedächtnis: braucht `variables: write`, ein weiteres Recht für Zustand, den ein Kommentar ohnehin sichtbar zeigt. Verworfen.
- **Selbst-Deaktivierung (`gh workflow disable`)** nach der Meldung: braucht `actions: write`, verhindert ein erneutes Melden bei späterem Zustandswechsel (z. B. erst `mac_fertig`, dann `editierbar`). Verworfen.
- **Kein Wächter, Henning-Erinnerung:** widerspricht „Henning merkt sich keine Termine für mich“.
- Gekippte ADR: keine.

### Befunde gegen den Plan
- Bisher kein Cron-Workflow im Repo, der Wächter ist der erste; Wirksamkeit des Zeitplans erst nach Merge belegbar, Zustandslogik und Marker-Prüfung aber vorher per Test und manuellem `workflow_dispatch` nach dem Merge.
- Zwei Meldungen können nacheinander kommen (`mac_fertig`, später `editierbar`): gewollt, da Marker je Lage.

### Dependencies
`asc_wait_build` (`read_config`, `find_app_id`, `Fatal`), `asc_what_to_test.get_data`, `asc_beta_probe` (`records`, `attributes`); `gh` auf dem Runner.

### Open Questions
- [ ] Freigabe der Zeilengrenze (≈ 290 statt 250 LoC) in der Spec, oder Tests kürzen?
- Gerätestufe: Kein Pfad der Geräteliste berührt.
