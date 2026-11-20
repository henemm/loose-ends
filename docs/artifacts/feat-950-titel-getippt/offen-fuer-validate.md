# Offen für /60-validate (#950)

- Der Simulatorbeleg (`simulator-run.txt`, CaptureSmokeTests 29/29 und InboxDrawerSmokeTests 2/2) entstand **vor** der
  Korrektur F001 (`heard = false` in `CaptureView.finish`, Commit f72e7e0). Sein Hash für `CaptureView.swift` passt
  deshalb nicht mehr: `./scripts/sim.sh test-proof InboxDrawerSmokeTests` und `./scripts/sim.sh test-proof CaptureSmokeTests`
  auf dem aktuellen Stand erneut fahren (CaptureSmokeTests ~16 min).
- F001 selbst ist nicht automatisiert nachspielbar (Sprache unter `--ui-testing` aus); am Code belegt, Adversary Runde 3.
