---
spec_file: docs/specs/tooling/feat-145-s2-gate.md
spec_sha256: 58614a6cc1ed1dc5a59f01a89da118b41557a3a8b2e7e222b716c3291e3422a2
spec_frozen_sha256: b0fb0557fa98a1866762cb0719b130d333a68e5350ee71d63ff257b5467c10eb
---

# PO-Briefing: feat-145-s2-gate

- **Spec:** docs/specs/tooling/feat-145-s2-gate.md
- **Issue:** #145
- **Erstellt:** 2026-10-22

## Was gebaut wird

Ein Ticket mit sichtbarer App-Änderung lässt sich nur abschließen, wenn ein echter, zum Stand passender Simulator-Durchlauf-Beleg vorliegt.

## Definition of Done

Ohne Beleg wird der Abschluss abgelehnt, mit ehrlichem Beleg aus einem Probe-Ticket durchgelassen; der Pilot an einem echten Ticket bleibt offen.

## Wie geprüft wird

Tests mit Attrappen und ein echter Probelauf zeigen Ablehnung und Annahme; ob das Gate im Alltag ehrliche Abschlüsse stört, zeigt erst der Pilot.

## Kritische Anmerkungen

- Neu seit erster Freigabe: Gate-Code ist im Plugin schon gebaut; Konfiguration wurde daran angepasst, Pilot-Ticket bleibt offen.
- Neu: Abnahme jetzt am Wegwerf-Probelauf statt am nächsten echten Ticket; Alltagstauglichkeit bleibt ungeprüft.
- Restlücke: selbst gebauter Beleg wird nicht als unecht erkannt.

## Freigabe-Frage

Soll das Gate in Loose Ends eingeschaltet werden, obwohl es ehrliche Abschlüsse blockieren kann?
