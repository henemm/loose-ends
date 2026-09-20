---
spec_file: docs/specs/measurement/feat-92-date-parser.md
spec_sha256: e977e41b9eed56756fbe151ba4eb50cfb249fd9ec752e9c473c74745c4e759ac
---

# PO-Briefing: feat-92-date-parser

- **Spec:** docs/specs/measurement/feat-92-date-parser.md
- **Issue:** #92
- **Erstellt:** 2026-09-20

## Was gebaut wird

Ein Messbericht zeigt, wie zuverlässig eine Regel statt der KI Datum und Uhrzeit erkennt.

## Definition of Done

Der Bericht weist mindestens 95 Prozent korrekt erkannte Termine und null erfundene Termine auf den Testsätzen nach.

## Wie geprüft wird

Automatisierte Tests rechnen den Parser gegen einen festen Textkorpus; ein Nachweis im echten App-Gebrauch fehlt noch.

## Kritische Anmerkungen

- Die App nutzt den Parser noch nicht; das Datum kommt weiterhin von der KI.
- Der geforderte Nachweis auf dem echten Gerät fehlt; geprüft wurde nur am Schreibtisch-Rechner.
- Abschlussschritte offen: Zusammenführen, Übernahme bei Henning, Folgeauftrag für die App-Änderung.

## Freigabe-Frage

Reicht dir der Messnachweis, oder soll vor der Freigabe auch der Gerätetest und App-Umbau folgen?
