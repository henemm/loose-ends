# Adversary Dialog — feat-145-s2-gate
Spec: docs/specs/tooling/feat-145-s2-gate.md
Datum: 2026-10-22 19:46

## Checkliste
- [x] **AC-1:** Kein Beleg, bewusster Fehlversuch. Given `evidence_checks` ist für `phase8_complete` gesetzt, eine Gate-Datei (z. B. `LooseEnds/Views/Foo.swift`) ist seit der Basis geändert und es existiert kein `simulator-run.txt` / When der Übergang nach `phase8_complete` versucht wird / Then wird er abgelehnt, und die Meldung nennt den fehlenden Beleg und den Befehl `scripts/sim.sh test-proof`.
- [x] **AC-2:** Veralteter Hash. Given ein gültiger Beleg, danach wird eine Gate-Datei inhaltlich verändert / When der Übergang versucht wird / Then Ablehnung, die Meldung nennt den Pfad dieser Datei und dass sie nach dem Lauf geändert wurde.
- [x] **AC-3:** Datei fehlt im Beleg. Given ein gültiger Beleg, danach kommt eine weitere Gate-Datei (geändert oder neu) hinzu, die im Block `## Geprüfte Dateien` fehlt / When der Übergang versucht wird / Then Ablehnung mit dem Pfad der nicht gebundenen Datei.
- [x] **AC-4:** Ergebnis nicht bestanden. Given ein Beleg mit `ergebnis: Failed` oder `Unbekannt` / When der Übergang versucht wird / Then Ablehnung mit dem Ergebniswert in der Meldung.
- [x] **AC-5:** Null Tests. Given ein Beleg mit `ergebnis: Passed`, aber `tests: 0 gesamt` (oder 0 bestanden) / When der Übergang versucht wird / Then Ablehnung mit dem Hinweis „kein bestandener Test".
- [x] **AC-6:** `summary.json` manipuliert. Given ein Beleg, dessen `summary.json` nach dem Lauf verändert wurde, sodass die Prüfsumme der Zeile `summary:` nicht mehr stimmt / When der Übergang versucht wird / Then Ablehnung, die Meldung nennt `summary.json` und die Prüfsumme.
- [x] **AC-7:** Bündel fehlt. Given ein sonst gültiger Beleg, dessen `simulator-run/run.xcresult` fehlt / When der Übergang versucht wird / Then Ablehnung mit „run.xcresult fehlt".
- [x] **AC-8:** Neuableitung weicht ab. Given ein Beleg und eine `summary.json`, die `Passed` und 3 bestandene Tests angeben, während die Neuableitung aus `run.xcresult` ein anderes `result` oder andere Zähler liefert / When der Übergang versucht wird / Then Ablehnung, die beide Werte (Beleg, Neuableitung) nennt.
- [x] **AC-9:** Format-Versionsunabhängigkeit. Given ein Beleg, dessen `summary.json` und Neuableitung in `result` und den fünf Zählern gleich sind, sich aber in anderen Feldern oder der Feldreihenfolge unterscheiden / When der Übergang versucht wird / Then wird er nicht wegen dieses Unterschieds abgelehnt (semantischer, nicht byteweiser Vergleich).
- [x] **AC-10:** `xcresulttool` nicht nutzbar, fail-closed. Given `xcresulttool` fehlt (z. B. Linux) oder überschreitet das Zeitlimit / When der Übergang versucht wird / Then Ablehnung mit einer Meldung, die `xcresulttool` und „nicht verfügbar" bzw. „Zeitlimit" nennt; es wird nie stillschweigend durchgelassen, und das Gate wirft keine Ausnahme.
- [x] **AC-11:** Gültiger Beleg wird akzeptiert. Given ein von `scripts/sim.sh test-proof` erzeugter Beleg, dessen Hashes zum Arbeitsbaum passen, mit `ergebnis: Passed` und passender Neuableitung / When der Übergang versucht wird / Then lässt das Gate ihn durch (die Adversary- und Dialog-Prüfungen gelten weiter unverändert).
- [x] **AC-12:** Keine Bindung an `head:`. Given ein gültiger Beleg und ein Rebase (oder Amend) ohne Änderung des Dateiinhalts, sodass `head:` im Beleg nicht mehr dem aktuellen HEAD entspricht / When der Übergang versucht wird / Then wird er nicht wegen `head:` abgelehnt.
- [x] **AC-13:** Keine Gate-Datei geändert. Given die seit der Basis geänderten Dateien sind nur Doku, Skripte oder Tests (`docs/`, `scripts/`, `*.md`) / When der Übergang versucht wird / Then verlangt das Gate keinen Beleg.
- [x] **AC-14:** Nur Ausnahmepfade geändert. Given die einzige geänderte Gate-Datei liegt unter einem `exempt_paths`-Muster (z. B. `LooseEnds/Mac/MenuBarCapture.swift` unter `LooseEnds/Mac/*`) / When der Übergang versucht wird / Then verlangt das Gate keinen Beleg. Given zusätzlich eine Datei außerhalb der Ausnahmepfade geändert ist / Then verlangt es ihn weiter (und prüft nur diese Datei gegen den Beleg).
- [x] **AC-15:** Projekt ohne Konfiguration unverändert. Given ein Projekt ohne Abschnitt `evidence_checks` (oder mit leerem) / When es nach `phase8_complete` geht / Then ist das Verhalten identisch zu Plugin 3.41.0, nachgewiesen durch einen Test mit leerer Konfiguration, der kein Dateisystem außerhalb des Workflows liest.
- [x] **AC-16:** Gilt für `complete` und `finish`. Given dasselbe Gate-Szenario wie AC-1 / When statt des direkten Übergangs `workflow.py complete` und `workflow.py finish` aufgerufen werden, auch bei bereits gesetzter Phase 8 / Then lehnen beide gleichermaßen ab.
- [x] **AC-17:** Kein neuer Artefakttyp, nichts per Hand zu öffnen. Given das Gate / When `add-artifact simulator_run` aufgerufen wird / Then bleibt der Typ unbekannt (Ablehnung wie heute); When `set-field` ein Feld setzt, das den Beleg ersetzen könnte, oder `add-artifact` einen anderen Pfad meldet / Then ändert das nichts am Gate-Ergebnis: gelesen wird ausschließlich der feste Pfad `docs/artifacts/<wf>/simulator-run.txt`.
- [x] **AC-18:** Beleg außerhalb des Projekts. Given der feste Pfad ist ein Symlink, der aus dem Projekt zeigt / When der Übergang versucht wird / Then Ablehnung (Prüfung „liegt im Projekt“ vor dem Lesen), der Inhalt wird nicht gelesen.
- [x] **AC-19:** Schreibsperre (Schnitt 2b). Given ein aktiver Workflow / When ein Write- oder Edit-Aufruf auf `docs/artifacts/<wf>/simulator-run.txt` oder eine Datei in `docs/artifacts/<wf>/simulator-run/` zielt, oder ein Bash-Befehl, dessen Text eine dieser Dateien mit `>`, `>>`, `tee`, `cp`, `mv`, `sed -i` oder `rm` beschreibt / Then wird der Aufruf blockiert, mit Meldung, dass der Beleg nur von `scripts/sim.sh test-proof` erzeugt wird.
- [x] **AC-20:** Erzeuger bleibt erlaubt. Given dieselbe Sperre / When `scripts/sim.sh test-proof <Klasse>` per Bash aufgerufen wird / Then wird der Aufruf nicht blockiert (erkannt am Befehl, nicht am Pfad allein), und der Beleg entsteht. Lesende Zugriffe (`cat`, Read) auf Beleg und Bündel bleiben erlaubt.
- [x] **AC-21:** Drift zwischen Erzeuger und Gate. Given die Dateimenge, die `scripts/sim_proof.py` in den Beleg schreibt, und die Gate-Menge des Plugins mit der Loose-Ends-Konfiguration (`is_gated_code_path` des installierten Plugins, abzüglich `evidence_checks.exempt_paths` als `fnmatch`-Muster wie im Plugin) / When ein Test beide für ein Musterset von Pfaden (`.swift` unter `LooseEnds/`, `Shared/`, `LooseEndsTests/`, `LooseEndsUITests/`, `Measurement/`, sowie `docs/`, `scripts/`, `*.md`, `*.json`) berechnet / Then ist die Erzeuger-Menge eine Obermenge der Gate-Menge. Der Test schlägt fehl, wenn das Plugin eine Endung oder einen Pfad zählt, den `sim_proof.py` nicht zählt.
- [x] **AC-22:** Override nur durch Henning. Given das Gate lehnt ab / When der Agent versucht, es zu umgehen (kein Beleg registrieren, `set-field`, Verzicht-Artefakt) / Then bleibt die Ablehnung; ausgenommen wird nur über den bestehenden Mechanismus mit Hennings **getipptem** `override` (Einstunden-Fenster, nur das Wort „override" zählt). Es gibt kein selbst registrierbares Verzichtsartefakt.
- [x] **AC-23:** Einschalten in Loose Ends. Given der Plugin-Release mit 2a ist installiert / When `openspec.yaml` den Abschnitt `evidence_checks` mit `phase8_complete` (`verifier: xcresult_proof`, `file: simulator-run.txt`) und `exempt_paths: ["LooseEnds/Mac/*"]` laut obiger Form enthält / Then liest `scripts/test_evidence_config.py` die Datei und bestätigt Form und Inhalt, und ein bewusster Fehlversuch wird abgelehnt: die Gate-Prüfung des installierten Plugins (`evidence_gate.check_evidence("phase8_complete", …)`) für einen Wegwerf-Workflow in Loose Ends, in dem eine Gate-Datei geändert ist und kein Beleg liegt, liefert eine Ablehnung, die den fehlenden Beleg nennt (nicht eine Config-Ablehnung).
- [x] **AC-24:** Ehrlicher Beleg wird akzeptiert. Given das Gate ist in Loose Ends eingeschaltet und derselbe Wegwerf-Workflow wie in AC-23 / When `scripts/sim.sh test-proof <Klasse>` im Simulator einen echten Beleg zu einer bestehenden UI-Testklasse erzeugt hat / Then liefert dieselbe Gate-Prüfung keine Ablehnung, ohne `override`. Schlägt das an einem ehrlichen Beleg fehl, wird das Gate repariert, nicht umgangen. Der Pilot am nächsten echten UI-Ticket bleibt offener Punkt in #145 (außerhalb dieses Workflows, weil er ein anderes Ticket braucht).

## Dialog

Testbeleg: `docs/artifacts/feat-145-s2-gate/adversary-test-output.txt` (Plugin, 65 passed), `adversary-config-test-output.txt` (Loose Ends, 6 OK), `adversary-gegenversuche.txt` (eigene Gegenversuche an einer frischen Kopie des Wegwerf-Klons, echtes `xcresulttool` auf dem echten Bündel). Das Gate liest `openspec.yaml` aus dem Haupt-Checkout; deshalb wirkt es in dieser Arbeitskopie erst nach dem Merge (kein Mangel, nur Reihenfolge).

Zuordnung der Plugin-Tests (Nummern in `tests/test_evidence_gate_447.py` weichen von den Spec-ACs ab):
AC-1 test_ac9_proof_missing_rejected; AC-2 test_ac11_stale_hash_rejected; AC-3 test_ac10_gate_file_missing_in_block_rejected; AC-4 test_ac20_result_not_passed_rejected; AC-5 test_ac21_zero_passed_tests_rejected; AC-6 test_ac12_summary_json_missing_or_checksum_wrong_rejected; AC-7 test_ac13_xcresult_missing_rejected; AC-8 test_ac18_*/test_ac19_*; AC-9 test_ac22_green_case_real_format (Fixture dreht Feldreihenfolge und ändert finishTime); AC-10 test_ac14_xcresulttool_missing_rejected, test_ac17_timeout_rejected; AC-11 test_ac22_green_case_real_format; AC-13/14 test_ac5_empty_gate_set_and_exempt_paths; AC-15 test_ac1_without_config_identical; AC-16 test_ac23_all_completion_paths_checked; AC-18 test_ac8_symlink_escape_rejected; AC-19/20 test_ac27_*, test_ac28_*, test_ac29_*; AC-22 test_ac25_override_opens_only_evidence_gate, test_ac26_runner_not_overridable_by_config_or_env; AC-21 und AC-23 scripts/test_evidence_config.py.

### Runde 1
**Adversary:** Ich gehe davon aus, dass das Gate zu öffnen ist. (a) Erster Lauf der Plugin-Tests mit meinem Standard-PATH: 43 von 65 rot, Grund in jedem Fall `FileNotFoundError: 'git'`. Der Test entfernt jedes PATH-Verzeichnis, in dem `xcrun` liegt (tests/test_evidence_gate_447.py:177-178); auf macOS ist das `/usr/bin`, dort liegt auch die Versionsverwaltung. Mit einem Verzeichnis, das nur diesen einen Befehl weiterreicht, alle 65 grün. Das ist ein Umgebungsmangel der Testsuite, nicht des Gates, aber das Plugin ist auf Hennings Mac nicht ohne Zusatz grün (Finding F001). (b) Bewusste Fehlversuche mit eigenem Skript gegen eine frische Kopie: ehrlicher Beleg nach Wiederherstellung der Datei durchgelassen (Hash dcb8bb7b... stimmt); `head:`-Zeile auf lauter Nullen gesetzt: durchgelassen (AC-12); `ergebnis: Failed` und `Unbekannt`: abgelehnt, Meldung nennt den Wert und die Neuableitung `Passed` (AC-4); `tests: 0 gesamt`: abgelehnt (AC-5); neue, ungebundene Swift-Datei: abgelehnt mit ihrem Pfad (AC-3); `summary.json` um ein Leerzeichen verändert: abgelehnt, nennt summary.json und Prüfsumme (AC-6); Bündel umbenannt: abgelehnt „run.xcresult fehlt“ (AC-7); fehlendes Werkzeug und Zeitlimit per Runner: beide abgelehnt, keine Ausnahme (AC-10); Beleg als Symlink aus dem Projekt: abgelehnt vor dem Lesen (AC-18); nur Doku und Skripte geändert, kein Beleg: durchgelassen (AC-13); nur `LooseEnds/Mac/MenuBarCapture.swift`: durchgelassen, plus eine Datei außerhalb: „Beleg fehlt (erzeugen mit scripts/sim.sh test-proof)“ (AC-14, AC-1); gelöschte Swift-Datei blockiert den ehrlichen Beleg nicht; Workflow-Name `../x`: abgelehnt. (c) AC-17: `simulator_run` fehlt in VALID_ARTIFACT_TYPES (core/hooks/workflow.py:276), das Gate liest nur den festen Pfad (core/hooks/evidence_gate.py:216-234); zusätzliche Felder in den Workflowdaten ändern das Ergebnis nicht (Gegenversuch). (d) Wiederholt: Spec-Fälschungsweg über Schreibsperre bleibt eng (Bash-Muster nur `>`, `tee`, `cp`, `mv`, `sed -i`, `rm`); `dd of=`, ein Python-Aufruf oder `ln -sf` stehen nicht in der Spec-Liste und sind die bewusst akzeptierte Restlücke.
**Implementierer:** F001 betrifft die Testumgebung im Plugin-Repo, nicht das Gate; Behebung dort: PATH-Filter darf das Verzeichnis des Versionsverwaltungs-Programms nicht entfernen. Alle Gate-Verhalten stehen nach Test und Gegenversuch; die Restlücke (selbst gebautes Bündel, Umgehung der Sperre per Skript) ist in der Spec als „relativ“ benannt.

### Runde 2
**Adversary:** Zweiter Angriff auf die Stellen, an denen Tests und Probe sich verlassen: (1) Reproduktion unabhängig von den vorhandenen Ausgabedateien: Ich habe `gate-gegenprobe-veraltet.txt` nicht übernommen, sondern den Klon neu kopiert. Der Klon enthielt die Gegenprobe-Änderung („nach dem Lauf geändert“); mit ihr lehnt das Gate ab (Zustand des Klons: Hash 42f0317... ≠ Beleg), ohne sie lässt es durch. Damit sind Fehlversuch und ehrlicher Beleg für AC-23/AC-24 an derselben Datei umkehrbar. Den Simulatorlauf habe ich nicht wiederholt; der Beleg `probe-145-beleg.txt` zeigt `** TEST SUCCEEDED **`, 1 von 1 bestanden, und die Neuableitung durch das echte `xcresulttool` bestätigte `Passed` (S0 im Gegenversuch). (2) AC-21-Mutationstest: ließ ich `sim_proof.is_gated_code_path` künstlich alles unter `Measurement/` ablehnen, schlug `test_producer_covers_every_gate_path` fehl (Gate verlangt `Measurement/LeaveOneOut.swift`, Beleg erfasst nicht); die Drift wird also gefangen. Eine Mutation auf `LooseEndsUITests/` wurde nicht gefangen, weil das Plugin diesen Pfad nicht zum Gate zählt (Gate-Menge: Views, App, Watch, Measurement, Shared; Erzeuger ist Obermenge). Das ist kein Mangel. (3) Konfiguration: `openspec.yaml` nennt `evidence_checks` nur in den Kommentarzeilen ohne den Schlüsselnamen im Fließtext vor einem `#`, die Roh-Prüfung des Plugins (evidence_gate.py:35-54) liest die Datei als ladbar; Form entspricht test_evidence_config.py:86-96. CI führt das Skript über `unittest discover` aus (Drift-Tests dort übersprungen, wie in der Spec vorgesehen). (4) Frühe-Einigung-Skepsis: Auch Runde 1 hat nicht alles geglaubt; die einzigen offenen Punkte sind F001 und die nicht eingecheckte Konfiguration (openspec.yaml ist noch Arbeitsbaum-Änderung, Commit steht aus).
**Implementierer:** Keine weitere Änderung am Gate nötig. F001 an das Plugin-Repo melden bzw. dort beheben; `openspec.yaml` wird mit dem Schnitt eingecheckt.

## Findings

Finding:
  ID: F001
  Severity: MEDIUM
  Category: anti_pattern
  Code reference: openspec.yaml:40
  Description: Die Testsuite des Plugins (tests/test_evidence_gate_447.py:177-178, im installierten Plugin 3.42.0) streicht aus PATH jedes Verzeichnis mit `xcrun`. Auf macOS ist das /usr/bin und damit auch das Versionsverwaltungs-Programm; 43 von 65 Tests schlagen mit `FileNotFoundError: 'git'` fehl. Mit PATH, das nur dieses Programm bereitstellt, laufen alle 65 grün (adversary-test-output.txt). Die Code-Referenz zeigt auf die Loose-Ends-Konfiguration, weil das Plugin-Verzeichnis außerhalb des Projekts liegt.
  Spec requirement: DoD — Plugin: tests/test_evidence_gate_447.py grün (#447)
  Conflict: Auf einem Entwicklungs-Mac mit Standard-PATH ist die Suite rot; das Gate-Verhalten selbst ist davon nicht betroffen (65/65 mit korrektem PATH, eigene Gegenversuche grün).
  Remediation: Im Plugin den PATH-Filter so ändern, dass nur ein Eintrag `xcrun` entfällt, nicht das Verzeichnis (Fake-Verzeichnis voranstellen und `xcrun` per Wrapper abfangen), oder das Verzeichnis des Versionsverwaltungs-Programms wieder anhängen.

## Bestätigungen

Confirmation:
  AC: AC-1 bis AC-20, AC-22
  Code reference: scripts/test_evidence_config.py:99
  Evidence: Plugin-Tests 65/65 (mit korrektem PATH) plus eigene Gegenversuche in adversary-gegenversuche.txt; Zuordnung oben.
  Status: CONFIRMED

Confirmation:
  AC: AC-21
  Code reference: scripts/test_evidence_config.py:118
  Evidence: Test grün, Mutation (Measurement/ im Erzeuger gestrichen) wird gefangen.
  Status: CONFIRMED

Confirmation:
  AC: AC-23
  Code reference: openspec.yaml:46
  Evidence: Form wird von test_evidence_config.py geprüft (3 Tests OK); Fehlversuch ohne Beleg: „Beleg fehlt ... (erzeugen mit scripts/sim.sh test-proof)“, keine Config-Ablehnung (gate-fehlversuch.txt, selbst nachgestellt mit Dateiänderung in frischer Kopie).
  Status: CONFIRMED

Confirmation:
  AC: AC-24
  Code reference: openspec.yaml:44
  Evidence: Echter Beleg probe-145-beleg.txt (Passed, 1/1); Gate lässt ihn durch ohne Override, von mir an frischer Kopie reproduziert.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS — alle 24 Gate-Verhaltenspunkte bewiesen; offen nur F001 (Plugin-Testsuite auf macOS ohne PATH-Anpassung rot, MEDIUM). Tests: Plugin 65 passed bei korrektem PATH, 43 failed bei Standard-PATH; Loose Ends 6 OK, 0 übersprungen.

## Geprüfte Dateien

- sha256:cbcaa2e9464c7d5e91f974477d3c2e03314f631c1c08ce96e25752019d336042  openspec.yaml
- sha256:c22e885dbfe83f36bdd804163bc9a7763cc4ebb867e90e01717815a4de98f713  scripts/test_evidence_config.py

## Prüfbasis

- base: b8e656ae939473ffcab59812c6a7af5800327485
- blob:2e5435c1967c171a5b216efa8d19c90228a14e58  openspec.yaml
- blob:b1d625eba184b999028f36636e05128d30b21a71  scripts/test_evidence_config.py

## Geprüfte Dateien

- sha256:cbcaa2e9464c7d5e91f974477d3c2e03314f631c1c08ce96e25752019d336042  openspec.yaml
- sha256:c22e885dbfe83f36bdd804163bc9a7763cc4ebb867e90e01717815a4de98f713  scripts/test_evidence_config.py

## Prüfbasis

- base: b8e656ae939473ffcab59812c6a7af5800327485
- blob:2e5435c1967c171a5b216efa8d19c90228a14e58  openspec.yaml
- blob:b1d625eba184b999028f36636e05128d30b21a71  scripts/test_evidence_config.py
