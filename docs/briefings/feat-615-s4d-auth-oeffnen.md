---
spec_file: docs/specs/feat-615-schnitt-4d-auth-oeffnen.md
spec_sha256: 26e9e8745a6fc392bb7568755611877e7913643de4cba9083614ffb4b1f1c332
spec_frozen_sha256: 0ecd60d335b1b701e2c5d2c4e4e831a4175b9df0cc823df80c5883f9241526e9
---

# PO-Briefing: feat-615-s4d-auth-oeffnen

- **Spec:** docs/specs/feat-615-schnitt-4d-auth-oeffnen.md
- **Issue:** #615
- **Erstellt:** 2026-11-10

## Was gebaut wird

Anmelden und Abmelden mit Apple in der App funktionieren künftig gegen den echten Dienst im Netz.

## Definition of Done

Die drei Wege sind von außen erreichbar und weisen Unberechtigte ab; du hast auf dem iPhone Anmelden und Abmelden erfolgreich ausprobiert.

## Wie geprüft wird

Ein Außenskript belegt die Öffnung, Löschen wird lokal echt geprüft; ob Apple dich in App und Browser gleich erkennt, zeigt nur dein iPhone-Test.

## Kritische Anmerkungen

- Dass Apple App und Browser als dieselbe Person erkennt, ist nur angenommen; andernfalls scheitert die Anmeldung und braucht einen Folgeschnitt.
- Löschen wird live nie mit echter Sitzung getestet; der Apple-Widerruf beim Löschen wird hier nicht eigens belegt.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
