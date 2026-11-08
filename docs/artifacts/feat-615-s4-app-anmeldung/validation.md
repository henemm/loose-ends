# Validation Report: feat-615-s4-app-anmeldung (Schnitt 4a, Sitzungsablauf)

Datum: 2026-11-08. Basis: Merge-Base `472ac7edaffc87c5c890b59237de2b0b5a1a6568`.

## Test Results
- `./server/scripts/test-local.sh`: Exit 0, typecheck ok, node:test tests 387, pass 387, fail 0, skipped 0, todo 0; Wegwerf-Postgres aufgeräumt.
- Die sieben Tests „sitzungsablauf: …“ (AC-1 bis AC-7) grün.

## Spec Compliance
- AC-1 bis AC-10: 10/10 erfüllt.
- SQL `server/src/accounts.ts:83`: `last_used_at > now() - make_interval(days => $2)`, `$2 = SESSION_IDLE_DAYS = 90`; `endSession` unverändert.

## AC-8 Beleg (`git diff --numstat` gegen Basis, `server/test/`)
```
89	2	server/test/accounts.test.ts
```
Die zwei gelöschten Zeilen sind die beiden festen Zeitpunkte `'2026-01-01…'` im Test „AC-4/AC-5: resolveSession finds a valid session …“ (jetzt `now() - interval '10 days'` bzw. `> now() - interval '1 minute'`).

## AC-10 Beleg
`git diff --name-only <Basis> HEAD -- . ':!docs' ':!.claude'`:
```
CLAUDE.md
server/src/accounts.ts
server/test/accounts.test.ts
```
Funktionslängen `server/src/accounts.ts`: findOrCreate 7, admit 9, admitFirst 25, allowedSubsFromEnv 7, createSession 5, resolveSession 8, endSession 5, deleteAccount 33 (alle ≤ 50).
`grep -n SESSION_IDLE_DAYS CLAUDE.md`: genau ein Treffer (Zeile 497, `server/`-Absatz zu `src/accounts.ts`).

## Regression Check
- Keine Regressionen (alle 387 Tests grün, Migrationen unberührt, `auth.ts` unberührt).

## Scope Check
- Files changed: 3 (Limit 5)
- LoC changed: +96/−5 (Limit 250)
- Out-of-scope changes: keine

## Result: PASS
