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
- [x] **AC-11:** Given der Zweig ist im Remote und die Läufe aus Punkt 10 gehören zu dieser Fassung, When vom Zweig `lesen en mac`, `hochladen en mac`, `platzieren en mac`, `platzieren en mac` (zweites Mal), der iOS-Lauf `platzieren en` und „ASC Store Version“ `lesen` laufen, Then besteht jeder Lauf; `hochladen` legt vier Bilder an, das erste `platzieren` vier Platzierungen, das zweite und der iOS-Lauf nichts, und „ASC Store Version“ zeigt für Mac en-US vier Bilder in Manifest-Reihenfolge und für Mac de-DE unverändert vier. Belegt durch die Run-IDs und die zitierten Protokollzeilen unter `docs/artifacts/feat-842-s5b-mac-bilder/`; erst danach der Merge.
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

### Runde 3
**Adversary:**
AC-11 per grep an den acht Protokollen unter docs/artifacts/feat-842-s5b-mac-bilder/ geprüft, nicht an der Zusammenfassung. Checkout: alle acht Läufe (a, b, b2, b3, c, d, e, f) holen und prüfen 6464b0f6fd8d2dc4c65cba307df3265d70a64369 aus. Die Blobs von 6464b0f sind für scripts/asc_store_images.py e104620..., scripts/test_asc_store_images.py e5361e5... und .github/workflows/asc-store-images.yml 1ca9e8b..., identisch mit den in Runde 1 gestempelten; der Diff der drei Dateien gegen 6464b0f ist leer. Gelaufen ist also der geprüfte Stand. In jedem Lauf "Ran 38 tests" (Script tests) vor dem Schritt gegen Apple.
Fehler: ##[error] nur in lauf-b (Zeile 149/150): "en-mac-03-neu: Bild 9b800019-... nach 40 Abfragen nicht PREPARE_FOR_SUBMISSION, zuletzt UPLOAD_COMPLETE". Sonst in keinem Protokoll.
(a) lesen en mac: lokalisierung en-US vorhanden, kategorie APP_SCREENSHOT, gruppe MAC_PROFILE vorhanden maxCount=10, vier Zeilen "plan en-mac-... fehlt". Die bis dahin offene Annahme zu MAC_PROFILE/maxCount ist am echten Konto bestätigt.
(b)+(b3) hochladen: Lauf b legt en-mac-01-start an und lädt es hoch; 03-neu bleibt in UPLOAD_COMPLETE (Abbruch). Lauf b3: 01 und 03 "schon vorhanden, übersprungen", 04-detail und 05-erledigt "hochgeladen", "zustand bereit" (b3 wartet auf alle Plan-Bilder, 03 war danach bereit). Zusammen vier Bilder, keine Doppelanlage. Lauf b2 (lesen) zeigt den Zwischenstand.
(c) platzieren en mac: vier Zeilen "platzierung en-mac-... angelegt" in Manifest-Reihenfolge, "gegenprobe MAC_PROFILE 4 in Manifest-Reihenfolge", "de-DE 4 unverändert". Der Preflight verlangt PREPARE_FOR_SUBMISSION und lief durch.
(d) zweites platzieren: viermal "schon platziert, übersprungen", keine "angelegt", Gegenprobe grün, de-DE 4 unverändert.
(e) iOS platzieren en: zwölfmal "schon platziert, übersprungen", Gegenprobe 5/5/2, "de-DE 5/5/2 unverändert", Mac nur als ::warning::-Hinweis.
(f) ASC Store Version lesen: MAC_OS en-US bildsaetze=1 bilder=4 platzierungen=4; MAC_OS de-DE bildsaetze=1 bilder=4 platzierungen=4 (wie vor dem Schnitt); iOS en-US 12 Platzierungen. Die Reihenfolge der Mac-en-US-Bilder belegt die Gegenprobe aus (c) und (d) (Lesen mit sort=placementGroupPosition), nicht (f), das nur Zahlen zeigt.
Befund F001 (LOW, edge_case) zum Hänger in lauf-b: Die Wartezeit für die Apple-Verarbeitung (POLLS = 40 mal sleep 15 s, ca. 10 min, scripts/asc_header_upload.py:21,62) reichte für en-mac-03-neu nicht; Apple blieb in UPLOAD_COMPLETE, später war das Bild bereit. Keine Spec-Verletzung und nicht im geänderten Code (asc_header_upload.py unverändert), aber ein ehrlicher Betriebsbefund: langsame Apple-Verarbeitung führt zum Abbruch. Der Lauf ist idempotent, die Wiederholung (b3) löste es ohne Doppelanlage und ohne Schaden. Kein Handlungsbedarf im Schnitt; ggf. Wartezeit erhöhen.
Ergebnis: Alle Sätze von AC-11 stützen sich auf Protokollzeilen; AC-11 bewiesen, mit dem Vermerk, dass hochladen zwei Läufe brauchte.
**Implementierer:** (nicht beteiligt, Kontextisolation)

Confirmation:
  AC: AC-11
  Code reference: scripts/asc_store_images.py:339
  Evidence: Acht Handläufe vom Zweig auf 6464b0f (= geprüfter Code-Stand), siehe Runde 3: hochladen über b und b3 vier Bilder, erstes platzieren vier Platzierungen, zweites und iOS-Lauf nichts, Store Version Mac en-US 4 und Mac de-DE 4. Einziger Fehler: Apple-Hänger in lauf-b (F001, LOW), durch idempotente Wiederholung gelöst.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Die Implementierung hat dem Adversary-Test standgehalten; AC-11 durch echte Läufe vom Zweig (Code-Stand 6464b0f, geprüfter Stand) belegt.
Findings: F001 (LOW, Apple-Verarbeitung hing in lauf-b, Wiederholung löste es), kein CRITICAL/HIGH/MEDIUM.
Tests: 98 passed, 0 failed, 0 übersprungen
Edge cases: All checked, none broken
Regressions: None found
Checklist: 12/12 points proven

## Geprüfte Dateien

- sha256:bd04314fe884079da38bde7fdc2f5b7a5a026e7a6e8eab314def39cf79dbf05a  .github/workflows/asc-store-images.yml
- sha256:007ee5da9a32fa2543ac3e8fa868530582d6af9450db057d414fbfdea644e003  scripts/asc_store_images.py
- sha256:922b9bc64ff1c4b061b041d4d1b1d7519f39c39c68ff1966d3aa1a4ab5412068  scripts/test_asc_store_images.py

## Prüfbasis

- base: 70d5818f54fa3661f5336983e0a4122ee721c84b
- blob:1ca9e8b5a267b67d60d0e5f2b7864d49432fc91f  .github/workflows/asc-store-images.yml
- blob:e10462022ee83944cf87f00522fa79c748a3761b  scripts/asc_store_images.py
- blob:e5361e58600c556cbd23716671d240b73d83a0ed  scripts/test_asc_store_images.py
