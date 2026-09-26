import json, unicodedata, operator
ge = operator.ge
gt = operator.gt
lt = operator.lt

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
            if cur:
                out.append("".join(cur))
                cur = []
    if cur:
        out.append("".join(cur))
    return out

def simwords(text):
    return set(w for w in (normalized(x) for x in words(text)) if ge(len(w), 4))

def jaccard(a, b):
    u = a.union(b)
    if not u:
        return 0.0
    return len(a.intersection(b)) / len(u)

def neighbors(target, pool, k, cache):
    tw = cache[target["id"]]
    scored = [(e, jaccard(tw, cache[e["id"]])) for e in pool if e["id"] != target["id"]]
    scored = [s for s in scored if gt(s[1], 0)]
    scored.sort(key=lambda s: (-s[1], s[0]["id"]))
    return [e for e, _ in scored[:k]]

def majority(neis, value):
    order, votes = [], {}
    for n in neis:
        v = value(n)
        if v is None:
            continue
        if v not in votes:
            order.append(v)
        votes[v] = votes.get(v, 0) + 1
    best = None
    for v in order:
        if best is None or gt(votes[v], best[1]):
            best = (v, votes[v])
    if best is None:
        return None
    return best[0]

def mcnemar(rule, base):
    b = sum(1 for r, x in zip(rule, base) if r and not x)
    c = sum(1 for r, x in zip(rule, base) if (not r) and x)
    n = b + c
    if n == 0:
        return b, c, 1.0
    coeff, tail = 1.0, 1.0
    for j in range(min(b, c)):
        coeff *= (n - j) / (j + 1)
        tail += coeff
    return b, c, min(1.0, 2 * tail / 2 ** n)

d = json.load(open("docs/reference/focusblox-corpus.json"))
cache = dict((e["id"], simwords(e["text"])) for e in d)

def ctxval(e):
    c = e.get("contextsTruth")
    if not c:
        return None
    return frozenset(x.lower() for x in c)

def dedup_exact_text(pool):
    seen, out = set(), []
    for e in pool:
        key = e["text"].strip().lower()
        if key not in seen:
            seen.add(key)
            out.append(e)
    return out

def dedup_wordset(pool):
    seen, out = set(), []
    for e in pool:
        key = frozenset(cache[e["id"]])
        if key not in seen:
            seen.add(key)
            out.append(e)
    return out

def identical_share(pool):
    hits = 0
    for e in pool:
        ns = neighbors(e, pool, 1, cache)
        if ns and jaccard(cache[e["id"]], cache[ns[0]["id"]]) == 1.0:
            hits += 1
    return hits / max(len(pool), 1), hits

def row(name, pool, ks, val):
    baseline = majority(pool, val)
    basecorr = [val(e) == baseline for e in pool]
    baserate = 0
    if pool:
        baserate = sum(basecorr) / len(pool)
    for k in ks:
        rulec, answered, ac = [], 0, 0
        for e in pool:
            p = majority(neighbors(e, pool, k, cache), val)
            hit = p is not None and p == val(e)
            rulec.append(hit)
            if p is not None:
                answered += 1
                if hit:
                    ac += 1
        b, c, pv = mcnemar(rulec, basecorr)
        corr = sum(rulec)
        rate = corr / len(pool)
        ansrate = 0
        if answered:
            ansrate = ac / answered
        met = ge(rate - baserate, 0.10) and lt(pv, 0.05)
        urteil = "nicht erfuellt"
        if met:
            urteil = "erfuellt"
        print("  %s k=%d: n=%d rate=%.1f%% ansrate=%.1f%% without=%d base=%.1f%% margin=%.1f b=%d c=%d p=%.4f urteil=%s"
              % (name, k, len(pool), rate * 100, ansrate * 100, len(pool) - answered,
                 baserate * 100, (rate - baserate) * 100, b, c, pv, urteil))

feats = [
    ("Kontexte", [e for e in d if ctxval(e) is not None], ctxval),
    ("Dauer", [e for e in d if e.get("durationTruth") is not None], lambda e: e.get("durationTruth")),
    ("Energie", [e for e in d if e.get("energyTruth") is not None], lambda e: e.get("energyTruth")),
]

print("=== Pool-Groessen, Dedup-Groessen, Jaccard-1.0-Anteil ===")
for name, pool, val in feats:
    dt = dedup_exact_text(pool)
    dw = dedup_wordset(pool)
    share, hits = identical_share(pool)
    ids_equal = [x["id"] for x in dt] == [x["id"] for x in dw]
    print("%s: pool=%d dedupExactText=%d dedupWordSet=%d gleicheVertreter=%s jaccard1.0=%.1f%% (%d/%d)"
          % (name, len(pool), len(dt), len(dw), ids_equal, share * 100, hits, len(pool)))

print("=== Gegenprobe-Zeilen (Dedup nach exaktem Text, k=1) ===")
for name, pool, val in feats:
    row(name, dedup_exact_text(pool), [1], val)

print("=== Gegenprobe k=3,5 zur Kontrolle ===")
for name, pool, val in feats:
    row(name, dedup_exact_text(pool), [3, 5], val)

print("=== Determinismus der Vertreterwahl: erste 5 ids je Merkmal ===")
for name, pool, val in feats:
    print("%s: %s" % (name, [x["id"] for x in dedup_exact_text(pool)][:5]))
