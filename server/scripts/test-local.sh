#!/usr/bin/env bash
# Typecheck and tests against a throwaway Postgres (own data folder, free port, TCP only), always cleaned up (#613).
set -euo pipefail

export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
server_dir="$(cd "$(dirname "$0")/.." && pwd)"
data_dir="$(mktemp -d)"
port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"

cleanup() {
  pg_ctl -D "$data_dir/pg" -m fast stop >/dev/null 2>&1 || true
  rm -rf "$data_dir"
}
trap cleanup EXIT

initdb -D "$data_dir/pg" -U postgres -A trust >"$data_dir/initdb.log"
# No Unix socket: a temp path is too long for one (103 bytes at most).
pg_ctl -D "$data_dir/pg" -l "$data_dir/postgres.log" \
  -o "-p $port -c unix_socket_directories= -c listen_addresses=127.0.0.1" -w start >/dev/null
echo "Postgres on 127.0.0.1:$port, data in $data_dir"

export DATABASE_URL="postgres://postgres@127.0.0.1:$port/postgres"
cd "$server_dir"
[ -d node_modules ] || npm ci
npm run typecheck
npm test
