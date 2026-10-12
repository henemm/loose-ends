---
spec_file: docs/specs/feat-368-schnitt-1-regel-jetzt.md
spec_sha256: b25d7fc12284752231548a2e38c6910ac7ab6d2161cd32a414122c3b7e25472c
---

# PO-Briefing: feat-368-startseite-drei-zonen

- **Spec:** docs/specs/feat-368-schnitt-1-regel-jetzt.md
- **Issue:** #368
- **Erstellt:** 2026-10-12

## Was gebaut wird

Die unsichtbare Sortierregel für „Jetzt“: überfällig, heute fällig, vorgemerkt, jede Aufgabe einmal.

## Definition of Done

Die Regel sortiert in allen Testfällen richtig, Zähler und bestehende Ansichten bleiben unverändert, die Startseite sieht aus wie vorher.

## Wie geprüft wird

Automatische Tests prüfen Reihenfolge, Einmaligkeit und Ausschlüsse, nicht das Aussehen auf dem Bildschirm.

## Kritische Anmerkungen

- Sie sehen nichts Neues: Eingangsleiste, Block „Jetzt“ und Texte kommen erst in Schritt 2 bis 4.
- Wörtlich aus der Gesamt-Spec übernommen, nichts fehlt; deren Freigabe-Haken ist noch leer.

## Freigabe-Frage

Soll zuerst nur die unsichtbare Regel gebaut werden, obwohl Sie erst ab Schritt 2 Neues sehen?
