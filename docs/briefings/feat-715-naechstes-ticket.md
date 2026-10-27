---
spec_file: docs/specs/tooling/feat-715-s1-next-ticket-skript.md
spec_sha256: 8c22acbe2bd5cb9aa089f920c36aa41a36582f73b78a0d86ac7976ec037ce9e2
spec_frozen_sha256: f4c95bdf367e881ff97ac3043e655b1268564255aeec35458018dbaf64d0c574
---

# PO-Briefing: feat-715-naechstes-ticket

- **Spec:** docs/specs/tooling/feat-715-s1-next-ticket-skript.md
- **Issue:** #715
- **Erstellt:** 2026-10-27

## Was gebaut wird

Ein Skript schlägt nach einem fertigen Ticket das nächste startbare Ticket des Epics vor, mit Begründung, Blockern und Überschneidungen.

## Definition of Done

Das Skript nennt für ein Epic das oberste freie Ticket oder erklärt verständlich, warum keines startbar ist, ohne GitHub zu verändern.

## Wie geprüft wird

Tests mit nachgebauten Antworten von GitHub und Sitzungen belegen Auswahl und Reihenfolge; ein echter Lauf gegen GitHub ist nicht enthalten.

## Kritische Anmerkungen

- Ohne gepflegte Blocker-Einträge schlägt es heute für #371 fälschlich #176 vor; diese Pflege ist nicht Teil der Spec.
- Das Ablegen des Vorschlags nach /clear fehlt hier; Henning ist erst mit dem zweiten Schnitt entlastet.
- Die Liste der Überschneidungs-Dateien ist geschätzt; Treffer warnen nur, streichen nichts.

## Freigabe-Frage

Soll zuerst nur das Skript gebaut werden, obwohl die Entlastung erst mit Hook und Blocker-Pflege eintritt?
