# Context: feat-773-testflight-crashes

## Request Summary
Henning (2026-10-31) möchte, dass Claude die Absturzberichte, die er und später externe Tester über TestFlight an Apple
schicken, selbst abholt und auswertet, ohne dass er etwas herunterladen muss. Gleiches Vorhaben in Restock (#242), dort
nach diesem Ticket übertragen.

## Recherche (2026-10-31)
- Ablage bei Apple: App Store Connect → App → TestFlight → Feedback → Crashes; 120 Tage vorgehalten; Xcode Organizer
  „Open in Xcode“. Quelle: https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback
- API (seit WWDC25-324 dokumentiert): `GET /v1/apps/{id}/betaFeedbackCrashSubmissions` (Liste),
  `GET /v1/betaFeedbackCrashSubmissions/{id}/crashLog` → Typ `betaCrashLogs`, einziges Attribut `logText` (string).
  Rollen ADMIN, APP MANAGER, DEVELOPER. Quelle: https://developer.apple.com/documentation/appstoreconnectapi/beta-feedback-crash-submissions
- Attribute einer Meldung (alle optional): appPlatform, appUptimeInMilliseconds, architecture, batteryPercentage,
  buildBundleId, comment, connectionType, createdDate, deviceFamily, deviceModel, devicePlatform, diskBytesAvailable,
  diskBytesTotal, **email**, locale, osVersion, pairedAppleWatch, screenHeightInPoints, screenWidthInPoints, timeZone.
- Forum: Organizer zeigt nicht immer alles, was ASC hat (https://developer.apple.com/forums/thread/742210); ein Hänger ohne
  echten Absturz liefert oft keinen Bericht.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_wait_build.py` | gemeinsame Bausteine: `Fatal`, `make_token` (ES256 per openssl), `get_json` (Wiederholung bei 5xx/408/429/Netz, 4xx Fatal), `find_app_id`, `read_config` (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE, ASC_BUNDLE_ID, ASC_API_BASE, ASC_POLL_SECONDS) |
| `scripts/asc_what_to_test.py` | Muster für ein Folgeskript: importiert aus `asc_wait_build`, `get_data` mit Wiederholung, `::error::` bei Fatal |
| `scripts/asc_beta_probe.py` | Muster für ein nur lesendes Skript, das eine Belegtabelle in den Lauf-Log druckt |
| `scripts/test_asc_what_to_test.py` | Testmuster: lokaler HTTP-Nachbau der ASC-API (`FakeASC`), Skript als Unterprozess, unittest, Aufruf `python3 scripts/test_….py` |
| `.github/workflows/asc-beta.yml` | Handlauf `workflow_dispatch` mit `aktion`-Auswahl; Schlüssel aus Secret nach `$RUNNER_TEMP/asc_key.p8` mit `umask 077` und `trap rm` |
| `.github/workflows/testflight.yml` | `uploadSymbols` true (iOS und Mac) → Apple hat die dSYMs, Berichte kommen voraussichtlich symbolisiert |
| `docs/reference/testflight.md` | Doku des TestFlight-Wegs; Abschnitt „Was der Workflow tut“, „Einladung: Apple-Seite (#705)“ |
| `.github/workflows/ci.yml` | führt die `scripts/test_*.py` aus (zu prüfen, ob neue Testdatei automatisch mitläuft) |

## Existing Patterns
- Jedes ASC-Skript: nur Standardbibliothek plus `openssl`, Schlüssel/Token nie im Log, Fehler als `::error::` und Exit 1.
- Handläufe laufen nie automatisch (`workflow_dispatch`), Belege stehen im Lauf-Log.
- Secrets nur über `env` im Job; das Repo ist öffentlich (Kommentar in `asc-beta.yml`).

## Dependencies
- Upstream: Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` (Rolle Admin), `asc_wait_build.py`.
- Downstream: niemand; neues, eigenständiges Werkzeug. Die App wird nicht berührt → keine Gerätestufe.

## Existing Specs
- `docs/specs/feat-176-testflight-abnahme.md`, `docs/specs/feat-175-cloudkit-produktion.md` (verwandter TestFlight-Weg)

## Risks & Considerations
- **Öffentliches Repo:** Lauf-Logs und Artefakte sind für jeden mit GitHub-Konto lesbar. Meldungen enthalten die E-Mail
  des Testers, Kommentar, Gerät, Zeitzone; Berichte Pfade und Gerätedaten. Klartext darf weder ins Log noch als
  Artefakt. Weg zu klären in der Analyse: asymmetrisch verschlüsseln (öffentlicher Schlüssel im Repo, privater nur auf
  Hennings Mac), privates Repo als Ablage, oder Auswertung nur lokal.
- Secrets-Guard blockt `.pem`/`.key` immer → eine Schlüsseldatei als Argument scheitert; `gpg` (vorhanden unter
  `/opt/homebrew/bin/gpg`) entschlüsselt aus dem Schlüsselbund ohne Dateipfad. `age` fehlt.
- Der lokale ASC-Schlüssel existiert absichtlich nicht ([[loose-ends-testflight-belege-abrufbar]]).
- Ob Berichte vollständig symbolisiert kommen, zeigt erst der echte Lauf; ohne Meldung gibt es nichts zu sehen → ein
  Probelauf mit „0 Meldungen“ belegt den Weg nur halb.
- Paging: Liste über `links.next`, `limit` bis 200.
- Restock (#242) ist ein anderes Repo mit eigener ASC-Bibliothek (`asc_lib.py` mit Pfad-Freigabeliste); Sichtbarkeit dort
  ebenfalls prüfen.

## Analysis

### Type
Feature (Werkzeug, die App wird nicht berührt)

### Kernproblem
Das Repo ist öffentlich (`gh repo view`: PUBLIC). Lauf-Log und Artefakte sind für jeden mit GitHub-Konto lesbar. Absturz-
meldungen tragen E-Mail, Kommentar, Gerät, Zeitzone der Tester; Berichte Gerätedaten. Klartext darf das Runner-Dateisystem
nie verlassen. Auf dem Mac gibt es noch keinen GPG-Schlüssel (`gpg --list-secret-keys` leer, 2026-10-31).

### Wege (verglichen)
| Weg | Henning tut | Datenschutz | Aufwand | kippt |
|---|---|---|---|---|
| **A: Artefakt mit GPG verschlüsselt** (öffentlicher Schlüssel im Repo, geheimer Teil ohne Passphrase nur im GnuPG-Verzeichnis dieses Macs; CI `gpg --recipient-file … --encrypt`, Claude `gpg --decrypt` in den Scratchpad) | nichts | Artefakt nur Chiffrat, Log nur Zahlen | klein, gpg auf ubuntu-latest vorinstalliert, kein neues Secret | nichts |
| B: Ablage in privatem Repo (Deploy-Key als Secret, CI pusht) | nichts | gut, aber Testerdaten liegen dauerhaft in Git-Historie | mittel: neues Repo, Schlüssel, Löschregel | nichts |
| C: Lokal abholen mit ASC-Schlüssel auf dem Mac | nichts | gut | klein | die bewusste Entscheidung „kein lokaler ASC-Schlüssel“ ([[loose-ends-testflight-belege-abrufbar]]) |
| D: Henning lädt die ZIP in ASC herunter | je Absturz Handarbeit | gut | null | seine Wahl im Ticket |
| E: Xcode Organizer auf dem Mac (lädt Crashes lokal) | evtl. Anmeldung | gut | null, aber unzuverlässig: meine xcodebuild-Läufe melden das Xcode-Konto ab, Organizer zeigt nicht alles (Forum 742210) | nichts |

Empfehlung: **A**. Gegen A spricht: geht der Schlüssel auf dem Mac verloren, sind alte Artefakte unlesbar — unkritisch,
Apple hält die Meldungen 120 Tage, ein neuer Lauf mit neuem Schlüssel holt sie wieder. `openssl` (hybrid RSA+AES) ginge
statt gpg, ist aber mehr Eigenbau; gpg mit `--recipient-file` braucht keinen Schlüsselbund auf dem Runner.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_crashes.py` | CREATE | Liste paginiert über `links.next` (limit 200), je Meldung `crashLog` → `logText`; schreibt `<id>.json` (Attribute) und `<id>.crash` in einen Zielordner; druckt nur Anzahl und je Meldung Build/Datum/Plattform, nie E-Mail, Kommentar, Gerät; ohne Meldung „keine Absturzmeldungen“ |
| `scripts/test_asc_crashes.py` | CREATE | `FakeASC` wie `test_asc_what_to_test.py`: 0 Meldungen, 2 Seiten, Bericht fehlt (404 → als „ohne Bericht“ vermerkt), 5xx-Wiederholung, Log enthält nie E-Mail/Kommentar; läuft über `unittest discover` in `ci.yml` automatisch mit |
| `.github/workflows/asc-crashes.yml` | CREATE | `workflow_dispatch`, ASC-Schlüssel wie in `asc-beta.yml`, Skript schreibt nach `$RUNNER_TEMP`, `tar` + `gpg --encrypt` → Artefakt `crashes.tar.gpg`, Klartext per `trap rm` weg, retention 14 Tage |
| `docs/reference/crash-recipient.pub.asc` (Name in der Spec festlegen, Secrets-Guard beachten) | CREATE | öffentlicher GPG-Schlüssel; Erzeugung ohne Passphrase auf diesem Mac durch Claude |
| `docs/reference/testflight.md` | MODIFY | Abschnitt „Absturzberichte abholen“: Lauf, `gh run download`, Entschlüsseln, Symbolisieren |

Eigener Workflow statt neuer `aktion` in `asc-beta.yml`: dort hängt jede Aktion am Probe-Job und neben nicht
rücknehmbaren Einladungsschritten; ein reines Lese-Werkzeug daneben bleibt getrennt und minimal berechtigt.

### Scope Assessment
- Files: 5 (eine davon die Schlüsseldatei)
- Estimated LoC: Skript ~110, Tests ~130, Workflow ~35, Doku ~20 → ~295 ohne Schlüsseldatei, also über 250
- Schnitt-Vorschlag: **Schnitt 1** Skript + Tests (~240); **Schnitt 2** Workflow, Schlüssel, Doku, Probelauf und ggf.
  Auswertung (~55 + Schlüssel)
- Risk Level: LOW — nur lesende ASC-Aufrufe, keine App-Datei, kein Pfad der Geräteliste → keine Gerätestufe

### Technical Approach
Schnitt 1: `asc_crashes.py <zielordner>` mit `read_config`/`find_app_id`/`get_json` aus `asc_wait_build.py`; Plattform
nicht filtern (iOS und Mac in einer Liste, `appPlatform` je Meldung). Schnitt 2: Workflow verschlüsselt den Ordner, Claude
lädt mit `gh run download`, entschlüsselt in den Scratchpad, liest. Symbolisierung: `uploadSymbols` ist an → Bericht
vermutlich symbolisiert; falls nicht, `atos` gegen das dSYM (erst prüfen, wenn ein Bericht da ist).

### Dependencies
`asc_wait_build.py` (Bausteine), Secrets `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_PRIVATE_KEY`, gpg auf ubuntu-latest und Mac.

### Open Questions
- keine PO-Frage: der Datenschutzweg ist technisch, Testerdaten verlassen den Runner nur verschlüsselt
- im echten Lauf zu klären: ob `crashLog` für jede Meldung existiert (Hänger ohne Bericht) und ob er symbolisiert ist
