# Speech Stress nach dem Nachtrag (Commit bfa0618) — Belege AC-9, AC-15, AC-16

## Lauf 37434224227 (pull_request, 10 Durchläufe) — success, 08:09:19–08:24:38 (15,3 Min.)

```
run 1: passed (91 s)
run 2: passed (140 s)
run 3: passed (42 s)
run 4: passed (38 s)
run 5: passed (37 s)
run 6: passed (41 s)
run 7: passed (38 s)
run 8: passed (42 s)
run 9: passed (53 s)
run 10: passed (56 s)
passed 10, failed 0 of 10
```

## Lauf 37434224929 (workflow_dispatch, Iterations 3) — success, 08:09:19–08:21:30 (12,2 Min.)

```
run 1: passed (96 s)
run 2: passed (69 s)
run 3: passed (118 s)
passed 3, failed 0 of 3
```

## Gegenprobe über alle 13 `run-*.log`

`grep -lE "Timed out after 600|Recognize speech via Apple|Computed hit point \{-1, -1\}"` → keine Datei.

- AC-15: jeder Durchlauf 37–140 s (< 300 s), keine 600-s-Diagnose.
- AC-16: 10/10 grün, kein Zustimmungsdialog, kein ins Leere gegangener Tipp.
- AC-9: `workflow_dispatch` mit Iterations 3 grün.

## Vorher (ohne Nachtrag, Commit c293275)

- Lauf 37415827670: 712 / 703 / 680 s, `passed 2, failed 1 of 3` (Dialog schluckte den Abbrechen-Tipp in Durchlauf 1).
- Lauf 37415824453 (10 Durchläufe): nach 75 Min. Zeitgrenze abgebrochen.
- Zum Vergleich auf `macos-26`: Lauf 37297700749, 30/30 grün, 53–216 s je Durchlauf.
