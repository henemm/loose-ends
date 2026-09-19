#!/usr/bin/env python3
"""Kurzfassung einer vom iPhone geholten Messdatei: wie weit ist die Messreihe?

Aufgerufen von `sim.sh lab-fetch`, damit nach dem Abholen sofort sichtbar ist, ob sich ein
Bericht schon lohnt oder ob die Labor-App noch Sätze vor sich hat.
"""
import collections
import json
import sys


def main(path: str) -> int:
    with open(path) as handle:
        run = json.load(handle)
    results = run.get("results", [])
    done = {r["entryID"] for r in results if not r.get("error")}
    failed = [r for r in results if r.get("error")]
    throttled = [r for r in failed if "rate limit" in r["error"].lower()]
    conditions = collections.Counter(
        f'{r["conditions"]["appState"]}/{r["conditions"]["power"]}'
        for r in results if "conditions" in r
    )
    seconds = [r["seconds"] for r in results if not r.get("error")]
    print(f'[sim] {len(done)} Sätze gemessen, {len(failed)} Fehlversuche (gedrosselt: {len(throttled)})')
    if seconds:
        print(f'[sim] {sum(seconds) / len(seconds):.1f} s je Satz')
    if conditions:
        print('[sim] Bedingungen: ' + ', '.join(f'{k} {v}x' for k, v in conditions.most_common()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
