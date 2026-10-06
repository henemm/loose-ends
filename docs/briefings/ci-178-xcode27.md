---
spec_file: docs/specs/tooling/fix-178-ci-xcode27.md
spec_sha256: 9f3aeaf187848a1f351a11c9ecf40b66b4708296ff0ae6d548521934f057398d
---

# PO-Briefing: ci-178-xcode27

- **Spec:** docs/specs/tooling/fix-178-ci-xcode27.md
- **Issue:** #178
- **Erstellt:** 2026-10-06

## Was gebaut wird

Die automatische Prüfung nutzt dieselbe Xcode-Version wie Henning; der Sprach-Belastungstest wird stabil und deutlich schneller.

## Definition of Done

Alle drei Prüfjobs laufen grün mit Xcode 27.0, der Belastungstest besteht zehn Durchläufe je unter fünf Minuten, ohne Absenkung auf 26.

## Wie geprüft wird

Echte Läufe in der Cloud-Prüfung und kleine lokale Skripttests belegen es; für den Dialog-Zufall gibt es keinen lokalen Test.

## Kritische Anmerkungen

- Rote Oberflächentests durch aktives KI-Modell im Simulator würden nicht wiederholt, sondern das Ticket bliebe offen (#208).
- Der Dialog-Zufall hat keinen lokalen Test; nur der Zehn-Durchläufe-Lauf beweist die Behebung.
- Sechs statt höchstens fünf Dateien, von Henning erlaubt; läuft zudem auf Vorschau-Runner, der wegfallen kann.

## Freigabe-Frage

Soll die CI auf Xcode 27.0 umgestellt und der Belastungstest repariert werden?
