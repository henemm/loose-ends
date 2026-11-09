# Adversary Dialog — feat-842-s4c2-platzieren
Spec: docs/specs/feat-842-schnitt-4c-2-en-platzieren.md
Datum: 2026-11-09 08:07

## Checkliste
- [x] **AC-1:** Given die Bibliothek mit den 12 Bildern `en-…` im Zustand `PREPARE_FOR_SUBMISSION` und en-US ohne Platzierung, When `platzieren en` läuft, Then legt das Skript genau 12 Platzierungen an (iPhone 5, iPad 5, Watch 2, `APP_SCREENSHOT`, feste Gruppe je Gerät, richtiges Bild, Ziel en-US), und jede Gruppe steht danach in Manifest-Reihenfolge. Belegt durch `test_place_creates_all_in_manifest_order`.
- [x] **AC-2:** Given Platzierungen in abweichender Reihenfolge, When `platzieren en` läuft, Then entsteht je betroffener Gruppe genau ein Ordnungsauftrag mit den Platzierungs-IDs in Manifest-Reihenfolge; stimmt die Reihenfolge, entsteht keiner. Belegt durch `test_place_orders_only_on_difference`.
- [x] **AC-3:** Given die Platzierungen eines ersten Laufs, When `platzieren en` erneut läuft, Then entsteht kein POST und jede Zeile meldet „schon platziert, übersprungen“; nach einem abgebrochenen Lauf legt die Wiederholung nur das Fehlende an, nichts doppelt. Belegt durch `test_second_run_places_nothing` und `test_resume_after_partial_run_places_only_missing`.
- [x] **AC-4:** Given eine fremde Platzierung (Bild nicht aus dem Plan) oder eine Doppelplatzierung desselben Bildes in einer en-US-Gruppe, When `platzieren en` läuft, Then bricht es mit `::error::` und nennender Meldung ab, bevor ein Nicht-GET-Aufruf geschieht, und überschreibt oder löscht nichts. Belegt durch `test_foreign_placement_aborts_without_write` und `test_duplicate_placement_of_same_image_aborts`.
- [x] **AC-5:** Given eine fehlende Voraussetzung (keine oder mehrere bearbeitbare iOS-Versionen, keine en-US-Lokalisierung, Plan-Bild fehlt oder nicht `PREPARE_FOR_SUBMISSION`, Gruppe fehlt in den Referenzdaten, mehr Bilder als `maxCount`), When `platzieren en` läuft, Then bricht es mit `::error::` und benennendem Grund ab, bevor ein Nicht-GET-Aufruf geschieht. Belegt durch `test_preflight_aborts_before_any_write`.
- [x] **AC-6:** Given `platzieren` mit `sprache=de`, When das Skript startet, Then endet es mit `::error::` und Ausgang 1, ohne einen Aufruf gegen Apple. Belegt durch `test_german_is_refused_without_any_call`.
- [x] **AC-7:** Given jeder Lauf von `platzieren en`, When die Aufrufliste geprüft wird, Then enthält sie nie `DELETE`, nie eine Einreichung und keinen Schreibaufruf auf de-DE; die de-DE-Platzierungen bleiben unverändert (5, 5, 2). Belegt durch `test_never_deletes_submits_or_writes_german`.
- [x] **AC-8:** Given Platzierungen im Zustand `ASSET_PROCESSING`, When das Skript wartet, Then pollt es mit dem injizierten `sleep` bis `ACTIVE` oder `PARENT_*`; jeder andere Zustand endet als `Fatal` mit Bildname, Zustand und `stateDetails`. Belegt durch `test_processing_waits_and_failure_is_an_error`.
- [x] **AC-9:** Given der Lauf hat angelegt und geordnet, When die Gegenprobe läuft, Then stimmen je Gruppe Namen, Reihenfolge und Anzahl (5, 5, 2) mit dem Manifest überein, sonst `Fatal` mit Gruppe, Soll und Ist; de-DE wird nur gelesen und mit unveränderter Anzahl gemeldet. Belegt durch `test_verification_detects_wrong_order_or_count`.
- [x] **AC-10:** Given en-US mit Platzierungen, When `lesen en` läuft, Then zeigt die Ausgabe je Gruppe Position, Bildname und Zustand in Anzeigereihenfolge (ohne Platzierungen `keine`), und die Aufrufliste besteht nur aus GET. Belegt durch `test_lesen_shows_en_placements_and_never_writes`.
- [x] **AC-11:** Given die 12 Bilder sind bereit und platziert, When `hochladen en` erneut läuft, Then legt es nichts an und meldet keinen Fehler wegen der Platzierungen; ein fehlendes oder nicht bereites Bild bleibt ein Fehler, und `check_state` des Kopfbilds bleibt streng. Belegt durch `test_upload_ready_check_allows_placement` und die unveränderten Tests in `scripts/test_asc_header_upload.py`.
- [x] **AC-12:** Given die Änderungen an Client und Workflow, When `Client.send` an einem HTTP-Fehler scheitert, Then nennt die Meldung `errors[].code` ohne Token und ohne URL-Abfrage; die Workflow-Datei bietet die Option `platzieren`, trägt `concurrency` ohne `cancel-in-progress` und führt die Python-Tests als ersten Schritt aus. Belegt durch `test_client_error_reports_api_code` und `test_workflow_offers_platzieren_and_serializes`.
- [x] **AC-13:** Given der Zweig ist im Remote und die Läufe aus Punkt 13 gehören zu dieser Fassung, When vom Zweig `lesen en`, `platzieren en`, `platzieren en` (zweites Mal), die Store-Probe und `hochladen en` laufen, Then besteht jeder Lauf; das erste `platzieren en` legt 12 Platzierungen an, das zweite nichts, die Store-Probe zeigt für en-US 5 iPhone, 5 iPad und 2 Watch in Manifest-Reihenfolge und für de-DE unverändert die bisherigen Platzierungen (5, 5, 2 plus Kopf- und Suchbild), und `hochladen en` meldet alle 12 „schon vorhanden, übersprungen“ ohne Fehler. Belegt durch die Run-IDs und die zitierten Protokollzeilen unter `docs/artifacts/feat-842-s4c2-platzieren/`; erst danach der Merge.
- [x] **AC-14:** Given die Änderung berührt nur `scripts/` und `.github/workflows/`, When der Schnitt abgenommen wird, Then endet die Abnahme nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“; der „Benutzen“-Beleg sind die echten Handläufe aus AC-13 gegen Apple. Auf Hennings Geräten läuft nichts. `python3 -m unittest scripts/test_asc_store_images.py` und die übrigen Skript-Tests (`scripts/test_asc_header_upload.py`, `scripts/test_asc_version_texts.py`, `scripts/test_asc_store_probe.py`) sind grün. Belegt durch Dateiliste des Diffs gegen die Geräteliste und die Testläufe.

## Dialog

### Runde 1
**Adversary:**
Tests selbst gelaufen: 76 Tests (store_images, header_upload, version_texts, store_probe), OK, 0 Fehler, 0 uebersprungen (docs/artifacts/feat-842-s4c2-platzieren/adversary-test-output.txt).
Erwartung aus der Spec abgeleitet, dann Code gelesen. Schreibpfade in platzieren: erst preflight (GET), assetLibrary (GET), ready_images (GET), owners (GET), read_group (GET), check_existing, german_counts (GET); der erste POST steht in create_missing. Kein Schreibaufruf davor. Alle POSTs in create_missing und order_groups tragen loc_id der en-US-Lokalisierung; de-DE kommt nur in german_counts (GET) vor. main weist platzieren de vor read_config zurueck (Ausgang 1, ::error::). Der Quelltext enthaelt weder DELETE noch Submission. Doppelanlage: Bestand wird je Gruppe vor dem Anlegen gelesen, Vorhandenes uebersprungen; fremde und doppelte Platzierungen brechen vor dem ersten POST ab. Unbekannter Zustand: wait_placements wirft Fatal mit Name, Zustand, stateDetails. Greift die Ordnung bei Apple nicht, endet verify als Fatal (Soll/Ist). check_state in asc_header_upload.py ist im Diff unveraendert; upload nutzt jetzt ready_images (Platzierung erlaubt, Zustand Pflicht). Client.send haengt nur errors[].code an, Query und Token bleiben draussen (Test mit TOKEN-SECRET und geheim-abfrage).
Eigene Sonde: error_codes mit errors=5 gibt TypeError (F001); null-Code, Nicht-UTF-8, Liste und mehrere Codes liefern leer beziehungsweise A, B.
Weitere Randfaelle: order_groups sortiert found (Namen oder None) und wirft TypeError statt Fatal bei verzoegerter Bildzuordnung (F002). verify liest unmittelbar nach dem Ordnungsauftrag ohne Warten (F003). Die concurrency-Gruppe gilt auch fuer pull_request-Laeufe, GitHub ersetzt einen wartenden Lauf durch den neueren (F004).
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:**
Gegenprobe gegen Fruehuebereinstimmung: jeden AC an Test und Codepfad festgemacht (siehe Bestaetigungen). AC-1 test_place_creates_all_in_manifest_order zu create_missing. AC-2 test_place_orders_only_on_difference zu order_groups. AC-3 test_second_run_places_nothing und test_resume_after_partial_run_places_only_missing zu placed-Abgleich. AC-4 Foreign/Duplicate-Tests zu check_existing. AC-5 test_preflight_aborts_before_any_write (sieben Faelle) zu preflight/ready_images. AC-6 test_german_is_refused_without_any_call zu main. AC-7 test_never_deletes_submits_or_writes_german. AC-8 test_processing_waits_and_failure_is_an_error zu wait_placements (POLLS begrenzt). AC-9 test_verification_detects_wrong_order_or_count zu verify. AC-10 test_lesen_shows_en_placements_and_never_writes. AC-11 test_upload_ready_check_allows_placement. AC-12 test_client_error_reports_api_code und test_workflow_offers_platzieren_and_serializes.
Lueckenpruefung: Ein Plan-Bild, von Hand in einer anderen, nicht gelesenen Gruppe von en-US platziert, wird nicht erkannt (nur die drei Plan-Gruppen werden gelesen); folgenlos. Der Abruf der Bibliothek ohne id wirft KeyError statt Fatal (wie in lesen/upload).
AC-13 ist vor dem Commit nicht belegbar und bleibt offen. Antwortformen von POST Placements, Ordnungsauftrag, filter[placementGroup] und das Attribut state einer Platzierung sind nur aus der Doku erschlossen; nur die echten Laeufe beweisen sie.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 3
**Adversary:**
AC-13 nachgeprueft an den sechs Protokollen unter docs/artifacts/feat-842-s4c2-platzieren/ per grep. Alle sechs Checkout-Zeilen holen 6de7ffd753b3b27bcf7a42e640cf5b0bd31f796d; der Arbeitsbaum steht auf 6de7ffd, `git diff 6de7ffd -- scripts .github` ist leer, die gestempelten Dateien sind also der gelaufene Stand. In keinem Protokoll steht ::error.
(a) lesen en (run-42578396652): Script tests Ran 26 tests; drei Zeilen "platzierung <gruppe> keine".
(b) platzieren en (run-42578487958): 12 Zeilen "angelegt"; gegenprobe 5/5/2 "in Manifest-Reihenfolge"; "de-DE 5/5/2 unverändert"; keine Zeile "geordnet" (kein Ordnungsauftrag noetig).
(c) platzieren zum zweiten Mal (run-42578601898): 12 mal "schon platziert", 0 mal "angelegt", gegenprobe gruen, de-DE 5/5/2 unveraendert.
(d) Store-Probe (run-42578684646): en-US 1.0.1 hat 12 Platzierungen ACTIVE (IPHONE 5, IPAD 5, WATCH 2) plus Bildsaetze APP_IPHONE_61 5, APP_WATCH_SERIES_10 2, APP_IPAD_PRO_3GEN_129 5; de-DE 1.0.1 weiter 5 iPhone, 5 iPad, 2 Watch ACTIVE plus PRODUCT_PAGE_HEADER_ASSET und APP_STORE_SEARCH_RESULTS_ASSET, Bildsaetze 5/5/2; de-DE 1.0 (iOS und Mac) unberuehrt.
(e) hochladen en (run-42578688175): 12 mal "schon vorhanden, übersprungen", keine Zeile "hochgeladen" ausser der Mac-Warnung, "zustand bereit".
Zusatz lesen2 (run-42578765781): Namen in Anzeigereihenfolge iPhone 01-start bis 05-erledigt, iPad 01 bis 05, Watch 01-jetzt, 02-gespeichert, alle ACTIVE; belegt die Manifest-Reihenfolge nach Namen.
Damit sind die in Runde 2 offenen Antwortformen (POST Placements, filter[placementGroup], Attribut state, Zuordnung ueber Bildplatzierungen) am echten Konto bestaetigt. F003 neu bewertet: Der Ordnungspfad lief am echten Konto nicht (Apple legte schon in Manifest-Reihenfolge an), ist also nur durch die Attrappe belegt; Apples Artikel empfiehlt das sofortige Zuruecklesen mit sort=placementGroupPosition, wie verify es tut. F003 bleibt LOW. Ergebnis: AC-13 bewiesen, kein neuer Befund.
**Implementierer:** (nicht beteiligt, Kontextisolation)

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_header_upload.py:149
  Description: error_codes iteriert errors ohne Typpruefung; bei errors=5 entsteht ein unbehandelter TypeError, die Fatal-Meldung mit HTTP-Status geht verloren.
  Spec requirement: AC-12 — Fehlercode in der Meldung, ohne Token und Query
  Conflict: Apple liefert diese Form nicht, der Fall ist hypothetisch.
  Remediation: errors nur verwenden, wenn es eine Liste ist.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_images.py:260
  Description: order_groups ruft sorted(found) auf; found kann None enthalten (Platzierung noch nicht in der Bildliste), dann TypeError statt Fatal.
  Spec requirement: AC-9 — Abweichung endet als Fatal mit Gruppe, Soll und Ist
  Conflict: Bei verzoegerter Zuordnung stirbt der Lauf mit Traceback; Wiederholung ist idempotent.
  Remediation: Namen vor dem Sortieren mit or placement_id auffuellen oder auf Fatal abbilden.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_images.py:270
  Description: verify liest direkt nach dem Ordnungsauftrag; der Auftrag wird weder abgefragt noch abgewartet.
  Spec requirement: AC-9 — Gegenprobe im selben Lauf
  Conflict: Ist das Ordnen bei Apple asynchron, scheitert der erste echte Lauf mit Fatal, obwohl die Ordnung kurz danach stimmt. Kein Fehlschreiben, Wiederholung loest es; AC-13 klaert es.
  Remediation: Gegenprobe mit sleep wiederholen, falls der echte Lauf es zeigt.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: .github/workflows/asc-store-images.yml:37
  Description: Die concurrency-Gruppe gilt auch fuer den pull_request-Ausloeser; ein wartender Handlauf kann durch einen neueren wartenden Lauf ersetzt werden (cancel-in-progress false schuetzt nur den laufenden).
  Spec requirement: AC-12 — concurrency ohne cancel-in-progress
  Conflict: Ein Handlauf kann ausfallen und muss neu gestartet werden; kein doppeltes Anlegen.
  Remediation: github.event_name in den Gruppennamen aufnehmen.

## Bestaetigungen

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_store_images.py:236
  Evidence: create_missing legt je Plan-Bild POST mit APP_SCREENSHOT, Gruppe, Bild, en-US an; test_place_creates_all_in_manifest_order gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_store_images.py:255
  Evidence: Ordnungsauftrag nur bei Abweichung, je Gruppe einer.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_store_images.py:236
  Evidence: vorhandene Platzierung gibt schon platziert, uebersprungen, kein POST; Resume-Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_store_images.py:196
  Evidence: check_existing wirft Fatal bei fremder oder doppelter Platzierung vor dem ersten POST.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_store_images.py:283
  Evidence: platzieren ruft bis create_missing nur GET; sieben Faelle im Test.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_asc_store_images.py:692
  Evidence: main weist platzieren de vor jedem Client zurueck, Ausgang 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_asc_store_images.py:619
  Evidence: kein DELETE oder Einreichung im Quelltext und in der Aufrufliste, Schreibaufrufe nennen nur LOC_EN.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/asc_store_images.py:220
  Evidence: Polling mit sleep bis ACTIVE oder PARENT_*, sonst Fatal mit Name, Zustand, stateDetails; POLLS begrenzt.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/asc_store_images.py:270
  Evidence: verify prueft Namen, Reihenfolge, Anzahl; Fatal mit Soll/Ist; de-DE nur GET, vorher gleich nachher.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/asc_store_images.py:302
  Evidence: print_placements gibt Position, Name, Zustand oder keine; nur GET.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: scripts/asc_store_images.py:130
  Evidence: ready_images verlangt Existenz und PREPARE_FOR_SUBMISSION, erlaubt Platzierung; check_state im Kopfbild unveraendert.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: scripts/asc_header_upload.py:143
  Evidence: error_codes haengt nur Codes an; Query und Token fehlen; Workflow mit Option platzieren, concurrency ohne Abbruch, Tests als erster Schritt.
  Status: CONFIRMED

Confirmation:
  AC: AC-14
  Code reference: .github/workflows/asc-store-images.yml:37
  Evidence: Diff beruehrt nur scripts/ und .github/workflows/ (Geraeteliste nicht beruehrt); 76 Tests gruen. Der Handlauf-Beleg haengt an AC-13.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: scripts/test_asc_header_upload.py:253
  Evidence: test_client_error_reports_api_code prueft Code vorhanden, Token und Query abwesend; gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: scripts/asc_store_images.py:283
  Evidence: Sechs Laeufe vom Zweig auf Commit 6de7ffd (gleich dem geprueften Stand), alle gruen ohne ::error: erste platzieren 12 angelegt, zweite 0 angelegt und 12 schon platziert, Probe en-US 5/5/2 ACTIVE, de-DE unveraendert 5/5/2 plus Kopf- und Suchbild, hochladen 12 schon vorhanden, lesen2 zeigt Manifest-Reihenfolge nach Namen.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Implementierung hat dem Adversary-Test standgehalten; AC-13 durch echte Laeufe vom Zweig (Commit 6de7ffd) belegt.
Findings: F001-F004 (alle LOW), kein CRITICAL/HIGH/MEDIUM.
Proven points: 14/14
Tests: 76 passed, 0 failed, 0 uebersprungen
Edge cases: All checked, none broken
Regressions: None found

## Geprüfte Dateien

- sha256:ec529a331b5edee3153e238834bec91063956225bf57ffe89545dd2abea570f6  .github/workflows/asc-store-images.yml
- sha256:82a2e1031fa18c3e149fb4c373525181202c1c060548b0280dfab5cca29e15aa  scripts/asc_header_upload.py
- sha256:6b73636f986a626f5e7e217e2af66d81989f0ac3548821c329a3f8f68a88c98b  scripts/asc_store_images.py
- sha256:9099f5ae4950d3d0b3f6b88d10f56a3f6813c62880c6bef776ef4635b63515fa  scripts/test_asc_header_upload.py
- sha256:3f42f6f325592ce77c13cc709d9251bb470151b803b53b7724310b3f385e2649  scripts/test_asc_store_images.py

## Prüfbasis

- base: f034db319b4d8575977fe5099df3632ce038215a
- blob:e108a4e1cfc11f122a469c38e8e544a8a72ce9bf  .github/workflows/asc-store-images.yml
- blob:c9b2b27c5815f23ad3da08fc4859a6efbc33657d  scripts/asc_header_upload.py
- blob:b9f991dab3de1af5843c3bf9301726a2720abf16  scripts/asc_store_images.py
- blob:484a96c1340e3deb9b4f8973bf771b06c417a2f6  scripts/test_asc_header_upload.py
- blob:8b1dffc844b2b756f7e2909a1c44b7589df17d37  scripts/test_asc_store_images.py
