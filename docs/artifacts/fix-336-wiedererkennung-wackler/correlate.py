"""Ordnet jede Watchdog-Blockade >= 3 s des roten CI-Laufs der XCTest-Aktivität zu, die kurz davor begann."""
import json, re, subprocess, datetime, sys

D = sys.argv[1]
ids = open(f"{D}/ids.txt").read().split()
acts = []  # (start, title, test)
for tid in ids:
    out = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "activities",
                          "--test-id", tid, "--path", f"{D}/UITestResults.xcresult", "--compact"],
                         capture_output=True, text=True).stdout
    try:
        d = json.loads(out)
    except Exception:
        continue
    def walk(a):
        for x in a:
            if isinstance(x.get("startTime"), (int, float)):
                acts.append((x["startTime"], x.get("title", ""), tid.split("/")[-1]))
            walk(x.get("childActivities", []))
    for r in d.get("testRuns", []):
        walk(r.get("activities", []))
acts.sort()

blocks = []
lines = open(f"{D}/watchdog.log").read().splitlines()
for i, l in enumerate(lines):
    m = re.match(r"(\S+ \S+) .*blocked for ([\d.]+) s", l)
    if m and float(m.group(2)) >= 3:
        end = datetime.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S.%f").replace(tzinfo=datetime.timezone.utc)
        dur = float(m.group(2))
        blocks.append((end.timestamp() - dur, dur))

for start, dur in blocks:
    before = [a for a in acts if a[0] <= start + 0.3][-3:]
    ts = datetime.datetime.fromtimestamp(start, datetime.timezone.utc).strftime("%H:%M:%S.%f")[:-3]
    print(f"\n{ts} Blockade {dur:.1f} s")
    for a in before:
        print(f"   {start - a[0]:+6.2f}s vorher  [{a[2][:40]}] {a[1][:90]}")
