---
spec_file: docs/specs/tooling/feat-145-simulator-beleg.md
spec_sha256: 8f984d99450f0ee98d8e2f2f9b9685fd47ef8acf7ff9a7172e291c2e5555e287
---

# PO-Briefing: feat-145-simulator-beleg

- **Spec:** docs/specs/tooling/feat-145-simulator-beleg.md
- **Issue:** #145
- **Erstellt:** 2026-10-01

## Was gebaut wird

Ein Befehl spielt einen Bedien-Test im Simulator durch und erzeugt daraus automatisch einen Beleg samt Screenshot.

## Definition of Done

Grüner Lauf liefert Beleg und Screenshot, roter Lauf einen Fehlerbeleg; die Prüfsummen im Beleg stimmen nachweislich mit den Dateien überein.

## Wie geprüft wird

Automatische Tests prüfen Format und Fehlerfälle, echte Simulatorläufe (grün und absichtlich rot) den Rest; Fälschungsschutz wird nicht geprüft.

## Kritische Anmerkungen

- Nicht fälschungssicher: Bis zum späteren Plugin-Gate lässt sich der Beleg von Hand schreiben, Forderung des Tickets bleibt offen.
- Jeder beliebige grüne Test genügt; ob er zum Ticket passt, prüft niemand maschinell.

## Freigabe-Frage

Gibst du Schnitt 1 frei, obwohl der Fälschungsschutz erst mit dem späteren Plugin-Gate (Schnitt 2) wirksam wird?
