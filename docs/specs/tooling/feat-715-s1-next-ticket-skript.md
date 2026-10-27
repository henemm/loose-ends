---
entity_id: feat-715-s1-next-ticket-skript
type: feature
created: 2026-10-27
updated: 2026-10-27
status: draft
workflow: feat-715-naechstes-ticket
---

# Spec: #715 Schnitt 1 — `scripts/next-ticket.sh` schlägt das nächste Ticket des Epics vor

## Approval

- [ ] Approved

## Purpose

Nach einem fertigen Ticket soll nicht Henning, sondern ein Skript sagen, welches Ticket des Epics dieser Sitzung als Nächstes
startbar ist: mit Begründung, mit den Blockern und mit dem Hinweis, wo es Dateien berührt, die gerade ein anderer offener Zweig
ändert. Schnitt 1 liefert nur das Skript (lesend, ändert nichts an GitHub). Der SessionStart-Hook, der den Vorschlag nach
`/clear` in den Kontext legt, ist Schnitt 2 (eigene Teil-Spec).

**Hat es bisher funktioniert?** Nein, es gab das nie. Die Wahl des nächsten Tickets lief von Hand und endete am 2026-10-26 in einer
Empfehlung ohne Blick auf belegte Tickets (Epic #467). Die Regel „je Sitzung ein Epic“ (2026-10-26) und die Korrektur „Name = Epic“
(2026-10-27) haben bisher kein Werkzeug.

**Befund (2026-10-27, echte Läufe, siehe `docs/context/feat-715-naechstes-ticket.md`):**
`HERDR_WORKSPACE_ID` ist gesetzt, `herdr workspace get` liefert das Label; heute steht dort für w3 „#176 Abnahme“, also ein Ticket,
kein Epic (#176 gehört zu #371). `gh api …/issues/<N>/sub_issues` und `…/parent` funktionieren; `…/dependencies/blocked_by` existiert,
ist heute aber nirgends gepflegt. Locks lebender und fertiger Sitzungen liegen unter `<Hauptcheckout>/.claude/session-locks/`.

**Ohne Modell:** Alles ist API-Abfrage, Filter und Sortierung. Kein Sprachverstehen nötig; die Regel ist der Vorschlag.

**Alternativen:** (a) Keine Epic-Zuordnung, jede Sitzung nimmt das oberste freie Board-Ticket: einfacher, kippt aber die Entscheidung
vom 2026-10-26 („je Sitzung ein Epic“). (b) Kein Skript, die Sitzung liest Board und Locks jedes Mal von Hand: das ist der Zustand
heute und die Fehlerquelle. Gewählt wird das Skript mit Epic-Zuordnung; die Entscheidung vom 2026-10-26 bleibt, kein ADR wird gekippt.

**Nicht Teil dieses Schnitts:** SessionStart-Hook und `~/.claude/settings.json` (Schnitt 2); „blocked by“-Einträge in den Epics anlegen
(reine GitHub-Pflege, Voraussetzung für den echten Lauf, aber kein Code).

## Source

- **File:** `scripts/next-ticket.sh` (neu)
- **Identifier:** Skript mit Funktionen `epic_of`, `candidates`, `busy_issues`, `overlaps`, `render`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `herdr workspace get $HERDR_WORKSPACE_ID` | werkzeug | Label der Sitzung (Epic oder Ticket) |
| `gh api repos/<repo>/issues/<N>/sub_issues`, `…/parent`, `…/dependencies/blocked_by` | werkzeug | Teil-Tickets, Eltern, Blocker |
| `gh project item-list 1 --owner henemm --format json` | werkzeug | Status, Priority, Hennings Reihenfolge |
| `gh pr list`, `gh pr diff --name-only` | werkzeug | offene PRs und ihre Dateien |
| `<Hauptcheckout>/.claude/session-locks/*.json` | datei | Belegung (`issue`, `phase`, `branch`, `pid`); Quelle ist das Plugin, nicht ändern |
| `git diff --name-only main...<branch>` | werkzeug | Dateien der Zweige lebender Sitzungen |
| `scripts/test_next_ticket.py` | test | Attrappen für `gh`/`herdr`/`git` im PATH |
| `LOOSEENDS_REPO` | muster | Repo-Überschreibung wie in `loose-ends-sync-main.sh` (für Tests) |
| `docs/reference/board.md` | doc | Board-Zugriff |
| „blocked by“-Einträge in den Epics (Teil 2) | voraussetzung | nur für den echten Lauf; die Skripttests brauchen sie nicht |

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `scripts/next-ticket.sh` | CREATE | Epic bestimmen, Kandidaten filtern und sortieren, Überschneidung melden, Vorschlag ausgeben |
| `scripts/test_next_ticket.py` | CREATE | Skripttest mit Attrappen, RED zuerst |
| `CLAUDE.md` | MODIFY | Abschnitt „Process“: Epic-Regel und Skript |

Geschätzt +230 LoC, 3 Dateien. Kein Produktcode, keine Berechtigungen, keine AppStorage-Schlüssel, keine Info.plist.
**Geräteliste:** Kein Pfad der Geräteliste berührt. Nichts läuft auf Hennings Geräten. Keine sichtbare UI-Änderung.

## Definition of Done

- [ ] Epic wird aus dem herdr-Namen bestimmt, auch wenn dort ein Ticket steht (AC-1, AC-2)
- [ ] Belegte, blockierte und fremde Tickets werden nicht vorgeschlagen (AC-3 bis AC-5)
- [ ] Reihenfolge nach Priority, dann Board-Reihenfolge (AC-6)
- [ ] Überschneidung mit offenen Zweigen steht im Vorschlag (AC-7)
- [ ] Leer, blockiert, kein Epic und Abruffehler enden verständlich mit Exit 0 (AC-8, AC-9)
- [ ] Erste Ausgabezeile maschinenlesbar (AC-10)
- [ ] `CLAUDE.md` ergänzt (AC-11)
- [ ] Alle Skripttests in `scripts/` grün

## Implementation Details

1. **Epic.** Label aus `herdr workspace get "$HERDR_WORKSPACE_ID"`. Führende `#N` (Regex `^#([0-9]+)`) lesen. Hat N Teil-Tickets
   (`sub_issues` nicht leer), ist N der Epic. Sonst ist `parent` von N der Epic. Ohne führende Nummer, ohne Eltern oder ohne
   `HERDR_WORKSPACE_ID`: `NEXT=none`, Grund „kein Epic“, keine Suche in fremden Epics.
2. **Kandidaten.** Offene Teil-Tickets des Epics.
3. **Abzug.** Ein Kandidat entfällt, wenn (a) sein Board-Status In progress oder In review ist, (b) ein offener PR auf ihn verweist,
   (c) eine **lebende** andere Sitzung ihn hält (Lock mit `pid` läuft, Phase kleiner `phase8_complete`, nicht die eigene Sitzung),
   (d) er ein offenes „blocked by“ hat. Locks fertiger Sitzungen (`phase8_complete`) oder toter Prozesse sperren nichts.
   Jeder Abzug wird mit Ticketnummer und Grund notiert, damit die Begründung ihn nennen kann.
4. **Reihenfolge.** Priority (P0 vor P1 vor P2), innerhalb einer Priority Hennings Reihenfolge auf dem Board (Position in `item-list`).
5. **Überschneidung.** Dateiliste je offenem PR (`gh pr diff --name-only`) und je Zweig einer lebenden Sitzung
   (`git diff --name-only main...<branch>`). Gemeldet werden Treffer auf die Hotspots `project.yml`, `cloudkit/schema.ckdb`,
   `*.xcstrings`, `CLAUDE.md`, `LooseEnds/Views/StartPage*`, `LooseEnds/Views/ContentView*`, je mit PR/Zweig. Der Hinweis ist
   Information und streicht den Vorschlag nicht.
6. **Ausgabe.** Erste Zeile `NEXT=#N` oder `NEXT=none`. Danach Klartext: Titel, Priority, warum dieses (oberstes freies), welche
   Kandidaten aus welchem Grund entfielen, Überschneidungen. Bei `none` mit offenen Kandidaten: die Blocker nennen und
   `herdr notification` senden, falls `herdr` erreichbar ist (Fehler dabei werden ignoriert).
7. **Defensiv.** Fehlt `gh`/`herdr` oder scheitert ein Abruf: `NEXT=unknown`, Zeile mit dem Grund, Exit 0. Das Skript schreibt nirgends
   nach GitHub und ändert keine Datei. `LOOSEENDS_REPO` überschreibt das Repo (Vorgabe `henemm/loose-ends`).

## Test Plan

Skripttests in Python (Muster `test_entitlements_sync.py`, `test_sim_lock.py`): `gh`, `herdr`, `git` als Stubs im PATH mit festen
JSON-Antworten, Lock-Verzeichnis im Temp-Ordner. RED zuerst.

| Test | Prüft |
|---|---|
| `test_epic_from_label_with_epic_number` | Label „#371 Texte“, #371 hat Teil-Tickets: Epic 371 (AC-1) |
| `test_epic_from_label_with_ticket_number` | Label „#176 Abnahme“, `parent` = 371: Epic 371 (AC-2) |
| `test_no_epic_gives_none` | Label „Restock“ und #715 ohne Eltern: `NEXT=none`, „kein Epic“, Exit 0 (AC-8) |
| `test_in_progress_and_pr_are_skipped` | Board-Status In progress, offener PR: nicht vorgeschlagen, Grund genannt (AC-3) |
| `test_live_session_lock_blocks_finished_lock_does_not` | Lock mit lebender PID sperrt, Lock mit `phase8_complete` und Lock mit toter PID nicht; eigene Sitzung sperrt sich nicht (AC-4) |
| `test_blocked_by_is_skipped_and_named` | offenes „blocked by“: Ticket entfällt, Blocker steht in der Ausgabe (AC-5) |
| `test_order_priority_then_board_position` | P0 vor P1; gleiche Priority nach Board-Position (AC-6) |
| `test_overlap_with_open_pr_is_reported` | zwei offene PRs, einer berührt `project.yml`: Hinweis mit PR-Nummer, `NEXT` bleibt (AC-7) |
| `test_all_blocked_gives_none_and_notifies` | alle Kandidaten entfallen: `NEXT=none`, Blocker genannt, `herdr notification` aufgerufen (AC-8) |
| `test_api_failure_gives_unknown_exit_zero` | `gh` scheitert: `NEXT=unknown`, Exit 0, nichts geschrieben (AC-9) |
| `test_first_line_is_machine_readable` | erste Zeile passt auf `^NEXT=(#[0-9]+|none|unknown)$` (AC-10) |
| `test_claude_md_names_script_and_epic_rule` | `CLAUDE.md` nennt im Abschnitt „Process“ `scripts/next-ticket.sh` und die Epic-Regel (AC-11) |

Zusätzlich: bestehende Skripttests in `scripts/` bleiben grün. Ein echter Lauf gegen GitHub (DoD des Tickets, Teil 2 vorausgesetzt)
folgt nach Teil 2 und ist nicht Teil dieser Tests.

## Acceptance Criteria

- **AC-1:** Given das herdr-Label beginnt mit `#N` und N hat Teil-Tickets, When das Skript läuft, Then ist N der Epic.
- **AC-2:** Given das Label beginnt mit `#N` und N hat keine Teil-Tickets, aber einen Eltern-Epic, When das Skript läuft, Then ist dieser Eltern-Epic der Epic.
- **AC-3:** Given ein Teil-Ticket steht auf dem Board In progress oder In review oder hat einen offenen PR, When das Skript läuft, Then wird es nicht vorgeschlagen und der Grund steht in der Ausgabe.
- **AC-4:** Given eine andere Sitzung mit laufender `pid` und Phase kleiner `phase8_complete` hält ein Ticket, When das Skript läuft, Then wird es nicht vorgeschlagen; Locks fertiger Sitzungen, toter Prozesse und der eigenen Sitzung sperren nichts.
- **AC-5:** Given ein Teil-Ticket hat ein offenes „blocked by“, When das Skript läuft, Then wird es nicht vorgeschlagen und der Blocker steht in der Ausgabe.
- **AC-6:** Given mehrere freie Kandidaten, When das Skript sortiert, Then entscheidet zuerst die Priority, innerhalb gleicher Priority Hennings Board-Reihenfolge (Ziehen schlägt Milestone).
- **AC-7:** Given ein offener PR oder der Zweig einer lebenden Sitzung berührt einen Hotspot, When der Vorschlag ausgegeben wird, Then nennt er Hotspot und PR/Zweig, ohne den Vorschlag zu streichen.
- **AC-8:** Given kein Epic oder kein freier Kandidat, When das Skript läuft, Then lautet die erste Zeile `NEXT=none`, der Grund (kein Epic bzw. die Blocker) steht darunter, bei offenen Kandidaten wird `herdr notification` gesendet, Exit-Code 0.
- **AC-9:** Given `gh` oder `herdr` fehlt oder ein Abruf scheitert, When das Skript läuft, Then lautet die erste Zeile `NEXT=unknown` mit Grund, Exit-Code 0, und nichts wird geschrieben.
- **AC-10:** Die erste Ausgabezeile ist immer `NEXT=#N`, `NEXT=none` oder `NEXT=unknown`; die Begründung folgt danach.
- **AC-11:** `CLAUDE.md`, Abschnitt „Process“, nennt die Epic-Regel (Name der Sitzung = Epic, Ticket-Name → dessen Eltern) und `scripts/next-ticket.sh`.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reines Sitzungswerkzeug ohne Wirkung auf das Produkt; die Entscheidung „je Sitzung ein Epic“ (2026-10-26) wird umgesetzt, nicht gekippt.

## Offener Punkt

Die Hotspot-Liste ist eine Schätzung aus bisherigen Konflikten; sie steht oben im Skript als eine Variable und ist leicht zu ergänzen.
Ohne gepflegte „blocked by“-Einträge (Teil 2) schlägt das Skript heute etwa für #371 noch #176 vor; das ist kein Fehler des Skripts.

## Changelog

- 2026-10-27: Spec erstellt (Schnitt 1 von #715; Hook folgt als Schnitt 2).
