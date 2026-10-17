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
LOCK_FUNCTIONS = ("lock_is_stale", "acquire_testlock", "release_testlock")


def function_source(name):
    text = (SCRIPTS / "sim.sh").read_text()
    match = re.search(rf"(?ms)^{name}\(\) \{{.*?^\}}", text)
    if match is None:
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
        functions = "\n".join(function_source(n) for n in LOCK_FUNCTIONS)
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

    def test_start_time_mismatch_is_orphan(self):
        sleeper = subprocess.Popen(["sleep", "60"])
        self.procs.append(sleeper)
        self.lock.mkdir()
        (self.lock / "pid").write_text(f"pid={sleeper.pid}\nstart=Thu Jan  1 00:00:00 1970\n"
                                       "worktree=alt\ncommand=test\n")
        t0 = time.time()
        r = self.run_bash('acquire_testlock "build"\nrelease_testlock')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertLess(time.time() - t0, 5, "PID lebt, Startzeit fremd: muss als verwaist gelten")

    def test_hand_lock_without_pid_waits(self):
        self.lock.mkdir()
        env = dict(self.env, LOOSEENDS_LOCK_HAND_GRACE="2")
        t0 = time.time()
        r = self.run_bash('acquire_testlock "build"\nrelease_testlock', env=env)
        waited = time.time() - t0
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertGreaterEqual(waited, 1.5, "Handsperre ohne pid sofort übernommen")
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


if __name__ == "__main__":
    unittest.main()
