"""Paralleler Läufer der Skripttests (#995).

Aufruf: python3 scripts/run_script_tests.py [ordner]
Je Modul `test_*.py` ein eigener Prozess `python -m unittest <modul> -v` mit dem Ordner als Arbeitsordner
(wie `unittest discover -s scripts`); Threads warten nur auf die Prozesse. Worker: SCRIPT_TESTS_WORKERS,
sonst max(4, min(8, Kerne)); Zeitlimit je Modul SCRIPT_TESTS_TIMEOUT Sekunden, Standard 600.
"""
import os
import re
import signal
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HEAVY = ("test_asc_store_submit", "test_sim_run_xcodebuild", "test_sim_lock", "test_asc_beta_invite",
         "test_asc_store_version")
LOCK = threading.Lock()


def modules(folder):
    return [p.stem for p in Path(folder).glob("test_*.py")]


def workers(env, cpu):
    if env.get("SCRIPT_TESTS_WORKERS"):
        return int(env["SCRIPT_TESTS_WORKERS"])
    return max(4, min(8, cpu or 4))


def ordered(folder, names):
    """Bekannte schwere Module vorn, dann nach Dateigröße absteigend, dann Name: nur Planung der Wartezeit."""
    def key(name):
        heavy = HEAVY.index(name) if name in HEAVY else len(HEAVY)
        return heavy, -(Path(folder) / f"{name}.py").stat().st_size, name
    return sorted(names, key=key)


def run_one(folder, name, timeout):
    """Ein Modul in einer eigenen Prozessgruppe; bei Zeitüberschreitung wird die ganze Gruppe beendet."""
    start = time.monotonic()
    proc = subprocess.Popen([sys.executable, "-m", "unittest", name, "-v"], cwd=folder, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    try:
        out, err = proc.communicate(timeout=timeout)
        ok, note = proc.returncode == 0, ""
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        out, err = proc.communicate()
        ok, note = False, f"\n{name}: Zeitlimit {timeout} s überschritten, Prozess beendet\n"
    took = time.monotonic() - start
    with LOCK:
        if ok:
            count = re.search(r"^Ran (\d+) tests?", err, re.M)
            print(f"ok   {name} {took:.1f} s, {count.group(1) if count else '?'} Tests", flush=True)
        else:
            print(f"===== ROT {name} ({took:.1f} s) =====\n{out}{err}{note}===== Ende {name} =====", flush=True)
    return name, ok


def main(argv, env):
    folder = Path(argv[1]) if len(argv) > 1 else Path(__file__).resolve().parent
    timeout = float(env.get("SCRIPT_TESTS_TIMEOUT") or 600)
    names = ordered(folder, modules(folder))
    with ThreadPoolExecutor(max_workers=workers(env, os.cpu_count())) as pool:
        results = list(pool.map(lambda name: run_one(folder, name, timeout), names))
    red = sorted(name for name, ok in results if not ok)
    print(f"{len(results)} Module, {len(red)} rot" + (f": {', '.join(red)}" if red else ""), flush=True)
    return 0 if results and not red else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv, os.environ))
