#!/usr/bin/env bash
# Prüfung von außen für #795 S5b: /app/device ist offen und weist ohne gültige Sitzung richtig ab, der Rest unter /app/
# bleibt 404, die Nachbarn sind unverändert. Nur curl, ohne Geheimnisse, ohne Authorization-Kopf.
# Genau 6 Anfragen, keine Schleife über Wiederholungen: fail2ban sperrt nach 10 Limit-Treffern die Adresse 1 h.
# Ausgabe zeilenweise OK/FEHLT mit Statuscode; Exit 0 nur, wenn alles OK und kein 429 kam.
# BASE überschreibt die Adresse (Standard https://loose-ends.henemm.com).
set -u
BASE="${BASE:-https://loose-ends.henemm.com}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILED=0
SENT=0
SAW_429=0

# fetch <method> <path> [curl-Argumente…]: Status nach stdout
fetch() {
  local method="$1" path="$2"; shift 2
  curl -sS --max-time 15 -X "$method" -o /dev/null -w '%{http_code}' "$@" "$BASE$path" 2>/dev/null || echo 000
}
check() { # check <soll> <text> <method> <path> [curl-Argumente…]
  local want="$1" text="$2"; shift 2
  local s; s=$(fetch "$@"); SENT=$((SENT + 1))
  [ "$s" = 429 ] && SAW_429=1
  if [ "$s" = "$want" ]; then echo "OK    $s $text (soll $want)"; else echo "FEHLT $s $text (soll $want)"; FAILED=1; fi
}

# Körper über 16 KiB (20 KiB), gültiges JSON
BIG="$TMP/big.json"
{ printf '{"x":"'; head -c 20480 /dev/zero | tr '\0' 'a'; printf '"}'; } > "$BIG"

check 401 "POST /app/device ohne Bearer"         POST /app/device
check 405 "GET /app/device"                      GET  /app/device
check 413 "POST /app/device mit 20-KiB-Körper, ohne Bearer, daher von nginx" \
  POST /app/device -H 'content-type: application/json' --data-binary "@$BIG"
check 404 "GET /app/x"                           GET  /app/x
check 401 "POST /app/transcript ohne Bearer"     POST /app/transcript
check 405 "GET /app/orders/claim"                GET  /app/orders/claim

[ "$SAW_429" = 1 ] && { echo "FEHLT 429 gesehen (Limit getroffen)"; FAILED=1; }
echo "Anfragen gesendet: $SENT (genau 6), 429 gesehen: $([ "$SAW_429" = 1 ] && echo ja || echo nein)"
echo "Stand: $(date -u +%Y-%m-%dT%H:%M:%SZ) gegen $BASE"
exit "$FAILED"
