# Validierung #615 S4f (2026-11-14)

## Testergebnisse
- Server (`./server/scripts/test-local.sh`): erster Lauf 421/422, rot `migrate.test.ts:216` (AC-3 Sperrtest, `lockIsFree` false),
  bekannt als #869 (dort vermerkt); drei sofortige Wiederholungen je 422/422, 0 übersprungen. Der Zweig ändert `server/src` nicht.
- Unit im Simulator (`./scripts/sim.sh unit`): Exit 0, 0 Fehler, 367 s.
- `./scripts/sim.sh test AccountSettingsTests`: 8/8, 0 übersprungen.
- `./scripts/sim.sh test AccountLocalServiceTests` ohne Variablen: 0 bestanden, 2 übersprungen (gewollt, AC-4):
  `testSignOutEndsOnlyThisSession`, `testDeleteRemovesTheAccount`. Mit Variablen grün (Protokoll A, AC-5/AC-6).
- `bash -n scripts/sim.sh` sauber; `ui_smoke_shards.py 4` teilt die neue Klasse Teil 3 zu.

## Spec-Abgleich
AC-1 bis AC-12 erfüllt (Belege `protokoll-a.md`). Nachgetragen im Protokoll: Zuordnung der umbenannten Belegdateien und
des Startbilds sowie der Stand der Läufe (Belege `head: 2b3d192`; `local-fixture.ts` und `sim.sh` vor dem ersten Lauf zuletzt
geändert, unverändert in `76e2c90` festgeschrieben).

## Umfang
3 Code-/Testdateien, 152 LoC (Limit 4–5 Dateien, ±250); `server/src`, `LooseEnds/`, `LooseEndsTests/`, `project.yml`,
`Info.plist`, Workflows, `ui_smoke_shards.py`, `AccountSettingsTests.swift` unberührt; keine Funktion über 50 Zeilen.
Doku: `CLAUDE.md`, `docs/reference/abnahme-und-arbeitsweise.md`.

## Ergebnis: PASS
Kein Pfad der Geräteliste berührt. Stufe 3 (TestFlight mit `konto=true`, Anmelden/Abmelden/wieder Anmelden) ist Teil der
Ticket-DoD, nicht dieses ACs; das Ticket bleibt bis Hennings Rückmeldung offen.
