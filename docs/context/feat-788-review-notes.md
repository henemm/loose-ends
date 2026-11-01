# Context: feat-788-review-notes

## Request Summary
Apple hat die Einreichung von Version 1.0 (iOS, 2026-10-31, ID b8154b09-0fff-4147-8354-a1e72a14aa4c) mit „Guideline 2.1 –
Information Needed“ zurückgegeben: Notizen (Zweck, Zielgruppe, Bedienung, Dienste, Regionen, Regulierung) ins Feld „Notes“ der
App-Review-Informationen plus Bildschirmaufnahme von einem echten Gerät. Henning hat die Aufnahme gemacht
(`~/Downloads/ScreenRecording_loose_ends.mov`, 77,7 s, 1206×2622, h264/aac, 64 MB, beginnt mit dem Öffnen aus TestFlight).
Ziel dieses Workflows: Notizen und Video per App Store Connect API an die Version 1.0 hängen und das belegen. Das erneute
Einreichen gehört nicht dazu und geschieht nur nach Hennings Wort.

## Related Files
| File | Relevance |
|------|-----------|
| `docs/reference/app-review-notizen.md` | Entwurf des Notes-Textes (2494 Byte, Limit 4000 Byte), an das gezeigte Video angepasst |
| `scripts/asc_wait_build.py` | `read_config`, `make_token`, `get_json`, `find_app_id`, `Fatal` — Grundlage jedes ASC-Skripts |
| `scripts/asc_what_to_test.py` | `send_json` (PATCH/POST mit Wiederholung bei 5xx/408/429), `get_data` |
| `scripts/asc_beta_setup.py` | Muster „erst lesen, nur Abweichungen schreiben, Ausgabe nur gesetzt/leer/unverändert“ — Vorbild für das neue Skript |
| `scripts/asc_store_probe.py` | liest `appStoreVersions` samt `appStoreState`; Vorbild für den Lesebeleg |
| `scripts/asc_beta_probe.py` | `Probe`, `records`, `attributes`, `filled` |
| `scripts/test_asc_beta_setup.py` | Testmuster für ASC-Skripte (Fake-Antworten, keine echten Aufrufe) |
| `.github/workflows/asc-store-probe.yml`, `asc-beta.yml` | Handlauf-Workflows mit Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` |
| `docs/reference/testflight.md` | Belegtabelle und Doku der ASC-Handläufe |

## Existing Patterns
- ASC-Zugriff nur in der CI: der Schlüssel liegt ausschließlich in GitHub-Secrets, lokal ist die ASC-API gesperrt (Memory
  „TestFlight-Belege abrufbar?“). Belege kommen ins Lauf-Protokoll, nie in die Step-Summary.
- Handläufe sind `workflow_dispatch` mit `aktion`-Auswahl; schreibende Aktionen idempotent, nie automatisch.
- Ausgaben nennen nie Werte (Kontaktdaten, Schlüssel), nur Zustände; das Repo ist öffentlich.
- Nur Standardbibliothek plus `openssl`.

## Apple-Schnittstelle (recherchiert 2026-11-01)
- `appStoreReviewDetails` hängt an der `appStoreVersion`; Attribut `notes`, Limit 4000 **Byte**
  ([App Review information](https://developer.apple.com/help/app-store-connect/reference/app-review-information),
  [App Store review details](https://developer.apple.com/documentation/appstoreconnectapi/app-store-review-details)).
- Anhänge: `appStoreReviewAttachments` für „demo videos“; POST (Reservierung mit `fileName`, `fileSize`, Beziehung
  `appStoreReviewDetail`) → PUT je `uploadOperations` (Byte-Bereiche, ohne JWT) → PATCH `uploaded=true`,
  `sourceFileChecksum` (MD5) → `assetDeliveryState` bis `COMPLETE`/`FAILED`; DELETE vor der Einreichung möglich
  ([App Store review attachments](https://developer.apple.com/documentation/appstoreconnectapi/app-store-review-attachments),
  [Uploading assets](https://developer.apple.com/documentation/appstoreconnectapi/uploading-assets-to-app-store-connect)).
- Bekannter Fallbericht: HTTP 500 beim POST eines Video-Anhangs, Notizen-PATCH lief
  ([Forum 776074](https://developer.apple.com/forums/thread/776074)). Dateitypen/Größenlimit nicht dokumentiert.
- Apple-Forenpraxis: Video als Anhang oder als Link in den Notizen, Antwort im Resolution Center.

## Dependencies
- Upstream: ASC-API, GitHub-Secrets, `openssl`.
- Downstream: keiner im Produkt. Die App wird nicht berührt; kein Pfad der Geräteliste.

## Existing Specs
- `docs/specs/feat-176-testflight-abnahme.md` (Beta-Seite, verwandt), keine Spec zur App-Store-Version.

## Risks & Considerations
- **Transport des Videos zur CI:** 64 MB, enthält Hennings echte Aufgabentitel, das Repo ist öffentlich. Nie ins Repo
  committen. Kandidaten: Entwurfs-Release (nur Mitarbeiter sehen es) als Zwischenablage, nach dem Lauf löschen; vorher
  verkleinern (ffmpeg). Alternative: öffentlicher Link in den Notizen (würde die Aufnahme veröffentlichen).
- Anhang-POST kann 500 liefern (Fallbericht) → Rückfallweg nötig.
- Version im Zustand nach „Information Needed“: ob Notes/Anhänge dort beschreibbar sind, erst der Lesebeleg zeigt es.
- Erneutes Einreichen (`reviewSubmissions`) ist nach außen gerichtet und nicht rücknehmbar → nicht in diesem Workflow.

## Analysis

### Type
Feature (Betriebsaufgabe: Angaben für App Review nachliefern; die App selbst wird nicht berührt)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_review_notes.py` | CREATE | Version 1.0 (iOS) finden, `appStoreReviewDetail` lesen; `lesen`: Zustand von Version, Notes (gesetzt/leer, Bytezahl) und Anhängen (Dateiname, Größe, `assetDeliveryState`); `notizen`: Notes nur bei Abweichung PATCHen (≤ 4000 Byte, Text aus dem Codeblock in `app-review-notizen.md`); `video`: Anhang reservieren (POST), Byte-Bereiche hochladen (PUT je `uploadOperations`, ohne JWT), bestätigen (PATCH `uploaded`, MD5), auf `COMPLETE`/`FAILED` warten; gleicher Dateiname schon `COMPLETE` = unverändert |
| `scripts/test_asc_review_notes.py` | CREATE | Fake-Antworten wie `test_asc_beta_setup.py`: Notes-Grenze in Byte, idempotenter PATCH, Upload-Teilstücke nach Offset/Länge, MD5, FAILED wird Fehler, kein Wert im Log |
| `.github/workflows/asc-review-notes.yml` | CREATE | Handlauf `workflow_dispatch`, `aktion` = lesen / notizen / video; holt das Video aus einem Entwurfs-Release (nur Repo-Mitarbeiter sehen es) und löscht dieses Release am Ende des Laufs |
| `docs/reference/app-review-notizen.md` | MODIFY | Platzhalter `<HIER_VIDEO_LINK>` → „attached to this submission“, Kopf auf neuen Stand |
| `docs/reference/testflight.md` | MODIFY | Handlauf und Beleg in der ASC-Tabelle |

### Scope Assessment
- Files: 5 (3 neu, 2 geändert)
- Estimated LoC: ~+320 / −5 — **über dem Limit von 250**
- Vorschlag Schnitt 1 (~150 LoC): `lesen` + `notizen` + Workflow + Doku. Schnitt 2 (~180 LoC): `video` samt Tests.
- Risk Level: LOW für das Produkt (kein App-Code, kein Pfad der Geräteliste); MEDIUM für den Ablauf (Anhang-POST kann 500
  liefern, Fallbericht Forum 776074; Dateitypen/Größenlimit undokumentiert)

### Technical Approach
Empfehlung: ASC-API über einen Handlauf in der CI, wie alle bisherigen ASC-Schritte (Schlüssel nur in den GitHub-Secrets).
Erst `lesen` (zeigt, ob die Version nach „Information Needed“ beschreibbar ist), dann `notizen`, dann `video`.
Video-Transport: Original-`.mov` (64 MB) als Asset eines Entwurfs-Release, mit `gh` hochgeladen, im Lauf geladen, danach samt
Release gelöscht; nie ins Repo. Unverändert hochladen (echte Geräteaufnahme ist Apples Forderung); nur wenn Apple `FAILED`
meldet, per ffmpeg nach MP4/H.264 umwandeln und erneut versuchen.
Neue Workflow-Dateien sind erst nach Merge auf `main` startbar (UI Smoke ~1,3 h je PR).

Alternative: Claude in Chrome trägt Notes ein und lädt das Video in der App-Store-Connect-Weboberfläche hoch (Hennings
Anmeldung im Browser). Kein Repo-Code, keine CI-Wartezeit, Video nie auf GitHub; dafür kein wiederholbarer Lauf, und die
Erweiterung war bei #742 nicht verbunden. Beleg danach trotzdem per Lesen (Schnitt 1 `lesen`).
Verworfen: öffentlicher Video-Link in den Notes (veröffentlicht Hennings echte Aufgabentitel).

### Dependencies
`asc_wait_build` (`read_config`, `make_token`, `get_json`, `find_app_id`, `Fatal`), `asc_what_to_test` (`send_json`,
`get_data`, `ATTEMPTS`), `asc_beta_probe` (`records`, `attributes`). Upstream ASC-API und die drei ASC-Secrets wie in
`asc-store-probe.yml`. Downstream keiner.

### Open Questions
- [x] Weg: Henning wählte 2026-11-01 „Zwei Schritte, automatisch“ → Schnitt 1 (`lesen` + `notizen`, Workflow, Doku),
  Schnitt 2 (`video`). Spec deckt zunächst Schnitt 1 ab.
- Erneutes Einreichen bleibt außerhalb dieses Workflows, nur nach Hennings Wort (DoD des Issues dafür offen lassen).
