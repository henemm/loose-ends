#!/bin/bash
#
# next-ticket-hook.sh — legt nach /clear und beim Sitzungsstart den Vorschlag von next-ticket.sh in den Kontext (#715 Schnitt 2)
#
# Läuft als SessionStart-Hook (Eintrag in ~/.claude/settings.json, Matcher ^(startup|clear)$, timeout 30).
# Liest die stdin-JSON (session_id, cwd, source) und ruft scripts/next-ticket.sh mit CLAUDE_SESSION_ID=<session_id>,
# damit die eigene Sitzung sich nicht selbst als fremde Sperre abzieht.
#
# Ausgabe nur bei NEXT=#N oder NEXT=none: SessionStart-JSON mit additionalContext (Hinweis, kein Auftrag).
# Leise (keine Ausgabe) bei: kaputtem stdin, Quelle resume/compact, fremdem Projekt, herdr-Name ohne führende #N,
# NEXT=unknown, Zeitüberschreitung, Exit ≠ 0. Schreibt nirgends hin. Endet immer mit Exit 0.
#
# Umgebung: HERDR_WORKSPACE_ID (Sitzung), LOOSEENDS_CHECKOUT (Hauptcheckout, Vorgabe /Users/hem/Developer/loose-ends),
#           LOOSEENDS_NEXT_TICKET (Vorgabe scripts/next-ticket.sh neben diesem Skript),
#           LOOSEENDS_NEXT_TIMEOUT (Sekunden, Vorgabe 25, unter dem timeout 30 des Eintrags)

set -u

CHECKOUT="${LOOSEENDS_CHECKOUT:-/Users/hem/Developer/loose-ends}"
SCRIPT="${LOOSEENDS_NEXT_TICKET:-$(cd "$(dirname "$0")" && pwd)/next-ticket.sh}"
LIMIT="${LOOSEENDS_NEXT_TIMEOUT:-25}"
NOTICE='Vorschlag für das nächste Ticket dieses Epics (Hinweis, kein Auftrag; ist ein Workflow aktiv, geht dessen Pflicht-Schritt vor):'

quiet() {  # quiet <grund>: Diagnose nur auf stderr, keine Ausgabe, Exit 0
    echo "next-ticket-hook: $1" >&2
    exit 0
}

command -v python3 >/dev/null 2>&1 || quiet "python3 fehlt"

# 1. stdin-JSON: drei Zeilen source, session_id, cwd (ohne Zeilenumbrüche); nicht lesbar = leise.
fields="$(python3 -c '
import json, sys
d = json.load(sys.stdin)
if not isinstance(d, dict):
    sys.exit(1)
for k in ("source", "session_id", "cwd"):
    v = d.get(k)
    print("" if v is None else str(v).replace("\n", " "))
' 2>/dev/null)" || quiet "stdin ist kein gültiges JSON"
{ IFS= read -r source; IFS= read -r session_id; IFS= read -r cwd; } <<< "$fields"

# 2. Nur startup und clear; bei resume/compact steht der Stand schon im Gespräch.
case "$source" in
    startup|clear) ;;
    *) quiet "Quelle '$source' wird nicht bedient" ;;
esac

# 3. Nur Loose Ends: Hauptcheckout oder darunter (Worktrees zählen mit).
case "$cwd" in
    "$CHECKOUT"|"$CHECKOUT"/*) ;;
    *) quiet "fremdes Projekt" ;;
esac

# 4. herdr-Sitzung mit führender #N im Namen.
[ -n "${HERDR_WORKSPACE_ID:-}" ] || quiet "keine herdr-Sitzung"
command -v herdr >/dev/null 2>&1 || quiet "herdr fehlt"
label="$(herdr workspace get "$HERDR_WORKSPACE_ID" 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
print((d.get("result") or d)["workspace"]["label"])
' 2>/dev/null)" || quiet "herdr-Name nicht lesbar"
[[ "$label" =~ ^#[0-9]+ ]] || quiet "herdr-Name ohne führende #N"

# 5. next-ticket.sh mit Zeitgrenze; die ganze Prozessgruppe wird beendet, damit kein Kindprozess die Ausgabe offen hält.
output="$(CLAUDE_SESSION_ID="$session_id" python3 -c '
import os, signal, subprocess, sys
p = subprocess.Popen(["bash", sys.argv[2]], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                     stderr=subprocess.DEVNULL, start_new_session=True)
try:
    out, _ = p.communicate(timeout=float(sys.argv[1]))
except subprocess.TimeoutExpired:
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except OSError:
        pass
    p.wait()
    sys.exit(124)
sys.stdout.write(out.decode("utf-8", "replace"))
sys.exit(p.returncode)
' "$LIMIT" "$SCRIPT" 2>/dev/null)"
rc=$?
[ "$rc" -eq 124 ] && quiet "next-ticket.sh braucht länger als $LIMIT s"
[ "$rc" -eq 0 ] || quiet "next-ticket.sh endet mit Exit $rc"

# 6. Nur NEXT=#N oder NEXT=none wird weitergegeben.
first="${output%%$'\n'*}"
[[ "$first" =~ ^NEXT=(#[0-9]+|none)$ ]] || quiet "kein Vorschlag (${first:-leer})"

NOTICE="$NOTICE" python3 -c '
import json, os, sys
text = os.environ["NOTICE"] + "\n" + sys.stdin.read().rstrip("\n")
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": text}}, ensure_ascii=False))
' <<< "$output" 2>/dev/null || quiet "Ausgabe nicht erzeugbar"
exit 0
