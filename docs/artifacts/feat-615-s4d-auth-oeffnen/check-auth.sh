#!/usr/bin/env bash
# Prüfung von außen für #615 S4d: /auth/apple, /auth/logout und /auth/delete sind offen und weisen ohne gültige
# Anmeldung richtig ab, der Rest unter /auth/ bleibt 404. Nur lesend (curl), ohne Geheimnisse, ohne gültige Sitzung.
# Höchstens 8 Anfragen, keine Schleife über Wiederholungen: fail2ban sperrt nach 10 Limit-Treffern die Adresse 1 h.
# Ausgabe zeilenweise OK/FEHLT mit Statuscode; Exit 0 nur, wenn alles OK und kein 429 kam.
# BASE überschreibt die Adresse (Standard https://loose-ends.henemm.com).
set -u
BASE="${BASE:-https://loose-ends.henemm.com}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILED=0
SENT=0
SAW_429=0

# fetch <method> <path> [curl-Argumente…]: Status nach stdout; zählt jede Anfrage
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

# Körper über 16 KiB (17 KiB), gültiges JSON
BIG="$TMP/big.json"
{ printf '{"identityToken":"'; head -c 17408 /dev/zero | tr '\0' 'a'; printf '"}'; } > "$BIG"

check 405 "GET /auth/apple"                     GET  /auth/apple
check 405 "GET /auth/logout"                    GET  /auth/logout
check 405 "GET /auth/delete"                    GET  /auth/delete
check 415 "POST /auth/apple ohne JSON-Kopf"     POST /auth/apple  -H 'content-type: text/plain' --data 'x'
check 401 "POST /auth/delete ohne Bearer"       POST /auth/delete
check 401 "POST /auth/delete mit falschem Bearer" POST /auth/delete -H 'authorization: Bearer s4d-gibt-es-nicht'
check 404 "GET /auth/x"                         GET  /auth/x
check 413 "POST /auth/apple mit 17-KiB-Körper"  POST /auth/apple  -H 'content-type: application/json' --data-binary "@$BIG"

[ "$SAW_429" = 1 ] && { echo "FEHLT 429 gesehen (Limit getroffen)"; FAILED=1; }
echo "Anfragen gesendet: $SENT (höchstens 8), 429 gesehen: $([ "$SAW_429" = 1 ] && echo ja || echo nein)"
echo "Stand: $(date -u +%Y-%m-%dT%H:%M:%SZ) gegen $BASE"
exit "$FAILED"
