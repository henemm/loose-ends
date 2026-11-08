# Validierung #621 S6b (Phase 7) — 2026-11-08

## Läufe

| Lauf | Ergebnis |
|---|---|
| `check-outside.sh` von außen, 14:28Z | Exit 0, 12/12 OK, 0 übersprungen, Zeilen wortgleich mit `green.txt` |
| `server/scripts/test-local.sh` (Postgres 18, typecheck + `node --test`) | 380 passed, 0 failed, 0 skipped (Stand S6a, kein Dienstcode geändert) |
| `scripts/test_catalog_languages.py`, `scripts/test_cloudkit_schema.py` | 8 + 2 OK |
| henemm-infra `pytest tests -q` (Adversary-Lauf auf rennwienix, `ec1aa61`) | 460 passed, 6 skipped |

Die 6 Übersprungenen der Infra-Suite: Der Quelltext von `ec1aa61` kennt genau zwei Skip-Gründe:
`tests/test_smtp_auth.py` und `tests/test_smtp_e2e.py` („MAIL_USER / MAIL_PASS nicht gesetzt“, Mail-Zugangsdaten,
fremder Dienst) sowie `tests/test_cleanup_gz_worktrees_secrets.py` („acl-Tools fehlen“, auf rennwienix vorhanden).
Die sechs `s` stehen im letzten Block der Ausgabe, wo die SMTP-Dateien alphabetisch liegen. Keiner betrifft
loose-ends. Ein Lauf mit `-rs` auf dem Mac kam nicht zustande (fehlende Python-Abhängigkeit `flask`, Installation
nicht freigegeben). Der Lauf auf dem Server ist der maßgebliche.

## Befunde des Abgleichs mit den ACs, nachgeprüft

- **AC-16, Testname:** gemeldet als „existiert nicht“. Falsch: `server/test/oauth-return.test.ts:536`
  „rueckweg: fremde sub ergibt access_denied ohne konto und ohne token“ besteht, dazu `:560` (fremde sub auf der Liste
  kommt durch) und `server/test/accounts.test.ts:289–297` (`admit` mit Liste). `tuer.md` zitiert richtig.
- **AC-10, Zeilen anderer Dienste im Diff:** Die Zeilen „Frieda: Software-Stand … e8f8bee → 82c5a5d“ und
  „testreise-…: gebaut mit Stand …“ stammen vom eigenen Abgleich von Frieda: `henemm/frieda-reist@82c5a5d` wurde um
  2026-11-08T11:24:49Z gemergt (Frieda #349) und von dessen automatischem Nachziehen geholt (frieda-reist#161), nicht
  von diesem Schnitt. `auto-deploy-infra` zeigt den neuen Infra-Stand `ec1aa61` (dieser Schnitt, erwartet). Übrige
  Unterschiede sind Zeitangaben, Zähler und Hostwerte. Keine Statuszeile eines anderen Dienstes kippte; `docker ps`:
  nur `loose-ends-server` neu gestartet, alle anderen Container mit unverändertem Startzeitpunkt; `uptime` 22 Tage.
  Hostwerte: CPU kurz gelb nach dem Docker-Build, Disk war vorher schon rot (95 % → 96 %), Adversary F003.
- **AC-5, CI grün:** henemm-infra hat keine GitHub-Actions; wörtlich nicht erfüllbar. Ersatz Repo-Suite auf dem
  Server (`infra-pr.txt`, Adversary F004), offen dargelegt.
- **AC-9, „nach 10 s wieder 200“:** Die Einzelanfrage nach der Zone traf zuerst die fail2ban-Sperre (Firewall, nicht
  nginx). Nach dem Aufheben der Sperre (≈ 1 min nach der Salve) antwortete die Zone mit 200. Das Aufheben ändert den
  Zustand der nginx-Zone nicht; belegt ist also: die Zone lässt nach Ablauf wieder durch. Der Nebenbefund (fail2ban
  sperrt einen Client nach 10 Zonentreffern eine Stunde) ist als henemm-infra#397 offen.
- **AC-18, Belege-PR:** folgt mit dem Abschluss dieser Phase.
- **AC-4, Dateiliste in `secrets-scan.txt`:** Der Scan lief um 13:45Z; `scan.txt`, `adversary-dialog.md` und
  `adversary-test-output.txt` entstanden danach. Für sie gilt die Suche dieses Abgleichs (kein PEM-Beginn, kein
  JWK-`"d"`, kein Muster einer Apple-`sub`; Treffer nur Musterbeschreibungen im Prüfprotokoll).

## Umfang

loose-ends: `CLAUDE.md` (+5/−1), Belegordner (Skript 50 Zeilen, übrige Text), Workflow-Dokumente. henemm-infra #396:
drei Dateien, +71/−6. `server/` unberührt. 5 Pfade, Code und Konfiguration 133 Zeilen.
