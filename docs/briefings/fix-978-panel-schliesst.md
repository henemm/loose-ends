---
spec_file: docs/specs/fix-978-panel-schliesst.md
spec_sha256: 8802a57b1330923bf876907ee48799efbb1fd782ed1a67bd62a8595055996c2d
spec_frozen_sha256: 33ef7122df13d50f0c8c9f266122185a0cdb94a64b650580bdac76e5fd792855
---

# PO-Briefing: fix-978-panel-schliesst

- **Spec:** docs/specs/fix-978-panel-schliesst.md
- **Issue:** #978
- **Erstellt:** 2026-11-22

## Was gebaut wird

Das Menüleisten-Panel bekommt Diagnose-Protokolle, damit die Ursache des seltenen Selbst-Schließens beim nächsten Auftreten belegt wird; Verhalten bleibt unverändert.

## Definition of Done

Der Mac-Test läuft wieder aktiv und grün, und ein Protokoll-Anhang zeigt nach Läufen, was das Panel schließt.

## Wie geprüft wird

Automatische Mac-Läufe belegen, dass Test und Protokoll funktionieren; die Ursache selbst und ob Nutzer das Schließen sehen, beweisen sie nicht.

## Kritische Anmerkungen

- Das Ticket verlangt Ursache, Fix und drei grüne Läufe; dieser Schnitt liefert nur Material, der Fix folgt separat, Ticket bleibt offen.
- Ein auftretender Fehler gilt als erwartet und bleibt grün; Claude muss die Ergebnisse selbst auswerten.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
