#!/usr/bin/env bash
# AC-11 (#615 S4d): real delete against a throwaway Postgres 18 and a local service, always cleaned up.
set -euo pipefail
export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
server_dir="$1"
data_dir="$(mktemp -d)"
free_port() { python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'; }
pg_port="$(free_port)"; svc_port="$(free_port)"
svc_pid=""
cleanup() {
  [ -n "$svc_pid" ] && kill "$svc_pid" 2>/dev/null || true
  pg_ctl -D "$data_dir/pg" -m fast stop >/dev/null 2>&1 || true
  rm -rf "$data_dir"
}
trap cleanup EXIT

initdb -D "$data_dir/pg" -U postgres -A trust >"$data_dir/initdb.log"
pg_ctl -D "$data_dir/pg" -l "$data_dir/postgres.log" \
  -o "-p $pg_port -c unix_socket_directories= -c listen_addresses=127.0.0.1" -w start >/dev/null
db="postgres://postgres@127.0.0.1:$pg_port/postgres"
echo "Postgres 18 Wegwerf auf 127.0.0.1:$pg_port, $(postgres --version)"

cd "$server_dir"
env -i PATH="$PATH" HOME="$HOME" DATABASE_URL="$db" PORT="$svc_port" HOST=127.0.0.1 npm start >"$data_dir/svc.log" 2>&1 &
svc_pid=$!
for _ in $(seq 1 60); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$svc_port/health" || true)" = "200" ] && break
  sleep 0.5
done
echo "Dienst auf 127.0.0.1:$svc_port, /health $(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$svc_port/health")"

read -r account token < <(DATABASE_URL="$db" node --input-type=module -e '
import pg from "pg";
import { findOrCreate, createSession } from "./src/accounts.ts";
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const id = await findOrCreate(pool, "lokal-wegwerf-sub");
console.log(id, await createSession(pool, id));
await pool.end();')

count() { psql "$db" -tAc "SELECT (SELECT count(*) FROM accounts WHERE id='$account') || ' ' || (SELECT count(*) FROM sessions WHERE account_id='$account')"; }
echo "Vorher accounts/sessions für das Konto: $(count)"
echo "1. POST /auth/delete mit Bearer: $(curl -s -o /dev/null -w '%{http_code}' -X POST -H "authorization: Bearer $token" "http://127.0.0.1:$svc_port/auth/delete")"
echo "Nachher accounts/sessions für das Konto: $(count)"
echo "2. POST /auth/delete mit demselben Bearer: $(curl -s -o /dev/null -w '%{http_code}' -X POST -H "authorization: Bearer $token" "http://127.0.0.1:$svc_port/auth/delete")"
echo "Dienst-Log:"; sed 's/^/  /' "$data_dir/svc.log"
