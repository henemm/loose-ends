---
spec_file: docs/specs/fix-883-widget-nachziehen-schnitt2.md
spec_sha256: 850db6b9c51c3ad07d1b7cf9157079a70ecad51af3625ebb8074b136bec6bcba
spec_frozen_sha256: 13d77f8c6dcad07625ba0d4a71f69220de85528139bc51a559d1f2ede424fa21
---

# PO-Briefing: fix-883-widget-schnitt2

- **Spec:** docs/specs/fix-883-widget-nachziehen-schnitt2.md
- **Issue:** #883
- **Erstellt:** 2026-11-13

## Was gebaut wird

Das Widget „Als nächstes“ aktualisiert sich, sobald Henning die App auf iPad oder Mac öffnet.

## Definition of Done

Nach einer Änderung am iPhone zeigt das Widget auf iPad und Mac nach dem Öffnen der App binnen Sekunden den neuen Stand.

## Wie geprüft wird

Tests und Simulator belegen das Neuladen beim Öffnen; ob das echte Widget auf iPad und Mac stimmt, zeigt nur Hennings TestFlight-Probe.

## Kritische Anmerkungen

- Bei weggewischter App bleibt das Widget bis zum Öffnen alt; die vermutete zweite Ursache wurde widerlegt, die echte bleibt ungeklärt.
- Ticket bleibt offen bis Hennings Rückmeldung; zeigt das Widget danach noch Altes, folgt ein neues Ticket.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
