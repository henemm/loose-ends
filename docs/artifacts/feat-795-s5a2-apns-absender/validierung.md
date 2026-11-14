# Validierung #795 S5a-2a — APNs-Absender (2026-11-14)

## Tests

- `./server/scripts/test-local.sh` (Regressionslauf): EXIT=0, 433 bestanden, 0 fehlgeschlagen, 0 übersprungen
  (origin/main: 418; +15 aus `server/test/apns.test.ts`). Typecheck grün.
- Zweiter Lauf, gleichzeitig mit dem ersten: 432/433, rot war `migrate.test.ts` „AC-3: after a failed run the lock is free“
  (`lockIsFree` = false). Bekannt und unabhängig von diesem Schnitt: #869 (lokal zeitabhängig, CI grün); `migrate.ts` und
  `migrate.test.ts` sind unverändert.
- Keine bestehende Testdatei verändert; `devices.ts` nur ergänzt (+12, −0).

## AC-13 — nichts verdrahtet

```
$ grep -il apns server/src/*.ts
server/src/apns.ts
$ grep -l './apns' server/src/*.ts
(keine Ausgabe, exit 1)
```

## AC-14 — Dateigrenze und Funktionslängen

```
$ git diff --name-only origin/main -- . ':!docs' ':!.claude'
server/src/apns.ts
server/src/devices.ts
server/test/apns.test.ts
```

(CLAUDE.md kommt mit der Doku-Aktualisierung dieser Phase hinzu, erlaubt laut AC-14.)
Produktcode +140 LoC (apns.ts 128, devices.ts 12), Tests +236. Längste Funktion: `createWaker` (apns.ts Z. 88–128, 41 Zeilen),
dann `sendHttp2` (26). `mcp.ts`, `main.ts`, `orders.ts`, `app-routes.ts`, `.github/`, `project.yml`, `server/package.json`,
Swift unverändert.

## Abgleich AC-1 bis AC-12

Jeder AC hat seinen benannten Test in `server/test/apns.test.ts`; Abgleich Code gegen Spec ohne Befund. Hinweis aus dem
Abgleich: AC-2 prüft je eine fehlende Variable (wie in der Spec „je eine fehlt“), nicht mehrere zugleich.

Ergebnis: PASS. Kein Pfad der Geräteliste berührt.
