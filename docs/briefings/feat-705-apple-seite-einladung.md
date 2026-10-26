---
spec_file: docs/specs/feat-705-schnitt-1-sondieren.md
spec_sha256: 85393ff3172f55ea08cf1e54351115c0472e05f907268848ab0c1ff1c825e0b5
---

# PO-Briefing: feat-705-apple-seite-einladung

- **Spec:** docs/specs/feat-705-schnitt-1-sondieren.md
- **Issue:** #705
- **Erstellt:** 2026-10-26

## Was gebaut wird

Ein Prüflauf liest bei Apple nur aus, was für die erste externe Einladung schon eingerichtet ist und was fehlt.

## Definition of Done

Die Prüfung ist gebaut und getestet; nach dem Merge liefert ein Probelauf Apples tatsächlichen Stand als Beleg.

## Wie geprüft wird

Tests gegen einen Apple-Nachbau belegen reines Lesen und Datenschutz; Apples echte Antworten zeigt erst der Probelauf.

## Kritische Anmerkungen

- Nur lesender Schnitt 1, Ticket bleibt offen. Schnitt 2 braucht deinen Wortlaut und Kontaktdaten; Datenschutz-Adresse nicht enthalten.
- Probelauf und Pull-Request-Text sind Nachweise nach dem Merge, keine Abnahmekriterien mehr (auf dein `override`).
- Umfang über der Schätzung: rund 250 Zeilen Produktionscode plus rund 280 Zeilen Tests.

## Freigabe-Frage

Soll zuerst nur der lesende Befund gebaut werden, bevor bei Apple etwas eingerichtet oder eingereicht wird?
