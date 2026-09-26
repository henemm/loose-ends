# Runde 5: unabhaengige Nachrechnung der Kontext-Nebenspalten aus AC-9 (Spike 69, Issue 131).
# Frage: rechnen "enthaelt erwarteten Kontext" und "Jaccard-Mittel" auf dem korrigierten
# Kontext-Pool (104, contextValue nicht nil), oder schlaegt wieder der 287er-Pool durch?
import json
import unicodedata
import operator

ge = operator.ge
gt = operator.gt


def normalized(t):
    t = t.lower().replace("ß", "ss")
    d = unicodedata.normalize("NFD", t)
    keep = "".join(c for c in d if not unicodedata.combining(c))
    return unicodedata.normalize("NFC", keep)


def words(text):
    out = []
    cur = []
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
    order = []
    votes = {}
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


d = json.load(open("docs/reference/focusblox-corpus.json"))
cache = dict((e["id"], simwords(e["text"])) for e in d)


def ctxval(e):
    c = e.get("contextsTruth")
    if not c:
        return None
    return frozenset(x.lower() for x in c)


pool104 = [e for e in d if ctxval(e) is not None]
pool287 = list(d)
pool_nonnull = [e for e in d if e.get("contextsTruth") is not None]


def side(pool, denom_pool, label):
    print("--- %s: iteriert und Nachbarpool %d, Nenner %d ---"
          % (label, len(pool), len(denom_pool)))
    for k in (1, 3, 5):
        contains = 0
        jsum = 0.0
        for e in pool:
            truth = ctxval(e)
            if truth is None:
                truth = frozenset(x.lower() for x in (e.get("contextsTruth") or []))
            pred = majority(neighbors(e, pool, k, cache), ctxval)
            if pred is None:
                pred = frozenset()
            if pred.intersection(truth):
                contains = contains + 1
            u = pred.union(truth)
            if u:
                jsum = jsum + len(pred.intersection(truth)) / len(u)
        total = max(len(denom_pool), 1)
        print("  k=%d  enthaelt erwarteten Kontext = %.1f %%   Jaccard-Mittel = %.1f %%"
              % (k, contains / total * 100, jsum / total * 100))


print("Korpus %d Aufgaben, Kontext-Pool (contextValue nicht nil) %d, Feld-nicht-null %d"
      % (len(d), len(pool104), len(pool_nonnull)))
side(pool104, pool104, "KORREKT Pool 104")
side(pool287, pool287, "FEHLERVARIANTE A alle 287")
side(pool287, pool104, "FEHLERVARIANTE B 287 iteriert, Nenner 104")
side(pool_nonnull, pool_nonnull, "FEHLERVARIANTE C contextsTruth nicht null")
