---
spec_file: docs/specs/feat-621-schnitt-6b-betrieb.md
spec_sha256: f3a952a4366709146a347c6443d0471217be33fafcb7c33e13881e4ff2b6f5e7
spec_frozen_sha256: 788ccd83e37cb287c8daff181407766d26cf8a47962cff3c935f7cc5c92f2ff3
---

# PO-Briefing: feat-621-s6b-betrieb

- **Spec:** docs/specs/feat-621-schnitt-6b-betrieb.md
- **Issue:** #621
- **Erstellt:** 2026-11-08

## Was gebaut wird

claude.ai wird einmal echt mit deinem Apple-Konto als Connector verbunden und kann deine Loose-Ends-Abschrift abrufen.

## Definition of Done

claude.ai zeigt den Connector als verbunden, ein Werkzeugaufruf antwortet ohne Fehler, und nur dein Konto ist zugelassen.

## Wie geprüft wird

Prüfungen von außen und Zugriffsprotokolle belegen Öffnung, Anmeldeablauf und genau ein Konto; die Abweisung fremder Konten ist live nicht prüfbar.

## Kritische Anmerkungen

- Du gibst vorab Server-Schreibfreigabe und einen 20-Minuten-Termin: Apple-Portal in Chrome anmelden, danach in claude.ai verbinden.
- Kurzes Zeitfenster: Das erste angemeldete Konto wird zugelassen, deshalb verbindest du direkt nach dem Öffnen; danach wird die Tür geschlossen.
- Abweisung fremder Apple-Konten ist live nicht prüfbar, nur durch Tests belegt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
