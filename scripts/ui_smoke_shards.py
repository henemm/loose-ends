#!/usr/bin/env python3
"""Splits the classes of LooseEndsUITests into N parts for the CI matrix `ui-smoke-shard` (#910, #939).

Usage: python3 scripts/ui_smoke_shards.py [N]   (default 4)
Prints {"include": [{"shard": 1, "classes": "A B", "only": "-only-testing:LooseEndsUITests/A …"}, …]} on stdout.

The classes are read from the code (`LooseEndsUITests/*.swift`, not the subfolder `Watch/`, which belongs to the watch
target), so a new class can never fall out of the run. Weight of a class = number of its `func test…`; the two photo
classes take a fixed 4 (one test each, but 155-183 s), Mac-only classes 0 (they only skip on iOS). Greedy: heaviest
first into the lightest part, ties by name, so the split is the same on every run. A class heavier than the target
size (total weight / N, rounded up), not a photo class, is split into units `Class/test` of weight 1 (#939).
A class counts when it derives from XCTestCase directly or through a class of its own (attributes like `@MainActor`
in front allowed); a base class without tests weighs 0. `only` names the classes of weight > 0 only (a Mac-only class
does not exist in the iOS build); a part whose `only` would be empty is an error, since an empty `$ONLY` runs the whole
target.
"""
import json
import re
import sys
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent.parent / "LooseEndsUITests"
TARGET = "LooseEndsUITests"
FIXED = {"DesignGalleryTests": 4, "StoreScreenshotsTests": 4}
CLASS = re.compile(r"^[ \t]*(?:@\w+(?:\([^)\n]*\))?\s+)*(?:(?:final|public|internal|open)\s+)*"
                   r"class\s+(?!(?:var|func|let)\b)(\w+)\s*:\s*(\w+)", re.MULTILINE)
TEST = re.compile(r"^\s*(?:@\w+\s+)*func\s+(test\w*)\s*\(", re.MULTILINE)


def _mac_only(text):
    code = [line.strip() for line in text.splitlines() if line.strip() and not line.strip().startswith("//")]
    return bool(code) and code[0].startswith("#if os(macOS)")


def _scan(tests_dir):
    """Class name → (weight, names of its `func test…`), for every XCTestCase class in tests_dir/*.swift."""
    found = {}  # class name → (base, weight, methods)
    for path in sorted(Path(tests_dir).glob("*.swift")):
        text = path.read_text(encoding="utf-8")
        starts = list(CLASS.finditer(text))
        for i, match in enumerate(starts):
            name, base = match.group(1), match.group(2)
            end = starts[i + 1].start() if i + 1 < len(starts) else len(text)
            names = TEST.findall(text, match.end(), end)
            found[name] = (base, 0 if _mac_only(text) else FIXED.get(name, len(names)), names)
    tests = {"XCTestCase"}
    while True:
        more = {name for name, (base, _, _) in found.items() if base in tests} - tests
        if not more:
            break
        tests |= more
    return {name: (weight, names) for name, (base, weight, names) in found.items() if name in tests}


def weights(tests_dir=TESTS_DIR):
    """Class name → weight, for every XCTestCase class in tests_dir/*.swift."""
    return {name: weight for name, (weight, _) in _scan(tests_dir).items()}


def methods(tests_dir=TESTS_DIR):
    """Class name → its `func test…` names, sorted (the same pattern that counts the weight)."""
    return {name: sorted(names) for name, (_, names) in _scan(tests_dir).items()}


def units(tests_dir=TESTS_DIR, n=4):
    """Unit → weight. A class over the target size (total weight / n, rounded up), not in FIXED and of weight > 0,
    becomes one unit `Class/test` of weight 1 per method (#939); every other class stays one unit."""
    scanned = _scan(tests_dir)
    target = -(-sum(weight for weight, _ in scanned.values()) // n)
    result = {}
    for name, (weight, names) in scanned.items():
        if weight > target and name not in FIXED:
            result.update({f"{name}/{test}": 1 for test in sorted(names)})
        else:
            result[name] = weight
    return result


def split(tests_dir=TESTS_DIR, n=4):
    """n lists of units, each sorted; every unit in exactly one list."""
    loads = [0] * n
    parts = [[] for _ in range(n)]
    for name, weight in sorted(units(tests_dir, n).items(), key=lambda item: (-item[1], item[0])):
        # The photo classes never share a part while there is one without a photo class (weight alone does not
        # guarantee it: with the classes of 2026-11-12 both landed in the same part).
        free = [i for i in range(n) if not (name in FIXED and FIXED.keys() & set(parts[i]))] or range(n)
        lightest = min(free, key=lambda i: (loads[i], len(parts[i]), i))
        parts[lightest].append(name)
        loads[lightest] += weight
    return [sorted(part) for part in parts]


def matrix(tests_dir=TESTS_DIR, n=4):
    weight = weights(tests_dir)
    include = []
    for i, part in enumerate(split(tests_dir, n)):
        classes = list(dict.fromkeys(unit.split("/")[0] for unit in part))
        include.append({"shard": i + 1, "classes": " ".join(classes),
                        "only": " ".join(f"-only-testing:{TARGET}/{unit}" for unit in part
                                         if weight[unit.split("/")[0]] > 0)})
    for entry in include:
        if not entry["only"]:
            sys.exit(f"part {entry['shard']} has no class with tests to run ({entry['classes'] or 'empty'})")
    return {"include": include}


if __name__ == "__main__":
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    if count < 1:
        sys.exit("N must be at least 1")
    print(json.dumps(matrix(TESTS_DIR, count)))
