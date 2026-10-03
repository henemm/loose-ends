# #184 Ausgangsmessung ohne Fix

Lauf: https://github.com/henemm/loose-ends/actions/runs/37126655235 (Commit 87d6162, Speech Stress, CaptureCancelCrashTests × 10, Rechte vor jedem Lauf zurückgesetzt)

```
run 1: passed (250 s)
run 2: passed (85 s)
run 3: passed (129 s)
run 4: passed (101 s)
run 5: passed (102 s)
run 6: passed (63 s)
run 7: passed (55 s)
run 8: passed (76 s)
run 9: passed (54 s)
run 10: passed (59 s)
passed 10, failed 0 of 10
```

Der Absturz aus CI-Lauf 37120830321 (SIGABRT in AVAudioEngine.inputNode nach Audio-RPC-Zeitüberschreitung, erster App-Start dort 56 s) trat in 10 Läufen nicht auf. Er ist selten und an einen langsamen Runner gebunden; ein grüner Vergleichslauf beweist deshalb nur, dass der Fix nichts verschlechtert.
