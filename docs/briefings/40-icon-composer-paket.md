---
spec_file: docs/specs/feat-40-icon-composer-paket.md
spec_sha256: 57f49590e9a4396e8c7f4e27cc7b8c5620d9526feb7c5b30aa0e61659be6b952
spec_frozen_sha256: 7c232a55fb935fa4b0e536e052d9e5cb980a7b6879dfd56d259da5f2be6edec8
---

# PO-Briefing: 40-icon-composer-paket

- **Spec:** docs/specs/feat-40-icon-composer-paket.md
- **Issue:** #40
- **Erstellt:** 2026-10-26

## Was gebaut wird

Das App-Icon bekommt Tiefe und Glanz im Liquid-Glass-Stil; Motiv und Farben bleiben unverändert.

## Definition of Done

Das Icon erscheint auf iPhone, Watch und Mac-Dock mit Glasoptik in Hell, Dunkel, Getönt und Klar, alle Builds laufen grün.

## Wie geprüft wird

Ein Skripttest prüft das Paket, Builds und Simulator belegen Hell; Dunkel, Getönt, Klar, Watch und Dock zeigt nur das Gerät.

## Kritische Anmerkungen

- Dunkel- und Getönt-Darstellung sind als Bild unerprobt; scheitert das Rendern, bleiben sie bis zum Gerätetest unbelegt.
- Abweichung: PNG-Fallbacks bleiben liegen, wirken aber nicht; Grund ist keine zweite Ebene, Logo-Doku wird umformuliert.
- Watch-Icon ist zusätzlich aufgenommen, im Ticket nicht verlangt; Ticket bleibt bis zum Gerätetest offen.

## Freigabe-Frage

Soll das Icon mit eigenem dunklem Grund und wirkungslosen PNG-Fallbacks wie beschrieben gebaut werden?
