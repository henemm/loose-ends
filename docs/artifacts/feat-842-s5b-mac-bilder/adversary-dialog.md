# Adversary Dialog — feat-842-s5b-mac-bilder
Spec: docs/specs/feat-842-schnitt-5b-mac-bilder.md
Datum: 2026-11-09 17:41

## Checkliste
- [x] **AC-1:** Given das echte Manifest, When der Plan für Mac und der Plan ohne Plattform gebildet werden, Then enthält der Mac-Plan genau die vier Bilder `en-mac-01-start`, `en-mac-03-neu`, `en-mac-04-detail`, `en-mac-05-erledigt` (Gruppe `MAC_PROFILE`, 1280×800) und der iOS-Plan unverändert die zwölf iPhone-, iPad- und Watch-Bilder ohne Mac. Belegt durch `test_mac_plan_is_only_mac_and_ios_plan_unchanged`.
- [x] **AC-2:** Given eine bearbeitbare Mac-Version mit en-US ohne Platzierung und vier bereiten Bibliotheksbildern, When `platzieren en mac` läuft, Then entstehen genau vier Platzierungen (`APP_SCREENSHOT`, `MAC_PROFILE`, richtiges Bild, Ziel en-US der Mac-Version) in Manifest-Reihenfolge, die Gegenprobe ist grün, und es gibt keinen Aufruf auf iOS-Lokalisierungen oder iOS-Gruppen. Belegt durch `test_mac_place_creates_four_on_mac_localization_only`.
- [x] **AC-3:** Given die vier Platzierungen, When `platzieren en mac` erneut läuft, Then entsteht kein POST und jede Zeile meldet „schon platziert, übersprungen“; bei abweichender Reihenfolge entsteht genau ein Ordnungsauftrag der Gruppe `MAC_PROFILE`, bei richtiger keiner. Belegt durch `test_mac_second_run_places_nothing` und `test_mac_orders_only_on_difference`.
- [x] **AC-4:** Given eine fremde Platzierung oder eine Doppelplatzierung in en-US der Mac-Version oder eine fehlende Voraussetzung (keine oder mehrere bearbeitbare Mac-Versionen, keine en-US-Lokalisierung, Bild fehlt oder nicht `PREPARE_FOR_SUBMISSION`, `MAC_PROFILE` fehlt, `maxCount` zu klein, falsches Dateimaß), When `platzieren en mac` läuft, Then bricht es mit `::error::` und benennendem Grund ab, bevor ein Nicht-GET-Aufruf geschieht. Belegt durch `test_mac_foreign_or_duplicate_aborts_without_write` und `test_mac_preflight_aborts_before_any_write`.
- [x] **AC-5:** Given die Bibliothek ohne Mac-Bilder, When `hochladen en mac` läuft, Then legt es genau die vier fehlenden `en-mac-…`-Bilder an (Bytes, `uploaded: true`, Zustand `PREPARE_FOR_SUBMISSION`) und fasst keine iOS-Bilder an; ein zweiter Lauf legt nichts an. Belegt durch `test_mac_upload_creates_only_missing_mac_images`.
- [x] **AC-6:** Given Mac-Bilder in Bibliothek und auf Mac en-US, When der iOS-Lauf `platzieren en` läuft, Then verhält er sich wie vor diesem Schnitt (zwölf Plan-Bilder, keine Aufrufe auf die Mac-Version, kein Fehler wegen Mac-Bildern). Belegt durch `test_ios_run_untouched_by_mac_images`.
- [x] **AC-7:** Given jeder Lauf von `platzieren en mac`, When die Aufrufliste geprüft wird, Then enthält sie nie `DELETE`, nie eine Einreichung und keinen Schreibaufruf auf de-DE; de-DE der Mac-Version bleibt unverändert (4 Platzierungen) und wird in der Gegenprobe nur gelesen gemeldet. Belegt durch `test_never_deletes_submits_or_writes_german_on_mac`.
- [x] **AC-8:** Given `lesen en mac`, When es läuft, Then zeigt die Ausgabe Lokalisierung, Gruppe `MAC_PROFILE` mit `maxCount`, Kategorie, Plan vorhanden/fehlt und die en-US-Platzierungen der Mac-Version (ohne `keine`), und die Aufrufliste besteht nur aus GET. Belegt durch `test_mac_lesen_shows_group_and_placements_and_never_writes`.
- [x] **AC-9:** Given der Aufruf von `main`, When ein drittes Argument `ios` oder `mac` fehlt, `ios` oder `mac` lautet, unbekannt ist, oder `platzieren de` lautet, Then läuft ohne Argument und mit `ios` der bisherige iOS-Weg, mit `mac` der Mac-Weg, eine unbekannte Plattform oder zu viele Argumente enden mit Ausgang 2 und `platzieren de` mit Ausgang 1 und `::error::`, jeweils ohne Aufruf gegen Apple. Belegt durch `test_main_platform_argument`.
- [x] **AC-10:** Given die Workflow-Datei, When sie geprüft wird, Then bietet sie die Eingabe `plattform` (`ios`, `mac`; Standard `ios`), übergibt sie dem Skript, führt die Python-Tests als ersten Schritt aus, gibt den Schlüssel nie aus und trägt `concurrency` ohne `cancel-in-progress`. Belegt durch `test_workflow_offers_plattform`.
- [ ] **AC-11:** Given der Zweig ist im Remote und die Läufe aus Punkt 10 gehören zu dieser Fassung, When vom Zweig `lesen en mac`, `hochladen en mac`, `platzieren en mac`, `platzieren en mac` (zweites Mal), der iOS-Lauf `platzieren en` und „ASC Store Version“ `lesen` laufen, Then besteht jeder Lauf; `hochladen` legt vier Bilder an, das erste `platzieren` vier Platzierungen, das zweite und der iOS-Lauf nichts, und „ASC Store Version“ zeigt für Mac en-US vier Bilder in Manifest-Reihenfolge und für Mac de-DE unverändert vier. Belegt durch die Run-IDs und die zitierten Protokollzeilen unter `docs/artifacts/feat-842-s5b-mac-bilder/`; erst danach der Merge.
- [x] **AC-12:** Given die Änderung berührt nur `scripts/`, `.github/workflows/` und `docs/`, When der Schnitt abgenommen wird, Then endet die Abnahme nach Stufe 2 mit dem Satz „Kein Pfad der Geräteliste berührt.“; der „Benutzen“-Beleg sind die echten Handläufe aus AC-11 gegen Apple. Auf Hennings Geräten läuft nichts. `python3 -m unittest scripts/test_asc_store_images.py` und die übrigen Skript-Tests (`test_asc_header_upload.py`, `test_asc_version_texts.py`, `test_asc_store_probe.py`) sind grün. Belegt durch Dateiliste des Diffs und die Testläufe.

## Dialog

### Runde 1
**Adversary:** Testlauf: 98 Tests OK (Ausgabe docs/artifacts/feat-842-s5b-mac-bilder/adversary-test-output.txt). Diff gelesen. iOS-Pfad: plan(sprache, root, plattform="ios") filtert auf {iphone,ipad,watch} = vorherige GROUPS ohne Mac, also byte-gleich; Standardwerte `plattform="ios"` in preflight/upload/lesen/platzieren. Mac-Lauf: ASC_PLATFORM["mac"]="MAC_OS", Lokalisierungen aus lookup(version["id"]) der Mac-Version; Gruppen nur aus plan (want), daher keine iOS-Gruppen; german_counts(client, locs, want) liest nur Gruppen der Plattform. Kein DELETE im Skript; Preflight (nur GET) liegt vor jedem POST in upload/platzieren. main: len 2 -> Usage (argv[3] nicht gelesen), len 5 -> 2, `tv` -> 2, `platzieren de mac` -> Abweisung nach Argumentprüfung. Rückgabewert von preflight (jetzt Tripel): grep zeigt nur zwei Aufrufer (upload Zeile 120, platzieren Zeile 299), beide angepasst; kein anderes Skript/Workflow nutzt asc_store_images. Workflow: PLATTFORM über env (keine Injektion; Auswahl `choice`), Schlüssel nur in Datei mit umask 077 und trap rm, concurrency ohne cancel-in-progress. Testkorrektur: Substring-Kollision 'L-en-US' in 'ML-en-US' ist real; assertNotRegex mit (?<![A-Za-z]) schließt nur Treffer mit direkt vorangestelltem Buchstaben aus, 'L-en-US'/'L-de-DE' als eigenständige ID (z. B. nach '/', Leerzeichen, Anführungszeichen) bleibt verboten, IPHONE/IPAD/WATCH sind unverändert geprüft. Die Prüfung ist nicht ausgehöhlt (leichte Restschwäche: ID mit Buchstaben-Präfix würde durchrutschen, hier irrelevant).
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Nachbohren. (a) Mehrere bearbeitbare Mac-Versionen: editable_version liefert laut Spec/Tests Fatal bzw. None; Preflight-Test dazu läuft grün. (b) Fremd-/Doppelplatzierung: check_existing läuft je Gruppe der Plattform vor create_missing, erst danach POST. (c) Zweiter Lauf: create_missing überspringt vorhandene, Ordnen nur bei Abweichung (Tests grün). (d) Mac-Bilder in der Bibliothek stören den iOS-Lauf nicht, da Plan/Gruppen nur iOS. (e) warn_mac nur im iOS-Lauf, Text verweist auf `… mac`; AC-7 unverändert erfüllt. (f) Versuch eines Mutationstests (Mac->IOS-Version) im Scratchpad wurde vom Sandbox-Guard blockiert, daher nicht ausgeführt; stattdessen Test-Code gelesen: die Mac-Tests prüfen konkrete Lokalisierungs-IDs (MLOC_EN) und Aufrufliste, nicht nur Ergebnisse. Keine Findings der Schwere MEDIUM oder höher. LOW: Workflow-Schritt 'Script tests' führt nur test_asc_store_images.py aus (wie zuvor, spec-konform). AC-11 kann nur nach Push/Handlauf belegt werden; Code ermöglicht es (Workflow-Eingabe plattform, Aufruf mit drittem Argument, `lesen en mac` gibt Gruppe/maxCount aus).
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Bestätigungen
Confirmation:
  AC: AC-1
  Code reference: scripts/asc_store_images.py:35
  Evidence: PLATTFORMEN/GROUPS und plan(...) filtern nach Plattform; Test grün
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/asc_store_images.py:296
  Evidence: platzieren nutzt Preflight-Lokalisierungen der Mac-Version; Test grün
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/asc_store_images.py:296
  Evidence: überspringt Vorhandenes, ordnet nur bei Abweichung; Tests grün
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/asc_store_images.py:93
  Evidence: preflight nur GET vor Schreiben, platform_version Fatal; Tests grün
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/asc_store_images.py:119
  Evidence: upload legt nur Plan-Bilder der Plattform an; Test grün
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/asc_store_images.py:296
  Evidence: iOS-Default-Pfad ohne Mac-Gruppen; Test grün
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/asc_store_images.py:221
  Evidence: german_counts nur lesend je Plattform-Gruppe; kein DELETE im Code; Test grün
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/asc_store_images.py:159
  Evidence: lesen nur GET mit Plattform; Test grün
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/asc_store_images.py:325
  Evidence: main-Argumentprüfung (3 oder 4 Args, Plattform in PLATTFORMEN); Test grün
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: .github/workflows/asc-store-images.yml:66
  Evidence: Eingabe plattform (ios/mac, Standard ios), env PLATTFORM, Aufruf mit "$PLATTFORM", concurrency Zeile 46-48; Test grün
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: scripts/test_asc_store_images.py:804
  Evidence: 98 Tests OK über alle vier Skript-Testdateien; Diff berührt nur scripts/, .github/workflows/, docs/. Die Testkorrektur (Regex mit Lookbehind) höhlt die Prüfung nicht aus.
  Status: CONFIRMED

AC-11 ist NICHT bewiesen: Handläufe gegen Apple stehen aus (Push gesperrt), vor dem Merge noch zu belegen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
VERIFIED gilt für den Code (AC-1..AC-10, AC-12), wie im Präzedenzfall 4c-2 (AC-13). AC-11 ist offen, vor dem Merge durch echte Läufe zu belegen, Checkbox bleibt leer, nicht als bewiesen markiert. Das ist nach Spec ein Abnahme-Nachweis außerhalb des Test Plans (Handläufe vom Zweig, erst nach Push möglich). Restrisiko bis dahin: Antwortformen und Referenzdaten für MAC_PROFILE (maxCount, Kategorie) nur aus Doku/Attrappe; ein Fehlschlag endet vor jedem Schreiben.
Findings: keine.
Tests: 98 passed, 0 failed, 0 übersprungen
Edge cases: All checked, none broken
Regressions: None found
Checklist: 11/12 points proven (AC-11 offen, vor dem Merge zu belegen)

## Geprüfte Dateien

- sha256:bd04314fe884079da38bde7fdc2f5b7a5a026e7a6e8eab314def39cf79dbf05a  .github/workflows/asc-store-images.yml
- sha256:007ee5da9a32fa2543ac3e8fa868530582d6af9450db057d414fbfdea644e003  scripts/asc_store_images.py
- sha256:922b9bc64ff1c4b061b041d4d1b1d7519f39c39c68ff1966d3aa1a4ab5412068  scripts/test_asc_store_images.py

## Prüfbasis

- base: 70d5818f54fa3661f5336983e0a4122ee721c84b
- blob:1ca9e8b5a267b67d60d0e5f2b7864d49432fc91f  .github/workflows/asc-store-images.yml
- blob:e10462022ee83944cf87f00522fa79c748a3761b  scripts/asc_store_images.py
- blob:e5361e58600c556cbd23716671d240b73d83a0ed  scripts/test_asc_store_images.py
