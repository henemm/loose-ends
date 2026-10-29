# Simulator-Durchlauf der Kette (AC-6), 2026-10-29

Wegwerf-Dateien außerhalb des Repos, erfundene Sätze („Zebrakuchen Satz Nummer N“), kein Gerät.

1. `guardrail_corpus.py build` → `heikel 100, Alltag 287, gesamt 387`
2. Wegwerf-Ergebnisdatei mit 774 Aufrufen, eine Ablehnung (`guardrail`) bei `alltag-7` → `guardrail_corpus.py count` → `774`
3. `./scripts/sim.sh sim-unit IphoneGuardrailReportTests` mit `TEST_RUNNER_LOOSEENDS_GUARDRAIL_*` → „Unit-Tests bestanden“
4. Rohdaten (121903 Byte): `grep -c Zebrakuchen` = 0, `alltag-7` vorhanden
5. Lokale Zusammenfassung: Zeile „gesamt: 1/387 Texte = 0.26 % (Grenze 1.45 %), Proben 1/774 gemessen“, Treffer mit Wortlaut (`grep -c Zebrakuchen` = 1)

`xcrun`/`devicectl` wurde nicht aufgerufen; der Trockenlauf-Test hat eine Attrappe, die jeden Aufruf melden würde.
