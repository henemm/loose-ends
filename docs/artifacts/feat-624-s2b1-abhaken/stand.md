# Stand #624 S2b-1 (2026-11-17, ca. 17:30Z)

- Umsetzung uncommittet im Worktree (`server/src/app-ui.ts` +128/−15, `CLAUDE.md` +1/−1); Tests in e299855.
- GREEN: 482/483 (rot nur #869 migrate-Sperrtest, lokal bekannt); Wiederholung 483/483 (`adversary-test-rerun-output.txt`). Henning `go`.
- Adversary: AMBIGUOUS, einziger offener Punkt AC-10 (Ausrollen + Sichtprüfung claude.ai). AC-1..9 belegt.
  Findings LOW, nicht blockierend: F001 Host-Nachricht ohne `jsonrpc` mit `kind:"tap"` gilt als Shell-Ereignis (Host ist vertrauenswürdig);
  F002 `pending` als Objekt, Antwort-id `"constructor"` trifft den Prototyp (Anzeige unverändert). Beides im PR vermerken.
- Gestempelt, registriert; QA-Gate CHECKLIST FAILED nur wegen AC-10 (Zirkel wie S2a, Memory openspec-ac14-gate-kein-aufschub).
- LoC: Produktcode +128/−15, Tests +247; Gesamt +376/−18 über ±250, Überhang im Testbudget (wie S2a).

## Danach (mit Hennings `override`)

1. Commit (feat: Abhaken aus dem Fenster, #624 Schnitt 2b-1, Refs #624) inkl. Artefakte und stand.md; PR mit `Refs #624`, CI, Squash-Merge.
2. henemm-infra: `LE_COMMIT` auf den Merge-SHA (Worktree auf rennwienix, Autor-Mail noreply), mergen,
   `ssh rennwienix bash /home/hem/henemm-infra/scripts/deploy-loose-ends.sh`, `/health` prüfen; Commit + UTC hier festhalten.
3. claude.ai im Chrome (zuerst `list_connected_browsers`), Connector „Loose Ends“: Prüfaufgabe per capture_task
   („Prüfaufgabe Fenster #624 – darf abgehakt werden“), `get_view now`; erster Prüfpunkt: erscheint der Kreisknopf (serverTools)?
   Knopf + Wartezeile hell und dunkel, Haken oder „Noch nicht übernommen …“; Farben per getComputedStyle. Nur die Prüfaufgabe abhaken.
4. Adversary-Runde für AC-10, stamp, add-artifact, qa_gate --infra → VERIFIED, `phase phase7_validate`, `/60-validate`.
