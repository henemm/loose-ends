import json, unicodedata, sys
from collections import Counter

CORPUS = "/Users/hem/Developer/loose-ends/docs/reference/focusblox-corpus.json"
raw = json.load(open(CORPUS))
entries = raw["entries"] if isinstance(raw, dict) and "entries" in raw else raw


def normalized(t):
    t = t.lower()
    return "".join(c for c in unicodedata.normalize("NFD", t) if not unicodedata.combining(c))


def words(t):
    out, cur = [], []
    for ch in t:
        if ch.isalpha() or ch.isnumeric() or ch == "-":
            cur.append(ch)
        else:
            if cur:
                out.append("".join(cur))
                cur = []
    if cur:
        out.append("".join(cur))
    return out


def simwords(t):
    return {w for w in (normalized(x) for x in words(t)) if len(w) >= 4}


for e in entries:
    e["_sw"] = simwords(e["text"])


def jac(a, b):
    u = a | b
    return 0.0 if not u else len(a & b) / len(u)


def ctx_value(e):
    c = e.get("contextsTruth")
    if not c:
        return None
    return frozenset(x.lower() for x in c)


def str_value(key):
    def f(e):
        v = e.get(key)
        if v is None or v == "":
            return None
        return v
    return f


FIELDS = [("Kontexte", ctx_value), ("Dauer", str_value("durationTruth")), ("Energie", str_value("energyTruth"))]


def best_neighbor(target, pool):
    tw = target["_sw"]
    scored = [(o, jac(tw, o["_sw"])) for o in pool if o["id"] != target["id"]]
    scored = [s for s in scored if s[1] > 0]
    if not scored:
        return None, 0.0
    scored.sort(key=lambda s: (-s[1], s[0]["id"]))
    return scored[0]


for name, val in FIELDS:
    pool = [e for e in entries if val(e) is not None]
    total = len(pool)
    cnt = Counter(val(e) for e in pool)
    const_n = cnt.most_common(1)[0][1]
    rows = []
    for e in pool:
        cand, score = best_neighbor(e, pool)
        if cand is None:
            continue
        pred = val(cand)
        if pred is None:
            continue
        rows.append((score, pred == val(e)))
    print("\n=== %s ===  Pool=%d  Konstante=%.1f%%" % (name, total, 100.0 * const_n / total))
    print("Schwelle | Fälle | Treffer | Quote-im-Bucket | Abdeckung-vom-Pool | bindend(vom Pool)")
    for th in [0.0001, 0.2, 0.25, 0.3, 0.34, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.99, 1.0]:
        sel = [r for r in rows if r[0] >= th - 1e-9]
        n = len(sel)
        h = sum(1 for r in sel if r[1])
        if n == 0:
            continue
        print("  >=%5.3f | %5d | %7d | %14.1f%% | %17.1f%% | %14.1f%%"
              % (th, n, h, 100.0 * h / n, 100.0 * n / total, 100.0 * h / total))
    misses = sorted([r[0] for r in rows if not r[1]], reverse=True)
    print("  höchste Jaccard-Werte mit FALSCHER Vorhersage:", ["%.3f" % m for m in misses[:8]])
    hits = sorted([r[0] for r in rows if r[1]])
    print("  niedrigste Jaccard-Werte mit RICHTIGER Vorhersage:", ["%.3f" % m for m in hits[:8]])
    band = [r for r in rows if 0.34 - 1e-9 <= r[0] < 0.99]
    print("  Band 0,34 <= J < 0,99: %d Fälle, %d Treffer" % (len(band), sum(1 for r in band if r[1])))
    ident = [r for r in rows if r[0] >= 0.99]
    print("  Band J >= 0,99 (gleiche Wortmenge): %d Fälle, %d Treffer" % (len(ident), sum(1 for r in ident if r[1])))
