---
spec_file: docs/specs/tooling/feat-268-schema-schranke.md
spec_sha256: 92b2cd8c77e5b81514efd8eee71c0ff16718e0504067993e4f0ccd993cf421be
spec_frozen_sha256: 2d6a12210b03ad4bbd662578bed2f02a791ea30c9995b02fb61c778b039e478e
---

# PO-Briefing: feat-268-schema-schranke

- **Spec:** docs/specs/tooling/feat-268-schema-schranke.md
- **Issue:** #268
- **Erstellt:** 2026-10-15

## Was gebaut wird

Ein TestFlight-Lauf bricht vor dem Hochladen ab, wenn Production ein Feld des Datenmodells noch nicht kennt.

## Definition of Done

Ein Probelauf mit absichtlich zusätzlichem Feld stoppt mit klarer Meldung, und es entsteht kein TestFlight-Build.

## Wie geprüft wird

Skript-Tests und ein Probelauf belegen den Halt; die Meldung bei fehlendem Token wird nur gelesen, nie ausgelöst.

## Kritische Anmerkungen

- Voraussetzung: PR #450 (Schema-Abbild, Test „Modell = Abbild“) ist noch offen; vorher kann nichts gebaut werden.
- Der Fall „Token fehlt“ bleibt ungetestet, nur per Durchsicht geprüft.
- Der Token läuft nach einem Jahr ab; dann stoppt jeder TestFlight-Lauf, bis ein neuer hinterlegt ist.

## Freigabe-Frage

Soll jede Modelländerung künftig den TestFlight-Lauf blockieren, bis du in der CloudKit Console deployt hast?
