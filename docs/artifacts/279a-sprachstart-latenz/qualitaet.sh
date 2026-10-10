#!/bin/bash
# Erkennungsgüte (#279 A): jeder Satz aus saetze.txt per `say` als Datei (ohne Wiedergabe), dann App-Modul gegen
# DictationTranscriber, Wortfehlerrate gegen den Solltext. Erst run.sh laufen lassen (baut das Messprogramm).
cd "$(dirname "$0")"
bin="${TMPDIR:-/tmp}/zerlegung-279a"
mkdir -p "${TMPDIR:-/tmp}/saetze-279a"
i=0
while IFS= read -r line; do
  i=$((i+1))
  f="${TMPDIR:-/tmp}/saetze-279a/$i.aiff"
  say -v Anna -o "$f" "$line"
  for v in ${VARIANTS:-app dict}; do
    hyp=$(LOG=1 "$bin" "$f" "$v" 1 | grep "Text:" | sed 's/^ *Text: //')
    first=$(LOG=1 "$bin" "$f" "$v" 1 | grep -o "erstes Wort [0-9.]*" | head -1)
    printf '%s\t%s\t%s\t%s\t%s\n' "$i" "$v" "$line" "$hyp" "$first"
  done
done < saetze.txt | python3 -c '
import sys, re
def norm(s): return re.sub(r"[^\wäöüß ]", " ", s.lower()).split()
def wer(r, h):
    d = [[0]*(len(h)+1) for _ in range(len(r)+1)]
    for i in range(len(r)+1): d[i][0] = i
    for j in range(len(h)+1): d[0][j] = j
    for i in range(1, len(r)+1):
        for j in range(1, len(h)+1):
            d[i][j] = min(d[i-1][j]+1, d[i][j-1]+1, d[i-1][j-1]+(r[i-1] != h[j-1]))
    return d[len(r)][len(h)]
tot = {}
for row in sys.stdin:
    i, v, ref, hyp, first = row.rstrip("\n").split("\t")
    e = wer(norm(ref), norm(hyp)); n = len(norm(ref))
    a = tot.setdefault(v, [0, 0]); a[0] += e; a[1] += n
    print(f"{i:>2} {v:5} Fehler {e}/{n}  {first:18}  {hyp}")
for v, (e, n) in tot.items(): print(f"{v}: Wortfehlerrate {100*e/n:.1f} % ({e}/{n})")
'
