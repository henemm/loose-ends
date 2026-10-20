---
entity_id: fix-516-schnitt-2-warteliste
type: bugfix
created: 2026-10-19
updated: 2026-10-19
status: draft
workflow: fix-516-schnitt-2-warteliste
---

# Spec: #516 Schnitt 2 — Warteliste für die rechnerweite Testsperre

## Approval

- [ ] Approved

## Purpose

Wer zuerst auf die rechnerweite Testsperre `/tmp/loose-ends-testlauf.lock` wartet, soll sie zuerst bekommen. Dazu kommen
zwei Funde aus Schnitt 1 (Kommentar an #516 nach PR #571): F001 (die Wächter-Subshell darf ihre sim.sh nicht überleben) und
F003 (die KILL-Eskalation des Wächters ist ungetestet).

**Hat es bisher funktioniert?** Vor #341 gab es keine rechnerweite Sperre, also keine Konkurrenz um sie. Seit #341/#413
ist sie da, aber unfair: #399 wartete am 2026-10-17 stundenlang hinter später Gekommenen.

**Ursache (belegt):** Die Warteschleife `until mkdir "$dir" … && claim_testlock` in `acquire_testlock` (`scripts/sim.sh`
Z. 107–137) hat keine Reihenfolge. Jeder Wartende fragt im eigenen Takt nach (sim.sh alle 5 s per `LOOSEENDS_LOCK_POLL`,
Handskripte alle 30 s); wer nach der Freigabe zufällig zuerst fragt, gewinnt. `mkdir` ist atomar, aber nicht fair
([BashFAQ/045](https://mywiki.wooledge.org/BashFAQ/045)). F001: Die Wächter-Subshell in `run_xcodebuild` (Z. 238–254) fragt
nicht, ob sim.sh noch lebt; stirbt sim.sh, läuft sie bis zur Frist weiter und könnte dann einen späteren Lauf derselben
Sitzung beenden (gleicher `-derivedDataPath`). F003: Kein Test erzwingt, dass ein Prozess, der TERM ignoriert, per KILL endet.

**Ohne Modell:** reine Shell-Logik, kein Sprachverstehen.

**Alternative:** Statt Wartemarken eine Sperre mit FIFO-Garantie. `flock` gibt es auf macOS nur per Homebrew (neue
Abhängigkeit) und es garantiert keine Reihenfolge; `mkfifo` braucht einen dauernd laufenden Verteiler, der bei seinem Tod
alle stehen lässt; nur das Pollintervall zu kürzen mildert, behebt nichts (Handskripte pollen weiter alle 30 s); eine laufende
Nummer per `mkdir max+1` braucht Kollisionsschleife und Reset-Fall bei gleichem Nutzen. Gewählt: Zeitstempel-Marken, ein
`mkdir`, kein Verteiler, verträgt Mischbetrieb. Eine höhere `LOOSEENDS_LOCK_MAX`-Vorgabe ändert die Geduld, nicht die
Fairness, und bleibt ein eigenes Thema. Kein ADR wird gekippt.

## Source

- **File:** `scripts/sim.sh`
- **Identifier:** `proc_start` (Z. 81), `lock_is_stale` (Z. 89), `acquire_testlock` (Z. 107), `claim_testlock` (Z. 140),
  `take_over_stale_lock` (Z. 151), `release_testlock` (Z. 169, EXIT-Trap), `run_xcodebuild` (Z. 227)

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/test_sim_lock.py` | test | Zieht Funktionen wörtlich per `LOCK_FUNCTIONS` aus `sim.sh`; neue Hilfsfunktionen dort eintragen |
| `scripts/test_sim_run_xcodebuild.py` | test | Zieht `run_xcodebuild()` wörtlich; bekommt F001/F003 |
| `scripts/test_sim_proof.py` | test | Setzt `LOOSEENDS_LOCK_DIR` auf Temp, bleibt unverändert grün |
| `CLAUDE.md` | doc | Absatz „Parallele Sitzungen“ |
| `LOOSEENDS_LOCK_MAX`, `_REPORT`, `_POLL`, `LOOSEENDS_LOCK_OWNER` | muster | Bestehende Umgebungsvariablen, unverändert |
| `mkdir`, `mv`, `ps -o lstart`, `stat -f %m`, `python3` | werkzeug | `python3 -c 'import time; …'` liefert die Nanosekunden (bash 3.2 hat kein `$EPOCHREALTIME`) |

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `scripts/sim.sh` | MODIFY | `queue_enter`, `queue_head`, `queue_leave`; `acquire_testlock` und `release_testlock` angepasst; Wächter-Ende in `run_xcodebuild` (F001) |
| `scripts/test_sim_lock.py` | MODIFY | `LOCK_FUNCTIONS` ergänzt, neue Fälle, Zusatzprüfung im Paralleltest |
| `scripts/test_sim_run_xcodebuild.py` | MODIFY | F001- und F003-Fälle |
| `CLAUDE.md` | MODIFY | Absatz „Parallele Sitzungen“: Warteliste in einem Satz |

Geschätzt ca. +180/−10 LoC, 4 Dateien. Kein Produktcode, keine Berechtigungen, keine AppStorage-Schlüssel, keine Info.plist.
**Geräteliste:** Kein Pfad der Geräteliste berührt. Nichts läuft auf Hennings Geräten. Keine sichtbare UI-Änderung.

## Definition of Done

- [ ] Wer sich zuerst anstellt, bekommt die Sperre zuerst (AC-1)
- [ ] Tote Köpfe und Abbrüche verklemmen nichts und hinterlassen keine Marke (AC-2, AC-3, AC-4)
- [ ] Reentrant und Mischbetrieb unverändert verträglich (AC-5, AC-6)
- [ ] Bestehender Paralleltest grün und `.queue` danach leer, Laufzeit unter der 30-s-Grenze (AC-7)
- [ ] F001 und F003 abgedeckt (AC-8, AC-9)
- [ ] `CLAUDE.md` ergänzt (AC-10)
- [ ] Alle Skripttests in `scripts/` grün

## Implementation Details

Wartemarken-Verzeichnis `<Sperre>.queue/` neben der Sperre (innerhalb der Sperre ginge nicht: sie entsteht und verschwindet
mit dem Halter). Es wird **nie** entfernt, sonst droht ein ENOENT-Rennen.

1. **`queue_enter`:** Marke `<Sperre>.queue/<time_ns, 20-stellig>-<pid>` per einem `mkdir`; darin `pid` mit `pid=`/`start=`
   wie in `claim_testlock` (erst schreiben, dann `mv`). Der Name sortiert lexikografisch gleich Ankunftsreihenfolge. Die
   Marke steht in der globalen Variable `QUEUE_MARK`.
2. **`queue_head`:** Gibt die Kopfmarke aus (kleinster Name). Lebendigkeit wird **nur für den Kopf** geprüft (PID tot, oder
   `proc_start` jünger als `start=`; Marke ohne pid-Datei und älter als 10 s gilt als tot); ein toter Kopf wird gelöscht,
   der Nächste rückt nach. Keine `ps`-Aufrufe für den Rest der Liste.
3. **`acquire_testlock`:** Reentrant (Halter `$$` oder `LOOSEENDS_LOCK_OWNER`) kehrt wie heute vor dem Anstellen zurück.
   Sonst `queue_enter`; die Schleife versucht `mkdir` der Sperre nur, wenn die eigene Marke der Kopf ist. Eine verwaiste
   Sperre übernimmt weiterhin jeder Wartende (`take_over_stale_lock`). Bei Erfolg und bei Abbruch nach `LOOSEENDS_LOCK_MAX`
   (weiter ab Wartebeginn gezählt) `queue_leave`; die Abbruchmeldung nennt den Platz in der Liste.
4. **`queue_leave`:** Löscht die eigene Marke, falls vorhanden; `release_testlock` (EXIT-Trap) ruft sie ebenfalls auf, damit
   auch ein per TERM/INT beendeter Wartender keine Marke zurücklässt.
5. **F001:** Die Wächter-Subshell prüft je Takt und unmittelbar vor `pgrep`/Kill `kill -0 $$` (in `( … )` ist `$$` die PID
   von sim.sh) und endet, sobald sim.sh nicht mehr lebt. **Bewusste Folge:** Stirbt sim.sh per KILL, bleibt der `xcodebuild`
   dieses Laufs als Waise stehen und hält seinen Simulator; ihn später zu beenden wäre genau die F001-Gefahr (er könnte
   schon zum nächsten Lauf gehören). Ein Waise endet mit seinem eigenen Lauf.
6. **F003:** Test mit Stub `xcodebuild` (trägt `-derivedDataPath`, sonst trifft `pgrep -f` nicht) und `trap '' TERM`.

## Test Plan

Skripttests, RED zuerst. Wie bestehend: Funktionen wörtlich aus `sim.sh`, neue (`queue_enter`, `queue_head`, `queue_leave`)
in `LOCK_FUNCTIONS` ergänzt; `LOOSEENDS_LOCK_DIR` im Temp-Ordner, kurze Takte.

| Test | Datei | Prüft |
|---|---|---|
| `test_waiters_get_lock_in_arrival_order` | `test_sim_lock.py` | drei Wartende nacheinander angestellt, Halter gibt frei: Reihenfolge der Übernahme = Reihenfolge des Anstellens (AC-1) |
| `test_dead_head_is_removed_and_next_proceeds` | `test_sim_lock.py` | Kopfmarke mit toter PID und mit PID-Wiederverwendung (`start=` älter als Prozessstart): gelöscht, Nächster bekommt die Sperre (AC-2) |
| `test_queue_mark_without_pid_file_dead_after_10s` | `test_sim_lock.py` | Marke ohne pid-Datei blockiert unter 10 s, danach tot und gelöscht (AC-2) |
| `test_abort_removes_own_mark_and_names_position` | `test_sim_lock.py` | `LOOSEENDS_LOCK_MAX=2`: Abbruch, eigene Marke weg, Meldung nennt den Platz (AC-3) |
| `test_success_and_exit_trap_remove_mark_queue_dir_stays` | `test_sim_lock.py` | nach Erfolg und nach EXIT-Trap keine Marke, `.queue` besteht weiter (AC-4) |
| `test_reentrant_does_not_enqueue` | `test_sim_lock.py` | Halter `$$` und `LOOSEENDS_LOCK_OWNER`: keine Marke entsteht (AC-5) |
| `test_mixed_mode_legacy_waiter_can_cut_in_but_nothing_deadlocks` | `test_sim_lock.py` | Teilnehmer nur mit `mkdir` der Sperre zieht an der Liste vorbei; danach bekommt der Kopf die Sperre; verwaiste Sperre übernimmt jeder Wartende (AC-6) |
| `test_parallel_takeover_of_orphan_lock` (erweitert) | `test_sim_lock.py` | bleibt grün, zusätzlich `.queue` danach leer; Laufzeit früh messen, Grenze 30 s (AC-7) |
| `test_watcher_ends_when_script_dies` | `test_sim_run_xcodebuild.py` | Rahmenskript wird mit KILL beendet: Wächter-Subshell endet binnen eines Takts, löst nicht mehr aus (AC-8) |
| `test_term_ignoring_xcodebuild_is_killed_after_grace` | `test_sim_run_xcodebuild.py` | Stub mit `trap '' TERM`: nach TERM + 5 s per KILL beendet, Dauer ≥ 5 s (AC-9) |

Zusätzlich: bestehende Fälle in `test_sim_lock.py`, `test_sim_run_xcodebuild.py`, `test_sim_proof.py` bleiben grün.

## Acceptance Criteria

- **AC-1:** Given mehrere Läufe warten auf die belegte Testsperre, When der Halter sie freigibt, Then bekommt sie der zuerst Angestellte zuerst (Marke `<Sperre>.queue/<time_ns 20-stellig>-<pid>`, nur der Kopf versucht `mkdir`).
- **AC-2:** Given der Kopf der Liste ist tot (PID tot, PID wiederverwendet mit Prozessstart jünger als `start=`, oder Marke ohne pid-Datei älter als 10 s), When ein Wartender prüft, Then wird die Marke gelöscht und der Nächste rückt nach; eine Marke ohne pid-Datei unter 10 s gilt als lebend.
- **AC-3:** Given ein Wartender erreicht `LOOSEENDS_LOCK_MAX`, When `acquire_testlock` abbricht, Then ist seine Marke entfernt und die Meldung nennt seinen Platz in der Liste.
- **AC-4:** Given ein Lauf hat die Sperre bekommen oder endet über den EXIT-Trap `release_testlock`, When er fertig ist, Then ist seine Marke entfernt und `<Sperre>.queue` selbst bleibt bestehen.
- **AC-5:** Given der Aufrufer ist Halter (`$$`) oder Kind des Halters (`LOOSEENDS_LOCK_OWNER`), When er `acquire_testlock` ruft, Then stellt er sich nicht an und kehrt sofort zurück.
- **AC-6:** Given ein Teilnehmer ohne Liste (nur `mkdir` der Sperre) drängelt sich vor, When die Sperre frei wird, Then verklemmt nichts: der Kopf wartet weiter und bekommt sie danach; eine verwaiste Sperre übernimmt weiterhin jeder Wartende.
- **AC-7:** Given 8 Wartende × 10 Runden um eine verwaiste Sperre, When `test_parallel_takeover_of_orphan_lock` läuft, Then ist er grün, `<Sperre>.queue` danach leer, und die Laufzeit bleibt unter der 30-s-Grenze.
- **AC-8:** Given sim.sh stirbt (auch per KILL) während der Wächter läuft, When der nächste Takt oder die Frist kommt, Then endet die Wächter-Subshell (`kill -0 $$` je Takt und vor `pgrep`/Kill) und beendet keinen Prozess mehr; der `xcodebuild` einer per KILL gestorbenen sim.sh bleibt dabei bewusst als Waise bestehen.
- **AC-9:** Given ein `xcodebuild` mit `-derivedDataPath` dieser Sitzung ignoriert TERM, When der Wächter auslöst, Then wird er nach TERM + 5 s per KILL beendet (Test mit Stub `trap '' TERM`).
- **AC-10:** Given `CLAUDE.md`, Absatz „Parallele Sitzungen“, When die Warteliste eingebaut ist, Then nennt er sie in einem Satz (wer zuerst wartet, bekommt die Sperre zuerst; Marke in `<Sperre>.queue`; Handskripte ohne Liste können vordrängeln).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reine Werkzeugänderung ohne Architekturwirkung auf das Produkt; keine bestehende Entscheidung wird gekippt.

## Risiken

- **Verklemmen:** zentrale Sperre aller Testläufe, Risiko MEDIUM. Abgesichert durch Mischbetrieb-Regel (kein Teilnehmer muss die Liste kennen), tote Köpfe werden gelöscht, `.queue` wird nie entfernt.
- **Uhr zurückgestellt:** Zeitstempel-Marken sind dann kurz unfair, nie verklemmend.
- **Paralleltest wird seriell:** geschätzt 2–3 s je Runde, Grenze 30 s; früh messen, sonst Takt im Test verkürzen.
- **Waise nach KILL (F001):** bewusst hingenommen, siehe Implementation Details 5.

## Changelog

- 2026-10-19: Spec erstellt (Schnitt 2 von #516: Warteliste, F001, F003).
