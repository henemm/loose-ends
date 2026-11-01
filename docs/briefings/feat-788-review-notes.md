---
spec_file: docs/specs/feat-788-schnitt-1-review-notizen.md
spec_sha256: a83caa656138d1c4add8c0538060fe5c683d56dc8e8369b2a9412271a408c4ce
spec_frozen_sha256: a836597fd8a16412dee2922dbcadbe12ac781cde0415b8fe18abdb7dfbbe8499
---

# PO-Briefing: feat-788-review-notes

- **Spec:** docs/specs/feat-788-schnitt-1-review-notizen.md
- **Issue:** #788
- **Erstellt:** 2026-11-01

## Was gebaut wird

Ein Handlauf liest den Stand der Einreichung bei Apple und trägt die geforderten Review-Notizen ein, ohne etwas einzureichen.

## Definition of Done

Der Handlauf zeigt Apples echten Stand, trägt den Notizentext nachweislich ein und meldet beim zweiten Lauf „unverändert“.

## Wie geprüft wird

Tests gegen einen Apple-Nachbau belegen Längengrenze, Wiederholbarkeit und Fehlerfälle; der echte Apple-Lauf ist erst nach dem Merge möglich.

## Kritische Anmerkungen

- Ticket-Ziel „Video-Link“ wird anders gelöst: Aufnahme als Anhang (Schnitt 2); Notizentext verweist schon vorher auf einen noch fehlenden Anhang.
- Ob Apple Notizen im Zustand „Information Needed“ überhaupt ändern lässt, zeigt erst der echte Lauf.
- Der Dokutext (kein Platzhalter, Verweis auf Anhang) hat nur Diff-Prüfung, keinen eigenen Test.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
