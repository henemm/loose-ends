# Mini-Spec: fix-543-leave-one-out-datum

**ADR-Nr.:** keine — reine Test- und Berichtsänderung, keine Architekturentscheidung

## Was ändert sich
- **AC-1:** Der Berichtskopf von `docs/reference/retrieval-leave-one-out-rules.md` trägt kein Datum mehr: Der Satz „Messtag: …" entfällt in `LooseEndsTests/RuleLeaveOneOutTests.swift`, `measurementDay()` und der Aufruf fallen weg.
- **AC-2:** Der Test prüft nicht mehr auf „Messtag: …" (Zeile 407), sondern darauf, dass der Kopf keinen Datumsstempel enthält.
- **AC-3:** Der eingecheckte Bericht verliert die Zeile „Messtag: …" einmalig; sonst bleibt sein Inhalt gleich.
- **AC-4 (Zusatz, Henning 2026-10-22):** `docs/reference/context-word-learning.md` (Bericht zu #233, nie eingecheckt, von `ContextWordLearningReportTests` bei jedem Lauf geschrieben, zwei Läufe mit gleicher Prüfsumme) wird einmalig eingecheckt. Danach hinterlässt `./scripts/sim.sh sim-unit` mit Korpus keinen Unterschied unter `docs/reference/`.

## Was darf sich nicht ändern
- Alle Zahlen, Tabellen und die Gegenprobe des Berichts.
- Die anderen Berichte (`ContextWordLearningReportTests`, `ConventionBaselineTests`, `SelfConsistencyReportTests`, `DateTitleReportTests`).

## Nachweis (Simulator, Korpus aus dem Hauptordner)
1. Vorher: `./scripts/sim.sh sim-unit` mit Korpus, danach `git diff docs/reference/` zeigt die Datumszeile.
2. Nachher: derselbe Lauf, `git diff docs/reference/` ist nach dem ersten Lauf leer; ein zweiter Lauf am selben Stand ebenfalls.

## Inline-Test
- [ ] Bericht enthält keine Zeile „Messtag:".
- [ ] Zwei Läufe hintereinander hinterlassen keinen Diff unter `docs/reference/`.

Kein Pfad der Geräteliste berührt.
