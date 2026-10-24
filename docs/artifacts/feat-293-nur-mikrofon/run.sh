#!/bin/bash
# Fährt den Versuch #293 auf dem Mac: 1) nie gefragt → transkribieren, 2) einmal fragen (Henning: „Nicht erlauben“),
# 3) abgelehnt → transkribieren. Nur nach Hennings „jetzt ist ein Test möglich“. Räumt das Recht danach ab.
set -euo pipefail
app="$1"
box="$HOME/Library/Containers/com.henning.speechprobe293/Data"
tccutil reset SpeechRecognition com.henning.speechprobe293 || true
for mode in transcribe deny transcribe-denied; do
  arg="${mode%-denied}"
  open -W -n "$app" --args "$arg"
  echo "== $mode"; cat "$box/result-$arg.txt"; echo
  cp "$box/result-$arg.txt" "$(dirname "$0")/result-$mode.txt"
done
tccutil reset SpeechRecognition com.henning.speechprobe293 || true
