#!/bin/bash
#
# sim.sh — Build- und Test-Toolkit für Loose Ends
#
# EINE Anlaufstelle für Build, Tests, Simulator. Die Workflow-Hooks blocken
# direktes xcodebuild/simctl; Bau- und Testläufe holen die rechnerweite Sperre /tmp/loose-ends-testlauf.lock.
#
# Usage:
#   ./scripts/sim.sh generate                 # Xcode-Projekt aus project.yml erzeugen
#   ./scripts/sim.sh unit [Suite[/test]]      # Unit-Tests im iOS-Simulator; Mac als Host nur mit LOOSEENDS_MAC_HOST=1
#   ./scripts/sim.sh real-model               # Tests gegen das echte Modell auf diesem Mac (Apple Intelligence an, #531)
#   ./scripts/sim.sh build                    # iOS-App für den Simulator bauen
#   ./scripts/sim.sh mac-build                # macOS-App bauen
#   ./scripts/sim.sh mac-schema-init          # CloudKit-Schema in Development anlegen (#175, schreibt in iCloud)
#   ./scripts/sim.sh mac                      # „LE Prüfbau“ auf dem Mac: signiert bauen, nach ~/Applications, starten (#287)
#   ./scripts/sim.sh sim-unit [Suite[/test]]  # Unit-Tests im iOS-Simulator
#   ./scripts/sim.sh test <Class[/test]>      # UI-Test im iOS-Simulator
#   ./scripts/sim.sh test-proof <Class[/test]> # UI-Test + Simulator-Beleg in docs/artifacts/<workflow>/ (#145)
#   ./scripts/sim.sh watch-test-proof <Class[/test]> # dasselbe im watchOS-Simulator (#409)
#     LOOSEENDS_PUSH=<datei.apns> davor: spielt die Mitteilung während des Laufs alle 5 s ein (#295)
#   ./scripts/sim.sh boot | status | launch | screenshot [pfad]
#
# Messreihen gegen das echte Modell (Spikes #65-#73), ohne das iPhone zu belegen:
#   ./scripts/sim.sh lab                      # Labor-App aufs iPhone bringen
#   ./scripts/sim.sh lab-run [sekunden]       # Messlauf vom Mac starten (iPhone entsperrt), Start/Stopp protokolliert
#   ./scripts/sim.sh lab-fetch                # Ergebnisse vom iPhone holen (still, ohne Zutun)
#   ./scripts/sim.sh report                   # Bericht aus den geholten Ergebnissen bauen
#
# Auf Hennings echtem iPhone — Stufe 2, erst nachdem der Simulator grün war:
#   ./scripts/sim.sh device-status            # verbundenes Gerät und Verbindungsweg zeigen
#   ./scripts/sim.sh device                   # signiert bauen, drahtlos installieren, starten
#   ./scripts/sim.sh device-console [sek]     # dasselbe, aber Logausgabe live mitlesen (Vorgabe 30 s)
#   ./scripts/sim.sh device-build-release     # Prüfbau in Release (für Startzeiten, #22)
#   ./scripts/sim.sh launch-measure <n>       # n Kaltstarts des Release-Prüfbaus, Zeiten nach build/launch-timings/
#
# Simulator per Name: LOOSEENDS_SIM="iPhone 17 Pro" ./scripts/sim.sh build
# Gerät per UDID:     LOOSEENDS_DEVICE=00008140-... ./scripts/sim.sh device
# Signier-Team:       LOOSEENDS_TEAM_ID=XK87E2B3VR (Vorgabe, project.yml lässt es leer)

set -eo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT="LooseEnds.xcodeproj"
SCHEME="LooseEnds"
UNIT_TARGET="LooseEndsTests"
UI_TARGET="LooseEndsUITests"
SIM_NAME="${LOOSEENDS_SIM:-iPhone 17}"
SIM_OS="iOS"                      # watch-test-proof stellt auf watchOS um (#409)
SIM_FAMILY="iPhone"
SIMCTL="xcrun simctl"
DEVICECTL="xcrun devicectl"
TEAM_ID="${LOOSEENDS_TEAM_ID:-XK87E2B3VR}"
DEVICE_DERIVED_DATA=""  # wird in device_derived_data() gesetzt
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

# Bauordner je Worktree (#304): bereinigter Ordnername, CLAUDE_SESSION_ID als Override.
session_key() {
    local key="${CLAUDE_SESSION_ID:-}"
    [ -z "$key" ] && key=$(basename "$PROJECT_DIR" | LC_ALL=C sed 's/[^A-Za-z0-9._-]/-/g')
    echo "${key:-default}"
}
SESSION_ID="$(session_key)"
SESSION_DERIVED_DATA="$DERIVED_DATA/LooseEnds-session-${SESSION_ID}"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${BLUE}[sim]${NC} $1" >&2; }
success() { echo -e "${GREEN}[sim]${NC} $1" >&2; }
warn()    { echo -e "${YELLOW}[sim]${NC} $1" >&2; }
error()   { echo -e "${RED}[sim]${NC} $1" >&2; }

# --- Rechnerweite Testsperre (#413): mkdir ist atomar, eine Sperre für alle Worktrees ---
# Datei pid: pid, Startzeit (Epoch-Sekunden), Worktree, Befehl. Verwaist = PID tot, oder Startzeit ist eine
# Zahl und der Prozess hinter der PID ist jünger als sie (PID wiederverwendet). Ein Prozess, der vor oder zur
# Startzeit lief, ist der Halter: Handsperren schreiben start=$(date +%s) später als ihr Prozessstart (#341).
# Eine Startzeit in fremdem Format zählt nicht, dann nur die PID.
# Ohne pid-Zeile (Handsperre) erst nach LOOSEENDS_LOCK_HAND_GRACE Sekunden seit der Änderungszeit.
# Übernommen wird nur unter der Übernahme-Sperre <Sperre>.takeover, sonst verschiebt ein zweiter Wartender die
# eben neu angelegte Sperre eines anderen (#341, F001).

# Startzeit eines Prozesses in Epoch-Sekunden, unabhängig von der Locale; leer, wenn er nicht lebt.
proc_start() {
    local lstart
    lstart=$(LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | awk '{$1=$1; print}' || true)
    [ -n "$lstart" ] || return 0
    LC_ALL=C date -j -f "%a %b %d %T %Y" "$lstart" +%s 2>/dev/null \
        || LC_ALL=C date -d "$lstart" +%s 2>/dev/null || true
}

lock_is_stale() {
    local dir="${LOOSEENDS_LOCK_DIR:-/tmp/loose-ends-testlauf.lock}" pid start now mtime
    [ -e "$dir" ] || return 1   # auch eine Datei (alte Handabsprache) zählt als Handsperre ohne pid
    pid=$(sed -n 's/^pid=//p' "$dir/pid" 2>/dev/null | head -1 || true)
    if [ -n "$pid" ]; then
        now=$(proc_start "$pid")
        [ -n "$now" ] || return 0
        start=$(sed -n 's/^start=//p' "$dir/pid" 2>/dev/null | head -1 || true)
        [[ "$start" =~ ^[0-9]+$ ]] && [ "$now" -gt "$start" ] && return 0
        return 1
    fi
    mtime=$(stat -f %m "$dir" 2>/dev/null || stat -c %Y "$dir" 2>/dev/null || true)
    [ -n "$mtime" ] || return 1
    [ $(( $(date +%s) - mtime )) -gt "${LOOSEENDS_LOCK_HAND_GRACE:-1800}" ]
}

# Holt die Sperre für den Befehl $1. Wartet mit Statuszeile alle LOOSEENDS_LOCK_REPORT s, bricht nach
# LOOSEENDS_LOCK_MAX s ab. Reentrant: dieselbe Skript-PID oder ein Kind des Halters (LOOSEENDS_LOCK_OWNER).
# Warteliste (#516): nur der Kopf versucht mkdir, wer zuerst wartet, bekommt die Sperre zuerst. Eine verwaiste
# Sperre räumt jeder Wartende ab; ein Handskript ohne Liste kann vordrängeln, verklemmt aber nichts.
acquire_testlock() {
    local dir="${LOOSEENDS_LOCK_DIR:-/tmp/loose-ends-testlauf.lock}" what="${1:-sim.sh}"
    local max="${LOOSEENDS_LOCK_MAX:-1800}" every="${LOOSEENDS_LOCK_REPORT:-30}"
    local holder t0 elapsed last=-1 desc place m n=0 total=0
    holder=$(sed -n 's/^pid=//p' "$dir/pid" 2>/dev/null || true)
    if [ -n "$holder" ] && { [ "$holder" = "$$" ] || [ "$holder" = "${LOOSEENDS_LOCK_OWNER:-}" ]; } && ! lock_is_stale; then
        return 0
    fi
    t0=$(date +%s)
    mkdir -p "$(dirname "$dir")"
    queue_enter
    until [ "$(queue_head)" = "$QUEUE_MARK" ] && mkdir "$dir" 2>/dev/null && claim_testlock "$dir" "$what"; do
        lock_is_stale && take_over_stale_lock "$dir" && continue
        elapsed=$(( $(date +%s) - t0 ))
        [ "$elapsed" -ge "$max" ] || [ "$last" -lt 0 ] || [ $(( elapsed - last )) -ge "$every" ] || {
            sleep "${LOOSEENDS_LOCK_POLL:-5}"; continue; }
        n=0; total=0
        for m in "$dir.queue"/[0-9]*; do
            [ -d "$m" ] || continue
            total=$((total + 1)); [[ "$m" > "$QUEUE_MARK" ]] || n=$((n + 1))
        done
        place="Platz $n von $total in der Warteliste"
        if [ -f "$dir/pid" ]; then
            desc="Worktree $(sed -n 's/^worktree=//p' "$dir/pid" 2>/dev/null), Befehl $(sed -n 's/^command=//p' "$dir/pid" 2>/dev/null), PID $(sed -n 's/^pid=//p' "$dir/pid" 2>/dev/null)" || true
        elif [ -e "$dir" ]; then
            desc="Handsperre ohne pid-Datei ($dir)"
        else
            desc="keiner, Sperre frei, Vorrang hat $(basename "$(queue_head)")"
        fi
        if [ "$elapsed" -ge "$max" ]; then
            queue_leave
            error "Testsperre nach ${max} s nicht frei. Halter: $desc. $place. Sperre: $dir"
            return 1
        fi
        info "Testsperre belegt — warte ($elapsed s, $place). Halter: $desc"
        last=$elapsed
        sleep "${LOOSEENDS_LOCK_POLL:-5}"
    done
    queue_leave
    export LOOSEENDS_LOCK_OWNER=$$
}

# Stellt diesen Prozess in die Warteliste <Sperre>.queue (#516). Marke = ein mkdir, Name <time_ns 20-stellig>-<pid>,
# sortiert also nach Ankunft; darin pid= und start= wie in der Sperre. Die Liste selbst wird nie gelöscht.
queue_enter() {
    local queue="${LOOSEENDS_LOCK_DIR:-/tmp/loose-ends-testlauf.lock}.queue" ns
    mkdir -p "$queue"
    ns=$(python3 -c 'import time; print(time.time_ns())')
    QUEUE_MARK="$queue/$(printf '%020d' "$ns")-$$"
    mkdir "$QUEUE_MARK"
    { echo "pid=$$"; echo "start=$(proc_start $$)"; } > "$QUEUE_MARK/.pid.$$" \
        && mv "$QUEUE_MARK/.pid.$$" "$QUEUE_MARK/pid"
}

# Gibt die Kopfmarke aus (kleinster Name). Nur der Kopf wird geprüft: tot ist er, wenn seine PID nicht lebt oder
# wiederverwendet ist, ohne pid-Datei erst 10 s nach dem Anlegen. Tote Köpfe werden gelöscht, der Nächste rückt nach.
queue_head() {
    local queue="${LOOSEENDS_LOCK_DIR:-/tmp/loose-ends-testlauf.lock}.queue" head pid start now mtime
    while :; do
        head=""
        for head in "$queue"/[0-9]*; do [ -d "$head" ] && break; head=""; done
        [ -n "$head" ] || return 0
        if [ "$head" != "${QUEUE_MARK:-}" ]; then
            pid=$(sed -n 's/^pid=//p' "$head/pid" 2>/dev/null | head -1 || true)
            if [ -n "$pid" ]; then
                now=$(proc_start "$pid")
                start=$(sed -n 's/^start=//p' "$head/pid" 2>/dev/null | head -1 || true)
                if [ -z "$now" ] || { [[ "$start" =~ ^[0-9]+$ ]] && [ "$now" -gt "$start" ]; }; then
                    rm -rf "$head"; continue
                fi
            elif [ ! -e "$head/pid" ]; then
                mtime=$(stat -f %m "$head" 2>/dev/null || stat -c %Y "$head" 2>/dev/null || true)
                if [ -n "$mtime" ] && [ $(( $(date +%s) - mtime )) -gt 10 ]; then rm -rf "$head"; continue; fi
            fi
        fi
        echo "$head"
        return 0
    done
}

# Löscht die eigene Wartemarke, falls es eine gibt (#516).
queue_leave() {
    if [ -n "${QUEUE_MARK:-}" ]; then rm -rf "$QUEUE_MARK" 2>/dev/null || true; fi
    QUEUE_MARK=""
}

# Schreibt die pid-Datei in die eben angelegte Sperre. Erst vollständig schreiben, dann hineinschieben: ein
# Leser sieht nie eine halbe pid-Datei. Scheitert es, ist die Sperre verloren und der Aufrufer wartet weiter.
claim_testlock() {
    { echo "pid=$$"; echo "start=$(proc_start $$)"
      echo "worktree=$PROJECT_DIR"; echo "command=$2"; } 2>/dev/null > "$1/.pid.$$" \
        && mv "$1/.pid.$$" "$1/pid" 2>/dev/null && return 0
    rm -f "$1/.pid.$$" 2>/dev/null || true
    warn "Testsperre beim Anlegen verloren, warte weiter"
    return 1
}

# Übernimmt eine verwaiste Sperre $1, nur unter der Übernahme-Sperre $1.takeover (#341, F001). Rückgabe 1:
# ein anderer übernimmt gerade, der Aufrufer wartet. Eine Übernahme-Sperre älter als 10 s ist verwaist.
take_over_stale_lock() {
    local dir="$1" guard="$1.takeover" old mtime
    if ! mkdir "$guard" 2>/dev/null; then
        mtime=$(stat -f %m "$guard" 2>/dev/null || stat -c %Y "$guard" 2>/dev/null || true)
        if [ -n "$mtime" ] && [ $(( $(date +%s) - mtime )) -gt 10 ]; then rmdir "$guard" 2>/dev/null || true; fi
        return 1
    fi
    if lock_is_stale; then
        old="$dir.stale.$$.$RANDOM"
        if mv "$dir" "$old" 2>/dev/null; then
            warn "Verwaiste Testsperre übernommen ($(tr '\n' ' ' 2>/dev/null < "$old/pid" || echo 'ohne pid-Datei'))"
            rm -rf "$old"
        fi
    fi
    rmdir "$guard" 2>/dev/null || true
}

# Gibt die Sperre nur frei, wenn sie diesem Prozess gehört; ohne Sperre gefahrlos.
release_testlock() {
    local dir="${LOOSEENDS_LOCK_DIR:-/tmp/loose-ends-testlauf.lock}" gone
    queue_leave   # auch ein Wartender ohne Sperre, etwa per TERM beendet, räumt seine Marke (#516)
    grep -qx "pid=$$" "$dir/pid" 2>/dev/null || return 0
    gone="$dir.done.$$.$RANDOM"
    mv "$dir" "$gone" 2>/dev/null && rm -rf "$gone"
    unset LOOSEENDS_LOCK_OWNER
    return 0
}
trap release_testlock EXIT

# --- Deployment Target aus project.yml lesen (eine Quelle der Wahrheit) ---
deployment_target() {
    python3 -c '
import re, sys
text = open(sys.argv[1]).read()
block = re.search(r"deploymentTarget:(.*?)\n\s{0,2}\w+:", text, re.S)
hit = re.search(sys.argv[2] + r":\s*\"?([\d.]+)", block.group(1) if block else text)
print(hit.group(1) if hit else "")' "$PROJECT_DIR/project.yml" "$1"
}

# --- Simulator auflösen ---
# Nur Laufzeiten, die das iOS-Deployment-Target erfüllen. Sonst landet man auf
# einem Gerät, das Xcode als Ziel ablehnt ("doesn't match deployment target") —
# daran scheiterte der Simulatorlauf am 2026-09-19: "iPhone 17" existiert
# gleichzeitig unter iOS 26.5 und 27.0, und die 26.5er Version kam zuerst.
sim_id() {
    $SIMCTL list devices available -j 2>/dev/null | python3 -c '
import json, re, sys
name, minimum = sys.argv[1], sys.argv[2]
def ver(s): return tuple(int(p) for p in re.findall(r"\d+", s)[:3])
floor = ver(minimum) if minimum else (0,)
cands = []
for runtime, devs in json.load(sys.stdin)["devices"].items():
    m = re.search(r"SimRuntime\." + sys.argv[3] + r"-([\d-]+)$", runtime)
    if not m: continue
    v = ver(m.group(1).replace("-", "."))
    if v < floor: continue
    cands += [(v, d) for d in devs]
if not cands: sys.exit(0)
hit = next((d for _, d in cands if d["name"] == name), None)
if hit is None:
    pool = [c for c in cands if c[1]["name"].startswith(sys.argv[4])] or cands
    hit = max(pool, key=lambda c: c[0])[1]
print(hit["udid"])' "$SIM_NAME" "$(deployment_target "$SIM_OS")" "$SIM_OS" "$SIM_FAMILY"
}

ensure_project() {
    if [ ! -d "$PROJECT_DIR/$PROJECT" ]; then info "Kein Projekt, erzeuge mit xcodegen"; cmd_generate; fi
}

cmd_generate() {
    cd "$PROJECT_DIR"
    command -v xcodegen >/dev/null || { error "xcodegen fehlt: brew install xcodegen"; return 1; }
    xcodegen generate
    success "Projekt erzeugt."
}

BUILD_LOG=""
run_xcodebuild() {
    cd "$PROJECT_DIR"
    mkdir -p "$SESSION_DERIVED_DATA"
    BUILD_LOG="$SESSION_DERIVED_DATA/xcodebuild.log"
    # Ein roter Test startet sonst `simctl diagnose --timeout=600` und xcodebuild wartet darauf,
    # bei mehreren Simulatoren bis zu 19 Min (#298). Testergebnis und Ergebnisbündel bleiben gleich.
    [ "${1:-}" = test ] && set -- "$@" -collect-test-diagnostics never
    # Stille-Wächter (#516): Bleibt das Log LOOSEENDS_SILENCE_MAX s stumm, endet nur der xcodebuild dieser
    # Sitzung (eigener -derivedDataPath) samt Kindern, sonst hielte er die rechnerweite Sperre unbegrenzt.
    # Der Wächter endet mit sim.sh ($$ in der Subshell): Ein xcodebuild einer per KILL gestorbenen sim.sh bleibt
    # bewusst als Waise stehen, später gehörte derselbe Pfad womöglich schon dem nächsten Lauf (#516, F001).
    local hung="$SESSION_DERIVED_DATA/xcodebuild.hung" status=0 watcher
    rm -f "$hung"; : > "$BUILD_LOG"
    (
        max=${LOOSEENDS_SILENCE_MAX:-900} sp=""
        trap '[ -n "$sp" ] && kill "$sp" 2>/dev/null; exit 0' TERM
        while :; do
            sleep "${LOOSEENDS_SILENCE_POLL:-10}" & sp=$!; wait "$sp"; sp=""
            kill -0 $$ 2>/dev/null || exit 0   # sim.sh tot (#516, F001): nichts mehr auslösen
            age=$(( $(date +%s) - $(stat -f %m "$BUILD_LOG" 2>/dev/null || date +%s) ))
            [ "$age" -gt "$max" ] || continue
            trap - TERM; touch "$hung"
            echo "xcodebuild hängt seit $((age / 60)) min, abgebrochen (Frist ${max} s Stille, LOOSEENDS_SILENCE_MAX)." >&2
            echo "Letzte Logzeile: $(tail -n 1 "$BUILD_LOG")" >&2
            echo "Ein Neustart von CoreSimulatorService kann nötig sein." >&2
            kill -0 $$ 2>/dev/null || exit 0
            pids=$(pgrep -f -- "xcodebuild.* -derivedDataPath $SESSION_DERIVED_DATA( |\$)" || true)
            for p in $pids; do pkill -TERM -P "$p" 2>/dev/null || true; kill -TERM "$p" 2>/dev/null || true; done
            sleep 5
            for p in $pids; do pkill -KILL -P "$p" 2>/dev/null || true; kill -KILL "$p" 2>/dev/null || true; done
            exit 0
        done
    ) </dev/null >/dev/null &
    watcher=$!
    # Die Rohausgabe geht ins Log, bevor xcbeautify sie kürzt: Messberichte stehen darin.
    if command -v xcbeautify >/dev/null; then
        xcodebuild "$@" -derivedDataPath "$SESSION_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$BUILD_LOG" | xcbeautify || status=$?
    else
        xcodebuild "$@" -derivedDataPath "$SESSION_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$BUILD_LOG" || status=$?
    fi
    # Hat der Wächter ausgelöst, darf er seinen KILL-Schritt beenden; die Markierung entscheidet, nicht pipefail.
    [ -e "$hung" ] || kill "$watcher" 2>/dev/null || true
    wait "$watcher" 2>/dev/null || true
    [ -e "$hung" ] && { rm -f "$hung"; return 1; }
    return "$status"
}

# Ein Messlauf druckt seinen Bericht zwischen Markern, weil ein Test auf dem iPhone nicht ins
# Repository schreiben kann. Hier wird er wieder herausgeschnitten und abgelegt.
extract_reports() {
    local log="$1"
    [ -f "$log" ] || return 0
    python3 - "$log" "$PROJECT_DIR/docs/reference" <<'EOF'
import re, sys, pathlib
log, out = pathlib.Path(sys.argv[1]).read_text(errors="replace"), pathlib.Path(sys.argv[2])
found = re.findall(r"<<<REPORT:([a-z0-9-]+)>>>\n(.*?)\n<<<END REPORT>>>", log, re.S)
for name, body in found:
    path = out / f"{name}.md"
    path.write_text(body.rstrip() + "\n")
    print(f"[sim] Bericht: {path.relative_to(out.parent.parent)}")
EOF
}

# Der Mac kann die Tests nur hosten, wenn sein macOS das Deployment Target
# erfüllt. Solange das Target über der installierten Version liegt (27.0 auf
# einem 26er Mac), lehnt xcodebuild die Mac-Destination rundweg ab — dann
# laufen dieselben Unit-Tests im iOS-Simulator statt gar nicht.
mac_hosts_tests() {
    local want; want=$(deployment_target macOS); [ -z "$want" ] && return 0
    python3 -c '
import re, sys
def ver(s): return tuple(int(p) for p in re.findall(r"\d+", s)[:3])
sys.exit(0 if ver(sys.argv[1]) >= ver(sys.argv[2]) else 1)' "$(sw_vers -productVersion)" "$want"
}

# Welche Messstrecken mangels Daten übersprungen wurden (#149): ein übersprungener Lauf meldet
# sonst „Test Succeeded" wie ein gemessener.
# Dazu der Latenzschutz aus #274 (#419) aus dem Rohlog des Laufs; ohne Log sagt das Skript „kein Log“.
measurement_status() {
    python3 "$PROJECT_DIR/scripts/measurement_status.py" --latency-log "${BUILD_LOG:-kein-xcodebuild-log}" >&2 \
        || warn "Messstrecken-Status nicht lesbar."
}

cmd_unit() {
    acquire_testlock "unit"
    ensure_project
    local only="$UNIT_TARGET"; [ -n "${1:-}" ] && only="$UNIT_TARGET/$1"
    # Standard ist der Simulator (#294, #374): der Mac hostet nur mit LOOSEENDS_MAC_HOST=1.
    if [ "${LOOSEENDS_MAC_HOST:-}" != 1 ]; then
        info "Unit-Tests im Simulator (Mac als Host nur mit LOOSEENDS_MAC_HOST=1)."
        cmd_sim_unit "$@"
        return
    fi
    if ! mac_hosts_tests; then
        warn "macOS $(sw_vers -productVersion) < Deployment Target $(deployment_target macOS) — Unit-Tests laufen im Simulator."
        cmd_sim_unit "$@"
        return
    fi
    info "Unit-Tests (macOS): $only"
    run_xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination 'platform=macOS' -only-testing:"$only" -parallel-testing-enabled NO
    success "Unit-Tests bestanden."
    measurement_status
}

# Das echte On-Device-Modell auf diesem Mac (#531): dasselbe Modell wie auf dem iPhone, ohne Labor-App.
# Nur hier gesetzt, nie in der CI; ohne Apple Intelligence überspringt die Suite sich selbst.
cmd_real_model() {
    acquire_testlock "real-model"
    ensure_project
    mac_hosts_tests || { error "macOS $(sw_vers -productVersion) < Deployment Target $(deployment_target macOS): das Modell läuft nur auf dem Mac selbst"; return 1; }
    [ "$(uname -m)" = arm64 ] || { error "Apple Intelligence braucht einen Mac mit Apple Silicon"; return 1; }
    info "Echtes Modell (macOS): $UNIT_TARGET/RealModelTests"
    local rc=0
    TEST_RUNNER_LOOSEENDS_REAL_MODEL=1 run_xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination 'platform=macOS' \
        -only-testing:"$UNIT_TARGET/RealModelTests" -parallel-testing-enabled NO || rc=$?
    real_model_result "$BUILD_LOG"
    return $rc
}

# Ein Satz am Ende statt „siehe Ausgabe“ (Henning, 2026-10-19: aus dem Log war nicht zu erkennen, ob die
# Modelltests liefen). Liest die Zeilen zu RealModelTests aus dem rohen xcodebuild-Log: Swift Testing
# schreibt je Test „passed“, „failed“ oder „skipped“ mit dem Grund des Gates.
real_model_result() {
    local log="$1"
    [ -f "$log" ] || { warn "Kein Log unter $log; Ergebnis der Modelltests unbekannt."; return; }
    local lines; lines=$(grep -E 'RealModelTests|LOOSEENDS_REAL_MODEL|Apple Intelligence is not available' "$log" | grep -E 'passed|failed|skipped' || true)
    echo "$lines" | sed '/^$/d' | sed 's/^/   /' >&2
    if echo "$lines" | grep -q 'skipped'; then
        warn "Modelltests ÜBERSPRUNGEN, nicht gelaufen. Grund steht oben (Variable nicht gesetzt oder Apple Intelligence aus)."
    elif echo "$lines" | grep -qE 'failed'; then
        error "Modelltests gegen das echte Modell FEHLGESCHLAGEN; Details oben und in $log"
    elif echo "$lines" | grep -qE 'passed'; then
        success "Modelltests gegen das echte Modell BESTANDEN: Das Modell lief auf diesem Mac."
    else
        warn "Keine Zeile zu RealModelTests im Log; der Lauf ist vermutlich vor den Tests abgebrochen: $log"
    fi
}

cmd_build() {
    acquire_testlock "build"
    ensure_project
    local id; id=$(sim_id); [ -z "$id" ] && { error "Kein Simulator '$SIM_NAME' gefunden"; return 1; }
    info "iOS-Build für $SIM_NAME ($id), DerivedData $SESSION_DERIVED_DATA"
    run_xcodebuild build -project "$PROJECT" -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$id"
    success "Build erfolgreich."
}

cmd_mac_build() {
    acquire_testlock "mac-build"
    ensure_project
    info "macOS-Build"
    run_xcodebuild build -project "$PROJECT" -scheme "$SCHEME" -destination 'platform=macOS'
    success "macOS-Build erfolgreich."
}

# Schreibt das volle CloudKit-Schema in Development der Hauptkennung (#175): signierter
# macOS-Debug-Bau, gestartet mit -LEInitializeCloudKitSchema. Schreibt in Hennings iCloud-Konto,
# nur nach Freigabe laufen lassen. Erstes Profil: einmal LOOSEENDS_REGISTER=1 (wie signed_build).
cmd_mac_schema_init() {
    ensure_project
    cd "$PROJECT_DIR"
    local dd; dd="$(device_derived_data)-mac"
    local args=(build -project "$PROJECT" -scheme "$SCHEME" -destination 'platform=macOS'
                -configuration Debug -derivedDataPath "$dd" "DEVELOPMENT_TEAM=$TEAM_ID")
    if [ "${LOOSEENDS_REGISTER:-}" = 1 ]; then
        warn "Registrierungslauf: benutzt die Anmeldung in Xcode (einmalig für neue Kennungen/Profile, #156)"
        args+=(-allowProvisioningUpdates)
    fi
    info "Signierter macOS-Debug-Bau der Hauptkennung, Team $TEAM_ID"
    # Rückgabewert von xcodebuild, nicht von xcbeautify (Lehre #144).
    local rc=0
    if command -v xcbeautify >/dev/null; then
        xcodebuild "${args[@]}" 2>&1 | xcbeautify || rc=${PIPESTATUS[0]}
    else
        xcodebuild "${args[@]}" 2>&1 || rc=$?
    fi
    [ "$rc" -eq 0 ] || { error "macOS-Bau fehlgeschlagen (xcodebuild $rc)."; return 1; }
    local bin="$dd/Build/Products/Debug/LooseEnds.app/Contents/MacOS/LooseEnds"
    [ -x "$bin" ] || { error "Programm fehlt: $bin"; return 1; }
    info "Starte Schema-Initialisierung: $bin -LEInitializeCloudKitSchema"
    # Der Exit-Code kommt vom Programm selbst, nicht von einer Pipe.
    local prc=0
    "$bin" -LEInitializeCloudKitSchema || prc=$?
    [ "$prc" -eq 0 ] || { error "Schema-Initialisierung fehlgeschlagen (Exit $prc)."; return "$prc"; }
    success "Schema-Initialisierung erfolgreich (Exit 0)."
}

# „LE Prüfbau“ auf dem Mac (#287), das Gegenstück zu `device`: Prüfkennung (.probe), eigene
# App-Gruppe und eigener iCloud-Container, nie Hennings normale Mac-App (Henning, 2026-10-08).
# Ersetzt die vorige Fassung in ~/Applications und startet sie. Die erste Mac-Fassung der
# Prüfkennung braucht einmal LOOSEENDS_REGISTER=1 (Mac-Profil, benutzt die Xcode-Anmeldung).
cmd_mac() {
    ensure_project
    cd "$PROJECT_DIR"
    local dd; dd="$(device_derived_data)-mac-probe"
    local args=(build -project "$PROJECT" -scheme "$SCHEME" -destination 'platform=macOS'
                -configuration Debug -derivedDataPath "$dd" "DEVELOPMENT_TEAM=$TEAM_ID"
                "BUNDLE_ID_SUFFIX=.probe" "LE_DISPLAY_NAME=LE Prüfbau")
    if [ "${LOOSEENDS_REGISTER:-}" = 1 ]; then
        warn "Registrierungslauf: benutzt die Anmeldung in Xcode (einmalig für neue Kennungen/Profile, #156)"
        args+=(-allowProvisioningUpdates)
    fi
    info "Signierter macOS-Prüfbau, Team $TEAM_ID"
    local rc=0
    if command -v xcbeautify >/dev/null; then
        xcodebuild "${args[@]}" 2>&1 | xcbeautify || rc=${PIPESTATUS[0]}
    else
        xcodebuild "${args[@]}" 2>&1 || rc=$?
    fi
    if [ "$rc" -ne 0 ]; then
        error "macOS-Prüfbau fehlgeschlagen (xcodebuild $rc)."
        warn "Erster Mac-Bau der Prüfkennung? Dann einmal: LOOSEENDS_REGISTER=1 ./scripts/sim.sh mac"
        return 1
    fi
    local built="$dd/Build/Products/Debug/LooseEnds.app"
    local bundle; bundle=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$built/Contents/Info.plist")
    [[ "$bundle" == *.probe ]] || { error "$bundle ist nicht die Prüfkennung — Abbruch."; return 1; }
    local target="$HOME/Applications/LE Prüfbau.app"
    mkdir -p "$HOME/Applications"
    # Eine laufende Fassung beenden, sonst startet `open` die alte weiter.
    osascript -e "tell application id \"$bundle\" to quit" >/dev/null 2>&1 || true
    rm -rf "$target"
    ditto "$built" "$target"
    open "$target"
    success "LE Prüfbau läuft auf dem Mac ($bundle, $target)."
}

cmd_boot() {
    local id; id=$(sim_id); [ -z "$id" ] && { error "Kein Simulator '$SIM_NAME'"; return 1; }
    open -a Simulator --args -CurrentDeviceUDID "$id" 2>/dev/null || true
    $SIMCTL boot "$id" 2>/dev/null || true
    $SIMCTL bootstatus "$id" -b >/dev/null 2>&1 || true
    # Frischer Simulator (#341): der Tastatur-Hinweis „Speed up your typing…“ hängt XCTest-Abfragen auf.
    [ "$SIM_OS" = "iOS" ] && { $SIMCTL spawn "$id" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true || warn "Tastatur-Hinweis nicht abgeschaltet ($SIM_NAME), UI-Tests können hängen (#341)"; }
    success "Simulator bereit ($SIM_NAME)."
}

cmd_status() {
    local id; id=$(sim_id)
    [ -z "$id" ] && { warn "Kein Simulator '$SIM_NAME' verfügbar"; $SIMCTL list devices available | grep iPhone || true; return 1; }
    info "Simulator: $SIM_NAME ($id)"
    $SIMCTL list devices | grep "$id" | grep -q Booted && success "Booted" || warn "Shutdown"
    ls -d "$SESSION_DERIVED_DATA"/Build/Products/Debug-iphonesimulator/LooseEnds.app >/dev/null 2>&1 && success "App gebaut" || warn "Noch nicht gebaut (./scripts/sim.sh build)"
}

cmd_sim_unit() {
    acquire_testlock "sim-unit"; ensure_project; cmd_boot
    local id; id=$(sim_id)
    local only="$UNIT_TARGET"; [ -n "${1:-}" ] && only="$UNIT_TARGET/$1"
    info "Unit-Tests (iOS-Simulator): $only"
    run_xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$id" -only-testing:"$only" -parallel-testing-enabled NO
    success "Unit-Tests bestanden."
    measurement_status
}

cmd_test() {
    [ -z "${1:-}" ] && { error "Usage: ./scripts/sim.sh test Class[/test]"; return 1; }
    acquire_testlock "test"; ensure_project; cmd_boot
    local id; id=$(sim_id)
    info "UI-Test: $1"
    run_xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$id" -only-testing:"$UI_TARGET/$1" -parallel-testing-enabled NO -disable-concurrent-destination-testing
    success "UI-Test bestanden."
}

# UI-Test mit maschinellem Beleg (#145): Beleg, summary.json und Screenshots entstehen aus diesem
# Lauf (Ergebnisbündel + xcodebuild-Rückgabewert), nie aus Handkopie. Prüfungen vor jedem Werkzeug.
cmd_test_proof() {
    [ -z "${1:-}" ] && { error "Usage: ./scripts/sim.sh test-proof <Testklasse>[/<test>]"; return 1; }
    local wf="" wf_file="$PROJECT_DIR/.claude/active_workflow"
    [ -f "$wf_file" ] && wf=$(tr -d '[:space:]' < "$wf_file")
    [ -z "$wf" ] && { error "Kein aktiver Workflow (.claude/active_workflow), Beleg hätte keinen Ablageort"; return 1; }
    # Der Name wird Pfadbestandteil und landet in `rm -rf`: nur ein einzelner Ordnername ist erlaubt (#166).
    if ! [[ "$wf" =~ ^[A-Za-z0-9._-]+$ ]] || [[ "$wf" == "." || "$wf" == ".." || "$wf" == *..* ]]; then
        error "Ungültiger Workflow-Name '$wf' (.claude/active_workflow): erlaubt sind Buchstaben, Ziffern, . _ -, ohne '..'"
        return 1
    fi
    local art="docs/artifacts/$wf"; local run="$art/simulator-run"
    cd "$PROJECT_DIR"
    # Erst die Sperre, dann aufräumen (#341): ein wartender Lauf löschte sonst das Ergebnisbündel des laufenden.
    acquire_testlock "test-proof"
    rm -rf "$art/simulator-run.txt" "$run"   # ein alter grüner Beleg darf keinen roten Lauf überleben
    mkdir -p "$run"
    cmd_generate; cmd_boot
    local id; id=$(sim_id)
    info "UI-Test mit Beleg: $1 → $art/simulator-run.txt"
    # Mitteilungstests (#295): `add` aus der App scheitert im iOS-27-Simulator (UNErrorDomain 2003),
    # also spielt der Lauf die Datei aus LOOSEENDS_PUSH alle 5 s per simctl push ein.
    local push_pid=""
    if [ -n "${LOOSEENDS_PUSH:-}" ]; then
        [ -f "$LOOSEENDS_PUSH" ] || { release_testlock; error "LOOSEENDS_PUSH: $LOOSEENDS_PUSH fehlt"; return 1; }
        export TEST_RUNNER_LOOSEENDS_PUSH_FEED=1
        ( while true; do $SIMCTL push "$id" com.henning.looseends "$LOOSEENDS_PUSH" >/dev/null 2>&1 || true; sleep 5; done ) &
        push_pid=$!
        info "Mitteilungen aus $LOOSEENDS_PUSH alle 5 s (simctl push)"
    fi
    # Rückgabewert aus diesem Lauf festhalten (pipefail, Lehre #144); `|| rc=` hält set -e auf.
    local rc=0
    # Watch (#409): App vorher deinstallieren, sonst hängt der Testläufer (developer.apple.com/forums/thread/805060).
    [ -n "${WATCH_APP_ID:-}" ] && { $SIMCTL uninstall "$id" "$WATCH_APP_ID" 2>/dev/null || true; }
    run_xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "platform=$SIM_OS Simulator,id=$id" \
        -only-testing:"$UI_TARGET/$1" -parallel-testing-enabled NO -disable-concurrent-destination-testing \
        -resultBundlePath "$run/run.xcresult" || rc=$?
    [ -n "$push_pid" ] && { kill "$push_pid" 2>/dev/null || true; }
    local endline; endline=$(grep -E '^\*\* TEST (SUCCEEDED|FAILED) \*\*' "$BUILD_LOG" | tail -1 || true)
    release_testlock
    local prc=0
    python3 scripts/sim_proof.py "$wf" "$1" "$run/run.xcresult" "${endline:-unbekannt}" \
        "scripts/sim.sh test-proof $1" "$rc" || prc=$?
    [ "$rc" -ne 0 ] && { error "UI-Test fehlgeschlagen (xcodebuild $rc), Beleg: $art/simulator-run.txt"; return "$rc"; }
    [ "$prc" -ne 0 ] && { error "Beleg ungültig (sim_proof $prc): $art/simulator-run.txt"; return "$prc"; }
    success "UI-Test bestanden, Beleg: $art/simulator-run.txt"
}

# Watch-UI-Test mit demselben Beleg (#409): watchOS-Simulator mit Laufzeit ≥ Target, eigenes Schema.
cmd_watch_test_proof() {
    SIM_OS="watchOS"; SIM_FAMILY="Apple Watch"; SIM_NAME="${LOOSEENDS_WATCH_SIM:-Apple Watch Series 12 (46mm)}"
    SCHEME="LooseEndsWatch"; UI_TARGET="LooseEndsWatchUITests"; WATCH_APP_ID="com.henning.looseends.watchkitapp"
    cmd_test_proof "$@"
}

cmd_launch() {
    acquire_testlock "launch"; cmd_boot
    local id; id=$(sim_id)
    local app="$SESSION_DERIVED_DATA/Build/Products/Debug-iphonesimulator/LooseEnds.app"
    [ -d "$app" ] || { error "Erst bauen: ./scripts/sim.sh build"; return 1; }
    local bundle; bundle=$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")
    $SIMCTL terminate "$id" "$bundle" 2>/dev/null || true
    $SIMCTL install "$id" "$app"
    $SIMCTL launch "$id" "$bundle" "$@"
    success "App gestartet ($bundle)."
}

# --- Stufe 2: Hennings echtes iPhone ---------------------------------------
# Was der Simulator prinzipiell nicht kann: Apple Intelligence auf dem Gerät,
# CloudKit-Sync zwischen Geräten, Watch, Action Button, Widgets, Mikrofon. Und:
# signierte Builds laufen durch Provisioning und Entitlements — genau dort lag
# der App-Group-Absturz (#55), den der unsignierte Simulator-Build nicht zeigt.
# Erst laufen lassen, wenn Unit-Tests, UI-Tests und der Simulator grün sind.

# Erstes verbundenes physisches iOS-Gerät, oder LOOSEENDS_DEVICE.
device_id() {
    if [ -n "${LOOSEENDS_DEVICE:-}" ]; then echo "$LOOSEENDS_DEVICE"; return; fi
    $DEVICECTL list devices 2>/dev/null | python3 -c '
import re, sys
for line in sys.stdin:
    if "physical" not in line: continue
    m = re.search(r"([0-9A-F]{8}-[0-9A-F]{16})\s+\(UDID\)\s+(\S+)", line)
    if m and m.group(2) != "unavailable":
        print(m.group(1)); break'
}

device_derived_data() {
    echo "$DERIVED_DATA/LooseEnds-device-${SESSION_ID}"
}

require_device() {
    local id; id=$(device_id)
    [ -z "$id" ] && { error "Kein verbundenes iPhone. Gerät entsperren und im selben WLAN halten."; return 1; }
    echo "$id"
}

cmd_device_status() {
    local id; id=$(require_device) || return 1
    info "Gerät: $id"
    $DEVICECTL device info details --device "$id" 2>&1 |
        grep -E "Device State|Transport Type|Marketing Name|Platform|OS Version" || true
}

# Signierte Gerätebauten nutzen nur die gespeicherten Profile (#156). Kein -allowProvisioningUpdates:
# es meldet seit Xcode 16 die Anmeldung in Xcode ab (Apple-Forum 765741, 765893). Kein API-Schlüssel:
# er kann keine neuen Entwicklungsprofile anlegen (Forum 763225, Lauf 36822132719). Neue Kennungen,
# Fähigkeiten oder abgelaufene Profile: einmal LOOSEENDS_REGISTER=1 (benutzt die Xcode-Anmeldung).
signed_build() {
    local id="$1" scheme="$2"; shift 2
    cd "$PROJECT_DIR"
    local args=(build -project "$PROJECT" -scheme "$scheme" -destination "id=$id"
                -derivedDataPath "$(device_derived_data)" "DEVELOPMENT_TEAM=$TEAM_ID" "$@")
    if [ "${LOOSEENDS_REGISTER:-}" = 1 ]; then
        warn "Registrierungslauf: benutzt die Anmeldung in Xcode (einmalig für neue Kennungen/Profile, #156)"
        args+=(-allowProvisioningUpdates)
    fi
    info "Signierter Build für das Gerät ($id), $scheme, Team $TEAM_ID"
    # Der Rückgabewert muss von xcodebuild kommen, nicht von xcbeautify: ohne
    # PIPESTATUS meldete die Stufe am 2026-09-28 „Gerätebuild erfolgreich“,
    # während xcodebuild „Unable to find a destination“ ausgab (#144-Abnahme).
    local rc=0
    if command -v xcbeautify >/dev/null; then
        xcodebuild "${args[@]}" 2>&1 | xcbeautify || rc=${PIPESTATUS[0]}
    else
        xcodebuild "${args[@]}" 2>&1 || rc=$?
    fi
    [ "$rc" -eq 0 ] || { error "Gerätebuild fehlgeschlagen ($scheme, xcodebuild $rc)."; return 1; }
}

cmd_device_build() {
    local id; id=$(require_device) || return 1
    ensure_project
    # Prüfkennung (#156, ADR-18): der Gerätebau installiert nie unter Hennings Kennung.
    signed_build "$id" "$SCHEME" "BUNDLE_ID_SUFFIX=.probe" "LE_DISPLAY_NAME=LE Prüfbau" || return 1
    success "Gerätebuild erfolgreich."
}

device_app_path() { echo "$(device_derived_data)/Build/Products/${1:-Debug}-iphoneos/LooseEnds.app"; }

# Startzeiten taugen nur aus Release (#22): Debug ist unoptimiert und lädt eine Debug-Dylib.
cmd_device_build_release() {
    local id; id=$(require_device) || return 1
    ensure_project
    signed_build "$id" "$SCHEME" -configuration Release "BUNDLE_ID_SUFFIX=.probe" "LE_DISPLAY_NAME=LE Prüfbau" || return 1
    $DEVICECTL device install app --device "$id" "$(device_app_path Release)" >/dev/null || {
        error "Installation fehlgeschlagen — iPhone entsperren und ins selbe WLAN holen."; return 1; }
    success "Release-Prüfbau installiert."
}

# Zahl der Läufe in der Messdatei des Prüfbaus. Nur lesend. 0 nur, wenn die Auflistung gelingt und
# die Datei fehlt; scheitert Auflistung oder Abruf (gesperrt, nicht erreichbar), Abbruch mit Fehler.
launch_runs_on_device() {
    local id="$1" bundle="$2" dest="$3" list="$3.list.json"
    local where=(--device "$id" --domain-type appDataContainer --domain-identifier "$bundle")
    rm -f "$dest" "$list"
    $DEVICECTL device info files "${where[@]}" --username mobile --subdirectory Documents --no-recurse \
        -q --json-output "$list" >/dev/null 2>&1 || { error "Messdatei nicht abrufbar (Auflistung) — iPhone entsperren."; return 1; }
    local has; has=$(python3 -c 'import json,sys; print(int(any(f["name"] == "launch-timings.json" for f in json.load(open(sys.argv[1]))["result"]["files"])))' "$list") \
        || { error "Auflistung der Messdatei unlesbar ($list)."; return 1; }
    [ "$has" = 1 ] || { echo 0; return; }
    $DEVICECTL device copy from "${where[@]}" --user mobile --source "Documents/launch-timings.json" \
        --destination "$dest" >/dev/null 2>&1 || { error "Messdatei nicht abrufbar (Kopie) — iPhone entsperren."; return 1; }
    python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$dest"
}

# n Kaltstarts per devicectl mit -measureLaunch (#22). Ausschließlich die Prüfkennung.
cmd_launch_measure() {
    local n="${1:?Anzahl der Läufe fehlt}"
    local id; id=$(require_device) || return 1
    # Gemessen wird genau dieser Stand: sonst startete ein zuvor installierter Debug-Prüfbau (F001).
    cmd_device_build_release || return 1
    local app; app=$(device_app_path Release)
    local bundle; bundle=$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")
    [[ "$bundle" == *.probe ]] || { error "$bundle ist nicht die Prüfkennung — Abbruch."; return 1; }
    local out="$PROJECT_DIR/build/launch-timings"; mkdir -p "$out"
    local file="$out/launch-timings.json"
    info "Konfiguration: Release ($app)"
    local count; count=$(launch_runs_on_device "$id" "$bundle" "$file") || return 1
    for ((i = 1; i <= n; i++)); do
        info "Kaltstart $i/$n ($bundle, bisher $count Läufe)"
        local rc=0
        $DEVICECTL device process launch --terminate-existing --device "$id" "$bundle" -measureLaunch 2>&1 | tail -3 || rc=${PIPESTATUS[0]}
        [ "$rc" -eq 0 ] || { error "Start abgelehnt (devicectl $rc) — iPhone entsperren, dann erneut."; return 1; }
        local waited=0 now="$count"
        while [ "$now" -le "$count" ]; do
            [ "$waited" -lt 30 ] || { error "Lauf $i: nach 30 s kein neuer Eintrag in der Messdatei."; return 1; }
            sleep 2; waited=$((waited + 2))
            now=$(launch_runs_on_device "$id" "$bundle" "$file") || return 1
        done
        count="$now"
    done
    python3 -c 'import json,sys
for r in json.load(open(sys.argv[1])):
    print(r["kind"], r["zeroPoint"], "total", r["sections"].get("total"), "firstBuffer", r["points"].get("firstBuffer"))' "$file"
    success "$count Läufe (Release) in build/launch-timings/launch-timings.json"
}

# Installieren geht auch bei gesperrtem iPhone; Starten braucht ein entsperrtes.
cmd_device_install() {
    local id; id=$(require_device) || return 1
    local app; app=$(device_app_path)
    [ -d "$app" ] || { error "Erst bauen: ./scripts/sim.sh device-build"; return 1; }
    info "Installiere drahtlos auf $id"
    $DEVICECTL device install app --device "$id" "$app" >/dev/null || {
        error "Installation fehlgeschlagen — iPhone entsperren und ins selbe WLAN holen."
        return 1
    }
    success "Installiert."
}

cmd_device_launch() {
    local id; id=$(require_device) || return 1
    local bundle; bundle=$(plutil -extract CFBundleIdentifier raw "$(device_app_path)/Info.plist")
    # `| tail -3` lieferte den Rückgabewert von tail, nie den von devicectl —
    # der Fehlerzweig war damit unerreichbar (#144-Abnahme, 2026-09-28).
    $DEVICECTL device process launch --terminate-existing --device "$id" "$bundle" 2>&1 | tail -3
    [ "${PIPESTATUS[0]}" -eq 0 ] || {
        error "Start abgelehnt — meist ist das iPhone gesperrt. Entsperren, dann erneut."
        return 1
    }
    success "Gestartet ($bundle)."
}

cmd_device() { cmd_device_build && cmd_device_install && cmd_device_launch; }

# Live-Logausgabe vom echten Gerät: das, was bei einem TestFlight-Build fehlt.
cmd_device_console() {
    local seconds="${1:-30}"
    cmd_device_build && cmd_device_install || return 1
    local id; id=$(require_device) || return 1
    local bundle; bundle=$(plutil -extract CFBundleIdentifier raw "$(device_app_path)/Info.plist")
    info "Starte mit Konsole, lese ${seconds}s mit"
    timeout "$seconds" $DEVICECTL device process launch \
        --terminate-existing --console --device "$id" "$bundle" 2>&1
    # 124 heißt: timeout hat die Konsole planmäßig beendet — das ist der Normalfall.
    # Jeder andere Wert ist ein abgelehnter Start und darf nicht als Erfolg durchgehen.
    local rc=$?
    case "$rc" in
        0|124) success "Konsole beendet." ;;
        *) error "Start mit Konsole fehlgeschlagen (devicectl $rc) — iPhone entsperren und ins selbe WLAN holen."; return 1 ;;
    esac
}

# --- Messreihen gegen das echte Modell ----------------------------------------
# Gemessen wird in der Labor-App auf dem iPhone, nicht in einem Testlauf: ein Testlauf belegt
# das Gerät am Stück und entsperrt, bis er fertig ist. Henning benutzt sein iPhone den ganzen
# Tag. Die Labor-App misst in Scheiben, sichert nach jedem Satz und macht später weiter.
LAB_SCHEME="LooseEndsLab"
LAB_BUNDLE="com.henning.looseends.lab"
LAB_RESULTS="Measurement/results"

cmd_lab() {
    local id; id=$(require_device) || return 1
    ensure_project
    signed_build "$id" "$LAB_SCHEME" || { error "Labor-App nicht gebaut"; return 1; }
    local app="$(device_derived_data)/Build/Products/Debug-iphoneos/LooseEndsLab.app"
    [ -d "$app" ] || { error "Labor-App nicht gebaut"; return 1; }
    $DEVICECTL device install app --device "$id" "$app" >/dev/null
    success "Labor-App installiert."
}

# Holt die Ergebnisdatei aus dem App-Container. Braucht nur, dass das iPhone im WLAN ist:
# kein Kabel, kein Xcode, kein Handgriff.
cmd_lab_fetch() {
    local id; id=$(require_device) || return 1
    local name="${1:-date-title}"
    mkdir -p "$PROJECT_DIR/$LAB_RESULTS"
    info "Hole $name.json vom iPhone"
    if ! $DEVICECTL device copy from --device "$id" --user mobile \
            --domain-type appDataContainer --domain-identifier "$LAB_BUNDLE" \
            --source "Documents/$name.json" \
            --destination "$PROJECT_DIR/$LAB_RESULTS/$name.json" 2>&1 | tail -3; then
        warn "Nichts abzuholen - die Labor-App hat noch nicht gemessen."
        return 1
    fi
    python3 "$PROJECT_DIR/scripts/measurement-summary.py" "$PROJECT_DIR/$LAB_RESULTS/$name.json" || true
    success "Ergebnisse in $LAB_RESULTS/$name.json"
}

# Startet den Messlauf vom Mac aus, für den Nachweis: das iPhone muss entsperrt sein und bleibt
# es während der Messung (die App hält den Bildschirm wach). Start und Stopp stehen Mac-seitig
# im Protokoll, damit ein Fehlversuch in der Ergebnisdatei gegen den Ablauf hier abgeglichen
# werden kann statt geraten. Nach Ablauf wird die App beendet; jeder Satz ist bis dahin gesichert.
cmd_lab_run() {
    local id; id=$(require_device) || return 1
    local seconds="${1:-40}"
    command -v timeout >/dev/null || { error "timeout fehlt: brew install coreutils"; return 1; }
    mkdir -p "$PROJECT_DIR/$LAB_RESULTS"
    local log="$PROJECT_DIR/$LAB_RESULTS/lab-run.log"
    echo "$(date '+%Y-%m-%dT%H:%M:%S%z') start  --measure, ${seconds}s geplant" >> "$log"
    info "Messlauf auf dem iPhone, ${seconds}s"
    # Der Ausgang steht im Protokoll, wie er war — nicht, wie er sein sollte: 124 heißt, die Zeit
    # lief ab und das Signal ging an die App (devicectl reicht es weiter); 0 heißt, die App hat
    # sich vorher selbst beendet; alles andere ist ein Fehler des Starts oder der Verbindung.
    # `set -e` würde die Funktion bei einem Fehlschlag des Starts sofort verlassen, bevor der
    # Ausgang im Protokoll steht — deshalb der Status über `&& … ||`.
    local out status=0
    out=$(timeout "$seconds" $DEVICECTL device process launch --terminate-existing --console \
        --device "$id" "$LAB_BUNDLE" --measure 2>&1) || status=$?
    local stamp; stamp=$(date '+%Y-%m-%dT%H:%M:%S%z')
    if echo "$out" | grep -q "BSErrorCodeDescription = Locked"; then
        echo "$stamp abort  iPhone gesperrt, App nicht gestartet" >> "$log"
        warn "iPhone ist gesperrt - der Messlauf kann nur bei entsperrtem Gerät starten."
        return 1
    fi
    case "$status" in
        124) echo "$stamp stop   Zeit abgelaufen, App per Signal beendet" >> "$log" ;;
        0)   echo "$stamp ended  App hat sich selbst beendet: $(echo "$out" | tail -1)" >> "$log" ;;
        *)   echo "$stamp error  devicectl Exit $status: $(echo "$out" | tail -1)" >> "$log"
             error "Start fehlgeschlagen (Exit $status)"; echo "$out" | tail -5; return 1 ;;
    esac
    cmd_lab_fetch
}

cmd_report() {
    ensure_project
    info "Bericht aus den geholten Ergebnissen"
    cmd_unit "DateTitleReportTests"
    success "Bericht in docs/reference/."
}

cmd_screenshot() {
    local out="${1:-/tmp/sim_screenshot.png}"; local id; id=$(sim_id)
    rm -f "$out"; $SIMCTL io "$id" screenshot "$out" 2>/dev/null
    [ -f "$out" ] && success "Screenshot: $out" || { error "Screenshot fehlgeschlagen"; return 1; }
}

cmd_help() { sed -n '3,34p' "$0" | sed 's/^# \{0,1\}//'; }

COMMAND="${1:-help}"; shift 2>/dev/null || true
case "$COMMAND" in
    generate)   cmd_generate ;;
    unit)       cmd_unit "$@" ;;
    real-model) cmd_real_model ;;
    build)      cmd_build ;;
    mac-build)  cmd_mac_build ;;
    mac-schema-init) cmd_mac_schema_init ;;
    mac)        cmd_mac ;;
    sim-unit)   cmd_sim_unit "$@" ;;
    test)       cmd_test "$@" ;;
    test-proof) cmd_test_proof "$@" ;;
    watch-test-proof) cmd_watch_test_proof "$@" ;;
    boot)       cmd_boot ;;
    status)     cmd_status ;;
    launch)     cmd_launch "$@" ;;
    screenshot) cmd_screenshot "$@" ;;
    device-status)  cmd_device_status ;;
    device-build)   cmd_device_build ;;
    device-build-release) cmd_device_build_release ;;
    launch-measure) cmd_launch_measure "$@" ;;
    device-install) cmd_device_install ;;
    device-launch)  cmd_device_launch ;;
    device-console) cmd_device_console "$@" ;;
    device)         cmd_device ;;
    lab)            cmd_lab ;;
    lab-run)        cmd_lab_run "$@" ;;
    lab-fetch)      cmd_lab_fetch "$@" ;;
    report)         cmd_report ;;
    help|--help|-h) cmd_help ;;
    *) error "Unbekannter Befehl: $COMMAND"; cmd_help; exit 1 ;;
esac
