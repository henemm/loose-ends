# Adversary Dialog — feat-715-naechstes-ticket
Spec: docs/specs/tooling/feat-715-s1-next-ticket-skript.md
Datum: 2026-10-27

## Checkliste
- [x] **AC-1:** Epic = N selbst, wenn N kein Eltern-Ticket, aber Teil-Tickets hat.
- [x] **AC-2:** Epic = oberstes Eltern-Ticket (echter Lauf: „#176 Abnahme“ → Epic #371).
- [x] **AC-12:** Kandidaten = unterste offene Ebene; Sammelticket #176 wird nie vorgeschlagen.
- [x] **AC-3:** In progress / In review / offener PR entfällt mit Grund.
- [x] **AC-4:** Nur lebende fremde Locks (pid läuft, Phase < 8) sperren.
- [x] **AC-5:** Offenes „blocked by“ entfällt, Blocker genannt.
- [x] **AC-6:** Priority, dann Board-Reihenfolge.
- [x] **AC-7:** Hotspot-Überschneidung wird gemeldet, streicht nichts.
- [x] **AC-8:** Kein Epic / kein freies Ticket → NEXT=none, Grund, Mitteilung, Exit 0.
- [x] **AC-9:** Werkzeug fehlt, Abruf scheitert oder hängt → NEXT=unknown, Exit 0.
- [x] **AC-10:** Erste Zeile immer NEXT=#N | none | unknown.
- [x] **AC-11:** CLAUDE.md „Process“ nennt Skript und Epic-Regel.

## Dialog

### Runde 1
**Adversary:** 17 Tests grün, aber Gegenproben mit eigenen Attrappen widerlegen AC-3 und AC-7 und zeigen Lücken bei AC-4 und AC-9: F001 (PR-Bezug nur Schlüsselwort + eine Nummer, Titel ignoriert), F002 (Lock-JSON `[]`/`null` verdeckt spätere Locks), F003 (Hotspot-Muster globben gegen das Arbeitsverzeichnis), F004 (kein Zeitlimit für gh). F005 (falscher Grundtext bei parent-Zyklus, LOW). Verdict Runde 1: BROKEN.
Code reference: scripts/next-ticket.sh:187
Code reference: scripts/test_next_ticket.py:100
**Implementierer:** Für F001–F004 vier rote Tests ergänzt (`test_pr_reference_in_title_and_in_closes_list`, `test_non_object_lock_does_not_hide_later_locks`, `test_hotspot_globs_do_not_depend_on_working_directory`, `test_hanging_gh_gives_unknown`) plus `test_missing_gh_gives_unknown`; Skript korrigiert (Titel und Nummernlisten, `isinstance(dict)`, `set -f`, `gh_run` mit `LOOSEENDS_GH_TIMEOUT`). F005: Zyklus in GitHub nicht möglich, Exit 0 und NEXT=none stimmen, nur Text; als Notiz belassen.

### Runde 2
**Adversary:** F001–F004 mit eigenen Läufen und Code-Lesen bestätigt behoben, 22/22 Tests grün, echter Lauf `HERDR_WORKSPACE_ID=w3`: `NEXT=#40`, Epic #371, entfallen #342/#601/#605/#607. F005 reicht als Notiz (keine AC verlangt Wortlaut). Neu F006 (MEDIUM): Zweigname-Regex zu weit (`work/2026-10-40`, `feat/ios-40-update`, `release-40` ziehen #40 ab). Verdict Runde 2: VERIFIED mit Empfehlung, F006 zu verengen.
Code reference: scripts/next-ticket.sh:224
Code reference: CLAUDE.md:276
**Implementierer:** F006 mit rotem Test `test_branch_numbers_only_count_right_after_prefix` belegt, Regel auf `^[A-Za-z]+/([0-9]{2,})(?:-|$)` verengt (Zeile 187); 23/23 Tests grün, echter Lauf unverändert `NEXT=#40`. Nicht selbst gelaufen vom Adversary: Timeout-Pfad und Leerzeichen-Argumente von `gh_run` (nur gelesen); durch `test_hanging_gh_gives_unknown` im Skripttest abgedeckt.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:bb71a09327d8c1e06e4d2ee28b902d655881c09471a0e1c9ca8c4f0e0e9c97b3  CLAUDE.md
- sha256:aa16630e36baa02225f4b69ee56aa2d00b135f1764375d5b74da996f289b3e84  scripts/next-ticket.sh
- sha256:85b7a0bbad571304aef140a4bda058b56cff4f4c14057ad66eebb8a67c3c4c7b  scripts/test_next_ticket.py

## Prüfbasis

- base: 582126e0e266453605b6a182b9420be2d1590e93
- blob:133b243b60e2ead65256f6b64f28d10d22cbde5b  CLAUDE.md
- blob:d7b86a5ad2ac4ce1cdbda86cad6effcdee6fcd52  scripts/next-ticket.sh
- blob:5946e6a773c73ec5ebe18b1053af54efb197a859  scripts/test_next_ticket.py
