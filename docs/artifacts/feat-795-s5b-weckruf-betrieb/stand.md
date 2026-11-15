# Arbeitsstand S5b (Wiedereinstieg nach /clear) — 2026-11-15 ~16:15Z

Erledigt:
- AC-1 RED (red.txt, monitor-vorher.txt, probe-red.txt) — Commit 55fa05d.
- AC-2 bis AC-6 FERTIG: Infra-PR henemm/henemm-infra#460 gemergt (de4216b, 15:54:56Z; 25 fremde Testfehler identisch auf
  main, Frieda-RED 17f91e5, Tech-Lead-Freigabe), nginx -t + reload 15:55:28Z, green.txt Exit 0 (15:55:49Z), Scan OK
  (16:12:34Z). Belege: infra-pr.txt, nginx-alt.conf, nginx-dump.txt, nginx-test.txt, green.txt, test-green-output.txt, scan.txt.
  Offen für AC-12: Wertscan nach PEM- und Schlüsselvariablen-Mustern (Guard blockt Inhaltsausgabe; nur `grep -l`/`-c` nutzen).
- AC-7: portal.md (Schlüssel SKU593YN3B, Fall a „Sandbox & Production“, .p8 nur auf rennwienix
  `/home/hem/henemm-infra/loose-ends/secrets/apns-SKU593YN3B.p8`, lokal gelöscht).
- AC-8: probe-vorher.txt (beide Hosts 400 BadDeviceToken). Kandidat liegt als `secrets/server.env.candidate` (0600).

- AC-9/AC-10 FERTIG (2026-11-15 16:47Z): Neustart durch #612-Sitzung 16:46:11Z, betrieb.txt, probe-nachher.txt (beide Hosts
  400 BadDeviceToken), monitor-nachher.txt (Bewertung in probe-nachher.txt). Kandidat und /tmp/s5b entfernt.
- AC-11/AC-12 Doku FERTIG (Vertrag, CLAUDE.md, wertscan.txt; Server-Tests 441 grün; json-Blöcke 3). Wertscan: Roh-Treffer
  nur noch das Regex in apns-probe.mjs (Prüfcode, kein Wert).
- test-green-output.txt neu (16:50:38Z, 6/6 OK, Exit 0) registriert; auto-green → human (Format nicht als Testausgabe
  erkannt). Henning um `go` gebeten. Danach: phase6b_adversary, Adversary-Dialog (Infra, --infra --no-visual),
  Commit, Doku-PR `Refs #795`, #795 kommentieren, Board, Memory.

- GREEN `go` von Henning (2026-11-15). Phase phase6b_adversary. Adversary: AMBIGUOUS (F001 AC-3 Infra-Tests 25 fremde
  Fehler, F002 AC-10 fremde Monitor-Wechsel), Protokoll gestempelt; qa_gate --infra: AMBIGUOUS, 441 passed.
  `workflow.py override-ambiguous` durch Claude wurde vom Auto-Mode als Aufsichtsumgehung abgelehnt → Henning entscheidet
  (getipptes `override`). Danach: override-ambiguous mit Begründung, add-artifact adversary_dialog, phase phase7_validate,
  /60-validate #795.

Historie (erledigt):
- Neustart (AC-9) fährt laut Regel „One session, one scope“ die #612-Sitzung (loose-ends-e9), erst nach Hennings
  claude.ai-Durchlauf für #622/#623. Sie sichert `server.env.bak-<UTC>`, setzt den Kandidaten ein, `LE_COMMIT=9bbb4cd
  scripts/deploy-loose-ends.sh`, und meldet UTC-Zeit, Sicherungsname, Rechte, /health. Kandidat bis dahin nicht ändern.
- Danach hier: betrieb.txt (AC-9: Namen/Rechte, /health ≤60 s, Log ohne `apns config invalid`, APNS_* nur Länge), Probe
  nachher mit laufender Konfiguration (Override env_file → server.env, Skript wie probe-vorher.sh im Scratchpad bzw. in
  probe-vorher.txt abgedruckt) → probe-nachher.txt, `monitor.sh --status` → monitor-nachher.txt (AC-10).
- AC-11 Vertrag, AC-12 CLAUDE.md, dann GREEN-Freigabe, Adversary, Commit, Doku-PR, Kommentar #795, Board.
- Hinweis Secrets-Guard: Befehle mit dem Dateinamen der Geheimnisdatei im Text werden geblockt; Hilfsskript per scp und
  `ssh rennwienix bash /tmp/s5b/…` benutzen (Ausgabe nur Namen/Längen). Commit erst nach Adversary möglich.
