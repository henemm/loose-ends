---
spec_file: docs/specs/feat-40-icon-composer-paket.md
spec_sha256: ade630a813690960480c03265093781979c400c9f77bc13322fef098c08486e3
spec_frozen_sha256: f79d4788ab642d9a1934ed887fa6fb180d091907cd8230186800869df63ae7bf
---

# PO-Briefing: 40-icon-composer-paket

- **Spec:** docs/specs/feat-40-icon-composer-paket.md
- **Issue:** #40
- **Erstellt:** 2026-10-26

## Was gebaut wird

Das App-Icon bekommt im Liquid-Glass-Stil Tiefe und Glanz; Motiv und Farben bleiben unverändert.

## Definition of Done

Im Simulator zeigt das Icon sichtbare Glasoptik, Hell und Dunkel sind gerendert, alle Builds und die CI laufen grün.

## Wie geprüft wird

Ein Skripttest prüft das Paket, Builds und Bilder belegen Hell und Dunkel; Getönt, Klar, Watch und Dock nicht.

## Kritische Anmerkungen

- Archiv-Prüfung und Geräteansicht folgen erst nach dem Merge; das Ticket bleibt bis zu deren Beleg offen.
- Getönt und Klar haben keinen Bildbeleg; Dunkel ist bisher nie gesehen worden.
- Watch-Icon ist zusätzlich enthalten, nicht verlangt; die alten PNG-Bilder bleiben wirkungslos liegen.

## Freigabe-Frage

Soll das Icon gebaut werden, obwohl Archiv und Geräteansicht erst nach dem Merge geprüft werden?
