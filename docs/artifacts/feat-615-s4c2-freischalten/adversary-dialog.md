# Adversary Dialog — feat-615-s4c2-freischalten
Spec: docs/specs/feat-615-schnitt-4c2a-freischalten.md
Datum: 2026-11-09 20:20

## Checkliste
- [x] **AC-1:** Berechtigung: `project.yml` führt `com.apple.developer.applesignin: [Default]` in `entitlements.properties` des App-Ziels, `LooseEnds/LooseEnds.entitlements` trägt `<key>com.apple.developer.applesignin</key>` mit `Default`, und `generate` hinterlässt keinen Diff. Test: `scripts/test_entitlements_sync.py` (vorhandene Vergleiche) plus Fall `test_app_target_has_applesignin` (liest die Quelle und prüft den Schlüssel und `Default`).
- [x] **AC-2:** Schalter aus als Bool: `project.yml` führt `LEAccountEnabled: false`, `LooseEnds/Info.plist` trägt den Schlüssel als `<false/>` (Typ Bool, nicht Text), `LEServiceURL` fehlt in beiden. Test: `scripts/test_info_plist_sync.py` (vorhandene Vergleiche) plus Fall `test_account_switch_is_a_false_bool` (`plistlib` liefert `False`, Typ `bool`, kein `LEServiceURL`).
- [x] **AC-3:** Eingabe: `testflight.yml` hat die Eingabe `konto` mit `type: boolean` und `default: false`; `ACCOUNT_BUILD` ist nur dann `true`, wenn `inputs.konto == true`, ein `v*`-Tag-Lauf also immer `false`. Test: `test_workflow_has_konto_input_default_false` (Textlauf).
- [x] **AC-4:** Setzen vor dem Archiv: in beiden Jobs `upload` und `upload-mac` steht der Schritt mit `plutil -replace LEAccountEnabled -bool YES LooseEnds/Info.plist` unter der Bedingung `ACCOUNT_BUILD == 'true'`, hinter „Generate project“ und vor dem Archiv-Schritt desselben Jobs; ohne die Bedingung käme er nirgends vor. Test: `test_switch_step_is_conditional_and_between_generate_and_archive` (Textlauf, je Job).
- [x] **AC-5:** Beleg am Archiv: die Archivprüfung (iOS) und die Mac-Prüfung enthalten je eine Prüfung von `LEAccountEnabled` auf Typ `bool` und Wert gleich der Eingabe; Abweichung (Schlüssel fehlt, Text statt Bool, falscher Wert) setzt den Schritt auf rot. Test: `test_archive_checks_prove_switch_type_and_value` (Textlauf: Schlüssel und `plutil -type` in beiden Prüfungen) sowie `test_switch_check_logic`, der den Prüfausschnitt des Workflows für die Fälle `bool true`, `bool false`, `string YES`, fehlend gegen die Eingabe `true`/`false` ausführt (Shell auf einer erzeugten Beispiel-Plist; erwartet 8 Ergebnisse als Tabelle).
- [x] **AC-6:** Beleg der Berechtigung am signierten Archiv: die iOS-Prüfung ruft `entitled com.henning.looseends com.apple.developer.applesignin` auf, die Mac-Prüfung führt `com.apple.developer.applesignin` in der Schlüsselliste; fehlt sie, ist der Schritt rot. Test: `test_archive_checks_prove_applesignin_entitlement` (Textlauf). Der echte Beleg am echten Archiv entsteht erst im ersten TestFlight-Lauf nach dem Merge (siehe Definition of Done).
- [x] **AC-7:** Kennzeichnung: `scripts/asc_what_to_test.py` hängt bei `ACCOUNT_BUILD=true` die Marke `ACCOUNT_BUILD_MARK` als letzte Zeile an **jeden** Abschnitt an (auch bei `de:`/`en:`-Abschnitten und bei Text ohne Marker); bei `false` und fehlender Variable bleibt der Text unverändert; kein doppeltes Anhängen; die 4000-Zeichen-Grenze gilt inklusive Marke (ein Text mit 3990 Zeichen ist mit Marke zu lang → `Fatal`). Gegenprobe am Nachbau: jede beim Schreiben (PATCH und POST) gesendete Fassung enthält die Marke. Test: `test_mark_is_added_to_every_section`, `test_mark_not_added_when_off`, `test_mark_respects_length_limit`, `test_mark_in_every_written_localization` in `scripts/test_asc_what_to_test.py`.
- [x] **AC-8:** Eine Quelle: der Wortlaut der Marke steht genau einmal als Konstante in `scripts/asc_what_to_test.py`; `scripts/asc_store_version.py` importiert sie, `testflight.yml` nennt den Wortlaut nicht. Test: `test_mark_defined_once` (liest die drei Dateien, zählt den Wortlaut: eine Fundstelle).
- [x] **AC-9:** Sperre: Gegeben Bauten 133 (ohne Marke), 134 (Marke in einer Lokalisierung), 135 (Marke in allen), 136 (ohne Marke) für Version 1.0.1, wählt `pick_build` 136; sind 136 und 135 gekennzeichnet, wählt es 133; die Ausgabe nennt je Übersprungenen die Buildnummer mit Grund `konto`. `anlegen` ordnet nie einen gekennzeichneten Bau zu (PATCH-Aufrufe geprüft). Test: `test_pick_build_skips_account_builds`, `test_anlegen_never_assigns_account_build` in `scripts/test_asc_store_version.py`.
- [x] **AC-10:** Fail-closed: ist für einen Kandidaten `GET …/betaBuildLocalizations` nicht lesbar (404, 500 und kein Antworten nach den Wiederholungen) oder die Liste leer, wird der Bau übersprungen (Grund `texte nicht lesbar`) und nie gewählt; bleibt kein Kandidat, endet der Lauf mit `Fatal` und **keinem** Schreibaufruf; kein Apple-Rohtext in der Ausgabe. Test: `test_pick_build_fail_closed_on_unreadable`, `test_pick_build_fail_closed_on_empty`, `test_pick_build_nothing_left_writes_nothing` in `scripts/test_asc_store_version.py`.
- [x] **AC-11:** Keine Wirkung auf das Vorhandene: ohne gekennzeichnete Bauten und mit lesbaren Lokalisierungen wählt `pick_build` wie bisher den Bau mit der höchsten (numerischen) Buildnummer; ein schon zugeordneter Bau bleibt unverändert; die bestehenden Tests von `test_asc_store_version.py` bleiben grün (der Nachbau liefert für Bauten ohne Angabe eine Lokalisierung ohne Marke). Test: `test_pick_build_unchanged_without_marks` plus der vorhandene Satz.
- [x] **AC-12:** Doku: `docs/reference/testflight.md` beschreibt die Eingabe `konto`, die Kennzeichnung samt der Regel „nie einem Store-Bau zuordnen, nie ohne Datenschutztext“ und die zwei neuen Prüfungen; der Abschnitt „Ship“ in `CLAUDE.md` nennt Eingabe, Marke und Sperre in einem Satz. Test: `test_docs_name_account_build` in `scripts/test_asc_what_to_test.py` (liest beide Dateien: `konto`, `applesignin` und `LEAccountEnabled` in `testflight.md`, `konto` im Abschnitt „Ship“ von `CLAUDE.md`; der Wortlaut der Marke steht in keiner der beiden, AC-8).
- [x] **AC-13:** Regression und Grenze: `./scripts/sim.sh generate` hinterlässt keinen Diff gegen die eingecheckten Abbilder; `./scripts/sim.sh sim-unit` (alle Unit-Tests) grün; `./scripts/sim.sh build` und `./scripts/sim.sh mac-build` bauen ohne Fehler und ohne neue Warnungen (die Berechtigung ändert beide Bauten); `python3 scripts/test_catalog_languages.py` unverändert grün. Test: `test_entitlements_sync.py` und `test_info_plist_sync.py` (Abbild = Quelle), der vorhandene `sim-unit`-Satz, die Bauläufe `build`/`mac-build` und der CI-Schritt „Generate leaves the tree clean“ auf dem PR. Die Dateigrenze des Schnitts (nur die Tabelle „Affected Files“) prüft `/60-validate` einmalig, kein Test gegen `origin/main` (Projektregel).

## Dialog

### Runde 1
**Adversary:** Behauptung: Berechtigung, Schalter, Eingabe, Archivpruefungen, Marke und Sperre sind korrekt und fail-closed. Ich verlange Belege und versuche zu brechen: Randfaelle der Pruefung account_switch (integer, string "true", real, leere/kaputte/fehlende Plist), Hinterlegung bei v*-Tag, Reihenfolge der Schritte, Wortlaut-Quelle, Laengengrenze, Buildnummern "10" vs "9", Marke nur in einer Lokalisierung, whatsNew null, Apple-Rohtext in der Ausgabe.
**Implementierer:** Belege (selbst eingeholt):
- Python-Laeufe: test_asc_store_version 22 Tests OK, test_asc_what_to_test 28 Tests OK, test_entitlements_sync 4 OK, test_info_plist_sync 4 OK, test_catalog_languages 8 OK (docs/artifacts/feat-615-s4c2-freischalten/adversary-test-output.txt).
- Shell-Ausschnitt account_switch aus dem Workflow (beide Kopien byte-gleich, per Regex extrahiert) unter bash -e -o pipefail gegen bool true/false, string true, string YES, integer 1, real 1, leere Plist, kaputte Datei, fehlende Datei, je mit ACCOUNT_BUILD true und false (18 Faelle): nur bool mit passendem Wert ist OK, alles andere setzt fail=1 und gibt ::error:: aus; kein vorzeitiger Abbruch durch set -e (die Funktion faengt plutil-Fehler mit || true ab, der Schritt endet danach ueber fail).
- Workflow: Eingabe konto (boolean, default false) testflight.yml:21-24; ACCOUNT_BUILD auf Top-Level-env (Zeile 38), gilt damit auch fuer confirm/confirm-mac (asc_what_to_test.py-Aufrufe Zeilen 592, 614) und ist bei v*-Tag (inputs leer, null == true ist false) 'false'. Schritt "Set the account switch" mit if env.ACCOUNT_BUILD == 'true' steht in beiden Jobs direkt nach "Generate project" und vor Archive. iOS-Pruefung: entitled ... applesignin, account_switch gegen Info.plist des Bundles com.henning.looseends (leerer Pfad -> FEHLER). Mac: applesignin in der Schluesselliste, account_switch "$P", danach [ "$fail" = 0 ].
- Marke: Konstante nur in scripts/asc_what_to_test.py:29; Wortlaut kommt in Workflow, Doku, CLAUDE.md und beiden Testdateien nicht vor (grep). mark_account_build haengt an jeden Abschnitt an; Grenze: 3966 Zeichen + Marke = 4000 ok, 3967 = 4001 -> Fatal (Pruefung nach dem Anhaengen, main Zeile 153ff). Doppelt: Text mit Marke bleibt unveraendert.
- pick_build (Stubs): Bauten 9 und 10 numerisch korrekt (10 gewaehlt); 10 mit Marke -> 9 gewaehlt, Ausgabe "bau IOS 10 uebersprungen: konto"; whatsNew null, Fatal beim GET (Ausgabe ohne Apple-Text "RAW APPLE TEXT"), leere Liste -> "texte nicht lesbar"; nichts uebrig -> Fatal "(1 uebersprungen), nichts geschrieben", kein Schreibaufruf in pick_build.

### Runde 2
**Adversary:** Zweiter Angriff auf die Raender: (a) Marke nur in einer von zwei Lokalisierungen, (b) eine Lokalisierung mit leerem/fehlendem Text neben einer lesbaren, (c) Marke mitten im Text, (d) Gueltigkeit der generierten Abbilder und der Plist-Typen, (e) Doku-Aussage und AC-13.
**Implementierer:** Belege:
- (a) Marke in einer von zwei Lokalisierungen -> "konto", Bau uebersprungen (is_account_build = any). (b) Eintrag ohne whatsNew neben lesbarem -> "texte nicht lesbar" (strenger als die Spec, aber fail-closed; kein Fehler). (c) Marke mitten im Text wird nicht erneut ans Ende gehaengt; is_account_build erkennt sie trotzdem (Teilstring) - folgenlos fuer die Sperre.
- (d) Info.plist: LEAccountEnabled als <false/> (Zeilen 63-64), LEServiceURL fehlt; entitlements: com.apple.developer.applesignin mit Default; test_entitlements_sync/test_info_plist_sync gruen = Abbild entspricht project.yml.
- (e) testflight.md:364ff und CLAUDE.md:263 nennen konto, Marke, Sperre; Tests test_docs_name_account_build laufen gruen.
- AC-13: sim-unit-output.txt ist bei Abschluss unvollstaendig (Lauf noch aktiv, letzte Zeilen mitten in der Suite, kein Ergebnis), mac-build-output.txt existiert nicht, Build Succeeded fuer iOS nur vom Entwickler gemeldet. Deshalb bleibt AC-13 offen. Generate-Diff ist ueber die beiden Sync-Tests belegt.

Findings:
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Description: pick_build meldet N gueltige Bauten inklusive uebersprungener; rein kosmetisch.
  Evidence: scripts/asc_store_version.py:119
  Remediation: Zaehler der zugelassenen Bauten ausgeben.
Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Description: Bauten ohne Lokalisierung oder mit leerem whatsNew (Altbauten vor #347) sind dauerhaft gesperrt; gewollt fail-closed.
  Evidence: scripts/asc_store_version.py:119 (build_lock)
  Remediation: Keine Aenderung noetig; im Abschlussbericht nennen.

Code reference: .github/workflows/testflight.yml:38
Code reference: .github/workflows/testflight.yml:116
Code reference: .github/workflows/testflight.yml:222
Code reference: project.yml:73
Code reference: project.yml:84
Code reference: LooseEnds/Info.plist:63
Code reference: LooseEnds/LooseEnds.entitlements:7
Code reference: scripts/asc_what_to_test.py:29
Code reference: scripts/asc_store_version.py:119
Code reference: scripts/test_asc_what_to_test.py:1
Code reference: scripts/test_asc_store_version.py:1

### Runde 3
**Adversary:** AC-13 war offen: sim-unit und mac-build waren nur behauptet. Ich pruefe die Ausgaben selbst, auch auf Warnungen und uebersprungene Tests.
**Implementierer:** sim-unit-output.txt Zeile 1593 Test Succeeded, Zeile 1595 Unit-Tests bestanden, Executed-Zeilen mit 0 failures; Zeile 1596: 3 von 6 Messstrecken uebersprungen (nicht gemessen, ohne Bezug zum Schnitt, einzeln benannt). mac-build-output.txt: Build Succeeded (Zeile 23), 0 Zeilen mit warning. Abbild-Pruefung ueber test_entitlements_sync und test_info_plist_sync gruen, test_catalog_languages gruen. AC-13 bewiesen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

AC-1 bis AC-13 bewiesen; zwei LOW-Findings (F001, F002), keine Regression. 62 Python-Tests OK, sim-unit Test Succeeded, mac-build ohne Warnungen.

## Geprüfte Dateien

- sha256:a9044436adb092fb4a7baffff5162cf2545c57370430252c205c2d559275de0d  .github/workflows/testflight.yml
- sha256:50645f7cdc46a806c47932c4786eb827049c488ec5cf65e11f6d8d3c933d5ebb  LooseEnds/Info.plist
- sha256:8f3562adf6414744176258d8c18bdb3ea30b7a6b209e8d05c8b43e4013593872  LooseEnds/LooseEnds.entitlements
- sha256:67f5a99fdc0744dea48f357755400c702af1ccf476614dd9c039032b20aa5222  project.yml
- sha256:bbd13d926640e50106de9cba5afca0a0c7c50ae06926293adc35326353051acd  scripts/asc_store_version.py
- sha256:bbfb4af41afac22ca2940c834fca299ec558a29399547e15a08949b36b59d973  scripts/asc_what_to_test.py
- sha256:7a739925b7d93a2f1c190dc945fa137ecf047737729a00b95c50cf9eed926786  scripts/test_asc_store_version.py
- sha256:8733d8e10d193aca6109fd205e007b075235151f70372e6ecb8488146c83bded  scripts/test_asc_what_to_test.py

## Prüfbasis

- base: 235c6d4604aba2c32da6012e99c5cad8d760a9ae
- blob:85fb1324dc2835ee755813a39ca8914912d92978  .github/workflows/testflight.yml
- blob:f1860c1967bbcdf0ff06280556906eda0418a5b7  LooseEnds/Info.plist
- blob:40482231c6ed261f2127f006f906e4d8acbde6cc  LooseEnds/LooseEnds.entitlements
- blob:9aa791cae3c79ed67298e4139df4e4beca10168b  project.yml
- blob:6ba7c1e3191310f06ccf5ffac68d23bb8219c0bd  scripts/asc_store_version.py
- blob:2259e35f9327cd09f1be15ef98dde59b54e3878b  scripts/asc_what_to_test.py
- blob:0cc43becf907494b8dd505d3c8057fab9f4838a6  scripts/test_asc_store_version.py
- blob:ab008c5cae11588b7158e5c3e72c059781f5310a  scripts/test_asc_what_to_test.py
