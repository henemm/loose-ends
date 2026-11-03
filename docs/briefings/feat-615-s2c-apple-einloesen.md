---
spec_file: docs/specs/feat-615-schnitt-2c1-apple-einloesen.md
spec_sha256: 371e6e657cf873ccd88c3add37e11f2f76eb562506dec15ac090b07167959fcc
spec_frozen_sha256: c84033a82f81b06e8b8d0ef45f4b9cb3bcb91c2f208c2ffbea822c024a3c6c9b
---

# PO-Briefing: feat-615-s2c-apple-einloesen

- **Spec:** docs/specs/feat-615-schnitt-2c1-apple-einloesen.md
- **Issue:** #615
- **Erstellt:** 2026-11-03

## Was gebaut wird

Der Dienst kann Apples einmaligen Anmeldecode einlösen und den langlebigen Schlüssel erhalten; in der App ändert sich nichts.

## Definition of Done

Alle Server-Tests und die automatische Prüfung laufen grün, und es ändern sich genau drei Dateien; sichtbar ist nichts.

## Wie geprüft wird

Tests spielen Apples Antworten nach und beweisen Ausweis, Anfrage und Fehlerfälle; echte Verbindung zu Apple wird nicht getestet.

## Kritische Anmerkungen

- Widerruf bei Apple fehlt hier bewusst (Folgeschnitt 2c-2); die Ticket-Vorgabe „Apple-Widerruf ausgelöst" ist erst danach erfüllt.
- Echte Apple-Antwort ungeprüft: nur Nachbildungen, Abweichungen zeigen sich erst bei der späteren Anbindung.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
