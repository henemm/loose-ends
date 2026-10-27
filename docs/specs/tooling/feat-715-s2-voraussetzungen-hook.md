---
entity_id: feat-715-s2-voraussetzungen-hook
type: feature
created: 2026-10-27
updated: 2026-10-27
status: draft
workflow: feat-715-s2-voraussetzungen-hook
---

# Spec: #715 Schnitt 2 — „blocked by“ eintragen, Vorschlag nach `/clear` in den Kontext legen

## Approval

- [ ] Approved

## Purpose

Schnitt 1 (`scripts/next-ticket.sh`, gemergt) sagt, welches Ticket des Epics als Nächstes frei ist. Zwei Dinge fehlen, damit das im Alltag
trägt: Die Reihenfolge der Tickets steht nur im Fließtext der Epics, nicht als „blocked by“ auf GitHub, also kennt das Skript sie nicht
(heute schlägt es in Epic #371 `#40` vor und könnte `#176` vorn führen, obwohl #176 als letzter Schritt dran ist). Und der Vorschlag
erscheint nicht von selbst: Wer `/clear` tippt, muss das Skript von Hand starten.

Schnitt 2 trägt (Teil 2) die Voraussetzungen als „blocked by“ ein und legt (Teil 4) den Vorschlag nach `/clear` und beim Start einer
Sitzung per SessionStart-Hook in den Kontext.

**Hat es bisher funktioniert?** Nein, beides gab es nie. `GET …/issues/176/dependencies/blocked_by` liefert heute `[]`. Der Befund stammt aus
dem echten Lauf vom 2026-10-27 (`docs/context/feat-715-s2-voraussetzungen-hook.md`): `NEXT=#40`, 14 s Laufzeit; in der herdr-Sitzung sind
`HERDR_WORKSPACE_ID=w3` und `HERDR_ENV=1` gesetzt, `CLAUDE_SESSION_ID` ist leer.

**Recherche (zuerst, Quellen):**
- Hooks: https://code.claude.com/docs/en/hooks — `SessionStart`-Quellen `startup`/`resume`/`clear`/`compact`; Klartext auf stdout oder
  JSON `hookSpecificOutput.additionalContext` landet im Kontext; stdin-JSON hat `session_id`, `cwd`, `source`. Ein Standard-Zeitlimit fand
  sich nicht, darum steht `timeout` ausdrücklich im Eintrag.
- Abhängigkeiten: https://docs.github.com/en/rest/issues/issue-dependencies — `POST /repos/{o}/{r}/issues/{n}/dependencies/blocked_by` mit
  `issue_id` = numerische REST-`id` des blockierenden Tickets (nicht die Nummer), 201 bei Erfolg, 422 bei Verstoß oder zu schnellem Schreiben.

**Ohne Modell:** Alles ist API-Abfrage, JSON und Filter. Kein Sprachverstehen; die Regel ist der Vorschlag.

**Alternativen:** (A) Kein Hook: `/00-intake` ohne Nummer ruft das Skript selbst auf (liegt im Plugin, anderes Repo; verfehlt „nach `/clear`
steht der Vorschlag im Kontext“; Rückfall, falls der Hook zu langsam oder fragil ist). (B) Vorschlag zwischenspeichern: sofort da, aber veraltet,
zweiter bewegter Teil. (C) Das Skript beschleunigen (parallele `gh`-Aufrufe): löst die 14 s an der Wurzel, ist ein eigener Schnitt am Skript
und wird als Folge-Ticket vorgemerkt, falls die Messung unten über 25 s liegt. Keine Alternative kippt eine frühere Entscheidung.

**Nicht Teil dieses Schnitts:** Änderungen an `scripts/next-ticket.sh`; Änderungen am Plugin; Epics ohne genannte Abhängigkeit (#370, #369, #468,
#373, #688, #642).

## Source

- **File:** `scripts/next-ticket-hook.sh` (neu)
- **Identifier:** SessionStart-Adapter; liest die stdin-JSON, ruft `scripts/next-ticket.sh`, gibt `additionalContext` aus

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/next-ticket.sh` | skript | liefert den Vorschlag (Schnitt 1, auf `main`) |
| SessionStart-stdin-JSON (`session_id`, `cwd`, `source`) | schnittstelle | Sitzungskennung für den Fremd-Sperren-Abzug, Quelle, Projektfilter |
| `HERDR_WORKSPACE_ID` | umgebung | im Hook vererbt; Sitzungsname = Epic |
| `gh api repos/henemm/loose-ends/issues/<N>/dependencies/blocked_by` | werkzeug | Voraussetzungen lesen, schreiben (Teil 2) |
| `~/.claude/settings.json`, Abschnitt `hooks.SessionStart` | konfiguration (außerhalb des Repos) | dritter Eintrag |
| `~/.claude/scripts/loose-ends-sync-main.sh` | vorbild | Filter „gehört die Sitzung zu Loose Ends“, defensiv, Exit 0 |
| `scripts/test_next_ticket_hook.py` | test | Attrappen für das Skript, kein Netz |

## Scope

| Datei | Änderung | Beschreibung |
|---|---|---|
| `scripts/next-ticket-hook.sh` | CREATE | Adapter, siehe Implementation Details |
| `scripts/test_next_ticket_hook.py` | CREATE | Skripttests mit Attrappe für `next-ticket.sh`, RED zuerst |
| `docs/reference/abnahme-und-arbeitsweise.md` | MODIFY (ein Absatz) | Hook, Wortlaut, wie man ihn abschaltet. `CLAUDE.md` bleibt unberührt (Hotspot) |
| `~/.claude/settings.json` | MODIFY (außerhalb des Repos) | dritter SessionStart-Eintrag, Matcher `^(startup\|clear)$`, `timeout` 30 |
| GitHub | MODIFY (Datenpflege, kein Code) | „blocked by“-Einträge, siehe Teil 2 |

Geschätzt +130 LoC, 3 Dateien im Repo. Kein Produktcode, keine Berechtigungen, keine AppStorage-Schlüssel, keine Info.plist.
**Geräteliste:** Kein Pfad der Geräteliste berührt. Nichts läuft auf Hennings Geräten. Keine sichtbare UI-Änderung.

## Definition of Done

- [ ] Voraussetzungen von #176 und Epic #612 stehen als „blocked by“ auf GitHub, nichts doppelt (AC-1, AC-2)
- [ ] Danach liefert das Skript in der Sitzung von Epic #371 nicht mehr `#176` (AC-3)
- [ ] Der Adapter reicht die Sitzungskennung aus stdin weiter und gibt den Vorschlag als Hinweis aus (AC-4, AC-5)
- [ ] Er bleibt in fremden Projekten, bei falscher Quelle, ohne `#N`, bei Zeitüberschreitung und bei Fehlern leise und endet mit Exit 0 (AC-6 bis AC-8)
- [ ] Der Hook ist in `~/.claude/settings.json` eingetragen und ändert die zwei bestehenden Einträge nicht (AC-9)
- [ ] Echter Durchlauf mit echter stdin-JSON in dieser herdr-Sitzung, Laufzeit gemessen (AC-10)
- [ ] Doku-Absatz geschrieben (AC-11)
- [ ] Alle Skripttests in `scripts/` grün

## Implementation Details

**Teil 2 — Voraussetzungen eintragen (einmalige Datenpflege, von Hand per `gh api`).**
1. Vor jedem Schreiben `GET …/dependencies/blocked_by` lesen; was schon steht, wird übersprungen.
2. `issue_id` = `gh api repos/henemm/loose-ends/issues/<Nummer> --jq .id`. Zwischen zwei Schreibaufrufen 2 s Pause (Sekundärlimit, sonst 422).
3. Kanten: `#176` ← `#342`, `#71`, `#88`, `#40`. Für Epic #612 nur die Übergänge Stufe 1→2 und 2→3, die der Epic-Text mit seinen fünf Stufen trägt:
   `#614`, `#615` ← `#613`; `#616` ← `#614`, `#615`. Der Text nennt keine Kanten zwischen einzelnen Tickets und keine zwischen Stufe 3→4 und 4→5;
   sie werden nicht eingetragen: die Kante ist nur Reihenfolge-Hilfe, eine falsche sperrt Arbeit. (Nachbesserung 2026-10-27, Henning „override“.)
4. Danach `GET` je Ticket: die Liste entspricht Punkt 3. Das ist der Beleg für AC-1 und AC-2.

**Teil 4 — `scripts/next-ticket-hook.sh`.**
1. stdin-JSON lesen (`python3`): `source`, `session_id`, `cwd`. Nicht lesbar: Ausgabe leer, Exit 0.
2. Nur bei `source` ∈ {`startup`, `clear`}. `resume` und `compact` bleiben still (dort steht der Stand schon im Gespräch).
3. Nur wenn `cwd` unter dem Loose-Ends-Hauptcheckout liegt (Worktrees darunter zählen; `LOOSEENDS_CHECKOUT` überschreibt den Pfad. `LOOSEENDS_REPO` ist schon das GitHub-Repo von `next-ticket.sh` und wird weder gelesen noch durchgereicht).
4. Nur wenn `HERDR_WORKSPACE_ID` gesetzt ist und `herdr workspace get` ein Label mit führendem `#N` liefert. Sonst leer, Exit 0.
5. `CLAUDE_SESSION_ID=<session_id> scripts/next-ticket.sh` (Pfad überschreibbar mit `LOOSEENDS_NEXT_TICKET`) mit Zeitgrenze (`LOOSEENDS_NEXT_TIMEOUT`, Vorgabe 25 s,
   unter dem `timeout` 30 des Eintrags). Zeitüberschreitung, Exit ≠ 0 oder erste Zeile `NEXT=unknown`: Ausgabe leer, Exit 0.
6. Ausgabe bei `NEXT=#N` oder `NEXT=none`: JSON `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"…"}}` mit dem Satz
   „Vorschlag für das nächste Ticket dieses Epics (Hinweis, kein Auftrag; ist ein Workflow aktiv, geht dessen Pflicht-Schritt vor):“ und danach
   dem Klartext des Skripts. Sonst nichts auf stdout; Diagnose nur auf stderr.
7. Immer Exit 0. Das Skript schreibt nirgends hin, weder nach GitHub noch in Dateien.

**Eintrag in `~/.claude/settings.json`.** Dritter Eintrag in `hooks.SessionStart`: Matcher `^(startup|clear)$`, Befehl
`bash /Users/hem/Developer/loose-ends/scripts/next-ticket-hook.sh`, `timeout` 30. Die zwei bestehenden Einträge bleiben Zeichen für Zeichen
gleich. Der Hauptcheckout bekommt das Skript mit dem nächsten Sync nach dem Merge; bis dahin ist der Eintrag wirkungslos, nicht schädlich
(fehlende Datei: Hook-Fehler ohne Wirkung auf die Sitzung).

## Test Plan

Skripttests in Python (Muster `test_next_ticket.py`): `next-ticket.sh` und `herdr` als Attrappen, stdin-JSON je Fall, kein Netz. RED zuerst.

| Test | Prüft |
|---|---|
| `test_session_id_from_stdin_reaches_script` | die Attrappe sieht `CLAUDE_SESSION_ID` = `session_id` aus stdin (AC-4) |
| `test_normal_case_outputs_additional_context_with_notice` | `NEXT=#40` → gültiges JSON, `additionalContext` enthält den Hinweissatz und den Klartext (AC-5) |
| `test_none_is_passed_on` | `NEXT=none` mit Grund → ebenfalls Hinweis (AC-5) |
| `test_other_source_is_silent` | `resume` und `compact` → leer, Exit 0 (AC-6) |
| `test_foreign_project_is_silent` | `cwd` außerhalb Loose Ends → leer, Skript nicht aufgerufen (AC-6) |
| `test_label_without_number_is_silent` | Label „Restock“ → leer (AC-6) |
| `test_unknown_is_silent` | `NEXT=unknown` → leer, Exit 0 (AC-7) |
| `test_timeout_is_silent` | Attrappe schläft über `LOOSEENDS_NEXT_TIMEOUT` → leer, Exit 0, Laufzeit begrenzt (AC-7) |
| `test_script_failure_and_bad_stdin_are_silent` | Skript Exit 3; stdin kein JSON → leer, Exit 0 (AC-8) |
| `test_settings_has_third_entry_and_keeps_others` | liest `~/.claude/settings.json` (überspringt, wenn die Datei fehlt, etwa in der CI): drei Einträge, Matcher, `timeout` 30, die zwei alten unverändert gegenüber ihrem Wortlaut im Test (AC-9) |

Nicht in den Tests, sondern als echter Durchlauf (AC-3, AC-10): Teil 2 per `gh api` gegen GitHub; Adapter mit echter stdin-JSON in dieser
herdr-Sitzung, Laufzeit mit `time` gemessen.

## Acceptance Criteria

- **AC-1:** Given `#176` hat kein „blocked by“, When Teil 2 durchgeführt ist, Then liefert `GET …/issues/176/dependencies/blocked_by` genau #342, #71, #88 und #40, und ein zweiter Durchlauf legt nichts doppelt an.
- **AC-2:** Given Epic #612 nennt seine Reihenfolge in Stufen, When Teil 2 durchgeführt ist, Then entspricht die Liste „blocked by“ je Ticket den Kanten aus Implementation Details Punkt 3, soweit der Epic-Text sie trägt; nicht getragene Kanten sind nicht eingetragen.
- **AC-3:** Given AC-1 erfüllt, When `scripts/next-ticket.sh` in der Sitzung von Epic #371 läuft, Then ist `#176` nicht der Vorschlag. (Nachbesserung 2026-10-27: Der Zusatz „der Blocker steht in der Ausgabe“ entfällt. `#176` hat offene Teil-Tickets und ist nie Kandidat; die Blocker eines Sammeltickets nennt das Skript erst nach einer Änderung an `next-ticket.sh`, siehe #723 und Known Limitations.)
- **AC-4:** Given die stdin-JSON trägt eine `session_id`, When der Adapter das Skript ruft, Then ist `CLAUDE_SESSION_ID` im Skript diese `session_id` (die Sitzung sperrt sich nicht selbst).
- **AC-5:** Given Quelle `startup` oder `clear`, eine Loose-Ends-Sitzung mit `#N` im herdr-Namen und `NEXT=#N` oder `NEXT=none`, When der Adapter läuft, Then gibt er gültiges SessionStart-JSON mit `additionalContext` aus, der den Hinweissatz („Hinweis, kein Auftrag; ein aktiver Workflow geht vor“) und den Klartext des Skripts enthält.
- **AC-6:** Given Quelle `resume` oder `compact`, ein fremdes Projekt oder ein herdr-Name ohne führende `#N`, When der Adapter läuft, Then ist die Ausgabe leer, das Skript wird nicht aufgerufen, Exit 0.
- **AC-7:** Given das Skript meldet `NEXT=unknown` oder braucht länger als `LOOSEENDS_NEXT_TIMEOUT`, When der Adapter läuft, Then ist die Ausgabe leer, Exit 0, und der Adapter kehrt innerhalb der Zeitgrenze plus 2 s zurück.
- **AC-8:** Given das Skript endet mit Fehler oder stdin ist kein gültiges JSON, When der Adapter läuft, Then ist die Ausgabe leer, Exit 0.
- **AC-9:** `~/.claude/settings.json` enthält in `hooks.SessionStart` den dritten Eintrag (Matcher `^(startup|clear)$`, `timeout` 30, Befehl auf `next-ticket-hook.sh` im Hauptcheckout); die zwei bisherigen Einträge sind unverändert.
- **AC-10:** Der Adapter wurde in dieser herdr-Sitzung mit echter stdin-JSON (`source` = `clear`) gelaufen; die Ausgabe ist gültiges JSON, die Laufzeit ist gemessen und im Abschlussbericht genannt. Liegt sie über 25 s, wird Alternative C als Folge-Ticket angelegt.
- **AC-11:** `docs/reference/abnahme-und-arbeitsweise.md` beschreibt den Hook: wann er greift, den Hinweiswortlaut, dass er nie blockiert, und wie man ihn abschaltet.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reines Sitzungswerkzeug ohne Wirkung auf das Produkt; die Regel „je Sitzung ein Epic“ (2026-10-26) wird umgesetzt, nicht gekippt.

## Offener Punkt

Der Hook läuft bei jedem Start in allen Projekten; Schutz sind die Filter (Quelle, Loose Ends, herdr-Name mit `#N`), die Zeitgrenze und Exit 0.
Die bis zu 14 s Wartezeit bei `/clear` in Epic-Sitzungen werden im echten Durchlauf gemessen (AC-10).
Der Settings-Eintrag liegt außerhalb des Repos und ist nicht versioniert; die Doku (AC-11) hält den Wortlaut fest.

## Known Limitations

- **AC-3, zweiter Teil („der Blocker steht in der Ausgabe“):** nicht erfüllbar in diesem Schnitt. `#176` hat offene Teil-Tickets (#601, #605, #607)
  und ist deshalb nie Kandidat; `next-ticket.sh` fragt „blocked by“ nur für Kandidaten ab. Der erste Teil (`#176` ist nicht der Vorschlag) gilt.
  Die Blocker eines Sammeltickets an seine Teil-Tickets weiterzugeben ist eine Änderung an `next-ticket.sh` und damit ein Folge-Ticket
  (Adversary-Befund F001, 2026-10-27).

## Changelog

- 2026-10-27: Spec erstellt (Schnitt 2 von #715: Teile 2 und 4).
- 2026-10-27: Nachbesserung nach Adversary-Befund (Henning „override“): AC-3 ohne Blocker-Zusatz, Variable `LOOSEENDS_CHECKOUT` statt `LOOSEENDS_REPO`, Epic-#612-Kanten auf die Stufenübergänge 1→2 und 2→3 beschränkt.
