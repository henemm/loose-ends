#!/bin/bash
# Prueft die Verzweigungen von cmd_device_test ohne echtes iPhone: Nutzungsmeldung, Sperre vorab,
# PIPESTATUS, Zeitschranke, deviceprep-Erkennung, Screenshot-Export, verwaistes Geraetelock.
#
# Was das hier NICHT beweist: das tatsaechliche Verhalten von devicectl/xcodebuild auf echter
# Hardware, den realen Inhalt der Screenshots, und ob "Enable UI Automation" gesetzt ist — das
# beweist ausschliesslich der echte Lauf auf Hennings iPhone (AC-8).
#
# Aufruf: bash scripts/tests/device-test.sh
set -uo pipefail
cd "$(dirname "$0")/../.."
FAILED=0
PASSED=0
T_FAIL=0

make_stub_dir() { mktemp -d "${TMPDIR:-/tmp}/device-test-stub.XXXXXX"; }

# xcodebuild-Stub: druckt $XCODEBUILD_STDOUT (falls gesetzt), schlaeft $XCODEBUILD_SLEEP Sekunden,
# beendet sich mit $XCODEBUILD_EXIT. Legt bei jedem Aufruf $STUB_MARKER an, damit ein Testfall
# beweisen kann, dass xcodebuild NICHT aufgerufen wurde.
write_xcodebuild_stub() {
    cat > "$1/xcodebuild" <<'STUB'
#!/bin/bash
[ -n "${STUB_MARKER:-}" ] && touch "$STUB_MARKER"
[ -n "${XCODEBUILD_STDOUT:-}" ] && echo "$XCODEBUILD_STDOUT"
[ -n "${XCODEBUILD_SLEEP:-}" ] && sleep "$XCODEBUILD_SLEEP"
exit "${XCODEBUILD_EXIT:-0}"
STUB
    chmod +x "$1/xcodebuild"
}

# xcrun-Stub: dispatcht nach devicectl (Probestart: $DEVICECTL_PROBE_LOCKED) und xcresulttool
# (Export: legt eine manifest.json im --output-path an, damit der Export-Test etwas vorfindet).
write_xcrun_stub() {
    cat > "$1/xcrun" <<'STUB'
#!/bin/bash
if [ "${1:-}" = "devicectl" ]; then
    if [ "${DEVICECTL_PROBE_LOCKED:-0}" = "1" ]; then
        echo 'BSErrorCodeDescription = Locked'; exit 3
    fi
    echo "process launched"; exit 0
elif [ "${1:-}" = "xcresulttool" ]; then
    prev=""
    for a in "$@"; do
        [ "$prev" = "--output-path" ] && mkdir -p "$a" && touch "$a/manifest.json"
        prev="$a"
    done
    exit 0
fi
exit 1
STUB
    chmod +x "$1/xcrun"
}

# T_FAIL ist der Zustand des LAUFENDEN Falls. Ohne diese Trennung wuerde ein einmal gesetztes
# globales FAILED jeden folgenden Fall als bestanden ausweisen — der Beleg wuerde luegen.
fail() { echo "  FAIL: $1"; T_FAIL=1; }

assert_contains() {
    case "$1" in
        *"$2"*) return 0 ;;
        *) fail "erwartet '$2' in der Ausgabe, bekam:"; echo "$1" | sed 's/^/        /' | tail -5; return 1 ;;
    esac
}

finish() {
    if [ "$T_FAIL" -eq 0 ]; then PASSED=$((PASSED + 1)); echo "  ok"; else FAILED=1; fi
}

# --- AC-1: ohne Argument bricht der Befehl mit Nutzungsmeldung ab, ohne ein Geraet anzusprechen ---
test_ohne_argument_nutzungsmeldung() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local marker; marker="$dir/called"
    local out
    out=$(PATH="$dir:$PATH" STUB_MARKER="$marker" LOOSEENDS_DEVICE=FAKE-0000 \
        bash scripts/sim.sh device-test 2>&1) && { fail "haette scheitern muessen"; return; }
    assert_contains "$out" "Usage: ./scripts/sim.sh device-test"
    [ -f "$marker" ] && { fail "xcodebuild ohne Argument aufgerufen"; }
    finish
}

# --- AC-2: gesperrtes Telefon wird VOR dem Bau erkannt, xcodebuild laeuft gar nicht erst an ---
test_sperrvorabpruefung_verhindert_bau() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local marker; marker="$dir/called"
    local out
    out=$(PATH="$dir:$PATH" STUB_MARKER="$marker" DEVICECTL_PROBE_LOCKED=1 LOOSEENDS_DEVICE=FAKE-0000 \
        bash scripts/sim.sh device-test SomeClass 2>&1) && { fail "haette scheitern muessen"; return; }
    assert_contains "$out" "iPhone ist gesperrt"
    [ -f "$marker" ] && { fail "xcodebuild wurde trotz Sperre aufgerufen"; }
    finish
}

# --- AC-3: der Rueckgabewert kommt aus xcodebuild, nicht aus dem letzten Glied der Pipe (#151) ---
test_pipestatus_kommt_von_xcodebuild() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local out
    out=$(PATH="$dir:$PATH" XCODEBUILD_EXIT=3 DEVICECTL_PROBE_LOCKED=0 LOOSEENDS_DEVICE=FAKE-0000 \
        bash scripts/sim.sh device-test SomeClass 2>&1) && { fail "haette scheitern muessen"; return; }
    assert_contains "$out" "xcodebuild 3"
    finish
}

# --- AC-4: ein haengendes xcodebuild wird von der Zeitschranke abgebrochen, nicht ausgesessen ---
test_zeitschranke_bricht_haengenden_bau_ab() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local start=$SECONDS out
    out=$(PATH="$dir:$PATH" XCODEBUILD_SLEEP=30 DEVICECTL_PROBE_LOCKED=0 LOOSEENDS_DEVICE=FAKE-0000 \
        LOOSEENDS_DEVICE_TEST_TIMEOUT=2 \
        bash scripts/sim.sh device-test SomeClass 2>&1) && { fail "haette scheitern muessen"; return; }
    [ $((SECONDS - start)) -le 5 ] || { fail "lief $((SECONDS - start))s, Zeitschranke war 2s"; }
    assert_contains "$out" "gesperrt"
    finish
}

# --- AC-5: Sperrung waehrend des Laufs traegt eine eigene Meldung, nicht die generische ---
test_deviceprep_code_minus3_wird_erkannt() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local out
    out=$(PATH="$dir:$PATH" DEVICECTL_PROBE_LOCKED=0 XCODEBUILD_EXIT=65 \
        XCODEBUILD_STDOUT='Error Domain=com.apple.dt.deviceprep Code=-3 "Unlock ... because the device is locked."' \
        LOOSEENDS_DEVICE=FAKE-0000 \
        bash scripts/sim.sh device-test SomeClass 2>&1) && { fail "haette scheitern muessen"; return; }
    assert_contains "$out" "gesperrt oder wurde waehrend des Laufs gesperrt"
    finish
}

# --- AC-6: ein erfolgreicher Lauf exportiert die Anhaenge in den Artefaktordner ---
test_erfolg_exportiert_screenshots() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local shots; shots=$(mktemp -d)
    PATH="$dir:$PATH" DEVICECTL_PROBE_LOCKED=0 XCODEBUILD_EXIT=0 LOOSEENDS_DEVICE=FAKE-0000 \
        LOOSEENDS_ARTIFACT_DIR="$shots" \
        bash scripts/sim.sh device-test SomeClass >/dev/null 2>&1 \
        || { fail "haette gelingen muessen"; return; }
    [ -f "$shots/screenshots/manifest.json" ] \
        || { fail "kein Export unter $shots/screenshots/"; }
    finish
}

# --- AC-7: ein verwaistes Geraetelock blockiert nicht dauerhaft und wird danach freigegeben ---
test_verwaistes_geraetelock_wird_entfernt() {
    local dir; dir=$(make_stub_dir); write_xcodebuild_stub "$dir"; write_xcrun_stub "$dir"
    local shots; shots=$(mktemp -d)
    mkdir -p .claude/device_lock.d
    echo $(( $(date +%s) - 900 )) > .claude/device_lock.d/info
    PATH="$dir:$PATH" DEVICECTL_PROBE_LOCKED=0 XCODEBUILD_EXIT=0 LOOSEENDS_DEVICE=FAKE-0000 \
        LOOSEENDS_ARTIFACT_DIR="$shots" \
        bash scripts/sim.sh device-test SomeClass >/dev/null 2>&1 \
        || { fail "verwaistes Lock hat den Lauf blockiert"; rm -rf .claude/device_lock.d; return; }
    [ -d .claude/device_lock.d ] && { fail "Lock nach dem Lauf nicht freigegeben"; rm -rf .claude/device_lock.d; }
    finish
}

for t in test_ohne_argument_nutzungsmeldung \
         test_sperrvorabpruefung_verhindert_bau \
         test_pipestatus_kommt_von_xcodebuild \
         test_zeitschranke_bricht_haengenden_bau_ab \
         test_deviceprep_code_minus3_wird_erkannt \
         test_erfolg_exportiert_screenshots \
         test_verwaistes_geraetelock_wird_entfernt; do
    echo "$t"
    T_FAIL=0
    "$t"
done

echo
if [ "$FAILED" -eq 0 ]; then
    echo "Alle 7 Verzweigungen geprueft."
else
    echo "Mindestens ein Fall gescheitert ($PASSED von 7 bestanden)."
    exit 1
fi
