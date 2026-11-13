# Vorab: SIGINT an ein Bash-Skript im Hintergrund (2026-11-13, Spec S3b-2)

Frage: Greift ein `trap … INT` in einem Skript, das aus einer nicht interaktiven Bash mit `&` gestartet wird?

Wegwerfskript `t.sh`:

```bash
#!/bin/bash
trap 'echo cleanup-ran; exit 0' INT TERM
while true; do /bin/sleep 0.2; done
```

Probe (macOS, `/bin/bash`):

```bash
echo "--- mit set -m"
set -m
./t.sh > m.log & p=$!
/bin/sleep 2; kill -INT $p; wait $p; echo "exit=$?"; cat m.log
set +m

echo "--- ohne set -m"
./t.sh > n.log & p=$!
/bin/sleep 0.5; kill -INT $p; /bin/sleep 0.6
if kill -0 $p 2>/dev/null; then echo "still-running nach INT"; kill -TERM $p; fi
wait $p; cat n.log
```

Ausgabe:

```
--- mit set -m
exit=0
cleanup-ran
--- ohne set -m
still-running nach INT
cleanup-ran
```

Befund: Ohne Job-Steuerung startet der Hintergrundjob mit ignoriertem SIGINT, der Trap greift nicht (erst SIGTERM beendet ihn).
Mit `set -m` greift der Trap bei SIGINT. Ein erster Lauf mit 0,5 s Wartezeit unter `set -m` endete mit 130 ohne Trap: Das Signal
kam, bevor das Skript den Trap gesetzt hatte. Darum setzt `local-service.sh` die Traps als erste Anweisung, und der Selbsttest
signalisiert erst nach der Zeile `STATE=`.
