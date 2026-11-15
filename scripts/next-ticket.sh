#!/bin/bash
#
# next-ticket.sh — schlägt das nächste freie Teil-Ticket des Epics dieser Sitzung vor (#715 Schnitt 1)
#
# Usage:
#   ./scripts/next-ticket.sh
#
# Erste Ausgabezeile ist maschinenlesbar: NEXT=#N | NEXT=none | NEXT=unknown. Danach Klartext.
# Zuständigkeit = führende #N im herdr-Namen der Sitzung: #N mit seinen Teil-Tickets, ohne Teil-Tickets #N allein (Henning
# 2026-11-15). Was eine andere Sitzung vorne im Namen trägt, fällt heraus (die genauere Nummer gewinnt); beginnen zwei
# Sitzungen mit derselben #N, gibt es keinen Vorschlag.
# Abzug: Board In progress/In review, offener PR, lebende fremde Sitzung (Lock), offenes „blocked by“.
# Reihenfolge: Priority, dann Hennings Board-Reihenfolge. Überschneidungen mit Hotspots werden gemeldet.
# Liest nur: schreibt nichts nach GitHub, ändert keine Datei. Endet immer mit Exit 0.
#
# Umgebung: HERDR_WORKSPACE_ID (Sitzung), CLAUDE_SESSION_ID (eigene Sitzung),
#           LOOSEENDS_REPO (Vorgabe henemm/loose-ends), LOOSEENDS_LOCKS_DIR (Vorgabe <Hauptcheckout>/.claude/session-locks)

set -u

# Dateien, an denen sich parallele Zweige erfahrungsgemäß stoßen (Glob-Muster, Leerzeichen getrennt).
HOTSPOTS='project.yml cloudkit/schema.ckdb *.xcstrings CLAUDE.md LooseEnds/Views/StartPage* LooseEnds/Views/ContentView*'

REPO="${LOOSEENDS_REPO:-henemm/loose-ends}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

unknown() {
    local reason="$1"
    [ -n "${WORK:-}" ] && [ -e "$WORK/gh.timeout" ] && reason="gh antwortet nicht ($1)"
    echo "NEXT=unknown"
    echo "Kein Vorschlag möglich: $reason"
    exit 0
}

no_epic() {
    echo "NEXT=none"
    echo "kein Epic: $1"
    exit 0
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/next-ticket.XXXXXX" 2>/dev/null)" || unknown "kein Temp-Ordner"
trap 'rm -rf "$WORK"' EXIT

gh_run() {  # gh mit Zeitgrenze LOOSEENDS_GH_TIMEOUT (Sekunden, Vorgabe 20); Zeitüberschreitung = Exit 124
    python3 -c '
import subprocess, sys
try:
    sys.exit(subprocess.run(["gh"] + sys.argv[2:], stdin=subprocess.DEVNULL, timeout=float(sys.argv[1])).returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
' "${LOOSEENDS_GH_TIMEOUT:-20}" "$@"
    local rc=$?
    [ "$rc" -eq 124 ] && : > "$WORK/gh.timeout"
    return "$rc"
}

json_get() {  # json_get <datei> <python-ausdruck über d>
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>/dev/null
}

locks_dir() {
    if [ -n "${LOOSEENDS_LOCKS_DIR:-}" ]; then echo "$LOOSEENDS_LOCKS_DIR"; return; fi
    local common
    common="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
    [ -n "$common" ] && echo "$(dirname "$common")/.claude/session-locks"
}

epic_of() {
    command -v herdr >/dev/null 2>&1 || unknown "herdr fehlt"
    command -v gh >/dev/null 2>&1 || unknown "gh fehlt"
    command -v python3 >/dev/null 2>&1 || unknown "python3 fehlt"
    [ -n "${HERDR_WORKSPACE_ID:-}" ] || no_epic "HERDR_WORKSPACE_ID ist nicht gesetzt, die Sitzung hat keinen Namen."
    herdr workspace get "$HERDR_WORKSPACE_ID" > "$WORK/ws.json" 2>/dev/null || unknown "herdr workspace get scheitert"
    local label n state
    label="$(json_get "$WORK/ws.json" '(d.get("result") or d)["workspace"]["label"]')" || unknown "herdr-Antwort ohne Namen"
    [[ "$label" =~ ^#([0-9]+) ]] || no_epic "Der Sitzungsname „${label}“ beginnt nicht mit #N."
    n="${BASH_REMATCH[1]}"
    other_sessions "$n"
    EPIC="$n"
    gh_run api "repos/$REPO/issues/$n/sub_issues?per_page=100" > "$WORK/sub.json" 2>/dev/null \
        || unknown "Teil-Tickets von #$n nicht abrufbar"
    if [ "$(json_get "$WORK/sub.json" 'sum(str(i.get("state", "open")).lower() == "open" for i in d)')" != "0" ]; then
        LABEL_NOTE="Sitzung „${label}“: #$n mit seinen Teil-Tickets."
        return
    fi
    gh_run api "repos/$REPO/issues/$n" > "$WORK/issue.json" 2>/dev/null || no_epic "#$n ist nicht abrufbar."
    state="$(json_get "$WORK/issue.json" 'str(d.get("state", "")).lower()')" || unknown "#$n nicht lesbar"
    [ "$state" = "open" ] || no_epic "#$n ist geschlossen und hat keine offenen Teil-Tickets."
    SINGLE="$(json_get "$WORK/issue.json" 'd.get("title", "")')" || unknown "#$n nicht lesbar"
    LABEL_NOTE="Sitzung „${label}“: nur #$n (keine Teil-Tickets)."
}

other_sessions() {  # other_sessions <n>: OTHERS = führende #M der anderen Sitzungen; dieselbe #N wie hier = kein Vorschlag
    herdr workspace list > "$WORK/wsl.json" 2>/dev/null || unknown "herdr workspace list scheitert"
    OTHERS="$(python3 - "$WORK/wsl.json" "$HERDR_WORKSPACE_ID" <<'PY2'
import json, re, sys
d = json.load(open(sys.argv[1]))
for w in (d.get("result") or d).get("workspaces", []):
    if w.get("workspace_id") == sys.argv[2]:
        continue
    m = re.match(r"#(\d+)", w.get("label") or "")
    if m:
        print(m.group(1))
PY2
)" || unknown "herdr-Liste nicht lesbar"
    if grep -qx "$1" <<< "$OTHERS"; then
        unknown "Zwei Sitzungen beginnen mit #$1. Eine muss umbenannt werden, bevor es einen Vorschlag gibt."
    fi
}

tree_leaves() {  # schreibt <nummer>\t<titel> je offenem Ticket ohne offene Teil-Tickets im Baum unter $EPIC
    local queue="$EPIC" n seen=" " kids
    : > "$WORK/cand.tsv"
    : > "$WORK/up.tsv"
    if [ -n "$SINGLE" ]; then
        printf '%s\t%s\n' "$EPIC" "$SINGLE" > "$WORK/cand.tsv"
        return
    fi
    while [ -n "$queue" ]; do
        n="${queue%% *}"; queue="${queue#"$n"}"; queue="${queue# }"
        case "$seen" in *" $n "*) continue ;; esac
        seen="$seen$n "
        gh_run api "repos/$REPO/issues/$n/sub_issues?per_page=100" > "$WORK/sub.json" 2>/dev/null \
            || unknown "Teil-Tickets von #$n nicht abrufbar"
        kids="$(python3 - "$WORK/sub.json" <<'PY'
import json, sys
print(" ".join(str(i["number"]) for i in json.load(open(sys.argv[1]))
               if str(i.get("state", "open")).lower() == "open"))
PY
)" || unknown "Teil-Tickets von #$n nicht lesbar"
        if [ -z "$kids" ]; then
            [ "$n" != "$EPIC" ] && printf '%s\t%s\n' "$n" "$(awk -F'\t' -v n="$n" '$1 == n { print $2; exit }' "$WORK/titles.tsv")" >> "$WORK/cand.tsv"
        else
            python3 -c 'import json,sys; [print("%s\t%s" % (i["number"], i.get("title", ""))) for i in json.load(open(sys.argv[1]))]' \
                "$WORK/sub.json" >> "$WORK/titles.tsv" || unknown "Titel unter #$n nicht lesbar"
            for k in $kids; do printf '%s\t%s\n' "$k" "$n" >> "$WORK/up.tsv"; done
            queue="$queue $kids"; queue="${queue# }"
        fi
    done
}

drop_others() {  # nimmt heraus, was selbst oder über ein Eltern-Ticket einer anderen Sitzung gehört
    python3 - "$WORK/cand.tsv" "$WORK/up.tsv" "$OTHERS" "$EPIC" > "$WORK/cand.own" 2> "$WORK/others.txt" <<'PY2' \
        || unknown "Zuständigkeit nicht auswertbar"
import sys
up = dict(l.rstrip("\n").split("\t")[:2] for l in open(sys.argv[2]) if "\t" in l)
others, root, dropped = set(sys.argv[3].split()), sys.argv[4], set()
for line in open(sys.argv[1]):
    n = line.split("\t")[0]
    while n and n != root and n not in others:
        n = up.get(n)
    if n in others:
        dropped.add(n)
    else:
        sys.stdout.write(line)
if dropped:
    sys.stderr.write(" ".join("#" + n for n in sorted(dropped, key=int)))
PY2
    mv "$WORK/cand.own" "$WORK/cand.tsv"
    [ -s "$WORK/others.txt" ] && LABEL_NOTE="$LABEL_NOTE Gehört anderen Sitzungen: $(cat "$WORK/others.txt")."
    return 0
}

candidates() {
    : > "$WORK/titles.tsv"
    tree_leaves
    [ -n "$OTHERS" ] && drop_others
    gh_run project item-list 1 --owner henemm --format json --limit 1000 > "$WORK/board.json" 2>/dev/null \
        || unknown "Board nicht abrufbar"
    gh_run pr list --repo "$REPO" --state open --limit 200 --json number,title,body,headRefName \
        > "$WORK/prs.json" 2>/dev/null || unknown "offene PRs nicht abrufbar"
    mkdir -p "$WORK/blocked"
    local n
    while IFS=$'\t' read -r n _; do
        [ -n "$n" ] || continue
        gh_run api "repos/$REPO/issues/$n/dependencies/blocked_by?per_page=100" > "$WORK/blocked/$n.json" 2>/dev/null \
            || unknown "„blocked by“ von #$n nicht abrufbar"
    done < "$WORK/cand.tsv"
}

live_locks() {  # schreibt <issue>\t<branch>\t<session> je lebender fremder Sitzung mit Phase < phase8_complete
    local dir
    dir="$(locks_dir)"
    : > "$WORK/live.tsv"
    [ -n "$dir" ] && [ -d "$dir" ] || return 0
    python3 - "$dir" "${CLAUDE_SESSION_ID:-}" > "$WORK/live.tsv" <<'PY' || true
import json, os, re, sys
from pathlib import Path
for f in sorted(Path(sys.argv[1]).glob("*.json")):
    try:
        lk = json.loads(f.read_text())
        if not isinstance(lk, dict):
            continue
        pid = int(lk.get("pid") or 0)
    except Exception:
        continue
    if not pid or lk.get("session_id") == sys.argv[2]:
        continue
    m = re.match(r"phase(\d+)", str(lk.get("phase", "")))
    if not m or int(m.group(1)) >= 8:
        continue
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        continue
    except PermissionError:
        pass
    print(f'{str(lk.get("issue", "")).lstrip("#")}\t{lk.get("branch", "")}\t{lk.get("session_id", "")}')
PY
}

busy_issues() {  # schreibt <nummer>\t<grund> je abgezogenem Kandidaten
    python3 - "$WORK" > "$WORK/skip.tsv" <<'PY' || unknown "Belegung nicht auswertbar"
import json, re, sys
from pathlib import Path
w = Path(sys.argv[1])
cands = [l.split("\t")[0] for l in (w / "cand.tsv").read_text().splitlines() if l]
board = {str(i.get("content", {}).get("number")): i for i in json.load(open(w / "board.json")).get("items", [])}
refs = {}
for p in json.load(open(w / "prs.json")):
    nums = re.findall(r"#(\d+)", p.get("title") or "")
    for lst in re.findall(r"(?i)\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?|refs?)\b:?\s*(#\d+(?:\s*(?:,|and|und|&)\s*#\d+)*)",
                          p.get("body") or ""):
        nums += re.findall(r"#(\d+)", lst)
    nums += re.findall(r"^[A-Za-z]+/([0-9]{2,})(?:-|$)", p.get("headRefName") or "")
    for n in nums:
        refs.setdefault(n, p["number"])
live = {l.split("\t")[0]: l.split("\t")[2] for l in (w / "live.tsv").read_text().splitlines() if l}
for n in cands:
    status = str(board.get(n, {}).get("status", ""))
    if status.lower() in ("in progress", "in review"):
        print(f"{n}\tBoard-Status {status}"); continue
    if n in refs:
        print(f"{n}\toffener PR #{refs[n]}"); continue
    if n in live:
        print(f"{n}\tvon der lebenden Sitzung {live[n]} belegt"); continue
    blockers = [f'#{b["number"]}' for b in json.load(open(w / "blocked" / f"{n}.json"))
                if str(b.get("state", "open")).lower() == "open"]
    if blockers:
        print(f"{n}\tblockiert durch {', '.join(blockers)}")
PY
}

rank() {  # schreibt die freien Kandidaten sortiert: <nummer>\t<priority>\t<titel>
    python3 - "$WORK" > "$WORK/free.tsv" <<'PY' || unknown "Reihenfolge nicht bestimmbar"
import json, sys
from pathlib import Path
w = Path(sys.argv[1])
skip = {l.split("\t")[0] for l in (w / "skip.tsv").read_text().splitlines() if l}
items = json.load(open(w / "board.json")).get("items", [])
pos = {str(i.get("content", {}).get("number")): k for k, i in enumerate(items)}
prio = {str(i.get("content", {}).get("number")): str(i.get("priority") or "") for i in items}
rows = [l.split("\t", 1) for l in (w / "cand.tsv").read_text().splitlines() if l]
free = [(n, t) for n, t in rows if n not in skip]
order = {"P0": 0, "P1": 1, "P2": 2}
free.sort(key=lambda r: (order.get(prio.get(r[0], ""), 9), pos.get(r[0], 10**6)))
for n, t in free:
    print(f'{n}\t{prio.get(n) or "ohne Priority"}\t{t}')
PY
}

is_hotspot() {
    local f="$1" pattern hit=1
    set -f  # Muster nur gegen den Dateinamen prüfen, nie gegen das Arbeitsverzeichnis expandieren
    for pattern in $HOTSPOTS; do
        # shellcheck disable=SC2254
        case "$f" in $pattern) hit=0; break ;; esac
    done
    set +f
    return "$hit"
}

overlaps() {  # schreibt Klartextzeilen je Hotspot-Treffer offener PRs und lebender Zweige
    : > "$WORK/overlap.txt"
    local pr branch f
    for pr in $(json_get "$WORK/prs.json" '" ".join(str(p["number"]) for p in d)'); do
        gh_run pr diff "$pr" --repo "$REPO" --name-only > "$WORK/diff.txt" 2>/dev/null \
            || unknown "Dateien von PR #$pr nicht abrufbar"
        while IFS= read -r f; do
            is_hotspot "$f" && echo "  - $f wird in PR #$pr geändert" >> "$WORK/overlap.txt"
        done < "$WORK/diff.txt"
    done
    while IFS=$'\t' read -r _ branch _; do
        [ -n "$branch" ] || continue
        git -C "$ROOT" diff --name-only "main...$branch" > "$WORK/diff.txt" 2>/dev/null || continue
        while IFS= read -r f; do
            is_hotspot "$f" && echo "  - $f wird im Zweig $branch einer lebenden Sitzung geändert" >> "$WORK/overlap.txt"
        done < "$WORK/diff.txt"
    done < "$WORK/live.tsv"
    return 0
}

print_skips() {
    [ -s "$WORK/skip.tsv" ] || return 0
    echo "Entfallen:"
    local n reason
    while IFS=$'\t' read -r n reason; do
        echo "  - #$n: $reason"
    done < "$WORK/skip.tsv"
}

notify_blocked() {
    command -v herdr >/dev/null 2>&1 || return 0
    herdr notification show "Kein freies Ticket unter #$EPIC" \
        --body "Alle offenen Teil-Tickets sind belegt oder blockiert." >/dev/null 2>&1 || true
}

render() {
    local n prio title
    if [ ! -s "$WORK/free.tsv" ]; then
        echo "NEXT=none"
        echo "$LABEL_NOTE"
        if [ -s "$WORK/cand.tsv" ]; then
            echo "Kein Ticket unter #$EPIC ist für diese Sitzung frei."
            print_skips
            notify_blocked
        else
            echo "Unter #$EPIC ist für diese Sitzung nichts mehr offen."
        fi
        return
    fi
    IFS=$'\t' read -r n prio title < "$WORK/free.tsv"
    echo "NEXT=#$n"
    echo "#$n $title ($prio)"
    echo "$LABEL_NOTE"
    echo "Warum: oberstes freies Teil-Ticket, sortiert nach Priority, dann nach Hennings Board-Reihenfolge."
    print_skips
    if [ -s "$WORK/overlap.txt" ]; then
        echo "Achtung, Überschneidung mit offenen Zweigen (nur Hinweis):"
        cat "$WORK/overlap.txt"
    fi
}

EPIC=""
LABEL_NOTE=""
SINGLE=""
OTHERS=""
epic_of
candidates
live_locks
busy_issues
rank
overlaps
render
exit 0
