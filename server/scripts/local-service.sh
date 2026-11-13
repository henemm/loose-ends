#!/usr/bin/env bash
# The service for the simulator against a throwaway Postgres (#795 S3b-2): own data folder, free port, TCP only,
# service on 127.0.0.1 without Apple and OAuth. Writes <tmp>/state.env, prints STATE=<path>, runs until a signal.
# Only for the simulator against this throwaway database: never pass a token of the live service as a launch argument.
set -euo pipefail
trap 'exit 130' INT
trap 'exit 143' TERM
trap '[ "$(type -t cleanup)" = function ] && cleanup' EXIT

cleanup() {
  if [ -n "${service_pid:-}" ]; then
    kill "$service_pid" 2>/dev/null || true
    wait "$service_pid" 2>/dev/null || true
  fi
  [ -d "${work_dir:-}/pg" ] && { pg_ctl -D "$work_dir/pg" -m fast stop >/dev/null 2>&1 || true; }
  [ -n "${work_dir:-}" ] && rm -rf "$work_dir"
  return 0
}

export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
command -v pg_ctl >/dev/null || { echo "local-service: Postgres 18 fehlt (brew install postgresql@18)" >&2; exit 1; }
command -v node >/dev/null || { echo "local-service: Node fehlt" >&2; exit 1; }
server_dir="$(cd "$(dirname "$0")/.." && pwd)"
free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'; }
work_dir="$(mktemp -d)"
pg_port="$(free_port)"
service_port="${LOCAL_SERVICE_PORT:-$(free_port)}"

cd "$server_dir"
[ -d node_modules ] || npm ci

initdb -D "$work_dir/pg" -U postgres -A trust >"$work_dir/initdb.log"
# No Unix socket: a temp path is too long for one (103 bytes at most).
pg_ctl -D "$work_dir/pg" -l "$work_dir/postgres.log" \
  -o "-p $pg_port -c unix_socket_directories= -c listen_addresses=127.0.0.1" -w start >/dev/null
echo "Postgres on 127.0.0.1:$pg_port, data in $work_dir"

database_url="postgres://postgres@127.0.0.1:$pg_port/postgres"
# Nothing inherited may configure the service otherwise: no Apple, no OAuth, no admission list, no public address.
for name in $(compgen -e | grep '^APPLE_' || true); do unset "$name"; done
unset OAUTH_COOKIE_KEYS OAUTH_SIGNING_JWK ALLOWED_APPLE_SUBS PUBLIC_URL
DATABASE_URL="$database_url" HOST=127.0.0.1 PORT="$service_port" node src/main.ts >"$work_dir/service.log" 2>&1 &
service_pid=$!

service_url="http://localhost:$service_port"
for _ in $(seq 1 60); do
  kill -0 "$service_pid" 2>/dev/null || break
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$service_url/health" || true)" = 200 ] && break
  sleep 0.5
done
if [ "$(curl -s -o /dev/null -w '%{http_code}' "$service_url/health" || true)" != 200 ]; then
  echo "local-service: Dienst nicht gesund auf $service_url, letzte Logzeilen:" >&2
  tail -n 20 "$work_dir/service.log" >&2
  exit 1
fi

session_token="$(DATABASE_URL="$database_url" node scripts/local-fixture.ts session)"
printf 'DATABASE_URL=%s\nPORT=%s\nSERVICE_URL=%s\nSESSION_TOKEN=%s\n' \
  "$database_url" "$service_port" "$service_url" "$session_token" >"$work_dir/state.env"
echo "Dienst auf $service_url (pid $service_pid)"
echo "STATE=$work_dir/state.env"
wait "$service_pid"
