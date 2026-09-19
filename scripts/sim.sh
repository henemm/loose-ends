#!/bin/bash
#
# sim.sh — Build- und Test-Toolkit für Loose Ends
#
# EINE Anlaufstelle für Build, Tests, Simulator. Die Workflow-Hooks blocken
# direktes xcodebuild/simctl, damit alle Sessions denselben, gelockten Weg gehen.
#
# Usage:
#   ./scripts/sim.sh generate                 # Xcode-Projekt aus project.yml erzeugen
#   ./scripts/sim.sh unit [Suite[/test]]      # Unit-Tests, macOS-Destination (schnell, kein Simulator)
#   ./scripts/sim.sh build                    # iOS-App für den Simulator bauen
#   ./scripts/sim.sh mac-build                # macOS-App bauen
#   ./scripts/sim.sh sim-unit [Suite[/test]]  # Unit-Tests im iOS-Simulator
#   ./scripts/sim.sh test <Class[/test]>      # UI-Test im iOS-Simulator
#   ./scripts/sim.sh boot | status | launch | screenshot [pfad]
#
# Auf Hennings echtem iPhone — Stufe 2, erst nachdem der Simulator grün war:
#   ./scripts/sim.sh device-status            # verbundenes Gerät und Verbindungsweg zeigen
#   ./scripts/sim.sh device                   # signiert bauen, drahtlos installieren, starten
#   ./scripts/sim.sh device-console [sek]     # dasselbe, aber Logausgabe live mitlesen (Vorgabe 30 s)
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
SIMCTL="xcrun simctl"
DEVICECTL="xcrun devicectl"
TEAM_ID="${LOOSEENDS_TEAM_ID:-XK87E2B3VR}"
DEVICE_DERIVED_DATA=""  # wird in device_derived_data() gesetzt
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
SESSION_DERIVED_DATA="$DERIVED_DATA/LooseEnds-session-${SESSION_ID}"
LOCK_DIR="$PROJECT_DIR/.claude/sim_lock.d"
LOCK_ACQUIRED=""

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${BLUE}[sim]${NC} $1" >&2; }
success() { echo -e "${GREEN}[sim]${NC} $1" >&2; }
warn()    { echo -e "${YELLOW}[sim]${NC} $1" >&2; }
error()   { echo -e "${RED}[sim]${NC} $1" >&2; }

# --- Simulator-Lock (mkdir ist atomar), serialisiert Sessions ---
acquire_lock() {
    local waited=0
    # Frische Worktrees haben kein .claude/, sonst scheitert mkdir bis zum Timeout.
    mkdir -p "$(dirname "$LOCK_DIR")"
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        if [ -f "$LOCK_DIR/info" ]; then
            local t; t=$(head -1 "$LOCK_DIR/info" 2>/dev/null || echo 0)
            if [ $(( $(date +%s) - t )) -gt 600 ]; then warn "Stale Lock entfernt"; rm -rf "$LOCK_DIR"; continue; fi
        fi
        [ $waited -ge 300 ] && { error "Simulator-Lock Timeout"; return 1; }
        sleep 5; waited=$((waited + 5))
    done
    mkdir -p "$(dirname "$LOCK_DIR")"
    date +%s > "$LOCK_DIR/info"; echo "$SESSION_ID" >> "$LOCK_DIR/info"; LOCK_ACQUIRED=1
}
release_lock() { [ -n "$LOCK_ACQUIRED" ] && rm -rf "$LOCK_DIR" 2>/dev/null; LOCK_ACQUIRED=""; return 0; }
trap release_lock EXIT

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
    m = re.search(r"SimRuntime\.iOS-([\d-]+)$", runtime)
    if not m: continue
    v = ver(m.group(1).replace("-", "."))
    if v < floor: continue
    cands += [(v, d) for d in devs]
if not cands: sys.exit(0)
hit = next((d for _, d in cands if d["name"] == name), None)
if hit is None:
    pool = [c for c in cands if c[1]["name"].startswith("iPhone")] or cands
    hit = max(pool, key=lambda c: c[0])[1]
print(hit["udid"])' "$SIM_NAME" "$(deployment_target iOS)"
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

run_xcodebuild() {
    cd "$PROJECT_DIR"
    if command -v xcbeautify >/dev/null; then
        xcodebuild "$@" -derivedDataPath "$SESSION_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO 2>&1 | xcbeautify
    else
        xcodebuild "$@" -derivedDataPath "$SESSION_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO 2>&1
    fi
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

cmd_unit() {
    ensure_project
    local only="$UNIT_TARGET"; [ -n "${1:-}" ] && only="$UNIT_TARGET/$1"
    if ! mac_hosts_tests; then
        warn "macOS $(sw_vers -productVersion) < Deployment Target $(deployment_target macOS) — Unit-Tests laufen im Simulator."
        cmd_sim_unit "$@"
        return
    fi
    info "Unit-Tests (macOS): $only"
    run_xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination 'platform=macOS' -only-testing:"$only" -parallel-testing-enabled NO
    success "Unit-Tests bestanden."
}

cmd_build() {
    ensure_project
    local id; id=$(sim_id); [ -z "$id" ] && { error "Kein Simulator '$SIM_NAME' gefunden"; return 1; }
    info "iOS-Build für $SIM_NAME ($id), DerivedData ${SESSION_ID:0:8}"
    run_xcodebuild build -project "$PROJECT" -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$id"
    success "Build erfolgreich."
}

cmd_mac_build() {
    ensure_project
    info "macOS-Build"
    run_xcodebuild build -project "$PROJECT" -scheme "$SCHEME" -destination 'platform=macOS'
    success "macOS-Build erfolgreich."
}

cmd_boot() {
    local id; id=$(sim_id); [ -z "$id" ] && { error "Kein Simulator '$SIM_NAME'"; return 1; }
    open -a Simulator --args -CurrentDeviceUDID "$id" 2>/dev/null || true
    $SIMCTL boot "$id" 2>/dev/null || true
    $SIMCTL bootstatus "$id" -b >/dev/null 2>&1 || true
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
    ensure_project; acquire_lock; cmd_boot
    local id; id=$(sim_id)
    local only="$UNIT_TARGET"; [ -n "${1:-}" ] && only="$UNIT_TARGET/$1"
    info "Unit-Tests (iOS-Simulator): $only"
    run_xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$id" -only-testing:"$only" -parallel-testing-enabled NO
    release_lock; success "Unit-Tests bestanden."
}

cmd_test() {
    [ -z "${1:-}" ] && { error "Usage: ./scripts/sim.sh test Class[/test]"; return 1; }
    ensure_project; acquire_lock; cmd_boot
    local id; id=$(sim_id)
    info "UI-Test: $1"
    run_xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$id" -only-testing:"$UI_TARGET/$1" -parallel-testing-enabled NO -disable-concurrent-destination-testing
    release_lock; success "UI-Test bestanden."
}

cmd_launch() {
    acquire_lock; cmd_boot
    local id; id=$(sim_id)
    local app="$SESSION_DERIVED_DATA/Build/Products/Debug-iphonesimulator/LooseEnds.app"
    [ -d "$app" ] || { error "Erst bauen: ./scripts/sim.sh build"; return 1; }
    local bundle; bundle=$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")
    $SIMCTL terminate "$id" "$bundle" 2>/dev/null || true
    $SIMCTL install "$id" "$app"
    $SIMCTL launch "$id" "$bundle" "$@"
    release_lock; success "App gestartet ($bundle)."
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

device_derived_data() { echo "$DERIVED_DATA/LooseEnds-device-${SESSION_ID}"; }

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

cmd_device_build() {
    ensure_project
    local id; id=$(require_device) || return 1
    local dd; dd=$(device_derived_data)
    info "Signierter Build für das Gerät ($id), Team $TEAM_ID"
    cd "$PROJECT_DIR"
    local args=(build -project "$PROJECT" -scheme "$SCHEME" -destination "id=$id"
                -derivedDataPath "$dd" -allowProvisioningUpdates "DEVELOPMENT_TEAM=$TEAM_ID")
    if command -v xcbeautify >/dev/null; then
        xcodebuild "${args[@]}" 2>&1 | xcbeautify
    else
        xcodebuild "${args[@]}" 2>&1
    fi
    success "Gerätebuild erfolgreich."
}

device_app_path() { echo "$(device_derived_data)/Build/Products/Debug-iphoneos/LooseEnds.app"; }

# Installieren geht auch bei gesperrtem iPhone; Starten braucht ein entsperrtes.
cmd_device_install() {
    local id; id=$(require_device) || return 1
    local app; app=$(device_app_path)
    [ -d "$app" ] || { error "Erst bauen: ./scripts/sim.sh device-build"; return 1; }
    info "Installiere drahtlos auf $id"
    $DEVICECTL device install app --device "$id" "$app" >/dev/null
    success "Installiert."
}

cmd_device_launch() {
    local id; id=$(require_device) || return 1
    local bundle; bundle=$(plutil -extract CFBundleIdentifier raw "$(device_app_path)/Info.plist")
    if ! $DEVICECTL device process launch --terminate-existing --device "$id" "$bundle" 2>&1 | tail -3; then
        error "Start abgelehnt — meist ist das iPhone gesperrt. Entsperren, dann erneut."
        return 1
    fi
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
        --terminate-existing --console --device "$id" "$bundle" 2>&1 || true
    success "Konsole beendet."
}

cmd_screenshot() {
    local out="${1:-/tmp/sim_screenshot.png}"; local id; id=$(sim_id)
    rm -f "$out"; $SIMCTL io "$id" screenshot "$out" 2>/dev/null
    [ -f "$out" ] && success "Screenshot: $out" || { error "Screenshot fehlgeschlagen"; return 1; }
}

cmd_help() { sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'; }

COMMAND="${1:-help}"; shift 2>/dev/null || true
case "$COMMAND" in
    generate)   cmd_generate ;;
    unit)       cmd_unit "$@" ;;
    build)      cmd_build ;;
    mac-build)  cmd_mac_build ;;
    sim-unit)   cmd_sim_unit "$@" ;;
    test)       cmd_test "$@" ;;
    boot)       cmd_boot ;;
    status)     cmd_status ;;
    launch)     cmd_launch "$@" ;;
    screenshot) cmd_screenshot "$@" ;;
    device-status)  cmd_device_status ;;
    device-build)   cmd_device_build ;;
    device-install) cmd_device_install ;;
    device-launch)  cmd_device_launch ;;
    device-console) cmd_device_console "$@" ;;
    device)         cmd_device ;;
    help|--help|-h) cmd_help ;;
    *) error "Unbekannter Befehl: $COMMAND"; cmd_help; exit 1 ;;
esac
