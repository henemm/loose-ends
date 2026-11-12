#!/usr/bin/env bash
# Prüfung von außen für #795 S1b: /app/transcript, /app/orders/claim und /app/orders/result sind offen und weisen ohne
# gültige Sitzung richtig ab, der Rest unter /app/ bleibt 404. Nur curl, ohne Geheimnisse, ohne Authorization-Kopf.
# Genau 8 Anfragen, keine Schleife über Wiederholungen: fail2ban sperrt nach 10 Limit-Treffern die Adresse 1 h.
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

# Körper über 256 KiB (300 KiB), gültiges JSON
BIG="$TMP/big.json"
{ printf '{"x":"'; head -c 307200 /dev/zero | tr '\0' 'a'; printf '"}'; } > "$BIG"

check 401 "POST /app/transcript ohne Bearer"      POST /app/transcript
check 401 "POST /app/orders/claim ohne Bearer"    POST /app/orders/claim
check 401 "POST /app/orders/result ohne Bearer"   POST /app/orders/result
check 405 "GET /app/transcript"                   GET  /app/transcript
check 405 "GET /app/orders/claim"                 GET  /app/orders/claim
check 405 "GET /app/orders/result"                GET  /app/orders/result
check 404 "GET /app/x"                            GET  /app/x
check 413 "POST /app/transcript mit 300-KiB-Körper, ohne Bearer, daher von nginx" \
  POST /app/transcript -H 'content-type: application/json' --data-binary "@$BIG"

[ "$SAW_429" = 1 ] && { echo "FEHLT 429 gesehen (Limit getroffen)"; FAILED=1; }
echo "Anfragen gesendet: $SENT (genau 8), 429 gesehen: $([ "$SAW_429" = 1 ] && echo ja || echo nein)"
echo "Stand: $(date -u +%Y-%m-%dT%H:%M:%SZ) gegen $BASE"
exit "$FAILED"
