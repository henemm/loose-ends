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
# Simulator per Name: LOOSEENDS_SIM="iPhone 17 Pro" ./scripts/sim.sh build

set -eo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT="LooseEnds.xcodeproj"
SCHEME="LooseEnds"
UNIT_TARGET="LooseEndsTests"
UI_TARGET="LooseEndsUITests"
SIM_NAME="${LOOSEENDS_SIM:-iPhone 17}"
SIMCTL="xcrun simctl"
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

# --- Simulator per Name auflösen (erstes verfügbares Gerät mit diesem Namen) ---
sim_id() {
    $SIMCTL list devices available -j 2>/dev/null | python3 -c '
import json, sys
name = sys.argv[1]
devs = [d for v in json.load(sys.stdin)["devices"].values() for d in v]
hit = next((d for d in devs if d["name"] == name), None) or next((d for d in devs if d["name"].startswith("iPhone")), None)
print(hit["udid"] if hit else "")' "$SIM_NAME"
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

cmd_unit() {
    ensure_project
    local only="$UNIT_TARGET"; [ -n "${1:-}" ] && only="$UNIT_TARGET/$1"
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

cmd_screenshot() {
    local out="${1:-/tmp/sim_screenshot.png}"; local id; id=$(sim_id)
    rm -f "$out"; $SIMCTL io "$id" screenshot "$out" 2>/dev/null
    [ -f "$out" ] && success "Screenshot: $out" || { error "Screenshot fehlgeschlagen"; return 1; }
}

cmd_help() { sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'; }

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
    help|--help|-h) cmd_help ;;
    *) error "Unbekannter Befehl: $COMMAND"; cmd_help; exit 1 ;;
esac
