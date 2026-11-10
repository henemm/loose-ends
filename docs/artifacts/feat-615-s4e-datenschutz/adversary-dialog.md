# Adversary Dialog — feat-615-s4e-datenschutz
Spec: docs/specs/feat-615-schnitt-4e-datenschutz.md
Datum: 2026-11-10 22:10

## Checkliste
- [x] **AC-1:** Kurzfassung korrigiert: GIVEN `docs/reference/datenschutz-entwurf.md` WHEN der Abschnitt „Kurzfassung für Nutzer“ und der Abschnitt „Wo es liegt“ gelesen werden THEN enthalten sie weder den heutigen Satz „Es gibt keinen eigenen Server, kein Konto bei uns, …“ noch „keinen eigenen Server“ noch „Kein eigenes Backend“, und die Kurzfassung verweist auf die freiwillige Verbindung zu Claude im Wortlaut von Punkt 1 und 2 oben.
- [x] **AC-2:** Konto-Abschnitt vollständig (deutsch): GIVEN der Entwurf WHEN der Abschnitt „Wenn du die Verbindung zu Claude nutzt“ gelesen wird THEN steht er nach „Wo es liegt“ und vor „Welche Rechte und warum“, trägt wörtlich den freigegebenen Text von Punkt 3 und enthält die Aussagen: nur Apple, kein Name und keine E-Mail, Sitzung nur als Prüfsumme und 90 Tage, Aufträge aus Claude mit Inhalt bis zur Kontolöschung, Hetzner in Deutschland, Protokolle mit IP-Adresse 14 Tage nach Art. 6 Abs. 1 lit. f DSGVO, Sicherungen höchstens 30 Tage, „Konto löschen“ entfernt das Konto samt Daten und widerruft bei Apple, Freiwilligkeit.
- [x] **AC-3:** Keine Behauptung ohne Beleg: GIVEN der Entwurf WHEN der Konto-Abschnitt auf Aufgabenübertragung geprüft wird THEN kommt weder „Abschrift“ noch eine Aussage vor, dass die App Aufgaben zum Dienst hochlädt; und jede Aussage des Abschnitts hat eine Zeile der Beleg-Tabelle mit Datei, Migration, Issue oder Beleg aus dem Belegordner; die Tabelle ersetzt die Zeile „Kein eigenes Backend, keine Fremd-SDKs“ und nennt den Konto-Teil als einzigen Ort für `URLSession`.
- [x] **AC-4:** Löschhinweis erweitert: GIVEN der Entwurf WHEN „Verantwortlicher und Kontakt“ gelesen wird THEN nennt der Löschsatz zusätzlich „Konto löschen“ in den Einstellungen der App (Wortlaut Punkt 4); die Knopfbezeichnungen im Text sind gegen die Kataloge gelesen (Beleg `knoepfe.txt`: Katalogschlüssel und Wort je Sprache).
- [x] **AC-5:** Englisch inhaltsgleich: GIVEN der Abschnitt „English“ im Entwurf WHEN er mit dem deutschen verglichen wird THEN enthält er die vier Änderungen (Abschnitt 2, 3, neuer Abschnitt 4, Löschsatz im Abschnitt 7, bisher 6) im oben angegebenen Wortlaut, ohne Zusätze und Kürzungen; die Zahlen 14, 30 und 90 stehen in beiden Sprachen; „Last updated“ trägt das Veröffentlichungsdatum; die Statuszeile des Abschnitts nennt die Freigabe und die englische Website-Seite.
- [x] **AC-6:** Prüfskript: GIVEN `scripts/test_datenschutz_text.py` (ein `unittest.TestCase`, wie die übrigen Skript-Tests) WHEN der CI-Befehl `python -m unittest discover -s scripts -p 'test_*.py'` läuft THEN ist es grün und prüft im Entwurf je Sprache (a) die Kernaussagen per Regex („14 Tage“/„14 days“, „30 Tage“/„30 days“, „90 Tage“/„90 days“, „Hetzner“, „Deutschland“/„Germany“, „Konto löschen“/„Delete account“, „Art. 6 Abs. 1 lit. f“/„Art. 6(1)(f)“), (b) dass die veralteten Wendungen des heutigen Textes („keinen eigenen Server“, „Kein eigenes Backend“, „no server of our own“, „No backend of our own“) im ganzen Entwurf fehlen; „kein Konto bei uns“/„no account with us“ ist nicht verboten, weil der neue Konto-Abschnitt es absichtlich sagt („Ohne sie gibt es kein Konto bei uns …“), (c) dass „Abschrift“/„transcript“ im Konto-Abschnitt fehlt. Es läuft in der CI des Repos mit.
- [x] **AC-7:** RED vorher: GIVEN das Skript und der unveränderte Entwurf WHEN das Skript läuft THEN ist es rot, und der Beleg `red.txt` zeigt die fehlenden Aussagen (mindestens 14 Tage, 30 Tage, 90 Tage, Hetzner, Konto löschen) und die vorhandenen veralteten Sätze.
- [x] **AC-8:** `CLAUDE.md` aktuell: GIVEN `CLAUDE.md` WHEN der Datenschutz-Absatz unter „Build“ gelesen wird THEN nennt er, dass der Text seit dem Veröffentlichungsdatum den Konto-Teil enthält (Verweis auf diese Spec), dass der Store-Schalter `LEAccountEnabled` bis #625 aus bleibt und die Sicherungsfrist 30 Tage beträgt; die übrigen Sätze des Absatzes bleiben unverändert.
- [x] **AC-9:** Standort und Protokollfrist belegt (lesend): GIVEN `rennwienix` und die Hetzner-Cloud-Angaben WHEN in der Umsetzung lesend geprüft wird — `/etc/logrotate.d/nginx` und das Rechenzentrum aus dem Metadatendienst (`http://169.254.169.254/hetzner/v1/metadata/availability-zone`) über SSH auf `rennwienix`, ersatzweise `hcloud server describe`; kein Schreiben, kein Neustart; dieser Lesezugriff braucht eine Freigabe der Sitzung für Lesen am Live-Server, die in der Spec-Phase nicht vorlag (in der Analyse wurde `rotate 14` dort schon gelesen) — THEN zeigt `protokolle.txt` `daily` und `rotate 14` für den nginx-Zugriffsprotokoll-Eintrag, und `standort.txt` nennt den Standort (erwartet Nürnberg, nbg1); lautet das Ergebnis anders als „Deutschland“ oder „14“, wird der Wortlaut angepasst und neu zur Freigabe vorgelegt, bevor etwas veröffentlicht wird.
- [x] **AC-10:** Reihenfolge, Sicherungsfrist gilt vor der Veröffentlichung: GIVEN `henemm/henemm-infra#421` WHEN der Website-PR gemergt werden soll THEN ist #421 geschlossen und `restic snapshots --path /home/hem/backups/loose-ends` (nur lesend; auf `rennwienix` gegen das off-site Repository mit den Zugangsdaten aus dessen Sicherungsskript oder auf dem Heimserver, der das Repository trägt und dort ausdünnt; `rennwienix:/home/hem/backups/loose-ends/` selbst hält nur den jüngsten Dump) zeigt keinen Snapshot älter als 30 Tage (Beleg `sicherung.txt` mit Befehl, Zeitpunkt, Zahl und ältestem Datum); ist die Frist erst im selben Zug gesetzt, zeigt der Beleg den Lauf der Aufbewahrung (`forget --prune` nach `--keep-within 30d`) und danach dieselbe Zählung; vorher wird der Website-PR nicht gemergt.
- [x] **AC-11:** Live-Prüfung: GIVEN der gemergte und ausgelieferte Website-PR WHEN `curl -sS -o seite.html -w '%{http_code}'` die URLs `https://www.henemm.com/legal/loose-ends/privacy-policy/` und `https://www.henemm.com/legal/loose-ends/privacy-policy-en/` abruft THEN ist der Code je 200, und das Prüfskript (Aufruf mit `DATENSCHUTZ_LIVE=1`) findet in beiden Seiten die Kernaussagen aus AC-6 (a), den Abschnitt „Wenn du die Verbindung zu Claude nutzt“ bzw. „If you use the connection to Claude“ und keinen der veralteten Sätze aus AC-6 (b); Beleg `live.txt` mit Codes und Treffern. Die Datenschutz-URL, die bei Apple gesetzt ist, bleibt unverändert (Beleg: Repo-Variable `ASC_PRIVACY_POLICY_URL` und `PRIVACY_URL_EN` ohne Diff).
- [x] **AC-12:** Seite und Entwurf gleich: GIVEN der veröffentlichte Text (beide Sprachen) und der Entwurf WHEN die Abschnitte verglichen werden THEN stimmen die Kernsätze der Punkte 1 bis 4 wörtlich überein; die öffentliche Seite enthält nicht die Abschnitte „Beleg im Code“ und „Offen, nicht belegt“ (Beleg `vergleich.txt`).
- [x] **AC-13:** Schalter unberührt: GIVEN der Diff beider PRs WHEN er geprüft wird THEN enthält er weder `project.yml` noch `LooseEnds/Info.plist` noch `PrivacyInfo.xcprivacy` noch `scripts/test_asc_what_to_test.py`, und `LEAccountEnabled` ist in `project.yml` weiterhin `false` (Beleg `schalter.txt`: Diff-Dateiliste und Zeile aus `project.yml`).

## Dialog

### Runde 1
**Adversary:** Ich gehe von "kaputt" aus. Tests: DATENSCHUTZ_LIVE=1 python3 -m unittest discover -s scripts -p test_datenschutz_text.py -v = 14 OK, 0 übersprungen (adversary-test-output.txt); Gesamtsuite laut test-green-output.txt 722 OK, 1 übersprungen (Live-Test ohne Variable). Gegenproben mit manipuliertem Text (adversary-probe-output.txt): EN 30->60 days, DE 30->31 Tage, "Abschrift" im Abschnitt, "No backend of our own" und 14->15 Tage werden gefangen. Schwäche: missing_core prüft den ganzen Sprachteil inkl. Beleg-Tabelle; "14 Tage" und "Deutschland" stehen auch außerhalb des Konto-Abschnitts, die Kern-Regex fängt DE 14->15 nicht allein. Der Ankertest (ANCHORS, scripts/test_datenschutz_text.py:32) fängt es. Auch die ANCHORS prüfen den ganzen Teil, nicht den Konto-Abschnitt; die Reihenfolge prüft ein eigener Test (scripts/test_datenschutz_text.py:132). Stale-Prüfung ist case-sensitiv. Alles LOW, kein Spec-Verstoß.
Wortlaut: Konto-Abschnitt DE (docs/reference/datenschutz-entwurf.md:67-100) und EN (docs/reference/datenschutz-entwurf.md:223-254) Satz für Satz gegen Spec Punkte 1-4 gelesen: wörtlich gleich (Kurzfassung Z.18-22, Wo es liegt Z.64-65, Löschsatz Z.29-31, EN Abschnitt 2 Z.201-204, Abschnitt 3 Z.220-221, Löschsatz Z.286-287). EN-Nummerierung 1-7 korrekt (4 neu, 5 Rechte, 6 Apple, 7 Löschen). "Last updated: November 10, 2026" = Merge-Datum Website-PR 79 (2026-11-10T20:59:03Z). "Abschrift/transcript" nicht im Abschnitt (Test + Gegenprobe). Live: beide Seiten 200; Screenshots geöffnet: DE zeigt Abschnitt 4 mit allen Absätzen, Abschnitte 5-7 neu nummeriert, kein "Beleg im Code"; EN zeigt "4. If you use the connection to Claude", "Last updated: November 10, 2026", Abschnitte bis 7.
Reihenfolge AC-10 (selbst per API-Abfrage geprüft): henemm-infra 422 20:30:31Z, 425 20:48:51Z, 426 20:57:58Z, Issue 421 geschlossen 20:30:32Z, Heimserver-Rollout 20:58Z (sicherung.txt), Website-PR 79 20:59:03Z: Reihenfolge eingehalten, knapp (65 s nach 426).
Code-Belege: server/src/accounts.ts:76 SESSION_IDLE_DAYS = 90 stimmt; server/migrations/002_accounts.sql nur apple_sub, created_at, Token als Hash; server/src/oauth-adapter.ts:10 Ids nur SHA-256; deleteAccount löscht order_results, orders, transcripts, oauth_records, Konto (accounts.ts:116-124). Aber: Sitzungszeilen werden nie gelöscht (accounts.ts:79); "sie endet" ist wahr (unbrauchbar), die Prüfsumme bleibt aber bis zur Kontolöschung. Der Text behauptet keine Löschung; gering.
Sicherungsfrist: Skript 28 Tage ab jetzt, Höchstalter laut Beleg < 30 Tage. Ältester heutiger Snapshot 2026-11-04, also heute keiner älter als 30 Tage. Der Aufbewahrungslauf hat aber noch nie echt gelöscht (nur Dry-runs, erster Tageslauf 2026-11-11, erste Löschung 2026-12-03). "Frist gilt" ist per Konfiguration und Dry-run belegt, nicht per Lauf; die Abweichung von AC-10 ist begründet (kein Snapshot älter als 30 Tage) und offen benannt. Der Montagslauf hing seit 2026-07-15 an einer verwaisten Sperre (behoben, Issue 423); Issue 424 ist offen, der Loose-Ends-Pfad wird aber über Teil 2 per Rewrite entfernt. Text "höchstens 30 Tage", Umsetzung unter 30 Tagen: vereinbar.
**Implementierer:** (aus Belegen) Abweichung AC-10 steht in sicherung.txt Zeile 184 und 273; Dry-runs Tages- und Montagsmodus belegt; nächste echte Läufe terminiert.

### Runde 2
**Adversary:** Nachbohren. (1) Statuszeilen: DE (docs/reference/datenschutz-entwurf.md:9-11) und EN (docs/reference/datenschutz-entwurf.md:183-185) sagen noch "veröffentlicht erst, wenn die Sicherungsfrist gilt"; die Seiten sind seit 2026-11-10 live. AC-5 verlangt Freigabe und englische Website-Seite in der Statuszeile: erfüllt. Die Zukunftsform ist aber veraltet und nennt weder Datum noch PR 79. LOW. (2) Hetzner Deutschland belegt durch standort.txt (nbg1-dc3, eu-central). "Weiterer Rechner in Deutschland" nur über Dokumentation (backup-offsite.md), nicht gemessen; nach Beleg-Tabelle hinreichend. Protokolle 14 Tage: protokolle.txt daily/rotate 14; der Loose-Ends-vhost hat keine eigene access_log-Zeile (per API gelesen), es gilt der Standardpfad mit Rotation; compress+delaycompress, Dateien bis etwa 15 Tage alt, "nach 14 Tagen" knapp vertretbar. Fail2ban- und Docker-Logs werden im Text nicht behauptet. (3) Beleg-Tabelle (docs/reference/datenschutz-entwurf.md:119-148) deckt jede Aussage; die Zeile "Kein eigenes Backend, keine Fremd-SDKs" ist ersetzt (Z.123) und nennt URLSession nur im Konto-Teil. "Offen, nicht belegt" ergänzt Aufgabenübertragung und Anthropic (docs/reference/datenschutz-entwurf.md:170-173). (4) CLAUDE.md:165-166: Konto-Teil seit 2026-11-10, Spec-Verweis, LEAccountEnabled aus bis #625, 30 Tage; Diff +2/-1. (5) AC-13: schalter.txt ohne verbotene Pfade, project.yml:84 LEAccountEnabled: false. (6) AC-12: vergleich.txt 25/25 Sätze je Sprache, keine internen Abschnitte. (7) AC-7: red.txt zeigt fehlende 14/30/90 Tage, Hetzner, Konto löschen und veraltete Sätze; red.txt stammt von einer früheren Skriptfassung, inhaltlich unerheblich.
**Implementierer:** Statuszeilen-Nachzug nicht gate-relevant; Schwächen der Regex-Prüfung sind durch Anker abgedeckt.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: docs/reference/datenschutz-entwurf.md:9
  Description: Statuszeilen (DE Z.9-11, EN Z.183-185) stehen in Zukunftsform (veröffentlicht erst, wenn die Sicherungsfrist gilt), obwohl die Seiten seit 2026-11-10 20:59Z live sind; Veröffentlichungsdatum und PR 79 fehlen.
  Spec requirement: AC-5 — Statuszeile nennt Freigabe und Veröffentlichung
  Conflict: Der Entwurf ist nach der Auslieferung in diesem Punkt veraltet.
  Remediation: Statuszeile auf veröffentlicht am 2026-11-10 (henemm/henemm-website#79) setzen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_datenschutz_text.py:84
  Description: missing_core und missing_anchors prüfen den ganzen Sprachteil statt des Konto-Abschnitts; 14 Tage und Deutschland stehen auch außerhalb, Stale-Prüfung case-sensitiv. Gegenprobe: DE 14->15 wird nur vom Anker gefangen, nicht von der Kern-Regex.
  Spec requirement: AC-6 — Kernaussagen je Sprache per Regex prüfen
  Conflict: Kern-Regex allein nicht trennscharf; ANCHORS (scripts/test_datenschutz_text.py:32) fangen es dennoch.
  Remediation: Kern-Regex und Anker auf section() beschränken.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: server/src/accounts.ts:79
  Description: Abgelaufene Sitzungszeilen (Prüfsumme, Konto, Zeitstempel) werden nie gelöscht, nur unbrauchbar; der Text sagt sie endet, wenn du sie 90 Tage nicht benutzt.
  Spec requirement: AC-3 — keine Aussage ohne Beleg
  Conflict: endet ist wahr, gelöscht wird nicht behauptet; ein Leser könnte Löschung verstehen. Kein Verstoß.
  Remediation: Optional ist dann ungültig formulieren; kein Blocker.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: docs/artifacts/feat-615-s4e-datenschutz/sicherung.txt:184
  Description: AC-10 ist ohne echten forget-Lauf belegt (Dry-runs, Konfiguration; erste echte Löschung 2026-12-03). Begründet: kein Snapshot älter als 30 Tage, ältester 2026-11-04; Frist 28 Tage, Höchstalter unter 30 Tagen.
  Spec requirement: AC-10 — keine Snapshots älter als 30 Tage; bei neu gesetzter Frist den Aufbewahrungslauf zeigen
  Conflict: Wortlaut nicht erfüllt, Zweck (Zusage zum Veröffentlichungszeitpunkt wahr) erfüllt.
  Remediation: Nachprüfung ab 2026-12-04 per restic snapshots im Issue 615 vermerken.

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: docs/reference/datenschutz-entwurf.md:18
  Evidence: Kurzfassung (Z.18-22) und Wo es liegt (Z.64-65) im Wortlaut Punkt 1/2; test_no_stale_phrases grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: docs/reference/datenschutz-entwurf.md:67
  Evidence: Abschnitt zwischen Wo es liegt (Z.58) und Welche Rechte (Z.102), Aussagen wörtlich wie Spec Punkt 3; Reihenfolge-Test grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/reference/datenschutz-entwurf.md:119
  Evidence: Beleg-Tabelle ersetzt die Backend-Zeile, jede Aussage hat eine Zeile; Abschrift fehlt im Abschnitt (Gegenprobe); Belege gegen accounts.ts:76, oauth-adapter.ts:10, accounts.ts:116 gelesen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/reference/datenschutz-entwurf.md:29
  Evidence: Löschsatz mit Konto löschen wörtlich; knoepfe.txt: Claude / Konto löschen / Abmelden aus dem Katalog.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: docs/reference/datenschutz-entwurf.md:223
  Evidence: EN Abschnitte 2, 3, 4, 7 wörtlich (Z.201, 220, 223, 286), 14/30/90 days vorhanden, Last updated Z.187 = Veröffentlichungsdatum, Statuszeile nennt Freigabe und EN-Seite (F001 nur Form).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_datenschutz_text.py:119
  Evidence: 14 Tests OK, Regex a/b/c vorhanden, läuft in discover; Gesamtsuite 722 OK, 1 übersprungen (Live ohne Variable, mit Variable ok).
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: docs/artifacts/feat-615-s4e-datenschutz/red.txt:1
  Evidence: rot gegen Commit 62c0dbe mit fehlenden Aussagen und veralteten Sätzen.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: CLAUDE.md:165
  Evidence: Konto-Teil, Spec-Verweis, LEAccountEnabled aus bis #625, 30 Tage; Diff +2/-1.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: docs/artifacts/feat-615-s4e-datenschutz/protokolle.txt:1
  Evidence: daily, rotate 14; standort.txt nbg1-dc3 (eu-central).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: docs/artifacts/feat-615-s4e-datenschutz/sicherung.txt:1
  Evidence: Issue 421 geschlossen 20:30:32Z, Infra-Merges 20:30Z bis 20:57:58Z, Website-Merge 20:59:03Z (API geprüft); ältester Snapshot 2026-11-04; Abweichung siehe F004.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: docs/artifacts/feat-615-s4e-datenschutz/live.txt:1
  Evidence: 200/200, eigener Live-Lauf 14 OK, Screenshots geöffnet und beschrieben, ASC-URL ohne Diff.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: docs/artifacts/feat-615-s4e-datenschutz/vergleich.txt:1
  Evidence: 25/25 Sätze je Sprache, keine internen Abschnitte auf der Seite.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: docs/artifacts/feat-615-s4e-datenschutz/schalter.txt:1
  Evidence: keine verbotenen Pfade in beiden PRs, LEAccountEnabled false.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Tests: 14 passed (Textprüfung, live), Gesamtsuite 722 OK, 0 failed, 1 übersprungen (Live-Test ohne Variable, mit DATENSCHUTZ_LIVE=1 grün)
Edge cases: vier LOW-Befunde (F001-F004), keiner bricht eine AC
Regressions: None found
Checklist: 13/13 points proven

## Geprüfte Dateien

- sha256:2322651d5e0cff74f8f9531b096eaf0249344f68c386f025f2f71e027e7ec053  CLAUDE.md
- sha256:e85727b1cbfd262abe85de11a28691e3d638a1d77e80ee221a55aceb4a5eae73  docs/artifacts/feat-615-s4e-datenschutz/live.txt
- sha256:f30d03cf1648366358493b469f9bb1e5da86c737e2b3a5c9756cff4e51b69a86  docs/artifacts/feat-615-s4e-datenschutz/protokolle.txt
- sha256:db0147c0ee1ccf49c0136e39a400920da980feec4676a5ccb370f9e1b8e48f9b  docs/artifacts/feat-615-s4e-datenschutz/red.txt
- sha256:58b9d184c9277f12bec9a3c1fedfa8f9508d3e7acfdbcc65b5c6888e4e3fadb9  docs/artifacts/feat-615-s4e-datenschutz/schalter.txt
- sha256:fff1f3407b8530dc4f96b5cfb0e627aef96d388acb10aca884b8a77bc3d573f6  docs/artifacts/feat-615-s4e-datenschutz/sicherung.txt
- sha256:e6c4120ebfd29e74faf9294a4142b14c85455f2577eeeac4289102dc4d9ca650  docs/artifacts/feat-615-s4e-datenschutz/vergleich.txt
- sha256:5a37e3e6243bd27cb457c4e9fc3b6e6e4490abc68af7c81ba6ff4583922cc03d  docs/reference/datenschutz-entwurf.md
- sha256:1d2b3fc02ac71f9302e22e1ccc7c8c58568b3f5002ae9d5df11425c26c818c00  scripts/test_datenschutz_text.py
- sha256:b59036c16af390ce5989f8c96ed59e0920a67a5f2e230966b9e8de2277fa2c4a  server/src/accounts.ts

## Prüfbasis

- base: 62c0dbe1f0ece30ddd37a8461b422ecb603f5b09
- blob:6ee357e0bdda36b7631a206f5bdf3c2e0070d607  CLAUDE.md
- blob:a22721dad9aea1a4142e657d007e81819d57c2a0  docs/artifacts/feat-615-s4e-datenschutz/live.txt
- blob:c1af52da22f7c4bf5e504579f5b5dcb1d4a80529  docs/artifacts/feat-615-s4e-datenschutz/protokolle.txt
- blob:9a3a6291aeed93ddee46b8917d8c9b5459c082c4  docs/artifacts/feat-615-s4e-datenschutz/red.txt
- blob:42cc61c214c31f71b5b88b0c7b07cd22a1a77fee  docs/artifacts/feat-615-s4e-datenschutz/schalter.txt
- blob:941516626ef8941e0eef0e559fb845b761b618a3  docs/artifacts/feat-615-s4e-datenschutz/sicherung.txt
- blob:a8e46b4e064eb25ab6b5ce472c56be1161d880c2  docs/artifacts/feat-615-s4e-datenschutz/vergleich.txt
- blob:1557d297e23d4b3d5ab090bdc702b2306f23a2e2  docs/reference/datenschutz-entwurf.md
- blob:6d088c90969d1da73382557271f390ee79325598  scripts/test_datenschutz_text.py
- blob:f9021c555938739c3e82db44da2dbe87476941f7  server/src/accounts.ts

## Geprüfte Dateien

- sha256:2322651d5e0cff74f8f9531b096eaf0249344f68c386f025f2f71e027e7ec053  CLAUDE.md
- sha256:e85727b1cbfd262abe85de11a28691e3d638a1d77e80ee221a55aceb4a5eae73  docs/artifacts/feat-615-s4e-datenschutz/live.txt
- sha256:f30d03cf1648366358493b469f9bb1e5da86c737e2b3a5c9756cff4e51b69a86  docs/artifacts/feat-615-s4e-datenschutz/protokolle.txt
- sha256:db0147c0ee1ccf49c0136e39a400920da980feec4676a5ccb370f9e1b8e48f9b  docs/artifacts/feat-615-s4e-datenschutz/red.txt
- sha256:58b9d184c9277f12bec9a3c1fedfa8f9508d3e7acfdbcc65b5c6888e4e3fadb9  docs/artifacts/feat-615-s4e-datenschutz/schalter.txt
- sha256:fff1f3407b8530dc4f96b5cfb0e627aef96d388acb10aca884b8a77bc3d573f6  docs/artifacts/feat-615-s4e-datenschutz/sicherung.txt
- sha256:e6c4120ebfd29e74faf9294a4142b14c85455f2577eeeac4289102dc4d9ca650  docs/artifacts/feat-615-s4e-datenschutz/vergleich.txt
- sha256:5a37e3e6243bd27cb457c4e9fc3b6e6e4490abc68af7c81ba6ff4583922cc03d  docs/reference/datenschutz-entwurf.md
- sha256:1d2b3fc02ac71f9302e22e1ccc7c8c58568b3f5002ae9d5df11425c26c818c00  scripts/test_datenschutz_text.py
- sha256:b59036c16af390ce5989f8c96ed59e0920a67a5f2e230966b9e8de2277fa2c4a  server/src/accounts.ts

## Prüfbasis

- base: 62c0dbe1f0ece30ddd37a8461b422ecb603f5b09
- blob:6ee357e0bdda36b7631a206f5bdf3c2e0070d607  CLAUDE.md
- blob:a22721dad9aea1a4142e657d007e81819d57c2a0  docs/artifacts/feat-615-s4e-datenschutz/live.txt
- blob:c1af52da22f7c4bf5e504579f5b5dcb1d4a80529  docs/artifacts/feat-615-s4e-datenschutz/protokolle.txt
- blob:9a3a6291aeed93ddee46b8917d8c9b5459c082c4  docs/artifacts/feat-615-s4e-datenschutz/red.txt
- blob:42cc61c214c31f71b5b88b0c7b07cd22a1a77fee  docs/artifacts/feat-615-s4e-datenschutz/schalter.txt
- blob:941516626ef8941e0eef0e559fb845b761b618a3  docs/artifacts/feat-615-s4e-datenschutz/sicherung.txt
- blob:a8e46b4e064eb25ab6b5ce472c56be1161d880c2  docs/artifacts/feat-615-s4e-datenschutz/vergleich.txt
- blob:1557d297e23d4b3d5ab090bdc702b2306f23a2e2  docs/reference/datenschutz-entwurf.md
- blob:6d088c90969d1da73382557271f390ee79325598  scripts/test_datenschutz_text.py
- blob:f9021c555938739c3e82db44da2dbe87476941f7  server/src/accounts.ts
