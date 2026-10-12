#!/bin/bash
# Misst den Nachlauf eines sim.sh-Testlaufs (#298): Zeit der Ergebniszeile im Log, Zeit des
# Prozessendes, und ob/wann ein `simctl diagnose` lief. Aufruf: measure.sh <label> <sim.sh-Argumente…>
# Läuft nur im Simulator (LOOSEENDS_SIM), nie mit dem Mac als Testhost.
set -u
label="$1"; shift
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
out="$here/nachlauf-$label.txt"
export CLAUDE_SESSION_ID="${CLAUDE_SESSION_ID:-fix298}"
export LOOSEENDS_SIM="${LOOSEENDS_SIM:-iPhone 17e}"
log="$HOME/Library/Developer/Xcode/DerivedData/LooseEnds-session-$CLAUDE_SESSION_ID/xcodebuild.log"
rm -f "$log"

ts() { date +%s; }
start=$(ts)
"$root/scripts/sim.sh" "$@" > "$here/sim-$label.log" 2>&1 &
pid=$!
result_at=""; diag_at=""; diag_seen=""
while kill -0 "$pid" 2>/dev/null; do
    if [ -z "$result_at" ] && [ -f "$log" ] && grep -qE '\*\* TEST (SUCCEEDED|FAILED) \*\*|Test run with [0-9]+ tests? in [0-9]+ suites? (passed|failed)|Test Suite .Selected tests. (passed|failed)' "$log"; then
        result_at=$(ts)
    fi
    if [ -z "$diag_at" ] && pgrep -f "simctl diagnose.*LooseEnds-session-$CLAUDE_SESSION_ID" >/dev/null; then
        diag_at=$(ts); diag_seen="$(pgrep -fl "simctl diagnose.*LooseEnds-session-$CLAUDE_SESSION_ID" | head -1)"
    fi
    sleep 2
done
wait "$pid"; rc=$?
end=$(ts)
{
    echo "# Nachlauf-Messung ($label), #298"
    echo "befehl: scripts/sim.sh $*"
    echo "simulator: $LOOSEENDS_SIM  session: $CLAUDE_SESSION_ID"
    echo "head: $(git -C "$root" rev-parse HEAD)"
    echo "diagnose-option in sim.sh: $(grep -c 'collect-test-diagnostics never' "$root/scripts/sim.sh")"
    echo "start: $(date -r "$start" '+%H:%M:%S')"
    echo "ergebniszeile: ${result_at:+$(date -r "$result_at" '+%H:%M:%S')}"
    echo "simctl diagnose gesehen: ${diag_at:+$(date -r "$diag_at" '+%H:%M:%S')} ${diag_seen}"
    echo "prozessende: $(date -r "$end" '+%H:%M:%S')  rc=$rc"
    [ -n "$result_at" ] && echo "nachlauf_s: $((end - result_at))"
    echo "ergebnis im log:"; grep -E '\*\* TEST|Test run with|Executed [0-9]+ test' "$log" | tail -4
} > "$out"
cat "$out"
