# Adversary Dialog — feat-796-s4b2-abschluss
Spec: docs/specs/fast/feat-796-s4b2-abschluss.md
Datum: 2026-11-20 09:07

## Checkliste
- [x] **AC-1:** Der Sonntagslauf vom 2026-11-15 liegt als Beleg im Repo (Datei oben), mit Quelle, Abrufdatum und Infra-PR.
- [x] **AC-2:** `CLAUDE.md` (Abschnitt `server/`, Betrieb) nennt die wöchentliche Rückspielprobe als in Betrieb (sonntags, Off-Site-Snapshot in Wegwerf-Container, Vergleich mit live, henemm-infra#385) statt „follows with S4b-2“.
- [x] **AC-3:** Die Vereinbarung „vor externen Nutzern (#625) auf einem eigenen Server im selben Projekt“ aus dem Issue-Text von #796 bleibt inhaltlich unverändert und wird nur umgetragen: ein eigenes Issue (Teil von #612) mit genau diesem Wortlaut und Verweis auf #796. #625 wartet heute auf #796 und damit auf diesen Umzug; nach dem Schließen von #796 trägt #625 stattdessen „Wartet auf“ das neue Issue. Der Umzug wird nicht vorgezogen und nicht gestrichen.
- [x] **AC-4:** #796 bekommt einen Abschlusskommentar (Definition of Done: Adresse, Neustart/Verbindungsabbruch aus S1–S4a, Rückspielprobe 2026-11-04 von Hand und 2026-11-15 automatisch) und wird über den PR geschlossen. (Vor-Merge-Teil belegt, Schließen nach Merge offen.)

## Dialog

### Runde 1
**Adversary:** Testlauf pruefung.sh: 10 PASS, FEHLER=0 (adversary-test-output.txt). Das Skript prüft nur Muster, deshalb lese ich selbst. AC-1: Beleg enthält Quelle (Zeile 2), Abrufdatum 2026-11-20, henemm-infra#385, Zeile 23 RUECKSPIELPROBE BESTANDEN mit Zeitstempel 2026-11-15T03:06:31Z, letzte Zeile 0. Einwand: Der Beleg ist ein Auszug von Hand, kein Rohlog (das Log hält nur den jüngsten Lauf). Die Kopfzeile nennt das offen als Auszug; nicht widerlegbar.
AC-2: CLAUDE.md Zeile 587 enthält "weekly automatic restore test in operation since S4b-2 (Sundays ...; henemm-infra#385, first Sunday run passed 2026-11-15)"; "follows with S4b-2" kommt nicht mehr vor. Sonntags, Off-Site-Snapshot, Wegwerf-Container, Vergleich mit live, #385 alle genannt.
Code reference: CLAUDE.md:587
Code reference: docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh:19
Code reference: docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt:23
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** AC-3 gegen den Originaltext: Die Teile-Zeile von #796 lautet "Bereitstellung auf dem bestehenden Hetzner-Server, vor externen Nutzern (#625) auf einem eigenen Server im selben Projekt." #966 zitiert exakt diesen Satz, verweist auf #796, ist "Teil von Epic #612", per sub_issues-API Kind von #612 und auf Board 1. #625: "Wartet auf: #795, #966, #623, #624", #796 nicht mehr genannt. Der #796-Body ist unverändert. Hinweis, kein Mangel: #625 wurde schon vor dem Merge umgestellt, die Spec sagt "nach dem Schließen"; unschädlich, da #966 die Wartebedingung trägt. Nicht vorgezogen, nicht gestrichen (DoD von #966).
AC-4: Letzter Kommentar von #796 enthält Adresse https://loose-ends.henemm.com, S1–S4a (/health, Fehler-Listener, advisory lock, SIGTERM), Rückspielprobe 2026-11-04 von Hand und 2026-11-15 automatisch, Verweis auf #966. Issue ist OPEN, vor Merge erwartet; pruefung.sh --nach-merge prüft danach. Restrisiko: "Closes #796" muss im PR-Text stehen.
Code reference: docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh:27
Code reference: docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh:29
Code reference: docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh:35
**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** Nachtrag nach Änderung von pruefung.sh. Diff geprüft: nur Zähler `bestanden` (Zeile 7/8) und letzte Ausgabezeile ergänzt, alle Prüfungen und die Fehlerlogik unverändert. Skript erneut gelaufen: 10 PASS, "10 passed, 0 failed", Ausgang 0. Verdict bleibt.
Code reference: docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh:40
**Implementierer:** (nicht beteiligt)

## Confirmations
Confirmation:
  AC: AC-1
  Code reference: docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt:2
  Evidence: Quelle, Abrufdatum, henemm-infra#385, BESTANDEN 2026-11-15, Fehlerzahl 0
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: CLAUDE.md:587
  Evidence: Probe als in Betrieb beschrieben, kein "follows with S4b-2"
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh:23
  Evidence: #966 mit Wortlaut aus #796, Sub-Issue von #612, auf Board, #625 wartet auf #966
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh:35
  Evidence: Abschlusskommentar vollständig; Schließen erst nach Merge (--nach-merge)
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**
Tests: 10 bestanden, 0 fehlgeschlagen, 0 übersprungen (pruefung.sh). Keine Findings. AC-4: Vor-Merge-Teil belegt, Schließen nach Merge über Closes #796.

## Geprüfte Dateien

- sha256:d6ccedc2308999db8362ebd9228ec56d80a2b91ceefc29d06a14b30938f63181  CLAUDE.md
- sha256:bbe82ed720bd9c671e423d13d020da151af582140339fba0b5448ba09a977bf2  docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh
- sha256:162024397f170ca199d9db61339654f44e20f908e60f4b037a277f4ecf541d0d  docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt

## Prüfbasis

- base: de0f43e3eb9aeccadc068947ccc898894668e33e
- blob:0c2e11a1ac04385bf0ae207f58e27503ffa7e03b  CLAUDE.md
- blob:7b7c0cea6c8458418290017562e821dc8c25af0d  docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh
- blob:bab56e10667b3c9971bd90f944e02bdc5d0e490c  docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt

## Geprüfte Dateien

- sha256:d6ccedc2308999db8362ebd9228ec56d80a2b91ceefc29d06a14b30938f63181  CLAUDE.md
- sha256:7d79e723c735966f21349ec0e45c1d85c9572120dd2e813520b355a1dee3b241  docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh
- sha256:162024397f170ca199d9db61339654f44e20f908e60f4b037a277f4ecf541d0d  docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt

## Prüfbasis

- base: de0f43e3eb9aeccadc068947ccc898894668e33e
- blob:0c2e11a1ac04385bf0ae207f58e27503ffa7e03b  CLAUDE.md
- blob:1f6bf396c952f13f127b4c1ae6112ec89ed3d3ee  docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh
- blob:bab56e10667b3c9971bd90f944e02bdc5d0e490c  docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt

## Geprüfte Dateien

- sha256:d6ccedc2308999db8362ebd9228ec56d80a2b91ceefc29d06a14b30938f63181  CLAUDE.md
- sha256:7d79e723c735966f21349ec0e45c1d85c9572120dd2e813520b355a1dee3b241  docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh
- sha256:162024397f170ca199d9db61339654f44e20f908e60f4b037a277f4ecf541d0d  docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt

## Prüfbasis

- base: de0f43e3eb9aeccadc068947ccc898894668e33e
- blob:0c2e11a1ac04385bf0ae207f58e27503ffa7e03b  CLAUDE.md
- blob:1f6bf396c952f13f127b4c1ae6112ec89ed3d3ee  docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh
- blob:bab56e10667b3c9971bd90f944e02bdc5d0e490c  docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt

## Geprüfte Dateien

- sha256:d6ccedc2308999db8362ebd9228ec56d80a2b91ceefc29d06a14b30938f63181  CLAUDE.md
- sha256:7d79e723c735966f21349ec0e45c1d85c9572120dd2e813520b355a1dee3b241  docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh
- sha256:162024397f170ca199d9db61339654f44e20f908e60f4b037a277f4ecf541d0d  docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt

## Prüfbasis

- base: de0f43e3eb9aeccadc068947ccc898894668e33e
- blob:0c2e11a1ac04385bf0ae207f58e27503ffa7e03b  CLAUDE.md
- blob:1f6bf396c952f13f127b4c1ae6112ec89ed3d3ee  docs/artifacts/feat-796-s4b2-abschluss/pruefung.sh
- blob:bab56e10667b3c9971bd90f944e02bdc5d0e490c  docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt
