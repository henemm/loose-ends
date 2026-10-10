#!/bin/bash
# Messreihe #279 A: übersetzt zerlegung.swift und fährt alle Varianten. Aufruf: run.sh [öffnungen]
set -e
cd "$(dirname "$0")"
bin="${TMPDIR:-/tmp}/zerlegung-279a"
swiftc -O -parse-as-library -o "$bin" zerlegung.swift 2>&1 | grep error || true
[ -f satz.aiff ] || say -v Anna -o satz.aiff "Morgen um zehn Uhr den Zahnarzt anrufen [[slnc 700]] und danach Milch, Brot und Kaffee einkaufen [[slnc 500]] nicht vergessen"
n="${1:-2}"
for v in app prep keep direct prog fin dict dictff; do
  LOG=1 "$bin" satz.aiff "$v" "$n" | grep -v "Text:"
done
for s in 1.3 1.6; do
  SIL=$s LOG=1 "$bin" satz.aiff app 1 | grep -v "Text:" | sed "s/^/SIL=$s /"
done
