# Adversary Dialog — fix-341-testlaeufe-verlaesslich
Spec: docs/specs/tooling/fix-341-testlaeufe-verlaesslich.md
Datum: 2026-10-18 11:34

## Checkliste
- [x] **AC-1:** Given ein Mac mit macOS ≥ Deployment Target, When `./scripts/sim.sh unit` ohne `LOOSEENDS_MAC_HOST` läuft, Then ist das Testziel ein iOS-Simulator mit Laufzeit ≥ 27.0 und `platform=macOS` kommt weder in der Ausgabe noch in der Destination vor (Skripttest `test_unit_never_macos_without_switch`).
- [x] **AC-2:** Given `LOOSEENDS_MAC_HOST=1`, When `unit` läuft, Then wählt es den Mac als Host; der Kopfkommentar von `scripts/sim.sh` nennt den Simulator als Standard und den Schalter.
- [x] **AC-3:** Given der Worktree-Ordner `prancy-noodling-axolotl` und kein `CLAUDE_SESSION_ID`, When `sim.sh` das DerivedData bestimmt, Then liegt es unter `LooseEnds-session-prancy-noodling-axolotl` (bereinigter Ordnername, nicht `default`); `device_derived_data` nutzt denselben Schlüssel (Skripttest `test_session_key_from_folder_name`).
- [x] **AC-4:** Given `CLAUDE_SESSION_ID=abc`, When `sim.sh` den Schlüssel bestimmt, Then gewinnt `abc` (Skripttest `test_session_key_override`).
- [x] **AC-5:** Given zwei gleichzeitig gestartete Läufe (zwei Worktrees), When beide eine gesperrte Aktion ausführen (`sim-unit`), Then laufen sie nacheinander; die Ausgabe des zweiten nennt den Halter (Worktree, Befehl, PID), und die Zeiträume beider Läufe überlappen nicht.
- [x] **AC-6:** Given ein Lauf, der per `kill -9` beendet wurde, When der nächste Lauf startet, Then übernimmt er die Sperre sofort (Skripttest `test_orphan_lock_taken_over`), ebenso bei lebender PID mit abweichender Startzeit.
- [x] **AC-7:** Given ein Sperrverzeichnis ohne `pid`-Datei, When ein Lauf startet, Then wartet er und übernimmt erst nach der langen Frist (30 min Standard, in der Prüfung verkürzt).
- [x] **AC-8:** Given ein gesperrter Befehl, der innerhalb desselben Prozessbaums einen weiteren gesperrten Befehl ruft (`test-proof` → `test`), When er läuft, Then blockiert er sich nicht selbst.
- [x] **AC-9:** Given ein belegter Halter, When ein Lauf wartet, Then erscheint alle 30 s genau eine Statuszeile mit Halter, und nach 30 min Wartezeit bricht er mit klarer Meldung und Exit-Code ≠ 0 ab.
- [x] **AC-10:** Given `build`, `unit`, `sim-unit`, `test`, `test-proof`, `launch`, `mac-build`, When sie starten, Then holen alle die Sperre; `run_xcodebuild` ist unverändert benannt, enthält keine Sperre, und `scripts/test_sim_run_xcodebuild.py` sowie `scripts/test_sim_proof.py` bleiben grün (letzterer mit `LOOSEENDS_LOCK_DIR` im Temp-Verzeichnis).
- [x] **AC-11:** Given `CalendarTargetTests`, When die Zeile unter dem Bildrand liegt, Then scrollt der Helfer mit bis zu fünf langsamen Wischversuchen auf die Liste, bis sie existiert, und schlägt sonst mit klarer Meldung fehl; alle fünf Ein-Wischen-Stellen nutzen ihn, die Zusicherungen sind unverändert.
- [x] **AC-12:** Given `allowCalendarAccessIfAsked`, When keine Systemabfrage erscheint, Then kehrt die Funktion nach kurzer Frist zurück statt nach 30 s auf die Zeile zu warten (gemessen an der Laufzeit der Klasse im Protokoll).
- [x] **AC-13:** `./scripts/sim.sh test-proof CaptureSmokeTests` ist zweimal und `RecognitionWalkthroughTests` dreimal hintereinander grün (maschineller Beleg, Screenshots geöffnet und beschrieben); #208 und #168 sind im Ticket als durch #228 erledigt eingeordnet.
- [x] **AC-14:** `ContextUniquenessTests` ist auf einem frisch zurückgesetzten und auf einem benutzten Simulator grün.
- [x] **AC-15:** `CalendarTargetTests` (ganze Klasse) ist mindestens fünfmal hintereinander auf dem benutzten Simulator grün, davon `testSwitchOnShowsTargetCalendar` jedes Mal; der Test ist nicht abgeschwächt.
- [x] **AC-16:** Given zwei Worktrees, When beide gleichzeitig `sim.sh build` und `sim-unit` starten, Then zeigt keiner den Stand des anderen (je eigener DerivedData-Ordner) und die Läufe sind serialisiert; Beleg: beide Ausgaben im Bericht zitiert.
- [x] **AC-17:** Der Build-Abschnitt in `CLAUDE.md` nennt: `unit` läuft im Simulator, Mac-Host nur mit `LOOSEENDS_MAC_HOST=1`, Sperre `/tmp/loose-ends-testlauf.lock`, Bauordner je Worktree; die Handabsprache per Sperrdatei ist als entfallen vermerkt.
- [x] **AC-18:** `scripts/test_sim_lock.py` enthält die neun Fälle aus dem Testplan und wird von der CI ohne Änderung an `ci.yml` erfasst (`unittest discover -s scripts -p 'test_*.py'`); alle Skripttests in `scripts/` sind grün.
- [ ] **AC-19:** Kein Produktcode geändert, `.github/workflows/ci.yml` unverändert. Geräteliste: Kein Pfad der Geräteliste berührt (weder `Shared/Persistence/`, `LooseEnds*/`-Zielpfade, `project.yml`, Entitlements noch Info.plist). Keine sichtbare UI-Änderung, daher keine Entwurfsvorschau. Nach dem Merge ist `bash ~/.claude/scripts/loose-ends-sync-main.sh` gelaufen.

## Dialog

### Runde 1
**Adversary:** Skripttests selbst gelaufen: `python3 -m unittest discover -s scripts -p 'test_*.py'` ergibt 152 Tests OK (Ausgabe: docs/artifacts/fix-341-testlaeufe-verlaesslich/adversary-test-output.txt). test_sim_lock.py enthaelt 16 Testmethoden, darunter die neun Faelle aus dem Testplan. Aenderungsumfang laut Diff-Stat: 6 Dateien, +248/-58 (davon LooseEnds/Info.plist +2 fremd, siehe AC-19); mit dem bereits committeten RED-Test (096c347, +222) liegt die Spec ueber der 250-LoC-Grenze (Spec nennt ca. +250/-20). Funktionen in sim.sh: keine laenger als 50 Zeilen (awk-Pruefung). Die Workflow-Datei ci.yml und das Workflow-Verzeichnis sind unveraendert.

Pruefung je AC mit Code-Beleg:

- AC-1/AC-2: Code reference: scripts/sim.sh:254 (cmd_unit leitet ohne LOOSEENDS_MAC_HOST=1 an cmd_sim_unit, Zeilen 257-262); Kopfkommentar Zeile 9 nennt Simulator und Schalter. Skripttest test_unit_never_macos_without_switch gruen. PROVEN.
- AC-3/AC-4: Code reference: scripts/sim.sh:56 (session_key: CLAUDE_SESSION_ID gewinnt, sonst bereinigter basename, sonst default); device_derived_data nutzt SESSION_ID ungekuerzt. Belegt durch reale Lauf-Logs: DerivedData LooseEnds-session-prancy-noodling-axolotl bzw. LooseEnds-session-wt-b (ac16-a.log Zeile 48, ac16-b.log Zeile 72). PROVEN.
- AC-5/AC-16: ac16-a.log/ac16-b.log. A: sim-unit-Testlauf-Bundle 08:32:15, Log-Ende 08:44:21; B: Bundle 08:44:27, Log-Ende 08:44:54. Zeitraeume ueberlappen nicht. B nennt in der Warteausgabe Halter mit Worktree, Befehl und PID (ac16-b.log Zeilen 48-66: Worktree .../prancy-noodling-axolotl, Befehl sim-unit, PID 70356). Getrennte DerivedData (prancy-noodling-axolotl vs wt-b). Auffaellig: B wartete 2131 s, mehr als die Obergrenze 1800 s; das ist nur erklaerbar, wenn LOOSEENDS_LOCK_MAX fuer den Lauf erhoeht war. Das steht in keinem Log (F003). Beleg trotzdem tragfaehig, weil Serialisierung und Halter-Ausgabe sichtbar sind. PROVEN.
- AC-6/AC-7/AC-8/AC-9: Code reference: scripts/sim.sh:86 (lock_is_stale), scripts/sim.sh:104 (acquire_testlock mit Reentranz in Zeile 109, Statuszeile/Obergrenze ab Zeile 124), Tests test_orphan_lock_taken_over, test_start_time_mismatch_is_orphan, test_hand_lock_without_pid_waits, test_hand_lock_file_waits_then_taken_over, test_reentrant, test_wait_message_and_cap, alle gruen. Im Einzelfall PROVEN; im Gedraenge siehe F001.
- AC-10: acquire_testlock steht in cmd_unit, cmd_build, cmd_mac_build, cmd_sim_unit, cmd_test, cmd_test_proof, cmd_launch (LockOrderTests prueft zusaetzlich: Sperre vor rm -rf/mkdir/generate). run_xcodebuild (Zeile 205) unveraendert benannt, ohne Sperre. test_sim_run_xcodebuild.py und test_sim_proof.py gruen (letzterer mit LOOSEENDS_LOCK_DIR, Code reference: scripts/test_sim_proof.py:119). watch-test-proof delegiert an cmd_test_proof (gesperrt, ok); weitere xcodebuild-nutzende Befehle (device-build, lab, mac) sind laut Spec nicht gefordert. PROVEN.
- AC-11: Code reference: LooseEndsUITests/CalendarTargetTests.swift:267 (scrollUntilVisible: bis zu 5 Wischversuche, list.swipeUp(velocity: .slow) auf app.collectionViews.firstMatch, XCTFail mit Meldung); fuenf Aufrufstellen Zeilen 46, 62, 163, 201, 213; Zusicherungen unveraendert (Diff zeigt nur die Wisch-/Abfrage-Zeilen). Die Meldung lautet "<name> nach 5 Wischversuchen nicht erzeugt"; inhaltlich wie gefordert. PROVEN.
- AC-12: Code reference: LooseEndsUITests/CalendarTargetTests.swift:255 (alerts.firstMatch, 3 s Frist). Der Code beweist die kurze Frist. Die Spec verlangt Messung an der Klassenlaufzeit; es gibt keinen Vorher-Wert, nur 5 Laeufe mit ca. 190-196 s (testSwitchOnShowsTargetCalendar 47 s, testDefaultCalendarIsStampedOnSwitchOn 133 s). Kein Vergleich, daher nur indirekt belegt (F004). Bleibt OFFEN.
- AC-13: capture-1 und capture-4 je 19/19 Passed mit Beleg (Stand 096c347 plus Arbeitsbaum); recognition-1..3 je 1/1 Passed. capture-2 war rot (testAnalyzeAgainReportsBack, "Task row should be listed in New") nach 2501 s unter Volllast und Handsperren-Uebernahme; capture-3: xcodebuild "Executed 19 tests, with 0 failures", aber sim_proof.py bricht mit CalledProcessError (xcresulttool 64) ab, also kein maschineller Beleg (nicht gezaehlt). #208 und #168 tragen den Kommentar "Eingeordnet in #341: Erledigt durch #228" mit Verweis auf die Belege und ehrlicher Nennung des roten Laufs. Zwei gueltige gruene Laeufe plus 3x Recognition. PROVEN, F005 als Hinweis.
- AC-14: context-used Passed; context-fresh3 Passed auf frischem Simulator "LE341 frisch" mit der sim.sh-Aenderung (Code reference: scripts/sim.sh:364, cmd_boot schreibt DidShowContinuousPathIntroduction). context-fresh (rot) ist die reproduzierte Ursache (Tastaturhinweis), RED-Belege test-red-keyboard-hint.txt und test-red-output-ac14-frisch.txt vorhanden. Der Screenshot-Ordner zu context-fresh3 liegt nicht unter runs/ (simulator-run.txt nennt 4 Stueck), siehe F005. PROVEN.
- AC-15: calendar-1..5 je 3/3 Passed, jeder Lauf enthaelt testSwitchOnShowsTargetCalendar gruen (Log calendar-3: 47.487 s). SHA256 von CalendarTargetTests.swift in den Belegen (f7052278...) gleich dem aktuellen Stand. Code reference: LooseEndsUITests/CalendarTargetTests.swift:13. Nicht abgeschwaecht (Diff). PROVEN.
- AC-17: CLAUDE.md Build-Abschnitt (Diff) nennt unit im Simulator, LOOSEENDS_MAC_HOST=1, /tmp/loose-ends-testlauf.lock, Bauordner je Worktree und "Handabsprache ... entfaellt". PROVEN.
- AC-18: 16 Testmethoden, neun Plan-Faelle vorhanden (session_key x2, unit, serialized, orphan, start mismatch, hand lock, reentrant, cap); ci.yml unveraendert; 152 Tests gruen. PROVEN.
- AC-19: Die Liste der geaenderten Dateien enthaelt keinen Produktcode und keine Workflow-Datei. LooseEnds/Info.plist: Diff enthaelt nur NSCameraUsageDescription (Kamera-Scan, "attach to a task"), kein Bezug zu #341; muss vor dem Commit ausgeschlossen werden. Teil "nach dem Merge ist loose-ends-sync-main.sh gelaufen": in dieser Phase nicht belegbar, bleibt OFFEN.

Aktive Sonden zur Sperre (eigenes Skript im Scratchpad, temporaeres LOOSEENDS_LOCK_DIR): 8 gleichzeitige Prozesse uebernehmen eine verwaiste Sperre (toter PID). Ergebnis in 38 von 40 Runden: mindestens ein Prozess bricht mit "mv: .../l/.pid.NNNN -> .../l/pid: No such file or directory" ab (Exit != 0 durch set -e), weil ein anderer Prozess seine frisch angelegte Sperre als "verwaist" weggezogen hat (Meldung "Verwaiste Testsperre uebernommen (ohne pid-Datei)"). Gegenseitiger Ausschluss wurde in den 40 Runden nie verletzt, aber der Rennfall, den die Spec ("verliert ein Lauf das Rennen, wartet er weiter") zusichert, ist nicht erfuellt (F001).

**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Nachpruefung der Gegenstuecke und Randfaelle.

- Race-Ursache gelesen: scripts/sim.sh:115-121. lock_is_stale prueft den Pfad, mv "$dir" "$old" verschiebt dann den Pfad, nicht die gepruefte Sperre. Zwischen Pruefung und mv kann ein Konkurrent die alte Sperre bereits entfernt und eine neue (lebende) angelegt haben; der mv zieht dann die LIVE-Sperre weg und rm -rf loescht sie. Folge A: der Besitzer scheitert beim Schreiben der pid-Datei (scripts/sim.sh:137-138, Abbruch durch set -e), ein Testlauf stirbt zufaellig, wenn mehrere wartende Sitzungen gleichzeitig eine verwaiste Sperre sehen, genau das Szenario "kill -9 plus mehrere Wartende" aus AC-6. Folge B (theoretisch): legt der Dieb sofort eine neue Sperre an, schreibt der Verlierer .pid.PID in dessen Verzeichnis und ueberschreibt per mv dessen pid-Datei, beide laufen dann gleichzeitig; in 40 Runden nicht ausgeloest, die Luecke existiert aber. Kein Test deckt gleichzeitige Uebernahme ab.
- Fremdformat-Szenario: die ac16-Logs zeigen eine fremde Sperre des Projekts Restock mit identischem pid-Dateiformat im selben Verzeichnis; Erkennung ueber pid=/Startzeit und die Grace-Frist funktionieren dort (Handsperre ohne pid wurde nicht uebernommen, ac16-a.log Zeile 1).
- Reentranz: scripts/sim.sh:109 gilt fuer dieselbe PID oder LOOSEENDS_LOCK_OWNER und nur wenn nicht verwaist; release_testlock (Zeile 147) raeumt nur eigene Sperre und setzt OWNER zurueck. cmd_unit -> cmd_sim_unit in einem Prozess ist reentrant, belegt durch test_reentrant und die Beleglaeufe.
- Skriptstand vs. Belege: CalendarTargetTests.swift-Hash in allen calendar-/capture-/context-Belegen gleich dem Arbeitsbaum. sim.sh ist nicht im Beleg-Hash. Alle Belege tragen als Commit-Kennung 096c347 (Arbeitsbaum ungestempelt), siehe F005.
- Hygiene: Funktionen in sim.sh <= 50 Zeilen; Info.plist-Fremdaenderung gehoert nicht zum Ticket.

Fruehe-Einigkeits-Skepsis: Ohne die aktive Wettlauf-Sonde waere alles gruen gewesen; die Sonde hat ein reproduzierbares Fehlverhalten gezeigt. Die uebrigen ACs sind je mit Code, Test und Lauf-Beleg gepruefte Punkte.

**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** Nachpruefung nach dem Fix fuer F001/F002 und den Nachweisen zu F003 bis F006.

- F001/F002 (behoben): Code reference: scripts/sim.sh:150 (take_over_stale_lock: Uebernahme nur unter der Sperre dir.takeover, lock_is_stale wird unter der Sperre erneut geprueft) und scripts/sim.sh:139 (claim_testlock: verlorene Anlage heisst weiter warten, kein Abbruch). Neuer Test scripts/test_sim_lock.py:202 test_parallel_takeover_of_orphan_lock. RED-Beleg test-red-takeover-race.txt vorhanden. Skripttests frisch gelaufen: 153 Tests OK (adversary-test-output.txt).
- Eigene Sonden gegen den Fix: (a) 12 parallele Prozesse gegen eine Sperre mit totem PID, 25 Runden: in jeder Runde 12 von 12 OK, kein Abbruch, kein Ueberlapp (vorher 38 von 40 Runden mit Abbruch bei 8 Prozessen). (b) dasselbe mit zusaetzlich verwaister dir.takeover (mtime 1970, simuliert einen waehrend der Uebernahme getoeteten Prozess), 10 Runden mit 12 Prozessen: 12 von 12 OK, kein Ueberlapp, kein Abbruch. Frische verwaiste takeover-Sperre kostet hoechstens 10 s Wartezeit, kein Fehler.
- Restfall des Entwicklers (zwei Wartende sehen gleichzeitig eine ueber 10 s alte takeover-Sperre): erforderlich ist ein Prozess, der genau waehrend einer Uebernahme stirbt (Fenster Millisekunden), UND mindestens zwei Wartende, die im selben Moment die alte takeover-Sperre abraeumen. Nur dann koennten zwei Prozesse gleichzeitig uebernehmen; selbst dann wird eine lebende Sperre nur verworfen, wenn sie exakt zwischen Pruefung und mv neu angelegt wurde. Praktisch nicht relevant (F008, LOW), und der Schaden waere ein abgebrochener Lauf, kein Datenverlust.
- F003: Erklaerung stimmt (Belegskript setzte LOOSEENDS_LOCK_MAX=14400, steht auch in ac12-messung.txt). Standardgrenze belegt der Test test_wait_message_and_cap. Erledigt, kein Mangel am Produkt.
- F004/AC-12: runs/calendar-6.log (3/3 gruen) und runs/ac12-messung.txt: Wartezeit auf den Springboard-Alert gemessen 3,1 bis 3,2 s je Aufruf. Der alte Code (Schleife bis 30 s, endet ohne Alert nur wenn die Zeile existiert) wurde nicht gemessen. Die Schlussfolgerung ist aber zwingend: derselbe Lauf zeigt, dass waitForExistence(10) auf calendarTargetRow voll ausläuft (10,3 bis 10,4 s), die Zeile also vor dem Wischen nicht existiert; damit haette die alte Schleife die vollen 30 s je Aufruf gewartet. Das genuegt als Beleg fuer die Verkuerzung, die Luecke (kein Altlauf) ist benannt. AC-12 PROVEN.
- F005: Commit-Kennung 096c347 ist der letzte Commit, die Umsetzung ist noch nicht committet; kein Mangel. capture-3 zaehlt nicht.
- F006: Umfang laut Diff-Stat jetzt 6 Dateien, +285/-58 (ohne fremde Info.plist +283/-58), zusaetzlich 222 Zeilen RED-Test aus 096c347. Grenze von 250 ueberschritten, zur Kenntnis. Funktionen in sim.sh: keine laenger als 50 Zeilen (awk-Pruefung, leere Ausgabe); keine Workflow-Datei geaendert.
- Neu F007: in acquire_testlock ist die lokale Variable old (scripts/sim.sh:109) nun ungenutzt. Kosmetik.
- AC-19: alles ausser dem Nachmerge-Teil belegt (kein Produktcode, ci.yml unveraendert, Info.plist-Aenderung ist fremd und gehoert nicht in den Commit). Es fehlt AUSSCHLIESSLICH der Teil "nach dem Merge ist loose-ends-sync-main.sh gelaufen"; sonst ist nichts offen.

**Implementierer:** (nicht beteiligt)

## Findings

Finding:
  ID: F001
  Severity: HIGH
  Category: edge_case
  Code reference: scripts/sim.sh:115
  Description: Uebernahme einer verwaisten Sperre: lock_is_stale (Zeile 115) und mv "$dir" "$old" (Zeile 117) sind nicht atomar zusammen. Ein zweiter Waiter kann zwischen Pruefung und mv die inzwischen vom ersten neu angelegte, lebende Sperre wegziehen und per rm -rf loeschen.
  Spec requirement: AC-6 / Teil B: "Uebernahme atomar per mv ...; verliert ein Lauf das Rennen, wartet er weiter."
  Conflict: Reproduktion: 8 parallele Prozesse gegen eine Sperre mit totem PID (Sonde im Scratchpad): in 38 von 40 Runden bricht mindestens ein Lauf mit "mv: .../l/.pid.N: No such file or directory" (Exit != 0) ab, statt zu warten. Der Dieb macht die Sperre eines Lebenden zunichte; Ausschluss ist dann nicht mehr garantiert (in 40 Runden kein Ueberlapp beobachtet).
  Remediation: Nach dem mv den verschobenen Inhalt pruefen: ist $old/pid vorhanden und der Halter lebt (oder pid fehlt und mtime frisch), den Ordner per mv "$old" "$dir" zurueckstellen bzw. verwerfen und weiterwarten. Alternativ Uebernahme unter einer zweiten Mutex (mkdir $dir.takeover), die nur ein Waiter gleichzeitig haelt. Dazu einen Test mit 8 gleichzeitigen Waitern auf verwaister Sperre.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/test_sim_lock.py:188
  Description: test_orphan_lock_taken_over und alle weiteren Sperrtests laufen mit hoechstens einem Konkurrenten; es gibt keinen Test fuer gleichzeitiges Uebernehmen, daher bleibt F001 unentdeckt, obwohl die Spec die Rennsituation ausdruecklich beschreibt.
  Spec requirement: AC-6 / Teil B (Rennen um die Uebernahme)
  Conflict: Das gruene Ergebnis der 152 Skripttests sagt nichts ueber den Rennfall.
  Remediation: Mehrprozess-Test (z. B. 6 Waiter, kritischer Abschnitt per mkdir pruefen, alle muessen mit Exit 0 enden) ergaenzen.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/sim.sh:106
  Description: Die Obergrenze LOOSEENDS_LOCK_MAX (Standard 1800 s) wurde im AC-16-Beleg offenbar uebersteuert (ac16-b.log wartet bis 2131 s und laeuft dann), ohne dass Log oder Bericht das festhalten.
  Spec requirement: AC-9: Abbruch nach 30 min; AC-16 Beleg im Bericht
  Conflict: Nicht nachvollziehbar, ob die Obergrenze im realen Betrieb ohne Variable greift; nur der Unit-Test mit verkuerzter Frist belegt sie.
  Remediation: Im Bericht die gesetzte Variable nennen oder den Beleglauf mit Standardwerten wiederholen.

Finding:
  ID: F004
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEndsUITests/CalendarTargetTests.swift:255
  Description: AC-12 verlangt, die Verkuerzung der Wartezeit an der Klassenlaufzeit im Protokoll zu messen. Es liegt kein Vorher-Wert vor (nur 5 Nachher-Laeufe, 190-196 s).
  Spec requirement: AC-12: "gemessen an der Laufzeit der Klasse im Protokoll"
  Conflict: Die Wirkung ist nur durch Code-Lesen belegt, nicht durch Vorher/Nachher-Messung.
  Remediation: Laufzeit der Klasse vor der Aenderung (aus frueheren Belegen oder CI-Protokoll) neben die neuen Werte stellen.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_sim_proof.py:119
  Description: Belege tragen die Commit-Kennung 096c347 (Arbeitsbaum ohne Commit); capture-3 hat 19/19 Tests gruen, aber keinen Beleg, weil sim_proof.py bei unlesbarem xcresult mit CalledProcessError-Traceback abbricht; die Screenshots von context-fresh3 liegen nicht unter runs/. Nicht gezaehlt, sondern benannt.
  Spec requirement: AC-13/AC-14: maschineller Beleg, Screenshots geoeffnet und beschrieben
  Conflict: Beleg-Vollstaendigkeit eingeschraenkt; kein Fehler im Spec-Umfang.
  Remediation: Beleg nach dem Commit mit Commit-Kennung festhalten; Screenshots von context-fresh3 ablegen.

Finding:
  ID: F006
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/sim.sh:56
  Description: Umfang: +248/-58 im Arbeitsbaum (ohne Info.plist +246/-58) plus 222 Zeilen RED-Test in 096c347; die Spec nannte ca. +250/-20 und die globale Grenze liegt bei +-250.
  Spec requirement: Scoping-Limit 250 LoC
  Conflict: Limit ueberschritten; die Spec sah dafuer den Rueckfall "Teil B als #413 abtrennen" vor.
  Remediation: Entscheidung dokumentieren (Buendelung bewusst) oder abtrennen.

Finding:
  ID: F007
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/sim.sh:109
  Description: Die lokale Variable old in acquire_testlock ist nach dem Umbau ungenutzt.
  Spec requirement: Code-Sauberkeit (keine Spec-Anforderung)
  Conflict: Toter Code, kein Funktionsfehler.
  Remediation: old aus der local-Zeile entfernen.

Finding:
  ID: F008
  Severity: LOW
  Category: edge_case
  Code reference: scripts/sim.sh:150
  Description: Restfall: zwei Wartende raeumen gleichzeitig eine ueber 10 s alte, verwaiste takeover-Sperre ab und uebernehmen dann evtl. parallel. Voraussetzung ist ein waehrend der Uebernahme gestorbener Prozess.
  Spec requirement: AC-6 (Uebernahme einer verwaisten Sperre)
  Conflict: Theoretisch nicht atomar, praktisch nicht relevant (Sonde b zeigt 120 von 120 Laeufen ohne Fehler).
  Remediation: Keine noetig; optional die Altersgrenze der takeover-Sperre vor dem Abraeumen erneut pruefen.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/sim.sh:254
  Evidence: cmd_unit ruft ohne LOOSEENDS_MAC_HOST=1 cmd_sim_unit; Test gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/sim.sh:56
  Evidence: session_key liefert bereinigten Ordnernamen bzw. Override; Lauf-Logs zeigen LooseEnds-session-prancy-noodling-axolotl.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/test_sim_proof.py:119
  Evidence: test-proof laeuft mit LOOSEENDS_LOCK_DIR im Temp-Verzeichnis, alle 152 Skripttests gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: LooseEndsUITests/CalendarTargetTests.swift:267
  Evidence: Helfer mit 5 langsamen Wischversuchen, 5 Aufrufstellen, calendar-1..5 gruen.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Es wurde keine Tabelle aus `precondition_origins.py` angehaengt, daher gibt es keine verdaechtigen Zeilen mit offenen Spalten "Bedingung davor" und "Test fuer diesen Weg".

## Verdict

Verdict Runde 2 (ueberholt, F001 behoben): BROKEN wegen F001 (HIGH, Wettlauf bei der Uebernahme einer verwaisten Sperre, reproduziert). Offen: AC-12 (keine Vorher/Nachher-Laufzeit), AC-19 (Teil "nach dem Merge ist loose-ends-sync-main.sh gelaufen" in dieser Phase prinzipbedingt nicht belegbar).
Tests: 152 passed, 0 failed, 0 uebersprungen

Verdict Runde 2 (ueberholt): BROKEN

Verdikt Runde 3: F001/F002 behoben und mit Sonden nicht mehr zu brechen, AC-12 belegt. Offen ist ausschliesslich AC-19, Teil "nach dem Merge ist loose-ends-sync-main.sh gelaufen", der in dieser Phase prinzipbedingt nicht belegbar ist; ausser diesem Nachmerge-Teil fehlt nichts. Findings F003 bis F008 sind LOW.
Tests: 153 passed, 0 failed, 0 uebersprungen

VERDICT: AMBIGUOUS

## Geprüfte Dateien

- sha256:f70522788126133af298cecbf3c744f10022eb3fac15f40327cc99e9ce58c304  LooseEndsUITests/CalendarTargetTests.swift
- sha256:fb95e663925f791868efdceb35d9712a321c06c854ded22cab1dde63ddf06ede  scripts/sim.sh
- sha256:92d8e6fa4764c6716933cf9ce5a08294d64651f372fc32af55c85a9b1527b54f  scripts/test_sim_lock.py
- sha256:911cbe1d41d0d912a4fca6690797e28f420bab4dc88ca5b9b43a22a832e63232  scripts/test_sim_proof.py

## Prüfbasis

- base: d0e166b970d7d35a1088df2478ae385fc5397f37
- blob:b5dd83d278c7db3dce1762240ddf38ee07403889  LooseEndsUITests/CalendarTargetTests.swift
- blob:5f0cd8886d04a99238768ad8def975659a305e60  scripts/sim.sh
- blob:bfaaff4ccc37a5a69b3b111a24350b76596f2682  scripts/test_sim_lock.py
- blob:31e6af2bfac18d22ce12923a5361b388b724cd12  scripts/test_sim_proof.py
