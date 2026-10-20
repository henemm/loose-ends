# Adversary Dialog — fix-516-schnitt-2-warteliste
Spec: docs/specs/tooling/fix-516-schnitt-2-warteliste.md
Datum: 2026-10-20 07:46

## Checkliste
- [x] **AC-1:** Given mehrere Läufe warten auf die belegte Testsperre, When der Halter sie freigibt, Then bekommt sie der zuerst Angestellte zuerst (Marke `<Sperre>.queue/<time_ns 20-stellig>-<pid>`, nur der Kopf versucht `mkdir`).
- [x] **AC-2:** Given der Kopf der Liste ist tot (PID tot, PID wiederverwendet mit Prozessstart jünger als `start=`, oder Marke ohne pid-Datei älter als 10 s), When ein Wartender prüft, Then wird die Marke gelöscht und der Nächste rückt nach; eine Marke ohne pid-Datei unter 10 s gilt als lebend.
- [x] **AC-3:** Given ein Wartender erreicht `LOOSEENDS_LOCK_MAX`, When `acquire_testlock` abbricht, Then ist seine Marke entfernt und die Meldung nennt seinen Platz in der Liste.
- [x] **AC-4:** Given ein Lauf hat die Sperre bekommen oder endet über den EXIT-Trap `release_testlock`, When er fertig ist, Then ist seine Marke entfernt und `<Sperre>.queue` selbst bleibt bestehen.
- [x] **AC-5:** Given der Aufrufer ist Halter (`$$`) oder Kind des Halters (`LOOSEENDS_LOCK_OWNER`), When er `acquire_testlock` ruft, Then stellt er sich nicht an und kehrt sofort zurück.
- [x] **AC-6:** Given ein Teilnehmer ohne Liste (nur `mkdir` der Sperre) drängelt sich vor, When die Sperre frei wird, Then verklemmt nichts: der Kopf wartet weiter und bekommt sie danach; eine verwaiste Sperre übernimmt weiterhin jeder Wartende.
- [x] **AC-7:** Given 8 Wartende × 10 Runden um eine verwaiste Sperre, When `test_parallel_takeover_of_orphan_lock` läuft, Then ist er grün, `<Sperre>.queue` danach leer, und die Laufzeit bleibt unter der 30-s-Grenze.
- [x] **AC-8:** Given sim.sh stirbt (auch per KILL) während der Wächter läuft, When der nächste Takt oder die Frist kommt, Then endet die Wächter-Subshell (`kill -0 $$` je Takt und vor `pgrep`/Kill) und beendet keinen Prozess mehr; der `xcodebuild` einer per KILL gestorbenen sim.sh bleibt dabei bewusst als Waise bestehen.
- [x] **AC-9:** Given ein `xcodebuild` mit `-derivedDataPath` dieser Sitzung ignoriert TERM, When der Wächter auslöst, Then wird er nach TERM + 5 s per KILL beendet (Test mit Stub `trap '' TERM`).
- [x] **AC-10:** Given `CLAUDE.md`, Absatz „Parallele Sitzungen“, When die Warteliste eingebaut ist, Then nennt er sie in einem Satz (wer zuerst wartet, bekommt die Sperre zuerst; Marke in `<Sperre>.queue`; Handskripte ohne Liste können vordrängeln).

## Dialog

### Runde 1
**Adversary:** Volle Suite (scripts/test_sim_lock.py, test_sim_run_xcodebuild.py, test_sim_proof.py): 51 Tests, OK, 0 uebersprungen, 0 Fehler (adversary-test-output.txt). Jeder Punkt mit Beleg:

Confirmation:
  AC: AC-1
  Code reference: scripts/sim.sh:109
  Evidence: acquire_testlock stellt sich per queue_enter an und ruft mkdir der Sperre nur, wenn queue_head die eigene Marke liefert. Test test_waiters_get_lock_in_arrival_order gruen; eigene Probe t2 (Halter, A, B, C): Reihenfolge der Marken = Ankunft, C bekam die Sperre nach Wegfall von A/B.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/sim.sh:165
  Evidence: queue_head prueft nur den Kopf, loescht bei toter PID, jungerem Prozessstart oder pid-loser Marke aelter 10 s (stat mtime). Probe: kill -9 auf Kopf A, C rueckte nach. Tests dead_head / without_pid_file gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/sim.sh:109
  Evidence: Bei elapsed >= max wird queue_leave vor error aufgerufen, Meldung enthaelt Platz n von total. Test test_abort_removes_own_mark_and_names_position gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/sim.sh:226
  Evidence: release_testlock ruft queue_leave (Z. 190) vor dem Halter-Test; queue_enter legt die Liste mit mkdir -p an, nichts entfernt sie. Probe: TERM auf wartenden B entfernte nur dessen Marke (EXIT-Trap), Liste blieb. Test test_success_and_exit_trap... gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/sim.sh:109
  Evidence: Der Reentrant-Return steht vor queue_enter. Test test_reentrant_does_not_enqueue gruen (Halter $$ und LOOSEENDS_LOCK_OWNER).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_sim_lock.py:461
  Evidence: Kein Test fuer das Vordraengeln selbst (nur Handsperre mit verwaister pid). Selbst nachgestellt (Probe t1): Halter 4 s, A, B angestellt, dann Nur-mkdir-Teilnehmer; Ergebnis Reihenfolge holder, legacy, A, B, danach .queue leer, Sperre frei, kein Verklemmen. Eine verwaiste Sperre uebernimmt jeder Wartende (lock_is_stale/take_over_stale_lock vor dem Kopf-Test, sim.sh Z. 118).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_sim_lock.py:240
  Evidence: test_parallel_takeover_of_orphan_lock (8x10 mit .queue-Pruefung) gruen im Gesamtlauf von 125 s fuer 51 Tests; Einzel-Laufzeit unter der Grenze (Test selbst prueft sie).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/sim.sh:303
  Evidence: kill -0 $$ je Takt (Z. 303) und vor pgrep/Kill (Z. 310); in der Subshell ist $$ die PID von sim.sh. Test test_watcher_ends_when_script_dies (scripts/test_sim_run_xcodebuild.py:170) gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/test_sim_run_xcodebuild.py:197
  Evidence: Stub mit trap TERM wird nach TERM + 5 s per KILL beendet, Test gruen (Dauer-Assertion >= 5 s).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: CLAUDE.md:76
  Evidence: Absatz Parallele Sitzungen nennt: wer zuerst wartet, Marke in <Sperre>.queue, nur der Kopf greift zu, Handskripte koennen vordraengeln.
  Status: CONFIRMED

Gebohrt ohne Treffer: set -e/pipefail (queue_head/queue_enter laufen im until-Kontext bzw. mit || true; Probe mit set -eo pipefail lief), Verklemmen bei totem/getermtem Kopf, Markenkollision (Name enthaelt ns und pid), Platz-Meldung ohne Treffer-Glob.
**Implementierer:** (n/a, isoliert)

### Runde 2
**Adversary:** Zweiter Durchgang auf Schwachstellen.
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/sim.sh:165
  Description: queue_head prueft die eigene Marke nicht auf Existenz. Wuerde sie von aussen geloescht (etwa manuell), liefert queue_head nie QUEUE_MARK und der Wartende laeuft bis LOOSEENDS_LOCK_MAX ohne Zugriff, obwohl die Sperre frei ist.
  Spec requirement: AC-2 — nur tote Koepfe werden entfernt; eigene Marke wird nicht beruecksichtigt
  Conflict: Nur theoretisch (nur Handeingriff), bricht nach Max mit klarer Meldung ab, kein Verklemmen anderer. Kein Blocker.
  Remediation: Optional: eigene Marke bei Verlust neu anstellen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_sim_lock.py:461
  Description: Das Vordraengeln eines Nur-mkdir-Teilnehmers an einem wartenden Kopf vorbei (AC-6 Kern) hat keinen eigenen Test; der vorhandene Test deckt nur Handsperre mit verwaister pid ab.
  Spec requirement: AC-6 — Test Plan nennt test_mixed_mode_legacy_waiter_can_cut_in_but_nothing_deadlocks
  Conflict: Verhalten per Probe belegt, Regressionsschutz fehlt.
  Remediation: Test ergaenzen (Probe t1 als Vorlage).

Weitere Proben (PID-Wiederverwendung, Abbruch durch TERM, Kopf kill -9, Reihenfolge nach Vordraengler) ohne Fehler. F001 (Waise) wie in der Spec bewusst; der Waise-Fall ist per Design akzeptiert.
**Implementierer:** (n/a)

### Runde 3
**Adversary:** Nachprüfung F002. Test test_mixed_mode_legacy_waiter_can_cut_in_but_nothing_deadlocks gelesen: Kopf A steht mit Marke in der Liste, der Teilnehmer ohne Liste (nur mkdir) startet und meldet sich per ready-Datei, A wird per SIGSTOP angehalten, erst danach gibt der Halter frei. Damit kann nur L die Sperre holen (deterministisch, kein Zeitfenster); danach SIGCONT, erwartet Reihenfolge L, A, leere Liste, keine Sperre uebrig. Kein wackelnder Teil gefunden. 6 Einzelläufe OK, Gesamtlauf neu: 52 Tests, OK, 0 uebersprungen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_sim_lock.py:486
  Description: Der fehlende Test fuers Vordraengeln ist nachgeliefert und belegt es deterministisch.
  Spec requirement: AC-6
  Conflict: behoben, kein Konflikt mehr
  Remediation: erledigt

Confirmation:
  AC: AC-6
  Code reference: scripts/test_sim_lock.py:486
  Evidence: Test belegt Vordraengeln (L vor A) und anschliessendes Nachruecken des Kopfes ohne Verklemmen.
  Status: CONFIRMED
**Implementierer:** F002 behoben, sim.sh unveraendert.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:d755a039731cc1f5542a6d79f7bc747166e619fe3106a672215c476f84409aef  CLAUDE.md
- sha256:b432ac44d7022b7bdbff96ffcaa1aeaf90892ec8e882bb859153d20aa9eb1c7f  scripts/sim.sh
- sha256:d0cf77b6ebbd766ae21eadca0dd255bf99ad18d31e213e7abd630354bd11fc27  scripts/test_sim_lock.py
- sha256:0d899fb7744d2c0c592532dad17743bf1530f99a4959c3e0dcbf51ce43945488  scripts/test_sim_run_xcodebuild.py

## Prüfbasis

- base: 92c4a7db2feb2fcb33692174263ee08b0f26e257
- blob:c66b56d5b7e45286f87c4922835f3fabfe7888bf  CLAUDE.md
- blob:3610e6685a4a762ed318efe57fbffdb425dd5261  scripts/sim.sh
- blob:150d26c1953fae1ddd9a0f53aa8791cd36947c00  scripts/test_sim_lock.py
- blob:206316389f865b8d572ca6332c03b24fcdb93a99  scripts/test_sim_run_xcodebuild.py
