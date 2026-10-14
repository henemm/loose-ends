---
spec_file: docs/specs/intents/feat-355-s3-komplikation.md
spec_sha256: c19f278ae3ef060e70ba5a0d7ed8c5a093b98b27330146f614660652fd941472
---

# PO-Briefing: feat-355-s3-komplikation

- **Spec:** docs/specs/intents/feat-355-s3-komplikation.md
- **Issue:** #355
- **Erstellt:** 2026-10-14

## Was gebaut wird

Auf dem Watch-Zifferblatt erscheint eine Komplikation mit dem Knoten; Antippen öffnet die Erfassung.

## Definition of Done

Auf Hennings Watch lässt sich die Komplikation wählen, zeigt den Knoten, und Antippen öffnet die Erfassung.

## Wie geprüft wird

Tests belegen die Zeichnung des Knotens in beiden Größen; Auswahl und Antippen auf dem Zifferblatt prüft nur Hennings Watch.

## Kritische Anmerkungen

- Abweichung: Das Diktat startet nicht von selbst, erst nach Tipp aufs Feld; das Ticket verlangte „direkt ins Diktat“.
- Ticket-Punkt „Watch-Hinweis“ fehlt hier und folgt in Schnitt 3b; das Ticket bleibt bis dahin offen.
- Ob der Knoten winzig erkennbar ist und die neue Signierung klappt, zeigt erst der TestFlight-Bau.

## Freigabe-Frage

Gibst du frei, dass die Komplikation den Knoten zeigt und die Erfassung öffnet, das Diktat aber erst nach einem Tipp startet?
