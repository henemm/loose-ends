---
spec_file: docs/specs/feat-240-schnitt-1-bausteine.md
spec_sha256: 90c33c1b67b98c589f77e839c8940eaf1b001398b78bd8d01a7e45033efdb328
---

# PO-Briefing: feat-240-ortsmitteilung

- **Spec:** docs/specs/feat-240-schnitt-1-bausteine.md
- **Issue:** #240
- **Erstellt:** 2026-10-14

## Was gebaut wird

Getestete Entscheidungsregeln für Ortsmitteilungen entstehen, die noch nirgends angeschlossen sind; sichtbar ändert sich nichts.

## Definition of Done

Alle Tests grün und die App startet im Simulator unverändert; die Ortsmitteilung selbst kommt erst mit dem zweiten Schnitt.

## Wie geprüft wird

Tests belegen Regeln für Knöpfe, Freigabe, Marke und Doppelanfragen, aber nicht, dass das iPhone tatsächlich eine Mitteilung zeigt.

## Kritische Anmerkungen

- Ticketziel (Erinnerung auf dem iPhone, zweite Mitteilung bleibt aus) ist erst nach Schnitt 2 erfüllt; #240 bleibt offen.
- Fehler bei den Mitteilungsknöpfen würden die Fällig-Knöpfe entfernen; echte Wirkung zeigt sich erst in Schnitt 2.

## Freigabe-Frage

Gibst du diesen unsichtbaren Vorbereitungsschritt frei, obwohl die Ortsmitteilung erst mit dem zweiten Schnitt greifbar wird?
