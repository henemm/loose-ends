---
spec_file: docs/specs/intents/feat-225-siri-link-flag-tags.md
spec_sha256: 8c5beecd882c9cda6404aed3d9b1a106b56ee55e3efbfc933e31f927b2828f19
---

# PO-Briefing: feat-225-siri-link-flag-tags

- **Spec:** docs/specs/intents/feat-225-siri-link-flag-tags.md
- **Issue:** #225
- **Erstellt:** 2026-10-06

## Was gebaut wird

Siris Link, Markierung und Tags landen in der neuen Aufgabe; unbekannte Tags oder mehrere Links werden abgelehnt.

## Definition of Done

Alle Abbildungen und Ablehnungen sind durch grüne Tests belegt; in der App ist noch nichts sichtbar, erst #25 schaltet Siri an.

## Wie geprüft wird

Tests prüfen Link, Markierung, Tags, Ablehnungen und Änderungsverlauf; ein echter Siri-Durchlauf wird nicht geprüft, das folgt mit #25.

## Kritische Anmerkungen

- Der Link bekommt keinen Änderungsverlauf, obwohl das Ticket das für jede Angabe verlangt; bewusste Abweichung.
- Siri nennt das abgelehnte Tag erst mit #25; hier gibt es nur den internen Fehler.
- Zwei Kriterien (Speicherfunktion unverändert, eine Namensregel) haben keinen Test, nur Diff-Sichtung.

## Freigabe-Frage

Akzeptierst du, dass der Link ohne Änderungsverlauf bleibt und Siri-Ablehnungen erst mit #25 sichtbar werden?
