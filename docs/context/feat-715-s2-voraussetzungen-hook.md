# Context: feat-715-s2-voraussetzungen-hook

## Request Summary
#715 Schnitt 2: Die Voraussetzungen der offenen Epics als „blocked by“ auf GitHub eintragen (Teil 2) und nach `/clear` den Vorschlag von `scripts/next-ticket.sh` in den Kontext legen (Teil 4). Schnitt 1 (das Skript, Teile 1, 3 und 5) ist gemergt (PR, Commit e63fcc3).

## Recherche (zuerst, mit Quellen)
- **SessionStart-Hook:** Matcher `startup`, `resume`, `clear`, `compact`, `fork`; die `source` entspricht dem Matcher. Klartext auf stdout eines SessionStart-Hooks landet im Kontext; alternativ JSON `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"…"}}`. stderr sieht nur der Nutzer. Formulierung sachlich, nicht als Befehl. Quelle: https://code.claude.com/docs/en/hooks (SessionStart-Abschnitt dort abgeschnitten: Timeout-Details und stdin-Schema nicht gelesen, vor dem Bau am echten Lauf prüfen).
- **„blocked by“ schreiben:** `POST /repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by` mit Body `{"issue_id": <interne ID des blockierenden Tickets>}`, nicht die Ticketnummer. Der Pfad nennt das blockierte Ticket. 201 bei Erfolg, 422 bei Validierungsfehler oder zu schnellem Schreiben (Sekundärlimit). Lesen: `GET …/dependencies/blocked_by`, Entfernen: `DELETE …/dependencies/blocked_by/{issue_id}`. Quelle: https://docs.github.com/en/rest/issues/issue-dependencies

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/next-ticket.sh` | Schnitt 1; liest `dependencies/blocked_by` schon (Zeile ~138), erste Zeile `NEXT=#N|none|unknown` |
| `scripts/test_next_ticket.py` | Skripttests mit Attrappen für `gh` und `herdr` |
| `~/.claude/settings.json` (Abschnitt `hooks.SessionStart`) | zwei Einträge: `loose-ends-sync-main.sh` (ohne Matcher) und `herdr-agent-state.sh` (Matcher alle Quellen) |
| `~/.claude/scripts/loose-ends-sync-main.sh` | Vorbild: filtert auf Loose-Ends-Sitzungen (`$REPO` oder Worktree darunter), defensiv, Exit 0 |
| `docs/specs/tooling/feat-715-s1-next-ticket-skript.md` | Spec von Schnitt 1 |

## Stand der Epics (2026-10-27)
- **#371** (Release): offen #342, #176, #40. Reihenfolge laut Epic-Text: #342 und #40 zuerst, dazu #71 und #88 (liegen in Epic #370), `#176` als letzter Schritt. Heute schlägt das Skript `#40` vor, weil kein „blocked by“ steht; #176 ist nicht zu sehen, weil es noch nicht blockiert ist und deshalb nach Priority/Board vorn liegen könnte.
- **#370** (Modell-Messung): offen #71, #88. Keine Abhängigkeit untereinander im Text.
- **#467** (Mac): offen #584. Keine Abhängigkeit.
- Zu tragen sind also im Kern: #176 blockiert durch #342, #71, #88, #40. Übrige Epics haben heute keine Voraussetzung im Text.

## Existing Patterns
- Hooks in `~/.claude/settings.json`, Skripte unter `~/.claude/scripts/`, Hennings Rechner. Der Hook liegt damit **außerhalb des Repos** und ist nicht versioniert; das Skript, das er aufruft, liegt im Repo (`scripts/next-ticket.sh`).
- Das Skript braucht `HERDR_WORKSPACE_ID` (Sitzungsname = Epic) und `CLAUDE_SESSION_ID`; ob beide im SessionStart-Hook gesetzt sind, ist ungeprüft.

## Dependencies
- Upstream: `gh`, `herdr`, GitHub-Token mit Schreibrecht auf Issues, Board-Spalten.
- Downstream: jede neue Sitzung nach `/clear`; `/00-intake` ohne Nummer soll den Vorschlag nehmen.

## Risks & Considerations
- Der Hook läuft bei **jedem** Start in **allen** Projekten: nur bei Loose-Ends-Sitzungen mit herdr-Namen aktiv werden, nie blockieren (kurzes Zeitlimit, Exit 0 bei jedem Fehler).
- Netzlauf (`gh`) beim Start kann dauern: Zeitlimit setzen, bei Überschreitung still weglassen.
- Wiederholtes Schreiben von „blocked by“ löst das Sekundärlimit aus: Eintragungen mit Pause, vorher lesen, nichts doppelt.
- Der Vorschlag ist ein Hinweis, kein Befehl: im Kontext sachlich formulieren, der Nutzer entscheidet per `/00-intake`.
- **Alternative** (kein Hook): `/00-intake` ohne Nummer ruft das Skript selbst auf. Das liegt im Plugin (nicht in diesem Repo) und ist ein zweiter Weg zum selben Ziel; Vorteil: kein globaler Hook. Nachteil: Ändert das Plugin, nicht das Projekt.
- Gerät: keines berührt.

## Analysis

### Type
Feature (Werkzeug/Prozess, kein Produkt-UI, kein Gerät).

### Befunde am echten Lauf (2026-10-27)
- `./scripts/next-ticket.sh` in Sitzung „#176 Abnahme“ (Epic #371): `NEXT=#40`, **14 s** Laufzeit (viele nacheinander laufende `gh`-Aufrufe). #176 steht nicht in der Abzugsliste, weil nichts es blockiert — heute hängt die Reihenfolge nur im Fließtext.
- `GET …/issues/176/dependencies/blocked_by` liefert `[]`: kein einziges „blocked by“ ist eingetragen.
- Umgebung der Sitzung: `HERDR_WORKSPACE_ID=w3` und `HERDR_ENV=1` sind gesetzt (ein Hook erbt sie, `herdr-agent-state.sh` verlässt sich schon darauf); `CLAUDE_SESSION_ID` ist **leer**. Das Skript schließt mit ihr die eigene Sitzung aus der Fremd-Sperrliste aus (Zeile 148). Der Hook muss die `session_id` deshalb aus seiner stdin-JSON lesen und dem Skript mitgeben.
- Offene Voraussetzungen im Text: nur #176 → #342, #71, #88, #40 (Ticket #176 „Voraussetzungen“ und Epic #371). Epics #370, #369, #468, #373, #688, #642: keine genannte Abhängigkeit, nichts einzutragen. #467 ist nicht mehr offen. Epic #612 (M4) nennt eine Reihenfolge in fünf Stufen (#613 → #614/#615 → #616–#620 → #621–#624 → #625).

### Recherche (Quellen)
- Hooks: https://code.claude.com/docs/en/hooks — SessionStart-`source` = startup/resume/clear/compact; Klartext auf stdout oder JSON `hookSpecificOutput.additionalContext` landet im Kontext; stdin-JSON enthält `session_id`, `cwd`, `source` (bestätigt durch Drittbeschreibungen, https://docs.claude.com/en/docs/claude-code/hooks). Ein dokumentiertes Standard-Zeitlimit für SessionStart fand ich nicht → `timeout` im Eintrag ausdrücklich setzen.
- Abhängigkeiten schreiben: https://docs.github.com/en/rest/issues/issue-dependencies — `POST /repos/{o}/{r}/issues/{n}/dependencies/blocked_by` mit der **internen** `issue_id` (z. B. #342 = `I_kwDO…`-Knoten ist nicht gemeint, die numerische REST-`id` aus `gh api repos/…/issues/342 --jq .id`), 201/422 (zu schnell), Entfernen per DELETE.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/next-ticket-hook.sh` | CREATE | SessionStart-Adapter: liest stdin-JSON, nur `startup`/`clear`, nur Loose-Ends-Sitzung mit `#N` im herdr-Namen, ruft `next-ticket.sh` mit `CLAUDE_SESSION_ID=<session_id>` und Zeitgrenze, gibt den Vorschlag als `additionalContext` aus; jeder Fehler = leere Ausgabe, Exit 0 |
| `scripts/test_next_ticket_hook.py` | CREATE | Tests mit Attrappen (kein Netz): falsche Quelle, fremdes Projekt, kein `#N`, Zeitüberschreitung, Skript-Fehler, Normalfall, Sitzungskennung kommt aus stdin |
| `~/.claude/settings.json` (außerhalb des Repos) | MODIFY | dritter SessionStart-Eintrag, Matcher `^(startup\|clear)$`, `timeout` 30, ruft das Skript im Hauptcheckout (den hält der Sync-Hook aktuell) |
| GitHub (kein Code) | MODIFY | „blocked by“: #176 ← #342, #71, #88, #40; #612-Stufen (siehe unten) |
| `docs/reference/…` oder `CLAUDE.md` | MODIFY (1 Satz) | CLAUDE.md ist Hotspot (Zweig `work/700-neu` ändert sie): bevorzugt `docs/reference/abnahme-und-arbeitsweise.md` |

### Scope Assessment
- Dateien im Repo: 2–3 (+ settings.json außerhalb)
- Geschätzt: +130/−0 LoC
- Risk Level: LOW–MEDIUM. Der Hook läuft global bei jedem Start; Schutz = Filter auf Loose Ends + herdr-Namen `#N`, Zeitgrenze, Exit 0 immer. Schlimmster Fall bei Fehler: kein Vorschlag, wie heute.

### Technical Approach (Empfehlung)
1. **Teil 2 zuerst, von Hand per `gh api`** (einmalige Datenpflege, kein Repo-Code): Vorher `GET blocked_by` lesen, nichts doppelt, 2 s Pause zwischen Schreibaufrufen (Sekundärlimit). #176 ← #342, #71, #88, #40. Für Epic #612 nur die Stufengrenzen als Kanten zwischen dem jeweils nennenden Ticket und seinen Vorgängern der Vorstufe (#614, #615 ← #613; #616 ← #614, #615; #617, #618, #619 ← #616; #620 ← #617, #618, #619; #621 ← #616; #622 ← #621; #623, #624 ← #622; #625 ← #620, #622, #623, #624) — jede Kante steht so in der Reihenfolge des Epic-Texts; im Zweifel weglassen, die Kante ist nur Reihenfolge-Hilfe. Beleg: danach liefert das Skript in Sitzung #371 nicht mehr #176.
2. **Teil 4**: Adapter-Skript im Repo (testbar), Eintrag in `settings.json`. Ausgabe sachlich als Hinweis, Wortlaut: „Vorschlag für das nächste Ticket dieses Epics (Hinweis, kein Auftrag; ist ein Workflow aktiv, geht dessen Pflicht-Schritt vor): …“ — damit er nicht gegen den Hook des aktiven Workflows arbeitet.
3. **Echter Durchlauf**: Adapter mit echter stdin-JSON in dieser herdr-Sitzung; danach beim nächsten `/clear` von Henning sichtbar (kein Gerät, kein Handgriff nötig).

### Alternativen
- **A) Kein Hook: `/00-intake` ohne Nummer ruft das Skript selbst auf** (im Plugin, anderes Repo). Vorteil: kein globaler Hook, die 14 s fallen nur an, wenn jemand fragt. Nachteil: ändert das Plugin statt des Projekts; verfehlt die DoD-Zeile „nach /clear steht der Vorschlag im Kontext“. Wird gewählt, falls der Hook sich als zu langsam oder zu fragil erweist.
- **B) Vorschlag zwischenspeichern** (Stop-Hook/Zeitgeber schreibt eine Datei, SessionStart liest sie): sofort da, aber veraltet; ein zweiter bewegter Teil. Nur nötig, wenn 14 s stören.
- **C) Skript beschleunigen** (parallele `gh`-Aufrufe): löst die Wartezeit an der Wurzel, ist aber eigener Schnitt (Skript Schnitt 1 nachbessern) — als Folge-Ticket vormerken, nicht hier.
- Kippt eine frühere Entscheidung? A/B/C nein; nur „keine Epic-Zuordnung“ (Ticket-Alternative) würde die Entscheidung vom 2026-10-26 kippen — nicht vorgeschlagen.

### Befunde gegen den Plan
- 14 s Wartezeit bei jedem `/clear`/Start in Epic-Sitzungen (Hook ist synchron). Hinnehmbar? Hennings `/clear` kommt ohnehin vor einem Auftrag; Zeitlimit 30 s deckt die Streuung. Wird beim echten Durchlauf gemessen; über 25 s → Alternative C vorziehen.
- `herdr-agent-state.sh` hat 10 s Zeitlimit — läuft parallel, blockiert nicht.

### Dependencies
`gh` mit Schreibrecht auf Issues (Token hat `project`-Scope), `herdr`, `python3`; `next-ticket.sh` aus Schnitt 1 (auf `main`).

### Open Questions
- [ ] Keine Produktfrage an Henning: Technik entscheidet Claude (Hook statt Plugin-Weg, Kantenauswahl #612).
