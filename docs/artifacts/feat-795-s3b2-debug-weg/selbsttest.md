# Selbsttest local-service.sh und local-fixture.ts (#795 S3b-2, AC-9 bis AC-11)

Lauf 2026-11-13 (zweiter Lauf nach dem Unterbefehl `due`, Spec-Nachtrag 2026-11-13; ersetzt den ersten Lauf), Mac, Postgres 18 (Homebrew), Node v26.13.0. Befehlsfolge der Spec Teil 2, Schritte 0 bis 6, in einer Bash mit `set -m` (Skript im Scratch-Ordner, Ausgabe unverändert); Schritt 3 zusätzlich mit `due <taskID> <Datum>` (gibt eine UUID) und `due` ohne Datum (Ausgang 1). Die Zeile `child setpgid … Operation not permitted` in Schritt 3 ist eine Warnung der Job-Steuerung, weil die Bash ohne Terminal läuft; sie ändert nichts (der Trap lief, Ausgang 143).

## Schritt 0: Bash mit Job-Steuerung

```

$ echo "$-" | grep -q m && echo "set -m aktiv"
set -m aktiv
(Ausgang 0)

$ (cd server && npm ci --silent) >/dev/null && echo "npm ci fertig"
npm ci fertig
(Ausgang 0)

```
## Schritt 1: Start mit geerbtem APPLE_TEAM_ID

```

$ APPLE_TEAM_ID=x server/scripts/local-service.sh > /var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.UNpbwArVUS/svc-term.log 2>&1 &
pid 73442
STATE=/var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.HtqyTmZTAR/state.env
Postgres on 127.0.0.1:62365, data in /var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.HtqyTmZTAR
Dienst auf http://localhost:62366 (pid 73486)
STATE=/var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.HtqyTmZTAR/state.env

$ cut -d= -f1 "$state"
DATABASE_URL
PORT
SERVICE_URL
SESSION_TOKEN
(Ausgang 0)

$ awk -F= '{ print $1, (length(substr($0, index($0, "=") + 1)) > 0 ? "nicht leer" : "LEER") }' "$state"
DATABASE_URL nicht leer
PORT nicht leer
SERVICE_URL nicht leer
SESSION_TOKEN nicht leer
(Ausgang 0)

```
## Schritt 2: Health, /auth/apple, Bindung

```

$ curl -s -o /dev/null -w "%{http_code}\n" "$SERVICE_URL/health"
200
(Ausgang 0)

$ curl -s -o /dev/null -w "%{http_code}\n" -X POST "$SERVICE_URL/auth/apple"
503
(Ausgang 0)

$ lsof -nP -iTCP:"$PORT" -sTCP:LISTEN
COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    73486  hem   12u  IPv4 0x21bafc6a69895349      0t0  TCP 127.0.0.1:62366 (LISTEN)
(Ausgang 0)

```
## Schritt 3: Abschrift und Fixture

```

$ curl -s -o /dev/null -w "%{http_code}\n" -X POST -H "Authorization: Bearer $SESSION_TOKEN" -H "Content-Type: application/json" --data "$doc" "$SERVICE_URL/app/transcript"
/private/tmp/claude-501/-Users-hem-Developer-loose-ends--claude-worktrees-cached-churning-yao/63521e8f-acae-4727-a517-0cc7339d3d12/scratchpad/selftest.sh: child setpgid (73514 to 73514): Operation not permitted
204
(Ausgang 0)

$ fx transcript
tasks=0
(Ausgang 0)

$ id=$(fx order "Selbsttest")
3bde0980-5102-4f91-bb67-e3714cfab555 (Ausgang 0)

$ fx result "$id"
waiting
(Ausgang 0)

$ fx result "$(uuidgen | tr A-Z a-z)"
unknown
(Ausgang 0)

$ fx due "$(uuidgen | tr A-Z a-z)" 2026-11-20T00:00:00Z
2a3f6d2f-dc0d-4011-a31a-8c53350f38ee
(Ausgang 0)

$ fx foo Selbsttest 2>>"$err"
(Ausgang 1)

$ fx order 2>>"$err"
(Ausgang 1)

$ fx due "$id" 2>>"$err"
(Ausgang 1)

$ env -u DATABASE_URL node server/scripts/local-fixture.ts order Selbsttest 2>>"$err"
(Ausgang 1)

$ DATABASE_URL=postgres://u@db.example:5432/x node server/scripts/local-fixture.ts order Selbsttest 2>>"$err"
(Ausgang 1)

$ cat "$err"
local-fixture: Unterbefehl: session | transcript | order <text> | result <id> | due <taskID> <datum>
local-fixture: order: Argument fehlt
local-fixture: due: Datum fehlt
local-fixture: DATABASE_URL fehlt
local-fixture: nur eine lokale Datenbank (127.0.0.1, localhost)
(Ausgang 0)

$ grep -F -- "$SESSION_TOKEN" "$err" || echo "Token nicht in stderr"
Token nicht in stderr
(Ausgang 0)

$ grep -F -- "Selbsttest" "$err" || echo "Text nicht in stderr"
Text nicht in stderr
(Ausgang 0)

```
## Schritt 4a: SIGTERM

```

$ kill -TERM 73442
Skript beendet, Ausgang 143

$ pgrep -f "$work_dir" || echo "kein Postgres dieses Laufs"
kein Postgres dieses Laufs
(Ausgang 0)

$ ps -p "$node_pid" -o pid=,command= || echo "kein Dienst (pid $node_pid)"
kein Dienst (pid 73486)
(Ausgang 0)

$ test -e "$work_dir" && echo "Temp-Ordner DA" || echo "Temp-Ordner fehlt"
Temp-Ordner fehlt
(Ausgang 0)

$ lsof -nP -iTCP:"$PORT" -sTCP:LISTEN || echo "Port $PORT frei"
Port 62366 frei
(Ausgang 0)

$ lsof -nP -iTCP:"$pg_port" -sTCP:LISTEN || echo "Port $pg_port frei"
Port 62365 frei
(Ausgang 0)

```
## Schritt 4b: Neustart und SIGINT

```

$ APPLE_TEAM_ID=x server/scripts/local-service.sh > /var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.UNpbwArVUS/svc-int.log 2>&1 &
pid 73557
STATE=/var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.u4ZILm1Qhc/state.env
Postgres on 127.0.0.1:62386, data in /var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.u4ZILm1Qhc
Dienst auf http://localhost:62387 (pid 73598)
STATE=/var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.u4ZILm1Qhc/state.env

$ cut -d= -f1 "$state"
DATABASE_URL
PORT
SERVICE_URL
SESSION_TOKEN
(Ausgang 0)

$ awk -F= '{ print $1, (length(substr($0, index($0, "=") + 1)) > 0 ? "nicht leer" : "LEER") }' "$state"
DATABASE_URL nicht leer
PORT nicht leer
SERVICE_URL nicht leer
SESSION_TOKEN nicht leer
(Ausgang 0)

$ curl -s -o /dev/null -w "%{http_code}\n" "$SERVICE_URL/health"
200
(Ausgang 0)

$ kill -INT 73557
Skript beendet, Ausgang 130

$ pgrep -f "$work_dir" || echo "kein Postgres dieses Laufs"
kein Postgres dieses Laufs
(Ausgang 0)

$ ps -p "$node_pid" -o pid=,command= || echo "kein Dienst (pid $node_pid)"
kein Dienst (pid 73598)
(Ausgang 0)

$ test -e "$work_dir" && echo "Temp-Ordner DA" || echo "Temp-Ordner fehlt"
Temp-Ordner fehlt
(Ausgang 0)

$ lsof -nP -iTCP:"$PORT" -sTCP:LISTEN || echo "Port $PORT frei"
Port 62387 frei
(Ausgang 0)

$ lsof -nP -iTCP:"$pg_port" -sTCP:LISTEN || echo "Port $pg_port frei"
Port 62386 frei
(Ausgang 0)

```
## Schritt 5: erzwungener Startfehler (belegter Port)

```

$ python3 -m http.server 62398 --bind 127.0.0.1 &

$ LOCAL_SERVICE_PORT=62398 server/scripts/local-service.sh
Ausgang 1 nach 1 s
Postgres on 127.0.0.1:62399, data in /var/folders/dk/p4qd3_xx6ls6_xybmqzfgs1h0000gn/T/tmp.LLhXSwVdsg
local-service: Dienst nicht gesund auf http://localhost:62398, letzte Logzeilen:
node:net:2390
    const ex = new UVExceptionWithHostPort(err, 'listen', address, port);
               ^

Error: listen EADDRINUSE: address already in use 127.0.0.1:62398
    at Server.setupListenHandle [as _listen2] (node:net:2390:16)
    at listenInCluster (node:net:2499:12)
    at node:net:2728:7
    at process.processTicksAndRejections (node:internal/process/task_queues:90:21) {
  code: 'EADDRINUSE',
  errno: -48,
  syscall: 'listen',
  address: '127.0.0.1',
  port: 62398
}

Node.js v26.13.0

$ pgrep -f "$work_dir" || echo "kein Postgres dieses Laufs"
kein Postgres dieses Laufs
(Ausgang 0)

$ test -e "$work_dir" && echo "Temp-Ordner DA" || echo "Temp-Ordner fehlt"
Temp-Ordner fehlt
(Ausgang 0)

$ lsof -nP -iTCP:"$p" -sTCP:LISTEN || echo "Python-Server beendet, Port $p frei"
Python-Server beendet, Port 62398 frei
(Ausgang 0)

```
## Schritt 6: server/src unverändert

```
$ git fetch -q origin main
$ git diff --stat origin/main...HEAD -- server/src/
(leer)
$ git diff --stat -- server/src/
(leer)
```

## Ergebnis

- AC-9: `/health` 200, `/auth/apple` 503 trotz geerbtem `APPLE_TEAM_ID`, Dienst lauscht nur auf `127.0.0.1`, `state.env` mit genau den vier Schlüsseln, alle nicht leer (Schritte 1–2).
- AC-10: nach SIGTERM (Ausgang 143) und SIGINT (Ausgang 130) und nach dem Startfehler mit belegtem `LOCAL_SERVICE_PORT` (Ausgang 1 nach 1 s) kein Dienst, kein Postgres, kein Temp-Ordner, Ports frei (Schritte 4–5).
- AC-11: Abschrift 204, `tasks=0`, Auftrag UUID, `waiting`, `unknown`, `due` mit Datum UUID; fünf Fehlaufrufe (darunter `due` ohne Datum: „due: Datum fehlt“) je Ausgang 1, stderr ohne Token und ohne Text; `server/src/` unverändert (Schritte 3 und 6).

## AC-16: Quellsuche in `AccountWiring.swift`

```
$ grep -n -- '-LEDebug' LooseEnds/Claude/AccountWiring.swift
56:        guard let address = value(after: "-LEDebugService"), let token = value(after: "-LEDebugSession"),
$ grep -n 'static let debugBuild = true' -B2 LooseEnds/Claude/AccountWiring.swift
22-    /// private, because it is the default argument of `serviceURL(info:allowsLocalHTTP:)`.
23-    #if DEBUG
24:    static let debugBuild = true
$ grep -n 'KeychainSessionStore' LooseEnds/Claude/AccountWiring.swift
78:        return AccountState(client: ServiceClient(baseURL: serviceURL(info: info)), store: KeychainSessionStore())
$ grep -nE 'try\?|print\(|logger\.' LooseEnds/Claude/AccountWiring.swift
(kein Treffer, Ausgang 1)
```

Zeile 56 liegt in `debugService` (Zeilen 49–63); Zeile 78 ist der bestehende Nicht-Debug-Zweig von `forApp`.
