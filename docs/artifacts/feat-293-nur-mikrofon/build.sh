#!/bin/bash
# Baut SpeechProbe293.app (ad-hoc signiert, Sandbox wie die App, eigene Kennung) nach $1. Startet nichts.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$1"
app="$out/SpeechProbe293.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -parse-as-library -O "$here/probe.swift" -o "$app/Contents/MacOS/SpeechProbe293"
say -v Anna "Morgen früh beim Bäcker Brot kaufen" -o "$app/Contents/Resources/satz.aiff"
cp "$here/Info.plist" "$app/Contents/Info.plist"
codesign --force -s - --entitlements "$here/probe.entitlements" "$app"
echo "$app"
