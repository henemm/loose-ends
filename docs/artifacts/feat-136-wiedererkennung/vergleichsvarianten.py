import json, unicodedata
from collections import Counter, defaultdict

CORPUS = "/Users/hem/Developer/loose-ends/docs/reference/focusblox-corpus.json"
entries = json.load(open(CORPUS))


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


VARIANTS = [
    ("A Wortmenge >=4 Zeichen (wie gemessen)", lambda t: frozenset(w for w in map(normalized, words(t)) if len(w) >= 4)),
    ("B Wortmenge, ALLE Woerter", lambda t: frozenset(map(normalized, words(t)))),
    ("C ganzer normalisierter Text", lambda t: normalized(t).strip()),
]


def ctx_value(e):
    c = e.get("contextsTruth")
    return None if not c else frozenset(x.lower() for x in c)


FIELDS = [("Kontexte", ctx_value), ("Dauer", lambda e: e.get("durationTruth") or None)]

# Wo unterscheiden sich A und B konkret?
ka = {e["id"]: VARIANTS[0][1](e["rawText"]) for e in entries}
kb = {e["id"]: VARIANTS[1][1](e["rawText"]) for e in entries}
ga, gb = defaultdict(list), defaultdict(list)
for e in entries:
    ga[ka[e["id"]]].append(e["rawText"])
    gb[kb[e["id"]]].append(e["rawText"])
print("A: %d Schluessel, B: %d Schluessel, C: %d Schluessel"
      % (len(ga), len(gb), len({VARIANTS[2][1](e["rawText"]) for e in entries})))
print("\nGruppen, die A zusammenwirft, B aber trennt:")
found = 0
for k, texts in ga.items():
    distinct = sorted(set(texts))
    subkeys = {kb[e["id"]] for e in entries if ka[e["id"]] == k}
    if len(subkeys) > 1:
        found += 1
        print("   ", distinct)
if not found:
    print("    keine")

for vname, keyfn in VARIANTS:
    for e in entries:
        e["_k"] = keyfn(e["rawText"])
    print("\n####", vname)
    for fname, val in FIELDS:
        pool = [e for e in entries if val(e) is not None]
        total = len(pool)
        by_key = defaultdict(list)
        for e in pool:
            by_key[e["_k"]].append(e)
        answered = hits = 0
        for e in pool:
            others = sorted([o for o in by_key[e["_k"]] if o["id"] != e["id"]], key=lambda o: o["id"])
            if not others:
                continue
            pred = val(others[0])
            if pred is None:
                continue
            answered += 1
            if pred == val(e):
                hits += 1
        acc = ("%.1f%%" % (100.0 * hits / answered)) if answered else "-"
        print("   %-9s Pool=%3d  Abdeckung=%3d (%.1f%%)  richtig=%3d  Quote=%s"
              % (fname, total, answered, 100.0 * answered / total, hits, acc))
