#!/usr/bin/env python3
"""Test bench for the archive verification step in .github/workflows/testflight.yml (#174).

Takes the step's shell block out of the workflow file, runs it against fixture archives and
checks exit code and error lines. With REAL_ARCHIVE=<path> it also runs against a real archive
(Test 4b). Run: python3 docs/artifacts/fix-174-testflight-ios27/verify_archive_test.py
"""
import os
import plistlib
import subprocess
import sys
import tempfile
import time

import yaml

STARTED = time.monotonic()

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
WORKFLOW = os.path.join(ROOT, ".github", "workflows", "testflight.yml")
STEP_NAME = "Verify the archive is built against the iOS 27 SDK"
BUILD = "4242"

APP_KEYS = {
    "NSMicrophoneUsageDescription": "mic",
    "NSSpeechRecognitionUsageDescription": "speech",
    "NSCalendarsFullAccessUsageDescription": "calendar",
    "ITSAppUsesNonExemptEncryption": False,
}
WATCH_KEYS = {"NSMicrophoneUsageDescription": "mic", "NSSpeechRecognitionUsageDescription": "speech"}
# relative bundle path, bundle id, sdk, extra keys
TARGETS = [
    ("LooseEnds.app", "com.henning.looseends", "iphoneos27.0", APP_KEYS),
    ("LooseEnds.app/Watch/LooseEndsWatch.app", "com.henning.looseends.watchkitapp", "watchos27.0", WATCH_KEYS),
    ("LooseEnds.app/PlugIns/LooseEndsWidgets.appex", "com.henning.looseends.widgets", "iphoneos27.0", {}),
    ("LooseEnds.app/PlugIns/LooseEndsShare.appex", "com.henning.looseends.share", "iphoneos27.0", {}),
]


def load_workflow():
    with open(WORKFLOW) as f:
        return yaml.safe_load(f)


def step_script():
    steps = load_workflow()["jobs"]["upload"]["steps"]
    for step in steps:
        if step.get("name") == STEP_NAME:
            return step["run"]
    return None


def make_archive(base, mutate=None):
    """Builds a fixture archive that mirrors the real Xcode 27.0 layout (checked 2026-10-03)."""
    archive = os.path.join(base, "LooseEnds.xcarchive")
    apps = os.path.join(archive, "Products", "Applications")
    plists = {}
    for rel, bid, sdk, extra in TARGETS:
        plists[bid] = {
            "CFBundleIdentifier": bid, "DTSDKName": sdk, "MinimumOSVersion": "27.0",
            "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": BUILD, **extra,
        }
    dsyms = {os.path.basename(rel) for rel, *_ in TARGETS}
    skip = set()
    if mutate:
        mutate(plists, dsyms, skip)
    for rel, bid, *_ in TARGETS:
        if bid in skip:
            continue
        os.makedirs(os.path.join(apps, rel), exist_ok=True)
        with open(os.path.join(apps, rel, "Info.plist"), "wb") as f:
            plistlib.dump(plists[bid], f)
    for name in dsyms:
        os.makedirs(os.path.join(archive, "dSYMs", name + ".dSYM"), exist_ok=True)
    return archive


def run_step(script, archive):
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as summary:
        path = summary.name
    env = dict(os.environ, ARCHIVE=archive, BUILD=BUILD, GITHUB_STEP_SUMMARY=path)
    # same shell GitHub uses for `run:` steps
    proc = subprocess.run(["bash", "--noprofile", "--norc", "-eo", "pipefail", "-c", script],
                          env=env, capture_output=True, text=True)
    with open(path) as f:
        table = f.read()
    os.unlink(path)
    return proc.returncode, proc.stdout + proc.stderr, table


def set_key(bid, key, value):
    def mutate(plists, dsyms, skip):
        plists[bid][key] = value
    return mutate


def del_key(bid, key):
    def mutate(plists, dsyms, skip):
        plists[bid].pop(key, None)
    return mutate


def drop_target(bid):
    def mutate(plists, dsyms, skip):
        skip.add(bid)
    return mutate


def drop_dsym(name):
    def mutate(plists, dsyms, skip):
        dsyms.discard(name)
    return mutate


def old_sdk(plists, dsyms, skip):
    for p in plists.values():
        p["DTSDKName"] = p["DTSDKName"].replace("27.0", "26.6")
        p["MinimumOSVersion"] = "26.0"


RED_CASES = [
    ("Test 2 (a) old SDK 26.6 / minimum 26.0", old_sdk, "linked against 'iphoneos26.6'"),
    ("Test 3 (b) share extension missing", drop_target("com.henning.looseends.share"),
     "Target com.henning.looseends.share not found in the archive"),
    ("Test 3b (c) widgets build number differs", set_key("com.henning.looseends.widgets", "CFBundleVersion", "1"),
     "com.henning.looseends.widgets version '0.1.0 (1)'"),
    ("Test 3b (d) watch dSYM missing", drop_dsym("LooseEndsWatch.app"),
     "com.henning.looseends.watchkitapp has no dSYM"),
    ("Test 3b (e) app without microphone text", del_key("com.henning.looseends", "NSMicrophoneUsageDescription"),
     "com.henning.looseends: NSMicrophoneUsageDescription"),
    ("Test 3b (f) encryption flag true", set_key("com.henning.looseends", "ITSAppUsesNonExemptEncryption", True),
     "ITSAppUsesNonExemptEncryption is 'true', expected false"),
]


def check(results, name, ok, detail):
    results.append(ok)
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
    if detail:
        print("      " + detail.strip().replace("\n", "\n      "))


def test_structure(results):
    wf = load_workflow()
    job = wf["jobs"]["upload"]
    text = open(WORKFLOW).read()
    check(results, "Test 5 runs-on is xcode-27", job.get("runs-on") == "xcode-27", f"runs-on: {job.get('runs-on')}")
    check(results, "Test 5 no sed lowering, no 26.0 in workflow", "sed -i" not in text and "26.0" not in text, "")
    names = [s.get("name") for s in job["steps"]]
    select = next((s for s in job["steps"] if s.get("name") == "Select Xcode 27.0"), None)
    check(results, "Test 5 step 'Select Xcode 27.0' pins /Applications/Xcode_27.app",
          bool(select) and "/Applications/Xcode_27.app" in select["run"] and '"Xcode 27.0"' in select["run"], "")
    order_ok = STEP_NAME in names and "Archive" in names and "Upload to TestFlight" in names and \
        names.index("Archive") < names.index(STEP_NAME) < names.index("Upload to TestFlight")
    check(results, "Test 5 verify step sits between Archive and Upload", order_ok, "")
    for step in job["steps"]:
        if "run" in step:
            syntax = subprocess.run(["bash", "-n", "-c", step["run"]], capture_output=True, text=True)
            if syntax.returncode != 0:
                check(results, f"Test 5 bash -n '{step.get('name')}'", False, syntax.stderr)


def main():
    results = []
    test_structure(results)
    script = step_script()
    if script is None:
        check(results, f"step '{STEP_NAME}' exists in testflight.yml", False, "step not found")
        print(f"\nRESULT: FAILED ({results.count(False)} failing)")
        return 1
    for name, mutate, expected in RED_CASES:
        with tempfile.TemporaryDirectory() as tmp:
            code, out, table = run_step(script, make_archive(tmp, mutate))
        check(results, name, code != 0 and expected in out and "FEHLER" in table,
              f"exit {code}; " + "; ".join(line for line in out.splitlines() if "::error::" in line))
    with tempfile.TemporaryDirectory() as tmp:
        code, out, table = run_step(script, make_archive(tmp))
    check(results, "Test 4 correct fixture passes", code == 0 and table.count("| OK |") == 4, f"exit {code}\n{table}{out}")
    real = os.environ.get("REAL_ARCHIVE")
    if real:
        env_build = os.environ.get("REAL_BUILD", BUILD)
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as summary:
            path = summary.name
        env = dict(os.environ, ARCHIVE=real, BUILD=env_build, GITHUB_STEP_SUMMARY=path)
        proc = subprocess.run(["bash", "--noprofile", "--norc", "-eo", "pipefail", "-c", script],
                              env=env, capture_output=True, text=True)
        table = open(path).read()
        os.unlink(path)
        check(results, "Test 4b real Xcode 27.0 archive passes",
              proc.returncode == 0 and table.count("| OK |") == 4, f"exit {proc.returncode}\n{table}{proc.stdout}{proc.stderr}")
    failing = results.count(False)
    print(f"\nRESULT: {'PASSED' if failing == 0 else 'FAILED'} ({len(results) - failing}/{len(results)} passing)")
    # pytest-style summary line, the one the openspec QA gate reads
    print(f"===== {len(results) - failing} passed, {failing} failed in {time.monotonic() - STARTED:.2f}s =====")
    return 0 if failing == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
