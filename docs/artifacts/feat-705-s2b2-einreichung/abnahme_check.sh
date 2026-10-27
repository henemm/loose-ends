#!/usr/bin/env bash
# Abnahmeprüfung #705 Schnitt 2b-2a (Datenschutzseite). Kein Projekttest (Spec: „Kein neuer automatischer Test“),
# sondern der wiederholbare Beleg für AC-2/3/4 (live), AC-5 (Variable) und AC-8 (Doku). RED vor, GREEN nach der Umsetzung.
set -u
URL="https://www.henemm.com/legal/loose-ends/privacy-policy/"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
fail=0
check() { if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi; }

html="$(curl -sL -w '\n%{http_code}' "$URL")"
code="${html##*$'\n'}"
body="${html%$'\n'*}"
check "AC-4 HTTP 200 ($code)" '[ "$code" = "200" ]'
for s in "HENEMM GmbH" "Eichenaue 14" "48157 Münster" "Henning Emmrich" "henning@henemm.com" "/footer-information/imprint/" "Mikrofon" "Apple Intelligence"; do
  check "AC-2/3 enthält „${s}“" 'grep -qF "$s" <<<"$body"'
done
check "AC-3 keine Code-Belege" '! grep -qE "project\.yml|xcprivacy|\.swift|#[0-9]{3}" <<<"$(sed -e "s/<[^>]*>//g" -e "s/&#[0-9]*;//g" <<<"$body")"'

var="$(gh variable get ASC_PRIVACY_POLICY_URL --repo henemm/loose-ends 2>/dev/null)"
check "AC-5 Variable = URL" '[ "$var" = "$URL" ]'

for f in docs/reference/datenschutz-entwurf.md docs/reference/testflight.md; do
  check "AC-8 $f nennt legal/loose-ends" 'grep -q "legal/loose-ends" "$ROOT/$f"'
done
check "AC-8 Entwurf nennt HENEMM GmbH" 'grep -q "HENEMM GmbH" "$ROOT/docs/reference/datenschutz-entwurf.md"'

[ "$fail" = 0 ] && echo "ERGEBNIS: GRÜN" || echo "ERGEBNIS: ROT"
exit "$fail"
