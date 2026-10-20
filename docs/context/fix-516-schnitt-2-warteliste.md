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

## Analysis

### Type
Bug (Werkzeug): Die Testsperre ist unfair — wer zuerst wartet, bekommt sie nicht zuerst (#399, 2026-10-17).

### Recherche
- `mkdir` ist atomar, aber ohne Reihenfolge: wer nach der Freigabe zuerst fragt, gewinnt
  ([BashFAQ/045](https://mywiki.wooledge.org/BashFAQ/045), [mkdir-Locking](https://tobrunet.ch/easy-bash-script-locking-with-mkdir)).
- macOS hat kein `flock`-Kommando (nur `flock(2)`, `shlock`); `flock` aus Homebrew wäre eine neue Abhängigkeit und
  garantiert ohnehin keine FIFO-Reihenfolge ([flock(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/flock.2.html), [brew flock](https://formulae.brew.sh/formula/flock)).
- FIFO per `mkfifo` braucht einen dauerhaft laufenden Verteiler-Prozess — stirbt er, steht alles; für Sitzungen, die
  einander nicht kennen, zu zerbrechlich.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/sim.sh` | MODIFY | `queue_enter`/`queue_head`/`queue_leave`; `acquire_testlock`: nur der Kopf der Liste versucht `mkdir`; `release_testlock` löscht die eigene Marke; Wächter in `run_xcodebuild` endet, wenn sim.sh nicht mehr lebt (F001) |
| `scripts/test_sim_lock.py` | MODIFY | `LOCK_FUNCTIONS` ergänzen; Tests: Reihenfolge, toter Kopf, Marke ohne pid-Datei, Abbruch räumt Marke, reentrant stellt sich nicht an, `.queue` nach Paralleltest leer |
| `scripts/test_sim_run_xcodebuild.py` | MODIFY | F003: Stub mit `trap '' TERM` wird per KILL beendet; F001: Wächter endet mit sim.sh |
| `CLAUDE.md` | MODIFY | Absatz „Parallele Sitzungen“: Warteliste in einem Satz |

### Scope Assessment
- Files: 4 (+ Spec)
- Estimated LoC: ca. +180/−10
- Risk Level: MEDIUM — zentrale Sperre aller Testläufe; Fehler hieße Verklemmen. Abgesichert durch Mischbetrieb-Regel
  (kein Teilnehmer muss die Liste kennen) und den bestehenden Paralleltest.

### Technical Approach (Empfehlung)
Wartemarken-Verzeichnis `<Sperre>.queue/` neben der Sperre, wird **nie** entfernt (sonst ENOENT-Rennen).
- **Anstellen:** Marke `<time_ns, 20-stellig>-<pid>` per einem `mkdir` (Zeit aus `python3 -c 'import time; …'`;
  bash 3.2 hat kein `$EPOCHREALTIME`). Darin `pid` mit `pid=`/`start=` wie `claim_testlock` (erst schreiben, dann `mv`).
  Name sortiert lexikografisch = Ankunftsreihenfolge; keine Nummernvergabe, kein Zähler-Reset.
- **Warten:** Jeder darf weiter eine verwaiste Sperre übernehmen (wie heute). `mkdir` der Sperre versucht nur, wessen
  Marke die kleinste lebende ist. Lebendigkeit wird **nur für die Kopfmarke** geprüft (PID tot oder jünger als `start`;
  ohne pid-Datei älter als 10 s = tot) und tote Köpfe gelöscht — sonst Dutzende `ps`-Aufrufe je Takt.
- **Verlassen:** Marke in globaler `QUEUE_MARK`; `acquire_testlock` löscht sie bei Erfolg und bei Abbruch,
  `release_testlock` (EXIT-Trap) ebenfalls, falls noch vorhanden.
- **Reentrant** (Halter oder Kind des Halters) kehrt vor dem Anstellen zurück, wie heute.
- **Mischbetrieb:** Altes sim.sh und Handskripte kennen die Liste nicht und können vordrängeln; verklemmen kann
  nichts, weil der Kopf weiter pollt.
- **F001:** Wächter-Subshell prüft je Takt und unmittelbar vor `pgrep`/Kill `kill -0 $$` (in `( … )` ist `$$` die
  PID von sim.sh) und endet, wenn sim.sh weg ist. Folge: Stirbt sim.sh per KILL, bleibt sein xcodebuild als Waise —
  bewusst, denn ihn später zu beenden wäre genau die F001-Gefahr. Wird in der Spec benannt.
- **F003:** Stub heißt `xcodebuild`, trägt `-derivedDataPath` (sonst trifft `pgrep -f` nicht), setzt `trap '' TERM`;
  Test dauert wegen `sleep 5` mind. 5 s.
- **`LOOSEENDS_LOCK_MAX`** bleibt ab Wartebeginn (Geduld des Aufrufers, 1800 s). Die Abbruchmeldung nennt zusätzlich
  den Platz in der Liste, damit sichtbar ist, warum.

### Alternativen
| Weg | Fair? | Bewertung |
|-----|-------|-----------|
| **Zeitstempel-Marken (empfohlen)** | ja (ns, bei Uhr-Rückstellung höchstens kurz unfair) | ein `mkdir`, kein Verteiler, verträgt Mischbetrieb |
| Laufende Nummer per `mkdir max+1` | ja | Kollisionsschleife und Reset-Fall, mehr Code bei gleichem Nutzen |
| `flock` (Homebrew) / Python `fcntl` | nein, keine FIFO-Garantie | neue Abhängigkeit bzw. neues Artefakt, alte Stände kennen es nicht |
| `mkfifo` mit Verteiler-Prozess | ja | Verteiler stirbt → alle stehen; zu zerbrechlich |
| Nur Pollintervall verkürzen | nein | mildert, behebt nicht; Handskripte pollen weiter 30 s |
| Höhere `LOCK_MAX`-Vorgabe | — | verworfen fürs Erste: ändert Geduld, nicht Fairness; eigenes Thema, falls Abbrüche auftreten |

Keine ADR betroffen.

### Risiken für bestehende Tests
`test_parallel_takeover_of_orphan_lock` (8 × 10) wird strikt seriell: geschätzt 2–3 s je Runde, Grenze 30 s — früh
messen. Er bekommt die Zusatzprüfung „`.queue` leer“.

### Open Questions
- keine (reines Werkzeugthema, keine Produktfrage)
