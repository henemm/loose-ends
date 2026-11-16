---
spec_file: docs/specs/feat-624-schnitt-2a-anzeige.md
spec_sha256: d10fe8c13894e17736f65639abf16ddc0dd6bf00ff9d8f88371fa49f8a2f2c4d
spec_frozen_sha256: ab5d8b4a92cd5623ecef296b40f41aeb88f75055841f4eb71537a9d4497fb222
---

# PO-Briefing: feat-624-s2-client

- **Spec:** docs/specs/feat-624-schnitt-2a-anzeige.md
- **Issue:** #624
- **Erstellt:** 2026-11-16

## Was gebaut wird

Claude zeigt im Chat die vier Ansichten der App (Jetzt, Fällig, Als nächstes, Offen) als Liste im freigegebenen Papier-Look.

## Definition of Done

In claude.ai erscheint zu „Jetzt“ eine Liste mit Kopf, Zahl und Randmarken, hell und dunkel, belegt durch geöffnete Bilder.

## Wie geprüft wird

Automatische Tests prüfen Darstellung, Absicherung gegen Fremdtext und Verbindungsablauf; das echte Aussehen in claude.ai prüft nur die Sichtprüfung nach dem Ausrollen.

## Kritische Anmerkungen

- Nur Anzeige: Abhaken und „Als nächstes“ aus dem Ticket fehlen und folgen im Teilschritt 2b; das Ticket bleibt offen.
- Zeilen von „Jetzt“ zeigen noch keine Tags (z. B. „Telefon“), anders als im Entwurf.
- Wirkt nach dem Ausrollen sofort bei jedem „Jetzt“-Aufruf in claude.ai; Rückweg ist der vorige Stand.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
