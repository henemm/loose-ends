"""Tests für Bauordner, rechnerweite Sperre und Unit-Ziel in sim.sh (#341, mit #304, #413, #294).

Die Funktionen werden wörtlich aus sim.sh gezogen, damit der Test das ausgelieferte Skript prüft.
Die Sperre liegt in jedem Test in einem eigenen Temp-Verzeichnis (LOOSEENDS_LOCK_DIR), nie in /tmp.

Aufruf: python3 -m unittest scripts/test_sim_lock.py
"""
import os
import re
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
LOCK_FUNCTIONS = ("proc_start", "lock_is_stale", "claim_testlock", "take_over_stale_lock", "acquire_testlock",
                  "release_testlock", "queue_enter", "queue_head", "queue_leave")
QUEUE_FUNCTIONS = ("queue_enter", "queue_head", "queue_leave")


def function_source(name, required=True):
    text = (SCRIPTS / "sim.sh").read_text()
    match = re.search(rf"(?ms)^{name}\(\) \{{.*?^\}}", text)
    if match is None:
        if not required:
            return ""
        raise AssertionError(f"{name}() fehlt in scripts/sim.sh")
    return match.group(0)


PRELUDE = "\n".join([
    "set -eo pipefail",
    'info()    { echo "[sim] $1" >&2; }',
    'success() { echo "[sim] $1" >&2; }',
    'warn()    { echo "[sim] $1" >&2; }',
    'error()   { echo "[sim] $1" >&2; }',
])


class LockHarness(unittest.TestCase):

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, True)
        self.lock = self.root / "testlauf.lock"
        self.env = dict(os.environ, LOOSEENDS_LOCK_DIR=str(self.lock), LOOSEENDS_LOCK_POLL="0.2",
                        LOOSEENDS_LOCK_REPORT="1", LOOSEENDS_LOCK_MAX="20")
        self.env.pop("LOOSEENDS_LOCK_OWNER", None)
        self.procs = []
        self.addCleanup(self.kill_all)

    def kill_all(self):
        for p in self.procs:
            if p.poll() is None:
                p.kill()
                p.wait()

    def script(self, body, worktree="wt-a"):
        functions = "\n".join(function_source(n, required=n not in QUEUE_FUNCTIONS) for n in LOCK_FUNCTIONS)
        return "\n".join([PRELUDE, f'PROJECT_DIR="{self.root / worktree}"', functions, body])

    def run_bash(self, body, env=None, worktree="wt-a", timeout=40):
        return subprocess.run(["bash", "-c", self.script(body, worktree)], env=env or self.env,
                              capture_output=True, text=True, timeout=timeout)

    def start_bash(self, body, worktree="wt-a"):
        p = subprocess.Popen(["bash", "-c", self.script(body, worktree)], env=self.env,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.procs.append(p)
        return p

    def wait_for_holder(self, timeout=10):
        pid_file = self.lock / "pid"
        end = time.time() + timeout
        while time.time() < end:
            if pid_file.exists() and "pid=" in pid_file.read_text():
                return pid_file.read_text()
            time.sleep(0.05)
        self.fail("Sperre wurde nicht angelegt")

    @property
    def queue(self):
        return Path(f"{self.lock}.queue")

    def marks(self):
        if not self.queue.is_dir():
            return []
        return sorted(m.name for m in self.queue.iterdir() if not m.name.startswith("."))

    def wait_for_marks(self, count, timeout=10):
        end = time.time() + timeout
        while time.time() < end:
            if len(self.marks()) >= count:
                return self.marks()
            time.sleep(0.05)
        self.fail(f"nach {timeout} s {len(self.marks())} statt {count} Wartemarken in {self.queue}")

    def put_mark(self, order, pid, start=None):
        """Wartemarke von Hand, Name wie in sim.sh: 20-stellige Nanosekunden, Bindestrich, PID."""
        mark = self.queue / f"{order:020d}-{pid}"
        mark.mkdir(parents=True)
        if start is not None:
            (mark / "pid").write_text(f"pid={pid}\nstart={start}\n")
        return mark

    def live_sleeper(self):
        sleeper = subprocess.Popen(["sleep", "60"])
        self.procs.append(sleeper)
        return sleeper

    def dead_pid(self):
        dead = subprocess.Popen(["true"])
        dead.wait()
        return dead.pid


class SessionKeyTests(unittest.TestCase):

    def key(self, project_dir, override=None):
        env = dict(os.environ)
        env.pop("CLAUDE_SESSION_ID", None)
        if override is not None:
            env["CLAUDE_SESSION_ID"] = override
        script = "\n".join([PRELUDE, f'PROJECT_DIR="{project_dir}"', 'DERIVED_DATA="/dd"',
                            function_source("session_key"), function_source("device_derived_data"),
                            'SESSION_ID="$(session_key)"', 'echo "$SESSION_ID"', "device_derived_data"])
        out = subprocess.run(["bash", "-c", script], env=env, check=True, capture_output=True,
                             text=True, timeout=10).stdout.splitlines()
        return out[0], out[1]

    def test_session_key_from_folder_name(self):
        key, device = self.key("/Users/x/loose-ends/.claude/worktrees/prancy-noodling-axolotl")
        self.assertEqual(key, "prancy-noodling-axolotl")
        self.assertEqual(device, "/dd/LooseEnds-device-prancy-noodling-axolotl")
        self.assertEqual(self.key("/tmp/foo bar+baz")[0], "foo-bar-baz")
        text = (SCRIPTS / "sim.sh").read_text()
        self.assertIn('SESSION_ID="$(session_key)"', text)
        self.assertNotIn("CLAUDE_SESSION_ID:-default", text)

    def test_session_key_override(self):
        self.assertEqual(self.key("/tmp/prancy-noodling-axolotl", override="abc")[0], "abc")


class UnitDestinationTests(unittest.TestCase):

    def destination_output(self, mac_switch):
        env = dict(os.environ)
        env.pop("LOOSEENDS_MAC_HOST", None)
        if mac_switch:
            env["LOOSEENDS_MAC_HOST"] = "1"
        script = "\n".join([
            PRELUDE, 'UNIT_TARGET="LooseEndsTests"', 'PROJECT="P"', 'SCHEME="S"',
            "ensure_project() { :; }", "measurement_status() { :; }",
            "acquire_testlock() { :; }", "release_testlock() { :; }",
            "mac_hosts_tests() { return 0; }",           # macOS ≥ Target, wie auf Hennings Mac
            "sw_vers() { echo 27.0.1; }", "deployment_target() { echo 27.0; }",
            'cmd_sim_unit() { echo "SIMULATOR $*"; }',
            'run_xcodebuild() { echo "XCODEBUILD $*"; }',
            function_source("cmd_unit"), "cmd_unit",
        ])
        r = subprocess.run(["bash", "-c", script], env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout + r.stderr

    def test_unit_never_macos_without_switch(self):
        out = self.destination_output(mac_switch=False)
        self.assertNotIn("platform=macOS", out)
        self.assertIn("SIMULATOR", out)
        self.assertIn("platform=macOS", self.destination_output(mac_switch=True))
        header = (SCRIPTS / "sim.sh").read_text().split("set -eo pipefail")[0]
        self.assertIn("LOOSEENDS_MAC_HOST", header)
        self.assertNotIn("macOS-Destination", header)


LOCKED_COMMANDS = ("cmd_unit", "cmd_build", "cmd_mac_build", "cmd_sim_unit", "cmd_test",
                   "cmd_test_proof", "cmd_launch")


class LockOrderTests(unittest.TestCase):
    """Ein wartender Lauf darf nichts aufräumen oder erzeugen, was der laufende braucht (#341)."""

    def test_lock_before_cleanup_and_generate(self):
        for name in LOCKED_COMMANDS:
            code = "\n".join(l for l in function_source(name).splitlines() if not l.strip().startswith("#"))
            lock = code.find("acquire_testlock")
            self.assertGreaterEqual(lock, 0, f"{name}: keine Sperre")
            for step in ("rm -rf", "mkdir", "cmd_generate", "ensure_project"):
                pos = code.find(step)
                if pos >= 0:
                    self.assertLess(lock, pos, f"{name}: {step} vor acquire_testlock")


class KeyboardHintTests(unittest.TestCase):
    """Frischer Simulator: der Tastatur-Hinweis „Speed up your typing…“ hängt XCTest auf (#341, AC-14)."""

    def test_boot_marks_continuous_path_hint_shown(self):
        code = function_source("cmd_boot")
        write = code.find("defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true")
        self.assertGreaterEqual(write, 0, "cmd_boot schreibt DidShowContinuousPathIntroduction nicht")
        self.assertLess(code.find("bootstatus"), write, "Einstellung vor dem fertigen Boot geschrieben")
        self.assertIn("|| warn", code[write:], "Fehler beim Schreiben wird verschluckt")


class TestLockTests(LockHarness):

    def test_two_runs_are_serialized(self):
        body = ('acquire_testlock "sim-unit"\n'
                'python3 -c "import time; print(\'start\', time.time())"\n'
                "sleep 1.5\n"
                'python3 -c "import time; print(\'end\', time.time())"\n'
                "release_testlock")
        a = self.start_bash(body, "wt-a")
        b = self.start_bash(body, "wt-b")
        outs = [p.communicate(timeout=30) for p in (a, b)]
        self.assertEqual([a.returncode, b.returncode], [0, 0], outs)
        spans = []
        for out, _ in outs:
            vals = dict(line.split() for line in out.splitlines())
            spans.append((float(vals["start"]), float(vals["end"])))
        first, second = sorted(spans)
        self.assertLessEqual(first[1], second[0], f"Läufe überlappen: {spans}")
        self.assertFalse(self.lock.exists(), "Sperre nach beiden Läufen nicht freigegeben")

    def test_orphan_lock_taken_over(self):
        holder = self.start_bash('acquire_testlock "test"\nsleep 60', "wt-a")
        self.wait_for_holder()
        os.kill(holder.pid, signal.SIGKILL)
        holder.wait()
        t0 = time.time()
        r = self.run_bash('acquire_testlock "build"\ncat "$LOOSEENDS_LOCK_DIR/pid"\nrelease_testlock', worktree="wt-b")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertLess(time.time() - t0, 5, "verwaiste Sperre nicht sofort übernommen")
        self.assertIn("worktree=", r.stdout)
        self.assertIn("wt-b", r.stdout)
        self.assertIn("command=build", r.stdout)

    def test_parallel_takeover_of_orphan_lock(self):
        """8 Wartende gegen eine verwaiste Sperre: keiner bricht ab, nie zwei zugleich drin (#341, F001)."""
        body = ('acquire_testlock "test"\n'
                f'mkdir "{self.root}/drin" || {{ echo UEBERLAPPUNG; exit 3; }}\n'
                f'sleep 0.05\nrmdir "{self.root}/drin"\nrelease_testlock')
        for _ in range(10):
            dead = subprocess.Popen(["true"])
            dead.wait()
            self.lock.mkdir()
            (self.lock / "pid").write_text(f"pid={dead.pid}\nstart=1\nworktree=alt\ncommand=test\n")
            procs = [self.start_bash(body, f"wt-{i}") for i in range(8)]
            outs = [p.communicate(timeout=30) for p in procs]
            self.assertEqual([p.returncode for p in procs], [0] * 8, outs)
            self.assertFalse(self.lock.exists(), "Sperre nach der Runde nicht freigegeben")
            self.assertEqual(self.marks(), [], "Wartemarken nach der Runde übrig (AC-7)")

    def test_start_time_mismatch_is_orphan(self):
        sleeper = subprocess.Popen(["sleep", "60"])
        self.procs.append(sleeper)
        self.lock.mkdir()
        (self.lock / "pid").write_text(f"pid={sleeper.pid}\nstart=1\nworktree=alt\ncommand=test\n")
        t0 = time.time()
        r = self.run_bash('acquire_testlock "build"\nrelease_testlock')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertLess(time.time() - t0, 5, "Sperre älter als der Prozess hinter der PID: PID wiederverwendet, verwaist")

    def test_live_holder_with_later_written_start_not_taken(self):
        """Handsperre mit start=$(date +%s) beim Schreiben: später als der Prozessstart, Halter lebt (#341)."""
        sleeper = subprocess.Popen(["sleep", "60"])
        self.procs.append(sleeper)
        later = int(time.time()) + 60
        self.assert_live_hand_lock_kept(f"pid={sleeper.pid}\nstart={later}\nworktree=hand\ncommand=sim-unit\n",
                                        sleeper.pid)

    def assert_live_hand_lock_kept(self, pid_text, pid):
        self.lock.mkdir()
        (self.lock / "pid").write_text(pid_text)
        r = self.run_bash('acquire_testlock "build"\necho bekommen', env=dict(self.env, LOOSEENDS_LOCK_MAX="2"))
        self.assertNotEqual(r.returncode, 0, "lebende Handsperre übernommen")
        self.assertNotIn("bekommen", r.stdout)
        self.assertIn(str(pid), r.stderr)
        self.assertTrue((self.lock / "pid").exists())

    def test_foreign_start_format_live_pid_not_taken(self):
        sleeper = subprocess.Popen(["sleep", "60"])
        self.procs.append(sleeper)
        self.assert_live_hand_lock_kept(f"pid={sleeper.pid}\nstart=Sa. 17 Okt. 2026 08:47:20 CEST\n"
                                        "worktree=hand\ncommand=test\n", sleeper.pid)

    def test_live_pid_without_start_not_taken(self):
        sleeper = subprocess.Popen(["sleep", "60"])
        self.procs.append(sleeper)
        self.assert_live_hand_lock_kept(f"pid={sleeper.pid}\nworktree=hand\ncommand=test\n", sleeper.pid)

    def test_locale_independent_start(self):
        de = dict(self.env, LANG="de_DE.UTF-8", LC_ALL="de_DE.UTF-8")
        holder = subprocess.Popen(["bash", "-c", self.script('acquire_testlock "test"\nsleep 60', "wt-de")],
                                  env=de, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.procs.append(holder)
        text = self.wait_for_holder()
        self.assertRegex(text, r"(?m)^start=\d+$", "Startzeit muss eine reine Zahl sein")
        c = dict(self.env, LC_ALL="C", LOOSEENDS_LOCK_MAX="2")
        r = self.run_bash('acquire_testlock "build"\necho bekommen', env=c, worktree="wt-c")
        self.assertNotEqual(r.returncode, 0, "unter anderer Locale als verwaist übernommen")
        self.assertNotIn("bekommen", r.stdout)

    def test_hand_lock_without_pid_waits(self):
        self.lock.mkdir()
        env = dict(self.env, LOOSEENDS_LOCK_HAND_GRACE="2")
        t0 = time.time()
        r = self.run_bash('acquire_testlock "build"\nrelease_testlock', env=env)
        waited = time.time() - t0
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertGreaterEqual(waited, 1.5, "Handsperre ohne pid sofort übernommen")
        self.assertLess(waited, 10)

    def test_hand_lock_file_waits_then_taken_over(self):
        """Die alte Handabsprache legte die Sperre als Datei an; sie gilt wie eine Handsperre ohne pid."""
        self.lock.write_text("hand\n")
        env = dict(self.env, LOOSEENDS_LOCK_HAND_GRACE="2")
        t0 = time.time()
        r = self.run_bash('acquire_testlock "build"\necho bekommen\nrelease_testlock', env=env)
        waited = time.time() - t0
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("bekommen", r.stdout)
        self.assertGreaterEqual(waited, 1.5, "Datei-Handsperre sofort übernommen")
        self.assertLess(waited, 10)

    def test_reentrant(self):
        functions = "\n".join(function_source(n) for n in LOCK_FUNCTIONS)
        inner = "\n".join([PRELUDE, functions, 'acquire_testlock "test"', "echo inner-ok", "release_testlock"])
        inner_file = self.root / "inner.sh"
        inner_file.write_text(inner)
        env = dict(self.env, LOOSEENDS_LOCK_MAX="3")
        r = self.run_bash(f'acquire_testlock "test-proof"\nbash "{inner_file}"\n'
                          '[ -f "$LOOSEENDS_LOCK_DIR/pid" ] && echo outer-still-held\nrelease_testlock', env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("inner-ok", r.stdout)
        self.assertIn("outer-still-held", r.stdout, "innerer Aufruf hat die äußere Sperre freigegeben")

    def test_wait_message_and_cap(self):
        self.start_bash('acquire_testlock "test-proof"\nsleep 60', "wt-holder")
        holder = self.wait_for_holder()
        holder_pid = re.search(r"pid=(\d+)", holder).group(1)
        env = dict(self.env, LOOSEENDS_LOCK_MAX="3")
        t0 = time.time()
        r = self.run_bash('acquire_testlock "build"\necho bekommen', env=env, worktree="wt-waiter")
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn("bekommen", r.stdout)
        self.assertLess(time.time() - t0, 10)
        self.assertIn("wt-holder", r.stderr)
        self.assertIn("test-proof", r.stderr)
        self.assertIn(holder_pid, r.stderr)
        self.assertGreaterEqual(r.stderr.count("wt-holder"), 2, "keine wiederholte Statuszeile")


class QueueTests(LockHarness):
    """Warteliste (#516 Schnitt 2): wer zuerst wartet, bekommt die Sperre zuerst."""

    HOLD = 'acquire_testlock "{what}"\nwhile [ ! -e "{go}" ]; do sleep 0.05; done\nrelease_testlock'
    TURN = 'acquire_testlock "{what}"\necho {name} >> "{order}"\nsleep 0.3\nrelease_testlock'
    LIST = 'ls -A "{queue}" | grep -v "^\\." || true'

    def env_with(self, **extra):
        return dict(self.env, **extra)

    def test_queue_functions_exist(self):
        for name in QUEUE_FUNCTIONS:
            function_source(name)

    def test_waiters_get_lock_in_arrival_order(self):
        go, order = self.root / "go", self.root / "order"
        self.start_bash(self.HOLD.format(what="halter", go=go), "wt-h")
        self.wait_for_holder()
        waiters = []
        for i, name in enumerate(("A", "B", "C"), start=1):
            waiters.append(self.start_bash(self.TURN.format(what=name, name=name, order=order), f"wt-{name}"))
            self.wait_for_marks(i)
        go.touch()
        outs = [p.communicate(timeout=30) for p in waiters]
        self.assertEqual([p.returncode for p in waiters], [0, 0, 0], outs)
        self.assertEqual(order.read_text().split(), ["A", "B", "C"], "Reihenfolge ≠ Reihenfolge des Anstellens")
        self.assertEqual(self.marks(), [])

    def test_live_head_blocks_free_lock(self):
        """Nur der Kopf versucht mkdir: eine freie Sperre bleibt frei, solange ein lebender Kopf vorn steht."""
        sleeper = self.live_sleeper()
        head = self.put_mark(1, sleeper.pid, start=int(time.time()) + 60)
        r = self.run_bash('acquire_testlock "build"\necho bekommen', env=self.env_with(LOOSEENDS_LOCK_MAX="2"))
        self.assertNotEqual(r.returncode, 0, "an einem lebenden Kopf vorbei die Sperre geholt")
        self.assertNotIn("bekommen", r.stdout)
        self.assertEqual(self.marks(), [head.name], "eigene Marke nach Abbruch übrig oder Kopf gelöscht")

    def test_dead_head_is_removed_and_next_proceeds(self):
        sleeper = self.live_sleeper()
        self.put_mark(1, self.dead_pid(), start=1)          # PID tot
        self.put_mark(2, sleeper.pid, start=1)              # PID lebt, ist aber jünger als start: wiederverwendet
        t0 = time.time()
        r = self.run_bash('acquire_testlock "build"\n' + self.LIST.format(queue=self.queue) +
                          '\necho bekommen\nrelease_testlock', env=self.env_with(LOOSEENDS_LOCK_MAX="5"))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertLess(time.time() - t0, 4, "tote Köpfe nicht sofort gelöscht")
        self.assertEqual(r.stdout.split(), ["bekommen"], "Marken nach dem Erhalt der Sperre übrig")
        self.assertEqual(self.marks(), [])

    def test_queue_mark_without_pid_file_dead_after_10s(self):
        mark = self.put_mark(1, 99999)
        r = self.run_bash('acquire_testlock "build"\necho bekommen', env=self.env_with(LOOSEENDS_LOCK_MAX="2"))
        self.assertNotEqual(r.returncode, 0, "frische Marke ohne pid-Datei übergangen")
        self.assertIn(mark.name, self.marks())
        old = time.time() - 20
        os.utime(mark, (old, old))
        r = self.run_bash('acquire_testlock "build"\necho bekommen\nrelease_testlock',
                          env=self.env_with(LOOSEENDS_LOCK_MAX="5"))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("bekommen", r.stdout)
        self.assertEqual(self.marks(), [], "Marke ohne pid-Datei älter als 10 s nicht gelöscht")

    def test_abort_removes_own_mark_and_names_position(self):
        self.start_bash(self.HOLD.format(what="halter", go=self.root / "nie"), "wt-h")
        self.wait_for_holder()
        sleeper = self.live_sleeper()
        head = self.put_mark(1, sleeper.pid, start=int(time.time()) + 60)
        r = self.run_bash('acquire_testlock "build"\necho bekommen', env=self.env_with(LOOSEENDS_LOCK_MAX="2"))
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn("bekommen", r.stdout)
        self.assertRegex(r.stderr, r"Platz 2\b", "Abbruchmeldung nennt den Platz in der Warteliste nicht")
        self.assertEqual(self.marks(), [head.name], "eigene Marke nach Abbruch übrig")

    def test_success_and_exit_trap_remove_mark_queue_dir_stays(self):
        r = self.run_bash('trap release_testlock EXIT\nacquire_testlock "build"\n' +
                          self.LIST.format(queue=self.queue) + '\necho bekommen')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.split(), ["bekommen"], "eigene Marke nach Erfolg übrig")
        self.assertTrue(self.queue.is_dir(), "Warteliste entfernt (ENOENT-Rennen)")
        # Ein Wartender, der per TERM endet, räumt seine Marke über den EXIT-Trap.
        go = self.root / "go"
        self.start_bash(self.HOLD.format(what="halter", go=go), "wt-h")
        self.wait_for_holder()
        waiter = self.start_bash('trap release_testlock EXIT\nacquire_testlock "build"\necho bekommen', "wt-w")
        self.wait_for_marks(1)
        waiter.send_signal(signal.SIGTERM)
        waiter.communicate(timeout=10)
        self.assertEqual(self.marks(), [], "Marke eines per TERM beendeten Wartenden übrig")
        self.assertTrue(self.queue.is_dir())
        go.touch()

    def test_reentrant_does_not_enqueue(self):
        function_source("queue_enter")
        entered = self.root / "entered"
        spy = (f'eval "orig_$(declare -f queue_enter)"\n'
               f'queue_enter() {{ echo x >> "{entered}"; orig_queue_enter "$@"; }}\n')
        inner_file = self.root / "inner.sh"
        functions = "\n".join(function_source(n) for n in LOCK_FUNCTIONS)
        inner_file.write_text("\n".join([PRELUDE, functions, spy, 'acquire_testlock "test"', "echo inner-ok"]))
        r = self.run_bash(spy + f'acquire_testlock "test-proof"\n: > "{entered}"\nacquire_testlock "again"\n'
                          f'bash "{inner_file}"\nrelease_testlock', env=self.env_with(LOOSEENDS_LOCK_MAX="3"))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("inner-ok", r.stdout)
        self.assertEqual(entered.read_text(), "", "Halter oder Kind des Halters hat sich angestellt")

    def test_mixed_mode_legacy_holder_and_stale_takeover(self):
        """Eine Sperre ohne Liste (Handskript) verklemmt nichts; wird sie verwaist, kommen die Wartenden der Reihe nach."""
        legacy = self.live_sleeper()
        self.lock.mkdir()
        (self.lock / "pid").write_text(f"pid={legacy.pid}\nstart={int(time.time()) + 60}\nworktree=hand\ncommand=test\n")
        order = self.root / "order"
        waiters = []
        for i, name in enumerate(("W", "V"), start=1):
            waiters.append(self.start_bash(self.TURN.format(what=name, name=name, order=order), f"wt-{name}"))
            self.wait_for_marks(i)
        legacy.kill()
        legacy.wait()
        outs = [p.communicate(timeout=30) for p in waiters]
        self.assertEqual([p.returncode for p in waiters], [0, 0], outs)
        self.assertEqual(order.read_text().split(), ["W", "V"])
        self.assertEqual(self.marks(), [])


if __name__ == "__main__":
    unittest.main()
