---
spec_file: docs/specs/tooling/feat-511-ci-mac-galerie.md
spec_sha256: cd685e9e63adacb9418eb03a5052c3b833dcd6b86526280bcdfd4ea1faa0c6e8
spec_frozen_sha256: b17de57667eb4679e12e3d419750c491bcee4c14e7a2edf6c14254f0cc2cbe98
---

# PO-Briefing: feat-511-ci-mac-galerie

- **Spec:** docs/specs/tooling/feat-511-ci-mac-galerie.md
- **Issue:** #511
- **Erstellt:** 2026-10-17

## Was gebaut wird

Die CI fotografiert die Mac-App automatisch: Startseite, Liste, Detail, hell und dunkel, ohne Hennings Mac.

## Definition of Done

Ein CI-Lauf auf dem Hauptzweig liefert sechs angesehene Mac-Bilder; iPhone-Galerie und andere Prüfungen bleiben unverändert.

## Wie geprüft wird

Tests prüfen CI-Einstellungen und dass jeder Bildschirm erreicht wird, nicht wie die Bilder aussehen.

## Kritische Anmerkungen

- Unklar, ob GitHubs Mac-Rechner Bedienung erlauben; sonst gibt es keine Bilder und das Ticket bleibt offen.
- Fenstergröße unbekannt; zu schmal heißt: rechte Spalte der Startseite fehlt, Folgeticket nötig.
- Dunkelbild: Ob Titelleiste und Seitenleiste mitfärben, zeigt sich erst am Bild.

## Freigabe-Frage

Gibst du dies als Experiment frei, dessen erster CI-Lauf klärt, ob Mac-Bilder überhaupt möglich sind?
