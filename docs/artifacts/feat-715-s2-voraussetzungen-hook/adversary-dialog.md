# Adversary Dialog — feat-715-s2-voraussetzungen-hook
Spec: docs/specs/tooling/feat-715-s2-voraussetzungen-hook.md
Datum: 2026-10-27 15:12

## Checkliste
- [x] **AC-1:** Given `#176` hat kein „blocked by“, When Teil 2 durchgeführt ist, Then liefert `GET …/issues/176/dependencies/blocked_by` genau #342, #71, #88 und #40, und ein zweiter Durchlauf legt nichts doppelt an.
- [x] **AC-2:** Given Epic #612 nennt seine Reihenfolge in Stufen, When Teil 2 durchgeführt ist, Then entspricht die Liste „blocked by“ je Ticket den Kanten aus Implementation Details Punkt 3, soweit der Epic-Text sie trägt; nicht getragene Kanten sind nicht eingetragen.
- [x] **AC-3:** Given AC-1 erfüllt, When `scripts/next-ticket.sh` in der Sitzung von Epic #371 läuft, Then ist `#176` nicht der Vorschlag.
- [x] **AC-4:** Given die stdin-JSON trägt eine `session_id`, When der Adapter das Skript ruft, Then ist `CLAUDE_SESSION_ID` im Skript diese `session_id` (die Sitzung sperrt sich nicht selbst).
- [x] **AC-5:** Given Quelle `startup` oder `clear`, eine Loose-Ends-Sitzung mit `#N` im herdr-Namen und `NEXT=#N` oder `NEXT=none`, When der Adapter läuft, Then gibt er gültiges SessionStart-JSON mit `additionalContext` aus, der den Hinweissatz („Hinweis, kein Auftrag; ein aktiver Workflow geht vor“) und den Klartext des Skripts enthält.
- [x] **AC-6:** Given Quelle `resume` oder `compact`, ein fremdes Projekt oder ein herdr-Name ohne führende `#N`, When der Adapter läuft, Then ist die Ausgabe leer, das Skript wird nicht aufgerufen, Exit 0.
- [x] **AC-7:** Given das Skript meldet `NEXT=unknown` oder braucht länger als `LOOSEENDS_NEXT_TIMEOUT`, When der Adapter läuft, Then ist die Ausgabe leer, Exit 0, und der Adapter kehrt innerhalb der Zeitgrenze plus 2 s zurück.
- [x] **AC-8:** Given das Skript endet mit Fehler oder stdin ist kein gültiges JSON, When der Adapter läuft, Then ist die Ausgabe leer, Exit 0.
- [x] **AC-9:** `~/.claude/settings.json` enthält in `hooks.SessionStart` den dritten Eintrag (Matcher `^(startup|clear)$`, `timeout` 30, Befehl auf `next-ticket-hook.sh` im Hauptcheckout); die zwei bisherigen Einträge sind unverändert.
- [x] **AC-10:** Der Adapter wurde in dieser herdr-Sitzung mit echter stdin-JSON (`source` = `clear`) gelaufen; die Ausgabe ist gültiges JSON, die Laufzeit ist gemessen und im Abschlussbericht genannt. Liegt sie über 25 s, wird Alternative C als Folge-Ticket angelegt.
- [x] **AC-11:** `docs/reference/abnahme-und-arbeitsweise.md` beschreibt den Hook: wann er greift, den Hinweiswortlaut, dass er nie blockiert, und wie man ihn abschaltet.

## Dialog

### Runde 1
**Adversary:** Eigene Läufe. `python3 scripts/test_next_ticket_hook.py -v`: 13 Tests, OK, 0 übersprungen (Ausgabe: adversary-test-output.txt); `scripts/test_next_ticket.py`: 23 Tests OK. Randfälle gegen scripts/next-ticket-hook.sh mit Attrappen für herdr und next-ticket.sh, jeder Fall Exit 0, stdout leer oder gültiges JSON:
- Pfad mit gleichem Präfix (`/Users/hem/Developer/loose-ends-other`, `-other/x`): still ("fremdes Projekt"). Case-Muster `"$CHECKOUT"|"$CHECKOUT"/*` hält. Pfad mit Schrägstrich am Ende: bedient (korrekt).
- Label `#abc`, `#`, ` #12` (führendes Leerzeichen): still. Label `#12abc`: bedient (LOW, harmlos).
- Skript, das nach der Grenze Kindprozesse hält (zwei sleep 30, Grenze 2 s): Rückkehr nach 2,1 s, still (Prozessgruppe wird per SIGKILL beendet, kein Hängen an der Pipe). AC-7 erfüllt.
- Ausgabe mit Anführungszeichen, Backslash, geschweiften Klammern: gültiges JSON (json.dumps), Zeichen unverändert.
- leere erste Zeile, `NEXT=unknown`, fehlendes Skript (Exit 127), Exit 3, `LOOSEENDS_NEXT_TIMEOUT=abc` (Skript bricht mit Exit 1, still): alles still, Exit 0.
- stdin leer, `[1]`, JSON mit null-Feldern, `source` als Zahl, Zeilenumbruch im Pfad oder in der session_id: still, Exit 0.
- herdr nicht im PATH, HERDR_WORKSPACE_ID leer: still.
- `NEXT=none` mit Grundzeile: wird weitergegeben (AC-5).
- Ein Pfad mit zwei Punkten aus dem Checkout hinaus wird als zugehörig gewertet (reiner Textvergleich): LOW, praktisch ohne Folge.
AC-9: Die Einstellungsdatei im Home-Verzeichnis gelesen. SessionStart hat drei Einträge: 1) loose-ends-sync-main.sh ohne Matcher, 2) herdr-agent-state mit Matcher `^(startup|resume|clear|compact|fork)$`, timeout 10, 3) `^(startup|clear)$`, `bash /Users/hem/Developer/loose-ends/scripts/next-ticket-hook.sh`, timeout 30. Gültiges JSON: der Test test_settings_has_third_entry_and_keeps_others lädt sie per json.loads und läuft grün (nicht übersprungen). Die ersten zwei Einträge sind gegen OLD_ENTRIES im Test (Zeile 155) gleich. Der Python-Einzeiler zum Prüfen wurde von einem Plugin-Hook blockiert, darum der Weg über Lesen und den Test.
AC-1/2 (nur lesend): blocked_by für #176 = 342, 71, 88, 40; #614 = 613; #615 = 613; #616 = 614, 615; #613 leer. Kein Doppeleintrag. #617 bis #625 haben keine Einträge.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Gezielt gegen die schwachen Stellen.
- AC-2: Spec Teil 2 Punkt 3 nennt auch #617 bis #625. Der Epic-Text #612 nennt nur Phasen und "Reihenfolge", keine Kanten. Eingetragen sind 613 -> 614/615 und 614/615 -> 616, das sind die Phasengrenzen 1->2 und 2->3. Nach demselben Maßstab wären auch 3->4 und 4->5 Grenzen. Dass hier gestoppt wurde, ist nach dem Spec-Wortlaut ("soweit der Epic-Text sie trägt; nicht getragene Kanten sind nicht eingetragen") vertretbar, die Grenzziehung ist aber nirgends belegt. Bewertung: AMBIGUOUS (F002).
- AC-3 und AC-10: Echter Lauf des Adapters mit der echten stdin-JSON und echtem herdr (Label "#176 Abnahme" -> Epic #371): Exit 0, gültiges JSON, hookEventName SessionStart, additionalContext beginnt mit dem Hinweissatz, danach Klartext `NEXT=#40 ...`. Laufzeit 17,2 s gesamt (unter 25 s, kein Folge-Ticket nach AC-10 nötig). #176 ist nicht der Vorschlag. Der Blocker steht aber NICHT in der Ausgabe: scripts/next-ticket.sh betrachtet nur Blatt-Tickets (Zeilen 92, 109, 134 bis 139: blocked_by wird nur für Kandidaten geholt); #176 hat offene Teil-Tickets und war nie Kandidat, auch vorher nicht. Der zweite Halbsatz von AC-3 ist mit unverändertem next-ticket.sh (laut Spec nicht Teil des Schnitts) nicht erreichbar, die Prämisse der Spec trifft nicht zu. Bewertung: als Datenpflege tragbar (Kanten stehen für den Fall, dass #176 Blatt wird), aber der Wortlaut von AC-3 ist nicht erfüllt, daher AMBIGUOUS (F001), Spec-Korrektur durch den Menschen.
- LOOSEENDS_CHECKOUT statt LOOSEENDS_REPO: scripts/next-ticket.sh Zeile 22 benutzt LOOSEENDS_REPO bereits als GitHub-Repo (owner/name). Dieselbe Variable für einen Dateipfad hätte beim Durchreichen das Skript zerstört. Die Abweichung ist begründet und richtig; der Test dokumentiert sie (Zeile 6). Kein Befund, Spec-Text sollte nachgezogen werden.
- AC-11: Abschnitt in docs/reference/abnahme-und-arbeitsweise.md ab Zeile 135: Auslöser (Quelle, Checkout, `#N`), Wortlaut des Hinweises (identisch mit Zeile 22 des Skripts), 25 s, "blockiert nie", Abschalten durch Entfernen des Eintrags.
- Regression: im Repo nur die Doku geändert (plus neue Dateien); scripts/next-ticket.sh unangetastet; die zwei einschlägigen Testdateien grün.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 3
**Adversary:** Nachprüfung nach Spec-Nachbesserung (AC-3 gekürzt, Folge-Ticket #723, LOOSEENDS_CHECKOUT, Epic-#612-Kanten nur 1->2 und 2->3). Code unverändert.
- AC-3 (neuer Wortlaut): `bash scripts/next-ticket.sh` in der Sitzung „#176 Abnahme“ liefert `NEXT=#40` (Icon-Composer-Paket), Zeile „#176 gehört zu Epic #371“. #176 ist nicht der Vorschlag. Belegt, selbst gelaufen.
- AC-1: `gh api .../issues/176/dependencies/blocked_by` = [342,71,88,40], unverändert.
- AC-2: #616 = [614,615]; #617 bis #625 je [] (alle neun einzeln geprüft). Entspricht der nachgebesserten Spec (Übergänge 1->2 und 2->3, nicht getragene Kanten nicht eingetragen). F002 damit durch Spec-Änderung erledigt.
- Spec und Code: `LOOSEENDS_CHECKOUT` steht in scripts/next-ticket-hook.sh (Zeilen 13, 19) und in der Spec (Zeile 101); `LOOSEENDS_REPO` kommt im Adapter nicht vor, in der Spec nur als ausdrücklich nicht gelesene Variable. Übereinstimmung belegt.
- F001 (Blocker in der Ausgabe) ist durch die Spec-Änderung erledigt, das Anliegen liegt in #723. F003 bleibt LOW ohne Handlungsbedarf.
- Alle übrigen Punkte unverändert: Code ist unverändert gegenüber Runde 1/2.
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Findings
Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: scripts/next-ticket-hook.sh:66
  Description: Der Adapter reicht die Ausgabe von next-ticket.sh unverändert durch; der Blocker von #176 erscheint dort nie, weil #176 als Nicht-Blatt kein Kandidat ist.
  Spec requirement: AC-3 — "#176 ist nicht der Vorschlag und der Blocker steht in der Ausgabe"
  Conflict: Erste Hälfte erfüllt (Vorschlag ist #40), zweite Hälfte nicht erreichbar ohne Änderung an next-ticket.sh (laut Spec ausgeschlossen). Prämisse der Spec war falsch.
  Remediation: AC-3 durch den Menschen auf "#176 ist nicht der Vorschlag" kürzen, oder Folge-Ticket für Ausgabe der Blocker auch bei Nicht-Blättern.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: scripts/test_next_ticket_hook.py:149
  Description: GitHub-Kanten für #617 bis #625 fehlen; kein Beleg im Repo, warum der Schnitt bei #616 endet.
  Spec requirement: AC-2 — Kanten aus Teil 2 Punkt 3, "soweit der Epic-Text sie trägt"
  Conflict: Epic-Text nennt nur Phasen, nach Wortlaut vertretbar; Grenze uneinheitlich (1->2 und 2->3 eingetragen, 3->4 und 4->5 nicht).
  Remediation: Entscheidung im Abschlussbericht festhalten oder Phasengrenzen einheitlich eintragen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/next-ticket-hook.sh:63
  Description: Regex `^#[0-9]+` akzeptiert "#12abc"; Pfade mit zwei Punkten werden als Checkout gewertet (Zeilen 50 bis 53).
  Spec requirement: AC-6 — herdr-Name ohne führende #N bleibt still
  Conflict: "#12abc" hat führende #12; nur Grenzfall, harmlos.
  Remediation: keine nötig.

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: scripts/test_next_ticket_hook.py:98
  Evidence: GET blocked_by #176 = 342, 71, 88, 40, nichts doppelt.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/next-ticket-hook.sh:66
  Evidence: Echter Lauf von scripts/next-ticket.sh in der Sitzung von Epic #371: NEXT=#40, #176 nicht der Vorschlag; blocked_by von #176 = [342,71,88,40].
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_next_ticket_hook.py:98
  Evidence: #616 = [614,615], #617 bis #625 leer, wie die nachgebesserte Spec es fordert.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/next-ticket-hook.sh:66
  Evidence: CLAUDE_SESSION_ID wird aus der session_id gesetzt; Test test_session_id_from_stdin_reaches_script grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/next-ticket-hook.sh:90
  Evidence: gültiges SessionStart-JSON mit Hinweissatz und Klartext, auch mit Anführungszeichen und Backslash; echter Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/next-ticket-hook.sh:44
  Evidence: resume/compact, Präfix-Pfad, Label ohne Zahl: still, Exit 0, Skript nicht gerufen.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/next-ticket-hook.sh:83
  Evidence: Kindprozess-Attrappe bei Grenze 2 s kehrt nach 2,1 s zurück; NEXT=unknown still.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/next-ticket-hook.sh:32
  Evidence: kaputtes oder leeres stdin, Skriptfehler (Exit 3, 127): still, Exit 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: scripts/test_next_ticket_hook.py:149
  Evidence: drei Einträge, dritter Matcher ^(startup|clear)$, timeout 30; Test nicht übersprungen.
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: scripts/next-ticket-hook.sh:95
  Evidence: Echter Lauf mit der stdin-JSON: 17,2 s, Exit 0, gültiges JSON.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/reference/abnahme-und-arbeitsweise.md:135
  Evidence: Abschnitt mit Auslöser, Wortlaut, nie blockierend, Abschalten.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

F001 und F002 sind durch die Spec-Änderung (2026-10-27) erledigt; F003 LOW ohne Handlungsbedarf.

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: 13 passed, 0 failed, 0 übersprungen (test_next_ticket_hook.py); 23 passed (test_next_ticket.py)
Edge cases: All checked, none broken
Regressions: None found
Checklist: 11/11 points proven

## Geprüfte Dateien

- sha256:9ffc7101e964bf6e3169bd6020e0db53813fa09fe0df1e854dcda241d8cf59e2  docs/reference/abnahme-und-arbeitsweise.md
- sha256:906808b782879c8c76a3832006cf80c58a42b1ff5f5cd904ca52a0bbd9b0fa2e  scripts/next-ticket-hook.sh
- sha256:7fc6c7ba68a9163805bcc7c2dae166bd499d734f830927c46703260b7c05d800  scripts/test_next_ticket_hook.py

## Prüfbasis

- base: 0ea113c2ddcf56fa03bcbf7aea84c76cbe5ca819
- blob:6dcf7c9f58459bf5a5482243229479e6c7238261  docs/reference/abnahme-und-arbeitsweise.md
- blob:539da12fbf735b801ea5d92f4784d410d92542d2  scripts/next-ticket-hook.sh
- blob:678845c3a6ae93fd340726a3014eadb10e256045  scripts/test_next_ticket_hook.py
