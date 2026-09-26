
import json, unicodedata, collections, math, sys

def normalized(t):
    t = t.lower().replace("ß", "ss")
    d = unicodedata.normalize("NFD", t)
    return unicodedata.normalize("NFC", "".join(c for c in d if not unicodedata.combining(c)))

def words(text):
    out, cur = [], []
    for ch in text:
        if ch.isalpha() or ch.isnumeric() or ch == "-":
            cur.append(ch)
        else:
            if cur: out.append("".join(cur)); cur = []
    if cur: out.append("".join(cur))
    return out

def simwords(text):
    return set(w for w in (normalized(x) for x in words(text)) if len(w) >= 4)

def jaccard(a, b):
    u = a | b
    return 0.0 if not u else len(a & b) / len(u)

def neighbors(target, pool, k, cache):
    tw = cache[target["id"]]
    scored = [(e, jaccard(tw, cache[e["id"]])) for e in pool if e["id"] != target["id"]]
    scored = [s for s in scored if s[1] > 0]
    scored.sort(key=lambda s: (-s[1], s[0]["id"]))
    return [e for e, _ in scored[:k]]

def majority(neis, value):
    order, votes = [], {}
    for n in neis:
        v = value(n)
        if v is None: continue
        if v not in votes: order.append(v)
        votes[v] = votes.get(v, 0) + 1
    best = None
    for v in order:
        if best is None or votes[v] > best[1]: best = (v, votes[v])
    return None if best is None else best[0]

def mcnemar(rule, base):
    b = sum(1 for r, x in zip(rule, base) if r and not x)
    c = sum(1 for r, x in zip(rule, base) if (not r) and x)
    n = b + c
    if n == 0: return b, c, 1.0
    coeff, tail = 1.0, 1.0
    for j in range(min(b, c)):
        coeff *= (n - j) / (j + 1)
        tail += coeff
    return b, c, min(1.0, 2 * tail / 2 ** n)

d = json.load(open("docs/reference/focusblox-corpus.json"))
cache = {e["id"]: simwords(e["text"]) for e in d}

def ctxval(e):
    c = e.get("contextsTruth")
    if not c: return None
    return frozenset(x.lower() for x in c)

feats = [
    ("Kontexte", [e for e in d if ctxval(e) is not None], ctxval),
    ("Dauer", [e for e in d if e.get("durationTruth") is not None], lambda e: e.get("durationTruth")),
    ("Energie", [e for e in d if e.get("energyTruth") is not None], lambda e: e.get("energyTruth")),
]
for name, pool, val in feats:
    baseline = majority(pool, val)
    basecorr = [val(e) == baseline for e in pool]
    baserate = sum(basecorr) / len(pool)
    print(f"== {name} pool={len(pool)} baseline={baseline!r} baserate={baserate*100:.1f}%")
    for k in (1, 3, 5):
        rulec, answered, ac = [], 0, 0
        for e in pool:
            p = majority(neighbors(e, pool, k, cache), val)
            hit = p is not None and p == val(e)
            rulec.append(hit)
            if p is not None:
                answered += 1
                if hit: ac += 1
        b, c, pv = mcnemar(rulec, basecorr)
        corr = sum(rulec)
        print(f"  k={k} rate={corr/len(pool)*100:.1f}% ({corr}/{len(pool)}) answered={answered} ansrate={(ac/answered*100 if answered else 0):.1f}% ({ac}/{answered}) without={len(pool)-answered} margin={(corr/len(pool)-baserate)*100:.1f} b={b} c={c} p={pv:.4f}")
