# Context: feat-715-naechstes-ticket

## Request Summary
Die Sitzung soll nach einem fertigen Ticket selbst das nächste startbare Ticket ihres Epics vorschlagen (Begründung, Blocker, Überschneidung mit offenen Zweigen) und den Vorschlag nach `/clear` in den Kontext legen. Henning tippt nichts mehr von Hand. Geplant in zwei Schnitten: **S1** Skript `scripts/next-ticket.sh` (Teile 1, 3, 5), **S2** SessionStart-Hook (Teil 4). Teil 2 („blocked by“ eintragen) ist reine GitHub-Pflege.

## Recherche (Stand 2026-10-27, gegen die echten Schnittstellen geprüft)

| Frage | Befund | Beleg |
|---|---|---|
| Epic der Sitzung | `HERDR_WORKSPACE_ID` ist gesetzt (hier `w3`); `herdr workspace get w3` liefert JSON mit `workspace.label`. Heute steht dort **„#176 Abnahme“**, also ein *Ticket*, kein Epic (#176 gehört zu Epic #371). | echter Lauf |
| Alle Sitzungen | `herdr workspace list`: w1 „#370 Modell + Einladung“, w2 „#371 Texte für Fremde (#342)“, w3 „#176 Abnahme“, w4 „Restock“ | echter Lauf |
| Teil-Tickets | `gh api repos/henemm/loose-ends/issues/<epic>/sub_issues` geht. #371 offen: #342, #176, #40. #370 offen: #71, #88. #468 offen: #65, #66, #78. #642 und #612: keine offenen. | echter Lauf |
| Eltern-Ticket | `.../issues/<N>/parent` geht: #176 → 371. #715 → 404 (hat keinen Epic). | echter Lauf |
| „blocked by“ | REST `.../issues/<N>/dependencies/blocked_by` existiert ([GitHub-Doku](https://docs.github.com/en/rest/issues/issue-dependencies)), lesen, anlegen, entfernen. Heute: #371 → 0 Einträge, also nirgends gepflegt. | echter Lauf, Doku |
| Board | `gh project item-list 1 --owner henemm --format json` liefert je Karte `status`, `priority`, `size`, `milestone`, `linked pull requests` in Hennings Reihenfolge. Kartenkörper sind lang (Ausgabe mit `--jq` auf Felder kürzen). | echter Lauf |
| Belegung durch andere Sitzungen | `session_singleton_guard` schreibt je Sitzung `<Hauptcheckout>/.claude/session-locks/<id>.json` mit `issue`, `phase`, `branch`, `worktree`, `pid`, `last_seen`. Eine fertige Sitzung bleibt mit `phase8_complete` stehen (z. B. #705). | echter Lauf |
| Offene Zweige | `git worktree list` zeigt ~25 Worktrees, viele alt oder ohne Sitzung; „offener Zweig“ muss also über offene PRs und aktive Locks bestimmt werden, nicht über alle Worktrees. | echter Lauf |
| SessionStart heute | `~/.claude/settings.json` hat zwei SessionStart-Hooks: `loose-ends-sync-main.sh` (alle) und einen mit Matcher `^(startup|resume|clear|compact|fork)$`. Ein dritter für `startup|clear` ist dort ergänzbar. | settings.json Z. 65–77 |

## Related Files
| Datei | Relevanz |
|---|---|
| `scripts/` (neu: `next-ticket.sh`) | S1, Hauptarbeit. Muster: `sim.sh`, `sim_prepare.sh`; Tests wie `scripts/test_*.py` |
| `scripts/test_*.py` | Vorbild für den Test (Python, `test_entitlements_sync.py`) |
| `docs/reference/board.md` | Board-Zugriff, Cloud-Fall (hier nur lokal nötig) |
| `~/.claude/settings.json`, `~/.claude/scripts/` | S2: Hook liegt außerhalb des Repos |
| `~/.claude/scripts/loose-ends-sync-main.sh` | Vorbild für Aufbau, Defensivität, Projekt-Filter |
| `.../hooks/session_singleton_guard.py` | Quelle der Belegung (Plugin, nicht ändern) |
| `CLAUDE.md` (Projekt) | Abschnitt „Process“ ergänzen (Epic-Regel, Skript) |

## Existing Patterns
- Hooks defensiv: nie scheitern lassen, Projekt-Filter, Überschreibbarkeit per Umgebungsvariable (`LOOSEENDS_REPO`) für Tests.
- Priorität nach Milestone (M1=P0 … M4=P2), dann Hennings Board-Reihenfolge (Ziehen schlägt Milestone innerhalb einer Priorität).
- Bash-Guard im Worktree blockt zusammengesetzte Befehle mit `gh`/`git`, also Skript statt Einzeiler-Ketten; im Skript selbst kein Problem.

## Dependencies
- Upstream: `herdr` (Socket-API, `herdr workspace get`), `gh` (Issues, Projects, PRs), `git`, Plugin-Lockdateien.
- Downstream: `/00-intake` ohne Nummer (liest den Vorschlag), Henning (liest die Begründung), `herdr notification` bei leerem oder blockiertem Epic.

## Abweichungen vom Tickettext (für die Analyse)
1. **Der herdr-Name ist nicht verlässlich ein Epic.** Hennings Korrektur vom 2026-10-27 sagt: Name = Epic. Die Ist-Bezeichnung von w3 ist aber ein Ticket (#176). Das Skript muss beides lesen: führende `#N` → hat N Teil-Tickets, ist N der Epic; sonst `parent` von N. Ohne führende Nummer („Restock“) oder ohne Epic: kein Vorschlag, klare Meldung.
2. **#715 selbst hat keinen Epic.** Ein Skript-Lauf aus dieser Sitzung fände nichts; das ist erwartetes Verhalten, kein Fehler.
3. **Leere „blocked by“-Beziehungen heute überall.** Teil 2 ist Voraussetzung für einen aussagekräftigen echten Lauf (DoD: für #371 nicht #176, sondern #342 oder den Blocker).
4. **Belegung:** Locks fertiger Sitzungen (`phase8_complete`) dürfen kein Ticket sperren; nur lebende Sitzungen (`pid` läuft) in Phase < 8.

## Alternative (Pflicht laut Henning 2026-09-19)
- Ohne Epic-Zuordnung: jede Sitzung nimmt das oberste freie Ticket vom Board. Einfacher, kippt aber die Entscheidung vom 2026-10-26 („je Sitzung ein Epic“) und die Korrektur vom 2026-10-27.
- Ohne Hook: das Skript nur von Hand per `/00-intake` ohne Nummer aufrufen. Spart S2, aber Henning müsste wieder etwas tun.

## Rules before model
Alles regelbasiert (API, Sortierung, `git diff --name-only`). Kein Sprachmodell nötig.

## Existing Specs
Keine. `docs/specs/` hat nichts zu Sitzungswerkzeugen.

## Risks & Considerations
- **Gerätestufe:** Kein Pfad der Geräteliste berührt (kein App-Code).
- Hook außerhalb des Repos: Änderung an `~/.claude/settings.json` ist Hennings Konfiguration; ich übernehme sie selbst (Regel „Einstellungen: ich übernehme“) und baue Rückfallpfad ein (Hook darf nie eine Sitzung blockieren).
- Ratenbegrenzung/Dauer: ein Lauf braucht mehrere `gh`-Aufrufe; Hook braucht Zeitlimit (z. B. 10 s), sonst verzögert er jeden Start.
- `gh project item-list` braucht den `project`-Scope (laut CLAUDE.md vorhanden).
- Überschneidung: Hotspots `project.yml`, `cloudkit/schema.ckdb`, `*.xcstrings`, `CLAUDE.md`, `StartPage`/`ContentView`; Dateiliste je offenem PR über `gh pr diff --name-only` ist robuster als Worktree-Zweige.
- Schnittgröße: S1 liegt wohl bei ~200 LoC (Skript + Test), S2 klein; Scoping-Limit im Blick halten.

## Analysis

### Type
Feature (Sitzungswerkzeug, kein App-Code, keine sichtbare Oberfläche, daher keine Entwurfsvorschau nötig)

### Ohne-Modell-Beleg
Alles regelbasiert: GitHub-API, Sortierung, `git diff --name-only`. Ein Sprachmodell wird nirgends gebraucht.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| scripts/next-ticket.sh | CREATE | S1: Epic bestimmen, Kandidaten filtern, sortieren, Überschneidung melden, Vorschlag mit Begründung |
| scripts/test_next_ticket.py | CREATE | S1: Test mit Attrappen für `gh`/`herdr`/`git` (PATH-Überschreibung), zwei Zweige mit Hotspot-Treffer |
| CLAUDE.md | MODIFY | Abschnitt „Process“: Epic-Regel und Skript |
| ~/.claude/scripts/loose-ends-next-ticket-hook.sh | CREATE | S2: SessionStart-Hook (startup/clear), Zeitlimit 10 s, scheitert nie |
| ~/.claude/settings.json | MODIFY | S2: dritter SessionStart-Eintrag |

### Technischer Ansatz (Skript)
1. Epic: `herdr workspace get $HERDR_WORKSPACE_ID` → Label. Führende `#N`: hat N Teil-Tickets, ist N der Epic; sonst `parent` von N. Keine Nummer oder kein Epic → Meldung, kein Vorschlag, kein Griff in fremde Epics.
2. Kandidaten: offene Teil-Tickets des Epics.
3. Abzug: Board-Status In progress/In review; Ticket mit offenem PR; Ticket in Sperre einer lebenden Sitzung (`pid` läuft, Phase < 8, andere Sitzung als die eigene); Ticket mit offenem „blocked by“.
4. Reihenfolge: Priority, dann Board-Reihenfolge (Ziehen schlägt Milestone innerhalb einer Priorität).
5. Überschneidung: Dateiliste jedes offenen PRs (`gh pr diff --name-only`) plus Zweige lebender Sitzungen (`git diff --name-only main...<branch>`) gegen die Hotspots; Treffer steht im Vorschlag.
6. Leer/blockiert: Blocker nennen und `herdr notification`; erste Ausgabezeile maschinenlesbar (`NEXT=#N` oder `NEXT=none`), Begründung danach.
7. Überschreibbar per `LOOSEENDS_REPO`; Fehler beim Abruf → Ausgabe „unbekannt“, Exit 0.

### Alternativen
- Keine Epic-Zuordnung, oberstes freies Board-Ticket: einfacher, kippt aber die Entscheidung vom 2026-10-26.
- Kein Hook, Skript nur von Hand via `/00-intake` ohne Nummer: spart S2, Henning müsste aber wieder etwas auslösen.
- Vorschlag nur am Ticketende statt bei SessionStart: kein Hook nötig, geht aber nach `/clear` verloren, deshalb Hook.

### Scope Assessment
- S1: 3 Dateien, ca. +230 LoC, Risiko LOW (nur lesend, ändert nichts an GitHub)
- S2: 2 Dateien außerhalb des Repos, ca. +40 LoC, Risiko MEDIUM (ein Fehler im Hook würde jeden Sitzungsstart verzögern; daher Zeitlimit, immer `exit 0`, Projektfilter)
- Gerätestufe: Kein Pfad der Geräteliste berührt.

### Dependencies
`herdr`, `gh` (Scope `project`), `git`, Sperrdateien in `<Hauptcheckout>/.claude/session-locks/` (Plugin, nicht ändern). Teil 2 („blocked by“ eintragen) ist GitHub-Pflege ohne Code und Voraussetzung für den echten Lauf der DoD.

### Befunde gegen den Plan
- Der herdr-Name ist nicht verlässlich ein Epic (w3 heißt „#176 Abnahme“); das Skript liest beides.
- #715 selbst hat keinen Epic; ein Lauf aus dieser Sitzung liefert „kein Epic“, erwartetes Verhalten.
- Sperren fertiger Sitzungen (z. B. #705, `phase8_complete`) dürfen nichts blockieren.
- „blocked by“ ist heute überall leer; ohne Teil 2 würde das Skript #176 vorschlagen.

### Empfehlung
Drei Schritte: S1 (Skript, Test, CLAUDE.md), dann Teil 2 (Einträge in den Epics, echter Lauf für #371), dann S2 (Hook). Je Schritt eine Teil-Spec.

### Open Questions
- [ ] Keine, die Henning betreffen; der Zuschnitt S1/S2 ist eine technische Entscheidung.
