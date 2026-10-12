#!/bin/bash
# Usage: run.sh <file> <mode> <variants...>  — eine Zeile je angebrochener Sekunde mit Ergebnis
cd "$(dirname "$0")"
f=$1; m=$2; shift 2
for v in "$@"; do
  echo "== $v ($m)"
  V=$v LOG=1 ./probe "$f" "$m" 1 | awk '/^  \+/{split($1,a,"+"); b=int(a[2]); if(!(b in s)){s[b]=1; print substr($0,1,90)}} / run /{print substr($0,1,110)}'
done
