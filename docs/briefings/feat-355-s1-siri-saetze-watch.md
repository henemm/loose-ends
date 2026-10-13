---
spec_file: docs/specs/intents/feat-355-s1-siri-saetze-watch.md
spec_sha256: 887833d77d2c3dfdda2da76123e7a4ca80e9b6f2cc7437f5ebc21b8345c897a6
---

# PO-Briefing: feat-355-s1-siri-saetze-watch

- **Spec:** docs/specs/intents/feat-355-s1-siri-saetze-watch.md
- **Issue:** #355
- **Erstellt:** 2026-10-13

## Was gebaut wird

Auf iPhone und Mac versteht Siri zusätzlich „Erfasse in Loose Ends“; die Watch erhält deutsche Texte und Siri-Namen.

## Definition of Done

Neuer Satz funktioniert auf dem iPhone; Watch-Paket enthält deutsche Texte; Siri auf der Watch ist ausdrücklich ausgenommen.

## Wie geprüft wird

Skripte und Paketinspektion belegen Satz, Katalog und Inhalt; Siri-Erkennung auf der Watch wird nicht geprüft, der Simulator kann nicht sprechen.

## Kritische Anmerkungen

- Watch-Siri funktioniert nicht (Build 52 und 54: „Los Angeles“); das Hauptziel des Tickets bleibt offen, Untersuchung in #404.
- Dialog bleibt „Was soll ich aufnehmen?“ statt gewünschtem „Was soll ich mir merken?“.
- Komplikation wird Watch-Hauptweg; #355 bleibt bis Schnitt 3 offen.

## Freigabe-Frage

Gibst du frei, dass ohne funktionierende Watch-Siri nur der iPhone-Satz und die deutschen Watch-Texte ausgeliefert werden?
