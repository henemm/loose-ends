# Context: #516 Schnitt 2 — Warteliste für die Testsperre

## Request Summary

Wer zuerst auf die rechnerweite Testsperre `/tmp/loose-ends-testlauf.lock` wartet, soll sie zuerst bekommen. Heute
fragen alle Wartenden im eigenen Takt per `mkdir` nach (sim.sh alle 5 s, Handskripte alle 30 s); wer nach der Freigabe
zufällig zuerst fragt, gewinnt. #399 wartete am 2026-10-17 deshalb Stunden hinter später Gekommenen (Ticket-Kommentar).
Mitzunehmen aus Schnitt 1 (Kommentar an #516 nach PR #571): F001 TERM/EXIT-Trap für die Wächter-Subshell, F003 Test der
KILL-Eskalation (`trap '' TERM` im Stub).

## Related Files

| File | Relevance |
|------|-----------|
| `scripts/sim.sh` Z. 74–177 | `proc_start`, `lock_is_stale`, `acquire_testlock` (Warteschleife `until mkdir … && claim_testlock`), `claim_testlock`, `take_over_stale_lock` (unter `<Sperre>.takeover`), `release_testlock`, `trap release_testlock EXIT` |
| `scripts/sim.sh` Z. 226–267 | `run_xcodebuild` mit Stille-Wächter (Subshell mit `trap … TERM`), Ziel von F001 |
| `scripts/sim.sh` Z. 307–544 | Aufrufer `acquire_testlock "<befehl>"`: unit, real-model, build, mac-build, sim-unit, test, test-proof, launch |
| `scripts/test_sim_lock.py` | Sperrtests; zieht `LOCK_FUNCTIONS` wörtlich aus sim.sh (neue Hilfsfunktionen dort ergänzen); `LockHarness` mit `LOOSEENDS_LOCK_DIR` im Temp-Ordner |
| `scripts/test_sim_run_xcodebuild.py` | Wächtertests (`RunXcodebuildSilenceGuardTests`), Ziel für F001/F003 |
| `scripts/test_sim_proof.py` Z. 120 | setzt `LOOSEENDS_LOCK_DIR` auf Temp, muss grün bleiben |
| `CLAUDE.md` Absatz „Parallele Sitzungen“ | beschreibt Warten/Übernahme; Warteliste ergänzen |

## Existing Patterns

- Zeitgrenzen als Umgebungsvariablen mit Vorgabe: `LOOSEENDS_LOCK_MAX` (1800), `LOOSEENDS_LOCK_REPORT` (30),
  `LOOSEENDS_LOCK_POLL` (5), `LOOSEENDS_LOCK_HAND_GRACE` (1800), `LOOSEENDS_SILENCE_MAX`/`_POLL`.
- Atomare Operationen über `mkdir` (Sperre, `.takeover`) und `mv` (pid-Datei erst vollständig schreiben, dann
  hineinschieben; Freigabe per `mv` nach `.done.$$.$RANDOM`).
- Lebendigkeit eines Halters: PID lebt UND Prozessstart ≤ `start=` (PID-Wiederverwendung), `proc_start` locale-frei.
- Reentrant: Halter-PID = `$$` oder `LOOSEENDS_LOCK_OWNER` (Kind des Halters).
- Tests ziehen Funktionen wörtlich per Regex `^name() {…^}` aus sim.sh.

## Dependencies

- Upstream: `mkdir`, `mv`, `ps -o lstart`, `stat -f %m` (BSD), `date -j`.
- Downstream: alle sim.sh-Befehle oben; andere Sitzungen mit älterem sim.sh-Stand (Worktrees, die main noch nicht
  nachgezogen haben) und Handskripte, die nur `mkdir` der Sperre kennen und die Warteliste nicht.

## Existing Specs

- `docs/specs/tooling/fix-341-testlaeufe-verlaesslich.md` — rechnerweite Sperre, Übernahme verwaister Sperren
- `docs/specs/tooling/fix-516-schnitt-1-testlauf-waechter.md` — Stille-Wächter

## Risks & Considerations

- **Mischbetrieb:** Ein Wartender mit altem sim.sh oder ein Handskript kennt die Liste nicht und kann sich beim
  Freiwerden vordrängen. Die Liste muss das vertragen (kein Verklemmen, höchstens Vordrängeln), nicht verhindern.
- **Tote Einträge:** Ein Wartender, der per KILL stirbt (kein EXIT-Trap), darf den Kopf nicht ewig blockieren —
  Lebendigkeit wie beim Halter (PID + Startzeit).
- **Atomarität der Liste:** Eine einzelne Datei `queue` braucht eine eigene Schreibsperre; Alternative: ein
  Wartemarken-Verzeichnis mit einer Datei je Wartendem, Reihenfolge über einen monotonen Namen (Zeit + PID).
- **Ort der Liste:** innerhalb des Sperrverzeichnisses geht nicht (es entsteht/verschwindet mit dem Halter) — eigener
  Pfad neben der Sperre, z. B. `<Sperre>.queue/`.
- **Reentrant-Aufrufe** dürfen sich nicht anstellen (Kind des Halters würde sonst hinter sich selbst warten).
- **Abbruch nach `LOOSEENDS_LOCK_MAX`** muss den eigenen Eintrag entfernen.
- **Bestehende Tests** (`test_parallel_takeover_of_orphan_lock`, 8 Wartende × 10 Runden) müssen grün bleiben.
- F001: `trap` in der Wächter-Subshell nur für TERM; ein TERM an sim.sh selbst erreicht die Subshell nicht — sie
  läuft bis zur Frist weiter (und könnte dann einen späteren Lauf derselben Sitzung beenden).
