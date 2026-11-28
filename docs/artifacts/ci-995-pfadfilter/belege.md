# #995 – Belege der Definition of Done

## Beleg A: voller CI-Lauf auf dem PR, alle Jobs grün

PR #1019, Lauf 46120373677, gemergt 2026-11-28 (Squash `53426c5`).
Alle 16 Jobs `success`. „UI Smoke part 4“ verlor im ersten Versuch den Runner
(„The hosted runner lost communication with the server“, nach 63 min; auf `main` braucht
der Teil 20–38 min). Die einmalige Wiederholung war nach 28 min grün.

| Job | Dauer (min) |
|---|---|
| Changed paths | 0 |
| Shipped languages | 0 |
| UI Smoke plan | 0 |
| Build (iOS Simulator) | 4 |
| Unit Tests (macOS destination) | 11 |
| UI iPad (iOS Simulator) | 16 |
| ui-smoke-lang (de) | 20 |
| ui-smoke-lang (en) | 28 |
| UI Smoke part 1–6 | 45 / 41 / 37 / 28 (Wiederholung) / 34 / 35 |
| Mac Gallery (macOS) | 36 |
| UI Smoke (iOS Simulator) | 0 (Sammeljob, jetzt `ubuntu-latest`) |

## Beleg B: reiner Doku-PR erfüllt die Pflicht-Checks in unter 10 min

Dieser PR ändert nur diese Datei unter `docs/`. Gemessen wird vom Laufstart bis zum letzten
Pflicht-Check; das Ergebnis steht im Issue #995.
