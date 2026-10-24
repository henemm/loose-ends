---
spec_file: docs/specs/feat-670-testsprache.md
spec_sha256: 73fe84947a2ae94c77ab3aa6da6dbf472aa40162380c4c70d386a5604e71ac14
spec_frozen_sha256: e5ba437b407269a706598af3770f5d39d11967935bbc8a150a87e463c775644a
---

# PO-Briefing: fix-670-testsprache

- **Spec:** docs/specs/feat-670-testsprache.md
- **Issue:** #670
- **Erstellt:** 2026-10-24

## Was gebaut wird

Lokale Testläufe lassen sich mit einer Variable auf Englisch statt Deutsch starten, ohne den Simulator umzustellen.

## Definition of Done

Der Knäuel-Testlauf ist mit Englisch-Variable grün und zeigt Englisch, ohne Variable weiter Deutsch; die Befehlszeile steht in der Projektanleitung.

## Wie geprüft wird

Skripttests belegen die weitergereichten Sprachangaben; dass Englisch im Simulator wirklich gilt, zeigt nur ein einmaliger, nicht eingecheckter Probelauf.

## Kritische Anmerkungen

- Ungeklärt, ob die Sprachangabe unter Xcode 27 bei Unit-Tests überhaupt wirkt; sonst wird die Spec vor dem Merge umgebaut.
- Wirkung im echten Lauf ist nur ein Einmalnachweis, kein dauerhafter Test.
- Zusatz ohne Anfrage: Regionstabelle und strikte Wertprüfung mit Abbruch bei ungültiger Eingabe.

## Freigabe-Frage

Soll die Testsprache wie beschrieben gebaut werden, mit Rückfall auf eine andere Methode, falls der echte Lauf keine Wirkung zeigt?
