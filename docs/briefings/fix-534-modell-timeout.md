---
spec_file: docs/specs/fix-534-schnitt-1-mac-latenz.md
spec_sha256: a2f60839c8c04c397a86a390786d5ea21b309560498b4997f21a2f96908ba6a5
spec_frozen_sha256: 38529ae97cb817fc654546ce05e607fafcb4f6e4377d5104be93013fc9f5a873
---

# PO-Briefing: fix-534-modell-timeout

- **Spec:** docs/specs/fix-534-schnitt-1-mac-latenz.md
- **Issue:** #534
- **Erstellt:** 2026-10-21

## Was gebaut wird

Die Antwortzeit des Sprachmodells wird auf dem Mac kalt und warm gemessen; ein Bericht empfiehlt eine Zeitgrenze.

## Definition of Done

Mindestens 15 Messläufe liegen mit Rohdaten und Bericht samt Empfehlung vor; das Produktlimit bleibt unverändert bei 30 Sekunden.

## Wie geprüft wird

Nur die Auswertung ist automatisch getestet; Messlauf und Bericht beweisen sich selbst einmalig, das iPhone fehlt.

## Kritische Anmerkungen

- Abweichung: Ticket will abgeleitetes Limit samt iPhone; Schnitt 1 liefert nur Mac-Empfehlung, Limit bleibt 30 s, Ticket bleibt offen.
- Messlauf und Bericht haben keinen automatischen Test; Mac-Modell kann vom iPhone abweichen, „kalt“ heißt nur prozess-kalt.

## Freigabe-Frage

Soll zuerst nur die Mac-Messung mit Empfehlung gebaut werden, iPhone-Messung und neue Zahl im Produkt folgen später?
