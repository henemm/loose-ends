# Mini-Spec: feat-796-s4b2-abschluss

Issue #796, Schnitt S4b-2 (wöchentliche automatische Rückspielprobe), Abschluss im Repo.

## Ausgangslage

- Die Probe ist seit 2026-11-04 live auf rennwienix (henemm/henemm-infra#385, Merge f7dfedc): sonntags nach dem
  nächtlichen Backup holt sie den jüngsten Off-Site-Snapshot, spielt `looseends.sql` in einen Wegwerf-Container
  `postgres:18.6` ein und vergleicht Tabellen und Migrationen lesend mit `loose-ends-db`.
- Vorgezogener Lauf, Fehlfall und unveränderter Zustand wurden am 2026-11-04 belegt (Workflow
  `feat-796-s4b2-rueckspielprobe`). Dessen Arbeitsordner samt Spec und Belegen ist nie ins Repo gelangt und
  existiert nicht mehr; offen war nur noch AC-14, der erste Lauf über den Cron-Weg am Sonntag.
- Sonntag 2026-11-15, 03:06Z: `RUECKSPIELPROBE BESTANDEN`, keine Fehlerzeile danach. Beleg:
  `docs/artifacts/feat-796-s4b2-rueckspielprobe/ac14-sonntagslauf.txt` (das Log hält nur den jüngsten Lauf, deshalb
  jetzt gesichert, bevor der Lauf am 2026-11-22 ihn überschreibt).

## Was ändert sich

- **AC-1:** Der Sonntagslauf vom 2026-11-15 liegt als Beleg im Repo (Datei oben), mit Quelle, Abrufdatum und Infra-PR.
- **AC-2:** `CLAUDE.md` (Abschnitt `server/`, Betrieb) nennt die wöchentliche Rückspielprobe als in Betrieb (sonntags,
  Off-Site-Snapshot in Wegwerf-Container, Vergleich mit live, henemm-infra#385) statt „follows with S4b-2“.
- **AC-3:** Die Vereinbarung „vor externen Nutzern (#625) auf einem eigenen Server im selben Projekt“ aus dem
  Issue-Text von #796 bleibt inhaltlich unverändert und wird nur umgetragen: ein eigenes Issue (Teil von #612) mit
  genau diesem Wortlaut und Verweis auf #796. #625 wartet heute auf #796 und damit auf diesen Umzug; nach dem Schließen
  von #796 trägt #625 stattdessen „Wartet auf“ das neue Issue. Der Umzug wird nicht vorgezogen und nicht gestrichen.
- **AC-4:** #796 bekommt einen Abschlusskommentar (Definition of Done: Adresse, Neustart/Verbindungsabbruch aus S1–S4a,
  Rückspielprobe 2026-11-04 von Hand und 2026-11-15 automatisch) und wird über den PR geschlossen.

## Was darf sich nicht ändern

- Nichts auf rennwienix (nur lesend per ssh), kein Code in `server/`, kein App-Code.
- Der alte Workflow `feat-796-s4b2-rueckspielprobe` wird nicht von Hand auf „fertig“ gesetzt; dieser Workflow löst ihn ab.

## Test-Schritte (automatisch, keine für den PO)

1. Beleg enthält `RUECKSPIELPROBE BESTANDEN` mit Datum 2026-11-15 und die Fehlerzahl 0 (`grep`).
2. `grep -n "S4b-2" CLAUDE.md` zeigt keine Formulierung „follows with S4b-2“ mehr.
3. Neues Issue existiert, als Teil von #612 verknüpft, auf dem Board; sein Text enthält den Wortlaut „auf einem
   eigenen Server im selben Projekt“; der Text von #625 nennt es unter „Wartet auf“.
4. Nach dem Merge: `gh issue view 796 --json state,comments` zeigt `CLOSED`, der letzte Kommentar nennt die
   Rückspielprobe vom 2026-11-15 und das neue Issue. Board-Status von #796 ist Done.

## Abnahme

Kein Pfad der Geräteliste berührt. Reine Doku- und Belegänderung, kein Simulatorlauf nötig.
