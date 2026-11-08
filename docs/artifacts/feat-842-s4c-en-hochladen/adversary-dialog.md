# Adversary Dialog — feat-842-s4c-en-hochladen
Spec: docs/specs/feat-842-schnitt-4c-1-en-bibliothek.md
Datum: 2026-11-08 20:51

## Checkliste
- [x] **AC-1:** Given das Manifest `docs/store/screenshots/en/manifest.json`, When `plan("en")` läuft, Then entstehen 12 Einträge mit `referenceName` `en-<gerät>-<datei ohne .png>` (iPhone 5, iPad 5, Watch 2, Mac nicht enthalten) und den festen Gruppen `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE`, `IPAD_13_PROFILE`, `WATCH_SERIES_10_PROFILE`. Belegt durch `test_plan_names_and_groups` (rot vor, grün nach der Umsetzung).
- [x] **AC-2:** Given eine Attrappe in Apples Form, When `lesen` läuft, Then besteht die Aufrufliste nur aus GET und die Ausgabe nennt bearbeitbare iOS-Version, Lokalisierung en-US, Gruppen mit `maxCount`, Bestand mit Namen und Zuständen, je Plan-Eintrag `vorhanden`/`fehlt` und die Mac-Meldung. Belegt durch `test_read_only_never_writes`.
- [x] **AC-3:** Given eine leere Bibliothek, When `hochladen` läuft, Then wird jedes Bild des Plans angelegt, hochgeladen, mit `uploaded: true` bestätigt und steht in `PREPARE_FOR_SUBMISSION`, und die Aufrufliste enthält **keinen** Aufruf an Platzierungen, Ordnungsaufträge oder Einreichung und **kein** `DELETE`. Belegt durch `test_upload_creates_all_and_never_places`.
- [x] **AC-4:** Given die Bibliothek nach einem ersten Lauf (auch mit Bildern anderer Sprache), When `hochladen` erneut läuft, Then entsteht kein POST, PUT oder PATCH und fremde Namen bleiben unberührt. Belegt durch `test_second_run_creates_nothing` und `test_existing_names_of_other_language_are_untouched`.
- [x] **AC-5:** Given eine der Voraussetzungen fehlt (keine oder mehrere bearbeitbare iOS-Versionen, keine en-US-Lokalisierung, Gruppe fehlt, mehr Bilder als `maxCount`, Datei fehlt, Pixelmaß weicht vom Manifest ab), When `hochladen` läuft, Then bricht es mit `::error::` und benennendem Grund ab, **bevor** ein Nicht-GET-Aufruf geschieht. Belegt durch `test_aborts_before_any_write` (alle sieben Fälle).
- [x] **AC-6:** Given keine bearbeitbare Mac-Version, When `hochladen` läuft, Then steht eine `::warning::`-Zeile zum Mac in der Ausgabe, es wird kein Mac-Bild angelegt, und der Lauf endet erfolgreich. Belegt durch `test_mac_without_editable_version_is_skipped_with_warning`.
- [x] **AC-7:** Given eine Bildverarbeitung bei Apple, die `FAILED` meldet, oder ein Bild des Plans in anderem Zustand als `PREPARE_FOR_SUBMISSION` oder mit Platzierung, When `hochladen` endet, Then meldet das Skript `Fatal` mit Bildname und Grund; „bereit“ nur bei allen Bildern bereit und unplatziert. Belegt durch `test_failed_processing_is_an_error` und `test_state_check_requires_ready_and_no_placement`; eine andere Sprache als `de`/`en` wird ohne Aufruf abgelehnt (`test_language_input_is_checked`); die Workflow-Datei führt die Python-Tests als ersten Schritt aus und gibt den Schlüssel nie aus (Lesen der Datei im Diff).
- [ ] **AC-8:** Given der Zweig ist im Remote und die Datei `asc-store-images.yml` liegt dort, When `gh workflow run asc-store-images.yml --ref <zweig> -f aktion=lesen` läuft, Then besteht der Lauf (Python-Tests grün), das Protokoll nennt die eine bearbeitbare iOS-Version 1.0.1, die en-US-Lokalisierung, die drei Gruppen mit `maxCount` und die Mac-Warnung, und die Bibliothek enthält noch keine Bilder mit Namen `en-…` (`fehlt` für alle 12). Belegt durch die Run-ID und das Protokoll im Abnahmebericht (vor dem Merge).
- [ ] **AC-9:** Given AC-8 ist belegt, When `gh workflow run asc-store-images.yml --ref <zweig> -f aktion=hochladen` läuft und danach `aktion=lesen` erneut, Then besteht der Lauf, und der erneute `lesen`-Lauf zeigt 12 Bibliotheksbilder `en-*` (iPhone 5, iPad 5, Watch 2) im Zustand `PREPARE_FOR_SUBMISSION` mit `platzierungen=0`; ein dritter `hochladen`-Lauf meldet für alle 12 „schon vorhanden, übersprungen“. Belegt durch die drei Run-IDs und die Protokollzeilen. Es sind 12 Bilder (5 + 5 + 2); die frühere Fassung dieser Spec hatte sich auf 11 verzählt. Die Bibliothek enthält danach zusätzlich die vorhandenen Bilder (Kopfbilder, deutsche Bilder), die unberührt bleiben.
- [ ] **AC-10:** Given die Läufe aus AC-9, When der Workflow „ASC Store Probe“ (`asc-store-probe.yml`) danach läuft, Then zeigt er für en-US weiterhin `platzierung keine` und `bildsatz keine` und für de-DE unverändert die bisherigen Platzierungen und Bildsätze: der Schnitt ist für die Store-Seite folgenlos. Belegt durch die Run-ID und die Protokollzeilen von en-US und de-DE.
- [x] **AC-11:** Given die Änderung berührt nur `scripts/` und `.github/workflows/`, When der Schnitt abgenommen wird, Then endet die Abnahme nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“; der „Benutzen“-Beleg sind die echten Handläufe der ACs 8 bis 10 gegen Apple. Auf Hennings Geräten läuft nichts. `python3 -m unittest scripts/test_asc_store_images.py` und die übrigen Skript-Tests (`scripts/test_asc_header_upload.py`, `scripts/test_asc_version_texts.py`, `scripts/test_asc_store_probe.py`) sind grün. Belegt durch Dateiliste des Diffs gegen die Geräteliste und die Testläufe.

## Dialog

### Runde 1
**Adversary:**
Tests selbst gelaufen: 61 Tests (store_images, header_upload, version_texts, store_probe), OK, 0 Fehler, 0 uebersprungen (docs/artifacts/feat-842-s4c-en-hochladen/adversary-test-output.txt).
Mutationen in einer Kopie im Scratch (Arbeitsbaum unberuehrt, git diff --stat zeigt nur die drei vorher geaenderten Dateien): Placement-Aufruf eingebaut -> 6 Tests rot; Vorabpruefung nach erstem POST -> test_aborts_before_any_write, test_upload_creates_all_and_never_places u.a. rot; vorhandene Namen nicht uebersprungen -> test_second_run_creates_nothing rot; Zustandscheck entfernt -> test_waiting_image_from_broken_run_fails_second_run rot (test_state_check testet check_state direkt, faengt das Entfernen aus upload also NICHT; das deckt der Zusatztest ab); Pixelpruefung, maxCount-Pruefung, Dateipruefung, Lokalisierungspruefung, Mac-Warnung, Sprachpruefung entfernt -> jeweils rot. Keine ueberlebende Mutation.
Echte Daten: plan en und de je 12 Eintraege, alle Dateien im Repo haben das Manifest-Pixelmass; preflight gegen die echte Bildablage mit Attrappe laeuft durch. Nicht-PNG -> Fatal "ist kein PNG" (manuell belegt, kein eigener Test).
Workflow: Tests sind erster Schritt, Apple-Schritt nur bei workflow_dispatch, Schluesseldatei mit trap und umask 077 wie im Header-Upload, kein echo/cat des Schluessels, Secrets nur im Dispatch-Schritt, permissions contents: read.
Findings siehe Verdict. Keine CRITICAL/HIGH/MEDIUM.
**Implementierer:**

### Runde 2
**Adversary:**
**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_images.py:126
  Description: lesen ohne bearbeitbare iOS-Version meldet nur die Zeile von editable_version, ueberspringt die Lokalisierungszeile und endet mit Ausgang 0 (gruen).
  Spec requirement: AC-8 — Protokoll nennt die bearbeitbare iOS-Version
  Conflict: Ein gruener lesen-Lauf kann ohne Version laufen; im echten Lauf muss das Protokoll die Zeile "version IOS 1.0.1" zeigen, sonst ist AC-8 nicht belegt.
  Remediation: Optional Ausgang 1 oder ::warning:: in lesen; mindestens im Abnahmebericht die Versionszeile zitieren.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_store_images.py:40
  Description: Namensschema <sprache>-<geraet>-<datei>; mit Sprache de wuerden Bilder de-iphone-... angelegt, auch wenn de-DE-Bilder in der Bibliothek unter anderen Namen schon liegen (Duplikate, nur Bibliothek, keine Platzierung).
  Spec requirement: Purpose — fasst Deutsch nie an
  Conflict: Der Workflow bietet sprache=de an; ein versehentlicher Lauf fuegt Bibliotheksbilder hinzu. Verstoesst nicht gegen AC, aber gegen den Geist von "Deutsch nie anfassen".
  Remediation: Handlauf nur mit en; optional hochladen mit de im Skript ablehnen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_asc_store_images.py:283
  Description: Kein Test fuer Nicht-PNG-Datei und keiner, der das Entfernen des check_state-Aufrufs in upload() direkt faengt ausser test_waiting_image_from_broken_run_fails_second_run (Zusatztest, nicht in der Spec).
  Spec requirement: AC-5, AC-7
  Conflict: Abdeckung haengt an einem Test ausserhalb der Spec-Liste; Verhalten selbst ist korrekt.
  Remediation: Fall Nicht-PNG in test_aborts_before_any_write aufnehmen.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: .github/workflows/asc-store-images.yml:35
  Description: Keine concurrency-Gruppe; zwei gleichzeitige hochladen-Laeufe koennten dieselben Namen doppelt anlegen (Pruefen-dann-Anlegen). Ein in AWAITING_UPLOAD haengendes Bild hat keinen Loeschweg (in der Spec als Risiko benannt).
  Spec requirement: AC-4 — kein doppeltes Anlegen
  Conflict: Nur bei parallelen Handlaeufen; unwahrscheinlich.
  Remediation: concurrency: group asc-store-images, cancel-in-progress: false.

Confirmation:
  AC: AC-1
  Code reference: scripts/asc_store_images.py:30
  Evidence: plan("en") liefert 12 Eintraege mit en-Namen und festen Gruppen; test_plan_names_and_groups gruen, Mac ausgelassen (Zeile 36).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_store_images.py:124
  Evidence: lesen nutzt nur client.get; Ausgabe gezeigt (Version, Lokalisierung, Gruppen mit maxCount, Bestand, plan vorhanden/fehlt, Mac-Warnung); Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_store_images.py:99
  Evidence: POST, put_bytes, PATCH uploaded, wait_ready je Bild; Quelltext ohne Placements/Ordering/Submission/DELETE; Mutation Placement rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_store_images.py:108
  Evidence: vorhandene Namen uebersprungen; fremde Namen unberuehrt; Mutation noskip rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_store_images.py:72
  Evidence: preflight nur GET vor jedem Schreiben; alle sieben Faelle im Test; Mutationen late_preflight, nopixel, nomax, nofilecheck, nolocale rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/asc_store_images.py:65
  Evidence: genau eine ::warning::-Zeile, kein Mac-Bild, Lauf erfolgreich; Mutation nowarn rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: .github/workflows/asc-store-images.yml:41
  Evidence: Tests erster Schritt (Zeile 41), Apple-Schritt nur bei workflow_dispatch (43), Schluessel nie ausgegeben; FAILED und check_state mit Bildname getestet; Sprache fr -> Ausgang 2 ohne Aufruf.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: scripts/test_asc_store_images.py:194
  Evidence: Dateiliste (scripts/, .github/workflows/) beruehrt keinen Pfad der Geraeteliste; 61 Tests gruen. Rest (Nachweis nach Stufe 2) haengt an AC-8 bis AC-10.
  Status: CONFIRMED

AC-8, AC-9, AC-10: OFFEN (nur mit echtem Lauf vom gepushten Zweig).
Gewuenscht in den Protokollen: AC-8 lesen: Zeile "version IOS 1.0.1 id=... state=PREPARE_FOR_SUBMISSION", "lokalisierung en-US vorhanden", "kategorie APP_SCREENSHOT=<Kategorie>" (nicht "-"), drei "gruppe ... vorhanden maxCount=N" mit N>=5 (iPad 5, iPhone 5, Watch 2), "plan en-... fehlt" x12, keine "bild name=en-..." Zeile, Zeile "::warning::keine bearbeitbare Mac-Version"; Tests-Schritt gruen. AC-9 hochladen: 12 Zeilen "bild en-... hochgeladen", Endzeile "zustand bereit"; danach lesen: 12 "bild name=en-... zustand=PREPARE_FOR_SUBMISSION platzierungen=0" und bestehende Bilder unveraendert; dritter Lauf: 12 mal "schon vorhanden, uebersprungen", kein "hochgeladen". Zeile mit echter Kategorie ist entscheidend (Risiko Antwortform). AC-10 Store-Probe: en-US "platzierung keine" und "bildsatz keine", de-DE unveraenderte Zeilen gegenueber dem Lauf 42515431363.

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Vorlaeufig: AC-1 bis AC-7 und AC-11 (Tests/Dateiliste) bewiesen, keine CRITICAL/HIGH/MEDIUM; AC-8, AC-9, AC-10 sind ohne echte Laeufe gegen Apple nicht belegbar.
Findings: F001-F004 (alle LOW).
Tests: 61 passed, 0 failed, 0 uebersprungen
Proven points: 8/11

## Geprüfte Dateien

- sha256:61f91cb6050b8e4971f77a4033d5c9cf42e2e52cdd58ef2dcfa251b8f81a3b27  .github/workflows/asc-store-images.yml
- sha256:b0a8dd2ea12c448aa77174d5be9cac8e1d90da408f906ffe5ba96ff2b4e476c7  scripts/asc_store_images.py
- sha256:ac208e9d0aad33dfd3934f7b38f359d0097e50ddff056298bc602158d13ad7f4  scripts/test_asc_store_images.py

## Prüfbasis

- base: 472ac7edaffc87c5c890b59237de2b0b5a1a6568
- blob:d650f6f3de238c374cb7cd3502e6523915243caa  .github/workflows/asc-store-images.yml
- blob:90536739f5442a8c3f6a6baab0f7b8272d5aa6d2  scripts/asc_store_images.py
- blob:80009242a19312c37f6f9073093385bac1907e19  scripts/test_asc_store_images.py
