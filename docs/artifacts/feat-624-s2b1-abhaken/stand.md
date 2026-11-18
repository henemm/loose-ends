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

## Stand 2026-11-18 (nach Auslieferung)

- Roter UI-Test (#939) war zu knappe Wartezeit der Dateiauswahl; Fix PR #948 (4121651).
- #947 gemergt als beda7d3; henemm-infra#468; Dienst läuft auf beda7d3 seit 2026-11-18T00:19Z (/health 200).
- Henning hat in claude.ai für Loose Ends „Immer erlauben“ gesetzt. Erste Prüfaufgabe hat er gelöscht.
- claude.ai, Chat „Prüfaufgabe Fenster #624“, get_view now, dunkel: Kreisknopf auf jeder Zeile (serverTools da) → `claude-ai-now-dunkel-knopf.png`.
- Neue Prüfaufgabe per capture_task, orderID D1B65D04-A73D-4C0F-A010-F69905A38411, wartet, bis ein Gerät die App öffnet (Weckruf erst mit #795 S5c-2).

Weiter: get_order_result für diese orderID → done; dann im selben Chat get_view now, NUR bei der Prüfaufgabe den Knopf drücken,
Wartezeile/Haken ansehen, hell + dunkel (Farben per getComputedStyle), Bilder hier ablegen; dann Schritt 4 oben.

- 2026-11-18 (neue Sitzung): orderID D1B65D04… weiter `waiting` — kein Gerät hat die App seither geöffnet. Wartet darauf, dass Henning die App einmal öffnet; dann weiter wie oben.
- 2026-11-18 ~18:50Z: Gerät hat die Prüfaufgabe übernommen (Ergebnis done). In claude.ai get_view open: Tipp nur bei „Prüfaufgabe Fenster #624“ → „Abgehakt, wartet …“, nach ~70 s „Noch nicht übernommen …“; dunkel und hell (Darstellung danach zurück auf System). Bilder `claude-ai-open-*.png`. Adversary Runde 3: VERIFIED 10/10.
- Testausgabe fürs QA-Gate: lokal 482/483, rot nur #869 (migrate-Sperrtest, nur lokal); deshalb server.yml-Lauf 44206668992 auf beda7d3 neu gestartet, 483/483, dessen Log als `adversary-test-output.txt`.
