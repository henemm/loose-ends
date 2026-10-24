---
spec_file: docs/specs/fix-418-ortanmeldung.md
spec_sha256: 357f960cea46f9b4eaf4ec2b891a9abdf1681f9293464b1f766eacf1b12154ad
spec_frozen_sha256: 50d25a9fad5839a65eb47d21aea919d744f723f290e918a872dae1968b42a0bb
---

# PO-Briefing: fix-418-ortanmeldung

- **Spec:** docs/specs/fix-418-ortanmeldung.md
- **Issue:** #418
- **Erstellt:** 2026-10-24

## Was gebaut wird

Scheitert die Ortsmitteilung für einen Ort, werden die anderen Orte trotzdem angemeldet.

## Definition of Done

Bei zwei Orten, von denen einer dauerhaft scheitert, wird der andere angemeldet; der scheiternde wird beim nächsten Lauf erneut versucht.

## Wie geprüft wird

Automatische Tests mit simuliertem Systemfehler weisen das nach; der echte Fehler ist weder im Simulator noch auf dem iPhone herstellbar.

## Kritische Anmerkungen

- Ein dauerhaft scheiternder Ort wird bei jedem Lauf neu versucht; keine Bremse, kein Hinweis für den Nutzer.
- Die Fehlerprotokollierung wird nur per Quelltext-Durchsicht geprüft, nicht durch einen Test.
- Der Gerätetest prüft nur „kein Rückschritt“, nicht den Fix selbst.

## Freigabe-Frage

Darf ein dauerhaft scheiternder Ort still immer wieder versucht werden, ohne dass die App darauf hinweist?
