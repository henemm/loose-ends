# GREEN-Stand #960 (2026-11-19)

- `npm run typecheck`: grün. `npm test`: 485 Tests, 484 grün, 1 rot.
- Alle 13 apns-Tests grün (`test-green-output.txt`), darunter alle neuen RED-Tests.
- Rot nur `migrate.test.ts` „AC-3: after a failed run the lock is free …“ (`lockIsFree` > 5 s).
  Ursache unabhängig von #960: alle Testdateien teilen eine Datenbank (`test/db.ts`, je Test ein Schema),
  das Advisory-Lock `MIGRATE_LOCK_ID` gilt datenbankweit, parallele `migrate`-Aufrufe anderer Dateien halten es.
- Gegenprobe: derselbe Test ist auf `origin/main` (ohne #960) lokal ebenso rot (5720 ms),
  `main-baseline-output.txt` (die übrigen 4 Fehlschläge dort fehlen nur, weil das Archiv ohne CLAUDE.md/Doku lief).
- 4 Läufe auf diesem Rechner, Last von 157 bis 7: immer rot; in der Server-CI zuletzt grün.
- Nachtrag: migrate-Test auf eigene Wegwerf-Datenbank (#963), danach 3 Läufe hintereinander 485/485 grün; test-green-output.txt ist der letzte.
