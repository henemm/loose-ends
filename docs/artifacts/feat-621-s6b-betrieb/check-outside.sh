#!/usr/bin/env bash
# Prüfung von außen für #621 S6b: was claude.ai erreichen muss, ist offen, alles andere bleibt 404.
# Nur lesend (curl, jq), ohne Geheimnisse. Ausgabe zeilenweise OK/FEHLT mit Statuscode; Exit 0 nur, wenn alles OK.
# BASE überschreibt die Adresse (Standard https://loose-ends.henemm.com).
set -u
BASE="${BASE:-https://loose-ends.henemm.com}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILED=0

# fetch <method> <path>: Status nach stdout, Kopf und Körper nach $TMP/head, $TMP/body
fetch() {
  curl -sS --max-time 15 -X "$1" -D "$TMP/head" -o "$TMP/body" -w '%{http_code}' "$BASE$2" 2>/dev/null || echo 000
}
line() { # line <ok?> <status> <text>
  if [ "$1" = 1 ]; then echo "OK    $2 $3"; else echo "FEHLT $2 $3"; FAILED=1; fi
}
json_is() { jq -e --arg v "$2" "$1 == \$v" "$TMP/body" >/dev/null 2>&1 && echo 1 || echo 0; }

s=$(fetch GET /health); line "$([ "$s" = 200 ] && echo 1 || echo 0)" "$s" "GET /health (soll 200)"

s=$(fetch GET /.well-known/oauth-authorization-server)
ok=0; [ "$s" = 200 ] && [ "$(json_is .issuer "$BASE")" = 1 ] && ok=1
line "$ok" "$s" "GET /.well-known/oauth-authorization-server (soll 200, issuer $BASE)"
ok=0; [ "$s" = 200 ] && jq -e '.client_id_metadata_document_supported == true' "$TMP/body" >/dev/null 2>&1 && ok=1
line "$ok" "$s" "  client_id_metadata_document_supported (soll true)"
ok=0; [ "$s" = 200 ] && jq -e '.token_endpoint_auth_methods_supported | index("none")' "$TMP/body" >/dev/null 2>&1 && ok=1
line "$ok" "$s" "  token_endpoint_auth_methods_supported (soll none enthalten)"

s=$(fetch GET /.well-known/openid-configuration)
ok=0; [ "$s" = 200 ] && [ "$(json_is .issuer "$BASE")" = 1 ] && ok=1
line "$ok" "$s" "GET /.well-known/openid-configuration (soll 200, issuer $BASE)"

s=$(fetch GET /.well-known/oauth-protected-resource/mcp)
ok=0; [ "$s" = 200 ] && [ "$(json_is .resource "$BASE/mcp")" = 1 ] && ok=1
line "$ok" "$s" "GET /.well-known/oauth-protected-resource/mcp (soll 200, resource $BASE/mcp)"

s=$(fetch POST /mcp)
ok=0; [ "$s" = 401 ] && grep -iq "^www-authenticate:.*resource_metadata=\"$BASE/.well-known/oauth-protected-resource/mcp\"" "$TMP/head" && ok=1
line "$ok" "$s" "POST /mcp ohne Token (soll 401, WWW-Authenticate mit resource_metadata)"

s=$(fetch GET /oauth/gibt-es-nicht)
ok=0; case "$s" in 000|502|503|504) ;; *) grep -q '<center>nginx</center>' "$TMP/body" || ok=1 ;; esac
line "$ok" "$s" "GET /oauth/gibt-es-nicht (soll Dienstantwort, keine nginx-Seite, kein 502/504)"

for req in "GET /auth/apple" "POST /auth/apple" "POST /auth/delete" "GET /"; do
  s=$(fetch ${req% *} "${req#* }"); line "$([ "$s" = 404 ] && echo 1 || echo 0)" "$s" "$req (soll 404)"
done

echo "Stand: $(date -u +%Y-%m-%dT%H:%M:%SZ) gegen $BASE"
exit "$FAILED"
