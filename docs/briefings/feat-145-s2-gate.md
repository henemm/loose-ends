---
spec_file: docs/specs/tooling/feat-145-s2-gate.md
spec_sha256: 872e4fa5b034c998985e690b6531e62e8cbadd3b336640db713a517b3ed30c0d
spec_frozen_sha256: 61db95edbf20e2a19416f343f0858f75783dec3790bb24318df462246da60dfb
---

# PO-Briefing: feat-145-s2-gate

- **Spec:** docs/specs/tooling/feat-145-s2-gate.md
- **Issue:** #145
- **Erstellt:** 2026-10-22

## Was gebaut wird

Abschluss eines Tickets mit sichtbarer Änderung wird gesperrt, solange kein echter, zum Stand passender Simulator-Durchlauf-Beleg vorliegt.

## Definition of Done

Bewusster Versuch ohne Beleg wird abgelehnt; beim nächsten echten UI-Ticket kommt der Abschluss mit gültigem Beleg durch.

## Wie geprüft wird

Tests mit Attrappen prüfen alle Regeln samt Fehlversuchen; ob das Gate echte Simulatorläufe verträgt, zeigt erst der Pilot.

## Kritische Anmerkungen

- Gate-Code wird nicht hier gebaut, sondern im Plugin-Ticket #447; Fertigstellung hängt von dessen Release und einem späteren Pilot-Ticket ab.
- Restlücke: Ein selbst gebauter Simulator-Beleg wird nicht als unecht erkannt; Schutz erschwert Fälschen nur.
- Mac-Änderungen sind ausgenommen; Doku-Schnitt fehlt bewusst.

## Freigabe-Frage

Soll das Gate in Loose Ends eingeschaltet werden, obwohl es auch ehrliche Abschlüsse blockieren kann?
