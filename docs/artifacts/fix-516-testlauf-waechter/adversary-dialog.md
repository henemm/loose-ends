# Adversary Dialog — fix-516-testlauf-waechter
Spec: docs/specs/tooling/fix-516-schnitt-1-testlauf-waechter.md
Datum: 2026-10-19 15:10

Testlauf (voll, python3 -m unittest scripts/test_sim_run_xcodebuild.py -v): 9 Tests, OK, 48.8 s; danach pgrep auf "sleep 600" leer.
Ausgabe: docs/artifacts/fix-516-testlauf-waechter/adversary-test-output.txt

## Checkliste
- [x] **AC-1:** Given xcodebuild schreibt länger als LOOSEENDS_SILENCE_MAX (Vorgabe 900 s) nichts in BUILD_LOG, When run_xcodebuild läuft, Then wird der xcodebuild dieses Laufs beendet (TERM, nach 5 s KILL).
- [x] **AC-2:** Given parallel läuft der xcodebuild einer anderen Sitzung (anderer -derivedDataPath), When der Wächter auslöst, Then bleibt dieser Prozess unberührt; Kinder des beendeten Prozesses werden mitbeendet.
- [x] **AC-3:** Given der Wächter hat ausgelöst, When run_xcodebuild zurückkehrt, Then ist der Exitcode ≠ 0 (mit und ohne pipefail, über Markierungsdatei), das Skript endet, der EXIT-Trap läuft und die Sperre ist frei.
- [x] **AC-4:** Given der Wächter hat ausgelöst, When die Meldung erscheint, Then steht sie auf stderr und nennt „hängt seit N min, abgebrochen“, die Frist, die letzte Logzeile und „Ein Neustart von CoreSimulatorService kann nötig sein“; der Wächter startet den Dienst nicht selbst neu.
- [x] **AC-5:** Given ein Lauf, der laufend Zeilen schreibt oder vor Ablauf der Frist endet, When er fertig ist, Then sind Exitcode und Ausgabe wie bisher, kein Wächterprozess läuft weiter und keine Markierungsdatei bleibt.
- [x] **AC-6:** CLAUDE.md, Absatz „Parallele Sitzungen“, nennt Frist (15 min Stille), LOOSEENDS_SILENCE_MAX und die Abbruchmeldung.

## Dialog

### Runde 1
**Adversary:** Alle sechs Punkte einzeln angegriffen, nicht nur der Testlauf.

AC-1. Der Wächter (Subshell, Poll LOOSEENDS_SILENCE_POLL, Standard 10 s) liest die mtime des Logs, Alter = jetzt minus mtime, löst bei Alter größer Frist aus, TERM, 5 s Pause, KILL. Eigenversuch mit einem Stub, der TERM ignoriert: Lauf endete nach 8,3 s mit rc 1, Killed: 9, keine Reste (pgrep leer). Der KILL-Pfad ist also real. Grenzfall: Stub schreibt alle 1,9 s bei Frist 2 s und Poll 1 s, 8 Zeilen: rc 0, keine Meldung, kein falscher Abbruch (mtime auf ganze Sekunden abgeschnitten überschätzt das Alter um weniger als 1 s, daher nie Alter größer Frist bei echtem Alter unter Frist). Stille 3 s bei Frist 2: rc 1; Stille 1 s: rc 0.
Code reference: scripts/sim.sh:242 (Poll), scripts/sim.sh:243 (stat/Alter), scripts/sim.sh:244 (Vergleich), scripts/sim.sh:253 (5 s Pause, dann KILL)

AC-2. pgrep mit Muster auf den eigenen -derivedDataPath, gefolgt von Leerzeichen oder Zeilenende (sim.sh:249). Fremdprozess mit anderem Pfad bleibt am Leben (Test test_other_session_xcodebuild_survives und Eigenversuch mit Pfad foo2 gegen foo: Präfix-Nachbar überlebt, auch mit Zusatzargument und Unterordner). Kinder: pkill -P vor kill; Mutation ohne pkill -TERM -P macht 5 von 7 Wächter-Tests rot.
Code reference: scripts/sim.sh:249, scripts/test_sim_run_xcodebuild.py:142

AC-3. Exitcode über Markierungsdatei xcodebuild.hung, return 1 (sim.sh:266), unabhängig von pipefail. Mutation Markierung entfernt macht 2 Tests rot (mit und ohne pipefail). EXIT-Trap lief im Test (test_lock_released_after_hang).
Code reference: scripts/sim.sh:266, scripts/test_sim_run_xcodebuild.py:122 und :137

AC-4. Meldung geht per Umleitung nach stderr (sim.sh:246-248), nennt Minuten, Frist, letzte Logzeile (tail -n 1) und CoreSimulatorService; der Dienst wird nicht angefasst (kein launchctl, kein killall). Test prüft stderr-Inhalt.
Code reference: scripts/sim.sh:246, scripts/test_sim_run_xcodebuild.py:128

AC-5. Pipeline-Gleichheit gegen die Fassung im letzten Commit in 16 Kombinationen (alt, neu; set -eu, set -euo pipefail; xcbeautify da, fehlt; Aufruf einfach, Aufruf mit rc-Abfang) mit einem Stub, der Exit 65 liefert: Exitcode, stdout und stderr identisch (ohne pipefail 0, mit pipefail 65; Aufrufer mit rc-Abfang bekommt 65, Aufrufer mit set -e bricht ab). Pfad mit Leerzeichen und Klammern in SESSION_DERIVED_DATA funktioniert. Normaler Lauf: Wächter wird per kill beendet, wait räumt, keine Reste, auch nicht bei Aufruf in einer Befehlsersetzung (kein hängender Aufrufer, 0,2 s).
Code reference: scripts/sim.sh:262-267, scripts/sim.sh:259 (Pipeline mit status-Abfang)

AC-6. CLAUDE.md nennt 15 min (= 900 s), LOOSEENDS_SILENCE_MAX in Sekunden, die Meldung „hängt seit N min, abgebrochen“, letzte Logzeile, Sperre wird frei, kein Neustart des Dienstes. Sachlich korrekt zum Code.
Code reference: CLAUDE.md:76
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Zweite Runde gegen Reste, Signale und Testqualität.

Reste und Signale: Wird das Skript mit SIGTERM beendet, während xcodebuild läuft, stirbt nur die äußere Shell; Wächter-Subshell, xcodebuild-Stub und tee bleiben stehen (Eigenversuch, pgrep auf den Pfad). Das Verhalten für xcodebuild und tee war schon vor der Änderung so (kein Trap im alten Code). Neu ist der Wächter: er läuft verwaist weiter, feuert nach Ablauf der Frist Stille auf den verwaisten xcodebuild (nützlich) oder endet nach der Frist ohne Treffer. Begrenzt; seine Standardkanäle sind geschlossen, er hält keine Pipe des Aufrufers offen. Kein EXIT-Trap in run_xcodebuild. Die Spec fordert das nur für normalen Lauf und vorzeitiges Ende; daher LOW (F001).
Code reference: scripts/sim.sh:236 (Subshell ohne Bindung an den Elternprozess)

Prozess-Treffer: pgrep -f trifft den Wächter selbst nicht (die Kommandozeile der Subshell ist die des Skripts und enthält den Pfad nicht in der Form xcodebuild, Argumente, -derivedDataPath, Pfad); tee und Testprozess treffen nicht. Einzige Restunschärfe: ein fremder xcodebuild, dessen -derivedDataPath exakt unser Pfad plus Leerzeichen plus Text lautet (Pfad mit Leerzeichen und unserem Pfad als Präfix), wird fälschlich getötet (Eigenversuch: Fremdprozess mit dd-session-foo x starb, foo2, foo/sub, foo2 X=1 blieben). Unrealistisch (Pfade LooseEnds-session-Ordnername), LOW (F002).
Code reference: scripts/sim.sh:249

Testqualität (Mutationsprobe in Kopien unter dem Scratchpad, je 7 Wächter-Tests):
- Markierung und return 1 entfernt: 2 Tests rot.
- pgrep zu breit (ohne Pfad): 5 Tests rot, darunter test_other_session_xcodebuild_survives.
- pkill -TERM -P entfernt: 5 rot.
- Wächter pollt nie: 7 rot.
- pkill -KILL -P entfernt: alle grün (Lücke). Kein Test hat einen xcodebuild, der TERM ignoriert. Die Funktion des KILL-Pfads belegt mein Eigenversuch, die Tests nicht. LOW (F003).
Die Tests sind nicht vakuös: der Fremdprozess wird real gestartet und überlebt nur bei engem Muster, der Hängetest läuft gegen echte Subprozesse und prüft pid und Kind-pid per kill -0.
Code reference: scripts/test_sim_run_xcodebuild.py:112, scripts/test_sim_run_xcodebuild.py:142

Skepsis gegen frühe Einigkeit: ein hartes Gegenbeispiel gab es nicht; die drei Funde sind Rand- und Testlücken, keine Verletzung eines AC.
Code reference: CLAUDE.md:76 (AC-6), scripts/sim.sh:249
**Implementierer:** (nicht beteiligt, Kontextisolation)

## Findings
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/sim.sh:236
  Description: Die Wächter-Subshell kennt den Elternprozess nicht. Wird das Skript per SIGTERM beendet, lebt sie weiter (zusammen mit dem verwaisten xcodebuild, was schon vorher so war).
  Spec requirement: AC-5 — keine Wächterprozesse nach normalem oder vorzeitig beendetem Lauf (Signalfall nicht gefordert)
  Conflict: Nur außerhalb des spezifizierten Falls; der Wächter endet spätestens nach Ablauf der Frist Stille.
  Remediation: Optional trap für EXIT und TERM in run_xcodebuild, der den Wächter beendet.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/sim.sh:249
  Description: Das Muster vergleicht Text der Kommandozeile; ein fremder Pfad unser-Pfad plus Leerzeichen plus Text ist nicht von unserem Pfad plus nächstem Argument zu unterscheiden.
  Spec requirement: AC-2 — fremder xcodebuild bleibt unberührt
  Conflict: Nur bei Verzeichnissen mit Leerzeichen und Präfixbeziehung, praktisch ausgeschlossen.
  Remediation: Hinnehmen oder den Prozess über die PID des Pipeline-Kindes statt pgrep bestimmen.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/test_sim_run_xcodebuild.py:112
  Description: Kein Test deckt einen xcodebuild ab, der TERM ignoriert; die Mutation KILL entfernt bleibt grün.
  Spec requirement: AC-1 — TERM, nach 5 s KILL
  Conflict: Die KILL-Eskalation funktioniert (Eigenversuch), ist aber ungetestet.
  Remediation: Test mit Stub, der TERM ignoriert, Frist 2 s, Erwartung: tot nach ca. 8 s.

## Confirmations
Confirmation:
  AC: AC-1
  Code reference: scripts/sim.sh:244
  Evidence: Alter größer Frist löst aus, TERM dann KILL nach 5 s; Eigenversuch mit TERM-ignorierendem Stub endete nach 8,3 s, Test test_silent_xcodebuild_is_killed_after_deadline grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_sim_run_xcodebuild.py:142
  Evidence: Fremdprozess überlebt, Kinder tot; Mutation mit breitem pgrep macht den Test rot.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/sim.sh:266
  Evidence: Markierungsdatei erzwingt return 1 auch ohne pipefail; Trap-Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/sim.sh:246
  Evidence: stderr-Meldung mit Minuten, Frist, letzter Zeile, Dienst-Hinweis.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/sim.sh:262
  Evidence: 16-Kombinationen-Vergleich gegen den letzten Commit identisch; keine Reste nach normalem Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: CLAUDE.md:76
  Evidence: 15 min, LOOSEENDS_SILENCE_MAX, Meldung genannt, sachlich richtig.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
Tests: 9 passed, 0 failed, 0 übersprungen
Edge cases: geprüft; drei LOW-Funde (F001-F003), keiner bricht ein AC
Regressions: keine (Pipeline-Verhalten gegen den letzten Commit in 16 Kombinationen identisch)
Checklist: 6/6 points proven

## Geprüfte Dateien

- sha256:daee08a458253397fd71f4f21463b23ee9c2009bea7a30156fd58e6cab56df2e  CLAUDE.md
- sha256:184d32d0782d3cd4866be307876dd038c2c2cb8051df81c94f96ef78f7346240  scripts/sim.sh
- sha256:034aeaac95ffb7523a25d964075cb3cdc0108277c7be1e6ed7abfcf72dd6c6f5  scripts/test_sim_run_xcodebuild.py

## Prüfbasis

- base: fb7a8d5d10175be98b25752a9ad26b62b76d5fbf
- blob:50238b26dc1bf9aac8d6c9df605f4173cebddce1  CLAUDE.md
- blob:38b590fe7dc0024b8c3095f914b7e402b26a7a26  scripts/sim.sh
- blob:edb3f993092860395038fc28048dfcf3f6598ad1  scripts/test_sim_run_xcodebuild.py
