---
spec_file: docs/specs/fix-939-ci-ui-smoke-zeitbudget.md
spec_sha256: 33ce71b80658e09bfb09e943bce1b6140d77b1a88683c474fff96b9e32bdc0a8
spec_frozen_sha256: cf71c700dd67f1de28a39d41d8ad73b2389b953076c87c7e129f08c785ed04e7
---

# PO-Briefing: fix-939-ci-simulator

- **Spec:** docs/specs/fix-939-ci-ui-smoke-zeitbudget.md
- **Issue:** #939
- **Erstellt:** 2026-11-20

## Was gebaut wird

Die automatische Bedienungsprüfung verteilt ihre Abläufe auf sechs Teile mit mehr Zeit, damit sie seltener am Zeitlimit scheitert.

## Definition of Done

Drei aufeinanderfolgende Prüfläufe auf demselben Stand laufen ohne Zeitlimit-Abbruch, alle sechs Teile beim ersten Versuch grün.

## Wie geprüft wird

Skripttests belegen die Aufteilung und die Einstellungen; ob die Läufe wirklich zuverlässig grün werden, zeigt erst die echte Prüfung nach dem Bau.

## Kritische Anmerkungen

- Behebt nur den häufigsten Grund (43 von 94 Fehlschlägen); wacklige Tests und Simulator-Ausfälle bleiben, Ziel „immer grün“ kann verfehlt werden.
- Sechs gleichzeitige Rechner statt vier: mögliche Wartezeiten bei parallelen Sitzungen.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
