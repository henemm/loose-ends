---
spec_file: docs/specs/tooling/feat-153-geraetestufe-ui-test.md
spec_sha256: f87c202027fb255a4591ccd57ab681bb4ed13123ccca16096ad8dd5dc48f9b5d
---

# PO-Briefing: feat-153-geraetestufe-ui-test

- **Spec:** docs/specs/tooling/feat-153-geraetestufe-ui-test.md
- **Issue:** #153
- **Erstellt:** 2026-09-29

## Was gebaut wird

Die dritte Abnahme-Stufe führt den echten Bedienablauf auf dem Testtelefon aus, nicht nur den Start.

## Definition of Done

Ein neuer Befehl lässt den Testablauf auf dem iPhone laufen, meldet eine Sperre eindeutig und sichert vier Bildschirmfotos.

## Wie geprüft wird

Automatisierte Prüfungen decken die Skriptlogik ab; nur ein echter Lauf zeigt, ob es mit dem Modell hält.

## Kritische Anmerkungen

- Teilen spart 85 Zeilen, lässt aber genau die Logik ungetestet, die #151 verursachte.
- AC-9 erlaubt, dass der zentrale Nachweis auf dem Gerät ausbleiben darf und trotzdem als erledigt gilt.
- Umfang wuchs über die Anfrage hinaus: neues Testskript, neue Einstellungsvariable, Zusatz zur Grundsatzentscheidung — technisch begründet.

## Freigabe-Frage

Soll das ganze Paket jetzt kommen (20 Zeilen über dem Limit, aber sofort automatisch geprüft), oder geteilt (im Limit, aber ungetestete Sperr-Logik bis zum Folgeticket)?
