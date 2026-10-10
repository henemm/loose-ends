#!/bin/bash
# Endtext je Modul (#279 A): gleicher Satz, SpeechTranscriber (App) gegen DictationTranscriber. Erst run.sh laufen lassen.
cd "$(dirname "$0")"
bin="${TMPDIR:-/tmp}/zerlegung-279a"
for f in satz.aiff "$@"; do
  for v in app dict dictff; do
    LOG=1 "$bin" "$f" "$v" 1 | grep "Text:" | sed "s/^/$f $v /"
  done
done
