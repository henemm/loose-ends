# Stand #978 Schnitt 1, Phase 6b (Adversary), 2026-11-22

Wiedereinstieg: `/50-implement #978`, Step 8 fortsetzen.

## Erledigt
- Umsetzung committet (248ca7b) auf `fix/978-panel-schliesst`, PR #981 (Refs #978), Board „In review“.
- GREEN auto-freigegeben, `test-green-output.txt` registriert (inkl. „Nachbesserung Runde 1“).
- Adversary Runde 1 (AMBIGUOUS, F001–F003) und Runde 2 (F001–F003 geschlossen, Code VERIFIED) im Protokoll
  `adversary-dialog.md`, gestempelt. AC-4 und AC-6 abgehakt.
- PO tippte „override“ (2026-11-22), damit der Commit vor dem CI-Lauf möglich war (Henne-Ei: AC-1/2/3/5 brauchen den PR-Lauf).

## Offen (nächste Schritte)
1. CI-Lauf 44993915314 abwarten (Job „Mac Gallery (macOS)“ 137120755192).
2. Belege holen (gefiltert): Ergebnis von `testMenuBarReopensAfterOpenAppWithOneClick` (ausgeführt, nicht übersprungen; ggf.
   erwarteter Fehler); Artefakt `MacGalleryPanelLog` nach `docs/artifacts/fix-978-panel-schliesst/ci-<run>-panel.log`, Zeilen
   öffnen und beschreiben (key/close, window=, event=, front=, policy=, stack=; keine Nutzerdaten). Job beim ersten Versuch grün?
3. Adversary Runde 3 (implementation-validator) mit diesen Belegen: AC-1, AC-2, AC-3, AC-5 abhaken, Verdict, Protokoll neu
   stempeln (alten Stempelblock entfernen), registrieren (`add-artifact adversary_dialog`), dann
   `qa_gate.py adversary-test-output.txt --checklist adversary-dialog.md --infra --no-visual "Mac-UI nur in CI"`.
4. `workflow.py phase phase7_validate`, dann `/60-validate #978`.
5. Nach Merge: Draft-PR #975 schließen, Zweig `diag/862-panel-schliesst` löschen, Stichtag der Ernte (≥ 15 Läufe) als Kommentar
   in #978; Issue bleibt offen.

## Nachtrag 2026-11-22 (Runde 3)
- PR-Lauf 44994038524: Mac-Job grün beim ersten Versuch, Test ausgeführt und bestanden (AC-1, AC-2, AC-5 belegt).
  Artefakt `ci-44994038524-panel.log`: 23 key-, 0 close-Zeilen → F004 (HIGH, AC-3): Panel wird ausgeblendet, nicht geschlossen.
- Nachbesserung (resign/hide, ohne zusätzliches applyDockPolicy) liegt UNCOMMITTET im Worktree; Prüfskript 12/12, Mac- und iOS-Bau grün.
- Commit-Gate blockt (kein VERIFIED) → PO tippt „override“, dann committen, pushen, neuer Mac-Lauf, Belege holen
  (resign/hide-Zeilen im Panel-Log), Adversary Runde 4, stempeln, registrieren, qa_gate, Phase 7.
