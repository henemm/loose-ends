#!/usr/bin/env bash
# GREEN-Lauf #705 Schnitt 2b-2a: Abnahmeprüfung (AC-2..5, AC-8) plus alle Skripttests (AC-10).
cd "$(dirname "$0")/../../.." || exit 1
"docs/artifacts/feat-705-s2b2-einreichung/abnahme_check.sh"
check=$?
echo "--- Skripttests (AC-10)"
fail=0
for t in scripts/test_*.py; do
  out="$(python3 "$t" 2>&1)"; rc=$?
  echo "$t: rc=$rc $(tail -1 <<<"$out")"
  [ "$rc" = 0 ] || fail=1
done
echo "abnahme=$check skripttests_fail=$fail"
[ "$check" = 0 ] && [ "$fail" = 0 ]
