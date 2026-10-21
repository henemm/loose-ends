#!/bin/bash
# Prepares a fresh iOS simulator for UI tests (#341, #578). One script for `sim.sh boot` and CI.
#   scripts/sim_prepare.sh <udid> [bundle-id]   (bundle id defaults to com.henning.looseends)
# - Keyboard hint "Speed up your typing…" off: on a fresh simulator it covers the keyboard for ~50 s.
# - Calendar access granted in advance: under iOS 27 the interruption monitor does not reliably catch
#   the system dialog, and a dialog left standing fails every following test (#578).
# Every failure ends with exit != 0 and names the command; nothing is swallowed.
set -euo pipefail

udid="${1:-}"
bundle="${2:-com.henning.looseends}"
[ -n "$udid" ] || { echo "Usage: scripts/sim_prepare.sh <udid> [bundle-id]" >&2; exit 2; }

xcrun simctl spawn "$udid" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true \
    || { echo "sim_prepare: 'defaults write DidShowContinuousPathIntroduction' failed ($udid)" >&2; exit 1; }
xcrun simctl privacy "$udid" grant calendar "$bundle" \
    || { echo "sim_prepare: 'simctl privacy grant calendar $bundle' failed ($udid)" >&2; exit 1; }

echo "Simulator prepared: keyboard hint off, calendar access granted for $bundle ($udid)"
