---
spec_file: docs/specs/feat-705-schnitt-1-sondieren.md
spec_sha256: 4b8984ff02b1b77e7df8897f5195204cc93bc97a14e24bdd3943aad28d9861e5
spec_frozen_sha256: 6775c664873b5503d13f80c076f8e70d68e70f1a359d2e79f43c9ccc8654fcb4
---

# PO-Briefing: feat-705-apple-seite-einladung

- **Spec:** docs/specs/feat-705-schnitt-1-sondieren.md
- **Issue:** #705
- **Erstellt:** 2026-10-26

## Was gebaut wird

Ein Prüflauf liest bei Apple nur aus, was für die erste externe Einladung schon eingerichtet ist und was fehlt.

## Definition of Done

Nach einem Probelauf für iPhone und Mac steht Apples tatsächlicher Stand als Beleg im Ticket; bei Apple wurde nichts verändert.

## Wie geprüft wird

Tests gegen einen Apple-Nachbau belegen Lesen und Datenschutz der Ausgabe; Apples echte Antworten belegt erst der Lauf nach dem Merge.

## Kritische Anmerkungen

- Nur lesender Schnitt 1: Nichts wird eingerichtet oder eingereicht; das Ticket bleibt offen.
- Schnitt 2 (Einrichten, Einreichen) braucht deinen Beschreibungstext und deine Kontaktdaten; ohne sie keine Beta-Review-Einreichung.
- Die Datenschutz-Adresse ist nicht enthalten; die Probe meldet nur, ob sie bei Apple gesetzt ist.

## Freigabe-Frage

Soll zuerst nur der lesende Befund gebaut werden, bevor bei Apple etwas eingerichtet oder eingereicht wird?
