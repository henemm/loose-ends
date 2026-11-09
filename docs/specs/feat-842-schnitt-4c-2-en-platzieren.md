---
entity_id: feat-842-schnitt-4c-2-en-platzieren
type: feature
created: 2026-11-09
updated: 2026-11-09
status: draft
workflow: feat-842-s4c2-platzieren
---

# Spec: #842 Schnitt 4c-2 — Englische Store-Bilder auf der Store-Seite platzieren, ordnen und gegenprüfen

## Approval

- [ ] Approved

Die englischen Bilder hat Henning in 4a und 4b freigegeben, den Umfang (ein Schritt, ca. 430 LoC) am 2026-11-09 per Auswahl „Ein Schritt (Empfohlen)“. Dieser Schnitt setzt die zwölf Bilder auf der englischen Store-Seite von 1.0.1 ein. Die Version ist noch nicht eingereicht, also nicht öffentlich. `approved` gibt die Umsetzung frei.

## Purpose

Seit Schnitt 4c-1 liegen die zwölf englischen Bilder (`en-iphone-…` 5, `en-ipad-…` 5, `en-watch-…` 2) unplatziert in Apples Asset-Bibliothek der App. Schnitt 4c-2 erweitert `scripts/asc_store_images.py` um die Aktion `platzieren`: Sie legt für jedes Bild eine Platzierung auf der Lokalisierung en-US der einzigen bearbeitbaren iOS-Version (1.0.1) an, ordnet jede Gruppe in der Manifest-Reihenfolge, wartet, bis Apple die Platzierungen verarbeitet hat, und prüft im selben Lauf gegen, dass die Store-Seite Namen und Reihenfolge des Manifests zeigt. Danach hat die englische Store-Seite von 1.0.1 Bilder für iPhone, iPad und Watch.

Für Henning ändert sich: Die englische Store-Seite von 1.0.1 zeigt fünf iPhone-, fünf iPad- und zwei Watch-Bilder in der gewohnten Reihenfolge. Die deutsche Seite bleibt unverändert, nichts wird eingereicht. Er muss nichts tun.

Das Platzieren ist der erste Schreibzugriff auf die echte Store-Seite. Eine Platzierung ist bei Apple unveränderlich; eine Korrektur geht nur durch Löschen und Neuanlegen. Dieser Schnitt löscht deshalb nie und prüft vor dem ersten Schreiben so streng, dass eine Fehlplatzierung gar nicht erst entsteht.

Nicht in diesem Schnitt:

- **Mac-Bilder:** keine bearbeitbare Mac-Version (nur 1.0, `READY_FOR_SALE`); der Mac bleibt mit `::warning::` aus, wie in 4c-1.
- **Einreichung von 1.0.1** und Kopfbild für en-US: Hennings Release-Entscheidung.
- **Löschen oder Austauschen von Platzierungen:** kein Löschweg in diesem Schnitt.
- **Produktcode:** keiner.

Ohne Modell geht es nicht: nicht relevant. Betriebsskript gegen die ASC-API, Regelweg.

## Source

- **File:** `scripts/asc_store_images.py`, `scripts/test_asc_store_images.py`, `scripts/asc_header_upload.py`, `scripts/test_asc_header_upload.py`, `.github/workflows/asc-store-images.yml` (alle bestehend)
- **Identifier:** neue Funktionen `platzieren(...)` und Hilfen in `asc_store_images.py`; `ACTIONS`; `upload(...)` (eigene Bereitschaftsprüfung); `lesen(...)` (Platzierungen); `Client.send` (Fehlercode); Eingabe `aktion` und Block `concurrency` im Workflow

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Client.api`, `Client.get`, `Client.post`, `REFDATA`, `IMAGES`, `wait_ready` (`scripts/asc_header_upload.py`) | Modul | Lesen und Schreiben gegen die ASC-API; `check_state` bleibt unverändert und gilt weiter für das Kopfbild |
| `app_versions`, `editable_version`, `localizations` (`scripts/asc_version_texts.py`) | Modul | genau eine bearbeitbare iOS-Version, Lokalisierungen `{locale: Datensatz mit id}`; unverändert |
| `ASC_LOCALES`, `Fatal`, `read_config`, `find_app_id` | Modul | Sprachcode → Locale, Fehlerklasse, Konfiguration; unverändert |
| `plan`, `preflight`, `screenshot_rules`, `GROUPS`, `warn_mac` (`scripts/asc_store_images.py`) | Modul | Plan aus dem Manifest, Gruppen und `maxCount`; werden wiederverwendet |
| `docs/store/screenshots/en/manifest.json` | Quelle | Reihenfolge der Dateien je Gerät = Store-Reihenfolge; nur gelesen |
| Apple: „Placing assets on your App Store surfaces“ (https://developer.apple.com/documentation/appstoreconnectapi/placing-assets-on-your-app-store-surfaces), Recherche 2026-11-09 | Quelle | Anlegen `POST /v1/appAssetLibraryPlacements` (`placementType` `APP_SCREENSHOT`, `placementGroup`, Relationen `image` und `appStoreVersionLocalization`); Ordnen `POST /v1/appAssetLibraryPlacementOrderingRequests` (`placementGroup`, `orderedPlacements`, `appStoreVersionLocalization`, je Gruppe einzeln); Lesen `GET /v1/appStoreVersionLocalizations/{id}/placements` mit `sort=placementGroupPosition`; Zustände `ASSET_PROCESSING` bis `PARENT_*`; Fehler 409 `ENTITY_ERROR.ATTRIBUTE.INVALID` und `STATE_ERROR.INVALID_STATE`; höchstens 10 Screenshots je Gruppe |
| Protokoll `docs/artifacts/feat-842-s4c-en-hochladen/run-42519049719-probe.log` | Beleg | Ist-Stand: en-US ohne Platzierung und ohne Bildsatz; de-DE 5 iPhone, 5 iPad, 2 Watch plus Kopf- und Suchbild im Zustand `ACTIVE`; Platzierungslisten tragen `placementGroup` und sind nach `placementGroupPosition` sortierbar |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_store_images.py | MODIFY | Aktion `platzieren` (nur `en`), Vorabprüfung, Anlegen, Ordnen, Warten, Gegenprobe; `lesen` zeigt en-US-Platzierungen je Gruppe; eigene Bereitschaftsprüfung in `upload` (ca. 130 LoC) |
| scripts/test_asc_store_images.py | MODIFY | `FakeClient` um Platzierungen je Lokalisierung, Anlegen, Ordnungsaufträge und Bildzuordnung erweitert; Tests je AC (ca. 300 LoC) |
| scripts/asc_header_upload.py | MODIFY | `Client.send` meldet bei HTTPError zusätzlich `errors[].code` (ca. 8 LoC) |
| scripts/test_asc_header_upload.py | MODIFY | ein Test für den Fehlercode (ca. 20 LoC) |
| .github/workflows/asc-store-images.yml | MODIFY | Option `platzieren`, `concurrency`-Gruppe ohne Abbruch, Kopfkommentar (ca. 6 LoC) |

Nicht betroffen (geprüft): `scripts/asc_version_texts.py`, `scripts/asc_store_probe.py` und ihre Tests, `docs/store/screenshots/`, `ci.yml`, Produktcode, `project.yml`, `CLAUDE.md`.

### Estimated Changes
- Dateien: **5** (Grenze 4–5 eingehalten).
- LoC: ca. **+460/−10** (Skripte ca. 144, Tests ca. 320; Henning nahm „ca. 430“ an), über der 250er-Grenze. Henning hat den Umfang am 2026-11-09 per AskUserQuestion angenommen (Ein Schritt, empfohlen). **Meldeschwelle: ca. 520 LoC**; darüber wird vor dem Weiterbauen erneut gefragt.
- Produktcode: keiner. Keine Berechtigung, keine `Info.plist`, kein Schema.
- „Kein Pfad der Geräteliste berührt.“

## Implementation Details

**1. Eingabe und Aktion.** `ACTIONS = ("lesen", "hochladen", "platzieren")`. `platzieren` ist nur mit `sprache=en` zulässig. Mit `de` endet `main` mit `::error::` und Ausgang 1, **ohne** einen Aufruf gegen Apple (Kleinbefund F002 aus 4c-1: de-DE wird nie geschrieben). `lesen` und `hochladen` akzeptieren weiter `de` und `en`.

**2. Vorabprüfung (nur GET).** Eine Funktion prüft alles, bevor die erste Platzierung angelegt wird. Jede gescheiterte Prüfung beendet den Lauf mit `Fatal` (`::error::`, Ausgang 1) und lässt die Aufrufliste ohne POST, PUT, PATCH, DELETE:
- genau eine bearbeitbare iOS-Version (`editable_version(app_versions(...), "IOS")`); keine oder mehrere → Abbruch;
- die Lokalisierung `en-US` gehört zu dieser Version; fehlt sie → Abbruch;
- jedes Bild des Plans (`en-iphone-…`, `en-ipad-…`, `en-watch-…`) steht in der Bibliothek im Zustand `PREPARE_FOR_SUBMISSION`; fehlt eines oder steht es in einem anderen Zustand → Abbruch mit Name und Zustand;
- Gruppe und `maxCount` aus den Referenzdaten (bestehende Prüfung aus `preflight`), und die Zahl der Platzierungen je Gruppe nach dem Lauf (vorhandene eigene plus fehlende) liegt unter oder bei `maxCount`; sonst Abbruch;
- der Bestand der en-US-Platzierungen je Gruppe (Punkt 3) enthält **nur** Bilder aus dem Plan und jedes höchstens einmal; eine fremde Platzierung (Bild nicht aus dem Plan, etwa von Hand gesetzt) oder eine Doppelplatzierung desselben Bildes → Abbruch, nichts wird überschrieben oder gelöscht.

**3. Zuordnung Platzierung → Bildname ohne `included`.** `Client.get` verwirft `included` und `relationships`; der Abgleich nutzt deshalb nur Antwortformen, die am echten Konto schon belegt sind. Je Gruppe: Liste der Lokalisierung `GET /v1/appStoreVersionLocalizations/{en-US-id}/placements?filter[placementType]=APP_SCREENSHOT&filter[placementGroup]=<gruppe>&sort=placementGroupPosition&limit=200` (Reihenfolge der Antwort = Anzeigereihenfolge; `limit` ausdrücklich gesetzt). Je Plan-Bild `GET /v1/appAssetLibraryImages/{id}/placements` (in 4c-1 `lesen` belegt). Die Schnittmenge der Platzierungs-IDs ordnet jede Platzierung ihrem Bildnamen zu. Eine Platzierung der Liste, die zu keinem Plan-Bild gehört, ist „fremd“ (Punkt 2).

**4. Anlegen.** Für jedes Plan-Bild ohne eigene Platzierung in seiner Gruppe: `POST /v1/appAssetLibraryPlacements` mit `placementType` `APP_SCREENSHOT`, `placementGroup` aus `GROUPS`, Relation `image` (das Bibliotheksbild) und Relation `appStoreVersionLocalization` (en-US). Reihenfolge der Aufrufe: Gruppe für Gruppe, in Manifest-Reihenfolge. Hat ein Bild schon eine eigene Platzierung, meldet der Lauf `platzierung <name> schon platziert, übersprungen`. Ein abgebrochener Lauf wird durch Wiederholen vervollständigt: es entsteht nur, was fehlt.

**5. Warten.** Nach dem Anlegen wird je Platzierung der `state` gelesen und gepollt (injiziertes `sleep`, `ASC_POLL_SECONDS` wie im Kopfbild-Upload, begrenzte Versuche). `ASSET_PROCESSING` = weiter warten; `ACTIVE` und `PARENT_*` (`PARENT_PREPARE_FOR_SUBMISSION` und die weiteren `PARENT_…`-Zustände) = gut; jeder andere Zustand → `Fatal` mit Bildname, Zustand und `stateDetails`. `ACTIVE` steht nicht in Apples Doku, ist aber der Zustand der de-DE-Platzierungen in der Store-Probe (Lauf 42519049719) und gilt deshalb als gut.

**6. Ordnen.** Je Gruppe wird die gelesene Reihenfolge (Punkt 3, Namen) mit der Manifest-Reihenfolge verglichen. Nur bei Abweichung folgt `POST /v1/appAssetLibraryPlacementOrderingRequests` mit `placementGroup`, `orderedPlacements` (Platzierungs-IDs in Manifest-Reihenfolge) und `appStoreVersionLocalization`, je Gruppe ein Auftrag. Stimmt die Reihenfolge, entsteht kein Ordnungsauftrag.

**7. Gegenprobe im selben Lauf.** Nach Anlegen, Warten und Ordnen liest der Lauf die Gruppen erneut (Punkt 3) und prüft je Gruppe: Namen und Reihenfolge = Manifest, Anzahl = 5 (iPhone), 5 (iPad), 2 (Watch). Abweichung → `Fatal` mit Gruppe, Soll und Ist. Zusätzlich liest der Lauf die Lokalisierung de-DE **nur** (GET) und meldet die Anzahl ihrer Platzierungen je Gruppe unverändert (5, 5, 2); de-DE wird nie beschrieben. Die Gegenprobe ersetzt nicht den Beleg durch die Store-Probe (AC-13).

**8. Bereitschaftsprüfung in `upload`.** `check_state` aus `asc_header_upload.py` verlangt „ohne Platzierung“ und bleibt für das Kopfbild unverändert streng. `upload` in `asc_store_images.py` bekommt eine eigene Prüfung „jedes Plan-Bild steht in der Bibliothek, Zustand `PREPARE_FOR_SUBMISSION`, Platzierung erlaubt“. Dadurch scheitert ein erneutes `hochladen en` nach dem Platzieren nicht fälschlich; ein fehlendes oder nicht bereites Bild bleibt ein Fehler.

**9. `lesen`.** Zusätzlich zu 4c-1 gibt `lesen` für `en` die en-US-Platzierungen je Gruppe mit Bildnamen in Anzeigereihenfolge aus (`platzierung <gruppe> <position> <bildname> zustand=<state>`), nur mit GET. Ist keine Platzierung vorhanden, steht `platzierung <gruppe> keine`.

**10. Fehlercode im Client.** `Client.send` in `asc_header_upload.py` hängt bei einem HTTPError die Codes aus `errors[].code` der Antwort an die Fehlermeldung. Es enthält weder Token noch die URL-Abfrage (Query); so ist ein 409 beim ersten Schreiben nicht blind (`ENTITY_ERROR.ATTRIBUTE.INVALID`, `STATE_ERROR.INVALID_STATE`).

**11. Workflow.** `aktion` bekommt die Option `platzieren`. Ein Block `concurrency: { group: asc-store-images, cancel-in-progress: false }` verhindert zwei gleichzeitige Läufe, die doppelt anlegen könnten (Kleinbefund F004 aus 4c-1), ohne einen laufenden Schreiblauf abzubrechen. Der Kopfkommentar nennt die neue Aktion und dass nie gelöscht und nie eingereicht wird. Der Auslöser `pull_request` bleibt (nur Tests, Registrierung für den Handlauf vom Zweig). Der Schritt gegen Apple ruft unverändert `scripts/asc_store_images.py "$AKTION" "$SPRACHE"` auf.

**12. Mac.** Unverändert: ohne bearbeitbare Mac-Version `::warning::keine bearbeitbare Mac-Version, Mac-Bilder nicht hochgeladen`; der Lauf bleibt grün.

**13. Ablauf am echten Konto (Nachweis vor dem Merge).** Vom Zweig aus, in dieser Reihenfolge, Protokolle unter `docs/artifacts/feat-842-s4c2-platzieren/`: (a) `gh workflow run asc-store-images.yml --ref <zweig> -f aktion=lesen -f sprache=en` (Bestand und Plan; en-US noch ohne Platzierung), (b) `aktion=platzieren -f sprache=en`, (c) `aktion=platzieren` ein zweites Mal (Idempotenz: nichts angelegt), (d) Workflow „ASC Store Probe“ (`asc-store-probe.yml`), (e) `aktion=hochladen` für `en` ein weiteres Mal (nichts angelegt, Bereitschaftsprüfung grün trotz Platzierungen). Erst danach Merge. Scheitert der Lauf vom Zweig, gilt der Rückfall aus 4c-1 (REST-Aufruf `POST /repos/{owner}/{repo}/actions/workflows/{datei}/dispatches` mit `ref`); ein Aufschub der Belege auf die Zeit nach dem Merge ist ausgeschlossen.

### Alternativen

| Weg | trägt? | Haken |
|---|---|---|
| **Bibliotheksplatzierung in einem Schnitt (gewählt)** | ja | ca. 430 LoC, über der Grenze, von Henning angenommen; Anlegen, Ordnen und Gegenprobe bilden zusammen den sichtbaren Nutzen |
| A Klassische `appScreenshotSets`/`appScreenshots` | ja, aber nicht empfohlen | lädt die Bilder ein zweites Mal hoch, lässt die 12 Bibliotheksbilder verwaist und weicht vom Weg der de-DE-Seite ab (dort Bibliotheksplatzierungen). Fällt: die Entscheidung „Bibliothek vor Platzierung“ aus der Spec 4c-1 (keine ADR-Nummer) |
| B Zwei Schnitte: 4c-2a Lesepfad, Fehlercode, Bereitschaftsprüfung (ca. 180 LoC); 4c-2b Anlegen, Ordnen, Gegenprobe (ca. 280 LoC) | ja | beide Hälften näher an der Grenze, aber die Schreibwege bleiben nach 2a unerprobt und Henning sieht nach 2a keinen Unterschied; der Hauptgrund (Form von `include` erst belegen) entfällt durch den Abgleich in Punkt 3. Von Henning abgelehnt (Ein Schritt) |
| C Henning platziert in App Store Connect selbst | nein | widerspricht „nie Arbeit an den PO“; verworfen |

Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_store_images.py` (`unittest`, ohne Netz), ausgenommen der Fehlercode-Test in `scripts/test_asc_header_upload.py`. Der bestehende `FakeClient` mit Zustand wird erweitert: Platzierungen je Lokalisierung (en-US und de-DE), `POST appAssetLibraryPlacements` (liefert ID und Zustand, zuerst `ASSET_PROCESSING`, dann `ACTIVE`), `POST …PlacementOrderingRequests` (setzt die Reihenfolge), `GET …/placements` je Lokalisierung (sortiert nach Position) und je Bibliotheksbild; Referenzdaten mit den echten Gruppennamen und `maxCount: 10`. RED: `platzieren` und die Attrappen-Erweiterung existieren noch nicht.

- [ ] `test_place_creates_all_in_manifest_order`: GIVEN die Bibliothek mit den 12 Bildern in `PREPARE_FOR_SUBMISSION`, en-US ohne Platzierung WHEN `platzieren en` läuft THEN gab es 12 `POST appAssetLibraryPlacements` (5 + 5 + 2) mit `APP_SCREENSHOT`, der festen Gruppe je Gerät, dem richtigen Bild und der Lokalisierung en-US; jede Gruppe steht danach in Manifest-Reihenfolge.
- [ ] `test_place_orders_only_on_difference`: GIVEN die Attrappe liefert die neuen Platzierungen in falscher Reihenfolge WHEN `platzieren en` läuft THEN gibt es je betroffener Gruppe genau einen Ordnungsauftrag mit den Platzierungs-IDs in Manifest-Reihenfolge, und die Gegenprobe ist grün. GIVEN die Reihenfolge stimmt schon THEN gibt es keinen Ordnungsauftrag.
- [ ] `test_second_run_places_nothing`: GIVEN die Platzierungen nach einem ersten Lauf WHEN `platzieren en` erneut läuft THEN gibt es keinen POST, jede Zeile meldet „schon platziert, übersprungen“.
- [ ] `test_resume_after_partial_run_places_only_missing`: GIVEN en-US trägt schon 3 der 5 iPhone-Platzierungen eigener Bilder WHEN `platzieren en` läuft THEN werden genau die fehlenden 2 plus iPad und Watch angelegt, keine doppelt.
- [ ] `test_foreign_placement_aborts_without_write`: GIVEN eine en-US-Gruppe trägt eine Platzierung eines Bildes, das nicht im Plan steht WHEN `platzieren en` läuft THEN `Fatal` mit Gruppe und Bildname und die Aufrufliste enthält kein Nicht-GET (kein POST, auch keines für andere Gruppen).
- [ ] `test_duplicate_placement_of_same_image_aborts`: GIVEN ein Plan-Bild ist zweimal in derselben en-US-Gruppe platziert WHEN `platzieren en` läuft THEN `Fatal` ohne Nicht-GET.
- [ ] `test_preflight_aborts_before_any_write`: GIVEN je einer der Fälle (keine bearbeitbare iOS-Version; zwei bearbeitbare; keine en-US-Lokalisierung; ein Plan-Bild fehlt in der Bibliothek; ein Plan-Bild in `AWAITING_UPLOAD`; Gruppe fehlt in den Referenzdaten; `maxCount` 4 bei 5 Bildern) WHEN `platzieren en` läuft THEN `Fatal` mit nennender Meldung und die Aufrufliste enthält kein Nicht-GET.
- [ ] `test_german_is_refused_without_any_call`: GIVEN `platzieren de` WHEN `main` läuft THEN Ausgang 1 mit `::error::`, ohne dass ein Client angelegt oder ein Aufruf abgesetzt wurde.
- [ ] `test_never_deletes_submits_or_writes_german`: GIVEN ein voller Lauf `platzieren en` (mit und ohne Ordnen, mit Wiederholung) WHEN die Aufrufliste geprüft wird THEN enthält sie kein `DELETE`, keinen Pfad mit Einreichung/`submission`, und jeder Schreibaufruf nennt die en-US-Lokalisierung, nie die de-DE-Lokalisierung; die de-DE-Platzierungen sind danach unverändert (5, 5, 2).
- [ ] `test_processing_waits_and_failure_is_an_error`: GIVEN die Attrappe meldet `ASSET_PROCESSING` einige Abfragen lang, dann `ACTIVE` THEN wartet der Lauf mit dem injizierten `sleep` und endet grün; GIVEN ein Zustand außerhalb von `ASSET_PROCESSING`/`ACTIVE`/`PARENT_*` (etwa `FAILED`) THEN `Fatal` mit Bildname und `stateDetails`.
- [ ] `test_verification_detects_wrong_order_or_count`: GIVEN die Attrappe liefert nach dem Ordnen weiterhin falsche Reihenfolge oder 4 statt 5 Platzierungen THEN `Fatal` mit Gruppe, Soll und Ist; bei richtigem Stand meldet der Lauf de-DE „5/5/2 unverändert“.
- [ ] `test_lesen_shows_en_placements_and_never_writes`: GIVEN en-US mit Platzierungen WHEN `lesen en` läuft THEN zeigt die Ausgabe je Gruppe Position, Bildname und Zustand in Anzeigereihenfolge (ohne Platzierungen `keine`), und die Aufrufliste besteht nur aus GET.
- [ ] `test_upload_ready_check_allows_placement`: GIVEN alle 12 Bilder bereit und platziert WHEN `hochladen en` läuft THEN gibt es keinen POST/PUT/PATCH und keinen Fehler; GIVEN ein Bild fehlt oder ist `AWAITING_UPLOAD` THEN weiter `Fatal`. Der bisherige `test_state_check_requires_ready_and_no_placement` wird auf die neue Prüfung umgestellt (Platzierung erlaubt, Zustand erforderlich); `check_state` des Kopfbilds bleibt in `test_asc_header_upload.py` streng und unverändert getestet.
- [ ] `test_workflow_offers_platzieren_and_serializes`: GIVEN die Workflow-Datei THEN enthält `aktion` die Option `platzieren`, es gibt ein `concurrency` mit `cancel-in-progress: false`, die Python-Tests laufen als erster Schritt, und der Schlüssel wird nie ausgegeben (Erweiterung von `test_workflow_runs_tests_first_and_hides_the_key`).
- [ ] `test_client_error_reports_api_code` (in `scripts/test_asc_header_upload.py`): GIVEN eine HTTP-409-Antwort mit `errors[].code` = `STATE_ERROR.INVALID_STATE` WHEN `Client.send` fehlschlägt THEN enthält der `Fatal`-Text den Code, aber weder das Token noch die URL-Abfrage.

## Acceptance Criteria

- **AC-1:** Given die Bibliothek mit den 12 Bildern `en-…` im Zustand `PREPARE_FOR_SUBMISSION` und en-US ohne Platzierung, When `platzieren en` läuft, Then legt das Skript genau 12 Platzierungen an (iPhone 5, iPad 5, Watch 2, `APP_SCREENSHOT`, feste Gruppe je Gerät, richtiges Bild, Ziel en-US), und jede Gruppe steht danach in Manifest-Reihenfolge. Belegt durch `test_place_creates_all_in_manifest_order`.
- **AC-2:** Given Platzierungen in abweichender Reihenfolge, When `platzieren en` läuft, Then entsteht je betroffener Gruppe genau ein Ordnungsauftrag mit den Platzierungs-IDs in Manifest-Reihenfolge; stimmt die Reihenfolge, entsteht keiner. Belegt durch `test_place_orders_only_on_difference`.
- **AC-3:** Given die Platzierungen eines ersten Laufs, When `platzieren en` erneut läuft, Then entsteht kein POST und jede Zeile meldet „schon platziert, übersprungen“; nach einem abgebrochenen Lauf legt die Wiederholung nur das Fehlende an, nichts doppelt. Belegt durch `test_second_run_places_nothing` und `test_resume_after_partial_run_places_only_missing`.
- **AC-4:** Given eine fremde Platzierung (Bild nicht aus dem Plan) oder eine Doppelplatzierung desselben Bildes in einer en-US-Gruppe, When `platzieren en` läuft, Then bricht es mit `::error::` und nennender Meldung ab, bevor ein Nicht-GET-Aufruf geschieht, und überschreibt oder löscht nichts. Belegt durch `test_foreign_placement_aborts_without_write` und `test_duplicate_placement_of_same_image_aborts`.
- **AC-5:** Given eine fehlende Voraussetzung (keine oder mehrere bearbeitbare iOS-Versionen, keine en-US-Lokalisierung, Plan-Bild fehlt oder nicht `PREPARE_FOR_SUBMISSION`, Gruppe fehlt in den Referenzdaten, mehr Bilder als `maxCount`), When `platzieren en` läuft, Then bricht es mit `::error::` und benennendem Grund ab, bevor ein Nicht-GET-Aufruf geschieht. Belegt durch `test_preflight_aborts_before_any_write`.
- **AC-6:** Given `platzieren` mit `sprache=de`, When das Skript startet, Then endet es mit `::error::` und Ausgang 1, ohne einen Aufruf gegen Apple. Belegt durch `test_german_is_refused_without_any_call`.
- **AC-7:** Given jeder Lauf von `platzieren en`, When die Aufrufliste geprüft wird, Then enthält sie nie `DELETE`, nie eine Einreichung und keinen Schreibaufruf auf de-DE; die de-DE-Platzierungen bleiben unverändert (5, 5, 2). Belegt durch `test_never_deletes_submits_or_writes_german`.
- **AC-8:** Given Platzierungen im Zustand `ASSET_PROCESSING`, When das Skript wartet, Then pollt es mit dem injizierten `sleep` bis `ACTIVE` oder `PARENT_*`; jeder andere Zustand endet als `Fatal` mit Bildname, Zustand und `stateDetails`. Belegt durch `test_processing_waits_and_failure_is_an_error`.
- **AC-9:** Given der Lauf hat angelegt und geordnet, When die Gegenprobe läuft, Then stimmen je Gruppe Namen, Reihenfolge und Anzahl (5, 5, 2) mit dem Manifest überein, sonst `Fatal` mit Gruppe, Soll und Ist; de-DE wird nur gelesen und mit unveränderter Anzahl gemeldet. Belegt durch `test_verification_detects_wrong_order_or_count`.
- **AC-10:** Given en-US mit Platzierungen, When `lesen en` läuft, Then zeigt die Ausgabe je Gruppe Position, Bildname und Zustand in Anzeigereihenfolge (ohne Platzierungen `keine`), und die Aufrufliste besteht nur aus GET. Belegt durch `test_lesen_shows_en_placements_and_never_writes`.
- **AC-11:** Given die 12 Bilder sind bereit und platziert, When `hochladen en` erneut läuft, Then legt es nichts an und meldet keinen Fehler wegen der Platzierungen; ein fehlendes oder nicht bereites Bild bleibt ein Fehler, und `check_state` des Kopfbilds bleibt streng. Belegt durch `test_upload_ready_check_allows_placement` und die unveränderten Tests in `scripts/test_asc_header_upload.py`.
- **AC-12:** Given die Änderungen an Client und Workflow, When `Client.send` an einem HTTP-Fehler scheitert, Then nennt die Meldung `errors[].code` ohne Token und ohne URL-Abfrage; die Workflow-Datei bietet die Option `platzieren`, trägt `concurrency` ohne `cancel-in-progress` und führt die Python-Tests als ersten Schritt aus. Belegt durch `test_client_error_reports_api_code` und `test_workflow_offers_platzieren_and_serializes`.
- **AC-13:** Given der Zweig ist im Remote und die Läufe aus Punkt 13 gehören zu dieser Fassung, When vom Zweig `lesen en`, `platzieren en`, `platzieren en` (zweites Mal), die Store-Probe und `hochladen en` laufen, Then besteht jeder Lauf; das erste `platzieren en` legt 12 Platzierungen an, das zweite nichts, die Store-Probe zeigt für en-US 5 iPhone, 5 iPad und 2 Watch in Manifest-Reihenfolge und für de-DE unverändert die bisherigen Platzierungen (5, 5, 2 plus Kopf- und Suchbild), und `hochladen en` meldet alle 12 „schon vorhanden, übersprungen“ ohne Fehler. Belegt durch die Run-IDs und die zitierten Protokollzeilen unter `docs/artifacts/feat-842-s4c2-platzieren/`; erst danach der Merge.
- **AC-14:** Given die Änderung berührt nur `scripts/` und `.github/workflows/`, When der Schnitt abgenommen wird, Then endet die Abnahme nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“; der „Benutzen“-Beleg sind die echten Handläufe aus AC-13 gegen Apple. Auf Hennings Geräten läuft nichts. `python3 -m unittest scripts/test_asc_store_images.py` und die übrigen Skript-Tests (`scripts/test_asc_header_upload.py`, `scripts/test_asc_version_texts.py`, `scripts/test_asc_store_probe.py`) sind grün. Belegt durch Dateiliste des Diffs gegen die Geräteliste und die Testläufe.

**Abnahmeweg.** Stufe 1: Python-Tests (AC-1 bis AC-12, AC-14). Stufe 2: die Handläufe vom Zweig aus (AC-13); sie sind zugleich der Beleg, weil das Ergebnis bei Apple liegt. Stufe 3 greift nicht; es gibt keine Nach-Merge-Punkte.

## Definition of Done

- [ ] Die Tests waren vor dem Skript vorhanden (RED) und sind danach grün; die übrigen Skript-Tests bleiben grün.
- [ ] Die Handläufe `lesen en`, `platzieren en`, `platzieren en` (zweites Mal), Store-Probe und `hochladen en` liefen vom Zweig aus; Run-IDs und zitierte Protokollzeilen stehen unter `docs/artifacts/feat-842-s4c2-platzieren/`.
- [ ] Die Store-Probe zeigt en-US mit 5 iPhone-, 5 iPad- und 2 Watch-Platzierungen in Manifest-Reihenfolge, de-DE unverändert.
- [ ] Der Umfang blieb unter der Meldeschwelle von ca. 520 LoC, sonst wurde vor dem Weiterbauen gefragt.
- [ ] PR gemergt, CI grün; #842 kommentiert: Schnitt 4c-2 erledigt, offen nur die Mac-Bilder (bis eine bearbeitbare Mac-Version existiert) und Hennings Entscheidung zur Einreichung von 1.0.1.

## Seiteneffekte

- Geänderte Dateien: die fünf oben; dazu die Belege unter `docs/artifacts/feat-842-s4c2-platzieren/`.
- Bei Apple: 12 Platzierungen auf der Lokalisierung en-US der Version 1.0.1 (noch nicht eingereicht); eventuell legt Apple dazu klassische Bildsätze an (bei de-DE erschienen sie, ob automatisch, ist undokumentiert; die Store-Probe zeigt es). Keine Einreichung, keine Löschung, de-DE unberührt.
- Platzierungen sind unveränderlich; eine Korrektur wäre nur Löschen und Neuanlegen, das dieser Schnitt nie ausführt.
- Keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.

## Risiken

- **Erster Schreibzugriff auf die echte Store-Seite.** Gegenmaßnahmen: strenge Vorabprüfung ohne Schreiben (Punkt 2), `lesen` vorab (Punkt 13), Wiederholbarkeit ohne Doppelanlage, nie Löschen. Die Version ist nicht eingereicht, die Seite also nicht öffentlich.
- **Antwortformen der Platzierungs-Endpunkte.** `POST appAssetLibraryPlacements` und die Ordnungsaufträge sind aus Apples Dokumentation erschlossen, nicht aus einem Lauf dieses Skripts. Gegenmaßnahme: die Attrappe folgt der dokumentierten Form; der Fehlercode im Client (Punkt 10) macht ein 409 sichtbar; scheitert die Form im echten Lauf, wird das Skript korrigiert und der Lauf wiederholt, nie die Attrappe angepasst, um grün zu werden.
- **Zustand `ACTIVE`.** Nicht in der Doku, aber in der Store-Probe belegt; gilt als gut. Ein unbekannter Zustand ist ein Fehler, nie ein stilles Weiterlaufen.
- **Automatische Bildsätze.** Ob Apple klassische Bildsätze mit anlegt, ist offen; es ändert die Gegenprobe nicht, die Store-Probe hält es fest.
- **Gleichzeitige Läufe.** `concurrency` ohne Abbruch serialisiert sie (F004 aus 4c-1).
- **Umfang.** Ca. 430 LoC angenommen; Meldeschwelle ca. 520 LoC.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebswerkzeug ohne Produktcode; es wird keine bestehende ADR gekippt (keine der Alternativen A bis C berührt eine ADR).
- **Rationale:** Das Platzieren setzt den in Spec 4c-1 gewählten Weg „Bibliothek vor Platzierung“ fort, so wie die de-DE-Seite aufgebaut ist; die Schnittentscheidung (ein Schritt statt zwei) ist eine technische Frage und von Henning angenommen.

## Changelog

- 2026-11-09: Initial spec created (Schnitt 4c-2 von #842: `platzieren` nur für `en`, Anlegen, Ordnen, Warten und Gegenprobe über Bibliotheksplatzierungen; Zuordnung ohne `included`; Vorabprüfung ohne Schreiben; Idempotenz; `lesen` mit Platzierungen; eigene Bereitschaftsprüfung in `upload`; Fehlercode im Client; `concurrency` im Workflow; Handläufe vom Zweig vor dem Merge)
