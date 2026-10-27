---
spec_file: docs/specs/tooling/feat-715-s1-next-ticket-skript.md
spec_sha256: 74ec580529cd4a074745c58d5678b31d864f8975bdc91e459c0abb82df21bddd
spec_frozen_sha256: eb85641384f197bf1f9119e85be2fab452beea95be60d9b1cd9abe588266f7fc
---

# PO-Briefing: feat-715-naechstes-ticket

- **Spec:** docs/specs/tooling/feat-715-s1-next-ticket-skript.md
- **Issue:** #715
- **Erstellt:** 2026-10-27

## Was gebaut wird

Ein Skript schlägt nach einem fertigen Ticket das nächste freie Ticket des Epics vor, mit Begründung und Überschneidungshinweis.

## Definition of Done

In allen Testfällen nennt das Skript das richtige nächste Ticket oder verständlich „keins“ und ändert nichts auf GitHub.

## Wie geprüft wird

14 Skripttests mit Attrappen decken jede Anforderung ab; ein echter Lauf gegen GitHub gehört nicht dazu.

## Kritische Anmerkungen

- Spec heute nachgebessert: Epic ist das oberste Eltern-Ticket, vorgeschlagen wird nur die unterste Ebene (neu AC-12, getestet).
- Ohne eingetragene Blocker schlägt das Skript heute Unpassendes vor; diese Pflege liegt außerhalb der Spec.
- Vorschlag nach /clear fehlt noch: kommt erst mit Schnitt 2, bis dahin tippt Henning weiter.

## Freigabe-Frage

Soll zuerst nur das Skript ohne den automatischen Vorschlag nach /clear gebaut werden?
