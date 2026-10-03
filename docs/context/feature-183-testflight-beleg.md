# Context: feature-183-testflight-beleg

## Request Summary
Issue #183: Jeder TestFlight-Lauf belegt selbst und abrufbar, dass der Build bei Apple angekommen und
verarbeitet ist (ASC-API, `processingState`), und schreibt die Archiv-Nachweistabelle zusätzlich ins
Lauf-Protokoll. Voraussetzung für #175 (Messung auf Hennings iPhone) und damit für #176.

## Befunde (2026-10-03)

| Befund | Beleg |
|---|---|
| Upload-Schritt endet grün mit „Upload succeeded“, sagt aber nichts über die Verarbeitung bei Apple | #174, Lauf 37119618643; `testflight.yml:149-160` |
| Nachweistabelle geht nur nach `$GITHUB_STEP_SUMMARY` (`SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"`) und ist per REST nicht abrufbar | `testflight.yml:88`, Memory `loose-ends-testflight-belege-abrufbar` |
| Der ASC-Schlüssel liegt nur in der CI (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`) und wird schon als `.p8` unter `$HOME/private_keys/` abgelegt; der Schritt „Remove the key“ läuft zuletzt | `testflight.yml:56-60,176-178` |
| Build-Nummer = `github.run_number`, Version `0.1.0` (fest im Nachweisschritt) | `testflight.yml:76,87` |
| Auf dem Mac ist weder `jwt` (Python) installiert noch der Schlüssel lokal zugänglich (Secrets-Guard) → die API-Abfrage lässt sich lokal nur gegen Fixtures prüfen, echt nur im CI-Lauf | `python3 -c "import jwt"` schlägt fehl; Memory |
| Es gibt kein Skript für ASC-Abfragen und keinen Test dafür; Muster für „Skript + Pythontest“ ist `scripts/sim_proof.py` + `scripts/test_sim_proof.py` | `ls scripts` |

## Related Files
| File | Relevance |
|------|-----------|
| `.github/workflows/testflight.yml` | Tabelle zusätzlich auf stdout; neuer Schritt nach „Upload to TestFlight“ (vor „Remove the key“) |
| `docs/reference/testflight.md` | Abschnitte „5. Build starten“ (Z. 75-85, „Grün heißt: hochgeladen“), „Wenn es hakt“, „Was der Workflow tut“ müssen den neuen Schritt beschreiben |
| `scripts/` (neu: ASC-Wartescript + Test) | Logik als testbares Skript statt Inline-YAML; Fixtures für `VALID`/`PROCESSING`/`INVALID`/Zeitüberschreitung |
| `scripts/sim_proof.py`, `scripts/test_sim_proof.py` | Vorbild für Aufbau und Testart |
| `.github/workflows/ci.yml` | Prüft heute keine `scripts/*.py`-Tests; falls der neue Test in CI laufen soll, ist das eine Änderung hier |

## Existing Patterns
- Nachweisschritt ist als lokal lauffähiges Bash-Fragment gebaut (`ARCHIVE=… BUILD=…`), Abweichung = `exit 1` mit `::error::`.
- Fehlertext in „Show what went wrong“ greppt `archive.log`/`upload.log`; Logs gehen als Artefakt `testflight-logs` hoch.
- Secrets werden nie ausgegeben; Schlüsseldatei wird am Ende immer gelöscht.

## Dependencies
- Upstream: App Store Connect API (`GET /v1/builds` mit Filter auf App und Build-Version, Feld `processingState`: `PROCESSING`, `FAILED`, `INVALID`, `VALID`), JWT mit ES256 aus dem vorhandenen `.p8`; Python 3.14 bzw. Runner-Python und `openssl` (JWT-Signatur ohne Zusatzpaket oder mit `pip install`).
- Downstream: #175 (Messung braucht belegten, verarbeiteten Build), #176; Anleitung `docs/reference/testflight.md`.

## Risks & Considerations
- **Offene Fachfragen für `/20-analyse` (Recherche zuerst):** genaue API-Pfade und Filter (Build-Nummer, App-ID aus Bundle-ID), ob `processingState` oder `buildAudienceType`/Ablaufstatus der richtige Beleg ist, Dauer der Verarbeitung (Hennings Doku sagt 10–30 Minuten), Rolle des Schlüssels (App Manager reicht fürs Lesen?).
- **Blast Radius:** der Schritt hängt hinter dem Upload; ein Fehler im Warteschritt macht einen erfolgreichen Upload rot. Wartezeit muss das `timeout-minutes: 60` des Jobs einhalten.
- **Nachweis nur im echten Lauf:** AC „Lauf zeigt `processingState: VALID`“ lässt sich nur durch einen echten TestFlight-Lauf belegen; der kostet eine Build-Nummer und lädt einen Build hoch.
- **Kein Pfad der Geräteliste berührt** (`project.yml`, Entitlements, Info.plist bleiben unverändert).
- **Alternative:** statt Warten per ASC-API den Upload-Status von `xcodebuild -exportArchive` auswerten — meldet nur „hochgeladen“, nicht „verarbeitet“, trägt DoD Punkt 2 nicht.

## Existing Specs
- Keine Spec zu ASC-Abfragen. Vorgänger: `docs/context/fix-174-testflight-ios27.md`.

## Analysis

### Type
Feature (CI-Werkzeug, keine App-Änderung, nichts Sichtbares → kein Entwurf nötig)

### Recherche (2026-10-03, Quellen)
- Token: ES256, Header `alg/kid/typ`, Payload `iss` (Issuer-ID), `iat`, `exp` (max. 20 min), `aud=appstoreconnect-v1`; optional `scope` (z. B. `GET /v1/builds?…`) — https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests
- Abfrage: `GET /v1/builds?filter[app]=<id>&filter[version]=<Build-Nr>`, Statuswerte `PROCESSING | FAILED | INVALID | VALID` — Apple-Seite „List builds“ liefert die Parameter nicht im Text; belegt über Beispiele anderer Entwickler (Suche 2026-10-03). App-ID kommt aus `GET /v1/apps?filter[bundleId]=com.henning.looseends`.
- Rolle: Admin-Schlüssel (Memory `apple-developer-account`) darf alles; App Manager/Developer genügen laut Rollenmatrix für Builds.
- Build erscheint erst Minuten nach „Upload succeeded“ in der Liste (Apple-Forum: teils Stunden) → leere Antwort heißt „noch nicht da“, nicht Fehler.
- `buildUploads` (neuere API, `BuildUploadState`) und Webhook `BUILD_UPLOAD_STATE_UPDATED` existieren; für `xcodebuild -exportArchive`-Uploads nicht belegt → nicht gewählt.

### Without the model…
Nicht zutreffend: reine Protokoll-/HTTP-Aufgabe, kein Sprachverstehen.

### Affected Files
| File | Change | Description |
|------|--------|-------------|
| `scripts/asc_wait_build.py` | CREATE | stdlib-only: JWT (ES256 via `openssl dgst -sign`, DER→r‖s in Python), App-ID aus Bundle-ID, Polling auf `filter[version]`, Ausgabe `build=<n> processingState=<…>`, Exit ≠ 0 bei FAILED/INVALID/Zeitüberschreitung |
| `scripts/test_asc_wait_build.py` | CREATE | Tests gegen lokalen Fake-Server (`ASC_API_BASE`), selbst erzeugter EC-Schlüssel; Signatur mit `openssl dgst -verify` geprüft |
| `.github/workflows/testflight.yml` | MODIFY | Tabelle zusätzlich ins Protokoll; neuer Job `confirm` (ubuntu-latest, `needs: upload`) ruft das Skript auf |
| `docs/reference/testflight.md` | MODIFY | Schritt 5, „Wenn es hakt“, „Was der Workflow tut“ |

### Scope Assessment
- Files: 4 · Estimated LoC: ca. +250 (Skript ~90, Test ~110, Workflow ~30, Doku ~20) — am Limit; Schnitt bei Überschreitung: Tabelle-im-Protokoll bleibt, Test auf Kernfälle kürzen
- Risk Level: LOW–MEDIUM (rührt Upload-Schritt nicht an; Blast Radius = nur der neue Job)
- Kein Pfad der Geräteliste berührt (`.github/`, `scripts/`, `docs/`).

### Technical Approach (Empfehlung)
1. Eigener Job `confirm` auf `ubuntu-latest` statt Schritt auf dem Mac-Runner: Das Warten (10–30 min) verbrennt keine teuren macOS-Minuten, der Upload-Job bleibt grün, und rot wird der Lauf trotzdem (ein roter Job). Schlüssel wird nur kurz in eine Temp-Datei geschrieben und danach gelöscht; nie ausgegeben.
2. Skript statt Inline-YAML, damit lokal gegen Fixtures testbar (Mac hat kein `jwt`, Schlüssel nicht zugänglich → stdlib + openssl).
3. Polling alle 30 s, Obergrenze 45 min; neues Token je Abfrage-Runde (Lebensdauer 10 min).
4. Beleg im Protokoll: Build-Nummer, `processingState`, `uploadedDate`; Tabelle der Archiv-Prüfung zusätzlich auf stdout.
5. Nachweis DoD 1+2 nur durch echten Lauf (`workflow_dispatch` vom PR-Zweig, kostet eine Build-Nummer).

### Alternativen
- **A (gewählt): ASC-Polling `builds`/`processingState`** — erfüllt DoD wörtlich.
- **B: Schritt im bestehenden Job** — einfacher, aber 30 min macOS-Runner und Upload-Job wird rot, obwohl Upload gelang.
- **C: `buildUploads`-Status** — früheres Signal, aber für Xcode-Uploads unbelegt; erst messen.
- **D: Bestätigung per Apple-Mail/Webhook** — Mail ist nicht abrufbar, Webhook bräuchte öffentlichen Endpunkt.
- **E: ganz ohne Warten** — „Upload succeeded“ genügt; trägt Hennings Messung (#175) nicht, weil sie einen verarbeiteten Build braucht.
- Gekippt würde keine ADR; nur die Annahme aus #174 „grün heißt hochgeladen“.

### Dependencies
Upstream: ASC-API, Secrets `ASC_KEY_ID/ISSUER_ID/PRIVATE_KEY`, `openssl`+`python3` auf ubuntu-latest. Downstream: #175, #176.

### Open Questions
- [ ] Parameter `filter[version]` praktisch bestätigen — nur der echte Lauf zeigt es; Skript prüft deshalb `attributes.version` der Antwort selbst.
- [ ] Freigabe, dass ein echter TestFlight-Lauf (eine Build-Nummer) zum Nachweis nötig ist.
