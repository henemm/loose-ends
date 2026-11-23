# Adversary Dialog — feat-625-s5b-schalter-quelle
Spec: docs/specs/feat-625-schnitt-5b-schalter-quelle.md
Datum: 2026-11-23 13:33

## Checkliste
- [x] **AC-1:** GIVEN `project.yml` WHEN `info.properties` des Ziels `LooseEnds` gelesen wird THEN ist `LEAccountEnabled` das Bool `true` (kein String), `LEServiceURL` bleibt ungesetzt, und die Kommentare an `LEAccountEnabled` und `com.apple.developer.applesignin` sagen nicht mehr „off by default“, „without effect while LEAccountEnabled is off“ oder „only a TestFlight run with konto“, sondern „an der Quelle an (#625 S5b)“. Test: `scripts/test_asc_what_to_test.py` `AccountBuildSourceTests.test_account_switch_is_a_true_bool` (umgedrehter `test_account_switch_is_a_false_bool`), Kommentare durch Lesen und Diff.
- [x] **AC-2:** GIVEN `LooseEnds/Info.plist` WHEN sie gelesen wird THEN trägt sie `LEAccountEnabled` als Bool `true` und kein `LEServiceURL`; GIVEN `./scripts/sim.sh generate` WHEN er läuft THEN hinterlässt er keinen Diff (`git status --porcelain` leer für `LooseEnds/`). Test: derselbe umgedrehte Test (zweiter Teil prüft `Info.plist`), `scripts/test_info_plist_sync.py` grün; Beleg `generate.txt`.
- [x] **AC-3:** GIVEN `LooseEnds/PrivacyInfo.xcprivacy` WHEN der Test sie liest THEN steht in `NSPrivacyCollectedDataTypes` genau die Liste `ACCOUNT_TYPES` (UserID, DeviceID, OtherUserContent; je Linked true, Tracking false, Zweck AppFunctionality); GIVEN eine Kopie der Quelle WHEN `privacy_manifest.py apply` darauf läuft THEN ist sie inhaltlich unverändert (Plist-Vergleich), und alle anderen Schlüssel (`NSPrivacyTracking`, `NSPrivacyAccessedAPITypes` mit CA92.1) sind unverändert. Test: `scripts/test_privacy_manifest.py` `CheckTests.test_source_carries_the_three_types_and_passes_only_with_account` (ersetzt `test_source_is_empty_and_passes_only_without_account`).
- [x] **AC-4:** GIVEN die Quelle WHEN `python3 scripts/privacy_manifest.py check LooseEnds/PrivacyInfo.xcprivacy --account true` läuft THEN endet es mit 0; WHEN `--account false` läuft THEN endet es ungleich 0 mit der Meldung zu `NSPrivacyCollectedDataTypes`. Test: derselbe Test wie AC-3; die übrigen Tests von `test_privacy_manifest.py` (Fehlerfälle, `apply`) bleiben in Aussage unverändert grün.
- [x] **AC-5:** GIVEN die Manifest-Quelle WHEN sie neu geschrieben wird THEN geschieht das nur mit `python3 scripts/privacy_manifest.py apply LooseEnds/PrivacyInfo.xcprivacy` (byte-gleich zu dem, was der Konto-Lauf in CI erzeugt, keine Handkopie); GIVEN der Docstring von `scripts/privacy_manifest.py` WHEN er gelesen wird THEN beschreibt er, dass die Quelle die drei Typen trägt und `check --account` weiter beide Zustände prüft (kein „Store-Bauten leer“ mehr). Beleg: `apply.txt` (Befehl, Ausgang 0, `git diff --stat` nur diese Datei), Lesen des Docstrings.
- [x] **AC-6:** GIVEN alle Python-Tests WHEN `python3 -m unittest discover -s scripts -p 'test_*.py'` läuft THEN ist der Lauf grün, einschließlich `test_info_plist_sync.py`, `test_app_store_datenschutzangaben.py` und der Konto-Bau-Prüfungen in `test_asc_what_to_test.py`; der RED-Lauf vor der Änderung (die beiden umgedrehten Tests rot gegen die alte Quelle, Beleg `red.txt`) und der grüne Lauf danach (`green.txt`) liegen im Belegordner.
- [x] **AC-7:** GIVEN die Gesamt-Diffliste WHEN sie geprüft wird THEN enthält sie genau diese Pfade: `project.yml`, `LooseEnds/Info.plist`, `LooseEnds/PrivacyInfo.xcprivacy`, `scripts/privacy_manifest.py`, `scripts/test_privacy_manifest.py`, `scripts/test_asc_what_to_test.py`, `CLAUDE.md`, die Spec, die Kontextdatei und den Belegordner; `.github/workflows/testflight.yml` und jede Swift-Datei sind nicht darin. Beleg: `dateiliste.txt` (`git diff --name-only origin/main...HEAD`).
- [x] **AC-8:** GIVEN der Unit-Lauf im Simulator WHEN `./scripts/sim.sh unit` mit der neuen Quelle läuft THEN endet er grün ohne Absturz des Test-Hosts (der Unit-Host baut jetzt `AccountState` mit `KeychainSessionStore`), und kein Test ist neu übersprungen; jede „übersprungen“-Zahl wird mit Namen belegt. Beleg: `unit.txt`.
- [x] **AC-9:** GIVEN die App im iOS-Simulator, gebaut und installiert aus dem Arbeitsstand, WHEN sie **ohne** `--ui-testing` gestartet und die Einstellungen geöffnet werden THEN zeigt die Gruppe „Claude“ direkt unter iCloud ihre Zeile für „Mit Apple anmelden“ (abgemeldet, kein Netzverkehr, nichts wird ohne Tippen gesendet), und die App startet ohne Absturz. Beleg: Screenshot `einstellungen-claude.png` (geöffnet und beschrieben, nicht gezählt) und `launch.txt` mit Befehl und Start ohne `--ui-testing`; Stufe 2.
- [x] **AC-10:** GIVEN `CLAUDE.md` WHEN der Absatz zu `AccountWiring` (Abschnitt „Where things live“, `LooseEnds/Claude`) und der Absatz zum Eingang `konto` im Abschnitt „Ship“ gelesen werden THEN steht dort: `LEAccountEnabled` ist in `project.yml` `true` (Schalter an der Quelle, #625 S5b), das Manifest trägt die drei Typen, fehlender oder fremder Typ blendet die Gruppe weiter aus; der Eingang `konto` ist bis S5c ohne Wirkung auf den Inhalt und wird dort zurückgebaut; kein Satz behauptet mehr „`project.yml` holds `false`“. Beleg: Lesen und Diff (`claude-md.txt`).

## Dialog

### Runde 1
**Adversary:**
Eigener Lauf der Python-Suite in scripts: Ran 806 tests in 643.5s, Ergebnis OK mit 1 Skip, Beleg adversary-test-output.txt.
Der Skip ist test_datenschutz_text LiveTests test_live_pages (nur mit gesetzter Live-Variable), vorbestehend, nicht neu. Also 805 bestanden, 0 fehlgeschlagen, 1 uebersprungen.
Eigene Pruefungen: check mit account true endet mit 0, mit account false mit 1 und der Meldung zu NSPrivacyCollectedDataTypes. Plist-Vergleich gegen main: einziger geaenderter Schluessel ist NSPrivacyCollectedDataTypes, vorher leer, jetzt 3 Eintraege; NSPrivacyTracking und NSPrivacyAccessedAPITypes mit CA92.1 gleich.
Die Kopie der Quelle ist nach apply byte-gleich. project.yml LEAccountEnabled ist YAML-Bool True, LEServiceURL fehlt; Info.plist true, kein LEServiceURL. Im Diff gegen main keine Swift-Datei und kein testflight.yml; Watch, Widgets, Share nicht im Diff.

Confirmation:
  AC: AC-1
  Code reference: project.yml:86
  Evidence: LEAccountEnabled true als Bool, kein LEServiceURL; Kommentare nennen on at the source (#625 S5b), kein off by default mehr. Der umgedrehte Bool-Fall ist gruen im Eigenlauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Info.plist:63
  Evidence: Schluessel LEAccountEnabled gefolgt von true; Diff gegen main genau diese Zeile; generate.txt zeigt drei Laeufe mit gleichem Diff, nur diese Datei.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/PrivacyInfo.xcprivacy:16
  Evidence: NSPrivacyCollectedDataTypes traegt die drei ACCOUNT_TYPES; sonst nichts gegenueber main geaendert; apply auf Kopie byte-gleich.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/test_privacy_manifest.py:106
  Evidence: Der Fall test_source_carries_the_three_types_and_passes_only_with_account prueft true und false; eigener CLI-Lauf 0 bzw. 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/privacy_manifest.py:3
  Evidence: Docstring beschreibt drei Typen an der Quelle und beide Zustaende von check; Store-Bauten leer entfernt. Manifest byte-gleich zum apply-Erzeugnis, apply.txt vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_asc_what_to_test.py:280
  Evidence: red.txt (committet) und green.txt vorhanden; Eigenlauf der Gesamtsuite gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/artifacts/feat-625-s5b-schalter-quelle/dateiliste.txt:1
  Evidence: Neu erzeugte Diffliste: nur die gelisteten Pfade plus Briefing (siehe F001); keine Swift-Datei, kein testflight.yml.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/artifacts/feat-625-s5b-schalter-quelle/unit.txt:2885
  Evidence: unit.txt Passed, total 1422, passed 1409, failed 0, skipped 13, alle 13 einzeln benannt (Mess-, Modell-, Sprachfaelle), kein Neustart des Hosts. Von mir nicht neu gefahren (Simulator), Beleg gelesen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: docs/artifacts/feat-625-s5b-schalter-quelle/launch.txt:1
  Evidence: Start ohne --ui-testing, Prozess lebt nach ueber 30 s; einstellungen-claude.png zeigt laut simulator-run.txt die Gruppe Claude mit echtem Mit-Apple-anmelden-Knopf direkt unter iCloud, abgemeldet. Wegwerf-Probe (Quelltext in launch.txt) geloescht, nicht im Diff.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: CLAUDE.md:502
  Evidence: Zeile 502 nennt project.yml holds true, drei ACCOUNT_TYPES, Fallback off; Zeile 295 nennt konto on by default, never on a tag, ohne Wirkung bis S5c. Gegenprobe testflight.yml:21-23: konto default true, ACCOUNT_BUILD false nur bei Tag oder konto aus; die Aussage stimmt. Kein Satz holds false mehr.
  Status: CONFIRMED

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: docs/briefings/feat-625-s5b-schalter-quelle.md:1
  Description: Das Briefing steht im Diff gegen main, ist aber in der Pfadliste von AC-7 nicht woertlich genannt (Spec, Kontextdatei, Belegordner).
  Spec requirement: AC-7 - Diffliste enthaelt genau diese Pfade
  Conflict: Woertlich ueberschritten; inhaltlich ein Workflow-Dokument wie Spec und Kontext, kein App-/Konfig-Code, zaehlt nicht zum Dateilimit.
  Remediation: Kein Eingriff noetig; bei der naechsten Spec Briefing in AC-7 aufnehmen. Bewertung: bricht AC-7 nicht.

### Runde 2
**Adversary:**
Randfaelle gebohrt.
a) TestFlight mit konto an (Vorgabe): testflight.yml:122 setzt LEAccountEnabled per plutil auf YES, auf bereits true ein Nullschritt; :124 apply idempotent, belegt byte-gleich; :272 check mit account true gegen die Quelle endet mit 0 im Eigenlauf. Bleibt gruen. Gleiches im macOS-Job :459, :461, :569.
b) konto aus oder v-Tag: ACCOUNT_BUILD ist false (testflight.yml:38), account_switch (:233) erwartet false, Quelle ist true, check mit account false scheitert (Eigenlauf). In der Spec als Seiteneffekt 2 und verbindliche Randbedingung genannt; kein Mangel dieses Schnitts, Betriebsrisiko bis S5c.
c) Watch, Widgets, Share: eigene PrivacyInfo-Dateien, nicht im Diff; LEAccountEnabled dort nicht vorhanden.
d) AccountWiring-Fallback unveraendert, ein Nicht-Bool blendet weiter aus; CLAUDE.md:502 stimmt damit.
e) simulator-run.txt nennt den Namen der geloeschten Wegwerf-Probe: verfaelscht nichts Behauptetes; Quelltext steht in launch.txt, Datei nicht im Diff, Screenshot stammt aus echtem Lauf mit 1 bestanden, 0 uebersprungen. Der erste Teilbefund Einstellungen nicht erreicht ist offen mit Nachtrag dokumentiert.
f) dateiliste.txt war veraltet; Liste neu erzeugt (Diff gegen main plus Status): CLAUDE.md, Info.plist, PrivacyInfo.xcprivacy, red.txt, Briefing, Kontext, Spec, project.yml, privacy_manifest.py, beide Testdateien; unversioniert nur Belege und das Verzeichnis .claude (Arbeitszustand, nicht committen).
g) Umfang: 4 Konfig-Dateien, Limit eingehalten.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: workflows/testflight.yml:38
  Description: ACCOUNT_BUILD ist bei konto aus und bei jedem v-Tag false; die Archivpruefungen account_switch (:233) und check (:272) erwarten dann false, die Quelle liefert true.
  Spec requirement: Randbedingung - testflight.yml bleibt unveraendert, kein Lauf zwischen S5b und S5c
  Conflict: Solche Laeufe scheitern bis S5c, gewollt und in der Spec benannt. Datei nicht geaendert.
  Remediation: S5c direkt nach dem Merge; bis dahin keinen Lauf mit konto aus starten.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/test_privacy_manifest.py:108
  Description: Der Fall macht sys.path.insert und den Import von ACCOUNT_TYPES innerhalb der Funktion.
  Spec requirement: AC-3 - Quelle traegt genau ACCOUNT_TYPES
  Conflict: Nur Stilfrage; Fall korrekt und gruen.
  Remediation: Optional Import an den Modulkopf.

Code reference: CLAUDE.md:295
Code reference: LooseEnds/Info.plist:63

Early-Agreement-Skepsis: keine Verletzung gefunden, aber jede AC wurde mit eigenem Lauf, CLI-Pruefungen, Plist-Vergleich, Bytevergleich, YAML-Typ und gegen testflight.yml nachvollzogen, nicht auf Zusage akzeptiert.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED
Edge cases: alle geprueft, keine gebrochen, F001 bis F003 nur LOW.
Regressions: keine gefunden.
Checklist: alle zehn Punkte bewiesen.
Tests: 805 gruen, 0 rot, 1 uebersprungen (vorbestehend, Live-Seiten nur mit Live-Variable).

## Geprüfte Dateien

- sha256:e2b7de583971c0c0b5da8a27850d89439cbd083079e7008584757107d9379415  CLAUDE.md
- sha256:e13966bad40bf6099fede3841682dc8d17786464547db7c7a8bb1bc744fbf657  LooseEnds/Info.plist
- sha256:f280e9a1a805dfb9806613c0ea9fba61f91149b7cf749acd2572f81926b70e80  LooseEnds/PrivacyInfo.xcprivacy
- sha256:59fbe1f13a1e9cde78256a0b53292acc31f1f684b8bde7c33d58fe543c835c8a  docs/artifacts/feat-625-s5b-schalter-quelle/dateiliste.txt
- sha256:263c8772747375786f0b8e8d4ce22dc6f6638a768b55f6c09cea0597b5b8fdd7  docs/artifacts/feat-625-s5b-schalter-quelle/launch.txt
- sha256:8f59514653351b38ed6654ca6319af2f6102729166437b2c5b88f4b68d48b855  docs/artifacts/feat-625-s5b-schalter-quelle/unit.txt
- sha256:45f244b2bd8c06ea087e5ec1d365f41af041474df44f775d635153bca2f3318f  docs/briefings/feat-625-s5b-schalter-quelle.md
- sha256:ef35764f41e1897a9b4b837a55e8861e974685f33182d76e1b29066320a47370  project.yml
- sha256:e025829adab621b042833add2b29df7762856429647736be4ca8a7e808bb3992  scripts/privacy_manifest.py
- sha256:f6d66a5c4d697d88e914a505cd6a20352e91aab44a685572c71f36020c9f6476  scripts/test_asc_what_to_test.py
- sha256:c6e50087cbae449513addb1f0f23299ff47a0b7055924a837d1e72bf7b695217  scripts/test_privacy_manifest.py

## Prüfbasis

- base: 04f697f4d2fd427b21a87f0946ce3c383c2561a4
- blob:986270e944dc6fefd3d61a21f4e2fd7591e1b5d6  CLAUDE.md
- blob:ace249fcdd7c43a45f1e7d3642f655a1d40637fe  LooseEnds/Info.plist
- blob:4afe277d3b74b22292b89638fad46cbb8ac4cbcc  LooseEnds/PrivacyInfo.xcprivacy
- blob:43c028cdcbd0ef0e560bf7f80c6d18bc4565f661  docs/artifacts/feat-625-s5b-schalter-quelle/dateiliste.txt
- blob:35fcc39a536280e36e0225ac62d1a5585c22071f  docs/artifacts/feat-625-s5b-schalter-quelle/launch.txt
- blob:8d07d04286b5905d47b70f74eb6190debd7b8531  docs/artifacts/feat-625-s5b-schalter-quelle/unit.txt
- blob:e50f78d42b84c34a0e10b646e911de9ccedcd156  docs/briefings/feat-625-s5b-schalter-quelle.md
- blob:cd71566d20eab09710c2fd7738468ab06ece71e6  project.yml
- blob:4d2a64c10c851147f3081c81eb1a1213f0b9195c  scripts/privacy_manifest.py
- blob:05a4b3c7fec32c2c5b3d5b9b968b79146ee1073d  scripts/test_asc_what_to_test.py
- blob:00ef8dc8b7bed98a0f3fabe7acee6a00e6667ee8  scripts/test_privacy_manifest.py
