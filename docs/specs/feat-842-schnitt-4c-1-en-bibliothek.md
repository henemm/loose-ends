---
entity_id: feat-842-schnitt-4c-1-en-bibliothek
type: feature
created: 2026-11-08
updated: 2026-11-08
status: draft
workflow: feat-842-s4c-en-hochladen
---

# Spec: #842 Schnitt 4c-1 — Englische Store-Bilder lesen und in die Asset-Bibliothek bei Apple hochladen

## Approval

- [ ] Approved

Die englischen Bilder hat Henning in 4a und 4b freigegeben; dieser Schnitt legt sie nur in Apples Bibliothek und ändert keine Store-Seite. Henning muss nichts neu entscheiden; `approved` gibt die Umsetzung frei.

## Purpose

Die englische Store-Seite von 1.0.1 hat noch keine Bilder; die elf Bilder für iPhone, iPad und Watch liegen im Repo (`docs/store/screenshots/en/`). Schnitt 4c-1 baut das Werkzeug, das zuerst bei Apple nur nachliest (bearbeitbare iOS-Version, englische Lokalisierung, Bildgruppen, Bestand der Bibliothek) und dann die Bilder mit eindeutigen Namen in Apples Asset-Bibliothek der App hochlädt und auf deren Verarbeitung wartet. Er legt **keine Platzierung** an, reicht nichts ein, löscht nichts und fasst Deutsch nie an. Die Bilder sind danach bei Apple, aber auf keiner Store-Seite sichtbar: folgenlos und jederzeit wiederholbar.

Für Henning ändert sich: nichts, was er tun müsste. Die englische Store-Seite sieht danach noch genauso aus wie vorher; erst der Folgeschnitt setzt die Bilder dort ein.

Nicht in diesem Schnitt:

- **Platzieren, Ordnen und Gegenprobe der Store-Seite** ist Schnitt 4c-2 (eigener, späterer Workflow, eigene Spec). Hier gibt es dafür keine Aufrufe und keine Abnahmekriterien.
- **Mac-Bilder:** Es gibt keine bearbeitbare Mac-Version (nur 1.0 im Zustand `READY_FOR_SALE`, gesperrt). Der Lauf meldet das als `::warning::` und überspringt den Mac; er lädt die Mac-Bilder erst hoch, wenn eine bearbeitbare Mac-Version existiert.
- **Kopfbilder für en-US** und das Anlegen einer Mac-Version (Hennings Release-Entscheidung).

Ohne Modell geht es nicht: nicht relevant. Betriebsskript gegen die ASC-API, Regelweg.

## Source

- **File:** `scripts/asc_store_images.py` (neu), `scripts/test_asc_store_images.py` (neu), `.github/workflows/asc-store-images.yml` (neu)
- **Identifier:** `lesen(...)`, `upload(...)`, `plan(...)`, `main(argv)`, Job `images` (`workflow_dispatch.inputs.aktion`, `inputs.sprache`)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `Client`, `put_bytes`, `wait_ready`, `REFDATA`, `IMAGES` (`scripts/asc_header_upload.py`) | Modul | Bibliothekszugang (Anlegen `POST /v1/appAssetLibraryImages`, Bytes über `uploadOperations`, `PATCH uploaded: true`), Warten auf `PREPARE_FOR_SUBMISSION`; werden importiert, nicht kopiert und nicht verändert |
| `app_versions`, `localizations`, `editable_version` (`scripts/asc_version_texts.py`) | Modul | bearbeitbare iOS- und Mac-Version (genau eine `PREPARE_FOR_SUBMISSION`, sonst Meldung oder `Fatal`), Lokalisierungen der Version; unverändert |
| `ASC_LOCALES` (`scripts/asc_locales.py`) | Modul | Sprachcode → Locale (`en` → `en-US`); nur `de` und `en` zulässig |
| `read_config`, `find_app_id`, `Fatal` (`scripts/asc_wait_build.py`) | Modul | Konfiguration, App-Kennung, Fehlerklasse |
| `docs/store/screenshots/en/manifest.json` | Quelle | `geraete[]` mit `geraet`, `pixel`, `ordner`, `dateien` (Reihenfolge = Store-Reihenfolge); wird nur gelesen |
| `.github/workflows/asc-header-upload.yml` | Muster | Handlauf mit `aktion` und ASC-Secrets, Schlüsseldatei mit `trap` und `umask 077` |
| `scripts/test_asc_header_upload.py` | Muster | `FakeClient` mit Zustand, Prüfung „nie Platzierung, nie Einreichen“ |
| Bildgruppen aus dem Lauf der Store-Probe 42515431363 (2026-11-08) | Beleg | echte Namen `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE`, `IPAD_13_PROFILE`, `WATCH_SERIES_10_PROFILE`; die Fixtures der Store-Probe nennen veraltete Namen (`IPHONE_67`) und werden **nicht** übernommen |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/asc_store_images.py | CREATE | Aktionen `lesen` (nur GET) und `hochladen` (nur Bibliothek); Plan aus dem Manifest, Prüfungen vor dem ersten Schreiben, Namensschema, Überspringen vorhandener Namen (ca. 100 LoC) |
| scripts/test_asc_store_images.py | CREATE | `FakeClient`-Tests ohne Netz mit den echten Gruppennamen; Beweis „nie Platzierung, nie Einreichen, nie Löschen“, Idempotenz, Abbruch vor dem Schreiben (ca. 100 LoC) |
| .github/workflows/asc-store-images.yml | CREATE | `workflow_dispatch`, `aktion` (`lesen` Standard, `hochladen`), `sprache` (`en` Standard, `de`/`en`), Secrets wie Header-Upload, Python-Tests als erster Schritt (ca. 35 LoC) |

Nicht betroffen (geprüft): `scripts/asc_header_upload.py`, `scripts/asc_version_texts.py`, `scripts/asc_store_probe.py` und ihre Tests, `docs/store/screenshots/`, `docs/store/header/`, `ci.yml`, Produktcode, `project.yml`, `CLAUDE.md`.

### Estimated Changes
- Dateien: **3** (Grenze 4–5 eingehalten).
- LoC: ca. **+235/−0** (Skript 100, Tests 100, Workflow 35), unter der 250er-Grenze. Die Analyse schätzte ca. 200; die Spanne hängt an den Tests. Überschreitet die Umsetzung 250, wird vor dem Bauen geteilt, nicht gedehnt.
- Produktcode: keiner. Keine Berechtigung, keine `Info.plist`, kein Schema.

## Implementation Details

**1. Plan aus dem Manifest.** `plan(sprache)` liest `docs/store/screenshots/<sprache>/manifest.json` und erzeugt je Datei einen Eintrag mit Pfad, Gerät, Soll-Pixelmaß und `referenceName = <sprache>-<gerät>-<datei ohne .png>`, z. B. `en-iphone-01-start`. Der Sprachname im Namen hält die englischen und die deutschen Bilder in der app-weiten Bibliothek auseinander (beide heißen `01-start.png`). Die Gruppe je Gerät ist fest: iphone → `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE`, ipad → `IPAD_13_PROFILE`, watch → `WATCH_SERIES_10_PROFILE` (dieselben, die de-DE heute trägt). Mac steht nicht in der Tabelle der Gruppen; er wird über die Version geprüft (Punkt 3).

**2. Vorabprüfungen (beide Aktionen, vor jedem Schreiben).** Jede Prüfung, die scheitert, beendet `hochladen` mit `::error::` und Ausgang 1, **ohne** einen Schreibaufruf (kein POST, PUT, PATCH, DELETE):
- genau eine bearbeitbare iOS-Version über `editable_version(app_versions(...), "IOS")`; keine oder mehrere → Abbruch;
- die Lokalisierung der gewählten Sprache (`en-US`) gehört zu dieser Version (über `localizations`); fehlt sie → Abbruch;
- jede Datei des Plans existiert und hat laut `pixel` im Manifest das Maß des Geräts (Dateikopf des PNG gelesen, ohne Zusatzabhängigkeit); fehlende Datei oder falsches Maß → Abbruch;
- jede Gruppe des Plans steht in den Referenzdaten (`/v1/appAssetLibraryRefData/1`, `features[].placementPolicies[].groupLimits[]`) und die Zahl der Bilder des Geräts liegt unter oder bei `maxCount`; fehlende Gruppe oder zu viele Bilder → Abbruch. Die Form der Referenzdaten stammt aus dem echten Lauf `lesen`, nicht aus einer Vermutung (Lehre #842 S2).

**3. Mac.** `editable_version(versions, "MAC_OS")` liefert heute `None`. Dann gibt der Lauf `::warning::keine bearbeitbare Mac-Version, Mac-Bilder nicht hochgeladen` aus und lässt die vier Mac-Einträge aus dem Plan; der Lauf bleibt grün. Liefert die Funktion künftig eine Version, gehören die Mac-Bilder zum Plan (Gruppe aus den Referenzdaten, nicht geraten): bis dahin ist das nicht Teil dieses Schnitts und nicht abnahmepflichtig.

**4. `lesen` (nur GET).** Gibt aus: bearbeitbare iOS-Version samt Zustand, Vorhandensein der Lokalisierung, je Gruppe `vorhanden` und `maxCount`, Bestand der Bibliothek (Name, Zustand, Zahl der Platzierungen) und je Plan-Eintrag `vorhanden` oder `fehlt`, dazu die Mac-Meldung. `lesen` ruft nur `client.get`; das beweist ein Test über die Aufrufliste.

**5. `hochladen`.** Nach den Vorabprüfungen: `GET` der Bibliothek, vorhandene `referenceName` werden mit der Meldung `bild <name> schon vorhanden, übersprungen` übergangen (ein zweiter Lauf legt nichts doppelt an). Für jeden fehlenden Eintrag derselbe Ablauf wie im Kopfbild-Upload, über die vorhandenen Bausteine: `POST` auf die Bibliothek (mit `fileName`, `fileSize`, `category`, `referenceName`), Bytes über `put_bytes`, `PATCH uploaded: true`, `wait_ready`. Die `category` kommt aus den Referenzdaten für `APP_SCREENSHOT` (Platzierungstyp, akzeptierte Kategorie), nicht aus einer Konstante. Am Ende prüft ein Zustandscheck: jedes Bild des Plans steht in der Bibliothek mit Zustand `PREPARE_FOR_SUBMISSION` und **ohne** Platzierung; sonst `Fatal`. Das Skript enthält keinen Aufruf an `appAssetLibraryPlacements`, an Platzierungs-Ordnungsaufträge, an Einreichungen oder an `DELETE`.

**6. Workflow.** Auslöser `workflow_dispatch` und zusätzlich `pull_request` mit Pfadfilter auf die drei Dateien dieses Schnitts (Punkt 7); beim Auslöser `pull_request` laufen nur die Python-Tests, der Schritt gegen Apple hat `if: github.event_name == 'workflow_dispatch'` und braucht dort keine Secrets. `workflow_dispatch` mit `aktion` (choice `lesen`, `hochladen`, Standard `lesen`) und `sprache` (choice `en`, `de`, Standard `en`; das Skript lässt nur `de` und `en` zu und bricht sonst mit Meldung ab). Der erste Schritt führt `python3 -m unittest scripts/test_asc_store_images.py` aus; schlägt er fehl, läuft nichts gegen Apple. Danach der Schritt mit Schlüsseldatei (`trap`, `umask 077`) und `python3 scripts/asc_store_images.py "$AKTION" "$SPRACHE"` wie in `asc-header-upload.yml`. Schlüssel und Token werden nie ausgegeben.

**7. Handlauf vor dem Merge (entschieden).** Recherche 2026-11-08: Eine `workflow_dispatch`-Datei, die nur auf einem Zweig liegt, findet `gh workflow run` erst, wenn GitHub sie registriert hat („could not find any workflows“); registriert wird sie durch einen Lauf mit anderem Auslöser auf dem Zweig, danach führt `gh workflow run <Datei> --ref <zweig>` die Fassung des Zweigs aus (GitHub Community #25746, #198084; Classmethod-Bericht; GitHub-Doku „Manually running a workflow“, `--ref`). Deshalb trägt die Datei den Auslöser `pull_request` (Punkt 6): Das Öffnen des PR startet die Python-Tests, registriert die Datei, und die Handläufe der ACs 8 bis 10 laufen danach mit `--ref <zweig>` vor dem Merge. Keine zusätzliche Datei, kein Rumpf auf `main`. Scheitert der Lauf vom Zweig trotzdem, ist der Rückfall ein Aufruf der REST-Schnittstelle `POST /repos/{owner}/{repo}/actions/workflows/{datei}/dispatches` mit `ref`; ein Aufschub der Belege auf die Zeit nach dem Merge ist ausgeschlossen.

### Alternativen

| Weg | trägt? | Haken |
|---|---|---|
| **A Teilung: erst Bibliothek (4c-1), dann Platzieren (4c-2) (gewählt)** | ja | zwei Schnitte; dafür ist die Bibliotheksstufe folgenlos vorab belegt, Fehlplatzierungen (unveränderlich, nur löschen) sind erst im zweiten Schnitt möglich |
| B Ein Schnitt mit Upload und Platzieren (ca. 380 LoC) | ja | über der 250er-Grenze; Upload und Platzierung gemeinsam ungeprüft, ein Fehler in der Gruppe wirkt sofort auf die Store-Seite |
| C Henning lädt per Hand oder Claude Desktop hoch (wie #742) | ja | kostet seine Zeit, nicht wiederholbar, vorab nicht prüfbar; widerspricht „Henning bekommt nichts zu tun“ |
| D Klassischer Bildsatz-Weg (`appScreenshotSets`/`appScreenshots`) | nein | von Apple als überholt gekennzeichnet; würde die Bibliothek umgehen |
| E Gruppe aus den de-DE-Platzierungen lesen statt fest | nein | koppelt en an Hennings Handstand und bräuchte schon in diesem Schnitt Leseaufrufe auf Platzierungen; feste Zuordnung mit Prüfung gegen die Referenzdaten ist robuster |

Warum A: kleinster Schritt, der schon echten Nutzen belegt (Apple nimmt die Bilder an) und dabei die Store-Seite nicht berührt. Gekippt wird keine ADR.

## Test Plan

### Automated Tests (TDD RED)

Alle in `scripts/test_asc_store_images.py` (`unittest`, ohne Netz; `FakeClient` mit Zustand nach dem Muster von `test_asc_header_upload.py`, Referenzdaten mit den echten Gruppennamen und `groupLimits` mit `maxCount: 10`; Versions- und Lokalisierungsaufrufe werden dem Skript als Funktionen übergeben und im Test ersetzt). RED: das Skript existiert noch nicht.

- [ ] `test_plan_names_and_groups`: GIVEN das Manifest `en-US` WHEN `plan("en")` läuft THEN gibt es 11 Einträge (iPhone 5, iPad 5, Watch 2) mit Namen `en-iphone-01-start` bis `en-iphone-05-erledigt`, `en-ipad-…`, `en-watch-01-jetzt`, `en-watch-02-gespeichert`, den drei festen Gruppen und Pfaden unter `docs/store/screenshots/en/`; der Mac ist nicht im Plan.
- [ ] `test_read_only_never_writes`: GIVEN eine vollständige Attrappe WHEN `lesen` läuft THEN besteht die Aufrufliste nur aus GET, und die Ausgabe nennt Version, Lokalisierung, Gruppen mit `maxCount`, Bestand und die Mac-Meldung.
- [ ] `test_upload_creates_all_and_never_places`: GIVEN leere Bibliothek WHEN `hochladen` läuft THEN gab es je Plan-Eintrag POST, PUT und `PATCH uploaded: true`, alle Bilder stehen in `PREPARE_FOR_SUBMISSION`, die Aufrufliste enthält keinen Pfad mit `appAssetLibraryPlacements` oder `OrderingRequests`, keine Einreichung und kein `DELETE`.
- [ ] `test_second_run_creates_nothing`: GIVEN die Bibliothek nach einem ersten Lauf WHEN `hochladen` erneut läuft THEN gibt es keinen POST, PUT oder PATCH; jede Zeile meldet „schon vorhanden, übersprungen“.
- [ ] `test_existing_names_of_other_language_are_untouched`: GIVEN die Bibliothek enthält `01-start` und `de-iphone-01-start` WHEN `hochladen` mit `en` läuft THEN werden diese nicht verändert und neue Namen beginnen mit `en-`.
- [ ] `test_aborts_before_any_write`: GIVEN je einer der Fälle (keine bearbeitbare iOS-Version; zwei bearbeitbare; keine en-US-Lokalisierung; Gruppe fehlt in den Referenzdaten; Gruppe mit `maxCount` 4 bei 5 Bildern; Bilddatei fehlt; Pixelmaß der Datei weicht vom Manifest ab) WHEN `hochladen` läuft THEN `Fatal` mit nennender Meldung und die Aufrufliste enthält kein Nicht-GET.
- [ ] `test_mac_without_editable_version_is_skipped_with_warning`: GIVEN `editable_version(…, "MAC_OS")` liefert `None` WHEN `hochladen` läuft THEN steht `::warning::` mit Mac-Hinweis in der Ausgabe, kein Mac-Bild wird angelegt und der Lauf endet erfolgreich.
- [ ] `test_failed_processing_is_an_error`: GIVEN die Attrappe lässt ein Bild nach dem Upload `FAILED` melden WHEN `hochladen` läuft THEN `Fatal` mit Bildname und `stateDetails`.
- [ ] `test_state_check_requires_ready_and_no_placement`: GIVEN ein Bild des Plans in `AWAITING_UPLOAD` oder mit einer Platzierung THEN meldet der Zustandscheck einen Fehler; nur wenn alle bereit und unplatziert sind, „bereit“.
- [ ] `test_language_input_is_checked`: GIVEN `sprache` = `fr` WHEN das Skript startet THEN endet es mit Ausgang 2 und Meldung, ohne einen Aufruf.

## Acceptance Criteria

- **AC-1:** Given das Manifest `docs/store/screenshots/en/manifest.json`, When `plan("en")` läuft, Then entstehen 11 Einträge mit `referenceName` `en-<gerät>-<datei ohne .png>` (iPhone 5, iPad 5, Watch 2, Mac nicht enthalten) und den festen Gruppen `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE`, `IPAD_13_PROFILE`, `WATCH_SERIES_10_PROFILE`. Belegt durch `test_plan_names_and_groups` (rot vor, grün nach der Umsetzung).
- **AC-2:** Given eine Attrappe in Apples Form, When `lesen` läuft, Then besteht die Aufrufliste nur aus GET und die Ausgabe nennt bearbeitbare iOS-Version, Lokalisierung en-US, Gruppen mit `maxCount`, Bestand mit Namen und Zuständen, je Plan-Eintrag `vorhanden`/`fehlt` und die Mac-Meldung. Belegt durch `test_read_only_never_writes`.
- **AC-3:** Given eine leere Bibliothek, When `hochladen` läuft, Then wird jedes Bild des Plans angelegt, hochgeladen, mit `uploaded: true` bestätigt und steht in `PREPARE_FOR_SUBMISSION`, und die Aufrufliste enthält **keinen** Aufruf an Platzierungen, Ordnungsaufträge oder Einreichung und **kein** `DELETE`. Belegt durch `test_upload_creates_all_and_never_places`.
- **AC-4:** Given die Bibliothek nach einem ersten Lauf (auch mit Bildern anderer Sprache), When `hochladen` erneut läuft, Then entsteht kein POST, PUT oder PATCH und fremde Namen bleiben unberührt. Belegt durch `test_second_run_creates_nothing` und `test_existing_names_of_other_language_are_untouched`.
- **AC-5:** Given eine der Voraussetzungen fehlt (keine oder mehrere bearbeitbare iOS-Versionen, keine en-US-Lokalisierung, Gruppe fehlt, mehr Bilder als `maxCount`, Datei fehlt, Pixelmaß weicht vom Manifest ab), When `hochladen` läuft, Then bricht es mit `::error::` und benennendem Grund ab, **bevor** ein Nicht-GET-Aufruf geschieht. Belegt durch `test_aborts_before_any_write` (alle sieben Fälle).
- **AC-6:** Given keine bearbeitbare Mac-Version, When `hochladen` läuft, Then steht eine `::warning::`-Zeile zum Mac in der Ausgabe, es wird kein Mac-Bild angelegt, und der Lauf endet erfolgreich. Belegt durch `test_mac_without_editable_version_is_skipped_with_warning`.
- **AC-7:** Given eine Bildverarbeitung bei Apple, die `FAILED` meldet, oder ein Bild des Plans in anderem Zustand als `PREPARE_FOR_SUBMISSION` oder mit Platzierung, When `hochladen` endet, Then meldet das Skript `Fatal` mit Bildname und Grund; „bereit“ nur bei allen Bildern bereit und unplatziert. Belegt durch `test_failed_processing_is_an_error` und `test_state_check_requires_ready_and_no_placement`; eine andere Sprache als `de`/`en` wird ohne Aufruf abgelehnt (`test_language_input_is_checked`); die Workflow-Datei führt die Python-Tests als ersten Schritt aus und gibt den Schlüssel nie aus (Lesen der Datei im Diff).
- **AC-8:** Given der Zweig ist im Remote und die Datei `asc-store-images.yml` liegt dort, When `gh workflow run asc-store-images.yml --ref <zweig> -f aktion=lesen` läuft, Then besteht der Lauf (Python-Tests grün), das Protokoll nennt die eine bearbeitbare iOS-Version 1.0.1, die en-US-Lokalisierung, die drei Gruppen mit `maxCount` und die Mac-Warnung, und die Bibliothek enthält noch keine Bilder mit Namen `en-…` (`fehlt` für alle 11). Belegt durch die Run-ID und das Protokoll im Abnahmebericht (vor dem Merge).
- **AC-9:** Given AC-8 ist belegt, When `gh workflow run asc-store-images.yml --ref <zweig> -f aktion=hochladen` läuft und danach `aktion=lesen` erneut, Then besteht der Lauf, und der erneute `lesen`-Lauf zeigt 11 Bibliotheksbilder `en-*` (iPhone 5, iPad 5, Watch 2) im Zustand `PREPARE_FOR_SUBMISSION` mit `platzierungen=0`; ein dritter `hochladen`-Lauf meldet für alle 11 „schon vorhanden, übersprungen“. Belegt durch die drei Run-IDs und die Protokollzeilen. Hinweis: Die Analyse spricht von 12 Bildern; es sind 11 (5 + 5 + 2). Die Bibliothek enthält danach zusätzlich die vorhandenen Bilder (Kopfbilder, deutsche Bilder), die unberührt bleiben.
- **AC-10:** Given die Läufe aus AC-9, When der Workflow „ASC Store Probe“ (`asc-store-probe.yml`) danach läuft, Then zeigt er für en-US weiterhin `platzierung keine` und `bildsatz keine` und für de-DE unverändert die bisherigen Platzierungen und Bildsätze: der Schnitt ist für die Store-Seite folgenlos. Belegt durch die Run-ID und die Protokollzeilen von en-US und de-DE.
- **AC-11:** Given die Änderung berührt nur `scripts/` und `.github/workflows/`, When der Schnitt abgenommen wird, Then endet die Abnahme nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“; der „Benutzen“-Beleg sind die echten Handläufe der ACs 8 bis 10 gegen Apple. Auf Hennings Geräten läuft nichts. `python3 -m unittest scripts/test_asc_store_images.py` und die übrigen Skript-Tests (`scripts/test_asc_header_upload.py`, `scripts/test_asc_version_texts.py`, `scripts/test_asc_store_probe.py`) sind grün. Belegt durch Dateiliste des Diffs gegen die Geräteliste und die Testläufe.

**Abnahmeweg.** Stufe 1: Python-Tests (AC-1 bis AC-7, AC-11). Stufe 2: die Handläufe vom Zweig aus (AC-8 bis AC-10), sie sind zugleich der Beleg, weil das Ergebnis bei Apple liegt. Stufe 3 greift nicht; es gibt keine Nach-Merge-Punkte.

## Definition of Done

- [ ] Die Tests in `scripts/test_asc_store_images.py` waren vor dem Skript vorhanden (RED) und sind danach grün; die übrigen Skript-Tests bleiben grün.
- [ ] Die Handläufe `lesen`, `hochladen`, erneutes `lesen`, zweites `hochladen` und die Store-Probe liefen vom Zweig aus; Run-IDs und die zitierten Protokollzeilen stehen im Abnahmebericht (`docs/artifacts/feat-842-s4c-en-hochladen/`).
- [ ] Die Store-Probe zeigt en-US weiterhin ohne Platzierung und ohne Bildsatz.
- [ ] PR gemergt, CI grün; #842 kommentiert: Schnitt 4c-1 erledigt, offen 4c-2 (Platzieren, Ordnen, Gegenprobe) und die Mac-Bilder.

## Seiteneffekte

- Geänderte Dateien: die drei oben; dazu der Abnahmebericht unter `docs/artifacts/feat-842-s4c-en-hochladen/`.
- Bei Apple: nur Bilder in der Asset-Bibliothek der App (11 Stück, Namen `en-…`); keine Platzierung, keine Einreichung, keine Löschung, de-DE unberührt. Die Bilder bleiben in der Bibliothek, bis jemand sie löscht; das ist unschädlich, solange nichts sie platziert.
- Keine neuen Berechtigungen, keine `Info.plist`, keine `project.yml`-Änderung, keine AppStorage-Schlüssel, keine Audio-Dateien, keine neuen Dependencies, kein Produktcode.

## Risiken

- **Antwortform der Referenzdaten.** Pfade und Feldnamen (`groupLimits`, `maxCount`, Kategorie für `APP_SCREENSHOT`) sind aus Apples Dokumentation und dem Lauf der Store-Probe erschlossen, nicht aus einem Lauf dieses Skripts. Gegenmaßnahme: `lesen` zuerst (AC-8) und die Testattrappe in der belegten Form; scheitert die Form im echten Lauf, wird das Skript korrigiert und der Lauf wiederholt, nie die Attrappe angepasst, um grün zu werden.
- **Namenskollision.** Die Bibliothek ist app-weit; das Sprachpräfix im Namen verhindert, dass `01-start` der deutschen Bilder mit den englischen kollidiert.
- **Doppellauf.** Bricht ein Lauf nach dem Anlegen und vor dem Bestätigen ab, bleibt ein Bild in `AWAITING_UPLOAD`; der nächste Lauf überspringt den Namen und der Zustandscheck meldet es als Fehler. Gegenmaßnahme: das Bild wird als Ausnahmefall im Abnahmebericht benannt; ein Löschweg gehört nicht in diesen Schnitt.
- **Lauf vom Zweig.** Siehe Implementation Details, Punkt 7.
- **Umfang.** Die Schätzung liegt mit ca. 235 LoC nahe an der Grenze; Zuwachs wird geteilt, nicht gedehnt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Betriebswerkzeug ohne Produktcode; es wird keine bestehende ADR gekippt (keine der Alternativen B bis E berührt eine ADR).
- **Rationale:** Die Aufteilung in Bibliothek und Platzierung ist eine technische Schnittentscheidung, kein Architekturentscheid; der Upload folgt dem Muster des Kopfbild-Uploads (#772).

## Changelog

- 2026-11-08: Initial spec created (Schnitt 4c-1 von #842: `asc_store_images.py` mit `lesen` und `hochladen` in die Asset-Bibliothek, Namensschema `<sprache>-<gerät>-<datei>`, Prüfungen vor dem ersten Schreiben, Mac mit Warnung übersprungen, Handläufe vom Zweig aus; Platzieren ist 4c-2)
