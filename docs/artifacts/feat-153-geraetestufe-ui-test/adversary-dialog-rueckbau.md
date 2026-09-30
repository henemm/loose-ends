# Adversary-Dialog: Rueckbau der Geraetestufe (#153)

Geprueft gegen docs/specs/tooling/feat-153-geraetestufe-ui-test.md. Alle Befehle unten wurden von
mir selbst ausgefuehrt (nicht aus den vorliegenden Belegdateien zitiert), Stand HEAD bb3170a
(Arbeitsstand, Rueckbau in scripts/tests/ noch als staged Deletion, sim.sh bereits zeichengleich
mit dem Vor-#153-Stand). Kein angeschlossenes iPhone wurde angesprochen - keine devicectl-,
xcodebuild-Geraete-Destination- oder ./scripts/sim.sh device*-Aufrufe ausser dem rein lesenden
device-status-Codepfad, der nicht ausgefuehrt, nur gelesen wurde.

### Runde 1

- [x] AC-1 device-test wird abgewiesen: ./scripts/sim.sh device-test X liefert
      "[sim] Unbekannter Befehl: device-test", exit=1. Kein device-test)-Zweig mehr im Dispatch
      (scripts/sim.sh:449-461).
- [x] AC-2 alle acht Bezeichner 0 Treffer (cmd_device_test, device_probe_locked,
      acquire_device_lock, release_device_lock, cleanup_locks, MAIN_BUNDLE_ID, DEVICE_LOCK_DIR,
      DEVICE_LOCK_ACQUIRED), einzeln gegrept.
- [x] AC-3 trap release_lock EXIT genau einmal (scripts/sim.sh:73); cleanup_locks 0 Treffer.
- [x] AC-4 scripts/tests/device-test.sh nicht mehr auf der Platte (WEG), git ls-files leer.
- [x] AC-5 git ls-files scripts/tests/ liefert keine Zeile.
- [x] AC-6 git grep -n "device-test" -- scripts CLAUDE.md docs/project LooseEndsUITests leer
      (rc=1); Gegenprobe git grep -l "device-test" -- docs/context docs/specs liefert 2 Dateien.
- [x] AC-7 ./scripts/sim.sh unit selbst ausgefuehrt: "Test Succeeded",
      "[sim] Unit-Tests bestanden.", keine fehlgeschlagene Suite in der kompletten Ausgabe.
      docs/reference/ danach per git checkout -- docs/reference/ zurueckgesetzt.
- [x] AC-8 ./scripts/sim.sh test RecognitionWalkthroughTests selbst ausgefuehrt, eigener
      Hintergrundlauf endete mit exit code 0 und "[sim] UI-Test bestanden.". Testergebnis auch im
      xcodebuild-Log: "Test Suite 'RecognitionWalkthroughTests' passed at 2026-09-30 11:00:31",
      "Executed 1 test, with 0 failures (0 unexpected) in 119.665 seconds".
- [x] AC-9 cmd_device_status (scripts/sim.sh:264-269) ruft ausschliesslich
      "$DEVICECTL device info details --device $id | grep ..." - kein install/launch/xcodebuild.
- [x] AC-10 docs/project/04-stand.md enthaelt "device-status" (Zeile 149) und NICHT mehr
      "3....device-test" als Stufe-3-Befehl (Regex-Gegenprobe liefert rc=1).
- [x] AC-11 docs/project/00-entscheidungen.md:136 "kein Fernstart einer App"; der alte Satz
      "Smoke-Test zusaetzlich auf dem angeschlossenen iPhone" kommt nirgends mehr vor.
- [x] AC-12 CLAUDE.md:83 verweist auf device-status; "der volle Bedienablauf ueber" kommt nicht
      mehr vor.
- [x] AC-13 git diff --stat main...HEAD -- Shared/ LooseEnds/Views/ liefert keine Ausgabe.

Zwischenstand Runde 1: alle 13 AC durch eigene Befehlsausfuehrung bestaetigt, keine der
vorgelegten Belegdateien blind uebernommen.

### Runde 2 - die sechs geforderten Tiefenpruefungen

1. Ist scripts/sim.sh zeichengenau zurueckgebaut? Vergleich gegen bd96461 (Stand unmittelbar vor
   dem #153-Aufbau) und gegen HEAD sind beide leer; md5 der Arbeitskopie und des bd96461-Standes
   sind identisch (d7d9265d574241867fb4552268073c40), beide 461 Zeilen. Die Datei ist damit
   byte-identisch mit dem Stand vor #153 - eine staerkere Garantie als die Spec verlangt. Gezielt
   nach Resten gesucht (device_lock, xctrunner, uitests, deviceprep, LOOSEENDS_ARTIFACT_DIR) - keine
   Treffer. PIPESTATUS-Vorkommen (scripts/sim.sh:285,315) gehoeren zu cmd_device_build/
   cmd_device_install, die es schon vor #153 gab, nicht zum entfernten Code.
2. Ist der Hilfetext heil? cmd_help (scripts/sim.sh:435) macht sed -n 3,29p. Kopfkommentar geht
   real bis Zeile 30 (Signier-Team-Zeile); Zeile 29 "Geraet per UDID..." ist die letzte gedruckte
   Zeile, Zeile 30 fehlt korrekt in der tatsaechlichen device-test X-Fehlerausgabe. Keine
   abgeschnittene, keine ueberzaehlige Zeile.
3. Laeuft der Befehl noch auf einem anderen Weg? .github/workflows/ci.yml vollstaendig gelesen:
   drei Jobs (unit-tests, ios-build, ui-smoke), alle auf Simulator/macOS-Destination, kein Bezug zu
   device-test oder scripts/tests/. Repoweite Suche ueber project.yml, README.md, .claude/
   (ungetrackt) - keine Treffer.
4. Sind die drei Testeingriffe unangetastet? Diff gegen main zeigt: garden.isSelected-Bedingung
   (aktuell Zeilen 157-165), topRow(in:) (Zeilen 62-70) mit detailRawText-Abgleich (Zeilen
   178-188), Rueckkehr ueber app.buttons["captureButton"] (Zeilen 172-176) - alle drei vorhanden,
   funktional bewiesen durch den gruenen Lauf aus AC-8. Referenzierte Accessibility-Identifier
   existieren im Produktcode (LooseEnds/Views/TaskDetailView.swift:47 detailRawText,
   LooseEnds/App/ContentView.swift captureButton) - kein toter Testverweis.
5. Widersprechen sich die vier Dokumente? Keine Stelle mit "Smoke-Test ... Geraet" oder "voller
   Bedienablauf" gefunden. device-console wird in docs/project/04-stand.md:164-166 korrekt als
   "Begruendung hinfaellig" (nicht "entfernt") beschrieben - deckt sich mit dem tatsaechlichen Code,
   der cmd_device_console unveraendert (vorbestehend, ausserhalb des Scopes von #153) weiterfuehrt.
6. Ist die Nachweisluecke benannt? docs/project/04-stand.md:172-176 und CLAUDE.md:84-87 nennen
   beide ausdruecklich Watch, Widgets, Share, Mikrofon, Mitteilungen als ungedeckt, mit
   #156/#143/#160.

### Runde 2 - Funde jenseits der gestellten Fragen

Finding:
  ID: F001
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:3
  Description: Der erste Satz des Kopfkommentars wurde ebenfalls umformuliert ("der Ablauf, den
    jemand ohne Apple Intelligence erlebt" auf main, Zeile 3, wurde zu "der
    Wiedererkennungs-Ablauf" in der Arbeitskopie), obwohl die Spec nur den zweiten Absatz
    ("--ui-testing schaltet...") als Ersatztext ausweist ("Ersetzt Z. 7-13").
  Spec requirement: Implementation Details, Abschnitt 3 - spezifiziert nur den zweiten Absatz als
    Ersatztext, der erste Satz soll unveraendert bleiben.
  Conflict: Der erste Satz wurde zusaetzlich veraendert; ob das waehrend des #153-Aufbaus oder
    waehrend dieses Rueckbaus geschah, laesst sich nicht mehr rekonstruieren, da der Zwischenstand
    (die #153-gebaute Fassung vor diesem Rueckbau) nie committet wurde.
  Remediation: Funktional folgenlos (reiner Docstring, kein device-test-Bezug, AC-6 bleibt gruen).
    Beim naechsten Griff an diese Datei den ersten Satz auf main-Wortlaut zuruecksetzen oder die
    Abweichung in der Spec nachtragen.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: spec_violation
  Code reference: docs/specs/tooling/feat-153-geraetestufe-ui-test.md:561-566
  Description: Zwei explizite Definition-of-Done-Punkte sind zum Pruefzeitpunkt nicht erfuellt.
    gh issue view 153 liefert weiterhin Titel "Geraetestufe: gezielte Sonden statt nachgespielter
    Bedienablaeufe" und eine DoD-Liste im Issue-Body, die den abgebauten Befehl beschreibt
    ("scripts/sim.sh bekommt einen Befehl, der einen benannten UI-Test auf dem Geraet faehrt
    (Vorschlag: device-test <Testpfad>)..."). gh issue view 155 zeigt state OPEN, nicht wie
    gefordert mit Begruendung geschlossen.
  Spec requirement: Definition of Done - "Issue #153: Titel, Body und DoD-Liste werden beim
    Abschluss auf den tatsaechlichen Rueckbau nachgezogen" und "#155 ... mit Begruendung
    geschlossen".
  Conflict: Beide Punkte sind zum Pruefzeitpunkt unerledigt, nachgewiesen per gh issue view, nicht
    nur behauptet.
  Remediation: Vor dem Merge Issue #153 (Titel, Body, DoD-Liste) auf den tatsaechlichen Rueckbau
    umschreiben und #155 mit Begruendung schliessen - beides bereits in der Spec vorformuliert
    (Abschnitt "Abweichung vom Tech-Lead-Kommentar", Dependencies-Tabelle).

### Bestaetigungen (Confirmations)

Confirmation:
  AC: AC-1
  Code reference: scripts/sim.sh:449-461
  Evidence: Kein device-test)-Zweig im Dispatch; Live-Aufruf liefert "Unbekannter Befehl", exit 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/sim.sh (volltextdurchsucht)
  Evidence: Alle acht Bezeichner einzeln gegrept, je 0 Treffer.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/sim.sh:73
  Evidence: trap release_lock EXIT einmal vorhanden, cleanup_locks 0 Treffer.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/tests/device-test.sh (nicht vorhanden)
  Evidence: test -f liefert WEG, git ls-files leer.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/tests/ (Verzeichnis)
  Evidence: git ls-files scripts/tests/ liefert keine Zeile.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/sim.sh, CLAUDE.md, docs/project/, LooseEndsUITests/ (repoweit
    durchsucht)
  Evidence: git grep leer (rc=1); Gegenprobe liefert 2 Begruendungsdokumente.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/sim.sh:194-198 (cmd_unit)
  Evidence: Eigener Lauf "Test Succeeded", keine fehlgeschlagene Suite in kompletter Ausgabe.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:17-186
  Evidence: Eigener Lauf endete exit 0, "[sim] UI-Test bestanden."; xcodebuild.log "Test Suite
    'RecognitionWalkthroughTests' passed ..., 0 failures".
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/sim.sh:264-269
  Evidence: Nur device info details, kein install/launch/xcodebuild.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: docs/project/04-stand.md:149-176
  Evidence: "device-status" vorhanden, "3....device-test" nicht mehr.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/project/00-entscheidungen.md:136
  Evidence: "kein Fernstart einer App" vorhanden, alter Satz weg.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: CLAUDE.md:83-87
  Evidence: "device-status" vorhanden, "der volle Bedienablauf ueber" weg.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: Shared/, LooseEnds/Views/ (Diff-Bereich)
  Evidence: git diff --stat main...HEAD -- Shared/ LooseEnds/Views/ leer.
  Status: CONFIRMED

### Runde 3 - Behebung von F001, Herkunft geklaert

Der Orchestrator hat die in F001 offen gebliebene Herkunftsfrage entschieden, statt sie
weiterzuschieben. Beleg, der den Zwischenstand doch rekonstruiert: `git diff bd96461 --
LooseEndsUITests/RecognitionWalkthroughTests.swift` (bd96461 ist der letzte Commit VOR dem
#153-Aufbau) zeigte fuer Z. 3-5 die Umformulierung. Damit stammt sie aus dem #153-Aufbau, nicht
aus dem Rueckbau, und die Spec hatte sie in ihrer Source-Liste uebersehen.

Sachliche Entscheidung: Die Verallgemeinerung von "der Ablauf, den jemand ohne Apple Intelligence
erlebt" zu "der Wiedererkennungs-Ablauf" entstand nur, weil derselbe Test laut #153 zusaetzlich
MIT Apple Intelligence auf dem Geraet laufen sollte. Diese Abnahmestufe existiert nach dem
Rueckbau nicht mehr - der Test laeuft ausschliesslich im Simulator, also ohne Apple Intelligence.
Die urspruengliche Formulierung ist damit wieder die zutreffende, und der Absatz gehoert zum
Rueckbau.

Ausgefuehrt: Z. 3-5 zeichengleich auf den Stand von bd96461 zurueckgesetzt. Bewusst ueber die
Source-Liste der Spec hinaus, offen benannt statt stillschweigend - die Spec haette diese Zeile
nennen muessen.

- [x] F001 behoben: `git diff bd96461 -- LooseEndsUITests/RecognitionWalkthroughTests.swift` zeigt
      fuer Z. 3-5 keinen Unterschied mehr; der erste Hunk beginnt erst bei Z. 5 als Kontextzeile.
      Code reference: LooseEndsUITests/RecognitionWalkthroughTests.swift:3
- [x] Keine Nebenwirkung: Abwesenheitspruefung nach der Korrektur erneut GREEN, Exit 0, alle 19
      Zeilen PASS (`docs/artifacts/feat-153-geraetestufe-ui-test/rueckbau-green-output.txt`).
- [x] Testnachweis nach der Korrektur: `./scripts/sim.sh test RecognitionWalkthroughTests` erneut
      im Simulator gefahren und gruen - eine Aenderung an einer Testdatei gilt erst als bewiesen,
      wenn der Test danach wieder laeuft. Beleg:
      `docs/artifacts/feat-153-geraetestufe-ui-test/rueckbau-testlaeufe.txt`.

F002 bleibt bewusst offen und ist kein Umsetzungsmangel: Titel, Body und DoD-Liste von Issue #153
nachziehen und #155 mit Begruendung schliessen sind Abschlussarbeiten, die die Spec ausdruecklich
"beim Abschluss" verortet. Sie werden in Phase 8 (Deploy) erledigt und sind dort als Pflichtpunkte
vermerkt.

### Zusammenfassung

13/13 Acceptance Criteria durch eigene Befehlsausfuehrung bestaetigt. Beide unabhaengig laufen
gelassenen Testlaeufe (Unit, UI) gruen, selbst ausgefuehrt, nicht nur aus Belegdateien zitiert.
Der Rueckbau von scripts/sim.sh ist nachweislich byte-identisch mit dem Vor-#153-Stand - keine
Restspur. Zwei nicht blockierende Funde: F001 (LOW, kosmetische Docstring-Abweichung ohne
AC-Bezug) und F002 (MEDIUM, zwei offene Definition-of-Done-Punkte zur Issue-Pflege - kein
Code-Defekt, muss aber vor dem eigentlichen Ticketabschluss noch passieren).

===========================================
VERDICT: VERIFIED
===========================================
Der Rueckbau haelt der Adversary-Pruefung stand.
Tests: 229 Unit-Tests gruen (0 fehlgeschlagen, selbst ausgefuehrt), 1 UI-Test gruen (0
fehlgeschlagen, selbst ausgefuehrt)
Edge cases: alle sechs geforderten Tiefenpruefungen einzeln nachvollzogen, keine davon gebrochen
Regressions: keine gefunden; kein anderer Aufrufer im Repo erwartet den entfernten Befehl
Checklist: 13/13 Acceptance Criteria bewiesen
Offene, nicht blockierende Funde: F001 (LOW) ist in Runde 3 behoben, mit Testnachweis. F002
(MEDIUM, Issue-Pflege) bleibt offen und gehoert laut Spec in den Abschluss (Phase 8).

## Geprüfte Dateien

- sha256:72a3a368935c42ab6ab9899c78a6c8f21ed0a10c04714c474004a664bf037442  CLAUDE.md
- sha256:92a6ccf2b8e8880dedaa485c4be3ad1e401c6b5e22693ab7feb95379dc44a0d3  LooseEndsUITests/RecognitionWalkthroughTests.swift
- sha256:c30797b07e2d5adecc5e6ce9c4b8e3f334679e143f2329461d318ed4611af1f0  docs/project/00-entscheidungen.md
- sha256:a1ebf57db78faaac52e71160f36ccf151cd83aafb4d8630d9541064b5f06d657  docs/project/04-stand.md
- sha256:55cd502ccf6dd41e4fd63be0a64e4b414432d6b40933d3f694b6c456ec895fb5  docs/specs/tooling/feat-153-geraetestufe-ui-test.md
- sha256:6dab304eb5793ce63804d00cc1ed6d73ce045a3bd8b69b2ae88870da9e5c9d4f  scripts/sim.sh

Anmerkung zum Werkzeug: `adversary_dialog.py stamp` hängt diesen Block an, statt ihn zu ersetzen.
Nach dem zweiten Stempellauf (nötig, weil die F001-Korrektur eine der gehashten Dateien änderte)
stand er doppelt in der Datei; das Duplikat wurde entfernt. Die Prüfsummen oben sind der Stand nach
der F001-Korrektur — `LooseEndsUITests/RecognitionWalkthroughTests.swift` trägt sha256:92a6ccf2…,
nicht mehr den Stand von vor der Korrektur.
